# AnarBib — Backlog technique **v33** (mise à jour 2026-06-17)

> **Pourquoi v33.** Reporte le **v32** (12/06). Cette version intègre un **audit
> complet de la « longue traîne » OPAC** (item #14 / §2.4) mené en lecture seule
> sur la prod (`uflwmikiyjfnikiphtcp`) le 16-17/06, et **5 livrables de session**
> produits **hors worktree** (sandbox `~/anarbib-traine`, **non déployés**, en
> attente d'intégration). Constat principal : **la longue traîne OPAC est
> très largement LIVRÉE en prod** — le v32 la listait « ouverte » à tort. Ce qui
> reste est surtout de la **donnée** (indexation, traductions, enrichissement),
> chiffrée ici. **REGISTRE > spec > backlog** inchangé.
>
> **Amendement 17/06 (session « Fédération — Assemblée du réseau »).** Le v33 d'origine
> porte sur l'OPAC ; cet amendement ajoute le **§0ter** (vague multi-sessions **hors OPAC** :
> mobile/PWA/scanner/recolement, fédération/cercles/visio, **Assembleias v0.1→P3**, Gazette+Lettre,
> thésaurus v1→v3, advisors lot 1, import/export, horaires, PUBLIB — **vérifiée par commit/MCP**),
> **corrige** les lignes §1 devenues fausses (#MOBILE, #FED, #BG), ajoute **§2.7** (suites AG/PUBLIB)
> et canonise **§32 `AG`** au REGISTRE. Contenu OPAC d'origine **inchangé**.
>
> **Amendement 17/06 (session « Gazette Rizoma & Lettre fédération », soir) — #PUBLIB LIVRÉ EN PROD.**
> Le chantier **annuaire + fiche publics des bibliothèques** est **intégralement déployé** (plus
> « frontend ouvert ») : migration opt-in `795ba6ed` → frontend `8346f57e` → carte OSM `ec91023f` →
> logos `44bcabec`. Couvre #PUB1 annuaire `/bibliotecas`, #PUB2 fiche `/bibliotecas/:slug`, #PUB3
> toggles admin « Fiche publique », #PUB4/#PUB5 sections contact+horaires (vues gated), #PUB-NAV-1 nav
> publique, #PUB6 rebond OPAC, **PUBLIB-O1** carte OSM (clic-pour-charger, anti-tracking) et **logos
> réels** sur cards/fiche. **Cloisonnement anon vérifié en prod** (biblio `network` exclue même opt-in ;
> défaut OFF → rien ne fuit). → §1, table §1 et §2.7 passés ✅ ; REGISTRE §31 (note de livraison +
> PUBLIB-O1 ✅). **`PUBLIB-SCHED-1` aussi soldé (17/06)** : sondage du réel — `consultation_schedule_struct` **conservé** (réservation de consultation, usage distinct), `service_schedule_text` (colonne **MORTE**) supprimée, `library_opening_hours` canonique, frontière documentée (migration `20260617061715`). **→ chantier #PUBLIB entièrement clos.**
>
> **Amendement 17/06 (session « File éditoriale — tri & supports AV »).** Livré + **en prod** (`main` `ae7e25d8`, DB appliquée via MCP puis tracée en migrations idempotentes). Trois axes :
> **(1) File éditoriale** (`QueuePanel`) — **tri par en-tête** de colonne (asc/desc, ▲/▼) sur Type/Titre-Nom/Statut/Ouvert le/Dern. modif. + nouvelle colonne **« Ouvert le »** (`last_opened_at` sur les 3 tables brouillon + RPC `fn_touch_draft_opened` + **garde GUC** `anarbib.skip_touch_updated_at` sur le trigger partagé `touch_updated_at` : ouvrir ≠ modifier). Migr. `20260617103939`.
> **(2) Supports non écrits approfondis** — rôles de contributeur **conditionnés au type de document** (audiovisuel : réalisateur·rice/scénariste/acteur·rice/interprète/compositeur·rice/narrateur·rice/producteur·rice ; audio : interprète/compositeur·rice/narrateur·rice/voix/producteur·rice ; écrits inchangés) ; **auteur catalogue** dérivé du rôle créateur principal du média (`v_book_authors_canonical` : `realizador`→AV, `compositor`→audio si pas d'`autor`). Migr. `20260617120646` (REFRESH 2 MV).
> **(3) Éditeur → distributeur / maison de disques** — **résout le gap noté CAT-E13** (`editora` absent de l'AV) : champ **`gravadora`** (audio) ajouté (colonne + form + copie au publish, migr. `20260617123948`/`124826`) ; libellé adapté au support sur la **fiche** (`v_book_detail_public_v2` expose distribuidora+gravadora, migr. `125221`) et la **liste OPAC** (`publisher_display` = CASE `tipo_material` repli `editora` ; `private.fn_publisher_display` + vues `api.catalog_list_*_v1`, migr. `130551` ; icône 🎬/💿 + tooltip ; export aligné ; tri/filtre liste restent sur `editora` — limite assumée).
> i18n ×10 (parité). build + 84 tests + lint 0 erreur. → REGISTRE **CAT-E15** (file éditoriale) + **CAT-E16** (supports non écrits, **résout CAT-E13**), + Phase 4 auteur AV/audio.
>
> **Provenance de vérification (légende).**
> - **✅ prod** — constaté cette session (requête lecture seule / code en prod lu).
> - **📦 sandbox** — livré + testé hors worktree, **pas encore déployé**.
> - **↩︎ v32** — report tel quel, **non re-vérifié cette session**.
> - **🟡 ouvert** · **🟠 en cours** · **⚪ cosmétique/différé**.

---

## 0. Livrables de cette session (16-17/06) — sandbox `~/anarbib-traine`, à intégrer

> Écrits **hors du worktree main** (session parallèle active : `~/anarbib` à
> `e154072c`, `~/anarbib-p2`). Testés ; **horodatages de migration à re-vérifier
> `> max` canonique au push** (le canonique a déjà dépassé `…210916`).

| # | Livrable | Fichier(s) sandbox | Test | Solde / avance |
|---|---|---|---|---|
| **(1a)** | Recherche catalogue **multi-mots** (+ corrige une collision `or` recherche↔multi-biblio) | `src/lib/catalogFilters.js` (extrait), `CatalogPage.jsx`, `src/tests/catalogFilters.test.js` | ✅ 8 tests Vitest + build | avance #58/#62 |
| **(2)** | Fiche auteur·rice : **formes du nom** (`variant_forms`) + `activityPlace`/`pseudonyms` | `AuthorPage.jsx` + `.css`, **10 locales** (+5 clés, parité) | ✅ build + 84 tests + **capture live** (Kropotkin) | avance #AUT |
| **(1b)** | Recherche **accents + pertinence** (RPC anon `api.catalog_search_ids_v1`) | `docs/drafts/opac_catalog_search_accent_rank_DRAFT.sql (hors migrations)` | 🟡 **brouillon** : requête validée read-only, enrobage à éprouver **sur branche** | #58/#62, accent gap |
| **i18n-sujets** | **30 sujets ×10 locales** (6 manquantes + trous fr/es/en) | `migrations/20260617020228_opac_subject_labels_i18n.sql` | ✅ validé read-only (10 clés/sujet) | **solde #I18N-sujets** |
| **enrich-AUT** | `variant_forms` de **9 auteur·rices** (API Wikidata, haute confiance) | `migrations/20260617020229_..._wikidata.sql` (+ `scripts/enrich-variant-forms-wikidata.cjs`) | ✅ validé read-only (JSON/apostrophes) | avance enrichissement |

> **Intégration** : (1a)+(2) = frontend (testables symlink) ; les 3 migrations =
> **données/DB** (validées en `SELECT` sans modifier la prod) → déploiement via CI/branche.
> **(1b)** ne couvre que le chemin **anon** ; le chemin **connecté** (session) reste à
> écrire sur le même patron — **ne pas câbler (1b) pour les connecté·es** d'ici là (régression).

---

## 0bis. Longue traîne OPAC — réconciliation (correction du v32 §2.4)

Le v32 listait ces items « ouverts ». **Vérifié ce 16/06 — la plupart sont en prod :**

| Item v32 | Réalité vérifiée |
|---|---|
| #OPAC4 similaires (UI) | ✅ **prod** — `api.similar_books` (fiche livre), `api.similar_authors` (fiche auteur) affichés |
| #OPAC6 description | ✅ **prod** — champ `notas` affiché |
| #OPAC9 favoris/wishlist | ✅ **prod** — ajout liste + fiche, **consultation/gestion** onglet « desejos » du compte (`user_wishlist`) |
| #OPAC10 parcours | ✅ **prod** — A–Z par auteur·rice + « nouveautés » |
| #AUT1-4 auteur·rices | ✅ **prod** — réseau intellectuel, nuage de sujets, dispo session-aware, export BibTeX/RIS |
| #61 date limite de retrait | ✅ **prod** — `earliest_due_back_at` affiché (fiche livre) |
| #58/#62 refonte/filtres | ✅ **prod** (facettes, recherche avancée, multi-biblio) + 📦 multi-mots (1a) |
| #OPAC5 tags | 🟡 **partiel** — `assuntos` en chips cliquables ✅ ; **tags contributifs (folksonomie) ouverts** (décision communauté/vie privée) |
| #OPAC11 RSS | ⚪ **différé** anti-tracking (partage lien/courriel livré à la place) |
| #152 proches-doublons | facette **catalogage** ✅ (12/06) ; **facette OPAC lecteur·rice ouverte** |

→ **#14 #CATALOG-EXT** n'est plus « partiel avancé » mais **quasi complet**.

---

## 0ter. Vague multi-sessions 15-17/06 (hors OPAC) — vérifiée

> Amendement (session « Fédération — Assemblée du réseau »). Le reste de la vague des 3 jours,
> **constaté par commit `feat` sur `main`** (= déployé par la CI app/backend ; le **P3 assembleias**
> en plus **vérifié via MCP** : migration appliquée, RPC émettent, EF redéployée). Corrige des lignes
> §1 du report v32 devenues fausses (#FED « ouvert », #MOBILE « scanner cadré »).

- **#MOBILE — socle terrain LIVRÉ** ✅ : PWA installable (`0fe66b9d`, SW prod-only shell-only) +
  MAJ SW fiable (`a08cea04`) ; **scanner** QR carte (`8db079d7`) + **ISBN universel ZXing**
  (`15250c52`/`ad2cee8f`) + scan ISBN catalogage (`5e7fd83f`) + carte révoquée (`731e688c`) ;
  **recolement** backend (`dfdd9f0a`) + UI scan (`b7274838`) ; **responsive A/B/C** (`f385d8b1`,
  hamburger `e1b94b79`, cartes Painel `38f54401`, catalogue cartes `f46c8c79`, safe-area `91f62924`,
  code-split `de26c311`). *(Le report v32 disait « scanner cadré » → en fait **livré**.)*
- **#FED — face fédération en prod** ✅ *(corrige « 🟡 ouvert »)* : gating onglets (`c120d87f`,
  FED-O8), **cercles** backend+front (`4738b7dd`/`1e289567`) + notif cercle hors biblio auteur·rice
  (FED-O10) + **visio Jitsi Autistici** en onglet dédié (FED-O9, `VITE_JITSI_DOMAIN`), Communs
  5 docs/guides ×10 locales.
- **#ASSEMBLEIAS (AG) — v0.1→P3 en prod** ✅ : objet AG + dépôt ODJ (`b25d2560`) + onglet
  data-driven 10 locales (`916f0451`), section Langues (régime linguistique), **P2b** facilitation
  (`79f86919`/`9cdbe3c7`), **P2c** volontariat (`64409ff3`), **P3 notifications** (migration
  `20260617004735` + handler EF `domain/assembleia.ts` + mail-strings 10 locales ; émission
  `network.assembleia.{convocada,agenda_published,item_proposed}`, **vérifié MCP**). → **§32 `AG`**
  au REGISTRE ; suites = **§2.7**.
- **#GAZ — Gazette « Rizoma » + Lettre v2** ✅ *(§29)* : Gazette (contribution+build `98e5d702`,
  cron mensuel `22823565`, panneau staff `6ee5730d`, diffuser `605d446c`, sources RSS `04fc3857`) ;
  Lettre opt-in (Lot 2/3) + **v2 corps multilingue L1-L5** (`cd491c48`→`4b645f8c`) + lecture in-app.
- **#THES — thésaurus matière v1→v3** ✅ *(§30)* : v1 gouvernance/picker/mots-clés, v2 synonymes/
  notation CDD/libellés multilingue/suggestions, v3 relations `skos:related`/arbre OPAC/export SKOS
  + URI stable. *(Recoupe le §0bis/§5 OPAC de cette v33 côté sujets.)*
- **#BG — sécurité** ✅ : advisors **lot 1** (revoke 14 fns trigger SECDEF `b9090213`) + **MV
  catalogue verrouillées** (option C `4b18b3b2`, wrappers schéma privé `fb2de8c9`, revoke anon
  `2c6f7d54`). *(Lot 1 = plafond sûr, cf. mémoire `secu-advisors-definer-intentional`.)*
- **#IMPORT / export** 🟢 : import adaptateur Perfil + overrides Estrutura/Vocabulário + GC fonds
  (`1b3ba4ae`/`1525fb06`/`c625f55c`) ; **export fonds D3** (palier `to_review`, auto-suggestion,
  destinations, notif réceptrice — `f5be3319`→`d14d8974`).
- **#BIBLIO — horaires/permanences** ✅ *(§19)* : `library_opening_hours` + RPC coordenador +
  éditeur + vitrine membre (`c509ea51`/`983e57b5`).
- **#PUBLIB — annuaire/fiche publics** ✅ **EN PROD** *(§31)* : annuaire `/bibliotecas` + fiche
  `/bibliotecas/:slug` + opt-in fin (toggles admin + vues gated) + carte OSM (`PUBLIB-O1`) + **logos réels**
  (`795ba6ed`→`8346f57e`→`ec91023f`→`44bcabec`→`d0681b61`) ; cloisonnement anon vérifié. **`PUBLIB-SCHED-1` soldé** (colonne morte `service_schedule_text` supprimée, frontière documentée). **#PUBLIB clos.**

---

## 1. Macro-chantiers — statuts

| # | Macro-chantier | Statut | Note |
|---|---|---|---|
| 1 | #BIBLIO | ↩︎ ✅ Clos | report v32 |
| 2 | #PAINEL | ↩︎ ✅ Clos | report v32 |
| 3 | #IMPORT | ↩︎ ⚠️ backend livré, UX à auditer | report v32 |
| 4 | #CL (carte-lecteur) | ↩︎ ✅ Clos (+ CARD-LOCAL Lot 0, suite N1-N5) | report v32 |
| 5 | #CATALOGACAO | ↩︎ ✅ Bouclé | report v32 |
| 6 | #110 mail | ↩︎ ✅ Clos | report v32 |
| 7 | **#MOBILE** | 🟢 **socle livré** : PWA ✅ + **scanner ✅** (QR+ISBN ZXing) + recolement ✅ + responsive A/B/C ✅ ; reste P3 permanence/P5 push/finitions | **§0ter (vérifié ; corrige « scanner cadré »)** |
| 8 | #NOTIFY-Painel | ↩︎ ✅ Livré | report v32 |
| 9 | #COTISATIONS | ↩︎ 🟡 Partiel (#25/#33/#36) | report v32 |
| 10 | #MM | ↩︎ 🟡 Ouvert | report v32 |
| 11 | **#FED** | 🟢 **Livré largement** : cercles, Communs, Entraide+visio, Gazette, Lettre, **Assembleias v0.1→P3** | **§0ter (vérifié ; corrige « ouvert »)** |
| 12 | #MODEL | ↩︎ ✅ specs implémentées | report v32 |
| 13 | #BG-PREP (sécurité) | 🟠 En cours — **advisors lot 1 + MV catalogue verrouillées** (15/06) ; reste à re-sonder | §0ter · mémoire `secu-advisors-definer-intentional` (NE PAS revoke de masse) |
| 14 | **#CATALOG-EXT (OPAC)** | ✅ **quasi complet** (cf. §0bis) | reliquats = #OPAC5 user-tags, #OPAC11 différé, #152 facette OPAC, (1b) chemin session |
| 15 | #HYGIENE-PERF-i18n | 🟡 Partiel — **#I18N-sujets 📦 réglé en sandbox** ; rollout-10 / charte / INVENTAIRE ouverts | — |
| — | #CI / infra | ↩︎ ✅ Refondé (Forgejo + runner) | report v32 |
| — | #PARTNER notifications | ↩︎ ✅ Livré (UX à auditer) | report v32 |
| — | **#THES (thésaurus matière)** | 🟢 **v1→v3 en prod** (relations, arbre OPAC, export SKOS) | §0ter (§30) |
| — | **#GAZ (Gazette + Lettre)** | 🟢 **En prod** (Rizoma + Lettre opt-in v2 multilingue) | §0ter (§29) |
| — | **#ASSEMBLEIAS (AG)** | ✅ **v0.1→P3 en prod** ; v0.2 + P3b ouverts | §0ter (§32 / §2.7) |
| — | **#PUBLIB (annuaire/fiche publics)** | ✅ **CLOS en prod** (annuaire+fiche+opt-in+carte OSM+logos + `PUBLIB-SCHED-1` soldé) | §0ter (§31) · 17/06 (`44bcabec`→`d0681b61`) |
| — | **#BIBLIO horaires** | ✅ **En prod** (`library_opening_hours`) | §0ter (§19) |

---

## 2. Backlog réel — ce qui reste

### 2.1 — Frontend / terrain  ↩︎ (report v32, non re-vérifié)
- **#MOBILE** : socle **livré** (PWA + **scanner P2 ✅** + recolement P4 ✅ + responsive A/B/C ✅, cf. §0ter) ; reste **P3 permanence, P5 push, `#MOB-QR-A4`**, finitions responsive.
- **#MM** (MM1-5 ; l'axe comm est partiellement couvert par **Gazette/Lettre** §29, mais ces items spécifiques restent), **#LIB-SIGNUP-UI P2** (écran on/off inscriptions) — report v32. *(**#FED** n'est plus « ouvert » : page + cercles + face fédération **livrés**, cf. §0ter.)*

### 2.2 — Cotisations  ↩︎ (report v32)
- **#25** cron expiration (7j/1j/J) ouvert, **#33** test blocage, **#36** CIRA Marseille, **#22** COALESCE trivial.

### 2.3 — Sécurité / Bologne  ↩︎ (report v32, **à re-sonder**)
- **#BG4** advisors (non re-sondés ici), **#BG2** sauvegardes, **#BG3** journalisation, **STR-2..5**, **#4**, **#119**, **#79** RBAC catalogage. Squash migrations (non urgent).

### 2.4 — OPAC / découverte  ✅ **quasi soldé** (cf. §0bis) — restent :
- **#OPAC5** tags contributifs (folksonomie) — 🟡 ouvert, **gated décision communauté/vie privée**.
- **#152** facette proches-doublons **côté OPAC lecteur·rice** — 🟡 ouvert (facette catalogage ✅).
- **#OPAC11** RSS — ⚪ différé anti-tracking.
- **(1b)** classement pertinence + accents — 📦 brouillon (chemin anon) ; **chemin session à écrire**.

### 2.5 — i18n / hygiène
- **#I18N-sujets** — 📦 **réglé en sandbox** (30 sujets ×10 locales ; déploiement = migration `…020228`). *(Reste à supprimer le sujet parasite `pierre-joseph-proudhon`, cf. §5.)*
- **#I18N-rollout-10**, **#I18N-charte-inclusive**, **#PERF-accountpage-split** — ↩︎ report v32 (non re-vérifiés).

### 2.6 — Reliquats cosmétiques / différés  ↩︎
- ⚪ Cosmétiques soldés 11/06. 🟡 **EA-12 ph.2** gelé (BIBLIO-9). 🟡 **#OPAC11 RSS** différé.

### 2.7 — Fédération : suites (chantiers #ASSEMBLEIAS & #PUBLIB)
> #FED est livré (§0ter) ; restent ces suites **consciemment différées**.
- **#ASSEMBLEIAS — P3b** : **rappels J-15/J-1** via pg_cron (motif `fn_circle_resolve_due`) —
  **prématuré tant qu'aucune AG n'est datée** (le cron scannerait le vide) ; **inclusion optionnelle
  des bibliothécaires** à la convocation — **bloquée** sur le régime interne par bibliothèque.
- **#ASSEMBLEIAS — v0.2** (cœur délibératif) : **choix de date** (dispo + préférence), **quorum
  60 % zones ∧ 50 % langues** (besoin liste canonique zones/langues-constituantes), **vote/
  consentement** des décisions de fond + **ratification asynchrone** + **PV multilingue**.
  *(spec-assembleias §11.)*
- **#PUBLIB** : ✅ **LIVRÉ EN PROD (17/06)** — annuaire `/bibliotecas` (#PUB1), fiche `/bibliotecas/:slug`
  (#PUB2), drapeaux `*_is_public` + RPC coordenador + vues `library_*_public_v1` (INVOKER, grant anon,
  filtre opt-in), nav (#PUB-NAV-1) + rebond OPAC (#PUB6), **carte OSM** (`PUBLIB-O1`, clic-pour-charger)
  et **logos réels** sur cards/fiche. Cloisonnement anon vérifié. **`PUBLIB-SCHED-1` soldé** :
  `service_schedule_text` (mort) supprimé ; `consultation_schedule_struct` conservé (réservation de consultation) ; frontière documentée. **→ #PUBLIB entièrement clos.**

---

## 5. Données de découverte — état chiffré (lecture seule prod, 16-17/06)

> La longue traîne OPAC est **codée mais affamée de données**. Le gain marginal le
> plus élevé n'est plus du code mais de l'**indexation + enrichissement** (humain,
> délégué — cf. mémoires `indexation-sujets-decision`, `orphelins-autorite-decision`).

- **Indexation par sujet** : 2 673 livres au total, **1 144 indexés** (1 285 affectations, 31 sujets). Distribution ultra-concentrée : *Anarquismo* 797 (~62 %). **Côté catalogue public anon : 499 livres dont 361 (72 %) sans sujet** → facettes/nuages couvrent **~28 %** du public. → chantier **Baqueiro**.
- **Traductions du thésaurus** : avant = pt-BR 31, fr/es/en 29, **it/de/ca/nl/eo/el 0** ; **après migration sandbox = 30 sujets ×10 locales** (termes rares de/nl/eo/el à faire relire natif).
- **Enrichissement auteur** (donnée derrière le code (2)) : `variant_forms` **13/1316** (→ **22** avec les 9 du sandbox) ; `structured_meta` : affiliation 5, activityPeriod 5, activityPlace 4, pseudonyms 1. **Code prêt, couverture ~1-2 %.** Seuls **22 auteur·rices ont un `wikidata_id`** (automatisable) ; au-delà = **identification** (Baqueiro).
- **Qualité de données (sujets)** : **`pierre-joseph-proudhon`** = sujet parasite (personne-comme-sujet, libellé « Pierre-Joseph Proudhon ; », 0 livre) → **à SUPPRIMER (catalogage)** ; **`anarcocomunismo`** 0 livre (vérifier).

---

## 3. Dérive documentaire à résorber (méta)
1. **`INDEX.md`** → pointer **v33** ; **`git mv` v32 → `archive/`** (règle #11) à l'intégration.
2. **`INVENTAIRE.md`** / specs — report v32 (plusieurs specs nouvelles 15-17/06 à resynchroniser : assembleias, gazeta-lettre, thésaurus, fiche publique).
3. **ce backlog** : règle #12 — items OPAC soldés annotés ci-dessus avec renvoi aux migrations sandbox ; **§0ter** ajoute la vague multi-sessions hors OPAC.
4. **`REGISTRE`** : **§32 `AG`** (Assemblée du réseau) ajouté avec cet amendement (canonise ODJ sans gardien/consentement/quorum/calendrier/régime linguistique/facilitation/convocation anti-rétention) ; §29 GAZ, §30 THES, §31 PUBLIB déjà inscrits par leurs sessions.

---

## 4. Réserves — ce que la base ne prouve pas
- Clôtures #IMPORT / PARTNER / PEB / ILL-digital : **requalifiées « à éprouver en usage »** (2026-06-23, suite audit externe). Les **écrans existent** (`ImportWizard`, `LibraryPartnershipsSection`/`StabilizedPartnershipsSection`, `PebHistorySection`, `LibraryDigitalSharesSection`) — le reste-à-faire n'est **pas l'UI** mais la **validation terrain par un·e non-spécialiste**. Mini-protocole : `../journal/audits/PROTOCOLE_validation_terrain_backend-seul_2026-06-23.md`.
- **(1b)** : requête de classement validée read-only, mais **enrobage RPC + grants + perfs + chemin session = à éprouver sur branche** avant déploiement (touche la chaîne de visibilité du catalogue → risque de fuite réseau/BTL si mal câblé).
- Items marqués **↩︎ report v32** : **non re-vérifiés** cette session — la session a porté sur la **longue traîne OPAC** et ses dépendances (fiche livre/auteur, indexation, traductions, enrichissement).

---

*Backlog v33 — 17 juin 2026. Reporte le v32 (12/06). Audit longue traîne OPAC +
5 livrables de session (sandbox hors worktree, à intégrer). Base prod vérifiée
`uflwmikiyjfnikiphtcp`. Ce qui fait doctrine est au REGISTRE (`../specs/REGISTRE_decisions.md`).*
