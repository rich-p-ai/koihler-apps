# Mulesoft Apps Migration from OCPAZ to OCP-PRD with GitOps

This project contains the complete migration of the `mulesoftapps-prod` namespace from the OCPAZ cluster to OCP-PRD cluster using GitOps repository management for automated deployment with Kustomize and ArgoCD.

## 🎯 Project Overview

- **Source**: OCPAZ cluster (`api.ocpaz.kohlerco.com`)
- **Target**: OCP-PRD cluster (`api.ocp-prd.kohlerco.com`)
- **Namespace**: `mulesoftapps-prod`
- **Method**: GitOps with Kustomize overlays
- **Orchestration**: ArgoCD applications

## 📁 Project Structure

```
mulesoftapps-migration/
├── README.md                           # This file
├── migrate-mulesoftapps.sh            # Automated migration script
├── deploy-to-ocp-prd.sh               # Deployment script
├── MULESOFTAPPS-INVENTORY.md          # Detailed resource inventory
├── backup/                             # Backup of original resources
│   ├── raw/                           # Raw exports from OCPAZ cluster
│   └── cleaned/                       # Cleaned resources ready for OCP-PRD
└── gitops/                            # GitOps structure with Kustomize
    ├── base/                          # Base Kustomize configuration
    │   ├── kustomization.yaml         # Base kustomization
    │   ├── namespace.yaml             # Namespace definition
    │   ├── serviceaccount.yaml        # Service accounts and RBAC
    │   └── scc-binding.yaml           # Security context constraints
    ├── overlays/                      # Environment-specific overlays
    │   └── prd/                       # Production environment (OCP-PRD)
    │       ├── kustomization.yaml     # Production configuration
    │       ├── deployments.yaml       # Application deployments
    │       ├── services.yaml          # Application services
    │       ├── routes.yaml            # HTTP routes
    │       ├── configmaps.yaml        # Configuration
    │       ├── secrets.yaml           # Application secrets
    │       └── [other resources]      # Additional migrated resources
    └── argocd-application.yaml        # ArgoCD application definition
```

## 🚀 Quick Start

### Prerequisites
- Access to both OCPAZ and OCP-PRD clusters
- OpenShift CLI (`oc`)
- ArgoCD access on OCP-PRD cluster
- `yq` tool for YAML processing (recommended)

### Step 1: Run Migration Script

```bash
# Make script executable
chmod +x migrate-mulesoftapps.sh

# Run migration (will prompt for OCPAZ cluster login)
./migrate-mulesoftapps.sh
```

### Step 2: Review Generated Files

```bash
# Review the inventory
cat MULESOFTAPPS-INVENTORY.md

# Check GitOps structure
tree gitops/

# Validate Kustomize build
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
oc get application mulesoftapps-prd -n openshift-gitops -w
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
- **Cross-Cluster Migration**: OCPAZ → OCP-PRD with GitOps structure
- **Registry Updates**: Automatic image registry reference updates
- **Resource Cleaning**: Removes cluster-specific metadata
- **Security**: Maintains service accounts with appropriate SCC permissions
- **Automation**: ArgoCD integration for continuous deployment
- **Infrastructure as Code**: All resources defined in Git

### Mulesoft-Specific Features
- **Runtime Compatibility**: Preserves Mulesoft runtime configurations
- **Anypoint Integration**: Maintains Anypoint Platform connectivity settings
- **API Management**: Preserves API gateway and management configurations
- **Data Persistence**: Handles persistent volume migrations

### Security and RBAC
- **Service Accounts**: `mulesoftapps-sa` and `useroot` with appropriate permissions
- **SCC Bindings**: `anyuid` and `privileged` access where required
- **Clean Secrets**: All sensitive data preserved and properly secured
- **Network Policies**: Maintained for secure inter-service communication

## 🔍 Verification and Testing

### Post-Migration Verification

```bash
# Check namespace and all resources
oc get all -n mulesoftapps-prod

# Check deployments and their status
oc get deployment -n mulesoftapps-prod
oc describe deployment/<app-name> -n mulesoftapps-prod

# Check routes and connectivity
oc get route -n mulesoftapps-prod
curl -k https://<route-hostname>/health

# Check persistent volumes
oc get pvc -n mulesoftapps-prod

# Check ArgoCD sync status
oc get application mulesoftapps-prd -n openshift-gitops
oc describe application mulesoftapps-prd -n openshift-gitops
```

### Application-Specific Testing

```bash
# Check application logs
oc logs -n mulesoftapps-prod deployment/<mulesoft-app>

# Test API endpoints
curl -k https://<route>/api/health
curl -k https://<route>/api/status

# Check Anypoint Platform connectivity
oc exec -n mulesoftapps-prod deployment/<app> -- curl -k https://anypoint.mulesoft.com
```

## 📊 Migration Summary

See `MULESOFTAPPS-INVENTORY.md` for detailed resource inventory and migration analysis.

## 🚨 Important Migration Notes

### Container Images
- **Registry Migration**: All images updated from OCPAZ internal registry to Quay registry
- **Image Pull Secrets**: Verify pull secrets are available on OCP-PRD
- **Version Compatibility**: Ensure Mulesoft runtime versions are supported

### Application Configuration
- **Environment Variables**: Review and update cluster-specific configurations
- **Database Connections**: Update connection strings for OCP-PRD environment
- **External APIs**: Verify connectivity to external services from OCP-PRD
- **Anypoint Platform**: Validate Anypoint Platform connectivity and authentication

### Storage and Persistence
- **Storage Classes**: Verify OCP-PRD storage classes match requirements
- **Data Migration**: Plan separate data migration for persistent volumes
- **Backup Strategy**: Implement backup procedures for new environment

### Networking
- **Routes**: Update route hostnames to avoid conflicts
- **Load Balancers**: Configure external load balancer rules
- **DNS Updates**: Update DNS records to point to OCP-PRD
- **Firewall Rules**: Ensure network connectivity between clusters during migration

## 🛠️ Troubleshooting

### ArgoCD Sync Issues
```bash
# Check application status
oc describe application mulesoftapps-prd -n openshift-gitops

# View ArgoCD controller logs
oc logs -n openshift-gitops deployment/argocd-application-controller

# Manual sync
argocd app sync mulesoftapps-prd
```

### Resource Conflicts
```bash
# Check for existing resources
oc get all -n mulesoftapps-prod

# Check events for errors
oc get events -n mulesoftapps-prod --sort-by='.lastTimestamp'

# Check resource quotas
oc describe quota -n mulesoftapps-prod
```

### Application Issues
```bash
# Check pod status
oc get pods -n mulesoftapps-prod

# Check application logs
oc logs -n mulesoftapps-prod deployment/<app-name>

# Check resource usage
oc top pods -n mulesoftapps-prod
```

## 🔄 Rollback Strategy

### Via ArgoCD
```bash
# View application history
argocd app history mulesoftapps-prd

# Rollback to previous version
argocd app rollback mulesoftapps-prd <revision>

# Or delete application to stop sync
oc delete application mulesoftapps-prd -n openshift-gitops
```

### Manual Rollback
```bash
# Delete resources
kubectl delete -k gitops/overlays/prd

# Redeploy to original cluster if needed
oc login https://api.ocpaz.kohlerco.com:6443
# [restore from backup]
```

## 📈 Post-Migration Tasks

### Immediate Tasks
1. **Verify Application Functionality**: Test all Mulesoft applications
2. **Update DNS Records**: Point domains to OCP-PRD routes
3. **Configure Monitoring**: Set up monitoring and alerting for new environment
4. **Update Documentation**: Update operational runbooks

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
- **Mulesoft Documentation**: `https://docs.mulesoft.com`
- **OpenShift GitOps Documentation**: `https://docs.openshift.com/container-platform/4.15/cicd/gitops/understanding-openshift-gitops.html`

