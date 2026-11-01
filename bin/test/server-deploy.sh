#!/bin/sh
# Test (#212): bin/devops/server-deploy.sh against a real sshd on localhost, with a stub bin/server/deploy.sh. Checks the
# required variables, that an unknown host key is refused, that the first run copies the files and asks for init, and
# that the next one keeps the server's .env.prod and backups/, deletes files the commit dropped and runs deploy.sh.
# Needs root, apk (Alpine). Usage: docker run --rm -v "$PWD:/w" -w /w alpine:3.22 sh bin/test/server-deploy.sh
set -eu

apk add --no-cache -q git openssh-server openssh-client rsync >/dev/null
SCRIPT=$(pwd)/bin/devops/server-deploy.sh
T=$(mktemp -d)
trap 'kill "$(cat "$T/sshd.pid" 2>/dev/null)" 2>/dev/null || true; rm -rf "$T"' EXIT
failures=0
fail() { failures=$((failures + 1)); echo "FAIL: $1" >&2; }

# sshd on 2222, a deploy user with a key.
ssh-keygen -q -A
adduser -D -s /bin/sh deploy && passwd -u deploy >/dev/null 2>&1 || true
ssh-keygen -q -t ed25519 -N '' -f "$T/id"
mkdir -p /home/deploy/.ssh && cp "$T/id.pub" /home/deploy/.ssh/authorized_keys
chown -R deploy /home/deploy/.ssh && chmod 700 /home/deploy/.ssh && chmod 600 /home/deploy/.ssh/authorized_keys
/usr/sbin/sshd -p 2222 -o PidFile="$T/sshd.pid" -o PasswordAuthentication=no
sleep 1
KNOWN=$(ssh-keyscan -p 2222 127.0.0.1 2>/dev/null)

# A project commit with a stub deploy.sh.
P="$T/project" && mkdir -p "$P/bin/server" "$P/bin/lib" && cd "$P"
cp "$SCRIPT" ./server-deploy.sh
printf '/.env.prod\n/backups/\n' > .gitignore
printf '#!/bin/sh\necho "STUB DEPLOY in $(pwd) php=${CWA_SERVER_PHP_IMAGE:-} app=${CWA_SERVER_APP_IMAGE:-} config=${CWA_SERVER_REGISTRY_CONFIG:-}"\n[ -z "${CWA_SERVER_REGISTRY_CONFIG:-}" ] || cat "$CWA_SERVER_REGISTRY_CONFIG/login"\n' > bin/server/deploy.sh
# A stub docker on the "server": records the login in its DOCKER_CONFIG.
printf '#!/bin/sh\n[ "$1" = login ] && { echo "login $* pw=$(cat)" > "$DOCKER_CONFIG/login"; exit 0; }\nexit 1\n' > /usr/local/bin/docker
chmod +x /usr/local/bin/docker
printf 'env_value() { sed -n "s/^$1=//p" .env.prod; }\n' > bin/server/lib.sh
echo old > dropped.txt
git init -q && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm one

run() { env CWA_CI_SERVER_HOST=127.0.0.1 CWA_CI_SERVER_PORT=2222 CWA_CI_SERVER_SSH_KEY="$(cat "$T/id")" CWA_CI_SERVER_KNOWN_HOSTS="$KNOWN" "$@" sh ./server-deploy.sh 2>&1; }

out=$(env -u CWA_CI_SERVER_HOST sh ./server-deploy.sh 2>&1) && fail "ran without CWA_CI_SERVER_HOST" || true
case "$out" in *"CWA_CI_SERVER_HOST isn't set"*) ;; *) fail "no-host message: $out" ;; esac

out=$(run CWA_CI_SERVER_KNOWN_HOSTS="127.0.0.1 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA") && fail "accepted a wrong host key" || true
case "$out" in *"Host key verification failed"*|*"REMOTE HOST IDENTIFICATION"*|*"No ED25519 host key"*) ;; *) fail "wrong host key message: $out" ;; esac

out=$(run CWA_CI_SERVER_PATH='x;touch /tmp/pwned') && fail "accepted a bad path" || true
case "$out" in *"CWA_CI_SERVER_PATH"*) ;; *) fail "bad path message: $out" ;; esac

# First run: files land, no .env.prod yet.
out=$(run) && fail "first run without .env.prod succeeded" || true
case "$out" in *"run \`cd cwa && sh bin/server/init\`"*) ;; *) fail "first-run message: $out" ;; esac
[ -f /home/deploy/cwa/dropped.txt ] || fail "files weren't copied"

# The server's own files, then a commit that drops a file.
printf 'SITE_HOST=example.test\nSECRET=keep\n' > /home/deploy/cwa/.env.prod
mkdir -p /home/deploy/cwa/backups && echo dump > /home/deploy/cwa/backups/a.dump
chown -R deploy /home/deploy/cwa
git rm -q dropped.txt && echo new > added.txt && git add added.txt && git -c user.email=t@t -c user.name=t commit -qm two

out=$(run) || fail "deploy run failed: $out"
case "$out" in *"STUB DEPLOY in /home/deploy/cwa"*) ;; *) fail "deploy.sh didn't run: $out" ;; esac
[ ! -e /home/deploy/cwa/dropped.txt ] || fail "a file the commit dropped is still on the server"
[ -f /home/deploy/cwa/added.txt ] || fail "a new file wasn't copied"
grep -q SECRET=keep /home/deploy/cwa/.env.prod || fail ".env.prod was changed or deleted"
[ -f /home/deploy/cwa/backups/a.dump ] || fail "backups/ was deleted"
[ ! -e /home/deploy/cwa/.git ] || fail ".git was copied"
[ "$(cat environment_url.env 2>/dev/null)" = "SITE_ENVIRONMENT_URL=https://example.test" ] || fail "environment_url.env: $(cat environment_url.env 2>/dev/null)"

# With a registry: the pipeline's images by digest, a login only for the run, gone afterwards.
digest=sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
out=$(run CI_REGISTRY=registry.test CI_REGISTRY_IMAGE=registry.test/g/p CI_REGISTRY_USER=ci-user CI_REGISTRY_PASSWORD=s3cret \
  CWA_CI_PHP_IMAGE_DIGEST=$digest TAG=main) || fail "image run: $out"
case "$out" in *"php=registry.test/g/p/php@$digest app=registry.test/g/p/app:main"*) ;; *) fail "images: $out" ;; esac
case "$out" in *"login -u ci-user --password-stdin registry.test pw=s3cret"*) ;; *) fail "registry login: $out" ;; esac
config=$(echo "$out" | sed -n 's/.*config=\([^ ]*\).*/\1/p' | head -n 1)
[ -n "$config" ] && [ ! -e "$config" ] || fail "the registry login was left on the server: '$config'"
out=$(run CI_REGISTRY_IMAGE=registry.test/g/p CWA_CI_SERVER_BUILD=true) || fail "build run: $out"
case "$out" in *"php= app="*) ;; *) fail "CWA_CI_SERVER_BUILD still passed images: $out" ;; esac
out=$(run CI_REGISTRY_IMAGE='registry.test/g/p;id' TAG=main) && fail "accepted a bad image name" || true

# A base64 key works too.
out=$(run CWA_CI_SERVER_SSH_KEY="$(base64 "$T/id" | tr -d '\n')") || fail "base64 key: $out"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)." >&2; exit 1; }
echo "All checks passed."
