#!/usr/bin/env bash

deploy_vercel_app() {
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
  # --upgrade for curl fix https://github.com/curl/curl/issues/4357
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
	VERCEL_DEPLOYED_URL=$(vercel app ${PROD_FLAG} ${SCOPE} \
	  --token="$VERCEL_TOKEN" \
		-e NUXT_PUBLIC_CWA_API_URL="${API_ENDPOINT}" \
		-e NUXT_PUBLIC_CWA_API_URL_BROWSER="${API_ENDPOINT}" \
		-e NODE_ENV="${NODE_ENV}" \
    -e MERCURE_SUBSCRIBE_URL="${MERCURE_SUBSCRIBE_URL}" \
		-b NODE_ENV="${NODE_ENV}" \
		-b MERCURE_SUBSCRIBE_URL="${MERCURE_SUBSCRIBE_URL}")

  if [ "$track" != "stable" ] && [ -n "$VERCEL_PREVIEW_ALIAS" ]; then
	  echo "Setting up alias for '${VERCEL_DEPLOYED_URL}' to custom preview domain '${VERCEL_PREVIEW_ALIAS}'"
	  vercel alias --token="$VERCEL_TOKEN" ${SCOPE} set "${VERCEL_DEPLOYED_URL}" "${VERCEL_PREVIEW_ALIAS}"
  fi
}
