---
Genre : référence
Statut : 🟡 cadrée
Décisions : incarne FS-D1…FS-D8 (REGISTRE §35) ; cite spec-sources-externes-autorites (D4 `variant_forms`, D6 identifiants au niveau autorité), spec-granularite-item (ordre nullable→backfill→NOT NULL), doctrine migrations (horodatage UTC exact)
Supersédé par : —
---

# Spec — Fonds d'archives sonores : modèle d'import et de catalogage des œuvres audio (`#AUDIO-fonds`)

- **Version :** 0.1 (cadrage initial)
- **Date :** 2026-06-21
- **Statut :** 🟡 cadrée — spécification de cadrage, arbitrages **proposés** (FS-D1…FS-D8) à ratifier avant implémentation.
- **Périmètre :** doter AnarBib d'un modèle de catalogage **fin** pour les fonds sonores (captations militantes : AG, conférences, chants, radios libres, entretiens d'histoire orale), en greffant le **modèle d'entités audio de MusicBrainz** sur les primitives existantes — sans importer ses données.
- **Auteur :** coordination AnarBib — rédaction assistée
- **Méthode :** audit de l'existant + réutilisation maximale (mêmes principes que `spec-sources-externes-autorites` : « réutiliser plutôt que réinventer », « une EF par concern », « chaque source = un candidat »).

**Dépendances entrantes :**
- `spec-granularite-item` (`#MODEL-item-grain`) — patron exemplaire/holding et **doctrine d'ordre de migration** (nullable → backfill → `NOT NULL`).
- `spec-sources-externes-autorites` v0.2 — couche autorité (VIAF/ISNI/Wikidata), `variant_forms`, identifiants au niveau autorité (D6), pattern EF.
- `spec-ressources-numeriques` — `book_digital_resources` (le fichier audio et son accès `escuta_online`).
- Schéma réel : `docs/schema/baseline_schema_2026-06-11.sql`.

**Dépendances sortantes :**
- `spec-acquisition-provenance` — toute notice/recording importé renseigne la traçabilité de source (`source_record_id`/`source_record_url`/`source_label`/`catalog_source`).
- `spec-oai-provider-gouvernance` — exposition des identifiants (dont MBID) pour l'interopérabilité fédérée.
- `spec-thesaurus-matiere` — indexation matière des œuvres sonores (réutilise `subjects`).

---

## 1. Objet & posture

AnarBib sait **déjà** cataloguer un objet sonore — à plat, comme une notice de plus. Cette spec ne réinvente pas ce socle : elle ajoute la **granularité intra-document** et la séparation **œuvre / enregistrement** que le modèle à plat ne sait pas exprimer, là et seulement là où un fonds sonore l'exige.

Posture, en une phrase : **on réutilise le _modèle_ de MusicBrainz, pas ses _données_.** Le modèle d'entités (Work / Recording / Release / Track / Artist / Label / Place / Event / Series) et son schéma d'identifiants (MBID) sont une référence de modélisation mûre, exactement adaptée au son ; la base et l'API de MusicBrainz, elles, ont une couverture quasi nulle pour de l'audio anarchiste et ne sont pas une source utile (cf. §4.3).

Principe directeur (hérité de la CHARTE — « une vérité, un foyer ») : **pas d'univers parallèle.** La notice `books` reste l'ancre de catalogage ; la nouvelle granularité est une **sous-couche opt-in** suspendue à cette notice, et réutilise l'autorité `authors`, les rôles à la `book_contributors`, le fichier `book_digital_resources`, les tables de référence `catalog_ref_*`.

---

## 2. Problème

Le modèle catalographique d'AnarBib est **FRBR aplati** : la table `books` confond œuvre, expression et manifestation en une seule notice, et `exemplares` porte l'item. Pour une monographie, c'est suffisant — c'est même ce qui fait sa simplicité.

Pour un fonds sonore, ce pli casse. L'audio militant est intrinsèquement **décomposé** :

> un **événement capté** (une AG, une conférence) → produit un ou plusieurs **enregistrements** → chacun découpé en **segments** (interventions, chants, prises de parole) → chaque segment réalisant une **œuvre** (un texte lu, un chant précis) → regroupés dans un **support / une collection** (une cassette, une émission, un fonds numérisé).

Le modèle à plat ne peut pas dire :
- « cette œuvre (un chant) existe dans **trois** enregistrements distincts » ;
- « cet enregistrement de 90 min contient **six** interventions, chacune avec son·sa locuteur·rice » ;
- « le·la _locuteur·rice_ de ce segment (rôle enregistrement) n'est pas l'_auteur·rice_ du texte lu (rôle œuvre) ».

C'est précisément la décomposition que MusicBrainz formalise.

---

## 3. État de l'existant (audit)

Vérifié dans `baseline_schema_2026-06-11.sql` :

- **`books`** gère déjà l'audio **à plat** : `tipo_material` ∈ CHECK inclut **`'audio'`** et **`'audiovisual'`** ; colonnes dédiées `audio_duration`, `audio_support`, `audio_format`, `audio_language`, `audio_participants`, `audio_recording_type` (et le pendant `audiovisual_*`). Plus `colecao` (collection, texte libre), `distribuidora`, `diffusion_place`.
- **`book_digital_resources`** porte le **fichier** : `resource_type` ∈ {…, `'audio'`, `'video'`} ; `usage_type` ∈ {…, `'escuta_online'`} ; `storage_bucket`/`storage_path`, `mime_type`, et un **`metadata jsonb`** libre. C'est le foyer naturel de l'empreinte audio (§6).
- **`authors`** est déjà une **autorité linked-data** : `viaf_id`, `isni`, `wikidata_id`, `variant_forms jsonb`, `structured_meta jsonb`. **Aucun champ MBID** aujourd'hui.
- **`book_authors`** (m:n, `role` défaut `'autor'`, `ord`) et **`book_contributors`** (`role`, `position`, `is_primary`, FK `author_id` optionnelle) : le patron « contributeur à rôle » existe.
- **`exemplares`** = support physique (cassette, bande) ; **`book_holdings`** = fonds par bibliothèque ; **`publishers`** ; **`subjects`/`book_subjects`** ; **`catalog_ref_*`** (formats, systèmes, méthodes… — patron de vocabulaire contrôlé).
- **EF existantes** réutilisables comme patrons : `catalog_metadata_lookup` (SRU/MARC), `authority_lookup` (VIAF/ISNI/Wikidata), `fetch-url-metadata`, `read-digital-asset`.
- **Front déjà outillé pour le wasm lourd côté navigateur** : `tesseract.js` (OCR), `@zxing/browser` + `jsqr` (codes-barres), `epubjs`. Le calcul d'empreinte audio en wasm s'inscrit dans ce patron existant (§6).

**Conclusion d'audit :** le socle « audio à plat » est en place et suffit pour un support simple. Il manque (a) la sous-couche de granularité, (b) le MBID, (c) l'empreinte.

---

## 4. Ce que MusicBrainz apporte — et ce qu'il n'apporte pas

### 4.1 Le modèle d'entités (réutilisé comme référence)

| Entité MusicBrainz | Greffe AnarBib (cf. §5) |
|---|---|
| **Work** (œuvre abstraite : un chant, un texte) | notice `books` réutilisée (FS-D4) |
| **Recording** (une captation précise) | nouvelle table `audio_recordings` |
| **Track / Medium** (segment positionné sur un support) | nouvelle table `audio_tracks` |
| **Release / Series** | `colecao` + la notice `books` (niveau document/support) |
| **Artist** | autorité **`authors`** (déjà VIAF/ISNI/Wikidata) |
| **Relationship types** (speaker, performer, composer, lyricist, sound engineer, interviewer…) | vocabulaire de rôles repris pour `audio_contributors` (FS-D5) |
| **Label** | `publishers` / `distribuidora` |
| **Place** (lieu de captation) | `diffusion_place` (texte) d'abord ; mini-autorité différée (Q2) |
| **Event** (l'AG/le concert capté) | **pièce manquante** — entité « événement capté » différée (Q2) |
| **MBID** | identifiant externe aligné sur la convention autorité (FS-D6) |

### 4.2 Les outils réellement réutilisables

- **Chromaprint** (lib LGPL-2.1) — calcul d'empreinte acoustique. Sert au **dédoublonnage** des numérisations et à l'identification, **indépendamment de toute présence dans MusicBrainz** (§6).
- **AcoustID** (API REST) — enrichissement optionnel à partir de l'empreinte (§6).
- **Le schéma MBID** — interopérabilité linked-data, cohérente avec la logique d'autorités existante.
- **La taxonomie des _relationship types_** — vocabulaire contrôlé de rôles pour `audio_contributors`.

### 4.3 Ce qu'on n'importe PAS

- **Le dump de la base** et les **lookups web-service live** : couverture ≈ nulle pour l'audio militant (discours, AG, chants inédits, radios libres ne sont pas dans MusicBrainz). On ne branche pas un agrégateur « source MusicBrainz » comme on l'a fait pour les SRU/BN : le rendement serait nul.
- Si un lookup AcoustID renvoie un MBID, il est traité **comme candidat** (jamais vérité automatique — même posture que Wikidata dans `spec-sources-externes-autorites` : « conserver la source, l'équipe choisit »).

### 4.4 Compatibilité de licences

Vérifié au regard des deux licences du dépôt (code AGPL-3.0, doc CC-BY-SA-4.0) :

- **Chromaprint = LGPL-2.1** → compatible avec une app AGPL, *a fortiori* utilisée comme lib/binaire séparé (ou wasm côté client). ✅
- **Modèle / schéma / taxonomie MB** = réutilisés comme inspiration de modélisation. ✅
- **Données _core_ MusicBrainz = CC0** → aucune obligation si jamais on en récupérait un fragment via AcoustID. ✅
- ⚠️ **Données _supplémentaires_ MB = CC-BY-NC-SA** : la clause **NC** frotterait avec un service en réseau **si** on réinjectait ces données. **On ne le fait pas** (FS-D1) → non concerné. À ne pas perdre de vue si l'enrichissement AcoustID s'élargissait un jour au-delà du seul MBID.

---

## 5. Modèle cible (re-ancré sur `works`)

> 🔁 **Révision 21/06/2026.** Cette section remplace la version initiale (qui supposait `books` à plat et inventait une table `audio_recordings`). Le modèle **FRBR-léger Œuvre → Édition → Exemplaire** est **livré en prod** (chantier `CADRAGE_modele_oeuvre_editions_2026-06-20`, lots `works_model_lot1..4` + `works_v2`/`works_v3`, 20/06). On s'y greffe — et le modèle audio en ressort **plus simple** : deux tables nouvelles au lieu de trois.

### 5.1 Le socle réel (vérifié en base, 20/06)

- **`public.works`** — autorité d'œuvre légère : `uniform_title`, `sort_title`, `primary_author_id → authors(id)`. RLS lecture OPAC / écriture staff. C'est l'**Œuvre** (le texte / chant intellectuel).
- **`books.work_id → works(id)`** (nullable) — l'**édition** (manifestation) rattachée à son œuvre ; les éditions d'une même œuvre partagent `work_id` (OPAC « autres éditions », RPC `api.work_public_detail`).
- **`public.work_expressions`** (`work_id`, `lang`, `unique(work_id,lang)`) + **`books.expression_id`** — l'**Expression** = une **langue** de l'œuvre, *dérivée* de `(work_id, idioma)` par le trigger `trg_sync_book_expression`. **Strictement par langue.**
- **`exemplares` / `book_holdings`** — l'**Item** (le support physique).
- **Contributeur·rices dérivé·es, jamais dupliqué·es** — doctrine `works_v3` : `work_public_detail` agrège les traducteur·rices *par expression* depuis `book_contributors` (`role='tradutor'`, `author_id`) des éditions, « la source de vérité reste le lien contributeur↔autorité, pas de colonne au niveau expression ». **On reprend ce patron pour l'audio.**

### 5.2 Le mapping MusicBrainz, re-câblé

| MusicBrainz | FRBR | AnarBib réel |
|---|---|---|
| **Work** (un chant, un texte) | Œuvre | **`public.works`** ✅ (entité réelle) |
| **Recording** (une captation) | Manifestation | **édition `books`** (`tipo_material='audio'`, `work_id`, `expression_id`) — *pas de table nouvelle* |
| **Release / fonds** | regroupement | `colecao` + `work_id` partagé |
| **Track / segment** | partie de manifestation | **NOUVEAU `audio_tracks`** |
| **Rôle** grain édition (interprète crédité·e) | contributeur | `book_contributors`, **dérivé** vers l'œuvre |
| **Rôle** grain segment (locuteur·rice d'une intervention) | — | **NOUVEAU `audio_track_contributors`** |
| **Label** | — | `publishers` / `distribuidora` |
| **MBID** | — | `external_ids` (autorité + segment) |

**L'insight central** : une **captation est une édition audio**. L'enregistrement de l'AG de 1977 = une notice `books` `tipo_material='audio'`, `work_id`→l'œuvre, `expression_id`→la langue. Trois captations d'un même chant = trois éditions audio partageant `work_id`, **déjà regroupées** par l'OPAC « autres éditions ». **Aucune table `audio_recordings` n'est nécessaire** (FS-D3 simplifié).

### 5.3 La seule sous-couche nouvelle : le segment (FS-D3 révisé)

Nécessaire uniquement pour la **granularité intra-document** : une cassette de 90 min portant **six interventions distinctes**, chacune réalisant une œuvre différente avec son·sa locuteur·rice. Esquisse :

```sql
-- Un segment positionné dans une édition audio (MB: Track)
create table public.audio_tracks (
  id              bigint generated always as identity primary key,
  book_id         bigint not null references public.books(id) on delete cascade,   -- l'édition audio
  position        int    not null,
  title           text,
  start_offset    text,            -- ex. '00:12:30'
  duration        text,
  work_id         bigint references public.works(id) on delete set null,           -- l'œuvre réalisée (FS-D4) ✅
  recording_date         date,     -- la captation peut varier d'un segment à l'autre
  recording_date_approx  text,     -- dates floues fréquentes en archives
  place_text      text,
  recording_type  text references public.catalog_ref_audio_recording_types(code),  -- §7
  external_ids    jsonb not null default '{}'::jsonb,   -- MBID recording / work
  notes           text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (book_id, position)
);
-- RLS calquée sur work_expressions : lecture OPAC, écriture staff (librarian/coordenador).
```

`audio_tracks.work_id → works(id)` **réutilise l'entité Œuvre réelle** (FS-D4 corrigé) : chaque segment réalise une œuvre sans surcharger `books`. Les métadonnées de captation (date / lieu / type) sont **au grain segment**, car un fonds agrège souvent des prises hétérogènes sur un même support.

### 5.4 Contributeur·rices — deux grains, une seule autorité

- **Grain édition** (un·e interprète crédité·e pour toute la captation) : `book_contributors` existant + rôles audio (§7), **dérivé** vers l'œuvre / expression à l'affichage, exactement comme `work_public_detail` agrège les traducteur·rices. **Aucune table nouvelle.**
- **Grain segment** (le·la locuteur·rice de l'intervention n°3) : non dérivable depuis l'édition → **NOUVEAU `audio_track_contributors`** (`track_id → audio_tracks`, `author_id → authors`, `role`, `position`, `is_primary`). Réutilise l'autorité **`authors`** (FS-D5) ; vocabulaire de rôles repris des _relationship types_ MB (§7).

→ **Deux tables nouvelles au total** (`audio_tracks` + `audio_track_contributors`), au lieu des trois envisagées initialement (`audio_recordings` disparaît).

### 5.5 Articulation exemplaire & circulation

- **`exemplares`** = support physique (cassette, bande), inchangé ; le lien support↔édition existe déjà (`exemplares → book_holdings → books`). **Q3 se dissout** : la captation EST l'édition `books`, pas une entité séparée.
- **Maille d'écoute** (`escuta_online` via `book_digital_resources`) : au niveau **édition** en V1, la granularité segment restant d'abord **descriptive** (Q4). Un « lire à partir du segment n » exploiterait `audio_tracks.start_offset` côté lecteur, sans circulation distincte.
- **Visibilité (FS-D9)** : en P1, `audio_tracks`/`audio_track_contributors` sont **staff-only** (lecture `librarian`/`coordenador`, écriture via RPC `api.audio_track_*` SECURITY DEFINER). L'exposition OPAC **anon-safe** (filtrée via `catalog_list_anon_v1`, comme `work_public_detail`) est **reportée en P3** — on ne fuite pas les titres de segments d'éditions non publiques.

---

## 6. Empreinte audio (Chromaprint / AcoustID)

### 6.1 Contrainte d'architecture — calcul côté client (FS-D7)

⚠️ **Point dur.** Le calcul d'une empreinte Chromaprint exige un décodage audio natif (`fpcalc`). **Les Edge Functions Deno ne sont pas le bon endroit** (pas de binaire natif, contrainte de bundle déjà rencontrée sur `notify-event`). Le patron du dépôt est clair et déjà éprouvé : **le traitement lourd se fait côté navigateur en wasm** (`tesseract.js` pour l'OCR, `@zxing/browser`/`jsqr` pour les codes-barres). On suit ce patron : **Chromaprint compilé en wasm, exécuté à l'upload côté client**, qui ne transmet que l'empreinte (texte) + la durée.

### 6.2 Flux

1. À l'upload d'un fichier audio (onglet Catalogação → ressource numérique), le client calcule l'empreinte Chromaprint (wasm).
2. L'empreinte est **stockée en colonnes dédiées de `book_digital_resources`** (`chromaprint_fp`, `acoustid_id`, `fingerprint_duration_ms`) — **ajoutées en P0** (migration `20260621162441`), indexées pour le dédoublonnage (FS-D7 ; tranche FS-Q5 vers les colonnes).
3. **Dédoublonnage interne** : comparaison de l'empreinte aux empreintes déjà connues du fonds (même prise sous plusieurs fichiers/formats) — utile **sans** réseau externe.
4. **Enrichissement optionnel** : une **EF dédiée `audio_fingerprint_lookup`** (pattern « une EF par concern ») interroge l'API **AcoustID** avec l'empreinte ; tout MBID renvoyé est un **candidat** (jamais écrit en aveugle), posé via la couche autorité/identifiants (§7).

### 6.3 Colonnes dédiées (tranché en P0)

FS-Q5 est **tranché vers les colonnes** dès P0 (le·la mainteneur·e a demandé un champ requêtable) : `acoustid_id`, `chromaprint_fp`, `fingerprint_duration_ms` sur `book_digital_resources`, avec **index partiel** sur `acoustid_id` pour le dédoublonnage. *(Le repli jsonb-first initialement envisagé est abandonné — volume faible, mais dédup requêtable d'emblée.)*

---

## 7. Identifiants externes & vocabulaires contrôlés

### 7.1 MBID (FS-D6)

Aligné sur la convention d'autorité existante (`viaf_id`/`isni`/`wikidata_id` — D6 de `spec-sources-externes-autorites`) :

- **Sur `authors`** : le MBID *artist* rejoint les identifiants externes (colonne `musicbrainz_id`, ou — préférable pour ne pas multiplier les colonnes — un `external_ids jsonb` consolidant viaf/isni/wikidata/musicbrainz). *Arbitrage de forme à trancher avec la couche autorité.*
- **Sur `audio_recordings` / `audio_tracks`** : MBID *recording* / *work* dans leur `external_ids jsonb`.

### 7.2 Vocabulaires (`catalog_ref_*`)

Mêmes patrons que les tables `catalog_ref_*` existantes :

- **`catalog_ref_audio_recording_types`** : `captation_live`, `studio`, `radio`, `terrain` (field), `entretien`, `autre`.
- **Vocabulaire de rôles `audio_contributors.role`**, repris de la taxonomie des _relationship types_ MusicBrainz : `locuteur` (speaker), `interprete` (performer), `compositeur`, `parolier` (lyricist), `preneur_son` (sound engineer), `intervieweur`, `interviewe`, `organisateur`, etc. — table de référence ou CHECK, à arrêter à l'implémentation.

---

## 8. Chemin à plat conservé (FS-D8)

Le socle « audio à plat » (`tipo_material='audio'` + colonnes `audio_*`) **reste** pour les holdings simples : un support = une notice, sans segmentation. La sous-couche §5 est **opt-in par notice**. Conséquence majeure : **aucune migration forcée** des notices audio déjà cataloguées — elles restent valides telles quelles, et n'acquièrent une granularité que si on la leur ajoute. Le coût d'adoption est donc nul pour l'existant.

---

## 9. Arbitrages proposés (à ratifier → REGISTRE)

| ID | Décision proposée |
|---|---|
| **FS-D1** | Réutiliser le **modèle** MusicBrainz, **pas ses données** : ni dump, ni lookup live MB (couverture nulle). AcoustID = enrichissement optionnel, MBID traité en candidat. |
| **FS-D2** | **Sous-couche opt-in**, pas d'univers parallèle : `books` reste l'ancre ; granularité ajoutée seulement quand le fonds l'exige. |
| **FS-D3** | ⚠️ **Révisé 21/06** : la captation = une **édition `books`** audio (pas de table `audio_recordings`). Seules tables nouvelles : **`audio_tracks`** (segment) + **`audio_track_contributors`** (FS-D5). |
| **FS-D4** | ⚠️ **Révisé 21/06** (modèle `works` réel, livré 20/06) : l'œuvre audio se rattache à **`public.works(id)`**, pas à une notice `books` ; `audio_tracks.work_id → works(id)`. Cf. amendement §5. |
| **FS-D5** | ⚠️ **Révisé 21/06** : crédits au **grain édition** = `book_contributors` existant, **dérivés** vers l'œuvre (patron `works_v3`) ; crédits au **grain segment** = nouvelle **`audio_track_contributors`** (`authors` + rôles MB). |
| **FS-D6** | **MBID** comme identifiant externe, aligné sur la convention autorité (viaf/isni/wikidata) — au niveau autorité **et** recording/track. |
| **FS-D7** | Empreinte **Chromaprint calculée côté client (wasm)**, stockée en **colonnes dédiées** de `book_digital_resources` (`chromaprint_fp`/`acoustid_id`/`fingerprint_duration_ms`, P0) ; **AcoustID** via EF dédiée `audio_fingerprint_lookup`. |
| **FS-D8** | **Chemin à plat conservé** pour les holdings simples ; **aucune migration forcée** de l'existant. |
| **FS-D9** | **Visibilité P1 = staff-only** (`audio_tracks`/`audio_track_contributors`) ; OPAC public-safe (via `catalog_list_anon_v1`) reporté en **P3**. Réf des types = lecture publique. *(✅ livré P1, migration `20260621180651`)* |

---

## 10. Questions ouvertes

- **Q1 — Œuvre.** ✅ **Résolu par le modèle `works`** (21/06) : l'œuvre audio = `public.works(id)`, l'entité réelle. Plus de surcharge de `books`, plus de table `audio_works`. *(cf. §5 re-ancré + FS-D4)*
- **Q2 — Place / Event.** MusicBrainz distingue **Place** (lieu) et **Event** (événement capté) comme entités. L'audio militant est massivement de l'**event recording**. V1 : rester en texte (`place_text`, `recording_date`). Créer une mini-autorité de lieu / une entité « événement » est différé — à arbitrer selon le volume réel.
- **Q3 — Support ↔ captation.** ✅ **Dissous** (21/06) : la captation EST une édition `books` ; le lien support↔édition passe par `exemplares → book_holdings → books`, déjà en place. Aucune FK audio nouvelle.
- **Q4 — Maille de circulation/écoute.** L'écoute (`escuta_online`) et la consultation portent-elles sur le segment, le recording ou la notice ? Aligner sur `spec-granularite-item` + `spec-ressources-numeriques`. Défaut V1 : granularité segment **descriptive**, écoute au niveau notice.
- **Q5 — Stockage empreinte.** ✅ **Tranché en P0** : colonnes dédiées indexées (`acoustid_id`/`chromaprint_fp`/`fingerprint_duration_ms` sur `book_digital_resources`), pas jsonb-first. *(cf. §6.3 + migration `20260621162441`)*

---

## 11. Périmètre & phasage

Découpage en paquets, du moins risqué au plus structurant (même esprit que `spec-sources-externes-autorites` §10) :

1. **P0 — Quick win, schéma minimal.** (a) MBID dans `authors.external_ids` ; (b) calcul Chromaprint côté client à l'upload + stockage en **colonnes** `book_digital_resources` (`chromaprint_fp`/`acoustid_id`/`fingerprint_duration_ms`) + **dédoublonnage interne**. **Prototypé** (migration `20260621162441`). **N'attend pas le reste.**
2. **P1 — Sous-couche granularité.** ✅ **Livré** (migration `20260621180651`, validé BEGIN/ROLLBACK) : `catalog_ref_audio_recording_types` (+seed), `audio_tracks` (`work_id→works`, `digital_resource_id`, `recording_type→réf`), `audio_track_contributors` (`authors` + rôle texte libre), **4 RPC** `api.audio_track_*` (staff), vue `v_audio_tracklist`. Visibilité **staff-only** (OPAC public-safe → P3). Cadrage `CADRAGE_fonds_sonores_P1_2026-06-21`.
3. **P2 — Enrichissement AcoustID.** ✅ **Livré** : EF `audio_fingerprint_lookup` (POST `{fingerprint, duration}` → candidats recordings MusicBrainz `{acoustid, score, recording_mbid, title, artists, musicbrainz_url}` ; `verify_jwt=true`, timeout 8 s, dégradé propre si pas de clé, **jamais bloquant** — FS-D1). ⚠️ **Requiert le secret `ACOUSTID_API_KEY`** (clé d'application AcoustID) côté Supabase, sinon lookup désactivé proprement.
4. **P3 — UI Catalogação + OPAC.** **P3a backend ✅ livré** (migration `20260621205119`) : RPC `api.audio_resource_set_fingerprint` (persiste l'empreinte client) + `api.audio_tracklist_public` (tracklist OPAC anon-safe via `catalog_list_anon_v1`, FS-D9). **P3b ✅ livré** (composant `AudioSegmentsBlock` greffé dans `BookDraftForm` : segments + crédits + **picker d'œuvre complet**, i18n ×10, build/test verts). **P3d ✅ livré** (tracklist sur la fiche publique `BookPage` via `api.audio_tracklist_public` public-safe, sans nouvelle clé i18n). **P3c ✅ livré** (composant `AudioFingerprintTool` : fichier → empreinte wasm `@unimusic/chromaprint` → EF → candidats → « Appliquer » ; wrapper `lib/chromaprintFingerprint.js` sans top-level await, wasm émis en asset, build vert). **Reste à valider le round-trip live en navigateur** (morceau connu → MBID attendu).
5. **P4 — i18n** ✅ **livré** : libellés segments + rôles réutilisés (P3b) + **erreurs `error.audio.*`** (11 clés × 10 + `localizeError` Cas 1b).
6. **P5 — Interop.** Exposition MBID via `spec-oai-provider-gouvernance`.

---

## 12. Migration & doctrines (rappel impératif)

Tout paquet DB de cette spec suit les doctrines actives du dépôt :

- **Ordre de migration** (doctrine `spec-granularite-item`) : colonne **nullable** → **backfill par script de migration** → contraintes `NOT NULL`/FK **après**. Jamais l'inverse. *(Ici, FS-D8 limite la casse : les nouvelles tables sont vides, peu de backfill — mais l'ajout d'un `external_ids`/MBID sur `authors` suit la règle.)*
- **Horodatage UTC EXACT** des fichiers `YYYYMMDDHHMMSS_*.sql` (jamais arrondi ; vérifier le max présent ; sessions parallèles → `max + 1 s`).
- **Doctrine objets sécurisés** : tables → `ENABLE ROW LEVEL SECURITY` + GRANT explicites + policies dédiées ; vues → `security_invoker = on` ; fonctions → `SECURITY DEFINER` + `SET search_path = public` + `REVOKE … FROM PUBLIC, anon, authenticated, service_role` puis `GRANT` ciblé.
- **Bloc `DO`** de vérification en fin de chaque migration (présence colonnes/FK/contraintes ; aucun orphelin).
- Le hook `.githooks/pre-commit.ps1` garde-fou ces points — l'activer (`git config core.hooksPath .githooks`).
- **Déploiement** par push (Forgejo Actions, job `backend`) ; jamais le SQL Editor avant push, jamais `apply_migration` via MCP.

---

## 13. i18n

- Nouvelles clés : libellés des entités (recording, segment/track, rôles), types de captation, libellés de l'onglet audio Catalogação, lecteur de tracklist.
- **10 locales en parité stricte** (gardée par la CI, `i18n.test.js`), `pt-BR` référence, charte de langage inclusif v2. Les rôles (`locuteur`, `interprete`…) suivent les conventions inclusives par locale.

---

## 14. Risques & vigilance

- **Chromaprint hors EF (P0).** Le calcul natif n'a pas sa place en Edge Function Deno — **côté client en wasm** (patron `tesseract.js`/`zxing`). Ne pas tenter un `fpcalc` serveur dans une EF.
- **Couverture MB nulle = pas d'agrégateur MB.** Ne pas reproduire le pattern SRU/BN pour MusicBrainz : le rendement serait nul (FS-D1). AcoustID seul, en candidat.
- **Surcharge sémantique de `books` (Q1).** La double casquette document/œuvre est commode mais doit être assumée explicitement, sous peine de drift de modèle.
- **Licence NC (§4.4).** Si l'enrichissement AcoustID s'élargit aux données supplémentaires MB (CC-BY-NC-SA), réévaluer la compatibilité avec le service en réseau. Le MBID seul (identifiant) ne pose pas ce problème.
- **Dates floues.** Les archives ont des dates approximatives : prévoir `recording_date_approx` à côté de `recording_date` dès P1.
- **Ne pas sur-modéliser (Q2).** Place/Event en entités n'est justifié qu'au volume — rester en texte tant que le besoin n'est pas démontré.

---

## 15. Liens

- **Granularité / migration :** `spec-granularite-item` (`#MODEL-item-grain`).
- **Autorités & identifiants externes :** `spec-sources-externes-autorites` v0.2 (VIAF/ISNI/Wikidata, `variant_forms`, pattern EF, candidat ≠ vérité).
- **Fichier & écoute :** `spec-ressources-numeriques` (`book_digital_resources`, `escuta_online`).
- **Provenance :** `spec-acquisition-provenance` (traçabilité de source).
- **Interop :** `spec-oai-provider-gouvernance` (exposition MBID).
- **Matière :** `spec-thesaurus-matiere`.
- **Schéma :** `docs/schema/baseline_schema_2026-06-11.sql` (`books`, `authors`, `book_digital_resources`, `book_contributors`, `catalog_ref_*`, `exemplares`, `book_holdings`).
- **Ressource externe :** MusicBrainz Developer Resources — https://musicbrainz.org/doc/Developer_Resources (modèle d'entités, MBID, Chromaprint/AcoustID, taxonomie des relationship types).

---

*Fin v0.1 (cadrage). Arbitrages **proposés** FS-D1…FS-D8, à ratifier puis inscrire au `REGISTRE_decisions.md` ; questions ouvertes Q1–Q5. À l'implémentation : commencer par P0 (MBID + empreinte client, sans bouleversement), réserver la sous-couche §5 aux fonds qui en ont besoin. À inscrire à `INDEX.md` et `INVENTAIRE.md` (CHARTE §5).*
