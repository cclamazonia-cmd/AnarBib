#!/usr/bin/env bash
# =============================================================================
# deploy/scripts/banc-garage.sh — la réserve partagée Garage, éprouvée au banc
# =============================================================================
# Session : Gros fichiers hors site
#
# Monte trois nœuds Garage dans des conteneurs jetables, un par « lieu » (les
# zones lyon, lille, asr), comme la réserve partagée proposée le 22/10/2026
# (note « Sortir des services états-uniens » v4.3, §4 bis). Puis il vérifie ce
# que cette note avance sans l'avoir essayé :
#
#   1. restic écrit dans Garage (S3) et relit tout (check --read-data) ;
#   2. un lieu éteint n'empêche ni d'écrire ni de restaurer (deux sur trois) ;
#   3. le lieu revenu reçoit ce qu'il a manqué : chaque lieu porte une copie
#      ENTIÈRE (trois zones, trois copies) ;
#   4. deux lieux éteints : on ne peut plus rien faire — la limite, mesurée ;
#   5. le fond de carte servi par le point web : requêtes Range (206) et CORS,
#      comme le lit protomaps-leaflet dans le navigateur.
#
# Aucun secret réel : la passphrase restic, le secret RPC et les clés S3 sont
# tirés au hasard pour l'essai et oubliés. Les données sont un échantillon des
# PDF PUBLICS du miroir lourd, et un extrait du fond de carte (public aussi).
#
# Ce que ça prouve : la mécanique, sur une seule machine. Ce que ça ne prouve
# pas : le comportement sur de vraies liaisons Internet entre lieux (latence,
# débit montant), ni la tenue dans la durée.
#
# Usage (WSL ou Linux, docker + restic + curl + openssl) :
#   bash deploy/scripts/banc-garage.sh [tag garage, défaut v2.4.1] [Mo d'échantillon, défaut 500]
# Variables : BANC_PDF (dossier des PDF), BANC_CARTE (fichier PMTiles).
# Sortie 0 si tous les contrôles attendus passent, 1 sinon. Nettoie derrière lui.
#
# Éprouvé le 22/10/2026 (Garage v2.4.1, restic 0.18.1, WSL) : 17/17. 498 Mo de
# PDF écrits en 30 s et relus ; un lieu éteint, l'écriture et la restauration
# passent ; revenu, il rattrape (491 Mo dans chacun des trois lieux) ; deux
# lieux éteints, plus rien ne s'écrit NI ne se lit — à trois lieux, une
# restauration demande que deux d'entre eux répondent ; Range 206 et CORS
# (pré-vol compris) sur le point web. Mémoire au repos : 5 à 31 Mio par nœud.
# =============================================================================
set -u
TAG="${1:-v2.4.1}"
MO="${2:-500}"
IMAGE="dxflrs/garage:$TAG"
PDF="${BANC_PDF:-/mnt/d/anarbib-sauvegardes/miroir-lourd/anarbib-pdf-public}"
CARTE="${BANC_CARTE:-$(ls -1 /mnt/d/anarbib-sauvegardes/miroir-lourd/map-tiles/*.pmtiles 2>/dev/null | head -1)}"
RESEAU=anarbib-banc-garage
NOEUDS=(a b c)
declare -A ZONE=([a]=lyon [b]=lille [c]=asr)
declare -A PORT=([a]=39100 [b]=39200 [c]=39300)   # S3 = port, web = port+2
TMP="$(mktemp -d)"
REUSSI=0; ECHOUE=0

ok()    { echo "  OK      $*"; REUSSI=$((REUSSI + 1)); }
rate()  { echo "  ÉCHEC   $*"; ECHOUE=$((ECHOUE + 1)); }
etape() { echo; echo "== $*"; }
g()     { docker exec -e RUST_LOG=warn "garage-$1" /garage "${@:2}"; }
# L'image Garage n'a ni shell ni du : la taille d'un lieu se lit depuis un conteneur jetable.
taille_mo() { docker run --rm -v "garage-banc-$1:/v:ro" alpine:3.20 du -sm /v/data 2>/dev/null | cut -f1; }
taille_h()  { docker run --rm -v "garage-banc-$1:/v:ro" alpine:3.20 du -sh /v/data 2>/dev/null | cut -f1; }

nettoyer() {
  local s=$?
  for n in "${NOEUDS[@]}"; do docker rm -f "garage-$n" >/dev/null 2>&1; done
  for n in "${NOEUDS[@]}"; do docker volume rm "garage-banc-$n" >/dev/null 2>&1; done
  docker network rm "$RESEAU" >/dev/null 2>&1
  rm -rf "$TMP"
  return $s
}
trap nettoyer EXIT

for o in docker restic curl openssl; do
  command -v "$o" >/dev/null || { echo "outil manquant : $o" >&2; exit 2; }
done
[ -d "$PDF" ] || { echo "dossier des PDF introuvable : $PDF (BANC_PDF)" >&2; exit 2; }

nettoyer; TMP="$(mktemp -d)"
SECRET_RPC=$(openssl rand -hex 32)
JETON_ADMIN=$(openssl rand -hex 32)
openssl rand -hex 32 > "$TMP/pass"

# --- 0. Trois lieux ------------------------------------------------------------
etape "0. Trois nœuds Garage $TAG, zones ${ZONE[a]} / ${ZONE[b]} / ${ZONE[c]}"
docker network create "$RESEAU" >/dev/null
for n in "${NOEUDS[@]}"; do
  cat > "$TMP/garage-$n.toml" <<EOF
metadata_dir = "/var/lib/garage/meta"
data_dir = "/var/lib/garage/data"
db_engine = "sqlite"
replication_factor = 3
consistency_mode = "consistent"
rpc_bind_addr = "[::]:3901"
rpc_public_addr = "garage-$n:3901"
rpc_secret = "$SECRET_RPC"

[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:3900"
root_domain = ".s3.garage.localhost"

[s3_web]
bind_addr = "[::]:3902"
root_domain = ".web.garage.localhost"
index = "index.html"

[admin]
api_bind_addr = "[::]:3903"
admin_token = "$JETON_ADMIN"
EOF
  docker run -d --name "garage-$n" --network "$RESEAU" \
    -p "127.0.0.1:${PORT[$n]}:3900" -p "127.0.0.1:$((PORT[$n] + 2)):3902" \
    -v "$TMP/garage-$n.toml:/etc/garage.toml:ro" \
    -v "garage-banc-$n:/var/lib/garage" "$IMAGE" >/dev/null \
    || { echo "impossible de lancer $IMAGE" >&2; exit 1; }
done
sleep 4
ID_A=$(g a node id -q 2>/dev/null | tail -1)
for n in b c; do g "$n" node connect "$ID_A" >/dev/null; done
sleep 3
for n in "${NOEUDS[@]}"; do
  id=$(g "$n" node id -q 2>/dev/null | tail -1 | cut -d@ -f1)
  g a layout assign -z "${ZONE[$n]}" -c 20G "${id:0:16}" >/dev/null
done
g a layout apply --version 1 >/dev/null
sleep 3
vus=$(g a status 2>/dev/null | grep -cE "^[0-9a-f]{16} ")
[ "$vus" -ge 3 ] && ok "trois nœuds se voient, chacun dans sa zone" || rate "les nœuds ne se voient pas ($vus) : $(g a status 2>&1 | tail -5)"

g a bucket create anarbib-public >/dev/null
CLE=$(g a key create restic-banc 2>/dev/null)
ID_CLE=$(printf '%s\n' "$CLE" | grep -iE '^key id' | awk '{print $NF}')
SECRET_CLE=$(printf '%s\n' "$CLE" | grep -iE '^secret key' | awk '{print $NF}')
g a bucket allow --read --write --owner anarbib-public --key restic-banc >/dev/null
[ -n "$ID_CLE" ] && [ -n "$SECRET_CLE" ] && ok "bucket et clé créés" || { rate "clé non lue : $CLE"; exit 1; }

export AWS_ACCESS_KEY_ID="$ID_CLE" AWS_SECRET_ACCESS_KEY="$SECRET_CLE" AWS_DEFAULT_REGION=garage
export RESTIC_PASSWORD_FILE="$TMP/pass"
depot() { printf 's3:http://127.0.0.1:%s/anarbib-public' "${PORT[$1]}"; }
r() { local n="$1"; shift; timeout "${DELAI:-600}" restic -r "$(depot "$n")" -o s3.bucket-lookup=path "$@"; }

# --- 1. restic écrit et relit --------------------------------------------------
etape "1. restic vers Garage : ~$MO Mo de PDF publics"
find "$PDF" -type f -printf '%s\t%p\n' | sort -t$'\t' -k2 \
  | awk -F'\t' -v max=$((MO * 1048576)) '{ t += $1; if (t > max) exit; print $2 }' > "$TMP/liste"
taille=$(tr '\n' '\0' < "$TMP/liste" | du -ch --files0-from=- 2>/dev/null | tail -1 | cut -f1)
echo "  $(wc -l < "$TMP/liste") fichiers, $taille"
r a init >/dev/null 2>&1 && ok "dépôt restic créé dans Garage" || rate "restic init"
debut=$(date +%s)
r a backup --files-from "$TMP/liste" --tag banc -q >/dev/null 2>&1 \
  && ok "sauvegarde écrite en $(( $(date +%s) - debut )) s" || rate "restic backup"
r a check --read-data -q >/dev/null 2>&1 && ok "check --read-data : chaque paquet relu et déchiffré" || rate "check --read-data"

# --- 2. Un lieu éteint ---------------------------------------------------------
etape "2. Le lieu ${ZONE[c]} s'éteint"
docker stop garage-c >/dev/null
head -n 20 "$TMP/liste" > "$TMP/liste2"
r a backup --files-from "$TMP/liste2" --tag banc-2-sur-3 -q >/dev/null 2>&1 \
  && ok "écriture à deux lieux sur trois" || rate "écriture à deux lieux sur trois"
cible="$(head -1 "$TMP/liste")"
r b restore latest --tag banc --include "$cible" --target "$TMP/restaure" -q >/dev/null 2>&1
if cmp -s "$cible" "$TMP/restaure$cible"; then ok "restauration par un autre lieu (${ZONE[b]}), fichier identique"
else rate "restauration à deux lieux sur trois"; fi

# --- 3. Le lieu revient --------------------------------------------------------
etape "3. Le lieu ${ZONE[c]} revient et rattrape"
docker start garage-c >/dev/null
sleep 8
g a repair --all-nodes --yes tables >/dev/null 2>&1
g a repair --all-nodes --yes blocks >/dev/null 2>&1
attendu=$(taille_mo a); attendu=${attendu:-0}
rattrape=""
for _ in $(seq 1 60); do
  c=$(taille_mo c); c=${c:-0}
  [ "$attendu" -gt 0 ] && [ "$c" -ge $((attendu * 98 / 100)) ] && { rattrape=1; break; }
  sleep 5
done
for n in "${NOEUDS[@]}"; do
  echo "  ${ZONE[$n]} : $(taille_h "$n") de données"
done
[ -n "$rattrape" ] && ok "chaque lieu porte une copie entière (${ZONE[c]} a rattrapé)" \
                   || rate "${ZONE[c]} n'a pas rattrapé en 5 min ($c Mo contre $attendu)"
DELAI=900 r c check --read-data -q >/dev/null 2>&1 && ok "check --read-data lu par le lieu revenu" || rate "check par le lieu revenu"

# --- 4. Deux lieux éteints : la limite ------------------------------------------
etape "4. Deux lieux éteints (${ZONE[b]} et ${ZONE[c]}) : ce qui ne marche plus"
docker stop garage-b garage-c >/dev/null
if DELAI=60 r a backup --files-from "$TMP/liste2" --tag banc-1-sur-3 -q >/dev/null 2>&1; then
  rate "une écriture a été acceptée par un seul lieu (inattendu en mode consistent)"
else ok "écriture refusée à un lieu sur trois — attendu : il faut deux lieux joignables"; fi
if DELAI=60 r a snapshots -q >/dev/null 2>&1; then
  echo "  (note) la liste des instantanés reste lisible à un lieu sur trois"
else echo "  (note) plus rien n'est lisible à un lieu sur trois : la lecture demande aussi deux lieux"; fi
docker start garage-b garage-c >/dev/null
sleep 8

# --- 5. Le fond de carte par le point web --------------------------------------
etape "5. Fond de carte : point web, Range et CORS"
if [ -n "$CARTE" ] && [ -f "$CARTE" ]; then
  head -c $((64 * 1048576)) "$CARTE" > "$TMP/extrait.pmtiles"
  g a bucket create carte-essai >/dev/null
  g a bucket allow --read --write --owner carte-essai --key restic-banc >/dev/null
  g a bucket website --allow carte-essai >/dev/null
  S3="http://127.0.0.1:${PORT[a]}"
  sig=(--aws-sigv4 "aws:amz:garage:s3" --user "$ID_CLE:$SECRET_CLE")
  code=$(curl -s -o /dev/null -w '%{http_code}' "${sig[@]}" -T "$TMP/extrait.pmtiles" "$S3/carte-essai/planet.pmtiles")
  [ "$code" = 200 ] && ok "extrait de 64 Mio déposé par S3" || rate "dépôt S3 : HTTP $code"
  cat > "$TMP/cors.xml" <<'EOF'
<CORSConfiguration><CORSRule><AllowedOrigin>*</AllowedOrigin><AllowedMethod>GET</AllowedMethod><AllowedMethod>HEAD</AllowedMethod><AllowedHeader>*</AllowedHeader><ExposeHeader>Content-Range</ExposeHeader><ExposeHeader>Content-Length</ExposeHeader><ExposeHeader>ETag</ExposeHeader><MaxAgeSeconds>3600</MaxAgeSeconds></CORSRule></CORSConfiguration>
EOF
  md5=$(openssl dgst -md5 -binary "$TMP/cors.xml" | openssl base64)
  code=$(curl -s -o "$TMP/cors-rep" -w '%{http_code}' "${sig[@]}" -X PUT -H "Content-MD5: $md5" \
         -H 'Content-Type: application/xml' --data-binary @"$TMP/cors.xml" "$S3/carte-essai?cors")
  [ "$code" = 200 ] && ok "règle CORS posée" || rate "règle CORS : HTTP $code $(cat "$TMP/cors-rep")"
  WEB="http://127.0.0.1:$((PORT[a] + 2))"
  H=(-H "Host: carte-essai.web.garage.localhost" -H "Origin: https://app.anarbib.org")
  for plage in "0-16383" "33554432-33619967"; do
    code=$(curl -s -D "$TMP/en-tetes" -o "$TMP/morceau" -w '%{http_code}' "${H[@]}" -H "Range: bytes=$plage" "$WEB/planet.pmtiles")
    debut=${plage%-*}; fin=${plage#*-}
    if [ "$code" = 206 ] && cmp -s "$TMP/morceau" <(tail -c +$((debut + 1)) "$TMP/extrait.pmtiles" | head -c $((fin - debut + 1))); then
      ok "Range bytes=$plage : 206, octets identiques"
    else rate "Range bytes=$plage : HTTP $code"; fi
  done
  grep -qi '^access-control-allow-origin:' "$TMP/en-tetes" \
    && ok "réponse avec Access-Control-Allow-Origin ($(grep -i '^access-control-allow-origin:' "$TMP/en-tetes" | tr -d '\r' | cut -d' ' -f2))" \
    || rate "pas d'en-tête CORS sur la réponse"
  grep -qi '^access-control-expose-headers:.*content-range' "$TMP/en-tetes" \
    && ok "Content-Range exposé au navigateur" || echo "  (note) Content-Range non exposé : à vérifier avec protomaps-leaflet"
  code=$(curl -s -D "$TMP/pre" -o /dev/null -w '%{http_code}' -X OPTIONS "${H[@]}" \
         -H 'Access-Control-Request-Method: GET' -H 'Access-Control-Request-Headers: range' "$WEB/planet.pmtiles")
  if [ "${code:0:1}" = 2 ] && grep -qi '^access-control-allow-' "$TMP/pre"; then ok "pré-vol CORS (OPTIONS, en-tête range) : $code"
  else rate "pré-vol CORS : HTTP $code"; fi
else
  echo "  fond de carte introuvable (BANC_CARTE) : étape sautée"
fi

# --- Mémoire ---------------------------------------------------------------------
etape "Mémoire des nœuds (au repos, après l'essai)"
docker stats --no-stream --format '  {{.Name}} : {{.MemUsage}}' garage-a garage-b garage-c

echo
echo "== Bilan : $REUSSI contrôle(s) réussi(s), $ECHOUE en échec (Garage $TAG)"
[ "$ECHOUE" -eq 0 ]
