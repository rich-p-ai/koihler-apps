# OracleCPQ Migration Inventory

**Migration Date**: Wed, Aug  6, 2025  6:10:19 AM
**Source Cluster**: OCP4 (api.ocp4.kohlerco.com)
**Target Cluster**: OCP-PRD (api.ocp-prd.kohlerco.com)
**Namespace**: oraclecpq

## Resource Summary

### Application Resources
- **Deployments**: 9
- **DeploymentConfigs**: 0
- **StatefulSets**: 0
- **Services**: 7
- **Routes**: 4

### Configuration Resources
- **ConfigMaps**: 12
- **Secrets**: 22
- **ServiceAccounts**: 5

### Storage and Other Resources
- **PVCs**: 8
- **RoleBindings**: 12
- **ImageStreams**: 6
- **BuildConfigs**: 1
- **CronJobs**: 0
- **Jobs**: 0
- **NetworkPolicies**: 0

## NodePort Configuration

Based on the HAProxy configuration, OracleCPQ uses the following NodePorts:
- **32029, 32030, 32031** - Primary application ports
- **32074, 32075, 32076** - Additional service ports

These ports must be configured on the OCP-PRD worker nodes:
- 10.20.136.62 (worker1)
- 10.20.136.63 (worker2) 
- 10.20.136.64 (worker3)

## Domain Configuration

- **Source Domain**: *.apps.ocp4.kohlerco.com
- **Target Domain**: *.apps.ocp-prd.kohlerco.com
- **Expected Route**: oraclecpq.apps.ocp-prd.kohlerco.com

## NFS Storage Configuration

The following NFS persistent volumes are configured:
- **Development**: /ifs/NFS/USWINFS01/D/Shared/DEV/kbnaOracleCpq
- **QA**: /ifs/NFS/USWINFS01/D/Shared/QA/kbnaOracleCpq
- **Production**: /ifs/NFS/USWINFS01/D/Shared/PRD/kbnaOracleCpq

These will need to be reconfigured for OCP-PRD storage classes.

## Directory Structure

```
oraclecpq-migration/
├── backup/
│   ├── raw/           # Original exported resources from OCP4
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
oc get all -n oraclecpq

# Check deployments
oc get deployment -n oraclecpq

# Check routes
oc get route -n oraclecpq

# Check storage
oc get pvc -n oraclecpq

# Check ArgoCD sync status
oc get application oraclecpq-prd -n openshift-gitops

# Check application logs
oc logs -n oraclecpq deployment/<app-name>
```

## Migration Considerations

### Oracle CPQ-Specific Notes
- ⚠️ **Database Connections**: Update database connection strings for new environment
- ⚠️ **Oracle Integration**: Verify Oracle product configuration connectivity
- ⚠️ **External APIs**: Verify external service connectivity from OCP-PRD
- ⚠️ **License Configuration**: Update Oracle CPQ license configuration

### Storage Migration
- ⚠️ **Storage Classes**: Updated to use `gp3-csi` for OCP-PRD compatibility
- ⚠️ **NFS Volumes**: Migrate NFS persistent volume data
- ⚠️ **Data Migration**: Plan data migration strategy for persistent volumes
- ⚠️ **Backup Strategy**: Implement backup procedures for new environment

### Security and RBAC
- ⚠️ **Service Accounts**: Review service account permissions
- ⚠️ **Security Contexts**: Validate SCC assignments
- ⚠️ **Network Policies**: Update network policies for new cluster network topology
- ⚠️ **Group Access**: Verify oraclecpq-admin group access

### Networking
- ⚠️ **Routes**: Verify route hostnames don't conflict with existing applications
- ⚠️ **NodePorts**: Configure NodePort services for HAProxy integration
- ⚠️ **Load Balancers**: Update external load balancer configurations
- ⚠️ **DNS**: Update DNS records to point to new cluster

## Post-Migration Checklist

1. **Pre-Migration Tasks**
   - Export data from NFS volumes
   - Document current database connections
   - Verify external integrations
   - Coordinate with Oracle CPQ team

2. **Data Migration**
   - Execute NFS data export/import
   - Verify data integrity after migration

3. **Deployment**
   - Review generated GitOps manifests in `gitops/overlays/prd/`
   - Update environment-specific configurations
   - Commit changes to Git repository
   - Deploy using ArgoCD

4. **Post-Migration Testing**
   - Verify application functionality
   - Test Oracle CPQ workflows
   - Test database connectivity
   - Monitor application performance
   - Update monitoring and alerting

5. **DNS and Load Balancer Updates**
   - Update DNS records
   - Configure HAProxy NodePort rules
   - Test external connectivity

6. **Documentation Updates**
   - Update runbooks and operational procedures
   - Update environment documentation
   - Notify stakeholders of new environment details

