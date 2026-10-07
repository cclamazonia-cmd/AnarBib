// ─────────────────────────────────────────────────────────────────────────────
// H21 lot 5 (07/10/2026, REGISTRE IMP-26 b, IMP-32 a) — « Divergences à
// traiter » : les notices PARTAGÉES qu'un réimport a trouvées différentes et
// qu'il n'a pas réécrites, pour la coordination de chaque bibliothèque qui les
// détient (l'administration du réseau voit tout). Une ligne par notice et
// bibliothèque qui importe (titre, référence, bibliothèque, champs) ; « Voir »
// déplie le bandeau de la notice (DivergencesNotice : détail champ par champ,
// Appliquer / Écarter / Tout écarter). fn_divergences_a_traiter, par pages.
// Tous les panneaux du catalogage restent montés : on ne charge qu'à
// l'ouverture (isActive), et le total remonte pour la pastille de l'onglet.
// ─────────────────────────────────────────────────────────────────────────────
import { useCallback, useEffect, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import CatalogStatusBar from '@/components/catalog/CatalogStatusBar';
import DivergencesNotice from '@/components/catalog/DivergencesNotice';
import { REGISTRY } from './fieldRegistry.js';

const PAGE = 50;
const LIBELLE_CHAMP = {
  ...Object.fromEntries(REGISTRY.flatMap(g => (Array.isArray(g.fields) ? g.fields : []).map(f => [f.id, f.label]))),
  contributors: 'catalogacao.ui.contributors',
};

export default function DivergencesPanel({ isActive = true, onOpenDraft, onCount }) {
  const { formatMessage: t } = useIntl();
  const [page, setPage] = useState(0);
  const [etat, setEtat] = useState({ charge: false, total: 0, notices: [] });
  const [ouverte, setOuverte] = useState(null);   // clé « notice:bibliothèque » dépliée
  const [msg, setMsg] = useState({ text: '', kind: '' });

  const charger = useCallback(async () => {
    setEtat(e => ({ ...e, charge: true }));
    try {
      const { data, error } = await supabase.rpc('fn_divergences_a_traiter', {
        p_library_id: null, p_limit: PAGE, p_offset: page * PAGE,
      });
      if (error) throw error;
      const total = Number(data?.total || 0);
      setEtat({ charge: false, total, notices: Array.isArray(data?.notices) ? data.notices.filter(Boolean) : [] });
      onCount?.(total);
    } catch (e) {
      setEtat({ charge: false, total: 0, notices: [] });
      setMsg({ text: localizeError(e, t), kind: 'error' });
    }
  }, [page, t, onCount]);

  useEffect(() => { if (isActive) charger(); }, [isActive, charger]);

  const libelle = (champ) => (LIBELLE_CHAMP[champ] ? t({ id: LIBELLE_CHAMP[champ] }) : champ);
  const pages = Math.max(1, Math.ceil(etat.total / PAGE));

  return (
    <div data-testid="divergences-panel">
      <div className="cat-panel-header">
        <h3>{t({ id: 'catalogacao.divergences.title' })}</h3>
      </div>
      <CatalogStatusBar msg={msg} onClose={() => setMsg({ text: '', kind: '' })} />
      <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #94a3b8)', marginTop: 0 }}>
        {t({ id: 'catalogacao.divergences.intro' })}
      </p>
      {etat.charge && <div style={{ fontSize: '.85rem' }}>{t({ id: 'catalogacao.divergences.loading' })}</div>}
      {!etat.charge && etat.notices.length === 0 && (
        <div data-testid="divergences-empty" style={{ fontSize: '.85rem', color: 'var(--brand-muted, #94a3b8)' }}>
          {t({ id: 'catalogacao.divergences.empty' })}
        </div>
      )}
      {etat.notices.length > 0 && (
        <div data-testid="divergences-count" style={{ fontSize: '.85rem', marginBottom: 8 }}>
          {t({ id: 'catalogacao.divergences.count' }, { n: etat.total })}
        </div>
      )}
      {etat.notices.map((n, i) => {
        const cle = `${n.book_id}:${n.library_id}`;
        const champs = Array.isArray(n.champs) ? n.champs : [];
        return (
          <div key={cle} data-testid="divergences-row" style={{
            padding: '10px 12px', borderBottom: '1px solid rgba(255,255,255,.06)', minWidth: 0,
            background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
          }}>
            <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', flexWrap: 'wrap' }}>
              <div style={{ flex: '1 1 240px', minWidth: 0 }}>
                <div style={{ fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {n.titulo || t({ id: 'catalogacao.queue.noTitle' })}
                </div>
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #94a3b8)' }}>
                  {n.bib_ref && <>ref. {n.bib_ref} · </>}
                  {t({ id: 'catalogacao.divergences.fromLibrary' }, { library: n.library_name || '—' })}
                </div>
                <div style={{ fontSize: '.8rem', marginTop: 2 }}>
                  {t({ id: 'catalogacao.divergences.fields' }, { n: Number(n.count || champs.length), list: champs.map(c => libelle(c.champ)).join(', ') })}
                </div>
                {n.draft_id && (
                  <div style={{ fontSize: '.78rem', marginTop: 2 }}>{t({ id: 'catalogacao.divergences.draftOpen' }, { id: n.draft_id })}</div>
                )}
              </div>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm" aria-expanded={ouverte === cle}
                onClick={() => setOuverte(o => (o === cle ? null : cle))}>
                {t({ id: ouverte === cle ? 'catalogacao.divergences.hideDetail' : 'catalogacao.divergences.view' })}
              </button>
            </div>
            {ouverte === cle && (
              <div style={{ marginTop: 10 }}>
                <DivergencesNotice bookId={n.book_id} defaultOpen onOpenDraft={onOpenDraft} onChanged={charger} />
              </div>
            )}
          </div>
        );
      })}
      {etat.total > PAGE && (
        <div style={{ display: 'flex', gap: 8, justifyContent: 'center', alignItems: 'center', marginTop: 10 }}>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" disabled={page === 0}
            onClick={() => setPage(p => Math.max(0, p - 1))}>{t({ id: 'catalogacao.catalog.prevPage' })}</button>
          <span style={{ fontSize: '.85rem' }}>{page + 1} / {pages}</span>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" disabled={page + 1 >= pages}
            onClick={() => setPage(p => p + 1)}>{t({ id: 'catalogacao.catalog.nextPage' })}</button>
        </div>
      )}
    </div>
  );
}
