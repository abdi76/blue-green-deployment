#!/bin/bash

set -e

NAMESPACE="blue-green-demo"
DOCKERHUB_USERNAME="your-dockerhub-username"

echo "Setting up Blue-Green deployment environment..."

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Apply shared resources
kubectl apply -f applications/k8s-app/shared/

# Deploy blue version first
echo "Deploying blue version..."
kubectl apply -f applications/k8s-app/blue/

# Wait for blue deployment to be ready
echo "Waiting for blue deployment to be ready..."
kubectl rollout status deployment/k8s-app-blue -n $NAMESPACE --timeout=300s

# Deploy green version (initially not receiving traffic)
echo "Deploying green version..."
kubectl apply -f applications/k8s-app/green/

# Wait for green deployment to be ready
echo "Waiting for green deployment to be ready..."
kubectl rollout status deployment/k8s-app-green -n $NAMESPACE --timeout=300s

# Verify deployments
echo "Verifying deployments..."
kubectl get pods -n $NAMESPACE -l app=k8s-app
kubectl get svc -n $NAMESPACE

# Check which version is active
ACTIVE_VERSION=$(kubectl get service k8s-app-main -n $NAMESPACE -o jsonpath='{.spec.selector.version}')
echo "Active version: $ACTIVE_VERSION"

echo "Blue-Green setup completed!"
echo "Access the application at: http://blue-green-demo.example.com"
echo "Use ./scripts/switch-traffic.sh to switch between versions"
