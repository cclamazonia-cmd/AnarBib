# Prompt de reprise — chantier « locale ro », après le lot 3 (14/10/2026)

Document de référence : « AnarBib — passer de 10 à 11 locales : inventaire et
plan pour le roumain » (https://claude.ai/code/artifact/50a03cff-ad18-4211-8581-e94207565e73).
Backlog : `E39`. Doctrine : `DOC-I18N-4` (sources), `DOC-I18N-5` (décisions D1
à D7). Reprise précédente : `PROMPT_reprise_locale_ro_lot1_2026-10-13.md`.
Notes pour la relecture : `RELECTURE_roumain_2026-10-14.md` (même dossier).

## Où on en est

Le roumain est **servi et hors des sélecteurs** (D5) depuis le commit
`49b479ae` (migration `20261014192932_le_roumain_onzieme_locale`) :

- `ro` est la onzième entrée des sources, avec `listed: false`, dans
  `src/i18n/locales.js` et `_shared/i18n/locales.ts` ; `fn_supported_locales()`
  rend onze codes.
- On l'atteint par `?lang=ro`, par la préférence d'un profil ou par le
  `localStorage`. La langue du navigateur ne choisit qu'une langue offerte
  (`LISTED_CODES`).
- Les sélecteurs passent par `localesDuSelecteur(...courantes)` : ils offrent
  les langues `listed`, plus celle qu'on a déjà. Ces sélecteurs sont
  LocaleSwitcher, LocaleSelector, ReadLanguagesField, InvitationsPanel et la
  gazette.
- Ce qui est traduit :
  - `ro.json` (7 631 clés) ;
  - les 709 gabarits de `mail-strings.ts` et les arbres des autres fonctions ;
  - `install.sh` (85 messages, « d » accepté comme oui) ;
  - la page « Viața rețelei » de la gazette ;
  - la casse de phrase et les mots-outils, côté base et dans `titleCase.js` ;
  - `ro/ron/rum → ro` dans `fn_locale_from_idioma` ;
  - le titre de la tâche « lot de fonds reçu ».
- Ce qui retombe sur une autre langue :
  - les recueils PDF (`null` → pt-BR, D7) ;
  - les sous-titres des tutoriels ;
  - le guide d'accueil des coordinations (`/en/welcome/`, jusqu'au lot 5).

Rien n'est encore relu par une personne roumanophone. Xavier sollicitera
lui-même Adrian (Anarhiva, Cluj-Napoca), en français : ne pas lui écrire.

## Données en base : faites (cc34a4c9, migration `20261014202251`)

Carte (187 fiches), sujets (39), tâches suggérées et récurrentes (21) ont leur
`ro`. Le thésaurus FICEDL a ses 461 descripteurs en **proposition**, dans
`ficedl_thesaurus_terms.labels_proposes`, jamais dans `labels` (`THES-FIC6`) ;
l'export pour la FICEDL (CSV et JSON, `mot_id`, URI, facette, fr, en, ro) est
à envoyer par Xavier à Claude Hortical. Une fiche de carte créée ou retouchée
après le 14/10 n'a pas de roumain tant que personne ne l'écrit (la fiche
s'édite dans la langue d'affichage).

## Lots suivants

- **Lot 4, documentation du dépôt : FAIT** (`cf64ee88`, 14/10). Restent, côté
  français : les « dix langues » écrites DANS les documents des Communs (D6),
  et les boutons cités qui n'existent plus (voir la fin de
  `RELECTURE_roumain_2026-10-14.md`).
- **Lot 5, vitrine : FAIT** (15/10 ; anarbib/pages `997070f` puis `3809dce`, app
  `5dccf68f`). Ouvrir le roumain sur la vitrine (lot 7) : retirer `"listed": false`
  de `tools/locales.json`, `node tools/pose-selecteur.cjs`, relancer les quatre
  générateurs (guide, confidentialité, comptes, auto-hébergement), et ajouter `ro`
  à la détection de la langue du navigateur dans `index.html`. Défaut connu : les
  pages engendrées de l'auto-hébergement n'ont pas d'`og:locale` (toutes langues).
- **Lot 6 : FAIT** (15/10, `a67b3405`). Recueils publiés avec le roumain en fin ;
  outils et sources sur E: (`Manual AnarBib v5/_outils/lot6-ro/`, un bloc de
  langue se refait avec `ajouter_section_ro.py` + export Word + composition
  sur les pages publiées). Reste à Xavier : déposer `tuto1-ro.vtt` et
  `tuto2-ro.vtt` sur Kolektiva, puis `SUBTITLE_LANG.ro = 'ro'` dans
  `ReaderTutorialsCard.jsx`. À l'ouverture : couvertures des deux manuels
  (11 langues), et les six captures avec session en roumain.
- **Lot 7** : le roumain est **OUVERT** depuis le 15/10/2026 (`11c90c62`,
  vitrine `b2e4aa5`, D5 amendée). Restent, dans l'ordre :
  - couvertures à onze langues des deux manuels (demande dans
    `E:\CCLA\BLMF\AnarBib\Manuels - Guides\Manual AnarBib\Couvertures 11 langues\`),
    puis remplacement de la page 1 des PDF publiés (dépôt sans trou :
    `_neuf_` puis bascule) ;
  - ~~six captures avec session~~ FAIT le 15/10 (images remplacées dans les PDF
    publiés : `_outils/lot6-ro/captures_ro_pdf.py` ; données de démo posées puis
    retirées, liste dans `_outils/lot6-ro/donnees-captures-ro.txt`) ;
  - **en dernier** : relecture d'Adrian (Anarhiva), corrections, annonce
    (Gazette, Lettre, État du projet), clôture d'E39 au REGISTRE.

## Pièges vus pendant le lot 3

- Le seuil des homographes de `DOC-I18N-3` (valeur identique à pt-BR dans
  ≥ 7 locales) bouge avec chaque langue. Une valeur laissée telle quelle en
  roumain peut faire tomber le vocabulaire légitime des autres langues : il
  faut la traduire (c'est ce qui a été fait pour « Dewey: » et
  « ID secundar »).
- Les entrées de `mail-strings.ts` écrites sur une ligne doivent y rester :
  `mail-invitation-i18n` les lit ligne à ligne.
- Les tests de scripts antérieurs au roumain (h21, h30) portent sur
  `LANGUES_DU_SCRIPT` (= `LOCALE_CODES` sans `ro`) : y ajouter `ro` quand le
  script sera traduit.
