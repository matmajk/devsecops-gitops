# Local Observability

Environment-specific observability configuration for the local Kind-based DevSecOps platform.

The local stack provides metrics, logs, Kubernetes Events and distributed tracing while keeping resource usage suitable for a development workstation.

## Table of Contents

- [Architecture](#architecture)
- [Components](#components)
- [GitOps Deployment](#gitops-deployment)
- [Online Boutique Tracing](#online-boutique-tracing)
- [Workload Activation](#workload-activation)
- [Validation](#validation)
- [Local Resource Profile](#local-resource-profile)
- [Related Documentation](#related-documentation)

## Architecture

```text
                          Online Boutique
                                |
              +-----------------+-----------------+
              |                 |                 |
              v                 v                 v
          Prometheus           Alloy        OpenTelemetry
              |                 |             Collector
              |                 v                 |
              |                Loki               v
              |                 |               Jaeger
              +-----------------+-----------------+
                                |
                                v
                             Grafana
```

The stack is split into independent layers so resource-intensive components do not need to remain active continuously.

## Components

### Metrics

`kube-prometheus-stack` provides:

- Prometheus
- Grafana
- Prometheus Operator
- kube-state-metrics
- node-exporter
- Kubernetes dashboards and rules

Configuration:

```text
kube-prometheus-stack-values.yaml
```

The local profile uses short retention and disables control-plane monitoring targets that provide limited value in Kind.

Alertmanager is currently disabled.

### Logging

Logging uses Grafana Alloy and Loki.

```text
Pod logs + Kubernetes Events
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

Loki runs in a lightweight monolithic configuration with ephemeral storage.

Alloy runs as a single Deployment and collects selected logs through the Kubernetes API rather than mounting node log directories.

Collection is limited to:

```text
online-boutique
argocd
monitoring
```

### Tracing

Tracing uses OpenTelemetry Collector and Jaeger.

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

The Collector uses a minimal trace pipeline:

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

Jaeger uses lightweight ephemeral storage suitable for local validation.

## GitOps Deployment

Observability components are deployed through Argo CD using upstream Helm charts and values stored in this directory.

Application definitions are maintained under:

```text
argocd/local/applications/
```

The local root reconciles:

```text
argocd/local/
```

Upstream observability charts are referenced rather than copied into this repository.

## Online Boutique Tracing

Local Online Boutique values enable tracing through:

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

Tracing is enabled for:

- frontend
- checkoutservice
- currencyservice
- emailservice
- paymentservice
- productcatalogservice
- recommendationservice

## Workload Activation

Active local Applications are selected through:

```text
argocd/local/applications/kustomization.yaml
```

This is the declarative switch for enabling or disabling observability layers.

Typical combinations include:

```text
Metrics
├── Online Boutique
├── Prometheus
└── Grafana

Logging
├── Online Boutique
├── Prometheus/Grafana
├── Loki
└── Alloy

Tracing
├── Online Boutique
├── Prometheus/Grafana
├── OpenTelemetry Collector
└── Jaeger
```

Manual `kubectl scale` is not used as an activation mechanism because Argo CD self-healing treats it as drift.

## Validation

### Grafana

```bash
kubectl port-forward \
  -n monitoring \
  service/kube-prometheus-stack-grafana \
  3000:80
```

### Prometheus

```bash
kubectl port-forward \
  -n monitoring \
  service/kube-prometheus-stack-prometheus \
  9090:9090
```

### Loki

```bash
kubectl get pods \
  -n monitoring \
  -l app.kubernetes.io/name=loki
```

Readiness:

```bash
kubectl port-forward \
  -n monitoring \
  service/loki \
  3100:3100

curl http://localhost:3100/ready
```

### Alloy

```bash
kubectl get pods \
  -n monitoring \
  -l app.kubernetes.io/name=alloy

kubectl logs \
  -n monitoring \
  -l app.kubernetes.io/name=alloy \
  --tail=100
```

### OpenTelemetry Collector

```bash
kubectl rollout status \
  deployment/opentelemetry-collector \
  -n monitoring

kubectl logs \
  -n monitoring \
  deployment/opentelemetry-collector \
  --tail=100
```

### Jaeger

```bash
kubectl port-forward \
  -n monitoring \
  service/jaeger \
  16686:16686
```

After generating traffic, traces should contain spans from multiple participating Online Boutique services.

### Application Tracing

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

Render local Online Boutique manifests:

```bash
helm template \
  online-boutique \
  applications/online-boutique/chart \
  -f environments/local/online-boutique/values.yaml \
  > /tmp/online-boutique-local.yaml
```

Seven workloads should receive tracing configuration:

```bash
grep -c 'name: ENABLE_TRACING' \
  /tmp/online-boutique-local.yaml
```

Expected:

```text
7
```

## Local Resource Profile

The local observability stack is intentionally optimized for low idle resource usage.

Configured resource budgets currently include:

| Layer | CPU requests | Memory requests | CPU limits | Memory limits |
|---|---:|---:|---:|---:|
| Metrics | 300m | 448 MiB | 850m | 1344 MiB |
| Logging | 150m | 192 MiB | 450m | 704 MiB |
| Tracing | 150m | 192 MiB | 400m | 576 MiB |

These values represent explicitly configured Kubernetes requests and limits, not the complete host footprint.

The complete local stack also consumes resources through Kubernetes, Argo CD, containerd, Docker Desktop and WSL2.

The full observability profile should be enabled temporarily for end-to-end validation rather than kept as the default development state.

## Related Documentation

- [GitOps Repository](../../../README.md)
- [Argo CD](../../../argocd/README.md)
- [Online Boutique Helm Chart](../../../applications/online-boutique/chart/README.md)
