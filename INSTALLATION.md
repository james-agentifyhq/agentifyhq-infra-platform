# Platform Installation Guide

This guide walks you through installing the complete infrastructure platform on your Kubernetes cluster.

## Prerequisites

### Required Tools

- Kubernetes cluster (1.24+) with kubectl access
- Helm 3.x installed
- Storage class available for persistent volumes
- Domain name with DNS control (for Let's Encrypt certificates)

### Optional Tools

- `kubeseal` CLI for creating sealed secrets
- ArgoCD CLI for managing applications
- Velero CLI for backup operations

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourorg/infrastructure-platform.git
cd infrastructure-platform
```

### 2. Update Configuration

Before installation, update the following files with your specific configuration:

#### Domain Names

Update all occurrences of `yourdomain.com` with your actual domain:

```bash
# Files to update:
- argocd/ingress.yaml
- traefik/middleware.yaml
- monitoring/grafana/base/ingress.yaml
- cert-manager/cluster-issuer.yaml
```

#### Let's Encrypt Email

Update the email address in `cert-manager/cluster-issuer.yaml`:

```yaml
email: admin@yourdomain.com  # Change this
```

#### Velero Backup Storage

Update the S3 bucket configuration in `velero/values.yaml`:

```yaml
configuration:
  backupStorageLocation:
    - name: default
      bucket: velero-backups  # Change to your bucket name
      config:
        region: us-east-1  # Change to your region
```

Create the Velero credentials secret:

```bash
kubectl create secret generic -n velero cloud-credentials \
  --from-literal=cloud='[default]
aws_access_key_id=YOUR_ACCESS_KEY
aws_secret_access_key=YOUR_SECRET_KEY'
```

### 3. Install Platform

Run the automated installation:

```bash
make install
```

This will:
1. Add all required Helm repositories
2. Install Traefik ingress controller
3. Install cert-manager for TLS
4. Install sealed-secrets for secret management
5. Install ArgoCD for GitOps
6. Install monitoring stack (Prometheus, Grafana, Loki)
7. Install Velero for backups

The installation takes approximately 10-15 minutes.

### 4. Verify Installation

Check the status of all components:

```bash
make status
```

You should see all pods running in their respective namespaces.

### 5. Access Platform Services

#### ArgoCD

Get the initial admin password:

```bash
make argocd-password
```

Access ArgoCD at `https://argocd.yourdomain.com`

**Important**: Change the password after first login:

```bash
argocd account update-password
```

#### Grafana

Get the Grafana admin password:

```bash
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo
```

Access Grafana at `https://grafana.yourdomain.com`

#### Traefik Dashboard

Access the Traefik dashboard at `https://traefik.yourdomain.com/dashboard/`

The dashboard is protected by basic authentication. Default credentials are in `traefik/middleware.yaml` (change these!).

## Post-Installation Configuration

### 1. DNS Configuration

Configure DNS A records pointing to your cluster's external IP:

```
argocd.yourdomain.com     -> CLUSTER_IP
grafana.yourdomain.com    -> CLUSTER_IP
traefik.yourdomain.com    -> CLUSTER_IP
prometheus.yourdomain.com -> CLUSTER_IP
```

For NodePort setup (bare-metal), point DNS to any node IP. Traefik is accessible on:
- HTTP: Port 30080
- HTTPS: Port 30443

### 2. TLS Certificates

Certificates are automatically issued by cert-manager using Let's Encrypt.

To check certificate status:

```bash
kubectl get certificates -A
kubectl get certificaterequests -A
```

For testing, use the staging issuer first:

```yaml
issuerRef:
  name: letsencrypt-staging  # Change to letsencrypt-prod when ready
  kind: ClusterIssuer
```

### 3. Sealed Secrets Setup

Install the kubeseal CLI:

```bash
# macOS
brew install kubeseal

# Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/kubeseal-0.24.5-linux-amd64.tar.gz
tar xfz kubeseal-0.24.5-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

Create a sealed secret:

```bash
# Create a regular secret
kubectl create secret generic mysecret --dry-run=client -n default \
  --from-literal=password=mypassword -o yaml > secret.yaml

# Seal the secret
kubeseal -f secret.yaml -w sealedsecret.yaml

# Apply the sealed secret
kubectl apply -f sealedsecret.yaml

# Clean up the unencrypted secret
rm secret.yaml
```

### 4. Backup Configuration

Verify Velero is working:

```bash
# Check backup storage location
velero backup-location get

# Create a test backup
velero backup create test-backup --include-namespaces default

# Check backup status
velero backup describe test-backup

# List all backups
velero backup get
```

Scheduled backups are configured in `velero/backup-schedules.yaml`.

### 5. Monitoring Configuration

#### Add Custom Dashboards

Upload custom Grafana dashboards:

1. Go to Grafana UI
2. Click "+" → "Import"
3. Enter dashboard ID from https://grafana.com/grafana/dashboards/
4. Select Prometheus data source

Recommended dashboards:
- **7249**: Kubernetes Cluster Monitoring
- **1860**: Node Exporter Full
- **17346**: Traefik Official
- **12006**: Kubernetes API Server

#### Configure Alertmanager

Edit Prometheus Alertmanager configuration:

```bash
kubectl edit secret -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager
```

Add Slack, email, or webhook receivers for alerts.

### 6. ArgoCD GitOps Setup

To manage platform via GitOps:

```bash
# Apply the platform Application of Applications
kubectl apply -f argocd-apps/platform.yaml
```

This configures ArgoCD to manage all platform components from Git.

**Important**: Update the repository URL in `argocd-apps/platform.yaml`:

```yaml
source:
  repoURL: https://github.com/yourorg/infrastructure-platform.git
  targetRevision: main
```

## Environment-Specific Configuration

### Development Environment

Use Kustomize overlays for dev-specific configuration:

```bash
kubectl apply -k monitoring/prometheus/overlays/dev
```

Development settings:
- Lower resource limits
- Shorter retention periods
- Single replicas (no HA)

### Production Environment

Use production overlays:

```bash
kubectl apply -k monitoring/prometheus/overlays/prod
```

Production settings:
- Higher resource limits
- Extended retention (30 days)
- High availability (multiple replicas)
- Pod anti-affinity rules

## Troubleshooting

### Common Issues

#### 1. Certificates Not Issuing

Check cert-manager logs:

```bash
kubectl logs -n cert-manager -l app=cert-manager -f
```

Verify DNS is resolving correctly:

```bash
nslookup argocd.yourdomain.com
```

Check certificate status:

```bash
kubectl describe certificate -n argocd argocd-server-tls
```

#### 2. Traefik Not Routing

Check Traefik logs:

```bash
kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f
```

Verify IngressRoute configuration:

```bash
kubectl get ingressroute -A
```

#### 3. ArgoCD Applications Out of Sync

Check application status:

```bash
kubectl get application -n argocd
```

View sync failures:

```bash
argocd app get <app-name>
```

Force sync:

```bash
argocd app sync <app-name> --force
```

#### 4. Prometheus Not Scraping Targets

Check ServiceMonitor configuration:

```bash
kubectl get servicemonitor -n monitoring
```

View Prometheus targets:

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets
```

#### 5. Velero Backups Failing

Check Velero logs:

```bash
kubectl logs -n velero -l app.kubernetes.io/name=velero -f
```

Verify storage location:

```bash
velero backup-location get
```

Test credentials:

```bash
velero backup create test-backup --include-namespaces default
velero backup describe test-backup
```

## Maintenance

### Upgrading Components

Upgrade all platform components:

```bash
make upgrade
```

Or upgrade individual components:

```bash
helm upgrade traefik traefik/traefik -n traefik -f traefik/values.yaml
```

### Backup and Restore

#### Create Manual Backup

```bash
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S)
```

#### Restore from Backup

```bash
# List available backups
velero backup get

# Restore entire cluster
velero restore create --from-backup <backup-name>

# Restore specific namespace
velero restore create --from-backup <backup-name> \
  --include-namespaces production
```

### Monitoring Health

Check platform component health:

```bash
# Overall status
make status

# Detailed pod status
kubectl get pods -A | grep -v Running

# Check events
kubectl get events -A --sort-by='.lastTimestamp'
```

## Security Best Practices

1. **Change Default Passwords**: Update all default passwords in `traefik/middleware.yaml`
2. **Enable RBAC**: Configure ArgoCD RBAC policies for your team
3. **Rotate Secrets**: Regularly rotate sealed secrets encryption keys
4. **Update Images**: Keep all container images up to date
5. **Network Policies**: Apply network policies to restrict pod communication
6. **Audit Logs**: Enable Kubernetes audit logging
7. **Backup Encryption**: Enable encryption for Velero backups

## Uninstallation

To remove all platform components:

```bash
make uninstall
```

**Warning**: This will delete all platform components and their data. Ensure you have backups before proceeding.

## Support

For issues and questions:
- Check the [README.md](README.md) for general information
- Review component-specific documentation in each directory
- Check logs using `kubectl logs` commands above
- Consult upstream documentation for specific components

## Next Steps

1. ✅ Install platform components
2. ✅ Configure DNS and TLS certificates
3. ✅ Set up GitOps with ArgoCD
4. ✅ Configure monitoring and alerting
5. ✅ Test backup and restore procedures
6. 📋 Deploy your applications to the platform
7. 📋 Set up CI/CD pipelines
8. 📋 Configure monitoring dashboards
9. 📋 Document runbooks for common operations

---

For more information, see the [README.md](README.md).