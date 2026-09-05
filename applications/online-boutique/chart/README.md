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

Additional microservices will be introduced incrementally.

## Current Application Slice

The currently implemented workloads provide the catalog-related
services used by the Online Boutique frontend.

Cart and checkout functionality will be introduced in subsequent
increments.

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