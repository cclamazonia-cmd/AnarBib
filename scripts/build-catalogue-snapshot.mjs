#!/usr/bin/env node
// ===========================================================================
// build-catalogue-snapshot.mjs — instantané du catalogue public (mode dégradé)
// ---------------------------------------------------------------------------
// Écrit `public/catalogue-snapshot.json`, embarqué tel quel dans `dist/` par
// Vite. Le front bascule dessus quand l'API ne répond plus (cf.
// src/lib/catalogueFallback.js) : la recherche et la consultation du catalogue
// restent possibles même si Supabase est indisponible, puisque Codeberg Pages,
// lui, sert un site statique.
//
// Lancé automatiquement par `npm run build` (script `prebuild`), donc
// l'instantané se rafraîchit à chaque déploiement — aucun cron, aucun secret et
// aucun pipeline de publication supplémentaire.
//
// ÉCHEC VOLONTAIREMENT SILENCIEUX : si l'API ne répond pas au moment du build,
// on n'écrase pas l'instantané existant et on ne casse SURTOUT pas le build.
// Un mode dégradé qui empêcherait de déployer serait une belle ironie.
//
// Source : api.catalog_list_anon_v1 — la vue catalogue déjà exposée à `anon`,
// donc exactement ce qu'un visiteur non connecté a le droit de voir. On ne
// fabrique pas une vue dédiée : ce qui part dans un fichier statique public ne
// doit rien contenir de plus que ce qui est déjà public.
// ===========================================================================

import { writeFileSync, existsSync, mkdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ICI = dirname(fileURLToPath(import.meta.url));
const RACINE = resolve(ICI, '..');
const SORTIE = resolve(RACINE, 'public', 'catalogue-snapshot.json');
const PAGE = 1000;

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

const URL_BASE = (process.env.VITE_SUPABASE_URL || '').replace(/\/+$/, '');
const CLE_ANON = process.env.VITE_SUPABASE_ANON_KEY || '';

// Champs retenus : de quoi chercher et afficher une notice lisible. On écarte
// volontairement le superflu pour garder le fichier léger (il est téléchargé
// par chaque navigateur qui bascule en mode dégradé).
const CHAMPS = [
  'book_id', 'bib_ref', 'titulo', 'subtitulo', 'autor', 'author_display',
  'ano', 'editora', 'publisher_display', 'local_publicacao', 'edicao',
  'isbn', 'issn', 'idioma', 'cdd', 'colecao', 'assuntos', 'tipo_material',
  'cover_object_path', 'loanable', 'global_available_count',
  'global_exemplares_total', 'bibliotecas_count', 'holding_library_names_json',
].join(',');

function abandon(raison) {
  console.warn(`[snapshot] ignoré : ${raison}`);
  console.warn('[snapshot] le build continue ; l\'instantané existant (le cas échéant) est conservé.');
  process.exit(0);
}

if (!URL_BASE || !CLE_ANON) {
  abandon('VITE_SUPABASE_URL ou VITE_SUPABASE_ANON_KEY absent de l\'environnement');
}

const entetes = {
  apikey: CLE_ANON,
  Authorization: `Bearer ${CLE_ANON}`,
  'Accept-Profile': 'api',
};

const livres = [];
try {
  for (let debut = 0; ; debut += PAGE) {
    const url =
      `${URL_BASE}/rest/v1/catalog_list_anon_v1` +
      `?select=${CHAMPS}&order=titulo.asc&limit=${PAGE}&offset=${debut}`;
    const r = await fetch(url, { headers: entetes });
    if (!r.ok) abandon(`HTTP ${r.status} sur catalog_list_anon_v1 — ${(await r.text()).slice(0, 200)}`);
    const lot = await r.json();
    if (!Array.isArray(lot)) abandon('réponse inattendue (tableau attendu)');
    livres.push(...lot);
    if (lot.length < PAGE) break;
  }
} catch (e) {
  abandon(String(e?.message ?? e));
}

if (!livres.length) abandon('catalogue vide — on préfère garder l\'instantané précédent');

const contenu = {
  genere_le: new Date().toISOString(),
  source: 'api.catalog_list_anon_v1',
  nombre: livres.length,
  livres,
};

mkdirSync(dirname(SORTIE), { recursive: true });
writeFileSync(SORTIE, JSON.stringify(contenu));
const ko = (existsSync(SORTIE) ? Buffer.byteLength(JSON.stringify(contenu)) : 0) / 1024;
console.log(`[snapshot] ${livres.length} notices écrites dans public/catalogue-snapshot.json (${ko.toFixed(0)} ko)`);
