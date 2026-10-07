// ─────────────────────────────────────────────────────────────────────────────
// H21 lot 5 (07/10/2026, REGISTRE IMP-26 b/c, IMP-32) — le bandeau d'une notice
// PARTAGÉE qu'un réimport n'a pas réécrite : « Le fichier de <bibliothèque>
// diffère sur N champs », et le détail champ par champ (base de l'import
// précédent / AnarBib / fichier / verdict), avec les gestes de la coordination
// d'une détentrice :
//   - « Appliquer la sélection » : un brouillon de reprise PRÉREMPLI des seuls
//     champs cochés applicables (fn_divergences_appliquer), que l'écran ouvre
//     dans l'éditeur ; la détentrice relit et publie elle-même. Responsabilités
//     et champs vidés par la source : montrés, jamais préremplis ;
//   - « Écarter la sélection » / « Tout écarter » (fn_divergences_ecarter) : la
//     base avance pour ces champs seuls, la même valeur ne revient plus.
// La base juge seule (détention, coordination, brouillon déjà ouvert, notice
// changée) ; l'écran dit ce qu'elle a fait et ce qu'elle a ignoré.
// Rien ne s'affiche pour qui n'est ni coordination d'une détentrice ni
// administration du réseau (fn_notice_divergences rend alors une liste vide).
// ─────────────────────────────────────────────────────────────────────────────
import { useCallback, useEffect, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useConfirm } from '@/contexts/ConfirmContext';
import AppIcon from '@/components/ui/AppIcon';
import CatalogStatusBar from '@/components/catalog/CatalogStatusBar';
import { REGISTRY } from '@/pages/catalogacao/fieldRegistry.js';

const LIBELLE_CHAMP = {
  ...Object.fromEntries(REGISTRY.flatMap(g => (Array.isArray(g.fields) ? g.fields : []).map(f => [f.id, f.label]))),
  contributors: 'catalogacao.ui.contributors',
};

// L'ordre du message : ce qui demande une action d'abord.
export const RAISONS_ECARTER = ['perimee', 'pas_ouverte', 'non_partagee', 'pas_detentrice', 'introuvable'];
export const RAISONS_APPLIQUER = ['pas_ouverte', 'non_partagee', 'autre_notice'];

export function valeurDuChamp(v) {
  if (v == null || (Array.isArray(v) && v.length === 0)) return '∅';
  if (Array.isArray(v)) return v.map(x => (Array.isArray(x) ? `${x[0] ?? '?'}${x[1] ? ` (${x[1]})` : ''}` : String(x))).join(' ; ');
  const s = String(v);
  return s.length > 160 ? `${s.slice(0, 157)}…` : s;
}

export function messageEcarter(t, res) {
  const n = Number(res?.ecartees || 0);
  const ignorees = res?.skipped || {};
  const parties = [n > 0
    ? t({ id: 'catalogacao.divergences.dismissed' }, { n })
    : t({ id: 'catalogacao.divergences.dismissedNone' })];
  const liste = RAISONS_ECARTER.filter(k => Number(ignorees[k] || 0) > 0)
    .map(k => t({ id: `catalogacao.divergences.skip.${k}` }, { n: Number(ignorees[k]) }));
  if (liste.length) parties.push(t({ id: 'catalogacao.divergences.skipped' }, { list: liste.join(', ') }));
  return { text: parties.join(' '), kind: n > 0 ? (liste.length ? 'info' : 'ok') : 'error' };
}

export default function DivergencesNotice({ bookId, onOpenDraft, onChanged, defaultOpen = false }) {
  const { formatMessage: t } = useIntl();
  const confirmer = useConfirm();
  const [data, setData] = useState(null);
  const [ouvert, setOuvert] = useState(defaultOpen);
  const [choix, setChoix] = useState(() => new Set());
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  const charger = useCallback(async () => {
    if (!bookId) { setData(null); return; }
    try {
      const { data: d, error } = await supabase.rpc('fn_notice_divergences', { p_book_id: Number(bookId) });
      if (error) throw error;
      setData(d || null);
    } catch (e) {
      // le bandeau n'est qu'une information : une erreur de lecture ne bloque pas l'éditeur
      console.warn('fn_notice_divergences:', e?.message || e);
      setData(null);
    }
  }, [bookId]);

  useEffect(() => { setChoix(new Set()); setMsg({ text: '', kind: '' }); charger(); }, [charger]);

  const groupes = Array.isArray(data?.groupes) ? data.groupes.filter(Boolean) : [];
  if (groupes.length === 0) {
    return msg.text
      ? <div data-testid="divergences-msg"><CatalogStatusBar msg={msg} onClose={() => setMsg({ text: '', kind: '' })} /></div>
      : null;
  }
  const champs = groupes.flatMap(g => (Array.isArray(g.champs) ? g.champs : []));
  const brouillon = data?.draft || null;
  const peutAppliquer = !!data?.can_apply && !brouillon;
  const choisisApplicables = champs.filter(c => choix.has(c.id) && c.applicable);
  const libelle = (champ) => (LIBELLE_CHAMP[champ] ? t({ id: LIBELLE_CHAMP[champ] }) : champ);

  function basculer(id) {
    setChoix(prev => {
      const s = new Set(prev);
      if (s.has(id)) s.delete(id); else s.add(id);
      return s;
    });
  }

  async function ecarter(ids) {
    if (!ids.length) return;
    setBusy(true); setMsg({ text: '', kind: '' });
    try {
      const { data: res, error } = await supabase.rpc('fn_divergences_ecarter', { p_ids: ids.map(Number) });
      if (error) throw error;
      setMsg(messageEcarter(t, res));
      setChoix(new Set());
      await charger();
      onChanged?.();
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(false);
    }
  }

  async function toutEcarter() {
    const ok = await confirmer({
      message: t({ id: 'catalogacao.divergences.dismissAllConfirm' }, { n: champs.length }),
      confirmLabel: t({ id: 'catalogacao.divergences.dismissAll' }),
    });
    if (ok) await ecarter(champs.map(c => c.id));
  }

  async function appliquer() {
    if (!choisisApplicables.length) return;
    setBusy(true); setMsg({ text: '', kind: '' });
    try {
      const { data: res, error } = await supabase.rpc('fn_divergences_appliquer', {
        p_book_id: Number(bookId), p_ids: [...choix].map(Number),
      });
      if (error) throw error;
      setChoix(new Set());
      await charger();
      onChanged?.();
      if (res?.draft_id) {
        setMsg({ text: t({ id: 'catalogacao.divergences.applied' }, { id: res.draft_id }), kind: 'ok' });
        onOpenDraft?.(res.draft_id);
      }
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div data-testid="divergences-notice" className="cat-divergences" role="region"
      aria-label={t({ id: 'catalogacao.divergences.regionLabel' })}
      style={{ border: '1px solid rgba(245,158,11,.45)', background: 'rgba(245,158,11,.08)', borderRadius: 10,
               padding: '10px 12px', marginBottom: 14, minWidth: 0 }}>
      {groupes.map(g => (
        <div key={g.library_id} data-testid="divergences-banner" style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          <AppIcon name="warning" size="1.05em" />
          <strong>{t({ id: 'catalogacao.divergences.banner' }, { library: g.library_name || '—', n: Number(g.count || 0) })}</strong>
        </div>
      ))}
      <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #94a3b8)', marginTop: 4 }}>
        {t({ id: 'catalogacao.divergences.bannerHelp' })}
      </div>
      {brouillon && (
        <div data-testid="divergences-draft" style={{ marginTop: 6, fontSize: '.82rem' }}>
          {t({ id: 'catalogacao.divergences.draftOpen' }, { id: brouillon.id })}{' '}
          {onOpenDraft && (
            <button type="button" className="ab-button ab-button--secondary ab-button--sm"
              onClick={() => onOpenDraft(brouillon.id)}>
              {t({ id: 'catalogacao.divergences.openDraft' })}
            </button>
          )}
        </div>
      )}
      <div style={{ marginTop: 8 }}>
        <button type="button" className="ab-button ab-button--ghost ab-button--sm" aria-expanded={ouvert}
          data-testid="divergences-toggle" onClick={() => setOuvert(o => !o)}>
          {t({ id: ouvert ? 'catalogacao.divergences.hideDetail' : 'catalogacao.divergences.showDetail' })}
        </button>
      </div>
      {ouvert && (
        <div data-testid="divergences-detail" style={{ marginTop: 8, overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.8rem' }}>
            <thead>
              <tr style={{ textAlign: 'left' }}>
                <th scope="col" style={{ width: 28 }} aria-label={t({ id: 'catalogacao.divergences.col.select' })} />
                <th scope="col">{t({ id: 'catalogacao.divergences.col.field' })}</th>
                <th scope="col">{t({ id: 'catalogacao.divergences.col.base' })}</th>
                <th scope="col">{t({ id: 'catalogacao.divergences.col.anarbib' })}</th>
                <th scope="col">{t({ id: 'catalogacao.divergences.col.file' })}</th>
                <th scope="col">{t({ id: 'catalogacao.divergences.col.verdict' })}</th>
              </tr>
            </thead>
            <tbody>
              {groupes.map(g => (Array.isArray(g.champs) ? g.champs : []).map(c => (
                <tr key={c.id} data-champ={c.champ} data-verdict={c.verdict} style={{ borderTop: '1px solid rgba(255,255,255,.08)', verticalAlign: 'top' }}>
                  <td>
                    <input type="checkbox" checked={choix.has(c.id)} onChange={() => basculer(c.id)} disabled={busy}
                      aria-label={t({ id: 'catalogacao.divergences.selectField' }, { field: libelle(c.champ) })} />
                  </td>
                  <td>
                    <strong>{libelle(c.champ)}</strong>
                    {groupes.length > 1 && <div style={{ color: 'var(--brand-muted, #94a3b8)' }}>{g.library_name}</div>}
                    {!c.applicable && (
                      <div data-testid="divergences-shown-only" style={{ color: 'var(--brand-muted, #94a3b8)' }}>
                        {t({ id: c.raison === 'responsabilites' ? 'catalogacao.divergences.shownContributors' : 'catalogacao.divergences.shownErased' })}
                      </div>
                    )}
                  </td>
                  <td>{valeurDuChamp(c.b)}</td>
                  <td>{valeurDuChamp(c.a)}</td>
                  <td>{valeurDuChamp(c.n)}</td>
                  <td>{t({ id: `catalogacao.divergences.verdict.${c.verdict}` })}</td>
                </tr>
              )))}
            </tbody>
          </table>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 10 }}>
            <button type="button" className="ab-button ab-button--primary ab-button--sm" data-testid="divergences-apply"
              disabled={busy || !peutAppliquer || choisisApplicables.length === 0} onClick={appliquer}
              title={t({ id: 'catalogacao.divergences.applyTitle' })}>
              {t({ id: 'catalogacao.divergences.apply' }, { n: choisisApplicables.length })}
            </button>
            <button type="button" className="ab-button ab-button--secondary ab-button--sm" data-testid="divergences-dismiss"
              disabled={busy || choix.size === 0} onClick={() => ecarter([...choix])}
              title={t({ id: 'catalogacao.divergences.dismissTitle' })}>
              {t({ id: 'catalogacao.divergences.dismiss' }, { n: choix.size })}
            </button>
            <button type="button" className="ab-button ab-button--ghost ab-button--sm" data-testid="divergences-dismiss-all"
              disabled={busy} onClick={toutEcarter}>
              {t({ id: 'catalogacao.divergences.dismissAll' })}
            </button>
          </div>
          {!data?.can_apply && (
            <div data-testid="divergences-not-holder" style={{ fontSize: '.78rem', color: 'var(--brand-muted, #94a3b8)', marginTop: 6 }}>
              {t({ id: 'catalogacao.divergences.applyNeedsActiveHolder' })}
            </div>
          )}
        </div>
      )}
      {msg.text && (
        <div data-testid="divergences-msg" style={{ marginTop: 8 }}>
          <CatalogStatusBar msg={msg} onClose={() => setMsg({ text: '', kind: '' })} />
        </div>
      )}
    </div>
  );
}
