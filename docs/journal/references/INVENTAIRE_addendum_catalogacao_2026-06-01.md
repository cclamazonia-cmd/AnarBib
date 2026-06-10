# 📋 Addendum INVENTAIRE — chantier Catalogação (4 specs)

**Date** : 1ᵉʳ juin 2026
**À intégrer dans** : `INVENTAIRE.md` (carte de dépendances + fiches de référence) et `INDEX.md` (navigation par domaine)
**Objet** : réinjecter les quatre specs du chantier Catalogação et **figer l'ordre de mise en œuvre** à l'aune des points de vigilance.

---

## 🗺️ Carte des dépendances — ajouts

Lecture : **A → B** = « A dépend de B ».

```
spec-catalogacao-fiche-et-paliers v0.4         (UX/champs — aucune migration DB)
  ├──→ spec-exemplaires-circulation (le padrão fiche sème la destination)
  ├──→ spec-module-capas (emplacement + ancre cover_object_path)
  └──→ spec-sources-externes-autorites (champs viaf/isni/wikidata, niveau autorité — D6)

spec-exemplaires-circulation v0.2              (couche DESTINATION)
  ├──→ spec-granularite-item  (#MODEL-item-grain — couche TRACE, prérequis matrice)
  ├──→ spec-acquisition-provenance (couche PROVENANCE — migration exemplares MUTUALISÉE)
  └──→ spec-catalogacao-fiche-et-paliers (padrão de circulation)

spec-module-capas v0.1                         (couverture — EF cover_lookup)
  ├──→ spec-catalogacao-fiche-et-paliers (emplacement réservé §5.3)
  └──→ spec-exemplaires-circulation (doublon → pas de re-upload de capa)

spec-sources-externes-autorites v0.2           (sources + autorité — EF)
  ├──→ spec-catalogacao-fiche-et-paliers (champs d'autorité au Completo)
  └──→ spec-acquisition-provenance (traçabilité de source à l'application d'une candidate)
```

> **Les trois couches de l'exemplaire** (clé de lecture transverse) : **trace** (`#MODEL-item-grain`) · **provenance** (`spec-acquisition-provenance`) · **destination** (`spec-exemplaires-circulation`). Elles partagent les tables `exemplares` / `exemplar_drafts` → d'où la migration mutualisée.

---

## 📚 Fiches de référence — les 4 specs

### 🗂️ `spec-catalogacao-fiche-et-paliers.md`
**Domaine** : fiche de catalogage, registre de champs déclaratif, 3 paliers, lisibilité.
**Version** : v0.4 (01/06) · **Statut** : 🟡 spécifiée, à implémenter (premier lot, **aucune migration DB**).
**Périmètre** : registre déclaratif (8.E), paliers `simple | advanced | complete`, 12 types × champs (sourcés sur les guide strings i18n), lisibilité = adoption des classes `.ab-*`, i18n 8 locales.
**Dépendances sortantes** : exemplaires (padrão), capas (emplacement), sources (champs autorité).
**Chantiers liés** : maquette v2 (référence visuelle). Promotion 🟢 après cahier des charges chrome + diff 7 locales.
**Points d'attention** : chrome (header/hero/polices) = harmonisation avec les pages existantes ; pt-BR strict (corrections *volante*/*lambe-lambe*).

### 🔄 `spec-exemplaires-circulation.md`
**Domaine** : couche **destination** de l'exemplaire (`circulation_policy` + `visibility`), padrão↔override, doublons fédérés.
**Version** : v0.2 (01/06) · **Statut** : 🟡 spécifiée, **coordonnée** avec item-grain + acquisition.
**Périmètre** : 2 colonnes (`text`+CHECK), padrão→seed→override, flux doublon→exemplaire, filtre catalogue public, matrice d'actions, gardes RPC/RLS.
**Dépendances entrantes** : `#MODEL-item-grain` (trace), `spec-acquisition-provenance` (migration mutualisée), fiche (padrão).
**Points d'attention** : **migration `exemplares` à co-rédiger** avec acquisition §5.1 ; matrice §6 inopérante avant le cœur item-grain.

### 🖼️ `spec-module-capas.md`
**Domaine** : couverture — stockage stable + recherche automatique (EF `cover_lookup`).
**Version** : v0.1 (01/06) · **Statut** : 🟡 spécifiée. **P1 (fix chemin) = bug autonome livrable immédiatement**.
**Périmètre** : chemin `bib_ref`/draft-id stable (fin collision `books/new/`), EF `cover_lookup` (Open Library + Wikimedia + page-1-PDF différé), UI galerie, anti-tracking, attribution `cover_source`/`cover_license`.
**Dépendances entrantes** : fiche (emplacement §5.3), exemplaires (pas de re-upload au rattachement).
**Points d'attention** : page-1-PDF = sous-paquet lourd différé ; capa appartient à la fiche partagée (clé `book_id` post-publish).

### 🌐 `spec-sources-externes-autorites.md`
**Domaine** : sources de métadonnées + couche autorité cross-lingue.
**Version** : v0.2 (01/06) · **Statut** : 🟡 spécifiée.
**Périmètre** : LoC réactivée (gardée), Wikidata/Open Library (adaptateurs REST dans `catalog_metadata_lookup`), **BN Brasil = réutilisation de l'EF scraper Sophia existante**, EF dédiée `authority_lookup`, Atelier autorités, `viaf/isni` au niveau autorité + `wikidata` aux deux (D6).
**Dépendances entrantes** : fiche (champs autorité), acquisition (traçabilité de source).
**Points d'attention** : scraper BN fragile (repli manuel + canari) ; LoC = diagnostic avant réactivation ; isoler l'autorité dans sa propre EF.

---

## 🧭 Ordre de mise en œuvre — pour ne pas faire de conneries

L'ordre n'est pas l'ordre d'écriture des specs (#1→#4) mais l'ordre dicté par les **dépendances dures**. Le **chemin critique est étroit** ; le reste se mène **en parallèle**.

### Chemin critique (séquentiel, à respecter)

- **Phase 0 — `#MODEL-item-grain` cœur.** L'`item_id` sur tous les circuits (dont la consultation). **Pierre angulaire** : sans elle, la matrice d'actions par exemplaire est impossible et `#ILL-availability` reste bloquée sur « une consultation bloque tout le fonds ».
- **Phase 1 — Migration foncière `exemplares` / `exemplar_drafts`, EN UNE SEULE VAGUE.** Ajoute **provenance** (acquisition §5.1) **et** destination `circulation_policy` + `visibility` (exemplaires §4.2) ensemble. Backfill (`visibility=public`, `policy` dérivé du padrão) + DO-block de vérification.
- **Phase 2 — Circulation effective.** padrão→seed→override (exemplaires §5) ; **matrice d'actions + filtre catalogue public + resserrement `#ILL-availability`** (exemplaires §6 — **dépend de la Phase 0**).
- **Phase 3 — Doublons fédérés.** Garde au publish (RAISE + hint) + `api.attach_exemplar` (exemplaires §7).

### Tracks parallèles (peu de dépendances dures)

- **Track A — Catalogação fiche/paliers (#1).** Aucune migration DB → **démarrable immédiatement** (registre, paliers, lisibilité par adoption des `.ab-*`, i18n). Seul couplage doux : le *padrão* de circulation (valeurs alignées sur `circulation_policy`).
- **Track B — Capas (#3).** **P1 (fix chemin) livrable tout de suite** (bug réel, zéro dépendance). Puis P2 `cover_lookup` (Open Library + Wikimedia) ; P3 page-1-PDF **différé**.
- **Track C — Sources/autorités (#4).** P1 LoC (diagnostic→réactivation gardée) ; P2 adaptateurs REST (Wikidata/OL) ; P3 BN Brasil (réutilise l'EF scraper) ; P4 `authority_lookup` + Atelier. Indépendant de la migration foncière.

### ⛔ Les conneries à ne pas faire (garde-fous durs)

1. **Jamais deux migrations séparées sur `exemplares`** (acquisition + destination) → **une seule vague co-rédigée** (sinon `relation already exists` / double vague).
2. **Jamais la matrice d'actions (#2 §6) avant le cœur item-grain** → sinon la consultation ne se résout pas par exemplaire et la matrice est fausse.
3. **Jamais réactiver LoC à l'aveugle** → diagnostic de la cause de désactivation d'abord.
4. **Jamais faire dépendre la catalogação de la seule BN auto** (scraper fragile) → repli manuel + canari de surveillance.
5. **Surveiller la taille de bundle des EF** (`cover_lookup` + page-1-PDF ; `authority_lookup`) → bascule CLI si > ~150 ko (cas connu `notify-event`).
6. **Jamais uploader une capa avant save** (collision `books/new/`) → corriger le chemin (capas P1) d'abord.
7. **Déploiement uniforme** : `git push` → Woodpecker pour **tout** (migrations via `supabase db push --linked`, EF via `deploy-edge-functions`). **Jamais** MCP `apply_migration` / `deploy_edge_function`, **jamais** SQL Editor manuel.

### Lecture express

```
Phase 0  item-grain cœur ───┐
Phase 1  migration mutualisée exemplares (provenance + destination)
Phase 2  circulation (seed/override + matrice + filtre + #ILL-availability)
Phase 3  doublons fédérés (publish guard + attach_exemplar)

   ║ en parallèle, dès maintenant ║
Track A  catalogação fiche/paliers (#1)        [aucune dépendance DB]
Track B  capas P1 fix chemin → P2 lookup → P3 PDF (différé)
Track C  sources : LoC → REST(Wikidata/OL) → BN(réutil.) → authority_lookup
```

---

## 🗂️ À faire dans `INVENTAIRE.md` / `INDEX.md`

- Ajouter les 4 fiches ci-dessus à la section « Specs de référence » et leurs arêtes à la carte de dépendances.
- Ajouter une entrée de domaine **« Catalogação »** dans `INDEX.md`.
- Reporter la micro-retouche **D6** déjà appliquée à `spec-catalogacao-fiche-et-paliers` §5.2.
- **En attente de ton feu vert** : ajout de `og:image` (`fetch-url-metadata`) comme 4ᵉ source de `cover_lookup` (spec #3).
