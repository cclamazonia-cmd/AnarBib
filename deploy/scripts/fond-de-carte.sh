#!/usr/bin/env bash
# =============================================================================
# AnarBib — fond de carte d'une instance auto-hébergée (16/10/2026)
# =============================================================================
# Une instance neuve n'a pas de fond de carte : le bucket `map-tiles` est vide
# et les cartes n'affichent que leurs points (ticket #36 du camarade ASR2026,
# point 2). Décision de Xavier (15/10/2026) : chaque instance EXTRAIT son
# fichier depuis le planet public de Protomaps, au zoom qu'elle peut porter —
# jamais de relais vers le Storage de la production.
#
# Ce script enveloppe la recette du projet (scripts/maptiles/, voir son README)
# pour qu'elle vise CETTE instance et non la production :
#   - l'adresse et la clé viennent de deploy/.env (API_EXTERNAL_URL,
#     SERVICE_ROLE_KEY) — televerser-tus.mjs, seul, enverrait vers la prod ;
#   - un zoom autre que 13 est un autre nom d'objet (planet-z<N>.pmtiles) :
#     le script pose VITE_MAPTILES_URL dans .env.local et reconstruit le front.
#     Le front lit le zoom maximal dans l'en-tête du fichier (mapTiles.js) :
#     au-delà, il agrandit ce qu'il a au lieu d'afficher du vide.
#
# Tailles (planet du 07/09/2026) : z10 = 3,7 Go · z11 = 7,9 Go · z12 = 18 Go ·
# z13 = 36 Go (la production). Prévoir le double sur le disque pendant l'envoi
# (l'extrait local + la copie du Storage) ; l'extrait local est effacé après un
# envoi vérifié, sauf --garder.
#
#   deploy/scripts/fond-de-carte.sh                    # mesure seulement, z12
#   deploy/scripts/fond-de-carte.sh --zoom 11          # mesure, z11
#   deploy/scripts/fond-de-carte.sh --zoom 11 --extraire [--garder]
#
# Il faut le binaire `pmtiles` (go-pmtiles, BSD-3) :
#   https://github.com/protomaps/go-pmtiles/releases → ~/.local/bin/pmtiles
# =============================================================================
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RACINE="$(cd "$DEPLOY_DIR/.." && pwd)"
ZOOM=12
EXTRAIRE=0
GARDER=0
while [ $# -gt 0 ]; do
  case "$1" in
    --zoom)     ZOOM="${2:-}"; shift ;;
    --extraire) EXTRAIRE=1 ;;
    --garder)   GARDER=1 ;;
    -h|--help)  sed -n '2,31p' "$0"; exit 0 ;;
    *) echo "✗ Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done
case "$ZOOM" in
  8|9|10|11|12|13) ;;
  *) echo "✗ --zoom entre 8 et 13 (au-delà de 13, l'envoi TUS plafonne à 62,9 Go)." >&2; exit 2 ;;
esac

lire_env() { grep -E "^$1=" "$DEPLOY_DIR/.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'"'\r'; }
API="$(lire_env API_EXTERNAL_URL)"
CLE="$(lire_env SERVICE_ROLE_KEY)"
[ -n "$API" ] && [ -n "$CLE" ] || { echo "✗ API_EXTERNAL_URL ou SERVICE_ROLE_KEY absent de deploy/.env." >&2; exit 1; }
case "$API" in
  *supabase.co*) echo "✗ deploy/.env vise un projet hébergé ($API) : ce script est pour une instance auto-hébergée." >&2; exit 1 ;;
esac

PMTILES_BIN="${PMTILES:-pmtiles}"
command -v "$PMTILES_BIN" >/dev/null || { echo "✗ pmtiles introuvable — https://github.com/protomaps/go-pmtiles/releases" >&2; exit 2; }
command -v node >/dev/null || { echo "✗ node introuvable." >&2; exit 2; }

DEST="${DEST:-$DEPLOY_DIR/.fond-de-carte}"
OBJET="planet-z${ZOOM}.pmtiles"
echo "Instance : $API — objet map-tiles/$OBJET — dossier de travail : $DEST"

if [ "$EXTRAIRE" = "0" ]; then
  MAXZOOM="$ZOOM" DEST="$DEST" PMTILES="$PMTILES_BIN" bash "$RACINE/scripts/maptiles/extraire-planet.sh"
  df -h "$DEST" 2>/dev/null | tail -1 | awk '{print "Disque libre sous " $6 " : " $4}' || true
  exit 0
fi

# Extraction puis envoi TUS vers CETTE instance (VITE_SUPABASE_URL lu par televerser-tus.mjs).
VITE_SUPABASE_URL="$API" SUPABASE_SECRET_KEY="$CLE" MAXZOOM="$ZOOM" DEST="$DEST" PMTILES="$PMTILES_BIN" \
  bash "$RACINE/scripts/maptiles/extraire-planet.sh" --extraire --televerser

# Contrôle : l'objet servi répond en plage, et son en-tête dit le bon zoom.
URL="$API/storage/v1/object/public/map-tiles/$OBJET"
ENTETE="$(mktemp)"; trap 'rm -f "$ENTETE"' EXIT
CODE="$(curl -s -o "$ENTETE" -w '%{http_code}' -r 0-126 "$URL" || echo 000)"
ZMAX="$(node -e 'const b=require("fs").readFileSync(process.argv[1]); console.log(b.slice(0,7).toString()==="PMTiles" ? b[101] : "?")' "$ENTETE")"
if [ "$CODE" != "206" ] || [ "$ZMAX" != "$ZOOM" ]; then
  echo "✗ Contrôle : HTTP $CODE (206 attendu), zoom de l'en-tête $ZMAX (attendu $ZOOM). Extrait gardé dans $DEST."
  exit 1
fi
echo "✓ map-tiles/$OBJET servi en plages, zoom maximal $ZMAX."

if [ "$GARDER" = "0" ]; then
  rm -f "$DEST"/planet-z"${ZOOM}"-*.pmtiles "$DEST"/planet-z"${ZOOM}"-*.pmtiles.tus
  echo "✓ Extrait local effacé (--garder pour le conserver)."
fi

# Le front vise planet-z13.pmtiles par défaut : un autre zoom = une autre adresse.
if [ "$ZOOM" != "13" ]; then
  ENVL="$RACINE/.env.local"
  LIGNE="VITE_MAPTILES_URL=/storage/v1/object/public/map-tiles/$OBJET"
  if grep -q '^VITE_MAPTILES_URL=' "$ENVL" 2>/dev/null; then
    sed -i "s|^VITE_MAPTILES_URL=.*|$LIGNE|" "$ENVL"
  else
    printf '%s\n' "$LIGNE" >> "$ENVL"
  fi
  echo "✓ $LIGNE (dans .env.local) — reconstruction du front :"
  bash "$DEPLOY_DIR/deploy.sh" --front
fi
