#!/bin/bash
# =====================================================================
# Émet, depuis le banc SQL local, l'export complet des 64 notices des fixtures
# PMB (H27, critère 2) : le fichier que src/tests/essai-h27-pmb.test.js écrit
# ensuite en UNIMARC pour le réimport dans PMB.
#
#   bash tests/pmb/exporter-h27.sh ~/pmb-banc/echange/h27/export-h27.json
#
# La suite tests/sql/aller_retour_pmb_tests.sql émet l'export (NOTICE
# H27-EXPORT) AVANT de rendre son verdict : un export tiré d'une suite qui
# échoue (lot promu à moitié, export qui a dérivé de l'attendu, réémission
# perdue) mesurerait dans PMB autre chose que ce qu'AnarBib fait. Rien n'est
# écrit tant que le verdict n'est pas « ALLER-RETOUR-PMB OK » (revue du 28/09 :
# la recette d'avant jetait le verdict et écrasait l'export avant de le lire).
#
# Prérequis : la base de test reconstruite (scripts/ci/run-sql-suites.sh),
# joignable par PGHOST/PGPORT/PGUSER/PGPASSWORD ; la suite engendrée à jour
# (REGENERER_H27=1 npx vitest run src/tests/pmb-aller-retour-base.test.js).
# =====================================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
SORTIE="${1:?usage : exporter-h27.sh export-h27.json}"
SUITE=tests/sql/aller_retour_pmb_tests.sql
TMP="$(mktemp)"
trap 'rm -f "$TMP" "$TMP.json"' EXIT
PGOPTIONS='-c anarbib.h27_export=on' psql -h "$PGHOST" -d "${PGDATABASE:-anarbib_test}" -v ON_ERROR_STOP=0 -f "$SUITE" > "$TMP" 2>&1 || true
VERDICT="$(grep -E 'ALLER-RETOUR-PMB (OK|ECHEC)' "$TMP" | tail -1 | cut -c1-800)"
echo "${VERDICT:-aucun verdict : la suite n'a pas tourné jusqu'au bout}"
grep -q 'ALLER-RETOUR-PMB OK' "$TMP" || { grep -E 'ERROR|ECHEC' "$TMP" | head -5 | cut -c1-800; exit 1; }
sed -n 's/.*NOTICE:  H27-EXPORT //p' "$TMP" \
  | node -e 'const s = require("fs").readFileSync(0, "utf8"); const a = JSON.parse(s);
      if (!Array.isArray(a.records) || !a.records.length) { console.error("export vide : lot non publié"); process.exit(1); }
      process.stdout.write(s);' \
  > "$TMP.json"
mkdir -p "$(dirname "$SORTIE")"
mv "$TMP.json" "$SORTIE"
echo "export écrit : $SORTIE ($(wc -c < "$SORTIE") octets, $(node -e "console.log(require('$SORTIE').records.length)") notices)"
