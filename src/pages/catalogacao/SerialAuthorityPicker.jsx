import { useState, useEffect, useRef } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

// #périodiques P7 (27/08/2026) — Sélecteur de TITRE DE REVUE au catalogage.
//
// Calqué sur SubjectAuthorityPicker, avec une différence de fond : un fascicule
// a UN SEUL titre de revue, pas une liste. Le composant gère donc une valeur,
// pas une collection — d'où l'absence de chips multiples et la présence d'un
// bouton « détacher ».
//
// CE QU'IL N'ÉCRIT PAS. Il ne touche jamais à `titulo_periodico`, qui reste la
// forme TRANSCRITE sur le fascicule. Les deux coexistent volontairement : un
// numéro peut porter un titre légèrement différent de la forme retenue, et
// c'est une information catalographique, pas une erreur. Le champ transcrit est
// juste à côté dans la même section.
//
// POURQUOI IL ÉCRIT DANS LE FORMULAIRE ET NON EN BASE. Contrairement au picker
// de matières (qui écrit dans book_draft_subjects, une table de liaison),
// serial_id est une colonne du brouillon : il suit donc l'enregistrement normal
// du formulaire, et la publication le recopie dans books (paquet P7a). Un appel
// direct ici créerait un second chemin d'écriture, désaccordé de l'autosave.
//
// La création à la volée passe par api.fn_serial_create : le titre naît
// `proposto`, exactement comme un sujet. C'est l'Atelier qui promeut.

function subtitle(r, t) {
  // Ce qui distingue deux revues homonymes, dans l'ordre où ça sert : les
  // dates de parution d'abord (c'est ce qui identifie un titre militant),
  // l'organisation éditrice ensuite, l'ISSN en dernier — il est rare sur nos
  // fonds, et quand il est là il est décisif mais peu parlant à l'œil.
  const bits = [];
  const span = [r.start_year, r.end_year].filter(Boolean).join('–');
  if (span) bits.push(span);
  else if (r.start_year) bits.push(r.start_year);
  if (r.emitter_org) bits.push(r.emitter_org);
  if (r.issn) bits.push(`ISSN ${r.issn}`);
  if (typeof r.issues_count === 'number' && r.issues_count > 0) {
    bits.push(t({ id: 'catalogacao.serial.issuesCount' }, { count: r.issues_count }));
  }
  return bits.join(' · ');
}

export default function SerialAuthorityPicker({ value, onChange, disabled }) {
  const { formatMessage: t } = useIntl();
  const [current, setCurrent] = useState(null); // { id, slug, uniform_title, status, ... }
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const lastLoaded = useRef(null);

  // Charger la revue déjà choisie (au retour sur un brouillon).
  useEffect(() => {
    const id = value ? Number(value) : null;
    if (!id) { setCurrent(null); lastLoaded.current = null; return; }
    if (lastLoaded.current === id) return;
    let cancelled = false;
    (async () => {
      const { data } = await supabase.schema('api').from('serials_list_v1')
        .select('id, slug, uniform_title, status, issn, start_year, end_year, emitter_org, issues_count')
        .eq('id', id).maybeSingle();
      if (!cancelled && data) { setCurrent(data); lastLoaded.current = id; }
    })();
    return () => { cancelled = true; };
  }, [value]);

  // Recherche (debounce 300 ms), même cadence que le picker de matières.
  useEffect(() => {
    const q = query.trim();
    if (q.length < 2) { setResults([]); return; }
    const h = setTimeout(async () => {
      try {
        const { data } = await supabase.schema('api')
          .rpc('fn_serial_search', { p_query: q, p_limit: 10 });
        setResults(Array.isArray(data) ? data : []);
      } catch { setResults([]); }
    }, 300);
    return () => clearTimeout(h);
  }, [query]);

  function pick(r) {
    setCurrent(r);
    lastLoaded.current = r.id;
    onChange(String(r.id));
    setQuery(''); setResults([]); setError(null);
  }

  function detach() {
    setCurrent(null);
    lastLoaded.current = null;
    onChange('');
  }

  async function createSerial() {
    const title = query.trim();
    if (!title) return;
    setBusy(true); setError(null);
    try {
      const { data, error: e } = await supabase.schema('api')
        .rpc('fn_serial_create', { p_uniform_title: title, p_payload: {} });
      if (e) throw e;
      const row = Array.isArray(data) ? data[0] : data;
      if (!row?.id) throw new Error('no_row');
      pick(row);
    } catch (err) {
      console.error('createSerial', err);
      setError(t({ id: 'catalogacao.serial.createFailed' }));
    } finally { setBusy(false); }
  }

  const ql = query.trim().toLowerCase();
  const canCreate = ql.length >= 2
    && !results.some(r => (r.uniform_title || '').toLowerCase() === ql);

  return (
    <div className="cat-field" style={{ gridColumn: 'span 3' }}>
      <label className="ab-field__label" style={ls}>
        {t({ id: 'catalogacao.serial.label' })}
      </label>

      {current ? (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center', marginBottom: 6 }}>
          <span style={chip}>
            {current.uniform_title}
            {current.status === 'proposto' && (
              <span style={badge} title={t({ id: 'catalogacao.serial.proposedHint' })}>
                {t({ id: 'catalogacao.serial.proposed' })}
              </span>
            )}
            <button type="button" onClick={detach} disabled={disabled || busy}
              style={chipX} aria-label={t({ id: 'catalogacao.serial.detach' })}
              title={t({ id: 'catalogacao.serial.detach' })}>✕</button>
          </span>
          {subtitle(current, t) && <span style={muted}>{subtitle(current, t)}</span>}
        </div>
      ) : (
        <div style={{ ...hint, marginBottom: 6 }}>{t({ id: 'catalogacao.serial.none' })}</div>
      )}

      <input className="ab-input" type="search" value={query} disabled={disabled}
        onChange={e => setQuery(e.target.value)}
        placeholder={t({ id: 'catalogacao.serial.searchPh' })} />

      {(results.length > 0 || canCreate) && (
        <div style={resultsBox}>
          {results.map(r => (
            <button key={r.id} type="button" onClick={() => pick(r)} disabled={disabled || busy} style={resultBtn}>
              <span style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                <span>{r.uniform_title}</span>
                {r.status === 'proposto' && (
                  <span style={badgeDark}>{t({ id: 'catalogacao.serial.proposed' })}</span>
                )}
              </span>
              {subtitle(r, t) && <span style={sub}>{subtitle(r, t)}</span>}
            </button>
          ))}
          {canCreate && (
            <button type="button" onClick={createSerial} disabled={disabled || busy}
              style={{ ...resultBtn, fontStyle: 'italic' }}>
              + {t({ id: 'catalogacao.serial.create' }, { term: query.trim() })}
              <span style={{ ...badgeDark, fontStyle: 'normal', marginLeft: 6 }}>
                {t({ id: 'catalogacao.serial.proposed' })}
              </span>
            </button>
          )}
        </div>
      )}

      {error && <div style={{ ...hint, color: 'var(--brand-action, #b32025)', marginTop: 4 }}>{error}</div>}
      <div style={{ ...hint, marginTop: 4 }}>{t({ id: 'catalogacao.serial.transcribedHint' })}</div>
    </div>
  );
}

const ls = { display: 'block', marginBottom: 4 };
const hint = { fontSize: '.78rem', color: 'var(--brand-muted, #999)' };
const muted = { fontSize: '.74rem', color: 'var(--brand-muted, #999)' };
const chip = { display: 'inline-flex', alignItems: 'center', gap: 5, padding: '2px 8px', fontSize: '.8rem', borderRadius: 999, background: 'var(--brand-action, #b32025)', color: '#fff' };
const chipX = { background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer', fontSize: '.7rem', padding: 0, lineHeight: 1 };
const badge = { fontSize: '.6rem', textTransform: 'uppercase', letterSpacing: '.03em', padding: '0 5px', borderRadius: 4, background: 'rgba(255,255,255,.22)', color: '#fff', whiteSpace: 'nowrap' };
const badgeDark = { fontSize: '.6rem', textTransform: 'uppercase', letterSpacing: '.03em', padding: '0 5px', borderRadius: 4, background: 'rgba(255,255,255,.12)', color: 'var(--brand-muted, #bbb)', whiteSpace: 'nowrap' };
const resultsBox = { marginTop: 4, border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))', borderRadius: 6, background: 'var(--brand-panel-bg-strong, rgba(10,10,10,.94))', maxHeight: 240, overflowY: 'auto' };
const resultBtn = { display: 'block', width: '100%', textAlign: 'left', padding: '5px 10px', background: 'transparent', border: 'none', borderBottom: '1px solid var(--brand-panel-border, rgba(255,255,255,.08))', color: 'var(--brand-text, #f5f2ea)', cursor: 'pointer', fontSize: '.82rem' };
const sub = { display: 'block', fontSize: '.7rem', color: 'var(--brand-muted, #999)', marginTop: 2, lineHeight: 1.3 };
