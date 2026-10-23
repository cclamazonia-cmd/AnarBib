// =====================================================================
// E6, formulaire d'autorité (23/10/2026) — les trois panneaux MONTÉS, leurs
// gestes joués. Le découpage avait laissé `const authorId = authorId;` en tête
// des fonctions (le motif f('published_author_id') remplacé dans sa propre
// déclaration) : une variable lue avant d'exister, la fonction tombait au
// premier pas, sans message — « Chercher » ne rendait qu'un vide (vu par
// Xavier en production). Le test de source ne le voyait pas : ici, on clique.
// =====================================================================
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const appels = [];
vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: async (nom, args) => { appels.push([nom, args]); return { data: [], error: null }; },
    from: () => ({ select: () => ({ eq: async () => ({ data: [], error: null }) }) }),
  },
}));
vi.mock('@/contexts/ConfirmContext', () => ({ useConfirm: () => async () => true }));

const { default: AuthorBookLinksPanel } = await import('@/pages/catalogacao/AuthorBookLinksPanel');
const { default: AuthorDuplicatesPanel } = await import('@/pages/catalogacao/AuthorDuplicatesPanel');
const { default: AuthorBioTranslations } = await import('@/pages/catalogacao/AuthorBioTranslations');
const fr = JSON.parse(readFileSync(path.resolve(__dirname, '..', 'i18n/locales/fr.json'), 'utf8'));
const avecIntl = (el) => render(<IntlProvider locale="fr" messages={fr} onError={() => {}}>{el}</IntlProvider>);

afterEach(() => { cleanup(); appels.length = 0; });

describe('les panneaux du formulaire d\'autorité, montés', () => {
  it('rattacher aux œuvres : « Chercher » appelle la base et dit « aucune »', async () => {
    const onMessage = vi.fn();
    avecIntl(<AuthorBookLinksPanel authorId="42" onMessage={onMessage} />);
    fireEvent.click(screen.getByText(fr['catalogacao.link.find']));
    await waitFor(() => expect(screen.getByText(fr['catalogacao.link.none'])).toBeTruthy());
    expect(appels).toEqual([['suggest_author_book_matches', { p_author_id: 42 }]]);
    expect(onMessage).not.toHaveBeenCalled();
  });
  it('doublons : « Chercher » appelle la base et dit « aucun »', async () => {
    const onMessage = vi.fn();
    avecIntl(<AuthorDuplicatesPanel authorId="42" preferredName="X" arbitreDoublons onMessage={onMessage} />);
    fireEvent.click(screen.getByText(fr['catalogacao.dedup.find']));
    await waitFor(() => expect(screen.getByText(fr['catalogacao.dedup.none'])).toBeTruthy());
    expect(appels).toEqual([['suggest_author_duplicates', { p_author_id: 42 }]]);
  });
  it('biographies : la bascule de revue appelle la base pour l\'autorité, puis relit les traductions', async () => {
    const onMessage = vi.fn();
    const bio = [{ lang: 'fr', biography: 'Texte', status: 'draft', author_id: 42 }];
    avecIntl(<AuthorBioTranslations authorId="42" bioTranslations={bio} setBioTranslations={() => {}} bioDirty={new Set()}
      setBioDirty={() => {}} user={{ id: 'u' }} onMessage={onMessage} confirmSaved={() => {}} />);
    fireEvent.click(screen.getByTitle(fr['catalogacao.bio.markReviewed']));
    await waitFor(() => expect(appels).toEqual([['set_author_translation_review', { p_author_id: 42, p_lang: 'fr', p_reviewed: true }]]));
    expect(onMessage).not.toHaveBeenCalled();
  });
  it('plus aucune variable qui se lit elle-même dans les trois panneaux', () => {
    for (const f of ['AuthorBioTranslations', 'AuthorBookLinksPanel', 'AuthorDuplicatesPanel']) {
      const src = readFileSync(path.resolve(__dirname, '..', `pages/catalogacao/${f}.jsx`), 'utf8');
      expect(src, f).not.toMatch(/const (\w+) = \1;/);
    }
  });
});
