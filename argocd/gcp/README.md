# GCP Argo CD Environment

This directory contains the Argo CD desired-state configuration for the GKE environment.

It defines the GCP-specific Argo CD Applications and AppProjects while reusing the shared Online Boutique Helm chart from the repository.

## Table of Contents

* [Directory Structure](#directory-structure)
* [Environment Scope](#environment-scope)
* [Bootstrap](#bootstrap)
* [Online Boutique Application](#online-boutique-application)
* [AppProject Security](#appproject-security)
* [Validation](#validation)
* [Related Documentation](#related-documentation)

## Directory Structure

```text
argocd/gcp/
├── applications/
│   ├── kustomization.yaml
│   └── online-boutique.yaml
│
├── projects/
│   ├── kustomization.yaml
│   ├── default.yaml
│   └── online-boutique.yaml
│
├── kustomization.yaml
└── README.md
```

The environment root is:

```text
argocd/gcp/kustomization.yaml
```

It aggregates:

```text
projects/
applications/
```

The GCP root Application reconciles this directory as a single desired-state entry point.

## Environment Scope

The initial GCP GitOps environment manages Online Boutique on GKE.

The workload uses the shared Helm chart:

```text
applications/online-boutique/chart/
```

with GCP-specific values:

```text
environments/gcp/online-boutique/values.yaml
```

The complete local observability stack is not included in the initial GCP baseline.

Local and GCP Argo CD configuration remain independent:

```text
argocd/local/
argocd/gcp/
```

This prevents environment-specific Applications from being reconciled by the wrong cluster.

## Bootstrap

Argo CD must exist before it can reconcile this directory.

The GCP bootstrap uses:

```text
argocd/bootstrap/platform-bootstrap-gcp-project.yaml
argocd/bootstrap/platform-root-gcp.yaml
```

After Argo CD itself is installed, apply the bootstrap project:

```bash
kubectl apply \
  -f argocd/bootstrap/platform-bootstrap-gcp-project.yaml
```

Then create the GCP root Application:

```bash
kubectl apply \
  -f argocd/bootstrap/platform-root-gcp.yaml
```

The resulting hierarchy is:

```text
    platform-root-gcp
            ↓
       argocd/gcp
            ↓
AppProjects + Applications
            ↓
           GKE
```

After this bootstrap step, workload lifecycle is managed through Git and Argo CD.

Do not manually deploy Online Boutique with Helm or `kubectl apply`.

## Online Boutique Application

The GCP Online Boutique Application is defined in:

```text
argocd/gcp/applications/online-boutique.yaml
```

It combines:

```text
applications/online-boutique/chart/
```

with:

```text
environments/gcp/online-boutique/values.yaml
```

The Application deploys to:

```text
server:
  https://kubernetes.default.svc

namespace:
  online-boutique
```

The same Helm chart is reused by the local environment.

Only environment-specific configuration is separated.

## AppProject Security

The GCP environment uses dedicated AppProjects.

The `default` AppProject is configured as deny-all so Applications cannot use it as an unrestricted fallback.

Online Boutique uses:

```text
argocd/gcp/projects/online-boutique.yaml
```

The project is restricted to:

* the GitOps repository
* the in-cluster Kubernetes API
* the `online-boutique` namespace
* explicitly allowed Kubernetes resource kinds

The Helm chart directly manages:

```text
Deployment
Service
ServiceAccount
```

The project also allows:

```text
ReplicaSet
Pod
```

to retain child-resource visibility in the Argo CD resource tree.

The bootstrap root uses the separate:

```text
platform-bootstrap-gcp
```

AppProject.

Its scope is limited to the GitOps repository, the `argocd` namespace and the Argo CD resource types required by the bootstrap hierarchy.

Permissions should be expanded only when a concrete workload requirement exists.

## Validation

Render the GCP Argo CD configuration:

```bash
kubectl kustomize argocd/gcp
```

List the rendered resources:

```bash
kubectl kustomize argocd/gcp \
  | yq -r '[.kind, .metadata.name] | @tsv'
```

Expected resources:

```text
AppProject    default
AppProject    online-boutique
Application   online-boutique
```

Validate the GCP Helm values:

```bash
helm lint \
  applications/online-boutique/chart \
  -f environments/gcp/online-boutique/values.yaml
```

Inspect the resource kinds rendered by the chart:

```bash
helm template online-boutique \
  applications/online-boutique/chart \
  -f environments/gcp/online-boutique/values.yaml \
  | yq -r '
      select(.kind != null) |
      [.apiVersion, .kind] |
      @tsv
    ' \
  | sort -u
```

Expected kinds:

```text
apps/v1 Deployment
v1      Service
v1      ServiceAccount
```

After bootstrap, verify AppProjects:

```bash
kubectl get appprojects -n argocd
```

Expected projects include:

```text
default
online-boutique
platform-bootstrap-gcp
```

Verify Applications:

```bash
kubectl get applications -n argocd
```

Expected Applications include:

```text
platform-root-gcp
online-boutique
```

Check the workload status:

```bash
kubectl get application online-boutique \
  -n argocd \
  -o jsonpath='{.status.sync.status}{" / "}{.status.health.status}{"\n"}'
```

The target state is:

```text
Synced/Healthy
```

The AppProject policy should also be validated with negative tests to confirm that unapproved resource kinds and deployment destinations are rejected.

Temporary validation manifests should not remain in the final desired state.

## Related Documentation

For the overall Argo CD configuration and local/GCP environment structure, see the [Argo CD README](../README.md).

For repository-level GitOps architecture and artifact promotion, see the [GitOps repository README](../../README.md).

For the shared workload definition, see the [Online Boutique Helm Chart](../../applications/online-boutique/chart/README.md).
