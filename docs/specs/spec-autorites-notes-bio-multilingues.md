# spec — Notes biographiques multilingues des autorités

> **Statut** : mini-spec (à valider) · **v0.2** · 2026-06-05
> **Chantier** : socle de données pour le futur module « Ateliers d'Autorités »
> **Révision v0.2** : la table multilingue **existe déjà** (`author_translations`).
> On **étend l'existant** au lieu de créer `author_bio_notes` (l'option « table
> dédiée » de la v0.1 est de facto déjà en place).
> **Préséance** : proposition. Le REGISTRE des décisions fait foi une fois acté.

## 1. Contexte & état réel (vérifié en base le 05/06)

AnarBib est multilingue (10 locales). Le futur module **« Ateliers d'Autorités »**
vise un **travail bénévole de complétion** des fiches auteur·rices **langue par
langue** : N bios par autorité, savoir quelles langues manquent, tracer les
contributions, gating par rôle.

**Découverte v0.2** : ce socle existe déjà.

- `authors.biography` (text) + `author_drafts.biography` : bio **monolingue
  legacy** (saisie au catalogage). 160 autorités, 48 avec bio.
- **`public.author_translations`** : table multilingue **déjà en place** —
  - `id` (PK), `author_id` (FK → `authors(id)` ON DELETE CASCADE),
    `lang` (text), `biography` (text NOT NULL), `translator_notes` (text),
    `created_by`/`updated_by` (uuid), `created_at`/`updated_at`.
  - **UNIQUE (author_id, lang)**.
  - RLS activée, 2 policies : `author_translations_public_read` (SELECT `true`)
    et `author_translations_librarian_write` (ALL, gated `librarian`/`coordenador`
    via `user_library_memberships`).
  - Données réelles : **48 pt-BR + 6 fr**.
  - Le frontend (`AuthorDraftForm`, bloc bio) lit/écrit déjà cette table.

> ⚠️ **Bug corrigé en parallèle (05/06)** : le GRANT écriture pour `authenticated`
> manquait (seul SELECT), rendant la policy `librarian_write` inopérante → le
> upsert frontend échouait. Corrigé par migration
> `20260605190000_fix_author_translations_grants.sql`.

## 2. Décision de modèle — v0.2

**Étendre `author_translations`** (et NON créer `author_bio_notes`). La table
remplit déjà le rôle de l'« option B » : granularité par langue, attribution,
parité mesurable. Créer une 2ᵉ table ferait doublon et fragmenterait les données
(48+6 lignes déjà présentes). On ajoute seulement ce qui manque pour les Ateliers.

### Manques à combler

| Besoin | Manque actuel | Ajout |
|---|---|---|
| Workflow de revue (Q4) | pas de `status` | `status` + `reviewed_by`/`reviewed_at` |
| Parité de locale fiable | `lang` libre (toute chaîne) | CHECK sur les 10 locales |
| Écriture frontend | GRANT manquant | ✅ déjà corrigé (migration séparée) |
| Rôle bénévole (Q3) | policy gated librarian/coordenador | élargissement ultérieur de la policy |

## 3. Migration (mutualisée Track D — Q5)

```sql
ALTER TABLE public.author_translations
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'reviewed'
    CHECK (status IN ('draft','reviewed')),
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;

-- CHECK locale (les 48 pt-BR + 6 fr existants sont compatibles).
ALTER TABLE public.author_translations
  ADD CONSTRAINT author_translations_lang_check
  CHECK (lang IN ('pt-BR','fr','es','en','it','de','ca','eo','nl','el'));
```

- `status` **défaut `reviewed`** : les lignes existantes (saisies par le staff)
  sont considérées validées ; les nouvelles contributions bénévoles passeront en
  `draft` côté RPC/UI (voir §3.1).
- CHECK `lang` : fige la parité sur les 10 locales (rejette les codes hors liste).
- **Mutualisation Q5** : cette migration co-embarque les colonnes Track D
  d'autorité multilingue (`variant_forms jsonb`, et au besoin la
  consolidation `viaf_id`/`isni`/`wikidata_id` déjà présentes) — un seul fichier
  horodaté.

### 3.1 Écriture & revue

- **Upsert bio** : conserver l'écriture directe gated par RLS (design existant
  `librarian_write`, désormais fonctionnel grâce au GRANT). À l'upsert, une
  nouvelle contribution doit poser `status='draft'` + `updated_by=auth.uid()`.
- **Revue** : passage `status='reviewed'` + `reviewed_by`/`reviewed_at`. Deux
  options (à trancher) : (a) update direct gated par une policy de revue dédiée,
  ou (b) RPC `review_author_translation(author_id, lang)` SECURITY DEFINER. *(reco
  (b) si la revue doit être réservée à un rôle distinct du contributeur.)*
- **Q3** : v1 = `librarian`/`coordenador` (policy actuelle). Rôle bénévole dédié
  ajouté plus tard en élargissant la policy `librarian_write`.

## 4. Articulation brouillon ↔ publié

- `authors.biography` / `author_drafts.biography` : **conservés** comme champ
  legacy de la langue par défaut au catalogage. Dépréciation possible plus tard.
- À la **publication** d'un brouillon, `publish_author_draft` devrait upserter la
  bio du brouillon dans `author_translations(author_id, lang, biography)` avec
  **`lang` = locale de l'UI au catalogage, défaut `pt-BR`** (Q1).
  ⚠️ **À vérifier en implémentation** : `publish_author_draft` écrit-il déjà dans
  `author_translations` ? (sinon, l'ajouter.)
- **Backfill (Q2)** : déjà effectif — 48 pt-BR (+ 6 fr) présents. Aucune reprise
  nécessaire ; le défaut `status='reviewed'` les marque validés.

## 5. Frontend

### 5.1 Mini-sélecteur de langue (immédiat)

`AuthorDraftForm` a déjà un bloc bio multilingue (le `<details>` réparé le 05/06).
À faire évoluer :
- Segmented control `.ab-seg` (Lot 4) listant les 10 locales, **pastille
  rempli / vide** par langue (matière du tableau de complétion Ateliers).
- Indicateur de **statut de revue** (`draft`/`reviewed`) par langue.
- Écriture via le chemin existant (upsert gated RLS) en posant `status='draft'`.

### 5.2 Module « Ateliers d'Autorités » (ultérieur)

Tableau des langues manquantes/à revoir, file de complétion, gating bénévoles,
validation (revue). S'appuie entièrement sur `author_translations` étendue.

## 6. Décisions actées (05/06)

- **Q1 ✅** — Locale au publish = locale de l'UI au catalogage, défaut `pt-BR`.
- **Q2 ✅** — Backfill déjà en place (48 pt-BR + 6 fr) ; existants = `reviewed`.
- **Q3 ✅** — Écriture v1 = `librarian`/`coordenador` (policy existante) ; rôle
  bénévole dédié ajouté plus tard (élargissement de policy).
- **Q4 ✅** — Workflow de revue dès la v1 : `status` + `reviewed_by`/`reviewed_at`.
- **Q5 ✅** — Migration mutualisée avec Track D (`variant_forms`, autorité
  multilingue) : une seule vague.
- **Q6 (v0.2) ✅** — Étendre `author_translations`, ne pas créer `author_bio_notes`.

## 7. Séquencement proposé

1. ~~Bug GRANT author_translations~~ ✅ (migration `20260605190000`, à pousser).
2. **Migration mutualisée Track D** : `ALTER author_translations` (status/revue +
   CHECK lang) + colonnes Track D (`variant_forms` …) + revue de
   `publish_author_draft` (upsert vers author_translations, §4) + RPC de revue si
   option (b).
3. Frontend : sélecteur de langue + pastilles rempli/vide + statut de revue (§5.1).
4. i18n : libellés du sélecteur et du statut (10 locales).
5. Ultérieur : rôle bénévole dédié (Q3) + module « Ateliers d'Autorités » (§5.2).

---

*Doctrine : aucune migration appliquée via MCP ; fichier horodaté dans
`supabase/migrations/` → push → Woodpecker. Cette spec ne committe aucun code.*
