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
#   scripts/ci/deployer-backend.sh --marqueur           # compare a ce qui est
#                                                       # REELLEMENT deploye, et
#                                                       # avance le marqueur
#   scripts/ci/deployer-backend.sh --depuis <SHA>       # saute les fonctions si
#                                                       # aucune n'a change depuis
#   scripts/ci/deployer-backend.sh --simulation         # n'appelle rien, montre
#   scripts/ci/deployer-backend.sh --use-api            # bundling cote serveur
#
# VARIABLES D'ENVIRONNEMENT
#   SUPABASE_ACCESS_TOKEN   obligatoire (sauf --simulation)
#   SUPABASE_PROJECT_REF    obligatoire (sauf --simulation)
#   SUPABASE_DB_PASSWORD    obligatoire pour les migrations
#   MARQUEUR_NOM            nom du tag marqueur (defaut : deployed-functions)
#   MARQUEUR_TOKEN          jeton de secours pour POUSSER le marqueur, quand le
#                           checkout de la forge ne laisse pas de quoi le faire
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
MARQUEUR=0
NOM_MARQUEUR="${MARQUEUR_NOM:-deployed-functions}"
choix_explicite=0

while [ $# -gt 0 ]; do
  case "$1" in
    --fonctions)  [ "$choix_explicite" = "0" ] && { FONCTIONS=0; MIGRATIONS=0; choix_explicite=1; }; FONCTIONS=1 ;;
    --migrations) [ "$choix_explicite" = "0" ] && { FONCTIONS=0; MIGRATIONS=0; choix_explicite=1; }; MIGRATIONS=1 ;;
    --depuis)     DEPUIS="${2:-}"; shift ;;
    --marqueur)   MARQUEUR=1 ;;
    --simulation) SIMULATION=1 ;;
    --use-api)    USE_API="--use-api" ;;
    -h|--help)    sed -n '2,41p' "$0"; exit 0 ;;
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
# 0. Le marqueur : quel etat est REELLEMENT deploye ?
# -----------------------------------------------------------------------------
# Un tag leger `deployed-functions` sur origin porte le dernier commit dont les
# fonctions ont effectivement ete deployees. C'est la seule reference qui vaille
# pour decider d'un saut ; le pourquoi est raconte au bloc « Edge Functions ».
#
# origin fait autorite, jamais le depot local : on efface le tag local avant de
# le re-tirer. Sans cela, un marqueur pose ici mais dont la poussee a echoue
# (pas de reseau, pas de droits) survivrait en local et ferait sauter un
# deploiement au nom d'un etat qui n'a jamais ete publie.

# Le depot est-il superficiel (checkout `fetch-depth: 1`) ? On ne peut alors pas
# demander a git une histoire qu'il n'a pas ; et surtout, on ne doit PAS employer
# `--depth` sur un depot complet, qui le RACCOURCIRAIT — ce serait mutiler le
# clone de qui rejoue a la main.
depot_superficiel() {
  [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]
}

lire_marqueur() {
  git tag -d "$NOM_MARQUEUR" >/dev/null 2>&1

  local refspec="+refs/tags/${NOM_MARQUEUR}:refs/tags/${NOM_MARQUEUR}"
  if depot_superficiel; then
    # `--deepen=25` d'un seul coup : il ramene le tag ET recule la frontiere de
    # `main` de 25 commits. Le premier sert a DECIDER (comparaison d'arbres), le
    # second seulement a RACONTER (enumerer les commits couverts). Mesure du
    # 27/08 sur ce depot : ~1 Mo, 0,4 s — le journal ne coute rien.
    git fetch --deepen=25 --force origin "$refspec" \
      "+refs/heads/main:refs/remotes/origin/main" >/dev/null 2>&1 \
      || git fetch --deepen=25 --force origin "$refspec" >/dev/null 2>&1 \
      || git fetch --depth=1 --force origin "$refspec" >/dev/null 2>&1
  else
    git fetch --force origin "$refspec" >/dev/null 2>&1
  fi

  git rev-parse --verify -q "refs/tags/${NOM_MARQUEUR}^{commit}"
}

avertir_marqueur() {
  echo ""
  echo "⚠⚠ MARQUEUR NON MIS A JOUR — $1"
  echo "   Consequence : le prochain run ignorera ce qui vient d'etre deploye et"
  echo "   redeploiera TOUTES les fonctions (~5 min). C'est le bon sens de la"
  echo "   panne : on perd du temps, jamais un deploiement. Mais tant que cet"
  echo "   avertissement revient, l'optimisation est morte — il faut y aller voir."
  echo "   Cause habituelle : le checkout de la forge ne donne pas le droit de"
  echo "   POUSSER. Remede : poser le secret dans MARQUEUR_TOKEN (cf. ci.yml)."
  echo "   Rattrapage a la main, depuis un clone a jour :"
  echo "     git tag -f ${NOM_MARQUEUR} <sha-deploye> && git push --force origin refs/tags/${NOM_MARQUEUR}"
  echo ""
}

poser_marqueur() {
  local cible="$1"
  local court; court=$(git rev-parse --short "$cible" 2>/dev/null || echo "$cible")

  if [ "$(git rev-parse -q --verify "refs/tags/${NOM_MARQUEUR}^{commit}" 2>/dev/null)" = "$(git rev-parse "$cible")" ]; then
    echo "→ marqueur ${NOM_MARQUEUR} deja sur ${court}"
    return 0
  fi

  git tag -f "$NOM_MARQUEUR" "$cible" >/dev/null 2>&1 || {
    avertir_marqueur "impossible de poser le tag en local"
    return 1
  }

  local refspec="refs/tags/${NOM_MARQUEUR}:refs/tags/${NOM_MARQUEUR}"
  local erreur=""
  if erreur=$(git push --force origin "$refspec" 2>&1); then
    echo "✓ marqueur ${NOM_MARQUEUR} avance sur ${court}"
    return 0
  fi

  # Second essai avec un jeton explicite. Selon la forge et l'action de checkout,
  # les identifiants laisses dans .git/config donnent la LECTURE et pas toujours
  # l'ecriture. L'URL porte le jeton : elle ne doit jamais atteindre le journal.
  if [ -n "${MARQUEUR_TOKEN:-}" ] && [ -n "${GITHUB_SERVER_URL:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
    local hote="${GITHUB_SERVER_URL#http://}"; hote="${hote#https://}"; hote="${hote%/}"
    if git push --force \
         "https://x-access-token:${MARQUEUR_TOKEN}@${hote}/${GITHUB_REPOSITORY}.git" \
         "$refspec" >/dev/null 2>&1; then
      echo "✓ marqueur ${NOM_MARQUEUR} avance sur ${court} (via MARQUEUR_TOKEN)"
      return 0
    fi
  fi

  # Le tag local ne doit pas survivre a une poussee ratee : il mentirait au
  # prochain passage en pretendant qu'un etat non publie est deploye.
  git tag -d "$NOM_MARQUEUR" >/dev/null 2>&1
  avertir_marqueur "$(printf '%s' "$erreur" | head -c 300)"
  return 1
}

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
  # ⚠️ POURQUOI ON NE COMPARE PLUS A `github.event.before` (incident du
  # 27/08/2026). Cette optimisation supposait que chaque push obtient son propre
  # run. Ce n'est pas garanti. Deux pushes a deux minutes d'intervalle :
  # e316e005 (qui modifiait supabase/functions/register/index.ts) puis 1c3491fd
  # (une migration seule). Forgejo n'a cree AUCUN run pour e316e005 — la
  # numerotation saute de 826/827 a 828/829. Le run 828 a donc calcule son diff
  # « depuis e316e005 », n'y a vu aucune fonction, et a saute l'etape EN VERT.
  # `register` n'a jamais ete deployee alors que la CI etait entierement verte.
  # Rattrape a la main. L'echec etait muet et ressemblait exactement a un succes.
  #
  # Le meme angle mort avale les pushes ou le workflow ne se declenche pas du
  # tout (paths-ignore, cf. le commentaire en tete de ci.yml, 26/08).
  #
  # LA REPONSE : ne plus comparer a « ce qui precede ce push » — une notion qui
  # appartient a la forge et qu'elle peut escamoter — mais a CE QUI EST DEPLOYE,
  # qu'on ecrit soi-meme apres chaque deploiement reussi (--marqueur). Un run
  # manquant ne cree alors plus de trou : il repousse le travail au run suivant,
  # qui voit tout ce qui separe le marqueur de la tete.
  #
  # La decision compare des ARBRES (`git diff <marqueur> <tete>`), pas des
  # commits : une histoire reecrite ou tronquee ne peut pas la fausser, au pire
  # elle empeche d'ENUMERER les commits couverts — ce que le journal dit alors.
  #
  # Si le point de comparaison est introuvable (marqueur jamais pose, branche
  # neuve, force-push, historique tronque), on NE saute PAS : mieux vaut cinq
  # minutes perdues qu'une fonction non deployee. En cas de doute, tout deployer.
  ICI=$(git rev-parse --verify -q "${GITHUB_SHA:-HEAD}^{commit}" || git rev-parse HEAD)
  BASE=""
  ORIGINE_BASE=""

  if [ "$MARQUEUR" = "1" ]; then
    [ -n "$DEPUIS" ] && echo "⚠ --depuis $DEPUIS ignore : --marqueur fait autorite (incident du 27/08, ci-dessus)."
    if BASE=$(lire_marqueur); then
      ORIGINE_BASE="le marqueur ${NOM_MARQUEUR}"
    else
      BASE=""
      echo "→ marqueur ${NOM_MARQUEUR} absent d'origin : on deploie tout (premiere pose)."
    fi
  elif [ -n "$DEPUIS" ] && [ "$DEPUIS" != "0000000000000000000000000000000000000000" ]; then
    # Conserve pour le rejeu a la main (« redeploie ce qui a bouge depuis X »).
    # ⚠️ NE PAS remettre `--depuis "${{ github.event.before }}"` dans ci.yml :
    # c'est exactement le trou du 27/08 decrit ci-dessus.
    if depot_superficiel; then
      git fetch --no-tags --depth=50 origin "$DEPUIS" >/dev/null 2>&1 || true
    else
      git fetch --no-tags origin "$DEPUIS" >/dev/null 2>&1 || true
    fi
    if git rev-parse --verify -q "${DEPUIS}^{commit}" >/dev/null; then
      BASE="$DEPUIS"
      ORIGINE_BASE="le SHA passe par --depuis ($DEPUIS)"
    else
      echo "→ SHA de depart $DEPUIS introuvable : on deploie tout (choix prudent)."
    fi
  fi

  # Le journal doit DIRE ce que le diff couvre. Un trou dans la couverture reste
  # invisible tant que le journal se contente d'annoncer le resultat : le 27/08,
  # « aucune fonction Edge modifiee depuis e316e005 » etait litteralement vrai et
  # completement trompeur. On imprime donc les deux bornes, les commits compris
  # entre elles, et les fichiers qui ont bouge.
  DEPLOYER_TOUT=1
  if [ -n "$BASE" ]; then
    resume_commit() { git log -1 --format='%h %ad « %s »' --date=short "$1" 2>/dev/null || git rev-parse --short "$1"; }
    echo "→ reference (${ORIGINE_BASE}) : $(resume_commit "$BASE")"
    echo "→ tete a deployer : $(resume_commit "$ICI")"

    if git merge-base --is-ancestor "$BASE" "$ICI" 2>/dev/null; then
      echo "→ commits couverts par ce deploiement : $(git rev-list --count "$BASE..$ICI" 2>/dev/null)"
      git log --oneline --no-decorate "$BASE..$ICI" 2>/dev/null | sed 's/^/    /'
    else
      echo "→ ⚠ la reference n'est pas un ancetre de la tete (historique tronque,"
      echo "    force-push, ou autre branche) : commits non enumerables. La decision,"
      echo "    elle, reste juste : elle compare les arbres et non les commits."
    fi

    MODIFS=$(git diff --name-only "$BASE" "$ICI" -- supabase/functions/ 2>/dev/null)
    if [ -n "$MODIFS" ]; then
      echo "→ fichiers modifies sous supabase/functions/ :"
      printf '%s\n' "$MODIFS" | sed 's/^/    /'
    else
      DEPLOYER_TOUT=0
    fi
  fi

  if [ "$DEPLOYER_TOUT" = "0" ]; then
    echo "→ aucune fonction Edge modifiee depuis $ORIGINE_BASE — etape sautee"
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

  # Le marqueur n'avance QU'APRES un deploiement integralement reussi — ou apres
  # un saut, qui prouve l'egalite des arbres tout aussi surement. Un echec sort
  # plus haut par `exit 1` : le marqueur reste ou il est, et le run suivant
  # reprend le travail non fait. C'est tout le mecanisme.
  if [ "$MARQUEUR" = "1" ] && [ "$SIMULATION" = "0" ] && [ "$ECHEC" = "0" ]; then
    poser_marqueur "$ICI"
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
