// src/pages/catalogacao/ShelfLabelPreview.jsx — E6, lot 6 (28/09/2026)
// La prévia de cote / étiquette du formulaire de notice (palier 3), sortie de
// BookDraftForm.jsx sans en changer une ligne : pur affichage, calculé à chaque
// rendu depuis l'auteur, le titre et la CDD par `buildShelfLabel` (lib).
import { useIntl } from 'react-intl';
import { buildShelfLabel } from '@/lib/catalogacao/bookDraft';

export default function ShelfLabelPreview({ author, title, cdd }) {
  const { formatMessage: t } = useIntl();
  const label = buildShelfLabel({ author, title, cdd });
  return (
    <div style={{ gridColumn: 'span 3' }}>
      <div style={{
        padding: 14, borderRadius: 10,
        background: 'rgba(255,255,255,.03)',
        border: '1px solid var(--brand-panel-border, rgba(255,255,255,.08))',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8, flexWrap: 'wrap', gap: 6 }}>
          <h4 style={{ margin: 0, fontSize: '.85rem' }}>{t({id:'catalogacao.ui.labelPreview'})}</h4>
          <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)' }}>
            {t({id:'catalogacao.ui.labelPreviewHint'})}
          </span>
        </div>
        <div style={{
          display: 'flex', gap: 16, alignItems: 'center',
          padding: '12px 16px', borderRadius: 8,
          background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.06)',
        }}>
          <div style={{
            width: 64, height: 64, borderRadius: 8,
            background: 'var(--brand-color-primary, #7a0b14)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontWeight: 900, fontSize: '1.1rem', color: '#fff',
            letterSpacing: '.05em', flexShrink: 0,
          }}>
            {label?.authorCode || '---'}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: '.88rem', fontWeight: 700, marginBottom: 2 }}>
              {title || t({ id: 'catalogacao.ui.titleFallback' })}
            </div>
            <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>
              {t({id:'catalogacao.shelf.authorPrefix'})} {author || '—'}
            </div>
            <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>
              {t({id:'catalogacao.shelf.cddPrefix'})} {cdd || '—'}
            </div>
            <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #666)', marginTop: 3 }}>
              {label ? `${t({id:'catalogacao.shelf.cotePrefix'})} ${label.shelfLine} (${label.reasonCodes.map(c => t({ id: 'catalogacao.shelf.' + c })).join(' + ')})` : t({id:'catalogacao.ui.labelFillHint'})}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
