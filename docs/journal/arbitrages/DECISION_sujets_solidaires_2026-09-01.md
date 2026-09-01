# Les sujets SOLIDAIRES n'embarquent pas dans les migrations

**1ᵉʳ septembre 2026.** Décision de la coordination, sur la doctrine déjà
tranchée le 26/08 pour le thésaurus FICEDL : **le vocabulaire fédéral embarque
dans les migrations ; les sujets locaux et leurs alignements n'embarquent pas.**

## L'état, mesuré le jour de la décision

- **35 sujets** `solidaires-*` en base, tous en statut `proposto` — rien de
  publié, rien d'activé. Créés le 27/08 lors de l'import du listing de la
  Bibliothèque Solidaires (lot d'essai, run 18).
- **47 alignements** vers le thésaurus FICEDL (sur 98 au total).
- Le brouillon SQL qui les a créés (`20260828_sujets_solidaires_ficedl.sql`)
  traînait dans `docs/drafts/` sans statut — c'était l'objet de l'item **C1**.

## Pourquoi ils sont locaux, et pas fédéraux

Le brouillon le dit lui-même : « *les libellés sont ceux du collectif, non
retraduits* », « *nous n'inventons pas de traductions* ». Ce sont les rubriques
d'un listing tel qu'un collectif l'a écrit — en français seul, dans ses mots,
avec ses regroupements (« Répression - Justice - Prison »). Les traduire ou les
normaliser pour les faire embarquer trahirait précisément ce qu'ils sont : un
vocabulaire *situé*. Le thésaurus FICEDL est la couche fédérale ; les 47
alignements font le pont, et c'est leur travail.

Une installation neuve d'AnarBib n'a aucune raison de naître avec les rubriques
de la Bibliothèque Solidaires — pas plus qu'avec les sujets locaux de la BLMF.
Elle naît avec le thésaurus, et chaque bibliothèque apporte ses mots.

## Ce que la décision fait

1. Le brouillon est **rangé en archive** (`docs/drafts/archive/`), daté, avec
   cette note pour statut : il a servi, il a été appliqué à la main le 27/08,
   il ne deviendra pas une migration.
2. Les 35 sujets et leurs alignements vivent **en production seulement**, comme
   toutes les données locales — couverts par la sauvegarde (BG2), pas par le
   rejouable.
3. La CI ne les connaîtra jamais : une suite qui en aurait besoin devra les
   créer en fixture, comme pour toute donnée vivante
   (`anarbib-migrations-avant-seed`).

## La limite, dite

Si un jour la fédération décide de faire des rubriques SOLIDAIRES un
vocabulaire *commun* — parce que d'autres bibliothèques les adoptent telles
quelles — cette décision se révise : c'est le critère « fédéral », pas le
préfixe, qui commande. Ce jour-là, la migration se réécrira depuis la base,
pas depuis ce brouillon.
