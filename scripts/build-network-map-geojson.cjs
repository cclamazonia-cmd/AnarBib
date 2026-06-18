#!/usr/bin/env node
/* eslint-disable */
// ============================================================================
// build-network-map-geojson.cjs
// Auteur : AnarBib · Session : Carte réseau 10 locales
// ----------------------------------------------------------------------------
// Convertit un export uMap (.umap) — 10 layers, un par locale — en GeoJSON
// minimisé servi par l'edge function `network-map` (bucket PRIVÉ) à l'annuaire
// géographique (src/pages/federacao/NetworkMapTab.jsx).
//
// Contrat de sortie (identique au geojson fr/pt historique, ÉTENDU à 10 locales) :
//   FeatureCollection, geometry Point [lon,lat]
//   properties: { color, category, anarbib, reseau, site, i18n }
//   i18n[locale]: { name, city, country, typeLabel, notes }
//   → JAMAIS email / tel / adresse (verrouillage export : données minimisées).
//
// Jointure inter-layers : par slug « collectif » (identique dans les 10 langues),
// désambiguïsé par proximité de coordonnées pour les rares slugs partagés.
// Champs language-independent (color/category/anarbib/reseau/site) + géométrie :
// pris sur le layer FR (référence).
//
// Usage : node scripts/build-network-map-geojson.cjs <input.umap> <output.geojson>
// ============================================================================
const fs = require('node:fs');

const [, , inFile, outFile] = process.argv;
if (!inFile || !outFile) {
  console.error('Usage: node scripts/build-network-map-geojson.cjs <input.umap> <output.geojson>');
  process.exit(2);
}

// Nom de champ par locale → sémantique. Détection du layer par sa clé « city ».
const FIELD = {
  fr: { name: 'nom',    city: 'ville',  country: 'pays',    type: 'type',  notes: 'notes',     slug: 'collectif'    },
  pt: { name: 'nome',   city: 'cidade', country: 'pais',    type: 'tipo',  notes: 'notas',     slug: 'coletivo'     },
  it: { name: 'nome',   city: 'citta',  country: 'paese',   type: 'tipo',  notes: 'note',      slug: 'collettivo'   },
  es: { name: 'nombre', city: 'ciudad', country: 'pais',    type: 'tipo',  notes: 'notas',     slug: 'colectivo'    },
  ca: { name: 'nom',    city: 'ciutat', country: 'pais',    type: 'tipus', notes: 'notes',     slug: 'collectiu'    },
  de: { name: 'name',   city: 'stadt',  country: 'land',    type: 'typ',   notes: 'notizen',   slug: 'kollektiv'    },
  en: { name: 'name',   city: 'city',   country: 'country', type: 'type',  notes: 'notes',     slug: 'collective'   },
  el: { name: 'onoma',  city: 'poli',   country: 'chora',   type: 'typos', notes: 'simeioseis',slug: 'syllogikotita'},
  nl: { name: 'naam',   city: 'stad',   country: 'land',    type: 'type',  notes: 'notities',  slug: 'collectief'   },
  eo: { name: 'nomo',   city: 'urbo',   country: 'lando',   type: 'tipo',  notes: 'notoj',     slug: 'kolektivo'    },
};
const LOCALES = Object.keys(FIELD);

// Champs language-independent — lus sur le layer FR.
const FR_INDEP = { color: 'couleur', cat: 'categorie', statut: 'statut_anarbib', anarbibLabel: 'anarbib_label', reseau: 'reseau', site: 'site' };

// catégorie uMap → clé front (CATEGORIES de NetworkMapTab.jsx)
const CAT_MAP = {
  biblioteca: 'biblioteca', arquivo: 'arquivo', ateneu: 'ateneu', livraria: 'livraria',
  centro_documentacao: 'centro_doc', espaco_misto: 'misto',
};
// palette canonique (= légende front) : la couleur de sortie en découle.
const PALETTE = { biblioteca: '#C8102E', arquivo: '#5B2C6F', centro_doc: '#1F618D', ateneu: '#B9770E', livraria: '#117A65', misto: '#2C2C2C' };

// Libellé de type par catégorie × locale.
// Le champ `type`/`tipo` du .umap est purement dérivé de la catégorie (aucune
// valeur plus fine), mais bruité en fr (formes machine « centre_doc », accents
// incohérents) et en pt (formes machine « espaco_misto » + fuites FR). On
// normalise donc `typeLabel` à partir de cette table canonique — valeurs tirées
// des 8 locales déjà propres du .umap (it/es/en/de/ca/eo/el), formes fr propres,
// et seul comblement manuel : pt « centro de documentação ». Aucune perte d'info.
const TYPE_LABEL = {
  biblioteca: { fr: 'bibliothèque',            pt: 'biblioteca',             it: 'biblioteca',               es: 'biblioteca',             en: 'library',             de: 'Bibliothek',           ca: 'biblioteca',             eo: 'biblioteko',     nl: 'bibliotheek',         el: 'βιβλιοθήκη' },
  arquivo:    { fr: 'archive',                 pt: 'arquivo',                it: 'archivio',                 es: 'archivo',                en: 'archive',             de: 'Archiv',               ca: 'arxiu',                  eo: 'arkivo',         nl: 'archief',             el: 'αρχείο' },
  centro_doc: { fr: 'centre de documentation', pt: 'centro de documentação', it: 'centro di documentazione', es: 'centro de documentación', en: 'documentation centre', de: 'Dokumentationszentrum', ca: 'centre de documentació', eo: 'dokumentcentro', nl: 'documentatiecentrum',  el: 'κέντρο τεκμηρίωσης' },
  ateneu:     { fr: 'athénée',                 pt: 'ateneu',                 it: 'ateneo',                   es: 'ateneo',                 en: 'athenaeum',           de: 'Athenäum',             ca: 'ateneu',                 eo: 'ateneo',         nl: 'atheneum',            el: 'αθήναιο' },
  livraria:   { fr: 'librairie',               pt: 'livraria',               it: 'libreria',                 es: 'librería',               en: 'bookshop',            de: 'Buchhandlung',         ca: 'llibreria',              eo: 'librovendejo',   nl: 'boekhandel',          el: 'βιβλιοπωλείο' },
  misto:      { fr: 'mixte',                   pt: 'misto',                  it: 'misto',                    es: 'mixto',                  en: 'mixed',               de: 'gemischt',             ca: 'mixt',                   eo: 'miksita',        nl: 'gemengd',             el: 'μικτό' },
};

const s = (v) => (v == null ? '' : String(v).trim());
const coordKey = (f) => f.geometry.coordinates.join(',');
const dist2 = (a, b) => (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2;

const um = JSON.parse(fs.readFileSync(inFile, 'utf8'));
const layers = um.layers || [];

// — détection locale de chaque layer (par présence de la clé « city » locale) —
const byLoc = {};
for (const ly of layers) {
  const feats = ly.features || [];
  const keys = new Set();
  for (const f of feats.slice(0, 8)) for (const k of Object.keys(f.properties || {})) keys.add(k);
  let loc = null;
  for (const [l, m] of Object.entries(FIELD)) if (keys.has(m.city) && keys.has(m.slug)) { loc = l; break; }
  if (!loc) { console.warn('[warn] layer locale non reconnue, clés=', [...keys].slice(0, 8)); continue; }
  if (byLoc[loc]) { console.warn(`[warn] layer ${loc} en double — ignore le second`); continue; }
  byLoc[loc] = feats;
}
const missing = LOCALES.filter((l) => !byLoc[l]);
if (missing.length) { console.error('[ERREUR] locales manquantes dans le .umap :', missing.join(', ')); process.exit(1); }
console.log('Layers détectés :', LOCALES.map((l) => `${l}=${byLoc[l].length}`).join('  '));

// — index par slug pour chaque locale (liste, car slugs parfois partagés) —
const idx = {};
for (const loc of LOCALES) {
  const m = new Map();
  for (const f of byLoc[loc]) {
    const slug = s(f.properties[FIELD[loc].slug]);
    if (!slug) { console.warn(`[warn] ${loc} : feature sans slug, coord=${coordKey(f)}`); continue; }
    if (!m.has(slug)) m.set(slug, []);
    m.get(slug).push(f);
  }
  idx[loc] = m;
}

// — construction : on itère le layer FR (référence) —
const out = [];
const warns = [];
let anarbibCount = 0;
const catTally = {};
const rawTypeSeen = {}; // {cat: {loc: {rawValue: count}}} — pour rapporter ce qui a été normalisé

for (const frf of byLoc.fr) {
  const fp = frf.properties;
  const slug = s(fp[FIELD.fr.slug]);
  const frCoords = frf.geometry.coordinates;

  // catégorie + couleur canonique
  const rawCat = s(fp[FR_INDEP.cat]);
  const category = CAT_MAP[rawCat] || rawCat;
  if (!CAT_MAP[rawCat]) warns.push(`catégorie inconnue "${rawCat}" (slug ${slug})`);
  catTally[category] = (catTally[category] || 0) + 1;
  const color = PALETTE[category] || s(fp[FR_INDEP.color]);
  const umColor = s(fp[FR_INDEP.color]);
  if (PALETTE[category] && umColor && umColor.toUpperCase() !== color.toUpperCase()) {
    warns.push(`couleur uMap ${umColor} ≠ palette ${color} pour ${category} (slug ${slug})`);
  }

  const anarbib = s(fp[FR_INDEP.statut]).toLowerCase() === 'membre' || !!s(fp[FR_INDEP.anarbibLabel]);
  if (anarbib) anarbibCount++;

  // i18n : pour chaque locale, retrouver LA feature correspondante
  const i18n = {};
  for (const loc of LOCALES) {
    const cands = idx[loc].get(slug) || [];
    let f = null;
    if (cands.length === 1) f = cands[0];
    else if (cands.length > 1) {
      // slug partagé → plus proche en coordonnées (FR référence)
      f = cands.reduce((best, c) =>
        (best == null || dist2(c.geometry.coordinates, frCoords) < dist2(best.geometry.coordinates, frCoords)) ? c : best, null);
      warns.push(`slug partagé "${slug}" en ${loc} (${cands.length}) → désambiguïsé par coord`);
    }
    if (!f) { console.error(`[ERREUR] slug "${slug}" introuvable en ${loc}`); process.exit(1); }
    const m = FIELD[loc];
    const p = f.properties;
    const rawType = s(p[m.type]);
    // typeLabel normalisé depuis la table canonique (voir TYPE_LABEL)
    const typeLabel = (TYPE_LABEL[category] && TYPE_LABEL[category][loc]) || rawType;
    // trace de normalisation
    rawTypeSeen[category] = rawTypeSeen[category] || {};
    rawTypeSeen[category][loc] = rawTypeSeen[category][loc] || {};
    rawTypeSeen[category][loc][rawType] = (rawTypeSeen[category][loc][rawType] || 0) + 1;
    i18n[loc] = {
      name: s(p[m.name]),
      city: s(p[m.city]),
      country: s(p[m.country]),
      typeLabel,
      notes: s(p[m.notes]),
    };
  }

  out.push({
    type: 'Feature',
    geometry: { type: 'Point', coordinates: frCoords },
    properties: {
      color,
      category,
      anarbib,
      reseau: s(fp[FR_INDEP.reseau]),
      site: s(fp[FR_INDEP.site]),
      i18n,
    },
  });
}

const fc = { type: 'FeatureCollection', features: out };
fs.writeFileSync(outFile, JSON.stringify(fc));

console.log(`\n✓ ${out.length} features écrites → ${outFile}`);
console.log('  catégories :', JSON.stringify(catTally));
console.log('  membres AnarBib (anarbib=true) :', anarbibCount);
console.log('  taille :', (fs.statSync(outFile).size / 1024).toFixed(0), 'Ko');
if (warns.length) {
  const seen = {};
  for (const w of warns) seen[w] = (seen[w] || 0) + 1;
  console.log('\n  avertissements :');
  for (const [w, n] of Object.entries(seen)) console.log(`   - ${w}${n > 1 ? ` (×${n})` : ''}`);
}

// Rapport de normalisation typeLabel : où la table canonique diffère du .umap brut
const normLines = [];
for (const [cat, byLocRaw] of Object.entries(rawTypeSeen)) {
  for (const [loc, vals] of Object.entries(byLocRaw)) {
    const canon = TYPE_LABEL[cat] && TYPE_LABEL[cat][loc];
    const rawDistinct = Object.keys(vals);
    const diverging = rawDistinct.filter((v) => v !== canon);
    if (canon && diverging.length) {
      const detail = diverging.map((v) => `"${v}"×${vals[v]}`).join(', ');
      normLines.push(`${cat}/${loc}: ${detail} → "${canon}"`);
    }
  }
}
if (normLines.length) {
  console.log('\n  typeLabel normalisés (umap brut → canonique) :');
  for (const l of normLines.sort()) console.log(`   - ${l}`);
}
