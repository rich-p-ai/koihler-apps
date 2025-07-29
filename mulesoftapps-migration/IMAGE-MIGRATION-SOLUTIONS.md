# 🚀 Mulesoft Image Migration Solutions

The image migration encountered issues with the local container runtime (Podman/Docker). Here are multiple solutions to complete the migration:

## 🎯 **Problem Analysis**

### Issues Identified:
- ✅ **Source Registry Login**: Success via `oc registry login`
- ❌ **Target Registry Login**: Failed due to Podman connection issues
- ❌ **Container Runtime**: Podman not properly initialized on Windows
- ❌ **Docker**: Not installed or configured

## 🛠️ **Solution Options**

### **Option 1: OpenShift Image Mirror (Recommended)**

Use OpenShift's built-in image mirroring capability:

```bash
# Run the OpenShift-native migration
./migrate-image-with-oc-mirror.sh
```

**Benefits:**
- ✅ Uses OpenShift CLI only (no container runtime needed)
- ✅ Direct registry-to-registry transfer
- ✅ Handles authentication automatically
- ✅ Works on Windows without Docker/Podman setup

### **Option 2: Fix Podman Setup**

Initialize Podman for Windows:

```bash
# Initialize Podman machine
podman machine init

# Start Podman machine
podman machine start

# Test connection
podman system connection list

# Then run the original migration
./migrate-mulesoft-image.sh
```

### **Option 3: Use WSL with Docker**

If you have WSL2 with Docker:

```bash
# Switch to WSL2
wsl

# Run migration from within WSL
./migrate-mulesoft-image.sh
```

### **Option 4: Manual Registry Operations**

Use `oc` commands for manual image operations:

```bash
# Export image from source
oc image extract <source-image> --path /tmp/image-export

# Import to target (requires additional setup)
# This is more complex and not recommended
```

## 🎯 **Recommended Approach**

**Run the OpenShift Image Mirror solution:**

```bash
./migrate-image-with-oc-mirror.sh
```

This approach:
- ✅ Bypasses local container runtime issues
- ✅ Uses native OpenShift capabilities
- ✅ Handles authentication properly
- ✅ Works regardless of local environment setup

## 🔧 **Quick Fix Commands**

### **For Immediate Migration**

```bash
# 1. Ensure you're logged into OCPAZ
oc whoami --show-server

# 2. Run the OpenShift-native migration
./migrate-image-with-oc-mirror.sh

# 3. Verify migration success
# Check the generated report: MULESOFT-IMAGE-MIRROR-REPORT.md
```

### **For Container Runtime Setup (Optional)**

If you want to fix Podman for future use:

```bash
# Initialize Podman
podman machine init

# Start Podman
podman machine start

# Test basic functionality
podman run hello-world

# Then test registry credentials
./test-quay-registry-creds.sh
```

## 📋 **Migration Status**

### ✅ **Working Components**
- OpenShift CLI (`oc`) - Installed and working
- OCPAZ cluster access - Connected successfully
- Source registry authentication - Success via `oc registry login`
- Target registry credentials - Provided and valid

### ❌ **Issues**
- Podman connection - Not initialized properly
- Docker - Not installed
- Skopeo - Not available

### 🎯 **Best Path Forward**
Use `migrate-image-with-oc-mirror.sh` which leverages OpenShift's native image mirroring and bypasses local container runtime requirements.

## 🚀 **Execute Migration Now**

```bash
# Run the working solution
./migrate-image-with-oc-mirror.sh
```

This will:
1. ✅ Use your existing OCPAZ connection
2. ✅ Discover the mulesoft-accelerator-2 image
3. ✅ Create proper authentication for Quay registry
4. ✅ Mirror the image directly registry-to-registry
5. ✅ Verify the migration success
6. ✅ Generate a detailed report

## 📊 **Expected Results**

After successful migration:
- **Source**: `default-route-openshift-image-registry.apps.ocpaz.kohlerco.com/mulesoftapps-prod/mulesoft-accelerator-2`
- **Target**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2`
- **Status**: ✅ Available in Quay registry
- **Usage**: Ready for deployment on OCP-PRD

Run the migration now with:
```bash
./migrate-image-with-oc-mirror.sh
```
