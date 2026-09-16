#!/usr/bin/env bash
# ===========================================================================
# run-image-replay.sh — rejoue les migrations dans la base `postgres` d'une
# image supabase/postgres RÉELLE, avec les scripts de la pile auto-hébergée.
# Backlog I18 (16/09/2026), corollaire de DOC-GRANT-2 / DOC-GRANT-3.
# ---------------------------------------------------------------------------
# POURQUOI UN SECOND REJEU. Le job `sql-tests` crée `anarbib_test` depuis
# `template0` : `pg_default_acl` y est vide, chaque fonction naît fermée, et
# le vert atteste les suites — pas qu'une image Supabase rejoue le dépôt. Une
# image réelle pose `anon=X` dans le défaut des fonctions de `public` pour
# `postgres` ET `supabase_admin` : sans A.1 avant le socle, un rejeu livre des
# centaines de fonctions ouvertes à anon (371 dont 233 DEFINER mesurées le
# 15/09 sur l'installateur de la PR #28 avant correction, contre 133 en prod).
# La CI ne le voyait pas ; un contributeur extérieur l'a découvert à notre
# place. Ce script rejoue donc EXACTEMENT ce que `install.sh` / `bootstrap.sh`
# font sur une machine vierge, dans la base `postgres` de l'image que le
# service `db` de sql-tests.yml lance déjà :
#
#   1. deploy/init-db/01-roles.sh    — mots de passe des rôles de service,
#                                       A.1 (anon retiré du défaut des deux
#                                       rôles, entrées conservées), pg_cron
#                                       (bootstrap.sh, étape 2/8) ;
#   2. ce que la pile obtient de ses SERVICES avant de migrer, et que la CI
#      n'a pas : le sel de pseudonymisation par vault.create_secret (étape
#      3/8, le Vault de l'image est réel), puis ce que GoTrue et Storage
#      auraient posé (étape 4/8) — tests/sql/_ci_setup_image_services_stub.sql
#      (colonnes récentes d'auth.users), puis les stubs `auth` (les quatre
#      helpers de référence, dont auth.jwt() que l'image n'a pas, et les
#      GRANT) et `storage` (storage.buckets + les buckets attendus) de
#      sql-tests. Mesuré le 16/09 : sans ce pont, le socle s'arrête à
#      « auth.jwt() does not exist », puis 20260623204043 sur une colonne
#      d'auth.users, puis 20260702081711 sur un auth.uid() d'origine qui ne
#      lit pas request.jwt.claims ;
#   3. deploy/scripts/run-migrations.sh — toutes les migrations, sous
#                                       `postgres` (A.2), arrêt à la première
#                                       erreur, journal dans
#                                       supabase_migrations.schema_migrations
#                                       (étape 5/8).
#
# Les deux scripts de deploy/ parlent à Postgres par `psql -U <rôle>` sans
# hôte : dans le conteneur ils passent par le socket, ici par TCP grâce à
# PGHOST/PGPASSWORD. C'est voulu : un même fichier sert la pile et la CI, et
# un changement qui casse l'un casse l'autre au même endroit.
#
# CE QUE CE JOB ATTESTE : « ça passe ou ça casse ». Aucune suite n'est jouée
# ici (c'est le rôle de sql-tests). Il vérifie seulement que A.1 a bien été
# appliqué (et pas « différé », ce qui serait un vert menteur), que chaque
# fichier de migration est passé, et il IMPRIME les mesures qui comptent :
# fonctions exécutables par anon (nombre + empreinte MD5, à comparer à la
# production : 133 / 56ed10b70dfd69e8436b6a4e818093ef le 15/09/2026), DEFINER
# parmi elles, jobs pg_cron, tables sans RLS. Une assertion fermée sur ces
# nombres relève de B22, pas d'ici.
#
# CE QU'IL NE FAIT PAS : GoTrue et Storage ne tournent pas, leurs migrations
# non plus — le pont du point 2 en pose le strict nécessaire, et il est écrit.
# Si une migration future dépend d'un objet `auth.*`/`storage.*` de plus, ce
# job rougira au même endroit qu'une restauration à froid, et le stub dira
# quoi ajouter.
#
# Variables : PGHOST (requis) · PGPORT(=5432) · PGPASSWORD(=postgres) —
# POSTGRES_PASSWORD (lu par 01-roles.sh) est aligné sur PGPASSWORD si absent.
# PGUSER est volontairement ignoré : chaque script choisit son rôle.
# ===========================================================================
set -uo pipefail

cd "$(dirname "$0")/../.." || { echo "racine dépôt introuvable"; exit 2; }

: "${PGHOST:?PGHOST requis (hôte du serveur Postgres qui porte la base à rejouer)}"
export PGHOST
export PGPORT="${PGPORT:-5432}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$PGPASSWORD}"
unset PGUSER PGDATABASE

ROLES_SH="deploy/init-db/01-roles.sh"
MIGR_SH="deploy/scripts/run-migrations.sh"
MIG_DIR="supabase/migrations"
SERVICES_STUB="tests/sql/_ci_setup_image_services_stub.sql"
AUTH_STUB="tests/sql/_ci_setup_auth_stub.sql"
STORAGE_STUB="tests/sql/_ci_setup_storage_stub.sql"

fail() { echo "::error::$*"; echo "ÉCHEC : $*" >&2; exit 1; }
command -v psql >/dev/null 2>&1 || fail "psql introuvable (installer postgresql-client)"
[ -f "$ROLES_SH" ] || fail "script des rôles absent : $ROLES_SH"
[ -f "$MIGR_SH" ]  || fail "script des migrations absent : $MIGR_SH"
[ -d "$MIG_DIR" ]  || fail "dossier des migrations absent : $MIG_DIR"
[ -f "$SERVICES_STUB" ] || fail "stub des services absent : $SERVICES_STUB"
[ -f "$AUTH_STUB" ]     || fail "stub auth absent : $AUTH_STUB"
[ -f "$STORAGE_STUB" ]  || fail "stub storage absent : $STORAGE_STUB"

PSA() { psql -h "$PGHOST" -U supabase_admin -d postgres -v ON_ERROR_STOP=1 "$@"; }
PSP() { psql -h "$PGHOST" -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"; }

echo "::group::attente du serveur ($PGHOST:$PGPORT, supabase_admin)"
ready=0
for i in $(seq 1 90); do
  if PSA -tAc 'select 1' >/dev/null 2>&1; then echo "serveur prêt après ${i}s"; ready=1; break; fi
  sleep 1
done
[ "$ready" -eq 1 ] || fail "serveur Postgres injoignable en TCP en supabase_admin"
sleep 2
# Les rôles de l'image doivent exister : c'est le serveur FINAL, pas celui
# d'amorçage, et c'est ce qui rend A.1 applicable tout de suite (pas différé).
for r in postgres anon authenticated service_role; do
  [ "$(PSA -tAc "select 1 from pg_roles where rolname = '$r'")" = "1" ] || fail "rôle $r absent : ce n'est pas une image supabase/postgres initialisée"
done
echo "image : $(PSA -tAc 'show server_version') ; rôles de l'image présents"
echo "::endgroup::"

echo "::group::1/3 — $ROLES_SH (mots de passe des rôles, A.1, pg_cron)"
sh "$ROLES_SH" || fail "$ROLES_SH a échoué"
echo "::endgroup::"

echo "::group::contrôle de A.1 et de pg_cron avant le rejeu"
# A.1 : les deux entrées pg_default_acl (postgres, supabase_admin) existent
# et ne portent plus anon=. Un « différé » de 01-roles.sh (rôle anon absent)
# est impossible ici — on l'a vérifié — mais on ne fait pas confiance à un
# message : on relit le catalogue.
acl_ko="$(PSA -tAc "
  select string_agg(pg_get_userbyid(d.defaclrole) || ' → ' || d.defaclacl::text, ' ; ')
    from pg_default_acl d join pg_namespace ns on ns.oid = d.defaclnamespace
   where ns.nspname = 'public' and d.defaclobjtype = 'f'
     and pg_get_userbyid(d.defaclrole) in ('postgres','supabase_admin')
     and d.defaclacl::text like '%anon=%'")"
[ -z "$acl_ko" ] || fail "A.1 non appliqué : anon encore dans le défaut des fonctions ($acl_ko)"
acl_n="$(PSA -tAc "
  select count(*) from pg_default_acl d join pg_namespace ns on ns.oid = d.defaclnamespace
   where ns.nspname = 'public' and d.defaclobjtype = 'f'
     and pg_get_userbyid(d.defaclrole) in ('postgres','supabase_admin')")"
[ "$acl_n" = "2" ] || fail "A.1 : $acl_n entrée(s) pg_default_acl au lieu de 2 (une entrée vidée a disparu — DOC-GRANT-1)"
echo "A.1 : anon retiré du défaut des fonctions de public pour postgres et supabase_admin (2 entrées conservées)"
[ "$(PSA -tAc "select 1 from pg_extension where extname = 'pg_cron'")" = "1" ] || fail "pg_cron absent après $ROLES_SH"
echo "pg_cron : extension présente, cron.job accessible : $(PSP -tAc 'select count(*) from cron.job') job(s)"
echo "::endgroup::"

echo "::group::2/3 — ce que la pile obtient de ses services avant de migrer"
# Le sel de pseudonymisation, comme bootstrap.sh --sel-jetable (étape 3/8) :
# une migration l'exige, et le Vault de l'image est le vrai (pas de stub).
# Valeur jetable : base jetable, aucun jeton à rendre incohérent.
PSA -q -c "
  select vault.create_secret(encode(gen_random_bytes(32), 'hex'), 'pseudonym_salt',
                             'Sel jetable du job rejeu-image (I18) — pas un secret')
   where not exists (select 1 from vault.secrets where name = 'pseudonym_salt')" >/dev/null \
  || fail "pose du sel de pseudonymisation au Vault"
echo "vault : pseudonym_salt posé par vault.create_secret (Vault réel de l'image)"
# Ce que GoTrue et Storage auraient posé (étape 4/8) — lire l'en-tête du stub
# des services : les quatre helpers auth.* de référence et les GRANT (stub
# auth de sql-tests, dont le CREATE TABLE IF NOT EXISTS ne fait rien ici),
# storage.buckets et ses buckets (stub storage), puis ce que l'image seule
# laisse manquer : colonnes récentes d'auth.users, droits de postgres sur les
# tables de storage (stub des services).
for stub in "$AUTH_STUB" "$STORAGE_STUB" "$SERVICES_STUB"; do
  if ! PSA -q -f "$stub" > /tmp/stub.log 2>&1; then
    tail -20 /tmp/stub.log; fail "application de $stub"
  fi
done
echo "auth : helpers auth.* de référence et GRANT ($AUTH_STUB), colonnes récentes d'auth.users ($SERVICES_STUB)"
echo "storage : storage.buckets et $(PSA -tAc 'select count(*) from storage.buckets') buckets posés ($STORAGE_STUB)"
for h in uid jwt role email; do
  [ "$(PSA -tAc "select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'auth' and p.proname = '$h'")" = "1" ] \
    || fail "auth.$h() absent : ce que bootstrap.sh attend de GoTrue n'est pas là"
done
echo "les quatre helpers auth.* que bootstrap.sh attend sont là"
echo "::endgroup::"

echo "::group::3/3 — $MIGR_SH (toutes les migrations, sous postgres)"
MIG_DIR="$MIG_DIR" sh "$MIGR_SH" || fail "$MIGR_SH a échoué (voir la migration nommée ci-dessus)"
echo "::endgroup::"

echo "::group::contrôle du rejeu"
attendu="$(ls "$MIG_DIR"/*.sql | grep -v '/_' | wc -l | tr -d ' ')"
journal="$(PSP -tAc 'select count(*) from supabase_migrations.schema_migrations')"
[ "$attendu" = "$journal" ] || fail "migrations : $journal journalisée(s) pour $attendu fichier(s)"
echo "migrations : $journal/$attendu, toutes journalisées dans supabase_migrations.schema_migrations"
proprio="$(PSP -tAc "
  select string_agg(o || ':' || n, ', ') from (
    select pg_get_userbyid(p.proowner) o, count(*) n from pg_proc p
      join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname = 'public' group by 1 order by 2 desc) s")"
echo "propriétaires des fonctions de public : ${proprio:-aucune}"
echo "::endgroup::"

echo "::group::mesures (informatives — la référence est la production)"
# Même périmètre et même formule que les relevés du 07/09 et du 15/09 (constat
# §9.9, backlog I16) : les quatre schémas du dépôt, une ligne
# « schéma.nom(arguments nommés) » par fonction, triée en C, jointe par sauts
# de ligne — c'est ce qui donne 133 / 56ed10b7… en production le 15/09/2026.
PSP -At -F ' ' -c "
  with f as (
    select ns.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' as sig,
           p.prosecdef
      from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname in ('public', 'api', 'ingest', 'private')
       and has_function_privilege('anon', p.oid, 'EXECUTE'))
  select 'fonctions exécutables par anon (public, api, ingest, private) : ' || count(*)
      || ' (dont SECURITY DEFINER : ' || count(*) filter (where prosecdef) || ')'
    from f
  union all
  select 'empreinte MD5 de la liste (prod 15/09/2026 : 133 / 56ed10b70dfd69e8436b6a4e818093ef) : '
      || md5(string_agg(sig, E'\n' order by sig collate \"C\"))
    from f
  union all
  select 'jobs pg_cron planifiés : ' || count(*) from cron.job
  union all
  select 'tables de public sans RLS (doit valoir 0) : ' || count(*)
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
  union all
  select 'tables de public : ' || count(*)
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'"
echo "::endgroup::"

echo "-------------------------------------------------------"
echo "✅ LE DÉPÔT REJOUE SUR L'IMAGE supabase/postgres ($journal migrations sous postgres, A.1 avant le socle)"
exit 0
