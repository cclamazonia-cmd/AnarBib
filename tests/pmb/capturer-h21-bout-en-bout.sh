#!/bin/bash
# =====================================================================
# Refait, depuis le banc SQL local, les deux fichiers figés de la suite de
# bout en bout (H21 lot 8) :
#   tests/pmb/h21-bout-en-bout-export.json  l'export d'AnarBib après le deuxième
#       import (T14), que src/tests/h21-bout-en-bout.test.js relit par l'analyse ;
#   tests/pmb/h21-bout-en-bout-ecran.json   les réponses des RPC de l'écran sur
#       le run 2, que src/tests/h21-lot8-ecran.test.jsx monte dans Importations.
# On ne les refait que quand l'import, la révision ou l'export change EXPRÈS —
# et on RELIT leur diff avant de les committer.
#
# Prérequis : la base de test reconstruite par scripts/ci/run-sql-suites.sh
# (migrations + seed), joignable par PGHOST/PGPORT/PGUSER/PGPASSWORD
# (PGDATABASE, anarbib_test par défaut) ; la suite engendrée à jour :
#   REGENERER_H21L8=1 npx vitest run src/tests/h21-bout-en-bout.test.js
# Puis réengendrer la suite (même commande) : elle embarque l'export figé.
# =====================================================================
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
SUITE=tests/sql/h21_bout_en_bout_tests.sql
TMP="$(mktemp)"
trap 'rm -f "$TMP" "$TMP.e" "$TMP.c"' EXIT
PGOPTIONS='-c anarbib.h21l8_capture=on' psql -h "$PGHOST" -d "${PGDATABASE:-anarbib_test}" -X -v ON_ERROR_STOP=0 -f "$SUITE" > "$TMP" 2>&1 || true
for quoi in EXPORT ECRAN; do
  if ! grep -q "H21L8-$quoi " "$TMP"; then
    echo "aucune capture $quoi — la suite a échoué avant :"
    grep -E 'ERROR|ECHEC' "$TMP" | cut -c1-2000
    exit 1
  fi
done
sed -n 's/.*NOTICE:  H21L8-EXPORT //p' "$TMP" \
  | node -e 'const a = JSON.parse(require("fs").readFileSync(0, "utf8"));
      if (!Array.isArray(a.records) || !a.records.length) { console.error("export vide : lot non publié"); process.exit(1); }
      process.stdout.write(JSON.stringify(a, null, 1) + "\n");' > "$TMP.e"
sed -n 's/.*NOTICE:  H21L8-ECRAN //p' "$TMP" \
  | node -e 'const a = JSON.parse(require("fs").readFileSync(0, "utf8"));
      if (!a.avant || !Array.isArray(a.avant.lignes) || !a.apres || !Array.isArray(a.apres.lignes)) { console.error("écran vide"); process.exit(1); }
      process.stdout.write(JSON.stringify(a, null, 1) + "\n");' > "$TMP.c"
mv "$TMP.e" tests/pmb/h21-bout-en-bout-export.json
mv "$TMP.c" tests/pmb/h21-bout-en-bout-ecran.json
echo "écrits : tests/pmb/h21-bout-en-bout-export.json, tests/pmb/h21-bout-en-bout-ecran.json"
grep -E 'H21-BOUT-EN-BOUT (OK|ECHEC)' "$TMP" | tail -1 | cut -c1-800
