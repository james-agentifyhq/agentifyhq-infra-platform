# Infrastructure Platform

This repository contains the core platform components for the Kubernetes infrastructure, deployed using Helm and Kustomize with ArgoCD GitOps workflows.

## Overview

The platform provides essential infrastructure services that applications depend on:

- **Traefik**: Ingress controller and reverse proxy
- **ArgoCD**: GitOps continuous delivery
- **Cert-Manager**: Automatic TLS certificate management
- **Sealed Secrets**: Encrypted secret management
- **Monitoring Stack**: Prometheus, Grafana, and Loki
- **Velero**: Backup and disaster recovery

## Architecture

```
Platform Components
├── Traefik (NodePort 30080/30443)
│   └── Ingress Controller
├── ArgoCD
│   └── GitOps Engine
├── Cert-Manager
│   └── Let's Encrypt Integration
├── Sealed Secrets
│   └── Secret Encryption
├── Monitoring
│   ├── Prometheus (Metrics)
│   ├── Grafana (Dashboards)
│   └── Loki (Logs)
└── Velero
    └── Backup & DR
```

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Helm 3.x installed
- Storage class available (for persistent volumes)

## Quick Start

### Install All Platform Components

```bash
make install
```

This will install all components in the correct dependency order.

### Install Individual Components

```bash
# Install Traefik
helm upgrade --install traefik traefik/traefik \
  -n traefik --create-namespace \
  -f traefik/values.yaml

# Install ArgoCD
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f argocd/values.yaml

# Install Cert-Manager
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  -f cert-manager/values.yaml

# Install Sealed Secrets
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  -n kube-system \
  -f sealed-secrets/values.yaml

# Install Prometheus
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/prometheus/values.yaml

# Install Grafana
helm upgrade --install grafana grafana/grafana \
  -n monitoring --create-namespace \
  -f monitoring/grafana/values.yaml

# Install Loki
helm upgrade --install loki grafana/loki-stack \
  -n monitoring --create-namespace \
  -f monitoring/loki/values.yaml

# Install Velero
helm upgrade --install velero vmware-tanzu/velero \
  -n velero --create-namespace \
  -f velero/values.yaml
```

## Access Platform Services

### ArgoCD

Get the initial admin password:

```bash
make argocd-password
# or
./scripts/get-argocd-password.sh
```

Access the UI:
- URL: https://argocd.yourdomain.com
- Username: admin
- Password: (from above command)

### Traefik Dashboard

Access the Traefik dashboard:
- URL: http://traefik.yourdomain.com/dashboard/

### Grafana

Get the Grafana admin password:

```bash
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

Access the UI:
- URL: https://grafana.yourdomain.com
- Username: admin
- Password: (from above command)

### Prometheus

Access Prometheus:
- URL: https://prometheus.yourdomain.com

## Configuration

### Traefik

Traefik is configured with NodePort service on ports 30080 (HTTP) and 30443 (HTTPS). This allows direct access to the cluster from external load balancers.

Key features:
- NodePort for bare-metal compatibility
- Rate limiting middleware
- TLS termination
- Let's Encrypt integration

### ArgoCD

ArgoCD is configured for GitOps deployments with:
- SSO integration ready
- RBAC policies
- Automated sync policies
- Health checks

### Cert-Manager

Cert-Manager handles TLS certificates with:
- Let's Encrypt ClusterIssuer (staging and production)
- Automatic certificate renewal
- DNS-01 and HTTP-01 challenge support

### Monitoring

The monitoring stack includes:
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation and querying

Kustomize overlays provide environment-specific configurations:
- `dev`: Lower retention, fewer resources
- `prod`: High availability, extended retention

## Backup and Disaster Recovery

Velero provides backup capabilities:

```bash
# Create a manual backup
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S)

# List backups
velero backup get

# Restore from backup
velero restore create --from-backup <backup-name>
```

Automated daily backups are configured in `velero/backup-schedules.yaml`.

## GitOps with ArgoCD

The `argocd-apps/platform.yaml` defines an "Application of Applications" pattern, allowing ArgoCD to manage all platform components.

Deploy the platform via ArgoCD:

```bash
kubectl apply -f argocd-apps/platform.yaml
```

## Customization

### Environment-Specific Values

Use Kustomize overlays for environment-specific configurations:

```bash
# Apply dev configuration
kubectl apply -k monitoring/prometheus/overlays/dev

# Apply prod configuration
kubectl apply -k monitoring/prometheus/overlays/prod
```

### Helm Values

Override default values by editing the respective `values.yaml` files in each component directory.

## Makefile Commands

```bash
make install              # Install all platform components
make uninstall           # Uninstall all platform components
make upgrade             # Upgrade all platform components
make status              # Check status of all components
make argocd-password     # Get ArgoCD admin password
make add-repos           # Add required Helm repositories
```

## Troubleshooting

### Check Platform Component Status

```bash
make status
```

### View Logs

```bash
# Traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik

# ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Cert-Manager
kubectl logs -n cert-manager -l app=cert-manager
```

### Common Issues

1. **Certificates not being issued**: Check cert-manager logs and ensure DNS is configured correctly
2. **ArgoCD sync issues**: Verify git repository access and credentials
3. **Traefik not routing**: Check IngressRoute definitions and middleware configuration

## Security Considerations

- All secrets are managed via Sealed Secrets
- TLS certificates are automatically managed by cert-manager
- RBAC policies are enforced across all components
- Network policies should be applied in production
- Regular backups are scheduled via Velero

## Maintenance

### Upgrading Components

```bash
# Update Helm repos
helm repo update

# Upgrade individual component
helm upgrade <release> <chart> -n <namespace> -f <values.yaml>

# Or upgrade all
make upgrade
```

### Monitoring Health

- Use ArgoCD UI to monitor sync status
- Check Prometheus alerts for issues
- Review Grafana dashboards for metrics
- Query Loki for application logs

## Contributing

When adding new platform components:

1. Create a directory for the component
2. Add Helm values.yaml or Kustomize configuration
3. Update the installation script with proper ordering
4. Add ArgoCD Application definition
5. Update this README

## License

MIT