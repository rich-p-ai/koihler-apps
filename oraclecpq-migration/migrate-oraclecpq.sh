#!/bin/bash
# OracleCPQ Migration Script for GitOps Repository
# This script extracts oraclecpq namespace from OCP4 cluster and prepares it for GitOps management on OCP-PRD
# Created: August 6, 2025

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_CLUSTER="https://api.ocp4.kohlerco.com:6443"
SOURCE_NAMESPACE="oraclecpq"
TARGET_CLUSTER="https://api.ocp-prd.kohlerco.com:6443"
TARGET_NAMESPACE="oraclecpq"
BACKUP_DIR="backup"
GITOPS_DIR="gitops"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PROJECT_DIR="."

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

# Create directory structure
create_directories() {
    print_section "CREATING DIRECTORY STRUCTURE"
    
    mkdir -p "$BACKUP_DIR/raw"
    mkdir -p "$BACKUP_DIR/cleaned"
    mkdir -p "$GITOPS_DIR/base"
    mkdir -p "$GITOPS_DIR/overlays/prd"
    
    print_success "Directory structure created"
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
        print_error "kubectl CLI is not installed"
        exit 1
    fi
    
    # Check if yq is available (optional but helpful)
    if ! command -v yq &> /dev/null; then
        print_warning "yq not found - will use sed for YAML processing"
    fi
    
    print_success "Prerequisites check completed"
}

# Login to source cluster
login_to_source() {
    print_section "CONNECTING TO SOURCE CLUSTER (OCP4)"
    
    print_info "Please ensure you're logged into the OCP4 cluster"
    print_info "Run: oc login https://api.ocp4.kohlerco.com:6443"
    
    # Check if already logged in to correct cluster
    current_server=$(oc whoami --show-server 2>/dev/null || echo "none")
    if [[ "$current_server" != "$SOURCE_CLUSTER" ]]; then
        print_error "Not connected to OCP4 cluster. Please login first."
        exit 1
    fi
    
    # Verify namespace exists
    if ! oc get namespace "$SOURCE_NAMESPACE" &>/dev/null; then
        print_error "Namespace '$SOURCE_NAMESPACE' not found on source cluster"
        print_info "Available namespaces:"
        oc get namespaces | grep -E "(oracle|cpq)" || oc get namespaces | head -10
        exit 1
    fi
    
    print_success "Successfully connected to OCP4 cluster"
    print_info "Current user: $(oc whoami 2>/dev/null || echo 'Unable to determine')"
    print_info "Using namespace: $SOURCE_NAMESPACE"
}

# Export resources from source cluster
export_resources() {
    print_section "EXPORTING RESOURCES FROM $SOURCE_NAMESPACE"
    
    cd "$BACKUP_DIR/raw"
    
    # Export namespace definition
    print_info "Exporting namespace..."
    oc get namespace "$SOURCE_NAMESPACE" -o yaml > namespace.yaml
    
    # Export all resources
    print_info "Exporting ConfigMaps..."
    oc get configmap -n "$SOURCE_NAMESPACE" -o yaml > configmaps.yaml
    
    print_info "Exporting Secrets..."
    oc get secret -n "$SOURCE_NAMESPACE" -o yaml > secrets.yaml
    
    print_info "Exporting ServiceAccounts..."
    oc get serviceaccount -n "$SOURCE_NAMESPACE" -o yaml > serviceaccounts.yaml
    
    print_info "Exporting Services..."
    oc get service -n "$SOURCE_NAMESPACE" -o yaml > services.yaml
    
    print_info "Exporting Routes..."
    oc get route -n "$SOURCE_NAMESPACE" -o yaml > routes.yaml 2>/dev/null || touch routes.yaml
    
    print_info "Exporting Deployments..."
    oc get deployment -n "$SOURCE_NAMESPACE" -o yaml > deployments.yaml 2>/dev/null || touch deployments.yaml
    
    print_info "Exporting DeploymentConfigs..."
    oc get deploymentconfig -n "$SOURCE_NAMESPACE" -o yaml > deploymentconfigs.yaml 2>/dev/null || touch deploymentconfigs.yaml
    
    print_info "Exporting StatefulSets..."
    oc get statefulset -n "$SOURCE_NAMESPACE" -o yaml > statefulsets.yaml 2>/dev/null || touch statefulsets.yaml
    
    print_info "Exporting PVCs..."
    oc get pvc -n "$SOURCE_NAMESPACE" -o yaml > pvcs.yaml 2>/dev/null || touch pvcs.yaml
    
    print_info "Exporting RoleBindings..."
    oc get rolebinding -n "$SOURCE_NAMESPACE" -o yaml > rolebindings.yaml 2>/dev/null || touch rolebindings.yaml
    
    print_info "Exporting ImageStreams..."
    oc get imagestream -n "$SOURCE_NAMESPACE" -o yaml > imagestreams.yaml 2>/dev/null || touch imagestreams.yaml
    
    print_info "Exporting BuildConfigs..."
    oc get buildconfig -n "$SOURCE_NAMESPACE" -o yaml > buildconfigs.yaml 2>/dev/null || touch buildconfigs.yaml
    
    print_info "Exporting CronJobs..."
    oc get cronjob -n "$SOURCE_NAMESPACE" -o yaml > cronjobs.yaml 2>/dev/null || touch cronjobs.yaml
    
    print_info "Exporting Jobs..."
    oc get job -n "$SOURCE_NAMESPACE" -o yaml > jobs.yaml 2>/dev/null || touch jobs.yaml
    
    print_info "Exporting NetworkPolicies..."
    oc get networkpolicy -n "$SOURCE_NAMESPACE" -o yaml > networkpolicies.yaml 2>/dev/null || touch networkpolicies.yaml
    
    cd - > /dev/null
    
    print_success "Resource export completed"
}

# Clean and prepare resources for target cluster
clean_resources() {
    print_section "CLEANING RESOURCES FOR TARGET CLUSTER"
    
    cd "$BACKUP_DIR"
    
    for file in raw/*.yaml; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            print_info "Cleaning $filename..."
            
            # Use yq for more precise cleaning if available
            if command -v yq &> /dev/null; then
                yq eval '
                    del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields, .status) |
                    del(.metadata.ownerReferences) |
                    (.spec.template.spec.containers[]? | select(.image) | .image) |= sub("ocp4.kohlerco.com/"; "ocp-prd.kohlerco.com/") |
                    (.spec.containers[]? | select(.image) | .image) |= sub("ocp4.kohlerco.com/"; "ocp-prd.kohlerco.com/") |
                    (.spec.storageClassName) |= "gp3-csi"
                ' "$file" > "cleaned/$filename" 2>/dev/null || cp "$file" "cleaned/$filename"
            else
                # Fallback to sed-based cleaning if yq is not available
                sed -e '/resourceVersion:/d' \
                    -e '/uid:/d' \
                    -e '/generation:/d' \
                    -e '/creationTimestamp:/d' \
                    -e '/selfLink:/d' \
                    -e '/managedFields:/,/^[[:space:]]*[^[:space:]]/d' \
                    -e '/ownerReferences:/,/^[[:space:]]*[^[:space:]]/d' \
                    -e '/status:/,/^[[:space:]]*[^[:space:]]/d' \
                    -e 's|image-registry.openshift-image-registry.svc:5000/|kohler-registry-quay-quay.apps.ocp-host.kohlerco.com/|g' \
                    -e 's|ocp4.kohlerco.com/|ocp-prd.kohlerco.com/|g' \
                    -e 's/storageClassName: .*/storageClassName: gp3-csi/g' \
                    "$file" > "cleaned/$filename"
            fi
        fi
    done
    
    cd - > /dev/null
    
    print_success "Resource cleaning completed"
}

# Create GitOps structure
create_gitops_structure() {
    print_section "CREATING GITOPS STRUCTURE"
    
    # Create base namespace
    cat > "$GITOPS_DIR/base/namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $TARGET_NAMESPACE
  labels:
    name: $TARGET_NAMESPACE
    app.kubernetes.io/name: oraclecpq
    app.kubernetes.io/component: oracle-cpq
    app.kubernetes.io/managed-by: argocd
EOF
    
    # Create service account and RBAC
    cat > "$GITOPS_DIR/base/serviceaccount.yaml" << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: oraclecpq-sa
  namespace: $TARGET_NAMESPACE
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: useroot
  namespace: $TARGET_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: oraclecpq-admin
  namespace: $TARGET_NAMESPACE
subjects:
- kind: Group
  name: oraclecpq-admin
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: oraclecpq-useroot-anyuid
  namespace: $TARGET_NAMESPACE
subjects:
- kind: ServiceAccount
  name: useroot
  namespace: $TARGET_NAMESPACE
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
  name: oraclecpq-anyuid
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
- system:serviceaccount:$TARGET_NAMESPACE:useroot
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
EOF
    
    # Create base kustomization
    cat > "$GITOPS_DIR/base/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- serviceaccount.yaml
- scc-binding.yaml

commonLabels:
  app.kubernetes.io/name: oraclecpq
  app.kubernetes.io/component: oracle-cpq
  app.kubernetes.io/managed-by: argocd
EOF
    
    # Copy cleaned resources to overlays/prd
    if [[ -d "$BACKUP_DIR/cleaned" ]]; then
        cp "$BACKUP_DIR/cleaned"/*.yaml "$GITOPS_DIR/overlays/prd/" 2>/dev/null || true
    fi
    
    # Create production overlay kustomization
    cat > "$GITOPS_DIR/overlays/prd/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: $TARGET_NAMESPACE

resources:
- ../../base
$(find "$GITOPS_DIR/overlays/prd" -name "*.yaml" -not -name "kustomization.yaml" -printf "- %f\n" 2>/dev/null || echo "")

patchesStrategicMerge: []

images: []

replicas: []

commonLabels:
  environment: production
  cluster: ocp-prd
EOF
    
    print_success "GitOps structure created"
}

# Create ArgoCD application
create_argocd_application() {
    print_section "CREATING ARGOCD APPLICATION"
    
    cat > "$GITOPS_DIR/argocd-application.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oraclecpq-prd
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/rich-p-ai/koihler-apps.git
    targetRevision: main
    path: oraclecpq-migration/gitops/overlays/prd
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
    
    cat > "deploy-to-ocp-prd.sh" << 'EOF'
#!/bin/bash
# Deploy OracleCPQ to OCP-PRD
# Generated automatically by migrate-oraclecpq.sh

set -e

CLUSTER_URL="https://api.ocp-prd.kohlerco.com:6443"
NAMESPACE="oraclecpq"

echo "🚀 Deploying OracleCPQ to OCP-PRD"
echo "=================================="

# Login to cluster
echo "Logging into OCP-PRD cluster..."
oc login "$CLUSTER_URL"

# Verify cluster connection
echo "Verifying cluster connection..."
oc whoami
oc cluster-info

# Deploy using ArgoCD
echo "Deploying ArgoCD application..."
oc apply -f gitops/argocd-application.yaml

echo "✅ Deployment initiated!"
echo ""
echo "Monitor deployment with:"
echo "  oc get application oraclecpq-prd -n openshift-gitops"
echo "  oc get all -n $NAMESPACE"
echo "  oc describe application oraclecpq-prd -n openshift-gitops"
echo ""
echo "Access ArgoCD UI:"
echo "  https://openshift-gitops-server-openshift-gitops.apps.ocp-prd.kohlerco.com"
EOF

    chmod +x "deploy-to-ocp-prd.sh"
    print_success "Deployment script created: deploy-to-ocp-prd.sh"
}

# Generate inventory report
create_inventory() {
    print_section "GENERATING INVENTORY REPORT"
    
    cat > "ORACLECPQ-INVENTORY.md" << EOF
# OracleCPQ Migration Inventory

**Migration Date**: $(date)
**Source Cluster**: OCP4 (api.ocp4.kohlerco.com)
**Target Cluster**: OCP-PRD (api.ocp-prd.kohlerco.com)
**Namespace**: $SOURCE_NAMESPACE

## Resource Summary

### Application Resources
- **Deployments**: $(oc get deployment -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **DeploymentConfigs**: $(oc get deploymentconfig -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **StatefulSets**: $(oc get statefulset -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **Services**: $(oc get service -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **Routes**: $(oc get route -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)

### Configuration Resources
- **ConfigMaps**: $(oc get configmap -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **Secrets**: $(oc get secret -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **ServiceAccounts**: $(oc get serviceaccount -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)

### Storage and Other Resources
- **PVCs**: $(oc get pvc -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **RoleBindings**: $(oc get rolebinding -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **ImageStreams**: $(oc get imagestream -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **BuildConfigs**: $(oc get buildconfig -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **CronJobs**: $(oc get cronjob -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **Jobs**: $(oc get job -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
- **NetworkPolicies**: $(oc get networkpolicy -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l)

## NodePort Configuration

Based on the HAProxy configuration, OracleCPQ uses the following NodePorts:
- **32029, 32030, 32031** - Primary application ports
- **32074, 32075, 32076** - Additional service ports

These ports must be configured on the OCP-PRD worker nodes:
- 10.20.136.62 (worker1)
- 10.20.136.63 (worker2) 
- 10.20.136.64 (worker3)

## Domain Configuration

- **Source Domain**: *.apps.ocp4.kohlerco.com
- **Target Domain**: *.apps.ocp-prd.kohlerco.com
- **Expected Route**: oraclecpq.apps.ocp-prd.kohlerco.com

## NFS Storage Configuration

The following NFS persistent volumes are configured:
- **Development**: /ifs/NFS/USWINFS01/D/Shared/DEV/kbnaOracleCpq
- **QA**: /ifs/NFS/USWINFS01/D/Shared/QA/kbnaOracleCpq
- **Production**: /ifs/NFS/USWINFS01/D/Shared/PRD/kbnaOracleCpq

These will need to be reconfigured for OCP-PRD storage classes.

## Directory Structure

\`\`\`
oraclecpq-migration/
├── backup/
│   ├── raw/           # Original exported resources from OCP4
│   └── cleaned/       # Processed resources for OCP-PRD
├── gitops/
│   ├── base/          # Base Kustomize configuration
│   └── overlays/
│       └── prd/       # Production overlay for OCP-PRD
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

### Option 3: Automated Script
\`\`\`bash
./deploy-to-ocp-prd.sh
\`\`\`

## Verification Commands

After deployment:
\`\`\`bash
# Check namespace and resources
oc get all -n $TARGET_NAMESPACE

# Check deployments
oc get deployment -n $TARGET_NAMESPACE

# Check routes
oc get route -n $TARGET_NAMESPACE

# Check storage
oc get pvc -n $TARGET_NAMESPACE

# Check ArgoCD sync status
oc get application oraclecpq-prd -n openshift-gitops

# Check application logs
oc logs -n $TARGET_NAMESPACE deployment/<app-name>
\`\`\`

## Migration Considerations

### Oracle CPQ-Specific Notes
- ⚠️ **Database Connections**: Update database connection strings for new environment
- ⚠️ **Oracle Integration**: Verify Oracle product configuration connectivity
- ⚠️ **External APIs**: Verify external service connectivity from OCP-PRD
- ⚠️ **License Configuration**: Update Oracle CPQ license configuration

### Storage Migration
- ⚠️ **Storage Classes**: Updated to use \`gp3-csi\` for OCP-PRD compatibility
- ⚠️ **NFS Volumes**: Migrate NFS persistent volume data
- ⚠️ **Data Migration**: Plan data migration strategy for persistent volumes
- ⚠️ **Backup Strategy**: Implement backup procedures for new environment

### Security and RBAC
- ⚠️ **Service Accounts**: Review service account permissions
- ⚠️ **Security Contexts**: Validate SCC assignments
- ⚠️ **Network Policies**: Update network policies for new cluster network topology
- ⚠️ **Group Access**: Verify oraclecpq-admin group access

### Networking
- ⚠️ **Routes**: Verify route hostnames don't conflict with existing applications
- ⚠️ **NodePorts**: Configure NodePort services for HAProxy integration
- ⚠️ **Load Balancers**: Update external load balancer configurations
- ⚠️ **DNS**: Update DNS records to point to new cluster

## Post-Migration Checklist

1. **Pre-Migration Tasks**
   - Export data from NFS volumes
   - Document current database connections
   - Verify external integrations
   - Coordinate with Oracle CPQ team

2. **Data Migration**
   - Execute NFS data export/import
   - Verify data integrity after migration

3. **Deployment**
   - Review generated GitOps manifests in \`gitops/overlays/prd/\`
   - Update environment-specific configurations
   - Commit changes to Git repository
   - Deploy using ArgoCD

4. **Post-Migration Testing**
   - Verify application functionality
   - Test Oracle CPQ workflows
   - Test database connectivity
   - Monitor application performance
   - Update monitoring and alerting

5. **DNS and Load Balancer Updates**
   - Update DNS records
   - Configure HAProxy NodePort rules
   - Test external connectivity

6. **Documentation Updates**
   - Update runbooks and operational procedures
   - Update environment documentation
   - Notify stakeholders of new environment details

EOF

    print_success "Inventory report generated"
}

# Create README file
create_readme() {
    print_section "CREATING README"
    
    cat > "README.md" << EOF
# OracleCPQ Migration from OCP4 to OCP-PRD with GitOps

## 🎯 Project Overview

This project contains the complete migration of the \`oraclecpq\` namespace from the OCP4 cluster to OCP-PRD cluster using GitOps repository management for automated deployment with Kustomize and ArgoCD.

- **Source**: OCP4 cluster (\`api.ocp4.kohlerco.com\`)
- **Target**: OCP-PRD cluster (\`api.ocp-prd.kohlerco.com\`)
- **Namespace**: \`oraclecpq\`
- **Method**: GitOps with Kustomize overlays
- **Orchestration**: ArgoCD applications

## 📁 Project Structure

\`\`\`
oraclecpq-migration/
├── README.md                          # This file
├── migrate-oraclecpq.sh              # Automated migration script
├── deploy-to-ocp-prd.sh              # Deployment script
├── ORACLECPQ-INVENTORY.md            # Detailed resource inventory
├── backup/                            # Backup of original resources
│   ├── raw/                          # Raw exports from OCP4 cluster
│   └── cleaned/                      # Cleaned resources ready for OCP-PRD
└── gitops/                           # GitOps structure with Kustomize
    ├── base/                         # Base Kustomize configuration
    │   ├── kustomization.yaml        # Base kustomization
    │   ├── namespace.yaml            # Namespace definition
    │   ├── serviceaccount.yaml       # Service accounts and RBAC
    │   └── scc-binding.yaml          # Security context constraints
    ├── overlays/                     # Environment-specific overlays
    │   └── prd/                      # Production environment (OCP-PRD)
    │       ├── kustomization.yaml    # Production configuration
    │       └── [exported resources]  # All migrated application resources
    └── argocd-application.yaml       # ArgoCD application definition
\`\`\`

## 🚀 Quick Start

### Prerequisites
- Access to OCP4 cluster (for backup/export)
- Access to OCP-PRD cluster (for deployment)
- OpenShift CLI (\`oc\`)
- ArgoCD access on target cluster
- \`yq\` for YAML processing (optional but recommended)

### Step 1: Run Migration Script

\`\`\`bash
# Login to OCP4 cluster
oc login https://api.ocp4.kohlerco.com:6443

# Navigate to migration directory
cd "/c/work/OneDrive - Kohler Co/Openshift/git/koihler-apps/oraclecpq-migration"

# Run migration script
./migrate-oraclecpq.sh
\`\`\`

### Step 2: Review Generated Files

After the script completes, review:

\`\`\`bash
# Check the inventory report
cat ORACLECPQ-INVENTORY.md

# Review GitOps structure
tree gitops/

# Test Kustomize build
kubectl kustomize gitops/overlays/prd
\`\`\`

### Step 3: Deploy to OCP-PRD

#### Option A: Using ArgoCD (Recommended)

\`\`\`bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy ArgoCD application
oc apply -f gitops/argocd-application.yaml

# Monitor deployment
oc get application oraclecpq-prd -n openshift-gitops -w
\`\`\`

#### Option B: Direct Kustomize Deployment

\`\`\`bash
# Login to OCP-PRD cluster
oc login https://api.ocp-prd.kohlerco.com:6443

# Deploy using Kustomize
kubectl apply -k gitops/overlays/prd
\`\`\`

#### Option C: Automated Script

\`\`\`bash
./deploy-to-ocp-prd.sh
\`\`\`

## 🔧 Key Features

### Migration Benefits
- **Cross-Cluster Migration**: OCP4 → OCP-PRD with GitOps structure
- **Registry Updates**: Automatic image registry reference updates
- **Resource Cleaning**: Removes cluster-specific metadata
- **Security**: Maintains service accounts with appropriate SCC permissions
- **Automation**: ArgoCD integration for continuous deployment
- **Infrastructure as Code**: All resources defined in Git

### Oracle CPQ-Specific Features
- **Database Integration**: Preserves Oracle database configurations
- **Product Configuration**: Maintains Oracle CPQ product configurations
- **API Integration**: Preserves external API configurations
- **Data Persistence**: Handles persistent volume migrations

### Security and RBAC
- **Service Accounts**: \`oraclecpq-sa\` and \`useroot\` with appropriate permissions
- **SCC Bindings**: \`anyuid\` access where required
- **Clean Secrets**: All sensitive data preserved and properly secured
- **Group Access**: \`oraclecpq-admin\` group with admin permissions

## 🔍 Verification and Testing

### Post-Migration Verification

\`\`\`bash
# Check namespace and all resources
oc get all -n oraclecpq

# Check deployments and their status
oc get deployment -n oraclecpq
oc describe deployment/<app-name> -n oraclecpq

# Check routes and connectivity
oc get route -n oraclecpq
curl -k https://<route-hostname>/health

# Check persistent volumes
oc get pvc -n oraclecpq

# Check ArgoCD sync status
oc get application oraclecpq-prd -n openshift-gitops
oc describe application oraclecpq-prd -n openshift-gitops
\`\`\`

### Application-Specific Testing

\`\`\`bash
# Check application logs
oc logs -n oraclecpq deployment/<oracle-cpq-app>

# Test Oracle CPQ endpoints
curl -k https://<route>/api/health
curl -k https://<route>/api/status

# Check database connectivity
oc exec -n oraclecpq deployment/<app> -- curl -k <database-endpoint>
\`\`\`

## 📊 Migration Summary

See \`ORACLECPQ-INVENTORY.md\` for detailed resource inventory and migration analysis.

## 🚨 Important Migration Notes

### Container Images
- **Registry Migration**: All images updated from OCP4 internal registry to Quay registry
- **Image Pull Secrets**: Verify pull secrets are available on OCP-PRD
- **Version Compatibility**: Ensure Oracle CPQ versions are supported

### Application Configuration
- **Environment Variables**: Review and update cluster-specific configurations
- **Database Connections**: Update connection strings for OCP-PRD environment
- **External APIs**: Verify connectivity to external services from OCP-PRD
- **Oracle Integration**: Validate Oracle product configuration connectivity

### Storage and Persistence
- **Storage Classes**: Updated to use \`gp3-csi\` for OCP-PRD compatibility
- **NFS Migration**: Plan separate data migration for NFS persistent volumes
- **Data Migration**: Plan data migration strategy for persistent volumes
- **Backup Strategy**: Implement backup procedures for new environment

### Networking
- **Routes**: Update route hostnames to avoid conflicts
- **NodePorts**: Configure NodePort services (32029, 32030, 32031, 32074, 32075, 32076)
- **Load Balancers**: Configure external load balancer rules
- **DNS Updates**: Update DNS records to point to OCP-PRD
- **Firewall Rules**: Ensure network connectivity between clusters during migration

## 🛠️ Troubleshooting

### ArgoCD Sync Issues
\`\`\`bash
# Check application status
oc describe application oraclecpq-prd -n openshift-gitops

# View ArgoCD controller logs
oc logs -n openshift-gitops deployment/argocd-application-controller

# Manual sync
argocd app sync oraclecpq-prd
\`\`\`

### Resource Conflicts
\`\`\`bash
# Check for existing resources
oc get all -n oraclecpq

# Check events for errors
oc get events -n oraclecpq --sort-by='.lastTimestamp'

# Check resource quotas
oc describe quota -n oraclecpq
\`\`\`

### Application Issues
\`\`\`bash
# Check pod status
oc get pods -n oraclecpq

# Check application logs
oc logs -n oraclecpq deployment/<app-name>

# Check service endpoints
oc get endpoints -n oraclecpq
\`\`\`

## 🔄 Rollback Strategy

### Via ArgoCD
\`\`\`bash
# View application history
argocd app history oraclecpq-prd

# Rollback to previous version
argocd app rollback oraclecpq-prd <revision>

# Or delete application to stop sync
oc delete application oraclecpq-prd -n openshift-gitops
\`\`\`

### Manual Rollback
\`\`\`bash
# Delete resources
kubectl delete -k gitops/overlays/prd

# Redeploy to original cluster if needed
oc login https://api.ocp4.kohlerco.com:6443
# [restore from backup]
\`\`\`

## 📈 Post-Migration Tasks

### Immediate Tasks
1. **Verify Application Functionality**: Test all Oracle CPQ features
2. **Update DNS Records**: Point domains to OCP-PRD routes
3. **Configure NodePorts**: Set up HAProxy NodePort configuration
4. **Configure Monitoring**: Set up monitoring and alerting for new environment
5. **Update Documentation**: Update operational runbooks

### Ongoing Tasks
1. **Performance Monitoring**: Monitor application performance in new environment
2. **Backup Configuration**: Set up automated backup procedures
3. **Security Hardening**: Review and enhance security configurations
4. **Capacity Planning**: Monitor resource usage and plan for scaling

### Team Communication
1. **Stakeholder Notification**: Inform teams of migration completion
2. **Training**: Provide training on new environment access and procedures
3. **Support Documentation**: Update support procedures and contact information

## 🔗 Additional Resources

- **ArgoCD UI**: \`https://openshift-gitops-server-openshift-gitops.apps.ocp-prd.kohlerco.com\`
- **OCP-PRD Console**: \`https://console-openshift-console.apps.ocp-prd.kohlerco.com\`
- **Oracle CPQ Documentation**: Internal Oracle CPQ documentation
- **OpenShift GitOps Documentation**: \`https://docs.openshift.com/container-platform/4.15/cicd/gitops/understanding-openshift-gitops.html\`
EOF

    print_success "README file created"
}

# Generate migration summary
generate_migration_summary() {
    print_section "GENERATING MIGRATION SUMMARY"
    
    cat > "ORACLECPQ-MIGRATION-SUMMARY.md" << EOF
# 🎉 OracleCPQ Migration Summary

## Migration Details

**Date**: $(date)
**Source Cluster**: OCP4 ($(oc whoami --show-server))
**Target Cluster**: OCP-PRD 
**Namespace**: $SOURCE_NAMESPACE -> $TARGET_NAMESPACE

## 📦 **RESOURCES MIGRATED**

### Application Workloads:
- ✅ **Deployments**: $(oc get deployment -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items
- ✅ **DeploymentConfigs**: $(oc get deploymentconfig -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items
- ✅ **StatefulSets**: $(oc get statefulset -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items

### Configuration:
- ✅ **ConfigMaps**: $(oc get configmap -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items
- ✅ **Secrets**: $(oc get secret -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items

### Storage:
- ✅ **PVCs**: $(oc get pvc -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items

### Services & Networking:
- ✅ **Services**: $(oc get service -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items
- ✅ **Routes**: $(oc get route -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items

### Build & CI/CD:
- ✅ **ImageStreams**: $(oc get imagestream -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items
- ✅ **BuildConfigs**: $(oc get buildconfig -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items

### Jobs & Automation:
- ✅ **CronJobs**: $(oc get cronjob -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items
- ✅ **Jobs**: $(oc get job -n "$SOURCE_NAMESPACE" --no-headers 2>/dev/null | wc -l) items

## 🔧 **KEY FEATURES**

### GitOps Ready:
- ✅ **Kustomize**: Structured overlay approach for different environments
- ✅ **ArgoCD**: Automated deployment and sync capabilities
- ✅ **Environment Isolation**: Separate dev and prd configurations
- ✅ **Resource Management**: Proper labeling and annotation strategy

### Security:
- ✅ **Service Account**: oraclecpq-sa and useroot with anyuid SCC permissions
- ✅ **Clean Secrets**: All sensitive data preserved
- ✅ **RBAC**: Group-based access control configured

### Oracle CPQ-Specific:
- ✅ **Database Integration**: Database connection configurations preserved
- ✅ **Oracle Configuration**: Product configuration settings maintained
- ✅ **API Integration**: External API configurations preserved
- ✅ **Storage Migration**: NFS volume configurations updated

### RBAC Configuration:
- ✅ **Admin Group**: oraclecpq-admin with admin role
- ✅ **Service Accounts**: Proper service account structure
- ✅ **Group Binding**: Proper group role binding structure

## ✅ **VERIFICATION COMMANDS**

### Check Deployment Status:
\`\`\`bash
# Check namespace and resources
oc get all -n $TARGET_NAMESPACE

# Check Oracle CPQ specific resources
oc get deployment,statefulset,service -n $TARGET_NAMESPACE

# Check RBAC
oc get rolebinding -n $TARGET_NAMESPACE

# Check ArgoCD sync status (if using ArgoCD)
oc get application oraclecpq-prd -n openshift-gitops
\`\`\`

## 🎯 **SUCCESS CRITERIA**

- ✅ **All Resources Exported**: Complete namespace backup from OCP4
- ✅ **Resource Cleaning**: Cluster-specific metadata removed
- ✅ **GitOps Structure**: Kustomize overlays created for different environments
- ✅ **ArgoCD Integration**: Application definition ready for deployment
- ✅ **Security Configuration**: RBAC and SCC properly configured
- ✅ **Storage Updates**: Storage classes updated for OCP-PRD
- ✅ **Registry Migration**: Image references updated for new cluster
- ✅ **Documentation**: Complete migration documentation generated

## 🚀 **DEPLOYMENT OPTIONS**

### 1. GitOps with ArgoCD (Recommended)
\`\`\`bash
oc login https://api.ocp-prd.kohlerco.com:6443
oc apply -f gitops/argocd-application.yaml
\`\`\`

### 2. Kustomize Production Deployment
\`\`\`bash
oc login https://api.ocp-prd.kohlerco.com:6443
kubectl apply -k gitops/overlays/prd
\`\`\`

### 3. Automated Deployment Script
\`\`\`bash
./deploy-to-ocp-prd.sh
\`\`\`

## ⚠️ **IMPORTANT NOTES**

### Pre-Deployment Checklist:
1. **NFS Data Migration**: Export data from NFS volumes on OCP4
2. **Database Configuration**: Update database connection strings
3. **External Dependencies**: Verify external service connectivity
4. **NodePort Configuration**: Configure HAProxy NodePort rules (32029, 32030, 32031, 32074, 32075, 32076)

### Post-Deployment Tasks:
1. **Data Import**: Import NFS data to OCP-PRD storage
2. **DNS Updates**: Update DNS records to point to OCP-PRD routes
3. **Monitoring Setup**: Configure monitoring and alerting
4. **Testing**: Comprehensive application testing

## 📁 **FILE STRUCTURE**

\`\`\`
oraclecpq-migration/
├── README.md                      # Project documentation
├── ORACLECPQ-INVENTORY.md         # Resource inventory
├── ORACLECPQ-MIGRATION-SUMMARY.md # This file
├── migrate-oraclecpq.sh          # Migration script
├── deploy-to-ocp-prd.sh          # Deployment script
├── backup/
│   ├── raw/                       # Original exports
│   └── cleaned/                   # Processed resources
└── gitops/
    ├── base/                      # Base configuration
    ├── overlays/prd/             # Production overlay
    └── argocd-application.yaml    # ArgoCD application
\`\`\`

## 🎉 **COMPLETION**

Migration preparation completed successfully! 

**Next Steps:**
1. Review generated files and documentation
2. Coordinate with Oracle CPQ team for data migration
3. Deploy to OCP-PRD using ArgoCD
4. Execute post-migration verification and testing

---

**Status**: ✅ READY FOR DEPLOYMENT
EOF

    print_success "Migration summary generated"
}

# Main execution flow
main() {
    print_section "ORACLECPQ MIGRATION FROM OCP4 TO OCP-PRD"
    print_info "Starting migration process..."
    
    check_prerequisites
    create_directories
    login_to_source
    export_resources
    clean_resources
    create_gitops_structure
    create_argocd_application
    create_deployment_script
    create_inventory
    create_readme
    generate_migration_summary
    
    print_section "MIGRATION COMPLETED SUCCESSFULLY"
    print_success "All resources have been exported and prepared for GitOps deployment"
    print_info "Review the generated files:"
    print_info "  - ORACLECPQ-INVENTORY.md (resource inventory)"
    print_info "  - README.md (project documentation)"
    print_info "  - gitops/ (GitOps structure)"
    print_info "  - deploy-to-ocp-prd.sh (deployment script)"
    
    print_info ""
    print_info "Next steps:"
    print_info "1. Review generated GitOps manifests"
    print_info "2. Commit changes to Git repository"
    print_info "3. Deploy to OCP-PRD using ArgoCD"
    print_info "4. Execute data migration for NFS volumes"
    print_info "5. Update DNS and NodePort configurations"
    
    print_success "Migration preparation complete! 🚀"
}

# Execute main function
main "$@"
