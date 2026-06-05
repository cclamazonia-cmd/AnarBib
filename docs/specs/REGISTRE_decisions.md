# 🧷 REGISTRE DES DÉCISIONS — AnarBib

- **Version :** 0.1 (seed d'audit du corpus complet — 02/06/2026)
- **Rôle :** **foyer unique** des choix (arbitrages) et des doctrines transverses. On **cite l'ID** ici, on ne reformule jamais ailleurs.
- **Préséance (rappel) :** en cas de conflit, ce registre + la spec courante + le backlog font foi ; CADRAGE / CHANTIER / SESSION = trace non-normative.
- **Comment lire un statut :** ✅ acté · 🟡 ouvert (à trancher) · 🔵 supersédé/historique · ⚠️ drift détecté (voir `AUDIT_coherence_corpus_2026-06-02.md`).
- **Le champ statut est le fil-piège :** quand une décision bascule, on change **une seule ligne** ici, et le statut dit quelle spec réaligner.

> Ce seed n'est pas exhaustif : il capture les **arbitrages structurants**, les **doctrines transverses** (les faits recopiés partout) et tous les **points ouverts / drifts**. Il se complète au fil des chantiers (règle « close before open » étendue à la doc).

---

## 0. Doctrines transverses — *un seul foyer, à citer partout*

Ce sont les faits recopiés dans presque toutes les specs : c'est là que naissent les drifts. Désormais foyer unique.

| ID | Énoncé | Statut | Foyer / origine |
|---|---|---|---|
| **DOC-I18N-1** | **10 locales** : pt-BR, fr, es, it, de, en, ca, eo, **nl**, **el**. Livraison en une passe, clés plates, LF sans BOM, 2 espaces. | ✅ acté (nl ajouté ~03/06, el le 04/06 ; depuis le « 6 » historique → ca/eo → nl/el) | acquisition §7 ⚠️ **les specs antérieures disent « 6 » ou « 8 » — trace périmée, cf. DRIFT-1** |
| **DOC-DEPLOY-1** | `git push` → Woodpecker déploie tout (`supabase db push --linked` + `deploy-edge-functions`). **Jamais** `apply_migration` MCP, **jamais** SQL Editor avant push, **jamais** CLI manuelle. Migrations horodatées **UTC**, vérifier avant de choisir. | ✅ acté (corrigé) | spec-migration-mail-resend §6.6 (v0.4) ; acquisition §7 |
| **DOC-DEPLOY-2** | Exception unique : `notify-event` se déploie en **CLI** (`--no-verify-jwt`, bundle >150 ko). `register` = seule EF avec `verify_jwt`. | ✅ acté | migration-mail §6.6 |
| **DOC-DEPLOY-3** | SQL Editor : **interdit** pour toute migration/DDL avant push (le schéma passe par fichier + `git push` → Woodpecker). **Toléré**, à titre exceptionnel et **tracé**, pour (a) le nettoyage ponctuel de données de test/résiduelles (DML sur quelques lignes, jamais de schéma) et (b) les lectures de diagnostic/validation. Toute opération consignée (date + objet) ; si effet durable, reportée en migration ou note de décision. | ✅ acté 02/06 | régularise cycle-vie-peb (purge PEB test = a) et historico (test = b) — clôt DRIFT-5 |
| **DOC-RPC-3** | RPC v3 : écritures (insert/update/delete + validation métier) via RPC ; `supabase.from()` toléré en lecture simple sous RLS ; `storage.from()` hors périmètre RPC. | ✅ acté 21/05 | acquisition §7 ; cartographie §3.2 |
| **DOC-OBJ-2** | Création d'objets backend v2 : `REVOKE … FROM PUBLIC, anon, authenticated, service_role` sur fonctions privées ; trigger non-DEFINER appelant une fonction DEFINER REVOKE-ée → patcher le trigger `SECURITY DEFINER` + `search_path` figé **avant** le REVOKE ; bloc DO de vérif en fin de migration ; `CREATE OR REPLACE` qui change la signature → **DROP + CREATE**. | ✅ acté | acquisition §7 |
| **DOC-RLS-1** | Tests RLS : `SET LOCAL ROLE` **+** `SET LOCAL "request.jwt.claims"` en `BEGIN/ROLLBACK`. | ✅ acté | acquisition §7 |
| **DOC-PS-1** | i18n : scripts via Node `.cjs` ou UTF-8 PowerShell explicite ; **vérifier toute mojibake avant correction** (faux positifs). (= R11, transverse) | ✅ acté | consultas §11.3 ; emprunts §11.3 |
| **DOC-NOTIF-1** | **On notifie qui n'a PAS initié l'action**, jamais l'acteur. (= R5 consultas, miroir admin-reseau §4.2.4) | ✅ acté | consultas §11.2 |
| **DOC-PERIM-1** | « **page = périmètre, pas de cross-calcul** » : un compteur s'agrège sur le périmètre de sa page ; pour les anonymes, sur les vues `*_anon_v1`, jamais sur une vue réseau (régression B.7). | ✅ acté v0.2 | admin-reseau §11.1 Q1 ; catalogue-decouverte INV-1 |
| **DOC-CLOSE-1** | « **close before open** » : committer+vérifier chaque paquet avant le suivant ; `npm run build` avant chaque push ; **étendu à la doc** (un chantier n'est clos que quand ses vérités ont gradué + sa trace est tamponnée). | ✅ acté | acquisition §7 |
| **DOC-MODELE-1** | Vocabulaire des strates du modèle, **deux axes distincts** : (1) **niveaux de granularité** (« Camadas ») = œuvre/notice → holding → exemplaire, axe *vertical* ; (2) **couches de l'exemplaire** = trace / provenance / destination, *facettes* du niveau exemplaire, axe *horizontal*. Ne pas confondre « couche » (facette) et « Camada/niveau » (granularité). La couche *provenance* = propriétés d'acquisition au niveau exemplaire. | ✅ acté 02/06 | exemplaires §2 ; acquisition §4 |
| **DOC-JSX-1** | Validation **hors bundler** : syntaxe JSX via `tsc transpileModule` (TypeScript ; ni résolution de modules ni typage → zéro faux positif sur imports) ; logique pure (registres, helpers) via harness **ESM `.mjs`** + `node --check`. Garde-fou quand `npm run build` est indisponible ; ne remplace pas le build avant push (`DOC-CLOSE-1`). | ✅ acté 04/06 | Track A catalogação (Lots 1–2b) |
| **DOC-ADDR-1** | **Registre d'adresse de l'UI = tutoiement.** L'app s'adresse au membre en **« tu »** (horizontal, compagnon ; **zéro « vous »**). Corps de texte et adresse directe en tu + possessifs `ton/ta/tes`. **Titres et intitulés des objets du membre en 1ʳᵉ personne** `mon/ma/mes` (« Mon mot de passe », « Ma carte », « Mes données », « Mes droits », « Mon compte », « Mes notifications »). Décliné par locale selon le registre informel/compagnon de chaque langue (du en de, tu en it, je en nl, εσύ en el, você en pt-BR, ci/vi en eo…) + conventions inclusives en place (point médian fr, Genderstern de…). | ✅ acté 04/06 (validé Xavier) | fr.json (61 chaînes) ; rollout 9 locales en cours |

---

## 1. Réseau & gouvernance — `RES` *(spec-administrateur-reseau-v0.4)*

| ID | Décision | Statut | Foyer |
|---|---|---|---|
| RES-Q1 | Un·e admin réseau peut être staff de plusieurs biblios (légitime ; DOC-PERIM-1 protège les compteurs) | ✅ v0.2 | §11.1 |
| RES-Q2 | Table `network_admin_cross_library_actions_log` créée au paquet C.5 | ✅ v0.3 | §11.1 |
| RES-Q3 | Expiration des propositions de cooptation = **60 jours** (+ rappels J+14/J+25) | ✅ v0.3 (30→60 à D.6) | §11.1 |
| RES-Q4 | Anonymat opposant = choix par vote (`disclose_identity`, **sans DEFAULT**) + rationale obligatoire si `opposed` | ✅ v0.3.1 | §11.1 / R6 |
| RES-Q5 | Carence retrait collectif = **7 jours fixes** ; auto-retrait immédiat sauf dernier admin (30 j) | ✅ v0.3 | §11.1 |
| RES-Q6 | Notif staff local sur actions transverses = digest hebdo + mail immédiat si critique | ✅ v0.3 | §11.1 |
| RES-R1..R7 | Doctrines de notification cooptation (proposeur 1er vote seul ; rationale conditionnelle ; reminder 2 mails ; etc.) | ✅ v0.3.1 | §11.2 |
| RES-D9 | Doctrine **anti-méga-machine** inscrite normativement (SIGB second, canal humain premier) | ✅ v0.4 | §11.2bis (miroir onboarding §1.4) |
| RES-D10 | Mécanisme « Proposer un échange » admins→biblios (table `library_member_invitations`, 3 RPC, 4 events) | 🟡 à implémenter | §4.7 |
| RES-D11 | Risque burnout admin réseau reconnu (éthique de soutenabilité) | ✅ v0.4 (suivi) | §8.8 |
| RES-Q9..Q12 | Mineures ouvertes : champ `restrictive` ; notif ajout admin ; stat publique canal humain ; vigilance biblios silencieuses | 🟡 ouvert | §11.3 |

---

## 2. Cartographie réseau — `MAP` *(spec-cartographie-reseau v0.1)*

⚠️ **Squelette d'arbitrages — TOUT est ouvert** (colonne Décision vide au §6).

| ID | Sujet | Reco | Statut |
|---|---|---|---|
| MAP-A | Localisation des données | A2 court terme, A3 si croissance | 🟡 ouvert |
| MAP-B | Modèle i18n des contenus carto | B4 | 🟡 ouvert |
| MAP-C | Hébergement carte publique | C2 | 🟡 ouvert |
| MAP-D | Validation des modifications | D1+D3 hybride | 🟡 ouvert |
| MAP-L | Sort de la carte uMap actuelle | L1 | 🟡 ouvert |
| MAP-CAL | Calendrier | Post-Bologna | 🟡 ouvert |

⚠️ Auto-contradiction interne : §0 dit « **octolingue** » puis « les **6 locales** actuelles » → voir DRIFT-4 (et DOC-I18N-1).

---

## 3. Migration mail — `MAIL` *(spec-migration-mail-resend v0.4)*

| ID | Décision | Statut | Foyer |
|---|---|---|---|
| MAIL-Q1 | Basculer transport par transport sur place (R.2–R.5), aligner plus tard (R.7) | ✅ (inversion v0.2) | §3.7 |
| MAIL-Q2 | Garde-fou doctrinal anti-tracking | ✅ | §6.4 / A6 |
| MAIL-Q3 | Audit dashboard webhooks bounces Brevo en R.1 | ✅ (audit à faire) | A2 |
| MAIL-Q4 | Bascule transport-par-transport sans staging dédié | ✅ | §3.7 |
| MAIL-Q5 | Rétention logs : conserver Resend + Supabase | ✅ | §3.7 |
| MAIL-Q6 | Sender = `no-reply@notifications.anarbib.org` | ✅ | §3.7 |

---

## 4. Consultations — `CONS` *(spec-flux-consultations-v2.2, source normative R-series)*

R1 invariant `schedule_missing` · R2 helper `scheduleFormat.js` · R3 reproposition après refus · R4 no-show conditionné temporel · **R5 = DOC-NOTIF-1** · R6 QA manuelle (E2E reportée) · **R7** ordre UPDATE narrative-avant-état · **R8** `workflow_note`(staff) vs `schedule_reply_note`(lecteur) · **R9** traçabilité coordination généralisée · **R10** signature payload stable handler/trigger · **R11 = DOC-PS-1**. — Toutes ✅ figées (v2.1/v2.2, chantiers #141/#142).

## 5. Emprunts — `EMP` *(spec-flux-emprunts v1.1)*

R7–R11 **propagés depuis consultas** par symétrie (✅ 31/05). R8 ne s'applique pas littéralement (pas de note d'origine lecteur aujourd'hui) mais à anticiper. R10 illustré par la refonte #NOTIFY-prorrogacao (cf. NPRO).

## 6. Notifications lecteur — `NOTIF` *(spec-notifications-lecteur v1.0)*

| ID | Doctrine | Statut |
|---|---|---|
| NOTIF-A | Admission : notifier seulement si **action requise** ou **impact subi** | ✅ |
| NOTIF-B | Mail = base ; in-app = réplique **restrictive** (B1 délai RGPD / B2 action 100 % in-app / B3 décision sur droits) | ✅ |
| NOTIF-C | `user_notifications` **réservée au rôle reader** ; staff via outboxes painel ; double notif si concernée aux deux titres | ✅ |

---

## 7. Modélisation item — `ITEM` *(spec-granularite-item v1, #MODEL-item-grain)*

| ID | Décision | Statut |
|---|---|---|
| ITEM-Q1 | `consulta_linhas_v2.item_id` **NOT NULL** (école A) | ✅ |
| ITEM-Q2 | L'exemplaire est choisi par **la bibliothèque**, résolu au plus tard à l'insertion de la `consulta_linha` | ✅ (moment exact à caler en impl.) |
| ITEM-Q3 | Migration des 30 lignes : résolution auto (mono-exemplaire) + signalement des holdings ambigus | ✅ |
| ITEM-Q4 | `book_holdings` **conservé** (`item_id` fort + `holding_id` confort, patron `emprestimo_itens_v2`) | ✅ |
| ITEM-Q5 | Périmètre = cœur (colonne+FK+migration+RPC consulta) ; suites = frontend + resserrement `#ILL-availability` | ✅ |

---

## 8. Acquisition / provenance — `ACQ` *(spec-acquisition-provenance v0.1)*

⚠️ Arbitrages = **recommandations à confirmer** (sauf Q4).

| ID | Reco | Statut |
|---|---|---|
| ACQ-Q1 | Provenance au niveau **exemplaire** (`exemplares`/`exemplar_drafts`) ; champs notice dépréciés (COMMENT, pas DROP) | 🟡 à confirmer |
| ACQ-Q2 | Desiderata = nouvel objet léger library-scoped `acquisition_desiderata` (≠ `user_wishlist`) | 🟡 à confirmer |
| ACQ-Q3 | Réception = cœur minimal (provenance par exemplaire) ; `reception_event` = suite | 🟡 à confirmer |
| ACQ-Q4 | UI : ingestion technique → Importações ; provenance/entrée en collection → Catalogação (onglet Exemplaires) | ✅ confirmé |

> Couplage : migration `exemplares` **mutualisée** avec CAT-B6 (destination). Terminologie clarifiée : « Camadas » = niveaux de granularité, « couches » = facettes de l'exemplaire (cf. `DOC-MODELE-1`) — **DRIFT-6 résolu 02/06**.

---

## 9. Validation physique — `VALID` *(spec-validation-physique v1.1)*

| ID | Décision | Statut |
|---|---|---|
| VALID-AMD | Bascule structurelle vers **validation par-appartenance** (et non plus par-compte) | ✅ amendement 30/05 |
| **ACCT-MIGRATION** | Migration de compte entre biblios : `spec-migration-compte v1.0` **archivée**, son socle **absorbé dans `spec-multi-appartenance-lecteur`** (à rédiger). Foyer désormais = multi-appartenance. | ✅ acté (backlog v25, Option D · VII.1) |
| VALID-C1..C4 | Bouton « valider en lot » ; note coordenador auto-validé ; notif compte en attente ; compteur d'attente | 🟡 ouvert (impl.) |

✅ Clôture réalignée 02/06 : pointe désormais vers `spec-multi-appartenance-lecteur` (cf. ACCT-MIGRATION) — DRIFT-2 corrigé.

## 10. Renouvellement granulaire — `RENOV` *(spec-renouvellement-granulaire v0.1)*

| ID | Point | Statut |
|---|---|---|
| RENOV-1 | `renewals_used` déprécié ou cache permanent ? | 🟡 (repoussé après phase 2) |
| RENOV-2 | Notif prolongation distingue item vs emprunt ? | ✅ **résolu** (NPRO-D1/D4 ; spec alignée 02/06) — DRIFT-3 corrigé |
| RENOV-3 | Bouton « tout renouveler » cohabite avec le par-item | ✅ (Décision 2, à confirmer à l'usage) |

## 11. Notify-prorrogação — `NPRO` *(spec-notify-prorrogacao-granulaire v0.1 ; chantier clos 30/05)*

| ID | Décision | Statut |
|---|---|---|
| NPRO-D1 | Émission depuis `fn_v2_extend_core` (couvre tous les wrappers) | ✅ |
| NPRO-D2 | **Un** événement par action portant `line_nos[]` (pas un mail par item) | ✅ |
| NPRO-D4 | **Retrait** du trigger header `trg_notify_emprestimo_prorrogacao` (DROP) | ✅ |
| NPRO-D5 | Texte `loan.renewed.once` reformulé « par exemplaire » × 8 locales | ✅ acté (chantier clos 30/05 ; spec alignée 02/06) |
| NPRO-D6 | Date unique si convergence, sinon liste « titre — date » | ✅ |

---

## 12. Catalogue & catalogage — `CAT` *(cluster 01/06 — addendum, hors zip d'audit)*

| ID | Décision | Statut |
|---|---|---|
| CAT-A1..A3 | Label `tract` corrigé (code interne gardé) ; palier Avançado mapping-only ; mode `simple\|advanced\|complete` sans remap | ✅ 01/06 |
| CAT-B1 | `circulation_policy`/`visibility` = `text`+CHECK (pas enum PG) | ✅ |
| CAT-B2 | `circulation_policy` conserve `ambos` | ✅ |
| CAT-B3 | `visibility` binaire {public, staff_only=arquivo} | ✅ |
| CAT-B4 | Écriture destination intégrée à la RPC d'édition d'exemplaire (pas de RPC dédiée) | ✅ |
| CAT-B5 | Doublon ISBN réseau = blocage dur + rattachement ; « Revisar o ISBN » (pas d'override self-service) | ✅ |
| CAT-B6 | Migration `exemplares` **mutualisée** avec ACQ §5.1 (une seule vague) | ✅ |
| CAT-B7 | Ordre impératif : item-grain cœur d'abord | ✅ |
| CAT-C1 | `cover_source`/`cover_license` créés (`text` nullable) | ✅ |
| CAT-C2 | Page-1-PDF = sous-paquet P3 différé | ✅ |
| CAT-C3 | Endpoint sélection→stockage dans `cover_lookup` | ✅ |
| CAT-C4 | 4ᵉ source capa `og:image` via réutilisation `fetch-url-metadata` | ✅ 01/06 |
| CAT-D1 | Une EF métadonnées à adaptateurs SRU+REST | ✅ |
| CAT-D2 | BN Brasil auto par **réutilisation** de l'EF scraper Sophia (manuel en repli) | ✅ |
| CAT-D3 | EF dédiée `authority_lookup` | ✅ |
| CAT-D4 | Formes variantes en `JSONB variant_forms` | ✅ |
| CAT-D5 | LoC = diagnostic avant réactivation | ✅ |
| CAT-D6 | `viaf`/`isni` au niveau autorité ; `wikidata` aux deux niveaux | ✅ |
| **CAT-E1** | **Refonte fiche = Track A** (spec-catalogacao-fiche-et-paliers §3). Registre déclaratif `fieldRegistry.js` : source unique des champs (`id`=clé d'état/colonne `book_drafts`, `label`=clé i18n, `tier`/`mat`/`type`/`span`/`opts`) + helpers visibilité §3.3. Lot 1. | ✅ 04/06 |
| **CAT-E2** | Registre **aligné sur la maquette normative** `maquette_fiche_catalogacao_v2.html` (fait foi pour palier × matériel) : `editora` 6 types (livro/periodico/zine/cartaz/tract/dossie) ; `issn` [periodico,artigo] ; `isbn` [livro] ; `local` 6 types ; `edicao`/`paginas` [livro,zine,dossie] ; `colecao` tier 3 [livro,tese]. Lot 2b. | ✅ 04/06 |
| **CAT-E3** | **Rendu piloté par le registre** (`CatalogFieldRenderer.jsx` : `renderField`/`renderMaterialSection`/`renderRegistryField`, `null` si invisible). BookDraftForm migré : panneaux matériels (Lot 2a) + 7 champs cœur à restriction matérielle (Lot 2b). **Reste** periódico in-grid + acquisition (Lot 2c). Réf. spec §3.1 / §9 P1. | 🟡 en cours |
| **CAT-E4** | **Intérim palier→tier** : prop `mode` binaire (CatalogacaoPage) → `catalogTier` complete→3, simple→2. Le Lot 3 (paliers ternaires, **= CAT-A3**, spec §4 / §9 P2) insérera advanced→2 et fera simple→1 ; clé `localStorage` du mode à confirmer ; retrait `.mode-complete-only`. | 🟡 intérim |
| **CAT-E5** | Spans `titulo`/`subtitulo` gardés **span 3** (layout prod) ; cible maquette (span 2 + réordonnancement du cœur) = **lisibilité (Lot 4, §7)**, pas le rendu. | 🟡 différé Lot 4 |
| **CAT-E6** | **Différés hors périmètre fiche** : (a) capa = gating par matériel (uploader **+** champ chemin **ensemble**) + champ chemin manuel co-localisé/lecture seule → **module capas** (cf. CAT-C) ; (b) circulation 3 valeurs (`loanable` booléen→enum) → exemplaires/circulation (cf. CAT-B2 `ambos`) ; (c) `viaf`/`isni`/`wikidata` tier 3 absents d'`EMPTY_FORM` → PLANNED, requiert migration+état (cf. CAT-D6) ; (d) `idioma` texte→select 8 langues = décision valeurs stockées vs données existantes ; (e) `bib_ref` omis du registre (système/compat). | 🟡 différé |
| **CAT-E7** | 7 clés i18n **nouvelles** introduites par le registre, à livrer au **Lot 5** (10 locales, `DOC-I18N-1`, spec §8) : `catalogacao.field.materialType`, `.field.author`, `.section.core`, `.section.periodical`, `.tag.core/.advanced/.complete/.material`. | 🟡 à livrer Lot 5 |

---

## 13. Réservation — `RESA`

Workflow **v3 sémantique en prod** (paquet 5b, 08–09/05). `spec-workflow-reservation-v2-negotiation` et `spec-refactor-v3-semantique` = 🔵 références historiques (doctrine absorbée).

## 14. PEB — `PEB` *(spec-cycle-vie-peb v1)*

Chantier `#ILL-lifecycle` à venir. ⚠️ Arbitrage 4 prescrit la suppression de 8 PEB de test **via SQL Editor** → tension avec DOC-DEPLOY-1/3 (voir DRIFT-5).

## 15. Profils bibliothèque — `PROF` *(spec-profils-bibliotheque-v0_7, en prod)*

Doctrines actées : ancrage géographique (§9.9.1) ; **délibération politique vs travail opérationnel** (§9.14.2) ; création objets backend v2.5 (= DOC-OBJ-2) ; doctrines PowerShell/Git (= DOC-PS-1).

## 16. Compte lecteur & autres

`HIST` (historico-retencao v1.0, #CL.8 en cours) · `NOTIFPRO` (cf. NPRO) · `CARD` (carte-lecteur, phase β en prod) · `114A` (🔵 clos 14/05 ; ⚠️ contient « 6 locales » historique). Détail à compléter au fil des chantiers.

## 17. Importações / Exportações — `IMP` *(spec-importacoes-exportacoes v0.1)*

| ID | Décision | Statut | Foyer |
|---|---|---|---|
| **IMP-1** | Module **bidirectionnel** : la page porte les deux sens — **import** (ingestion technique) ⇄ **export** (partage / sérialisation). Frontière **ACQ-Q4** maintenue : l'ingestion technique vit ici ; l'**entrée-en-collection** (provenance, exemplaires, destination) reste en Catalogação. | ✅ acté 05/06 | spec §1 |
| **IMP-2** | **Deux axes orthogonaux** : (a) **circuit** = d'où vient / où va le lot (*migração de sistema · importação de arquivo · fontes externas*), nommé par **nature du lot**, jamais par instance (BLMF, Terra Livre = simples exemples) ; (b) **format** = en quelle langue parle le lot. Le format n'est **jamais** un onglet. | ✅ acté 05/06 | spec §2–3 |
| **IMP-3** | **Format = trois plans** : *structure de transport* (ISO 2709, XML, JSON, tabulaire…) × *vocabulaire/schéma* (UNIMARC, MARC21, INTERMARC, Dublin Core, Zotero/CSL, BibTeX, RIS, ONIX, KBART, BIBFRAME…) × *modèle conceptuel*. AnarBib a **son** modèle (`book_drafts` + autorités) ; un adaptateur **mappe vers lui**, ne le reproduit pas. | ✅ acté 05/06 | spec §4 |
| **IMP-4** | **Adaptateur = décodeur de structure + mappeur de vocabulaire → `book_drafts`**, piloté par un **profil de mapping réutilisable**. Nouveau format = nouvel adaptateur (souvent une combinaison déjà connue) + profil — **pas** une nouvelle aba ; combinaison sans adaptateur → repli mapping manuel ; le **même registre sérialise** en sortie (export). | ✅ acté 05/06 | spec §5 |
| **IMP-5** | **Champs descriptifs ≠ points d'accès** : les champs descriptifs alimentent les colonnes de `book_drafts` ; les **points d'accès** (auteur, sujet) **résolvent ou créent des autorités**, jamais du texte libre. | ✅ acté 05/06 (cf. CAT-D3/D4/D6) | spec §6 |
| **IMP-6** | **Dérivation = passe de nettoyage** : tout import (surtout copy-cataloging « fontes externas ») impose un nettoyage — retrait des identifiants locaux de la source, re-pointage des autorités, traduction des notes. Cette passe **est** la **file de revisão** `book_drafts` ; aucun import ne publie directement. | ✅ acté 05/06 | spec §7 |
| **IMP-7** | **Symétrie import ↔ export** : ce qui sort est régi par les **mêmes signaux de consentement** que ce qui entre (flags `*_allowed`, dont `mutualize_allowed`) ; la **partilha numérique** par le **périmètre ILL**, et vit entre biblios fédérées (`library_partnerships`), **pas** avec les `catalog_partners`. | ✅ acté 05/06 (renvoi **ILL-1..9**) | spec §8 |
| **IMP-8** | **Assistant d'import (wizard)** : l'import par lot passe par un stepper guidé — sens + circuit → source / auto-détection (structure + vocabulaire → adaptateur) → profil de mapping → **aperçu/dry-run** (doublons ISBN/EAN, autorités à résoudre, drapeaux de périmètre) → **promotion vers la file de revisão**. La page reste un tableau de bord ; le wizard est l'action « Novo import ». | 🟡 cadré 05/06 (reste l'impl. : DDL « run d'import » + ratification rôles) | spec §9 |

> Réf. visuelle (trace, non-normative) : `maquette_importacoes_v7.html`.

---

*Fin du seed v0.1. Décisions transverses recensées : 12. Drifts ouverts : voir le rapport d'audit joint.*

*MàJ 04/06/2026 — Track A (refonte fiche catalogação) : `DOC-JSX-1` + `CAT-E1…E7`. Prompt de reprise Claude Code : `PROMPT_reprise_catalogacao_CODE.md`.*

*MàJ 05/06/2026 — chantier **Importações/Exportações** ouvert : `IMP-1…IMP-8` (§17) incarnés par `spec-importacoes-exportacoes` v0.1 (squelette). Réf. visuelle : `maquette_importacoes_v7.html`.*
