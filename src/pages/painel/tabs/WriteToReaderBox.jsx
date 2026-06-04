import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui';

// =============================================================================
// WriteToReaderBox -- composer « ecrire au lecteur » (reciproque biblio -> reader)
// -----------------------------------------------------------------------------
// Self-contained : etat local + appel api.send_message_to_reader (calque du
// pattern inline des blocs restriction/gel de TabLeitor). Mail-only (pas
// d'inbox in-app cette manche). Visible pour tout staff ; la RLS INSERT
// (user_has_library_staff_role + recipient membre actif) gate cote DB.
// =============================================================================
export default function WriteToReaderBox({ t, libraryId, reader }) {
  const [open, setOpen] = useState(false);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [msgErr, setMsgErr] = useState(false);

  if (!reader?.id || !libraryId) return null;

  const canSend = body.trim().length >= 1 && !busy;

  async function send() {
    const b = body.trim();
    if (b.length < 1) { setMsgErr(true); setMsg(t({ id: 'panel.reader.write.errorEmpty' })); return; }
    if (b.length > 4000) { setMsgErr(true); setMsg(t({ id: 'panel.reader.write.errorTooLong' })); return; }
    setBusy(true); setMsg(''); setMsgErr(false);
    try {
      const { error } = await supabase.schema('api').rpc('send_message_to_reader', {
        p_library_id: libraryId,
        p_reader_id: reader.id,
        p_subject: subject.trim() || null,
        p_body: b,
      });
      if (error) {
        const m = (error.message || '').toLowerCase();
        const id = m.includes('empty_body') ? 'panel.reader.write.errorEmpty'
          : m.includes('body_too_long') ? 'panel.reader.write.errorTooLong'
          : m.includes('rate_limited') ? 'panel.reader.write.errorRate'
          : 'panel.reader.write.errorGeneric';
        setMsgErr(true); setMsg(t({ id }));
        return;
      }
      setSubject(''); setBody(''); setOpen(false);
      setMsgErr(false); setMsg(t({ id: 'panel.reader.write.success' }));
    } catch {
      setMsgErr(true); setMsg(t({ id: 'panel.reader.write.errorGeneric' }));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ margin: '12px 0' }}>
      {!open ? (
        <Button onClick={() => { setOpen(true); setMsg(''); }}>
          {t({ id: 'panel.reader.write.button' })}
        </Button>
      ) : (
        <div>
          <input
            type="text"
            className="ab-painel-input"
            value={subject}
            onChange={e => setSubject(e.target.value)}
            placeholder={t({ id: 'panel.reader.write.subjectPlaceholder' })}
            maxLength={200}
          />
          <textarea
            className="ab-painel-input"
            style={{ marginTop: 8, minHeight: 96, resize: 'vertical' }}
            value={body}
            onChange={e => setBody(e.target.value)}
            placeholder={t({ id: 'panel.reader.write.bodyPlaceholder' })}
            maxLength={4000}
            rows={5}
          />
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted)', textAlign: 'right', marginTop: 4 }}>
            {body.length} / 4000
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            <Button onClick={send} disabled={!canSend}>
              {busy ? t({ id: 'panel.reader.write.sending' }) : t({ id: 'panel.reader.write.send' })}
            </Button>
            <Button variant="secondary" onClick={() => { setOpen(false); setMsg(''); }} disabled={busy}>
              {t({ id: 'panel.reader.write.cancel' })}
            </Button>
          </div>
        </div>
      )}
      {msg && (
        <p className="ab-painel-msg" style={{ color: msgErr ? '#fca5a5' : '#86efac' }}>{msg}</p>
      )}
    </div>
  );
}
