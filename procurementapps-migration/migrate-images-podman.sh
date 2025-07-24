#!/bin/bash

# Procurement Apps Image Migration Script (Podman-only version)
# Migrates images from OCP4 internal registry to new Quay registry using only Podman

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Migration parameters
SOURCE_REGISTRY="default-route-openshift-image-registry.apps.ocp4.kohlerco.com"
TARGET_REGISTRY="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
NAMESPACE="procurementapps"
IMAGE_NAME="pm-procedures-webapp"
ROBOT_USER="procurementapps+robot"
ROBOT_TOKEN="VH0781F461803O8TYUUWADVAZMEU2CV1CENXZ24O21F7EC8I1KSPMTRDZLEJLFTG"

# Tags to migrate (key ones based on inventory)
TAGS_TO_MIGRATE=("latest" "test" "dev" "2025.04.01" "2025.03.31" "2025.03.30" "2025.03.29" "2025.03.28" "2024.12.13")

# Track migration results
SUCCESSFUL_MIGRATIONS=()
FAILED_MIGRATIONS=()

# Function to print colored output
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
    
    if ! command -v podman &> /dev/null; then
        print_error "podman command not found. Please install Podman."
        exit 1
    fi
    
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login'"
        exit 1
    fi
    
    CURRENT_SERVER=$(oc whoami --show-server)
    print_info "Current cluster: $CURRENT_SERVER"
    
    if [[ "$CURRENT_SERVER" != *"ocp4"* ]]; then
        print_error "Please run this script while logged into OCP4 cluster"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Login to registries
login_registries() {
    print_section "LOGGING INTO REGISTRIES"
    
    # Get OCP token for source registry
    OCP_TOKEN=$(oc whoami -t)
    if [ -z "$OCP_TOKEN" ]; then
        print_error "Could not get OpenShift token"
        exit 1
    fi
    
    # Login to source registry (OCP4 internal)
    print_info "Logging into source registry..."
    echo "$OCP_TOKEN" | podman login -u="$(oc whoami)" --password-stdin "$SOURCE_REGISTRY"
    
    # Login to target Quay registry
    print_info "Logging into target Quay registry..."
    echo "$ROBOT_TOKEN" | podman login -u="$ROBOT_USER" --password-stdin "$TARGET_REGISTRY"
    
    print_success "Successfully logged into both registries"
}

# Create namespace in target repository if needed
create_target_namespace() {
    print_section "PREPARING TARGET REPOSITORY"
    
    TARGET_REPO="$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    print_info "Target repository: $TARGET_REPO"
    print_info "Note: Ensure the repository exists in Quay UI or will be auto-created on first push"
}

# Migrate images using podman
migrate_images() {
    print_section "MIGRATING IMAGES"
    
    SOURCE_REPO="$SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    TARGET_REPO="$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    
    for TAG in "${TAGS_TO_MIGRATE[@]}"; do
        print_info "Processing tag: $TAG"
        
        SOURCE_IMAGE="$SOURCE_REPO:$TAG"
        TARGET_IMAGE="$TARGET_REPO:$TAG"
        
        print_info "  Pulling from: $SOURCE_IMAGE"
        
        # Pull from source
        if podman pull "$SOURCE_IMAGE"; then
            print_success "  ✓ Pulled from source"
            
            # Tag for target
            print_info "  Tagging for target: $TARGET_IMAGE"
            if podman tag "$SOURCE_IMAGE" "$TARGET_IMAGE"; then
                print_success "  ✓ Tagged for target"
                
                # Push to target
                print_info "  Pushing to: $TARGET_IMAGE"
                if podman push "$TARGET_IMAGE"; then
                    print_success "  ✓ Successfully migrated: $TAG"
                    SUCCESSFUL_MIGRATIONS+=("$TAG")
                    
                    # Clean up local images to save space
                    podman rmi "$SOURCE_IMAGE" "$TARGET_IMAGE" >/dev/null 2>&1 || true
                else
                    print_error "  ✗ Failed to push: $TAG"
                    FAILED_MIGRATIONS+=("$TAG")
                fi
            else
                print_error "  ✗ Failed to tag: $TAG"
                FAILED_MIGRATIONS+=("$TAG")
            fi
        else
            print_error "  ✗ Failed to pull: $TAG"
            FAILED_MIGRATIONS+=("$TAG")
        fi
        
        echo
    done
}

# Verify migrated images
verify_migration() {
    print_section "VERIFYING MIGRATION"
    
    TARGET_REPO="$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    
    for TAG in "${SUCCESSFUL_MIGRATIONS[@]}"; do
        print_info "Verifying tag: $TAG"
        
        TARGET_IMAGE="$TARGET_REPO:$TAG"
        if podman pull "$TARGET_IMAGE" >/dev/null 2>&1; then
            print_success "  ✓ Verified: $TAG"
            # Clean up verification pull
            podman rmi "$TARGET_IMAGE" >/dev/null 2>&1 || true
        else
            print_error "  ✗ Verification failed: $TAG"
        fi
    done
}

# Update GitOps configuration
update_gitops() {
    print_section "UPDATING GITOPS CONFIGURATION"
    
    KUSTOMIZATION_FILE="../gitops/overlays/prd/kustomization.yaml"
    
    if [[ -f "$KUSTOMIZATION_FILE" ]]; then
        print_info "Updating image references in $KUSTOMIZATION_FILE"
        
        # Create backup
        cp "$KUSTOMIZATION_FILE" "$KUSTOMIZATION_FILE.backup"
        
        # Update image reference
        sed -i "s|quay.openshiftocp4.kohlerco.com/procurementapps/pm-procedures-webapp|$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME|g" "$KUSTOMIZATION_FILE"
        
        print_success "Updated GitOps configuration"
        print_info "Backup created: $KUSTOMIZATION_FILE.backup"
        
        # Show the change
        print_info "Updated image reference:"
        grep "newName:" "$KUSTOMIZATION_FILE" || print_info "Image reference updated"
    else
        print_error "Kustomization file not found: $KUSTOMIZATION_FILE"
        print_info "You'll need to manually update image references in your GitOps files"
    fi
}

# Generate migration summary
generate_summary() {
    print_section "GENERATING MIGRATION SUMMARY"
    
    MIGRATION_DATE=$(date)
    TOTAL_ATTEMPTED=${#TAGS_TO_MIGRATE[@]}
    TOTAL_SUCCESS=${#SUCCESSFUL_MIGRATIONS[@]}
    TOTAL_FAILED=${#FAILED_MIGRATIONS[@]}
    
    cat > "IMAGE-MIGRATION-SUMMARY.md" << EOF
# 📦 Image Migration Summary

## Migration Details

**Date**: $MIGRATION_DATE
**Source Registry**: $SOURCE_REGISTRY
**Target Registry**: $TARGET_REGISTRY
**Repository**: $NAMESPACE/$IMAGE_NAME

## Migration Results

- **Total Tags Attempted**: $TOTAL_ATTEMPTED
- **Successful Migrations**: $TOTAL_SUCCESS
- **Failed Migrations**: $TOTAL_FAILED

### ✅ Successfully Migrated Images

$(for TAG in "${SUCCESSFUL_MIGRATIONS[@]}"; do
    echo "- **$TAG**: \`$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG\`"
done)

$(if [ ${#FAILED_MIGRATIONS[@]} -gt 0 ]; then
    echo "### ❌ Failed Migrations"
    echo
    for TAG in "${FAILED_MIGRATIONS[@]}"; do
        echo "- **$TAG**: Migration failed - manual intervention required"
    done
    echo
fi)

## Registry Access

### Target Quay Registry
- **URL**: https://$TARGET_REGISTRY
- **Namespace**: $NAMESPACE
- **Robot Account**: $ROBOT_USER
- **Repository**: $NAMESPACE/$IMAGE_NAME

### Pull Command Examples
\`\`\`bash
# Pull latest
podman pull $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest

# Pull specific version
podman pull $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:2025.04.01
\`\`\`

### Registry Login
\`\`\`bash
# Login to new Quay registry
podman login -u="$ROBOT_USER" -p="TOKEN" $TARGET_REGISTRY
\`\`\`

## GitOps Configuration

The GitOps configuration has been updated to use the new registry:

### Updated Files
- \`gitops/overlays/prd/kustomization.yaml\`: Image references updated

### New Image Reference
\`\`\`yaml
images:
  - name: image-registry.openshift-image-registry.svc:5000/procurementapps/pm-procedures-webapp
    newName: $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME
    newTag: latest
\`\`\`

## Verification

To verify the migration:
\`\`\`bash
# Test pull from new registry
podman pull $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest

# Inspect image
podman inspect $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest
\`\`\`

## Next Steps

1. **Commit GitOps Changes**: Commit the updated kustomization.yaml to Git
2. **Update ArgoCD**: Sync the application to use new images
3. **Test Deployment**: Verify the application deploys correctly with new images
4. **Update CI/CD**: Configure build pipelines to push to new Quay registry
5. **Clean Up**: Remove old images from OCP4 registry if desired

$(if [ ${#FAILED_MIGRATIONS[@]} -gt 0 ]; then
    echo "## 🔧 Manual Migration Required"
    echo
    echo "The following tags failed automatic migration and need manual attention:"
    for TAG in "${FAILED_MIGRATIONS[@]}"; do
        echo "- **$TAG**"
    done
    echo
    echo "Manual migration steps:"
    echo '```bash'
    echo "# For each failed tag, try:"
    echo "podman pull $SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME:TAG"
    echo "podman tag $SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME:TAG $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:TAG"
    echo "podman push $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:TAG"
    echo '```'
fi)

---

**Migration Status**: $(if [ $TOTAL_FAILED -eq 0 ]; then echo "✅ Completed Successfully"; else echo "⚠️ Partially Completed - Manual intervention required"; fi)
EOF
    
    print_success "Migration summary created: IMAGE-MIGRATION-SUMMARY.md"
}

# Main function
main() {
    print_section "PROCUREMENT APPS IMAGE MIGRATION"
    print_info "Migrating images from OCP4 internal registry to Quay"
    print_info "Source: $SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    print_info "Target: $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    print_info "Tags to migrate: ${TAGS_TO_MIGRATE[*]}"
    
    check_prerequisites
    login_registries
    create_target_namespace
    migrate_images
    verify_migration
    update_gitops
    generate_summary
    
    print_section "MIGRATION COMPLETED"
    
    if [ ${#FAILED_MIGRATIONS[@]} -eq 0 ]; then
        print_success "🎉 All images migrated successfully!"
    else
        print_error "⚠️ Migration partially completed. ${#FAILED_MIGRATIONS[@]} tags failed."
        print_info "Failed tags: ${FAILED_MIGRATIONS[*]}"
    fi
    
    echo
    print_info "📁 Summary: IMAGE-MIGRATION-SUMMARY.md"
    print_info "🔄 GitOps updated: gitops/overlays/prd/kustomization.yaml"
    print_info "📦 Images available at: $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    echo
    print_info "Next steps:"
    print_info "1. Review the migration summary"
    print_info "2. Commit GitOps changes to Git"
    print_info "3. Deploy updated application via ArgoCD"
    print_info "4. Verify application functionality"
    
    if [ ${#FAILED_MIGRATIONS[@]} -gt 0 ]; then
        echo
        print_info "5. Manually migrate failed tags (see summary for details)"
    fi
}

# Run the migration
main "$@"
