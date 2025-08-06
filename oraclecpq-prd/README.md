# OracleCPQ Production Deployment

## Overview

This directory contains the GitOps configuration for deploying OracleCPQ to the OCP-PRD cluster using ArgoCD.

## Structure

```
oraclecpq-prd/
├── base/                           # Base Kustomize resources
│   ├── kustomization.yaml          # Base kustomization configuration
│   ├── namespace.yaml              # Namespace definition
│   ├── scc-binding.yaml            # Security context constraints
│   └── serviceaccount.yaml         # Service account configuration
└── overlays/prd/                   # Production overlay
    ├── kustomization.yaml          # Production kustomization
    ├── buildconfigs.yaml           # Build configurations
    ├── configmaps.yaml             # Configuration maps
    ├── cronjobs.yaml               # Cron jobs
    ├── deploymentconfigs.yaml      # Deployment configurations (OpenShift)
    ├── deployments.yaml            # Kubernetes deployments
    ├── imagestreams.yaml           # OpenShift image streams
    ├── jobs.yaml                   # Kubernetes jobs
    ├── namespace.yaml              # Namespace overlay
    ├── networkpolicies.yaml        # Network policies
    ├── pvcs.yaml                   # Persistent volume claims
    ├── rolebindings.yaml           # Role bindings
    ├── routes.yaml                 # OpenShift routes
    ├── secrets.yaml                # Secrets
    ├── serviceaccounts.yaml        # Service accounts
    ├── services.yaml               # Kubernetes services
    └── statefulsets.yaml           # Stateful sets
```

## Deployment

The application is deployed via ArgoCD using the application definition in:
- `applications/oraclecpq-prd.yaml`

### Manual Deployment

To deploy manually:

```bash
# Apply the ArgoCD application
oc apply -f applications/oraclecpq-prd.yaml

# Monitor the deployment
oc get application oraclecpq-prd -n openshift-gitops -w
```

### Direct Kustomize Deployment

For testing or manual deployment:

```bash
# Deploy using Kustomize
oc apply -k oraclecpq-prd/overlays/prd

# Verify deployment
oc get all -n oraclecpq
```

## Configuration

### Key Components

- **Namespace**: `oraclecpq`
- **Storage**: Uses `gp3-csi` storage class for OCP-PRD
- **NodePorts**: Configured for HAProxy integration (32029, 32030, 32031, 32074, 32075, 32076)
- **Security**: Uses `anyuid` SCC for required permissions
- **RBAC**: Configured for `oraclecpq-admin` group access

### Environment Variables

The application configurations have been updated for OCP-PRD environment:
- Database connections updated for production network
- Storage paths configured for production NFS
- Image registries updated to use Quay

## Monitoring

Monitor the application deployment and status:

```bash
# Check ArgoCD application status
oc get application oraclecpq-prd -n openshift-gitops

# Check application resources
oc get all -n oraclecpq

# Check application logs
oc logs -f deployment/[deployment-name] -n oraclecpq
```

## Access

The application will be accessible via:
- **Internal**: `oraclecpq.apps.ocp-prd.kohlerco.com`
- **External**: Through HAProxy load balancer configuration

## Troubleshooting

### Common Issues

1. **Pod Startup Issues**: Check storage class and PVC binding
2. **Database Connectivity**: Verify database connection strings and network policies
3. **Image Pull Issues**: Verify image registry access and credentials
4. **Permission Issues**: Check SCC bindings and service account permissions

### Debugging Commands

```bash
# Check pod status
oc get pods -n oraclecpq

# Check events
oc get events -n oraclecpq --sort-by='.lastTimestamp'

# Check ArgoCD sync status
oc describe application oraclecpq-prd -n openshift-gitops

# Check specific resource
oc describe [resource-type]/[resource-name] -n oraclecpq
```

## Migration Notes

This deployment was migrated from OCP4 cluster with the following key changes:
- Storage classes updated from OCP4 to OCP-PRD compatible classes
- Image registries updated for new cluster
- Network configurations adapted for OCP-PRD
- Security contexts updated for production environment

For detailed migration information, see the migration package documentation in `oraclecpq-migration/` directory.
