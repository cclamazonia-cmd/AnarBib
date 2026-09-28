// src/pages/biblioteca/styles.js — E6, BibliotecaPage lot 1 (28/09/2026)
// Les cinq styles en ligne que la page et ses sections partagent (champ,
// libellé, boîte, ligne de liste alternée, cadre de liste). Ils vivaient dans
// le corps du composant ; les sections extraites les importent d'ici.
export const fs = { width:'100%', padding:'10px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.9rem' };
export const ls = { display:'block', fontSize:'.85rem', fontWeight:600, marginBottom:3, color:'var(--brand-muted, #ccc)' };
export const bx = { padding:14, borderRadius:10, background:'rgba(255,255,255,.03)', border:'1px solid rgba(255,255,255,.08)', marginBottom:16 };
export const lr = (i) => ({ padding:'10px 12px', background:i%2===0?'rgba(0,0,0,.08)':'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 });
export const lw = { border:'1px solid rgba(255,255,255,.06)', borderRadius:8, overflow:'hidden' };
