#!/bin/bash

# Minimal debug commands for testing

run_debug_commands() {
    local target_level=$1
    
    echo "Debug Commands - Level $target_level"
    echo "================================"
    echo "Timestamp: $(date)"
    echo "Target Level: $target_level"
    
    # Level 0: Basic system status
    if [ "$target_level" -ge 0 ]; then
        echo ""
        echo "🔍 Debug Level: System Status"
        echo "=============================="
        echo "Hostname: $(hostname)"
        echo "Uptime: $(uptime -p)"
        docker-compose ps
    fi
    
    # Level 1: Service health
    if [ "$target_level" -ge 1 ]; then
        echo ""
        echo "🔍 Debug Level: Service Health"
        echo "=============================="
        echo "Checking key services..."
    fi
    
    echo ""
    echo "✅ Debug commands completed"
}

export -f run_debug_commands