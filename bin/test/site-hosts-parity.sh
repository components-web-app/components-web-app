#!/bin/sh
# Regression test (#207): the php entrypoint's host settings for compose.prod.yaml (api/frankenphp/site-hosts.sh) match
# what k8s.sh's apply_site_defaults sets on the stable track, and a set value wins.
# Usage (repository root): sh bin/test/site-hosts-parity.sh
set -eu

K8S=bin/devops/k8s.sh
HOSTS=api/frankenphp/site-hosts.sh
# GitLab deploys source k8s.sh in busybox ash; it isn't POSIX sh, so dash can't.
if command -v busybox >/dev/null 2>&1 && busybox ash -c : 2>/dev/null; then
  K8S_SHELL="busybox ash"
elif command -v bash >/dev/null 2>&1; then
  K8S_SHELL=bash
else
  echo "Needs busybox ash or bash to source $K8S." >&2
  exit 2
fi

# site-hosts.sh with SITE_HOST=$1 and SITE_ALIASES=$2 (as given), in POSIX sh.
entrypoint() {
  env -u TRUSTED_HOSTS -u CORS_ALLOW_ORIGIN -u MERCURE_CORS_ORIGIN SITE_HOST="$1" SITE_ALIASES="$2" sh -c '
    . "$0" && cwa_site_host_defaults && printf "%s\n%s\n%s" "$TRUSTED_HOSTS" "$CORS_ALLOW_ORIGIN" "$MERCURE_CORS_ORIGIN"' "$HOSTS"
}
# apply_site_defaults for DOMAIN=$1 and KUBE_INGRESS_ALIAS_DOMAINS=$2 (comma-separated, as on GitLab).
k8s() {
  env -u TRUSTED_HOSTS -u CORS_ALLOW_ORIGIN -u MERCURE_CORS_ORIGIN DOMAIN="$1" KUBE_INGRESS_ALIAS_DOMAINS="$2" $K8S_SHELL -c '
    . "$0" >/dev/null && apply_site_defaults stable && printf "%s\n%s\n%s" "$TRUSTED_HOSTS" "$CORS_ALLOW_ORIGIN" "$MERCURE_CORS_ORIGIN"' "$K8S"
}

failures=0
check() { # check <SITE_HOST> <SITE_ALIASES> <the same aliases, comma-separated>
  a=$(entrypoint "$1" "$2")
  b=$(k8s "$1" "$3")
  if [ "$a" = "$b" ]; then
    echo "ok: SITE_HOST='$1' SITE_ALIASES='$2'"
  else
    failures=$((failures + 1))
    printf 'FAIL: SITE_HOST=%s SITE_ALIASES=%s\n  entrypoint: %s\n  k8s.sh:     %s\n' "$1" "$2" "$a" "$b" >&2
  fi
}
check example.com '' ''
check example.com 'www.example.com' 'www.example.com'
check example.com 'www.example.com other.example.org' 'www.example.com,other.example.org'
check example.com 'www.example.com, other.example.org' 'www.example.com, other.example.org'
check sub.domain.example.co.uk '' ''
check localhost '' ''

# A set value wins; empty counts as unset (compose.prod.yaml passes empty).
got=$(TRUSTED_HOSTS='^custom$' CORS_ALLOW_ORIGIN='' SITE_HOST=example.com sh -c '. "$0" && cwa_site_host_defaults && printf "%s %s" "$TRUSTED_HOSTS" "$CORS_ALLOW_ORIGIN"' "$HOSTS")
if [ "$got" = '^custom$ ^https://(?:example\.com)$' ]; then echo "ok: a set value wins"; else failures=$((failures + 1)); echo "FAIL: override gave '$got'" >&2; fi
# No SITE_HOST (dev, Kubernetes): nothing changes.
got=$(env -u SITE_HOST -u TRUSTED_HOSTS sh -c '. "$0" && cwa_site_host_defaults && printf "%s" "${TRUSTED_HOSTS-unset}"' "$HOSTS")
if [ "$got" = unset ]; then echo "ok: no SITE_HOST, no change"; else failures=$((failures + 1)); echo "FAIL: without SITE_HOST got '$got'" >&2; fi
# Not a host name: refused, so the entrypoint stops.
for bad in 'https://example.com' 'example.com:8443' '.example.com' 'exa$mple.com'; do
  if SITE_HOST="$bad" sh -c '. "$0" && cwa_site_host_defaults' "$HOSTS" 2>/dev/null; then
    failures=$((failures + 1)); echo "FAIL: accepted SITE_HOST='$bad'" >&2
  else
    echo "ok: refuses SITE_HOST='$bad'"
  fi
done

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed." >&2; exit 1; }
echo "site-hosts.sh matches apply_site_defaults."
