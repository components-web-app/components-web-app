#!/usr/bin/env bash
# Exposes the site's NUXT_* and CWA_API_* secrets (repository, organisation and
# environment) to the job's later steps, so k8s.sh's site environment passthrough
# (#125) finds them as GitLab's jobs do. GitHub can't list secrets or give them to
# a job unless each one is named, so a new setting would otherwise need a workflow
# edit. Variables with these names already arrive through github-export-vars.sh.
# Run it in deploy jobs only (never a build job), after the kubectl and helm setup
# actions, just before the deploy steps, so the values reach this repository's own
# scripts and not those actions:
#
#   - name: Expose NUXT_* and CWA_API_* secrets to the deploy
#     env:
#       SECRETS_JSON: ${{ toJSON(secrets) }}
#     run: bin/devops/github-export-secrets.sh
#
# Only those names are exported; every other secret stays out of $GITHUB_ENV. The
# JSON arrives through the environment, never interpolated into the script. Each
# value is masked again, line by line as well as whole, so a multi-line secret
# stays hidden in the logs. A name the job already has (a variable of the same
# name) is left alone, with a warning. A NUXT_PUBLIC_* secret is exported with a
# warning: Nuxt sends public runtime config to every browser, so it isn't secret.
set -euo pipefail

: "${GITHUB_ENV:?run this inside a GitHub Actions job}"

if [ -z "${SECRETS_JSON:-}" ] || [ "$SECRETS_JSON" = "null" ]; then
  echo "No secrets to expose."
  exit 0
fi

# A workflow command's data is percent-decoded by the runner.
mask() {
  local value="$1"
  value="${value//'%'/%25}"
  value="${value//$'\r'/%0D}"
  value="${value//$'\n'/%0A}"
  echo "::add-mask::$value"
}

exported=()
kept=()
public=()
while IFS= read -r name; do
  if [ -n "${!name+x}" ]; then
    kept+=("$name")
    continue
  fi
  value=$(jq -r --arg k "$name" '.[$k]' <<<"$SECRETS_JSON"; printf x)
  value="${value%?}"
  value="${value%$'\n'}"
  if [ -n "$value" ]; then
    mask "$value"
    while IFS= read -r line; do
      line="${line%$'\r'}"
      # Very short lines (a lone brace) would mask that text everywhere in the log.
      [ "${#line}" -ge 4 ] && mask "$line"
    done <<<"$value"
  fi
  delimiter="CWA_SECRET_$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  {
    printf '%s<<%s\n' "$name" "$delimiter"
    printf '%s\n' "$value"
    printf '%s\n' "$delimiter"
  } >> "$GITHUB_ENV"
  exported+=("$name")
  case "$name" in
    NUXT_PUBLIC_*) public+=("$name") ;;
  esac
done < <(jq -r 'keys[] | select(test("^(NUXT_[A-Za-z0-9_]+|CWA_API_[A-Za-z0-9_]+)$"))' <<<"$SECRETS_JSON")

if [ "${#public[@]}" -gt 0 ]; then
  echo "::warning title=Public value stored as a secret::${public[*]}: NUXT_PUBLIC_* runtime config is sent to every browser, in page HTML, so it isn't secret. Make it a variable."
fi
if [ "${#kept[@]}" -gt 0 ]; then
  echo "::warning title=Secret shadowed::${kept[*]}: a variable (or the job's env) already sets this name, so the secret is not used. Delete one of the two."
fi
echo "Exposed ${#exported[@]} secret(s): ${exported[*]:-none}"
