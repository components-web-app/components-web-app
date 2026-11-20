#!/bin/sh
# Site functions shared by the Kubernetes deploy (bin/devops/k8s.sh sources this) and bin/server/deploy.sh (#212).
# POSIX sh plus `local`: GitLab runs it in busybox ash, a server's /bin/sh is often dash. No arrays, jq or xmllint.

# Writes the sitemap's page URLs to <out>, de-duplicated, origins replaced by <base_url>, for warm_cache and audits.
#   sitemap_pages <base_url> <out> <curl_tls_opt> <label>
sitemap_pages() {
  local base="$1" out="$2" tls_opt="$3" label="$4"
  local tmp child
  tmp=$(mktemp -d)

  # Prints the <loc> values of the XML on stdin, one per line, rewritten to $base.
  _sitemap_locs() {
    tr '\r\n\t' '   ' \
      | grep -o '<loc>[^<]*</loc>' \
      | sed -E -e 's#</?loc>##g' -e 's#^ +##' -e 's# +$##' -e 's#&amp;#\&#g' \
               -e "s#^https?://[^/]+#${base}#"
  }

  echo "Reading the sitemap from ${base}/sitemap.xml..."
  if ! curl -fsSL $tls_opt --max-redirs 5 --max-time 60 --retry 2 --retry-connrefused \
      -o "$tmp/root.xml" "${base}/sitemap.xml"; then
    echo "!!!! ${label} FAILED: could not fetch ${base}/sitemap.xml !!!!"
    rm -rf "$tmp"
    return 1
  fi

  : > "$tmp/urls.txt"
  if grep -q '<sitemapindex' "$tmp/root.xml"; then
    for child in $(_sitemap_locs < "$tmp/root.xml"); do
      echo "  child sitemap: ${child}"
      if ! curl -fsSL $tls_opt --max-redirs 5 --max-time 60 --retry 2 --retry-connrefused \
          -o "$tmp/child.xml" "$child"; then
        echo "!!!! ${label} FAILED: could not fetch child sitemap ${child} !!!!"
        rm -rf "$tmp"
        return 1
      fi
      _sitemap_locs < "$tmp/child.xml" >> "$tmp/urls.txt"
    done
  else
    _sitemap_locs < "$tmp/root.xml" >> "$tmp/urls.txt"
  fi
  # De-duplicate, keeping sitemap order.
  awk 'NF && !seen[$0]++' "$tmp/urls.txt" > "$out"
  rm -rf "$tmp"
}

# Refills the page cache after purge_rendered_html (#80): warm_cache [base_url, default https://$DOMAIN]. Fails on any page that isn't 200.
warm_cache() {
  local base="${1:-${DOMAIN:+https://$DOMAIN}}"
  local concurrency="${CWA_CI_WARM_CACHE_CONCURRENCY:-3}"
  # CWA_CI_WARM_CACHE_CURL_OPTS adds curl options, e.g. bin/server/deploy.sh's --resolve to this machine (#212).
  local tls_opt="${CWA_CI_WARM_CACHE_CURL_OPTS:-}"
  if [ "${CWA_CI_WARM_CACHE_INSECURE:-}" = "true" ]; then
    tls_opt="$tls_opt --insecure"
  fi

  if [ -z "$base" ]; then
    echo "!!!! CACHE WARM FAILED: no base URL (DOMAIN is empty) !!!!"
    return 1
  fi
  case "$base" in
    http://*|https://*) ;;
    *) base="https://$base" ;;
  esac
  base="${base%/}"

  local tmp
  tmp=$(mktemp -d)

  if ! sitemap_pages "$base" "$tmp/pages.txt" "$tls_opt" "CACHE WARM"; then
    rm -rf "$tmp"
    return 1
  fi

  local total
  total=$(wc -l < "$tmp/pages.txt" | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    echo "!!!! CACHE WARM FAILED: the sitemap lists no pages !!!!"
    rm -rf "$tmp"
    return 1
  fi

  echo "Warming ${total} pages, ${concurrency} at a time (status, time to first byte, URL):"
  local started finished
  started=$(date +%s)
  # --retry covers a brief 502/503 while the ingress settles; a page that fails
  # every attempt is still reported with its final status. 000 means no response.
  tr '\n' '\0' < "$tmp/pages.txt" \
    | xargs -0 -n 1 -P "$concurrency" \
        curl -s $tls_opt -o /dev/null --max-time 60 --retry 2 --retry-delay 2 --retry-connrefused \
          -H 'Accept: text/html' \
          -w '%{http_code} %{time_starttransfer}s %{url_effective}\n' \
    | tee "$tmp/results.txt" \
    | sed 's#^#  #'
  finished=$(date +%s)

  local ok failed
  ok=$(grep -c '^200 ' "$tmp/results.txt")
  failed=$(( total - ok ))
  echo "Warmed ${ok} of ${total} pages in $(( finished - started ))s. Slowest:"
  # sed, not head: head exits after three lines, and under GitLab's pipefail the
  # SIGPIPE that sort then takes fails a warm that succeeded (exit 141, GitLab #2).
  sort -k2 -rn "$tmp/results.txt" | sed -n '1,3s#^#  #p'

  if [ "$failed" -ne 0 ]; then
    echo ""
    echo "!!!! CACHE WARM FAILED: ${failed} of ${total} pages did not return 200 !!!!"
    grep -v '^200 ' "$tmp/results.txt" | sed 's#^#  #'
    # Shown on the workflow run's summary page, even though the job passes.
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
      echo "::error title=Cache warm failed::${failed} of ${total} sitemap pages did not return 200 - see the deploy step log"
    fi
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

# Souin panics on a `cdn` line with no value and php never starts (#116); an unexpanded $NAME fails here too.
check_cdn_config() {
  local line directive value bad=""
  while IFS= read -r line; do
    set -f
    # shellcheck disable=SC2086
    set -- $line
    set +f
    directive="${1:-}"
    value="${2:-}"
    case "$directive" in
      api_key|email|hostname|network|provider|service_id|strategy|zone_id) ;;
      *) continue ;;
    esac
    if [ -z "$value" ]; then
      bad="${bad}  '$directive' has no value
"
    else
      case "$value" in
        '$'*) bad="${bad}  '$directive' is '$value', a variable reference that was never expanded
" ;;
      esac
    fi
  done <<EOF
${CADDY_CACHE_CDN_CONFIG:-}
EOF
  if [ -n "$bad" ]; then
    echo "CADDY_CACHE_CDN_CONFIG is incomplete, so php would not start:" >&2
    printf '%s' "$bad" >&2
    echo "Check the variable it refers to reaches this job (on GitLab, a Protected variable is only given to protected branches) and that its reference is expanded." >&2
    return 1
  fi
}

# Warns when DOMAIN answers through Cloudflare but no Cloudflare purge is configured: its edge keeps immutable
# /_nuxt files from earlier builds (#230). Only a warning: the request can fail, or the domain not point here yet.
check_cdn_purge() {
  case "${CADDY_CACHE_CDN_CONFIG:-}" in *provider*cloudflare*) return 0 ;; esac
  [ -n "${DOMAIN:-}" ] || return 0
  curl -ksS -o /dev/null -D - --max-time 10 "https://${DOMAIN}/" 2>/dev/null | grep -qi '^cf-ray:' || return 0
  echo "##################################################################" >&2
  echo "!!!! ${DOMAIN} IS BEHIND CLOUDFLARE, BUT NO CLOUDFLARE PURGE IS SET UP !!!!" >&2
  echo "Cloudflare caches /_nuxt files for a year, and nothing purges them" >&2
  echo "on deploy, so pages can load an earlier build's chunks and CSS." >&2
  echo "Set CADDY_CACHE_CDN_CONFIG with 'provider cloudflare' and a Zone >" >&2
  echo "Cache Purge token (docs: Cloudflare), then deploy. A CI variable" >&2
  echo "on Kubernetes; in .env.prod on a single server." >&2
  echo "##################################################################" >&2
  [ "${GITHUB_ACTIONS:-}" = "true" ] && echo "::warning title=Cloudflare purge not configured::${DOMAIN} is behind Cloudflare; set CADDY_CACHE_CDN_CONFIG with provider cloudflare"
  return 0
}
