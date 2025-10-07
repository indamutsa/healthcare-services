#!/bin/bash
# Complete Kafka inspection script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

BS="localhost:9092"

print_header "1. Kafka Broker Status"
docker exec kafka kafka-broker-api-versions --bootstrap-server $BS | head -1

print_header "2. List All Topics"
docker exec kafka kafka-topics --bootstrap-server $BS --list

print_header "3. Topic Configurations"
for topic in patient-vitals lab-results medications adverse-events; do
    echo -e "${YELLOW}Topic: $topic${NC}"
    docker exec kafka kafka-topics --bootstrap-server $BS --describe --topic $topic
    echo ""
done

print_header "4. Message Counts"
for topic in patient-vitals lab-results medications adverse-events; do
    end=$(docker exec kafka kafka-get-offsets --bootstrap-server $BS --topic $topic --time -1 | awk -F: '{print $3}')
    begin=$(docker exec kafka kafka-get-offsets --bootstrap-server $BS --topic $topic --time -2 | awk -F: '{print $3}')
    count=$((end - begin))
    echo -e "${GREEN}$topic: $count messages${NC}"
done

print_header "5. Consumer Groups"
docker exec kafka kafka-consumer-groups --bootstrap-server $BS --list
echo ""
docker exec kafka kafka-consumer-groups --bootstrap-server $BS --describe --group clinical-consumer-group

print_header "6. Sample Messages (first 3 from patient-vitals)"
docker exec kafka kafka-console-consumer \
    --bootstrap-server $BS \
    --topic patient-vitals \
    --from-beginning \
    --max-messages 3

echo ""
echo -e "${GREEN}✅ Kafka inspection complete!${NC}"
echo ""
echo "To view live messages: docker exec -it kafka bash"
echo "Then run: kafka-console-consumer --bootstrap-server $BS --topic patient-vitals"