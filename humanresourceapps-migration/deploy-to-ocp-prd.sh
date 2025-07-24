#!/bin/bash

# Human Resource Apps Deployment Script for OCP-PRD
set -euo pipefail

NAMESPACE="humanresourceapps"
GITOPS_DIR="./gitops"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Check cluster connection
if ! oc whoami &> /dev/null; then
    echo "❌ Not logged in to OpenShift cluster"
    exit 1
fi

current_server=$(oc whoami --show-server)
print_info "Connected to: $current_server"

echo "Choose deployment method:"
echo "1. Deploy using Kustomize (Production)"
echo "2. Deploy using Kustomize (Development)"
echo "3. Deploy using raw manifests"
echo "4. Deploy ArgoCD Application"
read -p "Select option (1-4): " option

case $option in
    1)
        print_info "Deploying production environment using Kustomize..."
        kubectl apply -k "$GITOPS_DIR/overlays/prd"
        ;;
    2)
        print_info "Deploying development environment using Kustomize..."
        kubectl apply -k "$GITOPS_DIR/overlays/dev"
        ;;
    3)
        print_info "Deploying using raw manifests..."
        
        # Create namespace first
        kubectl apply -f "$GITOPS_DIR/base/namespace.yaml"
        
        # Deploy base resources
        kubectl apply -f "$GITOPS_DIR/base/serviceaccount.yaml"
        kubectl apply -f "$GITOPS_DIR/base/scc-binding.yaml"
        kubectl apply -f "$GITOPS_DIR/base/rbac.yaml"
        
        # Deploy application resources
        for file in "$GITOPS_DIR/overlays/prd"/*-cleaned.yaml; do
            if [[ -f "$file" ]]; then
                kubectl apply -f "$file"
            fi
        done
        ;;
    4)
        print_info "Deploying ArgoCD Application..."
        kubectl apply -f "$GITOPS_DIR/argocd-application.yaml"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

print_success "Deployment completed!"
