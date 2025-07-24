# Procurement Apps Migration to OCP-PRD with GitOps

This project contains the complete migration of the `procurementapps` namespace from OCP4 cluster to the new OCP-PRD cluster, with conversion from OpenShift DeploymentConfigs to standard Kubernetes Deployments and modern GitOps deployment using Kustomize and ArgoCD.

## 🎯 Project Overview

- **Source**: OCP4 cluster (`api.ocp4.kohlerco.com`)
- **Target**: OCP-PRD cluster (`api.ocp-prd.kohlerco.com`)
- **Namespace**: `procurementapps`
- **Migration Type**: DeploymentConfig → Deployment
- **Method**: GitOps with Kustomize overlays
- **Orchestration**: ArgoCD applications

## 📁 Project Structure

```
procurementapps-migration/
├── README.md                           # This file
├── migrate-procurementapps.sh          # Automated migration script
├── backup/                             # Backup of original resources
│   ├── raw/                           # Raw exports from OCP4
│   └── cleaned/                       # Cleaned resources ready for deployment
└── gitops/                            # GitOps structure with Kustomize
    ├── base/                          # Base Kustomize configuration
    │   ├── kustomization.yaml         # Base kustomization
    │   ├── namespace.yaml             # Namespace definition
    │   ├── serviceaccount.yaml        # Service accounts and RBAC
    │   └── scc-binding.yaml           # Security context constraints
    ├── overlays/                      # Environment-specific overlays
    │   └── prd/                       # Production environment
    │       ├── kustomization.yaml     # Prod-specific configuration
    │       ├── configmaps.yaml        # ConfigMaps for production
    │       ├── secrets.yaml           # Secrets for production
    │       ├── deployments.yaml       # Deployments (converted from DC)
    │       ├── services.yaml          # Services for production
    │       └── routes.yaml            # Routes for production
    └── argocd-application.yaml        # ArgoCD application definition
```

## 🚀 Quick Start

### Prerequisites
- Access to OCP4 cluster (for backup/reference)
- Access to OCP-PRD cluster (for deployment)
- OpenShift CLI (`oc`)
- ArgoCD access on target cluster

### Step 1: Deploy to OCP-PRD with ArgoCD

```bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# Monitor deployment
oc get application procurementapps-prd -n openshift-gitops
```

### Alternative: Direct Kustomize Deployment

```bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy using Kustomize
kubectl apply -k gitops/overlays/prd
```

## 🔧 Key Features

### Migration Benefits
- **DeploymentConfig → Deployment**: Converted from OpenShift-specific DeploymentConfigs to standard Kubernetes Deployments
- **GitOps Ready**: Structured overlay approach for different environments
- **ArgoCD Integration**: Automated deployment and sync capabilities
- **Container Registry**: Updated image references for target cluster (Quay registry)
- **Security**: Maintained useroot service account with anyuid SCC

### Applications Migrated
- **pm-procedures-prod**: Production PM Procedures webapp
- **pm-procedures-test**: Test PM Procedures webapp

### Key Changes Made
1. **DeploymentConfig → Deployment**: Converted OpenShift-specific resources to Kubernetes standard
2. **Image Registry**: Updated from internal registry to Quay registry
3. **Security Context**: Maintained root user permissions with proper SCC bindings
4. **Resource Management**: Added proper resource limits and requests
5. **Health Checks**: Maintained liveness and readiness probes
6. **Configuration**: Preserved all environment variables, secrets, and configmaps

## 🔍 Verification

After deployment, verify the migration:

```bash
# Check namespace and resources
oc get all -n procurementapps

# Check deployments specifically
oc get deployment -n procurementapps

# Check application health
oc get pods -n procurementapps

# Check routes and accessibility
oc get route -n procurementapps

# Check ArgoCD sync status
oc get application procurementapps-prd -n openshift-gitops
```

## 📊 Migration Summary

### Resources Migrated
- **DeploymentConfigs**: 2 → Converted to Deployments
- **Services**: 2 (pm-procedures-prod, pm-procedures-test)
- **Routes**: 2 (HTTPS with passthrough termination)
- **ConfigMaps**: 2 (application configuration)
- **Secrets**: 6 (certificates, passwords, application secrets)
- **ServiceAccounts**: 1 (useroot with anyuid SCC)
- **ImageStreams**: 1 (pm-procedures-webapp)

### Application URLs
- **Production**: `https://pm-procedures-prod.apps.ocp-prd.kohlerco.com`
- **Test**: `https://pm-procedures-test.apps.ocp-prd.kohlerco.com`

## 🚨 Important Notes

### Before Deployment
- ⚠️ **Image Registry**: Ensure images are available in Quay registry
- ⚠️ **Secrets**: Verify all secrets contain correct values for target environment
- ⚠️ **DNS**: Update DNS entries if cluster domains change
- ⚠️ **SSL Certificates**: Ensure SSL certificates are valid for new routes

### After Deployment
- 🔍 **Test Applications**: Verify both prod and test applications are accessible
- 🔍 **Monitor Performance**: Check resource usage and application performance
- 🔍 **Update Dependencies**: Update any external systems pointing to old URLs
- 🔍 **Certificate Renewal**: Plan for SSL certificate renewal process

## 🛠️ Troubleshooting

### Common Issues
1. **Image Pull Errors**: Check if images exist in Quay registry
2. **Permission Errors**: Verify SCC bindings and service account permissions
3. **Route Issues**: Check route configuration and SSL certificates
4. **Application Startup**: Check environment variables and mounted secrets

### Debug Commands
```bash
# Check pod logs
oc logs -f deployment/pm-procedures-prod -n procurementapps

# Check events
oc get events -n procurementapps --sort-by='.lastTimestamp'

# Describe problematic resources
oc describe deployment pm-procedures-prod -n procurementapps
oc describe pod <pod-name> -n procurementapps
```

## 🔄 Rollback

If issues occur:

```bash
# Remove ArgoCD application
oc delete application procurementapps-prd -n openshift-gitops

# Or remove namespace entirely
oc delete namespace procurementapps
```

Original resources are preserved in `backup/raw/` directory.

## 📈 Next Steps

1. Monitor application performance and stability
2. Set up monitoring and alerting
3. Plan decommissioning of OCP4 resources
4. Train team on GitOps procedures
5. Plan additional namespace migrations

---

**Status**: Ready for production deployment with GitOps! 🚀
