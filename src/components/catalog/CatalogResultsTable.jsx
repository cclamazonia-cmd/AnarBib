// src/components/catalog/CatalogResultsTable.jsx — E6, Catalogue public, lot 4 (10/10/2026)
// La table des résultats (chargement, vide, lignes par notice ou par œuvre, exemplaires dépliés,
// gestes rapides, pagination), sortie telle quelle avec ses rendus de lignes ; elle reçoit en un
// seul sac de props les valeurs et les gestes de la page qu'elle touchait (liste engendrée par
// analyse des variables libres, sans ressaisie du rendu).
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { yearsLabel } from '@/lib/catalogWorks';
import { coverThumbUrl } from '@/lib/coverThumbs';
import { digitalBadge } from '@/hooks/useDigitalAccess';
import { Button, EmptyState, Spinner } from '@/components/ui';
import { TIPO_ICONS, handleThumbError, libraryNameList, orderLibraryNames, getStatusInfo } from '@/lib/catalogOpac';
import LibraryCell from '@/components/catalog/LibraryCell';
import { languageLabel } from '@/lib/languages';
import AuthorLinks from '@/components/catalog/AuthorLinks';

export default function CatalogResultsTable(p) {
  const { formatMessage: t } = useIntl();
  const {
    STATUS_RANK,
    accesNumerique,
    books,
    cityByLib,
    compact,
    consultaState,
    consultedBibRefs,
    copiesByBook,
    expandedCopies,
    expandedWorks,
    fetchBooks,
    handleHeaderSort,
    handleQuickConsulta,
    handleQuickReserve,
    handleWishlist,
    hasMore,
    isAuth,
    libPriority,
    loading,
    loadingMore,
    quickConsultaAvailable,
    quickReserveAvailable,
    reserveState,
    reservedBibRefs,
    scrollTable,
    si,
    tableRef,
    tableRows,
    toggleCopies,
    toggleWork,
    totalCount,
    totalFetched,
    wishlistBusy,
    wishlistedIds,
  } = p;

  function badgeNumerique(bookIds) {
    const b = digitalBadge(bookIds.map((id) => accesNumerique.get(Number(id))));
    if (!b) return null;
    const libs = (b.libs || []).join(', ');
    if (b.kind === 'public') {
      const cle = { escuta_online: 'catalog.digital.listenOnline', visualizacao_online: 'catalog.digital.watchOnline',
                    link_externo: 'catalog.digital.externalLink' }[b.usage] || 'catalog.actions.readOnline';
      return <span className="ab-online-badge">{t({ id: cle })}</span>;
    }
    if (b.kind === 'reserved-open') {
      return <span className="ab-online-badge" title={t({ id: 'catalog.digital.reservedFor' }, { libraries: libs })}>
        {t({ id: 'catalog.digital.readReserved' })}</span>;
    }
    return <span className="ab-online-badge ab-online-badge--reserved" title={t({ id: 'catalog.digital.reservedHint' })}>
      {t({ id: 'catalog.digital.reservedFor' }, { libraries: libs })}</span>;
  }

  function copiesExpander(book) {
    const open = expandedCopies.has(book.book_id);
    return (
      <button type="button" className="ab-expander" aria-expanded={open}
        title={t({ id: open ? 'catalog.works.hideCopies' : 'catalog.works.showCopies' })}
        aria-label={t({ id: open ? 'catalog.works.hideCopies' : 'catalog.works.showCopies' })}
        onClick={() => toggleCopies(book.book_id)}>{open ? '−' : '+'}</button>
    );
  }

  function renderWorkRow(w, idx) {
    const eds = Array.isArray(w.editions) ? w.editions : [];
    const rep = eds.find(e => e.book_id === w.rep_book_id) || eds[0] || {};
    const isOpen = expandedWorks.has(w.key);
    const href = w.work_id ? `/obra/${w.work_id}` : `/livro/${rep.book_id}`;
    const icon = TIPO_ICONS[rep.tipo_material] || '';
    const libNames = orderLibraryNames((w.library_names || []).map(String), libPriority)
      .map(nm => (cityByLib[nm] ? `${nm} (${cityByLib[nm]})` : nm));
    const publishers = [...new Set(eds.map(e => e.publisher_display || e.editora).filter(Boolean))];
    const langs = [...new Set(eds.map(e => e.idioma).filter(Boolean))].map(c => languageLabel(c, t) || c);
    const best = eds.map(e => getStatusInfo(e, isAuth, t))
      .sort((a, b) => (STATUS_RANK[a.cls] ?? 9) - (STATUS_RANK[b.cls] ?? 9))[0] || { label: t({ id: 'catalog.avail.check' }), cls: 'muted' };
    return (
      <tr key={`w-${w.key}-${idx}`} className="ab-row--work" data-depth={1}>
        <td data-label={t({ id: 'catalog.table.ref' })}>
          <span className="ab-cat-ref-stack">
            <button type="button" className="ab-expander" aria-expanded={isOpen}
              aria-label={t({ id: isOpen ? 'catalog.works.collapse' : 'catalog.works.expand' })}
              title={t({ id: isOpen ? 'catalog.works.collapse' : 'catalog.works.expand' })}
              onClick={() => toggleWork(w.key)}>{isOpen ? '−' : '+'}</button>
            <span>
              {Number(w.volume_count) >= 2 && Number(w.volume_count) === eds.length
                ? t({ id: 'catalog.works.volumesCount' }, { count: w.volume_count })
                : t({ id: 'catalog.works.editionsCount' }, { count: w.edition_count || eds.length })}
            </span>
          </span>
        </td>
        <td data-label={t({ id: 'catalog.table.author' })}><AuthorLinks book={rep} /></td>
        <td data-label={t({ id: 'catalog.table.bookTitle' })}>
          <div className="ab-cat-title">
            <Link to={href} className="ab-cat-thumb" tabIndex={-1} aria-hidden="true">
              {rep.cover_object_path
                ? <img src={coverThumbUrl(rep.cover_object_path)} alt="" loading="lazy" decoding="async" width="30" height="42" onError={(e) => handleThumbError(e, rep.cover_object_path)} />
                : <span className="ab-cat-thumb__ph">{icon || '📖'}</span>}
            </Link>
            <span className="ab-cat-title__text">
              <Link to={href} className="ab-work-title">{w.display_title || rep.titulo}</Link>
              {badgeNumerique(eds.map((e) => e.book_id))}
              {langs.length > 0 && <div className="ab-work-meta">{langs.join(' · ')}</div>}
            </span>
          </div>
        </td>
        <td data-label={t({ id: 'catalog.table.year' })}>{yearsLabel(w.year_min, w.year_max)}</td>
        <td data-label={t({ id: 'catalog.table.publisher' })}>
          {publishers.length === 1 ? publishers[0] : publishers.length > 1 ? t({ id: 'catalog.works.publishers' }, { count: publishers.length }) : '—'}
        </td>
        <td data-label={t({ id: 'catalog.table.libraries' })}><LibraryCell names={libNames} t={t} /></td>
        <td data-label={t({ id: 'catalog.table.availability' })}><span className={`ab-status-dot ab-status-dot--${best.cls}`}>{best.label}</span></td>
        {isAuth && <td className="ab-table__actions-cell" />}
      </tr>
    );
  }

  // Disponibilité d'une bibliothèque pour cette édition. Doctrine A1/A2/A3 :
  // l'anon ne voit que « à vérifier » ; la lectrice voit sa bibliothèque par
  // l'indice de session. Pour les AUTRES bibliothèques, le « pour vous » de
  // l'édition prime (Xavier, 04/09) : un exemplaire libre à MLEG n'est pas
  // disponible pour une lectrice de BTL, la ligne ne doit pas dire le contraire.
  // Il n'y a pas de prêt entre bibliothèques : dès que la lectrice a une
  // bibliothèque de session, l'exemplaire d'une AUTRE bibliothèque n'est pas
  // pour elle — que la sienne détienne l'édition ou non. Le 06/10, un lecteur
  // de BLMF lisait « Disponible (1) » sur la ligne BTL d'une édition que BLMF
  // détient aussi : la règle ne visait que le cas « indisponible pour toi ».
  // Sans bibliothèque de session, les lignes restent informatives.
  function copyStatus(l, book) {
    if (!isAuth) return { label: t({ id: 'catalog.avail.check' }), cls: 'muted' };
    if (l.is_session_library && l.session_status_hint) {
      return getStatusInfo({ session_status_hint: l.session_status_hint, session_available_count: l.session_available_count, loanable: l.loanable }, isAuth, t);
    }
    const editionHint = (book?.session_status_hint || '').toLowerCase();
    if (!l.is_session_library && editionHint && editionHint !== 'sem_biblioteca_de_sessao') {
      return { label: t({ id: 'catalog.avail.unavailUser' }), cls: 'bad' };
    }
    if (l.loanable === false) return { label: t({ id: 'catalog.avail.consult' }), cls: 'warn' };
    if (Number(l.available_count) > 0) return { label: t({ id: 'catalog.avail.availableCount' }, { count: Number(l.available_count) }), cls: 'ok' };
    if (l.available_count == null) return { label: t({ id: 'catalog.avail.check' }), cls: 'muted' };
    return { label: t({ id: 'catalog.works.unavailableNow' }), cls: 'bad' };
  }

  function renderCopiesRow(book, idx, depth = 2) {
    const st = copiesByBook[book.book_id] || { loading: true, libraries: [] };
    const libs = st.libraries || [];
    return (
      <tr key={`c-${book.book_id}-${idx}`} className="ab-row--copies" data-depth={depth}>
        <td colSpan={isAuth ? 8 : 7}>
          <div className="ab-copies" role="region" aria-label={t({ id: 'catalog.works.showCopies' })}>
            {st.loading ? (
              <span className="ab-copies__muted">{t({ id: 'catalog.works.copiesLoading' })}</span>
            ) : libs.length === 0 ? (
              <span className="ab-copies__muted">{t({ id: 'catalog.works.copiesNone' })}</span>
            ) : libs.map(l => {
              const s = copyStatus(l, book);
              return (
                <div className="ab-copies__row" key={l.library_slug || l.library_name}>
                  <span className="ab-copies__lib">{l.short_name || l.library_name}{l.city ? ` (${l.city})` : ''}</span>
                  {l.is_session_library && <span className="ab-copies__mine">{t({ id: 'catalog.works.yourLibrary' })}</span>}
                  <span>{t({ id: 'catalog.works.copiesCount' }, { count: Number(l.exemplares_total) || 0 })}</span>
                  <span className={`ab-status-dot ab-status-dot--${s.cls}`}>{s.label}</span>
                  {l.local_bib_ref && <span className="ab-copies__muted">{l.local_bib_ref}</span>}
                </div>
              );
            })}
          </div>
        </td>
      </tr>
    );
  }

  return (
    <>
      {/* ══ TABLE ═════════════════════════════════════════════ */}
      {loading ? (
        <div className="ab-catalog-loading" role="status" aria-live="polite">
          <div className="ab-catalog-loading__message">
            <Spinner size={20} />
            <span>{t({ id: 'catalog.loading.message' })}</span>
          </div>
          <div className="ab-catalog-loading__skeleton" aria-hidden="true">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="ab-catalog-loading__row">
                <span className="ab-catalog-loading__cell ab-catalog-loading__cell--ref" />
                <span className="ab-catalog-loading__cell ab-catalog-loading__cell--title" />
                <span className="ab-catalog-loading__cell ab-catalog-loading__cell--author" />
                <span className="ab-catalog-loading__cell ab-catalog-loading__cell--year" />
              </div>
            ))}
          </div>
        </div>
      ) : books.length === 0 ? (
        <EmptyState message={t({ id: 'catalog.results.empty' })} />
      ) : (
        <div className="ab-sheet">
          <div className="ab-sheet__head">
            <div>
              <span className="ab-sheet__title">{t({ id: 'catalog.table.title' })}</span>
              <span className="ab-sheet__hint">{t({ id: 'catalog.table.sortHint' })}</span>
            </div>
            <div className="ab-table-jump">
              <button onClick={() => scrollTable('top')} title={t({ id: 'catalog.table.jumpTop' })}>↑</button>
              <button onClick={() => scrollTable('bottom')} title={t({ id: 'catalog.table.jumpBottom' })}>↓</button>
            </div>
          </div>
          <div className="ab-table-wrap" ref={tableRef}>
            <table className={`ab-table ab-table--cards ${compact ? 'ab-table--compact' : ''}`}>
              <thead>
                <tr>
                  <th onClick={() => handleHeaderSort('bib_ref')}>{t({ id: 'catalog.table.ref' })}{si('bib_ref')}</th>
                  <th onClick={() => handleHeaderSort('autor')}>{t({ id: 'catalog.table.author' })}{si('autor')}</th>
                  <th onClick={() => handleHeaderSort('titulo')}>{t({ id: 'catalog.table.bookTitle' })}{si('titulo')}</th>
                  <th onClick={() => handleHeaderSort('ano')}>{t({ id: 'catalog.table.year' })}{si('ano')}</th>
                  <th onClick={() => handleHeaderSort('editora')}>{t({ id: 'catalog.table.publisher' })}{si('editora')}</th>
                  <th>{t({ id: 'catalog.table.libraries' })}</th>
                  <th>{t({ id: 'catalog.table.availability' })}</th>
                  {isAuth && (
                    <th className="ab-table__actions-col">{t({ id: 'catalog.table.actions' })}</th>
                  )}
                </tr>
              </thead>
              <tbody>
                {tableRows.map((row, idx) => {
                  if (row.type === 'work') return renderWorkRow(row.w, idx);
                  if (row.type === 'copies') return renderCopiesRow(row.book, idx, row.depth);
                  const book = row.book;
                  const status = getStatusInfo(book, isAuth, t);
                  const icon = TIPO_ICONS[book.tipo_material] || '';
                  const libNames = orderLibraryNames(libraryNameList(book), libPriority)
                    .map(nm => (cityByLib[nm] ? `${nm} (${cityByLib[nm]})` : nm));
                  return (
                    <tr key={`${book.book_id}-${book.library_slug}-${idx}`} className={row.indent ? 'ab-row--edition' : undefined} data-depth={row.depth || 1}>
                      <td data-label={t({ id: 'catalog.table.ref' })}>
                        <span className="ab-cat-ref-stack">
                          {copiesExpander(book)}
                          <Link to={`/livro/${book.book_id}`}>{book.bib_ref || '—'}</Link>
                        </span>
                      </td>
                      <td data-label={t({ id: 'catalog.table.author' })}><AuthorLinks book={book} /></td>
                      <td data-label={t({ id: 'catalog.table.bookTitle' })}>
                        <div className="ab-cat-title">
                          <Link to={`/livro/${book.book_id}`} className="ab-cat-thumb" tabIndex={-1} aria-hidden="true">
                            {book.cover_object_path
                              ? <img src={coverThumbUrl(book.cover_object_path)} alt="" loading="lazy" decoding="async" width="30" height="42" onError={(e) => handleThumbError(e, book.cover_object_path)} />
                              : <span className="ab-cat-thumb__ph">{icon || '📖'}</span>}
                          </Link>
                          <span className="ab-cat-title__text">
                            <Link to={`/livro/${book.book_id}`}>
                              {book.volume && <span className="ab-volume-badge">{t({ id: 'catalog.works.volumeLabel' }, { n: book.volume })}</span>}
                              {book.titulo}
                              {book.subtitulo && <span className="ab-subtitulo"> — {book.subtitulo}</span>}
                            </Link>
                            {badgeNumerique([book.book_id])}
                          </span>
                        </div>
                      </td>
                      <td data-label={t({ id: 'catalog.table.year' })}>{book.ano || '—'}</td>
                      <td data-label={t({ id: 'catalog.table.publisher' })}>
                        {book.publisher_display ? (<>
                          {book.tipo_material === 'audiovisual' && <span title={t({ id: 'catalogacao.field.distribuidora' })}>🎬 </span>}
                          {book.tipo_material === 'audio' && <span title={t({ id: 'catalogacao.field.gravadora' })}>💿 </span>}
                          {book.publisher_display}
                        </>) : '—'}
                      </td>
                      <td data-label={t({ id: 'catalog.table.libraries' })}>
                        <LibraryCell names={libNames} t={t} />
                      </td>
                      <td data-label={t({ id: 'catalog.table.availability' })}><span className={`ab-status-dot ab-status-dot--${status.cls}`}>{status.label}</span></td>
                      {isAuth && (
                        <td className="ab-table__actions-cell">
                          {(() => {
                            // Bouton visible uniquement si :
                            //  - garde-fous globaux OK (service mode, non restreint)
                            //  - statut du livre = 'ok' (= disponible dans MA biblio, count > 0)
                            //  - livre prêtable (sinon c'est consultation, autre flux)
                            if (!quickReserveAvailable) return null;
                            if (status.cls !== 'ok') return null;
                            if (book.session_loanable === false) return null;

                            const key = String(book.book_id || book.bib_ref || '');
                            const refLow = String(book.bib_ref || '').trim().toLowerCase();
                            const localDone = reservedBibRefs.has(refLow);
                            const st = reserveState[key] || (localDone ? 'done' : 'idle');

                            if (st === 'done') {
                              return (
                                <span className="ab-quick-reserve ab-quick-reserve--done" title={t({ id: 'catalog.quickReserve.doneHint' })}>
                                  ✓ {t({ id: 'catalog.quickReserve.done' })}
                                </span>
                              );
                            }
                            if (st === 'reserving') {
                              return (
                                <button className="ab-quick-reserve ab-quick-reserve--loading" disabled>
                                  <Spinner size="sm" /> {t({ id: 'catalog.quickReserve.loading' })}
                                </button>
                              );
                            }
                            if (typeof st === 'string' && st.startsWith('error:')) {
                              const msg = st.slice(6);
                              return (
                                <div className="ab-quick-reserve-error">
                                  <span className="ab-quick-reserve-error__msg" title={msg}>{msg}</span>
                                  <button
                                    type="button"
                                    className="ab-quick-reserve ab-quick-reserve--retry"
                                    onClick={() => handleQuickReserve(book)}
                                  >
                                    {t({ id: 'catalog.quickReserve.retry' })}
                                  </button>
                                </div>
                              );
                            }
                            return (
                              <button
                                type="button"
                                className="ab-quick-reserve"
                                onClick={() => handleQuickReserve(book)}
                                title={t({ id: 'catalog.quickReserve.hint' })}
                              >
                                {t({ id: 'catalog.quickReserve.label' })}
                              </button>
                            );
                          })()}
                          {/* Bouton "Agendar consulta" (#consulta-loanable,
                              24/05/2026). Tout ouvrage en circulation est
                              consultable, qu'il soit empruntable ou non, et
                              que ses exemplaires soient ou non disponibles a
                              l'emprunt. quickConsultaAvailable porte deja la
                              garde de service (pausada -> non). La
                              disponibilite reelle d'un exemplaire est tranchee
                              cote base (fn_v2_resolve_consulta_exemplar,
                              #MODEL-item-grain). */}
                          {(() => {
                            if (!quickConsultaAvailable) return null;
                            // Bug fix 30/05/2026 — garde par livre manquante.
                            // Sans ce check, le bouton apparaissait sur les
                            // livres hors périmètre lecteur (typique BTL vu
                            // depuis compte BLMF, hint=indisponivel_para_voce,
                            // status.cls='bad'). Le backend bloque déjà côté
                            // RPC mais montrer le bouton est trompeur.
                            if (status.cls === 'bad') return null;

                            const key = String(book.book_id || book.bib_ref || '');
                            const refLow = String(book.bib_ref || '').trim().toLowerCase();
                            const localDone = consultedBibRefs.has(refLow);
                            const st = consultaState[key] || (localDone ? 'done' : 'idle');

                            if (st === 'done') {
                              return (
                                <span className="ab-quick-reserve ab-quick-reserve--done" title={t({ id: 'catalog.quickConsulta.doneHint' })}>
                                  ✓ {t({ id: 'catalog.quickConsulta.done' })}
                                </span>
                              );
                            }
                            if (st === 'reserving') {
                              return (
                                <button className="ab-quick-reserve ab-quick-reserve--loading" disabled>
                                  <Spinner size="sm" /> {t({ id: 'catalog.quickConsulta.loading' })}
                                </button>
                              );
                            }
                            if (typeof st === 'string' && st.startsWith('error:')) {
                              const msg = st.slice(6);
                              return (
                                <div className="ab-quick-reserve-error">
                                  <span className="ab-quick-reserve-error__msg" title={msg}>{msg}</span>
                                  <button
                                    type="button"
                                    className="ab-quick-reserve ab-quick-reserve--retry"
                                    onClick={() => handleQuickConsulta(book)}
                                  >
                                    {t({ id: 'catalog.quickReserve.retry' })}
                                  </button>
                                </div>
                              );
                            }
                            return (
                              <button
                                type="button"
                                className="ab-quick-reserve"
                                onClick={() => handleQuickConsulta(book)}
                                title={t({ id: 'catalog.quickConsulta.hint' })}
                              >
                                {t({ id: 'catalog.quickConsulta.label' })}
                              </button>
                            );
                          })()}
                          {/* #OPAC9 — Favoritar */}
                          {(() => {
                            const bid = book.book_id || book.id;
                            if (wishlistedIds.has(bid)) {
                              return (
                                <span className="ab-quick-reserve ab-quick-reserve--done" title={t({ id: 'catalog.wishlist.saved' })}>
                                  ★ {t({ id: 'catalog.wishlist.saved' })}
                                </span>
                              );
                            }
                            return (
                              <button
                                type="button"
                                className="ab-quick-reserve ab-wishlist-btn"
                                disabled={wishlistBusy === bid}
                                onClick={() => handleWishlist(book)}
                                title={t({ id: 'catalog.wishlist.add' })}
                              >
                                ☆ {t({ id: 'catalog.wishlist.add' })}
                              </button>
                            );
                          })()}
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Charger plus */}
      {hasMore && !loading && (
        <div className="ab-load-more">
          <Button variant="secondary" onClick={() => fetchBooks(totalFetched, true)} loading={loadingMore}>
            {t({ id: 'catalog.actions.loadMore' }, { loaded: totalFetched, total: totalCount ?? '…' })}
          </Button>
        </div>
      )}
    </>
  );
}
