#!/usr/bin/env bash
# Appele par anarbib-backup-failure@.service quand un service de backup echoue.
# Argument $1 = nom de l'unit fautive (passe par %i).
set -euo pipefail
FAILED_UNIT="${1:-inconnu}"
FLAG="$HOME/anarbib-ops/.last-failure"
{
  echo "ECHEC $(date -u +%Y-%m-%dT%H:%M:%SZ) : $FAILED_UNIT"
  echo "--- 20 dernieres lignes du journal ---"
  journalctl --user -u "$FAILED_UNIT" -n 20 --no-pager 2>&1 || echo "(journal indisponible)"
} > "$FLAG"
