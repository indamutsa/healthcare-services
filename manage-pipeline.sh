#!/bin/bash
# Manage data pipeline lifecycle: start, restart, shutdown, cleanup

set -e

# --- Colors ---
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Services ---
SERVICES="kafka zookeeper kafka-ui minio minio-setup kafka-producer kafka-consumer spark-master spark-batch spark-streaming spark-worker"

# --- Helper: usage ---
usage() {
  echo -e "${CYAN}Usage:${NC} $0 [option]"
  echo ""
  echo "Options:"
  echo "  -s, --start       Start services"
  echo "  -r, --restart     Restart services (rebuild & recreate)"
  echo "  -x, --shutdown    Shutdown services (keep images & volumes)"
  echo "  -f, --full-clean  Full cleanup (containers, images, volumes, networks)"
  echo "  -h, --help        Show this help message"
  echo ""
  exit 0
}

# --- No args ---
if [ $# -eq 0 ]; then
  usage
fi

# --- Parse flags (short + long) ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--start)
      echo -e "${YELLOW}Starting data pipeline services...${NC}"
      docker compose up -d $SERVICES
      echo -e "${GREEN}✓ Services started${NC}"
      ;;
    -r|--restart)
      echo -e "${YELLOW}Restarting data pipeline services...${NC}"
      docker compose stop $SERVICES
      docker compose down -v
      docker compose up -d --build --force-recreate $SERVICES
      echo -e "${GREEN}✓ Services restarted${NC}"
      ;;
    -x|--shutdown)
      echo -e "${YELLOW}Shutting down data pipeline services...${NC}"
      docker compose down
      echo -e "${GREEN}✓ Services stopped${NC}"
      ;;
    -f|--full-clean)
      echo -e "${RED}⚠ Performing full cleanup (containers, images, volumes, networks)...${NC}"
      docker compose down -v --remove-orphans || true
      docker system prune -a --volumes -f || true
      echo -e "${GREEN}✓ Full cleanup complete${NC}"
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "${RED}Unknown option:${NC} $1"
      usage
      ;;
  esac
  shift
done

echo ""
echo "Next steps:"
echo "  - Check service status: docker ps"
echo "  - View logs: docker compose logs -f kafka-producer kafka-consumer spark-streaming"
