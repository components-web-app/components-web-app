#!/bin/sh
# Regression test (#221): review apps sharing a namespace get a TLS secret each, other tracks keep theirs, names stay
# within 63 characters, and `delete review` removes only its own secret. Usage (repository root): bin/test/tls-secret-name.sh
set -eu

[ -f bin/devops/k8s.sh ] || { echo "Run from the repository root." >&2; exit 2; }
# GitLab deploys source k8s.sh in busybox ash; it isn't POSIX sh (function delete()), so dash can't.
if command -v busybox >/dev/null 2>&1 && busybox ash -c : 2>/dev/null; then shell="busybox ash"; else shell=bash; fi
log=$(mktemp)
trap 'rm -f "$log"' EXIT

LOG="$log" $shell -c '
  . ./bin/devops/k8s.sh
  failures=0
  check() { if [ "$2" = "$3" ]; then echo "ok: $1"; else echo "FAILED: $1: got \"$2\", expected \"$3\"" >&2; failures=$((failures + 1)); fi; }
  CWA_CI_TLS_SECRET_NAME=letsencrypt-cert
  check "production keeps its secret" "$(tls_secret_name stable production)" letsencrypt-cert-stable-api
  check "staging keeps its secret" "$(tls_secret_name staging production-staging)" letsencrypt-cert-staging-api
  check "a review app gets its own" "$(tls_secret_name review review-p1-shell-abc123-review)" letsencrypt-cert-review-p1-shell-abc123-review-api
  [ "$(tls_secret_name review review-a-review)" != "$(tls_secret_name review review-b-review)" ] \
    && echo "ok: two review apps get different secrets" || { echo "FAILED: two review apps share a secret" >&2; failures=$((failures + 1)); }
  long=$(tls_secret_name review review-a-very-long-branch-name-for-the-slug-review)
  other=$(tls_secret_name review review-a-very-long-branch-name-for-the-slug-other-review)
  check "a long name is at most 63 characters" "$([ "${#long}" -le 63 ] && echo yes)" yes
  [ "$long" != "$other" ] && echo "ok: long names that share a start still differ" || { echo "FAILED: long names collide" >&2; failures=$((failures + 1)); }

  # delete review removes this app'"'"'s secret only, after the uninstall.
  kubectl() { echo "kubectl $*" >> "$LOG"; }
  helm() { echo "helm $*" >> "$LOG"; }
  delete_review_storage() { :; }
  RELEASE=review-p1-shell-abc123 KUBE_NAMESPACE=ns delete review > /dev/null
  grep -q "kubectl delete secret --namespace=ns --ignore-not-found letsencrypt-cert-review-p1-shell-abc123-review-api" "$LOG" \
    && echo "ok: delete review removes its own TLS secret" || { echo "FAILED: delete review: $(cat "$LOG")" >&2; failures=$((failures + 1)); }
  ! grep -q "letsencrypt-cert-review-api" "$LOG" \
    && echo "ok: delete review leaves the old shared secret alone" || { echo "FAILED: delete review touched the shared secret" >&2; failures=$((failures + 1)); }
  [ "$failures" -eq 0 ]
' 2>&1 | tee /dev/stderr | grep -q FAILED && { echo "TLS secret name checks failed." >&2; exit 1; }
echo "TLS secret name checks passed."
