#!/bin/bash

set -e

TARGET_VERSION=${1}
NAMESPACE="blue-green-demo"
SWITCH_DELAY=${2:-30}

if [[ "$TARGET_VERSION" != "blue" && "$TARGET_VERSION" != "green" ]]; then
    echo "Error: Target version must be 'blue' or 'green'"
    exit 1
fi

# Get current active version
CURRENT_VERSION=$(kubectl get service k8s-app-main -n $NAMESPACE -o jsonpath='{.spec.selector.version}')
echo "Current active version: $CURRENT_VERSION"

if [[ "$CURRENT_VERSION" == "$TARGET_VERSION" ]]; then
    echo "Traffic is already pointing to $TARGET_VERSION version"
    exit 0
fi

echo "Switching traffic from $CURRENT_VERSION to $TARGET_VERSION..."

# Verify target deployment is ready
echo "Verifying $TARGET_VERSION deployment is ready..."
READY_REPLICAS=$(kubectl get deployment k8s-app-$TARGET_VERSION -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment k8s-app-$TARGET_VERSION -n $NAMESPACE -o jsonpath='{.spec.replicas}')

if [[ "$READY_REPLICAS" != "$DESIRED_REPLICAS" ]]; then
    echo "Error: $TARGET_VERSION deployment is not ready. Ready: $READY_REPLICAS, Desired: $DESIRED_REPLICAS"
    exit 1
fi

# Run pre-switch health check
echo "Running pre-switch health check on $TARGET_VERSION..."
./scripts/health-check.sh $TARGET_VERSION

# Wait for switch delay
if [[ $SWITCH_DELAY -gt 0 ]]; then
    echo "Waiting ${SWITCH_DELAY} seconds before switching traffic..."
    sleep $SWITCH_DELAY
fi

# Create backup of current service configuration
kubectl get service k8s-app-main -n $NAMESPACE -o yaml > /tmp/k8s-app-main-backup.yaml

# Switch traffic by updating service selector
echo "Switching traffic to $TARGET_VERSION..."
kubectl patch service k8s-app-main -n $NAMESPACE -p \
    '{"spec":{"selector":{"version":"'$TARGET_VERSION'"}}}'

# Update ingress to point to new service
kubectl patch ingress k8s-app-ingress -n $NAMESPACE -p \
    '{"spec":{"rules":[{"host":"blue-green-demo.example.com","http":{"paths":[{"path":"/","pathType":"Prefix","backend":{"service":{"name":"k8s-app-'$TARGET_VERSION'","port":{"number":80}}}}]}}]}}'

# Update service annotations
SWITCH_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
kubectl annotate service k8s-app-main -n $NAMESPACE \
    blue-green.deployment/active-version=$TARGET_VERSION \
    blue-green.deployment/last-switch="$SWITCH_TIME" \
    blue-green.deployment/previous-version="$CURRENT_VERSION" \
    --overwrite

echo "Traffic switched to $TARGET_VERSION version!"

# Run post-switch validation
echo "Running post-switch validation..."
sleep 10

# Verify switch was successful
ACTIVE_VERSION=$(kubectl get service k8s-app-main -n $NAMESPACE -o jsonpath='{.spec.selector.version}')
if [[ "$ACTIVE_VERSION" == "$TARGET_VERSION" ]]; then
    echo "Traffic switch successful! Active version: $ACTIVE_VERSION"
else
    echo "Traffic switch failed! Expected: $TARGET_VERSION, Actual: $ACTIVE_VERSION"
    echo "Rolling back..."
    kubectl apply -f /tmp/k8s-app-main-backup.yaml
    exit 1
fi

# Run post-switch health check
./scripts/health-check.sh $TARGET_VERSION

echo "Blue-Green deployment completed successfully!"
echo "Previous version ($CURRENT_VERSION) is still running and can be used for quick rollback."
echo "To rollback, run: ./scripts/rollback.sh"
