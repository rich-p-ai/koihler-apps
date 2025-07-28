# 🚀 Kohler OpenShift Applications - GitOps Repository

This repository contains OpenShift application deployments and migrations for Kohler Co, managed through ArgoCD for automated GitOps workflows.

## 📊 Current Status

✅ **ArgoCD Connected**: Repository successfully connected to OpenShift GitOps  
✅ **Data Analytics**: Successfully migrated and deployed to OCP-PRD  
✅ **GitOps Active**: Automated sync and deployment operational  

## 🔧 ArgoCD Integration

### Repository Connection
- **Repository URL**: `https://github.com/rich-p-ai/koihler-apps.git`
- **ArgoCD Instance**: OpenShift GitOps (`openshift-gitops` namespace)
- **Connection Status**: ✅ Connected and operational

### Active Applications
- **data-analytics-prd**: Production deployment of data-analytics namespace
  - **Path**: `data-analytics-migration/gitops/overlays/prd`
  - **Status**: ✅ Healthy and syncing
  - **Sync Policy**: Automated with self-healing

- **procurementapps-prd**: Production deployment of procurementapps namespace
  - **Path**: `procurementapps-migration/gitops/overlays/prd`
  - **Status**: 🔄 Ready for deployment
  - **Sync Policy**: Automated with self-healing

### Access ArgoCD UI
```bash
# Get ArgoCD URL
echo "https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"

# Direct URL: https://openshift-gitops-server-openshift-gitops.apps.ocp-prd.kohlerco.com
```

## Repository Structure

```
koihler-apps/
├── README.md
├── ARGOCD-SETUP-GUIDE.md           # ArgoCD integration guide
├── argocd-repository.yaml          # ArgoCD repository configuration
├── setup-argocd.sh                 # Automated ArgoCD setup script
├── data-analytics-migration/        # Data Analytics migration to OCP-PRD
│   ├── README.md                   # Migration project overview
│   ├── gitops/                     # GitOps structure with Kustomize
│   │   ├── base/                   # Base Kustomize configuration
│   │   └── overlays/               # Environment-specific overlays
│   └── migration-scripts/          # Migration automation scripts
├── procurementapps-migration/       # Procurement Apps migration to OCP-PRD
│   ├── README.md                   # Migration project overview
│   ├── gitops/                     # GitOps structure with Kustomize
│   │   ├── base/                   # Base Kustomize configuration
│   │   └── overlays/               # Environment-specific overlays
│   └── migrate-procurementapps.sh  # Migration automation script
└── applications/                   # Future application deployments
    └── README.md
```

## Projects

### Data Analytics Migration
Complete migration of the `data-analytics` namespace from OCP4 to OCP-PRD cluster with GitOps deployment using Kustomize and ArgoCD.

**Location**: `data-analytics-migration/`
**Status**: ✅ Deployed and operational
**Method**: GitOps with Kustomize overlays

### Procurement Apps Migration
Migration of the `procurementapps` namespace from OCP4 to OCP-PRD with conversion from DeploymentConfigs to Deployments and GitOps deployment.

**Location**: `procurementapps-migration/`
**Status**: 🔄 Ready for deployment
**Method**: DeploymentConfig → Deployment + GitOps
**Applications**: pm-procedures-prod, pm-procedures-test

### Corporate Apps Migration
Migration of the `corporateapps` namespace from PRD cluster to GitOps repository management for automated deployment using ArgoCD.

**Location**: `corporateapps-migration/`
**Status**: 🆕 Ready to execute
**Method**: GitOps with Kustomize overlays
**Applications**: java-phonelist-prd, wins0001173-prd, wins0001174-prd, batch processing applications

## Getting Started

### 1. ArgoCD Repository Setup
```bash
# Add repository to ArgoCD
./setup-argocd.sh

# Or manually apply repository configuration
kubectl apply -f argocd-repository.yaml
```

### 2. Deploy Applications
```bash
# Data Analytics (already deployed)
kubectl apply -f data-analytics-migration/gitops/argocd-application.yaml

# Procurement Apps (new)
kubectl apply -f procurementapps-migration/gitops/argocd-application.yaml

# Corporate Apps (new - run migration first)
cd corporateapps-migration && ./migrate-corporateapps.sh
kubectl apply -f corporateapps-migration/gitops/argocd-application.yaml
```

### 3. Direct Kustomize Deployment (Alternative)
```bash
# Data Analytics Production
kubectl apply -k data-analytics-migration/gitops/overlays/prd

# Procurement Apps Production
kubectl apply -k procurementapps-migration/gitops/overlays/prd

# Corporate Apps Production (after migration)
kubectl apply -k corporateapps-migration/gitops/overlays/prd

# Procurement Apps Production
kubectl apply -k procurementapps-migration/gitops/overlays/prd
```

### 4. ArgoCD Applications
```bash
kubectl apply -f data-analytics-migration/gitops/argocd-application.yaml
```

## Repository Management

This repository follows GitOps principles where:
- Infrastructure is defined as code
- Changes are made via Git commits
- ArgoCD automatically syncs deployments
- Environment-specific configurations use Kustomize overlays

## Contact

- **Team**: OpenShift Migration Specialists
- **Repository**: https://github.com/rich-p-ai/koihler-apps.git
