// =============================================================================
// LibraryPublicContactSection.jsx
// =============================================================================
// Chantier « Carte ma bibliotheque cote lecteur » -- etape 2.
// Editeur de la VITRINE PUBLIQUE de contact d'une biblioteca : les coordonnees
// que la biblio choisit de montrer a ses PROPRES lecteur-rices (page compte).
//
// A NE PAS CONFONDRE :
//   - library_commons          -> identite e-mail d'envoi (technique)
//   - library_contact_profiles -> contact reseau CONFIDENTIEL (cooperation PEB)
//   - library_public_contact   -> CETTE vitrine, publique, opt-in, vide par defaut
//
// Doctrine RPC v3 :
//   - lecture  : supabase.from('library_public_contact') (RLS : membre actif)
//   - ecriture : RPC upsert_library_public_contact(p_library_id, p_profile)
//
// Bouton « copier depuis le contact reseau » : pre-remplit les champs depuis
// library_contact_profiles (lecture staff) SANS fusionner les donnees ni
// enregistrer -- la coordination revise puis enregistre ce qu'elle expose.
//
// Aucun DDL : table + RLS + RPC posees a l'etape 1.
// =============================================================================

import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// Champs editables de la vitrine, dans l'ordre d'affichage.
const FIELDS = ['public_email', 'public_phone', 'public_whatsapp', 'public_address', 'public_note'];

// Mapping contact reseau confidentiel -> vitrine publique (bouton « copier »).
// public_note n'a pas d'equivalent reseau : laisse tel quel.
const NETWORK_MAP = {
  public_email:    'contact_email',
  public_phone:    'contact_phone',
  public_whatsapp: 'contact_whatsapp',
  public_address:  'postal_address',
};

// Normalise une ligne library_public_contact en etat de formulaire :
// chaque champ devient une chaine (jamais null) pour les inputs controles.
function normalizeProfile(row) {
  const r = row && typeof row === 'object' ? row : {};
  const out = {};
  for (const f of FIELDS) out[f] = typeof r[f] === 'string' ? r[f] : '';
  return out;
}

export default function LibraryPublicContactSection({ libraryId, canEdit }) {
  const { formatMessage: t } = useIntl();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [form, setForm] = useState(() => normalizeProfile(null));

  // ── Chargement (lecture simple .from(), doctrine RPC v3) ──────────────────
  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase
        .from('library_public_contact')
        .select('public_email, public_phone, public_whatsapp, public_address, public_note')
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

  // ── Sauvegarde via RPC upsert_library_public_contact ──────────────────────
  async function save() {
    if (!canEdit) return;
    setSaving(true);
    setMsg({ text: '', kind: '' });
    try {
      const profile = {};
      for (const f of FIELDS) profile[f] = form[f];
      const { error } = await supabase.rpc('upsert_library_public_contact', {
        p_library_id: libraryId,
        p_profile: profile,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.publicContact.saved' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // ── « Copier depuis le contact reseau » : lecture du profil confidentiel
  //    (staff) puis pre-remplissage des champs correspondants non vides, sans
  //    enregistrer. La coordination revise et enregistre ce qu'elle expose. ───
  async function copyFromNetwork() {
    if (!canEdit) return;
    setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase
        .from('library_contact_profiles')
        .select('contact_email, contact_phone, contact_whatsapp, postal_address')
        .eq('library_id', libraryId)
        .maybeSingle();
      if (error) throw error;
      const src = data || {};
      setForm(f => {
        const next = { ...f };
        for (const [pub, net] of Object.entries(NETWORK_MAP)) {
          const v = src[net];
          if (typeof v === 'string' && v.trim() !== '') next[pub] = v;
        }
        return next;
      });
      setMsg({ text: t({ id: 'biblioteca.publicContact.copied' }), kind: 'info' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  const setField = (key, value) => setForm(f => ({ ...f, [key]: value }));

  // ── Styles (coherents avec LibraryContactProfileSection, theme sombre) ─────
  const styles = useMemo(() => ({
    box: {
      padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)',
      border: '1px solid rgba(255,255,255,.08)', marginTop: 16,
    },
    intro: { fontSize: '.82rem', color: 'var(--brand-muted)', margin: '0 0 12px', lineHeight: 1.45 },
    label: { display: 'block', fontSize: '.78rem', color: 'var(--brand-muted, #ccc)', marginBottom: 4 },
    input: {
      width: '100%', padding: '8px 10px', borderRadius: 8,
      border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)',
      color: '#f4f4f4', fontSize: '.88rem',
    },
    textarea: {
      width: '100%', padding: '8px 10px', borderRadius: 8,
      border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)',
      color: '#f4f4f4', fontSize: '.88rem', resize: 'vertical', minHeight: 52, fontFamily: 'inherit',
    },
    actions: { display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 12, alignItems: 'center' },
    feedback: (kind) => ({
      fontSize: '.82rem',
      color: kind === 'ok' ? '#4ade80' : kind === 'info' ? '#93c5fd' : '#f87171',
    }),
  }), []);

  if (loading) {
    return <div style={{ fontSize: '.88rem', color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</div>;
  }

  // Rend un champ : type 'email' | 'tel' | 'textarea'.
  const field = (key, type) => (
    <div className="cat-field" key={key}>
      <label style={styles.label}>{t({ id: `biblioteca.publicContact.${key}` })}</label>
      {type === 'textarea' ? (
        <textarea
          style={styles.textarea}
          value={form[key]}
          disabled={!canEdit}
          placeholder={t({ id: `biblioteca.publicContact.${key}.placeholder` })}
          onChange={e => setField(key, e.target.value)}
        />
      ) : (
        <input
          type={type}
          style={styles.input}
          value={form[key]}
          disabled={!canEdit}
          placeholder={t({ id: `biblioteca.publicContact.${key}.placeholder` })}
          onChange={e => setField(key, e.target.value)}
        />
      )}
    </div>
  );

  return (
    <div style={styles.box}>
      <h4 style={{ margin: '0 0 6px' }}>{t({ id: 'biblioteca.publicContact.title' })}</h4>
      <p style={styles.intro}>{t({ id: 'biblioteca.publicContact.intro' })}</p>

      <div className="cat-book-grid">
        {field('public_email', 'email')}
        {field('public_phone', 'tel')}
        {field('public_whatsapp', 'tel')}
        {field('public_address', 'textarea')}
        {field('public_note', 'textarea')}
      </div>

      {canEdit && (
        <div style={styles.actions}>
          <button className="cat-btn secondary" onClick={copyFromNetwork} disabled={saving}>
            {t({ id: 'biblioteca.publicContact.copyFromNetwork' })}
          </button>
          <button className="cat-btn" onClick={save} disabled={saving}>
            {t({ id: 'biblioteca.publicContact.save' })}
          </button>
          <button className="cat-btn secondary" onClick={load} disabled={saving}>
            {t({ id: 'biblioteca.publicContact.reload' })}
          </button>
          {msg.text && <span style={styles.feedback(msg.kind)}>{msg.text}</span>}
        </div>
      )}
      {!canEdit && msg.text && (
        <div style={{ ...styles.feedback(msg.kind), marginTop: 10 }}>{msg.text}</div>
      )}
    </div>
  );
}
