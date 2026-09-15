#!/bin/sh
# =============================================================================
# AnarBib — mots de passe des rôles de service Postgres
# =============================================================================
# L'image supabase/postgres CRÉE les rôles de service (authenticator,
# supabase_auth_admin, supabase_storage_admin…) mais ne leur pose AUCUN mot de
# passe. Les services qui s'y connectent — PostgREST, GoTrue, Storage —
# échouent alors en boucle avec « password authentication failed » (SQLSTATE
# 28P01). Constaté à la première répétition, le 17/08/2026.
#
# ⚠️ DEUX PIÈGES, tous deux rencontrés le 17/08 :
#
#   1. Dans cette image, le rôle `postgres` N'EST PAS superutilisateur — c'est
#      `supabase_admin` qui l'est. Et `authenticator` est un rôle réservé :
#      « only superusers can modify it ». Il faut donc se connecter en
#      supabase_admin, pas en postgres.
#
#   2. Un `set -e` fait mourir la boucle au premier rôle en échec, et les
#      suivants ne sont jamais traités. Ici chaque rôle est traité
#      indépendamment, et le bilan est affiché à la fin.
#
# Monté dans /docker-entrypoint-initdb.d/ : s'exécute seul au premier démarrage
# d'un volume vierge. Sur un volume déjà initialisé, le lancer à la main :
#
#   docker compose exec db sh /docker-entrypoint-initdb.d/01-roles.sh
#
# Idempotent : le relancer ne casse rien.
# =============================================================================

if [ -z "$POSTGRES_PASSWORD" ]; then
  echo "✗ POSTGRES_PASSWORD absent de l'environnement — abandon."
  exit 1
fi

# --- Choix du compte de connexion : superutilisateur d'abord ----------------
SU=""
for candidat in supabase_admin postgres; do
  if psql -U "$candidat" -d postgres -tAc "select 1" >/dev/null 2>&1; then
    SU="$candidat"
    break
  fi
done

if [ -z "$SU" ]; then
  echo "✗ Impossible de se connecter à Postgres, ni en supabase_admin ni en postgres."
  exit 1
fi

echo "Connexion en tant que : $SU"
est_su=$(psql -U "$SU" -d postgres -tAc "select rolsuper from pg_roles where rolname = current_user")
if [ "$est_su" != "t" ]; then
  echo "⚠️  $SU n'est pas superutilisateur — les rôles réservés (authenticator)"
  echo "    ne pourront pas être modifiés."
fi
echo ""

ROLES="authenticator supabase_auth_admin supabase_storage_admin supabase_functions_admin supabase_read_only_user"

ok=""
ko=""
absents=""

for role in $ROLES; do
  existe=$(psql -U "$SU" -d postgres -tAc "select 1 from pg_roles where rolname = '$role'" 2>/dev/null)
  if [ "$existe" != "1" ]; then
    absents="$absents $role"
    continue
  fi
  if psql -U "$SU" -d postgres -v ON_ERROR_STOP=1 \
       -c "ALTER ROLE \"$role\" WITH LOGIN PASSWORD '$POSTGRES_PASSWORD';" >/dev/null 2>&1; then
    ok="$ok $role"
  else
    ko="$ko $role"
  fi
done

echo "─────────────────────────────────────────────"
[ -n "$ok" ]      && { echo "✓ mot de passe posé :"; for r in $ok; do echo "    $r"; done; }
[ -n "$absents" ] && { echo "· rôle absent, ignoré :"; for r in $absents; do echo "    $r"; done; }
[ -n "$ko" ]      && { echo "✗ ÉCHEC :"; for r in $ko; do echo "    $r"; done; }
echo "─────────────────────────────────────────────"

if [ -n "$ko" ]; then
  echo ""
  echo "Certains rôles n'ont pas pu être modifiés. Diagnostic :"
  echo "  docker compose exec db psql -U $SU -c \"\\du\""
  exit 1
fi

echo ""
echo "Rôles de service configurés. rest / auth / storage peuvent démarrer."

# --- Privilège par défaut : anon n'hérite plus d'EXECUTE (DOC-GRANT-3, A.1) --
# L'image pose `anon=X` dans le défaut des fonctions de `public` pour DEUX rôles
# (postgres et supabase_admin) : toute fonction du socle naîtrait ouverte à anon.
# On retire anon des deux entrées AVANT le rejeu, sans jamais vider une entrée
# (une entrée vide disparaît et le défaut natif PUBLIC=X revient — DOC-GRANT-1).
# Au premier passage (initdb), les rôles de l'image n'existent pas encore : on
# le dit et on diffère au rejeu de ce script par bootstrap.sh (étape 2).
if [ "$(psql -U "$SU" -d postgres -tAc "select 1 from pg_roles where rolname = 'anon'" 2>/dev/null)" != "1" ]; then
  echo "· Privilège par défaut : rôle anon absent à ce passage (scripts de l'image pas encore exécutés) — différé au prochain passage."
elif psql -U "$SU" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;
DO $$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN SELECT pg_get_userbyid(d.defaclrole) AS role, d.defaclacl::text AS acl
             FROM pg_default_acl d JOIN pg_namespace ns ON ns.oid = d.defaclnamespace
            WHERE ns.nspname = 'public' AND d.defaclobjtype = 'f'
              AND pg_get_userbyid(d.defaclrole) IN ('postgres','supabase_admin')
  LOOP
    n := n + 1;
    IF r.acl LIKE '%anon=%' THEN
      RAISE EXCEPTION 'A.1 : anon encore dans le défaut de % : %', r.role, r.acl;
    END IF;
  END LOOP;
  IF n <> 2 THEN
    RAISE EXCEPTION 'A.1 : % entrée(s) pg_default_acl au lieu de 2 — une entrée vidée a disparu (DOC-GRANT-1)', n;
  END IF;
END $$;
SQL
then
  echo "✓ Privilège par défaut : anon retiré des fonctions de public pour postgres et supabase_admin (entrées conservées)."
else
  echo "✗ Privilège par défaut : le retrait de anon a échoué." >&2
  exit 1
fi

# --- Initialisation de pg_cron ---------------------------------------------
# pg_cron est préchargé par l'image supabase/postgres (shared_preload_libraries).
# On crée l'extension dès l'initialisation pour que les migrations puissent
# planifier les crons réels (BG2-crons) au lieu de sauter la planification.
if [ "$(psql -U "$SU" -d postgres -tAc "select 1 from pg_roles where rolname = 'postgres'" 2>/dev/null)" = "1" ]; then
  echo ""
  echo "Initialisation de pg_cron..."
  if ! psql -U "$SU" -d postgres -v ON_ERROR_STOP=1 \
       -c "
CREATE EXTENSION IF NOT EXISTS pg_cron;
GRANT USAGE ON SCHEMA cron TO postgres, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA cron TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA cron TO postgres;
GRANT ALL ON ALL ROUTINES IN SCHEMA cron TO postgres;
"; then
    echo "✗ ÉCHEC de l'initialisation de pg_cron." >&2
    exit 1
  fi
  echo "✓ Extension pg_cron active (schéma cron prêt)."
else
  echo "· pg_cron : rôle postgres absent à ce passage (scripts de l'image pas encore exécutés) — différé au prochain passage."
fi


