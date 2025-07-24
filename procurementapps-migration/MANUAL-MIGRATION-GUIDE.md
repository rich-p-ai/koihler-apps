# 📦 Manual Image Migration Guide

## Overview

Since automated migration tools are encountering authentication challenges, this guide provides manual steps to migrate images from OCP4 internal registry to the new Quay registry.

## Prerequisites

- Access to both OCP4 and OCP-PRD clusters
- Robot account credentials for Quay registry
- Container runtime (Podman/Docker) available

## Step-by-Step Migration

### 1. Setup Authentication

```bash
# Login to OCP4 cluster
oc login https://api.ocp4.kohlerco.com:6443

# Login to source registry
oc registry login

# Login to target Quay registry (using robot account)
podman login -u="procurementapps+robot" -p="VH0781F461803O8TYUUWADVAZMEU2CV1CENXZ24O21F7EC8I1KSPMTRDZLEJLFTG" kohler-registry-quay-quay.apps.ocp-host.kohlerco.com
```

### 2. Images to Migrate

Based on the inventory, we need to migrate these key images:

**Essential Tags:**
- `latest` (production baseline)
- `test` (testing version)
- `dev` (development version)

**Recent Versions:**
- `2025.04.01` (most recent)
- `2025.03.31`
- `2025.03.30`
- `2025.03.29`
- `2025.03.28`
- `2024.12.13` (stable version)

### 3. Migration Methods

#### Option A: Using oc image mirror (Recommended)

```bash
# Export images to local directory first
mkdir -p /tmp/image-export

# For each image tag, export and import
for tag in latest test dev 2025.04.01 2025.03.31 2025.03.30 2025.03.29 2025.03.28 2024.12.13; do
  echo "Migrating: $tag"
  
  # Mirror from source to target
  oc image mirror \
    image-registry.openshift-image-registry.svc:5000/procurementapps/pm-procedures-webapp:$tag \
    kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:$tag \
    --registry-config=~/.docker/config.json
done
```

#### Option B: Using Podman (If available)

```bash
# For each tag
for tag in latest test dev 2025.04.01 2025.03.31 2025.03.30 2025.03.29 2025.03.28 2024.12.13; do
  echo "Processing: $tag"
  
  # Pull from source
  podman pull default-route-openshift-image-registry.apps.ocp4.kohlerco.com/procurementapps/pm-procedures-webapp:$tag
  
  # Tag for target
  podman tag \
    default-route-openshift-image-registry.apps.ocp4.kohlerco.com/procurementapps/pm-procedures-webapp:$tag \
    kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:$tag
  
  # Push to target
  podman push kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:$tag
  
  # Clean up local images
  podman rmi \
    default-route-openshift-image-registry.apps.ocp4.kohlerco.com/procurementapps/pm-procedures-webapp:$tag \
    kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:$tag
done
```

#### Option C: Export/Import via File

```bash
# Create export directory
mkdir -p ~/image-exports

# Export each image
for tag in latest test dev 2025.04.01 2025.03.31 2025.03.30 2025.03.29 2025.03.28 2024.12.13; do
  echo "Exporting: $tag"
  
  # Save image to tar file
  podman save \
    default-route-openshift-image-registry.apps.ocp4.kohlerco.com/procurementapps/pm-procedures-webapp:$tag \
    -o ~/image-exports/pm-procedures-webapp-$tag.tar
done

# Import each image
for tag in latest test dev 2025.04.01 2025.03.31 2025.03.30 2025.03.29 2025.03.28 2024.12.13; do
  echo "Importing: $tag"
  
  # Load image from tar file
  podman load -i ~/image-exports/pm-procedures-webapp-$tag.tar
  
  # Tag for target registry
  podman tag \
    default-route-openshift-image-registry.apps.ocp4.kohlerco.com/procurementapps/pm-procedures-webapp:$tag \
    kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:$tag
  
  # Push to target
  podman push kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:$tag
done
```

### 4. Verification

After migration, verify each image:

```bash
# Verify images exist in target registry
for tag in latest test dev 2025.04.01 2025.03.31 2025.03.30 2025.03.29 2025.03.28 2024.12.13; do
  echo "Verifying: $tag"
  podman pull kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:$tag
  podman inspect kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp:$tag
done
```

### 5. Update GitOps Configuration

After successful migration, update the image references:

```bash
# Navigate to GitOps directory
cd gitops/overlays/prd

# Update kustomization.yaml
# Change:
# newName: quay.openshiftocp4.kohlerco.com/procurementapps/pm-procedures-webapp
# To:
# newName: kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/procurementapps/pm-procedures-webapp
```

### 6. Test Deployment

```bash
# Test kustomize build
kustomize build gitops/overlays/prd

# Commit changes
git add .
git commit -m "Update image registry references to new Quay registry"
git push

# Sync ArgoCD application
oc login https://api.ocp-prd.kohlerco.com:6443
argocd app sync procurementapps-prd
```

## Troubleshooting

### Authentication Issues

```bash
# Check Docker config
cat ~/.docker/config.json

# Re-login to registries
oc registry login
podman login -u="procurementapps+robot" -p="TOKEN" kohler-registry-quay-quay.apps.ocp-host.kohlerco.com
```

### Registry Connectivity

```bash
# Test source registry
curl -k https://default-route-openshift-image-registry.apps.ocp4.kohlerco.com/v2/

# Test target registry
curl -k https://kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/v2/
```

### Image Not Found

```bash
# List available images in source
oc get imagestream -n procurementapps
oc get imagestream pm-procedures-webapp -n procurementapps -o yaml

# Check specific tag
oc describe imagestream pm-procedures-webapp -n procurementapps
```

## Registry Information

### Source Registry (OCP4)
- **Internal URL**: `image-registry.openshift-image-registry.svc:5000`
- **External URL**: `default-route-openshift-image-registry.apps.ocp4.kohlerco.com`
- **Authentication**: OpenShift user token

### Target Registry (Quay)
- **URL**: `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com`
- **Robot Account**: `procurementapps+robot`
- **Token**: `VH0781F461803O8TYUUWADVAZMEU2CV1CENXZ24O21F7EC8I1KSPMTRDZLEJLFTG`

## Post-Migration Checklist

- [ ] All required image tags migrated successfully
- [ ] GitOps configuration updated with new registry references
- [ ] Changes committed to Git repository
- [ ] ArgoCD application synced
- [ ] Application deployed and functional in target environment
- [ ] CI/CD pipelines updated to push to new registry
- [ ] Old images cleaned up (optional)

---

**Note**: Choose the migration method that works best with your available tools and environment constraints.
