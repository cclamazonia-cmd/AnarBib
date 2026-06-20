import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase } from '@/lib/supabase';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Spinner, EmptyState } from '@/components/ui';

const COVER_BASE = 'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/covers/';

// Page Œuvre (P4 v2 Lot A) : titre uniforme, auteur·rice, éditions publiques.
// Données via api.work_public_detail (public-safe : passe par catalog_list_anon_v1).
export default function WorkPage() {
  const { id } = useParams();
  const { formatMessage: t } = useIntl();
  const [work, setWork] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    (async () => {
      try {
        const { data } = await supabase.schema('api').rpc('work_public_detail', { p_work_id: Number(id) });
        if (alive) setWork(data || null);
      } catch { if (alive) setWork(null); }
      finally { if (alive) setLoading(false); }
    })();
    return () => { alive = false; };
  }, [id]);

  useDocumentTitle(work?.uniform_title || t({ id: 'work.page.title' }));

  if (loading) {
    return <PageShell><Topbar /><div style={{ textAlign: 'center', padding: 60 }}><Spinner size={32} /></div></PageShell>;
  }
  if (!work) {
    return <PageShell><Topbar /><EmptyState message={t({ id: 'work.page.notFound' })} /><Footer /></PageShell>;
  }

  const editions = Array.isArray(work.editions) ? work.editions : [];
  const subtitle = [work.author_name, t({ id: 'work.page.editions' }, { count: editions.length })].filter(Boolean).join(' · ');

  return (
    <PageShell>
      <Topbar />
      <Hero title={work.uniform_title} subtitle={subtitle}>
        {work.primary_author_id && work.author_name && (
          <Link to={`/autor/${work.primary_author_id}`} className="ab-button ab-button--secondary ab-button--sm">
            {work.author_name}
          </Link>
        )}
      </Hero>

      <div style={{ maxWidth: 1100, margin: '0 auto', padding: '16px 12px' }}>
        <h2 style={{ fontSize: '1rem', margin: '0 0 12px' }}>{t({ id: 'work.page.editionsHeading' })}</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 14 }}>
          {editions.map(e => (
            <Link key={e.book_id} to={`/livro/${e.book_id}`}
              style={{ display: 'flex', gap: 10, padding: 10, borderRadius: 10, border: '1px solid rgba(255,255,255,.08)', background: 'rgba(0,0,0,.15)', textDecoration: 'none', color: 'inherit' }}>
              {e.cover_object_path
                ? <img src={`${COVER_BASE}${e.cover_object_path}`} alt="" loading="lazy" style={{ width: 48, height: 68, objectFit: 'cover', borderRadius: 4, flexShrink: 0 }} />
                : <div style={{ width: 48, height: 68, borderRadius: 4, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(255,255,255,.06)', fontSize: '1.2rem' }}>{(e.titulo || '?')[0]}</div>}
              <div style={{ minWidth: 0 }}>
                <div style={{ fontSize: '.86rem', fontWeight: 600 }}>{e.titulo}</div>
                <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)' }}>{[e.ano, e.editora].filter(Boolean).join(' · ')}</div>
                {e.idioma && <div style={{ fontSize: '.68rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>{e.idioma}</div>}
              </div>
            </Link>
          ))}
        </div>
      </div>

      <Footer />
    </PageShell>
  );
}
