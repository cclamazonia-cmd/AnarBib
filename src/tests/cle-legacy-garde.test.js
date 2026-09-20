// ═══════════════════════════════════════════════════════════
// AnarBib — aucune Edge Function ne lit la clé legacy (B20, 20/09/2026)
//
// Le 02/09/2026 (B18), les clés legacy du projet ont été désactivées et le repli
// de `_shared/core/secret-key.ts` sur `SUPABASE_SERVICE_ROLE_KEY` a été retiré,
// avec un commentaire qui dit pourquoi : une clé morte ne mérite pas de chemin
// de code, et un repli vers elle masquerait une panne de `SUPABASE_SECRET_KEYS`
// au lieu de la dire (DOC-SILENCE-1). Quatre jours plus tard, la PR #28
// réintroduisait ce repli, de bonne foi (sommet `b5782ec1`, ligne 26 :
// `return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")`). Un commentaire n'avait
// pas suffi ; ceci est la garde.
//
// Ce qu'elle interdit : LIRE la variable d'environnement `SUPABASE_SERVICE_ROLE_KEY`
// dans `supabase/functions/**`. La clé secrète se lit par `secretKey()` /
// `mustSecretKey()` de `_shared/core/secret-key.ts`, un seul chemin pour tout le
// monde. Le 20/09, deux fonctions le contournaient encore (`opds`,
// `rss-novidades`, écrites après B18 sur le modèle d'avant) : elles passent par
// `secretKey()` dans le même commit que cette garde.
//
// Ce qu'elle n'interdit pas : un nom de constante locale (`const
// SUPABASE_SERVICE_ROLE_KEY = mustSecretKey()`), un message d'erreur, un
// commentaire. Ils sont trompeurs à la lecture mais ne lisent rien.
//
// Liste FERMÉE des fichiers autorisés à lire la variable : vide. Pour l'allonger,
// il faut une raison écrite ici et une entrée nommée dans `AUTORISES`.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'fs';
import { join, dirname, relative } from 'path';
import { fileURLToPath } from 'url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const RACINE = 'supabase/functions';

// Toute lecture d'environnement de la variable legacy, quelle que soit la forme :
// Deno.env.get('…'), env.get("…"), mustEnv('…'), getEnv(`…`), Deno.env.toObject().SUPABASE_SERVICE_ROLE_KEY.
export const LECTURE_LEGACY =
  /(?:env\s*\.\s*get|mustEnv|getEnv|requireEnv)\s*\(\s*['"`]SUPABASE_SERVICE_ROLE_KEY['"`]|toObject\s*\(\s*\)\s*(?:\.|\[\s*['"`])SUPABASE_SERVICE_ROLE_KEY/;

const AUTORISES = new Set([]);

function* fichiers(p) {
  const abs = join(ROOT, p);
  const st = statSync(abs);
  if (st.isDirectory()) {
    if (/(^|[\\/])node_modules$/.test(p)) return;
    for (const e of readdirSync(abs)) yield* fichiers(join(p, e));
  } else if (/\.(ts|tsx|js|mjs)$/.test(p)) yield p;
}

// Les lignes de commentaire ne lisent rien : on les retire avant de chercher.
function sansCommentaires(src) {
  return src
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split('\n')
    .filter((l) => !/^\s*\/\//.test(l))
    .join('\n');
}

describe('clé legacy — aucune lecture de SUPABASE_SERVICE_ROLE_KEY dans les Edge Functions', () => {
  const trouvees = [];
  for (const f of fichiers(RACINE)) {
    const rel = relative(ROOT, join(ROOT, f)).replace(/\\/g, '/');
    if (AUTORISES.has(rel)) continue;
    const src = sansCommentaires(readFileSync(join(ROOT, f), 'utf8'));
    src.split('\n').forEach((ligne, i) => {
      if (LECTURE_LEGACY.test(ligne)) trouvees.push(`${rel} : ${ligne.trim().slice(0, 120)}`);
    });
  }

  it('aucune fonction ne lit la variable legacy — passer par secretKey() / mustSecretKey()', () => {
    expect(trouvees).toEqual([]);
  });

  it('secret-key.ts ne connaît que SUPABASE_SECRET_KEYS', () => {
    const src = sansCommentaires(readFileSync(join(ROOT, RACINE, '_shared/core/secret-key.ts'), 'utf8'));
    expect(src).toMatch(/env\.get\(\s*["']SUPABASE_SECRET_KEYS["']\s*\)/);
    expect(src).not.toMatch(/SERVICE_ROLE/);
  });

  it('la garde reconnaît le repli que la PR #28 avait réintroduit, et ses variantes', () => {
    // La ligne 26 du secret-key.ts de b5782ec1 (06/09/2026), mot pour mot.
    expect(LECTURE_LEGACY.test('  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");')).toBe(true);
    expect(LECTURE_LEGACY.test("const k = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';")).toBe(true);
    expect(LECTURE_LEGACY.test('const k = mustEnv("SUPABASE_SERVICE_ROLE_KEY");')).toBe(true);
    expect(LECTURE_LEGACY.test('const k = Deno.env.toObject().SUPABASE_SERVICE_ROLE_KEY;')).toBe(true);
    // Et elle laisse passer ce qui ne lit rien.
    expect(LECTURE_LEGACY.test('const SUPABASE_SERVICE_ROLE_KEY = mustSecretKey();')).toBe(false);
    expect(LECTURE_LEGACY.test("throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');")).toBe(false);
  });

  it('la liste des fichiers autorisés reste vide', () => {
    expect(AUTORISES.size).toBe(0);
  });
});
