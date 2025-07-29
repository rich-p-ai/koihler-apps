# WSL Installation Script
# Run this in PowerShell as Administrator

Write-Host "🔧 WSL Installation Script" -ForegroundColor Blue
Write-Host "==========================" -ForegroundColor Blue
Write-Host ""

# Check if running as Administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 To run as Administrator:" -ForegroundColor Yellow
    Write-Host "   1. Press Win+X" -ForegroundColor White
    Write-Host "   2. Click 'Windows PowerShell (Admin)'" -ForegroundColor White
    Write-Host "   3. Navigate to this directory" -ForegroundColor White
    Write-Host "   4. Run: .\install-wsl.ps1" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "✅ Running as Administrator - Ready to install WSL!" -ForegroundColor Green
Write-Host ""

# Check current WSL status
Write-Host "🔍 Checking current WSL status..." -ForegroundColor Yellow
try {
    $wslStatus = wsl --status 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ WSL is already installed" -ForegroundColor Green
        Write-Host $wslStatus
        
        # Check distributions
        Write-Host ""
        Write-Host "📋 Installed distributions:" -ForegroundColor Yellow
        wsl --list --verbose
        
        Write-Host ""
        Write-Host "🎯 WSL appears to be working. You can proceed to configure Podman:" -ForegroundColor Green
        Write-Host "   podman machine init --cpus 2 --memory 4096" -ForegroundColor White
        Write-Host "   podman machine start" -ForegroundColor White
        
        Read-Host "Press Enter to continue"
        exit 0
    }
} catch {
    Write-Host "⚠️  WSL not installed or not working properly" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🚀 Installing WSL..." -ForegroundColor Yellow
Write-Host "This will install WSL2 and Ubuntu distribution" -ForegroundColor White
Write-Host ""

# Install WSL
try {
    Write-Host "Running: wsl --install" -ForegroundColor Cyan
    wsl --install
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ WSL installation completed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🔄 RESTART REQUIRED!" -ForegroundColor Red
        Write-Host "===================" -ForegroundColor Red
        Write-Host ""
        Write-Host "You MUST restart your computer now for WSL to work properly." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "📋 After restart:" -ForegroundColor Yellow
        Write-Host "   1. Ubuntu will start automatically (first time setup)" -ForegroundColor White
        Write-Host "   2. Create a username and password for Ubuntu" -ForegroundColor White
        Write-Host "   3. Run: sudo apt update && sudo apt upgrade" -ForegroundColor White
        Write-Host "   4. Then configure Podman:" -ForegroundColor White
        Write-Host "      podman machine init --cpus 2 --memory 4096" -ForegroundColor White
        Write-Host "      podman machine start" -ForegroundColor White
        Write-Host "   5. Test migration: ./migrate-mulesoft-image.sh" -ForegroundColor White
        Write-Host ""
        
        $restart = Read-Host "Do you want to restart now? (y/N)"
        if ($restart -eq "y" -or $restart -eq "Y") {
            Write-Host "🔄 Restarting computer..." -ForegroundColor Yellow
            Restart-Computer -Force
        } else {
            Write-Host ""
            Write-Host "⚠️  Remember to restart your computer manually!" -ForegroundColor Yellow
            Write-Host "WSL will not work until you restart." -ForegroundColor Red
        }
        
    } else {
        Write-Host ""
        Write-Host "❌ WSL installation failed!" -ForegroundColor Red
        Write-Host "Error code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "   1. Ensure you're running as Administrator" -ForegroundColor White
        Write-Host "   2. Check Windows version (WSL requires Windows 10 v2004+)" -ForegroundColor White
        Write-Host "   3. Enable Virtualization in BIOS" -ForegroundColor White
        Write-Host "   4. Try: dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart" -ForegroundColor White
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ WSL installation encountered an error!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Manual installation steps:" -ForegroundColor Yellow
    Write-Host "   1. Enable WSL feature: dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart" -ForegroundColor White
    Write-Host "   2. Enable VM Platform: dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart" -ForegroundColor White
    Write-Host "   3. Restart computer" -ForegroundColor White
    Write-Host "   4. Download WSL2 kernel: https://aka.ms/wsl2kernel" -ForegroundColor White
    Write-Host "   5. Set WSL2 as default: wsl --set-default-version 2" -ForegroundColor White
    Write-Host "   6. Install Ubuntu: wsl --install -d Ubuntu" -ForegroundColor White
}

Write-Host ""
Read-Host "Press Enter to exit"
