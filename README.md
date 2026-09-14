# DevSecOps GitOps

Source of truth for the Kubernetes desired state of the `devsecops-gcp-platform` project.

This repository contains the declarative deployment configuration consumed by Argo CD.

Application source code and CI pipelines are maintained separately from the Kubernetes desired state.

## Responsibilities

This repository owns:

* Argo CD application definitions
* Kubernetes desired state
* Online Boutique Helm deployment configuration
* environment-specific Helm values
* observability deployment configuration
* workload enablement and resource profiles
* application image versions selected for deployment
* artifact promotion into environment-specific desired state

It does not own:

* application source code
* application build and test pipelines
* container image creation
* vulnerability scanning
* SonarQube analysis
* JFrog infrastructure
* Kind cluster lifecycle
* GCP infrastructure provisioning

These responsibilities are maintained in the application and infrastructure repositories.

## GitOps Model

Git is the source of truth for the desired Kubernetes state.

```text
GitOps Repository
       ↓
    Argo CD
       ↓
   Kubernetes
```

Changes to managed workloads are introduced through Git.

Argo CD continuously reconciles the desired state stored in this repository with the actual state of the Kubernetes cluster.

Application CI does not deploy workloads directly with `kubectl`.

## Repository Structure

```text
.
├── applications/
│   └── online-boutique/
│       └── chart/
│           ├── templates/
│           ├── values.yaml
│           ├── values.schema.json
│           └── README.md
│
├── environments/
│   └── local/
│       ├── online-boutique/
│       │   └── values.yaml
│       └── observability/
│           └── ...
│
└── .github/
    ├── promotion/
    │   └── catalog.yaml
    └── workflows/
        └── promote-artifact.yaml
```

The base Helm chart defines reusable application defaults.

Environment directories contain only configuration that differs for a particular deployment environment.

## Online Boutique

The Online Boutique application is deployed through a custom Helm chart located under:

```text
applications/online-boutique/chart/
```

The chart defines:

* Kubernetes Deployments
* Services
* ServiceAccounts
* security contexts
* resource requests and limits
* readiness and liveness probes
* application dependencies
* tracing configuration
* container image configuration

Detailed chart behaviour and configuration are documented in:
`applications/online-boutique/chart/README.md`


## Environment Configuration

Environment-specific configuration is maintained separately from the base Helm chart.

The current local environment uses:
`environments/local/online-boutique/values.yaml`

Environment values can override configuration such as:

* enabled workloads
* resource profiles
* tracing configuration
* container image repository
* container image tag
* image pull secret references

The local environment currently runs on Kind.

Future cloud environments are expected to introduce separate configuration for:
- dev
- staging
- prod

The same base Helm chart should be reused across environments wherever possible.

## Container Images

Application services use global image configuration from the base Helm chart by default.

Individual services can override the image repository and tag through environment-specific values.

This allows independently built application artifacts to be deployed without changing the image source of unrelated services.

For example:

```text
   productcatalogservice
             ↓
 custom validated artifact

     remaining services
             ↓
default Online Boutique images
```

Container registry credentials are not stored in Git.

Private registry authentication is provided to Kubernetes through runtime-managed `imagePullSecrets`.

## Artifact Promotion

Artifact promotion is owned by the GitOps repository.

Promotion changes the desired state rather than deploying directly to Kubernetes.

The promotion flow is:

```text
   Verified Artifact
           ↓
   Artifact Promotion
           ↓
Environment Desired State
           ↓
    Git Pull Request
           ↓
         Merge
           ↓
        Argo CD
           ↓
       Kubernetes
```

The promotion workflow updates only the immutable application image version.

Environment-specific configuration such as:

* container registry location
* image pull secrets
* infrastructure-specific settings

is not modified by artifact promotion.

This separation allows the same artifact to be promoted between environments without rebuilding it.

```text
Build once
    ↓
  JFrog
    ↓
   Dev
    ↓
 Staging
    ↓
  Prod
```

### Automatic Artifact Promotion

Automated artifact promotions may be configured for automatic merging on a
per-environment basis through the promotion catalog.

Automatic merging applies only to promotions initiated by verified
`artifact-published` events. Manually requested promotions continue to require
an explicit pull request merge.

The local environment currently enables automatic merging to minimize manual
steps in the local delivery path.

## Promotion Catalog

The promotion workflow is designed as a reusable mechanism for multiple application services and environments.

Supported promotion targets are defined explicitly in: `.github/promotion/catalog.yaml`


The catalog maps external service identifiers to their Helm values configuration and maps deployment environments to their values files.

This provides:

* an explicit allowlist of promotable services
* centralized service-to-values mapping
* centralized environment configuration
* one promotion workflow shared by multiple microservices

The initial implementation supports:

```text
service:
  productcatalogservice

environment:
  local
```

Additional services are added to the promotion catalog only after their CI pipeline publishes validated artifacts.

## Promotion Workflow

The generic promotion workflow is located at: `.github/workflows/promote-artifact.yaml`

The workflow receives:

```text
service
environment
image_tag
```

and performs:

```text
      validate inputs
            ↓
     resolve service
            ↓
    resolve environment
            ↓
    update image tag
            ↓
validate Helm configuration
            ↓
    render manifests
            ↓
 create promotion branch
            ↓
   create pull request
```

The workflow does not:

* build application source code
* rebuild container images
* scan artifacts
* access Kubernetes directly
* perform `kubectl` deployment operations

Those concerns belong to CI or Argo CD.

Artifact promotion can be initiated either manually or automatically.

Manual promotions use `workflow_dispatch` and are useful for controlled
re-promotion of existing artifacts.

Validated artifacts can also be submitted through the `artifact-published`
repository dispatch event.

Both entry points use the same promotion engine and promotion catalog.

## Argo CD

Argo CD observes changes to the desired state stored in this repository.

After a promotion pull request is merged:

```text
       GitOps main
            ↓
  Argo CD detects change
            ↓
Application becomes OutOfSync
            ↓
  Argo CD reconciliation
            ↓
    Kubernetes rollout
```

The cluster state should not be modified manually when the resource is managed by Argo CD.

Manual Kubernetes changes may be overwritten during reconciliation.

## Observability

The local Kubernetes environment includes GitOps-managed observability components such as:

* Prometheus
* Grafana
* Loki
* OpenTelemetry Collector
* Jaeger

Observability-specific deployment details are maintained with the local observability configuration rather than duplicated in this repository overview.

## Current Delivery State

The currently validated delivery path is:

```text
      Application CI
            ↓
Validated container image
            ↓
          JFrog
            ↓
   GitOps image version
            ↓
         Argo CD
            ↓
     Kind Kubernetes
```

The JFrog-to-GitOps promotion step has been validated manually for `productcatalogservice`.

The current implementation milestone is replacing the manual desired-state update with the reusable GitOps artifact promotion workflow.

## Design Principles

The repository follows these principles:

* Git is the source of truth for Kubernetes desired state.
* CI does not deploy directly to Kubernetes.
* Argo CD is responsible for reconciliation.
* Container artifacts are built once and promoted without rebuilding.
* Environment configuration is separated from application defaults.
* Secrets and registry credentials are not committed to Git.
* Promotion changes artifact versions rather than environment infrastructure.
* Shared promotion logic is preferred over per-service workflow duplication.
