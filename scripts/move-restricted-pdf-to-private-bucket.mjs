#!/usr/bin/env node
/**
 * move-restricted-pdf-to-private-bucket.mjs — replace les PDF catalogues comme
 * RESTREINTS dans le seau prive `pdf-restrito`.
 *
 * POURQUOI. Constate le 20/08/2026 sur le livre 1434 (BTL-TL-001528) : la fiche
 * declare `storage_bucket = 'pdf-restrito'`, mais le fichier avait ete verse
 * dans `anarbib-pdf-public` — un seau PUBLIC EN LECTURE. Deux consequences :
 *   - la lecture en ligne ne marchait pas (le fichier n'existe pas la ou la
 *     fiche le cherche : `file_exists = false`) ;
 *   - et le PDF etait en realite telechargeable par quiconque connaissant
 *     l'URL, alors qu'il est catalogue « restreint ».
 * La restriction n'est pas portee par le libelle : elle est portee par le seau.
 *
 * CE QUE FAIT LE SCRIPT. Pour chaque ressource `access_scope = 'conta_ativa'`
 * dont le fichier est absent du seau declare mais present dans un seau public :
 * copie vers le seau declare, VERIFIE la copie (taille identique), puis supprime
 * l'original public. Jamais l'inverse : on ne supprime qu'apres verification.
 *
 * ACTION PROD (outward-facing) : a lancer DELIBEREMENT, jamais en auto.
 *
 * Auth : cle SERVICE_ROLE (lecture d'un seau prive + suppression).
 *
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/move-restricted-pdf-to-private-bucket.mjs --dry-run
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/move-restricted-pdf-to-private-bucket.mjs
 *
 * SOUS WINDOWS / POWERSHELL, ne tape PAS les lignes ci-dessus : la syntaxe
 * `VAR=valeur commande` est propre a bash, et la cle finirait en clair dans
 * l'historique PowerShell. Utilise l'enrobage, qui la demande a une invite
 * masquee et l'efface ensuite :
 *
 *   .\scripts\with-service-role.ps1 scripts\move-restricted-pdf-to-private-bucket.mjs --dry-run
 *
 * Options :
 *   --dry-run   n'ecrit rien, montre ce qui serait deplace
 *   --keep      copie mais NE SUPPRIME PAS l'original (verification manuelle)
 *
 * Idempotent : une ressource deja en place est signalee « rien a faire ».
 */

import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
import { readEnvLocal } from './lib/env-local.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

const DRY = process.argv.includes('--dry-run');
const KEEP = process.argv.includes('--keep');

const envLocal = readEnvLocal(ROOT);
const SUPABASE_URL = process.env.VITE_SUPABASE_URL || envLocal.VITE_SUPABASE_URL;
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SERVICE_ROLE_KEY;

if (!SUPABASE_URL) {
  console.error('✗ VITE_SUPABASE_URL introuvable (.env.local ou env).');
  process.exit(1);
}
if (!SERVICE_ROLE) {
  console.error('✗ Cle service_role manquante. Lance avec :');
  console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/move-restricted-pdf-to-private-bucket.mjs --dry-run');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Seaux publics ou un fichier restreint a pu atterrir par erreur.
const SEAUX_PUBLICS = ['anarbib-pdf-public'];

console.log(`▶ PDF restreints mal places  (${SUPABASE_URL})${DRY ? '  [DRY-RUN]' : ''}`);

const { data: rows, error } = await supabase
  .from('book_digital_resources')
  .select('id, book_id, storage_bucket, storage_path, access_scope, status, is_active')
  .eq('access_scope', 'conta_ativa')
  .eq('status', 'active')
  .eq('is_active', true);

if (error) {
  console.error('✗ lecture des ressources :', error.message);
  process.exit(1);
}
if (!rows?.length) {
  console.log('  Aucune ressource restreinte active. Rien a faire.');
  process.exit(0);
}

/** Le fichier est-il present a cet emplacement ? (list sur le prefixe exact) */
async function existe(bucket, path) {
  const i = path.lastIndexOf('/');
  const dossier = i === -1 ? '' : path.slice(0, i);
  const nom = i === -1 ? path : path.slice(i + 1);
  const { data, error: e } = await supabase.storage.from(bucket).list(dossier, { search: nom, limit: 100 });
  if (e) return { ok: false, taille: null };
  const trouve = (data || []).find((o) => o.name === nom);
  return { ok: Boolean(trouve), taille: trouve?.metadata?.size ?? null };
}

let deplaces = 0, deja = 0, introuvables = 0, echecs = 0;

for (const r of rows) {
  const cible = await existe(r.storage_bucket, r.storage_path);
  if (cible.ok) {
    console.log(`  · #${r.id} (livre ${r.book_id}) deja dans ${r.storage_bucket} — rien a faire`);
    deja += 1;
    continue;
  }

  let sourceBucket = null;
  for (const b of SEAUX_PUBLICS) {
    if (b === r.storage_bucket) continue;
    const s = await existe(b, r.storage_path);
    if (s.ok) { sourceBucket = b; break; }
  }

  // Cas « bon seau, mauvais chemin » : le fichier a ete verse a la main dans le
  // seau prive, mais hors de la convention `books/<id>/<horodatage>_<nom>`.
  // Vecu le 20/08/2026 sur le livre 1434. On le remet dans la convention, dans
  // le MEME seau — un deplacement interne, pas une copie entre seaux.
  let traiteSurPlace = false;
  if (!sourceBucket) {
    const { data: candidats } = await supabase.storage.from(r.storage_bucket).list('', { limit: 1000 });
    const dossiers = (candidats || []).filter((o) => o.id === null).map((o) => o.name);
    for (const d of dossiers) {
      const { data: fichiers } = await supabase.storage.from(r.storage_bucket).list(d, { limit: 1000 });
      const pdf = (fichiers || []).find((f) => f.name.toLowerCase().endsWith('.pdf'));
      if (!pdf) continue;
      const actuel = `${d}/${pdf.name}`;
      if (actuel === r.storage_path) continue;
      console.log(`  ↺ #${r.id} (livre ${r.book_id}) : chemin hors convention dans ${r.storage_bucket}`);
      console.log(`      trouve  : ${actuel}`);
      console.log(`      attendu : ${r.storage_path}`);
      traiteSurPlace = true;
      if (DRY) { deplaces += 1; break; }
      const mv = await supabase.storage.from(r.storage_bucket).move(actuel, r.storage_path);
      if (mv.error) { console.error(`      ✗ deplacement : ${mv.error.message}`); echecs += 1; }
      else { console.log('      ✓ remis dans la convention'); deplaces += 1; }
      break;
    }
  }
  if (traiteSurPlace) continue;

  if (!sourceBucket) {
    console.error(`  ✗ #${r.id} (livre ${r.book_id}) INTROUVABLE : ni dans ${r.storage_bucket}, ni dans les seaux publics.`);
    console.error(`      chemin : ${r.storage_path}`);
    introuvables += 1;
    continue;
  }

  console.log(`  → #${r.id} (livre ${r.book_id}) : ${sourceBucket} → ${r.storage_bucket}`);
  console.log(`      ${r.storage_path}`);
  if (DRY) { deplaces += 1; continue; }

  const dl = await supabase.storage.from(sourceBucket).download(r.storage_path);
  if (dl.error || !dl.data) {
    console.error(`      ✗ telechargement : ${dl.error?.message || 'vide'}`);
    echecs += 1;
    continue;
  }
  const octets = Buffer.from(await dl.data.arrayBuffer());

  const up = await supabase.storage.from(r.storage_bucket).upload(r.storage_path, octets, {
    contentType: 'application/pdf',
    upsert: true,
  });
  if (up.error) {
    console.error(`      ✗ copie : ${up.error.message}`);
    echecs += 1;
    continue;
  }

  // On ne supprime QU'APRES avoir verifie que la copie est bien la, a la bonne taille.
  const verif = await existe(r.storage_bucket, r.storage_path);
  if (!verif.ok || (verif.taille != null && Number(verif.taille) !== octets.length)) {
    console.error(`      ✗ verification echouee (present=${verif.ok}, taille=${verif.taille} vs ${octets.length}) — original CONSERVE`);
    echecs += 1;
    continue;
  }
  console.log(`      ✓ copie verifiee (${(octets.length / 1048576).toFixed(1)} Mo)`);

  if (KEEP) {
    console.log('      · --keep : original public conserve, a supprimer a la main');
  } else {
    const rm = await supabase.storage.from(sourceBucket).remove([r.storage_path]);
    if (rm.error) {
      console.error(`      ✗ suppression de l'original public : ${rm.error.message}`);
      console.error('        LE PDF RESTE DONC EXPOSE PUBLIQUEMENT — a retirer a la main.');
      echecs += 1;
      continue;
    }
    console.log('      ✓ original public supprime');
  }
  deplaces += 1;
}

console.log(`\n${deplaces} deplacee(s), ${deja} deja en place, ${introuvables} introuvable(s), ${echecs} echec(s).`);
process.exit(echecs || introuvables ? 1 : 0);
