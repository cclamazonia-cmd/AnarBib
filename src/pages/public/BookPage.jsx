import { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Spinner, EmptyState } from '@/components/ui';
import './BookPage.css';

const COVER_BASE = 'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/covers/';
const STORAGE_BASE = 'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/';

// Material type labels are resolved via i18n inside the component

function parseJson(v) { if (!v) return null; if (typeof v === 'object') return v; try { return JSON.parse(v); } catch { return null; } }

function getStatusInfo(book, sessionCtx, isAuth, t) {
  if (!isAuth || !sessionCtx) {
    if (book.loanable === false) return { label: t({ id: 'catalog.avail.consult' }), cls:'warn' };
    return { label: t({ id: 'catalog.avail.check' }), cls:'muted' };
  }
  const h = (sessionCtx.session_status_hint || '').toLowerCase();
  if (!h || h === 'sem_biblioteca_de_sessao') {
    if (book.loanable === false) return { label: t({ id: 'catalog.avail.consult' }), cls:'warn' };
    if (book.available_count > 0) return { label: t({ id: 'catalog.avail.availableCount' }, { count: book.available_count }), cls:'ok' };
    return { label: t({ id: 'catalog.avail.check' }), cls:'muted' };
  }
  if (h === 'indisponivel_para_voce') return { label: t({ id: 'catalog.avail.unavailUser' }), cls:'bad' };
  if (h === 'consultavel_no_local') return { label: t({ id: 'catalog.avail.consult' }), cls:'warn' };
  if (h === 'no_acervo_da_sua_biblioteca') {
    const c = Number(sessionCtx.session_available_count) || 0;
    if (c > 0) return { label: t({ id: 'catalog.avail.availableCount' }, { count: c }), cls:'ok' };
    // Unavailable but with expected return date
    if (sessionCtx.session_next_available_on) {
      return { label: t({ id: 'book.nextAvailable' }, { date: new Date(sessionCtx.session_next_available_on).toLocaleDateString() }), cls:'warn' };
    }
    return { label: t({ id: 'catalog.avail.unavailNow' }), cls:'bad' };
  }
  if (h === 'indisponivel_no_momento') {
    if (sessionCtx.session_next_available_on) {
      return { label: t({ id: 'book.nextAvailable' }, { date: new Date(sessionCtx.session_next_available_on).toLocaleDateString() }), cls:'warn' };
    }
    return { label: t({ id: 'catalog.avail.unavailNow' }), cls:'bad' };
  }
  return { label: t({ id: 'catalog.avail.check' }), cls:'muted' };
}

// ── Génération ISBD simplifiée ─────────────────────────────
function buildIsbdStatement(b) {
  const parts = [];
  // Zone 1 : Titre et mention de responsabilité
  let z1 = b.titulo || '';
  if (b.subtitulo) z1 += ` : ${b.subtitulo}`;
  if (b.autor || b.author_display) z1 += ` / ${b.author_display || b.autor}`;
  if (b.tradutor) z1 += ` ; trad. ${b.tradutor}`;
  if (b.organizador) z1 += ` ; org. ${b.organizador}`;
  if (z1) parts.push(z1);
  // Zone 2 : Édition
  if (b.edicao) parts.push(b.edicao);
  // Zone 4 : Publication
  const z4parts = [b.local_publicacao, b.editora, b.ano].filter(Boolean);
  if (z4parts.length) parts.push(z4parts.join(' : '));
  // Zone 5 : Description physique
  if (b.paginas) parts.push(`${b.paginas} p.`);
  // Zone 6 : Collection
  if (b.colecao) parts.push(`(${b.colecao})`);
  // Zone 8 : ISBN/ISSN
  if (b.isbn) parts.push(`ISBN ${b.isbn}`);
  if (b.issn) parts.push(`ISSN ${b.issn}`);
  return parts.join('. — ');
}

function buildIsbdZones(b, t) {
  const zones = [];
  // Zone 1
  let z1 = b.titulo || '';
  if (b.subtitulo) z1 += ` : ${b.subtitulo}`;
  let resp = b.author_display || b.autor || '';
  if (b.tradutor) resp += ` ; trad. ${b.tradutor}`;
  if (b.organizador) resp += ` ; org. ${b.organizador}`;
  if (z1) zones.push({ label: t({ id: 'book.isbd.zone1' }), value: resp ? `${z1} / ${resp}` : z1 });
  if (b.edicao) zones.push({ label: t({ id: 'book.isbd.zone2' }), value: b.edicao });
  const z4 = [b.local_publicacao, b.editora, b.ano].filter(Boolean).join(' : ');
  if (z4) zones.push({ label: t({ id: 'book.isbd.zone4' }), value: z4 });
  if (b.paginas) zones.push({ label: t({ id: 'book.isbd.zone5' }), value: `${b.paginas} p.` });
  if (b.colecao) zones.push({ label: t({ id: 'book.isbd.zone6' }), value: b.colecao });
  if (b.notas) zones.push({ label: t({ id: 'book.isbd.zone7' }), value: b.notas });
  const z8 = [b.isbn ? `ISBN ${b.isbn}` : '', b.issn ? `ISSN ${b.issn}` : ''].filter(Boolean).join(' ; ');
  if (z8) zones.push({ label: t({ id: 'book.isbd.zone8' }), value: z8 });
  if (b.assuntos) zones.push({ label: t({ id: 'book.isbd.subjects' }), value: b.assuntos });
  if (b.cdd) zones.push({ label: 'CDD', value: b.cdd });
  return zones;
}

export default function BookPage() {
  const { id } = useParams();
  const { user } = useAuth();
  const { formatMessage: t } = useIntl();
  const { librarySlug, libraryName: sessionLibName } = useLibrary();
  const navigate = useNavigate();
  const isAuth = !!user;

  const [book, setBook] = useState(null);
  const [sessionCtx, setSessionCtx] = useState(null);
  const [digitalAccess, setDigitalAccess] = useState(null);
  const [loading, setLoading] = useState(true);
  const [reserveStatus, setReserveStatus] = useState('');
  const [reserveError, setReserveError] = useState(false);
  const [viewMode, setViewMode] = useState('standard'); // 'standard' | 'isbd'

  // ── Chargement ───────────────────────────────────────────
  useEffect(() => {
    (async () => {
      setLoading(true);
      setDigitalAccess(null);
      setSessionCtx(null);
      setViewMode('standard');
      setReserveStatus('');
      try {
        // Charger le livre
        let bookData = null;
        const { data } = await supabase.from('v_book_detail_public_v2').select('*').eq('book_id', id).limit(1).maybeSingle();
        if (data) bookData = data;
        else {
          const fb = await supabase.from('books').select('*').eq('id', id).maybeSingle();
          if (fb.data) bookData = fb.data;
        }
        setBook(bookData);

        if (!bookData) return;

        const bookId = Number(bookData.book_id || bookData.id || 0);

        // Charger les ressources numériques via RPC
        if (bookId > 0) {
          try {
            const rpc = await supabase.rpc('get_book_primary_public_digital_asset_v2', { p_book_id: bookId });
            const row = Array.isArray(rpc.data) ? rpc.data?.[0] : rpc.data;
            if (row && (row.asset_id || (row.storage_bucket && row.storage_path))) {
              setDigitalAccess({
                hasPublicAccess: true,
                assetId: row.asset_id,
                resourceType: row.resource_type,
                usageType: row.usage_type,
                bucket: row.storage_bucket,
                path: row.storage_path,
                sourceName: row.source_name,
                sourceUrl: row.source_url,
                attribution: row.attribution_text,
                rights: row.rights_status,
                label: row.label,
              });
            }
          } catch {}

          // Aussi vérifier les restricted pour utilisateurs connectés
          if (user && !digitalAccess) {
            try {
              const rpc2 = await supabase.rpc('fn_book_restricted_pdf_state_for_current_user', { p_bib_ref: bookData.bib_ref });
              const r2 = Array.isArray(rpc2.data) ? rpc2.data?.[0] : rpc2.data;
              if (r2?.has_access) {
                setDigitalAccess({
                  hasPublicAccess: false,
                  hasRestrictedAccess: true,
                  canReadNow: r2.has_access,
                  bucket: r2.bucket_name,
                  path: r2.object_path,
                });
              }
            } catch {}
          }
        }

        // Charger le contexte session
        if (user && bookId > 0) {
          try {
            const rpc = await supabase.rpc('fn_v2_book_session_context_for_current_user', {
              p_book_id: bookId, p_bib_ref: null,
            });
            const row = Array.isArray(rpc.data) ? rpc.data?.[0] : rpc.data;
            if (row) setSessionCtx(row);
          } catch {}
        }
      } catch (err) { console.error('Book fetch error:', err); }
      finally { setLoading(false); }
    })();
  }, [id, user]);

  useEffect(() => {
    if (book?.titulo) document.title = `${book.titulo} — AnarBib`;
  }, [book]);

  async function handleReserve() {
    if (!user || !sessionCtx?.session_holding_id) return;
    setReserveStatus(t({ id: 'book.reserve.sending' }));
    setReserveError(false);
    try {
      const { error } = await supabase.rpc('fn_v2_create_reserva_by_holdings', {
        p_user_id: user.id, p_holding_ids: [sessionCtx.session_holding_id],
      });
      if (error) throw error;
      setReserveStatus(t({ id: 'book.reserve.success' }));
    } catch (err) { setReserveError(true); setReserveStatus(t({ id: 'common.errorPrefix' }, { message: err.message })); }
  }

  function buildLerUrl() {
    const base = `/ler/${book.book_id || book.id}`;
    if (digitalAccess?.assetId) return `${base}?asset_id=${digitalAccess.assetId}`;
    if (digitalAccess?.bucket && digitalAccess?.path) {
      return `${base}?public_bucket=${encodeURIComponent(digitalAccess.bucket)}&public_path=${encodeURIComponent(digitalAccess.path)}`;
    }
    return base;
  }

  // ── Rendu ────────────────────────────────────────────────
  if (loading) return <PageShell><Topbar /><div style={{ textAlign:'center', padding:60 }}><Spinner size={32} /></div></PageShell>;
  if (!book) return <PageShell><Topbar /><EmptyState message={t({ id: 'book.notFound' })} /><Footer /></PageShell>;

  const status = getStatusInfo(book, sessionCtx, isAuth, t);
  const holdingsJson = parseJson(book.holding_libraries_json);
  const tombosJson = parseJson(book.tombos_json);
  const tipoKey = book.tipo_material ? `material.${book.tipo_material}` : null;
  const tipoLabel = tipoKey ? t({ id: tipoKey, defaultMessage: book.tipo_material }) : '';
  const hasCover = !!book.cover_object_path;
  const hasDigital = !!digitalAccess?.hasPublicAccess || !!digitalAccess?.hasRestrictedAccess;
  const isbdStatement = buildIsbdStatement(book);
  const isbdZones = buildIsbdZones(book, t);

  return (
    <PageShell>
      <Topbar />

      {/* Navigation */}
      <div className="ab-livro-topbar">
        <Link to="/" className="ab-button ab-button--secondary">{t({ id: 'book.backToCatalog' })}</Link>
        {user
          ? <Button variant="secondary" onClick={() => navigate('/conta')}>{t({ id: 'book.accountPanel' })}</Button>
          : <Button onClick={() => navigate('/cadastro')}>{t({ id: 'nav.login' })}</Button>}
      </div>

      {/* Hero */}
      <Hero title={book.titulo || t({ id: 'book.noTitle' })} subtitle={book.subtitulo || ''}>
        <div className="ab-livro-author">
          <BookAuthorLinks book={book} />
        </div>
        <div className="ab-livro-chips">
          {book.bib_ref && <Pill>{t({ id: 'book.meta.ref' })}: {book.bib_ref}</Pill>}
          {book.ano && <Pill>{t({ id: 'book.meta.year' })}: {book.ano}</Pill>}
          {book.editora && <Pill>{t({ id: 'book.meta.publisher' })}: {book.editora}</Pill>}
          {book.global_exemplares_total > 0 && <Pill>{t({ id: 'book.copies' })}: {book.global_exemplares_total}</Pill>}
          {book.earliest_due_back_at && book.available_count === 0 && (
            <Pill variant="warn">{t({ id: 'book.nextAvailable' }, { date: new Date(book.earliest_due_back_at).toLocaleDateString() })}</Pill>
          )}
        </div>
        {Array.isArray(holdingsJson) && holdingsJson.length > 0 && (
          <div className="ab-livro-holdings-hero">
            {holdingsJson.map((h, i) => (
              <div key={i} className="ab-livro-holding-line">
                <span className="ab-livro-holding-lib">{h.library_name || h.library_slug || '?'}</span>
                <span>— {h.available_count > 0
                  ? t({ id: 'book.holding.available' }, { count: h.available_count })
                  : h.earliest_due_back_at
                    ? t({ id: 'book.holding.unavailableUntil' }, { date: new Date(h.earliest_due_back_at).toLocaleDateString() })
                    : t({ id: 'book.holding.unavailable' })
                }</span>
              </div>
            ))}
          </div>
        )}
      </Hero>

      {/* Carte détail */}
      <div className="ab-livro-card">
        <div className="ab-livro-layout">
          {/* Couverture */}
          <div className="ab-livro-cover">
            {hasCover
              ? <img src={`${COVER_BASE}${book.cover_object_path}`} alt={book.titulo} />
              : <div className="ab-livro-cover__placeholder"><span>{(book.titulo||'?')[0]}</span></div>}
          </div>

          <div className="ab-livro-content">
            {/* Toggle Standard / ISBD */}
            <div className="ab-livro-detail-header">
              <h2 className="ab-livro-section-title">
                {viewMode === 'standard' ? t({ id: 'book.detailsStandard' }) : t({ id: 'book.detailsIsbd' })}
              </h2>
              <button
                className="ab-button ab-button--mini"
                onClick={() => setViewMode(v => v === 'standard' ? 'isbd' : 'standard')}
                aria-pressed={viewMode === 'isbd'}
              >
                {viewMode === 'standard' ? t({ id: 'book.viewIsbd' }) : t({ id: 'book.viewStandard' })}
              </button>
            </div>

            {/* ── Vue Standard ─────────────────────────────── */}
            {viewMode === 'standard' && (
              <>
                <div className="ab-livro-meta-pills">
                  <MetaPill label={t({ id: 'book.meta.ref' })} value={book.bib_ref} always />
                  {tombosJson && Array.isArray(tombosJson) && tombosJson.length > 0 && (
                    <MetaPill label={t({ id: 'book.meta.tombo' })} value={tombosJson.join(', ')} />
                  )}
                  <MetaPill label={t({ id: 'book.meta.year' })} value={book.ano} always />
                  <MetaPill label={t({ id: 'book.meta.publisher' })} value={book.editora} always />
                  <MetaPill label={t({ id: 'book.meta.place' })} value={book.local_publicacao} />
                  <MetaPill label={t({ id: 'book.meta.edition' })} value={book.edicao} />
                  <MetaPill label={t({ id: 'book.meta.isbn' })} value={book.isbn} />
                  <MetaPill label={t({ id: 'book.meta.issn' })} value={book.issn} />
                  <MetaPill label={t({ id: 'book.meta.language' })} value={book.idioma} />
                  <MetaPill label={t({ id: 'book.meta.pages' })} value={book.paginas} />
                  <MetaPill label={t({ id: 'book.meta.type' })} value={tipoLabel} />
                  <MetaPill label={t({ id: 'book.meta.collection' })} value={book.colecao} />
                  <MetaPill label={t({ id: 'book.meta.volume' })} value={book.volume} />
                  <MetaPill label={t({ id: 'book.meta.translator' })} value={book.tradutor} />
                  <MetaPill label={t({ id: 'book.meta.organizer' })} value={book.organizador} />
                  <MetaPill label={t({ id: 'book.meta.secondaryAuthors' })} value={book.autores_secundarios} />
                  <MetaPill label={t({ id: 'book.meta.subjects' })} value={book.assuntos} />
                  <MetaPill label={t({ id: 'book.meta.cdd' })} value={book.cdd} always />
                </div>
                {book.notas && (<><div className="ab-livro-hr" /><p className="ab-livro-desc">{book.notas}</p></>)}
              </>
            )}

            {/* ── Vue ISBD ─────────────────────────────────── */}
            {viewMode === 'isbd' && (
              <div className="ab-livro-isbd">
                <p className="ab-livro-isbd-note">{t({ id: 'book.isbdNote' })}</p>
                <p className="ab-livro-isbd-statement">{isbdStatement || '—'}</p>
                <div className="ab-livro-isbd-zones">
                  {isbdZones.map((z, i) => (
                    <div key={i} className="ab-livro-isbd-zone">
                      <span className="ab-livro-isbd-zone-label">{z.label}</span>
                      <span className="ab-livro-isbd-zone-value">{z.value}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Statut */}
            <div className="ab-livro-status-section">
              <span className={`ab-status-dot ab-status-dot--${status.cls}`}>{status.label}</span>
              {isAuth && sessionCtx?.session_library_name && (
                <span className="ab-livro-status-lib">({sessionCtx.session_library_name})</span>
              )}
            </div>

            {/* Accès numérique */}
            <div className="ab-livro-digital">
              <span className="ab-livro-digital-label">{t({ id: 'book.digital.label' })}</span>
              {hasDigital ? (
                <>
                  <span className="ab-livro-digital-chip ab-livro-digital-chip--yes">
                    {digitalAccess.hasPublicAccess ? t({ id: 'book.digital.yes' }) : t({ id: 'book.digital.activeAccount' })}
                  </span>
                  <Link to={buildLerUrl()} className="ab-button">
                    {digitalAccess.hasPublicAccess ? t({ id: 'book.digital.read' }) : (isAuth ? t({ id: 'book.digital.checkAccess' }) : t({ id: 'book.digital.loginToRead' }))}
                  </Link>
                </>
              ) : (
                <span className="ab-livro-digital-chip ab-livro-digital-chip--no">{t({ id: 'book.digital.no' })}</span>
              )}
            </div>

            {/* Attribution source */}
            {digitalAccess?.sourceName && (
              <div className="ab-livro-digital-source">
                {t({ id: 'book.digital.source' })}: {digitalAccess.sourceUrl
                  ? <a href={digitalAccess.sourceUrl} target="_blank" rel="noopener noreferrer">{digitalAccess.sourceName}</a>
                  : digitalAccess.sourceName}
                {digitalAccess.rights && <span> — {digitalAccess.rights}</span>}
              </div>
            )}

            {/* Actions */}
            <div className="ab-livro-actions">
              {user && sessionCtx?.session_holding_id && status.cls === 'ok' && (
                <Button onClick={handleReserve}>{t({ id: 'book.reserve' })}</Button>
              )}
              {user && (
                <Button variant="secondary" onClick={async () => {
                  try {
                    const { error } = await supabase.from('user_wishlist').upsert({ user_id: user.id, book_id: book.id }, { onConflict: 'user_id,book_id' });
                    if (error) throw error;
                    alert(t({ id: 'book.savedToWishlist' }));
                  } catch (err) {
                    if (err.code === '23505') alert(t({ id: 'book.alreadyInWishlist' }));
                    else alert(`${t({ id: 'common.error' })} ${err.message}`);
                  }
                }}>{t({ id: 'book.saveForLater' })}</Button>
              )}
              {!user && <Link to="/cadastro"><Button>{t({ id: 'book.loginToReserve' })}</Button></Link>}
            </div>

            {reserveStatus && (
              <div className={`ab-livro-reserve-status ${reserveError ? 'ab-livro-reserve-status--error' : ''}`}>
                {reserveStatus}
              </div>
            )}
          </div>
        </div>
      </div>

      <Footer />
    </PageShell>
  );
}

function MetaPill({ label, value, always = false }) {
  const d = String(value ?? '').trim();
  if (!d && !always) return null;
  return (
    <div className="ab-livro-pill">
      <span className="ab-livro-pill__label">{label}:</span>{' '}
      <span className="ab-livro-pill__value">{d || '—'}</span>
    </div>
  );
}

function BookAuthorLinks({ book }) {
  // Essayer authors_json d'abord (plus riche), puis author_chips
  let authors = book.authors_json || book.author_chips;
  if (typeof authors === 'string') {
    try { authors = JSON.parse(authors); } catch { authors = null; }
  }

  if (Array.isArray(authors) && authors.length > 0) {
    return authors.map((a, i) => (
      <span key={a.author_id || i}>
        {i > 0 && ' ; '}
        <Link to={`/autor/${a.author_id}`} className="ab-livro-author-link">
          {a.preferred_name || a.display_name || a.label || '?'}
        </Link>
        {a.role && a.role !== 'autor' && (
          <span className="ab-livro-author-role"> ({a.role})</span>
        )}
      </span>
    ));
  }

  if (book.author_id) {
    return (
      <Link to={`/autor/${book.author_id}`} className="ab-livro-author-link">
        {book.author_display || book.autor || '—'}
      </Link>
    );
  }

  return <>{book.author_display || book.autor || '—'}</>;
}
