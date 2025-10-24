#!/bin/bash
# ===============================================================
# 🧠 Comprehensive Kafka Health & Inspection Script
# Author: Arsene AI Assistant
# ===============================================================

set -e

# ---------- COLORS ----------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

BS="localhost:9092"
BROKER_CONTAINER="kafka"
TOPICS=("patient-vitals" "lab-results" "medications" "adverse-events")

# ---------- 1. BROKER STATUS ----------
print_header "1. Kafka Broker Status & Metadata"
docker exec $BROKER_CONTAINER kafka-broker-api-versions --bootstrap-server $BS | head -1 || {
    echo -e "${RED}❌ Cannot reach Kafka broker at $BS${NC}"
    exit 1
}

echo -e "${GREEN}✅ Broker is reachable and responding.${NC}"

# ---------- 2. PRODUCER CHECK ----------
print_header "2. Producer Metadata Check"
docker exec $BROKER_CONTAINER kafka-metadata-shell --bootstrap-server $BS --describe 2>/dev/null | head -n 10 || {
    echo -e "${YELLOW}⚠️  kafka-metadata-shell not found, skipping metadata check.${NC}"
}

# ---------- 3. LIST TOPICS ----------
print_header "3. List All Topics"
docker exec $BROKER_CONTAINER kafka-topics --bootstrap-server $BS --list || {
    echo -e "${RED}❌ Unable to list topics.${NC}"
    exit 1
}

# ---------- 4. TOPIC DETAILS ----------
print_header "4. Topic Configurations & Partition Details"
for topic in "${TOPICS[@]}"; do
    echo -e "${YELLOW}🔹 Topic: ${topic}${NC}"
    docker exec $BROKER_CONTAINER kafka-topics --bootstrap-server $BS --describe --topic "$topic" || \
        echo -e "${RED}   ⚠️ Topic ${topic} not found.${NC}"
    echo ""
done

# ---------- 5. MESSAGE COUNT (Offsets) ----------
print_header "5. Message Counts (beginning → end offset difference)"
for topic in "${TOPICS[@]}"; do
    begin=$(docker exec $BROKER_CONTAINER kafka-run-class kafka.tools.GetOffsetShell --broker-list $BS --topic $topic --time -2 2>/dev/null | awk -F: '{sum += $3} END {print sum+0}')
    end=$(docker exec $BROKER_CONTAINER kafka-run-class kafka.tools.GetOffsetShell --broker-list $BS --topic $topic --time -1 2>/dev/null | awk -F: '{sum += $3} END {print sum+0}')
    count=$((end - begin))
    echo -e "${GREEN}$topic:${NC} $count messages"
done

# ---------- 6. CONSUMER GROUPS ----------
print_header "6. Consumer Groups Overview"
docker exec $BROKER_CONTAINER kafka-consumer-groups --bootstrap-server $BS --list || echo -e "${RED}❌ Failed to list consumer groups.${NC}"
echo ""

for group in $(docker exec $BROKER_CONTAINER kafka-consumer-groups --bootstrap-server $BS --list 2>/dev/null); do
    echo -e "${YELLOW}🔹 Group: $group${NC}"
    docker exec $BROKER_CONTAINER kafka-consumer-groups --bootstrap-server $BS --describe --group "$group" || \
        echo -e "${RED}   ⚠️ Failed to describe group $group${NC}"
    echo ""
done

# ---------- 7. CONSUMER LAG ----------
print_header "7. Consumer Lag per Partition"
for group in $(docker exec $BROKER_CONTAINER kafka-consumer-groups --bootstrap-server $BS --list 2>/dev/null); do
    echo -e "${YELLOW}Group: $group${NC}"
    docker exec $BROKER_CONTAINER kafka-consumer-groups --bootstrap-server $BS --describe --group "$group" \
        | awk '{if (NR>1 && $6!="") print "   Topic:", $2, "Partition:", $3, "Lag:", $6}'
    echo ""
done

# ---------- 8. SAMPLE MESSAGES ----------
print_header "8. Sample Messages (first 3 per topic)"
for topic in "${TOPICS[@]}"; do
    echo -e "${YELLOW}Topic: $topic${NC}"
    docker exec $BROKER_CONTAINER kafka-console-consumer \
        --bootstrap-server $BS \
        --topic "$topic" \
        --from-beginning \
        --max-messages 3 \
        --timeout-ms 5000 || echo -e "${RED}⚠️ No messages found for $topic${NC}"
    echo ""
done

# ---------- 9. OPTIONAL: LIVE STREAM ----------
print_header "9. Live Message Streaming"
echo -e "${BLUE}To view live messages from a topic, run:${NC}"
echo -e "${GREEN}docker exec -it kafka kafka-console-consumer --bootstrap-server $BS --topic patient-vitals --from-beginning${NC}"
echo ""
echo -e "${BLUE}To produce messages manually, run:${NC}"
echo -e "${GREEN}docker exec -it kafka kafka-console-producer --bootstrap-server $BS --topic patient-vitals${NC}"

# ---------- SUMMARY ----------
print_header "✅ Kafka Inspection Complete!"
echo -e "${GREEN}Broker:${NC} $BS"
echo -e "${GREEN}Topics:${NC} ${TOPICS[*]}"
echo -e "${GREEN}Checked consumer groups, lag, and sample messages.${NC}"
echo ""
