#!/usr/bin/env bash
set -euo pipefail

: "${INDEX_DIR:?INDEX_DIR is required}"
compgen -G 'work/deb/*.deb' > /dev/null || {
  echo "No new DEB assets" >&2
  exit 1
}

mkdir -p work
rewrite_filenames() {
  awk -v tag="$RELEASE_TAG" '
    /^Filename: / {
      name = $0
      sub(/^Filename: .*\//, "", name)
      print "Filename: ./" tag "/" name
      next
    }
    { print }
  ' "$1"
}

if [ -f "$INDEX_DIR/Packages" ]; then
  rewrite_filenames "$INDEX_DIR/Packages" > work/old-Packages
  mv work/old-Packages "$INDEX_DIR/Packages"
else
  : > "$INDEX_DIR/Packages"
fi

dpkg-scanpackages -m work/deb /dev/null > work/new-Packages
rewrite_filenames work/new-Packages > work/new-Packages.direct
printf '\n' >> "$INDEX_DIR/Packages"
cat work/new-Packages.direct >> "$INDEX_DIR/Packages"
gzip --keep --force --best "$INDEX_DIR/Packages"
