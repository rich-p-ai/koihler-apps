#!/bin/bash

# Direct Image Migration Script using oc image mirror
# Uses internal registry routes and proper authentication

set -e

echo "================================"
echo "INTERNAL REGISTRY MIGRATION"
echo "================================"
echo "[INFO] Using internal registry routes and oc image mirror"
echo ""

# Configuration
INTERNAL_REGISTRY="image-registry.openshift-image-registry.svc:5000"
TARGET_REGISTRY="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
SOURCE_NAMESPACE="mulesoftapps-prod"
TARGET_NAMESPACE="mulesoftapps"
IMAGE_NAME="mulesoft-accelerator-2"
TAG="latest"

# Robot account for target
ROBOT_USER="mulesoftapps+robot"
ROBOT_PASSWORD="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0"

echo "================================"
echo "STEP 1: VERIFY PREREQUISITES"
echo "================================"

# Check if oc is available and logged in
if ! command -v oc &> /dev/null; then
    echo "[ERROR] OpenShift CLI (oc) not found"
    exit 1
fi

if ! oc whoami &> /dev/null; then
    echo "[ERROR] Not logged into OpenShift cluster"
    echo "[INFO] Run: oc login --server=https://api.ocpaz.kohlerco.com:6443"
    exit 1
fi

echo "[SUCCESS] OpenShift CLI available: $(oc version --client | head -1)"
echo "[SUCCESS] Logged in as: $(oc whoami)"

echo ""
echo "================================"
echo "STEP 2: GET SOURCE IMAGE INFO"
echo "================================"

# Verify image exists
if ! oc get imagestream "$IMAGE_NAME" -n "$SOURCE_NAMESPACE" &> /dev/null; then
    echo "[ERROR] ImageStream '$IMAGE_NAME' not found in namespace '$SOURCE_NAMESPACE'"
    exit 1
fi

echo "[SUCCESS] Found ImageStream: $IMAGE_NAME"

# Get the specific image SHA that we found earlier
IMAGE_SHA="image-registry.openshift-image-registry.svc:5000/mulesoftapps-prod/mulesoft-accelerator-2@sha256:a25f221dc46e0c2ea60924e0cd68492fd6c27ed742f2c058ad1c8e152384c7c6"

echo "[SUCCESS] Source image: $IMAGE_SHA"

echo ""
echo "================================"
echo "STEP 3: CREATE TARGET AUTH"
echo "================================"

# Create a temporary auth config with just the target registry
AUTH_CONFIG=$(mktemp)
cat > "$AUTH_CONFIG" << EOF
{
  "auths": {
    "$TARGET_REGISTRY": {
      "username": "$ROBOT_USER",
      "password": "$ROBOT_PASSWORD",
      "auth": "$(echo -n "$ROBOT_USER:$ROBOT_PASSWORD" | base64 -w 0)"
    }
  }
}
EOF

echo "[SUCCESS] Created authentication config for target registry"
echo "[INFO] Target registry: $TARGET_REGISTRY"

echo ""
echo "================================"
echo "STEP 4: MIGRATE IMAGE"
echo "================================"

# Define target
TARGET_IMAGE="$TARGET_REGISTRY/$TARGET_NAMESPACE/$IMAGE_NAME:$TAG"

echo "[INFO] Source: $IMAGE_SHA"
echo "[INFO] Target: $TARGET_IMAGE"
echo ""

# Use oc image mirror with the internal source
echo "[INFO] Starting image migration (this may take a few minutes)..."

if oc image mirror \
    "$IMAGE_SHA" \
    "$TARGET_IMAGE" \
    --registry-config="$AUTH_CONFIG" \
    --insecure=true; then
    
    echo ""
    echo "================================"
    echo "✅ MIGRATION SUCCESSFUL!"
    echo "================================"
    echo "[SUCCESS] Image migrated successfully!"
    echo "[SUCCESS] Source: $IMAGE_SHA"
    echo "[SUCCESS] Target: $TARGET_IMAGE"
    echo ""
    echo "🎉 Your mulesoft-accelerator-2 image is now available in Quay!"
    echo ""
    echo "📋 Verification steps:"
    echo "   1. Check Quay UI: https://kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
    echo "   2. Navigate to mulesoftapps organization"
    echo "   3. Look for mulesoft-accelerator-2 repository"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Update deployment configs to use new registry"
    echo "   2. Test image pull: podman pull $TARGET_IMAGE"
    echo "   3. Verify application functionality"
    
else
    echo ""
    echo "================================"
    echo "❌ MIGRATION FAILED"
    echo "================================"
    echo "[ERROR] Image migration failed"
    echo "[INFO] Common issues and solutions:"
    echo "   1. Robot account credentials incorrect"
    echo "   2. Robot account lacks push permissions to mulesoftapps namespace"
    echo "   3. Network connectivity issues"
    echo "   4. Quay registry configuration problems"
    echo ""
    echo "🔧 Debug steps:"
    echo "   1. Verify robot credentials in Quay UI"
    echo "   2. Check robot permissions in mulesoftapps organization"
    echo "   3. Test manual login: podman login $TARGET_REGISTRY"
fi

# Clean up
rm -f "$AUTH_CONFIG"

echo ""
echo "================================"
echo "MIGRATION PROCESS COMPLETE"
echo "================================"
