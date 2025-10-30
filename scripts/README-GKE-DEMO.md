# 🚀 BookVerse GKE Demo Script

Automated demo setup and management script for BookVerse on Google Kubernetes Engine.

## 📋 Overview

`bookverse-demo-gke.sh` is the GKE-optimized version of `bookverse-demo.sh` that handles:
- Complete GKE deployment with external access
- Static IP reservation and management
- DNS configuration validation
- SSL certificate setup and monitoring
- ArgoCD and BookVerse deployment
- Demo lifecycle management

## 🎯 Key Differences from Standard Script

| Feature | Standard Script | GKE Script |
|---------|----------------|------------|
| **Access** | Port forwarding (localhost) | External (Load Balancer + Static IP) |
| **Domains** | /etc/hosts (local) | Real DNS records |
| **SSL** | None or self-signed | Google-Managed certificates |
| **Ingress** | Generic/Traefik | GKE Ingress (GCE) |
| **Use Case** | Local development/demos | Production demos / External access |

## ⚡ Quick Start

### First-Time Setup

```bash
# Set environment variables
export JFROG_URL="https://rodolphefplus.jfrog.io"
export JFROG_USER="your-username"
export JFROG_TOKEN="your-token"
export PROJECT_ID="your-gcp-project"  # Optional (auto-detected)

# Run setup
cd /Users/rodolphefontaine/bookverse-demo/bookverse-demo-init
./scripts/bookverse-demo-gke.sh --setup
```

### Check Status

```bash
./scripts/bookverse-demo-gke.sh --status
```

### Cleanup

```bash
./scripts/bookverse-demo-gke.sh --cleanup
```

## 📚 Usage

```bash
./scripts/bookverse-demo-gke.sh [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--setup` | First-time GKE demo setup |
| `--status` | Check deployment status and URLs |
| `--cleanup` | Complete demo cleanup |
| `--help` | Display help message |

### Default Behavior

Running without options shows deployment status (same as `--status`).

## 🔧 What --setup Does

The `--setup` command performs a complete GKE deployment:

1. **Validates Prerequisites**
   - Checks kubectl, gcloud, helm
   - Validates GKE cluster access
   - Verifies environment variables

2. **Reserves Static IPs**
   - `argocd-ip` for ArgoCD
   - `bookverse-web-ip` for BookVerse

3. **Checks DNS Configuration**
   - Validates DNS records point to static IPs
   - Prompts if DNS not configured

4. **Deploys ArgoCD**
   - Creates namespace
   - Installs ArgoCD with GKE-specific values
   - Creates Google-managed SSL certificate
   - Applies GKE ingress
   - Displays admin credentials

5. **Deploys BookVerse**
   - Creates namespaces (dev/qa/staging/prod)
   - Creates JFrog image pull secrets
   - Creates Google-managed SSL certificates
   - Deploys with Helm using GKE values
   - Applies GKE ingress

6. **Displays Status**
   - Shows access URLs
   - Displays SSL certificate status
   - Provides next steps

## 🌍 Environment Variables

### Required for Setup

| Variable | Description | Example |
|----------|-------------|---------|
| `JFROG_URL` | JFrog platform URL | `https://rodolphefplus.jfrog.io` |
| `JFROG_USER` | JFrog username | `your-user` |
| `JFROG_TOKEN` | JFrog token/password | `your-token` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `PROJECT_ID` | GCP project ID | Auto-detected from gcloud |
| `ENV` | Target environment | `prod` |
| `ARGOCD_DOMAIN` | ArgoCD domain | `argocd.rodolphef.org` |
| `BOOKVERSE_DOMAIN` | BookVerse domain | `bookverse.rodolphef.org` |

## 📊 Setup Flow

```
┌─────────────────────────────────────┐
│  1. Validate Prerequisites          │
│     ✓ kubectl, gcloud, helm         │
│     ✓ GKE cluster access            │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│  2. Reserve Static IPs              │
│     • argocd-ip (global)            │
│     • bookverse-web-ip (global)     │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│  3. Validate DNS Configuration      │
│     • argocd.rodolphef.org          │
│     • bookverse.rodolphef.org       │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│  4. Deploy ArgoCD                   │
│     • Helm install with GKE values  │
│     • Create managed certificate    │
│     • Apply GKE ingress             │
│     • Display admin credentials     │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│  5. Deploy BookVerse                │
│     • Create namespaces             │
│     • Create image pull secrets     │
│     • Create managed certificates   │
│     • Helm install with GKE values  │
│     • Apply GKE ingress             │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│  6. Display Status & Next Steps     │
│     ✓ Access URLs                   │
│     ✓ Certificate status            │
│     ✓ Deployment summary            │
└─────────────────────────────────────┘
```

## ✅ Success Criteria

After running `--setup`, you should see:

```
✅ Static IPs reserved
✅ ArgoCD deployed and accessible
✅ BookVerse deployed and accessible
⏳ SSL certificates provisioning (15-60 minutes)
```

## 🔍 Status Check Example

```bash
$ ./scripts/bookverse-demo-gke.sh --status

📊 Deployment Status Check

Static IP Addresses:
  ✅ ArgoCD IP: 34.128.163.54
  ✅ BookVerse IP: 35.201.45.123

ArgoCD Status:
  Pods: 7/7 running
  Ingress IP: 34.128.163.54
  ✅ Certificate: Active
  URL: https://argocd.rodolphef.org

BookVerse Status (prod):
  Pods: 5/5 running
  Ingress IP: 35.201.45.123
  ✅ Certificate: Active
  URL: https://bookverse.rodolphef.org

Access URLs:
  ArgoCD:    https://argocd.rodolphef.org
  BookVerse: https://bookverse.rodolphef.org
```

## 🐛 Troubleshooting

### Script Exits with Missing Tools

Ensure you have:
```bash
kubectl version --client
gcloud version
helm version
```

### Cannot Access GKE Cluster

```bash
# Configure kubectl for your GKE cluster
gcloud container clusters get-credentials YOUR_CLUSTER \
  --region=YOUR_REGION \
  --project=YOUR_PROJECT
```

### DNS Not Configured

The script will detect and prompt you. Configure DNS records before proceeding:
```bash
# Using Google Cloud DNS
gcloud dns record-sets create argocd.rodolphef.org. \
  --zone=YOUR_ZONE \
  --type=A \
  --rrdatas=YOUR_ARGOCD_IP

gcloud dns record-sets create bookverse.rodolphef.org. \
  --zone=YOUR_ZONE \
  --type=A \
  --rrdatas=YOUR_BOOKVERSE_IP
```

### Certificate Stuck in Provisioning

- Wait 15-60 minutes
- Verify DNS points to correct IP
- Check domain is accessible on port 80/443

```bash
# Check certificate status
kubectl get managedcertificate -n argocd
kubectl get managedcertificate -n bookverse-prod
```

## 📦 What Gets Deployed

### ArgoCD (namespace: argocd)
- ArgoCD server, repo-server, application-controller
- Redis
- GKE Ingress with static IP
- Google-managed SSL certificate

### BookVerse (namespace: bookverse-prod)
- Web frontend
- Inventory service
- Recommendations service  
- Checkout service
- GKE Ingress with static IP
- Google-managed SSL certificate

## 💰 Cost Implications

Running this script will create:
- 2x Global static IPs (~$7/month each)
- 2x Google-managed SSL certificates (free)
- GKE Load Balancer resources (variable)

The `--cleanup` command offers to delete static IPs to stop recurring costs.

## 🔗 Related Documentation

- **ArgoCD GKE Setup**: `../bookverse-demo-assets/gke-argocd/README.md`
- **BookVerse GKE Setup**: `../bookverse-helm/gke-deployment/README-GKE.md`
- **Complete GKE Guide**: `../GKE-DEPLOYMENT-GUIDE.md`

## 📝 Notes

- This script is inspired by `bookverse-demo.sh` but adapted for GKE
- Uses external access instead of port forwarding
- Designed for production demos with external audiences
- All GKE-specific configurations are isolated in dedicated directories

---

**Tip**: Run `--status` regularly to monitor certificate provisioning progress!

