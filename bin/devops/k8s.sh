#!/usr/bin/env bash

rand_str() {
  len=32
  head -c 256 /dev/urandom > /tmp/urandom.out
  tr -dc 'a-zA-Z0-9' < /tmp/urandom.out > /tmp/urandom.tr
  head -c ${len} /tmp/urandom.tr
}

install_dependencies() {
  echo "➡️ Installing prerequisites..."
  # upgrade for curl fix https://github.com/curl/curl/issues/4357
  apk add --update-cache --upgrade --no-cache -U openssl curl tar gzip ca-certificates git nodejs npm bash

  echo "Install gcompat"
	apk add gcompat

	echo "➡️ Installing Helm..."
	curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod +x get_helm.sh
  VERIFY_CHECKSUM=true ./get_helm.sh -v "v${HELM_VERSION}"
	helm version

  echo "➡️ Installing kubectl v${KUBERNETES_VERSION}..."
  curl -L -o /usr/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"
  chmod +x /usr/bin/kubectl
  kubectl version --client
}

generate_jwt_keys() {
	# Generate random passphrase and keys for JWT signing if not set
	if [[ -z ${JWT_PASSPHRASE} ]]; then
  	echo "Generate JWT_PASSPHRASE..."
		export JWT_PASSPHRASE="$(rand_str)"
	fi

	if [[ -z ${JWT_SECRET_KEY} ]]; then
  	echo "Generate JWT_SECRET_KEY..."
		JWT_SECRET_KEY_FILE=/tmp/jwt_secret

		openssl genpkey -pass pass:"${JWT_PASSPHRASE}" -aes256 -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out ${JWT_SECRET_KEY_FILE}
		export JWT_SECRET_KEY=$(cat ${JWT_SECRET_KEY_FILE})
		export JWT_PUBLIC_KEY=$(openssl pkey -in "$JWT_SECRET_KEY_FILE" -passin pass:"$JWT_PASSPHRASE" -pubout)

		rm ${JWT_SECRET_KEY_FILE}
	fi

  # Generate random key & jwt for Mercure if not set
  if [[ -z ${MERCURE_JWT_SECRET} ]]; then
  	echo "Generating MERCURE_JWT_SECRET..."
    export MERCURE_JWT_SECRET="$(rand_str)"
  fi
}

# For Kubernetes environment gitlab runner use the localhost for DIND - see https://docs.gitlab.com/runner/executors/kubernetes.html#using-dockerdind
# Using shared runners for now.
setup_docker_environment() {
  if ! docker info &>/dev/null; then
    if [[ -z "$DOCKER_HOST" && "$KUBERNETES_PORT" ]]; then
      export DOCKER_HOST='tcp://localhost:2375'
    fi
  fi
}

setup_test_db_environment() {
  if [[ -z ${KUBERNETES_PORT+x} ]]; then
    DB_HOST=postgres
  else
    DB_HOST=localhost
  fi
  export DATABASE_CA_CERT=''
  export DATABASE_CLIENT_CERT=''
  export DATABASE_CLIENT_KEY=''
  export DATABASE_SSL_MODE='disable'

  export DATABASE_URL="pgsql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:5432/${POSTGRES_DB}"
  echo "Test database: ${DATABASE_URL}"
}

build_api() {
  # https://gitlab.com/help/ci/variables/predefined_variables.md
  if [[ -n "$CI_REGISTRY_USER" ]]; then
    echo "Logging to GitLab Container Registry with CI credentials..."
    docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    echo ""
  fi

	docker buildx version
	docker context create builder
	docker buildx create builder --driver=docker-container --use

  docker buildx build --push \
  	--cache-to type=registry,ref=$PHP_REPOSITORY_CACHE:$TAG \
  	--cache-from type=registry,ref=$PHP_REPOSITORY_CACHE:$TAG \
  	--tag $PHP_REPOSITORY:$TAG \
  	--target frankenphp_prod \
  	"api"
}

build_app() {
  # https://gitlab.com/help/ci/variables/predefined_variables.md
  if [[ -n "$CI_REGISTRY_USER" ]]; then
    echo "Logging to GitLab Container Registry with CI credentials..."
    docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    echo ""
  fi

	docker buildx version
	docker context create builder
  docker buildx create builder --driver=docker-container --use

  docker buildx build \
    --build-arg CI=true \
    --push \
    --cache-to type=registry,ref=$APP_REPOSITORY_CACHE:$TAG \
    --cache-from type=registry,ref=$APP_REPOSITORY_CACHE:$TAG \
  	--tag $APP_REPOSITORY:$TAG \
  	--target prod \
  	"app"
}

run_test_phpunit() {
  echo "run_phpunit function"
  cd ./api || return
  mkdir -p build/logs/phpunit/
  composer install -o --prefer-dist --no-scripts --ignore-platform-reqs
  APP_ENV=test vendor/bin/simple-phpunit tests/Unit --log-junit build/logs/phpunit/junit.xml
}

run_test_behat() {
	export TRUSTED_HOSTS='^localhost|caddy(\.local)?|example\.com$'
  echo "run_behat function"
  cd ./api || return
  mkdir -p build/logs/behat/
  composer install -o --prefer-dist --no-scripts --ignore-platform-reqs
  php scripts/patch-behat.php
  APP_ENV=test php bin/console dbal:run-sql "CREATE EXTENSION IF NOT EXISTS citext;"
  php vendor/behat/behat/bin/behat --format=progress --out=std --format=junit --out=build/logs/behat/junit --profile=default --no-interaction --colors --tags='~@wip'
}

check_kube_domain() {
  if [[ -z ${CI_ENVIRONMENT_URL+x} ]]; then
    echo "In order to deploy or use Review Apps, CI_ENVIRONMENT_URL variable must be set"
    echo "You can do it in Auto DevOps project settings or defining a variable at group or project level"
    echo "You can also manually add it in .gitlab-ci.yml"
    false
  else
    true
  fi
}

helm_init() {
  rm -rf ~/.helm/repository/cache/*
  helm dependency update helm/cwa
  helm dependency build helm/cwa
}

apply_kube_context() {
	kubectl config get-contexts
  if [ -n "$KUBE_CONTEXT" ]; then kubectl config use-context "$KUBE_CONTEXT"; fi
}

set_namespace() {
	# the default service account will not allow creating of the namespace - we should look at this
	# when creating role bindings for the ci pipeline user to see if it's possible to allow
	# the user to create and delete specific namespaces
	if [[ -z "$KUBE_NAMESPACE" ]]; then
    export KUBE_NAMESPACE="$CI_PROJECT_NAME-$CI_ENVIRONMENT_SLUG"
    echo "KUBE_NAMESPACE not set. Defaulting to '$KUBE_NAMESPACE'"
  fi
}

ensure_namespace() {
	set_namespace
	echo "Ensuring namespace: $KUBE_NAMESPACE"
	NS_INFO=$(kubectl describe namespace "$KUBE_NAMESPACE" || EXIT_CODE=$? && true)
	if [[ -z "$NS_INFO" ]]; then
		echo ${EXIT_CODE}
	  echo "Namespaces must be created manually with appropriate role bindings. It is not secure to allow a single project to have the permissions to manage namespaces and role bindings across the cluster."
		echo "YOU MUST CREATE THE NAMESPACE '$KUBE_NAMESPACE'"
		false
	fi
}

create_docker_pull_secret() {
  if [[ "$CI_PROJECT_VISIBILITY" = "public" ]]; then
  	echo "Project is public - skipping secret creation"
    return
  fi
  echo "Create secret..."

  kubectl create secret -n "$KUBE_NAMESPACE" \
    docker-registry $GITLAB_PULL_SECRET_NAME \
    --docker-server="$CI_REGISTRY" \
    --docker-username="${CI_DEPLOY_USER:-$CI_REGISTRY_USER}" \
    --docker-password="${CI_DEPLOY_PASSWORD:-$CI_REGISTRY_PASSWORD}" \
    --docker-email="$GITLAB_USER_EMAIL" \
    -o yaml --dry-run=client | kubectl replace -n "$KUBE_NAMESPACE" --force -f -
}

generate_alias_tls_yaml() {
  track=${1:-stable}
  if [ "$track" != "stable" ]; then
    return
  fi

  alias_yaml=""

  if [ -n "${KUBE_INGRESS_ALIAS_DOMAINS:-}" ]; then
    OLD_IFS=$IFS
    IFS=','
    for alias in $KUBE_INGRESS_ALIAS_DOMAINS; do
      alias=$(echo "$alias" | awk '{$1=$1;print}')
      if [ -n "$alias" ]; then
        alias_yaml="$alias_yaml        - $alias
"
      fi
    done
    IFS=$OLD_IFS
  fi

  printf "%s" "$alias_yaml"
}

# Picks the TLS secret for the stable ingress, and makes sure it already holds a valid
# certificate for every hostname before helm points the ingress at it (#86).
#
# Changing the host list (adding an alias, retiring a preview hostname) used to change the
# certificate behind the live site in place. cert-manager then replaces the secret's contents
# with a temporary self-signed certificate while the new order runs: minutes at best, and up
# to an hour of back-off if a challenge fails. With HSTS, that is a hard outage for every
# hostname on the ingress, the live one included.
#
# So a changed host list gets a new secret, named from a hash of the list. Its Certificate
# is created and waited on here, while the ingress still serves the old one, and the switch
# is from one valid certificate to another. If it cannot be issued (DNS not pointing at the
# cluster yet, say) the deploy stops before helm runs and the live site is untouched.
#
# When the list is unchanged, the secret the ingress already uses is kept, so existing sites
# are not reissued. Stable track only: the other tracks serve one hostname that never changes
# for the life of their release.
#
# Sets TLS_SECRET_NAME, and TLS_PREVIOUS_SECRET_NAME for cleanup_tls_certificates.
ensure_tls_certificate() {
  local track="${1-stable}" release_name="$2" base="$3"
  local names current current_names hash new

  TLS_SECRET_NAME="$base"
  TLS_PREVIOUS_SECRET_NAME=""
  if [ "$track" != "stable" ] || [ "${INGRESS_ENABLED:-false}" != "true" ] || [ -z "${CLUSTER_ISSUER:-}" ]; then
    return 0
  fi
  if ! kubectl auth can-i create certificates.cert-manager.io -n "$KUBE_NAMESPACE" >/dev/null 2>&1; then
    echo "⚠️ TLS: cannot create cert-manager Certificates in '$KUBE_NAMESPACE', so a change of hostnames is not protected. Using '$base'."
    return 0
  fi

  names=$( { echo "$DOMAIN"; generate_alias_tls_yaml "$track" | sed 's/^ *- *//'; } \
    | tr 'A-Z' 'a-z' | sed '/^$/d' | sort -u )

  current=$(kubectl get ingress -n "$KUBE_NAMESPACE" \
    -l "app.kubernetes.io/name=cwa,app.kubernetes.io/instance=$release_name" \
    -o jsonpath='{.items[0].spec.tls[0].secretName}' 2>/dev/null || true)
  if [ -z "$current" ]; then
    # First deploy of this release: nothing is live yet, so cert-manager's ingress-shim
    # issues the certificate from the ingress, as it always has.
    echo "TLS: no live ingress yet, using '$base'"
    return 0
  fi

  current_names=$(kubectl get certificate "$current" -n "$KUBE_NAMESPACE" \
    -o jsonpath='{range .spec.dnsNames[*]}{@}{"\n"}{end}' 2>/dev/null \
    | tr 'A-Z' 'a-z' | sed '/^$/d' | sort -u)
  if [ "$current_names" = "$names" ]; then
    TLS_SECRET_NAME="$current"
    echo "TLS: hostnames unchanged, keeping '$current'"
    return 0
  fi

  hash=$(printf '%s\n' "$names" | sha256sum | cut -c1-8)
  if [ -z "$hash" ]; then
    echo "❌ TLS: could not hash the hostname list (is sha256sum installed?)"
    return 1
  fi
  new="$base-$hash"
  echo "TLS: hostnames are changing, so the new certificate is issued before the ingress moves to it"
  echo "  live '$current':"; printf '%s\n' "${current_names:-(no Certificate found)}" | sed 's/^/    /'
  echo "  new  '$new':";     printf '%s\n' "$names" | sed 's/^/    /'

  kubectl apply -n "$KUBE_NAMESPACE" -f - <<EOF || return 1
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: $new
  labels:
    app.kubernetes.io/instance: $release_name
    cwa.rocks/tls-rotation: "true"
spec:
  secretName: $new
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: $CLUSTER_ISSUER
  dnsNames:
$(printf '%s\n' "$names" | sed 's/^/    - /')
EOF

  if ! kubectl wait -n "$KUBE_NAMESPACE" --for=condition=Ready "certificate/$new" \
      --timeout="${TLS_CERTIFICATE_TIMEOUT:-600s}"; then
    echo "❌ TLS CERTIFICATE NOT READY: '$new' was not issued, so the deploy stopped before changing anything."
    echo "   The live site still serves '$current'. Check every hostname above resolves to this cluster, then re-run."
    kubectl describe certificate "$new" -n "$KUBE_NAMESPACE" | sed -n '/^Status:/,$p' || true
    kubectl get challenges -n "$KUBE_NAMESPACE" 2>/dev/null || true
    [ -n "${GITHUB_ACTIONS:-}" ] && echo "::error::TLS certificate '$new' was not issued; nothing was deployed."
    return 1
  fi

  TLS_SECRET_NAME="$new"
  TLS_PREVIOUS_SECRET_NAME="$current"
}

# Deletes the certificates ensure_tls_certificate created for this release, except the one
# now in use and the one it replaced. The previous one is kept so a rollback lands on a
# valid certificate. Only runs after a successful helm upgrade.
cleanup_tls_certificates() {
  local release_name="$1" keep_current="$2" keep_previous="$3" cert

  for cert in $(kubectl get certificate -n "$KUBE_NAMESPACE" \
      -l "cwa.rocks/tls-rotation=true,app.kubernetes.io/instance=$release_name" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    if [ "$cert" = "$keep_current" ] || [ "$cert" = "$keep_previous" ]; then
      continue
    fi
    echo "TLS: removing superseded certificate '$cert'"
    kubectl delete certificate "$cert" -n "$KUBE_NAMESPACE" --ignore-not-found || true
    kubectl delete secret "$cert" -n "$KUBE_NAMESPACE" --ignore-not-found || true
  done
}

deploy() {
	local track="${1-stable}"
	name="$RELEASE"
	LETSENCRYPT_SECRET_NAME_SCOPED="$LETSENCRYPT_SECRET_NAME-$track"
	if [[ "$track" != "stable" ]]; then
		name="$name-$track"
	fi

	echo "Installing/upgrading release '${name}' on namespace '${KUBE_NAMESPACE}' and host '${DOMAIN}' (${CI_ENVIRONMENT_URL})"

  if [[ -n "$HELM_UNINSTALL" ]]; then
  	delete ${track}
  fi

  ensure_tls_certificate "$track" "$name" "${LETSENCRYPT_SECRET_NAME_SCOPED}-api" || return 1

  DATABASE_CA_CERT_B64=$(echo "$DATABASE_CA_CERT" | base64 -w0)
  DATABASE_CLIENT_CERT_B64=$(echo "$DATABASE_CLIENT_CERT" | base64 -w0)
  DATABASE_CLIENT_KEY_B64=$(echo "$DATABASE_CLIENT_KEY" | base64 -w0)
  CADDY_CACHE_CDN_CONFIG_B64=$(echo "${CADDY_CACHE_CDN_CONFIG:-""}" | base64 -w0)
  CADDY_CACHE_EXTRA_CONFIG_B64=$(echo "${CADDY_CACHE_EXTRA_CONFIG:-"otter"}" | base64 -w0)
  GCLOUD_JSON="${GCLOUD_JSON:-"{}"}"
  GCLOUD_JSON_B64=$(echo "$GCLOUD_JSON" | base64 -w0)
  NUXT_PUBLIC_CWA_API_URL_BROWSER="https://${DOMAIN}/_api"
  CURRENT_DATE=$(date)

  # Per-track sizing. Review apps and staging exist to be correct, not fast, and
  # there are many of them at once, so they must not inherit production's pod
  # floor or its reservations. Staging in particular keeps a full copy running
  # from each push to main until the next production deploy deletes it.
  # Requests are what the scheduler reserves; the limits, and so the OOM
  # ceilings, are the same on every track. Anything set explicitly in CI still
  # wins - these only fill the gap.
  case "$track" in
    stable|canary)
      PWA_AUTOSCALE_MIN_DEFAULT="2"
      PWA_AUTOSCALE_MAX_DEFAULT="6"
      PWA_CPU_REQUEST_DEFAULT="250m"
      PWA_MEMORY_REQUEST_DEFAULT="160Mi"
      PHP_CPU_REQUEST_DEFAULT="200m"
      PHP_MEMORY_REQUEST_DEFAULT="350Mi"
      ;;
    *)
      PWA_AUTOSCALE_MIN_DEFAULT="1"
      PWA_AUTOSCALE_MAX_DEFAULT="2"
      PWA_CPU_REQUEST_DEFAULT="100m"
      PWA_MEMORY_REQUEST_DEFAULT="128Mi"
      PHP_CPU_REQUEST_DEFAULT="100m"
      PHP_MEMORY_REQUEST_DEFAULT="256Mi"
      ;;
  esac

  cat >values.tmp.yaml <<EOF
imagePullSecrets:
  - name: ${GITLAB_PULL_SECRET_NAME:-"~"}
pwa:
  image:
    repository: ${APP_REPOSITORY}
    tag: ${TAG}
    pullPolicy: Always
  # Left null so the chart's in-cluster default applies. Setting it to the public
  # URL sends every server-side render out to the load balancer and back in over
  # TLS for each API call it makes. Only the browser needs the public URL.
  apiUrl: ~
  apiUrlBrowser: ${NUXT_PUBLIC_CWA_API_URL_BROWSER}
  replicaCount: ${PWA_REPLICA_COUNT:-"1"}
  autoscaling:
    enabled: ${PWA_AUTOSCALE:-"true"}
    minReplicas: ${PWA_AUTOSCALE_MIN:-$PWA_AUTOSCALE_MIN_DEFAULT}
    maxReplicas: ${PWA_AUTOSCALE_MAX:-$PWA_AUTOSCALE_MAX_DEFAULT}
    targetCPUUtilizationPercentage: ${PWA_AUTOSCALE_CPU_PERCENT:-"70"}
    targetMemoryUtilizationPercentage: ${PWA_AUTOSCALE_MEMORY_PERCENT:-"~"}
  resources:
    limits:
      cpu: ${PWA_CPU_LIMIT:-"1000m"}
      memory: ${PWA_MEMORY_LIMIT:-"1Gi"}
    requests:
      cpu: ${PWA_CPU_REQUEST:-$PWA_CPU_REQUEST_DEFAULT}
      memory: ${PWA_MEMORY_REQUEST:-$PWA_MEMORY_REQUEST_DEFAULT}
php:
  image:
    repository: ${PHP_REPOSITORY}
    tag: ${TAG}
    pullPolicy: Always
  admin:
    username: ${ADMIN_USERNAME:-"admin"}
    password: ${ADMIN_PASSWORD:-"admin"}
    email: ${ADMIN_EMAIL:-"hello@cwa.rocks"}
  gcloud:
    jsonKey: ${GCLOUD_JSON_B64:-"my-dummy-very-long-json-key-placeholder-value"}
    bucket: ${GCLOUD_BUCKET:-"no-gcloud-bucket"}
    publicUrl: "${GCLOUD_PUBLIC_URL:-}"
  resources:
    requests:
      cpu: ${PHP_CPU_REQUEST:-$PHP_CPU_REQUEST_DEFAULT}
      memory: ${PHP_MEMORY_REQUEST:-$PHP_MEMORY_REQUEST_DEFAULT}
  corsAllowOrigin: ${CORS_ALLOW_ORIGIN:-"~"}
  trustedHosts: ${TRUSTED_HOSTS:-"~"}
  resetDatabase: "${RESET_DATABASE:-false}"
  apiSecretToken: ${VARNISH_TOKEN:-"~"}
  mailer:
    dsn: ${MAILER_DSN:-"~"}
    email: ${MAILER_EMAIL:-"~"}
  jwt:
    passphrase: "${JWT_PASSPHRASE:-"~"}"
    samesite: "${JWT_COOKIE_SAMESITE:-"lax"}"
  mercure:
    jwt:
      algorithm: "${MERCURE_JWT_ALGORITHM:-"hmac.sha256"}"
  databaseSSL:
    ca: "${DATABASE_CA_CERT_B64}"
    key: "${DATABASE_CLIENT_KEY_B64}"
    cert: "${DATABASE_CLIENT_CERT_B64}"
    mode: "${DATABASE_SSL_MODE:-"prefer"}"
  caddy:
    cdnConfig: "${CADDY_CACHE_CDN_CONFIG_B64}"
    storageConfig: "${CADDY_CACHE_EXTRA_CONFIG_B64:-"otter"}"
mercure:
  corsOrigin: '${MERCURE_CORS_ORIGIN:-"*"}'
  publicUrl: https://${MERCURE_SUBSCRIBE_DOMAIN}/.well-known/mercure
  jwtKey:
    subscriber:
      algorithm: ${MERCURE_SUBSCRIBER_JWT_ALG:-"HS256"}
    publisher:
      algorithm: ${MERCURE_PUBLISHER_JWT_ALG:-"HS256"}
ingress:
  enabled: ${INGRESS_ENABLED:-"false"}
  annotations:
    "spec.ingressClassName": nginx
    "cert-manager.io/cluster-issuer": ${CLUSTER_ISSUER:-"~"}
    "nginx.ingress.kubernetes.io/connection-proxy-header": "keep-alive"
    "nginx.ingress.kubernetes.io/proxy-buffering": "on"
    "nginx.ingress.kubernetes.io/proxy-buffers-number": "4"
    "nginx.ingress.kubernetes.io/proxy-buffer-size": "256k"
    "nginx.ingress.kubernetes.io/proxy-body-size": "30m"
    "nginx.ingress.kubernetes.io/proxy-max-temp-file-size": "1024m"
    "nginx.ingress.kubernetes.io/from-to-www-redirect": "${KUBE_INGRESS_WWW_REDIRECT:-false}"
    "nginx.ingress.kubernetes.io/server-alias": "${KUBE_INGRESS_ALIAS_DOMAINS}"
  hosts:
    - host: ${DOMAIN:-"~"}
      paths:
        - path: '/'
          pathType: ImplementationSpecific
  tls:
    - secretName: ${TLS_SECRET_NAME}
      hosts:
        - ${DOMAIN:-"~"}
$(generate_alias_tls_yaml "$track")
postgresql:
  image:
    tag: ${DATABASE_IMAGE_TAG:-"14"}
  url: ${DATABASE_URL:-"~"}
  enabled: ${POSTGRESQL_ENABLED:-"true"}
  auth:
    postgresPassword: ${POSTGRES_ROOT_PASSWORD-"pg_root_password"}
    database: ${POSTGRES_DB:-"pg_database"}
    username: ${POSTGRES_USERNAME:-"pg_user"}
    password: ${POSTGRES_PASSWORD:-"pg_password"}
replicaCount: ${REPLICA_COUNT:-"1"}
podAnnotations:
  timestamp: "${CURRENT_DATE}"
  app.gitlab.com/app: "${CI_PROJECT_PATH_SLUG}"
  app.gitlab.com/env: "${CI_ENVIRONMENT_SLUG}"
# API (php) tier only - the PWA has its own block above. The default max is 1
# because Souin's cache store and Mercure's bolt transport are both pod-local,
# so a second pod would serve and purge a cache the first pod never sees. See
# the autoscaling comment in helm/cwa/values.yaml.
autoscaling:
  enabled: ${AUTOSCALE:-"true"}
  minReplicas: ${AUTOSCALE_MIN:-"1"}
  maxReplicas: ${AUTOSCALE_MAX:-"1"}
  targetCPUUtilizationPercentage: ${AUTOSCALE_CPU_PERCENT:-"90"}
  targetMemoryUtilizationPercentage: ${AUTOSCALE_MEMORY_PERCENT:-"90"}
EOF

  helm upgrade --install \
    --reset-values \
    --namespace="$KUBE_NAMESPACE" \
    "$name" ./helm/cwa \
    --set php.jwt.secret="${JWT_SECRET_KEY}" \
    --set php.jwt.public="${JWT_PUBLIC_KEY}" \
    --set php.caddy.globalConfig="${CADDY_GLOBAL_CONFIG}" \
    --set mercure.jwtKey.subscriber.key="${MERCURE_JWT_SECRET}" \
    --set mercure.jwtKey.publisher.key="${MERCURE_JWT_SECRET}" \
  	-f values.tmp.yaml || return 1

  if [ -n "$TLS_PREVIOUS_SECRET_NAME" ]; then
    cleanup_tls_certificates "$name" "$TLS_SECRET_NAME" "$TLS_PREVIOUS_SECRET_NAME"
  fi
}

persist_environment_url() {
	echo $CI_ENVIRONMENT_URL > environment_url.txt
}

load_fixtures() {
  local track="${1-stable}"
  local release_name="$RELEASE"
  if [[ "$track" != "stable" ]]; then
    release_name="$release_name-$track"
  fi

  local deploy
  deploy=$(kubectl get deploy -n "$KUBE_NAMESPACE" \
    -l "app.kubernetes.io/name=cwa,app.kubernetes.io/instance=$release_name" \
    -o name | head -1)

  echo "Waiting for PHP deployment to be ready..."
  kubectl rollout status "$deploy" -n "$KUBE_NAMESPACE" --timeout=600s

  # --append is what makes this safe to run against a real site. Without it,
  # doctrine:fixtures:load empties every table before loading, so one run on a
  # live environment wipes all its content (#74). Fixtures here exist to seed a
  # new environment and its first admin: UsersFixture is idempotent, and on a
  # database that already has content the scaffold stops on a duplicate route
  # rather than deleting anything.
  echo "Loading database fixtures (append - existing content is kept)..."
  kubectl exec -n "$KUBE_NAMESPACE" "$deploy" \
    -- env SKIP_MERCURE_PUBLISH=true php bin/console doctrine:fixtures:load --append --no-interaction
}

# Drops every cached rendered page (the `cwa-html` surrogate key) once a deploy
# has finished. A new front-end build changes the /_nuxt asset hashes on every page
# without changing any API resource, so nothing else purges the HTML; a cached page
# from the old build would load scripts and styles that now 404.
#
# Order matters. Wait for the PWA rollout first: until the old PWA pods are gone
# they can still render old-build HTML into the cache, including into a freshly
# restarted API pod's empty store. Then wait for the API so the exec does not land
# on a pod that is terminating.
#
# The two deployments are selected by their exact name labels - `cwa` is the API,
# `cwa-pwa` is the front end (label selectors never prefix-match).
#
# `kubectl exec deploy/...` reaches one pod. That is complete only because the API
# is capped at one replica: Souin's store is per pod, so raising that cap means
# running this against every API pod.
purge_rendered_html() {
  local track="${1-stable}"
  local release_name="$RELEASE"
  if [[ "$track" != "stable" ]]; then
    release_name="$release_name-$track"
  fi

  local api_deploy pwa_deploy
  api_deploy=$(kubectl get deploy -n "$KUBE_NAMESPACE" \
    -l "app.kubernetes.io/name=cwa,app.kubernetes.io/instance=$release_name" \
    -o name | head -1)
  pwa_deploy=$(kubectl get deploy -n "$KUBE_NAMESPACE" \
    -l "app.kubernetes.io/name=cwa-pwa,app.kubernetes.io/instance=$release_name" \
    -o name | head -1)

  if [[ -z "$api_deploy" || -z "$pwa_deploy" ]]; then
    echo "Could not find both deployments for release '$release_name' (api: '${api_deploy}', pwa: '${pwa_deploy}') - rendered HTML NOT purged"
    return 1
  fi

  echo "Waiting for the PWA rollout, so no old-build pod can refill the cache..."
  kubectl rollout status "$pwa_deploy" -n "$KUBE_NAMESPACE" --timeout=600s
  echo "Waiting for the API rollout..."
  kubectl rollout status "$api_deploy" -n "$KUBE_NAMESPACE" --timeout=600s

  echo "Purging rendered HTML..."
  kubectl exec -n "$KUBE_NAMESPACE" "$api_deploy" \
    -- php bin/console silverback:api-components:purge-rendered-html
}

# Refills the page cache that purge_rendered_html has just emptied (#80). Without
# this, the first visitor to every page after a deploy waits for an SSR render,
# and that post-deploy burst is the one realistic spike of uncached renders.
# It also replaces the old sitespeed `performance` job as the per-deploy speed
# check: every page's status and time to first byte (TTFB) is printed.
#
#   warm_cache [base_url]    base_url defaults to CI_ENVIRONMENT_URL
#
# Returns non-zero if the sitemap cannot be read, lists no pages, or any page
# answers anything other than 200. The deploy steps decide what to do with that;
# see the comment where it is called in .gitlab-ci.yml.
#
# How it works, and why:
# - It reads /sitemap.xml, following redirects (@nuxtjs/sitemap redirects it to
#   /sitemap_index.xml). A <sitemapindex> is followed one level into its child
#   sitemaps; a plain <urlset> is used as it is.
# - The XML is parsed with grep/sed only, pulling out each <loc>. jq and xmllint
#   are not on the CI images (GitLab's Alpine image, GitHub's ubuntu-latest),
#   and a sitemap is flat enough that <loc>...</loc> is all we need. <image:loc>
#   and xhtml:link alternates do not match. Only &amp; is decoded.
# - Every <loc> has its origin replaced with base_url. Souin keys on the Host, so
#   the cache is only filled for the host visitors use, and the sitemap's own
#   origin is not trustworthy for that (in dev it says http://localhost:3000).
# - Page requests are anonymous: curl sends no cookies unless told to, and no
#   Authorization is set. A request carrying an `api_component` cookie or an
#   Authorization header bypasses the shared cache, so it would warm nothing.
# - Redirects are NOT followed for pages. A sitemap should list final URLs, so a
#   3xx is reported as a failure like any other non-200.
# - Concurrency is modest (WARM_CACHE_CONCURRENCY, default 3). The point is to
#   spare the SSR pods a burst, not to create one.
# - Each page is stored once whatever the browser's Accept or Accept-Encoding
#   (#79), so one warm request per page fills the cache for every visitor.
# - WARM_CACHE_INSECURE=true skips TLS verification. It exists for testing
#   against the local stack's self-signed certificate; never set it in CI.
# - The public URL reaches whichever API pod the ingress picks. That is the whole
#   store while the API is capped at one replica (see purge_rendered_html). For
#   canary, it is whichever of the stable and canary pods answers.
#
# Portability: GitLab sources this file into busybox ash before `bash` exists, so
# no arrays, `wait -n` or process substitution. Parallelism is `xargs -0 -P`,
# which busybox supports.
warm_cache() {
  local base="${1:-$CI_ENVIRONMENT_URL}"
  local concurrency="${WARM_CACHE_CONCURRENCY:-3}"
  local tls_opt=""
  if [[ "$WARM_CACHE_INSECURE" == "true" ]]; then
    tls_opt="--insecure"
  fi

  if [[ -z "$base" ]]; then
    echo "!!!! CACHE WARM FAILED: no base URL (set CI_ENVIRONMENT_URL) !!!!"
    return 1
  fi
  case "$base" in
    http://*|https://*) ;;
    *) base="https://$base" ;;
  esac
  base="${base%/}"

  local tmp
  tmp=$(mktemp -d)

  # Prints the <loc> values of the XML on stdin, one per line, rewritten to $base.
  _warm_cache_locs() {
    tr '\r\n\t' '   ' \
      | grep -o '<loc>[^<]*</loc>' \
      | sed -E -e 's#</?loc>##g' -e 's#^ +##' -e 's# +$##' -e 's#&amp;#\&#g' \
               -e "s#^https?://[^/]+#${base}#"
  }

  echo "Reading the sitemap from ${base}/sitemap.xml..."
  if ! curl -fsSL $tls_opt --max-redirs 5 --max-time 60 --retry 2 --retry-connrefused \
      -o "$tmp/root.xml" "${base}/sitemap.xml"; then
    echo "!!!! CACHE WARM FAILED: could not fetch ${base}/sitemap.xml !!!!"
    rm -rf "$tmp"
    return 1
  fi

  : > "$tmp/urls.txt"
  if grep -q '<sitemapindex' "$tmp/root.xml"; then
    local child
    for child in $(_warm_cache_locs < "$tmp/root.xml"); do
      echo "  child sitemap: ${child}"
      if ! curl -fsSL $tls_opt --max-redirs 5 --max-time 60 --retry 2 --retry-connrefused \
          -o "$tmp/child.xml" "$child"; then
        echo "!!!! CACHE WARM FAILED: could not fetch child sitemap ${child} !!!!"
        rm -rf "$tmp"
        return 1
      fi
      _warm_cache_locs < "$tmp/child.xml" >> "$tmp/urls.txt"
    done
  else
    _warm_cache_locs < "$tmp/root.xml" >> "$tmp/urls.txt"
  fi
  # De-duplicate, keeping sitemap order.
  awk 'NF && !seen[$0]++' "$tmp/urls.txt" > "$tmp/pages.txt"

  local total
  total=$(wc -l < "$tmp/pages.txt" | tr -d ' ')
  if [[ "$total" -eq 0 ]]; then
    echo "!!!! CACHE WARM FAILED: the sitemap lists no pages !!!!"
    rm -rf "$tmp"
    return 1
  fi

  echo "Warming ${total} pages, ${concurrency} at a time (status, time to first byte, URL):"
  local started finished
  started=$(date +%s)
  # --retry covers a brief 502/503 while the ingress settles; a page that fails
  # every attempt is still reported with its final status. 000 means no response.
  tr '\n' '\0' < "$tmp/pages.txt" \
    | xargs -0 -n 1 -P "$concurrency" \
        curl -s $tls_opt -o /dev/null --max-time 60 --retry 2 --retry-delay 2 --retry-connrefused \
          -H 'Accept: text/html' \
          -w '%{http_code} %{time_starttransfer}s %{url_effective}\n' \
    | tee "$tmp/results.txt" \
    | sed 's#^#  #'
  finished=$(date +%s)

  local ok failed
  ok=$(grep -c '^200 ' "$tmp/results.txt")
  failed=$(( total - ok ))
  echo "Warmed ${ok} of ${total} pages in $(( finished - started ))s. Slowest:"
  sort -k2 -rn "$tmp/results.txt" | head -3 | sed 's#^#  #'

  if [[ "$failed" -ne 0 ]]; then
    echo ""
    echo "!!!! CACHE WARM FAILED: ${failed} of ${total} pages did not return 200 !!!!"
    grep -v '^200 ' "$tmp/results.txt" | sed 's#^#  #'
    # Shown on the workflow run's summary page, even though the job passes.
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
      echo "::error title=Cache warm failed::${failed} of ${total} sitemap pages did not return 200 - see the deploy step log"
    fi
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

function delete() {
	track="${1-stable}"
	name="$RELEASE"

	if [[ "$track" != "stable" ]]; then
		name="$name-$track"
	fi

  # soft fail the uninstall in case of failed permissions
	helm uninstall --namespace="$KUBE_NAMESPACE" "$name" || EXIT_CODE=$? && true
  echo ${EXIT_CODE}

  # If we delete the namespace, when we create it we also need to recreate role bindings - no permissions for this
  # We should see if that will be possible, or manually clean up empty namespaces when they are no longer needed
	#if [[ ${CI_ENVIRONMENT_SLUG:0:6} == "review" ]]; then
	#  echo "Deleting namespace $KUBE_NAMESPACE"
  #  kubectl delete namespace $KUBE_NAMESPACE --grace-period=0 || EXIT_CODE=$? && true
  #  echo ${EXIT_CODE}
	#else
	#  echo "Skipping namespace delete for slug $CI_ENVIRONMENT_SLUG and namespace $KUBE_NAMESPACE"
	#fi
}
