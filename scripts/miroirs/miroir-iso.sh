#!/usr/bin/env bash
# =============================================================================
# AnarBib — recopie du dépôt de l'ISO du camarade vers le compte AnarBib
# =============================================================================
# Source (fait foi) : https://codeberg.org/ASR2026/anarbib-debian-iso
# Copie            : https://codeberg.org/AnarBib/anarbib-debian-iso
#
# Codeberg n'autorise plus les miroirs automatiques (ils coûtaient trop de
# trafic et de disque) et conseille le miroir à la main : un clone local
# `--mirror`, recopié par `git push`. Décision de Xavier (17/10/2026) : la copie
# est faite à chaque version mensuelle d'AnarBib ; les ISO elles-mêmes (1,4 Go,
# fichiers de release) ne sont PAS copiées — quota Codeberg — seulement la
# recette (branches et tags). Accord du camarade le 17/10/2026.
#
# Jeton : ~/.config/anarbib/codeberg-miroir-iso (0600), limité en écriture au
# seul dépôt AnarBib/anarbib-debian-iso ; jamais affiché.
#
#   bash scripts/miroirs/miroir-iso.sh
# =============================================================================
set -euo pipefail
SOURCE=https://codeberg.org/ASR2026/anarbib-debian-iso.git
COPIE=https://codeberg.org/AnarBib/anarbib-debian-iso.git
LOCAL="${ANARBIB_MIROIR_ISO_DIR:-$HOME/miroirs/anarbib-debian-iso.git}"
JETON_F=~/.config/anarbib/codeberg-miroir-iso
[ -r "$JETON_F" ] || { echo "✗ Jeton absent : $JETON_F" >&2; exit 1; }

# Le jeton passe par GIT_ASKPASS : ni dans l'URL, ni dans la ligne de commande.
ASK=$(mktemp); chmod 700 "$ASK"; trap 'rm -f "$ASK"' EXIT
printf '#!/bin/sh\ncase "$1" in Username*) echo AnarBib ;; *) tr -d "[:space:]" < %q ;; esac\n' "$JETON_F" > "$ASK"

mkdir -p "$(dirname "$LOCAL")"
if [ -d "$LOCAL" ]; then
  git -C "$LOCAL" remote update --prune >/dev/null
else
  git clone -q --mirror "$SOURCE" "$LOCAL"
fi
# Branches et tags seulement : pas les références internes des PR de l'origine.
GIT_ASKPASS="$ASK" GIT_TERMINAL_PROMPT=0 git -c credential.helper= -C "$LOCAL" \
  push -q --prune "$COPIE" '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*'

s=$(git ls-remote "$SOURCE" refs/heads/main | cut -c1-8)
c=$(git ls-remote "$COPIE" refs/heads/main | cut -c1-8)
ts=$(git ls-remote --tags "$SOURCE" | grep -vc '\^{}' || true)
tc=$(git ls-remote --tags "$COPIE" | grep -vc '\^{}' || true)
if [ "$s" = "$c" ] && [ "$ts" = "$tc" ]; then
  echo "✓ Copie à jour : main $c, $tc tag(s)."
else
  echo "✗ Écart : main source $s / copie $c ; tags $ts / $tc." >&2; exit 1
fi
