# Argo CD

This directory contains the Argo CD configuration used to manage workloads in the DevSecOps Kubernetes platform.

Argo CD provides the reconciliation layer between the desired state stored in Git and the workloads running in Kubernetes.

The configuration is separated between the local Kind environment and the GCP/GKE environment.

## Table of Contents

* [Directory Structure](#directory-structure)
* [Bootstrap Model](#bootstrap-model)
* [GitOps Hierarchy](#gitops-hierarchy)
* [Automated Reconciliation](#automated-reconciliation)
* [Resource Ownership](#resource-ownership)
* [Local Workload Activation](#local-workload-activation)

  * [Enabling a Workload](#enabling-a-workload)
  * [Disabling a Workload](#disabling-a-workload)
* [Resource-Constrained Local Profiles](#resource-constrained-local-profiles)
* [GCP Environment](#gcp-environment)
* [Access](#access)
* [Validation](#validation)
* [Related Documentation](#related-documentation)

## Directory Structure

```text
argocd/
├── bootstrap/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── root-application.yaml
│   ├── platform-bootstrap-gcp-project.yaml
│   └── platform-root-gcp.yaml
│
├── local/
│   ├── applications/
│   │   ├── kustomization.yaml
│   │   ├── online-boutique.yaml
│   │   ├── observability-alloy.yaml
│   │   ├── observability-jaeger.yaml
│   │   ├── observability-loki.yaml
│   │   ├── observability-metrics.yaml
│   │   └── observability-opentelemetry.yaml
│   ├── projects/
│   │   ├── kustomization.yaml
│   │   ├── online-boutique.yaml
│   │   └── observability.yaml
│   └── kustomization.yaml
│
├── gcp/
│   ├── applications/
│   │   ├── kustomization.yaml
│   │   └── online-boutique.yaml
│   ├── projects/
│   │   ├── kustomization.yaml
│   │   ├── default.yaml
│   │   └── online-boutique.yaml
│   ├── kustomization.yaml
│   └── README.md
│
└── README.md
```

Environment-specific Argo CD desired state is isolated under:

```text
argocd/local/
argocd/gcp/
```

Reusable workload definitions remain outside this directory under:

```text
applications/
```

Environment-specific Helm values are stored under:

```text
environments/
```

## Bootstrap Model

Argo CD must exist before it can reconcile resources from Git.

The initial Argo CD installation is therefore bootstrapped using configuration stored under:

```text
argocd/bootstrap/
```

After bootstrap, application and platform workload lifecycle is managed declaratively through Git.

### Local

The local root Application is:

```text
argocd/bootstrap/root-application.yaml
```

It reconciles:

```text
argocd/local/
```

The local environment uses a non-HA Argo CD installation because it is intended for development, integration testing and platform validation.

### GCP

The GCP environment uses a separate restricted bootstrap project and root Application:

```text
argocd/bootstrap/platform-bootstrap-gcp-project.yaml
argocd/bootstrap/platform-root-gcp.yaml
```

The GCP root reconciles:

```text
argocd/gcp/
```

This keeps the local and GCP desired states independent.

The Argo CD version is explicitly pinned to keep bootstrap behaviour reproducible.

## GitOps Hierarchy

The local GitOps hierarchy follows an app-of-apps model:

```text
platform-root
      ↓
argocd/local
      │
      ├── AppProjects
      │
      └── Applications
          ├── Online Boutique
          ├── Metrics
          ├── Loki
          ├── Alloy
          ├── OpenTelemetry Collector
          └── Jaeger
```

The GCP environment uses a separate root:

```text
platform-root-gcp
      ↓
argocd/gcp
      │
      ├── AppProjects
      └── Applications
          └── Online Boutique
```

Root Applications represent the GitOps bootstrap boundary.

Child Applications then reconcile their respective workloads.

## Automated Reconciliation

Managed Applications use automated GitOps reconciliation.

The reconciliation loop is:

```text
Git desired state
        ↓
     Argo CD
        ↓
     Compare
        ↓
    OutOfSync
        ↓
  Automatic Sync
        ↓
    Kubernetes
        ↓
  Synced/Healthy
```

Applications can use:

* automated synchronization
* automatic pruning
* automatic self-healing
* namespace creation
* controlled prune ordering

Manual changes to Argo CD-managed resources are treated as configuration drift and may be reverted automatically.

Changes to managed resources should therefore be introduced through Git.

## Resource Ownership

Argo CD owns the lifecycle of managed application resources.

Do not use the following commands to change desired state for resources managed by Argo CD:

```text
helm install
helm upgrade
kubectl apply
kubectl edit
kubectl scale
```

Operational inspection remains appropriate through commands such as:

```text
kubectl get
kubectl describe
kubectl logs
kubectl exec
kubectl port-forward
```

Infrastructure provisioning remains outside Argo CD ownership.

Terraform manages GCP infrastructure and GKE, while Argo CD manages Kubernetes workloads.

## Local Workload Activation

The local environment uses an explicit activation mechanism so that not every platform component must run continuously.

Active Applications are declared in:

```text
argocd/local/applications/kustomization.yaml
```

The current Application set is:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - online-boutique.yaml
  - observability-alloy.yaml
  - observability-jaeger.yaml
  - observability-loki.yaml
  - observability-metrics.yaml
  - observability-opentelemetry.yaml
```

The environment root:

```text
argocd/local/kustomization.yaml
```

aggregates both:

```text
projects/
applications/
```

Only Applications referenced by the local Applications Kustomization are reconciled by the root Application.

### Enabling a Workload

To enable a workload, add its Application manifest to:

```text
argocd/local/applications/kustomization.yaml
```

After the change is merged, `platform-root` detects the updated desired state and creates the corresponding child Application.

The child Application then deploys its managed resources.

### Disabling a Workload

To disable a workload, remove its Application manifest from:

```text
argocd/local/applications/kustomization.yaml
```

The root Application uses pruning, so the removed child Application is deleted.

Child Applications use the Argo CD resource finalizer:

```yaml
finalizers:
  - resources-finalizer.argocd.argoproj.io
```

This provides cascading deletion of resources managed by the removed Application.

```text
remove Application from Kustomization
                 ↓
             Git change
                 ↓
           platform-root
                 ↓
               prune
                 ↓
      child Application removed
                 ↓
       managed resources removed
```

This keeps workload activation fully declarative and Git-driven.

## Resource-Constrained Local Profiles

The activation model allows different platform combinations to be used depending on the task being performed.

Typical profiles include:

```text
Core
├── Online Boutique
└── Argo CD
```

```text
Metrics
├── Online Boutique
├── Argo CD
├── Prometheus
└── Grafana
```

```text
Logging
├── Online Boutique
├── Argo CD
├── Prometheus/Grafana
├── Loki
└── Alloy
```

```text
Tracing
├── Online Boutique
├── Argo CD
├── Prometheus/Grafana
├── OpenTelemetry Collector
└── Jaeger
```

A full platform profile can still be enabled temporarily for end-to-end CI/CD, GitOps and observability validation.

## GCP Environment

The GCP environment uses an independent Argo CD desired-state root:

```text
argocd/gcp/
```

The initial GCP configuration manages Online Boutique on GKE.

The same reusable Helm chart is used by both environments:

```text
applications/online-boutique/chart/
```

with separate environment values:

```text
environments/local/online-boutique/values.yaml
environments/gcp/online-boutique/values.yaml
```

The GCP configuration also introduces a more restrictive AppProject model.

The `default` project is configured as deny-all, while the Online Boutique project is restricted to:

* the GitOps repository
* the `online-boutique` namespace
* required Kubernetes resource kinds

Detailed GCP bootstrap and permission configuration is documented in:

```text
argocd/gcp/README.md
```

## Access

Forward the Argo CD API server:

```bash
kubectl port-forward \
  service/argocd-server \
  -n argocd \
  8081:443
```

The UI is then available at:

```text
https://localhost:8081
```

When both local and GCP environments exist, verify the active Kubernetes context first:

```bash
kubectl config current-context
```

## Validation

Render the local Argo CD configuration:

```bash
kubectl kustomize argocd/local
```

List local resources:

```bash
kubectl kustomize argocd/local \
  | yq -r '[.kind, .metadata.name] | @tsv' \
  | sort
```

Verify local Applications:

```bash
kubectl get applications -n argocd
```

Refresh the local root Application when required during troubleshooting:

```bash
argocd app get platform-root --refresh
```

Render the GCP Argo CD configuration:

```bash
kubectl kustomize argocd/gcp
```

List GCP resources:

```bash
kubectl kustomize argocd/gcp \
  | yq -r '[.kind, .metadata.name] | @tsv'
```

The GCP configuration should render:

```text
AppProject    default
AppProject    online-boutique
Application   online-boutique
```

After GCP bootstrap, verify:

```bash
kubectl get appprojects -n argocd
kubectl get applications -n argocd
```

Managed Applications should converge to:

```text
Synced/Healthy
```

Normal application lifecycle changes should not require manual Argo CD refreshes; reconciliation is expected to occur automatically.

## Related Documentation

For repository-level GitOps architecture and artifact promotion, see the [GitOps repository README](../README.md).

For detailed GCP Argo CD configuration, see [GCP Argo CD Environment](gcp/README.md).

For the application managed by Argo CD, see the [Online Boutique Helm Chart](../applications/online-boutique/chart/README.md).

For metrics, logging and tracing Applications, see [Local Observability](../environments/local/observability/README.md).
