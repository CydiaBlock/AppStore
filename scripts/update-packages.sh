#!/usr/bin/env bash
set -euo pipefail

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
