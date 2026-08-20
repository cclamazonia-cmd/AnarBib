#!/usr/bin/env bash
# ===========================================================================
# run-sql-suites.sh — exécute les suites SQL d'acceptation en CI (job sql-tests).
# Session : tests SQL en CI (P1, 18/06/2026).
# ---------------------------------------------------------------------------
# Reconstruit une base de test JETABLE à partir des migrations (baseline +
# forward) puis y exécute les suites listées dans tests/sql/ci-suites.txt.
# 100 % local au CI : aucun accès à la prod.
#
# Le PROVISIONNEMENT du serveur Postgres est délégué à l'appelant (un `services:`
# Forgejo en CI, un conteneur docker en test local) ; ce script se contente de
# s'y CONNECTER en TCP via psql. Variables attendues :
#   PGHOST (requis) · PGPORT(=5432) · PGUSER(=postgres) · PGPASSWORD(=postgres)
#
# Pourquoi cette mécanique (et pas `supabase start`/`db reset`) :
#   * isolation/portabilité → pas de docker-in-docker, pas de collision de port ;
#   * on se connecte en TCP : le serveur d'AMORÇAGE de l'image supabase/postgres
#     (qui tourne le temps de ses init-scripts) n'écoute QUE sur le socket Unix →
#     injoignable en TCP ; nos connexions n'aboutissent donc qu'au serveur FINAL,
#     ce qui évite par construction de se faire tuer la session à son redémarrage ;
#   * base de test créée via `CREATE DATABASE … TEMPLATE template0` → n'hérite
#     d'AUCUN event trigger (notamment issue_pg_graphql_access, dont le contrôle
#     de version casse l'application massive du baseline en psql brut) ;
#   * le baseline est un dump --schema public,api,ingest,private : il SUPPOSE le
#     schéma `auth` (table users + helpers uid/role/jwt). On le stube AVANT via
#     tests/sql/_ci_setup_auth_stub.sql (helpers = définitions réelles Supabase,
#     donc le JWT simulé par les suites pilote aussi la RLS, fidèlement).
#
# Gate : une suite PASSE si sa sortie contient une ligne « … OK : N/N » (cf.
# convention de bilan, ci-suites.txt). ECHEC ou crash précoce → rouge.
# ===========================================================================
set -uo pipefail

cd "$(dirname "$0")/../.." || { echo "racine dépôt introuvable"; exit 2; }

: "${PGHOST:?PGHOST requis (hôte du serveur Postgres de test)}"
export PGHOST
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
ADMIN_DB="${PGADMIN_DB:-postgres}"   # base d'admin (pour CREATE DATABASE)
TEST_DB="anarbib_test"

AUTHSTUB="tests/sql/_ci_setup_auth_stub.sql"
VAULTSTUB="tests/sql/_ci_setup_vault_stub.sql"
STORAGESTUB="tests/sql/_ci_setup_storage_stub.sql"
SEED="supabase/seed.sql"
MANIFEST="${SQL_SUITES_MANIFEST:-tests/sql/ci-suites.txt}"

fail() { echo "ÉCHEC : $*" >&2; exit 1; }
command -v psql >/dev/null 2>&1 || fail "psql introuvable (installer postgresql-client)"
[ -f "$AUTHSTUB" ] || fail "stub auth absent : $AUTHSTUB"
[ -f "$VAULTSTUB" ] || fail "stub vault absent : $VAULTSTUB"
[ -f "$STORAGESTUB" ] || fail "stub storage absent : $STORAGESTUB"
[ -f "$SEED" ]     || fail "seed absent : $SEED"
[ -f "$MANIFEST" ] || fail "manifeste absent : $MANIFEST"

PADMIN() { psql -h "$PGHOST" -d "$ADMIN_DB" "$@"; }
PT()     { psql -h "$PGHOST" -d "$TEST_DB" "$@"; }

apply() { # label fichier  (sur $TEST_DB, ON_ERROR_STOP=1)
  local label="$1" f="$2"
  if ! PT -v ON_ERROR_STOP=1 -q -f "$f" > "/tmp/${label}.log" 2>&1; then
    echo "---- $label : 25 dernières lignes ----"; tail -25 "/tmp/${label}.log"
    fail "application de $f"
  fi
}

echo "::group::attente du serveur de test ($PGHOST:$PGPORT)"
ready=0
for i in $(seq 1 90); do
  if PADMIN -tAc 'select 1' >/dev/null 2>&1; then echo "serveur prêt après ${i}s"; ready=1; break; fi
  sleep 1
done
[ "$ready" -eq 1 ] || fail "serveur Postgres injoignable en TCP"
sleep 2  # marge de stabilisation
echo "::endgroup::"

echo "::group::reconstruction du schéma"
PADMIN -v ON_ERROR_STOP=1 -q -c "DROP DATABASE IF EXISTS $TEST_DB;" >/dev/null || fail "DROP DATABASE"
PADMIN -v ON_ERROR_STOP=1 -q -c "CREATE DATABASE $TEST_DB TEMPLATE template0;" >/dev/null || fail "CREATE DATABASE"
apply authstub "$AUTHSTUB"; echo "stub auth appliqué"
apply vaultstub "$VAULTSTUB"; echo "stub vault appliqué"
apply storagestub "$STORAGESTUB"; echo "stub storage appliqué"
# Toutes les migrations dans l'ordre lexicographique (baseline d'abord, puis
# forward). [0-9]* ignore _TEMPLATE.sql et tout fichier hors convention.
shopt -s nullglob
migs=(supabase/migrations/[0-9]*.sql)
shopt -u nullglob
[ "${#migs[@]}" -gt 0 ] || fail "aucune migration trouvée"
printf '%s\n' "${migs[@]}" | LC_ALL=C sort > /tmp/migs.sorted
n=0
while IFS= read -r m; do
  n=$((n+1)); apply "mig_$(printf '%03d' "$n")" "$m"
done < /tmp/migs.sorted
echo "${n} migration(s) appliquée(s) (baseline + forward)"
apply seed "$SEED"; echo "seed appliqué"
echo "::endgroup::"

# ---- exécution des suites (allowlist du manifeste) ------------------------
rc=0; ran=0
while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | tr -d '[:space:]')"
  [ -z "$line" ] && continue
  suite="$line"
  [ -f "$suite" ] || { echo "::error::suite introuvable : $suite"; rc=1; continue; }
  ran=$((ran+1))
  echo "::group::suite $suite"
  out="$(PT -v ON_ERROR_STOP=0 -f "$suite" 2>&1)"
  bilan="$(echo "$out" | grep -E '(OK|ECHEC) :' | tail -1)"
  if echo "$out" | grep -qE ' OK : [0-9]+/[0-9]+'; then
    echo "✅ PASS — ${bilan#*ERROR:  }"
  else
    echo "❌ FAIL — ${bilan:-<aucun bilan : crash précoce>}"
    echo "$out" | tail -25
    rc=1
  fi
  echo "::endgroup::"
done < "$MANIFEST"

[ "$ran" -gt 0 ] || fail "aucune suite exécutée (manifeste vide ?)"
echo "-------------------------------------------------------"
if [ "$rc" -eq 0 ]; then echo "✅ TOUTES LES SUITES SQL SONT VERTES ($ran)"; else echo "❌ AU MOINS UNE SUITE SQL EST ROUGE"; fi
exit "$rc"
