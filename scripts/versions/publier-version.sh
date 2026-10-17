#!/usr/bin/env bash
# =============================================================================
# AnarBib — publier une version stable (vAAAA.MM), environ une fois par mois
# =============================================================================
# Décision de Xavier (17/10/2026) : une version stable environ chaque mois,
# posée par Claude sur son mot. Une version n'est JAMAIS un commit au hasard de
# main : c'est le dernier commit déployé et vérifié par la CI (le tag
# `deployed-functions`, posé par le job backend après les tests).
#
# Par défaut le script MONTRE seulement : le commit retenu, le nom, les notes.
# Avec --publier, il pose le tag annoté, le pousse sur Codeberg, crée la
# release (notes, sans fichier), puis recopie le miroir de l'ISO du camarade
# (scripts/miroirs/miroir-iso.sh, convenu le 17/10). Le tag sur GitHub se pousse
# ensuite depuis Windows (le jeton GitHub est dans wincred).
#
#   bash scripts/versions/publier-version.sh             # aperçu
#   bash scripts/versions/publier-version.sh --publier   # publication
#   bash scripts/versions/publier-version.sh --nom v2026.10.1 [--publier]
#
# Les instances qui suivent les versions la reçoivent à leur prochain
# deploy/deploy.sh (deploy/scripts/version.sh) ; celles qui suivent main ne
# bougent pas.
# =============================================================================
set -euo pipefail
RACINE="$(git rev-parse --show-toplevel)"; cd "$RACINE"
# shellcheck source=../../deploy/scripts/version.sh
. deploy/scripts/version.sh

PUBLIER=0; NOM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --publier) PUBLIER=1 ;;
    --nom) NOM="${2:-}"; shift ;;
    *) echo "✗ Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done

git fetch -q --tags --force origin
COMMIT="$(git rev-parse 'refs/tags/deployed-functions^{commit}')"
git merge-base --is-ancestor "$COMMIT" origin/main \
  || { echo "✗ deployed-functions ($COMMIT) n'est pas dans origin/main." >&2; exit 1; }
PREC="$(derniere_version)"
if [ -n "$PREC" ] && [ "$(git rev-parse "$PREC^{commit}")" = "$COMMIT" ]; then
  echo "Rien de neuf : $PREC est déjà posée sur le dernier commit déployé (${COMMIT:0:8})."; exit 0
fi
if [ -n "$PREC" ] && ! git merge-base --is-ancestor "$PREC" "$COMMIT"; then
  echo "✗ La version précédente $PREC n'est pas un ancêtre de ${COMMIT:0:8}." >&2; exit 1
fi

if [ -z "$NOM" ]; then
  NOM="v$(date +%Y.%m)"
  if git rev-parse -q --verify "refs/tags/$NOM" >/dev/null; then
    n=1; while git rev-parse -q --verify "refs/tags/$NOM.$n" >/dev/null; do n=$((n + 1)); done
    NOM="$NOM.$n"
  fi
fi
printf '%s' "$NOM" | grep -qE "$MOTIF_VERSION" || { echo "✗ Nom hors format vAAAA.MM[.N] : $NOM" >&2; exit 1; }
git rev-parse -q --verify "refs/tags/$NOM" >/dev/null && { echo "✗ $NOM existe déjà." >&2; exit 1; }

# ── Notes : nouveautés listées, corrections et le reste comptés ──────────────
if [ -n "$PREC" ]; then PLAGE=("$PREC..$COMMIT"); else PLAGE=(--since='1 month ago' "$COMMIT"); fi
SUJETS="$(git log --format='%s' "${PLAGE[@]}" | sed -E 's/ *\[(skip ci|CI SKIP)\]//I')"
FUSIONS="$(printf '%s\n' "$SUJETS" | sed -nE "s/^Merge pull request '(.*)' \(#([0-9]+)\).*/- \1 (#\2)/p")"
NOUVEAUTES="$(printf '%s\n' "$SUJETS" | grep -E '^feat(\(|:)' | sed -E 's/^feat(\(([^)]*)\))?: */- \2 : /; s/^-  : /- /' || true)"
NB_FIX="$(printf '%s\n' "$SUJETS" | grep -cE '^fix(\(|:)' || true)"
NB_TOUT="$(printf '%s\n' "$SUJETS" | grep -c . || true)"
NOTES="$(mktemp)"; trap 'rm -f "$NOTES"' EXIT
{
  echo "AnarBib $NOM — version stable du $(date +%d/%m/%Y)"
  echo
  echo "Posée sur ${COMMIT:0:8}, le dernier commit déployé et vérifié en production."
  [ -n "$PREC" ] && echo "Depuis $PREC : $NB_TOUT commits, dont $NB_FIX corrections." \
                 || echo "Première version stable ; le mois écoulé compte $NB_TOUT commits, dont $NB_FIX corrections."
  echo
  echo "Mettre à jour une instance qui suit les versions : deploy/deploy.sh"
  echo "Y passer depuis main : deploy/deploy.sh --version $NOM"
  if [ -n "$FUSIONS" ]; then echo; echo "Contributions fusionnées :"; printf '%s\n' "$FUSIONS"; fi
  if [ -n "$NOUVEAUTES" ]; then
    nb="$(printf '%s\n' "$NOUVEAUTES" | grep -c .)"
    echo; echo "Nouveautés ($nb) :"; printf '%s\n' "$NOUVEAUTES" | head -n 40
    [ "$nb" -gt 40 ] && echo "- … et $((nb - 40)) autres, dans le détail ci-dessous."
  fi
  echo
  if [ -n "$PREC" ]; then echo "Tout le détail : https://codeberg.org/AnarBib/anarbib/compare/$PREC...$NOM"
  else echo "Tout le détail : https://codeberg.org/AnarBib/anarbib/commits/tag/$NOM"; fi
} > "$NOTES"

echo "Version : $NOM   commit : $COMMIT   précédente : ${PREC:-aucune}"
echo "──────── notes ────────"; cat "$NOTES"; echo "───────────────────────"
if [ "$PUBLIER" = "0" ]; then echo "Aperçu seulement : relancer avec --publier."; exit 0; fi

git -c user.name=AnarBib -c user.email=x.vanwelden@gmail.com tag -a "$NOM" "$COMMIT" -F "$NOTES"
git push -q origin "refs/tags/$NOM"
echo "✓ Tag $NOM poussé sur Codeberg."

NETRC="$(mktemp)"; chmod 600 "$NETRC"; trap 'rm -f "$NOTES" "$NETRC"' EXIT
ligne="$(grep -m1 'codeberg.org' ~/.git-credentials)"; cred="${ligne#https://}"; cred="${cred%@codeberg.org*}"
printf 'machine codeberg.org login %s password %s\n' "${cred%%:*}" "${cred#*:}" > "$NETRC"
node -e '
  const fs = require("fs");
  const [tag, notes] = [process.argv[1], fs.readFileSync(process.argv[2], "utf8")];
  const lignes = notes.split("\n");
  console.log(JSON.stringify({ tag_name: tag, name: `AnarBib ${tag}`, body: lignes.slice(2).join("\n").trim(), draft: false, prerelease: false }));
' "$NOM" "$NOTES" > "$NOTES.json"
code="$(curl -s --netrc-file "$NETRC" -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  --data-binary @"$NOTES.json" https://codeberg.org/api/v1/repos/AnarBib/anarbib/releases)"
rm -f "$NOTES.json"
[ "$code" = "201" ] && echo "✓ Release $NOM créée." || echo "⚠ Release non créée (HTTP $code) — le tag existe, la créer à la main."

bash scripts/miroirs/miroir-iso.sh || echo "⚠ Miroir de l'ISO non recopié — relancer scripts/miroirs/miroir-iso.sh."
echo "Reste : pousser le tag sur GitHub depuis Windows (refs/tags/$NOM)."
