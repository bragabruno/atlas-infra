{{/*
Expand the name of the chart.
*/}}
{{- define "atlas-mlflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "atlas-mlflow.fullname" -}}
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
{{- define "atlas-mlflow.labels" -}}
helm.sh/chart: {{ include "atlas-mlflow.name" . }}-{{ .Chart.Version }}
{{ include "atlas-mlflow.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "atlas-mlflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "atlas-mlflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
