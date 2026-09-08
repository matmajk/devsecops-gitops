# Local Observability

This directory contains environment-specific configuration for the observability stack used by the local Kind-based DevSecOps platform.

The local observability architecture provides:
- Kubernetes and workload metrics
- centralized application and platform logging
- Kubernetes Events collection
- distributed tracing
- Grafana-based telemetry visualization
- lightweight resource profiles suitable for a development workstation

All observability components are deployed declaratively through Argo CD using upstream Helm charts and configuration stored in this repository.

## Architecture

```text
                            Online Boutique
                                    |
                +-------------------+-------------------+
                |                   |                   |
                |                   |                   |
            Metrics              Logs               Traces
                |                   |                   |
                v                   v                   v
            Prometheus             Alloy        OpenTelemetry
                |                   |             Collector
                |                   |                   |
                |                   v                   v
                |                  Loki               Jaeger
                |                   |                   |
                +-------------------+-------------------+
                                    |
                                    v
                                Grafana
```

The observability stack is split into independent layers so resource-intensive components do not need to remain active continuously.

## GitOps Deployment Model

Observability components are deployed through Argo CD.

The GitOps flow is:

```text
Git repository
      ↓
platform-root
      ↓
Argo CD Applications
      ↓
Upstream Helm charts
      +
Environment-specific values
      ↓
monitoring namespace
```

The repository contains only:

- Argo CD Application definitions
- pinned Helm chart versions
- local environment values
- platform-specific configuration

Upstream observability charts are not copied into the repository.

## Components

### Metrics

The metrics layer uses `kube-prometheus-stack`.

It provides:
- Prometheus
- Grafana
- Prometheus Operator
- kube-state-metrics
- node-exporter
- Kubernetes dashboards
- Kubernetes monitoring rules

Configuration:

`kube-prometheus-stack-values.yaml`

The local environment uses a reduced configuration intended for Kind.

The following control-plane monitoring targets are disabled where they do not provide sufficient value in the local environment:
- CoreDNS monitoring
- kube-controller-manager monitoring
- kube-scheduler monitoring
- etcd monitoring
- kube-proxy monitoring

Alertmanager is currently disabled because alerting policies and SLO-based rules are not yet part of the local environment.

Prometheus uses short retention suitable for development and functional validation.

### Centralized Logging

The logging layer consists of Grafana Alloy and Loki.

```text
Kubernetes Pods
Kubernetes Events
      ↓
Grafana Alloy
      ↓
     Loki
      ↓
   Grafana
```

Configuration:

`alloy-values.yaml`
`loki-values.yaml`

#### Loki

Loki runs in monolithic mode with a single replica.

The local configuration intentionally disables components that are unnecessary for a small development environment:
- Loki Gateway
- Loki Canary
- chunks cache
- results cache
- MinIO
- distributed read/write/backend components

Storage is ephemeral.

Historical logs may therefore be lost when the Loki workload or Kind cluster is recreated.

This is intentional for local development.

#### Grafana Alloy

Alloy runs as a single Kubernetes Deployment instead of a DaemonSet.

Logs are collected through the Kubernetes API rather than by mounting node log directories.

This reduces the number of Alloy instances required by the local two-node Kind cluster.

Log collection is restricted to selected namespaces:
- online-boutique
- argocd
- monitoring

This prevents unnecessary ingestion of Kubernetes system logs and reduces memory and API usage.

Alloy collects:
- Pod logs
- Kubernetes Events

and forwards them to Loki.

### Distributed Tracing

The tracing layer consists of OpenTelemetry Collector and Jaeger.

```text
Online Boutique
      |OTLP/gRPC :4317
      ↓
OpenTelemetry Collector
      |OTLP/gRPC
      ↓
    Jaeger
      |
      +----> Jaeger UI
      |
      +----> Grafana
```

Configuration:
`opentelemetry-collector-values.yaml`
`jaeger-values.yaml`

#### OpenTelemetry Collector

The Collector runs as a single lightweight Deployment.

Only the trace pipeline required by the local environment is enabled.

The pipeline is:

```text
 OTLP receiver
      ↓
memory_limiter
      ↓
    batch
      ↓
OTLP/gRPC exporter
      ↓
    Jaeger
```

Unused receivers and pipelines are disabled.

The application-facing OTLP endpoint is:

`opentelemetry-collector.monitoring.svc.cluster.local:4317`

#### Jaeger

Jaeger runs as a lightweight single-instance tracing backend.

The local environment uses ephemeral in-memory trace storage.

Trace data can therefore be lost when the Jaeger workload is recreated.

Persistent trace storage is intentionally deferred to the future cloud environment.

## Online Boutique Tracing

Distributed tracing is controlled by the custom Online Boutique Helm chart.

Local environment values enable:

```yaml
global:
  tracing:
    enabled: true
    collectorServiceAddress: "opentelemetry-collector.monitoring.svc.cluster.local:4317"
```

Supported workloads receive:

```text
ENABLE_TRACING=1
COLLECTOR_SERVICE_ADDR=<collector endpoint>
OTEL_SERVICE_NAME=<service name>
```

Tracing configuration is rendered through a shared Helm helper instead of being duplicated across Deployment templates.

Tracing is enabled only for services that support it in the Online Boutique application baseline:
- frontend
- checkoutservice
- currencyservice
- emailservice
- paymentservice
- productcatalogservice
- recommendationservice

Services without tracing support are intentionally left unchanged.

### Grafana

Grafana is the primary local observability interface.

Configured datasources are:

```text
Prometheus → metrics
Loki       → logs
Jaeger     → traces
```

A datasource can remain configured even when its corresponding backend is temporarily disabled.

This allows observability layers to be switched on and off without modifying Grafana configuration.

#### Access

```bash
kubectl port-forward \
  -n monitoring \
  service/kube-prometheus-stack-grafana \
  3000:80
```

Open: <http://localhost:3000>

The Grafana admin password can be retrieved from the Kubernetes Secret:

```bash
kubectl get secret \
  kube-prometheus-stack-grafana \
  -n monitoring \
  -o jsonpath='{.data.admin-password}' \
| base64 -d
```

### Prometheus

Prometheus can be accessed locally with:

```bash
kubectl port-forward \
  -n monitoring \
  service/kube-prometheus-stack-prometheus \
  9090:9090
```

Open: <http://localhost:9090>

#### Useful example query:

Online Boutique Pod status:

```text
kube_pod_status_phase{
  namespace="online-boutique",
  phase="Running"
}
```

Memory usage of the Online Boutique namespace:

```text
sum(
  container_memory_working_set_bytes{
    namespace="online-boutique",
    container!="",
    image!=""
  }
) / 1024 / 1024
```

Observability namespace memory usage:

```text
sum(
  container_memory_working_set_bytes{
    namespace="monitoring",
    container!="",
    image!=""
  }
) / 1024 / 1024
```

Largest Pods by memory consumption:

```text
topk(
  20,
  sum by (namespace, pod) (
    container_memory_working_set_bytes{
      container!="",
      image!=""
    }
  )
) / 1024 / 1024
```

### Loki Validation

#### Verify Loki workload:

```bash
kubectl get pods \
  -n monitoring \
  -l app.kubernetes.io/name=loki
```

#### Verify Loki readiness:

```bash
kubectl port-forward \
  -n monitoring \
  service/loki \
  3100:3100
```

Then:

```bash
curl http://localhost:3100/ready
```

Expected response: `ready`

#### Example LogQL queries:

`{namespace="online-boutique"}`

Frontend logs:

`{namespace="online-boutique", container="frontend"}`

Argo CD logs:

`{namespace="argocd"}`

Monitoring logs:

`{namespace="monitoring"}`

Kubernetes Events:

`{job="kubernetes-events"}`

### Alloy Validation

#### Verify Alloy:

```bash
kubectl get pods \
  -n monitoring \
  -l app.kubernetes.io/name=alloy
```

Check logs:

```bash
kubectl logs \
  -n monitoring \
  -l app.kubernetes.io/name=alloy \
  --tail=100
```

The logs should not contain recurring errors related to:
- RBAC
- 403
- Loki connectivity
- configuration parsing

### OpenTelemetry Collector Validation

#### Verify the Collector rollout:

```bash
kubectl rollout status \
  deployment/opentelemetry-collector \
  -n monitoring
```

#### Verify the Pod:

```bash
kubectl get pods \
  -n monitoring \
  -l app.kubernetes.io/name=opentelemetry-collector
```

#### Verify the image and executable:

```bash
kubectl get deployment opentelemetry-collector \
  -n monitoring \
  -o yaml \
  | grep -A8 -E 'image:|command:'
```

The Collector executable should be:

`/otelcol-k8s`

#### Check Collector logs:

```bash
kubectl logs \
  -n monitoring \
  deployment/opentelemetry-collector \
  --tail=100
```

### Jaeger Validation

#### Verify Jaeger:

```bash
kubectl get pods \
  -n monitoring \
  | grep jaeger
```

#### Access Jaeger UI:

```bash
kubectl port-forward \
  -n monitoring \
  service/jaeger \
  16686:16686
```

Open: <http://localhost:16686>

After generating application traffic, traces should appear for participating Online Boutique services.

A successful distributed trace should include spans from multiple microservices rather than only a single frontend span.

### Application Tracing Validation

#### Verify frontend tracing configuration:

```bash
kubectl get deployment frontend \
  -n online-boutique \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}{"="}{.value}{"\n"}{end}' \
  | grep -E 'ENABLE_TRACING|COLLECTOR_SERVICE_ADDR|OTEL_SERVICE_NAME'
```

Expected values include:

```text
ENABLE_TRACING=1
COLLECTOR_SERVICE_ADDR=opentelemetry-collector.monitoring.svc.cluster.local:4317
OTEL_SERVICE_NAME=frontend
```

The Helm rendering can also be validated before deployment:

```bash
helm template online-boutique \
  applications/online-boutique/chart \
  -f environments/local/online-boutique/values.yaml \
  > /tmp/online-boutique-local.yaml
```

Tracing should be rendered for seven supported workloads:

```bash
grep -c 'name: ENABLE_TRACING' \
  /tmp/online-boutique-local.yaml
```

Expected: `7`

## Argo CD Sync Order

Observability Applications use sync waves to express component dependencies.

```
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

Backends are therefore declared before the components that send telemetry to them.

### Local Workload Activation

The local environment is intentionally designed so not every platform component has to remain active continuously.

Active Argo CD Applications are selected through:
`argocd/kustomization.yaml`

For example, a tracing-focused workload set can contain:
- Online Boutique
- Prometheus
- Grafana
- OpenTelemetry Collector
- Jaeger

while temporarily excluding:
- Loki
- Alloy
- Load Generator

Removing an Application from the active Kustomize resource list allows the root Argo CD Application to prune it.

Child Applications use Argo CD resource finalizers so their managed workloads are removed as part of cascading deletion.

Manual `kubectl scale` operations are intentionally avoided because Argo CD self-healing would interpret them as configuration drift and restore the Git-defined state.

### Resource-Constrained Local Profile

The local environment runs on a resource-constrained development workstation.

The observability stack is therefore deliberately optimized for low idle resource usage.

Configured resource budgets currently include:

#### Metrics

|Component group|CPU requests|Memory requests|CPU limits|Memory limits|
|:---------------:|:------------:|:---------------:|:----------:|:-------------:|
|Prometheus, Grafana and Prometheus Operator|300m|448 MiB|850m|1344 MiB|

#### Logging

|Component|CPU requests|Memory requests|CPU limits|Memory limits|
|:---------------:|:------------:|:---------------:|:----------:|:-------------:|
|Loki|100m|128 MiB|300m|512 MiB|
|Alloy|50m|64 MiB|150m|192 MiB|
|Total|150m|192 MiB|450m|704 MiB|

#### Tracing

|Component|CPU requests|Memory requests|CPU limits|	Memory limits|
|:---------------:|:------------:|:---------------:|:----------:|:-------------:|
|OpenTelemetry Collector|50m|64 MiB|150m|192 MiB|
|Jaeger|100m|128 MiB|250m|384 MiB|
|Total|150m|192 MiB|400m|576 MiB|

These values represent explicitly configured Kubernetes requests and limits.

They do not represent the complete host footprint.

Additional resources are consumed by:
- Kubernetes control plane
- Argo CD
- containerd
- Docker Desktop
- WSL2
- Kubernetes networking
- observability sidecars
- the host operating system

The recommended development workflow is therefore to enable observability layers according to the scenario being tested.

### Recommended Local Profiles
#### Metrics
- Online Boutique
- Argo CD
- Prometheus
- Grafana

#### Logging
- Online Boutique
- Argo CD
- Prometheus
- Grafana
- Loki
- Alloy

#### Tracing
- Online Boutique
- Argo CD
- Prometheus
- Grafana
- OpenTelemetry Collector
- Jaeger

#### Full Observability Demo
- Online Boutique
- Argo CD
- Prometheus
- Grafana
- Loki
- Alloy
- OpenTelemetry Collector
- Jaeger
- Load Generator

The full profile should be used temporarily for end-to-end validation rather than as the default development state.

### Local vs Cloud Environment

The local observability profile prioritizes:
- low resource consumption
- reproducibility
- functional validation
- GitOps workflow testing
- short telemetry retention
- ephemeral storage
- incremental platform development

The future GCP environment can use separate configuration for:
- persistent storage
- longer telemetry retention
- managed or external storage backends
- scalable deployment modes
- high availability
- production alerting
- cloud-native monitoring integrations
- production SLOs and operational dashboards