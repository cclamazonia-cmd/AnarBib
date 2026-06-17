// =============================================================================
// BibliotecasPage.jsx — Annuaire PUBLIC des bibliothèques du réseau (#PUB1).
// =============================================================================
// Surface anon (route /bibliotecas, hors ProtectedRoute). Lit la vue publique
// déjà en place api.public_libraries (filtrée visibility_level='public' — PUBLIB-VIS-1).
// Niveau 1 de l'opt-in (PUBLIB-OPTIN-1) : nom / ville / logo / site / affiliation /
// nb de notices. Aucune donnée sensible (contact/horaires = niveau 2, fiche).
// Chantier PUBLIB (REGISTRE §31). Lecture seule, aucun tracking.
// =============================================================================

import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { apiQuery } from '@/lib/supabase';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

function initials(name) {
  if (!name) return '?';
  return name.trim().split(/\s+/).slice(0, 2).map((w) => w[0] || '').join('').toUpperCase() || '?';
}

function placeLine(lib) {
  return [lib.city, lib.country].filter(Boolean).join(' · ');
}

export default function BibliotecasPage() {
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.bibliotecas' }));

  const [libs, setLibs] = useState(null); // null = chargement
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await apiQuery('public_libraries', { order: 'name.asc' });
      if (!cancelled) setLibs(Array.isArray(data) ? data : []);
    })();
    return () => { cancelled = true; };
  }, []);

  const card = {
    display: 'flex', flexDirection: 'column', gap: 10, padding: 18, borderRadius: 12,
    background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)',
  };
  const logoBox = {
    width: 56, height: 56, borderRadius: 12, flex: '0 0 auto', objectFit: 'contain',
    background: 'rgba(255,255,255,.05)', border: '1px solid rgba(255,255,255,.10)',
  };
  const logoFallback = {
    ...logoBox, display: 'flex', alignItems: 'center', justifyContent: 'center',
    fontFamily: 'var(--brand-font-body)', fontSize: '1.1rem', fontWeight: 700, color: 'var(--brand-muted)',
  };
  const badge = {
    fontSize: '.7rem', textTransform: 'uppercase', letterSpacing: '.04em', padding: '3px 8px',
    borderRadius: 999, border: '1px solid rgba(255,255,255,.14)', color: 'var(--brand-muted)',
  };
  const linkStyle = { color: '#93c5fd', textDecoration: 'none', fontSize: '.85rem' };

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 1040, margin: '0 auto', padding: '24px 16px 48px' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 800, marginBottom: 6, fontFamily: 'var(--brand-font-body)' }}>
          {t({ id: 'bibliotecas.title' })}
        </h1>
        <p style={{ color: 'var(--brand-muted)', marginBottom: 28, fontSize: '.95rem' }}>
          {t({ id: 'bibliotecas.subtitle' })}
        </p>

        {libs === null ? (
          <p style={{ color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</p>
        ) : libs.length === 0 ? (
          <p style={{ color: 'var(--brand-muted)', fontStyle: 'italic' }}>{t({ id: 'bibliotecas.empty' })}</p>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 16 }}>
            {libs.map((lib) => (
              <div key={lib.id} style={card}>
                <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                  {lib.logo_url ? (
                    <img src={lib.logo_url} alt="" style={logoBox} onError={(e) => { e.currentTarget.style.display = 'none'; }} />
                  ) : (
                    <div style={logoFallback} aria-hidden="true">{initials(lib.name)}</div>
                  )}
                  <div style={{ minWidth: 0 }}>
                    <Link to={`/bibliotecas/${lib.slug}`} style={{ color: '#f4f4f4', textDecoration: 'none', fontWeight: 700, fontSize: '1.02rem', wordBreak: 'break-word' }}>
                      {lib.name}
                    </Link>
                    {placeLine(lib) && (
                      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginTop: 2 }}>{placeLine(lib)}</div>
                    )}
                  </div>
                </div>

                {lib.affiliation_label && (
                  <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>{lib.affiliation_label}</div>
                )}

                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center' }}>
                  <span style={badge}>
                    {lib.catalog_status === 'automatizado'
                      ? t({ id: 'bibliotecas.status.online' })
                      : t({ id: 'bibliotecas.status.building' })}
                  </span>
                  {typeof lib.notices_count === 'number' && lib.notices_count > 0 && (
                    <span style={{ fontSize: '.8rem', color: 'var(--brand-muted)' }}>
                      {t({ id: 'bibliotecas.noticesCount' }, { count: lib.notices_count })}
                    </span>
                  )}
                </div>

                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 14, marginTop: 'auto', paddingTop: 6 }}>
                  <Link to={`/catalogo/${lib.slug}`} style={linkStyle}>{t({ id: 'bibliotecas.viewCatalog' })}</Link>
                  {lib.website_url && (
                    <a href={lib.website_url} target="_blank" rel="noopener noreferrer" style={linkStyle}>
                      {t({ id: 'bibliotecas.website' })}
                    </a>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
      <Footer />
    </PageShell>
  );
}
