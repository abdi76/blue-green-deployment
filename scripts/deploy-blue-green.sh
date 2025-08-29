#!/bin/bash

set -e

VERSION=${1:-green}
IMAGE_TAG=${2:-latest}
NAMESPACE="blue-green-demo"

if [[ "$VERSION" != "blue" && "$VERSION" != "green" ]]; then
    echo "Error: Version must be 'blue' or 'green'"
    exit 1
fi

echo "Deploying $VERSION version with image tag: $IMAGE_TAG"

# Update image tag in deployment
DEPLOYMENT_FILE="applications/k8s-app/$VERSION/deployment.yaml"
sed -i.bak "s|image: .*|image: your-dockerhub-username/k8s-cicd-app:$IMAGE_TAG|g" $DEPLOYMENT_FILE

# Update timestamp annotation for rolling update
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
sed -i.bak "s|deployment.timestamp: \".*\"|deployment.timestamp: \"$TIMESTAMP\"|g" $DEPLOYMENT_FILE

# Apply the deployment
kubectl apply -f $DEPLOYMENT_FILE

# Wait for rollout to complete
echo "Waiting for $VERSION deployment to complete..."
kubectl rollout status deployment/k8s-app-$VERSION -n $NAMESPACE --timeout=300s

# Verify deployment
READY_REPLICAS=$(kubectl get deployment k8s-app-$VERSION -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment k8s-app-$VERSION -n $NAMESPACE -o jsonpath='{.spec.replicas}')

if [[ "$READY_REPLICAS" == "$DESIRED_REPLICAS" ]]; then
    echo "$VERSION deployment completed successfully!"
    echo "Ready replicas: $READY_REPLICAS/$DESIRED_REPLICAS"
else
    echo "Warning: Not all replicas are ready. Ready: $READY_REPLICAS, Desired: $DESIRED_REPLICAS"
    exit 1
fi

# Run health check
echo "Running health check on $VERSION deployment..."
./scripts/health-check.sh $VERSION

echo "Deployment completed! $VERSION version is ready."
echo "Run './scripts/switch-traffic.sh $VERSION' to switch traffic to this version."
