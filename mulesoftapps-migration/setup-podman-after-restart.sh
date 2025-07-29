#!/bin/bash

# Post-Restart Podman Configuration Script
# Run this after WSL is installed and computer has been restarted

echo "🚀 POST-RESTART PODMAN SETUP"
echo "============================"
echo ""

# Check if we're in WSL or Windows
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "✅ Running in WSL environment"
    WSL_ENV=true
else
    echo "✅ Running in Windows environment"
    WSL_ENV=false
fi

echo ""
echo "🔍 CHECKING WSL STATUS"
echo "====================="

if command -v wsl.exe &> /dev/null; then
    echo "✅ WSL command available"
    
    # Test WSL
    if wsl.exe --status &> /dev/null; then
        echo "✅ WSL is working!"
        echo ""
        echo "📋 WSL Status:"
        wsl.exe --status 2>/dev/null || echo "Status check failed but WSL is working"
        
        echo ""
        echo "📋 Installed distributions:"
        wsl.exe --list --verbose 2>/dev/null || echo "No distributions found"
        
    else
        echo "❌ WSL not working properly"
        echo "💡 You may need to restart your computer first"
        exit 1
    fi
else
    echo "❌ WSL command not found"
    echo "💡 WSL may not be installed or PATH not updated"
    exit 1
fi

echo ""
echo "🐧 CHECKING PODMAN STATUS"
echo "========================"

if command -v podman &> /dev/null; then
    echo "✅ Podman found: $(podman --version)"
    
    # Check if podman machine is initialized
    echo ""
    echo "🔍 Checking Podman machine status..."
    
    if podman machine list &> /dev/null; then
        echo "✅ Podman machine command accessible"
        
        # Check if any machines exist
        MACHINES=$(podman machine list 2>/dev/null | grep -v "NAME")
        if [[ -n "$MACHINES" ]]; then
            echo "✅ Podman machines found:"
            podman machine list 2>/dev/null
            
            # Check if default machine is running
            if podman machine list 2>/dev/null | grep -q "Currently running"; then
                echo "✅ Podman machine is running!"
                echo ""
                echo "🎉 PODMAN IS READY!"
                echo "=================="
                echo ""
                echo "You can now run the migration:"
                echo "   ./migrate-mulesoft-image.sh"
                echo ""
                exit 0
            else
                echo "⚠️  Podman machine exists but not running"
                echo "💡 Starting Podman machine..."
                
                if podman machine start; then
                    echo "✅ Podman machine started successfully!"
                    echo ""
                    echo "🎉 PODMAN IS READY!"
                    echo "=================="
                    echo ""
                    echo "You can now run the migration:"
                    echo "   ./migrate-mulesoft-image.sh"
                    echo ""
                    exit 0
                else
                    echo "❌ Failed to start Podman machine"
                    echo "💡 Try reinitializing: podman machine rm; podman machine init"
                fi
            fi
        else
            echo "⚠️  No Podman machines found"
            echo "💡 Need to initialize Podman machine"
        fi
    else
        echo "❌ Podman machine command failed"
        echo "💡 This indicates WSL/Podman integration issue"
    fi
    
    echo ""
    echo "🔧 INITIALIZING PODMAN MACHINE"
    echo "============================="
    
    echo "💡 Removing any existing machines..."
    podman machine rm --force 2>/dev/null || echo "No existing machines to remove"
    
    echo ""
    echo "🚀 Initializing new Podman machine..."
    echo "This will create a new VM with 2 CPUs and 4GB RAM"
    
    if podman machine init --cpus 2 --memory 4096 --disk-size 20; then
        echo "✅ Podman machine initialized successfully!"
        
        echo ""
        echo "🚀 Starting Podman machine..."
        if podman machine start; then
            echo "✅ Podman machine started successfully!"
            
            echo ""
            echo "🧪 Testing Podman with hello-world..."
            if podman run hello-world; then
                echo ""
                echo "🎉 PODMAN IS FULLY WORKING!"
                echo "=========================="
                echo ""
                echo "✅ WSL installed and working"
                echo "✅ Podman machine running"
                echo "✅ Container operations successful"
                echo ""
                echo "🚀 Ready to run migration:"
                echo "   ./migrate-mulesoft-image.sh"
                echo ""
                echo "📋 You can also test Quay credentials:"
                echo "   ./test-quay-registry-creds.sh"
                
            else
                echo "⚠️  Podman hello-world test failed"
                echo "But machine is running - migration might still work"
            fi
            
        else
            echo "❌ Failed to start Podman machine"
            echo ""
            echo "🔧 Troubleshooting tips:"
            echo "   1. Check virtualization is enabled in BIOS"
            echo "   2. Restart computer and try again"
            echo "   3. Try: podman machine rm; podman machine init"
        fi
        
    else
        echo "❌ Failed to initialize Podman machine"
        echo ""
        echo "🔧 Troubleshooting:"
        echo "   1. Check WSL2 is the default version: wsl --set-default-version 2"
        echo "   2. Ensure virtualization is enabled"
        echo "   3. Try restarting and running this script again"
    fi
    
else
    echo "❌ Podman not found"
    echo ""
    echo "🔧 Install Podman:"
    echo "   winget install RedHat.Podman"
    echo ""
    echo "Or download from: https://podman.io/getting-started/installation"
fi

echo ""
echo "📋 CURRENT STATUS SUMMARY"
echo "========================"

echo "WSL Status: $(if command -v wsl.exe &>/dev/null && wsl.exe --status &>/dev/null; then echo "✅ Working"; else echo "❌ Not working"; fi)"
echo "Podman Status: $(if command -v podman &>/dev/null; then echo "✅ Installed"; else echo "❌ Not installed"; fi)"
echo "Podman Machine: $(if command -v podman &>/dev/null && podman machine list 2>/dev/null | grep -q "Currently running"; then echo "✅ Running"; else echo "❌ Not running"; fi)"

echo ""
echo "🔄 To check status again, run:"
echo "   ./runtime-diagnostic.sh"
echo ""
echo "📚 For more help, see:"
echo "   CONTAINER-RUNTIME-FIX-GUIDE.md"
