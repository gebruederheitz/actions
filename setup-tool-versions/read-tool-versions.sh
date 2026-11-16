#!/usr/bin/env bash
# Reads an asdf .tool-versions file and sorts its lines into tools installed
# from prebuilt binaries (php, nodejs, pnpm) and tools left to asdf. Writes to
# $GITHUB_OUTPUT:
#   php, nodejs, pnpm  the version of each prebuilt tool (empty if not listed)
#   asdf-tools         the remaining lines ("<tool> <version>..."), one per line
# Fails with a GitHub error annotation for duplicate tools and for prebuilt
# tools without exactly one numeric version.
#
# Usage: read-tool-versions.sh <path>
set -euo pipefail

file=${1:?usage: read-tool-versions.sh <path to .tool-versions>}
output=${GITHUB_OUTPUT:-/dev/stdout}
prebuilt="php nodejs pnpm"

if [ ! -f "$file" ]; then
  echo "::error::'$file' not found. Check out the repository (actions/checkout) before running setup-tool-versions."
  exit 1
fi

declare -A versions=() seen=()
asdf_tools=()
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
  if [ -n "${seen[$tool]:-}" ]; then
    fail "$line_no" "'$tool' is listed more than once."
    continue
  fi
  seen[$tool]=1

  if [[ " $prebuilt " != *" $tool "* ]]; then
    asdf_tools+=("${fields[*]}")
    continue
  fi
  if [ "${#fields[@]}" -ne 2 ]; then
    fail "$line_no" "'$tool' must have exactly one version, found $((${#fields[@]} - 1)): '${fields[*]:1}'. setup-tool-versions installs $tool from a prebuilt binary."
    continue
  fi
  version=${fields[1]}
  if ! [[ "$version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    fail "$line_no" "Unsupported version '$version' for '$tool'. Use a numeric version like 8.4 or 8.4.16 (no 'system', 'latest', 'ref:' or 'path:'); setup-tool-versions installs $tool from a prebuilt binary."
    continue
  fi
  versions[$tool]=$version
done <"$file"

if [ "$errors" -gt 0 ]; then
  exit 1
fi

for tool in $prebuilt; do
  echo "$tool=${versions[$tool]:-}" >>"$output"
done
{
  echo "asdf-tools<<ASDF_TOOLS_EOF"
  if [ "${#asdf_tools[@]}" -gt 0 ]; then printf '%s\n' "${asdf_tools[@]}"; fi
  echo "ASDF_TOOLS_EOF"
} >>"$output"
if [ "${#asdf_tools[@]}" -gt 0 ]; then
  echo "::notice::Installing with asdf (no prebuilt binary support): $(printf '%s, ' "${asdf_tools[@]}" | sed 's/, $//')"
fi
