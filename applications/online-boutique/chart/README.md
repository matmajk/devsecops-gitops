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

## Local Installation

```bash
helm upgrade \
  --install online-boutique \
  applications/online-boutique/chart \
  --namespace online-boutique \
  --create-namespace \
  -f environments/local/online-boutique/values.yaml
```
## Validation

```bash
helm lint \
  applications/online-boutique/chart \
  --strict

helm template \
  online-boutique \
  applications/online-boutique/chart \
  --namespace online-boutique
```

## Chart Conventions

The chart follows a set of conventions intended to keep workload
definitions consistent while preserving service-specific configuration.

### Common workload configuration

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

## Service-specific configuration

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

### Deployment selectors

Deployment and Service selectors intentionally remain explicit and stable.

For example:
```yaml
selector:
  matchLabels:
    app.kubernetes.io/name: cartservice
```
Deployment selectors are not generated from the common metadata label
helper because `Deployment.spec.selector` is immutable after creation.

## Container images

Online Boutique application images use the shared `appImage` helper and
the global image repository and tag.

Third-party workloads, such as Redis, maintain their own image repository
and version configuration.