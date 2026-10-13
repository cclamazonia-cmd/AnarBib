// src/pages/catalogacao/LookupPanel.jsx — E6, lot 3 (28/09/2026)
// Le panneau de recherche catalographique du formulaire de notice, sorti de
// BookDraftForm.jsx sans en changer une ligne de logique : recherche par
// ISBN/ISSN/titre+auteur dans les sources (BNE, BnF, DNB, ICCU, LoC, Open
// Library, Wikidata, DBNL, BN Brasil), lecture du code-barres, liens manuels
// (recherche manuelle dans le catalogue choisi parmi ces sources — liste
// déroulante, 13/10/2026 —, WorldCat, portail ISSN) et liste des candidates — BN Brasil comprise : son
// ancien bouton « Chercher à la Bibliothèque Nationale (ISBN) » refaisait la
// requête que la recherche lance déjà avec un ISBN, il est retiré le 13/10/2026.
// Le panneau ne touche jamais au formulaire lui-même : l'ISBN lu et la
// candidate retenue remontent au parent par deux rappels, qui reste seul à
// écrire les champs, les contributeurs et l'état du brouillon.
import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { normalizeBnToCandidate } from '@/lib/catalogacao/bookDraft';
import CardScanner from '@/pages/painel/tabs/CardScanner';
import { CATALOGUES_MANUELS, CATALOGUE_MANUEL_DEFAUT, CLE_CATALOGUE_MANUEL, catalogueManuel, adresseRechercheManuelle } from '@/lib/catalogacao/rechercheManuelle';

export default function LookupPanel({ f, draftId, setMsg, onIsbnScanned, onApplyCandidate }) {
  const { formatMessage: t } = useIntl();
  // ── Lookup state ───────────────────────────────────────
  const [lookupLoading, setLookupLoading] = useState(false);
  const [isbnScanning, setIsbnScanning] = useState(false);
  const [lookupResult, setLookupResult] = useState(null); // { candidates, sources, summary }
  const [selectedCandidate, setSelectedCandidate] = useState(0);
  // ── Recherche manuelle : le catalogue choisi, retenu par navigateur ──
  const [catalogueManuelId, setCatalogueManuelId] = useState(() => {
    try { return catalogueManuel(localStorage.getItem(CLE_CATALOGUE_MANUEL)).id; } catch { return CATALOGUE_MANUEL_DEFAUT; }
  });
  function choisirCatalogueManuel(id) {
    setCatalogueManuelId(id);
    try { localStorage.setItem(CLE_CATALOGUE_MANUEL, id); } catch { /* stockage indisponible : le choix vaut pour la session */ }
  }
  // Le brouillon change (fiche vierge, autre brouillon chargé) : les résultats
  // affichés concernaient l'autre notice, ils se referment. Avant l'extraction,
  // seule la fiche vierge le faisait (resetForm) ; un brouillon chargé par-dessus
  // gardait les candidates de la notice précédente.
  useEffect(() => { setLookupResult(null); setSelectedCandidate(0); }, [draftId]);

  // ═══════════════════════════════════════════════════════
  // Catalog lookup (ISBN/ISSN/title+author → BNE, BnF, DNB, ICCU, LoC, OL, Wikidata, DBNL + BN Brasil)
  // ═══════════════════════════════════════════════════════


  // Scan ISBN (MOBILE P2b) : le code-barres lu remplit le champ + lance le lookup.
  function handleIsbnScanned(code) {
    const clean = (code || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    setIsbnScanning(false);
    if (!clean) return;
    onIsbnScanned(clean);
    runCatalogLookup({ isbn: clean });
  }

  async function runCatalogLookup(opts) {
    const scannedIsbn = opts && typeof opts.isbn === 'string' ? opts.isbn : null;
    const isbn = ((scannedIsbn ?? f('isbn')) || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    const issn = (f('issn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    const title = f('titulo').trim();
    const author = f('autor').trim();

    if (!isbn && !issn && !title) {
      setMsg({ text: t({id:'catalogacao.msg.needIsbnOrTitle'}), kind: 'error' });
      return;
    }

    setLookupLoading(true);
    setLookupResult(null);
    setSelectedCandidate(0);
    setMsg({ text: t({id:'catalogacao.msg.searchingSources'}), kind: 'info' });

    try {
      const promises = [
        supabase.functions.invoke('catalog_metadata_lookup', {
          body: { isbn: isbn || null, issn: issn || null, title: title || null, author: author || null, maximumRecords: 8, includeDebug: false },
        }),
      ];
      if (isbn) {
        promises.push(supabase.functions.invoke('bn_isbn_lookup', { body: { isbn } }));
      }

      const settled = await Promise.allSettled(promises);

      const catalogSettled = settled[0];
      let data;
      if (catalogSettled.status === 'fulfilled') {
        const { data: d, error: e } = catalogSettled.value;
        if (e && !d) throw e;
        if (!d?.ok) throw new Error(d?.error || t({id:'catalogacao.msg.lookupFailed'}));
        data = d;
      } else {
        throw catalogSettled.reason;
      }

      if (isbn && settled[1]) {
        const bnSettled = settled[1];
        const startMs = Date.now();
        if (bnSettled.status === 'fulfilled') {
          const bnData = bnSettled.value?.data;
          if (bnData?.ok && bnData.results?.length) {
            const bnCandidates = bnData.results.map(item => normalizeBnToCandidate(item, isbn));
            data.sources = [...(data.sources || []), { id: 'bn_brasil', label: 'BN Brasil', status: 'ok', count: bnCandidates.length, durationMs: Date.now() - startMs }];
            data.candidates = [...(data.candidates || []), ...bnCandidates].sort((a, b) => (b.confidence || 0) - (a.confidence || 0));
            data.total = data.candidates.length;
          } else {
            data.sources = [...(data.sources || []), { id: 'bn_brasil', label: 'BN Brasil', status: bnData?.ok ? 'empty' : 'error', count: 0, durationMs: Date.now() - startMs }];
          }
        } else {
          data.sources = [...(data.sources || []), { id: 'bn_brasil', label: 'BN Brasil', status: 'error', count: 0, durationMs: 0, error: 'Connection failed' }];
        }
      }

      setLookupResult(data);
      const total = data.total || 0;
      setMsg({
        text: total > 0
          ? t({ id: 'catalogacao.msg.candidatesFound' }, { total })
          : t({ id: 'catalogacao.msg.noCandidatesFound' }),
        kind: total > 0 ? 'ok' : 'info',
      });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.searchError' }, { message: localizeError(err, t, 'catalogacao.msg.connectionFailed') }), kind: 'error' });
    } finally {
      setLookupLoading(false);
    }
  }

  function openManualSearch() {
    window.open(adresseRechercheManuelle(catalogueManuelId, f), '_blank', 'noopener');
    setMsg({ text: t({ id: 'catalogacao.msg.manualSearchOpened' }, { catalogue: catalogueManuel(catalogueManuelId).label }), kind: 'info' });
  }

  function openWorldCat() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '');
    const query = isbn || f('issn') || [f('titulo'), f('autor')].filter(Boolean).join(' ');
    if (!query) {
      setMsg({ text: t({id:'catalogacao.msg.needBasicFields'}), kind: 'error' });
      return;
    }
    window.open(`https://search.worldcat.org/search?q=${encodeURIComponent(query)}`, '_blank', 'noopener');
    setMsg({ text: t({id:'catalogacao.msg.worldcatOpened'}), kind: 'info' });
  }

  function openIssnPortal() {
    const raw = (f('issn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    if (!raw) { setMsg({ text: t({ id: 'catalogacao.msg.needIssn' }), kind: 'error' }); return; }
    const formatted = raw.length === 8 ? `${raw.slice(0, 4)}-${raw.slice(4)}` : raw;
    window.open(`https://portal.issn.org/resource/ISSN/${encodeURIComponent(formatted)}`, '_blank', 'noopener');
    setMsg({ text: t({ id: 'catalogacao.msg.issnPortalOpened' }), kind: 'info' });
  }

  async function applySelectedCandidate() {
    if (!lookupResult?.candidates?.length) return;
    await onApplyCandidate(lookupResult.candidates[selectedCandidate] || lookupResult.candidates[0]);
  }

  function clearLookup() {
    setLookupResult(null);
    setSelectedCandidate(0);
  }

  return (
    <>
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 8 }}>
      <button type="button" className="ab-button ab-button--sm"
        onClick={runCatalogLookup} disabled={lookupLoading}>
        {lookupLoading ? t({id:'catalogacao.ui.searching'}) : t({id:'catalogacao.ui.searchMeta'})}
      </button>
      <button type="button" className="ab-button ab-button--secondary ab-button--sm"
        onClick={() => setIsbnScanning(s => !s)} disabled={lookupLoading}>
        {isbnScanning ? t({id:'card.resolve.scan.close'}) : t({id:'catalogacao.isbn.scan.action'})}
      </button>
      <span style={{ display: 'inline-flex', flexWrap: 'wrap', gap: 4, alignItems: 'stretch', maxWidth: '100%', minWidth: 0 }}>
        <select className="ab-select" value={catalogueManuelId}
          onChange={(e) => choisirCatalogueManuel(e.target.value)}
          aria-label={t({ id: 'catalogacao.ui.manualSearchCatalog' })} title={t({ id: 'catalogacao.ui.manualSearchCatalog' })}
          style={{ width: 'auto', minWidth: 0, maxWidth: '100%', padding: '4px 30px 4px 10px', fontSize: '.82rem', backgroundPosition: 'right 10px center' }}>
          {CATALOGUES_MANUELS.map((c) => <option key={c.id} value={c.id}>{c.label}</option>)}
        </select>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
          onClick={openManualSearch}>{t({ id: 'catalogacao.ui.manualSearch' })}</button>
      </span>
      <button type="button" className="ab-button ab-button--secondary ab-button--sm"
        onClick={openWorldCat}>{t({id:'catalogacao.ui.worldcat'})}</button>
      {f('issn') && (
        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
          onClick={openIssnPortal}>{t({id:'catalogacao.ui.issnPortal'})}</button>
      )}
      {lookupResult && (
        <button type="button" className="ab-button ab-button--ghost ab-button--sm"
          onClick={clearLookup}>{t({ id: 'catalogacao.ui.clearPanel' })}</button>
      )}
    </div>

    {isbnScanning && (
      <CardScanner
        t={t}
        formats={['ean_13', 'ean_8']}
        prompt={t({ id: 'catalogacao.isbn.scan.prompt' })}
        onScan={handleIsbnScanned}
        onClose={() => setIsbnScanning(false)}
      />
    )}

    {/* Lookup sources status */}
    {lookupResult?.sources && (
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 6 }}>
        {lookupResult.sources.map((s, i) => (
          <span key={i} className={`cat-pill ${s.status === 'ok' ? 'ok' : s.status === 'empty' ? 'warn' : 'danger'}`}>
            {s.label}: {s.status === 'ok' ? t({id:'catalogacao.lookup.results'}, {count: s.count}) : s.status === 'empty' ? t({id:'catalogacao.lookup.empty'}) : t({id:'catalogacao.lookup.error'})} ({s.durationMs}ms)
          </span>
        ))}
      </div>
    )}

    {/* Candidate list */}
    {lookupResult?.candidates?.length > 0 && (
      <div style={{ border: '1px solid rgba(255,255,255,.1)', borderRadius: 8, overflow: 'hidden', maxHeight: 260, overflowY: 'auto' }}>
        {lookupResult.candidates.map((c, i) => (
          <div key={i}
            onClick={() => setSelectedCandidate(i)}
            style={{
              padding: '8px 10px', cursor: 'pointer',
              background: i === selectedCandidate ? 'rgba(122,11,20,.25)' : (i % 2 === 0 ? 'rgba(0,0,0,.15)' : 'transparent'),
              borderBottom: '1px solid rgba(255,255,255,.06)',
            }}
          >
            <div style={{ fontSize: '.82rem', fontWeight: 600 }}>{c.title}{c.subtitle ? ` : ${c.subtitle}` : ''}</div>
            <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
              {[
                c.contributors?.[0]?.label || c.responsibility_statement,
                c.publisher,
                c.year,
                c.source?.toUpperCase(),
              ].filter(Boolean).join(' · ')}
              {c.isbn?.[0] && ` · ISBN ${c.isbn[0]}`}
            </div>
            <div style={{ fontSize: '.68rem', color: 'rgba(255,255,255,.4)', marginTop: 2 }}>
              {t({ id: 'catalogacao.ui.confidence' })}: {c.confidence} · {c.match_reasons?.join(', ')}
            </div>
          </div>
        ))}
        <div style={{ padding: '8px 10px', display: 'flex', gap: 6 }}>
          <button type="button" className="ab-button ab-button--sm"
            onClick={applySelectedCandidate}>
            {t({ id: 'catalogacao.ui.applyCandidate' })}
          </button>
        </div>
      </div>
    )}

    {lookupResult && lookupResult.candidates?.length === 0 && (
      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', padding: '8px 0' }}>
        {t({id:'catalogacao.msg.noCandidates'})}
      </div>
    )}

    </>
  );
}
