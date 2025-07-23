#!/bin/bash

# ArgoCD Repository Setup Script
# This script adds the koihler-apps repository to ArgoCD and deploys the applications

set -e

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
check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    if ! command -v oc &> /dev/null; then
        print_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl command not found. Please install kubectl."
        exit 1
    fi
    
    # Check if argocd CLI is available (optional)
    if command -v argocd &> /dev/null; then
        ARGOCD_CLI_AVAILABLE=true
        print_info "ArgoCD CLI found - will use for verification"
    else
        ARGOCD_CLI_AVAILABLE=false
        print_info "ArgoCD CLI not found - will use kubectl only"
    fi
    
    # Check OpenShift login
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login'"
        exit 1
    fi
    
    # Check if openshift-gitops namespace exists
    if ! oc get namespace openshift-gitops &> /dev/null; then
        print_error "openshift-gitops namespace not found. Please install ArgoCD first."
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Add repository to ArgoCD
add_repository() {
    print_section "ADDING REPOSITORY TO ARGOCD"
    
    print_info "Creating ArgoCD repository configuration..."
    
    # Apply the repository secret and configuration
    kubectl apply -f argocd-repository.yaml
    
    print_success "Repository added to ArgoCD"
    
    # Wait a moment for ArgoCD to process the new repository
    print_info "Waiting for ArgoCD to process the repository..."
    sleep 5
    
    # Verify repository is added (if ArgoCD CLI is available)
    if [[ "$ARGOCD_CLI_AVAILABLE" == "true" ]]; then
        # Try to login to ArgoCD (this might require manual intervention)
        print_info "Attempting to verify repository with ArgoCD CLI..."
        if argocd repo list 2>/dev/null | grep -q "koihler-apps"; then
            print_success "Repository verified in ArgoCD"
        else
            print_info "Repository may need manual verification in ArgoCD UI"
        fi
    fi
}

# Deploy ArgoCD applications
deploy_applications() {
    print_section "DEPLOYING ARGOCD APPLICATIONS"
    
    echo "Choose deployment option:"
    echo "1. Deploy both dev and production applications"
    echo "2. Deploy production application only"
    echo "3. Deploy development application only"
    echo "4. Skip application deployment (repository only)"
    read -p "Select option (1-4): " option
    
    case $option in
        1)
            print_info "Deploying both dev and production applications..."
            kubectl apply -f data-analytics-migration/gitops/argocd-application.yaml
            ;;
        2)
            print_info "Deploying production application only..."
            kubectl apply -f data-analytics-migration/gitops/argocd-application.yaml | grep -A 50 "name: data-analytics-prd" | kubectl apply -f -
            ;;
        3)
            print_info "Deploying development application only..."
            kubectl apply -f data-analytics-migration/gitops/argocd-application.yaml | grep -A 50 "name: data-analytics-dev" | kubectl apply -f -
            ;;
        4)
            print_info "Skipping application deployment"
            return
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
    
    print_success "ArgoCD applications created"
}

# Verify deployment
verify_deployment() {
    print_section "VERIFYING DEPLOYMENT"
    
    print_info "Checking ArgoCD applications..."
    kubectl get applications -n openshift-gitops | grep data-analytics || echo "No data-analytics applications found"
    
    print_info "Checking repository connection..."
    kubectl get secret koihler-apps-repo -n openshift-gitops -o jsonpath='{.data.url}' | base64 -d
    echo
    
    if [[ "$ARGOCD_CLI_AVAILABLE" == "true" ]]; then
        print_info "ArgoCD application status:"
        argocd app list | grep data-analytics || echo "ArgoCD CLI verification failed - check manually"
    fi
    
    print_info "ArgoCD UI can be accessed at:"
    echo "$(oc get route argocd-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo 'Route not found - check ArgoCD installation')"
}

# Display next steps
show_next_steps() {
    print_section "NEXT STEPS"
    
    echo "Repository has been added to ArgoCD. Next steps:"
    echo
    echo "1. 🌐 **Access ArgoCD UI**:"
    ARGOCD_ROUTE=$(oc get route argocd-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo 'Not found')
    echo "   https://$ARGOCD_ROUTE"
    echo
    echo "2. 🔐 **Get ArgoCD Admin Password**:"
    echo "   oc extract secret/argocd-initial-admin-secret -n openshift-gitops --to=-"
    echo
    echo "3. 📱 **Monitor Applications**:"
    echo "   - Check sync status in ArgoCD UI"
    echo "   - Monitor data-analytics namespace creation"
    echo "   - Verify PVC binding and pod startup"
    echo
    echo "4. 🚀 **Manual Sync (if needed)**:"
    echo "   argocd app sync data-analytics-prd"
    echo "   argocd app sync data-analytics-dev"
    echo
    echo "5. 📊 **Verify Resources**:"
    echo "   kubectl get all -n data-analytics"
    echo "   kubectl get pvc -n data-analytics"
    echo
    
    print_success "ArgoCD setup completed successfully!"
}

# Main function
main() {
    print_section "ARGOCD REPOSITORY SETUP"
    print_info "Repository: https://github.com/rich-p-ai/koihler-apps.git"
    print_info "Target: OpenShift GitOps (ArgoCD)"
    
    check_prerequisites
    add_repository
    deploy_applications
    verify_deployment
    show_next_steps
}

# Run the setup
main "$@"
