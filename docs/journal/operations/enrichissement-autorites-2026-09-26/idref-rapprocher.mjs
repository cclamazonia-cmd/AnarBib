// Troisième phase — IdRef (autorités des bibliothèques universitaires françaises, ABES). LECTURE SEULE.
// IdRef porte la nationalité (102), la langue (101) et les dates (103) ; ses notices sont liées aux
// documents SUDOC, dont les citations donnent la preuve : un titre de l'auteur au catalogue AnarBib.
// Ne comble que le vide de l'état ACTUEL (authors-p3.json, après les phases Wikidata et LC).
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ICI = dirname(fileURLToPath(import.meta.url));
const CACHE = join(ICI, 'cache-idref'); mkdirSync(CACHE, { recursive: true });
const UA = 'AnarBib-enrichissement-autorites/1.0 (https://anarbib.org; anarbib@proton.me)';
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
async function lire(url, json = true) {
  const f = join(CACHE, createHash('sha1').update(url).digest('hex') + (json ? '.json' : '.xml'));
  if (existsSync(f)) return json ? JSON.parse(readFileSync(f, 'utf8')) : readFileSync(f, 'utf8');
  for (let e = 0; e < 8; e++) {
    await dormir(200);
    try { const r = await fetch(url, { headers: { 'User-Agent': UA } });
      if (r.status === 404) { writeFileSync(f, json ? 'null' : ''); return json ? null : ''; }
      if (r.ok) { const t = await r.text(); writeFileSync(f, t); return json ? JSON.parse(t) : t; }
    } catch {}
    await dormir(2000 * (e + 1));
  }
  throw new Error('IdRef injoignable : ' + url);
}

const norm = (s) => String(s || '').normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim().replace(/\s+/g, ' ');
const vedette = (s) => norm(String(s || '').replace(/\([^)]*\)/g, ' '));
const MOTS_VIDES = new Set(['a', 'o', 'as', 'os', 'e', 'de', 'da', 'do', 'das', 'dos', 'la', 'le', 'les', 'el', 'los', 'las', 'the', 'of', 'and', 'et', 'y', 'du', 'des', 'en', 'em', 'no', 'na', 'un', 'une', 'uma', 'um', 'il', 'lo', 'di', 'del', 'della', 'per', 'por', 'para', 'sobre', 'sur', 'to', 'in']);
// ISO 639-2 (IdRef 101) → référentiel des notices.
const LANGUES = { por: 'pt-BR', spa: 'es', fre: 'fr', fra: 'fr', eng: 'en', ita: 'it', ger: 'de', deu: 'de', cat: 'ca', epo: 'eo', dut: 'nl', nld: 'nl',
  gre: 'el', ell: 'el', rus: 'ru', pol: 'pl', ukr: 'uk', cze: 'cs', ces: 'cs', hun: 'hu', rum: 'ro', ron: 'ro', swe: 'sv', dan: 'da', fin: 'fi',
  baq: 'eu', eus: 'eu', glg: 'gl', oci: 'oc', heb: 'he', ara: 'ar', tur: 'tr', jpn: 'ja', chi: 'zh', zho: 'zh', kor: 'ko', per: 'fa', fas: 'fa',
  bul: 'bg', hrv: 'hr', srp: 'sr', slo: 'sk', slk: 'sk', nob: 'nb', nor: 'nb', hin: 'hi', ind: 'id' };
const VALIDES = new Set(JSON.parse(readFileSync(join(ICI, 'iso2-valides.json'), 'utf8')));
// Langue confirmée par le catalogue ou par le pays (IdRef donne « eng » à Paulo Ghiraldelli Jr.).
const LANGUES_PAYS = { BR: ['pt-BR'], PT: ['pt-BR'], ES: ['es', 'ca', 'eu', 'gl'], AR: ['es'], UY: ['es'], MX: ['es'], CU: ['es'], CL: ['es'], CO: ['es'], PE: ['es'], VE: ['es'], BO: ['es'], PY: ['es'], EC: ['es'],
  FR: ['fr', 'oc'], BE: ['fr', 'nl'], CH: ['fr', 'de', 'it'], GB: ['en'], US: ['en'], CA: ['en', 'fr'], AU: ['en'], IE: ['en'], IT: ['it'], DE: ['de'], AT: ['de'],
  RU: ['ru'], UA: ['uk', 'ru'], PL: ['pl'], NL: ['nl'], SE: ['sv'], DK: ['da'], NO: ['nb'], FI: ['fi'], GR: ['el'], RO: ['ro'], HU: ['hu'], CZ: ['cs'], JP: ['ja'], RS: ['sr'], IL: ['he'] };
const annee = (s) => { const m = /^\s*(\d{4})/.exec(s || ''); return m ? Number(m[1]) : null; };
function champs(xml, tag, code) {
  const out = [];
  for (const m of xml.matchAll(new RegExp(`<datafield tag="${tag}"[^>]*>([\\s\\S]*?)</datafield>`, 'g')))
    for (const s of m[1].matchAll(new RegExp(`<subfield code="${code}">([^<]*)</subfield>`, 'g'))) out.push(s[1]);
  return out;
}

const auteurs = JSON.parse(readFileSync(join(ICI, 'authors-p3.json'), 'utf8'));
const notices = JSON.parse(readFileSync(join(ICI, 'books.json'), 'utf8'));
const titres = new Map();
for (const n of notices) if (n.author_id && n.titulo) {
  const principal = norm(String(n.titulo).split(/\s[:\-–]\s|:/)[0]);
  const sig = principal.split(' ').filter((w) => w.length > 1 && !MOTS_VIDES.has(w));
  // Deux mots significatifs au moins : « anarquistas », « venezuela » seuls ne prouvent rien.
  if (sig.length >= 2) (titres.get(n.author_id) || titres.set(n.author_id, new Set()).get(n.author_id)).add(principal);
}

const personnes = auteurs.filter((a) => (a.authority_type === null || a.authority_type === 'person') && (!a.country || !a.birth_year || !a.writing_language));
const resultats = []; let i = 0;
for (const a of personnes) {
  i++; if (i % 100 === 0) console.error(`IdRef ${i}/${personnes.length}`);
  const tri = a.sort_name && a.sort_name.includes(',') ? a.sort_name : a.preferred_name;
  const cible = vedette(tri);
  const mots = cible.split(' ').filter((w) => w.length > 1);
  if (mots.length < 2) { resultats.push({ id: a.id, nom: a.preferred_name, decision: 'nom_trop_court' }); continue; }
  const q = `persname_t:(${mots.map(encodeURIComponent).join('%20AND%20')})`;
  const r = await lire(`https://www.idref.fr/Sru/Solr?q=${q}&wt=json&fl=ppn_z,affcourt_z&rows=10`);
  const docs = (r?.response?.docs || []).filter((d) => vedette(d.affcourt_z) === cible);
  const sesTitres = titres.get(a.id) || new Set();
  const langsCatalogue = new Set(notices.filter((x) => x.author_id === a.id && x.idioma).map((x) => x.idioma));
  const verdicts = [];
  for (const d of docs) {
    const xml = await lire(`https://www.idref.fr/${d.ppn_z}.xml`, false);
    if (!xml || !/tag="008"[^>]*>Tp/.test(xml)) continue;                      // personne physique seulement
    const d103 = champs(xml, '103', 'a')[0], m103 = champs(xml, '103', 'b')[0];
    // Années du champ 103, à condition que la vedette ne dise pas autre chose (Alexandre Vieira : 1884 dans
    // la vedette, 1880 dans le 103 — on n'écrit alors aucune année).
    const vd = /\((\d{4})-(\d{4})?/.exec(d.affcourt_z || '');
    let n = annee(d103), m = annee(m103);
    if (vd && ((n && Number(vd[1]) !== n) || (m && vd[2] && Number(vd[2]) !== m))) { n = null; m = null; }
    const pays = champs(xml, '102', 'a').map((c) => c.trim().toUpperCase()).filter((c) => VALIDES.has(c));
    const langs = [...new Set(champs(xml, '101', 'a').map((c) => LANGUES[c.trim()]).filter(Boolean))];
    const biblio = await lire(`https://www.idref.fr/services/biblio/${d.ppn_z}.json`);
    const cites = norm(JSON.stringify(biblio?.sudoc?.result?.role || []).replace(/"citation":/g, ' '));
    const titre = [...sesTitres].find((s) => (' ' + cites + ' ').includes(' ' + s + ' '));
    const motifs = [];
    if (a.birth_year && n && Math.abs(n - a.birth_year) > 1) motifs.push(`naissance ${n} ≠ ${a.birth_year}`);
    if (a.death_year && m && Math.abs(m - a.death_year) > 1) motifs.push(`mort ${m} ≠ ${a.death_year}`);
    if (a.country && pays.length && !pays.includes(a.country)) motifs.push(`pays ${pays.join('/')} ≠ ${a.country}`);
    const accord = (a.birth_year && n && Math.abs(n - a.birth_year) <= 1) || (a.death_year && m && Math.abs(m - a.death_year) <= 1);
    verdicts.push({ ppn: d.ppn_z, vedette: d.affcourt_z, n, m, pays, langs, titre, accord, motifs });
  }
  const viables = verdicts.filter((v) => !v.motifs.length && (v.titre || v.accord));
  let decision; let v = null;
  if (!verdicts.length) decision = 'introuvable';
  else if (viables.length === 1) { decision = 'accepte'; v = viables[0]; }
  else if (viables.length > 1) decision = 'ambigu';
  else decision = verdicts.some((x) => x.motifs.length) ? 'contradiction' : 'non_corrobore';
  const out = { id: a.id, nom: a.preferred_name, decision, candidats: verdicts.map((x) => ({ ppn: x.ppn, vedette: x.vedette, motifs: x.motifs, titre: x.titre || null })) };
  if (v) {
    out.idref = { ppn: v.ppn, vedette: v.vedette, preuve: v.titre ? `titre « ${v.titre} »` : 'dates', naissance: v.n, mort: v.m, pays: v.pays, langues: v.langs };
    out.remplir = {
      naissance: !a.birth_year && v.n ? v.n : null,
      mort: !a.death_year && v.m && (!a.birth_year || v.m >= a.birth_year) && (!v.n || v.m >= v.n) ? v.m : null,
      pays: !a.country && v.pays.length === 1 ? v.pays[0] : null,
      langue: !a.writing_language && v.langs.length === 1 && (langsCatalogue.has(v.langs[0]) || (LANGUES_PAYS[a.country || (v.pays.length === 1 ? v.pays[0] : '')] || []).includes(v.langs[0])) ? v.langs[0] : null,
    };
  }
  resultats.push(out);
}
writeFileSync(join(ICI, 'resultats-idref.json'), JSON.stringify(resultats, null, 1));
const c = {}; for (const r of resultats) c[r.decision] = (c[r.decision] || 0) + 1;
const f = { naissance: 0, mort: 0, pays: 0, langue: 0, fiches: 0 };
for (const r of resultats.filter((x) => x.remplir)) { let k = 0; for (const x of ['naissance', 'mort', 'pays', 'langue']) if (r.remplir[x]) { f[x]++; k++; } if (k) f.fiches++; }
console.log('IdRef :', resultats.length, JSON.stringify(c), 'à remplir :', JSON.stringify(f));
