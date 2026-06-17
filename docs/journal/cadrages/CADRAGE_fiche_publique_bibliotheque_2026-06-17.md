# CADRAGE — Fiche & annuaire publics des bibliothèques (surface anon)

> ⚠️ **Document de travail — ouvert (17/06/2026).** Cadrage : prépare le terrain, **ne crée aucune décision normative**. Les arbitrages signalés (opt-in fin, consolidation des horaires, périmètre des vues) doivent être **portés au `REGISTRE_decisions.md`** avant toute implémentation. Pas une spec, pas le registre.

| Champ | Valeur |
|-|-|
| **Genre** | Dossier d'ouverture de chantier (cadrage — trace) |
| **Statut** | 🟢 Décisions tranchées (17/06/2026) — graduées au **REGISTRE §31 `PUBLIB`** ; spec à rédiger, **non construit** (`PUBLIB-O1` modalité carte ouverte) |
| **Session** | Gazette Rizoma & Lettre federation (commande Xavier, 17/06) |
| **Décisions invoquées** | DOC-PERIM-1 (page = périmètre / cloisonnement anon) · DOC-I18N-1 (10 locales) · DOC-RPC-3 (écritures via RPC) · DOC-OBJ-2 (REVOKE objets backend) · INV-1/3/5 (anti-tracking, vues `*_anon`) · CAT-B3 (`visibility`) · modèle d'accès concentrique (`libraries.visibility_level`) |
| **Sources de design** | À créer : `spec-fiche-publique-bibliotheque.md`. Modèle de visibilité : [`CADRAGE_modele_acces_concentrique_2026-06-04.md`](CADRAGE_modele_acces_concentrique_2026-06-04.md). En cas de conflit, [`REGISTRE_decisions.md`](../../specs/REGISTRE_decisions.md) prime. |
| **Supersession** | Premier document du chantier « surface publique des bibliothèques ». Ne supersède rien. À tamponner 🔵 quand le design aura gradué (spec + registre). |

> **Méthode (charte du corpus) : confronter au code et aux données réels.** Backend sondé en direct sur le projet Supabase `uflwmikiyjfnikiphtcp` le 17/06/2026 ; frontend constaté par l'absence de route publique. Ce document n'acte rien : il mesure l'écart et liste les arbitrages.

---

## 0 — Réalité des données (sondé le 17/06/2026)

> Cet état prime sur toute estimation faite « de tête ». Il fixe l'échelle réelle et révèle ce qui **existe déjà**.

- **3 bibliothèques**, toutes actives. `visibility_level` : **2 `public`**, **1 `network`** → le **flag d'opt-in au niveau biblio existe déjà** et différencie réellement.
- **`slug` rempli pour les 3** (0 manquant) → la clé d'URL propre (`/bibliotecas/:slug`) est immédiatement disponible.
- **`library_public_contact` : 3 lignes, les 3 renseignées** (email/tél/adresse/note publics). La donnée de contact public **existe déjà** (mais sa RLS actuelle = membre actif, cf. §2.2).
- **`library_opening_hours` : 0 ligne** (module livré ce jour, paquets 1-3 — `983e57b5` ; personne n'a encore saisi).
- **`library_commons.website_url` : renseigné pour les 3**.
- **⚠️ Redondance horaires** : **1 biblio utilise déjà** `library_service_state.consultation_schedule_struct` (horaire par jour structuré) **et** `service_schedule_text` (freetext par jour). Avec `library_opening_hours.slots` (neuf), **trois représentations d'horaires coexistent** (cf. §4.2).

**Vues publiques (anon) déjà en place** — sondées dans le schéma `api` :

| Vue | Colonnes exposées | Usage |
|---|---|---|
| **`api.public_libraries`** | `id, slug, name, short_name, city, state, country, affiliation_label, website_url, logo_url, catalog_mode, circulation_mode, notices_count, catalog_status` | **Source d'annuaire quasi complète** (logo, site, affiliation, géo, nb de notices, état catalogue). |
| **`api.library_service_public`** | `library_id, slug, name, …, service_mode, public_message, allows_new_reservations, allows_new_loans, updated_at` | État de service public (ouvert/fermé + message). |
| **`api.libraries_public_v1`** | `id, slug, name, short_name, city, state` | Minimal (sélecteur / autocomplete). |

> **Conséquence clé** : le « manque à combler » est **surtout frontend** (aucune page fiche/annuaire ne consomme ces vues pour un être humain) **et un opt-in fin** (contact + horaires), **pas un backend à bâtir de zéro**.

---

## 1 — Objet & lignes rouges

**Objet.** Donner à une personne **non connectée** une surface qui **présente une bibliothèque du réseau en tant que lieu** : qui sommes-nous, où, quand (si la biblio le veut), comment nous joindre, que contient notre fonds. Deux surfaces complémentaires :

- un **annuaire public** des bibliothèques du réseau (`/bibliotecas`) — porte d'entrée publique vers chaque collectif ;
- une **fiche publique** par bibliothèque (`/bibliotecas/:slug`) — présentation détaillée, opt-in.

C'est structurant : aujourd'hui l'OPAC montre des *livres* (avec filtre par biblio) mais **aucune surface ne présente la bibliothèque elle-même** à un public. Les horaires posés ce jour sont, faute de cette surface, invisibles hors connexion.

**Lignes rouges doctrinales** (à respecter sans exception) :

1. **Opt-in strict, jamais par défaut (sécurité des lieux militants).** Une bibliothèque ne devient publique que par un choix explicite. Exposer par défaut les permanences d'un collectif est un risque de sécurité, pas un détail d'UX. `visibility_level` gouverne déjà l'apparition dans l'annuaire ; les **données sensibles** (horaires, adresse exacte) exigent un **opt-in supplémentaire et distinct** (cf. §4.1).
2. **« Trouvable » ≠ « horaires publics ».** Une biblio doit pouvoir exister à l'annuaire (nom, ville, logo, canal de contact) **sans** publier *quand* elle est ouverte. La granularité de l'opt-in est la clé de voûte du chantier.
3. **Anti-tracking (INV-3/INV-5).** Aucune télémétrie de consultation des fiches ; aucun appel tiers qui fuiterait l'intérêt pour un collectif (pas de hotlink, pas de carte tierce chargée côté client sans consentement).
4. **Cloisonnement (DOC-PERIM-1 / INV-1).** L'anon lit **uniquement** des vues `*_public`/`*_anon` filtrées sur l'opt-in. Jamais une vue réseau/membre. Le `notices_count` affiché = compteur public, pas le périmètre réseau.
5. **Ne jamais croiser la cartographie sensible.** Les `.umap` (adresses/emails/tél de 368 collectifs) sont **hors dépôt et non consentis** : la fiche publique n'expose **que** ce que **la biblio elle-même** a explicitement opt-in dans l'app. Aucune reprise automatique d'une autre source.

---

## 2 — État réel sondé (17/06/2026)

### 2.1 Backend — ce qui existe

- **Annuaire** : `api.public_libraries` couvre déjà l'essentiel d'une carte de liste (logo, site, affiliation, ville/pays, `notices_count`, `catalog_status`). Vraisemblablement filtrée sur `visibility_level='public'` (2/3 biblios) — **WHERE exact à confirmer** (checklist).
- **État de service** : `api.library_service_public` expose `service_mode` + `public_message` (ouvert/fermé/en pause) à l'anon.
- **Clé d'URL** : `libraries.slug` rempli partout → routes propres prêtes.
- **Flag de visibilité** : `libraries.visibility_level` (`public`/`network`/…) déjà opérant.

### 2.2 Backend — ce qui manque

- 🔴 **Vue publique du contact** : `library_public_contact` (données déjà saisies) est en **RLS membre actif** — pas de surface anon. À créer : `api.library_contact_public_v1` filtrée sur l'opt-in.
- 🔴 **Vue publique des horaires** : `library_opening_hours` est en RLS membre actif. À créer : `api.library_opening_hours_public_v1`, **gated sur un opt-in distinct** (ligne rouge 2).
- 🟠 **Drapeau(x) d'opt-in fin** : il n'existe **aucun** flag « rendre mon contact public » / « rendre mes horaires publics ». `visibility_level='public'` est trop grossier pour les données sensibles (cf. §4.1).
- 🟠 **Consolidation des horaires** : `consultation_schedule_struct` / `service_schedule_text` (service_state) vs `library_opening_hours` — source canonique à désigner (§4.2).

### 2.3 Frontend — ce qui manque

- 🔴 **Aucune route publique** `/bibliotecas` ni `/bibliotecas/:slug`. Aucune page ne consomme `api.public_libraries` pour un rendu humain (la vue n'alimente, au mieux, que des sélecteurs internes).
- 🔴 **Aucun composant** « fiche bibliothèque » réutilisable côté public (le seul existant, [`MyLibraryContactCard.jsx`](../../../src/components/account/MyLibraryContactCard.jsx), est **connecté & membre-only** ; il peut servir de modèle visuel, pas de brique anon).
- 🟠 **Navigation** : pas d'entrée de menu public vers l'annuaire ; articulation à définir avec l'OPAC (filtre biblio → fiche) et le header.

---

## 3 — Paquets et écart

Légende : ✅ présent · ⚠️ partiel · ❌ absent. *(Intention = ce chantier ; statut = sondé le 17/06.)*

| Paquet | Surface | Front | Back | Écart à combler |
|---|---|:-:|:-:|---|
| **#PUB1** annuaire public | `/bibliotecas` | ❌ | ✅ | page liste (cartes) sur `api.public_libraries` ; i18n |
| **#PUB2** fiche publique | `/bibliotecas/:slug` | ❌ | ⚠️ | page fiche (identité, service, site, contact, horaires) |
| **#PUB3** opt-in fin | Biblioteca (admin) | ❌ | ❌ | flag(s) `public_contact_enabled` / `public_hours_enabled` + RPC + vues gated |
| **#PUB4** contact public anon | fiche | ❌ | ❌ | `api.library_contact_public_v1` (opt-in) + rendu |
| **#PUB5** horaires public anon | fiche | ❌ | ❌ | `api.library_opening_hours_public_v1` (opt-in) + rendu |
| **#PUB6** entrée OPAC → fiche | Catalog | ❌ | ✅ | lien « à propos de cette bibliothèque » depuis le filtre biblio |
| **#PUB7** consolidation horaires | data | — | ⚠️ | trancher source canonique (§4.2) ; éventuelle migration |

---

## 4 — Clés de voûte (à porter au registre)

### 4.1 — Le modèle d'opt-in fin (ligne rouge n°2)

Le cœur du chantier. Proposition de cadrage (à arbitrer) : **deux niveaux**.

- **Niveau 1 — apparaître à l'annuaire** : gouverné par `libraries.visibility_level='public'` (déjà en place). Expose le **strict présentable** : nom, ville/pays, logo, affiliation, site web, `notices_count`. Pas de donnée sensible.
- **Niveau 2 — données sensibles, opt-in *distinct et par section*** : deux drapeaux dédiés (recommandé : booléens portés par la table concernée, défaut **`false`**), p. ex.
  - `library_public_contact.is_public` → expose email/tél/adresse/note publics ;
  - `library_opening_hours.is_public` → expose les créneaux + note.

  > Granularité voulue : une biblio peut être **trouvable** (niveau 1) **sans** révéler **quand** elle est ouverte (niveau 2 horaires off) ni son adresse exacte (niveau 2 contact off). C'est la traduction technique de « trouvable ≠ horaires publics ».

- **Écritures** via RPC `SECURITY DEFINER` gardées coordenador (DOC-RPC-3 / DOC-OBJ-2), à l'image de `fn_upsert_library_opening_hours`. Un toggle dédié par section dans l'admin Biblioteca.
- **Vues publiques** filtrées sur `visibility_level='public' AND <section>.is_public` (DOC-PERIM-1), `SECURITY INVOKER` + REVOKE, grant `anon`.

*Variante à discuter* : un opt-in unique « fiche publique complète » (plus simple, moins fin) vs deux drapeaux par section (plus sûr, recommandé ici vu les lieux militants).

### 4.2 — Consolidation des trois représentations d'horaires

Sondé : **trois** structures décrivent des horaires, avec recouvrement :

| Source | Forme | Vocation d'origine |
|---|---|---|
| `library_service_state.consultation_schedule_struct` | `{lundi:{open,close,enabled}, …}` (1 plage/jour) | **Consultation sur place** (lié à `max_simultaneous_consultations`, `consultation_timezone`) |
| `library_service_state.service_schedule_text` | `{lundi:"", …, fixed_openings, exceptional_closures}` (freetext/jour) | Notes d'ouverture humaines |
| `library_opening_hours.slots` (neuf, ce jour) | `[{day,start,end,label}]` (N plages/jour, libellées) | **Permanences / ouvertures générales** (le plus flexible) |

**Reco de cadrage** (à trancher) : faire de **`library_opening_hours` la source canonique « horaires/permanences présentables »** (publique, multi-plages, libellée), et **cantonner `consultation_schedule_struct` à la mécanique de réservation de consultation** (créneaux de capacité, usage interne). À terme, soit la consultation lit `library_opening_hours`, soit on documente clairement la frontière. **Ne pas laisser trois sources diverger en silence** (dette introduite ce jour, assumée — à résorber dans ce chantier, pas en urgence).

---

## 5 — Décisions à trancher avant de coder

> ✅ **Tranché le 17/06 (Xavier) et gradué au `REGISTRE_decisions.md` §31 `PUBLIB`.** Synthèse : opt-in **deux drapeaux par section** (PUB-OPTIN-1) · **coordenador + rappel collectif** (PUB-OPTIN-2) · **`library_opening_hours` canonique** (PUB-SCHED-1) · **adresse opt-in + carte bordée anti-tracking** (PUB-GEO-1) · `public_libraries` = `visibility_level='public'` **confirmé** (PUB-VIS-1) · nav publique + rebond OPAC (PUB-NAV-1) · annuaire dans l'app, le site vitrine renvoie (PUB-VITRINE-1). **Reste ouvert** : modalité exacte de la carte (`PUBLIB-O1`). Le tableau ci-dessous est conservé comme trace du raisonnement.

| ID / sujet | État | Recommandation de cadrage |
|---|---|---|
| **PUB-OPTIN-1** granularité opt-in | ouvert | deux drapeaux par section (`*_is_public`, défaut `false`) plutôt qu'un opt-in global |
| **PUB-OPTIN-2** qui décide du passage public ? | ouvert | coordenador de la biblio (cohérent `user_can_manage_library`) ; mention « décision collective conseillée » dans l'UI |
| **PUB-SCHED-1** source canonique horaires | ouvert | `library_opening_hours` canonique public ; `consultation_schedule_struct` = consultation only |
| **PUB-VIS-1** WHERE de `public_libraries` | à confirmer | vérifier le filtre `visibility_level='public'` réel avant d'en dépendre |
| **PUB-NAV-1** entrée de navigation | ouvert | lien public « Bibliothèques » (header/footer) + rebond depuis le filtre biblio OPAC |
| **PUB-VITRINE-1** articulation anarbib.org | ouvert | l'annuaire **data-driven** vit dans l'app ; le site vitrine (repo séparé) y **renvoie**, ne le duplique pas |
| **PUB-GEO-1** adresse / carte | ouvert | adresse exacte = niveau 2 (opt-in) ; **pas** de carte tierce chargée sans consentement (INV-5) |

> Les IDs `PUB-*` sont **proposés**, non actés. À arbitrer et inscrire au **REGISTRE** (foyer unique) avant l'implémentation des vues gated et des toggles.

---

## 6 — Séquence proposée

**Phase 0 — préalables (registre)**
- Arbitrer PUB-OPTIN-1/2 + PUB-SCHED-1 · confirmer PUB-VIS-1 (WHERE de `public_libraries`) · décider PUB-VITRINE-1.

**Phase 1 — annuaire (quasi zéro backend)**
- **#PUB1** : page `/bibliotecas` (cartes) sur `api.public_libraries` + i18n. Fort ratio, aucune donnée sensible, aucun risque doctrinal.

**Phase 2 — opt-in fin (backend gated)**
- **#PUB3** : drapeaux `*_is_public` + RPC coordenador + toggles dans l'admin Biblioteca · **#PUB4/#PUB5** : vues publiques contact + horaires filtrées sur l'opt-in.

**Phase 3 — fiche publique**
- **#PUB2** : page `/bibliotecas/:slug` (identité, état de service via `library_service_public`, site, + contact/horaires **si** opt-in) · **#PUB6** : rebond OPAC → fiche.

**Phase 4 — consolidation & finitions**
- **#PUB7** : résorber la dette horaires (§4.2) · entrée de navigation (PUB-NAV-1) · renvoi depuis le site vitrine (PUB-VITRINE-1).

**Transverse** : i18n 10 locales (DOC-I18N-1) par paquet · `npm run build` avant push (DOC-CLOSE-1) · recette **cloisonnement anon** en tête (tester `anon` vs membre : une biblio `network` ou une section non opt-in **ne doit jamais** fuiter).

---

## 7 — Couplage & dépendances

- **OPAC** (§18) : le filtre biblio existant est le point de rebond naturel vers la fiche (#PUB6). `public_libraries.notices_count` relie déjà annuaire ↔ catalogue.
- **Modèle d'accès concentrique** : `visibility_level` est l'ancrage du niveau 1 ; le chantier en est une application directe.
- **Module horaires (livré 17/06)** : `library_opening_hours` + `fn_upsert_library_opening_hours` — la fiche publique en est le débouché anon (via #PUB5). Dette de consolidation (§4.2) à résorber ici.
- **Contact public** : `library_public_contact` (données déjà saisies ×3) — réutilisé tel quel, juste exposé via vue gated.
- **Site vitrine anarbib.org** (repo statique séparé) : **renvoie** vers l'annuaire de l'app, ne le réimplémente pas (PUB-VITRINE-1).
- **Cartographie `.umap` sensible** : **aucun** croisement automatique — la fiche n'expose que l'opt-in explicite de la biblio (ligne rouge 5).
- **RGPD** : le contact/horaires publics relèvent d'un choix du collectif (base légale = décision interne de la biblio, pas donnée personnelle d'un tiers) ; à border au `REGISTRE_TRAITEMENTS.md` si la fiche expose des coordonnées nominatives.

---

## 8 — Checklist de démarrage

- [ ] PUB-OPTIN-1/2 + PUB-SCHED-1 arbitrés et inscrits au REGISTRE.
- [ ] **PUB-VIS-1** : lire la définition réelle de `api.public_libraries` (confirmer `WHERE visibility_level='public'`) avant d'en dépendre.
- [ ] Maquette annuaire (#PUB1) + fiche (#PUB2) validées (réutiliser le langage visuel de `MyLibraryContactCard`).
- [ ] Drapeaux d'opt-in : table(s) cible, défaut `false`, RPC coordenador, toggles admin.
- [ ] Vues `api.library_contact_public_v1` / `api.library_opening_hours_public_v1` (SECURITY INVOKER + REVOKE + grant anon, filtre opt-in).
- [ ] Lot i18n recensé (annuaire, fiche, toggles, libellés jours via `Intl`) × 10 locales.
- [ ] Scénarios de recette **cloisonnement** : `anon` voit une biblio `public` opt-in ; **ne voit pas** une biblio `network`, ni une section non opt-in, ni les données membre-only.
- [ ] Décision PUB-VITRINE-1 transmise à la session du site vitrine.

---

*Fin v0.1. Document de travail (trace). À tamponner 🔵 quand son contenu aura gradué dans `spec-fiche-publique-bibliotheque.md` + le `REGISTRE_decisions.md` (charte du corpus §4/§5). Les vues `api.library_contact_public_v1`, `api.library_opening_hours_public_v1`, les drapeaux `*_is_public` et les IDs `PUB-*` y sont **proposés**, non actés.*
