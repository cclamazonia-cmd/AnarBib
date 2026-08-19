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
# Attend deux fichiers dans /dumps :
#   schema.sql   ← supabase db dump --linked -f deploy/dumps/schema.sql
#   data.sql     ← supabase db dump --linked --data-only -f deploy/dumps/data.sql
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
