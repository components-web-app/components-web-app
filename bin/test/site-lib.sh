#!/bin/sh
# Regression test (#212): bin/lib/site.sh's warm_cache works under plain POSIX sh (a server's dash), and k8s.sh still
# provides it. Serves a sitemap index with `php -S`. Usage (repository root): bin/test/site-lib.sh
set -eu

[ -f bin/lib/site.sh ] || { echo "Run from the repository root." >&2; exit 2; }
command -v php >/dev/null || { echo "Needs php (php -S serves the sitemap)." >&2; exit 2; }
failures=0
pass() { echo "ok: $*"; }
fail() { echo "FAILED: $*" >&2; failures=$((failures + 1)); }

root=$(mktemp -d)
port=18080
trap 'kill "$server" 2>/dev/null || true; rm -rf "$root"' EXIT
# A sitemap index with one child listing two pages, under another origin (the warm rewrites it); /missing is a 404.
cat > "$root/router.php" <<'PHP'
<?php
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$loc = fn (string $p) => "<loc>https://www.example.com$p</loc>";
header('Content-Type: application/xml');
switch ($path) {
    case '/sitemap.xml': echo '<sitemapindex><sitemap>' . $loc('/sitemap-pages.xml') . '</sitemap></sitemapindex>'; break;
    case '/sitemap-pages.xml':
        echo '<urlset><url>' . $loc('/') . '</url><url>' . $loc('/about') . '</url>';
        if (file_exists(__DIR__ . '/with-missing')) echo '<url>' . $loc('/missing') . '</url>';
        echo '</urlset>';
        break;
    case '/': case '/about': header('Content-Type: text/html'); echo 'page'; break;
    default: http_response_code(404);
}
PHP
php -n -S "127.0.0.1:$port" "$root/router.php" >/dev/null 2>&1 &
server=$!
tries=0
until curl -fs -o /dev/null "http://127.0.0.1:$port/sitemap.xml"; do
  tries=$((tries + 1)); [ "$tries" -lt 50 ] || { echo "php -S never answered." >&2; exit 1; }
  sleep 0.1
done

# Plain sh (dash on Debian), as bin/server/deploy.sh runs it.
if sh -c ". ./bin/lib/site.sh && warm_cache http://127.0.0.1:$port" > "$root/out" 2>&1 && grep -q 'Warmed 2 of 2 pages' "$root/out"; then
  pass "warm_cache follows the sitemap index and warms both pages under sh"
else
  fail "warm_cache under sh: $(cat "$root/out")"
fi
touch "$root/with-missing"
if sh -c ". ./bin/lib/site.sh && warm_cache http://127.0.0.1:$port" > "$root/out" 2>&1; then
  fail "warm_cache passed with a 404 page in the sitemap"
elif grep -q 'CACHE WARM FAILED: 1 of 3 pages' "$root/out"; then
  pass "warm_cache fails on a page that isn't 200"
else
  fail "warm_cache's failure: $(cat "$root/out")"
fi

# k8s.sh sources the file, so its deploys keep warm_cache and sitemap_pages.
if command -v busybox >/dev/null 2>&1 && busybox ash -c : 2>/dev/null; then shell="busybox ash"; else shell=bash; fi
if $shell -c '. ./bin/devops/k8s.sh && command -v warm_cache && command -v sitemap_pages' >/dev/null 2>&1; then
  pass "k8s.sh provides warm_cache and sitemap_pages ($shell)"
else
  fail "k8s.sh no longer provides warm_cache and sitemap_pages ($shell)"
fi

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed." >&2; exit 1; }
echo "site.sh checks passed."
