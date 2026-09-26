# Online Boutique Helm Chart

Reusable Helm chart for deploying Online Boutique workloads in the DevSecOps platform.

Environment-specific behaviour is supplied through separate values files rather than duplicated chart definitions.

## Table of Contents

- [Workloads](#workloads)
- [Chart Design](#chart-design)
- [Security Defaults](#security-defaults)
- [Container Images](#container-images)
- [Load Generation](#load-generation)
- [Distributed Tracing](#distributed-tracing)
- [Environment Model](#environment-model)
- [Values Schema](#values-schema)
- [Validation](#validation)
- [Related Documentation](#related-documentation)

## Workloads

The chart currently defines:

- frontend
- productcatalogservice
- currencyservice
- recommendationservice
- adservice
- redis-cart
- cartservice
- shippingservice
- paymentservice
- emailservice
- checkoutservice
- loadgenerator

The chart covers the core Online Boutique purchase flow:

```text
Frontend
└── Checkout Service
    ├── Cart Service ── Redis
    ├── Product Catalog
    ├── Currency Service
    ├── Payment Service
    ├── Shipping Service
    └── Email Service
```

## Chart Design

Shared application defaults are defined in `values.yaml`.

Reusable rendering logic is implemented in:

```text
templates/_helpers.tpl
```

Service-specific behaviour remains explicit where workloads have different requirements, including:

- ports
- environment variables
- dependencies
- probes
- resource requests and limits
- storage configuration

Deployment and Service selectors remain explicit and stable because `Deployment.spec.selector` is immutable.

## Security Defaults

The common Pod security baseline includes non-root execution:

```yaml
global:
  podSecurityContext:
    fsGroup: 1000
    runAsGroup: 1000
    runAsNonRoot: true
    runAsUser: 1000
```

Containers use restrictive defaults:

```yaml
global:
  containerSecurityContext:
    allowPrivilegeEscalation: false
    privileged: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

Environment values may specialize runtime configuration but should not weaken these baseline controls without an explicit design decision.

## Container Images

Application services use a shared image helper.

Default application images inherit:

```yaml
global:
  imageRepository: us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo
  imageTag: "v0.10.6"
```

Individual services can override the repository or tag.

Example:

```yaml
productCatalogService:
  image:
    name: productcatalogservice
    repository: "<registry>/<repository>"
    tag: "ci-<git-sha>"
```

If a service-specific repository or tag is empty, the corresponding global value is used.

This allows a validated artifact for one service to be deployed without changing the image source of unrelated workloads.

### Registry Authentication

The chart supports `imagePullSecrets` for registries that require Kubernetes-managed credentials:

```yaml
productCatalogService:
  imagePullSecrets:
    - name: jfrog-registry
```

Credentials must not be stored in Helm values or committed to Git.

The local JFrog integration uses a runtime-created Kubernetes Secret.

The GCP stage configuration uses Google Artifact Registry and does not store registry credentials in Git.

## Load Generation

The optional Load Generator uses Locust to generate traffic against the frontend.

Example:

```yaml
loadGenerator:
  enabled: true
  users: 10
  rate: 1
```

It is useful for integration, observability, autoscaling and failure-testing scenarios.

Environment profiles can disable it when continuous load is unnecessary.

## Distributed Tracing

The chart supports optional OpenTelemetry tracing for services that include tracing instrumentation.

Example:

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

Tracing is currently supported for:

- frontend
- checkoutservice
- currencyservice
- emailservice
- paymentservice
- productcatalogservice
- recommendationservice

Services without upstream tracing support remain unchanged.

## Environment Model

The chart is shared across environments.

Local:

```text
applications/online-boutique/chart
              +
environments/local/online-boutique/values.yaml
```

GCP stage:

```text
applications/online-boutique/chart
              +
environments/gcp/stage/online-boutique/values.yaml
```

Argo CD owns workload lifecycle in both environments.

Direct `helm install` or `helm upgrade` should not be used to manage an Argo CD-managed deployment.

## Values Schema

The chart contract is defined in:

```text
values.schema.json
```

Helm validates the merged configuration before rendering.

The schema covers areas including:

- required workload configuration
- value types
- replica counts
- ports and Service types
- image configuration
- image pull secret references
- dependencies
- resource configuration
- Pod and container security configuration

Unknown properties are rejected to catch configuration mistakes early.

## Validation

Local:

```bash
helm lint \
  applications/online-boutique/chart \
  --strict \
  -f environments/local/online-boutique/values.yaml

helm template \
  online-boutique \
  applications/online-boutique/chart \
  --namespace online-boutique \
  -f environments/local/online-boutique/values.yaml
```

GCP stage:

```bash
helm lint \
  applications/online-boutique/chart \
  --strict \
  -f environments/gcp/stage/online-boutique/values.yaml

helm template \
  online-boutique \
  applications/online-boutique/chart \
  --namespace online-boutique \
  -f environments/gcp/stage/online-boutique/values.yaml
```

## Related Documentation

- [GitOps Repository](../../../README.md)
- [Argo CD](../../../argocd/README.md)
- [GCP Argo CD Environment](../../../argocd/gcp/README.md)
- [Local Observability](../../../environments/local/observability/README.md)
