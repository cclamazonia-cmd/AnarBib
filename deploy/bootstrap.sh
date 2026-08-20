#!/usr/bin/env bash
# =============================================================================
# AnarBib — bootstrap : d'une machine nue à une pile qui sert le catalogue
# =============================================================================
# POURQUOI CE SCRIPT EXISTE. Les quatre briques existent déjà et sont éprouvées
# (séances A et B des 17 et 18/08). Ce qui manquait, c'est l'ordre — et l'ordre
# est la seule chose qui compte ici. Trois des quinze pannes des répétitions
# venaient d'un enchaînement, pas d'un défaut :
#
#   * les rôles de service n'ont pas de mot de passe à la création : posés trop
#     tard, les services échouent en boucle sur « password authentication
#     failed » ;
#   * les vues matérialisées ne voyagent pas dans un dump : sans rafraîchisse-
#     ment, la base est complète et le catalogue s'affiche VIDE ;
#   * PostgREST lit le schéma UNE FOIS, à son démarrage : démarré avant la
#     restauration, il sert un catalogue vide sur une base pleine.
#
# D'où : base seule → rôles → schéma+données → vues → et SEULEMENT ENSUITE les
# autres services.
#
# USAGE
#   ./bootstrap.sh --depuis-le-depot         # rejeu des migrations (128)
#   ./bootstrap.sh --depuis-une-sauvegarde   # restauration d'un dump
#   ./bootstrap.sh --depuis-le-depot --sans-verification
#
# À exécuter depuis deploy/, sur un hôte disposant de docker compose.
# Pour repartir vraiment de zéro : docker compose down -v  (⚠️ efface tout).
#
# CE QUE CE SCRIPT NE FAIT PAS, et qui reste à faire à la main :
#   * les fichiers physiques des buckets Storage (~430 Mo) — ils ne sont ni
#     dans le dump ni dans le dépôt : rsync depuis la sauvegarde `storage`.
#     (Les PLAFONDS des buckets, eux, sont posés — étape 7.) ;
#   * les secrets autres que le sel de pseudonymisation (clés d'API, secrets de
#     webhook) — ils vont dans deploy/functions.env ;
#   * le DNS et les certificats.
# =============================================================================

set -euo pipefail

MODE=""
VERIFIER=1
SERVICES_APPLICATIFS="rest auth storage functions caddy"

for arg in "$@"; do
  case "$arg" in
    --depuis-le-depot)       MODE="depot" ;;
    --depuis-une-sauvegarde) MODE="sauvegarde" ;;
    --sans-verification)     VERIFIER=0 ;;
    -h|--help)               sed -n '2,36p' "$0"; exit 0 ;;
    *) echo "✗ Option inconnue : $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "✗ Choisir un mode : --depuis-le-depot ou --depuis-une-sauvegarde" >&2
  exit 2
fi

cd "$(dirname "$0")"
[ -f .env ] || { echo "✗ deploy/.env absent. Le copier depuis .env.example et le remplir." >&2; exit 1; }

etape() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
sql()   { docker compose exec -T db psql -U supabase_admin -d postgres -tAc "$1"; }

# -----------------------------------------------------------------------------
# 1. La base seule, et rien d'autre
# -----------------------------------------------------------------------------
etape "1/7 · Démarrage de la base"
docker compose up -d --wait db
echo "✓ Base prête (le healthcheck vérifie que le rôle authenticator existe)."

# -----------------------------------------------------------------------------
# 2. Mots de passe des rôles de service
# -----------------------------------------------------------------------------
# Sur un volume vierge, le script s'exécute seul via /docker-entrypoint-initdb.d.
# Sur un volume déjà initialisé, il faut le rejouer — il est idempotent.
etape "2/7 · Mots de passe des rôles de service"
docker compose exec -T db sh /docker-entrypoint-initdb.d/99-roles.sh

# -----------------------------------------------------------------------------
# 3. Le sel de pseudonymisation, AVANT les migrations
# -----------------------------------------------------------------------------
# Une migration exige `pseudonym_salt`. Sans lui, le rejeu s'arrête au milieu —
# et surtout, restaurer plus tard avec un sel DIFFÉRENT ne produit aucune erreur
# visible : ça rend incohérents tous les jetons produits auparavant. Corruption
# silencieuse de données personnelles. On vérifie donc avant, pas pendant.
etape "3/7 · Vérification du sel de pseudonymisation"
if sql "select 1 from pg_namespace where nspname = 'vault'" | grep -q 1; then
  if [ "$(sql "select count(*) from vault.decrypted_secrets where name = 'pseudonym_salt'")" = "1" ]; then
    echo "✓ pseudonym_salt présent au Vault."
  else
    cat >&2 <<'AIDE'
✗ pseudonym_salt ABSENT du Vault.

  Les 21 secrets sont dans le flux BG2 « long », exportés en appels
  vault.create_secret rejouables. Les récupérer puis les injecter :

    restic dump <snapshot> <chemin>/vault.sql > /tmp/vault.sql
    docker compose exec -T db psql -U supabase_admin -d postgres < /tmp/vault.sql

  Puis relancer ce script. Ne PAS continuer sans : un sel différent ne
  provoque aucune erreur, seulement une corruption qui ne se signale pas.
AIDE
    exit 1
  fi
else
  echo "⚠ Schéma vault absent à ce stade — la migration qui exige le sel"
  echo "  échouera bruyamment. C'est le comportement voulu : elle s'arrête,"
  echo "  elle ne devine pas."
fi

# -----------------------------------------------------------------------------
# 4. Le schéma et les données
# -----------------------------------------------------------------------------
if [ "$MODE" = "depot" ]; then
  etape "4/7 · Rejeu des migrations depuis le dépôt"
  docker compose exec -T db sh /scripts/run-migrations.sh
else
  etape "4/7 · Restauration d'une sauvegarde"
  docker compose exec -T db sh /scripts/restore.sh
fi

# -----------------------------------------------------------------------------
# 5. Les vues matérialisées
# -----------------------------------------------------------------------------
etape "5/7 · Rafraîchissement des vues matérialisées"
docker compose exec -T db sh /scripts/refresh-matviews.sh

# -----------------------------------------------------------------------------
# 6. Les autres services — APRÈS, jamais avant
# -----------------------------------------------------------------------------
etape "6/7 · Démarrage des services applicatifs"
# shellcheck disable=SC2086
docker compose up -d --wait $SERVICES_APPLICATIFS
echo "✓ Six conteneurs en service."

# -----------------------------------------------------------------------------
# 7. Plafonds des buckets — APRÈS l'initialisation du service Storage
# -----------------------------------------------------------------------------
# Le schéma `storage` n'est pas créé par les migrations : c'est le service
# Storage qui le construit à son démarrage. À l'étape 4, il n'existait donc pas
# encore, et la migration des plafonds s'est délibérément abstenue plutôt que
# d'échouer. C'est ici qu'elle prend effet — le fichier est idempotent, et
# porte lui-même sa vérification.
etape "7/7 · Plafonds des buckets"
PLAFONDS=$(docker compose exec -T db sh -c 'ls /migrations/*_plafonds_buckets_numerisation.sql 2>/dev/null | head -1' | tr -d '\r')
if [ -n "$PLAFONDS" ]; then
  docker compose exec -T db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -f "$PLAFONDS"
  echo "✓ Plafonds et types autorisés posés sur les buckets."
else
  echo "⚠ Migration des plafonds introuvable dans /migrations — buckets sans borne."
fi

# -----------------------------------------------------------------------------
# Vérification
# -----------------------------------------------------------------------------
if [ "$VERIFIER" = "0" ]; then
  echo; echo "Vérification sautée (--sans-verification)."
  exit 0
fi

etape "Vérification"
ECHEC=0

# a) Aucune table publique sans RLS.
SANS_RLS=$(sql "select count(*) from pg_class c
                  join pg_namespace n on n.oid = c.relnamespace
                 where n.nspname = 'public' and c.relkind = 'r'
                   and c.relrowsecurity = false")
if [ "$SANS_RLS" = "0" ]; then
  echo "✓ Aucune table publique sans RLS."
else
  echo "✗ $SANS_RLS table(s) publique(s) sans RLS — le cloisonnement n'est pas revenu."
  ECHEC=1
fi

# b) Tables avec RLS mais AUCUNE policy.
#
# Ce contrôle n'existait pas, et son absence était un angle mort : le contrôle
# (a) lit `relrowsecurity`, pas l'existence de policies. Une table restaurée
# avec la RLS active et zéro policy passait donc le contrôle en étant
# inaccessible à tout rôle sauf service_role.
#
# Le chiffre attendu n'est pas zéro : douze tables d'import et de transit sont
# légitimement fermées par défaut, plus author_name_aliases et library_themes,
# lues par des fonctions SECURITY DEFINER. Ce qui compte est que le nombre ne
# BOUGE pas. S'il augmente, une policy a été perdue en chemin.
SANS_POLICY_ATTENDU=14
SANS_POLICY=$(sql "select count(*) from pg_class c
                     join pg_namespace n on n.oid = c.relnamespace
                    where n.nspname in ('public','ingest') and c.relkind = 'r'
                      and c.relrowsecurity = true
                      and not exists (select 1 from pg_policy p where p.polrelid = c.oid)")
if [ "$SANS_POLICY" = "$SANS_POLICY_ATTENDU" ]; then
  echo "✓ $SANS_POLICY tables avec RLS et sans policy — conforme à l'attendu."
else
  echo "✗ $SANS_POLICY tables avec RLS et sans policy, attendu $SANS_POLICY_ATTENDU."
  echo "  Les lister avant de conclure — une policy perdue ne se voit pas autrement :"
  sql "select n.nspname || '.' || c.relname from pg_class c
         join pg_namespace n on n.oid = c.relnamespace
        where n.nspname in ('public','ingest') and c.relkind = 'r'
          and c.relrowsecurity = true
          and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
        order by 1" | sed 's/^/    /'
  ECHEC=1
fi

# c) Les compteurs.
echo "  Notices        : $(sql 'select count(*) from public.books')"
echo "  Bibliothèques  : $(sql 'select count(*) from public.libraries')"
echo "  Comptes        : $(sql 'select count(*) from auth.users')"

# d) Les vues matérialisées sont peuplées.
VIDES=$(sql "select count(*) from pg_matviews where not ispopulated")
if [ "$VIDES" = "0" ]; then
  echo "✓ Toutes les vues matérialisées sont peuplées."
else
  echo "✗ $VIDES vue(s) matérialisée(s) vide(s) — le catalogue s'affichera vide."
  ECHEC=1
fi

# e) Cohérence de version GoTrue.
#
# L'image épinglée construit elle-même le schéma d'authentification. Si elle est
# en RETARD sur la production, un dump auth de production ne se restaure pas
# proprement. Mesuré le 20/08 : production 77, image v2.189.0 → 69.
AUTH_MIG=$(sql "select count(*) from auth.schema_migrations" 2>/dev/null || echo "?")
echo "  Migrations GoTrue de cette instance : $AUTH_MIG  (production au 20/08 : 77)"
if [ "$AUTH_MIG" != "?" ] && [ "$AUTH_MIG" -lt 77 ] 2>/dev/null; then
  echo "  ⚠ Image GoTrue en retard sur la production. Monter GOTRUE_TAG dans"
  echo "    deploy/.env avant toute bascule : image ≥ production, jamais l'inverse."
fi

echo
if [ "$ECHEC" = "0" ]; then
  echo "✓ Pile reconstruite et vérifiée."
  echo "  Dernier contrôle, à l'œil : ouvrir le catalogue en navigation anonyme"
  echo "  et ouvrir une notice. C'est le seul qui teste la chaîne entière."
  exit 0
else
  echo "✗ Reconstruction terminée avec des contrôles en échec — voir ci-dessus."
  exit 1
fi
