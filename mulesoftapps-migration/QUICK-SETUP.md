# Mulesoft Apps Migration from OCPAZ to OCP-PRD

## Quick Start Guide

This migration script will help you migrate the `mulesoftapps-prod` namespace from OCPAZ cluster to OCP-PRD cluster with GitOps structure for ArgoCD deployment.

## Prerequisites

Before running the migration:

1. **CLI Tools**:
   ```bash
   # Verify OpenShift CLI
   oc version
   
   # Verify kubectl
   kubectl version --client
   
   # Optional but recommended: Install yq
   # Windows: choco install yq
   # Or download from: https://github.com/mikefarah/yq/releases
   ```

2. **Cluster Access**:
   - Access to OCPAZ cluster (`https://api.ocpaz.kohlerco.com:6443`)
   - Access to OCP-PRD cluster (`https://api.ocp-prd.kohlerco.com:6443`)
   - Permissions to read from source namespace and create resources in target cluster
   - **OCPAZ Authentication**: Token-based authentication required (bash profile: `ocpaz`)

3. **OCPAZ Authentication Setup**:
   ```bash
   # Option 1: Use the login helper script
   ./login-ocpaz.sh
   
   # Option 2: Get token manually
   # 1. Visit: https://oauth-openshift.apps.ocpaz.kohlerco.com/oauth/token/request
   # 2. Copy the oc login command
   # 3. Execute: oc login --token=<your-token> --server=https://api.ocpaz.kohlerco.com:6443
   
   # Option 3: Use bash profile (if configured)
   source ~/.bash_profile  # should have ocpaz profile
   oc login https://api.ocpaz.kohlerco.com:6443
   ```

4. **Git Repository Access**:
   - Access to push to GitHub repository: `https://github.com/rich-p-ai/koihler-apps.git`

## Running the Migration

### Step 1: Execute Migration Script

```bash
cd "c:\work\OneDrive - Kohler Co\Openshift\git\koihler-apps\mulesoftapps-migration"

# Run the migration script
./migrate-mulesoftapps.sh
```

The script will:
- Prompt you to login to OCPAZ cluster
- Export all resources from `mulesoftapps-prod` namespace
- Clean and prepare resources for OCP-PRD
- Create GitOps structure with Kustomize
- Generate ArgoCD application manifest
- Create deployment scripts and documentation

### Step 2: Review Generated Files

After the script completes, review:

```bash
# Check the inventory report
cat MULESOFTAPPS-INVENTORY.md

# Review GitOps structure
tree gitops/

# Test Kustomize build
kubectl kustomize gitops/overlays/prd
```

### Step 3: Commit to Git Repository

```bash
# Add files to git
git add .
git commit -m "Add Mulesoft Apps migration from OCPAZ to OCP-PRD with GitOps structure"
git push origin main
```

### Step 4: Deploy to OCP-PRD

#### Option A: ArgoCD Deployment (Recommended)

```bash
# Login to OCP-PRD
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# Monitor deployment
oc get application mulesoftapps-prd -n openshift-gitops -w
```

#### Option B: Direct Deployment

```bash
# Use the provided deployment script
./deploy-to-ocp-prd.sh
```

## Key Features of This Migration

- **Cross-Cluster**: OCPAZ → OCP-PRD migration
- **GitOps Ready**: Kustomize structure for environment management
- **ArgoCD Integration**: Automated continuous deployment
- **Mulesoft Optimized**: Handles Mulesoft-specific configurations
- **Security**: Proper RBAC and SCC configurations
- **Documentation**: Complete inventory and deployment guides

## Post-Migration Verification

```bash
# Check namespace and resources
oc get all -n mulesoftapps-prod

# Check ArgoCD sync status
oc get application mulesoftapps-prd -n openshift-gitops

# Test application endpoints
oc get route -n mulesoftapps-prod
```

## Generated Directory Structure

```
mulesoftapps-migration/
├── README.md                       # Detailed documentation
├── QUICK-SETUP.md                  # This file
├── migrate-mulesoftapps.sh         # Migration script
├── deploy-to-ocp-prd.sh           # Deployment script
├── MULESOFTAPPS-INVENTORY.md       # Resource inventory
├── backup/                         # Original and cleaned resources
└── gitops/                         # GitOps structure
    ├── base/                       # Base configuration
    ├── overlays/prd/              # Production overlay
    └── argocd-application.yaml     # ArgoCD app definition
```

## Troubleshooting

If you encounter issues:

1. **Check Prerequisites**: Ensure all CLI tools are installed
2. **Verify Cluster Access**: Test login to both clusters
3. **Review Logs**: Check script output for error messages
4. **Validate Resources**: Use `kubectl kustomize gitops/overlays/prd` to test

For detailed troubleshooting, see the main `README.md` file.
