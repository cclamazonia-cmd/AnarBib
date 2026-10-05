<!--
  Copyright (c) 2026 Xavier VAN WELDEN and AnarBib contributors.
  This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
  International License (CC-BY-SA-4.0). See the LICENSE-docs file at the root
  of this repository.
-->

# Le lecteur EPUB — conserver ou remplacer ? (D6, 05/10/2026)

## Verdict

**Conserver epub.js, épinglé à `0.3.93`, avec `@xmldom/xmldom` forcé sur la ligne 0.8 corrigée ; foliate-js est le remplaçant désigné.**

Rien ne casse aujourd'hui, et rien ne presse. Le jour où un navigateur casse epub.js, ou dès qu'on touche au lecteur pour une autre raison, on passe à foliate-js plutôt que de réparer epub.js.

## Ce qui a été mesuré

### epub.js (`epubjs`, `src/lib/reader/epubEngine.js`, `src/components/viewers/EpubReader.jsx`)

- **npm** : `0.3.93`, publiée le 26/09/2023. Aucune version depuis. Une `0.5.0-alpha.3` existe sous l'étiquette `alpha`.
- **Dépôt** (`futurepress/epub.js`) : dernière fusion le 24/03/2026. 517 tickets ouverts, non archivé.

Le projet n'est pas mort, mais il ne publie plus.

**Dépendance fragile.** `@xmldom/xmldom` était bloquée en `^0.7.5` (résolue en 0.7.13), avec des failles « high » d'injection XML et de récursion, corrigées en 0.8.12–0.8.13.

Lu dans les sources d'epub.js (`src/utils/core.js` `parse()`, `src/section.js`) : xmldom n'est employée qu'en l'absence du `DOMParser` ou du `XMLSerializer` natifs, c'est-à-dire sous Node ou sous Internet Explorer. **Dans un navigateur, ce code n'est jamais appelé** : les failles étaient hors d'atteinte de l'application, mais présentes dans le bundle et dans l'audit npm.

L'emploi d'epub.js par AnarBib (`epubEngine.js`, 734 lignes) touche :
- le chargement d'archive (`book.load`, `book.archive.request`) ;
- les rendus et leurs crochets (`rendition.hooks.content`) ;
- les thèmes ;
- les positions CFI (`currentLocation`).

C'est l'essentiel de l'API publique d'epub.js. Le moteur est aussi partagé avec le site CCLA (`window.ePub`) : le constructeur est injecté.

### Les alternatives libres

- **foliate-js** (`johnfactotum/foliate-js`)
  - Licence MIT ; dernier commit le 01/05/2026 ; npm `1.0.1` (21/04/2025).
  - Pur JavaScript en modules ES, **sans dépendance**, sans chargement du fichier entier.
  - Lit EPUB, MOBI, KF8, FB2 et CBZ, et gère les CFI.
  - C'est le moteur de l'application de bureau Foliate, éprouvé sur WebKitGTK ; il fonctionne aussi sous Chromium et Firefox.
  - Son lecteur de haut niveau correspond à celui d'epub.js : migration d'un moteur à l'autre plutôt que réécriture.
- **Readium ts-toolkit** (`@readium/navigator`)
  - Licence BSD-3 ; `2.11.1` le 30/09/2026 ; portée par la Readium Foundation, très active.
  - C'est le choix le plus solide sur les standards et l'accessibilité.
  - Mais elle est plus lourde : elle est pensée autour du manifeste de publication Readium et de son outillage. C'est un changement d'architecture, pas un remplacement de moteur.

## Ce qui a été fait

- `package.json` : `"epubjs": "0.3.93"`, sans `^` : la version est désormais un choix.
- `"overrides": { "epubjs": { "@xmldom/xmldom": "^0.8.13" } }` : xmldom est résolue en **0.8.15**, et l'audit npm ne signale plus ni xmldom ni epubjs (22 → 20 avis au total ; les autres ne concernent pas le lecteur).
  - Sans effet dans le navigateur, qui emploie ses parseurs natifs.
  - Le build de production passe.
- `src/tests/lecteur-epub-ouvre-un-epub.test.js` (critère 2 de D6) :
  - construit un EPUB 3 complet : `mimetype` non compressé en tête, container, OPF, nav, deux chapitres XHTML ;
  - l'ouvre avec l'epub.js embarqué ;
  - vérifie les métadonnées, l'ordre de lecture, la table des matières et le texte d'un chapitre ;
  - vérifie aussi l'épinglage et la version de xmldom.

## Quand basculer, et comment

Signes qu'il faut basculer :
- un navigateur pris en charge n'ouvre plus un EPUB ;
- une faille atteignable dans le navigateur ;
- un besoin que le moteur ne sait pas servir (MOBI, FB2, accessibilité).

Chemin : remplacer `createEpubEngine({ ePub })` par un moteur foliate-js à la même interface (`open`, `onRelocate`, thèmes, CFI). `EpubReader.jsx` et la persistance de position restent. Le test ci-dessus sert de recette, et s'élargit au rendu.
