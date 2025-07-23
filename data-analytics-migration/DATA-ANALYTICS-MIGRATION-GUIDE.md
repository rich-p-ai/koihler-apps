# 🚀 DATA ANALYTICS MIGRATION GUIDE

## 📋 Overview
This guide covers the complete migration of the `data-analytics` namespace from OCP4 to the new OCP-PRD cluster, with conversion to a GitOps deployment using Kustomize and ArgoCD integration.

## 🎯 Migration Objectives
- ✅ Migrate all Secrets and ConfigMaps
- ✅ Migrate all PVCs and PVs with proper storage class mapping
- ✅ Create service accounts with correct SCC permissions
- ✅ Convert to GitOps deployment using Kustomize
- ✅ Set up ArgoCD applications for automated deployment
- ✅ Ensure environment separation (dev/prd)
- ✅ Maintain data persistence and security

## 📁 Migration Components

### Critical Resources to Migrate:
1. **Storage** - PVCs and PVs (with storage class updates)
2. **Security** - Secrets, service accounts, SCC bindings
3. **Configuration** - ConfigMaps
4. **Workloads** - Deployments, DeploymentConfigs, Services, Routes
5. **Images** - ImageStreams and container images

### Service Account Requirements:
- **useroot** service account with **anyuid** SCC for applications requiring root privileges
- Proper image pull secrets for Quay registry access

## 🔧 Prerequisites

### Tools Required:
```bash
# Verify tools are installed
oc version
kubectl version --client
yq --version
kustomize version  # Optional but recommended
```

### Cluster Access:
```bash
# Login to source cluster (OCP4)
oc login https://api.ocp4.kohlerco.com:6443

# Verify access to data-analytics namespace
oc project data-analytics
oc get all
```

### ArgoCD Access (Optional):
```bash
# For GitOps deployment
oc login https://api.ocp-prd.kohlerco.com:6443
oc get applications -n openshift-gitops
```

## 📦 Step 1: Export Resources from OCP4

### Option A: Use Automated Migration Script (Recommended)
```bash
cd "/c/work/OneDrive - Kohler Co/Openshift/git/migration/data-analytics-migration"
./migrate-data-analytics.sh
```

This script will:
- Export all resources from data-analytics namespace
- Clean and prepare resources for target cluster
- Create GitOps structure with Kustomize
- Generate ArgoCD applications
- Create deployment scripts
- Generate migration summary

### Option B: Manual Export
```bash
# Create migration directory
mkdir -p data-analytics-migration/backup/raw
cd data-analytics-migration

# Export core resources
oc get pvc -n data-analytics -o yaml > backup/raw/data-analytics-all-pvcs-raw.yaml
oc get secrets -n data-analytics -o yaml > backup/raw/data-analytics-all-secrets-raw.yaml
oc get configmaps -n data-analytics -o yaml > backup/raw/data-analytics-all-configmaps-raw.yaml
oc get serviceaccounts -n data-analytics -o yaml > backup/raw/data-analytics-all-serviceaccounts-raw.yaml

# Export workload resources
oc get deployments -n data-analytics -o yaml > backup/raw/data-analytics-all-deployments-raw.yaml
oc get deploymentconfigs -n data-analytics -o yaml > backup/raw/data-analytics-all-deploymentconfigs-raw.yaml
oc get services -n data-analytics -o yaml > backup/raw/data-analytics-all-services-raw.yaml
oc get routes -n data-analytics -o yaml > backup/raw/data-analytics-all-routes-raw.yaml
oc get imagestreams -n data-analytics -o yaml > backup/raw/data-analytics-all-imagestreams-raw.yaml
```

## 🧹 Step 2: Clean Resources for Target Cluster

The migration script automatically handles:
- Remove cluster-specific metadata (resourceVersion, uid, etc.)
- Update storage classes for target cluster compatibility
- Filter out system-generated secrets and service accounts
- Update route hostnames for target cluster domain
- Prepare resources for GitOps deployment

### Storage Class Mapping:
- `glusterfs-storage` → `ocs-storagecluster-ceph-rbd`
- `glusterfs-storage-block` → `ocs-storagecluster-ceph-rbd`
- `nfs-client` → `ocs-storagecluster-cephfs`

## 🗂️ Step 3: GitOps Structure Creation

The migration creates a complete Kustomize structure:

```
gitops/
├── base/
│   ├── kustomization.yaml       # Base configuration
│   ├── namespace.yaml           # Namespace definition
│   ├── serviceaccount.yaml      # Service accounts
│   └── scc-binding.yaml         # Security context constraints
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml   # Development overlay
│   │   ├── storage.yaml         # PVCs
│   │   ├── secrets.yaml         # Secrets
│   │   └── configmaps.yaml      # ConfigMaps
│   └── prd/
│       ├── kustomization.yaml   # Production overlay
│       ├── storage.yaml         # PVCs
│       ├── secrets.yaml         # Secrets
│       ├── configmaps.yaml      # ConfigMaps
│       ├── deployments.yaml     # Deployments
│       ├── services.yaml        # Services
│       └── routes.yaml          # Routes
└── argocd-application.yaml      # ArgoCD applications
```

## 🎯 Step 4: Deploy to OCP-PRD Cluster

### Option A: GitOps with ArgoCD (Recommended)
```bash
# Login to target cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy ArgoCD applications
kubectl apply -f gitops/argocd-application.yaml

# Monitor sync status
argocd app list
argocd app sync data-analytics-prd
```

### Option B: Kustomize Direct Deployment
```bash
# Production environment
kubectl apply -k gitops/overlays/prd

# Development environment
kubectl apply -k gitops/overlays/dev
```

### Option C: Manual Deployment
```bash
# Run the generated deployment script
./deploy-to-ocp-prd.sh
```

## ✅ Step 5: Verification

### Infrastructure Verification:
```bash
# Check namespace
kubectl get namespace data-analytics

# Check PVCs
kubectl get pvc -n data-analytics

# Check service account and SCC
kubectl get serviceaccount -n data-analytics
oc get scc data-analytics-anyuid

# Check secrets and configmaps
kubectl get secrets,configmaps -n data-analytics
```

### Application Verification:
```bash
# Check pods
kubectl get pods -n data-analytics

# Check services and routes
kubectl get services,routes -n data-analytics

# Check logs
kubectl logs -n data-analytics -l app.kubernetes.io/name=data-analytics
```

### GitOps Verification:
```bash
# Check ArgoCD applications
argocd app list | grep data-analytics

# Check sync status
argocd app get data-analytics-prd
```

## 🔄 Step 6: Post-Migration Tasks

### Container Image Migration:
```bash
# Identify images that need migration
oc get imagestreams -n data-analytics

# Migrate to Quay registry (if needed)
# Follow container image migration procedures
```

### Data Migration:
```bash
# If applications have persistent data, plan data migration
# Use appropriate tools based on data type (databases, files, etc.)
```

### Testing:
```bash
# Test application functionality
# Verify external integrations
# Check data integrity
# Test backup and recovery procedures
```

## 🚨 Troubleshooting

### Common Issues:

#### PVCs Not Binding:
```bash
# Check storage class availability
kubectl get storageclass

# Check PVC events
kubectl describe pvc -n data-analytics <pvc-name>
```

#### Permission Issues:
```bash
# Verify SCC binding
oc describe scc data-analytics-anyuid
oc get rolebinding,clusterrolebinding | grep data-analytics
```

#### ArgoCD Sync Issues:
```bash
# Check application status
argocd app get data-analytics-prd

# Manual sync
argocd app sync data-analytics-prd --prune
```

#### Pod Startup Issues:
```bash
# Check pod logs
kubectl logs -n data-analytics <pod-name>

# Check events
kubectl get events -n data-analytics --sort-by='.lastTimestamp'
```

## 📊 Success Criteria

### Infrastructure Complete:
- ✅ Namespace created with proper labels and annotations
- ✅ All PVCs bound and accessible
- ✅ Service account created with correct SCC
- ✅ Secrets and ConfigMaps deployed
- ✅ GitOps structure implemented with Kustomize

### Application Ready:
- ✅ Container images available in target registry
- ✅ Workloads deployed and running
- ✅ External connectivity verified
- ✅ Data persistence confirmed
- ✅ ArgoCD applications syncing successfully

### GitOps Ready:
- ✅ Kustomize base and overlays functional
- ✅ ArgoCD applications created and syncing
- ✅ Environment separation (dev/prd) working
- ✅ Automated deployment pipeline established

## 📁 File Structure

After migration, your directory should look like:
```
data-analytics-migration/
├── backup/
│   └── raw/                     # Original exports
├── cleaned/                     # Cleaned resources ready for deployment
├── gitops/                      # GitOps structure with Kustomize
│   ├── base/                    # Base Kustomize configuration
│   ├── overlays/                # Environment-specific overlays
│   │   ├── dev/                 # Development environment
│   │   └── prd/                 # Production environment
│   └── argocd-application.yaml  # ArgoCD application definitions
├── deploy-to-ocp-prd.sh         # Automated deployment script
└── DATA-ANALYTICS-MIGRATION-SUMMARY.md  # Migration summary
```

## 🎉 Completion

Once all steps are completed successfully:
1. Document any application-specific configurations
2. Update monitoring and alerting for new cluster
3. Set up automated GitOps workflows
4. Communicate migration completion to stakeholders
5. Archive OCP4 resources (if decommissioning)
6. Train team on new GitOps procedures

---

## 🚀 Key Benefits of This Migration Approach

### GitOps Implementation:
- **Infrastructure as Code**: All resources defined in Git
- **Environment Management**: Separate dev/prd configurations
- **Automated Deployment**: ArgoCD handles deployment and sync
- **Rollback Capability**: Easy rollback through Git
- **Audit Trail**: Complete history of changes

### Kustomize Benefits:
- **DRY Principle**: Base configuration with overlays
- **Environment Specific**: Different configurations per environment
- **Maintainable**: Clear separation of concerns
- **Scalable**: Easy to add new environments

### Migration Benefits:
- **Zero Downtime**: New deployment alongside existing
- **Validated Process**: Based on successful migration patterns
- **Comprehensive**: All resources and configurations migrated
- **Well Documented**: Complete migration documentation

---

**Based on successful migrations of:**
- ✅ **mulesoftapps** (100% complete)
- ✅ **kitchenandbathapps** (infrastructure complete)
- ✅ **crmapplications** (ready for migration)
- 🔄 **data-analytics** (ready for GitOps migration)

This guide ensures a consistent, reliable migration process with modern GitOps practices.
