#!/bin/sh
# Regression test (#180): the deploy's migrations plan, backup, migrate Job and maintenance window run in order, only when
# switched on and migrations are pending, and a failure stops before the rollout with maintenance left on.
# Runs k8s.sh against stub kubectl and helm. Usage (repository root): bin/test/database-guard.sh [k8s.sh]
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
mkdir "$DIR/bin" "$DIR/work"
# helm: the live release's values (none with STUB_NO_RELEASE), and a "manifest" that is the render's arguments.
cat >"$DIR/bin/helm" <<'STUB'
#!/bin/sh
echo "helm $*" >>"$STUB_LOG"
case "$1 $2" in
  "get values") [ -z "${STUB_NO_RELEASE:-}" ] || { echo "Error: release: not found" >&2; exit 1; }; echo "php: {}" ;;
  "template "*)
    echo "# rendered: $*"
    prev=""; for a; do [ "$prev" = "-f" ] && cat "$a" >>"$STUB_LOG.values"; prev="$a"; done ;;
esac
exit 0
STUB
# kubectl: Jobs finish at once; a task in STUB_FAIL fails. Plan logs report STUB_PENDING migrations on PostgreSQL 14.13.
cat >"$DIR/bin/kubectl" <<'STUB'
#!/bin/sh
echo "kubectl $*" >>"$STUB_LOG"
task() { case "$*" in *-db-plan-*) echo plan ;; *-db-backup-*) echo backup ;; *-db-migrate-*) echo migrate ;; esac; }
failed() { case " ${STUB_FAIL:-} " in *" $(task "$@") "*) return 0 ;; esac; return 1; }
case "$*" in
  *"get configmap"*maintenance-window*) [ -n "${STUB_MARKER:-}" ] || exit 1 ;;
  "create configmap"*) [ -z "${STUB_MARKER_FAIL:-}" ] || exit 1 ;;
  "create "*) cat "$4" >>"$STUB_LOG" ;;
  *"get job"*"succeeded}{.status.failed}"*) echo 1 ;;
  *"get job"*"status.succeeded}"*) failed "$@" || echo 1 ;;
  "logs "*)
    case "$(task "$@")" in
      plan) printf 'Out-of-date!\nALTER TABLE x;\nCWA_DATABASE_SERVER_VERSION=14.13\nCWA_MIGRATIONS_PENDING=%s\n' "${STUB_PENDING:-2}"
        [ -z "${STUB_PLAN_INCOMPLETE:-}" ] || echo "CWA_MIGRATIONS_PLAN_INCOMPLETE=1" ;;
      backup) failed "$@" || echo "CWA_DATABASE_BACKUP=gs://backups/group-site/production/rel/20261020-000000Z-abc.dump" ;;
      migrate) echo "migrated" ;;
    esac ;;
  *"get deploy"*"name=cwa,"*) echo "deployment.apps/rel-cwa" ;;
  *"maintenance status"*) echo "${STUB_MAINTENANCE:-off}"; exit "${STUB_MAINTENANCE_EXIT:-0}" ;;
esac
exit 0
STUB
chmod +x "$DIR/bin/helm" "$DIR/bin/kubectl"

# run <function call> <settings>: in a fresh shell, from $DIR/work, output in $DIR/out, status in $DIR/status.
case "$K8S" in /*) ;; *) K8S="$(pwd)/$K8S" ;; esac
run() {
  : >"$DIR/log"
  : >"$DIR/log.values"
  rm -f "$DIR/work/maintenance-window.txt"
  set +e
  (cd "$DIR/work" && PATH="$DIR/bin:$PATH" STUB_LOG="$DIR/log" RELEASE=rel KUBE_NAMESPACE=ns $K8S_SHELL -c '
    unset CWA_CI_DATABASE_BACKUP_PRODUCTION CWA_CI_DATABASE_BACKUP_STAGING CWA_CI_MIGRATIONS_JOB_DISABLED CWA_CI_MIGRATIONS_JOB_PRODUCTION \
      CWA_CI_MAINTENANCE_DURING_MIGRATIONS CWA_CI_DATABASE_BACKUP_BUCKET GCLOUD_BUCKET GCLOUD_PATH_PREFIX \
      CWA_CI_API_SCALED_PRODUCTION CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME STUB_FAIL STUB_PENDING STUB_NO_RELEASE \
      STUB_MAINTENANCE STUB_MAINTENANCE_EXIT STUB_MARKER STUB_MARKER_FAIL STUB_PLAN_INCOMPLETE CWA_CI_DATABASE_BACKUP_STORAGE CWA_CI_DATABASE_BACKUP_IMAGE CWA_CI_DATABASE_BACKUP_FOLDER GITHUB_REPOSITORY \
      PHP_IMAGE_TAG GCLOUD_JSON
    export CWA_CI_DATABASE_BACKUP_GCLOUD_JSON="$4" CI_PROJECT_PATH_SLUG=group-site TAG=main
    for setting in $3; do export "$setting"; done
    . "$1" >/dev/null
    export CWA_CI_DATABASE_JOB_POLL=0 CI_COMMIT_SHORT_SHA=abc1234
    image_digest() { printf "sha256:new"; }
    eval "$2"' k8s "$K8S" "$1" "$2" "$KEY_B64") >"$DIR/out" 2>&1
  echo $? >"$DIR/status"
  set -e
}

# A backup service account key, as the CI variable holds it: the key JSON, base64-encoded.
KEY_JSON='{"type": "service_account", "client_email": "db-backup@p.iam.gserviceaccount.com", "private_key": "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----\\n"}'
KEY_B64=$(printf '%s' "$KEY_JSON" | base64 | tr -d '\n')

failures=0
fail() { failures=$((failures + 1)); echo "FAIL ($1): $2" >&2; }
status() { [ "$(cat "$DIR/status")" = "$2" ] || { fail "$1" "exit $(cat "$DIR/status"), expected $2"; sed 's/^/    /' "$DIR/out" >&2; }; }
expect() { grep -qF -- "$2" "$DIR/log" || fail "$1" "no call containing: $2"; }
refuse() { if grep -qF -- "$2" "$DIR/log"; then fail "$1" "unexpected call containing: $2"; fi; }
said() { grep -qF -- "$2" "$DIR/out" || fail "$1" "no output containing: $2"; }
order() {
  first=$(grep -nF -- "$2" "$DIR/log" | head -1 | cut -d: -f1)
  second=$(grep -nF -- "$3" "$DIR/log" | head -1 | cut -d: -f1)
  if [ -z "$first" ] || [ -z "$second" ] || [ "$first" -ge "$second" ]; then fail "$1" "'$2' must come before '$3'"; fi
}

# Production migrates in a Job by default (#180): with migrations pending, the plan then the migrate Job.
run "database_guard stable" ""
status default 0
order default "databaseJob.task=plan" "databaseJob.task=migrate"
refuse default "databaseJob.task=backup"

# CWA_CI_MIGRATIONS_JOB_DISABLED turns it off: nothing but the marker check.
run "database_guard stable" "CWA_CI_MIGRATIONS_JOB_DISABLED=true"
status off 0
refuse off "helm"
expect off "kubectl get configmap -n ns rel-cwa-maintenance-window"
refuse off "maintenance status"

run "database_guard stable" "CWA_CI_DATABASE_BACKUP_PRODUCTION=true"
status no-bucket 1
said no-bucket "needs CWA_CI_DATABASE_BACKUP_BUCKET"
refuse no-bucket "kubectl"

run "database_guard stable" "CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=media GCLOUD_BUCKET=media"
status media-bucket 1
refuse media-bucket "kubectl"

run "database_guard stable" "CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=backups CWA_CI_DATABASE_BACKUP_GCLOUD_JSON="
status no-key 1
said no-key "needs CWA_CI_DATABASE_BACKUP_GCLOUD_JSON"
refuse no-key "kubectl"

run "database_guard stable" "CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=backups CWA_CI_DATABASE_BACKUP_GCLOUD_JSON=bm90IGEga2V5"
status bad-key 1
said bad-key "isn't a service account key"
refuse bad-key "kubectl"

# The media service account can't take backups.
run "database_guard stable" 'CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=backups GCLOUD_JSON={"client_email":"db-backup@p.iam.gserviceaccount.com"}'
status media-key 1
said media-key "is the media key"
refuse media-key "kubectl"

# GitHub: the folder is owner/repo as a slug; CWA_CI_DATABASE_BACKUP_FOLDER overrides it.
run "database_backup_location staging" "CWA_CI_DATABASE_BACKUP_BUCKET=backups CI_PROJECT_PATH_SLUG= GITHUB_REPOSITORY=Org/My.Repo"
said github-folder "backups org-my-repo/staging/rel-staging/"
run "database_backup_location stable" "CWA_CI_DATABASE_BACKUP_BUCKET=backups CWA_CI_DATABASE_BACKUP_FOLDER=shared-site"
said folder-override "backups shared-site/production/rel/"

run "database_guard stable" "CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_MIGRATIONS_JOB_DISABLED=true CWA_CI_DATABASE_BACKUP_BUCKET=backups GCLOUD_PATH_PREFIX=site-a"
status backup 0
expect backup "helm get values rel -n ns -o yaml"
expect backup "--set-string php.image.tag=main@sha256:new --set-string databaseJob.task=plan"
expect backup "databaseJob.backup.image=postgres:14-alpine"
expect backup "databaseJob.backup.bucket=backups"
expect backup "databaseJob.backup.directory=group-site/production/rel/"
grep -qF "gcloudJsonB64: \"$KEY_B64\"" "$DIR/log.values" || fail backup "the key isn't in the Job's values file"
refuse backup "$KEY_B64"
expect backup "kubectl delete secret -n ns rel-db-backup-"
expect backup "databaseJob.backup.label=abc1234"
order backup "databaseJob.task=plan" "databaseJob.task=backup"
refuse backup "databaseJob.task=migrate"
refuse backup "silverback:api-components:maintenance"
refuse backup "databaseJob.backup.storage"
said backup "Database backup: gs://backups/"

# A migration writing from up(): the plan can't show its SQL, but the deploy still backs up and migrates (#183).
run "database_guard stable" "CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=backups STUB_PLAN_INCOMPLETE=1 CWA_CI_DATABASE_BACKUP_STORAGE=20Gi"
status plan-incomplete 0
said plan-incomplete "so the plan shows no SQL"
order plan-incomplete "databaseJob.task=backup" "databaseJob.task=migrate"
expect plan-incomplete "databaseJob.backup.storage=20Gi"

run "database_guard stable" "CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=backups STUB_PENDING=0"
status up-to-date 0
expect up-to-date "databaseJob.task=plan"
refuse up-to-date "databaseJob.task=backup"

run "database_guard stable" "CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=backups STUB_NO_RELEASE=1"
status first-deploy 0
refuse first-deploy "kubectl create"

run "database_guard stable" "CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=backups STUB_FAIL=backup"
status backup-fails 1
said backup-fails "DATABASE BACKUP FAILED"
refuse backup-fails "databaseJob.task=migrate"

run "database_guard stable" ""
status migrate-job 0
order migrate-job "databaseJob.task=plan" "databaseJob.task=migrate"
refuse migrate-job "databaseJob.task=backup"

# The maintenance window, then its end after the rollout, in one shell as in the deploy job.
run "database_guard stable && finish_maintenance_window stable" "CWA_CI_MAINTENANCE_DURING_MIGRATIONS=true CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=backups"
status window 0
order window "databaseJob.task=plan" "maintenance status"
order window "maintenance status" "maintenance on"
order window "maintenance on" "databaseJob.task=backup"
order window "databaseJob.task=backup" "databaseJob.task=migrate"
order window "databaseJob.task=migrate" "purge-http-cache"
order window "purge-http-cache" "warm-http-cache"
order window "warm-http-cache" "maintenance off"
order window "create configmap -n ns rel-cwa-maintenance-window" "maintenance on"
order window "maintenance off" "delete configmap -n ns rel-cwa-maintenance-window"
said window "Maintenance mode is off."
[ ! -f "$DIR/work/maintenance-window.txt" ] || fail window "the notice was left behind"

run "database_guard stable" "CWA_CI_MAINTENANCE_DURING_MIGRATIONS=true CWA_CI_DATABASE_BACKUP_PRODUCTION=true CWA_CI_DATABASE_BACKUP_BUCKET=backups STUB_FAIL=migrate"
status window-fails 1
expect window-fails "maintenance on"
refuse window-fails "maintenance off"
said window-fails "MIGRATIONS FAILED"
said window-fails "MAINTENANCE MODE IS ON"
said window-fails "gs://backups/group-site/production/rel/20261020-000000Z-abc.dump"
said window-fails "kubectl exec -i -n ns rel-postgresql-0 -c postgresql -- sh -c"
said window-fails '-U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DATABASE:-postgres}"'
said window-fails "silverback:api-components:maintenance off"
said window-fails "kubectl delete configmap -n ns rel-cwa-maintenance-window"
refuse window-fails "delete configmap"
grep -qF "deploy/" "$DIR/out" && fail window-fails "the notice names deploy/..., which can pick a terminating pod"
grep -qF "maintenance off" "$DIR/work/maintenance-window.txt" 2>/dev/null || fail window-fails "no notice for the job's after_script"

# A window without a backup still runs, with a warning (Daniel, 2026-10-20).
run "database_guard stable && finish_maintenance_window stable" "CWA_CI_MAINTENANCE_DURING_MIGRATIONS=true"
status window-no-backup 0
order window-no-backup "maintenance on" "databaseJob.task=migrate"
refuse window-no-backup "databaseJob.task=backup"
said window-no-backup "takes no database backup"
expect window-no-backup "maintenance off"

run "database_guard stable" "CWA_CI_MAINTENANCE_DURING_MIGRATIONS=true STUB_MAINTENANCE_EXIT=1"
status no-command 1
refuse no-command "maintenance on"
refuse no-command "databaseJob.task=migrate"

run "database_guard staging" "CWA_CI_MAINTENANCE_DURING_MIGRATIONS=true"
status staging 0
said staging "for production only"
refuse staging "kubectl"

# A retry after the migrations ran: nothing pending, maintenance still on, so this deploy ends the window.
run "database_guard stable && finish_maintenance_window stable" "CWA_CI_MAINTENANCE_DURING_MIGRATIONS=true STUB_PENDING=0 STUB_MAINTENANCE=on"
status retry 0
refuse retry "maintenance on"
refuse retry "databaseJob.task=migrate"
expect retry "maintenance off"

# No marker, no window: maintenance stays off rather than start a window a later deploy couldn't find (#182).
run "database_guard stable" "CWA_CI_MAINTENANCE_DURING_MIGRATIONS=true STUB_MARKER_FAIL=1"
status no-marker 1
refuse no-marker "maintenance on"
refuse no-marker "databaseJob.task=migrate"
[ ! -f "$DIR/work/maintenance-window.txt" ] || fail no-marker "a notice for a window that never started"

# A window left on by a failed deploy: a later production deploy without the switch still ends it (#182).
run "database_guard stable && finish_maintenance_window stable" "STUB_MARKER=1 CWA_CI_MIGRATIONS_JOB_DISABLED=true"
status left-on 0
said left-on "still on from an earlier deploy's failed window"
refuse left-on "helm"
refuse left-on "maintenance on"
order left-on "purge-http-cache" "maintenance off"
order left-on "maintenance off" "delete configmap -n ns rel-cwa-maintenance-window"

# Likewise when the later deploy has other switches and migrations pending.
run "database_guard stable && finish_maintenance_window stable" "STUB_MARKER=1"
status left-on-migrate 0
order left-on-migrate "databaseJob.task=migrate" "maintenance off"

# Staging never ends production's window.
run "database_guard staging && finish_maintenance_window staging" "STUB_MARKER=1"
status left-on-staging 0
refuse left-on-staging "maintenance off"

run "migrations_plan stable" ""
status plan 0
said plan "2 migration(s) pending for 'rel' (PostgreSQL 14.13)"
said plan "ALTER TABLE x;"
refuse plan "databaseJob.task=backup"

run "migrations_plan stable" "STUB_FAIL=plan"
status plan-fails 1
said plan-fails "MIGRATIONS PLAN FAILED"

if [ "$failures" -ne 0 ]; then
  echo "$failures checks failed." >&2
  exit 1
fi
echo "All checks passed."
