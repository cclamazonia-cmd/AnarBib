import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { Button } from '@/components/ui';

// WorksWorkshopPanel — la file des ŒUVRES de l'Atelier (05/09/2026).
//
// Deux choses, dans cet ordre : la file « corrige-moi » (titres d'œuvre
// pré-traduits jamais relus, par langue) et le formulaire des cinq types de
// proposition sur une œuvre (titre, fusion, rattachement, scission, tomes).
// La liste des propositions, elle, est celle de la page (même moteur).
//
// Le staff valide ou corrige un titre directement (api.fn_work_title_validate) ;
// un·e contributeur·rice le propose (kind « titre »), et la bibliothèque qui
// détient une édition a sept jours pour objecter.

const LANGS = ['pt-BR', 'fr', 'es', 'it', 'en', 'de', 'ca', 'eo', 'nl', 'el'];
const KINDS = ['titre', 'fusion', 'rattachement', 'scission', 'tomes'];
const PART_VIDE = { uniform_title: '', book_ids: '' };
const FORM_VIDE = {
  kind: 'titre', workId: '', workLabel: '', lang: 'fr', title: '', mergeIntoId: '',
  bookId: '', parts: [{ ...PART_VIDE }, { ...PART_VIDE }], workIds: '', seriesTitle: '', rationale: '',
};

function parseIds(s) {
  return String(s || '').split(/[\s,;]+/).map(x => parseInt(x, 10)).filter(n => Number.isInteger(n) && n > 0);
}

export default function WorksWorkshopPanel({ isStaff, onProposed }) {
  const { formatMessage: t, locale } = useIntl();
  const fs = { width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem' };
  const ls = { display: 'block', fontSize: '.8rem', fontWeight: 600, marginBottom: 3, color: 'var(--brand-muted, #ccc)' };
  const card = { padding: 14, borderRadius: 10, border: '1px solid rgba(255,255,255,.1)', background: 'rgba(255,255,255,.03)', marginBottom: 10 };

  const [msg, setMsg] = useState({ text: '', kind: '' });

  // ── La file « corrige-moi » ──
  const [lang, setLang] = useState(LANGS.includes(locale) ? locale : 'fr');
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [edits, setEdits] = useState({});     // `${work_id}|${lang}` -> titre corrige
  const [busyKey, setBusyKey] = useState(null);

  const loadQueue = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase.schema('api').rpc('fn_work_titles_review_list', { p_lang: lang, p_limit: 60 });
    if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); setRows([]); }
    else setRows(Array.isArray(data) ? data : []);
    setLoading(false);
  }, [lang, t]);
  useEffect(() => { loadQueue(); }, [loadQueue]);

  async function validate(r, corrected) {
    const key = `${r.work_id}|${r.lang}`;
    setBusyKey(key); setMsg({ text: '', kind: '' });
    const { error } = await supabase.schema('api').rpc('fn_work_title_validate', {
      p_work_id: r.work_id, p_lang: r.lang, p_title: corrected && corrected.trim() !== r.title ? corrected.trim() : null,
    });
    setBusyKey(null);
    if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); return; }
    setMsg({ text: t({ id: 'atelier.titres.done' }), kind: 'ok' });
    loadQueue();
  }

  // ── Le formulaire ──
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ ...FORM_VIDE, parts: [{ ...PART_VIDE }, { ...PART_VIDE }] });
  const [submitting, setSubmitting] = useState(false);

  function proposeTitleFromQueue(r) {
    setForm({ ...FORM_VIDE, kind: 'titre', workId: String(r.work_id), workLabel: r.edition_title || '', lang: r.lang,
      title: edits[`${r.work_id}|${r.lang}`] ?? r.title, parts: [{ ...PART_VIDE }, { ...PART_VIDE }] });
    setShowForm(true);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  async function propose(e) {
    e.preventDefault();
    setMsg({ text: '', kind: '' });
    if (form.rationale.trim().length < 10) {
      setMsg({ text: t({ id: 'atelier.form.error.rationale' }), kind: 'error' }); return;
    }
    const wid = parseInt(form.workId, 10);
    if (!Number.isInteger(wid)) { setMsg({ text: t({ id: 'atelier.form.error.workId' }), kind: 'error' }); return; }
    let payload = {};
    let mergeInto = null;
    let label = `${t({ id: 'atelier.work.short' })} #${wid}${form.workLabel ? ` « ${form.workLabel.trim()} »` : ''}`;
    if (form.kind === 'titre') {
      if (!form.title.trim()) { setMsg({ text: t({ id: 'atelier.form.error.workTitle' }), kind: 'error' }); return; }
      payload = { lang: form.lang, title: form.title.trim() };
      label += ` — ${form.lang} : « ${form.title.trim()} »`;
    } else if (form.kind === 'fusion') {
      mergeInto = parseInt(form.mergeIntoId, 10);
      if (!Number.isInteger(mergeInto)) { setMsg({ text: t({ id: 'atelier.form.error.workId' }), kind: 'error' }); return; }
      label += ` → #${mergeInto}`;
    } else if (form.kind === 'rattachement') {
      const bid = parseInt(form.bookId, 10);
      if (!Number.isInteger(bid)) { setMsg({ text: t({ id: 'atelier.form.error.workBook' }), kind: 'error' }); return; }
      payload = { book_id: bid };
      label += ` ← ${t({ id: 'atelier.work.editionShort' })} #${bid}`;
    } else if (form.kind === 'scission') {
      const parts = form.parts
        .map(p => ({ uniform_title: p.uniform_title.trim(), book_ids: parseIds(p.book_ids) }))
        .filter(p => p.uniform_title || p.book_ids.length);
      if (parts.length < 2 || parts.some(p => !p.uniform_title || p.book_ids.length === 0)) {
        setMsg({ text: t({ id: 'atelier.form.error.workParts' }), kind: 'error' }); return;
      }
      payload = { parts };
      label += ` → ${parts.map(p => `« ${p.uniform_title} »`).join(' + ')}`;
    } else if (form.kind === 'tomes') {
      const ids = parseIds(form.workIds).filter(id => id !== wid);
      if (ids.length === 0) { setMsg({ text: t({ id: 'atelier.form.error.workTomes' }), kind: 'error' }); return; }
      payload = { work_ids: ids, series_title: form.seriesTitle.trim() || null };
      label += ` + ${ids.map(i => `#${i}`).join(', ')}${form.seriesTitle.trim() ? ` = « ${form.seriesTitle.trim()} »` : ''}`;
    }
    setSubmitting(true);
    const { error } = await supabase.schema('api').rpc('fn_authority_propose', {
      p_kind: form.kind, p_target_kind: 'work', p_target_id: wid, p_merge_into_id: mergeInto,
      p_payload: payload, p_rationale: `${label}. ${form.rationale.trim()}`,
    });
    setSubmitting(false);
    if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); return; }
    setMsg({ text: t({ id: 'atelier.form.success' }), kind: 'ok' });
    setForm({ ...FORM_VIDE, parts: [{ ...PART_VIDE }, { ...PART_VIDE }] });
    setShowForm(false);
    onProposed?.();
  }

  return (
    <div>
      <p style={{ color: 'var(--brand-muted)', marginBottom: 14, fontSize: '.9rem', lineHeight: 1.6 }}>
        {t({ id: 'atelier.obras.subtitle' })}
      </p>

      <div style={{ display: 'flex', gap: 10, marginBottom: 14, flexWrap: 'wrap' }}>
        <Button variant="primary" onClick={() => setShowForm(s => !s)}>
          {showForm ? t({ id: 'atelier.action.closeForm' }) : t({ id: 'atelier.action.newProposal' })}
        </Button>
        <Button variant="secondary" onClick={loadQueue} disabled={loading}>{t({ id: 'atelier.action.refresh' })}</Button>
      </div>

      {msg.text && (
        <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.85rem', marginBottom: 14,
          background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)',
          color: msg.kind === 'ok' ? '#4ade80' : '#f87171',
          border: `1px solid ${msg.kind === 'ok' ? 'rgba(21,128,61,.25)' : 'rgba(220,38,38,.25)'}` }}>
          {msg.text}
        </div>
      )}

      {showForm && (
        <form onSubmit={propose} style={{ ...card, background: 'rgba(29,78,216,.06)', border: '1px solid rgba(29,78,216,.2)', padding: 16, marginBottom: 18 }}>
          <h2 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 10, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
            {t({ id: 'atelier.form.newTitle' })}
          </h2>
          <div style={{ marginBottom: 10 }}>
            <label style={ls}>{t({ id: 'atelier.form.kind' })}</label>
            {/* Cinq boutons, pas un menu deroulant : ferme, un <select> ne montre
                que le type courant — Xavier y a vu « une seule categorie » (05/09). */}
            <div role="radiogroup" aria-label={t({ id: 'atelier.form.kind' })} style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {KINDS.map(k => {
                const on = form.kind === k;
                return (
                  <button key={k} type="button" role="radio" aria-checked={on}
                    onClick={() => setForm(f => ({ ...f, kind: k }))}
                    style={{ ...fs, width: 'auto', cursor: 'pointer', padding: '7px 12px', fontWeight: on ? 700 : 500,
                      borderColor: on ? 'var(--brand-color-primary, #e0304a)' : 'rgba(255,255,255,.12)',
                      background: on ? 'rgba(var(--brand-action-rgb, 200,16,46), .18)' : 'rgba(0,0,0,.3)' }}>
                    {t({ id: `atelier.kindLabel.work.${k}` })}
                  </button>
                );
              })}
            </div>
            <p style={{ fontSize: '.78rem', color: 'var(--brand-muted, #999)', margin: '8px 0 0', maxWidth: 640 }}>
              <strong>{t({ id: `atelier.kindProp.work.${form.kind}` })}</strong> — {t({ id: `atelier.form.work.hint.${form.kind}` })}
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '100px minmax(0, 1fr)', gap: 10, marginBottom: 10, alignItems: 'end' }}>
            <div>
              <label style={ls}>{t({ id: 'atelier.form.work.id' })}</label>
              <input type="number" value={form.workId} onChange={e => setForm(f => ({ ...f, workId: e.target.value }))} style={fs} />
            </div>
            <div>
              <label style={ls}>{t({ id: 'atelier.form.work.label' })}</label>
              <input type="text" value={form.workLabel} onChange={e => setForm(f => ({ ...f, workLabel: e.target.value }))} style={fs} />
            </div>
          </div>

          {form.kind === 'titre' && (
            <div style={{ display: 'grid', gridTemplateColumns: '104px minmax(0, 1fr)', gap: 10, marginBottom: 10, alignItems: 'end' }}>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.lang' })}</label>
                <select value={form.lang} onChange={e => setForm(f => ({ ...f, lang: e.target.value }))} style={fs}>
                  {LANGS.map(L => <option key={L} value={L}>{L}</option>)}
                </select>
              </div>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.work.title' })}</label>
                <input type="text" value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} style={fs} />
              </div>
            </div>
          )}

          {form.kind === 'fusion' && (
            <div style={{ marginBottom: 10, maxWidth: 260 }}>
              <label style={ls}>{t({ id: 'atelier.form.work.mergeInto' })}</label>
              <input type="number" value={form.mergeIntoId} onChange={e => setForm(f => ({ ...f, mergeIntoId: e.target.value }))} style={fs} />
            </div>
          )}

          {form.kind === 'rattachement' && (
            <div style={{ marginBottom: 10, maxWidth: 260 }}>
              <label style={ls}>{t({ id: 'atelier.form.work.bookId' })}</label>
              <input type="number" value={form.bookId} onChange={e => setForm(f => ({ ...f, bookId: e.target.value }))} style={fs} />
            </div>
          )}

          {form.kind === 'scission' && (<>
            <label style={ls}>{t({ id: 'atelier.form.work.parts' })}</label>
            {form.parts.map((p, i) => (
              <div key={i} style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr) 32px', gap: 8, marginBottom: 8, alignItems: 'end' }}>
                <div>
                  <label style={{ ...ls, fontSize: '.7rem' }}>{t({ id: 'atelier.form.work.partTitle' })}</label>
                  <input type="text" value={p.uniform_title} onChange={e => setForm(f => ({ ...f, parts: f.parts.map((q, k) => k === i ? { ...q, uniform_title: e.target.value } : q) }))} style={fs} />
                </div>
                <div>
                  <label style={{ ...ls, fontSize: '.7rem' }}>{t({ id: 'atelier.form.work.partBooks' })}</label>
                  <input type="text" value={p.book_ids} placeholder="12, 34" onChange={e => setForm(f => ({ ...f, parts: f.parts.map((q, k) => k === i ? { ...q, book_ids: e.target.value } : q) }))} style={fs} />
                </div>
                <button type="button" aria-label={t({ id: 'atelier.form.scission.removePart' })} disabled={form.parts.length <= 2}
                  onClick={() => setForm(f => ({ ...f, parts: f.parts.filter((_, k) => k !== i) }))}
                  style={{ ...fs, cursor: form.parts.length <= 2 ? 'not-allowed' : 'pointer', opacity: form.parts.length <= 2 ? .35 : 1, textAlign: 'center', padding: '8px 0' }}>×</button>
              </div>
            ))}
            <div style={{ marginBottom: 10 }}>
              <Button variant="ghost" type="button" onClick={() => setForm(f => ({ ...f, parts: [...f.parts, { ...PART_VIDE }] }))}>
                {t({ id: 'atelier.form.scission.addPart' })}
              </Button>
            </div>
          </>)}

          {form.kind === 'tomes' && (
            <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)', gap: 10, marginBottom: 10, alignItems: 'end' }}>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.work.workIds' })}</label>
                <input type="text" value={form.workIds} placeholder="45, 46, 47" onChange={e => setForm(f => ({ ...f, workIds: e.target.value }))} style={fs} />
              </div>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.work.seriesTitle' })}</label>
                <input type="text" value={form.seriesTitle} onChange={e => setForm(f => ({ ...f, seriesTitle: e.target.value }))} style={fs} />
              </div>
            </div>
          )}

          <div style={{ marginBottom: 12 }}>
            <label style={ls}>{t({ id: 'atelier.form.rationale' })}</label>
            <textarea value={form.rationale} onChange={e => setForm(f => ({ ...f, rationale: e.target.value }))} style={{ ...fs, resize: 'vertical', minHeight: 64 }} />
          </div>
          <Button variant="primary" type="submit" disabled={submitting}>
            {submitting ? t({ id: 'atelier.form.sending' }) : t({ id: 'atelier.form.submit' })}
          </Button>
        </form>
      )}

      {/* ── La file « corrige-moi » ── */}
      <div style={{ ...card, marginTop: 6 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap', alignItems: 'baseline', marginBottom: 6 }}>
          <h2 style={{ fontSize: '1rem', fontWeight: 700, margin: 0, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
            {t({ id: 'atelier.titres.title' })}
          </h2>
          <label style={{ display: 'inline-flex', alignItems: 'center', gap: 8, fontSize: '.8rem', color: 'var(--brand-muted)' }}>
            {t({ id: 'atelier.form.lang' })}
            <select value={lang} onChange={e => setLang(e.target.value)} style={{ ...fs, width: 'auto', padding: '5px 8px' }}>
              {LANGS.map(L => <option key={L} value={L}>{L}</option>)}
            </select>
          </label>
        </div>
        <p style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '0 0 12px', lineHeight: 1.5 }}>{t({ id: 'atelier.titres.intro' })}</p>
        {loading ? (
          <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem' }}>{t({ id: 'common.loading' })}</p>
        ) : rows.length === 0 ? (
          <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem' }}>{t({ id: 'atelier.titres.empty' })}</p>
        ) : rows.map(r => {
          const key = `${r.work_id}|${r.lang}`;
          const value = edits[key] ?? r.title;
          return (
            <div key={key} style={{ padding: '10px 0', borderTop: '1px solid rgba(255,255,255,.08)' }}>
              <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)', marginBottom: 4 }}>
                {t({ id: 'atelier.work.short' })} #{r.work_id}
                {r.edition_title && <> · {t({ id: 'atelier.titres.editionOf' }, { lang: r.edition_lang })} « {r.edition_title} »</>}
                {r.author_name && <> · {r.author_name}</>}
                {r.n_editions > 1 && <> · {t({ id: 'atelier.titres.editions' }, { n: r.n_editions })}</>}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) auto', gap: 8, alignItems: 'center' }}>
                <input type="text" value={value} onChange={e => setEdits(x => ({ ...x, [key]: e.target.value }))} style={fs} />
                <div style={{ display: 'flex', gap: 6 }}>
                  {isStaff ? (
                    <>
                      <Button variant="primary" disabled={busyKey === key} onClick={() => validate(r, value)}>
                        {value.trim() !== r.title ? t({ id: 'atelier.titres.correct' }) : t({ id: 'atelier.titres.validate' })}
                      </Button>
                    </>
                  ) : (
                    <Button variant="secondary" onClick={() => proposeTitleFromQueue(r)}>{t({ id: 'atelier.titres.propose' })}</Button>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
