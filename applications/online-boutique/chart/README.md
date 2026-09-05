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

Additional microservices will be introduced incrementally.

## Current Application Slice

The current implementation provides catalog browsing and
cart persistence using Cart Service backed by Redis.

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