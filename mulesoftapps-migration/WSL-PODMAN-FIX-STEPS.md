# 🚀 **WSL + PODMAN FIX - STEP BY STEP**

## 🎯 **Current Status**
- ❌ WSL not installed (confirmed by commands showing help instead of status)
- ✅ Podman 5.2.2 installed but can't run due to missing WSL
- ✅ All migration scripts ready and waiting

---

## 📋 **EXACT STEPS TO FIX**

### **STEP 1: Install WSL (5 minutes)**

1. **Right-click on Start button** → **Windows PowerShell (Admin)**
   
2. **Run this command:**
   ```powershell
   wsl --install
   ```

3. **Wait for installation** (usually takes 2-5 minutes)

4. **When prompted, restart your computer** ⚠️ **THIS IS REQUIRED!**

---

### **STEP 2: After Restart (10 minutes)**

5. **Ubuntu will start automatically** (first time only)
   - Create a username (example: `your-name`)
   - Create a password (you'll need this later)
   - Wait for setup to complete

6. **Update Ubuntu** (run in Ubuntu window):
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

7. **Close Ubuntu window**

---

### **STEP 3: Configure Podman (5 minutes)**

8. **Open regular PowerShell or Command Prompt**

9. **Initialize Podman machine:**
   ```bash
   podman machine init --cpus 2 --memory 4096
   ```

10. **Start Podman machine:**
    ```bash
    podman machine start
    ```

11. **Test Podman:**
    ```bash
    podman run hello-world
    ```

---

### **STEP 4: Run Migration (2 minutes)**

12. **Navigate to migration directory:**
    ```bash
    cd "c:\work\OneDrive - Kohler Co\Openshift\git\koihler-apps\mulesoftapps-migration"
    ```

13. **Run the migration:**
    ```bash
    ./migrate-mulesoft-image.sh
    ```

14. **Verify success** in Quay UI: https://kohler-registry-quay-quay.apps.ocp-host.kohlerco.com

---

## 🛠️ **Helper Scripts Available**

### **For WSL Installation:**
```powershell
# Run in PowerShell as Administrator
.\install-wsl.ps1
```

### **After Restart:**
```bash
# Run to configure Podman
./setup-podman-after-restart.sh
```

### **Check Status:**
```bash
# Run anytime to check what's working
./runtime-diagnostic.sh
```

---

## 🚨 **IMPORTANT NOTES**

- **Administrator required** for WSL installation only
- **Computer restart is mandatory** after WSL installation
- **Total time:** ~20 minutes (including restart)
- **Internet required** for downloading Ubuntu and container images

---

## 🎯 **SUCCESS INDICATORS**

✅ **WSL Working:** `wsl --status` shows status info (not help text)  
✅ **Podman Working:** `podman machine list` shows running machine  
✅ **Migration Ready:** `./runtime-diagnostic.sh` shows "Ready to migrate"  

---

## 🔧 **If Something Goes Wrong**

### **WSL Installation Fails:**
- Ensure Windows 10 version 2004+ or Windows 11
- Enable Virtualization in BIOS
- Try manual installation: `dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart`

### **Podman Fails to Start:**
- Ensure WSL2 is default: `wsl --set-default-version 2`
- Check virtualization enabled
- Try: `podman machine rm` then `podman machine init`

### **Need Help:**
- Run `./runtime-diagnostic.sh` for current status
- Check `CONTAINER-RUNTIME-FIX-GUIDE.md` for detailed troubleshooting

---

## 🚀 **START NOW**

**Right-click Start button → Windows PowerShell (Admin) → Run:**
```powershell
wsl --install
```

**Then restart when prompted!** 🔄
