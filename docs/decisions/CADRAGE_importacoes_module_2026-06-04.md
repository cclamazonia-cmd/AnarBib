# CADRAGE — Module Importações (chapeau d'import du catalogue)

| Champ | Valeur |
|-|-|
| **Genre** | Dossier d'ouverture de chantier-cadre (cadrage — pas une spec, pas une trace) |
| **Statut** | 🟠 Cadrage v0.1 — 04/06/2026. Aucune ligne de code engagée. À valider avant Phase 1. |
| **Décisions invoquées** | DOC-RPC-3 (RPC pour actions DB) · DOC-OBJ-2 (REVOKE objets backend) · DOC-DEPLOY-1 (migration → Woodpecker) · DOC-PERIM-1 (page = périmètre) · DOC-I18N-1 (9 locales) · **ACQ-Q4** (frontière Catalogação, déjà tranchée) · **FED-5** (rôle = coordenador) · méthode parité + audit doctrinal (stratégie post-Biblioteca) |
| **Supersession** | Premier document structurant du périmètre Importações. Ne supersède rien. Référencé depuis le backlog (macro-chantier à activer) et le registre. |

> Méthode : identique à Biblioteca — **parité fonctionnelle** (rendre utilisable ce qui existe en plomberie) + **audit doctrinal** (RLS / REVOKE / PII / consentement) + **qualité** (UX non-spécialiste). Séquentiel, cadré avant code.

---

## 1. Objectif politique

Importer, pour une bibliothèque militante, ce n'est pas « charger des données ». C'est trois gestes d'**autonomie** :

- **Récupérer son propre fonds** sans rester prisonnière d'un ancien outil (la dette BLMF) — *anti-lock-in*.
- **Mutualiser entre pairs** : tirer une notice d'une bibliothèque sœur du réseau, **avec son consentement explicite** (`mutualizacao_autorizada`), jamais par extraction unilatérale — *fédéralisme, pas centralisation*.
- **Réutiliser l'outillage commun** (Zotero / Terra Livre) sans dépendre d'un fournisseur — *low-tech, formats ouverts*.

Deux lignes rouges doctrinales en découlent et doivent traverser tout le module :
1. **Provenance honnête** : toute notice importée garde la trace d'où elle vient (`book_draft_import_events`). Pas de blanchiment d'origine.
2. **Humain dans la boucle** : pas d'auto-import aveugle. `confidence_level_code` + `review_status_code` existent pour ça — l'import propose, le·la catalogueur·euse dispose.

---

## 2. État réel (inventaire au 03/06/2026, sondé sur le dump)

Le constat clé : **la plomberie de provenance est déjà conçue et posée ; la surface d'usage manque entièrement.**

### 2.1 Ce qui existe

**Couche référence** — 8 tables `catalog_ref_*` (lookups code/label, le vocabulaire contrôlé de l'import) :
`acquisition_modes`, `confidence_levels`, `import_methods`, `mutualization_statuses`, `review_statuses`, `source_formats`, `source_partners`, `source_systems`. → Quelqu'un a modélisé l'import sérieusement avant d'écrire la moindre RPC.

**Couche cible** — `public.book_drafts` : la table de **brouillon de catalogage** (`action` create/update, `status` draft, tous les champs biblio, `batch_id`, `published_book_id`). **C'est là qu'atterrit tout import** avant publication. C'est aussi la table d'entrée de **Catalogação** → voir §6 (couplage).

**Couche provenance** — `public.book_draft_import_events` : journal par brouillon (`book_draft_id`, `event_kind`, `source_partner_code`, `source_system_code`, `source_record_id/url`, `source_format_code`, `import_method_code`, `imported_at`, `last_synced_at`, `review_status_code`, `confidence_level_code`, `event_payload jsonb`, `created_by`). C'est le **contrat de transparence** matérialisé.

**Gardes fédération** — `public.catalog_partners` (pairs : `slug`, `base_url`, `software_family`, `integration_mode`, `relationship_status` `identificada` → …) + trois fonctions de garde :
- `catalog_partner_can_import(status)` et `catalog_partner_status_allows_import(status)` → `true` ssi status ∈ {`importacao_autorizada`, `mutualizacao_autorizada`} ;
- `catalog_partner_require_import_authorized(slug)` → renvoie les `catalog_partners_policy_flags_v2` (garde dure).

### 2.2 Le manque structurel

- **Aucune RPC `api.*` d'import.** La seule fonction catalogue exposée est `api.search_catalog_v1` (recherche). Il n'existe **pas** de surface appelable pour : transformer une ligne de staging → `book_drafts`, déclencher un import Zotero, tirer chez un partenaire, ou réviser/approuver un `book_draft_import_events`.
- **Aucune UI.** Pas de page « Importações ».
- **Staging brut non typé** : `import_blmf_*` ont **toutes leurs colonnes en `text`** (dump CSV figé) ; `import_terra_livre_zotero_staging` a des colonnes `_raw` + `registro_bruto_json`. Rien ne les relie encore à `book_drafts`.

**Conclusion de cadrage** : le chantier n'est pas « concevoir l'import » (c'est fait) — c'est **bâtir l'orchestration, la surface `api.*` doctrinale, et l'UI** par-dessus une fondation déjà saine.

---

## 3. Périmètre du module-chapeau

Une page **Importações** (espace bibliothécaire) qui chapeaute les **trois logiques** sous un parcours unique, chacune produisant des `book_drafts` horodatés de leur provenance, soumis ensuite au flux de révision/publication (Catalogação) :

```
  [Source]            [Staging]                  [Transform/RPC api.*]      [Cible]            [Suite]
  BLMF legacy    →   import_blmf_*_rows      ┐
  Zotero/T.Livre →   ..._zotero_staging      ┼→  api.import_*  (à créer) →  book_drafts   →   révision → publish
  Partenaire     →   (pull en ligne)         ┘   + book_draft_import_events                   (Catalogação)
```

Hors périmètre explicite : la **publication** elle-même (book_drafts → catalogue publié) relève de **Catalogação** ; Importações s'arrête au brouillon tracé.

---

## 4. Les trois logiques (caractérisées)

| | **Legacy BLMF** | **Zotero / Terra Livre** | **Fédération partenaires** |
|-|-|-|-|
| Nature | Migration de fonds existant | Import d'outil de référence | Mutualisation entre pairs |
| Fréquence | **One-shot** (par biblio migrant) | Occasionnel / par lots | Récurrent, à la demande |
| Source | `import_blmf_books_rows` + `_exemplares_rows` (text brut) | `..._zotero_staging` (`_raw` + json) | `catalog_partners` en ligne (`base_url`) |
| Garde | **coordenador** (FED-5) | **coordenador** (FED-5) | **coordenador** + **`catalog_partner_can_import`** (consentement du pair) |
| Inconnue majeure | Mapping text → `book_drafts`, dédup ISBN/CDD | Parsing des `_raw` Zotero | **Mécanique du pull** (Z39.50 ? OAI-PMH ? API ? — `integration_mode` + `technical_probe`) |
| Question de fond | One-shot → est-ce un *module* ou un *script de migration* ? | — | C'est la logique la plus « vivante » et la plus alignée politiquement |

---

## 5. Audit doctrinal (à mener en Phase 2, points d'attention dès Phase 1)

- **DOC-RPC-3** : toute **action** (transform, pull, approuver, rejeter) = RPC `api.*`, **SECURITY DEFINER**, `search_path` figé. Comme **rien n'existe**, toute la surface est à bâtir proprement d'emblée — pas de dette à rattraper, mais pas de filet non plus.
- **DOC-OBJ-2** : chaque nouvelle fonction → `REVOKE … FROM PUBLIC, anon, authenticated, service_role` + `GRANT` ciblé + bloc `DO` de vérification en fin de migration.
- **RLS** : vérifier la posture des tables `import_blmf_*`, `..._zotero_staging`, `book_drafts`, `book_draft_import_events`. Tables `public.*` → `ENABLE RLS` + policy (jamais `DISABLE`). Le staging est probablement admin-only : à confirmer, pas à supposer.
- **Consentement fédératif** : le module **doit** passer par `catalog_partner_can_import` / `require_import_authorized` avant tout tirage. La garde existe ; l'enforcer est non négociable (ligne rouge §1).
- **PII / minimisation** : `created_by` dans le journal, données externes dans les pulls partenaires — minimiser ce qui est conservé.
- **i18n** : libellés des `catalog_ref_*` et de l'UI → 9 locales (DOC-I18N-1). Vérifier si les `label` des tables ref sont mono-langue (probable) → arbitrage A.4 ci-dessous.

---

## 6. Couplage avec Catalogação (à arbitrer, structurant)

Importações **produit** des `book_drafts` ; Catalogação **consomme et publie** `book_drafts`. Les deux chantiers partagent la même table-charnière. **La frontière est déjà tranchée par `ACQ-Q4` (registre §8)** : *ingestion technique → Importações ; provenance / entrée en collection → Catalogação (onglet Exemplaires)*. Reste de cadrage : Importações livre des brouillons en `review_status` initial ; le workflow de revue/publication est du ressort de Catalogação. La stratégie post-Biblioteca prévoit la séquence Importações **puis** Catalogação — mais l'import sans flux de révision aval est un cul-de-sac, d'où le couplage à garder en vue.

---

## 7. Arbitrages ouverts

| Réf | Question | Enjeu |
|-|-|-|
| **IMP-A1** | **Séquençage v1** : les 3 logiques d'un coup, ou une d'abord ? | Proposition : **fédération d'abord** (la plus vivante + alignée politiquement), BLMF en parallèle comme migration, Zotero ensuite. |
| **IMP-A2** | **BLMF = module ou script ?** One-shot text → `book_drafts`. | Si vraiment one-shot par biblio, peut-être un **outil de migration** (hors module récurrent) plutôt qu'une fonction de la page. |
| **IMP-A3** | **Mécanique du pull partenaire** (Z39.50 / OAI-PMH / API / scraping ?). | Inconnue technique #1. `integration_mode` + `technical_probe_last_at` suggèrent une **détection de capacités** à concevoir. Gros morceau. |
| **IMP-A4** | **Mapping & dédup** : staging → `book_drafts`, contre quoi déduplique-t-on (`published_book_id`, ISBN, CDD) ? | Cœur technique transverse aux 3 logiques. |
| **IMP-A5** | **i18n des `catalog_ref_*`** : labels mono-langue ou jsonb 9 locales ? | Conformité DOC-I18N-1 vs réalité de la table. À constater avant de trancher. |
| **IMP-A6** | **Frontière Importações ↔ Catalogação** — **déjà tranchée par `ACQ-Q4`** (ingestion → Importações ; provenance/collection → Catalogação). | ✅ clos : ne pas re-spécifier. |

---

## 8. Méthode & séquençage proposés (Biblioteca-style)

- **Phase 0 — Cadrage** *(ce document)* : périmètre, état réel, arbitrages. → validation.
- **Phase 1 — Parité fonctionnelle** : trancher IMP-A1/A2 ; concevoir la surface `api.*` minimale + le mapping (IMP-A4) ; UI page Importações (parcours par source). Une logique livrée de bout en bout avant la suivante.
- **Phase 2 — Audit doctrinal** : RLS/REVOKE/PII/consentement sur tout le module (§5).
- **Phase 3 — Qualité** : UX non-spécialiste (le·la catalogueur·euse n'est pas bibliothécaire de formation), provenance lisible, états de révision clairs.

Inconnue à dégrossir tôt : **IMP-A3 (pull partenaire)** conditionne l'ampleur réelle. À sonder en début de Phase 1 (que sont `integration_mode` / `software_family` dans les lignes `catalog_partners` réelles ?).

---

## Prompt de reprise

> Chantier-cadre **Importações**. Cadrage v0.1 du 04/06/2026 posé (ce fichier). Fondation backend SAINE et déjà en place : 8 tables `catalog_ref_*`, cible `book_drafts`, journal `book_draft_import_events`, gardes `catalog_partner_*_import`, staging `import_blmf_*` + `..._zotero_staging`. **Manque structurel = aucune surface `api.*` d'import + aucune UI.** Trois logiques : legacy BLMF (one-shot, text brut), Zotero/Terra Livre (occasionnel), fédération partenaires (récurrent, gaté par consentement). Couplage fort avec Catalogação via `book_drafts`. **Prochain pas** : valider le cadrage avec Xavier, trancher IMP-A1 (séquençage) et IMP-A2 (BLMF module vs script), puis ouvrir la Phase 1 sur la première logique retenue. Sonder IMP-A3 (mécanique pull) tôt.
