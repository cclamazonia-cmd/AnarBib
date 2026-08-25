#!/usr/bin/env bash
# Attend que le socket Docker (pont Docker Desktop <-> WSL) soit present et repondant.
# Sort 0 des que docker repond ; sort 1 apres timeout (Docker Desktop eteint ou
# integration WSL coupee). Appele en ExecStartPre du service forgejo-runner.
set -u
SOCK="/var/run/docker.sock"
TIMEOUT="${1:-120}"
elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  if [ -S "$SOCK" ] && docker version >/dev/null 2>&1; then
    echo "Docker joignable apres ${elapsed}s (socket + version OK)."
    exit 0
  fi
  sleep 3
  elapsed=$((elapsed + 3))
done
echo "TIMEOUT: Docker introuvable apres ${TIMEOUT}s (Docker Desktop eteint ? integration WSL coupee ?)." >&2
exit 1
