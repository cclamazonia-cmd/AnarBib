// =============================================================================
// MyLibraryContactCard.jsx
// =============================================================================
// Carte « ma bibliotheque » cote lecteur·rice -- chantier carte ma bibliotheque,
// etape 3. Montee dans l'onglet perfil du compte (colonne de droite).
//
// Affiche les coordonnees PUBLIQUES que la biblio a choisi d'exposer
// (library_public_contact, opt-in, vide par defaut) + son logo. Lecture seule.
// Le bouton « ecrire a ma bibliotheque » arrivera a l'etape 6 (canal in-systeme) ;
// il n'est volontairement PAS pose ici (pas de bouton mort).
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
  if (typeof commons.logo_url === 'string' && commons.logo_url.trim() !== '') return commons.logo_url;
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
            .select('logo_url, logo_file_key, name, short_name')
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

  const name = (commons && (commons.name || commons.short_name)) || libraryName || '';
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
    </div>
  );
}
