import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { pickLabel } from '@/lib/i18nLabel';

// ═══════════════════════════════════════════════════════════════════════════
// SubjectLabelEditor — thésaurus v2 étape H-1 : éditeur de libellés multilingue.
//
// Coordination catalogage uniquement (rendu sous le gate isCoord du panneau
// Matière). Cherche un sujet → édite, PAR LANGUE, le libellé `pref` (label_i18n),
// les synonymes (alt_i18n) et les variantes de recherche (hidden_i18n). Écrit via
// api.fn_subject_update_labels (gardé serveur). C'est le cœur vivant du
// multilingue : remplir les ⚐ manquants, enrichir la findabilité.
// ═══════════════════════════════════════════════════════════════════════════

const LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

function lbl(labelI18n, locale) {
  if (!labelI18n || typeof labelI18n !== 'object') return '';
  return labelI18n[locale] || labelI18n[(locale || '').split('-')[0]] || labelI18n['pt-BR'] || Object.values(labelI18n)[0] || '';
}
const toArr = (s) => (s || '').split(',').map((x) => x.trim()).filter(Boolean);

export default function SubjectLabelEditor() {
  const { formatMessage: t, locale } = useIntl();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [subj, setSubj] = useState(null);
  const [pref, setPref] = useState({});
  const [alt, setAlt] = useState({});
  const [hidden, setHidden] = useState({});
  const [notation, setNotation] = useState('');
  const [related, setRelated] = useState([]);      // sujets reliés « voir aussi » (v3-A)
  const [relQuery, setRelQuery] = useState('');
  const [relResults, setRelResults] = useState([]);
  const [ficedl, setFicedl] = useState([]);        // descripteurs FICEDL alignés (P3b)
  const [ficQuery, setFicQuery] = useState('');
  const [ficResults, setFicResults] = useState([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState(null);

  async function loadRelated(subjectId) {
    try {
      const { data } = await supabase.schema('api').rpc('subject_related_v1', { p_subject_id: subjectId });
      setRelated(Array.isArray(data) ? data : []);
    } catch { setRelated([]); }
  }

  async function loadFicedl(subjectId) {
    try {
      const { data } = await supabase.schema('api').rpc('subject_ficedl_links_v1', { p_subject_id: subjectId });
      setFicedl(Array.isArray(data) ? data : []);
    } catch { setFicedl([]); }
  }

  useEffect(() => {
    const q = query.trim();
    if (q.length < 2) { setResults([]); return; }
    const h = setTimeout(async () => {
      try {
        const { data } = await supabase.schema('api').rpc('search_subjects', { p_query: q, p_limit: 10 });
        setResults(Array.isArray(data) ? data : []);
      } catch { setResults([]); }
    }, 300);
    return () => clearTimeout(h);
  }, [query]);

  async function pick(id) {
    setBusy(true); setMsg(null);
    const { data, error } = await supabase.from('subjects')
      .select('id, slug, label_i18n, alt_i18n, hidden_i18n, notation').eq('id', id).single();
    if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); setBusy(false); return; }
    const p = {}, a = {}, h = {};
    for (const loc of LOCALES) {
      p[loc] = (data.label_i18n && data.label_i18n[loc]) || '';
      a[loc] = (data.alt_i18n && Array.isArray(data.alt_i18n[loc])) ? data.alt_i18n[loc].join(', ') : '';
      h[loc] = (data.hidden_i18n && Array.isArray(data.hidden_i18n[loc])) ? data.hidden_i18n[loc].join(', ') : '';
    }
    setSubj(data); setPref(p); setAlt(a); setHidden(h); setNotation(data.notation || '');
    setRelQuery(''); setRelResults([]); await loadRelated(data.id);
    setFicQuery(''); setFicResults([]); await loadFicedl(data.id);
    setResults([]); setQuery('');
    setBusy(false);
  }

  // Recherche d'un descripteur FICEDL à aligner (facette « sujets », hors déjà liés).
  useEffect(() => {
    const q = ficQuery.trim();
    if (q.length < 2 || !subj) { setFicResults([]); return; }
    const h = setTimeout(async () => {
      try {
        const short = (locale || '').split('-')[0];
        const { data } = await supabase
          .from('ficedl_thesaurus_terms')
          .select('mot_id, labels')
          .contains('facet', ['sujets'])
          .or(`labels->>fr.ilike.%${q}%,labels->>${short}.ilike.%${q}%`)
          .limit(8);
        const linked = new Set(ficedl.map((f) => f.mot_id));
        setFicResults((Array.isArray(data) ? data : []).filter((r) => !linked.has(r.mot_id)));
      } catch { setFicResults([]); }
    }, 300);
    return () => clearTimeout(h);
  }, [ficQuery, subj, ficedl, locale]);

  async function addFicedl(motId) {
    setBusy(true); setMsg(null);
    const { error } = await supabase.schema('api').rpc('fn_subject_add_ficedl_match', { p_subject_id: subj.id, p_mot_id: motId });
    if (error) setMsg({ text: localizeError(error, t), kind: 'error' });
    else { setFicQuery(''); setFicResults([]); await loadFicedl(subj.id); }
    setBusy(false);
  }

  async function removeFicedl(motId) {
    setBusy(true); setMsg(null);
    const { error } = await supabase.schema('api').rpc('fn_subject_remove_ficedl_match', { p_subject_id: subj.id, p_mot_id: motId });
    if (error) setMsg({ text: localizeError(error, t), kind: 'error' });
    else await loadFicedl(subj.id);
    setBusy(false);
  }

  // Recherche pour relier un sujet (exclut soi-même + déjà reliés).
  useEffect(() => {
    const q = relQuery.trim();
    if (q.length < 2 || !subj) { setRelResults([]); return; }
    const h = setTimeout(async () => {
      try {
        const { data } = await supabase.schema('api').rpc('search_subjects', { p_query: q, p_limit: 8 });
        const relIds = new Set(related.map((r) => r.id));
        setRelResults((Array.isArray(data) ? data : []).filter((r) => r.id !== subj.id && !relIds.has(r.id)));
      } catch { setRelResults([]); }
    }, 300);
    return () => clearTimeout(h);
  }, [relQuery, subj, related]);

  async function addRelation(relId) {
    setBusy(true); setMsg(null);
    const { error } = await supabase.schema('api').rpc('fn_subject_add_relation', { p_subject_id: subj.id, p_related_id: relId });
    if (error) setMsg({ text: localizeError(error, t), kind: 'error' });
    else { setRelQuery(''); setRelResults([]); await loadRelated(subj.id); }
    setBusy(false);
  }

  async function removeRelation(relId) {
    setBusy(true); setMsg(null);
    const { error } = await supabase.schema('api').rpc('fn_subject_remove_relation', { p_subject_id: subj.id, p_related_id: relId });
    if (error) setMsg({ text: localizeError(error, t), kind: 'error' });
    else await loadRelated(subj.id);
    setBusy(false);
  }

  async function save() {
    setBusy(true); setMsg(null);
    const label_i18n = {}, alt_i18n = {}, hidden_i18n = {};
    for (const loc of LOCALES) {
      const p = (pref[loc] || '').trim();
      if (p) label_i18n[loc] = p;
      const a = toArr(alt[loc]); if (a.length) alt_i18n[loc] = a;
      const hh = toArr(hidden[loc]); if (hh.length) hidden_i18n[loc] = hh;
    }
    const { error } = await supabase.schema('api').rpc('fn_subject_update_labels', {
      p_subject_id: subj.id, p_label_i18n: label_i18n, p_alt_i18n: alt_i18n, p_hidden_i18n: hidden_i18n,
    });
    let nErr = null;
    if (!error) {
      const res = await supabase.schema('api').rpc('fn_subject_set_notation', {
        p_subject_id: subj.id, p_notation: notation.trim() || null,
      });
      nErr = res.error;
    }
    if (error || nErr) setMsg({ text: localizeError(error || nErr, t), kind: 'error' });
    else setMsg({ text: t({ id: 'catalogacao.subjectGov.editSaved' }), kind: 'ok' });
    setBusy(false);
  }

  return (
    <div style={{ marginTop: 24, borderTop: '1px solid rgba(255,255,255,.1)', paddingTop: 16 }}>
      <div className="ab-fed-label">{t({ id: 'catalogacao.subjectGov.editTitle' })}</div>
      <p style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)', marginTop: 0 }}>{t({ id: 'catalogacao.subjectGov.editHint' })}</p>

      <input className="ab-input" type="search" value={query} onChange={(e) => setQuery(e.target.value)}
        placeholder={t({ id: 'catalogacao.subjectGov.editSearch' })} style={{ maxWidth: 380 }} />
      {results.length > 0 && (
        <div style={resultsBox}>
          {results.map((r) => (
            <button key={r.id} type="button" style={resultBtn} disabled={busy} onClick={() => pick(r.id)}>
              {lbl(r.label_i18n, locale)} {r.status === 'proposto' && <span style={{ opacity: .6 }}>· {t({ id: 'catalogacao.subjects.proposed' })}</span>}
            </button>
          ))}
        </div>
      )}

      {msg && <div style={{ margin: '10px 0', fontSize: '.82rem', color: msg.kind === 'error' ? '#f87171' : '#4ade80' }}>{msg.text}</div>}

      {subj && (
        <div style={{ marginTop: 12 }}>
          <div style={{ fontWeight: 600, marginBottom: 8 }}>
            {lbl(subj.label_i18n, locale)} <span style={{ fontSize: '.75rem', color: 'var(--brand-muted, #888)' }}>· {subj.slug}</span>
          </div>
          <div style={{ marginBottom: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
            <label style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.subjectGov.editNotation' })}</label>
            <input style={{ ...cell, maxWidth: 150, fontFamily: 'monospace' }} value={notation} onChange={(e) => setNotation(e.target.value)} placeholder="335" />
          </div>
          <table style={{ width: '100%', fontSize: '.8rem', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ color: 'var(--brand-muted, #aaa)', textAlign: 'left' }}>
                <th style={th}>·</th>
                <th style={th}>{t({ id: 'catalogacao.subjectGov.editPref' })}</th>
                <th style={th}>{t({ id: 'catalogacao.subjectGov.editAlt' })}</th>
                <th style={th}>{t({ id: 'catalogacao.subjectGov.editHidden' })}</th>
              </tr>
            </thead>
            <tbody>
              {LOCALES.map((loc) => (
                <tr key={loc}>
                  <td style={{ ...td, whiteSpace: 'nowrap', fontVariant: 'all-small-caps', color: !pref[loc] ? '#eab308' : 'var(--brand-muted, #aaa)' }}>
                    {loc}{!pref[loc] && ' ⚐'}
                  </td>
                  <td style={td}><input style={cell} value={pref[loc] || ''} onChange={(e) => setPref((s) => ({ ...s, [loc]: e.target.value }))} /></td>
                  <td style={td}><input style={cell} value={alt[loc] || ''} onChange={(e) => setAlt((s) => ({ ...s, [loc]: e.target.value }))} /></td>
                  <td style={td}><input style={cell} value={hidden[loc] || ''} onChange={(e) => setHidden((s) => ({ ...s, [loc]: e.target.value }))} /></td>
                </tr>
              ))}
            </tbody>
          </table>

          <div style={{ marginTop: 16 }}>
            <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)', marginBottom: 6 }}>{t({ id: 'catalogacao.subjectGov.relTitle' })}</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 6 }}>
              {related.length === 0 && <span style={{ fontSize: '.78rem', color: 'var(--brand-muted, #777)' }}>{t({ id: 'catalogacao.subjectGov.relNone' })}</span>}
              {related.map((r) => (
                <span key={r.id} style={relChip}>
                  {lbl(r.label_i18n, locale)}
                  <button type="button" disabled={busy} onClick={() => removeRelation(r.id)} style={relChipX} aria-label="✕">✕</button>
                </span>
              ))}
            </div>
            <input className="ab-input" type="search" value={relQuery} onChange={(e) => setRelQuery(e.target.value)}
              placeholder={t({ id: 'catalogacao.subjectGov.relAdd' })} style={{ maxWidth: 380 }} />
            {relResults.length > 0 && (
              <div style={resultsBox}>
                {relResults.map((r) => (
                  <button key={r.id} type="button" style={resultBtn} disabled={busy} onClick={() => addRelation(r.id)}>
                    + {lbl(r.label_i18n, locale)} {r.status === 'proposto' && <span style={{ opacity: .6 }}>· {t({ id: 'catalogacao.subjects.proposed' })}</span>}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Alignement sur le thésaurus partagé FICEDL (P3b) */}
          <div style={{ marginTop: 16 }}>
            <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)', marginBottom: 6 }}>{t({ id: 'catalogacao.subjectGov.ficedlTitle' })}</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 6 }}>
              {ficedl.length === 0 && <span style={{ fontSize: '.78rem', color: 'var(--brand-muted, #777)' }}>{t({ id: 'catalogacao.subjectGov.ficedlNone' })}</span>}
              {ficedl.map((f) => (
                <span key={f.mot_id} style={relChip}>
                  {pickLabel(f.labels, locale, 'fr')}
                  <button type="button" disabled={busy} onClick={() => removeFicedl(f.mot_id)} style={relChipX} aria-label="✕">✕</button>
                </span>
              ))}
            </div>
            <input className="ab-input" type="search" value={ficQuery} onChange={(e) => setFicQuery(e.target.value)}
              placeholder={t({ id: 'catalogacao.subjectGov.ficedlAdd' })} style={{ maxWidth: 380 }} />
            {ficResults.length > 0 && (
              <div style={resultsBox}>
                {ficResults.map((r) => (
                  <button key={r.mot_id} type="button" style={resultBtn} disabled={busy} onClick={() => addFicedl(r.mot_id)}>
                    + {pickLabel(r.labels, locale, 'fr')} <span style={{ opacity: .6 }}>· {r.mot_id}</span>
                  </button>
                ))}
              </div>
            )}
          </div>

          <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
            <button className="ab-button" disabled={busy} onClick={save}>{t({ id: 'catalogacao.subjectGov.editSave' })}</button>
            <button className="ab-button ab-button--ghost" onClick={() => { setSubj(null); setMsg(null); }}>{t({ id: 'catalogacao.subjectGov.editClose' })}</button>
          </div>
        </div>
      )}
    </div>
  );
}

const th = { padding: '4px 6px', fontWeight: 600 };
const td = { padding: '3px 6px', verticalAlign: 'middle' };
const cell = { width: '100%', fontSize: '.8rem', color: 'var(--brand-text, #f5f2ea)', background: 'rgba(255,255,255,.05)', border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))', borderRadius: 6, padding: '4px 7px' };
const resultsBox = { marginTop: 4, maxWidth: 380, border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))', borderRadius: 6, background: 'var(--brand-panel-bg-strong, rgba(10,10,10,.94))', maxHeight: 200, overflowY: 'auto' };
const resultBtn = { display: 'block', width: '100%', textAlign: 'left', padding: '5px 10px', background: 'transparent', border: 'none', borderBottom: '1px solid var(--brand-panel-border, rgba(255,255,255,.08))', color: 'var(--brand-text, #f5f2ea)', cursor: 'pointer', fontSize: '.82rem' };
const relChip = { display: 'inline-flex', alignItems: 'center', gap: 5, padding: '3px 6px 3px 10px', borderRadius: 999, fontSize: '.78rem', background: 'rgba(255,255,255,.06)', border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))', color: 'var(--brand-text, #f5f2ea)' };
const relChipX = { background: 'transparent', border: 'none', color: 'var(--brand-muted, #aaa)', cursor: 'pointer', fontSize: '.72rem', lineHeight: 1, padding: 2 };
