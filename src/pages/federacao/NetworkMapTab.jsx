import { useEffect, useRef, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import './NetworkMap.css';

// Annuaire géographique des collectifs (uMap → GeoJSON). Leaflet + markercluster
// VENDORISÉS (public/vendor/leaflet/, chargés à la volée) — pas de dépendance npm.
// Marqueurs colorés par catégorie, popups locale-aware (FR/PT). La donnée est
// servie par l'edge function `network-map` (auth requise, bucket PRIVÉ) — jamais
// par une URL publique, pour limiter l'export (verrouillage demandé). Payload déjà
// minimisé à la source (sans email/tél/adresse).

const CATEGORIES = [
  { key: 'biblioteca', color: '#C8102E' },
  { key: 'arquivo', color: '#5B2C6F' },
  { key: 'centro_doc', color: '#1F618D' },
  { key: 'ateneu', color: '#B9770E' },
  { key: 'livraria', color: '#117A65' },
  { key: 'misto', color: '#2C2C2C' },
];

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

// Marqueur « goutte » (style uMap « Drop ») coloré par catégorie. Les membres
// d'AnarBib (BLMF, Maloca…) portent l'emblème du réseau ; les autres, une
// pastille blanche.
function dropIcon(L, color, isMember) {
  const inner = isMember
    ? `<img src="/img/icon-192.png" alt="" width="17" height="17" style="position:absolute;left:6.5px;top:5.5px;border-radius:50%;background:#fff;object-fit:contain;box-shadow:0 0 0 1.5px #fff;" />`
    : `<span style="position:absolute;left:10px;top:9px;width:10px;height:10px;border-radius:50%;background:#fff;"></span>`;
  const svg = `<svg width="30" height="42" viewBox="0 0 30 42" xmlns="http://www.w3.org/2000/svg">`
    + `<path d="M15 41C15 41 28 24 28 14A13 13 0 1 0 2 14C2 24 15 41 15 41Z" fill="${esc(color)}" stroke="#ffffff" stroke-width="1.5"/></svg>`;
  return L.divIcon({
    html: `<div class="ab-map-pin">${svg}${inner}</div>`,
    className: 'ab-map-pinwrap',
    iconSize: [30, 42], iconAnchor: [15, 41], popupAnchor: [0, -38],
  });
}

export default function NetworkMapTab() {
  const { formatMessage: t, locale } = useIntl();
  const lang = locale && locale.startsWith('pt') ? 'pt' : 'fr';

  const containerRef = useRef(null);
  const mapRef = useRef(null);
  const clusterRef = useRef(null);
  const memberLayerRef = useRef(null);    // membres AnarBib hors cluster (toujours visibles)
  const markersRef = useRef([]);          // [{ marker, cat, text, member }]
  const filtersRef = useRef({ active: new Set(CATEGORIES.map((c) => c.key)), query: '' });

  const [status, setStatus] = useState('loading'); // loading | ready | error
  const [total, setTotal] = useState(0);
  const [shown, setShown] = useState(0);
  const [active, setActive] = useState(() => new Set(CATEGORIES.map((c) => c.key)));
  const [query, setQuery] = useState('');

  function popupHtml(p) {
    const i = (p.i18n[lang] && p.i18n[lang].name) ? p.i18n[lang] : (p.i18n.fr.name ? p.i18n.fr : p.i18n.pt);
    const loc = [i.city, i.country].filter(Boolean).join(', ');
    const site = p.site
      ? `<a href="${esc(p.site)}" target="_blank" rel="noopener noreferrer">${esc(p.site.replace(/^https?:\/\//, ''))}</a>`
      : '';
    const badge = p.anarbib ? `<span class="ab-map-badge">${esc(t({ id: 'federacao.carte.member' }))}</span>` : '';
    return `<div class="ab-map-popup">
      <div class="ab-map-pop-title"><span class="ab-map-dot" style="background:${esc(p.color)}"></span>${esc(i.name)}${badge}</div>
      ${i.typeLabel ? `<div class="ab-map-pop-type">${esc(i.typeLabel)}</div>` : ''}
      ${loc ? `<div class="ab-map-pop-loc">${esc(loc)}</div>` : ''}
      ${i.address ? `<div class="ab-map-pop-addr">${esc(i.address)}</div>` : ''}
      ${p.reseau ? `<div class="ab-map-pop-net">${esc(t({ id: 'federacao.carte.network' }))} : ${esc(p.reseau)}</div>` : ''}
      ${site ? `<div class="ab-map-pop-site">${site}</div>` : ''}
      ${i.notes ? `<div class="ab-map-pop-notes">${esc(i.notes)}</div>` : ''}
    </div>`;
  }

  function applyFilters() {
    const cluster = clusterRef.current; const memberLayer = memberLayerRef.current; const L = window.L;
    if (!cluster || !memberLayer || !L) return;
    const { active: act, query: q } = filtersRef.current;
    const qq = q.trim().toLowerCase();
    const matched = markersRef.current.filter((m) => act.has(m.cat) && (!qq || m.text.includes(qq)));
    cluster.clearLayers(); memberLayer.clearLayers();
    // Membres AnarBib : hors cluster, TOUJOURS visibles (emblème mis en avant, jamais noyé).
    cluster.addLayers(matched.filter((m) => !m.member).map((m) => m.marker));
    matched.filter((m) => m.member).forEach((m) => memberLayer.addLayer(m.marker));
    setShown(matched.length);
    if (qq && matched.length && mapRef.current) {
      try { mapRef.current.fitBounds(L.featureGroup(matched.map((m) => m.marker)).getBounds().pad(0.2), { maxZoom: 8 }); } catch { /* ignore */ }
    }
  }

  // Init (une fois) : Leaflet + tuiles + données + marqueurs.
  useEffect(() => {
    let cancelled = false;
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

        const { data: gj, error: gErr } = await supabase.functions.invoke('network-map');
        if (gErr || !gj || !gj.features) throw new Error('network-map ' + (gErr?.message || 'no data'));
        if (cancelled) return;

        markersRef.current = gj.features.map((f) => {
          const p = f.properties; const [lon, lat] = f.geometry.coordinates;
          const marker = L.marker([lat, lon], { icon: dropIcon(L, p.color, p.anarbib) });
          marker.bindPopup(popupHtml(p), { maxWidth: 300 });
          const fr = p.i18n.fr; const pt = p.i18n.pt;
          const text = [fr.name, fr.city, fr.country, pt.name, pt.city, pt.country].join(' ').toLowerCase();
          return { marker, cat: p.category, text, member: !!p.anarbib };
        });
        setTotal(markersRef.current.length);
        applyFilters();
        setStatus('ready');
        // Leaflet calcule mal sa taille si le conteneur a été monté caché : on force.
        setTimeout(() => { try { map.invalidateSize(); } catch { /* ignore */ } }, 200);
      } catch (e) {
        if (!cancelled) { console.error('[NetworkMap]', e); setStatus('error'); }
      }
    })();
    return () => { cancelled = true; if (mapRef.current) { mapRef.current.remove(); mapRef.current = null; } };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Re-filtrage quand légende / recherche changent.
  useEffect(() => {
    filtersRef.current = { active, query };
    if (status === 'ready') applyFilters();
  }, [active, query, status]);

  const toggleCat = (key) => setActive((prev) => {
    const n = new Set(prev); if (n.has(key)) n.delete(key); else n.add(key);
    return n.size ? n : prev; // ne jamais tout masquer
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
        {CATEGORIES.map((c) => (
          <button key={c.key} type="button" className={`ab-map-leg${active.has(c.key) ? '' : ' off'}`} onClick={() => toggleCat(c.key)}>
            <span className="ab-map-dot" style={{ background: c.color }} />{t({ id: `federacao.carte.cat.${c.key}` })}
          </button>
        ))}
      </div>
      <div className="ab-map-canvas" ref={containerRef} />
      {status === 'loading' && <div className="ab-map-status">{t({ id: 'common.loading' })}</div>}
      {status === 'error' && <div className="ab-map-status ab-map-err">{t({ id: 'federacao.carte.error' })}</div>}
      <div className="ab-map-foot">{t({ id: 'federacao.carte.attribution' })}</div>
    </div>
  );
}
