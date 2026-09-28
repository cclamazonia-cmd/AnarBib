// ═══════════════════════════════════════════════════════════
// AnarBib — les rapprochements d'autorité proposés en révision de lot
// (H18, 28/09/2026).
//
// On rend le VRAI ContributorCandidates avec les vrais dictionnaires fr et el,
// sur un faux Supabase qui répond comme fn_batch_contributor_candidates (forme
// figée par tests/sql/import_zones_tests.sql, T8). Ce que l'écran doit garder :
//   * rien n'est cherché ni rattaché sans un geste : la RPC ne part qu'au clic ;
//   * « Rattacher » écrit author_id sur la ligne du contributeur, et la nature
//     de la fiche seulement si le contributeur n'en avait pas ;
//   * un rattachement que les politiques refusent (0 ligne) se dit refusé,
//     jamais « Rattaché ».
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import fr from '@/i18n/locales/fr.json';
import el from '@/i18n/locales/el.json';

const etat = vi.hoisted(() => ({ appels: [], reponses: {} }));

vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: async (nom, args) => {
      etat.appels.push([nom, args]);
      return etat.reponses[nom] ?? { data: [], error: null };
    },
    from: (table) => ({
      update: (patch) => ({
        eq: (col, val) => ({
          select: async () => {
            etat.appels.push([`${table}:update`, patch, col, val]);
            return etat.reponses[`${table}:update`] ?? { data: [{ id: val }], error: null };
          },
        }),
      }),
    }),
  },
}));

vi.mock('@/lib/localizeError', () => ({ localizeError: (e) => String(e?.message || e) }));

import ContributorCandidates, { patchRattachement } from '@/components/catalog/ContributorCandidates.jsx';

const LIGNES = [
  { contributor_id: 901, draft_id: 17, titulo: 'Venue d\'un CSV', name: 'Reclus, Élisée', role: 'autor', nature: null,
    author_id: 55, author_name: 'Élisée Reclus', author_type: 'person' },
  { contributor_id: 902, draft_id: 18, titulo: 'Des bourses du travail', name: 'Muñoz, Pilar', role: 'tradutor', nature: 'person',
    author_id: 56, author_name: 'Pilar Muñoz', author_type: 'collective' },
];

const rendre = (messages = fr, locale = 'fr') =>
  render(<IntlProvider locale={locale} messages={messages}><ContributorCandidates batchId="63" /></IntlProvider>);

beforeEach(() => { etat.appels = []; etat.reponses = {}; });

describe('patchRattachement', () => {
  it('la fiche donne sa nature au contributeur qui n\'en a pas, jamais par-dessus la sienne', () => {
    expect(patchRattachement(LIGNES[0])).toEqual({ author_id: 55, nature: 'person' });
    expect(patchRattachement(LIGNES[1])).toEqual({ author_id: 56 });
    expect(patchRattachement({ author_id: 7, nature: null, author_type: null })).toEqual({ author_id: 7 });
  });
});

describe('ContributorCandidates — proposer, jamais appliquer d\'office', () => {
  it('rien ne part avant le clic ; la recherche liste les propositions ; « Rattacher » écrit la ligne', async () => {
    etat.reponses.fn_batch_contributor_candidates = { data: LIGNES, error: null };
    const { container } = rendre();
    expect(etat.appels).toEqual([]);
    fireEvent.click(screen.getByRole('button', { name: fr['review.report.contributors.search'] }));
    await waitFor(() => expect(container.querySelectorAll('[data-contributor]')).toHaveLength(2));
    expect(etat.appels[0]).toEqual(['fn_batch_contributor_candidates', { p_batch_id: 63 }]);
    expect(container.textContent).toContain('2 fiches proposées');
    const ligne = container.querySelector('[data-contributor="902"]');
    expect(ligne.textContent).toContain('Muñoz, Pilar');
    expect(ligne.textContent).toContain(fr['catalogacao.role.tradutor']);
    expect(ligne.textContent).toContain('Pilar Muñoz');
    expect(etat.appels.filter(([n]) => n.endsWith(':update'))).toEqual([]);

    const recus = [];
    const ecoute = (e) => recus.push(e.detail);
    window.addEventListener('anarbib:draft-contributor-linked', ecoute);
    fireEvent.click(ligne.querySelector('button'));
    await waitFor(() => expect(ligne.textContent).toContain(fr['review.report.contributors.linked']));
    window.removeEventListener('anarbib:draft-contributor-linked', ecoute);
    expect(etat.appels.at(-1)).toEqual(['book_draft_contributors:update', { author_id: 56 }, 'id', 902]);
    // le formulaire ouvert sur ce brouillon reprend le rattachement
    expect(recus).toEqual([{ draftId: 18, name: 'Muñoz, Pilar', authorId: 56, authorLabel: 'Pilar Muñoz', nature: null }]);
  });

  it('un rattachement refusé par les politiques (0 ligne) se dit refusé', async () => {
    etat.reponses.fn_batch_contributor_candidates = { data: LIGNES.slice(0, 1), error: null };
    etat.reponses['book_draft_contributors:update'] = { data: [], error: null };
    const { container } = rendre();
    fireEvent.click(screen.getByRole('button', { name: fr['review.report.contributors.search'] }));
    await waitFor(() => expect(container.querySelector('[data-contributor="901"]')).toBeTruthy());
    fireEvent.click(container.querySelector('[data-contributor="901"] button'));
    await waitFor(() => expect(screen.getByRole('alert').textContent).toBe(fr['review.report.contributors.linkFailed']));
    expect(container.textContent).not.toContain(fr['review.report.contributors.linked']);
    expect(etat.appels.at(-1)[1]).toEqual({ author_id: 55, nature: 'person' });
  });

  it('aucune proposition : une ligne qui le dit ; une erreur : une alerte', async () => {
    const a = rendre();
    fireEvent.click(screen.getByRole('button', { name: fr['review.report.contributors.search'] }));
    await waitFor(() => expect(a.container.textContent).toContain(fr['review.report.contributors.none']));
    a.unmount();
    etat.reponses.fn_batch_contributor_candidates = { data: null, error: { message: 'error.batch.other_libraries' } };
    rendre();
    fireEvent.click(screen.getByRole('button', { name: fr['review.report.contributors.search'] }));
    await waitFor(() => expect(screen.getByRole('alert').textContent).toBe('error.batch.other_libraries'));
  });

  it('en grec aussi, avec les pluriels ICU', async () => {
    etat.reponses.fn_batch_contributor_candidates = { data: LIGNES.slice(0, 1), error: null };
    const { container } = rendre(el, 'el');
    fireEvent.click(screen.getByRole('button', { name: el['review.report.contributors.search'] }));
    await waitFor(() => expect(container.textContent).toContain('1 προτεινόμενη εγγραφή'));
    expect(container.textContent).toContain(el['review.report.contributors.title']);
  });
});
