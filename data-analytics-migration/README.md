# Data Analytics Migration to OCP-PRD with GitOps

This project contains the complete migration of the `data-analytics` namespace from OCP4 cluster to the new OCP-PRD cluster, with conversion to a modern GitOps deployment using Kustomize and ArgoCD.

## 🎯 Project Overview

- **Source**: OCP4 cluster (`api.ocp4.kohlerco.com`)
- **Target**: OCP-PRD cluster (`api.ocp-prd.kohlerco.com`)
- **Namespace**: `data-analytics`
- **Method**: GitOps with Kustomize overlays
- **Orchestration**: ArgoCD applications

## 📁 Project Structure

```
data-analytics-migration/
├── README.md                           # This file
├── DATA-ANALYTICS-MIGRATION-GUIDE.md   # Complete migration guide
├── migration-scripts/                  # Migration automation scripts
│   ├── migrate-data-analytics.sh       # Automated migration script
│   ├── quick-start.sh                  # Quick start guide
│   └── deploy-to-ocp-prd.sh           # Deployment script (generated)
├── backup/                             # Backup of original resources
│   └── raw/                           # Raw exports from OCP4
├── cleaned/                           # Cleaned resources ready for deployment
└── gitops/                            # GitOps structure with Kustomize
│   ├── base/                          # Base Kustomize configuration
│   │   ├── kustomization.yaml         # Base kustomization
│   │   ├── namespace.yaml             # Namespace definition
│   │   ├── serviceaccount.yaml        # Service accounts
│   │   └── scc-binding.yaml           # Security context constraints
│   ├── overlays/                      # Environment-specific overlays
│   │   ├── dev/                       # Development environment
│   │   │   ├── kustomization.yaml     # Dev-specific configuration
│   │   │   ├── storage.yaml           # PVCs for development
│   │   │   ├── secrets.yaml           # Secrets for development
│   │   │   └── configmaps.yaml        # ConfigMaps for development
│   │   └── prd/                       # Production environment
│   │       ├── kustomization.yaml     # Prod-specific configuration
│   │       ├── storage.yaml           # PVCs for production
│   │       ├── secrets.yaml           # Secrets for production
│   │       ├── configmaps.yaml        # ConfigMaps for production
│   │       ├── deployments.yaml       # Deployments for production
│   │       ├── services.yaml          # Services for production
│   │       └── routes.yaml            # Routes for production
│   └── argocd-application.yaml        # ArgoCD application definitions
└── deploy-to-ocp-prd.sh              # Deployment script
```

## 🚀 Quick Start

### Prerequisites
- Access to OCP4 cluster (for backup)
- Access to OCP-PRD cluster (for deployment)
- OpenShift CLI (`oc`)
- Kubernetes CLI (`kubectl`)
- `yq` for YAML processing
- Optional: ArgoCD CLI

### Step 1: Run Migration Script
```bash
# Login to OCP4 cluster
oc login https://api.ocp4.kohlerco.com:6443

# Navigate to migration directory
cd "/c/work/OneDrive - Kohler Co/Openshift/git/koihler-apps/data-analytics-migration"

# Run migration script
./migration-scripts/migrate-data-analytics.sh
```

### Step 2: Deploy to OCP-PRD
```bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Option A: GitOps with ArgoCD (Recommended)
kubectl apply -f gitops/argocd-application.yaml

# Option B: Direct Kustomize deployment
kubectl apply -k gitops/overlays/prd

# Option C: Manual deployment
./migration-scripts/deploy-to-ocp-prd.sh
```

## 🔧 Key Features

### GitOps Ready
- **Kustomize**: Structured overlay approach for different environments
- **ArgoCD**: Automated deployment and sync capabilities
- **Environment Isolation**: Separate dev and prd configurations
- **Infrastructure as Code**: All resources defined in Git

### Migration Benefits
- **Automated**: One-click migration script
- **Safe**: Original resources preserved in backup
- **Clean**: Resources cleaned and optimized for target cluster
- **Tested**: Based on successful migration patterns

### Security
- **Service Account**: `useroot` with `anyuid` SCC permissions
- **Clean Secrets**: All sensitive data preserved
- **RBAC**: Proper role bindings configured
- **Storage**: Updated storage classes for target cluster

## 📋 Deployment Options

### 1. GitOps with ArgoCD (Recommended)
- Automated sync and drift detection
- Git-based configuration management
- Easy rollback capabilities
- Multi-environment support

### 2. Kustomize Direct Deployment
- Environment-specific configurations
- Overlay-based customization
- Kubernetes-native approach

### 3. Manual Deployment
- Step-by-step control
- Useful for troubleshooting
- Direct resource application

## 🔍 Verification

After deployment, verify the migration:

```bash
# Check namespace and resources
kubectl get namespace data-analytics
kubectl get all -n data-analytics

# Check storage
kubectl get pvc -n data-analytics

# Check security
kubectl get serviceaccount -n data-analytics
oc get scc data-analytics-anyuid

# Check ArgoCD sync (if using GitOps)
argocd app list | grep data-analytics
```

## 📚 Documentation

- **[DATA-ANALYTICS-MIGRATION-GUIDE.md](DATA-ANALYTICS-MIGRATION-GUIDE.md)**: Complete step-by-step migration guide
- **Migration Summary**: Generated after running migration script
- **Deployment Scripts**: Automated deployment options

## 🚨 Troubleshooting

### Common Issues

1. **PVCs not binding**: Check storage class availability
2. **Permission errors**: Verify SCC bindings
3. **ArgoCD sync issues**: Check application configuration
4. **Pod startup failures**: Check resource quotas and limits

### Getting Help

1. Check the migration guide for detailed troubleshooting
2. Review generated migration summary
3. Check OpenShift events and logs
4. Consult with OpenShift migration team

## 🎯 Success Criteria

- ✅ All resources migrated successfully
- ✅ GitOps structure implemented
- ✅ ArgoCD applications syncing
- ✅ Applications running in target cluster
- ✅ Storage and security properly configured

## 🔄 Rollback

If issues occur:

```bash
# Remove ArgoCD applications
kubectl delete -f gitops/argocd-application.yaml

# Or remove namespace entirely
kubectl delete namespace data-analytics
```

Original resources are preserved in `backup/raw/` directory.

## 👥 Team

- **Migration Team**: OpenShift Migration Specialists
- **Based on**: Successful mulesoftapps and kitchenandbathapps migrations
- **GitOps Approach**: Modern deployment practices with ArgoCD

## 📈 Next Steps

1. Monitor application performance
2. Set up monitoring and alerting
3. Train team on GitOps procedures
4. Plan additional namespace migrations
5. Optimize resource usage

---

**Status**: Ready for production deployment with GitOps! 🚀
