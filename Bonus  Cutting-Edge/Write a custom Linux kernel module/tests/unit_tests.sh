#!/bin/bash
#
# unit_tests.sh - Unit tests for SimpleChar kernel module
#
# This script contains unit tests for the SimpleChar kernel module,
# focusing on individual function testing and edge cases.
#

set -e

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODULE_NAME="simplechar"
DEVICE_FILE="/dev/$MODULE_NAME"

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
test_log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

# Test framework
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TOTAL_TESTS++))
    test_log "$test_name"
    
    if $test_function; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name"
        return 1
    fi
}

# Test prerequisites
test_module_loaded() {
    lsmod | grep -q "^$MODULE_NAME "
}

test_device_exists() {
    [[ -c "$DEVICE_FILE" ]]
}

test_device_permissions() {
    [[ -r "$DEVICE_FILE" && -w "$DEVICE_FILE" ]]
}

# Basic I/O tests
test_write_read_basic() {
    local test_data="Unit test data"
    echo "$test_data" > "$DEVICE_FILE"
    local result=$(cat "$DEVICE_FILE")
    [[ "$result" == "$test_data" ]]
}

test_write_empty() {
    echo -n "" > "$DEVICE_FILE"
    local result=$(cat "$DEVICE_FILE")
    [[ -z "$result" ]]
}

test_write_newline() {
    echo "" > "$DEVICE_FILE"
    local result=$(cat "$DEVICE_FILE")
    [[ "$result" == "" ]]
}

test_write_special_chars() {
    local test_data="Special chars: !@#$%^&*()_+-={}[]|\\:;\"'<>?,./"
    echo "$test_data" > "$DEVICE_FILE"
    local result=$(cat "$DEVICE_FILE")
    [[ "$result" == "$test_data" ]]
}

# Boundary tests
test_single_byte() {
    echo -n "A" > "$DEVICE_FILE"
    local result=$(cat "$DEVICE_FILE")
    [[ "$result" == "A" && ${#result} -eq 1 ]]
}

test_max_buffer_size() {
    # Create data close to buffer limit
    local test_data=$(printf "B%.0s" {1..1000})
    echo -n "$test_data" > "$DEVICE_FILE"
    local result=$(cat "$DEVICE_FILE")
    [[ ${#result} -eq 1000 ]]
}

test_oversize_write() {
    # Try to write more than buffer size
    local test_data=$(printf "C%.0s" {1..5000})
    echo -n "$test_data" > "$DEVICE_FILE" 2>/dev/null || true
    # Should not crash the system
    cat "$DEVICE_FILE" > /dev/null
    return 0  # Test passes if we get here without crash
}

# Concurrent access tests
test_multiple_writes() {
    local pids=()
    
    # Start multiple writers
    for i in {1..3}; do
        (
            for j in {1..5}; do
                echo "Writer $i - $j" > "$DEVICE_FILE"
                sleep 0.01
            done
        ) &
        pids+=($!)
    done
    
    # Wait for completion
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Should be able to read something
    cat "$DEVICE_FILE" > /dev/null
}

test_read_while_writing() {
    # Start a writer in background
    (
        for i in {1..10}; do
            echo "Background write $i" > "$DEVICE_FILE"
            sleep 0.1
        done
    ) &
    local writer_pid=$!
    
    # Read while writing
    for i in {1..5}; do
        cat "$DEVICE_FILE" > /dev/null
        sleep 0.05
    done
    
    # Wait for writer to complete
    wait $writer_pid
}

# Error condition tests
test_device_recovery() {
    # Write some data
    echo "Recovery test" > "$DEVICE_FILE"
    
    # Try invalid operations (should not crash)
    dd if="$DEVICE_FILE" of=/dev/null bs=1 count=0 2>/dev/null || true
    
    # Should still be able to read
    cat "$DEVICE_FILE" > /dev/null
}

# Performance tests
test_rapid_operations() {
    local start_time=$(date +%s.%N)
    
    for i in {1..50}; do
        echo "Rapid $i" > "$DEVICE_FILE"
        cat "$DEVICE_FILE" > /dev/null
    done
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
    
    # Test passes if completed within reasonable time (10 seconds)
    (( $(echo "$duration < 10" | bc -l 2>/dev/null || echo "1") ))
}

# Module parameter tests (if proc entry exists)
test_module_info() {
    local proc_file="/proc/$MODULE_NAME"
    
    if [[ -f "$proc_file" ]]; then
        # Should be able to read proc entry
        cat "$proc_file" > /dev/null
        
        # Should contain some expected information
        grep -q "Buffer Size" "$proc_file"
    else
        # If no proc entry, test still passes
        return 0
    fi
}

# Stress test
test_stress_operations() {
    local operations=100
    local data_sizes=(1 10 100 500 1000)
    
    for size in "${data_sizes[@]}"; do
        local test_data=$(printf "D%.0s" $(seq 1 $size))
        
        for i in $(seq 1 $operations); do
            echo -n "$test_data" > "$DEVICE_FILE" 2>/dev/null || true
            cat "$DEVICE_FILE" > /dev/null 2>/dev/null || true
        done
    done
    
    # Test passes if we complete without crashes
    return 0
}

# Test suite runner
run_test_suite() {
    echo "SimpleChar Module Unit Tests"
    echo "============================"
    echo
    
    # Prerequisites
    echo "Checking prerequisites..."
    run_test "Module is loaded" test_module_loaded
    run_test "Device file exists" test_device_exists
    run_test "Device permissions" test_device_permissions
    echo
    
    # Basic functionality
    echo "Basic functionality tests..."
    run_test "Write and read basic data" test_write_read_basic
    run_test "Write and read empty data" test_write_empty
    run_test "Write with newline" test_write_newline
    run_test "Write special characters" test_write_special_chars
    echo
    
    # Boundary tests
    echo "Boundary tests..."
    run_test "Single byte operation" test_single_byte
    run_test "Maximum buffer size" test_max_buffer_size
    run_test "Oversize write handling" test_oversize_write
    echo
    
    # Concurrent access
    echo "Concurrent access tests..."
    run_test "Multiple writers" test_multiple_writes
    run_test "Read while writing" test_read_while_writing
    echo
    
    # Error conditions
    echo "Error condition tests..."
    run_test "Device recovery" test_device_recovery
    echo
    
    # Performance
    echo "Performance tests..."
    run_test "Rapid operations" test_rapid_operations
    echo
    
    # Module information
    echo "Module information tests..."
    run_test "Module info access" test_module_info
    echo
    
    # Stress tests
    echo "Stress tests..."
    run_test "Stress operations" test_stress_operations
    echo
}

# Show results
show_test_results() {
    echo "Test Results"
    echo "============"
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Main function
main() {
    # Check if module is available
    if ! lsmod | grep -q "^$MODULE_NAME "; then
        echo -e "${RED}Error: Module $MODULE_NAME is not loaded${NC}"
        echo "Please load the module first: sudo simplechar-load"
        exit 1
    fi
    
    # Run tests
    run_test_suite
    
    # Show results
    if show_test_results; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"