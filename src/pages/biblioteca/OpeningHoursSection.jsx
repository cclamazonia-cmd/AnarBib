// src/pages/biblioteca/OpeningHoursSection.jsx — E6, BibliotecaPage lot 4 (12/10/2026)
// Les horaires et permanences hebdomadaires de la bibliothèque (OPENING-HOURS,
// migration 20260617004224), sortis de BibliotecaPage.jsx sans en changer une
// ligne de logique : les créneaux (jour, début, fin, libellé), la note publique,
// l'enregistrement par fn_upsert_library_opening_hours. L'état des horaires
// reste au parent (loadCore le charge) et arrive en props ; le message et
// l'enregistrement en cours vivent ici.
import { useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { fs, ls, bx } from './styles';

export default function OpeningHoursSection({ libraryId, openingHours, setOpeningHours }) {
  const { formatMessage: t, locale } = useIntl();
  const [ohSaving, setOhSaving] = useState(false);
  const [ohMsg, setOhMsg] = useState('');
  // day ISO 1..7 (lundi=1) ; le 2024-01-01 est un lundi → base de calcul Intl.
  const dayName = useCallback((d) => {
    try { return new Intl.DateTimeFormat(locale, { weekday: 'long' }).format(new Date(2024, 0, Number(d) || 1)); }
    catch { return String(d); }
  }, [locale]);
  function addSlot(){ setOpeningHours(p => ({ ...p, slots: [...p.slots, { day:1, start:'18:00', end:'20:00', label:'' }] })); setOhMsg(''); }
  function updateSlot(i,k,v){ setOpeningHours(p => ({ ...p, slots: p.slots.map((s,j)=> j===i ? { ...s, [k]: v } : s) })); setOhMsg(''); }
  function removeSlot(i){ setOpeningHours(p => ({ ...p, slots: p.slots.filter((_,j)=> j!==i) })); setOhMsg(''); }
  async function saveHours(){
    setOhSaving(true); setOhMsg('');
    try {
      const clean = (openingHours.slots || [])
        .filter(s => s && s.start && s.end)
        .map(s => ({ day: Number(s.day) || 1, start: String(s.start), end: String(s.end), label: (s.label || '').trim() || undefined }));
      const { error } = await apiRpc('fn_upsert_library_opening_hours', { p_library_id: libraryId, p_slots: clean, p_public_note: openingHours.public_note || null });
      if (error) throw error;
      setOpeningHours(p => ({ ...p, slots: clean.map(s => ({ ...s, label: s.label || '' })) }));
      setOhMsg(t({ id: 'biblioteca.msg.saved' }));
    } catch (e) {
      setOhMsg(localizeError(e, t));
    } finally {
      setOhSaving(false);
    }
  }

  return (
  <div style={bx}>
    <h4 style={{ margin:'0 0 4px' }}>{t({ id: 'biblioteca.openingHours.title' })}</h4>
    <p style={{ margin:'0 0 12px', fontSize:'.8rem', color:'var(--brand-muted)' }}>{t({ id: 'biblioteca.openingHours.hint' })}</p>
    {openingHours.slots.length === 0 ? (
      <p style={{ margin:'0 0 12px', fontSize:'.85rem', color:'var(--brand-muted)', fontStyle:'italic' }}>{t({ id: 'biblioteca.openingHours.empty' })}</p>
    ) : (
      <div style={{ display:'flex', flexDirection:'column', gap:10, marginBottom:12 }}>
        {openingHours.slots.map((s,i) => (
          <div key={i} style={{ display:'flex', flexWrap:'wrap', gap:8, alignItems:'flex-end', padding:'10px 12px', background:'rgba(0,0,0,.12)', borderRadius:8, border:'1px solid rgba(255,255,255,.06)' }}>
            <div style={{ minWidth:'min(130px, 100%)' }}>
              <select value={s.day||1} onChange={e=>updateSlot(i,'day',Number(e.target.value))} style={fs}>
                {[1,2,3,4,5,6,7].map(d => <option key={d} value={d}>{dayName(d)}</option>)}
              </select>
            </div>
            <div style={{ width:110 }}>
              <label style={{...ls,fontSize:'.72rem',marginBottom:2}}>{t({ id: 'biblioteca.openingHours.start' })}</label>
              <input type="time" value={s.start||''} onChange={e=>updateSlot(i,'start',e.target.value)} style={fs} />
            </div>
            <div style={{ width:110 }}>
              <label style={{...ls,fontSize:'.72rem',marginBottom:2}}>{t({ id: 'biblioteca.openingHours.end' })}</label>
              <input type="time" value={s.end||''} onChange={e=>updateSlot(i,'end',e.target.value)} style={fs} />
            </div>
            <div style={{ flex:'1 1 160px', minWidth:'min(140px, 100%)' }}>
              <input type="text" value={s.label||''} onChange={e=>updateSlot(i,'label',e.target.value)} style={fs} placeholder={t({ id: 'biblioteca.openingHours.labelPlaceholder' })} maxLength={80} />
            </div>
            <button type="button" onClick={()=>removeSlot(i)} style={{ padding:'10px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', cursor:'pointer', lineHeight:1 }} aria-label={t({ id: 'common.remove' })}>×</button>
          </div>
        ))}
      </div>
    )}
    <button type="button" onClick={addSlot} style={{ padding:'8px 14px', borderRadius:8, border:'1px solid rgba(255,255,255,.18)', background:'rgba(255,255,255,.05)', color:'#f4f4f4', cursor:'pointer', fontSize:'.85rem', marginBottom:14 }}>{t({ id: 'biblioteca.openingHours.addSlot' })}</button>
    <div className="cat-field" style={{ marginBottom:12 }}>
      <label style={ls}>{t({ id: 'biblioteca.openingHours.note' })}</label>
      <textarea value={openingHours.public_note||''} onChange={e=>{ setOpeningHours(p=>({...p,public_note:e.target.value})); setOhMsg(''); }} rows={2} style={{...fs,resize:'vertical'}} placeholder={t({ id: 'biblioteca.openingHours.notePlaceholder' })} maxLength={300} />
    </div>
    <div style={{ display:'flex', gap:12, alignItems:'center' }}>
      <button type="button" className="ab-button" onClick={saveHours} disabled={ohSaving}>{t({ id: 'common.save' })}</button>
      {ohMsg && <span style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>{ohMsg}</span>}
    </div>
  </div>
  );
}
