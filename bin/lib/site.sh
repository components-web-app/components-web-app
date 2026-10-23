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
