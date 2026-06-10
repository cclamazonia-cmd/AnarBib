// =============================================================================
// LibraryContactProfileSection.jsx
// =============================================================================
// EA-20 du chantier-cadre Biblioteca (rattache a la fin de l'etape 10).
// Editeur du profil de contact d'une biblioteca : les coordonnees humaines
// (personne ou collectif a joindre) affichees aux autres bibliotheques du
// reseau pour le PEB et les trocas interbibliotecas.
//
// A NE PAS CONFONDRE avec l'identite e-mail de l'onglet Comunicacoes
// (display_name, contact_email d'envoi, reply_to) : celle-la est l'adresse
// TECHNIQUE d'envoi de la biblioteca. Le profil de contact ci-dessous est le
// contact HUMAIN - qui joindre, comment, ou.
//
// Structure : table library_contact_profiles (1 ligne par biblioteca), 7
// champs : contact_name, contact_role, contact_email, contact_phone,
// contact_whatsapp, contact_alternate, postal_address.
//
// Doctrine RPC v3 (calque sur DocumentGovernanceSection / EA-08) :
//   - lecture : supabase.from('library_contact_profiles') simple, autorisee
//     (lecture protegee par RLS : can_manage_library_contact_profile)
//   - ecriture : RPC upsert_library_contact_profile(p_library_id, p_profile)
//     (action DB -> RPC obligatoire ; la RPC fait l'upsert on conflict)
//
// Aucun DDL : la table, les RLS et la RPC d'upsert preexistent.
// =============================================================================

import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// Les 7 champs editables du profil, dans l'ordre d'affichage.
const FIELDS = [
  'contact_name',
  'contact_role',
  'contact_email',
  'contact_phone',
  'contact_whatsapp',
  'contact_alternate',
  'postal_address',
];

// Normalise une ligne library_contact_profiles en etat de formulaire :
// chaque champ devient une chaine (jamais null) pour les inputs controles.
function normalizeProfile(row) {
  const r = row && typeof row === 'object' ? row : {};
  const out = {};
  for (const f of FIELDS) {
    out[f] = typeof r[f] === 'string' ? r[f] : '';
  }
  return out;
}

export default function LibraryContactProfileSection({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [form, setForm] = useState(() => normalizeProfile(null));

  // ── Chargement du profil (lecture simple .from(), doctrine RPC v3) ────────
  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase
        .from('library_contact_profiles')
        .select('contact_name, contact_role, contact_email, contact_phone, contact_whatsapp, contact_alternate, postal_address')
        .eq('library_id', libraryId)
        .maybeSingle();
      if (error) throw error;
      setForm(normalizeProfile(data));
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, t]);

  useEffect(() => { load(); }, [load]);

  // ── Sauvegarde via RPC upsert_library_contact_profile ─────────────────────
  async function save() {
    if (!canEdit) return;
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      // La RPC attend un p_profile jsonb ; elle trim et convertit '' -> null.
      const profile = {};
      for (const f of FIELDS) profile[f] = form[f];
      const { error } = await supabase.rpc('upsert_library_contact_profile', {
        p_library_id: libraryId,
        p_profile: profile,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.contactProfile.saved' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  const setField = (key, value) => setForm(f => ({ ...f, [key]: value }));

  // ── Styles (coherents avec le theme sombre AnarBib) ───────────────────────
  const styles = useMemo(() => ({
    fieldLabel: {
      display: 'block', fontSize: '.78rem',
      color: 'var(--brand-muted, #ccc)', marginBottom: 4,
    },
    input: {
      width: '100%', padding: '8px 10px', borderRadius: 8,
      border: '1px solid rgba(255,255,255,.12)',
      background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem',
    },
    textarea: {
      width: '100%', padding: '8px 10px', borderRadius: 8,
      border: '1px solid rgba(255,255,255,.12)',
      background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem',
      resize: 'vertical', minHeight: 52, fontFamily: 'inherit',
    },
  }), []);

  if (loading) {
    return <div style={{ fontSize: '.88rem', color: 'var(--brand-muted)' }}>
      {t({ id: 'common.loading' })}
    </div>;
  }

  // Champ texte simple (input). type : 'text' | 'email' | 'tel'.
  const textField = (key, type = 'text') => (
    <div className="cat-field">
      <label style={styles.fieldLabel}>{t({ id: `biblioteca.contactProfile.${key}` })}</label>
      <input type={type} disabled={!canEdit} style={styles.input}
        value={form[key]}
        placeholder={t({ id: `biblioteca.contactProfile.${key}.placeholder` })}
        onChange={e => setField(key, e.target.value)} />
    </div>
  );

  return (
    <div>
      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginBottom: 12 }}>
        {t({ id: 'biblioteca.contactProfile.intro' })}
      </div>

      <div className="cat-book-grid" style={{ marginBottom: 10 }}>
        {textField('contact_name')}
        {textField('contact_role')}
        {textField('contact_email', 'email')}
        {textField('contact_phone', 'tel')}
        {textField('contact_whatsapp', 'tel')}
        {textField('contact_alternate')}
      </div>

      {/* Adresse postale : champ multi-ligne */}
      <div className="cat-field" style={{ marginBottom: 12 }}>
        <label style={styles.fieldLabel}>
          {t({ id: 'biblioteca.contactProfile.postal_address' })}
        </label>
        <textarea disabled={!canEdit} style={styles.textarea}
          value={form.postal_address}
          placeholder={t({ id: 'biblioteca.contactProfile.postal_address.placeholder' })}
          onChange={e => setField('postal_address', e.target.value)} />
      </div>

      {canEdit && (
        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
          <button className="cat-btn secondary" onClick={load} disabled={saving}
            style={{ fontSize: '.88rem' }}>
            {t({ id: 'biblioteca.contactProfile.reload' })}
          </button>
          <button className="cat-btn primary" onClick={save} disabled={saving}
            style={{ fontSize: '.88rem' }}>
            {saving ? t({ id: 'common.saving' }) : t({ id: 'biblioteca.contactProfile.save' })}
          </button>
        </div>
      )}

      {msg.text && (
        <div style={{
          marginTop: 10, fontSize: '.85rem',
          color: msg.kind === 'ok' ? '#7ee0a8' : '#e89090',
        }}>
          {msg.text}
        </div>
      )}
    </div>
  );
}
