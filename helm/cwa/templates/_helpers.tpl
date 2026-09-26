{{/*
Expand the name of the chart.
*/}}
{{- define "cwa.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cwa.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "cwa.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cwa.labels" -}}
helm.sh/chart: {{ include "cwa.chart" . }}
{{ include "cwa.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common labels PWA
*/}}
{{- define "cwa.labelsPWA" -}}
helm.sh/chart: {{ include "cwa.chart" . }}
{{ include "cwa.selectorLabelsPWA" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cwa.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cwa.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "cwa.name" . }}
{{- end }}

{{/*
Selector labels PWA
*/}}
{{- define "cwa.selectorLabelsPWA" -}}
app.kubernetes.io/name: {{ include "cwa.name" . }}-pwa
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "cwa.name" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cwa.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cwa.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
The php container's environment, shared by the API deployment and the orphan
scan CronJob so the two can never drift apart.
*/}}
{{- define "cwa.phpEnv" -}}
{{- $fullName := include "cwa.fullname" . -}}
{{- $primaryHost := index .Values.ingress.hosts 0 -}}
- name: BROWSER_SERVER_NAME
  value: {{ $primaryHost.host | quote }}
- name: SERVER_NAME
  value: :80
- name: APP_UPSTREAM
  value: {{ include "cwa.fullname" . }}-pwa:3000
- name: MERCURE_PUBLISHER_JWT_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: mercure-publisher-jwt-key
- name: MERCURE_SUBSCRIBER_JWT_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: mercure-subscriber-jwt-key
- name: MERCURE_PUBLISHER_JWT_ALG
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: mercure-publisher-jwt-algorithm
- name: MERCURE_SUBSCRIBER_JWT_ALG
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: mercure-subscriber-jwt-algorithm
- name: TRUSTED_HOSTS
  valueFrom:
    configMapKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: php-trusted-hosts
- name: TRUSTED_PROXIES
  valueFrom:
    configMapKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: php-trusted-proxies
- name: APP_ENV
  valueFrom:
    configMapKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: php-app-env
- name: APP_DEBUG
  valueFrom:
    configMapKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: php-app-debug
- name: APP_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: php-app-secret
- name: CORS_ALLOW_ORIGIN
  valueFrom:
    configMapKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: php-cors-allow-origin
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: database-url
- name: CADDY_GLOBAL_CONFIG
  valueFrom:
    configMapKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: caddy-global-options
- name: CADDY_CACHE_CDN_CONFIG
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: caddy-cache-cdn-config
- name: CADDY_CACHE_EXTRA_CONFIG
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: caddy-cache-storage-config
- name: MERCURE_URL
  valueFrom:
    configMapKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: mercure-url
- name: MERCURE_PUBLIC_URL
  valueFrom:
    configMapKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: mercure-public-url
- name: MERCURE_EXTRA_DIRECTIVES
  valueFrom:
    configMapKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: mercure-extra-directives
- name: MERCURE_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: mercure-subscriber-jwt-key
- name: MERCURE_CORS_ORIGIN
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: mercure-cors-origin
- name: MERCURE_JWT_ALGORITHM
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: php-mercure-jwt-algorithm
- name: JWT_COOKIE_SAMESITE
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: jwt-cookie-samesite
- name: JWT_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: jwt-secret
- name: JWT_PUBLIC_KEY
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: jwt-public
- name: JWT_PASSPHRASE
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: jwt-passphrase
- name: MAILER_EMAIL
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: mailer-email
- name: MAILER_DSN
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: mailer-dsn
- name: DATABASE_CA_CERT
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: database-ssl-ca
- name: DATABASE_CLIENT_CERT
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: database-ssl-cert
- name: DATABASE_CLIENT_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: database-ssl-key
- name: DATABASE_SSL_MODE
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: database-ssl-mode
- name: GCLOUD_JSON
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: gcloud-json
- name: GCLOUD_BUCKET
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: gcloud-bucket
- name: GCLOUD_PUBLIC_URL
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: gcloud-public-url
- name: ADMIN_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: admin-username
- name: ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: admin-password
- name: ADMIN_EMAIL
  valueFrom:
    secretKeyRef:
      name: {{ $fullName }}
      key: admin-email
- name: CACHE_URL
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: cache-url
- name: RESET_DATABASE
  value: {{ .Values.php.resetDatabase | quote }}
{{- end }}
