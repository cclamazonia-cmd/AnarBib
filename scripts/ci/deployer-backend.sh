#!/usr/bin/env bash
# =============================================================================
# AnarBib — deploiement du backend Supabase, hors de toute forge
# =============================================================================
# POURQUOI CE SCRIPT EXISTE. Tout le deploiement vivait dans le job `backend` de
# .forgejo/workflows/ci.yml : boucle sur les fonctions, garde-fous, retries,
# `db push`. Une suspension de Codeberg — ou simplement un runner hors ligne —
# emportait donc la capacite a deployer, et il fallait rejouer les commandes de
# memoire, au moment ou l'on a le moins le temps de les retrouver.
#
# Ce fichier ne contient RIEN de neuf : c'est le job `backend` extrait tel quel,
# garde-fous compris. ci.yml l'APPELLE desormais au lieu de le dupliquer — une
# seule copie, donc pas de derive possible entre ce qui tourne en CI et ce qu'on
# rejoue a la main. Changer de forge devient un changement d'adresse.
#
# USAGE
#   scripts/ci/deployer-backend.sh                      # fonctions + migrations
#   scripts/ci/deployer-backend.sh --fonctions          # fonctions seules
#   scripts/ci/deployer-backend.sh --migrations         # migrations seules
#   scripts/ci/deployer-backend.sh --depuis <SHA>       # saute les fonctions si
#                                                       # aucune n'a change depuis
#   scripts/ci/deployer-backend.sh --simulation         # n'appelle rien, montre
#   scripts/ci/deployer-backend.sh --use-api            # bundling cote serveur
#
# VARIABLES D'ENVIRONNEMENT
#   SUPABASE_ACCESS_TOKEN   obligatoire (sauf --simulation)
#   SUPABASE_PROJECT_REF    obligatoire (sauf --simulation)
#   SUPABASE_DB_PASSWORD    obligatoire pour les migrations
#
# ⚠️ DEPUIS CE POSTE (Windows/WSL), ajouter --use-api. Le bundling Docker par
# defaut echoue : Docker ne sait pas monter la jonction Windows -> WSL, et rend
# « entrypoint path does not exist ». Avec --use-api le bundling se fait cote
# serveur, et les dependances _shared/ sont televersees correctement.
# En CI (conteneur Linux), le defaut convient : on ne change donc rien la-bas.
# =============================================================================

set -uo pipefail

FONCTIONS=1
MIGRATIONS=1
DEPUIS=""
SIMULATION=0
USE_API=""
choix_explicite=0

while [ $# -gt 0 ]; do
  case "$1" in
    --fonctions)  [ "$choix_explicite" = "0" ] && { FONCTIONS=0; MIGRATIONS=0; choix_explicite=1; }; FONCTIONS=1 ;;
    --migrations) [ "$choix_explicite" = "0" ] && { FONCTIONS=0; MIGRATIONS=0; choix_explicite=1; }; MIGRATIONS=1 ;;
    --depuis)     DEPUIS="${2:-}"; shift ;;
    --simulation) SIMULATION=1 ;;
    --use-api)    USE_API="--use-api" ;;
    -h|--help)    sed -n '2,38p' "$0"; exit 0 ;;
    *) echo "✗ Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done

# Toujours travailler depuis la racine du depot, quel que soit le repertoire
# courant : les chemins ci-dessous sont relatifs et le script doit pouvoir etre
# appele de n'importe ou.
RACINE=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "✗ Hors d'un depot git : impossible de situer supabase/." >&2; exit 1; }
cd "$RACINE" || exit 1

dire() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

if [ "$SIMULATION" = "1" ]; then
  echo "⚠ SIMULATION : rien ne sera deploye. Aucun appel a Supabase."
else
  manquantes=""
  [ -z "${SUPABASE_ACCESS_TOKEN:-}" ] && manquantes="$manquantes SUPABASE_ACCESS_TOKEN"
  [ -z "${SUPABASE_PROJECT_REF:-}" ]  && manquantes="$manquantes SUPABASE_PROJECT_REF"
  if [ "$MIGRATIONS" = "1" ] && [ -z "${SUPABASE_DB_PASSWORD:-}" ]; then
    manquantes="$manquantes SUPABASE_DB_PASSWORD"
  fi
  if [ -n "$manquantes" ]; then
    echo "✗ Variable(s) d'environnement absente(s) :$manquantes" >&2
    echo "  Les poser avant de relancer. En CI, elles viennent des secrets de la forge." >&2
    exit 1
  fi
  command -v supabase >/dev/null 2>&1 || {
    echo "✗ CLI supabase introuvable dans le PATH." >&2
    echo "  curl -sLo /tmp/supabase.tar.gz https://github.com/supabase/cli/releases/download/v2.98.1/supabase_linux_amd64.tar.gz" >&2
    echo "  tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin/ && chmod +x /usr/local/bin/supabase" >&2
    exit 1
  }
  supabase link --project-ref "$SUPABASE_PROJECT_REF"
fi

ECHEC=0

# -----------------------------------------------------------------------------
# 1. Edge Functions
# -----------------------------------------------------------------------------
if [ "$FONCTIONS" = "1" ]; then
  dire "Edge Functions"

  # Le push touche-t-il seulement une fonction ? Les 47 fonctions sont
  # redeployees une par une (~5 min) meme quand le push ne contient que des
  # migrations. Vecu le 21/08 (run 8829551) : trois migrations poussees,
  # 47 fonctions redeployees pour rien.
  #
  # On ne saute QUE le cas « zero fichier modifie sous supabase/functions ».
  # Le raffinement « seulement les fonctions modifiees » est un piege : _shared/
  # est importe par presque toutes, et un ensemble affecte mal calcule
  # deploierait une fonction avec un module partage perime — bug invisible au
  # deploiement, visible des semaines plus tard.
  #
  # Si le SHA de depart est introuvable (branche neuve, force-push, historique
  # tronque), on NE saute PAS : mieux vaut cinq minutes perdues qu'une fonction
  # non deployee. En cas de doute, le defaut est de tout deployer.
  DEPLOYER_TOUT=1
  if [ -n "$DEPUIS" ] && [ "$DEPUIS" != "0000000000000000000000000000000000000000" ]; then
    git fetch --no-tags --depth=50 origin "$DEPUIS" >/dev/null 2>&1 || true
    if git rev-parse --verify -q "${DEPUIS}^{commit}" >/dev/null; then
      ICI="${GITHUB_SHA:-HEAD}"
      if [ -z "$(git diff --name-only "$DEPUIS" "$ICI" -- supabase/functions/)" ]; then
        DEPLOYER_TOUT=0
      fi
    else
      echo "→ SHA de depart $DEPUIS introuvable : on deploie tout (choix prudent)."
    fi
  fi

  if [ "$DEPLOYER_TOUT" = "0" ]; then
    echo "→ aucune fonction Edge modifiee depuis $DEPUIS — etape sautee"
    echo "✓ Edge Functions inchangees"
  else
    n_deployees=0
    for fn_dir in supabase/functions/*/; do
      fn_name=$(basename "$fn_dir")

      # _shared n'est pas une fonction : c'est le module importe par les autres.
      [ "$fn_name" = "_shared" ] && { echo "→ skip _shared (module partage)"; continue; }

      # ⚠️ GARDE-FOU A NE JAMAIS RETIRER. `main` est le routeur de la pile
      # AUTO-HEBERGEE (point d'entree de edge-runtime, cf. deploy/). Il n'a aucun
      # sens sur Supabase heberge, ou chaque fonction porte deja son URL :
      # deploye la, il lirait un supabase/config.toml absent et planterait au
      # demarrage. La boucle d'origine n'excluait que _shared et l'aurait envoye.
      [ "$fn_name" = "main" ] && { echo "→ skip main (routeur auto-heberge)"; continue; }

      [ -f "${fn_dir}index.ts" ] || { echo "→ skip $fn_name (pas d'index.ts)"; continue; }

      if [ "$SIMULATION" = "1" ]; then
        echo "→ (simulation) deploierait $fn_name"
        n_deployees=$((n_deployees + 1))
        continue
      fi

      echo "→ deploy $fn_name"
      # Retry par fonction : un 502 transitoire de Supabase sur UNE fonction ne
      # doit pas abattre tout le deploiement. 3 essais / 8 s.
      #
      # `timeout 180` : la boucle de retry ne peut RIEN contre un deploiement qui
      # HANG — la commande ne rend jamais la main, donc le `until` ne se
      # re-evalue jamais. Vecu le 17/08 (run #605) : hang sur
      # notify-network-weekly-report, job mort apres 1 h 06, 18 fonctions non
      # deployees. Un deploiement prend 1 a 3 s : 180 s est une marge enorme.
      n=0
      # shellcheck disable=SC2086
      until timeout 180 supabase functions deploy "$fn_name" --project-ref "$SUPABASE_PROJECT_REF" $USE_API; do
        n=$((n + 1))
        if [ "$n" -ge 3 ]; then
          echo "✗ deploy $fn_name echoue apres 3 tentatives"
          ECHEC=1
          break
        fi
        echo "↻ deploy $fn_name KO (tentative $n/3 — 502 transitoire ?) — retry 8 s…"
        sleep 8
      done
      [ "$ECHEC" = "1" ] && exit 1
      n_deployees=$((n_deployees + 1))
    done
    echo "✓ Edge Functions deployees ($n_deployees)"
  fi
fi

# -----------------------------------------------------------------------------
# 2. Migrations SQL
# -----------------------------------------------------------------------------
if [ "$MIGRATIONS" = "1" ]; then
  dire "Migrations SQL"
  if [ ! -d supabase/migrations ] || [ -z "$(ls -A supabase/migrations 2>/dev/null)" ]; then
    echo "→ aucune migration, rien a deployer"
  elif [ "$SIMULATION" = "1" ]; then
    nb=$(ls supabase/migrations/*.sql 2>/dev/null | grep -vc '/_')
    echo "→ (simulation) supabase db push --linked --include-all  ($nb migration(s) au depot)"
  else
    supabase db push --linked --include-all || { echo "✗ db push echoue"; exit 1; }
    echo "✓ migrations synchronisees"
    # Le vert d'un job ne prouve pas qu'une migration est appliquee (vecu le
    # 26/08 : push mixte doc+code, workflow non declenche, migration restee au
    # depot sans aucun rouge). Le seul controle qui vaut est en base.
    echo "  Controle : select max(version) from supabase_migrations.schema_migrations;"
  fi
fi

exit "$ECHEC"
