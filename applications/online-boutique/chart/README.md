# Online Boutique Helm Chart

Custom Helm chart used to deploy the Online Boutique microservices
application as part of the DevSecOps platform.

## Current Status

Implemented workloads:

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

### Diagram

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

Additional microservices will be introduced incrementally.

## Current Application Slice

The current Helm chart supports the complete core Online Boutique
purchase flow, including product browsing, cart persistence,
shipping calculation, payment processing, checkout orchestration
and order confirmation.

The local Redis deployment uses ephemeral storage and is
intended for development and integration testing.

## Chart Conventions

The chart follows a set of conventions intended to keep workload
definitions consistent while preserving service-specific configuration.

### Common Workload Configuration

Configuration shared by Online Boutique workloads is centralized in
`values.yaml` and reusable Helm helpers.

The following settings are shared:
- Pod security context
- container security context
- common Kubernetes metadata labels
- Pod labels
- Online Boutique application image construction

Common security settings are defined under:

```yaml
global:
  podSecurityContext:
    fsGroup: 1000
    runAsGroup: 1000
    runAsNonRoot: true
    runAsUser: 1000

  containerSecurityContext:
    allowPrivilegeEscalation: false
    privileged: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```
Reusable template logic is implemented in `_helpers.tpl`.

## Service-Specific Configuration

Configuration that represents workload-specific behavior remains defined
independently for each service.

This includes:
- container and Service ports
- environment variables
- service dependencies
- readiness and liveness probes
- resource requests and limits
- storage configuration

This avoids over-generalizing workloads whose operational requirements
are different.

### Deployment Selectors

Deployment and Service selectors intentionally remain explicit and stable.

For example:
```yaml
selector:
  matchLabels:
    app.kubernetes.io/name: cartservice
```
Deployment selectors are not generated from the common metadata label
helper because `Deployment.spec.selector` is immutable after creation.

## Container Images

Online Boutique application services use the shared `appImage` helper to construct container image references.

By default, application services inherit the global image repository and tag:

```yaml
global:
  imageRepository: us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo
  imageTag: "v0.10.6"
```

This keeps the standard Online Boutique deployment configuration centralized.

Individual services can optionally override the image repository or tag when an independently built artifact must be deployed.

For example:

```yaml
productCatalogService:
  image:
    name: productcatalogservice
    repository: "<registry>/online-boutique-docker-local"
    tag: "ci-<git-sha>"
```

If `repository` or `tag` is empty, the corresponding global value is used.

This allows a single service to use a custom image without changing the image source for the remaining Online Boutique workloads.

For private registries, a service can also reference Kubernetes image pull secrets:

```yaml
productCatalogService:
  imagePullSecrets:
    - name: jfrog-registry
```

Registry credentials are not stored in Helm values or committed to Git. The referenced Kubernetes Secret must exist in the workload namespace before the Pod is scheduled.

Third-party workloads, such as Redis, maintain their own image repository and version configuration.

## Load Generation

The chart can optionally deploy the Online Boutique Load Generator,
which uses Locust to continuously generate realistic shopping traffic
against the frontend.

Load generation is disabled by default and can be enabled per environment.

Example:

```yaml
loadGenerator:
  enabled: true
  users: 10
  rate: 1
```
`users` defines the target number of simulated users, while `rate`
defines how quickly new users are spawned.

The workload uses an init container to verify frontend availability
before starting traffic generation.

The local environment enables the Load Generator to support integration
testing, observability exercises, autoscaling experiments and failure
testing.

## Distributed Tracing

The chart supports optional OpenTelemetry distributed tracing for Online Boutique services that provide tracing instrumentation in the upstream application.

Tracing is disabled by default and can be enabled through environment-specific values:

```yaml
global:
  tracing:
    enabled: true
    collectorServiceAddress: "opentelemetry-collector.monitoring.svc.cluster.local:4317"
```

When tracing is enabled, supported workloads receive the following environment variables:
- ENABLE_TRACING=1
- COLLECTOR_SERVICE_ADDR
- OTEL_SERVICE_NAME

The common tracing environment configuration is rendered through a shared Helm helper to avoid duplicating tracing configuration across workload templates.

Tracing is enabled only for services that support it in the application baseline used by this chart:
- frontend
- checkoutservice
- currencyservice
- emailservice
- paymentservice
- productcatalogservice
- recommendationservice

Services without upstream tracing support are intentionally left unchanged.

The default chart configuration keeps tracing disabled so the chart does not require an OpenTelemetry backend unless the selected environment explicitly enables it.

## Local Installation

```bash
helm upgrade \
  --install online-boutique \
  applications/online-boutique/chart \
  --namespace online-boutique \
  --create-namespace \
  -f environments/local/online-boutique/values.yaml
```

## Values Validation

The chart defines its configuration contract using
`values.schema.json`.

Helm automatically validates the final merged values before rendering or
installing the chart.

The schema validates, among other things:

- required workload configuration
- configuration value types
- replica counts
- container and Service port ranges
- supported Kubernetes Service types
- image pull policies
- global and service-specific container image configuration
- private registry image pull secret references
- service dependency addresses
- resource configuration structure
- common Pod and container security settings

Unknown configuration properties are rejected to help detect
configuration typos early.

For example, those invalid overrides:

```bash
helm template \
  online-boutique \
  applications/online-boutique/chart \
  --set frontend.replicaCont=3
```
is rejected because `replicaCont` is not part of the chart configuration
contract.

```bash
helm template \
  online-boutique \
  applications/online-boutique/chart \
  --set global.containerSecurityContext.privileged=true \
  > /dev/null
```
is rejected because schema set constant boolean value for `privileged` property as `false`.

```json
"privileged": {
  "type": "boolean",
  "const": false
}
```

### Validate the chart

```bash
helm lint \
  applications/online-boutique/chart \
  --strict \
  -f environments/local/online-boutique/values.yaml
```

Render locally:

```bash
helm template \
  online-boutique \
  applications/online-boutique/chart \
  --namespace online-boutique \
  -f environments/local/online-boutique/values.yaml
```

The same schema validation is also performed during `helm install` and
`helm upgrade`.