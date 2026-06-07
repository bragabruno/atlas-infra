{{/*
Expand the name of the chart.
*/}}
{{- define "atlas-qdrant.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "atlas-qdrant.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "atlas-qdrant.labels" -}}
helm.sh/chart: {{ include "atlas-qdrant.name" . }}-{{ .Chart.Version }}
{{ include "atlas-qdrant.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "atlas-qdrant.selectorLabels" -}}
app.kubernetes.io/name: {{ include "atlas-qdrant.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
