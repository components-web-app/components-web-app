#!/bin/sh
# Checks a cwa-php-base image before it is tagged (#208): patched plugins, extensions, then the Souin and Caddyfile tests.
# Runs inside the base image with this checkout as the working directory and Redis at REDIS_ADDR. Usage: bin/test/php-base-smoke.sh
set -eu

cd "$(dirname "$0")/../.."

# Lowest PHP a base may ship (CVE-2026-109618, CVE-2026-109619: fixed in 8.5.12); raise it with each PHP security release.
MIN_PHP_ID=80512
for php_id in "$(php -r 'echo PHP_VERSION_ID;')" "$(frankenphp php-cli -r 'echo PHP_VERSION_ID;')"; do
	[ "$php_id" -ge "$MIN_PHP_ID" ] || { echo "FAIL: PHP $php_id is below $MIN_PHP_ID (unpatched security release)"; exit 1; }
done
echo "ok:   PHP $(php -r 'echo PHP_VERSION;') is at or above the security floor"

# build-info prints a replace as a "=>" line under its "dep" line.
frankenphp build-info | awk '$1 == "dep" { m = $2 } $1 == "=>" { print m " => " $2 }' > /tmp/build-info.txt
for replace in 'github.com/darkweak/souin => /tmp/souin' \
	'github.com/darkweak/storages/go-redis => /tmp/storages-go-redis' \
	'github.com/components-web-app/components-web-app/api/frankenphp/caddy/queryallowlist => /tmp/queryallowlist'; do
	grep -qF "$replace" /tmp/build-info.txt || { echo "FAIL: build-info has no '$replace'"; exit 1; }
done
frankenphp list-modules | grep -qx 'http.handlers.query_allowlist' || { echo "FAIL: no query_allowlist module"; exit 1; }
echo "ok:   patched Souin, storages and query_allowlist are built in"

for ext in apcu intl 'Zend OPcache' zip exif xsl gd FFI brotli pdo_pgsql; do
	php -m | grep -qix "$ext" || { echo "FAIL: php extension $ext missing"; exit 1; }
done
php -m | grep -qix xdebug && { echo "FAIL: xdebug must be built but not enabled"; exit 1; }
test -f "$(php-config --extension-dir)/xdebug.so" || { echo "FAIL: xdebug.so missing"; exit 1; }
command -v composer retry-fetch install-php-extensions >/dev/null
php -r 'exit(extension_loaded("ffi") && class_exists("FFI") ? 0 : 1);'
ldconfig -p | grep -q 'libvips\.so\.42' || { echo "FAIL: libvips missing"; exit 1; }
echo "ok:   extensions, composer, retry-fetch and libvips"

for t in souin-purge-isolation souin-flush-storage souin-coalesced-5xx souin-php-flush souin-redis-shared-purge; do
	echo "== $t"
	sh "bin/test/$t.sh"
done

# The Caddyfile tests read it from /etc/caddy, as in a project image (its imports are relative).
mkdir -p /etc/caddy
cp api/frankenphp/Caddyfile api/frankenphp/worker.Caddyfile api/frankenphp/mercure-hub.caddy api/frankenphp/mercure-hub.Caddyfile /etc/caddy/
for t in caddy-validate cache-encoding caddy-php-headers souin-backend-timeout; do
	echo "== $t"
	sh "bin/test/$t.sh"
done
echo "OK: cwa-php-base smoke tests passed"
