#!/bin/bash

# Procurement Apps Image Migration Script (OpenShift oc image mirror version)
# Migrates images from OCP4 internal registry to new Quay registry using oc command

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Migration parameters
SOURCE_REGISTRY="default-route-openshift-image-registry.apps.ocp4.kohlerco.com"
SOURCE_REGISTRY_EXTERNAL="default-route-openshift-image-registry.apps.ocp4.kohlerco.com"
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
    
    # Check if oc image mirror is available
    if ! oc image --help | grep -q mirror; then
        print_error "oc image mirror command not available"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Setup registry authentication using service account secret
setup_registry_auth() {
    print_section "SETTING UP REGISTRY AUTHENTICATION"
    
    # Extract service account dockercfg secret
    print_info "Extracting service account Docker config..."
    oc get secret useroot-dockercfg-tvmxn -n procurementapps -o jsonpath='{.data.\.dockercfg}' | base64 -d > serviceaccount-dockercfg.json
    
    # Create enhanced auth config with both source and target registries
    QUAY_AUTH_FILE="registry-auth.json"
    
    # Extract the existing auth for source registry
    SOURCE_AUTH=$(cat serviceaccount-dockercfg.json | jq -r '."default-route-openshift-image-registry.apps.ocp4.kohlerco.com".auth')
    
    # Create combined Docker auth config
    cat > "$QUAY_AUTH_FILE" << EOF
{
  "auths": {
    "default-route-openshift-image-registry.apps.ocp4.kohlerco.com": {
      "auth": "$SOURCE_AUTH"
    },
    "$TARGET_REGISTRY": {
      "auth": "$(echo -n "$ROBOT_USER:$ROBOT_TOKEN" | base64 -w 0)"
    }
  }
}
EOF
    
    print_success "Registry authentication configured: $QUAY_AUTH_FILE"
    print_info "Using service account authentication for source registry"
    print_info "Using robot account authentication for target registry"
}

# Create image mapping file for bulk migration
create_image_mapping() {
    print_section "CREATING IMAGE MAPPING"
    
    MAPPING_FILE="image-mapping.txt"
    
    # Clear existing mapping file
    > "$MAPPING_FILE"
    
    # Create mapping for each tag
    for TAG in "${TAGS_TO_MIGRATE[@]}"; do
        SOURCE_IMAGE="$SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
        TARGET_IMAGE="$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
        
        echo "$SOURCE_IMAGE=$TARGET_IMAGE" >> "$MAPPING_FILE"
        print_info "Added mapping: $TAG"
    done
    
    print_success "Image mapping created: $MAPPING_FILE"
    print_info "Mapping contains ${#TAGS_TO_MIGRATE[@]} images"
}

# Migrate images using oc image mirror
migrate_images() {
    print_section "MIGRATING IMAGES"
    
    print_info "Starting bulk image migration..."
    print_info "Source: $SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    print_info "Target: $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    
        # Perform the migration
        if oc image mirror \
            --from-dir=/tmp/mirror \
            --registry-config="$QUAY_AUTH_FILE" \
            --filename="image-mapping.txt" \
            --dry-run=false \
            --force \
            --skip-multiple-scopes \
            --continue-on-error; then        print_success "Bulk migration completed"
        
        # Since oc image mirror is bulk operation, assume all succeeded
        # Individual verification will confirm actual status
        SUCCESSFUL_MIGRATIONS=("${TAGS_TO_MIGRATE[@]}")
    else
        print_error "Bulk migration encountered errors"
        print_info "Will attempt individual migrations..."
        
        # Try individual migrations
        migrate_images_individually
    fi
}

# Fallback: migrate images one by one
migrate_images_individually() {
    print_section "INDIVIDUAL IMAGE MIGRATION"
    
    for TAG in "${TAGS_TO_MIGRATE[@]}"; do
        print_info "Migrating tag: $TAG"
        
        SOURCE_IMAGE="$SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
        TARGET_IMAGE="$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
        
        # Create single image mapping
        echo "$SOURCE_IMAGE=$TARGET_IMAGE" > "single-mapping.txt"
        
        if oc image mirror \
            --registry-config="$QUAY_AUTH_FILE" \
            --filename="single-mapping.txt" \
            --dry-run=false \
            --force; then
            
            print_success "  ✓ Successfully migrated: $TAG"
            SUCCESSFUL_MIGRATIONS+=("$TAG")
        else
            print_error "  ✗ Failed to migrate: $TAG"
            FAILED_MIGRATIONS+=("$TAG")
        fi
        
        # Clean up single mapping file
        rm -f "single-mapping.txt"
    done
}

# Verify migrated images
verify_migration() {
    print_section "VERIFYING MIGRATION"
    
    for TAG in "${SUCCESSFUL_MIGRATIONS[@]}"; do
        print_info "Verifying tag: $TAG"
        
        TARGET_IMAGE="$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
        
        # Use oc image info to verify
        if oc image info --registry-config="$QUAY_AUTH_FILE" "$TARGET_IMAGE" >/dev/null 2>&1; then
            print_success "  ✓ Verified: $TAG"
        else
            print_error "  ✗ Verification failed: $TAG"
            # Move to failed list
            FAILED_MIGRATIONS+=("$TAG")
            SUCCESSFUL_MIGRATIONS=("${SUCCESSFUL_MIGRATIONS[@]/$TAG}")
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
**Source Registry**: $SOURCE_REGISTRY_EXTERNAL
**Target Registry**: $TARGET_REGISTRY
**Repository**: $NAMESPACE/$IMAGE_NAME
**Migration Method**: OpenShift \`oc image mirror\`

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
# Using oc
oc image info $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest

# Using podman (if available)
podman pull $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest
\`\`\`

### Registry Login for Manual Operations
\`\`\`bash
# Login to new Quay registry
podman login -u="$ROBOT_USER" -p="$ROBOT_TOKEN" $TARGET_REGISTRY
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

## Migration Files Generated

- \`quay-auth.json\`: Registry authentication configuration
- \`image-mapping.txt\`: Complete image mapping for bulk migration
- \`IMAGE-MIGRATION-SUMMARY.md\`: This summary document

## Verification

To verify the migration:
\`\`\`bash
# Check image exists in new registry
oc image info --registry-config=quay-auth.json $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest

# Test with different tags
oc image info --registry-config=quay-auth.json $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:test
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
    echo "oc image mirror \\"
    echo "  --registry-config=quay-auth.json \\"
    echo "  $SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME:TAG=$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:TAG"
    echo '```'
fi)

## Troubleshooting

If you encounter issues:

1. **Authentication Problems**: Verify robot account credentials in Quay UI
2. **Network Issues**: Check connectivity to target registry
3. **Repository Not Found**: Create repository in Quay UI first
4. **Permission Denied**: Verify robot account has push permissions

### Manual Verification Commands
\`\`\`bash
# Check source image exists
oc get imagestream $IMAGE_NAME -n $NAMESPACE

# Check target registry connectivity
curl -k https://$TARGET_REGISTRY/v2/

# Manual single image migration
oc image mirror \\
  --registry-config=quay-auth.json \\
  $SOURCE_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest=$TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME:latest
\`\`\`

---

**Migration Status**: $(if [ $TOTAL_FAILED -eq 0 ]; then echo "✅ Completed Successfully"; else echo "⚠️ Partially Completed - Manual intervention required"; fi)
EOF
    
    print_success "Migration summary created: IMAGE-MIGRATION-SUMMARY.md"
}

# Cleanup temporary files
cleanup() {
    print_section "CLEANUP"
    
    # Keep important files, remove temporary ones
    rm -f single-mapping.txt
    
    print_info "Keeping migration artifacts:"
    print_info "  - quay-auth.json (registry authentication)"
    print_info "  - image-mapping.txt (image mapping)"
    print_info "  - IMAGE-MIGRATION-SUMMARY.md (summary)"
}

# Main function
main() {
    print_section "PROCUREMENT APPS IMAGE MIGRATION"
    print_info "Migrating images from OCP4 internal registry to Quay"
    print_info "Source: $SOURCE_REGISTRY_EXTERNAL/$NAMESPACE/$IMAGE_NAME"
    print_info "Target: $TARGET_REGISTRY/$NAMESPACE/$IMAGE_NAME"
    print_info "Tags to migrate: ${TAGS_TO_MIGRATE[*]}"
    print_info "Method: OpenShift oc image mirror"
    
    check_prerequisites
    setup_registry_auth
    create_image_mapping
    migrate_images
    verify_migration
    update_gitops
    generate_summary
    cleanup
    
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
    print_info "🔐 Auth config: quay-auth.json"
    print_info "🗺️ Image mapping: image-mapping.txt"
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
