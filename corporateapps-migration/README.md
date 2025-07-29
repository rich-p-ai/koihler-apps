# Corporate Apps Migration to GitOps Repository

This directory contains the complete migration setup for extracting the `corporateapps` namespace from the PRD cluster and preparing it for GitOps management with ArgoCD.

## 🎯 Project Overview

- **Source**: OCP-PRD cluster (`api.ocp-prd.kohlerco.com`)
- **Namespace**: `corporateapps`
- **Method**: GitOps with Kustomize overlays
- **Orchestration**: ArgoCD applications
- **Target Registry**: Quay (`kohler-registry-quay-quay.apps.ocp-host.kohlerco.com`)

## 🚀 Quick Start

### Prerequisites
- Access to OCP-PRD cluster where corporateapps is currently running
- OpenShift CLI (`oc`) installed and configured
- `yq` tool installed for YAML processing
- Access to push to the koihler-apps GitHub repository

### Step 1: Run Migration Script

```bash
cd corporateapps-migration
./migrate-corporateapps.sh
```

The script will:
1. Login to the PRD cluster
2. Export all resources from the `corporateapps` namespace
3. Clean and prepare resources for GitOps
4. Create Kustomize base and overlay structure
5. Generate ArgoCD application manifest
6. Create deployment scripts and documentation

### Step 2: Review Generated Files

After running the script, review the generated structure:

```
corporateapps-migration/
├── backup/
│   ├── raw/           # Original exported resources from cluster
│   └── cleaned/       # Processed resources ready for deployment
├── gitops/
│   ├── base/          # Base Kustomize configuration
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml
│   │   └── scc-binding.yaml
│   └── overlays/
│       └── prd/       # Production overlay with all resources
│           ├── kustomization.yaml
│           ├── configmaps.yaml
│           ├── secrets.yaml
│           ├── services.yaml
│           ├── routes.yaml
│           ├── deployments.yaml
│           └── [other resource files]
└── argocd-application.yaml
```

### Step 3: Commit to Repository

```bash
git add .
git commit -m "feat: add corporateapps migration for GitOps"
git push origin main
```

### Step 4: Deploy with ArgoCD

```bash
# Login to target cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# Monitor deployment
oc get application corporateapps-prd -n openshift-gitops -w
```

## 🔧 Applications Included

Based on the image registry data, corporateapps includes:

- **java-phonelist-prd**: Java-based phone list application
- **wins0001173-prd**: Windows-based application
- **wins0001174-prd**: Windows-based application
- **dv01b2bd-batch**: Batch processing application (latest and test versions)
- **er13gplu-batch**: Batch processing application (latest and test versions)

## 🔍 Verification

After deployment, verify the migration:

```bash
# Check namespace and resources
oc get all -n corporateapps

# Check specific deployments
oc get deployment -n corporateapps

# Check routes and services
oc get route,service -n corporateapps

# Check ArgoCD sync status
oc get application corporateapps-prd -n openshift-gitops

# Check application logs
oc logs -n openshift-gitops deployment/argocd-application-controller | grep corporateapps
```

## 🚨 Important Notes

### Container Images
- All container images will be updated from internal registry to Quay registry
- Original: `image-registry.openshift-image-registry.svc:5000/corporateapps/*`
- Updated: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/corporateapps/*`

### Security Considerations
- Service accounts and RBAC permissions will be preserved
- SecurityContextConstraints (SCC) will be maintained for proper permissions
- Secrets will be exported but may need manual review for sensitive data

### DeploymentConfig Conversion
- If any DeploymentConfigs exist, they will be converted to standard Kubernetes Deployments
- Manual review recommended for complex deployment strategies

## 🛠️ Troubleshooting

### Migration Script Issues
```bash
# Check cluster connectivity
oc whoami
oc get namespace corporateapps

# Verify required tools
which oc kubectl yq
```

### ArgoCD Sync Issues
```bash
# Check application status
oc describe application corporateapps-prd -n openshift-gitops

# View ArgoCD logs
oc logs -n openshift-gitops deployment/argocd-application-controller

# Test Kustomize build locally
kubectl kustomize gitops/overlays/prd
```

### Resource Conflicts
```bash
# Check for existing resources
oc get all -n corporateapps

# Check events for errors
oc get events -n corporateapps --sort-by='.lastTimestamp'
```

## 📋 Migration Checklist

- [ ] Run migration script successfully
- [ ] Review generated GitOps structure
- [ ] Verify all applications are included
- [ ] Check image registry references are updated
- [ ] Test Kustomize build locally
- [ ] Commit changes to Git repository
- [ ] Deploy ArgoCD application
- [ ] Verify all pods are running
- [ ] Test application functionality
- [ ] Update documentation

## 🔗 Related Documentation

- [ArgoCD Setup Guide](../ARGOCD-SETUP-GUIDE.md)
- [koihler-apps Repository README](../README.md)
- [Data Analytics Migration](../data-analytics-migration/README.md)
- [Procurement Apps Migration](../procurementapps-migration/README.md)

## 💡 Next Steps

1. **Monitoring**: Set up monitoring and alerting for corporate applications
2. **Backup**: Configure backup strategies for persistent data
3. **CI/CD**: Integrate with CI/CD pipelines for automated updates
4. **Security**: Review and harden security policies
5. **Documentation**: Update internal documentation with new GitOps processes

---

**Created**: July 25, 2025  
**Status**: Ready for execution  
**Contact**: OpenShift Migration Team
