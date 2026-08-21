#!/usr/bin/env bash
# AnarBib — rafraichissement du miroir froid `anarbib-mirror.git`.
#
# CE QUE C'EST. Une copie bare complete du depot, posee hors de Codeberg et hors
# de WSL (elle vit sur le disque Windows). Son interet n'est pas d'etre a jour a
# la minute : c'est d'exister ailleurs le jour ou Codeberg ferme le compte, ou
# ou une manoeuvre efface une branche. Elle etait jusqu'ici rafraichie a la main,
# c'est-a-dire quand on y pensait.
#
# POURQUOI CE SCRIPT FAIT PLUS QU'UN `git remote update`. Un depot clone en
# --mirror porte un refspec FORCE (+refs/*:refs/*). Une reecriture d'historique
# en amont — rebase pousse en force, branche recreee — serait donc recopiee
# telle quelle, et la copie froide perdrait en silence ce qu'elle etait censee
# preserver. C'est le seul scenario ou un miroir automatique est PIRE qu'un
# miroir oublie : il propage le sinistre au lieu de le contenir.
#
# La parade tient en trois lignes : on note les SHA avant, on rafraichit, et on
# verifie que chaque ancien SHA est toujours un ANCETRE du nouveau. Si ce n'est
# pas le cas, l'historique a ete reecrit — le script le dit fort et sort en
# erreur, ce qui declenche la notification d'echec de l'unite systemd.
#
# Ce script ne modifie JAMAIS le depot amont. Il ne fait que lire.
set -uo pipefail

MIRROR="${ANARBIB_MIRROR:-/mnt/c/Users/accat/Codeberg/anarbib-mirror.git}"
REFS="main pages"

die()  { echo "ERREUR: $*" >&2; exit 1; }
info() { echo ">>> $*"; }

command -v git >/dev/null 2>&1 || die "git manquant"
[ -d "$MIRROR" ] || die "miroir introuvable: $MIRROR"
[ "$(git --git-dir="$MIRROR" rev-parse --is-bare-repository 2>/dev/null)" = "true" ] \
  || die "ce n'est pas un depot bare: $MIRROR"

url="$(git --git-dir="$MIRROR" remote get-url origin 2>/dev/null)" || die "pas de remote origin"
case "$url" in
  *codeberg.org/anarbib/anarbib*) : ;;
  *) die "remote inattendu ($url) — on ne rafraichit pas un miroir qu'on n'a pas reconnu" ;;
esac

info "Miroir : $MIRROR"
info "Amont  : $url"

# --- SHA avant ---------------------------------------------------------------
declare -A avant
for r in $REFS; do
  avant[$r]="$(git --git-dir="$MIRROR" rev-parse --verify --quiet "$r" || true)"
done

# --- rafraichissement --------------------------------------------------------
git --git-dir="$MIRROR" remote update --prune >/dev/null 2>&1 \
  || die "remote update a echoue (reseau ? droits ?)"

# --- controle de non-reecriture ---------------------------------------------
reecrit=0
for r in $REFS; do
  apres="$(git --git-dir="$MIRROR" rev-parse --verify --quiet "$r" || true)"
  vieux="${avant[$r]:-}"

  if [ -z "$apres" ]; then
    echo "!!! La reference '$r' a DISPARU en amont (elle valait ${vieux:-rien})." >&2
    reecrit=1; continue
  fi
  if [ -z "$vieux" ]; then
    info "$r : nouvelle reference, ${apres:0:8}"
    continue
  fi
  if [ "$vieux" = "$apres" ]; then
    info "$r : inchange (${apres:0:8})"
    continue
  fi
  if git --git-dir="$MIRROR" merge-base --is-ancestor "$vieux" "$apres"; then
    n="$(git --git-dir="$MIRROR" rev-list --count "$vieux..$apres")"
    info "$r : ${vieux:0:8} -> ${apres:0:8} (+$n commit(s))"
  else
    echo "!!! HISTORIQUE REECRIT sur '$r' : ${vieux:0:8} n'est plus un ancetre de ${apres:0:8}." >&2
    echo "!!! Le miroir vient de recopier cette reecriture. Si elle n'etait pas" >&2
    echo "!!! voulue, les objets d'avant sont encore la tant qu'aucun gc n'est" >&2
    echo "!!! passe : recuperer ${vieux:0:8} MAINTENANT." >&2
    reecrit=1
  fi
done

[ "$reecrit" -eq 0 ] || die "reecriture d'historique detectee — voir ci-dessus"

info "Miroir froid a jour. ($(du -sh "$MIRROR" 2>/dev/null | cut -f1))"
