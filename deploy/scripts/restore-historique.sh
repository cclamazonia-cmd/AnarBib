#!/bin/sh
# =============================================================================
# AnarBib — recharger le seul historique des migrations
# =============================================================================
# Pour une instance DÉJÀ restaurée sans son troisième fichier (cf. restore.sh,
# « 3 bis »), ou restaurée avant le 21/09/2026. Attend /dumps/migrations.sql :
#   supabase db dump --linked --data-only --schema supabase_migrations \
#     -f deploy/dumps/migrations.sql
# Usage :  docker compose exec -T db sh /scripts/restore-historique.sh
#
# ⚠️ Un historique PLUS RÉCENT que les données restaurées déclare faites des
# migrations que le schéma ne porte pas. Si un déploiement a eu lieu entre la
# sauvegarde et ce dump, retirer ensuite les versions postérieures :
#   delete from supabase_migrations.schema_migrations where version > '<dernière réellement en base>';
# puis `deploy/deploy.sh --migrations` les rejouera.
# =============================================================================
set -e
DUMPS="${DUMPS:-/dumps}"
[ -f "$DUMPS/migrations.sql" ] || { echo "✗ $DUMPS/migrations.sql introuvable."; exit 1; }
psql -q -U supabase_admin -d postgres -v ON_ERROR_STOP=1 >/dev/null <<'SQL'
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
N=$(psql -U supabase_admin -d postgres -tAc "select count(*) from supabase_migrations.schema_migrations")
if [ "$N" != "0" ]; then
  echo "✗ L'historique porte déjà $N ligne(s) : on ne recharge pas par-dessus."; exit 1
fi
psql -q -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -f "$DUMPS/migrations.sql" >/dev/null
psql -U supabase_admin -d postgres -tAc "select '✓ ' || count(*) || ' migrations inscrites, dernière ' || max(version) from supabase_migrations.schema_migrations"
