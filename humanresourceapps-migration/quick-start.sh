#!/bin/bash

# ====================================================================
# Human Resource Apps Migration - Quick Start Guide
# ====================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}  HUMAN RESOURCE APPS MIGRATION - QUICK START${NC}"
    echo -e "${BLUE}=================================================${NC}\n"
}

print_step() {
    echo -e "${BLUE}📋 STEP $1: $2${NC}\n"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Main quick start guide
main() {
    print_header
    
    print_step "1" "PREPARATION"
    echo "Before starting the migration, ensure you have:"
    echo "• Access to OCP4 cluster (source)"
    echo "• Access to OCP-PRD cluster (target)"
    echo "• OpenShift CLI (oc) installed"
    echo "• yq tool installed for YAML processing"
    echo ""
    
    print_step "2" "LOGIN TO SOURCE CLUSTER"
    echo "Login to the OCP4 cluster to export resources:"
    echo ""
    echo "  oc login https://api.ocp4.kohlerco.com:6443"
    echo ""
    
    print_step "3" "RUN MIGRATION SCRIPT"
    echo "Execute the migration script to export and prepare resources:"
    echo ""
    echo "  cd \"/c/work/OneDrive - Kohler Co/Openshift/git/koihler-apps/humanresourceapps-migration\""
    echo "  chmod +x migrate-humanresourceapps.sh"
    echo "  ./migrate-humanresourceapps.sh"
    echo ""
    
    print_step "4" "SWITCH TO TARGET CLUSTER"
    echo "Login to the OCP-PRD cluster for deployment:"
    echo ""
    echo "  oc login https://api.ocp-prd.kohlerco.com:6443"
    echo ""
    
    print_step "5" "DEPLOY TO OCP-PRD"
    echo "Choose one of the following deployment methods:"
    echo ""
    echo "Option A - GitOps with ArgoCD (Recommended):"
    echo "  oc apply -f gitops/argocd-application.yaml"
    echo ""
    echo "Option B - Direct Kustomize Deployment:"
    echo "  kubectl apply -k gitops/overlays/prd"
    echo ""
    echo "Option C - Guided Deployment Script:"
    echo "  ./deploy-to-ocp-prd.sh"
    echo ""
    
    print_step "6" "VERIFY DEPLOYMENT"
    echo "Check the deployment status:"
    echo ""
    echo "  # Check all resources"
    echo "  oc get all -n humanresourceapps"
    echo ""
    echo "  # Check jobs specifically"
    echo "  oc get jobs,cronjobs -n humanresourceapps"
    echo ""
    echo "  # Check ArgoCD sync (if using ArgoCD)"
    echo "  oc get application humanresourceapps-prd -n openshift-gitops"
    echo ""
    
    print_step "7" "POST-MIGRATION TASKS"
    echo "After successful deployment:"
    echo "• Verify all jobs are running correctly"
    echo "• Check CronJob schedules are appropriate"
    echo "• Test job execution and outputs"
    echo "• Update monitoring and alerting"
    echo "• Document any changes for the team"
    echo ""
    
    print_success "Quick Start Guide Complete!"
    print_info "For detailed information, see README.md"
    print_info "For troubleshooting, check the migration summary after running the script"
}

# Execute main function
main "$@"
