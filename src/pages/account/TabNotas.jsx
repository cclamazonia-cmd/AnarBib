import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';

// ═══════════════════════════════════════════════════════════
// AnarBib — l'onglet « Mes notes de lecture » de Mon compte (E6, AccountPage
// lot 3, 06/10/2026). Sorti d'AccountPage.jsx tel quel, lignes déplacées par
// script : les notes, le message, l'état d'édition et les deux écritures
// (saveReadingNote, deleteReadingNote) restent au parent — `saving` y sert
// aussi d'autres formulaires. Les props portent les noms du parent.
// ═══════════════════════════════════════════════════════════

export default function TabNotas({
  myReadingNotes, noteMsg, saving, editNoteId, setEditNoteId, editNoteBody, setEditNoteBody,
  saveReadingNote, deleteReadingNote,
}) {
  const { formatMessage: t } = useIntl();
  return (
    <div>
      <h2 className="ab-conta-section-title">{t({ id: 'account.readingNotes.title' })}</h2>
      <p className="ab-conta-hint">{t({ id: 'account.readingNotes.hint' })}</p>
      {noteMsg.text && (
        <div style={{ padding: '8px 12px', borderRadius: 8, fontSize: '.85rem', marginBottom: 12,
          background: noteMsg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)',
          color: noteMsg.kind === 'ok' ? '#4ade80' : '#f87171' }}>{noteMsg.text}</div>
      )}
      {myReadingNotes.length === 0 ? (
        <p className="ab-conta-empty">{t({ id: 'account.readingNotes.empty' })}</p>
      ) : (
        <div className="ab-conta-items">
          {myReadingNotes.map(n => (
            <div key={n.id} className="ab-conta-item" style={{ flexDirection: 'column', alignItems: 'stretch', gap: 6 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
                <Link to={`/obra/${n.work_id}`} className="ab-conta-item__title">
                  {n.works?.uniform_title || t({ id: 'account.readingNotes.workFallback' })}
                </Link>
                <span className="ab-conta-item__meta" style={{ fontSize: '.72rem' }}>
                  {(() => { try { return new Date(n.created_at).toLocaleDateString(undefined, { day: 'numeric', month: 'long', year: 'numeric' }); } catch { return ''; } })()}
                  {n.edited ? ` · ${t({ id: 'readingNotes.edited' })}` : ''}
                  {n.status === 'hidden' ? ` · ${t({ id: 'account.readingNotes.hidden' })}` : ''}
                </span>
              </div>
              {editNoteId === n.id ? (
                <div>
                  <textarea value={editNoteBody} maxLength={4000}
                    onChange={e => setEditNoteBody(e.target.value)}
                    style={{ width: '100%', minHeight: 90, padding: '8px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem', fontFamily: 'inherit', resize: 'vertical' }} />
                  <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                    <button type="button" className="ab-button ab-button--sm" disabled={saving || !editNoteBody.trim()}
                      onClick={() => saveReadingNote(n.id)}>{saving ? t({ id: 'common.saving' }) : t({ id: 'common.save' })}</button>
                    <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                      onClick={() => { setEditNoteId(null); setEditNoteBody(''); }}>{t({ id: 'common.cancel' })}</button>
                  </div>
                </div>
              ) : (
                <>
                  <div style={{ fontSize: '.88rem', lineHeight: 1.5, whiteSpace: 'pre-wrap' }}>{n.body}</div>
                  <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
                    <button type="button" className="ab-button ab-button--secondary ab-button--mini"
                      onClick={() => { setEditNoteId(n.id); setEditNoteBody(n.body); }}>{t({ id: 'common.edit' })}</button>
                    <button type="button" className="ab-button ab-button--danger ab-button--mini"
                      onClick={() => deleteReadingNote(n.id)} disabled={saving}>{t({ id: 'common.delete' })}</button>
                  </div>
                </>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
