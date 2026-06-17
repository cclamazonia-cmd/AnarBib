// scripts/enrich-variant-forms-wikidata.cjs
// Enrichit authors.variant_forms depuis l'API Wikidata (labels + alias) pour les
// auteur·rices déjà identifié·es par un wikidata_id mais sans variant_forms.
// Haute confiance : le QID confirme l'identité (pas de désambiguïsation à faire).
// Écrit une migration prête à relire. NE TOUCHE PAS la prod.
//
// Session : Catalogue longue traîne (recherche + fiche auteur)

const fs = require('fs');
const path = require('path');

// Cible : auteur·rices avec wikidata_id et variant_forms vide (requête prod du 16/06).
const AUTHORS = [
  { id: 11,    qid: 'Q205381',   name: 'Abraham GUILLÉN' },
  { id: 10022, qid: 'Q4689387',  name: 'Afonso SCHMIDT' },
  { id: 10023, qid: 'Q7243',     name: 'Lev TOLSTÓI' },
  { id: 10041, qid: 'Q274891',   name: 'Émile ARMAND' },
  { id: 10443, qid: 'Q3013875',  name: 'Daniel COLSON' },
  { id: 10495, qid: 'Q16170957', name: "Alèssi DELL'UMBRIA" },
  { id: 10973, qid: 'Q191530',   name: 'Abdullah ÖCALAN' },
  { id: 11001, qid: 'Q347930',   name: 'Anton PANNEKOEK' },
  { id: 11058, qid: 'Q9623207',  name: 'Antônio de Almeida PRADO' },
];

// Langues conservées : 10 locales de l'app + majeures à graphie/écriture distincte
// (cohérent avec la convention des variant_forms déjà en base : Kropotkin, Goldman…).
const KEEP = ['ar','ca','de','el','en','eo','es','fa','fr','he','it','ja','ko','ku','nl','pl','pt','ru','tr','uk','zh'];
const UA = 'AnarBib-enrichment/1.0 (https://app.anarbib.org; authority record enrichment)';

const sqlEscape = (s) => String(s).replace(/'/g, "''");
const norm = (v) => String(v || '').normalize('NFKD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();

async function fetchEntity(qid) {
  const url = `https://www.wikidata.org/w/api.php?action=wbgetentities&ids=${qid}&props=labels|aliases&format=json`;
  const res = await fetch(url, { headers: { 'User-Agent': UA, 'Accept': 'application/json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const json = await res.json();
  const ent = json.entities && json.entities[qid];
  if (!ent || ent.missing !== undefined) throw new Error('entity missing');
  return ent;
}

function buildVariantForms(ent) {
  const vf = {};
  for (const lang of KEEP) {
    const names = []; const seen = new Set();
    const push = (v) => { const k = norm(v); if (!k || seen.has(k)) return; seen.add(k); names.push(v); };
    if (ent.labels && ent.labels[lang]) push(ent.labels[lang].value);
    if (ent.aliases && ent.aliases[lang]) for (const a of ent.aliases[lang]) push(a.value);
    if (names.length) vf[lang] = names;
  }
  return vf;
}

(async () => {
  const lines = [];
  const summary = [];
  for (const a of AUTHORS) {
    try {
      const ent = await fetchEntity(a.qid);
      const vf = buildVariantForms(ent);
      const nLangs = Object.keys(vf).length;
      const nNames = Object.values(vf).reduce((s, arr) => s + arr.length, 0);
      summary.push(`${a.id}\t${a.name} (${a.qid}): ${nLangs} langues, ${nNames} formes | fr=${(vf.fr||[]).slice(0,2).join(' / ')||'—'} | en=${(vf.en||[]).slice(0,2).join(' / ')||'—'}`);
      if (nLangs === 0) { lines.push(`-- ${a.id} ${a.name} (${a.qid}) : aucune forme — ignoré`); continue; }
      lines.push(`update authors set variant_forms = '${sqlEscape(JSON.stringify(vf))}'::jsonb`);
      lines.push(`  where id = ${a.id} and (variant_forms is null or variant_forms in ('null'::jsonb,'[]'::jsonb,'{}'::jsonb)); -- ${a.name} (${a.qid})`);
    } catch (e) {
      summary.push(`${a.id}\t${a.name} (${a.qid}): ERREUR ${e.message}`);
      lines.push(`-- ${a.id} ${a.name} (${a.qid}) : ERREUR ${e.message} — à reprendre`);
    }
    await new Promise(r => setTimeout(r, 400));
  }

  const header = `-- 20260616212100_opac_author_variant_forms_wikidata.sql
-- OPAC / fiche auteur — peuple authors.variant_forms (formes du nom) pour 9
-- auteur·rices identifié·es par wikidata_id mais sans variant_forms.
-- Source : API Wikidata (labels + alias), langues retenues : ${KEEP.join(', ')}.
-- Généré par scripts/enrich-variant-forms-wikidata.cjs (le ${new Date().toISOString().slice(0,10)}).
-- Garde-fou : n'écrit QUE si variant_forms est encore vide (idempotent, ne
-- réécrit pas un enrichissement manuel ultérieur).
--
-- Session : Catalogue longue traîne (recherche + fiche auteur)

`;
  const file = path.join(__dirname, '..', 'supabase', 'migrations', '20260616212100_opac_author_variant_forms_wikidata.sql');
  fs.writeFileSync(file, header + lines.join('\n') + '\n', 'utf8');
  console.log(summary.join('\n'));
  console.log('\nMigration écrite : ' + file);
})();
