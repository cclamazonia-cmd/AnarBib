# État d'avancement — backlog consolidé multi-sessions · 2026-06-11

> **Reconstitué le 11/06/2026** (le doc précédemment référencé en mémoire avait disparu).
> **Source** : croisement des transcrits des 12 sessions archivées (05→10/06) + audit de
> drift schéma (prod vs `supabase/migrations/`).
> ⚠️ **Trace vivante, non normative.** Le normatif = [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md).
> Une session « Error message clarity » (10/06) avait déjà constaté que l'ancien backlog
> était « massivement en retard sur sa réalité » → ne jamais traiter ce fichier comme une
> vérité d'état sans revérifier dans le code.

## ⚠️ Risque structurel — migrations INCRÉMENTALES, pas un schéma complet
L'audit drift (11/06) révèle que la base **ne se reconstruit PAS** depuis les migrations
seules : le **socle fondateur** (tables `books`, `authors`, `profiles`, `libraries`, … +
~150 fonctions/vues) a été créé **hors `migrations/`** (projet Supabase initial / prototype
mono-biblio du 18/03). Le dossier `migrations/` ne porte que **l'incrémental** depuis ce
socle.
- **Conséquence** : `supabase db reset` ne rejoue pas le socle → **reproductibilité partielle**.
- **Nature** : fait architectural connu, **pas un chantier oublié**.
- **✅ Mitigation (11/06)** : un **snapshot de référence** du schéma complet est désormais
  versionné — [`../schema/baseline_schema_2026-06-11.sql`](../schema/baseline_schema_2026-06-11.sql)
  (DDL `public`/`api`/`ingest`, ~2 Mo ; cf. `../schema/README.md`). Assurance reprise-après-sinistre.
  Reste à faire un jour (gros, non urgent) : un **squash** rendant `db reset` reproductible de bout en bout.
- **Drift récent confirmé** (objet créé en cours de route, hors migration) :
  **`mv_books_catalog_list_v1`** (MV publique du catalogue — cf. mémoire `catalog-mv-project-location`).

## ✅ Session « Perf UX + nettoyage advisors sécurité » (15-16/06) — livré

Bloc livré et **déployé en prod** (pipelines verts) au cours de cette session :

- **Sécurité advisors** : Lot 1 (REVOKE EXECUTE sur 14 fn trigger SECDEF), Lot 2
  (triage helpers internes surexposés), **fuite MV réseau fermée** (option C —
  wrappers déplacés en schéma `private` non exposé ; cf. mémoire
  `catalogue-anon-mv-publique`). ~28 advisors retirés du dashboard, confirmé.
- **MOBILE — scan & PWA** :
  - **P0 socle PWA** (manifest + service worker ; le SW ne cache **jamais** l'API).
  - **P2 scan carte-lecteur** (Painel › Leitor, `CardScanner` + `ResolveCardBox`)
    + message **`card_revoked`** clair (régénérer une carte révoque l'ancienne).
  - **P2b scan ISBN au catalogage** (code-barres EAN → `catalog_metadata_lookup`
    + `bn_isbn_lookup`). Repli **ZXing** universel (Brave/iOS/Firefox n'ont pas
    `BarcodeDetector`). Limite webcam desktop = matérielle (assumée).
  - **P4 récolement** (inventaire par scan) : backend persisté (4 RPC SECDEF
    staff) **+ UI** (onglet Painel « Récolement », scan **continu** des étiquettes
    QR, rapport présents/manquants/intrus, export CSV/PDF).
- **Onboarding** : case **« ne plus afficher »** rendue accessible **depuis la
  visite guidée Painel** (et à chaque étape du wizard catalogação) → l'opt-out
  permanent ne réapparaît plus à chaque connexion.
- **Doc du commun** : guide pt-BR scan/QR pour Rodrigo (BTL) →
  [`../guides/guide-scan-qr-pt-BR.md`](../guides/guide-scan-qr-pt-BR.md) (esprit
  charte relationnelle / entraide).

**Reste (non bloquant)** : audit d'archivage du corpus de specs (notamment
`spec-flux-partage-numerique` ⚠️→🔵 si la parité UX est confirmée) — curation à
mener avec Xavier. Perf TOP 2-5 (memo lignes catalogue, virtualisation) — backlog.

— *Session: Perf UX + nettoyage advisors sécurité*

## ✅ Session « Fédération — Communs & Entraide » (16/06) — livré

Bloc livré et **déployé en prod** (pipelines verts, branche `pages` vérifiée). Doctrine au **REGISTRE §30 `THES`** + **§24 `FED-O8/O9/O10`**.

- **Communs** : tous les docs Communs servis en **10 locales** — dernier mono-langue (guide « Scan & QR ») résorbé (16/06, `byLocale` dans `communsRegistry`). Intégration ⇄ accueil fédération.
- **Thésaurus matière v1→v3** (§30 `THES`) : gouvernance statuts + file d'activation (v1) ; synonymes `alt`/`hidden`, éditeur libellés multilingue, notation CDD, suggestions assistées (v2) ; **relations « voir aussi »** (`subject_relations`, skos:related) + **arbre OPAC** (`subject_tree_v1`, compte visibilité-safe via `catalog_list_anon_v1`) + **export SKOS public** (Turtle/JSON-LD, URI stable `app.anarbib.org/thesaurus/`) (v3). **CDD-par-classe reporté** (0 notation ; cotage Baqueiro).
- **Entraide degré 3** : routage + **notification par cercles** (exclut la biblio de l'auteur·rice) ; **visio Jitsi** en **onglet dédié**, hôte militant **Autistici `vc.autistici.org`** (accord A/I 16/06, `VITE_JITSI_DOMAIN`, pas d'embedding) ; doc de démarche hébergeurs (`../journal/operations/HEBERGEURS_jitsi_militants_2026-06-16.md`).
- **Gating fédération** (§24 `FED-O8`) : onglets staff-only (entraide/cercles/carte/assemblées) vs ouverts (início/gazette/lettre/communs), défense en profondeur **UI + RLS**.

**Coordination** : câblage `AssembleiasTab` d'une **autre session** (AG planning) avalé par un commit (worktree partagé) → build CI cassé, réparé en committant leur `AssembleiasTab.jsx` (i18n + câblage déjà sur main) ; session AG **notifiée** (pill accueil « Assemblées » + CSS `.ab-fed-assembleias` à finir de leur côté).

— *Session: Fédération — Communs & Entraide*

### Assemblée du réseau (AG) — chantier livré (16–17/06)

- **v0.1 + P2b + P2c** (16/06) : objet assemblée + dépôt ODJ sans gardien ; rôle
  `assembleia_facilitators` (animation hors admins) ; volontariat + désignation parmi
  les volontaires. Onglet **data-driven** 10 locales, **staff-only**.
- **P3 — notifications** (17/06, **EN PROD**, vérifié MCP) : migration `20260617004735`
  (émission best-effort `network.assembleia.{convocada,agenda_published,item_proposed}`
  via `fn_network_notify_event`, voie outbox/jsonb — l'`uuid` voyage dans le payload, pas
  de `bigint`) ; handler EF `domain/assembleia.ts` (routé avant `network.*`) ; `mail-strings`
  **10 locales**. Convocation → **chaque coordenador·e** fédéré·e (anti-rétention, canal
  obligatoire) ; `item_proposed` → **facilitation**. Commits `29ba8214` + `33b1f2df`.
- **Différé P3b** : rappels J-15/J-1 (pg_cron) ; inclusion optionnelle des bibliothécaires
  par biblio. **v0.2** : choix de date, quorum 60/50, vote, ratification asynchrone.

— *Session: Fédération — Assemblée du réseau (AG)*

## Morceaux non résolus (survey sessions, bruit filtré)

### ✅ « À pérenniser » — RÉSOLU (faux positif, élucidé 11/06)
- Le « il faudra pérenniser » de la session 10/06 = le scoring de **`api.similar_books`**
  (LIMIT 16 + sujets comptés). Il était **déjà persisté** dans
  `20260609204931_persist_similar_books_scoring_v4.sql` (06-09). Prod == migration vérifié →
  **aucune perte, rien à faire**. (L'audit a confirmé qu'il n'y avait pas de vraie perte.)

### 🟠 Chantiers à finir
- ✅ **#CL.10** — **FAIT** (vérifié 11/06) : `libTag` + `sameTitleSignal` dans
  `ReservationCard.jsx` / `AccountPage.jsx` (tag biblio d'origine + signal « même titre » par
  titre normalisé ; i18n `account.circ.sameTitleSignal`). Rien à faire.
- **i18n sujets** : traduits seulement `pt-BR/fr/es/en`, autres locales en fallback
  (« à compléter au fil de l'eau ») — *[« Spec multi-appartenance »]*. **Reste ouvert** (non bloquant).

### 🟡 Différés CONSCIENTS (décision prise, pas oubliés)
- **#OPAC11** — RSS / courriel du catalogue, **différé anti-tracking** — *[« Spec
  multi-appartenance » / cadrage OPAC]*.
- **EA-12 phase 2** (parité PEB, **~45 fn JS**) — **gelé** par décision **REGISTRE BIBLIO-9**
  (08/06), conditionné à un besoin prod réel BLMF↔BTL. Vérifié 11/06 : **pas un quick-win**,
  décision délibérée → **on laisse gelé**.

### ⚪ Reliquats cosmétiques (optionnels) — SEUL actionnable restant
- « Trocas ativas » à ajouter dans la grille de chiffres ; `loansCreated30d` calculé mais
  jamais affiché (métrique morte) — *[« Chantiers annexes », 08/06]*. **Reportés** (optionnels,
  non bloquants) → à solder en quick-win une prochaine fois.

### ✅ Délégué / livré ailleurs — NE PAS re-traiter
- **Baqueiro** (docs de consignes) : brouillons MLEG, orphelins d'autorité, indexation
  sujets, enrichissement dates auteurs.
- **N4 — numéro/identité local·e** (mail réconciliation UUID ↔ identité) → **session identité
  dédiée**. CARD-LOCAL **Lot 0 déployé le 11/06** ; **Lots 1→5 construits le 12/06**
  (recherche painel N1, attribution/édition N2, modèle biblio N5, roster PDF/CSV N3,
  notif réconciliation N4 + finition CI Pages non bloquant) — commités en local,
  **en attente de push** (sérialisation avec les autres sessions).
- **Corpus `.ris` CIRA** → local, non commité (sans consentement explicite).
- **§21 PARTNER notifications** (NOTIF-1/2/3) → **livrées en prod** le 11/06.
- **CI** → migré Woodpecker→Forgejo Actions, **runner auto-hébergé WSL2**, **retry-Pages**
  (504 Codeberg transitoires), 2 jobs `app`/`backend` (11/06). Runbook
  `../journal/operations/SETUP_runner_wsl2_2026-06-11.md`.
- **Baseline schéma** → snapshot de référence versionné (`../schema/`, 11/06).

## Sessions actives au 11/06 (ne pas marcher dessus)
- **« Import/export wizard refactor »** — wizard « Novo import ».
- **« Italian schwa and hardcoded strings »** — i18n.
- **Session identité lecteur·rice** (N1→N5, dont N4) — *aspects identité/numéro local*.

## Import/Export — livré 2026-06-12 (session « fiabilisation matching & rapprochement »)
- ✅ **Fila de revisão** : pastilles autonomes (`aa69051`) ; **confidence réelle**
  affichée (= meilleur score candidat, fini le « 0% » trompeur ; migration
  `20260612005406`, `23efba2`, données backfillées) ; **rapprochement** d'un doublon
  publié → **brouillon d'exemplaire** (`exemplar_drafts`) au lieu d'un `book_draft`
  (migration `20260612011854`, `1987da8`).
- 🔸 **i18n `importacoes.circuit/migracao/deposit.*` NON orphelines** : utilisées par
  `ImportWizard.jsx` (`/importacoes/novo`, session wizard) et la feature dépôt partenaire
  (`fn_partner_register_deposit_source`, vivante). **Ne pas supprimer.**
- 🔸 **Pipeline `ingest` d'import (tables + ~23 fonctions) hors `migrations/`** = relève
  du **socle fondateur** ci-dessus (déjà capturé dans le baseline du 11/06, à jour). Pas
  un chantier oublié ; un *db reset* from-scratch ne le rejoue pas (cf. squash différé).
- 🟠 **Perf matching** (cadrage `CADRAGE_perf_matching_import`) : **toujours ouvert**
  (band-aid `statement_timeout=0` seul ; vrai fix immutable+index non fait).

---
*Rafraîchi le 11/06/2026 en fin de session (« Catalogação work completion ») : 🔴 pérennisation
résolue, #CL.10 fait, EA-12 confirmé gelé, baseline snapshot livré — ne reste qu'un reliquat
cosmétique optionnel.*
*Maintenir ce fichier quand on livre/clôt un chantier. En cas de doute sur un statut :
revérifier dans le code, pas se fier à cette trace seule.*
