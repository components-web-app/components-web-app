#!/bin/sh
# Backs up a single-server site (#212): the database (pg_dump -Fc, checked with pg_restore --list), the media volume and
# Caddy's data (its TLS certificates) into backups/<UTC time>-*, keeping the newest CWA_SERVER_BACKUP_KEEP (5).
# A backup on the server's own disk dies with the disk: copy backups/ somewhere else (bin/server/cron.example).
# Usage: bin/server/backup.sh. Restore with bin/server/restore.sh.
set -eu

cd "$(dirname "$0")/../.."
. ./bin/server/lib.sh
require_env_file
dir=${CWA_SERVER_BACKUP_DIR:-backups}
keep=${CWA_SERVER_BACKUP_KEEP:-5}
stamp=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$dir"
chmod 700 "$dir"
umask 077

echo "➡️ Dumping the database..."
c exec -T database sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "${POSTGRES_DB:-$POSTGRES_USER}" --format=custom' > "$dir/$stamp-database.dump.part"
c exec -T database pg_restore --list < "$dir/$stamp-database.dump.part" > /dev/null \
  || { rm -f "$dir/$stamp-database.dump.part"; echo "❌ The dump doesn't read back (pg_restore --list): no backup written." >&2; exit 1; }
mv "$dir/$stamp-database.dump.part" "$dir/$stamp-database.dump"

# From one-off containers on the same volumes, so php needn't be running.
echo "➡️ Archiving media and Caddy's data..."
c run --rm --no-deps -T --entrypoint tar php -czf - -C /app/public/uploads . > "$dir/$stamp-media.tar.gz"
c run --rm --no-deps -T --entrypoint tar php -czf - -C /data . > "$dir/$stamp-caddy-data.tar.gz"

# The newest $keep backups; only names in this script's form are ever deleted.
ls -1 "$dir" | sed -n 's/^\([0-9]\{8\}T[0-9]\{6\}Z\)-database\.dump$/\1/p' | sort -r | sed "1,${keep}d" | while read -r old; do
  rm -f "$dir/$old-database.dump" "$dir/$old-media.tar.gz" "$dir/$old-caddy-data.tar.gz"
  echo "Removed backup $old."
done
echo "✅ Backup $stamp in $dir/ ($(du -ch "$dir/$stamp"-* | tail -n 1 | cut -f1))."
