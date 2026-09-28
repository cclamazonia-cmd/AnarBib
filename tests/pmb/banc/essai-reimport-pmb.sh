#!/bin/bash
# =============================================================================
# Réimporte un export AnarBib dans un PMB VIDE du banc, compare ce qu'il en fait
# à ce que le PMB contenait, puis rend la base telle qu'elle était (H27,
# critère 2 — 28/09/2026).
#
#   bash tests/pmb/banc/essai-reimport-pmb.sh catalogue.iso [autorites.iso] [dossier-bilan]
#
# 1. sauvegarde la base PMB (mariadb-dump) — elle est RESTAURÉE en sortant,
#    même en cas d'échec (trap) — et en dresse le bilan (« origine ») ;
# 2. vide le jeu de test par le script de PMB (tables/empty_example_set.sql :
#    notices, exemplaires, auteurs, responsabilités, éditeurs, collections… ;
#    localisations, sections, types de documents et thésaurus restent) —
#    un PMB « neuf », où rien ne se dédoublonne avec l'existant ;
# 3. importe les autorités s'il y en a (importer-autorites-pmb.mjs), puis les
#    notices dans les réglages recommandés (tests/pmb/README.md) : fonction
#    « Catégories RAMEAU » ; et, si des autorités ont été importées, « Oui » à
#    « Tenir compte des notices d'autorités » avec l'origine AnarBib ;
# 4. dresse le même bilan (« réimport ») et écrit bilan-reimport.json.
# Le bilan ne compte que ce qui SERT (une collection du jeu de test que rien
# n'emploie n'est pas comptée), plus les catégories notice par notice.
# Identifiants de banc (locaux) : MariaDB bibli / bibli (tests/pmb/README.md).
# =============================================================================
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
CAT="${1:?usage : essai-reimport-pmb.sh catalogue.iso [autorites.iso] [dossier-bilan]}"
AUT="${2:-}"
OUT="${3:-$(dirname "$CAT")}"
DB="${PMB_DB_CONTENEUR:-pmb-banc-db-1}"
VIDE="${PMB_SCRIPT_VIDE:-$HOME/pmb-banc/src/pmb/tables/empty_example_set.sql}"
mkdir -p "$OUT"
Q() { docker exec "$DB" mariadb -ubibli -pbibli -N -B bibli -e "$1" 2>/dev/null; }

# Le bilan, en JSON, de l'état courant de la base.
bilan() {
  cat <<JSON
{
  "notices": $(Q "select count(*) from notices"),
  "notices_par_niveau": "$(Q "select group_concat(concat(niveau_biblio, niveau_hierar, '=', n) order by niveau_biblio separator ' ') from (select niveau_biblio, niveau_hierar, count(*) n from notices group by 1, 2) x")",
  "exemplaires": $(Q "select count(*) from exemplaires"),
  "exemplaires_sur_bulletins": $(Q "select count(*) from exemplaires where expl_bulletin <> 0"),
  "notices_sans_exemplaire": $(Q "select count(*) from notices n where not exists (select 1 from exemplaires e where e.expl_notice = n.notice_id) and not exists (select 1 from bulletins b join exemplaires e on e.expl_bulletin = b.bulletin_id where b.num_notice = n.notice_id)"),
  "bulletins": $(Q "select count(*) from bulletins"),
  "depouillements": $(Q "select count(*) from analysis"),
  "responsabilites": $(Q "select count(*) from responsability"),
  "auteurs_employes": $(Q "select count(distinct responsability_author) from responsability"),
  "liens_categories": $(Q "select count(*) from notices_categories"),
  "notices_avec_categorie": $(Q "select count(distinct notcateg_notice) from notices_categories"),
  "langues_par_type": "$(Q "select group_concat(concat(type_langue, '=', n) order by type_langue) from (select type_langue, count(*) n from notices_langues group by 1) x")",
  "editeurs_employes": $(Q "select count(distinct ed1_id) from notices where ed1_id <> 0"),
  "collections_employees": $(Q "select count(distinct coll_id) from notices where coll_id <> 0"),
  "notices_avec_collection": $(Q "select count(*) from notices where coll_id <> 0"),
  "responsabilites_rattachees_a_une_fiche_AnarBib": $(Q "select count(*) from responsability r where exists (select 1 from authorities_sources s join origin_authorities o on o.id_origin_authorities = s.num_origin_authority where s.num_authority = r.responsability_author and s.authority_type = 'author' and o.origin_authorities_name = 'AnarBib')"),
  "categories_par_notice": "$(Q "select group_concat(concat(replace(left(n.tit1, 40), '\"', ''), ':', c.k) order by n.tit1 separator ' | ') from (select notcateg_notice, count(*) k from notices_categories group by 1) c join notices n on n.notice_id = c.notcateg_notice")"
}
JSON
}

[ -f "$CAT" ] || { echo "catalogue introuvable : $CAT"; exit 2; }
[ -f "$VIDE" ] || { echo "script de vidage introuvable : $VIDE"; exit 2; }
SAUVE="$OUT/avant-reimport.sql"
docker exec "$DB" mariadb-dump -ubibli -pbibli --single-transaction bibli > "$SAUVE" 2>/dev/null \
  || { echo "sauvegarde impossible"; exit 1; }
AVANT=$(Q "select count(*) from notices")
echo "sauvegarde : $SAUVE ($(wc -c < "$SAUVE") octets) — $AVANT notices avant l'essai"
restaurer() {
  docker exec -i "$DB" mariadb -ubibli -pbibli bibli < "$SAUVE" 2>/dev/null
  echo "restauration : rc $? — $(Q 'select count(*) from notices') notices (avant l'essai : $AVANT)"
}
trap restaurer EXIT
bilan > "$OUT/bilan-origine.json"

# --force : le script de PMB supprime aussi des tables d'entrepôts qui n'existent
# pas dans toutes les bases (« Unknown table entrepot_source_2 ») ; on continue,
# et on vérifie le résultat.
docker exec -i "$DB" mariadb --force -ubibli -pbibli bibli < "$VIDE" > /dev/null 2>&1
RESTE="$(Q 'select count(*) from notices')/$(Q 'select count(*) from exemplaires')"
echo "vidé : notices/exemplaires restants = $RESTE"
[ "$RESTE" = "0/0" ] || { echo "vidage incomplet"; exit 1; }

if [ -n "$AUT" ] && [ -f "$AUT" ]; then
  node "$ICI/importer-autorites-pmb.mjs" "$AUT" "$OUT/bilan-autorites.json" > /dev/null 2> "$OUT/err-autorites.txt"
  echo "autorités : rc $? ($(tail -1 "$OUT/err-autorites.txt" 2>/dev/null))"
  # l'origine « AnarBib » n'existe qu'une fois des autorités importées (801 $b)
  export PMB_AUTORITES_NOTICES=1 PMB_ORIGINE=AnarBib
fi
PMB_FONCTION_IMPORT=func_cpt_rameau_first_level.inc \
  node "$ICI/importer-pmb.mjs" "$CAT" "$OUT/bilan-notices.json" > /dev/null 2> "$OUT/err-notices.txt"
echo "notices : rc $? ($(tail -1 "$OUT/err-notices.txt" 2>/dev/null))"
bilan > "$OUT/bilan-reimport.json"

node -e "
const o = require('$OUT/bilan-origine.json'), r = require('$OUT/bilan-reimport.json');
for (const k of Object.keys(o)) if (k !== 'categories_par_notice') console.log(k.padEnd(48), String(o[k]).padEnd(24), r[k]);
const cat = (s) => new Map(String(s).split(' | ').filter(Boolean).map((x) => { const i = x.lastIndexOf(':'); return [x.slice(0, i), x.slice(i + 1)]; }));
const co = cat(o.categories_par_notice), cr = cat(r.categories_par_notice);
const ecarts = [...new Set([...co.keys(), ...cr.keys()])].filter((t) => co.get(t) !== cr.get(t)).map((t) => t + ' : ' + (co.get(t) ?? 0) + ' → ' + (cr.get(t) ?? 0));
console.log('catégories qui changent :', ecarts.length ? ecarts.join(' ; ') : 'aucune');
const b = require('$OUT/bilan-notices.json');
console.log('PMB :', JSON.stringify({ a_charger: b.pmb.notices_a_charger, invalides: b.pmb.notices_invalides, erreurs: (b.pmb.erreurs || []).slice(0, 8) }));
"
