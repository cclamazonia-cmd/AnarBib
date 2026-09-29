#!/bin/bash
# =============================================================================
# Réimporte un export AnarBib dans un PMB VIDE du banc, compare ce qu'il en fait
# à ce que le PMB contenait, puis rend la base telle qu'elle était (H27,
# critère 2 — 28/09/2026 ; revu le même soir).
#
#   bash tests/pmb/banc/essai-reimport-pmb.sh catalogue.iso [autorites.iso] [dossier-bilan]
#
# 1. sauvegarde la base PMB (mariadb-dump) — elle est RESTAURÉE en sortant,
#    même en cas d'échec (trap ; une restauration qui ne rend pas le compte de
#    notices d'avant sort en 3 et dit la commande à refaire) — et en dresse le
#    bilan (« origine ») ;
# 2. vide le jeu de test par le script de PMB (tables/empty_example_set.sql :
#    notices, exemplaires, auteurs, responsabilités, éditeurs, collections,
#    séries, bulletins, liens…). Localisations, sections, types de documents,
#    le thésaurus et la table Dewey RESTENT, comme dans le PMB d'une
#    bibliothèque : une vedette ou un indice de l'export y est rapproché de son
#    entrée par son libellé ; tout le reste est recréé ;
# 3. importe les autorités s'il y en a (importer-autorites-pmb.mjs), puis les
#    notices ET leurs exemplaires par l'onglet « Exemplaires UNIMARC »
#    (tests/pmb/README.md) : fonction « Catégories RAMEAU », « Générer les
#    liens entre notices ? » à Oui ; et, si des autorités ont été importées,
#    « Oui » à « Tenir compte des notices d'autorités » avec l'origine AnarBib —
#    sinon « Non », et les auteurs sont rapprochés par leur nom et leurs dates.
#    Réglages surchargeables par l'appelant (importer-pmb.mjs) : PMB_LIENS=0
#    (le défaut du formulaire de PMB), PMB_AUTORITES_NOTICES=0,
#    PMB_COMME_LE_NAVIGATEUR=1 (l'origine envoyée comme le formulaire l'envoie :
#    PMB 8.1.1.1 ne la reçoit pas) ;
# 4. dresse le même bilan (« réimport ») et écrit bilan-h27.json : la date, les
#    réglages, les deux bilans, ce que l'import des notices a créé et le compte
#    rendu de PMB. Ces fichiers, versés TELS QUELS dans tests/pmb/bilans/, sont
#    ceux que src/tests/couverture-pmb.test.js lit (docs/interop/couverture-pmb.md) :
#    l'aller-retour, ses deux contre-essais (sans le tri, sans les liens) et les
#    trois réglages d'autorités — la recette est dans tests/pmb/README.md.
# Le bilan ne compte que ce qui SERT (une collection du jeu de test que rien
# n'emploie n'est pas comptée), plus les catégories notice par notice et la
# répartition des exemplaires par type, section et code statistique.
# Identifiants de banc (locaux) : MariaDB bibli / bibli (tests/pmb/README.md).
# =============================================================================
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
CAT="${1:?usage : essai-reimport-pmb.sh catalogue.iso [autorites.iso] [dossier-bilan]}"
AUT="${2:-}"
OUT="${3:-$(dirname "$CAT")}"
DB="${PMB_DB_CONTENEUR:-pmb-banc-db-1}"
VIDE="${PMB_SCRIPT_VIDE:-$HOME/pmb-banc/src/pmb/tables/empty_example_set.sql}"
[ -f "$CAT" ] || { echo "catalogue introuvable : $CAT"; exit 2; }
[ -z "$AUT" ] || [ -f "$AUT" ] || { echo "fichier d'autorités introuvable : $AUT"; exit 2; }
[ -f "$VIDE" ] || { echo "script de vidage introuvable : $VIDE"; exit 2; }
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"   # absolu : le résumé le passe à node
Q() { docker exec "$DB" mariadb -ubibli -pbibli -N -B bibli -e "$1" 2>/dev/null; }
# répartition « libellé=n | libellé=n », la plus nombreuse d'abord
repartition() { Q "select group_concat(concat(l, '=', n) order by n desc, l separator ' | ') from (select $2 l, count(*) n from exemplaires e join $1 group by 1) x"; }

# Le bilan, en JSON, de l'état courant de la base.
bilan() {
  cat <<JSON
{
  "notices": $(Q "select count(*) from notices"),
  "notices_par_niveau": "$(Q "select group_concat(concat(niveau_biblio, niveau_hierar, '=', n) order by niveau_biblio separator ' ') from (select niveau_biblio, niveau_hierar, count(*) n from notices group by 1, 2) x")",
  "exemplaires": $(Q "select count(*) from exemplaires"),
  "exemplaires_sur_bulletins": $(Q "select count(*) from exemplaires where expl_bulletin <> 0"),
  "exemplaires_par_type": "$(repartition "docs_type t on t.idtyp_doc = e.expl_typdoc" "t.tdoc_libelle")",
  "exemplaires_par_section": "$(repartition "docs_section s on s.idsection = e.expl_section" "s.section_libelle")",
  "exemplaires_par_code_statistique": "$(repartition "docs_codestat c on c.idcode = e.expl_codestat" "c.codestat_libelle")",
  "notices_sans_exemplaire": $(Q "select count(*) from notices n where not exists (select 1 from exemplaires e where e.expl_notice = n.notice_id) and not exists (select 1 from bulletins b join exemplaires e on e.expl_bulletin = b.bulletin_id where b.num_notice = n.notice_id)"),
  "bulletins": $(Q "select count(*) from bulletins"),
  "depouillements": $(Q "select count(*) from analysis"),
  "responsabilites": $(Q "select count(*) from responsability"),
  "responsabilites_sans_fonction": $(Q "select count(*) from responsability where responsability_fonction = ''"),
  "auteurs_employes": $(Q "select count(distinct responsability_author) from responsability"),
  "liens_categories": $(Q "select count(*) from notices_categories"),
  "notices_avec_categorie": $(Q "select count(distinct notcateg_notice) from notices_categories"),
  "langues_par_type": "$(Q "select group_concat(concat(type_langue, '=', n) order by type_langue) from (select type_langue, count(*) n from notices_langues group by 1) x")",
  "editeurs_employes": $(Q "select count(distinct ed1_id) from notices where ed1_id <> 0"),
  "collections_employees": $(Q "select count(distinct coll_id) from notices where coll_id <> 0"),
  "notices_avec_collection": $(Q "select count(*) from notices where coll_id <> 0"),
  "series_employees": $(Q "select count(distinct tparent_id) from notices where tparent_id <> 0"),
  "notices_en_serie": $(Q "select count(*) from notices where tparent_id <> 0"),
  "liens_entre_notices": $(Q "select count(distinct least(num_notice, linked_notice), greatest(num_notice, linked_notice), relation_type) from notices_relations"),
  "liens_notice_source_d_autorite": $(Q "select count(*) from notices_authorities_sources"),
  "liens_notice_source_d_autorite_sans_source": $(Q "select count(*) from notices_authorities_sources l where not exists (select 1 from authorities_sources s where s.id_authority_source = l.num_authority_source)"),
  "responsabilites_rattachees_a_une_fiche_AnarBib": $(Q "select count(*) from responsability r where exists (select 1 from authorities_sources s join origin_authorities o on o.id_origin_authorities = s.num_origin_authority where s.num_authority = r.responsability_author and s.authority_type = 'author' and o.origin_authorities_name = 'AnarBib')"),
  "categories_par_notice": "$(Q "select group_concat(concat(replace(left(n.tit1, 40), '\"', ''), ':', c.k) order by n.tit1 separator ' | ') from (select notcateg_notice, count(*) k from notices_categories group by 1) c join notices n on n.notice_id = c.notcateg_notice")"
}
JSON
}

SAUVE="$OUT/avant-reimport.sql"
docker exec "$DB" mariadb-dump -ubibli -pbibli --single-transaction bibli > "$SAUVE" 2>/dev/null \
  || { echo "sauvegarde impossible"; exit 1; }
AVANT=$(Q "select count(*) from notices")
echo "sauvegarde : $SAUVE ($(wc -c < "$SAUVE") octets) — $AVANT notices avant l'essai"
RC=0
restaurer() {
  docker exec -i "$DB" mariadb -ubibli -pbibli bibli < "$SAUVE" 2> "$OUT/err-restauration.txt"
  local rc=$? apres
  apres=$(Q 'select count(*) from notices')
  echo "restauration : rc $rc — $apres notices (avant l'essai : $AVANT)"
  if [ "$rc" != 0 ] || [ "$apres" != "$AVANT" ]; then
    echo "RESTAURATION À REFAIRE À LA MAIN : docker exec -i $DB mariadb -ubibli -pbibli bibli < $SAUVE"; exit 3
  fi
  exit "$RC"
}
trap restaurer EXIT
bilan > "$OUT/bilan-origine.json"
# les bilans d'un essai précédent ne doivent pas servir de résumé à celui-ci
rm -f "$OUT/bilan-notices.json" "$OUT/bilan-autorites.json" "$OUT/bilan-reimport.json" "$OUT/bilan-h27.json"

# --force : le script de PMB supprime aussi des tables d'entrepôts qui n'existent
# pas dans toutes les bases (« Unknown table entrepot_source_2 », ERROR 1051) ;
# on continue, toute autre erreur arrête l'essai, et l'on vérifie le résultat.
docker exec -i "$DB" mariadb --force -ubibli -pbibli bibli < "$VIDE" > /dev/null 2> "$OUT/err-vidage.txt"
if grep -v 'ERROR 1051' "$OUT/err-vidage.txt" | grep -q 'ERROR'; then
  echo "vidage en erreur : $(grep -v 'ERROR 1051' "$OUT/err-vidage.txt" | grep 'ERROR' | head -1)"; RC=1; exit 1
fi
RESTE=""
for t in notices exemplaires authors publishers collections sub_collections series bulletins analysis responsability notices_categories notices_relations authorities_sources; do
  RESTE="$RESTE${RESTE:+/}$(Q "select count(*) from $t")"
done
echo "vidé : restants (notices/exemplaires/auteurs/éditeurs/collections/sous-collections/séries/bulletins/dépouillements/responsabilités/liens de catégorie/liens entre notices/sources d'autorité) = $RESTE"
[ "$RESTE" = "0/0/0/0/0/0/0/0/0/0/0/0/0" ] || { echo "vidage incomplet"; RC=1; exit 1; }

if [ -n "$AUT" ]; then
  node "$ICI/importer-autorites-pmb.mjs" "$AUT" "$OUT/bilan-autorites.json" > /dev/null 2> "$OUT/err-autorites.txt"; rc=$?
  echo "autorités : rc $rc ($(tail -1 "$OUT/err-autorites.txt" 2>/dev/null))"
  [ "$rc" = 0 ] || { echo "import des autorités en échec : l'essai s'arrête (un réimport sans elles serait un autre essai)"; RC=1; exit 1; }
  # l'origine « AnarBib » n'existe qu'une fois des autorités importées (801 $b) ;
  # PMB_AUTORITES_NOTICES=0 posé par l'appelant mesure « Non » après un import d'autorités
  export PMB_AUTORITES_NOTICES="${PMB_AUTORITES_NOTICES:-1}" PMB_ORIGINE="${PMB_ORIGINE:-AnarBib}"
fi
PMB_FONCTION_IMPORT=func_cpt_rameau_first_level.inc \
  node "$ICI/importer-pmb.mjs" "$CAT" "$OUT/bilan-notices.json" > /dev/null 2> "$OUT/err-notices.txt"; rc=$?
echo "notices : rc $rc ($(tail -1 "$OUT/err-notices.txt" 2>/dev/null))"
[ "$rc" = 0 ] && [ -s "$OUT/bilan-notices.json" ] || { echo "import des notices en échec"; RC=1; exit 1; }
bilan > "$OUT/bilan-reimport.json"

node - "$OUT" "$CAT" "$AUT" <<'JS'
const fs = require('fs'), path = require('path');
const [OUT, CAT, AUT] = process.argv.slice(2);
const lire = (f) => JSON.parse(fs.readFileSync(path.join(OUT, f), 'utf8'));
const o = lire('bilan-origine.json'), r = lire('bilan-reimport.json'), b = lire('bilan-notices.json');
for (const k of Object.keys(o)) if (k !== 'categories_par_notice') console.log(k.padEnd(48), String(o[k]).padEnd(40), r[k]);
const cat = (s) => new Map(String(s).split(' | ').filter(Boolean).map((x) => { const i = x.lastIndexOf(':'); return [x.slice(0, i), x.slice(i + 1)]; }));
const co = cat(o.categories_par_notice), cr = cat(r.categories_par_notice);
const ecarts = [...new Set([...co.keys(), ...cr.keys()])].filter((t) => co.get(t) !== cr.get(t)).map((t) => t + ' : ' + (co.get(t) ?? 0) + ' → ' + (cr.get(t) ?? 0));
console.log('catégories qui changent :', ecarts.length ? ecarts.join(' ; ') : 'aucune');
const pmb = { notices_a_charger: b.pmb.notices_a_charger, notices_invalides: b.pmb.notices_invalides, erreurs: b.pmb.erreurs || [] };
console.log('PMB :', JSON.stringify({ ...pmb, erreurs: pmb.erreurs.slice(0, 8) }));
const bilan = {
  mesure: new Date().toISOString().slice(0, 10),
  fichiers: { catalogue: path.basename(CAT), autorites: AUT ? path.basename(AUT) : null },
  reglages: { onglet: 'Administration > Imports > Exemplaires UNIMARC', fonction_import: b.fonction_import, ...(b.options || {}) },
  origine: o, reimport: r, cree_par_l_import_des_notices: (b.base && b.base.delta) || null, pmb,
};
fs.writeFileSync(path.join(OUT, 'bilan-h27.json'), JSON.stringify(bilan, null, 1) + '\n');
console.log(`bilan-h27.json écrit dans ${OUT} — à verser dans tests/pmb/bilans/ si cette mesure fait foi`);
JS
