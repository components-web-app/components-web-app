#!/usr/bin/env bash

# echo the commands that are run
[[ "$TRACE" ]] && set -x

export CI_APPLICATION_REPOSITORY=$CI_REGISTRY_IMAGE/$CI_COMMIT_REF_SLUG
export CI_APPLICATION_TAG=$CI_COMMIT_SHA

export GITLAB_PULL_SECRET_NAME=gitlab-registry
export KUBERNETES_VERSION=1.18.2
export HELM_VERSION=3.2.1

# Choose the branch for production deploy.
if [ -z "$DEPLOYMENT_BRANCH" ]; then
  export DEPLOYMENT_BRANCH=master
fi

# Configure your sub-domains for: api
if [ -z "$API_SUBDOMAIN" ]; then
  export API_SUBDOMAIN=api
fi

# Miscellaneous
if [ -z "$LETSENCRYPT_SECRET" ]; then
  export LETSENCRYPT_SECRET="letsencrypt-prod"
fi
if [ -z "$CORS_ALLOW_ORIGIN" ]; then
  export CORS_ALLOW_ORIGIN="^https?:\/\/(.*\.)?example\.com"
fi
if [ -z "$TRUSTED_HOSTS" ]; then
  export TRUSTED_HOSTS="^.*\.example\.com$"
fi

export DOMAIN=${KUBE_INGRESS_BASE_DOMAIN}
export DOCKER_REPOSITORY=${CI_REGISTRY_IMAGE}
export PHP_REPOSITORY="${DOCKER_REPOSITORY}/php"
export NGINX_REPOSITORY="${DOCKER_REPOSITORY}/nginx"
export VARNISH_REPOSITORY="${DOCKER_REPOSITORY}/varnish"

if [[ "$CI_COMMIT_REF_NAME" == "$DEPLOYMENT_BRANCH" ]]; then
  export RELEASE="${CI_ENVIRONMENT_SLUG}"
  export TAG=latest
  export API_ENTRYPOINT="${API_SUBDOMAIN}.${DOMAIN}"
  export MERCURE_SUBSCRIBE_URL="https://mercure.${DOMAIN}/.well-known/mercure"
else
  if [ -n "$CI_ENVIRONMENT_SLUG" ] && [ -z "$RELEASE" ]; then
    export RELEASE="${CI_ENVIRONMENT_SLUG}"
  fi
  if [[ -z "$RELEASE" ]]; then echo 'RELEASE is not defined in your ci environment variables for non-production releases.'; fi
  export TAG=$RELEASE
  export API_ENTRYPOINT="${RELEASE}.${API_SUBDOMAIN}.${DOMAIN}"
  export MERCURE_SUBSCRIBE_URL="https://${RELEASE}.mercure.${DOMAIN}/.well-known/mercure"
fi

# To enable blackfire, set the environment variables
if [ -n "$BLACKFIRE_SERVER_ID" ] && [ -n "$BLACKFIRE_SERVER_TOKEN" ] && [ -n "$BLACKFIRE_CLIENT_ID" ] && [ -n "$BLACKFIRE_CLIENT_TOKEN" ] ; then
  export BLACKFIRE_ENABLED=true
fi

rand_str() {
  len=32
  head -c 256 /dev/urandom > /tmp/urandom.out
  tr -dc 'a-zA-Z0-9' < /tmp/urandom.out > /tmp/urandom.tr
  head -c ${len} /tmp/urandom.tr
}

install_dependencies() {
  echo "Adding openssl curl tar gzip ca-certificates git nodejs nodejs-npm"
  # upgrade for curl fix https://github.com/curl/curl/issues/4357
  apk add --update-cache --upgrade --no-cache -U openssl curl tar gzip ca-certificates git nodejs nodejs-npm

  wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
  wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk
  apk add glibc-2.28-r0.apk
  rm glibc-2.28-r0.apk

  echo "Intalling helm..."
  curl "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar zx
  mv linux-amd64/helm /usr/bin/

  helm version --client

  echo "Intalling kubectl..."
  curl -L -o /usr/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"
  chmod +x /usr/bin/kubectl
  kubectl version --client

  # Generate random passphrase and keys for JWT signing if not set
	if [ -z "$JWT_PASSPHRASE" ]; then
		JWT_PASSPHRASE="$(rand_str)"
		export JWT_PASSPHRASE
	fi

	if [ -z "$JWT_SECRET_KEY" ]; then
		JWT_SECRET_KEY_FILE=/tmp/jwt_secret

		openssl genpkey -pass pass:"${JWT_PASSPHRASE}" -aes256 -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out $JWT_SECRET_KEY_FILE
		JWT_SECRET_KEY=$(cat $JWT_SECRET_KEY_FILE)
		export JWT_SECRET_KEY

		JWT_PUBLIC_KEY=$(openssl pkey -in "$JWT_SECRET_KEY_FILE" -passin pass:"$JWT_PASSPHRASE" -pubout)
		export JWT_PUBLIC_KEY

		rm $JWT_SECRET_KEY_FILE
	fi
}

# For Kubernetes environment gitlab runner use the localhost for DIND - see https://docs.gitlab.com/runner/executors/kubernetes.html#using-dockerdind
# Using shared runners for now.
setup_docker() {
  if ! docker info &>/dev/null; then
    if [ -z "$DOCKER_HOST" -a "$KUBERNETES_PORT" ]; then
      export DOCKER_HOST='tcp://localhost:2375'
    fi
  fi
}

build() {
  # https://gitlab.com/help/ci/variables/predefined_variables.md
  if [ -n "$CI_REGISTRY_USER" ]; then
    echo "Logging to GitLab Container Registry with CI credentials..."
    docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    echo ""
  fi

  docker pull $VARNISH_REPOSITORY:$TAG || true
  docker build --cache-from $VARNISH_REPOSITORY:$TAG --tag $VARNISH_REPOSITORY:$TAG --target cwa_varnish api

  docker pull $PHP_REPOSITORY:$TAG || true
  docker build --cache-from $PHP_REPOSITORY:$TAG --tag $PHP_REPOSITORY:$TAG --target cwa_php api

  docker pull $NGINX_REPOSITORY:$TAG || true
  docker build --cache-from $NGINX_REPOSITORY:$TAG --tag $NGINX_REPOSITORY:$TAG --target cwa_nginx api

  docker push $VARNISH_REPOSITORY:$TAG
  docker push $PHP_REPOSITORY:$TAG
  docker push $NGINX_REPOSITORY:$TAG
}

function setup_test_db() {
  if [ -z ${KUBERNETES_PORT+x} ]; then
    DB_HOST=postgres
  else
    DB_HOST=localhost
  fi
  export DATABASE_URL="pgsql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:5432/${POSTGRES_DB}"
}

run_tests() {
	echo "run_tests function disabled - needs refactoring/checking"

  if [ -n "$CI_REGISTRY_USER" ]; then
    echo "Logging to GitLab Container Registry with CI credentials..."
    docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    echo ""
  fi

#  docker pull $PHP_REPOSITORY:$TAG
#
#  docker run --env DATABASE_URL --env APP_ENV=test --name php $PHP_REPOSITORY
#
#  docker cp api/behat.yml php:srv/api/behat.yml
#  docker cp api/features php:srv/api/features
#
#  docker exec php sh -c "vendor/bin/behat --format=progress --out=std --format=junit --out=build/logs/behat/junit --profile=default --no-interaction --colors --tags='~@wip'"
#
#  docker rm -f php

#  Need to run PHPUnit tests too
}

check_kube_domain() {
  if [ -z ${KUBE_INGRESS_BASE_DOMAIN+x} ]; then
    echo "In order to deploy or use Review Apps, KUBE_INGRESS_BASE_DOMAIN variable must be set"
    echo "You can do it in Auto DevOps project settings or defining a variable at group or project level"
    echo "You can also manually add it in .gitlab-ci.yml"
    false
  else
    true
  fi
}

helm_init() {
  rm -rf ~/.helm/repository/cache/*
  # helm init --client-only --skip-refresh
  helm repo add default https://kubernetes-charts.storage.googleapis.com
  # helm repo add incubator https://storage.googleapis.com/kubernetes-charts-incubator
  helm repo add blackfire https://tech.sparkfabrik.com/blackfire-chart/
  helm dependency update api/_helm/api
  helm dependency build api/_helm/api
}

ensure_namespace() {
  kubectl describe namespace "$KUBE_NAMESPACE" || kubectl create namespace "$KUBE_NAMESPACE"
}

create_secret() {
  if [ "$CI_PROJECT_VISIBILITY" = "public" ]; then
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

deploy_api() {
  echo "Installing/upgrading release '${RELEASE}' on namespace '${KUBE_NAMESPACE}'"

#	track="${1-stable}"
#	percentage="${2:-100}"
#	name="$CI_ENVIRONMENT_SLUG"
#
#	replicas="1"
#	service_enabled="true"
#	database_enabled="$DATABASE_ENABLED"
#	indexation_enabled="false"
#
#	# if track is different than stable,
#	# re-use all attached resources
#	if [[ "$track" != "stable" ]]; then
#		name="$name-$track"
#		service_enabled="false"
#		database_enabled="false"
#	fi
#
#	replicas=$(get_replicas "$track" "$percentage")
#
#	if [[ "$CI_PROJECT_VISIBILITY" != "public" ]]; then
#		secret_name='gitlab-registry'
#	else
#		secret_name=''
#	fi
#	# helm delete --purge $name
#	kubectl delete job indexation-job --ignore-not-found
#	kubectl delete job ${name}-db-indexation --ignore-not-found
#	kubectl delete job ${name}-db-migrate-job --ignore-not-found
#	if [[ "$APP_ENV" != "prod" ]]; then
#		PHP_APPLICATION_REPOSITORY=$CI_APPLICATION_REPOSITORY
#		NGINX_APPLICATION_REPOSITORY="$CI_APPLICATION_REPOSITORY/nginx"
#	else
#		PHP_APPLICATION_REPOSITORY="$CI_APPLICATION_REPOSITORY/prod"
#		NGINX_APPLICATION_REPOSITORY="$CI_APPLICATION_REPOSITORY/nginx-prod"
#	fi

  if [[ -n "$HELM_DELETE" ]]; then
    helm delete --purge "$RELEASE" || EXIT_CODE=$? && true
    echo ${EXIT_CODE}
  fi

  helm upgrade --install --reset-values --force --namespace="$KUBE_NAMESPACE" "$RELEASE" ./api/_helm/api \
    --set imagePullSecrets[0].name="${GITLAB_PULL_SECRET_NAME}" \
    --set php.corsAllowOrigin="${CORS_ALLOW_ORIGIN}" \
    --set php.trustedHosts="${TRUSTED_HOSTS}" \
    --set php.repository="${PHP_REPOSITORY}" \
    --set php.mercure.jwtToken="${____TODO____}" \
    --set php.databaseUrl="${DATABASE_URL}" \
    --set nginx.repository="${NGINX_REPOSITORY}" \
    --set varnish.repository="${VARNISH_REPOSITORY}" \
    --set ingress.enabled="${INGRESS_ENABLED}" \
    --set ingress.host="${API_ENTRYPOINT}" \
    --set ingress.secretName="${LETSENCRYPT_SECRET}" \
    --set mercure.subscribeUrl="${MERCURE_SUBSCRIBE_URL}" \
    --set blackfire.enabled="${BLACKFIRE_ENABLED}" \
    --set blackfire.server.id="${BLACKFIRE_SERVER_ID}" \
    --set blackfire.server.token="${BLACKFIRE_SERVER_TOKEN}" \
    --set blackfire.client.id="${BLACKFIRE_CLIENT_ID}" \
    --set blackfire.client.token="${BLACKFIRE_CLIENT_TOKEN}" \
    --set labels."app\.gitlab\.com/app"="${CI_PROJECT_PATH_SLUG}" \
    --set labels."app\.gitlab\.com/env"="${CI_ENVIRONMENT_SLUG}"
#   ^^ COULD NOT WORK OUT HOW TO APPLY LABELS INTO THE LABELS HELPER - THIS WILL LINK DEPLOYMENT STATUS WITH GITLAB UI
}

persist_environment_url() {
	echo $CI_ENVIRONMENT_URL > environment_url.txt
}

performance() {
	echo "performance function disabled - needs refactoring/checking"
  export CI_ENVIRONMENT_URL=$(cat environment_url.txt)

  mkdir gitlab-exporter
  wget -O gitlab-exporter/index.js https://gitlab.com/gitlab-org/gl-performance/raw/10-5/index.js

  mkdir sitespeed-results

  if [ -f .gitlab-urls.txt ]
  then
    sed -i -e 's@^@'"$CI_ENVIRONMENT_URL"'@' .gitlab-urls.txt
    docker run --shm-size=1g --rm -v "$(pwd)":/sitespeed.io sitespeedio/sitespeed.io:6.3.1 --plugins.add ./gitlab-exporter --outputFolder sitespeed-results .gitlab-urls.txt
  else
    docker run --shm-size=1g --rm -v "$(pwd)":/sitespeed.io sitespeedio/sitespeed.io:6.3.1 --plugins.add ./gitlab-exporter --outputFolder sitespeed-results "$CI_ENVIRONMENT_URL"
  fi

  mv sitespeed-results/data/performance.json performance.json
}

clean() {
	echo "Needs re-working and checking..."
#  # Get kubernetes namespaces
#  NAMESPACES=$(kubectl get namespaces -l project=$PROJECT_NAME --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
#	echo "namespaces: $NAMESPACES"
#  # Get git repository branches
#  BRANCHES=$(git ls-remote --heads origin | awk -F '	' '{print $2}' | sed -E 's#^refs/heads/(.*)#\1#g' | sed -E "s/\//-/g" | sed -e 's/\(.*\)/\L\1/')
#	echo "branches: $BRANCHES"
#  # Calculate differences between those 2 arrays
#  DIFF=$(comm -3 <(echo "${NAMESPACES[*]}") <(echo "${BRANCHES[*]}"))
#	echo "diff: $DIFF"
#  # Only get existing namespaces
#  NAMESPACES_TO_DELETE=($(comm -12 <(for X in "${DIFF[@]}"; do echo "${X}"; done|sort)  <(for X in "${NAMESPACES[@]}"; do echo "${X}"; done|sort)))
#	echo "namespaces to delete: $NAMESPACES_TO_DELETE"
#  # Remove useless kubernetes namespaces
#  for i in "${NAMESPACES_TO_DELETE[@]}"; do
#      if [[ $DEPLOYMENT_BRANCH != $i ]]
#      then
#          echo "Remove namespace/release $i"
#          helm delete --purge $i || echo "Release $i does not exist"
#          kubectl delete namespace $i --wait --cascade || echo "Namespace $i does not exist"
#      fi
#  done
}

function delete() {
	track="${1-stable}"
	name="$CI_ENVIRONMENT_SLUG"

	if [[ "$track" != "stable" ]]; then
		name="$name-$track"
	fi

	if [[ -n "$(helm ls -q "^$name$")" ]]; then
		helm delete --purge "$name"
	fi
}
