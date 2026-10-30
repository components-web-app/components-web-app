#!/bin/sh
set -e

# compose.prod.yaml's host settings from SITE_HOST and SITE_ALIASES (#207); unset everywhere else.
. "$(dirname "$0")/site-hosts.sh"
cwa_site_host_defaults

if [ "$1" = 'frankenphp' ] || [ "$1" = 'php' ] || [ "$1" = 'bin/console' ]; then
	if [ -z "$(ls -A 'vendor/' 2>/dev/null)" ]; then
	  if [[ -n "$GITHUB_TOKEN" ]]; then
      composer config -g github-oauth.github.com "$GITHUB_TOKEN"
    else
		  # if invalid GITHUB_TOKEN characters this will need to be run to clear it
      rm -rf /config/composer/auth.json
    fi
		# Three tries, 10 s apart: one refused connection to GitHub left vendor/ empty and php unhealthy (#226).
		for attempt in 1 2 3; do
			composer install --prefer-dist --no-progress --no-interaction && break
			[ "$attempt" = 3 ] && exit 1
			echo "composer install failed (attempt $attempt of 3); retrying in 10 s" >&2
			sleep 10
		done
	fi

	# Dev keys only: production passes the keys as env, and the prod image carries no key files.
	if [ "$APP_ENV" != 'prod' ]; then
		php bin/console lexik:jwt:generate-keypair --skip-if-exists
	fi

  mkdir -p var/database
	echo "$DATABASE_CA_CERT" > var/database/server-ca.pem
	echo "$DATABASE_CLIENT_CERT" > var/database/client-cert.pem
	echo "$DATABASE_CLIENT_KEY" > var/database/client-key.pem

	setfacl -R -m u:www-data:rwX -m u:"$(whoami)":rwX var || true
  setfacl -dR -m u:www-data:rwX -m u:"$(whoami)":rwX var || true

  chown -R www-data var/database/*
	chmod -R 0600 var/database/*

	if grep -q ^DATABASE_URL= .env; then
		echo "Waiting for database to be ready..."
		ATTEMPTS_LEFT_TO_REACH_DATABASE=30
		until [ $ATTEMPTS_LEFT_TO_REACH_DATABASE -eq 0 ] || DATABASE_ERROR=$(bin/console dbal:run-sql "SELECT 1" 2>&1); do
			if [ $? -eq 255 ]; then
				# If the Doctrine command exits with 255, an unrecoverable error occurred
				ATTEMPTS_LEFT_TO_REACH_DATABASE=0
				break
			fi
			sleep 1
			ATTEMPTS_LEFT_TO_REACH_DATABASE=$((ATTEMPTS_LEFT_TO_REACH_DATABASE - 1))
			echo "Still waiting for database to be ready... Or maybe the database is not reachable. $ATTEMPTS_LEFT_TO_REACH_DATABASE attempts left."
		done

		if [ $ATTEMPTS_LEFT_TO_REACH_DATABASE -eq 0 ]; then
			echo "!* The database is not up or not reachable:"
			echo "!* $DATABASE_ERROR"
			exit 1
		else
			echo "* The database is now ready and reachable"
		fi

		if [ "${SKIP_MIGRATIONS:-false}" = "true" ]; then
			# The deploy's database Jobs (#180): a plan or backup must never change the schema.
			echo "* SKIP_MIGRATIONS=true: not migrating"
		else
			if [ "${RESET_DATABASE:-false}" = "true" ]; then
				echo "* RESET_DATABASE=true: dropping schema before migrations..."
				php bin/console doctrine:schema:drop --force --full-database
			fi

			# Migrations and ANALYZE under a database lock, so pods and CronJobs starting together run them once (#85).
			php bin/console app:database:migrate --no-interaction
		fi
	fi

	echo "* READY"
fi

exec docker-php-entrypoint "$@"
