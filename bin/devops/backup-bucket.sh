#!/bin/sh
# The shared private bucket for Silverback's database backups (#180), one managed folder and service account per
# project. Run by a person with an authenticated gcloud, never by CI. Every command is safe to repeat.
#
#   bin/devops/backup-bucket.sh init
#       The bucket (uniform access, public access prevention, objects deleted after 90 days) and the custom role.
#   bin/devops/backup-bucket.sh project <project-slug> [--output FILE] [--no-key]
#       The managed folder <project-slug>/, its service account with the role on that folder only, and a new key,
#       printed (or written to FILE) as one base64 line: the project's CWA_CI_DATABASE_BACKUP_GCLOUD_JSON.
#   bin/devops/backup-bucket.sh verify <project-slug> <key file>
#       With that key: writes, lists and deletes a test object in the folder, and checks it can't reach the rest of
#       the bucket and that nobody can read it anonymously.
#
# <project-slug> is GitLab's CI_PROJECT_PATH_SLUG (e.g. silverback-web-apps-cwa-components-web-app), or GitHub's
# owner/repo lower-cased with every other character a dash: the folder the deploy writes to (database_backup_folder).
set -eu

GCP_PROJECT="${CWA_BACKUP_GCP_PROJECT:-silverback-web-apps}"
BUCKET="${CWA_BACKUP_BUCKET:-silverback-db-backups}"
LOCATION="${CWA_BACKUP_LOCATION:-europe-west2}"
RETENTION_DAYS=90
ROLE_ID=cwaDatabaseBackup
ROLE="projects/$GCP_PROJECT/roles/$ROLE_ID"
# Upload, the size check, keep-N's listing and deleting: nothing on the bucket itself, nothing on IAM.
ROLE_PERMISSIONS="storage.objects.create,storage.objects.get,storage.objects.list,storage.objects.delete"

say() { printf '%s\n' "$*" >&2; }
die() { say "ERROR: $*"; exit 1; }

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

command -v gcloud >/dev/null 2>&1 || die "Needs gcloud, signed in (gcloud auth login) as someone who can manage $GCP_PROJECT."

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -c1-64; else shasum -a 256 | cut -c1-64; fi
}

check_slug() {
  printf '%s' "$1" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$' \
    || die "'$1' isn't a project slug (lower-case letters, digits and dashes, at most 63; e.g. CI_PROJECT_PATH_SLUG)."
}

# The service account id: db-backup-<slug>, or a shortened slug plus a hash when that's over 30 characters.
service_account_id() {
  local id="db-backup-$1"
  if [ "${#id}" -gt 30 ]; then
    id="db-backup-$(printf '%s' "$1" | cut -c1-13 | sed 's/-*$//')-$(printf '%s' "$1" | sha256 | cut -c1-6)"
  fi
  printf '%s' "$id"
}

bucket_exists() {
  gcloud storage buckets describe "gs://$BUCKET" --project="$GCP_PROJECT" --format='value(name)' >/dev/null 2>&1
}

cmd_init() {
  local lifecycle settings
  if bucket_exists; then
    say "Bucket gs://$BUCKET exists."
  else
    say "Creating gs://$BUCKET in $GCP_PROJECT ($LOCATION)..."
    gcloud storage buckets create "gs://$BUCKET" --project="$GCP_PROJECT" --location="$LOCATION" \
      --default-storage-class=STANDARD --uniform-bucket-level-access --public-access-prevention >&2
  fi
  lifecycle=$(mktemp)
  printf '{"lifecycle": {"rule": [{"action": {"type": "Delete"}, "condition": {"age": %s}}]}}\n' "$RETENTION_DAYS" > "$lifecycle"
  # Again on an existing bucket, so the settings are always these.
  gcloud storage buckets update "gs://$BUCKET" --project="$GCP_PROJECT" \
    --uniform-bucket-level-access --public-access-prevention --lifecycle-file="$lifecycle" >&2 \
    || { rm -f "$lifecycle"; die "Could not update gs://$BUCKET."; }
  rm -f "$lifecycle"
  settings=$(gcloud storage buckets describe "gs://$BUCKET" --project="$GCP_PROJECT" \
    --format='value(uniform_bucket_level_access,public_access_prevention)' | tr '[:upper:]' '[:lower:]')
  case "$settings" in
    *true*enforced*) say "gs://$BUCKET: uniform bucket-level access on, public access prevention enforced, objects deleted after $RETENTION_DAYS days." ;;
    *) die "gs://$BUCKET doesn't report uniform access and enforced public access prevention: '$settings'." ;;
  esac

  local role
  role=$(gcloud iam roles describe "$ROLE_ID" --project="$GCP_PROJECT" --format='value(deleted)' 2>/dev/null) || role=missing
  case "$(printf '%s' "$role" | tr '[:upper:]' '[:lower:]')" in
    missing)
      say "Creating the role $ROLE..."
      gcloud iam roles create "$ROLE_ID" --project="$GCP_PROJECT" --title="CWA database backup" \
        --description="Write, list and delete database backups in one managed folder of gs://$BUCKET (components-web-app #180)." \
        --permissions="$ROLE_PERMISSIONS" --stage=GA >&2 ;;
    true)
      say "Restoring the deleted role $ROLE..."
      gcloud iam roles undelete "$ROLE_ID" --project="$GCP_PROJECT" >&2
      gcloud iam roles update "$ROLE_ID" --project="$GCP_PROJECT" --permissions="$ROLE_PERMISSIONS" >&2 ;;
    *)
      gcloud iam roles update "$ROLE_ID" --project="$GCP_PROJECT" --permissions="$ROLE_PERMISSIONS" >&2 ;;
  esac
  say "Role $ROLE: $ROLE_PERMISSIONS."
  say "Done. Set CWA_CI_DATABASE_BACKUP_BUCKET=$BUCKET once on the GitLab group (or as a GitHub organisation variable)."
}

cmd_project() {
  local slug="$1" output="" key=true sa email keys json value attempt
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --output) [ $# -ge 2 ] || usage; output="$2"; shift 2 ;;
      --output=*) output="${1#--output=}"; shift ;;
      --no-key) key=false; shift ;;
      *) usage ;;
    esac
  done
  check_slug "$slug"
  bucket_exists || die "No gs://$BUCKET: run '$0 init' first."

  if gcloud storage managed-folders describe "gs://$BUCKET/$slug/" >/dev/null 2>&1; then
    say "Managed folder gs://$BUCKET/$slug/ exists."
  else
    say "Creating the managed folder gs://$BUCKET/$slug/..."
    gcloud storage managed-folders create "gs://$BUCKET/$slug/" >&2
  fi

  sa=$(service_account_id "$slug")
  email="$sa@$GCP_PROJECT.iam.gserviceaccount.com"
  if gcloud iam service-accounts describe "$email" --project="$GCP_PROJECT" >/dev/null 2>&1; then
    say "Service account $email exists."
  else
    say "Creating the service account $email..."
    gcloud iam service-accounts create "$sa" --project="$GCP_PROJECT" \
      --display-name="DB backups: $(printf '%s' "$slug" | cut -c1-80)" \
      --description="Database backups for $slug, in gs://$BUCKET/$slug/ only (components-web-app #180)." >&2
  fi

  # A new service account can take a few seconds to be usable in a policy.
  for attempt in 1 2 3 4 5 6; do
    if gcloud storage managed-folders add-iam-policy-binding "gs://$BUCKET/$slug/" \
        --member="serviceAccount:$email" --role="$ROLE" >/dev/null 2>&1; then
      break
    fi
    [ "$attempt" != 6 ] || die "Could not grant $ROLE on gs://$BUCKET/$slug/ to $email (did '$0 init' create the role?)."
    sleep "${CWA_BACKUP_RETRY_DELAY:-5}"
  done
  say "Granted $ROLE on gs://$BUCKET/$slug/ (and nothing else) to $email."

  [ "$key" = "true" ] || { say "No key created (--no-key)."; return 0; }
  keys=$(gcloud iam service-accounts keys list --iam-account="$email" --project="$GCP_PROJECT" --managed-by=user --format='value(name)' 2>/dev/null | grep -c . || true)
  [ "${keys:-0}" -eq 0 ] || say "WARNING: $email already has $keys key(s). Delete the old one once CI uses the new key: gcloud iam service-accounts keys list --iam-account=$email"
  json=$(mktemp)
  # The key JSON never stays on disk: base64 in one line (maskable on GitLab), then removed.
  if ! gcloud iam service-accounts keys create "$json" --iam-account="$email" --project="$GCP_PROJECT" >/dev/null 2>&1; then
    rm -f "$json"
    die "Could not create a key for $email (an organisation policy may forbid service account keys)."
  fi
  value=$(base64 < "$json" | tr -d '\n')
  rm -f "$json"
  if [ -n "$output" ]; then
    (umask 077 && printf '%s\n' "$value" > "$output")
    say "Wrote the key (base64) to $output. Delete it once it is in CI."
  else
    printf '%s\n' "$value"
  fi
  say ""
  say "Set on the project (GitLab: Settings > CI/CD > Variables; GitHub: a repository secret):"
  say "  CWA_CI_DATABASE_BACKUP_GCLOUD_JSON = that base64 line (GitLab: Masked and hidden, Protected; all environments)"
  say "  CWA_CI_DATABASE_BACKUP_<TRACK>=true (e.g. PRODUCTION) to back up before migrating."
  say "The deploy writes to gs://$BUCKET/$slug/<track>/<release>/ (CWA_CI_DATABASE_BACKUP_FOLDER=$slug if the project's slug differs)."
}

cmd_verify() {
  local slug="$1" keyfile="$2" json probe other code
  check_slug "$slug"
  [ -f "$keyfile" ] || die "No key file $keyfile."
  json=$(mktemp)
  case "$(head -c1 "$keyfile")" in
    '{') cat "$keyfile" > "$json" ;;
    *) tr -d ' \n\r' < "$keyfile" | base64 -d > "$json" 2>/dev/null || { rm -f "$json"; die "$keyfile is neither key JSON nor its base64."; } ;;
  esac
  probe="gs://$BUCKET/$slug/verify/$(date -u +%Y%m%d-%H%M%S).txt"
  as_key() { CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE="$json" gcloud "$@"; }
  local failed=0
  if printf 'backup-bucket.sh verify\n' | as_key storage cp - "$probe" >/dev/null 2>&1; then say "ok   write $probe"; else say "FAIL write $probe"; failed=1; fi
  if as_key storage ls "gs://$BUCKET/$slug/verify/" 2>/dev/null | grep -qF "$probe"; then say "ok   list gs://$BUCKET/$slug/verify/"; else say "FAIL list gs://$BUCKET/$slug/verify/"; failed=1; fi
  code=$(curl -s -o /dev/null -w '%{http_code}' "https://storage.googleapis.com/$BUCKET/${probe#gs://$BUCKET/}" || true)
  case "$code" in 401|403) say "ok   anonymous read refused ($code)" ;; *) say "FAIL anonymous read answered $code"; failed=1 ;; esac
  if as_key storage rm "$probe" >/dev/null 2>&1; then say "ok   delete $probe"; else say "FAIL delete $probe"; failed=1; fi
  other="gs://$BUCKET/verify-outside-$slug/"
  if as_key storage ls "$other" >/dev/null 2>&1 || as_key storage ls "gs://$BUCKET/" >/dev/null 2>&1; then
    say "FAIL the key can list outside gs://$BUCKET/$slug/"; failed=1
  else
    say "ok   no access outside gs://$BUCKET/$slug/"
  fi
  rm -f "$json"
  [ "$failed" -eq 0 ] || die "The key can't do exactly what the backup needs."
  say "The key works for gs://$BUCKET/$slug/ only."
}

case "${1:-}" in
  init) [ $# -eq 1 ] || usage; cmd_init ;;
  project) [ $# -ge 2 ] || usage; shift; cmd_project "$@" ;;
  verify) [ $# -eq 3 ] || usage; cmd_verify "$2" "$3" ;;
  *) usage ;;
esac
