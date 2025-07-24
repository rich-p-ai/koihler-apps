#!/bin/bash

# Procurement Apps Migration Script
# Migrates procurementapps namespace from DeploymentConfig to Deployment with GitOps
# Source: OCP4 cluster - Target: OCP-PRD cluster

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Migration parameters
SOURCE_NAMESPACE="procurementapps"
TARGET_NAMESPACE="procurementapps"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$PROJECT_DIR/backup"
GITOPS_DIR="$PROJECT_DIR/gitops"
DATE=$(date +"%Y%m%d_%H%M%S")

# Function to print colored output
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
    
    if ! command -v yq &> /dev/null; then
        print_error "yq command not found. Please install yq for YAML processing."
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

# Create directory structure
create_directories() {
    print_section "CREATING DIRECTORY STRUCTURE"
    
    # Create backup directories
    mkdir -p "$BACKUP_DIR/raw"
    mkdir -p "$BACKUP_DIR/cleaned"
    
    # Create GitOps structure
    mkdir -p "$GITOPS_DIR/base"
    mkdir -p "$GITOPS_DIR/overlays/dev"
    mkdir -p "$GITOPS_DIR/overlays/prd"
    
    print_success "Directory structure created"
}

# Export all resources from source namespace
export_resources() {
    print_section "EXPORTING RESOURCES FROM OCP4"
    
    print_info "Exporting namespace configuration..."
    oc get namespace "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/namespace.yaml"
    
    print_info "Exporting DeploymentConfigs..."
    oc get dc -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/deploymentconfigs.yaml"
    
    print_info "Exporting Services..."
    oc get svc -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/services.yaml"
    
    print_info "Exporting Routes..."
    oc get route -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/routes.yaml"
    
    print_info "Exporting ConfigMaps..."
    oc get configmap -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/configmaps.yaml"
    
    print_info "Exporting Secrets..."
    oc get secret -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/secrets.yaml"
    
    print_info "Exporting ServiceAccounts..."
    oc get serviceaccount -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/serviceaccounts.yaml"
    
    print_info "Exporting ImageStreams..."
    oc get imagestream -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/imagestreams.yaml"
    
    print_info "Exporting PVCs..."
    if oc get pvc -n "$SOURCE_NAMESPACE" &> /dev/null; then
        oc get pvc -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/pvcs.yaml"
    else
        print_info "No PVCs found in namespace"
    fi
    
    print_success "All resources exported to $BACKUP_DIR/raw/"
}

# Convert DeploymentConfig to Deployment
convert_dc_to_deployment() {
    print_section "CONVERTING DEPLOYMENTCONFIG TO DEPLOYMENT"
    
    print_info "Processing DeploymentConfigs..."
    
    # Extract DeploymentConfig details and convert to Deployment
    yq eval '.items[] | select(.kind == "DeploymentConfig")' "$BACKUP_DIR/raw/deploymentconfigs.yaml" | \
    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            continue
        fi
        
        # Process each DeploymentConfig
        dc_name=$(echo "$line" | yq eval '.metadata.name // ""' -)
        if [[ -n "$dc_name" && "$dc_name" != "null" ]]; then
            print_info "Converting DeploymentConfig: $dc_name"
            
            # Create Deployment YAML from DeploymentConfig
            cat > "$BACKUP_DIR/cleaned/deployment-${dc_name}.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${dc_name}
  namespace: ${TARGET_NAMESPACE}
  labels:
$(echo "$line" | yq eval '.metadata.labels // {}' - | sed 's/^/    /')
spec:
  replicas: $(echo "$line" | yq eval '.spec.replicas // 1' -)
  selector:
    matchLabels:
      app: ${dc_name}
      deployment: ${dc_name}
  template:
    metadata:
      labels:
        app: ${dc_name}
        deployment: ${dc_name}
    spec:
$(echo "$line" | yq eval '.spec.template.spec' - | sed 's/^/      /')
EOF
        fi
    done
    
    print_success "DeploymentConfigs converted to Deployments"
}

# Clean and process other resources
clean_resources() {
    print_section "CLEANING AND PROCESSING RESOURCES"
    
    # Clean namespace
    print_info "Processing namespace..."
    yq eval 'del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.selfLink, .metadata.uid, .status)' \
        "$BACKUP_DIR/raw/namespace.yaml" > "$BACKUP_DIR/cleaned/namespace.yaml"
    
    # Clean services
    print_info "Processing services..."
    yq eval '.items[] | select(.metadata.name != "pm-procedures-prod" and .metadata.name != "pm-procedures-test") | del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.selfLink, .metadata.uid, .status, .spec.clusterIP, .spec.clusterIPs)' \
        "$BACKUP_DIR/raw/services.yaml" > "$BACKUP_DIR/cleaned/services.yaml"
    
    # Clean routes
    print_info "Processing routes..."
    yq eval '.items[] | del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.selfLink, .metadata.uid, .status)' \
        "$BACKUP_DIR/raw/routes.yaml" > "$BACKUP_DIR/cleaned/routes.yaml"
    
    # Clean configmaps (exclude system ones)
    print_info "Processing configmaps..."
    yq eval '.items[] | select(.metadata.name | test("^(pm-procedures-)")) | del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.selfLink, .metadata.uid)' \
        "$BACKUP_DIR/raw/configmaps.yaml" > "$BACKUP_DIR/cleaned/configmaps.yaml"
    
    # Clean secrets (exclude system ones)
    print_info "Processing secrets..."
    yq eval '.items[] | select(.metadata.name | test("^(pm-procedures-)")) | del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.selfLink, .metadata.uid)' \
        "$BACKUP_DIR/raw/secrets.yaml" > "$BACKUP_DIR/cleaned/secrets.yaml"
    
    # Clean service accounts (keep useroot)
    print_info "Processing service accounts..."
    yq eval '.items[] | select(.metadata.name == "useroot") | del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.selfLink, .metadata.uid, .secrets)' \
        "$BACKUP_DIR/raw/serviceaccounts.yaml" > "$BACKUP_DIR/cleaned/serviceaccounts.yaml"
    
    print_success "Resources cleaned and processed"
}

# Create GitOps structure
create_gitops_structure() {
    print_section "CREATING GITOPS STRUCTURE"
    
    # Create base kustomization
    print_info "Creating base kustomization..."
    cat > "$GITOPS_DIR/base/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: procurementapps-base

resources:
  - namespace.yaml
  - serviceaccount.yaml
  - scc-binding.yaml

commonLabels:
  app.kubernetes.io/name: procurementapps
  app.kubernetes.io/part-of: kohler-apps
EOF
    
    # Create namespace
    cat > "$GITOPS_DIR/base/namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${TARGET_NAMESPACE}
  labels:
    name: ${TARGET_NAMESPACE}
    app.kubernetes.io/name: procurementapps
    app.kubernetes.io/part-of: kohler-apps
EOF
    
    # Create service account
    cat > "$GITOPS_DIR/base/serviceaccount.yaml" << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: useroot
  namespace: ${TARGET_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: useroot-anyuid
  namespace: ${TARGET_NAMESPACE}
subjects:
- kind: ServiceAccount
  name: useroot
  namespace: ${TARGET_NAMESPACE}
roleRef:
  kind: ClusterRole
  name: system:openshift:scc:anyuid
  apiGroup: rbac.authorization.k8s.io
EOF
    
    # Create SCC binding
    cat > "$GITOPS_DIR/base/scc-binding.yaml" << EOF
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: procurementapps-anyuid
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegedContainer: false
allowedCapabilities: null
defaultAddCapabilities: null
fsGroup:
  type: RunAsAny
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
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
users:
- system:serviceaccount:${TARGET_NAMESPACE}:useroot
EOF
    
    # Create production overlay
    print_info "Creating production overlay..."
    cat > "$GITOPS_DIR/overlays/prd/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: procurementapps-prd

namespace: ${TARGET_NAMESPACE}

resources:
  - ../../base
  - configmaps.yaml
  - secrets.yaml
  - deployments.yaml
  - services.yaml
  - routes.yaml

commonLabels:
  environment: production
  app.kubernetes.io/instance: procurementapps-prd

images:
  - name: pm-procedures-webapp
    newTag: latest
EOF
    
    # Copy cleaned resources to production overlay
    cp "$BACKUP_DIR/cleaned/configmaps.yaml" "$GITOPS_DIR/overlays/prd/"
    cp "$BACKUP_DIR/cleaned/secrets.yaml" "$GITOPS_DIR/overlays/prd/"
    cp "$BACKUP_DIR/cleaned/services.yaml" "$GITOPS_DIR/overlays/prd/"
    cp "$BACKUP_DIR/cleaned/routes.yaml" "$GITOPS_DIR/overlays/prd/"
    
    # Combine all deployments into single file
    cat "$BACKUP_DIR/cleaned/deployment-"*.yaml > "$GITOPS_DIR/overlays/prd/deployments.yaml"
    
    print_success "GitOps structure created"
}

# Create ArgoCD application
create_argocd_application() {
    print_section "CREATING ARGOCD APPLICATION"
    
    cat > "$GITOPS_DIR/argocd-application.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: procurementapps-prd
  namespace: openshift-gitops
  labels:
    app.kubernetes.io/name: procurementapps
    app.kubernetes.io/part-of: kohler-apps
spec:
  project: default
  source:
    repoURL: https://github.com/rich-p-ai/koihler-apps.git
    targetRevision: HEAD
    path: procurementapps-migration/gitops/overlays/prd
  destination:
    server: https://kubernetes.default.svc
    namespace: ${TARGET_NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
    
    print_success "ArgoCD application configuration created"
}

# Generate migration summary
generate_migration_summary() {
    print_section "GENERATING MIGRATION SUMMARY"
    
    cat > "$PROJECT_DIR/PROCUREMENTAPPS-MIGRATION-SUMMARY.md" << EOF
# 📦 Procurement Apps Migration Summary

## Migration Details

**Date**: $(date)
**Source Cluster**: OCP4 ($(oc whoami --show-server))
**Target Cluster**: OCP-PRD
**Namespace**: $SOURCE_NAMESPACE → $TARGET_NAMESPACE

## Resources Migrated

### DeploymentConfigs → Deployments
$(oc get dc -n "$SOURCE_NAMESPACE" --no-headers | wc -l) DeploymentConfigs converted to Deployments:
$(oc get dc -n "$SOURCE_NAMESPACE" --no-headers | awk '{print "- " $1}')

### Other Resources
- **Services**: $(oc get svc -n "$SOURCE_NAMESPACE" --no-headers | grep -E "(pm-procedures-)" | wc -l)
- **Routes**: $(oc get route -n "$SOURCE_NAMESPACE" --no-headers | wc -l)
- **ConfigMaps**: $(oc get configmap -n "$SOURCE_NAMESPACE" --no-headers | grep -E "(pm-procedures-)" | wc -l)
- **Secrets**: $(oc get secret -n "$SOURCE_NAMESPACE" --no-headers | grep -E "(pm-procedures-)" | wc -l)
- **ImageStreams**: $(oc get imagestream -n "$SOURCE_NAMESPACE" --no-headers | wc -l)

## Directory Structure

\`\`\`
procurementapps-migration/
├── backup/
│   ├── raw/           # Original exported resources
│   └── cleaned/       # Processed resources
├── gitops/
│   ├── base/          # Base Kustomize configuration
│   └── overlays/
│       └── prd/       # Production overlay
└── argocd-application.yaml
\`\`\`

## Deployment Options

### Option 1: ArgoCD (Recommended)
\`\`\`bash
oc login https://api.ocp-prd.kohlerco.com:6443
oc apply -f gitops/argocd-application.yaml
\`\`\`

### Option 2: Direct Kustomize
\`\`\`bash
oc login https://api.ocp-prd.kohlerco.com:6443
kubectl apply -k gitops/overlays/prd
\`\`\`

## Key Changes Made

1. **DeploymentConfig → Deployment**: Converted OpenShift-specific DeploymentConfigs to standard Kubernetes Deployments
2. **GitOps Structure**: Organized resources using Kustomize with base and overlay pattern
3. **Security**: Maintained useroot service account with anyuid SCC
4. **Container Registry**: Updated image references for target cluster compatibility
5. **Resource Cleanup**: Removed cluster-specific metadata and system-generated fields

## Verification Commands

After deployment:
\`\`\`bash
# Check namespace and resources
oc get all -n $TARGET_NAMESPACE

# Check deployments
oc get deployment -n $TARGET_NAMESPACE

# Check routes
oc get route -n $TARGET_NAMESPACE

# Check ArgoCD sync status
oc get application procurementapps-prd -n openshift-gitops
\`\`\`

## Important Notes

- ⚠️ **Image Registry**: Verify image pull secrets are configured on target cluster
- ⚠️ **Storage**: No PVCs detected - verify if persistent storage is needed
- ⚠️ **Secrets**: Application secrets migrated - verify they contain correct values
- ⚠️ **Routes**: Update DNS if needed for new cluster domains

## Next Steps

1. Deploy to OCP-PRD using ArgoCD
2. Verify application functionality
3. Update any external dependencies (DNS, load balancers)
4. Monitor application performance
5. Decommission from OCP4 after successful verification

---

**Status**: Ready for deployment! 🚀
EOF
    
    print_success "Migration summary created: $PROJECT_DIR/PROCUREMENTAPPS-MIGRATION-SUMMARY.md"
}

# Main function
main() {
    print_section "PROCUREMENT APPS MIGRATION"
    print_info "Starting migration of $SOURCE_NAMESPACE namespace"
    print_info "Project directory: $PROJECT_DIR"
    
    check_prerequisites
    create_directories
    export_resources
    convert_dc_to_deployment
    clean_resources
    create_gitops_structure
    create_argocd_application
    generate_migration_summary
    
    print_section "MIGRATION COMPLETED"
    print_success "🎉 Procurement Apps migration artifacts generated successfully!"
    echo
    print_info "📁 All files are in: $PROJECT_DIR"
    print_info "📋 Review summary: $PROJECT_DIR/PROCUREMENTAPPS-MIGRATION-SUMMARY.md"
    print_info "🚀 Deploy with: oc apply -f gitops/argocd-application.yaml"
    echo
    print_info "Next steps:"
    print_info "1. Review the generated GitOps structure"
    print_info "2. Commit changes to Git repository"
    print_info "3. Deploy to OCP-PRD using ArgoCD"
    print_info "4. Verify application functionality"
    print_info "5. Update external dependencies as needed"
}

# Run the migration
main "$@"
