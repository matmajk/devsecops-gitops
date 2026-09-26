# Local Argo CD Environment

This directory defines the Argo CD desired state used by the local Kind environment.

It contains local AppProjects and Applications while reusing shared workload definitions and environment-specific configuration from the repository.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Scope](#scope)
- [Bootstrap](#bootstrap)
- [Online Boutique](#online-boutique)
- [Observability](#observability)
- [AppProjects](#appprojects)
- [Workload Activation](#workload-activation)
- [Validation](#validation)
- [Related Documentation](#related-documentation)

## Directory Structure

```text
argocd/local/
├── applications/
│   ├── kustomization.yaml
│   ├── online-boutique.yaml
│   ├── observability-alloy.yaml
│   ├── observability-jaeger.yaml
│   ├── observability-loki.yaml
│   ├── observability-metrics.yaml
│   └── observability-opentelemetry.yaml
├── projects/
│   ├── kustomization.yaml
│   ├── online-boutique.yaml
│   └── observability.yaml
├── kustomization.yaml
└── README.md
```

The environment root:

```text
argocd/local/kustomization.yaml
```

aggregates:

```text
projects/
applications/
```

## Scope

The local GitOps environment manages workloads running on the Kind cluster.

Current scope:

```text
Online Boutique
Prometheus/Grafana
Loki
Alloy
OpenTelemetry Collector
Jaeger
```

Environment-specific configuration is stored under:

```text
environments/local/
```

Local and GCP desired state remain isolated:

```text
argocd/local/
argocd/gcp/
```

## Bootstrap

The local Argo CD root Application is defined in:

```text
argocd/bootstrap/root-application.yaml
```

It reconciles:

```text
argocd/local/
```

The hierarchy is:

```text
      platform-root
            ↓
      argocd/local
            ↓
AppProjects + Applications
            ↓
       Kind cluster
```

After bootstrap, normal workload lifecycle is managed through Git and Argo CD.

## Online Boutique

The local Online Boutique Application is defined in:

```text
argocd/local/applications/online-boutique.yaml
```

It combines the shared chart:

```text
applications/online-boutique/chart/
```

with local values:

```text
environments/local/online-boutique/values.yaml
```

The Application deploys to the:

```text
online-boutique
```

namespace.

The same Helm chart is reused by the GCP stage environment with separate values.

## Observability

Local observability is split into dedicated Argo CD Applications:

```text
observability-metrics.yaml
observability-loki.yaml
observability-alloy.yaml
observability-opentelemetry.yaml
observability-jaeger.yaml
```

Their Helm values are stored under:

```text
environments/local/observability/
```

Detailed metrics, logging and tracing configuration is documented in:

```text
environments/local/observability/README.md
```

Keeping observability components as separate Applications allows individual layers to be enabled or disabled declaratively.

## AppProjects

Local workloads use dedicated AppProjects:

```text
online-boutique
observability
```

Definitions are stored under:

```text
argocd/local/projects/
```

The Online Boutique project owns application workloads.

The observability project owns metrics, logging and tracing Applications.

## Workload Activation

Active local Applications are selected through:

```text
argocd/local/applications/kustomization.yaml
```

The current set is:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - online-boutique.yaml
  - observability-alloy.yaml
  - observability-jaeger.yaml
  - observability-loki.yaml
  - observability-metrics.yaml
  - observability-opentelemetry.yaml
```

Removing an Application from this file removes it from the local desired state.

Adding an Application makes it part of the desired state reconciled by `platform-root`.

Manual `kubectl scale` is not used as a workload activation mechanism because Argo CD self-healing treats it as drift.

## Validation

Render the complete local desired state:

```bash
kubectl kustomize argocd/local
```

List rendered resources:

```bash
kubectl kustomize argocd/local \
  | yq -r '[.kind, .metadata.name] | @tsv' \
  | sort
```

Expected resources include:

```text
Application    observability-alloy-local
Application    observability-jaeger-local
Application    observability-loki-local
Application    observability-metrics-local
Application    observability-opentelemetry-local
Application    online-boutique-local
AppProject     observability
AppProject     online-boutique
```

Verify the active context before operating on the cluster:

```bash
kubectl config current-context
```

Expected local context:

```text
kind-devsecops-local
```

Verify Argo CD resources:

```bash
kubectl get applications -n argocd
kubectl get appprojects -n argocd
```

Verify managed workloads:

```bash
kubectl get pods -A
```

A manual root refresh is useful only for troubleshooting:

```bash
argocd app get platform-root --refresh
```

Normal lifecycle changes should reconcile automatically.

## Related Documentation

- [Argo CD](../README.md)
- [GitOps Repository](../../README.md)
- [Online Boutique Helm Chart](../../applications/online-boutique/chart/README.md)
- [Local Observability](../../environments/local/observability/README.md)
