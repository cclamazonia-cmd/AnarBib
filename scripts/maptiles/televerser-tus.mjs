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
//
// REPRISE. L'adresse TUS est gardée dans <fichier>.tus ; relancer la même commande
// reprend au même octet. ⚠️ Une adresse TUS n'est valable QUE 24 h après sa
// création (documentation Supabase) : passé REPRISE_MAX_H, ce script repart de
// zéro de lui-même, en le disant, plutôt que d'user la ligne pour un envoi qui
// sera refusé en route. Vécu le 19-20/09/2026 : 68 Go lancés le soir, la machine
// a dormi 12 h au milieu, la fenêtre s'est vidée à 65 % — un envoi doit tenir
// dans une seule fenêtre, donc la machine ne doit pas dormir pendant ce temps.
//
// Journal : <fichier>.upload.log (en plus de la sortie standard), pour pouvoir
// suivre l'envoi depuis une autre session que le terminal qui l'a lancé.
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
// PLAFOND DUR, payé le 21/09/2026 à 92 % d'un envoi de 68,3 Go : le Storage range
// chaque morceau TUS comme une « part » S3, et S3 en accepte 10 000 au plus
// (« Part number must be an integer between 1 and 10000 »). À 6 Mio le morceau —
// taille imposée par Supabase — un fichier ne peut donc pas dépasser 62,9 Go par
// cette voie. Au-delà : protocole S3 du Storage avec de grosses parts, ou un
// extrait plus petit (z13 = 36 Go). On refuse AVANT d'user la ligne.
const MAX_TUS = 10_000 * CHUNK;
if (size > MAX_TUS) {
  console.error(`fichier de ${(size / 1e9).toFixed(1)} Go : au-delà des ${(MAX_TUS / 1e9).toFixed(1)} Go que TUS peut porter (10 000 morceaux de 6 Mio). Voir l'en-tête de ce script.`);
  process.exit(2);
}
const TIMEOUT_MS = 120_000;   // un morceau qui pend plus de 2 min est perdu, pas attendu
const ESSAIS = 8;
const REPRISE_MAX_H = 22;     // marge sous les 24 h de validité d'une adresse TUS
const stateFile = `${file}.tus`;
const logFile = `${file}.upload.log`;
const auth = { authorization: `Bearer ${key}`, apikey: key, 'Tus-Resumable': '1.0.0' };
const b64 = (s) => Buffer.from(s).toString('base64');

function dire(ligne) {
  const l = `${new Date().toTimeString().slice(0, 8)} ${ligne}`;   // heure locale, pas UTC
  console.log(l);
  try { fs.appendFileSync(logFile, `${l}\n`); } catch { /* le journal est un confort */ }
}

async function creer() {
  const r = await fetch(endpoint, {
    method: 'POST',
    signal: AbortSignal.timeout(TIMEOUT_MS),
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
  try {
    const r = await fetch(url, { method: 'HEAD', headers: auth, signal: AbortSignal.timeout(30_000) });
    if (r.status !== 200) return null;   // 404/410 = adresse expirée ou envoi inconnu
    return Number(r.headers.get('upload-offset') || 0);
  } catch { return null; }
}

async function main() {
  let url = fs.existsSync(stateFile) ? fs.readFileSync(stateFile, 'utf8').trim() : '';
  let offset = null;

  if (url) {
    const ageH = (Date.now() - fs.statSync(stateFile).mtimeMs) / 3_600_000;
    if (ageH >= REPRISE_MAX_H) {
      dire(`adresse de reprise vieille de ${ageH.toFixed(1)} h : au-delà de ${REPRISE_MAX_H} h elle va expirer en route — on repart de zéro`);
      url = '';
    } else {
      offset = await offsetDe(url);
      if (offset === null) dire(`adresse de reprise refusée par le serveur (expirée ?) après ${ageH.toFixed(1)} h — on repart de zéro`);
      else dire(`reprise à ${(offset / 1e9).toFixed(2)} Go sur ${(size / 1e9).toFixed(2)} (${Math.floor(offset / size * 100)} %), adresse vieille de ${ageH.toFixed(1)} h — il reste ${(24 - ageH).toFixed(1)} h de validité`);
    }
  }
  if (offset === null || !url) { url = await creer(); offset = 0; dire(`nouvel envoi de ${(size / 1e9).toFixed(2)} Go — la machine ne doit pas dormir avant la fin`); }

  const depart = offset;
  const fd = fs.openSync(file, 'r');
  const t0 = Date.now();
  let lastPct = -1;
  let coupures = 0;

  while (offset < size) {
    const len = Math.min(CHUNK, size - offset);
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, offset);
    let ok = false;
    for (let essai = 0; essai < ESSAIS && !ok; essai++) {
      try {
        const r = await fetch(url, {
          method: 'PATCH',
          signal: AbortSignal.timeout(TIMEOUT_MS),
          headers: { ...auth, 'Upload-Offset': String(offset), 'Content-Type': 'application/offset+octet-stream' },
          body: buf,
        });
        if (r.status === 204) {
          // Sans en-tête d'offset, ne JAMAIS supposer 0 : on renverrait tout depuis le début.
          const o = Number(r.headers.get('upload-offset'));
          offset = Number.isFinite(o) && o > offset ? o : ((await offsetDe(url)) ?? (offset + len));
          ok = true;
        }
        else if (r.status === 409 || r.status === 412) {
          const o = await offsetDe(url);
          if (o === null) { dire('adresse TUS perdue en cours d\'envoi — relancer la commande repartira de zéro'); process.exit(1); }
          offset = o; ok = true;
        } else if (r.status === 404 || r.status === 410) {
          dire(`adresse TUS expirée à ${(offset / 1e9).toFixed(2)} Go — relancer la commande repartira de zéro`);
          process.exit(1);
        } else throw new Error(`${r.status} ${(await r.text()).slice(0, 120).replace(/\s+/g, ' ')}`);
      } catch (e) {
        coupures++;
        const attente = Math.min(30_000, 3000 * (essai + 1));
        dire(`coupure à ${(offset / 1e9).toFixed(2)} Go : ${e.message} — essai ${essai + 1}/${ESSAIS} dans ${attente / 1000} s`);
        await new Promise((res) => setTimeout(res, attente));
        const o = await offsetDe(url);   // le serveur a peut-être reçu le morceau malgré la coupure
        if (o !== null && o > offset) { offset = o; ok = true; }
      }
    }
    if (!ok) { dire(`abandon à ${(offset / 1e9).toFixed(2)} Go après ${ESSAIS} essais ; relancer la commande pour reprendre`); process.exit(1); }

    const pct = Math.floor((offset / size) * 100);
    if (pct !== lastPct && pct % 5 === 0) {
      lastPct = pct;
      const s = (Date.now() - t0) / 1000;
      const debit = (offset - depart) / 1e6 / s;              // débit de CETTE session, pas le cumul
      const reste = debit > 0 ? (size - offset) / 1e6 / debit / 60 : 0;
      dire(`${pct}% — ${(offset / 1e9).toFixed(2)} Go sur ${(size / 1e9).toFixed(2)} ; ${debit.toFixed(1)} Mo/s ; reste ~${reste.toFixed(0)} min ; ${coupures} coupure(s)`);
    }
  }

  fs.closeSync(fd);
  fs.rmSync(stateFile, { force: true });
  dire(`OK ${bucket}/${object} (${size} octets) en ${((Date.now() - t0) / 1000 / 60).toFixed(0)} min, ${coupures} coupure(s)`);
  dire(`contrôle : curl -sI -r 0-99 ${base}/storage/v1/object/public/${bucket}/${object}  → 206`);
}

main().catch((e) => { dire(`ERREUR ${e.message}`); process.exit(1); });
