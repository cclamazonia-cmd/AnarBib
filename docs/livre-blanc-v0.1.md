# AnarBib — Livre Blanc v0.1

**Date** : 2026-05-05
**Auteur·ices** : Xavier (admin·istrateur·ice AnarBib) + assistant IA (rédaction)
**Statut** : Mini-Livre Blanc, point d'étape pré-Bologna
**Périmètre** : photographie aérienne du projet à date

> ⚠️ **Avertissement de version** : ce document est un **point d'étape v0.1**, rédigé en fin de journée d'une session intensive (14 livrables déployés ce jour). Il documente fidèlement ce qui a pu être audité, et **marque explicitement les zones grisées** qui devront être documentées en session dédiée. Une version v1.0 plus exhaustive est prévue après l'application de quelques specs majeures (validation physique, gouvernance des rôles, workflow réservation) et après nettoyage de la dette technique identifiée.

---

## Sommaire

1. [Identité du projet](#1-identité-du-projet)
2. [Indicateurs](#2-indicateurs)
3. [Architecture technique](#3-architecture-technique)
4. [Frontend](#4-frontend)
5. [Backend Supabase](#5-backend-supabase)
6. [Edge Functions](#6-edge-functions)
7. [Sécurité](#7-sécurité)
8. [Internationalisation](#8-internationalisation)
9. [Documentation](#9-documentation)
10. [Dette technique identifiée](#10-dette-technique-identifiée)
11. [Roadmap](#11-roadmap)
12. [Zones grisées](#12-zones-grisées)

---

## 1. Identité du projet

**AnarBib** est un Système Intégré de Gestion de Bibliothèques (SIGB) destiné à un réseau de **bibliothèques militantes anarchistes et libertaires** : **RebAL** (Réseau de Bibliothèques Alternatives Libertaires).

**Objectif** : fournir un outil de bibliothéconomie professionnel — catalogage, circulation, prêt entre bibliothèques, gestion des cotisations — adapté à la **culture politique** du réseau (horizontalité, langage inclusif, transparence des décisions).

**Échéance majeure** : présentation au réseau lors du **FICEDL Bologne, septembre 2026**.

**Domaine** : `anarbib.org` (registrar OVH). Application accessible sur `app.anarbib.org`.

**Positionnement** : alternative non-marchande aux SIGB existants (PMB, Koha, etc.), avec une attention particulière à l'inclusivité linguistique (6 locales avec conventions militantes propres) et à la gouvernance horizontale.

---

## 2. Indicateurs

### 2.1. Volumes de données (au 05/05/2026)

|Entité|Comptage|
|-|-|
|**Bibliothèques**|3|
|**Profils utilisateur·rices**|4|
|**Memberships actifs**|4|
|**Livres (notices catalogue)**|2 450|
|**Exemplaires physiques**|2 461|
|**Inventaires de bibliothèque (book_holdings)**|2 451|
|**Auteur·rices**|160|
|**Liens livre↔auteur**|726|
|**Réservations actives ou historiques**|10|
|**Lignes de réservation**|10|
|**Workflows de réservation**|10|
|**Emprunts (emprestimos)**|10|
|**Items d'emprunts**|10|
|**Consultations sur place**|6|
|**Prêts entre bibliothèques (PEB)**|1|
|**Tâches internes painel**|1|
|**Paiements de cotisation**|1|
|**Demandes d'adhésion bibliothèque**|0|
|**Documents numériques (digital_assets)**|1|
|**Resources digitales rattachées aux livres**|7|

### 2.2. Lecture politique de ces chiffres

Le projet est en **phase de maturité technique avancée** mais d'**adoption naissante** :

* L'**infrastructure** est riche et profonde (84 tables, 100+ fonctions, 19 Edge Functions, RLS partout)
* Le **catalogue** est substantiel (2 450 livres, 2 461 exemplaires) — c'est le résultat d'imports massifs de catalogues partenaires
* L'**activité circulatoire** est encore embryonnaire (10 emprunts, 10 réservations, 1 PEB) — l'outil n'est pas encore en pleine production opérationnelle
* Le **réseau RebAL** compte 3 bibliothèques techniquement actives sur la plateforme, dont la BLMF (Belém do Pará)

C'est un signal sain : **on a construit l'outillage avant de scaler l'usage**. Le défi des prochains mois sera l'adoption opérationnelle, en lien avec les bibliothèques qui rejoindront via le workflow d'onboarding.

### 2.3. Taille du dépôt

|Métrique|Valeur|
|-|-|
|Fichiers suivis par git|132|
|Volume total|~6,3 MB|
|Frontend (src/)|5,7 MB|
|JSX/JS source|45 fichiers|
|CSS|13 fichiers|
|Migrations DB|5 fichiers historiques|
|Edge Functions (supabase/)|23 fichiers TS|
|Documentation|15 fichiers|

---

## 3. Architecture technique

### 3.1. Stack

```
┌──────────────────────────────────────────────────────────────────┐
│  Frontend (React 19 + Vite 6)                                    │
│  Codeberg Pages (prod) + GitHub Pages (mirror)                   │
│  Domaine : app.anarbib.org                                       │
└──────────────────────────────────────────────────────────────────┘
                            │
                            │ HTTPS
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│  Cloudflare Turnstile (anti-bruteforce)                          │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│  Supabase Cloud (uflwmikiyjfnikiphtcp.supabase.co)               │
│  ┌────────────────┐  ┌──────────────┐  ┌───────────────────┐     │
│  │ PostgreSQL 17  │  │ Auth (GoTrue)│  │ Edge Functions    │     │
│  │ (84 tables)    │  │              │  │ (Deno, 19 fns)    │     │
│  └────────────────┘  └──────────────┘  └───────────────────┘     │
│  ┌────────────────┐  ┌──────────────┐  ┌───────────────────┐     │
│  │ Storage        │  │ pg_cron      │  │ Vault (secrets)   │     │
│  │ (11 buckets)   │  │ (6 jobs)     │  │                   │     │
│  └────────────────┘  └──────────────┘  └───────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│  Brevo (mail transactionnel multi-clés API)                      │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2. Hosting et déploiement

* **Frontend** : déployé statiquement sur **Codeberg Pages** (prod) et **GitHub Pages** (mirror). Build via `vite build`, push automatique via `gh-pages`.
* **Backend** : Supabase Cloud, project ref `uflwmikiyjfnikiphtcp`, région à confirmer.
* **Domaine** : DNS configuré chez OVH, pointage vers Codeberg Pages.

### 3.3. Workflow git

* **Remotes doubles** : `origin` (GitHub `cclamazonia-cmd/AnarBib`) et `codeberg` (`anarbib/anarbib`)
* **Alias custom** : `git publish-app` pousse aux deux remotes
* **Branche principale** : `main`
* **Commit le plus récent** : `eb8b148` — *docs(gouvernance): spec gouvernance des rôles*

---

## 4. Frontend

### 4.1. Stack technique

|Dépendance|Version|Rôle|
|-|-|-|
|`react`|19.1.0|UI|
|`react-dom`|19.1.0|Render|
|`react-router-dom`|7.5.0|Routing SPA|
|`react-intl`|7.1.0|i18n|
|`@supabase/supabase-js`|2.49.0|Client BDD|
|`@marsidev/react-turnstile`|1.5.2|Captcha (ajouté 05/05)|
|`react-phone-number-input`|3.4.16|Saisie tél internationale|
|`react-markdown`|10.1.0|Rendu markdown (manuel, RGPD)|
|`i18n-iso-countries`|7.14.0|Référentiel pays|
|`jszip`|3.10.1|Export RGPD données utilisateur|
|`vite`|6.3.0|Build (dev)|
|`vitest`|4.1.5|Tests (dev)|

### 4.1.1. Lecteur multi-format



#### Contexte et choix politique



AnarBib propose une expérience de lecture en ligne **immersive et politiquement consciente** des contenus numériques mis à disposition par les bibliothèques du réseau. Le lecteur est conçu pour respecter trois principes simultanés :



1. **Accessibilité totale aux militant·es** : aucune barrière technique, formats variés (texte, audio, vidéo, image), interface multilingue avec conventions inclusives.

2. **Respect de la confiance** plutôt que DRM : on attribue les fuites par filigrane email/timestamp, on ne tente pas de les empêcher mécaniquement (ce qui serait à la fois techniquement vain et politiquement contradictoire).

3. **Code unique pour toute l'application** : un seul composant `ReaderPage`, branché sur tous les formats, accessible par une URL stable `/ler/:id`.



#### Formats supportés



Le `viewer_kind` est calculé côté Edge Function (`read-digital-asset`) à partir du `resource_type` et du `mime_type` de la ressource :



| Format | Composant | Capacités |

|---|---|---|

| **PDF** | `ReaderPage` (rendu interne) | Scroll continu, IntersectionObserver, filigrane diagonal, fit-width, plein écran, navigation par numéro de page |

| **Audio** | `<AudioPlayer />` | Scrub, vitesse cyclique 0.5×–2×, saut ±10s, bookmark localStorage, filigrane décoratif |

| **Vidéo** | `<VideoPlayer />` | Idem audio + sous-titres `.vtt` (API prête), filigrane sur l'image, auto-hide contrôles en plein écran |

| **Image** | `<ImageViewer />` | Zoom mollette/boutons/double-click, pan, reset, dimensions natives, filigrane sur l'image |

| **Lien externe** | Notice + redirection | Avertissement "site externe" avant ouverture |

| **Type non reconnu** | Fallback | Ouverture nouvelle fenêtre |



#### Architecture technique



```

URL : /ler/:id  ou  /ler-recurso?asset_id=X

        │

        ▼

┌──────────────────────────────────────────────┐

│  ReaderPage  (src/pages/public/ReaderPage)   │

│  ─ Récupère le titre du livre                │

│  ─ Appelle l'Edge Function read-digital-asset│

│  ─ Reçoit { viewer_kind, access_url, asset } │

└──────────────────────────────────────────────┘

        │

        ▼ dispatch sur viewer_kind

        │

        ├──── pdf       → rendu interne (scroll continu)

        ├──── audio     → <AudioPlayer />

        ├──── video     → <VideoPlayer />

        ├──── image     → <ImageViewer />

        ├──── ext_link  → notice + bouton ouvrir

        └──── generic   → fallback ouvrir

```



Tous les viewers respectent un **moule commun** :

- Chargement en blob (l'URL signée Supabase n'est jamais exposée au DOM)

- Scope d'anti-copie limité au conteneur viewer (clic droit / Ctrl+S / drag)

- Filigrane optionnel (`AnarBib · {libraryName} · {userEmail}`)

- i18n complète × 6 locales avec conventions militantes

- CSS cohérent (variables `--brand-*`, ratio 16:9 quand applicable)



#### Migration depuis ResourcePage



Avant cette refonte, AnarBib avait deux pages de lecture :

- `ReaderPage` : lecteur PDF avec scroll continu et filigrane (UX immersive)

- `ResourcePage` : "lecteur multi-format" générique mais qui ne testait que le PDF



Cette dualité a été résolue en mai 2026 par la promotion de `ReaderPage` au rang de lecteur multi-format unique. `ResourcePage` a été déprécié et supprimé du repo. Les routes `/ler/:id` et `/ler-recurso?asset_id=X` pointent désormais toutes les deux vers `ReaderPage`, garantissant la rétro-compatibilité des liens existants.



#### Stockage et contraintes



Les ressources sont stockées dans Supabase Storage :



- **`anarbib-pdf-public`** / **`pdf-restrito`** : PDF

- **`anarbib-media-public`** / **`anarbib-media-restricted`** : audio, vidéo, image



La cohérence `asset_kind` ↔ `bucket_name` est garantie au niveau base par la contrainte CHECK `digital_assets_kind_bucket_chk` (impossible de mettre un MP3 dans un bucket PDF par accident).



#### État au jalon Livre Blanc v0.1



- ✅ Code des 4 viewers (PDF, Audio, Vidéo, Image) en place et testé sur PDF en production

- ✅ Edge Function `read-digital-asset` opérationnelle (8 versions déployées)

- ✅ Migration SQL appliquée (`asset_kind` élargi à 8 valeurs, contraintes cohérentes)

- ✅ i18n complète : 46 nouvelles clés × 6 locales pour les viewers, 14 pour `reader.*`

- ⏳ Aucun asset audio/vidéo/image en base (uniquement PDF) — tests en attente d'usages réels

- ⏳ Cataloguation manuelle pour ces formats (extension `CatalogacaoPage` au backlog)

- ⏳ EPUB et archive : viewers à créer (epub.js, ~1 j de dev)

- ⏳ Sous-titres vidéo : API frontend prête, schéma base à étendre



#### Limites assumées



Le filigrane et l'anti-copie ne sont **pas** des protections absolues. Une personne déterminée peut toujours :

- Capturer l'écran (PrintScreen, outils OS)

- Enregistrer la vidéo/l'audio via un enregistreur d'écran

- Extraire le contenu via DevTools



Ce choix est politique : on attribue les fuites par filigrane (responsabilité collective) plutôt que de les empêcher (DRM, qui serait à la fois techniquement contournable et idéologiquement opposé à la libre circulation des savoirs militants). La confiance entre les bibliothèques et leurs lectrices·eurs reste le pilier de l'éthique de partage.



### 4.2. Pages principales

Le projet expose **21 pages** organisées par domaine :

**Pages publiques** (`src/pages/public/`) :

* `CatalogPage.jsx` (40 KB) — catalogue unifié, recherche, navigation facettée
* `BookPage.jsx` — fiche livre détaillée
* `AuthorPage.jsx` — fiche auteur·rice
* `ReaderPage.jsx` — page publique d'un·e lecteur·rice (sur sa biblio)
* `ResourcePage.jsx` — page ressource numérique
* `LoginPage.jsx` — connexion (refactorée 05/05 avec Turnstile)
* `CriarContaPage.jsx` — création de compte
* `SolicitarBibliotecaPage.jsx` — formulaire d'adhésion d'une nouvelle biblio
* `PrivacyPolicyPage.jsx` — RGPD/politique de confidentialité

**Pages utilisateur** :

* `AccountPage.jsx` (65 KB) — dashboard `/conta` (compte personnel, emprunts, réservations, paiements)
* `BibliotecaPage.jsx` (87 KB) — dashboard `/biblioteca` (gestion d'une bibliothèque, identité, équipe, etc.)

**Pages staff** :

* `PanelPage.jsx` (87 KB) — `/painel` (gestion opérationnelle : circulation, validation inscriptions, tâches)
* `CatalogacaoPage.jsx` (22 KB) — `/catalogação` (catalogage)
* `BookDraftForm.jsx` (105 KB) — formulaire de brouillon livre (le plus gros fichier du projet)
* `AuthorDraftForm.jsx` (35 KB)
* `ExemplarDraftForm.jsx` (28 KB)
* `CatalogPanel.jsx`, `QueuePanel.jsx`, `LabelSheetPrinter.jsx` — outils catalogage

**Pages réseau et import** :

* `RedePage.jsx` (31 KB) — vue réseau (statistiques, autres biblios)
* `ImportacoesPage.jsx` (38 KB) — imports en lot

### 4.3. Composants partagés

`src/components/` :

* **forms/** : `CountrySelect`, `StateSelect`, `PhoneInput` (refactorés 05/05)
* **layout/** : `ProtectedRoute`, `index` (Navbar, Footer)
* **library/** : `RetentionPolicySection` (configuration RGPD)
* **privacy/** : `LibraryPrivacySection`
* **account/** : `DataExportButton` (export RGPD avec jszip)
* **ui/** : composants génériques (modales, badges, etc.)
* `UnifiedSearchCombobox` — autocomplétion unifiée du catalogue

### 4.4. Bibliothèques utilitaires

`src/lib/` :

* `addressFormat.js` — helper de formatage d'adresse (créé 05/05, gère 4 formats legacy en lecture)
* `countries.js` — utilitaires ISO et i18n des noms de pays
* `roles.js` — helpers de permissions (`isReader`, `isLibrarian`, `isCoord`, `isAdmin`, `canSeeXxx`)
* `supabase.js` — client Supabase + helpers `notifyEvent`, `apiQuery`, `apiRpc`, `publicAssetUrl`
* `theme.js` — système de thèmes (per-library, override CSS variables)
* `useDocumentTitle.js` — hook SPA pour title (créé 05/05)

---

## 5. Backend Supabase

### 5.1. Modèle relationnel

**84 tables** organisées en domaines logiques :

**Identité et accès** :

* `profiles` (4 lignes) — utilisateur·rices
* `user_library_memberships` (4 lignes) — liens user↔biblio↔rôle
* `auth_rate_limits` (créée 05/05) — anti-bruteforce login
* `network_staff`, `network_reviewers` — rôles cross-réseau

**Bibliothèques** :

* `libraries` (3 lignes) — métadonnées techniques
* `library_commons` — identité publique partagée
* `library_contact_profiles` — contacts confidentiels
* `library_email_identity` — identité email d'envoi
* `library_membership_rules` — règles de cotisation
* `library_notification_policies`, `library_notification_profiles`, `library_mail_channels` — config notifs
* `library_regulation_documents`, `library_document_governance` — règlements
* `library_circulation_policy_sets`, `library_circulation_policy_rules` — règles de prêt
* `library_retention_policies` — politique RGPD
* `library_service_state` — état de service (ouvert/pause)
* `library_themes`, `library_theme_configs` — thèmes UI
* `library_requests`, `library_request_claims`, `library_request_notification_events` — workflow d'adhésion

**Catalogue** :

* `books` (2 450 lignes), `book_holdings` (2 451), `exemplares` (2 461)
* `book_catalog_context`, `book_contributors`, `book_authors`, `book_digital_resources`
* `authors` (160), `author_translations`, `author_name_aliases`
* `digital_assets`
* 7 tables `catalog_ref_*` — référentiels (modes acquisition, formats, etc.)
* `book_drafts`, `author_drafts`, `exemplar_drafts` + tables draft associées — workflow catalogage
* `catalog_batches`, `catalog_partners`, `catalog_partner_capabilities`, `catalog_partner_probe_runs`
* `partner_source_records`, `partner_source_items`, `partner_source_holdings` — staging imports
* `import_blmf_books_rows`, `import_blmf_exemplares_rows`, `import_terra_livre_zotero_staging` — staging spécifiques

**Circulation** :

* `reservas_v2`, `reserva_linhas_v2`, `reserva_item_workflow_v2`
* `emprestimos_v2`, `emprestimo_itens_v2`
* `consultas_locais_v2`, `consulta_linhas_v2`, `consulta_item_workflow_v2`
* `interlibrary_loans_v2`, `interlibrary_loan_items_v2`, `interlibrary_loan_events`, `interlibrary_loan_notification_events`
* `loan_midpoint_message_log`
* `membership_payments`

**Painel (gestion staff)** :

* `painel_internal_tasks`, `painel_internal_task_invites`
* `painel_internal_task_notification_outbox`, `painel_internal_task_invitation_outbox`
* `document_permission_requests`, `document_permission_request_notification_events`

**Utilisateur·rices** :

* `user_notifications`
* `user_wishlist`

**Reliquats à nettoyer** (cf. §10) :

* `_backup_library_request_claims_20260408`
* `_backup_library_request_notification_events_20260408`
* `_backup_library_requests_20260408`
* `book_authors_backup_suspect_mono`

### 5.2. API publique : 34 vues `api.*`

Le schéma `api` expose un **contrat stable** entre frontend et BDD, indépendant du modèle physique :

* **Catalogue** : `catalog_book_detail_public_v2`, `catalog_books_public_v2`, `catalog_books_public_session_v2`, `catalog_list_anon_v1`, `catalog_list_session_v1`, `books_count_v1`
* **Bibliothèques** : `libraries_public_v1`, `library_circulation_stats`, `library_email_identity`, `library_service_public`
* **Session utilisateur** : `my_access`, `my_profile`, `my_library_context`, `my_session_context`
* **Mes données** : `my_consultas_active_v2`, `my_consultas_history_v2`, `my_reservations_active_v2`, `my_reservations_history_v2`
* **Painel staff** : `consulta_itens_ui`, `consulta_itens_followup_ui`, `emprestimo_itens_ui`, `emprestimo_itens_painel_ui`, `emprestimo_lotes_painel_ui`, `interlibrary_loan_items_ui`, `interlibrary_loans_painel_ui`, `interlibrary_loans_reports_ui`, `reserva_itens_followup_ui`
* **Imports partenaires** : 7 vues `partner_catalog_*_ui`

### 5.3. Vues matérialisées

* `mv_books_catalog_list_v1` — catalogue public anonyme (rafraîchi par cron toutes les 15 min)
* `mv_books_catalog_list_network_v1` — catalogue niveau réseau

Ces vues matérialisées portent l'essentiel du poids des index (les indexes les plus volumineux du projet sont sur ces vues, pour le full-text via `pg_trgm`).

### 5.4. Fonctions PL/pgSQL et SQL

> ⚠️ **Zone partiellement grisée** : le retour SQL audit a été tronqué à 100 fonctions par limitation de pagination. Le compte total est probablement de **150-250 fonctions**. Une cartographie exhaustive est à faire en session dédiée.

**Catégories identifiées** (sur le sous-ensemble audité) :

* **Helpers de permissions** : `user_has_library_staff_role`, `user_can_manage_library`, `fn_library_visible_to_caller`, `fn_current_user_is_in_network`, `fn_current_user_is_member_of`, `fn_current_user_can_*` (5 helpers réseau), etc.
* **Fonctions API** (schéma `api`) : 12 fonctions de circulation (`get_due_date_for_loan`, `get_remaining_renewals`, `resolve_circulation_rule`, etc.) + `resolve_login_email`, `search_catalog_v1`
* **Workflow drafts catalogue** : `create_book_draft_from_book`, `create_author_draft_from_author`, `copy_book_catalog_context_to_draft`, etc.
* **Notifications** : `fn_enqueue_*` (3 enqueue : document_permission, library_request, interlibrary_loan), `fn_notify_*_now`, `fn_dispatch_circulation_notify_event`, `dispatch_task_notification_outbox`, `dispatch_task_invitation_outbox`
* **RGPD** : `fn_export_my_data`, `fn_delete_my_account`, `fn_purge_expired_data`, `fn_notify_users_before_purge`, `fn_get_retention_policy`
* **Painel** : `fn_painel_find_profile_by_email`, `fn_painel_find_profile_by_lookup`, `fn_painel_get_profile_by_id`
* **Réseau** : `fn_network_dashboard_summary`, `fn_network_library_metrics`, `fn_network_get_library_request`, `fn_network_list_library_requests`, `fn_network_discard_library_request`
* **Workflow library_requests** : `fn_review_library_request`, `fn_activate_approved_library_request`, `fn_consume_library_request_claim`, `fn_get_library_request_claim_context`
* **Cotisations** : `fn_record_membership_payment`, `fn_compute_membership_validity`, `fn_list_membership_payments_for_user`
* **Renouvellement emprunts** : `fn_renew_my_loan`, `fn_is_loan_blocked_by_dues`
* **Catalog bridge** : `catalog_bridge_*` (helpers JSON pour MARC)

### 5.5. RLS — Row Level Security

**RLS activée sur 100% des 84 tables** (`relrowsecurity=true`). Aucune table sans RLS.

> ⚠️ Note : `relforcerowsecurity` est `false` partout. Les fonctions SECURITY DEFINER bypassent donc la RLS quand elles agissent. C'est volontaire pour le pattern Supabase.

**Politiques RLS notables** :

* **`libraries`** : visibilité publique conditionnelle (`is_active` + `visibility_level` parmi `public`/`network`/`private`)
* **`books`, `book_holdings`, `exemplares`, `authors`, `book_authors`** : lecture anonyme cascadée via `fn_library_visible_to_caller(library_id)` (durci 02/05 et 05/05)
* **`library_commons`** : lecture publique via visibility, écriture staff via `user_has_library_staff_role` (UPDATE policy ajoutée 05/05)
* **`user_library_memberships`** : seule policy SELECT (lecture de ses propres memberships). Toutes mutations via RPC SECURITY DEFINER
* **`auth_rate_limits`** : RLS activée mais **aucune policy** — accès uniquement via service_role (intentionnel)
* **Tables painel et catalogacao** : policy unifiée via vue `api.my_access` qui consolide les permissions

### 5.6. Triggers

**52 triggers actifs** (échantillon analysé) répartis en :

* **Touch updated_at** : 25+ triggers `BEFORE UPDATE` qui mettent à jour `updated_at`
* **Synchronisation** : `sync_book_native_provenance_bridge`, `sync_book_catalog_context_from_marc_json`, `sync_profile_is_librarian_from_memberships`, `sync_primary_membership_role_from_profile_flag`
* **Notifications de circulation** : `trg_notify_emprestimo_lifecycle`, `trg_notify_emprestimo_prorrogacao`, `trg_notify_reserva_workflow`
* **Notifications inter-bibliothèques** : `trg_interlibrary_loan_enqueue_notifications`, `trg_document_permission_request_notifications`
* **Notifications library_requests** : `trg_library_requests_notify`
* **Auto-dispatch** : `trg_auto_dispatch_task_invitation_outbox`, `trg_auto_dispatch_task_notification_outbox`
* **Painel tasks** : 4 triggers (fill_owner, touch, enqueue notifications, sync invites)

### 5.7. pg_cron

|#|Cron|Fréquence|Statut|
|-|-|-|-|
|1|`notify-mid-loan-reading`|quotidien 9h05|✅ actif|
|2|`notify-weekly-report`|lundi 8h|✅ actif|
|3|`notify-network-weekly-report`|lundi 8h15|✅ actif|
|5|`refresh_mv_books_catalog_list_v1`|toutes les 15 min|✅ actif|
|6|`fn_notify_users_before_purge`|dimanche 2h|⚠️ **inactif**|
|7|`fn_purge_expired_data`|dimanche 3h|⚠️ **inactif**|

> ⚠️ Les crons RGPD #6 et #7 sont **désactivés**. À auditer : volonté ou oubli ? Cf. §10.

### 5.8. Storage — 11 buckets

|Bucket|Public|MIME limité|Note|
|-|-|-|-|
|`anarbib-media-public`|✅|non|Media réseau|
|`anarbib-media-restricted`|❌|non||
|`anarbib-pdf-public`|✅|non|PDFs en accès libre|
|`pdf-restrito`|❌|non|PDFs en accès restreint|
|`authors`|✅|non|Photos auteurs|
|`covers`|✅|non|Couvertures de livres|
|`library-ui-assets`|✅|non|Assets UI per-library|
|`library-regimentos-public`|✅|non|Règlements publiés|
|`library-regimentos-private`|❌|non|Règlements en draft|
|`library-privacy-public`|✅|text/markdown, text/plain (512 KB)|Politiques RGPD|
|`catalogos_parceiros_raw`|❌|non|Imports bruts|

### 5.9. Indexes — top consommateurs

Les indexes les plus volumineux sont concentrés sur :

* **Recherche full-text** (`pg_trgm`) : `books.titulo`, `books.autor`, `books.editora` + équivalents sur `mv_books_catalog_list_network_v1`
* **Identification d'exemplaires** : `exemplares.bib_ref`, `exemplares.tombo`, `exemplares.library_id+bib_ref`
* **Cohérence book_holdings** : index unique `book_id+library_id`

Total des 30 plus gros indexes : ~6,7 MB. Volume très raisonnable pour 2 450 livres.

### 5.10. Extensions PostgreSQL installées

|Extension|Version|Rôle|
|-|-|-|
|`plpgsql`|1.0|Fonctions stockées|
|`pgcrypto`|1.3|Hash/chiffrement (claim tokens)|
|`pg_trgm`|1.6|Recherche full-text par similarité|
|`unaccent`|1.1|Normalisation accents (recherche)|
|`uuid-ossp`|1.1|Génération UUID|
|`pg_cron`|1.6.4|Tâches planifiées|
|`pg_net`|0.20.0|HTTP depuis SQL (webhook → Edge)|
|`supabase_vault`|0.3.1|Secrets DB (anon key cron)|
|`pg_stat_statements`|1.11|Monitoring requêtes|
|`hypopg`|1.4.1|Hypothetical indexes (perf tuning)|
|`index_advisor`|0.2.0|Recommandation d'indexes|

---

## 6. Edge Functions

### 6.1. Liste des 19 fonctions déployées

|Fonction|Déployée il y a|Déploiements|Catégorie|
|-|-|-|-|
|`bn_isbn_lookup`|1 mois|22|Lookup catalogue externe|
|`catalog_metadata_lookup`|16 jours|7|Lookup catalogue externe|
|`fetch-url-metadata`|13 jours|6|Métadonnées URL|
|`login`|**3 heures**|1|Auth (créée 05/05)|
|`login-with-identifier`|8 jours|7|Auth|
|`mail-i18n-test`|8 jours|6|Test mail|
|`notify-document-permission-request`|1 mois|8|Notification|
|`notify-event`|1 mois|34|**Hub notification**|
|`notify-interlibrary-loan`|25 jours|6|Notification|
|`notify-internal-task`|1 mois|27|Notification|
|`notify-library-request`|1 mois|25|Notification|
|`notify-mid-loan-reading`|1 mois|8|Notification cron|
|`notify-network-weekly-report`|1 mois|17|Rapport hebdo|
|`notify-weekly-report`|1 mois|18|Rapport hebdo|
|`probe-partner-catalog`|1 mois|19|Catalogues partenaires|
|`process-partner-catalog-import`|1 mois|28|Catalogues partenaires|
|`read-digital-asset`|1 mois|15|Lecture asset signée|
|`read-pdf`|2 mois|25|Lecture PDF restreinte|
|`register`|1 mois (dernier deploy il y a 11h)|66|Création de compte|

### 6.2. Code source disponible

> ⚠️ **Anomalie détectée** : le dépôt `supabase/functions/` ne contient que **3 dossiers** (`_shared/`, `login/`, `notify-event/`, `register/`) alors que **19 fonctions** sont déployées en prod.
>
> Il y a donc **15+ Edge Functions déployées dont le code source n'est pas dans le dépôt**. C'est un problème de traçabilité majeur. Hypothèses : (a) le code a été développé directement dans le dashboard Supabase et jamais récupéré ; (b) les fonctions sont dans un autre repo ; (c) le `.gitignore` exclut certains dossiers. À auditer.

### 6.3. Modules partagés `supabase/functions/_shared/`

Architecture modulaire bien organisée :

* `core/` : `dispatch.ts`, `env.ts`, `webhook.ts` — boilerplate de base
* `mail/` : `layout.ts` — gabarits HTML mail
* `transport/` : `email.ts` — envoi via Brevo
* `i18n/` : `mail-strings.ts` (944 lignes) + tests Deno
* `data/` : `reservas.ts`, `emprestimos.ts` — accès BDD
* `domain/` : `profiles.ts`, `reservas.ts`, `emprestimos.ts`, `legacy.ts` — logique métier
* `context/` : `library-mail-routing.ts`, `library-notification-context.ts`, `policies.ts` — résolution des règles d'envoi par biblio
* `shared/` : `payload.ts`, `format.ts`, `events.ts`, `branding.ts`

### 6.4. Doublon login/login-with-identifier

> ⚠️ **À investiguer** : `login` (créée aujourd'hui) et `login-with-identifier` (déployée il y a 8 jours) coexistent. Le frontend appelle `supabase.functions.invoke('login')` (vérifié dans `LoginPage.jsx`). La fonction `login-with-identifier` est-elle code mort ? À vérifier en session reposée.

### 6.5. Secrets configurés (~75)

L'inventaire des secrets configurés (sans valeurs) liste **75 noms**, organisés en familles :

* **Branding par tenant** : 7 entrées par tenant (ANARBIB_, BLMF_, BTL_, NETWORK_) × ~7 = ~30 secrets
* **Brevo** : 5 clés API distinctes (différenciées par usage : transactionnel, notifications, internal_task, reserva, staging)
* **Supabase auto-injectés** : URL, anon_key, service_role, JWKS, vault keys
* **Webhook secrets** : 6 secrets différents (notify-event, notify-internal-task, notify-library-request, notify-mid-loan, notify-weekly-report, notify-network-weekly-report, notify-document-permission-request)
* **Sécurité** : `TURNSTILE_SECRET_KEY` (ajouté 05/05), `ANARBIB_PARTNER_IMPORT_SECRET`
* **Configuration** : timezone, TTL signed URL, etc.

> ⚠️ **Incohérence à investiguer** : certains secrets ont un digest qui correspond à une chaîne vide (`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` est le SHA-256 d'une chaîne vide). C'est le cas de plusieurs `_BLMF_INTERNAL_REDIRECT_EMAIL`, `BTL_INTERNAL_REDIRECT_EMAIL`, `BRAND_NAME`, `LIBRARY_*` et autres. Ces secrets sont **vides en prod**. Voulu (placeholders) ou bug ?

---

## 7. Sécurité

### 7.1. État au 05/05/2026 — backlog vidé

Tous les items de sécurité ouverts au début de la session ont été résolus :

|Item|État|Commit|
|-|-|-|
|Patches `digital_asset_*_v2`|✅ Déjà fixé 02/05|(pré-existant)|
|Fuites `v_book_detail_public_v2`|✅ Déjà fixé 02/05|(pré-existant)|
|Reload-au-focus AccountPage|✅ Déjà fixé 02/05|bfbaf74, 039af1e|
|RLS `library_commons` UPDATE|✅ Ajouté 05/05|80ff5ec|
|RLS `books_public_read` cascade visibility|✅ Durci 05/05|2f4d9e5|
|Rate limiting login|✅ Implémenté 05/05|5f68693|
|Cloudflare Turnstile sur login|✅ Implémenté 05/05|ceb8f6e|
|Fallback hardcodé anon_key|✅ Retiré 05/05|e9d8fae|

### 7.2. Mécanismes de défense

* **RLS partout** (84/84 tables)
* **Helpers de permission centralisés** (4 fonctions principales : `user_has_library_staff_role`, `user_can_manage_library`, `fn_library_visible_to_caller`, `fn_current_user_is_member_of`)
* **Cascade de visibilité catalogue** : un livre n'est visible que si au moins un `book_holding` pointe vers une biblio visible pour le caller
* **SECURITY DEFINER avec `search_path` figé** : pattern uniformisé sur les RPCs sensibles
* **Webhook secrets** dédiés par Edge Function (impossibilité de cross-pollination)
* **Vault Supabase** pour stocker les anon keys utilisées par pg_cron
* **Cloudflare Turnstile** sur la connexion (managed challenge)
* **Rate limiting login** : IP (10 échecs/15 min → blocage 1h) + email (5 échecs/30 min → blocage 1h)
* **Messages d'erreur génériques** sur login (anti-énumération)

### 7.3. Mécanismes RGPD

* Buckets storage publics/privés bien séparés
* `library_retention_policies` : politique de rétention configurable per-library
* `fn_export_my_data` : export RGPD JSON complet du compte (DataExportButton)
* `fn_delete_my_account` : auto-suppression du compte
* `library-privacy-public` bucket : politiques RGPD par biblio publiables
* Pages de politique de confidentialité dans le frontend
* DPA disponibles dans `docs/legal/` × 6 locales (`dpa-pt-BR.md`, `dpa-fr.md`, etc.)
* `INCIDENT_RESPONSE.md` et `REGISTRE_TRAITEMENTS.md` également documentés

> ⚠️ **MAIS** : les crons RGPD (notification J-30 avant purge + purge effective) sont **désactivés en prod** (cf. §5.7). Il y a un décalage entre l'outillage RGPD documenté et son fonctionnement effectif.

### 7.4. Recommandations sécurité résiduelle

* **Auditer les fonctions SECURITY DEFINER** restantes (volume non quantifié, cf. zone grisée §5.4)
* **Vérifier les secrets vides** signalés au §6.5
* **Décider du sort des crons RGPD désactivés** (cf. §10)
* **Auditer le doublon login/login-with-identifier** (cf. §6.4)

---

## 8. Internationalisation

### 8.1. Architecture i18n

* **6 locales** : pt-BR (référence), fr, es, en, it, de
* **Fichiers** : `src/i18n/locales/{locale}.json`
* **Volumétrie** :

|Locale|Clés|
|-|-|
|pt-BR|1 752|
|fr|1 752|
|en|1 771|
|es|1 765|
|it|1 770|
|de|1 770|

**Total** : ~10 580 chaînes traduites. Excellente couverture.

> ⚠️ Note : pt-BR et fr ont 1 752 clés, les autres entre 1 765 et 1 771. Léger écart (~20 clés) à investiguer en session dédiée — peut-être des clés héritées non purgées.

### 8.2. Conventions militantes par locale

Chaque locale respecte une **convention typographique militante** propre, validée par Xavier :

* **pt-BR** : forme triple `o/a/e`, démonstratifs binôme `dest(e/a)`, contractions article-préposition triples `d(o/a/e)`
* **fr** : point médian (`lecteur·rice`, `le·la`)
* **es** : neutre argentin `e` (`le`, `les`, `une`, `conectade`), participes accordés
* **en** : neutre standard (épicène)
* **it** : `compagno/a/e` ou variantes — **JAMAIS** `camerata`/`camerati` (terme fasciste)
* **de** : Genderstern (`Leser*in`, `Genoss*in`) — **JAMAIS** `Compas`

### 8.3. i18n des mails (Edge Functions)

Indépendant du frontend : `supabase/functions/_shared/i18n/mail-strings.ts` (944 lignes), avec ses propres tests Deno (`mail-strings.test.ts`).

100 clés × 6 locales = **600 chaînes** dédiées aux mails transactionnels.

---

## 9. Documentation

### 9.1. Manuel utilisateur·rice

`docs/manual.md` (146 lignes) — guide général.

### 9.2. Specs fonctionnelles commitées

|Spec|Lignes|Date|
|-|-|-|
|`spec-gouvernance-roles.md`|1 230|05/05/2026|
|`spec-migration-compte.md`|939|03/05/2026|
|`spec-validation-physique.md`|775|(avant 05/05)|
|`spec-onboarding-biblioteca.md`|606|(avant 05/05)|
|`spec-workflow-reservation.md`|792|(avant 05/05)|

**Total** : 4 342 lignes de spécifications fonctionnelles. Très substantiel.

> ⚠️ Trois specs (`validation-physique`, `onboarding-biblioteca`, `workflow-reservation`) sont commitées mais leur **statut d'implémentation** n'a pas été audité dans cette v0.1. À documenter en session dédiée.

### 9.3. Documentation légale RGPD

`docs/legal/` :

* `INCIDENT_RESPONSE.md`
* `REGISTRE_TRAITEMENTS.md`
* `README.md`
* `dpa-pt-BR.md`, `dpa-fr.md`, `dpa-es.md`, `dpa-en.md`, `dpa-it.md`, `dpa-de.md`

### 9.4. README.md

Présent à la racine du dépôt (12 KB). Contenu non audité dans cette v0.1.

---

## 10. Dette technique identifiée

Liste des points relevés pendant l'audit :

### 10.1. Hygiène base de données

* **3 tables `_backup_*_20260408`** traînent depuis le 8 avril 2026 (un mois). À supprimer après vérification qu'elles ne sont plus consultées.
* **Table `book_authors_backup_suspect_mono`** : autre backup d'opération de fix `book_authors`. Idem.

### 10.2. Crons RGPD désactivés

* `fn_notify_users_before_purge` (cron #6) et `fn_purge_expired_data` (cron #7) sont **désactivés**. Le code existe en BDD, le programme existe dans `cron.job`, mais `active=false`.
* **Trois options** : (a) les réactiver après audit du comportement réel ; (b) les supprimer si l'approche RGPD a changé ; (c) les laisser désactivés mais documenter pourquoi.

### 10.3. Edge Functions non versionnées

* **15+ Edge Functions déployées** dont le code source n'est pas dans `supabase/functions/` du dépôt git. Risque majeur de perte de traçabilité.
* Action : exporter via `supabase functions download <name>` toutes les fonctions manquantes et les commiter.

### 10.4. Doublon login

* `login` et `login-with-identifier` coexistent. Code mort potentiel.

### 10.5. Secrets Edge Functions vides

* ~10 secrets ont un digest correspondant à une chaîne vide. À auditer (placeholders légitimes ou oubli ?).

### 10.6. Performance frontend

* Custom fonts (titre.ttf 1 MB, accent.ttf 484 KB) chargées via `theme.js` sans preload, en concurrence avec Supabase au premier chargement (~30s de Content Download observés). Pistes : `preconnect` Supabase dans `index.html`, lazy-load des fonts d'affichage après la font d'interface, `font-display: swap`.

### 10.7. UX résiduelle

* `must_change_password` wiring à investiguer
* `profiles.email` vs `auth.users.email` : divergences possibles
* Bug SPA `document.title` : ✅ **corrigé 05/05**, mais le bug reload-au-focus (avant fix 02/05) avait masqué celui-ci

### 10.8. Zones grisées de cet audit

* **Cartographie complète des fonctions PL/pgSQL** (au-delà des 100 retournées)
* **Inventaire des RLS policies** (au-delà des 100 retournées par le bloc D)
* **Audit du frontend.zip** : seul l'inventaire structurel a été fait, pas la qualité du code, pas les warnings ESLint, pas les routes effectivement protégées
* **Tests** : présence de `tests/` et de `vitest`, mais couverture non mesurée
* **Specs `validation-physique`, `onboarding-biblioteca`, `workflow-reservation`** : commitées mais statut d'implémentation non audité
* **Inventaire des chaînes i18n inutilisées** (orphelines)

---

## 11. Roadmap

### 11.1. Spécifications cadrées et à implémenter

Avant Bologna sept 2026 :

1. **Spec gouvernance des rôles** (commitée 05/05) — implémentation en 7 lots planifiés dans la spec elle-même
2. **Spec validation physique** (commitée) — implémentation
3. **Spec onboarding bibliothèque** (commitée) — implémentation
4. **Spec workflow réservation** (commitée) — corriger les mails 4b/5/6 cassés et l'événement `retirada_efetivada` manquant
5. **Spec migration de compte** (commitée 03/05) — implémentation

### 11.2. Spécifications à rédiger

* **`spec-administrador-anarbib.md`** (renvoyée par §13.4 de la spec gouvernance) — modalités collégiales du rôle administrador AnarBib
* **`spec-invitation-equipe.md`** — workflow d'invitation par mail des membres staff sans compte préalable

### 11.3. Chantiers techniques résiduels

* Récupération du code source des Edge Functions manquantes (cf. §10.3)
* Audit du doublon login (cf. §10.4)
* Décision RGPD crons (cf. §10.2)
* Performance frontend (cf. §10.6)
* Nettoyage des tables backup (cf. §10.1)

### 11.4. Chantiers fonctionnels reportés

* Module de catalogage avancé (`CatalogacaoPage` 22 KB + `BookDraftForm` 105 KB) à enrichir
* Endpoint OAI-PMH pour le harvesting du catalogue par d'autres SIGB du réseau
* Formulaire d'adhésion en ligne (workflow complet)

### 11.5. Audit à conduire

* **Livre Blanc v1.0** : reprise de ce document avec audit exhaustif des fonctions PL/pgSQL, RLS policies, Edge Functions et tests
* **Audits fonctionnels** : `/importações`, `/biblioteca`, `/painel`, `/conta` (reportés après implémentation validation physique)

---

## 12. Zones grisées

Récapitulatif des éléments **non audités ou audités partiellement** dans cette v0.1, à reprendre en session dédiée :

|Domaine|Statut|Priorité|
|-|-|-|
|Cartographie complète des fonctions PL/pgSQL|partielle (100/?)|moyenne|
|Liste exhaustive des RLS policies|partielle (100/?)|moyenne|
|Code source des Edge Functions hors `_shared/login/notify-event/register`|absent du dépôt|**haute**|
|Doublon login/login-with-identifier|non investigué|**haute**|
|Secrets Edge Functions vides|non investigué|moyenne|
|Statut d'implémentation des 5 specs commitées|non audité|moyenne|
|Couverture de tests|non mesurée|basse|
|Comportement des crons RGPD désactivés|non décidé|moyenne|
|Audit qualité du frontend (ESLint, accessibilité, performance)|non fait|basse|
|Audit i18n des clés orphelines|non fait|basse|

---

## Annexe — Glossaire

* **AnarBib** : nom du SIGB. Aussi nom de la communauté/projet.
* **BLMF** : Biblioteca Libertária de Música e Filosofia (Belém do Pará). Bibliothèque pilote.
* **RebAL** : Réseau de Bibliothèques Alternatives Libertaires.
* **SIGB** : Système Intégré de Gestion de Bibliothèques.
* **PEB** : Prêt entre bibliothèques (interlibrary loan).
* **`api.*`** : schéma PostgreSQL exposant les vues et fonctions accessibles depuis le frontend.
* **`public.*`** : schéma PostgreSQL contenant le modèle physique.
* **RLS** : Row Level Security (policies de sécurité PostgreSQL au niveau ligne).
* **MV** : Materialized View (vue matérialisée).
* **Codeberg** : forge git non-marchande, hôte principal du projet.
* **FICEDL** : Fédération Internationale des Centres d'Études et de Documentation Libertaires.

---

*Fin du document. Version 0.1 — sera enrichie en session dédiée.*

