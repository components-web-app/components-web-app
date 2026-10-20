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
The API's HPA only when it can scale: at maxReplicas 1 it can't act and shows memory over target for good (#172).
*/}}
{{- define "cwa.hpaEnabled" -}}
{{- if and .Values.autoscaling.enabled (gt (int .Values.autoscaling.maxReplicas) 1) }}true{{ end -}}
{{- end }}

{{/*
Scaled mode (#85): several API pods sharing this release's Redis as the cache.
*/}}
{{- define "cwa.scaled" -}}
{{- if .Values.scaled.enabled }}true{{ end -}}
{{- end }}

{{/*
Redis's own labels: never the API's name label, which k8s.sh and the PDB select the API by.
*/}}
{{- define "cwa.redisLabels" -}}
helm.sh/chart: {{ include "cwa.chart" . }}
app.kubernetes.io/name: {{ include "cwa.name" . }}-redis
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: cache
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
The Mercure hub's own labels in scaled mode: never the API's name label.
*/}}
{{- define "cwa.mercureLabels" -}}
helm.sh/chart: {{ include "cwa.chart" . }}
app.kubernetes.io/name: {{ include "cwa.name" . }}-mercure
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: mercure
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Souin's store block for this release's Redis, put in CADDY_CACHE_STORAGE. Short timeouts and no retries, so a Redis
outage makes requests uncached instead of slow (go-redis's defaults add seconds per request).
*/}}
{{- define "cwa.scaled.cacheStorage" -}}
redis {
	configuration {
		Addrs {{ include "cwa.fullname" . }}-redis:6379
		Password {{ required "scaled.redis.password is required in scaled mode" .Values.scaled.redis.password }}
		DialTimeout 100ms
		ReadTimeout 100ms
		WriteTimeout 100ms
		PoolTimeout 100ms
		MaxRetries -1
	}
}
{{- end }}

{{/*
The php container's env, shared by the API deployment and the orphan scan CronJob.
Never add RESET_DATABASE: the CronJob runs the entrypoint, which would drop the schema (#103).
*/}}
{{- define "cwa.phpEnv" -}}
{{- $fullName := include "cwa.fullname" . -}}
{{- $primaryHost := index .Values.ingress.hosts 0 -}}
- name: BROWSER_SERVER_NAME
  value: {{ $primaryHost.host | quote }}
- name: SERVER_NAME
  value: :80
{{- with .Values.cwaEnvironment }}
- name: CWA_ENVIRONMENT
  value: {{ . | quote }}
{{- end }}
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
{{- if .Values.php.skipMigrations }}
# A track sharing production's database never migrates it: production's deploy does (#180).
- name: SKIP_MIGRATIONS
  value: "true"
{{- end }}
- name: CADDY_CACHE_CDN_CONFIG
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: caddy-cache-cdn-config
      optional: true
- name: CADDY_CACHE_EXTRA_CONFIG
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: caddy-cache-extra-config
      optional: true
{{- if include "cwa.scaled" . }}
- name: CADDY_CACHE_STORAGE
  valueFrom:
    secretKeyRef:
      name: {{ include "cwa.fullname" . }}
      key: caddy-cache-storage
# Subscribers reach the hub's pod through php; php's own hub stays off (#85).
- name: MERCURE_HUB_UPSTREAM
  value: {{ include "cwa.fullname" . }}-mercure:80
{{- end }}
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
- name: GCLOUD_PATH_PREFIX
  valueFrom:
    configMapKeyRef:
      name: {{ $fullName }}
      key: gcloud-path-prefix
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
{{- /* Optional php settings come from cwa.siteEnvFrom (CWA_API_*). */}}
{{- end }}

{{/*
envFrom for the site settings (templates/site-env.yaml): (dict "ctx" $ "side" "api"|"pwa").
*/}}
{{- define "cwa.siteEnvFrom" -}}
{{- $fullName := include "cwa.fullname" .ctx -}}
{{- $plain := and (eq .side "pwa") .ctx.Values.siteEnv.pwa -}}
{{- $secret := index .ctx.Values.siteEnv (printf "%sSecret" .side) -}}
{{- if or $plain $secret -}}
envFrom:
{{- if $plain }}
  - configMapRef:
      name: {{ $fullName }}-{{ .side }}-env
{{- end }}
{{- if $secret }}
  - secretRef:
      name: {{ $fullName }}-{{ .side }}-env
{{- end }}
{{- end -}}
{{- end }}

{{/*
A Mi/Gi quantity in MiB; 0 for any other form.
*/}}
{{- define "cwa.mib" -}}
{{- $q := toString . -}}
{{- if regexMatch "^[0-9]+Gi$" $q -}}
{{- mul (atoi (trimSuffix "Gi" $q)) 1024 -}}
{{- else if regexMatch "^[0-9]+Mi$" $q -}}
{{- atoi (trimSuffix "Mi" $q) -}}
{{- else -}}
0
{{- end -}}
{{- end -}}

{{/*
php.memoryLimit as PHP shorthand (128Mi -> 128M); fails on any other form.
*/}}
{{- define "cwa.php.memoryLimit" -}}
{{- if not (regexMatch "^[0-9]+[MG]i$" (toString .Values.php.memoryLimit)) -}}
{{- fail (printf "php.memoryLimit must be Mi or Gi, got %v" .Values.php.memoryLimit) -}}
{{- end -}}
{{- trimSuffix "i" (toString .Values.php.memoryLimit) -}}
{{- end -}}

{{/*
GOMEMLIMIT (#117, #136): php.goMemLimit, else what the php budget leaves of a Mi/Gi memory limit, at least 64MiB;
nothing for "off" or another form. Deployment only, not cwa.phpEnv.
*/}}
{{- define "cwa.php.goMemLimit" -}}
{{- $set := toString (.Values.php.goMemLimit | default "") -}}
{{- if eq $set "off" -}}
{{- else if $set -}}
{{- $set -}}
{{- else -}}
{{- $limit := atoi (include "cwa.mib" (dig "limits" "memory" "" .Values.php.resources)) -}}
{{- if gt $limit 0 -}}
{{- $worker := atoi (include "cwa.mib" .Values.php.memoryLimit) -}}
{{- $imagine := atoi (include "cwa.mib" .Values.php.imagineMemoryLimit) -}}
{{- $go := sub (sub (sub $limit (mul (int .Values.php.workers) $worker)) (max 0 (sub $imagine $worker))) (atoi (include "cwa.mib" .Values.php.reservedMemory)) -}}
{{- max 64 $go }}MiB
{{- end -}}
{{- end -}}
{{- end -}}
