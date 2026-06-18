import { useEffect, useRef, useState } from 'react';
import { useIntl } from 'react-intl';
import { apiQuery } from '@/lib/supabase';
import CartographyEditModal from './CartographyEditModal';
import './NetworkMap.css';

// Composant carte partagé de l'annuaire géographique du réseau. Leaflet +
// markercluster VENDORISÉS (public/vendor/leaflet/, chargés à la volée). Source =
// table public.cartography_entries via une vue api SECDEF (N1 uniquement : jamais
// email/tél/adresse — MAP-E). Utilisé par :
//   - NetworkMapTab (interne, authentifié·e) → api.cartography_network_v1 (+ can_edit)
//   - CartografiaPage (publique, anon)        → api.cartography_public_v1 (opt-in)
// Édition (MAP-D) : sur la carte interne, les marqueurs éditables (can_edit) portent
// un bouton « Éditer » ouvrant CartographyEditModal. Prop : viewName.

const CATEGORIES = [
  { key: 'biblioteca', color: '#C8102E' },
  { key: 'arquivo', color: '#5B2C6F' },
  { key: 'centro_doc', color: '#1F618D' },
  { key: 'ateneu', color: '#B9770E' },
  { key: 'livraria', color: '#117A65' },
  { key: 'misto', color: '#2C2C2C' },
];
const COLOR = Object.fromEntries(CATEGORIES.map((c) => [c.key, c.color]));

// Filtre MAP-G : réseau AnarBib (membres + partenaires) vs paysage libertaire (cibles).
const SCOPES = ['reseau', 'paysage'];

// Locales servies par la donnée (i18n par collectif). `pt-BR` → `pt`. Repli `fr`.
const MAP_LOCALES = ['fr', 'pt', 'it', 'es', 'en', 'de', 'ca', 'eo', 'nl', 'el'];
function resolveMapLang(locale) {
  const base = (locale || '').toLowerCase().startsWith('pt') ? 'pt' : (locale || '').slice(0, 2).toLowerCase();
  return MAP_LOCALES.includes(base) ? base : 'fr';
}

function loadCss(href) {
  if ([...document.querySelectorAll('link[rel="stylesheet"]')].some((l) => l.href.includes(href))) return;
  const l = document.createElement('link'); l.rel = 'stylesheet'; l.href = href; document.head.appendChild(l);
}
function loadScript(src) {
  return new Promise((resolve, reject) => {
    if ([...document.scripts].some((s) => s.src.includes(src))) return resolve();
    const s = document.createElement('script'); s.src = src; s.async = true;
    s.onload = () => resolve(); s.onerror = () => reject(new Error('load ' + src));
    document.head.appendChild(s);
  });
}
async function loadLeaflet() {
  loadCss('/vendor/leaflet/leaflet.css');
  loadCss('/vendor/leaflet/MarkerCluster.css');
  loadCss('/vendor/leaflet/MarkerCluster.Default.css');
  await loadScript('/vendor/leaflet/leaflet.js');
  await loadScript('/vendor/leaflet/leaflet.markercluster.js');
  return window.L;
}

function esc(s) {
  return String(s || '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

// Marqueur « goutte » coloré par catégorie. Membres AnarBib = emblème réseau (MAP-H).
function dropIcon(L, color, isMember) {
  const inner = isMember
    ? `<img src="/img/icon-192.png" alt="" width="17" height="17" style="position:absolute;left:6.5px;top:5.5px;border-radius:50%;background:#fff;object-fit:contain;box-shadow:0 0 0 1.5px #fff;" />`
    : `<svg width="17" height="17" viewBox="0 0 24 24" style="position:absolute;left:6.5px;top:6px;">`
      + `<circle cx="12" cy="12" r="8.3" fill="none" stroke="#fff" stroke-width="2.2"/>`
      + `<path d="M8 17.5L12 6.5L16 17.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linejoin="round"/>`
      + `<path d="M3.4 14.2H20.6" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></svg>`;
  const svg = `<svg width="30" height="42" viewBox="0 0 30 42" xmlns="http://www.w3.org/2000/svg">`
    + `<path d="M15 41C15 41 28 24 28 14A13 13 0 1 0 2 14C2 24 15 41 15 41Z" fill="${esc(color)}" stroke="#ffffff" stroke-width="1.5"/></svg>`;
  return L.divIcon({
    html: `<div class="ab-map-pin">${svg}${inner}</div>`,
    className: 'ab-map-pinwrap',
    iconSize: [30, 42], iconAnchor: [15, 41], popupAnchor: [0, -38],
  });
}

export default function CartographyMap({ viewName }) {
  const { formatMessage: t, locale } = useIntl();
  const lang = resolveMapLang(locale);

  const containerRef = useRef(null);
  const mapRef = useRef(null);
  const clusterRef = useRef(null);
  const memberLayerRef = useRef(null);
  const markersRef = useRef([]);          // [{ marker, props, cat, scope, text, member }]
  const filtersRef = useRef({ active: new Set(CATEGORIES.map((c) => c.key)), scopes: new Set(SCOPES), query: '' });

  const [status, setStatus] = useState('loading'); // loading | ready | error
  const [total, setTotal] = useState(0);
  const [shown, setShown] = useState(0);
  const [active, setActive] = useState(() => new Set(CATEGORIES.map((c) => c.key)));
  const [scopes, setScopes] = useState(() => new Set(SCOPES));
  const [query, setQuery] = useState('');
  const [editingId, setEditingId] = useState(null);

  function popupHtml(p) {
    const i = (p.i18n[lang] && p.i18n[lang].name) ? p.i18n[lang] : ((p.i18n.fr && p.i18n.fr.name) ? p.i18n.fr : (p.i18n.pt || {}));
    const loc = [i.city, i.country].filter(Boolean).join(', ');
    const site = p.site
      ? `<a href="${esc(p.site)}" target="_blank" rel="noopener noreferrer">${esc(p.site.replace(/^https?:\/\//, ''))}</a>`
      : '';
    const badge = p.anarbib ? `<span class="ab-map-badge">${esc(t({ id: 'federacao.carte.member' }))}</span>` : '';
    const typeLabel = p.category ? t({ id: `federacao.carte.cat.${p.category}` }) : '';
    const editBtn = p.canEdit
      ? `<button type="button" class="ab-map-edit-btn" data-entry-id="${esc(p.id)}" style="margin-top:8px;padding:4px 11px;border-radius:6px;border:1px solid rgba(0,0,0,.18);background:#2563eb;color:#fff;font-size:.8rem;cursor:pointer;">${esc(t({ id: 'federacao.carte.edit' }))}</button>`
      : '';
    return `<div class="ab-map-popup">
      <div class="ab-map-pop-title"><span class="ab-map-dot" style="background:${esc(p.color)}"></span>${esc(i.name)}${badge}</div>
      ${typeLabel ? `<div class="ab-map-pop-type">${esc(typeLabel)}</div>` : ''}
      ${loc ? `<div class="ab-map-pop-loc">${esc(loc)}</div>` : ''}
      ${p.reseau ? `<div class="ab-map-pop-net">${esc(t({ id: 'federacao.carte.network' }))} : ${esc(p.reseau)}</div>` : ''}
      ${site ? `<div class="ab-map-pop-site">${site}</div>` : ''}
      ${i.notes ? `<div class="ab-map-pop-notes">${esc(i.notes)}</div>` : ''}
      ${editBtn}
    </div>`;
  }

  function applyFilters() {
    const cluster = clusterRef.current; const memberLayer = memberLayerRef.current; const L = window.L;
    if (!cluster || !memberLayer || !L) return;
    const { active: act, scopes: scp, query: q } = filtersRef.current;
    const qq = q.trim().toLowerCase();
    const matched = markersRef.current.filter((m) => act.has(m.cat) && scp.has(m.scope) && (!qq || m.text.includes(qq)));
    cluster.clearLayers(); memberLayer.clearLayers();
    cluster.addLayers(matched.filter((m) => !m.member).map((m) => m.marker));
    matched.filter((m) => m.member).forEach((m) => memberLayer.addLayer(m.marker));
    setShown(matched.length);
    if (qq && matched.length && mapRef.current) {
      try { mapRef.current.fitBounds(L.featureGroup(matched.map((m) => m.marker)).getBounds().pad(0.2), { maxZoom: 8 }); } catch { /* ignore */ }
    }
  }

  // Charge (ou recharge) les données et reconstruit les marqueurs. Réutilise la
  // carte Leaflet déjà montée (window.L). Appelé à l'init et après une édition.
  async function loadData() {
    const L = window.L;
    const { data: rows, error: qErr } = await apiQuery(viewName);
    if (qErr || !Array.isArray(rows)) throw new Error(viewName + ' ' + (qErr?.message || 'no data'));
    markersRef.current = rows.map((row) => {
      const category = row.categorie;
      const anarbib = row.statut_anarbib === 'membre';
      const scope = row.statut_anarbib === 'cible' ? 'paysage' : 'reseau';
      const i18n = {};
      for (const lc of MAP_LOCALES) {
        i18n[lc] = {
          name: (row.name_i18n || {})[lc] || '',
          city: (row.city_i18n || {})[lc] || '',
          country: (row.country_i18n || {})[lc] || '',
          notes: (row.notes_i18n || {})[lc] || '',
        };
      }
      const p = { id: row.id, canEdit: !!row.can_edit, color: COLOR[category] || '#2C2C2C', category, anarbib, reseau: row.reseau, site: row.site_url, i18n };
      const marker = L.marker([Number(row.lat), Number(row.lon)], { icon: dropIcon(L, p.color, anarbib) });
      marker.bindPopup(popupHtml(p), { maxWidth: 300 });
      const text = Object.values(i18n).flatMap((x) => [x.name, x.city, x.country]).filter(Boolean).join(' ').toLowerCase();
      return { marker, props: p, cat: category, scope, text, member: anarbib };
    });
    setTotal(markersRef.current.length);
    applyFilters();
  }

  // Init (une fois) : Leaflet + tuiles + données + délégation du clic « Éditer ».
  useEffect(() => {
    let cancelled = false;
    const containerEl = containerRef.current;
    const onEditClick = (e) => {
      const btn = e.target.closest && e.target.closest('.ab-map-edit-btn');
      if (btn && btn.dataset.entryId) { e.preventDefault(); setEditingId(btn.dataset.entryId); }
    };
    (async () => {
      try {
        const L = await loadLeaflet();
        if (cancelled || !containerRef.current) return;
        const map = L.map(containerRef.current, { worldCopyJump: true }).setView([25, 5], 2);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          attribution: '&copy; OpenStreetMap', maxZoom: 18,
        }).addTo(map);
        const cluster = L.markerClusterGroup({ maxClusterRadius: 45, chunkedLoading: true });
        map.addLayer(cluster);
        const memberLayer = L.layerGroup().addTo(map);
        mapRef.current = map; clusterRef.current = cluster; memberLayerRef.current = memberLayer;
        if (containerEl) containerEl.addEventListener('click', onEditClick);
        await loadData();
        if (cancelled) return;
        setStatus('ready');
        setTimeout(() => { try { map.invalidateSize(); } catch { /* ignore */ } }, 200);
      } catch (e) {
        if (!cancelled) { console.error('[CartographyMap]', e); setStatus('error'); }
      }
    })();
    return () => {
      cancelled = true;
      if (containerEl) containerEl.removeEventListener('click', onEditClick);
      if (mapRef.current) { mapRef.current.remove(); mapRef.current = null; }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [viewName]);

  // Re-filtrage quand légende / scope / recherche changent.
  useEffect(() => {
    filtersRef.current = { active, scopes, query };
    if (status === 'ready') applyFilters();
  }, [active, scopes, query, status]);

  // Re-localiser les popups quand la langue change (sans re-télécharger).
  useEffect(() => {
    if (status !== 'ready') return;
    for (const m of markersRef.current) {
      try { m.marker.setPopupContent(popupHtml(m.props)); } catch { /* ignore */ }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lang, status]);

  const toggleCat = (key) => setActive((prev) => {
    const n = new Set(prev); if (n.has(key)) n.delete(key); else n.add(key);
    return n.size ? n : prev;
  });
  const toggleScope = (key) => setScopes((prev) => {
    const n = new Set(prev); if (n.has(key)) n.delete(key); else n.add(key);
    return n.size ? n : prev;
  });

  return (
    <div className="ab-map-wrap">
      <p className="ab-map-lead">{t({ id: 'federacao.carte.lead' })}</p>
      <div className="ab-map-head">
        <div className="ab-map-count">{t({ id: 'federacao.carte.count' }, { shown, total })}</div>
        <input
          className="ab-map-search" type="search"
          placeholder={t({ id: 'federacao.carte.search' })}
          value={query} onChange={(e) => setQuery(e.target.value)}
        />
      </div>
      <div className="ab-map-legend">
        {SCOPES.map((k) => (
          <button key={k} type="button" className={`ab-map-leg ab-map-scope${scopes.has(k) ? '' : ' off'}`} onClick={() => toggleScope(k)}>
            {t({ id: `federacao.carte.scope.${k}` })}
          </button>
        ))}
        <span className="ab-map-legsep" aria-hidden="true" />
        {CATEGORIES.map((c) => (
          <button key={c.key} type="button" className={`ab-map-leg${active.has(c.key) ? '' : ' off'}`} onClick={() => toggleCat(c.key)}>
            <span className="ab-map-dot" style={{ background: c.color }} />{t({ id: `federacao.carte.cat.${c.key}` })}
          </button>
        ))}
      </div>
      <div className="ab-map-canvas" ref={containerRef} />
      {status === 'loading' && <div className="ab-map-status">{t({ id: 'common.loading' })}</div>}
      {status === 'error' && <div className="ab-map-status ab-map-err">{t({ id: 'federacao.carte.error' })}</div>}
      {status === 'ready' && shown === 0 && (
        <div className="ab-map-status">{t({ id: 'federacao.carte.empty' })}</div>
      )}
      <div className="ab-map-foot">{t({ id: 'federacao.carte.attribution' })}</div>
      {editingId && (
        <CartographyEditModal
          entryId={editingId}
          onClose={() => setEditingId(null)}
          onSaved={() => { setEditingId(null); loadData(); }}
        />
      )}
    </div>
  );
}
