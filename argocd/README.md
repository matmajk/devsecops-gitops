# Argo CD

Argo CD provides the reconciliation layer between the desired state stored in Git and workloads running in Kubernetes.

Local Kind and GCP/GKE use separate desired-state roots.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Bootstrap Model](#bootstrap-model)
- [GitOps Hierarchy](#gitops-hierarchy)
- [Resource Ownership](#resource-ownership)
- [Local Environment](#local-environment)
- [GCP Environment](#gcp-environment)
- [Validation](#validation)
- [Related Documentation](#related-documentation)

## Directory Structure

```text
argocd/
├── bootstrap/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── root-application.yaml
│   ├── platform-bootstrap-gcp-project.yaml
│   └── platform-root-gcp.yaml
│
├── local/
│   ├── applications/
│   ├── projects/
│   ├── kustomization.yaml
│   └── README.md
│
├── gcp/
│   ├── applications/
│   ├── projects/
│   ├── kustomization.yaml
│   └── README.md
│
└── README.md
```

Reusable Helm charts remain under `applications/`.

Environment-specific Helm values remain under `environments/`.

## Bootstrap Model

Argo CD must exist before it can reconcile desired state from Git.

Bootstrap resources are stored under:

```text
argocd/bootstrap/
```

After bootstrap, workload lifecycle is managed declaratively through Git.

### Local Root

```text
argocd/bootstrap/root-application.yaml
        ↓
argocd/local/
```

### GCP Root

```text
argocd/bootstrap/platform-bootstrap-gcp-project.yaml
argocd/bootstrap/platform-root-gcp.yaml
        ↓
argocd/gcp/
```

The separate roots prevent local Applications from being reconciled by GKE and GCP Applications from being reconciled by Kind.

## GitOps Hierarchy

Local:

```text
platform-root
    ↓
argocd/local
    ├── AppProjects
    └── Applications
        ├── Online Boutique
        └── Observability
```

GCP:

```text
platform-root-gcp
    ↓
argocd/gcp
    ├── AppProjects
    └── Applications
        └── Online Boutique
```

Managed Applications use automated synchronization, pruning and self-healing where configured.

## Resource Ownership

Argo CD owns the desired state of managed Kubernetes resources.

Do not use these commands to make persistent changes to Argo CD-managed workloads:

```text
helm install
helm upgrade
kubectl apply
kubectl edit
kubectl scale
```

Operational inspection remains appropriate:

```text
kubectl get
kubectl describe
kubectl logs
kubectl exec
kubectl port-forward
```

Terraform owns GCP infrastructure and GKE. Argo CD owns Kubernetes workloads.

## Local Environment

Local desired state is stored under:

```text
argocd/local/
```

Active local Applications are selected through:

```text
argocd/local/applications/kustomization.yaml
```

This allows resource-intensive observability layers to be enabled or disabled declaratively without manual scaling.

The local environment uses:

```text
environments/local/online-boutique/values.yaml
environments/local/observability/
```

Detailed local-specific behaviour belongs in:

```text
argocd/local/README.md
environments/local/observability/README.md
```

## GCP Environment

GCP desired state is stored under:

```text
argocd/gcp/
```

The current GCP Application reuses:

```text
applications/online-boutique/chart/
```

with stage values from:

```text
environments/gcp/stage/online-boutique/values.yaml
```

The GCP AppProject model is more restrictive than the local development environment and should be expanded only when a concrete workload requirement exists.

Detailed GCP bootstrap and AppProject configuration is documented in [`gcp/README.md`](gcp/README.md).

## Validation

Render local desired state:

```bash
kubectl kustomize argocd/local
```

Render GCP desired state:

```bash
kubectl kustomize argocd/gcp
```

List local Applications:

```bash
kubectl get applications -n argocd
```

When working with multiple clusters, always verify the active context first:

```bash
kubectl config current-context
```

For GCP, the expected Application state after reconciliation is:

```text
Synced / Healthy
```

## Related Documentation

- [GitOps Repository](../README.md)
- [GCP Argo CD Environment](gcp/README.md)
- [Online Boutique Helm Chart](../applications/online-boutique/chart/README.md)
- [Local Observability](../environments/local/observability/README.md)
