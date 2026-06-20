# CADRAGE — Modèle Œuvre v2 (page Œuvre, auto-regroupement, facette)

> **Date** : 2026-06-20 · **Statut** : cadrage (à valider, puis coder en lots).
> **Prérequis** : v1 livré (table `works`, `books.work_id`, RPC works, dédoublonnage par work,
> OPAC « autres éditions »). Cf. `CADRAGE_modele_oeuvre_editions_2026-06-20.md`.
> **Session** : Doublons d'autorité & i18n erreurs catalogue.

## 0. Priorisation par la donnée (prod 20/06)

- 153 œuvres, 344 notices rattachées. **Seulement 5 œuvres multilingues** ; 49 notices rattachées
  sans langue renseignée.
- ⇒ **La couche FRBR Expression (table dédiée par langue) est faible valeur** : on la **diffère**.
  En v2 on se contente d'**afficher la langue** comme sous-groupe/étiquette sur la page Œuvre.
- Les deux pièces à forte valeur : **(A) page Œuvre publique** (payoff utilisateur du modèle) et
  **(B) auto-regroupement** (outil staff pour finir de relier les éditions, ex. « La Anarquía »
  2010 que le backfill n'a pas captée car titre normalisé différent).

## 1. Lots proposés

### Lot v2-A — Page Œuvre OPAC  *(forte valeur, public)*
- RPC `api.work_public_detail(p_work_id)` : renvoie l'œuvre (titre uniforme, auteur·rice +
  `author_id`) **+ ses éditions publiques** (calque `book_other_editions` : via
  `catalog_list_anon_v1`, public-safe), triées par année, avec la **langue** par édition.
- `WorkPage` + route **`/obra/:id`** (cohérent avec `/livro/:id`, `/autor/:id`, lazy dans `App.jsx`).
  Rendu : titre uniforme, lien auteur·rice (`/autor/:id`), liste d'éditions (cartes → `/livro/:id`),
  regroupées par langue si multilingue (les 5 cas).
- **Lien depuis `BookPage`** : le « Œuvre : {titre} » devient cliquable → `/obra/:id`.
- i18n ×10. Public-only par design (comme `book_other_editions`).

### Lot v2-B — Auto-regroupement d'éditions  *(forte valeur, staff)*
- RPC `suggest_editions_for_book(p_book_id)` (staff) : autres notices du **même auteur·rice
  principal·e** dont le titre est **proche** (`similarity` trigramme, seuil bas) et qui ne sont
  **pas déjà dans la même œuvre** → candidates à regrouper (capte les titres voisins « La Anarquía »
  vs « Anarquía » que le backfill exact a ratés).
- UI : dans le bloc « Œuvre » de `BookDraftForm` (palier ≥ Avancé), bouton **« Suggérer des
  éditions »** → liste → **« Regrouper »** (réutilise `group_books_as_editions`).
- *(Le regroupement manuel existe déjà via « Même œuvre » dans la liste de doublons ; ce lot ajoute
  la suggestion proactive par auteur·rice+titre proche, indépendante du seuil de doublon.)*

### Lot v2-C — Facette / regroupement au catalogue  *(valeur moyenne, plus lourd)*
- Exposer `work_id` dans la MV catalogue (`mv_books_catalog_list_v1` + `catalog_list_anon_v1`) →
  permet à `CatalogPage` de **replier les éditions sous leur œuvre** (1 carte œuvre, « N éditions »)
  ou une facette « œuvre ». Touche la MV (rebuild) + la liste OPAC.
- À cadrer plus finement (impact perf MV + UX liste) → **après A et B**.

### Différé (v3) — Expression/langue dédiée, titre uniforme comme autorité (alias d'œuvre),
suggestion automatique inter-bibliothèques. Faible valeur immédiate (5 œuvres multilingues).

## 2. Intégrations / garde-fous
- RPC publiques (`work_public_detail`) **public-safe** via `catalog_list_anon_v1` (jamais
  `from('books')` direct — fuite réseau, cf. [[catalogue-anon-mv-publique]]).
- RPC staff (`suggest_editions_for_book`) gardée librarian/coordenador, hints `error.catalog.work.*`.
- `merge_book`/`merge_author` : déjà intègrent work_id / works (v1) — vérifier non-régression si
  Lot v2-C touche la MV.
- Aucune perte de notice : v2 reste **non destructif** (regroupement, jamais fusion).

## 3. Phasage recommandé
**A (page Œuvre) → B (auto-regroupement) → C (facette catalogue)**. Expression différée v3.
Chaque lot : migration (si RPC) testée begin/rollback + front (build/eslint/i18n), poussé et CI
verte avant le suivant (les lots front dépendent des RPC déployées).

## 4. Tests d'acceptation (A + B)
- `/obra/15` affiche 4 éditions « Encontros com a Civilização brasileira », auteur lié, tri par année.
- `BookPage` d'une édition : « Œuvre » cliquable → page œuvre.
- `suggest_editions_for_book` propose « La Anarquía » 2010 pour l'œuvre Anarquía (titre proche, même
  auteur·rice, œuvre différente) ; « Regrouper » la rattache.
- Public-safe : œuvre 100% réseau → page œuvre vide côté anon (cohérent avec « autres éditions »).
