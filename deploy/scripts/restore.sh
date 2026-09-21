#!/bin/sh
# =============================================================================
# AnarBib — restauration d'une sauvegarde sur une base vierge
# =============================================================================
# Procédure de reprise après sinistre. À dérouler sur un volume NEUF
# (docker compose down -v && docker compose up -d).
#
# Usage :
#   docker compose exec db sh /scripts/restore.sh
#
# Attend TROIS fichiers dans /dumps :
#   schema.sql     ← supabase db dump --linked -f deploy/dumps/schema.sql
#   data.sql       ← supabase db dump --linked --data-only -f deploy/dumps/data.sql
#   migrations.sql ← supabase db dump --linked --data-only --schema supabase_migrations \
#                      -f deploy/dumps/migrations.sql
#
# -----------------------------------------------------------------------------
# ⚠️ LE TROISIÈME FICHIER — L'HISTORIQUE DES MIGRATIONS (constaté le 21/09/2026)
# -----------------------------------------------------------------------------
# `supabase db dump` n'emporte PAS le schéma `supabase_migrations`, ni dans le
# dump du schéma ni dans celui des données : il faut le demander par son nom.
# Sans lui, l'instance restaurée est complète… et ne sait plus quelles
# migrations elle porte. La première mise à jour (`deploy/deploy.sh`) trouve un
# historique VIDE et entreprend de rejouer les migrations depuis le socle, sur
# une base pleine. Trouvé le 21/09 en restaurant un dump réel : l'échec est
# immédiat (« type "membership_payment_method" already exists »), donc sans
# dégât — mais l'instance ne pouvait plus JAMAIS être mise à jour.
#
# ⚠️ LES TROIS FICHIERS SE PRENNENT ENSEMBLE, SANS DÉPLOIEMENT ENTRE-TEMPS. Le
# 21/09, l'historique a été dumpé un quart d'heure après les données ; une
# migration était passée entre les deux. L'historique la déclarait appliquée,
# le schéma ne la portait pas : marquée « en place », elle n'aurait plus jamais
# été rejouée. Ordre conseillé : migrations.sql d'ABORD (30 s), puis schéma et
# données — une migration de trop dans le schéma se rejoue (elles sont écrites
# pour), une migration de trop dans l'historique se perd.
#
# ET LES CRONS ? Ils ne sont dans AUCUN des trois fichiers, et n'ont pas à y
# être : l'étape « 3 ter » appelle private.fn_crons_replanifier(), qui porte la
# liste et voyage dans le dump du schéma (I26, 21/09/2026).
#
# ⚠️ PAS DE DUMP PENDANT QU'UNE MIGRATION ATTEND EN CI : pg_dump tient un verrou
# de lecture sur toutes les tables, et un ALTER TABLE qui l'attend meurt sur le
# statement timeout (même jour, même séance).
#
# -----------------------------------------------------------------------------
# ⚠️ LE PIÈGE DES CLÉS ÉTRANGÈRES CIRCULAIRES
# -----------------------------------------------------------------------------
# La table `subjects` (thésaurus : termes génériques ↔ spécifiques) porte des
# clés étrangères circulaires. pg_dump le signale lui-même :
#
#   « there are circular foreign-key constraints on this table: subjects
#     You might not be able to restore the dump without using --disable-triggers »
#
# Un `psql -f data.sql` échouerait donc : aucune ligne ne peut être insérée en
# premier, chacune attendant l'autre.
#
# La parade est `SET session_replication_role = replica` : dans cette session,
# Postgres suspend les triggers ET la vérification des clés étrangères. Les
# contraintes restent en place et redeviennent actives ensuite — elles ne sont
# pas supprimées, seulement ignorées le temps du chargement.
# Cela exige d'être superutilisateur, d'où la connexion en supabase_admin.
#
# Constaté le 18/08/2026, première restauration.
# =============================================================================

DUMPS="${DUMPS:-/dumps}"
SU=""

for candidat in supabase_admin postgres; do
  if psql -U "$candidat" -d postgres -tAc "select 1" >/dev/null 2>&1; then
    SU="$candidat"; break
  fi
done

[ -z "$SU" ] && { echo "✗ Connexion à Postgres impossible."; exit 1; }

est_su=$(psql -U "$SU" -d postgres -tAc "select rolsuper from pg_roles where rolname = current_user")
if [ "$est_su" != "t" ]; then
  echo "✗ $SU n'est pas superutilisateur — la restauration des données échouera"
  echo "  (session_replication_role exige le superutilisateur)."
  exit 1
fi

[ -f "$DUMPS/schema.sql" ] || { echo "✗ $DUMPS/schema.sql introuvable."; exit 1; }
[ -f "$DUMPS/data.sql" ]   || { echo "✗ $DUMPS/data.sql introuvable.";   exit 1; }

echo "Connexion : $SU (superutilisateur)"
echo "─────────────────────────────────────────────"

# --- 1. Schéma --------------------------------------------------------------
echo "1/3  Schéma…"
debut=$(date +%s)
if psql -q -U "$SU" -d postgres -v ON_ERROR_STOP=1 -f "$DUMPS/schema.sql" >/dev/null 2>/tmp/restore_err; then
  echo "     OK"
else
  echo "     ÉCHEC"; echo ""; tail -n 15 /tmp/restore_err; exit 1
fi

# --- 2. Données, contraintes suspendues -------------------------------------
echo "2/3  Données (clés étrangères suspendues le temps du chargement)…"
{
  echo "SET session_replication_role = replica;"
  cat "$DUMPS/data.sql"
  echo "SET session_replication_role = origin;"
} | psql -q -U "$SU" -d postgres -v ON_ERROR_STOP=1 >/dev/null 2>/tmp/restore_err
if [ $? -eq 0 ]; then
  echo "     OK"
else
  echo "     ÉCHEC"; echo ""; tail -n 15 /tmp/restore_err; exit 1
fi
# --- 3. Vues matérialisées --------------------------------------------------
# Un dump ne transporte PAS le contenu des vues matérialisées : elles sont
# recréées vides. Sans ce rafraîchissement, la base est complète mais le
# catalogue s'affiche vide (erreur 55000). Constaté le 18/08/2026.
echo "3/3  Vues matérialisées…"
if [ -x /scripts/refresh-matviews.sh ] || [ -f /scripts/refresh-matviews.sh ]; then
  sh /scripts/refresh-matviews.sh | sed 's/^/     /'
else
  echo "     ⚠️  /scripts/refresh-matviews.sh introuvable — à lancer à la main."
fi

# --- 3 bis. Historique des migrations ---------------------------------------
# La table du dump porte les colonnes de la CLI Supabase récente (created_by,
# idempotency_key, rollback) ; celle que créent nos scripts n'en a que trois.
# On la crée donc ici dans sa forme LARGE avant de charger, sinon l'INSERT du
# dump échoue sur des colonnes inconnues.
echo "3 bis  Historique des migrations…"
if [ -f "$DUMPS/migrations.sql" ]; then
  psql -q -U "$SU" -d postgres -v ON_ERROR_STOP=1 >/dev/null 2>/tmp/restore_err <<'SQL'
CREATE SCHEMA IF NOT EXISTS supabase_migrations;
CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations (
  version text PRIMARY KEY, statements text[], name text);
ALTER TABLE supabase_migrations.schema_migrations
  ADD COLUMN IF NOT EXISTS created_by text,
  ADD COLUMN IF NOT EXISTS idempotency_key text,
  ADD COLUMN IF NOT EXISTS rollback text[];
GRANT ALL ON SCHEMA supabase_migrations TO postgres, supabase_admin;
GRANT ALL ON ALL TABLES IN SCHEMA supabase_migrations TO postgres, supabase_admin;
SQL
  if [ $? -eq 0 ] && psql -q -U "$SU" -d postgres -v ON_ERROR_STOP=1 -f "$DUMPS/migrations.sql" >/dev/null 2>/tmp/restore_err; then
    psql -U "$SU" -d postgres -tAc "select '     OK — ' || count(*) || ' migrations inscrites, dernière ' || max(version) from supabase_migrations.schema_migrations"
  else
    echo "     ÉCHEC"; echo ""; tail -n 15 /tmp/restore_err; exit 1
  fi
else
  echo "     ⚠️  $DUMPS/migrations.sql ABSENT."
  echo "     L'instance sera complète mais ne saura pas quelles migrations elle porte :"
  echo "     deploy/deploy.sh REFUSERA de la mettre à jour. Le reprendre à la source :"
  echo "       supabase db dump --linked --data-only --schema supabase_migrations -f deploy/dumps/migrations.sql"
  echo "     puis :  docker compose exec -T db psql -U supabase_admin -d postgres -f /dumps/migrations.sql"
  HISTORIQUE_ABSENT=1
fi

# --- 3 ter. Crons -----------------------------------------------------------
# `supabase db dump` n'emporte pas non plus le schéma `cron` : une instance
# restaurée portait ZÉRO job — ni rappel, ni moisson, ni gazette, ni sonde de
# santé — et, l'historique des migrations étant restauré, aucune migration ne
# les replanifiait. Constaté le 21/09/2026 (I26). La fonction voyage dans le
# dump avec le schéma ; elle ne touche qu'aux jobs absents ou différents.
echo "3 ter  Crons…"
if [ "$(psql -U "$SU" -d postgres -tAc "select to_regprocedure('private.fn_crons_replanifier()') is not null")" = "t" ]; then
  BILAN_CRONS=$(psql -U "$SU" -d postgres -tAc "select private.fn_crons_replanifier()" 2>/tmp/restore_err) || BILAN_CRONS=""
  case "$BILAN_CRONS" in
    *'"ok": true'*)
      psql -U "$SU" -d postgres -tAc "select '     OK — ' || count(*) || ' jobs planifiés, tous sous le rôle ' || string_agg(distinct username, ',') from cron.job"
      echo "     bilan : $(printf '%s' "$BILAN_CRONS" | cut -c1-300)" ;;
    *)
      echo "     ⚠️  Crons NON replanifiés : ${BILAN_CRONS:-$(tail -n 3 /tmp/restore_err)}"
      CRONS_ABSENTS=1 ;;
  esac
else
  echo "     ⚠️  private.fn_crons_replanifier() absente de ce dump (antérieur au 21/09/2026)."
  echo "     Appliquer les migrations en attente (deploy/deploy.sh --migrations), puis :"
  echo "       docker compose exec -T db psql -U supabase_admin -d postgres -c 'select private.fn_crons_replanifier()'"
  CRONS_ABSENTS=1
fi

fin=$(date +%s)

# --- 4. Contrôles -----------------------------------------------------------
echo "─────────────────────────────────────────────"
echo ""
echo "✓ Restauration terminée en $((fin - debut)) secondes."
echo ""
echo "Contrôles :"
psql -U "$SU" -d postgres -tAc "select '  tables publiques   : ' || count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r'"
psql -U "$SU" -d postgres -tAc "select '  sans RLS           : ' || count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity"
psql -U "$SU" -d postgres -tAc "select '  notices            : ' || count(*) from public.books" 2>/dev/null
psql -U "$SU" -d postgres -tAc "select '  comptes            : ' || count(*) from auth.users" 2>/dev/null
psql -U "$SU" -d postgres -tAc "select '  bibliotheques      : ' || count(*) from public.libraries" 2>/dev/null
echo ""
echo "Vérification des clés étrangères réactivées :"
psql -U "$SU" -d postgres -tAc "select '  session_replication_role = ' || current_setting('session_replication_role')"
echo ""
echo "« sans RLS » doit valoir 0, et les compteurs doivent correspondre à la production."
if [ "${CRONS_ABSENTS:-0}" = "1" ]; then
  echo ""
  echo "⚠️  Crons NON replanifiés (voir 3 ter) : cette instance n'enverra aucun rappel et ne se surveillera pas."
fi
if [ "${HISTORIQUE_ABSENT:-0}" = "1" ]; then
  echo ""
  echo "⚠️  Historique des migrations NON restauré (voir 3 bis) : à faire avant toute mise à jour."
fi
