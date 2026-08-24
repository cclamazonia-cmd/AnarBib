#!/usr/bin/env bash
#
# forgejo-runner-notify-failure.sh — appele par forgejo-runner-failure.service
# quand le runner Forgejo n'arrive pas a demarrer.
#
# CE FICHIER EST LA SOURCE DE VERITE — versionne. Voir deploy/ops/README.md.
#
# --------------------------------------------------------------------------
# POURQUOI UN SCRIPT PLUTOT QU'UN `ExecStart=/bin/sh -c '...'`
#
# Parce que le message ecrit dans le drapeau etait illisible. L'unite portait :
#
#     ExecStart=/bin/sh -c 'echo "... $(date -u +%Y-%m-%dT%H:%M:%SZ) ..." > ...'
#
# et systemd interprete les `%` DANS LES FICHIERS D'UNITE, avant que le shell ne
# voie quoi que ce soit. Le format de date n'est jamais parvenu a `date` :
#
#     %Y -> le dossier du fichier d'unite   (/etc/systemd/system)
#     %m -> l'identifiant machine           (e241810b51de4c7c9f9b21c22abdfacc)
#     %d -> le dossier de credentials       (/run/credentials/<unite>)
#     %H -> le nom d'hote                   (ACCATTONE)
#     %M -> rien, ce n'est pas un specificateur
#     %S -> la racine des state dirs        (/var/lib)
#
# d'ou l'horodatage observe le 24/08/2026 :
#   « /etc/systemd/system-e241810b51de4c7c9f9b21c22abdfacc-/run/credentials/
#     forgejo-runner-failure.serviceTACCATTONE::/var/libZ »
#
# On aurait pu doubler les `%` en `%%`. On ne l'a pas fait : cela laisse la
# prochaine personne a un caractere d'un message de panne illisible, dans le
# seul texte qu'on lise un jour ou quelque chose est casse. Un script ordinaire
# ne connait pas ces specificateurs — le probleme ne peut plus se poser.
# --------------------------------------------------------------------------
set -euo pipefail

FLAG="${FLAG:-/home/accattone/anarbib-ops/.last-failure-runner}"
UNITE="${1:-forgejo-runner.service}"

{
  echo "RUNNER FORGEJO EN ECHEC $(date -u +%Y-%m-%dT%H:%M:%SZ) — unite : $UNITE"
  echo "Cause la plus frequente : Docker injoignable."
  echo "  1. lancer Docker Desktop cote Windows"
  echo "  2. verifier l'integration WSL (Ubuntu-26.04) dans ses reglages"
  echo "  3. sudo systemctl start forgejo-runner"
  echo "--- 10 dernieres lignes du journal ---"
  journalctl -u "$UNITE" -n 10 --no-pager 2>&1 || echo "(journal indisponible)"
} > "$FLAG"

# Lisible par la personne qui ouvre un terminal, pas seulement par root : c'est
# ~/.bashrc qui affiche ce fichier, et il tourne sans privileges.
chmod 644 "$FLAG" 2>/dev/null || true
