---
Genre : référence
Statut : ✅ implémentée en prod (v1→v3, 15-16/06/2026) — doctrine consolidée a posteriori (18/06)
Décisions : incarne THES-1, THES-2, THES-3, THES-URI (REGISTRE §30) ; cite OPAC-ATL1/OPAC-AGG1 (§18), CAT-H1/ATE-O3 (fusion matière), DOC-I18N-1
Supersédé par : —
---

# Spec — Thésaurus matière

**Statut** : v1.0 — consolidation doctrinale.
**Date** : 18/06/2026
**Origine** : audit 360° (P2 « specs », option 2 — feature livrée en prod **sans spec de référence**, seulement une trace de cadrage). Le chantier thésaurus a été livré en 3 vagues (v1 gouvernance, v2 libellés/synonymes/notation, v3 relations + navigation OPAC + export SKOS) les 15-16/06. **Point critique justifiant la mise par écrit** : THES-URI grave un **identifiant public stable** (`https://app.anarbib.org/thesaurus/<slug>`) qu'il faut honorer. Trace : `docs/journal/cadrages/CADRAGE_thesaurus_matiere_v2_2026-06-16.md`. Ce spec **ne décide rien de neuf**.
**Périmètre** : gouvernance du vocabulaire matière (`subjects`), relations associatives, navigation OPAC par sujets, export SKOS / données liées. **Hors périmètre** : la **fusion** de doublons matière (= `CAT-H1`/`ATE-O3`, `merge_subject`) ; l'indexation matière des notices (déléguée à Baqueiro).

> **Articulation** : §28 ATE (autorités), §18 OPAC (nuage #OPAC8/#AUT2, facettes), §12 CAT (catalogage). Le thésaurus est le **vocabulaire contrôlé** que l'OPAC consomme (arbre, voir-aussi) et que l'extérieur peut moissonner (SKOS).

---

## 1. Principes directeurs

- **THES-1 — éditer le thésaurus = coordination catalogage.** Libellés, statut, notation **et** relations s'éditent via la garde `public.fn_is_catalog_coordinator()`. **Ouvrir l'édition aux contributeur·rices = décision d'AG réseau** (cf. `CADRAGE_assembleias_reseau` §6.1), jamais un arbitrage unilatéral.
- **Anti-fuite OPAC.** La navigation publique compte les livres via `catalog_list_anon_v1` (MV publique), **jamais** `book_subjects` brut → pas de fuite des livres réseau (BTL `visibility_level='network'`) à l'anonyme. *(INV cloisonnement, cohérent §18.)*
- **THES-URI — identifiant public stable.** Chaque concept a une URI **`https://app.anarbib.org/thesaurus/<slug>`**, **identifiant public et stable** (engagement de données liées). **En changer casserait les consommateurs externes** → conserver, ou prévoir une redirection.

---

## 2. Modèle de données

### 2.1 `public.subjects` — les concepts
`id`, **`slug`** (clé de l'URI publique), **`label_i18n` `jsonb`** (libellé préféré multilingue), **`alt_i18n` `jsonb`** (synonymes / variantes affichables = `skos:altLabel`), **`hidden_i18n` `jsonb`** (formes de recherche non affichées = `skos:hiddenLabel`), **`parent_id`** (hiérarchie broader/narrower), **`notation`** (cote CDD), `scope_note`, **`status`** ∈ `{proposto, ativo, depreciado}` (défaut `proposto`, CHECK), horodatage + `created_by`/`updated_by`.

### 2.2 `public.subject_relations` — relations associatives (THES-2)
Paire **canonique symétrique** (« voir aussi » = `skos:related`). La hiérarchie broader/narrower reste portée par `subjects.parent_id` (pas ici).

### 2.3 Liens aux notices
`public.book_subjects` (notices publiées) + `public.book_draft_subjects` (brouillons, RLS catalogação) ; alimentés au catalogage par le picker `SubjectAuthorityPicker` + `fn_sync_book_subjects_on_publish`.

---

## 3. Gouvernance & cycle de vie (THES-1, v1)

- **Statuts** : `proposto` (proposé, en file d'activation) → `ativo` (publié, utilisable) → `depreciado` (retiré du choix actif, conservé pour l'historique/redirection). Une relation (THES-2) **exige deux concepts `ativo`** (garde dans `fn_subject_add_relation`).
- **Édition** (coord catalogage) : libellés multilingues + synonymes + notation + relations, via l'éditeur **`SubjectLabelEditor`** (catalogage) ; suggestions assistées (v2).
- **Fusion** de doublons : hors de cette spec → `merge_subject` (`CAT-H1`/`ATE-O3`).

---

## 4. Relations associatives — `skos:related` (THES-2, v3-A)

- **`api.fn_subject_add_relation(p_subject_id, p_related_id)`** / **`api.fn_subject_remove_relation(...)`** — `authenticated`, REVOKE PUBLIC, **garde coord** + exige les 2 sujets `ativo` ; paire canonique symétrique (pas de doublon inverse).
- **`api.subject_related_v1(p_subject_id) → (id, slug, label_i18n, notation)`** — **public** (`anon`), alimente le « voir aussi » de l'OPAC.

---

## 5. Navigation OPAC (THES-3, v3-C)

- **`api.subject_tree_v1() → (id, slug, label_i18n, parent_id, notation, book_count)`** — **public** (`anon`) ; l'**arbre** des sujets avec **compte de livres calculé sur `catalog_list_anon_v1`** (anti-fuite, cf. §1). Câblé dans `CatalogPage` (`subjectTree`).
- **Nuage / facette sujets** : `api.author_subjects_v1(author_id)` (page auteur·rice, #AUT2) + clé `subjects` de `api.catalog_facets_v1` (#OPAC8) — cf. §18 OPAC-AGG1.
- **OPAC par cote CDD** : **reporté** (0 notation remplie ; le cotage est délégué à Baqueiro).

---

## 6. Export SKOS / données liées (THES-URI, v3-B)

- **`api.thesaurus_export_v1() → jsonb`** — **public** (`anon`) ; sérialisé par **`src/lib/skosExport.js`** en **Turtle** et **JSON-LD** (téléchargeable depuis l'OPAC).
- **URI de base** : `THESAURUS_BASE = 'https://app.anarbib.org/thesaurus/'` → URI concept = base + `slug`. **Stable, à honorer.**
- **Mapping SKOS** : `label_i18n` → `skos:prefLabel` (par langue) ; `alt_i18n` → `skos:altLabel` ; `hidden_i18n` → `skos:hiddenLabel` ; `parent_id` → `skos:broader` ; `subject_relations` → `skos:related` ; `notation` → `skos:notation` ; `scope_note` → `skos:scopeNote` ; le `status` gouverne l'inclusion (concepts `ativo`).

---

## 7. i18n

`label_i18n` / `alt_i18n` / `hidden_i18n` sont des dictionnaires par locale → le thésaurus est **multilingue** (DOC-I18N-1, 10 locales). Le 1er seed couvre ~29 sujets anarchistes (13 en hiérarchie).

---

## 8. Points ouverts / hors-périmètre

- **Ouverture de l'édition aux contributeur·rices** : 🟡 **décision d'AG réseau** (pas unilatérale) — cf. `CADRAGE_assembleias_reseau` §6.1.
- **OPAC par cote CDD** : reporté (dépend du cotage, délégué Baqueiro).
- **Reprise de l'`assuntos` texte** (legacy) vers le thésaurus : non prioritaire (le picker peuple au fil du catalogage).
- **Fusion de doublons matière** : `merge_subject` (§28 ATE / CAT-H1).

---

## 9. Annexe — artefacts (vérifiés dans le baseline `20260510000000_baseline_live.sql`)

- **Tables** : `public.subjects` (status/label_i18n/alt_i18n/hidden_i18n/notation/parent_id/slug), `public.subject_relations`, `public.book_subjects`, `public.book_draft_subjects`.
- **Fonctions** : `public.fn_is_catalog_coordinator` ; `api.fn_subject_add_relation` / `fn_subject_remove_relation` (coord) ; `api.subject_related_v1` / `subject_tree_v1` / `thesaurus_export_v1` (public `anon`) ; `api.search_subjects` / `author_subjects_v1` ; `fn_sync_book_subjects_on_publish`.
- **Frontend** : `src/lib/skosExport.js` (`THESAURUS_BASE`, `toTurtle`/`toJsonLd`) ; `CatalogPage` (arbre `subject_tree_v1`, voir-aussi `subject_related_v1`, export `thesaurus_export_v1`) ; `SubjectLabelEditor` + `SubjectAuthorityPicker` (catalogage).
- **Décisions REGISTRE** : §30 THES-1/2/3/URI ; cousins §18 OPAC (OPAC-ATL1/AGG1), §28 ATE, §12 CAT (`merge_subject`).

---
*Spec produit le 18/06/2026 (session « Audit 360 — remise à niveau P0/P1 »), consolidation a posteriori d'un chantier livré en prod (v1→v3, 15-16/06) qui n'avait qu'une trace de cadrage. ⚠️ THES-URI : l'URI `https://app.anarbib.org/thesaurus/<slug>` est un engagement public stable à honorer.*
