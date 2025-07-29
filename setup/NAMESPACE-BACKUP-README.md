# Kubernetes Namespace Backup with GitOps and ArgoCD

This repository contains comprehensive scripts for backing up Kubernetes namespaces to GitHub using GitOps methodology with ArgoCD. The system provides automated daily backups, version control of configuration changes, and disaster recovery capabilities.

## 🎯 Overview

The backup system consists of two main scripts:

1. **`backup-namespace-setup.sh`** - Initial setup script that creates the GitHub repository structure and ArgoCD configuration
2. **`daily-namespace-backup.sh`** - Daily backup script that captures changes and updates GitHub

### Key Features

- ✅ **Automated Daily Backups** - Captures all namespace resources daily
- ✅ **GitOps Deployment** - Uses ArgoCD for infrastructure as code
- ✅ **Change Detection** - Only commits when actual changes are detected
- ✅ **Resource Cleaning** - Removes cluster-specific metadata for portability
- ✅ **Disaster Recovery** - Complete namespace restoration capabilities
- ✅ **Monitoring** - Comprehensive logging and status reporting
- ✅ **Kustomize Integration** - Organized overlay structure for different environments

## 📋 Prerequisites

Before using these scripts, ensure you have:

- OpenShift CLI (`oc`) installed and configured
- `kubectl` installed
- `git` installed and configured
- Access to the source OpenShift cluster
- ArgoCD installed in the target cluster
- GitHub repository with write access
- Optional: `yq` for advanced YAML processing

## 🚀 Quick Start

### Step 1: Initial Setup

Run the setup script to create the initial backup structure:

```bash
# Make the script executable
chmod +x backup-namespace-setup.sh

# Run the setup (will prompt for configuration)
./backup-namespace-setup.sh
```

The setup script will prompt you for:
- Source namespace to backup
- GitHub repository URL
- Repository name

### Step 2: Configure Daily Backups

Set up automated daily backups:

```bash
# Navigate to the scripts directory (created by setup)
cd scripts

# Setup cron job for daily execution at 2 AM
./setup-cron.sh
```

### Step 3: Deploy ArgoCD Application

Deploy the ArgoCD application to enable GitOps:

```bash
# Login to target cluster
oc login https://your-cluster-url

# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# Monitor deployment
oc get application [namespace]-backup -n openshift-gitops -w
```

## 📁 Repository Structure

After running the setup script, your repository will have this structure:

```
├── backup/                    # Backup artifacts
│   ├── raw/                   # Raw exported resources
│   ├── cleaned/               # Cleaned resources ready for deployment
│   └── daily/                 # Daily backup snapshots
│       └── YYYYMMDD-HHMMSS/   # Timestamped backup directories
├── gitops/                    # GitOps manifests
│   ├── base/                  # Base Kustomize resources
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml
│   │   ├── scc-binding.yaml
│   │   └── kustomization.yaml
│   ├── overlays/              # Environment overlays
│   │   └── prd/               # Production overlay
│   │       ├── kustomization.yaml
│   │       ├── configmaps.yaml
│   │       ├── secrets.yaml
│   │       ├── services.yaml
│   │       ├── deployments.yaml
│   │       └── [other resource files]
│   └── argocd-application.yaml
├── scripts/                   # Automation scripts
│   ├── daily-backup.sh        # Daily backup script
│   └── setup-cron.sh          # Cron job setup
├── backup-namespace-setup.sh  # Initial setup script
├── daily-namespace-backup.sh  # Standalone daily backup script
└── README.md                  # This file
```

## 🔧 Configuration

### Environment Variables

You can configure the scripts using environment variables:

```bash
export SOURCE_CLUSTER="https://api.ocp-prd.kohlerco.com:6443"
export SOURCE_NAMESPACE="your-namespace"
export GITHUB_REPO_URL="https://github.com/user/repo.git"
export ARGOCD_NAMESPACE="openshift-gitops"
```

### Script Configuration

Alternatively, modify the configuration section in each script:

```bash
# In backup-namespace-setup.sh and daily-namespace-backup.sh
SOURCE_CLUSTER="https://your-cluster-url"
SOURCE_NAMESPACE="your-namespace"
GITHUB_REPO_URL="https://github.com/user/repo.git"
ARGOCD_NAMESPACE="openshift-gitops"
```

## 📊 Monitoring and Verification

### Check Backup Status

```bash
# View latest backup summary
ls -la backup/daily/
cat backup/daily/latest/backup-summary.md

# Check cron job status
crontab -l

# View backup logs
tail -f /var/log/[namespace]-backup.log
```

### ArgoCD Monitoring

```bash
# Check application status
oc get application [namespace]-backup -n openshift-gitops

# View detailed status
oc describe application [namespace]-backup -n openshift-gitops

# Check ArgoCD sync logs
oc logs -n openshift-gitops deployment/argocd-application-controller | grep [namespace]
```

### Target Namespace Verification

```bash
# Check all resources in target namespace
oc get all -n [namespace]

# Check specific resource types
oc get pvc,secrets,configmaps -n [namespace]

# Monitor events
oc get events -n [namespace] --sort-by='.lastTimestamp'
```

## 🚨 Disaster Recovery

### Complete Namespace Restoration

In case of complete namespace loss, restore using any of these methods:

#### Method 1: ArgoCD Deployment (Recommended)
```bash
# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# ArgoCD will automatically sync and restore all resources
oc get application [namespace]-backup -n openshift-gitops -w
```

#### Method 2: Kustomize Deployment
```bash
# Deploy using Kustomize
kubectl apply -k gitops/overlays/prd

# Verify deployment
oc get all -n [namespace]
```

#### Method 3: Raw Resource Deployment
```bash
# Deploy from a specific backup snapshot
kubectl apply -f backup/daily/YYYYMMDD-HHMMSS/cleaned/

# Or deploy from cleaned backup
kubectl apply -f backup/cleaned/
```

### Partial Recovery

For recovering specific resources:

```bash
# Restore specific resource type
oc apply -f gitops/overlays/prd/configmaps.yaml

# Restore from specific backup
oc apply -f backup/daily/YYYYMMDD-HHMMSS/cleaned/secrets-all.yaml
```

## 🔄 Workflow

### Daily Backup Workflow

1. **Login** to source cluster
2. **Export** all resources from source namespace
3. **Clean** resources by removing cluster-specific metadata
4. **Compare** with existing GitOps manifests
5. **Update** GitOps structure if changes detected
6. **Commit** and push changes to GitHub
7. **Generate** backup summary and logs
8. **Verify** GitOps structure integrity

### ArgoCD Sync Workflow

1. **Monitor** GitHub repository for changes
2. **Detect** changes in GitOps manifests
3. **Sync** changes to target cluster
4. **Apply** resources to target namespace
5. **Self-heal** any drift from desired state
6. **Report** sync status and health

## 🛠️ Troubleshooting

### Common Issues

#### Backup Script Issues

```bash
# Check script permissions
ls -la backup-namespace-setup.sh daily-namespace-backup.sh

# Make scripts executable
chmod +x *.sh

# Check configuration
echo $SOURCE_NAMESPACE $GITHUB_REPO_URL
```

#### Authentication Issues

```bash
# Check cluster login
oc whoami
oc get namespace [namespace]

# Check GitHub access
git remote -v
git push --dry-run
```

#### ArgoCD Sync Issues

```bash
# Check application status
oc describe application [namespace]-backup -n openshift-gitops

# Check ArgoCD logs
oc logs -n openshift-gitops deployment/argocd-application-controller

# Force refresh
oc patch application [namespace]-backup -n openshift-gitops -p '{"operation":{"sync":{}}}' --type merge
```

#### Kustomize Build Issues

```bash
# Test Kustomize build
kubectl kustomize gitops/overlays/prd

# Check YAML syntax
yq eval . gitops/overlays/prd/*.yaml
```

### Log Files

- **Backup Logs**: `/var/log/[namespace]-backup.log`
- **Cron Logs**: `/var/log/cron`
- **ArgoCD Logs**: `oc logs -n openshift-gitops deployment/argocd-application-controller`

### Debugging Commands

```bash
# Test daily backup manually
./daily-namespace-backup.sh

# Check git status
git status
git log --oneline -10

# Verify cluster resources
oc get all -n [namespace]
oc describe namespace [namespace]
```

## 📚 Resource Types Backed Up

The scripts automatically backup the following Kubernetes resource types:

- **Core Resources**: ConfigMaps, Secrets, Services, ServiceAccounts
- **Workloads**: Deployments, DeploymentConfigs, DaemonSets, StatefulSets, ReplicaSets
- **Storage**: PersistentVolumeClaims
- **Networking**: Routes, Ingresses, NetworkPolicies
- **Jobs**: Jobs, CronJobs
- **OpenShift**: ImageStreams, BuildConfigs
- **RBAC**: Roles, RoleBindings
- **Policies**: ResourceQuotas, LimitRanges, HorizontalPodAutoscalers
- **Runtime**: Pods (for reference, not deployment)

## 🔐 Security Considerations

- **Secrets**: Backed up but cleaned of sensitive cluster-specific data
- **ServiceAccounts**: Recreated with appropriate permissions
- **RBAC**: Role bindings preserved for namespace-scoped access
- **Security Context Constraints**: Configured for proper pod security
- **Network Policies**: Preserved to maintain security boundaries

## 🚀 Advanced Usage

### Custom Resource Types

To backup additional resource types, modify the `resource_types` array in the daily backup script:

```bash
resource_types+=(
    "customresource1"
    "customresource2"
)
```

### Multiple Environments

Create additional overlays for different environments:

```bash
mkdir -p gitops/overlays/dev
mkdir -p gitops/overlays/staging

# Copy and modify kustomization.yaml for each environment
```

### Custom Cleaning Rules

Modify the `yq` cleaning rules in the scripts to handle specific resource types:

```bash
# Add custom cleaning rules
yq eval 'del(.spec.customField)' file.yaml
```

## 📈 Best Practices

1. **Regular Testing**: Periodically test disaster recovery procedures
2. **Monitoring**: Set up alerts for backup failures and ArgoCD sync issues
3. **Documentation**: Keep this README updated with environment-specific details
4. **Security**: Review and rotate credentials regularly
5. **Cleanup**: Periodically clean old backup snapshots to save space
6. **Validation**: Regularly validate Kustomize builds and ArgoCD configurations

## 🤝 Contributing

To improve these scripts:

1. Test changes in a development environment
2. Update documentation for any new features
3. Ensure backward compatibility
4. Add appropriate error handling
5. Update the troubleshooting section

## 📞 Support

For issues or questions:

1. Check the troubleshooting section above
2. Review ArgoCD application status and logs
3. Verify cluster connectivity and permissions
4. Check GitHub repository for recent changes
5. Review backup logs for error messages

---

**Created**: July 29, 2025  
**Version**: 1.0  
**Backup System**: GitOps with ArgoCD  
**Update Frequency**: Daily automated backups
