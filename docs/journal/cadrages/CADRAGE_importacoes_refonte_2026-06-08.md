# Cadrage — Refonte de la page Importações/Exportações (confrontation au backend réel)

**Date** : 2026-06-08
**Auteur** : Xavier (lead AnarBib) en session avec Claude
**Session** : Refonte Importações/Exportações
**Statut** : ✅ cadrage technique livré — confronte la maquette v7 + la spec `spec-importacoes-exportacoes` v0.2 au **code et à la base réels** (sondage `ingest` + EF + frontend, 08/06/2026). Préséance : REGISTRE §17 (`IMP-*`) ; cette note = trace.

> **Pourquoi cette note.** La spec v0.2 (§12) proposait des tables `public.catalog_import_*`. Le sondage du backend a révélé que **le pipeline d'import existe déjà**, dans un schéma **`ingest`** invisible aux requêtes limitées à `public`. Ce cadrage corrige le tir : on **réutilise** l'existant, on ne duplique pas. Doctrine « ne rien supposer / le composant peut être déjà là ».

---

## 1. Le pipeline d'import EXISTE (schéma `ingest`)

Flux réel, de bout en bout (déjà câblé, la page actuelle l'utilise) :

```
1. Upload fichier → Supabase Storage (bucket catalogos_parceiros_raw)
2. ingest.fn_create_partner_catalog_import(source_id, storage_path, …, sha256, detected_format) → run_id
      (idempotent sur source_id + sha256)
3. ingest.fn_dispatch_partner_catalog_import(run_id) → appelle l'EF process-partner-catalog-import
      (parse CSV/TSV/RIS → écrit partner_catalog_staging_rows + statuts)
4. [matching] ingest.fn_match_partner_catalog_run(run_id) → match_candidates / match_status
   [review]   ingest.fn_set_partner_catalog_rows_review(run_id, row_ids[], review_status, selected_for_draft, match_status)
              ingest.fn_set_partner_catalog_editorial_decision(...) / fn_bulk_set_... (accept_new|accept_duplicate|pending|reject)
5. ingest.fn_bulk_create_book_drafts_from_run(run_id, match_statuses[], editorial_decisions[], batch_name)
      → transaction : public.catalog_batches (lote) + public.book_drafts + public.book_draft_import_events (journal)
```

### Modèle de données (existant)
- `ingest.partner_catalog_sources` — sources : `partner_name, library_id, relation_status, source_kind (= manual_upload seul), import_enabled, zotero_*`.
- `ingest.partner_catalog_import_runs` — **le RUN (= IMP-9, déjà là)** : `run_status (ready_for_review|drafts_created|failed), imported_rows/selected_rows/created_drafts, summary jsonb, error_log jsonb, detected_format, parser_version, storage_path, sha256`.
- `ingest.partner_catalog_staging_rows` — **le staging = l'aperçu/dry-run + la fila d'ingestion** : colonnes normalisées + `raw_payload`/`normalized_payload`, `parse_status, match_status, review_status, confidence, warnings, editorial_decision, selected_for_draft, created_book_draft_id`.
- `ingest.partner_catalog_match_candidates` (dédup) · `partner_catalog_row_to_draft` (lien) · `partner_catalog_import_files` · `partner_catalog_import_dispatch_log`.
- `public.catalog_batches` (lote) → `public.book_drafts` (cible) + `public.book_draft_import_events` (journal).
- **Vues UI publiques** (lecture front) : `partner_catalog_sources_ui`, `partner_catalog_import_runs_ui`, `partner_catalog_import_rows_ui`.

### Contrat RPC (tout `ingest.*`, appelé via `supabase.schema('ingest').rpc(...)`)
| RPC | Signature (clé) | Rôle |
|---|---|---|
| `fn_create_partner_catalog_import` | `(source_id, storage_path, original_filename, bucket_id, mime_type, size_bytes, sha256, detected_format, requested_by) → bigint` | crée le run (idempotent sha256) |
| `fn_dispatch_partner_catalog_import` | `(run_id, force_reparse) → jsonb` | appelle l'EF parser |
| `fn_match_partner_catalog_run` / `_row` | `(run_id, row_ids[])` / `(staging_row_id) → jsonb` | dédup |
| `fn_set_partner_catalog_rows_review` | `(run_id, row_ids[], review_status, selected_for_draft, match_status) → jsonb` | révision |
| `fn_set_partner_catalog_editorial_decision` / `fn_bulk_set_...` | `(run_id, row_ids[], decision, note)` / `(run_id, decision, match_statuses[], current_decisions[], note) → jsonb` | décision éditoriale |
| `fn_refresh_partner_catalog_run_counters` | `(run_id) → jsonb` | compteurs |
| `fn_create_book_drafts_from_import_rows` | `(run_id, row_ids[], batch_name, batch_notes) → jsonb` | promotion ciblée |
| `fn_bulk_create_book_drafts_from_run` | `(run_id, match_statuses[], editorial_decisions[]=['accept_new','accept_duplicate'], batch_name, batch_notes) → jsonb` | promotion en masse |

### EF
- `process-partner-catalog-import` (754 l.) — **le parser** : CSV/TSV (détection délimiteur) + RIS (signature). **Mapping codé en dur par alias** (`mapRecord` l.339-436, `mapRisRecord` l.244-316). MARC21/ISO2709 acceptés à l'upload mais **non parsés**. Secret `ANARBIB_PARTNER_IMPORT_SECRET`. Écrit `staging_rows` + maj run.
- `catalog_metadata_lookup` (1305 l.) — **lookup 7-8 sources** (BNE/BnF/DNB/ICCU/LoC/Open Library/Wikidata + BN Brasil), SRU/JSON/SPARQL → **candidats à l'écran**. **N'aboutit pas en staging.**
- `probe-partner-catalog` (196 l.) — **audit de capacités** d'une source (OAI/SRU/REST). **N'aboutit pas en staging.**
- `fetch-url-metadata` — extraction ISBN/métadonnées/RSS depuis une URL (onglets URL/RSS actuels).

### Frontend actuel
`src/pages/importacoes/ImportacoesPage.jsx` (608 l.) — 4 onglets **Reception / URL / RSS / History** ; route `/importacoes` (`ProtectedRoute`, garde-fou **dans la page** : `canImport = librarian|coordenador|administrador`) ; **73 clés `importacoes.*`**.

---

## 2. Confrontation v0.2 ↔ réalité

| Pièce v0.2 | Réalité | Verdict |
|---|---|---|
| **IMP-9** run · dry-run · promotion · dédup · fila (IMP-6) | pipeline `ingest.*` complet ; le **staging EST l'aperçu** | ✅ **EXISTE** — la spec dupliquait, à corriger |
| **IMP-10** profils de mapping | mapping **codé en dur** dans l'EF | ❌ **manquant** (vrai nouveau backend) |
| **IMP-11** registre d'adaptateurs | `detected_format` + parser EF + `parser_version` | ⚠️ logique présente, **registre déclaratif absent** |
| **Circuits** migração / arquivo / fontes externas | `source_kind = manual_upload` seul ; **promotion candidat→staging des fontes externas NON câblée** ; **pull companheira (OAI/Z39.50) inexistant** | ⚠️ **partiel** |
| **Parser MARC/UNIMARC** (migração BLMF) | absent de l'EF | ❌ **manquant** |
| **Export** (lote, ILL, ser fonte OAI) | rien dans le repo | ❌ **entièrement à construire** |
| **Statut de révision** affiché | `staging_rows.review_status` existe mais **non remonté** ; draft = `book_draft_catalog_context.review_status_code` + journal | ⚠️ **à exposer** |
| **Rôles / RLS** | RPC `ingest.*` = **`service_role` seulement** ; garde-fou **frontend uniquement**, **zéro validation backend** | 🛑 **à durcir (DOC-RPC-3)** |
| **Frontend v7** | page 4 onglets, ne porte pas le modèle v7 | ❌ **le gros écart visible** |

---

## 3. Corrections à porter à la spec v0.2
1. **IMP-9** : ne crée **pas** `public.catalog_import_runs` — pointe l'existant **`ingest.partner_catalog_import_runs`**. Le « dry-run » = le **staging** (`partner_catalog_staging_rows` avec `match_status/confidence/warnings`).
2. **IMP-10 / IMP-11** : nouvelles tables **dans le schéma `ingest`** (`ingest.import_mapping_profiles`, `ingest.import_adapters`), pas `public`.
3. **Circuits** : `source_kind` porte le circuit ; les fontes externas exigent **deux ajouts manquants** : (a) promotion candidat `catalog_metadata_lookup` → `staging_rows` (institutionnelles), (b) pull companheira OAI/Z39.50 → `staging_rows` (compagnonnes).
4. **Rôles** : durcir les RPC `ingest.*` — `GRANT … TO authenticated` + **validation de rôle dans la RPC** (`user_can_act_as_staff_on_library` ou équivalent), conformément à DOC-RPC-3 et IMP-14. Le garde-fou frontend ne suffit pas.
5. **Export** : acter qu'il est **100 % à construire** (référence ILL = `spec-flux-partage-numerique`, à coder).

---

## 4. Plan de lots corrigé (réalité-fondé)

- **Lot 0 — durcissement RPC + exposition** *(petit, prérequis)* : `GRANT … TO authenticated` + validation de rôle dans les RPC `ingest.*` (DOC-RPC-3, IMP-14) ; exposer `review_status` dans les vues UI. Sans ça, l'import ne marche pas pour le staff.
- **Lot 1 — frontend v7 (face import)** *(le cœur visible)* : refonte `ImportacoesPage.jsx` sur la maquette v7 (toggle Sentido, bandeau adaptateur en lecture, 3 circuits, **fila de revisão** avec états, **journal**), branchée sur le pipeline `ingest` existant. i18n (10 locales).
- **Lot 2 — fontes externas, bout-en-bout** : câbler candidat `catalog_metadata_lookup` → `staging_row` (institutionnelles) ; cadrer le pull companheira (OAI) — l'inconnue technique.
- **Lot 3 — profils de mapping (IMP-10)** : table `ingest.import_mapping_profiles` + l'EF consulte la table au lieu des alias en dur + UI d'édition (étape mapping).
- **Lot 4 — parser MARC/UNIMARC** (migração BLMF) : ajouter le décodeur ISO 2709/UNIMARC à l'EF.
- **Lot 5 — face export** : sérialisation de lote (couche adaptateur inverse) ; partilha ILL (`spec-flux-partage-numerique`) ; ser fonte (endpoint OAI, `mutualize_allowed`).

---

*Cadrage technique livré le 08/06/2026 ; corrige la spec v0.2 (alignée sur `ingest`). Le backend d'import est construit ; le chantier est surtout **frontend (Lot 1)** + le durcissement des rôles (Lot 0) + les compléments (fontes externas, profils, MARC, export). Foyer normatif : REGISTRE §17.*
