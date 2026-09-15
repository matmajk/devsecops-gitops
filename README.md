# DevSecOps GitOps

Source of truth for the Kubernetes desired state of the `devsecops-gcp-platform` project.

This repository contains the declarative deployment configuration consumed by Argo CD and represents the deployment side of the platform CI/CD flow.

Application source code, artifact creation, infrastructure provisioning and Kubernetes desired state are intentionally maintained in separate repositories.

## Table of Contents

- [Responsibilities](#responsibilities)
- [GitOps Model](#gitops-model)
- [End-to-End Delivery Flow](#end-to-end-delivery-flow)
- [Repository Structure](#repository-structure)
- [Argo CD](#argo-cd)
- [Online Boutique](#online-boutique)
- [Environment Configuration](#environment-configuration)
- [Container Images](#container-images)
- [Artifact Promotion](#artifact-promotion)
- [Promotion Catalog](#promotion-catalog)
- [Promotion Workflow](#promotion-workflow)
- [Local Workload Activation](#local-workload-activation)
- [Observability](#observability)
- [Security Model](#security-model)
- [Validation](#validation)
- [Documentation](#documentation)
- [Design Principles](#design-principles)

## Responsibilities

This repository owns:

* Argo CD bootstrap and application definitions
* Kubernetes desired state
* Online Boutique Helm deployment configuration
* environment-specific Helm values
* observability deployment configuration
* workload activation
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

Those responsibilities belong to the application and infrastructure repositories.

## GitOps Model

Git is the source of truth for the desired Kubernetes state.

```text
GitOps Repository
       ↓
    Argo CD
       ↓
   Kubernetes
```

Changes to Argo CD-managed workloads are introduced through Git rather than direct deployment commands.

Argo CD continuously compares the desired state stored in this repository with the state running in Kubernetes and reconciles detected differences.

Application CI does not deploy workloads directly with `kubectl` or Helm.

## End-to-End Delivery Flow

The validated local delivery path is:

```text
    Application Repository
              ↓
             CI
              ↓
 Build/Test/Security Validation
              ↓
       Container Image
              ↓
            JFrog
              ↓
   artifact-published event
              ↓
  GitOps Promotion Workflow
              ↓
Environment Image Version Update
              ↓
         Pull Request
              ↓
            Merge
              ↓
           Argo CD
              ↓
       Kind Kubernetes
```

The application pipeline is responsible for producing and validating an immutable artifact.

The GitOps repository is responsible for selecting that artifact for deployment.

Argo CD is responsible for reconciling the resulting desired state into Kubernetes.

This separation ensures that CI never requires direct deployment access to the cluster.

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
├── argocd/
│   ├── bootstrap/
│   ├── projects/
│   ├── applications/
│   ├── kustomization.yaml
│   └── README.md
│
├── environments/
│   └── local/
│       ├── online-boutique/
│       │   └── values.yaml
│       └── observability/
│           ├── kube-prometheus-stack-values.yaml
│           ├── loki-values.yaml
│           ├── alloy-values.yaml
│           ├── opentelemetry-collector-values.yaml
│           ├── jaeger-values.yaml
│           └── README.md
│
└── .github/
    ├── promotion/
    │   └── catalog.yaml
    └── workflows/
        └── promote-artifact.yaml
```

The base Helm chart defines reusable application defaults.

Environment directories contain only configuration that differs for a particular deployment environment.

## Argo CD

Argo CD manages the Kubernetes lifecycle of workloads defined in this repository.

The local GitOps hierarchy is:

```text
platform-root
├── AppProjects
└── Applications
    ├── Online Boutique
    ├── Metrics
    ├── Logging
    └── Tracing
```

The root Application reconciles Argo CD projects and child Applications.

Child Applications then reconcile their respective Helm-based workloads.

Argo CD-managed resources use automated synchronization, pruning and self-healing.

Detailed Argo CD bootstrap, reconciliation and workload activation behaviour is documented in: [Argo CD documentation](argocd/README.md)


## Online Boutique

The Online Boutique application is deployed through the custom Helm chart located at:

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
* distributed tracing configuration
* container image configuration

Detailed Helm chart configuration and behaviour is documented in:
[Online Boutique Helm Chart](applications/online-boutique/chart/README.md)

## Environment Configuration

Environment-specific configuration is maintained separately from the reusable Helm chart.

The local environment uses:

```text
environments/local/online-boutique/values.yaml
```

Environment values can override configuration such as:

* replicas
* resource profiles
* tracing configuration
* container image repository
* container image tag
* image pull secret references
* workload-specific settings

The current environment runs on a local Kind cluster.

Future cloud environments can provide separate values while reusing the same base chart.

## Container Images

Online Boutique services use the global image configuration from the base chart unless a service-specific override is defined.

This allows independently built artifacts to be deployed without changing unrelated workloads.

For example:

```text
     productcatalogservice
               ↓
validated CI artifact from JFrog

      remaining services
               ↓
  default Online Boutique images
```

Container registry credentials are not stored in Git.

Private registry authentication is provided to Kubernetes through runtime-managed `imagePullSecrets`.

## Artifact Promotion

Artifact promotion modifies the desired state stored in Git.

It does not deploy directly to Kubernetes.

```text
Validated Artifact
        ↓
      JFrog
        ↓
Promotion Workflow
        ↓
Environment Values
        ↓
Pull Request
        ↓
      Merge
        ↓
     Argo CD
        ↓
   Kubernetes
```

Only immutable image versions are promoted.

Environment-specific configuration such as registry locations, image pull secrets and infrastructure settings remains unchanged.

This implements the:

```text
Build once
     ↓
  Promote
     ↓
   Deploy
```

model without rebuilding an artifact between environments.

## Promotion Catalog

Supported promotion targets are declared in:

```text
.github/promotion/catalog.yaml
```

The catalog maps:

```text
   service identifier
           ↓
Helm values configuration

      environment
           ↓
environment values file
```

This provides:

* an explicit allowlist of promotable services
* centralized service-to-values mapping
* centralized environment mapping
* one reusable promotion workflow

The currently validated end-to-end promotion path includes `productcatalogservice` in the `local` environment.

Additional services can be added to the catalog as their CI pipelines begin publishing validated artifacts.

## Promotion Workflow

The reusable promotion workflow is located at:

```text
.github/workflows/promote-artifact.yaml
```

It accepts:

```text
service
environment
image_tag
```

and performs:

```text
         validate request
                ↓
     resolve promotion target
                ↓
       update image version
                ↓
    validate Helm configuration
                ↓
        render manifests
                ↓
     create promotion branch
                ↓
       create pull request
                ↓
merge according to environment policy
```

Validated application pipelines can trigger promotion using an `artifact-published` repository event.

Manual promotion is also available through `workflow_dispatch`.

Automatic merging can be configured per environment through the promotion catalog.

The local environment uses automatic merge for validated CI-triggered promotions to provide a fully automated local delivery path.

Manually requested promotions remain reviewable through the pull request workflow.

## Local Workload Activation

Not every platform workload must remain active continuously in the local environment.

Active Argo CD Applications are selected through:

```text
argocd/kustomization.yaml
```

This allows resource-intensive layers such as logging and tracing to be enabled only when required.

Application definitions can remain available under:

```text
argocd/applications/
```

without being part of the currently active local profile.

Argo CD pruning and Application finalizers provide declarative cleanup when a workload is removed from the active set.

## Observability

The local environment supports GitOps-managed:

* Prometheus
* Grafana
* Loki
* Grafana Alloy
* OpenTelemetry Collector
* Jaeger

The stack is intentionally modular so metrics, logging and tracing can be enabled independently depending on the development scenario.

Metrics, logging and tracing architecture is documented in:
[Local Observability](environments/local/observability/README.md)

## Security Model

The GitOps repository does not contain registry credentials or other runtime secrets.

Application workloads use restrictive Kubernetes security settings including:

* non-root execution
* disabled privilege escalation
* dropped Linux capabilities
* read-only root filesystems where supported

Artifact security validation is performed before promotion by the application CI pipeline.

Only artifacts that successfully complete the CI validation flow are submitted to the GitOps promotion path.

## Validation

Validate the Online Boutique chart:

```bash
helm lint \
  applications/online-boutique/chart \
  --strict \
  -f environments/local/online-boutique/values.yaml
```

Render the environment locally:

```bash
helm template \
  online-boutique \
  applications/online-boutique/chart \
  --namespace online-boutique \
  -f environments/local/online-boutique/values.yaml
```

Render the active Argo CD configuration:

```bash
kubectl kustomize argocd
```

## Documentation

The repository documentation is organized by responsibility.

| Area | Documentation |
|---|---|
| GitOps overview and artifact promotion | This README |
| Argo CD bootstrap and reconciliation | [argocd/README.md](argocd/README.md) |
| Online Boutique Helm chart | [applications/online-boutique/chart/README.md](applications/online-boutique/chart/README.md) |
| Local observability architecture | [environments/local/observability/README.md](environments/local/observability/README.md) |

The root README describes repository-level architecture and ownership.

Component README files document implementation and configuration details specific to their respective areas.

Operational troubleshooting should remain separate from architecture-level documentation as dedicated runbooks are introduced.

## Design Principles

The repository follows these principles:

* Git is the source of truth for Kubernetes desired state.
* CI does not deploy directly to Kubernetes.
* Argo CD owns workload reconciliation.
* Artifacts are built once and promoted without rebuilding.
* Environment configuration is separated from reusable application defaults.
* Secrets and registry credentials are not committed to Git.
* Promotion changes application versions rather than environment infrastructure.
* Deployment configuration is validated before promotion is merged.
* Shared promotion logic is preferred over workflow duplication.
* Local workloads can be activated independently to control workstation resource consumption.
