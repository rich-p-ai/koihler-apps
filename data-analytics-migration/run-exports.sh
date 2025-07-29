#!/bin/bash
echo "=== Running Data Export Jobs on OCP4 ==="

if ! oc whoami --show-server | grep -q "ocp4"; then
    echo "ERROR: Please login to OCP4 cluster first"
    echo "Run: oc login https://api.ocp4.kohlerco.com:6443"
    exit 1
fi

echo "Applying export jobs..."
for export_file in export-*.yaml; do
    if [[ -f "$export_file" ]]; then
        echo "Applying $export_file..."
        oc apply -f "$export_file"
    fi
done

echo ""
echo "Export jobs submitted. Monitor with:"
echo "oc get jobs -n data-analytics -l migration=data-analytics"
echo "oc logs -n data-analytics -l migration=data-analytics --follow"
