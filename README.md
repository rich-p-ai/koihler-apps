# Kohler OpenShift Applications

This repository contains OpenShift application deployments and migrations for Kohler Co.

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
