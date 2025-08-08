# OracleCPQ NFS Storage Configuration

## Overview

This directory contains the NFS Persistent Volumes (PVs) and Persistent Volume Claims (PVCs) for the OracleCPQ application. These are required for NFS storage mapping to specific server paths.

## NFS Storage Structure

### Persistent Volumes (PVs)

The following NFS Persistent Volumes are defined in `nfs-persistent-volumes.yaml`:

| PV Name | Environment | NFS Path | Server | Capacity |
|---------|-------------|----------|--------|----------|
| `nfspvdevnaskbnaoraclecpq` | DEV | `/ifs/NFS/USWINFS01/D/Shared/DEV/kbnaOracleCpq` | `USWINFS01.kohlerco.com` | 20Gi |
| `nfspvqanaskbnaoraclecpq` | QA | `/ifs/NFS/USWINFS01/D/Shared/QA/kbnaOracleCpq` | `USWINFS01.kohlerco.com` | 20Gi |
| `nfspvprdnaskbnaoraclecpq` | PRD | `/ifs/NFS/USWINFS01/D/Shared/PRD/kbnaOracleCpq` | `USWINFS01.kohlerco.com` | 20Gi |
| `nfspvdevnascpq` | DEV | `/ifs/NFS/USWINFS01/D/Shared/DEV/cpq` | `USWINFS01.kohlerco.com` | 20Gi |
| `nfspvqanascpq` | QA | `/ifs/NFS/USWINFS01/D/Shared/QA/cpq` | `USWINFS01.kohlerco.com` | 20Gi |
| `nfspvprdnascpq` | PRD | `/ifs/NFS/USWINFS01/D/Shared/PRD/cpq` | `USWINFS01.kohlerco.com` | 20Gi |

### Persistent Volume Claims (PVCs)

The following NFS Persistent Volume Claims are defined in `pvcs.yaml`:

| PVC Name | Environment | Volume Name | Storage Request | Access Mode |
|----------|-------------|-------------|-----------------|-------------|
| `nfspvcdevnaskbnaoraclecpq` | DEV | `nfspvdevnaskbnaoraclecpq` | 15Gi | ReadWriteMany |
| `nfspvcqanaskbnaoraclecpq` | QA | `nfspvqanaskbnaoraclecpq` | 15Gi | ReadWriteMany |
| `nfspvcprdnaskbnaoraclecpq` | PRD | `nfspvprdnaskbnaoraclecpq` | 15Gi | ReadWriteMany |
| `nfspvcdevnascpq` | DEV | `nfspvdevnascpq` | 20Gi | ReadWriteMany |
| `nfspvcqanascpq` | QA | `nfspvqanascpq` | 20Gi | ReadWriteMany |
| `nfspvcprdnascpq` | PRD | `nfspvprdnascpq` | 20Gi | ReadWriteMany |

## Deployment Order

When deploying with ArgoCD, the resources are applied in the following order:

1. **Persistent Volumes** (`nfs-persistent-volumes.yaml`) - Must be created first
2. **Persistent Volume Claims** (`pvcs.yaml`) - Reference the PVs via `volumeName`

## Important Notes

### NFS Server Requirements

- **Server**: `USWINFS01.kohlerco.com`
- **Network Access**: Ensure the cluster nodes can access the NFS server
- **Path Permissions**: Verify the NFS paths have appropriate read/write permissions

### Storage Class

- **Storage Class**: `nfs`
- **Reclaim Policy**: `Retain` (PVs are not automatically deleted)
- **Access Mode**: `ReadWriteMany` (supports multiple pods reading/writing)

### ArgoCD Integration

The NFS storage configuration is integrated with ArgoCD through:

1. **Kustomization**: Resources are included in `kustomization.yaml`
2. **Labels**: All resources are labeled for ArgoCD management
3. **Namespace**: Resources are deployed to the `oraclecpq` namespace

## Verification Commands

After deployment, verify the NFS storage setup:

```bash
# Check Persistent Volumes
oc get pv | grep nfspv

# Check Persistent Volume Claims
oc get pvc -n oraclecpq | grep nfs

# Check PV/PVC binding status
oc describe pv nfspvprdnaskbnaoraclecpq
oc describe pvc nfspvcprdnaskbnaoraclecpq -n oraclecpq

# Check NFS mount points (if pods are running)
oc exec -n oraclecpq <pod-name> -- df -h
```

## Troubleshooting

### Common Issues

1. **PV Not Bound**: Check if the NFS server is accessible and paths exist
2. **Permission Denied**: Verify NFS path permissions on the server
3. **Network Issues**: Ensure cluster nodes can reach `USWINFS01.kohlerco.com`

### Debug Commands

```bash
# Check NFS server connectivity
oc debug node/<node-name> -- chroot /host nslookup USWINFS01.kohlerco.com

# Check NFS mount status
oc debug node/<node-name> -- chroot /host mount | grep nfs

# Check PV events
oc describe pv nfspvprdnaskbnaoraclecpq
```

## Migration from OCP4

These NFS storage configurations were migrated from the OCP4 cluster and adapted for OCP-PRD deployment with ArgoCD. The key changes include:

- Added ArgoCD labels for resource management
- Updated namespace references for OCP-PRD
- Ensured proper volumeName references between PVs and PVCs
- Maintained NFS server and path configurations
