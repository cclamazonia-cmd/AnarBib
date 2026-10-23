// Bloc « Doublons possibles » de la notice publiée (palier avancé/complet) :
// recherche, « même œuvre », « pas un doublon », signalement, fusion.
// Sorti de BookDraftForm.jsx tel quel (E6, 23/10/2026), avec l'état et les
// actions qu'il est seul à lire (calculés par @babel/traverse).
// Garde : src/tests/notice-sections-montees.test.jsx.
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export default function BookDuplicatesPanel(p) {
  const { formatMessage: t } = useIntl();
  const {
    arbitreDoublons, bookDupBusy, bookDupLoading, bookDupMatches, catalogTier, confirmer,
    draftState, f, fillFromRecord, findBookDuplicates, groupAsEditions, setBookDupBusy, setMsg,
  } = p;

  // Fusionne le livre doublon `dupId` DANS le livre courant (= canonique).
  // La fusion reporte sur CE brouillon (ouvert sur la notice gardée) ce qu'elle
  // reprend du doublon — champs vides, sujets, contributeur·rices — : on le
  // recharge, sinon la prochaine publication réécrirait la notice avec ce qui
  // est à l'écran, et effacerait tout. Des modifications non enregistrées
  // seraient perdues au rechargement : on demande d'enregistrer d'abord.
  async function mergeBookDuplicateIntoCurrent(dupId, dupTitle) {
    const canonicalId = f('published_book_id');
    if (!canonicalId) return;
    if (draftState === 'dirty') {
      setMsg({ text: t({ id: 'catalogacao.dedup.saveBeforeMerge' }), kind: 'error' });
      return;
    }
    if (!(await confirmer({ message: t({ id: 'catalogacao.dedup.confirm' }, { dup: dupTitle, canonical: f('titulo') }), confirmLabel: t({ id: 'confirm.action.merge' }), tone: 'danger' }))) return;
    setBookDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('merge_book', {
        p_canonical_id: Number(canonicalId), p_duplicate_id: Number(dupId),
      });
      if (error) throw error;
      if (f('id')) {
        const { data: rechargé } = await supabase.from('book_drafts').select('*').eq('id', Number(f('id'))).single();
        if (rechargé) fillFromRecord(rechargé);   // efface le message : le nôtre vient après
      }
      setMsg({ text: t({ id: 'catalogacao.dedup.mergedBook' }, { dup: dupTitle }), kind: 'ok' });
      await findBookDuplicates(); // rafraichir
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // P1b : marquer une paire « ce n'est pas un doublon » (éditions distinctes) →
  // la paire est masquée définitivement des suggestions (table book_not_duplicate).
  async function markBooksNotDuplicate(dupId) {
    const canonicalId = f('published_book_id');
    if (!canonicalId) return;
    setBookDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('mark_books_not_duplicate', { p_a: Number(canonicalId), p_b: Number(dupId) });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.dedup.markedNotDuplicate' }), kind: 'ok' });
      await findBookDuplicates(); // rafraîchir : la paire écartée disparaît
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // DOUBLONS P4 : signaler la paire à la coordination. C'est ce qui remplace,
  // au poste de catalogage, les boutons qui détruisaient. Rien n'est modifié au
  // catalogue ; la personne qui a le livre en main transmet ce qu'elle a vu.
  async function reportDuplicatePair(dupId) {
    const canonicalId = f('published_book_id');
    if (!canonicalId) return;
    setBookDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('report_duplicate_pair', {
        p_a: Number(canonicalId), p_b: Number(dupId), p_note: null,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.dedup.reported' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  return (
    <>{catalogTier >= 2 && f('published_book_id') && (
            <div className="ab-span3" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 6 }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.dedup.title' })}</span>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findBookDuplicates} disabled={bookDupLoading}>
                  {bookDupLoading ? t({ id: 'catalogacao.dedup.finding' }) : t({ id: 'catalogacao.dedup.find' })}
                </button>
              </div>
              {bookDupMatches !== null && bookDupMatches.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.none' })}</div>
              )}
              {bookDupMatches !== null && bookDupMatches.length > 0 && (
                <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                  {bookDupMatches.map(d => (
                    <div key={d.book_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderBottom: '1px solid rgba(255,255,255,.04)' }}>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: '.82rem' }}>{d.titulo}{d.ano ? ` (${d.ano})` : ''}</div>
                        <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>{d.autor}{d.editora ? ` · ${d.editora}` : ''}{d.isbn ? ` · ISBN ${d.isbn}` : ''}</div>
                      </div>
                      <span style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.copies' }, { count: d.exemplares })}</span>
                      <span className={`cat-pill ${d.match_kind === 'isbn' ? 'ok' : 'warn'}`} style={{ fontSize: '.6rem' }}>
                        {d.match_kind === 'isbn' ? 'ISBN' : t({ id: 'catalogacao.link.approx' })} {Math.round(d.score * 100)}%
                      </span>
                      <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                        onClick={() => groupAsEditions(d.book_id)} disabled={bookDupBusy != null}
                        title={t({ id: 'catalogacao.dedup.sameWorkHint' })}>
                        {t({ id: 'catalogacao.dedup.sameWork' })}
                      </button>
                      {arbitreDoublons ? (
                        <>
                          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                            onClick={() => markBooksNotDuplicate(d.book_id)} disabled={bookDupBusy != null}
                            title={t({ id: 'catalogacao.dedup.notDuplicateHint' })}>
                            {t({ id: 'catalogacao.dedup.notDuplicate' })}
                          </button>
                          <button type="button" className="ab-button ab-button--danger ab-button--sm"
                            onClick={() => mergeBookDuplicateIntoCurrent(d.book_id, d.titulo)} disabled={bookDupBusy != null}
                            title={t({ id: 'catalogacao.dedup.deleteThisRecordHint' })}>
                            {bookDupBusy === d.book_id ? '…' : t({ id: 'catalogacao.dedup.deleteThisRecord' })}
                          </button>
                        </>
                      ) : (
                        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                          onClick={() => reportDuplicatePair(d.book_id)} disabled={bookDupBusy != null}
                          title={t({ id: 'catalogacao.dedup.reportHint' })}>
                          {bookDupBusy === d.book_id ? '…' : t({ id: 'catalogacao.dedup.report' })}
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}</>
  );
}
