#!/usr/bin/env bash
set -euo pipefail

: "${PROXY_URL:?PROXY_URL is required}"

{
  echo "# CydiaBlock AppStore"
  echo
  echo "Decrypted iOS applications and games converted to DEB packages."
  echo
  for tag in game application; do
    entries=$(awk -v tag="$tag" '
      function emit() {
        if (entry_tag == tag && name != "" && file != "" && !seen[file]++) {
          print name "\t" file
        }
        name = entry_tag = file = ""
      }
      /^Name: / { name = substr($0, 7) }
      /^Filename: \.\/(game|application)\// {
        path = $0
        sub(/^Filename: \.\//, "", path)
        entry_tag = path
        sub(/\/.*$/, "", entry_tag)
        sub(/^[^/]+\//, "", path)
        file = path
      }
      /^$/ { emit() }
      END { emit() }
    ' Packages)
    [ -z "$entries" ] && continue
    echo "## ${tag^}"
    while IFS=$'\t' read -r name file; do
      printf -- '- [%s](%s/%s/%s) — `%s`\n' \
        "$name" "$PROXY_URL" "$tag" "$file" "$file"
    done <<< "$entries"
    echo
  done
} > README.md
