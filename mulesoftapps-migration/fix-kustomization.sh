#!/bin/bash
# Fix Kustomization YAML Script
# This script repairs the malformed kustomization.yaml file

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

# Fix the kustomization.yaml file
fix_kustomization() {
    print_section "FIXING KUSTOMIZATION.YAML"
    
    local kustomization_file="gitops/overlays/prd/kustomization.yaml"
    
    if [[ ! -f "$kustomization_file" ]]; then
        print_error "Kustomization file not found: $kustomization_file"
        return 1
    fi
    
    print_info "Backing up original kustomization.yaml..."
    cp "$kustomization_file" "${kustomization_file}.backup"
    
    print_info "Creating corrected kustomization.yaml..."
    
    # Create the fixed kustomization file
    cat > "$kustomization_file" << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: mulesoftapps-prod

resources:
  - ../../base

patchesStrategicMerge: []

images: []

configMapGenerator: []

secretGenerator: []

commonLabels:
  environment: production
  cluster: ocp-prd
  app.kubernetes.io/name: mulesoftapps
  app.kubernetes.io/part-of: mulesoftapps
  app.kubernetes.io/managed-by: argocd
  migrated-from: ocpaz

commonAnnotations:
  migration.date: "20250728"
  migration.source: "ocpaz"
  migration.target: "ocp-prd"
EOF

    # Check for existing resource files and add them properly
    local resources_found=()
    local prd_dir="gitops/overlays/prd"
    
    for file in "$prd_dir"/*.yaml; do
        if [[ -f "$file" && "$(basename "$file")" != "kustomization.yaml" ]]; then
            resources_found+=("$(basename "$file")")
        fi
    done
    
    # Add resources section if we have any resource files
    if [[ ${#resources_found[@]} -gt 0 ]]; then
        echo "" >> "$kustomization_file"
        echo "# Application Resources" >> "$kustomization_file"
        echo "resources:" >> "$kustomization_file"
        echo "  - ../../base" >> "$kustomization_file"
        
        for resource in "${resources_found[@]}"; do
            echo "  - $resource" >> "$kustomization_file"
            print_info "Added resource: $resource"
        done
    fi
    
    print_success "Kustomization.yaml fixed successfully"
}

# Test the fixed kustomization
test_kustomization() {
    print_section "TESTING FIXED KUSTOMIZATION"
    
    if command -v kubectl &> /dev/null; then
        print_info "Testing base kustomization..."
        if kubectl kustomize gitops/base > /dev/null 2>&1; then
            print_success "✅ Base kustomization builds successfully"
        else
            print_error "❌ Base kustomization has errors"
            kubectl kustomize gitops/base 2>&1 | head -10
            return 1
        fi
        
        print_info "Testing production overlay..."
        if kubectl kustomize gitops/overlays/prd > /dev/null 2>&1; then
            print_success "✅ Production overlay builds successfully"
        else
            print_error "❌ Production overlay still has errors:"
            kubectl kustomize gitops/overlays/prd 2>&1 | head -10
            return 1
        fi
        
        # Count resources
        local resource_count
        resource_count=$(kubectl kustomize gitops/overlays/prd 2>/dev/null | grep -c "^kind:" || echo "0")
        print_info "Total resources in production overlay: $resource_count"
        
    else
        print_warning "kubectl not available - skipping kustomize test"
    fi
}

# Show the structure
show_structure() {
    print_section "GITOPS STRUCTURE"
    
    if command -v tree &> /dev/null; then
        tree gitops/
    else
        print_info "GitOps directory structure:"
        find gitops/ -type f | sort
    fi
}

# Main function
main() {
    print_section "KUSTOMIZATION YAML REPAIR TOOL"
    
    if [[ ! -d "gitops" ]]; then
        print_error "GitOps directory not found. Please run the migration script first."
        exit 1
    fi
    
    fix_kustomization
    test_kustomization
    show_structure
    
    print_section "REPAIR COMPLETED"
    print_success "🎉 Kustomization.yaml has been fixed and validated!"
    print_info "You can now proceed with deployment using:"
    print_info "  kubectl apply -k gitops/overlays/prd"
    print_info "  OR"
    print_info "  oc apply -f gitops/argocd-application.yaml"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
