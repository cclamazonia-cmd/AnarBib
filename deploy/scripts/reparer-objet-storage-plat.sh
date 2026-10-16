#!/usr/bin/env bash
# Transpose un objet du backend fichier historique vers la disposition
# versionnée attendue par Supabase Storage. Ne touche qu'aux chemins qui sont
# encore des fichiers ordinaires ; un objet déjà versionné reste inchangé.
set -Eeuo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUCKET=${1:-}
OBJECT_NAME=${2:-}

die() {
  printf 'Réparation Storage refusée : %s\n' "$*" >&2
  exit 1
}

[[ "$BUCKET" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
  || die "bucket invalide"
[[ -n "$OBJECT_NAME" && "$OBJECT_NAME" != /* && "$OBJECT_NAME" != *$'\n'* ]] \
  || die "nom d'objet invalide"

IFS=/ read -r -a path_parts <<< "$OBJECT_NAME"
for part in "${path_parts[@]}"; do
  [[ -n "$part" && "$part" != . && "$part" != .. ]] \
    || die "segment de chemin invalide"
done

cd "$DEPLOY_DIR"

has_flat_file=$(
  docker compose exec -T \
    -e "ANARBIB_OBJECT_BUCKET=$BUCKET" \
    -e "ANARBIB_OBJECT_NAME=$OBJECT_NAME" \
    storage sh -eu -c '
      root="${FILE_STORAGE_BACKEND_PATH:?}/${GLOBAL_S3_BUCKET:?}/${TENANT_ID:?}"
      legacy="$root/$ANARBIB_OBJECT_BUCKET/$ANARBIB_OBJECT_NAME"
      if [ -f "$legacy" ]; then
        printf yes
      fi
    '
)

[[ "$has_flat_file" == yes ]] || exit 0

db_row=$(
  printf '%s\n' \
    "select id::text || '|' || coalesce(version, '') from storage.objects" \
    "where bucket_id = :'bucket' and name = :'object_name'" \
    "limit 1;" \
  | docker compose exec -T db psql \
      -U supabase_admin -d postgres -X -A -t -v ON_ERROR_STOP=1 \
      -v "bucket=$BUCKET" -v "object_name=$OBJECT_NAME"
)
db_row=${db_row//$'\r'/}
db_row=${db_row//$'\n'/}

# Sans ligne en base, Storage choisira lui-même la version lors du premier
# envoi. Il n'existe donc aucune destination fiable à fabriquer ici.
[[ -n "$db_row" ]] || exit 0

OBJECT_ID=${db_row%%|*}
VERSION=${db_row#*|}
GENERATED_VERSION=0

if [[ -z "$VERSION" ]]; then
  VERSION=$(
    printf '%s\n' \
      "update storage.objects" \
      "set version = gen_random_uuid()::text" \
      "where id = :'object_id'::uuid and (version is null or version = '')" \
      "returning version;" \
    | docker compose exec -T db psql \
        -U supabase_admin -d postgres -X -A -t -v ON_ERROR_STOP=1 \
        -v "object_id=$OBJECT_ID"
  )
  VERSION=${VERSION//$'\r'/}
  VERSION=${VERSION//$'\n'/}
  GENERATED_VERSION=1
fi

[[ "$VERSION" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
  || die "version d'objet invalide"

rollback_db_version() {
  if [[ "$GENERATED_VERSION" == "1" ]]; then
    printf '%s\n' \
      "update storage.objects" \
      "set version = null" \
      "where id = :'object_id'::uuid and version = :'version';" \
    | docker compose exec -T db psql \
        -U supabase_admin -d postgres -X -A -t -v ON_ERROR_STOP=1 \
        -v "object_id=$OBJECT_ID" -v "version=$VERSION" >/dev/null 2>&1 || true
  fi
}

if ! result=$(
  docker compose exec -T \
    -e "ANARBIB_OBJECT_BUCKET=$BUCKET" \
    -e "ANARBIB_OBJECT_NAME=$OBJECT_NAME" \
    -e "ANARBIB_OBJECT_VERSION=$VERSION" \
    storage sh -eu -c '
      root="${FILE_STORAGE_BACKEND_PATH:?}/${GLOBAL_S3_BUCKET:?}/${TENANT_ID:?}"
      legacy="$root/$ANARBIB_OBJECT_BUCKET/$ANARBIB_OBJECT_NAME"
      [ -f "$legacy" ] || exit 0

      temporary="${legacy}.anarbib-flat.$$"
      mv "$legacy" "$temporary"
      rollback() {
        if [ -f "$temporary" ]; then
          rmdir "$legacy" 2>/dev/null || true
          mv "$temporary" "$legacy"
        fi
      }
      trap rollback EXIT HUP INT TERM

      mkdir "$legacy"
      mv "$temporary" "$legacy/$ANARBIB_OBJECT_VERSION"
      trap - EXIT HUP INT TERM
      printf repaired
    '
); then
  rollback_db_version
  exit 1
fi

if [[ "$result" == repaired ]]; then
  printf 'Disposition Storage héritée transposée : %s/%s\n' "$BUCKET" "$OBJECT_NAME"
else
  rollback_db_version
fi

