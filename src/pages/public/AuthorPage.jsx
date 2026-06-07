import { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { detectLocale } from '@/i18n';
import { getCountryName } from '@/lib/countries';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Spinner, EmptyState } from '@/components/ui';
import './AuthorPage.css';
import { buildBibtex, buildRis, triggerDownload } from '@/lib/citations';

const PHOTO_BASE = 'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/authors/';
const COVER_BASE = 'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/covers/';

function yearsLabel(birth, death) {
  const b = birth ? String(birth) : '';
  const d = death ? String(death) : '';
  if (!b && !d) return '';
  if (b && d) return `${b} – ${d}`;
  if (b) return `${b} –`;
  return `– ${d}`;
}

// #AUT4 — pastille de disponibilité (connecté·es uniquement, doctrine A1/A2/A3).
function bookAvail(r, t) {
  if (!r) return null;
  const c = Number(r.session_available_count) || 0;
  const h = (r.session_status_hint || '').toLowerCase();
  if (h === 'consultavel_no_local') return { label: t({ id: 'catalog.avail.consult' }), cls: 'warn' };
  if (c > 0) return { label: t({ id: 'catalog.avail.availableCount' }, { count: c }), cls: 'ok' };
  return null; // on n'encombre pas les cartes avec « indisponible »
}

function buildHeroIntro(author, booksCount, t, locale) {
  const parts = [];
  // FIX B.1: use i18n-iso-countries helper instead of static i18n country keys
  // — country.* keys were missing in all 6 locales, showing raw ISO code.
  if (author.country) {
    const countryName = getCountryName(author.country, locale);
    if (countryName) parts.push(countryName);
  }
  const years = yearsLabel(author.birth_year, author.death_year);
  if (years) parts.push(years);
  if (booksCount > 0) parts.push(t({ id: 'author.booksCount' }, { count: booksCount }));
  return parts.join(' · ') || '';
}

// Structured meta is now a dedicated jsonb column (authors.structured_meta).
// Legacy marker-based encoding in notes has been migrated.

export default function AuthorPage() {
  const { id } = useParams();
  const { user } = useAuth();
  const { formatMessage: t, locale } = useIntl();
  const { librarySlug } = useLibrary();
  const navigate = useNavigate();

  const [author, setAuthor] = useState(null);
  const [books, setBooks] = useState([]);
  const [related, setRelated] = useState([]); // #AUT1 : réseau d'auteur·rices (par contenu)
  const [availMap, setAvailMap] = useState({}); // #AUT4 : dispo session-aware par livre
  const [loading, setLoading] = useState(true);
  const isAuth = !!user;
  const [toast, setToast] = useState(''); // #AUT3 : retour copie permalien

  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        const [authorRes, booksRes, transRes, relRes] = await Promise.all([
          supabase.from('authors').select('*').eq('id', id).single(),
          supabase.from('author_books_public').select('*').eq('author_id', id),
          supabase.from('author_translations').select('lang, biography').eq('author_id', id),
          supabase.schema('api').rpc('similar_authors', { p_author_id: id }), // #AUT1
        ]);
        if (Array.isArray(relRes?.data)) setRelated(relRes.data);

        if (authorRes.data) {
          const authorData = authorRes.data;
          // Attach translations as biography_i18n map
          if (transRes.data?.length) {
            authorData.biography_i18n = {};
            // FIX B.1 (bonus): rename loop variable `t` -> `tr` to avoid shadowing
            // the outer formatMessage `t`. Was harmless here (used as object) but
            // a latent trap for future edits.
            transRes.data.forEach(tr => { authorData.biography_i18n[tr.lang] = tr.biography; });
          }
          setAuthor(authorData);
        }
        if (booksRes.data) {
          // Trier par année décroissante puis titre
          const sorted = [...booksRes.data].sort((a, b) => {
            const ya = parseInt(a.ano) || 0, yb = parseInt(b.ano) || 0;
            if (yb !== ya) return yb - ya;
            return (a.titulo || '').localeCompare(b.titulo || '');
          });
          setBooks(sorted);
          // #AUT4 — dispo session-aware par livre (connecté·es uniquement)
          if (user && sorted.length) {
            try {
              const ids = sorted.map(b => b.book_id).filter(Boolean);
              const av = await supabase.schema('api').from('catalog_list_session_v1')
                .select('book_id, session_status_hint, session_available_count')
                .in('book_id', ids);
              if (Array.isArray(av.data)) {
                const map = {};
                av.data.forEach(r => { map[r.book_id] = r; });
                setAvailMap(map);
              }
            } catch { /* non-bloquant */ }
          }
        }
      } catch (err) {
        console.error('Author fetch error:', err);
      } finally {
        setLoading(false);
      }
    })();
  }, [id, user?.id]);

  useDocumentTitle(
    author
      ? (author.preferred_name || author.sort_name || t({ id: 'author.title' }))
      : t({ id: 'author.title' })
  );

  if (loading) {
    return <PageShell><Topbar /><div style={{ textAlign: 'center', padding: 60 }}><Spinner size={32} /></div></PageShell>;
  }

  if (!author) {
    return (
      <PageShell><Topbar />
        <EmptyState message={t({ id: 'author.notFound' })} />
        <Footer />
      </PageShell>
    );
  }

  const displayName = author.preferred_name || author.sort_name || t({ id: 'author.noName' });
  const secondaryName = [author.sort_name, author.preferred_name]
    .map(v => String(v || '').trim())
    .find(v => v && v !== displayName) || '';
  const intro = buildHeroIntro(author, books.length, t, locale);
  const hasPhoto = !!author.photo_object_path;
  const sourceLabel = [author.source_kind, author.source_label].filter(Boolean).join(' · ');
  const meta = author.structured_meta || {};

  // #AUT3 — barre d'actions d'autorité (permalien + export biblio)
  const permalink = `${window.location.origin}/autor/${id}`;
  const fileBase = String(author.sort_name || displayName || `autor-${id}`).replace(/[^\w.-]/g, '_');
  const showToast = (m) => { setToast(m); setTimeout(() => setToast(''), 1800); };
  const copyText = async (text) => {
    try { await navigator.clipboard.writeText(text); } catch { /* clipboard indispo */ }
    showToast(t({ id: 'book.actions.copied' }));
  };
  const exportBiblio = (kind) => {
    if (!books.length) return;
    const origin = window.location.origin;
    if (kind === 'bib') {
      const text = books.map(b => buildBibtex(b, displayName, `${origin}/livro/${b.book_id}`)).join('\n');
      triggerDownload(`${fileBase}.bib`, text, 'application/x-bibtex;charset=utf-8');
    } else {
      const text = books.map(b => buildRis(b, [displayName], `${origin}/livro/${b.book_id}`)).join('');
      triggerDownload(`${fileBase}.ris`, text, 'application/x-research-info-systems;charset=utf-8');
    }
  };

  return (
    <PageShell>
      <Topbar />

      {/* Navigation */}
      <div className="ab-autor-topbar">
        <Link to="/" className="ab-button ab-button--secondary">{t({ id: 'author.backToCatalog' })}</Link>
        {user
          ? <Button variant="secondary" onClick={() => navigate('/conta')}>{t({ id: 'author.accountPanel' })}</Button>
          : <Button onClick={() => navigate('/cadastro')}>{t({ id: 'nav.login' })}</Button>}
      </div>

      {/* #AUT3 — Barre d'actions d'autorité */}
      <div className="ab-autor-toolbar">
        <button className="ab-button ab-button--mini" onClick={() => copyText(permalink)}>
          {t({ id: 'book.actions.permalink' })}
        </button>
        {books.length > 0 && (
          <>
            <span className="ab-autor-toolbar-sep" aria-hidden="true">·</span>
            <span className="ab-autor-toolbar-export">{t({ id: 'book.actions.export' })} :</span>
            <button className="ab-button ab-button--mini" onClick={() => exportBiblio('bib')}>BibTeX</button>
            <button className="ab-button ab-button--mini" onClick={() => exportBiblio('ris')}>RIS</button>
          </>
        )}
        {toast && <span className="ab-autor-toast" role="status">{toast}</span>}
      </div>

      {/* Hero */}
      <Hero title={displayName} subtitle={intro}>
        <div className="ab-autor-chips">
          {/* B1 : naissance/décès, pays et nombre de livres figurent déjà dans le sous-titre
              du Hero — on ne les répète pas en chips. Ces emplacements accueilleront en B2
              les dates d'activité et l'appartenance (organisation/syndicat) quand les champs
              existeront sur la table authors. */}
          {/* B2 : periode d'activite + affiliation (depuis la meta structuree de notes). */}
          {meta.activityPeriod && <Pill>{t({ id: 'author.activityPeriod' })}: {meta.activityPeriod}</Pill>}
          {meta.affiliation && <Pill>{t({ id: 'author.affiliation' })}: {meta.affiliation}</Pill>}
          {author.viaf_id && (
            <Pill>
              VIAF: <a href={`https://viaf.org/viaf/${author.viaf_id}`} target="_blank" rel="noopener noreferrer">{author.viaf_id}</a>
            </Pill>
          )}
          {author.isni && (
            <Pill>
              ISNI: <a href={`https://isni.org/isni/${author.isni.replace(/\s/g, '')}`} target="_blank" rel="noopener noreferrer">{author.isni}</a>
            </Pill>
          )}
          {author.wikidata_id && (
            <Pill>
              Wikidata: <a href={`https://www.wikidata.org/wiki/${author.wikidata_id}`} target="_blank" rel="noopener noreferrer">{author.wikidata_id}</a>
            </Pill>
          )}
          {sourceLabel && <Pill>{t({ id: 'author.source' })}: {sourceLabel}</Pill>}
        </div>
      </Hero>

      {/* Grille : détail + livres */}
      <div className="ab-autor-grid">
        {/* Carte biographie */}
        <div className="ab-autor-card">
          <div className="ab-autor-detail">
            {/* Photo */}
            <div className="ab-autor-photo">
              {hasPhoto ? (
                <img src={`${PHOTO_BASE}${author.photo_object_path}`} alt={displayName} />
              ) : (
                <div className="ab-autor-photo__placeholder">
                  <span>{displayName[0]}</span>
                </div>
              )}
            </div>

            {/* Contenu */}
            <div className="ab-autor-content">
              {secondaryName && <p className="ab-autor-sort-name">{secondaryName}</p>}
              <h2 className="ab-autor-section-title">{t({ id: 'author.bio' })}</h2>
              {(() => {
                const locale = detectLocale();
                const i18n = author.biography_i18n || {};
                // Fallback chain: exact locale → base language → pt-BR → any available → original column
                const bio = i18n[locale]
                  || i18n[locale.split('-')[0]]
                  || i18n['pt-BR']
                  || Object.values(i18n)[0]
                  || author.biography
                  || author.notes
                  || '—';
                // Show available translations indicator
                const availLangs = Object.keys(i18n);
                const showingLang = i18n[locale] ? locale : i18n[locale.split('-')[0]] ? locale.split('-')[0] : i18n['pt-BR'] ? 'pt-BR' : availLangs[0] || null;
                return (
                  <>
                    <p className="ab-autor-bio" style={{ whiteSpace: 'pre-line' }}>{bio}</p>
                    {availLangs.length > 1 && (
                      <p style={{ fontSize: '.75rem', color: 'var(--brand-muted)', marginTop: 4 }}>
                        {t({ id: 'author.bioAvailableLangs' })}: {availLangs.join(', ')}
                        {showingLang && showingLang !== locale && <span> — {t({ id: 'author.bioShowingFallback' }, { lang: showingLang })}</span>}
                      </p>
                    )}
                    {availLangs.length <= 1 && showingLang && showingLang !== locale && showingLang !== locale.split('-')[0] && (
                      <p style={{ fontSize: '.75rem', color: 'var(--brand-muted)', marginTop: 4 }}>
                        {t({ id: 'author.bioShowingFallback' }, { lang: showingLang })}
                      </p>
                    )}
                  </>
                );
              })()}
            </div>
          </div>
        </div>

        {/* Liste des livres */}
        <div className="ab-autor-card">
          <h2 className="ab-autor-section-title">{t({ id: 'author.booksTitle' })}</h2>
          {books.length === 0 ? (
            <p className="ab-autor-empty">{t({ id: 'author.noBooks' })}</p>
          ) : (
            <div className="ab-autor-books">
              {books.map((book) => (
                <Link
                  key={book.book_id}
                  to={`/livro/${book.book_id}`}
                  className="ab-autor-book-card"
                >
                  {book.cover_object_path && (
                    <img
                      className="ab-autor-book-cover"
                      src={`${COVER_BASE}${book.cover_object_path}`}
                      alt=""
                      loading="lazy"
                    />
                  )}
                  <div className="ab-autor-book-info">
                    <div className="ab-autor-book-title">{book.titulo || t({ id: 'author.bookNoTitle' })}</div>
                    {book.subtitulo && <div className="ab-autor-book-subtitle">{book.subtitulo}</div>}
                    <div className="ab-autor-book-meta">
                      {book.bib_ref && <span>{t({ id: 'book.meta.ref' })}: {book.bib_ref}</span>}
                      {book.ano && <span>{t({ id: 'book.meta.year' })}: {book.ano}</span>}
                    </div>
                    <div className="ab-autor-book-meta">
                      {book.editora && <span>{book.editora}</span>}
                      {book.role && <span>{t({ id: 'author.role' })}: {book.role}</span>}
                    </div>
                    {isAuth && availMap[book.book_id] && (() => {
                      const s = bookAvail(availMap[book.book_id], t);
                      return s ? <div className="ab-autor-book-avail"><span className={`ab-status-dot ab-status-dot--${s.cls}`}>{s.label}</span></div> : null;
                    })()}
                  </div>
                </Link>
              ))}
            </div>
          )}
        </div>

        {/* #AUT1 — Réseau d'auteur·rices (par contenu) */}
        {related.length > 0 && (
          <div className="ab-autor-card">
            <h2 className="ab-autor-section-title">{t({ id: 'author.related.title' })}</h2>
            <div className="ab-autor-related">
              {related.map(r => (
                <Link key={r.author_id} to={`/autor/${r.author_id}`} className="ab-autor-related-chip">
                  {r.label}
                  {r.shared_count > 0 && <span className="ab-autor-related-count" title={t({ id: 'author.related.shared' })}>{r.shared_count}</span>}
                </Link>
              ))}
            </div>
          </div>
        )}
      </div>

      <Footer />
    </PageShell>
  );
}
