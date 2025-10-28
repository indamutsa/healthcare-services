#!/bin/bash
#
# Observability Health Checks for Clinical MLOps Platform
# Provides detailed health monitoring for monitoring services
#
# Note: Common utilities must be sourced before this script

set -e

# Detailed Prometheus checks
check_prometheus() {
    local component="Prometheus"
    local url="http://localhost:9090"

    echo -e "${CYAN}Checking $component...${NC}"

    # Basic connectivity
    if ! curl -f "$url/-/healthy" >/dev/null 2>&1; then
        echo "  ${RED}✗${NC} Health endpoint not responding"
        return 1
    fi

    # Check if serving metrics
    if curl -s "$url/api/v1/label/__name__/values" | jq -r '.status' 2>/dev/null | grep -q "success"; then
        echo "  ${GREEN}✓${NC} Metrics API accessible"
    else
        echo "  ${YELLOW}⚠${NC} Metrics API not responding properly"
    fi

    # Check targets
    local target_count=$(curl -s "$url/api/v1/targets" 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
    echo "  ${GREEN}✓${NC} $target_count active targets"

    return 0
}

# Detailed Grafana checks
check_grafana() {
    local component="Grafana"
    local url="http://localhost:3000"

    echo -e "${CYAN}Checking $component...${NC}"

    # Basic connectivity
    if ! curl -f "$url/api/health" >/dev/null 2>&1; then
        echo "  ${RED}✗${NC} Health endpoint not responding"
        return 1
    fi

    # Check if serving UI
    if curl -s "$url" | grep -q "Grafana"; then
        echo "  ${GREEN}✓${NC} UI serving correctly"
    else
        echo "  ${YELLOW}⚠${NC} UI not responding properly"
    fi

    # Check dashboards
    local dashboard_count=$(curl -s "$url/api/search" 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    echo "  ${GREEN}✓${NC} $dashboard_count dashboards configured"

    return 0
}

# Detailed OpenSearch checks
check_opensearch() {
    local component="OpenSearch"
    local url="http://localhost:9200"

    echo -e "${CYAN}Checking $component...${NC}"

    # Basic connectivity
    if ! curl -f "$url" >/dev/null 2>&1; then
        echo "  ${RED}✗${NC} Not responding"
        return 1
    fi

    # Check cluster health
    local cluster_status=$(curl -s "$url/_cluster/health" 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unknown")
    echo "  ${GREEN}✓${NC} Cluster status: $cluster_status"

    # Check indices
    local index_count=$(curl -s "$url/_cat/indices" 2>/dev/null | wc -l 2>/dev/null || echo "0")
    echo "  ${GREEN}✓${NC} $index_count indices"

    return 0
}

# Detailed OpenSearch Dashboards checks
check_opensearch_dashboards() {
    local component="OpenSearch Dashboards"
    local url="http://localhost:5601"

    echo -e "${CYAN}Checking $component...${NC}"

    # Basic connectivity
    if ! curl -f "$url/api/status" >/dev/null 2>&1; then
        echo "  ${RED}✗${NC} Status endpoint not responding"
        return 1
    fi

    # Check if serving UI
    if curl -s "$url" | grep -q "OpenSearch"; then
        echo "  ${GREEN}✓${NC} UI serving correctly"
    else
        echo "  ${YELLOW}⚠${NC} UI not responding properly"
    fi

    return 0
}

# Quick observability status for visualization
quick_observability_status() {
    echo -e "${CYAN}Observability Services Status:${NC}"
    
    # Prometheus
    if curl -s --max-time 2 "http://localhost:9090/-/healthy" >/dev/null 2>&1; then
        local metrics_count=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" 2>/dev/null | jq -r '.data | length' 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} Prometheus: Healthy ($metrics_count metrics)"
    else
        echo -e "  ${RED}✗${NC} Prometheus: Unhealthy"
    fi
    
    # Grafana
    if curl -s --max-time 2 "http://localhost:3000/api/health" >/dev/null 2>&1; then
        local dashboard_count=$(curl -s "http://localhost:3000/api/search" 2>/dev/null | jq -r 'length' 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} Grafana: Healthy ($dashboard_count dashboards)"
    else
        echo -e "  ${RED}✗${NC} Grafana: Unhealthy"
    fi
    
    # OpenSearch
    if curl -s --max-time 2 "http://localhost:9200" >/dev/null 2>&1; then
        local cluster_status=$(curl -s "http://localhost:9200/_cluster/health" 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} OpenSearch: Healthy ($cluster_status)"
    else
        echo -e "  ${RED}✗${NC} OpenSearch: Unhealthy"
    fi
    
    # OpenSearch Dashboards
    if curl -s --max-time 2 "http://localhost:5601/api/status" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} OpenSearch Dashboards: Healthy"
    else
        echo -e "  ${RED}✗${NC} OpenSearch Dashboards: Unhealthy"
    fi
    
    # Data Prepper
    if curl -s --max-time 2 "http://localhost:4900/health" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Data Prepper: Healthy"
    else
        echo -e "  ${RED}✗${NC} Data Prepper: Unhealthy"
    fi
    
    # Filebeat
    if docker ps | grep -q filebeat; then
        echo -e "  ${GREEN}✓${NC} Filebeat: Running"
    else
        echo -e "  ${RED}✗${NC} Filebeat: Not running"
    fi
}

# Show observability URLs
show_observability_urls() {
    echo -e "${CYAN}Observability URLs:${NC}"
    echo -e "  • Prometheus:     http://localhost:9090"
    echo -e "  • Grafana:        http://localhost:3000"
    echo -e "  • OpenSearch:     http://localhost:9200"
    echo -e "  • OpenSearch Dashboards: http://localhost:5601"
    echo -e "  • Data Prepper:   http://localhost:4900"
}