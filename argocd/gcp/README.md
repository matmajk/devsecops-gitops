# GCP Argo CD Environment

This directory defines the Argo CD desired state used by the GKE stage environment.

It contains GCP-specific AppProjects and Applications while reusing the shared Online Boutique Helm chart.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Scope](#scope)
- [Bootstrap](#bootstrap)
- [Online Boutique](#online-boutique)
- [AppProject Security](#appproject-security)
- [Validation](#validation)
- [Related Documentation](#related-documentation)

## Directory Structure

```text
argocd/gcp/
├── applications/
│   ├── kustomization.yaml
│   └── online-boutique.yaml
├── projects/
│   ├── kustomization.yaml
│   ├── default.yaml
│   └── online-boutique.yaml
├── kustomization.yaml
└── README.md
```

The environment root:

```text
argocd/gcp/kustomization.yaml
```

aggregates:

```text
projects/
applications/
```

## Scope

The initial GCP GitOps scope is Online Boutique on GKE.

The Application combines:

```text
applications/online-boutique/chart/
```

with:

```text
environments/gcp/stage/online-boutique/values.yaml
```

The stage values select the validated Product Catalog artifact from Google Artifact Registry.

The complete local observability stack is intentionally not duplicated in this initial GCP baseline.

## Bootstrap

Argo CD must exist before this directory can be reconciled.

The GCP bootstrap boundary consists of:

```text
argocd/bootstrap/platform-bootstrap-gcp-project.yaml
argocd/bootstrap/platform-root-gcp.yaml
```

After Argo CD itself is installed:

```bash
kubectl apply \
  -f argocd/bootstrap/platform-bootstrap-gcp-project.yaml

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

After bootstrap, Online Boutique lifecycle changes should be introduced through Git.

## Online Boutique

The GCP Application is defined in:

```text
argocd/gcp/applications/online-boutique.yaml
```

It deploys to the in-cluster Kubernetes API:

```yaml
destination:
  server: https://kubernetes.default.svc
  namespace: online-boutique
```

The Application uses the shared chart and stage-specific values:

```text
applications/online-boutique/chart/
environments/gcp/stage/online-boutique/values.yaml
```

The current stage configuration disables local tracing dependencies and does not use the local JFrog image pull secret.

## AppProject Security

The GCP environment uses dedicated AppProjects.

The `default` AppProject is configured as deny-all.

Online Boutique uses:

```text
argocd/gcp/projects/online-boutique.yaml
```

The project is restricted to:

- the GitOps repository
- the in-cluster Kubernetes API
- the `online-boutique` namespace
- explicitly allowed Kubernetes resource kinds

The chart currently renders:

```text
Deployment
Service
ServiceAccount
```

The project also allows `ReplicaSet` and `Pod` for child-resource visibility in the Argo CD resource tree.

Permissions should be expanded only when the rendered workload requires additional kinds.

The GCP root uses the separate `platform-bootstrap-gcp` AppProject for bootstrap-level Argo CD resources.

## Validation

Render GCP Argo CD configuration:

```bash
kubectl kustomize argocd/gcp
```

Expected resources include:

```text
AppProject    default
AppProject    online-boutique
Application   online-boutique
```

Validate stage Helm values:

```bash
helm lint \
  applications/online-boutique/chart \
  --strict \
  -f environments/gcp/stage/online-boutique/values.yaml
```

Inspect resource kinds rendered by the chart:

```bash
helm template \
  online-boutique \
  applications/online-boutique/chart \
  --namespace online-boutique \
  -f environments/gcp/stage/online-boutique/values.yaml \
  | yq -r '
      select(.kind != null) |
      [.apiVersion, .kind] |
      @tsv
    ' \
  | sort -u
```

Expected chart kinds:

```text
apps/v1 Deployment
v1      Service
v1      ServiceAccount
```

After GCP bootstrap:

```bash
kubectl get appprojects -n argocd
kubectl get applications -n argocd
```

Expected Applications include:

```text
platform-root-gcp
online-boutique
```

Check Online Boutique reconciliation:

```bash
kubectl get application online-boutique \
  -n argocd \
  -o jsonpath='{.status.sync.status}{" / "}{.status.health.status}{"\n"}'
```

Target:

```text
Synced / Healthy
```

Verify the deployed Product Catalog image:

```bash
kubectl get deployment productcatalogservice \
  -n online-boutique \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

It should resolve to the expected immutable image in:

```text
europe-central2-docker.pkg.dev/devsecops-portfolio-matmajk/online-boutique/productcatalogservice:ci-<git-sha>
```

## Related Documentation

- [Argo CD](../README.md)
- [GitOps Repository](../../README.md)
- [Online Boutique Helm Chart](../../applications/online-boutique/chart/README.md)
