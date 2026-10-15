// =============================================================================
// mapTiles.js — fond de carte AUTO-HÉBERGÉ des cartes Leaflet (backlog E5, 07/09/2026)
// =============================================================================
// Avant : les trois cartes (CartographyMap, CartographyEditModal, CartografiaAjouterPage)
// chargeaient leurs tuiles depuis les serveurs d'OpenStreetMap — la seule exception
// anti-pistage restante (INV-5) : le navigateur de la visiteuse livrait son IP
// à un tiers, ce que la page vie privée déclarait (privacy.s6.maptiles).
//
// Après : UN fichier PMTiles (Protomaps, dérivé d'OpenStreetMap, licence ODbL,
// attribution OSM obligatoire) extrait du planet avec `pmtiles extract --maxzoom=13`
// (≈ 36 Go, planet du 17/09/2026 ; z12 = 18 Go du 07 au 21/09) et servi par notre
// Storage. Pourquoi z13 et pas z14 : le z14 pèse 68 Go, et l'envoi TUS du Storage
// plafonne à 62,9 Go (10 000 morceaux de 6 Mio) — payé à 92 % d'un envoi le 21/09.
// Le navigateur ne lit que les octets des tuiles
// affichées, par requêtes HTTP Range — aucun appel vers un domaine tiers. Le rendu
// est fait dans Leaflet par protomaps-leaflet (vendorisé, public/vendor/leaflet/,
// BSD-3, dist 4.0.1, sha256 8e3d2aa0…ec9e) : tuiles vectorielles dessinées en
// canvas, étiquettes en polices web — pas de serveur de glyphes.
//
// Au-delà du zoom 13, les tuiles vectorielles sont agrandies (overzoom) : les rues
// et leurs noms restent nets, aucune donnée de plus n'est chargée. Les bâtiments
// (z14 = 68 Go) et le planet complet (z15 = 138 Go) attendent la VM de I2 : là, le
// fichier s'extrait et se sert sur place, sans ligne montante ni plafond d'envoi.
//
// Recette d'extraction / de rafraîchissement : scripts/maptiles/README.md.
// Déménagement (I2, VM Herbes Folles) : poser VITE_MAPTILES_URL au build, rien d'autre.
// =============================================================================

import { loadVendorScript } from '@/lib/loadVendorScript';
import { resolveSupabaseUrl } from '@/lib/supabaseUrl';

// Par le résolveur, jamais la variable brute : sur une pile auto-hébergée elle
// vaut 'auto', et `auto/storage/v1/…` tombait sur index.html — carte blanche
// (ticket #36 du camarade, 15/10/2026).
const SUPABASE_URL = (resolveSupabaseUrl() || '').replace(/\/+$/, '');

/** Adresse du fichier PMTiles. Par défaut : bucket public `map-tiles` du projet. */
export const MAPTILES_URL = import.meta.env.VITE_MAPTILES_URL
  || `${SUPABASE_URL}/storage/v1/object/public/map-tiles/planet-z13.pmtiles`;

/** Zoom maximal contenu dans le fichier (au-delà : overzoom côté client). */
export const MAPTILES_MAX_DATA_ZOOM = 13;

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

/**
 * Les lectures du fichier PMTiles ne passent PAS par le cache HTTP du navigateur.
 *
 * Vécu le 12/10/2026 sur le Brave de Xavier : à chaque première visite, le cache
 * rendait une réponse 200 (fichier entier annoncé) à une demande de plage au lieu
 * du 206 que le serveur envoie toujours. Le greffon lève alors « Server returned no
 * content-length header or content-length exceeding request » et abandonne la tuile
 * sans réessayer : points sans fond de carte, revenu après deux rechargements. Avec
 * le cache désactivé dans les outils du navigateur, la carte s'affichait du premier
 * coup, 206 partout. Le serveur, lui, répond 206 depuis ce poste comme depuis un
 * profil vierge (Brave et Edge).
 *
 * Le greffon ne permet pas de régler son `fetch` : on enrobe donc `window.fetch`,
 * une seule fois, et SEULEMENT pour l'adresse du fichier de carte. Coût : l'en-tête
 * et les répertoires (≈ 50 Ko) sont relus à chaque visite ; le greffon garde les
 * tuiles en mémoire pendant la visite.
 */
export function lireCarteSansCache(win = window, urlCarte = MAPTILES_URL) {
  if (!win.fetch || win.fetch.__carteSansCache) return;
  const base = String(urlCarte).split('?')[0];
  const original = win.fetch.bind(win);
  const enrobe = (input, init) => {
    const url = typeof input === 'string' ? input : (input && input.url) || '';
    if (url.split('?')[0] === base) {
      const cache = init && init.cache;
      if (!cache || cache === 'default') return original(input, { ...(init || {}), cache: 'no-store' });
    }
    return original(input, init);
  };
  enrobe.__carteSansCache = true;
  win.fetch = enrobe;
}

/**
 * Ajoute le fond de carte auto-hébergé à une carte Leaflet déjà créée.
 * @param {object} map   instance L.map
 * @param {object} opts  { locale, attribution }
 * @returns {Promise<object>} la couche ajoutée
 */
export async function addBasemap(map, { locale, attribution } = {}) {
  await loadVendorScript('/vendor/leaflet/protomaps-leaflet.js', 'protomapsL');
  lireCarteSansCache();
  // ⚠️ La dist 4.0.1 vendorisée lit `theme` (le README en ligne, plus récent, dit
  // `flavor`). Sans thème reconnu : zéro règle de peinture, tuiles transparentes —
  // vécu en production le 08/09/2026 à 01 h 30, sans la moindre erreur console.
  const layer = window.protomapsL.leafletLayer({
    url: MAPTILES_URL,
    theme: 'light',
    lang: basemapLang(locale),
    maxDataZoom: MAPTILES_MAX_DATA_ZOOM,
    maxZoom: MAPTILES_MAX_ZOOM,
    attribution: attribution === undefined ? '&copy; OpenStreetMap' : attribution,
  });
  layer.addTo(map);
  return layer;
}
