#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - GKE Demo Execution and Management Script
# =============================================================================
#
# GKE-specific demo orchestration script for the BookVerse platform
# Adapted from bookverse-demo.sh for Google Kubernetes Engine deployment
#
# 🎯 PURPOSE:
#     This script provides complete demo execution and management for BookVerse
#     on GKE with external access via Google Cloud Load Balancer, static IPs,
#     and Google-managed SSL certificates.
#
# 🏗️ GKE-SPECIFIC FEATURES:
#     - External Access: Uses Google Cloud Load Balancer (no port forwarding)
#     - Static IPs: Global static IP addresses for stable endpoints
#     - SSL Certificates: Google-managed certificates (automatic HTTPS)
#     - DNS Integration: Real domain names instead of /etc/hosts
#     - Production-Ready: Designed for external demos and production use
#
# 🚀 KEY DIFFERENCES FROM STANDARD SCRIPT:
#     - No port forwarding (uses external IPs and domains)
#     - No /etc/hosts modification (uses real DNS)
#     - GKE-specific ingress configuration
#     - Google-managed SSL certificates
#     - External load balancer integration
#
# ⚙️ PARAMETERS:
#     --setup               : First-time GKE demo setup
#     --status              : Check deployment status
#     --cleanup             : Complete demo cleanup
#     --help, -h           : Display help information
#
# 🌍 ENVIRONMENT VARIABLES:
#     ENV                  : Target environment (prod, staging, dev) [default: prod]
#     JFROG_URL           : JFrog platform URL
#     JFROG_USER          : JFrog username for image pulls
#     JFROG_TOKEN         : JFrog token/password
#     PROJECT_ID          : GCP project ID
#     ARGOCD_DOMAIN       : ArgoCD domain [default: argocd.rodolphef.org]
#     BOOKVERSE_DOMAIN    : BookVerse domain [default: bookverse.rodolphef.org]
#
# 📋 PREREQUISITES:
#     - kubectl configured for GKE cluster
#     - gcloud CLI authenticated
#     - helm v3+ installed
#     - Static IPs reserved (argocd-ip, bookverse-web-ip)
#     - DNS records configured
#
# 💡 EXAMPLES:
#     # First-time setup
#     ./scripts/bookverse-demo-gke.sh --setup
#     
#     # Check status
#     ./scripts/bookverse-demo-gke.sh --status
#     
#     # Cleanup
#     ./scripts/bookverse-demo-gke.sh --cleanup
#
# =============================================================================

set -euo pipefail

# 🔧 Core Configuration
ENV="${ENV:-prod}"
SETUP_MODE=false
STATUS_MODE=false
CLEANUP_MODE=false

ARGO_NS="argocd"
NS="bookverse-${ENV}"
APP_NAME="platform-${ENV}"

# GKE-specific domains
ARGOCD_DOMAIN="${ARGOCD_DOMAIN:-argocd.rodolphef.org}"
BOOKVERSE_DOMAIN="${BOOKVERSE_DOMAIN:-bookverse.rodolphef.org}"

# Static IP names
ARGOCD_IP_NAME="argocd-ip"
BOOKVERSE_IP_NAME="bookverse-web-ip"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${WHITE}$1${NC}"; }

usage() {
  cat <<'EOF'
🚀 BookVerse Demo - GKE Deployment

USAGE:
  ./scripts/bookverse-demo-gke.sh [OPTIONS]

OPTIONS:
  --setup        First-time GKE demo setup
                 - Reserves static IPs
                 - Deploys ArgoCD with external access
                 - Deploys BookVerse with external access
                 - Configures SSL certificates

  --status       Check deployment status
                 - Verify static IPs
                 - Check DNS configuration
                 - Validate SSL certificates
                 - Display access URLs

  --cleanup      Complete demo cleanup
                 - Delete all BookVerse resources
                 - Delete ArgoCD resources
                 - Optionally delete static IPs

  --help, -h     Display this help message

ENVIRONMENT VARIABLES:
  ENV                    Target environment (prod|staging|dev) [default: prod]
  JFROG_URL             JFrog platform URL (required)
  JFROG_USER            JFrog username (required for setup)
  JFROG_TOKEN           JFrog token (required for setup)
  PROJECT_ID            GCP project ID (auto-detected if not set)
  ARGOCD_DOMAIN         ArgoCD domain [default: argocd.rodolphef.org]
  BOOKVERSE_DOMAIN      BookVerse domain [default: bookverse.rodolphef.org]

EXAMPLES:
  # First-time setup
  export JFROG_URL="https://rodolphefplus.jfrog.io"
  export JFROG_USER="your-user"
  export JFROG_TOKEN="your-token"
  ./scripts/bookverse-demo-gke.sh --setup

  # Check status
  ./scripts/bookverse-demo-gke.sh --status

  # Cleanup
  ./scripts/bookverse-demo-gke.sh --cleanup

ACCESS URLS (after deployment):
  ArgoCD:    https://argocd.rodolphef.org
  BookVerse: https://bookverse.rodolphef.org

PREREQUISITES:
  - GKE cluster running
  - kubectl configured
  - gcloud CLI authenticated
  - helm installed
  - DNS records configured for domains

For detailed documentation, see:
  - bookverse-demo-assets/gke-argocd/README.md
  - bookverse-helm/gke-deployment/README-GKE.md

EOF
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_prerequisites() {
  log_info "Validating prerequisites..."

  local missing_tools=()
  
  command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
  command -v gcloud >/dev/null 2>&1 || missing_tools+=("gcloud")
  command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
  
  if [ ${#missing_tools[@]} -ne 0 ]; then
    log_error "Missing required tools: ${missing_tools[*]}"
    log_error "Please install the missing tools and try again"
    exit 1
  fi

  if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "kubectl not configured or GKE cluster not accessible"
    log_error "Please ensure your GKE cluster is running and kubectl is configured"
    exit 1
  fi

  log_success "All prerequisites validated"
}

validate_environment() {
  log_info "Validating environment variables..."

  if [[ "${SETUP_MODE}" == "true" ]]; then
    if [[ -z "${JFROG_URL:-}" ]]; then
      log_error "JFROG_URL environment variable not set"
      log_error "Example: export JFROG_URL='https://rodolphefplus.jfrog.io'"
      exit 1
    fi

    if [[ -z "${JFROG_USER:-}" ]]; then
      log_error "JFROG_USER environment variable not set"
      log_error "Required for creating image pull secrets"
      exit 1
    fi

    if [[ -z "${JFROG_TOKEN:-}" ]]; then
      log_error "JFROG_TOKEN environment variable not set"
      log_error "Required for creating image pull secrets"
      exit 1
    fi
  fi

  # Auto-detect project ID if not set
  if [[ -z "${PROJECT_ID:-}" ]]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [[ -z "${PROJECT_ID}" ]]; then
      log_warning "PROJECT_ID not set and could not auto-detect from gcloud"
      if [[ "${SETUP_MODE}" == "true" ]]; then
        log_error "PROJECT_ID required for setup mode"
        exit 1
      fi
    fi
  fi

  log_success "Environment variables validated"
  log_info "Environment: ${ENV}"
  log_info "GCP Project: ${PROJECT_ID:-not set}"
  log_info "ArgoCD Domain: ${ARGOCD_DOMAIN}"
  log_info "BookVerse Domain: ${BOOKVERSE_DOMAIN}"
  if [[ -n "${JFROG_URL:-}" ]]; then
    log_info "JFrog URL: ${JFROG_URL}"
  fi
}

# =============================================================================
# STATIC IP MANAGEMENT
# =============================================================================

check_static_ip() {
  local ip_name="$1"
  local ip_var_name="$2"
  
  if gcloud compute addresses describe "$ip_name" --global --project="${PROJECT_ID}" &>/dev/null; then
    local ip=$(gcloud compute addresses describe "$ip_name" --global --project="${PROJECT_ID}" --format="value(address)")
    eval "$ip_var_name='$ip'"
    return 0
  else
    return 1
  fi
}

reserve_static_ips() {
  log_step "📌 Reserving Static IP Addresses"
  echo ""
  
  # ArgoCD IP
  log_info "Checking ArgoCD static IP ($ARGOCD_IP_NAME)..."
  if check_static_ip "$ARGOCD_IP_NAME" "ARGOCD_IP"; then
    log_success "ArgoCD static IP already exists: $ARGOCD_IP"
  else
    log_info "Creating ArgoCD static IP..."
    gcloud compute addresses create "$ARGOCD_IP_NAME" --global --project="${PROJECT_ID}"
    check_static_ip "$ARGOCD_IP_NAME" "ARGOCD_IP"
    log_success "ArgoCD static IP created: $ARGOCD_IP"
  fi
  
  # BookVerse IP
  log_info "Checking BookVerse static IP ($BOOKVERSE_IP_NAME)..."
  if check_static_ip "$BOOKVERSE_IP_NAME" "BOOKVERSE_IP"; then
    log_success "BookVerse static IP already exists: $BOOKVERSE_IP"
  else
    log_info "Creating BookVerse static IP..."
    gcloud compute addresses create "$BOOKVERSE_IP_NAME" --global --project="${PROJECT_ID}"
    check_static_ip "$BOOKVERSE_IP_NAME" "BOOKVERSE_IP"
    log_success "BookVerse static IP created: $BOOKVERSE_IP"
  fi
  
  echo ""
  log_success "Static IPs configured:"
  echo "  ArgoCD:    $ARGOCD_DOMAIN → $ARGOCD_IP"
  echo "  BookVerse: $BOOKVERSE_DOMAIN → $BOOKVERSE_IP"
  echo ""
}

check_dns_configuration() {
  log_step "🌐 Checking DNS Configuration"
  echo ""
  
  local dns_ok=true
  
  # Check ArgoCD DNS
  log_info "Checking ArgoCD DNS ($ARGOCD_DOMAIN)..."
  if RESOLVED_IP=$(dig +short "$ARGOCD_DOMAIN" 2>/dev/null | tail -1); then
    if [[ -n "$RESOLVED_IP" && "$RESOLVED_IP" == "${ARGOCD_IP}" ]]; then
      log_success "ArgoCD DNS correctly configured: $ARGOCD_DOMAIN → $RESOLVED_IP"
    else
      log_warning "ArgoCD DNS mismatch or not configured"
      log_warning "Expected: $ARGOCD_IP, Got: ${RESOLVED_IP:-none}"
      dns_ok=false
    fi
  else
    log_warning "Could not resolve $ARGOCD_DOMAIN"
    dns_ok=false
  fi
  
  # Check BookVerse DNS
  log_info "Checking BookVerse DNS ($BOOKVERSE_DOMAIN)..."
  if RESOLVED_IP=$(dig +short "$BOOKVERSE_DOMAIN" 2>/dev/null | tail -1); then
    if [[ -n "$RESOLVED_IP" && "$RESOLVED_IP" == "${BOOKVERSE_IP}" ]]; then
      log_success "BookVerse DNS correctly configured: $BOOKVERSE_DOMAIN → $RESOLVED_IP"
    else
      log_warning "BookVerse DNS mismatch or not configured"
      log_warning "Expected: $BOOKVERSE_IP, Got: ${RESOLVED_IP:-none}"
      dns_ok=false
    fi
  else
    log_warning "Could not resolve $BOOKVERSE_DOMAIN"
    dns_ok=false
  fi
  
  echo ""
  if [[ "$dns_ok" == "false" ]]; then
    log_warning "DNS Configuration Required!"
    echo ""
    echo "  Please create the following DNS A records:"
    echo ""
    echo "  Record 1:"
    echo "    Name: $ARGOCD_DOMAIN"
    echo "    Type: A"
    echo "    Value: ${ARGOCD_IP:-not yet reserved}"
    echo ""
    echo "  Record 2:"
    echo "    Name: $BOOKVERSE_DOMAIN"
    echo "    Type: A"
    echo "    Value: ${BOOKVERSE_IP:-not yet reserved}"
    echo ""
    if [[ "${SETUP_MODE}" == "true" ]]; then
      read -p "Press Enter to continue after configuring DNS (or Ctrl+C to abort)..."
    fi
  fi
  echo ""
}

# =============================================================================
# ARGOCD SETUP
# =============================================================================

setup_argocd_gke() {
  log_step "🔧 Setting up ArgoCD on GKE with External Access"
  echo ""
  
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local argocd_gke_dir="${script_dir}/../../bookverse-demo-assets/gke-argocd"
  
  if [[ ! -d "${argocd_gke_dir}" ]]; then
    log_error "ArgoCD GKE configuration not found at: ${argocd_gke_dir}"
    log_error "Please ensure bookverse-demo-assets repository is cloned"
    exit 1
  fi
  
  cd "${argocd_gke_dir}"
  
  # Deploy ArgoCD
  log_info "Deploying ArgoCD to GKE..."
  
  # Create namespace
  kubectl apply -f 00-argocd-namespace.yaml
  
  # Add Helm repo
  helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
  helm repo update >/dev/null 2>&1
  
  # Create managed certificate
  kubectl apply -f 02-argocd-managed-certificate.yaml
  
  # Deploy ArgoCD with GKE values
  helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --values 03-argocd-values-gke.yaml \
    --wait \
    --timeout 10m
  
  # Apply GKE ingress
  kubectl apply -f 01-argocd-ingress.yaml
  
  log_success "ArgoCD deployed to GKE"
  
  # Get admin password
  ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
  
  echo ""
  log_success "ArgoCD Credentials:"
  echo "  URL: https://${ARGOCD_DOMAIN}"
  echo "  Username: admin"
  if [[ -n "$ARGOCD_PASSWORD" ]]; then
    echo "  Password: $ARGOCD_PASSWORD"
  else
    echo "  Password: (run command below to retrieve)"
    echo "    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
  fi
  echo ""
  
  log_warning "Note: SSL certificate provisioning takes 15-60 minutes"
  log_info "Monitor with: kubectl get managedcertificate -n argocd -w"
  echo ""
}

# =============================================================================
# BOOKVERSE SETUP
# =============================================================================

setup_bookverse_gke() {
  log_step "🚀 Setting up BookVerse on GKE with External Access"
  echo ""
  
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local bookverse_gke_dir="${script_dir}/../../bookverse-helm/gke-deployment"
  
  if [[ ! -d "${bookverse_gke_dir}" ]]; then
    log_error "BookVerse GKE configuration not found at: ${bookverse_gke_dir}"
    log_error "Please ensure bookverse-helm repository is up to date"
    exit 1
  fi
  
  # Create namespaces
  log_info "Creating BookVerse namespaces..."
  kubectl apply -f "${bookverse_gke_dir}/k8s-manifests/01-namespace.yaml"
  
  # Create image pull secrets
  log_info "Creating JFrog image pull secrets..."
  for ns in bookverse-dev bookverse-qa bookverse-staging bookverse-prod; do
    kubectl create secret docker-registry jfrog-docker-pull \
      --docker-server="${JFROG_URL#https://}" \
      --docker-username="${JFROG_USER}" \
      --docker-password="${JFROG_TOKEN}" \
      --namespace="$ns" \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  done
  log_success "Image pull secrets created"
  
  # Create managed certificates
  log_info "Creating Google-managed SSL certificates..."
  kubectl apply -f "${bookverse_gke_dir}/k8s-manifests/02-managed-certificate.yaml"
  
  # Deploy with Helm
  log_info "Deploying BookVerse with Helm..."
  cd "${script_dir}/../../bookverse-helm"
  
  helm upgrade --install bookverse-platform ./charts/platform \
    --namespace "${NS}" \
    --values gke-deployment/values-gke.yaml \
    --set web.ingress.host="${BOOKVERSE_DOMAIN}" \
    --create-namespace \
    --wait \
    --timeout 10m
  
  # Apply GKE ingress
  log_info "Applying GKE Ingress..."
  kubectl apply -f "${bookverse_gke_dir}/k8s-manifests/03-gke-ingress.yaml"
  
  log_success "BookVerse deployed to GKE"
  
  echo ""
  log_success "BookVerse Access:"
  echo "  URL: https://${BOOKVERSE_DOMAIN}"
  echo ""
  
  log_warning "Note: SSL certificate provisioning takes 15-60 minutes"
  log_info "Monitor with: kubectl get managedcertificate -n ${NS} -w"
  echo ""
}

# =============================================================================
# STATUS CHECKING
# =============================================================================

check_deployment_status() {
  log_step "📊 Deployment Status Check"
  echo ""
  
  # Get static IPs
  log_info "Static IP Addresses:"
  if check_static_ip "$ARGOCD_IP_NAME" "ARGOCD_IP"; then
    echo "  ✅ ArgoCD IP: $ARGOCD_IP"
  else
    echo "  ❌ ArgoCD IP: Not reserved"
  fi
  
  if check_static_ip "$BOOKVERSE_IP_NAME" "BOOKVERSE_IP"; then
    echo "  ✅ BookVerse IP: $BOOKVERSE_IP"
  else
    echo "  ❌ BookVerse IP: Not reserved"
  fi
  echo ""
  
  # Check ArgoCD
  log_info "ArgoCD Status:"
  if kubectl get namespace argocd >/dev/null 2>&1; then
    local argocd_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
    local argocd_ready=$(kubectl get pods -n argocd --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    echo "  Pods: $argocd_ready/$argocd_pods running"
    
    # Check ingress
    if kubectl get ingress argocd-server-ingress -n argocd >/dev/null 2>&1; then
      local argocd_ip=$(kubectl get ingress argocd-server-ingress -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
      echo "  Ingress IP: $argocd_ip"
    fi
    
    # Check certificate
    if kubectl get managedcertificate argocd-cert -n argocd >/dev/null 2>&1; then
      local cert_status=$(kubectl get managedcertificate argocd-cert -n argocd -o jsonpath='{.status.certificateStatus}' 2>/dev/null || echo "unknown")
      if [[ "$cert_status" == "Active" ]]; then
        echo "  ✅ Certificate: Active"
      else
        echo "  ⏳ Certificate: $cert_status (provisioning...)"
      fi
    fi
    
    echo "  URL: https://${ARGOCD_DOMAIN}"
  else
    echo "  ❌ Not deployed"
  fi
  echo ""
  
  # Check BookVerse
  log_info "BookVerse Status (${ENV}):"
  if kubectl get namespace "${NS}" >/dev/null 2>&1; then
    local bv_pods=$(kubectl get pods -n "${NS}" --no-headers 2>/dev/null | wc -l)
    local bv_ready=$(kubectl get pods -n "${NS}" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    echo "  Pods: $bv_ready/$bv_pods running"
    
    # Check ingress
    if kubectl get ingress bookverse-web-ingress -n "${NS}" >/dev/null 2>&1; then
      local bv_ip=$(kubectl get ingress bookverse-web-ingress -n "${NS}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
      echo "  Ingress IP: $bv_ip"
    fi
    
    # Check certificate
    local cert_name="bookverse-web-cert-${ENV}"
    if kubectl get managedcertificate "$cert_name" -n "${NS}" >/dev/null 2>&1; then
      local cert_status=$(kubectl get managedcertificate "$cert_name" -n "${NS}" -o jsonpath='{.status.certificateStatus}' 2>/dev/null || echo "unknown")
      if [[ "$cert_status" == "Active" ]]; then
        echo "  ✅ Certificate: Active"
      else
        echo "  ⏳ Certificate: $cert_status (provisioning...)"
      fi
    fi
    
    echo "  URL: https://${BOOKVERSE_DOMAIN}"
  else
    echo "  ❌ Not deployed"
  fi
  echo ""
  
  # Display access URLs
  log_success "Access URLs:"
  echo "  ArgoCD:    https://${ARGOCD_DOMAIN}"
  echo "  BookVerse: https://${BOOKVERSE_DOMAIN}"
  echo ""
  
  # Check DNS
  check_dns_configuration
}

# =============================================================================
# CLEANUP
# =============================================================================

cleanup_demo_gke() {
  log_step "🗑️  Cleaning up BookVerse GKE Demo"
  echo ""
  
  # Delete BookVerse
  log_info "Deleting BookVerse application..."
  helm uninstall bookverse-platform -n "${NS}" 2>/dev/null || log_warning "BookVerse Helm release not found"
  kubectl delete namespace "${NS}" --ignore-not-found=true
  
  # Delete ArgoCD
  log_info "Deleting ArgoCD..."
  helm uninstall argocd -n argocd 2>/dev/null || log_warning "ArgoCD Helm release not found"
  kubectl delete namespace argocd --ignore-not-found=true
  
  # Ask about static IPs
  echo ""
  log_warning "Static IP Cleanup"
  echo "Static IPs will incur costs if left reserved."
  read -p "Delete static IPs? (y/N): " delete_ips
  
  if [[ "$delete_ips" =~ ^[Yy]$ ]]; then
    log_info "Deleting static IPs..."
    gcloud compute addresses delete "$ARGOCD_IP_NAME" --global --project="${PROJECT_ID}" --quiet 2>/dev/null || true
    gcloud compute addresses delete "$BOOKVERSE_IP_NAME" --global --project="${PROJECT_ID}" --quiet 2>/dev/null || true
    log_success "Static IPs deleted"
  else
    log_info "Static IPs preserved"
    echo "  To delete later:"
    echo "    gcloud compute addresses delete $ARGOCD_IP_NAME --global"
    echo "    gcloud compute addresses delete $BOOKVERSE_IP_NAME --global"
  fi
  
  echo ""
  log_success "Demo cleanup completed"
  echo ""
  log_info "DNS records should also be removed manually if no longer needed"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --setup)
        SETUP_MODE=true
        shift
        ;;
      --status)
        STATUS_MODE=true
        shift
        ;;
      --cleanup)
        CLEANUP_MODE=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
  
  # Header
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🚀 BookVerse Platform - GKE Demo Manager"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Validate prerequisites
  validate_prerequisites
  validate_environment
  
  # Execute mode
  if [[ "${CLEANUP_MODE}" == "true" ]]; then
    # Get IPs before cleanup for display
    check_static_ip "$ARGOCD_IP_NAME" "ARGOCD_IP" || ARGOCD_IP="unknown"
    check_static_ip "$BOOKVERSE_IP_NAME" "BOOKVERSE_IP" || BOOKVERSE_IP="unknown"
    cleanup_demo_gke
    
  elif [[ "${STATUS_MODE}" == "true" ]]; then
    check_static_ip "$ARGOCD_IP_NAME" "ARGOCD_IP" || ARGOCD_IP="not reserved"
    check_static_ip "$BOOKVERSE_IP_NAME" "BOOKVERSE_IP" || BOOKVERSE_IP="not reserved"
    check_deployment_status
    
  elif [[ "${SETUP_MODE}" == "true" ]]; then
    echo "🔧 BookVerse Demo - GKE First-Time Setup"
    echo "=========================================="
    echo ""
    
    # Step 1: Reserve static IPs
    reserve_static_ips
    
    # Step 2: Check DNS
    check_dns_configuration
    
    # Step 3: Deploy ArgoCD
    setup_argocd_gke
    
    # Step 4: Deploy BookVerse
    setup_bookverse_gke
    
    # Step 5: Final status
    echo ""
    log_step "🎉 Setup Complete!"
    echo "===================="
    echo ""
    log_success "Demo Endpoints:"
    echo "  ArgoCD:    https://${ARGOCD_DOMAIN}"
    echo "  BookVerse: https://${BOOKVERSE_DOMAIN}"
    echo ""
    log_warning "Next Steps:"
    echo "  1. ⏱️  Wait 15-60 minutes for SSL certificates to provision"
    echo "  2. 🔍 Check status: ./scripts/bookverse-demo-gke.sh --status"
    echo "  3. 🌐 Access ArgoCD and configure BookVerse repositories"
    echo "  4. 🚀 Deploy BookVerse apps via ArgoCD"
    echo ""
    
  else
    # Default: Show status
    check_static_ip "$ARGOCD_IP_NAME" "ARGOCD_IP" || ARGOCD_IP="not reserved"
    check_static_ip "$BOOKVERSE_IP_NAME" "BOOKVERSE_IP" || BOOKVERSE_IP="not reserved"
    check_deployment_status
    
    log_info "Tip: Use --setup for first-time deployment or --cleanup to remove everything"
  fi
  
  echo ""
}

# Execute main function
main "$@"

