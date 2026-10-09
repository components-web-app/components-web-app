#!/usr/bin/env bash

# echo the commands that are run
[[ "$CWA_CI_TRACE" ]] && set -x

export CI_APPLICATION_REPOSITORY=$CI_REGISTRY_IMAGE/$CI_COMMIT_REF_SLUG
export CI_APPLICATION_TAG=$CI_COMMIT_SHA

export GITLAB_PULL_SECRET_NAME=gitlab-registry
export KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.31.0}"
export HELM_VERSION="${HELM_VERSION:-3.19.0}"

# Choose the branch for production deploy.
if [[ -z "$CWA_CI_DEPLOYMENT_BRANCH" ]]; then
  export CWA_CI_DEPLOYMENT_BRANCH=main
fi

# Production certificates are opt-in (CWA_CI_CLUSTER_ISSUER=letsencrypt-prod);
# an explicit empty value turns cert-manager off.
if [[ -z "${CWA_CI_CLUSTER_ISSUER+x}" ]]; then
  export CWA_CI_CLUSTER_ISSUER="letsencrypt-staging"
fi
if [[ -z "$CWA_CI_TLS_SECRET_NAME" ]]; then
  export CWA_CI_TLS_SECRET_NAME="letsencrypt-cert"
fi
if [[ -z "$CI_ENVIRONMENT_URL" ]]; then
  export CI_ENVIRONMENT_URL="test-domain.com"
fi

export DOMAIN=$(basename ${CI_ENVIRONMENT_URL})
export DOCKER_REPOSITORY=${CI_REGISTRY_IMAGE}
export PHP_REPOSITORY="${DOCKER_REPOSITORY}/php"
export PHP_REPOSITORY_CACHE="${DOCKER_REPOSITORY}/php-cache"
export APP_REPOSITORY="${DOCKER_REPOSITORY}/app"
export APP_REPOSITORY_CACHE="${DOCKER_REPOSITORY}/app-cache"
export MERCURE_SUBSCRIBE_DOMAIN="${DOMAIN/php.}"
export KUBE_INGRESS_ALIAS_DOMAINS="${KUBE_INGRESS_ALIAS_DOMAINS}"

# CORS_ALLOW_ORIGIN, TRUSTED_HOSTS and MERCURE_CORS_ORIGIN default to this
# deploy's own hostnames (apply_site_defaults in k8s.sh), so they're optional.

if [[ "$CI_COMMIT_REF_NAME" == "$CWA_CI_DEPLOYMENT_BRANCH" ]]; then
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

export MERCURE_SUBSCRIBER_JWT_ALG=HS256
export MERCURE_PUBLISHER_JWT_ALG=HS256

# An optional GITHUB_TOKEN authenticates composer (anonymous is 60 requests an hour per IP).
# Unset stays unset: an empty token is rejected outright, worse than anonymous.
if [[ -n "$GITHUB_TOKEN" ]]; then
  export COMPOSER_AUTH="{\"github-oauth\": {\"github.com\": \"${GITHUB_TOKEN}\"}}"
  echo "COMPOSER_AUTH: configured from GITHUB_TOKEN"
else
  echo "COMPOSER_AUTH: GITHUB_TOKEN is empty, composer will hit github anonymously"
fi
# Composer's default of 12 parallel downloads is enough of a burst to be
# throttled even when authenticated.
export COMPOSER_MAX_PARALLEL_HTTP=6
