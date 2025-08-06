# OracleCPQ Migration from OCP4 to OCP-PRD

## Quick Start Guide

This migration script will help you migrate the `oraclecpq` namespace from OCP4 cluster to OCP-PRD cluster with GitOps structure for ArgoCD deployment.

### Overview

OracleCPQ is currently running on the OCP4 cluster and needs to be migrated to the new OCP-PRD production environment. This migration includes:

- **Application workloads** (deployments, statefulsets, services)
- **Configuration data** (configmaps, secrets)
- **Storage volumes** (PVCs with NFS backends)
- **Network routing** (NodePort services for HAProxy integration)
- **Security configurations** (RBAC, service accounts)

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
   - Access to OCP4 cluster (`https://api.ocp4.kohlerco.com:6443`)
   - Access to OCP-PRD cluster (`https://api.ocp-prd.kohlerco.com:6443`)
   - Permissions to read from source namespace and create resources in target cluster

3. **OCP4 Authentication Setup**:
   ```bash
   # Login to OCP4 cluster
   oc login https://api.ocp4.kohlerco.com:6443
   
   # Verify access to oraclecpq namespace
   oc get all -n oraclecpq
   ```

4. **NodePort Configuration**:
   - OracleCPQ uses specific NodePorts: 32029, 32030, 32031, 32074, 32075, 32076
   - These need to be configured on OCP-PRD worker nodes for HAProxy integration

## Running the Migration

### Step 1: Execute Migration Script

```bash
cd "c:\work\OneDrive - Kohler Co\Openshift\git\koihler-apps\oraclecpq-migration"

# Run the migration script
./migrate-oraclecpq.sh
```

The script will:
- Prompt you to login to OCP4 cluster
- Export all resources from `oraclecpq` namespace
- Clean and prepare resources for OCP-PRD
- Create GitOps structure with Kustomize
- Generate ArgoCD application manifest
- Create deployment scripts and documentation

### Step 2: Review Generated Files

After the script completes, review:

```bash
# Check the inventory report
cat ORACLECPQ-INVENTORY.md

# Review GitOps structure
tree gitops/

# Test Kustomize build
kubectl kustomize gitops/overlays/prd
```

### Step 3: Data Migration Planning

OracleCPQ uses NFS persistent volumes that need data migration:

```bash
# Check current NFS configuration
oc get pv | grep oraclecpq
oc get pvc -n oraclecpq

# NFS Paths to migrate:
# - DEV: /ifs/NFS/USWINFS01/D/Shared/DEV/kbnaOracleCpq
# - QA: /ifs/NFS/USWINFS01/D/Shared/QA/kbnaOracleCpq  
# - PRD: /ifs/NFS/USWINFS01/D/Shared/PRD/kbnaOracleCpq
```

**Important**: Coordinate with storage team for data migration from NFS volumes.

### Step 4: Commit to Git Repository

```bash
# Add files to git
git add .
git commit -m "Add OracleCPQ migration from OCP4 to OCP-PRD with GitOps structure"
git push origin main
```

### Step 5: Deploy to OCP-PRD

#### Option A: ArgoCD Deployment (Recommended)

```bash
# Login to OCP-PRD
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# Monitor deployment
oc get application oraclecpq-prd -n openshift-gitops -w
```

#### Option B: Direct Deployment

```bash
# Use the provided deployment script
./deploy-to-ocp-prd.sh
```

## Key Features of This Migration

- **Cross-Cluster**: OCP4 → OCP-PRD migration
- **GitOps Ready**: Kustomize structure for environment management
- **ArgoCD Integration**: Automated continuous deployment
- **Oracle CPQ Optimized**: Handles Oracle-specific configurations
- **Security**: Proper RBAC and SCC configurations
- **NodePort Support**: Configured for HAProxy integration
- **Documentation**: Complete inventory and deployment guides

## NodePort Configuration

OracleCPQ requires specific NodePort services for HAProxy integration:

```yaml
# NodePorts that need to be available on OCP-PRD workers:
# - 32029, 32030, 32031 (Primary services)
# - 32074, 32075, 32076 (Additional services)

# Worker nodes that need these ports:
# - 10.20.136.62 (worker1)
# - 10.20.136.63 (worker2)
# - 10.20.136.64 (worker3)
```

## Post-Migration Verification

```bash
# Check namespace and resources
oc get all -n oraclecpq

# Check ArgoCD sync status
oc get application oraclecpq-prd -n openshift-gitops

# Check routes and NodePort services
oc get route,svc -n oraclecpq

# Test application endpoints
curl -k https://oraclecpq.apps.ocp-prd.kohlerco.com/health
```

## Expected Domain Changes

- **Old Domain**: `*.apps.ocp4.kohlerco.com`
- **New Domain**: `*.apps.ocp-prd.kohlerco.com`
- **Expected Route**: `oraclecpq.apps.ocp-prd.kohlerco.com`

## Generated Directory Structure

```
oraclecpq-migration/
├── README.md                       # Detailed documentation
├── QUICK-SETUP.md                  # This file
├── migrate-oraclecpq.sh           # Migration script
├── deploy-to-ocp-prd.sh           # Deployment script
├── ORACLECPQ-INVENTORY.md         # Resource inventory
├── backup/                         # Original and cleaned resources
└── gitops/                         # GitOps structure
    ├── base/                       # Base configuration
    ├── overlays/prd/              # Production overlay
    └── argocd-application.yaml     # ArgoCD app definition
```

## Important Migration Considerations

### Database and External Integrations
- **Oracle Database**: Update connection strings for new cluster
- **External APIs**: Verify connectivity from OCP-PRD network
- **License Server**: Update Oracle CPQ license configuration

### Storage Migration
- **NFS Volumes**: Plan data export/import from NFS shares
- **Storage Classes**: Updated to use `gp3-csi` for OCP-PRD
- **Backup Strategy**: Ensure backups before migration

### Network and Security
- **NodePort Services**: Configure HAProxy rules for NodePort access
- **Security Groups**: Update firewall rules for new cluster
- **RBAC**: Verify `oraclecpq-admin` group access

## Troubleshooting

If you encounter issues:

1. **Check Prerequisites**: Ensure all CLI tools are installed
2. **Verify Cluster Access**: Test login to both clusters
3. **Review Logs**: Check script output for error messages
4. **Validate Resources**: Use `kubectl kustomize gitops/overlays/prd` to test
5. **Check NodePorts**: Verify NodePort availability on target cluster

For detailed troubleshooting, see the main `README.md` file.

## Migration Timeline

### Phase 1: Preparation (This Script)
- ✅ Export resources from OCP4
- ✅ Create GitOps structure
- ✅ Generate migration documentation

### Phase 2: Data Migration
- 📋 Export NFS data from OCP4
- 📋 Import data to OCP-PRD storage
- 📋 Verify data integrity

### Phase 3: Application Deployment
- 📋 Deploy via ArgoCD to OCP-PRD
- 📋 Configure NodePort services
- 📋 Update DNS records

### Phase 4: Testing & Cutover
- 📋 Comprehensive testing
- 📋 Performance validation
- 📋 Production cutover

## Next Steps

1. **Complete Migration Preparation**: Run this script to export and prepare resources
2. **Coordinate Data Migration**: Work with storage team for NFS data migration
3. **Deploy to OCP-PRD**: Use ArgoCD for application deployment
4. **Configure Network**: Set up HAProxy NodePort rules
5. **Update DNS**: Point domain to new cluster
6. **Comprehensive Testing**: Validate all Oracle CPQ functionality

---

**Ready to begin migration? Run `./migrate-oraclecpq.sh` to start!** 🚀
