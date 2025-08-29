# Blue-Green Deployment Troubleshooting

## Common Issues

### Deployment Fails
```bash
# Check pod status
kubectl get pods -n blue-green-demo

# Check pod logs
kubectl logs -l app=k8s-app,version=green -n blue-green-demo

# Check events
kubectl get events -n blue-green-demo --sort-by=.lastTimestamp
```

### Health Checks Fail
```bash
# Manual health check
./scripts/health-check.sh green

# Check service endpoints
kubectl get endpoints -n blue-green-demo

# Test connectivity
kubectl run debug --rm -i --restart=Never --image=curlimages/curl -- curl -v http://k8s-app-green/health
```

### Traffic Not Switching
```bash
# Check service selector
kubectl get svc k8s-app-main -n blue-green-demo -o yaml

# Check ingress configuration
kubectl get ingress -n blue-green-demo -o yaml

# Verify service annotations
kubectl describe svc k8s-app-main -n blue-green-demo
```

## Emergency Procedures

### Immediate Rollback
```bash
./scripts/rollback.sh
```

### Manual Traffic Switch
```bash
kubectl patch service k8s-app-main -n blue-green-demo -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Scale Down Failed Version
```bash
kubectl scale deployment k8s-app-green --replicas=0 -n blue-green-demo
```
