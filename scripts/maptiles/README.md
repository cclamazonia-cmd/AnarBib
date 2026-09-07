# Fond de carte auto-hébergé (PMTiles)

**Depuis le 07/09/2026** (backlog v34, E5), les cartes d'AnarBib ne chargent plus
rien depuis `tile.openstreetmap.org`. Le fond est **un seul fichier** au format
[PMTiles](https://docs.protomaps.com/pmtiles/), extrait du planet que
[Protomaps](https://docs.protomaps.com/basemaps/downloads) reconstruit chaque
jour depuis OpenStreetMap, et servi par notre Storage (bucket public `map-tiles`).
Le navigateur ne lit que les octets des tuiles affichées, par requêtes HTTP
Range — aucun appel vers un domaine tiers (INV-5).

Côté front : `src/lib/mapTiles.js` (adresse, zooms, langue des étiquettes) et
`public/vendor/leaflet/protomaps-leaflet.js` (rendu vectoriel dans Leaflet,
BSD-3, dist 4.0.1, sha256 `8e3d2aa0f5a2fd46871ff9c6ed47fdcdb969bc6ed10bf6719dee507b46a2ec9e`).
Garde CI : `src/tests/carte-sans-domaine-tiers.test.js`.

## Ce que pèse un extrait (mesures du 07/09/2026, planet du jour)

| Zoom maximal | Taille | Ce qu'on voit au dernier niveau |
|---|---|---|
| 10 | 3,7 Go | quartiers, grands axes |
| 11 | 7,9 Go | rues principales |
| **12** | **18 Go** | **rues (choix actuel)** |
| 13 | 36 Go | toutes les rues, noms |
| 14 | 68 Go | bâtiments |
| 15 | 138 Go | planet complet |

Au-delà du zoom contenu, Leaflet **agrandit** les tuiles vectorielles (overzoom
jusqu'au zoom 18) : ce qui existe reste net, rien de plus n'apparaît. Mesurer
avant de télécharger : `pmtiles extract … --dry-run` lit seulement l'index.

## Licence et attribution

Fond « Protomaps Basemap », **ODbL** (produit dérivé d'OpenStreetMap) + Natural
Earth (domaine public). L'attribution `© OpenStreetMap` est portée par la couche
Leaflet et par la clé `federacao.carte.attribution` des dix locales. Rien d'autre
n'est dû à Protomaps (outils BSD-3).

## Fabriquer ou rafraîchir le fichier

Outil : binaire `pmtiles` ([go-pmtiles](https://github.com/protomaps/go-pmtiles/releases),
≈ 17 Mo), posé dans `~/.local/bin`. Le script mesure par défaut et n'agit
que sur demande :

```bash
bash scripts/maptiles/extraire-planet.sh                       # mesure (dry-run)
bash scripts/maptiles/extraire-planet.sh --extraire --televerser
```

Sur ce poste : ≈ 40 à 100 Mo/s depuis Protomaps (4 min pour 18 Go le 07/09),
puis le téléversement. **Le téléversement passe par TUS** (`televerser-tus.mjs`,
morceaux de 6 Mio, reprise automatique, aucune dépendance) : `supabase storage
cp` envoie d'un seul tenant et Cloudflare le refuse au-delà de quelques Go
(413, vécu le 07/09/2026). Il lui faut une clé secrète du projet
(`SUPABASE_SECRET_KEY` dans l'environnement, ou `~/.config/anarbib/secret-key`
en mode 600) — jamais dans le dépôt, jamais dans un transcript :

```bash
SUPABASE_SECRET_KEY=sb_secret_… node scripts/maptiles/televerser-tus.mjs ~/pmtiles/planet-z12-20260907.pmtiles
```

Le nom dans le bucket est **stable** (`planet-z12.pmtiles`) :
le remplacer en place suffit, le front ne change pas. Rythme suggéré : **deux à
quatre fois par an** — un fond de carte vieux de six mois n'a jamais gêné
personne, et chaque extraction coûte 18 Go de transfert.

Pour changer de profondeur (z13…), changer `MAXZOOM`, le nom d'objet dans
`src/lib/mapTiles.js` (`MAPTILES_URL`, `MAPTILES_MAX_DATA_ZOOM`) et le plafond
du bucket (migration `20260907234500`, 20 Gio) ainsi que le plafond global
Storage (API de gestion, `fileSizeLimit`).

## Ce qui entoure le fichier

- **Bucket** `map-tiles` : public, plafond 20 Gio, créé par la migration
  `20260907234500_bucket_map_tiles_fond_de_carte.sql`. Le plafond **global** du
  projet a été monté à 20 Gio le même jour (API de gestion) ; les cinq buckets
  qui n'avaient pas de plafond propre ont reçu explicitement les 500 Mo qu'ils
  avaient de fait.
- **Sauvegarde #BG2** : `map-tiles` est volontairement **hors** du flux storage
  (liste `BUCKETS` de `deploy/ops/anarbib-bg2.sh`) — reconstructible en une
  demi-heure, il triplerait le dépôt restic.
- **Déménagement** (I2, VM Herbes Folles) : copier le fichier là où Caddy le sert
  (`file_server` honore le Range), poser `VITE_MAPTILES_URL` au build. Compter
  le fichier dans le disque demandé (le chiffre de 20 Go donné aux Herbes Folles
  ne l'incluait pas).

## Ce que ce paquet n'est pas

Pas un géocodeur. « Localiser depuis l'adresse » (Nominatim, MAP-F) reste
non configuré : le pin manuel fait foi. L'essai Nominatim de juin 2026 avait
échoué sur l'indexation (15 Go de RAM) — rien à voir avec les fonds de carte,
qui ne demandent aucun calcul.
