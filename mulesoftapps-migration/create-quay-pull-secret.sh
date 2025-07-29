#!/bin/bash
# Create Quay Pull Secret for Mulesoft Apps
# This script creates the necessary pull secret for accessing Quay registry images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_REGISTRY="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
TARGET_NAMESPACE="mulesoftapps-prod"
ROBOT_USER="mulesoftapps+robot"
ROBOT_PASSWORD="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0"
SECRET_NAME="quay-pull-secret"

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

# Main function
main() {
    print_section "CREATING QUAY PULL SECRET"
    
    print_info "Target Registry: $TARGET_REGISTRY"
    print_info "Target Namespace: $TARGET_NAMESPACE"
    print_info "Robot User: $ROBOT_USER"
    print_info "Secret Name: $SECRET_NAME"
    
    # Check if oc is available
    if ! command -v oc &> /dev/null; then
        print_error "OpenShift CLI (oc) is not installed"
        exit 1
    fi
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged into OpenShift cluster"
        print_info "Please login first: oc login <cluster-url>"
        exit 1
    fi
    
    print_info "Current cluster: $(oc whoami --show-server 2>/dev/null || echo 'Unknown')"
    print_info "Current user: $(oc whoami 2>/dev/null || echo 'Unknown')"
    
    # Check if namespace exists
    if ! oc get namespace "$TARGET_NAMESPACE" &>/dev/null; then
        print_warning "Namespace '$TARGET_NAMESPACE' does not exist"
        print_info "Creating namespace..."
        oc create namespace "$TARGET_NAMESPACE"
        print_success "Namespace created: $TARGET_NAMESPACE"
    fi
    
    # Delete existing secret if it exists
    if oc get secret "$SECRET_NAME" -n "$TARGET_NAMESPACE" &>/dev/null; then
        print_info "Deleting existing secret: $SECRET_NAME"
        oc delete secret "$SECRET_NAME" -n "$TARGET_NAMESPACE"
    fi
    
    # Create the pull secret
    print_info "Creating pull secret..."
    if oc create secret docker-registry "$SECRET_NAME" \
        --docker-server="$TARGET_REGISTRY" \
        --docker-username="$ROBOT_USER" \
        --docker-password="$ROBOT_PASSWORD" \
        --namespace="$TARGET_NAMESPACE"; then
        print_success "Pull secret created: $SECRET_NAME"
    else
        print_error "Failed to create pull secret"
        exit 1
    fi
    
    # Update default service account
    print_info "Updating default service account to use pull secret..."
    if oc patch serviceaccount default -p "{\"imagePullSecrets\": [{\"name\": \"$SECRET_NAME\"}]}" -n "$TARGET_NAMESPACE"; then
        print_success "Default service account updated"
    else
        print_warning "Failed to update default service account"
    fi
    
    # Update mulesoftapps-sa service account if it exists
    if oc get serviceaccount mulesoftapps-sa -n "$TARGET_NAMESPACE" &>/dev/null; then
        print_info "Updating mulesoftapps-sa service account..."
        if oc patch serviceaccount mulesoftapps-sa -p "{\"imagePullSecrets\": [{\"name\": \"$SECRET_NAME\"}]}" -n "$TARGET_NAMESPACE"; then
            print_success "mulesoftapps-sa service account updated"
        else
            print_warning "Failed to update mulesoftapps-sa service account"
        fi
    fi
    
    # Verify the secret
    print_info "Verifying pull secret..."
    if oc get secret "$SECRET_NAME" -n "$TARGET_NAMESPACE" -o yaml > /tmp/pull-secret-verify.yaml; then
        print_success "Pull secret verification successful"
        rm -f /tmp/pull-secret-verify.yaml
    else
        print_error "Pull secret verification failed"
    fi
    
    print_section "PULL SECRET SETUP COMPLETE!"
    print_success "🎉 Quay pull secret successfully created and configured!"
    print_info "Secret Name: $SECRET_NAME"
    print_info "Namespace: $TARGET_NAMESPACE"
    print_info "Registry: $TARGET_REGISTRY"
    
    print_info "Service accounts updated:"
    print_info "  - default"
    if oc get serviceaccount mulesoftapps-sa -n "$TARGET_NAMESPACE" &>/dev/null; then
        print_info "  - mulesoftapps-sa"
    fi
    
    echo ""
    print_info "You can now pull images from: $TARGET_REGISTRY/mulesoftapps/*"
    print_info "Example: $TARGET_REGISTRY/mulesoftapps/mulesoft-accelerator-2:latest"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
