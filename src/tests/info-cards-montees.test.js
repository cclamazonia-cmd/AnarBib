// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/info-cards-montees.test.js
//
// CE QUE CE TEST PROTÈGE. E6 lot 8 (28/09/2026) sort les cartes « para
// informação » de l'aperçu de BookDraftForm.jsx (InfoCards.jsx). C29 lot 4
// (11/10/2026, décision de Xavier) retire la carte des exemplaires : elle
// redisait le panneau Exemplaires de la fiche (ExemplaresPanel) et envoyait vers
// Indexation. On lit la SOURCE et on garde le contrat que ni lint, ni build, ni
// suite ne verraient casser :
//   1. la carte des auteur·rices est MONTÉE dans l'aperçu live de la fiche, avec
//      les contributeur·rices et le rappel vers l'onglet Autorité ;
//   2. la carte des exemplaires n'y est plus : InfoCards ne lit plus la base, ne
//      connaît ni la notice publiée, ni Indexation, ni la reprise d'un exemplaire ;
//      c'est le panneau Exemplaires qui porte tout cela ;
//   3. rien n'y écrit le formulaire.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const form = src('pages/catalogacao/BookDraftForm.jsx');
const panel = src('pages/catalogacao/InfoCards.jsx');

describe('carte « para informação » (E6 lot 8, C29 lot 4) — réellement montée', () => {
  it('est rendue dans l’aperçu live de la fiche', () => {
    const preview = form.indexOf('function renderLivePreview()');
    const mount = form.indexOf('<InfoCards');
    const previewEnd = form.indexOf('</aside>', preview);
    expect(preview).toBeGreaterThan(-1);
    expect(mount).toBeGreaterThan(preview);
    expect(mount).toBeLessThan(previewEnd);
    expect(form.indexOf("import InfoCards from './InfoCards';")).toBeGreaterThan(-1);
  });

  it('reçoit les contributeur·rices et le rappel vers Autorité, rien d’autre', () => {
    const mount = form.indexOf('<InfoCards');
    const props = form.slice(mount, form.indexOf('/>', mount));
    expect(props).toMatch(/contributors=\{contributors\} onNavigateTab=\{onNavigateTab\}/);
    expect(props).not.toContain('onEditExemplar');
    expect(props).not.toContain('publishedBookId');
    expect(panel).toMatch(/onNavigateTab\?\.\('authorsPanel'\)/);
  });

  it('la carte des exemplaires est retirée : ni base, ni Indexation, ni reprise ; c’est le panneau qui les porte', () => {
    for (const gone of ['linkedExemplars', 'myExemplars', 'renderInfoCards']) {
      expect(form.includes(gone), `${gone} encore dans BookDraftForm`).toBe(false);
    }
    for (const gone of ['supabase', 'useState', 'useEffect', 'indexPanel', 'onEditExemplar', 'BadgeRetire', 'catalogacao.infocard.exemplar', 'catalogacao.infocard.goExemplar', 'catalogacao.infocard.noExemplar']) {
      expect(panel.includes(gone), `${gone} encore dans InfoCards`).toBe(false);
    }
    for (const forbidden of ["f('", 'setForm(', 'setMany(', 'form.published_book_id', 'setContributors']) {
      expect(panel.includes(forbidden), `${forbidden} dans InfoCards`).toBe(false);
    }
    // Le badge « sorti du catalogue d'origine » suit les exemplaires dans le panneau.
    const copies = src('pages/catalogacao/ExemplaresPanel.jsx');
    expect(copies).toContain("import BadgeRetire from '@/components/catalog/BadgeRetire';");
    expect(copies).toContain('<BadgeRetire exemplaire={l.source} />');
  });
});
