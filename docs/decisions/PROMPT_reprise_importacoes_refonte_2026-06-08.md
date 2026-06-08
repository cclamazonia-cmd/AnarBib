# Prompt de reprise — Refonte de la page Importações/Exportações (08/06/2026)

## 0. Pour démarrer (résumé en 5 lignes)
Le chantier de **refonte de la page Importações/Exportações** est **cadré, confronté au backend réel et corrigé**, mais **aucun code n'a encore été écrit**. La découverte majeure : **le backend d'import existe déjà** (schéma `ingest`), seul **le frontend v7 et la couche d'API publique manquent**. La prochaine étape est le **Lot 0 (API publique d'import, ~8 RPC + 1 colonne)**, dont le **design est verrouillé** (§5 ci-dessous). Ne suppose rien : relis les 3 docs d'autorité (§2) avant de coder.

---

## 1. Contexte
Tu reprends le travail de Xavier, lead dev unique d'AnarBib (SIGB pour bibliothèques anarchistes ; React 19 + Vite / Supabase Postgres + Edge Functions Deno ; Codeberg primaire + CI Woodpecker, miroir GitHub). Xavier a fourni la **maquette cible** : `maquette_importacoes_v7.html` (un **tableau de bord** import/export ; copie dans `docs/specs/maquettes/`). Il existe aussi `maquette_wizard_import_v1.html` (stepper, **à re-dériver après** la page — cf. IMP-15).

Le chantier a été **ouvert et cadré le 08/06/2026** (session « Refonte Importações/Exportações »), à la suite de la clôture de plusieurs gros chantiers (Brevo→Resend R.6/R.7, guide de gouvernance 10 langues, clôture Biblioteca, #NOTIFY-Painel-acts complet).

## 2. Documents d'autorité (à relire AVANT de coder)
1. **`docs/specs/spec-importacoes-exportacoes.md` v0.2** — la conception consolidée. `IMP-1..15` tranchés. §12 = les arbitrages ; §13 = le plan de lots (corrigé sur le backend réel).
2. **`docs/specs/REGISTRE_decisions.md` §17 (`IMP-1..15`)** — **foyer normatif** (préséance : REGISTRE > spec > backlog > trace). En cas de doute, c'est lui qui tranche.
3. **`docs/decisions/CADRAGE_importacoes_refonte_2026-06-08.md`** — **LE doc clé** : le contrat exact du backend `ingest` (pipeline + RPC + modèle de données) + l'analyse d'écart + le plan de lots. À lire en entier.

Specs liées : `spec-flux-partage-numerique` (ILL, pour l'export), `spec-partenariat-biblios` (`library_partnerships`, `digital_share`), `spec-acquisition-provenance` (frontière `ACQ-Q4` : ingestion ici, entrée-en-collection en Catalogação).

## 3. Doctrine (décisions tranchées `IMP-1..15`, résumé)
- **IMP-1** bidirectionnel (import ⇄ export) ; frontière `ACQ-Q4`.
- **IMP-2/3/4** : axes orthogonaux **circuit** (migração/arquivo/fontes externas) × **format** (3 plans : structure / vocabulaire / modèle) ; adaptateur = décodeur structure + mappeur vocabulaire → `book_drafts`, piloté par **profil réutilisable**.
- **IMP-5** points d'accès → autorités (jamais texte libre). **IMP-6** tout import → fila de revisão, rien d'auto-publié.
- **IMP-7** symétrie import↔export ; partilha numérique = circuit **ILL-1..9** (biblios fédérées, pas `catalog_partners`).
- **IMP-8** wizard (à re-dériver, IMP-15). **IMP-9** run = `ingest.partner_catalog_import_runs` (existe). **IMP-10** profils de mapping (`ingest.import_mapping_profiles`, à créer). **IMP-11** adaptateurs (registre `ingest.import_adapters` + logique en code). **IMP-12** autorités au dry-run (non bloquant → fila). **IMP-13** export de lote (sérialisation). **IMP-14** rôles (`coordenador`/`librarian`, à durcir). **IMP-15** page v7 canonique, wizard re-dérivé après.

## 4. La réalité du backend — CE QUI EXISTE DÉJÀ (schéma `ingest`)
⚠️ **Piège** : ce schéma est **invisible** aux requêtes limitées à `public`. Toujours sonder `ingest` ET `public`.

Pipeline complet déjà câblé : `upload Storage → ingest.fn_create_partner_catalog_import(source_id, storage_path, …, sha256) → run_id → ingest.fn_dispatch_partner_catalog_import(run_id) [appelle l'EF process-partner-catalog-import qui parse → staging] → matching/review → ingest.fn_bulk_create_book_drafts_from_run(run_id, …) → catalog_batches + book_drafts + book_draft_import_events`.

Tables `ingest` : `partner_catalog_sources`, `partner_catalog_import_runs` (run : statut, compteurs, summary, error_log, detected_format), `partner_catalog_staging_rows` (le staging = l'aperçu ; colonnes normalisées + raw/normalized_payload, parse_status, match_status, **review_status**, confidence, warnings, editorial_decision, selected_for_draft), `partner_catalog_match_candidates`, `partner_catalog_row_to_draft`, `partner_catalog_import_files`, `partner_catalog_import_dispatch_log`.

RPC `ingest.*` (contrat détaillé dans le CADRAGE) : `fn_create_partner_catalog_import`, `fn_dispatch_partner_catalog_import`, `fn_match_partner_catalog_run/_row`, `fn_set_partner_catalog_rows_review`, `fn_set_partner_catalog_editorial_decision` (+ `fn_bulk_set_…`), `fn_refresh_partner_catalog_run_counters`, `fn_create_book_drafts_from_import_rows`, `fn_bulk_create_book_drafts_from_run`.

EF : `process-partner-catalog-import` (parser **CSV/TSV/RIS**, mapping **codé en dur** par alias ; pas de MARC/ISO2709 ; secret `ANARBIB_PARTNER_IMPORT_SECRET`), `catalog_metadata_lookup` (lookup 8 sources → candidats **à l'écran seulement**), `probe-partner-catalog` (audit capacités), `fetch-url-metadata`.

Front actuel : `src/pages/importacoes/ImportacoesPage.jsx` (**608 l.**, 4 onglets Reception/URL/RSS/History, 73 clés `importacoes.*`, route `/importacoes` ProtectedRoute, garde-fou frontend `canImport`).

## 5. CE QUI MANQUE + le design du LOT 0 (à construire en premier)
**Manques** : (a) la **couche API publique** (les vues `partner_catalog_*_ui` n'existent PAS ; `authenticated` n'a aucun accès `ingest`) → **la page actuelle est un squelette non fonctionnel pour le staff** ; (b) les RPC `ingest.*` sont **`service_role` seulement**, garde-fou **frontend uniquement** (zéro validation backend) ; (c) profils de mapping (codés en dur) ; (d) fontes externas = lookup-only (candidat→staging non câblé) ; (e) export = **100 % à construire** ; (f) le **frontend v7**.

### Modèle de sécurité (VALIDÉ par Xavier le 08/06)
Scope = **biblio active de l'acteur** (`my_access.library_id` + `my_access.can_access_painel`), **pas** la biblio de la source. Rôle = `can_access_painel` (cohérent `fn_record_membership_payment`, `IMP-14`).

### Design Lot 0 (VERROUILLÉ) — API publique d'import, ~8 RPC + 1 colonne
Décision technique : **couche 100 % RPC** (pas de vues). Raison : une vue lecture devrait soit être `security_definer` (**bloquée par le hook pre-commit** qui exige `security_invoker=true`), soit imposer **RLS sur les tables `ingest`** (gros). Les RPC `SECURITY DEFINER` role-gated évitent ce conflit (cohérent DOC-RPC-3).
- **Schéma** : `ALTER TABLE ingest.partner_catalog_import_runs ADD COLUMN IF NOT EXISTS library_id uuid;` — estampillé par `fn_import_create` (= biblio active de l'acteur). Sert au filtrage par biblio.
- **RPC lecture** (`SECURITY DEFINER`, scopées biblio acteur) : `fn_import_list_sources()`, `fn_import_list_runs()`, `fn_import_list_run_rows(p_run_id)` — exposent `review_status`.
- **RPC écriture** (valident `can_access_painel`, délèguent aux `ingest.*` **intacts**) : `fn_import_create(...)` (estampille `library_id`), `fn_import_dispatch(p_run_id)`, `fn_import_set_rows_review(...)`, `fn_import_set_editorial(...)`, `fn_import_promote(...)`.
- **Tous** : `SECURITY DEFINER` + `SET search_path` (inclure `ingest`) + `REVOKE EXECUTE FROM PUBLIC` + `GRANT EXECUTE TO authenticated`. Validation du run (« appartient à la biblio de l'acteur ») dans chaque write.
- Vérifier que `fn_import_create` ne casse pas l'idempotence sha256 existante de `ingest.fn_create_partner_catalog_import`.

## 6. Plan de lots complet (cf. spec §13)
- **Lot 0** — API publique d'import (ci-dessus). **Prérequis.**
- **Lot 1** — **Frontend v7 (face import)** : refonte `ImportacoesPage.jsx` sur la maquette v7 (toggle Sentido, bandeau adaptateur en lecture, 3 circuits, fila de revisão avec états, journal), branché sur l'API du Lot 0. i18n 10 locales (préfixe `importacoes.*`, étendre les 73 clés existantes). **Le cœur visible.**
- **Lot 2** — Fontes externas bout-en-bout : câbler candidat `catalog_metadata_lookup` → `staging_row` ; cadrer le pull companheira OAI/Z39.50 (l'inconnue technique).
- **Lot 3** — Profils de mapping (`IMP-10`) : `ingest.import_mapping_profiles` + l'EF consulte la table (au lieu des alias) + UI.
- **Lot 4** — Parser MARC/UNIMARC ISO 2709 (migração BLMF) dans l'EF.
- **Lot 5** — Face Export (100 % à construire) : sérialisation de lote (`IMP-13`), partilha ILL (réf. `spec-flux-partage-numerique`), ser fonte (endpoint OAI, `mutualize_allowed`).
- **Lot 6** — Wizard : maj `maquette_wizard_import_v1` → v2 alignée, puis impl. (`IMP-15`).

## 7. Pièges & découvertes (ne pas re-tomber dedans)
1. **Le schéma `ingest`** porte tout le backend d'import — invisible si on ne sonde que `public`. Sonder les deux.
2. **Les RPC `ingest.*` = `service_role` seulement** ; la page actuelle ne marche pas pour le staff. C'est ce que le Lot 0 répare.
3. **Vues UI absentes** — ne pas supposer qu'elles existent (le front les appelle, elles n'existent pas).
4. **Hook pre-commit actif** (`.githooks`, `core.hooksPath`) : bloque `SECURITY DEFINER` sans `SET search_path` + `REVOKE EXECUTE FROM PUBLIC`, et `CREATE VIEW` sans `security_invoker=true`. D'où le choix all-RPC au Lot 0.
4bis. **Sessions parallèles** : une session OPAC édite activement le corpus docs + le frontend (BibliotecaPage, locales, INDEX, REGISTRE…). **Toujours** `git status --short` avant de stager, **ne stager QUE ses propres fichiers** (chemins explicites), et **re-vérifier le max d'horodatage des migrations** juste avant chaque push (collisions).
5. **Mapping codé en dur** dans l'EF `process-partner-catalog-import` (`mapRecord`/`mapRisRecord`) — c'est là que les profils (Lot 3) se branchent.
6. **Fontes externas = lookup-only** : `catalog_metadata_lookup`/`probe-partner-catalog` n'aboutissent pas en staging (Lot 2 le câble).
7. **Export = rien** dans le repo (Lot 5 = construction complète).
8. **Statut de révision** : `staging_rows.review_status` (côté import) ; côté draft = `book_draft_catalog_context.review_status_code` + journal `book_draft_import_events.review_status_code`.

## 8. Doctrine de travail (rappel, à respecter sans exception)
- **Outils MCP Supabase** : `execute_sql` en **lecture seule** uniquement (diagnostic). **JAMAIS** `apply_migration`/MCP pour le DDL ni `deploy_edge_function` : DDL = fichier de migration horodaté (UTC exact, strictement > max du dossier) + commit + push → Woodpecker applique ; EF déployées par Woodpecker au push.
- **Git** : `git push origin main` pousse Codeberg + GitHub. **Règle d'or** : jamais deux push concurrents ; `git fetch` + vérifier pas en retard avant de pousser ; sérialiser ses propres push (attendre le pipeline vert avant un 2ᵉ push avec migration). Commits : Conventional Commits, **ASCII pur** (mojibake PS), trailer `Session: …` + `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. Docs (.md/.docx) = `[CI SKIP]` ; **jamais** `[CI SKIP]` sur un commit de tête qui porte une migration/EF.
- **SQL** : doctrine `SECURITY DEFINER` + `SET search_path` + `REVOKE EXECUTE FROM PUBLIC` + `GRANT` ; RLS sur nouvelles tables ; horodatage exact. Le hook pre-commit garde ça.
- **i18n** : 10 locales (pt-BR, fr, es, it, de, en, ca, eo, nl, el), clés plates, LF sans BOM, 2 espaces, parité gardée par `i18n.test.js`. Charte v2 : `notes-audit/anarbib-charte-langage-inclusif-v2.md`. (Mails = `mail-strings.ts`, 10 locales, système distinct.)
- **Méthode** : blocs avec points d'arrêt ; `npm run build` **et** `npm test` verts avant commit frontend ; **état des lieux fondé sur le code/la base réels, ne rien supposer** (cette session l'a prouvé 3 fois sur ce chantier) ; préséance documentaire (REGISTRE).
- **Vérif runtime** : pour un nouvel objet, confirmer en lecture seule via `execute_sql` après pipeline vert (migration appliquée, RPC présente, garde-fou rejette) ; e2e = geste de Xavier.

## 9. Identifiants utiles
- **Repo** : Codeberg `anarbib/anarbib` (primaire, Woodpecker) ; miroir GitHub `cclamazonia-cmd/AnarBib`. Repo local : `C:\Users\accat\Claude's AnarBib\anarbib-app\` (apostrophe → guillemets en PowerShell).
- **Supabase** : projet `uflwmikiyjfnikiphtcp`. Prod : `app.anarbib.org`.
- **Bibliothèques pilotes** : BLMF (`library_id='1234825f-a0f9-4fbd-a875-6551c30ea4ca'`, source de la migração UNIMARC/PMB), Terra Livre / BTL (source Zotero).
- **Maquettes** : `maquette_importacoes_v7.html` (tableau de bord, cible) + `maquette_wizard_import_v1.html` (wizard, à re-dériver). Copies repo : `docs/specs/maquettes/`.

## 10. Comment démarrer la prochaine session
1. Salue Xavier, propose un **point d'état rapide** (le rythme du projet est tel que des choses ont pu bouger — un Lot déjà commencé, des migrations OPAC, etc. — **ne suppose rien**, `git fetch` + relis le REGISTRE §17).
2. Relis les 3 docs d'autorité (§2) + sonde `ingest` ET `public` en lecture seule pour confirmer que le backend est inchangé.
3. Attaque le **Lot 0** selon le design verrouillé (§5), en blocs vérifiés : migration (colonne + ~8 RPC, horodatage exact, hook respecté) → push → pipeline vert → vérif lecture seule → puis Lot 1.
4. Si tu vois un présupposé ou un raccourci, **arrête-toi et vérifie** — c'est la règle qui a évité de dupliquer tout le schéma `ingest` cette fois-ci.

Bonne reprise, camarade.
