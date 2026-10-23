#syntax=docker/dockerfile:1

# Adapted from https://github.com/dunglas/symfony-docker

# The php base (#208): a release sets this release's ghcr.io/components-web-app/cwa-php-base:<version>, prebuilt with our plugins, patches and extensions.
# cwa_php_base builds it from source (--build-arg CWA_PHP_BASE=cwa_php_base), for projects that change api/frankenphp/{souin,storages,caddy}.
ARG CWA_PHP_BASE=ghcr.io/components-web-app/cwa-php-base:2.0.0-alpha.47

FROM dunglas/frankenphp:builder AS builder

# Copy xcaddy in the builder image
COPY --from=caddy:builder /usr/bin/xcaddy /usr/bin/xcaddy
# Go module fetches stall or fail (sum.golang.org stream errors) on GitLab SaaS runners: bound and retry them, as for Debian (#176, #213).
COPY --link --chmod=755 frankenphp/retry-fetch.sh /usr/local/bin/retry-fetch
# sum.golang.org resets HTTP/2 streams from GitLab SaaS runners ("stream error … INTERNAL_ERROR"): Go fetches over HTTP/1.1 (#213).
ENV GODEBUG=http2client=0

# Patched Souin v1.7.9: purge regex (#84), singleflight (#62, #137), flush (#114), Cloudflare purge (#108, #115), writer Flush (#185).
# Remove each with its replace once a Souin release has it (bin/test/souin-*.sh must pass).
COPY --link frankenphp/souin/v1.7.9-purge-fix.patch /tmp/souin-purge-fix.patch
COPY --link frankenphp/souin/v1.7.9-singleflight-fix.patch /tmp/souin-singleflight-fix.patch
COPY --link frankenphp/souin/v1.7.9-singleflight-5xx.patch /tmp/souin-singleflight-5xx.patch
COPY --link frankenphp/souin/v1.7.9-flush-no-close.patch /tmp/souin-flush-no-close.patch
COPY --link frankenphp/souin/v1.7.9-cloudflare-purge.patch /tmp/souin-cloudflare-purge.patch
COPY --link frankenphp/souin/v1.7.9-writer-flush.patch /tmp/souin-writer-flush.patch
RUN retry-fetch 300 go mod download github.com/darkweak/souin@v1.7.9 && SOUIN_DIR=$(go mod download -json github.com/darkweak/souin@v1.7.9 | sed -n 's/.*"Dir": "\(.*\)",/\1/p') && \
	cp -r "$SOUIN_DIR" /tmp/souin && \
	chmod -R u+w /tmp/souin && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-purge-fix.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-singleflight-fix.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-singleflight-5xx.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-flush-no-close.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-cloudflare-purge.patch && \
	patch -d /tmp/souin -p1 --forward < /tmp/souin-writer-flush.patch

# Patched storages go-redis v0.0.20: atomic tag sets across pods (#85, darkweak/storages#65).
# Remove with its replace once a storages release has it (bin/test/souin-redis-shared-purge.sh must pass).
COPY --link frankenphp/storages/go-redis-v0.0.20-atomic-sets.patch /tmp/storages-go-redis.patch
RUN retry-fetch 300 go mod download github.com/darkweak/storages/go-redis@v0.0.20 && GO_REDIS_DIR=$(go mod download -json github.com/darkweak/storages/go-redis@v0.0.20 | sed -n 's/.*"Dir": "\(.*\)",/\1/p') && \
	cp -r "$GO_REDIS_DIR" /tmp/storages-go-redis && \
	chmod -R u+w /tmp/storages-go-redis && \
	patch -d /tmp/storages-go-redis -p1 --forward < /tmp/storages-go-redis.patch

# The template's own Caddy handler: keeps only the allowlisted query parameters on
# pages (`query_allowlist` in the Caddyfile, #106).
COPY --link frankenphp/caddy/queryallowlist /tmp/queryallowlist

RUN CGO_ENABLED=1 \
    XCADDY_SETCAP=1 \
    XCADDY_GO_BUILD_FLAGS="-ldflags='-w -s' -tags=nobadger,nomysql,nopgx" \
    CGO_CFLAGS=$(php-config --includes) \
    CGO_LDFLAGS="$(php-config --ldflags) $(php-config --libs)" \
    retry-fetch 1000 xcaddy build \
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
	# Shared store for scaled mode (#85); only one of go-redis/caddy and redis/caddy can be built.
	--with github.com/darkweak/storages/go-redis/caddy \
	--with github.com/darkweak/storages/go-redis=/tmp/storages-go-redis \
	# Per-visitor rate limit on cache misses (`rate_limit` in the Caddyfile, #106).
	--with github.com/mholt/caddy-ratelimit \
	--with github.com/components-web-app/components-web-app/api/frankenphp/caddy/queryallowlist=/tmp/queryallowlist

# Published as cwa-php-base by publish-php-base.yml (#208): nothing project-specific in this stage.
FROM dunglas/frankenphp:latest AS cwa_php_base
COPY --from=builder --link /usr/local/bin/frankenphp /usr/local/bin/frankenphp

# apt retries, timeouts and no pipelining for every apt call, install-php-extensions' too; retry-fetch bounds each step (#176).
# Debian over HTTPS: plain HTTP to deb.debian.org stalls on GitLab SaaS runners (#176).
COPY --link --chmod=755 frankenphp/retry-fetch.sh /usr/local/bin/retry-fetch
RUN printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\nAcquire::http::Pipeline-Depth "0";\n' > /etc/apt/apt.conf.d/80-cwa-retries \
	&& sed -i 's#http://deb.debian.org#https://deb.debian.org#' /etc/apt/sources.list.d/debian.sources

# persistent / runtime deps
# hadolint ignore=DL3008
RUN apt-get clean && retry-fetch 240 sh -c 'apt-get update && apt-get install --no-install-recommends -y \
	acl \
	file \
	gettext \
	git \
	libvips42t64' \
	&& rm -rf /var/lib/apt/lists/*

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

# Uncached, about 4 minutes; a retry skips the extensions already installed.
# brotli: warm-http-cache --accept-encoding=br decodes br with it, or warms only the routes (#175).
# xdebug is built here but left disabled; frankenphp_dev enables it with no network (#208).
RUN retry-fetch 480 install-php-extensions \
		@composer \
		apcu \
		intl \
		opcache \
		zip \
		exif \
		xsl \
		gd \
		ffi \
		brotli \
		pdo_pgsql \
		xdebug \
	&& rm "$PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini"

# libvips, the imagine driver (#141): no ImageMagick, PDF or SVG loaders for uploads, two threads per image,
# and glibc settings that hand freed image buffers back to the OS. All overridable at runtime.
ENV VIPS_BLOCK_UNTRUSTED=1 VIPS_CONCURRENCY=2 MALLOC_ARENA_MAX=2 MALLOC_MMAP_THRESHOLD_=1048576

# Inherited by project images, so `docker inspect` shows which base they were built on (#208).
LABEL rocks.cwa.php-base.source="https://github.com/components-web-app/components-web-app"

# The different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/develop/develop-images/multistage-build/#stop-at-a-specific-build-stage
# https://docs.docker.com/compose/compose-file/#target

# Base FrankenPHP image: the published base (or cwa_php_base) plus this project's config (#208).
FROM ${CWA_PHP_BASE} AS frankenphp_base

WORKDIR /app

# pdo_pgsql is already in the base (#208); a recipe adding an install-php-extensions line here is harmless.
###> recipes ###
###< recipes ###

COPY --link frankenphp/conf.d/10-app.ini $PHP_INI_DIR/conf.d/
COPY --link --chmod=755 frankenphp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --link frankenphp/site-hosts.sh /usr/local/bin/site-hosts.sh
COPY --link frankenphp/Caddyfile /etc/caddy/Caddyfile
COPY --link frankenphp/mercure-hub.caddy frankenphp/mercure-hub.Caddyfile /etc/caddy/

ENTRYPOINT ["docker-entrypoint"]

# php and the database through the Caddyfile's loopback health site, whatever SERVER_NAME is (#205); start-period covers migrations.
# Kubernetes ignores this: the chart's probes are its own.
HEALTHCHECK --start-period=300s --start-interval=2s --interval=10s --timeout=5s --retries=3 \
	CMD curl -fsS -o /dev/null --max-time 4 http://127.0.0.1:2080/_api/_/health || exit 1
CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile" ]

# Dev FrankenPHP image
FROM frankenphp_base AS frankenphp_dev

ENV APP_ENV=dev XDEBUG_MODE=off
VOLUME /app/var/

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

# Built into the base, disabled (#208).
RUN docker-php-ext-enable xdebug

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
