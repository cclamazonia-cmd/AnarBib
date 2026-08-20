#!/usr/bin/env node
/**
 * upload-library-privacy.mjs — dépose les addenda de confidentialité par
 * bibliothèque dans le bucket public Supabase `library-privacy-public/`.
 *
 * Source versionnée : docs/legal/library-privacy/<slug>/privacy-<locale>.md
 * Destination        : library-privacy-public/<slug>/privacy-<locale>.md
 * Lecture front      : src/components/privacy/LibraryPrivacySection.jsx
 *
 * ACTION PROD (outward-facing) : à lancer DÉLIBÉRÉMENT, jamais en auto.
 *
 * Auth : nécessite une clé SERVICE_ROLE (l'INSERT sur le bucket exige
 * service_role, qui bypass la RLS). La clé n'est PAS dans .env.local (seule
 * l'anon y est). Fournis-la à l'exécution, elle n'est pas persistée :
 *
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/upload-library-privacy.mjs
 *
 * Optionnel — limiter à une biblio :
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/upload-library-privacy.mjs blmf
 *
 * VITE_SUPABASE_URL est lu depuis .env.local automatiquement.
 * Idempotent (upsert) : relançable sans dommage.
 */
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
import { readEnvLocal } from './lib/env-local.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = resolve(ROOT, 'docs/legal/library-privacy');
const BUCKET = 'library-privacy-public';
const ONLY_SLUG = process.argv[2] || null;

const envLocal = readEnvLocal(ROOT);
const SUPABASE_URL = process.env.VITE_SUPABASE_URL || envLocal.VITE_SUPABASE_URL;
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SERVICE_ROLE_KEY;

if (!SUPABASE_URL) {
  console.error('✗ VITE_SUPABASE_URL introuvable (.env.local ou env).');
  process.exit(1);
}
if (!SERVICE_ROLE) {
  console.error('✗ Clé service_role manquante. Lance avec :');
  console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/upload-library-privacy.mjs');
  process.exit(1);
}
if (!existsSync(SRC)) {
  console.error(`✗ dossier source absent: ${SRC}`);
  process.exit(1);
}

// Découverte : docs/legal/library-privacy/<slug>/privacy-<locale>.md
const tasks = [];
for (const slug of readdirSync(SRC)) {
  if (ONLY_SLUG && slug !== ONLY_SLUG) continue;
  const slugDir = join(SRC, slug);
  if (!statSync(slugDir).isDirectory()) continue;
  for (const file of readdirSync(slugDir)) {
    if (!/^privacy-[A-Za-z-]+\.md$/.test(file)) continue;
    tasks.push({ remotePath: `${slug}/${file}`, localPath: join(slugDir, file) });
  }
}

if (!tasks.length) {
  console.error('✗ aucun fichier privacy-*.md trouvé.');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false, autoRefreshToken: false },
});

console.log(`▶ Upload addenda confidentialité → ${BUCKET}/  (${SUPABASE_URL})`);

let ok = 0;
let fail = 0;
for (const t of tasks) {
  const body = readFileSync(t.localPath);
  const { error } = await supabase.storage.from(BUCKET).upload(t.remotePath, body, {
    contentType: 'text/markdown', // bucket allowed_mime_types = {text/markdown, text/plain} (match exact, pas de ; charset)
    upsert: true,
    cacheControl: '300', // 5 min — contenu légal susceptible d'évoluer
  });
  if (error) {
    console.error(`  ✗ ${t.remotePath} : ${error.message}`);
    fail += 1;
  } else {
    console.log(`  ✓ ${t.remotePath} (${(body.length / 1024).toFixed(1)} Ko)`);
    ok += 1;
  }
}

console.log(`\n${ok} uploadés, ${fail} échecs.`);
process.exit(fail ? 1 : 0);
