"""
Kafka consumer for clinical trial data ingestion.
Consumes messages from multiple topics and writes batched data to MinIO (bronze layer).
"""

import os
import time
import json
import logging
import signal
import sys
from datetime import datetime
from typing import Dict, List
from collections import defaultdict
import yaml
from kafka import KafkaConsumer
from kafka.errors import KafkaError
from s3_writer import S3Writer

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ClinicalDataConsumer:
    """
    Kafka consumer for clinical trial data.
    Implements batching and writes to MinIO bronze layer.
    """
    
    def __init__(
        self,
        bootstrap_servers: str,
        topics: List[str],
        group_id: str,
        s3_endpoint: str,
        s3_access_key: str,
        s3_secret_key: str,
        s3_bucket: str,
        s3_prefix: str = "raw/",
        max_batch_size: int = 1000,
        max_wait_seconds: int = 30
    ):
        """
        Initialize Kafka consumer.
        
        Args:
            bootstrap_servers: Kafka broker addresses
            topics: List of topics to consume
            group_id: Consumer group ID
            s3_endpoint: MinIO endpoint URL
            s3_access_key: S3 access key
            s3_secret_key: S3 secret key
            s3_bucket: S3 bucket name
            s3_prefix: Prefix for bronze layer
            max_batch_size: Maximum messages per batch
            max_wait_seconds: Maximum seconds to wait before flushing
        """
        self.topics = topics
        self.max_batch_size = max_batch_size
        self.max_wait_seconds = max_wait_seconds
        self.running = True
        
        # Initialize Kafka consumer
        self.consumer = KafkaConsumer(
            *topics,
            bootstrap_servers=bootstrap_servers,
            group_id=group_id,
            auto_offset_reset='earliest',  # Start from beginning if no offset
            enable_auto_commit=False,      # Manual commit for better control
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            max_poll_records=1000
        )
        
        # Initialize S3 writer
        self.s3_writer = S3Writer(
            endpoint_url=s3_endpoint,
            access_key=s3_access_key,
            secret_key=s3_secret_key,
            bucket=s3_bucket,
            prefix=s3_prefix
        )
        
        # Batching state (per topic)
        self.batches: Dict[str, List[Dict]] = defaultdict(list)
        self.batch_start_times: Dict[str, float] = {}
        
        # Statistics
        self.stats = {
            "messages_consumed": 0,
            "batches_written": 0,
            "errors": 0
        }
        
        # Setup graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
        logger.info(
            f"Initialized consumer: topics={topics}, "
            f"group={group_id}, batch_size={max_batch_size}, "
            f"wait={max_wait_seconds}s"
        )
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully."""
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False
    
    def _should_flush_batch(self, topic: str) -> bool:
        """
        Check if batch should be flushed.
        
        Args:
            topic: Topic name
            
        Returns:
            True if batch should be flushed
        """
        batch = self.batches[topic]
        
        # Flush if batch size reached
        if len(batch) >= self.max_batch_size:
            return True
        
        # Flush if time limit reached
        if topic in self.batch_start_times:
            elapsed = time.time() - self.batch_start_times[topic]
            if elapsed >= self.max_wait_seconds:
                return True
        
        return False
    
    def _flush_batch(self, topic: str):
        """
        Write batch to S3 and commit offsets.
        
        Args:
            topic: Topic name
        """
        batch = self.batches[topic]
        
        if not batch:
            return
        
        try:
            # Write batch to S3
            s3_key = self.s3_writer.write_batch(
                topic=topic,
                messages=batch
            )
            
            # Commit Kafka offsets (all messages processed successfully)
            self.consumer.commit()
            
            # Update statistics
            self.stats["batches_written"] += 1
            
            # Clear batch
            self.batches[topic] = []
            if topic in self.batch_start_times:
                del self.batch_start_times[topic]
            
            logger.info(
                f"✓ Flushed batch: topic={topic}, size={len(batch)}, key={s3_key}"
            )
            
        except Exception as e:
            logger.error(f"✗ Failed to flush batch for {topic}: {e}")
            self.stats["errors"] += 1
            # Don't clear batch or commit - will retry on next flush attempt
    
    def _flush_all_batches(self):
        """Flush all pending batches (called on shutdown)."""
        logger.info("Flushing all pending batches...")
        
        for topic in list(self.batches.keys()):
            if self.batches[topic]:
                self._flush_batch(topic)
    
    def run(self):
        """
        Main consumer loop.
        Consumes messages and writes batched data to MinIO.
        """
        logger.info("🚀 Starting clinical data consumer...")
        logger.info(f"Consuming from topics: {', '.join(self.topics)}")
        
        try:
            while self.running:
                # Poll for messages (timeout 1 second)
                message_batch = self.consumer.poll(timeout_ms=1000)
                
                if not message_batch:
                    # No messages, check if any batches should be flushed by time
                    for topic in list(self.batches.keys()):
                        if self._should_flush_batch(topic):
                            self._flush_batch(topic)
                    continue
                
                # Process messages by topic
                for topic_partition, messages in message_batch.items():
                    topic = topic_partition.topic
                    
                    for message in messages:
                        # Add message to batch
                        self.batches[topic].append(message.value)
                        self.stats["messages_consumed"] += 1
                        
                        # Set batch start time if first message
                        if len(self.batches[topic]) == 1:
                            self.batch_start_times[topic] = time.time()
                        
                        # Check if batch should be flushed
                        if self._should_flush_batch(topic):
                            self._flush_batch(topic)
                
                # Log progress every 1000 messages
                if self.stats["messages_consumed"] % 1000 == 0:
                    logger.info(
                        f"📊 Consumed {self.stats['messages_consumed']} messages, "
                        f"written {self.stats['batches_written']} batches, "
                        f"errors: {self.stats['errors']}"
                    )
        
        except KeyboardInterrupt:
            logger.info("⏸️  Interrupted by user")
        
        except Exception as e:
            logger.error(f"✗ Consumer error: {e}", exc_info=True)
        
        finally:
            # Graceful shutdown
            logger.info("Shutting down consumer...")
            self._flush_all_batches()
            self.consumer.close()
            
            logger.info(
                f"✅ Consumer stopped. Final stats: "
                f"messages={self.stats['messages_consumed']}, "
                f"batches={self.stats['batches_written']}, "
                f"errors={self.stats['errors']}"
            )


# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

if __name__ == "__main__":
    # Get configuration from environment variables
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
    group_id = os.getenv("KAFKA_GROUP_ID", "clinical-consumer-group")
    
    # S3/MinIO configuration
    s3_endpoint = os.getenv("S3_ENDPOINT", "http://localhost:9000")
    s3_access_key = os.getenv("S3_ACCESS_KEY", "minioadmin")
    s3_secret_key = os.getenv("S3_SECRET_KEY", "minioadmin")
    s3_bucket = os.getenv("S3_BUCKET", "clinical-mlops")
    s3_prefix = os.getenv("S3_PREFIX", "raw/")
    
    # Batching configuration
    max_batch_size = int(os.getenv("MAX_BATCH_SIZE", "1000"))
    max_wait_seconds = int(os.getenv("MAX_WAIT_SECONDS", "30"))
    
    # Topics
    topics = [
        "patient-vitals",
        "lab-results",
        "medications",
        "adverse-events"
    ]
    
    logger.info("=" * 60)
    logger.info("Clinical MLOps - Kafka Consumer")
    logger.info("=" * 60)
    logger.info(f"Configuration:")
    logger.info(f"  • Kafka Brokers: {bootstrap_servers}")
    logger.info(f"  • Consumer Group: {group_id}")
    logger.info(f"  • Topics: {', '.join(topics)}")
    logger.info(f"  • S3 Endpoint: {s3_endpoint}")
    logger.info(f"  • S3 Bucket: {s3_bucket}")
    logger.info(f"  • Batch Size: {max_batch_size}")
    logger.info(f"  • Max Wait: {max_wait_seconds}s")
    logger.info("=" * 60)
    
    # Create and run consumer
    consumer = ClinicalDataConsumer(
        bootstrap_servers=bootstrap_servers,
        topics=topics,
        group_id=group_id,
        s3_endpoint=s3_endpoint,
        s3_access_key=s3_access_key,
        s3_secret_key=s3_secret_key,
        s3_bucket=s3_bucket,
        s3_prefix=s3_prefix,
        max_batch_size=max_batch_size,
        max_wait_seconds=max_wait_seconds
    )
    
    consumer.run()