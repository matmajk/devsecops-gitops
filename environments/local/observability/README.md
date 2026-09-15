# Local Observability

This directory contains environment-specific configuration for the observability stack used by the local Kind-based DevSecOps platform.

The stack provides:

* Kubernetes and workload metrics
* centralized application and platform logging
* Kubernetes Events collection
* distributed tracing
* Grafana-based telemetry visualization

All components are deployed declaratively through Argo CD using upstream Helm charts and local values stored in this repository.

## Architecture

```text
                         Online Boutique
                               |
              +----------------+----------------+
              |                |                |
           Metrics            Logs            Traces
              |                |                |
              v                v                v
         Prometheus          Alloy        OpenTelemetry
              |                |           Collector
              |                v                |
              |               Loki              v
              |                |              Jaeger
              +----------------+----------------+
                               |
                               v
                            Grafana
```

The observability stack is intentionally split into independent layers so resource-intensive components do not need to remain active continuously.

## GitOps Deployment Model

Observability components are deployed through Argo CD.

```text
Git
 ↓
platform-root
 ↓
Argo CD Applications
 ↓
upstream Helm charts
 +
local values
 ↓
monitoring namespace
```

The repository stores:

* Argo CD Application definitions
* pinned Helm chart versions
* local Helm values
* platform-specific configuration

Upstream charts are not copied into the repository.

## Metrics

The metrics layer uses `kube-prometheus-stack`.

It provides:

* Prometheus
* Grafana
* Prometheus Operator
* kube-state-metrics
* node-exporter
* Kubernetes dashboards
* Kubernetes monitoring rules

Configuration:

```text
kube-prometheus-stack-values.yaml
```

The local configuration is optimized for Kind and disables unnecessary control-plane monitoring targets.

Alertmanager is currently disabled because production alerting policies and SLO-based rules are outside the scope of the local environment.

Prometheus uses short retention suitable for development and functional validation.

## Logging

The logging layer consists of Grafana Alloy and Loki.

```text
Kubernetes Pods
Kubernetes Events
        ↓
      Alloy
        ↓
       Loki
        ↓
      Grafana
```

Configuration:

```text
alloy-values.yaml
loki-values.yaml
```

### Loki

Loki runs as a lightweight single-instance backend.

The local deployment intentionally avoids distributed components and persistent storage.

Log data is ephemeral and may be lost when the workload or Kind environment is recreated.

### Grafana Alloy

Alloy runs as a single Kubernetes Deployment.

Logs are collected through the Kubernetes API rather than by mounting node log directories.

This reduces the number of required Alloy instances on the local Kind cluster.

Collection is restricted to selected namespaces:

* `online-boutique`
* `argocd`
* `monitoring`

Alloy collects:

* Pod logs
* Kubernetes Events

and forwards them to Loki.

## Distributed Tracing

The tracing layer consists of OpenTelemetry Collector and Jaeger.

```text
Online Boutique
      |
  OTLP/gRPC
      ↓
OpenTelemetry Collector
      |
  OTLP/gRPC
      ↓
    Jaeger
      |
      +----> Jaeger UI
      |
      +----> Grafana
```

Configuration:

```text
opentelemetry-collector-values.yaml
jaeger-values.yaml
```

### OpenTelemetry Collector

The Collector runs as a lightweight single Deployment.

The local trace pipeline is:

```text
OTLP receiver
      ↓
memory_limiter
      ↓
    batch
      ↓
OTLP exporter
      ↓
   Jaeger
```

The application-facing endpoint is:

```text
opentelemetry-collector.monitoring.svc.cluster.local:4317
```

### Jaeger

Jaeger runs as a single-instance tracing backend.

Trace storage is ephemeral in the local environment.

Persistent and scalable storage is intentionally deferred to the future cloud environment.

## Grafana

Grafana is the primary interface for local telemetry.

Configured datasources are:

```text
Prometheus → metrics
Loki       → logs
Jaeger     → traces
```

A datasource can remain configured while its backend is temporarily disabled.

This allows observability layers to be switched independently without repeatedly changing Grafana configuration.

### Access

```bash
kubectl port-forward \
  -n monitoring \
  service/kube-prometheus-stack-grafana \
  3000:80
```

Open:

```text
http://localhost:3000
```

## Argo CD Sync Order

Observability Applications use Argo CD sync waves to express dependencies.

```text
Wave -1
└── observability AppProject

Wave 0
└── metrics stack

Wave 1
├── Loki
└── Jaeger

Wave 2
├── Alloy
└── OpenTelemetry Collector
```

Telemetry backends are therefore declared before components that send data to them.

## Local Workload Activation

Not every observability component is expected to run continuously.

Active Applications are selected through:

```text
argocd/kustomization.yaml
```

Typical local combinations include:

```text
Metrics
├── Online Boutique
├── Argo CD
├── Prometheus
└── Grafana
```

```text
Logging
├── Online Boutique
├── Argo CD
├── Prometheus / Grafana
├── Loki
└── Alloy
```

```text
Tracing
├── Online Boutique
├── Argo CD
├── Prometheus / Grafana
├── OpenTelemetry Collector
└── Jaeger
```

A full profile can be enabled temporarily for complete platform demonstrations and end-to-end validation.

## Resource-Constrained Local Profile

The local platform runs on a development workstation, so observability components use deliberately constrained Kubernetes resource budgets.

### Metrics

| Component group                             | CPU requests | Memory requests | CPU limits | Memory limits |
| ------------------------------------------- | -----------: | --------------: | ---------: | ------------: |
| Prometheus, Grafana and Prometheus Operator |         300m |         448 MiB |       850m |      1344 MiB |

### Logging

| Component | CPU requests | Memory requests | CPU limits | Memory limits |
| --------- | -----------: | --------------: | ---------: | ------------: |
| Loki      |         100m |         128 MiB |       300m |       512 MiB |
| Alloy     |          50m |          64 MiB |       150m |       192 MiB |
| **Total** |     **150m** |     **192 MiB** |   **450m** |   **704 MiB** |

### Tracing

| Component               | CPU requests | Memory requests | CPU limits | Memory limits |
| ----------------------- | -----------: | --------------: | ---------: | ------------: |
| OpenTelemetry Collector |          50m |          64 MiB |       150m |       192 MiB |
| Jaeger                  |         100m |         128 MiB |       250m |       384 MiB |
| **Total**               |     **150m** |     **192 MiB** |   **400m** |   **576 MiB** |

These values represent explicitly configured Kubernetes requests and limits rather than total host resource consumption.

Additional resources are consumed by components such as:

* Kubernetes control plane
* Argo CD
* container runtime
* Docker Desktop
* WSL2
* Kubernetes networking
* host operating system

The recommended workflow is therefore to enable only the observability layers required for the current development scenario.

## Storage Model

The local environment prioritizes reproducibility and low resource usage over telemetry durability.

Prometheus, Loki and Jaeger therefore use development-oriented storage and retention settings.

The future cloud environment can introduce:

* persistent storage
* longer telemetry retention
* scalable deployment modes
* managed or external backends
* high availability
* production alerting
* SLO-based monitoring
* cloud-native monitoring integrations

## Quick Validation

Verify Argo CD Applications:

```bash
kubectl get applications -n argocd
```

Verify monitoring workloads:

```bash
kubectl get pods -n monitoring
```

Verify Online Boutique workloads:

```bash
kubectl get pods -n online-boutique
```

Access Prometheus:

```bash
kubectl port-forward \
  -n monitoring \
  service/kube-prometheus-stack-prometheus \
  9090:9090
```

Access Jaeger:

```bash
kubectl port-forward \
  -n monitoring \
  service/jaeger \
  16686:16686
```

Detailed troubleshooting commands and telemetry queries are maintained separately from this architecture-level README as the operational runbook grows.

Find it here: [README.md](https://github.com/matmajk/devsecops-gcp-infrastructure/blob/master/docs/runbooks/README.md)
