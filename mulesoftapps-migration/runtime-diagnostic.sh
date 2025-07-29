#!/bin/bash

# 🔧 Container Runtime Diagnostic and Helper Script
# Provides comprehensive status check and guidance for container runtime setup

echo "🔧 Container Runtime Diagnostic Tool"
echo "===================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to test WSL status
check_wsl() {
    echo "📋 Checking WSL Status..."
    
    if command_exists wsl.exe; then
        echo "✅ WSL command found"
        
        # Test if WSL is working
        if wsl.exe --status > /dev/null 2>&1; then
            echo "✅ WSL is working"
            wsl.exe --list --verbose 2>/dev/null || echo "⚠️  No WSL distributions installed"
        else
            echo "❌ WSL not working properly"
            echo "   💡 Fix: Run 'wsl --install' as Administrator"
        fi
    else
        echo "❌ WSL not found"
        echo "   💡 Fix: Run 'wsl --install' as Administrator"
    fi
    echo ""
}

# Function to check Podman
check_podman() {
    echo "🐧 Checking Podman Status..."
    
    if command_exists podman; then
        echo "✅ Podman found: $(podman --version)"
        
        # Check if podman machine is working
        if podman machine list > /dev/null 2>&1; then
            echo "✅ Podman machine accessible"
            local machines=$(podman machine list 2>/dev/null)
            if [[ -n "$machines" ]]; then
                echo "$machines"
            else
                echo "ℹ️  No podman machines found"
                echo "   💡 Fix: Run 'podman machine init && podman machine start'"
            fi
        else
            echo "❌ Podman machine not working"
            echo "   💡 Fix: Ensure WSL is working, then run 'podman machine init'"
        fi
    else
        echo "❌ Podman not found"
        echo "   💡 Install: winget install RedHat.Podman"
    fi
    echo ""
}

# Function to check Docker
check_docker() {
    echo "🐳 Checking Docker Status..."
    
    if command_exists docker; then
        echo "✅ Docker found: $(docker --version)"
        
        if docker ps > /dev/null 2>&1; then
            echo "✅ Docker is running and accessible"
        else
            echo "❌ Docker not running or not accessible"
            echo "   💡 Fix: Start Docker Desktop or check 'docker context list'"
        fi
    else
        echo "❌ Docker not found"
        echo "   💡 Install: Download Docker Desktop from https://docker.com"
    fi
    echo ""
}

# Function to check OpenShift CLI
check_oc() {
    echo "🔧 Checking OpenShift CLI..."
    
    if command_exists oc; then
        echo "✅ OpenShift CLI found: $(oc version --client)"
        
        # Check if logged in
        if oc whoami > /dev/null 2>&1; then
            echo "✅ Logged in as: $(oc whoami)"
            echo "✅ Current project: $(oc project -q 2>/dev/null || echo 'Not set')"
            echo "✅ Server: $(oc whoami --show-server 2>/dev/null)"
        else
            echo "⚠️  Not logged in to OpenShift"
            echo "   💡 Login: oc login --server=https://api.ocpaz.kohlerco.com:6443"
        fi
    else
        echo "❌ OpenShift CLI not found"
        echo "   💡 Install: Download from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/"
    fi
    echo ""
}

# Function to provide recommendations
provide_recommendations() {
    echo "🎯 Recommendations"
    echo "=================="
    
    # Check what's available
    local has_working_runtime=false
    local runtime_type=""
    
    if command_exists docker && docker ps > /dev/null 2>&1; then
        has_working_runtime=true
        runtime_type="Docker"
    elif command_exists podman && podman machine list > /dev/null 2>&1; then
        has_working_runtime=true
        runtime_type="Podman"
    fi
    
    if [ "$has_working_runtime" = true ]; then
        echo "🎉 SUCCESS: You have a working container runtime ($runtime_type)!"
        echo ""
        echo "✅ Ready to use container-based migration:"
        echo "   → ./migrate-mulesoft-image.sh"
        echo ""
    else
        echo "❌ No working container runtime found"
        echo ""
        echo "🚀 IMMEDIATE SOLUTION (No container runtime needed):"
        echo "======================================================"
        echo "✅ Use OpenShift-native migration:"
        echo "   → ./migrate-image-with-oc-mirror.sh"
        echo ""
        echo "🔧 LONG-TERM FIXES:"
        echo "==================="
        echo ""
        echo "Option 1: Fix WSL + Podman (Recommended)"
        echo "   1. Open PowerShell as Administrator"
        echo "   2. Run: wsl --install"
        echo "   3. Restart computer"
        echo "   4. After restart: podman machine init && podman machine start"
        echo ""
        echo "Option 2: Install Docker Desktop"
        echo "   1. Download from: https://docker.com/products/docker-desktop"
        echo "   2. Install with WSL2 backend enabled"
        echo "   3. Start Docker Desktop"
        echo "   4. Test with: docker run hello-world"
        echo ""
    fi
}

# Function to test migration readiness
test_migration_readiness() {
    echo "🧪 Migration Readiness Test"
    echo "============================"
    
    local ready=true
    
    # Check OpenShift authentication
    echo "📡 Testing OCPAZ registry access..."
    if oc whoami > /dev/null 2>&1; then
        echo "✅ OCPAZ authentication working"
        
        # Test namespace access
        if oc get imagestream -n mulesoftapps-prod > /dev/null 2>&1; then
            echo "✅ mulesoftapps-prod namespace accessible"
        else
            echo "⚠️  Cannot access mulesoftapps-prod namespace"
            echo "   This may be normal if you don't have permissions"
        fi
        
        # Test if target image exists
        if oc get imagestream mulesoft-accelerator-2 -n mulesoftapps-prod > /dev/null 2>&1; then
            echo "✅ Target image 'mulesoft-accelerator-2' found"
        else
            echo "⚠️  Cannot find image 'mulesoft-accelerator-2' in mulesoftapps-prod"
            echo "   Run: oc get imagestream -n mulesoftapps-prod | grep mulesoft"
        fi
    else
        echo "❌ Not authenticated to OCPAZ"
        echo "   💡 Fix: oc login --server=https://api.ocpaz.kohlerco.com:6443"
        ready=false
    fi
    
    echo ""
    echo "🎯 Migration Status:"
    if [ "$ready" = true ]; then
        echo "✅ READY TO MIGRATE!"
        echo ""
        echo "🚀 Execute migration now:"
        echo "   ./migrate-image-with-oc-mirror.sh"
    else
        echo "❌ NOT READY - Fix authentication first"
    fi
}

# Function to show quick action menu
show_action_menu() {
    echo ""
    echo "🎯 Quick Actions"
    echo "================"
    echo ""
    echo "1. 🚀 Run Migration (OpenShift-native, no containers needed)"
    echo "   → ./migrate-image-with-oc-mirror.sh"
    echo ""
    echo "2. 🔧 Test Container Runtime Migration (if runtime working)"
    echo "   → ./migrate-mulesoft-image.sh"
    echo ""
    echo "3. 🧪 Test Registry Credentials"
    echo "   → ./test-quay-registry-creds.sh"
    echo ""
    echo "4. 📋 Check Available Images"
    echo "   → oc get imagestream -n mulesoftapps-prod | grep mulesoft"
    echo ""
    echo "5. 🔍 Get Full Fix Guide"
    echo "   → cat CONTAINER-RUNTIME-FIX-GUIDE.md"
}

# Main execution
main() {
    echo "Starting comprehensive diagnostic..."
    echo ""
    
    check_wsl
    check_podman
    check_docker
    check_oc
    test_migration_readiness
    provide_recommendations
    show_action_menu
    
    echo ""
    echo "📚 Documentation:"
    echo "   • CONTAINER-RUNTIME-FIX-GUIDE.md - Detailed fix instructions"
    echo "   • MIGRATION-SUMMARY.md - Migration overview"
    echo ""
    echo "🔄 Run this script again after making changes: ./runtime-diagnostic.sh"
}

# Run the main function
main
