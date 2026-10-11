#!/bin/bash
# =============================================================================
# Les exports suivants du jeu de test, PAR PMB LUI-MÊME (H21 lot 8, 11/10/2026).
#
#   PMB_BASE_DEPART=~/pmb-banc/echange/sauvegardes/bibli-avant-cas-difficiles.sql \
#     bash tests/pmb/banc/deuxieme-export-h21.sh
#
# Le premier export (tests/pmb/fixtures/pmb-8.1.1.1_jeu-de-test.unimarc.iso) est
# le jeu de test de PMB tel qu'installé. Ce script rejoue, dans le PMB du banc,
# ce qu'une bibliothèque change entre deux exports, puis fait exporter PMB :
#
#   v2        h21-v2.sql                       → pmb-8.1.1.1_jeu-de-test-v2.unimarc.*
#   v2-seuil  h21-v2.sql puis h21-v2-seuil.sql → pmb-8.1.1.1_jeu-de-test-v2-seuil.unimarc.*
#   v3        h21-v2.sql puis h21-v3.sql       → pmb-8.1.1.1_jeu-de-test-v3.unimarc.*
#
# Chaque variante part de la base du PREMIER export : le fichier
# PMB_BASE_DEPART (mariadb-dump) — au banc, la sauvegarde prise juste après le
# premier export, avant l'import des cas difficiles (H25) — ou, sans lui, la
# base telle qu'elle est, qui doit alors être celle que laissent
# installer-pmb.sh et maj-base-pmb.sh, sans autre import. Pourquoi pas la base
# du banc telle qu'elle est le 11/10 : l'import des cas difficiles y a ajouté
# 14 notices (61 à 74 — une notice créée ici prendrait un autre numéro que
# dans les fixtures versées) et créé les indices Dewey 101 et 102, que les
# notices 58 et 59 du jeu de test désignaient sans qu'ils existent : le premier
# export n'avait pas de 676 pour elles, un export d'aujourd'hui en a un.
# La base du banc est sauvegardée au début et RESTAURÉE en sortant, même en
# cas d'échec. Export : celui de l'écran de PMB, par exporter-pmb.mjs
# (UNIMARC ISO2709, exemplaires inclus). La lecture yaz-marcdump (.txt) est
# écrite à côté de chaque fichier.
#
# Ce que PMB écrit de lui-même dans un export suivant (mesuré le 11/10) :
# la date de l'export (801 $c ; 100 $a des notices de bulletin), la date de
# mise à jour de la notice (009 $u) quand on la change, et rien d'autre ; une
# « notice de bulletin » (1-bull, 2-bull) n'est exportée que tant que son
# bulletin a un exemplaire.
#
# Les cas, un par un, et ce qu'AnarBib en fait : tests/pmb/h21-bout-en-bout-cas.json.
# Identifiants de banc (locaux) : MariaDB bibli / bibli (tests/pmb/README.md).
# =============================================================================
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
RACINE="$(cd "$ICI/../../.." && pwd)"
FIX="$RACINE/tests/pmb/fixtures"
DB="${PMB_DB_CONTENEUR:-pmb-banc-db-1}"
WEB="${PMB_WEB_CONTENEUR:-pmb-banc-web-1}"
ECH="${PMB_ECHANGE_DIR:-$HOME/pmb-banc/echange}"
OUT="$ECH/h21l8"
mkdir -p "$OUT"
Q() { docker exec "$DB" mariadb -ubibli -pbibli -N -B bibli -e "$1" 2>/dev/null; }

SAUVE="$OUT/avant-h21.sql"
docker exec "$DB" mariadb-dump -ubibli -pbibli --single-transaction bibli > "$SAUVE" 2>/dev/null \
  || { echo "sauvegarde impossible"; exit 1; }
AVANT="$(Q 'select count(*) from notices')/$(Q 'select count(*) from exemplaires')"
echo "sauvegarde : $SAUVE — notices/exemplaires avant : $AVANT"
DEPART="${PMB_BASE_DEPART:-$SAUVE}"
[ -f "$DEPART" ] || { echo "base de départ introuvable : $DEPART"; exit 2; }
restaurer() {
  local rc=$?
  docker exec -i "$DB" mariadb -ubibli -pbibli bibli < "$SAUVE" || true
  local apres
  apres="$(Q 'select count(*) from notices')/$(Q 'select count(*) from exemplaires')"
  echo "restauration : $apres (avant : $AVANT)"
  [ "$apres" = "$AVANT" ] || { echo "RESTAURATION À REFAIRE : docker exec -i $DB mariadb -ubibli -pbibli bibli < $SAUVE"; exit 3; }
  exit "$rc"
}
trap restaurer EXIT

variante() {
  local nom="$1"; shift
  docker exec -i "$DB" mariadb -ubibli -pbibli bibli < "$DEPART"
  for f in "$@"; do docker exec -i "$DB" mariadb -ubibli -pbibli bibli < "$ICI/$f"; done
  echo "$nom : $(Q 'select count(*) from notices') notices, $(Q 'select count(*) from exemplaires') exemplaires dans PMB"
  node "$ICI/exporter-pmb.mjs" "UNIMARC ISO2709" "$OUT/$nom-brut.iso"
  local cible="$FIX/pmb-8.1.1.1_jeu-de-test-$nom.unimarc"
  cp "$OUT/$nom-brut.iso" "$cible.iso"
  docker exec "$WEB" yaz-marcdump "/echange/h21l8/$nom-brut.iso" > "$cible.txt"
}

# Le témoin : la base de départ réexportée sans rien changer ne diffère du
# premier export que par la date de l'export (vérifié par le test de la
# fixture, src/tests/h21-bout-en-bout.test.js).
variante v1-reexport
variante v2 h21-v2.sql
variante v2-seuil h21-v2.sql h21-v2-seuil.sql
variante v3 h21-v2.sql h21-v3.sql
