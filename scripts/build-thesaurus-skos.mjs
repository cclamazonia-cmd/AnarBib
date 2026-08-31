#!/usr/bin/env node
// ===========================================================================
// build-thesaurus-skos.mjs — le thésaurus en SKOS, à une adresse stable (H3)
// ---------------------------------------------------------------------------
// Écrit `public/thesaurus.ttl` et `public/thesaurus.jsonld`, embarqués dans
// `dist/` par Vite et servis par Codeberg Pages :
//
//   https://app.anarbib.org/thesaurus.ttl
//   https://app.anarbib.org/thesaurus.jsonld
//
// Jusqu'ici l'export SKOS n'existait que comme bouton de téléchargement sur la
// page catalogue : le contenu — y compris les alignements FICEDL en
// skos:exactMatch / skos:closeMatch — était juste, mais aucune machine ne
// pouvait le retrouver sans cliquer. Un alignement publié à une adresse
// stable est citable par les catalogues partenaires ; un téléchargement ne
// l'est pas.
//
// Même patron que build-catalogue-snapshot.mjs, et mêmes raisons :
//   - source : api.thesaurus_export_v1, la RPC déjà exposée à `anon` qui sert
//     le bouton public — rien ne part dans le fichier qui ne soit déjà public ;
//   - sérialisation : src/lib/skosExport.js, LE MÊME code que le bouton —
//     l'adresse stable et le téléchargement ne peuvent pas diverger ;
//   - lancé par `prebuild`, rafraîchi à chaque déploiement, aucun secret ;
//   - ÉCHEC VOLONTAIREMENT SILENCIEUX : API muette au moment du build →
//     on garde les fichiers existants et on ne casse pas le déploiement.
//
// La hiérarchie émise (skos:broader) est celle des sujets AnarBib entre eux.
// Côté FICEDL, seuls exact/close sortent — le vocabulaire de
// subject_ficedl_links ne connaît rien d'autre (pas de broadMatch), et c'est
// voulu tant que H2 n'a pas de réponse sur la hiérarchie de la source.
// ===========================================================================

import { writeFileSync, existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { toTurtle, toJsonLd } from '../src/lib/skosExport.js';

const ICI = dirname(fileURLToPath(import.meta.url));
const RACINE = resolve(ICI, '..');

// En CI, les VITE_* viennent de l'environnement du job. En local elles vivent
// dans .env.local, que Vite lit mais pas Node : on le lit donc nous-mêmes.
// L'environnement réel reste prioritaire.
function chargerEnvLocal() {
  for (const nom of ['.env.local', '.env']) {
    const chemin = resolve(RACINE, nom);
    if (!existsSync(chemin)) continue;
    for (const ligne of readFileSync(chemin, 'utf8').split(/\r?\n/)) {
      const m = ligne.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)$/i);
      if (!m) continue;
      const [, cle, brut] = m;
      if (process.env[cle]) continue;
      process.env[cle] = brut.trim().replace(/^["']|["']$/g, '');
    }
  }
}
chargerEnvLocal();

const URL_BASE = process.env.VITE_SUPABASE_URL;
const CLE_ANON = process.env.VITE_SUPABASE_ANON_KEY;

async function principal() {
  if (!URL_BASE || !CLE_ANON) {
    console.warn('[thesaurus-skos] VITE_SUPABASE_URL/ANON_KEY absents : fichiers existants conservés.');
    return;
  }
  let data;
  try {
    const rep = await fetch(`${URL_BASE}/rest/v1/rpc/thesaurus_export_v1`, {
      method: 'POST',
      headers: {
        apikey: CLE_ANON,
        Authorization: `Bearer ${CLE_ANON}`,
        'Content-Type': 'application/json',
        // La RPC vit dans le schéma `api`, pas `public`.
        'Content-Profile': 'api',
      },
      body: '{}',
    });
    if (!rep.ok) throw new Error(`HTTP ${rep.status}`);
    data = await rep.json();
  } catch (e) {
    console.warn(`[thesaurus-skos] API muette (${e.message}) : fichiers existants conservés, build intact.`);
    return;
  }
  const concepts = (data?.concepts || []).length;
  const alignes = (data?.concepts || []).filter((c) => (c.ficedl || []).length).length;
  if (!concepts) {
    console.warn('[thesaurus-skos] export vide : fichiers existants conservés.');
    return;
  }
  writeFileSync(resolve(RACINE, 'public', 'thesaurus.ttl'), toTurtle(data), 'utf8');
  writeFileSync(resolve(RACINE, 'public', 'thesaurus.jsonld'), toJsonLd(data), 'utf8');
  console.log(`[thesaurus-skos] écrit : ${concepts} concepts, dont ${alignes} alignés FICEDL → public/thesaurus.{ttl,jsonld}`);
}

await principal();
