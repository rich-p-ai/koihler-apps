#!/bin/bash
# Run this script on OCP-PRD cluster to import PVC data

TARGET_NAMESPACE="data-analytics"
IMPORT_DIR="/tmp/pvc-exports"

# PVCs to import
PVCS=("cdh-callfinder-vol01" "nfspvcdataanalyticsdata01" "sci-scorecard-dev-vol01" "sftp-analytics-01" "sftp-analytics-data01" "sftp-datalake-01" "sftp-datalake-data01")

for pvc in "${PVCS[@]}"; do
    if [ ! -f "${IMPORT_DIR}/${pvc}-data.tar.gz" ]; then
        echo "Archive not found for $pvc, skipping..."
        continue
    fi
    
    echo "Importing data to PVC: $pvc"
    
    # Create import pod
    cat << YAML | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: import-${pvc}
  namespace: ${TARGET_NAMESPACE}
spec:
  serviceAccountName: useroot
  securityContext:
    runAsUser: 0
    fsGroup: 0
  containers:
  - name: importer
    image: registry.redhat.io/ubi8/ubi:latest
    command: ["/bin/sleep", "3600"]
    volumeMounts:
    - name: data-volume
      mountPath: /data
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: ${pvc}
  restartPolicy: Never
YAML

    # Wait for pod to be ready
    oc wait --for=condition=Ready pod/import-${pvc} -n ${TARGET_NAMESPACE} --timeout=300s
    
    # Copy archive to pod
    oc cp ${IMPORT_DIR}/${pvc}-data.tar.gz ${TARGET_NAMESPACE}/import-${pvc}:/tmp/${pvc}-data.tar.gz
    
    # Extract archive
    echo "Extracting data for $pvc..."
    oc exec import-${pvc} -n ${TARGET_NAMESPACE} -- tar -xzf /tmp/${pvc}-data.tar.gz -C /data
    
    # Verify extraction
    oc exec import-${pvc} -n ${TARGET_NAMESPACE} -- ls -la /data
    
    # Clean up import pod
    oc delete pod import-${pvc} -n ${TARGET_NAMESPACE}
    
    echo "Import completed for $pvc"
done

echo "All PVC data imported"
