// =============================================================================
// CartografiaAjouterPage.jsx — Auto-déclaration publique « ajouter ma biblio » (MAP-J).
// =============================================================================
// Route /cartografia/ajouter (anon). On ne déclare que SA propre bibliothèque
// (J-B). Soumission → Edge Function publique submit-cartography-entry (Turnstile +
// honeypot + rate-limit) → staging cartography_submissions (pending). Rien n'est
// public : la coordination modère, puis opt-in requis (MAP-E). Paquet CARTO-7.
// =============================================================================

import { useEffect, useRef, useState } from 'react';
import { useIntl } from 'react-intl';
import { Turnstile } from '@marsidev/react-turnstile';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { callEdgeFunction } from '@/lib/supabase';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

const CATS = ['biblioteca', 'arquivo', 'centro_doc', 'ateneu', 'livraria', 'misto'];
const MAP_LOCALES = ['fr', 'pt', 'it', 'es', 'en', 'de', 'ca', 'eo', 'nl', 'el'];
const TURNSTILE_SITE_KEY = import.meta.env.VITE_TURNSTILE_SITE_KEY;
function mapLang(locale) {
  const b = (locale || '').toLowerCase().startsWith('pt') ? 'pt' : (locale || '').slice(0, 2).toLowerCase();
  return MAP_LOCALES.includes(b) ? b : 'fr';
}
function loadCss(href) {
  if ([...document.querySelectorAll('link[rel="stylesheet"]')].some((l) => l.href.includes(href))) return;
  const l = document.createElement('link'); l.rel = 'stylesheet'; l.href = href; document.head.appendChild(l);
}
function loadScript(src) {
  return new Promise((res, rej) => {
    if ([...document.scripts].some((s) => s.src.includes(src))) return res();
    const s = document.createElement('script'); s.src = src; s.async = true;
    s.onload = () => res(); s.onerror = () => rej(new Error('load ' + src)); document.head.appendChild(s);
  });
}

export default function CartografiaAjouterPage() {
  const { formatMessage: t, locale } = useIntl();
  useDocumentTitle(t({ id: 'cartografia.add.title' }));
  const lang = mapLang(locale);

  const [f, setF] = useState({
    name: '', city: '', country: '', categorie: 'biblioteca', langue_fonds: '',
    site_url: '', email: '', tel: '', adresse: '', notes: '', submitter_note: '',
    lat: null, lon: null, website: '',
  });
  const set = (k, v) => setF((p) => ({ ...p, [k]: v }));
  const [token, setToken] = useState('');
  const [state, setState] = useState('idle'); // idle | sending | done | error
  const [errMsg, setErrMsg] = useState('');

  const pickerRef = useRef(null);
  const mapRef = useRef(null);
  useEffect(() => {
    let cancel = false;
    (async () => {
      try {
        loadCss('/vendor/leaflet/leaflet.css');
        await loadScript('/vendor/leaflet/leaflet.js');
        if (cancel || !pickerRef.current || mapRef.current) return;
        const L = window.L;
        const map = L.map(pickerRef.current, { worldCopyJump: true, attributionControl: false }).setView([20, 5], 2);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18 }).addTo(map);
        let marker = null;
        map.on('click', (e) => {
          if (!marker) marker = L.marker(e.latlng, { draggable: true }).addTo(map);
          else marker.setLatLng(e.latlng);
          const apply = (ll) => setF((p) => ({ ...p, lat: Number(ll.lat.toFixed(5)), lon: Number(ll.lng.toFixed(5)) }));
          apply(e.latlng);
          marker.on('dragend', () => apply(marker.getLatLng()));
        });
        mapRef.current = map;
        setTimeout(() => { try { map.invalidateSize(); } catch { /* ignore */ } }, 150);
      } catch { /* picker optionnel */ }
    })();
    return () => { cancel = true; if (mapRef.current) { try { mapRef.current.remove(); } catch { /* ignore */ } mapRef.current = null; } };
  }, []);

  async function submit(e) {
    e.preventDefault();
    if (f.name.trim().length < 2) { setErrMsg(t({ id: 'cartografia.add.error' })); setState('error'); return; }
    setState('sending'); setErrMsg('');
    const res = await callEdgeFunction('submit-cartography-entry', {
      name: f.name, city: f.city, country: f.country, categorie: f.categorie,
      langue_fonds: f.langue_fonds, site_url: f.site_url, email: f.email, tel: f.tel,
      adresse: f.adresse, notes: f.notes, submitter_note: f.submitter_note,
      notes_locale: lang, lat: f.lat, lon: f.lon,
      turnstile_token: token, website: f.website,
    });
    if (res.ok) { setState('done'); }
    else { setErrMsg(t({ id: 'cartografia.add.error' })); setState('error'); }
  }

  const panel = {
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)', borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)', padding: '24px 24px 32px',
  };
  const label = { display: 'block', fontSize: '.78rem', color: 'var(--brand-muted)', margin: '12px 0 4px' };
  const input = {
    width: '100%', boxSizing: 'border-box', padding: '8px 10px', borderRadius: 8,
    border: '1px solid rgba(255,255,255,.14)', background: 'rgba(255,255,255,.04)', color: 'inherit', fontSize: '.9rem',
  };

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 640, margin: '0 auto', padding: '24px 16px 48px' }}>
        <div style={panel}>
          <h1 style={{ fontSize: '1.6rem', fontWeight: 800, marginBottom: 6, fontFamily: 'var(--brand-font-body)' }}>
            {t({ id: 'cartografia.add.title' })}
          </h1>
          <p style={{ color: 'var(--brand-muted)', marginBottom: 8 }}>{t({ id: 'cartografia.add.intro' })}</p>
          <p style={{ color: 'var(--brand-muted)', fontSize: '.82rem', marginBottom: 16 }}>{t({ id: 'cartografia.add.consent' })}</p>

          {state === 'done' ? (
            <p style={{ color: '#86efac', fontSize: '1rem' }}>{t({ id: 'cartografia.add.success' })}</p>
          ) : (
            <form onSubmit={submit}>
              {/* honeypot anti-bot (caché) */}
              <input type="text" name="website" autoComplete="off" tabIndex={-1}
                value={f.website} onChange={(e) => set('website', e.target.value)}
                style={{ position: 'absolute', left: '-9999px', width: 1, height: 1 }} aria-hidden="true" />

              <label style={label}>{t({ id: 'federacao.carte.edit.name' })} *</label>
              <input style={input} value={f.name} onChange={(e) => set('name', e.target.value)} required />

              <div style={{ display: 'flex', gap: 10 }}>
                <div style={{ flex: 1 }}>
                  <label style={label}>{t({ id: 'federacao.carte.edit.city' })}</label>
                  <input style={input} value={f.city} onChange={(e) => set('city', e.target.value)} />
                </div>
                <div style={{ flex: 1 }}>
                  <label style={label}>{t({ id: 'federacao.carte.edit.country' })}</label>
                  <input style={input} value={f.country} onChange={(e) => set('country', e.target.value)} />
                </div>
              </div>

              <label style={label}>{t({ id: 'federacao.carte.edit.category' })}</label>
              <select style={input} value={f.categorie} onChange={(e) => set('categorie', e.target.value)}>
                {CATS.map((c) => <option key={c} value={c}>{t({ id: `federacao.carte.cat.${c}` })}</option>)}
              </select>

              <label style={label}>{t({ id: 'federacao.carte.edit.langs' })}</label>
              <input style={input} value={f.langue_fonds} onChange={(e) => set('langue_fonds', e.target.value)} placeholder="fr, es, it" />

              <label style={label}>{t({ id: 'federacao.carte.edit.site' })}</label>
              <input style={input} value={f.site_url} onChange={(e) => set('site_url', e.target.value)} />

              <div style={{ display: 'flex', gap: 10 }}>
                <div style={{ flex: 1 }}>
                  <label style={label}>{t({ id: 'federacao.carte.edit.email' })}</label>
                  <input style={input} value={f.email} onChange={(e) => set('email', e.target.value)} />
                </div>
                <div style={{ flex: 1 }}>
                  <label style={label}>{t({ id: 'federacao.carte.edit.tel' })}</label>
                  <input style={input} value={f.tel} onChange={(e) => set('tel', e.target.value)} />
                </div>
              </div>

              <label style={label}>{t({ id: 'federacao.carte.edit.address' })}</label>
              <input style={input} value={f.adresse} onChange={(e) => set('adresse', e.target.value)} />

              <label style={label}>{t({ id: 'federacao.carte.edit.notes' })}</label>
              <textarea style={{ ...input, minHeight: 70, resize: 'vertical' }} value={f.notes} onChange={(e) => set('notes', e.target.value)} />

              <label style={label}>{t({ id: 'cartografia.add.submitterNote' })}</label>
              <input style={input} value={f.submitter_note} onChange={(e) => set('submitter_note', e.target.value)} />

              <label style={label}>{t({ id: 'federacao.carte.edit.position' })}</label>
              <div ref={pickerRef} style={{ height: 220, borderRadius: 8, overflow: 'hidden', border: '1px solid rgba(255,255,255,.14)' }} />
              {f.lat != null && (
                <div style={{ fontSize: '.72rem', color: 'var(--brand-muted)', marginTop: 4 }}>{f.lat}, {f.lon}</div>
              )}

              {TURNSTILE_SITE_KEY && (
                <div style={{ marginTop: 16 }}>
                  <Turnstile siteKey={TURNSTILE_SITE_KEY} onSuccess={setToken} options={{ theme: 'dark' }} />
                </div>
              )}

              {state === 'error' && <p style={{ color: '#fca5a5', fontSize: '.85rem', marginTop: 12 }}>{errMsg}</p>}

              <button type="submit" disabled={state === 'sending'}
                style={{ ...input, width: 'auto', marginTop: 18, cursor: 'pointer', background: 'var(--brand-accent, #2563eb)', borderColor: 'transparent', fontWeight: 700, padding: '10px 20px' }}>
                {state === 'sending' ? t({ id: 'cartografia.add.sending' }) : t({ id: 'cartografia.add.submit' })}
              </button>
            </form>
          )}
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
