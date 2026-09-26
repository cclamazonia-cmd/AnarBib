#!/usr/bin/env node
// Importe un fichier UNIMARC ISO 2709 dans le banc PMB sans cliquer (H14).
//
// Pilote par HTTP le module Administration > Import > « Import de notices et
// exemplaires » de PMB 8.1. admin.php?categ=import&sub=import_expl n'est qu'un
// cadre : tout se passe dans admin/import/iimport_expl.php (l'iframe), dont
// chaque étape est un POST sur elle-même, avec `action` :
//   1. (GET, sans action) choix de la fonction d'import — <select func_import>,
//      présélection = paramètre pmb_import_modele (func_bdp.inc.php sur le
//      banc) — et de l'encodage (vide = détection : 100 $a pos. 26-27 « 50 »
//      ⇒ UTF-8).
//   2. action=beforeupload + func_import : la fonction est gardée en session
//      ($_SESSION["func_import_model"]) jusqu'à la fin ; la page rend le
//      formulaire multipart des options (tpl_beforeupload_expl).
//   3. action=afterupload + userfile (multipart) : le fichier est déplacé dans
//      temp/, puis la page rend un formulaire caché « afterupload »
//      (action=preload) que <script>setTimeout("document.afterupload.submit()")
//      renvoie.
//   4. action=preload : loadfile_in_table() coupe le fichier sur 0x1D et range
//      les notices dans la table import_marc par paquets de
//      pmb_import_limit_read_file ; formulaire « preload » tant qu'il en
//      reste, puis formulaire « load ».
//   5. action=load : traite pmb_import_limit_record_load notices de
//      import_marc (notice, liens 46X si link_generate, exemplaires 995 par la
//      fonction d'import) ; formulaire « load » tant qu'il en reste. La
//      dernière page porte le bilan : « Il y avait N notice(s) à charger »,
//      notices déjà présentes, notices invalides, exemplaires ignorés, et la
//      « Liste des erreurs constatées » (table error_log de la session).
// À la différence de l'export (document.location=…), les relances sont des
// formulaires POST cachés soumis par setTimeout : le script relit le
// formulaire nommé dans le setTimeout et le renvoie tel quel.
//
// Usage : node tests/pmb/banc/importer-pmb.mjs fichier.iso [bilan.json]
// Options retenues (celles du formulaire, sauf mention) : fonction d'import
// présélectionnée (func_bdp : 995 $f code-barres, $k cote, $u note, $r type,
// $q section/public ; propriétaire, statut et localisation pris dans le
// formulaire, pas dans la 995) ; ISBN non obligatoire ; dédoublonnage sur ISBN
// seul ; statut de notice présélectionné ; génération des liens 46X ACTIVÉE
// (le formulaire propose « Non ») ; propriétaire présélectionné (préférence
// deflt_import_lenders de l'utilisateur), statut « Document en bon état »,
// localisation « Bibliothèque principale » ; cote non obligatoire ; codages
// type/section/code statistique génériques ; indexation faite.
// Variables : PMB_URL_BANC, PMB_FONCTION_IMPORT (ex. func_pmb.inc),
// PMB_ENCODAGE (utf8, iso8859, iso5426), PMB_LIENS (0/1), PMB_PROPRIETAIRE,
// PMB_STATUT, PMB_LOCALISATION (libellés), PMB_DB_CONTENEUR, PMB_TRACE_DIR
// (garde chaque page HTML).
// Identifiants de banc : admin / admin (installer-pmb.sh) ; base bibli/bibli.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const BASE = process.env.PMB_URL_BANC || 'http://127.0.0.1:8088/pmb';
const ENTREE = process.argv[2];
const BILAN = process.argv[3];
const DB = process.env.PMB_DB_CONTENEUR || 'pmb-banc-db-1';
const TRACE = process.env.PMB_TRACE_DIR;
if (!ENTREE) {
  console.error('usage : node tests/pmb/banc/importer-pmb.mjs fichier.iso [bilan.json]');
  process.exit(2);
}
const donnees = fs.readFileSync(ENTREE);

// --- HTTP : bocal à cookies, comme exporter-pmb.mjs ---------------------------
const cookies = {};
const jar = () => Object.entries(cookies).map(([k, v]) => `${k}=${v}`).join('; ');
let nPage = 0;
async function req(url, opts = {}) {
  const res = await fetch(url, { redirect: 'manual', ...opts, headers: { cookie: jar(), ...(opts.headers || {}) } });
  for (const c of res.headers.getSetCookie?.() || []) {
    const kv = c.split(';')[0];
    const i = kv.indexOf('=');
    cookies[kv.slice(0, i)] = kv.slice(i + 1);
  }
  const buf = Buffer.from(await res.arrayBuffer());
  nPage++;
  if (TRACE) {
    fs.mkdirSync(TRACE, { recursive: true });
    fs.writeFileSync(path.join(TRACE, `${String(nPage).padStart(3, '0')}.html`), buf);
  }
  return { status: res.status, buf, text: buf.toString('utf8') };
}
const form = (o) => {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(o)) (Array.isArray(v) ? v : [v]).forEach((x) => p.append(k, x));
  return p;
};
const URL_IMPORT = `${BASE}/admin/import/iimport_expl.php`;

// --- HTML : juste ce qu'il faut pour relire les formulaires de PMB -----------
const entites = (s) => s
  .replace(/&#0*39;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/&nbsp;/g, ' ').replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
  .replace(/&([a-z]+);/gi, (m, n) => ({ eacute: 'é', egrave: 'è', ecirc: 'ê', agrave: 'à', acirc: 'â', ccedil: 'ç', ocirc: 'ô', ucirc: 'û', icirc: 'î', amp: '&' })[n] ?? m);
const attrs = (tag) => {
  const a = {};
  for (const m of tag.matchAll(/([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/g)) a[m[1].toLowerCase()] = entites(m[2] ?? m[3] ?? m[4]);
  return a;
};
const texte = (html) => entites(html.replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]*>/g, ' ')).replace(/[ \t]+/g, ' ').replace(/\s*\n\s*/g, '\n').trim();
// Options d'un <select name=…> : [{ valeur, libelle, choisie }]
function options(html, nom) {
  const m = html.match(new RegExp(`<select\\b[^>]*\\bname\\s*=\\s*["']${nom}["'][^>]*>([\\s\\S]*?)</select>`, 'i'));
  if (!m) return [];
  return [...m[1].matchAll(/<option\b([^>]*)>([^<]*)/gi)].map((o) => ({
    valeur: attrs(`<x ${o[1]}>`).value,
    libelle: entites(o[2]).trim(),
    choisie: /\bselected\b/i.test(o[1]),
  }));
}
function choisir(html, nom, libelle) {
  const opts = options(html, nom);
  if (!opts.length) throw new Error(`liste ${nom} absente du formulaire`);
  const o = libelle ? opts.find((x) => x.libelle === libelle) : (opts.find((x) => x.choisie) || opts[0]);
  if (!o) throw new Error(`${nom} : « ${libelle} » introuvable (${opts.map((x) => x.libelle).join(' | ')})`);
  return o;
}
// Formulaire caché relancé par setTimeout("document.NOM.submit()") → champs.
function relance(html) {
  const s = html.match(/setTimeout\(\s*["']document\.(\w+)\.submit\(\)["']/);
  if (!s) return null;
  const f = html.match(new RegExp(`<form\\b[^>]*\\bname\\s*=\\s*["']?${s[1]}["']?[^>]*>([\\s\\S]*?)</form>`, 'i'));
  if (!f) throw new Error(`formulaire « ${s[1]} » annoncé mais introuvable`);
  const champs = {};
  for (const m of f[1].matchAll(/<input\b[^>]*>/gi)) {
    const a = attrs(m[0]);
    if (a.name && (!a.type || a.type.toLowerCase() === 'hidden')) champs[a.name] = a.value ?? '';
  }
  return { nom: s[1], champs };
}
// Avertissements PHP éventuellement affichés dans la page.
const avertissements = new Map();
function relever(html) {
  for (const m of html.matchAll(/<b>(Warning|Notice|Deprecated|Fatal error|Parse error)<\/b>:\s*([\s\S]*?)<br\s*\/?>/gi)) {
    const k = `${m[1]}: ${texte(m[2])}`;
    avertissements.set(k, (avertissements.get(k) || 0) + 1);
  }
}

// --- Base : comptes avant/après par docker exec -------------------------------
function sql(requete) {
  const out = execFileSync('docker', ['exec', DB, 'mariadb', '-ubibli', '-pbibli', '-N', '-B', 'bibli', '-e', requete], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  return out.split('\n').filter((l) => l !== '').map((l) => l.split('\t'));
}
const TABLES = ['notices', 'exemplaires', 'bulletins', 'analysis', 'notices_relations', 'responsability', 'authors',
  'publishers', 'collections', 'sub_collections', 'series', 'indexint', 'categories', 'notices_categories',
  'notices_langues', 'docs_type', 'docs_section', 'docs_codestat', 'import_marc', 'error_log'];
function comptes() {
  const r = sql(TABLES.map((t) => `select '${t}', count(*) from ${t}`).join(' union all '));
  const c = Object.fromEntries(r.map(([t, n]) => [t, Number(n)]));
  const [[maxNotice, maxExpl]] = sql('select (select coalesce(max(notice_id),0) from notices), (select coalesce(max(expl_id),0) from exemplaires)');
  return { ...c, max_notice_id: Number(maxNotice), max_expl_id: Number(maxExpl) };
}

const avant = comptes();

// --- 1-2. Connexion, fonction d'import, formulaire des options ---------------
await req(`${BASE}/index.php`);
await req(`${BASE}/main.php`, { method: 'POST', body: form({ user: 'admin', password: 'admin', database: 'bibli' }) });
if (!cookies['PhpMyBibli-SESSID']) throw new Error('connexion PMB refusée');

let r = await req(`${URL_IMPORT}?categ=import&sub=import_expl`);
const fonctions = options(r.text, 'func_import');
const fonction = process.env.PMB_FONCTION_IMPORT
  ? fonctions.find((o) => o.valeur === process.env.PMB_FONCTION_IMPORT)
  : fonctions.find((o) => o.choisie);
if (!fonction) throw new Error(`fonction d'import introuvable (${fonctions.map((o) => o.valeur).join(', ')})`);
const encodage = process.env.PMB_ENCODAGE || '';

r = await req(URL_IMPORT, { method: 'POST', body: form({ categ: 'import', sub: 'import_expl', action: 'beforeupload', func_import: fonction.valeur, encodage_fic_source: encodage }) });
if (!/name=['"]userfile['"]/i.test(r.text)) throw new Error("pas de formulaire d'envoi après beforeupload");
const proprietaire = choisir(r.text, 'book_lender_id', process.env.PMB_PROPRIETAIRE);
const statut = choisir(r.text, 'book_statut_id', process.env.PMB_STATUT || 'Document en bon état');
const localisation = choisir(r.text, 'book_location_id', process.env.PMB_LOCALISATION || 'Bibliothèque principale');
const statutNotice = choisir(r.text, 'statutnot');
const origine = choisir(r.text, 'authorities_origin');
const liens = (process.env.PMB_LIENS ?? '1') === '1';

// --- 3. Envoi du fichier (multipart) -----------------------------------------
const champs = {
  categ: 'import', sub: 'import_expl', action: 'afterupload',
  isbn_mandatory: '0', isbn_dedoublonnage: '1', isbn_only: '1',
  statutnot: statutNotice.valeur, link_generate: liens ? '1' : '0', notice_replace_links: '0',
  import_force_notice_is_new: '0', authorities_notices: '0', import_notice_existing_replace: '0',
  authorities_default_origin: origine.valeur,
  book_lender_id: proprietaire.valeur, book_statut_id: statut.valeur, book_location_id: localisation.valeur,
  cote_mandatory: '0', tdoc_codage: '0', statisdoc_codage: '0', sdoc_codage: '0',
};
const fd = new FormData();
for (const [k, v] of Object.entries(champs)) fd.append(k, v);
fd.append('userfile', new Blob([donnees], { type: 'application/octet-stream' }), path.basename(ENTREE));
r = await req(URL_IMPORT, { method: 'POST', body: fd });
relever(r.text);

// --- 4-5. Relances preload… puis load… jusqu'à la page de bilan --------------
const etapes = [];
for (let pas = 0; pas < 1000; pas++) {
  const suite = relance(r.text);
  if (!suite) break;
  etapes.push(suite.champs.action || suite.nom);
  r = await req(URL_IMPORT, { method: 'POST', body: form(suite.champs) });
  relever(r.text);
}
const fin = texte(r.text);
const nb = (re) => { const m = fin.match(re); return m ? Number(m[1]) : null; };
const aCharger = nb(/Il y avait\s*(\d+)\s*notice\(s\) à charger/);
if (aCharger === null) {
  const garde = `${BILAN || ENTREE}.page.html`;
  fs.writeFileSync(garde, r.buf);
  throw new Error(`pas de page de bilan après ${etapes.length} relances — page gardée dans ${garde}`);
}
const erreurs = [];
const tableErreurs = r.text.split('Liste des erreurs constat')[1];
if (tableErreurs) {
  for (const tr of tableErreurs.matchAll(/<tr>([\s\S]*?)<\/tr>/gi)) {
    const cells = [...tr[1].matchAll(/<td[^>]*>([\s\S]*?)<\/td>/gi)].map((c) => texte(c[1]));
    if (cells.length === 3) erreurs.push({ origine: cells[0], erreur: cells[1], nb: Number(cells[2]) });
  }
}

// --- Contrôle en base ---------------------------------------------------------
const apres = comptes();
const delta = Object.fromEntries(Object.keys(apres).filter((k) => !k.startsWith('max_')).map((k) => [k, apres[k] - avant[k]]));
const noticesCreees = sql(`select notice_id, concat(niveau_biblio, niveau_hierar), code, tit1 from notices where notice_id > ${avant.max_notice_id} order by notice_id`)
  .map(([id, niveau, code, titre]) => ({ id: Number(id), niveau, code, titre }));
const exemplairesCrees = sql(`select e.expl_id, e.expl_notice, e.expl_bulletin, e.expl_cb, e.expl_cote, l.lender_libelle, s.statut_libelle, o.location_libelle, x.section_libelle, t.tdoc_libelle, c.codestat_libelle
  from exemplaires e left join lenders l on l.idlender = e.expl_owner left join docs_statut s on s.idstatut = e.expl_statut
  left join docs_location o on o.idlocation = e.expl_location left join docs_section x on x.idsection = e.expl_section
  left join docs_type t on t.idtyp_doc = e.expl_typdoc left join docs_codestat c on c.idcode = e.expl_codestat
  where e.expl_id > ${avant.max_expl_id} order by e.expl_id`)
  .map(([id, notice, bulletin, cb, cote, prop, st, loc, sec, type, codestat]) => ({ id: Number(id), notice: Number(notice), bulletin: Number(bulletin), cb, cote, proprietaire: prop, statut: st, localisation: loc, section: sec, type, codestat }));

const bilan = {
  fichier: ENTREE,
  octets: donnees.length,
  notices_dans_le_fichier: donnees.filter((o) => o === 0x1d).length,
  fonction_import: `${fonction.valeur}.php (${fonction.libelle})`,
  encodage: encodage || 'détection automatique',
  options: {
    proprietaire: proprietaire.libelle, statut: statut.libelle, localisation: localisation.libelle,
    statut_notice: statutNotice.libelle, liens_46X: liens, dedoublonnage_isbn: true, isbn_obligatoire: false, cote_obligatoire: false,
  },
  relances: etapes,
  pmb: {
    notices_a_charger: aCharger,
    notices_deja_presentes: nb(/dont\s*(\d+)\s*notices? déjà présentes? dans la base/) ?? 0,
    notices_invalides: nb(/(\d+)\s*notices invalides/) ?? 0,
    exemplaires_ignores: nb(/(\d+)\s*exemplaire\(s\) ignoré\(s\)/),
    erreurs,
    avertissements_php: [...avertissements].map(([message, fois]) => ({ message, fois })),
  },
  base: { avant, apres, delta },
  notices_creees: noticesCreees,
  exemplaires_crees: exemplairesCrees,
};
const json = JSON.stringify(bilan, null, 2);
if (BILAN) fs.writeFileSync(BILAN, `${json}\n`);
console.log(json);
