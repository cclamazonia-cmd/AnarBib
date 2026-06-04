// =============================================================================
// MyLibraryContactCard.jsx
// =============================================================================
// Carte « ma bibliotheque » cote lecteur·rice -- chantier carte ma bibliotheque.
// Montee dans l'onglet perfil du compte (colonne de droite).
//
// Affiche les coordonnees PUBLIQUES que la biblio a choisi d'exposer
// (library_public_contact, opt-in, vide par defaut) + son logo. Lecture seule.
// Etape 6 : composer in-systeme « ecrire a ma bibliotheque » (RPC
// fn_reader_send_message_to_library, anti-spam 3/24h cote DB). Canal toujours
// disponible (independant du contact public affiche).
//
// Sources (lecture simple from(), doctrine RPC v3) :
//   - library_public_contact : RLS membre actif (le·a lecteur·rice l'est)
//   - library_commons        : lecture publique (logo + nom)
//
// Logo : source data-driven (logo_url, sinon logo_file_key -> bucket public
// library-ui-assets). JAMAIS le LIBRARY_LOGO_MAP code en dur (cf. TR-6.2b).
// Repli texte (initiales) si pas de logo. Carte JAMAIS masquee (decision 04/06).
// =============================================================================

import { useState, useEffect, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useLibrary } from '@/contexts/LibraryContext';

const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
const CONTACT_FIELDS = ['public_email', 'public_phone', 'public_whatsapp', 'public_address', 'public_note'];

// Resolution data-driven du logo (logo_url prioritaire, sinon logo_file_key).
function resolveLogo(commons) {
  if (!commons) return null;
  // logo_url pris en compte SEULEMENT si URL absolue http(s).
  // Valeurs relatives heritees (ex. ./assets/.../logo-btl.png) ignorees :
  // on retombe sur logo_file_key (chemin bucket). Cf. TR-6.2b.
  const url = typeof commons.logo_url === 'string' ? commons.logo_url.trim() : '';
  if (/^https?:\/\//i.test(url)) return url;
  const key = commons.logo_file_key;
  if (typeof key === 'string' && key.trim() !== '') {
    const tail = key.includes('/') ? key : `themes/${key}/logo-${key}.png`;
    return `${PROJECT_URL}/storage/v1/object/public/library-ui-assets/${tail}`;
  }
  return null;
}

function initials(name) {
  if (!name) return '?';
  return name.trim().split(/\s+/).slice(0, 2).map(w => w[0] || '').join('').toUpperCase() || '?';
}

export default function MyLibraryContactCard() {
  const { formatMessage: t } = useIntl();
  const { libraryId, libraryName } = useLibrary();

  const [loading, setLoading] = useState(true);
  const [contact, setContact] = useState(null);
  const [commons, setCommons] = useState(null);
  const [logoBroken, setLogoBroken] = useState(false);

  // Etape 6 : etat du composer « ecrire a ma bibliotheque ».
  const [writing, setWriting] = useState(false);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [sending, setSending] = useState(false);
  const [sendMsg, setSendMsg] = useState('');
  const [sendErr, setSendErr] = useState(false);

  useEffect(() => {
    if (!libraryId) { setLoading(false); return; }
    let cancelled = false;
    (async () => {
      setLoading(true);
      setLogoBroken(false);
      try {
        const [pc, cm] = await Promise.all([
          supabase.from('library_public_contact')
            .select('public_email, public_phone, public_whatsapp, public_address, public_note')
            .eq('library_id', libraryId).maybeSingle(),
          supabase.from('library_commons')
            .select('logo_url, logo_file_key, display_name, short_name')
            .eq('library_id', libraryId).maybeSingle(),
        ]);
        if (cancelled) return;
        setContact(pc.data || null);
        setCommons(cm.data || null);
      } catch {
        // Silencieux : la carte degrade proprement (nom + message).
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [libraryId]);

  const name = (commons && (commons.display_name || commons.short_name)) || libraryName || '';
  const logoSrc = useMemo(() => resolveLogo(commons), [commons]);
  const hasAnyContact = !!contact && CONTACT_FIELDS.some(f => typeof contact[f] === 'string' && contact[f].trim() !== '');

  // Lecteur·rice sans biblio d'attache (orphelin·e) : pas de carte.
  if (!libraryId) return null;

  const box = { padding: 18, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' };
  const labelStyle = { fontSize: '.72rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted)', marginBottom: 2 };
  const valueStyle = { fontSize: '.9rem', color: '#f4f4f4', wordBreak: 'break-word', whiteSpace: 'pre-line' };
  const linkStyle = { ...valueStyle, color: '#93c5fd', textDecoration: 'none' };
  const rowStyle = { marginTop: 12 };
  const logoBox = {
    width: 72, height: 72, borderRadius: 12, flex: '0 0 auto', objectFit: 'contain',
    background: 'rgba(255,255,255,.05)', border: '1px solid rgba(255,255,255,.10)',
  };
  const logoFallback = {
    ...logoBox, display: 'flex', alignItems: 'center', justifyContent: 'center',
    fontFamily: 'var(--brand-font-body)', fontSize: '1.2rem', fontWeight: 700, color: 'var(--brand-muted)',
  };
  const btnPrimary = {
    padding: '8px 14px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)',
    background: '#c00000', color: '#fff', fontWeight: 600, fontSize: '.85rem', cursor: 'pointer',
  };
  const btnGhost = {
    padding: '8px 14px', borderRadius: 8, border: '1px solid rgba(255,255,255,.15)',
    background: 'transparent', color: '#cfcfcf', fontSize: '.85rem', cursor: 'pointer',
  };
  const inputStyle = {
    width: '100%', boxSizing: 'border-box', padding: '8px 10px', borderRadius: 8,
    border: '1px solid rgba(255,255,255,.12)', background: 'rgba(255,255,255,.04)',
    color: '#f4f4f4', fontSize: '.88rem', fontFamily: 'inherit',
  };

  const waDigits = contact?.public_whatsapp ? contact.public_whatsapp.replace(/[^\d]/g, '') : '';

  // Rend un champ uniquement s'il est rempli.
  const field = (key, label, render) => {
    const v = contact?.[key];
    if (typeof v !== 'string' || v.trim() === '') return null;
    return (
      <div style={rowStyle} key={key}>
        <div style={labelStyle}>{label}</div>
        {render(v.trim())}
      </div>
    );
  };

  const canSend = body.trim().length >= 1 && !sending;

  async function handleSend() {
    const b = body.trim();
    if (b.length < 1) { setSendErr(true); setSendMsg(t({ id: 'account.mylib.write.errorEmpty' })); return; }
    if (b.length > 4000) { setSendErr(true); setSendMsg(t({ id: 'account.mylib.write.errorTooLong' })); return; }
    setSending(true); setSendMsg(''); setSendErr(false);
    try {
      const { error } = await supabase.rpc('fn_reader_send_message_to_library', {
        p_library_id: libraryId,
        p_subject: subject.trim() || null,
        p_body: b,
      });
      if (error) {
        const m = (error.message || '').toLowerCase();
        const id = m.includes('empty_body') ? 'account.mylib.write.errorEmpty'
          : m.includes('body_too_long') ? 'account.mylib.write.errorTooLong'
          : m.includes('rate_limited') ? 'account.mylib.write.errorRate'
          : 'account.mylib.write.errorGeneric';
        setSendErr(true); setSendMsg(t({ id }));
        return;
      }
      setSubject(''); setBody(''); setWriting(false);
      setSendErr(false); setSendMsg(t({ id: 'account.mylib.write.success' }));
    } catch {
      setSendErr(true); setSendMsg(t({ id: 'account.mylib.write.errorGeneric' }));
    } finally {
      setSending(false);
    }
  }

  return (
    <div style={box}>
      <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
        {logoSrc && !logoBroken ? (
          <img src={logoSrc} alt={name} style={logoBox} onError={() => setLogoBroken(true)} />
        ) : (
          <div style={logoFallback} aria-hidden="true">{initials(name)}</div>
        )}
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: '.72rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted)' }}>
            {t({ id: 'account.mylib.title' })}
          </div>
          <div style={{ fontSize: '1.02rem', fontWeight: 600, color: '#f4f4f4', wordBreak: 'break-word' }}>{name}</div>
        </div>
      </div>

      {loading ? null : hasAnyContact ? (
        <>
          {field('public_email', t({ id: 'account.mylib.email' }), v => (
            <a href={`mailto:${v}`} style={linkStyle}>{v}</a>
          ))}
          {field('public_phone', t({ id: 'account.mylib.phone' }), v => (
            <a href={`tel:${v.replace(/\s+/g, '')}`} style={linkStyle}>{v}</a>
          ))}
          {field('public_whatsapp', t({ id: 'account.mylib.whatsapp' }), v => (
            waDigits
              ? <a href={`https://wa.me/${waDigits}`} target="_blank" rel="noopener noreferrer" style={linkStyle}>{v}</a>
              : <div style={valueStyle}>{v}</div>
          ))}
          {field('public_address', t({ id: 'account.mylib.address' }), v => <div style={valueStyle}>{v}</div>)}
          {field('public_note', t({ id: 'account.mylib.note' }), v => <div style={valueStyle}>{v}</div>)}
        </>
      ) : (
        <div style={{ ...valueStyle, marginTop: 12, color: 'var(--brand-muted)' }}>
          {t({ id: 'account.mylib.noPublicContact' })}
        </div>
      )}

      {/* Etape 6 : canal in-systeme « ecrire a ma bibliotheque » */}
      <div style={{ marginTop: 16, paddingTop: 14, borderTop: '1px solid rgba(255,255,255,.08)' }}>
        {!writing ? (
          <button type="button" onClick={() => { setWriting(true); setSendMsg(''); }} style={btnPrimary}>
            {t({ id: 'account.mylib.write.button' })}
          </button>
        ) : (
          <div>
            <div style={{ ...labelStyle, marginBottom: 6 }}>{t({ id: 'account.mylib.write.title' })}</div>
            <input
              type="text"
              value={subject}
              onChange={e => setSubject(e.target.value)}
              placeholder={t({ id: 'account.mylib.write.subjectPlaceholder' })}
              maxLength={200}
              style={inputStyle}
            />
            <textarea
              value={body}
              onChange={e => setBody(e.target.value)}
              placeholder={t({ id: 'account.mylib.write.bodyPlaceholder' })}
              maxLength={4000}
              rows={5}
              style={{ ...inputStyle, marginTop: 8, resize: 'vertical', minHeight: 96 }}
            />
            <div style={{ fontSize: '.72rem', color: 'var(--brand-muted)', textAlign: 'right', marginTop: 4 }}>
              {body.length} / 4000
            </div>
            <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
              <button type="button" onClick={handleSend} disabled={!canSend} style={{ ...btnPrimary, opacity: canSend ? 1 : .6 }}>
                {sending ? t({ id: 'account.mylib.write.sending' }) : t({ id: 'account.mylib.write.send' })}
              </button>
              <button type="button" onClick={() => { setWriting(false); setSendMsg(''); }} disabled={sending} style={btnGhost}>
                {t({ id: 'account.mylib.write.cancel' })}
              </button>
            </div>
          </div>
        )}
        {sendMsg ? (
          <div style={{ marginTop: 10, fontSize: '.82rem', color: sendErr ? '#fca5a5' : '#86efac' }}>
            {sendMsg}
          </div>
        ) : null}
      </div>
    </div>
  );
}