#!/bin/sh
# Template CI only (#215): creates a project from this checkout with the built CLI, starts it through bin/up and checks the login.
# Usage: packages/create-cwa/smoke.sh <work dir>   (SMOKE_FEATURES: all|none|a,b; SMOKE_FIXTURES: true|false)
# Needs node and pnpm (or a built dist/), git, docker with compose, and free ports 80, 443, 3001, 5432 and 8025.
set -u

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORK=${1:?usage: smoke.sh <work dir>}
FEATURES=${SMOKE_FEATURES:-all}
FIXTURES=${SMOKE_FIXTURES:-true}
NAME=cwa-smoke
PROJECT="$WORK/$NAME"
# The images' first build, composer and pnpm installs on a CI runner take longer than a laptop's default 900 s.
export CWA_UP_TIMEOUT="${CWA_UP_TIMEOUT:-1800}"

fail() {
  [ -z "${GITHUB_ACTIONS:-}" ] || echo "::error::create-cwa smoke: $*"
  echo "create-cwa smoke failed: $*" >&2
  [ "$(pwd)" != "$PROJECT" ] || docker compose logs --no-color --tail 80 php app >&2
  exit 1
}

if [ ! -f "$ROOT/packages/create-cwa/dist/index.js" ]; then
  (cd "$ROOT/packages/create-cwa" && pnpm install --frozen-lockfile && pnpm run build) || fail "couldn't build the CLI"
fi

[ ! -e "$PROJECT" ] || fail "$PROJECT already exists"
mkdir -p "$WORK" || exit 1
# CI checkouts can belong to another user than the one running git here (GitLab's dind job, GitHub containers).
if [ -n "${CI:-}" ]; then git config --global --add safe.directory "$ROOT"; fi

[ "$FIXTURES" = true ] && fixtures=--fixtures || fixtures=--no-fixtures
cd "$WORK" || exit 1
echo "==> create-cwa $NAME --ci --template-dir $ROOT --pipeline none --features $FEATURES $fixtures --start"
# The exit status goes through a file: POSIX sh has no pipefail.
{ node "$ROOT/packages/create-cwa/bin/create-cwa.js" "$NAME" --ci --template-dir "$ROOT" \
    --pipeline none --features "$FEATURES" "$fixtures" --start 2>&1; echo $? > "$WORK/status"; } | tee "$WORK/create-cwa.log"
status=$(cat "$WORK/status")
[ "$status" = 0 ] || fail "create-cwa exited $status (bin/up's output is above)"

grep -q 'Sign in:   https://localhost/login' "$WORK/create-cwa.log" || fail "bin/up didn't print the login URL"
grep -q 'Admin:     admin / admin' "$WORK/create-cwa.log" || fail "bin/up didn't print the admin login"

cd "$PROJECT" || exit 1
# From inside php, as bin/up does: the published ports are on the Docker host, which isn't this machine under dind.
login=$(docker compose exec -T php curl -fsSk --max-time 60 --resolve localhost:443:127.0.0.1 https://localhost/login) \
  || fail "https://localhost/login didn't answer 200"
echo "$login" | grep -q 'type="password"' || fail "https://localhost/login has no password field"

code=$(docker compose exec -T php curl -sk --max-time 30 --resolve localhost:443:127.0.0.1 -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin"}' https://localhost/_api/login | tr -d '\r')
[ "$code" = 204 ] || fail "signing in as admin / admin answered $code, not 204"

echo "create-cwa smoke passed: features $FEATURES, fixtures $FIXTURES"
