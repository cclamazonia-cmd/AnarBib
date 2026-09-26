// Engendre la migration de données depuis resultats.json + authors.json.
// Ne retient que les décisions « accepte » et « deja_lie », et, pour chacune, que les
// champs VIDES dans AnarBib (la migration re-vérifie en SQL : coalesce partout).
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ICI = dirname(fileURLToPath(import.meta.url));
const SORTIE = process.argv[2]; if (!SORTIE) throw new Error('usage: node engendrer-migration.mjs <fichier.sql>');
const resultats = JSON.parse(readFileSync(join(ICI, 'resultats.json'), 'utf8'));
const auteurs = new Map(JSON.parse(readFileSync(join(ICI, 'authors.json'), 'utf8')).map((a) => [a.id, a]));

// Référentiel des langues des notices (src/lib/languages.js) : le portugais y est pt-BR.
const LANGUES = new Set(['ar', 'bg', 'ca', 'cs', 'da', 'de', 'el', 'en', 'eo', 'es', 'eu', 'fa', 'fi', 'fr', 'gl', 'he', 'hi', 'hr',
  'hu', 'id', 'it', 'ja', 'ko', 'nb', 'nl', 'oc', 'pl', 'pt-BR', 'ro', 'ru', 'sk', 'sr', 'sv', 'tr', 'uk', 'zh']);
const VERS_REFERENTIEL = { pt: 'pt-BR', no: 'nb', iw: 'he' };
const langue = (c) => { if (!c) return null; const x = VERS_REFERENTIEL[c] || c; return LANGUES.has(x) ? x : null; };
const q = (s) => (s === null || s === undefined ? 'NULL' : `'${String(s).replace(/'/g, "''")}'`);

const lignes = []; const horsReferentiel = []; const stats = { naissance: 0, mort: 0, pays: 0, langue: 0, wikidata: 0, viaf: 0, isni: 0, type: 0 };
// Écartées à la relecture du 26/09, versées « à relire ».
const EXCLUS = new Map([[10971, 'Flor O\'Squarr : mort en 1890 selon Wikidata, signe Les coulisses de l\'anarchie en 1892 (père et fils confondus ?)']]);
for (const r of resultats) {
  if (EXCLUS.has(r.id)) continue;
  if (!['accepte', 'deja_lie'].includes(r.decision) || !r.wd) continue;
  const a = auteurs.get(r.id); if (!a) continue;
  const w = r.wd;
  const naissance = a.birth_year == null && w.naissance ? w.naissance : null;
  let mort = a.death_year == null && w.mort ? w.mort : null;
  const refNaiss = a.birth_year ?? naissance;
  if (mort && refNaiss && mort < refNaiss) mort = null;
  const pays = !a.country && w.pays ? w.pays : null;
  const lg = langue(w.langue);
  if (w.langue && !lg) horsReferentiel.push(`${a.preferred_name} : ${w.langue}`);
  const wikidata = !a.wikidata_id ? r.qid : null;
  const viaf = !a.viaf_id && w.viaf ? w.viaf : null;
  const isni = !a.isni && w.isni && /^\d{15}[\dX]$/.test(w.isni) ? w.isni : null;
  const type = a.authority_type == null;
  if (!naissance && !mort && !pays && !lg && !wikidata && !viaf && !isni && !type) continue;
  stats.naissance += !!naissance; stats.mort += !!mort; stats.pays += !!pays; stats.langue += !!lg;
  stats.wikidata += !!wikidata; stats.viaf += !!viaf; stats.isni += !!isni; stats.type += type;
  lignes.push(`  (${a.id}, ${q(a.preferred_name)}, ${q(r.qid)}, ${naissance ?? 'NULL'}, ${mort ?? 'NULL'}, ${q(pays)}, ${q(lg)}, ${q(viaf)}, ${q(isni)})`);
}
const valeurs = lignes.join(',\n');
writeFileSync(SORTIE + '.values', valeurs + '\n');
writeFileSync(join(ICI, 'hors-referentiel.txt'), horsReferentiel.join('\n') + '\n');
console.log(JSON.stringify({ fiches: lignes.length, ...stats, horsReferentiel: horsReferentiel.length }));
