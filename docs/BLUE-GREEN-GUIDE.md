# Blue-Green Deployment Guide

## Overview

Blue-Green deployment is a technique that reduces downtime and risk by running two identical production environments called Blue and Green. At any time, only one of the environments is live, with the other serving as a staging environment.

## Benefits

1. **Zero Downtime**: Instant cutover between versions
2. **Easy Rollback**: Quick revert to previous version
3. **Risk Reduction**: Test in production-like environment
4. **Performance Testing**: Load test new version before switch

## Deployment Process

### 1. Initial Setup
```bash
./scripts/setup-blue-green.sh
```

### 2. Deploy New Version
```bash
./scripts/deploy-blue-green.sh green v2.0.0
```

### 3. Run Tests
```bash
./tests/smoke-tests.sh green
```

### 4. Switch Traffic
```bash
./scripts/switch-traffic.sh green
```

### 5. Rollback if Needed
```bash
./scripts/rollback.sh
```

## Best Practices

- Always run health checks before switching traffic
- Monitor both versions during the switch
- Keep the previous version running for quick rollback
- Use automation to reduce human error
- Test rollback procedures regularly

## Monitoring

- Health check endpoints: `/health`
- Version information: `/`
- Metrics: `/metrics`
- Application status: Prometheus alerts
