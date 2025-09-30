#!/bin/bash

set -e

echo "Retrieving ArgoCD initial admin password..."
echo ""

# Check if argocd namespace exists
if ! kubectl get namespace argocd &> /dev/null; then
    echo "Error: ArgoCD namespace not found. Is ArgoCD installed?"
    exit 1
fi

# Check if the secret exists
if ! kubectl get secret argocd-initial-admin-secret -n argocd &> /dev/null; then
    echo "Error: ArgoCD initial admin secret not found."
    echo "The secret may have been deleted or ArgoCD installation is incomplete."
    exit 1
fi

# Get the password
PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD Login Credentials:"
echo "========================="
echo "Username: admin"
echo "Password: $PASSWORD"
echo ""
echo "Access ArgoCD at: https://argocd.yourdomain.com"
echo ""
echo "Note: Change the password after first login using:"
echo "  argocd account update-password"
echo ""