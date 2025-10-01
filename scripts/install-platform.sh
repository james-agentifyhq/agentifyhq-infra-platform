#!/bin/bash

set -e

echo "=================================="
echo "Platform Installation Script"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}

    print_info "Waiting for deployment $deployment in namespace $namespace to be ready..."
    kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}

    print_info "Waiting for pods with label $label in namespace $namespace to be ready..."
    kubectl wait --for=condition=ready --timeout=${timeout}s pod -l $label -n $namespace
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm not found. Please install helm first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_info "Connected to Kubernetes cluster"
kubectl cluster-info | head -n 1

echo ""
echo "=================================="
echo "Step 1: Installing Traefik"
echo "=================================="
print_info "Traefik is the ingress controller for the platform"

kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f - 

helm upgrade --install traefik traefik/traefik \
    --namespace traefik \
    --create-namespace \
    --values traefik/values.yaml \
    --wait \
    --timeout 5m

print_info "Waiting for Traefik CRDs to be established..."
kubectl wait --for condition=established --timeout=60s crd/middlewares.traefik.io crd/ingressroutes.traefik.io
sleep 5 # Additional brief sleep to ensure propagation

# Apply middleware
kubectl apply -f traefik/middleware.yaml

print_info "Traefik installed successfully!"
kubectl get svc -n traefik traefik

echo ""
echo "=================================="
echo "Step 2: Installing Monitoring Stack"
echo "=================================="
print_info "Installing Prometheus, Grafana, and Loki for monitoring and logging"

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - 

# Install Prometheus
print_info "Installing Prometheus..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --values monitoring/prometheus/values.yaml \
    --wait \
    --timeout 10m

# Apply Prometheus IngressRoute
print_info "Creating Prometheus IngressRoute..."
kubectl apply -f monitoring/prometheus/ingress.yaml

# Install Grafana
print_info "Installing Grafana..."
helm upgrade --install grafana grafana/grafana \
    --namespace monitoring \
    --create-namespace \
    --values monitoring/grafana/values.yaml \
    --wait \
    --timeout 5m

# Apply Grafana IngressRoute
print_info "Creating Grafana IngressRoute..."
kubectl apply -f monitoring/grafana/base/ingress.yaml

# Install Loki
print_info "Installing Loki..."
helm upgrade --install loki grafana/loki-stack \
    --namespace monitoring \
    --create-namespace \
    --values monitoring/loki/values.yaml \
    --wait \
    --timeout 5m

print_info "Monitoring stack installed successfully!"

echo ""
echo "=================================="
echo "Step 3: Installing Cert-Manager"
echo "=================================="
print_info "Cert-Manager handles TLS certificate management"

kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f - 

helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --values cert-manager/values.yaml \
    --wait \
    --timeout 5m

# Wait for cert-manager to be ready before creating issuers
print_info "Waiting for cert-manager webhook to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager

# Apply cluster issuers
print_info "Creating ClusterIssuers..."
kubectl apply -f cert-manager/cluster-issuer.yaml

print_info "Cert-Manager installed successfully!"

echo ""
echo "=================================="
echo "Step 4: Installing Sealed Secrets"
echo "=================================="
print_info "Sealed Secrets provides encrypted secret management"

helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
    --namespace kube-system \
    --values sealed-secrets/values.yaml \
    --wait \
    --timeout 5m

print_info "Sealed Secrets installed successfully!"

echo ""
echo "=================================="
echo "Step 5: Installing ArgoCD"
echo "=================================="
print_info "ArgoCD is the GitOps continuous delivery tool"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - 

helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --create-namespace \
    --values argocd/values.yaml \
    --wait \
    --timeout 5m

# Apply ArgoCD ingress
print_info "Creating ArgoCD IngressRoute..."
kubectl apply -f argocd/ingress.yaml

print_info "ArgoCD installed successfully!"
print_warning "Get the initial admin password with: make argocd-password"

echo ""

# ==================================
# # Step 6: Installing Velero
# ==================================
# print_info "Velero provides backup and disaster recovery capabilities"

# kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -

# helm upgrade --install velero vmware-tanzu/velero \
#     --namespace velero \
#     --create-namespace \
#     --values velero/values.yaml \
#     --wait \
#     --timeout 5m

# # Apply backup schedules
# print_info "Creating backup schedules..."
# kubectl apply -f velero/backup-schedules.yaml

# print_info "Velero installed successfully!"


echo ""
echo "=================================="
echo "Installation Complete!"
echo "=================================="
echo ""
print_info "Platform components installed successfully!"
echo ""
echo "Quick Access Commands:"
echo "----------------------"
echo "ArgoCD Password:   make argocd-password"
echo "Platform Status:   make status"
echo "Grafana Password:  kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' | base64 -d"

echo ""
echo "Platform Services:"
echo "------------------"
echo "Traefik:     NodePort 30080 (HTTP) / 30443 (HTTPS)"
echo "ArgoCD:      https://argocd.yourdomain.com"
echo "Grafana:     https://grafana.yourdomain.com"
echo "Prometheus:  https://prometheus.yourdomain.com"

echo ""
print_warning "Remember to configure DNS records for your ingress endpoints!"
print_warning "Update domain names in ingress configurations before accessing services!"
echo ""
