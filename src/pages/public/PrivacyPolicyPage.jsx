import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { useLibrary } from '@/contexts/LibraryContext';
import { supabase } from '@/lib/supabase';
import LibraryPrivacySection from '@/components/privacy/LibraryPrivacySection';

// ── Helpers de mise en forme ─────────────────────────────
const sectionStyle = {
  marginBottom: 28,
};

const h2Style = {
  fontSize: '1.15rem',
  fontWeight: 700,
  marginBottom: 10,
  marginTop: 0,
  fontFamily: 'var(--brand-font-body)',
  textTransform: 'none',
  color: 'var(--brand-fg, #f4f4f4)',
};

const pStyle = {
  fontSize: '.92rem',
  lineHeight: 1.6,
  color: 'var(--brand-fg, #e8e8e8)',
  marginTop: 0,
  marginBottom: 10,
};

const ulStyle = {
  fontSize: '.92rem',
  lineHeight: 1.6,
  color: 'var(--brand-fg, #e8e8e8)',
  paddingLeft: 22,
  marginTop: 0,
  marginBottom: 10,
};

const noticeStyle = {
  padding: '12px 14px',
  borderRadius: 8,
  background: 'rgba(180,83,9,.06)',
  border: '1px solid rgba(180,83,9,.18)',
  fontSize: '.85rem',
  color: 'var(--brand-muted, #ccc)',
  marginTop: 16,
  marginBottom: 16,
};

const updatedStyle = {
  fontSize: '.82rem',
  color: 'var(--brand-muted, #999)',
  fontStyle: 'italic',
  marginTop: 32,
  paddingTop: 16,
  borderTop: '1px solid rgba(255,255,255,.08)',
};

// ── Page ─────────────────────────────────────────────────
export default function PrivacyPolicyPage() {
  const { formatMessage: t, locale } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.privacy' }));
  const { slug: urlSlug } = useParams(); // /privacidade/:slug
  const { libraries: userMemberships } = useLibrary();

  // Si on est sur /privacidade/:slug, on fetch la library correspondante pour avoir son name complet
  const [urlLibrary, setUrlLibrary] = useState(null);

  useEffect(() => {
    if (!urlSlug) {
      setUrlLibrary(null);
      return;
    }
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('libraries')
        .select('id, slug, name, short_name')
        .eq('slug', urlSlug)
        .eq('is_active', true)
        .maybeSingle();
      if (!cancelled) {
        // Si la biblio n'existe pas, on garde un objet minimal pour que le composant tente quand même
        // de fetch le .md (il y aura un 404 silencieux, c'est OK)
        setUrlLibrary(data || { slug: urlSlug, name: urlSlug, short_name: urlSlug });
      }
    })();
    return () => { cancelled = true; };
  }, [urlSlug]);

  // Résolution des biblios à afficher :
  // - Si /privacidade/:slug → uniquement cette biblio (URL canonique pour partage public)
  // - Sinon, si user connecté avec biblios actives → toutes ses biblios actives
  // - Sinon → aucune biblio (politique commune AnarBib seule)
  const librariesToShow = urlSlug
    ? (urlLibrary ? [urlLibrary] : [])
    : (userMemberships || [])
        .map(m => m.libraries)
        .filter(Boolean);

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '24px 16px 48px' }}>
        <h1 style={{
          fontSize: '1.75rem',
          fontWeight: 800,
          marginBottom: 6,
          fontFamily: 'var(--brand-font-body)',
          textTransform: 'none',
        }}>
          {t({ id: 'privacy.title' })}
        </h1>
        <p style={{ color: 'var(--brand-muted)', marginBottom: 28, fontSize: '.95rem' }}>
          {t({ id: 'privacy.subtitle' })}
        </p>

        <section style={sectionStyle}>
          <p style={pStyle}>{t({ id: 'privacy.intro' })}</p>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s1.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.s1.body' })}</p>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s2.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.s2.collected' })}</p>
          <ul style={ulStyle}>
            <li>{t({ id: 'privacy.s2.item.email' })}</li>
            <li>{t({ id: 'privacy.s2.item.username' })}</li>
            <li>{t({ id: 'privacy.s2.item.password' })}</li>
            <li>{t({ id: 'privacy.s2.item.name' })}</li>
            <li>{t({ id: 'privacy.s2.item.loans' })}</li>
            <li>{t({ id: 'privacy.s2.item.lang' })}</li>
            <li>{t({ id: 'privacy.s2.item.libraries' })}</li>
          </ul>
          <p style={pStyle}>{t({ id: 'privacy.s2.notCollected' })}</p>
          <ul style={ulStyle}>
            <li>{t({ id: 'privacy.s2.notItem.birth' })}</li>
            <li>{t({ id: 'privacy.s2.notItem.address' })}</li>
            <li>{t({ id: 'privacy.s2.notItem.phone' })}</li>
            <li>{t({ id: 'privacy.s2.notItem.profession' })}</li>
            <li>{t({ id: 'privacy.s2.notItem.tracking' })}</li>
            <li>{t({ id: 'privacy.s2.notItem.analytics' })}</li>
          </ul>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s3.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.s3.body' })}</p>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s4.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.s4.body' })}</p>
          <div style={noticeStyle}>{t({ id: 'privacy.s4.notice' })}</div>
        </section>

        {/* ── Durée de conservation (Phase 4a RGPD) ──────────────────── */}
        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.retention.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.retention.body' })}</p>
          <ul style={ulStyle}>
            <li>{t({ id: 'privacy.retention.loans' })}</li>
            <li>{t({ id: 'privacy.retention.reservations' })}</li>
            <li>{t({ id: 'privacy.retention.consultations' })}</li>
            <li>{t({ id: 'privacy.retention.notifications' })}</li>
            <li>{t({ id: 'privacy.retention.profile' })}</li>
          </ul>
          <p style={pStyle}>{t({ id: 'privacy.retention.override' })}</p>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s5.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.s5.body' })}</p>
          <ul style={ulStyle}>
            <li>{t({ id: 'privacy.s5.right.access' })}</li>
            <li>{t({ id: 'privacy.s5.right.rectify' })}</li>
            <li>{t({ id: 'privacy.s5.right.delete' })}</li>
            <li>{t({ id: 'privacy.s5.right.portable' })}</li>
            <li>{t({ id: 'privacy.s5.right.object' })}</li>
            <li>{t({ id: 'privacy.s5.right.limit' })}</li>
          </ul>
          <p style={pStyle}>
            {t({ id: 'privacy.s5.exercise' })}{' '}
            <Link to="/conta" style={{ color: 'var(--brand-accent, #c44)' }}>
              {t({ id: 'privacy.s5.linkAccount' })}
            </Link>
            .
          </p>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s6.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.s6.body' })}</p>
          <ul style={ulStyle}>
            <li>{t({ id: 'privacy.s6.subprocessor.supabase' })}</li>
            <li>{t({ id: 'privacy.s6.subprocessor.brevo' })}</li>
            <li>{t({ id: 'privacy.s6.subprocessor.codeberg' })}</li>
          </ul>
          <p style={pStyle}>{t({ id: 'privacy.s6.transfer' })}</p>
          <p style={pStyle}>
            <strong>{t({ id: 'privacy.s6.noResale' })}</strong>
          </p>
          <p style={pStyle}>
            {t({ id: 'privacy.s6.dpa' })}{' '}
            <a
              href={`https://codeberg.org/anarbib/anarbib/src/branch/main/docs/legal/dpa-${locale}.md`}
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: 'var(--brand-accent, #c44)' }}
            >
              {t({ id: 'privacy.s6.dpa.link' })}
            </a>
            .
          </p>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s7.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.s7.body' })}</p>
          <ul style={ulStyle}>
            <li>{t({ id: 'privacy.s7.measure.tls' })}</li>
            <li>{t({ id: 'privacy.s7.measure.hash' })}</li>
            <li>{t({ id: 'privacy.s7.measure.rls' })}</li>
            <li>{t({ id: 'privacy.s7.measure.minimization' })}</li>
            <li>{t({ id: 'privacy.s7.measure.audit' })}</li>
          </ul>
          <p style={pStyle}>{t({ id: 'privacy.s7.honest' })}</p>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s8.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.s8.body' })}</p>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s9.title' })}</h2>
          <p style={pStyle}>{t({ id: 'privacy.s9.body' })}</p>
        </section>

        <section style={sectionStyle}>
          <h2 style={h2Style}>{t({ id: 'privacy.s10.title' })}</h2>
          <p style={pStyle}>
            {t({ id: 'privacy.s10.body' })}{' '}
            <a
              href="mailto:contato@anarbib.org"
              style={{ color: 'var(--brand-accent, #c44)' }}
            >
              contato@anarbib.org
            </a>
            .
          </p>
          <p style={pStyle}>{t({ id: 'privacy.s10.authority' })}</p>
        </section>

        {/* ── Sections spécifiques par bibliothèque ─────────────────── */}
        {/* Affichées si:                                                   */}
        {/*   - URL canonique /privacidade/:slug   → cette biblio           */}
        {/*   - User connecté avec biblios actives → ses biblios            */}
        {/* Le composant gère lui-même le 404 silencieux si pas de .md.    */}
        {librariesToShow.map(lib => (
          <LibraryPrivacySection
            key={lib.slug}
            library={lib}
            locale={locale}
          />
        ))}

        <p style={updatedStyle}>{t({ id: 'privacy.updated' })}</p>
      </div>
      <Footer />
    </PageShell>
  );
}
