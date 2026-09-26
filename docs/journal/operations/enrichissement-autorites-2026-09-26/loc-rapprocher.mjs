// Seconde phase — rapprochement avec le fichier d'autorités de la Library of Congress (id.loc.gov).
// LECTURE SEULE. Ne comble que ce qui reste vide APRÈS la phase 1 (valeurs de donnees.sql.values).
// Corroboration obligatoire : un titre de l'auteur au catalogue AnarBib cité dans les sources
// de la notice LC (champ 670), ou des dates concordantes avec la fiche. Le nom seul ne suffit jamais.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const ICI = dirname(fileURLToPath(import.meta.url));
const require = createRequire('C:/Users/accat/Codeberg/anarbib/package.json');
const pays = require('i18n-iso-countries');
pays.registerLocale(require('i18n-iso-countries/langs/en.json'));
const CACHE = join(ICI, 'cache-loc'); mkdirSync(CACHE, { recursive: true });
const UA = 'AnarBib-enrichissement-autorites/1.0 (https://anarbib.org; anarbib@proton.me)';
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));

async function loc(q) {
  const url = `https://id.loc.gov/authorities/names/suggest2?q=${encodeURIComponent(q)}&searchtype=keyword&count=10`;
  const f = join(CACHE, createHash('sha1').update(url).digest('hex') + '.json');
  if (existsSync(f)) return JSON.parse(readFileSync(f, 'utf8'));
  for (let e = 0; e < 10; e++) {
    await dormir(250);
    try { const r = await fetch(url, { headers: { 'User-Agent': UA } });
      if (r.ok) { const j = await r.json(); writeFileSync(f, JSON.stringify(j)); return j; }
      await dormir(2000 * (e + 1));
    } catch { await dormir(2000 * (e + 1)); }
  }
  throw new Error('id.loc.gov injoignable : ' + q);
}

const norm = (s) => String(s || '').normalize('NFD').replace(/\p{M}/gu, '').toLowerCase()
  .replace(/[^\p{L}\p{N}]+/gu, ' ').trim().replace(/\s+/g, ' ');
// Vedette LC → nom seul : sans dates, sans précisions entre parenthèses, sans titre ajouté après les dates.
const vedette = (s) => norm(String(s || '').replace(/\([^)]*\)/g, ' ').replace(/,\s*(\d{3,4}|active|approximately|b\.|d\.|fl\.).*$/i, ''));
const MOTS_VIDES = new Set(['a', 'o', 'as', 'os', 'e', 'de', 'da', 'do', 'das', 'dos', 'la', 'le', 'les', 'el', 'los', 'las', 'the', 'of', 'and', 'et', 'y', 'du', 'des', 'en', 'em', 'no', 'na', 'un', 'une', 'uma', 'um', 'il', 'lo', 'di', 'del', 'della', 'per', 'por', 'para', 'sobre', 'sur', 'to', 'in']);
const signature = (titre) => norm(titre).split(' ').filter((w) => w.length > 1 && !MOTS_VIDES.has(w)).slice(0, 4).join(' ');

const LANGUES = { Portuguese: 'pt-BR', Spanish: 'es', French: 'fr', English: 'en', Italian: 'it', German: 'de', Catalan: 'ca',
  Esperanto: 'eo', Dutch: 'nl', Greek: 'el', 'Greek, Modern (1453- )': 'el', Russian: 'ru', Polish: 'pl', Ukrainian: 'uk', Czech: 'cs', Hungarian: 'hu',
  Romanian: 'ro', Swedish: 'sv', Danish: 'da', Finnish: 'fi', Basque: 'eu', Galician: 'gl', Occitan: 'oc', Hebrew: 'he', Arabic: 'ar',
  Turkish: 'tr', Japanese: 'ja', Chinese: 'zh', Korean: 'ko', Persian: 'fa', Bulgarian: 'bg', Croatian: 'hr', Serbian: 'sr', Slovak: 'sk',
  Norwegian: 'nb', 'Norwegian (Bokmål)': 'nb', Hindi: 'hi', Indonesian: 'id' };
const ALIAS_PAYS = { 'Russia': 'RU', 'Russia (Federation)': 'RU', 'Soviet Union': null, 'Great Britain': 'GB', 'England': 'GB', 'Scotland': 'GB', 'Wales': 'GB',
  'Northern Ireland': 'GB', 'U.S.': 'US', 'United States': 'US', 'Brazil': 'BR', 'Czech Republic': 'CZ', 'Czechoslovakia': null, 'Yugoslavia': null,
  'Germany (East)': 'DE', 'Germany (West)': 'DE', 'Korea (South)': 'KR', 'Vietnam': 'VN', 'Iran': 'IR', 'Venezuela': 'VE', 'Bolivia': 'BO' };
const ETATS_US = new Set(['Ala.', 'Alaska', 'Ariz.', 'Ark.', 'Calif.', 'Colo.', 'Conn.', 'Del.', 'D.C.', 'Fla.', 'Ga.', 'Hawaii', 'Idaho', 'Ill.', 'Ind.', 'Iowa',
  'Kan.', 'Ky.', 'La.', 'Me.', 'Md.', 'Mass.', 'Mich.', 'Minn.', 'Miss.', 'Mo.', 'Mont.', 'Neb.', 'Nev.', 'N.H.', 'N.J.', 'N.M.', 'N.Y.', 'N.C.', 'N.D.', 'Ohio',
  'Okla.', 'Or.', 'Pa.', 'R.I.', 'S.C.', 'S.D.', 'Tenn.', 'Tex.', 'Utah', 'Vt.', 'Va.', 'Wash.', 'W. Va.', 'Wis.', 'Wyo.']);
const ETATS_BR = new Set(['Acre', 'Alagoas', 'Amapá', 'Amazonas', 'Bahia', 'Ceará', 'Espírito Santo', 'Goiás', 'Maranhão', 'Mato Grosso', 'Mato Grosso do Sul',
  'Minas Gerais', 'Pará', 'Paraíba', 'Paraná', 'Pernambuco', 'Piauí', 'Rio de Janeiro', 'Rio Grande do Norte', 'Rio Grande do Sul', 'Rondônia', 'Roraima',
  'Santa Catarina', 'São Paulo', 'Sergipe', 'Tocantins', 'Brazil']);
function paysDe(lieu) {
  const m = /\(([^()]+)\)\s*$/.exec(lieu || ''); if (!m) return null;
  const x = m[1].trim();
  if (x in ALIAS_PAYS) return ALIAS_PAYS[x];
  if (ETATS_US.has(x)) return 'US';
  if (ETATS_BR.has(x)) return 'BR';
  return pays.getAlpha2Code(x, 'en') || null;
}
// Langues « naturelles » d'un pays, pour confirmer une langue donnée par la LC (Reich et Gandhi y sont « English »).
const LANGUES_PAYS = { BR: ['pt-BR'], PT: ['pt-BR'], ES: ['es', 'ca', 'eu', 'gl'], AR: ['es'], UY: ['es'], MX: ['es'], CU: ['es'], CL: ['es'], CO: ['es'], PE: ['es'], VE: ['es'], BO: ['es'], PY: ['es'], EC: ['es'],
  FR: ['fr', 'oc'], BE: ['fr', 'nl'], CH: ['fr', 'de', 'it'], GB: ['en'], US: ['en'], CA: ['en', 'fr'], AU: ['en'], IE: ['en'], NZ: ['en'], IT: ['it'], DE: ['de'], AT: ['de'],
  RU: ['ru'], UA: ['uk', 'ru'], PL: ['pl'], NL: ['nl'], SE: ['sv'], DK: ['da'], NO: ['nb'], FI: ['fi'], GR: ['el'], RO: ['ro'], HU: ['hu'], CZ: ['cs'], JP: ['ja'], CN: ['zh'], TR: ['tr'], IL: ['he'] };
const annee = (s) => { const m = /^(\d{3,4})(?:-|$)/.exec(String(s || '')); return m ? Number(m[1]) : null; };

// ── État AnarBib APRÈS la phase 1 ───────────────────────────────────────────
const auteurs = JSON.parse(readFileSync(join(ICI, 'authors.json'), 'utf8'));
const phase1 = new Map();
for (const m of readFileSync(join(ICI, 'donnees.sql.values'), 'utf8').matchAll(/^\s+\((\d+), '(?:[^']|'')*', '(Q\d+)', (\S+), (\S+), (\S+), (\S+),/gm)) {
  const v = (s) => (s === 'NULL' ? null : s.replace(/^'|'$/g, ''));
  phase1.set(Number(m[1]), { naissance: v(m[3]) && Number(v(m[3])), mort: v(m[4]) && Number(v(m[4])), pays: v(m[5]), langue: v(m[6]) });
}
const notices = JSON.parse(readFileSync(join(ICI, 'books.json'), 'utf8'));
const titres = new Map();
// Titre PRINCIPAL (avant « : » ou « - ») : la LC cite souvent le titre court (« Violentados, 1995 »).
// Il doit figurer en entier dans les sources, avec au moins deux mots significatifs ou un mot de 8 lettres.
for (const n of notices) if (n.author_id && n.titulo) {
  const principal = norm(String(n.titulo).split(/s[:-–]s|:/)[0]);
  const sig = principal.split(' ').filter((w) => w.length > 1 && !MOTS_VIDES.has(w));
  if (sig.length >= 2 || (sig.length === 1 && sig[0].length >= 8)) (titres.get(n.author_id) || titres.set(n.author_id, new Set()).get(n.author_id)).add(principal);
}

const personnes = auteurs.filter((a) => a.authority_type === null || a.authority_type === 'person');
const resultats = []; let i = 0;
for (const a of personnes) {
  i++; if (i % 100 === 0) console.error(`LC ${i}/${personnes.length}`);
  const p1 = phase1.get(a.id) || {};
  const etat = { naissance: a.birth_year ?? p1.naissance ?? null, mort: a.death_year ?? p1.mort ?? null, pays: a.country ?? p1.pays ?? null, langue: p1.langue ?? null };
  if (etat.naissance && etat.mort && etat.pays && etat.langue) continue;
  const tri = a.sort_name && a.sort_name.includes(',') ? a.sort_name : a.preferred_name;
  const cible = vedette(tri);
  if (cible.split(' ').length < 2) { resultats.push({ id: a.id, nom: a.preferred_name, decision: 'nom_trop_court' }); continue; }
  const r = await loc(tri);
  const cands = (r.hits || []).filter((h) => (h.more?.rdftypes || []).includes('PersonalName') && vedette(h.aLabel) === cible);
  const sesTitres = titres.get(a.id) || new Set();
  const langsCatalogue = new Set(notices.filter((n) => n.author_id === a.id && n.idioma).map((n) => n.idioma));
  const verdicts = cands.map((h) => {
    const m = h.more || {};
    // Dates : champ structuré (046) sinon la vedette ($d) — « Silva, José, 1920-1985 », « …, 1951- », « …, b. 1951 ».
    const vd = /,s*(?:b.s*)?(d{4})(?:-(d{4})?)?s*$/.exec(h.aLabel || '');
    const n = annee((m.birthdates || [])[0]) ?? (vd ? Number(vd[1]) : null);
    const d = annee((m.deathdates || [])[0]) ?? (vd && vd[2] ? Number(vd[2]) : null);
    const sources = norm((m.sources || []).join(' '));
    const titre = [...sesTitres].find((s) => (' ' + sources + ' ').includes(' ' + s + ' '));
    const motifs = [];
    if (etat.naissance && n && Math.abs(n - etat.naissance) > 1) motifs.push(`naissance ${n} ≠ ${etat.naissance}`);
    if (etat.mort && d && Math.abs(d - etat.mort) > 1) motifs.push(`mort ${d} ≠ ${etat.mort}`);
    const accord = (etat.naissance && n && Math.abs(n - etat.naissance) <= 1) || (etat.mort && d && Math.abs(d - etat.mort) <= 1);
    return { h, n, d, titre, accord, motifs };
  });
  const viables = verdicts.filter((v) => !v.motifs.length && (v.titre || v.accord));
  let decision; let v = null;
  if (!cands.length) decision = 'introuvable';
  else if (viables.length === 1) { decision = 'accepte'; v = viables[0]; }
  else if (viables.length > 1) decision = 'ambigu';
  else decision = verdicts.some((x) => x.motifs.length) ? 'contradiction' : 'non_corrobore';
  const out = { id: a.id, nom: a.preferred_name, decision, candidats: verdicts.map((x) => ({ uri: x.h.uri, vedette: x.h.aLabel, motifs: x.motifs, titre: x.titre || null })) };
  if (v) {
    const m = v.h.more || {};
    const langs = (m.languages || []).map((l) => LANGUES[l]).filter(Boolean);
    out.lc = { uri: v.h.uri, vedette: v.h.aLabel, preuve: v.titre ? `titre « ${v.titre} »` : 'dates', naissance: v.n, mort: v.d,
      lieu: (m.birthplaces || [])[0] || null, pays: paysDe((m.birthplaces || [])[0]), langues: m.languages || [], langue: new Set(langs).size === 1 ? langs[0] : null };
    out.remplir = {
      naissance: !etat.naissance && v.n ? v.n : null,
      mort: !etat.mort && v.d && (!etat.naissance || v.d >= etat.naissance) && (!v.n || v.d >= v.n) ? v.d : null,
      pays: !etat.pays && out.lc.pays ? out.lc.pays : null,
      langue: !etat.langue && out.lc.langue && (langsCatalogue.has(out.lc.langue) || (LANGUES_PAYS[etat.pays || out.lc.pays] || []).includes(out.lc.langue)) ? out.lc.langue : null,
    };
  }
  resultats.push(out);
}
writeFileSync(join(ICI, 'resultats-loc.json'), JSON.stringify(resultats, null, 1));
const c = {}; for (const r of resultats) c[r.decision] = (c[r.decision] || 0) + 1;
const f = { naissance: 0, mort: 0, pays: 0, langue: 0, fiches: 0 };
for (const r of resultats.filter((x) => x.remplir)) { let k = 0; for (const x of ['naissance', 'mort', 'pays', 'langue']) if (r.remplir[x]) { f[x]++; k++; } if (k) f.fiches++; }
console.log('LC :', resultats.length, JSON.stringify(c), 'à remplir :', JSON.stringify(f));
