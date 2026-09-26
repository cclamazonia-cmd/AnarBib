// Rapprochement des autorités AnarBib avec Wikidata — LECTURE SEULE.
// Entrées : authors.json (API publique), books.json (auteur principal, année, langue des notices).
// Sorties : cache/ (réponses Wikidata), resultats.json (une décision par autorité), bilan à l'écran.
// Rien n'est écrit en base : la décision d'écrire vient après relecture du bilan.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ICI = dirname(fileURLToPath(import.meta.url));
const CACHE = join(ICI, 'cache'); mkdirSync(CACHE, { recursive: true });
const UA = 'AnarBib-enrichissement-autorites/1.0 (https://anarbib.org; anarbib@proton.me)';
const API = 'https://www.wikidata.org/w/api.php';
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));

async function wd(params) {
  // Lecture seule : pas de maxlag (fait pour les robots qui écrivent ; il faisait refuser les
  // lectures quand le service de requêtes prenait du retard). La clé du cache garde la forme
  // d'origine pour réutiliser les réponses déjà obtenues.
  const q = new URLSearchParams({ format: 'json', ...params }).toString();
  const cle = new URLSearchParams({ format: 'json', maxlag: '5', ...params }).toString();
  const f = join(CACHE, createHash('sha1').update(cle).digest('hex') + '.json');
  if (existsSync(f)) return JSON.parse(readFileSync(f, 'utf8'));
  for (let essai = 0; essai < 10; essai++) {
    await dormir(120);
    try {
      const r = await fetch(`${API}?${q}`, { headers: { 'User-Agent': UA } });
      if (r.status === 429 || r.status >= 500) { await dormir(2000 * (essai + 1)); continue; }
      const j = await r.json();
      if (j.error && j.error.code === 'maxlag') { await dormir(5000); continue; }
      writeFileSync(f, JSON.stringify(j));
      return j;
    } catch { await dormir(2000 * (essai + 1)); }
  }
  throw new Error('Wikidata injoignable : ' + q.slice(0, 120));
}

// ── Normalisation des noms ──────────────────────────────────────────────────
const norm = (s) => String(s || '').normalize('NFD').replace(/\p{M}/gu, '').toLowerCase()
  .replace(/[^\p{L}\p{N}]+/gu, ' ').trim().replace(/\s+/g, ' ');
const jetons = (s) => norm(s).split(' ').filter(Boolean).sort().join(' ');
function formesDe(a) {
  const f = new Set();
  const add = (s) => { if (s && norm(s).length >= 3) { f.add(norm(s)); f.add('§' + jetons(s)); } };
  add(a.preferred_name);
  if (a.sort_name && a.sort_name.includes(',')) { const [n, p] = a.sort_name.split(',').map((x) => x.trim()); add(`${p} ${n}`); }
  add(a.sort_name);
  if (a.variant_forms && typeof a.variant_forms === 'object')
    for (const v of Object.values(a.variant_forms)) for (const s of (Array.isArray(v) ? v : [v])) add(s);
  return f;
}
function formesEntite(e) {
  const f = new Set();
  const add = (s) => { if (s) { f.add(norm(s)); f.add('§' + jetons(s)); } };
  for (const l of Object.values(e.labels || {})) add(l.value);
  for (const arr of Object.values(e.aliases || {})) for (const l of arr) add(l.value);
  return f;
}

// ── Lecture des déclarations ────────────────────────────────────────────────
const valeurs = (e, p) => (e.claims?.[p] || []).filter((c) => c.rank !== 'deprecated' && c.mainsnak?.snaktype === 'value');
const preferees = (e, p) => { const v = valeurs(e, p); const pr = v.filter((c) => c.rank === 'preferred'); return pr.length ? pr : v; };
const qids = (e, p) => preferees(e, p).map((c) => c.mainsnak.datavalue.value.id).filter(Boolean);
function annee(e, p) {
  const ans = new Set();
  for (const c of preferees(e, p)) {
    const v = c.mainsnak.datavalue.value;
    if (v.precision < 9) return { incertain: true };
    const m = /^([+-])0*(\d+)-/.exec(v.time); if (!m || m[1] === '-') return { incertain: true };
    ans.add(Number(m[2]));
  }
  if (ans.size > 1) return { incertain: true, valeurs: [...ans] };
  return ans.size ? { valeur: [...ans][0] } : {};
}
const chaine = (e, p) => preferees(e, p).map((c) => c.mainsnak.datavalue.value).filter((x) => typeof x === 'string');

const METIERS_ECRITURE = new Set(['Q36180', 'Q1930187', 'Q49757', 'Q6625963', 'Q11774202', 'Q4964182', 'Q201788', 'Q2306091',
  'Q1238570', 'Q188094', 'Q4773904', 'Q333634', 'Q1231865', 'Q37226', 'Q1622272', 'Q15253558', 'Q11499147', 'Q15627169',
  'Q3242115', 'Q1607826', 'Q2516866', 'Q175151', 'Q214917', 'Q4263842', 'Q901402', 'Q1650915', 'Q635734', 'Q182436',
  'Q715301', 'Q644687', 'Q1114448', 'Q4853732', 'Q1028181', 'Q3410028', 'Q212980', 'Q1234713', 'Q18814623', 'Q12144794',
  'Q16533', 'Q1350157', 'Q17167049', 'Q13570226', 'Q5322166', 'Q8178443', 'Q27532437', 'Q18939491', 'Q15949613']);
const IDS_BIBLIO = ['P214', 'P213', 'P244', 'P268', 'P269', 'P950', 'P396', 'P227', 'P1006', 'P409', 'P1015', 'P3280', 'P1375', 'P7859', 'P5587'];
// Signaux, du plus fort au plus faible. « chercheur » (Q1650915) seul est FAIBLE : des fiches
// créées en masse depuis ORCID, où un nom courant trouve toujours un homonyme.
const signaux = (e) => { const s = [];
  if (IDS_BIBLIO.some((p) => valeurs(e, p).length)) s.push('biblio');
  const m = qids(e, 'P106').filter((q) => METIERS_ECRITURE.has(q));
  if (m.some((q) => q !== 'Q1650915')) s.push('metier'); else if (m.length) s.push('chercheur');
  if (qids(e, 'P1142').includes('Q6199')) s.push('anarchisme');
  return s; };
const corrobore = (e) => signaux(e).some((x) => x !== 'chercheur');

// ── Données AnarBib ─────────────────────────────────────────────────────────
const auteurs = JSON.parse(readFileSync(join(ICI, 'authors.json'), 'utf8'));
const notices = JSON.parse(readFileSync(join(ICI, 'books.json'), 'utf8'));
const parAuteur = new Map();
for (const n of notices) {
  if (!n.author_id) continue;
  const o = parAuteur.get(n.author_id) || { annees: [], langues: new Set() };
  const m = /(1[5-9]\d\d|20\d\d)/.exec(n.ano || ''); if (m) o.annees.push(Number(m[1]));
  if (n.idioma) o.langues.add(n.idioma.split('-')[0]);
  parAuteur.set(n.author_id, o);
}

const personnes = auteurs.filter((a) => a.authority_type === null || a.authority_type === 'person');
const LIMITE = Number(process.env.LIMITE || personnes.length);

// ── 1. Recherche ────────────────────────────────────────────────────────────
const candidatsDe = new Map();
let i = 0;
for (const a of personnes.slice(0, LIMITE)) {
  i++;
  if (a.wikidata_id) { candidatsDe.set(a.id, [a.wikidata_id]); continue; }
  const r = await wd({ action: 'query', list: 'search', srsearch: `${a.preferred_name} haswbstatement:P31=Q5`, srlimit: '10', srnamespace: '0' });
  candidatsDe.set(a.id, (r.query?.search || []).map((s) => s.title));
  if (i % 100 === 0) console.error(`recherche ${i}/${Math.min(LIMITE, personnes.length)}`);
}

// ── 2. Entités candidates ───────────────────────────────────────────────────
const entites = new Map();
async function charger(ids, props = 'labels|aliases|claims|sitelinks') {
  const manquants = [...new Set(ids)].filter((q) => !entites.has(q));
  for (let k = 0; k < manquants.length; k += 50) {
    const lot = manquants.slice(k, k + 50);
    const r = await wd({ action: 'wbgetentities', ids: lot.join('|'), props, languages: 'mul|pt|fr|es|en|it|de|ca|eo|nl|el|oc|gl|eu|pl|ru' });
    for (const [q, e] of Object.entries(r.entities || {})) entites.set(q, e);
  }
}
await charger([...candidatsDe.values()].flat());
console.error(`entités candidates chargées : ${entites.size}`);

// ── 3. Décision par autorité ────────────────────────────────────────────────
const resultats = [];
for (const a of personnes.slice(0, LIMITE)) {
  const ev = parAuteur.get(a.id) || { annees: [], langues: new Set() };
  const minPub = ev.annees.length ? Math.min(...ev.annees) : null;
  const formes = formesDe(a);
  const cands = (candidatsDe.get(a.id) || []).map((q) => entites.get(q)).filter(Boolean);
  const nomOk = cands.filter((e) => {
    if (a.wikidata_id) return true;
    if (!qids(e, 'P31').includes('Q5')) return false;
    const fe = formesEntite(e);
    return [...formes].some((f) => fe.has(f));
  });
  const verdicts = nomOk.map((e) => {
    const n = annee(e, 'P569'), d = annee(e, 'P570');
    const motifs = [];
    if (a.birth_year && n.valeur && Math.abs(n.valeur - a.birth_year) > 1) motifs.push(`naissance ${n.valeur} ≠ ${a.birth_year}`);
    if (a.death_year && d.valeur && Math.abs(d.valeur - a.death_year) > 1) motifs.push(`mort ${d.valeur} ≠ ${a.death_year}`);
    if (minPub && n.valeur && n.valeur > minPub - 10) motifs.push(`né ${n.valeur}, publié dès ${minPub}`);
    const accord = (a.birth_year && n.valeur && Math.abs(n.valeur - a.birth_year) <= 1) || (a.death_year && d.valeur && Math.abs(d.valeur - a.death_year) <= 1);
    return { e, motifs, accord, corrobore: corrobore(e), signaux: signaux(e) };
  });
  const viables = verdicts.filter((v) => !v.motifs.length && (v.corrobore || v.accord || a.wikidata_id));
  let decision, retenu = null;
  if (a.wikidata_id) { decision = 'deja_lie'; retenu = verdicts[0]; }
  else if (!nomOk.length) decision = 'introuvable';
  // Un seul signal sans concordance de dates : une sur dix était fausse à la relecture du 26/09
  // (acteurs, astronome, sculpteur du XVIIe) → « a_relire », jamais écrit d'office.
  else if (viables.length === 1 && (nomOk.length < 3 || viables[0].accord)) {
    const forts = viables[0].signaux.filter((x) => x !== 'chercheur').length;
    decision = (viables[0].accord || forts >= 2) ? 'accepte' : 'a_relire'; retenu = viables[0]; }
  else if (viables.length === 0) decision = verdicts.some((v) => v.motifs.length) ? 'contradiction' : 'non_corrobore';
  else decision = 'ambigu';
  resultats.push({
    id: a.id, nom: a.preferred_name, decision, qid: retenu?.e.id || null,
    candidats: verdicts.map((v) => ({ qid: v.e.id, motifs: v.motifs, corrobore: v.corrobore, accord: !!v.accord, signaux: v.signaux })),
    signaux: retenu ? retenu.signaux : [], accord: retenu ? !!retenu.accord : false,
    minPub, langues: [...ev.langues],
  });
}

// ── 4. Pays et langues des retenus ──────────────────────────────────────────
const retenus = resultats.filter((r) => r.qid).map((r) => entites.get(r.qid)).filter(Boolean);
await charger(retenus.flatMap((e) => [...qids(e, 'P27'), ...qids(e, 'P6886'), ...qids(e, 'P1412'), ...qids(e, 'P103'), ...qids(e, 'P19')]), 'labels|claims');
// Lieu de naissance → pays ACTUEL (rang préféré de P17), puis son code.
await charger(retenus.flatMap((e) => qids(e, 'P19')).flatMap((q) => entites.get(q) ? qids(entites.get(q), 'P17') : []), 'labels|claims');
const VALIDES = new Set(JSON.parse(readFileSync(join(ICI, 'iso2-valides.json'), 'utf8')));
const iso2 = (q) => { const e = entites.get(q); const c = e ? (chaine(e, 'P297')[0] || null) : null; return c && VALIDES.has(c) ? c : null; };
const paysNaissance = (e) => { const lieu = entites.get(qids(e, 'P19')[0]); if (!lieu) return null; const p = qids(lieu, 'P17'); return p.length === 1 ? iso2(p[0]) : null; };
const iso639 = (q) => { const e = entites.get(q); return e ? (chaine(e, 'P218')[0] || chaine(e, 'P220')[0] || null) : null; };
const libelle = (q) => { const e = entites.get(q); return e?.labels?.fr?.value || e?.labels?.en?.value || e?.labels?.mul?.value || q; };

const HISTORIQUES = JSON.parse(existsSync(join(ICI, 'etats-historiques.json')) ? readFileSync(join(ICI, 'etats-historiques.json'), 'utf8') : '{}');
const nonMappes = new Map();
for (const r of resultats.filter((x) => x.qid)) {
  const e = entites.get(r.qid); if (!e) continue;
  const n = annee(e, 'P569'), d = annee(e, 'P570');
  // Nationalité : P27 en codes ISO actuels. Un seul → retenu. Plusieurs → celui du pays de naissance
  // s'il en fait partie. Aucun code actuel (État disparu : Empire russe, URSS, royaume d'Italie…)
  // → pays actuel du lieu de naissance. Sinon rien.
  // États disparus : etats-historiques.json → un code (successeur unique) ou une liste
  // (plusieurs successeurs : le pays de naissance n'est retenu que s'il en fait partie).
  const citoyennetes = qids(e, 'P27');
  const naiss = paysNaissance(e);
  const R = new Set(); const nonResolus = [];
  for (const q of citoyennetes) {
    const c = iso2(q) || (typeof HISTORIQUES[q] === 'string' ? HISTORIQUES[q] : null);
    if (c) { R.add(c); continue; }
    if (Array.isArray(HISTORIQUES[q])) { if (naiss && HISTORIQUES[q].includes(naiss)) R.add(naiss); else nonResolus.push(HISTORIQUES[q]); continue; }
    nonMappes.set(q, (nonMappes.get(q) || 0) + 1); nonResolus.push([]);
  }
  let pays = null, paysRegle = null;
  const codes = [...R];
  if (codes.length === 1 && nonResolus.every((l) => l.includes(codes[0]))) { pays = codes[0]; paysRegle = citoyennetes.every((q) => iso2(q)) ? 'P27' : 'P27 (État disparu → successeur)'; }
  else if (codes.length > 1 && naiss && codes.includes(naiss) && !nonResolus.length) { pays = naiss; paysRegle = 'P27 plusieurs → pays de naissance'; }

  // Langue d'écriture : P6886 (langue d'écriture) fait foi. À défaut, P1412 (parlée ou écrite)
  // n'est retenue que si elle est aussi la langue maternelle (P103) ou celle de ses livres au
  // catalogue — P1412 seul a donné l'espéranto pour Tragtenberg.
  const catalogue = new Set(r.langues);
  const ecrit = qids(e, 'P6886'), parle = qids(e, 'P1412'), natale = qids(e, 'P103');
  const unique = (arr) => { const u = [...new Set(arr.map(iso639).filter(Boolean))]; return u.length === 1 ? u[0] : null; };
  let langue = null, langueRegle = null;
  if (ecrit.length) {
    langue = unique(ecrit) || unique(ecrit.filter((q) => natale.includes(q))) || unique(ecrit.filter((q) => catalogue.has(iso639(q))));
    if (langue) langueRegle = 'P6886';
  } else if (parle.length) {
    const sures = parle.filter((q) => natale.includes(q) || catalogue.has(iso639(q)));
    langue = unique(sures) || unique(sures.filter((q) => natale.includes(q)));
    if (langue) langueRegle = 'P1412 confirmée';
  }
  r.wd = {
    libelle: e.labels?.fr?.value || e.labels?.pt?.value || e.labels?.en?.value || e.labels?.mul?.value,
    naissance: n.valeur ?? null, mort: d.valeur ?? null,
    pays, paysRegle, pays_libelles: citoyennetes.map(libelle), pays_naissance: naiss,
    langue, langueRegle, langues_libelles: [...ecrit, ...parle].map(libelle),
    viaf: chaine(e, 'P214')[0] || null, isni: (chaine(e, 'P213')[0] || '').replace(/\s/g, '') || null,
    sitelinks: Object.keys(e.sitelinks || {}).length,
  };
}

writeFileSync(join(ICI, 'resultats.json'), JSON.stringify(resultats, null, 1));
writeFileSync(join(ICI, 'etats-non-mappes.json'), JSON.stringify([...nonMappes].map(([q, n]) => ({ q, n, libelle: libelle(q) })).sort((x, y) => y.n - x.n), null, 1));
const c = {}; for (const r of resultats) c[r.decision] = (c[r.decision] || 0) + 1;
console.log('autorités traitées :', resultats.length, JSON.stringify(c));
console.log('états sans code ISO (P27) :', nonMappes.size);
