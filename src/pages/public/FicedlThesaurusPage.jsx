// =============================================================================
// FicedlThesaurusPage.jsx — navigation PUBLIQUE du thésaurus partagé FICEDL.
// =============================================================================
// Surface anon (route /thesaurus-ficedl, hors ProtectedRoute). Lecture seule de
// public.ficedl_thesaurus_terms (SELECT public + RLS ; cf. migration 25/06/2026).
//
// ANTI-FORK : la source de vérité est le SPIP FICEDL (thesaurus.ficedl.info) ;
// AnarBib n'affiche qu'un cache ré-aspirable. Les libellés sont montrés TELS
// QU'ASPIRÉS (pas de charte inclusive sur le vocabulaire partagé). P3a.
// =============================================================================

import { useState, useEffect, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { supabase } from '@/lib/supabase';
import { pickLabel } from '@/lib/i18nLabel';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

const FACETS = ['sujets', 'geo'];

// Normalisation pour recherche insensible aux accents et à la casse.
function norm(s) {
  return (s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '');
}

export default function FicedlThesaurusPage() {
  const { formatMessage: t, locale } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.ficedl' }));

  const [terms, setTerms] = useState(null); // null = chargement
  const [facet, setFacet] = useState('sujets');
  const [query, setQuery] = useState('');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('ficedl_thesaurus_terms')
        .select('mot_id, facet, labels');
      if (!cancelled) setTerms(Array.isArray(data) ? data : []);
    })();
    return () => { cancelled = true; };
  }, []);

  // Liste filtrée (facette + recherche) puis triée par libellé localisé.
  const list = useMemo(() => {
    if (!terms) return [];
    const q = norm(query.trim());
    return terms
      .filter((tm) => Array.isArray(tm.facet) && tm.facet.includes(facet))
      .map((tm) => ({ ...tm, _label: pickLabel(tm.labels, locale) }))
      .filter((tm) => !q || norm(tm._label).includes(q))
      .sort((a, b) => a._label.localeCompare(b._label, undefined, { sensitivity: 'base' }));
  }, [terms, facet, query, locale]);

  const panel = {
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)',
    borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)',
    padding: '24px 24px 32px',
  };
  const tab = (active) => ({
    fontSize: '.85rem', padding: '6px 14px', borderRadius: 999, cursor: 'pointer',
    border: '1px solid rgba(255,255,255,.14)',
    background: active ? 'rgba(147,197,253,.16)' : 'rgba(255,255,255,.03)',
    color: active ? '#bfdbfe' : 'var(--brand-muted)', fontWeight: active ? 700 : 500,
  });
  const input = {
    width: '100%', padding: '10px 12px', borderRadius: 10, fontSize: '.95rem',
    background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.12)',
    color: '#f4f4f4', boxSizing: 'border-box',
  };

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 1040, margin: '0 auto', padding: '24px 16px 48px' }}>
        <div style={panel}>
          <h1 style={{ fontSize: '1.75rem', fontWeight: 800, marginBottom: 6, fontFamily: 'var(--brand-font-body)' }}>
            {t({ id: 'ficedl.title' })}
          </h1>
          <p style={{ color: 'var(--brand-muted)', marginBottom: 20, fontSize: '.95rem' }}>
            {t({ id: 'ficedl.subtitle' })}
          </p>

          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
            {FACETS.map((f) => (
              <button key={f} type="button" style={tab(facet === f)} onClick={() => setFacet(f)}>
                {t({ id: `ficedl.facet.${f}` })}
              </button>
            ))}
          </div>

          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t({ id: 'ficedl.search.placeholder' })}
            style={input}
            aria-label={t({ id: 'ficedl.search.placeholder' })}
          />

          {terms === null ? (
            <p style={{ color: 'var(--brand-muted)', marginTop: 20 }}>{t({ id: 'common.loading' })}</p>
          ) : (
            <>
              <p style={{ color: 'var(--brand-muted)', fontSize: '.82rem', margin: '16px 0 10px' }}>
                {t({ id: 'ficedl.count' }, { count: list.length })}
              </p>
              {list.length === 0 ? (
                <p style={{ color: 'var(--brand-muted)', fontStyle: 'italic' }}>
                  {query.trim()
                    ? t({ id: 'ficedl.noResults' }, { query: query.trim() })
                    : t({ id: 'ficedl.empty' })}
                </p>
              ) : (
                <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(min(240px, 100%), 1fr))', gap: 8 }}>
                  {list.map((tm) => (
                    <li key={tm.mot_id}>
                      <Link
                        to={`/thesaurus-ficedl/${tm.mot_id}`}
                        style={{
                          display: 'block', padding: '8px 12px', borderRadius: 8,
                          background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.07)',
                          color: '#f4f4f4', textDecoration: 'none', fontSize: '.92rem', wordBreak: 'break-word',
                        }}
                      >
                        {tm._label}
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </>
          )}

          <p style={{ color: 'var(--brand-muted)', fontSize: '.78rem', marginTop: 28, fontStyle: 'italic' }}>
            {t({ id: 'ficedl.antiforkNote' })}
          </p>
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
