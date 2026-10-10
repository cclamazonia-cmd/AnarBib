// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 7 (09/10/2026, REGISTRE IMP-26 d/e/f, IMP-34) : les
// exemplaires retirés d'un run, dans Importations.
//
// Le constat (public.fn_import_retraits) se fait sur le FICHIER ENTIER : un
// exemplaire importé de la même source, sur une notice du fichier, dont ni le
// code ni l'identifiant interne ne sont plus décrits nulle part, a disparu ;
// en prêt, réservé, en PEB ou en consultation, il est « disparu mais engagé »
// et attend le réimport suivant ; un retiré qui réapparaît reçoit une levée.
// Rien n'est proposé sans « export complet » déclaré au dépôt, pour un fichier
// qui ne décrit aucun exemplaire, une ligne en échec ou un run en cours ; au-delà
// du seuil (10 % ET 20), la coordination confirme d'abord. « Proposer les
// retraits » range les brouillons dans le lot du run : ils passent par la
// révision, puis la publication ne change que le marqueur.
// ═══════════════════════════════════════════════════════════
import { useCallback, useEffect, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import AppIcon from '@/components/ui/AppIcon';
import { assertRpcOk } from '../../lib/rpcStatus.js';
import {
  VERDICTS_RETRAITS, PAGE_RETRAITS, proposables, confirmationDemandee, aDesConstats,
  cleVerdict, cleDetail, cumulerPropositions,
} from '../../lib/importRetraits.js';

const muted = { color: 'var(--brand-muted, #94a3b8)' };
const cell = { padding: '3px 8px', borderBottom: '1px solid var(--brand-border, rgba(0,0,0,.08))', textAlign: 'left', verticalAlign: 'top' };
// au plus tant d'appels du geste à la suite (1 000 brouillons chacun)
const APPELS_MAX = 50;

export default function RunRetraitsPanel({ runId, canAct = false, onChanged }) {
  const { formatMessage: t, formatDate } = useIntl();
  const [bilan, setBilan] = useState(null);
  const [erreur, setErreur] = useState('');
  const [decalage, setDecalage] = useState(0);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  const charger = useCallback(async (offset = 0) => {
    if (!runId) return;
    const { data, error } = await supabase.rpc('fn_import_retraits', {
      p_run_id: Number(runId), p_limite: PAGE_RETRAITS, p_decalage: offset,
    });
    if (error) { setErreur(localizeError(error, t)); setBilan(null); return; }
    setErreur('');
    setBilan(data || null);
    setDecalage(offset);
  }, [runId, t]);

  useEffect(() => { setMsg({ text: '', kind: '' }); charger(0); }, [charger]);

  async function confirmer() {
    setBusy(true);
    try {
      const { data, error } = await supabase.rpc('fn_import_confirmer_export_complet', { p_run_id: Number(runId) });
      if (error) throw error;
      assertRpcOk(data);
      setMsg({ text: t({ id: 'importacoes.retraits.confirmed' }), kind: 'ok' });
      await charger(0);
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setBusy(false); }
  }

  async function proposer() {
    setBusy(true);
    setMsg({ text: t({ id: 'importacoes.retraits.proposing' }), kind: 'info' });
    try {
      let total = null;
      for (let i = 0; i < APPELS_MAX; i += 1) {
        const { data, error } = await supabase.rpc('fn_import_proposer_retraits', { p_run_id: Number(runId) });
        if (error) throw error;
        total = cumulerPropositions(total, data);
        if (!(Number(data?.reste) > 0) || Number(data?.retraits || 0) + Number(data?.levees || 0) === 0) break;
      }
      setMsg({
        text: t({ id: 'importacoes.retraits.proposed' }, { retraits: total.retraits, levees: total.levees, lot: total.batch_id ?? '—' }),
        kind: total.retraits + total.levees > 0 ? 'ok' : 'info',
      });
      await charger(0);
      onChanged?.();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setBusy(false); }
  }

  if (erreur) {
    return <p className="imp-note" data-testid="run-retraits-error" style={{ margin: '0 0 12px' }}>{erreur}</p>;
  }
  if (!bilan) return null;

  const c = bilan.counts || {};
  const s = bilan.seuil || {};
  const nProposables = proposables(bilan);
  const items = Array.isArray(bilan.items) ? bilan.items : [];
  const totalListe = VERDICTS_RETRAITS.reduce((acc, v) => acc + Number(c[v] || 0), 0);
  const blocage = bilan.bloque_retraits;

  return (
    <div className="imp-sheet" style={{ marginBottom: 12 }} data-testid="run-retraits"
      data-bloque={blocage || ''} data-proposables={nProposables}>
      <div className="imp-sheet__body">
        <span className="ab-field__label" style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <AppIcon name="archive" size={14} />
          {t({ id: 'importacoes.retraits.title' })}
        </span>
        <p className="imp-note" style={{ margin: '4px 0 0' }} data-testid="run-retraits-export">
          {bilan.export_complet
            ? t({ id: 'importacoes.retraits.exportComplet' }, {
              date: bilan.export_complet_le ? formatDate(bilan.export_complet_le, { dateStyle: 'medium', timeStyle: 'short' }) : '—',
            })
            : t({ id: 'importacoes.retraits.exportNonDeclare' })}
        </p>
        {aDesConstats(bilan) && (
          <p className="imp-note" style={{ margin: '4px 0 0' }} data-testid="run-retraits-counts">
            {t({ id: 'importacoes.retraits.counts' }, {
              disparu: Number(c.disparu || 0), engage: Number(c.disparu_engage || 0),
              brouillon: Number(c.disparu_brouillon || 0), reapparu: Number(c.retire_reapparu || 0),
            })}
          </p>
        )}
        {Number(c.hors_fichier || 0) > 0 && (
          <p className="imp-note" style={{ margin: '2px 0 0', ...muted }} data-testid="run-retraits-hors-fichier">
            {t({ id: 'importacoes.retraits.horsFichier' }, { n: Number(c.hors_fichier) })}
          </p>
        )}
        {Number(s.disparus || 0) > 0 && (
          <p className="imp-note" style={{ margin: '2px 0 0' }} data-testid="run-retraits-seuil">
            {t({ id: s.atteint ? 'importacoes.retraits.seuilAtteint' : 'importacoes.retraits.seuil' }, {
              disparus: Number(s.disparus || 0), total: Number(s.total || 0), taux: s.taux ?? '—',
            })}
            {bilan.confirme && bilan.confirme_le
              ? <> {t({ id: 'importacoes.retraits.confirmedAt' }, { date: formatDate(bilan.confirme_le, { dateStyle: 'medium', timeStyle: 'short' }) })}</>
              : null}
          </p>
        )}
        {blocage && (
          <p className="imp-note" data-testid="run-retraits-blocage" data-blocage={blocage}
            style={{ margin: '6px 0 0', color: 'var(--brand-warning, #9a6700)', fontWeight: 600 }}>
            {t({ id: `importacoes.retraits.bloque.${blocage}` })}
          </p>
        )}
        {bilan.bloque_levees && bilan.bloque_levees !== blocage && (
          <p className="imp-note" style={{ margin: '2px 0 0', color: 'var(--brand-warning, #9a6700)' }}>
            {t({ id: `importacoes.retraits.bloque.${bilan.bloque_levees}` })}
          </p>
        )}
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 8 }}>
          {canAct && confirmationDemandee(bilan) && (
            <button type="button" className="cat-btn secondary" disabled={busy} onClick={confirmer} data-testid="run-retraits-confirmer">
              {t({ id: 'importacoes.retraits.confirm' })}
            </button>
          )}
          {canAct && (
            <button type="button" className="cat-btn" disabled={busy || nProposables === 0} onClick={proposer}
              data-testid="run-retraits-proposer" title={t({ id: 'importacoes.retraits.proposeHint' })}>
              {busy ? t({ id: 'importacoes.retraits.proposing' }) : t({ id: 'importacoes.retraits.propose' }, { n: nProposables })}
            </button>
          )}
        </div>
        {msg.text && (
          <p className="imp-note" data-testid="run-retraits-msg" data-kind={msg.kind}
            style={{ margin: '6px 0 0', color: msg.kind === 'error' ? 'var(--brand-danger, #b42318)' : undefined }}>{msg.text}</p>
        )}
        {items.length > 0 && (
          <div style={{ overflowX: 'auto', marginTop: 8 }}>
            <table style={{ borderCollapse: 'collapse', fontSize: '.76rem', width: '100%' }} data-testid="run-retraits-list">
              <thead><tr>
                <th style={cell}>{t({ id: 'recolement.col.tombo' })}</th>
                <th style={cell}>{t({ id: 'importacoes.retraits.col.code' })}</th>
                <th style={cell}>{t({ id: 'recolement.col.title' })}</th>
                <th style={cell}>{t({ id: 'importacoes.retraits.col.verdict' })}</th>
              </tr></thead>
              <tbody>
                {items.map((it) => {
                  const detail = cleDetail(it);
                  return (
                    <tr key={`${it.verdict}-${it.exemplar_id}`} data-verdict={it.verdict} data-exemplar={it.exemplar_id}>
                      <td style={cell}>{it.tombo || '—'}</td>
                      <td style={{ ...cell, fontFamily: 'monospace', overflowWrap: 'anywhere' }}>{it.code || it.expl_id || '—'}</td>
                      <td style={{ ...cell, overflowWrap: 'anywhere' }}>{it.titulo || '—'}</td>
                      <td style={cell}>
                        {t({ id: cleVerdict(it) })}
                        {detail ? <span style={muted}> · {t({ id: detail }, { id: it.draft_id })}</span> : null}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            {totalListe > PAGE_RETRAITS && (
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 6 }}>
                <button type="button" className="imp-linkbtn" disabled={busy || decalage === 0}
                  onClick={() => charger(Math.max(0, decalage - PAGE_RETRAITS))}>{t({ id: 'importacoes.retraits.prev' })}</button>
                <span className="imp-note">{t({ id: 'importacoes.retraits.page' }, {
                  from: decalage + 1, to: Math.min(decalage + PAGE_RETRAITS, totalListe), total: totalListe,
                })}</span>
                <button type="button" className="imp-linkbtn" disabled={busy || decalage + PAGE_RETRAITS >= totalListe}
                  onClick={() => charger(decalage + PAGE_RETRAITS)}>{t({ id: 'importacoes.retraits.next' })}</button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
