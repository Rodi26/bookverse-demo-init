# ⚡ BookVerse on GKE - Ultra Quick Start

Deploy the complete BookVerse platform on GKE in minutes with external access.

## 🎯 One-Command Deployment

```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-demo-init

# Set credentials
export JFROG_URL="https://rodolphefplus.jfrog.io"
export JFROG_USER="your-username"
export JFROG_TOKEN="your-token"

# Deploy everything
./scripts/bookverse-demo-gke.sh --setup
```

## ✅ What This Deploys

- **ArgoCD** at `https://argocd.rodolphef.org`
- **BookVerse** at `https://bookverse.rodolphef.org`
- Global static IPs for both
- Google-managed SSL certificates (automatic HTTPS)

## ⏱️ Timeline

- Script execution: 5-10 minutes
- SSL certificates: +15-60 minutes (automatic provisioning)

## 📋 Prerequisites

Before running, ensure:
1. ✅ GKE cluster is running
2. ✅ kubectl configured: `kubectl cluster-info`
3. ✅ DNS zones ready for records
4. ✅ JFrog credentials available

## 🌐 DNS Configuration

The script will display IP addresses. Create these DNS A records:

```bash
# After script shows IPs, create:
argocd.rodolphef.org    → ARGOCD_STATIC_IP
bookverse.rodolphef.org → BOOKVERSE_STATIC_IP
```

## 🔍 Check Status

```bash
./scripts/bookverse-demo-gke.sh --status
```

Example output:
```
Static IP Addresses:
  ✅ ArgoCD IP: 34.128.163.54
  ✅ BookVerse IP: 35.201.45.123

ArgoCD Status:
  Pods: 7/7 running
  ✅ Certificate: Active
  URL: https://argocd.rodolphef.org

BookVerse Status (prod):
  Pods: 5/5 running
  ✅ Certificate: Active
  URL: https://bookverse.rodolphef.org
```

## 🎉 Access

Once certificates are active:
- **ArgoCD**: https://argocd.rodolphef.org (admin / see script output for password)
- **BookVerse**: https://bookverse.rodolphef.org

## 🗑️ Cleanup

```bash
./scripts/bookverse-demo-gke.sh --cleanup
```

## 📚 Full Documentation

- **Script Guide**: `scripts/README-GKE-DEMO.md`
- **Complete Guide**: `docs/GKE-DEPLOYMENT-GUIDE.md`
- **ArgoCD Setup**: `../bookverse-demo-assets/gke-argocd/README.md`
- **BookVerse Setup**: `../bookverse-helm/gke-deployment/README-GKE.md`

---

**That's it!** The script handles everything else automatically. 🚀

