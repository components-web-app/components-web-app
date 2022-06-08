#!/usr/bin/env bash

# echo the commands that are run
[[ "$TRACE" ]] && set -x

export CI_APPLICATION_REPOSITORY=$CI_REGISTRY_IMAGE/$CI_COMMIT_REF_SLUG
export CI_APPLICATION_TAG=$CI_COMMIT_SHA

export GITLAB_PULL_SECRET_NAME=gitlab-registry
export KUBERNETES_VERSION=1.18.2
export HELM_VERSION=3.4.1
export GLIBC_VERSION=2.33-r0

# Choose the branch for production deploy.
if [[ -z "$DEPLOYMENT_BRANCH" ]]; then
  export DEPLOYMENT_BRANCH=main
fi

# Miscellaneous
if [[ -z "$CLUSTER_ISSUER" ]]; then
  export CLUSTER_ISSUER="letsencrypt-staging"
fi
if [[ -z "$LETSENCRYPT_SECRET_NAME" ]]; then
  export LETSENCRYPT_SECRET_NAME="letsencrypt-cert"
fi

export DOMAIN=$(basename ${CI_ENVIRONMENT_URL})
export DOCKER_REPOSITORY=${CI_REGISTRY_IMAGE}
export PHP_REPOSITORY="${DOCKER_REPOSITORY}/php"
export CADDY_REPOSITORY="${DOCKER_REPOSITORY}/caddy"
export VARNISH_REPOSITORY="${DOCKER_REPOSITORY}/varnish"

export MERCURE_SUBSCRIBE_DOMAIN="${DOMAIN/caddy.}"

if [[ -z "$CORS_ALLOW_ORIGIN" ]]; then
  echo "!!!! WARNING CORS_ALLOW_ORIGIN ENVIRONMENT IS NOT SET !!!!";
  echo "Expected a regex string similar to ^https?:\/\/(.*\.)?example\.com"
fi
if [[ -z "$TRUSTED_HOSTS" ]]; then
  echo '!!!! WARNING TRUSTED_HOSTS ENVIRONMENT IS NOT SET !!!!';
  echo "Expected a regex string similar to ^.*\.example\.com$"
fi

if [[ "$CI_COMMIT_REF_NAME" == "$DEPLOYMENT_BRANCH" ]]; then
  export RELEASE="${CI_ENVIRONMENT_SLUG}"
  export TAG=${CI_COMMIT_REF_SLUG}
else
  if [[ -n "$CI_ENVIRONMENT_SLUG" ]] && [[ -z "$RELEASE" ]]; then
    export RELEASE="${CI_ENVIRONMENT_SLUG}"
  fi
  if [[ -z "$RELEASE" ]]; then echo 'Helm RELEASE environment variable is not defined in your ci environment variables for non-production helm releases.'; fi
  export TAG=${CI_COMMIT_REF_SLUG:-dev}
  echo "CONTAINER TAG: '${TAG}'"
fi

# To enable blackfire, set the environment variables
if [[ -n "$BLACKFIRE_SERVER_ID" ]] && [[ -n "$BLACKFIRE_SERVER_TOKEN" ]] ; then
  export BLACKFIRE_SERVER_ENABLED=true
fi

# hBipH0zBIp98alQOCfB4IecnWudKxFbw
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
	wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk"
	apk add "glibc-${GLIBC_VERSION}.apk"
	rm "glibc-${GLIBC_VERSION}.apk"

  echo "Intalling helm..."
  curl "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar zx
  mv linux-amd64/helm /usr/bin/

  helm version

  echo "Intalling kubectl..."
  curl -L -o /usr/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"
  chmod +x /usr/bin/kubectl
  kubectl version --client

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
  if [[ -z ${MERCURE_JWT_SECRET_KEY} ]]; then
  	echo "Generating MERCURE_JWT_SECRET_KEY..."
    export MERCURE_JWT_SECRET_KEY="$(rand_str)"
  fi

	if [[ -z ${MERCURE_SUBSCRIBER_JWT_KEY} ]]; then
  	echo "!! Generating MERCURE_SUBSCRIBER_JWT_KEY !! (IF YOU ARE RESTRICTING SUBSCRIBERS YOU SHOULD HAVE SET THIS PUBLIC KEY ALREADY)"
    JWT_SECRET_KEY_FILE=/tmp/jwt_secret.key
		ssh-keygen -q -t rsa -b 4096 -m PEM -f ${JWT_SECRET_KEY_FILE} -P "${MERCURE_JWT_SECRET_KEY}"
		openssl rsa -in ${JWT_SECRET_KEY_FILE} -pubout -outform PEM -out ${JWT_SECRET_KEY_FILE}.pub -passin pass:"${MERCURE_JWT_SECRET_KEY}"
		export MERCURE_SUBSCRIBER_JWT_KEY=$(cat ${JWT_SECRET_KEY_FILE}.pub)
    export MERCURE_SUBSCRIBER_JWT_ALG=RS256
    rm -f ${JWT_SECRET_KEY_FILE}
    rm -f ${JWT_SECRET_KEY_FILE}.pub
	fi

  # If the secret key is defined and and token is not we will generate a token with the key
	if [[ -z ${MERCURE_PUBLISHER_JWT_KEY} ]]; then
  	echo "Generating MERCURE_PUBLISHER_JWT_KEY..."
		JWT_SECRET_KEY_FILE=/tmp/jwt_secret.key
		ssh-keygen -q -t rsa -b 4096 -m PEM -f ${JWT_SECRET_KEY_FILE} -P "${MERCURE_JWT_SECRET_KEY}"
		openssl rsa -in ${JWT_SECRET_KEY_FILE} -pubout -outform PEM -out ${JWT_SECRET_KEY_FILE}.pub -passin pass:"${MERCURE_JWT_SECRET_KEY}"
		export MERCURE_PUBLISHER_JWT_KEY=$(cat ${JWT_SECRET_KEY_FILE}.pub)
    export MERCURE_PUBLISHER_JWT_ALG=RS256

    echo "Generate MERCURE_JWT_SECRET_TOKEN..."
		npm install --global "@clarketm/jwt-cli"
		MERCURE_PUBLISHER_SECRET_KEY=$(cat ${JWT_SECRET_KEY_FILE})
		export MERCURE_JWT_SECRET_TOKEN=$(jwt sign --noCopy --expiresIn '100 years' --algorithm 'RS256' --passphrase "$MERCURE_JWT_SECRET_KEY"  -- '{"mercure": {"publish": ["*"]}}' "$MERCURE_PUBLISHER_SECRET_KEY")

    rm -f ${JWT_SECRET_KEY_FILE}
    rm -f ${JWT_SECRET_KEY_FILE}.pub
  fi

  if [[ -z ${MERCURE_JWT_SECRET_TOKEN} ]]; then
  	echo "!!! MERCURE_JWT_SECRET_TOKEN DOES NOT EXIST AND WAS NOT CREATED BECAUSE THE MERCURE_PUBLISHER_JWT_KEY ALREADY EXISTS !!!"
  	false
	fi
}

# For Kubernetes environment gitlab runner use the localhost for DIND - see https://docs.gitlab.com/runner/executors/kubernetes.html#using-dockerdind
# Using shared runners for now.
setup_docker() {
  if ! docker info &>/dev/null; then
    if [[ -z "$DOCKER_HOST" && "$KUBERNETES_PORT" ]]; then
      export DOCKER_HOST='tcp://localhost:2375'
    fi
  fi
}

build() {
  # https://gitlab.com/help/ci/variables/predefined_variables.md
  if [[ -n "$CI_REGISTRY_USER" ]]; then
    echo "Logging to GitLab Container Registry with CI credentials..."
    docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    echo ""
  fi

  docker pull $PHP_REPOSITORY:$TAG || true
  docker build \
  	--cache-from $PHP_REPOSITORY:$TAG \
  	--tag $PHP_REPOSITORY:$TAG \
  	--target cwa_php \
  	"api"

  docker pull $CADDY_REPOSITORY:$TAG || true
  docker build \
  	--cache-from $PHP_REPOSITORY:$TAG \
  	--cache-from $CADDY_REPOSITORY:$TAG \
  	--tag $CADDY_REPOSITORY:$TAG \
  	--target cwa_caddy \
  	"api"

  docker pull $VARNISH_REPOSITORY:$TAG || true
  docker build \
  	--cache-from $PHP_REPOSITORY:$TAG \
  	--cache-from $VARNISH_REPOSITORY:$TAG \
  	--tag $VARNISH_REPOSITORY:$TAG \
  	--target cwa_varnish \
  	"api"

  docker push $PHP_REPOSITORY:$TAG
  docker push $CADDY_REPOSITORY:$TAG
  docker push $VARNISH_REPOSITORY:$TAG
}

function setup_test_db() {
  if [[ -z ${KUBERNETES_PORT+x} ]]; then
    DB_HOST=postgres
  else
    DB_HOST=localhost
  fi
  export DATABASE_URL="pgsql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:5432/${POSTGRES_DB}"
}

function run_phpunit() {
  echo "run_phpunit function"
  cd ./api || return
  mkdir -p build/logs/phpunit/
  composer install -o --prefer-dist --no-scripts --ignore-platform-reqs
  vendor/bin/simple-phpunit tests/Unit --log-junit build/logs/phpunit/junit.xml
}

function run_behat() {
  echo "run_behat function"
  cd ./api || return
  mkdir -p build/logs/behat/
  composer install -o --prefer-dist --no-scripts --ignore-platform-reqs
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
  helm dependency update api/_helm/api
  helm dependency build api/_helm/api
}

apply_kube_context() {
	kubectl config get-contexts
  if [ -n "$KUBE_CONTEXT" ]; then kubectl config use-context "$KUBE_CONTEXT"; fi
}

ensure_namespace() {
	if [[ -z "$KUBE_NAMESPACE" ]]; then
    export KUBE_NAMESPACE="$CI_PROJECT_NAME-$CI_ENVIRONMENT_SLUG"
  fi
	echo "Ensuring namespace: $KUBE_NAMESPACE"
  kubectl describe namespace "$KUBE_NAMESPACE" || kubectl create namespace "$KUBE_NAMESPACE"
}

create_secret() {
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

function get_replicas() {
	track="${1:-stable}"
	percentage="${2:-100}"

	env_track=$( echo $track | tr -s  '[:lower:]'  '[:upper:]' )
	env_slug=$( echo ${CI_ENVIRONMENT_SLUG//-/_} | tr -s  '[:lower:]'  '[:upper:]' )

	if [[ "$track" == "stable" ]] || [[ "$track" == "rollout" ]]; then
		# for stable track get number of replicas from `PRODUCTION_REPLICAS`
		eval new_replicas=\$${env_slug}_REPLICAS
		if [[ -z "$new_replicas" ]]; then
			new_replicas=$REPLICAS
		fi
	else
		# for all tracks get number of replicas from `CANARY_PRODUCTION_REPLICAS`
		eval new_replicas=\$${env_track}_${env_slug}_REPLICAS
		if [[ -z "$new_replicas" ]]; then
			eval new_replicas=\$env_track_REPLICAS
		fi
	fi

	replicas="${new_replicas:-1}"
	replicas="$(($replicas * $percentage / 100))"

	# always return at least one replica
	if [[ $replicas -gt 0 ]]; then
		echo "$replicas"
	else
		echo 1
	fi
}

deploy_vercel_pwa() {
	if [[ -z "$VERCEL_ORG_ID" ]]; then
	  echo 'You must define $VERCEL_ORG_ID to deploy to Vercel'
		false
	fi
	if [[ -z "$VERCEL_PROJECT_ID" ]]; then
		echo 'You must define $VERCEL_PROJECT_ID to deploy to Vercel'
		false
	fi
	if [[ -z "$VERCEL_TOKEN" ]]; then
		echo 'You must define $VERCEL_TOKEN to deploy to Vercel'
		false
	fi

	echo "Adding nodejs npm ..."
  # upgrade for curl fix https://github.com/curl/curl/issues/4357
  apk add --update-cache --upgrade --no-cache -U openssl nodejs npm
	echo "Installing Vercel CLI ..."
	npm i -g vercel

  echo "Setting up Vercel environment ..."
  track="${1-stable}"
	SCOPE=""
	NODE_ENV="production"
	MERCURE_SUBSCRIBE_URL="https://${MERCURE_SUBSCRIBE_DOMAIN}/.well-known/mercure"
	if [[ -n "$VERCEL_SCOPE" ]]; then
		SCOPE="--scope $VERCEL_SCOPE"
	fi
	if [[ "$track" == "stable" ]]; then
		PROD_FLAG="--prod"
  else
    PROD_FLAG="--target=staging"
	fi
	API_ENDPOINT="https://${DOMAIN}"

	echo "Deploying Vercel with API ${API_ENDPOINT} and Mercure subscriber URL ${MERCURE_SUBSCRIBE_URL} ..."
	VERCEL_ORG_ID="$VERCEL_ORG_ID"
	VERCEL_PROJECT_ID="$VERCEL_PROJECT_ID"
	vercel --no-clipboard \
	  ${PROD_FLAG} ${SCOPE} \
	  --token="$VERCEL_TOKEN" \
		-A ./${VERCEL_CONFIG_PATH:-"vercel.json"} \
		-e API_URL="${API_ENDPOINT}" \
		-e API_URL_BROWSER="${API_ENDPOINT}" \
		-e NODE_ENV="${NODE_ENV}" \
		-b API_URL="${API_ENDPOINT}" \
		-b API_URL_BROWSER="${API_ENDPOINT}" \
		-b NODE_ENV="${NODE_ENV}" \
		-b MERCURE_SUBSCRIBE_URL="${MERCURE_SUBSCRIBE_URL}"

# if [[ "$track" == "stable" ]]; then
#		echo "Removing old deployments with --safe flag ..."
#		vercel remove --safe --yes --token="$VERCEL_TOKEN"
#	fi
}

deploy_api() {
	track="${1-stable}"
	percentage="${2:-100}"
	name="$RELEASE"
	if [[ "$track" == "canary" ]]; then
		export BLACKFIRE_SERVER_ENABLED=false
	fi
	echo "Installing/upgrading release '${name}' on namespace '${KUBE_NAMESPACE}' and host '${DOMAIN}' (${CI_ENVIRONMENT_URL})"

	replicas=$(get_replicas "$track" "$percentage")

  if [[ -n "$HELM_UNINSTALL" ]]; then
    helm uninstall --namespace="$KUBE_NAMESPACE" "$name" || EXIT_CODE=$? && true
    echo ${EXIT_CODE}
  fi

  cat >values.tmp.yaml <<EOF
imagePullSecrets:
  - name: ${GITLAB_PULL_SECRET_NAME:-"~"}
php:
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
  blackfire:
    id: "${BLACKFIRE_CLIENT_ID}"
    token: "${BLACKFIRE_CLIENT_TOKEN}"
postgresql:
  url: ${DATABASE_URL:-"~"}
mercure:
  url: https://${MERCURE_SUBSCRIBE_DOMAIN}/.well-known/mercure
  publicUrl: https://${MERCURE_SUBSCRIBE_DOMAIN}/.well-known/mercure
  jwtKey:
    subscriber:
      algorithm: ${MERCURE_SUBSCRIBER_JWT_ALG:-"HS256"}
    publisher:
      algorithm: ${MERCURE_PUBLISHER_JWT_ALG:-"HS256"}
caddy:
  image:
    repository: ${CADDY_REPOSITORY}
    tag: ${TAG}
    pullPolicy: Always
varnish:
  image:
    repository: ${VARNISH_REPOSITORY}
    tag: ${TAG}
    pullPolicy: Always
ingress:
  enabled: ${INGRESS_ENABLED:-"false"}
  annotations:
    "kubernetes.io/ingress.class": nginx
    "cert-manager.io/cluster-issuer": ${CLUSTER_ISSUER:-"~"}
  hosts:
    - host: ${DOMAIN:-"~"}
      paths: [ "/" ]
  tls:
    - secretName: ${LETSENCRYPT_SECRET_NAME}-api
      hosts:
        - ${DOMAIN:-"~"}
blackfire:
  enabled: ${BLACKFIRE_SERVER_ENABLED:-false}
  server:
    id: "${BLACKFIRE_SERVER_ID}"
    token: "${BLACKFIRE_SERVER_TOKEN}"
annotations:
  app.gitlab.com/app: "${CI_PROJECT_PATH_SLUG}"
  app.gitlab.com/env: "${CI_ENVIRONMENT_SLUG}"
EOF

  helm upgrade --install \
    --reset-values \
    --namespace="$KUBE_NAMESPACE" \
    "$name" ./api/_helm/api \
    --set php.jwt.secret="${JWT_SECRET_KEY}" \
    --set php.jwt.public="${JWT_PUBLIC_KEY}" \
    --set mercure.jwtKey.subscriber.key="${MERCURE_SUBSCRIBER_JWT_KEY}" \
    --set mercure.jwtKey.publisher.key="${MERCURE_PUBLISHER_JWT_KEY}" \
    --set mercure.jwtSecret="${MERCURE_JWT_SECRET_TOKEN}" \
  	-f values.tmp.yaml
}

persist_environment_url() {
	echo $CI_ENVIRONMENT_URL > environment_url.txt
}

performance() {
  export CI_ENVIRONMENT_URL=$(cat environment_url.txt)

  mkdir gitlab-exporter
  wget -O gitlab-exporter/index.js https://gitlab.com/gitlab-org/gl-performance/raw/10-5/index.js

  mkdir sitespeed-results

  if [[ -f .gitlab-urls.txt ]]; then
    sed -i -e 's@^@'"$CI_ENVIRONMENT_URL"'@' .gitlab-urls.txt
    docker run --shm-size=1g --rm -v "$(pwd)":/sitespeed.io sitespeedio/sitespeed.io:6.3.1 --plugins.add ./gitlab-exporter --outputFolder sitespeed-results .gitlab-urls.txt
  else
    docker run --shm-size=1g --rm -v "$(pwd)":/sitespeed.io sitespeedio/sitespeed.io:6.3.1 --plugins.add ./gitlab-exporter --outputFolder sitespeed-results "$CI_ENVIRONMENT_URL"
  fi

  mv sitespeed-results/data/performance.json performance.json
}

function delete() {
	track="${1-stable}"
	name="$RELEASE"

	if [[ "$track" != "stable" ]]; then
		name="$name-$track"
	fi

	helm uninstall "$name" || EXIT_CODE=$? && true
  echo ${EXIT_CODE}

  # It appears the default service account does not have permissions for this.
	if [[ ${CI_ENVIRONMENT_SLUG:0:6} == "review" ]]; then
	  echo "Deleting namespace $KUBE_NAMESPACE"
		kubectl delete namespace $KUBE_NAMESPACE --grace-period=0
	else
	  echo "Skipping namespace delete for slug $CI_ENVIRONMENT_SLUG and namespace $KUBE_NAMESPACE"
	fi
}
