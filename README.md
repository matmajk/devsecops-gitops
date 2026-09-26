# DevSecOps GitOps

Source of truth for the Kubernetes desired state of the DevSecOps platform.

This repository contains the declarative deployment configuration consumed by Argo CD. Application source code, CI pipelines and GCP infrastructure are maintained in separate repositories.

## Table of Contents

- [Responsibilities](#responsibilities)
- [GitOps Model](#gitops-model)
- [Repository Structure](#repository-structure)
- [Environment Model](#environment-model)
- [Artifact Delivery](#artifact-delivery)
- [Argo CD](#argo-cd)
- [Validation](#validation)
- [Current Status](#current-status)
- [Related Documentation](#related-documentation)

## Responsibilities

This repository owns:

- Kubernetes desired state
- Argo CD bootstrap, AppProjects and Applications
- the reusable Online Boutique Helm chart
- environment-specific Helm values
- local observability configuration
- application image versions selected for deployment
- artifact promotion into environment-specific desired state

It does not own:

- application source code
- application build, test and security pipelines
- container image creation
- SonarQube or JFrog infrastructure
- Kind cluster lifecycle
- GCP infrastructure provisioning

## GitOps Model

Git is the source of truth for Kubernetes desired state.

```text
  Application CI
        ↓
Validated artifact
        ↓
GitOps desired state
        ↓
    Argo CD
        ↓
    Kubernetes
```

CI does not deploy directly to Kubernetes.

Terraform owns GCP infrastructure and GKE. Argo CD owns Kubernetes workload reconciliation.

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
│   ├── local/
│   │   ├── applications/
│   │   ├── projects/
│   │   └── kustomization.yaml
│   ├── gcp/
│   │   ├── applications/
│   │   ├── projects/
│   │   ├── kustomization.yaml
│   │   └── README.md
│   └── README.md
│
├── environments/
│   ├── local/
│   │   ├── online-boutique/
│   │   │   └── values.yaml
│   │   └── observability/
│   │       └── ...
│   └── gcp/
│       └── stage/
│           └── online-boutique/
│               └── values.yaml
│
└── .github/
    ├── promotion/
    │   └── catalog.yaml
    └── workflows/
        └── promote-artifact.yaml
```

The repository separates three concerns:

```text
applications/
    reusable workload definitions

environments/
    environment-specific configuration

argocd/
    environment-specific reconciliation
```

## Environment Model

The same Online Boutique Helm chart is reused across environments.

Local:

```text
applications/online-boutique/chart
              +
environments/local/online-boutique/values.yaml
              ↓
       Kind Kubernetes
```

GCP stage:

```text
applications/online-boutique/chart
              +
environments/gcp/stage/online-boutique/values.yaml
              ↓
             GKE
```

The local environment includes the full local observability stack.

The initial GCP stage scope is intentionally limited to Online Boutique. Cloud observability is introduced separately.

## Artifact Delivery

The application pipeline produces and validates an immutable container artifact.

The local delivery path is:

```text
    Source
       ↓
 CI validation
       ↓
     JFrog
       ↓
GitOps promotion
       ↓
    Argo CD
       ↓
     Kind
```

For GCP stage, the validated Product Catalog artifact is replicated to Google Artifact Registry before deployment:

```text
Validated JFrog artifact
          ↓
         GAR
          ↓
GCP stage desired state
          ↓
       Argo CD
          ↓
         GKE
```

Artifacts are built once and promoted without rebuilding.

### Promotion Workflow

Promotion is implemented by:

```text
.github/workflows/promote-artifact.yaml
```

Supported promotion targets are declared in:

```text
.github/promotion/catalog.yaml
```

The workflow updates an immutable image version in the selected environment values file and creates a pull request.

The currently validated automated promotion path targets the local environment. GCP stage promotion should be enabled only after the stage deployment path has been validated on GKE.

## Argo CD

Local and GCP desired states use separate roots:

```text
  platform-root
       ↓
  argocd/local

platform-root-gcp
       ↓
   argocd/gcp
```

This prevents environment-specific Applications from being reconciled by the wrong cluster.

Detailed bootstrap, reconciliation and ownership rules are documented in [`argocd/README.md`](argocd/README.md).

## Validation

Validate the local Online Boutique configuration:

```bash
helm lint \
  applications/online-boutique/chart \
  --strict \
  -f environments/local/online-boutique/values.yaml
```

Validate GCP stage:

```bash
helm lint \
  applications/online-boutique/chart \
  --strict \
  -f environments/gcp/stage/online-boutique/values.yaml
```

Render Argo CD desired state:

```bash
kubectl kustomize argocd/local
kubectl kustomize argocd/gcp
```

## Current Status

Local GitOps is the validated integration baseline and includes Online Boutique plus local observability.

GCP uses a dedicated Argo CD root and AppProject model. The stage configuration selects the validated Product Catalog artifact from Google Artifact Registry and is intended for GKE integration validation.

## Related Documentation

- [Argo CD](argocd/README.md)
- [GCP Argo CD Environment](argocd/gcp/README.md)
- [Online Boutique Helm Chart](applications/online-boutique/chart/README.md)
- [Local Observability](environments/local/observability/README.md)
