#!/bin/bash
# Update Storage Classes Script
# This script updates storage classes in existing PVC files to ocs-storagecluster-ceph-rbd

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Update storage classes in PVCs
update_pvc_storage_classes() {
    print_section "UPDATING STORAGE CLASSES TO OCS-STORAGECLUSTER-CEPH-RBD"
    
    local target_storage_class="ocs-storagecluster-ceph-rbd"
    local files_updated=0
    
    # Check backup/cleaned directory
    if [[ -f "backup/cleaned/pvcs.yaml" ]]; then
        print_info "Updating storage classes in backup/cleaned/pvcs.yaml..."
        
        if command -v yq &> /dev/null; then
            # Show current storage classes
            print_info "Current storage classes:"
            yq eval '.items[]? | select(.kind == "PersistentVolumeClaim") | .metadata.name + " -> " + (.spec.storageClassName // "default")' backup/cleaned/pvcs.yaml 2>/dev/null | while read -r line; do
                print_info "  $line"
            done
            
            # Update storage classes
            yq eval '
                (.items[]? | select(.kind == "PersistentVolumeClaim") | .spec.storageClassName) = "ocs-storagecluster-ceph-rbd"
            ' backup/cleaned/pvcs.yaml > backup/cleaned/pvcs.yaml.tmp && mv backup/cleaned/pvcs.yaml.tmp backup/cleaned/pvcs.yaml
            
            # Show updated storage classes
            print_info "Updated storage classes:"
            yq eval '.items[]? | select(.kind == "PersistentVolumeClaim") | .metadata.name + " -> " + .spec.storageClassName' backup/cleaned/pvcs.yaml 2>/dev/null | while read -r line; do
                print_success "  $line"
            done
        else
            # Fallback to sed
            sed -i.bak 's/storageClassName: .*/storageClassName: ocs-storagecluster-ceph-rbd/g' backup/cleaned/pvcs.yaml
            print_success "Updated using sed (backup created as .bak)"
        fi
        
        files_updated=$((files_updated + 1))
    fi
    
    # Check gitops overlay directory
    if [[ -f "gitops/overlays/prd/pvcs.yaml" ]]; then
        print_info "Updating storage classes in gitops/overlays/prd/pvcs.yaml..."
        
        if command -v yq &> /dev/null; then
            yq eval '
                (.items[]? | select(.kind == "PersistentVolumeClaim") | .spec.storageClassName) = "ocs-storagecluster-ceph-rbd"
            ' gitops/overlays/prd/pvcs.yaml > gitops/overlays/prd/pvcs.yaml.tmp && mv gitops/overlays/prd/pvcs.yaml.tmp gitops/overlays/prd/pvcs.yaml
        else
            sed -i.bak 's/storageClassName: .*/storageClassName: ocs-storagecluster-ceph-rbd/g' gitops/overlays/prd/pvcs.yaml
        fi
        
        files_updated=$((files_updated + 1))
    fi
    
    if [[ $files_updated -eq 0 ]]; then
        print_warning "No PVC files found to update"
        print_info "Available files:"
        find . -name "*.yaml" -path "*/pvc*" -o -name "pvcs.yaml" 2>/dev/null || echo "No PVC files found"
    else
        print_success "Updated storage classes in $files_updated file(s)"
    fi
}

# Validate the changes
validate_storage_classes() {
    print_section "VALIDATING STORAGE CLASS CHANGES"
    
    local target_storage_class="ocs-storagecluster-ceph-rbd"
    
    # Check if kustomize still builds correctly
    if [[ -d "gitops/overlays/prd" ]] && command -v kubectl &> /dev/null; then
        print_info "Testing Kustomize build after storage class update..."
        if kubectl kustomize gitops/overlays/prd > /dev/null 2>&1; then
            print_success "✅ Kustomize build successful"
            
            # Count PVCs with correct storage class
            local pvc_count
            pvc_count=$(kubectl kustomize gitops/overlays/prd 2>/dev/null | grep -A 10 "kind: PersistentVolumeClaim" | grep "storageClassName: $target_storage_class" | wc -l)
            print_info "PVCs with correct storage class: $pvc_count"
        else
            print_error "❌ Kustomize build failed"
            kubectl kustomize gitops/overlays/prd 2>&1 | head -10
        fi
    fi
    
    # Show storage class summary
    print_info "Storage class configuration summary:"
    print_success "  Target storage class: $target_storage_class"
    print_success "  Purpose: OpenShift Container Storage (OCS) with Ceph RBD"
    print_success "  Cluster: OCP-PRD"
}

# Main function
main() {
    print_section "STORAGE CLASS UPDATE TOOL"
    print_info "Updating storage classes to: ocs-storagecluster-ceph-rbd"
    print_info "This ensures compatibility with OCP-PRD OpenShift Container Storage"
    
    if [[ ! -d "backup" && ! -d "gitops" ]]; then
        print_error "No migration files found. Please run migrate-mulesoftapps.sh first."
        exit 1
    fi
    
    update_pvc_storage_classes
    validate_storage_classes
    
    print_section "STORAGE CLASS UPDATE COMPLETE"
    print_success "🎉 All PVCs configured for OCS storage on OCP-PRD!"
    print_info "Ready for deployment with correct storage configuration."
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
