// C4 — candidates « identité sûre, pays à proposer » parmi les fiches sans pays.
// Entrées : les trois decisions*.csv des passes de septembre (trace au dépôt) et la
// liste des ids sans pays (prod, 09/10). Sortie : propositions.csv (une ligne par
// fiche : id, nom, source, identifiant, forme, pays ISO, règle, motif) et refus.csv.
// Règle (Xavier, 08/10) : identité sûre = dates concordantes OU deux signaux
// indépendants ; le pays vient de la source ; posé en proposition, jamais d'office.
// Wikidata seul est interrogé ici (P27 → P297 ISO 3166-1 α-2 ; États disparus
// → successeur, etats-historiques.json), pour les candidats retenus.
import fs from 'node:fs';
import path from 'node:path';
const ROOT = process.argv[2];           // dossier enrichissement-autorites-2026-09-26
const IDS = new Set(fs.readFileSync(process.argv[3], 'utf8').split(/[\s,]+/).filter(Boolean).map(Number));
const OUT = process.argv[4] || '.';
const UA = 'AnarBib-enrichissement-autorites/1.0 (https://anarbib.org; anarbib@proton.me)';
const lire = (f) => {
  const t = fs.readFileSync(path.join(ROOT, f), 'utf8').replace(/^﻿/, '').split('\n').filter((l) => l.trim());
  const h = t[0].split(';');
  return new Map(t.slice(1).map((l) => { const c = l.split(';'); const o = {}; h.forEach((k, i) => (o[k] = c[i] ?? '')); return [Number(o.id), o]; }));
};
const wd = lire('decisions.csv'), lc = lire('decisions-lc.csv');
const hist = JSON.parse(fs.readFileSync(path.join(ROOT, 'etats-historiques.json'), 'utf8'));

// Un candidat Wikidata : « Qxxx [notes] {sig1+sig2} »
function candidats(cm) {
  return cm.split('|').map((s) => s.trim()).filter(Boolean).map((s) => {
    const q = (s.match(/^(Q\d+)/) || [])[1];
    const sig = (s.match(/\{([^}]*)\}/) || [, ''])[1].split('+').map((x) => x.trim()).filter(Boolean);
    const contradiction = /\[[^\]]*(né|mort|publié)[^\]]*\]/.test(s);
    return { q, sig, contradiction, brut: s };
  }).filter((c) => c.q);
}
const retenus = [], refus = [];
for (const id of IDS) {
  const r = wd.get(id);
  if (!r) { refus.push([id, '', 'wikidata', 'absente des passes de septembre (fiche postérieure ?)']); continue; }
  if (r.decision === 'introuvable') { refus.push([id, r.nom, 'wikidata', 'introuvable dans Wikidata']); continue; }
  if (r.decision === 'acceptée') { refus.push([id, r.nom, 'wikidata', `acceptée en septembre (${r.qid}) mais Wikidata ne donne pas de nationalité`]); continue; }
  const cs = candidats(r.candidats_et_motifs || '').filter((c) => !c.contradiction);
  const forts = cs.filter((c) => c.sig.length >= 2);
  if (forts.length === 1) {
    const autres = cs.filter((c) => c !== forts[0]).map((c) => c.brut).join(' | ');
    retenus.push({ id, nom: r.nom, source: 'wikidata', q: forts[0].q, sig: forts[0].sig.join('+'), decision: r.decision, autres });
  } else if (forts.length > 1) {
    refus.push([id, r.nom, 'wikidata', `${forts.length} candidats à deux signaux ou plus : ${forts.map((c) => c.brut).join(' | ')}`]);
  } else {
    refus.push([id, r.nom, 'wikidata', `${r.decision} — aucun candidat à deux signaux (${(r.candidats_et_motifs || '').slice(0, 120)})`]);
  }
}
// Library of Congress : acceptée en septembre (règle de la passe : vedette + preuve) et un lieu de naissance connu.
const lcRetenus = [];
for (const id of IDS) {
  const r = lc.get(id);
  if (r && r.decision === 'accepte' && r.lieu_naissance_lc) lcRetenus.push({ id, nom: r.nom, lccn: r.lccn, vedette: r.vedette_lc, lieu: r.lieu_naissance_lc, preuve: r.preuve });
}

// ── Wikidata : P27 des candidats retenus, puis P297 des pays ─────────────────
async function api(params) {
  const q = new URLSearchParams({ format: 'json', ...params }).toString();
  const r = await fetch(`https://www.wikidata.org/w/api.php?${q}`, { headers: { 'User-Agent': UA } });
  if (!r.ok) throw new Error(`wikidata ${r.status}`);
  return r.json();
}
async function entites(ids, props) {
  const out = {};
  for (let i = 0; i < ids.length; i += 50) {
    const lot = ids.slice(i, i + 50);
    const j = await api({ action: 'wbgetentities', ids: lot.join('|'), props, languages: 'fr|pt|es|en|it|de|mul' });
    Object.assign(out, j.entities || {});
    await new Promise((res) => setTimeout(res, 300));
  }
  return out;
}
const val = (e, p) => ((e?.claims?.[p]) || []).filter((c) => c.rank !== 'deprecated').map((c) => c.mainsnak?.datavalue?.value).filter(Boolean);
const label = (e) => e?.labels?.fr?.value || e?.labels?.en?.value || e?.labels?.pt?.value || e?.labels?.es?.value || e?.labels?.mul?.value || '';
const annee = (e, p) => { const v = val(e, p)[0]; return v && v.time ? v.time.slice(1, 5) : ''; };

const qids = retenus.map((r) => r.q);
const ents = qids.length ? await entites(qids, 'labels|claims') : {};
const paysQ = new Set();
for (const r of retenus) for (const v of val(ents[r.q], 'P27')) paysQ.add(v.id);
const paysEnt = paysQ.size ? await entites([...paysQ], 'labels|claims') : {};
const iso = (q) => (val(paysEnt[q], 'P297')[0]) || hist[q] || '';
const propositions = [];
for (const r of retenus) {
  const e = ents[r.q];
  const cit = val(e, 'P27').map((v) => v.id);
  const codes = [...new Set(cit.map(iso).filter(Boolean))];
  const naissance = annee(e, 'P569'), mort = annee(e, 'P570');
  let pays = '', regle = '';
  if (codes.length === 1 && cit.every((q) => iso(q))) { pays = codes[0]; regle = 'P27'; }
  else if (codes.length > 1) {
    const lieu = val(e, 'P19')[0]?.id; // pays de naissance = P17 du lieu : non résolu ici → on ne tranche pas
    regle = `plusieurs nationalités (${codes.join(', ')})`;
  } else regle = cit.length ? `nationalité sans code ISO (${cit.join(', ')})` : 'pas de nationalité dans Wikidata';
  const ligne = { ...r, libelle: label(e), naissance, mort, pays, regle };
  if (pays) propositions.push(ligne); else refus.push([r.id, r.nom, 'wikidata', `${r.q} ${label(e)} : ${regle}`]);
}
for (const r of lcRetenus) propositions.push({ id: r.id, nom: r.nom, source: 'lc', q: r.lccn, sig: 'vedette+preuve', decision: 'accepte', autres: '', libelle: r.vedette, naissance: '', mort: '', pays: '', regle: `lieu de naissance LC : ${r.lieu} — pays à lire à la main`, preuve: r.preuve });

const csv = (rows, cols) => [cols.join(';'), ...rows.map((r) => cols.map((c) => String(r[c] ?? '').replace(/;/g, ',')).join(';'))].join('\n') + '\n';
fs.writeFileSync(path.join(OUT, 'propositions.csv'), csv(propositions, ['id', 'nom', 'source', 'q', 'libelle', 'naissance', 'mort', 'pays', 'regle', 'sig', 'decision', 'autres']));
fs.writeFileSync(path.join(OUT, 'refus.csv'), [['id', 'nom', 'source', 'motif'].join(';'), ...refus.map((r) => r.map((x) => String(x).replace(/;/g, ',')).join(';'))].join('\n') + '\n');
const parRegle = {}; for (const p of propositions) parRegle[p.regle.split(' ')[0]] = (parRegle[p.regle.split(' ')[0]] || 0) + 1;
console.log(`sans pays ${IDS.size} ; candidats Wikidata à deux signaux (un seul par fiche) ${retenus.length} ; propositions ${propositions.length} (dont LC lieu de naissance ${lcRetenus.length}) ; refus ${refus.length}`);
console.log('par règle :', parRegle);
for (const p of propositions.slice(0, 60)) console.log(` ${p.id} ${p.nom} → ${p.pays} [${p.source} ${p.q} ${p.libelle} ${p.naissance}-${p.mort}] ${p.sig}${p.autres ? ' | autres : ' + p.autres.slice(0, 80) : ''}`);
