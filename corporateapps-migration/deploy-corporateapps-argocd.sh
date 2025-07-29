#!/bin/bash
# Quick Deploy Corporate Apps to OCP-PRD via ArgoCD
# This script assumes the migration has been completed and GitOps structure exists

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_URL="https://api.ocp-prd.kohlerco.com:6443"
NAMESPACE="corporateapps"
ARGOCD_NAMESPACE="openshift-gitops"
APP_NAME="corporateapps-prd"

# Logging functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    # Check if oc is installed
    if ! command -v oc &> /dev/null; then
        print_error "OpenShift CLI (oc) is not installed"
        exit 1
    fi
    
    # Check if ArgoCD application file exists
    if [[ ! -f "gitops/argocd-application.yaml" ]]; then
        print_error "ArgoCD application file not found. Run migrate-corporateapps.sh first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Login to cluster
login_to_cluster() {
    print_section "CLUSTER LOGIN"
    
    print_info "Current cluster context:"
    oc whoami --show-server 2>/dev/null || echo "Not logged in"
    
    print_info "Logging into OCP-PRD cluster: $CLUSTER_URL"
    oc login "$CLUSTER_URL" || {
        print_error "Failed to login to cluster"
        exit 1
    }
    
    print_success "Successfully logged into cluster"
}

# Check ArgoCD installation
check_argocd() {
    print_section "CHECKING ARGOCD INSTALLATION"
    
    if ! oc get namespace "$ARGOCD_NAMESPACE" &>/dev/null; then
        print_error "ArgoCD namespace '$ARGOCD_NAMESPACE' not found"
        print_info "Please ensure OpenShift GitOps is installed"
        exit 1
    fi
    
    if ! oc get deployment argocd-application-controller -n "$ARGOCD_NAMESPACE" &>/dev/null; then
        print_error "ArgoCD application controller not found"
        exit 1
    fi
    
    print_success "ArgoCD installation verified"
}

# Deploy ArgoCD application
deploy_application() {
    print_section "DEPLOYING ARGOCD APPLICATION"
    
    print_info "Applying ArgoCD application manifest..."
    oc apply -f gitops/argocd-application.yaml
    
    print_success "ArgoCD application deployed successfully"
    
    # Wait a moment for the application to be registered
    sleep 5
    
    print_info "Application status:"
    oc get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o wide 2>/dev/null || print_warning "Application not yet available"
}

# Monitor deployment
monitor_deployment() {
    print_section "MONITORING DEPLOYMENT"
    
    print_info "Monitoring ArgoCD application sync..."
    
    # Wait for sync to start
    local timeout=300  # 5 minutes
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local sync_status=$(oc get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        local health_status=$(oc get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        print_info "Sync Status: $sync_status | Health Status: $health_status"
        
        if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
            print_success "Application successfully synced and healthy!"
            break
        elif [[ "$sync_status" == "OutOfSync" ]]; then
            print_warning "Application is out of sync, ArgoCD will retry..."
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        print_warning "Deployment monitoring timed out after 5 minutes"
        print_info "Check ArgoCD UI for detailed status"
    fi
}

# Verify deployment
verify_deployment() {
    print_section "VERIFYING DEPLOYMENT"
    
    # Check namespace
    if oc get namespace "$NAMESPACE" &>/dev/null; then
        print_success "Namespace '$NAMESPACE' exists"
    else
        print_error "Namespace '$NAMESPACE' not found"
    fi
    
    # Check resources
    print_info "Resources in namespace:"
    oc get all -n "$NAMESPACE" 2>/dev/null || print_warning "No resources found or namespace not accessible"
    
    # Check specific deployments
    local deployment_count=$(oc get deployment -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    print_info "Deployments found: $deployment_count"
    
    # Check routes
    local route_count=$(oc get route -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    print_info "Routes found: $route_count"
    
    if [[ $route_count -gt 0 ]]; then
        print_info "Application URLs:"
        oc get route -n "$NAMESPACE" -o custom-columns="NAME:.metadata.name,URL:.spec.host" --no-headers 2>/dev/null | while read name host; do
            echo "  - $name: https://$host"
        done
    fi
}

# Show next steps
show_next_steps() {
    print_section "NEXT STEPS"
    
    echo "🎉 Corporate Apps deployment initiated!"
    echo ""
    echo "📊 Monitor progress:"
    echo "  ArgoCD UI: https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null)"
    echo "  Command: oc get application $APP_NAME -n $ARGOCD_NAMESPACE -w"
    echo ""
    echo "🔍 Check application status:"
    echo "  oc get all -n $NAMESPACE"
    echo "  oc get route -n $NAMESPACE"
    echo ""
    echo "🚨 Troubleshooting:"
    echo "  oc describe application $APP_NAME -n $ARGOCD_NAMESPACE"
    echo "  oc logs -n $ARGOCD_NAMESPACE deployment/argocd-application-controller"
    echo ""
    echo "📝 Documentation:"
    echo "  See README.md for detailed information"
}

# Main function
main() {
    print_section "CORPORATE APPS ARGOCD DEPLOYMENT"
    print_info "Deploying corporateapps to OCP-PRD via ArgoCD"
    
    check_prerequisites
    login_to_cluster
    check_argocd
    deploy_application
    monitor_deployment
    verify_deployment
    show_next_steps
    
    print_section "DEPLOYMENT COMPLETE"
    print_success "Corporate Apps ArgoCD deployment process finished"
}

# Run main function
main "$@"
