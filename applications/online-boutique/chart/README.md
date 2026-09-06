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