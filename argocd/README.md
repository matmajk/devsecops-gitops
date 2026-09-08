# Argo CD

This directory contains the GitOps configuration used to deploy and
manage workloads in Kubernetes using Argo CD.

## Directory Structure

```text
argocd/
├── bootstrap/
│   └── Argo CD installation configuration
├── projects/
│   └── Argo CD AppProject definitions
└── applications/
    └── Argo CD Application definitions
```

## Bootstrap Model

Argo CD must exist before it can reconcile resources from Git.

For this reason, the initial Argo CD installation is performed manually
using the manifests stored under `bootstrap/`.

After bootstrap, application deployment and lifecycle management are
handled declaratively through Argo CD.

The local environment uses the non-HA Argo CD installation because it is
intended for development and integration testing.

The Argo CD version is explicitly pinned to provide reproducible
installations.

## Bootstrap

Render the manifests:
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
kubectl get applications.argoproj.io -n argocd
```

## Access

Forward the Argo CD API server locally:

```bash
kubectl port-forward \
  service/argocd-server \
  -n argocd \
  8081:443
```

The UI is then available at: <https://localhost:8081>

Application configuration is introduced separately and is managed using
declarative `Application` and `AppProject` resources.

## Online Boutique Application

The local Online Boutique deployment is managed through a declarative
Argo CD `Application`.

The Application uses:

- the `online-boutique` AppProject
- the Online Boutique Helm chart stored in this repository
- environment-specific values from `environments/local`
- the local Kubernetes cluster as the deployment destination
- the `online-boutique` namespace

Argo CD uses Helm to render Kubernetes manifests while Argo CD manages
the application lifecycle.

The local Application initially uses manual synchronization so changes
can be reviewed before they are applied to the cluster.

## Deployment Workflow

Changes to the application deployment configuration follow this flow:

```text
Git commit
    ↓
Git repository
    ↓
Argo CD comparison
    ↓
OutOfSync
    ↓
Manual Sync
    ↓
Kubernetes
    ↓
Synced / Healthy
```

Automated synchronization, pruning and self-healing are introduced
separately after the manual reconciliation workflow has been validated.

## Automated Reconciliation

The local Online Boutique Application uses automated GitOps
reconciliation.

Argo CD continuously compares the desired state stored in Git with the
actual state running in Kubernetes.

The Application enables:

- automated synchronization
- automatic pruning of resources removed from Git
- automatic self-healing of cluster drift
- namespace creation
- pruning after successful resource synchronization

The reconciliation model is:

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
Synced / Healthy
```

Manual changes to Argo CD-managed application resources are considered
configuration drift and may be automatically reverted.

Application lifecycle changes should therefore be introduced through Git
rather than through direct `kubectl apply`, `kubectl edit` or Helm CLI
operations.

### Resource Ownership

Online Boutique workload lifecycle is owned by Argo CD.

For managed application resources:

Do not use:

- `helm install`
- `helm upgrade`
- `kubectl apply`
- `kubectl edit`

Use Git changes and Argo CD reconciliation instead.

`kubectl` remains appropriate for operational inspection and
troubleshooting, including:

- `kubectl get`
- `kubectl describe`
- `kubectl logs`
- `kubectl exec`
- `kubectl port-forward`

## GitOps Hierarchy

```text
platform-root
├── online-boutique AppProject
└── online-boutique-local Application
    └── Online Boutique Helm workloads
```

### Explanation:

The root Application is the bootstrap boundary of the GitOps model.
After Argo CD is installed, the root Application reconciles Argo CD
projects and child Applications directly from Git.

Child Applications then reconcile application workloads.

## Local Workload Activation

The local platform uses an explicit workload activation mechanism to control which Argo CD Applications are deployed at a given time.

This is particularly important for the local environment, where running all observability and DevSecOps components simultaneously may exceed the available workstation resources.

Active applications are declared in:
`argocd/kustomization.yaml`

Example:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - applications/online-boutique-local.yaml
  - applications/observability-metrics-local.yaml
  - applications/observability-opentelemetry-local.yaml
  - applications/observability-jaeger-local.yaml
```

Only Applications referenced by this Kustomization are reconciled by the root Argo CD Application.

Application definitions remain available under:
`argocd/applications/`
but a definition stored in that directory does not automatically mean that the workload is active.

This separates:

```text
available applications
        ↓
argocd/applications/

active applications
        ↓
argocd/kustomization.yaml
```

### Enabling a Workload

To enable an application, add its manifest to the `resources` list.

For example, to enable centralized logging:

```yaml
resources:
  - applications/online-boutique-local.yaml
  - applications/observability-metrics-local.yaml
  - applications/observability-loki-local.yaml
  - applications/observability-alloy-local.yaml
```

After the change is merged, the root Application detects the updated Kustomize output and creates the required child Applications.

### Disabling a Workload

To disable a platform layer, remove its Application manifests from the resources list.

For example, to disable logging:

```yaml
resources:
  - applications/online-boutique-local.yaml
  - applications/observability-metrics-local.yaml
```

The root Application uses automated pruning, so removed child Applications are deleted.

Child Applications use:

```yaml
finalizers:
  - resources-finalizer.argocd.argoproj.io
```

This enables cascading deletion of resources managed by the removed Application.

The resulting flow is:

```text
remove Application from Kustomization
                ↓
         Git change merged
                ↓
            platform-root
                ↓
              prune
                ↓
        child Application deleted
                ↓
managed Kubernetes resources deleted
```

### Why Manual Scaling Is Avoided

Manual changes such as:

```bash
kubectl scale deployment <deployment> --replicas=0
```

are not used as a workload control mechanism.

Active Applications have Argo CD self-healing enabled, so manual changes are treated as configuration drift and reverted to the desired state stored in Git.

Workload activation therefore remains fully declarative and Git-driven.

### Resource-Constrained Profiles

The activation mechanism allows the local platform to run different workload combinations depending on the current development task.

Examples include:

```text
Core
├── Online Boutique
└── Argo CD

Metrics
├── Online Boutique
├── Argo CD
├── Prometheus
└── Grafana

Logging
├── Online Boutique
├── Argo CD
├── Prometheus/Grafana
├── Loki
└── Alloy

Tracing
├── Online Boutique
├── Argo CD
├── Prometheus/Grafana
├── OpenTelemetry Collector
└── Jaeger
```

A full platform profile can still be activated temporarily for end-to-end validation and demonstrations.

#### Validation

Render the currently active Application set locally:

```bash
kubectl kustomize argocd
```

Verify Argo CD Applications:

```bash
kubectl get applications -n argocd
```

Force the root Application to refresh after a Git change:

```bash
argocd app get platform-root --refresh
```

Verify that disabled Applications are removed:

```bash
kubectl get applications -n argocd
```

Verify that their managed workloads are also removed from the corresponding namespaces.
