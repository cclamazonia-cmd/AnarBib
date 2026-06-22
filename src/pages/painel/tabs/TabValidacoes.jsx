import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { Button, EmptyState } from '@/components/ui';
import { fmtD, TabHeader } from '../_shared';
import { supabase } from '@/lib/supabase';
import { useToast } from '@/contexts/ToastContext';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════
// TabValidacoes — MULTI P5 (volet staff) — validation des inscriptions
// ───────────────────────────────────────────────────────────
// Liste les appartenances `pending_validation` (rôle reader) de la biblio
// courante via api.list_pending_validations, et permet de les valider via
// api.validate_membership (→ active + numéro lecteur·rice local + note +
// journal). Maillon manquant qui rend l'auto-inscription P5c exploitable.
//
// Auto-suffisant (gère son propre fetch + actions, contrairement aux autres
// onglets du Painel) pour ne pas alourdir PanelPage. La garde de rôle reste
// côté PanelPage (tab === 'validacoes' && isLibrarian). Spec §8, #CL.10.
// ═══════════════════════════════════════════════════════════
export default function TabValidacoes({ libraryId }) {
  const { formatMessage: t } = useIntl();
  const { notifySuccess, notifyError } = useToast();
  const [rows, setRows] = useState(null);
  const [drafts, setDrafts] = useState({}); // membership_id -> { number, note }
  const [busyId, setBusyId] = useState(null);
  const [bulkBusy, setBulkBusy] = useState(false); // VALID-C1 : validation en lot
  // Suite 4 : prochain n° de lecteur·rice suggéré (préfixe + incrément), montré en
  // placeholder du champ numéro. Recalculé à chaque load (donc après validation).
  const [suggestedNumber, setSuggestedNumber] = useState(null);

  const load = useCallback(async () => {
    setRows(null);
    try {
      const { data, error } = await supabase
        .schema('api')
        .rpc('list_pending_validations', { p_library_id: libraryId || null });
      if (error) throw error;
      setRows(Array.isArray(data) ? data : []);
    } catch (e) {
      notifyError(localizeError(e, t, 'panel.validations.loadError'), e);
      setRows([]);
    }
    // Suite 4 : suggestion du prochain n° local (best-effort, ne bloque jamais la
    // liste). Seulement quand une biblio précise est ciblée. Tolère l'absence de la
    // RPC (404 le temps que PostgREST recharge le schéma) → simplement pas de suggestion.
    if (libraryId) {
      try {
        const { data: sug } = await supabase
          .schema('api')
          .rpc('suggest_next_reader_number', { p_library_id: libraryId });
        setSuggestedNumber(typeof sug === 'string' && sug.trim() ? sug.trim() : null);
      } catch { setSuggestedNumber(null); }
    } else {
      setSuggestedNumber(null);
    }
  }, [libraryId, notifyError, t]);

  useEffect(() => { load(); }, [load]);

  const patchDraft = (id, patch) =>
    setDrafts((d) => ({ ...d, [id]: { ...d[id], ...patch } }));

  const validate = useCallback(async (m) => {
    if (busyId) return;
    setBusyId(m.membership_id);
    const draft = drafts[m.membership_id] || {};
    try {
      const { data, error } = await supabase.schema('api').rpc('validate_membership', {
        p_membership_id: m.membership_id,
        p_local_reader_number: (draft.number || '').trim() || null,
        p_note: (draft.note || '').trim() || null,
      });
      if (error) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      if (row && row.ok === false) throw new Error(row.message || 'validate_failed');
      notifySuccess(t({ id: 'panel.validations.validateSuccess' }));
      await load();
    } catch (e) {
      notifyError(localizeError(e, t, 'panel.validations.validateError'), e);
    } finally {
      setBusyId(null);
    }
  }, [busyId, drafts, load, notifySuccess, notifyError, t]);

  // Suite 6 — refuser une inscription en attente. Silencieux (aucune notif), statut
  // 'removed' (re-candidature possible), raison = le champ « Nota » (note interne staff).
  const reject = useCallback(async (m) => {
    if (busyId) return;
    const name = [m.first_name, m.last_name].filter(Boolean).join(' ').trim() || m.email || '';
    if (!window.confirm(t({ id: 'panel.validations.rejectConfirm' }, { name }))) return;
    setBusyId(m.membership_id);
    const draft = drafts[m.membership_id] || {};
    try {
      const { data, error } = await supabase.schema('api').rpc('reject_membership', {
        p_membership_id: m.membership_id,
        p_note: (draft.note || '').trim() || null,
      });
      if (error) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      if (row && row.ok === false) throw new Error(row.message || 'reject_failed');
      notifySuccess(t({ id: 'panel.validations.rejectSuccess' }));
      await load();
    } catch (e) {
      notifyError(localizeError(e, t, 'panel.validations.rejectError'), e);
    } finally {
      setBusyId(null);
    }
  }, [busyId, drafts, load, notifySuccess, notifyError, t]);

  // VALID-C1 — valider en lot toutes les demandes en attente (sans numéro local ;
  // les numéros restent assignables individuellement). Confirmation explicite.
  const validateAll = useCallback(async () => {
    if (bulkBusy || !Array.isArray(rows) || rows.length === 0) return;
    if (!window.confirm(t({ id: 'panel.validations.bulkConfirm' }, { count: rows.length }))) return;
    setBulkBusy(true);
    let ok = 0, fail = 0;
    for (const m of rows) {
      try {
        const { data, error } = await supabase.schema('api').rpc('validate_membership', {
          p_membership_id: m.membership_id,
          p_local_reader_number: null,
          p_note: null,
        });
        if (error) throw error;
        const row = Array.isArray(data) ? data[0] : data;
        if (row && row.ok === false) throw new Error('failed');
        ok++;
      } catch { fail++; }
    }
    if (ok > 0) notifySuccess(t({ id: 'panel.validations.bulkDone' }, { count: ok }));
    if (fail > 0) notifyError(t({ id: 'panel.validations.bulkPartial' }, { count: fail }));
    await load();
    setBulkBusy(false);
  }, [bulkBusy, rows, load, notifySuccess, notifyError, t]);

  const displayName = (m) =>
    [m.first_name, m.last_name].filter(Boolean).join(' ').trim() || m.email || m.user_id;

  if (rows === null) {
    return <p className="ab-painel-memb-hint">{t({ id: 'common.loading' })}</p>;
  }

  return (
    <div>
      <TabHeader title={t({ id: 'panel.validations.title' })} onRefresh={load} />
      <p className="ab-painel-memb-hint">{t({ id: 'panel.tab.validations.hint' })}</p>

      {rows.length >= 2 && (
        <div style={{ marginBottom: 12 }}>
          <Button onClick={validateAll} disabled={bulkBusy}>
            {bulkBusy ? t({ id: 'common.loading' }) : t({ id: 'panel.validations.bulkButton' }, { count: rows.length })}
          </Button>
        </div>
      )}

      {rows.length === 0 ? (
        <EmptyState message={t({ id: 'panel.validations.empty' })} />
      ) : (
        <div className="ab-painel-memb-list">
          {rows.map((m) => {
            const draft = drafts[m.membership_id] || {};
            const busy = busyId === m.membership_id;
            return (
              <div key={m.membership_id} className="ab-painel-memb-row" style={{ flexWrap: 'wrap', gap: 10 }}>
                <div className="ab-painel-memb-row__main">
                  <div className="ab-painel-memb-name">{displayName(m)}</div>
                  <div className="ab-painel-memb-meta">
                    {m.email}
                    {m.email && ' · '}
                    {t({ id: 'panel.validations.requestedAt' })}: {fmtD(m.requested_at)}
                  </div>
                </div>
                <div className="ab-painel-memb-actions" style={{ flexWrap: 'wrap', gap: 8, alignItems: 'flex-end' }}>
                  <label style={{ display: 'flex', flexDirection: 'column', gap: 2, fontSize: '.72rem' }}>
                    {t({ id: 'panel.validations.readerNumber' })}
                    <input
                      className="ab-input"
                      type="text"
                      value={draft.number || ''}
                      disabled={busy}
                      placeholder={suggestedNumber || t({ id: 'panel.validations.readerNumberPlaceholder' })}
                      onChange={(e) => patchDraft(m.membership_id, { number: e.target.value })}
                      style={{ minWidth: 130 }}
                    />
                  </label>
                  <label style={{ display: 'flex', flexDirection: 'column', gap: 2, fontSize: '.72rem' }}>
                    {t({ id: 'panel.validations.note' })}
                    <input
                      className="ab-input"
                      type="text"
                      value={draft.note || ''}
                      disabled={busy}
                      placeholder={t({ id: 'panel.validations.notePlaceholder' })}
                      onChange={(e) => patchDraft(m.membership_id, { note: e.target.value })}
                      style={{ minWidth: 150 }}
                    />
                  </label>
                  <Button onClick={() => validate(m)} disabled={busy}>
                    {busy ? t({ id: 'common.loading' }) : t({ id: 'panel.validations.validateButton' })}
                  </Button>
                  <button
                    type="button"
                    className="ab-button ab-button--secondary"
                    onClick={() => reject(m)}
                    disabled={busy}
                    title={t({ id: 'panel.validations.rejectButton' })}
                  >
                    {t({ id: 'panel.validations.rejectButton' })}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
