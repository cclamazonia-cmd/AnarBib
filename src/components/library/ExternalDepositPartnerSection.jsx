import { useState, useCallback, useRef } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

/**
 * ExternalDepositPartnerSection
 * --------------------------------------------------------------------------
 * Enregistre un partenaire EXTERNE de dépôt (ex. CIRA Marseille, export Zotero)
 * dans l'onglet Relações de Biblioteca. Crée une vraie entité catalog_partners
 * + la source de dépôt liée de la bibliothèque, via la RPC
 * public.fn_partner_register_deposit_source (inc. B1). Le partenaire apparaît
 * ensuite comme source sélectionnable dans Importações (dépôt format maison).
 *
 * Remplace le « + » texte-libre (cassé) de la page Import par la voie noble.
 * Détection de doublon : fn_partner_search (suggestions pendant la saisie).
 *
 * Props : libraryId (uuid, non utilisé par la RPC qui lit my_access mais gardé
 *         pour cohérence), canEdit (isCoord — masque la section sinon).
 */

const box = {
  background: 'var(--brand-panel-bg, rgba(20,20,20,.55))',
  border: '1px solid var(--brand-panel-border, rgba(255,255,255,.12))',
  borderRadius: 12, padding: 16, marginBottom: 16,
};
const muted = { color: 'var(--brand-muted, #9a958c)', fontSize: '.82rem' };
const label = { display: 'block', fontSize: '.78rem', color: 'var(--brand-muted, #c9c3b8)', marginBottom: 3, fontWeight: 600 };
const input = {
  width: '100%', padding: '8px 10px', borderRadius: 8, boxSizing: 'border-box',
  background: 'rgba(0,0,0,.28)', border: '1px solid rgba(255,255,255,.15)',
  color: 'var(--brand-text, #f5f2ea)', fontSize: '.88rem',
};
const btnPrimary = {
  padding: '9px 18px', borderRadius: 8, fontWeight: 700, fontSize: '.88rem',
  background: 'var(--brand-color-primary, #7a0b14)', color: '#fff',
  border: 'none', cursor: 'pointer',
};

export default function ExternalDepositPartnerSection({ libraryId, canEdit }) {
  void libraryId;
  const intl = useIntl();
  const t = (d, v) => intl.formatMessage(d, v);

  const [name, setName] = useState('');
  const [baseUrl, setBaseUrl] = useState('');
  const [country, setCountry] = useState('');
  const [notes, setNotes] = useState('');
  const [importAuth, setImportAuth] = useState(true);
  const [suggestions, setSuggestions] = useState([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState(null); // { kind: 'ok'|'warn', text }
  const searchTimer = useRef(null);

  const runSearch = useCallback((q) => {
    if (searchTimer.current) clearTimeout(searchTimer.current);
    if (!q || q.trim().length < 2) { setSuggestions([]); return; }
    searchTimer.current = setTimeout(async () => {
      const { data, error } = await supabase.rpc('fn_partner_search', { p_query: q.trim() });
      if (!error && Array.isArray(data)) setSuggestions(data);
    }, 300);
  }, []);

  function onNameChange(e) {
    const v = e.target.value;
    setName(v);
    runSearch(v);
  }

  async function handleRegister() {
    if (!name.trim()) return;
    setBusy(true);
    setMsg(null);
    try {
      const { data, error } = await supabase.rpc('fn_partner_register_deposit_source', {
        p_display_name: name.trim(),
        p_base_url: baseUrl.trim(),
        p_country_code: country.trim() || null,
        p_notes: notes.trim() || null,
        p_import_authorized: importAuth,
      });
      if (error) throw error;
      setMsg({
        kind: 'ok',
        text: t({ id: data?.partner_created ? 'biblioteca.extPartner.created' : 'biblioteca.extPartner.linked' }, { name: name.trim() }),
      });
      setName(''); setBaseUrl(''); setCountry(''); setNotes(''); setSuggestions([]);
    } catch (err) {
      setMsg({ kind: 'warn', text: localizeError(err, t) || t({ id: 'biblioteca.extPartner.error' }) });
    } finally { setBusy(false); }
  }

  if (!canEdit) return null;

  return (
    <div style={box}>
      <h4 style={{ margin: '0 0 4px' }}>{t({ id: 'biblioteca.extPartner.title' })}</h4>
      <div style={{ ...muted, marginBottom: 12 }}>{t({ id: 'biblioteca.extPartner.hint' })}</div>

      {msg && (
        <div className={msg.kind === 'ok' ? 'cat-pill ok' : 'cat-pill warn'}
          style={{ display: 'block', marginBottom: 10, fontSize: '.78rem' }}>
          {msg.text}
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)', gap: 10 }}>
        <div style={{ gridColumn: 'span 2' }}>
          <label style={label}>{t({ id: 'biblioteca.extPartner.name' })}</label>
          <input style={input} value={name} onChange={onNameChange}
            placeholder={t({ id: 'biblioteca.extPartner.namePlaceholder' })} />
        </div>
        <div>
          <label style={label}>{t({ id: 'biblioteca.extPartner.country' })}</label>
          <input style={input} value={country} onChange={e => setCountry(e.target.value)}
            placeholder="FR" maxLength={2} />
        </div>
        <div>
          <label style={label}>{t({ id: 'biblioteca.extPartner.baseUrl' })}</label>
          <input style={input} value={baseUrl} onChange={e => setBaseUrl(e.target.value)}
            placeholder="https://…" />
        </div>
        <div style={{ gridColumn: 'span 2' }}>
          <label style={label}>{t({ id: 'biblioteca.extPartner.notes' })}</label>
          <input style={input} value={notes} onChange={e => setNotes(e.target.value)} />
        </div>
      </div>

      {suggestions.length > 0 && (
        <div style={{ marginTop: 10 }}>
          <div style={{ ...muted, marginBottom: 4 }}>{t({ id: 'biblioteca.extPartner.dupHint' })}</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {suggestions.map(s => (
              <span key={s.id} className="cat-pill" style={{ fontSize: '.72rem' }}>
                {s.display_name}{s.country_code ? ` · ${s.country_code}` : ''}
              </span>
            ))}
          </div>
        </div>
      )}

      <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 12, fontSize: '.85rem', cursor: 'pointer' }}>
        <input type="checkbox" checked={importAuth} onChange={e => setImportAuth(e.target.checked)} />
        {t({ id: 'biblioteca.extPartner.importAuth' })}
      </label>

      <div style={{ marginTop: 12 }}>
        <button style={{ ...btnPrimary, opacity: (busy || !name.trim()) ? 0.5 : 1 }}
          onClick={handleRegister} disabled={busy || !name.trim()}>
          {busy ? t({ id: 'biblioteca.extPartner.registering' }) : t({ id: 'biblioteca.extPartner.register' })}
        </button>
      </div>
    </div>
  );
}
