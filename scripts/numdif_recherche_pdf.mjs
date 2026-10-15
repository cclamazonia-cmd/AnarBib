#!/usr/bin/env node
// ===========================================================================
// numdif_recherche_pdf.mjs — chercher les PDF d'une notice et lire l'édition
// réelle sur la page de titre (backlog v34 D14, REGISTRE §47 NUMDIF-1, 2, 5)
// ---------------------------------------------------------------------------
// Auteur  : Claude (assistant·e), pour la coordination
// Session : File de candidats PDF
// Date    : 2026-10-15
//
// CE QUE FAIT LE SCRIPT, lancé à la main, notice par notice :
//   1. lit la notice au catalogue public (clé publiable, rien de plus) ;
//   2. cherche sur Archive.org (API advancedsearch puis metadata) et EXCLUT le
//      prêt contrôlé : item `access-restricted-item`, fichier `private` — ces
//      éditions sont signalées dans le rapport, jamais téléchargées ;
//      ou prend une URL donnée à la main (--url, --urls) ;
//   3. télécharge le PDF, calcule SHA-256 et taille ;
//   4. lit les premières et les dernières pages (`pdftotext`) : page de titre,
//      copyright, achevé d'imprimer ;
//   5. PROPOSE un verdict (NUMDIF-1 : meme_edition, autre_edition,
//      texte_ressaisi) et un cas de source (NUMDIF-2 : diffusion_autorisee,
//      anti_copyright, statut_inconnu ; domaine_public hors NUMDIF-2), avec
//      l'édition constatée et la mention trouvée ;
//   6. écrit les candidats dans un fichier JSON — que la coordination charge
//      dans la file depuis la page Importations (D15) — ou, avec --submit et
//      le jeton de session d'une coordination, directement dans la file
//      (RPC fn_digital_candidates_propose, D13).
//
// CE QUE LE SCRIPT NE FAIT PAS
//   - Il ne décide rien : la concordance d'édition se valide PDF ouvert, par
//     la coordination de la bibliothèque détentrice (NUMDIF-5). Les
//     métadonnées des sources ne prouvent rien ; seul le texte du PDF compte.
//   - Il ne contourne AUCUNE protection : une réponse Cloudflare, un CAPTCHA,
//     un 401/403/429 arrêtent la source et se disent dans le rapport.
//   - Il ne manipule aucune clé de service : la lecture du catalogue se fait
//     avec la clé publiable ; l'écriture dans la file, par la coordination.
//
// PRÉREQUIS : Node 20+, `pdftotext` (poppler-utils ou xpdf) dans le PATH ;
//   `pdfinfo` facultatif (nombre de pages). Sous WSL :
//   sudo apt install poppler-utils. Sous Windows, Git for Windows fournit
//   pdftotext (ucrt64).
//
// USAGE
//   node scripts/numdif_recherche_pdf.mjs --books 86,96
//   node scripts/numdif_recherche_pdf.mjs --author "gu_rin, daniel"   (motif ilike ; _ = une lettre)
//   node scripts/numdif_recherche_pdf.mjs --book 2195 --url https://… [--page-url https://…] [--source-name …]
//   node scripts/numdif_recherche_pdf.mjs --urls candidats-a-la-main.json   ([{book_id, file_url, page_url?, source_name?}])
//   Options : --library <uuid> (sinon : la détentrice unique de chaque notice)
//             --out <fichier.json> (défaut : numdif-candidats-<date>.json dans le dossier courant)
//             --dl-dir <dossier> (défaut : <tmp>/anarbib-numdif) · --max-per-book 3 · --max-mb 300
//             --no-archive (ne prend que les URL données) · --submit (ANARBIB_ACCESS_TOKEN requis)
//   Configuration : VITE_SUPABASE_URL et VITE_SUPABASE_PUBLISHABLE_KEY (ou
//   VITE_SUPABASE_ANON_KEY), lues dans l'environnement ou dans .env.local/.env.
// ===========================================================================

import { createWriteStream, existsSync, mkdirSync, readFileSync, statSync, writeFileSync, createReadStream,
  openSync, readSync, closeSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

const VERSION = '1.0.0';
const ICI = dirname(fileURLToPath(import.meta.url));
const RACINE = resolve(ICI, '..');
const UA = `AnarBib-NUMDIF/${VERSION} (recherche manuelle d'une bibliotheque; +https://anarbib.org)`;
const ANNEE = new Date().getFullYear();

// ── arguments ───────────────────────────────────────────────────────────
function lireArgs(argv) {
  const a = { books: [], urls: [], maxPerBook: 3, maxMb: 300, archive: true, submit: false };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    const v = () => { const x = argv[++i]; if (x === undefined) throw new Error(`valeur manquante pour ${k}`); return x; };
    if (k === '--books' || k === '--book') a.books.push(...v().split(',').map((s) => Number(s.trim())).filter(Boolean));
    else if (k === '--author') a.author = v();
    else if (k === '--library') a.library = v();
    else if (k === '--url') a.urls.push({ file_url: v() });
    else if (k === '--page-url') { if (!a.urls.length) throw new Error('--page-url suit un --url'); a.urls.at(-1).page_url = v(); }
    else if (k === '--source-name') { if (!a.urls.length) throw new Error('--source-name suit un --url'); a.urls.at(-1).source_name = v(); }
    else if (k === '--urls') a.urlsFile = v();
    else if (k === '--out') a.out = v();
    else if (k === '--dl-dir') a.dlDir = v();
    else if (k === '--max-per-book') a.maxPerBook = Number(v());
    else if (k === '--max-mb') a.maxMb = Number(v());
    else if (k === '--no-archive') a.archive = false;
    else if (k === '--submit') a.submit = true;
    else if (k === '-h' || k === '--help') a.help = true;
    else throw new Error(`argument inconnu : ${k}`);
  }
  return a;
}

function chargerEnvLocal() {
  for (const nom of ['.env.local', '.env']) {
    const chemin = resolve(RACINE, nom);
    if (!existsSync(chemin)) continue;
    for (const ligne of readFileSync(chemin, 'utf8').split(/\r?\n/)) {
      const m = ligne.match(/^\s*(VITE_SUPABASE_URL|VITE_SUPABASE_PUBLISHABLE_KEY|VITE_SUPABASE_ANON_KEY)\s*=\s*(.*)$/);
      if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
    }
  }
}

// ── texte : normaliser, comparer ──────────────────────────────────────
export const norm = (s) => String(s ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '')
  .toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
const squash = (s) => norm(s).replace(/ /g, '');
const MOTS_VIDES = new Set(('a an and the of de del della di da do dos das du des la le les el los las lo y e et und der die das '
  + 'en in im au aux con com por para pour sur sobre').split(' '));
const MOTS_EDITEUR = new Set(('editorial editoriales ediciones edicions edicoes editions edition edizioni editora editoras '
  + 'editores editeur editeurs editrice publisher publishers publishing press verlag libros livros libri books ltd inc '
  + 'company compania cia sa sl ltda co sons brothers bros comunidad biblioteca coleccion collection').split(' '));
const jetons = (s, { editeur = false } = {}) => norm(s).split(' ')
  .filter((w) => w.length >= 3 && !MOTS_VIDES.has(w) && !(editeur && MOTS_EDITEUR.has(w)));
const alternatives = (s) => String(s ?? '').split(/\s*[/;|]\s*/).map((x) => x.trim()).filter(Boolean);
const contientJeton = (texteSquash, texteMots, j) => (j.length >= 4 ? texteSquash.includes(j) : texteMots.has(j));

// Une alternative (« Altamira / Nordan » : l'une ou l'autre) est trouvée quand
// tous ses mots significatifs le sont.
function trouveDans(texte, champ, opts) {
  const sq = squash(texte);
  const mots = new Set(norm(texte).split(' '));
  for (const alt of alternatives(champ)) {
    const js = jetons(alt, opts);
    if (js.length && js.every((j) => contientJeton(sq, mots, j))) return alt;
  }
  return null;
}
export const annees = (s) => [...String(s ?? '').matchAll(/(?<![0-9])(1[5-9][0-9]{2}|20[0-9]{2})(?![0-9])/g)]
  .map((m) => Number(m[1])).filter((y) => y <= ANNEE);
const isbnNorm = (s) => String(s ?? '').replace(/[^0-9Xx]/g, '').toUpperCase();
function isbnsDuTexte(t) {
  return [...String(t).matchAll(/I\s?S\s?B\s?N[\s:.\-–]*((?:97[89][\s\-–]?)?[0-9][0-9\s\-–]{7,15}[0-9Xx])/g)]
    .map((m) => isbnNorm(m[1])).filter((x) => x.length === 10 || x.length === 13);
}
// ISBN-10 et ISBN-13 d'un même livre se reconnaissent par leurs neuf chiffres centraux.
const memeIsbn = (a, b) => {
  const c = (x) => (x.length === 13 ? x.slice(3, 12) : x.slice(0, 9));
  return a && b && c(a) === c(b);
};

// ── lecture du PDF ──────────────────────────────────────────────────────
function outil(nom) {
  const r = spawnSync(nom, ['-v'], { encoding: 'utf8' });
  return !r.error;
}
function pdftotext(fichier, premiere, derniere) {
  const r = spawnSync('pdftotext', ['-f', String(premiere), '-l', String(derniere), '-enc', 'UTF-8', '-layout', fichier, '-'],
    { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (r.error) throw r.error;
  // une page par saut de page ; le dernier élément est vide
  return (r.stdout || '').split('\f').slice(0, Math.max(0, derniere - premiere + 1));
}
function infosPdf(fichier) {
  if (outil('pdfinfo')) {
    const r = spawnSync('pdfinfo', [fichier], { encoding: 'utf8' });
    const champ = (k) => (r.stdout?.match(new RegExp(`^${k}:\\s*(.*)$`, 'm')) || [])[1]?.trim() || null;
    const pages = Number(champ('Pages')) || null;
    return { pages, producer: champ('Producer'), creator: champ('Creator') };
  }
  // Sans pdfinfo (xpdf de Git for Windows) : le compte de l'arbre de pages et
  // les champs /Producer, /Creator quand ils ne sont pas compressés.
  const buf = readFileSync(fichier, 'latin1');
  const counts = [...buf.matchAll(/\/Type\s*\/Pages\b[^>]*?\/Count\s+(\d+)/g)].map((m) => Number(m[1]));
  const counts2 = [...buf.matchAll(/\/Count\s+(\d+)[^>]*?\/Type\s*\/Pages\b/g)].map((m) => Number(m[1]));
  const pages = Math.max(0, ...counts, ...counts2) || null;
  const lit = (k) => (buf.match(new RegExp(`/${k}\\s*\\(([^)]{1,200})\\)`)) || [])[1] || null;
  return { pages, producer: lit('Producer'), creator: lit('Creator') };
}

// ── proposer : édition constatée, verdict, cas ──────────────────────────
// bornes de lettre, pas \b : « Expeditions » n'est pas « editions »
const RE_EDITEUR = /(?<!\p{L})(editorial|ediciones|edicions|edições|edicoes|éditions|editions|edizioni|editora|editores|verlag|press|publishers?|libros|livros|books|imprenta|tipograf\p{L}*|librairie|libreria|typographie)(?!\p{L})/iu;
const RE_IMPRESSUM = /(©|\(c\)|copyright|isbn|impreso|imprimé|imprime|achevé|acheve|dep[oó]sito legal|printed|edici[oó]n|édition|edition|edição|primera|première|first published|hecho el dep)/i;
// Pour la concordance, seules les lignes d'impressum caractérisées comptent :
// « the first French edition appeared in 1873 », dans une préface, n'en est pas une.
const RE_IMPRESSUM_STRICT = /(©|\(c\)\s*[0-9]|copyright|isbn|impreso en|impr[ie]m[ée] en|achev[ée] d.imprimer|dep[oó]sito legal|printed in|first published|primera edici[oó]n|premi[eè]re [ée]dition|edi[cç][iaã]o\s*:|[ée]dici[oó]n\s*:|[ée]dition\s*:|hecho el dep[oó]sito)/i;
const RE_TRAD =/(traducci[oó]n|traduction|traduit|translated|tradução|traduzione|übersetz|traducido|traducción de|versión castellana|version française)[^\n]{0,90}/i;
// NUMDIF-2 : les mentions imprimées dans l'édition
const RE_LIBRE = [
  /(reproducci[oó]n|reproduction|reprodução|riproduzione|difusi[oó]n|copia)[^\n]{0,160}(permitid|autorizad|alentad|libre|liberad|encouraged|permitted|allowed|autoris|livre|consentit)/i,
  /(anti[\s-]?copyright|copyleft|sin copyright|sans copyright|no copyright|reproduction libre|reproducci[oó]n libre|libre reproducci[oó]n|creative commons|licencia libre|licence libre|domaine public|dominio p[uú]blico)/i,
];
const RE_EDITEUR_MENTION = /(editor|éditeur|editeur|publisher|editora|edici|edit)/i;
const RE_NE_DIT_RIEN = /(prohibida|interdite|all rights reserved|todos los derechos reservados|tous droits réservés|tous droits de reproduction|reservados todos)/i;

function phraseAutour(texte, index, longueur) {
  const debut = Math.max(0, texte.lastIndexOf('\n', Math.max(0, index - 1)) + 1, index - 220);
  let fin = texte.indexOf('\n\n', index + longueur);
  if (fin < 0 || fin - index > 400) fin = Math.min(texte.length, index + longueur + 260);
  return texte.slice(debut, fin).replace(/\s+/g, ' ').trim();
}

// Ce que le numériseur ajoute n'est pas l'édition : l'avertissement de Google
// Books (une page entière), les mentions « Digitized by… ».
const RE_PAGE_NUMERISEUR = /(this is a digital copy of a book that was preserved|usage guidelines\s+google is proud|ceci est une copie num[ée]rique d.un ouvrage conserv)/i;
const RE_LIGNE_NUMERISEUR = /(digiti[sz]ed by|google|internet archive|archive\.org|microsoft corporation|university of toronto|library of congress)/i;
export const nettoyerPage = (t) => (RE_PAGE_NUMERISEUR.test(t) ? ''
  : String(t).split('\n').filter((l) => !RE_LIGNE_NUMERISEUR.test(l)).join('\n'));

export function proposer(notice, pagesBrutes, { premierePage = 1, dernieresPages = [], infos = {}, auteurs = [] } = {}) {
  const notes = { outil: 'numdif_recherche_pdf', version: VERSION, controles: {}, avertissements: [] };
  const pages = pagesBrutes.map(nettoyerPage);
  dernieresPages = dernieresPages.map((p) => ({ ...p, t: nettoyerPage(p.t) }));
  const toutes = [...pages.map((t, i) => ({ n: premierePage + i, t })), ...dernieresPages];
  const texteDebut = pages.join('\n');
  const caracteres = texteDebut.replace(/\s/g, '').length;
  const res = { found: {}, title_page_number: null, title_page_text: null, proposed_verdict: null,
    proposed_case: null, proposed_mention: null, proposed_mention_page: null, tool_notes: notes };

  // la page de titre : celle des premières qui porte le plus de mots du titre
  const motsTitre = jetons(notice.titulo);
  let meilleure = -1, score = -1;
  pages.forEach((t, i) => {
    const sq = squash(t); const mots = new Set(norm(t).split(' '));
    const s = motsTitre.filter((j) => contientJeton(sq, mots, j)).length
      + (trouveDans(t, notice.editora, { editeur: true }) ? 2 : 0);
    if (s > score) { score = s; meilleure = i; }
  });
  if (meilleure >= 0 && score > 0) res.title_page_number = premierePage + meilleure;
  const bornes = [Math.max(0, (meilleure >= 0 ? meilleure : 0) - 1), Math.min(pages.length, (meilleure >= 0 ? meilleure : 0) + 3)];
  res.title_page_text = pages.slice(bornes[0], bornes[1])
    .map((t, i) => `— p. ${premierePage + bornes[0] + i} —\n${t.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim()}`)
    .join('\n\n').slice(0, 8000) || null;

  if (caracteres < 200) {
    notes.avertissements.push('sans_couche_texte');
    return res;
  }

  // l'édition : éditeur, lieu, année, traduction, ISBN — lus dans le PDF, sur
  // la page de titre et son verso, plus les lignes d'impressum (copyright,
  // achevé d'imprimer, dépôt légal) des premières pages : un « Harper » ou un
  // « 1873 » cité dans une préface ne fait pas l'édition.
  const lignesImp = [texteDebut, ...dernieresPages.map((p) => p.t)].join('\n').split('\n')
    .filter((l) => RE_IMPRESSUM_STRICT.test(l));
  const zone = [pages[Math.max(0, meilleure)] || '', ...lignesImp].join('\n');
  const editeur = trouveDans(zone, notice.editora, { editeur: true });
  const lieu = trouveDans(zone, notice.local_publicacao);
  const anneesNotice = annees(notice.ano);
  const anneesPdf = annees(zone);
  const anneeOk = anneesNotice.length > 0 && anneesNotice.some((y) => anneesPdf.includes(y));
  const tradNotice = notice.tradutor ? jetons(notice.tradutor).filter((j) => j.length >= 4) : [];
  const tradOk = !tradNotice.length || tradNotice.some((j) => squash(texteDebut).includes(j));
  const isbnsPdf = isbnsDuTexte(texteDebut);
  const isbnNotice = isbnNorm(notice.isbn);
  const isbnConflit = Boolean(isbnNotice && isbnsPdf.length && !isbnsPdf.some((x) => memeIsbn(x, isbnNotice)));
  const isbnOk = Boolean(isbnNotice && isbnsPdf.some((x) => memeIsbn(x, isbnNotice)));
  const titreOk = motsTitre.length > 0 && score >= Math.ceil(motsTitre.length / 2);
  notes.controles = { titre: titreOk, editeur: Boolean(editeur), lieu: notice.local_publicacao ? Boolean(lieu) : null,
    annee: anneesNotice.length ? anneeOk : null, traduction: notice.tradutor ? tradOk : null,
    isbn: isbnNotice && isbnsPdf.length ? isbnOk : null, caracteres };

  const lignes = texteDebut.split('\n').map((l) => l.replace(/\s+/g, ' ').trim()).filter(Boolean);
  const lignesZone = zone.split('\n').map((l) => l.replace(/\s+/g, ' ').trim()).filter(Boolean);
  // la ligne d'éditeur se cherche sur la page de titre et ses voisines, en
  // lignes courtes : « The press, that select tool… » d'un chapitre n'en est pas une
  const voisines = pages.slice(Math.max(0, meilleure - 1), Math.max(0, meilleure) + 2).join('\n')
    .split('\n').map((l) => l.replace(/\s+/g, ' ').trim()).filter((l) => l && l.length <= 80);
  const ligneEditeur = [...lignesZone.filter((l) => l.length <= 100), ...voisines].find((l) => RE_EDITEUR.test(l));
  const lignesImpressum = lignes.filter((l) => RE_IMPRESSUM.test(l));
  const anneesImpressum = annees(lignesImpressum.join(' '));
  const frequente = (xs) => xs.sort((a, b) => xs.filter((y) => y === b).length - xs.filter((y) => y === a).length)[0];
  res.found = {
    found_title: lignes.find((l) => motsTitre.some((j) => squash(l).includes(j)))?.slice(0, 300) || null,
    found_publisher: editeur || ligneEditeur?.slice(0, 200) || null,
    found_place: lieu || null,
    found_year: anneeOk ? String(anneesNotice.find((y) => anneesPdf.includes(y)))
      : (anneesImpressum.length ? String(Math.max(...anneesImpressum)) : (anneesPdf.length ? String(frequente([...anneesPdf])) : null)),
    found_translator: (texteDebut.match(RE_TRAD) || [])[0]?.replace(/\s+/g, ' ').trim().slice(0, 200) || null,
    found_isbn: isbnsPdf[0] || null,
  };

  // NUMDIF-1 — le verdict proposé
  const neNeDitPasEditeur = !ligneEditeur && !editeur;
  const nativementNumerique = /(word|writer|libreoffice|openoffice|pages|google docs|latex|pdftex|xetex|luatex|calibre|prince|wkhtmltopdf|indesign|quark|scribus)/i
    .test(`${infos.producer || ''} ${infos.creator || ''}`);
  if (isbnConflit) {
    res.proposed_verdict = 'autre_edition';
    notes.avertissements.push('isbn_different');
  } else if (titreOk && editeur && anneeOk && (!notice.local_publicacao || lieu) && tradOk) {
    res.proposed_verdict = 'meme_edition';
  } else if (neNeDitPasEditeur && nativementNumerique) {
    res.proposed_verdict = 'texte_ressaisi';
  } else {
    res.proposed_verdict = 'autre_edition';
  }
  if (!titreOk) notes.avertissements.push('titre_peu_trouve');
  if (res.proposed_verdict === 'meme_edition' && !notice.local_publicacao) notes.avertissements.push('lieu_absent_de_la_notice');

  // NUMDIF-2 — le cas proposé, et la mention avec sa page
  for (const { n, t } of toutes) {
    for (const re of RE_LIBRE) {
      const m = re.exec(t);
      if (!m) continue;
      const phrase = phraseAutour(t, m.index, m[0].length);
      if (RE_NE_DIT_RIEN.test(phrase) && !/copyleft|anti/i.test(phrase)) continue;
      res.proposed_mention = phrase.slice(0, 600);
      res.proposed_mention_page = String(n);
      res.proposed_case = RE_EDITEUR_MENTION.test(phrase) && re === RE_LIBRE[0] ? 'diffusion_autorisee' : 'anti_copyright';
      break;
    }
    if (res.proposed_case) break;
  }
  if (!res.proposed_case) {
    const deces = auteurs.map((x) => x.death_year).filter((y) => Number.isFinite(Number(y)) && y !== null).map(Number);
    if (auteurs.length && deces.length === auteurs.length && Math.max(...deces) + 70 < ANNEE) {
      res.proposed_case = 'domaine_public';
      notes.deces = auteurs.map((x) => `${x.name} (†${x.death_year})`);
      if (notice.tradutor) notes.avertissements.push('traduction_a_verifier');
    } else {
      // le doute tranche vers (c)
      res.proposed_case = 'statut_inconnu';
    }
  }
  return res;
}

// ── réseau : lecture polie, sans contournement ────────────────────────────
const attendre = (ms) => new Promise((r) => setTimeout(r, ms));
class Protection extends Error {}
async function obtenir(url, opts = {}) {
  let r;
  // Une reprise, une seule, sur une coupure réseau (vu le 15/10 sur un miroir
  // dnXXXX d'Archive.org) — jamais sur un refus.
  for (let essai = 0; ; essai++) {
    try {
      r = await fetch(url, { ...opts, headers: { 'User-Agent': UA, ...(opts.headers || {}) }, redirect: 'follow' });
      break;
    } catch (e) {
      if (essai >= 1) throw e;
      await attendre(3000);
    }
  }
  const cf = r.headers.get('cf-mitigated') || (r.headers.get('server') || '').toLowerCase().includes('cloudflare');
  if ([401, 403, 429, 503].includes(r.status) || (cf && r.status >= 400)) {
    throw new Protection(`${r.status} ${cf ? '(Cloudflare) ' : ''}— source fermée aux automates : à consulter à la main`);
  }
  if (!r.ok) throw new Error(`HTTP ${r.status} sur ${url}`);
  return r;
}
const json = async (url, opts) => (await obtenir(url, opts)).json();

async function lireNotices(cfg, args) {
  const select = 'id,titulo,subtitulo,autor,editora,local_publicacao,ano,edicao,tradutor,isbn,idioma,bib_ref,'
    + 'book_holdings(library_id),book_authors(role,authors(preferred_name,death_year))';
  const h = { apikey: cfg.key, Authorization: `Bearer ${cfg.key}` };
  const parties = [];
  if (args.books.length) parties.push(`id=in.(${[...new Set(args.books)].join(',')})`);
  if (args.author) parties.push(`autor=ilike.*${encodeURIComponent(args.author)}*`);
  if (!parties.length) return [];
  const out = [];
  for (const p of parties) {
    out.push(...await json(`${cfg.url}/rest/v1/books?select=${select}&${p}&order=id`, { headers: h }));
  }
  const vus = new Set();
  return out.filter((b) => !vus.has(b.id) && vus.add(b.id));
}

function requeteArchive(notice) {
  const mots = jetons(notice.titulo).sort((a, b) => b.length - a.length).slice(0, 4);
  const nom = jetons(String(notice.autor || '').split(',')[0])[0];
  const titre = mots.map((w) => `title:(${w})`).join(' AND ');
  const an = annees(notice.ano)[0];
  const avec = nom ? `${titre} AND creator:(${nom}) AND mediatype:(texts)` : null;
  return {
    // l'année de la notice d'abord : un titre court (« The Earth ») rend des
    // centaines de volumes voisins, et la bonne édition passe au-delà des 50
    annee: an ? `${avec || `${titre} AND mediatype:(texts)`} AND year:(${an})` : null,
    avec, sans: `${titre} AND mediatype:(texts)`,
  };
}
// Les métadonnées de la source ne PROUVENT rien (NUMDIF-1) ; elles servent
// seulement à choisir quels fichiers télécharger d'abord : année et éditeur de
// la notice en tête.
export function classerResultats(notice, docs) {
  const ans = annees(notice.ano);
  const motsTitre = jetons(notice.titulo);
  const score = (d) => {
    const t = [].concat(d.title || []).join(' ');
    const p = [].concat(d.publisher || []).join(' ');
    const y = annees([].concat(d.date || []).join(' '));
    return (ans.length && y.some((x) => ans.includes(x)) ? 3 : 0)
      + (notice.editora && trouveDans(p, notice.editora, { editeur: true }) ? 2 : 0)
      + (motsTitre.length && motsTitre.every((j) => squash(t).includes(j)) ? 1 : 0);
  };
  return docs.map((d, i) => ({ d, s: score(d), i })).sort((a, b) => b.s - a.s || a.i - b.i).map((x) => x.d);
}
export function pertinentSansAuteur(notice, doc) {
  const nom = jetons(String(notice.autor || '').split(',')[0])[0];
  const createurs = [].concat(doc.creator || []).join(' ');
  const titre = [].concat(doc.title || []).join(' ');
  const motsTitre = jetons(notice.titulo);
  if (!motsTitre.length || !motsTitre.every((j) => squash(titre).includes(j))) return false;
  if (createurs) return !nom || squash(createurs).includes(nom);
  // Sans créateur aux métadonnées : le titre nomme l'auteur, ou il ne porte
  // qu'un mot de plus que la notice (« Anarquismo y revolución en Rusia… —
  // Carlos Taibo » n'est pas « El anarquismo »).
  if (nom && squash(titre).includes(nom)) return true;
  const enTrop = jetons(titre).filter((j) => !/^[0-9]+$/.test(j) && !motsTitre.some((m) => j.includes(m) || m.includes(j)));
  return enTrop.length <= 1;
}
async function chercherArchive(notice, rapport) {
  const { annee, avec, sans } = requeteArchive(notice);
  const fl = ['identifier', 'title', 'creator', 'date', 'publisher', 'language'].map((f) => `fl[]=${f}`).join('&');
  const trouves = [];
  const vus = new Set();
  for (const q of [annee, avec, sans].filter(Boolean)) {
    // la requête sans auteur ne sert que si les autres n'ont rien rendu
    if (q === sans && trouves.length) break;
    const d = await json(`https://archive.org/advancedsearch.php?q=${encodeURIComponent(q)}&${fl}&rows=50&page=1&output=json`);
    await attendre(600);
    const docs = d?.response?.docs || [];
    rapport.requetes.push({ q, n: docs.length });
    for (const x of docs) {
      if (vus.has(x.identifier)) continue;
      // Sans l'auteur dans la requête, un titre court (« Lenin ») ramène
      // n'importe quel livre : on ne garde que ceux dont les métadonnées ne
      // nomment pas un autre auteur et portent tout le titre.
      if (q === sans && !pertinentSansAuteur(notice, x)) { rapport.ecartes = (rapport.ecartes || 0) + 1; continue; }
      vus.add(x.identifier); trouves.push(x);
    }
  }
  return classerResultats(notice, trouves);
}
const PRIORITE_FORMAT = ['Text PDF', 'Additional Text PDF', 'PDF', 'Image Container PDF'];
async function fichiersArchive(id, rapport) {
  const m = await json(`https://archive.org/metadata/${encodeURIComponent(id)}`);
  await attendre(600);
  const meta = m?.metadata || {};
  const pdfs = (m?.files || []).filter((f) => /pdf/i.test(f.format || '') || /\.pdf$/i.test(f.name || ''));
  const publics = pdfs.filter((f) => String(f.private) !== 'true');
  if (String(meta['access-restricted-item']) === 'true' || (pdfs.length && !publics.length)) {
    rapport.pret_controle.push({ identifier: id, title: meta.title || null, publisher: meta.publisher || null, date: meta.date || null });
    return null;
  }
  if (!publics.length) return null;
  publics.sort((a, b) => {
    const pa = PRIORITE_FORMAT.indexOf(a.format); const pb = PRIORITE_FORMAT.indexOf(b.format);
    return (pa < 0 ? 99 : pa) - (pb < 0 ? 99 : pb);
  });
  const f = publics[0];
  return {
    file_url: `https://archive.org/download/${encodeURIComponent(id)}/${f.name.split('/').map(encodeURIComponent).join('/')}`,
    page_url: `https://archive.org/details/${encodeURIComponent(id)}`,
    source_name: 'Internet Archive', source_identifier: id, original_filename: basename(f.name),
    size: Number(f.size) || null, meta_source: { title: meta.title || null, publisher: meta.publisher || null, date: meta.date || null, language: meta.language || null },
  };
}

async function telecharger(url, dossier, nom, maxOctets) {
  mkdirSync(dossier, { recursive: true });
  const chemin = join(dossier, nom.replace(/[^\w.\-]+/g, '_').slice(0, 150) || 'candidat.pdf');
  const r = await obtenir(url);
  const longueur = Number(r.headers.get('content-length')) || null;
  if (longueur && longueur > maxOctets) throw new Error(`fichier trop lourd (${Math.round(longueur / 1e6)} Mo)`);
  if (existsSync(chemin) && longueur && statSync(chemin).size === longueur) {
    r.body?.cancel?.();
  } else {
    let lu = 0;
    const garde = new TransformStream({ transform(chunk, ctl) {
      lu += chunk.byteLength; if (lu > maxOctets) ctl.error(new Error('fichier trop lourd')); else ctl.enqueue(chunk);
    } });
    await pipeline(Readable.fromWeb(r.body.pipeThrough(garde)), createWriteStream(chemin));
  }
  const tete = Buffer.alloc(5);
  const fd = openSync(chemin, 'r'); readSync(fd, tete, 0, 5, 0); closeSync(fd);
  if (tete.toString('latin1') !== '%PDF-') throw new Error('la réponse n\'est pas un PDF (page HTML, protection ?)');
  const hash = createHash('sha256');
  await pipeline(createReadStream(chemin), hash);
  return { chemin, sha256: hash.digest('hex'), taille: statSync(chemin).size };
}

async function examiner(notice, source, args) {
  const nom = source.original_filename || decodeURIComponent(basename(new URL(source.file_url).pathname)) || 'candidat.pdf';
  let fichier;
  for (let essai = 0; ; essai++) {
    try {
      fichier = await telecharger(source.file_url, join(args.dlDir, String(notice.id)), nom, args.maxMb * 1e6);
      break;
    } catch (e) {
      // une coupure en cours de transfert se reprend une fois ; un refus, jamais
      if (essai >= 1 || e instanceof Protection || /trop lourd|n'est pas un PDF/.test(e.message)) throw e;
      await attendre(3000);
    }
  }
  const infos = infosPdf(fichier.chemin);
  const premieres = pdftotext(fichier.chemin, 1, Math.min(14, infos.pages || 14));
  let dernieres = [];
  if (infos.pages && infos.pages > 16) {
    dernieres = pdftotext(fichier.chemin, infos.pages - 2, infos.pages).map((t, i) => ({ n: infos.pages - 2 + i, t }));
  }
  const auteurs = (notice.book_authors || []).filter((x) => x.authors && (!x.role || /aut|autor|author/i.test(x.role)))
    .map((x) => ({ name: x.authors.preferred_name, death_year: x.authors.death_year }));
  const p = proposer(notice, premieres, { premierePage: 1, dernieresPages: dernieres, infos, auteurs });
  p.tool_notes.source = source.meta_source || null;
  p.tool_notes.pdf = { producer: infos.producer, creator: infos.creator };
  return {
    book_id: notice.id, library_id: source.library_id,
    file_url: source.file_url, page_url: source.page_url || null,
    source_name: source.source_name || new URL(source.file_url).hostname, source_identifier: source.source_identifier || null,
    ...p.found, found_language: source.meta_source?.language || null,
    title_page_text: p.title_page_text, title_page_number: p.title_page_number,
    proposed_verdict: p.proposed_verdict, proposed_case: p.proposed_case,
    proposed_mention: p.proposed_mention, proposed_mention_page: p.proposed_mention_page,
    tool_notes: p.tool_notes, sha256: fichier.sha256, file_size_bytes: fichier.taille,
    page_count: infos.pages, original_filename: basename(fichier.chemin),
  };
}

async function soumettre(cfg, candidats) {
  const jeton = process.env.ANARBIB_ACCESS_TOKEN;
  if (!jeton) throw new Error('--submit : ANARBIB_ACCESS_TOKEN (jeton de session d\'une coordination) absent');
  const parBib = new Map();
  for (const c of candidats) { if (!parBib.has(c.library_id)) parBib.set(c.library_id, []); parBib.get(c.library_id).push(c); }
  for (const [lib, liste] of parBib) {
    for (let i = 0; i < liste.length; i += 200) {
      const r = await fetch(`${cfg.url}/rest/v1/rpc/fn_digital_candidates_propose`, {
        method: 'POST',
        headers: { apikey: cfg.key, Authorization: `Bearer ${jeton}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_library_id: lib, p_candidates: liste.slice(i, i + 200) }),
      });
      const corps = await r.json().catch(() => null);
      if (!r.ok) throw new Error(`file (${lib}) : ${r.status} ${corps?.hint || corps?.message || ''}`);
      console.log(`file ${lib} : ${corps.created} créé(s), ${corps.refreshed} rafraîchi(s), ignorés ${JSON.stringify(corps.skipped)}`);
    }
  }
}

async function principal() {
  const args = lireArgs(process.argv.slice(2));
  if (args.help || (!args.books.length && !args.author && !args.urlsFile)) {
    console.log(readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').filter((l) => l.startsWith('//')).slice(0, 60).join('\n'));
    process.exit(args.help ? 0 : 2);
  }
  chargerEnvLocal();
  const cfg = {
    url: (process.env.VITE_SUPABASE_URL || '').replace(/\/+$/, ''),
    key: process.env.VITE_SUPABASE_PUBLISHABLE_KEY || process.env.VITE_SUPABASE_ANON_KEY || '',
  };
  if (!cfg.url || !cfg.key) throw new Error('VITE_SUPABASE_URL et VITE_SUPABASE_PUBLISHABLE_KEY requis (environnement ou .env.local)');
  if (!outil('pdftotext')) throw new Error('pdftotext introuvable : installer poppler-utils (sudo apt install poppler-utils)');
  args.dlDir = resolve(args.dlDir || join(tmpdir(), 'anarbib-numdif'));

  let aLaMain = [];
  if (args.urlsFile) aLaMain = JSON.parse(readFileSync(args.urlsFile, 'utf8'));
  if (args.urls.length) {
    if (args.books.length !== 1) throw new Error('--url demande exactement une notice (--book <id>)');
    aLaMain.push(...args.urls.map((u) => ({ ...u, book_id: args.books[0] })));
  }
  for (const u of aLaMain) if (u.book_id) args.books.push(Number(u.book_id));

  const notices = await lireNotices(cfg, args);
  if (!notices.length) throw new Error('aucune notice lue au catalogue');
  const candidats = [];
  const rapports = [];

  for (const notice of notices) {
    const libs = [...new Set((notice.book_holdings || []).map((h) => h.library_id))];
    const library_id = args.library || (libs.length === 1 ? libs[0] : null);
    const rapport = { book_id: notice.id, bib_ref: notice.bib_ref, titulo: notice.titulo, autor: notice.autor,
      edition: [notice.editora, notice.local_publicacao, notice.ano].filter(Boolean).join(', '),
      library_id, requetes: [], pret_controle: [], candidats: [], erreurs: [] };
    rapports.push(rapport);
    if (!library_id) rapport.erreurs.push(libs.length ? `plusieurs détentrices (${libs.join(', ')}) : préciser --library` : 'aucune détentrice');
    else if (args.library && !libs.includes(args.library)) rapport.erreurs.push('la bibliothèque donnée ne détient pas la notice');

    const sources = aLaMain.filter((u) => Number(u.book_id) === notice.id).map((u) => ({ ...u }));
    if (args.archive) {
      try {
        const docs = await chercherArchive(notice, rapport);
        for (const d of docs) {
          if (sources.filter((s) => s.source_name === 'Internet Archive').length >= args.maxPerBook) break;
          try {
            const f = await fichiersArchive(d.identifier, rapport);
            if (f) sources.push(f);
          } catch (e) { rapport.erreurs.push(`${d.identifier} : ${e.message}`); if (e instanceof Protection) break; }
        }
      } catch (e) { rapport.erreurs.push(`Archive.org : ${e.message}`); }
    }

    for (const s of sources) {
      s.library_id = library_id;
      try {
        if (s.size && s.size > args.maxMb * 1e6) { rapport.erreurs.push(`${s.file_url} : trop lourd (${Math.round(s.size / 1e6)} Mo)`); continue; }
        process.stderr.write(`  notice ${notice.id} : ${s.file_url}\n`);
        const c = await examiner(notice, s, args);
        candidats.push(c);
        rapport.candidats.push({ file_url: c.file_url, verdict: c.proposed_verdict, cas: c.proposed_case,
          edition_trouvee: [c.found_publisher, c.found_place, c.found_year].filter(Boolean).join(', '),
          controles: c.tool_notes.controles, avertissements: c.tool_notes.avertissements });
      } catch (e) { rapport.erreurs.push(`${s.file_url} : ${e.message}`); }
    }
  }

  const out = resolve(args.out || `numdif-candidats-${new Date().toISOString().slice(0, 10)}.json`);
  const proposables = candidats.filter((c) => c.library_id);
  writeFileSync(out, JSON.stringify({ tool: 'numdif_recherche_pdf', version: VERSION, generated_at: new Date().toISOString(),
    candidates: proposables, report: rapports }, null, 2) + '\n');

  console.log('\nnotice | édition au catalogue | candidat(s) : verdict proposé (cas) — édition trouvée');
  for (const r of rapports) {
    const lignes = r.candidats.map((c) => `${c.verdict || '?'} (${c.cas || '?'}) — ${c.edition_trouvee || '—'}`);
    if (r.pret_controle.length) lignes.push(`prêt contrôlé, non téléchargé : ${r.pret_controle.map((p) => p.identifier).join(', ')}`);
    if (r.erreurs.length) lignes.push(`erreurs : ${r.erreurs.join(' ; ')}`);
    console.log(`${r.book_id} ${r.titulo} | ${r.edition} | ${lignes.join(' · ') || 'aucun PDF librement téléchargeable trouvé'}`);
  }
  const n = (v) => proposables.filter((c) => c.proposed_verdict === v).length;
  console.log(`\n${proposables.length} candidat(s) : ${n('meme_edition')} même édition, ${n('autre_edition')} autre édition, `
    + `${n('texte_ressaisi')} texte ressaisi, ${proposables.length - n('meme_edition') - n('autre_edition') - n('texte_ressaisi')} sans verdict`);
  console.log(`écrit : ${out}`);
  if (args.submit) await soumettre(cfg, proposables);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  principal().catch((e) => { console.error(`ÉCHEC : ${e.message}`); process.exit(1); });
}
