#!/usr/bin/env node
/**
 * upload-ocr-assets.mjs — depose les assets OCR (tesseract.js) dans le bucket
 * public Supabase `anarbib-media-public/ocr/` (piste B, P3a).
 *
 * Session : OCR import navigateur (piste B)
 * Cadrage : docs/journal/cadrages/CADRAGE_ocr_import_navigateur_2026-06-17.md (§2, §8)
 *
 * Pourquoi : en prod, l'OCR ne tourne pas depuis /vendor/tesseract (assets
 * gitignores). Le composant bascule sur l'URL publique du bucket
 * (anarbib-media-public/ocr/). Ce script y televerse les memes fichiers que
 * scripts/install-tesseract.sh a vendorises localement.
 *
 * ACTION PROD (outward-facing) : a lancer DELIBEREMENT, jamais en auto.
 *
 * Auth : necessite une cle SERVICE_ROLE (le bucket exige can_access_catalogacao
 * en INSERT ; service_role bypass la RLS). La cle n'est PAS dans .env.local
 * (seule l'anon y est). Fournis-la a l'execution, elle n'est pas persistee :
 *
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/upload-ocr-assets.mjs
 *
 * VITE_SUPABASE_URL est lu depuis .env.local automatiquement.
 * Idempotent (upsert) : relancable sans dommage.
 */

import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
import { readEnvLocal } from './lib/env-local.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = resolve(ROOT, 'public/vendor/tesseract');
const BUCKET = 'anarbib-media-public';
const PREFIX = 'ocr';

// ── Resolution de la config ────────────────────────────────────────────
const envLocal = readEnvLocal(ROOT);
const SUPABASE_URL = process.env.VITE_SUPABASE_URL || envLocal.VITE_SUPABASE_URL;
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SERVICE_ROLE_KEY;

if (!SUPABASE_URL) {
  console.error('✗ VITE_SUPABASE_URL introuvable (.env.local ou env).');
  process.exit(1);
}
if (!SERVICE_ROLE) {
  console.error('✗ Cle service_role manquante. Lance avec :');
  console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/upload-ocr-assets.mjs');
  process.exit(1);
}

// Fichiers a deposer (memes que install-tesseract.sh ; pas les .js loaders Node).
const FILES = [
  { local: 'worker.min.js', remote: 'worker.min.js', type: 'text/javascript' },
  { local: 'tesseract-core-relaxedsimd-lstm.wasm.js', remote: 'tesseract-core-relaxedsimd-lstm.wasm.js', type: 'text/javascript' },
  { local: 'tesseract-core-simd-lstm.wasm.js', remote: 'tesseract-core-simd-lstm.wasm.js', type: 'text/javascript' },
  { local: 'tesseract-core-lstm.wasm.js', remote: 'tesseract-core-lstm.wasm.js', type: 'text/javascript' },
  { local: 'lang/por.traineddata.gz', remote: 'lang/por.traineddata.gz', type: 'application/gzip' },
  { local: 'VERSION', remote: 'VERSION', type: 'text/plain' },
];

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false, autoRefreshToken: false },
});

console.log(`▶ Upload assets OCR → ${BUCKET}/${PREFIX}/  (${SUPABASE_URL})`);

let ok = 0;
let fail = 0;
for (const f of FILES) {
  const localPath = resolve(SRC, f.local);
  if (!existsSync(localPath)) {
    console.error(`  ✗ absent localement: ${f.local} — lance d'abord scripts/install-tesseract.sh`);
    fail += 1;
    continue;
  }
  const body = readFileSync(localPath);
  const remotePath = `${PREFIX}/${f.remote}`;
  const { error } = await supabase.storage.from(BUCKET).upload(remotePath, body, {
    contentType: f.type,
    upsert: true,
    cacheControl: '604800', // 7 j — assets stables
  });
  if (error) {
    console.error(`  ✗ ${remotePath} : ${error.message}`);
    fail += 1;
  } else {
    console.log(`  ✓ ${remotePath} (${(body.length / 1024).toFixed(0)} Ko)`);
    ok += 1;
  }
}

const base = supabase.storage.from(BUCKET).getPublicUrl(PREFIX).data.publicUrl;
console.log(`\n${ok} uploades, ${fail} echecs.`);
console.log(`URL publique de base : ${base}`);
console.log('Verifie : curl -sI "' + base + '/worker.min.js"');
process.exit(fail ? 1 : 0);
