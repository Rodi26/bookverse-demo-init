# 🚀 Complete BookVerse GKE Deployment Guide

Complete guide for deploying BookVerse and ArgoCD on Google Kubernetes Engine with external access.

## 📦 Overview

This guide covers deploying the complete BookVerse platform on GKE with:
- ✅ ArgoCD for GitOps management
- ✅ BookVerse application platform
- ✅ External access via Google Cloud Load Balancer
- ✅ Global static IPs
- ✅ Google-managed SSL certificates

## 🗂️ GKE Configuration Locations

All GKE-specific configurations are **isolated** and do NOT modify existing files:

### 1. ArgoCD GKE Configuration
**Location**: `bookverse-demo-assets/gke-argocd/`
```
gke-argocd/
├── README.md                           # ArgoCD GKE guide
├── deploy-argocd-gke.sh               # Automated ArgoCD deployment
├── 00-argocd-namespace.yaml           # Namespace
├── 01-argocd-ingress.yaml             # Ingress with static IP
├── 02-argocd-managed-certificate.yaml # SSL certificate
└── 03-argocd-values-gke.yaml          # Helm values
```

### 2. BookVerse GKE Configuration
**Location**: `bookverse-helm/gke-deployment/`
```
gke-deployment/
├── README-GKE.md                      # Main guide
├── QUICKSTART.md                      # Quick start
├── INDEX.md                           # File index
├── deploy-to-gke.sh                  # Automated deployment
├── setup-gke-ingress.sh              # Static IP setup
├── generate-docker-secret.sh         # JFrog secrets
├── values-gke.yaml                   # Helm values
└── k8s-manifests/                    # K8s resources
    ├── 01-namespace.yaml
    ├── 02-managed-certificate.yaml
    ├── 03-gke-ingress.yaml
    └── 04-image-pull-secret.yaml.template
```

## 🎯 Deployment Architecture

```
Google Cloud Platform
├── Static IPs
│   ├── argocd-ip         (for ArgoCD)
│   └── bookverse-web-ip  (for BookVerse)
│
├── DNS Records
│   ├── argocd.rodolphef.org → argocd-ip
│   └── bookverse.rodolphef.org → bookverse-web-ip
│
└── GKE Cluster
    ├── argocd namespace
    │   └── ArgoCD (GitOps management)
    │       ↓
    └── bookverse-{dev,qa,staging,prod} namespaces
        └── BookVerse Application Platform
            ├── Web Frontend
            ├── Inventory Service
            ├── Recommendations Service
            └── Checkout Service
```

## 🚀 Deployment Methods

### Method 1: Automated Script (Recommended)

Use the all-in-one GKE demo script:

```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-demo-init

# Set environment variables
export JFROG_URL="https://rodolphefplus.jfrog.io"
export JFROG_USER="your-username"
export JFROG_TOKEN="your-token"

# Run automated setup
./scripts/bookverse-demo-gke.sh --setup
```

This script will:
- ✅ Reserve both static IPs
- ✅ Validate DNS configuration
- ✅ Deploy ArgoCD with external access
- ✅ Deploy BookVerse with external access
- ✅ Configure SSL certificates
- ✅ Display access credentials

**Check status anytime:**
```bash
./scripts/bookverse-demo-gke.sh --status
```

### Method 2: Manual Step-by-Step

## 🚀 Complete Deployment Steps

### Phase 1: Deploy ArgoCD (15-20 minutes + certificate provisioning)

```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-demo-assets/gke-argocd

# 1. Reserve static IP for ArgoCD
gcloud compute addresses create argocd-ip --global
ARGOCD_IP=$(gcloud compute addresses describe argocd-ip --global --format="value(address)")

# 2. Configure DNS: argocd.rodolphef.org → $ARGOCD_IP

# 3. Deploy ArgoCD
./deploy-argocd-gke.sh

# 4. Wait for certificate (15-60 minutes)
kubectl get managedcertificate -n argocd -w

# 5. Access ArgoCD
# URL: https://argocd.rodolphef.org
# Username: admin
# Password: (displayed by script)
```

### Phase 2: Configure ArgoCD (5-10 minutes)

In ArgoCD UI at `https://argocd.rodolphef.org`:

1. **Add JFrog Helm Repositories**
   - Settings → Repositories → Connect Repo
   - Add both `bookverse-helm-internal` and `bookverse-helm-release`

2. **Add GitHub Repository**
   - URL: `https://github.com/Rodi26/bookverse-demo-assets.git`

3. **Create ArgoCD Projects** (optional)
   - Use definitions in `gitops/projects/`

### Phase 3: Deploy BookVerse (5-10 minutes + certificate provisioning)

```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-helm/gke-deployment

# 1. Reserve static IP for BookVerse
gcloud compute addresses create bookverse-web-ip --global
BOOKVERSE_IP=$(gcloud compute addresses describe bookverse-web-ip --global --format="value(address)")

# 2. Configure DNS: bookverse.rodolphef.org → $BOOKVERSE_IP

# 3. Deploy BookVerse
./deploy-to-gke.sh

# 4. Wait for certificate (15-60 minutes)
kubectl get managedcertificate -n bookverse-prod -w

# 5. Access BookVerse
# URL: https://bookverse.rodolphef.org
```

### Phase 4: Configure GitOps (ArgoCD manages BookVerse)

In ArgoCD UI, create applications from:
- `gitops/apps/dev/platform.yaml`
- `gitops/apps/qa/platform.yaml`
- `gitops/apps/staging/platform.yaml`
- `gitops/apps/prod/platform.yaml`

## 📊 Static IPs Summary

| Resource | IP Name | Domain | Purpose |
|----------|---------|--------|---------|
| ArgoCD | `argocd-ip` | `argocd.rodolphef.org` | GitOps management UI |
| BookVerse | `bookverse-web-ip` | `bookverse.rodolphef.org` | Application platform |

## ✅ Verification Checklist

### ArgoCD
- [ ] Static IP reserved and configured
- [ ] DNS record created and propagated
- [ ] Certificate status: ACTIVE
- [ ] ArgoCD UI accessible via HTTPS
- [ ] JFrog Helm repos added
- [ ] GitHub repo added

### BookVerse
- [ ] Static IP reserved and configured
- [ ] DNS record created and propagated
- [ ] Certificate status: ACTIVE
- [ ] All pods running
- [ ] Ingress has external IP
- [ ] Application accessible via HTTPS

## 🔐 Security Notes

- Both ArgoCD and BookVerse use Google-managed SSL certificates
- TLS is enforced for all external access
- JFrog credentials stored as Kubernetes secrets
- Admin passwords should be changed after initial deployment

## 💰 Cost Considerations

**Resources created:**
- 2x Global static IPs (~$7/month each)
- 2x Google-managed SSL certificates (free)
- GKE Ingress / Load Balancer (variable based on traffic)

**Optimization tips:**
- Use regional IPs if not serving global traffic
- Use preemptible nodes for non-prod environments
- Configure autoscaling based on actual usage

## 📚 Documentation Links

### Automated Deployment
- **GKE Demo Script**: `bookverse-demo-init/scripts/bookverse-demo-gke.sh`
- **Script Documentation**: `bookverse-demo-init/scripts/README-GKE-DEMO.md`

### Manual Deployment
- **ArgoCD GKE Setup**: `bookverse-demo-assets/gke-argocd/README.md`
- **BookVerse GKE Setup**: `bookverse-helm/gke-deployment/README-GKE.md`
- **Quick Start**: `bookverse-helm/gke-deployment/QUICKSTART.md`

## 🎉 Success Criteria

When everything is working:
1. ✅ ArgoCD accessible at: `https://argocd.rodolphef.org`
2. ✅ BookVerse accessible at: `https://bookverse.rodolphef.org`
3. ✅ Both using Google-managed SSL certificates
4. ✅ ArgoCD managing BookVerse deployments via GitOps

---

**Note**: All GKE configurations are isolated in separate directories and do not modify any existing files.

