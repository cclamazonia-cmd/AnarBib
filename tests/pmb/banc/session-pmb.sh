#!/bin/bash
# Ouvre une session de gestion PMB (admin / admin, identifiants de banc) et
# laisse le bocal à cookies dans $PMB_COOKIES, pour les scripts qui suivent.
# À sourcer : `source tests/pmb/banc/session-pmb.sh`.
URL="${PMB_URL_BANC:-http://127.0.0.1:8088/pmb}"
export PMB_URL_BANC="$URL"
export PMB_COOKIES="${PMB_COOKIES:-$HOME/pmb-banc/echange/.cookies}"
mkdir -p "$(dirname "$PMB_COOKIES")"
rm -f "$PMB_COOKIES"
curl -fsS -c "$PMB_COOKIES" -b "$PMB_COOKIES" -o /dev/null "$URL/index.php"
curl -fsS -c "$PMB_COOKIES" -b "$PMB_COOKIES" -o /dev/null -L "$URL/main.php" \
  --data-urlencode "user=admin" --data-urlencode "password=admin" --data-urlencode "database=bibli"
if ! grep -q PhpMyBibli "$PMB_COOKIES"; then
  echo "session PMB : échec de connexion" >&2
  return 1 2>/dev/null || exit 1
fi
