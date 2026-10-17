#!/bin/sh
# Regression test (#168): k8s.sh's gcloud_path_prefix tidies GCLOUD_PATH_PREFIX exactly as php's PathPrefixEnvVarProcessor.
# Usage (repository root, after composer install): bin/test/storage-prefix-parity.sh [k8s.sh] [api/vendor/autoload.php]
set -eu

K8S="${1:-bin/devops/k8s.sh}"
AUTOLOAD="${2:-api/vendor/autoload.php}"
REVIEW_REFUSAL="GCLOUD_PATH_PREFIX can't contain a 'review' segment: review apps store under <GCLOUD_PATH_PREFIX>review/<slug>/ (#168)."
[ -f "$K8S" ] || { echo "No $K8S." >&2; exit 2; }
[ -f "$AUTOLOAD" ] || { echo "No $AUTOLOAD: run composer install in api/ first." >&2; exit 2; }

# GitLab deploys source k8s.sh in busybox ash; it isn't POSIX sh (function delete()), so dash can't.
if command -v busybox >/dev/null 2>&1 && busybox ash -c : 2>/dev/null; then
  K8S_SHELL="busybox ash"
elif command -v bash >/dev/null 2>&1; then
  K8S_SHELL=bash
else
  echo "Needs busybox ash or bash to source $K8S." >&2
  exit 2
fi
echo "Sourcing $K8S with $K8S_SHELL."

# One printf %b-escaped case per line.
CASES='

\t\n\r\v
//
/
site-a
site-a/
site-a//
/site-a
 site-a/
\tsite-a/\n
//a//b//
a b/c
 a b /c
...
a..b
.hidden
a/.hidden/b
0
a/0/b
.
..
a/./b
/..
review/../site
./..
a/../.
a\nb
review
review/
site-a/review
site-a/review/x
reviews
site-a/reviewed/
my-review/
'

decode() { printf '%b' "$1"; }

php_result() {
  GCLOUD_PATH_PREFIX="$1" AUTOLOAD="$AUTOLOAD" php -r '
    require getenv("AUTOLOAD");
    try {
      $prefix = App\Flysystem\PathPrefixEnvVarProcessor::normalise((string) getenv("GCLOUD_PATH_PREFIX"));
      echo "ok:", $prefix;
    } catch (RuntimeException $e) {
      echo "refused:", $e->getMessage();
    }'
}

k8s_result() {
  GCLOUD_PATH_PREFIX="$1" CI_ENVIRONMENT_SLUG=slug $K8S_SHELL -c '
    . "$1" >/dev/null
    err=$(mktemp)
    if out=$(gcloud_path_prefix "$2" 2>"$err"); then printf "ok:%s" "$out"; else printf "refused:"; cat "$err"; fi
    rm -f "$err"' k8s "$K8S" "$2"
}

# Prints a value one character at a time (od -c), so whitespace and control characters show.
show() { printf '%s' "$1" | od -An -c | tr -d '\n' | sed 's/   */ /g'; }

failures=0
count=0
check() {
  count=$((count + 1))
  if [ "$3" != "$4" ]; then
    failures=$((failures + 1))
    echo "FAIL: GCLOUD_PATH_PREFIX=[$(show "$1")] ($2)" >&2
    echo "  expected: $(show "$3")" >&2
    echo "  k8s.sh:   $(show "$4")" >&2
  fi
}

while IFS= read -r line; do
  value=$(decode "$line"; echo x); value=${value%x}
  php=$(php_result "$value"; echo x); php=${php%x}
  case "$php" in
    ok:*)
      prefix=${php#ok:}
      case "/$prefix" in
        */review/*) stable="refused:$REVIEW_REFUSAL"; review=$stable ;;
        *) stable="ok:$prefix"; review="ok:${prefix}review/slug/" ;;
      esac
      ;;
    refused:*)
      # php ends its message with a full stop; the deploy names the variable before it.
      stable="${php%.} (GCLOUD_PATH_PREFIX)."; review=$stable
      ;;
    *) echo "php gave no result for [$(show "$value")]: $php" >&2; exit 2 ;;
  esac
  got=$(k8s_result "$value" stable; echo x); got=${got%x}; got=${got%"
"}
  check "$value" stable "$stable" "$got"
  got=$(k8s_result "$value" review; echo x); got=${got%x}; got=${got%"
"}
  check "$value" review "$review" "$got"
done <<EOF
$CASES
EOF

if [ "$failures" -ne 0 ]; then
  echo "storage-prefix-parity: $failures of $count checks differ from php (#168)." >&2
  exit 1
fi
echo "storage-prefix-parity: $count checks agree with php."
