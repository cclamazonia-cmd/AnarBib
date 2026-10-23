// Pop-up de création d'une notice : œuvre nouvelle, ou nouvelle édition d'une
// œuvre existante (recherche d'éditions).
// Sorti de BookDraftForm.jsx tel quel (E6, 23/10/2026), avec l'état et les
// actions qu'il est seul à lire (calculés par @babel/traverse).
// Garde : src/tests/notice-sections-montees.test.jsx.
import { useIntl } from 'react-intl';
import Modal from '@/components/ui/Modal';

export default function BookCreationChoice(p) {
  const { formatMessage: t } = useIntl();
  const {
    creationChoice, editingId, editionQuery, editionResults, editionSearching, f, panelActive,
    prefillRecord, selectEditionAsWork, set, setCreationChoice, setEditionQuery, setLinkedWorkLabel,
  } = p;

  return (
    <Modal
          isOpen={panelActive && creationChoice === null && !f('id') && !f('published_book_id') && !editingId && !prefillRecord}
          onClose={() => setCreationChoice('work')}
          title={t({ id: 'catalogacao.create.title' })}
          size="medium"
        >
          <p style={{ margin: '0 0 12px', fontSize: '.9rem' }}>{t({ id: 'catalogacao.create.question' })}</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <button type="button" className="ab-button" style={{ textAlign: 'left', display: 'block' }}
              onClick={() => { set('work_id', ''); setLinkedWorkLabel(''); setCreationChoice('work'); }}>
              <div style={{ fontWeight: 700 }}>{t({ id: 'catalogacao.create.newWork' })}</div>
              <div style={{ fontSize: '.72rem', opacity: .85 }}>{t({ id: 'catalogacao.create.newWorkDesc' })}</div>
            </button>
            <div style={{ padding: 10, borderRadius: 8, border: '1px solid rgba(255,255,255,.12)' }}>
              <div style={{ fontWeight: 700, fontSize: '.85rem' }}>{t({ id: 'catalogacao.create.newEdition' })}</div>
              <div style={{ fontSize: '.72rem', opacity: .85, marginBottom: 6 }}>{t({ id: 'catalogacao.create.newEditionDesc' })}</div>
              <input type="text" value={editionQuery} onChange={e => setEditionQuery(e.target.value)}
                placeholder={t({ id: 'catalogacao.create.searchEdition' })}
                style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
              {editionQuery.trim().length >= 3 && (
                <div style={{ marginTop: 4, maxHeight: 220, overflowY: 'auto', border: '1px solid rgba(255,255,255,.1)', borderRadius: 6 }}>
                  {editionSearching && <div style={{ padding: '8px 12px', fontSize: '.74rem', color: 'var(--brand-muted,#999)' }}>{t({ id: 'common.searching' })}</div>}
                  {!editionSearching && editionResults.length === 0 && <div style={{ padding: '8px 12px', fontSize: '.74rem', color: 'var(--brand-muted,#999)' }}>{t({ id: 'catalogacao.create.noEditionFound' })}</div>}
                  {editionResults.map(bk => (
                    <button type="button" key={bk.id} onClick={() => selectEditionAsWork(bk)}
                      style={{ display: 'block', width: '100%', textAlign: 'left', padding: '8px 12px', background: 'none', border: 'none', borderBottom: '1px solid rgba(255,255,255,.06)', cursor: 'pointer', color: 'inherit' }}>
                      <div style={{ fontSize: '.8rem', fontWeight: 700 }}>{bk.titulo}{bk.ano ? ` (${bk.ano})` : ''}</div>
                      <div style={{ fontSize: '.7rem', color: 'var(--brand-muted,#aaa)' }}>{[bk.autor, bk.edicao, bk.editora, bk.bib_ref ? `ref. ${bk.bib_ref}` : ''].filter(Boolean).join(' · ')}</div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </Modal>
  );
}
