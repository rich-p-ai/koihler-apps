# 🚀 Corporate Apps Migration Guide

This guide walks through the complete process of migrating the `corporateapps` namespace from the PRD cluster to GitOps repository management with ArgoCD.

## 📋 Overview

The `corporateapps` namespace contains several critical business applications including:
- **java-phonelist-prd**: Java-based employee phone directory
- **wins0001173-prd** & **wins0001174-prd**: Windows-based applications
- **dv01b2bd-batch** & **er13gplu-batch**: Batch processing applications

## 🎯 Migration Objectives

1. **Extract** all resources from the existing PRD cluster
2. **Convert** to GitOps-compatible Kubernetes manifests
3. **Structure** using Kustomize for environment management
4. **Deploy** via ArgoCD for automated GitOps workflows
5. **Update** container images to use Quay registry

## 📁 Project Structure

```
corporateapps-migration/
├── README.md                           # Project documentation
├── CORPORATEAPPS-MIGRATION-GUIDE.md   # This detailed guide
├── migrate-corporateapps.sh            # Automated migration script
├── deploy-corporateapps-argocd.sh     # ArgoCD deployment script
├── backup/                             # Backup of original resources
│   ├── raw/                           # Raw exports from PRD cluster
│   └── cleaned/                       # Processed resources for deployment
└── gitops/                            # GitOps structure with Kustomize
    ├── base/                          # Base Kustomize configuration
    │   ├── kustomization.yaml         # Base kustomization
    │   ├── namespace.yaml             # Namespace definition
    │   ├── serviceaccount.yaml        # Service accounts and RBAC
    │   └── scc-binding.yaml           # Security context constraints
    ├── overlays/                      # Environment-specific overlays
    │   └── prd/                       # Production environment
    │       ├── kustomization.yaml     # Production configuration
    │       ├── configmaps.yaml        # Configuration maps
    │       ├── secrets.yaml           # Application secrets
    │       ├── services.yaml          # Kubernetes services
    │       ├── routes.yaml            # OpenShift routes
    │       ├── deployments.yaml       # Application deployments
    │       ├── pvcs.yaml              # Persistent volume claims
    │       └── [other resource files] # Additional resources as needed
    └── argocd-application.yaml        # ArgoCD application definition
```

## 🛠️ Prerequisites

### Required Tools
- **OpenShift CLI** (`oc`) - for cluster access and resource export
- **kubectl** - for Kubernetes operations
- **yq** - for YAML processing and manipulation
- **Git** - for version control

### Access Requirements
- **OCP-PRD Cluster Access**: Login credentials for the PRD cluster
- **GitHub Repository Access**: Push permissions to koihler-apps repository
- **ArgoCD Access**: Access to OpenShift GitOps on target cluster

### Install Required Tools

#### Install yq (if not already installed)
```bash
# On Linux
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# On macOS
brew install yq

# On Windows (using chocolatey)
choco install yq
```

## 🚀 Step-by-Step Migration Process

### Step 1: Prepare Migration Environment

```bash
# Navigate to the migration directory
cd koihler-apps/corporateapps-migration

# Verify all required tools are available
which oc kubectl yq git
```

### Step 2: Execute Migration Script

```bash
# Run the automated migration script
./migrate-corporateapps.sh
```

The script will perform the following actions:

1. **Login Verification**: Ensure you're logged into the correct PRD cluster
2. **Resource Export**: Extract all resources from the corporateapps namespace
3. **Resource Cleaning**: Remove cluster-specific metadata and fields
4. **Image Updates**: Update container image references to use Quay registry
5. **GitOps Structure**: Create Kustomize base and overlay configurations
6. **ArgoCD Setup**: Generate ArgoCD application manifest
7. **Documentation**: Create deployment scripts and documentation

### Step 3: Review Generated Files

After the migration script completes, review the generated structure:

```bash
# Check the overall structure
tree corporateapps-migration/

# Review the cleaned resources
ls -la backup/cleaned/

# Verify the GitOps structure
ls -la gitops/base/
ls -la gitops/overlays/prd/

# Test the Kustomize build
kubectl kustomize gitops/overlays/prd
```

### Step 4: Commit to Repository

```bash
# Add all generated files
git add .

# Commit the migration
git commit -m "feat: add corporateapps migration for GitOps deployment

- Extract all resources from PRD cluster corporateapps namespace  
- Create Kustomize base and production overlay structure
- Generate ArgoCD application for automated GitOps deployment
- Update container images to use Quay registry
- Add deployment scripts and comprehensive documentation"

# Push to repository
git push origin main
```

### Step 5: Deploy with ArgoCD

```bash
# Option 1: Use the deployment script
./deploy-corporateapps-argocd.sh

# Option 2: Manual deployment
oc login https://api.ocp-prd.kohlerco.com:6443
oc apply -f gitops/argocd-application.yaml
```

## 🔍 Verification and Testing

### Post-Deployment Verification

```bash
# Check ArgoCD application status
oc get application corporateapps-prd -n openshift-gitops

# Verify namespace and resources
oc get all -n corporateapps

# Check specific applications
oc get deployment -n corporateapps
oc get route -n corporateapps

# Review pod logs for any issues
oc logs -n corporateapps deployment/java-phonelist-prd
oc logs -n corporateapps deployment/wins0001173-prd
```

### Application Testing

1. **Access Applications**: Test each application URL from the routes
2. **Functionality Testing**: Verify core functionality of each application
3. **Performance Testing**: Compare performance with original deployment
4. **Data Integrity**: Verify any persistent data is accessible

### Monitoring ArgoCD Sync

```bash
# Watch ArgoCD sync status
oc get application corporateapps-prd -n openshift-gitops -w

# Check sync history
argocd app history corporateapps-prd

# View detailed application information
argocd app get corporateapps-prd
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Migration Script Fails
```bash
# Check cluster connectivity
oc whoami
oc get namespace corporateapps

# Verify tools are installed
which oc kubectl yq

# Check namespace exists
oc get namespace corporateapps
```

#### ArgoCD Sync Failures
```bash
# Check application status
oc describe application corporateapps-prd -n openshift-gitops

# View ArgoCD logs
oc logs -n openshift-gitops deployment/argocd-application-controller

# Test Kustomize build
kubectl kustomize gitops/overlays/prd | kubectl apply --dry-run=client -f -
```

#### Container Image Pull Errors
```bash
# Check image pull secrets
oc get secret -n corporateapps | grep pull

# Verify Quay registry access
oc describe pod <pod-name> -n corporateapps

# Check image references in deployments
oc get deployment -n corporateapps -o yaml | grep image:
```

#### Storage Issues
```bash
# Check PVC status
oc get pvc -n corporateapps

# Review storage classes
oc get storageclass

# Check pod events for storage errors
oc describe pod <pod-name> -n corporateapps
```

### Debug ArgoCD Application

```bash
# Force refresh the application
argocd app get corporateapps-prd --refresh

# Hard refresh (clear cache)
argocd app get corporateapps-prd --hard-refresh

# Manual sync
argocd app sync corporateapps-prd

# Sync with pruning
argocd app sync corporateapps-prd --prune
```

## 📊 Key Considerations

### Security
- **Service Accounts**: Maintain proper RBAC permissions
- **Secrets**: Review exported secrets for sensitive data
- **Security Context Constraints**: Ensure SCC permissions are appropriate
- **Network Policies**: Consider implementing network policies for isolation

### Performance
- **Resource Limits**: Review and adjust CPU/memory limits
- **Storage Performance**: Verify storage class performance characteristics
- **Load Balancing**: Ensure proper load balancing for multi-pod applications

### Data Management
- **Persistent Volumes**: Verify PV/PVC configurations
- **Backup Strategy**: Implement backup procedures for persistent data
- **Data Migration**: Plan for any required data migration

### Container Images
- **Registry Migration**: All images updated to use Quay registry
- **Tag Management**: Implement proper image tagging strategy
- **Security Scanning**: Ensure container images are scanned for vulnerabilities

## 🔄 Rollback Procedures

### ArgoCD Rollback
```bash
# View application history
argocd app history corporateapps-prd

# Rollback to previous version
argocd app rollback corporateapps-prd <revision-id>

# Or delete the application
oc delete application corporateapps-prd -n openshift-gitops
```

### Manual Rollback
```bash
# Remove all resources
kubectl delete -k gitops/overlays/prd

# Or remove just the namespace (will delete everything)
oc delete namespace corporateapps
```

## 📈 Post-Migration Tasks

### Immediate Tasks (Day 1)
- [ ] Verify all applications are running
- [ ] Test application functionality
- [ ] Update DNS/load balancer configurations
- [ ] Notify users of any changes

### Short-term Tasks (Week 1)
- [ ] Set up monitoring and alerting
- [ ] Configure backup procedures
- [ ] Update documentation
- [ ] Train team on GitOps workflows

### Long-term Tasks (Month 1)
- [ ] Implement CI/CD pipelines
- [ ] Set up automated security scanning
- [ ] Optimize resource utilization
- [ ] Plan for scaling and high availability

## 📚 Related Documentation

- [Main koihler-apps README](../README.md)
- [ArgoCD Setup Guide](../ARGOCD-SETUP-GUIDE.md)
- [Data Analytics Migration](../data-analytics-migration/README.md)
- [Procurement Apps Migration](../procurementapps-migration/README.md)

## 🆘 Support and Contacts

- **OpenShift Migration Team**: Primary support for migration issues
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Kustomize Documentation**: https://kustomize.io/
- **OpenShift GitOps**: https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html

---

**Created**: July 25, 2025  
**Last Updated**: July 25, 2025  
**Version**: 1.0  
**Status**: Ready for execution
