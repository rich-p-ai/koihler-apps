#!/bin/bash
# Test Quay Registry Credentials
# This script tests the robot account credentials for Quay registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_REGISTRY="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
ROBOT_USER="mulesoftapps+robot"
ROBOT_PASSWORD="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0"

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

main() {
    print_section "TESTING QUAY REGISTRY CREDENTIALS"
    
    # Check if podman/docker is available
    if command -v podman &> /dev/null; then
        CONTAINER_TOOL="podman"
        print_info "Using podman for testing"
    elif command -v docker &> /dev/null; then
        CONTAINER_TOOL="docker"
        print_info "Using docker for testing"
    else
        print_error "Neither podman nor docker is installed"
        exit 1
    fi
    
    print_info "Registry: $TARGET_REGISTRY"
    print_info "Robot User: $ROBOT_USER"
    print_info "Password length: ${#ROBOT_PASSWORD} characters"
    
    # Test different login methods
    print_section "TESTING LOGIN METHODS"
    
    # Method 1: Standard login
    print_info "Method 1: Standard login"
    if echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin "$TARGET_REGISTRY" 2>/dev/null; then
        print_success "✅ Standard login successful!"
        $CONTAINER_TOOL logout "$TARGET_REGISTRY" 2>/dev/null || true
    else
        print_warning "❌ Standard login failed"
        
        # Method 2: Insecure login
        print_info "Method 2: Insecure login (--tls-verify=false)"
        if echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin --tls-verify=false "$TARGET_REGISTRY" 2>/dev/null; then
            print_success "✅ Insecure login successful!"
            $CONTAINER_TOOL logout "$TARGET_REGISTRY" 2>/dev/null || true
        else
            print_warning "❌ Insecure login failed"
            
            # Method 3: HTTPS prefix
            print_info "Method 3: With HTTPS prefix"
            local alt_registry="https://$TARGET_REGISTRY"
            if echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin "$alt_registry" 2>/dev/null; then
                print_success "✅ HTTPS prefix login successful!"
                $CONTAINER_TOOL logout "$alt_registry" 2>/dev/null || true
            else
                print_error "❌ All login methods failed"
                
                # Show detailed error information
                print_section "DETAILED ERROR ANALYSIS"
                print_info "Attempting login with verbose output..."
                echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin "$TARGET_REGISTRY" 2>&1 || true
                
                print_info ""
                print_info "Please verify:"
                print_info "  1. Robot account exists in Quay"
                print_info "  2. Robot account has correct permissions"
                print_info "  3. Registry URL is correct and accessible"
                print_info "  4. Password is not expired"
                print_info "  5. Network connectivity to registry"
                
                exit 1
            fi
        fi
    fi
    
    # Test registry connectivity
    print_section "TESTING REGISTRY CONNECTIVITY"
    
    print_info "Testing registry accessibility..."
    if curl -k -s --connect-timeout 10 "https://$TARGET_REGISTRY/v2/" >/dev/null 2>&1; then
        print_success "✅ Registry is accessible via HTTPS"
    else
        print_warning "⚠️ Registry accessibility test failed"
        print_info "This might be normal for Quay registries with authentication"
    fi
    
    # Test with a small image pull/push if login worked
    print_section "TESTING IMAGE OPERATIONS"
    
    print_info "Testing basic image operations..."
    
    # Try to pull a small public image and push it to test push permissions
    local test_image="alpine:latest"
    local test_target="$TARGET_REGISTRY/mulesoftapps/test-image:latest"
    
    # Login again
    echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin "$TARGET_REGISTRY" --tls-verify=false 2>/dev/null || {
        echo "$ROBOT_PASSWORD" | $CONTAINER_TOOL login --username "$ROBOT_USER" --password-stdin "$TARGET_REGISTRY" 2>/dev/null || {
            print_warning "Cannot test image operations - login failed"
            exit 0
        }
    }
    
    print_info "Pulling test image: $test_image"
    if $CONTAINER_TOOL pull "$test_image" >/dev/null 2>&1; then
        print_success "Test image pulled successfully"
        
        print_info "Tagging for target registry..."
        if $CONTAINER_TOOL tag "$test_image" "$test_target" 2>/dev/null; then
            print_success "Image tagged successfully"
            
            print_info "Testing push to target registry..."
            if $CONTAINER_TOOL push "$test_target" 2>/dev/null; then
                print_success "✅ Push test successful - robot account has push permissions!"
                
                # Clean up test image
                print_info "Cleaning up test images..."
                $CONTAINER_TOOL rmi "$test_image" "$test_target" 2>/dev/null || true
                
            else
                print_warning "❌ Push test failed - check robot account permissions"
            fi
        else
            print_warning "Failed to tag image for target registry"
        fi
    else
        print_warning "Failed to pull test image"
    fi
    
    # Logout
    $CONTAINER_TOOL logout "$TARGET_REGISTRY" 2>/dev/null || true
    
    print_section "CREDENTIAL TEST COMPLETE"
    print_success "🎉 Quay registry credential testing completed!"
}

# Run the test
main "$@"
