# Mulesoft Apps Migration Inventory

**Migration Date**: Mon, Jul 28, 2025  8:31:27 AM
**Source Cluster**: https://api.ocpaz.kohlerco.com:6443
**Source Namespace**: mulesoftapps-prod
**Target Cluster**: https://api.ocp-prd.kohlerco.com:6443
**Target Namespace**: mulesoftapps-prod

## Resource Summary

### Applications and Services
3 total applications (Deployments + DeploymentConfigs)

### Detailed Resources
- **ConfigMaps**: 4
- **Secrets**: 23
- **Services**: 1
- **Routes**: 1
- **Deployments**: 3
- **DeploymentConfigs**: 0
- **StatefulSets**: 0
- **DaemonSets**: 0
- **PVCs**: 2
- **RoleBindings**: 9
- **ImageStreams**: 3
- **BuildConfigs**: 0
- **CronJobs**: 0
- **Jobs**: 0
- **NetworkPolicies**: 0

## Applications Identified

mulesoft-accelerator-2      Deployment   image-registry.openshift-image-registry.svc:5000/mulesoftapps-prod/mulesoft-accelerator-2@sha256:a25f221dc46e0c2ea60924e0cd68492fd6c27ed742f2c058ad1c8e152384c7c6
wins0002499-codepuller      Deployment   image-registry.openshift-image-registry.svc:5000/mulesoftapps-prod/wins0002499-codepuller@sha256:f030450d84862b684a69042498d3a33fae01e75f6fb6939f7377b2d87b8c97e6
wins0002537-notifications   Deployment   image-registry.openshift-image-registry.svc:5000/mulesoftapps-prod/wins0002537-notifications@sha256:2feaa545430b367a3f85795ad614539b6a0a9697c39a91bdd7532738214b311c

## Container Images

image-registry.openshift-image-registry.svc:5000/mulesoftapps-prod/mulesoft-accelerator-2@sha256:a25f221dc46e0c2ea60924e0cd68492fd6c27ed742f2c058ad1c8e152384c7c6
image-registry.openshift-image-registry.svc:5000/mulesoftapps-prod/wins0002499-codepuller@sha256:f030450d84862b684a69042498d3a33fae01e75f6fb6939f7377b2d87b8c97e6
image-registry.openshift-image-registry.svc:5000/mulesoftapps-prod/wins0002537-notifications@sha256:2feaa545430b367a3f85795ad614539b6a0a9697c39a91bdd7532738214b311c

## Storage Requirements

mulesoft-accelerator     10Gi    azure-file
notifications-storage1   512Mi   azure-file

## Network Routes

mulesoftprd.apps.ocpaz.kohlerco.com   mulesoftprd.apps.ocpaz.kohlerco.com   mulesoft-accelerator-2

## Directory Structure

```
mulesoftapps-migration/
├── backup/
│   ├── raw/           # Original exported resources from OCPAZ
│   └── cleaned/       # Processed resources for OCP-PRD
├── gitops/
│   ├── base/          # Base Kustomize configuration
│   └── overlays/
│       └── prd/       # Production overlay for OCP-PRD
└── argocd-application.yaml
```

## Deployment Options

### Option 1: ArgoCD (Recommended)
```bash
oc login https://api.ocp-prd.kohlerco.com:6443
oc apply -f gitops/argocd-application.yaml
```

### Option 2: Direct Kustomize
```bash
oc login https://api.ocp-prd.kohlerco.com:6443
kubectl apply -k gitops/overlays/prd
```

### Option 3: Automated Script
```bash
./deploy-to-ocp-prd.sh
```

## Verification Commands

After deployment:
```bash
# Check namespace and resources
oc get all -n mulesoftapps-prod

# Check deployments
oc get deployment -n mulesoftapps-prod

# Check routes
oc get route -n mulesoftapps-prod

# Check storage
oc get pvc -n mulesoftapps-prod

# Check ArgoCD sync status
oc get application mulesoftapps-prd -n openshift-gitops

# Check application logs
oc logs -n mulesoftapps-prod deployment/<app-name>
```

## Migration Considerations

### Image Registry Migration
- ⚠️ **Container Images**: Updated registry references from OCPAZ to OCP-PRD
- ⚠️ **Internal Registry**: Changed from `image-registry.openshift-image-registry.svc:5000/` to Quay registry
- ⚠️ **Registry Authentication**: Verify pull secrets are available on target cluster

### Application-Specific Notes
- ⚠️ **Mulesoft Runtime**: Verify Mulesoft runtime versions are compatible
- ⚠️ **Anypoint Platform**: Update connectivity to Anypoint Platform if required
- ⚠️ **Environment Variables**: Review and update environment-specific configurations
- ⚠️ **Database Connections**: Update database connection strings for new environment
- ⚠️ **External APIs**: Verify external service connectivity from OCP-PRD

### Storage Migration
- ⚠️ **Storage Classes**: Verify storage classes are available on OCP-PRD
- ⚠️ **Data Migration**: Plan data migration strategy for persistent volumes
- ⚠️ **Backup Strategy**: Implement backup procedures for new environment

### Security and RBAC
- ⚠️ **Service Accounts**: Review service account permissions
- ⚠️ **Security Contexts**: Validate SCC assignments
- ⚠️ **Network Policies**: Update network policies for new cluster network topology

### Networking
- ⚠️ **Routes**: Verify route hostnames don't conflict with existing applications
- ⚠️ **Load Balancers**: Update external load balancer configurations
- ⚠️ **DNS**: Update DNS records to point to new cluster

## Important Notes

- 🚨 **DeploymentConfigs**: Converted to standard Kubernetes Deployments (manual review required)
- 🚨 **ImageStreams**: May require adjustment for OCP-PRD compatibility
- 🚨 **BuildConfigs**: Review build configurations for new cluster
- 🚨 **Persistent Data**: Plan data migration strategy separately
- 🚨 **Secrets**: Verify all secrets are properly migrated and accessible

## Next Steps

1. **Pre-Migration Testing**
   - Test GitOps manifests in development environment
   - Verify container image accessibility
   - Test database connectivity

2. **Data Migration** (if required)
   - Plan and execute persistent volume data migration
   - Backup critical data before migration
   - Verify data integrity after migration

3. **Deployment**
   - Review generated GitOps manifests in `gitops/overlays/prd/`
   - Update environment-specific configurations
   - Commit changes to Git repository
   - Deploy using ArgoCD

4. **Post-Migration Testing**
   - Verify application functionality
   - Test all endpoints and APIs
   - Monitor application performance
   - Update monitoring and alerting

5. **DNS and Load Balancer Updates**
   - Update DNS records
   - Configure load balancer rules
   - Test external connectivity

6. **Documentation Updates**
   - Update runbooks and operational procedures
   - Update environment documentation
   - Notify stakeholders of new environment details

