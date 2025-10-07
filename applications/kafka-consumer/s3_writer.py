"""
S3/MinIO writer for Kafka consumer.
Handles batched writes with date/hour partitioning for data lake bronze layer.
"""

import json
import logging
from datetime import datetime
from typing import List, Dict
from pathlib import Path
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class S3Writer:
    """
    Writes batched messages to S3/MinIO with partitioning.
    Implements bronze layer storage strategy for data lake.
    """
    
    def __init__(
        self,
        endpoint_url: str,
        access_key: str,
        secret_key: str,
        bucket: str,
        prefix: str = "raw/"
    ):
        """
        Initialize S3 writer.
        
        Args:
            endpoint_url: MinIO endpoint (e.g., http://minio:9000)
            access_key: S3 access key
            secret_key: S3 secret key
            bucket: S3 bucket name
            prefix: Prefix for all objects (bronze layer path)
        """
        self.bucket = bucket
        self.prefix = prefix.rstrip('/') + '/'
        
        # Initialize S3 client (works with MinIO)
        self.s3_client = boto3.client(
            's3',
            endpoint_url=endpoint_url,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name='us-east-1'  # MinIO doesn't care about region
        )
        
        # Verify bucket exists
        self._ensure_bucket_exists()
        
        logger.info(
            f"Initialized S3Writer: bucket={bucket}, "
            f"prefix={self.prefix}, endpoint={endpoint_url}"
        )
    
    def _ensure_bucket_exists(self):
        """Create bucket if it doesn't exist."""
        try:
            self.s3_client.head_bucket(Bucket=self.bucket)
            logger.info(f"Bucket '{self.bucket}' exists")
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == '404':
                logger.info(f"Creating bucket '{self.bucket}'")
                self.s3_client.create_bucket(Bucket=self.bucket)
            else:
                raise
    
    def write_batch(
        self,
        topic: str,
        messages: List[Dict],
        batch_id: str = None
    ) -> str:
        """
        Write batch of messages to S3 with partitioning.
        
        Args:
            topic: Kafka topic name (used for path)
            messages: List of message dictionaries
            batch_id: Optional batch identifier (timestamp by default)
            
        Returns:
            S3 key where data was written
        """
        if not messages:
            logger.warning("Empty batch, skipping write")
            return None
        
        # Generate batch metadata
        now = datetime.utcnow()
        batch_id = batch_id or now.strftime("%Y%m%d_%H%M%S_%f")
        
        # Build partitioned path: raw/topic/date=YYYY-MM-DD/hour=HH/batch_*.json
        s3_key = self._build_s3_key(topic, now, batch_id)
        
        # Prepare batch content (newline-delimited JSON)
        batch_content = self._serialize_batch(messages)
        
        # Write to S3
        try:
            self.s3_client.put_object(
                Bucket=self.bucket,
                Key=s3_key,
                Body=batch_content.encode('utf-8'),
                ContentType='application/json',
                Metadata={
                    'topic': topic,
                    'batch_size': str(len(messages)),
                    'timestamp': now.isoformat(),
                    'batch_id': batch_id
                }
            )
            
            logger.info(
                f"✓ Wrote batch to s3://{self.bucket}/{s3_key} "
                f"({len(messages)} messages, {len(batch_content)} bytes)"
            )
            
            return s3_key
            
        except ClientError as e:
            logger.error(f"✗ Failed to write batch to S3: {e}")
            raise
    
    def _build_s3_key(self, topic: str, timestamp: datetime, batch_id: str) -> str:
        """
        Build S3 key with partitioning.
        
        Format: raw/{topic}/date={YYYY-MM-DD}/hour={HH}/batch_{batch_id}.json
        
        Args:
            topic: Kafka topic name
            timestamp: Batch timestamp
            batch_id: Unique batch identifier
            
        Returns:
            S3 key path
        """
        date_str = timestamp.strftime("%Y-%m-%d")
        hour_str = timestamp.strftime("%H")
        
        # Sanitize topic name (replace hyphens with underscores for consistency)
        topic_safe = topic.replace('-', '_')
        
        return (
            f"{self.prefix}{topic_safe}/"
            f"date={date_str}/"
            f"hour={hour_str}/"
            f"batch_{batch_id}.json"
        )
    
    def _serialize_batch(self, messages: List[Dict]) -> str:
        """
        Serialize messages to newline-delimited JSON.
        
        Args:
            messages: List of message dictionaries
            
        Returns:
            Newline-delimited JSON string
        """
        # Each message on its own line (JSONL format)
        # This makes it easy to process with tools like jq, Spark, etc.
        return '\n'.join(json.dumps(msg) for msg in messages)
    
    def read_batch(self, s3_key: str) -> List[Dict]:
        """
        Read batch from S3 (useful for testing/debugging).
        
        Args:
            s3_key: S3 key to read
            
        Returns:
            List of message dictionaries
        """
        try:
            response = self.s3_client.get_object(
                Bucket=self.bucket,
                Key=s3_key
            )
            
            content = response['Body'].read().decode('utf-8')
            
            # Parse newline-delimited JSON
            messages = [json.loads(line) for line in content.strip().split('\n')]
            
            logger.info(f"Read {len(messages)} messages from s3://{self.bucket}/{s3_key}")
            return messages
            
        except ClientError as e:
            logger.error(f"Failed to read from S3: {e}")
            raise
    
    def list_batches(self, topic: str, date: str = None, hour: str = None) -> List[str]:
        """
        List batch files for a topic.
        
        Args:
            topic: Kafka topic name
            date: Optional date filter (YYYY-MM-DD)
            hour: Optional hour filter (HH)
            
        Returns:
            List of S3 keys
        """
        topic_safe = topic.replace('-', '_')
        prefix = f"{self.prefix}{topic_safe}/"
        
        if date:
            prefix += f"date={date}/"
            if hour:
                prefix += f"hour={hour}/"
        
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket,
                Prefix=prefix
            )
            
            if 'Contents' not in response:
                return []
            
            keys = [obj['Key'] for obj in response['Contents']]
            logger.info(f"Found {len(keys)} batches for {topic} (prefix={prefix})")
            return keys
            
        except ClientError as e:
            logger.error(f"Failed to list batches: {e}")
            raise