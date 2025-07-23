#!/bin/bash

# Data Analytics Deployment Script for OCP-PRD Cluster
# This script deploys the migrated resources to the target cluster

set -e

NAMESPACE="data-analytics"
GITOPS_DIR="gitops"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check prerequisites
if ! command -v oc &> /dev/null; then
    print_error "oc command not found"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl command not found"
    exit 1
fi

if ! oc whoami &> /dev/null; then
    print_error "Not logged in to OpenShift"
    exit 1
fi

print_section "DEPLOYING DATA ANALYTICS TO OCP-PRD"

# Option 1: Deploy using Kustomize
echo "Choose deployment method:"
echo "1. Deploy using Kustomize (Production)"
echo "2. Deploy using Kustomize (Development)"
echo "3. Deploy using raw manifests"
echo "4. Deploy ArgoCD Applications"
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
        
        # Deploy cleaned resources
        if [[ -f "cleaned/${NAMESPACE}-all-pvcs-cleaned.yaml" ]]; then
            kubectl apply -f "cleaned/${NAMESPACE}-all-pvcs-cleaned.yaml"
        fi
        
        if [[ -f "cleaned/${NAMESPACE}-all-secrets-cleaned.yaml" ]]; then
            kubectl apply -f "cleaned/${NAMESPACE}-all-secrets-cleaned.yaml"
        fi
        
        if [[ -f "cleaned/${NAMESPACE}-all-configmaps-cleaned.yaml" ]]; then
            kubectl apply -f "cleaned/${NAMESPACE}-all-configmaps-cleaned.yaml"
        fi
        
        if [[ -f "cleaned/${NAMESPACE}-all-services-cleaned.yaml" ]]; then
            kubectl apply -f "cleaned/${NAMESPACE}-all-services-cleaned.yaml"
        fi
        
        if [[ -f "cleaned/${NAMESPACE}-all-deployments-cleaned.yaml" ]]; then
            kubectl apply -f "cleaned/${NAMESPACE}-all-deployments-cleaned.yaml"
        fi
        
        if [[ -f "cleaned/${NAMESPACE}-all-deploymentconfigs-cleaned.yaml" ]]; then
            kubectl apply -f "cleaned/${NAMESPACE}-all-deploymentconfigs-cleaned.yaml"
        fi
        
        if [[ -f "cleaned/${NAMESPACE}-all-routes-cleaned.yaml" ]]; then
            kubectl apply -f "cleaned/${NAMESPACE}-all-routes-cleaned.yaml"
        fi
        ;;
    4)
        print_info "Deploying ArgoCD Applications..."
        kubectl apply -f "$GITOPS_DIR/argocd-application.yaml"
        print_info "ArgoCD will now sync the applications automatically"
        ;;
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

print_section "VERIFYING DEPLOYMENT"

print_info "Checking namespace..."
kubectl get namespace $NAMESPACE

print_info "Checking PVCs..."
kubectl get pvc -n $NAMESPACE

print_info "Checking secrets..."
kubectl get secrets -n $NAMESPACE | grep -v token

print_info "Checking service accounts..."
kubectl get serviceaccounts -n $NAMESPACE

print_info "Checking pods..."
kubectl get pods -n $NAMESPACE

echo
print_success "Data Analytics deployment completed!"
print_info "Next steps:"
print_info "1. Verify all PVCs are Bound"
print_info "2. Check pod status and logs"
print_info "3. Test application functionality"
print_info "4. Migrate container images to Quay registry if needed"
