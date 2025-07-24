# 📦 Image Migration Summary

## Migration Details

**Date**: Thu, Jul 24, 2025 10:53:33 AM
**Source Registry**: default-route-openshift-image-registry.apps.ocp4.kohlerco.com
**Target Registry**: kohler-registry-quay-quay.apps.ocp-host.kohlerco.com
**Repository**: procurementapps/pm-procedures-webapp
**Migration Method**: OpenShift `oc image mirror`

## Migration Results

- **Total Tags Attempted**: 9
- **Successful Migrations**: 9
- **Failed Migrations**: 1

### ✅ Successfully Migrated Images

- **la**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:la`
- ****: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:`
- **dev**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:dev`
- **2025.04.01**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:2025.04.01`
- **2025.03.31**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:2025.03.31`
- **2025.03.30**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:2025.03.30`
- **2025.03.29**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:2025.03.29`
- **2025.03.28**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:2025.03.28`
- **2024.12.13**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:2024.12.13`

### ❌ Failed Migrations

- **test**: Migration failed - manual intervention required

## Registry Access

### Target Quay Registry
- **URL**: https://kohler-registry-quay-quay.apps.ocp-host.kohlerco.com
- **Namespace**: procurementapps
- **Robot Account**: procurementapps+robot
- **Repository**: procurementapps/pm-procedures-webapp

### Pull Command Examples
```bash
# Using oc
oc image info kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:latest

# Using podman (if available)
podman pull kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:latest
```

### Registry Login for Manual Operations
```bash
# Login to new Quay registry
podman login -u="procurementapps+robot" -p="VH0781F461803O8TYUUWADVAZMEU2CV1CENXZ24O21F7EC8I1KSPMTRDZLEJLFTG" kohler-registry-quay-quay.apps.ocp-host.kohlerco.com
```

## GitOps Configuration

The GitOps configuration has been updated to use the new registry:

### Updated Files
- `gitops/overlays/prd/kustomization.yaml`: Image references updated

### New Image Reference
```yaml
images:
  - name: image-registry.openshift-image-registry.svc:5000/procurementapps/pm-procedures-webapp
    newName: kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp
    newTag: latest
```

## Migration Files Generated

- `quay-auth.json`: Registry authentication configuration
- `image-mapping.txt`: Complete image mapping for bulk migration
- `IMAGE-MIGRATION-SUMMARY.md`: This summary document

## Verification

To verify the migration:
```bash
# Check image exists in new registry
oc image info --registry-config=quay-auth.json kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:latest

# Test with different tags
oc image info --registry-config=quay-auth.json kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:test
```

## Next Steps

1. **Commit GitOps Changes**: Commit the updated kustomization.yaml to Git
2. **Update ArgoCD**: Sync the application to use new images
3. **Test Deployment**: Verify the application deploys correctly with new images
4. **Update CI/CD**: Configure build pipelines to push to new Quay registry
5. **Clean Up**: Remove old images from OCP4 registry if desired

## 🔧 Manual Migration Required

The following tags failed automatic migration and need manual attention:
- **test**

Manual migration steps:
```bash
# For each failed tag, try:
oc image mirror \
  --registry-config=quay-auth.json \
  default-route-openshift-image-registry.apps.ocp4.kohlerco.com/procurementapps/pm-procedures-webapp:TAG=kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:TAG
```

## Troubleshooting

If you encounter issues:

1. **Authentication Problems**: Verify robot account credentials in Quay UI
2. **Network Issues**: Check connectivity to target registry
3. **Repository Not Found**: Create repository in Quay UI first
4. **Permission Denied**: Verify robot account has push permissions

### Manual Verification Commands
```bash
# Check source image exists
oc get imagestream pm-procedures-webapp -n procurementapps

# Check target registry connectivity
curl -k https://kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/v2/

# Manual single image migration
oc image mirror \
  --registry-config=quay-auth.json \
  default-route-openshift-image-registry.apps.ocp4.kohlerco.com/procurementapps/pm-procedures-webapp:latest=kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:latest
```

---

**Migration Status**: ⚠️ Partially Completed - Manual intervention required
