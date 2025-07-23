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
└── applications/                   # Future application deployments
    └── README.md
```

## Projects

### Data Analytics Migration
Complete migration of the `data-analytics` namespace from OCP4 to OCP-PRD cluster with GitOps deployment using Kustomize and ArgoCD.

**Location**: `data-analytics-migration/`
**Status**: Ready for deployment
**Method**: GitOps with Kustomize overlays

## Getting Started

### 1. ArgoCD Repository Setup
```bash
# Add repository to ArgoCD
./setup-argocd.sh

# Or manually apply repository configuration
kubectl apply -f argocd-repository.yaml
```

### 2. Data Analytics Migration
```bash
cd data-analytics-migration
./migration-scripts/quick-start.sh
```

### 3. GitOps Deployment
```bash
# Production
kubectl apply -k data-analytics-migration/gitops/overlays/prd

# Development
kubectl apply -k data-analytics-migration/gitops/overlays/dev
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
