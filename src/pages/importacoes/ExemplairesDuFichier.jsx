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
// ═══════════════════════════════════════════════════════════
import { useIntl } from 'react-intl';
import AppIcon from '@/components/ui/AppIcon';
import { SIGNAUX, libelleVerdict } from '@/lib/importItemVerdicts.js';

const ICONE = {
  nouveau: 'sparkles', deja_la: 'check', deja_en_brouillon: 'penLine', sans_code: 'warning',
  deplace: 'arrowLeftRight', reetiquete: 'tags', code_repris: 'circleAlert',
};
const COULEUR = {
  nouveau: 'var(--brand-success, #4ade80)',
  deja_la: 'var(--brand-muted, #94a3b8)',
  deja_en_brouillon: 'var(--brand-info, #60a5fa)',
};

export default function ExemplairesDuFichier({ items, titreLigne }) {
  const { formatMessage: t } = useIntl();
  if (!Array.isArray(items) || items.length === 0) return null;
  return (
    <ul className="imp-items" data-testid="row-items"
      aria-label={t({ id: 'importacoes.items.title' }, { n: items.length })}
      style={{ listStyle: 'none', margin: '4px 0 0', padding: 0, fontSize: '.72rem' }}>
      {items.map((it) => (
        <li key={it.n ?? `${it.code}-${it.expl_id}`} data-verdict={it.verdict || ''}
          style={{ display: 'flex', gap: 6, alignItems: 'baseline', flexWrap: 'wrap', minWidth: 0,
                   color: COULEUR[it.verdict] || (SIGNAUX.includes(it.verdict) ? 'var(--brand-warning, #fbbf24)' : undefined) }}>
          <AppIcon name={ICONE[it.verdict] || 'package'} size={12} />
          <span style={{ fontFamily: 'monospace', overflowWrap: 'anywhere' }}>
            {it.code || t({ id: 'importacoes.items.noCode' })}
            {it.cote ? ` · ${it.cote}` : ''}
          </span>
          <span>{libelleVerdict(t, it, titreLigne)}</span>
        </li>
      ))}
    </ul>
  );
}
