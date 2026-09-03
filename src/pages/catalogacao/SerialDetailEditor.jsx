import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════════════════════
// SerialDetailEditor — tout ce qu'on peut faire sur UN titre de périodique.
//
// Quatre sections, dans l'ordre où elles servent au catalogage :
//   1. DESCRIPTION  — api.fn_serial_update. Un titre créé à la volée depuis le
//      sélecteur n'a QUE son nom : sans cet écran, les ~100 titres d'Anarchief
//      resteraient des coquilles vides.
//   2. FILIATION    — api.fn_serial_set_filiation. C'est la raison d'être du
//      modèle : sur un fonds qui court de 1860 à aujourd'hui, un journal qui
//      change de nom est la règle, pas l'exception.
//   3. NUMÉROS      — api.serial_issues_v1 + attach/detach. Voir ce qui est
//      déjà rattaché est ce qui évite de recataloguer un fascicule en double.
//   4. ÉTAT DE COLLECTION — api.fn_serial_upsert_holdings.
//
// CE QU'IL N'Y A PAS ICI, ET POURQUOI : la FUSION de deux titres. Le
// commentaire de public.serials l'a écrit dès le premier paquet — la création,
// la correction et la fusion passent par l'Atelier autorités. Une fusion
// supprime une autorité que d'autres bibliothèques utilisent peut-être ; elle
// se délibère (14 jours), elle ne se clique pas au fil du catalogage. Le
// panneau des doublons ci-contre mène donc à l'Atelier.
//
// LE SLUG NE SE MODIFIE PAS, même quand le titre retenu change. C'est
// l'identité de l'URL publique : la changer casserait les liens déjà partagés.
// L'écran le dit plutôt que de laisser la surprise arriver.
// ═══════════════════════════════════════════════════════════════════════════

const COMPLETENESS = ['completa', 'quase_completa', 'parcial', 'esparsa', 'desconhecida'];

// Les champs descriptifs que fn_serial_update accepte. Tenir cette liste
// alignée sur la liste blanche de public.fn_serial_apply_payload : la RPC LÈVE
// sur une clé inconnue, ce qui est voulu — une faute de frappe ne doit pas
// disparaître en silence.
const TEXT_FIELDS = [
  'sort_title', 'issn', 'issn_l', 'emitter_org', 'place_publication',
  'country_code', 'language', 'periodicidade', 'start_year', 'end_year',
];

// Formes parallèles / rejetées : stockées par locale ({fr: [...], es: [...]}).
// On n'édite QUE la locale de lecture, et on réinjecte les autres telles
// quelles — sinon enregistrer en français effacerait les formes espagnoles.
function formsFor(obj, locale) {
  if (!obj || typeof obj !== 'object') return '';
  const v = obj[locale] || obj[(locale || '').split('-')[0]];
  return Array.isArray(v) ? v.join('\n') : '';
}
function mergeForms(obj, locale, text) {
  const next = (obj && typeof obj === 'object') ? { ...obj } : {};
  const list = (text || '').split('\n').map(s => s.trim()).filter(Boolean);
  if (list.length === 0) delete next[locale]; else next[locale] = list;
  return next;
}

// Typeahead compact sur les titres, pour désigner un prédécesseur ou un
// successeur. Réutilise api.fn_serial_search : la RLS y fait déjà le tri, donc
// le staff trouve aussi les titres encore proposés.
function SerialLookup({ label, value, valueLabel, onPick, disabled }) {
  const { formatMessage: t } = useIntl();
  const [q, setQ] = useState('');
  const [res, setRes] = useState([]);

  useEffect(() => {
    const s = q.trim();
    if (s.length < 2) { setRes([]); return; }
    const h = setTimeout(async () => {
      try {
        const { data } = await supabase.schema('api').rpc('fn_serial_search', { p_query: s, p_limit: 8 });
        setRes(Array.isArray(data) ? data : []);
      } catch { setRes([]); }
    }, 300);
    return () => clearTimeout(h);
  }, [q]);

  return (
    <div>
      <label style={lbl}>{label}</label>
      {value ? (
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
          <span style={chip}>{valueLabel || `#${value}`}</span>
          <button type="button" className="ab-button ab-button--ghost" style={btnXs}
            disabled={disabled} onClick={() => onPick(null, null)}>
            {t({ id: 'catalogacao.serialDetail.filiation.clear' })}
          </button>
        </div>
      ) : (
        <>
          <input className="ab-input" type="search" value={q} disabled={disabled}
            placeholder={t({ id: 'catalogacao.serialDetail.filiation.searchPh' })}
            onChange={e => setQ(e.target.value)} />
          {res.length > 0 && (
            <div style={resultsBox}>
              {res.map(r => (
                <button key={r.id} type="button" style={resultBtn}
                  onClick={() => { onPick(r.id, r.uniform_title); setQ(''); setRes([]); }}>
                  {r.uniform_title}
                  {r.start_year && <span style={muted}> · {r.start_year}</span>}
                </button>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}

export default function SerialDetailEditor({ serial, myLibraries, onChanged }) {
  const { formatMessage: t, locale } = useIntl();
  const [detail, setDetail] = useState(null);
  const [form, setForm] = useState(null);
  const [issues, setIssues] = useState([]);
  const [holdings, setHoldings] = useState([]);
  const [hDrafts, setHDrafts] = useState({});
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState(null);
  const [attachQ, setAttachQ] = useState('');
  const [attachRes, setAttachRes] = useState([]);

  const load = useCallback(async () => {
    const api = supabase.schema('api');
    const [det, iss, hold] = await Promise.all([
      api.rpc('serial_detail_v1', { p_slug: serial.slug }),
      api.rpc('serial_issues_v1', { p_serial_id: serial.id }),
      api.from('serial_holdings_public_v1').select('*').eq('serial_id', serial.id),
    ]);
    const d = Array.isArray(det.data) ? det.data[0] : det.data;
    setDetail(d || null);
    setIssues(Array.isArray(iss.data) ? iss.data : []);
    const hrows = Array.isArray(hold.data) ? hold.data : [];
    setHoldings(hrows);
    if (d) {
      const f = { uniform_title: d.uniform_title || '', is_continuing: d.is_continuing !== false,
        scope_note: d.scope_note || '',
        alt: formsFor(d.alt_i18n, locale) };
      for (const k of TEXT_FIELDS) f[k] = d[k] || '';
      setForm(f);
    }
    const next = {};
    for (const lib of myLibraries) {
      const row = hrows.find(r => r.library_id === lib.library_id);
      next[lib.library_id] = {
        statement: row?.statement || '', gaps_note: row?.gaps_note || '',
        completeness: row?.completeness || 'desconhecida',
        is_public: row ? row.is_public !== false : true,
      };
    }
    setHDrafts(next);
  }, [serial.id, serial.slug, locale, myLibraries]);

  useEffect(() => { load(); }, [load]);

  // Recherche de fascicules NON rattachés, pour en rattacher un existant.
  // Bornée aux types que la garde G3 autorise : inutile de proposer un livre
  // que le trigger refusera.
  useEffect(() => {
    const s = attachQ.trim();
    if (s.length < 2) { setAttachRes([]); return; }
    const h = setTimeout(async () => {
      const { data } = await supabase.from('books')
        .select('id, titulo, ano, numero, bib_ref')
        .is('serial_id', null)
        .in('tipo_material', ['periodico', 'artigo'])
        .ilike('titulo', `%${s}%`)
        .limit(8);
      setAttachRes(Array.isArray(data) ? data : []);
    }, 300);
    return () => clearTimeout(h);
  }, [attachQ]);

  function set(k, v) { setForm(prev => ({ ...prev, [k]: v })); }

  async function call(key, fn, okKey, failKey) {
    setBusy(key); setMsg(null);
    const { error } = await fn();
    if (error) setMsg({ text: localizeError(error, t, failKey), kind: 'error' });
    else { setMsg({ text: t({ id: okKey }), kind: 'ok' }); await load(); onChanged?.(); }
    setBusy(null);
  }

  async function saveDescription() {
    const payload = { uniform_title: form.uniform_title.trim(), is_continuing: form.is_continuing,
      scope_note: form.scope_note.trim() || null,
      // Les autres locales sont réinjectées telles quelles : enregistrer dans
      // une langue ne doit pas effacer le travail fait dans une autre.
      alt_i18n: mergeForms(detail?.alt_i18n, locale, form.alt) };
    for (const k of TEXT_FIELDS) payload[k] = form[k].trim() || null;
    await call('desc',
      () => supabase.schema('api').rpc('fn_serial_update', { p_serial_id: serial.id, p_payload: payload }),
      'catalogacao.serialDetail.saved', 'catalogacao.serialDetail.saveFailed');
  }

  async function saveFiliation(predId, succId) {
    await call('fil',
      () => supabase.schema('api').rpc('fn_serial_set_filiation', {
        p_serial_id: serial.id, p_predecessor_id: predId, p_successor_id: succId }),
      'catalogacao.serialDetail.filiation.saved', 'catalogacao.serialDetail.filiation.failed');
  }

  async function attach(bookId) {
    setAttachQ(''); setAttachRes([]);
    await call('att',
      () => supabase.schema('api').rpc('fn_serial_attach_issue', { p_book_id: bookId, p_serial_id: serial.id }),
      'catalogacao.serialDetail.issues.attached', 'catalogacao.serialDetail.issues.attachFailed');
  }

  async function detachIssue(bookId) {
    await call(`det-${bookId}`,
      () => supabase.schema('api').rpc('fn_serial_detach_issue', { p_book_id: bookId }),
      'catalogacao.serialDetail.issues.detached', 'catalogacao.serialDetail.issues.attachFailed');
  }

  async function saveHoldings(libraryId) {
    const d = hDrafts[libraryId];
    await call(`hold-${libraryId}`,
      () => supabase.schema('api').rpc('fn_serial_upsert_holdings', {
        p_serial_id: serial.id, p_library_id: libraryId,
        p_statement: d.statement || null, p_gaps_note: d.gaps_note || null,
        p_completeness: d.completeness, p_is_public: d.is_public }),
      'catalogacao.serialGov.holdings.saved', 'catalogacao.serialGov.holdings.failed');
  }

  if (!form) return <div style={sub}>{t({ id: 'common.loading' })}</div>;

  const issueLabel = (it) => [it.volume && `vol. ${it.volume}`, it.numero && `n° ${it.numero}`,
    it.fasciculo, it.data_edicao].filter(Boolean).join(' · ') || it.ano || it.titulo;

  return (
    <div style={{ paddingLeft: 18 }}>
      {msg && <div style={{ fontSize: '.82rem', margin: '4px 0 8px', color: msg.kind === 'error' ? '#f87171' : '#4ade80' }}>{msg.text}</div>}

      {/* ── 1. Description ─────────────────────────────────────────────── */}
      <div style={secTitle}>{t({ id: 'catalogacao.serialDetail.description' })}</div>
      <div style={grid2}>
        <div style={{ gridColumn: '1 / -1' }}>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.uniformTitle' })}</label>
          <input className="ab-input" value={form.uniform_title} onChange={e => set('uniform_title', e.target.value)} />
          <div style={sub}>{t({ id: 'catalogacao.serialDetail.slugFixed' }, { slug: serial.slug })}</div>
        </div>
        <div>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.sortTitle' })}</label>
          <input className="ab-input" value={form.sort_title} onChange={e => set('sort_title', e.target.value)} />
        </div>
        <div>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.emitter' })}</label>
          <input className="ab-input" value={form.emitter_org} onChange={e => set('emitter_org', e.target.value)} />
        </div>
        <div>
          <label style={lbl}>ISSN</label>
          <input className="ab-input" value={form.issn} onChange={e => set('issn', e.target.value)} placeholder="0251-1479" />
        </div>
        <div>
          <label style={lbl}>ISSN-L</label>
          <input className="ab-input" value={form.issn_l} onChange={e => set('issn_l', e.target.value)} />
          <div style={sub}>{t({ id: 'catalogacao.serialDetail.issnLHint' })}</div>
        </div>
        <div>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.startYear' })}</label>
          <input className="ab-input" value={form.start_year} onChange={e => set('start_year', e.target.value)} placeholder="1896" />
        </div>
        <div>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.endYear' })}</label>
          <input className="ab-input" value={form.end_year} onChange={e => set('end_year', e.target.value)} disabled={form.is_continuing} />
          <label style={{ ...sub, display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
            <input type="checkbox" checked={form.is_continuing}
              onChange={e => set('is_continuing', e.target.checked)} />
            {t({ id: 'catalogacao.serialDetail.stillRunning' })}
          </label>
        </div>
        <div>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.place' })}</label>
          <input className="ab-input" value={form.place_publication} onChange={e => set('place_publication', e.target.value)} />
        </div>
        <div>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.frequency' })}</label>
          {/* D2/1 (verdict 03/09) : vocabulaire LIBRE, avec une liste de suggestions non
              contraignante — la liste ne se ferme que le jour où un fonds réel (Anarchief)
              en fait apparaître le besoin. */}
          <input className="ab-input" list="serial-periodicidade-suggestions" value={form.periodicidade}
            onChange={e => set('periodicidade', e.target.value)} placeholder={t({ id: 'catalogacao.serialDetail.frequencyOption.quarterly' })} />
          <datalist id="serial-periodicidade-suggestions">
            {['weekly', 'biweekly', 'monthly', 'bimonthly', 'quarterly', 'biannual', 'annual', 'irregular'].map(k => (
              <option key={k} value={t({ id: `catalogacao.serialDetail.frequencyOption.${k}` })} />
            ))}
          </datalist>
        </div>
        <div>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.language' })}</label>
          <input className="ab-input" value={form.language} onChange={e => set('language', e.target.value)} placeholder="fr" />
        </div>
        <div>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.country' })}</label>
          <input className="ab-input" value={form.country_code} onChange={e => set('country_code', e.target.value)} placeholder="BR" />
        </div>
        <div style={{ gridColumn: '1 / -1' }}>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.altForms' }, { locale })}</label>
          <textarea className="ab-input" rows={2} value={form.alt} onChange={e => set('alt', e.target.value)} />
          <div style={sub}>{t({ id: 'catalogacao.serialDetail.altFormsHint' })}</div>
        </div>
        <div style={{ gridColumn: '1 / -1' }}>
          <label style={lbl}>{t({ id: 'catalogacao.serialDetail.scopeNote' })}</label>
          <textarea className="ab-input" rows={2} value={form.scope_note} onChange={e => set('scope_note', e.target.value)} />
        </div>
      </div>
      <button className="ab-button ab-button--secondary" style={btnSm}
        disabled={busy === 'desc'} onClick={saveDescription}>
        {t({ id: 'catalogacao.serialDetail.save' })}
      </button>

      {/* ── 2. Filiation ───────────────────────────────────────────────── */}
      <div style={secTitle}>{t({ id: 'catalogacao.serialDetail.filiation' })}</div>
      <p style={{ ...sub, marginTop: 0 }}>{t({ id: 'catalogacao.serialDetail.filiation.intro' })}</p>
      <div style={grid2}>
        <SerialLookup
          label={t({ id: 'catalogacao.serialDetail.filiation.predecessor' })}
          value={detail?.predecessor_id} valueLabel={detail?.predecessor_title}
          disabled={busy === 'fil'}
          onPick={(id) => saveFiliation(id, detail?.successor_id ?? null)} />
        <SerialLookup
          label={t({ id: 'catalogacao.serialDetail.filiation.successor' })}
          value={detail?.successor_id} valueLabel={detail?.successor_title}
          disabled={busy === 'fil'}
          onPick={(id) => saveFiliation(detail?.predecessor_id ?? null, id)} />
      </div>

      {/* ── 3. Numéros ─────────────────────────────────────────────────── */}
      <div style={secTitle}>
        {t({ id: 'catalogacao.serialDetail.issues' }, { count: issues.length })}
      </div>
      {issues.length === 0 ? (
        <div style={sub}>{t({ id: 'catalogacao.serialDetail.issues.none' })}</div>
      ) : (
        <ul style={{ listStyle: 'none', padding: 0, margin: '0 0 8px' }}>
          {issues.map(it => (
            <li key={`${it.book_id}-${it.library_id || 'na'}`} style={issueRow}>
              <Link to={`/livro/${it.book_id}`} style={{ color: '#93c5fd', fontSize: '.84rem' }}>
                {issueLabel(it)}
              </Link>
              <span style={muted}>{it.library_name ? ` · ${it.library_name}` : ''}</span>
              <button type="button" className="ab-button ab-button--ghost" style={btnXs}
                disabled={busy === `det-${it.book_id}`} onClick={() => detachIssue(it.book_id)}>
                {t({ id: 'catalogacao.serialDetail.issues.detach' })}
              </button>
            </li>
          ))}
        </ul>
      )}
      <label style={lbl}>{t({ id: 'catalogacao.serialDetail.issues.attach' })}</label>
      <input className="ab-input" type="search" value={attachQ}
        placeholder={t({ id: 'catalogacao.serialDetail.issues.attachPh' })}
        onChange={e => setAttachQ(e.target.value)} />
      {attachRes.length > 0 && (
        <div style={resultsBox}>
          {attachRes.map(b => (
            <button key={b.id} type="button" style={resultBtn} disabled={busy === 'att'}
              onClick={() => attach(b.id)}>
              {b.titulo}
              <span style={muted}> · {[b.numero && `n° ${b.numero}`, b.ano, b.bib_ref].filter(Boolean).join(' · ')}</span>
            </button>
          ))}
        </div>
      )}

      {/* ── 4. État de collection ──────────────────────────────────────── */}
      <div style={secTitle}>{t({ id: 'catalogacao.serialGov.holdings' })}</div>
      <p style={{ ...sub, marginTop: 0 }}>{t({ id: 'catalogacao.serialGov.holdings.declaredWins' })}</p>
      {holdings.filter(r => !myLibraries.some(l => l.library_id === r.library_id)).map(r => (
        <div key={r.library_id} style={otherLib}>
          <strong>{r.library_name || r.library_slug}</strong>
          <div>{r.has_statement ? r.statement : t({ id: 'catalogacao.serialGov.holdings.computed' }, {
            first: r.computed_first || '?', last: r.computed_last || '?', count: r.computed_count || 0 })}</div>
        </div>
      ))}
      {myLibraries.length === 0 ? (
        <div style={sub}>{t({ id: 'catalogacao.serialGov.holdings.noLibrary' })}</div>
      ) : myLibraries.map(lib => {
        const d = hDrafts[lib.library_id] || { statement: '', gaps_note: '', completeness: 'desconhecida', is_public: true };
        const row = holdings.find(r => r.library_id === lib.library_id);
        const setD = (patch) => setHDrafts(p => ({ ...p, [lib.library_id]: { ...p[lib.library_id], ...patch } }));
        return (
          <div key={lib.library_id} style={myLib}>
            <div style={{ fontWeight: 600, marginBottom: 4 }}>{lib.library_name || lib.library_slug}</div>
            <div style={{ ...sub, marginBottom: 6 }}>
              {t({ id: 'catalogacao.serialGov.holdings.computed' }, {
                first: row?.computed_first || '?', last: row?.computed_last || '?', count: row?.computed_count || 0 })}
            </div>
            <label style={lbl}>{t({ id: 'catalogacao.serialGov.holdings.statement' })}</label>
            <textarea className="ab-input" rows={2} value={d.statement}
              placeholder={t({ id: 'catalogacao.serialGov.holdings.statementPh' })}
              onChange={e => setD({ statement: e.target.value })} />
            <label style={lbl}>{t({ id: 'catalogacao.serialGov.holdings.gaps' })}</label>
            <input className="ab-input" value={d.gaps_note} onChange={e => setD({ gaps_note: e.target.value })} />
            <div style={{ display: 'flex', gap: 14, alignItems: 'flex-end', flexWrap: 'wrap', marginTop: 6 }}>
              <div>
                <label style={lbl}>{t({ id: 'catalogacao.serialGov.holdings.completeness' })}</label>
                <select className="ab-input" value={d.completeness} onChange={e => setD({ completeness: e.target.value })}>
                  {COMPLETENESS.map(c => (
                    <option key={c} value={c}>
                      {c === 'desconhecida' ? t({ id: 'catalogacao.serialGov.holdings.unknown' })
                        : t({ id: `serial.completeness.${c}` })}
                    </option>
                  ))}
                </select>
              </div>
              <label style={{ fontSize: '.8rem', display: 'flex', alignItems: 'center', gap: 6 }}>
                <input type="checkbox" checked={d.is_public} onChange={e => setD({ is_public: e.target.checked })} />
                {t({ id: 'catalogacao.serialGov.holdings.isPublic' })}
              </label>
              <button className="ab-button ab-button--secondary" style={btnSm}
                disabled={busy === `hold-${lib.library_id}`} onClick={() => saveHoldings(lib.library_id)}>
                {t({ id: 'catalogacao.serialGov.holdings.save' })}
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}

const secTitle = { fontSize: '.76rem', textTransform: 'uppercase', letterSpacing: '.05em',
  color: 'var(--brand-muted, #999)', fontWeight: 700, margin: '16px 0 6px' };
const grid2 = { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(220px, 100%), 1fr))', gap: 10 };
const sub = { fontSize: '.74rem', color: 'var(--brand-muted, #999)', marginTop: 2 };
const muted = { fontSize: '.74rem', color: 'var(--brand-muted, #999)' };
const lbl = { display: 'block', fontSize: '.74rem', color: 'var(--brand-muted, #999)', margin: '6px 0 2px' };
const btnSm = { marginTop: 8, fontSize: '.75rem', padding: '4px 10px' };
const btnXs = { fontSize: '.7rem', padding: '2px 8px', marginLeft: 6 };
const chip = { display: 'inline-flex', alignItems: 'center', padding: '2px 8px', fontSize: '.8rem',
  borderRadius: 999, background: 'rgba(255,255,255,.08)' };
const issueRow = { display: 'flex', alignItems: 'center', gap: 4, flexWrap: 'wrap', padding: '2px 0' };
const otherLib = { fontSize: '.8rem', color: 'var(--brand-muted, #bbb)', borderLeft: '2px solid rgba(255,255,255,.12)', paddingLeft: 10, marginBottom: 8 };
const myLib = { border: '1px solid rgba(255,255,255,.12)', borderRadius: 8, padding: '10px 12px', marginBottom: 10 };
const resultsBox = { marginTop: 4, border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))', borderRadius: 6, background: 'var(--brand-panel-bg-strong, rgba(10,10,10,.94))', maxHeight: 220, overflowY: 'auto' };
const resultBtn = { display: 'block', width: '100%', textAlign: 'left', padding: '5px 10px', background: 'transparent', border: 'none', borderBottom: '1px solid rgba(255,255,255,.08)', color: 'var(--brand-text, #f5f2ea)', cursor: 'pointer', fontSize: '.82rem' };
