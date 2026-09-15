# Online Boutique Helm Chart

Custom Helm chart used to deploy the Online Boutique microservices application as part of the DevSecOps platform.

The chart provides the reusable Kubernetes application definition, while environment-specific behaviour is supplied through separate values files.

## Workloads

The chart currently defines:

* frontend
* productcatalogservice
* currencyservice
* recommendationservice
* adservice
* redis-cart
* cartservice
* shippingservice
* paymentservice
* emailservice
* checkoutservice
* loadgenerator

The application covers the complete Online Boutique purchase flow, including:

```text
Frontend
└── Checkout Service
    ├── Cart Service - Redis
    ├── Product Catalog
    ├── Currency Service
    ├── Payment Service
    ├── Shipping Service
    └── Email Service
```

Redis uses ephemeral storage in the local environment and is intended for development and integration testing.

## Chart Design

The chart separates configuration into:

```text
shared application configuration
             +
service-specific configuration
```

Shared settings are centralized in `values.yaml` and reusable Helm helpers.

Service-specific behaviour remains explicit where workloads have different operational requirements.

## Shared Configuration

Common configuration includes:

* Kubernetes metadata
* Pod security context
* container security context
* application image construction
* distributed tracing configuration

Reusable Helm logic is implemented in:

```text
templates/_helpers.tpl
```

## Security Defaults

Common Pod security configuration includes non-root execution:

```yaml
global:
  podSecurityContext:
    fsGroup: 1000
    runAsGroup: 1000
    runAsNonRoot: true
    runAsUser: 1000
```

Common container security configuration includes:

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

These defaults provide a restrictive baseline for application workloads.

## Service-Specific Configuration

Configuration that reflects workload-specific behaviour remains defined per service.

This includes:

* container ports
* Service ports
* environment variables
* service dependencies
* readiness and liveness probes
* resource requests and limits
* storage configuration

Deployment and Service selectors remain explicit and stable because `Deployment.spec.selector` is immutable after creation.

## Container Images

Application services use a shared image helper.

Default images inherit:

```yaml
global:
  imageRepository: us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo
  imageTag: "v0.10.6"
```

A service can override its repository or tag when a separately built artifact must be deployed.

Example:

```yaml
productCatalogService:
  image:
    name: productcatalogservice
    repository: "<registry>/online-boutique-docker-local"
    tag: "ci-<git-sha>"
```

If a service-specific repository or tag is not provided, the corresponding global value is used.

This makes it possible to deploy a validated CI artifact for a single service without changing unrelated workloads.

## Private Registry Authentication

Services can reference Kubernetes image pull secrets:

```yaml
productCatalogService:
  imagePullSecrets:
    - name: jfrog-registry
```

Registry credentials are not stored in Helm values or committed to Git.

The referenced Kubernetes Secret must exist in the workload namespace before the Pod is scheduled.

## Load Generation

The chart can optionally deploy the Online Boutique Load Generator.

It uses Locust to generate application traffic against the frontend.

Example:

```yaml
loadGenerator:
  enabled: true
  users: 10
  rate: 1
```

Load generation is useful for:

* integration testing
* observability validation
* tracing validation
* autoscaling experiments
* failure testing

It can be disabled when workstation resources need to be conserved.

## Distributed Tracing

The chart supports optional OpenTelemetry tracing for services that include tracing instrumentation in the Online Boutique application baseline.

Tracing is configured through environment values:

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

Tracing is enabled for supported services only:

* frontend
* checkoutservice
* currencyservice
* emailservice
* paymentservice
* productcatalogservice
* recommendationservice

Services without upstream tracing support remain unchanged.

Tracing configuration is rendered through shared Helm helpers to avoid repeating identical environment configuration across Deployment templates.

## Environment Model

The chart contains reusable application defaults.

Environment-specific configuration is stored separately.

For the local environment:

```text
environments/local/online-boutique/values.yaml
```

The effective deployment configuration is therefore:

```text
base chart
    +
local values
    ↓
rendered Kubernetes manifests
```

The local environment is deployed and reconciled by Argo CD.

Direct `helm install` or `helm upgrade` operations should not be used to manage the lifecycle of the Argo CD-managed deployment.

## Values Schema

The chart defines its configuration contract using:

```text
values.schema.json
```

Helm validates the merged values before rendering or deployment.

The schema validates areas including:

* required workload configuration
* configuration value types
* replica counts
* container and Service ports
* Kubernetes Service types
* image pull policies
* global and service-specific image configuration
* image pull secret references
* dependency addresses
* resource configuration
* Pod security configuration
* container security configuration

Unknown properties are rejected to detect configuration mistakes early.

## Validation

Lint the chart:

```bash
helm lint \
  applications/online-boutique/chart \
  --strict \
  -f environments/local/online-boutique/values.yaml
```

Render the local environment:

```bash
helm template \
  online-boutique \
  applications/online-boutique/chart \
  --namespace online-boutique \
  -f environments/local/online-boutique/values.yaml
```

Both commands apply `values.schema.json` validation before producing the resulting manifests.
