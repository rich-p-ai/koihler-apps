#!/bin/bash

# Complete PVC Data Migration Tool Generator
set -e

BACKUP_PATH="/tmp/data-analytics-pvc-migration"
SOURCE_NAMESPACE="data-analytics"

echo "=== CREATING COMPLETE PVC MIGRATION TOOLING ==="

# Ensure base directory exists
mkdir -p "$BACKUP_PATH/scripts"

# Get current PVC list
echo "Getting current PVC information..."
PVC_NAMES=$(oc get pvc -n "$SOURCE_NAMESPACE" --no-headers -o custom-columns=":metadata.name")

echo "Found PVCs: $PVC_NAMES"

# Create individual export jobs for each PVC
echo "Creating export job manifests..."
for PVC_NAME in $PVC_NAMES; do
    echo "Creating export job for: $PVC_NAME"
    
    cat > "$BACKUP_PATH/scripts/export-${PVC_NAME}.yaml" << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: export-${PVC_NAME}
  namespace: ${SOURCE_NAMESPACE}
  labels:
    migration: data-analytics
    pvc: ${PVC_NAME}
spec:
  template:
    metadata:
      labels:
        migration: data-analytics
        pvc: ${PVC_NAME}
    spec:
      restartPolicy: Never
      serviceAccountName: useroot
      securityContext:
        runAsUser: 0
        fsGroup: 0
      containers:
      - name: export
        image: registry.redhat.io/ubi8/ubi:latest
        command:
        - /bin/bash
        - -c
        - |
          echo "Starting export of PVC: ${PVC_NAME}"
          
          # Install required tools
          dnf install -y tar gzip
          
          # Check if source directory has data
          if [ -d "/source" ] && [ "\$(find /source -mindepth 1 -maxdepth 1 | wc -l)" -gt 0 ]; then
            echo "Data found in /source, creating archive..."
            cd /source
            tar -czf "/backup/${PVC_NAME}-data.tar.gz" .
            echo "Archive created: ${PVC_NAME}-data.tar.gz"
            echo "Archive size: \$(du -h /backup/${PVC_NAME}-data.tar.gz)"
          else
            echo "No data found in /source for ${PVC_NAME}"
            touch "/backup/${PVC_NAME}-empty.marker"
          fi
          
          echo "Export completed for PVC: ${PVC_NAME}"
        volumeMounts:
        - name: source-data
          mountPath: /source
        - name: backup-storage
          mountPath: /backup
      volumes:
      - name: source-data
        persistentVolumeClaim:
          claimName: ${PVC_NAME}
      - name: backup-storage
        persistentVolumeClaim:
          claimName: migration-backup-storage
---
EOF

    # Create corresponding import job
    cat > "$BACKUP_PATH/scripts/import-${PVC_NAME}.yaml" << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: import-${PVC_NAME}
  namespace: ${SOURCE_NAMESPACE}
  labels:
    migration: data-analytics
    pvc: ${PVC_NAME}
spec:
  template:
    metadata:
      labels:
        migration: data-analytics
        pvc: ${PVC_NAME}
    spec:
      restartPolicy: Never
      serviceAccountName: useroot
      securityContext:
        runAsUser: 0
        fsGroup: 0
      containers:
      - name: import
        image: registry.redhat.io/ubi8/ubi:latest
        command:
        - /bin/bash
        - -c
        - |
          echo "Starting import for PVC: ${PVC_NAME}"
          
          # Install required tools
          dnf install -y tar gzip
          
          # Check for data archive
          if [ -f "/backup/${PVC_NAME}-data.tar.gz" ]; then
            echo "Found data archive, extracting..."
            cd /target
            tar -xzf "/backup/${PVC_NAME}-data.tar.gz"
            echo "Data extracted to /target"
          elif [ -f "/backup/${PVC_NAME}-empty.marker" ]; then
            echo "PVC ${PVC_NAME} was empty, no data to restore"
          else
            echo "No backup file found for ${PVC_NAME}"
          fi
          
          echo "Import completed for PVC: ${PVC_NAME}"
        volumeMounts:
        - name: target-data
          mountPath: /target
        - name: backup-storage
          mountPath: /backup
      volumes:
      - name: target-data
        persistentVolumeClaim:
          claimName: ${PVC_NAME}
      - name: backup-storage
        persistentVolumeClaim:
          claimName: migration-backup-storage
---
EOF

done

# Create backup storage for target cluster
cat > "$BACKUP_PATH/scripts/target-backup-storage.yaml" << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: migration-backup-storage
  namespace: data-analytics
  labels:
    migration: data-analytics
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: ocs-storagecluster-cephfs
---
EOF

# Create execution scripts
echo "Creating execution scripts..."

cat > "$BACKUP_PATH/scripts/run-exports.sh" << 'EOF'
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
EOF

cat > "$BACKUP_PATH/scripts/run-imports.sh" << 'EOF'
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
EOF

# Make scripts executable
chmod +x "$BACKUP_PATH/scripts/run-exports.sh"
chmod +x "$BACKUP_PATH/scripts/run-imports.sh"

# Create migration guide
cat > "$BACKUP_PATH/PVC-MIGRATION-GUIDE.md" << EOF
# í³¦ PVC Data Migration Guide

## Overview
- **Date**: $(date)
- **Source**: OCP4 ($(oc whoami --show-server))
- **Target**: OCP-PRD
- **Namespace**: data-analytics
- **PVCs**: $(echo $PVC_NAMES | wc -w) total

## PVC List
\`\`\`
$(oc get pvc -n data-analytics)
\`\`\`

## Migration Steps

### 1. Export Data from OCP4
\`\`\`bash
cd $BACKUP_PATH/scripts
./run-exports.sh
\`\`\`

### 2. Monitor Export Progress
\`\`\`bash
oc get jobs -n data-analytics -l migration=data-analytics
oc logs -n data-analytics -l migration=data-analytics --follow
\`\`\`

### 3. Switch to OCP-PRD and Import
\`\`\`bash
oc login https://api.ocp-prd.kohlerco.com:6443
cd $BACKUP_PATH/scripts  
./run-imports.sh
\`\`\`

### 4. Verify Migration
\`\`\`bash
oc get pods -n data-analytics
# Check if applications can access the data
\`\`\`

## Files Generated
$(ls -1 $BACKUP_PATH/scripts/)

**Ready to migrate!** íº€
EOF

echo ""
echo "âœ… Complete PVC migration tooling created!"
echo "í³ Location: $BACKUP_PATH"
echo "í³‹ Guide: $BACKUP_PATH/PVC-MIGRATION-GUIDE.md"
echo ""
echo "Next steps:"
echo "1. cd $BACKUP_PATH/scripts"
echo "2. ./run-exports.sh (on OCP4)"
echo "3. Switch to OCP-PRD and ./run-imports.sh"

