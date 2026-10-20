{{/*
Expand the name of the chart.
*/}}
{{- define "pulsewatch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "pulsewatch.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label
*/}}
{{- define "pulsewatch.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pulsewatch.labels" -}}
helm.sh/chart: {{ include "pulsewatch.chart" . }}
{{ include "pulsewatch.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pulsewatch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pulsewatch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Database URL Resolver
*/}}
{{- define "pulsewatch.databaseUrl" -}}
{{- if .Values.database.overrideUrl -}}
{{ .Values.database.overrideUrl }}
{{- else -}}
postgres://{{ .Values.database.user }}:{{ .Values.database.password }}@{{ .Values.database.host }}:{{ .Values.database.port }}/{{ .Values.database.dbName }}?sslmode={{ .Values.database.sslmode }}
{{- end -}}
{{- end }}

{{/*
RabbitMQ URL Resolver
*/}}
{{- define "pulsewatch.rabbitmqUrl" -}}
{{- if .Values.rabbitmq.overrideUrl -}}
{{ .Values.rabbitmq.overrideUrl }}
{{- else if .Values.rabbitmq.enabled -}}
amqp://{{ .Values.rabbitmq.auth.username }}:{{ .Values.rabbitmq.auth.password }}@{{ include "pulsewatch.fullname" . }}-rabbitmq:5672/
{{- else -}}
{{ .Values.rabbitmq.externalUrl }}
{{- end -}}
{{- end }}
