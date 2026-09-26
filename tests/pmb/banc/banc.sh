#!/bin/bash
# Enveloppe de `docker compose` pour le banc PMB : fixe la version (pmb.env) et
# les deux dossiers de l'hôte (archive, échanges), hors du dépôt.
#   bash tests/pmb/banc/banc.sh up -d --build
#   bash tests/pmb/banc/banc.sh down        # garde la base
#   bash tests/pmb/banc/banc.sh down -v     # repart de zéro
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
set -a; source "$ICI/pmb.env"; set +a
export PMB_DL_DIR="${PMB_DL_DIR:-$HOME/pmb-banc/dl}"
export PMB_ECHANGE_DIR="${PMB_ECHANGE_DIR:-$HOME/pmb-banc/echange}"
mkdir -p "$PMB_ECHANGE_DIR"
exec docker compose -f "$ICI/compose.yml" "$@"
