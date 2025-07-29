# Mulesoft Image Migration Guide

This guide provides step-by-step instructions for migrating the `mulesoft-accelerator-2` image from OCPAZ internal registry to Quay registry.

## 🎯 Migration Overview

**Source**: `default-route-openshift-image-registry.apps.ocpaz.kohlerco.com/mulesoftapps-prod/mulesoft-accelerator-2`
**Target**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2`

## 📋 Prerequisites

- Access to OCPAZ cluster with the source image
- Robot account credentials for Quay registry
- OpenShift CLI (`oc`) installed
- Podman or Docker installed
- Skopeo installed (optional, for direct registry copy)

## 🚀 Quick Start

### Option 1: Automated Migration (Recommended)

```bash
# Make script executable
chmod +x migrate-mulesoft-image.sh

# Run the migration script
./migrate-mulesoft-image.sh
```

The script will:
1. Login to OCPAZ cluster
2. Extract source registry credentials
3. Identify and pull the image
4. Push to Quay registry
5. Verify migration success

### Option 2: Manual Migration Steps

#### Step 1: Login to OCPAZ Cluster

```bash
# Get token from: https://oauth-openshift.apps.ocpaz.kohlerco.com/oauth/token/request
oc login --token=<your-token> --server=https://api.ocpaz.kohlerco.com:6443
```

#### Step 2: Extract Source Image Details

```bash
# Check available images
oc get imagestream -n mulesoftapps-prod

# Get specific image details
oc get imagestream mulesoft-accelerator-2 -n mulesoftapps-prod -o yaml
```

#### Step 3: Login to Registries

```bash
# Login to target Quay registry
echo "MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0" | \
  podman login --username "mulesoftapps+robot" --password-stdin \
  kohler-registry-quay-quay.apps.ocp-host.kohlerco.com
```

#### Step 4: Migrate Image

**Using Skopeo (Direct Registry Copy)**:
```bash
skopeo copy \
  --src-tls-verify=false --dest-tls-verify=false \
  docker://default-route-openshift-image-registry.apps.ocpaz.kohlerco.com/mulesoftapps-prod/mulesoft-accelerator-2:latest \
  docker://kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2:latest
```

**Using Podman/Docker**:
```bash
# Pull from source
podman pull default-route-openshift-image-registry.apps.ocpaz.kohlerco.com/mulesoftapps-prod/mulesoft-accelerator-2:latest

# Tag for target
podman tag \
  default-route-openshift-image-registry.apps.ocpaz.kohlerco.com/mulesoftapps-prod/mulesoft-accelerator-2:latest \
  kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2:latest

# Push to target
podman push kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2:latest
```

#### Step 5: Verify Migration

```bash
# Test pull from target registry
podman pull kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2:latest
```

## 🔐 Setting Up Pull Secrets in Target Environment

After migrating the image, you need to create pull secrets in the target OpenShift cluster.

### Automated Pull Secret Creation

```bash
# Login to target cluster (OCP-PRD)
oc login https://api.ocp-prd.kohlerco.com:6443

# Run pull secret creation script
./create-quay-pull-secret.sh
```

### Manual Pull Secret Creation

```bash
# Create pull secret
oc create secret docker-registry quay-pull-secret \
  --docker-server=kohler-registry-quay-quay.apps.ocp-host.kohlerco.com \
  --docker-username="mulesoftapps+robot" \
  --docker-password="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0" \
  --namespace=mulesoftapps-prod

# Update service account
oc patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "quay-pull-secret"}]}' \
  -n mulesoftapps-prod
```

## 📝 Updating Deployment Manifests

After migration, update your deployment manifests to reference the new image location:

### Before (OCPAZ Internal Registry)
```yaml
spec:
  containers:
  - name: mulesoft-app
    image: image-registry.openshift-image-registry.svc:5000/mulesoftapps-prod/mulesoft-accelerator-2:latest
```

### After (Quay Registry)
```yaml
spec:
  containers:
  - name: mulesoft-app
    image: kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2:latest
```

## 🔍 Verification Commands

### Check Image in Target Registry
```bash
# Login to Quay registry
echo "MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0" | \
  podman login --username "mulesoftapps+robot" --password-stdin \
  kohler-registry-quay-quay.apps.ocp-host.kohlerco.com

# Pull and inspect image
podman pull kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2:latest
podman inspect kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2:latest
```

### Test Deployment with New Image
```bash
# Create test deployment
oc create deployment test-mulesoft-migration \
  --image=kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2:latest \
  -n mulesoftapps-prod

# Check deployment status
oc get deployment test-mulesoft-migration -n mulesoftapps-prod
oc get pods -l app=test-mulesoft-migration -n mulesoftapps-prod

# Clean up test deployment
oc delete deployment test-mulesoft-migration -n mulesoftapps-prod
```

## 🛠️ Troubleshooting

### Image Pull Errors
```bash
# Check pull secret exists
oc get secret quay-pull-secret -n mulesoftapps-prod

# Verify service account has pull secret
oc describe serviceaccount default -n mulesoftapps-prod

# Check image reference in deployment
oc describe deployment <deployment-name> -n mulesoftapps-prod
```

### Registry Authentication Issues
```bash
# Test registry login manually
echo "MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0" | \
  podman login --username "mulesoftapps+robot" --password-stdin \
  kohler-registry-quay-quay.apps.ocp-host.kohlerco.com

# Verify credentials
podman pull kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/mulesoftapps/mulesoft-accelerator-2:latest
```

### Source Image Not Found
```bash
# List available ImageStreams in source namespace
oc get imagestream -n mulesoftapps-prod

# Check specific ImageStream details
oc describe imagestream mulesoft-accelerator-2 -n mulesoftapps-prod

# List all images in namespace
oc get images | grep mulesoftapps-prod
```

## 📊 Migration Status Checklist

- [ ] OCPAZ cluster access verified
- [ ] Source image identified and accessible
- [ ] Quay registry credentials tested
- [ ] Image successfully migrated to Quay
- [ ] Pull secret created in target namespace
- [ ] Service accounts updated with pull secret
- [ ] Deployment manifests updated with new image reference
- [ ] Applications tested with new image
- [ ] Migration documentation updated

## 🔄 Post-Migration Tasks

1. **Update CI/CD Pipelines**: Modify build pipelines to push directly to Quay registry
2. **Update Documentation**: Update operational runbooks with new image references
3. **Monitor Applications**: Ensure applications work correctly with migrated images
4. **Security Review**: Verify robot account permissions are appropriate
5. **Backup Strategy**: Implement backup procedures for Quay registry images

## 📁 Generated Files

- `migrate-mulesoft-image.sh` - Automated migration script
- `create-quay-pull-secret.sh` - Pull secret creation script
- `MULESOFT-IMAGE-MIGRATION-REPORT.md` - Detailed migration report
- `IMAGE-MIGRATION-README.md` - This guide

## 🔗 Additional Resources

- **Quay Registry UI**: `https://kohler-registry-quay-quay.apps.ocp-host.kohlerco.com`
- **OCPAZ Console**: `https://console-openshift-console.apps.ocpaz.kohlerco.com`
- **Robot Account Management**: Access through Quay UI → mulesoftapps organization
- **Skopeo Documentation**: `https://github.com/containers/skopeo`
- **Podman Documentation**: `https://podman.io/getting-started/`
