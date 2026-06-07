# CADRAGE — Chantier OPAC (catalogue public de découverte)

| Champ | Valeur |
|-|-|
| **Genre** | Dossier d'ouverture de chantier (cadrage — trace, pas une spec, pas le registre) |
| **Statut** | 🟡 Cadrage v0.1 — 07/06/2026. Aucune ligne de code engagée. À valider avant Phase 1. |
| **Session** | Cadrage chantier OPAC |
| **Décisions invoquées** | OPAC-W1 (wishlist serveur) · OPAC-F1 (RPC facettes) · OPAC-AGG1 (agrégation sujets mutualisée) · OPAC-ATL1 (tables collectivité/matière) · DOC-PERIM-1 (page = périmètre) · DOC-I18N-1 (10 locales) · DOC-RPC-3 (écritures via RPC) · DOC-OBJ-2 (REVOKE objets backend) · DOC-CLOSE-1 (close before open) · INV-1..6 (anti-tracking, specs OPAC) · CAT-B3 (filtre `visibility`) |
| **Sources de design** | [`spec-catalogue-decouverte.md`](../specs/spec-catalogue-decouverte.md) (#OPAC7–11) · [`spec-notice-autorite-enrichie.md`](../specs/spec-notice-autorite-enrichie.md) (#OPAC1–6, #AUT1–4). En cas de conflit : [`REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md) prime. |
| **Supersession** | Premier document structurant du chantier OPAC. Ne supersède rien. À tamponner 🔵 quand le design aura gradué dans les specs + le registre (charte §4/§5). |

> Méthode : **confronter la spec au code réel** (frontend lu intégralement + backend sondé en direct sur le projet Supabase) pour produire, paquet par paquet, l'écart à combler — et non re-spécifier. Ce document ne crée aucune décision : il prépare le terrain, et signale les arbitrages à porter au registre avant de coder.

---

## 1. Objet & lignes rouges

L'OPAC est la **couche découverte publique** : permettre à une lectrice d'arriver *sans référence précise* (« qu'y a-t-il sur l'antimilitarisme ? ») et de **tomber sur ce qu'elle ne cherchait pas**. Pour une bibliothèque militante, la découverte par rebonds est un acte d'émancipation documentaire — c'est le cœur de la différence avec un SIGB standard. Le retard constaté face à RebAL (OPAC fédéré) porte précisément là : AnarBib sait chercher quand on sait quoi chercher, mais guide mal la flânerie.

Trois lignes rouges doctrinales traversent tout le chantier (invariants des deux specs, à respecter sans exception) :

1. **Cloisonnement (INV-1 / DOC-PERIM-1)** — un compteur ne révèle jamais à un·e anonyme un décompte calculé sur le périmètre réseau. Source = vue `*_anon_v1` pour l'anonyme, `*_session_v1` pour le connecté. (Régression déjà rencontrée et corrigée en B.7.)
2. **Anti-tracking (INV-3 / INV-5)** — aucun log de navigation/recherche côté serveur ; aucune reco par *comportement* (uniquement par *contenu*) ; aucun appel tiers susceptible de fuiter une consultation (pas de hotlink Google Books, pas d'appel client Wikidata à l'affichage).
3. **Vie privée lectrice (INV-2 / OPAC-W1)** — la wishlist est strictement isolée par RLS, invisible au staff et au réseau.

---

## 2. État réel sondé (07/06/2026)

Constat clé : **les fondations sont livrées, la couche données catalogue existe déjà ; il manque surtout une brique d'agrégation et une série de surfaces frontend.**

### 2.1 Backend — ce qui existe (sondé sur le projet Supabase)

- **Liste catalogue** : matview `public.mv_books_catalog_list_v1` (+ `_network_v1`), rafraîchie par `public.refresh_mv_books_catalog_list_v1()`, exposée via les vues API **`api.catalog_list_anon_v1`** et **`api.catalog_list_session_v1`** — le split anon/session exigé par DOC-PERIM-1 est **en place**. La vue session porte déjà `session_available_count`, `session_status_hint`, etc.
- **Colonnes facettables déjà exposées** : `tipo_material`, `idioma`, `ano`, `library_id`/`library_name`, `author_id`/`author_chips` (jsonb), `assuntos`, `available_count`/`global_available_count`.
- **Détail notice** : vue `public.v_book_detail_public_v2`. **Recherche** : RPC `api.search_catalog_v1(q)`. **Bibliographie autorité** : vue `public.author_books_public`.
- **Wishlist** : table `public.user_wishlist` (`user_id, book_id, library_id, note, created_at`), **RLS activée**, politique unique `USING (auth.uid() = user_id)` ; `anon` n'a **aucun grant** SELECT/INSERT. → l'isolement exigé par OPAC-W1/INV-2 est **essentiellement satisfait**.
- Index trigram (titulo/autor/editora) en place ; matview ≈ 2500 lignes (agrégation `GROUP BY` bon marché).

### 2.2 Backend — ce qui manque

- 🔴 **Aucune fonction de facettes/compteurs** (seul `refresh_mv_...` existe). Le `api.catalog_facets_v1` recommandé par OPAC-F1 est **à créer entièrement**.
- 🟠 **`assuntos` est exposé en `text`** dans les vues liste (pas un tableau/jsonb), alors que la source `books.assuntos` est en JSONB. Le filtre `ilike` fonctionne, mais **l'agrégation de sujets (nuage/facette) n'a pas de support structuré** : décision d'implémentation à prendre (cf. §4).
- 🔴 **Aucun backend** pour la similarité par contenu (documents similaires #OPAC4 ; réseau d'auteur·rices #AUT1).
- 🟠 `author_books_public` **n'expose pas** de statut de disponibilité session-aware (requis par #AUT4).

### 2.3 Frontend — état des surfaces (lecture intégrale)

- **`CatalogPage.jsx`** : recherche (combobox `api.search_catalog_v1` + filtre texte PostgREST sur la grille), filtres **tous en saisie texte/select mono-valeur sans compteur**, tri + tri par en-tête, pagination « carregar mais », export CSV/PDF, lien partageable (`copySearchLink`), mode compact, boutons inline Réserver/Consulter (connecté·es). `subjectsFilter` existe mais alimenté **uniquement** par un input texte avancé.
- **`BookPage.jsx`** : Hero, toggle **Standard/ISBD** (`buildIsbdStatement`/`buildIsbdZones`), contributeurs liés → `/autor/:id`, statut dispo session-aware, accès numérique, wishlist « Salvar para depois » (upsert direct `user_wishlist`).
- **`AuthorPage.jsx`** : Hero, chips VIAF/ISNI/Wikidata, bio multilingue (`author_translations` + fallback), photo, bibliographie (rôle, **sans** pastille dispo).
- **Absents** : toute facette chiffrée, tout nuage de sujets, toute barre d'actions (citer/imprimer/export), tout bloc « documents similaires » / « réseau intellectuel ».

---

## 3. Les paquets et leur écart

Légende : ✅ présent · ⚠️ partiel · ❌ absent. *(Intention = specs ; statut = code réel sondé.)*

| Paquet | Surface | Front | Back | Écart à combler |
|---|---|:-:|:-:|---|
| **#OPAC7** facettes à compteurs | Catalog | ❌ | ❌ | RPC agrégation + UI panneau/accordéon |
| **#OPAC8** nuage de sujets | Catalog | ❌ | ❌ | RPC agrégation sujets (source structurée) + UI chips |
| **#OPAC9** wishlist | Catalog/Book | ⚠️ (Book) | ✅ | bouton sur la liste (pattern existant) ; `WITH CHECK` explicite |
| **#OPAC10** alpha + nouveautés | Catalog | ❌ | ✅ | **front only** (réutilise tri + `created_at`) |
| **#OPAC11** courriel + RSS | Catalog | ⚠️ | — | mailto (front) ; **RSS différé** (anti-tracking) |
| **#OPAC1** barre d'actions notice | Book | ❌ | ✅ | **front only** (citer/imprimer/permalien/BibTeX/RIS) |
| **#OPAC4** documents similaires | Book | ❌ | ❌ | RPC `similar_books` (par contenu) + UI |
| **#OPAC6** description structurée | Book | ⚠️ | ✅ | restructurer notes/sujets en bloc + chips |
| **#AUT1** réseau intellectuel | Author | ❌ | ❌ | RPC `similar_authors` + UI |
| **#AUT2** nuage sujets auteur | Author | ❌ | ⚠️ | RPC agrégation **mutualisée #OPAC8** + UI |
| **#AUT3** barre d'actions autorité | Author | ❌ | ✅ | **front only** (permalien + export biblio) |
| **#AUT4** biblio enrichie | Author | ⚠️ | ❌ | exposer dispo dans `author_books_public` + UI |

---

## 4. Clé de voûte : la RPC d'agrégation (à porter au registre)

Une seule brique débloque **#OPAC7 + #OPAC8 + #AUT2** (OPAC-F1, OPAC-AGG1, et la mutualisation D4).

- **Proposition** : `api.catalog_facets_v1(filters jsonb) → jsonb` renvoyant `{ libraries, materials, authors(top-N), languages, decades, subjects }` en un appel, **paramétrable sur le périmètre** (résultats de recherche *ou* bibliographie d'un·e auteur·rice, pour servir aussi #AUT2). `STABLE SECURITY INVOKER`, doctrine REVOKE (DOC-OBJ-2).
- **Cloisonnement** : agréger sur `api.catalog_list_anon_v1` (anonyme) / `_session_v1` (connecté) — **jamais** la vue réseau (INV-1 / DOC-PERIM-1).
- **Décompte d'une facette** = `count(*) GROUP BY <champ>` sur le périmètre courant, **en excluant le filtre de la facette elle-même** (permet l'élargissement, pas la surcontrainte).
- **Point dur — source des sujets** : `assuntos` étant exposé en `text` dans la vue, deux voies (à trancher) : **(a)** enrichir `mv_books_catalog_list_v1` pour exposer les sujets en `jsonb`/array (puis agréger en base) ; **(b)** agréger directement depuis `public.books.assuntos` (jsonb) dans la RPC. (a) est plus performant et cohérent avec la vue ; (b) évite de toucher la matview.
- **Perf** : ≈2500 lignes → un `GROUP BY` est trivial, pas d'index dédié requis en v1.

---

## 5. Décisions à trancher avant de coder

| ID / sujet | État | Recommandation de cadrage |
|---|---|---|
| **D1** calcul des compteurs | ouvert (OPAC-F1 = reco) | RPC dédiée `api.catalog_facets_v1` (option a) ; proscrire le `count` par facette et l'agrégation client |
| **assuntos structuré** *(nouveau — révélé par le code)* | ouvert | trancher voie (a) matview jsonb vs (b) lecture `books.assuntos` |
| **D4** mutualiser #OPAC8 ↔ #AUT2 | ouvert | une seule fonction paramétrée par périmètre |
| **D3** top-N sujets | ouvert | 15 + « plus… », tri par fréquence |
| **D6** onglets vs sections (notice/autorité) | ouvert | sections déroulantes (cohérent AnarBib, doctrine #MOBILE) |
| **OPAC-ATL1 / D7** tables *collectivité* + *matière* | ouvert (backlog) | préalable à l'« Atelier autorités » — hors v1 OPAC, mais à inscrire |
| **RSS (#OPAC11)** | différé | mailto oui ; RSS plus tard, gating public-only si jamais |
| **wishlist (OPAC-W1)** audit RLS | **quasi clos** | confirmer (fait : owner-only, `anon` sans grant) ; ajouter `WITH CHECK` explicite |

> ⚠️ Les IDs `OPAC-F1`, `OPAC-AGG1`, et la décision « assuntos structuré » doivent être **arbitrés et inscrits au REGISTRE** (foyer unique) avant l'implémentation de la clé de voûte. Ce cadrage ne les tranche pas.

---

## 6. Séquence proposée

**Phase 0 — préalables**
- Arbitrer D1 + source assuntos (registre) · confirmer l'audit RLS wishlist · (option) décider OPAC-ATL1.

**Phase 1 — quick wins frontend (zéro backend)**
- **#OPAC1** (barre d'actions notice), **#AUT3** (export biblio), **#OPAC10** (alpha/nouveautés), **#OPAC9** extension liste, **#OPAC11** courriel. Fort ratio, aucun risque doctrinal.

**Phase 2 — clé de voûte**
- `api.catalog_facets_v1` → **#OPAC8** (nuage sujets, signature RebAL la plus marquante) → **#OPAC7** (facettes, réutilise l'infra) → **#AUT2** (mutualisé).

**Phase 3 — réseaux par contenu**
- `api.similar_books` / `api.similar_authors` → **#OPAC4** + **#AUT1** (scoring auteur > sujet > collection, jamais comportemental).

**Phase 4 — compléments**
- **#OPAC6** (description structurée), **#AUT4** (dispo dans la biblio — nécessite d'exposer le statut dans `author_books_public`).

**Transverse** : i18n 10 locales (DOC-I18N-1) livrée par paquet ; `npm run build` avant chaque push (DOC-CLOSE-1) ; un paquet clos avant le suivant.

---

## 7. Couplage & dépendances

- **Filtre public** : `visibility = 'public'` (CAT-B3) gouverne ce qui apparaît à l'OPAC — déjà en place.
- **Item-grain** (#MODEL-item-grain, livré 03/06) : pré-requis de la dispo par exemplaire — satisfait.
- **Capas** (CAT-C5) : vignettes en liste/notice — intégration optionnelle, jamais de hotlink tiers (INV-5).
- **Autorités** (CAT-D6/G1/I1) : VIAF/ISNI/Wikidata + liaison + bios multilingues — alimentent #AUT*.
- **Aval** : l'« Atelier autorités » (spec dédiée à venir) dépend de OPAC-ATL1 (tables collectivité/matière).

---

## 8. Checklist de démarrage

- [ ] D1 + source `assuntos` arbitrés et inscrits au registre (OPAC-F1, OPAC-AGG1).
- [ ] Audit RLS `user_wishlist` formalisé (constat : owner-only ✅) + `WITH CHECK` explicite.
- [ ] Décision OPAC-ATL1 (tables collectivité/matière : v1 OPAC ou backlog ?).
- [ ] Maquette D6 (sections vs onglets) validée.
- [ ] Lot i18n recensé (facettes, chips, actions) × 10 locales.
- [ ] Scénarios de recette par paquet (cloisonnement anon/session en tête : tester `anon` vs `authenticated`).

---

*Fin v0.1. Document de travail (trace). À tamponner 🔵 quand son contenu normatif aura gradué dans `spec-catalogue-decouverte.md` / `spec-notice-autorite-enrichie.md` et le `REGISTRE_decisions.md` (charte du corpus §4/§5). Les RPC `api.catalog_facets_v1`, `api.similar_books`, `api.similar_authors` y sont **proposées**, non actées.*
