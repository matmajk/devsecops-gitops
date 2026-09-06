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