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
awk '/^Filename: / { print $2 }' Packages > work/known-files
awk -v RS='' -v ORS='\n\n' -v known=work/known-files '
  BEGIN {
    while ((getline file < known) > 0) seen[file] = 1
    close(known)
  }
  {
    file = ""
    count = split($0, lines, "\n")
    for (i = 1; i <= count; i++) {
      if (lines[i] ~ /^Filename: /) {
        file = lines[i]
        sub(/^Filename: /, "", file)
      }
    }
    if (file != "" && !seen[file]) {
      print $0
      seen[file] = 1
    }
  }
' work/new-Packages.direct > work/unique-Packages
if [ -s work/unique-Packages ]; then
  [ ! -s Packages ] || printf '\n' >> Packages
  cat work/unique-Packages >> Packages
fi
gzip --keep --force --best Packages
