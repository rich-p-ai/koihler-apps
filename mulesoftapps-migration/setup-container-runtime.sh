#!/bin/bash
# Podman and Docker Setup Script for Windows
# This script initializes and configures Podman/Docker for container operations
# Created: July 28, 2025

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check current status
check_current_status() {
    print_section "CHECKING CURRENT CONTAINER RUNTIME STATUS"
    
    # Check Podman
    if command -v podman &> /dev/null; then
        print_info "Podman is installed at: $(which podman)"
        print_info "Podman version: $(podman --version 2>/dev/null || echo 'Unable to determine')"
        
        # Check Podman connections
        print_info "Podman system connections:"
        podman system connection list || echo "No connections found"
        
        # Check Podman machines
        print_info "Podman machines:"
        podman machine list || echo "No machines found"
        
        # Test Podman connectivity
        if podman system connection list | grep -q "Default.*true"; then
            print_success "Podman has a default connection"
        else
            print_warning "Podman has no default connection"
        fi
    else
        print_warning "Podman is not installed or not in PATH"
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        print_info "Docker is installed at: $(which docker)"
        print_info "Docker version: $(docker --version 2>/dev/null || echo 'Unable to determine')"
        
        # Test Docker connectivity
        if docker info &>/dev/null; then
            print_success "Docker is running and accessible"
        else
            print_warning "Docker is installed but not running or accessible"
        fi
    else
        print_warning "Docker is not installed or not in PATH"
    fi
}

# Fix Podman setup
setup_podman() {
    print_section "SETTING UP PODMAN"
    
    if ! command -v podman &> /dev/null; then
        print_error "Podman is not installed. Please install Podman first."
        print_info "Download from: https://podman.io/getting-started/installation"
        return 1
    fi
    
    print_info "Initializing Podman machine..."
    
    # Check if a machine already exists
    if podman machine list | grep -q "podman-machine-default"; then
        print_info "Default Podman machine already exists"
        
        # Check if it's running
        if podman machine list | grep "podman-machine-default" | grep -q "Running"; then
            print_success "Podman machine is already running"
        else
            print_info "Starting existing Podman machine..."
            if podman machine start podman-machine-default; then
                print_success "Podman machine started successfully"
            else
                print_error "Failed to start Podman machine"
                return 1
            fi
        fi
    else
        print_info "Creating new Podman machine..."
        if podman machine init --cpus 2 --memory 4096 --disk-size 20; then
            print_success "Podman machine initialized successfully"
            
            print_info "Starting Podman machine..."
            if podman machine start; then
                print_success "Podman machine started successfully"
            else
                print_error "Failed to start Podman machine"
                return 1
            fi
        else
            print_error "Failed to initialize Podman machine"
            return 1
        fi
    fi
    
    # Wait a moment for the connection to establish
    sleep 3
    
    # Test Podman functionality
    print_info "Testing Podman functionality..."
    if podman run --rm hello-world >/dev/null 2>&1; then
        print_success "✅ Podman is working correctly!"
    else
        print_warning "Podman test failed - trying alternative test..."
        if podman run --rm alpine:latest echo "Podman test successful" >/dev/null 2>&1; then
            print_success "✅ Podman is working correctly!"
        else
            print_error "❌ Podman test failed"
            return 1
        fi
    fi
    
    return 0
}

# Install Docker Desktop (guidance)
setup_docker() {
    print_section "DOCKER SETUP GUIDANCE"
    
    if command -v docker &> /dev/null; then
        print_info "Docker is already installed"
        
        # Test if Docker is running
        if docker info &>/dev/null; then
            print_success "✅ Docker is running and accessible"
            
            # Test Docker functionality
            print_info "Testing Docker functionality..."
            if docker run --rm hello-world >/dev/null 2>&1; then
                print_success "✅ Docker is working correctly!"
            else
                print_warning "Docker test failed - may need restart"
            fi
        else
            print_warning "Docker is installed but not running"
            print_info "Please start Docker Desktop manually"
            print_info "Docker Desktop should be available in your system tray"
        fi
    else
        print_info "Docker is not installed"
        print_info "To install Docker Desktop:"
        print_info "  1. Download from: https://www.docker.com/products/docker-desktop/"
        print_info "  2. Install Docker Desktop for Windows"
        print_info "  3. Start Docker Desktop"
        print_info "  4. Ensure WSL2 integration is enabled (if using WSL2)"
    fi
}

# Test registry operations
test_registry_operations() {
    print_section "TESTING REGISTRY OPERATIONS"
    
    # Determine which container tool to use
    local container_tool=""
    if command -v podman &> /dev/null && podman system connection list | grep -q "Default.*true"; then
        container_tool="podman"
        print_info "Using Podman for testing"
    elif command -v docker &> /dev/null && docker info &>/dev/null; then
        container_tool="docker"
        print_info "Using Docker for testing"
    else
        print_error "No working container runtime available"
        return 1
    fi
    
    # Test basic operations
    print_info "Testing basic container operations..."
    
    # Test pull
    print_info "Testing image pull..."
    if $container_tool pull alpine:latest >/dev/null 2>&1; then
        print_success "✅ Image pull successful"
        
        # Test run
        print_info "Testing container run..."
        if $container_tool run --rm alpine:latest echo "Container test successful" >/dev/null 2>&1; then
            print_success "✅ Container run successful"
        else
            print_warning "⚠️ Container run failed"
        fi
        
        # Clean up test image
        $container_tool rmi alpine:latest >/dev/null 2>&1 || true
    else
        print_error "❌ Image pull failed"
        return 1
    fi
    
    return 0
}

# Test registry authentication
test_registry_auth() {
    print_section "TESTING REGISTRY AUTHENTICATION"
    
    # Configuration for testing
    local target_registry="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
    local robot_user="mulesoftapps+robot"
    local robot_password="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0"
    
    # Determine container tool
    local container_tool=""
    if command -v podman &> /dev/null && podman system connection list | grep -q "Default.*true"; then
        container_tool="podman"
    elif command -v docker &> /dev/null && docker info &>/dev/null; then
        container_tool="docker"
    else
        print_error "No working container runtime available for auth testing"
        return 1
    fi
    
    print_info "Testing Quay registry authentication with $container_tool..."
    
    # Test login
    if echo "$robot_password" | $container_tool login --username "$robot_user" --password-stdin "$target_registry" 2>/dev/null; then
        print_success "✅ Quay registry login successful!"
        
        # Test logout
        $container_tool logout "$target_registry" 2>/dev/null || true
        print_info "Logged out from registry"
        
        return 0
    else
        print_warning "⚠️ Quay registry login failed - trying insecure method..."
        
        # Try with insecure flag
        if echo "$robot_password" | $container_tool login --username "$robot_user" --password-stdin --tls-verify=false "$target_registry" 2>/dev/null; then
            print_success "✅ Quay registry login successful (insecure)!"
            $container_tool logout "$target_registry" 2>/dev/null || true
            return 0
        else
            print_error "❌ Quay registry authentication failed"
            return 1
        fi
    fi
}

# Create container runtime preference script
create_runtime_script() {
    print_section "CREATING CONTAINER RUNTIME HELPER"
    
    cat > "container-runtime-helper.sh" << 'EOF'
#!/bin/bash
# Container Runtime Helper Script
# Automatically selects the best available container runtime

get_container_tool() {
    # Check for working Podman
    if command -v podman &> /dev/null; then
        if podman system connection list | grep -q "Default.*true" 2>/dev/null; then
            echo "podman"
            return 0
        fi
    fi
    
    # Check for working Docker
    if command -v docker &> /dev/null; then
        if docker info &>/dev/null 2>&1; then
            echo "docker"
            return 0
        fi
    fi
    
    # No working runtime found
    echo "none"
    return 1
}

# Export the function for use in other scripts
export -f get_container_tool

# If script is run directly, show the current runtime
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    runtime=$(get_container_tool)
    if [[ "$runtime" == "none" ]]; then
        echo "ERROR: No working container runtime found"
        exit 1
    else
        echo "Available container runtime: $runtime"
        $runtime --version
    fi
fi
EOF
    
    chmod +x container-runtime-helper.sh
    print_success "Created container-runtime-helper.sh"
}

# Generate setup report
generate_setup_report() {
    print_section "GENERATING SETUP REPORT"
    
    cat > "CONTAINER-RUNTIME-SETUP-REPORT.md" << EOF
# Container Runtime Setup Report

**Setup Date**: $(date)
**System**: Windows with $(bash --version | head -1)

## Setup Summary

### Podman Status
$(if command -v podman &> /dev/null; then
    echo "- ✅ **Installed**: $(podman --version 2>/dev/null || echo 'Version unknown')"
    echo "- **Location**: $(which podman)"
    if podman system connection list | grep -q "Default.*true" 2>/dev/null; then
        echo "- ✅ **Status**: Working and connected"
    else
        echo "- ❌ **Status**: Not connected or not working"
    fi
else
    echo "- ❌ **Not Installed**"
fi)

### Docker Status
$(if command -v docker &> /dev/null; then
    echo "- ✅ **Installed**: $(docker --version 2>/dev/null || echo 'Version unknown')"
    echo "- **Location**: $(which docker)"
    if docker info &>/dev/null 2>&1; then
        echo "- ✅ **Status**: Running and accessible"
    else
        echo "- ❌ **Status**: Not running or not accessible"
    fi
else
    echo "- ❌ **Not Installed**"
fi)

## Recommended Container Runtime

$(
# Determine the best runtime
if command -v podman &> /dev/null && podman system connection list | grep -q "Default.*true" 2>/dev/null; then
    echo "**Podman** - Working and recommended for OpenShift environments"
elif command -v docker &> /dev/null && docker info &>/dev/null 2>&1; then
    echo "**Docker** - Working and available"
else
    echo "**None Available** - Setup required"
fi
)

## Registry Authentication Test Results

### Quay Registry (kohler-registry-quay-quay.apps.ocp-host.kohlerco.com)
$(
# Test results would go here - simplified for report
echo "- Robot User: mulesoftapps+robot"
echo "- Test Status: See setup log for detailed results"
)

## Usage Instructions

### For Image Migration
\`\`\`bash
# Use the working runtime for migration
$(
if command -v podman &> /dev/null && podman system connection list | grep -q "Default.*true" 2>/dev/null; then
    echo "./migrate-mulesoft-image.sh  # Will use Podman"
elif command -v docker &> /dev/null && docker info &>/dev/null 2>&1; then
    echo "./migrate-mulesoft-image.sh  # Will use Docker"
else
    echo "# Fix container runtime first, then:"
    echo "./migrate-mulesoft-image.sh"
fi
)

# Or use OpenShift-native approach (no container runtime needed)
./migrate-image-with-oc-mirror.sh
\`\`\`

### Helper Script
A helper script \`container-runtime-helper.sh\` has been created to automatically detect the best available container runtime.

## Troubleshooting

### Podman Issues
\`\`\`bash
# Restart Podman machine
podman machine stop
podman machine start

# Recreate Podman machine if needed
podman machine rm podman-machine-default
podman machine init
podman machine start
\`\`\`

### Docker Issues
- Ensure Docker Desktop is running
- Check Docker Desktop settings
- Restart Docker Desktop if needed
- Verify WSL2 integration (if using WSL2)

## Next Steps

1. **If Container Runtime is Working**: Use \`./migrate-mulesoft-image.sh\`
2. **If Container Runtime Issues Persist**: Use \`./migrate-image-with-oc-mirror.sh\`
3. **For Verification**: Run \`./test-quay-registry-creds.sh\`

## Files Created
- \`container-runtime-helper.sh\` - Runtime detection helper
- \`CONTAINER-RUNTIME-SETUP-REPORT.md\` - This report

EOF

    print_success "Setup report generated: CONTAINER-RUNTIME-SETUP-REPORT.md"
}

# Main setup function
main() {
    print_section "CONTAINER RUNTIME SETUP FOR MULESOFT IMAGE MIGRATION"
    print_info "This script will setup and test Podman/Docker for container operations"
    print_info "Required for: Image migration from OCPAZ to Quay registry"
    
    check_current_status
    
    # Try to setup Podman first (preferred for OpenShift environments)
    if setup_podman; then
        print_success "Podman setup completed successfully"
        PODMAN_WORKING=true
    else
        print_warning "Podman setup failed or incomplete"
        PODMAN_WORKING=false
    fi
    
    # Check Docker setup
    setup_docker
    
    # Test basic operations
    if test_registry_operations; then
        print_success "Container runtime operations are working"
        
        # Test registry authentication
        if test_registry_auth; then
            print_success "Registry authentication is working"
        else
            print_warning "Registry authentication needs attention"
        fi
    else
        print_warning "Container runtime operations need attention"
    fi
    
    create_runtime_script
    generate_setup_report
    
    print_section "SETUP COMPLETE!"
    
    # Final recommendations
    if command -v podman &> /dev/null && podman system connection list | grep -q "Default.*true" 2>/dev/null; then
        print_success "🎉 Podman is working! You can now run:"
        print_info "  ./migrate-mulesoft-image.sh"
    elif command -v docker &> /dev/null && docker info &>/dev/null 2>&1; then
        print_success "🎉 Docker is working! You can now run:"
        print_info "  ./migrate-mulesoft-image.sh"
    else
        print_warning "⚠️ No working container runtime. Alternatives:"
        print_info "  1. Fix Podman: podman machine init && podman machine start"
        print_info "  2. Install/start Docker Desktop"
        print_info "  3. Use OpenShift-native approach: ./migrate-image-with-oc-mirror.sh"
    fi
    
    print_info "📋 Check CONTAINER-RUNTIME-SETUP-REPORT.md for detailed status"
}

# Run setup
main "$@"
