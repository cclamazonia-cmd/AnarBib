import { useEffect, useRef, useState } from 'react';
import { useIntl } from 'react-intl';
import { apiRpc, supabase } from '@/lib/supabase';

// Modale d'édition d'une fiche cartographique (Phase 3, MAP-D). Ouverte depuis la
// carte interne (clic « Éditer » sur un marqueur éditable). Pré-remplie via
// api.fn_cartography_get_for_edit (révèle les contacts N2 aux seuls éditeurs).
// Enregistre via update_self (staff de la biblio liée, D1) ou update_admin
// (coordination, can_admin → champs structurants D3). Le nom et les notes sont
// édités dans la langue d'affichage courante (fusion dans le JSONB 10 locales).

const CATS = ['biblioteca', 'arquivo', 'centro_doc', 'ateneu', 'livraria', 'misto'];
const STATUTS = ['membre', 'partenaire', 'cible'];
const MAP_LOCALES = ['fr', 'pt', 'it', 'es', 'en', 'de', 'ca', 'eo', 'nl', 'el'];
function mapLang(locale) {
  const b = (locale || '').toLowerCase().startsWith('pt') ? 'pt' : (locale || '').slice(0, 2).toLowerCase();
  return MAP_LOCALES.includes(b) ? b : 'fr';
}

export default function CartographyEditModal({ entryId, onClose, onSaved }) {
  const { formatMessage: t, locale } = useIntl();
  const lang = mapLang(locale);
  const [row, setRow] = useState(null);
  const [form, setForm] = useState(null);
  const [err, setErr] = useState('');
  const [saving, setSaving] = useState(false);
  const [geoBusy, setGeoBusy] = useState(false);
  const [geoMsg, setGeoMsg] = useState('');
  const pickerDivRef = useRef(null);
  const pickerMapRef = useRef(null);
  const pickerMarkerRef = useRef(null);

  useEffect(() => {
    let cancel = false;
    (async () => {
      const { data, error } = await apiRpc('fn_cartography_get_for_edit', { p_entry_id: entryId });
      if (cancel) return;
      if (error || !Array.isArray(data) || !data[0]) { setErr(t({ id: 'federacao.carte.edit.error' })); return; }
      const r = data[0];
      setRow(r);
      setForm({
        name: (r.name_i18n || {})[lang] || '',
        city: (r.city_i18n || {})[lang] || '',
        country: (r.country_i18n || {})[lang] || '',
        notes: (r.notes_i18n || {})[lang] || '',
        langue_fonds: (r.langue_fonds || []).join(', '),
        site_url: r.site_url || '',
        email: r.email || '',
        tel: r.tel || '',
        adresse: r.adresse || '',
        statut_public: !!r.statut_public,
        contact_public: !!r.contact_public,
        categorie: r.categorie,
        statut_anarbib: r.statut_anarbib,
        lat: Number(r.lat), lon: Number(r.lon),
      });
    })();
    return () => { cancel = true; };
  }, [entryId, lang, t]);

  // Mini-carte de positionnement (coordination, MAP-F partiel) : marqueur
  // déplaçable + clic pour repositionner. Pas de géocodage adresse→GPS (Nominatim
  // self-hosted = infra à venir) ; ici saisie des coordonnées par clic/glisser.
  useEffect(() => {
    if (!row || !row.can_admin || !window.L || !pickerDivRef.current || pickerMapRef.current) return;
    const L = window.L;
    const lat0 = Number(row.lat) || 0;
    const lon0 = Number(row.lon) || 0;
    const map = L.map(pickerDivRef.current, { worldCopyJump: true, attributionControl: false }).setView([lat0, lon0], 6);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18 }).addTo(map);
    const marker = L.marker([lat0, lon0], { draggable: true }).addTo(map);
    const apply = (ll) => setForm((f) => ({ ...f, lat: Number(ll.lat.toFixed(5)), lon: Number(ll.lng.toFixed(5)) }));
    marker.on('dragend', () => apply(marker.getLatLng()));
    map.on('click', (e) => { marker.setLatLng(e.latlng); apply(e.latlng); });
    pickerMapRef.current = map;
    pickerMarkerRef.current = marker;
    setTimeout(() => { try { map.invalidateSize(); } catch { /* ignore */ } }, 150);
    return () => { try { map.remove(); } catch { /* ignore */ } pickerMapRef.current = null; pickerMarkerRef.current = null; };
  }, [row]);

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  async function save() {
    setSaving(true); setErr('');
    const payload = {
      name_i18n: { ...(row.name_i18n || {}), [lang]: form.name },
      city_i18n: { ...(row.city_i18n || {}), [lang]: form.city },
      country_i18n: { ...(row.country_i18n || {}), [lang]: form.country },
      notes_i18n: { ...(row.notes_i18n || {}), [lang]: form.notes },
      langue_fonds: form.langue_fonds.split(/[,;]+/).map((s) => s.trim()).filter(Boolean),
      site_url: form.site_url,
      email: form.email,
      tel: form.tel,
      adresse: form.adresse,
      statut_public: form.statut_public,
      contact_public: form.contact_public,
    };
    if (row.can_admin) {
      payload.categorie = form.categorie;
      payload.statut_anarbib = form.statut_anarbib;
      if (Number.isFinite(form.lat) && Number.isFinite(form.lon)) {
        payload.lat = form.lat;
        payload.lon = form.lon;
      }
    }
    const fn = row.can_admin ? 'fn_cartography_update_admin' : 'fn_cartography_update_self';
    const { error } = await apiRpc(fn, { p_entry_id: entryId, p_payload: payload });
    setSaving(false);
    if (error) { setErr(t({ id: 'federacao.carte.edit.error' })); return; }
    onSaved();
  }

  // Géocodage adresse→GPS via le proxy serveur (EF geocode → Nominatim self-hosted).
  // Repli silencieux sur le pin manuel si indisponible (MAP-F / spec §7).
  async function geocodeFromAddress() {
    const q = [form.adresse, form.city, form.country].filter(Boolean).join(', ');
    if (q.trim().length < 3) return;
    setGeoBusy(true); setGeoMsg('');
    const { data, error } = await supabase.functions.invoke('geocode', { body: { q } });
    setGeoBusy(false);
    const lat = Number(data?.lat), lon = Number(data?.lon);
    if (error || !data?.found || !Number.isFinite(lat) || !Number.isFinite(lon)) {
      setGeoMsg(t({ id: 'federacao.carte.edit.geocodeFail' })); return;
    }
    const rlat = Number(lat.toFixed(5)), rlon = Number(lon.toFixed(5));
    setForm((f) => ({ ...f, lat: rlat, lon: rlon }));
    if (pickerMarkerRef.current && pickerMapRef.current) {
      pickerMarkerRef.current.setLatLng([rlat, rlon]);
      pickerMapRef.current.setView([rlat, rlon], 13);
    }
  }

  const overlay = {
    position: 'fixed', inset: 0, zIndex: 4000, background: 'rgba(0,0,0,.55)',
    display: 'flex', alignItems: 'flex-start', justifyContent: 'center', padding: '5vh 16px', overflowY: 'auto',
  };
  const panel = {
    width: '100%', maxWidth: 520,
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)', borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)', padding: '22px 22px 26px',
  };
  const label = { display: 'block', fontSize: '.78rem', color: 'var(--brand-muted)', margin: '12px 0 4px' };
  const input = {
    width: '100%', boxSizing: 'border-box', padding: '8px 10px', borderRadius: 8,
    border: '1px solid rgba(255,255,255,.14)', background: 'rgba(255,255,255,.04)', color: 'inherit', fontSize: '.9rem',
  };
  const checkRow = { display: 'flex', alignItems: 'center', gap: 8, marginTop: 12, fontSize: '.88rem' };

  return (
    <div style={overlay} onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={panel} role="dialog" aria-modal="true">
        <h2 style={{ fontSize: '1.2rem', fontWeight: 800, marginBottom: 4 }}>{t({ id: 'federacao.carte.edit.title' })}</h2>
        {!form ? (
          <p style={{ color: 'var(--brand-muted)' }}>{err || t({ id: 'common.loading' })}</p>
        ) : (
          <>
            <p style={{ fontSize: '.78rem', color: 'var(--brand-muted)', margin: '2px 0 6px' }}>
              {t({ id: 'federacao.carte.edit.localeNote' })} ({lang})
            </p>

            <label style={label}>{t({ id: 'federacao.carte.edit.name' })}</label>
            <input style={input} value={form.name} onChange={(e) => set('name', e.target.value)} />

            <div style={{ display: 'flex', gap: 10 }}>
              <div style={{ flex: 1 }}>
                <label style={label}>{t({ id: 'federacao.carte.edit.city' })}</label>
                <input style={input} value={form.city} onChange={(e) => set('city', e.target.value)} />
              </div>
              <div style={{ flex: 1 }}>
                <label style={label}>{t({ id: 'federacao.carte.edit.country' })}</label>
                <input style={input} value={form.country} onChange={(e) => set('country', e.target.value)} />
              </div>
            </div>

            <label style={label}>{t({ id: 'federacao.carte.edit.notes' })}</label>
            <textarea style={{ ...input, minHeight: 80, resize: 'vertical' }} value={form.notes} onChange={(e) => set('notes', e.target.value)} />

            <label style={label}>{t({ id: 'federacao.carte.edit.langs' })}</label>
            <input style={input} value={form.langue_fonds} onChange={(e) => set('langue_fonds', e.target.value)} placeholder="fr, es, it" />

            <label style={label}>{t({ id: 'federacao.carte.edit.site' })}</label>
            <input style={input} value={form.site_url} onChange={(e) => set('site_url', e.target.value)} />

            <div style={{ display: 'flex', gap: 10 }}>
              <div style={{ flex: 1 }}>
                <label style={label}>{t({ id: 'federacao.carte.edit.email' })}</label>
                <input style={input} value={form.email} onChange={(e) => set('email', e.target.value)} />
              </div>
              <div style={{ flex: 1 }}>
                <label style={label}>{t({ id: 'federacao.carte.edit.tel' })}</label>
                <input style={input} value={form.tel} onChange={(e) => set('tel', e.target.value)} />
              </div>
            </div>

            <label style={label}>{t({ id: 'federacao.carte.edit.address' })}</label>
            <input style={input} value={form.adresse} onChange={(e) => set('adresse', e.target.value)} />

            <label style={checkRow}>
              <input type="checkbox" checked={form.statut_public} onChange={(e) => set('statut_public', e.target.checked)} />
              {t({ id: 'federacao.carte.edit.public' })}
            </label>
            <label style={checkRow}>
              <input type="checkbox" checked={form.contact_public} onChange={(e) => set('contact_public', e.target.checked)} />
              {t({ id: 'federacao.carte.edit.contactPublic' })}
            </label>

            {row.can_admin && (
              <div style={{ marginTop: 16, paddingTop: 12, borderTop: '1px solid rgba(255,255,255,.10)' }}>
                <div style={{ fontSize: '.78rem', fontWeight: 700, color: 'var(--brand-muted)', textTransform: 'uppercase', letterSpacing: '.03em' }}>
                  {t({ id: 'federacao.carte.edit.adminSection' })}
                </div>
                <label style={label}>{t({ id: 'federacao.carte.edit.category' })}</label>
                <select style={input} value={form.categorie} onChange={(e) => set('categorie', e.target.value)}>
                  {CATS.map((c) => <option key={c} value={c}>{t({ id: `federacao.carte.cat.${c}` })}</option>)}
                </select>
                <label style={label}>{t({ id: 'federacao.carte.edit.status' })}</label>
                <select style={input} value={form.statut_anarbib} onChange={(e) => set('statut_anarbib', e.target.value)}>
                  {STATUTS.map((s) => <option key={s} value={s}>{t({ id: `federacao.carte.statut.${s}` })}</option>)}
                </select>
                <label style={label}>{t({ id: 'federacao.carte.edit.position' })}</label>
                <button type="button" onClick={geocodeFromAddress} disabled={geoBusy}
                  style={{ ...input, width: 'auto', cursor: 'pointer', background: 'rgba(255,255,255,.06)', fontSize: '.8rem', padding: '6px 12px', marginBottom: 6 }}>
                  {geoBusy ? '…' : t({ id: 'federacao.carte.edit.geocode' })}
                </button>
                {geoMsg && <div style={{ fontSize: '.72rem', color: '#fca5a5', marginBottom: 4 }}>{geoMsg}</div>}
                <div ref={pickerDivRef} style={{ height: 200, borderRadius: 8, overflow: 'hidden', border: '1px solid rgba(255,255,255,.14)' }} />
                <div style={{ fontSize: '.72rem', color: 'var(--brand-muted)', marginTop: 4 }}>
                  {Number(form.lat).toFixed(5)}, {Number(form.lon).toFixed(5)}
                </div>
              </div>
            )}

            {err && <p style={{ color: '#fca5a5', fontSize: '.85rem', marginTop: 12 }}>{err}</p>}

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 20 }}>
              <button type="button" onClick={onClose} disabled={saving}
                style={{ ...input, width: 'auto', cursor: 'pointer', background: 'transparent' }}>
                {t({ id: 'federacao.carte.edit.cancel' })}
              </button>
              <button type="button" onClick={save} disabled={saving}
                style={{ ...input, width: 'auto', cursor: 'pointer', background: 'rgb(var(--brand-accent-rgb))', borderColor: 'transparent', fontWeight: 700 }}>
                {t({ id: 'federacao.carte.edit.save' })}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
