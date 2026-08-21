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
# À quoi s'ajoute, constaté le 21/08/2026 à la première reconstruction vraiment
# partie de zéro, un quatrième enchaînement — de sens INVERSE aux trois autres :
#
#   * `auth` n'est pas un consommateur du schéma, c'en est un PRODUCTEUR. Une
#     centaine de migrations appellent `auth.uid()` ou `auth.jwt()`, et ces
#     fonctions-là, aucune migration ne les crée : c'est GoTrue qui les pose au
#     démarrage. Démarré à l'étape des « autres services », il arrivait après
#     les migrations qui en dépendent, et le rejeu depuis le dépôt mourait sur
#     une base vierge — le seul cas où ce script sert vraiment.
#
# D'où : base seule → rôles → GoTrue → schéma+données → vues → et SEULEMENT
# ENSUITE les services qui LISENT le schéma.
#
# USAGE
#   ./bootstrap.sh --depuis-le-depot         # rejeu des migrations (158)
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
    -h|--help)               sed -n '2,46p' "$0"; exit 0 ;;
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
etape "1/8 · Démarrage de la base"
docker compose up -d --wait db
echo "✓ Base prête (le healthcheck vérifie que le rôle authenticator existe)."

# -----------------------------------------------------------------------------
# 2. Mots de passe des rôles de service
# -----------------------------------------------------------------------------
# Sur un volume vierge, le script s'exécute seul via /docker-entrypoint-initdb.d.
# Sur un volume déjà initialisé, il faut le rejouer — il est idempotent.
etape "2/8 · Mots de passe des rôles de service"
docker compose exec -T db sh /docker-entrypoint-initdb.d/99-roles.sh

# -----------------------------------------------------------------------------
# 3. Le sel de pseudonymisation, AVANT les migrations
# -----------------------------------------------------------------------------
# Une migration exige `pseudonym_salt`. Sans lui, le rejeu s'arrête au milieu —
# et surtout, restaurer plus tard avec un sel DIFFÉRENT ne produit aucune erreur
# visible : ça rend incohérents tous les jetons produits auparavant. Corruption
# silencieuse de données personnelles. On vérifie donc avant, pas pendant.
etape "3/8 · Vérification du sel de pseudonymisation"
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
# 4. Le schéma d'authentification — AVANT les migrations, jamais après
# -----------------------------------------------------------------------------
# Voir l'en-tête : `auth` produit le schéma dont les migrations ont besoin. Il
# doit donc tourner ici, seul, et on attend qu'il ait FINI — le conteneur est
# « up » bien avant d'avoir posé quoi que ce soit.
#
# Ce qu'on attend n'est pas un délai mais un fait : les quatre fonctions que les
# migrations appellent. C'est le seul témoin honnête ; compter les tables du
# schéma `auth` ne vaut rien, elles apparaissent au fil des migrations de GoTrue
# et le compte franchit n'importe quel seuil bien avant la fin.
#
# Et l'attente est bornée, avec le journal en cas d'échec : sans mot de passe
# valide, GoTrue ne plante pas — il redémarre en boucle toutes les 60 secondes
# en écrivant `password authentication failed` dans un journal que personne ne
# lit. On attendrait indéfiniment devant une erreur déjà écrite.
etape "4/8 · Schéma d'authentification (GoTrue)"
docker compose up -d auth

HELPERS="uid jwt role email"
LIMITE=180
attendu=0
debut_auth=$(date +%s)
while [ $(( $(date +%s) - debut_auth )) -lt "$LIMITE" ]; do
  presentes=$(sql "select count(distinct p.proname) from pg_proc p
                     join pg_namespace n on n.oid = p.pronamespace
                    where n.nspname = 'auth'
                      and p.proname in ('uid','jwt','role','email')" 2>/dev/null || echo 0)
  if [ "${presentes:-0}" = "4" ]; then attendu=1; break; fi
  sleep 3
done

if [ "$attendu" = "1" ]; then
  echo "✓ auth.uid(), auth.jwt(), auth.role(), auth.email() en place"        "(en $(( $(date +%s) - debut_auth )) s)."
else
  echo "✗ GoTrue n'a pas posé les quatre fonctions en ${LIMITE} s." >&2
  echo "  Fonctions présentes : ${presentes:-0}/4 sur $HELPERS" >&2
  echo "" >&2
  echo "  Dernières lignes du journal de GoTrue — la cause y est presque" >&2
  echo "  toujours écrite en clair :" >&2
  docker compose logs --tail=15 auth 2>&1 | sed 's/^/    /' >&2
  echo "" >&2
  echo "  Cause la plus fréquente : « password authentication failed for user" >&2
  echo "  supabase_auth_admin ». L'étape 2 n'a alors pas pris — la rejouer :" >&2
  echo "      docker compose exec -T db sh /docker-entrypoint-initdb.d/99-roles.sh" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 5. Le schéma et les données
# -----------------------------------------------------------------------------
if [ "$MODE" = "depot" ]; then
  etape "5/8 · Rejeu des migrations depuis le dépôt"
  docker compose exec -T db sh /scripts/run-migrations.sh
else
  etape "5/8 · Restauration d'une sauvegarde"
  docker compose exec -T db sh /scripts/restore.sh
fi

# -----------------------------------------------------------------------------
# 6. Les vues matérialisées
# -----------------------------------------------------------------------------
etape "6/8 · Rafraîchissement des vues matérialisées"
docker compose exec -T db sh /scripts/refresh-matviews.sh

# -----------------------------------------------------------------------------
# 7. Les autres services — APRÈS, jamais avant
# -----------------------------------------------------------------------------
etape "7/8 · Démarrage des services applicatifs"
# shellcheck disable=SC2086
docker compose up -d --wait $SERVICES_APPLICATIFS
echo "✓ Six conteneurs en service."

# -----------------------------------------------------------------------------
# 8. Plafonds des buckets — APRÈS l'initialisation du service Storage
# -----------------------------------------------------------------------------
# Le schéma `storage` n'est pas créé par les migrations : c'est le service
# Storage qui le construit à son démarrage. À l'étape 4, il n'existait donc pas
# encore, et la migration des plafonds s'est délibérément abstenue plutôt que
# d'échouer. C'est ici qu'elle prend effet — le fichier est idempotent, et
# porte lui-même sa vérification.
etape "8/8 · Plafonds des buckets"
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
# La liste attendue n'est pas vide et n'a pas à l'être : ces tables sont
# légitimement fermées — tables d'import et de transit, plus author_name_aliases
# et library_themes, lues par des fonctions SECURITY DEFINER. Ce qui compte
# n'est pas leur nombre, c'est que la liste ne BOUGE pas.
#
# ⚠️ C'est une LISTE et non un compte, et c'est délibéré. Le contrôle a d'abord
# été écrit « attendu : 14 ». Le 21/08/2026 il est passé au rouge à 15 — sans
# dire laquelle, ni si c'était une table neuve ou une policy perdue. Les deux
# hypothèses ont la même tête vue d'un compteur, et elles n'ont pas du tout la
# même gravité. (C'était altcha_consumed_challenges, créée la veille par la
# migration anti-rejeu ALTCHA.) Un contrôle qui signale sans nommer fait perdre
# exactement le temps qu'on n'a pas au moment où il se déclenche.
#
# Quand ce contrôle rougit : comparer d'abord avec la PRODUCTION, qui est la
# référence. Si la production a la même liste, c'est ici qu'il faut ajouter la
# ligne. Sinon, une policy a été perdue en chemin.
SANS_POLICY_ATTENDUES="ingest.import_profiles
ingest.partner_catalog_received_assets
public.altcha_consumed_challenges
public.author_name_aliases
public.catalog_partner_capabilities
public.catalog_partner_probe_runs
public.import_blmf_books_rows
public.import_blmf_exemplares_rows
public.import_terra_livre_zotero_staging
public.interlibrary_loan_events
public.library_theme_configs
public.library_themes
public.partner_source_holdings
public.partner_source_items
public.partner_source_records"

SANS_POLICY_VUES=$(sql "select n.nspname || '.' || c.relname from pg_class c
                          join pg_namespace n on n.oid = c.relnamespace
                         where n.nspname in ('public','ingest') and c.relkind = 'r'
                           and c.relrowsecurity = true
                           and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
                         order by 1" | tr -d '
')

EN_TROP=$(comm -13 <(echo "$SANS_POLICY_ATTENDUES" | sort) <(echo "$SANS_POLICY_VUES" | sort))
MANQUANTES=$(comm -23 <(echo "$SANS_POLICY_ATTENDUES" | sort) <(echo "$SANS_POLICY_VUES" | sort))

if [ -z "$EN_TROP" ] && [ -z "$MANQUANTES" ]; then
  echo "✓ Tables avec RLS et sans policy : conformes à la liste attendue"        "($(echo "$SANS_POLICY_ATTENDUES" | grep -c .))."
else
  if [ -n "$EN_TROP" ]; then
    echo "✗ Table(s) fermée(s) EN TROP — policy perdue, ou table neuve à inscrire :"
    echo "$EN_TROP" | sed 's/^/    + /'
  fi
  if [ -n "$MANQUANTES" ]; then
    echo "✗ Table(s) attendue(s) fermée(s) qui ne le sont plus — ou disparues :"
    echo "$MANQUANTES" | sed 's/^/    - /'
  fi
  echo "  Comparer avec la production avant de conclure."
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

# f) La chaîne HTTP répond — et le catalogue n'est pas vide sur une base pleine.
#
# Les contrôles (a) à (e) interrogent Postgres. Ils ne disent RIEN de la chaîne
# que les lectrices empruntent : Caddy → PostgREST → policies RLS. Or c'est
# exactement là que se produit le sinistre que ce script existe pour éviter —
# « PostgREST lit le schéma UNE FOIS, à son démarrage » : démarré avant la
# restauration, il sert un catalogue VIDE sur une base PLEINE, et pas un seul
# des contrôles SQL ne s'en aperçoit. Le script se terminait donc en renvoyant
# l'opérateur à un contrôle « à l'œil ». On le fait faire à la machine.
#
# DEUX CLÉS, ET C'EST VOULU. Les trois codes 200 sont demandés avec la clé
# ANONYME : ils prouvent que le chemin public — Caddy, puis chaque service —
# répond bien à une visiteuse. Mais l'assertion « le catalogue n'est pas vide »
# se fait avec la clé de SERVICE, qui passe outre la RLS. Sans quoi le contrôle
# se retournerait contre une instance dont les bibliothèques sont toutes
# privées : anon n'en verrait aucune, légitimement, et le script hurlerait à la
# panne. Ce qu'on teste ici n'est pas le droit de lire, c'est que PostgREST voit
# les données — le cache de schéma, et rien d'autre.
#
# L'assertion est de plus à SENS UNIQUE : si la base contient des bibliothèques,
# l'API doit en rendre au moins une. On ne compare pas les deux nombres.
BASE_HTTP=""
for essai in "https://localhost" "http://localhost"; do
  if curl -sk -o /dev/null --max-time 5 "$essai/auth/v1/health" 2>/dev/null; then
    BASE_HTTP="$essai"; break
  fi
done

if [ -z "$BASE_HTTP" ]; then
  echo "⚠ Chaîne HTTP injoignable depuis cet hôte (ni https:// ni http://localhost)."
  echo "  Ce n'est pas forcément une panne : Caddy peut n'écouter que sur le"
  echo "  domaine réel. À vérifier alors à la main, c'est le seul contrôle qui"
  echo "  teste la chaîne entière."
else
  ANON=$(grep -E '^ANON_KEY=' .env | cut -d= -f2- | tr -d '\r' | tr -d '"')
  SERVICE=$(grep -E '^SERVICE_ROLE_KEY=' .env | cut -d= -f2- | tr -d '\r' | tr -d '"')
  code_de() {
    curl -sk -o /dev/null --max-time 10 -w '%{http_code}' \
      -H "apikey: $ANON" -H "Authorization: Bearer $ANON" "$BASE_HTTP/$1"
  }
  HTTP_OK=1
  for point in "auth/v1/health" "storage/v1/bucket" "rest/v1/libraries?select=id&limit=1"; do
    c=$(code_de "$point")
    if [ "$c" = "200" ]; then
      echo "✓ $BASE_HTTP/${point%%\?*} → 200"
    else
      echo "✗ $BASE_HTTP/${point%%\?*} → $c"
      HTTP_OK=0; ECHEC=1
    fi
  done

  # Le contrôle qui compte vraiment.
  BIB_SQL=$(sql "select count(*) from public.libraries")
  if [ "$HTTP_OK" = "1" ] && [ "${BIB_SQL:-0}" -gt 0 ] 2>/dev/null; then
    RENDU=$(curl -sk --max-time 10 -H "apikey: $SERVICE" -H "Authorization: Bearer $SERVICE" \
              "$BASE_HTTP/rest/v1/libraries?select=id&limit=1" | grep -c '"id"' || true)
    if [ "${RENDU:-0}" -gt 0 ]; then
      echo "✓ L'API rend des bibliothèques sur une base qui en contient $BIB_SQL."
    else
      echo "✗ La base contient $BIB_SQL bibliothèque(s) et l'API n'en rend AUCUNE,"
      echo "  alors même qu'on interroge avec la clé de service (la RLS est donc"
      echo "  hors de cause)."
      echo "  C'est la panne que ce script existe pour éviter : PostgREST a lu le"
      echo "  schéma avant que les données soient là. Le redémarrer suffit :"
      echo "      docker compose restart rest"
      ECHEC=1
    fi
  elif [ "${BIB_SQL:-0}" = "0" ]; then
    echo "· Base sans bibliothèque : le contrôle « catalogue non vide » n'a pas d'objet."
  fi
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
