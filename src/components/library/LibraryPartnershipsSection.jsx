import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

/**
 * LibraryPartnershipsSection
 * --------------------------------------------------------------------------
 * Editeur des partenaires de correspondance d'une bibliotheque.
 * Chantier « Partenaires de correspondance », etape 3.
 * Spec : docs/decisions/CHANTIER_partenaires_correspondance_2026-05-24.md
 *
 * Un partenaire de correspondance est, au choix :
 *   - une autre bibliotheque AnarBib federee (partner_library_id) ;
 *   - un collectif de l'annuaire catalog_partners (partner_catalog_id).
 * Une ligne = une declaration unilaterale (decision D4). La reciprocite
 * entre deux bibliotheques est affichee, pas couplee.
 *
 * Lecture   : vue api.library_partnerships_ui (from(), RLS, doctrine v3).
 * Ecritures : RPC fn_library_partnership_add / _remove / _update_notes.
 * Droits    : reserve au staff de coordination (prop canEdit = isCoord).
 *
 * Props :
 *   libraryId    uuid de la bibliotheque courante
 *   canEdit      booleen — autorise l'ajout / le retrait (isCoord)
 *   allLibraries liste deja chargee par BibliotecaPage (id, slug, name,
 *                short_name, network_mode, ...) — evite un fetch redondant
 */
export default function LibraryPartnershipsSection({ libraryId, canEdit, allLibraries = [] }) {
  const intl = useIntl();
  const t = (d, v) => intl.formatMessage(d, v);

  const [partnerships, setPartnerships] = useState([]);
  const [catalogPartners, setCatalogPartners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  // formulaire d'ajout : 'library' | 'catalog' | null
  const [addKind, setAddKind] = useState(null);
  const [selectedTarget, setSelectedTarget] = useState('');

  // ── styles alignes sur BibliotecaPage (theme sombre, variables --brand-*) ──
  const bx = { padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)',
    border: '1px solid rgba(255,255,255,.08)', marginTop: 16 };
  const lw = { border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, overflow: 'hidden' };
  const lr = (i) => ({ padding: '10px 12px',
    background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
    borderBottom: '1px solid rgba(255,255,255,.04)',
    display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 });
  const muted = { fontSize: '.82rem', color: 'var(--brand-muted)' };

  // ── chargement ────────────────────────────────────────────────────────────
  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      // Vue UI : security_invoker, RLS appliquee. Lecture simple -> from().
      const [{ data: lpData, error: lpErr }, { data: cpData, error: cpErr }] = await Promise.all([
        supabase.schema('api').from('library_partnerships_ui')
          .select('*').eq('library_id', libraryId).order('created_at', { ascending: true }),
        supabase.from('catalog_partners').select('*').order('display_name'),
      ]);
      if (lpErr) throw lpErr;
      if (cpErr) throw cpErr;
      setPartnerships(lpData || []);
      setCatalogPartners(cpData || []);
      setError('');
    } catch (err) {
      console.warn('LibraryPartnershipsSection.load:', err);
      setError(t({ id: 'biblioteca.partnerships.loadError' }));
    } finally {
      setLoading(false);
    }
  }, [libraryId]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { load(); }, [load]);

  // ── options d'ajout : exclure les partenaires deja declares ───────────────
  const linkedLibraryIds = useMemo(
    () => new Set(partnerships.filter(p => p.partner_kind === 'library').map(p => p.partner_library_id)),
    [partnerships]
  );
  const linkedCatalogIds = useMemo(
    () => new Set(partnerships.filter(p => p.partner_kind === 'catalog_partner').map(p => p.partner_catalog_id)),
    [partnerships]
  );

  // bibliotheques federees, hors la courante, hors deja declarees
  const availableLibraries = useMemo(
    () => allLibraries.filter(l =>
      l.network_mode === 'federated'
      && l.id !== libraryId
      && !linkedLibraryIds.has(l.id)
    ),
    [allLibraries, libraryId, linkedLibraryIds]
  );

  // collectifs de catalog_partners non encore declares
  const availableCatalogPartners = useMemo(
    () => catalogPartners.filter(cp => !linkedCatalogIds.has(cp.id)),
    [catalogPartners, linkedCatalogIds]
  );

  // ── actions ───────────────────────────────────────────────────────────────
  const resetAddForm = () => { setAddKind(null); setSelectedTarget(''); };

  const handleAdd = async () => {
    if (!selectedTarget || busy) return;
    setBusy(true);
    setError('');
    try {
      const params = addKind === 'library'
        ? { p_library_id: libraryId, p_partner_library_id: selectedTarget }
        : { p_library_id: libraryId, p_partner_catalog_id: Number(selectedTarget) };
      const { error: rpcErr } = await supabase.rpc('fn_library_partnership_add', params);
      if (rpcErr) throw rpcErr;
      resetAddForm();
      await load();
    } catch (err) {
      console.warn('LibraryPartnershipsSection.handleAdd:', err);
      // message duplicate -> cle dediee, sinon message generique
      const isDup = typeof err?.message === 'string' && err.message.includes('duplicate');
      setError(t({ id: isDup ? 'biblioteca.partnerships.duplicateError'
                             : 'biblioteca.partnerships.addError' }));
    } finally {
      setBusy(false);
    }
  };

  const handleRemove = async (partnershipId) => {
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      const { error: rpcErr } = await supabase.rpc('fn_library_partnership_remove',
        { p_partnership_id: partnershipId });
      if (rpcErr) throw rpcErr;
      await load();
    } catch (err) {
      console.warn('LibraryPartnershipsSection.handleRemove:', err);
      setError(t({ id: 'biblioteca.partnerships.removeError' }));
    } finally {
      setBusy(false);
    }
  };

  // ── nom d'affichage d'une bibliotheque pour le <select> ───────────────────
  const libLabel = (l) => l.short_name || l.name || l.slug;

  // ── rendu ─────────────────────────────────────────────────────────────────
  return (
    <div style={bx}>
      <h4 style={{ margin: '0 0 4px' }}>{t({ id: 'biblioteca.partnerships.title' })}</h4>
      <div style={{ ...muted, marginBottom: 10 }}>{t({ id: 'biblioteca.partnerships.hint' })}</div>

      {error && (
        <div className="cat-pill warn" style={{ display: 'block', marginBottom: 10, fontSize: '.78rem' }}>
          {error}
        </div>
      )}

      {loading && <div style={muted}>{t({ id: 'biblioteca.partnerships.loading' })}</div>}

      {/* Liste des partenaires declares */}
      {!loading && partnerships.length === 0 && (
        <div style={muted}>{t({ id: 'biblioteca.partnerships.empty' })}</div>
      )}

      {!loading && partnerships.length > 0 && (
        <div style={lw}>
          {partnerships.map((p, i) => (
            <div key={p.id} style={lr(i)}>
              <div style={{ minWidth: 0 }}>
                <div style={{ fontSize: '.9rem', fontWeight: 600, display: 'flex',
                  alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                  <span>{p.partner_display_name || '—'}</span>
                  {/* type de partenaire */}
                  <span className="cat-pill" style={{ fontSize: '.66rem' }}>
                    {p.partner_kind === 'library'
                      ? t({ id: 'biblioteca.partnerships.kindLibrary' })
                      : t({ id: 'biblioteca.partnerships.kindCatalog' })}
                  </span>
                  {/* reciprocite (seulement pour les partenaires-biblio) */}
                  {p.partner_kind === 'library' && p.is_reciprocal && (
                    <span className="cat-pill ok" style={{ fontSize: '.66rem' }}>
                      {t({ id: 'biblioteca.partnerships.reciprocal' })}
                    </span>
                  )}
                </div>
                <div style={muted}>
                  {p.partner_kind === 'library'
                    ? (p.partner_library_slug || '—')
                    : [p.partner_catalog_country_code, p.partner_catalog_base_url]
                        .filter(Boolean).join(' · ') || '—'}
                </div>
              </div>
              {canEdit && (
                <button
                  className="cat-tab-btn"
                  style={{ fontSize: '.74rem', flexShrink: 0 }}
                  disabled={busy}
                  onClick={() => handleRemove(p.id)}
                >
                  {t({ id: 'biblioteca.partnerships.remove' })}
                </button>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Bloc d'ajout — staff de coordination uniquement */}
      {canEdit && !loading && (
        <div style={{ marginTop: 12 }}>
          {addKind === null && (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button
                className="cat-tab-btn"
                style={{ fontSize: '.78rem' }}
                disabled={availableLibraries.length === 0}
                onClick={() => { setAddKind('library'); setSelectedTarget(''); }}
              >
                {t({ id: 'biblioteca.partnerships.addLibrary' })}
              </button>
              <button
                className="cat-tab-btn"
                style={{ fontSize: '.78rem' }}
                disabled={availableCatalogPartners.length === 0}
                onClick={() => { setAddKind('catalog'); setSelectedTarget(''); }}
              >
                {t({ id: 'biblioteca.partnerships.addCatalog' })}
              </button>
            </div>
          )}

          {addKind !== null && (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
              <select
                value={selectedTarget}
                onChange={(e) => setSelectedTarget(e.target.value)}
                style={{ flex: '1 1 220px', minWidth: 0 }}
              >
                <option value="">
                  {addKind === 'library'
                    ? t({ id: 'biblioteca.partnerships.selectLibrary' })
                    : t({ id: 'biblioteca.partnerships.selectCatalog' })}
                </option>
                {addKind === 'library'
                  ? availableLibraries.map(l => (
                      <option key={l.id} value={l.id}>{libLabel(l)}</option>
                    ))
                  : availableCatalogPartners.map(cp => (
                      <option key={cp.id} value={cp.id}>
                        {cp.display_name || cp.slug}
                      </option>
                    ))}
              </select>
              <button
                className="cat-tab-btn"
                style={{ fontSize: '.78rem' }}
                disabled={!selectedTarget || busy}
                onClick={handleAdd}
              >
                {t({ id: 'biblioteca.partnerships.confirmAdd' })}
              </button>
              <button
                className="cat-tab-btn"
                style={{ fontSize: '.78rem' }}
                disabled={busy}
                onClick={resetAddForm}
              >
                {t({ id: 'biblioteca.partnerships.cancel' })}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
