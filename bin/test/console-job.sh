#!/bin/sh
# Regression test (#229): console work runs in one-off Jobs from the suspended <release>-console CronJob, never in the
# serving API pod. run_console_job's Job spec, log and exit code; load_fixtures loads in a Job, then flushes in the API pod
# (Souin's admin API is its loopback) and warms; scaled mode's warm goes through the Service from Jobs. Runs k8s.sh against
# a stub kubectl. Usage (repository root): bin/test/console-job.sh [k8s.sh]
set -eu

K8S="${1:-bin/devops/k8s.sh}"
[ -f "$K8S" ] || { echo "No $K8S." >&2; exit 2; }
if command -v busybox >/dev/null 2>&1 && busybox ash -c : 2>/dev/null; then
  K8S_SHELL="busybox ash"
elif command -v bash >/dev/null 2>&1; then
  K8S_SHELL=bash
else
  echo "Needs busybox ash or bash to source $K8S." >&2
  exit 2
fi
echo "Sourcing $K8S with $K8S_SHELL."

DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT
mkdir "$DIR/bin"
# Records every call. The first console Job exits STUB_JOB_EXIT (default 0, "none": no pod), later ones 0.
cat >"$DIR/bin/kubectl" <<'STUB'
#!/bin/sh
echo "kubectl $*" >>"$STUB_LOG"
case "$*" in
  *"get cronjob"*"name=cwa-console,app.kubernetes.io/instance=$STUB_RELEASE"*) [ -n "${STUB_NO_CONSOLE:-}" ] || echo "cronjob.batch/$STUB_RELEASE-cwa-console" ;;
  *"get cronjob"*) ;;
  *"create job"*"--dry-run=client"*) echo '{"kind":"Job"}' ;;
  *"patch --local"*) echo '{"kind":"Job","patched":true}' ;;
  *"create -n"*" -f "*) ;;
  *"get job "*) echo 1 ;;
  *"logs "*"job/"*) echo "stub job log" ;;
  *"get pods"*"job-name="*)
    if [ -f "$STUB_LOG.job" ]; then echo 0; else
      : >"$STUB_LOG.job"
      [ "${STUB_JOB_EXIT:-0}" = none ] || echo "${STUB_JOB_EXIT:-0}"
    fi ;;
  *"get deploy"*"name=cwa,"*) echo "deployment.apps/$STUB_RELEASE-cwa" ;;
  *"get pods"*"{{if .metadata.deletionTimestamp}}"*) ;;
  *"get pods"*"name=cwa,"*) echo "pod/$STUB_RELEASE-cwa-new" ;;
esac
exit 0
STUB
chmod +x "$DIR/bin/kubectl"

# run <release> <shell code> [settings]: sources k8s.sh with RELEASE=rel and runs the code.
run() {
  : >"$DIR/log"
  rm -f "$DIR/log.job"
  status=0
  PATH="$DIR/bin:$PATH" STUB_LOG="$DIR/log" STUB_RELEASE="$1" RELEASE=rel KUBE_NAMESPACE=ns $K8S_SHELL -c '
    unset CWA_CI_API_SCALED_PRODUCTION CWA_CI_API_SCALED_REVIEW CWA_CI_API_AUTOSCALE_MIN CWA_CI_API_AUTOSCALE_MAX \
      CWA_CI_API_WARM_SURGE CWA_CI_API_WARM_CONCURRENCY CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME CWA_CI_FIXTURES_PURGE \
      ADMIN_PASSWORD GITHUB_ACTIONS
    for setting in $3; do export "$setting"; done
    . "$1" >/dev/null
    eval "$2"' k8s "$K8S" "$2" "${3:-}" >"$DIR/out" 2>&1 || status=$?
}
failures=0
fail() { failures=$((failures + 1)); echo "FAIL ($1): $2" >&2; }
expect() { grep -qF -- "$2" "$DIR/log" || fail "$1" "no call containing: $2"; }
refuse() { ! grep -qF -- "$2" "$DIR/log" || fail "$1" "unexpected call containing: $2"; }
said() { grep -qF -- "$2" "$DIR/out" || fail "$1" "the output doesn't say: $2"; }
exited() { [ "$status" -eq "$2" ] || fail "$1" "exited $status, wanted $2"; }
order() {
  first=$(grep -nF -- "$2" "$DIR/log" | head -1 | cut -d: -f1)
  second=$(grep -nF -- "$3" "$DIR/log" | head -1 | cut -d: -f1)
  if [ -z "$first" ] || [ -z "$second" ] || [ "$first" -ge "$second" ]; then fail "$1" "'$2' must come before '$3'"; fi
}

# The helper: args replace the CronJob's, NAME=value pairs become env, the log is printed and a success deleted.
run rel 'run_console_job stable SKIP_MERCURE_PUBLISH=true app:thing "say \"hi\"" --opt=a=b'
exited helper 0
expect helper 'get cronjob -n ns -l app.kubernetes.io/name=cwa-console,app.kubernetes.io/instance=rel -o name'
expect helper '--from=cronjob/rel-cwa-console --dry-run=client -o json'
expect helper '"value":["bin/console","app:thing","say \"hi\"","--opt=a=b"]'
expect helper '"path":"/spec/template/spec/containers/0/env/-","value":{"name":"SKIP_MERCURE_PUBLISH","value":"true"}'
refuse helper '"name":"--opt"'
expect helper 'create -n ns -f '
expect helper 'delete job -n ns rel-console-'
refuse helper 'exec '
said helper 'stub job log'
order helper 'patch --local' 'create -n ns -f '

run rel 'run_console_job stable app:thing' "STUB_JOB_EXIT=137"
exited failed 137
refuse failed 'delete job'
said failed 'exited 137'

run rel 'run_console_job stable app:thing' "STUB_JOB_EXIT=none"
exited unfinished 124
said unfinished 'did not finish'

run rel 'run_console_job stable app:thing' "STUB_NO_CONSOLE=1"
exited no-cronjob 1
refuse no-cronjob 'create job'
said no-cronjob 'CONSOLE JOB NOT RUN'

# The fixture load: a Job, then the flush in the API pod, then the warm (one pod: in the pod, on localhost).
run rel 'load_fixtures'
exited load 0
expect load '"value":["bin/console","doctrine:fixtures:load","--append","--no-interaction"]'
expect load '{"name":"SKIP_MERCURE_PUBLISH","value":"true"}'
refuse load 'doctrine:fixtures:load --append'
expect load 'exec -n ns pod/rel-cwa-new -- php bin/console silverback:api-components:purge-http-cache'
expect load 'exec -n ns pod/rel-cwa-new -- php bin/console silverback:api-components:warm-http-cache --base-url=http://localhost'
order load 'rollout status' 'create job'
order load 'create -n ns -f ' 'purge-http-cache'
order load 'purge-http-cache' 'warm-http-cache'

run rel 'load_fixtures' "CWA_CI_FIXTURES_PURGE=force"
expect purge '"value":["bin/console","doctrine:fixtures:load","--no-interaction"]'

run rel-review 'load_fixtures review' "CWA_CI_FIXTURES_PURGE=true"
expect review 'app.kubernetes.io/instance=rel-review -o name'
expect review '"value":["bin/console","doctrine:fixtures:load","--no-interaction"]'
expect review 'delete job -n ns rel-review-console-'

# A failed load stops before the flush and the warm.
run rel 'load_fixtures' "STUB_JOB_EXIT=1"
exited load-failed 1
refuse load-failed 'purge-http-cache'
refuse load-failed 'warm-http-cache'
said load-failed 'FIXTURES NOT LOADED'

run rel 'load_fixtures' "STUB_JOB_EXIT=1 GITHUB_ACTIONS=true"
said load-failed-github '::error title=Fixtures not loaded::'

# Scaled mode: the warm goes through the Service from two Jobs (gzip, then br), never an exec in an API pod.
run rel 'load_fixtures' "CWA_CI_API_SCALED_PRODUCTION=true"
exited scaled 0
expect scaled 'exec -n ns pod/rel-cwa-new -- php bin/console silverback:api-components:purge-http-cache'
expect scaled '"silverback:api-components:warm-http-cache","--base-url=http://rel-cwa","--concurrency=4","--requests-per-connection=1","--max-time=60","--no-interaction"]'
expect scaled '"--requests-per-connection=1","--accept-encoding=br","--max-time=60"'
refuse scaled 'exec -n ns pod/rel-cwa-new -- php bin/console silverback:api-components:warm-http-cache'
order scaled 'purge-http-cache' 'warm-http-cache'
if [ "$(grep -c 'create -n ns -f ' "$DIR/log")" -ne 3 ]; then
  fail scaled "expected 3 console Jobs (load, gzip, br), got $(grep -c 'create -n ns -f ' "$DIR/log")"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures checks failed." >&2
  exit 1
fi
echo "All checks passed."
