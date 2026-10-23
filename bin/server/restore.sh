#!/bin/sh
# Restores a bin/server/backup.sh backup (#212): the database and media, under the bundle's maintenance mode.
# Usage: bin/server/restore.sh [<backup time, e.g. 20261024T031500Z>, default the newest] [--certificates] [--yes]
#   --certificates  also restores Caddy's data (TLS certificates), for a new server taking over the site.
#   --yes           doesn't ask for confirmation.
# Everything since the backup is lost: the database and media are replaced, not merged.
set -eu

cd "$(dirname "$0")/../.."
. ./bin/server/lib.sh
require_env_file
dir=${CWA_SERVER_BACKUP_DIR:-backups}
stamp="" certificates=false yes=false
for arg in "$@"; do
  case "$arg" in
    --certificates) certificates=true ;;
    --yes) yes=true ;;
    -*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) stamp=$arg ;;
  esac
done
[ -n "$stamp" ] || stamp=$(ls -1 "$dir" 2>/dev/null | sed -n 's/^\([0-9]\{8\}T[0-9]\{6\}Z\)-database\.dump$/\1/p' | sort -r | head -n 1)
[ -n "$stamp" ] && [ -f "$dir/$stamp-database.dump" ] && [ -f "$dir/$stamp-media.tar.gz" ] \
  || { echo "No complete backup ${stamp:+$stamp }in $dir/." >&2; exit 1; }
SITE_HOST=$(env_value SITE_HOST)

if [ "$yes" != "true" ]; then
  echo "This replaces $SITE_HOST's database and media with backup $stamp. Everything since then is lost."
  printf 'Type the site host (%s) to go on: ' "$SITE_HOST"
  read -r answer
  [ "$answer" = "$SITE_HOST" ] || { echo "Not restored."; exit 1; }
fi

c up -d --wait --no-build database php
echo "➡️ Maintenance on..."
c exec -T php bin/console silverback:api-components:maintenance on
echo "➡️ Restoring the database..."
c exec -T database sh -c 'exec pg_restore -U "$POSTGRES_USER" -d "${POSTGRES_DB:-$POSTGRES_USER}" --clean --if-exists --no-owner --single-transaction' \
  < "$dir/$stamp-database.dump"
# Maintenance mode is a site setting, so the restored database brought the backup's back: turn it on again.
c exec -T php bin/console silverback:api-components:maintenance on
echo "➡️ Restoring media..."
c exec -T php sh -c 'find /app/public/uploads -mindepth 1 -delete && exec tar -xzf - -C /app/public/uploads' < "$dir/$stamp-media.tar.gz"
if [ "$certificates" = "true" ]; then
  echo "➡️ Restoring Caddy's data..."
  c exec -T php sh -c 'exec tar -xzf - -C /data' < "$dir/$stamp-caddy-data.tar.gz"
fi
# The restored database may be at an older migration than this checkout, and php migrates as it starts: restart it.
c restart php
c up -d --wait --no-build php
c exec -T php bin/console silverback:api-components:purge-http-cache
echo "➡️ Maintenance off..."
c exec -T php bin/console silverback:api-components:maintenance off
echo "✅ Restored backup $stamp."
