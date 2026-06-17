// =============================================================================
// BibliotecaPublicaPage.jsx — Fiche PUBLIQUE d'une bibliothèque (#PUB2).
// =============================================================================
// Surface anon (route /bibliotecas/:slug). Squelette Phase 1 : lit les vues
// publiques DÉJÀ en place — api.public_libraries (identité, opt-in niveau 1) et
// api.library_service_public (état de service + mot public). Les sections
// CONTACT et HORAIRES (opt-in niveau 2, PUBLIB-OPTIN-1) viendront via les vues
// gated api.library_contact_public_v1 / api.library_opening_hours_public_v1
// (Phase 2 backend, non encore construites) — emplacements marqués ci-dessous.
// Chantier PUBLIB (REGISTRE §31). Lecture seule, aucun tracking.
// =============================================================================

import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { Link, useParams } from 'react-router-dom';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { apiQuery } from '@/lib/supabase';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

function initials(name) {
  if (!name) return '?';
  return name.trim().split(/\s+/).slice(0, 2).map((w) => w[0] || '').join('').toUpperCase() || '?';
}

export default function BibliotecaPublicaPage() {
  const { formatMessage: t, locale } = useIntl();
  const { slug } = useParams();

  const [state, setState] = useState({ loading: true, lib: null, service: null, contact: null, hours: null });
  useEffect(() => {
    let cancelled = false;
    setState({ loading: true, lib: null, service: null, contact: null, hours: null });
    (async () => {
      // Vues publiques gated (Phase 2) : contact/horaires ne renvoient une ligne
      // que si la biblio a opt-in la section (is_public) ET est répertoriée publiquement.
      const [pl, sv, ct, hr] = await Promise.all([
        apiQuery('public_libraries', { filters: { slug: `eq.${slug}` } }),
        apiQuery('library_service_public', { filters: { slug: `eq.${slug}` } }),
        apiQuery('library_contact_public_v1', { filters: { slug: `eq.${slug}` } }),
        apiQuery('library_opening_hours_public_v1', { filters: { slug: `eq.${slug}` } }),
      ]);
      if (cancelled) return;
      setState({
        loading: false,
        lib: pl.data?.[0] || null,
        service: sv.data?.[0] || null,
        contact: ct.data?.[0] || null,
        hours: hr.data?.[0] || null,
      });
    })();
    return () => { cancelled = true; };
  }, [slug]);

  const { loading, lib, service, contact, hours } = state;
  // day ISO 1..7 (lundi=1) ; 2024-01-01 est un lundi.
  const dayName = (d) => {
    try { return new Intl.DateTimeFormat(locale, { weekday: 'long' }).format(new Date(2024, 0, Number(d) || 1)); }
    catch { return String(d); }
  };
  const sortedSlots = [...(hours?.slots || [])]
    .filter((s) => s && s.start && s.end)
    .sort((a, b) => (Number(a.day) - Number(b.day)) || String(a.start).localeCompare(String(b.start)));
  const contactFields = [
    ['public_email', 'account.mylib.email', (v) => <a href={`mailto:${v}`} style={{ color: '#93c5fd', textDecoration: 'none' }}>{v}</a>],
    ['public_phone', 'account.mylib.phone', (v) => <a href={`tel:${v.replace(/\s+/g, '')}`} style={{ color: '#93c5fd', textDecoration: 'none' }}>{v}</a>],
    ['public_whatsapp', 'account.mylib.whatsapp', (v) => <span>{v}</span>],
    ['public_address', 'account.mylib.address', (v) => (
      <span style={{ whiteSpace: 'pre-line' }}>
        {v}
        {' · '}
        {/* PUBLIB-O1 : « voir sur la carte » = lien OSM (clic-pour-charger ; aucune tuile
            ni géocodage sur notre page, le clic navigue vers OSM = consentement explicite). */}
        <a
          href={`https://www.openstreetmap.org/search?query=${encodeURIComponent(v)}`}
          target="_blank" rel="noopener noreferrer"
          style={{ color: '#93c5fd', textDecoration: 'none', fontSize: '.82rem', whiteSpace: 'nowrap' }}
        >
          {t({ id: 'bibliotecaPublica.viewOnMap' })} ↗
        </a>
      </span>
    )],
    ['public_note', 'account.mylib.note', (v) => <span style={{ whiteSpace: 'pre-line' }}>{v}</span>],
  ];
  const hasContact = contact && contactFields.some(([k]) => (contact[k] || '').trim() !== '');
  useDocumentTitle(lib?.name || t({ id: 'pageTitle.bibliotecaPublica' }));

  const box = {
    padding: 18, borderRadius: 12, background: 'rgba(255,255,255,.03)',
    border: '1px solid rgba(255,255,255,.08)', marginBottom: 16,
  };
  const logoBox = {
    width: 72, height: 72, borderRadius: 14, flex: '0 0 auto', objectFit: 'contain',
    background: 'rgba(255,255,255,.05)', border: '1px solid rgba(255,255,255,.10)',
  };
  const logoFallback = {
    ...logoBox, display: 'flex', alignItems: 'center', justifyContent: 'center',
    fontFamily: 'var(--brand-font-body)', fontSize: '1.3rem', fontWeight: 700, color: 'var(--brand-muted)',
  };
  const linkStyle = { color: '#93c5fd', textDecoration: 'none' };
  const place = lib ? [lib.city, lib.state, lib.country].filter(Boolean).join(' · ') : '';

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '24px 16px 48px' }}>
        <Link to="/bibliotecas" style={{ ...linkStyle, fontSize: '.85rem' }}>
          {t({ id: 'bibliotecaPublica.back' })}
        </Link>

        {loading ? (
          <p style={{ color: 'var(--brand-muted)', marginTop: 20 }}>{t({ id: 'common.loading' })}</p>
        ) : !lib ? (
          <p style={{ color: 'var(--brand-muted)', marginTop: 20, fontStyle: 'italic' }}>
            {t({ id: 'bibliotecaPublica.notFound' })}
          </p>
        ) : (
          <>
            {/* ── En-tête identité (opt-in niveau 1) ── */}
            <div style={{ ...box, marginTop: 16 }}>
              <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
                {lib.logo_url ? (
                  <img src={lib.logo_url} alt="" style={logoBox} onError={(e) => { e.currentTarget.style.display = 'none'; }} />
                ) : (
                  <div style={logoFallback} aria-hidden="true">{initials(lib.name)}</div>
                )}
                <div style={{ minWidth: 0 }}>
                  <h1 style={{ fontSize: '1.5rem', fontWeight: 800, margin: 0, fontFamily: 'var(--brand-font-body)', wordBreak: 'break-word' }}>
                    {lib.name}
                  </h1>
                  {place && <div style={{ fontSize: '.9rem', color: 'var(--brand-muted)', marginTop: 4 }}>{place}</div>}
                  {lib.affiliation_label && (
                    <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginTop: 2 }}>{lib.affiliation_label}</div>
                  )}
                </div>
              </div>

              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, marginTop: 14 }}>
                <Link to={`/catalogo/${lib.slug}`} style={linkStyle}>{t({ id: 'bibliotecas.viewCatalog' })}</Link>
                {lib.website_url && (
                  <a href={lib.website_url} target="_blank" rel="noopener noreferrer" style={linkStyle}>
                    {t({ id: 'bibliotecas.website' })}
                  </a>
                )}
              </div>
            </div>

            {/* ── Mot public de la bibliothèque (état de service) ── */}
            {service?.public_message && (
              <div style={box}>
                <div style={{ fontSize: '.72rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted)', marginBottom: 6 }}>
                  {t({ id: 'bibliotecaPublica.serviceMessage' })}
                </div>
                <p style={{ margin: 0, fontSize: '.95rem', lineHeight: 1.6, color: '#f4f4f4', whiteSpace: 'pre-line' }}>
                  {service.public_message}
                </p>
              </div>
            )}

            {/* ── Contact public (opt-in niveau 2, #PUB4 — api.library_contact_public_v1) ── */}
            {hasContact && (
              <div style={box}>
                <div style={{ fontSize: '.72rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted)', marginBottom: 8 }}>
                  {t({ id: 'bibliotecaPublica.contact' })}
                </div>
                {contactFields.map(([k, labelId, render]) => {
                  const v = (contact[k] || '').trim();
                  if (!v) return null;
                  return (
                    <div key={k} style={{ marginTop: 6 }}>
                      <div style={{ fontSize: '.72rem', color: 'var(--brand-muted)' }}>{t({ id: labelId })}</div>
                      <div style={{ fontSize: '.9rem', color: '#f4f4f4', wordBreak: 'break-word' }}>{render(v)}</div>
                    </div>
                  );
                })}
              </div>
            )}

            {/* ── Horaires / permanences (opt-in niveau 2, #PUB5 — api.library_opening_hours_public_v1) ── */}
            {(sortedSlots.length > 0 || hours?.public_note) && (
              <div style={box}>
                <div style={{ fontSize: '.72rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted)', marginBottom: 8 }}>
                  {t({ id: 'account.mylib.hours' })}
                </div>
                {sortedSlots.length > 0 && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                    {sortedSlots.map((s, i) => (
                      <div key={i} style={{ fontSize: '.9rem', color: '#f4f4f4' }}>
                        <span style={{ fontWeight: 600, textTransform: 'capitalize' }}>{dayName(s.day)}</span>
                        {' · '}{s.start}–{s.end}
                        {s.label ? <span style={{ color: 'var(--brand-muted)' }}>{' — '}{s.label}</span> : null}
                      </div>
                    ))}
                  </div>
                )}
                {hours?.public_note ? (
                  <div style={{ marginTop: 6, fontSize: '.9rem', color: 'var(--brand-muted)', fontStyle: 'italic', whiteSpace: 'pre-line' }}>{hours.public_note}</div>
                ) : null}
              </div>
            )}

            {/* PUBLIB-GEO-1 / PUBLIB-O1 — adresse exacte + carte « clic-pour-charger »
                (anti-tracking) : à instruire quand l'adresse opt-in sera disponible. */}
          </>
        )}
      </div>
      <Footer />
    </PageShell>
  );
}
