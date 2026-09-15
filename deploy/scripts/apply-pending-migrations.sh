#!/bin/sh
# =============================================================================
# AnarBib — application incrémentale des migrations en attente
# =============================================================================
# Contrairement à `run-migrations.sh` (qui rejoue tout depuis la baseline sur
# base vierge), ce script est destiné aux MISES À JOUR d'une instance existante.
#
# Comportement :
#   - Crée la table de suivi `supabase_migrations.schema_migrations` si absente
#     (structure identique à celle utilisée par Supabase CLI / db push) ;
#   - Compare les fichiers de /migrations à ceux déjà appliqués ;
#   - N'applique QUE les nouvelles migrations, dans l'ordre lexicographique ;
#   - S'arrête à la première erreur ;
#   - Envoie un signal de rechargement de schéma à PostgREST (`NOTIFY pgrst`).
#
# Usage :
#   docker compose exec db sh /scripts/apply-pending-migrations.sh
# =============================================================================

set -e

MIG_DIR="${MIG_DIR:-/migrations}"
SU=""

# Les migrations s'appliquent sous `postgres`, comme en production et en CI
# (DOC-GRANT-3, A.2) : c'est ce rôle que le socle et 20260831105114 règlent.
# supabase_admin reste un repli, et il se dit.
for candidat in postgres supabase_admin; do
  if psql -U "$candidat" -d postgres -tAc "select 1" >/dev/null 2>&1; then
    SU="$candidat"; break
  fi
done

if [ -z "$SU" ]; then
  echo "✗ Impossible de se connecter à Postgres."
  exit 1
fi

if [ "$SU" != "postgres" ]; then
  echo "· postgres refusé — repli sur $SU : les objets seront possédés par $SU, pas comme en production."
fi

# Initialisation de la table de suivi si nécessaire
# Le GRANT garantit que les deux rôles peuvent utiliser le schéma même si
# c'est l'autre qui l'a créé lors d'un run précédent.
psql -q -U "$SU" -d postgres -c "
CREATE SCHEMA IF NOT EXISTS supabase_migrations;
GRANT ALL ON SCHEMA supabase_migrations TO postgres, supabase_admin;
CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations (
  version text PRIMARY KEY,
  statements text[],
  name text
);
GRANT ALL ON ALL TABLES IN SCHEMA supabase_migrations TO postgres, supabase_admin;
" >/dev/null

LISTE=$(ls "$MIG_DIR"/*.sql 2>/dev/null | grep -v '/_' | sort)
total=$(echo "$LISTE" | grep -c . || echo 0)

if [ "$total" = "0" ]; then
  echo "· Aucune migration trouvée dans $MIG_DIR"
  exit 0
fi

# Récupération des versions déjà appliquées
DEJA_APPLIQUEES=$(psql -U "$SU" -d postgres -tAc "SELECT version FROM supabase_migrations.schema_migrations;" 2>/dev/null || echo "")

appliquees=0
sautees=0

echo "Connexion : $SU"
echo "─────────────────────────────────────────────"

for f in $LISTE; do
  nom=$(basename "$f")
  version=$(echo "$nom" | cut -d_ -f1)
  nom_sans_version=$(echo "$nom" | cut -d_ -f2- | sed 's/\.sql$//')

  # Vérification si déjà appliquée
  if echo "$DEJA_APPLIQUEES" | grep -qx "$version"; then
    sautees=$((sautees + 1))
    continue
  fi

  printf "→ Application de %-60s " "$nom"

  if psql -q -U "$SU" -d postgres -v ON_ERROR_STOP=1 -f "$f" >/dev/null 2>/tmp/mig_err; then
    psql -q -U "$SU" -d postgres -c "
      INSERT INTO supabase_migrations.schema_migrations (version, name)
      VALUES ('$version', '$nom_sans_version')
      ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name;
    " >/dev/null
    echo "OK"
    appliquees=$((appliquees + 1))
  else
    echo "ÉCHEC"
    echo ""
    echo "─────────────────────────────────────────────"
    echo "Migration en échec : $nom"
    echo ""
    tail -n 15 /tmp/mig_err
    echo "─────────────────────────────────────────────"
    exit 1
  fi
done

echo "─────────────────────────────────────────────"
if [ "$appliquees" -eq 0 ]; then
  echo "✓ Schéma à jour ($sautees migration(s) déjà en place, aucune en attente)."
else
  echo "✓ $appliquees nouvelle(s) migration(s) appliquée(s) ($sautees déjà en place)."
  # Notification de rechargement à PostgREST
  psql -q -U "$SU" -d postgres -c "NOTIFY pgrst, 'reload schema';" >/dev/null 2>&1 || true
  echo "✓ Signal de rechargement envoyé à PostgREST."
fi
