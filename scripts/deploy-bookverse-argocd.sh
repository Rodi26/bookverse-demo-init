#!/usr/bin/env bash
# =============================================================================
# Deploy BookVerse via ArgoCD on GKE
# =============================================================================
# This script deploys BookVerse applications via ArgoCD on an existing GKE cluster
# Assumes ArgoCD is already installed
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
ENV="${ENV:-prod}"
ARGOCD_NS="argocd"
BOOKVERSE_NS="bookverse-${ENV}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Deploy BookVerse via ArgoCD on GKE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Verify ArgoCD is running
log_info "Verifying ArgoCD installation..."
if ! kubectl get namespace $ARGOCD_NS >/dev/null 2>&1; then
    log_error "ArgoCD namespace not found"
    log_error "Please deploy ArgoCD first: cd bookverse-demo-assets/gke-argocd && ./deploy-argocd-gke.sh"
    exit 1
fi

if ! kubectl get pods -n $ARGOCD_NS -l app.kubernetes.io/name=argocd-server >/dev/null 2>&1; then
    log_error "ArgoCD server not found"
    exit 1
fi

log_success "ArgoCD is running"
echo ""

# Step 2: Get paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITOPS_DIR="${SCRIPT_DIR}/../../bookverse-demo-assets/gitops"

if [[ ! -d "$GITOPS_DIR" ]]; then
    log_error "GitOps directory not found: $GITOPS_DIR"
    log_error "Please ensure bookverse-demo-assets repository is cloned"
    exit 1
fi

# Step 3: Create ArgoCD project
log_info "Creating ArgoCD project for BookVerse ${ENV}..."
kubectl apply -f "${GITOPS_DIR}/projects/bookverse-${ENV}.yaml"
log_success "Project created"
echo ""

# Step 4: Create BookVerse application
log_info "Deploying BookVerse platform application..."
kubectl apply -f "${GITOPS_DIR}/apps/${ENV}/platform.yaml"
log_success "Application deployed"
echo ""

# Step 5: Wait for sync
log_info "Waiting for ArgoCD to sync (30 seconds)..."
sleep 30

# Step 6: Check status
log_info "Application Status:"
kubectl get application platform-${ENV} -n argocd
echo ""

# Step 7: Check pods
log_info "BookVerse Pods:"
kubectl get pods -n $BOOKVERSE_NS 2>&1 || log_warning "Namespace not yet created"
echo ""

# Step 8: Display access info
ARGOCD_IP=$(gcloud compute addresses describe argocd-ip --global --format="value(address)" 2>/dev/null || echo "unknown")
BOOKVERSE_IP=$(gcloud compute addresses describe bookverse-web-ip --global --format="value(address)" 2>/dev/null || echo "not reserved")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_success "Access Points:"
echo "  ArgoCD:    https://argocd.rodolphef.org ($ARGOCD_IP)"
echo "  BookVerse: https://bookverse.rodolphef.org ($BOOKVERSE_IP)"
echo ""
log_info "Monitor deployment in ArgoCD UI:"
echo "  1. Login to https://argocd.rodolphef.org"
echo "  2. View application: platform-${ENV}"
echo "  3. Check sync and health status"
echo ""
log_info "Check pods:"
echo "  kubectl get pods -n $BOOKVERSE_NS"
echo ""
log_warning "If pods are in ImagePullBackOff:"
echo "  1. Verify Docker images exist in JFrog"
echo "  2. Check imagePullSecrets in namespace"
echo "  3. Verify image tags in values-gke.yaml"
echo ""

