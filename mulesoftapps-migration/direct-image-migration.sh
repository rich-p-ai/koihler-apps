#!/bin/bash

# Direct Image Migration Script using oc image mirror
# This bypasses container runtime issues and uses OpenShift's native tools

set -e

echo "================================"
echo "DIRECT MULESOFT IMAGE MIGRATION"
echo "================================"
echo "[INFO] Using oc image mirror for direct registry-to-registry transfer"
echo "[INFO] Source: OCPAZ internal registry"
echo "[INFO] Target: Quay registry"
echo ""

# Configuration
SOURCE_REGISTRY="default-route-openshift-image-registry.apps.ocpaz.kohlerco.com"
TARGET_REGISTRY="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
SOURCE_NAMESPACE="mulesoftapps-prod"
TARGET_NAMESPACE="mulesoftapps"
IMAGE_NAME="mulesoft-accelerator-2"
TAG="latest"

# Service account token for source
SERVICE_TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6Im82WHdoYl9oZ3NTMm1SUWRSV2hWSUxvQ3V5Q2Q3Qm85eGhtTkZtblA5SlEifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJtdWxlc29mdGFwcHMtcHJvZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkZWZhdWx0LXRva2VuLTh2ZzUyIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImRlZmF1bHQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJkNDU4ZTVjNi1kNGFiLTQwYzItYTBlNi1iZGU5YzM4M2UxN2IiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6bXVsZXNvZnRhcHBzLXByb2Q6ZGVmYXVsdCJ9.E_RN5gE3oePrmQlIFgWUhMYFOpvCVaAp7d3JMlHqRuOIzWnDpOPMrGzfnXTF2ZV5QmLLZVzUQvJSGvJFSGp8qIatyI-ZVhV3wqvKR_m3S5zM7G4cBpE5q3tG4fUV0g7GjRyN_fFz8xwOtFVbF8NGP6G9gB-rL2X4j8CkGpM_j6Q5OdSXoZVwz3vP5jI2yF_LGNzBV9rWxF7zVvP8H_yGU6Fc4rK8j3r2pL-4OdZGz7B_VqzWxTfV9r6YPjLz3xU"

# Robot account for target
ROBOT_USER="mulesoftapps+robot"
ROBOT_PASSWORD="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0"

echo "================================"
echo "STEP 1: VERIFY PREREQUISITES"
echo "================================"

# Check if oc is available
if ! command -v oc &> /dev/null; then
    echo "[ERROR] OpenShift CLI (oc) not found"
    exit 1
fi

echo "[SUCCESS] OpenShift CLI available: $(oc version --client | head -1)"

# Check if logged in
if ! oc whoami &> /dev/null; then
    echo "[ERROR] Not logged into OpenShift cluster"
    echo "[INFO] Run: oc login --server=https://api.ocpaz.kohlerco.com:6443"
    exit 1
fi

echo "[SUCCESS] Logged in as: $(oc whoami)"
echo "[SUCCESS] Connected to: $(oc whoami --show-server)"

echo ""
echo "================================"
echo "STEP 2: GET SOURCE IMAGE INFO"
echo "================================"

# Get the image SHA from the imagestream
echo "[INFO] Looking up image SHA for: $IMAGE_NAME:$TAG"

if ! oc get imagestream "$IMAGE_NAME" -n "$SOURCE_NAMESPACE" &> /dev/null; then
    echo "[ERROR] ImageStream '$IMAGE_NAME' not found in namespace '$SOURCE_NAMESPACE'"
    exit 1
fi

echo "[SUCCESS] Found ImageStream: $IMAGE_NAME"

# Get the image SHA
IMAGE_SHA=$(oc get imagestream "$IMAGE_NAME" -n "$SOURCE_NAMESPACE" -o jsonpath='{.status.tags[?(@.tag=="'$TAG'")].items[0].dockerImageReference}')

if [[ -z "$IMAGE_SHA" ]]; then
    echo "[ERROR] Could not find SHA for tag: $TAG"
    echo "[INFO] Available tags:"
    oc get imagestream "$IMAGE_NAME" -n "$SOURCE_NAMESPACE" -o jsonpath='{.status.tags[*].tag}' | tr ' ' '\n'
    exit 1
fi

echo "[SUCCESS] Source image: $IMAGE_SHA"

echo ""
echo "================================"
echo "STEP 3: CREATE AUTH CONFIG"
echo "================================"

# Create a temporary auth config file
AUTH_CONFIG=$(mktemp)
cat > "$AUTH_CONFIG" << EOF
{
  "auths": {
    "$SOURCE_REGISTRY": {
      "username": "serviceaccount",
      "password": "$SERVICE_TOKEN",
      "auth": "$(echo -n "serviceaccount:$SERVICE_TOKEN" | base64 -w 0)"
    },
    "$TARGET_REGISTRY": {
      "username": "$ROBOT_USER",
      "password": "$ROBOT_PASSWORD",
      "auth": "$(echo -n "$ROBOT_USER:$ROBOT_PASSWORD" | base64 -w 0)"
    }
  }
}
EOF

echo "[SUCCESS] Created authentication config"
echo "[INFO] Source registry: $SOURCE_REGISTRY"
echo "[INFO] Target registry: $TARGET_REGISTRY"

echo ""
echo "================================"
echo "STEP 4: MIGRATE IMAGE"
echo "================================"

# Define source and target
SOURCE_IMAGE="$SOURCE_REGISTRY/$SOURCE_NAMESPACE/$IMAGE_NAME:$TAG"
TARGET_IMAGE="$TARGET_REGISTRY/$TARGET_NAMESPACE/$IMAGE_NAME:$TAG"

echo "[INFO] Source: $SOURCE_IMAGE"
echo "[INFO] Target: $TARGET_IMAGE"
echo ""
echo "[INFO] Starting image migration..."

# Perform the migration
if oc image mirror \
    "$SOURCE_IMAGE" \
    "$TARGET_IMAGE" \
    --registry-config="$AUTH_CONFIG" \
    --insecure=true \
    --force=true; then
    
    echo ""
    echo "================================"
    echo "✅ MIGRATION SUCCESSFUL!"
    echo "================================"
    echo "[SUCCESS] Image migrated successfully!"
    echo "[SUCCESS] Source: $SOURCE_IMAGE"
    echo "[SUCCESS] Target: $TARGET_IMAGE"
    echo ""
    echo "🎉 Your mulesoft-accelerator-2 image is now available in Quay!"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Verify the image in Quay UI: https://kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
    echo "   2. Update your deployments to use the new Quay registry"
    echo "   3. Test the image pull from the new location"
    
else
    echo ""
    echo "================================"
    echo "❌ MIGRATION FAILED"
    echo "================================"
    echo "[ERROR] Image migration failed"
    echo "[INFO] Check the error messages above for details"
    echo ""
    echo "🔧 Troubleshooting tips:"
    echo "   1. Verify registry authentication"
    echo "   2. Check network connectivity to both registries"
    echo "   3. Ensure robot account has push permissions"
    echo "   4. Try the container-based migration: ./migrate-mulesoft-image.sh"
fi

# Clean up
rm -f "$AUTH_CONFIG"

echo ""
echo "================================"
echo "MIGRATION COMPLETE"
echo "================================"
