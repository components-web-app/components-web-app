#syntax=docker/dockerfile:1

# Adapted from https://github.com/dunglas/symfony-docker

# Versions
FROM dunglas/frankenphp:builder AS builder

# Copy xcaddy in the builder image
COPY --from=caddy:builder /usr/bin/xcaddy /usr/bin/xcaddy

# Souin v1.7.9 deletes purged surrogate keys with an unanchored regex, so purging
# one tag also drops the index entry of every tag containing it, and those cached
# responses can never be purged again. Build from a patched copy of v1.7.9.
# Remove this, the patch and the replace below once a Souin release includes the
# fix; bin/test/souin-purge-isolation.sh must pass.
# https://github.com/components-web-app/components-web-app/issues/84
# https://github.com/darkweak/souin/issues/867 (fix: https://github.com/darkweak/souin/pull/868)
#
# Souin coalesces upstream fetches with singleflight, and v1.7.9 keeps a key's
# call open until php returns. A request that never returns therefore costs the
# key for the life of the process: every later request for it waits out the
# backend timeout and 504s. On the readiness probe's URL that leaves the pod
# unready and never restarted (#62, and cymru-kitchens for 35h on 2026-09-30).
# The patch is darkweak/souin#850 (issue #849): a timed-out request forgets the
# key, so the next one starts a fresh call. Remove it with the replace below once
# a Souin release includes it.
#
# Souin's Cloudflare purge has never worked: it POSTs to /zones/<id>/purge, not
# /purge_cache, sends only Global API Key headers, and throws the result away in
# a goroutine, so it fails silently with any credential (#108). The patch fixes
# the endpoint, sends api_key as a bearer token when no email is set (a scoped
# Zone > Cache Purge token), bounds each request with a timeout and logs any
# failure. A full flush (PURGE .../flush) also purges everything in the zone, so
# "Purge all cached data", fixture loads and deploys clear the edge too. It only
# runs when CADDY_CACHE_CDN_CONFIG sets `provider cloudflare`.
COPY --link frankenphp/souin/v1.7.9-purge-fix.patch /tmp/souin-purge-fix.patch
COPY --link frankenphp/souin/v1.7.9-singleflight-fix.patch /tmp/souin-singleflight-fix.patch
COPY --link frankenphp/souin/v1.7.9-cloudflare-purge.patch /tmp/souin-cloudflare-purge.patch
RUN SOUIN_DIR=$(go mod download -json github.com/darkweak/souin@v1.7.9 | sed -n 's/.*"Dir": "\(.*\)",/\1/p') && \
	cp -r "$SOUIN_DIR" /tmp/souin && \
	chmod -R u+w /tmp/souin && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-purge-fix.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-singleflight-fix.patch && \
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
RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

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
