#!/bin/bash

set -e

VERSION=${1:-blue}
NAMESPACE="blue-green-demo"
TEST_DURATION=60
CONCURRENT_REQUESTS=5

echo "Running smoke tests for $VERSION version..."

# Get service endpoint
SERVICE_NAME="k8s-app-$VERSION"
SERVICE_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')

if [[ -z "$SERVICE_IP" ]]; then
    echo "Error: Could not get service IP for $SERVICE_NAME"
    exit 1
fi

# Test function
run_test() {
    local test_name=$1
    local endpoint=$2
    local expected_status=$3
    local max_retries=${4:-3}
    
    echo "Running test: $test_name"
    
    for ((i=1; i<=max_retries; i++)); do
        if kubectl run smoke-test-$VERSION-$i --rm -i --restart=Never --image=curlimages/curl -- \
           curl -f -s -w "%{http_code}" -m 10 "http://$SERVICE_IP$endpoint" | grep -q "$expected_status"; then
            echo "✅ $test_name: PASSED"
            return 0
        else
            echo "❌ $test_name: FAILED (attempt $i/$max_retries)"
            if [[ $i -lt $max_retries ]]; then
                sleep 5
            fi
        fi
    done
    
    echo "❌ $test_name: FAILED after $max_retries attempts"
    return 1
}

# Run individual tests
FAILED_TESTS=0

# Basic health check
if ! run_test "Health Check" "/health" "200"; then
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Version check
if ! run_test "Version Check" "/" "200"; then
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Metrics endpoint
if ! run_test "Metrics Check" "/metrics" "200"; then
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# API endpoint
if ! run_test "API Check" "/api/users" "200"; then
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Summary
echo ""
echo "Smoke test summary for $VERSION version:"
echo "Failed tests: $FAILED_TESTS"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "✅ All smoke tests PASSED"
    exit 0
else
    echo "❌ Some smoke tests FAILED"
    exit 1
fi
