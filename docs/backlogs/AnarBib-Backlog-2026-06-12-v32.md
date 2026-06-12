# AnarBib — Backlog technique **v32** (mise à jour 2026-06-12)

> **Pourquoi v32.** Reporte le **v31** au **12/06** : livraison de la **détection +
> comparaison + fusion de doublons en file éditoriale** (catalogage) — cf. §0 ; **v31
> (11/06 soir) archivé**. *Historique v31 :* Le **v30** (10/06) reste la base vérifiée en prod. Ce **v31** le
> reporte au **soir du 11/06** : une grosse session a livré le **CI auto-hébergé**,
> les **notifications §21 PARTNER**, un **snapshot de schéma de référence**, et a
> **soldé/clarifié** plusieurs reliquats multi-sessions (tour des sessions archivées
> + audit de drift schéma). Règles inchangées : **REGISTRE > spec > backlog** ; ce
> document porte l'**état** et les **priorités**, ce qui fait doctrine est au REGISTRE.
>
> **Cutoff de vérification** : prod ≈ **320 migrations**, max `20260611184337`
> (11/06 ~18:43 UTC). 21+ Edge Functions actives. Tout ✅ est **constaté**
> (migration appliquée / RPC `api.*`·`public.*` / EF / table / cron / fichier front),
> pas déduit. Trois niveaux : **✅ vérifié prod** · **🟢 vérifié front+back** ·
> **⚠️ backend seul** (UX/terrain non audité).

---

## 0. Nouveautés depuis v30 — sessions des 11–12/06

### Catalogação — détection & fusion de doublons en file éditoriale (12/06) ✅ 🟢
- **Détection + comparaison** : `api.suggest_draft_duplicates(p_draft_id)` + modale
  `DuplicateCompareModal` — bouton « Doublons » par brouillon, comparaison côte-à-côte des
  **9 champs cruciaux** (diffs surlignées), candidats = autres brouillons **même biblio** +
  **catalogue publié** (pg_trgm + `fn_normalize_name`). *(`20260612010421` ; cc0a3a6/b99f255.)*
- **Fusion** (arbitrage **champ-par-champ**, journalisée `merge_log`, `entity_type` élargi à
  `book_draft`) : `api.merge_draft_into_book` (brouillon → fiche publiée : enrichit la fiche des
  champs repris, absorbe le brouillon en **corbeille**) et `api.merge_book_drafts` (brouillon →
  brouillon **même biblio**). *(`20260612074558` ; a2279bf3 + correctif sens `4d8883f4`.)*
- **Erreurs traduites** : HINT `error.merge.*` ×10 via `localizeError` (zéro PT brut côté usager·ère).
  *(`20260612125517`.)*
- **Conséquences backlog** *(règle d'or piège #12)* :
  - **#152 proches-doublons** (§2.4) : **facette catalogage/staff LIVRÉE** ; la facette **OPAC
    lecteur·rice** (signaler des proches-doublons côté public) **reste ouverte**.
  - **Exemplaires** : la fusion est **bibliographique**. Le **détrompage / rattachement
    d'exemplaires** à une fiche publiée est déjà couvert par l'**import**
    (`fn_import_reconcile_duplicates` → `exemplar_draft` sur le livre canonique) — **pas de
    double mécanisme** ; le draft↔draft repointe au mieux par `bib_ref` (best-effort).
  - **#OPAC4** (`api.similar_books` existant) : socle de similarité **partagé** (pg_trgm).

### Infra CI — refonte complète ✅ *(11/06)*
- **Woodpecker → Forgejo Actions** (`.forgejo/workflows/ci.yml`, **2 jobs** `app`/`backend`,
  `backend: needs app`). Woodpecker hébergé (~22 % uptime) retiré.
- **Runner auto-hébergé** `anarbib-local` (act_runner v12.10.2 sur le **WSL2** de Xavier,
  service **systemd**) — gratuit, **~3 min/run**, plus de limite ~5 min des runners
  mutualisés. Runbook : `docs/journal/operations/SETUP_runner_wsl2_2026-06-11.md`.
- **retry-Pages** (3 tentatives) : absorbe les **HTTP 504 transitoires** de Codeberg sur
  le push lourd de la branche `pages`.
- Miroir GitHub = **dual-push `origin`** (plus d'étape CI ; Codeberg bloque les miroirs natifs).
  `CLAUDE.md` réaligné sur tout ça.

### §21 PARTNER — notifications livrées en prod ✅ 🟢
- **NOTIF-1** coordenador : `fn_partnership_propose/accept/refuse/break` → mail au contact de
  la biblio concernée. *Validé en prod (BLMF a reçu l'accept de la BTL).*
- **NOTIF-2** transparence activée → **fan-out aux lectrices communes** des 2 biblios → invite
  à consentir (`/conta`, `MyPartnershipsConsentSection`). *Validé.*
- **NOTIF-3** config élargie → **re-sollicite uniquement les consentements stale**
  (`reader_partnership_consent`, version < courante).
- Handler `_shared/domain/partnership.ts` + 16 clés mail i18n ×10. Migrations
  `20260611120340` / `153423` / `164859`. *(Débloqué par le déploiement de `notify-event` via le CI.)*

### Identité lecteur·rice (session dédiée) ✅
- **CARD-LOCAL Lot 0** déployé (`20260611183911`) : `libraries.reader_identity_model` /
  `reader_validation_mode`, `user_library_memberships.imported_from_legacy`, unicité de
  l'identité locale par **trigger conditionnel** (modèles numériques, statuts vivants).
  Suite **N1→N5** (dont N4 mail réconciliation UUID↔identité) **en cours** dans cette session.

### Import 🟢
- `fn_import_delete_run` (`20260611184337`) — suppression d'un run d'import + son fichier storage
  (CASCADE enfants). Coordenador-only, scopé biblio.

### Dette technique & reproductibilité 🔎
- **Audit de drift schéma** (prod vs `migrations/`) : `supabase/migrations/` est **incrémental** —
  le **socle fondateur** (tables `books`/`authors`/`profiles`/`libraries` + ~150 fn/vues) a été
  créé **hors migrations** (projet/prototype initial). → **`supabase db reset` ne reconstruit pas**
  la base (reproductibilité partielle). Fait architectural connu, pas un oubli.
- **✅ Mitigation** : **snapshot de schéma de référence** versionné —
  `docs/schema/baseline_schema_2026-06-11.sql` (DDL `public`/`api`/`ingest`, ~2 Mo ; cf.
  `docs/schema/README.md`). Assurance reprise-après-sinistre.
- **Reste (gros, non urgent)** : un **squash** (baseline horodaté en tête de `migrations/` +
  archivage des incréments) pour rendre `db reset` reproductible de bout en bout.
- Drift d'objet confirmé : `mv_books_catalog_list_v1` (MV publique, hors migration —
  cf. mémoire `catalog-mv-project-location`).

### Reliquats multi-sessions tranchés (tour des 12 sessions archivées)
- ✅ **« à pérenniser »** = **faux positif** : le scoring `api.similar_books` (LIMIT 16 + sujets)
  était **déjà persisté** dans `20260609204931_persist_similar_books_scoring_v4.sql` (06-09).
  Prod == migration → aucune perte.
- ✅ **#CL.10** = **déjà fait** : `libTag` + `sameTitleSignal` dans `ReservationCard.jsx` /
  `AccountPage.jsx` (tag biblio d'origine + signal « même titre » ; i18n `account.circ.sameTitleSignal`).
- ⚪ **Cosmétique** : `loansCreated30d` **ajouté** à la grille de chiffres (`trocasActive` déjà présent).
- 🟡 **EA-12 ph.2** (parité PEB, ~45 fn JS) — **gelé** par décision **REGISTRE BIBLIO-9**,
  conditionné à un besoin prod réel BLMF↔BTL : **laisser**.
- 🟡 **#OPAC11 RSS/courriel** — **différé anti-tracking** : laisser.

---

## 1. Macro-chantiers — statuts vérifiés (report du v30, MàJ 11/06)

| # | Macro-chantier | Statut **vérifié** | Base |
|---|---|---|---|
| 1 | #BIBLIO | ✅ Clos | RPC biblioteca, `get_library_*_ui` |
| 2 | #PAINEL | ✅ Clos | api circulation complète |
| 3 | #IMPORT | ⚠️ **Phase 1 backend livrée** ; UX à auditer (+ `fn_import_delete_run` 11/06) | 16+ `fn_import_*` + 3 EF |
| 4 | #CL (carte-lecteur / appartenance) | ✅ Clos (+ **CARD-LOCAL Lot 0** 11/06, suite N1-N5 en cours) | api memberships, reader_card, reader_identity_model |
| 5 | #CATALOGACAO | ✅ Bouclé (Phase 1-3 + Tracks A/B/C/D) | migrations P1.* + EF |
| 6 | #110 mail (Resend) | ✅ Clos | EF Resend |
| 7 | #MOBILE | 🟡 **Réellement ouvert** (hors carte-lecteur ✅) | aucun SW/scanner en `src` |
| 8 | #NOTIFY-Painel-acts | ✅ Livré | `fn_record_membership_payment` + notifs |
| 9 | #COTISATIONS | 🟡 **Partiel** : moteur ✅, #25/#33/#36 ouverts | `membership_payments`, pas de cron expiration |
| 10 | #MM (mouvement/comm) | 🟡 **Réellement ouvert** | aucune trace conversemos/banner en `src` |
| 11 | #FED (fédéralisme) | 🟡 **Réellement ouvert** (spec + crons gouvernance seulement) | aucune table/fn círculo |
| 12 | #MODEL | ✅ specs implémentées (multi-appart., partenariat, PEB, ILL-digital) | voir §0 + v30 §B |
| 13 | #BG-PREP (Bologne/sécurité) | 🟠 En cours (durcissement continu) | advisors à re-sonder |
| 14 | #CATALOG-EXT (OPAC) | 🟡 **Partiel avancé** : OPAC7/8 ✅, longue traîne ouverte | api facets/subjects/similar |
| 15 | #HYGIENE-PERF-i18n | 🟡 Partiel : REG-1/ui-assets/INDEX-locales ✅ ; i18n rollout + INVENTAIRE à finir | — |
| — | **#CI / infra** | ✅ **Refondé 11/06** (Forgejo + runner auto-hébergé + retry-Pages) | `.forgejo/`, runbook |
| — | **#PARTNER notifications** | ✅ **Livré 11/06** (NOTIF-1/2/3) | `partnership.ts`, migrations notif |

> **§21 PARTNER (spec partenariat)** : backend P1→P6 + **notifications NOTIF-1/2/3** désormais
> livrés. Reste l'**audit UX bout-en-bout** des deux côtés biblio (cf. §4 Réserves).

---

## 2. Backlog réel — ce qui reste vraiment (priorisé)

> Dégraissé de tout ce qui est livré. Les **vrais** chantiers ouverts.

### 2.1 — Frontend / terrain (le gros du reste)
- **#MOBILE** — `P0` socle PWA (aucun service worker en prod), `P2` scanner ISBN (aucun
  `BarcodeDetector`/lib en `src`), `P3` permanence, `P4` récolement, `P5` push,
  `#MOB-QR-A4` (retouche A4 carte-lecteur). *Carte-lecteur β+γ = ✅.*
- **#MM** — `MM1` banner G, `MM2` footer global staff, `MM3` encadrés Biblioteca,
  `MM4` page `/conversemos`, `MM5` bandeau SolicitarBiblioteca. **Aucun** livré.
- **#FED** — socle page « Ferramentas federalistas » + primitive `círculo` : **aucune**
  table/RPC/écran en prod (seuls la spec v0.1 et les crons de gouvernance réseau existent).

### 2.2 — Cotisations (moteur livré, finitions ouvertes)
- **#25** notifications d'expiration cotisation 7 j / 1 j / J — **aucun cron** d'expiration → **ouvert**.
- **#33** test scénario blocage emprunt par cotisation expirée — probable ouvert.
- **#36** activation CIRA Marseille — config/donnée, à confirmer.
- **#22** `fn_submit_library_request_via_claim` COALESCE — trivial, statut à vérifier.

### 2.3 — Sécurité / Bologne (durcissement continu)
- **#BG4** durcissement RLS/advisors (**re-sonder l'état advisor** — bougé depuis le 05/06),
  **#BG2** sauvegardes, **#BG3** journalisation, dettes **STR-2..5**, **#4** doc `SECURITY DEFINER`,
  **#119** secrets, **#79** RBAC catalogage (8 fn sans garde — à re-vérifier).
- *(Nouveau, lié au baseline)* : envisager le **squash migrations** pour la repro complète (non urgent).

### 2.4 — OPAC / découverte (longue traîne)
- Livrés : **#OPAC7** facettes, **#OPAC8** sujets (front+back).
- Ouverts : favoris/wishlist `#OPAC9`, parcours `#OPAC10`, **`#OPAC11` RSS (différé anti-tracking)**,
  tags `#OPAC5`, similaires UI `#OPAC4` (NB : `api.similar_books`/`similar_authors` **existent** →
  surface backend prête), description `#OPAC6`, auteur·rices `#AUT1-4`, `#61` date limite de retrait,
  `#58`/`#62` refonte/filtres, `#152` proches-doublons *(facette catalogage **livrée 12/06**, cf. §0 ; facette OPAC ouverte)*.

### 2.5 — i18n / hygiène
- **#I18N-rollout-10** : tutoiement 9 locales restantes + nl/el dans l'UI React.
- **#I18N-charte-inclusive** : clés non conformes (audit récent à confirmer).
- **#I18N-sujets** : thésaurus sujets traduit `pt-BR/fr/es/en` seulement ; autres locales en
  fallback (« à compléter au fil de l'eau »).
- **#PERF-accountpage-split** : AccountPage en onglets lazy → probablement fait, à confirmer.

### 2.6 — Reliquats cosmétiques / différés conscients
- ⚪ Cosmétiques **soldés** 11/06 (`loansCreated30d`, `trocasActive`).
- 🟡 **EA-12 ph.2** (parité PEB ~45 fn) — gelé (BIBLIO-9), prod-gated. **Ne pas rouvrir** sans besoin réel.
- 🟡 **#OPAC11 RSS** — différé anti-tracking.

---

## 3. Dérive documentaire à résorber (méta)
1. **`docs/backlogs/INDEX.md`** : annonçait « version courante v26/v29 » → **réaligner sur v31**
   (archiver v29/v30).
2. **`docs/specs/INVENTAIRE.md`** : statuts de specs périmés → passe de synchro dédiée.
3. **`docs/specs/INDEX.md`** : réaligné le 10/06.
4. **`CLAUDE.md`** : section CI **réalignée 11/06** (Forgejo + runner) ✅.
5. **`docs/backlogs/ETAT-AVANCEMENT-multisessions.md`** : trace de survey multi-sessions
   (reconstituée 11/06) — complément léger de ce backlog.

---

## 4. Réserves — ce que la base ne prouve pas
Les clôtures **⚠️ backend seul** (#IMPORT, PARTNER, PEB, ILL-digital) signifient que la
**surface backend tourne**, mais qu'aucun audit frontend/UX/terrain n'a été fait. Avant de
les graver « clos » au REGISTRE :
- **#IMPORT** : parcours complet source → harvest → revue éditoriale → promotion `book_drafts`
  utilisable par un·e non-spécialiste ? (RPC présentes ; UI à éprouver — c'est l'objet de la
  session import active.)
- **PARTNER** : cycle propose→accept→consentement→rupture **+ notifications** lisible côté UI
  des deux biblios ? (Backend + notifs livrés ; **UX à auditer**.)
- **PEB / ILL-digital** : parcours bout-en-bout testé sur un cas réel BLMF↔BTL ?

---

*Backlog v31 — 11 juin 2026 (soir). Report du v30 (base prod vérifiée `uflwmikiyjfnikiphtcp`)
+ livraisons de la session du 11/06 (CI auto-hébergé, notifications §21 PARTNER, baseline
schéma, reliquats tranchés). Remplace v30. Ce qui fait doctrine est au REGISTRE
(`../specs/REGISTRE_decisions.md`).*
