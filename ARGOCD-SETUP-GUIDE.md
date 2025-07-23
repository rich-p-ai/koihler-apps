# ArgoCD Repository Setup Guide - ✅ COMPLETED

This guide shows how to add the koihler-apps repository to ArgoCD for GitOps deployment of the data-analytics migration.

## 🎉 Setup Status: COMPLETED SUCCESSFULLY

✅ **Repository Connected**: koihler-apps repository successfully added to ArgoCD  
✅ **Application Deployed**: data-analytics-prd application created and syncing  
✅ **RBAC Configured**: ArgoCD permissions properly set  
✅ **Resources Created**: Namespace, ServiceAccount, and SCC deployed  

**Completion Date**: July 23, 2025  
**ArgoCD URL**: https://openshift-gitops-server-openshift-gitops.apps.ocp-prd.kohlerco.com

## 🚀 Quick Setup

### Option 1: Automated Setup (Recommended)
```bash
# Navigate to the repository
cd koihler-apps

# Run the automated setup script
./setup-argocd.sh
```

### Option 2: Manual Setup

#### Step 1: Add Repository to ArgoCD
```bash
# Apply the repository configuration
kubectl apply -f argocd-repository.yaml
```

#### Step 2: Deploy Applications
```bash
# Deploy both dev and production applications
kubectl apply -f data-analytics-migration/gitops/argocd-application.yaml
```

## 🔧 Manual ArgoCD UI Setup

If you prefer to use the ArgoCD web interface:

### 1. Access ArgoCD UI
```bash
# Get the ArgoCD route
oc get route argocd-server -n openshift-gitops

# Get the admin password
oc extract secret/argocd-initial-admin-secret -n openshift-gitops --to=-
```

### 2. Add Repository via UI
1. Login to ArgoCD UI
2. Go to **Settings** → **Repositories**
3. Click **+ CONNECT REPO**
4. Fill in:
   - **Type**: Git
   - **Repository URL**: `https://github.com/rich-p-ai/koihler-apps.git`
   - **Name**: `koihler-apps`
5. Click **CONNECT**

### 3. Create Applications via UI
1. Go to **Applications**
2. Click **+ NEW APP**
3. Fill in for Production:
   - **Application Name**: `data-analytics-prd`
   - **Project**: `default`
   - **Repository URL**: `https://github.com/rich-p-ai/koihler-apps.git`
   - **Path**: `data-analytics-migration/gitops/overlays/prd`
   - **Cluster URL**: `https://kubernetes.default.svc`
   - **Namespace**: `data-analytics`
4. Enable **Auto-Sync**
5. Click **CREATE**

Repeat for Development environment with:
- **Application Name**: `data-analytics-dev`
- **Path**: `data-analytics-migration/gitops/overlays/dev`

## 📊 Verification

### Check Repository
```bash
# Verify repository is added
kubectl get secret koihler-apps-repo -n openshift-gitops

# Check if ArgoCD can access the repo
argocd repo list | grep koihler-apps
```

### Check Applications
```bash
# List ArgoCD applications
kubectl get applications -n openshift-gitops

# Check application status
argocd app list | grep data-analytics
argocd app get data-analytics-prd
```

### Monitor Deployment
```bash
# Watch namespace creation
kubectl get namespace data-analytics

# Monitor resource creation
kubectl get all -n data-analytics
kubectl get pvc -n data-analytics

# Check application sync status
argocd app sync data-analytics-prd
argocd app logs data-analytics-prd
```

## 🔄 Sync and Management

### Manual Sync
```bash
# Sync production application
argocd app sync data-analytics-prd

# Sync development application
argocd app sync data-analytics-dev

# Sync with pruning (remove resources not in Git)
argocd app sync data-analytics-prd --prune
```

### Application Management
```bash
# Get application details
argocd app get data-analytics-prd

# View application resources
argocd app resources data-analytics-prd

# View application logs
argocd app logs data-analytics-prd

# Delete application (if needed)
argocd app delete data-analytics-prd
```

## 🚨 Troubleshooting

### Repository Connection Issues
```bash
# Check repository secret
kubectl describe secret koihler-apps-repo -n openshift-gitops

# Check ArgoCD server logs
kubectl logs -n openshift-gitops deployment/argocd-server

# Test repository connection manually
argocd repo get https://github.com/rich-p-ai/koihler-apps.git
```

### Application Sync Issues
```bash
# Check application status
argocd app get data-analytics-prd

# View sync operation details
argocd app history data-analytics-prd

# Check for resource conflicts
kubectl get events -n data-analytics

# Force refresh
argocd app get data-analytics-prd --refresh
```

### Common Issues

1. **Repository not accessible**:
   - Verify repository URL is correct
   - Check if repository is public or credentials are needed
   - Ensure ArgoCD has network access to GitHub

2. **Application won't sync**:
   - Check Kustomize syntax: `kubectl kustomize data-analytics-migration/gitops/overlays/prd`
   - Verify YAML syntax in all files
   - Check namespace permissions

3. **Resources not created**:
   - Verify target namespace exists or auto-creation is enabled
   - Check RBAC permissions
   - Review ArgoCD application logs

## 📋 Repository Structure

The ArgoCD applications will deploy from this structure:
```
koihler-apps/
└── data-analytics-migration/
    └── gitops/
        ├── base/                    # Base Kustomize resources
        │   ├── kustomization.yaml
        │   ├── namespace.yaml
        │   ├── serviceaccount.yaml
        │   └── scc-binding.yaml
        └── overlays/               # Environment-specific overlays
            ├── dev/                # Development environment
            │   └── kustomization.yaml
            └── prd/                # Production environment
                └── kustomization.yaml
```

## 🎯 Expected Results

After successful setup:
- ✅ Repository `koihler-apps` appears in ArgoCD UI
- ✅ Applications `data-analytics-prd` and `data-analytics-dev` are created
- ✅ Applications sync automatically with Git changes
- ✅ `data-analytics` namespace is created in OpenShift
- ✅ PVCs, secrets, and other resources are deployed
- ✅ Applications show "Healthy" and "Synced" status

## 🔗 Useful Links

- **ArgoCD UI**: `https://$(oc get route argocd-server -n openshift-gitops -o jsonpath='{.spec.host}')`
- **Repository**: https://github.com/rich-p-ai/koihler-apps.git
- **Documentation**: See `data-analytics-migration/DATA-ANALYTICS-MIGRATION-GUIDE.md`

---

**Setup completed!** Your repository is now integrated with ArgoCD for automated GitOps deployment. 🚀
