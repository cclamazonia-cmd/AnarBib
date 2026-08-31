// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/mail-footer-regimento.test.js
//
// Le pied de page des courriels affichait un lien « Règlement » construit à
// partir d'une variable d'environnement globale. Elle était vide, ses deux
// replis n'existaient pas : la ligne n'a JAMAIS été affichée dans un seul
// message envoyé par le réseau (item F7).
//
// Elle supposait de surcroît un règlement unique, du réseau — qui n'existe pas
// et n'existera pas : ce sont les bibliothèques qui définissent le leur. Le
// lien vient donc désormais du règlement publié et actif de CHAQUE
// bibliothèque, annoncé par `v_library_notification_context`.
//
// Ce test exerce le VRAI `footerPadrao` (esbuild en mémoire, imports stubés)
// sur les deux contextes relevés en base le 31/08 : la BLMF, qui a un
// règlement publié, et une bibliothèque qui n'en a pas. Le cas « pas de
// règlement » est le plus important : il doit rendre AUCUNE ligne — pas une
// ligne vide, pas un lien mort.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const R = new URL('../../supabase/functions/_shared/', import.meta.url);

function charger(rel, stubs) {
  const code = transformSync(readFileSync(new URL(rel, R), 'utf8'), {
    loader: 'ts', format: 'cjs', target: 'es2022',
  }).code;
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', code)(stubs, mod, mod.exports);
  return mod.exports;
}

const PROJET = 'https://exemple.supabase.co';
const envStub = {
  ADMIN_EMAIL: 'a@x.org', ADMIN_NAME: 'Coord', LOGO_URL: '', LIBRARIAN_PHONE: '',
  SENDER_EMAIL: 'no-reply@x.org', SENDER_NAME: 'AnarBib',
  supabaseAdmin: {
    storage: {
      from: (b) => ({
        getPublicUrl: (k) => ({ data: { publicUrl: `${PROJET}/storage/v1/object/public/${b}/${k}` } }),
      }),
    },
  },
};
const brandingStub = {
  replaceBrandTokens: (t) => t,
  resolvedBrandName: (c) => c?.library_short_name || 'AnarBib',
  resolvedSubjectTag: (c) => c?.library_short_name || 'AnarBib',
};

function charherLayout() {
  const i18n = charger('i18n/mail-strings.ts', () => ({}));
  const routing = charger('context/library-mail-routing.ts', (spec) => {
    if (spec.includes('core/env')) return envStub;
    if (spec.includes('shared/branding')) return brandingStub;
    if (spec.includes('i18n/mail-strings')) return i18n;
    throw new Error(`import inattendu : ${spec}`);
  });
  return charger('mail/layout.ts', (spec) => {
    if (spec.includes('core/env')) return envStub;
    if (spec.includes('context/library-mail-routing')) return routing;
    if (spec.includes('shared/format')) return { esc: (t) => String(t ?? '') };
    if (spec.includes('i18n/mail-strings')) return i18n;
    throw new Error(`import inattendu : ${spec}`);
  });
}

// Relevés dans v_library_notification_context le 31/08/2026.
const AVEC = {
  library_short_name: 'BLMF',
  regulation_bucket: 'library-regimentos-public',
  regulation_path: 'regimentos/blmf/1777322365774-regimento-atual.pdf',
};
const SANS = { library_short_name: 'BTL', regulation_bucket: null, regulation_path: null };

describe('le pied de page renvoie au règlement de la bibliothèque', () => {
  it('affiche le lien quand la bibliothèque a un règlement publié', () => {
    const { footerPadrao } = charherLayout();
    const fr = footerPadrao(AVEC, 'fr');
    expect(fr).toContain('library-regimentos-public');
    expect(fr).toContain('regimento-atual.pdf');
    expect(fr).toContain('Règlement');
  });

  it("n'affiche RIEN quand elle n'en a pas", () => {
    const { footerPadrao } = charherLayout();
    const fr = footerPadrao(SANS, 'fr');
    expect(fr).not.toContain('href=');
    expect(fr).not.toContain('Règlement');
  });

  it('ne casse pas sans contexte du tout', () => {
    const { footerPadrao } = charherLayout();
    const fr = footerPadrao(null, 'fr');
    expect(typeof fr).toBe('string');
    expect(fr).not.toContain('href=');
  });

  it('traduit le texte du lien, qui était en dur en portugais', () => {
    const { footerPadrao } = charherLayout();
    expect(footerPadrao(AVEC, 'fr')).toContain('>ouvrir<');
    expect(footerPadrao(AVEC, 'pt-BR')).toContain('>abrir<');
    expect(footerPadrao(AVEC, 'el')).toContain('>άνοιγμα<');
    // Le portugais ne doit plus fuir dans les autres langues.
    expect(footerPadrao(AVEC, 'de')).not.toContain('>abrir<');
  });

  it('un chemin sans seau ne fabrique pas d\'URL bancale', () => {
    const { footerPadrao } = charherLayout();
    const bancal = { regulation_bucket: null, regulation_path: 'un/chemin.pdf' };
    expect(footerPadrao(bancal, 'fr')).not.toContain('href=');
  });
});
