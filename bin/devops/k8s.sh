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
	# A key supplied without its passphrase can't be decrypted, and a random
	# passphrase would never match it: login would fail at runtime with a
	# decryption error. So that is a deploy error, not something to fill in.
	if [ -n "${JWT_SECRET_KEY}" ] && [ -z "${JWT_PASSPHRASE}" ]; then
		echo "!!!! JWT_SECRET_KEY is set but JWT_PASSPHRASE is empty. Set the passphrase the key was generated with. !!!!"
		return 1
	fi

	# Quoted POSIX tests throughout: a PEM key has spaces and newlines, and busybox
	# ash splits an unquoted one inside [[ ]], silently making the test false.
	if [ -z "${JWT_SECRET_KEY}" ]; then
		# A new key pair, with a new passphrase unless one was given.
		if [ -z "${JWT_PASSPHRASE}" ]; then
			echo "Generate JWT_PASSPHRASE..."
			export JWT_PASSPHRASE="$(rand_str)"
		fi
		echo "Generate JWT_SECRET_KEY..."
		JWT_SECRET_KEY_FILE=/tmp/jwt_secret

		openssl genpkey -pass pass:"${JWT_PASSPHRASE}" -aes256 -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out ${JWT_SECRET_KEY_FILE}
		export JWT_SECRET_KEY=$(cat ${JWT_SECRET_KEY_FILE})
		export JWT_PUBLIC_KEY=$(openssl pkey -in "$JWT_SECRET_KEY_FILE" -passin pass:"$JWT_PASSPHRASE" -pubout)

		rm ${JWT_SECRET_KEY_FILE}
	elif [ -z "${JWT_PUBLIC_KEY}" ]; then
		# Lexik can derive the public key at runtime, but only by decrypting the
		# private key on every verification. Deriving it here puts the real key in
		# the chart, and fails the deploy if the passphrase doesn't match the key.
		echo "Derive JWT_PUBLIC_KEY from JWT_SECRET_KEY..."
		if ! JWT_PUBLIC_KEY=$(printf '%s\n' "$JWT_SECRET_KEY" | openssl pkey -passin pass:"$JWT_PASSPHRASE" -pubout 2>/dev/null) || [ -z "${JWT_PUBLIC_KEY}" ]; then
			echo "!!!! Could not decrypt JWT_SECRET_KEY with JWT_PASSPHRASE. Check that they belong together. !!!!"
			return 1
		fi
		export JWT_PUBLIC_KEY
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

  # COMPOSER_AUTH (from GITHUB_TOKEN in setup.sh) authenticates composer's ~180
  # downloads from github.com. A build secret, so it's never written to the
  # image; empty is fine, the Dockerfile only uses it when it has content.
  docker buildx build --push \
  	--secret id=composer_auth,env=COMPOSER_AUTH \
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

  # Site settings are runtime env: never pass one as a --build-arg or --secret.
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
  APP_ENV=test vendor/bin/phpunit tests/Unit --log-junit build/logs/phpunit/junit.xml
}

run_test_functional() {
  # HTTP tests through API Platform's test client (tests/Functional). Each test drops and
  # rebuilds the schema, so this needs the job's own database (setup_test_db_environment).
  # CI variables can carry the real site's TRUSTED_HOSTS; the test client's host is localhost.
  export TRUSTED_HOSTS='^(?:localhost|caddy(?:\.local)?|example\.com)$'
  # CI variables beat .env.test: a project's live mail relay would deliver test email. Unset, tests get null://null.
  unset MAILER_DSN MAILER_EMAIL
  # CI's JWT_* hold key contents for the deploy, not .env's paths (#130).
  unset JWT_SECRET_KEY JWT_PUBLIC_KEY JWT_PASSPHRASE
  echo "run_test_functional function"
  cd ./api || return
  mkdir -p build/logs/phpunit/
  composer install -o --prefer-dist --no-scripts --ignore-platform-reqs
  # A test that signs in needs a keypair matching .env's JWT_PASSPHRASE. The
  # .pem files are git-ignored, so they aren't in the image, and this job doesn't
  # run generate_jwt_keys. --skip-if-exists leaves a working local checkout alone.
  APP_ENV=test php bin/console lexik:jwt:generate-keypair --skip-if-exists --no-interaction
  APP_ENV=test vendor/bin/phpunit tests/Functional --log-junit build/logs/phpunit/functional.xml
}

check_kube_domain() {
  if [[ -z "$DOMAIN" ]]; then
    echo "No domain to deploy to. setup.sh takes DOMAIN from the job's environment"
    echo "url (CI_ENVIRONMENT_URL), unless bin/devops/project.sh sets it: set the job's"
    echo "environment url, or the variable it uses (e.g. KUBE_INGRESS_BASE_DOMAIN)."
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

# Exit code of a review job whose branch has no namespace: GitLab shows it orange, not red (#4).
# Keep it in sync with the review job's `allow_failure: exit_codes` in .gitlab-ci.yml.
REVIEW_NO_NAMESPACE_EXIT_CODE=3

# Prints present, missing or error for $KUBE_NAMESPACE (call set_namespace first).
# NotFound and Forbidden both mean nobody provisioned it for this project; anything
# else (no cluster, a bad context) is a real error and must not look like a skip.
review_namespace_state() {
	ns_output=$(kubectl get namespace "$KUBE_NAMESPACE" 2>&1) && { echo present; return 0; }
	case "$ns_output" in
		*NotFound*|*Forbidden*|*forbidden*) echo missing ;;
		*) echo "$ns_output" >&2; echo error ;;
	esac
}

skip_review_without_namespace() {
	set_namespace
	case "$(review_namespace_state)" in
		present) ;;
		missing)
			echo "No namespace '$KUBE_NAMESPACE', so this branch has no review environment to deploy to."
			echo "Create it, with its role bindings, if this branch needs one."
			exit "$REVIEW_NO_NAMESPACE_EXIT_CODE"
			;;
		*)
			echo "Could not check for the namespace '$KUBE_NAMESPACE'."
			return 1
			;;
	esac
}

# Follow-on review jobs still run after an orange review (#99); environment_url.txt exists only if it deployed.
skip_unless_review_deployed() {
	if [ ! -f environment_url.txt ]; then
		echo "The review job didn't deploy (this branch has no namespace), so there is no review environment to use."
		exit "$REVIEW_NO_NAMESPACE_EXIT_CODE"
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
    -o yaml --dry-run=client | kubectl apply -n "$KUBE_NAMESPACE" -f -
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

# Optional ingress-nginx rate limits (#106). Counts every request (hits, /_nuxt) by
# the connecting address, so keep it far above Caddy's and off behind Cloudflare.
ingress_rate_limit_annotations() {
  if [ -z "${CWA_CI_INGRESS_RATE_LIMIT_RPS:-}" ]; then
    return
  fi
  printf '    "nginx.ingress.kubernetes.io/limit-rps": "%s"\n' "$CWA_CI_INGRESS_RATE_LIMIT_RPS"
  if [ -n "${CWA_CI_INGRESS_RATE_LIMIT_BURST_MULTIPLIER:-}" ]; then
    printf '    "nginx.ingress.kubernetes.io/limit-burst-multiplier": "%s"\n' "$CWA_CI_INGRESS_RATE_LIMIT_BURST_MULTIPLIER"
  fi
  if [ -n "${CWA_CI_INGRESS_RATE_LIMIT_CONNECTIONS:-}" ]; then
    printf '    "nginx.ingress.kubernetes.io/limit-connections": "%s"\n' "$CWA_CI_INGRESS_RATE_LIMIT_CONNECTIONS"
  fi
}

# The chart's `cwa.fullname` for a release (which names its main ingress); k8s.sh sets no name overrides.
cwa_fullname() {
  local full
  case "$1" in
    *cwa*) full="$1" ;;
    *) full="$1-cwa" ;;
  esac
  printf '%s' "$full" | cut -c1-63 | sed 's/-*$//'
}

# Picks the stable ingress's TLS secret; a changed host list gets a new one, issued before helm switches to it (#86).
# Sets TLS_SECRET_NAME, and TLS_PREVIOUS_SECRET_NAME for cleanup_tls_certificates.
ensure_tls_certificate() {
  local track="${1-stable}" release_name="$2" base="$3"
  local names current current_names hash new

  TLS_SECRET_NAME="$base"
  TLS_PREVIOUS_SECRET_NAME=""
  if [ "$track" != "stable" ] || [ "${CWA_CI_INGRESS_ENABLED:-false}" != "true" ] || [ -z "${CWA_CI_CLUSTER_ISSUER:-}" ]; then
    return 0
  fi
  if ! kubectl auth can-i create certificates.cert-manager.io -n "$KUBE_NAMESPACE" >/dev/null 2>&1; then
    echo "⚠️ TLS: cannot create cert-manager Certificates in '$KUBE_NAMESPACE', so a change of hostnames is not protected. Using '$base'."
    return 0
  fi

  names=$( { echo "$DOMAIN"; generate_alias_tls_yaml "$track" | sed 's/^ *- *//'; } \
    | tr 'A-Z' 'a-z' | sed '/^$/d' | sort -u )

  # The chart's own ingress by name: not by label (a redirect ingress shares them) or host (DOMAIN changes at launch).
  current=$(kubectl get ingress "$(cwa_fullname "$release_name")" -n "$KUBE_NAMESPACE" \
    -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null || true)
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
    name: $CWA_CI_CLUSTER_ISSUER
  dnsNames:
$(printf '%s\n' "$names" | sed 's/^/    - /')
EOF

  if ! kubectl wait -n "$KUBE_NAMESPACE" --for=condition=Ready "certificate/$new" \
      --timeout="${CWA_CI_TLS_CERTIFICATE_TIMEOUT:-600s}"; then
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

# Souin panics on a `cdn` line with no value while helm says deployed (#116); an unexpanded $NAME fails here too.
check_cdn_config() {
  local line directive value bad=""
  while IFS= read -r line; do
    set -f
    # shellcheck disable=SC2086
    set -- $line
    set +f
    directive="${1:-}"
    value="${2:-}"
    case "$directive" in
      api_key|email|hostname|network|provider|service_id|strategy|zone_id) ;;
      *) continue ;;
    esac
    if [ -z "$value" ]; then
      bad="${bad}  '$directive' has no value
"
    else
      case "$value" in
        '$'*) bad="${bad}  '$directive' is '$value', a variable reference that was never expanded
" ;;
      esac
    fi
  done <<EOF
${CADDY_CACHE_CDN_CONFIG:-}
EOF
  if [ -n "$bad" ]; then
    echo "CADDY_CACHE_CDN_CONFIG is incomplete, so php would not start:" >&2
    printf '%s' "$bad" >&2
    echo "Check the variable it refers to reaches this job (on GitLab, a Protected variable is only given to protected branches) and that its reference is expanded." >&2
    return 1
  fi
}

# The hostnames this deploy serves: DOMAIN, plus KUBE_INGRESS_ALIAS_DOMAINS on the
# stable track (the only one that gets them), space-separated.
site_hosts() {
  local hosts="$DOMAIN"
  if [ "${1:-stable}" = "stable" ]; then
    hosts="$hosts $(generate_alias_tls_yaml stable | sed 's/^ *- *//' | tr '\n' ' ')"
  fi
  echo $hosts
}

# Defaults a CI variable still overrides. CWA_CI_CLUSTER_ISSUER is defaulted in
# setup.sh (letsencrypt-staging): production certificates are opt-in.
apply_site_defaults() {
  local track="${1:-stable}" hosts alt="" origins="" host escaped
  hosts=$(site_hosts "$track")
  for host in $hosts; do
    escaped=$(printf '%s' "$host" | sed 's/[.]/\\./g')
    alt="${alt:+$alt|}$escaped"
    origins="${origins:+$origins }https://$host"
  done
  CWA_CI_INGRESS_ENABLED="${CWA_CI_INGRESS_ENABLED:-true}"
  CORS_ALLOW_ORIGIN="${CORS_ALLOW_ORIGIN:-^https://(?:$alt)\$}"
  TRUSTED_HOSTS="${TRUSTED_HOSTS:-^(?:$alt|localhost)\$}"
  MERCURE_CORS_ORIGIN="${MERCURE_CORS_ORIGIN:-$origins}"
  # An external database (no in-cluster PostgreSQL) is reached over the network,
  # so it needs TLS; the in-cluster chart's PostgreSQL has none.
  if [ "${CWA_CI_POSTGRES_ENABLED:-true}" = "false" ]; then
    DATABASE_SSL_MODE="${DATABASE_SSL_MODE:-require}"
  fi
}

# CWA_ENVIRONMENT / NUXT_PUBLIC_CWA_ENVIRONMENT, from the track (staging's GitLab
# job runs as environment: production). A CWA_ENVIRONMENT CI variable overrides it.
cwa_environment_name() {
  local name
  case "${1:-stable}" in
    stable) name="production" ;;
    *) name="$1" ;;
  esac
  name="${CWA_ENVIRONMENT:-$name}"
  case "$name" in
    ''|*[!A-Za-z0-9._-]*)
      echo "CWA_ENVIRONMENT must be letters, digits, '.', '_' or '-', not '$name'." >&2
      return 1
      ;;
  esac
  printf '%s' "$name"
}

# Names the chart sets with explicit `env:` entries, which would beat envFrom.
# Keep in sync with cwa.phpEnv, deployment.yaml and pwa-deployment.yaml.
# NUXT_PUBLIC_CWA_API_URL (deprecated) would put the internal API URL in pages.
SITE_ENV_RESERVED_API="
  ADMIN_EMAIL ADMIN_PASSWORD ADMIN_USERNAME APP_DEBUG APP_ENV APP_SECRET APP_UPSTREAM
  BROWSER_SERVER_NAME CACHE_URL CADDY_CACHE_CDN_CONFIG CADDY_CACHE_EXTRA_CONFIG
  CORS_ALLOW_ORIGIN CWA_ENVIRONMENT DATABASE_CA_CERT DATABASE_CLIENT_CERT
  DATABASE_CLIENT_KEY DATABASE_SSL_MODE DATABASE_URL FRANKENPHP_CONFIG GCLOUD_BUCKET
  GCLOUD_JSON GCLOUD_PUBLIC_URL GOMEMLIMIT JWT_PASSPHRASE JWT_PUBLIC_KEY JWT_SECRET_KEY
  MAILER_DSN MAILER_EMAIL MERCURE_CORS_ORIGIN MERCURE_EXTRA_DIRECTIVES
  MERCURE_JWT_SECRET MERCURE_PUBLIC_URL MERCURE_PUBLISHER_JWT_ALG
  MERCURE_PUBLISHER_JWT_KEY MERCURE_SUBSCRIBER_JWT_ALG MERCURE_SUBSCRIBER_JWT_KEY
  MERCURE_URL RESET_DATABASE SERVER_NAME TRUSTED_HOSTS TRUSTED_PROXIES
"
SITE_ENV_RESERVED_PWA="
  NUXT_CWA_API_URL NUXT_PUBLIC_CWA_API_URL NUXT_PUBLIC_CWA_API_URL_BROWSER
  NUXT_PUBLIC_CWA_ENVIRONMENT
"

# Site settings (#125): NUXT_PUBLIC_* to the PWA's ConfigMap, other NUXT_* to its Secret, CWA_API_<NAME> to the API's
# Secret as <NAME>. Prints a base64 values file; values are never printed. Fails on a reserved or unusable name.
site_env_values() {
  local environment="$1" names name target kind key value isset b64
  local pwa="" pwa_secret="" api_secret="" bad="" summary=""
  names=$(env | sed -n -e 's/^\(NUXT_[A-Za-z0-9_]*\)=.*/\1/p' -e 's/^\(CWA_API_[A-Za-z0-9_]*\)=.*/\1/p' | sort -u)
  for name in $names; do
    case "$name" in
      NUXT_PUBLIC_*) target=pwa; kind=config; key="$name" ;;
      NUXT_*) target=pwa; kind=secret; key="$name" ;;
      CWA_API_*) target=api; kind=secret; key="${name#CWA_API_}" ;;
      *) continue ;;
    esac
    eval "isset=\${$name+x}"
    [ -n "$isset" ] || continue
    eval "value=\${$name}"
    case "$key" in
      ''|[0-9]*|NUXT_|NUXT_PUBLIC_)
        bad="${bad}  $name: '$key' is not a usable variable name
"
        continue
        ;;
    esac
    if site_env_reserved "$target" "$key"; then
      bad="${bad}  $name: $key is reserved on the $target container: the chart or its image sets it (use its own CI variable, if it has one, or delete this one)
"
      continue
    fi
    # Empty would replace a Caddyfile/Symfony default; Nuxt applies empty on purpose.
    if [ "$target" = api ] && [ -z "$value" ]; then
      summary="${summary}  api: $key left unset, $name is empty
"
      continue
    fi
    b64=$(printf '%s' "$value" | base64 -w0)
    case "$target:$kind" in
      pwa:config) pwa="${pwa}    \"$key\": \"$b64\"
" ;;
      pwa:secret) pwa_secret="${pwa_secret}    \"$key\": \"$b64\"
" ;;
      api:secret) api_secret="${api_secret}    \"$key\": \"$b64\"
" ;;
    esac
    summary="${summary}  $target $kind $key (from $name)
"
  done

  if [ -n "$bad" ]; then
    echo "❌ Site environment variables (NUXT_*, CWA_API_*) that can't be passed through:" >&2
    printf '%s' "$bad" >&2
    return 1
  fi
  echo "Environment name: $environment" >&2
  if [ -n "$summary" ]; then
    echo "Site environment variables:" >&2
    printf '%s' "$summary" >&2
  else
    echo "Site environment variables: none" >&2
  fi

  printf 'cwaEnvironment: "%s"\nsiteEnv:\n' "$environment"
  site_env_block pwa "$pwa"
  site_env_block pwaSecret "$pwa_secret"
  site_env_block apiSecret "$api_secret"
}

site_env_reserved() {
  local list
  if [ "$1" = api ]; then list="$SITE_ENV_RESERVED_API"; else list="$SITE_ENV_RESERVED_PWA"; fi
  # Space-padded, so only whole names match.
  # shellcheck disable=SC2086,SC2116
  list=" $(echo $list) "
  case "$list" in
    *" $2 "*) return 0 ;;
  esac
  return 1
}

site_env_block() {
  if [ -n "$2" ]; then
    printf '  %s:\n%s' "$1" "$2"
  else
    printf '  %s: {}\n' "$1"
  fi
}

# A YAML single-quoted scalar.
yaml_squote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

# postgresql.global.postgresql.auth (Bitnami prefers it; secrets.yaml builds
# database-url from it), with only the values that are set.
postgres_auth_yaml() {
  local lines=""
  if [ -n "$POSTGRES_USER" ]; then
    lines="${lines}        username: $(yaml_squote "$POSTGRES_USER")
"
  fi
  if [ -n "$POSTGRES_PASSWORD" ]; then
    lines="${lines}        password: $(yaml_squote "$POSTGRES_PASSWORD")
"
  fi
  if [ -n "$POSTGRES_DB" ]; then
    lines="${lines}        database: $(yaml_squote "$POSTGRES_DB")
"
  fi
  if [ -n "$lines" ]; then
    printf '  global:\n    postgresql:\n      auth:\n%s' "$lines"
  fi
}

# postgresql.primary.persistence, with only the values that are set.
postgres_persistence_yaml() {
  local lines=""
  if [ -n "$CWA_CI_POSTGRES_PERSISTENCE" ]; then
    lines="${lines}      enabled: ${CWA_CI_POSTGRES_PERSISTENCE}
"
  fi
  if [ -n "$CWA_CI_POSTGRES_PERSISTENCE_SIZE" ]; then
    lines="${lines}      size: $(yaml_squote "$CWA_CI_POSTGRES_PERSISTENCE_SIZE")
"
  fi
  if [ -n "$CWA_CI_POSTGRES_STORAGE_CLASS" ]; then
    lines="${lines}      storageClass: $(yaml_squote "$CWA_CI_POSTGRES_STORAGE_CLASS")
"
  fi
  if [ -n "$lines" ]; then
    printf '  primary:\n    persistence:\n%s' "$lines"
  fi
}

# A StatefulSet's volumeClaimTemplates can't change, so stop before helm when the
# persistence settings differ from the live one, saying what to run.
check_postgres_persistence() {
  local name="$1" want="${CWA_CI_POSTGRES_PERSISTENCE:-}" size="${CWA_CI_POSTGRES_PERSISTENCE_SIZE:-}"
  local class="${CWA_CI_POSTGRES_STORAGE_CLASS:-}" out sts live_size live_class pvc fix
  case "$want" in
    ''|true|false) ;;
    *)
      echo "CWA_CI_POSTGRES_PERSISTENCE must be true or false, not '$want'." >&2
      return 1
      ;;
  esac
  if [ "${CWA_CI_POSTGRES_ENABLED:-true}" = "false" ] || [ -z "$want$size$class" ]; then
    return 0
  fi
  # Bitnami's "-" means no storage class.
  if [ "$class" = "-" ]; then class=""; fi
  if ! out=$(kubectl get statefulset -n "$KUBE_NAMESPACE" \
    -l "app.kubernetes.io/instance=$name,app.kubernetes.io/name=postgresql,app.kubernetes.io/component=primary" \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .spec.volumeClaimTemplates[?(@.metadata.name=="data")]}{.spec.resources.requests.storage}{" "}{.spec.storageClassName}{end}{"\n"}{end}' 2>&1); then
    echo "Warning: can't read the PostgreSQL StatefulSet, so the persistence check is skipped: $out" >&2
    return 0
  fi
  # No StatefulSet yet: a first deploy can have any volume.
  [ -n "$out" ] || return 0
  read -r sts live_size live_class <<EOF
$out
EOF
  pvc="data-$sts-0"
  fix="kubectl delete statefulset $sts -n $KUBE_NAMESPACE --cascade=orphan"
  if [ "$want" = "true" ] && [ -z "$live_size" ]; then
    echo "CWA_CI_POSTGRES_PERSISTENCE=true, but the live in-cluster PostgreSQL ($sts) has no volume, and helm can't add one to a StatefulSet." >&2
    echo "Its data lives only in the pod and is lost when the pod is replaced: pg_dump it first if you need it. Then run" >&2
    echo "  $fix" >&2
    echo "and deploy again. The new pod starts with an empty volume (load fixtures or restore the dump)." >&2
    return 1
  fi
  if [ "$want" = "false" ] && [ -n "$live_size" ]; then
    echo "CWA_CI_POSTGRES_PERSISTENCE=false, but the live in-cluster PostgreSQL ($sts) has a volume, and helm can't remove it from a StatefulSet." >&2
    echo "To stop using it, run" >&2
    echo "  $fix" >&2
    echo "and deploy again. The new pod starts empty; the volume ($pvc) and its data stay until you run kubectl delete pvc $pvc -n $KUBE_NAMESPACE." >&2
    return 1
  fi
  [ -n "$live_size" ] || return 0
  if [ -n "$size" ] && [ "$size" != "$live_size" ]; then
    echo "CWA_CI_POSTGRES_PERSISTENCE_SIZE=$size, but the live in-cluster PostgreSQL ($sts) was created with $live_size, and helm can't change it." >&2
    echo "Set it back to $live_size, or run" >&2
    echo "  $fix" >&2
    echo "and deploy again: the volume ($pvc) and its data are kept, still at $live_size. To grow it (if the storage class allows expansion):" >&2
    echo "  kubectl patch pvc $pvc -n $KUBE_NAMESPACE -p '{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"$size\"}}}}'" >&2
    return 1
  fi
  if [ -n "$CWA_CI_POSTGRES_STORAGE_CLASS" ] && [ "$class" != "$live_class" ]; then
    echo "CWA_CI_POSTGRES_STORAGE_CLASS=$CWA_CI_POSTGRES_STORAGE_CLASS, but the live in-cluster PostgreSQL ($sts) uses '$live_class', and helm can't change it." >&2
    echo "Set it back, or move to a new volume: pg_dump the data, then run" >&2
    echo "  $fix" >&2
    echo "  kubectl delete pvc $pvc -n $KUBE_NAMESPACE   # deletes the data" >&2
    echo "and deploy again, then restore the dump." >&2
    return 1
  fi
}

deploy() {
	local track="${1-stable}" environment_name site_env_yaml pwa_min_default pwa_max_default
	local pwa_cpu_request_default pwa_memory_request_default api_cpu_request_default
	local api_memory_request_default orphan_scan_default
	check_cdn_config || return 1
	apply_site_defaults "$track"
	# Before anything changes in the cluster, so a bad name stops the deploy cold.
	environment_name=$(cwa_environment_name "$track") || return 1
	site_env_yaml=$(site_env_values "$environment_name") || return 1
	name="$RELEASE"
	TLS_SECRET_NAME_SCOPED="$CWA_CI_TLS_SECRET_NAME-$track"
	if [[ "$track" != "stable" ]]; then
		name="$name-$track"
	fi

	echo "Installing/upgrading release '${name}' on namespace '${KUBE_NAMESPACE}' and host '${DOMAIN}' (${CI_ENVIRONMENT_URL})"

  if [[ -n "$CWA_CI_HELM_UNINSTALL" ]]; then
  	delete ${track}
  fi

  check_postgres_persistence "$name" || return 1
  ensure_tls_certificate "$track" "$name" "${TLS_SECRET_NAME_SCOPED}-api" || return 1

  DATABASE_CA_CERT_B64=$(echo "$DATABASE_CA_CERT" | base64 -w0)
  DATABASE_CLIENT_CERT_B64=$(echo "$DATABASE_CLIENT_CERT" | base64 -w0)
  DATABASE_CLIENT_KEY_B64=$(echo "$DATABASE_CLIENT_KEY" | base64 -w0)
  # Empty when unset, so the chart passes nothing and the Caddyfile's default
  # (`strategy hard`) applies. `echo "" | base64` gave "Cg==", a newline, which
  # replaced that default with an empty cdn block.
  CADDY_CACHE_CDN_CONFIG_B64=""
  if [ -n "${CADDY_CACHE_CDN_CONFIG:-}" ]; then
    CADDY_CACHE_CDN_CONFIG_B64=$(printf '%s\n' "$CADDY_CACHE_CDN_CONFIG" | base64 -w0)
  fi
  CADDY_CACHE_EXTRA_CONFIG_B64=$(echo "${CADDY_CACHE_EXTRA_CONFIG:-"otter"}" | base64 -w0)
  GCLOUD_JSON="${GCLOUD_JSON:-"{}"}"
  GCLOUD_JSON_B64=$(echo "$GCLOUD_JSON" | base64 -w0)
  NUXT_PUBLIC_CWA_API_URL_BROWSER="https://${DOMAIN}/_api"
  CURRENT_DATE=$(date)

  # Per-track sizing defaults (requests only; limits are the same on every track). A CI variable still wins.
  case "$track" in
    stable|canary)
      # Production keeps two SSR pods; a canary runs beside it, so one is enough (#124).
      if [ "$track" = "stable" ]; then pwa_min_default="2"; else pwa_min_default="1"; fi
      pwa_max_default="6"
      pwa_cpu_request_default="100m"
      pwa_memory_request_default="160Mi"
      api_cpu_request_default="100m"
      api_memory_request_default="350Mi"
      ;;
    *)
      pwa_min_default="1"
      pwa_max_default="2"
      pwa_cpu_request_default="100m"
      pwa_memory_request_default="128Mi"
      api_cpu_request_default="100m"
      api_memory_request_default="256Mi"
      ;;
  esac

  # The daily orphan scan runs on production only (#101): staging and canary can
  # share production's database, so their scans would send the same alert again.
  case "$track" in
    stable) orphan_scan_default="true" ;;
    *) orphan_scan_default="false" ;;
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
  replicaCount: ${CWA_CI_PWA_REPLICA_COUNT:-"1"}
  autoscaling:
    enabled: ${CWA_CI_PWA_AUTOSCALE:-"true"}
    minReplicas: ${CWA_CI_PWA_AUTOSCALE_MIN:-$pwa_min_default}
    maxReplicas: ${CWA_CI_PWA_AUTOSCALE_MAX:-$pwa_max_default}
    targetCPUUtilizationPercentage: ${CWA_CI_PWA_AUTOSCALE_CPU_PERCENT:-"175"}
    targetMemoryUtilizationPercentage: ${CWA_CI_PWA_AUTOSCALE_MEMORY_PERCENT:-"~"}
  resources:
    limits:
      cpu: ${CWA_CI_PWA_CPU_LIMIT:-"1000m"}
      memory: ${CWA_CI_PWA_MEMORY_LIMIT:-"1Gi"}
    requests:
      cpu: ${CWA_CI_PWA_CPU_REQUEST:-$pwa_cpu_request_default}
      memory: ${CWA_CI_PWA_MEMORY_REQUEST:-$pwa_memory_request_default}
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
    limits:
      memory: ${CWA_CI_API_MEMORY_LIMIT:-"1Gi"}
    requests:
      cpu: ${CWA_CI_API_CPU_REQUEST:-$api_cpu_request_default}
      memory: ${CWA_CI_API_MEMORY_REQUEST:-$api_memory_request_default}
  # Empty: 80% of the memory limit above (helm/cwa/values.yaml, #117).
  goMemLimit: "${CWA_CI_API_GOMEMLIMIT:-}"
  corsAllowOrigin: ${CORS_ALLOW_ORIGIN:-"~"}
  trustedHosts: ${TRUSTED_HOSTS:-"~"}
  resetDatabase: "${CWA_CI_RESET_DATABASE:-false}"
  mailer:
    dsn: ${MAILER_DSN:-"~"}
    email: ${MAILER_EMAIL:-"~"}
  jwt:
    passphrase: "${JWT_PASSPHRASE:-"~"}"
  databaseSSL:
    ca: "${DATABASE_CA_CERT_B64}"
    key: "${DATABASE_CLIENT_KEY_B64}"
    cert: "${DATABASE_CLIENT_CERT_B64}"
    mode: "${DATABASE_SSL_MODE:-"prefer"}"
  caddy:
    cdnConfig: "${CADDY_CACHE_CDN_CONFIG_B64}"
    storageConfig: "${CADDY_CACHE_EXTRA_CONFIG_B64:-"otter"}"
    # The other php settings are CWA_API_* site settings.
mercure:
  corsOrigin: '${MERCURE_CORS_ORIGIN:-"*"}'
  publicUrl: https://${MERCURE_SUBSCRIBE_DOMAIN}/.well-known/mercure
  jwtKey:
    subscriber:
      algorithm: ${MERCURE_SUBSCRIBER_JWT_ALG:-"HS256"}
    publisher:
      algorithm: ${MERCURE_PUBLISHER_JWT_ALG:-"HS256"}
ingress:
  enabled: ${CWA_CI_INGRESS_ENABLED:-"false"}
  annotations:
    "spec.ingressClassName": nginx
    "cert-manager.io/cluster-issuer": ${CWA_CI_CLUSTER_ISSUER:-"~"}
    "nginx.ingress.kubernetes.io/connection-proxy-header": "keep-alive"
    "nginx.ingress.kubernetes.io/proxy-buffering": "on"
    "nginx.ingress.kubernetes.io/proxy-buffers-number": "4"
    "nginx.ingress.kubernetes.io/proxy-buffer-size": "256k"
    "nginx.ingress.kubernetes.io/proxy-body-size": "30m"
    "nginx.ingress.kubernetes.io/proxy-max-temp-file-size": "1024m"
    "nginx.ingress.kubernetes.io/from-to-www-redirect": "${CWA_CI_WWW_REDIRECT:-false}"
    "nginx.ingress.kubernetes.io/server-alias": "${KUBE_INGRESS_ALIAS_DOMAINS}"
$(ingress_rate_limit_annotations)
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
    tag: ${CWA_CI_POSTGRES_IMAGE_TAG:-"14"}
  url: ${DATABASE_URL:-"~"}
  enabled: ${CWA_CI_POSTGRES_ENABLED:-"true"}
  auth:
    postgresPassword: ${POSTGRES_ROOT_PASSWORD-"pg_root_password"}
$(postgres_auth_yaml)
$(postgres_persistence_yaml)
replicaCount: ${CWA_CI_API_REPLICA_COUNT:-"1"}
podAnnotations:
  timestamp: "${CURRENT_DATE}"
  app.gitlab.com/app: "${CI_PROJECT_PATH_SLUG}"
  app.gitlab.com/env: "${CI_ENVIRONMENT_SLUG}"
# API (php) tier only - the PWA has its own block above. The default max is 1
# because Souin's cache store and Mercure's bolt transport are both pod-local,
# so a second pod would serve and purge a cache the first pod never sees. See
# the autoscaling comment in helm/cwa/values.yaml.
autoscaling:
  enabled: ${CWA_CI_API_AUTOSCALE:-"true"}
  minReplicas: ${CWA_CI_API_AUTOSCALE_MIN:-"1"}
  maxReplicas: ${CWA_CI_API_AUTOSCALE_MAX:-"1"}
  targetCPUUtilizationPercentage: ${CWA_CI_API_AUTOSCALE_CPU_PERCENT:-"90"}
  targetMemoryUtilizationPercentage: ${CWA_CI_API_AUTOSCALE_MEMORY_PERCENT:-"90"}
cronjobs:
  orphanScan:
    enabled: ${CWA_CI_ORPHAN_SCAN:-$orphan_scan_default}
    schedule: "${CWA_CI_ORPHAN_SCAN_SCHEDULE:-0 3 * * *}"
    timeZone: "${CWA_CI_ORPHAN_SCAN_TIMEZONE:-Europe/London}"
EOF

  # Holds secrets: removed after helm.
  printf '%s\n' "$site_env_yaml" > values.site-env.tmp.yaml

  # A project's own chart values (optional): project_values, defined in
  # bin/devops/project.sh, prints YAML for this track, e.g. the settings of a
  # template the project adds to helm/cwa/templates. Applied last.
  local project_values_args=()
  if declare -F project_values >/dev/null; then
    project_values "$track" > values.project.tmp.yaml || return 1
    project_values_args=(-f values.project.tmp.yaml)
  fi

  helm upgrade --install \
    --reset-values \
    --namespace="$KUBE_NAMESPACE" \
    "$name" ./helm/cwa \
    --set php.jwt.secret="${JWT_SECRET_KEY}" \
    --set php.jwt.public="${JWT_PUBLIC_KEY}" \
    --set mercure.jwtKey.subscriber.key="${MERCURE_JWT_SECRET}" \
    --set mercure.jwtKey.publisher.key="${MERCURE_JWT_SECRET}" \
  	-f values.tmp.yaml \
  	-f values.site-env.tmp.yaml \
  	"${project_values_args[@]}" || { rm -f values.site-env.tmp.yaml values.project.tmp.yaml; return 1; }
  rm -f values.site-env.tmp.yaml values.project.tmp.yaml

  if [ -n "$TLS_PREVIOUS_SECRET_NAME" ]; then
    cleanup_tls_certificates "$name" "$TLS_SECRET_NAME" "$TLS_PREVIOUS_SECRET_NAME"
  fi
}

# The URL this deploy went to: environment_url.txt (the artifact), and
# environment_url.env, a dotenv report a job can use as its environment url
# (`url: $SITE_ENVIRONMENT_URL` with `artifacts: reports: dotenv:`) when the
# domain is worked out in the job (bin/devops/project.sh) rather than known
# up front.
persist_environment_url() {
	echo "https://${DOMAIN}" > environment_url.txt
	echo "SITE_ENVIRONMENT_URL=https://${DOMAIN}" > environment_url.env
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
    -o name | sed -n 1p)

  echo "Waiting for PHP deployment to be ready..."
  kubectl rollout status "$deploy" -n "$KUBE_NAMESPACE" --timeout=600s

  # CWA_CI_FIXTURES_PURGE empties every table first: review on "true" or "force", production only on "force".
  # Otherwise the load appends (#74). Staging has no fixture job: it would write to production's database.
  local append="--append"
  case "$track:${CWA_CI_FIXTURES_PURGE:-false}" in
    review:true|review:force|stable:force)
      append=""
      echo "CWA_CI_FIXTURES_PURGE=$CWA_CI_FIXTURES_PURGE: EMPTYING EVERY TABLE in $KUBE_NAMESPACE, then loading fixtures..."
      ;;
    stable:true)
      echo "CWA_CI_FIXTURES_PURGE=true is ignored for production, which needs CWA_CI_FIXTURES_PURGE=force. Appending instead."
      ;;
    *:true|*:force)
      echo "CWA_CI_FIXTURES_PURGE is only read for review apps and production. Appending instead."
      ;;
  esac
  [ -n "$append" ] && echo "Loading database fixtures (append - existing content is kept)..."
  kubectl exec -n "$KUBE_NAMESPACE" "$deploy" \
    -- env SKIP_MERCURE_PUBLISH=true php bin/console doctrine:fixtures:load $append --no-interaction

  # The load changes data under Souin's cache, so flush all of it; one pod is enough while the API has one replica.
  echo "Flushing the HTTP cache..."
  kubectl exec -n "$KUBE_NAMESPACE" "$deploy" \
    -- php bin/console silverback:api-components:purge-http-cache
}

# Drops every cached page (`cwa-html`) after a deploy, or old HTML loads /_nuxt files that now 404 (#71).
# Waits for the PWA, then the API. `exec deploy/...` reaches one pod: complete only while the API has one replica.
purge_rendered_html() {
  local track="${1-stable}"
  local release_name="$RELEASE"
  if [[ "$track" != "stable" ]]; then
    release_name="$release_name-$track"
  fi

  local api_deploy pwa_deploy
  api_deploy=$(kubectl get deploy -n "$KUBE_NAMESPACE" \
    -l "app.kubernetes.io/name=cwa,app.kubernetes.io/instance=$release_name" \
    -o name | sed -n 1p)
  pwa_deploy=$(kubectl get deploy -n "$KUBE_NAMESPACE" \
    -l "app.kubernetes.io/name=cwa-pwa,app.kubernetes.io/instance=$release_name" \
    -o name | sed -n 1p)

  if [[ -z "$api_deploy" || -z "$pwa_deploy" ]]; then
    echo "Could not find both deployments for release '$release_name' (api: '${api_deploy}', pwa: '${pwa_deploy}') - rendered HTML NOT purged"
    return 1
  fi

  echo "Waiting for the PWA rollout, so no old-build pod can refill the cache..."
  kubectl rollout status "$pwa_deploy" -n "$KUBE_NAMESPACE" --timeout=600s
  echo "Waiting for the API rollout..."
  kubectl rollout status "$api_deploy" -n "$KUBE_NAMESPACE" --timeout=600s

  # With Cloudflare (#108) the edge also holds /_api responses, so flush everything, which purges the whole zone.
  # Staging shares CADDY_CACHE_CDN_CONFIG, so its deploys purge the zone too.
  case "${CADDY_CACHE_CDN_CONFIG:-}" in
    *"provider cloudflare"*)
      echo "Cloudflare is configured: flushing the HTTP cache, which also purges everything at Cloudflare..."
      kubectl exec -n "$KUBE_NAMESPACE" "$api_deploy" \
        -- php bin/console silverback:api-components:purge-http-cache
      ;;
    *)
      echo "Purging rendered HTML..."
      kubectl exec -n "$KUBE_NAMESPACE" "$api_deploy" \
        -- php bin/console silverback:api-components:purge-rendered-html
      ;;
  esac
}

# Refills the page cache after purge_rendered_html (#80): warm_cache [base_url]. Fails on any page that isn't 200.
# GitLab sources this into busybox ash: no arrays, `wait -n` or process substitution, and no jq or xmllint.
warm_cache() {
  local base="${1:-$CI_ENVIRONMENT_URL}"
  local concurrency="${CWA_CI_WARM_CACHE_CONCURRENCY:-3}"
  local tls_opt=""
  if [[ "$CWA_CI_WARM_CACHE_INSECURE" == "true" ]]; then
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

  if ! sitemap_pages "$base" "$tmp/pages.txt" "$tls_opt" "CACHE WARM"; then
    rm -rf "$tmp"
    return 1
  fi

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
  # sed, not head: head exits after three lines, and under GitLab's pipefail the
  # SIGPIPE that sort then takes fails a warm that succeeded (exit 141, GitLab #2).
  sort -k2 -rn "$tmp/results.txt" | sed -n '1,3s#^#  #p'

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

# Writes the sitemap's page URLs to <out>, de-duplicated, origins replaced by <base_url>, for warm_cache and audits.
#   sitemap_pages <base_url> <out> <curl_tls_opt> <label>
sitemap_pages() {
  local base="$1" out="$2" tls_opt="$3" label="$4"
  local tmp child
  tmp=$(mktemp -d)

  # Prints the <loc> values of the XML on stdin, one per line, rewritten to $base.
  _sitemap_locs() {
    tr '\r\n\t' '   ' \
      | grep -o '<loc>[^<]*</loc>' \
      | sed -E -e 's#</?loc>##g' -e 's#^ +##' -e 's# +$##' -e 's#&amp;#\&#g' \
               -e "s#^https?://[^/]+#${base}#"
  }

  echo "Reading the sitemap from ${base}/sitemap.xml..."
  if ! curl -fsSL $tls_opt --max-redirs 5 --max-time 60 --retry 2 --retry-connrefused \
      -o "$tmp/root.xml" "${base}/sitemap.xml"; then
    echo "!!!! ${label} FAILED: could not fetch ${base}/sitemap.xml !!!!"
    rm -rf "$tmp"
    return 1
  fi

  : > "$tmp/urls.txt"
  if grep -q '<sitemapindex' "$tmp/root.xml"; then
    for child in $(_sitemap_locs < "$tmp/root.xml"); do
      echo "  child sitemap: ${child}"
      if ! curl -fsSL $tls_opt --max-redirs 5 --max-time 60 --retry 2 --retry-connrefused \
          -o "$tmp/child.xml" "$child"; then
        echo "!!!! ${label} FAILED: could not fetch child sitemap ${child} !!!!"
        rm -rf "$tmp"
        return 1
      fi
      _sitemap_locs < "$tmp/child.xml" >> "$tmp/urls.txt"
    done
  else
    _sitemap_locs < "$tmp/root.xml" >> "$tmp/urls.txt"
  fi
  # De-duplicate, keeping sitemap order.
  awk 'NF && !seen[$0]++' "$tmp/urls.txt" > "$out"
  rm -rf "$tmp"
}

# Lighthouse CI audit of a few cached pages (#87): performance_audit [base_url]. Settings are the locals below.
# A missed budget returns 1; the CI jobs allow it to fail, so it never fails a live deploy.
performance_audit() {
  local base="${1:-$CI_ENVIRONMENT_URL}"
  local max="${CWA_CI_PERFORMANCE_AUDIT_MAX_PAGES:-3}"
  local runs="${CWA_CI_PERFORMANCE_AUDIT_RUNS:-5}"
  local form_factors="${CWA_CI_PERFORMANCE_AUDIT_FORM_FACTORS:-mobile}"
  local config="${CWA_CI_PERFORMANCE_AUDIT_CONFIG:-bin/devops/lighthouserc.json}"
  local out="${CWA_CI_PERFORMANCE_AUDIT_OUTPUT:-performance-report}"
  local lhci="npx --yes @lhci/cli@${CWA_CI_PERFORMANCE_AUDIT_LHCI_VERSION:-0.15.1}"
  local chrome_flags="--headless=new --no-sandbox --disable-dev-shm-usage"
  # Real throttling by default: simulated scores are bimodal on shared CI runners.
  local throttling="${CWA_CI_PERFORMANCE_AUDIT_THROTTLING:-devtools}"
  local tls_opt="" status=0 ff preset page tmp

  if [ "${CWA_CI_PERFORMANCE_AUDIT_INSECURE:-}" = "true" ]; then
    tls_opt="--insecure"
    chrome_flags="$chrome_flags --ignore-certificate-errors"
  fi
  if [ -z "$base" ]; then
    echo "!!!! PERFORMANCE AUDIT FAILED: no base URL (set CI_ENVIRONMENT_URL) !!!!"
    return 1
  fi
  case "$base" in
    http://*|https://*) ;;
    *) base="https://$base" ;;
  esac
  base="${base%/}"

  tmp=$(mktemp -d)
  if [ -n "${CWA_CI_PERFORMANCE_AUDIT_URLS:-}" ]; then
    for page in $(echo "$CWA_CI_PERFORMANCE_AUDIT_URLS" | tr ',' ' '); do
      case "$page" in
        http://*|https://*) echo "$page" ;;
        /*) echo "${base}${page}" ;;
        *) echo "${base}/${page}" ;;
      esac
    done > "$tmp/pages.txt"
  else
    if ! sitemap_pages "$base" "$tmp/all.txt" "$tls_opt" "PERFORMANCE AUDIT"; then
      rm -rf "$tmp"
      return 1
    fi
    head -n "$max" "$tmp/all.txt" > "$tmp/pages.txt"
  fi
  if [ ! -s "$tmp/pages.txt" ]; then
    echo "!!!! PERFORMANCE AUDIT FAILED: no pages to audit !!!!"
    rm -rf "$tmp"
    return 1
  fi

  echo "Auditing $(wc -l < "$tmp/pages.txt" | tr -d ' ') pages (${form_factors}, ${runs} runs each):"
  sed 's#^#  #' "$tmp/pages.txt"

  rm -rf "$out"
  mkdir -p "$out"
  for ff in $(echo "$form_factors" | tr ',' ' '); do
    case "$ff" in
      mobile) preset="" ;;
      desktop) preset="--collect.settings.preset=desktop" ;;
      *)
        echo "!!!! PERFORMANCE AUDIT: unknown form factor '$ff' (use mobile or desktop) !!!!"
        status=1
        continue
        ;;
    esac

    # One --collect.url per page. Positional parameters are the only list that
    # works in busybox ash, and this function has finished with its own.
    set --
    while read -r page; do
      set -- "$@" "--collect.url=$page"
    done < "$tmp/pages.txt"

    echo "--- ${ff}"
    rm -rf .lighthouseci
    # Every collect setting goes on the command line: any --collect.settings.* replaces lighthouserc.json's whole block.
    if ! $lhci collect --config="$config" --collect.numberOfRuns="$runs" \
        --collect.settings.chromeFlags="$chrome_flags" \
        --collect.settings.onlyCategories=performance \
        --collect.settings.throttlingMethod="$throttling" \
        $preset "$@"; then
      echo "!!!! PERFORMANCE AUDIT FAILED: Lighthouse could not collect the ${ff} results !!!!"
      status=1
      continue
    fi
    if ! $lhci assert --config="$config" > "$out/${ff}-assertions.txt" 2>&1; then
      status=1
    fi
    cat "$out/${ff}-assertions.txt"
    $lhci upload --target=filesystem --outputDir="$out/${ff}" || status=1
  done
  rm -rf "$tmp" .lighthouseci

  # Prints an aligned table for the job log and writes summary.md (Markdown) for GitHub.
  node bin/devops/lighthouse-summary.mjs "$out" "$config" || status=1
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    cat "$out/summary.md" >> "$GITHUB_STEP_SUMMARY"
  fi

  if [ "$status" -ne 0 ]; then
    echo ""
    echo "!!!! PERFORMANCE AUDIT: a budget was missed or a page could not be audited - see above !!!!"
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
      echo "::warning title=Performance audit::A Lighthouse budget was missed or a page could not be audited - see the step summary"
    fi
    return 1
  fi
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

  # helm leaves PVCs behind; a review app's goes with it. Other tracks keep theirs.
  if [ "$track" = "review" ]; then
    kubectl delete pvc --namespace="$KUBE_NAMESPACE" --wait=false \
      -l "app.kubernetes.io/instance=$name,app.kubernetes.io/name=postgresql" || true
  fi

  # Namespaces are never deleted: CI can't recreate their role bindings (see ensure_namespace).
}
