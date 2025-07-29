#!/bin/bash
# Namespace Backup Setup Script for GitOps Repository
# This script creates the initial GitHub repository structure and ArgoCD configuration
# for backing up a Kubernetes namespace using GitOps methodology
# Created: July 29, 2025

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - MODIFY THESE VALUES
SOURCE_CLUSTER="https://api.ocp-prd.kohlerco.com:6443"
SOURCE_NAMESPACE=""  # Will be prompted if not set
GITHUB_REPO_URL=""   # Will be prompted if not set
GITHUB_REPO_NAME=""  # Will be prompted if not set
ARGOCD_NAMESPACE="openshift-gitops"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Directory structure
BACKUP_DIR="backup"
GITOPS_DIR="gitops"
SCRIPTS_DIR="scripts"

# Logging functions
print_section() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Prompt for configuration if not set
prompt_configuration() {
    print_section "CONFIGURATION SETUP"
    
    if [[ -z "$SOURCE_NAMESPACE" ]]; then
        read -p "Enter the namespace to backup: " SOURCE_NAMESPACE
    fi
    
    if [[ -z "$GITHUB_REPO_URL" ]]; then
        read -p "Enter GitHub repository URL (e.g., https://github.com/user/repo.git): " GITHUB_REPO_URL
    fi
    
    if [[ -z "$GITHUB_REPO_NAME" ]]; then
        read -p "Enter GitHub repository name (e.g., namespace-backup): " GITHUB_REPO_NAME
    fi
    
    print_info "Configuration:"
    print_info "  Source Namespace: $SOURCE_NAMESPACE"
    print_info "  GitHub Repository: $GITHUB_REPO_URL"
    print_info "  Repository Name: $GITHUB_REPO_NAME"
    
    read -p "Continue with this configuration? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_error "Configuration cancelled"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    # Check if oc is installed
    if ! command -v oc &> /dev/null; then
        print_error "OpenShift CLI (oc) is not installed"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        print_error "git is not installed"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create directory structure
create_directories() {
    print_section "CREATING DIRECTORY STRUCTURE"
    
    mkdir -p "$BACKUP_DIR/raw"
    mkdir -p "$BACKUP_DIR/cleaned"
    mkdir -p "$BACKUP_DIR/manifests"
    mkdir -p "$GITOPS_DIR/base"
    mkdir -p "$GITOPS_DIR/overlays/prd"
    mkdir -p "$SCRIPTS_DIR"
    
    print_success "Directory structure created"
}

# Login to source cluster
login_to_cluster() {
    print_section "CLUSTER LOGIN"
    
    print_info "Logging into source cluster: $SOURCE_CLUSTER"
    print_info "Please provide your credentials when prompted"
    
    oc login "$SOURCE_CLUSTER" || {
        print_error "Failed to login to source cluster"
        exit 1
    }
    
    # Verify namespace exists
    if ! oc get namespace "$SOURCE_NAMESPACE" &>/dev/null; then
        print_error "Namespace '$SOURCE_NAMESPACE' not found on source cluster"
        exit 1
    fi
    
    print_success "Successfully logged into source cluster"
    print_info "Using namespace: $SOURCE_NAMESPACE"
}

# Export all resources from source namespace
export_resources() {
    print_section "EXPORTING RESOURCES FROM NAMESPACE"
    
    local raw_dir="$BACKUP_DIR/raw"
    
    print_info "Exporting all resources from namespace '$SOURCE_NAMESPACE'..."
    
    # Export different resource types
    local resource_types=(
        "configmaps"
        "secrets"
        "services"
        "serviceaccounts"
        "deployments"
        "deploymentconfigs"
        "daemonsets"
        "statefulsets"
        "persistentvolumeclaims"
        "routes"
        "ingresses"
        "jobs"
        "cronjobs"
        "imagestreams"
        "buildconfigs"
        "pods"
        "replicasets"
        "networkpolicies"
        "resourcequotas"
        "limitranges"
        "rolebindings"
        "roles"
        "horizontalpodautoscalers"
    )
    
    for resource_type in "${resource_types[@]}"; do
        print_info "Exporting $resource_type..."
        
        # Get resource list
        local resources=$(oc get "$resource_type" -n "$SOURCE_NAMESPACE" -o name 2>/dev/null || true)
        
        if [[ -n "$resources" ]]; then
            # Export each resource individually
            while IFS= read -r resource; do
                local resource_name=$(echo "$resource" | cut -d'/' -f2)
                local filename="${resource_type}-${resource_name}.yaml"
                
                oc get "$resource" -n "$SOURCE_NAMESPACE" -o yaml > "$raw_dir/$filename" 2>/dev/null || {
                    print_warning "Failed to export $resource"
                }
            done <<< "$resources"
            
            # Also export all resources of this type in one file
            oc get "$resource_type" -n "$SOURCE_NAMESPACE" -o yaml > "$raw_dir/${resource_type}-all.yaml" 2>/dev/null || {
                print_warning "Failed to export all $resource_type"
            }
        else
            print_info "No $resource_type found in namespace"
        fi
    done
    
    print_success "Resource export completed"
}

# Clean exported resources for GitOps deployment
clean_resources() {
    print_section "CLEANING RESOURCES FOR GITOPS"
    
    local raw_dir="$BACKUP_DIR/raw"
    local cleaned_dir="$BACKUP_DIR/cleaned"
    
    print_info "Cleaning exported resources..."
    
    # Process each YAML file
    for file in "$raw_dir"/*.yaml; do
        if [[ -f "$file" ]]; then
            local basename=$(basename "$file")
            local cleaned_file="$cleaned_dir/$basename"
            
            print_info "Cleaning $basename..."
            
            # Clean the YAML file by removing cluster-specific metadata
            yq eval '
                del(.metadata.uid) |
                del(.metadata.selfLink) |
                del(.metadata.resourceVersion) |
                del(.metadata.generation) |
                del(.metadata.creationTimestamp) |
                del(.metadata.deletionTimestamp) |
                del(.metadata.deletionGracePeriodSeconds) |
                del(.metadata.ownerReferences) |
                del(.metadata.finalizers) |
                del(.metadata.managedFields) |
                del(.status) |
                del(.spec.clusterIP) |
                del(.spec.clusterIPs) |
                del(.spec.nodeName) |
                del(.spec.serviceAccount) |
                del(.spec.hostIP) |
                del(.spec.podIP) |
                del(.spec.podIPs) |
                del(.spec.phase) |
                del(.spec.qosClass) |
                del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") |
                del(.metadata.annotations."deployment.kubernetes.io/revision") |
                del(.metadata.annotations."pv.kubernetes.io/bind-completed") |
                del(.metadata.annotations."pv.kubernetes.io/bound-by-controller") |
                del(.metadata.annotations."volume.beta.kubernetes.io/storage-provisioner")
            ' "$file" > "$cleaned_file" 2>/dev/null || {
                # If yq is not available, use sed for basic cleaning
                sed -e '/uid:/d' \
                    -e '/selfLink:/d' \
                    -e '/resourceVersion:/d' \
                    -e '/generation:/d' \
                    -e '/creationTimestamp:/d' \
                    -e '/deletionTimestamp:/d' \
                    -e '/deletionGracePeriodSeconds:/d' \
                    -e '/ownerReferences:/d' \
                    -e '/finalizers:/d' \
                    -e '/managedFields:/d' \
                    -e '/status:/d' \
                    -e '/clusterIP:/d' \
                    -e '/clusterIPs:/d' \
                    -e '/nodeName:/d' \
                    -e '/hostIP:/d' \
                    -e '/podIP:/d' \
                    -e '/podIPs:/d' \
                    -e '/phase:/d' \
                    -e '/qosClass:/d' \
                    "$file" > "$cleaned_file"
            }
        fi
    done
    
    print_success "Resource cleaning completed"
}

# Create GitOps structure
create_gitops_structure() {
    print_section "CREATING GITOPS STRUCTURE"
    
    # Create base namespace.yaml
    cat > "$GITOPS_DIR/base/namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $SOURCE_NAMESPACE
  labels:
    app.kubernetes.io/name: $SOURCE_NAMESPACE
    app.kubernetes.io/managed-by: argocd
    backup.kohlerco.com/source: "automated-backup"
    backup.kohlerco.com/timestamp: "$TIMESTAMP"
EOF
    
    # Create base serviceaccount.yaml
    cat > "$GITOPS_DIR/base/serviceaccount.yaml" << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: useroot
  namespace: $SOURCE_NAMESPACE
  labels:
    app.kubernetes.io/name: $SOURCE_NAMESPACE
    app.kubernetes.io/managed-by: argocd
EOF
    
    # Create base scc-binding.yaml
    cat > "$GITOPS_DIR/base/scc-binding.yaml" << EOF
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: $SOURCE_NAMESPACE-anyuid
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: true
allowPrivilegedContainer: false
allowedCapabilities: null
defaultAddCapabilities: null
fsGroup:
  type: RunAsAny
groups:
- system:cluster-admins
priority: 10
readOnlyRootFilesystem: false
requiredDropCapabilities:
- MKNOD
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
users:
- system:serviceaccount:$SOURCE_NAMESPACE:useroot
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $SOURCE_NAMESPACE-anyuid
  namespace: $SOURCE_NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:anyuid
subjects:
- kind: ServiceAccount
  name: useroot
  namespace: $SOURCE_NAMESPACE
EOF
    
    # Create base kustomization.yaml
    cat > "$GITOPS_DIR/base/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: $SOURCE_NAMESPACE-base

resources:
- namespace.yaml
- serviceaccount.yaml
- scc-binding.yaml

labels:
- includeSelectors: true
  pairs:
    app.kubernetes.io/name: $SOURCE_NAMESPACE
    app.kubernetes.io/managed-by: argocd
    backup.kohlerco.com/source: "automated-backup"
EOF
    
    # Create production overlay
    cat > "$GITOPS_DIR/overlays/prd/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: $SOURCE_NAMESPACE-prd

resources:
- ../../base

patchesStrategicMerge: []

labels:
- includeSelectors: true
  pairs:
    app.kubernetes.io/environment: production
    backup.kohlerco.com/timestamp: "$TIMESTAMP"
EOF
    
    print_success "GitOps structure created"
}

# Organize cleaned resources into GitOps structure
organize_resources() {
    print_section "ORGANIZING RESOURCES INTO GITOPS"
    
    local cleaned_dir="$BACKUP_DIR/cleaned"
    local overlay_dir="$GITOPS_DIR/overlays/prd"
    
    # Combine similar resources into organized files
    local resource_groups=(
        "configmaps:configmaps-all.yaml"
        "secrets:secrets-all.yaml"
        "services:services-all.yaml"
        "serviceaccounts:serviceaccounts-all.yaml"
        "deployments:deployments-all.yaml"
        "deploymentconfigs:deploymentconfigs-all.yaml"
        "persistentvolumeclaims:persistentvolumeclaims-all.yaml"
        "routes:routes-all.yaml"
        "jobs:jobs-all.yaml"
        "cronjobs:cronjobs-all.yaml"
        "imagestreams:imagestreams-all.yaml"
    )
    
    for group in "${resource_groups[@]}"; do
        local resource_type=$(echo "$group" | cut -d':' -f1)
        local filename=$(echo "$group" | cut -d':' -f2)
        local source_file="$cleaned_dir/$filename"
        local target_file="$overlay_dir/${resource_type}.yaml"
        
        if [[ -f "$source_file" ]] && [[ -s "$source_file" ]]; then
            print_info "Adding $resource_type to overlay..."
            cp "$source_file" "$target_file"
            
            # Add to kustomization.yaml
            if ! grep -q "- ${resource_type}.yaml" "$overlay_dir/kustomization.yaml"; then
                sed -i '/patchesStrategicMerge: \[\]/a - '"${resource_type}.yaml" "$overlay_dir/kustomization.yaml"
            fi
        fi
    done
    
    print_success "Resources organized into GitOps structure"
}

# Create ArgoCD application manifest
create_argocd_application() {
    print_section "CREATING ARGOCD APPLICATION"
    
    cat > "$GITOPS_DIR/argocd-application.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $SOURCE_NAMESPACE-backup
  namespace: $ARGOCD_NAMESPACE
  labels:
    app.kubernetes.io/name: $SOURCE_NAMESPACE
    app.kubernetes.io/part-of: ${SOURCE_NAMESPACE}-platform
    backup.kohlerco.com/source: "automated-backup"
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: $GITHUB_REPO_URL
    targetRevision: HEAD
    path: $GITOPS_DIR/overlays/prd
  destination:
    server: https://kubernetes.default.svc
    namespace: $SOURCE_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - RespectIgnoreDifferences=true
    - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  ignoreDifferences:
  - group: ""
    kind: "Secret"
    jsonPointers:
    - /data
  - group: ""
    kind: "ConfigMap"
    jsonPointers:
    - /data
  - group: "apps"
    kind: "Deployment"
    jsonPointers:
    - /spec/replicas
  - group: "route.openshift.io"
    kind: "Route"
    jsonPointers:
    - /status
EOF
    
    print_success "ArgoCD application manifest created"
}

# Create daily backup script
create_daily_backup_script() {
    print_section "CREATING DAILY BACKUP SCRIPT"
    
    cat > "$SCRIPTS_DIR/daily-backup.sh" << 'SCRIPT_EOF'
#!/bin/bash
# Daily Namespace Backup Script
# This script performs daily backups of the namespace and updates GitHub
# Auto-generated by backup-namespace-setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration (set during initial setup)
SOURCE_CLUSTER="SOURCE_CLUSTER_PLACEHOLDER"
SOURCE_NAMESPACE="SOURCE_NAMESPACE_PLACEHOLDER"
GITHUB_REPO_URL="GITHUB_REPO_URL_PLACEHOLDER"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Directories
BACKUP_DIR="backup"
GITOPS_DIR="gitops"
DAILY_DIR="$BACKUP_DIR/daily/$TIMESTAMP"

# Logging functions
print_section() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create daily backup directory
mkdir -p "$DAILY_DIR/raw"
mkdir -p "$DAILY_DIR/cleaned"

# Login to cluster
print_section "CLUSTER LOGIN"
print_info "Logging into cluster: $SOURCE_CLUSTER"

if ! oc login "$SOURCE_CLUSTER" --token="$(cat ~/.kube/token 2>/dev/null || echo '')" &>/dev/null; then
    print_info "Token login failed, prompting for credentials"
    oc login "$SOURCE_CLUSTER" || {
        print_error "Failed to login to cluster"
        exit 1
    }
fi

print_success "Successfully logged into cluster"

# Export current state
print_section "EXPORTING CURRENT NAMESPACE STATE"

resource_types=(
    "configmaps"
    "secrets"
    "services"
    "serviceaccounts"
    "deployments"
    "deploymentconfigs"
    "daemonsets"
    "statefulsets"
    "persistentvolumeclaims"
    "routes"
    "ingresses"
    "jobs"
    "cronjobs"
    "imagestreams"
    "buildconfigs"
    "networkpolicies"
    "resourcequotas"
    "limitranges"
    "rolebindings"
    "roles"
    "horizontalpodautoscalers"
)

for resource_type in "${resource_types[@]}"; do
    print_info "Exporting $resource_type..."
    
    if oc get "$resource_type" -n "$SOURCE_NAMESPACE" -o yaml > "$DAILY_DIR/raw/${resource_type}-all.yaml" 2>/dev/null; then
        # Clean the exported resources
        if command -v yq &> /dev/null; then
            yq eval '
                del(.metadata.uid) |
                del(.metadata.selfLink) |
                del(.metadata.resourceVersion) |
                del(.metadata.generation) |
                del(.metadata.creationTimestamp) |
                del(.metadata.deletionTimestamp) |
                del(.metadata.deletionGracePeriodSeconds) |
                del(.metadata.ownerReferences) |
                del(.metadata.finalizers) |
                del(.metadata.managedFields) |
                del(.status) |
                del(.spec.clusterIP) |
                del(.spec.clusterIPs) |
                del(.spec.nodeName) |
                del(.spec.serviceAccount) |
                del(.spec.hostIP) |
                del(.spec.podIP) |
                del(.spec.podIPs) |
                del(.spec.phase) |
                del(.spec.qosClass)
            ' "$DAILY_DIR/raw/${resource_type}-all.yaml" > "$DAILY_DIR/cleaned/${resource_type}.yaml" 2>/dev/null
        else
            # Basic cleaning with sed if yq is not available
            sed -e '/uid:/d' \
                -e '/selfLink:/d' \
                -e '/resourceVersion:/d' \
                -e '/generation:/d' \
                -e '/creationTimestamp:/d' \
                -e '/status:/d' \
                -e '/clusterIP:/d' \
                -e '/nodeName:/d' \
                "$DAILY_DIR/raw/${resource_type}-all.yaml" > "$DAILY_DIR/cleaned/${resource_type}.yaml"
        fi
    else
        print_info "No $resource_type found in namespace"
    fi
done

print_success "Export completed"

# Check for changes and update GitOps structure if needed
print_section "CHECKING FOR CHANGES"

changes_detected=false

for resource_type in "${resource_types[@]}"; do
    daily_file="$DAILY_DIR/cleaned/${resource_type}.yaml"
    gitops_file="$GITOPS_DIR/overlays/prd/${resource_type}.yaml"
    
    if [[ -f "$daily_file" ]] && [[ -s "$daily_file" ]]; then
        if [[ ! -f "$gitops_file" ]] || ! diff -q "$daily_file" "$gitops_file" &>/dev/null; then
            print_info "Changes detected in $resource_type"
            cp "$daily_file" "$gitops_file"
            changes_detected=true
            
            # Ensure resource is in kustomization.yaml
            if ! grep -q "- ${resource_type}.yaml" "$GITOPS_DIR/overlays/prd/kustomization.yaml"; then
                sed -i '/resources:/a - '"${resource_type}.yaml" "$GITOPS_DIR/overlays/prd/kustomization.yaml"
            fi
        fi
    elif [[ -f "$gitops_file" ]]; then
        print_info "Resource $resource_type no longer exists, removing from GitOps"
        rm -f "$gitops_file"
        sed -i "/- ${resource_type}.yaml/d" "$GITOPS_DIR/overlays/prd/kustomization.yaml"
        changes_detected=true
    fi
done

# Update timestamp in kustomization
sed -i "s/backup.kohlerco.com\/timestamp: .*/backup.kohlerco.com\/timestamp: \"$TIMESTAMP\"/" "$GITOPS_DIR/overlays/prd/kustomization.yaml"

if [[ "$changes_detected" == "true" ]]; then
    print_success "Changes detected and GitOps structure updated"
    
    # Commit and push changes
    print_section "COMMITTING CHANGES TO GITHUB"
    
    git add .
    git commit -m "Auto-backup: Update $SOURCE_NAMESPACE namespace - $TIMESTAMP

- Automated backup of namespace resources
- Timestamp: $TIMESTAMP
- Changes detected in namespace configuration
- Updated GitOps manifests for ArgoCD sync" || {
        print_warning "No changes to commit or commit failed"
    }
    
    git push origin main || {
        print_error "Failed to push to GitHub"
        exit 1
    }
    
    print_success "Changes pushed to GitHub successfully"
else
    print_info "No changes detected since last backup"
fi

# Generate backup summary
print_section "BACKUP SUMMARY"

cat > "$DAILY_DIR/backup-summary.md" << SUMMARY_EOF
# Daily Backup Summary - $TIMESTAMP

## Namespace: $SOURCE_NAMESPACE
## Date: $(date)
## Changes Detected: $changes_detected

## Resources Backed Up:
SUMMARY_EOF

for resource_type in "${resource_types[@]}"; do
    if [[ -f "$DAILY_DIR/cleaned/${resource_type}.yaml" ]] && [[ -s "$DAILY_DIR/cleaned/${resource_type}.yaml" ]]; then
        resource_count=$(yq eval '.items | length' "$DAILY_DIR/cleaned/${resource_type}.yaml" 2>/dev/null || echo "Unknown")
        echo "- $resource_type: $resource_count items" >> "$DAILY_DIR/backup-summary.md"
    fi
done

cat >> "$DAILY_DIR/backup-summary.md" << SUMMARY_EOF

## GitOps Status:
- Repository: $GITHUB_REPO_URL
- ArgoCD Application: $SOURCE_NAMESPACE-backup
- Target Namespace: $SOURCE_NAMESPACE

## Next Steps:
1. Verify ArgoCD sync status
2. Check application health in target cluster
3. Review any sync errors in ArgoCD UI

---
Generated by automated backup script
SUMMARY_EOF

print_success "Daily backup completed successfully"

if [[ "$changes_detected" == "true" ]]; then
    print_info "GitOps repository updated - ArgoCD will sync changes automatically"
else
    print_info "No changes detected - GitOps repository unchanged"
fi

SCRIPT_EOF
    
    # Replace placeholders in the daily backup script
    sed -i "s|SOURCE_CLUSTER_PLACEHOLDER|$SOURCE_CLUSTER|g" "$SCRIPTS_DIR/daily-backup.sh"
    sed -i "s|SOURCE_NAMESPACE_PLACEHOLDER|$SOURCE_NAMESPACE|g" "$SCRIPTS_DIR/daily-backup.sh"
    sed -i "s|GITHUB_REPO_URL_PLACEHOLDER|$GITHUB_REPO_URL|g" "$SCRIPTS_DIR/daily-backup.sh"
    
    chmod +x "$SCRIPTS_DIR/daily-backup.sh"
    
    print_success "Daily backup script created and made executable"
}

# Create cron job setup script
create_cron_setup() {
    print_section "CREATING CRON JOB SETUP"
    
    cat > "$SCRIPTS_DIR/setup-cron.sh" << EOF
#!/bin/bash
# Setup cron job for daily namespace backup
# Run this script to schedule the daily backup

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
DAILY_SCRIPT="\$SCRIPT_DIR/daily-backup.sh"
REPO_DIR="\$(dirname "\$SCRIPT_DIR")"

# Add cron job to run daily at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * cd \$REPO_DIR && \$DAILY_SCRIPT >> /var/log/${SOURCE_NAMESPACE}-backup.log 2>&1") | crontab -

echo "Cron job added successfully!"
echo "Daily backup will run at 2:00 AM"
echo "Logs will be written to: /var/log/${SOURCE_NAMESPACE}-backup.log"
echo ""
echo "To check cron jobs: crontab -l"
echo "To remove cron job: crontab -e (then delete the line)"
EOF
    
    chmod +x "$SCRIPTS_DIR/setup-cron.sh"
    
    print_success "Cron setup script created"
}

# Initialize git repository
initialize_git_repo() {
    print_section "INITIALIZING GIT REPOSITORY"
    
    # Initialize git if not already initialized
    if [[ ! -d ".git" ]]; then
        git init
        print_info "Git repository initialized"
    fi
    
    # Create .gitignore
    cat > .gitignore << EOF
# Backup artifacts
backup/raw/
backup/daily/*/raw/
*.log

# Temporary files
*.tmp
*.temp
.DS_Store
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db
EOF
    
    # Create README
    cat > README.md << EOF
# $SOURCE_NAMESPACE Namespace Backup

This repository contains automated backup of the \`$SOURCE_NAMESPACE\` namespace using GitOps methodology with ArgoCD.

## Overview

This backup system provides:
- **Automated daily backups** of all namespace resources
- **GitOps deployment** using ArgoCD for infrastructure as code
- **Version control** of all configuration changes
- **Disaster recovery** capabilities

## Repository Structure

\`\`\`
├── backup/                    # Backup artifacts
│   ├── raw/                   # Raw exported resources
│   ├── cleaned/               # Cleaned resources
│   └── daily/                 # Daily backup snapshots
├── gitops/                    # GitOps manifests
│   ├── base/                  # Base Kustomize resources
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml
│   │   ├── scc-binding.yaml
│   │   └── kustomization.yaml
│   ├── overlays/              # Environment overlays
│   │   └── prd/               # Production overlay
│   │       ├── kustomization.yaml
│   │       └── [resource files]
│   └── argocd-application.yaml
├── scripts/                   # Automation scripts
│   ├── daily-backup.sh        # Daily backup script
│   └── setup-cron.sh          # Cron job setup
└── README.md
\`\`\`

## Setup

### Initial Setup
The initial setup was completed on $(date) using:
\`\`\`bash
./backup-namespace-setup.sh
\`\`\`

### Daily Backups
Daily backups are automated using:
\`\`\`bash
# Manual run
./scripts/daily-backup.sh

# Setup cron job (runs daily at 2 AM)
./scripts/setup-cron.sh
\`\`\`

## ArgoCD Deployment

### Deploy the ArgoCD Application
\`\`\`bash
# Login to target cluster
oc login $SOURCE_CLUSTER

# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# Monitor deployment
oc get application $SOURCE_NAMESPACE-backup -n $ARGOCD_NAMESPACE -w
\`\`\`

### Verify Deployment
\`\`\`bash
# Check application status
oc get application $SOURCE_NAMESPACE-backup -n $ARGOCD_NAMESPACE

# Check target namespace
oc get all -n $SOURCE_NAMESPACE

# Check ArgoCD logs
oc logs -n $ARGOCD_NAMESPACE deployment/argocd-application-controller
\`\`\`

## Monitoring

### ArgoCD UI
Access the ArgoCD UI to monitor sync status:
- Application: \`$SOURCE_NAMESPACE-backup\`
- Namespace: \`$ARGOCD_NAMESPACE\`

### Backup Logs
Daily backup logs are available at:
\`\`\`bash
# View latest backup log
tail -f /var/log/${SOURCE_NAMESPACE}-backup.log

# View backup summaries
ls -la backup/daily/
\`\`\`

## Disaster Recovery

### Restore from Backup
1. Ensure target cluster is accessible
2. Deploy ArgoCD application:
   \`\`\`bash
   oc apply -f gitops/argocd-application.yaml
   \`\`\`
3. ArgoCD will automatically sync and restore all resources

### Manual Restore
If ArgoCD is not available:
\`\`\`bash
# Deploy using Kustomize
kubectl apply -k gitops/overlays/prd
\`\`\`

## Configuration

- **Source Cluster**: $SOURCE_CLUSTER
- **Source Namespace**: $SOURCE_NAMESPACE
- **GitHub Repository**: $GITHUB_REPO_URL
- **ArgoCD Namespace**: $ARGOCD_NAMESPACE

## Support

For issues or questions:
1. Check ArgoCD application status and logs
2. Review daily backup logs
3. Verify cluster connectivity and permissions
4. Check GitHub repository for recent changes

---

**Created**: $(date)  
**Backup System**: Automated GitOps with ArgoCD  
**Update Frequency**: Daily at 2:00 AM
EOF
    
    # Add remote if provided
    if [[ -n "$GITHUB_REPO_URL" ]]; then
        git remote add origin "$GITHUB_REPO_URL" 2>/dev/null || {
            git remote set-url origin "$GITHUB_REPO_URL"
        }
        print_info "Git remote 'origin' set to $GITHUB_REPO_URL"
    fi
    
    print_success "Git repository initialized"
}

# Commit initial setup
commit_initial_setup() {
    print_section "COMMITTING INITIAL SETUP"
    
    git add .
    git commit -m "Initial setup: $SOURCE_NAMESPACE namespace backup with GitOps

- Created GitOps structure with base and overlay manifests
- Added ArgoCD application configuration for automated deployment
- Implemented daily backup automation with change detection
- Exported and cleaned all namespace resources
- Set up cron job automation for daily backups
- Configured disaster recovery capabilities

Setup Date: $(date)
Source Namespace: $SOURCE_NAMESPACE
Target Repository: $GITHUB_REPO_URL
ArgoCD Namespace: $ARGOCD_NAMESPACE" || {
        print_error "Failed to commit initial setup"
        exit 1
    }
    
    if [[ -n "$GITHUB_REPO_URL" ]]; then
        print_info "Pushing to GitHub repository..."
        git push -u origin main || {
            print_error "Failed to push to GitHub. You may need to:"
            print_error "1. Create the repository on GitHub first"
            print_error "2. Ensure you have proper authentication"
            print_error "3. Run 'git push -u origin main' manually"
        }
    fi
    
    print_success "Initial setup committed to repository"
}

# Deploy ArgoCD application
deploy_argocd_application() {
    print_section "DEPLOYING ARGOCD APPLICATION"
    
    read -p "Deploy ArgoCD application now? (y/N): " deploy_now
    if [[ "$deploy_now" =~ ^[Yy]$ ]]; then
        print_info "Deploying ArgoCD application..."
        
        oc apply -f "$GITOPS_DIR/argocd-application.yaml" || {
            print_error "Failed to deploy ArgoCD application"
            print_info "You can deploy it manually later with:"
            print_info "oc apply -f $GITOPS_DIR/argocd-application.yaml"
            return 1
        }
        
        print_success "ArgoCD application deployed successfully"
        
        # Wait a moment for the application to be registered
        sleep 5
        
        print_info "Application status:"
        oc get application "$SOURCE_NAMESPACE-backup" -n "$ARGOCD_NAMESPACE" -o wide 2>/dev/null || {
            print_warning "Application not yet available"
        }
    else
        print_info "Skipping ArgoCD deployment. Deploy later with:"
        print_info "oc apply -f $GITOPS_DIR/argocd-application.yaml"
    fi
}

# Display next steps
show_next_steps() {
    print_section "SETUP COMPLETE - NEXT STEPS"
    
    echo "🎉 Namespace backup setup completed successfully!"
    echo ""
    echo "📋 Summary:"
    echo "  ✅ Exported all resources from namespace '$SOURCE_NAMESPACE'"
    echo "  ✅ Created GitOps structure with Kustomize"
    echo "  ✅ Generated ArgoCD application manifest"
    echo "  ✅ Created daily backup automation"
    echo "  ✅ Initialized Git repository with remote"
    echo ""
    echo "🚀 Next Steps:"
    echo ""
    echo "1. 📅 SETUP DAILY BACKUPS:"
    echo "   ./scripts/setup-cron.sh"
    echo ""
    echo "2. 🔄 DEPLOY ARGOCD APPLICATION (if not done already):"
    echo "   oc apply -f gitops/argocd-application.yaml"
    echo ""
    echo "3. 🌐 MONITOR ARGOCD:"
    echo "   - Access ArgoCD UI to monitor '$SOURCE_NAMESPACE-backup' application"
    echo "   - Verify sync status and health"
    echo ""
    echo "4. ✅ VERIFY BACKUP:"
    echo "   ./scripts/daily-backup.sh  # Test manual backup"
    echo ""
    echo "5. 📊 MONITOR LOGS:"
    echo "   tail -f /var/log/${SOURCE_NAMESPACE}-backup.log"
    echo ""
    echo "🔗 Important Files:"
    echo "  📁 GitOps Manifests: gitops/"
    echo "  🤖 Daily Backup: scripts/daily-backup.sh"
    echo "  ⏰ Cron Setup: scripts/setup-cron.sh"
    echo "  📖 Documentation: README.md"
    echo ""
    echo "🆘 Disaster Recovery:"
    echo "  Deploy ArgoCD application to restore entire namespace"
    echo "  Alternative: kubectl apply -k gitops/overlays/prd"
    echo ""
    print_success "Backup system is ready for operation!"
}

# Main execution
main() {
    echo "🚀 Namespace Backup Setup with GitOps and ArgoCD"
    echo "================================================="
    echo ""
    
    prompt_configuration
    check_prerequisites
    create_directories
    login_to_cluster
    export_resources
    clean_resources
    create_gitops_structure
    organize_resources
    create_argocd_application
    create_daily_backup_script
    create_cron_setup
    initialize_git_repo
    commit_initial_setup
    deploy_argocd_application
    show_next_steps
}

# Run main function
main "$@"
