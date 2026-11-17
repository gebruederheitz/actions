#!/usr/bin/env bash
# Installs or activates the tools that setup-tool-versions leaves to asdf.
# Reads $ASDF_TOOLS: one "<tool> <version> [<version>...]" line per tool.
#
#   asdf-tools.sh install   adds missing plugins and installs every listed version
#   asdf-tools.sh export    pins each tool's first version for the rest of the
#                           job (ASDF_<TOOL>_VERSION in $GITHUB_ENV), so asdf's
#                           shims work in any directory and with any
#                           tool-versions-path
set -euo pipefail

mode=${1:?usage: asdf-tools.sh install|export}

while read -r tool tool_versions; do
  [ -n "$tool" ] || continue
  read -r -a tool_versions <<<"$tool_versions"
  case "$mode" in
    install)
      if ! asdf plugin list 2>/dev/null | grep -qx "$tool"; then
        asdf plugin add "$tool"
      fi
      for version in "${tool_versions[@]}"; do
        case "$version" in
          system | path:*) echo "Skipping $tool $version (not installed by asdf)." ;;
          *) asdf install "$tool" "$version" ;;
        esac
      done
      ;;
    export)
      variable="ASDF_$(echo "$tool" | tr '[:lower:]-' '[:upper:]_')_VERSION"
      echo "$variable=${tool_versions[0]}" >>"${GITHUB_ENV:?}"
      ;;
    *)
      echo "::error::Unknown mode '$mode'." >&2
      exit 2
      ;;
  esac
done <<<"${ASDF_TOOLS:-}"
