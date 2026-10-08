// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 6a (08/10/2026, REGISTRE IMP-33) : les exemplaires du
// fichier d'une ligne d'import et leur verdict.
//
// Lu dans fn_import_list_run_rows.exemplaires : le constat que la promotion ou
// « Rapprocher » a posé (ingest.fn_h21_constat_exemplaire), sinon la liste des
// exemplaires du fichier sans verdict. Un verdict par exemplaire :
//   nouveau            un brouillon a été (ou sera) créé ;
//   deja_la            déjà dans la bibliothèque, sur cette notice ;
//   deja_en_brouillon  un brouillon vivant le porte déjà ;
//   sans_code          sans code-barres : à ajouter à la main (IMP-33 b) ;
//   deplace            déplacé dans PMB vers cette notice — dans AnarBib, il
//                      est sur une autre : signalé, jamais déplacé (IMP-33 d) ;
//   reetiquete         réétiqueté dans PMB (ancien code → nouveau), même
//                      identifiant interne : signalé, jamais appliqué (IMP-33 a) ;
//   code_repris        le code est repris par un autre exemplaire PMB.
// Rien ne s'écrit ici : la liste est lue, le geste est à la main.
// H21 lot 6b (08/10/2026, IMP-33 c) : pour un exemplaire « déjà là », la cote
// et la note comparées à trois états (fn_import_list_run_rows.exemplaires_maj,
// prop `maj`) — les champs qui ont bougé, leur verdict (sans valeurs : le
// détail de la ligne les montre), et la mise à jour préparée ou publiée ;
// hors de vue, « masqué » ; un brouillon vivant ailleurs (empeche) est dit.
// ═══════════════════════════════════════════════════════════
import { useIntl } from 'react-intl';
import AppIcon from '@/components/ui/AppIcon';
import { SIGNAUX, libelleVerdict } from '@/lib/importItemVerdicts.js';
import { majDeLItem, champsQuiBougent } from '@/lib/importItemUpdates.js';

const ICONE = {
  nouveau: 'sparkles', deja_la: 'check', deja_en_brouillon: 'penLine', sans_code: 'warning',
  deplace: 'arrowLeftRight', reetiquete: 'tags', code_repris: 'circleAlert',
};
const COULEUR = {
  nouveau: 'var(--brand-success, #4ade80)',
  deja_la: 'var(--brand-muted, #94a3b8)',
  deja_en_brouillon: 'var(--brand-info, #60a5fa)',
};

export default function ExemplairesDuFichier({ items, titreLigne, maj = null }) {
  const { formatMessage: t } = useIntl();
  if (!Array.isArray(items) || items.length === 0) return null;
  return (
    <ul className="imp-items" data-testid="row-items"
      aria-label={t({ id: 'importacoes.items.title' }, { n: items.length })}
      style={{ listStyle: 'none', margin: '4px 0 0', padding: 0, fontSize: '.72rem' }}>
      {items.map((it) => {
        const m = majDeLItem(maj, it.n);
        const bougent = m ? champsQuiBougent(m.verdicts) : [];
        return (
          <li key={it.n ?? `${it.code}-${it.expl_id}`} data-verdict={it.verdict || ''}
            style={{ display: 'flex', gap: 6, alignItems: 'baseline', flexWrap: 'wrap', minWidth: 0,
                     color: COULEUR[it.verdict] || (SIGNAUX.includes(it.verdict) ? 'var(--brand-warning, #fbbf24)' : undefined) }}>
            <AppIcon name={ICONE[it.verdict] || 'package'} size={12} />
            <span style={{ fontFamily: 'monospace', overflowWrap: 'anywhere' }}>
              {it.code || t({ id: 'importacoes.items.noCode' })}
              {it.cote ? ` · ${it.cote}` : ''}
            </span>
            <span>{libelleVerdict(t, it, titreLigne)}</span>
            {bougent.length > 0 && (
              <span data-testid="row-item-update" data-item-update={bougent.map((c) => `${c.champ}:${c.verdict}`).join(' ')}
                style={{ color: 'var(--brand-info, #60a5fa)' }}>
                {bougent.map((c) => `${t({ id: `importacoes.items.field.${c.champ}` })} — ${c.verdict === 'masque'
                  ? t({ id: 'importacoes.fila.detail.itemFieldMasked' })
                  : t({ id: `review.report.updates.verdict.${c.verdict}` })}`).join(' · ')}
              </span>
            )}
            {m && m.draft_id && m.draft_status !== 'cancelled' && (
              <span data-testid="row-item-update-draft" style={{ color: 'var(--brand-info, #60a5fa)' }}>
                {t({ id: m.draft_status === 'published' ? 'importacoes.items.update.published' : 'importacoes.items.update.prepared' },
                  { id: m.draft_id })}
              </span>
            )}
            {/* (revue sceptique du 08/10) un brouillon vivant ailleurs : rien à préparer ici */}
            {m && m.empeche && !(m.draft_id && m.draft_status !== 'cancelled') && (
              <span data-testid="row-item-update-blocked" data-empeche={m.empeche} style={{ color: 'var(--brand-muted, #94a3b8)' }}>
                {t({ id: `importacoes.items.update.empeche.${m.empeche}` })}
              </span>
            )}
          </li>
        );
      })}
    </ul>
  );
}
