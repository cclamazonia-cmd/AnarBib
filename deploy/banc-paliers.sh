#!/usr/bin/env bash
# =============================================================================
# AnarBib — banc des paliers GoTrue / Storage
# =============================================================================
# RÈGLE : image ≥ production, jamais l'inverse — et l'hébergeur monte la
# production de lui-même (constaté le 21/09/2026 : 77 → 82 lignes auth, 65 → 68
# migrations Storage, pins repassés dessous sans que rien le dise). Le pin se
# MESURE : une base vierge par palier, l'image lancée seule contre elle, et on
# lit ce qu'elle a construit. On retient le premier palier qui atteint la
# production. Les chiffres de la production se relèvent par :
#   select count(*), max(version) from auth.schema_migrations;
#   select count(*) from storage.migrations;
#
# Usage : deploy/banc-paliers.sh auth|storage <tag> [<tag>...]
#   deploy/banc-paliers.sh auth v2.197.0 v2.198.0
#   PG_TAG=17.6.1.136 deploy/banc-paliers.sh storage v1.72.0 v1.73.1
# Toujours inclure le pin courant comme TÉMOIN : s'il ne rend pas le chiffre
# déjà connu, c'est le banc qui est faux, pas l'image.
# Sortie : une ligne par palier — service, tag, lignes avant, lignes après,
# dernière version — et la liste des dernières migrations dans /tmp.
# Ne touche à aucune pile : conteneurs banc-db / banc-svc, réseau à part, tout
# est retiré à la fin. Relevé du 21/09 : NOTE_pins-images-remesures_2026-09-21.
# =============================================================================
set -u
SERVICE="$1"; shift
PG_TAG="${PG_TAG:-17.6.1.136}"
PW="banc-paliers-jetable"
JWT="banc-paliers-secret-jetable-de-plus-de-32-caracteres"
NET="banc-paliers-net"
SORTIE="${SORTIE:-/tmp/banc-paliers-$SERVICE.tsv}"
: > "$SORTIE"

docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null

case "$SERVICE" in
  auth)    REQ="select count(*)||E'\t'||coalesce(max(version),'-') from auth.schema_migrations" ;;
  storage) REQ="select count(*)||E'\t'||coalesce((select name from storage.migrations order by id desc limit 1),'-') from storage.migrations" ;;
  *) echo "service inconnu" >&2; exit 2 ;;
esac

mesure() { docker exec banc-db psql -U supabase_admin -d postgres -tAc "$REQ" 2>/dev/null || echo "0	-"; }

for TAG in "$@"; do
  docker rm -fv banc-db banc-svc >/dev/null 2>&1
  docker run -d --name banc-db --network "$NET" --network-alias db \
    -e POSTGRES_PASSWORD="$PW" -e POSTGRES_DB=postgres -e JWT_SECRET="$JWT" -e JWT_EXP=3600 \
    "supabase/postgres:$PG_TAG" >/dev/null || { echo "$SERVICE	$TAG	ECHEC-DB" >> "$SORTIE"; continue; }

  # Attendre un FAIT : le rôle de service existe (pg_isready ment sur une base sans rôles).
  for i in $(seq 1 90); do
    r=$(docker exec banc-db psql -U supabase_admin -d postgres -tAc "select 1 from pg_roles where rolname='supabase_storage_admin'" 2>/dev/null)
    [ "$r" = "1" ] && break; sleep 2
  done
  sleep 3
  for role in supabase_auth_admin supabase_storage_admin authenticator; do
    docker exec banc-db psql -U supabase_admin -d postgres -c "alter role \"$role\" with login password '$PW'" >/dev/null 2>&1
  done
  AVANT=$(mesure | cut -f1)

  if [ "$SERVICE" = auth ]; then
    docker run -d --name banc-svc --network "$NET" \
      -e GOTRUE_API_HOST=0.0.0.0 -e GOTRUE_API_PORT=9999 -e API_EXTERNAL_URL=http://localhost \
      -e GOTRUE_DB_DRIVER=postgres \
      -e GOTRUE_DB_DATABASE_URL="postgres://supabase_auth_admin:$PW@db:5432/postgres" \
      -e GOTRUE_SITE_URL=http://localhost -e GOTRUE_JWT_SECRET="$JWT" -e GOTRUE_JWT_EXP=3600 \
      -e GOTRUE_JWT_AUD=authenticated -e GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated \
      -e GOTRUE_EXTERNAL_EMAIL_ENABLED=true -e GOTRUE_MAILER_AUTOCONFIRM=true \
      "supabase/gotrue:$TAG" >/dev/null
  else
    docker run -d --name banc-svc --network "$NET" \
      -e ANON_KEY=x -e SERVICE_KEY=x -e PGRST_JWT_SECRET="$JWT" -e AUTH_JWT_SECRET="$JWT" \
      -e DATABASE_URL="postgres://supabase_storage_admin:$PW@db:5432/postgres" \
      -e POSTGREST_URL=http://rest:3000 -e FILE_SIZE_LIMIT=52428800 \
      -e STORAGE_BACKEND=file -e FILE_STORAGE_BACKEND_PATH=/var/lib/storage \
      -e TENANT_ID=anarbib -e REGION=local -e GLOBAL_S3_BUCKET=anarbib \
      -e ENABLE_IMAGE_TRANSFORMATION=false \
      "supabase/storage-api:$TAG" >/dev/null
  fi

  # Attendre que le décompte se stabilise (4 lectures égales, > AVANT), 150 s au plus.
  prec=""; egal=0; M="0	-"
  for i in $(seq 1 75); do
    sleep 2
    M=$(mesure); n=$(echo "$M" | cut -f1)
    if [ "$n" = "$prec" ] && [ "$n" != "$AVANT" ]; then egal=$((egal+1)); else egal=0; fi
    prec="$n"
    [ "$egal" -ge 4 ] && break
  done
  ETAT=$(docker inspect -f '{{.State.Status}}' banc-svc 2>/dev/null)
  echo "$SERVICE	$TAG	avant=$AVANT	$M	conteneur=$ETAT" | tee -a "$SORTIE"
  if [ "$SERVICE" = storage ]; then
    docker exec banc-db psql -U supabase_admin -d postgres -tAc "select string_agg(name, ',' order by id) from storage.migrations where id > 60" > "/tmp/banc-storage-$TAG.noms" 2>/dev/null
  else
    docker exec banc-db psql -U supabase_admin -d postgres -tAc "select string_agg(version, ',' order by version) from auth.schema_migrations where version > '20260101'" > "/tmp/banc-auth-$TAG.versions" 2>/dev/null
  fi
  [ "$ETAT" != running ] && docker logs --tail 15 banc-svc > "/tmp/banc-$SERVICE-$TAG.log" 2>&1
done
docker rm -fv banc-db banc-svc >/dev/null 2>&1
docker network rm "$NET" >/dev/null 2>&1
echo FIN
