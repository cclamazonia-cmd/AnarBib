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
#   5. Reconstruction du front servi par Caddy, si le code a changé (21/09/2026)
#   6. Contrôle de santé des services
#
# Usage :
#   deploy/deploy.sh                  # mise à jour complète standard
#   deploy/deploy.sh --sans-pull      # applique sans faire git pull
#   deploy/deploy.sh --migrations     # migrations seules
#   deploy/deploy.sh --fonctions      # fonctions seules
#   deploy/deploy.sh --front          # front seul (reconstruit même si rien n'a changé)
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
FRONT=1
FRONT_FORCE=0
CONTROLE=1
choix_explicite=0

while [ $# -gt 0 ]; do
  case "$1" in
    --sans-pull)  PULL=0 ;;
    --migrations) [ "$choix_explicite" = "0" ] && { PULL=0; MIGRATIONS=0; FONCTIONS=0; FRONT=0; CONTROLE=0; choix_explicite=1; }; MIGRATIONS=1 ;;
    --fonctions)  [ "$choix_explicite" = "0" ] && { PULL=0; MIGRATIONS=0; FONCTIONS=0; FRONT=0; CONTROLE=0; choix_explicite=1; }; FONCTIONS=1 ;;
    --front)      [ "$choix_explicite" = "0" ] && { PULL=0; MIGRATIONS=0; FONCTIONS=0; FRONT=0; CONTROLE=0; choix_explicite=1; }; FRONT=1; FRONT_FORCE=1 ;;
    --controle)   [ "$choix_explicite" = "0" ] && { PULL=0; MIGRATIONS=0; FONCTIONS=0; FRONT=0; CONTROLE=0; choix_explicite=1; }; CONTROLE=1 ;;
    -h|--help)    sed -n '2,22p' "$0"; exit 0 ;;

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

# 5. Front
#
# Jusqu'au 21/09/2026 ce script mettait à jour la base et les fonctions, JAMAIS
# le front : `install.sh` le construit une fois (« dist/ déjà prêt » ensuite),
# et une instance mise à jour servait donc indéfiniment le front du jour de son
# installation contre un backend du jour. Un écran qui appelle une RPC
# renommée, c'est une page blanche que rien ici ne signalait.
#
# Caddy monte `../dist` en lecture seule : on ne REMPLACE donc jamais le
# dossier (le montage suivrait l'ancien inode), on en synchronise le contenu —
# fichiers neufs d'abord, périmés ensuite, pour qu'aucun index.html servi ne
# pointe vers un bundle absent. `dist/.version-front` porte le commit construit.
if [ "$FRONT" = "1" ]; then
  dire "Front (dist/ servi par Caddy)"
  cd "$RACINE"
  TETE="$(git rev-parse HEAD)"
  CONSTRUIT="$(cat dist/.version-front 2>/dev/null || echo aucun)"
  if [ "$FRONT_FORCE" = "0" ] && [ "$CONSTRUIT" = "$TETE" ]; then
    echo "✓ Front déjà construit depuis ce commit (${TETE:0:8})."
  elif ! command -v npm >/dev/null 2>&1; then
    echo "⚠ npm introuvable : le front N'A PAS été reconstruit (il date de ${CONSTRUIT:0:8})."
    echo "  Base et fonctions sont à jour, l'interface ne l'est pas."
    FRONT_KO=1
  elif [ ! -f .env.local ]; then
    echo "⚠ .env.local absent (install.sh le pose) : front non reconstruit."
    FRONT_KO=1
  else
    if [ ! -x node_modules/.bin/vite ] || [ package-lock.json -nt node_modules/.package-lock.json ]; then
      echo "→ npm ci"
      npm ci --no-audit --no-fund >/dev/null || { echo "✗ npm ci a échoué." >&2; exit 1; }
    fi
    rm -rf dist.neuf
    # `--` transmet --outDir à `vite build` ; prebuild tourne comme d'habitude.
    if npm run build -- --outDir dist.neuf --emptyOutDir >/tmp/anarbib-front-build.log 2>&1 \
       && [ -f dist.neuf/index.html ]; then
      printf '%s\n' "$TETE" > dist.neuf/.version-front
      mkdir -p dist
      if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete-after dist.neuf/ dist/
      else
        cp -a dist.neuf/. dist/
        echo "  (rsync absent : les anciens bundles restent dans dist/ — sans effet, mais ils s'accumulent)"
      fi
      rm -rf dist.neuf
      echo "✓ Front reconstruit depuis ${TETE:0:8} (avant : ${CONSTRUIT:0:8})."
    else
      rm -rf dist.neuf
      echo "✗ La construction du front a échoué — dist/ n'a PAS été touché, l'ancien front reste servi."
      echo "  Journal : /tmp/anarbib-front-build.log"
      tail -5 /tmp/anarbib-front-build.log | sed 's/^/    /'
      FRONT_KO=1
    fi
  fi
  cd "$DEPLOY_DIR"
fi

# 6. Contrôle de santé
SANTE_OK=1
[ "${FRONT_KO:-0}" = "1" ] && SANTE_OK=0
if [ "$CONTROLE" = "1" ]; then
  dire "Contrôle de santé de la pile"
  
  # Front : ce que Caddy sert est-il le commit du dépôt ? (21/09/2026)
  FRONT_SERVI=$(docker compose exec -T caddy cat /srv/.version-front 2>/dev/null | tr -d '\r\n' || true)
  TETE_DEPOT=$(git -C "$RACINE" rev-parse HEAD)
  if [ -z "$FRONT_SERVI" ]; then
    echo "⚠ Front : version inconnue (dist/.version-front absent) — relancer deploy/deploy.sh --front"
    SANTE_OK=0
  elif [ "$FRONT_SERVI" = "$TETE_DEPOT" ]; then
    echo "✓ Front : construit depuis le commit du dépôt (${TETE_DEPOT:0:8})"
  else
    echo "⚠ Front : construit depuis ${FRONT_SERVI:0:8}, dépôt à ${TETE_DEPOT:0:8} — relancer deploy/deploy.sh --front"
    SANTE_OK=0
  fi

  # Base Postgres
  RLS_KO=$(docker compose exec -T db psql -U supabase_admin -d postgres -tAc \
    "select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;" 2>/dev/null || echo "err")
  if [ "$RLS_KO" = "0" ]; then
    echo "✓ RLS : OK (0 table publique sans RLS)"
  else
    echo "⚠ RLS : anomalie ($RLS_KO table(s) sans RLS)"
    SANTE_OK=0
  fi

  # PostgREST (/libraries évite de générer tout le schéma OpenAPI à froid)
  REST_STATUS=$(docker compose exec -T caddy curl -s -o /dev/null -w "%{http_code}" "http://rest:3000/libraries" 2>/dev/null || echo "000")
  if [ "$REST_STATUS" = "200" ]; then
    echo "✓ PostgREST : OK (HTTP 200)"
  else
    echo "⚠ PostgREST : HTTP $REST_STATUS"
    SANTE_OK=0
  fi

  # GoTrue
  AUTH_STATUS=$(docker compose exec -T caddy curl -s "http://auth:9999/health" 2>/dev/null | grep -o '"version":[^,}]*' || echo "injoignable")
  if [ "$AUTH_STATUS" != "injoignable" ]; then
    echo "✓ GoTrue : OK ($AUTH_STATUS)"
  else
    echo "⚠ GoTrue : injoignable"
    SANTE_OK=0
  fi

  # Storage
  STORAGE_STATUS=$(docker compose exec -T caddy curl -s -o /dev/null -w "%{http_code}" "http://storage:5000/status" 2>/dev/null || echo "000")
  if [ "$STORAGE_STATUS" = "200" ]; then
    echo "✓ Storage : OK (HTTP 200)"
  else
    echo "⚠ Storage : HTTP $STORAGE_STATUS"
    SANTE_OK=0
  fi

  # Functions
  FN_STATUS=$(docker compose exec -T caddy curl -s -o /dev/null -w "%{http_code}" "http://functions:9000/health-probe" 2>/dev/null || echo "000")
  if [ "$FN_STATUS" = "405" ] || [ "$FN_STATUS" = "401" ] || [ "$FN_STATUS" = "200" ]; then
    echo "✓ Edge Runtime : OK (routeur main actif)"
  else
    echo "⚠ Edge Runtime : HTTP $FN_STATUS"
    SANTE_OK=0
  fi

  # pg_cron — l'extension existe et les jobs attendus sont planifiés, eux seuls (I19).
  # Source de vérité : la suite tests/sql/crons_planifies_tests.sql, la même que
  # la CI rejoue sur le banc — ici elle interroge le VRAI cron.job de cette
  # instance, ce que le banc ne peut pas faire (son schéma cron est un stub).
  # La liste nommée vit dans la suite, pas ici (DOC-RECENS-1 : une seule liste).
  CRON_EXT=$(docker compose exec -T db psql -U supabase_admin -d postgres -tAc \
    "select count(*) from pg_extension where extname = 'pg_cron';" 2>/dev/null || echo "0")
  if [ "$CRON_EXT" != "1" ]; then
    echo "⚠ pg_cron : extension ABSENTE — aucun rappel, aucune moisson, aucun digest ne partira"
    SANTE_OK=0
  else
    CRON_JOBS=$(docker compose exec -T db psql -U supabase_admin -d postgres -tAc \
      "select count(*) from cron.job;" 2>/dev/null || echo "?")
    CRON_SUITE="$RACINE/tests/sql/crons_planifies_tests.sql"
    if [ -f "$CRON_SUITE" ]; then
      CRON_BILAN=$(docker compose exec -T db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=0 \
        -f /dev/stdin < "$CRON_SUITE" 2>&1 | grep -oE 'CRONS-PLANIFIES (OK|ECHEC) : .*' | head -n 1 | cut -c1-600)
      case "$CRON_BILAN" in
        "CRONS-PLANIFIES OK"*)
          # Le bilan vert porte aussi une note interne de la suite après « ; » : on la coupe.
          echo "✓ pg_cron : $CRON_JOBS jobs planifiés — $(printf '%s' "${CRON_BILAN#CRONS-PLANIFIES }" | sed 's/ ; .*//')" ;;
        "CRONS-PLANIFIES ECHEC"*)
          # Le bilan rouge nomme les jobs manquants, en trop ou décalés après « | » : on le garde entier.
          echo "⚠ pg_cron : $CRON_JOBS jobs planifiés, mais ${CRON_BILAN#CRONS-PLANIFIES }"
          echo "  Détail : docker compose exec -T db psql -U supabase_admin -d postgres -f /dev/stdin < tests/sql/crons_planifies_tests.sql"
          SANTE_OK=0 ;;
        *)
          echo "⚠ pg_cron : la suite crons_planifies n'a pas rendu de bilan ($CRON_JOBS jobs planifiés)"
          SANTE_OK=0 ;;
      esac
    elif [ "$CRON_JOBS" != "?" ] && [ "$CRON_JOBS" -gt 0 ]; then
      echo "✓ pg_cron : $CRON_JOBS jobs planifiés (suite tests/sql/crons_planifies_tests.sql absente : liste non vérifiée)"
    else
      echo "⚠ pg_cron : aucun job planifié ($CRON_JOBS)"
      SANTE_OK=0
    fi
  fi

  # Frontend Web
  FRONT_STATUS=$(docker compose exec -T caddy curl -s -o /dev/null -w "%{http_code}" "http://localhost/" 2>/dev/null || echo "000")
  if [ "$FRONT_STATUS" = "200" ]; then
    echo "✓ Application Web : OK (HTTP 200 sur http://localhost)"
  else
    echo "⚠ Application Web : HTTP $FRONT_STATUS"
    SANTE_OK=0
  fi
fi

if [ "$choix_explicite" = "1" ] && [ "$CONTROLE" = "1" ] && [ "$MIGRATIONS" = "0" ] && [ "$FONCTIONS" = "0" ]; then
  if [ "$SANTE_OK" = "1" ]; then
    dire "Contrôle de santé terminé avec succès."
    exit 0
  else
    echo "✗ Contrôle de santé : des anomalies ont été détectées." >&2
    exit 1
  fi
fi

if [ "$SANTE_OK" = "1" ]; then
  dire "Déploiement terminé avec succès."
  exit 0
else
  echo "⚠ Déploiement terminé avec des anomalies de santé." >&2
  exit 1
fi
