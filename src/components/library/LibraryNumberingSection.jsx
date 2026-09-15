import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// ─────────────────────────────────────────────────────────────────────────
// LibraryNumberingSection — la serie de numeros d'inventaire (tombo) et la
// cote d'une bibliotheque, reglees depuis l'ecran (backlog E21, 15/09/2026).
//
// Jusqu'ici `libraries.tombo_pattern` et `bib_ref_prefix/pad/auto` n'avaient
// aucun ecran : trois bibliotheques reglees en SQL a la main, et une
// bibliotheque nee dans l'app incapable de publier un exemplaire. Deux RPC :
//   fn_library_numbering_get(lib)  — staff de la biblio ou admin reseau
//   fn_library_numbering_set(...)  — coordination de la biblio ou admin
// Les gardes vivent en base (prefixe obligatoire, unique dans le reseau,
// fige des qu'un exemplaire l'a utilise) ; l'ecran les explique avant.
//
// Props : libraryId (uuid), canEdit (bool), compact (bool, pour la page Reseau)
// ─────────────────────────────────────────────────────────────────────────

const ls = { fontSize: '.75rem', color: 'var(--brand-muted, #aaa)', display: 'block', marginBottom: 3 };
const fs = { width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };

function pad(n, width) {
  const s = String(n);
  return width > 0 && s.length < width ? '0'.repeat(width - s.length) + s : s;
}

export function tomboExample(form, n = 1) {
  const year = form.tombo_year ? String(new Date().getFullYear()) + (form.tombo_sep || '') : '';
  return `${(form.tombo_prefix || '').trim()}${year}${pad(n, Number(form.tombo_pad) || 0)}`;
}

export function bibRefExample(form, n = 1) {
  return `${(form.bib_ref_prefix || '').trim()}${pad(n, Math.max(Number(form.bib_ref_pad) || 1, 1))}`;
}

export default function LibraryNumberingSection({ libraryId, canEdit = false, compact = false }) {
  const { formatMessage: t } = useIntl();
  const [state, setState] = useState(null);     // reponse de fn_library_numbering_get
  const [form, setForm] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState(null);

  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_library_numbering_get', { p_library_id: libraryId });
      if (error) throw error;
      setState(data);
      setForm({
        tombo_prefix: data?.tombo_prefix || '',
        tombo_year: data?.tombo_year === true,
        tombo_sep: data?.tombo_sep || '',
        tombo_pad: data?.tombo_pad ?? 0,
        bib_ref_prefix: data?.bib_ref_prefix || '',
        bib_ref_pad: data?.bib_ref_pad ?? 5,
        bib_ref_auto: data?.bib_ref_auto !== false,
      });
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, t]);
  useEffect(() => { load(); }, [load]);

  function set(key, value) { setForm(prev => ({ ...prev, [key]: value })); }

  async function save() {
    if (!form) return;
    setSaving(true);
    setMsg(null);
    try {
      const { data, error } = await supabase.rpc('fn_library_numbering_set', {
        p_library_id: libraryId,
        p_tombo_prefix: form.tombo_prefix,
        p_tombo_year: form.tombo_year === true,
        p_tombo_sep: form.tombo_sep || '',
        p_tombo_pad: Number(form.tombo_pad) || 0,
        p_bib_ref_prefix: form.bib_ref_prefix || '',
        p_bib_ref_pad: Math.max(Number(form.bib_ref_pad) || 1, 1),
        p_bib_ref_auto: form.bib_ref_auto !== false,
      });
      if (error) throw error;
      setState(data);
      setMsg({ text: t({ id: 'biblioteca.numbering.saved' }, { next: data?.next_tombo || '' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  const frozen = state?.tombo_frozen === true;
  const configured = !!state?.tombo_prefix;
  const bx = { padding: compact ? 12 : 16, marginBottom: 16, borderRadius: 10, background: 'var(--brand-panel-bg, rgba(16,16,16,.86))', border: '1px solid var(--brand-panel-border, rgba(255,255,255,.1))' };

  return (
    <div style={bx}>
      <h4 style={{ margin: '0 0 4px' }}>{t({ id: 'biblioteca.numbering.title' })}</h4>
      <p style={{ margin: '0 0 12px', fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'biblioteca.numbering.hint' })}</p>

      {loading && <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'common.loading' })}</p>}

      {!loading && state && !configured && (
        <p style={{ margin: '0 0 12px', fontSize: '.85rem', color: '#fbbf24' }}>{t({ id: 'biblioteca.numbering.notConfigured' })}</p>
      )}

      {!loading && form && (
        <>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 10, marginBottom: 10 }}>
            <div className="cat-field" style={{ minWidth: 0 }}>
              <label style={ls}>{t({ id: 'biblioteca.numbering.tomboPrefix' })}</label>
              <input type="text" value={form.tombo_prefix} maxLength={24} disabled={!canEdit || frozen}
                onChange={e => set('tombo_prefix', e.target.value)} style={fs} placeholder="SOL-" />
            </div>
            <div className="cat-field" style={{ minWidth: 0 }}>
              <label style={{ ...ls, display: 'flex', gap: 8, alignItems: 'center', marginTop: 18 }}>
                <input type="checkbox" checked={form.tombo_year} disabled={!canEdit || frozen}
                  onChange={e => set('tombo_year', e.target.checked)} />
                {t({ id: 'biblioteca.numbering.tomboYear' })}
              </label>
            </div>
            <div className="cat-field" style={{ minWidth: 0 }}>
              <label style={ls}>{t({ id: 'biblioteca.numbering.tomboSep' })}</label>
              <input type="text" value={form.tombo_sep} maxLength={3} disabled={!canEdit || frozen || !form.tombo_year}
                onChange={e => set('tombo_sep', e.target.value)} style={fs} placeholder="." />
            </div>
            <div className="cat-field" style={{ minWidth: 0 }}>
              <label style={ls}>{t({ id: 'biblioteca.numbering.tomboPad' })}</label>
              <input type="number" min={0} max={8} value={form.tombo_pad} disabled={!canEdit}
                onChange={e => set('tombo_pad', e.target.value)} style={fs} />
            </div>
          </div>

          <div style={{ fontSize: '.85rem', marginBottom: 12, display: 'flex', flexWrap: 'wrap', gap: '4px 18px' }}>
            <span>{t({ id: 'biblioteca.numbering.example' })} <code style={{ fontWeight: 700 }}>{form.tombo_prefix.trim() ? tomboExample(form, 1) : '—'}</code></span>
            <span style={{ color: 'var(--brand-muted, #aaa)' }}>
              {t({ id: 'biblioteca.numbering.next' })} <code>{state?.next_tombo || '—'}</code>
              {state?.last_tombo ? <> · {t({ id: 'biblioteca.numbering.last' })} <code>{state.last_tombo}</code></> : null}
              {' · '}{t({ id: 'biblioteca.numbering.exemplars' }, { count: Number(state?.exemplars_count ?? 0) })}
            </span>
          </div>
          {frozen && (
            <p style={{ margin: '0 0 12px', fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'biblioteca.numbering.frozen' })}</p>
          )}

          <h5 style={{ margin: '8px 0 6px', fontSize: '.85rem' }}>{t({ id: 'biblioteca.numbering.bibRefTitle' })}</h5>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 10, marginBottom: 10 }}>
            <div className="cat-field" style={{ minWidth: 0 }}>
              <label style={ls}>{t({ id: 'biblioteca.numbering.bibRefPrefix' })}</label>
              <input type="text" value={form.bib_ref_prefix} maxLength={24} disabled={!canEdit}
                onChange={e => set('bib_ref_prefix', e.target.value)} style={fs} placeholder="SOL-" />
            </div>
            <div className="cat-field" style={{ minWidth: 0 }}>
              <label style={ls}>{t({ id: 'biblioteca.numbering.bibRefPad' })}</label>
              <input type="number" min={1} max={10} value={form.bib_ref_pad} disabled={!canEdit}
                onChange={e => set('bib_ref_pad', e.target.value)} style={fs} />
            </div>
            <div className="cat-field" style={{ minWidth: 0 }}>
              <label style={{ ...ls, display: 'flex', gap: 8, alignItems: 'center', marginTop: 18 }}>
                <input type="checkbox" checked={form.bib_ref_auto} disabled={!canEdit}
                  onChange={e => set('bib_ref_auto', e.target.checked)} />
                {t({ id: 'biblioteca.numbering.bibRefAuto' })}
              </label>
            </div>
          </div>
          <div style={{ fontSize: '.85rem', marginBottom: 12 }}>
            {t({ id: 'biblioteca.numbering.example' })} <code style={{ fontWeight: 700 }}>{bibRefExample(form, 1)}</code>
            <span style={{ color: 'var(--brand-muted, #aaa)' }}> · {t({ id: 'biblioteca.numbering.next' })} <code>{state?.next_bib_ref || '—'}</code></span>
          </div>

          {canEdit && (
            <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
              <button className="ab-button" onClick={save} disabled={saving || !form.tombo_prefix.trim()}>
                {saving ? t({ id: 'common.saving' }) : t({ id: 'common.save' })}
              </button>
              <span style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'biblioteca.numbering.uniqueHint' })}</span>
            </div>
          )}
        </>
      )}

      {msg && <div style={{ marginTop: 10, fontSize: '.82rem', color: msg.kind === 'error' ? '#f87171' : '#4ade80' }}>{msg.text}</div>}
    </div>
  );
}
