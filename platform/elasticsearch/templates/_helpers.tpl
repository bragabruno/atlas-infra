{{/*
Expand the name of the chart.
*/}}
{{- define "atlas-elasticsearch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "atlas-elasticsearch.fullname" -}}
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
{{- define "atlas-elasticsearch.labels" -}}
helm.sh/chart: {{ include "atlas-elasticsearch.name" . }}-{{ .Chart.Version }}
{{ include "atlas-elasticsearch.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "atlas-elasticsearch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "atlas-elasticsearch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
