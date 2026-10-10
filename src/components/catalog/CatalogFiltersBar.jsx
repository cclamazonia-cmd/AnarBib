// src/components/catalog/CatalogFiltersBar.jsx — E6, Catalogue public, lot 3 (10/10/2026)
// La section « Filtres » de la page du catalogue, sortie telle quelle : elle reçoit en un seul sac
// de props les valeurs et les gestes de la page qu'elle touchait (liste engendrée par analyse des
// variables libres, sans ressaisie du rendu). La page garde l'état ; la barre ne fait que l'afficher
// et appeler ses gestes.
import { useIntl } from 'react-intl';
import { localizedSubjectLabel } from '@/lib/catalogOpac';

export default function CatalogFiltersBar(p) {
  const { formatMessage: t, locale } = useIntl();
  const {
    LANGUAGE_OPTIONS,
    SORT_OPTIONS,
    advancedOpen,
    alphaFilter,
    authorFilter,
    availabilityFilter,
    availabilityOptions,
    catalogNetworks,
    cddFilter,
    clearFilters,
    collapseEditions,
    collectionFilter,
    compact,
    copySearchLink,
    dAuthor,
    dCdd,
    dCollection,
    dIsbn,
    dLanguage,
    dPlace,
    dPublisher,
    dSearch,
    dSubjects,
    dYear,
    emailSearchLink,
    filtersActiveCount,
    filtersOpen,
    hasActiveFilters,
    horsReseau,
    isbnFilter,
    languageFilter,
    libMenuOpen,
    libMenuRef,
    libraryFilter,
    libraryOptions,
    libsDesReseaux,
    materialFilter,
    netMenuOpen,
    netMenuRef,
    pickSubject,
    placeFilter,
    publisherFilter,
    relatedSubjects,
    reseauxActifs,
    search,
    setAdvancedOpen,
    setAlphaFilter,
    setAuthorFilter,
    setAuthorIdFilter,
    setAvailabilityFilter,
    setCddFilter,
    setCollapseEditions,
    setCollectionFilter,
    setCompact,
    setFiltersOpen,
    setIsbnFilter,
    setLanguageFilter,
    setLibMenuOpen,
    setLibraryFilter,
    setMaterialFilter,
    setNetMenuOpen,
    setNetworkFilter,
    setPlaceFilter,
    setPublisherFilter,
    setSearch,
    setSortValue,
    setSubjectFilter,
    setSubjectsFilter,
    setYearFilter,
    sortValue,
    subjectFilter,
    subjectLabel,
    subjectsFilter,
    yearFilter,
  } = p;
  return (
    <>
      {/* ══ FILTRES (escamotable) ════════════════════════════ */}
      <section className={`ab-toolbar${filtersOpen ? '' : ' ab-toolbar--replie'}`}>
        <button type="button" className="ab-collapse-header" onClick={() => setFiltersOpen(o => !o)} aria-expanded={filtersOpen}>
          {t({ id: 'catalog.section.filters' })}
          {!filtersOpen && filtersActiveCount > 0 && (
            <span className="ab-collapse-badge" title={t({ id: 'catalog.section.exploreActive' }, { count: filtersActiveCount })}>
              <span aria-hidden="true">{filtersActiveCount}</span>
              <span className="ab-sr-only">{t({ id: 'catalog.section.exploreActive' }, { count: filtersActiveCount })}</span>
            </span>
          )}
          {' '}<span className="ab-collapse-chevron" aria-hidden="true">{filtersOpen ? '▾' : '▸'}</span>
        </button>
        {filtersOpen && (<>
        <div className="ab-filters-grid">
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.searchLabel' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.searchPlaceholder' })}
              value={search} onChange={e => setSearch(e.target.value)} />
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.author' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.authorPlaceholder' })}
              value={authorFilter} onChange={e => { setAuthorFilter(e.target.value); setAuthorIdFilter(''); setAlphaFilter(''); }} />
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.publisher' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.publisherPlaceholder' })}
              value={publisherFilter} onChange={e => setPublisherFilter(e.target.value)} />
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.year' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.yearPlaceholder' })}
              value={yearFilter} onChange={e => setYearFilter(e.target.value)} />
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.availability' })}</label>
            <select className="ab-select" value={availabilityFilter} onChange={e => setAvailabilityFilter(e.target.value)}>
              {availabilityOptions.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.sortLabel' })}</label>
            <select className="ab-select" value={sortValue} onChange={e => setSortValue(e.target.value)}>
              {SORT_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.libraryLabel' })}</label>
            <div style={{ position: 'relative' }} ref={libMenuRef}>
              <button type="button" className="ab-select" aria-expanded={libMenuOpen}
                style={{ textAlign: 'left', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%', gap: 6, flexWrap: 'wrap' }}
                onClick={() => setLibMenuOpen(o => !o)}>
                <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {libraryFilter.length === 0
                    ? t({ id: 'catalog.avail.all' })
                    : libraryFilter.length === 1
                      ? (libraryOptions.find(o => o.value === libraryFilter[0])?.label || libraryFilter[0])
                      : t({ id: 'catalog.filters.libraryNSelected' }, { n: libraryFilter.length })}
                </span>
                <span aria-hidden="true">▾</span>
              </button>
              {libMenuOpen && (
                <div style={{ position: 'absolute', zIndex: 30, top: '100%', left: 0, right: 0, marginTop: 2, background: 'var(--brand-surface, #1e1e1e)', border: '1px solid rgba(255,255,255,.15)', borderRadius: 8, maxHeight: 240, overflowY: 'auto', padding: 4, boxShadow: '0 8px 24px rgba(0,0,0,.45)' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px', cursor: 'pointer', borderRadius: 6 }}>
                    <input type="checkbox" checked={libraryFilter.length === 0} onChange={() => setLibraryFilter([])} />
                    <span>{t({ id: 'catalog.avail.all' })}</span>
                  </label>
                  {libraryOptions.filter(o => o.value !== '__all__' && (reseauxActifs.length === 0 || libsDesReseaux.has(o.value))).map(o => (
                    <label key={o.value} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px', cursor: 'pointer', borderRadius: 6 }}>
                      <input type="checkbox" checked={libraryFilter.includes(o.value)}
                        onChange={() => setLibraryFilter(prev => prev.includes(o.value) ? prev.filter(v => v !== o.value) : [...prev, o.value])} />
                      <span>{o.label}</span>
                    </label>
                  ))}
                </div>
              )}
            </div>
          </div>
          {catalogNetworks.length > 0 && (
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.networkLabel' })}</label>
            <div style={{ position: 'relative' }} ref={netMenuRef}>
              <button type="button" className="ab-select" aria-expanded={netMenuOpen} aria-haspopup="true"
                style={{ textAlign: 'left', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%', gap: 6, flexWrap: 'wrap' }}
                onClick={() => setNetMenuOpen(o => !o)}>
                <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {reseauxActifs.length === 0
                    ? t({ id: 'catalog.filters.networkAll' })
                    : reseauxActifs.length === 1
                      ? (catalogNetworks.find(n => n.slug === reseauxActifs[0])?.label || reseauxActifs[0])
                      : t({ id: 'catalog.filters.networkNSelected' }, { n: reseauxActifs.length })}
                </span>
                <span aria-hidden="true">▾</span>
              </button>
              {netMenuOpen && (
                <div style={{ position: 'absolute', zIndex: 30, top: '100%', left: 0, right: 0, marginTop: 2, background: 'var(--brand-surface, #1e1e1e)', border: '1px solid rgba(255,255,255,.15)', borderRadius: 8, maxHeight: 280, overflowY: 'auto', padding: 4, boxShadow: '0 8px 24px rgba(0,0,0,.45)' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px', cursor: 'pointer', borderRadius: 6 }}>
                    <input type="checkbox" checked={reseauxActifs.length === 0} onChange={() => setNetworkFilter([])} />
                    <span>{t({ id: 'catalog.filters.networkAll' })}</span>
                  </label>
                  {catalogNetworks.map(n => (
                    <label key={n.slug} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px', cursor: 'pointer', borderRadius: 6 }}>
                      <input type="checkbox" checked={reseauxActifs.includes(n.slug)}
                        onChange={() => setNetworkFilter(prev => prev.includes(n.slug) ? prev.filter(v => v !== n.slug) : [...prev.filter(v => catalogNetworks.some(c => c.slug === v)), n.slug])} />
                      <span>{n.label} <small style={{ color: 'var(--brand-muted)' }}>({(n.libraries || []).map(l => l.short_name || l.name || l.slug).join(', ')})</small></span>
                    </label>
                  ))}
                  {horsReseau.length > 0 && (
                    <p style={{ margin: '6px 8px 4px', fontSize: '.78rem', color: 'var(--brand-muted)' }}>
                      {t({ id: 'catalog.filters.networkOutside' }, { names: horsReseau.join(', ') })}
                    </p>
                  )}
                </div>
              )}
            </div>
          </div>
          )}
          <div className="ab-field ab-field--action">
            <label className="ab-field__label">{t({ id: 'catalog.filters.clearAll' })}</label>
            <button className="ab-button ab-button--secondary" onClick={clearFilters} style={{ borderColor: 'var(--brand-action, #b32025)', color: 'var(--brand-action, #b32025)', fontWeight: 700 }}>↺ {t({ id: 'catalog.filters.clearButton' })}</button>
          </div>
        </div>

        {/* ── Advanced search toggle ──────────────────── */}
        <button
          className="ab-button ab-button--secondary"
          style={{ margin: '8px 0 0', fontSize: '.78rem', padding: '4px 14px' }}
          onClick={() => setAdvancedOpen(p => !p)}
        >
          {t({ id: 'catalog.advancedSearch.toggle' })} {advancedOpen ? '▲' : '▼'}
        </button>

        {/* ── Advanced search fields ─────────────────── */}
        {advancedOpen && (
          <div className="ab-filters-grid" style={{ marginTop: 8 }}>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.isbn' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.isbnPh' })}
                value={isbnFilter} onChange={e => setIsbnFilter(e.target.value)} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.language' })}</label>
              {/* CONV-7 : depuis la normalisation, `idioma` porte un code BCP-47.
                  Un champ texte libre n'y repond plus — taper « Portugues » rendait
                  zero resultat. Le selecteur envoie le code, l'ecran montre le
                  libelle localise (DOC-CONV-1 : une verite, plusieurs rendus). */}
              <select className="ab-input" value={languageFilter}
                onChange={e => setLanguageFilter(e.target.value)}>
                <option value="">{t({ id: 'catalog.filters.languagePh' })}</option>
                {LANGUAGE_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.cdd' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.cddPh' })}
                value={cddFilter} onChange={e => setCddFilter(e.target.value)} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.subjects' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.subjectsPh' })}
                value={subjectsFilter} onChange={e => setSubjectsFilter(e.target.value)} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.material' })}</label>
              <select className="ab-select" value={materialFilter} onChange={e => setMaterialFilter(e.target.value)}>
                <option value="__all__">{t({ id: 'catalog.filters.materialAll' })}</option>
                {['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine'].map(mt => (
                  <option key={mt} value={mt}>{t({ id: `catalogacao.material.${mt}` })}</option>
                ))}
              </select>
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.collection' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.collectionPh' })}
                value={collectionFilter} onChange={e => setCollectionFilter(e.target.value)} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.place' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.placePh' })}
                value={placeFilter} onChange={e => setPlaceFilter(e.target.value)} />
            </div>
          </div>
        )}
        </>)}

        {/* Chips + view controls */}
        <div className="ab-toolbar-meta">
          {hasActiveFilters && (
            <div className="ab-active-filters">
              {dSearch && <span className="ab-filter-chip">{t({ id: 'catalog.chip.search' })}: <strong>{dSearch}</strong> <button onClick={() => setSearch('')}>✕</button></span>}
              {dAuthor && <span className="ab-filter-chip">{t({ id: 'catalog.chip.author' })}: <strong>{dAuthor}</strong> <button onClick={() => { setAuthorFilter(''); setAuthorIdFilter(''); }}>✕</button></span>}
              {alphaFilter && <span className="ab-filter-chip">{t({ id: 'catalog.browse.alpha' })}: <strong>{alphaFilter}</strong> <button onClick={() => setAlphaFilter('')}>✕</button></span>}
              {subjectFilter && <span className="ab-filter-chip">{t({ id: 'book.meta.subjects' })}: <strong>{subjectLabel || subjectFilter}</strong> <button onClick={() => setSubjectFilter('')}>✕</button></span>}
              {dPublisher && <span className="ab-filter-chip">{t({ id: 'catalog.chip.publisher' })}: <strong>{dPublisher}</strong> <button onClick={() => setPublisherFilter('')}>✕</button></span>}
              {dYear && <span className="ab-filter-chip">{t({ id: 'catalog.chip.year' })}: <strong>{dYear}</strong> <button onClick={() => setYearFilter('')}>✕</button></span>}
              {availabilityFilter !== '__all__' && <span className="ab-filter-chip">{t({ id: 'catalog.chip.avail' })}: <strong>{availabilityOptions.find(o => o.value === availabilityFilter)?.label}</strong> <button onClick={() => setAvailabilityFilter('__all__')}>✕</button></span>}
              {reseauxActifs.map(slug => <span key={`net-${slug}`} className="ab-filter-chip">{t({ id: 'catalog.chip.network' })}: <strong>{catalogNetworks.find(n => n.slug === slug)?.label || slug}</strong> <button onClick={() => setNetworkFilter(prev => prev.filter(v => v !== slug))}>✕</button></span>)}
              {libraryFilter.map(slug => <span key={slug} className="ab-filter-chip">{t({ id: 'catalog.chip.library' })}: <strong>{libraryOptions.find(o => o.value === slug)?.label || slug}</strong> <button onClick={() => setLibraryFilter(prev => prev.filter(v => v !== slug))}>✕</button></span>)}
              {dIsbn && <span className="ab-filter-chip">{t({ id: 'catalog.chip.isbn' })}: <strong>{dIsbn}</strong> <button onClick={() => setIsbnFilter('')}>✕</button></span>}
              {dLanguage && <span className="ab-filter-chip">{t({ id: 'catalog.chip.language' })}: <strong>{dLanguage}</strong> <button onClick={() => setLanguageFilter('')}>✕</button></span>}
              {dCdd && <span className="ab-filter-chip">{t({ id: 'catalog.chip.cdd' })}: <strong>{dCdd}</strong> <button onClick={() => setCddFilter('')}>✕</button></span>}
              {dSubjects && <span className="ab-filter-chip">{t({ id: 'catalog.chip.subjects' })}: <strong>{dSubjects}</strong> <button onClick={() => setSubjectsFilter('')}>✕</button></span>}
              {materialFilter !== '__all__' && <span className="ab-filter-chip">{t({ id: 'catalog.chip.material' })}: <strong>{t({ id: `catalogacao.material.${materialFilter}` })}</strong> <button onClick={() => setMaterialFilter('__all__')}>✕</button></span>}
              {dCollection && <span className="ab-filter-chip">{t({ id: 'catalog.chip.collection' })}: <strong>{dCollection}</strong> <button onClick={() => setCollectionFilter('')}>✕</button></span>}
              {dPlace && <span className="ab-filter-chip">{t({ id: 'catalog.chip.place' })}: <strong>{dPlace}</strong> <button onClick={() => setPlaceFilter('')}>✕</button></span>}
            </div>
          )}
          {subjectFilter && relatedSubjects.length > 0 && (
            <div className="ab-related-subjects">
              <span className="ab-related-subjects__label">{t({ id: 'catalog.related.subjects' })}</span>
              {relatedSubjects.map((r) => (
                <button key={r.id} type="button" className="ab-facet-chip"
                  onClick={() => pickSubject({ slug: r.slug, label_i18n: r.label_i18n })}>
                  {localizedSubjectLabel(r.label_i18n, locale)}
                </button>
              ))}
            </div>
          )}
          <div className="ab-view-controls">
            <button className="ab-mini-action" onClick={copySearchLink}>{t({ id: 'catalog.actions.copyLink' })}</button>
            <button className="ab-mini-action" onClick={emailSearchLink}>{t({ id: 'catalog.actions.emailLink' })}</button>
            <button className="ab-mini-action" onClick={() => setCompact(!compact)} aria-pressed={compact}>
              {compact ? t({ id: 'catalog.actions.compactOn' }) : t({ id: 'catalog.actions.compactOff' })}
            </button>
            <button className="ab-mini-action" onClick={() => setCollapseEditions(v => !v)} aria-pressed={collapseEditions}
              title={t({ id: 'catalog.works.groupedHint' })}>
              {collapseEditions ? t({ id: 'catalog.works.flatList' }) : t({ id: 'catalog.collapseEditions' })}
            </button>
          </div>
        </div>
      </section>
    </>
  );
}
