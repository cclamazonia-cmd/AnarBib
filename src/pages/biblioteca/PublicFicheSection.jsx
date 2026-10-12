// src/pages/biblioteca/PublicFicheSection.jsx — E6, BibliotecaPage lot 4 (12/10/2026)
// La fiche publique (#PUB3, opt-in niveau 2) : ce qui apparaît sur
// /bibliotecas/:slug — contact et horaires —, basculé par RPC
// (fn_set_library_contact_public, fn_set_library_hours_public). L'état arrive
// du parent (loadCore le charge) ; la bascule en cours vit ici.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { apiRpc } from '@/lib/supabase';
import { bx } from './styles';

export default function PublicFicheSection({ libraryId, fichePublic, setFichePublic }) {
  const { formatMessage: t } = useIntl();
  const [fpSaving, setFpSaving] = useState('');
  // PUBLIB-OPTIN-1/2 (#PUB3) : bascule d'une section en public (coordenador), via RPC.
  async function toggleFiche(which, value){
    setFpSaving(which);
    try {
      const fn = which === 'contact' ? 'fn_set_library_contact_public' : 'fn_set_library_hours_public';
      const { error } = await apiRpc(fn, { p_library_id: libraryId, p_is_public: value });
      if (error) throw error;
      setFichePublic(p => ({ ...p, [which === 'contact' ? 'contact_is_public' : 'hours_is_public']: value }));
    } catch { /* silencieux : l'état ne bascule pas si l'RPC échoue */ }
    finally { setFpSaving(''); }
  }

  return (
  <div style={bx}>
    <h4 style={{ margin:'0 0 4px' }}>{t({ id: 'biblioteca.publicFiche.title' })}</h4>
    <p style={{ margin:'0 0 4px', fontSize:'.8rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.publicFiche.hint' })}</p>
    <p style={{ margin:'0 0 12px', fontSize:'.78rem', color:'var(--brand-muted)', fontStyle:'italic' }}>{t({ id: 'biblioteca.publicFiche.requiresPublic' })}</p>
    <label style={{ display:'flex', gap:8, alignItems:'center', marginBottom:8, cursor: fpSaving==='contact'?'wait':'pointer' }}>
      <input type="checkbox" checked={fichePublic.contact_is_public} disabled={fpSaving==='contact'} onChange={e=>toggleFiche('contact', e.target.checked)} />
      <span>{t({ id: 'biblioteca.publicFiche.contactToggle' })}</span>
    </label>
    <label style={{ display:'flex', gap:8, alignItems:'center', marginBottom:12, cursor: fpSaving==='hours'?'wait':'pointer' }}>
      <input type="checkbox" checked={fichePublic.hours_is_public} disabled={fpSaving==='hours'} onChange={e=>toggleFiche('hours', e.target.checked)} />
      <span>{t({ id: 'biblioteca.publicFiche.hoursToggle' })}</span>
    </label>
    <p style={{ margin:0, fontSize:'.78rem', color:'var(--brand-muted)' }}>⚠ {t({ id: 'biblioteca.publicFiche.collective' })}</p>
  </div>
  );
}
