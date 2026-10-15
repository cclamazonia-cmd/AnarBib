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
# Le stub `cron` reproduit l'INTERFACE de pg_cron (table job + schedule/
# unschedule/alter_job), jamais son service : il permet de vérifier qu'une
# migration PLANIFIE bien un job, et rien de plus. Lire son en-tête avant de
# lui faire dire davantage.
CRONSTUB="tests/sql/_ci_setup_cron_stub.sql"
SEED="supabase/seed.sql"
MANIFEST="${SQL_SUITES_MANIFEST:-tests/sql/ci-suites.txt}"
# Classement des tables pour la sauvegarde #BG2 (cf. filet plus bas). Source de
# vérité : ce fichier. ~/anarbib-ops/bg2-known-tables.txt est un lien vers lui.
KNOWN="deploy/bg2-known-tables.txt"

fail() { echo "ÉCHEC : $*" >&2; exit 1; }
# Fichiers de travail dans un dossier PROPRE à ce lancement (15/10/2026) : en
# chemins fixes sous /tmp, deux sessions qui jouaient leurs suites en même
# temps sur la machine de Xavier s'écrasaient migs.sorted — l'une appliquait
# la liste de migrations de l'autre (« No such file or directory »). En CI
# chaque job a son conteneur ; en local, non.
TMPD="$(mktemp -d)" || fail "mktemp -d"
trap 'rm -rf "$TMPD"' EXIT
command -v psql >/dev/null 2>&1 || fail "psql introuvable (installer postgresql-client)"
[ -f "$AUTHSTUB" ] || fail "stub auth absent : $AUTHSTUB"
[ -f "$VAULTSTUB" ] || fail "stub vault absent : $VAULTSTUB"
[ -f "$STORAGESTUB" ] || fail "stub storage absent : $STORAGESTUB"
[ -f "$CRONSTUB" ] || fail "stub cron absent : $CRONSTUB"
[ -f "$SEED" ]     || fail "seed absent : $SEED"
[ -f "$MANIFEST" ] || fail "manifeste absent : $MANIFEST"

PADMIN() { psql -h "$PGHOST" -d "$ADMIN_DB" "$@"; }
PT()     { psql -h "$PGHOST" -d "$TEST_DB" "$@"; }

apply() { # label fichier  (sur $TEST_DB, ON_ERROR_STOP=1)
  local label="$1" f="$2"
  if ! PT -v ON_ERROR_STOP=1 -q -f "$f" > "$TMPD/${label}.log" 2>&1; then
    echo "---- $label : 25 dernières lignes ----"; tail -25 "$TMPD/${label}.log"
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
apply cronstub "$CRONSTUB"; echo "stub cron appliqué"
# Ce que la plate-forme pose avant toute migration et qu'un dump n'emporte pas :
# le schéma `extensions` avec ses droits d'usage (ACL Supabase relevée en
# production le 28/09/2026 : anon, authenticated, service_role = USAGE). Sans
# lui, le premier parse d'une requête citant `extensions.*` sous anon lève 42501
# — vu par B32 : quand les vues du catalogue ont remplacé les enveloppes, le
# REFRESH d'une fixture a invalidé le plan compilé sous postgres, et le cache
# de plan a cessé de masquer l'absence du droit (opac_par_oeuvre T8).
PT -v ON_ERROR_STOP=1 -q -c "CREATE SCHEMA IF NOT EXISTS extensions; GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role;" || fail "droits plate-forme sur extensions"
echo "droits plate-forme (extensions) posés"
# Toutes les migrations dans l'ordre lexicographique (baseline d'abord, puis
# forward). [0-9]* ignore _TEMPLATE.sql et tout fichier hors convention.
shopt -s nullglob
migs=(supabase/migrations/[0-9]*.sql)
shopt -u nullglob
[ "${#migs[@]}" -gt 0 ] || fail "aucune migration trouvée"
printf '%s\n' "${migs[@]}" | LC_ALL=C sort > "$TMPD/migs.sorted"
n=0
while IFS= read -r m; do
  n=$((n+1)); apply "mig_$(printf '%03d' "$n")" "$m"
done < "$TMPD/migs.sorted"
echo "${n} migration(s) appliquée(s) (baseline + forward)"
apply seed "$SEED"; echo "seed appliqué"
echo "::endgroup::"

# ---- filet BG2 : toute table de `public` et d'`ingest` doit être classée ----
# PLAN_DE_MARCHE règle 6 : une table créée dans `public` BLOQUE la sauvegarde
# suivante tant qu'elle n'est pas classée — anarbib-bg2.sh y appelle `die`, il
# ne se contente pas d'avertir. Jusqu'ici la règle n'était qu'une discipline :
# le fichier de classement vivait hors dépôt (~/anarbib-ops/), donc RIEN ne
# l'appliquait. Vécu le 19/08/2026 : `altcha_consumed_challenges` est arrivée
# non classée et TOUTES les sauvegardes échouaient depuis, sans que personne le
# voie ; seule l'alarme de silence l'aurait dit, ~36 h plus tard.
# Le fichier est désormais dans le dépôt et ~/anarbib-ops/ pointe dessus par un
# lien symbolique : une seule copie, et la forge échoue sur LE commit fautif.
#
# BG2-13 (05/10/2026) : le flux long prend aussi le schéma `ingest`, et le
# filet classe donc les tables de `public` (nues) ET d'`ingest` (qualifiées :
# `ingest.<table>`). bg2_sql_tables et bg2_normaliser existent À L'IDENTIQUE
# dans deploy/ops/anarbib-bg2.sh : la forge et le poste lisent le même
# classement de la même façon (src/tests/bg2-ingest-flux-long.test.js compare
# les deux définitions et les exécute). Toute retouche se fait DES DEUX CÔTÉS.
bg2_sql_tables() {
  printf '%s\n' "select case when n.nspname = 'public' then c.relname else n.nspname || '.' || c.relname end
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname in ('public', 'ingest', 'private', 'api') and c.relkind in ('r', 'p')
 order by 1;"
}
bg2_normaliser() {
  sed -e 's/#.*$//' -e 's/[[:space:]]//g' | grep -v '^$' | LC_ALL=C sort -u || true
}
echo "::group::filet BG2 (classement des tables pour la sauvegarde)"
[ -f "$KNOWN" ] || fail "classement des tables absent : $KNOWN"
PT -At -c "$(bg2_sql_tables)" | bg2_normaliser > "$TMPD/bg2-real.txt"
[ -s "$TMPD/bg2-real.txt" ] || fail "filet BG2 : aucune table lue dans le schéma reconstruit"
bg2_normaliser < "$KNOWN" > "$TMPD/bg2-known.txt"
non_classees="$(comm -23 "$TMPD/bg2-real.txt" "$TMPD/bg2-known.txt")"
# Sens NON bloquant : une table classée mais absente du schéma reconstruit
# n'empêche aucune sauvegarde (le filet de anarbib-bg2.sh ne teste pas ce sens
# sur KNOWN, seulement sur la denylist). Simple signalement.
orphelines="$(comm -13 "$TMPD/bg2-real.txt" "$TMPD/bg2-known.txt")"
[ -z "$orphelines" ] || { echo "::warning::classées mais absentes du schéma reconstruit :"
  printf '%s\n' "$orphelines" | sed 's/^/    - /'; }
echo "::endgroup::"
if [ -n "$non_classees" ]; then
  echo "::error::tables NON CLASSÉES pour la sauvegarde :"
  printf '%s\n' "$non_classees" | sed 's/^/    - /'
  echo "  → ajoute-les à $KNOWN (table de public : nom nu ; d'ingest : ingest.<table>)."
  echo "    Si elles portent des données personnelles,"
  echo "    ajoute-les AUSSI à bg2-denylist.txt (côté ~/anarbib-ops/)."
  fail "filet BG2 : classe les nouvelles tables avant de fusionner."
fi
echo "filet BG2 OK : $(wc -l < "$TMPD/bg2-real.txt") tables, toutes classées"

# ---- budget de temps des mesures, à la charge de la machine ---------------
# Les suites de mesure (H21, H33, H34) exigent « < 8 s » par appel : c'est le
# statement_timeout du rôle authenticated en production, et le seuil a attrapé
# de vraies régressions (×7, ×10). Mais un seuil ABSOLU mesuré sur le poste du
# runner, partagé avec les autres sessions, rougit sur la seule charge : le
# 15/10 au soir, quatre runs sql-tests d'affilée sur T18b de h21_lot6b et T12
# de h34 (8 011, 10 576, 13 043 ms ; page à 8 596 ms) pour un code inchangé
# depuis le dernier vert, sous une charge moyenne de ~15 sur 8 cœurs (vitest de
# sessions parallèles, Postgres de banc, pile locale) — la mesure de référence
# de 200 lignes passait de 622 à 1 826 ms dans le même temps.
# D'où : juste avant chaque suite qui lit `anarbib.budget_ms`, on lit la charge
# (la plus haute de 1 et 5 min, rapportée au nombre de cœurs) et on pose
# 8 000 ms × ce facteur, borné à [1, 3]. Machine calme : 8 s, inchangé. Plafond
# 24 s : une régression d'un ordre de grandeur rougit toujours. La charge côté
# Windows ne se voit pas d'ici (seule celle de la VM WSL) : si un rouge de
# mesure revenait avec un facteur 1, c'est là qu'il faut regarder. Hors de ce
# script, la variable est absente et les suites retombent sur 8 000.
budget_mesures() { # → « budget_ms facteur charge cœurs »
  local cpus; cpus="$(nproc 2>/dev/null || echo 1)"
  if [ -r /proc/loadavg ]; then
    awk -v cpus="$cpus" '{ l = ($1 > $2) ? $1 : $2; f = l / cpus;
      if (f < 1) f = 1; if (f > 3) f = 3;
      printf "%d %.2f %.1f %d\n", 8000 * f, f, l, cpus }' /proc/loadavg
  else
    echo "8000 1.00 ? $cpus"
  fi
}

# ---- exécution des suites (allowlist du manifeste) ------------------------
rc=0; ran=0
while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | tr -d '[:space:]')"
  [ -z "$line" ] && continue
  suite="$line"
  [ -f "$suite" ] || { echo "::error::suite introuvable : $suite"; rc=1; continue; }
  ran=$((ran+1))
  echo "::group::suite $suite"
  # I25 (24/09) : le filet lit la sortie depuis un FICHIER, sans tube. L'ancienne forme
  # (`echo "$out" | grep -q …` sous `pipefail`) pouvait rendre FAIL sur une suite verte :
  # `grep -q` quitte à la première ligne « OK : », `echo` n'a pas fini d'écrire ce qui
  # suit (« ROLLBACK »), reçoit SIGPIPE, et `pipefail` fait du 141 de `echo` le verdict.
  # Reproduit hors CI le 24/09 (rare, dépend de l'ordonnancement). Sur FAIL, le journal
  # dit désormais le code de psql, celui de grep, le nombre de lignes « OK : » et la
  # taille de la sortie — de quoi nommer le maillon si un rouge revenait.
  out_f="$(mktemp)"
  suite_pgoptions="${PGOPTIONS:-}"
  if grep -q 'anarbib.budget_ms' "$suite"; then
    read -r b_ms b_f b_l b_c < <(budget_mesures)
    echo "⏱ budget des mesures : ${b_ms} ms (8 000 ms × ${b_f} — charge ${b_l} sur ${b_c} cœurs)"
    suite_pgoptions="${suite_pgoptions} -c anarbib.budget_ms=${b_ms}"
  fi
  PGOPTIONS="$suite_pgoptions" PT -v ON_ERROR_STOP=0 -f "$suite" > "$out_f" 2>&1; rc_psql=$?
  bilan="$(grep -E '(OK|ECHEC) :' "$out_f" | tail -1)"
  n_ok="$(grep -cE ' OK : [0-9]+/[0-9]+' "$out_f")"; rc_grep=$?
  if [ "${n_ok:-0}" -gt 0 ]; then
    echo "✅ PASS — ${bilan#*ERROR:  }"
  else
    echo "❌ FAIL — ${bilan:-<aucun bilan : crash précoce>}"
    echo "filet : psql rc=$rc_psql · grep rc=$rc_grep · lignes « OK : »=${n_ok:-?} · sortie $(wc -c < "$out_f") octets"
    tail -25 "$out_f"
    rc=1
  fi
  rm -f "$out_f"
  echo "::endgroup::"
done < "$MANIFEST"

[ "$ran" -gt 0 ] || fail "aucune suite exécutée (manifeste vide ?)"
echo "-------------------------------------------------------"
if [ "$rc" -eq 0 ]; then echo "✅ TOUTES LES SUITES SQL SONT VERTES ($ran)"; else echo "❌ AU MOINS UNE SUITE SQL EST ROUGE"; fi
exit "$rc"
