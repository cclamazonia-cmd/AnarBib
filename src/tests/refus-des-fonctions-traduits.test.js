// ═══════════════════════════════════════════════════════════
// AnarBib — E24 (05/10/2026) : les refus des Edge Functions portent un code
// que l'écran traduit, pas une phrase en dur.
//
// attach-received-asset, deposit-fonds-direct et revoke-digital-asset
// répondaient en français (« Fichier déjà attaché. »), en portugais mêlé de
// français (« Recurso recebido … introuvável. ») ou en anglais ; la page
// Importations passait ce texte à localizeError, qui le rendait tel quel :
// une coordination qui travaille en grec lisait un refus en français.
// Désormais chaque refus passe par `refus(code, texte, statut)` ; l'écran en
// fait une Error par src/lib/edgeError.js (hint de la base d'abord, sinon
// error.edge.<code>). Modèle : `login` (3cf927e1).
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { erreurDeFonction, EDGE_KEY_PREFIX } from '@/lib/edgeError';
import { localizeError } from '@/lib/localizeError';

const RACINE = path.resolve(__dirname, '../..');
// Liste fermée : une fonction de plus dont l'écran affiche le refus y entre.
const FONCTIONS = ['attach-received-asset', 'deposit-fonds-direct', 'revoke-digital-asset'];
const LOC = path.resolve(RACINE, 'src/i18n/locales');
const locales = readdirSync(LOC).filter((f) => f.endsWith('.json'))
  .map((f) => [f, JSON.parse(readFileSync(path.join(LOC, f), 'utf8'))]);

const source = (f) => readFileSync(path.join(RACINE, 'supabase/functions', f, 'index.ts'), 'utf8');
const codesDe = (src) => {
  const codes = new Set();
  for (const m of src.matchAll(/refus\(\s*(?:restricted\s*\?\s*'([a-z_]+)'\s*:\s*'([a-z_]+)'|'([a-z_]+)')/g)) {
    for (const c of [m[1], m[2], m[3]]) if (c) codes.add(c);
  }
  return [...codes];
};

describe('E24 — les refus des fonctions de la page Importations', () => {
  for (const f of FONCTIONS) {
    it(`${f} : aucun refus ne sort sans code`, () => {
      const src = source(f);
      // La seule réponse { error } directe est celle de l'aide `refus` elle-même.
      const bruts = [...src.matchAll(/json\(\{\s*error\b/g)];
      expect(bruts).toHaveLength(1);
      expect(src).toMatch(/function refus\(code: string, error: string, status: number/);
      expect(codesDe(src).length).toBeGreaterThan(2);
    });
  }

  it('chaque code émis a son libellé dans les dix locales', () => {
    expect(locales).toHaveLength(10);
    const codes = new Set(FONCTIONS.flatMap((f) => codesDe(source(f))));
    expect([...codes].sort()).toEqual(expect.arrayContaining(['already_attached', 'auth_required', 'forbidden', 'no_eligible_record', 'server_error']));
    for (const [f, j] of locales) for (const c of codes) expect(j[EDGE_KEY_PREFIX + c], `${f} ${c}`).toBeTruthy();
  });

  it("l'écran n'affiche plus le texte brut d'une fonction de la page", () => {
    const page = readFileSync(path.join(RACINE, 'src/pages/importacoes/ImportacoesPage.jsx'), 'utf8');
    expect(page).not.toMatch(/throw new Error\(out\?\.error/);
    expect((page.match(/throw erreurDeFonction\(out, res\.status\)/g) || []).length).toBe(3);
  });
});

describe('E24 — erreurDeFonction', () => {
  const t = ({ id }) => (id.startsWith('error.') ? `T:${id}` : id);

  it('le code devient la clé error.edge.<code>, traduite', () => {
    const err = erreurDeFonction({ error: 'Fichier déjà attaché.', code: 'already_attached' }, 409);
    expect(err.hint).toBe('error.edge.already_attached');
    expect(localizeError(err, t)).toBe('T:error.edge.already_attached');
  });

  it('le hint de la base passe avant le code', () => {
    const err = erreurDeFonction({ error: 'Acesso restrito.', code: 'forbidden', hint: 'error.catalog.staff_only' }, 403);
    expect(localizeError(err, t)).toBe('T:error.catalog.staff_only');
  });

  it('sans code ni hint, le texte reste en repli ; sans corps, le statut', () => {
    expect(erreurDeFonction({ error: 'Texte libre.' }, 400).message).toBe('Texte libre.');
    expect(erreurDeFonction(null, 502).message).toBe('HTTP 502');
    expect(erreurDeFonction({ code: 'Pas Un Code' }, 400).hint).toBeUndefined();
  });
});
