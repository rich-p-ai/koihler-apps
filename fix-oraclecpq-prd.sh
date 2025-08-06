#!/bin/bash
# Fix OracleCPQ-PRD configuration for OCP-PRD deployment
# This script updates OCP4 references to OCP-PRD equivalents

set -e

OVERLAY_DIR="c:/work/OneDrive - Kohler Co/Openshift/git/koihler-apps/oraclecpq-prd/overlays/prd"

echo "🔧 Fixing OracleCPQ-PRD configuration for OCP-PRD deployment..."

# Fix route domains
echo "📍 Updating route domains..."
sed -i 's/apps\.ocp4\.kohlerco\.com/apps.ocp-prd.kohlerco.com/g' "$OVERLAY_DIR/routes.yaml"
sed -i 's/router-default\.apps\.ocp4\.kohlerco\.com/router-default.apps.ocp-prd.kohlerco.com/g' "$OVERLAY_DIR/routes.yaml"

# Fix image registry references
echo "🐳 Updating image registry references..."
sed -i 's/image-registry\.openshift-image-registry\.svc:5000\/oraclecpq\//quay.io\/kohlerco\/oraclecpq\//g' "$OVERLAY_DIR/deployments.yaml"

# Fix imagestream registry references
echo "🖼️ Updating imagestream registry references..."
sed -i 's/default-route-openshift-image-registry\.apps\.ocp4\.kohlerco\.com\/oraclecpq\//quay.io\/kohlerco\/oraclecpq\//g' "$OVERLAY_DIR/imagestreams.yaml"

# Fix service account secret references
echo "🔐 Updating service account secrets..."
sed -i 's/builder-quay-openshiftocp4/builder-quay-ocp-prd/g' "$OVERLAY_DIR/serviceaccounts.yaml"
sed -i 's/default-quay-openshiftocp4/default-quay-ocp-prd/g' "$OVERLAY_DIR/serviceaccounts.yaml"
sed -i 's/deployer-quay-openshiftocp4/deployer-quay-ocp-prd/g' "$OVERLAY_DIR/serviceaccounts.yaml"

# Fix secret names
echo "🔑 Updating secret names..."
sed -i 's/builder-quay-openshiftocp4/builder-quay-ocp-prd/g' "$OVERLAY_DIR/secrets.yaml"
sed -i 's/default-quay-openshiftocp4/default-quay-ocp-prd/g' "$OVERLAY_DIR/secrets.yaml"
sed -i 's/deployer-quay-openshiftocp4/deployer-quay-ocp-prd/g' "$OVERLAY_DIR/secrets.yaml"

# Clean up runtime metadata from all files
echo "🧹 Cleaning up runtime metadata..."
for file in "$OVERLAY_DIR"/*.yaml; do
    if [[ -f "$file" ]]; then
        # Remove runtime metadata
        sed -i '/creationTimestamp:/d' "$file"
        sed -i '/resourceVersion:/d' "$file"
        sed -i '/uid:/d' "$file"
        sed -i '/generation:/d' "$file"
        sed -i '/finalizers:/d' "$file"
        sed -i '/managedFields:/d' "$file"
        sed -i '/status:/,/^[[:space:]]*[^[:space:]]/d' "$file"
        
        # Remove specific annotations that are runtime-specific
        sed -i '/pv\.kubernetes\.io\/bind-completed/d' "$file"
        sed -i '/pv\.kubernetes\.io\/bound-by-controller/d' "$file"
        sed -i '/volume\.beta\.kubernetes\.io\/storage-provisioner/d' "$file"
        sed -i '/kubectl\.kubernetes\.io\/last-applied-configuration/d' "$file"
    fi
done

echo "✅ OracleCPQ-PRD configuration updated for OCP-PRD deployment!"
echo ""
echo "Key changes made:"
echo "  📍 Routes: *.apps.ocp4.kohlerco.com → *.apps.ocp-prd.kohlerco.com"
echo "  🐳 Images: image-registry.openshift-image-registry.svc:5000 → quay.io/kohlerco"
echo "  🖼️ ImageStreams: default-route-openshift-image-registry.apps.ocp4.kohlerco.com → quay.io/kohlerco"
echo "  🔐 Secrets: *-quay-openshiftocp4 → *-quay-ocp-prd"
echo "  🧹 Metadata: Removed runtime-specific metadata"
echo ""
echo "Next steps:"
echo "  1. Review the changes"
echo "  2. Commit and push to repository"
echo "  3. Deploy with ArgoCD: oc apply -f applications/oraclecpq-prd.yaml"
