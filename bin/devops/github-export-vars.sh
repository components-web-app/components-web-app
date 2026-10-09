#!/usr/bin/env bash
# Exports every GitHub variable to the job's later steps, as GitLab does (#91); names the job already sets win.
# Run first after checkout, with env VARS_JSON: ${{ toJSON(vars) }}. Secrets aren't in vars: map them explicitly.
set -euo pipefail

: "${GITHUB_ENV:?run this inside a GitHub Actions job}"

if [ -z "${VARS_JSON:-}" ] || [ "$VARS_JSON" = "null" ]; then
  echo "No GitHub variables to expose."
  exit 0
fi

exported=()
kept=()
while IFS= read -r name; do
  case "$name" in
    GITHUB_*|RUNNER_*|CI) continue ;;
  esac
  if [ -n "${!name+x}" ]; then
    kept+=("$name")
    continue
  fi
  delimiter="CWA_VAR_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
  {
    printf '%s<<%s\n' "$name" "$delimiter"
    jq -r --arg k "$name" '.[$k]' <<<"$VARS_JSON"
    printf '%s\n' "$delimiter"
  } >> "$GITHUB_ENV"
  exported+=("$name")
done < <(jq -r 'keys[] | select(test("^[A-Za-z_][A-Za-z0-9_]*$"))' <<<"$VARS_JSON")

echo "Exposed ${#exported[@]} variable(s): ${exported[*]:-none}"
if [ "${#kept[@]}" -gt 0 ]; then
  echo "Already set by the job, left as is: ${kept[*]}"
fi
