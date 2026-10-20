#!/bin/sh
# Chart check (#180): templates/database-job.yaml renders nothing by default, and every task it renders skips the
# entrypoint's migrate; the plan and backup are read-only. Needs helm (not in CI's php image), so it is run by hand.
# Usage (repository root): bin/test/database-job-chart.sh
set -eu

command -v helm >/dev/null 2>&1 || { echo "Needs helm." >&2; exit 2; }
DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT
cp -R helm/cwa "$DIR/cwa"
helm dependency build "$DIR/cwa" >/dev/null

render() {
  helm template rel "$DIR/cwa" --set mercure.publicUrl=https://x/.well-known/mercure "$@" --show-only templates/database-job.yaml 2>&1
}
failures=0
fail() { failures=$((failures + 1)); echo "FAIL ($1): $2" >&2; }

out=$(render) || true
case "$out" in *"could not find template"*) ;; *) fail off "rendered something without databaseJob.task: $out" ;; esac

for task in plan backup migrate; do
  out=$(render --set databaseJob.task=$task --set databaseJob.name=rel-db-$task --set databaseJob.backup.bucket=backups --set databaseJob.backup.gcloudJsonB64=a2V5 --set-string php.image.tag=main@sha256:new) \
    || { fail "$task" "did not render: $out"; continue; }
  printf '%s\n' "$out" | grep -A1 -- '- name: SKIP_MIGRATIONS' | grep -q '"true"' || fail "$task" "SKIP_MIGRATIONS is not true"
  printf '%s\n' "$out" | grep -q 'image: "chart-example.local/cwa/php:main@sha256:new"' || fail "$task" "not the given php image"
  printf '%s\n' "$out" | grep -q 'restartPolicy: Never' || fail "$task" "a failed Job would be retried"
  readonly_count=$(printf '%s\n' "$out" | grep -c 'default_transaction_read_only=on' || true)
  case "$task" in
    plan) [ "$readonly_count" = 1 ] || fail plan "the plan's session isn't read-only" ;;
    backup) [ "$readonly_count" = 2 ] || fail backup "pg_dump and the upload must both be read-only" ;;
    migrate) [ "$readonly_count" = 0 ] || fail migrate "the migrate Job can't be read-only" ;;
  esac
done

out=$(render --set databaseJob.task=backup --set databaseJob.name=x --set databaseJob.backup.gcloudJsonB64=a2V5) && fail no-bucket "a backup rendered without a bucket"
out=$(render --set databaseJob.task=backup --set databaseJob.name=x --set databaseJob.backup.bucket=backups) && fail no-key "a backup rendered without its key"

# The backup's own key: a Secret named after the Job, read as DATABASE_BACKUP_GCLOUD_JSON; other tasks have none.
out=$(render --set databaseJob.task=backup --set databaseJob.name=rel-db-backup-1 --set databaseJob.backup.bucket=backups --set databaseJob.backup.gcloudJsonB64=a2V5)
printf '%s\n' "$out" | grep -q '^kind: Secret' || fail backup-key "no Secret for the key"
printf '%s\n' "$out" | grep -q 'gcloud-json: "a2V5"' || fail backup-key "the Secret doesn't hold the key"
printf '%s\n' "$out" | grep -A3 -- '- name: DATABASE_BACKUP_GCLOUD_JSON' | grep -q 'name: rel-db-backup-1' || fail backup-key "the key isn't read from the Job's Secret"
out=$(render --set databaseJob.task=migrate --set databaseJob.name=x)
printf '%s\n' "$out" | grep -q 'kind: Secret\|DATABASE_BACKUP_GCLOUD_JSON' && fail migrate-key "a migrate Job got the backup key"

# A track on production's database (#180): every php workload skips migrating, and the Job doesn't repeat the name.
out=$(render --set databaseJob.task=plan --set databaseJob.name=x --set php.skipMigrations=true)
[ "$(printf '%s\n' "$out" | grep -c -- '- name: SKIP_MIGRATIONS')" = 1 ] || fail shared "SKIP_MIGRATIONS isn't set exactly once"
for template in deployment.yaml orphan-scan-cronjob.yaml image-variants-cronjob.yaml; do
  out=$(helm template rel "$DIR/cwa" --set mercure.publicUrl=https://x/.well-known/mercure --set php.skipMigrations=true \
    --set cronjobs.orphanScan.enabled=true --show-only "templates/$template" 2>&1)
  printf '%s\n' "$out" | grep -A1 -- '- name: SKIP_MIGRATIONS' | grep -q '"true"' || fail shared "$template doesn't skip migrations"
  out=$(helm template rel "$DIR/cwa" --set mercure.publicUrl=https://x/.well-known/mercure \
    --set cronjobs.orphanScan.enabled=true --show-only "templates/$template" 2>&1)
  printf '%s\n' "$out" | grep -q 'SKIP_MIGRATIONS' && fail default "$template skips migrations by default"
done
out=$(render --set databaseJob.task=drop --set databaseJob.name=x) && fail bad-task "an unknown task rendered"

if [ "$failures" -ne 0 ]; then
  echo "$failures checks failed." >&2
  exit 1
fi
echo "All checks passed."
