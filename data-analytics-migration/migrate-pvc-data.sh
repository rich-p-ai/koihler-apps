#!/bin/bash

# PVC Data Migration Script for Data Analytics
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m' 
BLUE='\033[0;34m'
NC='\033[0m'

# Migration parameters
SOURCE_NAMESPACE="data-analytics"
TARGET_NAMESPACE="data-analytics"
BACKUP_PATH="/tmp/data-analytics-pvc-migration"

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    if ! command -v oc &> /dev/null; then
        print_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
    
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login'"
        exit 1
    fi
    
    CURRENT_SERVER=$(oc whoami --show-server)
    print_info "Current cluster: $CURRENT_SERVER"
    
    if [[ "$CURRENT_SERVER" != *"ocp4"* ]]; then
        print_error "Please run this script while logged into OCP4 cluster"
        print_info "Run: oc login https://api.ocp4.kohlerco.com:6443"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Get PVC information
get_pvc_info() {
    print_section "ANALYZING PVCS"
    
    # Create backup directory structure
    mkdir -p "$BACKUP_PATH/exports"
    mkdir -p "$BACKUP_PATH/scripts"
    
    # Get PVC list and details
    oc get pvc -n "$SOURCE_NAMESPACE" -o json > "$BACKUP_PATH/pvc-info.json"
    
    print_info "Found the following PVCs:"
    oc get pvc -n "$SOURCE_NAMESPACE" --no-headers | while read pvc status volume capacity access storageclass age; do
        print_info "- $pvc ($capacity, $storageclass)"
    done
}

# Create backup storage PVC
create_backup_storage() {
    print_section "CREATING BACKUP STORAGE"
    
    cat > "$BACKUP_PATH/scripts/backup-storage.yaml" << 'EOF'
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
  storageClassName: ocs-external-storagecluster-cephfs
EOF
    
    print_info "Creating backup storage PVC on source cluster..."
    oc apply -f "$BACKUP_PATH/scripts/backup-storage.yaml"
    
    print_success "Backup storage configuration created"
}

print_section "PVC DATA MIGRATION PREPARATION"
print_info "Preparing data migration for data-analytics namespace"
print_info "Backup location: $BACKUP_PATH"

check_prerequisites
get_pvc_info
create_backup_storage

print_section "BASIC SETUP COMPLETED"
print_success "í¾‰ Basic PVC migration setup completed!"
print_info "í³ Files created in: $BACKUP_PATH"
print_info "Next: Run the full script for complete migration tooling"

