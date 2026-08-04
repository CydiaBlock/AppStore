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
awk -v RS='' -v ORS='\n\n' '
  function filename(block, lines, count, i, file) {
    count = split(block, lines, "\n")
    for (i = 1; i <= count; i++) {
      if (lines[i] ~ /^Filename: /) {
        file = lines[i]
        sub(/^Filename: /, "", file)
        return file
      }
    }
    return ""
  }
  FNR == NR {
    file = filename($0)
    if (file != "") replacement[file] = $0
    next
  }
  {
    file = filename($0)
    if (!(file in replacement)) print $0
  }
  END {
    for (file in replacement) print replacement[file]
  }
' work/new-Packages.direct Packages > work/merged-Packages
mv work/merged-Packages Packages
gzip --keep --force --best Packages
