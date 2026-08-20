/**
 * Lecture de .env.local pour les scripts Node du depot.
 *
 * Vite lit .env.local tout seul ; Node non. Les scripts d'administration
 * (upload-*, ficedl_*) ont donc besoin de le lire eux-memes pour recuperer
 * VITE_SUPABASE_URL. Cette fonction etait dupliquee dans quatre scripts, ce
 * qui a coute deux fois la meme correction : elle vit ici desormais.
 *
 * Deux pieges, tous deux rencontres pour de vrai :
 *
 * 1. CRLF. Le .env.local du depot est en CRLF. En splittant sur '\n', le \r
 *    final reste colle a chaque ligne ; comme '.' ne matche pas \r en
 *    JavaScript, /^([A-Z0-9_]+)=(.*)$/ echoue et AUCUNE cle n'est extraite.
 *    Le script s'arrete alors sur « VITE_SUPABASE_URL introuvable » alors que
 *    la variable est bien la. D'ou le split sur /\r?\n/.
 *
 * 2. Chiffres dans les noms de cles. Les anciennes copies utilisaient
 *    [A-Z_]+, qui ignore silencieusement une cle du genre VITE_S3_BUCKET.
 *    Meme mode de panne que le CRLF : invisible et trompeur. D'ou [A-Z0-9_]+.
 *
 * Ne lit QUE .env.local, et ne touche pas a process.env : c'est a l'appelant
 * de decider de la priorite (partout dans le depot : l'environnement reel
 * d'abord, .env.local en repli).
 */

import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

/** Racine du depot, deduite de l'emplacement de ce fichier (scripts/lib/). */
export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

/**
 * @param {string} [root] racine ou chercher .env.local (defaut : racine du depot)
 * @returns {Record<string, string>} les cles trouvees, {} si le fichier est absent
 */
export function readEnvLocal(root = ROOT) {
  const p = resolve(root, '.env.local');
  if (!existsSync(p)) return {};
  const out = {};
  for (const line of readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m) out[m[1]] = m[2].trim();
  }
  return out;
}
