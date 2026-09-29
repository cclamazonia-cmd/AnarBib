// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/library-context-patch.test.js
//
// CE QUE CE TEST PROTÈGE. Le 29/09/2026, la cotisation réactivée pour la BLMF
// dans la page Bibliothèque n'apparaissait ni dans « Mon compte » ni au tableau
// de bord : ces écrans lisent le contexte de session, chargé une fois, et
// l'interrupteur n'écrivait qu'en base et dans sa page. Le report vit dans
// `src/contexts/libraryPatch.js` (règle pure, éprouvée ici) et
// `LibraryContext.patchLibrary` ; trois gestes l'appellent. Ce banc garde :
//   1. la règle — liste fermée, bibliothèque active seulement, références
//      inchangées quand rien ne bouge ;
//   2. le câblage — le contexte expose patchLibrary et l'écrit en session ; les
//      trois gestes l'appellent APRÈS le succès de l'écriture en base.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { appliquerReglage, REGLAGES_DU_CONTEXTE } from '../contexts/libraryPatch.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const BLMF = 'aaaaaaaa-0000-4000-8000-000000000001';
const BTL = 'bbbbbbbb-0000-4000-8000-000000000002';
const ctxBlmf = () => ({ librarySlug: 'blmf', libraryId: BLMF, role: 'coordenador', circulation_mode: 'full_sigb', membership_enabled: false, reader_cards_enabled: false, allow_direct_coordenador: false });
const adhesions = () => ([
  { library_id: BLMF, role: 'coordenador', is_primary: true, libraries: { id: BLMF, slug: 'blmf', membership_enabled: false } },
  { library_id: BTL, role: 'librarian', is_primary: false, libraries: { id: BTL, slug: 'btl', membership_enabled: false } },
]);

describe('report d’un réglage de bibliothèque dans le contexte — la règle', () => {
  it('la cotisation activée pour la bibliothèque active se voit dans le contexte', () => {
    const { ctx, libraries } = appliquerReglage(ctxBlmf(), adhesions(), BLMF, { membership_enabled: true });
    expect(ctx.membership_enabled).toBe(true);
    expect(libraries[0].libraries.membership_enabled).toBe(true);
    expect(libraries[1].libraries.membership_enabled).toBe(false);
    // le reste du contexte n'a pas bougé
    expect(ctx.role).toBe('coordenador');
    expect(ctx.circulation_mode).toBe('full_sigb');
  });

  it('une autre bibliothèque que l’active ne touche pas le contexte courant', () => {
    const avant = ctxBlmf();
    const { ctx, libraries } = appliquerReglage(avant, adhesions(), BTL, { membership_enabled: true });
    expect(ctx).toBe(avant);
    // mais la liste suit : un changement de bibliothèque active repartira de la bonne valeur
    expect(libraries[1].libraries.membership_enabled).toBe(true);
  });

  it('la liste est fermée : ni rôle, ni identité n’entrent par ce chemin', () => {
    const avant = ctxBlmf();
    const liste = adhesions();
    const { ctx, libraries } = appliquerReglage(avant, liste, BLMF, { role: 'network_admin', libraryId: BTL, librarySlug: 'btl', themeSlug: 'x' });
    expect(ctx).toBe(avant);
    expect(libraries).toBe(liste);
    expect(REGLAGES_DU_CONTEXTE).toEqual(['catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode', 'membership_enabled', 'reader_cards_enabled', 'allow_direct_coordenador']);
  });

  it('un booléen reste un booléen, un mode vide est ignoré', () => {
    const { ctx } = appliquerReglage(ctxBlmf(), adhesions(), BLMF, { reader_cards_enabled: 'oui', circulation_mode: '' });
    expect(ctx.reader_cards_enabled).toBe(false);
    expect(ctx.circulation_mode).toBe('full_sigb');
    const { ctx: c2 } = appliquerReglage(ctxBlmf(), adhesions(), BLMF, { allow_direct_coordenador: true, circulation_mode: 'informal' });
    expect(c2.allow_direct_coordenador).toBe(true);
    expect(c2.circulation_mode).toBe('informal');
  });

  it('rend les mêmes références quand rien ne change', () => {
    const avant = { ...ctxBlmf(), membership_enabled: true };
    const { ctx } = appliquerReglage(avant, null, BLMF, { membership_enabled: true });
    expect(ctx).toBe(avant);
    expect(appliquerReglage(avant, null, null, { membership_enabled: false }).ctx).toBe(avant);
    expect(appliquerReglage(avant, null, BLMF, null).ctx).toBe(avant);
    expect(appliquerReglage(null, null, BLMF, { membership_enabled: true })).toEqual({ ctx: null, libraries: null });
  });
});

describe('report d’un réglage de bibliothèque dans le contexte — le câblage', () => {
  const contexte = src('contexts/LibraryContext.jsx');
  const cotisation = src('pages/biblioteca/MembershipSection.jsx');
  const page = src('pages/biblioteca/BibliotecaPage.jsx');
  const gouvernance = src('components/team/GovernanceSettings.jsx');

  it('le contexte expose patchLibrary et l’écrit en session', () => {
    expect(contexte).toMatch(/import \{ appliquerReglage \} from '\.\/libraryPatch';/);
    expect(contexte).toMatch(/const patchLibrary = useCallback\(\(libraryId, fields\) => \{/);
    expect(contexte).toMatch(/if \(next !== prev\) writeToSession\(next\);/);
    // dans la valeur du contexte ET dans ses dépendances, sinon les écrans reçoivent un no-op
    expect((contexte.match(/\bpatchLibrary\b/g) || []).length).toBeGreaterThanOrEqual(4);
  });

  const apres = (source, ecriture, report) => {
    const i = source.indexOf(ecriture);
    const j = source.indexOf(report);
    expect(i, `écriture introuvable : ${ecriture}`).toBeGreaterThan(-1);
    expect(j, `report introuvable : ${report}`).toBeGreaterThan(i);
    // entre l'écriture et le report, l'erreur de la base a été relevée
    expect(source.slice(i, j)).toMatch(/throw/);
  };

  it('la cotisation se reporte après le succès de l’écriture', () => {
    apres(cotisation, ".update({ membership_enabled: next })", "patchLibrary(libraryId, { membership_enabled: next });");
  });

  it('la carte-lecteur se reporte après le succès de l’enregistrement de l’identité', () => {
    apres(page, "reader_cards_enabled:lib.reader_cards_enabled===true", "patchLibrary(libraryId, { reader_cards_enabled: lib.reader_cards_enabled === true });");
  });

  it('le saut collégial se reporte après le succès de la bascule', () => {
    apres(gouvernance, ".update({ allow_direct_coordenador: next })", "patchLibrary(libraryId, { allow_direct_coordenador: next });");
  });
});
