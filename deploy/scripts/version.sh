#!/usr/bin/env bash
# =============================================================================
# AnarBib — suivre une branche ou les versions stables (à sourcer)
# =============================================================================
# Décision de Xavier (17/10/2026) : une version stable environ chaque mois,
# nommée par la date — `vAAAA.MM` (v2026.10), `vAAAA.MM.N` pour un correctif
# dans le mois. Elle est posée sur un commit déjà déployé et vérifié par la CI
# (scripts/versions/publier-version.sh).
#
# Une instance suit l'un des deux canaux :
#   - « branche » : la copie est sur une branche (main) ; on la tire comme avant ;
#   - « version » : la copie est posée sur un tag v… (HEAD détaché) ; on passe à
#     la dernière version publiée, jamais à un commit intermédiaire.
# C'est la convention de l'ISO du camarade (ASR2026, anarbib-auto-update) : une
# machine placée sur un tag suit les tags, une machine sur une branche suit la
# branche. Rien ne fait basculer une instance d'un canal à l'autre sans qu'on le
# demande (`deploy.sh --version …` / `deploy.sh --branche …`).
#
# Fonctions (le répertoire courant doit être dans la copie git) :
#   derniere_version            la plus récente vAAAA.MM[.N], ou rien
#   version_courante            le tag v… posé sur HEAD, ou rien
#   canal_courant               « branche » ou « version »
#   mettre_a_jour_code [CIBLE]  CIBLE vide = suivre son canal ; « derniere » ou
#                               « vAAAA.MM[.N] » = aller à cette version ;
#                               « branche:NOM » = revenir sur la branche NOM.
# Garde : src/tests/versions-instance.test.js (dépôts git jetables).
# =============================================================================

MOTIF_VERSION='^v[0-9]{4}\.[0-9]{2}(\.[0-9]+)?$'

derniere_version() {
  git tag -l 'v*' --sort=-v:refname | grep -E "$MOTIF_VERSION" | head -n1 || true
}

version_courante() {
  git tag --points-at HEAD -l 'v*' --sort=-v:refname | grep -E "$MOTIF_VERSION" | head -n1 || true
}

canal_courant() {
  if git symbolic-ref -q HEAD >/dev/null; then echo branche; else echo version; fi
}

_copie_propre() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "✗ La copie de travail porte des modifications locales : mise à jour du code refusée." >&2
    git status --short | head -10 | sed 's/^/    /' >&2
    return 1
  fi
}

mettre_a_jour_code() {
  local cible="${1:-}" d c br
  git fetch -q --tags --force origin || { echo "✗ git fetch impossible (réseau, forge ?)." >&2; return 1; }
  case "$cible" in
    "")
      if [ "$(canal_courant)" = branche ]; then
        br="$(git symbolic-ref --short HEAD)"
        echo "→ Canal : branche $br"
        git pull -q --ff-only origin "$br" || { echo "✗ git pull --ff-only a échoué sur $br." >&2; return 1; }
      else
        d="$(derniere_version)"; c="$(version_courante)"
        echo "→ Canal : versions (actuelle : ${c:-aucune})"
        if [ -z "$d" ]; then
          echo "✗ Copie détachée hors de toute version, et aucune version v… publiée." >&2
          echo "  Revenir sur une branche : deploy/deploy.sh --branche main" >&2
          return 1
        fi
        if [ "$d" != "$c" ]; then
          _copie_propre || return 1
          git -c advice.detachedHead=false checkout -q "$d" || return 1
          echo "→ Passage à la version $d"
        else
          echo "→ Déjà sur la dernière version ($d)"
        fi
      fi ;;
    derniere|v*)
      [ "$cible" = derniere ] && cible="$(derniere_version)"
      if [ -z "$cible" ] || ! printf '%s' "$cible" | grep -qE "$MOTIF_VERSION" \
         || ! git rev-parse -q --verify "refs/tags/$cible" >/dev/null; then
        echo "✗ Version introuvable : ${1}. Publiées : $(git tag -l 'v*' --sort=-v:refname | grep -E "$MOTIF_VERSION" | head -5 | tr '\n' ' ')" >&2
        return 1
      fi
      _copie_propre || return 1
      git -c advice.detachedHead=false checkout -q "$cible" || return 1
      echo "→ Canal : versions — copie posée sur $cible" ;;
    branche:*)
      br="${cible#branche:}"
      _copie_propre || return 1
      git checkout -q "$br" || return 1
      git pull -q --ff-only origin "$br" || { echo "✗ git pull --ff-only a échoué sur $br." >&2; return 1; }
      echo "→ Canal : branche $br" ;;
    *)
      echo "✗ Cible inconnue : $cible (attendu : derniere, vAAAA.MM[.N] ou branche:NOM)" >&2
      return 2 ;;
  esac
}
