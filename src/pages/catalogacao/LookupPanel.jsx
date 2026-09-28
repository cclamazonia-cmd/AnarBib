// src/pages/catalogacao/LookupPanel.jsx — E6, lot 3 (28/09/2026)
// Le panneau de recherche catalographique du formulaire de notice, sorti de
// BookDraftForm.jsx sans en changer une ligne de logique : recherche par
// ISBN/ISSN/titre+auteur dans les sources (BNE, BnF, DNB, ICCU, LoC, Open
// Library, Wikidata, BN Brasil), lecture du code-barres, liens manuels (BN,
// WorldCat, portail ISSN), liste des candidates et résultats BN Brasil.
// Le panneau ne touche jamais au formulaire lui-même : l'ISBN lu, la candidate
// ou la notice BN retenue remontent au parent par trois rappels, qui reste
// seul à écrire les champs, les contributeurs et l'état du brouillon.
import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { normalizeBnToCandidate } from '@/lib/catalogacao/bookDraft';
import CardScanner from '@/pages/painel/tabs/CardScanner';

export default function LookupPanel({ f, draftId, setMsg, onIsbnScanned, onApplyCandidate, onApplyBnResult }) {
  const { formatMessage: t } = useIntl();
  // ── Lookup state ───────────────────────────────────────
  const [lookupLoading, setLookupLoading] = useState(false);
  const [isbnScanning, setIsbnScanning] = useState(false);
  const [lookupResult, setLookupResult] = useState(null); // { candidates, sources, summary }
  const [selectedCandidate, setSelectedCandidate] = useState(0);
  // ── BN Brasil state ────────────────────────────────────
  const [bnLoading, setBnLoading] = useState(false);
  const [bnResult, setBnResult] = useState(null);
  // Le brouillon change (fiche vierge, autre brouillon chargé) : les résultats
  // affichés concernaient l'autre notice, ils se referment. Avant l'extraction,
  // seule la fiche vierge le faisait (resetForm) ; un brouillon chargé par-dessus
  // gardait les candidates de la notice précédente.
  useEffect(() => { setLookupResult(null); setSelectedCandidate(0); setBnResult(null); }, [draftId]);

  // ═══════════════════════════════════════════════════════
  // Catalog lookup (ISBN/ISSN/title+author → BNE, BnF, DNB, ICCU, LoC, OL, Wikidata + BN Brasil)
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
    setBnResult(null);
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

  function openBnManual() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '');
    const identifier = isbn || f('issn') || f('titulo') || f('autor');
    const url = identifier
      ? `https://acervo.bn.gov.br/sophia_web/busca/acervo/?q=${encodeURIComponent(identifier)}`
      : 'https://acervo.bn.gov.br/sophia_web/busca/acervo/';
    window.open(url, '_blank', 'noopener');
    setMsg({ text: t({id:'catalogacao.msg.bnOpened'}), kind: 'info' });
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

  // ═══════════════════════════════════════════════════════
  // BN Brasil ISBN lookup (via bn_isbn_lookup edge function)
  // ═══════════════════════════════════════════════════════

  async function runBnIsbnLookup() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    if (!isbn) {
      setMsg({ text: t({ id: 'catalogacao.msg.needIsbnForBn' }), kind: 'error' });
      return;
    }

    setBnLoading(true);
    setBnResult(null);
    setMsg({ text: t({ id: 'catalogacao.msg.bnSearching' }), kind: 'info' });

    try {
      const { data, error } = await supabase.functions.invoke('bn_isbn_lookup', {
        body: { isbn },
      });

      if (error && !data) throw error;
      if (!data?.ok) throw new Error(data?.error || t({ id: 'catalogacao.bn.searchFailed' }));

      setBnResult(data);
      const total = data.total || 0;
      setMsg({
        text: total > 0
          ? t({ id: 'catalogacao.bn.resultsFound' }, { total })
          : t({ id: 'catalogacao.bn.noResults' }),
        kind: total > 0 ? 'ok' : 'info',
      });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.bnError' }, { message: localizeError(err, t, 'catalogacao.msg.connectionFailed') }), kind: 'error' });
    } finally {
      setBnLoading(false);
    }
  }

  function clearBnResult() {
    setBnResult(null);
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
      <button type="button" className="ab-button ab-button--secondary ab-button--sm"
        onClick={openBnManual}>{t({id:'catalogacao.ui.bnManual'})}</button>
      <button type="button" className="ab-button ab-button--secondary ab-button--sm"
        onClick={runBnIsbnLookup} disabled={bnLoading}>
        {bnLoading ? t({id:'catalogacao.ui.bnLoading'}) : t({id:'catalogacao.ui.bnIsbn'})}
      </button>
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

    {/* BN Brasil results */}
    {bnResult?.results?.length > 0 && (
      <div style={{ marginTop: 10 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6, flexWrap: 'wrap', gap: 6 }}>
          <span style={{ fontSize: '.78rem', fontWeight: 600 }}>{t({ id: 'catalogacao.ui.bnResultsTitle' }, { total: bnResult.total })}</span>
          <button type="button" className="ab-button ab-button--ghost ab-button--sm"
            onClick={clearBnResult}>{t({ id: 'catalogacao.ui.clearBn' })}</button>
        </div>
        <div style={{ border: '1px solid rgba(255,255,255,.1)', borderRadius: 8, overflow: 'hidden', maxHeight: 200, overflowY: 'auto' }}>
          {bnResult.results.map((item, i) => (
            <div key={i} style={{
              padding: '8px 10px', cursor: 'pointer',
              background: i % 2 === 0 ? 'rgba(0,0,0,.15)' : 'transparent',
              borderBottom: '1px solid rgba(255,255,255,.06)',
            }}
              onClick={() => onApplyBnResult(item)}
            >
              <div style={{ fontSize: '.82rem', fontWeight: 600 }}>{item.title}</div>
              <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                {[item.author, item.publication, item.material].filter(Boolean).join(' · ')}
              </div>
              {item.subject && (
                <div style={{ fontSize: '.68rem', color: 'rgba(255,255,255,.4)', marginTop: 2 }}>
                  {t({ id: 'catalogacao.ui.subjectsLabel' })} {item.subject}
                </div>
              )}
            </div>
          ))}
        </div>
        <div style={{ fontSize: '.68rem', color: 'var(--brand-muted, #666)', marginTop: 4 }}>
          {t({ id: 'catalogacao.ui.bnApplyHint' })}
        </div>
      </div>
    )}

    {bnResult && bnResult.results?.length === 0 && (
      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', padding: '8px 0', marginTop: 6 }}>
        {t({ id: 'catalogacao.ui.bnNoResult' })}
      </div>
    )}
    </>
  );
}
