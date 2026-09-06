# Argo CD

This directory contains the GitOps configuration used to deploy and
manage workloads in Kubernetes using Argo CD.

## Directory Structure

```text
argocd/
├── bootstrap/
│   └── Argo CD installation configuration
├── projects/
│   └── Argo CD AppProject definitions
└── applications/
    └── Argo CD Application definitions
```

## Bootstrap Model

Argo CD must exist before it can reconcile resources from Git.

For this reason, the initial Argo CD installation is performed manually
using the manifests stored under `bootstrap/`.

After bootstrap, application deployment and lifecycle management are
handled declaratively through Argo CD.

The local environment uses the non-HA Argo CD installation because it is
intended for development and integration testing.

The Argo CD version is explicitly pinned to provide reproducible
installations.

## Bootstrap

Render the manifests:
```bash
kubectl kustomize argocd/bootstrap
```

Install Argo CD:
```bash
kubectl apply \
  --server-side \
  --force-conflicts \
  -k argocd/bootstrap
```

Verify:

```bash
kubectl get pods -n argocd
kubectl get applications.argoproj.io -n argocd
```

## Access

Forward the Argo CD API server locally:

```bash
kubectl port-forward \
  service/argocd-server \
  -n argocd \
  8081:443
```

The UI is then available at `https://localhost:8081`

Application configuration is introduced separately and is managed using
declarative `Application` and `AppProject` resources.

## Online Boutique Application

The local Online Boutique deployment is managed through a declarative
Argo CD `Application`.

The Application uses:

- the `online-boutique` AppProject
- the Online Boutique Helm chart stored in this repository
- environment-specific values from `environments/local`
- the local Kubernetes cluster as the deployment destination
- the `online-boutique` namespace

Argo CD uses Helm to render Kubernetes manifests while Argo CD manages
the application lifecycle.

The local Application initially uses manual synchronization so changes
can be reviewed before they are applied to the cluster.

## Deployment Workflow

Changes to the application deployment configuration follow this flow:

```text
Git commit
    ↓
Git repository
    ↓
Argo CD comparison
    ↓
OutOfSync
    ↓
Manual Sync
    ↓
Kubernetes
    ↓
Synced / Healthy
```

Automated synchronization, pruning and self-healing are introduced
separately after the manual reconciliation workflow has been validated.

## Automated Reconciliation

The local Online Boutique Application uses automated GitOps
reconciliation.

Argo CD continuously compares the desired state stored in Git with the
actual state running in Kubernetes.

The Application enables:

- automated synchronization
- automatic pruning of resources removed from Git
- automatic self-healing of cluster drift
- namespace creation
- pruning after successful resource synchronization

The reconciliation model is:

```text
Git desired state
      ↓
Argo CD
      ↓
Compare
      ↓
OutOfSync
      ↓
Automatic Sync
      ↓
Kubernetes
      ↓
Synced / Healthy
```

Manual changes to Argo CD-managed application resources are considered
configuration drift and may be automatically reverted.

Application lifecycle changes should therefore be introduced through Git
rather than through direct `kubectl apply`, `kubectl edit` or Helm CLI
operations.

### Resource Ownership

Online Boutique workload lifecycle is owned by Argo CD.

For managed application resources:

Do not use:

- `helm install`
- `helm upgrade`
- `kubectl apply`
- `kubectl edit`

Use Git changes and Argo CD reconciliation instead.

`kubectl` remains appropriate for operational inspection and
troubleshooting, including:

- `kubectl get`
- `kubectl describe`
- `kubectl logs`
- `kubectl exec`
- `kubectl port-forward`