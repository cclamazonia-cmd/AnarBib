import { useState, useEffect, useRef } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

// Sélecteur multiple CONTRÔLÉ de sujets du thésaurus (typeahead api.search_subjects).
// Contrairement à SubjectAuthorityPicker (couplé au catalogage, écrit dans
// book_draft_subjects), ce composant ne fait AUCUNE écriture : il expose une
// valeur contrôlée à passer à l'appelant·e.
//
//   value    : Array<{ id, label_i18n, slug }>
//   onChange : (nextValue) => void
//   max      : nombre max de sujets (défaut 8)
//   searchFn : (query) => Promise<subject[]>  (injection pour tests ; défaut = RPC)

function localizedLabel(labelI18n, locale) {
  if (!labelI18n || typeof labelI18n !== 'object') return '';
  return labelI18n[locale]
    || labelI18n[(locale || '').split('-')[0]]
    || labelI18n['pt-BR']
    || Object.values(labelI18n)[0]
    || '';
}

export default function SubjectMultiSelect({ value = [], onChange, max = 8, searchFn }) {
  const { formatMessage: t, locale } = useIntl();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [busy, setBusy] = useState(false);
  const timerRef = useRef();

  const doSearch = searchFn || (async (q) => {
    const { data } = await supabase.schema('api').rpc('search_subjects', { p_query: q, p_limit: 8 });
    return Array.isArray(data) ? data : [];
  });

  useEffect(() => {
    if (!query.trim()) { setResults([]); return; }
    clearTimeout(timerRef.current);
    timerRef.current = setTimeout(async () => {
      setBusy(true);
      try { setResults(await doSearch(query.trim())); }
      catch { setResults([]); }
      finally { setBusy(false); }
    }, 300);
    return () => clearTimeout(timerRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  const selectedIds = new Set(value.map(v => v.id));
  const add = (s) => {
    if (selectedIds.has(s.id) || value.length >= max) return;
    onChange([...value, { id: s.id, label_i18n: s.label_i18n, slug: s.slug }]);
    setQuery('');
    setResults([]);
  };
  const remove = (id) => onChange(value.filter(v => v.id !== id));

  return (
    <div className="ab-subject-multiselect" style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {value.length > 0 && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {value.map(v => (
            <span key={v.id} style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '2px 8px', borderRadius: 12, background: 'rgba(96,165,250,.15)', fontSize: '.82rem' }}>
              {localizedLabel(v.label_i18n, locale) || v.slug}
              <button type="button" onClick={() => remove(v.id)} title="×"
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'inherit', padding: 0, lineHeight: 1, fontSize: '1rem' }}>×</button>
            </span>
          ))}
        </div>
      )}
      {value.length < max && (
        <input
          type="text"
          value={query}
          onChange={e => setQuery(e.target.value)}
          placeholder={t({ id: 'federacao.circulos.create.subjects' })}
          aria-label={t({ id: 'federacao.circulos.create.subjects' })}
        />
      )}
      {busy && <div style={{ fontSize: '.78rem', opacity: .6 }}>…</div>}
      {results.filter(s => !selectedIds.has(s.id)).length > 0 && (
        <div style={{ border: '1px solid rgba(255,255,255,.15)', borderRadius: 6, maxHeight: 180, overflowY: 'auto' }}>
          {results.filter(s => !selectedIds.has(s.id)).map(s => (
            <button type="button" key={s.id} onClick={() => add(s)}
              style={{ display: 'block', width: '100%', textAlign: 'left', padding: '6px 10px', background: 'none', border: 'none', borderBottom: '1px solid rgba(255,255,255,.06)', cursor: 'pointer', color: 'inherit', fontSize: '.85rem' }}>
              {localizedLabel(s.label_i18n, locale) || s.slug}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
