#!/bin/bash

set -e

VERSION=${1:-blue}
NAMESPACE="blue-green-demo"
MAX_RETRIES=10
RETRY_INTERVAL=5

echo "Running health check for $VERSION version..."

# Check if deployment exists and is ready
if ! kubectl get deployment k8s-app-$VERSION -n $NAMESPACE &>/dev/null; then
    echo "Error: Deployment k8s-app-$VERSION not found"
    exit 1
fi

# Wait for deployment to be ready
echo "Waiting for deployment k8s-app-$VERSION to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/k8s-app-$VERSION -n $NAMESPACE

# Get service endpoint
SERVICE_NAME="k8s-app-$VERSION"
SERVICE_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')

if [[ -z "$SERVICE_IP" ]]; then
    echo "Error: Could not get service IP for $SERVICE_NAME"
    exit 1
fi

# Health check function
health_check() {
    local endpoint=$1
    echo "Checking $endpoint endpoint..."
    
    for ((i=1; i<=MAX_RETRIES; i++)); do
        if kubectl run health-check-$VERSION-$i --rm -i --restart=Never --image=curlimages/curl -- \
           curl -f -s -m 10 "http://$SERVICE_IP$endpoint" >/dev/null 2>&1; then
            echo "$endpoint endpoint: HEALTHY"
            return 0
        else
            echo "$endpoint endpoint: UNHEALTHY (attempt $i/$MAX_RETRIES)"
            if [[ $i -lt $MAX_RETRIES ]]; then
                sleep $RETRY_INTERVAL
            fi
        fi
    done
    
    echo "$endpoint endpoint: FAILED after $MAX_RETRIES attempts"
    return 1
}

# Run health checks
HEALTH_FAILED=0

# Basic health check
if ! health_check "/health"; then
    HEALTH_FAILED=1
fi

# Version-specific check
echo "Checking version endpoint..."
VERSION_RESPONSE=$(kubectl run version-check-$VERSION --rm -i --restart=Never --image=curlimages/curl -- \
    curl -f -s -m 10 "http://$SERVICE_IP/" 2>/dev/null || echo "FAILED")

if [[ "$VERSION_RESPONSE" == *"$VERSION"* ]]; then
    echo "Version endpoint: HEALTHY (returned $VERSION version info)"
else
    echo "Version endpoint: FAILED (expected $VERSION version info)"
    HEALTH_FAILED=1
fi

# Check pod status
echo "Checking pod status..."
READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=k8s-app,version=$VERSION -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' | grep Running | wc -l)
TOTAL_PODS=$(kubectl get pods -n $NAMESPACE -l app=k8s-app,version=$VERSION --no-headers | wc -l)

echo "Pod status: $READY_PODS/$TOTAL_PODS pods running"

if [[ $READY_PODS -eq $TOTAL_PODS && $TOTAL_PODS -gt 0 ]]; then
    echo "Pod status: HEALTHY"
else
    echo "Pod status: UNHEALTHY"
    HEALTH_FAILED=1
fi

if [[ $HEALTH_FAILED -eq 0 ]]; then
    echo "Health check PASSED for $VERSION version"
    exit 0
else
    echo "Health check FAILED for $VERSION version"
    exit 1
fi
