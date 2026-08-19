import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import Modal from '@/components/ui/Modal';
import { localizeError } from '@/lib/localizeError';

/**
 * Dédoublonnage du catalogue PUBLIÉ (balayage global).
 *
 * Pendant global de la détection par notice qui existe déjà dans BookDraftForm
 * pendant le catalogage : `suggest_catalog_duplicates()` applique exactement
 * les mêmes règles (ISBN normalisé identique, ou titre ≥ 0,5 avec auteur
 * compatible ≥ 0,4, hors même œuvre et hors paires déjà écartées), mais sur
 * tout le catalogue d'un coup. Les deux vues ne peuvent donc pas se contredire.
 *
 * Deux natures de doublons, volontairement séparées à l'écran :
 *   • INTERNE — les deux notices ont les mêmes bibliothèques détentrices.
 *     C'est du ménage : la fusion est proposée.
 *   • INTER-BIBLIOTHÈQUES — la même œuvre cataloguée séparément par des
 *     bibliothèques différentes. Fusionner revient à MUTUALISER, ce qui engage
 *     une bibliothèque dont on n'est pas forcément membre : on liste et on
 *     signale, sans bouton destructeur. `fusion_possible` est calculé côté
 *     base, pour que l'interface ne puisse pas se tromper — et merge_book
 *     refuserait de toute façon (garde de rattachement, 20/08/2026).
 *
 * Trois actions, reprises de la détection par notice pour rester cohérent :
 *   • « Même œuvre » (group_books_as_editions) — non destructive, disponible
 *     sur les DEUX listes. C'est souvent la bonne réponse en inter-biblios :
 *     deux éditions du même texte. La paire disparaît alors du balayage, qui
 *     exclut les notices partageant une œuvre.
 *   • « Pas un doublon » (mark_books_not_duplicate) — écarte la paire.
 *   • « Fusionner ici » (merge_book) — destructif, interne uniquement.
 *
 * L'appel coûte ~4 s sur 2 700 notices (index GIN trigrammes). On charge donc
 * TOUT une fois, puis on filtre en mémoire : un seul temps d'attente.
 */
export default function CatalogDuplicatesModal({ isOpen, onClose, onChanged }) {
  const { formatMessage: t } = useIntl();
  const [loading, setLoading] = useState(false);
  const [rows, setRows] = useState([]);
  const [err, setErr] = useState('');
  const [scope, setScope] = useState('interne');
  const [busyPair, setBusyPair] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setErr('');
    const { data, error } = await supabase.rpc('suggest_catalog_duplicates', { p_max: 500 });
    if (error) setErr(localizeError(error, t));
    else setRows(data || []);
    setLoading(false);
  }, [t]);

  useEffect(() => { if (isOpen) load(); }, [isOpen, load]);

  const key = (r) => `${r.book_id_a}:${r.book_id_b}`;
  const shown = rows.filter((r) => (scope === 'interne' ? r.fusion_possible : !r.fusion_possible));
  const nbInterne = rows.filter((r) => r.fusion_possible).length;
  const nbCroise = rows.length - nbInterne;

  const retirer = (r) => setRows((prev) => prev.filter((x) => key(x) !== key(r)));

  async function agir(r, fn) {
    setBusyPair(key(r));
    setErr('');
    const { error } = await fn();
    if (error) setErr(localizeError(error, t));
    else { retirer(r); onChanged?.(); }
    setBusyPair(null);
  }

  const ecarter = (r) => agir(r, () =>
    supabase.rpc('mark_books_not_duplicate', { p_a: r.book_id_a, p_b: r.book_id_b }));

  const memeOeuvre = (r) => agir(r, () =>
    supabase.rpc('group_books_as_editions', { p_book_ids: [r.book_id_a, r.book_id_b] }));

  function fusionner(r, canonicalId) {
    const garde = canonicalId === r.book_id_a ? r.titulo_a : r.titulo_b;
    const perdu = canonicalId === r.book_id_a ? r.titulo_b : r.titulo_a;
    const duplicateId = canonicalId === r.book_id_a ? r.book_id_b : r.book_id_a;
    if (!window.confirm(t({ id: 'catalogacao.dedup.confirm' }, { dup: perdu, canonical: garde }))) return;
    return agir(r, () =>
      supabase.rpc('merge_book', { p_canonical_id: canonicalId, p_duplicate_id: duplicateId }));
  }

  const cote = (r, p) => ({
    id: r[`book_id_${p}`],
    ref: r[`ref_${p}`],
    titulo: r[`titulo_${p}`],
    autor: r[`autor_${p}`],
    ano: r[`ano_${p}`],
    libs: r[`bibliotecas_${p}`],
    ex: r[`exemplares_${p}`],
  });

  const tabBtn = (id, label, n) => (
    <button
      type="button"
      onClick={() => setScope(id)}
      style={{
        padding: '8px 16px', fontSize: '.88rem', fontWeight: 600, background: 'none',
        border: 'none', cursor: 'pointer', marginBottom: -2,
        borderBottom: `2px solid ${scope === id ? 'var(--brand-color-primary, #7a0b14)' : 'transparent'}`,
        color: scope === id ? 'var(--brand-text, #f4f4f4)' : 'var(--brand-muted, #aaa)',
      }}
    >
      {label} ({n})
    </button>
  );

  return (
    <Modal isOpen={isOpen} onClose={onClose} size="large" title={t({ id: 'catalogacao.dedup.title' })}>
      {loading && (
        <p style={{ color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.finding' })}</p>
      )}

      {err && (
        <div style={{
          padding: '10px 14px', borderRadius: 8, marginBottom: 12,
          background: 'rgba(220,38,38,.12)', color: '#f87171', fontSize: '.9rem',
        }}>{err}</div>
      )}

      {!loading && !err && rows.length === 0 && <p>{t({ id: 'catalogacao.dedup.none' })}</p>}

      {!loading && rows.length > 0 && (
        <>
          <div style={{ display: 'flex', borderBottom: '2px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
            {tabBtn('interne', t({ id: 'catalogacao.dedup.scanTabInternal' }), nbInterne)}
            {tabBtn('croise', t({ id: 'catalogacao.dedup.scanTabCross' }), nbCroise)}
          </div>

          <p style={{ fontSize: '.84rem', color: 'var(--brand-muted, #999)', marginTop: 0, marginBottom: 14 }}>
            {t({ id: scope === 'interne' ? 'catalogacao.dedup.scanHelpInternal' : 'catalogacao.dedup.scanHelpCross' })}
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {shown.map((r) => {
              const busy = busyPair === key(r);
              return (
                <div key={key(r)} style={{
                  border: '1px solid rgba(255,255,255,.12)', borderRadius: 10, padding: 12,
                  opacity: busy ? 0.5 : 1,
                }}>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8, flexWrap: 'wrap' }}>
                    <span className={`ab-pill ${r.match_kind === 'isbn' ? 'ab-pill--warn' : ''}`}>
                      {t({ id: r.match_kind === 'isbn' ? 'catalogacao.dedup.scanKindIsbn' : 'catalogacao.dedup.scanKindApprox' })}
                    </span>
                    <span style={{ fontSize: '.8rem', color: 'var(--brand-muted, #999)' }}>
                      {Math.round((r.score || 0) * 100)}%
                    </span>
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 10 }}>
                    {[cote(r, 'a'), cote(r, 'b')].map((c) => (
                      <div key={c.id} style={{ fontSize: '.86rem' }}>
                        <div style={{ fontWeight: 600 }}>{c.titulo}</div>
                        <div style={{ color: 'var(--brand-muted, #aaa)' }}>
                          {c.autor}{c.ano ? ` · ${c.ano}` : ''}
                        </div>
                        <div style={{ color: 'var(--brand-muted, #888)', fontSize: '.8rem', marginTop: 2 }}>
                          {c.ref} · {c.libs || '—'} · {t({ id: 'catalogacao.dedup.copies' }, { count: c.ex })}
                        </div>
                        <div style={{ marginTop: 6, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                          <a className="ab-button ab-button--mini" href={`/livro/${c.id}`}>
                            {t({ id: 'catalogacao.dedup.scanOpen' })}
                          </a>
                          {r.fusion_possible && (
                            <button type="button" className="ab-button ab-button--mini" disabled={busy}
                              onClick={() => fusionner(r, c.id)}>
                              {t({ id: 'catalogacao.dedup.merge' })}
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>

                  <div style={{ marginTop: 10, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                      disabled={busy} onClick={() => memeOeuvre(r)}
                      title={t({ id: 'catalogacao.dedup.sameWorkHint' })}>
                      {t({ id: 'catalogacao.dedup.sameWork' })}
                    </button>
                    <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                      disabled={busy} onClick={() => ecarter(r)}
                      title={t({ id: 'catalogacao.dedup.notDuplicateHint' })}>
                      {t({ id: 'catalogacao.dedup.notDuplicate' })}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}
    </Modal>
  );
}
