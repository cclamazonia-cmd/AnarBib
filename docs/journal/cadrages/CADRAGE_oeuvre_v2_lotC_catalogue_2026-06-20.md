# CADRAGE — Lot C : repli des éditions + facette « œuvre » au catalogue

> **Date** : 2026-06-20 · **Statut** : cadrage (à valider AVANT de coder — refonte du cœur OPAC).
> **Prérequis** : v2 Lots A (page Œuvre) + B (auto-regroupement) livrés.
> **Session** : Doublons d'autorité & i18n erreurs catalogue.

## 0. Objectif
Au catalogue public (`CatalogPage`), **regrouper les éditions d'une même œuvre** (afficher une seule
entrée « œuvre · N éditions » au lieu de N notices) et/ou offrir une **facette « œuvre »**.

## 1. Pourquoi c'est un vrai chantier (et pas un tweak)
La liste OPAC est une requête **PostgREST paginée sur la vue `catalog_list_{anon,session}_v1`**, avec
un empilement de filtres (recherche par ids via `catalog_search_ids_v1`, sujet, auteur·rice, année,
bibliothèque, disponibilité, ISBN, langue, CDD, matériel, collection, lieu), un **tri** et un
**« charger plus »** (offset). Les **facettes** (`catalog_facets_v1`) comptent des **notices**.

Replier « une ligne par œuvre » impose un **regroupement côté serveur** qui doit coexister avec
**tous** ces filtres + la **pagination** (paginer des œuvres, pas des notices) + les **compteurs**
(compter des œuvres). C'est une réécriture du modèle de liste — risque direct sur le cœur public.

## 2. Backend commun (faible risque, sans rebuild MV)
Exposer sur `catalog_list_anon_v1` / `catalog_list_session_v1` : **`work_id`** + **`edition_count`**
(nb d'éditions publiques de l'œuvre), via le motif éprouvé **fn scalaire SECDEF + append à la vue**
(cf. [[catalog-opac-list-data-flow]]) — **aucun rebuild de MV**. Disponible quelle que soit l'option front.

## 3. Options front (décision requise)

### Opt A — Repli serveur intégral (haute fidélité, haut risque)
Nouveau RPC `api.catalog_collapsed_v1(p_filters, p_offset, ...)` : applique les mêmes filtres puis
**regroupe par `work_id`** (les notices sans œuvre = entrées seules), renvoie des **entrées
catalogue** (œuvre collapsée + count, ou notice seule) paginées. ⇒ réimplémenter filtres/tri/paging
côté serveur + adapter les facettes (compter des œuvres). **Effort élevé, tests lourds.**

### Opt B — Bascule « Regrouper les éditions » (par défaut OFF)
Même chose qu'Opt A mais **derrière un interrupteur**, OFF par défaut → le comportement actuel reste
la norme, le repli est opt-in. **Limite le rayon de blast** ; effort serveur ≈ Opt A mais risque
maîtrisé (la liste par défaut ne change pas).

### Opt C — Facette « œuvres » (filtre) + badge sur les cartes  *(pragmatique, faible risque)*
Pas de repli structurel. (1) **Badge** « N éditions — voir l'œuvre » (→ `/obra/:id`) sur les cartes
dont `edition_count > 1`. (2) **Facette/chip** « Œuvres à plusieurs éditions » qui **filtre** la liste
(via `work_id`/`edition_count`). Zéro pagination groupée, zéro refonte. Livre la **découverte des
œuvres** au catalogue ; « facette » au sens propre.

## 4. Recommandation
Vu le risque sur le cœur OPAC : **Opt C maintenant** (valeur de découverte, sûr), et le **repli
intégral (Opt A) en Opt B (bascule OFF) dans une session dédiée** avec tests (pagination groupée,
facettes-œuvres, intersection recherche). Le repli « dur » par défaut (Opt A sans bascule) est
déconseillé avant l'ouverture.

## 5. Tests d'acceptation (selon l'option retenue)
- Backend : `catalog_list_anon_v1` expose `work_id` + `edition_count` corrects ; perf liste non dégradée.
- Opt C : badge « 4 éditions » sur les cartes de l'œuvre 15 ; chip « plusieurs éditions » filtre la liste.
- Opt B : bascule OFF = liste inchangée (non-régression) ; ON = œuvres collapsées + count, pagination
  et facettes cohérentes ; tous les filtres existants fonctionnent dans les deux modes.
