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
// Logo : resolveLibraryLogo de @/lib/theme (source partagee avec le header,
// item 2 -- plus de logique de resolution dupliquee ici). JAMAIS le
// LIBRARY_LOGO_MAP code en dur (cf. TR-6.2b). Repli texte (initiales) si pas
// de logo. Carte JAMAIS masquee (decision 04/06).
// =============================================================================

import { useState, useEffect, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useLibrary } from '@/contexts/LibraryContext';
import { resolveLibraryLogo } from '@/lib/theme';

const CONTACT_FIELDS = ['public_email', 'public_phone', 'public_whatsapp', 'public_address', 'public_note'];

function initials(name) {
  if (!name) return '?';
  return name.trim().split(/\s+/).slice(0, 2).map(w => w[0] || '').join('').toUpperCase() || '?';
}

export default function MyLibraryContactCard() {
  const { formatMessage: t, locale } = useIntl();
  const { libraryId, libraryName } = useLibrary();

  const [loading, setLoading] = useState(true);
  const [contact, setContact] = useState(null);
  const [commons, setCommons] = useState(null);
  const [hours, setHours] = useState(null);   // { slots:[], public_note }
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
        const [pc, cm, oh] = await Promise.all([
          supabase.from('library_public_contact')
            .select('public_email, public_phone, public_whatsapp, public_address, public_note')
            .eq('library_id', libraryId).maybeSingle(),
          supabase.from('library_commons')
            .select('logo_url, logo_file_key, display_name, short_name')
            .eq('library_id', libraryId).maybeSingle(),
          supabase.from('library_opening_hours')
            .select('slots, public_note')
            .eq('library_id', libraryId).maybeSingle(),
        ]);
        if (cancelled) return;
        setContact(pc.data || null);
        setCommons(cm.data || null);
        setHours(oh.data ? { slots: Array.isArray(oh.data.slots) ? oh.data.slots : [], public_note: oh.data.public_note || '' } : null);
      } catch {
        // Silencieux : la carte degrade proprement (nom + message).
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [libraryId]);

  const name = (commons && (commons.display_name || commons.short_name)) || libraryName || '';
  const logoSrc = useMemo(() => resolveLibraryLogo(commons), [commons]);
  const hasAnyContact = !!contact && CONTACT_FIELDS.some(f => typeof contact[f] === 'string' && contact[f].trim() !== '');

  // Horaires/permanences : day ISO 1..7 (lundi=1) ; 2024-01-01 est un lundi.
  const dayName = (d) => {
    try { return new Intl.DateTimeFormat(locale, { weekday: 'long' }).format(new Date(2024, 0, Number(d) || 1)); }
    catch { return String(d); }
  };
  const sortedSlots = useMemo(() => {
    const s = (hours?.slots || []).filter(x => x && x.start && x.end);
    return [...s].sort((a, b) => (Number(a.day) - Number(b.day)) || String(a.start).localeCompare(String(b.start)));
  }, [hours]);
  const hasHours = sortedSlots.length > 0 || !!(hours?.public_note);

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
    background: 'linear-gradient(135deg, rgba(var(--brand-action-rgb), .92), var(--brand-color-primary))', color: '#fff', fontWeight: 600, fontSize: '.85rem', cursor: 'pointer',
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

      {/* Horaires / permanences hebdomadaires (lecture membre actif) */}
      {!loading && hasHours && (
        <div style={{ marginTop: 16, paddingTop: 14, borderTop: '1px solid rgba(255,255,255,.08)' }}>
          <div style={labelStyle}>{t({ id: 'account.mylib.hours' })}</div>
          {sortedSlots.length > 0 && (
            <div style={{ marginTop: 6, display: 'flex', flexDirection: 'column', gap: 4 }}>
              {sortedSlots.map((s, i) => (
                <div key={i} style={valueStyle}>
                  <span style={{ fontWeight: 600, textTransform: 'capitalize' }}>{dayName(s.day)}</span>
                  {' · '}{s.start}–{s.end}
                  {s.label ? <span style={{ color: 'var(--brand-muted)' }}>{' — '}{s.label}</span> : null}
                </div>
              ))}
            </div>
          )}
          {hours?.public_note ? (
            <div style={{ ...valueStyle, marginTop: 6, color: 'var(--brand-muted)', fontStyle: 'italic' }}>{hours.public_note}</div>
          ) : null}
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
