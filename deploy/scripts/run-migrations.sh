#!/bin/sh
# =============================================================================
# AnarBib — rejeu ordonné des migrations sur la base locale
# =============================================================================
# Répond à LA question posée par un hébergeur : « peut-on reconstruire la base
# depuis le dépôt seul ? »
#
# Usage :
#   docker compose exec db sh /scripts/run-migrations.sh          # depuis le début
#   docker compose exec db sh /scripts/run-migrations.sh 69       # reprise à la 69e
#
# Comportement :
#   - applique les fichiers de /migrations dans l'ordre lexicographique strict
#     (c'est l'ordre que `supabase db push` respecte lui aussi) ;
#   - s'ARRÊTE à la première erreur et affiche les dernières lignes du message ;
#   - affiche une ligne par migration, pour qu'on voie où ça casse.
#
# ⚠️ Connexion en `supabase_admin` et non `postgres` : dans l'image
# supabase/postgres, `postgres` n'est PAS superutilisateur, et les migrations
# créent des extensions, des rôles et des objets qui l'exigent.
# (Constaté le 17/08/2026 — cf. compte rendu de la séance A.)
# =============================================================================

MIG_DIR="${MIG_DIR:-/migrations}"
DEPART="${1:-1}"          # numéro de la première migration à appliquer
SU=""

for candidat in supabase_admin postgres; do
  if psql -U "$candidat" -d postgres -tAc "select 1" >/dev/null 2>&1; then
    SU="$candidat"; break
  fi
done

if [ -z "$SU" ]; then
  echo "✗ Impossible de se connecter à Postgres."
  exit 1
fi

# Le modèle de migration (_TEMPLATE.sql) et tout fichier préfixé par « _ »
# sont exclus : ce sont des gabarits, pas des migrations.
LISTE=$(ls "$MIG_DIR"/*.sql 2>/dev/null | grep -v '/_' )
total=$(echo "$LISTE" | grep -c . )
if [ "$total" = "0" ]; then
  echo "✗ Aucune migration trouvée dans $MIG_DIR"
  exit 1
fi

# --- Garde-fou : ce script rejoue TOUT depuis la baseline ---------------------
# Il n'a aucune notion de « déjà appliqué ». Sur une base déjà peuplée il meurt
# donc à la première migration, avec un message qui nomme un type Postgres et
# pas le problème :
#
#     ERROR: type "membership_payment_method" already exists
#
# Vécu à la première exécution réelle de bootstrap.sh, le 20/08/2026. On perd
# du temps à chercher un défaut de migration là où il n'y a qu'un volume non
# vierge — et on le perd au pire moment, puisque ce script sert précisément à
# reconstruire après un sinistre.
#
# `--depart` reste la porte de sortie pour une reprise volontaire en cours de
# liste : dans ce cas on sait ce qu'on fait, et le garde-fou s'efface.
if [ "$DEPART" -le 1 ]; then
  deja=$(psql -U "$SU" -d postgres -tAc \
    "select count(*) from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r'" 2>/dev/null || echo 0)
  if [ "${deja:-0}" -gt 0 ]; then
    echo "✗ La base n'est PAS vierge : $deja table(s) dans public."
    echo ""
    echo "  Ce script rejoue les migrations DEPUIS LA BASELINE ; il ne sait pas"
    echo "  reprendre une base déjà construite, et échouerait à la première."
    echo ""
    echo "  Pour reconstruire vraiment de zéro (⚠️ EFFACE TOUT) :"
    echo "      docker compose down -v && ./bootstrap.sh --depuis-le-depot"
    echo ""
    echo "  Pour reprendre volontairement en cours de liste (argument positionnel) :"
    echo "      $0 <numero-de-la-premiere-migration>"
    exit 1
  fi
fi

echo "Connexion : $SU"
echo "Migrations présentes : $total"
[ "$DEPART" -gt 1 ] && echo "Reprise à partir de la n° $DEPART (les précédentes sont supposées déjà appliquées)"
echo "─────────────────────────────────────────────"

n=0
debut=$(date +%s)

for f in $LISTE; do
  n=$((n + 1))
  [ "$n" -lt "$DEPART" ] && continue
  nom=$(basename "$f")
  printf "%3d/%s  %-70s " "$n" "$total" "$nom"

  if psql -q -U "$SU" -d postgres -v ON_ERROR_STOP=1 -f "$f" >/dev/null 2>/tmp/mig_err; then
    echo "OK"
  else
    echo "ÉCHEC"
    echo ""
    echo "─────────────────────────────────────────────"
    echo "Migration en échec : $nom"
    echo ""
    tail -n 12 /tmp/mig_err
    echo "─────────────────────────────────────────────"
    echo ""
    echo "$((n - 1)) migration(s) appliquée(s) avant l'échec."
    echo "Pour rejouer celle-ci seule après correction :"
    echo "  docker compose exec db psql -U $SU -d postgres -f $f"
    exit 1
  fi
done

fin=$(date +%s)
echo "─────────────────────────────────────────────"
echo ""
echo "✓ Migrations $DEPART à $total appliquées, en $((fin - debut)) secondes."
echo ""
echo "Contrôle rapide :"
psql -U "$SU" -d postgres -tAc \
  "select 'tables publiques : ' || count(*) from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'"
psql -U "$SU" -d postgres -tAc \
  "select 'sans RLS        : ' || count(*) from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity"
psql -U "$SU" -d postgres -tAc \
  "select 'fonctions api.* : ' || count(*) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'api'"
echo ""
echo "« sans RLS » doit valoir 0."
