#!/usr/bin/env bash
# Exposes every GitHub variable (repository, organisation and environment) to the
# job's later steps, the way GitLab exposes project variables to every job (#91).
#
# GitHub only passes the variables a job's `env:` names. Run this as the first
# step after checkout:
#
#   - name: Expose repository variables to the scripts, as GitLab does
#     env:
#       VARS_JSON: ${{ toJSON(vars) }}
#     run: bin/devops/github-export-vars.sh
#
# The JSON arrives through the environment, never interpolated into the script,
# so a quote or `$` in a value can't break or inject anything. A name the job
# already sets (an explicit `env:` mapping, or a secret mapped to that name) is
# left alone, so explicit mappings always win. Secrets are not in `vars`: map
# them explicitly, so GitHub masks them.
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
