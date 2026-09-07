#!/bin/bash
# =============================================================================
# extraire-planet.sh — fabrique (et, sur demande, téléverse) le fond de carte
# =============================================================================
# Extrait du planet Protomaps un fichier PMTiles limité à un zoom maximal, puis
# le téléverse dans le bucket public `map-tiles` du projet lié (CLI supabase).
# Lire scripts/maptiles/README.md avant : dimensions, licence, rythme.
#
# Usage :
#   bash scripts/maptiles/extraire-planet.sh                 # mesure seulement (--dry-run)
#   bash scripts/maptiles/extraire-planet.sh --extraire      # télécharge (~18 Go pour z12)
#   bash scripts/maptiles/extraire-planet.sh --extraire --televerser
#
# Variables (toutes optionnelles) :
#   BUILD=20260907     jour du build Protomaps (défaut : hier, UTC — le build du
#                      jour n'est pas toujours publié)
#   SUPABASE_SECRET_KEY=sb_secret_…   pour --televerser (ou ~/.config/anarbib/secret-key)
#   MAXZOOM=12         zoom maximal inclus (z12 = 18 Go, z13 = 36, z14 = 68, z15 = 138)
#   DEST=~/pmtiles     dossier de travail
#   PMTILES=pmtiles    binaire (https://github.com/protomaps/go-pmtiles/releases)
# =============================================================================
set -euo pipefail

BUILD="${BUILD:-$(date -u -d 'yesterday' +%Y%m%d)}"
MAXZOOM="${MAXZOOM:-12}"
DEST="${DEST:-$HOME/pmtiles}"
PMTILES="${PMTILES:-pmtiles}"
SRC="https://build.protomaps.com/${BUILD}.pmtiles"
OUT="$DEST/planet-z${MAXZOOM}-${BUILD}.pmtiles"
OBJET="planet-z${MAXZOOM}.pmtiles"     # nom STABLE dans le bucket (lu par src/lib/mapTiles.js)

command -v "$PMTILES" >/dev/null || { echo "pmtiles introuvable (PMTILES=$PMTILES)" >&2; exit 2; }
mkdir -p "$DEST"

echo "source  : $SRC"
echo "sortie  : $OUT"
if ! curl -sfI "$SRC" >/dev/null; then
  echo "build $BUILD introuvable chez Protomaps — essayer BUILD=<autre jour>" >&2; exit 3
fi

if [[ " $* " != *" --extraire "* ]]; then
  "$PMTILES" extract "$SRC" "$OUT" --maxzoom="$MAXZOOM" --dry-run
  echo "(mesure seulement ; relancer avec --extraire pour télécharger)"
  exit 0
fi

"$PMTILES" extract "$SRC" "$OUT" --maxzoom="$MAXZOOM" --download-threads=8
"$PMTILES" show "$OUT" | grep -E "max zoom|tile entries|planetiler:osm:osmosisreplicationtime"
ls -lh "$OUT"

if [[ " $* " == *" --televerser "* ]]; then
  # Pas `supabase storage cp` : envoi d'un seul tenant, refusé par Cloudflare
  # au-delà de quelques Go (413, vécu le 07/09/2026). TUS par morceaux de 6 Mio,
  # clé secrète dans SUPABASE_SECRET_KEY ou ~/.config/anarbib/secret-key (600).
  echo "téléversement TUS → map-tiles/$OBJET"
  node "$(dirname "$0")/televerser-tus.mjs" "$OUT" map-tiles "$OBJET" 604800
fi
