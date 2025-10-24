#!/bin/bash
#
# Visualize ML Training Results
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

MLFLOW_URL="http://localhost:5000"

print_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "$1"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

check_mlflow() {
    if ! curl -sf "$MLFLOW_URL/health" > /dev/null 2>&1; then
        echo -e "${RED}✗ MLflow server not accessible${NC}"
        echo "Start MLflow: ./manage-pipeline.sh start 4"
        exit 1
    fi
}

get_experiments() {
    curl -sf "$MLFLOW_URL/api/2.0/mlflow/experiments/list" | \
        jq -r '.experiments[] | "\(.experiment_id)|\(.name)"' 2>/dev/null
}

get_runs() {
    local experiment_id=$1
    curl -sf "$MLFLOW_URL/api/2.0/mlflow/runs/search" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"experiment_ids\": [\"$experiment_id\"]}" | \
        jq -r '.runs[] | "\(.info.run_id)|\(.info.run_name)|\(.data.metrics)"' 2>/dev/null
}

show_summary() {
    print_header "📊 ML Training Summary"
    
    # Get experiments
    local experiments=$(get_experiments)
    
    if [ -z "$experiments" ]; then
        echo -e "${YELLOW}No experiments found${NC}"
        echo ""
        echo "Run training first: ./manage-pipeline.sh train"
        return
    fi
    
    echo "Experiments:"
    echo ""
    
    local exp_count=0
    while IFS='|' read -r exp_id exp_name; do
        ((exp_count++))
        echo -e "${CYAN}$exp_count. $exp_name${NC} (ID: $exp_id)"
        
        # Get runs for this experiment
        local runs=$(curl -sf "$MLFLOW_URL/api/2.0/mlflow/runs/search" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "{\"experiment_ids\": [\"$exp_id\"], \"max_results\": 10}" | \
            jq -r '.runs[]' 2>/dev/null)
        
        if [ -n "$runs" ]; then
            echo "$runs" | jq -r '"   Run: \(.info.run_name // "unnamed") | Status: \(.info.status) | AUC: \(.data.metrics[] | select(.key=="val_roc_auc") | .value)"' | head -10
        fi
        
        echo ""
    done <<< "$experiments"
}

show_best_models() {
    print_header "🏆 Best Models by Metric"
    
    # Get all runs
    local all_runs=$(curl -sf "$MLFLOW_URL/api/2.0/mlflow/runs/search" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"max_results": 100}' | \
        jq -r '.runs[]' 2>/dev/null)
    
    if [ -z "$all_runs" ]; then
        echo "No runs found"
        return
    fi
    
    # Best by AUC
    echo -e "${CYAN}Best by Validation AUC:${NC}"
    echo "$all_runs" | \
        jq -r 'select(.data.metrics[] | select(.key=="val_roc_auc")) | 
               "\(.info.run_name // "unnamed"): \(.data.metrics[] | select(.key=="val_roc_auc") | .value)"' | \
        sort -t: -k2 -rn | head -5
    
    echo ""
    
    # Best by F1
    echo -e "${CYAN}Best by F1 Score:${NC}"
    echo "$all_runs" | \
        jq -r 'select(.data.metrics[] | select(.key=="val_f1_score")) | 
               "\(.info.run_name // "unnamed"): \(.data.metrics[] | select(.key=="val_f1_score") | .value)"' | \
        sort -t: -k2 -rn | head -5
    
    echo ""
}

show_recent_runs() {
    print_header "🕐 Recent Training Runs"
    
    local runs=$(curl -sf "$MLFLOW_URL/api/2.0/mlflow/runs/search" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"max_results": 10, "order_by": ["attribute.start_time DESC"]}' | \
        jq -r '.runs[]' 2>/dev/null)
    
    if [ -z "$runs" ]; then
        echo "No runs found"
        return
    fi
    
    echo "Last 10 training runs:"
    echo ""
    
    printf "%-30s %-15s %-10s %-10s\n" "Run Name" "Status" "AUC" "Duration"
    echo "────────────────────────────────────────────────────────────────────"
    
    echo "$runs" | jq -r '
        .info as $info | 
        (.data.metrics[] | select(.key=="val_roc_auc") | .value // "N/A") as $auc |
        (($info.end_time - $info.start_time) / 1000 // 0) as $duration |
        "\($info.run_name // "unnamed")|\($info.status)|\($auc)|\($duration)s"
    ' | while IFS='|' read -r name status auc duration; do
        printf "%-30s %-15s %-10s %-10s\n" "$name" "$status" "$auc" "$duration"
    done
    
    echo ""
}

show_model_comparison() {
    print_header "📈 Model Comparison"
    
    # Get latest parent run
    local parent_run=$(curl -sf "$MLFLOW_URL/api/2.0/mlflow/runs/search" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"filter": "tags.mlflow.runName LIKE \"%training_pipeline%\"", "max_results": 1, "order_by": ["attribute.start_time DESC"]}' | \
        jq -r '.runs[0].info.run_id' 2>/dev/null)
    
    if [ -z "$parent_run" ] || [ "$parent_run" = "null" ]; then
        echo "No training pipeline runs found"
        return
    fi
    
    echo "Latest Training Pipeline: $parent_run"
    echo ""
    
    # Get child runs
    local child_runs=$(curl -sf "$MLFLOW_URL/api/2.0/mlflow/runs/search" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"filter\": \"tags.mlflow.parentRunId = '$parent_run'\"}" | \
        jq -r '.runs[]' 2>/dev/null)
    
    if [ -z "$child_runs" ]; then
        echo "No model runs found"
        return
    fi
    
    printf "%-25s %-10s %-10s %-10s %-10s\n" "Model" "AUC" "Precision" "Recall" "F1"
    echo "────────────────────────────────────────────────────────────────────────"
    
    echo "$child_runs" | jq -r '
        .info.run_name as $name |
        (.data.metrics[] | select(.key=="val_roc_auc") | .value // "N/A") as $auc |
        (.data.metrics[] | select(.key=="val_precision") | .value // "N/A") as $prec |
        (.data.metrics[] | select(.key=="val_sensitivity") | .value // "N/A") as $rec |
        (.data.metrics[] | select(.key=="val_f1_score") | .value // "N/A") as $f1 |
        "\($name)|\($auc)|\($prec)|\($rec)|\($f1)"
    ' | while IFS='|' read -r name auc prec rec f1; do
        printf "%-25s %-10s %-10s %-10s %-10s\n" "$name" "$auc" "$prec" "$rec" "$f1"
    done
    
    echo ""
}

open_mlflow_ui() {
    echo ""
    echo -e "${CYAN}Opening MLflow UI...${NC}"
    echo ""
    echo "URL: $MLFLOW_URL"
    echo ""
    
    # Try to open browser
    if command -v xdg-open > /dev/null; then
        xdg-open "$MLFLOW_URL" 2>/dev/null
    elif command -v open > /dev/null; then
        open "$MLFLOW_URL" 2>/dev/null
    else
        echo "Open this URL in your browser: $MLFLOW_URL"
    fi
}

main() {
    print_header "🎨 ML Training Visualization"
    
    # Check MLflow
    check_mlflow
    
    # Show summaries
    show_summary
    show_recent_runs
    show_best_models
    show_model_comparison
    
    # Prompt to open UI
    echo ""
    echo -e "${GREEN}View detailed results in MLflow UI?${NC}"
    read -p "Open browser? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open_mlflow_ui
    else
        echo ""
        echo "Access MLflow UI at: ${CYAN}$MLFLOW_URL${NC}"
    fi
    
    echo ""
}

# Run main
main