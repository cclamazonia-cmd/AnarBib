# Décision — l'OPAC se lit par œuvre (04/09/2026)

**Demande** (Xavier, 04/09/2026) : présenter les résultats de l'OPAC par œuvre, dans la langue d'affichage de la lectrice, avec un « + » vers les éditions (vignette, éditeur, année) et un second « + » vers les exemplaires détenus par bibliothèque avec leur disponibilité. Auteur et titre restent toujours visibles. Motif : la liste plate montrait sept fois « Desobediência civil » sous des éditions différentes, et chaque bibliothèque entrante ajoute les siennes.

## Ce que la mesure a montré avant de décider

Le problème n'était pas d'abord d'affichage. Les huit « Desobediência civil » de Thoreau vivaient sur **six œuvres** : `fn_books_ensure_work` crée une œuvre par notice publiée et rien ne les rapprochait ensuite ; `group_books_as_editions` déplaçait les notices sans supprimer l'œuvre quittée (cinq œuvres vides trouvées).

| Mesure en prod (04/09, avant) | Valeur |
|---|---|
| Notices / œuvres | 2 659 / 2 495 |
| Œuvres à plusieurs éditions | 141 |
| Œuvres détenues par plus d'une bibliothèque | 81 |
| Œuvres avec éditions en plusieurs langues | 4 |
| Groupes d'œuvres probablement scindées (même auteur, même titre normalisé) | 30 groupes, 68 fiches |
| Œuvres sans auteur principal (invisibles à toute heuristique) | 263, dont 218 avec une notice qui en a un |

Déjà en place : un bouton « Regrouper les éditions » (lot C) caché sous « Explorer », inactif par défaut, côté client sur la page chargée ; la page Œuvre `/obra/:id` ; `work_id` dans les deux vues de l'OPAC ; `assign_book_to_work` sans interface.

## Les quatre décisions

1. **Regroupement par œuvre actif par défaut**, bouton pour revenir à la liste plate. Donc regroupement **côté serveur** (une œuvre à cheval sur deux pages apparaissait deux fois), tri et pagination au niveau œuvre.
2. **Titre multilingue = table `work_titles`** (œuvre, langue, titre), pas un JSON : une ligne par langue, unicité, RLS et audit simples, cohérent avec `work_expressions`. Affichage : titre dans la locale → titre d'une édition dans cette langue → titre uniforme.
3. **Les 30 groupes scindés sont arbitrés à la main** sur un export (jamais de fusion par script), puis appliqués par migration (`20260904095317`) : 31 notices déplacées, 35 œuvres vides supprimées, 10 coquilles, 4 langues, 3 notes d'œuvre. Doctrine actée à cette occasion : les tomes forment une **œuvre-série** (Mechoso 38, Hugh Thomas 16) ; un recueil « … e outros escritos » est une **œuvre-recueil** distincte du texte seul (Thoreau 1867 ≠ 97).
4. **Saisie : titre d'origine + pré-traduction automatique « corrige-moi »** dans les dix locales, même doctrine que les Communs ; les titres des éditions existantes remplissent leurs langues sans appel externe. Périmètre : les œuvres à plusieurs éditions (celles dont le titre uniforme s'affiche) ; une œuvre à une seule édition montre le titre de cette édition.

5. **Le titre uniforme s'écrit dans la langue de l'œuvre elle-même** (décision du soir, 04/09/2026), pas dans celle d'une traduction : convention bibliothéconomique, tenable depuis que `work_titles` parle à chaque locale. Il ne s'affiche qu'aux langues sans édition ni titre. Un recueil composé par un éditeur n'a pas d'autre langue que celle de ses éditions (1867 garde son titre portugais). Le catalogage reçoit un champ « Titre uniforme » (`set_work_uniform_title`, migration `20260904163000`) ; l'œuvre 97 de Thoreau devient « Civil Disobedience ». Corollaire de la même soirée : une erreur de pré-traduction se rejoue après un jour, non sept (`20260904160000`).

## Ce que cela pose (lots 1b, 2, 3 — migrations `20260904130000`, `130100`, `130200`)

- **Lot 1b, données** : `work_not_same` (mémoire des « garder séparées »), `fn_work_prune_if_empty` appelée par tous les gestes de rattachement, `merge_works`, `suggest_split_works` (le balayage, servi dans l'assistant de doublons sous un troisième onglet « Œuvres scindées »), `mark_works_not_same`, `search_works_for_link` (« rattacher à une autre œuvre » au catalogage), 218 auteurs principaux rattrapés.
- **Lot 3, titres** : `work_titles` (sources manual > edition > auto), semis par trigger depuis les notices, `set_work_title`, `fn_work_display_title`, Edge Function `work-titles-autofill` (cron toutes les 10 min, secret partagé des crons), éditeur « Titres par langue » au catalogage, page Œuvre dans la locale.
- **Lot 2, OPAC** : `api.catalog_works_v1` (mêmes filtres que la liste plate, recherche par `catalog_search_ids_v1`, une ligne par œuvre avec éditions imbriquées), `api.book_copies_by_library_v1` (doctrine A1/A2/A3 : rien de plus que le nombre d'exemplaires pour l'anon), CatalogPage en mode œuvre par défaut, repli client conservé pour le mode dégradé.

## Reste ouvert

- Les doublons de **notices** (même édition cataloguée deux fois : 1458/2333, 1451/1446, 1359/1353) relèvent de l'assistant de doublons, pas des œuvres.
- L'autorité « Anoar Aiex » sur l'œuvre 178 (texte de Vaneigem/Ratgeb) ; le tome de la notice BTL 375.
- Le titre uniforme de l'œuvre 97 reste en espagnol (« Desobediencia Civil ») alors que deux éditions sur trois sont en portugais : `work_titles` le résout à l'affichage.
