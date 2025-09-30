.PHONY: help install uninstall upgrade status argocd-password add-repos

help:
	@echo "Infrastructure Platform - Makefile Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make install              Install all platform components"
	@echo "  make uninstall           Uninstall all platform components"
	@echo "  make upgrade             Upgrade all platform components"
	@echo "  make status              Check status of all components"
	@echo "  make argocd-password     Get ArgoCD admin password"
	@echo "  make add-repos           Add required Helm repositories"
	@echo ""

add-repos:
	@echo "Adding Helm repositories..."
	helm repo add traefik https://traefik.github.io/charts
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo add jetstack https://charts.jetstack.io
	helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
	helm repo update
	@echo "Helm repositories added and updated!"

install: add-repos
	@echo "Installing platform components..."
	@./scripts/install-platform.sh
	@echo "Platform installation complete!"

uninstall:
	@echo "Uninstalling platform components..."
	@echo "Removing Velero..."
	-helm uninstall velero -n velero
	@echo "Removing Monitoring stack..."
	-helm uninstall loki -n monitoring
	-helm uninstall grafana -n monitoring
	-helm uninstall prometheus -n monitoring
	@echo "Removing Sealed Secrets..."
	-helm uninstall sealed-secrets -n kube-system
	@echo "Removing Cert-Manager..."
	-kubectl delete -f cert-manager/cluster-issuer.yaml
	-helm uninstall cert-manager -n cert-manager
	@echo "Removing ArgoCD..."
	-helm uninstall argocd -n argocd
	@echo "Removing Traefik..."
	-helm uninstall traefik -n traefik
	@echo "Deleting namespaces..."
	-kubectl delete namespace traefik argocd cert-manager monitoring velero
	@echo "Platform uninstalled!"

upgrade: add-repos
	@echo "Upgrading platform components..."
	@echo "Upgrading Traefik..."
	helm upgrade traefik traefik/traefik -n traefik -f traefik/values.yaml
	@echo "Upgrading ArgoCD..."
	helm upgrade argocd argo/argo-cd -n argocd -f argocd/values.yaml
	@echo "Upgrading Cert-Manager..."
	helm upgrade cert-manager jetstack/cert-manager -n cert-manager -f cert-manager/values.yaml
	@echo "Upgrading Sealed Secrets..."
	helm upgrade sealed-secrets sealed-secrets/sealed-secrets -n kube-system -f sealed-secrets/values.yaml
	@echo "Upgrading Prometheus..."
	helm upgrade prometheus prometheus-community/kube-prometheus-stack -n monitoring -f monitoring/prometheus/values.yaml
	@echo "Upgrading Grafana..."
	helm upgrade grafana grafana/grafana -n monitoring -f monitoring/grafana/values.yaml
	@echo "Upgrading Loki..."
	helm upgrade loki grafana/loki-stack -n monitoring -f monitoring/loki/values.yaml
	@echo "Upgrading Velero..."
	helm upgrade velero vmware-tanzu/velero -n velero -f velero/values.yaml
	@echo "Platform upgrade complete!"

status:
	@echo "Platform Component Status"
	@echo "=========================="
	@echo ""
	@echo "Traefik:"
	@kubectl get pods -n traefik -l app.kubernetes.io/name=traefik 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "ArgoCD:"
	@kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "Cert-Manager:"
	@kubectl get pods -n cert-manager -l app=cert-manager 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "Sealed Secrets:"
	@kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "Prometheus:"
	@kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "Grafana:"
	@kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "Loki:"
	@kubectl get pods -n monitoring -l app=loki 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "Velero:"
	@kubectl get pods -n velero -l app.kubernetes.io/name=velero 2>/dev/null || echo "  Not installed"
	@echo ""

argocd-password:
	@./scripts/get-argocd-password.sh