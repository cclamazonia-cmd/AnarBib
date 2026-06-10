# Cadrage — Wizard d'import « Novo import » (IMP-8)

**Date** : 2026-06-10
**Auteur** : Xavier (lead AnarBib) en session avec Claude
**Session** : Durcissement IMP-14 + cadrage wizard
**Statut** : ✅ cadrage livré (lecture seule, rien codé). Préséance : spec
`spec-importacoes-exportacoes` §9 (IMP-8) + cadrage `CADRAGE_importacoes_refonte_2026-06-08`.

> **Principe (IMP-15).** La page v7 fige le modèle ; le wizard **re-dérive** ce
> modèle en flux linéaire guidé. Conséquence majeure, vérifiée sur le backend
> réel : **presque tout le backend existe déjà** — le wizard réutilise les RPC
> publics `fn_import_*`. Quasi **zéro nouveau backend**.

---

## 1. Forme & route

- **Route dédiée** `/importacoes/novo` (pas une modale), `ProtectedRoute`.
- **Rôle : coordenador uniquement** — aligné sur le durcissement **IMP-14**
  (10/06) qui a passé les wrappers `fn_import_*` en coordenador-only. Cela
  **surclasse** la reco §9.3 (« librarian + coordenador »), conformément à la
  décision de Xavier : import/export sous l'autorité des coordinateurs.
- Lancé par un bouton **« Novo import »** sur le tableau de bord `ImportacoesPage`.
- **Stepper linéaire** avec **retour arrière**. **Écriture `book_drafts`
  uniquement à l'étape finale** (promotion).
- **Import-only** (l'export reste hors wizard, machine à états ILL-7).

## 2. Étapes (v1 réaliste — 4 étapes, mapping différé)

| # | Étape | Backend (déjà présent) |
|---|---|---|
| 1 | **Circuit** : migração / arquivo / fontes externas — détermine l'étape 2 | — (UI) |
| 2 | **Source** (polymorphe) : *arquivo* → upload ; *fontes* → lookup ; *migração* → run en staging existant | `fn_import_create` + `fn_import_dispatch` · `fn_import_ingest_candidate` · `fn_import_list_runs` |
| ~~3~~ | ~~**Mapping** (IMP-10)~~ → **DIFFÉRÉ** : profils `ingest.import_mapping_profiles` pas encore créés ; l'EF mappe par alias codés en dur → v1 = mapping auto, étape masquée | (futur, IMP-10) |
| 4 | **Aperçu / dry-run = LE STAGING** : lignes + statut/confiance/warnings ; exclusion ; décision éditoriale. Zéro écriture `book_drafts` | `fn_import_list_run_rows` · `fn_import_set_rows_review` · `fn_import_set_editorial` |
| 5 | **Promotion** : 1 RPC transactionnelle → `catalog_batches` (lote) + `book_drafts` + `book_draft_import_events` ; récap (N promus / M exclus / P warnings) | `fn_import_promote` |

**Auto-détection** structure/format = l'EF `process-partner-catalog-import`
(`detected_format`), MARC/UNIMARC inclus depuis le **Lot 4**.

## 3. État & reprise — AUCUN nouveau DDL

L'« objet run d'import » **existe déjà** : `ingest.partner_catalog_import_runs`
(`run_status` : `pending → processing → ready_for_review → drafts_created | failed`,
+ compteurs, `summary`, `error_log`, acteur, horodatages). Le wizard lit/écrit ce
run. Quitter/reprendre = rouvrir un run dans son état. → Le « DDL à trancher » du
§9.4 est **caduc** (corrigé au cadrage du 08/06 : le run existe).

## 4. Doctrine dry-run (rappel spec §9.2)

- **Bloquant** : doublon ISBN réseau (CAT-B5) ; ligne non-mappable.
- **Avertissement** (non bloquant) : confiance basse, autorité non résolue → la
  ligne **passe quand même** en `book_drafts` (`review_status = pending_review`
  + drapeau de confiance) ; la **file de revisão** tranche (IMP-6).
- **Idempotence** : `source_record_id` + ISBN/EAN pour ne pas réimporter.

## 5. Ce qui reste réellement à CODER (peu)

1. **Coquille wizard** : route + stepper + état local + navigation av/arrière.
2. **Câblage** des 4 étapes sur les RPC existants (tous présents).
3. *migração* : sélection d'un **run existant** (liste via `fn_import_list_runs`).
4. **i18n** : clés `importacoes.wizard.*` × 10 locales — **dépend de l'accalmie
   de la churn i18n** (au 10/06, une autre session réécrit les locales).
5. *(Futur)* étape **mapping** quand **IMP-10** sera livré.

## 6. Dépendances & coordination

- **Composant stepper** : la session **« BTL database cleanup »** construit un
  `CatalogacaoWizard.jsx` — un wizard de **découverte/onboarding du catalogage**
  (≠ notre wizard d'**import**). Pas de conflit fonctionnel, mais **si elle
  factorise un `<Wizard>`/stepper réutilisable, le réutiliser** (DRY). À
  **clarifier avec elle** avant de coder la coquille.
- **i18n** : ne pas éditer les locales tant qu'elles sont *dirty* côté autre
  session (cf. piège `git add` sweep, vécu le 10/06).

## 7. Maquette

`docs/specs/maquettes/maquette_wizard_import_v1.html` existe → à **réaligner en
v2** sur la page v7 finie (IMP-15 : on dérive le wizard de la page, pas l'inverse).

---

*Cadrage livré le 10/06/2026. Le moteur d'import est construit (Lots 0–4) ; le
wizard est surtout une coquille de présentation guidée + câblage, avec deux
dépendances : coordination du composant stepper (session BTL) et accalmie i18n.*
