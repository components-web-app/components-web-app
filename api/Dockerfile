# the different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/develop/develop-images/multistage-build/#stop-at-a-specific-build-stage
# https://docs.docker.com/compose/compose-file/#target

# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
# in dev incompatible packages are (for PHP 8.0)
# friends-of-behat/mink 1.8.0
# friends-of-behat/mink-browserkit-driver 1.4.0
# friends-of-behat/mink-extension 2.4.0
# friends-of-behat/symfony-extension (dev supports it)
# behatch/contexts requires friends-of-behat/mink-extension ^2.3.1
ARG PHP_VERSION=7.4
ARG APCU_VERSION=5.1.19
ARG VARNISH_VERSION=6.4
ARG CADDY_VERSION=2

# "php" stage
FROM registry.gitlab.com/silverback-web-apps/cwa/docker/php:${PHP_VERSION}-fpm-alpine AS cwa_php

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

ENV PATH="${PATH}:/root/.composer/vendor/bin"

# build for production
ARG APP_ENV=prod

RUN ln -s $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY _docker/php/conf.d $PHP_INI_DIR/cwa.conf.d/

# prevent the reinstallation of vendors at every changes in the source code
COPY composer.* symfony.lock ./
RUN set -eux; \
	composer install --prefer-dist --no-dev --no-scripts --no-progress; \
	composer clear-cache

# do not use .env files in production
COPY .env ./
RUN composer dump-env prod; \
	rm .env

# copy only specifically what we need
COPY bin bin/
COPY config config/
COPY public public/
COPY src src/
COPY assets assets/
COPY migrations migrations/

RUN set -eux; \
	mkdir -p var/cache var/log; \
	composer dump-autoload --classmap-authoritative --no-dev; \
	composer run-script --no-dev post-install-cmd; \
	chmod +x bin/console; sync

VOLUME /srv/api/var

## healthchech override for socket
COPY _docker/php/docker-healthcheck.sh /usr/local/bin/docker-healthcheck
RUN chmod +x /usr/local/bin/docker-healthcheck
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD ["docker-healthcheck"]

COPY _docker/php/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
## end healthchech override for socket instead of port

VOLUME /var/run/php

COPY _docker/php/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENV SYMFONY_PHPUNIT_VERSION=9

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]

# "caddy" stage
# depends on the "php" stage above
FROM caddy:${CADDY_VERSION} AS cwa_caddy

WORKDIR /srv/api

COPY --from=dunglas/mercure:v0.11 /srv/public /srv/mercure-assets/
COPY --from=registry.gitlab.com/silverback-web-apps/cwa/docker/caddy-builder:mercure-vulcain /usr/bin/caddy /usr/bin/caddy
COPY --from=cwa_php /srv/api/public public/
COPY _docker/caddy/Caddyfile /etc/caddy/Caddyfile

# "varnish" stage
# does not depend on any of the above stages
FROM varnish:${VARNISH_VERSION} AS cwa_varnish

RUN \
  apt-get update \
  && apt-get -y install gettext-base \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY _docker/varnish/conf/default.vcl /tmp/varnish/conf/default.vcl
COPY _docker/varnish/persist-environment.sh /usr/local/bin/persist-environment

RUN chmod +x /usr/local/bin/persist-environment
ENTRYPOINT ["persist-environment", "docker-varnish-entrypoint"]

CMD ["varnishd", "-F", "-f", "/etc/varnish/default.vcl", "-p", "http_resp_hdr_len=65536", "-p", "http_resp_size=98304", "-p", "workspace_backend=512K"]
