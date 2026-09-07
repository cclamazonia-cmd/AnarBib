#!/usr/bin/env node
// =============================================================================
// televerser-tus.mjs — téléverse un gros fichier dans le Storage par morceaux
// =============================================================================
// Pourquoi ce script : `supabase storage cp` envoie le fichier d'un seul tenant
// et Cloudflare refuse au-delà de quelques Go (413 Payload Too Large, vécu le
// 07/09/2026 sur les 18 Go du fond de carte). Le protocole TUS du Storage
// (« resumable upload ») accepte des morceaux de 6 Mio et reprend où il s'est
// arrêté. Aucune dépendance : fetch et fs de Node ≥ 18.
//
// Usage :
//   SUPABASE_SECRET_KEY=sb_secret_… node scripts/maptiles/televerser-tus.mjs \
//       <fichier> [bucket=map-tiles] [objet=<nom du fichier>] [cache=604800]
//
// La clé secrète vient de l'environnement ou du fichier ~/.config/anarbib/secret-key
// (mode 600) ; elle n'est jamais écrite ni affichée. Le projet est lu dans
// VITE_SUPABASE_URL, sinon la production (uflwmikiyjfnikiphtcp).
// Reprise : l'adresse TUS est gardée dans <fichier>.tus ; relancer suffit.
// =============================================================================
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const [,, file, bucket = 'map-tiles', objectArg, cacheArg = '604800'] = process.argv;
if (!file) { console.error('usage : televerser-tus.mjs <fichier> [bucket] [objet] [cache-secondes]'); process.exit(2); }
const object = objectArg || path.basename(file).replace(/-\d{8}\.pmtiles$/, '.pmtiles');
const base = (process.env.VITE_SUPABASE_URL || 'https://uflwmikiyjfnikiphtcp.supabase.co').replace(/\/+$/, '');
const endpoint = `${base}/storage/v1/upload/resumable`;

let key = process.env.SUPABASE_SECRET_KEY || '';
if (!key) {
  const f = path.join(os.homedir(), '.config', 'anarbib', 'secret-key');
  if (fs.existsSync(f)) key = fs.readFileSync(f, 'utf8').trim();
}
if (!key) { console.error('clé secrète absente : SUPABASE_SECRET_KEY ou ~/.config/anarbib/secret-key'); process.exit(2); }

const size = fs.statSync(file).size;
const CHUNK = 6 * 1024 * 1024;
const stateFile = `${file}.tus`;
const auth = { authorization: `Bearer ${key}`, apikey: key, 'Tus-Resumable': '1.0.0' };
const b64 = (s) => Buffer.from(s).toString('base64');

async function creer() {
  const r = await fetch(endpoint, {
    method: 'POST',
    headers: {
      ...auth,
      'x-upsert': 'true',
      'Upload-Length': String(size),
      'Upload-Metadata': [
        `bucketName ${b64(bucket)}`, `objectName ${b64(object)}`,
        `contentType ${b64('application/octet-stream')}`, `cacheControl ${b64(String(cacheArg))}`,
      ].join(','),
    },
  });
  if (r.status !== 201) throw new Error(`création TUS : ${r.status} ${await r.text()}`);
  const loc = r.headers.get('location');
  const url = loc.startsWith('http') ? loc : `${base}${loc}`;
  fs.writeFileSync(stateFile, url);
  return url;
}

async function offsetDe(url) {
  const r = await fetch(url, { method: 'HEAD', headers: auth });
  if (r.status !== 200) return null;
  return Number(r.headers.get('upload-offset') || 0);
}

async function main() {
  let url = fs.existsSync(stateFile) ? fs.readFileSync(stateFile, 'utf8').trim() : '';
  let offset = url ? await offsetDe(url) : null;
  if (offset === null) { url = await creer(); offset = 0; console.log('nouvel envoi'); }
  else console.log(`reprise à ${(offset / 1e9).toFixed(2)} Go`);

  const fd = fs.openSync(file, 'r');
  const t0 = Date.now();
  let lastPct = -1;
  while (offset < size) {
    const len = Math.min(CHUNK, size - offset);
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, offset);
    let ok = false;
    for (let essai = 0; essai < 6 && !ok; essai++) {
      try {
        const r = await fetch(url, {
          method: 'PATCH',
          headers: { ...auth, 'Upload-Offset': String(offset), 'Content-Type': 'application/offset+octet-stream' },
          body: buf,
        });
        if (r.status === 204) { offset = Number(r.headers.get('upload-offset')); ok = true; }
        else if (r.status === 409 || r.status === 412) { offset = (await offsetDe(url)) ?? offset; ok = true; }
        else throw new Error(`${r.status} ${await r.text()}`);
      } catch (e) {
        console.error(`morceau à ${offset} : ${e.message} — nouvel essai ${essai + 1}/6`);
        await new Promise((res) => setTimeout(res, 3000 * (essai + 1)));
      }
    }
    if (!ok) { console.error('abandon ; relancer pour reprendre'); process.exit(1); }
    const pct = Math.floor((offset / size) * 100);
    if (pct !== lastPct && pct % 5 === 0) {
      lastPct = pct;
      const s = (Date.now() - t0) / 1000;
      console.log(`${pct}% — ${(offset / 1e9).toFixed(2)} Go en ${s.toFixed(0)} s (${(offset / 1e6 / s).toFixed(1)} Mo/s)`);
    }
  }
  fs.closeSync(fd);
  fs.rmSync(stateFile, { force: true });
  console.log(`OK ${bucket}/${object} (${size} octets) en ${((Date.now() - t0) / 1000).toFixed(0)} s`);
  console.log(`contrôle : curl -sI -r 0-99 ${base}/storage/v1/object/public/${bucket}/${object}  → 206`);
}

main().catch((e) => { console.error('ERREUR', e.message); process.exit(1); });
