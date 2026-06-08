import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

// #OPAC-ATL1 P2 — Indexation matière : typeahead sur l'autorité `subjects`
// (thésaurus), création à la volée, écriture directe dans book_draft_subjects
// (RLS gardée par api.my_access.can_access_catalogacao). Persiste à chaque
// ajout/retrait quand le brouillon est sauvegardé (a un id).

function localizedLabel(labelI18n, locale) {
  if (!labelI18n || typeof labelI18n !== 'object') return '';
  return labelI18n[locale]
    || labelI18n[(locale || '').split('-')[0]]
    || labelI18n['pt-BR']
    || Object.values(labelI18n)[0]
    || '';
}

export default function SubjectAuthorityPicker({ draftId }) {
  const { formatMessage: t, locale } = useIntl();
  const [selected, setSelected] = useState([]); // [{subject_id, slug, label_i18n}]
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [busy, setBusy] = useState(false);

  // Charger les sujets déjà liés au brouillon
  useEffect(() => {
    if (!draftId) { setSelected([]); return; }
    let cancelled = false;
    (async () => {
      const { data } = await supabase.from('book_draft_subjects')
        .select('subject_id, ord, subjects(id, slug, label_i18n)')
        .eq('book_draft_id', draftId).order('ord');
      if (!cancelled && Array.isArray(data)) {
        setSelected(data.map(r => ({ subject_id: r.subject_id, slug: r.subjects?.slug, label_i18n: r.subjects?.label_i18n })));
      }
    })();
    return () => { cancelled = true; };
  }, [draftId]);

  // Recherche (debounce 300 ms) via api.search_subjects
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

  async function addSubject(subj) {
    if (!draftId || selected.some(s => s.subject_id === subj.id)) return;
    setBusy(true);
    try {
      const { error } = await supabase.from('book_draft_subjects')
        .insert({ book_draft_id: draftId, subject_id: subj.id, ord: selected.length });
      if (error && error.code !== '23505') throw error;
      setSelected(prev => [...prev, { subject_id: subj.id, slug: subj.slug, label_i18n: subj.label_i18n }]);
      setQuery(''); setResults([]);
    } catch (e) { console.error('addSubject', e); }
    finally { setBusy(false); }
  }

  async function removeSubject(subjectId) {
    if (!draftId) return;
    setBusy(true);
    try {
      await supabase.from('book_draft_subjects').delete()
        .eq('book_draft_id', draftId).eq('subject_id', subjectId);
      setSelected(prev => prev.filter(s => s.subject_id !== subjectId));
    } catch (e) { console.error('removeSubject', e); }
    finally { setBusy(false); }
  }

  async function createSubject() {
    const label = query.trim();
    if (!label) return;
    setBusy(true);
    try {
      const labelI18n = { [locale]: label };
      if (locale !== 'pt-BR') labelI18n['pt-BR'] = label; // garantit le fallback
      const { data, error } = await supabase.from('subjects')
        .insert({ label_i18n: labelI18n }).select('id, slug, label_i18n').single();
      if (error) throw error;
      await addSubject(data);
    } catch (e) { console.error('createSubject', e); }
    finally { setBusy(false); }
  }

  if (!draftId) {
    return (
      <div className="cat-field" style={{ gridColumn: 'span 3' }}>
        <label className="ab-field__label" style={ls}>{t({ id: 'catalogacao.subjects.label' })}</label>
        <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #999)' }}>{t({ id: 'catalogacao.subjects.saveFirst' })}</div>
      </div>
    );
  }

  const ql = query.trim().toLowerCase();
  const canCreate = ql.length >= 2 && !results.some(r => localizedLabel(r.label_i18n, locale).toLowerCase() === ql);

  return (
    <div className="cat-field" style={{ gridColumn: 'span 3' }}>
      <label className="ab-field__label" style={ls}>{t({ id: 'catalogacao.subjects.label' })}</label>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 6 }}>
        {selected.map(s => (
          <span key={s.subject_id} style={chip}>
            {localizedLabel(s.label_i18n, locale)}
            <button type="button" onClick={() => removeSubject(s.subject_id)} disabled={busy} style={chipX} aria-label="×">✕</button>
          </span>
        ))}
        {selected.length === 0 && <span style={{ fontSize: '.78rem', color: 'var(--brand-muted, #999)' }}>{t({ id: 'catalogacao.subjects.none' })}</span>}
      </div>
      <input className="ab-input" type="search" value={query} onChange={e => setQuery(e.target.value)}
        placeholder={t({ id: 'catalogacao.subjects.searchPh' })} />
      {(results.length > 0 || canCreate) && (
        <div style={resultsBox}>
          {results.map(r => (
            <button key={r.id} type="button" onClick={() => addSubject(r)} disabled={busy} style={resultBtn}>
              <span>{localizedLabel(r.label_i18n, locale)}</span>
              {r.parent_label && <span style={{ fontSize: '.7rem', color: 'var(--brand-muted, #999)' }}> · {localizedLabel(r.parent_label, locale)}</span>}
            </button>
          ))}
          {canCreate && (
            <button type="button" onClick={createSubject} disabled={busy} style={{ ...resultBtn, fontStyle: 'italic' }}>
              + {t({ id: 'catalogacao.subjects.create' }, { term: query.trim() })}
            </button>
          )}
        </div>
      )}
    </div>
  );
}

const ls = { display: 'block', marginBottom: 4 };
const chip = { display: 'inline-flex', alignItems: 'center', gap: 6, padding: '2px 8px', fontSize: '.8rem', borderRadius: 999, background: 'var(--brand-action, #b32025)', color: '#fff' };
const chipX = { background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer', fontSize: '.7rem', padding: 0, lineHeight: 1 };
const resultsBox = { marginTop: 4, border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))', borderRadius: 6, background: 'var(--brand-panel-bg-strong, rgba(10,10,10,.94))', maxHeight: 200, overflowY: 'auto' };
const resultBtn = { display: 'block', width: '100%', textAlign: 'left', padding: '5px 10px', background: 'transparent', border: 'none', borderBottom: '1px solid var(--brand-panel-border, rgba(255,255,255,.08))', color: 'var(--brand-text, #f5f2ea)', cursor: 'pointer', fontSize: '.82rem' };
