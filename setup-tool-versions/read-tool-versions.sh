#!/usr/bin/env bash
# Reads an asdf .tool-versions file and writes one output per supported tool
# (php, nodejs, pnpm) to $GITHUB_OUTPUT. Fails with a GitHub error annotation
# for anything this action cannot install from a prebuilt binary.
#
# Usage: read-tool-versions.sh <path>
set -euo pipefail

file=${1:?usage: read-tool-versions.sh <path to .tool-versions>}
output=${GITHUB_OUTPUT:-/dev/stdout}
supported="php nodejs pnpm"

if [ ! -f "$file" ]; then
  echo "::error::'$file' not found. Check out the repository (actions/checkout) before running setup-tool-versions."
  exit 1
fi

declare -A versions=()
errors=0
fail() {
  echo "::error file=$file,line=$1::$2"
  errors=$((errors + 1))
}

line_no=0
while IFS= read -r line || [ -n "$line" ]; do
  line_no=$((line_no + 1))
  line=${line%$'\r'}
  line=${line%%#*}
  read -r -a fields <<<"$line" || true
  [ "${#fields[@]}" -eq 0 ] && continue

  tool=${fields[0]}
  if [[ " $supported " != *" $tool "* ]]; then
    fail "$line_no" "Unsupported tool '$tool'. setup-tool-versions installs only: $supported. Remove it from $file and set it up in the workflow, or use cached-asdf."
    continue
  fi
  if [ "${#fields[@]}" -ne 2 ]; then
    fail "$line_no" "'$tool' must have exactly one version, found $((${#fields[@]} - 1)): '${fields[*]:1}'."
    continue
  fi
  version=${fields[1]}
  if ! [[ "$version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    fail "$line_no" "Unsupported version '$version' for '$tool'. Use a numeric version like 8.4 or 8.4.16 (no 'system', 'latest', 'ref:' or 'path:')."
    continue
  fi
  if [ -n "${versions[$tool]:-}" ]; then
    fail "$line_no" "'$tool' is listed more than once."
    continue
  fi
  versions[$tool]=$version
done <"$file"

if [ "$errors" -gt 0 ]; then
  exit 1
fi

for tool in $supported; do
  echo "$tool=${versions[$tool]:-}" >>"$output"
done
