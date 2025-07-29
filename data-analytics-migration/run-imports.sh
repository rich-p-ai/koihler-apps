#!/bin/bash
echo "=== Running Data Import Jobs on OCP-PRD ==="

if ! oc whoami --show-server | grep -q "ocp-prd"; then
    echo "ERROR: Please login to OCP-PRD cluster first"  
    echo "Run: oc login https://api.ocp-prd.kohlerco.com:6443"
    exit 1
fi

echo "Creating backup storage on target cluster..."
oc apply -f target-backup-storage.yaml

echo "Waiting for backup storage to bind..."
oc wait --for=condition=Bound pvc/migration-backup-storage -n data-analytics --timeout=300s

echo "Applying import jobs..."
for import_file in import-*.yaml; do
    if [[ -f "$import_file" ]]; then
        echo "Applying $import_file..."
        oc apply -f "$import_file"
    fi
done

echo ""
echo "Import jobs submitted. Monitor with:"
echo "oc get jobs -n data-analytics -l migration=data-analytics"
echo "oc logs -n data-analytics -l migration=data-analytics --follow"
