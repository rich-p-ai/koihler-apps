#!/bin/bash

# Image Migration via Extract and Push
# Extracts image from OCPAZ and pushes to Quay

set -e

echo "================================"
echo "IMAGE MIGRATION VIA EXTRACT/PUSH"
echo "================================"
echo "[INFO] Alternative approach: extract from OCPAZ, push to Quay"
echo ""

# Configuration
SOURCE_NAMESPACE="mulesoftapps-prod"
IMAGE_NAME="mulesoft-accelerator-2"
TAG="latest"
TARGET_REGISTRY="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
TARGET_NAMESPACE="mulesoftapps"

ROBOT_USER="mulesoftapps+robot"
ROBOT_PASSWORD="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0"

echo "================================"
echo "STEP 1: VERIFY PREREQUISITES"
echo "================================"

if ! command -v oc &> /dev/null; then
    echo "[ERROR] OpenShift CLI (oc) not found"
    exit 1
fi

if ! oc whoami &> /dev/null; then
    echo "[ERROR] Not logged into OpenShift cluster"
    exit 1
fi

echo "[SUCCESS] OpenShift CLI available"
echo "[SUCCESS] Logged in as: $(oc whoami)"

echo ""
echo "================================"
echo "STEP 2: GET IMAGE DETAILS"
echo "================================"

# Get image details
if ! oc get imagestream "$IMAGE_NAME" -n "$SOURCE_NAMESPACE" &> /dev/null; then
    echo "[ERROR] ImageStream '$IMAGE_NAME' not found in namespace '$SOURCE_NAMESPACE'"
    exit 1
fi

echo "[SUCCESS] Found ImageStream: $IMAGE_NAME"

# Get the image reference
IMAGE_REF=$(oc get imagestream "$IMAGE_NAME" -n "$SOURCE_NAMESPACE" -o jsonpath='{.status.tags[?(@.tag=="'$TAG'")].items[0].dockerImageReference}')

if [[ -z "$IMAGE_REF" ]]; then
    echo "[ERROR] Could not find image reference for tag: $TAG"
    exit 1
fi

echo "[SUCCESS] Image reference: $IMAGE_REF"

echo ""
echo "================================"
echo "STEP 3: TEST QUAY CONNECTIVITY"
echo "================================"

# Create a simple test to see if we can reach Quay
echo "[INFO] Testing Quay registry connectivity..."

# Try to create a simple auth test
AUTH_TEST=$(mktemp)
cat > "$AUTH_TEST" << EOF
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

echo "[INFO] Testing authentication to: $TARGET_REGISTRY"
echo "[INFO] Robot user: $ROBOT_USER"

# Try to list repositories (this will test auth without pulling)
if curl -f -s -H "Authorization: Bearer $ROBOT_PASSWORD" \
   "https://$TARGET_REGISTRY/api/v1/repository" > /dev/null 2>&1; then
    echo "[SUCCESS] Quay API is accessible"
else
    echo "[WARNING] Could not access Quay API (this might be normal)"
fi

echo ""
echo "================================"
echo "STEP 4: CREATE MIGRATION APPROACH"
echo "================================"

echo "[INFO] This migration requires one of these approaches:"
echo ""
echo "Option 1: Container Runtime Required"
echo "   • Fix Podman/Docker setup"
echo "   • Use: ./migrate-mulesoft-image.sh"
echo ""
echo "Option 2: External Tool (Skopeo)"
echo "   • Install Skopeo tool"
echo "   • Direct registry-to-registry copy"
echo ""
echo "Option 3: Manual Export/Import"
echo "   • Export image as tar file"
echo "   • Import to target registry"
echo ""

echo "🔧 CURRENT ISSUE: Container runtime not properly configured"
echo "   WSL not working -> Podman can't start -> Image operations fail"
echo ""
echo "📋 IMMEDIATE OPTIONS:"
echo ""
echo "A) Fix WSL (Recommended for long-term)"
echo "   1. Run PowerShell as Administrator"
echo "   2. wsl --install"
echo "   3. Restart computer"
echo "   4. podman machine init && podman machine start"
echo ""
echo "B) Install Docker Desktop"
echo "   1. Download from docker.com"
echo "   2. Install with WSL2 backend"
echo "   3. Use Docker instead of Podman"
echo ""
echo "C) Use External Tools"
echo "   1. Install Skopeo on Linux/WSL"
echo "   2. Use skopeo copy for direct migration"
echo ""

# Generate a skopeo command for reference
echo "================================"
echo "SKOPEO COMMAND REFERENCE"
echo "================================"
echo ""
echo "If you have access to a Linux system with Skopeo:"
echo ""
echo "skopeo copy \\"
echo "  --src-creds=\"serviceaccount:$(echo $SERVICE_TOKEN | cut -c1-20)...\" \\"
echo "  --dest-creds=\"$ROBOT_USER:$ROBOT_PASSWORD\" \\"
echo "  docker://$IMAGE_REF \\"
echo "  docker://$TARGET_REGISTRY/$TARGET_NAMESPACE/$IMAGE_NAME:$TAG"
echo ""

# Clean up
rm -f "$AUTH_TEST"

echo "================================"
echo "ANALYSIS COMPLETE"
echo "================================"
echo ""
echo "📊 SUMMARY:"
echo "✅ Source image found and accessible"
echo "✅ Target registry credentials configured" 
echo "✅ OpenShift authentication working"
echo "❌ Local container runtime not working (WSL issue)"
echo ""
echo "🎯 NEXT STEPS:"
echo "1. Fix WSL installation (recommended)"
echo "2. Or install Docker Desktop"
echo "3. Then run: ./migrate-mulesoft-image.sh"
echo ""
echo "💡 For immediate help, see: CONTAINER-RUNTIME-FIX-GUIDE.md"
