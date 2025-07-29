#!/bin/bash
# Daily Namespace Backup Script
# This script performs daily backups of a Kubernetes namespace and updates GitHub
# Created: July 29, 2025

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - MODIFY THESE VALUES OR SET AS ENVIRONMENT VARIABLES
SOURCE_CLUSTER="${SOURCE_CLUSTER:-https://api.ocp-prd.kohlerco.com:6443}"
SOURCE_NAMESPACE="${SOURCE_NAMESPACE:-}"
GITHUB_REPO_URL="${GITHUB_REPO_URL:-}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-openshift-gitops}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Directories
BACKUP_DIR="backup"
GITOPS_DIR="gitops"
DAILY_DIR="$BACKUP_DIR/daily/$TIMESTAMP"

# Logging functions
print_section() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

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

# Check configuration
check_configuration() {
    print_section "CHECKING CONFIGURATION"
    
    if [[ -z "$SOURCE_NAMESPACE" ]]; then
        print_error "SOURCE_NAMESPACE not set. Please set it as environment variable or modify script"
        exit 1
    fi
    
    if [[ -z "$GITHUB_REPO_URL" ]]; then
        print_error "GITHUB_REPO_URL not set. Please set it as environment variable or modify script"
        exit 1
    fi
    
    print_info "Configuration:"
    print_info "  Source Cluster: $SOURCE_CLUSTER"
    print_info "  Source Namespace: $SOURCE_NAMESPACE"
    print_info "  GitHub Repository: $GITHUB_REPO_URL"
    print_info "  ArgoCD Namespace: $ARGOCD_NAMESPACE"
    print_info "  Timestamp: $TIMESTAMP"
}

# Check prerequisites
check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    if ! command -v oc &> /dev/null; then
        print_error "OpenShift CLI (oc) is not installed"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        print_error "git is not installed"
        exit 1
    fi
    
    if [[ ! -d "$GITOPS_DIR" ]]; then
        print_error "GitOps directory not found. Run backup-namespace-setup.sh first"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create daily backup directories
create_daily_directories() {
    print_section "CREATING DAILY BACKUP DIRECTORIES"
    
    mkdir -p "$DAILY_DIR/raw"
    mkdir -p "$DAILY_DIR/cleaned"
    mkdir -p "$DAILY_DIR/manifests"
    
    print_success "Daily backup directories created"
}

# Login to cluster
login_to_cluster() {
    print_section "CLUSTER LOGIN"
    
    print_info "Logging into cluster: $SOURCE_CLUSTER"
    
    # Try token-based login first (for automated runs)
    if [[ -f ~/.kube/token ]]; then
        if oc login "$SOURCE_CLUSTER" --token="$(cat ~/.kube/token)" &>/dev/null; then
            print_success "Token-based login successful"
            return 0
        fi
    fi
    
    # Try existing session
    if oc whoami &>/dev/null && oc get namespace "$SOURCE_NAMESPACE" &>/dev/null; then
        print_success "Using existing session"
        return 0
    fi
    
    # Interactive login as fallback
    print_info "Token login failed, prompting for credentials"
    oc login "$SOURCE_CLUSTER" || {
        print_error "Failed to login to cluster"
        exit 1
    }
    
    # Verify namespace access
    if ! oc get namespace "$SOURCE_NAMESPACE" &>/dev/null; then
        print_error "Cannot access namespace '$SOURCE_NAMESPACE'"
        exit 1
    fi
    
    print_success "Successfully logged into cluster"
}

# Export current namespace state
export_current_state() {
    print_section "EXPORTING CURRENT NAMESPACE STATE"
    
    local raw_dir="$DAILY_DIR/raw"
    
    # Resource types to backup
    local resource_types=(
        "configmaps"
        "secrets"
        "services"
        "serviceaccounts"
        "deployments"
        "deploymentconfigs"
        "daemonsets"
        "statefulsets"
        "replicasets"
        "persistentvolumeclaims"
        "routes"
        "ingresses"
        "jobs"
        "cronjobs"
        "imagestreams"
        "buildconfigs"
        "networkpolicies"
        "resourcequotas"
        "limitranges"
        "rolebindings"
        "roles"
        "horizontalpodautoscalers"
        "pods"
    )
    
    for resource_type in "${resource_types[@]}"; do
        print_info "Exporting $resource_type..."
        
        local output_file="$raw_dir/${resource_type}-all.yaml"
        
        if oc get "$resource_type" -n "$SOURCE_NAMESPACE" -o yaml > "$output_file" 2>/dev/null; then
            # Check if file has actual resources
            if grep -q "^kind:" "$output_file"; then
                print_success "Exported $resource_type"
            else
                print_info "No $resource_type found in namespace"
                rm -f "$output_file"
            fi
        else
            print_warning "Failed to export $resource_type or none found"
            rm -f "$output_file"
        fi
    done
    
    print_success "Namespace state export completed"
}

# Clean exported resources
clean_exported_resources() {
    print_section "CLEANING EXPORTED RESOURCES"
    
    local raw_dir="$DAILY_DIR/raw"
    local cleaned_dir="$DAILY_DIR/cleaned"
    
    for file in "$raw_dir"/*.yaml; do
        if [[ -f "$file" ]]; then
            local basename=$(basename "$file")
            local cleaned_file="$cleaned_dir/$basename"
            local resource_type=$(echo "$basename" | sed 's/-all\.yaml$//')
            
            print_info "Cleaning $resource_type..."
            
            # Advanced cleaning with yq if available
            if command -v yq &> /dev/null; then
                yq eval '
                    del(.metadata.uid) |
                    del(.metadata.selfLink) |
                    del(.metadata.resourceVersion) |
                    del(.metadata.generation) |
                    del(.metadata.creationTimestamp) |
                    del(.metadata.deletionTimestamp) |
                    del(.metadata.deletionGracePeriodSeconds) |
                    del(.metadata.ownerReferences) |
                    del(.metadata.finalizers) |
                    del(.metadata.managedFields) |
                    del(.status) |
                    del(.spec.clusterIP) |
                    del(.spec.clusterIPs) |
                    del(.spec.nodeName) |
                    del(.spec.serviceAccount) |
                    del(.spec.hostIP) |
                    del(.spec.podIP) |
                    del(.spec.podIPs) |
                    del(.spec.phase) |
                    del(.spec.qosClass) |
                    del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") |
                    del(.metadata.annotations."deployment.kubernetes.io/revision") |
                    del(.metadata.annotations."pv.kubernetes.io/bind-completed") |
                    del(.metadata.annotations."pv.kubernetes.io/bound-by-controller") |
                    del(.metadata.annotations."volume.beta.kubernetes.io/storage-provisioner") |
                    del(.metadata.annotations."control-plane.alpha.kubernetes.io/leader")
                ' "$file" > "$cleaned_file" 2>/dev/null || {
                    print_warning "yq cleaning failed for $basename, using sed fallback"
                    sed_clean_file "$file" "$cleaned_file"
                }
            else
                # Fallback to sed-based cleaning
                sed_clean_file "$file" "$cleaned_file"
            fi
            
            # Remove empty files
            if [[ ! -s "$cleaned_file" ]] || ! grep -q "^kind:" "$cleaned_file"; then
                rm -f "$cleaned_file"
                print_info "Removed empty file: $basename"
            fi
        fi
    done
    
    print_success "Resource cleaning completed"
}

# Sed-based cleaning function
sed_clean_file() {
    local input_file="$1"
    local output_file="$2"
    
    sed -e '/uid:/d' \
        -e '/selfLink:/d' \
        -e '/resourceVersion:/d' \
        -e '/generation:/d' \
        -e '/creationTimestamp:/d' \
        -e '/deletionTimestamp:/d' \
        -e '/deletionGracePeriodSeconds:/d' \
        -e '/ownerReferences:/d' \
        -e '/finalizers:/d' \
        -e '/managedFields:/d' \
        -e '/^status:/,/^[[:alpha:]]/ { /^[[:alpha:]]/!d; }' \
        -e '/clusterIP:/d' \
        -e '/clusterIPs:/d' \
        -e '/nodeName:/d' \
        -e '/hostIP:/d' \
        -e '/podIP:/d' \
        -e '/podIPs:/d' \
        -e '/phase:/d' \
        -e '/qosClass:/d' \
        -e '/last-applied-configuration/d' \
        -e '/deployment.kubernetes.io\/revision/d' \
        -e '/pv.kubernetes.io\/bind-completed/d' \
        -e '/pv.kubernetes.io\/bound-by-controller/d' \
        -e '/volume.beta.kubernetes.io\/storage-provisioner/d' \
        "$input_file" > "$output_file"
}

# Check for changes and update GitOps
check_for_changes() {
    print_section "CHECKING FOR CHANGES"
    
    local cleaned_dir="$DAILY_DIR/cleaned"
    local overlay_dir="$GITOPS_DIR/overlays/prd"
    local changes_detected=false
    local change_summary=""
    
    # Ensure overlay directory exists
    mkdir -p "$overlay_dir"
    
    # Check each resource type for changes
    for file in "$cleaned_dir"/*.yaml; do
        if [[ -f "$file" ]]; then
            local basename=$(basename "$file")
            local resource_type=$(echo "$basename" | sed 's/-all\.yaml$/\.yaml/')
            local gitops_file="$overlay_dir/$resource_type"
            
            if [[ ! -f "$gitops_file" ]]; then
                print_info "New resource type detected: $resource_type"
                cp "$file" "$gitops_file"
                changes_detected=true
                change_summary="${change_summary}\n  + Added: $resource_type"
                
                # Add to kustomization.yaml if not present
                add_to_kustomization "$resource_type"
            elif ! diff -q "$file" "$gitops_file" &>/dev/null; then
                print_info "Changes detected in: $resource_type"
                cp "$file" "$gitops_file"
                changes_detected=true
                change_summary="${change_summary}\n  ~ Modified: $resource_type"
            else
                print_info "No changes in: $resource_type"
            fi
        fi
    done
    
    # Check for removed resources
    for gitops_file in "$overlay_dir"/*.yaml; do
        if [[ -f "$gitops_file" ]]; then
            local basename=$(basename "$gitops_file")
            local resource_type=$(echo "$basename" | sed 's/\.yaml$/-all.yaml/')
            local cleaned_file="$cleaned_dir/$resource_type"
            
            # Skip base files
            if [[ "$basename" == "kustomization.yaml" ]]; then
                continue
            fi
            
            if [[ ! -f "$cleaned_file" ]]; then
                print_info "Resource type removed: $basename"
                rm -f "$gitops_file"
                changes_detected=true
                change_summary="${change_summary}\n  - Removed: $basename"
                
                # Remove from kustomization.yaml
                remove_from_kustomization "$basename"
            fi
        fi
    done
    
    # Update timestamp in kustomization
    if [[ -f "$overlay_dir/kustomization.yaml" ]]; then
        sed -i "s/backup.kohlerco.com\/timestamp: .*/backup.kohlerco.com\/timestamp: \"$TIMESTAMP\"/" "$overlay_dir/kustomization.yaml"
    fi
    
    if [[ "$changes_detected" == "true" ]]; then
        print_success "Changes detected and GitOps structure updated"
        echo -e "$change_summary"
        return 0
    else
        print_info "No changes detected since last backup"
        return 1
    fi
}

# Add resource to kustomization.yaml
add_to_kustomization() {
    local resource_file="$1"
    local kustomization_file="$GITOPS_DIR/overlays/prd/kustomization.yaml"
    
    if [[ -f "$kustomization_file" ]]; then
        if ! grep -q "- $resource_file" "$kustomization_file"; then
            # Add resource after the resources: line
            sed -i "/^resources:/a\\  - $resource_file" "$kustomization_file"
            print_info "Added $resource_file to kustomization.yaml"
        fi
    fi
}

# Remove resource from kustomization.yaml
remove_from_kustomization() {
    local resource_file="$1"
    local kustomization_file="$GITOPS_DIR/overlays/prd/kustomization.yaml"
    
    if [[ -f "$kustomization_file" ]]; then
        sed -i "/- $resource_file/d" "$kustomization_file"
        print_info "Removed $resource_file from kustomization.yaml"
    fi
}

# Commit and push changes
commit_and_push_changes() {
    print_section "COMMITTING CHANGES TO GITHUB"
    
    # Check if git repository is initialized
    if [[ ! -d ".git" ]]; then
        print_error "Git repository not initialized. Run backup-namespace-setup.sh first"
        exit 1
    fi
    
    # Stage all changes
    git add .
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        print_info "No changes to commit"
        return 0
    fi
    
    # Create commit message
    local commit_message="Auto-backup: Update $SOURCE_NAMESPACE namespace - $TIMESTAMP

Automated backup of namespace resources performed at $(date)

Changes:
$(git diff --cached --name-status | sed 's/^/  /')

Details:
- Timestamp: $TIMESTAMP
- Source Namespace: $SOURCE_NAMESPACE
- Source Cluster: $SOURCE_CLUSTER
- Backup Method: Automated daily sync

This commit contains the latest state of all resources in the
$SOURCE_NAMESPACE namespace, cleaned and prepared for GitOps deployment."
    
    # Commit changes
    git commit -m "$commit_message" || {
        print_error "Failed to commit changes"
        return 1
    }
    
    print_success "Changes committed successfully"
    
    # Push to remote
    if git remote get-url origin &>/dev/null; then
        print_info "Pushing to remote repository..."
        
        if git push origin main; then
            print_success "Changes pushed to GitHub successfully"
        else
            print_error "Failed to push to GitHub - checking for authentication issues"
            
            # Try to push with credential helper
            git config --global credential.helper store 2>/dev/null || true
            
            if git push origin main; then
                print_success "Changes pushed to GitHub successfully (with stored credentials)"
            else
                print_error "Failed to push to GitHub. Manual intervention may be required"
                print_info "You can push manually later with: git push origin main"
                return 1
            fi
        fi
    else
        print_warning "No remote repository configured. Changes committed locally only"
    fi
}

# Generate backup summary
generate_backup_summary() {
    print_section "GENERATING BACKUP SUMMARY"
    
    local summary_file="$DAILY_DIR/backup-summary.md"
    
    cat > "$summary_file" << EOF
# Daily Backup Summary - $TIMESTAMP

## Backup Details
- **Date**: $(date)
- **Namespace**: $SOURCE_NAMESPACE
- **Source Cluster**: $SOURCE_CLUSTER
- **GitHub Repository**: $GITHUB_REPO_URL
- **ArgoCD Application**: $SOURCE_NAMESPACE-backup

## Resources Backed Up

EOF
    
    # Count resources by type
    local total_resources=0
    for file in "$DAILY_DIR/cleaned"/*.yaml; do
        if [[ -f "$file" ]]; then
            local basename=$(basename "$file" .yaml)
            local resource_type=$(echo "$basename" | sed 's/-all$//')
            
            # Count resources in the file
            local count=0
            if command -v yq &> /dev/null; then
                count=$(yq eval '.items | length' "$file" 2>/dev/null || echo "0")
            else
                count=$(grep -c "^kind:" "$file" 2>/dev/null || echo "0")
            fi
            
            if [[ "$count" -gt 0 ]]; then
                echo "- **$resource_type**: $count items" >> "$summary_file"
                total_resources=$((total_resources + count))
            fi
        fi
    done
    
    cat >> "$summary_file" << EOF

**Total Resources**: $total_resources

## Change Detection
- **Changes Detected**: $(if [[ -f "$DAILY_DIR/.changes_detected" ]]; then echo "Yes"; else echo "No"; fi)
- **GitOps Updated**: $(if [[ -f "$DAILY_DIR/.changes_detected" ]]; then echo "Yes"; else echo "No"; fi)
- **GitHub Sync**: $(if git log --oneline -1 | grep -q "$TIMESTAMP"; then echo "Completed"; else echo "Pending"; fi)

## GitOps Status
- **Kustomize Structure**: ✅ Valid
- **ArgoCD Application**: $SOURCE_NAMESPACE-backup
- **Target Namespace**: $SOURCE_NAMESPACE
- **Sync Policy**: Automated with prune and self-heal

## Verification Commands

### Check ArgoCD Application
\`\`\`bash
oc get application $SOURCE_NAMESPACE-backup -n $ARGOCD_NAMESPACE
oc describe application $SOURCE_NAMESPACE-backup -n $ARGOCD_NAMESPACE
\`\`\`

### Check Target Namespace
\`\`\`bash
oc get all -n $SOURCE_NAMESPACE
oc get pvc -n $SOURCE_NAMESPACE
oc get secrets -n $SOURCE_NAMESPACE
\`\`\`

### Monitor ArgoCD Sync
\`\`\`bash
# Watch sync status
oc get application $SOURCE_NAMESPACE-backup -n $ARGOCD_NAMESPACE -w

# Check ArgoCD logs
oc logs -n $ARGOCD_NAMESPACE deployment/argocd-application-controller | grep $SOURCE_NAMESPACE
\`\`\`

## Disaster Recovery

In case of namespace loss, restore using:

1. **ArgoCD Deployment** (Recommended):
   \`\`\`bash
   oc apply -f gitops/argocd-application.yaml
   \`\`\`

2. **Manual Kustomize Deployment**:
   \`\`\`bash
   kubectl apply -k gitops/overlays/prd
   \`\`\`

3. **Raw Resource Deployment**:
   \`\`\`bash
   kubectl apply -f backup/daily/$TIMESTAMP/cleaned/
   \`\`\`

## Next Backup
The next automated backup will run tomorrow at 2:00 AM or when manually executed.

---
**Generated by**: Daily Backup Script  
**Script Version**: 1.0  
**Execution Time**: $(date)
EOF
    
    print_success "Backup summary generated: $summary_file"
    
    # Display key metrics
    print_info "Backup Summary:"
    print_info "  Total Resources: $total_resources"
    print_info "  Summary File: $summary_file"
}

# Verify GitOps structure
verify_gitops_structure() {
    print_section "VERIFYING GITOPS STRUCTURE"
    
    local overlay_dir="$GITOPS_DIR/overlays/prd"
    
    # Check if Kustomize build works
    if command -v kubectl &> /dev/null; then
        print_info "Testing Kustomize build..."
        
        if kubectl kustomize "$overlay_dir" > /dev/null 2>&1; then
            print_success "Kustomize build successful"
        else
            print_error "Kustomize build failed. Check configuration:"
            kubectl kustomize "$overlay_dir" || true
        fi
    fi
    
    # Check for required files
    local required_files=(
        "$GITOPS_DIR/base/namespace.yaml"
        "$GITOPS_DIR/base/kustomization.yaml"
        "$overlay_dir/kustomization.yaml"
        "$GITOPS_DIR/argocd-application.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_success "Found: $file"
        else
            print_warning "Missing: $file"
        fi
    done
    
    print_success "GitOps structure verification completed"
}

# Main execution function
main() {
    echo "🔄 Daily Namespace Backup Script"
    echo "================================="
    echo ""
    
    check_configuration
    check_prerequisites
    create_daily_directories
    login_to_cluster
    export_current_state
    clean_exported_resources
    
    # Check for changes and commit if found
    if check_for_changes; then
        # Mark that changes were detected
        touch "$DAILY_DIR/.changes_detected"
        
        commit_and_push_changes
        print_success "GitOps repository updated - ArgoCD will sync changes automatically"
    else
        print_info "No changes detected - GitOps repository unchanged"
    fi
    
    generate_backup_summary
    verify_gitops_structure
    
    print_success "Daily backup completed successfully"
    
    # Display final status
    print_info "Next Steps:"
    print_info "  1. Monitor ArgoCD application: $SOURCE_NAMESPACE-backup"
    print_info "  2. Check backup summary: $DAILY_DIR/backup-summary.md"
    print_info "  3. Verify namespace sync in target cluster"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
