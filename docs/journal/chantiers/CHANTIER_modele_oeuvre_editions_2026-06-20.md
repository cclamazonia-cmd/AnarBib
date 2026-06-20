# CHANTIER — Modèle Œuvre / Éditions (FRBR-léger) & dédoublonnage de fond

> **Date** : 2026-06-20
> **Session** : Doublons d'autorité & i18n erreurs catalogue
> **Branche** : `feat/catalog-audit-fixes`
> **Statut** : ✅ **Livré** (déployé en prod, projet `uflwmikiyjfnikiphtcp`).
> **Cadrages amont** : [`../cadrages/CADRAGE_fusion_autorites_2026-06-19.md`](../cadrages/CADRAGE_fusion_autorites_2026-06-19.md) ·
> [`../cadrages/CADRAGE_modele_oeuvre_editions_2026-06-20.md`](../cadrages/CADRAGE_modele_oeuvre_editions_2026-06-20.md) ·
> [`../cadrages/CADRAGE_oeuvre_v2_2026-06-20.md`](../cadrages/CADRAGE_oeuvre_v2_2026-06-20.md) ·
> [`../cadrages/CADRAGE_oeuvre_v2_lotC_catalogue_2026-06-20.md`](../cadrages/CADRAGE_oeuvre_v2_lotC_catalogue_2026-06-20.md)
> **Audit fondateur** : [`../audits/AUDIT_catalogacao_tables_vues_2026-06-20.md`](../audits/AUDIT_catalogacao_tables_vues_2026-06-20.md)

---

## 1. Le problème de fond

Le catalogue d'AnarBib était jusqu'ici une **liste plate de documents indépendants**. Chaque
édition d'un même texte (ex. González Prada, *La Anarquía*, 1940 / 2010 / 2020 ; Kropotkine,
*L'Entraide* en plusieurs langues) existait comme une **fiche isolée**, sans aucun lien avec ses
sœurs. Conséquences observées et signalées par la coordination :

- **Doublonnage passif et indirect des œuvres** : la même œuvre se démultipliait en fiches sans
  parenté, sans que rien dans le modèle ne le sache. Impossible de répondre à « quelles éditions
  de ce classique avons-nous ? » autrement qu'à l'œil.
- **Outils de dédoublonnage aveugles à l'édition** : `suggest_book_duplicates` /
  `suggest_draft_duplicates` comparaient *titre + auteur normalisés sans l'édition* → deux éditions
  **distinctes** d'un classique étaient signalées comme **doublons**, et la fiche en cours d'édition
  pouvait s'auto-signaler comme doublon d'elle-même.
- **Confusions de couverture** perçues à l'édition (état transitoire de l'éditeur), alimentant le
  soupçon d'une « bave » entre éditions — alors que l'OPAC lit la couverture **par notice**.
- **Autorités dédoublées** en amont (Fábio LUZ / Fábio Luz, etc.) bloquant la mise au rebut, sur fond
  de **désynchronisation `book_authors` ↔ `book_contributors`** (imports legacy).

Le souci n'était donc pas cosmétique : il manquait au catalogue **la notion même d'œuvre**.

## 2. La solution — un modèle bibliographique FRBR-léger

On a introduit la hiérarchie **FRBR allégée**, adaptée aux moyens et aux besoins réels du réseau :

```
Œuvre (works)            ← le texte intellectuel (« La Anarquía » de González Prada)
  └─ Expression          ← une version, ici par LANGUE (es, fr, …) — work_expressions
       └─ Manifestation  ← une édition publiée = une notice (books)
            └─ Exemplaire ← une copie physique en rayon (exemplares)
```

- L'**Œuvre** regroupe ses éditions ; l'**Expression** distingue les versions linguistiques ;
  la **Manifestation** reste la notice telle qu'on la cataloguait déjà ; l'**Exemplaire** était
  déjà modélisé.
- Choix de cadrage assumé avec Xavier : **on construit l'entité même quand les occurrences sont
  peu nombreuses** (5 œuvres multilingues aujourd'hui) — *« si on sait faire, on le fait
  maintenant, pas dans l'urgence demain »*. La couche Expression et le traducteur·rice par
  expression ont été posés à ce titre.

## 3. Ce qui a été construit (par couche)

### Préalables — autorités & cohérence des liens
- **Surfaçage de `merge_author`** : la fusion d'autorités existait (gère 6 FK + `merge_log`) mais
  était inaccessible → bouton **« Fusionner… »** dans `CatalogPanel`. (Voir cadrage fusion.)
- **Réconciliation `book_authors` ↔ `book_contributors`** — migration `20260619210445` (1243 liens
  réalignés ; ~271 fantômes à nom divergent laissés en revue manuelle).
- **Hints d'erreur catalogue localisés** — migration `20260619160150` : les hints `catalog_discard_*`
  re-préfixés `error.catalog.discard.*` pour que `localizeError` les traduise (fin du message brut
  pt-BR sur UI FR).

### Dédoublonnage conscient de l'édition — migration `20260620083749`
- `suggest_*` **excluent les éditions à ISBN distincts** (ISBN identique = doublon certain).
- Table **`public.book_not_duplicate`** (paires ordonnées, RLS staff) + RPC
  `mark_books_not_duplicate(a,b)` + bouton **« Pas un doublon »** (BookDraftForm, DuplicateCompareModal).
- Bouton **« Retirer la couverture »** (efface champ + objet Storage) + reset de l'état couverture
  au changement de fiche.

### Modèle Œuvre — v1
- **Lot 1** `20260620090724` : table **`works`** (RLS staff / lecture OPAC) + `books.work_id` ;
  backfill **153 œuvres / 344 notices** (groupes ≥ 2 éditions, titre normalisé + auteur principal,
  `uniform_title` = plus ancienne) ; `merge_author` repointe `works.primary_author_id` (7ᵉ FK) ;
  `suggest_*` excluent désormais les notices de même `work_id`.
- **Lot 2** `20260620091752` : RPC non destructives staff `create_work_from_book`,
  `assign_book_to_work`, `detach_book_from_work`, `group_books_as_editions`.
- **Lot 4** `20260620100926` : RPC `api.book_other_editions` (public-safe) + section
  **« Autres éditions de cette œuvre »** sur `BookPage`.
- **Front (v1)** : bloc « Œuvre » + boutons **« Même œuvre »** / **« Pas un doublon »** dans
  `BookDraftForm` et `DuplicateCompareModal`, **gatés palier ≥ Avancé** (`catalogTier>=2`).

### Modèle Œuvre — v2
- **Lot A** `20260620102802` : RPC `api.work_public_detail` + page publique **`WorkPage`** (route
  `/obra/:id`) + lien « Voir l'œuvre » depuis `BookPage`.
- **Lot B** `20260620103632` : RPC `suggest_editions_for_book` (titre proche même auteur, seuil 0,35)
  + bouton **« Suggérer des éditions »** dans le bloc Œuvre.
- **Lot C backend** `20260620105747` : `work_id` exposé sur `catalog_list_anon_v1` / `_session_v1`
  via `private.fn_book_work_id` (append aux vues, **`security_invoker` préservé, sans rebuild MV**).
- **Lot C front** : bascule **« Regrouper les éditions »** (OFF par défaut) dans `CatalogPage` —
  repli **côté client** des notices chargées par `work_id` (ligne représentante + badge → `/obra/:id`),
  **filtres / pagination / requête inchangés** (zéro risque OPAC). La page Œuvre reste la **référence
  du jeu complet** d'éditions.

### Couche Expression (langue) — v3
- **Expression** `20260620113134` : table **`work_expressions`** (`work_id` + `lang`) +
  `books.expression_id`, **dérivé de `(work_id, idioma)`** par le trigger `fn_sync_book_expression`
  → les RPC de regroupement le maintiennent **automatiquement** ; backfill **198 expressions /
  345 notices**. `work_public_detail` renvoie les éditions **groupées par expression** ; `WorkPage`
  affiche un **en-tête de langue** quand l'œuvre est multilingue.
- **Traducteur·rice par expression** `20260620114434` : `work_public_detail` **agrège** les
  traducteur·rices (`book_contributors` rôle `tradutor` liés à une autorité) **par expression** ;
  `WorkPage` affiche **« Traduit par X »** (lien autorité) par groupe de langue. **Dérivé, pas de
  colonne** sur `work_expressions` → aucune duplication ; vide aujourd'hui (0 traducteur lié),
  s'allume au premier rattachement.

### Guide de catalogage
- Nouvelle étape **« Œuvres & doublons »** du `CatalogacaoWizard` (après « documento », onglet
  `booksPanel`) : explique concrètement Fusionner / Pas un doublon / Même œuvre / Suggérer des
  éditions / Retirer la couverture, **palier Avancé + Complet signalé** (titre, corps, astuce).

## 4. Comment ça s'utilise

- **Cataloguer** (palier **Avancé** ou **Complet**) : sous une fiche, repérer les doublons et
  **fusionner** ; **écarter** une fausse alerte (« Pas un doublon ») ; **regrouper** des éditions
  (« Même œuvre » / « Suggérer des éditions ») ; **retirer** une couverture erronée. En **Simple**,
  la fiche reste épurée (ces outils sont masqués).
- **OPAC / lecture publique** : page **`/obra/:id`** = vue de référence de l'œuvre, éditions
  **groupées par langue** (et « Traduit par … » dès qu'un·e traducteur·rice est lié·e) ; depuis une
  notice, « Autres éditions » + « Voir l'œuvre ». Sur le catalogue, bascule **« Regrouper les
  éditions »** (optionnelle, OFF par défaut).

## 5. Décisions de conception (et pourquoi)

1. **Dériver plutôt que dupliquer.** Le traducteur·rice par expression est **agrégé** des liens
   contributeur↔autorité existants, sans colonne `translator_id` fantôme : une seule source de
   vérité, pas de dérive à synchroniser.
2. **Expression maintenue par trigger.** `expression_id` est dérivé de `(work_id, idioma)` → les RPC
   de regroupement n'ont **rien à câbler** ; impossible d'oublier de mettre à jour l'expression.
3. **Repli catalogue côté client d'abord.** Le regroupement au catalogue est un repli **client**
   (sur les notices déjà chargées) : il **ne touche ni la requête ni la pagination ni les filtres**
   → **zéro risque** pour le cœur OPAC. Le repli **serveur strict** (RPC collapsé filtre-aware) est
   gardé en réserve, à n'activer que s'il devient nécessaire à l'usage.
4. **Construire l'entité même sur peu d'occurrences** (décision Xavier) : la couche Expression est
   posée maintenant pour ne pas la refaire dans l'urgence quand le fonds multilingue grossira
   (ex. afflux FICEDL).
5. **Outils avancés gatés par palier** (`catalogTier>=2`) : la complexité bibliographique n'alourdit
   pas le parcours des camarades en mode Simple.
6. **Couvertures par notice** : l'OPAC lit `books.cover_object_path` **par notice** — aucune bave
   entre éditions côté catalogue (la « bave » vue à l'éditeur = état transitoire de lookup).

## 6. Garde-fous / invariants respectés

- **Surface publique** : tout ce qui sert l'OPAC passe par `catalog_list_anon_v1` (public-safe) ;
  jamais de lecture directe de `books` pour une liste catalogue (fuite réseau `visibility_level`).
- **Sécurité objets** : `work_expressions` en **RLS** (lecture OPAC, écriture staff) ; vues
  catalogue **`security_invoker` préservé** ; `work_id` ajouté **sans rebuild de MV**.
- **i18n** : chaque chaîne nouvelle traduite dans les **10 locales** (parité gardée par la CI,
  29 tests verts), charte respectée (zéro « camerata »).
- **Migrations** : horodatage UTC exact, série strictement croissante ; chaque migration validée en
  `begin … rollback` sur la prod (compilation + comportement) avant commit.

## 7. Ce qui reste ouvert (volontairement)

- **Repli catalogue serveur strict** (Opt A : RPC collapsé filtre-aware avec pagination/compteurs
  sur les œuvres) — **uniquement si** le repli client montre ses limites à l'usage.
- **Enrichissements futurs** de la couche Expression : titre uniforme comme autorité, traducteur·rice
  comme responsabilité d'expression à part entière (l'affichage est déjà prêt).
- **Revue manuelle** déléguée : ~271 liens fantômes à nom divergent ; quelques grappes d'autorités
  et de notices à trancher pièce par pièce (Baqueiro / coordination).

## 8. Portée à long terme

AnarBib passe d'un **catalogue plat** (documents isolés, doublonnage passif des œuvres) à un **vrai
modèle bibliographique** : les œuvres existent comme entités, leurs éditions et leurs langues sont
reliées et lisibles, le dédoublonnage distingue enfin **doublon** et **édition**, et les outils sont
là pour entretenir cette qualité dans la durée. C'est le socle sur lequel pourront s'appuyer
l'ingestion FICEDL, l'export SKOS/bibliographique et la fédération inter-bibliothèques.

---

### Annexe — migrations & front

**Migrations** (`supabase/migrations/`, prod) :
`20260619160150` hints i18n · `20260619210445` réconciliation liens ·
`20260620083749` dédoublonnage édition-aware + `book_not_duplicate` ·
`20260620090724` works lot 1 · `20260620091752` works lot 2 (RPC) ·
`20260620100926` `book_other_editions` · `20260620102802` `work_public_detail` ·
`20260620103632` `suggest_editions_for_book` · `20260620105747` `work_id` aux vues ·
`20260620113134` Expression (`work_expressions`) · `20260620114434` traducteur·rice par expression.

**Front** : `CatalogPanel.jsx` (Fusionner) · `BookDraftForm.jsx` & `DuplicateCompareModal.jsx`
(Même œuvre / Pas un doublon / Suggérer / Retirer couverture) · `CatalogPage.jsx` (Regrouper les
éditions) · `WorkPage.jsx` *(nouveau)* + route `/obra/:id` dans `App.jsx` · `BookPage.jsx` (Autres
éditions / Voir l'œuvre) · `CatalogacaoWizard.jsx` (étape Œuvres & doublons).
