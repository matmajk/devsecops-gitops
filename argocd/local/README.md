# Local Argo CD Environment

This directory contains the Argo CD desired-state configuration for the local Kind environment.

It defines the local Argo CD Applications and AppProjects while reusing shared application definitions and local environment-specific configuration from the GitOps repository.

## Table of Contents

* [Directory Structure](#directory-structure)
* [Environment Scope](#environment-scope)
* [Bootstrap](#bootstrap)
* [Online Boutique Application](#online-boutique-application)
* [Observability Applications](#observability-applications)
* [AppProjects](#appprojects)
* [Workload Activation](#workload-activation)
* [Validation](#validation)
* [Related Documentation](#related-documentation)

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
│
├── projects/
│   ├── kustomization.yaml
│   ├── online-boutique.yaml
│   └── observability.yaml
│
├── kustomization.yaml
└── README.md
```

The environment root is:

```text
argocd/local/kustomization.yaml
```

It aggregates:

```text
projects/
applications/
```

This provides a single desired-state entry point for the local Argo CD root Application.

## Environment Scope

The local GitOps environment manages the application and observability workloads running on the Kind cluster.

The current scope includes:

```text
Online Boutique
Prometheus/Grafana
Loki
Alloy
OpenTelemetry Collector
Jaeger
```

The local environment uses shared application definitions where possible and keeps environment-specific configuration under:

```text
environments/local/
```

Local and GCP Argo CD configuration remain independent:

```text
argocd/local/
argocd/gcp/
```

This keeps local-only observability workloads separate from the initial GCP workload baseline.

## Bootstrap

Argo CD must exist before it can reconcile this directory.

The local root Application is defined in:

```text
argocd/bootstrap/root-application.yaml
```

It reconciles:

```text
argocd/local/
```

The resulting hierarchy is:

```text
      platform-root
            ↓
      argocd/local
            ↓
AppProjects + Applications
            ↓
       Kind cluster
```

The local environment uses a non-HA Argo CD installation because it is intended for development, integration testing and platform validation.

After bootstrap, normal workload lifecycle is managed through Git and Argo CD.

## Online Boutique Application

The local Online Boutique Application is defined in:

```text
argocd/local/applications/online-boutique.yaml
```

It uses the shared Helm chart:

```text
applications/online-boutique/chart/
```

with local values:

```text
environments/local/online-boutique/values.yaml
```

The Application deploys Online Boutique to the local Kubernetes cluster and the:

```text
online-boutique
```

namespace.

The same reusable Helm chart is also used by the GCP environment.

## Observability Applications

Local observability is split into dedicated Argo CD Applications.

The current Application definitions are:

```text
observability-metrics.yaml
observability-loki.yaml
observability-alloy.yaml
observability-opentelemetry.yaml
observability-jaeger.yaml
```

Their environment-specific configuration is stored under:

```text
environments/local/observability/
```

The observability stack provides:

```text
Metrics
├── Prometheus
└── Grafana

Logging
├── Loki
└── Alloy

Tracing
├── OpenTelemetry Collector
└── Jaeger
```

Keeping the components as separate Applications allows individual platform layers to be enabled or disabled declaratively when required.

Detailed configuration is documented in:

```text
environments/local/observability/README.md
```

## AppProjects

Local Applications are grouped into dedicated Argo CD AppProjects.

The current projects are:

```text
online-boutique
observability
```

Their definitions are stored under:

```text
argocd/local/projects/
```

The Online Boutique project manages the application workload.

The observability project manages the metrics, logging and tracing Applications.

Project definitions are included in:

```text
argocd/local/projects/kustomization.yaml
```

and are reconciled together with the local Applications through the environment root.

## Workload Activation

Active local Applications are declared in:

```text
argocd/local/applications/kustomization.yaml
```

The current Application set is:

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

Removing an Application from this Kustomization removes it from the local desired state.

Adding an Application makes it part of the desired state reconciled by:

```text
platform-root
```

This mechanism allows local platform components to be controlled declaratively without relying on manual scaling or direct Kubernetes changes.

Because Argo CD uses pruning and self-healing, workload activation should be changed through Git.

## Validation

Render the complete local Argo CD desired state:

```bash
kubectl kustomize argocd/local
```

List the rendered resources:

```bash
kubectl kustomize argocd/local \
  | yq -r '[.kind, .metadata.name] | @tsv' \
  | sort
```

The current configuration should include:

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

Verify the active Kubernetes context:

```bash
kubectl config current-context
```

For the local environment, the expected context is:

```text
kind-devsecops-local
```

Verify Argo CD Applications:

```bash
kubectl get applications -n argocd
```

Verify AppProjects:

```bash
kubectl get appprojects -n argocd
```

Verify managed workloads:

```bash
kubectl get pods -A
```

Refresh the local root Application when required during troubleshooting:

```bash
argocd app get platform-root --refresh
```

Normal application lifecycle changes should not require manual refreshes; reconciliation is expected to occur automatically.

## Related Documentation

For the overall Argo CD configuration and local/GCP environment structure, see the [Argo CD README](../README.md).

For repository-level GitOps architecture and artifact promotion, see the [GitOps repository README](../../README.md).

For the shared workload definition, see the [Online Boutique Helm Chart](../../applications/online-boutique/chart/README.md).

For local metrics, logging and tracing configuration, see [Local Observability](../../environments/local/observability/README.md).
