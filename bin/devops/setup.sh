#!/usr/bin/env bash

# echo the commands that are run
[[ "$TRACE" ]] && set -x

export CI_APPLICATION_REPOSITORY=$CI_REGISTRY_IMAGE/$CI_COMMIT_REF_SLUG
export CI_APPLICATION_TAG=$CI_COMMIT_SHA

export GITLAB_PULL_SECRET_NAME=gitlab-registry
export KUBERNETES_VERSION=1.31.0
export HELM_VERSION=3.16.1

# Choose the branch for production deploy.
if [[ -z "$DEPLOYMENT_BRANCH" ]]; then
  export DEPLOYMENT_BRANCH=main
fi

if [[ -z "$CLUSTER_ISSUER" ]]; then
  export CLUSTER_ISSUER="letsencrypt-staging"
fi
if [[ -z "$LETSENCRYPT_SECRET_NAME" ]]; then
  export LETSENCRYPT_SECRET_NAME="letsencrypt-cert"
fi
if [[ -z "$CI_ENVIRONMENT_URL" ]]; then
  export CI_ENVIRONMENT_URL="test-domain.com"
fi

export DOMAIN=$(basename ${CI_ENVIRONMENT_URL})
export DOCKER_REPOSITORY=${CI_REGISTRY_IMAGE}
export PHP_REPOSITORY="${DOCKER_REPOSITORY}/php"
export APP_REPOSITORY="${DOCKER_REPOSITORY}/app"
export VARNISH_REPOSITORY="${DOCKER_REPOSITORY}/varnish"
export MERCURE_SUBSCRIBE_DOMAIN="${DOMAIN/php.}"

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

export MERCURE_SUBSCRIBER_JWT_ALG=HS256
export MERCURE_PUBLISHER_JWT_ALG=HS256
