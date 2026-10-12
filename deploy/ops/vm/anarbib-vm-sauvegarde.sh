#!/usr/bin/env bash
#
# anarbib-vm-sauvegarde.sh — la sauvegarde d'une AnarBib auto-hébergée, lancée
# depuis la machine qui l'héberge (VM, ISO d'ASR2026, serveur d'un collectif).
#
# POURQUOI UN SECOND SCRIPT, à côté de ../anarbib-bg2.sh.
# La chaîne #BG2 sauvegarde la PRODUCTION HÉBERGÉE depuis le poste de
# maintenance : elle parle au pooler Supabase, tire les buckets par le CLI
# `supabase storage cp --linked`, lit deux listes de tables à données
# personnelles tenues hors dépôt, et tourne dans la session utilisateur WSL.
# Rien de cela n'existe sur une VM : la base est un conteneur du compose de
# deploy/, les fichiers sont dans un volume Docker, et personne n'a les listes.
# Plutôt que de rendre #BG2 bimodal — c'est la brique dont la production
# dépend, on ne la retouche pas pour un autre usage —, ce script fait, avec les
# mêmes garde-fous (verrou, filet RGPD, témoins en base, verrous restic
# orphelins), ce qu'une VM peut faire seule :
#
#   base     les TROIS fichiers que deploy/scripts/restore.sh attend
#            (schema.sql, data.sql, migrations.sql), produits par pg_dump DANS
#            le conteneur db avec exactement les options et les filtres du
#            CLI Supabase (`supabase db dump`, v2.98.1, pkg/migration/scripts),
#            plus vault.sql : les secrets du Vault déchiffrés, dont le sel de
#            pseudonymisation sans lequel une restauration corrompt en silence.
#            Quotidien, rétention 7 jours / 4 semaines / 6 mois.
#   storage  le volume Docker des fichiers (buckets), sauf map-tiles (le fond
#            de carte, reconstructible en 30 min, triplerait le dépôt).
#            Hebdomadaire, même rétention.
#
# Pas de découpage court/long (données personnelles à rétention courte) : il
# demande les deux listes PII, qui ne sont pas au dépôt. Une instance qui en
# dispose peut les poser dans ANARBIB_OPS et reprendre ../anarbib-bg2.sh.
# Conséquence assumée : les données personnelles de l'instance vivent 6 mois
# dans le dépôt restic. À dire dans le registre des traitements de l'instance.
#
# TÉMOINS EN BASE. La sonde health-probe de l'instance lit
# public.fn_backup_heartbeat_status() et attend trois flux nommés court (36 h),
# long (9 j) et storage (9 j) — les noms de #BG2, figés par une contrainte. Le
# tir « base » quotidien témoigne donc pour court ET long (il contient les
# deux), le tir « storage » pour storage. L'absence de témoin ouvre un incident
# et un courriel aux admins de l'instance : c'est la supervision, sans rien
# d'autre à installer.
#
# Ne contient AUCUN secret. Tout vient de /etc/anarbib/sauvegarde.env (mode 600) :
#   ANARBIB_DIR              dossier du dépôt cloné (défaut /opt/anarbib)
#   RESTIC_REPOSITORY        dépôt restic HORS de la machine (sftp:…, rest:…, s3:…)
#   RESTIC_PASSWORD_FILE     fichier de passphrase (mode 600)
#   + ce que le dépôt demande (clé SSH via ~/.ssh/config, AWS_*…)
#
# Sous-commandes :
#   check            prérequis, dépôt restic joignable, base et volume présents, rien d'écrit
#   backup base      les quatre fichiers → restic (tag flux-vm-base)
#   backup storage   le volume des fichiers → restic (tag flux-vm-storage)
#   backup all       les deux, dans cet ordre
#   dumps            les quatre fichiers dans deploy/dumps/, SANS restic
#                    (pour restore.sh sur une autre pile, ou avant une mise à jour risquée)
#   prune            applique la rétention et compacte le dépôt (mensuel)
#   snapshots        liste les instantanés des deux flux
#
# Voir deploy/ops/vm/README.md pour l'installation et la restauration.
#
set -euo pipefail

CONFIG="${ANARBIB_SAUVEGARDE_ENV:-/etc/anarbib/sauvegarde.env}"
if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1090
  set -a; . "$CONFIG"; set +a
fi

ANARBIB_DIR="${ANARBIB_DIR:-/opt/anarbib}"
ANARBIB_OPS="${ANARBIB_OPS:-/var/lib/anarbib-sauvegarde}"   # verrou, marqueurs, espace de travail
WORK="$ANARBIB_OPS/.work"
COMPOSE_FILE="$ANARBIB_DIR/deploy/compose.yml"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-anarbib-selfhost}"         # `name:` de deploy/compose.yml
STORAGE_VOLUME="${STORAGE_VOLUME:-${COMPOSE_PROJECT}_storage-data}"
CLI_VERSION_RECETTE="v2.98.1"   # la version du CLI dont on reproduit les dumps (cf. ci.yml)

# Comment on parle à la base. Par défaut : le conteneur db du compose. Pour le
# banc d'essai (base de dev, autre conteneur) : ANARBIB_DB_EXEC="docker exec -i <ctn>".
DB_EXEC="${ANARBIB_DB_EXEC:-docker compose -f $COMPOSE_FILE exec -T db}"
PGUSER_DUMP="${PGUSER_DUMP:-supabase_admin}"

# --- Recette du CLI Supabase v2.98.1 (pkg/migration/dump.go), à l'identique ----
# Schémas que `supabase db dump` (schéma) EXCLUT : maintenus par la plateforme.
CLI_SCHEMAS_INTERNES='information_schema|pg_*|_analytics|_realtime|_supavisor|auth|etl|extensions|pgbouncer|realtime|storage|supabase_functions|supabase_migrations|cron|dbdev|graphql|graphql_public|net|pgmq|pgsodium|pgsodium_masks|pgtle|repack|tiger|tiger_data|timescaledb_*|_timescaledb_*|topology|vault'
# Schémas que `supabase db dump --data-only` EXCLUT : auth, storage, cron, net,
# pgmq et supabase_functions y sont volontairement GARDÉS (comptes, buckets,
# objets, crons voyagent avec les données).
CLI_SCHEMAS_EXCLUS_DONNEES='information_schema|pg_*|graphql|graphql_public|pgsodium|pgsodium_masks|pgtle|repack|tiger|tiger_data|timescaledb_*|_timescaledb_*|topology|vault|etl|extensions|pgbouncer|realtime|supabase_migrations|_analytics|_realtime|_supavisor'
# ----------------------------------------------------------------------------

die()  { echo "ERREUR: $*" >&2; exit 1; }
info() { echo ">>> $*"; }
require() { command -v "$1" >/dev/null 2>&1 || die "outil manquant : $1"; }

# --- Filet RGPD : à la sortie, quelle qu'en soit la cause, tout dump résiduel
#     de l'espace de travail est détruit (schema/data en clair, vault EN CLAIR).
cleanup_work() {
  local f
  [ -d "${WORK:-}" ] || return 0
  for f in "$WORK"/*.sql; do
    [ -e "$f" ] || continue
    shred -u "$f" 2>/dev/null || rm -f "$f"
  done
}

# --- Un tir à la fois (même raison que #BG2, I24) : les tirs partagent WORK.
prendre_le_verrou() {
  require flock
  mkdir -p "$ANARBIB_OPS"; chmod 700 "$ANARBIB_OPS"
  exec 9>"$ANARBIB_OPS/.sauvegarde.lock"
  if ! flock -n 9; then
    info "Un autre tir tourne : attente de son tour (45 min au plus)."
    flock -w 2700 9 || die "un autre tir tient le verrou depuis plus de 45 min — abandon, rien n'a été touché"
  fi
  trap cleanup_work EXIT
}

# --- Verrous restic orphelins (un tir tué laisse un verrou qui bloque les suivants).
unlock_stale() {
  local out
  out="$(restic unlock 2>&1 || true)"
  case "$out" in *removed\ 0\ locks*|"") : ;; *) info "Verrou restic orphelin levé : $out" ;; esac
}

psql_db() {  # $1 = SQL ; sortie brute (-tA)
  # shellcheck disable=SC2086
  $DB_EXEC psql -U "$PGUSER_DUMP" -d postgres -X -tA -v ON_ERROR_STOP=1 -c "$1"
}

# --- Témoin de vie en base (les noms de flux sont ceux que la sonde attend).
heartbeat() {
  local flux="$1" phase="${2:-ok}" snap="${3:-}" snap_sql='null' marqueur="$ANARBIB_OPS/.en-cours-$1"
  if [ "$phase" = started ]; then printf '%s %s\n' "$(date +%s)" "$$" > "$marqueur" 2>/dev/null || true
  else rm -f "$marqueur" 2>/dev/null || true; fi
  [ -n "$snap" ] && snap_sql="'$snap'"
  if psql_db "select public.fn_record_backup_heartbeat('$flux', $snap_sql, '$(hostname)', '$phase');" >/dev/null 2>&1; then
    info "Témoin '$phase' envoyé ($flux${snap:+, instantané $snap})."
  else
    echo "AVERTISSEMENT : témoin '$phase' NON envoyé pour '$flux' (base injoignable, ou fonction absente)." >&2
    echo "                La sauvegarde, elle, suit son cours ; la sonde ne le saura pas." >&2
  fi
}

# Identifiant du dernier instantané d'une étiquette : la date la plus grande,
# pas `--latest 1` (qui rend un instantané PAR GROUPE host+chemins).
snapshot_id_de() {
  local tag="$1" json ligne ts best=0 id="" cur=""
  json="$(restic snapshots --tag "$tag" --json 2>/dev/null)" || return 0
  while IFS= read -r ligne; do
    case "$ligne" in
      '"time":'*) cur="$(printf '%s' "$ligne" | cut -d'"' -f4)" ;;
      '"short_id":'*)
        [ -n "$cur" ] || continue
        ts="$(date -d "$cur" +%s 2>/dev/null)" || continue
        if [ "$ts" -gt "$best" ]; then best="$ts"; id="$(printf '%s' "$ligne" | cut -d'"' -f4)"; fi ;;
    esac
  done <<< "$(printf '%s' "$json" | grep -o '"time":"[^"]*"\|"short_id":"[^"]*"')"
  printf '%s' "$id"
}

preflight() {
  require docker; require restic; require shred
  [ -n "${RESTIC_REPOSITORY:-}" ]    || die "RESTIC_REPOSITORY absent de $CONFIG (le dépôt restic doit être HORS de cette machine)"
  [ -f "${RESTIC_PASSWORD_FILE:-}" ] || die "RESTIC_PASSWORD_FILE absent ou introuvable (${RESTIC_PASSWORD_FILE:-non défini})"
  [ -f "$COMPOSE_FILE" ] || [ -n "${ANARBIB_DB_EXEC:-}" ] || die "compose introuvable : $COMPOSE_FILE (ANARBIB_DIR=$ANARBIB_DIR)"
  mkdir -p "$WORK"; chmod 700 "$WORK"
}

# --- Les quatre fichiers, produits dans le conteneur db --------------------
# La recette est celle de `supabase db dump` v2.98.1, filtres sed compris : ce
# que deploy/scripts/restore.sh sait restaurer. Le script shell est passé sur
# l'entrée standard de `bash -s` dans le conteneur ; les sorties reviennent
# par la sortie standard, rien n'est écrit dans le conteneur.
dump_schema() {
  # shellcheck disable=SC2086
  $DB_EXEC bash -s -- "$PGUSER_DUMP" "$CLI_SCHEMAS_INTERNES" <<'DANS_LE_CONTENEUR'
set -euo pipefail
PGUSER="$1"; EXCL="$2"; export PGUSER PGDATABASE=postgres
pg_dump --schema-only --quote-all-identifier --role postgres --exclude-schema "$EXCL" \
| sed -E 's/^\\(un)?restrict .*$/-- &/' \
| sed -E 's/^CREATE SCHEMA "/CREATE SCHEMA IF NOT EXISTS "/' \
| sed -E 's/^CREATE TABLE "/CREATE TABLE IF NOT EXISTS "/' \
| sed -E 's/^CREATE SEQUENCE "/CREATE SEQUENCE IF NOT EXISTS "/' \
| sed -E 's/^CREATE VIEW "/CREATE OR REPLACE VIEW "/' \
| sed -E 's/^CREATE FUNCTION "/CREATE OR REPLACE FUNCTION "/' \
| sed -E 's/^CREATE TRIGGER "/CREATE OR REPLACE TRIGGER "/' \
| sed -E 's/^CREATE PUBLICATION "supabase_realtime/-- &/' \
| sed -E 's/^CREATE EVENT TRIGGER /-- &/' \
| sed -E 's/^         WHEN TAG IN /-- &/' \
| sed -E 's/^   EXECUTE FUNCTION /-- &/' \
| sed -E 's/^ALTER EVENT TRIGGER /-- &/' \
| sed -E 's/^ALTER PUBLICATION "supabase_realtime_/-- &/' \
| sed -E 's/^ALTER FOREIGN DATA WRAPPER (.+) OWNER TO /-- &/' \
| sed -E 's/^ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin"/-- &/' \
| sed -E 's/^GRANT ALL ON FOREIGN DATA WRAPPER (.+) TO "postgres" WITH GRANT OPTION/-- &/' \
| sed -E "s/^GRANT (.+) ON (.+) \"($EXCL)\"/-- &/" \
| sed -E "s/^REVOKE (.+) ON (.+) \"($EXCL)\"/-- &/" \
| sed -E 's/^(CREATE EXTENSION IF NOT EXISTS "pg_tle").+/\1;/' \
| sed -E 's/^(CREATE EXTENSION IF NOT EXISTS "pgsodium").+/\1;/' \
| sed -E 's/^(CREATE EXTENSION IF NOT EXISTS "pgmq").+/\1;/' \
| sed -E 's/^COMMENT ON EXTENSION (.+)/-- &/' \
| sed -E 's/^CREATE POLICY "cron_job_/-- &/' \
| sed -E 's/^ALTER TABLE "cron"/-- &/' \
| sed -E 's/^SET transaction_timeout = 0;/-- &/' \
| sed -E '/^--/d'
DANS_LE_CONTENEUR
}

dump_data() {  # $1 = schémas inclus ('*' ou 'supabase_migrations'), $2 = schémas exclus ('' = aucun)
  # shellcheck disable=SC2086
  $DB_EXEC bash -s -- "$PGUSER_DUMP" "$1" "$2" <<'DANS_LE_CONTENEUR'
set -euo pipefail
PGUSER="$1"; INCL="$2"; EXCL="$3"; export PGUSER PGDATABASE=postgres
EXCL_FLAG=(); [ -n "$EXCL" ] && EXCL_FLAG=(--exclude-schema "$EXCL")
echo "SET session_replication_role = replica;"
echo
pg_dump --data-only --quote-all-identifier --role postgres "${EXCL_FLAG[@]}" \
  --exclude-table "auth.schema_migrations" --exclude-table "storage.migrations" \
  --exclude-table "supabase_functions.migrations" --schema "$INCL" \
| sed -E 's/^\\(un)?restrict .*$/-- &/'
echo "RESET ALL;"
DANS_LE_CONTENEUR
}

dump_vault() {  # $1 = fichier de sortie ; secrets EN CLAIR, mode 600, détruit au shred par le filet
  local out="$1" n
  umask 077
  {
    echo "-- AnarBib — secrets du Vault, exportés le $(date -u +%Y-%m-%dT%H:%M:%SZ) depuis $(hostname)"
    echo "-- SECRETS EN CLAIR. Rejeu sur une base cible : psql -f <ce fichier>"
    echo "-- Rejouer un secret déjà présent lève une erreur de doublon : voulu."
    psql_db "select format('select vault.create_secret(%L, %L, %L);', decrypted_secret, name, coalesce(description,'')) from vault.decrypted_secrets order by name;"
  } > "$out"
  chmod 600 "$out"
  n="$(grep -c '^select vault.create_secret' "$out" || true)"
  [ "${n:-0}" -ge 1 ] || die "VAULT : export vide — droits insuffisants sur vault.decrypted_secrets ?"
  grep -q "'pseudonym_salt'" "$out" || die "VAULT : pseudonym_salt ABSENT de l'export — on n'envoie rien."
  info "Vault : $n secrets, dont pseudonym_salt."
}

produire_les_dumps() {  # $1 = dossier cible
  local d="$1" debut
  mkdir -p "$d"; chmod 700 "$d"
  debut=$(date +%s)
  info "schema.sql (recette CLI $CLI_VERSION_RECETTE, schémas internes exclus)…"
  dump_schema > "$d/schema.sql"
  info "data.sql (toutes données hors schémas de plateforme, triggers suspendus)…"
  dump_data '*' "$CLI_SCHEMAS_EXCLUS_DONNEES" > "$d/data.sql"
  info "migrations.sql (historique supabase_migrations)…"
  dump_data 'supabase_migrations' '' > "$d/migrations.sql"
  dump_vault "$d/vault.sql"
  chmod 600 "$d"/*.sql
  # Canaris : un dump qui ne porte pas ces lignes ne restaurera rien.
  grep -q '^CREATE TABLE IF NOT EXISTS "public"\."books"' "$d/schema.sql" || die "schema.sql : public.books absente — dump incomplet ?"
  grep -q '^SET session_replication_role = replica;' "$d/data.sql"       || die "data.sql : en-tête du CLI absent"
  grep -q 'supabase_migrations' "$d/migrations.sql"                        || die "migrations.sql : vide — l'historique des migrations manque"
  info "Quatre fichiers produits en $(( $(date +%s) - debut )) s : $(du -ch "$d"/*.sql | tail -1 | cut -f1)."
}

# --- Flux base -------------------------------------------------------------
backup_base() {
  preflight; prendre_le_verrou
  heartbeat court started; heartbeat long started
  rm -f "$WORK"/*.sql
  produire_les_dumps "$WORK"
  unlock_stale
  info "restic backup (tag flux-vm-base)…"
  restic backup "$WORK/schema.sql" "$WORK/data.sql" "$WORK/migrations.sql" "$WORK/vault.sql" \
    --tag flux-vm-base --tag anarbib-vm
  restic forget --tag flux-vm-base --group-by tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6
  local snap; snap="$(snapshot_id_de flux-vm-base)"
  heartbeat court ok "$snap"; heartbeat long ok "$snap"
  cleanup_work
  info "Flux base terminé (instantané ${snap:-?})."
}

# --- Flux storage ----------------------------------------------------------
backup_storage() {
  preflight; prendre_le_verrou
  local point
  point="$(docker volume inspect -f '{{.Mountpoint}}' "$STORAGE_VOLUME" 2>/dev/null)" \
    || die "volume Docker introuvable : $STORAGE_VOLUME (la pile tourne-t-elle sous ce nom de projet ?)"
  [ -d "$point" ] || die "le point de montage du volume n'est pas lisible : $point (lancer en root)"
  heartbeat storage started
  unlock_stale
  info "restic backup du volume $STORAGE_VOLUME ($point), map-tiles exclu…"
  # Disposition du service : <s3>/<tenant>/<bucket>/<objet>/<version>. On exclut
  # le bucket du fond de carte où qu'il soit dans l'arbre.
  restic backup "$point" --tag flux-vm-storage --tag anarbib-vm --exclude '*/map-tiles' --exclude '*/map-tiles/**'
  restic forget --tag flux-vm-storage --group-by tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6
  local snap; snap="$(snapshot_id_de flux-vm-storage)"
  heartbeat storage ok "$snap"
  info "Flux storage terminé (instantané ${snap:-?})."
}

cmd_check() {
  preflight
  info "Dépôt restic : $RESTIC_REPOSITORY"
  restic cat config >/dev/null 2>&1 || die "dépôt restic injoignable ou non initialisé (restic init ?)"
  info "Dépôt joignable."
  psql_db "select 1" >/dev/null || die "base injoignable par : $DB_EXEC"
  info "Base joignable ($PGUSER_DUMP)."
  [ "$(psql_db "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='fn_record_backup_heartbeat'")" = "1" ] \
    && info "Témoin de vie : fonction présente." || echo "AVERTISSEMENT : public.fn_record_backup_heartbeat absente — pas de supervision par la sonde." >&2
  [ "$(psql_db "select count(*) from vault.decrypted_secrets where name='pseudonym_salt'")" = "1" ] \
    && info "Vault : pseudonym_salt présent." || die "Vault : pseudonym_salt ABSENT — une sauvegarde sans lui ne vaut rien."
  if docker volume inspect "$STORAGE_VOLUME" >/dev/null 2>&1; then info "Volume Storage : $STORAGE_VOLUME présent."
  else echo "AVERTISSEMENT : volume $STORAGE_VOLUME absent — le flux storage échouera." >&2; fi
  local nb_base nb_storage
  nb_base="$(restic snapshots --tag flux-vm-base --json 2>/dev/null | grep -o '"short_id"' | wc -l)"
  nb_storage="$(restic snapshots --tag flux-vm-storage --json 2>/dev/null | grep -o '"short_id"' | wc -l)"
  info "Instantanés : ${nb_base:-0} base, ${nb_storage:-0} storage."
  info "check OK — rien n'a été écrit."
}

cmd_prune() {
  preflight; prendre_le_verrou; unlock_stale
  restic forget --tag flux-vm-base    --group-by tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6
  restic forget --tag flux-vm-storage --group-by tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6
  restic prune
  info "prune terminé."
}

cmd_dumps() {
  preflight; prendre_le_verrou
  local d="$ANARBIB_DIR/deploy/dumps"
  trap - EXIT   # ces fichiers sont voulus sur disque : pas de filet ici
  produire_les_dumps "$d"
  echo "Les quatre fichiers sont dans $d (mode 600). vault.sql porte des SECRETS EN CLAIR :"
  echo "le détruire (shred -u) dès qu'il a servi. Restauration : deploy/README.md, bootstrap.sh --depuis-une-sauvegarde."
}

case "${1:-}" in
  check)     cmd_check ;;
  backup)    case "${2:-}" in
               base)    backup_base ;;
               storage) backup_storage ;;
               all)     backup_base; backup_storage ;;
               *) die "usage : $0 backup base|storage|all" ;;
             esac ;;
  dumps)     cmd_dumps ;;
  prune)     cmd_prune ;;
  snapshots) preflight; restic snapshots --tag flux-vm-base --group-by tags; restic snapshots --tag flux-vm-storage --group-by tags ;;
  *) sed -n '2,56p' "$0"; exit 1 ;;
esac
