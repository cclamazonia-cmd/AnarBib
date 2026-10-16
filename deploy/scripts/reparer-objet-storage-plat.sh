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
VERSION=$(
  printf '%s\n' \
    "select version from storage.objects" \
    "where bucket_id = :'bucket' and name = :'object_name'" \
    "limit 1;" \
  | docker compose exec -T db psql \
      -U supabase_admin -d postgres -X -A -t -v ON_ERROR_STOP=1 \
      -v "bucket=$BUCKET" -v "object_name=$OBJECT_NAME"
)
VERSION=${VERSION//$'\r'/}
VERSION=${VERSION//$'\n'/}

# Sans ligne en base, Storage choisira lui-même la version lors du premier
# envoi. Il n'existe donc aucune destination fiable à fabriquer ici.
[[ -n "$VERSION" ]] || exit 0
[[ "$VERSION" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
  || die "version d'objet invalide"

result=$(
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
)

if [[ "$result" == repaired ]]; then
  printf 'Disposition Storage héritée transposée : %s/%s\n' "$BUCKET" "$OBJECT_NAME"
fi
