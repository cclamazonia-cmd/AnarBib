# spec — Liaison autorités ↔ œuvres (rattachement des contributeurs)

> **Statut** : mini-spec · **v0.2** · 2026-06-05 (Q1–Q6 actées)
> **Chantier** : contrôle d'autorité — relier une autorité publiée à ses œuvres
> (volet du module « Ateliers d'Autorités »).
> **Préséance** : proposition. Le REGISTRE fait foi une fois acté.

## 1. Contexte & trou fonctionnel (vérifié en base le 05/06)

Symptôme : une autorité créée à la main (ex. Hugues LENOIR, `authors.id=10120`)
n'est rattachée à **aucun** de ses livres pourtant présents au catalogue. Sa
fiche publique reste vide.

Cause : le rattachement contributeur→autorité **n'est pas implémenté**.

- `public.link_book_contributors_to_authors(book_id)` → **stub** `select true;`
- `public.link_author_to_book_contributors(author_id)` → **stub** `select true;`

Les 726 liens existants proviennent de l'**import initial**, pas de ces
fonctions. Tout auteur catalogué à la main reste orphelin.

## 2. Modèle de données réel

Deux représentations **parallèles**, **non synchronisées** (aucun trigger) :

- **`book_contributors`** (contributeurs structurés, par livre) :
  `id, book_id, author_id (FK authors, NULLABLE), position, name (texte),
  role, is_primary, created_at, updated_at`.
  → Le **lien d'autorité** est `author_id`. `NULL` = contributeur en texte seul.
- **`book_authors`** (table de lien dénormalisée) :
  `book_id, author_id, role, ord, created_at`.
  → Utilisée par la **RLS `authors_public_read`** et la fiche auteur publique
  pour lister les œuvres d'une autorité.
- `books.autor` (texte libre) = **affichage legacy** sur la fiche livre,
  **non autoritatif** (ne participe pas au lien).

⚠️ **Constat clé** : poser `book_contributors.author_id` ne crée PAS
automatiquement la ligne `book_authors` (pas de trigger). Toute logique de
liaison doit **maintenir les DEUX** de façon cohérente. *(Décision Q3 : trigger
de synchro vs maintien explicite dans la RPC — voir §6.)*

### État LENOIR (illustration)

| Livre | Contributeur | author_id | book_authors |
|---|---|---|---|
| 919, 926, 2301 | « Lenoir, Hugues » / « LENOIR, Hugues » | NULL | absent |
| 1628, 1633 | Joyeux→10014 ✅ ; Lenoir (pos. 4, « Lenoir, Hughes »/typo) | NULL | Joyeux seul |

→ Tous les contributeurs Lenoir sont `author_id NULL`. Les formes varient
(casse, « Hughes » typo).

## 3. Stratégie de matching (le cœur du problème)

Lier par nom est **délicat** (contrôle d'autorité) :

- **Normalisation** : casse-insensible, accents repliés, ordre « Nom, Prénom »
  normalisé, espaces/ponctuation compactés. Comparer la forme normalisée du
  contributeur (`book_contributors.name`) à :
  - `authors.preferred_name` et `authors.sort_name` normalisés ;
  - les **formes variantes** `authors.variant_forms` (jsonb, colonne ajoutée le
    05/06) — utile pour « Hughes » (typo) ou graphies alternatives.
- **Typos / quasi-égalité** : option `pg_trgm` (similarité trigramme, seuil) pour
  rattraper « Hughes » vs « Hugues ». *(Q1 : exact-normalisé seul vs trigramme.)*
- **Homonymes** : NE JAMAIS fusionner deux personnes distinctes par nom seul.
  → matching = **proposition de candidats**, **confirmation humaine** obligatoire
  pour les correspondances non certaines. *(Q2 : auto-appliquer les exacts ?)*
- **Identifiants d'autorité** (viaf/isni/wikidata) : pas portés par
  `book_contributors` aujourd'hui → désambiguïsation par identifiant différée
  (Track D). Le matching v1 reste nominal.

## 4. Fonctions à implémenter

Toutes `SECURITY DEFINER`, `SET search_path`, REVOKE PUBLIC/anon, GRANT staff
(librarian/coordenador), et **maintien cohérent `book_contributors.author_id`
↔ `book_authors`**.

- **`suggest_author_book_matches(p_author_id)`** → renvoie les
  `book_contributors` non liés (`author_id IS NULL`) dont le nom normalisé
  matche l'autorité, avec un **score** (exact / variante / trigramme). Lecture
  seule (pour l'UI de revue).
- **`confirm_author_book_link(p_author_id, p_contributor_id)`** → pose
  `book_contributors.author_id = p_author_id` ET upserte la ligne
  `book_authors(book_id, author_id, role, ord)`. Idempotent.
- **`unlink_author_book(p_author_id, p_contributor_id)`** → inverse (corriger une
  erreur de rattachement).
- (Optionnel) **`link_book_contributors_to_authors(p_book_id)`** : au publish
  d'un livre, proposer/lier les contributeurs aux autorités exactes. Remplace le
  stub.

## 5. Frontend

Deux chemins complémentaires :

1. **Rétroactif (backlog)** — sur la fiche autorité publiée : bouton
   « Rattacher aux œuvres » → liste les candidats (`suggest_author_book_matches`)
   avec titre/score → le staff coche → `confirm_author_book_link`. Résout le cas
   LENOIR et tout l'historique importé en texte.
2. **À la source (préventif)** — dans le formulaire livre, sur chaque ligne
   contributeur : un **sélecteur d'autorité** (recherche `authors`) qui pose
   `author_id` explicitement. Empêche le problème de se reproduire.

## 6. Décisions actées (05/06)

- **Q1 ✅** — Matching = **exact-normalisé + variantes + `pg_trgm`**. Les
  correspondances trigramme sont affichées « approximatives », **jamais
  auto-confirmées**.
- **Q2 ✅** — **Validation humaine toujours** : même un match exact est proposé,
  jamais appliqué seul (protège des homonymes parfaits). Confirmation par lot.
- **Q3 ✅** — **Trigger** de synchro `book_contributors.author_id` → `book_authors`
  (cohérence garantie quelle que soit la source d'écriture).
- **Q4 ✅** — v1 = **rétroactif + préventif ensemble** (outil « Rattacher aux
  œuvres » **et** sélecteur d'autorité par contributeur dans le form livre).
- **Q5 ✅** — Désambiguïsation par identifiants (viaf/isni/wikidata) **différée à
  Track D** ; v1 = matching nominal.
- **Q6 ✅** — Cas LENOIR relié **via le futur outil** (dogfooding) ; pas de
  migration ponctuelle.

## 7. Séquencement (Q1–Q6 actées)

1. ~~Arbitrer §6~~ ✅ (05/06). Reporter au REGISTRE.
2. **Migration** : extension `pg_trgm` (si absente) + `fn_normalize_name`
   (immutable) + **trigger** de synchro `book_contributors.author_id` →
   `book_authors` (Q3) + RPC `suggest_author_book_matches` (exact/variante/
   trigramme, score) + `confirm_author_book_link` (pose author_id ; le trigger
   propage book_authors) + `unlink_author_book`. Doctrine SECURITY DEFINER /
   search_path / REVOKE PUBLIC / GRANT staff.
3. **Frontend rétroactif** : bouton « Rattacher aux œuvres » sur la fiche
   autorité + UI de revue des candidats (titre + score + confirmation par lot).
4. **Frontend préventif** : sélecteur d'autorité (recherche `authors`) par ligne
   contributeur dans le formulaire livre, posant `author_id` explicitement.
5. **Dogfooding** : relier LENOIR (10120) à ses 5 livres via l'outil (Q6).
6. **Track D (ultérieur)** : désambiguïsation par identifiants ; remplacement du
   stub `link_book_contributors_to_authors` au publish d'un livre.

---

*Doctrine : migrations via fichier horodaté → push → Woodpecker (jamais MCP).
Cette spec ne committe aucun code ; elle cadre le travail.*
