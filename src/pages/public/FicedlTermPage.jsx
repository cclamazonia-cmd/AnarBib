// =============================================================================
// FicedlTermPage.jsx — fiche PUBLIQUE d'un descripteur du thésaurus FICEDL.
// =============================================================================
// Surface anon (route /thesaurus-ficedl/:motId). Lecture seule de
// public.ficedl_thesaurus_terms. motId = identifiant FICEDL = clé de fédération.
//
// Affiche : libellé dans la locale active, les 10 langues du vocabulaire partagé
// (feature : c'est un thésaurus multilingue), la hiérarchie, et — fédération
// ENTRANTE — les liens vers le même terme dans les catalogues partenaires
// (catalog_links : CIRA, Marseille, Placard, CCL…). ANTI-FORK : libellés tels
// qu'aspirés, lien vers la source FICEDL. P3a.
// =============================================================================

import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { Link, useParams } from 'react-router-dom';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { supabase } from '@/lib/supabase';
import { pickLabel } from '@/lib/i18nLabel';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

// Les 10 langues du thésaurus partagé, dans un ordre stable d'affichage.
const LANGS = ['fr', 'ca', 'de', 'el', 'en', 'eo', 'es', 'it', 'nl', 'pt'];

// Nom de langue localisé (ex. 'de' → « allemand » en fr). Repli sur le code.
function langName(code, locale) {
  try {
    return new Intl.DisplayNames([locale || 'fr'], { type: 'language' }).of(code) || code;
  } catch {
    return code;
  }
}

export default function FicedlTermPage() {
  const { motId } = useParams();
  const { formatMessage: t, locale } = useIntl();

  const [term, setTerm] = useState(undefined); // undefined = chargement, null = absent

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('ficedl_thesaurus_terms')
        .select('mot_id, facet, labels, el_roman, hierarchy, catalog_links, source_url')
        .eq('mot_id', motId)
        .maybeSingle();
      if (!cancelled) setTerm(data || null);
    })();
    return () => { cancelled = true; };
  }, [motId]);

  const label = term ? pickLabel(term.labels, locale) : '';
  useDocumentTitle(label || t({ id: 'pageTitle.ficedl' }));

  const panel = {
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)',
    borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)',
    padding: '24px 24px 32px',
  };
  const badge = {
    fontSize: '.7rem', textTransform: 'uppercase', letterSpacing: '.04em', padding: '3px 8px',
    borderRadius: 999, border: '1px solid rgba(255,255,255,.14)', color: 'var(--brand-muted)',
  };
  const sectionTitle = {
    fontSize: '.78rem', textTransform: 'uppercase', letterSpacing: '.05em',
    color: 'var(--brand-muted)', margin: '26px 0 10px', fontWeight: 700,
  };
  const linkBlue = { color: '#93c5fd', textDecoration: 'none' };

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 860, margin: '0 auto', padding: '24px 16px 48px' }}>
        <Link to="/thesaurus-ficedl" style={{ ...linkBlue, fontSize: '.85rem' }}>
          ← {t({ id: 'ficedl.backToIndex' })}
        </Link>

        <div style={{ ...panel, marginTop: 12 }}>
          {term === undefined ? (
            <p style={{ color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</p>
          ) : term === null ? (
            <p style={{ color: 'var(--brand-muted)', fontStyle: 'italic' }}>{t({ id: 'ficedl.term.notFound' })}</p>
          ) : (
            <>
              <h1 style={{ fontSize: '1.7rem', fontWeight: 800, marginBottom: 8, fontFamily: 'var(--brand-font-body)' }}>
                {label}
              </h1>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 4 }}>
                {(term.facet || []).map((f) => (
                  <span key={f} style={badge}>{t({ id: `ficedl.facet.${f}`, defaultMessage: f })}</span>
                ))}
              </div>

              {/* Hiérarchie (fil d'ariane du descripteur tel que fourni par FICEDL) */}
              {Array.isArray(term.hierarchy) && term.hierarchy.length > 1 && (
                <>
                  <div style={sectionTitle}>{t({ id: 'ficedl.term.hierarchy' })}</div>
                  <div style={{ fontSize: '.9rem', color: 'var(--brand-muted)' }}>
                    {term.hierarchy.join('  ›  ')}
                  </div>
                </>
              )}

              {/* Les 10 langues du vocabulaire partagé */}
              <div style={sectionTitle}>{t({ id: 'ficedl.term.allLanguages' })}</div>
              <dl style={{ display: 'grid', gridTemplateColumns: 'auto minmax(0, 1fr)', gap: '4px 14px', margin: 0, fontSize: '.92rem' }}>
                {LANGS.filter((code) => term.labels && term.labels[code]).map((code) => (
                  <div key={code} style={{ display: 'contents' }}>
                    <dt style={{ color: 'var(--brand-muted)', textTransform: 'capitalize' }}>{langName(code, locale)}</dt>
                    <dd style={{ margin: 0, color: '#f4f4f4' }}>
                      {term.labels[code]}
                      {code === 'el' && term.el_roman && (
                        <span style={{ color: 'var(--brand-muted)', fontStyle: 'italic' }}> — {term.el_roman}</span>
                      )}
                    </dd>
                  </div>
                ))}
              </dl>

              {/* Fédération ENTRANTE : ce terme dans les catalogues partenaires */}
              {Array.isArray(term.catalog_links) && term.catalog_links.length > 0 && (
                <>
                  <div style={sectionTitle}>{t({ id: 'ficedl.term.partnerCatalogs' })}</div>
                  <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
                    {term.catalog_links.map((cl, i) => (
                      <li key={`${cl.href}-${i}`}>
                        <a href={cl.href} target="_blank" rel="noopener noreferrer" style={{ ...linkBlue, fontSize: '.9rem' }}>
                          {cl.name || cl.href}
                        </a>
                      </li>
                    ))}
                  </ul>
                </>
              )}

              {/* Source : lien vers la fiche sur le SPIP FICEDL */}
              {term.source_url && (
                <p style={{ marginTop: 24 }}>
                  <a href={term.source_url} target="_blank" rel="noopener noreferrer" style={{ ...linkBlue, fontSize: '.9rem' }}>
                    {t({ id: 'ficedl.term.source' })} ↗
                  </a>
                </p>
              )}

              <p style={{ color: 'var(--brand-muted)', fontSize: '.78rem', marginTop: 20, fontStyle: 'italic' }}>
                {t({ id: 'ficedl.antiforkNote' })}
              </p>
            </>
          )}
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
