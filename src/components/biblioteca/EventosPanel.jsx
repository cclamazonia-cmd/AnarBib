import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

/**
 * EventosPanel — événements organisés par une bibliothèque.
 *
 * Onglet « Événements » de la page de gestion /biblioteca (réservé au
 * coordinateur, cf. coordOnly dans BibliotecaPage). Permet de créer, éditer,
 * annuler (annulation douce) et supprimer des lectures publiques, débats,
 * ateliers, rencontres, projections…
 *
 * Écriture directe sur public.library_events, la RLS (policies
 * library_events_*_same_library_team via user_can_act_as_staff_on_library)
 * garantissant qu'on n'agit que sur SA bibliothèque. Les événements publics et
 * à venir remontent côté lecteur dans le compte /conta via la RPC
 * api.fn_my_library_events (SECURITY DEFINER).
 */

const EVENT_TYPES = ['lecture_publique', 'debat', 'atelier', 'rencontre', 'projection', 'autre'];

const EMPTY_FORM = {
  id: null,
  title: '',
  event_type: 'lecture_publique',
  starts_at: '',
  ends_at: '',
  location: '',
  description: '',
  is_public: true,
};

// timestamptz (ISO UTC) → valeur d'un <input type="datetime-local"> (heure locale).
function toInputValue(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
// valeur d'un <input type="datetime-local"> (heure locale) → ISO UTC pour la DB.
function fromInputValue(local) {
  if (!local) return null;
  const d = new Date(local);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

export default function EventosPanel({ libraryId }) {
  const { formatMessage: t, locale } = useIntl();

  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [busyId, setBusyId] = useState(null);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  const dtFmt = new Intl.DateTimeFormat(locale, {
    dateStyle: 'medium', timeStyle: 'short',
  });

  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('library_events')
        .select('*')
        .eq('library_id', libraryId)
        .order('starts_at', { ascending: false });
      if (error) throw error;
      setEvents(data || []);
    } catch (err) {
      console.warn('EventosPanel load:', err);
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, t]);

  useEffect(() => { load(); }, [load]);

  const resetForm = () => { setForm(EMPTY_FORM); setMsg({ text: '', kind: '' }); };

  const startEdit = (ev) => {
    setForm({
      id: ev.id,
      title: ev.title || '',
      event_type: ev.event_type || 'autre',
      starts_at: toInputValue(ev.starts_at),
      ends_at: toInputValue(ev.ends_at),
      location: ev.location || '',
      description: ev.description || '',
      is_public: ev.is_public !== false,
    });
    setMsg({ text: '', kind: '' });
    if (typeof window !== 'undefined') window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  async function handleSave(e) {
    e.preventDefault();
    if (saving) return;
    const title = form.title.trim();
    if (!title) {
      setMsg({ text: t({ id: 'biblioteca.events.form.titleRequired' }), kind: 'error' });
      return;
    }
    const startsIso = fromInputValue(form.starts_at);
    if (!startsIso) {
      setMsg({ text: t({ id: 'biblioteca.events.form.startRequired' }), kind: 'error' });
      return;
    }
    const endsIso = fromInputValue(form.ends_at);
    if (endsIso && endsIso < startsIso) {
      setMsg({ text: t({ id: 'biblioteca.events.form.endBeforeStart' }), kind: 'error' });
      return;
    }
    setSaving(true);
    setMsg({ text: '', kind: '' });
    const payload = {
      library_id: libraryId,
      title,
      event_type: form.event_type,
      starts_at: startsIso,
      ends_at: endsIso,
      location: form.location.trim() || null,
      description: form.description.trim() || null,
      is_public: !!form.is_public,
    };
    try {
      let error;
      if (form.id) {
        ({ error } = await supabase.from('library_events').update(payload).eq('id', form.id));
      } else {
        ({ error } = await supabase.from('library_events').insert(payload));
      }
      if (error) throw error;
      setMsg({ text: t({ id: form.id ? 'biblioteca.events.updated' : 'biblioteca.events.created' }), kind: 'success' });
      resetForm();
      await load();
    } catch (err) {
      console.warn('EventosPanel save:', err);
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  async function toggleCancelled(ev) {
    if (busyId) return;
    setBusyId(ev.id);
    try {
      const { error } = await supabase
        .from('library_events')
        .update({ is_cancelled: !ev.is_cancelled })
        .eq('id', ev.id);
      if (error) throw error;
      await load();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setBusyId(null);
    }
  }

  async function handleDelete(ev) {
    if (busyId) return;
    if (!window.confirm(t({ id: 'biblioteca.events.deleteConfirm' }, { title: ev.title }))) return;
    setBusyId(ev.id);
    try {
      const { error } = await supabase.from('library_events').delete().eq('id', ev.id);
      if (error) throw error;
      if (form.id === ev.id) resetForm();
      await load();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setBusyId(null);
    }
  }

  const typeLabel = (key) => t({ id: `biblioteca.events.type.${key}`, defaultMessage: key });

  return (
    <div>
      <h3 style={{ marginBottom: 6 }}>{t({ id: 'biblioteca.events.title' })}</h3>
      <p style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 16 }}>
        {t({ id: 'biblioteca.events.hint' })}
      </p>

      {/* ── Formulaire création / édition ─────────────────────────────── */}
      <form onSubmit={handleSave} style={{ marginBottom: 24, padding: '16px', borderRadius: 10, border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))', background: 'var(--brand-panel-bg, rgba(255,255,255,.03))' }}>
        <h4 style={{ marginTop: 0, marginBottom: 12, fontSize: '.95rem' }}>
          {t({ id: form.id ? 'biblioteca.events.form.editTitle' : 'biblioteca.events.form.newTitle' })}
        </h4>

        <div style={{ display: 'grid', gap: 12 }}>
          <label style={{ display: 'grid', gap: 4 }}>
            <span style={{ fontSize: '.82rem' }}>{t({ id: 'biblioteca.events.form.eventTitle' })}</span>
            <input className="ab-input" type="text" value={form.title} maxLength={200}
              onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))} />
          </label>

          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            <label style={{ display: 'grid', gap: 4, flex: 1, minWidth: 160 }}>
              <span style={{ fontSize: '.82rem' }}>{t({ id: 'biblioteca.events.form.type' })}</span>
              <select className="ab-input" value={form.event_type}
                onChange={(e) => setForm((f) => ({ ...f, event_type: e.target.value }))}>
                {EVENT_TYPES.map((k) => <option key={k} value={k}>{typeLabel(k)}</option>)}
              </select>
            </label>
            <label style={{ display: 'grid', gap: 4, flex: 1, minWidth: 'min(200px, 100%)' }}>
              <span style={{ fontSize: '.82rem' }}>{t({ id: 'biblioteca.events.form.location' })}</span>
              <input className="ab-input" type="text" value={form.location} maxLength={300}
                placeholder={t({ id: 'biblioteca.events.form.locationPlaceholder' })}
                onChange={(e) => setForm((f) => ({ ...f, location: e.target.value }))} />
            </label>
          </div>

          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            <label style={{ display: 'grid', gap: 4, flex: 1, minWidth: 'min(200px, 100%)' }}>
              <span style={{ fontSize: '.82rem' }}>{t({ id: 'biblioteca.events.form.startsAt' })}</span>
              <input className="ab-input" type="datetime-local" value={form.starts_at}
                onChange={(e) => setForm((f) => ({ ...f, starts_at: e.target.value }))} />
            </label>
            <label style={{ display: 'grid', gap: 4, flex: 1, minWidth: 'min(200px, 100%)' }}>
              <span style={{ fontSize: '.82rem' }}>{t({ id: 'biblioteca.events.form.endsAt' })}</span>
              <input className="ab-input" type="datetime-local" value={form.ends_at}
                onChange={(e) => setForm((f) => ({ ...f, ends_at: e.target.value }))} />
            </label>
          </div>

          <label style={{ display: 'grid', gap: 4 }}>
            <span style={{ fontSize: '.82rem' }}>{t({ id: 'biblioteca.events.form.description' })}</span>
            <textarea className="ab-input" rows={3} value={form.description} maxLength={4000}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))} />
          </label>

          <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: '.85rem' }}>
            <input type="checkbox" checked={form.is_public}
              onChange={(e) => setForm((f) => ({ ...f, is_public: e.target.checked }))} />
            {t({ id: 'biblioteca.events.form.isPublic' })}
          </label>
        </div>

        <div style={{ display: 'flex', gap: 8, marginTop: 14, flexWrap: 'wrap' }}>
          <button type="submit" className="ab-button ab-button--secondary" disabled={saving}>
            {saving ? t({ id: 'common.loading' }) : t({ id: form.id ? 'biblioteca.events.form.saveEdit' : 'biblioteca.events.form.create' })}
          </button>
          {form.id && (
            <button type="button" className="ab-button ab-button--mini" disabled={saving} onClick={resetForm}>
              {t({ id: 'common.cancel' })}
            </button>
          )}
        </div>

        {msg.text && (
          <p style={{ marginTop: 10, fontSize: '.85rem', color: msg.kind === 'success' ? '#4ade80' : '#f87171' }}>
            {msg.text}
          </p>
        )}
      </form>

      {/* ── Liste des événements ──────────────────────────────────────── */}
      <h4 style={{ fontSize: '.95rem', marginBottom: 10 }}>{t({ id: 'biblioteca.events.listTitle' })}</h4>
      {loading ? (
        <p className="ab-conta-hint">{t({ id: 'common.loading' })}</p>
      ) : events.length === 0 ? (
        <p className="ab-conta-empty">{t({ id: 'biblioteca.events.empty' })}</p>
      ) : (
        <div className="ab-conta-items">
          {events.map((ev) => {
            const past = new Date(ev.starts_at).getTime() < Date.now();
            return (
              <div key={ev.id} className="ab-conta-item" style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'flex-start', opacity: ev.is_cancelled ? 0.6 : 1 }}>
                <div style={{ flex: 1, minWidth: 'min(220px, 100%)' }}>
                  <span className="ab-conta-item__title" style={{ textDecoration: ev.is_cancelled ? 'line-through' : 'none' }}>
                    {ev.title}
                  </span>
                  <span className="ab-conta-item__meta" style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 4 }}>
                    <span style={{ padding: '1px 8px', borderRadius: 999, background: 'rgba(255,255,255,.08)', fontSize: '.72rem' }}>
                      {typeLabel(ev.event_type)}
                    </span>
                    <span>{dtFmt.format(new Date(ev.starts_at))}</span>
                    {ev.location && <span>· {ev.location}</span>}
                  </span>
                  <span className="ab-conta-item__meta" style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 4 }}>
                    {!ev.is_public && <span style={{ color: '#fbbf24' }}>⚠ {t({ id: 'biblioteca.events.badge.draft' })}</span>}
                    {ev.is_cancelled && <span style={{ color: '#f87171' }}>{t({ id: 'biblioteca.events.badge.cancelled' })}</span>}
                    {past && !ev.is_cancelled && <span style={{ color: 'var(--brand-muted)' }}>{t({ id: 'biblioteca.events.badge.past' })}</span>}
                  </span>
                </div>
                <div style={{ display: 'flex', gap: 6, flexShrink: 0, flexWrap: 'wrap' }}>
                  <button type="button" className="ab-button ab-button--mini ab-button--secondary" disabled={busyId === ev.id} onClick={() => startEdit(ev)}>
                    {t({ id: 'common.edit' })}
                  </button>
                  <button type="button" className="ab-button ab-button--mini" disabled={busyId === ev.id} onClick={() => toggleCancelled(ev)}>
                    {t({ id: ev.is_cancelled ? 'biblioteca.events.reactivate' : 'biblioteca.events.cancel' })}
                  </button>
                  <button type="button" className="ab-button ab-button--mini ab-button--danger" disabled={busyId === ev.id} onClick={() => handleDelete(ev)}>
                    {t({ id: 'common.delete' })}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
