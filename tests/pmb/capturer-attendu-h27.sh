#!/bin/bash
# =====================================================================
# Refait tests/pmb/aller-retour-attendu.json (H27) et
# tests/pmb/aller-retour-brouillons.json (H21 lot 2) depuis le banc SQL local.
#
# L'attendu est ce que la base exporte des deux fixtures PMB après import,
# promotion et publication (tests/sql/aller_retour_pmb_tests.sql, T3). On ne
# le refait que quand l'import ou l'export change EXPRÈS — et on RELIT son
# diff avant de le committer : c'est lui qui dit ce qu'AnarBib garde d'un
# catalogue PMB.
#
# Prérequis :
#   * la base de test reconstruite par scripts/ci/run-sql-suites.sh
#     (migrations + seed), joignable par PGHOST/PGPORT/PGUSER/PGPASSWORD ;
#   * la suite engendrée à jour :
#       REGENERER_H27=1 npx vitest run src/tests/pmb-aller-retour-base.test.js
# Puis, l'attendu refait, réengendrer la suite (même commande) : elle l'embarque.
# =====================================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
SUITE=tests/sql/aller_retour_pmb_tests.sql
SORTIE=tests/pmb/aller-retour-attendu.json
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
PGOPTIONS='-c anarbib.h27_capture=on' psql -h "$PGHOST" -d "${PGDATABASE:-anarbib_test}" -v ON_ERROR_STOP=0 -f "$SUITE" > "$TMP" 2>&1 || true
if ! grep -q 'H27-CAPTURE ' "$TMP"; then
  echo "aucune capture — la suite a échoué avant T3 :"
  grep -E 'ERROR|ECHEC' "$TMP" | cut -c1-2000
  exit 1
fi
# Une capture sans notice (lot non publié : T1 ou T2 en échec) n'écrase rien.
sed -n 's/.*NOTICE:  H27-CAPTURE //p' "$TMP" \
  | node -e 'const s = require("fs").readFileSync(0, "utf8"); const a = JSON.parse(s);
      if (!Array.isArray(a.records) || !a.records.length) { console.error("capture vide : lot non publié"); process.exit(1); }
      process.stdout.write(JSON.stringify(a, null, 1) + "\n");' \
  > "$TMP.json" || { grep -E '(OK|ECHEC) :' "$TMP" | tail -1 | cut -c1-2000; rm -f "$TMP.json"; exit 1; }
mv "$TMP.json" "$SORTIE"
echo "attendu écrit : $SORTIE ($(wc -c < "$SORTIE") octets)"
# H21 lot 2 (05/10/2026) : les brouillons que la promotion crée (T5). On ne les
# refait que quand la correspondance fichier → colonnes (ingest.fn_import_row_as_book)
# change EXPRÈS — et on relit leur diff : le lot 2 les a figés avec la définition
# d'avant pour prouver qu'il ne changeait rien à la création.
BROUILLONS=tests/pmb/aller-retour-brouillons.json
sed -n 's/.*NOTICE:  H27-BROUILLONS //p' "$TMP" \
  | node -e 'const s = require("fs").readFileSync(0, "utf8"); const a = JSON.parse(s);
      if (!Array.isArray(a) || !a.length) { console.error("brouillons vides : promotion en échec"); process.exit(1); }
      process.stdout.write(JSON.stringify(a, null, 1) + "\n");' \
  > "$TMP.b.json" || { rm -f "$TMP.b.json"; echo "brouillons non capturés"; exit 1; }
mv "$TMP.b.json" "$BROUILLONS"
echo "brouillons écrits : $BROUILLONS ($(wc -c < "$BROUILLONS") octets)"
grep -E '(OK|ECHEC) :' "$TMP" | tail -1 | cut -c1-800
