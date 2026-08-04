import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════════════════════
// ReadingNotesModeration — moderation A POSTERIORI des notes de lecture, cote
// staff de la biblio D'ORIGINE (Lot 3 du CADRAGE_notes_de_lecture_2026-08-01).
// - File des signalements en attente (masquer la note / ignorer le signalement).
// - Liste des notes deja masquees (retablir).
// RLS : le staff ne voit/agit que sur les notes de SA biblio (origin_library_id).
// ═══════════════════════════════════════════════════════════════════════════

export default function ReadingNotesModeration({ libraryId }) {
  const { formatMessage: t, locale } = useIntl();
  const { user } = useAuth();
  const [reports, setReports] = useState([]);
  const [hidden, setHidden] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      const [rep, hid] = await Promise.all([
        // Signalements non resolus (RLS -> uniquement ceux des notes de ma biblio).
        supabase.from('book_reading_note_reports')
          .select('id, reason, created_at, note:note_id(id, work_id, author_pseudonym, body, status, origin_library_id)')
          .is('resolved_at', null)
          .order('created_at', { ascending: true }),
        // Notes deja masquees de ma biblio (pour retablir).
        supabase.from('book_reading_notes')
          .select('id, work_id, author_pseudonym, body, status, hidden_at')
          .eq('origin_library_id', libraryId).eq('status', 'hidden')
          .order('hidden_at', { ascending: false }),
      ]);
      // Ne garder que les signalements dont la note releve bien de ma biblio.
      setReports((rep.data || []).filter(r => r.note && r.note.origin_library_id === libraryId));
      setHidden(hid.data || []);
    } finally { setLoading(false); }
  }, [libraryId]);

  useEffect(() => { load(); }, [load]);

  const fmtDate = (d) => { try { return new Date(d).toLocaleDateString(locale || undefined, { day: 'numeric', month: 'short', year: 'numeric' }); } catch { return ''; } };

  async function setNoteStatus(noteId, status) {
    const { error } = await supabase.from('book_reading_notes').update({ status }).eq('id', noteId);
    if (error) throw error;
  }
  async function resolveReport(reportId) {
    const { error } = await supabase.from('book_reading_note_reports')
      .update({ resolved_at: new Date().toISOString(), resolved_by: user?.id || null })
      .eq('id', reportId);
    if (error) throw error;
  }

  async function hideFromReport(report) {
    setBusy(true); setMsg({ text: '', kind: '' });
    try {
      await setNoteStatus(report.note.id, 'hidden');
      await resolveReport(report.id);
      setMsg({ text: t({ id: 'biblioteca.readingNotes.noteHidden' }), kind: 'ok' });
      await load();
    } catch (err) { setMsg({ text: localizeError(err, t), kind: 'error' }); }
    finally { setBusy(false); }
  }
  async function ignoreReport(report) {
    setBusy(true); setMsg({ text: '', kind: '' });
    try {
      await resolveReport(report.id);
      setMsg({ text: t({ id: 'biblioteca.readingNotes.reportResolved' }), kind: 'ok' });
      await load();
    } catch (err) { setMsg({ text: localizeError(err, t), kind: 'error' }); }
    finally { setBusy(false); }
  }
  async function unhide(noteId) {
    setBusy(true); setMsg({ text: '', kind: '' });
    try {
      await setNoteStatus(noteId, 'published');
      setMsg({ text: t({ id: 'biblioteca.readingNotes.noteRestored' }), kind: 'ok' });
      await load();
    } catch (err) { setMsg({ text: localizeError(err, t), kind: 'error' }); }
    finally { setBusy(false); }
  }

  const noteBox = (n, extra) => (
    <div style={{ padding: '10px 12px', borderRadius: 8, background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.08)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap', marginBottom: 4 }}>
        <span style={{ fontWeight: 600, fontSize: '.85rem' }}>{n.author_pseudonym}</span>
        <Link to={`/obra/${n.work_id}`} style={{ fontSize: '.74rem' }}>{t({ id: 'biblioteca.readingNotes.viewWork' })}</Link>
      </div>
      <div style={{ fontSize: '.85rem', lineHeight: 1.45, whiteSpace: 'pre-wrap', color: 'var(--brand-text, #eee)' }}>{n.body}</div>
      {extra}
    </div>
  );

  return (
    <div>
      <h3 style={{ margin: '0 0 4px' }}>{t({ id: 'biblioteca.readingNotes.modTitle' })}</h3>
      <p className="ab-conta-hint" style={{ marginTop: 0 }}>{t({ id: 'biblioteca.readingNotes.modIntro' })}</p>

      {msg.text && (
        <div style={{ padding: '8px 12px', borderRadius: 8, fontSize: '.85rem', margin: '8px 0 12px',
          background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)',
          color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>{msg.text}</div>
      )}

      {loading ? <p className="ab-conta-hint">{t({ id: 'common.loading' })}</p> : (
        <>
          {/* Signalements en attente */}
          <h4 style={{ margin: '14px 0 8px', fontSize: '.9rem' }}>
            {t({ id: 'biblioteca.readingNotes.reportsPending' })} ({reports.length})
          </h4>
          {reports.length === 0 ? (
            <p className="ab-conta-empty">{t({ id: 'biblioteca.readingNotes.noReports' })}</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {reports.map(r => noteBox(r.note, (
                <div>
                  {r.reason && (
                    <div style={{ fontSize: '.78rem', color: '#fbbf24', marginTop: 6 }}>
                      {t({ id: 'biblioteca.readingNotes.reportReason' })} {r.reason}
                    </div>
                  )}
                  <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>{fmtDate(r.created_at)}</div>
                  <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                    {r.note.status !== 'hidden' && (
                      <button type="button" className="ab-button ab-button--danger ab-button--mini" disabled={busy} onClick={() => hideFromReport(r)}>
                        {t({ id: 'biblioteca.readingNotes.hideNote' })}
                      </button>
                    )}
                    <button type="button" className="ab-button ab-button--secondary ab-button--mini" disabled={busy} onClick={() => ignoreReport(r)}>
                      {t({ id: 'biblioteca.readingNotes.ignoreReport' })}
                    </button>
                  </div>
                </div>
              )))}
            </div>
          )}

          {/* Notes masquees */}
          <h4 style={{ margin: '20px 0 8px', fontSize: '.9rem' }}>
            {t({ id: 'biblioteca.readingNotes.hiddenNotes' })} ({hidden.length})
          </h4>
          {hidden.length === 0 ? (
            <p className="ab-conta-empty">{t({ id: 'biblioteca.readingNotes.noHidden' })}</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {hidden.map(n => noteBox(n, (
                <div style={{ marginTop: 8 }}>
                  <button type="button" className="ab-button ab-button--secondary ab-button--mini" disabled={busy} onClick={() => unhide(n.id)}>
                    {t({ id: 'biblioteca.readingNotes.unhide' })}
                  </button>
                </div>
              )))}
            </div>
          )}
        </>
      )}
    </div>
  );
}
