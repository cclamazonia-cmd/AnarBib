#!/usr/bin/env node
// scripts/noms-propres-attestes.mjs — C6, casse des titres (spec conventions §4.1).
//
// Engendre src/lib/nomsPropres.js : les mots qu'une mise en casse de phrase
// ne doit PAS abaisser, parce que le catalogue lui-même les traite en noms
// propres. Trois sources, toutes publiques :
//   1. le catalogue — dans les titres DÉJÀ en casse de phrase (au moins deux mots
//      pleins en minuscules, et les deux tiers d'entre eux), les mots écrits avec
//      une majuscule hors début et hors nom qui suit l'article initial : c'est le
//      choix des catalogueur·ses ;
//   2. les patronymes des autorités de type personne (avant la virgule) ;
//   3. (et 4., plus bas) les collectivités de la base, en phrases ;
//   3. les noms de pays (i18n-iso-countries : pt, es, fr, it, en, ca, de, nl, el) ; ceux de plusieurs
//      mots vont dans `phrases` (« estados unidos »).
// Un mot vu en minuscules en milieu de titre au moins aussi souvent qu'avec une
// majuscule dans un titre en casse de phrase est ÉCARTÉ : c'est aussi un mot
// commun (« paz », « argentina » adjectif, « social ») ; de même tout mot des
// sources 1 et 2 présent en minuscules dans nos dix fichiers de langue (le
// lexique gratuit du dépôt : « guerra », « campos », « estado »). Les pays restent.
// Clés : minuscules sans accents. Sortie triée : deux passes sur les mêmes
// données rendent le même fichier.
//
// Usage : node scripts/noms-propres-attestes.mjs   (lit l'API publique, clé publiable)
// Puis : une migration qui recopie les deux listes dans la fonction SQL miroir
// (voir src/tests/title-case.test.js, garde « dictionnaire SQL = JSON »).

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const RACINE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(path.join(RACINE, 'package.json'));
const URL_API = 'https://uflwmikiyjfnikiphtcp.supabase.co/rest/v1/';
const CLE_PUBLIABLE = 'sb_publishable_KJBytsICkVClr8iG26b0CQ_BxsVQooZ';

const { stopwordsFor } = await import(path.join(RACINE, 'src/lib/titleCase.js').replace(/\\/g, '/').replace(/^([A-Za-z]):/, 'file:///$1:'));
const { PARTICULES } = await import(path.join(RACINE, 'src/lib/nameEntry.js').replace(/\\/g, '/').replace(/^([A-Za-z]):/, 'file:///$1:'));

async function tout(table, select) {
  const out = [];
  for (let de = 0; ; de += 1000) {
    const r = await fetch(`${URL_API}${table}?select=${select}&order=id`, { headers: { apikey: CLE_PUBLIABLE, Range: `${de}-${de + 999}` } });
    if (!r.ok) throw new Error(`${table} : ${r.status} ${await r.text()}`);
    const rows = await r.json(); out.push(...rows); if (rows.length < 1000) break;
  }
  return out;
}

export const cleNom = (w) => w.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
const nu = (w) => w.replace(/^[^\p{L}]+|[^\p{L}]+$/gu, '');
const OUTILS = new Set(['pt', 'es', 'fr', 'it', 'en', 'ca', 'eo', 'de'].flatMap((l) => [...stopwordsFor(l)]).map(cleNom));
const frontiere = (w) => /[:;?!.]$/.test(w) || ['-', '–', '—'].includes(w);
const ARTICLES = new Set(['le', 'la', 'les', 'l', 'el', 'los', 'las', 'o', 'a', 'os', 'as', 'il', 'lo', 'gli', 'i',
  'the', 'der', 'die', 'das', 'de', 'het', 'un', 'une', 'uno', 'una', 'um', 'uma']);
// Lexique des mots communs : les mots en minuscules de nos dix fichiers de langue.
// Un patronyme qui y figure (« Guerra », « Campos ») est aussi un nom commun.
const LEXIQUE = new Set();
for (const f of fs.readdirSync(path.join(RACINE, 'src/i18n/locales'))) {
  const j = JSON.parse(fs.readFileSync(path.join(RACINE, 'src/i18n/locales', f), 'utf8'));
  for (const v of Object.values(j)) for (const m of String(v).split(/[^\p{L}]+/u)) if (/^\p{Ll}/u.test(m)) LEXIQUE.add(cleNom(m));
}

const books = await tout('books', 'id,titulo,subtitulo');
const authors = await tout('authors', 'id,sort_name,preferred_name,authority_type');

const maj = new Map(), min = new Map(), source = new Map();
const inc = (m, k) => m.set(k, (m.get(k) || 0) + 1);
for (const b of books) for (const t of [b.titulo, b.subtitulo]) {
  if (!t) continue;
  const w = t.split(/\s+/).filter(Boolean);
  // Mots pleins hors tête : pas le premier, pas après une ponctuation forte, pas
  // un mot-outil, et pas le nom qui suit l'article initial (la typographie
  // française met « Le Mouvement anarchiste » : ce n'est pas un nom propre).
  const pleins = w.map((x, i) => i).filter((i) => i > 0 && !frontiere(w[i - 1])
    && !(i === 1 && ARTICLES.has(cleNom(nu(w[0]))))
    && nu(w[i]).length >= 3 && !OUTILS.has(cleNom(nu(w[i]))));
  const enMinuscules = pleins.filter((i) => /^\p{Ll}+$/u.test(nu(w[i]))).length;
  // Casse de phrase avérée : au moins deux mots pleins en minuscules, et les deux tiers.
  const enPhrase = enMinuscules >= 2 && enMinuscules * 3 >= pleins.length * 2;
  for (const i of pleins) {
    const n = nu(w[i]);
    if (/^\p{Ll}+$/u.test(n)) inc(min, cleNom(n));
    else if (enPhrase && /^\p{Lu}\p{Ll}+$/u.test(n)) inc(maj, cleNom(n));
  }
}
for (const [k] of maj) source.set(k, 'catalogue');
for (const a of authors) {
  if (a.authority_type !== 'person' || !a.sort_name?.includes(',')) continue;
  for (const x of a.sort_name.split(',')[0].split(/[\s-]+/)) {
    const n = nu(x);
    if (n.length < 3 || !/^\p{Lu}/u.test(n) || PARTICULES.has(cleNom(n)) || OUTILS.has(cleNom(n))) continue;
    if (!source.has(cleNom(n))) source.set(cleNom(n), 'autorite');
  }
}
const pays = require('i18n-iso-countries');
const phrases = new Set();
// 4. les collectivités : leur nom est un nom propre (« Confederación Nacional del
//    Trabajo ») — en phrase, pour ne pas mettre une majuscule à « nacional » partout.
for (const a of authors) {
  if (!['collective', 'congress'].includes(a.authority_type) || !a.preferred_name) continue;
  const w = a.preferred_name.replace(/\([^)]*\)/g, ' ').split(/[\s,;:/–—-]+/).map(nu).filter(Boolean);
  if (w.length >= 2 && w.length <= 8) phrases.add(w.map(cleNom).join(' '));
}
for (const l of ['pt', 'es', 'fr', 'it', 'en', 'ca', 'de', 'nl', 'el']) {   // pas d'espéranto dans i18n-iso-countries
  pays.registerLocale(require(`i18n-iso-countries/langs/${l}.json`));
  for (const nom of Object.values(pays.getNames(l))) {
    const w = nom.replace(/[(),]/g, ' ').split(/\s+/).filter(Boolean);
    if (w.length === 1) { if (!source.has(cleNom(w[0]))) source.set(cleNom(w[0]), 'pays'); }
    else phrases.add(w.map(cleNom).join(' '));
  }
}
const garde = (k) => (source.get(k) === 'pays' || !LEXIQUE.has(k))
  && (!min.has(k) || (maj.get(k) || 0) > min.get(k));
const mots = [...source.keys()].filter(garde).sort();
const lesPhrases = [...phrases].sort();
const liste = (a) => '[\n' + a.map((x) => '  ' + JSON.stringify(x) + ',').join('\n') + '\n]';
fs.writeFileSync(path.join(RACINE, 'src/lib/nomsPropres.js'),
  '// src/lib/nomsPropres.js — ENGENDRÉ par scripts/noms-propres-attestes.mjs, ne pas éditer à la main.\n'
  + '// Noms propres attestés (clés : minuscules sans accents) : la casse de phrase ne les abaisse pas.\n'
  + '// Recopié dans la fonction SQL miroir private.conv_noms_propres() ; garde de parité : src/tests/title-case.test.js.\n'
  + `export const NOMS_PROPRES_MOTS = ${liste(mots)};\n\nexport const NOMS_PROPRES_PHRASES = ${liste(lesPhrases)};\n`);
console.log(`nomsPropres.js : ${mots.length} mots, ${lesPhrases.length} phrases (notices ${books.length}, autorités ${authors.length})`);
