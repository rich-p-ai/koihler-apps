#!/bin/bash
# Run this script on OCP4 cluster to export PVC data

SOURCE_NAMESPACE="data-analytics"
EXPORT_DIR="/tmp/pvc-exports"

mkdir -p "$EXPORT_DIR"

# PVCs to export
PVCS=("cdh-callfinder-vol01" "nfspvcdataanalyticsdata01" "sci-scorecard-dev-vol01" "sftp-analytics-01" "sftp-analytics-data01" "sftp-datalake-01" "sftp-datalake-data01")

for pvc in "${PVCS[@]}"; do
    echo "Exporting data from PVC: $pvc"
    
    # Create export pod
    cat << YAML | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: export-${pvc}
  namespace: ${SOURCE_NAMESPACE}
spec:
  serviceAccountName: useroot
  containers:
  - name: exporter
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
    oc wait --for=condition=Ready pod/export-${pvc} -n ${SOURCE_NAMESPACE} --timeout=300s
    
    # Create tar archive of the data
    echo "Creating archive for $pvc..."
    oc exec export-${pvc} -n ${SOURCE_NAMESPACE} -- tar -czf /tmp/${pvc}-data.tar.gz -C /data .
    
    # Copy archive to local machine
    oc cp ${SOURCE_NAMESPACE}/export-${pvc}:/tmp/${pvc}-data.tar.gz ${EXPORT_DIR}/${pvc}-data.tar.gz
    
    # Clean up export pod
    oc delete pod export-${pvc} -n ${SOURCE_NAMESPACE}
    
    echo "Export completed for $pvc - archive saved to ${EXPORT_DIR}/${pvc}-data.tar.gz"
done

echo "All PVC data exported to $EXPORT_DIR"
