#!/usr/bin/env bash
# ============================================================================
# AnarBib — sauvegarde hors fournisseur (#BG2)
# ----------------------------------------------------------------------------
# Sauvegarde chiffrée et dédupliquée (restic) de :
#   1. la base Postgres (pg_dump logique, complet)
#   2. tous les buckets Storage (via rclone, endpoint S3 de Supabase)
#   3. les secrets/config hors git (dossier fourni par l'opérateur·rice)
#
# Conçu pour tourner en cron SUR LE VPS (modèle « pull ») : il fonctionne même
# quand le poste de Xavier est éteint. Aucun secret n'est codé en dur : tout
# vient du fichier de config (voir anarbib-backup.env.example).
#
# Usage :   ./anarbib-backup.sh /chemin/vers/anarbib-backup.env
# Restauration : voir docs/journal/operations/RUNBOOK_restauration_BG2_2026-07-01.md
# ============================================================================
set -euo pipefail

CONF="${1:-}"
if [[ -z "$CONF" || ! -f "$CONF" ]]; then
  echo "ERREUR : fournir le fichier de config en argument (cf. anarbib-backup.env.example)." >&2
  exit 2
fi
# shellcheck disable=SC1090
source "$CONF"

: "${SUPABASE_DB_URL:?chaîne de connexion Postgres requise}"
: "${RESTIC_REPOSITORY:?dépôt restic requis (ex: sftp:user@vps-lille:/srv/backups/anarbib)}"
: "${RESTIC_PASSWORD_FILE:?fichier mot de passe restic requis}"
: "${RCLONE_REMOTE:?remote rclone du Storage requis (ex: supabase-s3:)}"
STAGING="${STAGING_DIR:-/tmp/anarbib-backup-staging}"
SECRETS_DIR="${SECRETS_DIR:-}"           # optionnel : dossier de secrets à inclure
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"
FAIL_WEBHOOK="${FAIL_WEBHOOK:-}"         # optionnel : URL pingée en cas d'échec

export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE

TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_TAG="[anarbib-backup ${TS}]"

notify_fail() {
  echo "${LOG_TAG} ECHEC: $1" >&2
  if [[ -n "$FAIL_WEBHOOK" ]]; then
    curl -fsS -m 15 -X POST "$FAIL_WEBHOOK" \
      -H 'content-type: application/json' \
      -d "{\"text\":\"AnarBib backup ECHEC ${TS}: $1\"}" >/dev/null 2>&1 || true
  fi
}
trap 'notify_fail "interruption inattendue (ligne $LINENO)"' ERR

echo "${LOG_TAG} début"
rm -rf "$STAGING"
mkdir -p "$STAGING/db" "$STAGING/storage"

# 1. Base Postgres -----------------------------------------------------------
echo "${LOG_TAG} pg_dump…"
pg_dump --no-owner --no-privileges --format=custom \
  --file="$STAGING/db/anarbib_${TS}.dump" "$SUPABASE_DB_URL"
# dump SQL texte en complément (lisible / diff / restauration partielle)
pg_dump --no-owner --no-privileges --format=plain "$SUPABASE_DB_URL" \
  | gzip -9 > "$STAGING/db/anarbib_${TS}.sql.gz"

# 2. Storage (tous les buckets) ----------------------------------------------
echo "${LOG_TAG} rclone Storage…"
rclone copy "$RCLONE_REMOTE" "$STAGING/storage" --fast-list --transfers 8 --stats-one-line

# 3. Secrets / config hors git (optionnel) -----------------------------------
if [[ -n "$SECRETS_DIR" && -d "$SECRETS_DIR" ]]; then
  echo "${LOG_TAG} copie secrets…"
  mkdir -p "$STAGING/secrets"
  cp -a "$SECRETS_DIR/." "$STAGING/secrets/"
fi

# 4. restic backup (chiffré) -------------------------------------------------
echo "${LOG_TAG} restic backup…"
restic backup "$STAGING" --tag anarbib --tag "auto" --host anarbib

# 5. Rétention (GFS) ---------------------------------------------------------
echo "${LOG_TAG} restic forget/prune…"
restic forget --tag anarbib \
  --keep-daily  "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune

# 6. Intégrité (léger ; --read-data-subset pour ne pas tout relire) ----------
echo "${LOG_TAG} restic check…"
restic check --read-data-subset=5%

# 7. Nettoyage ---------------------------------------------------------------
rm -rf "$STAGING"
trap - ERR
echo "${LOG_TAG} OK — sauvegarde terminée"
