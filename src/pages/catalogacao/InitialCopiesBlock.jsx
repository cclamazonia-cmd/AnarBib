// src/pages/catalogacao/InitialCopiesBlock.jsx — E6, lot 6 (28/09/2026)
// Le bloc « exemplaires initiaux » d'une fiche non encore publiée, sorti de
// BookDraftForm.jsx sans en changer une ligne : le nombre d'exemplaires à créer
// à la publication et, pour l'administration du réseau, la bibliothèque qui les
// reçoit ; ou le rappel qu'un import les a déjà fournis. Le bloc n'écrit pas le
// formulaire : chaque saisie remonte par `onChange(champ, valeur)`, câblé sur
// `set` du parent. Le parent décide de l'afficher (fiche non publiée).
import { useIntl } from 'react-intl';

export default function InitialCopiesBlock({ importedItems, copies, libraryIdValue, isNetworkAdmin, libraries, onChange }) {
  const { formatMessage: t } = useIntl();
  return (
    <div style={{ marginTop: 16, padding: 12, borderRadius: 10, background: 'rgba(29,78,216,.06)', border: '1px solid rgba(29,78,216,.15)' }}>
      <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 8 }}>{t({ id: 'catalogacao.publish.copiesTitle' })}</div>
      {importedItems > 0 ? (
        <div data-testid="copies-imported" style={{ fontSize: '.8rem' }}>
          {t({ id: 'catalogacao.publish.copiesImported' }, { n: importedItems })}
        </div>
      ) : (
      <div className="cat-book-grid">
        <div className="cat-field">
          <label>{t({ id: 'catalogacao.publish.copiesLabel' })}</label>
          <input type="number" min="1" max="50" value={copies}
            onChange={e => onChange('initial_copies', e.target.value)}
            style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
          <div style={{ fontSize: '.7rem', color: 'var(--brand-muted,#888)', marginTop: 2 }}>{t({ id: 'catalogacao.publish.copiesHint' })}</div>
        </div>
        {isNetworkAdmin && (
          <div className="cat-field" style={{ gridColumn: 'span 2' }}>
            <label>{t({ id: 'catalogacao.publish.copiesLibrary' })}</label>
            <select value={libraryIdValue} onChange={e => onChange('initial_copies_library_id', e.target.value)}
              style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
              <option value="">{t({ id: 'catalogacao.publish.copiesLibraryDefault' })}</option>
              {libraries.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
            </select>
          </div>
        )}
      </div>
      )}
    </div>
  );
}
