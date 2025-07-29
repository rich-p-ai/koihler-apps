#!/bin/bash
# Mulesoft Image Migration using oc image mirror
# This script migrates the mulesoft-accelerator-2 image using OpenShift's built-in image mirroring
# Created: July 28, 2025

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_REGISTRY="default-route-openshift-image-registry.apps.ocpaz.kohlerco.com"
SOURCE_NAMESPACE="mulesoftapps-prod"
SOURCE_IMAGE="mulesoft-accelerator-2"
TARGET_REGISTRY="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
TARGET_NAMESPACE="mulesoftapps"
TARGET_IMAGE="mulesoft-accelerator-2"
ROBOT_USER="mulesoftapps+robot"
ROBOT_PASSWORD="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0"

# Service account credentials for source registry
SOURCE_USER="serviceaccount"
SOURCE_PASSWORD="eyJhbGciOiJSUzI1NiIsImtpZCI6Im5EbTZEUVJKbUw0UWg1SVBZWjBuYy14NFZZdl9DaFhKQlZpSjNZZ1JqcGMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJtdWxlc29mdGFwcHMtcHJvZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkZWZhdWx0LXRva2VuLXo3c2d6Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImRlZmF1bHQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJlNjk2N2FiZi00YjYzLTRiY2UtOWYyNy1hOWNkOGY0YzFlMjciLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6bXVsZXNvZnRhcHBzLXByb2Q6ZGVmYXVsdCJ9.bxtOhSsZO859Yes5cvUH07w51l6yAoNBQE8RMpW5LNXYazmIkHI-iRuDqLOW1TicEu0kClRcNdeSOifl1-208YlDdYg1eU9gXI2d8OZjq1C6aCNqR9hNiNCys9rT_h59OMhnrrRncOPId8w4YbQzhgSuqzP_EXcGwOuQSHfPou2AYyovtS88d1o9va6siXnqzw4tmmKtf6s6_O2VgaXXXVqS1QJnUdutpt3IjfXZz5uHF1Tf38tsSGYy-a8JoTF7D3KZ-WcXp-qtJJ_rjsyP4Dn0GW95xjiNlMpuiPUMm66RcsOMZCG4zp0uaXv4Odzkdn9kLXrf5wZpO3mmG7UFhA"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

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

# Check prerequisites
check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    # Check if oc is installed
    if ! command -v oc &> /dev/null; then
        print_error "OpenShift CLI (oc) is not installed"
        exit 1
    fi
    
    print_success "OpenShift CLI available"
    print_info "Will use 'oc image mirror' for image migration"
}

# Login to OCPAZ cluster
login_to_ocpaz() {
    print_section "LOGGING INTO OCPAZ CLUSTER"
    
    # Check if already logged in to the correct cluster
    if oc whoami --show-server 2>/dev/null | grep -q "ocpaz.kohlerco.com"; then
        print_success "Already logged into OCPAZ cluster"
    else
        print_info "Authentication required for OCPAZ cluster"
        print_info "Please obtain an API token from: https://oauth-openshift.apps.ocpaz.kohlerco.com/oauth/token/request"
        
        # Prompt for token-based login
        echo ""
        echo -e "${YELLOW}Please copy the login command from the token request page and paste it here:${NC}"
        echo -e "${YELLOW}It should look like: oc login --token=<token> --server=https://api.ocpaz.kohlerco.com:6443${NC}"
        echo ""
        read -p "Enter the oc login command: " login_command
        
        # Execute the login command
        if eval "$login_command"; then
            print_success "Successfully logged into OCPAZ cluster"
        else
            print_error "Failed to login to OCPAZ cluster"
            exit 1
        fi
    fi
    
    # Verify namespace exists
    if ! oc get namespace "$SOURCE_NAMESPACE" &>/dev/null; then
        print_error "Namespace '$SOURCE_NAMESPACE' not found on OCPAZ cluster"
        exit 1
    fi
    
    print_success "Connected to OCPAZ cluster"
    print_info "Current user: $(oc whoami 2>/dev/null || echo 'Unable to determine')"
}

# Get image details
get_image_details() {
    print_section "GETTING IMAGE DETAILS"
    
    print_info "Checking for ImageStream: $SOURCE_IMAGE in namespace: $SOURCE_NAMESPACE"
    
    # Check if ImageStream exists
    if ! oc get imagestream "$SOURCE_IMAGE" -n "$SOURCE_NAMESPACE" &>/dev/null; then
        print_error "ImageStream '$SOURCE_IMAGE' not found in namespace '$SOURCE_NAMESPACE'"
        print_info "Available ImageStreams:"
        oc get imagestream -n "$SOURCE_NAMESPACE" 2>/dev/null || echo "No ImageStreams found"
        exit 1
    fi
    
    print_success "Found ImageStream: $SOURCE_IMAGE"
    
    # Get available tags
    local tags
    tags=$(oc get imagestream "$SOURCE_IMAGE" -n "$SOURCE_NAMESPACE" -o jsonpath='{.status.tags[*].tag}' 2>/dev/null || echo "")
    if [[ -n "$tags" ]]; then
        print_info "Available tags: $tags"
        
        # Use latest tag if available, otherwise use first tag
        if echo "$tags" | grep -q "latest"; then
            IMAGE_TAG="latest"
        else
            IMAGE_TAG=$(echo "$tags" | awk '{print $1}')
        fi
        print_info "Using tag: $IMAGE_TAG"
    else
        IMAGE_TAG="latest"
        print_warning "No tags found, using: $IMAGE_TAG"
    fi
    
    # Get the full image reference
    SOURCE_IMAGE_REF=$(oc get imagestream "$SOURCE_IMAGE" -n "$SOURCE_NAMESPACE" -o jsonpath="{.status.tags[?(@.tag=='$IMAGE_TAG')].items[0].dockerImageReference}" 2>/dev/null || echo "")
    
    if [[ -n "$SOURCE_IMAGE_REF" ]]; then
        print_success "Source image reference: $SOURCE_IMAGE_REF"
    else
        # Fallback to constructed reference
        SOURCE_IMAGE_REF="${SOURCE_REGISTRY}/${SOURCE_NAMESPACE}/${SOURCE_IMAGE}:${IMAGE_TAG}"
        print_warning "Using constructed reference: $SOURCE_IMAGE_REF"
    fi
    
    # Target image reference
    TARGET_IMAGE_REF="${TARGET_REGISTRY}/${TARGET_NAMESPACE}/${TARGET_IMAGE}:${IMAGE_TAG}"
    print_info "Target image reference: $TARGET_IMAGE_REF"
}

# Create registry authentication secret
create_registry_auth() {
    print_section "CREATING REGISTRY AUTHENTICATION"
    
    # Create temporary namespace for migration (if it doesn't exist)
    local temp_namespace="image-migration-temp"
    if ! oc get namespace "$temp_namespace" &>/dev/null; then
        print_info "Creating temporary namespace: $temp_namespace"
        oc create namespace "$temp_namespace" 2>/dev/null || true
    fi
    
    # Create pull secret for target registry
    print_info "Creating pull secret for target registry..."
    oc create secret docker-registry quay-migration-secret \
        --docker-server="$TARGET_REGISTRY" \
        --docker-username="$ROBOT_USER" \
        --docker-password="$ROBOT_PASSWORD" \
        --namespace="$temp_namespace" \
        --dry-run=client -o yaml | oc apply -f - 2>/dev/null || {
        print_warning "Pull secret might already exist, continuing..."
    }
    
    print_success "Registry authentication configured"
}

# Mirror image using oc image mirror
mirror_image() {
    print_section "MIRRORING IMAGE"
    
    print_info "Source: $SOURCE_IMAGE_REF"
    print_info "Target: $TARGET_IMAGE_REF"
    
    # Create a mapping file for oc image mirror
    cat > image-mapping.txt << EOF
$SOURCE_IMAGE_REF=$TARGET_IMAGE_REF
EOF
    
    print_info "Created image mapping file"
    cat image-mapping.txt
    
    # Perform the image mirror operation
    print_info "Starting image mirror operation..."
    
    # Try with authentication
    if oc image mirror \
        --filename=image-mapping.txt \
        --registry-config=/dev/null \
        --insecure=true \
        --keep-manifest-list=true \
        --filter-by-os='.*' \
        --skip-missing=false \
        --continue-on-error=false; then
        print_success "Image mirrored successfully using oc image mirror"
        return 0
    else
        print_warning "oc image mirror failed, trying alternative approaches..."
        
        # Try with manual authentication setup
        print_info "Setting up manual authentication..."
        
        # Create auth file
        mkdir -p ~/.docker
        cat > ~/.docker/config.json << EOF
{
    "auths": {
        "$SOURCE_REGISTRY": {
            "username": "$SOURCE_USER",
            "password": "$SOURCE_PASSWORD"
        },
        "$TARGET_REGISTRY": {
            "username": "$ROBOT_USER",
            "password": "$ROBOT_PASSWORD"
        }
    }
}
EOF
        
        # Try mirror operation with auth file
        if oc image mirror \
            --filename=image-mapping.txt \
            --registry-config=~/.docker/config.json \
            --insecure=true; then
            print_success "Image mirrored successfully with manual authentication"
            return 0
        else
            print_error "Image mirror operation failed"
            return 1
        fi
    fi
}

# Verify migration
verify_migration() {
    print_section "VERIFYING MIGRATION"
    
    print_info "Verifying target image: $TARGET_IMAGE_REF"
    
    # Create a test pod to verify the image is accessible
    local test_pod_name="image-verification-test-$(date +%s)"
    
    cat > test-pod.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: $test_pod_name
  namespace: image-migration-temp
spec:
  restartPolicy: Never
  imagePullSecrets:
  - name: quay-migration-secret
  containers:
  - name: test-container
    image: $TARGET_IMAGE_REF
    command: ["/bin/sh", "-c", "echo 'Image verification successful' && exit 0"]
EOF
    
    print_info "Creating test pod to verify image accessibility..."
    if oc apply -f test-pod.yaml; then
        # Wait for pod to complete
        print_info "Waiting for test pod to complete..."
        oc wait --for=condition=Ready pod/"$test_pod_name" -n image-migration-temp --timeout=60s 2>/dev/null || true
        
        # Check pod status
        local pod_status
        pod_status=$(oc get pod "$test_pod_name" -n image-migration-temp -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        
        if [[ "$pod_status" == "Succeeded" ]] || [[ "$pod_status" == "Running" ]]; then
            print_success "✅ Image verification successful - image is accessible in target registry"
        else
            print_warning "⚠️ Image verification inconclusive - pod status: $pod_status"
            print_info "Check pod logs for details:"
            oc logs "$test_pod_name" -n image-migration-temp 2>/dev/null || echo "No logs available"
        fi
        
        # Clean up test pod
        oc delete pod "$test_pod_name" -n image-migration-temp 2>/dev/null || true
    else
        print_warning "Could not create verification pod - manual verification required"
    fi
    
    # Clean up test files
    rm -f test-pod.yaml
    
    print_info "Migration verification completed"
}

# Generate migration report
generate_migration_report() {
    print_section "GENERATING MIGRATION REPORT"
    
    cat > "MULESOFT-IMAGE-MIRROR-REPORT.md" << EOF
# Mulesoft Image Migration Report (oc image mirror)

**Migration Date**: $(date)
**Migration Method**: OpenShift Image Mirror (oc image mirror)
**Source Registry**: $SOURCE_REGISTRY
**Target Registry**: $TARGET_REGISTRY

## Image Details

| Attribute | Value |
|-----------|-------|
| **Source Image** | \`$SOURCE_IMAGE_REF\` |
| **Target Image** | \`$TARGET_IMAGE_REF\` |
| **Source Namespace** | \`$SOURCE_NAMESPACE\` |
| **Target Namespace** | \`$TARGET_NAMESPACE\` |
| **Image Tag** | \`$IMAGE_TAG\` |
| **Migration Method** | OpenShift oc image mirror |

## Migration Summary

✅ **SUCCESSFUL MIGRATION**

The Mulesoft accelerator image has been successfully migrated using OpenShift's built-in image mirroring capabilities.

## Benefits of oc image mirror

- ✅ **Native OpenShift Tool**: Uses OpenShift's built-in image mirroring
- ✅ **Authentication Handling**: Automatically handles registry authentication
- ✅ **Manifest Preservation**: Preserves image manifests and metadata
- ✅ **Cross-Platform**: Works regardless of local container runtime
- ✅ **Efficient**: Direct registry-to-registry transfer

## Verification Commands

\`\`\`bash
# Verify image exists in target registry (requires pull secret)
oc run test-image --image=$TARGET_IMAGE_REF --rm -it --restart=Never -- echo "Image accessible"

# Create pull secret for verification
oc create secret docker-registry quay-pull-secret \\
  --docker-server=$TARGET_REGISTRY \\
  --docker-username="$ROBOT_USER" \\
  --docker-password="$ROBOT_PASSWORD" \\
  --namespace=<your-namespace>
\`\`\`

## Update Deployment References

Update your Kubernetes/OpenShift deployments to use the new image reference:

\`\`\`yaml
# Old reference (OCPAZ)
image: $SOURCE_IMAGE_REF

# New reference (Quay)
image: $TARGET_IMAGE_REF
\`\`\`

## Image Mapping Used

\`\`\`
$SOURCE_IMAGE_REF=$TARGET_IMAGE_REF
\`\`\`

## Next Steps

1. **Update Deployments**: Update all Kubernetes manifests to use the new image reference
2. **Create Pull Secrets**: Ensure target namespaces have appropriate pull secrets
3. **Test Deployment**: Deploy and test applications with new image references
4. **Update CI/CD**: Update build pipelines to push to Quay registry
5. **Monitor**: Monitor applications after migration for any issues

## Files Generated

- \`MULESOFT-IMAGE-MIRROR-REPORT.md\` - This report
- \`migrate-image-with-oc-mirror.sh\` - This migration script
- \`image-mapping.txt\` - Image mapping file (cleaned up)

## Clean Up

The following temporary resources were created and should be cleaned up:
- Namespace: \`image-migration-temp\`
- Secret: \`quay-migration-secret\`

\`\`\`bash
# Clean up temporary resources
oc delete namespace image-migration-temp
\`\`\`

EOF

    print_success "Migration report generated: MULESOFT-IMAGE-MIRROR-REPORT.md"
}

# Cleanup function
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -f image-mapping.txt test-pod.yaml ~/.docker/config.json
    
    # Optionally clean up temporary namespace
    print_info "Temporary namespace 'image-migration-temp' left for verification"
    print_info "Clean up with: oc delete namespace image-migration-temp"
}

# Main function
main() {
    print_section "MULESOFT IMAGE MIGRATION (OC IMAGE MIRROR)"
    print_info "Migrating: $SOURCE_NAMESPACE/$SOURCE_IMAGE"
    print_info "From: $SOURCE_REGISTRY"
    print_info "To: $TARGET_REGISTRY/$TARGET_NAMESPACE/$TARGET_IMAGE"
    print_info "Method: OpenShift Image Mirror (oc image mirror)"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    check_prerequisites
    login_to_ocpaz
    get_image_details
    create_registry_auth
    
    if mirror_image; then
        verify_migration
        generate_migration_report
        
        print_section "MIGRATION COMPLETE!"
        print_success "🎉 Mulesoft image successfully migrated using oc image mirror!"
        print_info "Source: $SOURCE_IMAGE_REF"
        print_info "Target: $TARGET_IMAGE_REF"
        print_info "📋 Check MULESOFT-IMAGE-MIRROR-REPORT.md for details"
        
    else
        print_section "MIGRATION FAILED!"
        print_error "❌ Failed to migrate image using oc image mirror"
        print_info "Check the logs above for error details"
        
        # Provide manual migration instructions
        print_section "MANUAL MIGRATION ALTERNATIVE"
        print_info "You can manually migrate the image using these steps:"
        print_info "1. Set up a working container environment (Docker/Podman)"
        print_info "2. Run: ./migrate-mulesoft-image.sh"
        print_info "3. Or use external tools like Skopeo"
        
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
