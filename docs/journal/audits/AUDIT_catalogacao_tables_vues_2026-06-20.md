# AUDIT — Tables & vues derrière les onglets de catalogage

> **Date** : 2026-06-20 · **Statut** : audit (constats vérifiés en prod uflwmikiyjfnikiphtcp).
> **Déclencheur** : confusions vécues à l'édition des éditions multiples d'un classique
> (González Prada, « Anarquía » 1940/2010/2020) — couverture qui « bave », fiche éditée qui
> apparaît dans ses propres doublons, éditions distinctes traitées comme doublons.
> **Session** : Doublons d'autorité & i18n erreurs catalogue.

## 0. Verdict pour la mise en service

**Les données ne sont pas corrompues.** Les deux peurs principales sont des **confusions
d'ergonomie**, pas des pertes/mélanges de données :
- Les couvertures sont stockées **par notice** (`books.cover_object_path`) et l'OPAC (`BookPage`)
  les lit **uniquement** sur la notice (placeholder sinon) — **aucune cover partagée entre éditions
  côté catalogue public**.
- La fusion **exclut** déjà la fiche source ; ce qui ressemble à « la fiche en cours » dans les
  doublons est une **autre édition au titre identique**.

Ce qui manque, ce sont des **garde-fous de précision** (dédoublonnage conscient de l'édition) et des
**outils** (retirer une cover, marquer « pas un doublon »). Réparable, non bloquant si on traite les
P1 ci-dessous avant l'ouverture.

## 1. Cartographie — onglets → sources de données

| Onglet | Composant | Tables / vues / fonctions clés |
|---|---|---|
| Documento | `BookDraftForm` | `book_drafts`, `book_draft_contributors`, `books`, `book_contributors` ; `publish_book_draft`, `suggest_book_duplicates`, `merge_book`, `cover_lookup` (EF), `catalog_metadata_lookup` (EF) |
| Autoria | `AuthorDraftForm` | `author_drafts`, `authors`, `author_name_aliases`, `author_translations` ; `publish_author_draft`, `suggest_author_duplicates`, `merge_author`, `suggest_author_book_matches`, `confirm_author_book_link` |
| Indexação | (indexPanel) | `book_subjects`, `subjects` ; `fn_suggest_subjects_for_draft` |
| Etiquetas | `LabelSheetPrinter` | `exemplares`, `get_exemplar_labels`, `update_exemplar_labels` |
| OCR | `OcrDepositTab` | `book_drafts` (tesseract.js navigateur) |
| Fila | `QueuePanel` | `book_drafts`/`author_drafts`/`exemplar_drafts` (+ `DuplicateCompareModal` → `suggest_draft_duplicates`, `merge_draft_into_book`, `merge_book_drafts`) |
| Lotes | (batchesPanel) | `catalog_batches`, `publish_catalog_batch` |
| Catálogo | `CatalogPanel` | `books`/`authors`/`exemplares` ; `discard_*`, `merge_author` (surfacé 19/06), `request_catalog_refresh` |
| Matéria | `SubjectGovernancePanel` | `subjects`, `subject_relations` ; `merge_subject`, `suggest_subject_duplicates`, `subject_tree_v1` |

Affichage public : MV `mv_books_catalog_list_v1` / `_network_v1` ← `private.fn_catalog_public_rows`/
`_network_rows` ; détail = `BookPage` (lecture directe `books` + `book_holdings`).

## 2. Constats — sain (vérifié)

- **C-OK-1 — Couvertures par notice.** `books.cover_object_path` + `cover_source`/`cover_license`,
  clé Storage stable `books/<bib_ref||id>/front.<ext>` (bucket `covers`). OPAC : `hasCover =
  !!book.cover_object_path`. Vérifié : sur les 3 « Anarquía », seule l'édition 2020 (id 2149) a une
  cover ; 1940/2010 = NULL → placeholder. **Pas de bave en prod.**
- **C-OK-2 — Dédoublonnage exclut la source.** `suggest_book_duplicates` (`b.id <> p_book_id`) et
  `suggest_draft_duplicates` (`b.id IS DISTINCT FROM v_pub`, `d.id <> p_draft_id`) excluent la fiche
  courante / son livre publié.
- **C-OK-3 — Fusions complètes.** `merge_author`/`merge_book`/`merge_subject` réaffectent les FK +
  journalisent (`merge_log`) + suppriment. (`merge_author` couvre les 6 FK, vérifié 19/06.)
- **C-OK-4 — Désync book_authors↔book_contributors réconciliée** (migration
  `20260619210445`, 1243 liens ; 1517→271 fantômes). Voir
  `[[book-authors-contributors-desync]]`.

## 3. Constats — manques confirmés (à corriger)

### P1 — Dédoublonnage aveugle à l'édition  *(le plus structurant)*
`suggest_book_duplicates`/`suggest_draft_duplicates` ne comparent que `fn_normalize_name(titulo)`
(+ auteur) avec seuil `similarity >= 0.5`. **Ni l'année, ni l'éditeur, ni l'ISBN ne discriminent.**
- Cas vécu : les 3 éditions de « Anarquía » (1940 Ercilla / 2010 Fundación / 2020 Colmena), **ISBN
  différents**, se signalent mutuellement ; l'édition 2020 ressort même à **score 1.0** (« Anarquía »
  se normalise comme « Anarquia »).
- Conséquence : impossible de distinguer un **vrai doublon** d'une **édition distincte d'un même
  classique** ; et aucun moyen d'**étouffer** une paire signalée à tort → le rapport et les onglets
  re-proposent éternellement les mêmes faux doublons.
- **Aucune table `book_not_duplicate` / drapeau d'arbitrage.**

### P2 — Pas d'outil « Retirer la couverture »
Le widget cover (`BookDraftForm` ~2150) propose : chercher (EF `cover_lookup`), fichier, page 1 PDF,
mais **rien pour effacer** une cover non désirée. Effacer demande aujourd'hui une édition SQL de
`cover_object_path` + suppression manuelle de l'objet Storage.

### P3 — État de couverture non réinitialisé entre fiches
`coverPreviewUrl`/`coverCandidates` ne sont remis à zéro qu'au `resetForm()`. La recherche de cover
étant **par titre** (EF `cover_lookup`), passer d'une édition à l'autre du même titre montre les
**mêmes vignettes** → impression de bave dans l'éditeur (sans persistance erronée).

### P4 — Sémantique « édition » absente du modèle
`books` n'a pas de champ structuré « édition / réimpression / manifestation » ni de lien
œuvre↔éditions (FRBR-léger). Les éditions d'un classique sont des notices indépendantes que rien ne
relie ni ne distingue — racine commune de P1. (Décision de modélisation, pas un quick win.)

## 4. Illustration — cluster « Anarquía » (González Prada, autorité 10202)

| id | bib_ref | titre | année | éditeur | ISBN | cover |
|---|---|---|---|---|---|---|
| 736 | BTL-TL-000792 | Anarquia | 1940 | Ediciones Ercilla | — | NULL |
| 1201 | BTL-TL-001283 | La Anarquía | 2010 | Fundación… | 978-958-9480-36-6 | NULL |
| 2149 | BTL-TL-002294 | Anarquía | 2020 | Colmena/Anarcrítica | 978-612-48316-3-8 | `books/BTL-TL-002294/front.jpg` |

`suggest_book_duplicates(736)` → renvoie **2149 (1.0)** + **1201 (0.75)** : trois éditions
légitimes, signalées comme doublons.

## 5. Backlog priorisé

- **P1a — dédoublonnage conscient de l'édition** (`suggest_book_duplicates` / `suggest_draft_duplicates`) :
  si les **ISBN normalisés diffèrent et sont tous deux non vides** → exclure (ce ne sont pas des
  doublons) ; si l'un est vide, garder mais **abaisser le score** quand année **ou** éditeur diffèrent.
  Conserver le match ISBN-égal = doublon certain.
- **P1b — drapeau d'arbitrage** : table `public.book_not_duplicate (book_id_a, book_id_b, by, at)`
  (paires ordonnées), consultée par les `suggest_*` pour **masquer définitivement** une paire jugée
  « éditions distinctes ». UI : bouton « Ce n'est pas un doublon » à côté de « Fusionner ici ».
- **P2 — « Retirer la couverture »** : action front (efface `cover_object_path`/`cover_source`/
  `cover_license` + `supabase.storage.from('covers').remove([...])`), gardée staff.
- **P3 — reset cover** : vider `coverPreviewUrl`/`coverCandidates`/`coverFile` au chargement d'une
  fiche (effet sur l'id chargé), pas seulement au `resetForm()`.
- **P4 — modélisation édition/œuvre** (chantier) : champ `edition`/`reimpressao` + éventuel
  `work_id` reliant les éditions, pour distinguer proprement manifestations d'une même œuvre.
  À cadrer (FRBR-léger) — pas avant l'ouverture.

## 6. Déjà livré cette session (rappel)
i18n des erreurs `discard` (`error.catalog.discard.*` ×10) ; bouton « Fusionner… » dans
`CatalogPanel` (surface `merge_author`) ; réconciliation book_authors↔book_contributors
(`20260619210445`) ; nettoyage des doublons d'autorités du rapport réseau (13→2 clusters, 9→2
divergences). Cf. `[[book-authors-contributors-desync]]`, `[[fusion-autorites-pas-doutil-merge]]`,
`[[localizeerror-hint-error-prefix]]`.
