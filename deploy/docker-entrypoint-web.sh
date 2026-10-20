#!/bin/sh
set -e

# =============================================================================
# AnarBib — Point d'entrée de l'image anarbib/web (Zero-Build)
# =============================================================================
# 1. Injecte dynamiquement la clé anonyme Supabase (ANON_KEY) propre à l'instance
#    dans /srv/config.js si la variable est définie.
# 2. Écrit /srv/.version-front si la variable FRONT_COMMIT est fournie et que le
#    fichier est absent (nécessaire pour deploy/deploy.sh --controle).
# =============================================================================

if [ -n "$ANON_KEY" ]; then
  cat <<EOF > /srv/config.js
window.__ANARBIB_CONFIG__ = Object.assign(window.__ANARBIB_CONFIG__ || {}, {
  anonKey: "$ANON_KEY"
});
EOF
fi

if [ -n "$FRONT_COMMIT" ] && [ ! -f /srv/.version-front ]; then
  printf '%s\n' "$FRONT_COMMIT" > /srv/.version-front
fi

exec "$@"
