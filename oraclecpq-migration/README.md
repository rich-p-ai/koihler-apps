# OracleCPQ Migration from OCP4 to OCP-PRD with GitOps

## 🎯 Project Overview

This project contains the complete migration of the `oraclecpq` namespace from the OCP4 cluster to OCP-PRD cluster using GitOps repository management for automated deployment with Kustomize and ArgoCD.

- **Source**: OCP4 cluster (`api.ocp4.kohlerco.com`)
- **Target**: OCP-PRD cluster (`api.ocp-prd.kohlerco.com`)
- **Namespace**: `oraclecpq`
- **Method**: GitOps with Kustomize overlays
- **Orchestration**: ArgoCD applications

## 📁 Project Structure

```
oraclecpq-migration/
├── README.md                          # This file
├── migrate-oraclecpq.sh              # Automated migration script
├── deploy-to-ocp-prd.sh              # Deployment script
├── ORACLECPQ-INVENTORY.md            # Detailed resource inventory
├── backup/                            # Backup of original resources
│   ├── raw/                          # Raw exports from OCP4 cluster
│   └── cleaned/                      # Cleaned resources ready for OCP-PRD
└── gitops/                           # GitOps structure with Kustomize
    ├── base/                         # Base Kustomize configuration
    │   ├── kustomization.yaml        # Base kustomization
    │   ├── namespace.yaml            # Namespace definition
    │   ├── serviceaccount.yaml       # Service accounts and RBAC
    │   └── scc-binding.yaml          # Security context constraints
    ├── overlays/                     # Environment-specific overlays
    │   └── prd/                      # Production environment (OCP-PRD)
    │       ├── kustomization.yaml    # Production configuration
    │       └── [exported resources]  # All migrated application resources
    └── argocd-application.yaml       # ArgoCD application definition
```

## 🚀 Quick Start

### Prerequisites
- Access to OCP4 cluster (for backup/export)
- Access to OCP-PRD cluster (for deployment)
- OpenShift CLI (`oc`)
- ArgoCD access on target cluster
- `yq` for YAML processing (optional but recommended)

### Step 1: Run Migration Script

```bash
# Login to OCP4 cluster
oc login https://api.ocp4.kohlerco.com:6443

# Navigate to migration directory
cd "/c/work/OneDrive - Kohler Co/Openshift/git/koihler-apps/oraclecpq-migration"

# Run migration script
./migrate-oraclecpq.sh
```

### Step 2: Review Generated Files

After the script completes, review:

```bash
# Check the inventory report
cat ORACLECPQ-INVENTORY.md

# Review GitOps structure
tree gitops/

# Test Kustomize build
kubectl kustomize gitops/overlays/prd
```

### Step 3: Deploy to OCP-PRD

#### Option A: Using ArgoCD (Recommended)

```bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# Monitor deployment
oc get application oraclecpq-prd -n openshift-gitops -w
```

#### Option B: Direct Kustomize Deployment

```bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy using Kustomize
kubectl apply -k gitops/overlays/prd
```

#### Option C: Automated Script

```bash
./deploy-to-ocp-prd.sh
```

## 🔧 Key Features

### Migration Benefits
- **Cross-Cluster Migration**: OCP4 → OCP-PRD with GitOps structure
- **Registry Updates**: Automatic image registry reference updates
- **Resource Cleaning**: Removes cluster-specific metadata
- **Security**: Maintains service accounts with appropriate SCC permissions
- **Automation**: ArgoCD integration for continuous deployment
- **Infrastructure as Code**: All resources defined in Git

### Oracle CPQ-Specific Features
- **Database Integration**: Preserves Oracle database configurations
- **Product Configuration**: Maintains Oracle CPQ product configurations
- **API Integration**: Preserves external API configurations
- **Data Persistence**: Handles persistent volume migrations

### Security and RBAC
- **Service Accounts**: `oraclecpq-sa` and `useroot` with appropriate permissions
- **SCC Bindings**: `anyuid` access where required
- **Clean Secrets**: All sensitive data preserved and properly secured
- **Group Access**: `oraclecpq-admin` group with admin permissions

## 🔍 Verification and Testing

### Post-Migration Verification

```bash
# Check namespace and all resources
oc get all -n oraclecpq

# Check deployments and their status
oc get deployment -n oraclecpq
oc describe deployment/<app-name> -n oraclecpq

# Check routes and connectivity
oc get route -n oraclecpq
curl -k https://<route-hostname>/health

# Check persistent volumes
oc get pvc -n oraclecpq

# Check ArgoCD sync status
oc get application oraclecpq-prd -n openshift-gitops
oc describe application oraclecpq-prd -n openshift-gitops
```

### Application-Specific Testing

```bash
# Check application logs
oc logs -n oraclecpq deployment/<oracle-cpq-app>

# Test Oracle CPQ endpoints
curl -k https://<route>/api/health
curl -k https://<route>/api/status

# Check database connectivity
oc exec -n oraclecpq deployment/<app> -- curl -k <database-endpoint>
```

## 📊 Migration Summary

See `ORACLECPQ-INVENTORY.md` for detailed resource inventory and migration analysis.

## 🚨 Important Migration Notes

### Container Images
- **Registry Migration**: All images updated from OCP4 internal registry to Quay registry
- **Image Pull Secrets**: Verify pull secrets are available on OCP-PRD
- **Version Compatibility**: Ensure Oracle CPQ versions are supported

### Application Configuration
- **Environment Variables**: Review and update cluster-specific configurations
- **Database Connections**: Update connection strings for OCP-PRD environment
- **External APIs**: Verify connectivity to external services from OCP-PRD
- **Oracle Integration**: Validate Oracle product configuration connectivity

### Storage and Persistence
- **Storage Classes**: Updated to use `gp3-csi` for OCP-PRD compatibility
- **NFS Migration**: Plan separate data migration for NFS persistent volumes
- **Data Migration**: Plan data migration strategy for persistent volumes
- **Backup Strategy**: Implement backup procedures for new environment

### Networking
- **Routes**: Update route hostnames to avoid conflicts
- **NodePorts**: Configure NodePort services (32029, 32030, 32031, 32074, 32075, 32076)
- **Load Balancers**: Configure external load balancer rules
- **DNS Updates**: Update DNS records to point to OCP-PRD
- **Firewall Rules**: Ensure network connectivity between clusters during migration

## 🛠️ Troubleshooting

### ArgoCD Sync Issues
```bash
# Check application status
oc describe application oraclecpq-prd -n openshift-gitops

# View ArgoCD controller logs
oc logs -n openshift-gitops deployment/argocd-application-controller

# Manual sync
argocd app sync oraclecpq-prd
```

### Resource Conflicts
```bash
# Check for existing resources
oc get all -n oraclecpq

# Check events for errors
oc get events -n oraclecpq --sort-by='.lastTimestamp'

# Check resource quotas
oc describe quota -n oraclecpq
```

### Application Issues
```bash
# Check pod status
oc get pods -n oraclecpq

# Check application logs
oc logs -n oraclecpq deployment/<app-name>

# Check service endpoints
oc get endpoints -n oraclecpq
```

## 🔄 Rollback Strategy

### Via ArgoCD
```bash
# View application history
argocd app history oraclecpq-prd

# Rollback to previous version
argocd app rollback oraclecpq-prd <revision>

# Or delete application to stop sync
oc delete application oraclecpq-prd -n openshift-gitops
```

### Manual Rollback
```bash
# Delete resources
kubectl delete -k gitops/overlays/prd

# Redeploy to original cluster if needed
oc login https://api.ocp4.kohlerco.com:6443
# [restore from backup]
```

## 📈 Post-Migration Tasks

### Immediate Tasks
1. **Verify Application Functionality**: Test all Oracle CPQ features
2. **Update DNS Records**: Point domains to OCP-PRD routes
3. **Configure NodePorts**: Set up HAProxy NodePort configuration
4. **Configure Monitoring**: Set up monitoring and alerting for new environment
5. **Update Documentation**: Update operational runbooks

### Ongoing Tasks
1. **Performance Monitoring**: Monitor application performance in new environment
2. **Backup Configuration**: Set up automated backup procedures
3. **Security Hardening**: Review and enhance security configurations
4. **Capacity Planning**: Monitor resource usage and plan for scaling

### Team Communication
1. **Stakeholder Notification**: Inform teams of migration completion
2. **Training**: Provide training on new environment access and procedures
3. **Support Documentation**: Update support procedures and contact information

## 🔗 Additional Resources

- **ArgoCD UI**: `https://openshift-gitops-server-openshift-gitops.apps.ocp-prd.kohlerco.com`
- **OCP-PRD Console**: `https://console-openshift-console.apps.ocp-prd.kohlerco.com`
- **Oracle CPQ Documentation**: Internal Oracle CPQ documentation
- **OpenShift GitOps Documentation**: `https://docs.openshift.com/container-platform/4.15/cicd/gitops/understanding-openshift-gitops.html`
