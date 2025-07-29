#!/bin/bash

# WSL + Podman Fix Script
# Comprehensive guide and automation for fixing WSL and Podman setup

echo "🔧 WSL + PODMAN FIX SCRIPT"
echo "=========================="
echo ""

# Check if running in PowerShell/Windows
if [[ "$OS" == "Windows_NT" ]] || command -v powershell.exe &> /dev/null; then
    echo "✅ Running on Windows system"
    echo ""
    echo "📋 WSL + PODMAN FIX PROCESS"
    echo "=========================="
    echo ""
    echo "🎯 PHASE 1: INSTALL WSL (Administrator Required)"
    echo "=============================================="
    echo ""
    echo "You need to run these commands as Administrator in PowerShell:"
    echo ""
    echo "1️⃣ Install WSL:"
    echo "   wsl --install"
    echo ""
    echo "2️⃣ Restart Computer (Required!):"
    echo "   This is mandatory after WSL installation"
    echo ""
    echo "3️⃣ After restart, complete Ubuntu setup:"
    echo "   - Create username and password"
    echo "   - Update Ubuntu: sudo apt update"
    echo ""
    echo "🎯 PHASE 2: CONFIGURE PODMAN (After Restart)"
    echo "=========================================="
    echo ""
    echo "After restarting your computer:"
    echo ""
    echo "1️⃣ Initialize Podman machine:"
    echo "   podman machine init --cpus 2 --memory 4096"
    echo ""
    echo "2️⃣ Start Podman machine:"
    echo "   podman machine start"
    echo ""
    echo "3️⃣ Test Podman:"
    echo "   podman run hello-world"
    echo ""
    echo "4️⃣ Run migration:"
    echo "   ./migrate-mulesoft-image.sh"
    echo ""
    echo "🚨 IMPORTANT STEPS TO TAKE NOW:"
    echo "=============================="
    echo ""
    echo "RIGHT NOW:"
    echo "----------"
    echo "1. Open PowerShell as Administrator (Right-click → Run as Administrator)"
    echo "2. Run: wsl --install"
    echo "3. When prompted, restart your computer"
    echo ""
    echo "AFTER RESTART:"
    echo "--------------"
    echo "4. Complete Ubuntu setup (username/password)"
    echo "5. Run: podman machine init"
    echo "6. Run: podman machine start" 
    echo "7. Run: ./migrate-mulesoft-image.sh"
    echo ""
    
    # Try to detect if we're already in an admin session
    echo "🔍 CHECKING CURRENT PERMISSIONS"
    echo "=============================="
    
    # Create a test script to check admin status
    cat > check_admin.ps1 << 'EOF'
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "✅ Running as Administrator - You can install WSL now!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🚀 Ready to install WSL:" -ForegroundColor Yellow
    Write-Host "   wsl --install" -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  You will need to restart after installation!" -ForegroundColor Yellow
} else {
    Write-Host "❌ Not running as Administrator" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 To get Administrator access:" -ForegroundColor Yellow
    Write-Host "   1. Press Win+X" -ForegroundColor White
    Write-Host "   2. Click 'Windows PowerShell (Admin)'" -ForegroundColor White
    Write-Host "   3. Run: wsl --install" -ForegroundColor White
}
EOF
    
    if command -v powershell.exe &> /dev/null; then
        echo ""
        echo "🔍 Checking Administrator status..."
        powershell.exe -ExecutionPolicy Bypass -File check_admin.ps1
    fi
    
    # Clean up
    rm -f check_admin.ps1
    
else
    echo "⚠️  This appears to be a Linux/WSL environment"
    echo "WSL is already working if you can run this script!"
    
    # Check Podman status in Linux
    echo ""
    echo "🐧 CHECKING PODMAN IN LINUX/WSL"
    echo "=============================="
    
    if command -v podman &> /dev/null; then
        echo "✅ Podman found: $(podman --version)"
        
        if podman machine list &> /dev/null; then
            echo "✅ Podman machine accessible"
            podman machine list 2>/dev/null || echo "No machines configured"
        else
            echo "❌ Podman machine not accessible"
            echo "💡 Try: podman machine init && podman machine start"
        fi
    else
        echo "❌ Podman not found in this environment"
        echo "💡 Install: sudo apt install podman"
    fi
fi

echo ""
echo "📚 REFERENCE COMMANDS"
echo "==================="
echo ""
echo "PowerShell Commands (Run as Administrator):"
echo "-------------------------------------------"
echo "wsl --install                    # Install WSL"
echo "wsl --list --verbose             # Check WSL status"
echo "wsl --update                     # Update WSL"
echo "wsl --set-default-version 2      # Set WSL2 as default"
echo ""
echo "Podman Commands (After WSL is working):"
echo "---------------------------------------"
echo "podman machine init              # Initialize Podman VM"
echo "podman machine start             # Start Podman VM"
echo "podman machine list              # List Podman machines"
echo "podman run hello-world           # Test Podman"
echo ""
echo "Migration Commands (After Podman is working):"
echo "---------------------------------------------"
echo "./runtime-diagnostic.sh         # Check status"
echo "./migrate-mulesoft-image.sh     # Run migration"
echo ""

echo "🎯 QUICK START CHECKLIST"
echo "======================="
echo ""
echo "□ Open PowerShell as Administrator"
echo "□ Run: wsl --install"
echo "□ Restart computer when prompted"
echo "□ Complete Ubuntu setup after restart"
echo "□ Run: podman machine init"
echo "□ Run: podman machine start"
echo "□ Run: ./migrate-mulesoft-image.sh"
echo "□ Verify image in Quay registry"
echo ""

echo "🔗 HELPFUL LINKS"
echo "================"
echo ""
echo "WSL Installation Guide:"
echo "https://docs.microsoft.com/en-us/windows/wsl/install"
echo ""
echo "Podman Desktop:"
echo "https://podman-desktop.io/"
echo ""
echo "Troubleshooting:"
echo "https://docs.podman.io/en/latest/troubleshooting.html"
echo ""

echo "✅ WSL + Podman fix guide complete!"
echo ""
echo "🚀 Next step: Open PowerShell as Administrator and run 'wsl --install'"
