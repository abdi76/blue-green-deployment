# Blue-Green Deployment Implementation

A complete Blue-Green deployment solution for Kubernetes with automation, monitoring, and comprehensive testing.

## Features

- **Zero Downtime Deployments**: Instant traffic switching between versions
- **Automated Health Checks**: Comprehensive validation before traffic switch
- **Easy Rollback**: Quick revert to previous version with one command
- **Monitoring Integration**: Prometheus alerts and metrics
- **Production Ready**: Security contexts, resource limits, and best practices

## Quick Start

1. **Setup Environment**:
   ```bash
   ./scripts/setup-blue-green.sh
   ```

2. **Deploy New Version**:
   ```bash
   ./scripts/deploy-blue-green.sh green v2.0.0
   ```

3. **Run Tests**:
   ```bash
   ./tests/smoke-tests.sh green
   ```

4. **Switch Traffic**:
   ```bash
   ./scripts/switch-traffic.sh green
   ```

## Architecture

```
Internet → Ingress → Main Service → Blue/Green Services → Pods
```

## Scripts

- `setup-blue-green.sh`: Initial environment setup
- `deploy-blue-green.sh`: Deploy to specific version (blue/green)
- `switch-traffic.sh`: Switch traffic between versions
- `health-check.sh`: Validate deployment health
- `rollback.sh`: Rollback to previous version

## Monitoring

- Prometheus alerts for error rates and latency
- Health check endpoints for automated validation
- Deployment metrics and tracking

## Documentation

- [Blue-Green Guide](docs/BLUE-GREEN-GUIDE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## License

MIT License
