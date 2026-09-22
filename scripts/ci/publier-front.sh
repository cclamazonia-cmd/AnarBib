#!/usr/bin/env bash
# =============================================================================
# AnarBib — construction et publication du front, hors de toute forge
# =============================================================================
# POURQUOI CE SCRIPT EXISTE. Le backend a son chemin hors forge depuis le 01/09
# (`scripts/ci/deployer-backend.sh`). Le front n'en avait pas : `npm run deploy`
# a été retiré à la bascule git-pages du 21/08, et la publication ne vivait plus
# que dans trois pas `uses: git-pages/action` du job `app` de ci.yml. Un runner
# hors ligne — il tourne sur le poste du mainteneur — suffisait donc à figer le
# site, sans aucun geste de repli écrit. Constaté le 21/09/2026.
#
# Ce fichier ne contient RIEN de neuf : l'action git-pages n'est qu'une image
# Docker (`git-pages-cli`) appelée avec six arguments. On l'appelle ici avec
# les mêmes. La liste des sites et la variable de visio sont tenues égales à
# celles de ci.yml par la garde `src/tests/publier-front-coherence.test.js`.
#
# CE QUE CE SCRIPT NE RÈGLE PAS. Il publie CHEZ Codeberg Pages. Si c'est la
# forge elle-même qui disparaît, l'hébergement du front disparaît avec elle :
# la réponse est alors `--vers-dossier` (un `dist/` à poser derrière n'importe
# quel serveur de fichiers statiques) ou la pile auto-hébergée, où Caddy sert
# `dist/` et où `deploy/deploy.sh --front` le reconstruit.
#
# USAGE
#   scripts/ci/publier-front.sh                     # construit + publie les trois sites
#   scripts/ci/publier-front.sh --simulation        # construit, montre ce qu'il publierait
#   scripts/ci/publier-front.sh --essai             # construit, fait VÉRIFIER l'autorisation
#                                                   # par le serveur, ne publie rien
#                                                   # (le --dry-run de git-pages-cli)
#   scripts/ci/publier-front.sh --sans-build        # publie le dist/ déjà là
#   scripts/ci/publier-front.sh --site https://app.anarbib.is/    # un seul site
#   scripts/ci/publier-front.sh --vers-dossier /srv/anarbib       # construit, copie, ne publie pas
#
# VARIABLES D'ENVIRONNEMENT
#   VITE_SUPABASE_URL              obligatoire pour construire
#   VITE_SUPABASE_PUBLISHABLE_KEY  obligatoire pour construire — ⚠️ `prebuild`
#                                  (instantané du catalogue + thésaurus SKOS)
#                                  fait `exit 0` si elle manque : sans cette
#                                  garde-ci, on publierait un instantané périmé
#                                  EN SILENCE.
#   GIT_PAGES_TOKEN                jeton d'accès Codeberg d'un compte qui peut
#                                  pousser sur anarbib/anarbib, avec DEUX
#                                  permissions : `repository` lecture-écriture ET
#                                  `user` lecture. Mesuré le 22/09/2026 : sans
#                                  `user`, git-pages demande GET /api/v1/user pour
#                                  savoir qui vous êtes, Codeberg répond 403 et le
#                                  serveur refuse — alors que le dépôt, lui, était
#                                  bien lisible et poussable. Jamais en argument,
#                                  jamais dans un fichier suivi : il se lit dans
#                                  l'environnement (sur le poste du mainteneur :
#                                  ~/anarbib-ops/git-pages.token, chmod 600, copie
#                                  dans Dashlane « Codeberg — jeton publier-front »).
#   GIT_PAGES_PASSWORD             autre voie d'autorisation de git-pages (défi
#                                  DNS), si le jeton de forge n'est pas disponible.
#
# ÉTAT AU 22/09/2026 : chemin emprunté de bout en bout. `--essai` accepté sur
# les trois sites (« dry-run ok »), puis une publication réelle sur
# app.anarbib.is (« result: replaced ») : le site a servi `.version-front`
# (fichier que seul ce script écrit) et le même bundle que le canonique. Le
# premier tir a été fait un jour calme ; c'est pour ça qu'il marchera un jour
# de panne.
# =============================================================================

set -uo pipefail

# ── Tenu égal à .forgejo/workflows/ci.yml par la garde vitest ────────────────
SITES_PAR_DEFAUT=(
  "https://app.anarbib.org/"
  "https://app.anarbib.is/"
  "https://app.anarbib.org.br/"
)
SERVEUR="codeberg.page"
export VITE_JITSI_DOMAIN="${VITE_JITSI_DOMAIN:-framatalk.org}"
# Version de git-pages-cli : celle qu'épingle l'action `git-pages/action@v2`.
CLI_IMAGE="${GIT_PAGES_CLI_IMAGE:-data.forgejo.org/git-pages/git-pages-cli:1.10.0}"

BUILD=1
SIMULATION=0
ESSAI=0
DOSSIER=""
SITES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --simulation)   SIMULATION=1 ;;
    --essai)        ESSAI=1 ;;
    --sans-build)   BUILD=0 ;;
    --site)         SITES+=("${2:-}"); shift ;;
    --vers-dossier) DOSSIER="${2:-}"; shift ;;
    -h|--help)      sed -n '2,49p' "$0"; exit 0 ;;
    *) echo "✗ Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done
[ "${#SITES[@]}" -eq 0 ] && SITES=("${SITES_PAR_DEFAUT[@]}")

RACINE=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "✗ Hors d'un dépôt git." >&2; exit 1; }
cd "$RACINE" || exit 1

dire() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

# ── 1. Construire ────────────────────────────────────────────────────────────
if [ "$BUILD" = "1" ]; then
  dire "Construction du front ($(git log -1 --format='%h %s' | cut -c1-70))"
  manque=""
  [ -z "${VITE_SUPABASE_URL:-}" ] && manque="$manque VITE_SUPABASE_URL"
  [ -z "${VITE_SUPABASE_PUBLISHABLE_KEY:-}" ] && manque="$manque VITE_SUPABASE_PUBLISHABLE_KEY"
  if [ -n "$manque" ]; then
    echo "✗ Variable(s) absente(s) :$manque" >&2
    echo "  Sans elles, prebuild sort en 0 et l'on publierait un instantané du" >&2
    echo "  catalogue périmé sans le savoir. On s'arrête." >&2
    exit 1
  fi
  if [ -n "$(git status --porcelain -- src public index.html package.json package-lock.json vite.config.js 2>/dev/null)" ]; then
    echo "⚠ La copie de travail porte des modifications non commitées : ce qui sera"
    echo "  construit n'est PAS le commit affiché ci-dessus."
  fi
  if [ ! -x node_modules/.bin/vite ] || [ package-lock.json -nt node_modules/.package-lock.json ]; then
    echo "→ npm ci"
    npm ci --no-audit --no-fund || { echo "✗ npm ci a échoué." >&2; exit 1; }
  fi
  npm run build || { echo "✗ npm run build a échoué." >&2; exit 1; }
fi

[ -f dist/index.html ] || { echo "✗ dist/index.html introuvable : rien à publier." >&2; exit 1; }
git rev-parse HEAD > dist/.version-front 2>/dev/null || true
echo "✓ dist/ prêt : $(find dist -type f | wc -l) fichiers, $(du -sh dist | cut -f1)"

# ── 2a. Copier vers un dossier (aucune forge en jeu) ─────────────────────────
if [ -n "$DOSSIER" ]; then
  dire "Copie vers $DOSSIER"
  mkdir -p "$DOSSIER" || exit 1
  # Les fichiers neufs d'abord, les périmés ensuite : un serveur qui lit ce
  # dossier ne doit jamais voir un index.html pointant vers un bundle absent.
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete-after dist/ "$DOSSIER"/ || exit 1
  else
    cp -a dist/. "$DOSSIER"/ || exit 1
    echo "⚠ rsync absent : les anciens fichiers n'ont pas été retirés de $DOSSIER."
  fi
  echo "✓ Copié. Rien n'a été publié."
  exit 0
fi

# ── 2b. Publier sur git-pages ────────────────────────────────────────────────
ECHECS=0
for site in "${SITES[@]}"; do
  dire "Publication : $site"
  if [ "$SIMULATION" = "1" ]; then
    echo "  [simulation] docker run --rm -v \"$RACINE/dist:/site:ro\" $CLI_IMAGE \\"
    echo "      $site --parents --server=$SERVEUR --token=*** --upload-dir=/site"
    continue
  fi
  if [ -z "${GIT_PAGES_TOKEN:-}" ] && [ -z "${GIT_PAGES_PASSWORD:-}" ]; then
    echo "✗ Ni GIT_PAGES_TOKEN ni GIT_PAGES_PASSWORD dans l'environnement." >&2
    exit 1
  fi
  command -v docker >/dev/null 2>&1 || { echo "✗ docker introuvable." >&2; exit 1; }
  # L'image n'a pas de shell (vérifié le 21/09 : entrypoint /bin/git-pages-cli,
  # rien d'autre) et la CLI ne lit le jeton que sur sa ligne de commande : il est
  # donc visible dans `ps` le temps du téléversement. Acceptable sur un poste à
  # un·e seul·e utilisateur·ice ; sur une machine partagée, préférer
  # GIT_PAGES_PASSWORD, qui passe par un fichier.
  args=("$site" --parents "--server=$SERVEUR" --upload-dir=/site)
  [ "$ESSAI" = "1" ] && args+=(--dry-run)
  montages=(-v "$RACINE/dist:/site:ro")
  if [ -n "${GIT_PAGES_TOKEN:-}" ]; then
    args+=("--token=$GIT_PAGES_TOKEN")
  else
    fichier_mdp=$(mktemp) && chmod 600 "$fichier_mdp" && printf '%s' "$GIT_PAGES_PASSWORD" > "$fichier_mdp"
    montages+=(-v "$fichier_mdp:/mdp:ro"); args+=(--password-file=/mdp)
  fi
  if docker run --rm "${montages[@]}" "$CLI_IMAGE" "${args[@]}"; then
    [ "$ESSAI" = "1" ] && echo "✓ $site — autorisation acceptée, rien publié (--essai)" || echo "✓ $site"
  else
    echo "✗ $site — publication refusée ou serveur injoignable." >&2
    ECHECS=$((ECHECS + 1))
  fi
  [ -n "${fichier_mdp:-}" ] && rm -f "$fichier_mdp"
done

if [ "$SIMULATION" = "1" ]; then
  echo; echo "Simulation : rien n'a été publié."; exit 0
fi

# Comme en CI, une route de repli en panne ne doit pas masquer le canonique —
# mais ici un humain regarde : on le dit, et le code de sortie le porte.
[ "$ECHECS" -eq 0 ] || { echo; echo "✗ $ECHECS site(s) non publié(s)." >&2; exit 1; }
[ "$ESSAI" = "1" ] && { echo; echo "Essai : autorisation vérifiée, rien n'a été publié."; exit 0; }

cat <<'FIN'

✓ Publié. LA SEULE PREUVE est qu'une modification apparaisse en ligne : le repli
  SPA rend 200 sur n'importe quel chemin, y compris /.git-pages/manifest.json.
  Vérifier le nom haché du bundle dans le index.html servi :
      curl -s https://app.anarbib.org/ | grep -o 'assets/index-[^"]*\.js'
      ls dist/assets | grep '^index-.*\.js$'
FIN
