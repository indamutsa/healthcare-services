#!/bin/bash

run_debug_commands() {
    local target_level=$1
    echo "Debug Level: $target_level"
    echo "Test successful"
}

export -f run_debug_commands