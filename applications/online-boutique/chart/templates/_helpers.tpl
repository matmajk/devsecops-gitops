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
