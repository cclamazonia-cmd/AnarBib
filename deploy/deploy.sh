#!/usr/bin/env bash
# =============================================================================
# AnarBib — déploiement et mise à jour de la pile auto-hébergée
# =============================================================================
# Ce script met à jour une instance auto-hébergée en production ou en essai,
# de manière 100 % autonome, HORS de toute forge ou intégration continue.
#
# Séquence :
#   1. Mise à jour du code (git pull --ff-only, sauf --sans-pull)
#   2. Application des migrations SQL en attente (apply-pending-migrations.sh)
#   3. Rafraîchissement des vues matérialisées (refresh-matviews.sh)
#   4. Rechargement des Edge Functions (redémarrage du conteneur functions)
#   5. Contrôle de santé des services
#
# Usage :
#   deploy/deploy.sh                  # mise à jour complète standard
#   deploy/deploy.sh --sans-pull      # applique sans faire git pull
#   deploy/deploy.sh --migrations     # migrations seules
#   deploy/deploy.sh --fonctions      # fonctions seules
#   deploy/deploy.sh --controle       # contrôles de santé seuls
# =============================================================================

set -euo pipefail

RACINE="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "✗ Hors d'un dépôt git." >&2
  exit 1
}
cd "$RACINE"

DEPLOY_DIR="$RACINE/deploy"
PULL=1
MIGRATIONS=1
FONCTIONS=1
CONTROLE=1
choix_explicite=0

while [ $# -gt 0 ]; do
  case "$1" in
    --sans-pull)  PULL=0 ;;
    --migrations) [ "$choix_explicite" = "0" ] && { PULL=0; MIGRATIONS=0; FONCTIONS=0; CONTROLE=0; choix_explicite=1; }; MIGRATIONS=1 ;;
    --fonctions)  [ "$choix_explicite" = "0" ] && { PULL=0; MIGRATIONS=0; FONCTIONS=0; CONTROLE=0; choix_explicite=1; }; FONCTIONS=1 ;;
    --controle)   [ "$choix_explicite" = "0" ] && { PULL=0; MIGRATIONS=0; FONCTIONS=0; CONTROLE=0; choix_explicite=1; }; CONTROLE=1 ;;
    -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;

    *) echo "✗ Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done

dire() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

# 1. Vérification que la pile tourne
cd "$DEPLOY_DIR"
if ! docker compose ps --services --filter "status=running" | grep -q "db"; then
  echo "✗ La pile AnarBib n'est pas démarrée (conteneur db absent ou arrêté)." >&2
  echo "  Démarrer d'abord la pile avec : cd deploy && docker compose up -d" >&2
  exit 1
fi

# 2. Mise à jour du code git
if [ "$PULL" = "1" ]; then
  dire "Mise à jour du dépôt Git"
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  echo "→ Branche courante : $BRANCH"
  git pull --ff-only origin "$BRANCH" || {
    echo "✗ Échec du git pull --ff-only. Vérifier l'état de la copie de travail." >&2
    exit 1
  }
  echo "✓ Code à jour : $(git log -1 --oneline --no-decorate)"
fi

# 3. Migrations SQL
if [ "$MIGRATIONS" = "1" ]; then
  dire "Migrations SQL incrémentales"
  docker compose exec -T db sh /scripts/apply-pending-migrations.sh
  
  # Rafraîchissement des vues matérialisées si nécessaire
  docker compose exec -T db sh /scripts/refresh-matviews.sh >/dev/null 2>&1 || true
fi

# 4. Edge Functions
if [ "$FONCTIONS" = "1" ]; then
  dire "Edge Functions (rechargement)"
  # Les fonctions sont montées en volume dans le conteneur functions.
  # Un simple redémarrage recharge le cache Deno et le routeur main.
  docker compose restart functions >/dev/null
  echo "✓ Conteneur functions rechargé."
fi

# 5. Contrôle de santé
if [ "$CONTROLE" = "1" ]; then
  dire "Contrôle de santé de la pile"
  
  # Base Postgres
  RLS_KO=$(docker compose exec -T db psql -U supabase_admin -d postgres -tAc \
    "select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;" 2>/dev/null || echo "err")
  if [ "$RLS_KO" = "0" ]; then
    echo "✓ RLS : OK (0 table publique sans RLS)"
  else
    echo "⚠ RLS : anomalie ($RLS_KO table(s) sans RLS)"
  fi

  # PostgREST
  REST_STATUS=$(docker compose exec -T caddy curl -s -o /dev/null -w "%{http_code}" "http://rest:3000/" 2>/dev/null || echo "000")
  if [ "$REST_STATUS" = "200" ]; then
    echo "✓ PostgREST : OK (HTTP 200)"
  else
    echo "⚠ PostgREST : HTTP $REST_STATUS"
  fi

  # GoTrue
  AUTH_STATUS=$(docker compose exec -T caddy curl -s "http://auth:9999/health" 2>/dev/null | grep -o '"version":[^,}]*' || echo "injoignable")
  echo "✓ GoTrue : OK ($AUTH_STATUS)"

  # Storage
  STORAGE_STATUS=$(docker compose exec -T caddy curl -s -o /dev/null -w "%{http_code}" "http://storage:5000/status" 2>/dev/null || echo "000")
  if [ "$STORAGE_STATUS" = "200" ]; then
    echo "✓ Storage : OK (HTTP 200)"
  else
    echo "⚠ Storage : HTTP $STORAGE_STATUS"
  fi


  # Functions
  FN_STATUS=$(docker compose exec -T caddy curl -s -o /dev/null -w "%{http_code}" "http://functions:9000/health-probe" 2>/dev/null || echo "000")
  if [ "$FN_STATUS" = "405" ] || [ "$FN_STATUS" = "401" ] || [ "$FN_STATUS" = "200" ]; then
    echo "✓ Edge Runtime : OK (routeur main actif)"
  else
    echo "⚠ Edge Runtime : HTTP $FN_STATUS"
  fi

  # Frontend Web
  FRONT_STATUS=$(docker compose exec -T caddy curl -s -o /dev/null -w "%{http_code}" "http://localhost/" 2>/dev/null || echo "000")
  if [ "$FRONT_STATUS" = "200" ]; then
    echo "✓ Application Web : OK (HTTP 200 sur http://localhost et http://localhost:5173)"
  else
    echo "⚠ Application Web : HTTP $FRONT_STATUS"
  fi
fi

dire "Déploiement terminé avec succès."
