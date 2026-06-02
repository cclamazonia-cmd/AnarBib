# Spec — Sources externes & autorités

- **Version :** 0.2 (arbitrages D1–D6 actés + EF réelles intégrées)
- **Date :** 2026-06-01
- **Statut :** 🟡 Spécification, à implémenter — lot #4 du chantier Catalogação (Q1 du cadrage)
- **Périmètre :** enrichissement de l'agrégateur de métadonnées (sources) + couche **autorité** cross-lingue (VIAF/ISNI/Wikidata) et son Atelier.
- **Auteur :** Xavier (coordination AnarBib) — rédaction assistée
- **Méthode :** parité fonctionnelle + qualitative + audit doctrinal (même grille que #BIBLIO / Importações / Catalogação)

**Dépendances entrantes :**
- `CADRAGE_catalogacao_parite_et_module_capas_2026-06-01` (8.B autorité, 8.C sources nationales ; Q12 sources)
- `spec-catalogacao-fiche-et-paliers` v0.3 (les champs `viaf` / `isni` / `wikidata` du palier Completo, §5.2)
- EF existante `catalog_metadata_lookup` (`index.ts`) — agrégateur SRU/MARC : **BNE, BnF, DNB, ICCU actives ; LoC désactivé**

**Dépendances sortantes :**
- `spec-acquisition-provenance` (l'application d'une candidate renseigne la **traçabilité de source** : `source_record_id` / `source_record_url` / `source_label` / `catalog_source`)

---

## 1. Objet & posture

Deux briques distinctes :
- **Métadonnées** — élargir l'agrégateur existant à de nouvelles sources (Q12) sans le réécrire ;
- **Autorité** — poser la couche d'**identité cross-lingue** (un même auteur sous toutes ses formes : Kropotkin / Кропоткин / Pierre / Pyotr…), pivotée sur VIAF/ISNI/Wikidata.

Posture : **réutiliser** `catalog_metadata_lookup` plutôt que le réinventer ; l'autorité sert l'**interopérabilité du réseau** et le **multilinguisme** (cohérent avec les 8 locales). Chaque source reste un **candidat** présenté à l'équipe — pas d'écriture automatique aveugle.

---

## 2. Périmètre

**Dans le périmètre :**
- **Sources de métadonnées** : réactivation **LoC**, ajout **BN Brasil**, **Wikidata**, **Open Library** ; normalisation vers une **forme candidate commune**.
- **Couche autorité (8.B)** : identifiants VIAF/ISNI/Wikidata sur l'entité autorité, formes variantes, **Atelier autorités**.

**Hors périmètre (renvoyé ailleurs) :**
- Les **couvertures** → `spec-module-capas` (EF jumelle `cover_lookup`).
- Le **registre de champs** / paliers → `spec-catalogacao-fiche-et-paliers`.
- La **circulation / exemplaires** → `spec-exemplaires-circulation`.

---

## 3. État de l'existant (audit)

- `catalog_metadata_lookup` agrège en **SRU/MARC** : **BNE** (España), **BnF** (France), **DNB** (Deutschland), **ICCU** (Italia). **LoC est désactivé** (cause à élucider — §4.1). Sa CORS est dans `cors.ts` (origine configurable via `CATALOG_METADATA_ALLOW_ORIGIN`).
- **BN Brasil — une EF auto existe déjà.** Au-delà du bouton manuel (« Buscar na Biblioteca Nacional (ISBN) »), il existe une **EF qui automatise la recherche** : un **scraper de session de l'OPAC Sophia** (`acervo.bn.gov.br`) qui extrait le `__RequestVerificationToken` + `Guid`, poste une recherche par ISBN (gestion des cookies), suit la redirection et **parse les résultats** (titre, autor, material, localização, publicação, assunto, `detail_url`). → la décision D2 se résout en **réutilisation** (§4.2).
- **`fetch-url-metadata` existe** (EF distincte) : fetch d'une URL avec détection RSS/Atom vs HTML, extraction des balises `og:`/`dc.`/`citation_`, **détection d'ISBN dans le texte**, et **`og:image`**. À noter pour les capas (source gratuite côté ressources URL/numériques — cf. spec #3).
- Les champs de **traçabilité de source** existent déjà (`source_record_id`, `source_record_url`, `source_label`, `catalog_source`) et les champs d'**autorité** `viaf` / `isni` / `wikidata` sont prévus au palier Completo (spec #1).

---

## 4. Sources de métadonnées (Q12)

### 4.1 Réactiver LoC — diagnostic d'abord

LoC a été **désactivé** ; **on ne le réactive pas à l'aveugle**. Étape 1 : élucider la cause (rate limit ? instabilité du SRU ? qualité/format des réponses ?). Étape 2 : réactiver **avec garde** (timeout court, retry borné, repli silencieux si la source ne répond pas — la requête globale ne doit jamais être bloquée par une source lente).

### 4.2 BN Brasil — réutiliser l'EF auto existante (D2 résolue)

L'automatisation n'est pas à inventer : **l'EF scraper Sophia existe et fonctionne** (§3). Décision D2 : **l'intégrer comme source BN Brasil** dans le flux « Buscar metadados », **prioritaire** (source nationale du pays). Le **bouton manuel reste le repli** quand le scraper ne renvoie rien ou échoue.

> **Vigilance — scraper fragile.** Le mécanisme repose sur le `__RequestVerificationToken`, le `Guid`, les cookies de session et la **structure HTML** de Sophia : il **cassera** si le site change. Mitigations : repli manuel systématique ; retour partiel (une panne BN ne bloque pas les autres sources) ; **surveillance** d'un canari (alerte si 0 résultat persistant) ; ne jamais faire dépendre la catalogação de la seule BN auto.

### 4.3 Wikidata & Open Library — sources REST/JSON

Contrairement aux SRU/MARC, Wikidata et Open Library sont des **API REST/JSON**. Conséquence d'architecture : l'EF, aujourd'hui SRU/MARC-orientée, a besoin d'un **adaptateur** qui normalise ces réponses vers la **forme candidate commune** (titre, autorité, année, éditeur, ISBN, identifiants, source).

### 4.4 Stratégie d'agrégation

- **Dédup** par ISBN, à défaut titre + autorité normalisés.
- **Priorité** : BN Brasil → source nationale pertinente selon la langue → Wikidata / Open Library en complément.
- Chaque candidate **porte sa source** (`source_label` / `catalog_source`) ; pas de cross-calcul entre sources — l'équipe choisit.
- **Retour partiel** assumé : si une source traîne ou échoue, les autres candidates s'affichent quand même.

---

## 5. Couche autorité (8.B)

### 5.1 Principe

Une **autorité** (auteur, traducteur, collectif/organisation) est une identité stable, indépendante de ses **formes** d'écriture. Le **pivot** est l'identifiant externe : **VIAF**, **ISNI**, **Wikidata (Q…)**. À partir du pivot, on récupère les **formes variantes** entre langues (Kropotkin / Кропоткин / Pierre Kropotkine / Pyotr Kropotkin…).

### 5.2 Bénéfices

- **Dédoublonnage** des auteurs (une seule autorité, plusieurs graphies).
- **Affichage cross-lingue** cohérent (l'UI peut montrer la forme localisée).
- **Interopérabilité réseau** (deux biblios pointent la même autorité).

### 5.3 Modèle cible (léger, à confirmer)

- Sur l'entité autorité : identifiants `viaf` / `isni` / `wikidata` (déjà prévus côté fiche au Completo — à porter au niveau autorité).
- Un **stockage des formes variantes** (forme privilégiée + variantes par langue) — modèle léger à arrêter à l'implémentation.
- Le **lien** se fait via une **recherche d'autorité** (EF dédiée — §7), pas par saisie manuelle des identifiants.

---

## 6. Sources nationales (8.C)

- **BN Brasil prioritaire** pour le contexte ; les SRU nationales (BNE/BnF/DNB/ICCU/LoC) couvrent surtout les ouvrages **étrangers**.
- Sélection de la source par **langue / contexte** de l'ouvrage ; chaque source = un candidat, **sans cross-calcul** (même principe « perimeter, no cross-calculation » que les compteurs).

---

## 7. UI

- **Métadonnées** : « Buscar metadados » (multi-sources, galerie de candidates) + « Buscar na BN » (auto si endpoint, sinon manuel). L'application d'une candidate renseigne la fiche **et** la traçabilité de source (cf. provenance). États existants réutilisés (`searchingMeta`, `metaApplied`, `noMetaFound`).
- **Atelier autorités** (l'onglet aperçu dans la capture) : rechercher une autorité, afficher ses formes variantes, **lier** (pose `viaf`/`isni`/`wikidata`), **résoudre les doublons** d'auteurs. Sobre, au palier qui l'expose (Completo / staff avancé).

---

## 8. Gardes / EF

> **Architecture EF — pattern « une EF par concern » (observé).** Le repo a déjà *trois* EF distinctes (`catalog_metadata_lookup` SRU, `fetch-url-metadata` URL/RSS, scraper BN Brasil). On suit ce grain.

- **Métadonnées SRU + REST** : étendre `catalog_metadata_lookup` avec (a) réactivation LoC gardée, (b) un **adaptateur REST** interne pour Wikidata/Open Library (même forme « notice par ISBN/titre »). C'est le périmètre « une EF métadonnées à adaptateurs » (D1).
- **BN Brasil** : **EF distincte réutilisée** (le scraper Sophia existant), pas un adaptateur interne — sa stratégie (session/scrape) diffère trop. L'UI « Buscar metadados » **fédère** les candidates de `catalog_metadata_lookup` **et** de l'EF BN Brasil, dédup §4.4.
- **Autorité** : **EF dédiée `authority_lookup`** (D3, confirmée par le pattern) — VIAF/ISNI/Wikidata, logique d'identité ≠ logique de notice.
- **Déploiement** : `git push` → Woodpecker (`deploy-edge-functions`) ; jamais MCP `deploy_edge_function`, jamais SQL Editor. **Surveiller la taille de bundle** (cas connu `notify-event` > ~150 ko → bascule CLI).
- **Robustesse** : timeouts courts (cf. l'`AbortController` à 15 s de `fetch-url-metadata`), parallélisme borné, retour partiel ; une source défaillante ne bloque jamais la requête.
- **CORS / Auth** : réutiliser le motif de `cors.ts` (origine configurable) ; posture d'auth alignée sur `catalog_metadata_lookup`.

---

## 9. i18n

- Existants réutilisés : `searchMeta`, `searchBN`, `searchBNHint`, `searchingMeta`, `metaApplied`, `noMetaFound`, `sourceLabel`, `sourceRecordId`, `sourceRecordUrl`.
- À ajouter : libellés de l'**Atelier autorités** (rechercher, formes variantes, lier, doublon), libellés des nouvelles sources.
- **8 locales en une passe** ; flat, LF sans BOM, 2 espaces ; PT-BR strict.

---

## 10. Implémentation & risques

Séquence de paquets :
1. **P1 — LoC** : diagnostic de la désactivation, puis réactivation **gardée** (timeout/retry/repli).
2. **P2 — Adaptateur REST + Wikidata + Open Library** (métadonnées) ; normalisation candidate commune.
3. **P3 — BN Brasil** : **intégrer l'EF scraper existante** comme source prioritaire + fédération UI ; manuel en repli.
4. **P4 — Couche autorité** : EF `authority_lookup` + identifiants au niveau autorité + formes variantes + Atelier autorités.
5. **P5 — i18n** (8 locales).

**Risques & vigilance :**
- **SRU instables / rate limits** : mitigation par retour partiel + timeouts ; ne jamais bloquer l'UI.
- **BN Brasil = scraper de session fragile** (token anti-forgery + cookies + HTML Sophia) : casse si le site change. Mitigation : repli manuel systématique, retour partiel, surveillance canari (alerte si 0 résultat persistant).
- **Réactivation LoC à l'aveugle** : diagnostic **obligatoire** d'abord — la désactivation avait une raison.
- **Données Wikidata** : qualité/complétude variables et licences — traiter comme candidat, pas comme vérité ; conserver la source.
- **Surcharge de l'EF métadonnées** : isoler l'autorité dans sa propre EF (§8).

---

## 11. Liens

- **Cadrage parent :** `CADRAGE_catalogacao_parite_et_module_capas_2026-06-01.md` (8.B, 8.C, Q12)
- **Spec fiche :** `spec-catalogacao-fiche-et-paliers` v0.3 (champs `viaf`/`isni`/`wikidata`, §5.2)
- **Provenance :** `spec-acquisition-provenance` (traçabilité de source à l'application d'une candidate)
- **EF existantes :** `catalog_metadata_lookup` (SRU, `index.ts` + `cors.ts`), `fetch-url-metadata` (URL/RSS/HTML + og:image), **scraper BN Brasil** (Sophia/`acervo.bn.gov.br`)
- **EF jumelle :** `cover_lookup` (`spec-module-capas`) ; **EF nouvelle :** `authority_lookup`

---

*Fin v0.2. Arbitrages actés : D1 une EF métadonnées à adaptateurs SRU+REST (Wikidata/OL internes) ; D2 **BN Brasil auto par réutilisation de l'EF scraper Sophia existante** (manuel en repli, scraper fragile à surveiller) ; D3 EF dédiée `authority_lookup` (confirmée par le pattern « une EF par concern ») ; D4 formes variantes en `JSONB variant_forms` ; D5 LoC = diagnostic d'abord puis réactivation gardée ; D6 `viaf`/`isni` au niveau autorité, `wikidata` aux deux niveaux. Petite retouche à reporter sur spec #1 §5.2 (D6). Bonus à confirmer : `og:image` de `fetch-url-metadata` comme 4ᵉ source de capa (spec #3).*
