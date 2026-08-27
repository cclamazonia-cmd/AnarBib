#!/usr/bin/env node
/**
 * ficedl_thesaurus_sync.mjs — seed / re-sync de la table-cache du thésaurus FICEDL.
 *
 * Session : Intégration thésaurus FICEDL P1 (table-cache + seed)
 * Auteur  : AnarBib
 *
 * Charge le JSON déjà aspiré (docs/journal/ficedl/ficedl_thesaurus_<date>.json) et
 * UPSERT chaque descripteur TRADUIT dans public.ficedl_thesaurus_terms.
 *
 * POLITIQUE ANTI-FORK : la source de vérité reste le SPIP FICEDL. Ce script ne fait
 * que CACHER une copie ré-aspirable. Les libellés sont chargés TELS QU'ASPIRÉS —
 * aucune normalisation, aucune charte inclusive appliquée. Le re-routage des balises
 * de langue erronées (déjà fait à l'aspiration) est conservé dans `import_normalizations`.
 *
 * Sélection : toute fiche qui porte un NOM est seedée. Deux cas :
 *   — fiche traduite (sujets, geo) : le bloc `labels` fournit les 10 langues ;
 *   — fiche SANS bloc de traduction (facette "dates", 158 fiches) : son H1 est
 *     son libellé canonique, en français, et devient `labels.fr`.
 *
 * Ce second cas n'est PAS un fork : sur le SPIP FICEDL, le français est la langue
 * source, jamais une traduction. Écrire le H1 dans `labels.fr` dit donc la vérité —
 * « nous connaissons son nom français » — et rien de plus. La distinction réelle,
 * « cette fiche n'a aucun bloc de traduction », reste portée par le drapeau
 * `no_translation_block` que l'aspiration pose déjà dans `import_flags`. C'est le
 * mécanisme prévu pour ça, il existe, et il survit à l'upsert.
 *
 * Re-sync (P4) : ré-exécuter ce script après un nouveau harvest met simplement à jour
 * les lignes (upsert sur mot_id). Les termes disparus de la source NE sont PAS supprimés
 * par défaut (passer --prune pour les retirer).
 *
 * Auth : nécessite une clé SERVICE_ROLE (écriture ; aucune policy write publique sur la
 * table — service_role bypass la RLS). La clé n'est PAS dans .env.local. Usage :
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/ficedl_thesaurus_sync.mjs
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/ficedl_thesaurus_sync.mjs --dry-run
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/ficedl_thesaurus_sync.mjs --prune
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/ficedl_thesaurus_sync.mjs --json path/to.json
 * VITE_SUPABASE_URL est lu depuis .env.local automatiquement.
 */

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
import { readEnvLocal } from './lib/env-local.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const JOURNAL_DIR = resolve(ROOT, 'docs/journal/ficedl');
const TABLE = 'ficedl_thesaurus_terms';
const BATCH = 100;
const LOCALES = ['fr', 'ca', 'de', 'el', 'en', 'eo', 'es', 'it', 'nl', 'pt'];

// ── Arguments ──────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const DRY_RUN = argv.includes('--dry-run');
const PRUNE = argv.includes('--prune');
const jsonFlagIdx = argv.indexOf('--json');
const jsonArg = jsonFlagIdx !== -1 ? argv[jsonFlagIdx + 1] : null;

// ── Resolution de la config (même convention que les autres scripts) ────
const envLocal = readEnvLocal(ROOT);
const SUPABASE_URL = process.env.VITE_SUPABASE_URL || envLocal.VITE_SUPABASE_URL;
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SERVICE_ROLE_KEY;

// ── Localisation du JSON aspiré ─────────────────────────────────────────
function resolveJsonPath() {
  if (jsonArg) return resolve(process.cwd(), jsonArg);
  // Sinon : le plus récent ficedl_thesaurus_*.json du dossier journal.
  const candidates = existsSync(JOURNAL_DIR)
    ? readdirSync(JOURNAL_DIR)
        .filter((f) => /^ficedl_thesaurus_.*\.json$/.test(f))
        .sort()
    : [];
  if (!candidates.length) return null;
  return resolve(JOURNAL_DIR, candidates[candidates.length - 1]);
}

/**
 * Vrai si la fiche porte un nom exploitable — donc seedable.
 * Soit un bloc `labels` non vide, soit, à défaut, le H1 relevé à l'aspiration.
 */
export function isSyncable(rec) {
  if (!rec) return false;
  if (rec.labels && Object.keys(rec.labels).length > 0) return true;
  return typeof rec.title_fr === 'string' && rec.title_fr.trim() !== '';
}

// ── Mapping JSON → ligne de table (anti-fork : aucune réécriture) ───────
export function toRow(rec, harvestedAt) {
  const labels = { ...(rec.labels || {}) };
  // el_roman vit DANS labels à l'aspiration → on le sort dans sa colonne dédiée.
  const elRoman = labels.el_roman ?? null;
  delete labels.el_roman;
  // Fiche sans bloc de traduction : son H1 est son libellé français canonique.
  // On ne l'écrit QUE si `labels` est vide — sur une fiche traduite, le H1 peut
  // être une forme précoordonnée différente du bloc, et l'écraser serait un fork.
  if (Object.keys(labels).length === 0
      && typeof rec.title_fr === 'string' && rec.title_fr.trim() !== '') {
    labels.fr = rec.title_fr.trim();
  }
  return {
    mot_id: rec.id,
    facet: Array.isArray(rec.facet) ? rec.facet : [],
    labels, // 10 langues, JSON creux, TELS QU'ASPIRÉS
    el_roman: elRoman,
    hierarchy: Array.isArray(rec.hierarchy) ? rec.hierarchy : [],
    depth: Number.isInteger(rec.depth) ? rec.depth : null,
    catalog_links: Array.isArray(rec.catalog_links) ? rec.catalog_links : [],
    import_normalizations: Array.isArray(rec.normalizations) ? rec.normalizations : [],
    import_flags: Array.isArray(rec.flags) ? rec.flags : [],
    source_url: rec.url,
    harvested_at: harvestedAt,
  };
}

async function main() {
  if (!SUPABASE_URL) {
    console.error('✗ VITE_SUPABASE_URL introuvable (.env.local ou env).');
    process.exit(1);
  }
  if (!SERVICE_ROLE && !DRY_RUN) {
    console.error('✗ Clé service_role manquante. Lance avec :');
    console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/ficedl_thesaurus_sync.mjs');
    process.exit(1);
  }

  const jsonPath = resolveJsonPath();
  if (!jsonPath || !existsSync(jsonPath)) {
    console.error('✗ JSON du thésaurus introuvable (docs/journal/ficedl/ficedl_thesaurus_*.json ou --json).');
    process.exit(1);
  }

  const all = JSON.parse(readFileSync(jsonPath, 'utf8'));
  if (!Array.isArray(all)) {
    console.error('✗ Format JSON inattendu : un tableau d\'enregistrements est attendu.');
    process.exit(1);
  }

  // Toute fiche qui porte un nom : bloc `labels`, ou H1 à défaut.
  const syncable = all.filter(isSyncable);
  const skipped = all.length - syncable.length;
  const parH1 = syncable.filter((r) => !r.labels || Object.keys(r.labels).length === 0).length;

  // harvested_at : horodatage de ce run de sync (approx. de l'aspiration courante).
  const harvestedAt = new Date().toISOString();
  const rows = syncable.map((r) => toRow(r, harvestedAt));

  console.log(`▶ Sync thésaurus FICEDL → ${TABLE}  (${SUPABASE_URL})`);
  console.log(`  Source        : ${jsonPath}`);
  console.log(`  Total fiches  : ${all.length}`);
  console.log(`  À seeder      : ${rows.length}`);
  console.log(`    dont par H1 : ${parH1} (sans bloc de traduction — libellé fr seul)`);
  console.log(`  Exclues       : ${skipped} (aucun nom exploitable)`);

  if (DRY_RUN) {
    console.log('  [DRY RUN] aucun écrit. Aperçu de la première ligne :');
    console.log(JSON.stringify(rows[0], null, 2));
    return;
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let upserted = 0;
  for (let i = 0; i < rows.length; i += BATCH) {
    const chunk = rows.slice(i, i + BATCH);
    const { error } = await supabase.from(TABLE).upsert(chunk, { onConflict: 'mot_id' });
    if (error) {
      console.error(`✗ Échec upsert lot ${i}-${i + chunk.length} : ${error.message}`);
      process.exit(1);
    }
    upserted += chunk.length;
    console.log(`  … ${upserted}/${rows.length}`);
  }

  if (PRUNE) {
    const keepIds = rows.map((r) => r.mot_id);
    const { data: existing, error: selErr } = await supabase.from(TABLE).select('mot_id');
    if (selErr) {
      console.error(`✗ Échec lecture pour --prune : ${selErr.message}`);
      process.exit(1);
    }
    const stale = existing.map((r) => r.mot_id).filter((id) => !keepIds.includes(id));
    if (stale.length) {
      const { error: delErr } = await supabase.from(TABLE).delete().in('mot_id', stale);
      if (delErr) {
        console.error(`✗ Échec suppression --prune : ${delErr.message}`);
        process.exit(1);
      }
      console.log(`  ✂ --prune : ${stale.length} terme(s) disparu(s) de la source supprimé(s).`);
    } else {
      console.log('  ✂ --prune : aucun terme obsolète.');
    }
  }

  console.log(`✓ Terminé : ${upserted} terme(s) upsertés.`);
}

// Le module est importé par src/tests/ficedl-thesaurus-sync.test.js : on ne
// déclenche `main()` que si le script est lancé directement.
const lanceDirectement =
  process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (lanceDirectement) {
  main().catch((e) => {
    console.error('✗ Erreur inattendue :', e);
    process.exit(1);
  });
}
