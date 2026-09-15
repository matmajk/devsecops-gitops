# Argo CD

This directory contains the Argo CD configuration used to manage workloads in the DevSecOps Kubernetes platform.

Argo CD provides the reconciliation layer between the desired state stored in Git and the workloads running in Kubernetes.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Bootstrap Model](#bootstrap-model)
- [Bootstrap](#bootstrap)
- [GitOps Hierarchy](#gitops-hierarchy)
- [Automated Reconciliation](#automated-reconciliation)
- [Resource Ownership](#resource-ownership)
- [Local Workload Activation](#local-workload-activation)
  - [Enabling a Workload](#enabling-a-workload)
  - [Disabling a Workload](#disabling-a-workload)
- [Resource-Constrained Local Profiles](#resource-constrained-local-profiles)
- [Access](#access)
- [Validation](#validation)
- [Related Documentation](#related-documentation)

## Directory Structure

```text
argocd/
├── bootstrap/
│   └── Argo CD installation configuration
├── projects/
│   └── AppProject definitions
├── applications/
│   └── Application definitions
├── kustomization.yaml
└── README.md
```

## Bootstrap Model

Argo CD must exist before it can reconcile resources from Git.

The initial Argo CD installation is therefore bootstrapped using configuration stored under:

```text
argocd/bootstrap/
```

The local environment uses a non-HA installation because it is intended for development, integration testing and platform validation.

The Argo CD version is explicitly pinned to keep bootstrap behaviour reproducible.

After bootstrap, application and platform workload lifecycle is managed declaratively through Git.

## Bootstrap

Render the bootstrap configuration:

```bash
kubectl kustomize argocd/bootstrap
```

Install Argo CD:

```bash
kubectl apply \
  --server-side \
  --force-conflicts \
  -k argocd/bootstrap
```

Verify:

```bash
kubectl get pods -n argocd
```

## GitOps Hierarchy

The local GitOps hierarchy follows an app-of-apps model:

```text
platform-root
├── AppProjects
└── child Applications
    ├── Online Boutique
    ├── Metrics
    ├── Logging
    └── Tracing
```

The root Application represents the GitOps bootstrap boundary.

After Argo CD is installed, `platform-root` reconciles:

* Argo CD projects
* active child Applications

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

Do not use the following commands to change desired state:

```text
helm install
helm upgrade
kubectl apply
kubectl edit
kubectl scale
```

for resources managed by Argo CD.

Operational inspection remains appropriate through commands such as:

```text
kubectl get
kubectl describe
kubectl logs
kubectl exec
kubectl port-forward
```

## Local Workload Activation

The local environment uses an explicit activation mechanism so that not every platform component must run continuously.

Active Applications are declared in:

```text
argocd/kustomization.yaml
```

For example:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - applications/online-boutique-local.yaml
  - applications/observability-metrics-local.yaml
  - applications/observability-opentelemetry-local.yaml
  - applications/observability-jaeger-local.yaml
```

Only Applications referenced by this Kustomization are reconciled by the root Application.

Definitions stored under:

```text
argocd/applications/
```

represent available Applications, not necessarily active workloads.

```text
available Applications
           ↓
 argocd/applications/

  active Applications
           ↓
argocd/kustomization.yaml
```

## Enabling a Workload

To enable a workload, add its Application manifest to:

```text
argocd/kustomization.yaml
```

After the change is merged, `platform-root` detects the updated desired state and creates the corresponding child Application.

The child Application then deploys its managed resources.

## Disabling a Workload

To disable a workload, remove its Application manifest from:

```text
argocd/kustomization.yaml
```

The root Application uses pruning, so the removed child Application is deleted.

Child Applications use the Argo CD resource finalizer:

```yaml
finalizers:
  - resources-finalizer.argocd.argoproj.io
```

This provides cascading deletion of resources managed by the removed Application.

```text
remove Application from kustomization
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

## Access

Forward the Argo CD API server locally:

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

## Validation

Render the active Argo CD configuration:

```bash
kubectl kustomize argocd
```

Verify Applications:

```bash
kubectl get applications -n argocd
```

Refresh the root Application when required during troubleshooting:

```bash
argocd app get platform-root --refresh
```

Verify managed workloads:

```bash
kubectl get pods -A
```

Normal application lifecycle changes should not require manual Argo CD refreshes; reconciliation is expected to occur automatically.

## Related Documentation

For repository-level GitOps architecture and artifact promotion, see the [GitOps repository README](../README.md).

For the application managed by Argo CD, see the [Online Boutique Helm Chart](../applications/online-boutique/chart/README.md).

For metrics, logging and tracing Applications, see [Local Observability](../environments/local/observability/README.md).
