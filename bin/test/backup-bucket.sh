#!/bin/sh
# Test (#180): bin/devops/backup-bucket.sh creates the private backup bucket, its role, a project's managed folder,
# service account, folder-only grant and key, repeats safely, and its verify catches a key that reaches too far.
# Runs against a stub gcloud (and curl); never a real one. Usage (repository root): bin/test/backup-bucket.sh
set -eu

SCRIPT="$(pwd)/bin/devops/backup-bucket.sh"
[ -f "$SCRIPT" ] || { echo "Run from the repository root." >&2; exit 2; }
DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT
mkdir "$DIR/bin" "$DIR/state" "$DIR/tmp"

# gcloud: a bucket, role, folders, service accounts and keys kept as files in $STUB_STATE.
cat >"$DIR/bin/gcloud" <<'STUB'
#!/bin/sh
echo "gcloud $*" >>"$STUB_LOG"
S="$STUB_STATE"
arg() { for a; do case "$a" in --*) ;; *) printf '%s' "$a"; return ;; esac; done; }
case "$1 $2 $3" in
  "storage buckets describe")
    [ -f "$S/bucket" ] || exit 1
    case "$*" in *uniform_bucket_level_access*) printf 'True\tenforced\n' ;; *) echo silverback-db-backups ;; esac ;;
  "storage buckets create") touch "$S/bucket" ;;
  "storage buckets update")
    for a; do case "$a" in --lifecycle-file=*) cat "${a#--lifecycle-file=}" > "$S/lifecycle" ;; esac; done ;;
  "iam roles describe") [ -f "$S/role" ] || exit 1; echo "" ;;
  "iam roles create") touch "$S/role" ;;
  "iam roles update") ;;
  "storage managed-folders describe") [ -f "$S/folder-$(echo "$4" | tr / _)" ] || exit 1 ;;
  "storage managed-folders create") touch "$S/folder-$(echo "$4" | tr / _)" ;;
  "storage managed-folders add-iam-policy-binding")
    n=$(cat "$S/binding-tries" 2>/dev/null || echo 0); echo $((n + 1)) > "$S/binding-tries"
    [ "$n" -ge "${STUB_BINDING_FAILS:-0}" ] || exit 1 ;;
  "iam service-accounts describe") [ -f "$S/sa-$4" ] || exit 1 ;;
  "iam service-accounts create") touch "$S/sa-$4@silverback-web-apps.iam.gserviceaccount.com" ;;
  "iam service-accounts keys")
    case "$4" in
      list) cat "$S/keys" 2>/dev/null || true ;;
      create)
        printf '{\n  "type": "service_account",\n  "client_email": "x@y",\n  "private_key": "-----BEGIN PRIVATE KEY-----\\nk\\n-----END PRIVATE KEY-----\\n"\n}\n' > "$5"
        echo "projects/p/serviceAccounts/x/keys/$(date +%s)$$" >> "$S/keys" ;;
    esac ;;
  "storage cp -")
    grep -q '"private_key"' "${CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE:-/nonexistent}" || exit 1
    cat > /dev/null; echo "$4" > "$S/probe" ;;
  "storage ls "*)
    grep -q '"private_key"' "${CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE:-/nonexistent}" || exit 1
    case "$3" in
      gs://silverback-db-backups/site-a/verify/) cat "$S/probe" ;;
      *) [ -n "${STUB_OPEN:-}" ] || { echo "AccessDeniedException: 403" >&2; exit 1; } ;;
    esac ;;
  "storage rm "*) rm -f "$S/probe" ;;
esac
exit 0
STUB
cat >"$DIR/bin/curl" <<'STUB'
#!/bin/sh
echo "curl $*" >>"$STUB_LOG"
if [ -n "${STUB_PUBLIC:-}" ]; then printf 200; else printf 403; fi
STUB
chmod +x "$DIR/bin/gcloud" "$DIR/bin/curl"

run() {
  : >"$DIR/log"
  set +e
  env -i HOME="$DIR" PATH="$DIR/bin:/usr/bin:/bin" TMPDIR="$DIR/tmp" STUB_LOG="$DIR/log" STUB_STATE="$DIR/state" \
    CWA_BACKUP_RETRY_DELAY=0 $2 sh "$SCRIPT" $1 >"$DIR/out" 2>"$DIR/err"
  echo $? >"$DIR/status"
  set -e
}

failures=0
fail() { failures=$((failures + 1)); echo "FAIL ($1): $2" >&2; }
status() { [ "$(cat "$DIR/status")" = "$2" ] || { fail "$1" "exit $(cat "$DIR/status"), expected $2"; sed 's/^/    /' "$DIR/err" >&2; }; }
expect() { grep -qF -- "$2" "$DIR/log" || fail "$1" "no call containing: $2"; }
refuse() { if grep -qF -- "$2" "$DIR/log"; then fail "$1" "unexpected call containing: $2"; fi; }
said() { grep -qF -- "$2" "$DIR/err" || fail "$1" "no message containing: $2"; }
no_temp() { [ -z "$(ls -A "$DIR/tmp")" ] || fail "$1" "left files in TMPDIR: $(ls -A "$DIR/tmp")"; }

run "init" ""
status init 0
expect init "storage buckets create gs://silverback-db-backups --project=silverback-web-apps --location=europe-west2 --default-storage-class=STANDARD --uniform-bucket-level-access --public-access-prevention"
expect init "storage buckets update gs://silverback-db-backups --project=silverback-web-apps --uniform-bucket-level-access --public-access-prevention --lifecycle-file="
grep -qF '"action": {"type": "Delete"}, "condition": {"age": 90}' "$DIR/state/lifecycle" || fail init "no 90-day delete rule"
expect init "iam roles create cwaDatabaseBackup --project=silverback-web-apps"
expect init "--permissions=storage.objects.create,storage.objects.get,storage.objects.list,storage.objects.delete --stage=GA"
said init "CWA_CI_DATABASE_BACKUP_BUCKET=silverback-db-backups"
no_temp init

run "init" ""
status init-again 0
refuse init-again "buckets create"
refuse init-again "roles create"
expect init-again "buckets update"
expect init-again "iam roles update cwaDatabaseBackup --project=silverback-web-apps --permissions=storage.objects.create,storage.objects.get,storage.objects.list,storage.objects.delete"

run "project site-a" "STUB_BINDING_FAILS=2"
status project 0
expect project "storage managed-folders create gs://silverback-db-backups/site-a/"
expect project "iam service-accounts create db-backup-site-a --project=silverback-web-apps"
expect project "storage managed-folders add-iam-policy-binding gs://silverback-db-backups/site-a/ --member=serviceAccount:db-backup-site-a@silverback-web-apps.iam.gserviceaccount.com --role=projects/silverback-web-apps/roles/cwaDatabaseBackup"
refuse project "add-iam-policy-binding gs://silverback-db-backups "
refuse project "buckets add-iam-policy-binding"
refuse project "projects add-iam-policy-binding"
[ "$(wc -l < "$DIR/out" | tr -d ' ')" = 1 ] || fail project "stdout isn't one line"
base64 -d < "$DIR/out" 2>/dev/null | grep -q '"private_key"' || fail project "stdout isn't the key's base64"
said project "CWA_CI_DATABASE_BACKUP_GCLOUD_JSON"
no_temp project
cp "$DIR/out" "$DIR/key.b64"

run "project site-a --no-key" ""
status project-again 0
refuse project-again "managed-folders create"
refuse project-again "service-accounts create"
refuse project-again "keys create"
expect project-again "add-iam-policy-binding"

run "project site-a --output $DIR/key.out" ""
status output 0
said output "already has 1 key(s)"
[ ! -s "$DIR/out" ] || fail output "printed the key although --output was given"
base64 -d < "$DIR/key.out" | grep -q '"private_key"' || fail output "the file isn't the key's base64"
case "$(ls -l "$DIR/key.out")" in -rw-------*) ;; *) fail output "the key file isn't private: $(ls -l "$DIR/key.out")" ;; esac

run "project silverback-web-apps-cwa-components-web-app --no-key" ""
status long-slug 0
id=$(sed -n 's/.*iam service-accounts create \([^ ]*\) .*/\1/p' "$DIR/log")
[ "${#id}" -le 30 ] && printf '%s' "$id" | grep -Eq '^db-backup-silverback-we-[0-9a-f]{6}$' || fail long-slug "service account id '$id'"
expect long-slug "managed-folders create gs://silverback-db-backups/silverback-web-apps-cwa-components-web-app/"

for bad in Site-A site_a -site site- ""; do
  run "project $bad" ""
  [ "$(cat "$DIR/status")" != 0 ] || fail "bad-slug '$bad'" "accepted"
done
refuse bad-slug "create"

rm -f "$DIR/state/bucket"
run "project site-b" ""
status no-bucket 1
said no-bucket "run"
refuse no-bucket "managed-folders create"
touch "$DIR/state/bucket"

run "verify site-a $DIR/key.b64" ""
status verify 0
said verify "works for gs://silverback-db-backups/site-a/ only"
no_temp verify

run "verify site-a $DIR/key.b64" "STUB_OPEN=1"
status verify-open 1
said verify-open "FAIL the key can list outside"

run "verify site-a $DIR/key.b64" "STUB_PUBLIC=1"
status verify-public 1
said verify-public "FAIL anonymous read answered 200"

if [ "$failures" -ne 0 ]; then
  echo "$failures checks failed." >&2
  exit 1
fi
echo "All checks passed."
