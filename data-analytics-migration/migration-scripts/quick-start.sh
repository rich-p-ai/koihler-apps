#!/bin/bash

# Quick Start Script for Data Analytics Migration
# This script guides you through the migration process

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Data Analytics Migration Quick Start ===${NC}"
echo
echo "This script will help you migrate the data-analytics namespace from OCP4 to OCP-PRD"
echo "with GitOps deployment using Kustomize and ArgoCD."
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v oc &> /dev/null; then
    echo "❌ OpenShift CLI (oc) not found. Please install it first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ Kubernetes CLI (kubectl) not found. Please install it first."
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "❌ yq not found. Please install it first."
    exit 1
fi

echo "✅ All prerequisites met!"
echo

# Step 1: Login to source cluster
echo -e "${BLUE}Step 1: Login to Source Cluster (OCP4)${NC}"
echo "Please login to the OCP4 cluster to export data-analytics resources:"
echo "oc login https://api.ocp4.kohlerco.com:6443"
echo
read -p "Press Enter after logging in to OCP4..."

# Verify access to data-analytics namespace
if ! oc get namespace data-analytics &> /dev/null; then
    echo "❌ Cannot access data-analytics namespace. Please check your permissions."
    exit 1
fi

echo "✅ Access to data-analytics namespace confirmed!"
echo

# Step 2: Run migration script
echo -e "${BLUE}Step 2: Run Migration Script${NC}"
echo "Running automated migration script..."
echo
./migration-scripts/migrate-data-analytics.sh

echo
echo -e "${GREEN}✅ Migration script completed!${NC}"
echo

# Step 3: Review results
echo -e "${BLUE}Step 3: Review Migration Results${NC}"
echo "Please review the following files:"
echo "- README.md - Project overview"
echo "- DATA-ANALYTICS-MIGRATION-GUIDE.md - Complete guide"
echo "- DATA-ANALYTICS-MIGRATION-SUMMARY.md - Migration summary"
echo "- gitops/ - GitOps structure with Kustomize"
echo
read -p "Press Enter after reviewing the files..."

# Step 4: Deploy to target cluster
echo -e "${BLUE}Step 4: Deploy to Target Cluster (OCP-PRD)${NC}"
echo "Please login to the OCP-PRD cluster:"
echo "oc login https://api.ocp-prd.kohlerco.com:6443"
echo
read -p "Press Enter after logging in to OCP-PRD..."

echo
echo "Choose deployment method:"
echo "1. GitOps with ArgoCD (Recommended)"
echo "2. Direct Kustomize deployment (Production)"
echo "3. Direct Kustomize deployment (Development)"
echo "4. Manual deployment script"
echo
read -p "Select option (1-4): " option

case $option in
    1)
        echo "Deploying ArgoCD applications..."
        kubectl apply -f gitops/argocd-application.yaml
        echo "✅ ArgoCD applications created. Check ArgoCD UI for sync status."
        ;;
    2)
        echo "Deploying production environment..."
        kubectl apply -k gitops/overlays/prd
        echo "✅ Production environment deployed."
        ;;
    3)
        echo "Deploying development environment..."
        kubectl apply -k gitops/overlays/dev
        echo "✅ Development environment deployed."
        ;;
    4)
        echo "Running manual deployment script..."
        ./migration-scripts/deploy-to-ocp-prd.sh
        ;;
    *)
        echo "Invalid option. Please run ./migration-scripts/deploy-to-ocp-prd.sh manually."
        ;;
esac

echo
echo -e "${GREEN}🎉 Data Analytics Migration Completed!${NC}"
echo
echo "Next steps:"
echo "1. Verify all resources are deployed correctly"
echo "2. Test application functionality"
echo "3. Migrate container images if needed"
echo "4. Set up monitoring and alerting"
echo
echo "For detailed information, see:"
echo "- DATA-ANALYTICS-MIGRATION-GUIDE.md"
echo "- DATA-ANALYTICS-MIGRATION-SUMMARY.md"
