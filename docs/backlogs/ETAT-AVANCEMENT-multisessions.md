# État d'avancement — backlog consolidé multi-sessions · **repris le 2026-08-20**

> 📍 **Lecture rapide** : le [tableau de bord par chantier](#tableau-de-bord-par-chantier)
> en fin de document consolide les deux mois qui manquaient (20/06 → 20/08). Ce qui suit
> immédiatement est la trace d'origine, reconstituée le 11/06 et tenue jusqu'au 20/06 —
> conservée telle quelle.

## Trace d'origine (11/06 → 20/06)

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

## ✅ Session « File éditoriale — tri & supports AV » (17/06) — livré

Bloc livré et **déployé en prod** (`main` `ae7e25d8` ; DB appliquée via MCP puis tracée en migrations idempotentes ; doc `caca8518` `[CI SKIP]`). Doctrine au **REGISTRE §12 CAT-E15/E16** (CAT-E16 **résout le gap noté CAT-E13** : `editora` absent de l'audiovisuel). Backlog **v33** amendé.

- **File éditoriale** (`QueuePanel`) : **tri par en-tête** (asc/desc, ▲/▼) sur Type/Titre-Nom/Statut/Ouvert le/Dern. modif. + nouvelle colonne **« Ouvert le »** — `last_opened_at` sur les 3 tables brouillon + RPC `fn_touch_draft_opened` + **garde GUC** `anarbib.skip_touch_updated_at` sur le trigger partagé `touch_updated_at` (ouvrir ≠ modifier). Migr. `20260617103939`.
- **Rôles de contributeur conditionnés au `tipo_material`** : audiovisuel (réalisateur·rice/scénariste/acteur·rice/interprète/compositeur·rice/narrateur·rice/producteur·rice), audio (+voix) ; écrits inchangés. Garde rôle hors-liste sur reprise. i18n ×10.
- **Auteur catalogue dérivé du rôle créateur principal du média** : `v_book_authors_canonical` → `realizador` (AV) / `compositor` (audio) si pas d'`autor` ; écrits inchangés (migr. `20260617120646`, REFRESH des 2 MV).
- **Éditeur → distributeur / maison de disques** : champ `gravadora` (audio) + copie au publish (migr. `123948`/`124826`) ; libellé adapté au support sur la **fiche** (`v_book_detail_public_v2`, migr. `125221`) et la **liste OPAC** (`publisher_display` = CASE par média repli `editora` ; `private.fn_publisher_display` + vues `api.catalog_list_*_v1`, migr. `130551` ; icône 🎬/💿 + tooltip). Tri/filtre liste restent sur `editora` (≈2 lignes AV/audio sur 503 — limite assumée).

— *Session: File éditoriale — tri & supports AV*

## ✅ Session « Doublons d'autorité & i18n erreurs catalogue » (19-20/06) — livré

Bloc livré et **déployé en prod** (`feat/catalog-audit-fixes`). **Avancée de fond** : le catalogue
passe d'une liste plate de documents isolés (doublonnage **passif** des œuvres) à un **modèle
bibliographique FRBR-léger** Œuvre → Expression → Manifestation → Exemplaire. Synthèse complète :
[`../journal/chantiers/CHANTIER_modele_oeuvre_editions_2026-06-20.md`](../journal/chantiers/CHANTIER_modele_oeuvre_editions_2026-06-20.md).

- **Autorités** : `merge_author` surfacé (bouton « Fusionner… » dans `CatalogPanel`) ; réconciliation
  `book_authors`↔`book_contributors` (1243 liens, migr. `20260619210445`) ; hints d'erreur catalogue
  localisés (`error.catalog.discard.*`, migr. `20260619160150`). LUZ + 11 grappes fusionnées.
- **Dédoublonnage conscient de l'édition** (migr. `20260620083749`) : `suggest_*` excluent les ISBN
  distincts + table `book_not_duplicate` + « Pas un doublon » + « Retirer la couverture ».
- **Modèle Œuvre v1** : table `works` + `books.work_id` + backfill 153 œuvres/344 notices (migr.
  `…090724`) ; RPC de regroupement non destructives (`…091752`) ; « Autres éditions » sur BookPage
  (`…100926`) ; bloc Œuvre + « Même œuvre »/« Pas un doublon » **gatés palier ≥ Avancé**.
- **Modèle Œuvre v2** : page publique `/obra/:id` (`WorkPage` + `work_public_detail`, `…102802`) ;
  `suggest_editions_for_book` (`…103632`) ; `work_id` aux vues catalogue sans rebuild MV (`…105747`) ;
  bascule « Regrouper les éditions » au catalogue (repli **client**, OFF par défaut, zéro risque OPAC).
- **Couche Expression v3** : `work_expressions` (langue) + `books.expression_id` dérivé par trigger
  (`…113134`, 198 expressions/345 notices) ; page Œuvre **groupée par langue** ; **traducteur·rice par
  expression** dérivé des contributeurs (`…114434`, pas de colonne fantôme).
- **Guide** : étape `CatalogacaoWizard` « Œuvres & doublons », **palier Avancé signalé**.
- **Reste ouvert (volontaire)** : repli catalogue **serveur strict** — *uniquement si* le repli client
  montre ses limites. i18n 10 locales à parité (CI verte), migrations validées en `begin…rollback`.

— *Session: Doublons d'autorité & i18n erreurs catalogue*

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
---

# 🔄 Reprise du 20/08/2026 — deux mois consolidés (20/06 → 20/08)

> **Pourquoi.** Ce fichier était figé au **20/06**. Entre-temps : **293 commits**, dont
> **119 migrations**, et une bascule complète du centre de gravité du projet — de
> l'applicatif vers l'infrastructure, puis vers la sécurité.
>
> **Méthode.** Reconstruit à partir de trois sources croisées, jamais de mémoire :
> (1) les sections du [REGISTRE](../specs/REGISTRE_decisions.md), tenues à jour section
> par section — c'est la source normative ; (2) le `git log` par scope ; (3) des
> **vérifications de lecture en production** (MCP Supabase, lectures seules) pour tout
> statut qui ne se déduisait pas du code. Les vérifications faites sont **nommées** dans
> chaque ligne : quand rien n'est nommé, c'est que la preuve est le commit.
>
> **Ce que ce document n'est pas.** Une garantie. La consigne de 2026-06-11 tient
> toujours : *en cas de doute sur un statut, revérifier dans le code, pas se fier à cette
> trace seule.*

## Tableau de bord par chantier

Légende : ✅ livré & déployé · 🟢 livré, reliquat mineur · 🟠 en cours · 🟡 cadré, non implémenté · ⬜ décidé, non commencé

| Chantier | Statut | Preuve retenue | REGISTRE |
|---|---|---|---|
| **Œuvre / Éditions** (FRBR-léger) | ✅ | tables `works`, `work_expressions` **vérifiées en prod** ; pages `/obra/:id` | §12 `CAT` |
| **Thésaurus matière** v1→v3 | ✅ | `subject_relations` **vérifiée en prod** ; export SKOS public (Turtle/JSON-LD) | §30 `THES` |
| **Thésaurus FICEDL** (vocabulaire partagé) | ✅ | `subject_ficedl_links` **vérifiée en prod** ; pages-sujets publiques (P3a/P3b, 25-30/06) ; vadémécum 10 locales (02/07) | §30 · `journal/ficedl/` |
| **Fonds sonores** (#AUDIO) P0→P5 | ✅ | `audio_tracks` **vérifiée en prod** ; EF `audio_fingerprint_lookup` **déployée** ; OAI-PMH `oai_dc`+`marcxml` (22/06) | §35 `AUDIO` |
| **Assemblée du réseau** (AG) | 🟢 | `assembleias` **vérifiée en prod** ; P3 notifications livré | §32 `AG` — reste P3b (rappels J-15/J-1) et v0.2 (quorum, vote) |
| **Dépôt de garantie** | ✅ | `loan_deposits` **vérifiée en prod** ; dépôt tournant, plafonds anti-barrière, rapport PDF (30/06) | `spec-depot-garantie` |
| **Validation d'inscription — refonte du refus** | ✅ | modèle à 2 passages, écrans de refus, mail `membership_refused`, journal `reader_membership_events` **vérifié en prod** (22-23/06) | §9 `VALID` |
| **Notifications in-app** (cloche) | ✅ | MVP au-dessus de `user_notifications` (23/06) | §6 `NOTIF` |
| **Événements de bibliothèque** | ✅ | `library_events` **vérifiée en prod** ; avis in-app, opt-out lecteur, deep-link (05/07) | — |
| **#BG2 — sauvegarde hors-fournisseur** | ✅ | 3 flux restic chiffrés hors-site ; pseudonymisation `BG2-14` ; `backup_heartbeats` **vérifiée en prod** ; garde-fou CI « table non classée » (20/08) | `§BG2` + `§BG2 (suite)` |
| **Supervision du service public** | ✅ | `service_health_probes` / `service_health_incidents` **vérifiées en prod** ; cron `anarbib-health-probe` **actif, toutes les 5 min** (vérifié) ; EF `health-probe` déployée | — *(pas encore de carte au REGISTRE)* |
| **Gazette Rizoma — automatisation** | ✅ | 3 crons **actifs vérifiés** : `anarbib-gazette-monthly-start` (15 du mois 06:00), `-reconcile-tick` (5 min), `-translate-submissions` (10 min) | §29 `GAZ` |
| **Lettre de la fédération** | ✅ | opt-in `/conta` + case au signup, compose/envoi staff, numéros | §29 `GAZ` |
| **Récapitulatifs inter-bibliothèques** | ✅ | EF `notify-network-weekly-report` + `notify-cross-library-digest` déployées ; crons **actifs vérifiés** (lundi 08:15 / 08:30) ; mode simulation (17/08) | §6 `NOTIF` |
| **Notes de lecture** | ✅ | `book_reading_notes` + `book_reading_note_reports` (modération) **vérifiées en prod** ; Lots 1→5 des 02 au 04/08 | `CADRAGE_notes_de_lecture` (01/08) |
| **Sécurité — Altcha & oracles** | ✅ | EF `altcha-challenge` déployée ; Turnstile retiré partout (login, inscription, cartographie) ; oracles d'appartenance et « n° lecteur → e-mail » fermés (18-19/08) | `PRIV-2` (aligné 20/08) |
| **Identité visuelle** | ✅ | nouveau logo (dessin humain) + déclinaison ; bandeau pilotable par bibliothèque ; assets versionnés (19/08) | — |
| **Numérisation** | 🟢 | chaîne arrêtée (ScanTailor Advanced + img2pdf), captures effacées après validation, fiche pratique (19-20/08) | `DECISION_profil_numerisation` |
| **Catalogage — doublons** | ✅ | détection floue `pg_trgm` + modale d'avertissement (13/08) ; `book_not_duplicate` **vérifiée en prod** ; dédoublonnage global du catalogue publié (19/08) ; tri par niveau de preuve (20/08) | §12 `CAT` |
| **Catalogage — œuvre vs édition + N exemplaires** | ✅ | choix à la création, N exemplaires par bibliothèque à la publication (16/08) | §12 `CAT` |
| **Droits (`rights_status`)** | ✅ | vocabulaire contrôlé + justification écrite + liste fermée au catalogage (19/08) | — |
| **Lecture restreinte** | ✅ | réservée aux membres de la bibliothèque détentrice (20/08) ; URL source d'un document restreint cessée d'être exposée | §22 `ILL` |
| **Chantier mobile / responsive** | 🟢 | Phases A/B/C livrées ; doctrine graduée le 20/08 | **§36 `MOBILE`** — reste `MOB-Q1..Q3` |
| **Migration hors Supabase (VPS)** | 🟠 | arbitrage rendu (03/07), shortlist + runbook + plan serveur (04/07), pile auto-hébergée éprouvée en répétition (18/08), essai `test.anarbib.org` (19/08) | `DECISION_arbitrage_migration_vps` — **chemin critique opérationnel, pas technique** |
| **Perf matching import** | ✅ *(corrige ce fichier)* | volets A+B+C confirmés le 03/07 ; band-aid `statement_timeout=0` remplacé par une borne 120 s — migration `20260703182035_bound_partner_matching_statement_timeout.sql` **présente au dépôt** | cf. `ETAT-lancement-consolide-2026-07-03` |
| **Squash des migrations** | ⬜ | toujours non fait — 146 migrations, dont 119 depuis le 20/06 ; le risque structurel décrit en tête de ce fichier **reste entier** | — |

## Ce qui a changé de nature, mois par mois

**Fin juin — la vague la plus dense.** Le catalogue passe au modèle bibliographique
(Œuvre → Expression → Manifestation → Exemplaire), le thésaurus atteint v3 puis rencontre
le vocabulaire FICEDL, les fonds sonores traversent P0→P5 en quatre jours, le dépôt de
garantie et la refonte du refus d'inscription arrivent. C'est le dernier mois « applicatif ».

**Juillet — bascule vers l'infrastructure.** 78 commits seulement, mais structurants :
#BG2 occupe le mois (partition par sensibilité, trois flux, automatisation systemd,
pseudonymisation à l'effacement), et la sortie de Supabase est instruite (arbitrage,
shortlist VPS, runbook de migration, plan serveur Dell). Le 03/07,
`ETAT-lancement-consolide` pose le verdict : **AnarBib est fonctionnellement prêt, le
chemin critique est désormais opérationnel et humain**.

**Août — sécurité, identité, finitions.** Altcha auto-hébergé remplace Turnstile et fait
tomber la dernière dépendance externe ; plusieurs oracles sont fermés ; la supervision du
service public apparaît ; le réseau reçoit son logo et son bandeau par bibliothèque ; les
notes de lecture sont livrées en cinq lots ; le catalogue gagne un dédoublonnage global et
un mode dégradé.

## Corrections apportées à ce fichier

- **Perf matching import** : la section « Morceaux non résolus » le disait *toujours
  ouvert (band-aid `statement_timeout=0` seul)*. **Résolu le 03/07** — volets A+B+C
  confirmés, borne 120 s en migration. Ligne à considérer comme close.
- **Source vivante** : ce fichier existe en deux exemplaires ; **celui-ci** (dans
  `backlogs/`) fait référence. La copie de `journal/sessions/`, figée au 10/06, porte un
  tampon de supersession depuis le 20/08.

## Ce que je n'ai pas tranché

- **Trois crons inactifs en production** (`active = false`, vérifié le 20/08) :
  `anarbib-collective-removal-execute-daily`, `anarbib-cooptation-reminders-daily`,
  `anarbib-request-eval-digest`. Désactivation volontaire ou oubli ? Je ne peux pas le
  déduire du code — **à trancher par la coordination**. Les trois touchent à de la
  gouvernance (retrait collectif, rappels de cooptation, digest d'évaluation).
- **Supervision et identité visuelle** n'ont **pas de carte au REGISTRE**, alors que la
  règle du 18/06 dit « plus aucune feature livrée sans au moins une carte de doctrine ».
  Deux graduations à faire, sur le modèle de `§36 MOBILE`.
- **Le statut fin des chantiers non touchés depuis juin** (cotisations, #MM, i18n
  rollout, suites AG v0.2) n'a pas été re-vérifié en prod : le tableau ci-dessus ne les
  mentionne que là où une preuve existait.

---
*Reprise du 20/08/2026, session « Débordements mobile — champs de saisie ». Vérifications
en prod : existence de 13 tables, liste des 32 tâches `cron.job` (29 actives), liste des
47 edge functions déployées, présence des migrations citées. Le REGISTRE reste la source
normative ; ce fichier reste de la trace.*
