#!/bin/sh
# Regression test (#164, #180, #203): deploy copies the track tag only after its migrations and both rollouts succeeded, and a
# track sharing production's database never migrates it and isn't deployed while migrations are pending.
# A missing or default ADMIN_PASSWORD warns but deploys.
# Runs the real setup.sh and k8s.sh against stub kubectl, helm and curl (the registry). Usage (repository root):
# bin/test/deploy-promotion.sh
set -eu

[ -f bin/devops/k8s.sh ] || { echo "Run from the repository root." >&2; exit 2; }
if command -v busybox >/dev/null 2>&1 && busybox ash -c : 2>/dev/null; then
  K8S_SHELL="busybox ash"
elif command -v bash >/dev/null 2>&1; then
  K8S_SHELL=bash
else
  echo "Needs busybox ash or bash to source k8s.sh." >&2
  exit 2
fi
echo "Sourcing setup.sh and k8s.sh with $K8S_SHELL."

ROOT=$(pwd)
DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT
mkdir "$DIR/bin" "$DIR/work"
ln -s "$ROOT/bin" "$DIR/work/bin"
ln -s "$ROOT/helm" "$DIR/work/helm"

# helm: release values for the database Jobs (STUB_NO_RELEASE: none), a "manifest" that is the render's arguments.
cat >"$DIR/bin/helm" <<'STUB'
#!/bin/sh
echo "helm $*" >>"$STUB_LOG"
case "$1 $2" in
  "get values") [ -z "${STUB_NO_RELEASE:-}" ] || { echo "Error: release: not found" >&2; exit 1; }; echo "php: {}" ;;
  "template "*) echo "# rendered: $*" ;;
esac
exit 0
STUB
# kubectl: deployments named after their release; STUB_ROLLOUT_FAIL (cwa or cwa-pwa) fails that rollout. STUB_PROD_DB is
# production's live database-url (STUB_REVIEW_PROD_DB: as a review job finds it in site-production). Database Jobs finish at once; a task in STUB_FAIL fails; plans report STUB_PENDING.
cat >"$DIR/bin/kubectl" <<'STUB'
#!/bin/sh
echo "kubectl $*" >>"$STUB_LOG"
task() { case "$*" in *-db-plan-*) echo plan ;; *-db-backup-*) echo backup ;; *-db-migrate-*) echo migrate ;; esac; }
failed() { case " ${STUB_FAIL:-} " in *" $(task "$@") "*) return 0 ;; esac; return 1; }
instance() { printf '%s' "$*" | sed -n 's/.*app.kubernetes.io\/instance=\([^ ,]*\).*/\1/p'; }
case "$*" in
  *"exec "*"ADMIN_PASSWORD"*) [ -z "${STUB_POD_ADMIN_DEFAULT:-}" ] || exit 3 ;;
  "create "*) cat "$4" >>"$STUB_LOG" ;;
  *"get job"*"succeeded}{.status.failed}"*) echo 1 ;;
  *"get job"*"status.succeeded}"*) failed "$@" || echo 1 ;;
  "logs "*)
    case "$(task "$@")" in
      plan) printf 'CWA_DATABASE_SERVER_VERSION=16.4\nCWA_MIGRATIONS_PENDING=%s\n' "${STUB_PENDING:-0}" ;;
      migrate) echo migrated ;;
    esac ;;
  "get secret rel-cwa "*"database-url"*) [ -z "${STUB_PROD_DB:-}" ] || printf '%s' "$STUB_PROD_DB" | base64 | tr -d '\n' ;;
  "get secret production-cwa -n site-production "*"database-url"*) [ -z "${STUB_REVIEW_PROD_DB:-}" ] || printf '%s' "$STUB_REVIEW_PROD_DB" | base64 | tr -d '\n' ;;
  "get secret "*) ;;
  *"get deploy"*"name=cwa-pwa,"*) echo "deployment.apps/$(instance "$@")-cwa-pwa" ;;
  *"get deploy"*"name=cwa,"*) echo "deployment.apps/$(instance "$@")-cwa" ;;
  "rollout status "*)
    case "$3" in *-"${STUB_ROLLOUT_FAIL:-none}") echo "error: deployment exceeded its progress deadline" >&2; exit 1 ;; esac ;;
  *"get pods"*"{{if .metadata.deletionTimestamp}}"*) ;;
  *"get pods"*"name=cwa,"*) echo "pod/$(instance "$@")-cwa-new" ;;
esac
exit 0
STUB
# curl: the registry. No auth challenge; :main's digest is sha256:main-<repo>; STUB_PUT_FAIL refuses tag copies.
cat >"$DIR/bin/curl" <<'STUB'
#!/bin/sh
echo "curl $*" >>"$STUB_LOG"
for last; do :; done
repo=$(printf '%s' "$last" | sed -n 's/.*\/\(php\|app\)\/manifests\/.*/\1/p')
case " $* " in
  *" -X PUT "*) [ -z "${STUB_PUT_FAIL:-}" ] || exit 22 ;;
  *" -I "*) printf 'HTTP/1.1 200 OK\r\nDocker-Content-Digest: sha256:main-%s\r\n\r\n' "$repo" ;;
  *" -o "*)
    out=""; prev=""
    for a; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done
    [ "$out" = /dev/null ] || printf '{}' > "$out"
    case " $* " in *" -D - "*) printf 'HTTP/1.1 200 OK\r\nContent-Type: application/vnd.oci.image.index.v1+json\r\n\r\n' ;; esac ;;
esac
exit 0
STUB
chmod +x "$DIR/bin/helm" "$DIR/bin/kubectl" "$DIR/bin/curl"

# run <function calls> <settings>: in a fresh shell from $DIR/work, after setup.sh and k8s.sh, as a GitLab job on main.
run() {
  : >"$DIR/log"
  rm -f "$DIR/work/deploy-skipped.txt" "$DIR/work/values.tmp.yaml"
  set +e
  (cd "$DIR/work" && env -i HOME="$HOME" PATH="$DIR/bin:$PATH" STUB_LOG="$DIR/log" \
    CI_REGISTRY_IMAGE=registry.test/site CI_COMMIT_REF_SLUG=main CI_COMMIT_REF_NAME=main CI_COMMIT_SHA=abc1234def \
    CI_ENVIRONMENT_SLUG=rel CI_ENVIRONMENT_URL=https://site.test CI_PROJECT_PATH_SLUG=group-site KUBE_NAMESPACE=ns \
    APP_SECRET=app-secret NUXT_APP_SECRET=nuxt-secret-nuxt-secret-nuxt-secret-0 MERCURE_JWT_SECRET=mercure \
    JWT_SECRET_KEY=private JWT_PUBLIC_KEY=public JWT_PASSPHRASE=pass CWA_CI_CLUSTER_ISSUER= \
    CWA_CI_PHP_IMAGE_DIGEST=sha256:php CWA_CI_APP_IMAGE_DIGEST=sha256:app CWA_CI_DATABASE_JOB_POLL=0 \
    CWA_CI_REGISTRY_RETRY_DELAY=0 \
    $K8S_SHELL -c '
    set -f
    for setting in $2; do export "$setting"; done
    set +f
    . ./bin/devops/setup.sh >/dev/null
    . ./bin/devops/k8s.sh >/dev/null
    eval "$1"' k8s "$1" "$2") >"$DIR/out" 2>&1
  echo $? >"$DIR/status"
  set -e
}

failures=0
fail() { failures=$((failures + 1)); echo "FAIL ($1): $2" >&2; }
status() { [ "$(cat "$DIR/status")" = "$2" ] || { fail "$1" "exit $(cat "$DIR/status"), expected $2"; sed 's/^/    /' "$DIR/out" >&2; }; }
expect() { grep -qF -- "$2" "$DIR/log" || fail "$1" "no call containing: $2"; }
refuse() { if grep -qF -- "$2" "$DIR/log"; then fail "$1" "unexpected call containing: $2"; fi; }
said() { grep -qF -- "$2" "$DIR/out" || fail "$1" "no output containing: $2"; }
values() { grep -qF -- "$2" "$DIR/work/values.tmp.yaml" 2>/dev/null || fail "$1" "values.tmp.yaml has no: $2"; }
order() {
  first=$(grep -nF -- "$2" "$DIR/log" | head -1 | cut -d: -f1)
  second=$(grep -nF -- "$3" "$DIR/log" | head -1 | cut -d: -f1)
  if [ -z "$first" ] || [ -z "$second" ] || [ "$first" -ge "$second" ]; then fail "$1" "'$2' must come before '$3'"; fi
}
PUT_PHP="-X PUT -H Content-Type: application/vnd.oci.image.index.v1+json --data-binary"
TAG_PHP="registry.test/v2/site/php/manifests"

# Production: pinned to this build's digests, tagged :production only after both rollouts.
run "deploy" ""
status stable 0
values stable "tag: production@sha256:php"
values stable "tag: production@sha256:app"
values stable "skipMigrations: false"
order stable "helm upgrade --install" "rollout status deployment.apps/rel-cwa-pwa"
order stable "rollout status deployment.apps/rel-cwa-pwa" "rollout status deployment.apps/rel-cwa "
order stable "rollout status deployment.apps/rel-cwa " "$PUT_PHP"
expect stable "$TAG_PHP/production"
expect stable "registry.test/v2/site/app/manifests/production"
expect stable "$TAG_PHP/sha256:php"
said stable "Tagged registry.test/site/php@sha256:php as production"

# A pod that never gets ready (e.g. its entrypoint migration failed): the deploy fails and the tag stays put.
run "deploy" "STUB_ROLLOUT_FAIL=cwa"
status api-rollout-fails 1
expect api-rollout-fails "helm upgrade --install"
refuse api-rollout-fails "-X PUT"
said api-rollout-fails "THE cwa ROLLOUT DID NOT FINISH"

run "deploy" "STUB_ROLLOUT_FAIL=cwa-pwa"
status pwa-rollout-fails 1
refuse pwa-rollout-fails "-X PUT"

# The migrate Job fails: no helm, no tag.
run "deploy" "STUB_PENDING=2 STUB_FAIL=migrate"
status migrate-fails 1
expect migrate-fails "databaseJob.task=migrate"
expect migrate-fails "php.image.tag=production@sha256:php"
refuse migrate-fails "helm upgrade"
refuse migrate-fails "-X PUT"

# No build in this pipeline (CWA_CI_BUILD_DISABLED, GitHub's production.yml): :main's digest at deploy time.
run "deploy" "CWA_CI_PHP_IMAGE_DIGEST= CWA_CI_APP_IMAGE_DIGEST="
status no-digest 0
expect no-digest "-I -H Accept:"
values no-digest "tag: production@sha256:main-php"
order no-digest "rollout status deployment.apps/rel-cwa " "$TAG_PHP/production"

# The registry refuses the copy: the live deploy still succeeds, with a warning.
run "deploy" "STUB_PUT_FAIL=1"
status put-fails 0
said put-fails "couldn't be copied"

# A review app keeps its branch tag, pinned by digest, and copies nothing.
run "deploy review" "CI_COMMIT_REF_NAME=feature CI_COMMIT_REF_SLUG=feature CI_ENVIRONMENT_SLUG=review-feature RELEASE=rel-feature"
status review 0
values review "tag: feature@sha256:php"
refuse review "-X PUT"

# Staging on production's database with migrations pending: not deployed, exit 0; the purge leaves the old one alone.
SHARED="CWA_CI_POSTGRES_ENABLED=false DATABASE_URL=pgsql://stage:pw@DB.example:5432/app?serverVersion=16 STUB_PROD_DB=postgresql://prod:other@db.example/app"
run "deploy staging && purge_rendered_html staging" "$SHARED STUB_PENDING=3"
status shared-pending 0
expect shared-pending "helm get values rel -n ns"
expect shared-pending "databaseJob.task=plan"
refuse shared-pending "databaseJob.task=migrate"
refuse shared-pending "helm upgrade"
refuse shared-pending "-X PUT"
refuse shared-pending "rollout status"
said shared-pending "staging NOT DEPLOYED: 3 migration(s) pending"
said shared-pending "nothing to purge"
if grep -qF "pw@" "$DIR/out" || grep -qF "other@" "$DIR/out"; then fail shared-pending "printed a database URL"; fi

# The same, nothing pending: deployed, its pods never migrate, tagged :staging after the rollout.
run "deploy staging" "$SHARED STUB_PENDING=0 CWA_CI_MIGRATIONS_JOB_STAGING=true"
status shared-up-to-date 0
values shared-up-to-date "skipMigrations: true"
refuse shared-up-to-date "databaseJob.task=migrate"
order shared-up-to-date "rollout status deployment.apps/rel-staging-cwa " "$TAG_PHP/staging"

# A canary can't wait: with migrations pending on production's database it fails.
run "deploy canary" "$SHARED STUB_PENDING=1"
status shared-canary 1
said shared-canary "CANARY NOT DEPLOYED"
refuse shared-canary "helm upgrade"

# Staging with its own database (another host, or in-cluster PostgreSQL) migrates as before, with no plan.
run "deploy staging" "CWA_CI_POSTGRES_ENABLED=false DATABASE_URL=pgsql://u:p@staging-db.example/app STUB_PROD_DB=pgsql://u:p@db.example/app"
status own-database 0
values own-database "skipMigrations: false"
refuse own-database "databaseJob.task=plan"
run "deploy staging" "STUB_PROD_DB=pgsql://u:p@rel-postgresql/app"
status in-cluster 0
values in-cluster "skipMigrations: false"
refuse in-cluster "databaseJob.task=plan"

# A review app on production's database is refused (#197): production is release production in <project>-production.
REVIEW_EXTERNAL="CI_PROJECT_NAME=site CWA_CI_POSTGRES_ENABLED=false DATABASE_URL=pgsql://u:p@db.example/app"
run "deploy review" "$REVIEW_EXTERNAL STUB_REVIEW_PROD_DB=postgresql://prod:other@DB.example:5432/app"
status review-shared 1
expect review-shared "get secret production-cwa -n site-production"
said review-shared "REVIEW APP NOT DEPLOYED"
refuse review-shared "helm upgrade"
if grep -qF "p@db" "$DIR/out" || grep -qF "other@" "$DIR/out"; then fail review-shared "printed a database URL"; fi

run "deploy review" "$REVIEW_EXTERNAL STUB_REVIEW_PROD_DB=postgresql://prod:other@prod-db.example/app"
status review-own 0
expect review-own "helm upgrade"

# Unreadable from the review job: a warning, and the deploy goes on.
run "deploy review" "$REVIEW_EXTERNAL"
status review-unchecked 0
said review-unchecked "could not read production's database URL (release 'production' in namespace 'site-production'"

run "deploy review" "$REVIEW_EXTERNAL KUBE_NAMESPACE_PRODUCTION=prod-ns RELEASE_PRODUCTION=live"
expect review-names "get secret live-cwa -n prod-ns"

run "deploy review" "CI_PROJECT_NAME=site"
status review-in-cluster 0
refuse review-in-cluster "get secret production-cwa"

# The public admin/admin login warns but still deploys (#203); a real password says nothing.
ADMIN_WARNING="the super-admin login on site.test is admin/admin"
run "deploy" ""
status admin-unset 0
said admin-unset "ADMIN_PASSWORD is unset"
expect admin-unset "helm upgrade --install"
values admin-unset "password: admin"
run "deploy" "ADMIN_PASSWORD=admin GITHUB_ACTIONS=true"
status admin-default 0
said admin-default "ADMIN_PASSWORD is 'admin'"
said admin-default "::warning title=Public admin password::"
run "deploy" "ADMIN_PASSWORD=s3cret-long-value"
status admin-set 0
if grep -qF "$ADMIN_WARNING" "$DIR/out"; then fail admin-set "warned with a real password"; fi
if grep -qF "s3cret-long-value" "$DIR/out"; then fail admin-set "printed the password"; fi

# The fixture load checks the pod's own value, since that's what it writes.
run "load_fixtures" "ADMIN_PASSWORD=s3cret-long-value STUB_POD_ADMIN_DEFAULT=1"
said fixtures-pod-default "ADMIN_PASSWORD is unset or 'admin' in the API pod"
expect fixtures-pod-default "doctrine:fixtures:load --append"
run "load_fixtures" "ADMIN_PASSWORD=admin"
if grep -qF "$ADMIN_WARNING" "$DIR/out"; then fail fixtures-pod-set "warned though the pod has a real password"; fi
expect fixtures-pod-set "doctrine:fixtures:load --append"

if [ "$failures" -ne 0 ]; then
  echo "$failures checks failed." >&2
  exit 1
fi
echo "All checks passed."
