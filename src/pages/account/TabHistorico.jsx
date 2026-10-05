import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { SUPABASE_URL } from '@/lib/supabase';
import { useLibrary } from '@/contexts/LibraryContext';
import { Button } from '@/components/ui';
import BookAvailability from '@/components/BookAvailability';
import ContaTabHeader from '@/pages/account/ContaTabHeader';

// ═══════════════════════════════════════════════════════════
// AnarBib — l'onglet « Historique » de Mon compte (E6, AccountPage lot 1,
// 05/10/2026). Sorti d'AccountPage.jsx tel quel : les données (emprunts,
// consultations et réservations terminés, préférences de conservation) et
// leurs écritures restent au parent, qui les charge à la première visite
// (HEAVY_TABS) ; les props portent les noms du parent.
// ═══════════════════════════════════════════════════════════

export default function TabHistorico({
  loanHistory, consultationsHistory, history, showHiddenHistory, setShowHiddenHistory,
  renderHistActions, histLinkBtn, retentionPrefs, setRetentionPrefs, handleSaveRetentionPrefs,
  retentionSaving, retentionMsg, setDeleteAllTarget, setDeleteAllConfirmText, loadData,
  availabilityMap, countFor,
}) {
  const { formatMessage: t } = useIntl();
  const { libraryName, libraryId } = useLibrary();
    const hiddenCount =
      loanHistory.filter(x => x.is_hidden_by_user).length +
      consultationsHistory.filter(x => x.is_hidden_by_user).length +
      history.filter(x => x.is_hidden_by_user).length;
    const visLoans = loanHistory.filter(x => showHiddenHistory || !x.is_hidden_by_user);
    const visConsult = consultationsHistory.filter(x => showHiddenHistory || !x.is_hidden_by_user);
    const visResas = history.filter(x => showHiddenHistory || !x.is_hidden_by_user);
    return (
    <div>
      <ContaTabHeader title={t({ id: 'account.history.title' })} onRefresh={() => loadData({ silent: true })} />
      <p className="ab-conta-hint">{t({ id: 'account.history.hint' })}</p>

      {/* #CL.8 D.6 — bandeau pédagogique permanent (politique de conservation) */}
      <div style={{ marginTop: 8, marginBottom: 8, padding: 12, background: 'rgba(96,165,250,.05)', borderRadius: 8, border: '1px solid rgba(96,165,250,.15)', fontSize: '.82rem', color: 'var(--brand-muted)' }}>
        <strong style={{ color: 'inherit' }}>{t({ id: 'account.retention.banner.title' })}</strong>{' '}
        {t({ id: 'account.retention.banner.body' })}
      </div>

      {hiddenCount > 0 && (
        <button type="button" style={{ ...histLinkBtn, marginBottom: 8 }}
          onClick={() => setShowHiddenHistory(v => !v)}>
          {showHiddenHistory
            ? t({ id: 'account.history.hideHiddenToggle' })
            : t({ id: 'account.history.showHiddenToggle' }, { count: hiddenCount })}
        </button>
      )}

      {/* Paquet 10 (10/05/2026) : section historique des emprunts */}
      <div style={{ marginTop: 16 }}>
        <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.history.loans.title' })}</h3>
        {visLoans.length === 0 ? (
          <p className="ab-conta-empty">{t({ id: 'account.history.loans.empty' })}</p>
        ) : (
          <div className="ab-conta-items">
            {visLoans.map((lh) => (
              <div key={`loan-${lh.emprestimo_id}`} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10, opacity: lh.is_hidden_by_user ? 0.55 : 1 }}>
                <div className="ab-conta-item__main" style={{ flex: 1 }}>
                  {lh.book_id ? (
                    <Link to={`/livro/${lh.book_id}`} className="ab-conta-item__title">{lh.titulos || '\u2014'}</Link>
                  ) : (
                    <span className="ab-conta-item__title">{lh.titulos || '\u2014'}</span>
                  )}
                  {lh.autores && <span className="ab-conta-item__meta">{lh.autores}</span>}
                  <span className="ab-conta-item__meta">
                    {lh.items_count > 1 && <>{t({ id: 'account.history.loans.itemsCount' }, { count: lh.items_count })} · </>}
                    ref: {lh.bib_refs || '\u2014'} · {lh.library_name || '\u2014'}
                    {lh.emprestimo_created_at && <> · {t({id:'account.loans.checkout'})}: {new Date(lh.emprestimo_created_at).toLocaleDateString()}</>}
                    {lh.returned_at && <> · {t({id:'account.loans.returnedOn'})}: {new Date(lh.returned_at).toLocaleDateString()}</>}
                    {lh.renewals_used > 0 && <> · {t({ id: 'account.history.loans.renewalsUsed' }, { count: lh.renewals_used })}</>}
                  </span>
                  {lh.book_id && availabilityMap.get(Number(lh.book_id)) && (
                    <span className="ab-conta-item__meta" style={{ marginTop: 4 }}>
                      <BookAvailability availability={availabilityMap.get(Number(lh.book_id))} variant="inline" />
                    </span>
                  )}
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                  <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600, background: 'rgba(74,222,128,.12)', color: '#4ade80' }}>
                    {t({ id: 'account.history.loans.completed' })}
                  </span>
                  {renderHistActions('loans', lh.emprestimo_id, lh.titulos || '\u2014', lh.is_hidden_by_user)}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
      {/* Paquet 26 L4 (14/05/2026) : section historique des consultas */}
      <div style={{ marginTop: 24 }}>
        <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.history.consultations.title' })}</h3>
        {visConsult.length === 0 ? (
          <p className="ab-conta-empty">{t({ id: 'account.history.consultations.empty' })}</p>
        ) : (
          <div className="ab-conta-items">
            {visConsult.map((c, i) => {
              const stageKey = c.workflow_stage || c.status || '';
              const stageLabel = stageKey ? t({ id: `consultation.stage.${stageKey.replace('-','_')}`, defaultMessage: stageKey }) : '\u2014';
              const isFinal = ['consultada','cancelada_leitor','cancelada_biblioteca','expirada'].includes(stageKey);
              return (
                <div key={`ch-${c.consulta_item_id ?? i}`} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10, opacity: c.is_hidden_by_user ? 0.55 : 1 }}>
                  <div className="ab-conta-item__main" style={{ flex: 1 }}>
                    <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || '\u2014'}</Link>
                    <span className="ab-conta-item__meta">{c.autor || '\u2014'}{c.editora && ` \u00b7 ${c.editora}`}{c.ano && ` (${c.ano})`}</span>
                    <span className="ab-conta-item__meta">
                      ref: {c.bib_ref || '\u2014'} · {c.library_name || '\u2014'}
                      {c.requested_at && <> · {t({id:'account.history.consultations.requestedOn'})}: {new Date(c.requested_at).toLocaleDateString()}</>}
                      {c.consulted_at && <> · {t({id:'account.history.consultations.consultedOn'})}: {new Date(c.consulted_at).toLocaleDateString()}</>}
                      {c.cancelled_at && <> · {t({id:'account.history.cancelledOn'})}: {new Date(c.cancelled_at).toLocaleDateString()}</>}
                    </span>
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                    <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600,
                      background: isFinal ? 'rgba(255,255,255,.05)' : 'rgba(251,191,36,.12)',
                      color: isFinal ? 'var(--brand-muted)' : '#fbbf24' }}>
                      {stageLabel}
                    </span>
                    {renderHistActions('consultations', c.consulta_item_id, c.titulo || c.bib_ref || '\u2014', c.is_hidden_by_user)}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Section historique des reservations (preexistante) */}
      <div style={{ marginTop: 24 }}>
        <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.history.reservations.title' })}</h3>
        {visResas.length === 0 ? (
          <p className="ab-conta-empty">{t({ id: 'account.history.empty' })}</p>
        ) : (
        <div className="ab-conta-items">
          {visResas.map((h, i) => {
            const coverUrl = h.cover_object_path ? `${SUPABASE_URL}/storage/v1/object/public/covers/${h.cover_object_path}` : null;
            const stageKey = h.workflow_stage_effective || h.status || '';
            const stageLabel = stageKey ? t({ id: `reservation.stage.${stageKey.replace('-','_')}`, defaultMessage: stageKey }) : '\u2014';
            const isFinal = ['cancelada_leitor','cancelada_biblioteca','expirada','retirada_efetivada','liberada_para_circulacao','convertida_em_emprestimo'].includes(h.workflow_stage_effective || h.status);
            return (
              <div key={`res-${h.reserva_item_id ?? i}`} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10, opacity: h.is_hidden_by_user ? 0.55 : 1 }}>
                {coverUrl && <img src={coverUrl} alt="" loading="lazy" style={{ width: 40, height: 56, objectFit: 'cover', borderRadius: 4, flexShrink: 0, background: 'rgba(0,0,0,.2)' }} onError={e => { e.target.style.display = 'none'; }} />}
                <div className="ab-conta-item__main" style={{ flex: 1 }}>
                  <Link to={`/livro/${h.book_id}`} className="ab-conta-item__title">{h.titulo || h.bib_ref || '\u2014'}</Link>
                  <span className="ab-conta-item__meta">{h.autor || '\u2014'}{h.editora && ` \u00b7 ${h.editora}`}{h.ano && ` (${h.ano})`}</span>
                  <span className="ab-conta-item__meta">
                    ref: {h.bib_ref || '\u2014'} · {h.library_name || '\u2014'}
                    {h.reserved_at && <> · {t({id:'account.history.reservedOn'})}: {new Date(h.reserved_at).toLocaleDateString()}</>}
                    {h.fulfilled_at && <> · {t({id:'account.history.fulfilledOn'})}: {new Date(h.fulfilled_at).toLocaleDateString()}</>}
                    {h.cancelled_at && <> · {t({id:'account.history.cancelledOn'})}: {new Date(h.cancelled_at).toLocaleDateString()}</>}
                  </span>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                  <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600,
                    background: isFinal ? 'rgba(255,255,255,.05)' : 'rgba(251,191,36,.12)',
                    color: isFinal ? 'var(--brand-muted)' : '#fbbf24' }}>
                    {stageLabel}
                  </span>
                  <Link to={`/livro/${h.book_id}`} style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>{t({ id: 'account.history.seeAvailability' })}</Link>
                  {renderHistActions('reservations', h.reserva_item_id, h.titulo || h.bib_ref || '\u2014', h.is_hidden_by_user)}
                </div>
              </div>
            );
          })}
        </div>
        )}
      </div>
      {/* #CL.8 D.7 — préférences de conservation prospective (par domaine) */}
      {libraryId && (
      <div style={{ marginTop: 24, padding: 16, background: 'rgba(96,165,250,.05)', borderRadius: 8, border: '1px solid rgba(96,165,250,.15)' }}>
        <h3 className="ab-conta-section-title" style={{ fontSize: '1rem', marginTop: 0, marginBottom: 8 }}>
          {t({ id: 'account.retentionPrefs.title' })}
        </h3>
        <p className="ab-conta-hint" style={{ marginTop: 0, marginBottom: 12 }}>
          {t({ id: 'account.retentionPrefs.intro' }, { library: libraryName })}
        </p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 12 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
            <input type="checkbox" checked={retentionPrefs.loans}
              onChange={(e) => setRetentionPrefs(p => ({ ...p, loans: e.target.checked }))} />
            <span>{t({ id: 'account.retentionPrefs.disableLoans' })}</span>
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
            <input type="checkbox" checked={retentionPrefs.reservations}
              onChange={(e) => setRetentionPrefs(p => ({ ...p, reservations: e.target.checked }))} />
            <span>{t({ id: 'account.retentionPrefs.disableReservations' })}</span>
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
            <input type="checkbox" checked={retentionPrefs.consultations}
              onChange={(e) => setRetentionPrefs(p => ({ ...p, consultations: e.target.checked }))} />
            <span>{t({ id: 'account.retentionPrefs.disableConsultations' })}</span>
          </label>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <Button variant="secondary" onClick={handleSaveRetentionPrefs} disabled={retentionSaving}>
            {retentionSaving ? t({ id: 'common.saving' }) : t({ id: 'common.save' })}
          </Button>
          {retentionMsg && <span className="ab-conta-msg" style={{ fontSize: '.85rem' }}>{retentionMsg}</span>}
        </div>
        <p className="ab-conta-hint" style={{ marginTop: 12, marginBottom: 0, fontSize: '.78rem', fontStyle: 'italic' }}>
          {t({ id: 'account.retentionPrefs.note' })}
        </p>
      </div>
      )}
      {/* #CL.8 C.5 — suppression de masse rétroactive par domaine (D.7) */}
      {libraryId && ['loans','reservations','consultations'].some(d => countFor(d) > 0) && (
      <div style={{ marginTop: 16, padding: 16, background: 'rgba(248,113,113,.05)', borderRadius: 8, border: '1px solid rgba(248,113,113,.2)' }}>
        <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem', marginTop: 0, marginBottom: 8, color: '#f87171' }}>
          {t({ id: 'account.history.deleteAll.sectionTitle' })}
        </h3>
        <p className="ab-conta-hint" style={{ marginTop: 0, marginBottom: 12 }}>
          {t({ id: 'account.history.deleteAll.sectionHint' })}
        </p>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {['loans','reservations','consultations'].map(domain => {
            const cnt = countFor(domain);
            if (cnt === 0) return null;
            return (
              <Button key={domain} variant="danger" onClick={() => { setDeleteAllConfirmText(''); setDeleteAllTarget({ domain }); }}>
                {t({ id: 'account.history.deleteAll.button' }, { domain: t({ id: `account.history.deleteAll.domain.${domain}` }), count: cnt })}
              </Button>
            );
          })}
        </div>
      </div>
      )}
    </div>
    );
}
