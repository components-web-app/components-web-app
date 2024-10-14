rand_str() {
  len=32
  head -c 256 /dev/urandom > /tmp/urandom.out
  tr -dc 'a-zA-Z0-9' < /tmp/urandom.out > /tmp/urandom.tr
  head -c ${len} /tmp/urandom.tr
}

install_dependencies() {
  echo "Adding openssl curl tar gzip ca-certificates git nodejs npm ..."
  # upgrade for curl fix https://github.com/curl/curl/issues/4357
  apk add --update-cache --upgrade --no-cache -U openssl curl tar gzip ca-certificates git nodejs npm openssh-keygen

  echo "Install glibc"
	wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
	apk add gcompat

  echo "Intalling helm..."
  curl "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar zx
  mv linux-amd64/helm /usr/bin/

  helm version

  echo "Intalling kubectl v${KUBERNETES_VERSION}..."
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

  docker pull $PHP_REPOSITORY:$TAG || true
  docker pull $PHP_REPOSITORY:dev || true

  docker build \
  	--build-arg BUILDKIT_INLINE_CACHE=1 \
  	--cache-from $PHP_REPOSITORY:$TAG \
  	--cache-from $PHP_REPOSITORY:dev \
  	--tag $PHP_REPOSITORY:$TAG \
  	--tag $PHP_REPOSITORY:dev \
  	--target frankenphp_prod \
  	"api"

  docker push $PHP_REPOSITORY:$TAG
}

build_app() {
  # https://gitlab.com/help/ci/variables/predefined_variables.md
  if [[ -n "$CI_REGISTRY_USER" ]]; then
    echo "Logging to GitLab Container Registry with CI credentials..."
    docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    echo ""
  fi

  docker pull $APP_REPOSITORY:$TAG || true
  docker pull $APP_REPOSITORY:dev || true

  docker build \
  	--build-arg BUILDKIT_INLINE_CACHE=1 \
  	--cache-from $APP_REPOSITORY:$TAG \
  	--cache-from $APP_REPOSITORY:dev \
  	--tag $APP_REPOSITORY:$TAG \
  	--tag $APP_REPOSITORY:dev \
  	--target prod \
  	"app"

  docker push $APP_REPOSITORY:$TAG
}

run_test_phpunit() {
  echo "run_phpunit function"
  cd ./api || return
  mkdir -p build/logs/phpunit/
  composer install -o --prefer-dist --no-scripts --ignore-platform-reqs
  vendor/bin/simple-phpunit tests/Unit --log-junit build/logs/phpunit/junit.xml
}

run_test_behat() {
	export TRUSTED_HOSTS='^localhost|caddy(\.local)?|example\.com$'
  echo "run_behat function"
  cd ./api || return
  mkdir -p build/logs/behat/
  composer install -o --prefer-dist --no-scripts --ignore-platform-reqs
  echo "Behat environment for DATABASE_URL: ${DATABASE_URL}"
  bin/console doctrine:query:sql "CREATE EXTENSION IF NOT EXISTS citext;"
  vendor/bin/behat --format=progress --out=std --format=junit --out=build/logs/behat/junit --profile=default --no-interaction --colors --tags='~@wip'
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
  helm repo add bitnami https://charts.bitnami.com/bitnami
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
    -o yaml --dry-run | kubectl replace -n "$KUBE_NAMESPACE" --force -f -
}

deploy() {
	track="${1-stable}"
	name="$RELEASE"
	LETSENCRYPT_SECRET_NAME_SCOPED="$LETSENCRYPT_SECRET_NAME-$track"
	if [[ "$track" != "stable" ]]; then
		name="$name-$track"
	fi

	echo "Installing/upgrading release '${name}' on namespace '${KUBE_NAMESPACE}' and host '${DOMAIN}' (${CI_ENVIRONMENT_URL})"

  if [[ -n "$HELM_UNINSTALL" ]]; then
  	delete ${track}
  fi

  DATABASE_CA_CERT_B64=$(echo "$DATABASE_CA_CERT" | base64 -w0)
  DATABASE_CLIENT_CERT_B64=$(echo "$DATABASE_CLIENT_CERT" | base64 -w0)
  DATABASE_CLIENT_KEY_B64=$(echo "$DATABASE_CLIENT_KEY" | base64 -w0)
  GCLOUD_JSON="${GCLOUD_JSON:-"{}"}"
  GCLOUD_JSON_B64=$(echo "$GCLOUD_JSON" | base64 -w0)
  NUXT_PUBLIC_CWA_API_URL_BROWSER="https://${DOMAIN}"

  cat >values.tmp.yaml <<EOF
imagePullSecrets:
  - name: ${GITLAB_PULL_SECRET_NAME:-"~"}
pwa:
  image:
    repository: ${APP_REPOSITORY}
    tag: ${TAG}
    pullPolicy: Always
  apiUrl: ${NUXT_PUBLIC_CWA_API_URL_BROWSER}
  apiUrlBrowser: ${NUXT_PUBLIC_CWA_API_URL_BROWSER}
php:
  admin:
    username: ${ADMIN_USERNAME:-"admin"}
    password: ${ADMIN_PASSWORD:-"admin"}
    email: ${ADMIN_EMAIL:-"hello@cwa.rocks"}
  gcloud:
    jsonKey: ${GCLOUD_JSON_B64:-"my-dummy-very-long-json-key-placeholder-value"}
    bucket: ${GCLOUD_BUCKET:-"no-gcloud-bucket"}
  image:
    repository: ${PHP_REPOSITORY}
    tag: ${TAG}
    pullPolicy: Always
  corsAllowOrigin: ${CORS_ALLOW_ORIGIN:-"~"}
  trustedHosts: ${TRUSTED_HOSTS:-"~"}
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
replicaCount: ${API_REPLICA_COUNT:-"2"}
autoscaling:
  enabled: ${API_AUTOSCALE:-"true"}
  minReplicas: ${API_AUTOSCALE_MIN:-"2"}
  maxReplicas: ${API_AUTOSCALE_MAX:-"4"}
  targetCPUUtilizationPercentage: ${API_AUTOSCALE_CPU:-"80"}
  targetMemoryUtilizationPercentage: ${API_AUTOSCALE_MEMORY:-"80"}
mercure:
  corsOrigin: '${MERCURE_CORS_ORIGIN:-"*"}'
  publicUrl: https://${MERCURE_SUBSCRIBE_DOMAIN}/.well-known/mercure
  jwtKey:
    subscriber:
      algorithm: ${MERCURE_SUBSCRIBER_JWT_ALG:-"HS256"}
    publisher:
      algorithm: ${MERCURE_PUBLISHER_JWT_ALG:-"HS256"}
caddy:
  replicaCount: ${CADDY_REPLICA_COUNT:-"1"}
  image:
    repository: ${CADDY_REPOSITORY}
    tag: ${TAG}
    pullPolicy: Always
varnish:
  enabled: ${VARNISH_ENABLED:="true"}
  replicaCount: ${VARNISH_REPLICA_COUNT:-"1"}
  image:
    repository: ${VARNISH_REPOSITORY}
    tag: ${TAG}
    pullPolicy: Always
ingress:
  enabled: ${INGRESS_ENABLED:-"false"}
  annotations:
    "spec.ingressClassName": nginx
    "cert-manager.io/cluster-issuer": ${CLUSTER_ISSUER:-"~"}
  hosts:
    - host: ${DOMAIN:-"~"}
      paths:
        - path: '/'
          pathType: ImplementationSpecific
  tls:
    - secretName: ${LETSENCRYPT_SECRET_NAME_SCOPED}-api
      hosts:
        - ${DOMAIN:-"~"}
annotations:
  app.gitlab.com/app: "${CI_PROJECT_PATH_SLUG}"
  app.gitlab.com/env: "${CI_ENVIRONMENT_SLUG}"
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
EOF

  helm upgrade --install \
    --reset-values \
    --namespace="$KUBE_NAMESPACE" \
    "$name" ./helm/cwa \
    --set php.jwt.secret="${JWT_SECRET_KEY}" \
    --set php.jwt.public="${JWT_PUBLIC_KEY}" \
    --set mercure.jwtKey.subscriber.key="${MERCURE_JWT_SECRET}" \
    --set mercure.jwtKey.publisher.key="${MERCURE_JWT_SECRET}" \
  	-f values.tmp.yaml
}

persist_environment_url() {
	echo $CI_ENVIRONMENT_URL > environment_url.txt
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
