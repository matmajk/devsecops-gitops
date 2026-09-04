# Online Boutique Helm Chart

Custom Helm chart used to deploy the Online Boutique microservices
application as part of the DevSecOps platform.

## Current Status

Implemented workloads:

- frontend

Additional microservices will be introduced incrementally.

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