# AnarBib — Backlog technique **v30** (réécriture critique, 2026-06-10)

> **Pourquoi cette réécriture.** Le v29 (10/06) était **gravement désynchronisé**
> de la production : sa structure (tableaux macro, ordre de priorité, quick-wins,
> sous-tickets) reconduisait des statuts « à faire » sur des chantiers **livrés et
> déployés**, et se contredisait lui-même (fiches « clos » vs tableaux « en cours »).
> Ce v30 est **reconstruit depuis la réalité vérifiée en prod**, pas depuis le
> texte du v29.
>
> **Source de vérité de cette réécriture** = la base de prod `uflwmikiyjfnikiphtcp`
> (2675 livros / 2719 exemplares — l'instance servie par `app.anarbib.org`),
> croisée avec les migrations sur disque, l'inventaire des Edge Functions et le
> code frontend. **Préséance inchangée** : REGISTRE > spec > backlog. Ce document
> porte l'**état** et les **priorités** ; ce qui fait doctrine est au REGISTRE.
>
> **Cutoff de vérification** : prod à **309 migrations**, max `20260610120238`
> (≈ 12:02 UTC le 10/06). 21 Edge Functions actives. Tout ce qui est marqué
> ✅ ci-dessous a été **constaté en base/EF/code**, pas déduit du v29.

---

## A. Méthode

Chaque statut ✅ est **étayé** par un artefact constaté : nom de migration
appliquée, RPC `api.*`/`public.*` présente, Edge Function active, table, job
cron, ou fichier frontend. Les items réellement ouverts sont confirmés par
**absence** d'artefact (ex. aucun service worker → pas de PWA ; aucun cron
d'expiration de cotisation → #25 ouvert). Trois niveaux de confiance :

- **✅ Vérifié prod** : artefact backend constaté (le plus fiable).
- **🟢 Vérifié front+back** : artefact backend **et** câblage frontend constatés.
- **⚠️ Backend seul** : surface backend déployée, **UX/usage réel non audité** —
  à confirmer côté frontend/terrain avant clôture définitive.

> ⚠️ **Angle mort assumé.** La base prouve qu'une fonction *existe et est
> déployée* ; elle ne prouve pas qu'un parcours UX est *complet, testé et utilisé
> en vrai*. Les clôtures « backend seul » ci-dessous demandent une passe
> frontend/terrain. C'est la limite honnête de cet audit.

---

## B. Corrections majeures — v29 disait « à faire », c'est livré en prod

| Item v29 | Statut v29 | Réalité prod (étayée) | Conf. |
|---|---|---|---|
| **#CATALOGACAO Phase 1** (P1.1 migration mutualisée exemplares) | 🟢 PRÊT, « confirmer F.10 » | Migration `20260603073556_exemplares_provenance_destination` appliquée ; colonnes `circulation_policy`/`visibility`/`source_library` présentes ; **2719/2719 exemplares ont `circulation_policy` rempli** | ✅ |
| **P1.2** seed padrão + RPC édition | ⬜ après P1.1 | `20260603075434_p1_2_publish_exemplar_draft_destination_seed` ; `api.attach_exemplar`, `publish_exemplar_draft` en prod | ✅ |
| **P1.3** doublon fédéré `api.attach_exemplar` | ⬜ après P1.1 | `20260603140222_p1_3b_api_attach_exemplar` ; `api.attach_exemplar` présent | ✅ |
| **P1.4** filtre public `visibility` | ⬜ après P1.1-P1.2 | `20260603142749_p1_4a_filtre_public_visibility` + `20260608143145_catalog_exemplar_visibility_filter` | ✅ |
| **TRA-v3** fiche maquette v3 (aperçu live, jauge 3/3, hints) | 🟢 PRÊT « réf. design » | Visible en prod (capture 10/06) ; `BookDraftForm.jsx` rendu par registre | 🟢 |
| **Track A** (TRA-2c/3/4/5), **CAPAS-P1/2/3**, Track C/D | 🟠/🟡 mélangés | EFs `cover_lookup`, `authority_lookup`, `catalog_metadata_lookup` actives ; section E v29 (CAT-E8/C5/D5) le confirme | 🟢 |
| **CAT-E6** « circulation 3 valeurs » | 🟡 DIFFÉRÉ | `20260606114851_circulation_default_three_values` | ✅ |
| **#OPAC7** facettes (`api.catalog_facets_v1`) | 🟡 « aval » | `20260607225547_opac_catalog_facets_v1` ; `api.catalog_facets_v1` ; câblé `CatalogPage.jsx` | 🟢 |
| **#OPAC8** sujets (`api.search_subjects`, `author_subjects_v1`) | 🟡 RebAL | `20260608074214_opac_subjects_cataloging` ; RPC présentes ; câblé `CatalogPage` | 🟢 |
| **#IMPORT Phase 1** (surface api.* + mapping/dédup + UI) | 🟡 « IMP-A1/A2 à trancher, IMP-P1 ⬜ » | **16 RPC `fn_import_*`** (create/dispatch/harvest_oai/ingest/promote/register OAI+deposit/set_editorial/list_runs…) + EFs `process-partner-catalog-import`, `probe-partner-catalog`, `export-catalog-lote` ; tables `catalog_partners*`, `partner_source_*`, `catalog_ref_*` | ⚠️ |
| **spec-partenariat-biblios** (PARTNER) | 🟡 FIGÉE v0.3 | `fn_partnership_*` (propose/accept/refuse/break/consent/rights/sync/transparence) ; tables `library_partnerships`, `partnership_rights`, `reader_partnership_consent` ; migrations jusqu'à `20260610120238` | ⚠️ |
| **spec-cycle-vie-peb** (#ILL-lifecycle) | 🟡 « à venir » | **14 `fn_peb_*`** (create_loan_with_items, propagate/validate_status, archive, search_exemplares…) + `fn_v2_dispatch_emprestimo_interbibliotecas` + EF `notify-interlibrary-loan` | ⚠️ |
| **spec-flux-partage-numerique** (#ILL-digital) | 🟡 FIGÉE v0.2 | `digital_assets`, `book_digital_resources`, EF `read-digital-asset`, `notify-document-permission-request` + `fn_notify_document_permission_request_now` ; composants `library/Exchange*` | ⚠️ |
| **#NOTIFY-Painel-acts** | 🟡 CADRÉ (tableau B) | C.8 v29 le dit livré ; confirmé : `fn_record_membership_payment`, `api.restrict_member/freeze_account`, `fn_notify_lph/lpp/lpv` | ✅ |
| **#HYG-ui-assets** (migration `20260605170000`) | 🟢 « à déployer » (quick-win #1) | `20260605170000_scope_library_ui_assets_policies` **dans `schema_migrations`** (+ correctifs `20260608002842`/`20260608161818`) | ✅ |
| **#HYG-REG-1** réinscription §17-26 | 🟢 « préalable » (D.0 #4) | Intro + section E v29 : **soldé**. Tableaux non mis à jour | ✅ |
| **#BIBLIO** | 🟠 EN COURS (tableau B) | C.1 v29 : ✅ CLOS 08/06. RPC `get_library_*_ui`, `get_library_institutional_workspace` présentes | ✅ |
| Crons RGPD « désactivés » (section G) | désactivés | `anarbib-rgpd-notify-weekly` **et** `anarbib-rgpd-purge-weekly` **schedulés** dans `cron.job` (gardés par validation rétention biblio — à confirmer) | ⚠️ |

**Conséquence** : `#CATALOGACAO` n'est pas « 🟠 EN COURS » mais ✅ **bouclé en
prod** (Phase 1-3 + Tracks A/B/C/D + OPAC facettes/sujets). Les arbitrages
**F.6** (étape 8 déjà débloquée) et **F.10** (4 confirmations avant P1.1 — la
migration tourne) sont **caducs**.

---

## C. Macro-chantiers — statuts vérifiés (remplace le tableau B du v29)

| # | Macro-chantier | Statut v29 | Statut **vérifié** | Base |
|---|---|---|---|---|
| 1 | #BIBLIO | 🟠 EN COURS | ✅ Clos | RPC biblioteca + C.1 |
| 2 | #PAINEL | ✅ | ✅ Clos | api circulation complète |
| 3 | #IMPORT | 🟡 cadrage | ⚠️ **Phase 1 backend livrée** ; UX à auditer | 16 `fn_import_*` + 3 EF |
| 4 | #CL | ✅ 10/10 | ✅ Clos | api memberships + reader_card |
| 5 | #CATALOGACAO | 🟠 EN COURS | ✅ **Bouclé** (Phase 1-3 + Tracks) | migrations P1.* + EF |
| 6 | #110 mail | ✅ | ✅ Clos | EF Resend, pas de Brevo |
| 7 | #MOBILE | 🟡 | 🟡 **Réellement ouvert** (hors carte-lecteur ✅) | aucun SW/scanner en `src` |
| 8 | #NOTIFY-Painel-acts | 🟡 CADRÉ | ✅ Livré | `fn_record_membership_payment` + notifs |
| 9 | #COTISATIONS | 🟢 PRÊT | 🟡 **Partiel** : moteur ✅, #25/#33/#36 ouverts | `membership_payments`, pas de cron expiration |
| 10 | #MM | 🟡 CADRÉ | 🟡 **Réellement ouvert** | aucune trace conversemos/banner en `src` |
| 11 | #FED | 🟡 CADRÉ | 🟡 **Réellement ouvert** (spec + crons gouvernance seulement) | aucune table/fn círculo |
| 12 | #MODEL | 🟡 CADRÉ | ✅ **specs implémentées** (multi-appart., partenariat, PEB, ILL-digital) | voir §B |
| 13 | #BG-PREP | 🟠 EN COURS | 🟠 En cours (durcissement continu) | advisors à re-sonder |
| 14 | #CATALOG-EXT | 🟡 PARTIEL | 🟡 **Partiel avancé** : OPAC7/8 ✅, longue traîne ouverte | api facets/subjects/similar |
| 15 | #HYGIENE-PERF-i18n | 🟢 PRÊT | 🟡 Partiel : REG-1/ui-assets/INDEX-locales ✅, i18n rollout + INVENTAIRE à finir | — |

---

## D. Backlog réel — ce qui reste vraiment (priorisé)

> Dégraissé de tout ce qui est livré. Ce sont les **vrais** chantiers ouverts.

### D.1 — Frontend / terrain (le gros du reste)

- **#MOBILE** — `P0` socle PWA (aucun service worker en prod), `P2` scanner ISBN
  (aucun `BarcodeDetector`/lib en `src`), `P3` permanence, `P4` récolement,
  `P5` push, `#MOB-QR-A4` (retouche A4 carte-lecteur). *Carte-lecteur β+γ = ✅.*
- **#MM** — `MM1` banner G, `MM2` footer global staff, `MM3` encadrés Biblioteca,
  `MM4` page `/conversemos`, `MM5` bandeau SolicitarBiblioteca. **Aucun** livré.
- **#FED** — socle page « Ferramentas federalistas » + primitive `círculo` :
  **aucune** table/RPC/écran en prod (seuls la spec v0.1 et les crons de
  gouvernance réseau — cooptation, retrait collectif — existent).

### D.2 — Cotisations (moteur livré, finitions ouvertes)

- **#25** notifications d'expiration cotisation 7 j / 1 j / J — **aucun cron**
  d'expiration de cotisation dans `cron.job` → **ouvert**.
- **#33** test scénario blocage emprunt par cotisation expirée — opérationnel,
  non vérifiable en base (probable ouvert).
- **#36** activation CIRA Marseille — opérationnel (donnée/config), à confirmer.
- **#22** `fn_submit_library_request_via_claim` COALESCE — trivial, statut à vérifier.

### D.3 — Sécurité / Bologne (durcissement continu)

- **#BG4** durcissement RLS/advisors (re-sonder l'état advisor actuel — le compteur
  a bougé depuis le 05/06), **#BG2** sauvegardes, **#BG3** journalisation,
  dettes **STR-2..5**, **#4** doc `SECURITY DEFINER` (audit lent), **#119** secrets,
  **#79** RBAC catalogage (8 fn sans garde — **à re-vérifier** : non confirmé fait).

### D.4 — OPAC / découverte (longue traîne, aval livré en partie)

- Livrés : **#OPAC7** facettes, **#OPAC8** sujets (front+back). 
- Ouverts : favoris/wishlist `#OPAC9`, parcours `#OPAC10`, tags `#OPAC5`,
  similaires UI `#OPAC4` (NB : `api.similar_books`/`similar_authors` **existent**
  → surface backend prête), description `#OPAC6`, auteur·rices `#AUT1-4`,
  `#61` date limite de retrait (**créneaux + cron expiration existent → à
  confirmer si déjà couvert**), `#58`/`#62` refonte/filtres, `#152` proches-doublons.

### D.5 — i18n / hygiène

- **#I18N-rollout-10** : tutoiement 9 locales restantes + nl/el dans l'UI React.
- **#I18N-charte-inclusive** : 7 clés non conformes (audit séparé récent l'a peut-être déjà traité — à confirmer).
- **#PERF-accountpage-split** : la section E v29 dit AccountPage refactoré en
  onglets lazy → **probablement fait**, à confirmer.

---

## E. Dérive documentaire à résorber (méta)

1. **`docs/backlogs/INDEX.md`** annonce encore « version courante **v26** » (v27/v28
   en archive, v29 et ce v30 à la racine) → réaligner sur v30.
2. **`docs/specs/INVENTAIRE.md`** : statuts des specs périmés (entrées 🟡 cadrée pour
   des chantiers livrés) → passe de synchro dédiée (44 réfs vers les 9 specs
   archivées le 10/06).
3. **`docs/specs/INDEX.md`** : déjà réaligné le 10/06 (9 specs implémentées
   archivées). 
4. La **section G RGPD** du v29 (« crons désactivés ») est à corriger : les deux
   crons RGPD sont **schedulés** (gardés applicativement, à documenter précisément).

---

## F. Réserves — ce que la base ne prouve pas

Les clôtures **⚠️ backend seul** (#IMPORT, PARTNER, PEB, ILL-digital) signifient
que la **surface backend tourne**, mais qu'aucun audit frontend/UX/terrain n'a été
fait dans cette passe. Avant de les graver « clos » au REGISTRE :
- #IMPORT : la page Importações offre-t-elle un parcours complet (source → harvest
  → revue éditoriale → promotion en `book_drafts`) utilisable par un·e
  non-spécialiste ? (RPC présentes ; UI à éprouver.)
- PARTNER : le cycle propose→accept→consentement lectrice→rupture est-il câblé et
  lisible côté UI des deux biblios ?
- PEB / ILL-digital : parcours de bout en bout testé sur un cas réel BLMF↔BTL ?

Ces trois chantiers passent de « cadrés » à « **backend livré, parité UX à
auditer** » — un saut majeur par rapport au v29, mais pas une clôture aveugle.

---

*Backlog v30 — 10 juin 2026. Réécriture critique sur base prod vérifiée
(`uflwmikiyjfnikiphtcp`, 309 migrations, 21 EF). Remplace le v29 (désynchronisé).
Détail des preuves : [`AUDIT_backlog-v29-vs-prod_2026-06-10`](../journal/audits/AUDIT_backlog-v29-vs-prod_2026-06-10.md).
Ce qui fait doctrine est au REGISTRE.*
