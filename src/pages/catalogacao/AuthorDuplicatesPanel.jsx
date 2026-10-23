// Doublons probables d'une autorité publiée : fusion (coordination) ou signalement — sorti d'AuthorDraftForm.jsx tel quel (E6, 23/10/2026). Monté avec
// key={authorId} ; la fusion reste réservée à qui arbitre les doublons (P4).
// Garde : src/tests/autorite-panneaux-montes.test.js.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { useConfirm } from '@/contexts/ConfirmContext';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export default function AuthorDuplicatesPanel({ authorId, preferredName, arbitreDoublons, onMessage }) {
  const { formatMessage: t } = useIntl();
  const confirmer = useConfirm();
  // Doublons d'autorite
  const [dupMatches, setDupMatches] = useState(null); // null = pas cherche
  const [dupLoading, setDupLoading] = useState(false);
  const [dupBusy, setDupBusy] = useState(null); // author_id en cours de fusion

  // ── Doublons d'autorite : detection + fusion ────────────────────────────
  async function findAuthorDuplicates() {
    if (!authorId) return;
    setDupLoading(true); setDupMatches(null);
    try {
      const { data, error } = await supabase.rpc('suggest_author_duplicates', { p_author_id: Number(authorId) });
      if (error) throw error;
      setDupMatches(data || []);
    } catch (err) {
      onMessage({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setDupLoading(false); }
  }

  // Fusionne le doublon `dupId` DANS l'autorite courante (= canonique).
  async function mergeDuplicateIntoCurrent(dupId, dupName) {
    const canonicalId = authorId;
    if (!canonicalId) return;
    if (!(await confirmer({ message: t({ id: 'catalogacao.dedup.confirm' }, { dup: dupName, canonical: preferredName }), confirmLabel: t({ id: 'confirm.action.merge' }), tone: 'danger' }))) return;
    setDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('merge_author', {
        p_canonical_id: Number(canonicalId), p_duplicate_id: Number(dupId),
      });
      if (error) throw error;
      onMessage({ text: t({ id: 'catalogacao.dedup.merged' }, { dup: dupName }), kind: 'ok' });
      await findAuthorDuplicates(); // rafraichir
    } catch (err) {
      onMessage({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setDupBusy(null); }
  }

  // DOUBLONS P8 : ce qu'on rend au staff en echange de merge_author, qui lui a
  // ete retire au paquet P4. Sans ce bouton, une bibliothecaire voyait la liste
  // des doublons probables et n'avait aucun moyen de transmettre ce qu'elle sait.
  async function reportAuthorityPair(dupId) {
    const courant = authorId;
    if (!courant) return;
    setDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('report_authority_pair', {
        p_a: Number(courant), p_b: Number(dupId), p_note: null,
      });
      if (error) throw error;
      onMessage({ text: t({ id: 'catalogacao.dedup.reported' }), kind: 'ok' });
    } catch (err) {
      onMessage({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setDupBusy(null); }
  }

  return (
    <>
          {/* ── Doublons possibles (fusion d'autorites) ─────────────── */}
          {authorId && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 6 }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.dedup.title' })}</span>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findAuthorDuplicates} disabled={dupLoading}>
                  {dupLoading ? t({ id: 'catalogacao.dedup.finding' }) : t({ id: 'catalogacao.dedup.find' })}
                </button>
              </div>
              {dupMatches !== null && dupMatches.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.none' })}</div>
              )}
              {dupMatches !== null && dupMatches.length > 0 && (
                <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                  {dupMatches.map(d => (
                    <div key={d.author_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderBottom: '1px solid rgba(255,255,255,.04)' }}>
                      <span style={{ flex: 1, minWidth: 0, fontSize: '.82rem' }}>{d.preferred_name}</span>
                      <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.books' }, { count: d.linked_books })}</span>
                      <span className={`cat-pill ${d.match_kind === 'exact' ? 'ok' : 'warn'}`} style={{ fontSize: '.6rem' }}>
                        {t({ id: d.match_kind === 'exact' ? 'catalogacao.link.exact' : 'catalogacao.link.approx' })} {Math.round(d.score * 100)}%
                      </span>
                      {arbitreDoublons ? (
                        <button type="button" className="ab-button ab-button--danger ab-button--sm"
                          onClick={() => mergeDuplicateIntoCurrent(d.author_id, d.preferred_name)} disabled={dupBusy != null}
                          title={t({ id: 'catalogacao.dedup.deleteThisAuthorityHint' })}>
                          {dupBusy === d.author_id ? '…' : t({ id: 'catalogacao.dedup.deleteThisAuthority' })}
                        </button>
                      ) : (
                        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                          onClick={() => reportAuthorityPair(d.author_id)} disabled={dupBusy != null}
                          title={t({ id: 'catalogacao.dedup.reportHint' })}>
                          {dupBusy === d.author_id ? '…' : t({ id: 'catalogacao.dedup.report' })}
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
    </>
  );
}
