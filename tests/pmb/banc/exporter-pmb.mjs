#!/usr/bin/env node
// Exporte le catalogue du banc PMB sans cliquer (H14).
//
// Pilote par HTTP le module Administration > Import/Export > Export de PMB 8.1 :
// admin/convert/export.php (formulaire) → start_export.php (lots de 200
// notices, relancés par `document.location=…` en JavaScript) →
// start_import.php?noimport=1 (conversion pmb-XML → format demandé, relancée
// de la même façon) → lien de téléchargement du fichier final.
//
// Usage : node tests/pmb/banc/exporter-pmb.mjs [format] [fichier-de-sortie]
//   format : libellé exact d'une option du formulaire, « UNIMARC ISO2709 » par
//            défaut (« UNIMARC PMB XML », « XML MARC », « DUBLIN CORE (DC) »…)
// Options d'export retenues : exemplaires inclus (keep_expl), liens
// générés (notices mères/filles, bulletins, périodiques, articles).
// Identifiants de banc : admin / admin (installer-pmb.sh).
import fs from 'node:fs';
import path from 'node:path';

const BASE = process.env.PMB_URL_BANC || 'http://127.0.0.1:8088/pmb';
const FORMAT = process.argv[2] || 'UNIMARC ISO2709';
const SORTIE = process.argv[3] || path.join(process.env.HOME, 'pmb-banc/echange', 'export-unimarc.iso');

const cookies = {};
const jar = () => Object.entries(cookies).map(([k, v]) => `${k}=${v}`).join('; ');
async function req(url, opts = {}) {
  const res = await fetch(url, { redirect: 'manual', ...opts, headers: { cookie: jar(), ...(opts.headers || {}) } });
  for (const c of res.headers.getSetCookie?.() || []) {
    const kv = c.split(';')[0];
    const i = kv.indexOf('=');
    cookies[kv.slice(0, i)] = kv.slice(i + 1);
  }
  const buf = Buffer.from(await res.arrayBuffer());
  return { status: res.status, loc: res.headers.get('location'), ct: res.headers.get('content-type') || '', cd: res.headers.get('content-disposition') || '', buf, text: buf.toString('latin1') };
}
const form = (o) => {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(o)) (Array.isArray(v) ? v : [v]).forEach((x) => p.append(k, x));
  return p;
};
const abs = (dir, href) => new URL(href.replace(/&amp;/g, '&'), `${BASE}/${dir}/`).toString();

await req(`${BASE}/index.php`);
await req(`${BASE}/main.php`, { method: 'POST', body: form({ user: 'admin', password: 'admin', database: 'bibli' }) });
if (!cookies['PhpMyBibli-SESSID']) throw new Error('connexion PMB refusée');

let r = await req(`${BASE}/admin/convert/export.php`);
const opt = [...r.text.matchAll(/<option value="(\d+)">([^<]+)<\/option>/g)].find((m) => m[2].trim() === FORMAT);
if (!opt) throw new Error(`format inconnu : ${FORMAT}`);

r = await req(`${BASE}/admin/convert/start_export.php`, {
  method: 'POST',
  body: form({
    export_type: opt[1], lender: 'x', keep_expl: '1',
    genere_lien: '1', mere: '1', fille: '1', horizontale: '1',
    notice_mere: '1', notice_fille: '1', notice_horizontale: '1',
    bull_link: '1', perio_link: '1', art_link: '1',
    bulletinage: '1', notice_perio: '1', notice_art: '1',
  }),
});

// Suivre les relances JavaScript, puis chercher le lien du fichier produit.
let url = null;
for (let pas = 0; pas < 500; pas++) {
  const suite = r.text.match(/document\.location\s*=\s*['"]([^'"]+)['"]/);
  if (!suite) break;
  url = abs('admin/convert', suite[1]);
  r = await req(url);
}
// Dernière page (end_import) : « N notices traitées », la liste des erreurs de
// conversion, et le formulaire `destfic` (folow_import.php, deliver=3 =
// « Télécharger le fichier converti ») qui livre le fichier.
const traitees = (r.text.match(/(\d+) notices trait/) || [])[1];
const erreurs = (r.text.split('Liste des erreurs')[1] || '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 500);
const destfic = r.text.match(/<form[^>]*name="destfic"[^>]*>([\s\S]*?)<\/form>/);
if (!destfic) {
  fs.writeFileSync(`${SORTIE}.page.html`, r.buf);
  throw new Error(`pas de formulaire de livraison sur la dernière page (${url}) — page gardée dans ${SORTIE}.page.html`);
}
const champs = {};
for (const m of destfic[1].matchAll(/<input[^>]*name="([^"]+)"[^>]*value="([^"]*)"[^>]*>/g)) champs[m[1]] = m[2];
champs.deliver = '3';
const f = await req(`${BASE}/admin/convert/folow_import.php`, { method: 'POST', body: form(champs) });
if (f.status !== 200 || /<html/i.test(f.buf.subarray(0, 200).toString('latin1'))) {
  fs.writeFileSync(`${SORTIE}.page.html`, f.buf);
  throw new Error(`la livraison n'a pas rendu un fichier (HTTP ${f.status}) — page gardée dans ${SORTIE}.page.html`);
}
fs.mkdirSync(path.dirname(SORTIE), { recursive: true });
fs.writeFileSync(SORTIE, f.buf);
console.log(JSON.stringify({ format: FORMAT, notices_traitees: Number(traitees), erreurs, octets: f.buf.length, type: f.ct, sortie: SORTIE }));
