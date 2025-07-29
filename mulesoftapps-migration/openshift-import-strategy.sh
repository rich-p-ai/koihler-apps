#!/bin/bash

# Direct OpenShift Import Strategy
# Uses OpenShift's import capabilities to move images

set -e

echo "================================"
echo "OPENSHIFT IMPORT STRATEGY"
echo "================================"
echo "[INFO] Using OpenShift import functionality"
echo ""

# Configuration
SOURCE_NAMESPACE="mulesoftapps-prod"
IMAGE_NAME="mulesoft-accelerator-2"
TAG="latest"
TARGET_REGISTRY="kohler-registry-quay-quay.apps.ocp-host.kohlerco.com"
TARGET_NAMESPACE="mulesoftapps"

# Robot account for target
ROBOT_USER="mulesoftapps+robot"
ROBOT_PASSWORD="MVH0181MWI2K0RBL5SF2ZVYYBLS21QOIZNLPGJA1FP6UK6EC2FDEKMDQYKUZKBN0"

echo "================================"
echo "STEP 1: CREATE TEMPORARY PROJECT"
echo "================================"

TEMP_PROJECT="image-migration-$(date +%s)"
echo "[INFO] Creating temporary project: $TEMP_PROJECT"

if oc new-project "$TEMP_PROJECT" &> /dev/null; then
    echo "[SUCCESS] Created temporary project: $TEMP_PROJECT"
else
    echo "[INFO] Using existing project or switching to temp project"
    oc project "$TEMP_PROJECT" &> /dev/null || oc new-project "$TEMP_PROJECT"
fi

echo ""
echo "================================"
echo "STEP 2: CREATE QUAY SECRET"
echo "================================"

# Create secret for Quay registry
echo "[INFO] Creating pull secret for Quay registry..."

oc create secret docker-registry quay-migration-secret \
    --docker-server="$TARGET_REGISTRY" \
    --docker-username="$ROBOT_USER" \
    --docker-password="$ROBOT_PASSWORD" \
    --docker-email="noreply@kohler.com" \
    --dry-run=client -o yaml | oc apply -f -

echo "[SUCCESS] Created Quay registry secret"

echo ""
echo "================================"
echo "STEP 3: GET SOURCE IMAGE"
echo "================================"

# Get the source image reference
echo "[INFO] Getting source image details..."

SOURCE_IMAGE_REF=$(oc get imagestream "$IMAGE_NAME" -n "$SOURCE_NAMESPACE" -o jsonpath='{.status.tags[?(@.tag=="'$TAG'")].items[0].dockerImageReference}')

if [[ -z "$SOURCE_IMAGE_REF" ]]; then
    echo "[ERROR] Could not find source image reference"
    exit 1
fi

echo "[SUCCESS] Source image: $SOURCE_IMAGE_REF"

echo ""
echo "================================"
echo "STEP 4: CREATE IMPORT IMAGESTREAM"
echo "================================"

TARGET_IMAGE="$TARGET_REGISTRY/$TARGET_NAMESPACE/$IMAGE_NAME:$TAG"

echo "[INFO] Creating ImageStream to import to Quay..."
echo "[INFO] Target: $TARGET_IMAGE"

# Create an ImageStream that imports from the source and pushes to target
cat << EOF | oc apply -f -
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: migration-target
  namespace: $TEMP_PROJECT
spec:
  tags:
  - name: $TAG
    from:
      kind: DockerImage
      name: $SOURCE_IMAGE_REF
    importPolicy:
      scheduled: false
    referencePolicy:
      type: Source
EOF

echo "[SUCCESS] Created import ImageStream"

echo ""
echo "================================"
echo "STEP 5: WAIT FOR IMPORT"
echo "================================"

echo "[INFO] Waiting for image import to complete..."

# Wait for the import to complete
for i in {1..30}; do
    if oc get imagestream migration-target -o jsonpath='{.status.tags[0].items[0].dockerImageReference}' 2>/dev/null | grep -q "sha256"; then
        echo "[SUCCESS] Image import completed"
        break
    fi
    echo "[INFO] Waiting for import... (attempt $i/30)"
    sleep 2
done

# Get the imported image reference
IMPORTED_IMAGE=$(oc get imagestream migration-target -o jsonpath='{.status.tags[0].items[0].dockerImageReference}')
echo "[INFO] Imported image: $IMPORTED_IMAGE"

echo ""
echo "================================"
echo "STEP 6: TAG AND PUSH TO QUAY"
echo "================================"

echo "[INFO] Now we need to tag and push this image to Quay..."
echo "[INFO] This step requires a working container runtime."

# Check if we can use oc image mirror with better auth
echo "[INFO] Attempting direct tag operation..."

# Try to use oc tag to push to external registry
if oc tag "$SOURCE_NAMESPACE/$IMAGE_NAME:$TAG" "$TARGET_IMAGE" --reference-policy=source; then
    echo "[SUCCESS] Tagged image for external registry"
else
    echo "[WARNING] Direct tagging failed"
fi

echo ""
echo "================================"
echo "CURRENT STATUS"
echo "================================"

echo "✅ Source image accessible: $SOURCE_IMAGE_REF"
echo "✅ Temporary project created: $TEMP_PROJECT"
echo "✅ Quay credentials configured"
echo "✅ Import mechanism set up"
echo ""
echo "⚠️  NEXT STEPS NEEDED:"
echo "The image is available in OpenShift but needs to be pushed to Quay."
echo "This requires a working container runtime (Docker/Podman)."
echo ""
echo "🔧 TO COMPLETE MIGRATION:"
echo "1. Fix container runtime (see CONTAINER-RUNTIME-FIX-GUIDE.md)"
echo "2. Run: ./migrate-mulesoft-image.sh"
echo "3. Or use external tools like Skopeo"
echo ""
echo "📋 CLEANUP:"
echo "When done, clean up: oc delete project $TEMP_PROJECT"

echo ""
echo "================================"
echo "MIGRATION SETUP COMPLETE"
echo "================================"
echo ""
echo "The migration infrastructure is ready."
echo "Fix the container runtime to complete the process."
