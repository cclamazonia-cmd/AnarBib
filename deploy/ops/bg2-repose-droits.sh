#!/bin/bash
# =====================================================================
# bg2-repose-droits.sh — I30 (05/10/2026) : la repose des droits après
# rejeu d'un dump #BG2.
#
#   bg2-repose-droits.sh <dump.sql> [<dump.sql> ...]   > repose.sql
#   (schémas : BG2_SCHEMAS, par défaut « public ingest private api » ; passer
#   TOUS les dumps rejoués — long ET court —, la remise à zéro touchant tout
#   le schéma)
#   psql "$CIBLE" -v ON_ERROR_STOP=0 -f repose.sql
#
# Pourquoi. pg_dump écrit les droits d'un objet comme une DIFFÉRENCE avec les
# droits par défaut de Postgres (acldefault) : il suppose que l'objet naît
# avec eux. Or une instance Supabase neuve accorde d'office, à chaque objet
# créé par `postgres`, des droits à anon, authenticated et service_role
# (ALTER DEFAULT PRIVILEGES de la plateforme). Rejoué tel quel, le dump
# AJOUTE ses GRANT à ces droits d'office sans les retirer : mesuré au banc le
# 05/10, des fonctions SECURITY DEFINER (assign_book_to_work…) reviennent
# exécutables par anon, et les tables de public avec des droits d'écriture
# qu'elles n'ont pas en production.
#
# Ce que fait la repose, schéma par schéma, dans une transaction :
#   1. ramener chaque objet aux droits par défaut de Postgres — tables, vues
#      et séquences au seul propriétaire ; fonctions au propriétaire et à
#      PUBLIC (EXECUTE), comme acldefault('f') ;
#   2. ramener les privilèges par défaut du schéma pour `postgres` à rien ;
#   3. rejouer, du dump, les lignes GRANT et REVOKE, et les ALTER DEFAULT
#      PRIVILEGES de `postgres` : elles rendent exactement l'état de la
#      production (le dump doit avoir été pris SANS --no-privileges).
# Les droits sur les SCHÉMAS ne sont pas touchés : le rejeu les pose, et
# l'empreinte du banc les trouve identiques.
# Contrôle : bg2-empreinte-droits.sql, en production et sur la cible.
# =====================================================================
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <dump.sql> [<dump.sql> ...]" >&2; exit 2; }
for d in "$@"; do [ -f "$d" ] || { echo "dump introuvable : $d" >&2; exit 2; }; done
read -r -a schemas <<< "${BG2_SCHEMAS:-public ingest private api}"
n=$(cat "$@" | grep -cE '^(GRANT|REVOKE) ' || true)
[ "$n" -gt 0 ] || { echo "le dump ne porte aucun GRANT ni REVOKE : pris en --no-privileges ? (repose impossible)" >&2; exit 3; }
ROLES="PUBLIC, anon, authenticated, service_role"
echo "-- repose des droits (I30), d'après $(for d in "$@"; do basename "$d"; done | paste -sd ' ') : $n lignes GRANT/REVOKE"
echo "BEGIN;"
for s in "${schemas[@]}"; do
  cat <<SQL
-- $s : aux droits par défaut de Postgres
REVOKE ALL ON ALL TABLES    IN SCHEMA $s FROM $ROLES;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA $s FROM $ROLES;
REVOKE ALL ON ALL ROUTINES  IN SCHEMA $s FROM anon, authenticated, service_role;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA $s TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA $s REVOKE ALL ON TABLES    FROM $ROLES;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA $s REVOKE ALL ON SEQUENCES FROM $ROLES;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA $s REVOKE ALL ON FUNCTIONS FROM anon, authenticated, service_role;
SQL
done
echo "-- les droits de la production, tels que le dump les porte"
# Seulement les objets des schemas sauvegardes : le dump court porte aussi les
# droits des tables auth.* (roles de la plateforme, proprietaire
# supabase_auth_admin) — `postgres` ne peut pas les rejouer, et une seule
# erreur annulerait toute la transaction.
liste="$(printf '%s|' "${schemas[@]}")"; liste="${liste%|}"
cat "$@" | grep -E '^(GRANT|REVOKE) ' \
  | grep -E " ON (TABLE|SEQUENCE|FUNCTION|PROCEDURE|SCHEMA) \"?($liste)\"?[ .;]"
# Les privilèges par défaut ne se rejouent que pour `postgres`, le rôle qui
# restaure : ceux de supabase_admin sont ceux de la plateforme, qu'une instance
# neuve pose elle-même, et `postgres` n'a pas le droit de les changer (une
# seule erreur annulerait toute la transaction).
cat "$@" | grep -E '^ALTER DEFAULT PRIVILEGES FOR ROLE postgres ' || true
echo "COMMIT;"
