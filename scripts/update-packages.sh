#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
api_url=https://api.github.com
[ "$SERVER_URL" = "https://github.com" ] || api_url="$SERVER_URL/api/v3"
compgen -G 'work/deb/*.deb' > /dev/null || {
  echo "No new DEB assets" >&2
  exit 1
}

mkdir -p work
: > work/asset-urls
while IFS=$'\t' read -r name asset_id; do
  headers=$(mktemp)
  curl --fail --silent --show-error \
    --dump-header "$headers" --output /dev/null \
    -H "Accept: application/octet-stream" \
    -H "Authorization: Bearer $GH_TOKEN" \
    "$api_url/repos/$REPOSITORY/releases/assets/$asset_id"
  direct_url=$(awk 'tolower($1) == "location:" { sub(/^Location: /, ""); sub(/\r$/, ""); print; exit }' "$headers")
  rm -f "$headers"
  [ -n "$direct_url" ] || { echo "Could not resolve direct URL for $name" >&2; exit 1; }
  printf '%s\t%s\n' "$name" "$direct_url" >> work/asset-urls
done < <(gh api "/repos/$REPOSITORY/releases/tags/$RELEASE_TAG" \
  --jq '.assets[] | select(.name | endswith(".deb")) | [.name, .id] | @tsv')

rewrite_filenames() {
  awk -F '\t' '
    NR == FNR { urls[$1] = $2; next }
    /^Filename: / {
      name = $0
      sub(/^Filename: .*\//, "", name)
      if (urls[name] != "") {
        print "Filename: " urls[name]
        next
      }
    }
    { print }
  ' work/asset-urls "$1"
}

if [ -f Packages ]; then
  rewrite_filenames Packages > work/old-Packages
  mv work/old-Packages Packages
else
  : > Packages
fi

dpkg-scanpackages -m work/deb /dev/null > work/new-Packages
rewrite_filenames work/new-Packages > work/new-Packages.direct
printf '\n' >> Packages
cat work/new-Packages.direct >> Packages
gzip --keep --force --best Packages
