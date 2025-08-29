#!/bin/bash

set -e

NAMESPACE="blue-green-demo"

echo "Performing Blue-Green rollback..."

# Get current and previous versions
CURRENT_VERSION=$(kubectl get service k8s-app-main -n $NAMESPACE -o jsonpath='{.spec.selector.version}')
PREVIOUS_VERSION=$(kubectl get service k8s-app-main -n $NAMESPACE -o jsonpath='{.metadata.annotations.blue-green\.deployment/previous-version}')

if [[ -z "$PREVIOUS_VERSION" ]]; then
    echo "Error: No previous version found in service annotations"
    echo "Current version: $CURRENT_VERSION"
    exit 1
fi

echo "Rolling back from $CURRENT_VERSION to $PREVIOUS_VERSION..."

# Verify previous version deployment is still ready
READY_REPLICAS=$(kubectl get deployment k8s-app-$PREVIOUS_VERSION -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment k8s-app-$PREVIOUS_VERSION -n $NAMESPACE -o jsonpath='{.spec.replicas}')

if [[ "$READY_REPLICAS" != "$DESIRED_REPLICAS" ]]; then
    echo "Error: Previous version ($PREVIOUS_VERSION) is not ready for rollback"
    echo "Ready: $READY_REPLICAS, Desired: $DESIRED_REPLICAS"
    exit 1
fi

# Run health check on previous version
echo "Running health check on previous version ($PREVIOUS_VERSION)..."
./scripts/health-check.sh $PREVIOUS_VERSION

# Switch traffic back to previous version
kubectl patch service k8s-app-main -n $NAMESPACE -p \
    '{"spec":{"selector":{"version":"'$PREVIOUS_VERSION'"}}}'

# Update ingress
kubectl patch ingress k8s-app-ingress -n $NAMESPACE -p \
    '{"spec":{"rules":[{"host":"blue-green-demo.example.com","http":{"paths":[{"path":"/","pathType":"Prefix","backend":{"service":{"name":"k8s-app-'$PREVIOUS_VERSION'","port":{"number":80}}}}]}}]}}'

# Update annotations
ROLLBACK_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
kubectl annotate service k8s-app-main -n $NAMESPACE \
    blue-green.deployment/active-version=$PREVIOUS_VERSION \
    blue-green.deployment/last-switch="$ROLLBACK_TIME" \
    blue-green.deployment/previous-version="$CURRENT_VERSION" \
    blue-green.deployment/rollback-performed="true" \
    --overwrite

echo "Rollback completed!"
echo "Traffic switched back to $PREVIOUS_VERSION version"

# Verify rollback
sleep 5
ACTIVE_VERSION=$(kubectl get service k8s-app-main -n $NAMESPACE -o jsonpath='{.spec.selector.version}')
echo "Current active version: $ACTIVE_VERSION"

# Run post-rollback health check
./scripts/health-check.sh $ACTIVE_VERSION
