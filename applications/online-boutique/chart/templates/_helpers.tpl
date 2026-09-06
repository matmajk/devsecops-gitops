{{/*
Chart name.
*/}}
{{- define "online-boutique.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common Kubernetes labels.
*/}}
{{- define "online-boutique.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/part-of: {{ include "online-boutique.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Component metadata labels.

Expected arguments:
    root      - root Helm context
    name      - Kubernetes application name
    component - logical application component
*/}}
{{- define "online-boutique.componentLabels" -}}
{{ include "online-boutique.labels" .root }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Labels applied to Pods.

Keep app.kubernetes.io/name stable because Services and
Deployments use it as a selector.
*/}}
{{- define "online-boutique.podLabels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/part-of: {{ include "online-boutique.name" .root }}
{{- end }}

{{/*
Container image for Online Boutique application services.
*/}}
{{- define "online-boutique.appImage" -}}
{{- printf "%s/%s:%s" .root.Values.global.imageRepository .name .root.Values.global.imageTag -}}
{{- end }}