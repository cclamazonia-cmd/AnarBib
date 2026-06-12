import { useIntl } from 'react-intl';
import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// Champs cruciaux comparés (colonne nom → clé i18n EXISTANTE, zéro nouvelle clé).
// Les noms de colonne correspondent aux retours de api.suggest_draft_duplicates
// ET aux colonnes de book_drafts (fetch source).
const FIELDS = [
  ['titulo', 'catalogacao.field.title'],
  ['subtitulo', 'catalogacao.field.subtitle'],
  ['autor', 'catalog.chip.author'],
  ['isbn', 'catalogacao.field.isbn'],
  ['ano', 'catalogacao.field.year'],
  ['editora', 'catalogacao.field.publisher'],
  ['cdd', 'catalogacao.field.cdd'],
  ['colecao', 'catalog.chip.collection'],
  ['idioma', 'catalogacao.field.language'],
];

const norm = (v) => (v == null ? '' : String(v).trim().toLowerCase());

/**
 * Comparaison + fusion de doublons d'un brouillon (#152) — file éditoriale.
 * Appelle api.suggest_draft_duplicates(p_draft_id) + relit le brouillon source,
 * affiche une comparaison côte-à-côte des champs cruciaux (différences surlignées),
 * et permet — champ par champ — de reprendre une valeur d'un candidat puis de fusionner :
 *   • candidat publié → api.merge_draft_into_book (enrichit la fiche, absorbe le brouillon) ;
 *   • candidat brouillon → api.merge_book_drafts (enrichit ce brouillon, écarte le doublon).
 */
export default function DuplicateCompareModal({ draftId, draftLabel, onClose, onEditItem, onMerged }) {
  const { formatMessage: t } = useIntl();
  const [src, setSrc] = useState(null);
  const [cands, setCands] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState('');
  const [picks, setPicks] = useState({});     // `${i}:${col}` → true (reprendre la valeur du candidat i)
  const [merging, setMerging] = useState(false);
  const [mergeErr, setMergeErr] = useState('');

  useEffect(() => {
    let alive = true;
    (async () => {
      setLoading(true); setErr('');
      try {
        const sel = 'titulo,subtitulo,autor,isbn,ano,editora,cdd,colecao,idioma,tipo_material';
        const [srcRes, candRes] = await Promise.all([
          supabase.from('book_drafts').select(sel).eq('id', draftId).maybeSingle(),
          supabase.schema('api').rpc('suggest_draft_duplicates', { p_draft_id: draftId }),
        ]);
        if (candRes.error) throw candRes.error;
        if (!alive) return;
        setSrc(srcRes.data || {});
        setCands((candRes.data || []).slice(0, 6));
      } catch (e) { if (alive) setErr(localizeError(e, t)); }
      finally { if (alive) setLoading(false); }
    })();
    return () => { alive = false; };
  }, [draftId, t]);

  // Sens du merge (asymétrique) :
  //   • candidat publié (A) : c'est la FICHE (candidat) qui survit → elle adopte la
  //     valeur DU BROUILLON (src) pour les champs cochés ;
  //   • candidat brouillon (B) : c'est le BROUILLON-SOURCE qui survit → il adopte la
  //     valeur DU CANDIDAT pour les champs cochés.
  const otherVal  = (c, col) => (c.source === 'book' ? src?.[col] : c[col]);   // valeur adoptée si cochée
  const targetVal = (c, col) => (c.source === 'book' ? c[col] : src?.[col]);   // valeur de la cible (survivante)
  const canTake   = (c, col) => norm(otherVal(c, col)) !== '' && norm(otherVal(c, col)) !== norm(targetVal(c, col));
  const togglePick = (i, col) => setPicks((p) => ({ ...p, [`${i}:${col}`]: !p[`${i}:${col}`] }));

  const cellBg = (srcVal, candVal, picked) => {
    if (picked) return 'rgba(29,78,216,.30)';
    const a = norm(srcVal), b = norm(candVal);
    if (!a || !b) return 'transparent';
    return a === b ? 'rgba(21,128,61,.18)' : 'rgba(180,83,9,.18)';
  };

  async function doMerge(cand, i) {
    const fields = {};
    for (const [col] of FIELDS) {
      if (picks[`${i}:${col}`] && canTake(cand, col)) fields[col] = otherVal(cand, col);
    }
    if (!window.confirm(t({ id: 'catalogacao.dup.mergeConfirm' }))) return;
    setMerging(true); setMergeErr('');
    try {
      const isBook = cand.source === 'book';
      const fn = isBook ? 'merge_draft_into_book' : 'merge_book_drafts';
      const params = isBook
        ? { p_draft_id: draftId, p_book_id: cand.candidate_id, p_fields: fields }
        : { p_survivor_id: draftId, p_loser_id: cand.candidate_id, p_fields: fields };
      const { error } = await supabase.schema('api').rpc(fn, params);
      if (error) throw error;
      onMerged?.();
      onClose();
    } catch (e) {
      setMergeErr(localizeError(e, t));
    } finally {
      setMerging(false);
    }
  }

  const th = { padding: '8px 10px', textAlign: 'left', fontSize: '.72rem', fontWeight: 700, borderBottom: '1px solid rgba(255,255,255,.12)', verticalAlign: 'bottom' };
  const td = { padding: '6px 10px', fontSize: '.8rem', borderBottom: '1px solid rgba(255,255,255,.05)', verticalAlign: 'top' };
  const lblTd = { ...td, fontWeight: 600, color: 'var(--brand-muted, #bbb)', whiteSpace: 'nowrap' };

  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed', inset: 0, zIndex: 1000, background: 'rgba(0,0,0,.6)',
        display: 'flex', alignItems: 'flex-start', justifyContent: 'center', padding: '4vh 12px', overflowY: 'auto',
      }}
    >
      <div
        onClick={e => e.stopPropagation()}
        style={{
          width: 'min(960px, 100%)', background: 'var(--brand-surface, #1b1b1f)',
          border: '1px solid rgba(255,255,255,.12)', borderRadius: 12, boxShadow: '0 12px 40px rgba(0,0,0,.5)',
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12, padding: '14px 16px', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
          <div style={{ minWidth: 0 }}>
            <h3 style={{ margin: 0, fontSize: '1rem' }}>{t({ id: 'catalogacao.dup.title' })}</h3>
            <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #999)', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {draftLabel}
            </div>
          </div>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={onClose} style={{ flexShrink: 0 }}>
            {t({ id: 'common.close' })}
          </button>
        </div>

        <div style={{ padding: 16 }}>
          {loading && <div style={{ fontSize: '.85rem', color: 'var(--brand-muted, #999)' }}>{t({ id: 'catalogacao.queue.refreshing' })}</div>}
          {err && <div style={{ fontSize: '.82rem', color: '#f87171' }}>{err}</div>}
          {!loading && !err && cands.length === 0 && (
            <div style={{ fontSize: '.88rem', color: '#4ade80', padding: '8px 0' }}>{t({ id: 'catalogacao.dup.none' })}</div>
          )}

          {!loading && !err && cands.length > 0 && (
            <div style={{ overflowX: 'auto' }}>
              {mergeErr && <div style={{ fontSize: '.82rem', color: '#f87171', marginBottom: 8 }}>{mergeErr}</div>}
              <table style={{ borderCollapse: 'collapse', width: '100%', minWidth: 520 }}>
                <thead>
                  <tr>
                    <th style={{ ...th, minWidth: 96 }} />
                    <th style={{ ...th, background: 'rgba(29,78,216,.12)' }}>{t({ id: 'catalogacao.dup.source' })}</th>
                    {cands.map((c, i) => (
                      <th key={i} style={th}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                          <span style={{ display: 'flex', gap: 4, flexWrap: 'wrap', alignItems: 'center' }}>
                            <span className={`cat-pill ${c.source === 'book' ? 'ok' : 'info'}`} style={{ fontSize: '.58rem' }}>
                              {t({ id: c.source === 'book' ? 'catalogacao.status.published' : 'catalogacao.status.draft' })}
                            </span>
                            <span className={`cat-pill ${c.match_kind === 'isbn' ? 'warn' : ''}`} style={{ fontSize: '.58rem' }}>
                              {t({ id: c.match_kind === 'isbn' ? 'catalogacao.dup.byIsbn' : 'catalogacao.dup.byApprox' })}
                            </span>
                            <span style={{ fontSize: '.66rem', color: 'var(--brand-muted, #aaa)' }}>{Math.round((Number(c.score) || 0) * 100)}%</span>
                          </span>
                          <button type="button" className="ab-button ab-button--sm" disabled={merging}
                            onClick={() => doMerge(c, i)} style={{ alignSelf: 'flex-start', fontSize: '.66rem', padding: '3px 8px' }}>
                            {t({ id: c.source === 'book' ? 'catalogacao.dup.mergeInto' : 'catalogacao.dup.mergeDrafts' })}
                          </button>
                          {c.source === 'draft' && onEditItem && (
                            <button type="button" className="ab-button ab-button--secondary ab-button--sm" style={{ alignSelf: 'flex-start', fontSize: '.62rem', padding: '1px 6px' }}
                              onClick={() => { onClose(); onEditItem('book', c.candidate_id); }}>
                              {t({ id: 'catalogacao.queue.resume' })}
                            </button>
                          )}
                        </div>
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {FIELDS.map(([col, key]) => (
                    <tr key={col}>
                      <td style={lblTd}>{t({ id: key })}</td>
                      <td style={{ ...td, background: 'rgba(29,78,216,.06)' }}>{src?.[col] || '—'}</td>
                      {cands.map((c, i) => {
                        const takeable = canTake(c, col);
                        const picked = !!picks[`${i}:${col}`];
                        const other = otherVal(c, col);
                        // En scénario A la valeur adoptée (brouillon) diffère de la valeur affichée (fiche) → on l'explicite.
                        const append = takeable && norm(other) !== norm(c[col]);
                        return (
                          <td key={i} style={{ ...td, background: cellBg(src?.[col], c[col], picked && takeable) }}>
                            <div>{c[col] || '—'}</div>
                            {takeable && (
                              <label style={{ display: 'inline-flex', gap: 4, alignItems: 'center', marginTop: 3, fontSize: '.64rem', color: 'var(--brand-muted, #9bb)', cursor: 'pointer' }}>
                                <input type="checkbox" checked={picked} disabled={merging} onChange={() => togglePick(i, col)} />
                                <span>{t({ id: 'catalogacao.dup.fieldTake' })}{append ? ` « ${other} »` : ''}</span>
                              </label>
                            )}
                          </td>
                        );
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
              <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 8 }}>
                {t({ id: 'catalogacao.queue.selectedCount' }, { count: cands.length })}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
