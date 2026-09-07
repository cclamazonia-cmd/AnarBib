// =============================================================================
// mapTiles.js — fond de carte AUTO-HÉBERGÉ des cartes Leaflet (backlog E5, 07/09/2026)
// =============================================================================
// Avant : les trois cartes (CartographyMap, CartographyEditModal, CartografiaAjouterPage)
// chargeaient leurs tuiles depuis les serveurs d'OpenStreetMap — la seule exception
// anti-pistage restante (INV-5) : le navigateur de la visiteuse livrait son IP
// à un tiers, ce que la page vie privée déclarait (privacy.s6.maptiles).
//
// Après : UN fichier PMTiles (Protomaps, dérivé d'OpenStreetMap, licence ODbL,
// attribution OSM obligatoire) extrait du planet avec `pmtiles extract --maxzoom=12`
// (18 Go) et servi par notre Storage. Le navigateur ne lit que les octets des tuiles
// affichées, par requêtes HTTP Range — aucun appel vers un domaine tiers. Le rendu
// est fait dans Leaflet par protomaps-leaflet (vendorisé, public/vendor/leaflet/,
// BSD-3, dist 4.0.1, sha256 8e3d2aa0…ec9e) : tuiles vectorielles dessinées en
// canvas, étiquettes en polices web — pas de serveur de glyphes.
//
// Au-delà du zoom 12, les tuiles vectorielles sont agrandies (overzoom) : les rues
// existantes restent nettes, aucune donnée de plus n'est chargée. Pour aller plus
// fin, ré-extraire avec un maxzoom plus grand (z13 = 36 Go, z14 = 68 Go, z15 = 138 Go
// mesurés le 07/09/2026) et ajuster MAPTILES_MAX_DATA_ZOOM.
//
// Recette d'extraction / de rafraîchissement : scripts/maptiles/README.md.
// Déménagement (I2, VM Herbes Folles) : poser VITE_MAPTILES_URL au build, rien d'autre.
// =============================================================================

const SUPABASE_URL = (import.meta.env.VITE_SUPABASE_URL || '').replace(/\/+$/, '');

/** Adresse du fichier PMTiles. Par défaut : bucket public `map-tiles` du projet. */
export const MAPTILES_URL = import.meta.env.VITE_MAPTILES_URL
  || `${SUPABASE_URL}/storage/v1/object/public/map-tiles/planet-z12.pmtiles`;

/** Zoom maximal contenu dans le fichier (au-delà : overzoom côté client). */
export const MAPTILES_MAX_DATA_ZOOM = 12;

/** Zoom maximal offert à l'utilisatrice (identique à l'ancien réglage OSM). */
export const MAPTILES_MAX_ZOOM = 18;

// Langues d'étiquettes présentes dans le fond Protomaps v4 (name:xx). Le catalan et
// l'espéranto n'y sont pas : on laisse alors les noms locaux (pas de repli vers une
// autre langue, qui serait un choix politique fait à la place des lectrices).
const BASEMAP_LANGS = new Set(['fr', 'pt', 'it', 'es', 'en', 'de', 'nl', 'el']);

export function basemapLang(locale) {
  const l = (locale || '').toLowerCase();
  const base = l.startsWith('pt') ? 'pt' : l.slice(0, 2);
  return BASEMAP_LANGS.has(base) ? base : undefined;
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    if ([...document.scripts].some((s) => s.src.includes(src))) return resolve();
    const s = document.createElement('script'); s.src = src; s.async = true;
    s.onload = () => resolve(); s.onerror = () => reject(new Error('load ' + src));
    document.head.appendChild(s);
  });
}

/**
 * Ajoute le fond de carte auto-hébergé à une carte Leaflet déjà créée.
 * @param {object} map   instance L.map
 * @param {object} opts  { locale, attribution }
 * @returns {Promise<object>} la couche ajoutée
 */
export async function addBasemap(map, { locale, attribution } = {}) {
  await loadScript('/vendor/leaflet/protomaps-leaflet.js');
  const layer = window.protomapsL.leafletLayer({
    url: MAPTILES_URL,
    flavor: 'light',
    lang: basemapLang(locale),
    maxDataZoom: MAPTILES_MAX_DATA_ZOOM,
    maxZoom: MAPTILES_MAX_ZOOM,
    attribution: attribution === undefined ? '&copy; OpenStreetMap' : attribution,
  });
  layer.addTo(map);
  return layer;
}
