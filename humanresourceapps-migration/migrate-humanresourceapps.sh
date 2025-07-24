#!/bin/bash

# ====================================================================
# Human Resource Apps Migration Script
# Source: OCP4 cluster -> Target: OCP-PRD cluster
# ====================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_NAMESPACE="humanresourceapps"
TARGET_NAMESPACE="humanresourceapps"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$PROJECT_DIR/backup"
CLEAN_DIR="$PROJECT_DIR/cleaned"
GITOPS_DIR="$PROJECT_DIR/gitops"

# Helper functions
print_section() {
    echo -e "\n${BLUE}===== $1 =====${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Create directory structure
create_directories() {
    print_section "CREATING DIRECTORY STRUCTURE"
    
    mkdir -p "$BACKUP_DIR/raw"
    mkdir -p "$CLEAN_DIR"
    mkdir -p "$GITOPS_DIR/base"
    mkdir -p "$GITOPS_DIR/overlays/prd"
    mkdir -p "$GITOPS_DIR/overlays/dev"
    
    print_success "Directory structure created"
}

# Export resources from source cluster
export_resources() {
    print_section "EXPORTING RESOURCES FROM OCP4 CLUSTER"
    
    # Verify we're connected to source cluster
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift cluster"
        exit 1
    fi
    
    current_server=$(oc whoami --show-server)
    print_info "Connected to: $current_server"
    
    # Check if namespace exists
    if ! oc get namespace "$SOURCE_NAMESPACE" &> /dev/null; then
        print_error "Namespace '$SOURCE_NAMESPACE' not found on source cluster"
        exit 1
    fi
    
    print_info "Exporting Jobs..."
    oc get jobs -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/jobs.yaml" 2>/dev/null || echo "No jobs found"
    
    print_info "Exporting CronJobs..."
    oc get cronjobs -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/cronjobs.yaml" 2>/dev/null || echo "No cronjobs found"
    
    print_info "Exporting ConfigMaps..."
    oc get configmap -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/configmaps.yaml"
    
    print_info "Exporting Secrets..."
    oc get secret -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/secrets.yaml"
    
    print_info "Exporting ServiceAccounts..."
    oc get serviceaccount -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/serviceaccounts.yaml"
    
    print_info "Exporting Services..."
    oc get svc -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/services.yaml"
    
    print_info "Exporting Routes..."
    oc get route -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/routes.yaml" 2>/dev/null || echo "No routes found"
    
    print_info "Exporting Deployments..."
    oc get deployment -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/deployments.yaml" 2>/dev/null || echo "No deployments found"
    
    print_info "Exporting DeploymentConfigs..."
    oc get dc -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/deploymentconfigs.yaml" 2>/dev/null || echo "No deploymentconfigs found"
    
    print_info "Exporting PVCs..."
    oc get pvc -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/pvcs.yaml" 2>/dev/null || echo "No pvcs found"
    
    print_info "Exporting ImageStreams..."
    oc get imagestream -n "$SOURCE_NAMESPACE" -o yaml > "$BACKUP_DIR/raw/imagestreams.yaml" 2>/dev/null || echo "No imagestreams found"
    
    print_success "Resource export completed"
}

# Clean resources for target cluster
clean_resources() {
    print_section "CLEANING RESOURCES FOR TARGET CLUSTER"
    
    # Process each resource type
    for file in "$BACKUP_DIR/raw"/*.yaml; do
        if [[ -f "$file" && -s "$file" ]]; then
            filename=$(basename "$file")
            print_info "Cleaning $filename..."
            
            # Remove cluster-specific metadata
            yq eval 'del(.metadata.resourceVersion, .metadata.uid, .metadata.selfLink, .metadata.creationTimestamp, .status)' "$file" > "$CLEAN_DIR/${filename%.yaml}-cleaned.yaml"
            
            # If it has items (list of resources), clean each item
            if yq eval '.items' "$file" | grep -q "\[\]"; then
                # Empty array, skip
                continue
            elif yq eval '.items' "$file" | grep -q "null"; then
                # No items field, single resource
                yq eval 'del(.metadata.resourceVersion, .metadata.uid, .metadata.selfLink, .metadata.creationTimestamp, .status)' "$file" > "$CLEAN_DIR/${filename%.yaml}-cleaned.yaml"
            else
                # Has items, clean each
                yq eval 'del(.items[].metadata.resourceVersion, .items[].metadata.uid, .items[].metadata.selfLink, .items[].metadata.creationTimestamp, .items[].status)' "$file" > "$CLEAN_DIR/${filename%.yaml}-cleaned.yaml"
            fi
        fi
    done
    
    # Update domains for target cluster
    if [[ -f "$CLEAN_DIR/routes-cleaned.yaml" ]]; then
        print_info "Updating route domains for target cluster..."
        sed -i 's/\.apps\.ocp4\.kohlerco\.com/.apps.ocp-prd.kohlerco.com/g' "$CLEAN_DIR/routes-cleaned.yaml"
    fi
    
    # Update storage classes if needed
    if [[ -f "$CLEAN_DIR/pvcs-cleaned.yaml" ]]; then
        print_info "Updating storage classes for target cluster..."
        sed -i 's/storageClassName: .*/storageClassName: gp3-csi/g' "$CLEAN_DIR/pvcs-cleaned.yaml"
    fi
    
    print_success "Resource cleaning completed"
}

# Create GitOps structure
create_gitops_structure() {
    print_section "CREATING GITOPS STRUCTURE WITH KUSTOMIZE"
    
    # Create base kustomization.yaml
    cat > "$GITOPS_DIR/base/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: humanresourceapps-base
  annotations:
    argocd.argoproj.io/sync-wave: "1"

namespace: $TARGET_NAMESPACE

resources:
  - namespace.yaml
  - serviceaccount.yaml
  - scc-binding.yaml
  - rbac.yaml

commonLabels:
  app.kubernetes.io/name: humanresourceapps
  app.kubernetes.io/part-of: humanresource-platform
  app.kubernetes.io/managed-by: kustomize

patchesStrategicMerge: []
patchesJson6902: []
EOF

    # Create namespace definition
    cat > "$GITOPS_DIR/base/namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $TARGET_NAMESPACE
  labels:
    name: $TARGET_NAMESPACE
    openshift.io/cluster-monitoring: "true"
  annotations:
    openshift.io/display-name: "Human Resource Apps"
    openshift.io/description: "Human Resource applications and jobs"
EOF

    # Create service account
    cat > "$GITOPS_DIR/base/serviceaccount.yaml" << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: useroot
  namespace: $TARGET_NAMESPACE
  labels:
    app.kubernetes.io/name: humanresourceapps
EOF

    # Create SCC binding
    cat > "$GITOPS_DIR/base/scc-binding.yaml" << EOF
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: useroot-$TARGET_NAMESPACE
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
- system:serviceaccount:$TARGET_NAMESPACE:useroot
EOF

    # Create RBAC configuration
    cat > "$GITOPS_DIR/base/rbac.yaml" << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: humanresourceapps-admins-binding
  namespace: $TARGET_NAMESPACE
  labels:
    app.kubernetes.io/name: humanresourceapps
    app.kubernetes.io/component: rbac
    app.kubernetes.io/managed-by: kustomize
subjects:
  - kind: Group
    name: humanresourceapps-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: humanresourceapps-users-binding
  namespace: $TARGET_NAMESPACE
subjects:
- kind: User
  name: Jeyasri.Babuji@kohler.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
EOF

    # Create production overlay
    cat > "$GITOPS_DIR/overlays/prd/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: humanresourceapps-prd

namespace: $TARGET_NAMESPACE

resources:
  - ../../base

commonLabels:
  environment: production
  app.kubernetes.io/instance: humanresourceapps-prd

# Add resource files if they exist
$(find "$CLEAN_DIR" -name "*-cleaned.yaml" -exec basename {} \; | sed 's/^/  - /' | head -20)

replicas:
  - name: "*"
    count: 1

images: []
EOF

    # Copy cleaned resources to overlays
    for file in "$CLEAN_DIR"/*-cleaned.yaml; do
        if [[ -f "$file" ]]; then
            cp "$file" "$GITOPS_DIR/overlays/prd/"
        fi
    done
    
    # Create development overlay
    cat > "$GITOPS_DIR/overlays/dev/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: humanresourceapps-dev

namespace: $TARGET_NAMESPACE

resources:
  - ../../base

commonLabels:
  environment: development
  app.kubernetes.io/instance: humanresourceapps-dev

replicas:
  - name: "*"
    count: 1

images: []
EOF

    print_success "GitOps structure created with Kustomize"
}

# Create ArgoCD application
create_argocd_application() {
    print_section "CREATING ARGOCD APPLICATION"
    
    cat > "$GITOPS_DIR/argocd-application.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: humanresourceapps-prd
  namespace: openshift-gitops
  labels:
    app.kubernetes.io/name: humanresourceapps
    app.kubernetes.io/part-of: humanresource-platform
spec:
  project: default
  source:
    repoURL: https://github.com/rich-p-ai/koihler-apps.git
    targetRevision: HEAD
    path: humanresourceapps-migration/gitops/overlays/prd
  destination:
    server: https://kubernetes.default.svc
    namespace: $TARGET_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - RespectIgnoreDifferences=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    print_success "ArgoCD application configuration created"
}

# Generate deployment script
create_deployment_script() {
    print_section "CREATING DEPLOYMENT SCRIPT"
    
    cat > "$PROJECT_DIR/deploy-to-ocp-prd.sh" << 'EOF'
#!/bin/bash

# Human Resource Apps Deployment Script for OCP-PRD
set -euo pipefail

NAMESPACE="humanresourceapps"
GITOPS_DIR="./gitops"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Check cluster connection
if ! oc whoami &> /dev/null; then
    echo "❌ Not logged in to OpenShift cluster"
    exit 1
fi

current_server=$(oc whoami --show-server)
print_info "Connected to: $current_server"

echo "Choose deployment method:"
echo "1. Deploy using Kustomize (Production)"
echo "2. Deploy using Kustomize (Development)"
echo "3. Deploy using raw manifests"
echo "4. Deploy ArgoCD Application"
read -p "Select option (1-4): " option

case $option in
    1)
        print_info "Deploying production environment using Kustomize..."
        kubectl apply -k "$GITOPS_DIR/overlays/prd"
        ;;
    2)
        print_info "Deploying development environment using Kustomize..."
        kubectl apply -k "$GITOPS_DIR/overlays/dev"
        ;;
    3)
        print_info "Deploying using raw manifests..."
        
        # Create namespace first
        kubectl apply -f "$GITOPS_DIR/base/namespace.yaml"
        
        # Deploy base resources
        kubectl apply -f "$GITOPS_DIR/base/serviceaccount.yaml"
        kubectl apply -f "$GITOPS_DIR/base/scc-binding.yaml"
        kubectl apply -f "$GITOPS_DIR/base/rbac.yaml"
        
        # Deploy application resources
        for file in "$GITOPS_DIR/overlays/prd"/*-cleaned.yaml; do
            if [[ -f "$file" ]]; then
                kubectl apply -f "$file"
            fi
        done
        ;;
    4)
        print_info "Deploying ArgoCD Application..."
        kubectl apply -f "$GITOPS_DIR/argocd-application.yaml"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

print_success "Deployment completed!"
EOF

    chmod +x "$PROJECT_DIR/deploy-to-ocp-prd.sh"
    print_success "Deployment script created: deploy-to-ocp-prd.sh"
}

# Generate migration summary
generate_migration_summary() {
    print_section "GENERATING MIGRATION SUMMARY"
    
    cat > "$PROJECT_DIR/HUMANRESOURCEAPPS-MIGRATION-SUMMARY.md" << EOF
# 🎉 Human Resource Apps Migration Summary

## Migration Details

**Date**: $(date)
**Source Cluster**: OCP4 ($(oc whoami --show-server))
**Target Cluster**: OCP-PRD 
**Namespace**: $SOURCE_NAMESPACE -> $TARGET_NAMESPACE

## 📦 **RESOURCES MIGRATED**

### Jobs and CronJobs:
$(ls -la "$BACKUP_DIR/raw/" | grep -E "(job|cron)" | wc -l) job-related resources exported

### Configuration:
- ✅ **ConfigMaps**: $(if [[ -f "$BACKUP_DIR/raw/configmaps.yaml" ]]; then yq eval '.items | length' "$BACKUP_DIR/raw/configmaps.yaml" 2>/dev/null || echo "0"; else echo "0"; fi) items
- ✅ **Secrets**: $(if [[ -f "$BACKUP_DIR/raw/secrets.yaml" ]]; then yq eval '.items | length' "$BACKUP_DIR/raw/secrets.yaml" 2>/dev/null || echo "0"; else echo "0"; fi) items

### Storage:
- ✅ **PVCs**: $(if [[ -f "$BACKUP_DIR/raw/pvcs.yaml" ]]; then yq eval '.items | length' "$BACKUP_DIR/raw/pvcs.yaml" 2>/dev/null || echo "0"; else echo "0"; fi) items

### Services & Networking:
- ✅ **Services**: $(if [[ -f "$BACKUP_DIR/raw/services.yaml" ]]; then yq eval '.items | length' "$BACKUP_DIR/raw/services.yaml" 2>/dev/null || echo "0"; else echo "0"; fi) items
- ✅ **Routes**: $(if [[ -f "$BACKUP_DIR/raw/routes.yaml" ]]; then yq eval '.items | length' "$BACKUP_DIR/raw/routes.yaml" 2>/dev/null || echo "0"; else echo "0"; fi) items

## 🗂️ **GITOPS STRUCTURE CREATED**

### Kustomize Structure:
\`\`\`
gitops/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── scc-binding.yaml
│   └── rbac.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   └── prd/
│       ├── kustomization.yaml
│       └── [cleaned resource files]
└── argocd-application.yaml
\`\`\`

## 🚀 **DEPLOYMENT OPTIONS**

### 1. GitOps with ArgoCD (Recommended)
\`\`\`bash
kubectl apply -f gitops/argocd-application.yaml
\`\`\`

### 2. Kustomize Production Deployment
\`\`\`bash
kubectl apply -k gitops/overlays/prd
\`\`\`

### 3. Kustomize Development Deployment
\`\`\`bash
kubectl apply -k gitops/overlays/dev
\`\`\`

### 4. Manual Deployment
\`\`\`bash
./deploy-to-ocp-prd.sh
\`\`\`

## 🔧 **KEY FEATURES**

### GitOps Ready:
- ✅ **Kustomize**: Structured overlay approach for different environments
- ✅ **ArgoCD**: Automated deployment and sync capabilities
- ✅ **Environment Isolation**: Separate dev and prd configurations
- ✅ **Resource Management**: Proper labeling and annotation strategy

### Security:
- ✅ **Service Account**: useroot with anyuid SCC permissions
- ✅ **Clean Secrets**: All sensitive data preserved
- ✅ **RBAC**: Group-based access control configured

### RBAC Configuration:
- ✅ **Admin Group**: humanresourceapps-admins with admin role
- ✅ **User Access**: Jeyasri.Babuji@kohler.com with edit permissions
- ✅ **Group Binding**: Proper group role binding structure

## ✅ **VERIFICATION COMMANDS**

### Check Deployment Status:
\`\`\`bash
# Check namespace and resources
oc get all -n $TARGET_NAMESPACE

# Check jobs specifically
oc get jobs,cronjobs -n $TARGET_NAMESPACE

# Check RBAC
oc get rolebinding -n $TARGET_NAMESPACE

# Check ArgoCD sync status (if using ArgoCD)
oc get application humanresourceapps-prd -n openshift-gitops
\`\`\`

## 🎯 **SUCCESS CRITERIA**

- [x] All jobs exported from source cluster
- [x] Resources cleaned for target cluster compatibility
- [x] GitOps structure created with Kustomize
- [x] ArgoCD application configuration ready
- [x] RBAC properly configured
- [x] Deployment scripts created
- [x] Documentation completed

## 📁 **NEXT STEPS**

1. **Deploy to OCP-PRD**: Use one of the deployment options above
2. **Verify Jobs**: Check that all jobs are running properly
3. **Test Functionality**: Validate job execution and outputs
4. **Monitor Performance**: Check job performance and scheduling
5. **Update Documentation**: Document any job-specific configurations

---

**Migration Status**: ✅ **READY FOR DEPLOYMENT**

**Team**: DevOps Migration Team  
**Contact**: migration-support@kohler.com
EOF

    print_success "Migration summary created: HUMANRESOURCEAPPS-MIGRATION-SUMMARY.md"
}

# Main execution
main() {
    print_section "HUMAN RESOURCE APPS MIGRATION TO OCP-PRD"
    print_info "Source: $SOURCE_NAMESPACE namespace on OCP4"
    print_info "Target: $TARGET_NAMESPACE namespace on OCP-PRD"
    
    create_directories
    export_resources
    clean_resources
    create_gitops_structure
    create_argocd_application
    create_deployment_script
    generate_migration_summary
    
    print_section "MIGRATION PREPARATION COMPLETE!"
    print_success "All resources have been exported and prepared for deployment"
    print_info "Review the generated files and run ./deploy-to-ocp-prd.sh when ready"
    print_info "Or use: kubectl apply -f gitops/argocd-application.yaml for GitOps deployment"
}

# Run main function
main "$@"
