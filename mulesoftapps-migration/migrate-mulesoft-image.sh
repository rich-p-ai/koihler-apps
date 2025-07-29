#!/bin/bash
# Mulesoft Image Migration Script
# This script migrates the mulesoft-accelerator-2 image from OCPAZ to Quay registry
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
SOURCE_SECRET="default-dockercfg-8vvph"
TARGET_REGISTRY="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
TARGET_NAMESPACE="mulesoftapps"
TARGET_IMAGE="mulesoft-accelerator-2"
ROBOT_USER="mulesoftapps+robot"
ROBOT_PASSWORD="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0"
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
    
    # Check if podman/docker is installed
    if command -v podman &> /dev/null; then
        CONTAINER_TOOL="podman"
        print_info "Using podman for container operations"
    elif command -v docker &> /dev/null; then
        CONTAINER_TOOL="docker"
        print_info "Using docker for container operations"
    else
        print_error "Neither podman nor docker is installed"
        exit 1
    fi
    
    # Check if skopeo is installed (alternative method)
    if command -v skopeo &> /dev/null; then
        print_info "Skopeo available for direct registry-to-registry copy"
        SKOPEO_AVAILABLE=true
    else
        print_warning "Skopeo not available - will use podman/docker method"
        SKOPEO_AVAILABLE=false
    fi
    
    print_success "Prerequisites check passed"
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

# Set source registry credentials
set_source_credentials() {
    print_section "SETTING SOURCE REGISTRY CREDENTIALS"
    
    print_info "Using provided service account credentials for source registry"
    
    # Set the credentials directly from the provided information
    SOURCE_USER="serviceaccount"
    SOURCE_PASSWORD="eyJhbGciOiJSUzI1NiIsImtpZCI6Im5EbTZEUVJKbUw0UWg1SVBZWjBuYy14NFZZdl9DaFhKQlZpSjNZZ1JqcGMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJtdWxlc29mdGFwcHMtcHJvZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkZWZhdWx0LXRva2VuLXo3c2d6Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImRlZmF1bHQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJlNjk2N2FiZi00YjYzLTRiY2UtOWYyNy1hOWNkOGY0YzFlMjciLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6bXVsZXNvZnRhcHBzLXByb2Q6ZGVmYXVsdCJ9.bxtOhSsZO859Yes5cvUH07w51l6yAoNBQE8RMpW5LNXYazmIkHI-iRuDqLOW1TicEu0kClRcNdeSOifl1-208YlDdYg1eU9gXI2d8OZjq1C6aCNqR9hNiNCys9rT_h59OMhnrrRncOPId8w4YbQzhgSuqzP_EXcGwOuQSHfPou2AYyovtS88d1o9va6siXnqzw4tmmKtf6s6_O2VgaXXXVqS1QJnUdutpt3IjfXZz5uHF1Tf38tsSGYy-a8JoTF7D3KZ-WcXp-qtJJ_rjsyP4Dn0GW95xjiNlMpuiPUMm66RcsOMZCG4zp0uaXv4Odzkdn9kLXrf5wZpO3mmG7UFhA"
    SOURCE_AUTH="c2VydmljZWFjY291bnQ6ZXlKaGJHY2lPaUpTVXpJMU5pSXNJbXRwWkNJNkltNUViVFpFVVZKS2JVdzBVV2cxU1ZCWldqQnVZeTE0TkZaWmRsOURhRmhLUWxacFNqTlpaMUpxY0dNaWZRLmV5SnBjM01pT2lKcmRXSmxjbTVsZEdWekwzTmxjblpwWTJWaFkyTnZkVzUwSWl3aWEzVmlaWEp1WlhSbGN5NXBieTl6WlhKMmFXTmxZV05qYjNWdWRDOXVZVzFsYzNCaFkyVWlPaUp0ZFd4bGMyOW1kR0Z3Y0hNdGNISnZaQ0lzSW10MVltVnlibVYwWlhNdWFXOHZjMlZ5ZG1salpXRmpZMjkxYm5RdmMyVmpjbVYwTG01aGJXVWlPaUprWldaaGRXeDBMWFJ2YTJWdUxYbzNjMmQ2SWl3aWEzVmlaWEp1WlhSbGN5NXBieTl6WlhKMmFXTmxZV05qYjNWdWRDOXpaWEoyYVdObExXRmpZMjkxYm5RdWJtRnRaU0k2SW1SbFptRjFiSFFpTENKcmRXSmxjbTVsZEdWekxtbHZMM05sY25acFkyVmhZMk52ZFc1MEwzTmxjblpwWTJVdFlXTmpiM1Z1ZEM1MWFXUWlPaUpsTmprMk4yRmlaaTAwWWpZekxUUmlZMlV0T1dZeU55MWhPV05rT0dZMFl6RmxNamNpTENKemRXSWlPaUp6ZVhOMFpXMDZjMlZ5ZG1salpXRmpZMjkxYm5RNmJYVnNaWE52Wm5SaGNIQnpMWEJ5YjJRNlpHVm1ZWFZzZENKOS5ieHRPaFNzWk84NTlZZXM1Y3ZVSDA3dzUxbDZ5QW9OQlFFOFJNcFc1TE5YWWF6bUlrSEktaVJ1RHFMT1cxVGljRXUwa0NsUmNOZGVTT2lmbDEtMjA4WWxEZFlnMWVVOWdYSTJkOE9aanExQzZhQ05xUjloTmlOQ3lzOXJUX2g1OU9NaG5yclJuY09QSWQ4dzRZYlF6aGdTdXF6UF9FWGNHd091UVNIZlBvdTJBWXlvdnRTODhkMW85dmE2c2lYbnF6dzR0bW1LdGY2czZfTzJWZ2FYWFhWcVMxUUpuVWR1dHB0M0lqZlhaejV1SEYxVGYzOHRzU0dZeS1hOEpvVEY3RDNLWi1XY1hwLXF0SkpfcmpzeVA0RG4wR1c5NXhqaU5sTXB1aVBVTW02NlJjc09NWkNHNHpwMHVhWHY0T2R6a2RuOWtMWHJmNXdacE8zbW1HN1VGaEE="
    
    print_success "Source registry credentials set successfully"
    print_info "Username: $SOURCE_USER"
    print_info "Registry: $SOURCE_REGISTRY"
}

# List available images
list_available_images() {
    print_section "LISTING AVAILABLE IMAGES"
    
    print_info "Checking available images in namespace: $SOURCE_NAMESPACE"
    
    # List ImageStreams
    if oc get imagestream -n "$SOURCE_NAMESPACE" &>/dev/null; then
        print_info "Available ImageStreams:"
        oc get imagestream -n "$SOURCE_NAMESPACE" -o custom-columns="NAME:.metadata.name,TAGS:.status.tags[*].tag" 2>/dev/null || echo "No ImageStreams found"
    fi
    
    # Check for specific image
    if oc get imagestream "$SOURCE_IMAGE" -n "$SOURCE_NAMESPACE" &>/dev/null; then
        print_success "Found ImageStream: $SOURCE_IMAGE"
        
        # Get image tags
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
    else
        print_error "ImageStream '$SOURCE_IMAGE' not found in namespace '$SOURCE_NAMESPACE'"
        print_info "Available ImageStreams:"
        oc get imagestream -n "$SOURCE_NAMESPACE" 2>/dev/null || echo "No ImageStreams found"
        exit 1
    fi
}

# Get image SHA
get_image_sha() {
    print_section "RETRIEVING IMAGE SHA"
    
    local full_image_name="${SOURCE_REGISTRY}/${SOURCE_NAMESPACE}/${SOURCE_IMAGE}:${IMAGE_TAG}"
    print_info "Getting SHA for image: $full_image_name"
    
    # Get the image SHA from ImageStream
    IMAGE_SHA=$(oc get imagestream "$SOURCE_IMAGE" -n "$SOURCE_NAMESPACE" -o jsonpath="{.status.tags[?(@.tag=='$IMAGE_TAG')].items[0].dockerImageReference}" 2>/dev/null || echo "")
    
    if [[ -n "$IMAGE_SHA" ]]; then
        print_success "Image SHA found: $IMAGE_SHA"
        SOURCE_IMAGE_FULL="$IMAGE_SHA"
    else
        print_warning "Could not get SHA, using tag-based reference"
        SOURCE_IMAGE_FULL="$full_image_name"
    fi
    
    print_info "Source image: $SOURCE_IMAGE_FULL"
}

# Login to container registry
login_to_registries() {
    print_section "LOGGING INTO CONTAINER REGISTRIES"
    
    print_info "Logging into source registry: $SOURCE_REGISTRY"
    
    # Login to source registry using provided credentials
    if [[ -n "$SOURCE_USER" && -n "$SOURCE_PASSWORD" ]]; then
        if echo "$SOURCE_PASSWORD" | $CONTAINER_TOOL login --username "$SOURCE_USER" --password-stdin "$SOURCE_REGISTRY" 2>/dev/null; then
            print_success "Logged into source registry: $SOURCE_REGISTRY"
        else
            print_warning "Failed to login to source registry with provided credentials"
            print_info "Attempting fallback authentication methods..."
            
            # Try using oc to login to internal registry
            if oc registry login --insecure=true 2>/dev/null; then
                print_success "Logged into source registry via oc registry login"
            else
                print_warning "Could not authenticate to source registry"
            fi
        fi
    else
        print_warning "Source registry credentials not available"
    fi
    
    # Login to target registry
    print_info "Logging into target registry: $TARGET_REGISTRY"
    
    # Try different methods to login to Quay registry
    local quay_login_success=false
    
    # Method 1: Standard login
    if echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin "$TARGET_REGISTRY" 2>/dev/null; then
        print_success "Logged into target registry: $TARGET_REGISTRY"
        quay_login_success=true
    else
        print_warning "Standard login failed, trying alternative methods..."
        
        # Method 2: Try with insecure flag
        if echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin --tls-verify=false "$TARGET_REGISTRY" 2>/dev/null; then
            print_success "Logged into target registry with insecure flag: $TARGET_REGISTRY"
            quay_login_success=true
        else
            # Method 3: Try with different registry URL formats
            print_info "Trying alternative registry URL format..."
            local alt_registry="https://$TARGET_REGISTRY"
            if echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin "$alt_registry" 2>/dev/null; then
                print_success "Logged into target registry with https prefix: $alt_registry"
                quay_login_success=true
            else
                print_warning "All target registry login methods failed"
                print_info "Target registry: $TARGET_REGISTRY"
                print_info "Robot user: $ROBOT_USER"
                print_info "Password length: ${#ROBOT_PASSWORD} characters"
                
                # Show detailed error
                print_info "Attempting login with verbose output..."
                echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin "$TARGET_REGISTRY" || true
            fi
        fi
    fi
    
    if [[ "$quay_login_success" == "false" ]]; then
        print_error "Failed to login to target registry after all attempts"
        print_info "Please verify:"
        print_info "  1. Robot account credentials are correct"
        print_info "  2. Registry URL is accessible: $TARGET_REGISTRY"
        print_info "  3. Robot account has push permissions to mulesoftapps namespace"
        exit 1
    fi
}

# Method 1: Using skopeo for direct registry-to-registry copy
migrate_image_with_skopeo() {
    print_section "MIGRATING IMAGE WITH SKOPEO"
    
    local source_full="${SOURCE_IMAGE_FULL}"
    local target_full="${TARGET_REGISTRY}/${TARGET_NAMESPACE}/${TARGET_IMAGE}:${IMAGE_TAG}"
    
    print_info "Source: $source_full"
    print_info "Target: $target_full"
    
    # Create auth file for skopeo
    mkdir -p ~/.config/containers
    cat > ~/.config/containers/auth.json << EOF
{
    "auths": {
        "$SOURCE_REGISTRY": {
            "auth": "$SOURCE_AUTH"
        },
        "$TARGET_REGISTRY": {
            "auth": "$(echo -n "$ROBOT_USER:$ROBOT_PASSWORD" | base64)"
        }
    }
}
EOF
    
    # Copy image using skopeo with proper authentication
    print_info "Attempting skopeo copy with service account authentication..."
    if skopeo copy --src-tls-verify=false --dest-tls-verify=false \
        --src-creds="$SOURCE_USER:$SOURCE_PASSWORD" \
        --dest-creds="$ROBOT_USER:$ROBOT_PASSWORD" \
        "docker://$source_full" \
        "docker://$target_full"; then
        print_success "Image migrated successfully using skopeo"
        return 0
    else
        print_error "Failed to migrate image using skopeo"
        return 1
    fi
}

# Method 2: Using podman/docker pull and push
migrate_image_with_container_tool() {
    print_section "MIGRATING IMAGE WITH $CONTAINER_TOOL"
    
    local source_full="${SOURCE_IMAGE_FULL}"
    local target_full="${TARGET_REGISTRY}/${TARGET_NAMESPACE}/${TARGET_IMAGE}:${IMAGE_TAG}"
    
    print_info "Source: $source_full"
    print_info "Target: $target_full"
    
    # Pull image from source
    print_info "Pulling image from source registry..."
    
    # Try different pull methods
    local pull_success=false
    
    # Method 1: Direct pull with registry authentication
    if $CONTAINER_TOOL pull "$source_full" 2>/dev/null; then
        print_success "Image pulled successfully with existing authentication"
        pull_success=true
    else
        print_warning "Direct pull failed, trying alternative methods..."
        
        # Method 2: Use oc image mirror for internal registry images
        print_info "Attempting to use oc image mirror..."
        local temp_external_ref="${SOURCE_REGISTRY}/${SOURCE_NAMESPACE}/${SOURCE_IMAGE}:${IMAGE_TAG}"
        
        # Try to get the internal image reference
        local internal_ref=$(oc get imagestream "$SOURCE_IMAGE" -n "$SOURCE_NAMESPACE" -o jsonpath='{.status.dockerImageRepository}' 2>/dev/null || echo "")
        if [[ -n "$internal_ref" ]]; then
            local internal_full="${internal_ref}:${IMAGE_TAG}"
            print_info "Trying internal reference: $internal_full"
            
            if $CONTAINER_TOOL pull "$internal_full" 2>/dev/null; then
                print_success "Image pulled successfully using internal reference"
                # Re-tag to use external reference for consistency
                $CONTAINER_TOOL tag "$internal_full" "$source_full" 2>/dev/null || true
                pull_success=true
            fi
        fi
        
        # Method 3: Try with insecure registry flag
        if [[ "$pull_success" == "false" ]]; then
            print_info "Attempting insecure pull..."
            if $CONTAINER_TOOL pull --tls-verify=false "$source_full" 2>/dev/null; then
                print_success "Image pulled successfully with insecure flag"
                pull_success=true
            fi
        fi
    fi
    
    if [[ "$pull_success" == "false" ]]; then
        print_error "Failed to pull image from source registry using all methods"
        print_info "Available methods tried:"
        print_info "  1. Direct pull with authentication"
        print_info "  2. Internal registry reference"
        print_info "  3. Insecure pull"
        return 1
    fi
    
    # Tag for target registry
    print_info "Tagging image for target registry..."
    if $CONTAINER_TOOL tag "$source_full" "$target_full"; then
        print_success "Image tagged successfully"
    else
        print_error "Failed to tag image"
        return 1
    fi
    
    # Push to target registry
    print_info "Pushing image to target registry..."
    if $CONTAINER_TOOL push "$target_full"; then
        print_success "Image pushed successfully"
        
        # Clean up local images
        print_info "Cleaning up local images..."
        $CONTAINER_TOOL rmi "$source_full" "$target_full" 2>/dev/null || true
        
        return 0
    else
        print_error "Failed to push image to target registry"
        return 1
    fi
}

# Verify migration
verify_migration() {
    print_section "VERIFYING MIGRATION"
    
    local target_full="${TARGET_REGISTRY}/${TARGET_NAMESPACE}/${TARGET_IMAGE}:${IMAGE_TAG}"
    
    print_info "Verifying image exists in target registry: $target_full"
    
    if $CONTAINER_TOOL pull "$target_full" >/dev/null 2>&1; then
        print_success "✅ Image successfully migrated and accessible"
        $CONTAINER_TOOL rmi "$target_full" 2>/dev/null || true
        
        # Show image info
        print_info "Target image details:"
        print_info "Registry: $TARGET_REGISTRY"
        print_info "Namespace: $TARGET_NAMESPACE"
        print_info "Image: $TARGET_IMAGE"
        print_info "Tag: $IMAGE_TAG"
        print_info "Full reference: $target_full"
        
        return 0
    else
        print_error "❌ Failed to verify migrated image"
        return 1
    fi
}

# Update main migration script
update_main_migration_script() {
    print_section "UPDATING MAIN MIGRATION SCRIPT"
    
    if [[ -f "migrate-mulesoftapps.sh" ]]; then
        print_info "Adding image migration function to main script..."
        
        # Create backup
        cp migrate-mulesoftapps.sh migrate-mulesoftapps.sh.backup
        
        # Add image migration call to main script
        # This will be inserted before the main function
        cat > image_migration_addition.txt << 'EOF'

# Migrate container images
migrate_container_images() {
    print_section "MIGRATING CONTAINER IMAGES"
    
    print_info "Running image migration script..."
    if [[ -f "migrate-mulesoft-image.sh" ]]; then
        bash migrate-mulesoft-image.sh
        if [[ $? -eq 0 ]]; then
            print_success "Container images migrated successfully"
        else
            print_warning "Image migration had issues - review manually"
        fi
    else
        print_warning "Image migration script not found - skipping image migration"
    fi
}
EOF
        
        print_info "Image migration function added to main script"
        print_info "To use it, add 'migrate_container_images' call to the main function"
        
    else
        print_warning "Main migration script not found - no updates made"
    fi
}

# Generate image migration report
generate_migration_report() {
    print_section "GENERATING MIGRATION REPORT"
    
    cat > "MULESOFT-IMAGE-MIGRATION-REPORT.md" << EOF
# Mulesoft Image Migration Report

**Migration Date**: $(date)
**Source Registry**: $SOURCE_REGISTRY
**Target Registry**: $TARGET_REGISTRY

## Image Details

| Attribute | Value |
|-----------|-------|
| **Source Image** | \`$SOURCE_REGISTRY/$SOURCE_NAMESPACE/$SOURCE_IMAGE:$IMAGE_TAG\` |
| **Target Image** | \`$TARGET_REGISTRY/$TARGET_NAMESPACE/$TARGET_IMAGE:$IMAGE_TAG\` |
| **Source Namespace** | \`$SOURCE_NAMESPACE\` |
| **Target Namespace** | \`$TARGET_NAMESPACE\` |
| **Image Tag** | \`$IMAGE_TAG\` |
| **Migration Method** | $(if [[ "$SKOPEO_AVAILABLE" == "true" ]]; then echo "Skopeo (direct registry copy)"; else echo "$CONTAINER_TOOL (pull/push)"; fi) |

## Migration Summary

✅ **SUCCESSFUL MIGRATION**

The Mulesoft accelerator image has been successfully migrated from OCPAZ internal registry to Quay registry.

## Verification Commands

\`\`\`bash
# Verify image exists in target registry
$CONTAINER_TOOL pull $TARGET_REGISTRY/$TARGET_NAMESPACE/$TARGET_IMAGE:$IMAGE_TAG

# Login to target registry
echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin $TARGET_REGISTRY

# Check image details
$CONTAINER_TOOL inspect $TARGET_REGISTRY/$TARGET_NAMESPACE/$TARGET_IMAGE:$IMAGE_TAG
\`\`\`

## Update Deployment References

Update your Kubernetes/OpenShift deployments to use the new image reference:

\`\`\`yaml
# Old reference (OCPAZ)
image: $SOURCE_REGISTRY/$SOURCE_NAMESPACE/$SOURCE_IMAGE:$IMAGE_TAG

# New reference (Quay)
image: $TARGET_REGISTRY/$TARGET_NAMESPACE/$TARGET_IMAGE:$IMAGE_TAG
\`\`\`

## Pull Secret for Target Registry

Create a pull secret for the Quay registry in your target namespace:

\`\`\`bash
oc create secret docker-registry quay-pull-secret \\
  --docker-server=$TARGET_REGISTRY \\
  --docker-username="$ROBOT_USER" \\
  --docker-password="$ROBOT_PASSWORD" \\
  --namespace=mulesoftapps-prod

# Update service account to use the pull secret
oc patch serviceaccount default -p '{"imagePullSecrets": [{"name": "quay-pull-secret"}]}' -n mulesoftapps-prod
\`\`\`

## Robot Account Details

- **Registry**: \`$TARGET_REGISTRY\`
- **Robot Account**: \`$ROBOT_USER\`
- **Namespace**: \`$TARGET_NAMESPACE\`
- **Permissions**: Push/Pull access to mulesoftapps namespace

## Next Steps

1. **Update Deployments**: Update all Kubernetes manifests to use the new image reference
2. **Create Pull Secrets**: Ensure target namespaces have appropriate pull secrets
3. **Test Deployment**: Deploy and test applications with new image references
4. **Update CI/CD**: Update build pipelines to push to Quay registry
5. **Monitor**: Monitor applications after migration for any issues

## Files Generated

- \`MULESOFT-IMAGE-MIGRATION-REPORT.md\` - This report
- \`migrate-mulesoft-image.sh\` - Reusable image migration script
- \`source_dockercfg.json\` - Extracted source registry credentials (cleaned up)

EOF

    print_success "Migration report generated: MULESOFT-IMAGE-MIGRATION-REPORT.md"
}

# Cleanup function
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -f source_secret.json source_dockercfg.json ~/.config/containers/auth.json image_migration_addition.txt
}

# Main function
main() {
    print_section "MULESOFT IMAGE MIGRATION"
    print_info "Migrating: $SOURCE_REGISTRY/$SOURCE_NAMESPACE/$SOURCE_IMAGE"
    print_info "Target: $TARGET_REGISTRY/$TARGET_NAMESPACE/$TARGET_IMAGE"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    check_prerequisites
    login_to_ocpaz
    set_source_credentials
    list_available_images
    get_image_sha
    login_to_registries
    
    # Try migration methods
    if [[ "$SKOPEO_AVAILABLE" == "true" ]]; then
        print_info "Attempting migration with skopeo..."
        if migrate_image_with_skopeo; then
            MIGRATION_SUCCESS=true
        else
            print_warning "Skopeo method failed, trying container tool method..."
            if migrate_image_with_container_tool; then
                MIGRATION_SUCCESS=true
            else
                MIGRATION_SUCCESS=false
            fi
        fi
    else
        print_info "Using container tool method..."
        if migrate_image_with_container_tool; then
            MIGRATION_SUCCESS=true
        else
            MIGRATION_SUCCESS=false
        fi
    fi
    
    if [[ "$MIGRATION_SUCCESS" == "true" ]]; then
        verify_migration
        generate_migration_report
        update_main_migration_script
        
        print_section "MIGRATION COMPLETE!"
        print_success "🎉 Mulesoft image successfully migrated!"
        print_info "Source: $SOURCE_REGISTRY/$SOURCE_NAMESPACE/$SOURCE_IMAGE:$IMAGE_TAG"
        print_info "Target: $TARGET_REGISTRY/$TARGET_NAMESPACE/$TARGET_IMAGE:$IMAGE_TAG"
        print_info "📋 Check MULESOFT-IMAGE-MIGRATION-REPORT.md for details"
        
    else
        print_section "MIGRATION FAILED!"
        print_error "❌ Failed to migrate image"
        print_info "Check the logs above for error details"
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
