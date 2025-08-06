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
