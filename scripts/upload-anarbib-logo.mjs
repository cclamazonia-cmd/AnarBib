#!/usr/bin/env node
/**
 * upload-anarbib-logo.mjs — pousse le logo AnarBib (dessin humain, 2026) dans
 * le theme par defaut du bucket public `library-ui-assets/themes/default/`.
 *
 * Pourquoi ce script : les fichiers de public/img/ ne sont servis qu'apres un
 * build+deploiement du front, alors que le theme par defaut est lu en direct
 * depuis le Storage — par l'app (manifest.json -> logo.svg, favicon.png) et
 * par les mails (supabase/functions/register/index.ts, qui inline
 * themes/default/logo-anarbib.png en data URI). Les deux copies doivent donc
 * etre poussees ensemble, sinon le logo change dans l'app mais pas dans les
 * mails (ou l'inverse).
 *
 * ACTION PROD (outward-facing) : a lancer DELIBEREMENT, jamais en auto.
 * L'effet est immediat pour tout le monde, sans deploiement.
 *
 * Auth : cle SERVICE_ROLE (le bucket est public en lecture, pas en ecriture).
 * Elle n'est PAS dans .env.local et n'est pas persistee :
 *
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/upload-anarbib-logo.mjs
 *
 * Options :
 *   --dry-run    n'ecrit rien, liste ce qui serait pousse
 *   --no-backup  saute la sauvegarde locale de l'existant (deconseille)
 *
 * Idempotent (upsert) : relancable sans dommage.
 */

import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = resolve(ROOT, 'public/img');
const BUCKET = 'library-ui-assets';
const PREFIX = 'themes/default';
const BACKUP = resolve(ROOT, '_handoff/logo-storage-avant-remplacement');

const DRY = process.argv.includes('--dry-run');
const NO_BACKUP = process.argv.includes('--no-backup');

function readEnvLocal() {
  const p = resolve(ROOT, '.env.local');
  if (!existsSync(p)) return {};
  const out = {};
  // Split sur /\r?\n/ : en CRLF, le \r final ferait echouer /^([A-Z_]+)=(.*)$/
  // ('.' ne matche pas \r) et toutes les cles passeraient pour absentes.
  for (const line of readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z_]+)=(.*)$/);
    if (m) out[m[1]] = m[2].trim();
  }
  return out;
}

const envLocal = readEnvLocal();
const SUPABASE_URL = process.env.VITE_SUPABASE_URL || envLocal.VITE_SUPABASE_URL;
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SERVICE_ROLE_KEY;

if (!SUPABASE_URL) {
  console.error('✗ VITE_SUPABASE_URL introuvable (.env.local ou env).');
  process.exit(1);
}
if (!SERVICE_ROLE && !DRY) {
  console.error('✗ Cle service_role manquante. Lance avec :');
  console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/upload-anarbib-logo.mjs');
  process.exit(1);
}

// Ce qui est remplace. On NE touche PAS a bg.webp (fond de page), aux polices
// ni a manifest.json : le manifeste pointe deja sur logo.svg et favicon.png,
// qui sont remplaces en place.
const FILES = [
  { local: 'anarbib-logo.svg',    remote: 'logo.svg',             type: 'image/svg+xml' },
  { local: 'logo-anarbib.png',    remote: 'logo-anarbib.png',     type: 'image/png' },
  { local: 'favicon.png',         remote: 'favicon.png',          type: 'image/png' },
  { local: 'favicon-32.png',      remote: 'favicon-32.png',       type: 'image/png' },
  { local: 'icon-192.png',        remote: 'icon-192.png',         type: 'image/png' },
  { local: 'icon-512.png',        remote: 'icon-512.png',         type: 'image/png' },
  { local: 'apple-touch-icon.png',remote: 'apple-touch-icon.png', type: 'image/png' },
  { local: 'og-image.png',        remote: 'og-image.png',         type: 'image/png' },
];

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE || 'dry', {
  auth: { persistSession: false, autoRefreshToken: false },
});

console.log(`▶ Logo AnarBib → ${BUCKET}/${PREFIX}/  (${SUPABASE_URL})${DRY ? '  [DRY-RUN]' : ''}`);

// ── Sauvegarde de l'existant ────────────────────────────────────────────
if (!NO_BACKUP && !DRY) {
  mkdirSync(BACKUP, { recursive: true });
  for (const f of FILES) {
    const url = supabase.storage.from(BUCKET).getPublicUrl(`${PREFIX}/${f.remote}`).data.publicUrl;
    const r = await fetch(url);
    if (!r.ok) { console.log(`  · pas d'existant a sauver : ${f.remote} (${r.status})`); continue; }
    writeFileSync(resolve(BACKUP, f.remote), Buffer.from(await r.arrayBuffer()));
    console.log(`  ↓ sauvegarde ${f.remote}`);
  }
  console.log(`  Sauvegarde dans ${BACKUP}\n`);
}

// ── Depot ───────────────────────────────────────────────────────────────
let ok = 0, fail = 0;
for (const f of FILES) {
  const localPath = resolve(SRC, f.local);
  if (!existsSync(localPath)) {
    console.error(`  ✗ absent localement : public/img/${f.local}`);
    fail += 1;
    continue;
  }
  const body = readFileSync(localPath);
  const remotePath = `${PREFIX}/${f.remote}`;
  if (DRY) {
    console.log(`  ~ ${remotePath} ← public/img/${f.local} (${(body.length / 1024).toFixed(1)} Ko)`);
    ok += 1;
    continue;
  }
  const { error } = await supabase.storage.from(BUCKET).upload(remotePath, body, {
    contentType: f.type,
    upsert: true,
    cacheControl: '3600', // 1 h : le logo bouge rarement, mais on veut pouvoir corriger vite
  });
  if (error) { console.error(`  ✗ ${remotePath} : ${error.message}`); fail += 1; }
  else { console.log(`  ✓ ${remotePath} (${(body.length / 1024).toFixed(1)} Ko)`); ok += 1; }
}

const base = supabase.storage.from(BUCKET).getPublicUrl(PREFIX).data.publicUrl;
console.log(`\n${ok} pousses, ${fail} echecs.`);
console.log(`Base publique : ${base}`);
if (!DRY) {
  console.log('Verifie :  curl -sI "' + base + '/logo.svg"');
  console.log('Le CDN garde l\'ancienne copie jusqu\'a 1 h : ajoute ?v=' + Date.now() + ' pour forcer.');
}
process.exit(fail ? 1 : 0);
