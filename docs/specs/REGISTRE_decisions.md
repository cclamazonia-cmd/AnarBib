# 🧷 REGISTRE DES DÉCISIONS — AnarBib

* **Version :** 0.1 (seed d'audit du corpus complet — 02/06/2026)
* **Rôle :** **foyer unique** des choix (arbitrages) et des doctrines transverses. On **cite l'ID** ici, on ne reformule jamais ailleurs.
* **Préséance (rappel) :** en cas de conflit, ce registre + la spec courante + le backlog font foi ; CADRAGE / CHANTIER / SESSION = trace non-normative.
* **Comment lire un statut :** ✅ acté · 🟡 ouvert (à trancher) · 🔵 supersédé/historique · ⚠️ drift détecté (voir `AUDIT_coherence_corpus_2026-06-02.md`).
* **Le champ statut est le fil-piège :** quand une décision bascule, on change **une seule ligne** ici, et le statut dit quelle spec réaligner.

> Ce seed n'est pas exhaustif : il capture les **arbitrages structurants**, les **doctrines transverses** (les faits recopiés partout) et tous les **points ouverts / drifts**. Il se complète au fil des chantiers (règle « close before open » étendue à la doc).

---

## 0. Doctrines transverses — *un seul foyer, à citer partout*

Ce sont les faits recopiés dans presque toutes les specs : c'est là que naissent les drifts. Désormais foyer unique.

|ID|Énoncé|Statut|Foyer / origine|
|-|-|-|-|
|**DOC-I18N-1**|**9 locales** : pt-BR, fr, es, it, de, en, **ca**, **eo**, **nl**. Livraison de chaque clé dans TOUTES les locales en une passe, clés plates, LF sans BOM, 2 espaces.|✅ acté (ca/eo depuis le « 6 » historique ; **nl ajouté ~03/06**)|acquisition §7 ; notify-prorrogacao D5 ⚠️ **~13 specs disent encore « 6 locales » — voir DRIFT-1**|
|**DOC-DEPLOY-1**|`git push` → Woodpecker déploie tout (`supabase db push --linked` + `deploy-edge-functions`). **Jamais** `apply_migration` MCP, **jamais** SQL Editor avant push, **jamais** CLI manuelle. Migrations horodatées **UTC**, vérifier avant de choisir.|✅ acté (corrigé)|spec-migration-mail-resend §6.6 (v0.4) ; acquisition §7|
|**DOC-DEPLOY-2**|Exception unique : `notify-event` se déploie en **CLI** (`--no-verify-jwt`, bundle >150 ko). `register` = seule EF avec `verify_jwt`.|✅ acté|migration-mail §6.6|
|**DOC-DEPLOY-3**|SQL Editor : **interdit** pour toute migration/DDL avant push (le schéma passe par fichier + `git push` → Woodpecker). **Toléré**, à titre exceptionnel et **tracé**, pour (a) le nettoyage ponctuel de données de test/résiduelles (DML sur quelques lignes, jamais de schéma) et (b) les lectures de diagnostic/validation. Toute opération consignée (date + objet) ; si effet durable, reportée en migration ou note de décision.|✅ acté 02/06|régularise cycle-vie-peb (purge PEB test = a) et historico (test = b) — clôt DRIFT-5|
|**DOC-RPC-3**|RPC v3 : écritures (insert/update/delete + validation métier) via RPC ; `supabase.from()` toléré en lecture simple sous RLS ; `storage.from()` hors périmètre RPC.|✅ acté 21/05|acquisition §7 ; cartographie §3.2|
|**DOC-OBJ-2**|Création d'objets backend v2 : `REVOKE … FROM PUBLIC, anon, authenticated, service_role` sur fonctions privées ; trigger non-DEFINER appelant une fonction DEFINER REVOKE-ée → patcher le trigger `SECURITY DEFINER` + `search_path` figé **avant** le REVOKE ; bloc DO de vérif en fin de migration ; `CREATE OR REPLACE` qui change la signature → **DROP + CREATE**.|✅ acté|acquisition §7|
|**DOC-RLS-1**|Tests RLS : `SET LOCAL ROLE` **+** `SET LOCAL "request.jwt.claims"` en `BEGIN/ROLLBACK`.|✅ acté|acquisition §7|
|**DOC-PS-1**|i18n : scripts via Node `.cjs` ou UTF-8 PowerShell explicite ; **vérifier toute mojibake avant correction** (faux positifs). (= R11, transverse)|✅ acté|consultas §11.3 ; emprunts §11.3|
|**DOC-NOTIF-1**|**On notifie qui n'a PAS initié l'action**, jamais l'acteur. (= R5 consultas, miroir admin-reseau §4.2.4)|✅ acté|consultas §11.2|
|**DOC-PERIM-1**|« **page = périmètre, pas de cross-calcul** » : un compteur s'agrège sur le périmètre de sa page ; pour les anonymes, sur les vues `*_anon_v1`, jamais sur une vue réseau (régression B.7).|✅ acté v0.2|admin-reseau §11.1 Q1 ; catalogue-decouverte INV-1|
|**DOC-CLOSE-1**|« **close before open** » : committer+vérifier chaque paquet avant le suivant ; `npm run build` avant chaque push ; **étendu à la doc** (un chantier n'est clos que quand ses vérités ont gradué + sa trace est tamponnée).|✅ acté|acquisition §7|
|**DOC-MODELE-1**|Vocabulaire des strates du modèle, **deux axes distincts** : (1) **niveaux de granularité** (« Camadas ») = œuvre/notice → holding → exemplaire, axe *vertical* ; (2) **couches de l'exemplaire** = trace / provenance / destination, *facettes* du niveau exemplaire, axe *horizontal*. Ne pas confondre « couche » (facette) et « Camada/niveau » (granularité). La couche *provenance* = propriétés d'acquisition au niveau exemplaire.|✅ acté 02/06|exemplaires §2 ; acquisition §4|
|**DOC-COLLECTIVE-1**|**Délibération collective** : les décisions **structurantes/politiques** (profil, gouvernance, partenariats, règlement) se prennent **en collectif** ; l'outil le rappelle **là où l'enjeu est politique** — **pas** sur les réglages opératoires mineurs (anti-paternalisme). Sœur de **RES-D9** (canal humain) mais distincte : porte sur l'**acte de décider**, pas sur la disponibilité du canal.|✅ acté 02/06|ancrages : ONBO-D1 (onboarding) ; PROF E.5 (transitions)|
|**DOC-CIRC-1**|Défauts de `circulation_policy` par exemplaire : empruntable (`books.loanable`) → **`ambos`** (prêt + consultation) ; non-empruntable → **`consulta`**. `emprestavel` (prêt seul, non consultable) n'est **jamais un défaut** — c'est une restriction délibérée par exemplaire (cas BTL). Le padrão de la ficha pré-remplit chaque exemplaire (override par exemplaire). Sous-tend le seed catalogage (P1.4b-e1), la **matrice §6.2** (prêt/consulta/réserve/PEB) et le sélecteur **P1.6-a.1**.|✅ acté 03/06|spec-exemplaires-circulation §4.2 ; absorbe & étend **CAT-B2**|
|**USER-EMAIL-1**|`auth.users.email` = **source de vérité** de l'e-mail utilisateur (c'est le credential de login). `profiles.email` = **miroir dénormalisé** (le schéma `auth` étant d'accès restreint, on recopie l'e-mail dans `profiles` pour login/mail/lookup/API sans joindre `auth.users` partout). Synchronisé à la **création** (trigger `handle_auth_user_created_profile`) **et** au **changement** d'e-mail (trigger `on_auth_user_email_changed` → `sync_profile_email_on_auth_change`). Aucun lecteur ne traite `profiles.email` comme un champ contact indépendant éditable.|✅ acté 03/06 (migration USER-EMAIL-1 ; réconcilie aussi l'existant)|sous-tend `resolve_login_email` (login), le ciblage `notification_outbox.recipient_email`, le lookup user-par-email|

---

## 1. Réseau & gouvernance — `RES` *(spec-administrateur-reseau-v0.4)*

|ID|Décision|Statut|Foyer|
|-|-|-|-|
|RES-Q1|Un·e admin réseau peut être staff de plusieurs biblios (légitime ; DOC-PERIM-1 protège les compteurs)|✅ v0.2|§11.1|
|RES-Q2|Table `network_admin_cross_library_actions_log` créée au paquet C.5|✅ v0.3|§11.1|
|RES-Q3|Expiration des propositions de cooptation = **60 jours** (+ rappels J+14/J+25)|✅ v0.3 (30→60 à D.6)|§11.1|
|RES-Q4|Anonymat opposant = choix par vote (`disclose_identity`, **sans DEFAULT**) + rationale obligatoire si `opposed`|✅ v0.3.1|§11.1 / R6|
|RES-Q5|Carence retrait collectif = **7 jours fixes** ; auto-retrait immédiat sauf dernier admin (30 j)|✅ v0.3|§11.1|
|RES-Q6|Notif staff local sur actions transverses = digest hebdo + mail immédiat si critique|✅ v0.3|§11.1|
|RES-R1..R7|Doctrines de notification cooptation (proposeur 1er vote seul ; rationale conditionnelle ; reminder 2 mails ; etc.)|✅ v0.3.1|§11.2|
|RES-D9|Doctrine **anti-méga-machine** inscrite normativement (SIGB second, canal humain premier)|✅ v0.4|§11.2bis (miroir onboarding §1.4)|
|RES-D10|Mécanisme « Proposer un échange » admins→biblios (table `library_member_invitations`, 3 RPC, 4 events)|🟡 à implémenter|§4.7|
|RES-D11|Risque burnout admin réseau reconnu (éthique de soutenabilité)|✅ v0.4 (suivi)|§8.8|
|RES-Q9, RES-Q10|Mineures ouvertes : champ `restrictive` ; notif ajout admin|🟡 ouvert|§11.3|
|RES-Q11, RES-Q12|Stat canal humain = **agrégée/non-individualisante** ; **pas** de scoring du silence (« vigilance » = un « on est là » général, pas une watchlist)|✅ acté 02/06 (cf. ONBO-Q12)|§11.3|

---

## 2. Cartographie réseau — `MAP` *(spec-cartographie-reseau v0.1)*

⚠️ **Squelette d'arbitrages — TOUT est ouvert** (colonne Décision vide au §6).

|ID|Sujet|Reco|Statut|
|-|-|-|-|
|MAP-A|Localisation des données|A2 court terme, A3 si croissance|🟡 ouvert|
|MAP-B|Modèle i18n des contenus carto|B4|🟡 ouvert|
|MAP-C|Hébergement carte publique|C2|🟡 ouvert|
|MAP-D|Validation des modifications|D1+D3 hybride|🟡 ouvert|
|MAP-L|Sort de la carte uMap actuelle|L1|🟡 ouvert|
|MAP-CAL|Calendrier|Post-Bologna|🟡 ouvert|

⚠️ Auto-contradiction interne : §0 dit « **octolingue** » puis « les **6 locales** actuelles » → voir DRIFT-4 (et DOC-I18N-1).

---

## 3. Migration mail — `MAIL` *(spec-migration-mail-resend v0.4)*

|ID|Décision|Statut|Foyer|
|-|-|-|-|
|MAIL-Q1|Basculer transport par transport sur place (R.2–R.5), aligner plus tard (R.7)|✅ (inversion v0.2)|§3.7|
|MAIL-Q2|Garde-fou doctrinal anti-tracking|✅|§6.4 / A6|
|MAIL-Q3|Audit dashboard webhooks bounces Brevo en R.1|✅ (audit à faire)|A2|
|MAIL-Q4|Bascule transport-par-transport sans staging dédié|✅|§3.7|
|MAIL-Q5|Rétention logs : conserver Resend + Supabase|✅|§3.7|
|MAIL-Q6|Sender = `no-reply@notifications.anarbib.org`|✅|§3.7|

---

## 4. Consultations — `CONS` *(spec-flux-consultations-v2.2, source normative R-series)*

R1 invariant `schedule_missing` · R2 helper `scheduleFormat.js` · R3 reproposition après refus · R4 no-show conditionné temporel · **R5 = DOC-NOTIF-1** · R6 QA manuelle (E2E reportée) · **R7** ordre UPDATE narrative-avant-état · **R8** `workflow_note`(staff) vs `schedule_reply_note`(lecteur) · **R9** traçabilité coordination généralisée · **R10** signature payload stable handler/trigger · **R11 = DOC-PS-1**. — Toutes ✅ figées (v2.1/v2.2, chantiers #141/#142).

## 5. Emprunts — `EMP` *(spec-flux-emprunts v1.1)*

R7–R11 **propagés depuis consultas** par symétrie (✅ 31/05). R8 ne s'applique pas littéralement (pas de note d'origine lecteur aujourd'hui) mais à anticiper. R10 illustré par la refonte #NOTIFY-prorrogacao (cf. NPRO).

## 6. Notifications lecteur — `NOTIF` *(spec-notifications-lecteur v1.0)*

|ID|Doctrine|Statut|
|-|-|-|
|NOTIF-A|Admission : notifier seulement si **action requise** ou **impact subi**|✅|
|NOTIF-B|Mail = base ; in-app = réplique **restrictive** (B1 délai RGPD / B2 action 100 % in-app / B3 décision sur droits)|✅|
|NOTIF-C|`user_notifications` **réservée au rôle reader** ; staff via outboxes painel ; double notif si concernée aux deux titres|✅|

---

## 7. Modélisation item — `ITEM` *(spec-granularite-item v1, #MODEL-item-grain)*

|ID|Décision|Statut|
|-|-|-|
|ITEM-Q1|`consulta_linhas_v2.item_id` **NOT NULL** (école A)|✅|
|ITEM-Q2|L'exemplaire est choisi par **la bibliothèque**, résolu au plus tard à l'insertion de la `consulta_linha`|✅ (moment exact à caler en impl.)|
|ITEM-Q3|Migration des 30 lignes : résolution auto (mono-exemplaire) + signalement des holdings ambigus|✅|
|ITEM-Q4|`book_holdings` **conservé** (`item_id` fort + `holding_id` confort, patron `emprestimo_itens_v2`)|✅|
|ITEM-Q5|Périmètre = cœur (colonne+FK+migration+RPC consulta) ; suites = frontend + resserrement `#ILL-availability`|✅|

---

## 8. Acquisition / provenance — `ACQ` *(spec-acquisition-provenance v0.1)*

⚠️ Arbitrages = **recommandations à confirmer** (sauf Q4).

|ID|Reco|Statut|
|-|-|-|
|ACQ-Q1|Provenance au niveau **exemplaire** (`exemplares`/`exemplar_drafts`) ; champs notice dépréciés (COMMENT, pas DROP)|🟡 à confirmer|
|ACQ-Q2|Desiderata = nouvel objet léger library-scoped `acquisition_desiderata` (≠ `user_wishlist`)|🟡 à confirmer|
|ACQ-Q3|Réception = cœur minimal (provenance par exemplaire) ; `reception_event` = suite|🟡 à confirmer|
|ACQ-Q4|UI : ingestion technique → Importações ; provenance/entrée en collection → Catalogação (onglet Exemplaires)|✅ confirmé|

> Couplage : migration `exemplares` **mutualisée** avec CAT-B6 (destination). Terminologie clarifiée : « Camadas » = niveaux de granularité, « couches » = facettes de l'exemplaire (cf. `DOC-MODELE-1`) — **DRIFT-6 résolu 02/06**.

---

## 9. Validation physique — `VALID` *(spec-validation-physique v1.1)*

|ID|Décision|Statut|
|-|-|-|
|VALID-AMD|Bascule structurelle vers **validation par-appartenance** (et non plus par-compte)|✅ amendement 30/05|
|**ACCT-MIGRATION**|Migration de compte entre biblios : `spec-migration-compte v1.0` **archivée**, son socle **absorbé dans `spec-multi-appartenance-lecteur`** (à rédiger). Foyer désormais = multi-appartenance.|✅ acté (backlog v25, Option D · VII.1)|
|**VALID-β1**|Ajout d'une 2e+ appartenance conditionné à **≥ 1 appartenance déjà validée** (1re inscription libre) ; β.2 (primaire validée) / β.3 (toutes validées) rejetés|✅ acté 30/05 (`DECISION_validation_par_appartenance` §2)|
|**VALID-γ1**|Révocation d'une appartenance = **non-cascade** (autres appartenances intactes ; canal humain pour alerter ; aucune notif auto inter-biblios) — « la confiance n'est pas transitive dans une fédération sans hiérarchie »|✅ acté 30/05 (§3)|
|VALID-C1..C4|Bouton « valider en lot » ; note coordenador auto-validé ; notif compte en attente ; compteur d'attente|🟡 ouvert (impl.)|

✅ Clôture réalignée 02/06 : pointe désormais vers `spec-multi-appartenance-lecteur` (cf. ACCT-MIGRATION) — DRIFT-2 corrigé.

## 10. Renouvellement granulaire — `RENOV` *(spec-renouvellement-granulaire v0.1)*

|ID|Point|Statut|
|-|-|-|
|RENOV-1|`renewals_used` déprécié ou cache permanent ?|🟡 (repoussé après phase 2)|
|RENOV-2|Notif prolongation distingue item vs emprunt ?|✅ **résolu** (NPRO-D1/D4 ; spec alignée 02/06) — DRIFT-3 corrigé|
|RENOV-3|Bouton « tout renouveler » cohabite avec le par-item|✅ (Décision 2, à confirmer à l'usage)|

## 11. Notify-prorrogação — `NPRO` *(spec-notify-prorrogacao-granulaire v0.1 ; chantier clos 30/05)*

|ID|Décision|Statut|
|-|-|-|
|NPRO-D1|Émission depuis `fn_v2_extend_core` (couvre tous les wrappers)|✅|
|NPRO-D2|**Un** événement par action portant `line_nos[]` (pas un mail par item)|✅|
|NPRO-D4|**Retrait** du trigger header `trg_notify_emprestimo_prorrogacao` (DROP)|✅|
|NPRO-D5|Texte `loan.renewed.once` reformulé « par exemplaire » × 8 locales|✅ acté (chantier clos 30/05 ; spec alignée 02/06)|
|NPRO-D6|Date unique si convergence, sinon liste « titre — date »|✅|

---

## 12. Catalogue & catalogage — `CAT` *(cluster 01/06 — addendum, hors zip d'audit)*

|ID|Décision|Statut|
|-|-|-|
|CAT-A1..A3|Label `tract` corrigé (code interne gardé) ; palier Avançado mapping-only ; mode `simple\|advanced\|complete` sans remap|✅ 01/06|
|CAT-B1|`circulation_policy`/`visibility` = `text`+CHECK (pas enum PG)|✅|
|CAT-B2|`circulation_policy` conserve `ambos` (défauts complets → gradués **DOC-CIRC-1**)|✅|
|CAT-B3|`visibility` binaire {public, staff_only=arquivo}|✅|
|CAT-B4|Écriture destination intégrée à la RPC d'édition d'exemplaire (pas de RPC dédiée)|✅|
|CAT-B5|Doublon ISBN réseau = blocage dur + rattachement ; « Revisar o ISBN » (pas d'override self-service)|✅|
|CAT-B6|Migration `exemplares` **mutualisée** avec ACQ §5.1 (une seule vague)|✅|
|CAT-B7|Ordre impératif : item-grain cœur d'abord|✅|
|CAT-C1|`cover_source`/`cover_license` créés (`text` nullable)|✅|
|CAT-C2|Page-1-PDF = sous-paquet P3 différé|✅|
|CAT-C3|Endpoint sélection→stockage dans `cover_lookup`|✅|
|CAT-C4|4ᵉ source capa `og:image` via réutilisation `fetch-url-metadata`|✅ 01/06|
|CAT-D1|Une EF métadonnées à adaptateurs SRU+REST|✅|
|CAT-D2|BN Brasil auto par **réutilisation** de l'EF scraper Sophia (manuel en repli)|✅|
|CAT-D3|EF dédiée `authority_lookup`|✅|
|CAT-D4|Formes variantes en `JSONB variant_forms`|✅|
|CAT-D5|LoC = diagnostic avant réactivation|✅|
|CAT-D6|`viaf`/`isni` au niveau autorité ; `wikidata` aux deux niveaux|✅|

---

## 13. Réservation — `RESA`

Workflow **v3 sémantique en prod** (paquet 5b, 08–09/05). `spec-workflow-reservation-v2-negotiation` et `spec-refactor-v3-semantique` = 🔵 références historiques (doctrine absorbée).

## 14. PEB — `PEB` *(spec-cycle-vie-peb v1)*

Chantier `#ILL-lifecycle` à venir. ⚠️ Arbitrage 4 prescrit la suppression de 8 PEB de test **via SQL Editor** → tension avec DOC-DEPLOY-1/3 (voir DRIFT-5).

**PEB-CIRC-1** (mini-PEB, 03/06) : `fn_peb_search_exemplares` applique la **branche prêt** de la matrice §6.2 — `visibility='public'` ET `circulation_policy IN ('emprestavel','ambos')`. Un PEB sort physiquement l'exemplaire de la prêteuse → copies *consulta-sur-place* et *staff_only* (archive) exclues. Miroir de `fn_v2_create_emprestimo_by_holdings` (P1.4b-e2). Artefact : migration `…_mini_peb_matrice_62.sql`. ⏳ *Sous réserve : si un jour un PEB-consultation est introduit, `consulta` serait traité à part.*

## 15. Profils bibliothèque — `PROF` *(spec-profils-bibliotheque-v0_7, en prod)*

Doctrines actées : ancrage géographique (§9.9.1) ; **délibération politique vs travail opérationnel** (§9.14.2) ; création objets backend v2.5 (= DOC-OBJ-2) ; doctrines PowerShell/Git (= DOC-PS-1).

## 16. Compte lecteur & autres

`HIST` (historico-retencao v1.0, #CL.8 en cours) · `NOTIFPRO` (cf. NPRO) · `CARD` (carte-lecteur — **détail désormais en §22** ; β en prod + résolution staff backend 03/06) · `114A` (🔵 clos 14/05 ; ⚠️ contient « 6 locales » historique). Détail à compléter au fil des chantiers.

---

## 17. Multi-appartenance lectrice — `MULTI` *(spec-multi-appartenance-lecteur, charpente v0.3 — à rédiger)*

|ID|Décision|Statut|
|-|-|-|
|MULTI-MODEL|Appartenance = `(user_id, library_id)` ; **tout par biblio** (rôle, restrictions, cotisations, historique, validation) ; **8 statuts** ; `is_primary` (existant) = biblio principale|✅ acté 31/05 (cadrage, Clusters A–E + Arbitrage A)|
|MULTI-CTX|Contexte d'action = sélecteur de biblio courante (`sessionStorage`) ; lecture **agrégée**, action **contextuelle** ; propagation backend par **`p_library_id`** (option α)|✅ acté 31/05|
|MULTI-F3|`user_notification_preferences` → clé composée `(user_id, library_id)` pour le lié-biblio ; transverses globales (**option c, hybride**)|✅ acté 02/06|
|MULTI-D1|Même titre emprunté dans 2 biblios = **toléré, signalé côté lectrice, jamais bloqué**|✅ acté 02/06|
|MULTI-Z19|Sélecteur **masqué en mono-biblio**, apparaît à ≥ 2 appartenances|✅ acté 02/06|
|MULTI-B2|Bandeau de contexte permanent (multi-biblio) + bascule du thème `--brand-*` de la biblio courante|✅ acté 02/06|
|MULTI-PRIMARY|`is_primary` **non couplé** à la validation (β.2 rejeté) ; `fn_my_account_status` = vérité de la primaire ; détail par-biblio via `fn_my_memberships_status`|✅ acté 02/06 (audit Zone 23)|

> Cite **VALID-β1** (garde intégrée au workflow d'auto-inscription), **VALID-γ1** (borne la transparence inter-biblios), **ACCT-MIGRATION** (absorbe `spec-migration-compte`).

## 18. Partenariat stabilisé biblios — `PARTNER` *(spec-partenariat-biblios, cadrage clos 02/06 — à rédiger)*

> Arbitrages tranchés le 02/06 sous **mandat impératif du collectif** (critère : irréprochabilité politique anarchiste). Foyer du cadrage : `CADRAGE_partenariat_stabilise_2026-06-02.md`.

|ID|Décision|Statut|
|-|-|-|
|PARTNER-D1|Consentement lectrice = **opt-in explicite par partenariat** ; défaut = transparence minimale|✅ acté 02/06|
|PARTNER-D2|Granularité = **droit par droit** côté biblios ; consentement lectrice au niveau du partenariat (resollicité si la config change)|✅ acté 02/06|
|PARTNER-D3|**Orthogonalité stricte** cercle / partenariat (aucun partenariat déduit d'un cercle ; le cercle n'ouvre aucun droit)|✅ acté 02/06|
|PARTNER-D4|**Symétrie stricte** (même périmètre dans les deux sens)|✅ acté 02/06|
|PARTNER-D5|Révocation = **visibilité conditionnée, pas copie** ; rupture ferme l'accès sans résidu ; exception = docs transmis (#ILL-digital) ; trace d'audit|✅ acté 02/06|
|PARTNER-D6|Droits réservés **biblio↔biblio AnarBib** ; collectifs (`catalog_partners`) restent déclaratifs (#PARTNERS)|✅ acté 02/06|
|PARTNER-D7|**Cycle de vie** : proposition/acceptation réservées au rôle `coordenador` ; **activation bilatérale** (les deux biblios acceptent — sinon aucun droit ; états `proposé → actif\|refusé`) ; **rupture unilatérale** fermant l'accès des deux côtés (`D5`), tracée. « Deux pour s'unir, un seul pour partir. »|✅ acté 02/06|
|PARTNER-D8|**Retrait du consentement lectrice** : depuis `/conta`, effet immédiat (RLS, retour transparence minimale, sans résidu) ; re-sollicitation **uniquement à l'ajout** d'un droit (config qui s'élargit), maintenu au retrait — sollicitation **ciblée** (lectrices concernées), **groupée** (un changement = une sollicitation), **douce** (notification, pas blocage)|✅ acté 02/06|
|PARTNER-D9|**Granularité** : table de jonction `partnership_rights (partnership_id, right_key)` (`right_key` sous CHECK) plutôt que colonnes booléennes ; jeu de droits attaché au **partenariat-paire** (symétrie `D4` par construction ; trigger si `library_partnerships` directionnel)|✅ acté 02/06|

## 19. Partage numérique — `ILL` *(#ILL-digital → spec-flux-partage-numerique, à écrire ; arbitré 02/06 sous mandat BLMF)*

> Circuit **distinct du PEB** (acté au cadrage §3). Foyer du cadrage : `CADRAGE_ILL-digital_2026-05-25` (🔵 à tamponner).

|ID|Décision|Statut|
|-|-|-|
|ILL-1|**Périmètre** : cible le **matériel gris non commercialisé** (affiches, tracts, brochures militantes) ; les ouvrages à ISBN/ISSN sont hors cible (PEB physique / déjà en ligne)|✅ acté 02/06|
|ILL-2|**ISBN/ISSN** : détection → **signalement** + demi-verrou — vérification des catalogues du réseau ; **si le document y figure → export bloqué**, renvoi à l'échange inter-biblios (PEB physique si exemplaire papier) ; sinon, signalement seul (responsabilité humaine)|✅ acté 02/06|
|ILL-3|**Plafond de diffusion non-élargissable** : « un document ne gagne jamais en diffusion en changeant de main ». Plafond à l'export ≤ niveau appliqué par la source ; le récepteur hérite, peut durcir, jamais assouplir ; figé à la transmission|✅ acté 02/06|
|ILL-4|**Cycle du fichier** : **ponctuel** (défaut — accès temporaire via signed URL TTL court + `ProtectedMediaViewer`, **zéro copie chez le récepteur**, purge à expiration) ou **versement durable** (copie en bucket privé, rattachée à la notice, réservé aux documents libres de droits)|✅ acté 02/06|
|ILL-5|**Catalogage = affirmation irrévocable « libre de tous droits »** : un document sous plafond restreint n'est **jamais catalogué** (accès interne ponctuel) ; seuls les documents libres de droits entrent au catalogue (ressource numérique sur la notice)|✅ acté 02/06|
|ILL-6|**Conservation patrimoniale source** : la biblio qui numérise conserve son scan (préservation, seule trace possible) ; le circuit n'y touche pas. Audit = trace de la **demande satisfaite**, pas copie systématique|✅ acté 02/06|
|ILL-7|**Flux** : `demandé → accepté\|refusé\|indisponible → numérisation → transmis → clôturé` ; initiation **staff** (biblio↔biblio) ; transmission **via l'app** (Supabase Storage puis VPS) ; section dédiée dans les comptes-rendus hebdo|✅ acté 02/06|
|ILL-8|**Lien partenariat** : le partage numérique est un **droit du partenariat stabilisé** (`PARTNER`) — réutilise `library_partnerships` (biblios fédérées, droit activé)|✅ acté 02/06|
|ILL-9|**Mécanique du plafond** (`ILL-3`) : crans **binaires** `public`/`staff_only` (aligné `CAT-B3`) ; **verrou en base** (contrainte empêchant `visibility=public` pour un document reçu sous plafond `staff_only`) ; **trace double horodatée** (déclaration à l'export + acceptation à la réception ; audit immuable)|✅ acté 02/06|

> Réserve : prudence *by-design* (réduit le risque IP), **pas un avis juridique** — l'exposition réelle relève d'un conseil compétent.

---

## 20. Découverte / OPAC public — `OPAC` *(specs `spec-catalogue-decouverte` + `spec-notice-autorite-enrichie`, cadrage 01/06)*

> Couche **lecteur** (liste, notice, autorité), en aval du catalogage. Lignes rouges : anti-tracking + autonomie. i18n des nouvelles clés = **DOC-I18N-1** (ne pas recopier). Compteurs = **DOC-PERIM-1**. Recadrage clé : plusieurs « manques » RebAL du 20/05 étaient **déjà faits** (voir OPAC-MARC1, OPAC-AUTH1).

|ID|Décision|Statut|Foyer|
|-|-|-|-|
|**OPAC-W1**|Favoris (#OPAC9) = `user_wishlist` **côté serveur** conservée (déjà en prod via `BookPage`), sous réserve d'**audit RLS strict** (`user_id=auth.uid()`, invisible staff/réseau). **Annule** la reco local-first.|🟡 reco (audit à faire)|notice-autorite §3 ; **supersède** catalogue-decouverte §4.1/D2 ; à ne pas confondre avec `acquisition_desiderata` (ACQ-Q2)|
|**OPAC-F1**|Compteurs facettes/sujets (#OPAC7/#OPAC8) via **une RPC d'agrégation dédiée** (`api.catalog_facets_v1`, JSONB, SECURITY INVOKER + REVOKE) — ni N requêtes, ni calcul client (faux en pagination).|🟡 reco|catalogue-decouverte §5/D1 ; cite DOC-PERIM-1|
|**OPAC-AGG1**|Agrégation de sujets **mutualisée** : liste (#OPAC8) ↔ bibliographie d'auteur·rice (#AUT2) = une seule fonction paramétrée par périmètre.|🟡 reco|catalogue-decouverte ; notice-autorite D4|
|**OPAC-SIM1**|« Documents similaires » (#OPAC4) et « auteur·rices lié·es » (#AUT1) = recommandation **par contenu** (auteur/sujet/collection/graphe), **jamais** par comportement ; aucun log de navigation.|✅ acté (invariant)|notice-autorite INV-1/§4|
|**OPAC-PRIV1**|**Aucun appel tiers au runtime** (Wikidata, couvertures…) révélant une consultation ; enrichissement externe = moissonnage **serveur au catalogage**, stocké local.|✅ acté (invariant)|notice-autorite INV-3 ; cite CAT-D6|
|**OPAC-COM1**|**Pas de commentaires publics** sur les notices (exposerait les intérêts politiques des lectrices) ; toute annotation = staff-only.|✅ acté (invariant)|notice-autorite INV-5 (#OPAC6)|
|**OPAC-MARC1**|#OPAC2 « MARC » = **déjà couvert** par la vue **ISBD humaine** (`BookPage` toggle Standard/ISBD) ; onglet MARC brut = optionnel (interop), pas valeur lectrice.|✅ requalifié|notice-autorite §3|
|**OPAC-AUTH1**|#OPAC3 « contributeurs liés » = **en grande partie fait** (`BookAuthorLinks`) ; résidu = `autores_secundarios` texte→entité (qualité de données, pas frontend).|✅ requalifié|notice-autorite §3|
|**OPAC-X1**|Formats d'export notice/biblio (#OPAC1/#AUT3) : BibTeX + RIS ; MARC/MODS à décider pour l'interop.|🟡 ouvert|notice-autorite D2|
|**OPAC-UI1**|Onglets RebAL (Exemplaires/Description/Similaires/MARC) vs sections AnarBib : à trancher selon ergonomie **#MOBILE**.|🟡 ouvert|notice-autorite D5 ; catalogue-decouverte D4|
|**OPAC-ATL1**|**Préalable Atelier autorités** : créer les tables autorités *collectivité* et *matière* (absentes) avant/pendant le catalogage. Structurant. Spec dédiée `spec-atelier-autorites` à venir (gouvernance par **consentement sans vote**).|🟡 ouvert|notice-autorite §5/D7 ; cite CAT-D3/D4/D6|

---

## 21. Onboarding & atelier de constitution — `ONBO` *(spec-onboarding-biblioteca v2.0 → v2.1 à produire ; `spec-onboarding-painel` à créer ; cadrage 02/06)*

> Foyer du cadrage : `CADRAGE_onboarding_atelier_2026-06-02.md` (trace). Décisions normatives ci-dessous.
> i18n des nouvelles clés = **DOC-I18N-1** (9 locales — la spec v2.0 dit encore « ×6 », corriger en v2.1, cf. DRIFT-1). Délibération = **DOC-COLLECTIVE-1**. Écritures = **DOC-RPC-3**. Objets backend = **DOC-OBJ-2**. Déploiement = **DOC-DEPLOY-1**. Clôture par paquet = **DOC-CLOSE-1**. Canal humain = **RES-D9** ; composants partagés `<HumanChannelInlineCallout>` (MM3), `<HumanChannelFooter>` (MM2).

|ID|Décision|Statut|Foyer|
|-|-|-|-|
|**ONBO-Q1**|**Modèle unifié** : un seul atelier réutilisable sert la **constitution** (pré-activation, volets 0-10, #111) **et** la **redéfinition** post-création. Pas de wizard de redéfinition séparé (cf. ONBO-D2).|✅ acté 02/06|cadrage §1 ; étend spec-onboarding §6|
|**ONBO-Q2**|L'atelier **embarque les composants de section de prod** (`RetentionPolicySection`, `DocumentGovernanceSection`, `PolicySetManager`/`RegimeStateBox`, `TeamPanel`, `LibraryContactProfileSection`, `LeitoresPanel`, `LibraryPartnershipsSection`, `LocaleSelector`, `LibraryVisualAssetsSection`) : couche d'orchestration mince, **un seul chemin d'écriture**, zéro formulaire en doublon.|✅ acté 02/06|cadrage §3 (mapping volet↔onglet↔composant)|
|**ONBO-Q3**|Périmètre : **pas de bilan de santé rétroactif** des biblios existantes. BLMF gérée en direct ; BTL fera l'onboarding complet **en réunion** ; BLT fictive. Cible = **nouvelles** biblios + mode **redéfinition** (ONBO-D2).|✅ acté 02/06|cadrage §1|
|**ONBO-D1**|**Application onboarding de DOC-COLLECTIVE-1** : on ne s'assoit pas seul·e devant l'écran. Matérialisée par une **bannière permanente non-fermable** et un vocabulaire d'action (« marquer comme **discuté en collectif** »).|✅ acté 02/06|cadrage §2 ; cf. **DOC-COLLECTIVE-1**, RES-D9|
|**ONBO-Q4**|**Painel = orientation, pas configuration** : prise en main **profil-pilotée** (tour guidé *coach-marks* + check-list de premières actions). Le·la bibliothécaire **opère**, ne configure pas. Visibilité = `usePanelAvailability` (PROF §9.8). **`spec-onboarding-painel` à créer.**|✅ acté 02/06|cadrage §4 ; cf. PROF|
|**ONBO-Q5**|**Expiration du parcours** : avertissement + **2 rappels J+67 et J+74**, puis **gel** (réveillable par admin réseau).|✅ acté 02/06 (supersède TODO 1)|spec-onboarding §6.1/§10|
|**ONBO-Q6**|**Changement de profil (volet 0) en cours d'atelier autorisé**, **à condition de ne pas créer de boucle sans fin** ; volets devenus inapplicables → « **sans objet** » **sans effacer** les saisies.|✅ acté 02/06 (supersède TODO 4)|spec-onboarding §6.2|
|**ONBO-D2**|**Mode redéfinition** : atelier d'onboarding **étendu** à la reconfiguration post-création. Déclencheur = **demande explicite du collectif** ; axes structurels **sous vote collectif** (PROF E.5).|✅ acté 02/06|cadrage §5 ; cf. PROF (E.5) ; `RIFLEXION_articulation_onboarding_profils §6`|
|**ONBO-Q7**|**Volet 4 catalogage = déclaration non-contraignante** du système : palette « **classement libre/thématique propre** » (défaut) + CDU + Dewey + « **le nôtre** » (libre). N'entrave jamais le catalogage. L'arbitrage **profond** de la classification relève du chantier **CAT**.|✅ acté 02/06 (résout TODO 2 au périmètre onboarding)|spec-onboarding §6.3 ; cf. CAT|
|**ONBO-Q8**|**Transfert de mandat coordinateur·rice** : **plusieurs coordenadores possibles** (anti-hiérarchie) ; **ajout = cooptation** (gouvernance v1.1) ; **auto-retrait libre** ; **retrait d'autrui = décision collective** ; **garde-fou « dernier·ère coordenador·a »** (pas de descente à zéro sans passation, miroir RES-Q5). Sans objet si `governance_mode = informal`.|✅ acté 02/06 (résout TODO 3)|spec-gouvernance v1.1 ; cf. D.6, RES-Q5|
|**ONBO-Q9**|**Parcours d'entrée** : chemin **éditorial sur `anarbib.org`** (charte, portes différenciées, « écris-nous d'abord ») ; **formulaire `/solicitar-biblioteca` sur l'app**. Dépendance actée : créer les **pages d'entrée éditoriales dans toutes les locales** (cf. DOC-I18N-1) sur anarbib.org. Direction tranchée ; **réalisation au #111**.|✅ acté 02/06 (résout §6.7)|spec-onboarding §6.7 ; DOC-I18N-1|
|**ONBO-Q10**|Entrée en `coordenador_em_constituicao` → **notification digest in-app aux admins réseau actifs** (pas de spam individuel). But = **canal humain proactif** (RES-D10), pas surveillance ; respecte RES-D11 (burnout).|✅ acté 02/06 (résout TODO 5)|cf. RES-D10, RES-Q6, RES-D11|
|**ONBO-Q11**|**Jamais de blocage** de soumission d'un volet (anti-paternalisme). Incohérence flairée (heuristique, cas Émile-Henry) → **nudge non-bloquant** « ça vaut peut-être un échange » + appui sur ONBO-Q10.|✅ acté 02/06 (résout TODO 6)|spec-onboarding §6.5 ; cf. ONBO-Q10|
|**ONBO-Q12**|Stats anti-méga-machine = **agrégées et non-individualisantes** (invitations/30 j, taux d'acceptation, délai moyen). **Pas de scoring du silence** ni watchlist des biblios « silencieuses » — réponse = « on est là » général, jamais surveillance.|✅ acté 02/06 (résout TODO 7 ; aligne RES-Q11/Q12)|cf. RES-Q11/Q12|

---

## 22. Carte-lecteur / mode terrain — `CARD` *(spec-carte-lecteur v0.2)*

> La carte = **projection de l'appartenance** en un jeton de présentation **opaque**, inerte hors scan staff (pointeur, pas clé). Objets backend = **DOC-OBJ-2** ; actions DB = **DOC-RPC-3** ; portée/compteurs = **DOC-PERIM-1**. Le séquençage du chantier mobile (A.1) relève de la roadmap (**DOC-COLLECTIVE-1**, échéance Bologne). Les arbitrages A.2/A.3/A.4 ont été **tranchés par l'implémentation du 28/05** (le dossier de chantier les listait « en attente »).

|ID|Décision|Statut|Foyer|
|-|-|-|-|
|**CARD-A1**|Séquençage du chantier mobile vis-à-vis de Catalogação : tout après Catalogação, **ou** détacher P0 (socle PWA) / P1 (carte) en avance de phase pour **Bologne (FICEDL sept. 2026)**. P1 est déjà détaché et livré.|🟡 ouvert (roadmap ; cf. DOC-COLLECTIVE-1)|spec-carte-lecteur v0.2 §3|
|**CARD-A2**|Portée du jeton = **par appartenance** (un·e membre de 3 biblios a 3 cartes) ; **un seul actif par appartenance** (index `uq_reader_card_active_per_membership`). Cohérent DOC-PERIM-1 + la carte porte le logo d'**une** biblio.|✅ acté (implémentation 28/05)|spec-carte-lecteur v0.2 §3-4|
|**CARD-A3**|Stockage = **mini-table dédiée** `reader_card_tokens` (conserve l'historique des révocations), pas de colonnes jeton/statut sur l'appartenance. Privilégie la traçabilité.|✅ acté (28/05)|spec-carte-lecteur v0.2 §4|
|**CARD-A4**|Risque résiduel « carte-fichier sur téléphone saisi » (révèle l'appartenance, ne donne **pas** accès au compte) acté/documenté ; **génération = choix du lecteur**.|✅ acté|spec-carte-lecteur v0.2 §2-3|
|**CARD-R1**|Résolution staff = RPC `api.resolve_reader_card(p_token)` : jeton scanné/saisi → hache (`fn_hash_claim_token`) → appartenance, **gardée staff (`librarian`/`coordenador`) de la biblio du jeton** + RLS ; DEFINER + REVOKE doctrinal ; aucune divulgation hors droit.|✅ backend livré 03/06 (UI staff à venir)|spec-carte-lecteur v0.2 §5.3|

## 23. Réseau fédératif — face fédération & outils fédéralistes — `FED` *(cadrage `CADRAGE_modele_acces_concentrique_2026-06-04.md` ; prolonge `CHANTIER_reseau_federatif_2026-05-25`)*

> **Modèle d'accès concentrique** : deux axes distincts — **échelle de l'objet** (anneaux `catálogo → conta → painel → catalogação → importações/exportações → biblioteca → círculos → rede`) et **portée des rôles** (`leitor → bibliotecário → coordenador → administrador`). La portée n'est **pas** une attribution contiguë de 2 anneaux/rôle. Objets backend = **DOC-OBJ-2** ; écritures = **DOC-RPC-3** ; compteurs/intimité = **DOC-PERIM-1** ; délibération politique = **DOC-COLLECTIVE-1** ; anti-méga-machine = **RES-D9**. Foyer du raisonnement = le cadrage (trace).

|ID|Décision|Statut|Foyer|
|-|-|-|-|
|**FED-1**|`círculos` (cercles d'affinité reliant des **bibliothèques**) relève de la **face fédération**, pas de `rede`. **Voir** = tout membre rattaché (leitor inclus) ; **agir/engager** (rejoindre/quitter, escrever ao círculo, compartilhar catálogo, traiter le signal) = **coordenador** (`user_can_manage_library`).|✅ acté 04/06|cadrage §6 ; cf. PARTNER|
|**FED-2**|Bloc **« Ferramentas federalistas »** (círculos = 1er outil), dans la nav **entre `biblioteca` et `rede`**, **contrôle d'accès propre** (rattachement biblio + mandat coord pour agir), distinct de `isNetworkAdmin`.|✅ acté 04/06 (label + terminologie : FED-O4)|cadrage §6|
|**FED-3**|**Deux axes décollés** : échelle d'objet (anneaux) ≠ portée des rôles. Abandon de la symétrie 2-2-2-2 (fausse symétrie masquant une hiérarchie : `círculos` n'est pas le compagnon admin de `rede`).|✅ acté 04/06|cadrage §2-3|
|**FED-4**|**« voir ≠ agir »** : actions emboîtées vers l'extérieur (logique FAU) ; lecture emboîtée **sauf** (a) `conta` *first-person* et (b) `círculos` ouvert vers le dedans (lecture jusqu'au leitor).|✅ acté 04/06|cadrage §5 ; cf. DOC-PERIM-1|
|**FED-5**|**Importações/exportações = `coordenador` intégral** (config sources/partenaires + run + export) : définitions politiques des relations extérieures. Pas de délégation d'exécution au bibliotecário.|✅ acté 04/06|cadrage §6 ; cf. DOC-COLLECTIVE-1, PARTNER|
|**FED-6**|`conta` reste *first-person* intégral ; **vue limitée des comptes lecteurs dans `painel`** (staff au comptoir), **finalisée** par l'intervention à la demande du lecteur présent — **fonction de service**, pas privilège de rang.|✅ acté 04/06 (bordures FED-O1/O2)|cadrage §6|
|**FED-7**|**Doctrine anti-panoptique** : aucun outil fédéraliste ne produit de **vue agrégée du tissu relationnel** (cercles + partenariats) ; donnée servie **en 1ʳᵉ personne** ; signaux de santé **situés** (aux membres du cercle), jamais dashboard de surplomb ; **pas de carte relationnelle persistée**. Garde contre la **police idéologique intra-mouvement** + la concentration de pouvoir informationnel.|✅ acté 04/06|cadrage §6 ; sœur DOC-PERIM-1, ONBO-Q12, RES-Q11/Q12|
|**FED-O1**|Périmètre de la vue `painel` : empréstimos/consultas en cours + état carte = oui ; données perso sensibles + historique complet = non.|🟡 ouvert|cadrage §6 (FED-6)|
|**FED-O2**|Traçabilité : journaliser les consultations de compte par le staff (qui, quel compte, quand) — service rendu, jamais surveillance.|🟡 ouvert|cadrage §6|
|**FED-O3**|Scope = **une** biblio (cercles niveau biblio) → **sélecteur de biblio** si la personne est staff de plusieurs.|🟡 ouvert|cadrage §6|
|**FED-O4**|Label pt-BR du bloc (*Ferramentas federalistas* / *Federalismo*) + terminologie objet (`círculo` / `coletivo` / `afinidade`).|🟡 ouvert|cadrage §6 (FED-2)|

---

*Fin du seed v0.1 (enrichi 02/06 : VALID-β1/γ1, sections MULTI, PARTNER, ILL, OPAC, ONBO ; doctrine DOC-COLLECTIVE-1 ; enrichi 03/06 : DOC-CIRC-1, USER-EMAIL-1, section CARD (carte-lecteur) ; enrichi 04/06 : section FED — réseau fédératif / outils fédéralistes). Décisions transverses recensées : 15. Drifts ouverts : voir le rapport d'audit joint.*
