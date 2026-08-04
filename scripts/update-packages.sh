#!/usr/bin/env bash
set -euo pipefail

compgen -G 'work/deb/*.deb' > /dev/null || {
  echo "No new DEB assets" >&2
  exit 1
}

if [ ! -f Packages ]; then
  : > Packages
fi

dpkg-scanpackages -m work/deb /dev/null \
  | sed -E "s#^Filename: .*/([^/]+\.deb)$#Filename: ${SERVER_URL}/${REPOSITORY}/releases/download/${RELEASE_TAG}/\1#" \
  > work/new-Packages
printf '\n' >> Packages
cat work/new-Packages >> Packages
gzip --keep --force --best Packages
