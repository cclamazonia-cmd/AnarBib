#!/bin/sh
# =============================================================================
# AnarBib — rafraîchissement des vues matérialisées
# =============================================================================
# Usage :
#   docker compose exec db sh /scripts/refresh-matviews.sh
#
# POURQUOI CE SCRIPT EXISTE
# -------------------------
# Un dump PostgreSQL ne transporte PAS le contenu des vues matérialisées : il
# recrée leur définition, pas leurs données. Après restauration, elles existent
# mais sont vides, et toute requête dessus échoue :
#
#   ERROR 55000 : materialized view "mv_books_catalog_list_v1" has not been
#   populated. HINT: Use the REFRESH MATERIALIZED VIEW command.
#
# Conséquence observée le 18/08/2026 : base restaurée, 2677 notices bien
# présentes dans les tables, et catalogue VIDE à l'écran. Le symptôme ne
# ressemble pas du tout à sa cause.
#
# Ce script rafraîchit toutes les vues non peuplées, en plusieurs passes pour
# absorber les dépendances entre elles (une vue peut en alimenter une autre).
# =============================================================================

SU=""
for candidat in supabase_admin postgres; do
  if psql -U "$candidat" -d postgres -tAc "select 1" >/dev/null 2>&1; then
    SU="$candidat"; break
  fi
done
[ -z "$SU" ] && { echo "✗ Connexion à Postgres impossible."; exit 1; }

total=$(psql -U "$SU" -d postgres -tAc "select count(*) from pg_matviews")
echo "Vues matérialisées présentes : $total"

restant=$(psql -U "$SU" -d postgres -tAc "select count(*) from pg_matviews where not ispopulated")
echo "Non peuplées au départ       : $restant"

if [ "$restant" = "0" ]; then
  echo ""
  echo "· Rien à faire : toutes les vues sont déjà peuplées."
  exit 0
fi

echo "─────────────────────────────────────────────"

passe=0
while [ "$restant" != "0" ] && [ "$passe" -lt 5 ]; do
  passe=$((passe + 1))
  echo "Passe $passe…"

  psql -U "$SU" -d postgres -v ON_ERROR_STOP=0 <<'SQL' 2>&1 | grep -E "NOTICE|ERROR" | sed 's/^/    /'
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT schemaname, matviewname FROM pg_matviews WHERE NOT ispopulated LOOP
    BEGIN
      EXECUTE format('REFRESH MATERIALIZED VIEW %I.%I', r.schemaname, r.matviewname);
      RAISE NOTICE 'rafraichie : %.%', r.schemaname, r.matviewname;
    EXCEPTION WHEN others THEN
      RAISE NOTICE 'reportee   : %.% (%)', r.schemaname, r.matviewname, SQLERRM;
    END;
  END LOOP;
END
$$;
SQL

  avant="$restant"
  restant=$(psql -U "$SU" -d postgres -tAc "select count(*) from pg_matviews where not ispopulated")
  [ "$restant" = "$avant" ] && { echo "  (aucun progrès à cette passe — on s'arrête)"; break; }
done

echo "─────────────────────────────────────────────"
echo ""
if [ "$restant" = "0" ]; then
  echo "✓ Toutes les vues matérialisées sont peuplées."
else
  echo "⚠️  $restant vue(s) toujours non peuplée(s) :"
  psql -U "$SU" -d postgres -tAc \
    "select '    ' || schemaname || '.' || matviewname from pg_matviews where not ispopulated"
  echo ""
  echo "  Les rafraîchir une par une pour voir l'erreur réelle :"
  echo "    docker compose exec db psql -U $SU -d postgres -c 'REFRESH MATERIALIZED VIEW <schema>.<vue>;'"
  exit 1
fi
