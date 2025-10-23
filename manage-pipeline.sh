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
      echo -e "${RED}⚠ Performing full cleanup for data pipeline (containers, images, volumes, networks)...${NC}"

      SERVICES="kafka zookeeper kafka-ui minio minio-setup kafka-producer kafka-consumer spark-master spark-batch spark-streaming spark-worker"

      echo -e "${YELLOW}→ Stopping and removing containers for project services...${NC}"
      for svc in $SERVICES; do
        CID=$(docker ps -aqf "name=${svc}")
        if [ -n "$CID" ]; then
          echo "   - Removing container: $svc ($CID)"
          docker rm -f "$CID" >/dev/null 2>&1 || true
        else
          echo "   - No running container found for: $svc"
        fi
      done

      echo -e "${YELLOW}→ Removing project-specific volumes (attached to services)...${NC}"
      for svc in $SERVICES; do
        docker volume ls -q | grep -E "${svc}" | xargs -r docker volume rm -f >/dev/null 2>&1 || true
      done

      echo -e "${YELLOW}→ Removing project-specific networks...${NC}"
      docker network ls --format '{{.Name}}' | grep -E "clinical|mlops" | xargs -r docker network rm >/dev/null 2>&1 || true

      echo -e "${YELLOW}→ Detecting and removing images tied to project services...${NC}"
      IMAGES_TO_REMOVE=()

      for svc in $SERVICES; do
        IMG_ID=$(docker compose images --quiet $svc 2>/dev/null || true)
        if [ -z "$IMG_ID" ]; then
          IMG_ID=$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -E "$svc" | awk '{print $2}' | head -n 1)
        fi
        if [ -n "$IMG_ID" ]; then
          echo "   - Found image for $svc: $IMG_ID"
          IMAGES_TO_REMOVE+=("$IMG_ID")
        fi
      done

      # Also include known upstream base images
      echo -e "${YELLOW}→ Including known upstream base images...${NC}"
      BASE_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | \
        grep -E "apache/spark|confluentinc/cp-kafka|minio/minio|minio/mc" | \
        awk '{print $2}')
      if [ -n "$BASE_IMAGES" ]; then
        IMAGES_TO_REMOVE+=($BASE_IMAGES)
      fi

      UNIQUE_IMAGES=$(printf "%s\n" "${IMAGES_TO_REMOVE[@]}" | sort -u)
      if [ -n "$UNIQUE_IMAGES" ]; then
        echo ""
        echo "Removing these images:"
        echo "$UNIQUE_IMAGES" | sed 's/^/   - /'
        echo "$UNIQUE_IMAGES" | xargs -r docker rmi -f >/dev/null 2>&1 || true
      else
        echo "No images found for project services or base images."
      fi

      echo -e "${YELLOW}→ Final prune (dangling cache, layers)...${NC}"
      docker system prune -f >/dev/null 2>&1 || true

      echo -e "${GREEN}✓ Full cleanup complete!${NC}"
      echo ""
      echo "You can now rebuild everything fresh:"
      echo "  docker compose up -d --build"
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
