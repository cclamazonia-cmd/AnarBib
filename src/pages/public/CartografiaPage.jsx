// =============================================================================
// CartografiaPage.jsx — Carte PUBLIQUE du réseau (MAP-C, route /cartografia).
// =============================================================================
// Surface anon (hors ProtectedRoute), cohérente avec /bibliotecas (PUBLIB). Lit
// api.cartography_public_v1 (fiches statut_public=true uniquement, N1 ; opt-in
// MAP-E — la carte est vide tant qu'aucun collectif ne s'est rendu visible).
// Rendu Leaflet + filtres + popups 10 locales mutualisés via CartographyMap.
// Lecture seule, aucun tracking (OSM tiles, INV-5 / PUBLIB-O1). REGISTRE §34.
// =============================================================================

import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { useAuth } from '@/contexts/AuthContext';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import CartographyMap from '@/pages/federacao/CartographyMap';

export default function CartografiaPage() {
  const { formatMessage: t } = useIntl();
  const { user } = useAuth();
  useDocumentTitle(t({ id: 'cartografia.title' }));

  const panel = {
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)',
    borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)',
    padding: '24px 24px 32px',
  };

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 1040, margin: '0 auto', padding: '24px 16px 48px' }}>
        <div style={panel}>
          <h1 style={{ fontSize: '1.75rem', fontWeight: 800, marginBottom: 6, fontFamily: 'var(--brand-font-body)' }}>
            {t({ id: 'cartografia.title' })}
          </h1>
          <p style={{ color: 'var(--brand-muted)', marginBottom: 14 }}>
            {t({ id: 'cartografia.intro' })}
          </p>
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 18 }}>
            <Link to="/cartografia/ajouter"
              style={{ padding: '8px 16px', borderRadius: 8, background: 'rgb(var(--brand-accent-rgb))', color: '#fff', fontWeight: 700, fontSize: '.85rem', textDecoration: 'none' }}>
              {t({ id: 'cartografia.add' })}
            </Link>
            {user && (
              <Link to="/cartografia/moderacao"
                style={{ padding: '8px 16px', borderRadius: 8, border: '1px solid rgba(255,255,255,.16)', color: 'var(--brand-muted)', fontSize: '.85rem', textDecoration: 'none' }}>
                {t({ id: 'cartografia.mod' })}
              </Link>
            )}
          </div>
          <CartographyMap viewName="cartography_public_v1" />
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
