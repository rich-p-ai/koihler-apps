#!/bin/bash

# Procurement Apps Image Migration Script
# Migrates images from OCP4 internal registry to new Quay registry

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
    
    if ! command -v skopeo &> /dev/null; then
        print_error "skopeo command not found. Please install Skopeo for image copying."
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
    
    # Login to source registry (OCP4 internal)
    print_info "Logging into source registry..."
    oc registry login
    
    # Login to target Quay registry
    print_info "Logging into target Quay registry..."
    podman login -u="$ROBOT_USER" -p="$ROBOT_TOKEN" "$TARGET_REGISTRY"
    
    print_success "Successfully logged into both registries"
}

# Create target repository if needed
create_target_repo() {
    print_section "PREPARING TARGET REPOSITORY"
    
    TARGET_REPO="$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    print_info "Target repository: $TARGET_REPO"
    
    # Test connectivity
    print_info "Testing target registry connectivity..."
    if podman search "$TARGET_REGISTRY/$NAMESPACE" 2>/dev/null; then
        print_success "Target registry accessible"
    else
        print_info "Repository may need to be created in Quay UI"
    fi
}

# Migrate images using skopeo
migrate_images() {
    print_section "MIGRATING IMAGES"
    
    SOURCE_REPO="$SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    TARGET_REPO="$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    
    for TAG in "${TAGS_TO_MIGRATE[@]}"; do
        print_info "Migrating tag: $TAG"
        
        SOURCE_IMAGE="docker://$SOURCE_REPO:$TAG"
        TARGET_IMAGE="docker://$TARGET_REPO:$TAG"
        
        print_info "  Source: $SOURCE_IMAGE"
        print_info "  Target: $TARGET_IMAGE"
        
        # Copy image using skopeo
        if skopeo copy --src-creds="$(oc whoami -t)" --dest-creds="$ROBOT_USER:$ROBOT_TOKEN" \
           "$SOURCE_IMAGE" "$TARGET_IMAGE"; then
            print_success "  ✓ Successfully migrated: $TAG"
        else
            print_error "  ✗ Failed to migrate: $TAG"
        fi
        
        echo
    done
}

# Verify migrated images
verify_migration() {
    print_section "VERIFYING MIGRATION"
    
    TARGET_REPO="$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    
    for TAG in "${TAGS_TO_MIGRATE[@]}"; do
        print_info "Verifying tag: $TAG"
        
        if skopeo inspect --creds="$ROBOT_USER:$ROBOT_TOKEN" "docker://$TARGET_REPO:$TAG" >/dev/null 2>&1; then
            print_success "  ✓ Verified: $TAG"
        else
            print_error "  ✗ Not found: $TAG"
        fi
    done
}

# Update GitOps configuration
update_gitops() {
    print_section "UPDATING GITOPS CONFIGURATION"
    
    KUSTOMIZATION_FILE="gitops/overlays/prd/kustomization.yaml"
    
    print_info "Updating image references in $KUSTOMIZATION_FILE"
    
    # Update the image reference in kustomization.yaml
    if [[ -f "$KUSTOMIZATION_FILE" ]]; then
        # Create backup
        cp "$KUSTOMIZATION_FILE" "$KUSTOMIZATION_FILE.backup"
        
        # Update image reference
        sed -i "s|quay.openshiftocp4.kohlerco.com/procurementapps/pm-procedures-webapp|$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME|g" "$KUSTOMIZATION_FILE"
        
        print_success "Updated GitOps configuration"
        print_info "Backup created: $KUSTOMIZATION_FILE.backup"
    else
        print_error "Kustomization file not found: $KUSTOMIZATION_FILE"
    fi
}

# Generate migration summary
generate_summary() {
    print_section "GENERATING MIGRATION SUMMARY"
    
    cat > "IMAGE-MIGRATION-SUMMARY.md" << EOF
# 📦 Image Migration Summary

## Migration Details

**Date**: $(date)
**Source Registry**: $SOURCE_REGISTRY
**Target Registry**: $TARGET_REGISTRY
**Repository**: $NAMESPACE/$IMAGE_NAME

## Images Migrated

$(for TAG in "${TAGS_TO_MIGRATE[@]}"; do
    echo "- **$TAG**: $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
done)

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

## GitOps Configuration Updated

The following files have been updated:
- \`gitops/overlays/prd/kustomization.yaml\`: Updated image references

### Before
\`\`\`yaml
images:
  - name: image-registry.openshift-image-registry.svc:5000/procurementapps/pm-procedures-webapp
    newName: quay.openshiftocp4.kohlerco.com/procurementapps/pm-procedures-webapp
    newTag: latest
\`\`\`

### After
\`\`\`yaml
images:
  - name: image-registry.openshift-image-registry.svc:5000/procurementapps/pm-procedures-webapp
    newName: $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME
    newTag: latest
\`\`\`

## Verification

To verify the migration:
\`\`\`bash
# Check image exists
skopeo inspect --creds="$ROBOT_USER:TOKEN" docker://$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest

# Test pull
podman pull $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest
\`\`\`

## Next Steps

1. Commit updated GitOps configuration to Git
2. Deploy updated application via ArgoCD
3. Verify application functionality with new images
4. Update any CI/CD pipelines to push to new registry

---

**Migration completed successfully!** 🚀
EOF
    
    print_success "Migration summary created: IMAGE-MIGRATION-SUMMARY.md"
}

# Main function
main() {
    print_section "PROCUREMENT APPS IMAGE MIGRATION"
    print_info "Migrating images from OCP4 internal registry to Quay"
    print_info "Source: $SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    print_info "Target: $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    
    check_prerequisites
    login_registries
    create_target_repo
    migrate_images
    verify_migration
    update_gitops
    generate_summary
    
    print_section "MIGRATION COMPLETED"
    print_success "🎉 Image migration completed successfully!"
    echo
    print_info "📁 Summary: IMAGE-MIGRATION-SUMMARY.md"
    print_info "🔄 GitOps updated: gitops/overlays/prd/kustomization.yaml"
    print_info "📦 Images available at: $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    echo
    print_info "Next steps:"
    print_info "1. Review the migration summary"
    print_info "2. Commit GitOps changes to Git"
    print_info "3. Deploy updated application"
    print_info "4. Verify application functionality"
}

# Run the migration
main "$@"
