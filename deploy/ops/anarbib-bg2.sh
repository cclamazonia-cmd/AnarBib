#!/usr/bin/env bash
#
# anarbib-bg2.sh (v2) — outillage de sauvegarde / restauration BG2, TROIS FLUX
#
# CE FICHIER EST LA SOURCE DE VERITE — versionne depuis le 20/08/2026.
# `~/anarbib-ops/anarbib-bg2.sh` n'en est qu'un lien symbolique. On modifie ici,
# on commite ici ; le poste suit. Voir deploy/ops/README.md.
#
# (L'en-tete disait jusque-la « a garder HORS du repo ». C'etait un contresens :
#  la chaine de sauvegarde etait la seule brique dont TOUT depend, et la seule
#  a n'exister qu'en un exemplaire, sur un poste. Verifie avant de la verser :
#  elle ne divulgue rien que le depot ne contienne deja — l'hote Herbes Folles
#  est nomme dans six documents, le project ref dans soixante-cinq.)
#
# Ne contient AUCUN secret :
#   - mot de passe DB      -> lu depuis ~/.pgpass
#   - passphrase restic    -> lue depuis ~/.config/restic-anarbib.pass
#   - cle SSH              -> fournie par l'agent ssh (ssh-add)
#   - les deux listes PII  -> restent dans ~/anarbib-ops/, hors depot (public)
#
# Trois flux, chacun son depot restic, sa retention, sa logique de selection :
#   long     schemas public + ingest MOINS les PII               retention 7/4/6
#            (denylist + FILET), dans UN SEUL dump anarbib-long.sql
#            + les 21 secrets du Vault, dechiffres (BG2-15, 19/08)
#            (ingest depuis le 05/10/2026 : BG2-13, decision de Xavier)
#   court    30 tables PII + auth.users/identities/mfa_factors  retention 7 j
#            (ALLOWLIST stricte)
#   storage  les 16 buckets Storage (resync systematique)       retention 7/4/6
#
# Sous-commandes :
#   check                    Prerequis + FILET (aucune ecriture, aucun envoi).
#   backup long|court|storage|all
#   restore-test             Test reel en sequence auth -> long -> court (Docker jetable).
#
set -euo pipefail

# ====================== CONFIG (adapter si besoin) ======================
OPS_DIR="${OPS_DIR:-$HOME/anarbib-ops}"
DENYLIST="$OPS_DIR/bg2-denylist.txt"           # 30 tables PII (flux court / exclues du long)
EXCLUDELONG="$OPS_DIR/bg2-exclude-long.txt"      # tables transitoires : exclues du long ET du court (BG2-14)
KNOWN="$OPS_DIR/bg2-known-tables.txt"           # TOUTES les tables classees (filet)
# Les trois listes acceptent des noms QUALIFIES (05/10/2026, BG2-13) : une table
# de public s'ecrit nue (`books`), une table d'un autre schema s'ecrit avec son
# schema (`ingest.book_import_baselines`). Cf. bg2_qualifier / bg2_normaliser.

# Schemas du flux long (BG2-13, 05/10/2026 ; I30, 05/10/2026 : private et api,
# qui ne portent que des vues et des fonctions — l'API de l'OPAC, les aides des
# politiques RLS — et n'etaient dans AUCUN flux). Le filet classe les tables de
# ces memes schemas (bg2_sql_tables) : les deux listes vont ensemble.
LONG_SCHEMAS=(public ingest private api)
WORK="$OPS_DIR/.work"                           # dumps base temporaires
STORAGE_WORK="$OPS_DIR/.storage-work"           # miroir local des buckets (resync a chaque fois)

PGHOST="aws-1-sa-east-1.pooler.supabase.com"
PGPORT="5432"; PGDB="postgres"; PGUSER="postgres.uflwmikiyjfnikiphtcp"
PGCONN="host=$PGHOST port=$PGPORT dbname=$PGDB user=$PGUSER sslmode=require"

SUPABASE_PROJECT_REF="uflwmikiyjfnikiphtcp"     # prod Sao Paulo (PAS le projet Frankfurt)
SUPABASE_REPO="$HOME/anarbib"                    # dossier lie a la prod (pour supabase --linked)

RESTIC_BASE="sftp:anarbib@bricolage.herbesfolles.org:/data"
export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-$HOME/.config/restic-anarbib.pass}"

# Auth : tables a inclure dans le flux court (les 3 tables d'identite durable)
AUTH_TABLES=(auth.users auth.identities auth.mfa_factors)

# map-tiles (fond de carte PMTiles, 18 Go, 07/09/2026) est EXCLU volontairement :
# reconstructible en 30 min depuis Protomaps (scripts/maptiles/README.md), il
# triplerait le depot restic. Ne pas l ajouter ici.
# Buckets Storage (ordre indifferent ; les vides donnent 0 fichier)
BUCKETS=(pdf-restrito library-ui-assets anarbib-pdf-public authors covers
  library-regimentos-private library-regimentos-public catalogos_parceiros_raw
  anarbib-media-public anarbib-media-restricted library-privacy-public
  anarbib-carte-rede partner-catalog-deposits network-map
  anarbib-epub-public anarbib-epub-restricted)

# Temoins pour les controles anti-fuite
PII_CANARIES='profiles|loan_deposits|emprestimos_v2|reservas_v2|membership_payments|reader_card_tokens|user_library_memberships'
LONG_CANARIES='books|authors|libraries|subjects|circles|works|publishers'

PG_IMAGE="postgres:17"
# =======================================================================

die()  { echo "ERREUR: $*" >&2; exit 1; }
info() { echo ">>> $*"; }

# --- FILET RGPD GLOBAL (#BG2) : shred tout dump *.sql residuel dans WORK a la
#     sortie du script, quelle qu'en soit la cause. Necessaire car un trap RETURN
#     local NE se declenche PAS sous set -e quand restic echoue -> un dump PII en
#     clair pouvait survivre a un echec d'envoi. Ce trap EXIT global corrige cela.
#     BG2-15 (19/08) : couvre aussi anarbib-vault.sql, qui porte les secrets du
#     Vault en clair — meme regle, meme motif, meme *.sql.
cleanup_work() {
  local f
  [ -n "${WORK:-}" ] || return 0
  for f in "$WORK"/*.sql; do
    [ -e "$f" ] || continue
    shred -u "$f" 2>/dev/null || rm -f "$f"
  done
}
# Le trap n'est arme qu'une fois le verrou tenu (voir prendre_le_verrou) : un
# tir qui attend ou renonce ne doit pas detruire les dumps de celui qui tourne.

# --- UN TIR A LA FOIS (30/09/2026, backlog I24) --------------------------
# Les tirs partagent $WORK, et cleanup_work detruit a la sortie TOUS les *.sql
# qui s'y trouvent. Deux tirs simultanes — ce que font les rattrapages
# `Persistent=` au demarrage du poste : le 15/09, `court` a fini a 08 h 17
# pendant que `long` tournait jusqu'a 08 h 20 — se detruisaient donc leurs
# dumps : le premier sorti effacait celui de l'autre, ou le reecrivait au shred
# pendant que restic le lisait. Un verrou exclusif les fait passer l'un apres
# l'autre ; le filet RGPD redevient sur et continue de nettoyer ce qu'un tir
# TUE a laisse. Il sert aussi la relance du controle de fraicheur : un tir
# relance pendant un autre attend son tour au lieu de le percuter.
# L'attente (BG2_ATTENTE_MAX, 45 min) tient sous TimeoutStartSec (1 h) des
# services : storage dure ~20 min, long ~5, court ~2.
prendre_le_verrou() {
  local attente="${BG2_ATTENTE_MAX:-2700}"
  require flock
  mkdir -p "$OPS_DIR"
  exec 9>"$OPS_DIR/.bg2.lock"
  if ! flock -n 9; then
    info "Un autre tir anarbib-bg2.sh tourne : attente de son tour (${attente} s au plus)."
    flock -w "$attente" 9 || die "un autre tir tient le verrou depuis plus de ${attente} s — abandon (rien n'a ete touche)"
    info "Verrou obtenu, le tir commence."
  fi
  trap cleanup_work EXIT
}
require() { command -v "$1" >/dev/null 2>&1 || die "outil manquant: $1"; }

# BG2 (30/07): auto-reparation des verrous restic orphelins. Un `restic backup`
# tue en plein vol (redemarrage machine) laisse un lock exclusif qui bloque TOUS
# les tirs suivants (vecu : flux court fige du 16 au 30/07). `restic unlock` SANS
# --remove-all ne retire QUE les locks de processus morts (verifie sur le meme
# hote) : un tir concurrent legitime garde son verrou. RESTIC_REPOSITORY doit
# etre deja exporte -> appeler DANS chaque flux, juste avant `restic backup`.
unlock_stale() {
  local out=""
  out="$(restic unlock 2>&1 || true)"
  case "$out" in
    *"removed 0 locks"*|"") : ;;
    *"removed"*) info "Verrou orphelin restic leve avant backup : $out" ;;
    *) info "unlock (inattendu) : $out" ;;
  esac
}

# --- TEMOIN DE VIE (BG2-16) -------------------------------------------------
# Signale a la base qu'un flux vient d'aboutir. C'est ce signal — et surtout son
# ABSENCE — qui permet a Supabase de constater que les sauvegardes se sont tues.
# Aucun `OnFailure=` ne peut le faire : systemd detecte les ERREURS, pas les
# SILENCES, et un poste eteint ne produit ni l'une ni l'autre (RUNBOOK §7.5).
#
# VOLONTAIREMENT NON BLOQUANT. Si la base est injoignable, la sauvegarde est
# faite et c'est ce qui compte : on avertit, on ne meurt pas. L'inverse serait
# absurde — perdre une sauvegarde reussie parce qu'on n'a pas pu dire qu'elle
# avait reussi.
# DEUX TEMOINS PAR TIR (20/08/2026, migrations 20260820163045 et 20260820165002) :
# un au DEPART (phase 'started'), un a l'ARRIVEE (phase 'ok', le defaut).
#
# Pourquoi. Le 20/08, un tir a ete tue en plein repack par un demontage de
# session. Il n'a rien ecrit en base : ni succes, ni echec. Pour la sonde, une
# machine eteinte toute la journee et un tir mort en route etaient donc le MEME
# evenement — d'ou 37 heures d'aveuglement, alors que l'information existait des
# la premiere minute. Un temoin de depart reste seul est sans ambiguite : la
# sonde ouvre un incident au bout d'une heure, sans attendre les 36 h de silence.
heartbeat() {
  local flux="$1" phase="${2:-ok}" snap="${3:-}"

  # --- MARQUEUR LOCAL « TIR EN COURS » (24/08/2026) ----------------------
  # Pose au depart, retire a l'arrivee. Sa raison d'etre est de SURVIVRE a ce
  # que le temoin ne survit pas : quand le processus est tue (session WSL
  # demontee, machine eteinte), le temoin d'arrivee ne part jamais et aucun
  # `OnFailure=` ne peut le dire — systemd refuse d'enfiler un job de
  # notification pendant un arret. Le fichier, lui, reste sur le disque.
  #
  # C'est ce que le controle de fraicheur relit au reveil. Il ne remplace pas
  # la sonde en base, qui voit la meme chose de son cote ; il la double la ou
  # elle ne peut rien : sur un poste hors ligne, ou face a un tir interrompu
  # dont la DONNEE reste fraiche — cas vecu le 24/08, ou `long` a ete tue en
  # plein pg_dump alors que son dernier instantane datait de deux jours. La
  # fraicheur seule disait « tout va bien », et disait vrai.
  #
  # Ecrit AVANT l'appel psql, et hors de sa reussite : le marqueur ne depend
  # pas du reseau, sinon il heriterait de la fragilite qu'il compense.
  local marqueur="$OPS_DIR/.en-cours-$flux"
  if [ "$phase" = 'started' ]; then
    printf '%s %s\n' "$(date +%s)" "$$" > "$marqueur" 2>/dev/null || true
  else
    rm -f "$marqueur" 2>/dev/null || true
  fi

  local snap_sql='null'
  [ -n "$snap" ] && snap_sql="'$snap'"
  if psql "$PGCONN" -v ON_ERROR_STOP=1 -q -c \
       "select public.fn_record_backup_heartbeat('$flux', $snap_sql, '$(hostname)', '$phase');" \
       >/dev/null 2>&1; then
    if [ "$phase" = 'started' ]; then
      info "Temoin de depart envoye ($flux)."
    else
      info "Temoin de vie envoye ($flux${snap:+, snapshot $snap})."
    fi
  else
    echo "AVERTISSEMENT: temoin '$phase' NON envoye pour '$flux' — base injoignable ?" >&2
    echo "               La sauvegarde, elle, suit son cours. Mais la sonde ne le saura pas." >&2
  fi
}

# Identifiant du dernier snapshot restic d'une etiquette donnee.
#
# Pourquoi il manquait. Jusqu'ici le temoin transmettait `null` : il prouvait que
# le SCRIPT etait alle au bout, pas qu'un instantane existait dans le depot
# restic. Deux choses differentes — un `restic backup` peut reussir et le depot
# etre inaccessible a la relecture.
#
# `jq` n'est pas installe sur ce poste : on lit le JSON au grep, ce qui suffit
# pour un champ plat. Non bloquant : sans identifiant, le temoin part quand meme.
# ON N'UTILISE PAS `--latest 1`. Piege verifie le 21/08/2026 : restic groupe les
# snapshots par (host, paths) et `--latest n` rend n snapshots PAR GROUPE. Le
# depot `long` en a trois groupes depuis que anarbib-vault.sql s'est ajoute au
# chemin (BG2-15, 19/08) : `--latest 1 --tag flux-long` y rendait TROIS lignes,
# dont la premiere datait du 30/06. Le `head -1` d'origine transmettait donc au
# temoin l'identifiant d'un snapshot vieux de sept semaines, en le presentant
# comme celui du tir qui venait de finir — un mensonge tranquille, et lisible
# seulement le jour de la restauration.
#
# On lit toutes les paires (time, short_id) et on garde celle dont la date est la
# plus grande. Comparaison sur l'epoch, pas sur la chaine ISO : les snapshots
# d'avant juillet portent un decalage +02:00 et les recents -03:00, un tri
# lexical les melangerait.
snapshot_id_de() {
  local tag="$1" json="" ligne="" ts="" best=0 id="" cur_iso=""
  json="$(restic snapshots --tag "$tag" --json 2>/dev/null)" || return 0
  while IFS= read -r ligne; do
    case "$ligne" in
      '"time":'*)
        cur_iso="$(printf '%s' "$ligne" | cut -d'"' -f4)"
        ;;
      '"short_id":'*)
        [ -n "$cur_iso" ] || continue
        ts="$(date -d "$cur_iso" +%s 2>/dev/null)" || continue
        if [ "$ts" -gt "$best" ]; then
          best="$ts"; id="$(printf '%s' "$ligne" | cut -d'"' -f4)"
        fi
        ;;
    esac
  done <<< "$(printf '%s' "$json" | grep -o '"time":"[^"]*"\|"short_id":"[^"]*"')"
  printf '%s' "$id"
  return 0
}

ensure_agent() {
  # Mode manuel : un agent charge (ta cle principale a passphrase) -> parfait.
  # Mode automate (timer systemd) : pas d'agent, mais ~/.ssh/config route
  #   l'hote Herbes Folles vers la cle dediee sans passphrase (IdentitiesOnly).
  #   Dans ce cas on NE meurt PAS : on verifie juste que la voie dediee existe.
  if ssh-add -l >/dev/null 2>&1; then
    info "SSH : agent charge (mode manuel)."
  else
    [ -f "$HOME/.ssh/id_ed25519_bg2" ] \
      || die "ni agent SSH, ni cle dediee ~/.ssh/id_ed25519_bg2 — connexion impossible."
    grep -q 'id_ed25519_bg2' "$HOME/.ssh/config" 2>/dev/null \
      || die "cle dediee presente mais absente de ~/.ssh/config — l'hote ne sera pas route dessus."
    info "SSH : pas d'agent, voie dediee (cle bg2 via ~/.ssh/config) — mode automate."
  fi
}

preflight() {
  require restic; require pg_dump; require psql
  [ -f "$RESTIC_PASSWORD_FILE" ] || die "passphrase restic absente: $RESTIC_PASSWORD_FILE"
  [ -f "$HOME/.pgpass" ]         || die "~/.pgpass absent (mot de passe DB)"
  [ -f "$DENYLIST" ]            || die "denylist absente: $DENYLIST"
  [ -f "$KNOWN" ]              || die "known-tables absente: $KNOWN"
  ensure_agent
  mkdir -p "$WORK"; chmod 700 "$WORK"
}

# --- CLASSEMENT CONSCIENT DES SCHEMAS (05/10/2026, BG2-13) ----------------
# Jusqu'au 05/10 le filet ne regardait que public, et le flux long ne prenait
# que public : le schema ingest (import catalogue : lots, lignes de staging,
# bases d'import H21) n'etait sauvegarde par AUCUN flux, alors que BG2-13 le
# disait « -> flux long » depuis le 30/06. Le classement nomme desormais les
# tables de public NUES et celles d'ingest QUALIFIEES (`ingest.<table>`).
#
# bg2_sql_tables et bg2_normaliser existent A L'IDENTIQUE dans
# scripts/ci/run-sql-suites.sh (filet de la CI) : la forge et le poste doivent
# lire le meme classement de la meme facon, sinon l'un laisse passer ce que
# l'autre refuse. src/tests/bg2-ingest-flux-long.test.js compare les deux
# definitions et les execute. Toute retouche se fait DES DEUX COTES.
bg2_sql_tables() {
  printf '%s\n' "select case when n.nspname = 'public' then c.relname else n.nspname || '.' || c.relname end
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname in ('public', 'ingest', 'private', 'api') and c.relkind in ('r', 'p')
 order by 1;"
}
bg2_normaliser() {
  sed -e 's/#.*$//' -e 's/[[:space:]]//g' | grep -v '^$' | LC_ALL=C sort -u || true
}
# Nom nu -> public.<nom> ; nom deja qualifie -> tel quel.
bg2_qualifier() {
  case "$1" in
    *.*) printf '%s\n' "$1" ;;
    *)   printf 'public.%s\n' "$1" ;;
  esac
}

real_tables() {
  psql "$PGCONN" -t -A -c "$(bg2_sql_tables)" | bg2_normaliser
}

# ----------------------------- LE FILET --------------------------------
filet() {
  info "Filet : comparaison tables reelles (${LONG_SCHEMAS[*]}) vs classees connues"
  local real new gone
  real="$(real_tables)"
  [ -n "$real" ] || die "Filet : aucune table lue en base — connexion ou droits ?"
  new="$(comm -23 <(printf '%s\n' "$real") <(bg2_normaliser < "$KNOWN") || true)"
  if [ -n "$new" ]; then
    { echo "!!! TABLES NON CLASSEES (ni court ni long connu) :"
      printf '%s\n' "$new" | sed 's/^/    - /'
      echo "    -> si PII : ajoute a $DENYLIST. Dans TOUS les cas : ajoute a $KNOWN, puis relance."
      echo "       (une table de public s'ecrit nue, une table d'ingest s'ecrit ingest.<table>)"; } >&2
    die "Filet declenche : classe les nouvelles tables avant de sauvegarder."
  fi
  gone="$(comm -23 <(bg2_normaliser < "$DENYLIST") <(printf '%s\n' "$real") || true)"
  [ -z "$gone" ] || { echo "!!! denylist : tables introuvables en base :" >&2
    printf '%s\n' "$gone" | sed 's/^/    - /' >&2; die "Corrige la denylist."; }
  info "Filet OK : toutes les tables sont classees."
}

# --------------------------- VAULT (BG2-15) ----------------------------
# Les 21 secrets du Vault ne sont dans AUCUN dump. Le pg_dump du long (public, ingest) ne
# les voit pas, et dumper le schema vault ne servirait a rien : les valeurs y
# sont chiffrees par une cle de plateforme qui, elle, ne sort jamais. Il faut
# donc les exporter DECHIFFRES.
#
# Vingt d'entre eux sont rejouables par rotation : ce sont des secrets partages
# entre des declencheurs SQL et des Edge Functions ; les perdre coute une
# reconfiguration des deux cotes, rien de plus.
#
# Le vingt-et-unieme, pseudonym_salt, ne l'est PAS. Le remplacer ne leve aucune
# erreur : ca rend seulement incoherents tous les jetons deja inscrits dans
# erasure_log, et le rejeu des effacements ne purge plus rien. Dommage RGPD
# silencieux. C'est la raison d'etre de cette fonction.
# Cf. RUNBOOK_restauration_BG2 §3.2-bis, qui decrivait deja la REINJECTION du
# sel mais supposait qu'on l'avait garde quelque part. Desormais on l'a.
#
# Le fichier produit contient des secrets EN CLAIR. Il vit dans $WORK (chmod
# 700) et le trap cleanup_work EXIT le detruit au shred, comme les dumps PII.
dump_vault() {
  local out="$1" n
  info "VAULT : export des secrets dechiffres"
  umask 077
  {
    echo "-- AnarBib — secrets du Vault, exportes le $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "-- SECRETS EN CLAIR. Rejeu sur une base cible : psql -f <ce fichier>"
    echo "-- Rejouer un secret deja present leve une erreur de doublon : c'est"
    echo "-- voulu. On ne veut pas ecraser en silence une valeur en place."
    psql "$PGCONN" -t -A -v ON_ERROR_STOP=1 -c \
      "select format('select vault.create_secret(%L, %L, %L);',
                     decrypted_secret, name, coalesce(description,''))
         from vault.decrypted_secrets order by name;"
  } > "$out"
  chmod 600 "$out"

  n="$(grep -c '^select vault.create_secret' "$out" || true)"
  [ "${n:-0}" -ge 1 ] \
    || die "VAULT : export vide — droits insuffisants sur vault.decrypted_secrets ?"
  # Canari, dans le style des controles anti-fuite ci-dessous : le seul secret
  # dont la perte est irreparable doit etre la, sinon on n'envoie rien.
  grep -q "'pseudonym_salt'" "$out" \
    || die "VAULT : pseudonym_salt ABSENT de l'export — ANNULE."
  info "Vault OK : $n secrets, dont pseudonym_salt."
}

# --------------------------- BACKUP LONG -------------------------------
backup_long() {
  preflight; filet
  # Apres le filet, pas avant : un refus du filet appelle `die`, donc OnFailure=
  # tire normalement (la machine tourne, puisque le script tourne). Signaler le
  # depart avant ferait ouvrir un second incident une heure plus tard, en double.
  # Ce qui est couvert ici, c'est tout ce qui est long : dump, restic, prune.
  heartbeat long started
  export RESTIC_REPOSITORY="$RESTIC_BASE/anarbib-long"
  local dump="$WORK/anarbib-long.sql"
  local vault="$WORK/anarbib-vault.sql"

  # Exclusions : noms nus = public, noms qualifies = leur schema (BG2-13).
  local EXCLUDES=() SCHEMAS=() t s
  while IFS= read -r t; do
    EXCLUDES+=(--exclude-table="$(bg2_qualifier "$t")")
  done < <(bg2_normaliser < "$DENYLIST")
  # BG2-14 : outboxes transitoires — exclues du long SANS aller au court
  if [ -f "$EXCLUDELONG" ]; then
    while IFS= read -r t; do
      EXCLUDES+=(--exclude-table="$(bg2_qualifier "$t")")
    done < <(bg2_normaliser < "$EXCLUDELONG")
  fi
  # BG2-13 (05/10/2026) : public ET ingest, dans le MEME fichier. Ne pas ouvrir
  # un second dump pour ingest : un chemin neuf ouvre une lignee restic neuve
  # (piege vecu avec anarbib-vault.sql, cf. BG2-15 plus bas).
  for s in "${LONG_SCHEMAS[@]}"; do SCHEMAS+=(--schema="$s"); done
  info "LONG : pg_dump (schemas ${LONG_SCHEMAS[*]}, ${#EXCLUDES[@]} tables exclues : PII + transitoires)"
  # I30 (05/10/2026) : PLUS de --no-privileges. Sans GRANT ni REVOKE dans le
  # dump, une base restauree perdait les droits de public (l'application ne
  # lit plus rien) et toute fonction recreee reprenait l'EXECUTE a PUBLIC.
  # Apres rejeu, bg2-repose-droits.sh rend les droits exacts (runbook §3.2-quater).
  pg_dump "$PGCONN" "${SCHEMAS[@]}" "${EXCLUDES[@]}" --no-owner --file="$dump"

  info "Controle anti-fuite (aucune PII ne doit sortir)"
  grep -qE "^CREATE TABLE public\.($PII_CANARIES) " "$dump" && die "FUITE PII dans le dump long — ANNULE."
  # Au-dela des temoins : AUCUNE table exclue, quel que soit son schema.
  local x
  for x in "${EXCLUDES[@]}"; do
    x="${x#--exclude-table=}"
    if grep -qE "^CREATE (UNLOGGED )?TABLE ${x//./\\.} \(" "$dump"; then
      die "FUITE : table exclue $x presente dans le dump long — ANNULE."
    fi
  done
  # Et chaque schema du flux est bien la : un ingest disparu du dump ne doit
  # pas passer pour une sauvegarde complete.
  for s in "${LONG_SCHEMAS[@]}"; do
    grep -qE "^CREATE (TABLE|VIEW|MATERIALIZED VIEW|FUNCTION) $s\." "$dump" \
      || die "schema $s ABSENT du dump long — ANNULE."
  done
  # Et les droits sont dans le dump : un --no-privileges revenu se voit ici.
  grep -qE '^GRANT ' "$dump" || die "aucun GRANT dans le dump long (--no-privileges ?) — ANNULE."
  info "Dump long OK : $(grep -c '^CREATE TABLE ' "$dump") tables (public $(grep -c '^CREATE TABLE public\.' "$dump"), ingest $(grep -c '^CREATE TABLE ingest\.' "$dump")), $(grep -cE '^CREATE (OR REPLACE )?FUNCTION ' "$dump") fonctions, $(grep -cE '^(GRANT|REVOKE) ' "$dump") droits, $(du -h "$dump" | cut -f1)"

  dump_vault "$vault"

  unlock_stale
  # BG2-15 : les secrets du Vault partent avec le flux long, pas le court — la
  # retention du court est de 7 jours, trop courte pour un sel qu'on peut avoir
  # a retrouver des mois plus tard.
  restic backup "$dump" "$vault" --tag flux-long --tag bg2
  # BG2-15 (19/08) : --group-by tags. Par defaut restic groupe les snapshots par
  # hote ET par chemins ; ajouter anarbib-vault.sql a la liste des chemins a donc
  # ouvert un groupe neuf, laissant l'ancienne lignee figee et hors retention
  # (elle ne tombera jamais, plus aucun tir ne la rejoint). Grouper par etiquette
  # rend la retention independante et des chemins et de l'hote : elle survivra
  # aussi au jour ou ces flux tireront depuis un VPS et non depuis cette machine.
  restic forget --tag flux-long --group-by tags \
    --keep-daily 7 --keep-weekly 4 --keep-monthly 6
  heartbeat long ok "$(snapshot_id_de flux-long)"
  info "Flux long termine."
}

# --------------------------- BACKUP COURT ------------------------------
backup_court() {
  preflight; filet
  heartbeat court started
  export RESTIC_REPOSITORY="$RESTIC_BASE/anarbib-court"
  local dump="$WORK/anarbib-court.sql"

  local TABLES=()
  while IFS= read -r t; do
    TABLES+=(--table="$(bg2_qualifier "$t")")
  done < <(bg2_normaliser < "$DENYLIST")
  local a; for a in "${AUTH_TABLES[@]}"; do TABLES+=(--table="$a"); done
  info "COURT : pg_dump (allowlist stricte, ${#TABLES[@]} tables)"
  # I30 : droits gardes, comme le long (les tables PII de public y ont les leurs).
  pg_dump "$PGCONN" "${TABLES[@]}" --no-owner --file="$dump"

  info "Controle anti-fuite inverse (aucune table du long ne doit entrer)"
  grep -qE "^CREATE TABLE public\.($LONG_CANARIES) " "$dump" && die "FUITE : une table du long dans le court — ANNULE."
  grep -qE '^CREATE TABLE auth\.users ' "$dump" || die "auth.users absent du dump court — ANNULE."
  grep -qE '^GRANT ' "$dump" || die "aucun GRANT dans le dump court (--no-privileges ?) — ANNULE."
  info "Dump court OK : $(grep -c '^CREATE TABLE ' "$dump") tables, $(du -h "$dump" | cut -f1)"

  unlock_stale
  restic backup "$dump" --tag flux-court --tag bg2
  restic forget --tag flux-court --group-by tags --keep-daily 7
  heartbeat court ok "$(snapshot_id_de flux-court)"
  info "Flux court termine. (dump clair — comptes — efface)"
}

# -------------------------- BACKUP STORAGE -----------------------------
backup_storage() {
  preflight; require supabase
  heartbeat storage started
  export RESTIC_REPOSITORY="$RESTIC_BASE/anarbib-storage"
  mkdir -p "$STORAGE_WORK"; chmod 700 "$STORAGE_WORK"

  info "STORAGE : resync systematique des ${#BUCKETS[@]} buckets (peut prendre 1-2 min)"
  local b
  for b in "${BUCKETS[@]}"; do
    rm -rf "$STORAGE_WORK/$b"   # BG2 (02/07): purge avant resync -> evite le nesting $b/$b
    ( cd "$SUPABASE_REPO" && supabase storage cp --linked --experimental -r \
        "ss:///$b" "$STORAGE_WORK/$b" ) > "$STORAGE_WORK/.log-$b.txt" 2>&1 \
      && echo "    OK  $b ($(find "$STORAGE_WORK/$b" -type f 2>/dev/null | wc -l))" \
      || echo "    !!  $b — voir $STORAGE_WORK/.log-$b.txt"
  done
  info "Resync terminee : $(du -sh "$STORAGE_WORK" | cut -f1), $(find "$STORAGE_WORK" -type f -not -name '.log-*' | wc -l) fichiers"

  unlock_stale
  restic backup "$STORAGE_WORK" --tag flux-storage --tag bg2
  restic forget --tag flux-storage --group-by tags \
    --keep-daily 7 --keep-weekly 4 --keep-monthly 6
  heartbeat storage ok "$(snapshot_id_de flux-storage)"
  info "Flux storage termine. (miroir local conserve, chmod 700)"
}

# -------------------------- RESTORE-TEST -------------------------------
# Test REEL de la sequence de sinistre : squelette auth + roles -> long -> court.
cmd_restore_test() {
  preflight; require docker
  local ctn="bg2-restore-test" dir="$WORK/restore-test"
  rm -rf "$dir"; mkdir -p "$dir"
  trap 'docker rm -f "$ctn" >/dev/null 2>&1 || true; rm -rf "$dir"' EXIT

  info "Recuperation des dumps long + court depuis Herbes Folles"
  RESTIC_REPOSITORY="$RESTIC_BASE/anarbib-long"  restic restore latest --tag flux-long  --target "$dir/long"
  RESTIC_REPOSITORY="$RESTIC_BASE/anarbib-court" restic restore latest --tag flux-court --target "$dir/court"
  local long court
  long="$(find "$dir/long" -name 'anarbib-long.sql' | head -1)"
  court="$(find "$dir/court" -name 'anarbib-court.sql' | head -1)"
  [ -n "$long" ] && [ -n "$court" ] || die "dump(s) introuvable(s) apres restauration"

  info "Postgres jetable ($PG_IMAGE)"
  docker rm -f "$ctn" >/dev/null 2>&1 || true
  docker run -d --name "$ctn" -e POSTGRES_PASSWORD=throwaway -p 55434:5432 "$PG_IMAGE" >/dev/null
  local i; for i in $(seq 1 20); do docker exec "$ctn" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 1; done

  info "Squelette auth + roles Supabase (prerequis du jour J)"
  docker exec -i "$ctn" psql -U postgres -d postgres >/dev/null <<'SQL'
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT NULL::uuid $f$;
DO $$ BEGIN CREATE TYPE auth.factor_type   AS ENUM ('totp','webauthn','phone'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE auth.factor_status AS ENUM ('unverified','verified');   EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE auth.aal_level     AS ENUM ('aal1','aal2','aal3');       EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE anon;          EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE authenticated; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE service_role;  EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE authenticator; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- I30 : ce qu'une instance Supabase neuve porte deja et qu'aucun dump n'emporte —
-- les extensions du projet (index trigramme, unaccent…) et les fonctions auth.*
-- que les politiques et les vues appellent (definitions reelles de Supabase).
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm     WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS unaccent    WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto    WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE OR REPLACE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $f$
  select coalesce(current_setting('request.jwt.claim.role', true), (current_setting('request.jwt.claims', true)::jsonb ->> 'role'))::text $f$;
CREATE OR REPLACE FUNCTION auth.email() RETURNS text LANGUAGE sql STABLE AS $f$
  select coalesce(current_setting('request.jwt.claim.email', true), (current_setting('request.jwt.claims', true)::jsonb ->> 'email'))::text $f$;
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $f$
  select coalesce(nullif(current_setting('request.jwt.claim', true), ''), nullif(current_setting('request.jwt.claims', true), ''))::jsonb $f$;
SQL

  info "Rejeu LONG puis COURT"
  docker exec -i "$ctn" psql -U postgres -d postgres -v ON_ERROR_STOP=0 < "$long"  > "$dir/long.log"  2>&1 || true
  docker exec -i "$ctn" psql -U postgres -d postgres -v ON_ERROR_STOP=0 < "$court" > "$dir/court.log" 2>&1 || true

  # I30 : les droits exacts de la production (runbook §3.2-quater).
  info "Repose des droits (bg2-repose-droits.sh)"
  bash "$OPS_DIR/bg2-repose-droits.sh" "$long" "$court" \
    | docker exec -i "$ctn" psql -U postgres -d postgres -v ON_ERROR_STOP=1 > "$dir/repose.log" 2>&1 \
    || echo "    !!! repose des droits en echec (voir $dir/repose.log)" >&2

  echo; info "VERDICT"
  docker exec "$ctn" psql -U postgres -d postgres -c \
    "select 'tables public' t, count(*)::text v from pg_tables where schemaname='public'
     union all select 'tables ingest',   count(*)::text from pg_tables where schemaname='ingest'
     union all select 'auth.users',      count(*)::text from auth.users
     union all select 'profiles',        count(*)::text from profiles
     union all select 'books',           count(*)::text from books
     union all select 'emprestimos_v2',  count(*)::text from emprestimos_v2;"
  # A part : si ingest manquait, l'union ci-dessus perdrait tout le verdict.
  docker exec "$ctn" psql -U postgres -d postgres -tAc \
    "select 'ingest.book_import_baselines : ' || count(*) || ' lignes' from ingest.book_import_baselines" \
    || echo "    !!! ingest.book_import_baselines introuvable apres rejeu" >&2
  # Attendus tires du classement, plus d'un nombre fige (« ~172 » datait du 01/07).
  local s n att
  for s in "${LONG_SCHEMAS[@]}"; do
    att="$(attendu_apres_restauration "$s")"
    n="$(docker exec "$ctn" psql -U postgres -d postgres -tAc \
           "select count(*) from pg_tables where schemaname='$s'" 2>/dev/null || echo '?')"
    if [ "$n" = "$att" ]; then
      echo "    tables $s : $n, attendu $att (classement - exclues du long) : OK"
    else
      echo "    !!! tables $s : $n, attendu $att (classement - exclues du long) : ECART" >&2
    fi
  done
  echo "    (auth.users et profiles non nuls ; books ~2674)"

  # I30 : memes droits, memes fonctions, vues, tables et sequences que la
  # production, schema par schema (bg2-empreinte-droits.sql, lu des deux
  # cotes). Seuls ecarts admis : les privileges par defaut de supabase_admin,
  # role de la plateforme absent d'un Postgres nu, qu'une instance neuve pose
  # elle-meme.
  local prod_e rest_e ecarts
  prod_e="$(psql "$PGCONN" -X -q -A -F ' ' -t -f "$OPS_DIR/bg2-empreinte-droits.sql" | grep -v '/defaut:supabase_admin ' | sort)"
  rest_e="$(docker exec -i "$ctn" psql -U postgres -d postgres -X -q -A -F ' ' -t < "$OPS_DIR/bg2-empreinte-droits.sql" | grep -v '/defaut:supabase_admin ' | sort)"
  ecarts="$(diff <(printf '%s\n' "$prod_e") <(printf '%s\n' "$rest_e") | grep '^[<>]' || true)"
  if [ -n "$prod_e" ] && [ -z "$ecarts" ]; then
    echo "    droits et objets : $(printf '%s\n' "$prod_e" | wc -l) empreintes identiques a la production : OK"
  else
    { echo "    !!! droits et objets : ECART avec la production (< production, > restauration) :"
      printf '%s\n' "$ecarts" | sed 's/^/        /'; } >&2
  fi
  info "Nettoyage du bac a sable"
}

# Nombre de tables d'un schema qu'une restauration long + court doit recreer :
# le classement, moins les tables exclues du long sans aller au court
# (bg2-exclude-long.txt). Les PII de la denylist reviennent par le court.
attendu_apres_restauration() {
  local s="$1"
  comm -23 <(bg2_normaliser < "$KNOWN") \
           <( { [ -f "$EXCLUDELONG" ] && cat "$EXCLUDELONG"; true; } | bg2_normaliser ) \
    | if [ "$s" = public ]; then grep -vc '\.'; else grep -c "^$s\."; fi || true
}

# --------------------------- PRUNE MENSUEL -----------------------------
# BG2-17 (21/08/2026) : le prune sort du tir de sauvegarde.
#
# NE PAS RAJOUTER `--no-prune` AUX `restic forget` CI-DESSUS. Le drapeau a existe,
# il n'existe plus : depuis restic 0.17 le `forget` ne prune QUE si on lui passe
# `--prune`, et `--no-prune` est devenu une option inconnue. La version installee
# ici est 0.18.1. Un `forget` nu fait donc exactement ce que BG2-17 veut.
#
# Vecu le 21/08/2026, tir de 15:48 : le drapeau a fait sortir restic en erreur
# APRES l'enregistrement du snapshot. Consequences en cascade — la retention n'a
# pas ete appliquee, le temoin d'arrivee n'est jamais parti (le script mourait
# avant), et la sonde a signale un « tir interrompu » pour un tir dont la donnee
# etait pourtant bien sauvegardee. Les trois flux portaient le drapeau.
#
# POURQUOI. `restic forget --prune` faisait porter au tir de sauvegarde le cout
# du prune, qui ne tombe que lorsque la retention retire un instantane. La duree
# devenait donc BIMODALE. Mesure sur le flux storage : 11 min 18 s sans prune
# (09/08), 22 min 56 s avec (20/08), pour une borne systemd de 30 min. Sept
# minutes de marge, et pas un document numerise n'est encore verse.
#
# CE QUE LA CORRECTION NE TOUCHE PAS, ET POURQUOI. Ni TimeoutStartSec, ni le
# seuil d'alarme d'une heure. Ces deux nombres sont couples : le seuil vaut le
# DOUBLE du timeout, si bien qu'un tir legitime ne peut jamais l'atteindre —
# systemd le tue avant — et c'est ce qui rend le faux positif impossible. Les
# relever aurait exige de les relever ensemble. Sortir le prune evite ce noeud.
#
# `forget` RESTE dans chaque flux : il ne touche que des metadonnees, il est
# quasi instantane, et la politique de retention continue donc de s'appliquer a
# chaque tir. Seule la RECUPERATION d'espace est differee. Consequence assumee :
# jusqu'a un mois de donnees non reclamees dans les trois depots. La
# deduplication restic rend le surcout modeste, mais il n'est pas nul.
#
# CE PRUNE N'ECRIT AUCUN TEMOIN DE VIE. Ce n'est pas une sauvegarde ; l'alarme
# de silence ne doit pas le compter comme telle, sous peine de tenir un flux
# pour vivant alors que seul son menage a tourne.
prune_repos() {
  preflight
  local repo
  for repo in anarbib-long anarbib-court anarbib-storage; do
    export RESTIC_REPOSITORY="$RESTIC_BASE/$repo"
    info "Prune de $repo..."
    unlock_stale
    restic prune || die "prune echoue sur $repo"
  done
  info "=== Prune des trois depots termine. ==="
}

# ------------------------------ MAIN -----------------------------------
case "${1:-}" in
  backup|prune|restore-test) prendre_le_verrou ;;
esac
case "${1:-}" in
  check)        preflight; filet; info "Tout est pret (prerequis + filet)." ;;
  backup)
    case "${2:-}" in
      long)    backup_long ;;
      court)   backup_court ;;
      storage) backup_storage ;;
      all)     backup_long; backup_court; backup_storage; info "=== Les trois flux sont sauvegardes. ===" ;;
      *) echo "Usage: $0 backup {long|court|storage|all}" >&2; exit 2 ;;
    esac ;;
  prune)        prune_repos ;;
  restore-test) cmd_restore_test ;;
  *) echo "Usage: $0 {check | backup long|court|storage|all | prune | restore-test}" >&2; exit 2 ;;
esac
