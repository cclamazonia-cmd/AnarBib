#!/usr/bin/env bash
# =============================================================================
# deploy/scripts/essai-routeur-main.sh — les tests du routeur `main` (I3)
# =============================================================================
# Lance le routeur des Edge Functions SEUL, dans un conteneur jetable, comme la
# pile auto-hébergée le lance (deploy/compose.yml, service `functions`), puis
# passe les quatre tests de deploy/REPETITION.md §5 et trois contrôles de plus.
# Aucun secret réel : le secret JWT est tiré au hasard pour l'essai et oublié.
#
# Ce que ça prouve : la DÉCISION du routeur (404 / 401 / laisser passer).
# Ce que ça ne prouve pas : qu'une fonction répond 200 — elle a besoin de la
# base et de ses secrets, c'est la répétition complète (backlog I21).
#
# Usage (WSL ou Linux, docker + openssl + curl) :
#   bash deploy/scripts/essai-routeur-main.sh [tag edge-runtime, défaut v1.74.0]
# Sortie 0 si les sept décisions sont celles attendues, 1 sinon.
# Éprouvé le 27/09/2026 : 7/7, 40 fonctions dispensées, 54 montées.
# =============================================================================
set -u
TAG="${1:-v1.74.0}"
RACINE="$(cd "$(dirname "$0")/../.." && pwd)"
NOM=anarbib-essai-routeur
PORT=19000
U="http://localhost:$PORT"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
jeton() {   # jeton <secret> <iat> <exp>
  local h p s
  h=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
  p=$(printf '{"role":"anon","iss":"essai-routeur","iat":%s,"exp":%s}' "$2" "$3" | b64url)
  s=$(printf '%s.%s' "$h" "$p" | openssl dgst -sha256 -hmac "$1" -binary | b64url)
  printf '%s.%s.%s' "$h" "$p" "$s"
}

SECRET=$(openssl rand -hex 32)
AUTRE=$(openssl rand -hex 32)
MAINTENANT=$(date +%s)
BON=$(jeton "$SECRET" "$MAINTENANT" $((MAINTENANT + 3600)))
FAUX=$(jeton "$AUTRE" "$MAINTENANT" $((MAINTENANT + 3600)))
EXPIRE=$(jeton "$SECRET" $((MAINTENANT - 7200)) $((MAINTENANT - 3600)))

docker rm -f "$NOM" >/dev/null 2>&1
docker run -d --name "$NOM" -p "$PORT:9000" \
  -v "$RACINE/supabase/functions:/home/deno/functions:ro" \
  -v "$RACINE/supabase/config.toml:/home/deno/config.toml:ro" \
  -e SUPABASE_JWT_SECRET="$SECRET" -e SUPABASE_URL=http://localhost:1 -e SUPABASE_ANON_KEY=essai \
  -e VERIFY_JWT=false \
  "supabase/edge-runtime:$TAG" start --main-service /home/deno/functions/main >/dev/null || { echo "docker run a échoué"; exit 1; }
trap 'docker rm -f "$NOM" >/dev/null 2>&1' EXIT
for _ in $(seq 1 30); do docker logs "$NOM" 2>&1 | grep -q "fonction(s) montée(s)" && break; sleep 1; done
docker logs "$NOM" 2>&1 | grep -E '^\[main\]'

ok=0; total=0
essai() {   # essai <libellé> <verdict attendu : 404|401|passe> <curl…>
  local lib="$1" att="$2"; shift 2
  local code corps
  code=$(curl -s -o /tmp/essai-routeur-corps -w '%{http_code}' --max-time 60 "$@")
  corps=$(head -c 100 /tmp/essai-routeur-corps | tr '\n' ' ')
  total=$((total + 1))
  if { [ "$att" = passe ] && [ "$code" != 401 ] && [ "$code" != 404 ]; } || [ "$code" = "$att" ]; then
    ok=$((ok + 1)); echo "✅ $lib → $code"
  else
    echo "❌ $lib → $code (attendu : $att) $corps"
  fi
}
essai "1. nom inexistant"                         404   "$U/functions/v1/nexiste-pas"
essai "2. fonction dispensée (health-probe)"       passe -X POST "$U/functions/v1/health-probe"
essai "3. fonction protégée sans jeton"            401   "$U/functions/v1/cover_lookup"
essai "4. fonction protégée, jeton valide"         passe "$U/functions/v1/cover_lookup" -H "Authorization: Bearer $BON"
essai "5. jeton signé d'un autre secret"           401   "$U/functions/v1/cover_lookup" -H "Authorization: Bearer $FAUX"
essai "6. jeton expiré"                            401   "$U/functions/v1/cover_lookup" -H "Authorization: Bearer $EXPIRE"
essai "7. chemin sans /functions/v1"               401   "$U/cover_lookup"
echo "ROUTEUR : $ok/$total décisions attendues"
[ "$ok" = "$total" ]
