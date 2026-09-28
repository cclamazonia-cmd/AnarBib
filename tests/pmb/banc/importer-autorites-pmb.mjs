#!/usr/bin/env node
// Importe un fichier UNIMARC Autorités (ISO 2709) dans le banc PMB (H25).
//
// Pilote par HTTP le module Autorités > Import de PMB 8.1 :
// autorites/import/iimport_authorities.php, chaque étape un POST sur lui-même :
//   1. (GET) formulaire : type d'autorités, thésaurus (id_thesaurus), liens ;
//   2. action=upload + userfile (multipart) : le fichier va dans temp/, puis
//      un formulaire caché « afterupload » (action=load) relancé par setTimeout ;
//   3. action=load : le fichier est coupé sur 0x1D et rangé dans import_marc,
//      formulaire relancé tant qu'il en reste, puis « import » ;
//   4. action=import : authority_import (classe désignée par
//      pmb_import_modele_authorities) lit chaque notice d'autorité : la 001
//      devient authorities_sources.authority_number, l'origine est la ligne
//      d'origin_authorities nommée par 801 $b (créée au besoin). Bilan :
//      « Import terminé! N notices ont été traitées. ».
// (Lu dans le code de PMB 8.1.1.1 le 28/09/2026 : autorites/import/,
// classes/notice_authority.class.php, classes/origin.class.php.)
//
// Usage : node tests/pmb/banc/importer-autorites-pmb.mjs autorites.iso [bilan.json]
// Options : type « toutes », liens créés (formes rejetées, termes associés)
// vers les seules autorités présentes, sans mise à jour forcée, UTF-8.
// Variables : PMB_URL_BANC, PMB_THESAURUS (libellé ; défaut : le thésaurus par défaut de PMB),
// PMB_DB_CONTENEUR, PMB_TRACE_DIR. Identifiants de banc : admin / admin.
// Importer les autorités AVANT les notices (importer-pmb.mjs avec
// PMB_AUTORITES_NOTICES=1 et PMB_ORIGINE=AnarBib).
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const BASE = process.env.PMB_URL_BANC || 'http://127.0.0.1:8088/pmb';
const ENTREE = process.argv[2];
const BILAN = process.argv[3];
const DB = process.env.PMB_DB_CONTENEUR || 'pmb-banc-db-1';
const TRACE = process.env.PMB_TRACE_DIR;
if (!ENTREE) {
  console.error('usage : node tests/pmb/banc/importer-autorites-pmb.mjs autorites.iso [bilan.json]');
  process.exit(2);
}
const donnees = fs.readFileSync(ENTREE);

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
    fs.writeFileSync(path.join(TRACE, `aut-${String(nPage).padStart(3, '0')}.html`), buf);
  }
  return { status: res.status, buf, text: buf.toString('utf8') };
}
const form = (o) => {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(o)) (Array.isArray(v) ? v : [v]).forEach((x) => p.append(k, x));
  return p;
};
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
function options(html, nom) {
  const m = html.match(new RegExp(`<select\\b[^>]*\\bname\\s*=\\s*["']${nom}["'][^>]*>([\\s\\S]*?)</select>`, 'i'));
  if (!m) return [];
  return [...m[1].matchAll(/<option\b([^>]*)>([^<]*)/gi)].map((o) => ({
    valeur: attrs(`<x ${o[1]}>`).value, libelle: entites(o[2]).trim(), choisie: /\bselected\b/i.test(o[1]),
  }));
}
function choisir(html, nom, libelle) {
  const opts = options(html, nom);
  if (!opts.length) throw new Error(`liste ${nom} absente du formulaire`);
  const o = libelle ? opts.find((x) => x.libelle === libelle) : (opts.find((x) => x.choisie) || opts[0]);
  if (!o) throw new Error(`${nom} : « ${libelle} » introuvable (${opts.map((x) => x.libelle).join(' | ')})`);
  return o;
}
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
function sql(requete) {
  const out = execFileSync('docker', ['exec', DB, 'mariadb', '-ubibli', '-pbibli', '-N', '-B', 'bibli', '-e', requete], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  return out.split('\n').filter((l) => l !== '').map((l) => l.split('\t'));
}
const TABLES = ['authors', 'authorities_sources', 'origin_authorities', 'noeuds', 'categories', 'aut_link', 'voir_aussi'];
const comptes = () => Object.fromEntries(sql(TABLES.map((t) => `select '${t}', count(*) from ${t}`).join(' union all ')).map(([t, n]) => [t, Number(n)]));

const avant = comptes();
await req(`${BASE}/index.php`);
await req(`${BASE}/main.php`, { method: 'POST', body: form({ user: 'admin', password: 'admin', database: 'bibli' }) });
if (!cookies['PhpMyBibli-SESSID']) throw new Error('connexion PMB refusée');

const URL_AUT = `${BASE}/autorites/import/iimport_authorities.php`;
let r = await req(URL_AUT);
// Le thésaurus : celui que nomme PMB_THESAURUS, sinon le thésaurus PAR DÉFAUT
// de PMB (parametres thesaurus/defaut) — c'est là que l'import des notices
// (func_cpt_rameau_first_level) cherche une 606 par son libellé ; importées
// ailleurs, les vedettes ne seraient rattachées à rien (revue du 28/09).
const thDefaut = sql("select valeur_param from parametres where type_param = 'thesaurus' and sstype_param = 'defaut'")[0]?.[0];
const thOptions = options(r.text, 'id_thesaurus');
const thesaurus = process.env.PMB_THESAURUS || !thOptions.some((o) => o.valeur === thDefaut)
  ? choisir(r.text, 'id_thesaurus', process.env.PMB_THESAURUS)
  : thOptions.find((o) => o.valeur === thDefaut);
const fd = new FormData();
for (const [k, v] of Object.entries({
  action: 'upload', authorities_type: 'all', category_or_concept: 'category', id_thesaurus: thesaurus.valeur, scheme_uri: '',
  'type_link[subcollection]': '0', create_link: '1', 'type_link[rejected]': '1', 'type_link[associated]': '1',
  create_link_spec: '1', force_update: '0', encodage_fic_source: 'utf8',
})) fd.append(k, v);
fd.append('userfile', new Blob([donnees], { type: 'application/octet-stream' }), path.basename(ENTREE));
r = await req(URL_AUT, { method: 'POST', body: fd });
const etapes = [];
for (let pas = 0; pas < 1000; pas++) {
  const suite = relance(r.text);
  if (!suite) break;
  etapes.push(suite.champs.action || suite.nom);
  r = await req(URL_AUT, { method: 'POST', body: form(suite.champs) });
}
const fin = texte(r.text);
const nb = (re) => { const m = fin.match(re); return m ? Number(m[1]) : null; };
const traitees = nb(/Import termin\S*\s*(\d+)\s*notices/);
if (traitees === null) {
  const garde = `${BILAN || ENTREE}.page.html`;
  fs.writeFileSync(garde, r.buf);
  throw new Error(`pas de page de bilan après ${etapes.length} relances — page gardée dans ${garde}`);
}
const apres = comptes();
const bilan = {
  fichier: ENTREE,
  notices_dans_le_fichier: donnees.filter((o) => o === 0x1d).length,
  thesaurus: thesaurus.libelle,
  relances: etapes,
  pmb: {
    traitees,
    auteurs: nb(/(\d+)\s+Auteurs? trait/),
    categories: nb(/(\d+)\s+Cat\S*gories? trait/),
    erronees: nb(/(\d+) notice\(s\) erron/) ?? 0,
  },
  base: { avant, apres, delta: Object.fromEntries(Object.keys(apres).map((k) => [k, apres[k] - avant[k]])) },
  origines: sql('select id_origin_authorities, origin_authorities_name, origin_authorities_country from origin_authorities order by 1')
    .map(([id, nom, pays]) => ({ id: Number(id), nom, pays })),
};
const json = JSON.stringify(bilan, null, 2);
if (BILAN) fs.writeFileSync(BILAN, `${json}\n`);
console.log(json);
