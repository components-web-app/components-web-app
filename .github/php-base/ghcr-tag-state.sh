#!/bin/sh
# Prints "present" or "absent" for <owner>/<package>:<tag> on GHCR; any other registry answer exits 1, so the never-overwrite check fails closed (#208).
# Needs GITHUB_ACTOR and GITHUB_TOKEN (packages: read). A package that doesn't exist yet is a 404 when authenticated. Usage: ghcr-tag-state.sh <owner>/<package> <tag>
set -eu

repo=$1
tag=$2
token=$(curl -sS --max-time 30 --retry 3 -u "$GITHUB_ACTOR:$GITHUB_TOKEN" \
	"https://ghcr.io/token?service=ghcr.io&scope=repository:$repo:pull" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p') || token=
[ -n "$token" ] || { echo "::error::GHCR gave no pull token for $repo" >&2; exit 1; }
code=$(curl -sS --max-time 30 --retry 3 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $token" \
	-H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json" \
	"https://ghcr.io/v2/$repo/manifests/$tag") || code=000
case "$code" in
	200) echo present ;;
	404) echo absent ;;
	*) echo "::error::GHCR answered $code for $repo:$tag; not treating it as absent" >&2; exit 1 ;;
esac
