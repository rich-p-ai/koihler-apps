# 🛠️ Container Runtime Fix Guide

The setup identified that **WSL (Windows Subsystem for Linux)** is not properly configured, which is required for Podman on Windows.

## 🎯 **Current Status**

### ❌ **Issues Found**
- Podman installed but cannot initialize machine
- WSL not properly configured/installed
- Docker not installed
- Error: `command C:\WINDOWS\System32\wsl.exe [-l --quiet] failed: exit status 1`

### ✅ **What's Working**
- Podman 5.2.2 is installed
- OpenShift CLI is working
- OCPAZ cluster connectivity established

## 🚀 **Solution Options**

### **Option 1: Fix WSL for Podman (Recommended)**

#### **Step 1: Install/Enable WSL**
```powershell
# Run in PowerShell as Administrator
wsl --install

# If WSL is already installed but not working:
wsl --update
wsl --set-default-version 2
```

#### **Step 2: Install a Linux Distribution**
```powershell
# Install Ubuntu (recommended)
wsl --install -d Ubuntu

# Or list available distributions
wsl --list --online
```

#### **Step 3: Initialize Podman After WSL Setup**
```bash
# After WSL is working, run:
podman machine init --cpus 2 --memory 4096
podman machine start
```

### **Option 2: Install Docker Desktop (Alternative)**

#### **Download and Install**
1. Go to: https://www.docker.com/products/docker-desktop/
2. Download Docker Desktop for Windows
3. Install with default settings
4. Ensure WSL2 integration is enabled in Docker settings

#### **Test Docker Installation**
```bash
docker --version
docker run hello-world
```

### **Option 3: Use OpenShift-Native Approach (No Container Runtime Needed)**

This is the **immediate solution** that bypasses container runtime issues:

```bash
./migrate-image-with-oc-mirror.sh
```

**Benefits:**
- ✅ Works without Docker/Podman
- ✅ Uses OpenShift's native image mirroring
- ✅ No additional setup required
- ✅ Ready to use now

## 🎯 **Immediate Action Plan**

### **For Immediate Migration (Recommended)**
```bash
# Use the OpenShift-native approach right now
./migrate-image-with-oc-mirror.sh
```

### **For Future Container Operations**

#### **Option A: Fix WSL + Podman**
```powershell
# 1. Run PowerShell as Administrator
# 2. Install WSL
wsl --install

# 3. Restart computer when prompted
# 4. After restart, set up Ubuntu
# 5. Then run:
```

```bash
podman machine init
podman machine start
./migrate-mulesoft-image.sh
```

#### **Option B: Install Docker Desktop**
```powershell
# 1. Download Docker Desktop from docker.com
# 2. Install with WSL2 backend
# 3. Start Docker Desktop
# 4. Test with:
```

```bash
docker run hello-world
./migrate-mulesoft-image.sh
```

## 🔧 **Detailed WSL Fix Steps**

### **1. Check Current WSL Status**
```powershell
# Run in PowerShell
wsl --status
wsl --list --verbose
```

### **2. Install/Update WSL**
```powershell
# Install WSL (if not installed)
wsl --install

# Update WSL (if already installed)
wsl --update
wsl --shutdown
```

### **3. Install Linux Distribution**
```powershell
# Install Ubuntu
wsl --install -d Ubuntu

# Set as default
wsl --set-default Ubuntu
```

### **4. Verify WSL is Working**
```powershell
wsl --list --verbose
# Should show Ubuntu running
```

### **5. Test Podman After WSL Fix**
```bash
podman machine init
podman machine start
podman run hello-world
```

## 📊 **Quick Status Check**

Run this to check what's working:
```bash
./container-runtime-helper.sh
```

## 🎯 **Recommended Path Forward**

### **Immediate (5 minutes)**
```bash
# Run the migration without container runtime
./migrate-image-with-oc-mirror.sh
```

### **Long-term Setup (30 minutes)**
1. **Install WSL**: Run `wsl --install` in Administrator PowerShell
2. **Restart Computer**: Required after WSL installation
3. **Setup Ubuntu**: Complete Ubuntu setup after restart
4. **Initialize Podman**: Run `podman machine init && podman machine start`
5. **Test**: Run `./migrate-mulesoft-image.sh`

## 🚨 **Important Notes**

- **WSL Installation requires Administrator privileges**
- **Computer restart is typically required after WSL installation**
- **Ubuntu setup will prompt for username/password creation**
- **WSL2 is required for both Podman and modern Docker Desktop**

## ✅ **Success Indicators**

### **WSL Working**
```powershell
wsl --list --verbose
# Shows: Ubuntu Running
```

### **Podman Working**
```bash
podman machine list
# Shows: podman-machine-default Running
```

### **Ready for Migration**
```bash
./test-quay-registry-creds.sh
# Shows: ✅ Login successful
```

---

## 🎯 **Execute Now**

**For immediate image migration:**
```bash
./migrate-image-with-oc-mirror.sh
```

**This will complete your image migration without needing to fix the container runtime first!**
