# 🚀 HUMAN RESOURCE APPS MIGRATION GUIDE

## 📋 Overview

This guide provides comprehensive instructions for migrating the `humanresourceapps` namespace from the OCP4 cluster to the new OCP-PRD cluster. The migration includes all jobs, configurations, and supporting resources with a modern GitOps approach using Kustomize and ArgoCD.

## 🎯 Migration Objectives

- **Complete Resource Migration**: Transfer all jobs, CronJobs, and supporting resources
- **GitOps Implementation**: Modern deployment approach with Kustomize and ArgoCD
- **Environment Isolation**: Separate configurations for development and production
- **Security Enhancement**: Proper RBAC and security context configurations
- **Monitoring Integration**: Enable cluster monitoring and observability

## 📁 Migration Components

### Jobs and Batch Processing:
- Kubernetes Jobs
- CronJobs with proper scheduling
- Job dependencies and relationships
- Batch processing configurations

### Configuration Management:
- ConfigMaps for application settings
- Secrets for sensitive data
- Service accounts and RBAC
- Security context constraints

### Storage and Persistence:
- Persistent Volume Claims
- Storage class updates for target cluster
- Data persistence requirements

### Networking:
- Services for job communication
- Routes for external access (if applicable)
- Network policies

## 🔧 Prerequisites

### Required Access:
- **OCP4 Cluster**: For resource export and backup
- **OCP-PRD Cluster**: For deployment and testing
- **ArgoCD**: Access to GitOps deployment platform

### Required Tools:
- **OpenShift CLI (`oc`)**: Latest version
- **Kubernetes CLI (`kubectl`)**: For Kustomize operations
- **yq**: For YAML processing and manipulation
- **Git**: For repository management

### Permissions:
- **Source Cluster**: Read access to humanresourceapps namespace
- **Target Cluster**: Admin access for deployment
- **ArgoCD**: Application creation permissions

## 📦 Step 1: Export Resources from OCP4

### Login to Source Cluster:
```bash
oc login https://api.ocp4.kohlerco.com:6443
```

### Option A: Automated Export (Recommended)
```bash
cd "/c/work/OneDrive - Kohler Co/Openshift/git/koihler-apps/humanresourceapps-migration"
./migrate-humanresourceapps.sh
```

### Option B: Manual Export
If you need to export specific resources manually:

```bash
# Create backup directory
mkdir -p backup/raw

# Export Jobs
oc get jobs -n humanresourceapps -o yaml > backup/raw/jobs.yaml

# Export CronJobs
oc get cronjobs -n humanresourceapps -o yaml > backup/raw/cronjobs.yaml

# Export ConfigMaps
oc get configmaps -n humanresourceapps -o yaml > backup/raw/configmaps.yaml

# Export Secrets
oc get secrets -n humanresourceapps -o yaml > backup/raw/secrets.yaml

# Export Services
oc get services -n humanresourceapps -o yaml > backup/raw/services.yaml

# Export Routes
oc get routes -n humanresourceapps -o yaml > backup/raw/routes.yaml

# Export ServiceAccounts
oc get serviceaccounts -n humanresourceapps -o yaml > backup/raw/serviceaccounts.yaml

# Export PVCs
oc get pvc -n humanresourceapps -o yaml > backup/raw/pvcs.yaml
```

## 🧹 Step 2: Clean Resources for Target Cluster

The automated script handles this, but for manual processing:

```bash
# Remove cluster-specific metadata
for file in backup/raw/*.yaml; do
    yq eval 'del(.items[].metadata.resourceVersion, .items[].metadata.uid, .items[].metadata.selfLink, .items[].metadata.creationTimestamp, .items[].status)' "$file" > "cleaned/$(basename "$file" .yaml)-cleaned.yaml"
done

# Update domains for target cluster
sed -i 's/\.apps\.ocp4\.kohlerco\.com/.apps.ocp-prd.kohlerco.com/g' cleaned/routes-cleaned.yaml

# Update storage classes
sed -i 's/storageClassName: .*/storageClassName: gp3-csi/g' cleaned/pvcs-cleaned.yaml
```

## 🗂️ Step 3: GitOps Structure Creation

The migration creates a complete Kustomize structure:

```
gitops/
├── base/
│   ├── kustomization.yaml       # Base configuration
│   ├── namespace.yaml           # Namespace definition
│   ├── serviceaccount.yaml      # Service accounts
│   ├── scc-binding.yaml         # Security context constraints
│   └── rbac.yaml               # Role bindings
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml   # Development overlay
│   └── prd/
│       ├── kustomization.yaml   # Production overlay
│       ├── jobs-cleaned.yaml    # Kubernetes Jobs
│       ├── cronjobs-cleaned.yaml # CronJobs
│       ├── configmaps-cleaned.yaml # ConfigMaps
│       ├── secrets-cleaned.yaml   # Secrets
│       └── services-cleaned.yaml  # Services
└── argocd-application.yaml      # ArgoCD applications
```

## 🎯 Step 4: Deploy to OCP-PRD Cluster

### Login to Target Cluster:
```bash
oc login https://api.ocp-prd.kohlerco.com:6443
```

### Option A: GitOps with ArgoCD (Recommended)
```bash
# Deploy ArgoCD applications
kubectl apply -f gitops/argocd-application.yaml

# Monitor sync status
oc get application humanresourceapps-prd -n openshift-gitops

# Check sync progress
oc describe application humanresourceapps-prd -n openshift-gitops
```

### Option B: Kustomize Direct Deployment
```bash
# Production environment
kubectl apply -k gitops/overlays/prd

# Development environment (if needed)
kubectl apply -k gitops/overlays/dev
```

### Option C: Manual Deployment
```bash
# Run the generated deployment script
./deploy-to-ocp-prd.sh

# Follow prompts to select deployment method
```

## ✅ Step 5: Verification

### Basic Resource Check:
```bash
# Check namespace status
oc get namespace humanresourceapps

# Check all resources
oc get all -n humanresourceapps

# Check specific job resources
oc get jobs,cronjobs -n humanresourceapps -o wide
```

### Job Execution Verification:
```bash
# Check job history
oc get jobs -n humanresourceapps --sort-by='.metadata.creationTimestamp'

# Check CronJob schedules
oc get cronjobs -n humanresourceapps -o custom-columns=NAME:.metadata.name,SCHEDULE:.spec.schedule,SUSPEND:.spec.suspend,ACTIVE:.status.active,LAST-SCHEDULE:.status.lastScheduleTime

# View job logs
oc logs -l job-name=<job-name> -n humanresourceapps

# Check pod status for failed jobs
oc get pods -n humanresourceapps | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)"
```

### RBAC Verification:
```bash
# Check role bindings
oc get rolebindings -n humanresourceapps

# Verify user access
oc auth can-i create jobs --as=Jeyasri.Babuji@kohler.com -n humanresourceapps

# Check service account permissions
oc auth can-i create jobs --as=system:serviceaccount:humanresourceapps:useroot -n humanresourceapps
```

### ArgoCD Verification (if using GitOps):
```bash
# Check application status
oc get application humanresourceapps-prd -n openshift-gitops

# View sync details
oc describe application humanresourceapps-prd -n openshift-gitops

# Check for sync errors
oc get application humanresourceapps-prd -n openshift-gitops -o jsonpath='{.status.conditions}'
```

## 🔄 Step 6: Post-Migration Tasks

### Job Scheduling Validation:
1. **CronJob Testing**: Manually trigger a CronJob to test execution
2. **Schedule Verification**: Confirm schedules match business requirements
3. **Timezone Check**: Verify timezone settings for scheduled jobs

### Performance Monitoring:
1. **Resource Usage**: Monitor CPU and memory usage of jobs
2. **Execution Time**: Compare job execution times with source cluster
3. **Success Rate**: Monitor job completion rates

### Documentation Updates:
1. **Operational Procedures**: Update job monitoring procedures
2. **Contact Information**: Update escalation contacts
3. **Troubleshooting Guides**: Document common issues and solutions

## 🚨 Troubleshooting

### Common Issues and Solutions:

#### Job Fails to Start:
```bash
# Check job status
oc describe job <job-name> -n humanresourceapps

# Check pod events
oc get events -n humanresourceapps --field-selector reason=Failed

# Check image pull issues
oc describe pod <pod-name> -n humanresourceapps | grep -A 5 "Events:"
```

#### CronJob Not Scheduling:
```bash
# Verify CronJob configuration
oc get cronjob <cronjob-name> -n humanresourceapps -o yaml

# Check CronJob controller logs
oc logs -n openshift-kube-controller-manager -l app=kube-controller-manager | grep cronjob

# Manually trigger for testing
oc create job test-run --from=cronjob/<cronjob-name> -n humanresourceapps
```

#### Permission Denied Errors:
```bash
# Check SCC assignment
oc get pod <pod-name> -n humanresourceapps -o yaml | grep -A 5 "annotations:"

# Verify service account
oc get sa useroot -n humanresourceapps -o yaml

# Check role bindings
oc describe rolebinding -n humanresourceapps
```

#### Storage Issues:
```bash
# Check PVC status
oc get pvc -n humanresourceapps

# Describe storage issues
oc describe pvc <pvc-name> -n humanresourceapps

# Check storage class
oc get storageclass gp3-csi
```

### ArgoCD Sync Issues:
```bash
# Force sync
oc patch application humanresourceapps-prd -n openshift-gitops -p '{"operation":{"sync":{"revision":"HEAD"}}}' --type=merge

# Check sync status
oc get application humanresourceapps-prd -n openshift-gitops -o jsonpath='{.status.sync.status}'

# View detailed sync information
argocd app get humanresourceapps-prd --show-params
```

## 📊 Success Criteria

### Technical Validation:
- [ ] All jobs successfully imported to target cluster
- [ ] CronJobs are scheduling according to defined crons
- [ ] Job pods can successfully start and complete
- [ ] Required secrets and configmaps are accessible
- [ ] Storage volumes are properly mounted and accessible
- [ ] RBAC permissions function correctly

### Functional Validation:
- [ ] Job outputs match expected results
- [ ] Data processing jobs complete successfully
- [ ] External integrations work properly
- [ ] Log aggregation and monitoring function
- [ ] Backup and recovery processes work

### Performance Validation:
- [ ] Job execution times are within acceptable ranges
- [ ] Resource utilization is optimal
- [ ] No performance degradation observed
- [ ] Cluster resource consumption is reasonable

## 📁 File Structure

After migration completion, you'll have:

```
humanresourceapps-migration/
├── README.md                                    # This documentation
├── migrate-humanresourceapps.sh                 # Main migration script
├── quick-start.sh                              # Quick start guide
├── deploy-to-ocp-prd.sh                        # Deployment script
├── HUMANRESOURCEAPPS-MIGRATION-SUMMARY.md       # Generated summary
├── backup/                                     # Original resources
│   └── raw/                                   # Raw exports
├── cleaned/                                   # Cleaned resources
├── gitops/                                   # GitOps structure
│   ├── base/                                # Base Kustomize configs
│   ├── overlays/                            # Environment overlays
│   └── argocd-application.yaml              # ArgoCD application
```

## 🎉 Completion

### Migration Success Indicators:
✅ All resources successfully exported from source cluster  
✅ Resources cleaned and prepared for target cluster  
✅ GitOps structure created with proper configuration  
✅ Deployment completed without errors  
✅ All jobs are running and completing successfully  
✅ RBAC and security configurations are working  
✅ Monitoring and logging are functional  

### Handover Checklist:
- [ ] Team briefed on new GitOps workflow
- [ ] Documentation updated and accessible
- [ ] Monitoring alerts configured
- [ ] Backup procedures validated
- [ ] Emergency contacts updated
- [ ] Post-migration support arranged

## 🚀 Key Benefits of This Migration Approach

### GitOps Benefits:
- **Declarative Configuration**: All infrastructure as code
- **Version Control**: Full audit trail of changes
- **Automated Deployment**: Consistent, repeatable deployments
- **Rollback Capability**: Easy rollback to previous versions

### Operational Benefits:
- **Reduced Manual Effort**: Automated deployment processes
- **Improved Reliability**: Consistent environment configurations
- **Better Monitoring**: Integrated with cluster monitoring
- **Enhanced Security**: Proper RBAC and security contexts

### Development Benefits:
- **Environment Parity**: Consistent dev/prod configurations
- **Easy Testing**: Simple environment provisioning
- **Faster Deployment**: Streamlined deployment pipeline
- **Better Collaboration**: Shared configuration management

---

**Migration Prepared By**: DevOps Migration Team  
**Date**: $(date +"%B %d, %Y")  
**Status**: ✅ Ready for Execution  
**Support**: migration-support@kohler.com
