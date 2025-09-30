# Infrastructure Platform Repository Structure

## Overview

This repository contains production-ready Kubernetes platform components using Helm charts and Kustomize overlays, designed for GitOps deployment with ArgoCD.

## Directory Structure

```
infrastructure-platform/
├── README.md                    # Main documentation and overview
├── INSTALLATION.md              # Detailed installation guide
├── STRUCTURE.md                 # This file - repository structure
├── Makefile                     # Helper commands for platform management
├── .gitignore                   # Git ignore patterns
│
├── scripts/                     # Installation and utility scripts
│   ├── install-platform.sh      # Automated platform installation script
│   └── get-argocd-password.sh   # Retrieve ArgoCD admin password
│
├── traefik/                     # Ingress controller (Wave 0)
│   ├── values.yaml              # Traefik Helm values (NodePort 30080/30443)
│   └── middleware.yaml          # Traefik middlewares (rate limit, auth, security)
│
├── cert-manager/                # TLS certificate management (Wave 1)
│   ├── values.yaml              # Cert-manager Helm values
│   └── cluster-issuer.yaml      # Let's Encrypt ClusterIssuers (staging/prod)
│
├── sealed-secrets/              # Encrypted secret management (Wave 1)
│   └── values.yaml              # Sealed Secrets Helm values
│
├── argocd/                      # GitOps continuous delivery (Wave 2)
│   ├── values.yaml              # ArgoCD Helm values (HA config, RBAC)
│   └── ingress.yaml             # ArgoCD IngressRoute and Certificate
│
├── monitoring/                  # Observability stack (Wave 3)
│   │
│   ├── prometheus/              # Metrics collection and alerting
│   │   ├── values.yaml          # Prometheus stack Helm values
│   │   ├── base/                # Base Kustomize configuration
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   └── servicemonitor.yaml
│   │   └── overlays/            # Environment-specific overlays
│   │       ├── dev/             # Development configuration
│   │       │   ├── kustomization.yaml
│   │       │   └── prometheus-patch.yaml
│   │       └── prod/            # Production configuration
│   │           ├── kustomization.yaml
│   │           ├── prometheus-patch.yaml
│   │           └── alertmanager-patch.yaml
│   │
│   ├── grafana/                 # Visualization and dashboards
│   │   ├── values.yaml          # Grafana Helm values
│   │   └── base/                # Base Kustomize configuration
│   │       ├── kustomization.yaml
│   │       └── ingress.yaml     # Grafana IngressRoute and Certificate
│   │
│   └── loki/                    # Log aggregation
│       └── values.yaml          # Loki stack Helm values (with Promtail)
│
├── velero/                      # Backup and disaster recovery (Wave 4)
│   ├── values.yaml              # Velero Helm values (AWS S3 config)
│   └── backup-schedules.yaml    # Scheduled backup definitions
│
└── argocd-apps/                 # ArgoCD Application definitions
    └── platform.yaml            # Application of Applications pattern

```

## Component Breakdown

### Core Platform (28 files)

1. **Documentation (3 files)**
   - README.md - Main overview and quick reference
   - INSTALLATION.md - Detailed installation guide
   - STRUCTURE.md - Repository structure documentation

2. **Build & Deploy (2 files)**
   - Makefile - Helper commands
   - .gitignore - Git ignore patterns

3. **Scripts (2 files)**
   - install-platform.sh - Automated installation
   - get-argocd-password.sh - ArgoCD password retrieval

4. **Traefik (2 files)**
   - values.yaml - NodePort configuration (30080/30443)
   - middleware.yaml - Rate limiting, security headers, CORS, auth

5. **Cert-Manager (2 files)**
   - values.yaml - Certificate management configuration
   - cluster-issuer.yaml - Let's Encrypt issuers (staging + prod)

6. **Sealed Secrets (1 file)**
   - values.yaml - Encrypted secret management

7. **ArgoCD (2 files)**
   - values.yaml - GitOps engine with HA and RBAC
   - ingress.yaml - IngressRoute and TLS certificate

8. **Prometheus (7 files)**
   - values.yaml - Main configuration
   - base/ - Base Kustomize setup (3 files)
   - overlays/dev/ - Development config (2 files)
   - overlays/prod/ - Production config (3 files)

9. **Grafana (3 files)**
   - values.yaml - Dashboard configuration
   - base/ - Base Kustomize with ingress (2 files)

10. **Loki (1 file)**
    - values.yaml - Log aggregation with Promtail

11. **Velero (2 files)**
    - values.yaml - Backup configuration
    - backup-schedules.yaml - Automated backup schedules

12. **ArgoCD Apps (1 file)**
    - platform.yaml - Application of Applications

## Installation Order (Sync Waves)

The platform components are installed in the following order to respect dependencies:

### Wave 0: Base Infrastructure
- **Traefik** - Ingress controller (NodePort 30080/30443)
  - Required by all ingress routes
  - Exposes services externally

### Wave 1: Security & Certificates
- **Cert-Manager** - TLS certificate management
  - Required for automatic HTTPS certificates
  - Uses Let's Encrypt HTTP-01 challenge

- **Sealed Secrets** - Encrypted secret management
  - Allows storing encrypted secrets in Git
  - Controller decrypts at runtime

### Wave 2: GitOps
- **ArgoCD** - Continuous delivery engine
  - Manages platform components via Git
  - Self-management capability
  - RBAC for team access

### Wave 3: Observability
- **Prometheus** - Metrics collection and alerting
  - Monitors all platform components
  - 30-day retention (production)
  - High availability mode

- **Grafana** - Visualization and dashboards
  - Pre-configured dashboards
  - Integrates with Prometheus and Loki
  - Custom dashboard support

- **Loki** - Log aggregation
  - Centralized logging via Promtail
  - 7-day retention
  - Integrates with Grafana

### Wave 4: Backup & DR
- **Velero** - Backup and disaster recovery
  - Daily full backups
  - Hourly critical namespace backups
  - Weekly platform backups
  - Monthly long-term backups

## Configuration Patterns

### Helm Values Files
Each component includes a well-commented `values.yaml` file with:
- Production-ready defaults
- Resource limits and requests
- Security contexts (non-root, read-only filesystem)
- High availability options
- Monitoring integration (Prometheus)

### Kustomize Overlays
Environment-specific configurations use Kustomize:
- **base/** - Common configuration
- **overlays/dev/** - Development (lower resources, faster iterations)
- **overlays/prod/** - Production (HA, extended retention)

### GitOps with ArgoCD
All components can be managed via ArgoCD:
- Automated sync policies
- Self-healing enabled
- Retry with exponential backoff
- Proper namespace creation

## Key Features

### Security
- Non-root containers
- Read-only root filesystems
- Capability dropping (drop ALL)
- Sealed secrets for sensitive data
- TLS everywhere (Let's Encrypt)
- RBAC policies

### High Availability
- Multiple replicas for critical components
- Pod anti-affinity rules
- Pod disruption budgets
- Rolling updates with zero downtime

### Observability
- Prometheus metrics from all components
- ServiceMonitors for auto-discovery
- Pre-configured Grafana dashboards
- Centralized logging with Loki
- Alertmanager integration

### Backup & Recovery
- Automated backup schedules
- Multiple retention policies
- Volume snapshot support
- Restic for file-level backups
- Easy restore procedures

## Customization Points

### Required Updates Before Deployment

1. **Domain names** (update in all files):
   - argocd.yourdomain.com
   - grafana.yourdomain.com
   - traefik.yourdomain.com
   - prometheus.yourdomain.com

2. **Email address** (cert-manager/cluster-issuer.yaml):
   - admin@yourdomain.com

3. **S3 backup storage** (velero/values.yaml):
   - Bucket name
   - Region
   - Credentials

4. **Git repository** (argocd-apps/platform.yaml):
   - Repository URL
   - Branch/tag

### Optional Customizations

1. **Storage classes** - Update in values.yaml files
2. **Resource limits** - Adjust based on cluster size
3. **Retention periods** - Modify backup/metric retention
4. **Replica counts** - Scale for HA requirements
5. **Monitoring endpoints** - Add custom ServiceMonitors

## Access Information

### Default Ports

- **Traefik HTTP**: NodePort 30080
- **Traefik HTTPS**: NodePort 30443
- **Prometheus**: ClusterIP port 9090
- **Grafana**: ClusterIP port 80
- **ArgoCD**: ClusterIP port 80
- **Loki**: ClusterIP port 3100

### Default Namespaces

- `traefik` - Ingress controller
- `argocd` - GitOps engine
- `cert-manager` - Certificate management
- `kube-system` - Sealed secrets controller
- `monitoring` - Prometheus, Grafana, Loki
- `velero` - Backup system

### Access Commands

```bash
# ArgoCD password
make argocd-password

# Grafana password
kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' | base64 -d

# Platform status
make status

# Install all components
make install

# Upgrade all components
make upgrade
```

## File Statistics

- **Total files**: 28
- **YAML configuration files**: 21
- **Shell scripts**: 2
- **Documentation**: 3
- **Build files**: 2

## Dependencies

### External Helm Repositories

- traefik.github.io/charts
- argoproj.github.io/argo-helm
- charts.jetstack.io
- bitnami-labs.github.io/sealed-secrets
- prometheus-community.github.io/helm-charts
- grafana.github.io/helm-charts
- vmware-tanzu.github.io/helm-charts

### Kubernetes Requirements

- Kubernetes 1.24+
- Storage class (for persistent volumes)
- Load balancer OR NodePort access
- DNS configuration capability

## Next Steps

1. Review [INSTALLATION.md](INSTALLATION.md) for deployment instructions
2. Update configuration files with your environment details
3. Run `make install` to deploy the platform
4. Configure DNS records for ingress endpoints
5. Access platform services and change default passwords
6. Deploy your applications using ArgoCD

---

For detailed information, see:
- [README.md](README.md) - Overview and usage
- [INSTALLATION.md](INSTALLATION.md) - Installation guide