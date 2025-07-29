#!/bin/bash
# Test script to verify source registry credentials
# This script tests the provided service account credentials for OCPAZ registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_REGISTRY="default-route-openshift-image-registry.apps.ocpaz.kohlerco.com"
SOURCE_USER="serviceaccount"
SOURCE_PASSWORD="eyJhbGciOiJSUzI1NiIsImtpZCI6Im5EbTZEUVJKbUw0UWg1SVBZWjBuYy14NFZZdl9DaFhKQlZpSjNZZ1JqcGMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJtdWxlc29mdGFwcHMtcHJvZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkZWZhdWx0LXRva2VuLXo3c2d6Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImRlZmF1bHQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJlNjk2N2FiZi00YjYzLTRiY2UtOWYyNy1hOWNkOGY0YzFlMjciLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6bXVsZXNvZnRhcHBzLXByb2Q6ZGVmYXVsdCJ9.bxtOhSsZO859Yes5cvUH07w51l6yAoNBQE8RMpW5LNXYazmIkHI-iRuDqLOW1TicEu0kClRcNdeSOifl1-208YlDdYg1eU9gXI2d8OZjq1C6aCNqR9hNiNCys9rT_h59OMhnrrRncOPId8w4YbQzhgSuqzP_EXcGwOuQSHfPou2AYyovtS88d1o9va6siXnqzw4tmmKtf6s6_O2VgaXXXVqS1QJnUdutpt3IjfXZz5uHF1Tf38tsSGYy-a8JoTF7D3KZ-WcXp-qtJJ_rjsyP4Dn0GW95xjiNlMpuiPUMm66RcsOMZCG4zp0uaXv4Odzkdn9kLXrf5wZpO3mmG7UFhA"

# Logging functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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
    print_section "TESTING SOURCE REGISTRY CREDENTIALS"
    
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
    
    print_info "Registry: $SOURCE_REGISTRY"
    print_info "Username: $SOURCE_USER"
    print_info "Token length: ${#SOURCE_PASSWORD} characters"
    
    # Test login
    print_info "Testing registry login..."
    if echo "$SOURCE_PASSWORD" | $CONTAINER_TOOL login --username "$SOURCE_USER" --password-stdin "$SOURCE_REGISTRY" 2>/dev/null; then
        print_success "✅ Successfully logged into source registry!"
        print_info "Credentials are valid and working"
        
        # Test logout
        $CONTAINER_TOOL logout "$SOURCE_REGISTRY" 2>/dev/null || true
        print_info "Logged out from registry"
        
    else
        print_error "❌ Failed to login to source registry"
        print_info "Please verify the credentials are correct"
        exit 1
    fi
    
    print_section "CREDENTIAL TEST COMPLETE"
    print_success "🎉 Source registry credentials are working correctly!"
}

# Run the test
main "$@"
