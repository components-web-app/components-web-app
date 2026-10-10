#syntax=docker/dockerfile:1

# Adapted from https://github.com/dunglas/symfony-docker

# Versions
FROM dunglas/frankenphp:builder AS builder

# Copy xcaddy in the builder image
COPY --from=caddy:builder /usr/bin/xcaddy /usr/bin/xcaddy

# Patched Souin v1.7.9: purge regex (#84), singleflight (#62, #137), flush (#114), Cloudflare purge (#108, #115).
# Remove each with its replace once a Souin release has it (bin/test/souin-*.sh must pass).
COPY --link frankenphp/souin/v1.7.9-purge-fix.patch /tmp/souin-purge-fix.patch
COPY --link frankenphp/souin/v1.7.9-singleflight-fix.patch /tmp/souin-singleflight-fix.patch
COPY --link frankenphp/souin/v1.7.9-singleflight-5xx.patch /tmp/souin-singleflight-5xx.patch
COPY --link frankenphp/souin/v1.7.9-flush-no-close.patch /tmp/souin-flush-no-close.patch
COPY --link frankenphp/souin/v1.7.9-cloudflare-purge.patch /tmp/souin-cloudflare-purge.patch
RUN SOUIN_DIR=$(go mod download -json github.com/darkweak/souin@v1.7.9 | sed -n 's/.*"Dir": "\(.*\)",/\1/p') && \
	cp -r "$SOUIN_DIR" /tmp/souin && \
	chmod -R u+w /tmp/souin && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-purge-fix.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-singleflight-fix.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-singleflight-5xx.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-flush-no-close.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-cloudflare-purge.patch

# The template's own Caddy handler: keeps only the allowlisted query parameters on
# pages (`query_allowlist` in the Caddyfile, #106).
COPY --link frankenphp/caddy/queryallowlist /tmp/queryallowlist

RUN CGO_ENABLED=1 \
    XCADDY_SETCAP=1 \
    XCADDY_GO_BUILD_FLAGS="-ldflags='-w -s' -tags=nobadger,nomysql,nopgx" \
    CGO_CFLAGS=$(php-config --includes) \
    CGO_LDFLAGS="$(php-config --ldflags) $(php-config --libs)" \
    xcaddy build \
    --output /usr/local/bin/frankenphp \
	--with github.com/dunglas/frankenphp/caddy \
	--with github.com/dunglas/caddy-cbrotli \
	--with github.com/dunglas/mercure/caddy \
	--with github.com/dunglas/vulcain/caddy \
	--with github.com/darkweak/souin/plugins/caddy \
	--with github.com/darkweak/souin=/tmp/souin \
	--with github.com/darkweak/storages/otter/caddy \
	--with github.com/darkweak/storages/badger/caddy \
	--with github.com/darkweak/storages/nuts/caddy \
	# Per-visitor rate limit on cache misses (`rate_limit` in the Caddyfile, #106).
	--with github.com/mholt/caddy-ratelimit \
	--with github.com/components-web-app/components-web-app/api/frankenphp/caddy/queryallowlist=/tmp/queryallowlist
	# --with github.com/darkweak/storages/go-redis/caddy \

FROM dunglas/frankenphp:latest AS frankenphp_upstream
COPY --from=builder --link /usr/local/bin/frankenphp /usr/local/bin/frankenphp

# The different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/develop/develop-images/multistage-build/#stop-at-a-specific-build-stage
# https://docs.docker.com/compose/compose-file/#target

# Base FrankenPHP image
FROM frankenphp_upstream AS frankenphp_base

WORKDIR /app

# persistent / runtime deps
# hadolint ignore=DL3008
RUN apt-get clean && apt-get update && apt-get install --no-install-recommends -y \
	acl \
	file \
	gettext \
	git \
	&& rm -rf /var/lib/apt/lists/*

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN set -eux; \
	install-php-extensions \
		@composer \
		apcu \
		intl \
		opcache \
		zip \
		exif \
		xsl \
		gd \
	;

###> recipes ###
###> doctrine/doctrine-bundle ###
RUN set -eux; \
	install-php-extensions pdo_pgsql
###< doctrine/doctrine-bundle ###
###< recipes ###

COPY --link frankenphp/conf.d/10-app.ini $PHP_INI_DIR/conf.d/
COPY --link --chmod=755 frankenphp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --link frankenphp/Caddyfile /etc/caddy/Caddyfile

ENTRYPOINT ["docker-entrypoint"]

HEALTHCHECK --start-period=60s CMD curl -f http://localhost:2019/metrics || exit 1
CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile" ]

# Dev FrankenPHP image
FROM frankenphp_base AS frankenphp_dev

ENV APP_ENV=dev XDEBUG_MODE=off
VOLUME /app/var/

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

RUN set -eux; \
	install-php-extensions \
		xdebug \
	;

COPY --link frankenphp/conf.d/20-app.dev.ini $PHP_INI_DIR/conf.d/

CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--watch" ]

# Prod FrankenPHP image
FROM frankenphp_base AS frankenphp_prod

ENV APP_ENV=prod
ENV FRANKENPHP_CONFIG="import worker.Caddyfile"
ENV GOOGLE_CLOUD_PROJECT="local-fallback-id"

# prevent the reinstallation of vendors at every changes in the source code
COPY --link composer.* symfony.* ./
# composer_auth is an optional build secret, never a build arg (it would land in the image history).
# The rate-limit line prints 60 when no token reached the build and 5000 when one did.
RUN --mount=type=secret,id=composer_auth \
	set -eu; \
	if [ -s /run/secrets/composer_auth ]; then COMPOSER_AUTH="$(cat /run/secrets/composer_auth)"; export COMPOSER_AUTH; fi; \
	GH_TOKEN="$(printf '%s' "${COMPOSER_AUTH:-}" | sed -n 's/.*"github\.com": *"\([^"]*\)".*/\1/p')"; \
	if [ -n "$GH_TOKEN" ]; then RL="$(curl -s -o /dev/null -D - -H "Authorization: Bearer ${GH_TOKEN}" https://api.github.com/rate_limit || true)"; else RL="$(curl -s -o /dev/null -D - https://api.github.com/rate_limit || true)"; fi; \
	echo "github rate limit for this build: $(printf '%s' "$RL" | tr -d '\r' | sed -n 's/^[Xx]-[Rr]ate[Ll]imit-[Ll]imit: //p' | head -1)  (60 = anonymous, 5000 = token applied)"; \
	COMPOSER_MAX_PARALLEL_HTTP=6 composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

# Moved these below the composer install as they will not affect it and then if we change them it will miss cache and wait for composer install again
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY --link frankenphp/conf.d/20-app.prod.ini $PHP_INI_DIR/conf.d/
COPY --link frankenphp/worker.Caddyfile /etc/caddy/worker.Caddyfile

# copy sources
COPY --link . ./
RUN rm -Rf frankenphp/

RUN set -eux; \
	mkdir -p var/cache var/log; \
	composer dump-autoload --classmap-authoritative --no-dev; \
	composer dump-env prod; \
	composer run-script --no-dev post-install-cmd; \
	chmod +x bin/console; sync;
