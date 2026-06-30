// =============================================================================
// SubjectPage.jsx — fiche PUBLIQUE d'un sujet du thésaurus-matière AnarBib.
// =============================================================================
// Route /thesaurus/:slug — honore l'URI stable THES-URI
// (https://app.anarbib.org/thesaurus/<slug>, engagement de données liées).
// Surface anon, lecture seule, concepts `ativo` uniquement.
//
// Affiche : libellé (pivot pt-BR), synonymes, note de portée, hiérarchie
// (broader/narrower), « voir aussi » (relations), lien vers les livres (OPAC,
// anti-fuite via le filtre catalogue), et — fédération ENTRANTE (P3b) — le bloc
// « dans les catalogues partenaires » issu des descripteurs FICEDL alignés.
// =============================================================================

import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { Link, useParams } from 'react-router-dom';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { supabase } from '@/lib/supabase';
import { pickLabel } from '@/lib/i18nLabel';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

export default function SubjectPage() {
  const { slug } = useParams();
  const { formatMessage: t, locale } = useIntl();

  const [subj, setSubj] = useState(undefined);   // undefined = chargement, null = absent
  const [related, setRelated] = useState([]);
  const [children, setChildren] = useState([]);
  const [bookCount, setBookCount] = useState(0);
  const [ficedl, setFicedl] = useState([]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const api = supabase.schema('api');
      const { data: det } = await api.rpc('subject_detail_v1', { p_slug: slug });
      const s = Array.isArray(det) ? det[0] : det;
      if (cancelled) return;
      if (!s) { setSubj(null); return; }
      setSubj(s);

      // Relations « voir aussi », liens FICEDL, et arbre (pour enfants + compte de livres).
      const [rel, fic, tree] = await Promise.all([
        api.rpc('subject_related_v1', { p_subject_id: s.id }),
        api.rpc('subject_ficedl_links_v1', { p_subject_id: s.id }),
        api.rpc('subject_tree_v1'),
      ]);
      if (cancelled) return;
      setRelated(Array.isArray(rel.data) ? rel.data : []);
      setFicedl(Array.isArray(fic.data) ? fic.data : []);
      const nodes = Array.isArray(tree.data) ? tree.data : [];
      setChildren(nodes.filter((n) => n.parent_id === s.id));
      const self = nodes.find((n) => n.id === s.id);
      setBookCount(self ? self.book_count || 0 : 0);
    })();
    return () => { cancelled = true; };
  }, [slug]);

  const label = subj ? pickLabel(subj.label_i18n, locale, 'pt-BR') : '';
  useDocumentTitle(label || t({ id: 'subject.pageTitle' }));

  // Catalogues partenaires : aplatis les catalog_links de tous les termes FICEDL alignés (dédup par href).
  const partnerLinks = [];
  const seen = new Set();
  for (const f of ficedl) {
    for (const cl of (Array.isArray(f.catalog_links) ? f.catalog_links : [])) {
      if (cl && cl.href && !seen.has(cl.href)) { seen.add(cl.href); partnerLinks.push(cl); }
    }
  }
  const altList = subj ? ((subj.alt_i18n && (subj.alt_i18n[locale] || subj.alt_i18n[(locale || '').split('-')[0]])) || []) : [];

  const panel = {
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)',
    borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)', padding: '24px 24px 32px',
  };
  const sectionTitle = {
    fontSize: '.78rem', textTransform: 'uppercase', letterSpacing: '.05em',
    color: 'var(--brand-muted)', margin: '24px 0 8px', fontWeight: 700,
  };
  const linkBlue = { color: '#93c5fd', textDecoration: 'none' };
  const chip = {
    display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 10px', borderRadius: 999,
    fontSize: '.84rem', background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.12)',
  };

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 860, margin: '0 auto', padding: '24px 16px 48px' }}>
        <div style={panel}>
          {subj === undefined ? (
            <p style={{ color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</p>
          ) : subj === null ? (
            <p style={{ color: 'var(--brand-muted)', fontStyle: 'italic' }}>{t({ id: 'subject.notFound' })}</p>
          ) : (
            <>
              {subj.parent_slug && (
                <div style={{ fontSize: '.82rem', marginBottom: 6 }}>
                  <Link to={`/thesaurus/${subj.parent_slug}`} style={linkBlue}>
                    {pickLabel(subj.parent_label_i18n, locale, 'pt-BR')}
                  </Link>
                  <span style={{ color: 'var(--brand-muted)' }}>  ›  </span>
                </div>
              )}
              <h1 style={{ fontSize: '1.7rem', fontWeight: 800, margin: '0 0 6px', fontFamily: 'var(--brand-font-body)' }}>
                {label}
                {subj.notation && (
                  <span style={{ fontFamily: 'monospace', fontSize: '1rem', color: 'var(--brand-muted)', marginLeft: 10 }}>{subj.notation}</span>
                )}
              </h1>
              {altList.length > 0 && (
                <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem', margin: '0 0 4px' }}>
                  {t({ id: 'subject.altLabels' })} : {altList.join(', ')}
                </p>
              )}
              {subj.scope_note && (
                <p style={{ color: '#d4d4d4', fontSize: '.92rem', margin: '8px 0 0' }}>{subj.scope_note}</p>
              )}

              <p style={{ marginTop: 16 }}>
                <Link to={`/catalogo?subject=${encodeURIComponent(subj.slug)}`} style={{ ...linkBlue, fontSize: '.92rem' }}>
                  {t({ id: 'subject.viewBooks' }, { count: bookCount })} →
                </Link>
              </p>

              {children.length > 0 && (
                <>
                  <div style={sectionTitle}>{t({ id: 'subject.narrower' })}</div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                    {children.map((c) => (
                      <Link key={c.id} to={`/thesaurus/${c.slug}`} style={{ ...chip, ...linkBlue }}>
                        {pickLabel(c.label_i18n, locale, 'pt-BR')}
                      </Link>
                    ))}
                  </div>
                </>
              )}

              {related.length > 0 && (
                <>
                  <div style={sectionTitle}>{t({ id: 'subject.related' })}</div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                    {related.map((r) => (
                      <Link key={r.id} to={`/thesaurus/${r.slug}`} style={{ ...chip, ...linkBlue }}>
                        {pickLabel(r.label_i18n, locale, 'pt-BR')}
                      </Link>
                    ))}
                  </div>
                </>
              )}

              {/* Fédération ENTRANTE (P3b) : descripteurs FICEDL alignés + catalogues partenaires */}
              {ficedl.length > 0 && (
                <>
                  <div style={sectionTitle}>{t({ id: 'subject.ficedlAlignment' })}</div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 10 }}>
                    {ficedl.map((f) => (
                      <Link key={f.mot_id} to={`/thesaurus-ficedl/${f.mot_id}`} style={{ ...chip, ...linkBlue }}>
                        {pickLabel(f.labels, locale, 'fr')}
                        <span style={{ fontSize: '.68rem', color: 'var(--brand-muted)', textTransform: 'uppercase' }}>
                          {f.match_type === 'close' ? t({ id: 'subject.matchClose' }) : t({ id: 'subject.matchExact' })}
                        </span>
                      </Link>
                    ))}
                  </div>
                  {partnerLinks.length > 0 && (
                    <>
                      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '6px 0' }}>
                        {t({ id: 'ficedl.term.partnerCatalogs' })}
                      </div>
                      <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 5 }}>
                        {partnerLinks.map((cl, i) => (
                          <li key={`${cl.href}-${i}`}>
                            <a href={cl.href} target="_blank" rel="noopener noreferrer" style={{ ...linkBlue, fontSize: '.9rem' }}>
                              {cl.name || cl.href}
                            </a>
                          </li>
                        ))}
                      </ul>
                    </>
                  )}
                </>
              )}
            </>
          )}
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
