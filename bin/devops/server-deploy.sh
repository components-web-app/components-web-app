#!/bin/sh
# Deploys this commit to a single server over SSH (#212), from GitLab's "production server" job or GitHub's server.yml:
# copies the commit's files to the server with rsync, then runs bin/server/deploy.sh there on the images this pipeline
# built (pulled with the job's registry login, which never stays on the server), then migrates, purges and warms.
# Setting CWA_CI_SERVER_HOST makes a project single-server: the Kubernetes deploy jobs don't run.
#   CWA_CI_SERVER_HOST         the server's address (required)
#   CWA_CI_SERVER_SSH_KEY      a private key the server accepts, as is or base64 on one line (required, secret)
#   CWA_CI_SERVER_KNOWN_HOSTS  the server's host keys, from `ssh-keyscan <host>` (required; never skipped)
#   CWA_CI_SERVER_USER         (deploy), CWA_CI_SERVER_PORT (22), CWA_CI_SERVER_PATH (cwa: relative to the user's home)
#   CWA_CI_SERVER_BUILD        "true" builds on the server instead (a server of another architecture than the runners)
# The server needs docker with compose, rsync and curl, and the user in the docker group. Files git ignores there
# (.env.prod, backups/) are never sent or deleted.
set -eu

fail() { echo "❌ $*" >&2; exit 1; }

host=${CWA_CI_SERVER_HOST:-}
user=${CWA_CI_SERVER_USER:-deploy}
port=${CWA_CI_SERVER_PORT:-22}
dir=${CWA_CI_SERVER_PATH:-cwa}
[ -n "$host" ] || fail "CWA_CI_SERVER_HOST isn't set: the server's address."
[ -n "${CWA_CI_SERVER_SSH_KEY:-}" ] || fail "CWA_CI_SERVER_SSH_KEY isn't set: a private key the server's $user user accepts."
[ -n "${CWA_CI_SERVER_KNOWN_HOSTS:-}" ] || fail "CWA_CI_SERVER_KNOWN_HOSTS isn't set: run \`ssh-keyscan -p $port $host\` and store its output."
# Interpolated into remote commands, so only plain path characters.
case "$dir" in
  ''|*[!A-Za-z0-9._/-]*|-*) fail "CWA_CI_SERVER_PATH ($dir): use letters, digits and . _ / - only." ;;
esac
case "$user$host$port" in
  *[!A-Za-z0-9._:@-]*) fail "CWA_CI_SERVER_USER, _HOST or _PORT has a character that isn't allowed." ;;
esac
command -v rsync >/dev/null 2>&1 || fail "rsync isn't installed in this job."
command -v ssh >/dev/null 2>&1 || fail "ssh isn't installed in this job."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
case "$CWA_CI_SERVER_SSH_KEY" in
  *"-----BEGIN"*) printf '%s\n' "$CWA_CI_SERVER_SSH_KEY" ;;
  *) printf '%s' "$CWA_CI_SERVER_SSH_KEY" | base64 -d ;;
esac > "$work/key" || fail "CWA_CI_SERVER_SSH_KEY is neither a key nor base64."
chmod 600 "$work/key"
printf '%s\n' "$CWA_CI_SERVER_KNOWN_HOSTS" > "$work/known_hosts"

ssh_cmd="ssh -i $work/key -p $port -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$work/known_hosts"
target="$user@$host"

echo "➡️ Copying $(git rev-parse --short HEAD) to $target:$dir..."
mkdir "$work/tree"
git archive --format=tar HEAD | tar -x -C "$work/tree"
$ssh_cmd "$target" "mkdir -p '$dir'"
# The .gitignore filter keeps what only the server has (.env.prod, backups/): excluded files are never deleted.
rsync -rlptz --delete --filter=':- .gitignore' --exclude=/.git -e "$ssh_cmd" "$work/tree/" "$target:$dir/"

if ! $ssh_cmd "$target" "test -f '$dir/.env.prod'"; then
  fail "No .env.prod on the server yet. The files are there now: on the server, run \`cd $dir && sh bin/server/init\`, then \`sh bin/server/deploy.sh --fixtures\` for the first deploy, and run this job again for the next ones."
fi

site_host=$($ssh_cmd "$target" "cd '$dir' && . ./bin/server/lib.sh && env_value SITE_HOST") || site_host=""
if [ -n "$site_host" ]; then
  # A dotenv artifact: the environment's url, as persist_environment_url writes it for Kubernetes deploys.
  printf 'SITE_ENVIRONMENT_URL=https://%s\n' "$site_host" > environment_url.env
fi

# The pipeline's images: by digest when the build job recorded one (image_digest.env), else this ref's tag.
images=""
if [ "${CWA_CI_SERVER_BUILD:-}" != "true" ] && [ -n "${CI_REGISTRY_IMAGE:-}" ]; then
  tag=${TAG:-${CI_COMMIT_REF_SLUG:-main}}
  php_image="$CI_REGISTRY_IMAGE/php${CWA_CI_PHP_IMAGE_DIGEST:+@$CWA_CI_PHP_IMAGE_DIGEST}"
  app_image="$CI_REGISTRY_IMAGE/app${CWA_CI_APP_IMAGE_DIGEST:+@$CWA_CI_APP_IMAGE_DIGEST}"
  [ -n "${CWA_CI_PHP_IMAGE_DIGEST:-}" ] || php_image="$php_image:$tag"
  [ -n "${CWA_CI_APP_IMAGE_DIGEST:-}" ] || app_image="$app_image:$tag"
  case "$php_image$app_image${CI_REGISTRY:-}${CI_REGISTRY_USER:-}" in
    *[!A-Za-z0-9._/:@-]*) fail "An image or registry name has a character that isn't allowed: $php_image $app_image" ;;
  esac
  images="CWA_SERVER_PHP_IMAGE='$php_image' CWA_SERVER_APP_IMAGE='$app_image'"
  echo "Images: $php_image, $app_image"
fi

echo "➡️ Deploying on the server..."
if [ -n "$images" ] && [ -n "${CI_REGISTRY_PASSWORD:-}" ]; then
  # The login lives in a temporary DOCKER_CONFIG for the pulls only, deleted however deploy.sh ends.
  printf '%s' "$CI_REGISTRY_PASSWORD" | $ssh_cmd "$target" "set -e; d=\$(mktemp -d); trap 'rm -rf \"\$d\"' EXIT; \
    DOCKER_CONFIG=\"\$d\" docker login -u '$CI_REGISTRY_USER' --password-stdin '$CI_REGISTRY' >/dev/null; \
    cd '$dir' && CWA_SERVER_REGISTRY_CONFIG=\"\$d\" $images sh bin/server/deploy.sh </dev/null"
elif [ -n "$images" ]; then
  $ssh_cmd "$target" "cd '$dir' && $images sh bin/server/deploy.sh"
else
  $ssh_cmd "$target" "cd '$dir' && sh bin/server/deploy.sh"
fi
