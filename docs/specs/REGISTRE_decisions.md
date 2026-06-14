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
| **NOTIF-PA0** | **#NOTIFY-Painel-acts** : 3 familles d'actes Painel modifiant le compte d'un membre sont muettes (aucune notif). Déclencheurs réels : `fn_record_membership_payment` (cotisation), `api.restrict_member`/`unrestrict_member` (restriction locale = `user_library_memberships.is_restricted`), `api.freeze_account`/`unfreeze_account` (gel global = `profiles.is_restricted`). Câblage = pattern dispatch + EF + i18n (+ in-app B3 pour restriction/gel). Débloqué par #110. Audit : `AUDIT_NOTIFY-Painel-acts_2026-06-08.md`. | ✅ **livré et vérifié 08/06** (e-mail 3 familles + levées, in-app B3, toggle) |
| **NOTIF-PA1** | **Levées notifiées** : `unrestrict`/`unfreeze` déclenchent aussi une notif au membre (e-mail + courte réplique in-app) — rétablissement de droits, par symétrie. | ✅ acté 08/06 |
| **NOTIF-PA2** | **E-mail cotisation configurable par biblio, défaut ON** (souveraineté biblio, Position 1) → nouvelle colonne `library_notification_policies.cotisation_payment_mail_enabled`. | ✅ acté 08/06 |
| **NOTIF-PA3** | **Restriction/gel = e-mail au membre OBLIGATOIRE** (B3, plancher éthique, non désactivable) ; `profile_restriction_enabled` réinterprété en **copie staff** (optionnelle), jamais en interrupteur du mail membre. | ✅ acté 08/06 |
| **NOTIF-PA4** | **Contenu** : restriction/gel = motif obligatoire + portée (locale/réseau) + date, « qui » = le collectif/la biblio (pas l'individu, anti-méga-machine) ; cotisation = montant + période de validité + méthode. | ✅ acté 08/06 |

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
| VALID-C1..C4 | Bouton « valider en lot » ; note coordenador auto-validé ; notif compte en attente ; compteur d'attente | ✅ **livré 10/06/2026** |

✅ Clôture réalignée 02/06 : pointe désormais vers `spec-multi-appartenance-lecteur` (cf. ACCT-MIGRATION) — DRIFT-2 corrigé.

> 🆕 **Livré 10/06/2026** (session MULTI P5). Validation par-appartenance, en présentiel, par le staff (canal humain premier, RES-D9) — c'est le filtre anti-infiltration (vraie personne ? camarade ?). Écran staff **unitaire** livré avec MULTI (onglet `Validações`, RPC `list_pending_validations` + `api.validate_membership`). Puis **C1** « valider en lot » + **C3** notification staff « compte en attente » (`request_membership` → event `membership_validation_requested` → e-mail biblio, CTA /painel ; pendant staff du `validation_confirmed` côté lectrice) + **C4** compteur (badge onglet + card « Inscrições pendentes » dans *Trabalho do dia*). **C2 sans code** : appartenances coordenador créées `active` par promotion d'équipe, jamais `pending` (confiance par rôle déjà acquise). Migrations `20260608154320` (validate), `20260609225414` (notif lectrice P4b), `20260610014812` (notif staff C3). Confiance **non transitive** (MULTI-γ.1) préservée : chaque biblio valide la sienne, pas d'autorité centrale.

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
| **CAT-B8** | **Phase 2 — filtre `visibility` exemplaire câblé au catalogue public (08/06)**. Compteurs déjà exemplaire-aware (P1.4a : `fn_v2_recompute_holdings_availability` dérive `book_holdings.{exemplares_total,available_count}` de `exemplares WHERE visibility='public'`). 2 trous comblés : (1) **trigger** `trg_exemplar_recompute_availability` sur `exemplares` (AFTER ins/del/upd de `visibility`\|`holding_id`) → recompute le holding via la fn canonique — comble `publish_exemplar_draft`/`discard_exemplar` qui **ne recomputaient pas** (archiver propage enfin) ; (2) **filtre de présence** `WHERE exemplares_total > 0` dans la **vue** `api.catalog_list_anon_v1` (pas la matview → grants/index/`security_invoker` préservés). 0 notice affectée aujourd'hui (237, toutes publiques) ; **lève la dépendance d'ILL-5 (§22)** et câble l'arquivo `staff_only`. Reflet catalogue au refresh cron (≤15 min). Migration `20260608143145`. | ✅ livré 08/06 |
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
| **CAT-COLL** | **Œuvre produite par une revue/collectif/groupe** → autorité de type **`collective`** (jamais `person`, jamais nom inversé type « NOM, Prénom »). **Rôle :** `autor` (**entrée principale corporative**) quand l'œuvre **émane de l'entité et paraît sous son nom** (dossier, anthologie thématique, manifeste, communiqué) — s'affiche alors en ligne auteur·rice via `v_book_authors_canonical` ; `organizador` réservé à « **Personne X (org.)** » compilant des textes d'auteur·rices **distinct·es** (lesquel·les = `autor`/`coautor`). `editora` = toujours l'**imprint matériel**, distinct du rôle intellectuel. Démonstrateur : *El Mundo libertario : Anarquismo en el Bicentenario de Proudhon* (Le Monde Diplomatique, Santiago 2009 ; éd. Aún Creemos en los Sueños) — migration `20260610192318`. **Suivi** : `v_book_authors_canonical` n'agrège que `role='autor'` → un `organizador`-seul n'apparaît pas en ligne auteur·rice (prévoir un repli « organizador » quand aucun `autor`). | ✅ acté 10/06 |
| **CAT-E1** | **Refonte fiche = Track A** (spec-catalogacao-fiche-et-paliers §3). Registre déclaratif `fieldRegistry.js` : source unique des champs (`id`=clé d'état/colonne `book_drafts`, `label`=clé i18n, `tier`/`mat`/`type`/`span`/`opts`) + helpers visibilité §3.3. Lot 1. | ✅ 04/06 |
| **CAT-E2** | Registre **aligné sur la maquette normative** `maquette_fiche_catalogacao_v2.html` (fait foi pour palier × matériel) : `editora` 6 types (livro/periodico/zine/cartaz/tract/dossie) ; `issn` [periodico,artigo] ; `isbn` [livro] ; `local` 6 types ; `edicao`/`paginas` [livro,zine,dossie] ; `colecao` tier 3 [livro,tese]. Lot 2b. | ✅ 04/06 |
| **CAT-E3** | **Rendu piloté par le registre** (`CatalogFieldRenderer.jsx` : `renderField`/`renderMaterialSection`/`renderRegistryField`, `null` si invisible). BookDraftForm migré : panneaux matériels (Lot 2a) + 7 champs cœur à restriction matérielle (Lot 2b). **Reste** periódico in-grid + acquisition (Lot 2c). Réf. spec §3.1 / §9 P1. | 🟡 en cours |
| **CAT-E4** | **Intérim palier→tier** : prop `mode` binaire (CatalogacaoPage) → `catalogTier` complete→3, simple→2. Le Lot 3 (paliers ternaires, **= CAT-A3**, spec §4 / §9 P2) insérera advanced→2 et fera simple→1 ; clé `localStorage` du mode à confirmer ; retrait `.mode-complete-only`. | 🟡 intérim |
| **CAT-E5** | Spans `titulo`/`subtitulo` gardés **span 3** (layout prod) ; cible maquette (span 2 + réordonnancement du cœur) = **lisibilité (Lot 4, §7)**, pas le rendu. | 🟡 différé Lot 4 |
| **CAT-E6** | **Différés hors périmètre fiche** : (a) capa = gating par matériel (uploader **+** champ chemin **ensemble**) + champ chemin manuel co-localisé/lecture seule → **module capas** (cf. CAT-C) ; (b) circulation 3 valeurs (`loanable` booléen→enum) → ~~exemplaires/circulation~~ **✅ levé le 06/06, livré au niveau fiche par `circulation_default` additif (cf. CAT-E11)** ; (c) `viaf`/`isni`/`wikidata` tier 3 absents d'`EMPTY_FORM` → PLANNED, requiert migration+état (cf. CAT-D6) ; (d) `idioma` texte→select 8 langues = décision valeurs stockées vs données existantes ; (e) `bib_ref` omis du registre (système/compat). | 🟡 différé |
| **CAT-E7** | 7 clés i18n **nouvelles** introduites par le registre, à livrer au **Lot 5** (10 locales, `DOC-I18N-1`, spec §8) : `catalogacao.field.materialType`, `.field.author`, `.section.core`, `.section.periodical`, `.tag.core/.advanced/.complete/.material`. | ✅ livré 05/06 |
| **CAT-E8** | **Track A complet (05/06)** : Lots 1→6 + Lot 3b (12 types matériels : tese/artigo/relatorio/zine ajoutés) livrés. Paliers ternaires `simple\|advanced\|complete` effectifs (intérim CAT-E4 levé, `.mode-complete-only` retiré). Classes `.ab-*` + segmented control (Lot 4). Ancres doublon + capa (Lot 6). i18n 10 locales. | ✅ livré |
| **CAT-E9** | **Item-grain (#MODEL-item-grain) & Track B (exemplaires/circulation) constatés DÉJÀ LIVRÉS en base** (05/06) : `consulta_linhas_v2.item_id`, `circulation_policy`/`visibility` sur `exemplares`/`exemplar_drafts` (CHECK), `ExemplarDraftForm` câblé, `api.attach_exemplar`. Le corpus était en retard sur la prod. | ✅ constaté |
| **CAT-C5** | **Module capas livré (P1/P2/P3)** : P1 clé de stockage stable (`bib_ref\|\|id`, fin des collisions `books/new/`) ; P2 colonnes `cover_source`/`cover_license` + EF `cover_lookup` (OpenLibrary/Google Books/og:image, mode `store` serveur CAT-C3) + galerie ; **P3 page-1-PDF côté CLIENT** (réutilise le pdf.js de `/public/vendor/pdfjs`) — **divergence assumée** vs spec « rasterisation serveur » (évite un bundle edge lourd ; acté 05/06). | ✅ livré |
| **CAT-G1** | **Liaison autorités↔œuvres** (spec-liaison-autorites-oeuvres v0.2, Q1–Q6 actées) : `fn_normalize_name` (tokens triés, accents repliés, IMMUTABLE) + **trigger** `book_contributors.author_id`→`book_authors` (ciblé, jamais de rebuild ; backfill 371) + RPC `suggest_author_book_matches`/`confirm_author_book_link`/`unlink_author_book` (exact-normalisé + trigramme, **validation humaine**) + outil « Rattacher aux œuvres ». | ✅ rétroactif livré |
| **CAT-I2** | **Notes bio multilingues — UI de revue (spec v0.2 §5.1, Q1/Q4)** : widget bio d'AuthorDraftForm enrichi du **workflow de revue** : badge de statut par langue (`brouillon`/`revu`/`modifié`), bascule revu↔brouillon via RPC `set_author_translation_review(author_id,lang,reviewed)` (SECURITY DEFINER, staff, migration `20260605350001`), save qui n'upserte que les langues **éditées** et (re)pose `status='draft'` (une bio modifiée doit être re-revue ; les traductions revues non touchées restent intactes). **Seed bio au publish (Q1)** : `handlePublish` upserte la bio principale du brouillon dans `author_translations` à la **locale UI** (défaut `pt-BR`), `ON CONFLICT DO NOTHING` (ne clobbe jamais une traduction revue) — fait **côté frontend** (la locale est une donnée UI ; évite un DROP+CREATE de `publish_author_draft`). i18n 5 clés `catalogacao.bio.status*`/`mark*` × 10 locales. **Divergence vs spec** : la spec suggérait le seed dans `publish_author_draft` (serveur) ; fait au frontend pour les raisons ci-dessus. | ✅ livré |
| **CAT-G3** | **Volet préventif (Q4) livré** : sélecteur d'autorité par ligne contributeur dans BookDraftForm. Colonne `book_draft_contributors.author_id` (FK→authors, `ON DELETE SET NULL`) ; RPC `search_authors_by_name(text,int)` (exact-normalisé / préfixe / substring / trigramme, `search_path` incluant **`extensions`** — piège #2 ; gating staff) ; `fn_seed_draft_contributors` copie aussi `author_id` à la reprise ; `fn_sync_book_contributors_on_publish` fait **primer l'`author_id` explicite** du brouillon (COALESCE, filet par nom en repli). UI : bouton « Lier » → recherche → badge lié + délier. i18n 7 clés `catalogacao.authlink.*` × 10 locales. **Pose `author_id` dès le catalogage → empêche les contributeurs orphelins à la source** (complète le curatif G1, prévient le bug réactivement patché côté catalogue). | ✅ livré |
| **CAT-G2** | **Contributeurs (fiche & flux)** : fiche livre publique affiche TOUS les contributeurs (`get_book_contributors_public`, liés en lien + non liés en texte, #FICHE-AUTEURS-INCOMPLETE) ; flux brouillon→publié comblé par 2 triggers (seed à la reprise + sync au publish **avec préservation des `author_id` par nom normalisé**). `publish_book_draft` ne touchait pas `book_contributors` (trou comblé). | ✅ livré |
| **CAT-H1** | **Fusion de doublons** (spec-doublons-detection-fusion v0.1) : table d'audit `merge_log` + `suggest_author_duplicates`/`merge_author` (réassigne book_authors/contributors/translations/aliases/drafts, conflit bio lang = garder canonique) + `suggest_book_duplicates`/`merge_book` (holdings : fusion même biblio / repoint sinon ; circulation prêts/réservations/PEB repointée ; wishlist dedupe ; recompute `fn_v2_recompute_holdings_availability`). Validation humaine. Dogfood OK (Castoriadis, Educar Para Emancipar). | ✅ livré |
| **CAT-I1** | **Socle « Ateliers d'autorités »** (spec-autorites-notes-bio-multilingues v0.2) : `author_translations` étendue (`status` draft/reviewed + `reviewed_by/at`, CHECK `lang` sur 10 locales) ; **édition bio post-publication uniquement** (clé `published_author_id`, jamais l'id de brouillon — collision corrigée) ; `variant_forms jsonb` (ancre Track D). GRANT écriture `authenticated` rétabli (policy `librarian_write` jadis inopérante). | ✅ socle livré |
| **CAT-D5a** | **Réactivation LoC gardée (P1 Track D)** : diagnostic — endpoint SRU `lx2.loc.gov/sru/lcdb` (minuscules) cassé après migration FOLIO (juin 2025), le MetaProxy IndexData attend `LCDB` (majuscules). Index titre (`dc.title`/`bath.title`) instables côté LoC ; `bath.isbn`/`bath.author`/`bath.issn` fonctionnent mais avec des 502 intermittents. Fix : (1) URL corrigée `sru/LCDB` ; (2) index CQL `bath.title`/`bath.author` (au lieu de `dc.*`) ; (3) retry unique sur 502 (instabilité MetaProxy) ; (4) défaut `ENABLE_LOC` → `true`. Le retour partiel existant (catch → status `error`) protège l'UX. | ✅ livré |
| **CAT-D5b** | **Adaptateur REST Open Library + Wikidata (P2 Track D)** : `catalog_metadata_lookup` étendu à 7 sources. **Open Library** : `buildUrl + parser` (ISBN + titre/auteur → candidats riches, `openlibrary_json`). **Wikidata** : mode `query` custom (2 appels : MediaWiki `haswbstatement:P31=Q7725634` + `wbgetentities`) ; titre/auteur seulement (ISBN = couverture WD trop sparse) ; auteur extrait de la description (`book by ...`) ; Q-id conservé comme passerelle vers P4 autorités. Scoring `+1` pour les deux (sources complémentaires). Toggles env `ENABLE_OPENLIBRARY`/`ENABLE_WIKIDATA` (défaut `true`). | ✅ livré |
| **CAT-D5c** | **BN Brasil fédéré dans « Buscar metadados » (P3 Track D)** : `runCatalogLookup` appelle `catalog_metadata_lookup` ET `bn_isbn_lookup` en **parallèle** (`Promise.allSettled`). Les résultats BN sont normalisés en candidats standard (`normalizeBnToCandidate` : title:subtitle split, publication parsing, confidence scoring côté client) et fusionnés dans le panel unifié (sources pills + candidate list trié par confiance). Le bouton « Buscar na BN » reste en repli manuel (spec §4.2). L'UI affiche désormais **8 sources** : BNE, BnF, DNB, ICCU/SBN, LoC, Open Library, Wikidata, BN Brasil. | ✅ livré |
| **CAT-D5d** | **EF `authority_lookup` + Atelier autorités (P4 Track D)** : nouvelle EF Deno `authority_lookup` utilisant **Wikidata uniquement** (VIAF API inaccessible depuis juin 2025 — renvoie 403/HTML après refonte Next.js). Recherche de personnes par nom (`haswbstatement:P31=Q5`) puis `wbgetentities` (labels, aliases, claims). Extrait : `wikidata_id`, `viaf_id` (P214), `isni` (P213), `birth_year`/`death_year` (P569/P570), **`variant_forms`** (labels + aliases par langue, 14 langues). UI dans AuthorDraftForm (tier Completo) : bouton « Buscar autoridade (Wikidata) » → panel de candidats → clic lie l'autorité (remplit viaf/isni/wikidata + variant_forms + source). `variant_forms` ajouté au payload de sauvegarde du brouillon. **Fuite à la publication colmatée (close-before-open)** : `publish_author_draft` ne copiait pas `variant_forms` du brouillon vers `authors` (fonction antérieure à la colonne, jamais repatchée — vérifié en prod, `variant_forms` absent du corps) → migration `20260605330000` (CREATE OR REPLACE signature identique, privilèges préservés, DO-block de vérif). i18n 8 clés × 10 locales (P5). | ✅ livré |
| **CAT-E11** | **Audit spec-catalogacao-fiche-et-paliers — complétion (06/06)** : passe d'alignement de BookDraftForm sur la spec. **§7.3** surface/scrim portée au niveau **`.cat-panel.active`** → tous les onglets (Documento/Autoria/Indexação/Fila/Lotes/Catálogo) reposent sur un panneau sombre `.ab-sheet`. **§7.5** boutons migrés `.cat-btn`+inline → kit `.ab-button` (+ variantes additives `--ghost`, `--sm` composable) sur **toute la page catalogação** (BookDraftForm + Author/Exemplar/Queue/CatalogPanel/CatalogacaoPage, P5 inclus, 67 boutons). `.cat-btn` CSS conservé pour le reste de l'app (Biblioteca/Rede/Importações, hors périmètre spec). **§8** chaînes en dur externalisées (messages `catalogacao.msg.*` + labels visibles + sous-formulaire ressources numériques + panneau BN/lookup + résidus §8c : options `<select>`, raisons de cote, fallbacks `'Título'` — ~85 clés × 10 locales). Seuls les **descripteurs ISBD** restent en dur (données bibliographiques standard écrites dans la notice, pas du chrome). **§5.6 — circulação 3 valeurs LIVRÉE (lève le différé CAT-E6)** : colonne `circulation_default` (emprestavel/consulta/ambos) sur `book_drafts`+`books`, **stratégie additive+synchro** (`loanable` conservé synchronisé `= circ <> consulta` → dispo/MV catalogue/BookPage inchangés) ; **1 trigger AFTER-publish** propage au livre publié (publish_book_draft NON touchée) ; seed exemplaire précis ; migration `20260606114851` (1er horodatage UTC **réel** exact). | ✅ livré |
| **CAT-E12** | **Bug prod : publication bloquée pour 9 des 12 types de matériel (06/06)** + **gating périodique**. (1) `books_tipo_material_check` n'autorisait que l'ancien set `['livro','periodico','folheto','arquivo','zine','outro']` ; l'extension Track A à 12 types (CAT-E8) a élargi le form + `book_drafts` (qui n'a **aucun** CHECK sur tipo_material) mais **pas `books`** → brouillon OK, **publication KO** (`audiovisual`/`tract`/`cartaz`/`audio`/`recurso_digital`/`dossie`/`tese`/`artigo`/`relatorio`) avec « violates check constraint books_tipo_material_check ». Repro : DVD « Batalha em Seattle ». Fix : migration `20260606124642` élargit le CHECK aux 12 types + legacy (folheto/arquivo/outro). **Doctrine : toute addition d'un type de matériel doit mettre à jour le CHECK `books` (le seul porteur ; `book_drafts` non contraint).** (2) Champs périodique in-grid fuyaient dans tous les types (rendus via `renderRegistryField` sans `mat` propre) → `mat:['periodico']` ajouté. | ✅ livré |
| **CAT-E13** | **Modèle de champs — dédoublonnage langue + portée CDD (06/06)** : (1) **une seule langue** — le champ cœur `idioma` (mat:'all') porte la langue de TOUS les types ; les champs de section `audio_language` (« Idioma falado ») et `audiovisual_language` (« Idioma », doublon strict du cœur) **retirés** du registre (l'AV garde `legendas`, distinct). Doctrine : ne pas réintroduire de champ « langue » dans une section matérielle. (2) **CDD scopée** par `CDD_MAT` = `['livro','periodico','tract','cartaz','dossie','tese','artigo','relatorio','zine']` — exclue des **médias natifs** (`audiovisual`/`audio`/`recurso_digital`) où la Dewey ne s'applique pas ; **conservée pour les thèses**. Audit complet des 12 types : sections matérielles toutes présentes (tese=universidade/orientador, artigo, relatorio, zine…), aucun autre doublon de champ cœur. Gaps signalés (non traités, = additions à trancher) : `editora` absent de l'audiovisuel (distributeur d'un film sans champ) ; `paginas` absent des thèses. | ✅ livré |
| **CAT-E14** | **Admin réseau — attribuer une notice + ses exemplaires à une bibliothèque (06/06)** : nouvelle action cross-bibliothèque en **tête de fiche document** (BookDraftForm), visible seulement pour l'admin réseau sur une notice **publiée**. Sélecteur des biblios « catalogue présent » (`list_catalog_libraries` = `catalog_mode='network_published'`) + RPC `network_admin_reassign_book_to_library(book, library)` (gardée `fn_caller_is_network_admin()`) = **transfert complet** : `owner_library`/`holder_library` ← nom cible, **tous les exemplaires** déplacés vers le holding (get-or-create) de la cible, recompute des compteurs, **journal critique** `fn_log_cross_library_action` → notif staff local (RES-Q6). Anciens holdings vidés conservés (pas de DROP, anti-effet-de-bord FK). i18n `catalogacao.reassign.*` × 10 locales. | ✅ livré |
| **CAT-E10** | **Fiche v3 — aperçu live (TRA-v3, `maquette_fiche_catalogacao_v3.html`)** : par-dessus Track A (livré sur la maquette v2), implémentation des ajouts v3 dans BookDraftForm. Disposition **2 colonnes** (`.ab-work` : formulaire à gauche, **aperçu live sticky** à droite) montrant la fiche telle qu'elle paraîtra au catalogue (type, circulation, titre, auteur·rice/année, éditeur/lieu/langue, CDD, assuntos, statut brouillon), recalculé à chaque frappe (re-render React). **Jauge « essenciais N/3 »** (titre, auteur, année) dans l'en-tête de l'aperçu, colorée selon complétude. **Validations légères** affichées dans l'aperçu (ISBN 10/13 chiffres ; année 1700-2027). Les **hints de palier** existaient déjà (`catalogacao.modeSimple/Advanced/Complete` dans CatalogacaoPage). i18n 8 clés `catalogacao.preview.*`/`validate.*` × 10 locales. | ✅ livré |

---

## 13. Réservation — `RESA`

Workflow **v3 sémantique en prod** (paquet 5b, 08–09/05). `spec-workflow-reservation-v2-negotiation` et `spec-refactor-v3-semantique` = 🔵 références historiques (doctrine absorbée).

## 14. PEB — `PEB` *(spec-cycle-vie-peb v1)*

Chantier `#ILL-lifecycle` à venir. ⚠️ Arbitrage 4 prescrit la suppression de 8 PEB de test **via SQL Editor** → tension avec DOC-DEPLOY-1/3 (voir DRIFT-5).

## 15. Profils bibliothèque — `PROF` *(spec-profils-bibliotheque-v0_7, en prod)*

Doctrines actées : ancrage géographique (§9.9.1) ; **délibération politique vs travail opérationnel** (§9.14.2) ; création objets backend v2.5 (= DOC-OBJ-2) ; doctrines PowerShell/Git (= DOC-PS-1).

## 16. Compte lecteur & autres

`HIST` (historico-retencao v1.0, #CL.8 en cours) · `NOTIFPRO` (cf. NPRO) · `CARD` (carte-lecteur, phase β en prod) · `114A` (🔵 clos 14/05 ; ⚠️ contient « 6 locales » historique). Détail à compléter au fil des chantiers.

## 17. Importações / Exportações — `IMP` *(spec-importacoes-exportacoes v0.2)*

| ID | Décision | Statut | Foyer |
|---|---|---|---|
| **IMP-1** | Module **bidirectionnel** : la page porte les deux sens — **import** (ingestion technique) ⇄ **export** (partage / sérialisation). Frontière **ACQ-Q4** maintenue : l'ingestion technique vit ici ; l'**entrée-en-collection** (provenance, exemplaires, destination) reste en Catalogação. | ✅ acté 05/06 | spec §1 |
| **IMP-2** | **Deux axes orthogonaux** : (a) **circuit** = d'où vient / où va le lot (*migração de sistema · importação de arquivo · fontes externas*), nommé par **nature du lot**, jamais par instance (BLMF, Terra Livre = simples exemples) ; (b) **format** = en quelle langue parle le lot. Le format n'est **jamais** un onglet. | ✅ acté 05/06 | spec §2–3 |
| **IMP-3** | **Format = trois plans** : *structure de transport* (ISO 2709, XML, JSON, tabulaire…) × *vocabulaire/schéma* (UNIMARC, MARC21, INTERMARC, Dublin Core, Zotero/CSL, BibTeX, RIS, ONIX, KBART, BIBFRAME…) × *modèle conceptuel*. AnarBib a **son** modèle (`book_drafts` + autorités) ; un adaptateur **mappe vers lui**, ne le reproduit pas. | ✅ acté 05/06 | spec §4 |
| **IMP-4** | **Adaptateur = décodeur de structure + mappeur de vocabulaire → `book_drafts`**, piloté par un **profil de mapping réutilisable**. Nouveau format = nouvel adaptateur (souvent une combinaison déjà connue) + profil — **pas** une nouvelle aba ; combinaison sans adaptateur → repli mapping manuel ; le **même registre sérialise** en sortie (export). | ✅ acté 05/06 | spec §5 |
| **IMP-5** | **Champs descriptifs ≠ points d'accès** : les champs descriptifs alimentent les colonnes de `book_drafts` ; les **points d'accès** (auteur, sujet) **résolvent ou créent des autorités**, jamais du texte libre. | ✅ acté 05/06 (cf. CAT-D3/D4/D6) | spec §6 |
| **IMP-6** | **Dérivation = passe de nettoyage** : tout import (surtout copy-cataloging « fontes externas ») impose un nettoyage — retrait des identifiants locaux de la source, re-pointage des autorités, traduction des notes. Cette passe **est** la **file de revisão** `book_drafts` ; aucun import ne publie directement. | ✅ acté 05/06 | spec §7 |
| **IMP-7** | **Symétrie import ↔ export** : ce qui sort est régi par les **mêmes signaux de consentement** que ce qui entre (flags `*_allowed`, dont `mutualize_allowed`) ; la **partilha numérique** par le **périmètre ILL**, et vit entre biblios fédérées (`library_partnerships`), **pas** avec les `catalog_partners`. | ✅ acté 05/06 (renvoi **ILL-1..9**) | spec §8 |
| **IMP-8** | **Assistant d'import (wizard)** : l'import par lot passe par un stepper guidé — sens + circuit → source / auto-détection (structure + vocabulaire → adaptateur) → profil de mapping → **aperçu/dry-run** (doublons ISBN/EAN, autorités à résoudre, drapeaux de périmètre) → **promotion vers la file de revisão**. La page reste un tableau de bord ; le wizard est l'action « Novo import ». | 🟡 cadré 05/06 ; restes tranchés 08/06 (IMP-9/14/15) | spec §9 |
| **IMP-9** | **Run d'import** = **`ingest.partner_catalog_import_runs`** (⚠️ **corrigé 08/06** : déjà construit, pas de nouvelle table `catalog_import_runs`). Statut, compteurs, `summary`, `error_log`. **Dry-run = le staging** `ingest.partner_catalog_staging_rows`. Pipeline create→dispatch(EF)→staging→review→promote (`fn_bulk_create_book_drafts_from_run`) **déjà câblé**. | ✅ acté 08/06 (corrigé) | spec §12 ; CADRAGE 08/06 |
| **IMP-10** | **Profils de mapping** = table **`ingest.import_mapping_profiles`** {name, scope library\|network, library_id, structure, vocabulaire, mapping **jsonb**}. ⚠️ aujourd'hui mapping **codé en dur** dans l'EF parser → IMP-10 = l'EF consulte la table + UI. Portée biblio défaut, réseau optionnel. | ✅ acté 08/06 (corrigé) | spec §12 |
| **IMP-11** | **Adaptateurs hybrides** : registre déclaratif **`ingest.import_adapters`** + logique de décodage **en code** (EF parser CSV/TSV/RIS déjà ; `detected_format`/`parser_version`). Détection auto = la **structure** ; vocabulaire déclaré. Priorité : (a) CSV/TSV/RIS (faits) + Zotero-CSL + UNIMARC ISO2709 ; (b) Dublin Core/MARCXML/OAI ; (c) MARC21/BIBFRAME. | ✅ acté 08/06 (corrigé) | spec §12 |
| **IMP-12** | **Autorités au dry-run** : auto-match (`authority_lookup`/CAT-D3) ; non résolus **non bloquants** → `book_drafts` `review_status=pending_review` + drapeau, résolution ensuite en Catalogação (IMP-6 + ACQ-Q4). | ✅ acté 08/06 | spec §12 |
| **IMP-13** | **Exportação de lote** : périmètre catalogue/collection/sélection ; formats = couche adaptateur en sens inverse (MARC21/MARCXML/DC/UNIMARC/CSV/JSON/BibTeX) ; 1 RPC/EF de sérialisation. Verrou consentement régi par §8/ILL-1..9 (ne contourne rien). | ✅ acté 08/06 | spec §12 |
| **IMP-14** | **Rôles** : `coordenador` lance import + promeut + exporte + gère relations partenaires/`digital_share` (PARTNER-D7) ; `librarian` consulte + imports fichier simples. Ratification `spec-gouvernance-roles`. | ✅ acté 08/06 | spec §12 |
| **IMP-15** | **Articulation tableau de bord / wizard** : la page v7 (`maquette_importacoes_v7`) est **canonique** (porte le modèle) ; le wizard est l'action guidée lancée d'elle. **Ordre** : bâtir la page v7 d'abord (fige le modèle + backend), **puis re-dériver le wizard** (`maquette_wizard_import_v1`→v2). | ✅ acté 08/06 | spec §12, §13 |

> Réf. visuelle (trace, non-normative) : `maquette_importacoes_v7.html`.
>
> **Foyer du chantier.** Ces décisions `IMP-1..8` **remplacent** les arbitrages `IMP-A1..A5` du `CADRAGE_importacoes_module_2026-06-04` (trace, périmée par préséance : registre > trace) ; les 6 points ouverts ont été **tranchés le 08/06** (`IMP-9..15`, spec v0.2 §12) ; reste l'implémentation **par lots** (spec §13). On ne suit plus le schéma `IMP-A*`.

---

## 18. OPAC / catalogue de découverte — `OPAC` *(spec-catalogue-decouverte v0.1, spec-notice-autorite-enrichie v0.1)*

| ID | Décision | Statut |
|---|---|---|
| **OPAC-AXIS1** | **Axe de découverte v1 = CDD** (facette + étagères thématiques, libellés localisés) + facettes **auteur** & **décennie**. Confronté aux données (08/06) : catalogue public = **237 notices / 1 biblio**, `assuntos` **2/237** (vide, non normalisé) vs **CDD 72 %** (signal réel, 335=anarchisme=58). Nuage de sujets (#OPAC8/#AUT2) **différé** (data-blocked) → réactivé par OPAC-ATL1. | ✅ acté 08/06 |
| **OPAC-F1** | Compteurs de facettes = **RPC `api.catalog_facets_v1(filters jsonb)→jsonb`** (tous compteurs en un appel), `STABLE SECURITY INVOKER` + REVOKE (DOC-OBJ-2), agrégée sur `catalog_list_anon_v1`/`_session_v1` — **jamais** la vue réseau (INV-1/DOC-PERIM-1). Écarte le `count` PostgREST par facette et l'agrégation client. | ✅ acté 08/06 |
| **OPAC-W1** | Favoris = **`user_wishlist` serveur** (déjà en prod via BookPage). Audit RLS **fait** (08/06) : RLS active, policy unique `auth.uid()=user_id`, `anon` sans grant → isolé staff/réseau (INV-2). Reste : **`WITH CHECK` explicite** + bouton sur la liste (#OPAC9). | ✅ audité 08/06 |
| **OPAC-ATL1** | Autorité **matière** (étape 2). **Collectivité = déjà couverte** par `authors.authorityType='collective'`. **Livré (P1-P3, 08/06)** : `subjects` (thésaurus jsonb `label_i18n` hiérarchique, **29 sujets anarchistes** seedés, 13 en hiérarchie) + `book_subjects` + `book_draft_subjects` (RLS catalogação) + RPC `api.search_subjects` + trigger auto-slug + `fn_sync_book_subjects_on_publish` + picker `SubjectAuthorityPicker` (BookDraftForm) + nuages #OPAC8/#AUT2. Reprise de l'`assuntos` texte **non faite** (le picker peuple au catalogage ; nuages vides au départ). | ✅ livré 08/06 (P1-P3) |
| **OPAC-AGG1** | Agrégation sujets **mutualisée (D4)** : `api.catalog_facets_v1` étendue (clé `subjects` + filtre `subject`, sémantique expand) pour le nuage catalogue ; `api.author_subjects_v1(author_id)` pour la page auteur·rice. Cloisonnement INV-1 conservé. | ✅ livré 08/06 (P3) |
| **OPAC-UI1** | Blocs enrichis notice/autorité (#OPAC4/6, #AUT1/4) en **sections déroulantes** (cohérent AnarBib, mobile #MOBILE), pas en onglets. | ✅ acté 08/06 |
| **OPAC-SIM1** | Similaires (#OPAC4) / réseau auteur·rices (#AUT1) = recommandation **par contenu seul** (auteur·CDD·collection), jamais comportementale, sans log de navigation (INV-1/3/5). RPC serveur `api.similar_books`/`api.similar_authors` (top-N + score). | ✅ livré 08/06 |
| **OPAC-RSS1** | Flux RSS de recherche (#OPAC11) **différé** (anti-tracking : l'URL encode la requête en clair). `mailto:` côté client OK. | 🟡 différé |
| **OPAC-SEQ1** | Séquence : **étape 1 (v1)** = quick wins frontend (#OPAC1, #AUT3, #OPAC10, #OPAC9 sur la liste) + facettes CDD/auteur/décennie + #OPAC4/#AUT1 + #OPAC6/#AUT4 (sections) ; **étape 2** = OPAC-ATL1 → débloque #OPAC8/#AUT2. Top-N facettes = **15 + « plus… », tri par fréquence**. | ✅ acté 08/06 |

> Foyer : ces décisions priment sur la trace `CADRAGE_OPAC_chantier_2026-06-07.md` (registre > trace, désormais 🔵 historique — contenu gradué ici). Confrontation specs↔code (frontend lu + backend sondé le 08/06) détaillée dans ce cadrage.
>
> **Livraison (08/06).** **Étape 1** (découverte) en prod : #OPAC1/4/6/7/9/10, #AUT1/3/4 ; RPC `api.catalog_facets_v1` (facettes CDD/auteur/décennie) + `api.similar_books`/`api.similar_authors` ; affinages (libellés CDD curés `catalog.cdd.div.*`, blocs catalogue escamotables, bandeau réseau auteur·rice). **Étape 2** (autorité matière) : backend en prod + frontend déployé (P1-P3, cf. OPAC-ATL1/OPAC-AGG1). **Reste** : #OPAC11 RSS (OPAC-RSS1, différé anti-tracking) ; `WITH CHECK` explicite sur `user_wishlist` (durcissement mineur, RLS déjà sûre) ; reprise de l'`assuntos` texte vers l'autorité matière (non prioritaire, le picker peuple au fil de l'eau). **Garde-fou opérationnel constaté** : `deploy-pages` (Codeberg Pages) **instable par intermittence** ; un échec transitoire n'altère pas `main` (push ≠ déploiement) — un re-run vert republie tout `main`. Vérifier l'**icône** de statut, pas la durée d'étape.

---

## 19. Chantier-cadre Biblioteca — `BIBLIO` *(trace : `journal/chantiers/CHANTIER_audit_biblioteca_parite_doctrinale_2026-05-21.md`)*

| ID | Décision | Statut |
|---|---|---|
| **BIBLIO-CLOSE** | **Chantier-cadre Biblioteca CLOS le 08/06/2026** sur sa mission (12 onglets fonctionnels, parité doctrinale, transports mail câblés). Dernière réserve = **étape 8** (mails EA-13/14/19) livrée et vérifiée de bout en bout, débloquée par la clôture de #110 (Brevo→Resend). EA-13 = RPC `fn_send_weekly_report_now` + bouton « Enviar relatório » recâblé sur `notify-weekly-report` ; EA-14 = cron hebdo actif (`anarbib-notify-weekly-report-weekly`) ; EA-19 = déjà livré (`fn_task_invite`). | ✅ acté 08/06 |
| **BIBLIO-9** | **EA-12 phase 2** (parité fonctionnelle PEB, ~45 fn JS) = **DIFFÉRÉE / gelée**, conditionnée au retour d'usage réel BLMF↔BTL en prod. Hors chantier-cadre, ticket dormant au backlog ; ne se rouvre que sur manque concret constaté. | ✅ acté 08/06 (différé) |
| **BIBLIO-10** | **EA-11** (parité HTML radicale des échanges, ~118 fn JS, refonte intégrale) = **NON RETENUE par défaut**. Panneau React des échanges jugé fonctionnellement suffisant ; répliquer l'exhaustivité de l'ancien HTML n'est pas un objectif du réseau. Réouvrable seulement sur décision délibérée. | ✅ acté 08/06 (non retenu) |

> Foyer normatif de la clôture ; la cartographie (`decisions/…`) en est la trace détaillée (§6.4) — registre > trace.

---

## 20. Multi-appartenance lecteur — `MULTI` *(spec-multi-appartenance-lecteur v0.3)*

| ID | Décision | Statut |
|---|---|---|
| **MULTI-MODEL** | Appartenance = `(user_id, library_id)` + attributs locaux ; clé composée. | ✅ acté |
| **MULTI-A.2 (PRIMARY)** | Biblio principale = `is_primary` existant + contrainte unique partielle (au plus un `true`/`user_id`). | ✅ acté |
| **MULTI-A.2bis** | Bascule du sélecteur éphémère (session) ; re-marquage de la primaire = action explicite séparée. | ✅ acté |
| **MULTI-A.4** | Sortie volontaire distincte du retrait staff : `suspended` / `left_with_pending_circulation` / `terminated`. | ✅ acté |
| **MULTI-STATUS** | 8 statuts (4 existants + 4 nouveaux `suspended`/`left_with_pending_circulation`/`terminated`/`pending_validation`) ; CHECK à étendre. | ✅ acté |
| **MULTI-B.1/B.2** | Sélecteur de biblio courante à l'entrée de `/conta`, persistance `sessionStorage` ; bandeau de contexte + bascule `--brand-*` de la biblio courante. | ✅ acté |
| **MULTI-Z19** | Sélecteur + bandeau réservés au multi-biblio : masqués en mono, apparaissent dès 2 appartenances. | ✅ acté |
| **MULTI-B.3** | Lecture agrégée toutes biblios, action contextuelle (l'action s'attache à la biblio courante). | ✅ acté |
| **MULTI-C.1–C.4** | Rôle, restrictions, cotisations, plafonds : strictement par biblio, sans agrégation ni transfert de privilège. | ✅ acté |
| **MULTI-F.1** | 5 conditions pour engager une circulation dans X (appartenance active, validation physique par-appartenance, pas de restriction, cotisation à jour, plafonds non atteints) ; action cross-contexte = refus + proposition de bascule. | ✅ acté |
| **MULTI-D.1** | Même titre dans deux biblios : toléré, avertissement non-bloquant, jamais bloqué ; la biblio ne coordonne pas. | ✅ acté |
| **MULTI-E.2** | Numéro lectrice par appartenance, format libre, `UNIQUE (library_id, local_reader_number)`, saisie staff à la validation ; UUID auth transverse inchangé. | ✅ acté |
| **MULTI-F.2** | Profil transverse (nom, e-mail, langue) = souveraineté lectrice seule, sans validation biblio. | ✅ acté |
| **MULTI-E.3** | Transparence minimale par défaut (existence des appartenances) ; enrichissement via partenariat stabilisé (§21), opt-out renvoyé à `PARTNER`. | ✅ acté |
| **MULTI-β.1** | Première auto-inscription libre ; toute inscription supplémentaire exige ≥ 1 appartenance déjà validée (anti-inscription parallèle malveillante). | ✅ acté |
| **MULTI-γ.1** | Non-cascade : biblio dissoute n'effondre pas les autres appartenances (confiance non transitive). | ✅ acté |
| **MULTI-F.3** | `user_notification_preferences` en clé composée `(user_id, library_id)` pour les préfs liées à une biblio, transverses globales (hybride). | ✅ acté |
| **MULTI-Z15** | Propagation du contexte au backend = paramètre RPC explicite `p_library_id`. | ✅ acté |
| **MULTI-ArbB** | `history_enabled` synchronisé par trigger avec les préférences de rétention #CL.8 (la spec rétention prime). | ✅ acté |
| **MULTI-Z23** | `fn_my_account_status` garde la vérité de la primaire, complété par `fn_my_memberships_status` (RPC par-biblio). | ✅ acté |
| **MULTI-MIGRATION** | Aucune migration auto des lectrices existantes ; deux comptes test BTL traités manuellement. | ✅ acté |

> Foyer : design dans `docs/specs/spec-multi-appartenance-lecteur.md` (v0.3, charpente figée) ; trace `docs/journal/cadrages/CADRAGE_spec-multi-appartenance-lecteur_2026-05-31.md`. Registre > trace.

> ✅ **Implémenté & déployé 08-10/06/2026** (session MULTI P5). **Backend** : P1 modèle 8 statuts + validation par-appartenance + n° local + journal (`20260608145936`) ; P2 statut par biblio `fn_my_memberships_status` (`20260608151435`) ; P3 gate de circulation `fn_membership_can_engage_circulation` + triggers emprunt/consulta — MULTI-F.1 cond. 1-4 (`20260608153720`) ; P4 auto-inscription `request_membership` (garde β.1) + validation staff `validate_membership` (`20260608154320`). **Frontend (P5)** : onglet « Mes biblios » (TabBiblios), bandeau de contexte « biblio courante » ≥2 appartenances (MULTI-B.1/B.2/Z19, re-thème + sessionStorage via LibraryContext), auto-inscription lectrice, UI validation staff (onglet Validações). **#CL.10 / B.3 / D.1** : lecture agrégée — tag biblio d'origine par ligne de circulation + signal « même titre dans 2 biblios » (frontend pur, résolution `library_id`→biblio côté client ; commit `49d464a`). **Notifs e-mail 10 langues** : `validation_confirmed` (lectrice, P4b) + `membership_validation_requested` (staff, VALID-C3). **MULTI-F.1 cond. 5** (plafonds de circulation simultanée par lectrice ET par biblio) implémentée par une session parallèle (`4b5934d`, 10/06) — les **5 conditions de la porte de circulation sont désormais posées**. §21 PARTNER : **socle backend P1→P4 livré** (cf. §21) ; reste les UI coordenador/`conta` (P5-P6). Détail validation physique → §9 VALID.

---

## 21. Partenariat bibliothèques — `PARTNER` *(spec-partenariat-biblios v0.3)*

| ID | Décision | Statut |
|---|---|---|
| **PARTNER-D1** | Consentement lectrice : opt-in explicite **par partenariat** ; défaut = transparence minimale. | ✅ acté |
| **PARTNER-D2** | Granularité : activation **droit par droit** côté biblios (cases réciproques) ; consentement lectrice au niveau du partenariat, pas case par case. | ✅ acté |
| **PARTNER-D3** | Orthogonalité au cercle : aucun partenariat ne se déduit d'un cercle commun ; le cercle facilite socialement mais ne crée jamais le droit. | ✅ acté |
| **PARTNER-D4** | Symétrie stricte : un seul jeu de droits réciproques, même périmètre dans les deux sens, attaché au partenariat-paire `{A,B}` (anti-pouvoir). | ✅ acté |
| **PARTNER-D5** | Révocation : partage = visibilité conditionnée par RLS, jamais copie ; rupture ferme l'accès sans résidu + audit (artefacts ILL transmis exceptés). | ✅ acté |
| **PARTNER-D6** | Périmètre : droits réservés **biblio↔biblio AnarBib** ; collectifs `catalog_partners` restent déclaratifs, sans droits internes. | ✅ acté |
| **PARTNER-D7** | Cycle de vie : proposition/acceptation réservées au `coordenador` ; activation **bilatérale** ; rupture **unilatérale** tracée. | ✅ acté |
| **PARTNER-D8** | Consentement révocable depuis `/conta` (effet immédiat RLS) ; re-sollicitation **vers le haut** seulement (ajout de droit). | ✅ acté |
| **PARTNER-D9** | Droits portés par table de jonction `partnership_rights (partnership_id, right_key)` sous CHECK/enum ; ajouter un droit = une valeur, pas une migration. | ✅ acté |

> Foyer : `docs/specs/spec-partenariat-biblios.md` v0.3 (charpente figée) ; trace `docs/journal/cadrages/CADRAGE_partenariat_stabilise_2026-06-02.md`. Registre > trace.

> ✅ **Socle backend livré 10/06/2026** (session Catalogação work completion ; modèle « enrichir `library_partnerships` + trigger de symétrie », conforme spec §10/§13, pas de table de partenariat séparée). **P1** socle : statut de cycle de vie + `config_version` sur `library_partnerships` ; `partnership_rights` (D9) ; `partnership_break_log` immuable (D5) ; triggers de symétrie statut+droits `{A→B}`↔`{B→A}` (D4) — `20260610053519`. **P2** RPC cycle de vie `fn_partnership_propose/accept/refuse/break/set_right` (D7 ; activation bilatérale, rupture unilatérale tracée ; `set_right` bump `config_version` à l'ajout) — `20260610054308`. **P3** consentement lectrice : `reader_partnership_consent` versionné + `fn_partnership_consent`/`fn_partnership_revoke_consent` + helpers `fn_partnership_canonical_id`/`fn_reader_consent_valid` (D1/D8) — `20260610073931`. **P4** transparence enrichie conditionnée (Zone 21) : garde `fn_partnership_transparence_active` + RPC painel `fn_painel_reader_other_memberships` (minimal par défaut, enrichi sous partenariat actif ∧ droit `transparence` ∧ consentement) — `20260610082627` (P4a) + carte « autres appartenances » dans `TabLeitor` (P4b). Chaque sous-lot validé end-to-end (dry-run authentifié). **Reste** : UI coordenador proposer/accepter/rompre + cases de droits (P5) ; encart `/conta` + notifications (P6). ⚠️ **P4a appliquée MANUELLEMENT** le 10/06 (SQL + ligne `schema_migrations` posée à la main) pendant une panne Woodpecker — idempotente, sautée au prochain `db push` ; le frontend P4b a dû être publié via `npm run deploy` manuel pour la même raison.

---

## 22. Prêt inter-bibliothèques / partage numérique — `ILL` *(spec-flux-partage-numerique v0.2)*

| ID | Décision | Statut |
|---|---|---|
| **ILL-1** | Périmètre = matériel gris non commercialisé (affiches, tracts, brochures) ; ouvrages à ISBN/ISSN hors cible. | ✅ acté |
| **ILL-2** | Demi-verrou ISBN/ISSN : à la détection, signaler et orienter vers le PEB ; si le document est dans un catalogue du réseau, export bloqué. | ✅ acté |
| **ILL-3** | Plafond de diffusion qui voyage avec le document : non-élargissable (durcir oui, assouplir non), figé à la transmission. | ✅ acté |
| **ILL-4** | Deux modes — ponctuel (défaut, aucune copie chez le récepteur, URL signée TTL court) / versement durable en bucket privé. | ✅ acté |
| **ILL-5** | Cataloguer = affirmer irrévocablement « libre de tous droits » ; seuls les libres de droits entrent au catalogue. **Filtre `visibility` exemplaire désormais câblé au catalogue public (CAT-B8, 08/06)** → dépendance levée. | ✅ acté 08/06 |
| **ILL-6** | La source conserve son scan (préservation) ; l'audit garde la demande satisfaite, pas une copie du fichier. | ✅ acté |
| **ILL-7** | Flux `demandé → accepté\|refusé\|indisponible → numérisation → transmis → clôturé` ; initiation staff biblio↔biblio ; section dédiée aux comptes-rendus hebdo. | ✅ acté |
| **ILL-8** | Le partage est le droit `digital_share` d'un partenariat stabilisé (`PARTNER-D9`) ; export = partenariat actif ∧ droit ∧ plafond compatible. | ✅ acté |
| **ILL-9** | Mécanique du plafond : crans binaires `public`/`staff_only` (aligné `CAT-B3`), verrou en base, trace double horodatée export/réception. | ✅ acté |

> Foyer : REGISTRE §22 (`ILL-1..ILL-9`) fait foi ; conception figée dans `spec-flux-partage-numerique` v0.2 ; trace `CADRAGE_ILL-digital_2026-05-25`. Registre > spec > trace.

*MàJ 13/06/2026 — **ILL-1..ILL-9 IMPLÉMENTÉS & déployés** (lots ILL-I1..I5). DDL `ill_digital_shares` + audit + RPC `fn_ill_*` (migration `20260612230500`), accès ponctuel EF `read-ill-shared-asset`, frontend `LibraryDigitalSharesSection` (BibliotecaPage onglet `ill`), notif `notify-digital-share`, section hebdo + i18n `digishare.*`×10. Gaté `digital_share`. `spec-flux-partage-numerique` v0.3 (implémenté).*

---

## 23. Carte-lecteur — `CARD` *(spec-carte-lecteur v0.2)*

| ID | Décision | Statut |
|---|---|---|
| **CARD-A.2** | Portée **par appartenance** : une carte par appartenance, index UNIQUE `uq_reader_card_active_per_membership` (un seul jeton actif par appartenance). | ✅ acté (impl. 28/05) |
| **CARD-A.3** | Stockage en mini-table dédiée `public.reader_card_tokens` (conserve l'historique des révocations). | ✅ acté |
| **CARD-A.4** | **Génération = choix du lecteur·rice** : risque résiduel « carte-fichier sur téléphone saisi » acté et documenté ; un·e lecteur·rice exposé·e peut ne jamais en générer. | ✅ acté |
| **CARD-A.1** | Séquençage chantier mobile vs Catalogação / échéance Bologne (FICEDL 09/2026) : après Catalogação ou détachement P0/P1 en avance de phase. | 🟡 ouvert |
| **CARD-TOKEN** | Le QR encode un **jeton opaque** (pointeur, pas clé) : identifie sans authentifier, inerte hors scan staff ; clair jamais stocké (seul `token_hash` SHA-256). | ✅ acté |
| **CARD-QR** | Génération **locale** du QR côté client ; la carte ne porte que logo/slug de la biblio, aucun nom ni identifiant en clair → anti-tracking. | ✅ acté |
| **CARD-FLAG** | Activation **par bibliothèque** via `libraries.reader_cards_enabled` ; génération refusée (`cards_disabled`) si non activée. | ✅ acté |
| **CARD-RPC-GEN** | `api.generate_my_reader_card(p_library_id)` : membre actif tout rôle, révoque le jeton précédent, rend le clair une seule fois. | ✅ livré prod (28/05) |
| **CARD-RPC-REV** | `api.revoke_my_reader_card(p_token_id)` : le·la lecteur·rice révoque son propre jeton actif. | ✅ livré prod (28/05) |
| **CARD-RPC-RES** | `api.resolve_reader_card(p_token)` : résolution staff ; garde interne `librarian`/`coordenador` de la **bonne** biblio (sinon `not_staff_of_library`), retour minimisé. | ✅ livré prod (03/06) |
| **CARD-SCOPE** | Hors périmètre v0.2 : UI scan caméra (socle PWA P0 + scanner P2), permanence mobile (P3) ; saisie manuelle du jeton possible sans caméra. | 🔵 différé |

> Foyer : `docs/specs/spec-carte-lecteur-v0_2.md` (v0.2) ; carte-lecteur **livrée en prod** β (generate/revoke, 28/05) + γ (resolve staff, 03/06). Registre > trace.

---

## 24. Face fédération / outils fédéralistes — `FED` *(spec-outils-federalistes v0.1)*

| ID | Décision | Statut |
|---|---|---|
| **FED-1** | `círculos` = objet niveau biblio relevant de la **face fédération**, hors `rede` ; voir = tout membre rattaché (leitor inclus), agir = `coordenador`. | ✅ acté |
| **FED-2** | Bloc **Ferramentas federalistas** (1er outil = `círculos`) en nav entre `biblioteca` et `rede`, contrôle d'accès propre, distinct de `isNetworkAdmin`. | ✅ acté |
| **FED-3** | Deux axes **décollés** : échelle de l'objet (`catálogo→rede`) vs portée des rôles (`leitor→administrador`) ; symétrie 2-2-2-2 abandonnée. | ✅ acté |
| **FED-4** | « **Voir ≠ agir** » : actions emboîtées vers l'extérieur, lecture emboîtée sauf (a) `conta` first-person et (b) `círculos` ouvert vers le dedans. | ✅ acté |
| **FED-5** | Importações/exportações relèvent **intégralement** du `coordenador` (relations extérieures = définitions politiques) ; pas de délégation au bibliotecário. | ✅ acté |
| **FED-6** | `conta` reste first-person ; une **vue limitée** des comptes lecteurs vit dans `painel` (anneau opérationnel), au comptoir à la demande — service, pas privilège de rang. | ✅ acté |
| **FED-7** | **Doctrine anti-panoptique** : aucun outil fédéraliste ne produit de vue agrégée du tissu relationnel ; donnée servie à la 1ʳᵉ personne, pas de carte relationnelle persistée. | ✅ acté |
| **FED-O4** | Terme de la primitive = **`círculo`** ; label du bloc = *Ferramentas federalistas*. | ✅ acté (tranché 04/06) |
| **FED-O5** | Adhésion = **accueil par défaut (opt-out)**, le silence vaut consentement ; objection motivée tracée, effet **anti-blackball** (objection isolée suspend et ouvre la discussion). | ✅ acté (tranché 04/06) |
| **FED-O6** | Mutualisation de catalogue = **axe distinct** de la visibilité de fiche ; opt-in par biblio, multi-cercles ; granularité = tout le fonds moins `local_only` ; renvoyée à catalogação. | ✅ acté (tranché 04/06) |
| **FED-O1** | Périmètre exact de la vue `painel` (empréstimos/consultas en cours + carte oui ; données sensibles + historique complet non) à border en spec. | 🟡 ouvert |
| **FED-O2** | Traçabilité : journaliser les consultations de compte par le staff (qui, quel compte, quand) — service rendu ≠ surveillance. | 🟡 ouvert |
| **FED-O3** | Scope = une biblio (cercles niveau biblio) → sélecteur de biblio en tête de page pour le staff multi-biblios. | 🟡 ouvert |
| **FED-O7** | **Gouvernance des autorités partagées = prérogative fédérale démocratisée** (par consentement, jamais un·e admin seul·e). Articulation *split* : le modèle de proposition/fusion + la grammaire de consentement relèvent de `spec-atelier-autorites` (**v0.1 cadrage, 12/06**) ; la face fédération **expose/surface** le rituel de décision et y renvoie. Mécanisme bas niveau déjà livré = `CAT-H1` (`merge_author`/`merge_book`, `merge_log`). Signal amont = rapports `rede` **R3b** (doublons d'autorités) & **R4** (incohérences) du **paquet RAPPORTS-REDE** (12/06). **Tranché (12/06) par `ATE-1..4` (§28)** : portée **réseau entier**, parties prenantes dérivées des données (ATE-1) ; **réemploi `FED-O5`** opt-out/anti-blackball, fenêtre modulée par l'impact (ATE-2) ; propose = `network_contributors` + staff, objecte = `coordenador` utilisatrice + coord. atelier (ATE-3) ; **pas de quorum** (ATE-4). | 🟢 instruit (12/06, renvoi `spec-atelier-autorites`) |

> Foyer : REGISTRE §24 (`FED`) fait foi ; raisonnement dans `docs/journal/cadrages/CADRAGE_modele_acces_concentrique_2026-06-04.md`, spec `docs/specs/spec-outils-federalistes.md` v0.2. Registre > trace.

---

## 25. Ma bibliothèque (vitrine lecteur·rice) — `MYLIB` *(trace : CHANTIER_carte_ma_bibliotheque_lecteur)*

| ID | Décision | Statut |
|---|---|---|
| **MYLIB-1** | Vitrine de contact lecteur·rice = **publique opt-in, vide par défaut**, table sœur `library_public_contact`, distincte du confidentiel `library_contact_profiles` (minimisation). | ✅ acté |
| **MYLIB-2** | **SELECT vitrine = membres actifs only** (pas de lecture `anon`) ; **édition coordOnly** via RPC `upsert_library_public_contact`. | ✅ acté |
| **MYLIB-3** | Logo de la carte lu **data-driven** sur `library_commons.logo_url`/`logo_file_key`, jamais le `LIBRARY_LOGO_MAP` codé en dur ; repli texte ; carte jamais masquée. | ✅ acté |
| **MYLIB-4** | Canal « écrire » = **in-système** (`reader_library_messages` → trigger → `notify-event`), jamais `mailto:` ; anti-spam ≤ 3 / 24 h / lecteur·rice / biblio ; accusé de réception. | ✅ acté |
| **MYLIB-5** | Canal **réciproque biblio→lecteur·rice = mail-only** (RPC `api.send_message_to_reader`, anti-spam 30/24 h, colonne `direction`) ; mail au destinataire seul, sans copie staff ni actionBox ; cadre en langue du destinataire. | ✅ acté |
| **MYLIB-6** | **TR-6.2b clos** : `layout/index.jsx` dé-hardcodé (`LIBRARY_LOGO_MAP` supprimé → `resolveLogoData(commons)`) ; migration `btl_logo_url_cleanup`. | ✅ acté |
| **MYLIB-7** | **Dispatcher renommé** `fn_dispatch_circulation_notify_event` → `fn_dispatch_notify_event` ; 13 appelants réécrits, 0 résidu. | ✅ acté |
| **MYLIB-O1** | **« Chat ouvert » in-app** (fil bidirectionnel persistant) **reporté** — on attend une demande réelle ; v1 = mail-only des deux côtés. | 🟡 reporté (horizon) |

> Foyer : chantier **livré-clos le 04/06/2026** ; détail as-built dans `CHANTIER_carte_ma_bibliotheque_lecteur_2026-06-04.md` (§10–§11). Registre > trace.

---

## 26. Onboarding — `ONBO` *(spec-onboarding-biblioteca v2.0, spec-onboarding-criar-conta v0.3, CADRAGE atelier 2026-06-02)*

| ID | Décision | Statut |
|---|---|---|
| **ONBO-Q1** | Un **seul atelier réutilisable** sert la constitution (pré-activation) ET la redéfinition d'une biblio active — pas trois objets distincts. | ✅ acté |
| **ONBO-Q2** | Atelier et BibliotecaPage = deux vues de la même config ; panneaux embarquant les composants de prod (un seul chemin d'écriture, `library_constitution_progress`). | ✅ acté |
| **ONBO-Q3** | Pas de bilan rétroactif ; périmètre de test = BLMF en direct, BTL en réunion, BLT fictive. | ✅ acté |
| **ONBO-Q4** | Painel = **prise en main** (coach-marks + check-list), pas configuration ; visibilité pilotée par `usePanelAvailability`. | ✅ acté |
| **ONBO-Q5** | Expiration constitution : avertissement + rappels **J+67/J+74**, puis **gel réveillable**. | ✅ acté |
| **ONBO-Q6** | Changement de profil en cours d'atelier autorisé sans boucle ; volets inapplicables → « sans objet » sans effacement. | ✅ acté |
| **ONBO-Q7** | L'onboarding ne fixe que la **déclaration** de catalogage (volet 4) ; l'arbitrage de classification appartient au chantier CAT. | ✅ acté |
| **ONBO-Q8** | Mandat coordinateur·rice : **plusieurs coordenadores** possibles, ajout par cooptation, auto-retrait libre, retrait d'autrui collectif, garde-fou « dernier·ère coordenador·a ». | ✅ acté |
| **ONBO-Q9** | Parcours d'entrée **éditorial sur `anarbib.org`** (portes différenciées) + formulaire `/solicitar-biblioteca` ; réalisation #111. | ✅ acté (réa. #111) |
| **ONBO-Q10** | Proactivité admins : digest in-app à l'entrée en constitution → « proposer un échange » (RES-D10), en tenant le risque burnout (RES-D11). | ✅ acté |
| **ONBO-Q11** | Incohérence flairée → **nudge non-bloquant**, jamais un verrou. | ✅ acté |
| **ONBO-Q12** | Mesure : stats **agrégées et non-individualisantes**, pas de watchlist du silence. | ✅ acté |
| **ONBO-D1** | Canal humain Biblioteca : **bannière permanente non-fermable** + `<HumanChannelInlineCallout>` en tête de chaque volet (matérialise DOC-COLLECTIVE-1). | ✅ acté |
| **ONBO-D2** | **Mode redéfinition** = même atelier ; déclencheur = demande explicite du collectif ; axes structurels **sous vote collectif** (PROF E.5). | ✅ acté |
| **criar-conta D1/D3/D4** | Compte = **agir sur un catalogue** ; le cas équipe ne passe **pas** par `/criar-conta` (cooptation) ; **3 cas** au sélecteur (biblio active / nouvelle biblio / lectrice orpheline). | ✅ acté |
| **criar-conta D7/D8** | Bandeau vitrine → galerie `anarbib.org/<lang>/explorar/` (#K2) ; champ « nom de biblio » optionnel pour orpheline + privacy notice, pas de claim `reader_attachment` en v0.1. | ✅ acté |

> Foyer : décisions au registre §26 (ONBO-Q1..Q12, ONBO-D1/D2) + table D1-D9 de `spec-onboarding-criar-conta v0.3` §8 ; specs `spec-onboarding-biblioteca v2.0` + CADRAGE atelier = trace. Registre > trace.

---

## 27. Identité lecteur·rice locale — `CARD-LOCAL` *(trace : CADRAGE_identite_lecteur_numero_local v2, 10/06 ; spec à rédiger)*

> Étend MULTI-E.2 (§20) : le champ `local_reader_number` **existe et est en prod** ; ce chantier l'**ouvre** (recherche, attribution, roster, canaux) et ajoute un **modèle côté biblio**. **Décisions arbitrées par Xavier le 11/06/2026** (cf. CADRAGE v2 §9). Spec `spec-identite-lecteur-locale` à rédiger avant code.

| ID | Décision | Statut |
|---|---|---|
| **CARD-LOCAL-IDENT** | `local_reader_number` porte une **identité locale** (numéro, **nom** ou autre schéma maison), pas seulement un nombre ; libellés UI **neutres**. Extension de MULTI-E.2. | ✅ acté (Xavier 10/06) |
| **CARD-LOCAL-STAFF** | L'identité locale est **toujours** un acte **staff** ; le·la lecteur·rice ne se l'attribue jamais (wizard/e-mails **informent**, ne font pas saisir). | ✅ acté (Xavier 10/06) |
| **CARD-LOCAL-GATE** | L'identité locale **n'est pas** une condition de circulation : le gate reste sur l'appartenance **validée** (`status='active'`). L'état intermédiaire bloquant = `pending_validation` (déjà en place). Clarifie MULTI-F.1. | ✅ acté (clarification) |
| **CARD-LOCAL-UNIQ** | Unicité par biblio **conditionnelle au modèle** : appliquée aux modèles numériques (`free_number`/`sequenced_number`), **levée en mode `name`** (homonymes tolérés). La condition dépendant de `libraries.reader_identity_model` (autre table), elle passe par un **trigger** `BEFORE INSERT/UPDATE`, pas un index partiel. Collision : message **sans divulguer** le compte existant. | ✅ acté (11/06) |
| **CARD-LOCAL-1** | **Recherche painel** par **UUID / e-mail / identité locale**, scopée à la **biblio courante** ; repli « toutes mes biblios » si zéro résultat (biblio d'origine signalée). Préalable : lire la def hors-migration de `fn_painel_find_profile_by_lookup`. | ✅ acté (11/06) |
| **CARD-LOCAL-2** | **Modèle d'identité par biblio** : `libraries.reader_identity_model` `{free_number · sequenced_number · name · none}`. Le « dernier identifiant attribué » (hint à l'ouverture) est **dérivé** en RPC coordenador — **pas de colonne cache** (`libraries` étant anon-lisible, un cache fuiterait ~le compteur de lecteur·rices ; évite aussi tout cache obsolète). **Guide non bloquant** (n'invalide jamais le legacy). | ✅ acté (11/06) |
| **CARD-LOCAL-3** | **Mode de validation par biblio** : `libraries.reader_validation_mode` `{presential · remote · none}` — pilote le message (identité par e-mail si `remote`, au 1er passage si `presential`, accès direct si `none`). | ✅ acté (11/06) |
| **CARD-LOCAL-5** | **Marqueur legacy** : `user_library_memberships.imported_from_legacy` (bool, défaut `false`), posé à l'attribution/import, exporté au roster. | ✅ acté (11/06) |
| **CARD-LOCAL-6** | **Réutilisation d'identité** : l'unicité **exclut `removed` + `terminated`** (seuls les départs **définitifs** libèrent l'identité ; tout le reste — dont `left_with_pending_circulation` — la garde réservée). | ✅ acté (11/06) |
| **CARD-LOCAL-N3** | **Roster** dans l'**écran biblio** (`BibliotecaPage`), **coordenador uniquement** (cohérent archi) : NOM, prénom, inscrit·e depuis, e-mail, UUID, identité, statut, **legacy/AnarBib** (+ emprunts/résa/consultations/cotisation optionnels). Export **PDF tableau à colonnes** (jspdf) = livrable principal ; **CSV** en option (travail de données). Scopé RLS coordenador. | ✅ acté (11/06) |
| **CARD-LOCAL-N4** | **Notif réconciliation** à l'**attribution** (validation **ou** édition) : **lectrice + biblio** ; **dédup** avec `validation_confirmed` ; via `notify-event`. **Construction immédiate ; déploiement tributaire de Woodpecker** (sinon CLI manuel). | ✅ acté (11/06) |
| **CARD-LOCAL-CANAL** | **Boussole canal** (CADRAGE §6) : à la **création** → UUID + identifiant de login + « comment marche ta biblio » + « tu es en attente » ; identité locale → à la **validation/attribution**, jamais à la création (n'existe pas encore). | ✅ acté (11/06) |
| **CARD-LOCAL-I18N** | Tous les messages (champ, hint, erreur, colonnes roster, e-mails) × **10 locales** (DOC-I18N-1), libellés **neutres** (identité, pas « numéro »). | ✅ acté (11/06) |

> Foyer : trace `docs/journal/cadrages/CADRAGE_identite_lecteur_numero_local_2026-06-10.md` (v2). Parent : **MULTI-E.2** (§20). Articulation : VALID-C1..C4 (§9, validation où l'identité s'attribue) ; CARD-FLAG (§23, `reader_cards_enabled`). Le **wizard de création** fera l'objet d'un cadrage dédié. Registre > trace.

---

## 28. Atelier autorités — `ATE` *(spec : spec-atelier-autorites v0.1)*

> Instruit **FED-O7** (§24). Face *contribution* du corpus d'autorités partagé (personnes, collectivités, matières). Foyer = `docs/specs/spec-atelier-autorites.md`. Registre > spec.

| ID | Décision | Statut |
|---|---|---|
| **ATE-1** | **Portée = réseau entier** (corpus partagé), *pas* par cercle. Parties prenantes d'une proposition **dérivées des données** : biblios utilisatrices de l'autorité (≥ 1 doc lié) + coordination atelier. Aucun « super-cercle fédéral » (anti-hiérarchie, FED-7). | ✅ tranché (12/06) |
| **ATE-2** | **Grammaire = réemploi `FED-O5`** (opt-out, silence = consentement, anti-blackball : objection isolée suspend + ouvre, refus ssi **≥ 2 biblios utilisatrices distinctes**). **Fenêtre modulée par l'impact** : courte (création/édition/traduction), ≈ 14 j (fusion). **Pas de vote.** | ✅ tranché (12/06) |
| **ATE-3** | **Propose** = `network_contributors` (4ᵉ cercle, compte réseau non rattaché) + staff biblio ; *propose, n'édite jamais*. **Objecte** = `coordenador` d'une biblio utilisatrice (FED-4) + coord. atelier ; un contributeur n'est jamais seul juge. **Exécute** = `merge_author`/`merge_book` (CAT-H1), tracé `merge_log` + journal. | ✅ tranché (12/06) |
| **ATE-4** | **Aucun quorum** : consentement = absence d'objection motivée dans la fenêtre, jamais un décompte (reprend `spec-notice-autorite-enrichie` INV-6). | ✅ tranché (12/06) |
| **ATE-O1** | ✅ **tranché (13/06)** : `network_contributors` = **table dédiée** (calquée sur `network_administrators`, pas un rôle `user_library_memberships` — FED-3). Livrée paquet 1 (migration `20260613150000`). | ✅ tranché (13/06) |
| **ATE-O2** | ✅ **tranché (13/06)** : fenêtres **7 j** (création/édition/traduction) / **14 j** (fusion). Dans `fn_authority_propose`. | ✅ tranché (13/06) |
| **ATE-O3** | **Caduc → tranché (13/06)** : collectivité (=`authors`+`structured_meta.authorityType`) et matière (=`subjects`) **existent déjà** en prod. Vrai gap = doter la matière du primitif de fusion CAT-H1 : `merge_subject` + `suggest_subject_duplicates` (+ `merge_log.entity_type` étendu à 'subject'). Migration `20260613120000`, validée BEGIN/ROLLBACK. | ✅ tranché (13/06) |
| **ATE-O4** | Outbox events : famille générique réutilisée vs `authority_proposal_notification_outbox` dédiée. | 🟡 ouvert |
| **ATE-O5** | Surface frontend (paquet 2) : onglet face fédération, page autorité, ou les deux. | 🟡 ouvert |

> Foyer : `docs/specs/spec-atelier-autorites.md` v0.1 (cadrage validé 12/06). Parent : **FED-O7** (§24). Articulation : **CAT-H1** (fusion bas niveau), **FED-O5** (grammaire), `R3b`/`R4` (signal amont, RAPPORTS-REDE). Registre > spec.

---

*Fin du seed v0.1. Décisions transverses recensées : 12. Drifts ouverts : voir le rapport d'audit joint.*

*MàJ 04/06/2026 — Track A (refonte fiche catalogação) : `DOC-JSX-1` + `CAT-E1…E7`. Prompt de reprise Claude Code : `PROMPT_reprise_catalogacao_CODE.md`.*

*MàJ 05/06/2026 — chantier **Importações/Exportações** ouvert : `IMP-1…IMP-8` (§17) incarnés par `spec-importacoes-exportacoes` v0.1 (squelette). Réf. visuelle : `maquette_importacoes_v7.html`.*

*MàJ 05/06/2026 (session soir) — grosse session catalogação/autorités : **CAT-E7…E9, CAT-C5, CAT-G1/G2, CAT-H1, CAT-I1** (Track A complet, capas P1-P3, liaison autorités↔œuvres, fusion de doublons autorités+documents, flux contributeurs, socle Ateliers). 3 specs nouvelles : `spec-autorites-notes-bio-multilingues` v0.2, `spec-liaison-autorites-oeuvres` v0.2, `spec-doublons-detection-fusion` v0.1. **Pièges opérationnels Supabase constatés** (à internaliser) : (1) `[CI SKIP]` sur le commit de TÊTE saute tout le push, migration comprise — ne jamais coiffer une migration d'un commit doc `[CI SKIP]` ; (2) les fonctions d'extension (pg_trgm `similarity`) vivent dans le schéma `extensions` → l'inclure dans le `search_path` des fonctions SECURITY DEFINER (sinon 42883) ; (3) `position` est un mot réservé → quoter `"position"` en colonne de `RETURNS TABLE` ; (4) le catalogue lit des vues matérialisées rafraîchies par cron (≤15 min) → délai entre une écriture et son reflet.*

*MàJ 08/06/2026 — **#HYG-REG-1 (réinscription du foyer)**. Le registre s'arrêtait à §19 ; inscription des sections citées partout mais absentes : **§20 MULTI · §21 PARTNER · §22 ILL · §23 CARD · §24 FED · §25 MYLIB · §26 ONBO**. Schéma **« foyer souverain »** ratifié (Xavier, 08/06) : §17 IMP / §18 OPAC / §19 BIBLIO **inchangés** (on ne renumérote pas le normatif déjà inscrit) ; les sections manquantes prennent les numéros suivants. **Conséquence** : les renvois de TRACE citant l'ancien schéma dispersé (CADRAGE/INVENTAIRE : « MULTI §17, PARTNER §18, ILL §19, OPAC §20, CARD §22, FED §23, MYLIB §24, ONBO §21 ») sont **à conformer** à ces numéros — sweep trace non-normatif, en suivi. Audit de réconciliation : deux schémas concurrents (foyer vs trace) avec collisions sur §17-19.*

*MàJ 08/06/2026 — **Catalogação Phase 2 livrée** (`CAT-B8`) : le catalogue public reflète la **visibilité exemplaire**. Trigger de recompute sur `exemplares` + filtre de présence `exemplares_total > 0` dans la vue `catalog_list_anon_v1` (les compteurs étaient déjà exemplaire-aware via P1.4a). **Lève la dépendance d'`ILL-5` (§22)** → passé ✅. Migration `20260608143145`, validée en BEGIN/ROLLBACK puis vérifiée en prod. Approche faible risque : ni la matview cœur ni les compteurs canoniques touchés.*

*MàJ 05/06/2026 (session Track D) — **CAT-D5a** : P1 Track D sources externes — diagnostic et réactivation gardée de la source LoC. Cause : migration FOLIO (juin 2025) a cassé l'endpoint SRU (casse du database name + instabilité MetaProxy). 5ème piège opérationnel constaté : le MetaProxy IndexData est sensible à la casse du database name (`LCDB` ≠ `lcdb`). **CAT-D5b** : P2 Track D — adaptateurs REST Open Library (ISBN + titre/auteur, candidats riches) et Wikidata (titre/auteur seulement, Q-id passerelle vers P4 autorités). `catalog_metadata_lookup` passe de 5 à 7 sources. **CAT-D5c** : P3 Track D — BN Brasil fédéré dans « Buscar metadados » (`Promise.allSettled` parallèle, normalisation candidats, fusion dans le panel unifié). 8 sources au total. **CAT-D5d** : P4 Track D — EF `authority_lookup` (Wikidata → VIAF/ISNI/variant_forms) + Atelier autorités dans AuthorDraftForm (tier Completo). VIAF API inaccessible (403/HTML depuis juin 2025) → Wikidata seul, qui contient les VIAF/ISNI en claims.*

*MàJ 08/06/2026 — chantier **OPAC** ouvert : §18 (`OPAC-AXIS1/F1/W1/ATL1/UI1/SIM1/RSS1/SEQ1`), specs `spec-catalogue-decouverte` v0.1 + `spec-notice-autorite-enrichie` v0.1. Confrontation specs↔code (frontend lu + backend sondé) tracée dans `CADRAGE_OPAC_chantier_2026-06-07.md`. Décision-clé : axe découverte = **CDD** (sujets data-blocked, 2/237), compteurs via RPC `api.catalog_facets_v1`, autorité matière en étape 2 (collectivité déjà couverte par `authors.authorityType='collective'`).*

*MàJ 08/06/2026 — chantier-cadre **Biblioteca** CLOS : §19 (`BIBLIO-CLOSE/9/10`). Étape 8 (mails EA-13/14/19) livrée et vérifiée de bout en bout ; EA-13 = RPC `fn_send_weekly_report_now` recâblant le bouton « Enviar relatório » sur `notify-weekly-report` (débloquée par #110). Étapes 9-10 (parité HTML radicale) reclassées hors chantier : EA-12 ph.2 différée/prod-gated, EA-11 non retenue par défaut. Trace : cartographie §6.4 ; backlog v27 mis à jour.*

*MàJ 08/06/2026 — chantier **#NOTIFY-Painel-acts** ouvert : §6 (`NOTIF-PA0..4`). Audit préalable (`AUDIT_NOTIFY-Painel-acts_2026-06-08.md`) : 3 familles d'actes Painel muettes (cotisation, restriction locale, gel global) → câblage pattern dispatch + EF + i18n + in-app B3, débloqué par #110. 4 arbitrages tranchés (levées notifiées ; cotisation configurable défaut ON ; restriction/gel mail membre obligatoire + `profile_restriction_enabled` = copie staff ; contenu motif/portée/montant).*

*MàJ 08/06/2026 (soir) — **#NOTIFY-Painel-acts LIVRÉ et vérifié** : câblage e-mail des 3 familles + levées (destinataires membre / toutes biblios concernées / réseau `ADMIN_EMAIL` pour le gel), réplique in-app B3 (`user_notifications`), toggle Painel `cotisation_payment_mail_enabled`. Pattern : dispatch (`fn_record_membership_payment`, `api.restrict_member`/`unrestrict_member`/`freeze_account`/`unfreeze_account`) → `notify-event` → handlers `domain/membership*.ts`. Code mort `handleProfileNotice` nettoyé (décision A). Testé en runtime (pg_net 200, mails reçus, `user_notifications` peuplée).*

*MàJ 08/06/2026 (soir) — cadrage **Importações/Exportações** consolidé : `IMP-9..15` tranchés (§17), spec `spec-importacoes-exportacoes` **v0.2** (run d'import, profils de mapping, adaptateurs hybrides, autorités au dry-run, export de lote, rôles, articulation tableau de bord v7 / wizard re-dérivé). Plan de lots en spec §13 (Lot 0 backend → Lot 1 dashboard v7 → circuits Zotero/UNIMARC/fontes → export → wizard). Implémentation à suivre.*

*MàJ 08/06/2026 (soir, correction) — confrontation au backend réel : **le pipeline d'import EXISTE** dans le schéma **`ingest`** (`partner_catalog_import_runs`/`_sources`/`_staging_rows`, matching, promotion, journal, vues UI). IMP-9 corrigé (réutilise `ingest`, pas de nouvelle table) ; IMP-10/11 → schéma `ingest`. Constats : mapping codé en dur dans l'EF, **fontes externas = lookup-only** (pas d'aboutissement staging), **export 100% à construire**, **RPC `ingest.*` = service_role seul + garde-fou frontend** (à durcir, DOC-RPC-3). Plan de lots corrigé (Lot 0 durcissement → Lot 1 frontend v7 → fontes externas → profils → MARC → export). Doc : `journal/cadrages/CADRAGE_importacoes_refonte_2026-06-08.md`.*

*MàJ 12-13/06/2026 — **FACE EXPORT (§13 Lot 5) COMPLÈTE & déployée.** (1) **exportação de lote** (`IMP-13`, EF `export-catalog-lote`). (2) **ser fonte** = endpoint OAI-PMH **gouverné** : gouvernance d'ouverture à deux sens (ascendant 1 admin / descendant vote 21j unanime tacite), scrutin secret, EF publique `oai-pmh-provider` (oai_dc + marcxml), notif fédérale `notify-oai-opening`. Doctrine : nouvelle spec `spec-oai-provider-gouvernance` (**`OAI-1..OAI-9`, à inscrire formellement ici §17**, prolonge `IMP-13`). (3) **partilha de documento** = flux ILL-digital implémenté (cf. §22 MàJ 13/06, `spec-flux-partage-numerique` v0.3). **Niveau 2 restant** (export de fonds gris en lot, miroir import) : cadré + décidé — `CADRAGE_export_fonds_numeriques_2026-06-12` (modes ZIP+transfert direct, droit `mutualisation`, `public_domain_confirmed` strict), plan EX-1..5, **non construit** (`IMP-16..` à inscrire à la réalisation).*

*MàJ 10/06/2026 — chantier **Identité lecteur·rice locale** : §27 (`CARD-LOCAL-*`) ouvert. Réécriture v2 du cadrage `CADRAGE_identite_lecteur_numero_local_2026-06-10.md` après vérif code (socle §20 MULTI **déjà en prod**) + recadrage Xavier : on parle d'**identité** (numéro **ou nom** ou autre), pas de « numéro » ; l'identité est un **acte staff** (le lecteur ne se l'attribue jamais) ; elle **ne gate pas** la circulation (l'état bloquant = `pending_validation`). 3 décisions actées (IDENT, STAFF, GATE) ; 9 ouvertes (recherche, modèle biblio, mode validation, marqueur legacy, réutilisation post-removed, roster onglet Rapports, notif réconciliation, boussole canal, i18n). Le **wizard de création** = cadrage dédié à venir. Décisions 🟡 à arbitrer avant inscription définitive.*

*MàJ 12/06/2026 — **CARD-LOCAL §27 : Lots 1→5 construits** (session « Identité lecteur·rice locale »). **N1** recherche painel par UUID / e-mail / **identité locale** scopée biblio courante + repli signalé (`fn_painel_search_reader`). **N2** attribution/édition staff de l'identité (`api.set_local_reader_identity`, indépendante de la validation ; unicité via trigger Lot 0 → HINT i18n `error.cardLocal.identityTaken`). **N5** config biblio (modèle d'identité + mode de validation dans l'onglet identité ; « dernier identifiant attribué » **dérivé** via `api.get_last_assigned_reader_identity`, pas de cache). **N3** roster coordenador (`api.get_reader_roster`) + export **PDF tableau** (jspdf manuel, lazy) **et CSV**, distinction legacy/AnarBib. **N4** notif réconciliation à l'attribution hors validation (`reader_identity_assigned` → `handleReaderIdentityAssigned` : lectrice + copie biblio ; **dédup** avec `validation_confirmed` car dispatch seulement si appartenance déjà active). i18n × 10 (libellés neutres). Finition CI : **Deploy Pages non bloquant** (`continue-on-error`). Commités en local, **en attente de push** (sérialisation). Reste : **canaux/welcome** (CARD-LOCAL-CANAL, register/CriarContaPage) et **wizard de création** (cadrage dédié).*

*MàJ 12/06/2026 — **FED-O7 instruit** (§24 → 🟢) par `spec-atelier-autorites` **v0.1 cadrage** (`docs/specs/`). Arbitrages tranchés = **ATE-1..4** (§28) : portée **réseau entier** + parties prenantes dérivées des données (ATE-1) ; **réemploi FED-O5** opt-out/anti-blackball, fenêtre modulée par l'impact (ATE-2) ; propose = `network_contributors` + staff / objecte = `coordenador` utilisatrice + coord. atelier / exécute via `merge_author`/`merge_book` (CAT-H1) (ATE-3) ; **pas de quorum** (ATE-4). 5 décisions ouvertes (**ATE-O1..O5**, dont préalable tables **collectivité/matière**, spec-notice D7). **Sous-paquet 1b events** cadré (spec §6) : le « blocage uuid » est un faux problème — `notify-event` lit l'id **bigint** de la ligne d'outbox, la proposition reste **uuid** dans le payload (pattern `painel_internal_task`) ; catalogue `authority.*` + handler `handleAuthorityEvent` (solde aussi le 1b cercles). **Spec + registre non encore stagés.***

*MàJ 13/06/2026 — **ATE-O3 tranché** (révision `spec-atelier-autorites`). Vérif prod : collectivité (`authors`+`structured_meta.authorityType`) et matière (`subjects`) **existent déjà** → le préalable « créer les tables » est **caduc**. Le gap réel = la matière n'avait pas le primitif de fusion CAT-H1 → migration `20260613120000` : `merge_subject` + `suggest_subject_duplicates` (calqués sur merge_author/suggest_author_duplicates, seuil pg_trgm durci à 0.60 car les slugs de matière partagent des morphèmes) + extension `merge_log.entity_type` à 'subject'. **Validée BEGIN/ROLLBACK contre la prod** (zéro persistance, le DML a tourné sur 2 sujets réels puis rollback forcé). Migration + révisions spec/registre **non stagées** (accord requis).*

*MàJ 13/06/2026 — **Atelier autorités, paquet 1 (backend) LIVRÉ**. ATE-O1 tranché (**table dédiée** `network_contributors`) + ATE-O2 (fenêtres **7 j / 14 j**). Migrations `20260613150000` (lot 1 : 3 tables + RLS + helpers `fn_caller_is_network_contributor`/`fn_caller_is_staff`) et `20260613150100` (lot 2 : `fn_library_uses_authority` + RPC `fn_authority_propose`/`object`/`withdraw`/`resolve_due`/`apply` + cron `anarbib-authority-resolve-due-daily`). **Voie B** : consentement opt-out auto → `resolved_consent` ; application **staff-confirmée** → `applied` (fusion via `merge_author`/`merge_subject` CAT-H1/ATE-O3, édition authors/subjects ; création/traduction différées). FED-O5 anti-blackball dans `fn_authority_object` (refus si ≥2 biblios utilisatrices distinctes). Validé lot1+lot2 BEGIN/ROLLBACK (zéro persistance, cron compris). Reste : sous-paquet **1b events** + **paquet 2** (frontend : accès criar-conta `signup_intent` + lien vitrine).*
