## BookVerse GitOps (Multi-Environment)

This demo uses Argo CD to deploy across all environments (DEV, QA, STAGING, PROD). Deployments occur when AppTrust promotes artifacts through the lifecycle stages and CI/CD updates the Helm values accordingly.

### Flow
1. AppTrust promotes artifacts through lifecycle stages (DEV → QA → STAGING → PROD).
2. CI/CD updates `bookverse-helm/charts/platform/values.yaml` (chart/image versions) for each environment.
3. Argo CD auto-syncs applications to their respective namespaces:
   - `apps/prod/platform.yaml` → `bookverse-prod` namespace

### Bootstrap (All Environments)
1. Apply `gitops/bootstrap/*` (creates secrets and helm repos for all namespaces).
2. Apply `gitops/projects/bookverse-*.yaml` (creates ArgoCD projects for each environment).
3. Apply `gitops/apps/*/platform.yaml` (creates applications for each environment).

See the **Quick Kubernetes Bootstrap** section in `docs/GETTING_STARTED.md` for one-command local bootstrap.

### Policies
Policies are placeholders for demo purposes and are not enforced. See `gitops/policies/` for notes.


