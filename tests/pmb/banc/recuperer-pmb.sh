#!/bin/bash
# Télécharge l'archive officielle de PMB dans ~/pmb-banc/dl et vérifie sa somme.
# L'archive ne va jamais dans le dépôt (110 Mo) ; seul pmb.env la désigne.
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$ICI/pmb.env"
DL="${PMB_DL_DIR:-$HOME/pmb-banc/dl}"
mkdir -p "$DL"
ZIP="$DL/pmb${PMB_VERSION}.zip"
if [ ! -f "$ZIP" ]; then
  curl -fsSL -o "$ZIP.part" "$PMB_URL"
  mv "$ZIP.part" "$ZIP"
fi
echo "$PMB_SHA256  $ZIP" | sha256sum -c -
