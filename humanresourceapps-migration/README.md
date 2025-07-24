# Human Resource Apps Migration to OCP-PRD with GitOps

This project contains the complete migration of the `humanresourceapps` namespace from OCP4 cluster to the new OCP-PRD cluster, with modern GitOps deployment using Kustomize and ArgoCD.

## 🎯 Project Overview

This migration focuses on transferring all Human Resource applications, jobs, and configurations from the legacy OCP4 environment to the new production cluster while implementing GitOps best practices.

## 📁 Project Structure

```
humanresourceapps-migration/
├── README.md                           # This file
├── migrate-humanresourceapps.sh        # Automated migration script
├── backup/                             # Backup of original resources
│   └── raw/                           # Raw exports from OCP4
│       ├── jobs.yaml                  # Kubernetes Jobs
│       ├── cronjobs.yaml              # CronJobs
│       ├── configmaps.yaml            # ConfigMaps
│       ├── secrets.yaml               # Secrets
│       ├── services.yaml              # Services
│       ├── routes.yaml                # Routes
│       └── ...                        # Other resources
├── cleaned/                           # Cleaned resources ready for deployment
│   └── [cleaned resource files]
├── gitops/                            # GitOps structure with Kustomize
│   ├── base/                          # Base Kustomize configuration
│   │   ├── kustomization.yaml         # Base kustomization
│   │   ├── namespace.yaml             # Namespace definition
│   │   ├── serviceaccount.yaml        # Service accounts and RBAC
│   │   ├── scc-binding.yaml           # Security context constraints
│   │   └── rbac.yaml                  # Role bindings
│   ├── overlays/                      # Environment-specific overlays
│   │   ├── dev/                       # Development environment
│   │   │   └── kustomization.yaml     # Dev-specific configuration
│   │   └── prd/                       # Production environment
│   │       ├── kustomization.yaml     # Prod-specific configuration
│   │       └── [resource files]       # Production resources
│   └── argocd-application.yaml        # ArgoCD application definition
└── deploy-to-ocp-prd.sh              # Deployment script
```

## 🚀 Quick Start

### Prerequisites
- Access to OCP4 cluster (for backup/export)
- Access to OCP-PRD cluster (for deployment)
- OpenShift CLI (`oc`)
- ArgoCD access on target cluster
- `yq` for YAML processing

### Step 1: Export and Prepare Resources

```bash
# Login to OCP4 cluster
oc login https://api.ocp4.kohlerco.com:6443

# Navigate to migration directory
cd "/c/work/OneDrive - Kohler Co/Openshift/git/koihler-apps/humanresourceapps-migration"

# Run migration script
./migrate-humanresourceapps.sh
```

### Step 2: Deploy to OCP-PRD with ArgoCD (Recommended)

```bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# Monitor deployment
oc get application humanresourceapps-prd -n openshift-gitops
```

### Alternative: Direct Kustomize Deployment

```bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy using Kustomize
kubectl apply -k gitops/overlays/prd
```

## 🔧 Key Features

### Jobs and Automation:
- ✅ **Kubernetes Jobs**: Full migration of batch processing jobs
- ✅ **CronJobs**: Scheduled job migration with proper timing
- ✅ **Job Dependencies**: Maintains job relationships and dependencies

### GitOps Ready:
- ✅ **Kustomize**: Structured overlay approach for different environments
- ✅ **ArgoCD**: Automated deployment and sync capabilities
- ✅ **Environment Isolation**: Separate dev and prd configurations
- ✅ **Resource Management**: Proper labeling and annotation strategy

### Security:
- ✅ **Service Account**: useroot with anyuid SCC permissions
- ✅ **Clean Secrets**: All sensitive data preserved
- ✅ **RBAC**: Group-based access control configured
- ✅ **User Access**: Jeyasri.Babuji@kohler.com with edit permissions

### Storage & Configuration:
- ✅ **PVC Migration**: Storage requirements maintained
- ✅ **ConfigMap Updates**: Environment-specific configurations
- ✅ **Secret Management**: Secure handling of sensitive data

## 🔍 Verification

### Check Deployment Status:
```bash
# Check all resources
oc get all -n humanresourceapps

# Check jobs specifically
oc get jobs,cronjobs -n humanresourceapps

# Check job execution
oc get pods -n humanresourceapps | grep job

# Check RBAC
oc get rolebinding -n humanresourceapps

# Check ArgoCD sync status
oc get application humanresourceapps-prd -n openshift-gitops
```

### Validate Jobs:
```bash
# List all jobs and their status
oc get jobs -n humanresourceapps -o wide

# Check CronJob schedules
oc get cronjobs -n humanresourceapps -o wide

# View job logs
oc logs -l job-name=<job-name> -n humanresourceapps
```

## 📊 Migration Summary

The migration script will generate a comprehensive summary including:
- Resource counts and types
- GitOps structure details
- Deployment options
- Verification commands
- Success criteria checklist

## 🚨 Important Notes

### Domain Updates:
- Routes updated from `.apps.ocp4.kohlerco.com` to `.apps.ocp-prd.kohlerco.com`
- DNS entries may need updating after deployment

### Storage Classes:
- PVCs updated to use `gp3-csi` storage class for OCP-PRD compatibility

### Job Scheduling:
- CronJob schedules preserved from source cluster
- Verify timezone settings match operational requirements

### RBAC:
- Group `humanresourceapps-admins` configured with admin role
- User `Jeyasri.Babuji@kohler.com` has edit permissions
- Additional users can be added via group membership

## 🛠️ Troubleshooting

### Common Issues:

#### Jobs Not Starting:
```bash
# Check job status
oc describe job <job-name> -n humanresourceapps

# Check pod status
oc get pods -l job-name=<job-name> -n humanresourceapps

# Check events
oc get events -n humanresourceapps --sort-by='.lastTimestamp'
```

#### CronJob Not Scheduling:
```bash
# Check CronJob status
oc describe cronjob <cronjob-name> -n humanresourceapps

# Check schedule format
oc get cronjob <cronjob-name> -n humanresourceapps -o yaml | grep schedule
```

#### Permission Issues:
```bash
# Check RBAC
oc auth can-i create jobs --as=system:serviceaccount:humanresourceapps:useroot -n humanresourceapps

# Check SCC assignment
oc get scc useroot-humanresourceapps -o yaml
```

## 🔄 Rollback

If rollback is needed:

```bash
# Using ArgoCD
oc delete application humanresourceapps-prd -n openshift-gitops

# Using Kustomize
kubectl delete -k gitops/overlays/prd

# Manual cleanup
oc delete namespace humanresourceapps
```

## 📈 Next Steps

1. **Monitor Job Execution**: Verify all jobs run as expected
2. **Performance Tuning**: Optimize job resource requests/limits
3. **Alerting Setup**: Configure monitoring for job failures
4. **Documentation**: Update operational procedures
5. **Team Training**: Brief team on new GitOps workflow

## 👥 Access Control

### Current Users:
- **Jeyasri.Babuji@kohler.com**: Edit permissions

### To Add More Users:
1. Edit `gitops/base/rbac.yaml`
2. Add users to the role binding
3. Apply changes: `kubectl apply -k gitops/overlays/prd`

## 🔗 Related Documentation

- [OpenShift Jobs Documentation](https://docs.openshift.com/container-platform/latest/nodes/jobs/nodes-pods-jobs.html)
- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

---

**Status**: 🚀 Ready for deployment  
**Team**: DevOps Migration Team  
**Last Updated**: $(date +"%B %d, %Y")
