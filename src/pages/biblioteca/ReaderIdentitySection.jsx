// src/pages/biblioteca/ReaderIdentitySection.jsx — E6, BibliotecaPage lot 4 (12/10/2026)
// Le modèle d'identité des lecteur·rices et le mode de validation (CARD-LOCAL-2/3,
// N5), l'ouverture des inscriptions publiques, et le « dernier identifiant
// attribué » (lu par api.get_last_assigned_reader_identity au montage — la
// section n'est montée que sous l'onglet Identité). Les champs écrivent dans
// `lib` du parent par setL ; l'enregistrement reste au bouton de l'onglet.
import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { fs, ls, bx } from './styles';

export default function ReaderIdentitySection({ libraryId, isCoord, lib, setL }) {
  const { formatMessage: t } = useIntl();
  // CARD-LOCAL-2/N5 : « dernier identifiant attribué » dérivé (hint config, coord).
  const [lastAssignedIdentity, setLastAssignedIdentity] = useState(null);
  useEffect(() => {
    if (!isCoord || !libraryId) return;
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.schema('api').rpc('get_last_assigned_reader_identity', { p_library_id: libraryId });
        if (!cancelled) setLastAssignedIdentity(data ?? null);
      } catch { if (!cancelled) setLastAssignedIdentity(null); }
    })();
    return () => { cancelled = true; };
  }, [isCoord, libraryId]);

  return (
  <div style={bx}>
    <h4 style={{ margin:'0 0 4px' }}>{t({ id: 'biblioteca.readerIdentity.title' })}</h4>
    <p style={{ margin:'0 0 10px', fontSize:'.8rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.readerIdentity.hint' })}</p>
    <div className="cat-book-grid">
      <div className="cat-field">
        <label style={ls}>{t({ id: 'biblioteca.readerIdentity.model' })}</label>
        <select value={lib.reader_identity_model||'free_number'} onChange={e=>setL('reader_identity_model',e.target.value)} style={fs}>
          <option value="free_number">{t({id:'biblioteca.readerIdentity.model.free_number'})}</option>
          <option value="sequenced_number">{t({id:'biblioteca.readerIdentity.model.sequenced_number'})}</option>
          <option value="name">{t({id:'biblioteca.readerIdentity.model.name'})}</option>
          <option value="none">{t({id:'biblioteca.readerIdentity.model.none'})}</option>
        </select>
      </div>
      <div className="cat-field">
        <label style={ls}>{t({ id: 'biblioteca.readerIdentity.mode' })}</label>
        <select value={lib.reader_validation_mode||'presential'} onChange={e=>setL('reader_validation_mode',e.target.value)} style={fs}>
          <option value="presential">{t({id:'biblioteca.readerIdentity.mode.presential'})}</option>
          <option value="remote">{t({id:'biblioteca.readerIdentity.mode.remote'})}</option>
          <option value="none">{t({id:'biblioteca.readerIdentity.mode.none'})}</option>
        </select>
      </div>
      {/* #LIB-SIGNUP-UI — interrupteur d'ouverture des inscriptions publiques (accepts_public_signup) */}
      <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={{...ls,display:'flex',gap:8,alignItems:'flex-start'}}><input type="checkbox" checked={lib.accepts_public_signup||false} onChange={e=>setL('accepts_public_signup',e.target.checked)} style={{marginTop:3}} /> <span><span>{t({id:'biblioteca.readerIdentity.publicSignup'})}</span><br/><span style={{fontSize:'.8rem',color:'var(--brand-muted)',fontWeight:400}}>{t({id:'biblioteca.readerIdentity.publicSignup.hint'})}</span></span></label></div>
      {lastAssignedIdentity != null && lastAssignedIdentity !== '' && (
        <div className="cat-field" style={{ gridColumn:'span 3' }}>
          <span style={{ fontSize:'.8rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.readerIdentity.lastAssigned' }, { value: lastAssignedIdentity })}</span>
        </div>
      )}
    </div>
  </div>
  );
}
