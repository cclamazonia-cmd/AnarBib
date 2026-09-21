// ═══════════════════════════════════════════════════════════
// AnarBib — le bandeau de /conta à l'état de constitution mène au guide
// d'accueil des coordinations, dans la langue de la personne (16/09/2026).
//
// On rend le VRAI MinhaSolicitacaoPanel (celui qui coiffe Mon compte quand
// la demande est approuvée et la bibliothèque pas née) avec les vrais
// dictionnaires fr et el : une demande `aprovada`, une progression sans
// completed_at, un compte connecté. Ce qu'on regarde : le titre du bandeau,
// et un lien dont l'adresse est celle de la locale (fr/accueil, el/ypodochi)
// et dont le libellé est le cta de la locale. Deux langues, comme la recette
// le demande — et le grec, parce que c'est là qu'un repli vers l'anglais ou
// le portugais passerait inaperçu.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import fr from '@/i18n/locales/fr.json';
import el from '@/i18n/locales/el.json';
import MinhaSolicitacaoPanel from '@/components/account/MinhaSolicitacaoPanel';
import { siteUrl } from '@/lib/siteUrl';

const DEMANDE = {
  id: 'req-1', request_status: 'aprovada', library_name: 'Biblioteca Emma Goldman',
  created_at: '2026-09-16T10:00:00Z', updated_at: '2026-09-16T10:00:00Z',
};

// Un compte connecté : le panneau ne charge rien sans user.id.
vi.mock('@/contexts/AuthContext', () => ({
  useAuth: () => ({ user: { id: 'user-louise' }, loading: false }),
}));

// Client supabase minimal, chaînable, qui répond selon la table.
vi.mock('@/lib/supabase', () => {
  const reponse = (table) => {
    if (table === 'library_requests') return { data: DEMANDE, error: null };
    return { data: [], error: null };
  };
  const requete = (table) => {
    const p = new Proxy(function () {}, {
      get(_c, prop) {
        if (prop === 'then') return (res) => res(reponse(table));
        return () => p;
      },
    });
    return p;
  };
  return {
    supabase: { from: requete },
    // my_constitution_progress_v1 : une ligne, sans completed_at → bandeau affiché.
    apiQuery: async () => ({ data: [{ request_id: 'req-1', completed_at: null }], error: null }),
    apiRpc: async () => ({ data: null, error: null }),
  };
});

vi.mock('@/lib/localizeError', () => ({ localizeError: (e) => String(e?.message || e) }));

function rendre(locale, messages) {
  return render(
    <IntlProvider locale={locale} messages={messages} defaultLocale="pt-BR" onError={() => {}}>
      <MinhaSolicitacaoPanel />
    </IntlProvider>,
  );
}

describe('/conta — bandeau de constitution vers le guide d\'accueil', () => {
  for (const [locale, messages, slug] of [['fr', fr, 'fr/accueil'], ['el', el, 'el/ypodochi']]) {
    it(`en ${locale} : titre du bandeau, lien vers ${slug} et libellé de la locale`, async () => {
      rendre(locale, messages);
      expect(await screen.findByText(messages['account.constitution.banner.title'])).toBeTruthy();
      expect(screen.getByText(messages['account.constitution.banner.body'])).toBeTruthy();
      const lien = screen.getByRole('link', { name: messages['account.constitution.banner.cta'] });
      expect(lien.getAttribute('href')).toBe(`https://anarbib.org/${slug}/`);
      // La locale ne porte que le chemin ; la base vient de src/lib/siteUrl.js (21/09/2026).
      expect(messages['account.constitution.guidePath']).toBe(`/${slug}/`);
      expect(lien.getAttribute('href')).toBe(siteUrl(messages['account.constitution.guidePath']));
      expect(lien.getAttribute('target')).toBe('_blank');
      // Le bouton existant vers l'atelier est toujours là (Link est rendu nu par le setup).
      expect(screen.getByText(messages['conta.demande.goAtelier'])).toBeTruthy();
    });
  }
});
