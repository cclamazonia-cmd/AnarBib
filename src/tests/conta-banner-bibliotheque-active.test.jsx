// ═══════════════════════════════════════════════════════════
// AnarBib — /conta : bibliothèque activée avant la fin de l'atelier (21/10/2026).
//
// L'administration du réseau peut activer une bibliothèque avant que sa
// coordination ait terminé l'atelier (api.fn_constitution_activate_early).
// Le bandeau de /conta ne doit plus dire « ta bibliothèque est pré-active » :
// il dit qu'elle est active et que l'atelier reste ouvert, et garde le lien
// vers le guide d'accueil et le bouton vers l'atelier. Même montage que
// conta-guide-banner.test.jsx, avec library_is_active à vrai.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import fr from '@/i18n/locales/fr.json';
import MinhaSolicitacaoPanel from '@/components/account/MinhaSolicitacaoPanel';

const DEMANDE = {
  id: 'req-1', request_status: 'aprovada', library_name: 'Biblioteca Emma Goldman',
  created_at: '2026-09-16T10:00:00Z', updated_at: '2026-09-16T10:00:00Z',
};

vi.mock('@/contexts/AuthContext', () => ({
  useAuth: () => ({ user: { id: 'user-louise' }, loading: false }),
}));

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
    // Atelier ouvert (pas de completed_at), bibliothèque déjà active.
    apiQuery: async () => ({ data: [{ request_id: 'req-1', completed_at: null, library_is_active: true }], error: null }),
    apiRpc: async () => ({ data: null, error: null }),
  };
});

vi.mock('@/lib/localizeError', () => ({ localizeError: (e) => String(e?.message || e) }));

describe('/conta — bibliothèque active, atelier encore ouvert', () => {
  it('dit la bibliothèque active, garde le guide et l\'atelier', async () => {
    render(
      <IntlProvider locale="fr" messages={fr} defaultLocale="pt-BR" onError={() => {}}>
        <MinhaSolicitacaoPanel />
      </IntlProvider>,
    );
    expect(await screen.findByText(fr['account.constitution.banner.titleActive'])).toBeTruthy();
    expect(screen.getByText(fr['account.constitution.banner.bodyActive'])).toBeTruthy();
    expect(screen.queryByText(fr['account.constitution.banner.body'])).toBeNull();
    expect(screen.getByRole('link', { name: fr['account.constitution.banner.cta'] })).toBeTruthy();
    expect(screen.getByText(fr['conta.demande.goAtelier'])).toBeTruthy();
  });
});
