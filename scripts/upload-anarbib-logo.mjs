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
 * SOUS WINDOWS / POWERSHELL, ne tape PAS la ligne ci-dessus : la syntaxe
 * `VAR=valeur commande` est propre a bash, et la cle finirait en clair dans
 * l'historique PowerShell. Utilise l'enrobage, qui la demande a une invite
 * masquee et l'efface ensuite :
 *
 *   .\scripts\with-service-role.ps1 scripts\upload-anarbib-logo.mjs
 *
 * Options :
 *   --dry-run    n'ecrit rien, liste ce qui serait pousse
 *   --no-backup  saute la sauvegarde locale de l'existant (deconseille)
 *
 * Chaque fichier part sous DEUX noms : versionne (logo-v2.svg, cache un an, ce
 * que le manifeste reference) et nu (logo.svg, alias stable pour les URLs en
 * dur, cache une heure). Le script repointe aussi themes/default/manifest.json.
 * Pour publier un nouveau dessin : incrementer ASSET_VERSION, puis relancer.
 *
 * Idempotent (upsert) : relancable sans dommage.
 */

import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
import { readEnvLocal } from './lib/env-local.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = resolve(ROOT, 'public/img');
const BUCKET = 'library-ui-assets';
const PREFIX = 'themes/default';
const BACKUP = resolve(ROOT, '_handoff/logo-storage-avant-remplacement');

const DRY = process.argv.includes('--dry-run');
const NO_BACKUP = process.argv.includes('--no-backup');

const envLocal = readEnvLocal(ROOT);
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

// ── Noms versionnes ─────────────────────────────────────────────────────
// Convention deja en place cote BLMF (logo-v2.png, favicon-v3.png) : le nom
// du fichier porte sa generation. C'est la seule parade fiable au cache.
//
// Sans ca, remplacer un asset EN PLACE laisse l'ancienne copie vivre jusqu'a
// une heure (cacheControl: 3600) chez chaque visiteur et dans le CDN — d'ou le
// bricolage historique du `?v=<timestamp>` colle a la main. Avec un nom neuf,
// l'URL change : il n'y a plus rien a invalider, et l'ancienne generation reste
// accessible (retour arriere immediat en repointant le manifeste).
//
// POUR CHANGER LE LOGO : incrementer ASSET_VERSION, puis relancer le script. Il
// pousse sous les nouveaux noms ET repointe le manifeste dessus. Ne JAMAIS
// re-pousser une version deja publiee avec des octets differents : ca reintroduit
// exactement le probleme que le versionnement supprime.
//
// CHAQUE FICHIER EST POUSSE DEUX FOIS, et c'est deliberé :
//   - sous son nom VERSIONNE (logo-v2.svg), cacheable un an puisque ce nom ne
//     designera jamais d'autres octets. C'est ce que le manifeste reference,
//     donc ce que l'app sert : plus jamais de logo perime ;
//   - sous son nom NU (logo.svg), alias stable pour les consommateurs qui ne
//     lisent pas le manifeste et pointent une URL en dur. Le seul aujourd'hui
//     est supabase/functions/register/index.ts, qui inline logo-anarbib.png en
//     data URI dans les mails. Ne pousser QUE des noms versionnes le figerait
//     sur l'ancien dessin, en silence — le genre de panne qu'on ne voit qu'en
//     recevant un mail six mois plus tard. L'alias garde le cache d'une heure,
//     sans consequence : le mail telecharge et inline l'image a l'envoi.
//
// v1 = generation implicite, celle d'avant l'introduction des noms versionnes.
const ASSET_VERSION = 'v2';

/** 'logo.svg' + 'v2' -> 'logo-v2.svg' */
function versioned(name) {
  const dot = name.lastIndexOf('.');
  return `${name.slice(0, dot)}-${ASSET_VERSION}${name.slice(dot)}`;
}

// Ce qui est pousse. On NE touche PAS a bg.webp (fond de page) ni aux polices.
// `manifest.json`, lui, est desormais mis a jour : avec des noms versionnes il
// DOIT l'etre, sinon il continuerait de pointer sur la generation precedente.
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

// Cles du manifeste a repointer, et le fichier (nom nu) qui les alimente.
const MANIFEST_ASSETS = { logo: 'logo.svg', favicon: 'favicon.png' };

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE || 'dry', {
  auth: { persistSession: false, autoRefreshToken: false },
});

console.log(`▶ Logo AnarBib → ${BUCKET}/${PREFIX}/  (${SUPABASE_URL})${DRY ? '  [DRY-RUN]' : ''}`);

// ── Sauvegarde de l'existant ────────────────────────────────────────────
// On sauve les noms NUS (ceux qui sont ecrases) et le manifeste (reecrit en
// place). Les noms versionnes, eux, n'ecrasent rien par construction : ils
// n'ont pas besoin d'etre sauves, et l'ancienne generation reste en ligne.
if (!NO_BACKUP && !DRY) {
  mkdirSync(BACKUP, { recursive: true });
  {
    const url = supabase.storage.from(BUCKET).getPublicUrl(`${PREFIX}/manifest.json`).data.publicUrl;
    const r = await fetch(`${url}?t=${Date.now()}`, { cache: 'no-store' });
    if (r.ok) {
      writeFileSync(resolve(BACKUP, 'manifest.json'), Buffer.from(await r.arrayBuffer()));
      console.log('  ↓ sauvegarde manifest.json  (a reposer tel quel pour revenir en arriere)');
    } else {
      console.log(`  · manifeste illisible (${r.status}) : rien a sauver`);
    }
  }
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
  const ko = (body.length / 1024).toFixed(1);

  // Deux depots par fichier — cf. le commentaire d'ASSET_VERSION.
  const cibles = [
    // Nom versionne : ce nom ne designera jamais d'autres octets, donc un an de
    // cache (immutable de fait). C'est ce que le manifeste reference.
    { path: `${PREFIX}/${versioned(f.remote)}`, cache: '31536000' },
    // Alias nu : ecrase a chaque generation, donc cache court.
    { path: `${PREFIX}/${f.remote}`, cache: '3600' },
  ];

  for (const cible of cibles) {
    if (DRY) {
      console.log(`  ~ ${cible.path} ← public/img/${f.local} (${ko} Ko, cache ${cible.cache}s)`);
      ok += 1;
      continue;
    }
    const { error } = await supabase.storage.from(BUCKET).upload(cible.path, body, {
      contentType: f.type,
      upsert: true,
      cacheControl: cible.cache,
    });
    if (error) { console.error(`  ✗ ${cible.path} : ${error.message}`); fail += 1; }
    else { console.log(`  ✓ ${cible.path} (${ko} Ko, cache ${cible.cache}s)`); ok += 1; }
  }
}

// ── Repointage du manifeste ─────────────────────────────────────────────
// Etape indissociable de la precedente : les assets viennent d'arriver sous des
// noms neufs, personne ne les sert tant que le manifeste designe les anciens.
// On ne le reecrit donc QUE si les depots ont tous reussi.
if (fail === 0) {
  const remotePath = `${PREFIX}/manifest.json`;
  const url = supabase.storage.from(BUCKET).getPublicUrl(remotePath).data.publicUrl;
  const r = await fetch(`${url}?t=${Date.now()}`, { cache: 'no-store' });
  if (!r.ok) {
    console.error(`\n  ✗ manifeste illisible (${r.status}) : assets pousses mais NON references.`);
    fail += 1;
  } else {
    const manifest = await r.json();
    manifest.assets = manifest.assets || {};
    console.log('\n▶ Manifeste :');
    for (const [cle, nomNu] of Object.entries(MANIFEST_ASSETS)) {
      const neuf = supabase.storage.from(BUCKET)
        .getPublicUrl(`${PREFIX}/${versioned(nomNu)}`).data.publicUrl;
      const avant = manifest.assets[cle];
      manifest.assets[cle] = neuf;
      console.log(`  ${avant === neuf ? '=' : '~'} assets.${cle}`);
      if (avant !== neuf) console.log(`      ${avant || '(absent)'}\n   -> ${neuf}`);
    }
    if (DRY) {
      console.log('  [DRY-RUN] manifeste non reecrit.');
    } else {
      const { error } = await supabase.storage.from(BUCKET).upload(
        remotePath,
        Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`, 'utf8'),
        {
          contentType: 'application/json',
          upsert: true,
          // JAMAIS de cache sur le manifeste : c'est lui qui porte l'indirection.
          // S'il est mis en cache une heure, le versionnement des assets ne sert
          // a rien — les navigateurs continueraient de lire l'ancien pointage.
          cacheControl: 'no-cache',
        },
      );
      if (error) { console.error(`  ✗ manifest.json : ${error.message}`); fail += 1; }
      else { console.log('  ✓ manifest.json repointe'); }
    }
  }
}

const base = supabase.storage.from(BUCKET).getPublicUrl(PREFIX).data.publicUrl;
console.log(`\n${ok} pousses, ${fail} echecs.`);
console.log(`Base publique : ${base}`);
if (!DRY) {
  console.log(`Verifie :  curl -sI "${base}/${versioned('logo.svg')}"`);
  console.log('Plus de ?v= a coller : le nom porte la generation, l\'URL change avec elle.');
}
process.exit(fail ? 1 : 0);
