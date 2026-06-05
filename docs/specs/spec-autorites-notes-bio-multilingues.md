# spec — Notes biographiques multilingues des autorités

> **Statut** : mini-spec (à valider) · v0.1 · 2026-06-05
> **Chantier** : socle de données pour le futur module « Ateliers d'Autorités »
> **Option retenue** : **B — table dédiée** (arbitrée avec Xavier le 05/06)
> **Préséance** : ce document est une proposition. Le REGISTRE des décisions fait
> foi une fois l'arbitrage acté.

## 1. Contexte & besoin

Les fiches d'autorité (`authors`) portent aujourd'hui **une seule** biographie
monolingue : colonne `authors.biography` (text), dupliquée sur `author_drafts`.
État réel constaté en base (05/06) : **160 autorités**, dont **48 avec bio**.

AnarBib est multilingue (10 locales). Le futur module **« Ateliers d'Autorités »**
vise un **travail bénévole de complétion** des fiches auteur·rices **langue par
langue**. Cela suppose :

- N biographies par autorité, **une par langue** ;
- savoir **quelles langues sont remplies / manquantes** (matière du tableau de
  complétion des Ateliers) ;
- **tracer** qui a contribué quoi (travail bénévole) ;
- un **gating par rôle** (qui peut éditer).

La colonne `biography` unique ne permet aucun de ces points → besoin d'un modèle
relationnel.

## 2. Décision de modèle — option B

| Option | Forme | Verdict |
|---|---|---|
| A — JSONB | `authors.bio_notes jsonb` = `{locale: texte}` | ❌ pas de RLS/attribution/historique par note ; cul-de-sac pour du bénévolat tracé |
| **B — table dédiée** | `author_bio_notes(author_id, locale, …)` | ✅ granularité RLS, attribution, statut « à compléter », parité mesurable |

**Option B retenue.**

## 3. Modèle de données

### 3.1 Table `public.author_bio_notes`

```
CREATE TABLE public.author_bio_notes (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  author_id   bigint NOT NULL REFERENCES public.authors(id) ON DELETE CASCADE,
  locale      text   NOT NULL CHECK (locale IN
                ('pt-BR','fr','es','en','it','de','ca','eo','nl','el')),
  biography   text   NOT NULL DEFAULT '',
  status      text   NOT NULL DEFAULT 'draft'
                CHECK (status IN ('draft','reviewed')),
  updated_by  uuid   REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_by uuid   REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (author_id, locale)
);

CREATE INDEX author_bio_notes_author_id_idx ON public.author_bio_notes(author_id);
```

- **Clé sur l'autorité PUBLIÉE** (`authors.id`), pas le brouillon — voir §4
  (le travail des Ateliers porte sur le catalogue vivant, en continu, hors
  workflow brouillon→publication).
- `locale` contraint aux **10 locales** d'AnarBib (parité mesurable).
- `UNIQUE(author_id, locale)` : une bio par langue et par autorité.
- **Workflow de revue dès la v1 (Q4)** : `status` ∈ {`draft`,`reviewed`} +
  `reviewed_by`/`reviewed_at`. Toute édition repasse la note en `draft` ; une
  validation explicite la passe en `reviewed`. `updated_by` + timestamps tracent
  la contribution (bénévolat).

### 3.2 RLS & GRANT (doctrine `_TEMPLATE.sql`)

- **SELECT** : public (les bios paraissent sur les pages auteur·rice publiques)
  → `GRANT SELECT TO anon, authenticated` + policy `USING (true)`.
- **Écriture** : jamais en direct par la Data API → `REVOKE INSERT/UPDATE/DELETE
  FROM anon, authenticated` ; toute mutation passe par RPC SECURITY DEFINER
  (§3.3) avec contrôle de rôle interne.
- `GRANT ALL TO service_role`.
- `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + policy SELECT publique.

### 3.3 RPC d'écriture (SECURITY DEFINER)

```
public.upsert_author_bio_note(p_author_id bigint, p_locale text, p_biography text)
public.delete_author_bio_note(p_author_id bigint, p_locale text)
public.review_author_bio_note(p_author_id bigint, p_locale text)   -- status -> reviewed
```

- `SECURITY DEFINER`, `SET search_path = public, pg_catalog`.
- `REVOKE EXECUTE … FROM PUBLIC, anon` ; `GRANT EXECUTE … TO authenticated`.
- **Contrôle de rôle interne (Q3)** : v1 = **staff catalogação** — réutiliser le
  helper de rôle existant (p. ex. `user_can_act_as_staff_on_library` / rôle
  catalogação). Un **rôle bénévole dédié** (« contributeur Ateliers ») sera
  ajouté à l'inscription des premiers bénévoles (ajout rapide : élargir le
  contrôle de rôle des 3 RPC).
- `upsert_author_bio_note` : aligné sur `UNIQUE(author_id, locale)` ; met à jour
  `biography`, `updated_by = auth.uid()`, `updated_at = now()`, et **repasse
  `status` à `draft`** (toute édition annule la revue).
- `review_author_bio_note` : passe `status = 'reviewed'`, `reviewed_by =
  auth.uid()`, `reviewed_at = now()`.
- Notifier PostgREST en fin de migration si nécessaire (`NOTIFY pgrst`).

## 4. Articulation brouillon ↔ publié

- `authors.biography` (mono) **reste** comme champ legacy du brouillon
  (`author_drafts.biography`) : c'est la **note de langue par défaut** saisie au
  catalogage initial.
- À la **publication** d'un brouillon, `publish_author_draft` upserte la bio du
  brouillon dans `author_bio_notes(author_id, locale, biography)` avec
  **`locale` = locale de l'UI au moment du catalogage, défaut `pt-BR`** (Q1).
- Les **Ateliers** éditent ensuite directement `author_bio_notes` sur les
  autorités publiées, sans repasser par le brouillon.
- **Backfill (Q2)** : migrer les **48 bios existantes** →
  `author_bio_notes(author_id, 'pt-BR', biography, status='reviewed')`. Les bios
  actuelles sont considérées en **pt-BR** (UI pt-BR-first) et déjà validées
  (catalogage staff). On NE supprime PAS `authors.biography` dans cette migration
  (compat lecture ; dépréciation ultérieure).

## 5. Frontend

### 5.1 Mini-sélecteur de langue (immédiat)

Dans la surface d'édition des fiches autorité (onglet autorités) : un segmented
control de langues (réutiliser `.ab-seg` du Lot 4 catalogação ; liste depuis
`SUPPORTED_LOCALES` de `src/i18n/index.js`) au-dessus du textarea de bio. Il
swappe le contenu affiché selon la locale choisie. ~30 lignes.

- Indicateur visuel **rempli / vide** par langue (pastille) → préfigure le
  tableau de complétion des Ateliers.
- Écriture via `upsert_author_bio_note`.

### 5.2 Module « Ateliers d'Autorités » (ultérieur, hors cette spec)

S'appuie sur le socle ci-dessus : tableau de bord des langues manquantes,
file de complétion, gating bénévoles, éventuel workflow de revue.

## 6. Décisions actées (05/06)

- **Q1 ✅** — Locale au publish = **locale de l'UI au catalogage, défaut `pt-BR`**.
- **Q2 ✅** — Les 48 bios existantes sont traitées comme **pt-BR** ; backfill
  direct, marquées `status='reviewed'` (catalogage staff).
- **Q3 ✅** — Contribution v1 = **staff catalogação** ; **rôle bénévole dédié**
  ajouté plus tard (à l'inscription des premiers bénévoles — élargissement rapide
  du contrôle de rôle des RPC).
- **Q4 ✅** — **Workflow de revue dès la v1** : `status` ∈ {`draft`,`reviewed`} +
  `reviewed_by`/`reviewed_at` + RPC `review_author_bio_note`.
- **Q5 ✅** — **Mutualiser la migration avec Track D** (`variant_forms`, autorité
  multilingue) : une seule vague sur le domaine « autorité multilingue ».

## 7. Séquencement proposé

1. ~~Arbitrer §6~~ ✅ (fait le 05/06). Reporter les décisions au REGISTRE.
2. **Migration mutualisée avec Track D** (Q5) : table `author_bio_notes`
   (avec `status`/revue) + RLS + RPC `upsert`/`delete`/`review` (gating staff) +
   backfill des 48 bios en pt-BR `reviewed` + adaptation `publish_author_draft`
   (locale UI, défaut pt-BR) + colonnes Track D (`variant_forms`, etc.).
3. Frontend : mini-sélecteur de langue + pastilles rempli/vide + état revue
   (§5.1).
4. i18n : libellés du sélecteur et du statut de revue (10 locales).
5. Ultérieur : rôle bénévole dédié (Q3) + module « Ateliers d'Autorités » (§5.2).

---

*Doctrine : aucune migration appliquée via MCP ; fichier horodaté dans
`supabase/migrations/` → push → Woodpecker. Cette spec ne committe aucun code ;
elle cadre le travail.*
