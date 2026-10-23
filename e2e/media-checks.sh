#!/bin/sh
# Media acceptance (#211). e2e/run.sh runs it in the php container (`sh -s`), with ADMIN_PASSWORD in the environment.
# `upload`: an admin uploads a PNG; checks the original and its WebP variants are served, then prints their URLs.
# `served <url>...`: checks each URL still answers 200 (run.sh recreates php in between).
set -eu

failures=0
pass() { echo "  ok: $*" >&2; }
fail() { echo "  FAILED: $*" >&2; failures=$((failures + 1)); }
# The status and content type of a GET, from inside php (the URLs name the site's public host or the bucket's).
served() { curl -sk --resolve localhost:443:127.0.0.1 -o /dev/null -w '%{http_code} %{content_type}' "$1"; }

case "${1:-}" in
  upload)
    work=$(mktemp -d)
    php -r '$i = imagecreatetruecolor(1600, 1200); imagefill($i, 0, 0, imagecolorallocate($i, 200, 30, 30)); imagepng($i, $argv[1]);' "$work/media.png"
    code=$(curl -sk -c "$work/jar" -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' \
      -d "{\"username\":\"admin\",\"password\":\"$ADMIN_PASSWORD\"}" https://localhost/_api/login)
    [ "$code" = 204 ] || { fail "admin login answered $code"; exit 1; }
    curl -sk -b "$work/jar" -o "$work/image.json" -H 'Accept: application/ld+json' -F "file=@$work/media.png;type=image/png" \
      https://localhost/_api/component/images/upload
    # The upload's response lists the original and each filter's variant (generated on this first read).
    urls=$(grep -o '"contentUrl":"http[^"]*"' "$work/image.json" | sed 's/^"contentUrl":"//; s/"$//; s#\\/#/#g')
    rm -rf "$work"
    original=$(echo "$urls" | grep -v '/cache/' | head -n 1)
    variants=$(echo "$urls" | grep '/cache/' || true)
    [ -n "$original" ] || { fail "the upload returned no contentUrl"; exit 1; }
    [ -n "$variants" ] || fail "the upload returned no imagine variants"
    case "$(served "$original")" in "200 image/png"*) pass "original served: $original" ;; *) fail "original $original: $(served "$original")" ;; esac
    for url in $variants; do
      case "$(served "$url")" in "200 image/webp"*) pass "WebP variant served: $url" ;; *) fail "variant $url: $(served "$url")" ;; esac
    done
    [ "$failures" = 0 ] || exit 1
    echo $original $variants
    ;;
  served)
    shift
    for url in "$@"; do
      case "$(served "$url")" in 200*) pass "still served: $url" ;; *) fail "$url: $(served "$url")" ;; esac
    done
    [ "$failures" = 0 ] || exit 1
    ;;
  *) echo "Usage: media-checks.sh upload | served <url>..." >&2; exit 2 ;;
esac
