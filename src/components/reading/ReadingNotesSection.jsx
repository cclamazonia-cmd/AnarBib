import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════════════════════
// ReadingNotesSection — notes de lecture partagees sur une ŒUVRE (works.id).
// Cadrage : docs/journal/cadrages/CADRAGE_notes_de_lecture_2026-08-01.md (Lot 2).
//
// - Lecture : notes 'published' du reseau (RLS -> visible aux comptes connectes).
// - Rediger : reserve aux lecteur·rices valide·es d'une biblio ayant active la
//   fonction ; le serveur (fn_my_reading_note_target) dit SI et SOUS QUELLE
//   biblio ecrire + pre-remplit le pseudonyme. Une note par personne et par
//   oeuvre (contrainte DB) -> si deja ecrite, on affiche l'edition/suppression.
// - Identite : pseudonyme choisi (pas le nom reel). Date seule (pas d'heure ->
//   pas de question de fuseau ici).
// ═══════════════════════════════════════════════════════════════════════════

const MAX_BODY = 4000;
const MAX_PSEUDO = 60;

export default function ReadingNotesSection({ workId }) {
  const { formatMessage: t, locale } = useIntl();
  const { user } = useAuth();

  const [notes, setNotes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [target, setTarget] = useState(null);      // { origin_library_id, suggested_pseudonym } | null
  const [form, setForm] = useState({ pseudonym: '', body: '' });
  const [editing, setEditing] = useState(false);   // edition de sa propre note
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await supabase.from('book_reading_notes')
        .select('id, author_pseudonym, body, language, created_at, edited, author_user_id, status')
        .eq('work_id', workId).eq('status', 'published')
        .order('created_at', { ascending: false });
      setNotes(Array.isArray(data) ? data : []);
    } finally { setLoading(false); }
  }, [workId]);

  useEffect(() => { load(); }, [load]);

  // Eligibilite d'ecriture (cote serveur : le flag reading_notes_enabled est
  // staff-only, on ne peut pas le lire directement).
  useEffect(() => {
    if (!user) { setTarget(null); return; }
    let alive = true;
    (async () => {
      try {
        const { data } = await supabase.rpc('fn_my_reading_note_target');
        const row = Array.isArray(data) ? data[0] : data;
        if (alive) setTarget(row?.origin_library_id ? row : null);
      } catch { if (alive) setTarget(null); }
    })();
    return () => { alive = false; };
  }, [user]);

  const myNote = user ? notes.find(n => n.author_user_id === user.id) : null;
  const canWrite = !!target && !myNote;

  // pre-remplissage du pseudonyme (dernier utilise), sans ecraser une saisie.
  useEffect(() => {
    if (target?.suggested_pseudonym) {
      setForm(f => (f.pseudonym ? f : { ...f, pseudonym: target.suggested_pseudonym }));
    }
  }, [target]);

  const fmtDate = (d) => {
    try { return new Date(d).toLocaleDateString(locale || undefined, { day: 'numeric', month: 'long', year: 'numeric' }); }
    catch { return ''; }
  };

  async function submitNew(e) {
    e?.preventDefault();
    const pseudonym = form.pseudonym.trim();
    const body = form.body.trim();
    if (!pseudonym || !body || !target) return;
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from('book_reading_notes').insert({
        work_id: workId,
        origin_library_id: target.origin_library_id,
        author_pseudonym: pseudonym,
        body,
        language: locale || null,
      });
      if (error) throw error;
      setForm(f => ({ ...f, body: '' }));
      setMsg({ text: t({ id: 'readingNotes.msg.published' }), kind: 'ok' });
      await load();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSaving(false); }
  }

  async function saveEdit(e) {
    e?.preventDefault();
    if (!myNote) return;
    const body = form.body.trim();
    if (!body) return;
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from('book_reading_notes')
        .update({ body, language: locale || null })
        .eq('id', myNote.id);
      if (error) throw error;
      setEditing(false);
      setMsg({ text: t({ id: 'readingNotes.msg.updated' }), kind: 'ok' });
      await load();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSaving(false); }
  }

  async function removeMine() {
    if (!myNote) return;
    if (!window.confirm(t({ id: 'readingNotes.confirm.delete' }))) return;
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.from('book_reading_notes').delete().eq('id', myNote.id);
      if (error) throw error;
      setMsg({ text: t({ id: 'readingNotes.msg.deleted' }), kind: 'ok' });
      await load();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSaving(false); }
  }

  const ta = { width: '100%', minHeight: 96, padding: '10px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.9rem', fontFamily: 'inherit', resize: 'vertical' };
  const inp = { ...ta, minHeight: 0, maxWidth: 280 };

  return (
    <section style={{ maxWidth: 1100, margin: '0 auto', padding: '8px 12px 28px' }}>
      <h2 style={{ fontSize: '1rem', margin: '18px 0 4px' }}>{t({ id: 'readingNotes.title' })}</h2>
      <p style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', margin: '0 0 14px' }}>
        {t({ id: 'readingNotes.intro' })}
      </p>

      {msg.text && (
        <div style={{ padding: '8px 12px', borderRadius: 8, fontSize: '.85rem', marginBottom: 12,
          background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)',
          color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>{msg.text}</div>
      )}

      {!user && (
        <div style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', fontStyle: 'italic' }}>
          {t({ id: 'readingNotes.anonHint' })}
        </div>
      )}

      {user && loading && (
        <div style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'common.loading' })}</div>
      )}

      {user && !loading && notes.length === 0 && (
        <div style={{ fontSize: '.85rem', color: 'var(--brand-muted, #888)', fontStyle: 'italic', marginBottom: 14 }}>
          {t({ id: 'readingNotes.empty' })}
        </div>
      )}

      {/* Liste des notes publiées */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 18 }}>
        {notes.map(n => {
          const mine = user && n.author_user_id === user.id;
          if (mine && editing) return null; // remplacé par le formulaire d'édition ci-dessous
          return (
            <div key={n.id} style={{ padding: '12px 14px', borderRadius: 10, border: `1px solid ${mine ? 'rgba(96,165,250,.35)' : 'rgba(255,255,255,.08)'}`, background: 'rgba(0,0,0,.15)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap', marginBottom: 6 }}>
                <span style={{ fontWeight: 600, fontSize: '.9rem' }}>
                  {n.author_pseudonym}
                  {mine && <span style={{ marginLeft: 8, fontSize: '.7rem', color: '#60a5fa' }}>{t({ id: 'readingNotes.you' })}</span>}
                </span>
                <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)' }}>
                  {fmtDate(n.created_at)}{n.edited ? ` · ${t({ id: 'readingNotes.edited' })}` : ''}
                </span>
              </div>
              <div style={{ fontSize: '.9rem', lineHeight: 1.5, whiteSpace: 'pre-wrap' }}>{n.body}</div>
              {mine && (
                <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                  <button type="button" className="ab-button ab-button--secondary ab-button--mini"
                    onClick={() => { setForm(f => ({ ...f, body: n.body })); setEditing(true); }}>
                    {t({ id: 'common.edit' })}
                  </button>
                  <button type="button" className="ab-button ab-button--danger ab-button--mini"
                    onClick={removeMine} disabled={saving}>
                    {t({ id: 'common.delete' })}
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Édition de sa propre note */}
      {myNote && editing && (
        <form onSubmit={saveEdit} style={{ marginBottom: 18, padding: 14, borderRadius: 10, border: '1px solid rgba(96,165,250,.35)', background: 'rgba(29,78,216,.06)' }}>
          <div style={{ fontSize: '.85rem', fontWeight: 600, marginBottom: 8 }}>{t({ id: 'readingNotes.editTitle' })}</div>
          <textarea style={ta} maxLength={MAX_BODY} value={form.body}
            onChange={e => setForm(f => ({ ...f, body: e.target.value }))} />
          <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
            <button type="submit" className="ab-button ab-button--sm" disabled={saving || !form.body.trim()}>
              {saving ? t({ id: 'common.saving' }) : t({ id: 'common.save' })}
            </button>
            <button type="button" className="ab-button ab-button--secondary ab-button--sm"
              onClick={() => { setEditing(false); setForm(f => ({ ...f, body: '' })); }}>
              {t({ id: 'common.cancel' })}
            </button>
          </div>
        </form>
      )}

      {/* Rédaction d'une nouvelle note */}
      {canWrite && (
        <form onSubmit={submitNew} style={{ padding: 14, borderRadius: 10, border: '1px solid rgba(21,128,61,.25)', background: 'rgba(21,128,61,.05)' }}>
          <div style={{ fontSize: '.85rem', fontWeight: 600, marginBottom: 10 }}>{t({ id: 'readingNotes.writeTitle' })}</div>
          <label style={{ display: 'block', fontSize: '.76rem', color: 'var(--brand-muted, #bbb)', marginBottom: 4 }}>
            {t({ id: 'readingNotes.pseudonymLabel' })}
          </label>
          <input type="text" style={inp} maxLength={MAX_PSEUDO} value={form.pseudonym}
            placeholder={t({ id: 'readingNotes.pseudonymPlaceholder' })}
            onChange={e => setForm(f => ({ ...f, pseudonym: e.target.value }))} />
          <label style={{ display: 'block', fontSize: '.76rem', color: 'var(--brand-muted, #bbb)', margin: '10px 0 4px' }}>
            {t({ id: 'readingNotes.bodyLabel' })}
          </label>
          <textarea style={ta} maxLength={MAX_BODY} value={form.body}
            placeholder={t({ id: 'readingNotes.bodyPlaceholder' })}
            onChange={e => setForm(f => ({ ...f, body: e.target.value }))} />
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
            <span style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
              {t({ id: 'readingNotes.pseudonymHint' })}
            </span>
            <button type="submit" className="ab-button ab-button--sm"
              disabled={saving || !form.pseudonym.trim() || !form.body.trim()}>
              {saving ? t({ id: 'common.saving' }) : t({ id: 'readingNotes.publish' })}
            </button>
          </div>
        </form>
      )}

      {/* Connecté mais pas éligible (biblio n'a pas activé, ou pas validé) */}
      {user && !target && !myNote && !loading && (
        <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #888)', fontStyle: 'italic' }}>
          {t({ id: 'readingNotes.notEligibleHint' })}
        </div>
      )}
    </section>
  );
}
