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
  out=$(render --set databaseJob.task=$task --set databaseJob.name=rel-db-$task --set databaseJob.backup.bucket=backups --set-string php.image.tag=main@sha256:new) \
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

out=$(render --set databaseJob.task=backup --set databaseJob.name=x) && fail no-bucket "a backup rendered without a bucket"
out=$(render --set databaseJob.task=drop --set databaseJob.name=x) && fail bad-task "an unknown task rendered"

if [ "$failures" -ne 0 ]; then
  echo "$failures checks failed." >&2
  exit 1
fi
echo "All checks passed."
