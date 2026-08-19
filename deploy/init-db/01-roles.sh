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
