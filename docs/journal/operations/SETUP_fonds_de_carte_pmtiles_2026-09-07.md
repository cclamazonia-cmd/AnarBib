# Fond de carte auto-hébergé — PMTiles (E5, MAP-M)

**Date :** 2026-09-07, soirée et nuit
**Statut :** ✅ livré, en production le soir même
**Réfs :** backlog v34 **E5** (clos) · REGISTRE §34 **MAP-M** · INV-5 · `scripts/maptiles/README.md` · `src/lib/mapTiles.js` · migration `20260907234500` · `src/tests/carte-sans-domaine-tiers.test.js`
**Voisin :** `SETUP_nominatim_geocoding_2026-06-18.md` (l'autre moitié de MAP-F, toujours non configurée)

## 0. Ce qu'on croyait, ce qui était

Xavier se souvenait d'un essai de juin 2026 « pour récupérer les fonds de carte
OpenStreetMap », qui avait « somptueusement merdoyé : trop long ». Le journal dit
autre chose : l'abandon du 19/06 concernait **Nominatim**, le géocodeur
(adresse → coordonnées), dont l'indexation ne finissait pas sur les 15 Go du WSL.
**Les fonds de carte n'avaient jamais été tentés** — aucun transcript de juin ne
parle de serveur de tuiles. Le sujet dormait au backlog en E5, avec une piste
(« relayer les tuiles par le serveur ») qui était la mauvaise : la
[politique des tuiles OSM](https://operations.osmfoundation.org/policies/tiles/)
déconseille les proxys cache et interdit tout préchargement, et un relais
aurait gardé la dépendance.

## 1. Ce qui a été fait

**Un fichier, pas un serveur.** Le fond est un fichier
[PMTiles](https://docs.protomaps.com/pmtiles/) extrait du planet que Protomaps
reconstruit chaque jour depuis OpenStreetMap (ODbL, attribution OSM conservée).
`pmtiles extract` ne lit que les octets utiles du planet : pas d'import, pas
d'indexation, pas de RAM — rien de ce qui avait tué Nominatim.

| Mesure à vide (`--dry-run`, planet du 07/09) | Taille |
|---|---|
| z0-10 | 3,7 Go |
| z0-11 | 7,9 Go |
| **z0-12 (retenu)** | **18 Go** |
| z0-13 | 36 Go |
| z0-14 | 68 Go |
| z0-15 (planet entier) | 138 Go |

Xavier visait z15 « idéalement », z12 « pour commencer si ça ne fait pas trop
énorme ». z12 = les rues ; au-delà, Leaflet agrandit les tuiles vectorielles
jusqu'au zoom 18 sans rien charger de plus.

**Hébergement.** Bucket public `map-tiles` du Storage Supabase (plan Pro).
Vérifié avant de choisir : le Storage public honore le Range (206) avec CORS
`*` ; Codeberg Pages l'honore aussi mais ses quotas (100 Mio) excluent un
fichier de plusieurs Go. Le plafond global de taille de fichier (500 Mo) a été
monté à 20 Gio par l'API de gestion, **après** avoir figé à 500 Mo les cinq
buckets qui n'avaient pas de plafond propre (ils héritaient du global). Le
bucket est créé en base et par la migration `20260907234500` (inerte en
production, reconstructible ailleurs), le stub CI le connaît.

**Front.** `protomaps-leaflet` 4.0.1 vendorisé à côté de Leaflet (BSD-3,
100 Ko, sha256 `8e3d2aa0…ec9e`) dessine les tuiles vectorielles en canvas avec
des polices web — pas de serveur de glyphes, pas de MapLibre. Le module
`src/lib/mapTiles.js` porte l'adresse (défaut : le bucket du projet,
surcharge `VITE_MAPTILES_URL`), les zooms et la langue des étiquettes (`ca` et
`eo` absents du fond → noms locaux, jamais de repli vers une autre langue).
Les trois cartes n'ont plus une ligne `L.tileLayer`. Garde CI :
`carte-sans-domaine-tiers.test.js`.

**Dix locales.** `privacy.s6.maptiles` ne dit plus « nous y travaillons » mais
ce qui est ; `federacao.carte.attribution` dit « hébergé par AnarBib ».

**Sauvegarde.** `map-tiles` est volontairement hors du flux storage de BG2
(commentaire dans les deux copies du script) : 18 Go reconstructibles en une
demi-heure tripleraient le dépôt restic.

## 2. Ce que ce paquet ne fait pas

- **Il ne sort pas du périmètre Cloud Act.** Le fichier est chez Supabase comme
  le reste de l'application. La fuite d'adresses IP vers un tiers est close ;
  la souveraineté vient avec **I2** : copier le fichier là où Caddy le sert
  (`file_server` honore le Range), poser `VITE_MAPTILES_URL`, et **compter ces
  18 Go dans le disque demandé aux Herbes Folles** (le chiffre de 20 Go donné
  le 20/08 ne les incluait pas — **I21**).
- **Il ne géocode pas.** « Localiser depuis l'adresse » reste non configuré.

## 3. Incident de méthode

La mesure à vide de z15 (177 millions d'entrées de tuiles en mémoire) lancée
en même temps que l'extraction z12 et un `npm ci` a **figé WSL à son plafond de
15 Go** pendant dix minutes, sans que le tueur de mémoire du noyau ne le
libère. `wsl --shutdown` avec l'accord de Xavier, après avoir vérifié qu'aucune
autre session Claude n'était active et que le seul client WSL hors Docker
Desktop était le mien. Rien de perdu (fichiers du worktree sur disque,
extraction et `npm ci` relancés). Leçon : **une mesure à vide du planet entier
se lance seule**, ou pas du tout — la doubler d'un téléchargement et d'une
installation npm, c'est trois fois trop sur 15 Go.

Second piège, connu et repayé : un `npm ci` lancé dans une ligne
`wsl.exe … bash -c "…"` a rendu `rc=0` sans rien installer (mangling des
variables par Git Bash). Toujours un script fichier, ou une ligne sans variable.

## 4. Rafraîchir

`bash scripts/maptiles/extraire-planet.sh` mesure ; `--extraire --televerser`
fait. Deux à quatre fois par an suffisent. Voir le README pour changer de
profondeur (z13 = 36 Go : plafond du bucket, plafond global, `MAPTILES_URL`,
`MAPTILES_MAX_DATA_ZOOM`).
