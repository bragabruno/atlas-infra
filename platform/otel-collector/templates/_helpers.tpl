{{/*
Expand the name of the chart.
*/}}
{{- define "atlas-otel-collector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "atlas-otel-collector.fullname" -}}
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
{{- define "atlas-otel-collector.labels" -}}
helm.sh/chart: {{ include "atlas-otel-collector.name" . }}-{{ .Chart.Version }}
{{ include "atlas-otel-collector.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "atlas-otel-collector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "atlas-otel-collector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
