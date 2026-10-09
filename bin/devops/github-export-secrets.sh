#!/usr/bin/env bash
# Exports the NUXT_* and CWA_API_* secrets (GitHub can't list secrets) to the
# job's later steps, masked. Deploy jobs only, after the setup actions:
#   env: { SECRETS_JSON: ${{ toJSON(secrets) }} }
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
