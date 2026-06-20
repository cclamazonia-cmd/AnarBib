# CADRAGE — Modèle Œuvre / Éditions (FRBR-léger)  [P4 de l'audit catalogage]

> **Date** : 2026-06-20 · **Statut** : cadrage (à valider, puis coder à la suite).
> **Origine** : audit catalogage 2026-06-20, manque **P4**. Les éditions multiples d'un classique
> (ex. González Prada « Anarquía » 1940/2010/2020) sont des notices indépendantes que rien ne relie
> ni ne distingue → confondues avec des doublons. Les correctifs P1a/P1b (dédoublonnage conscient de
> l'ISBN + drapeau `book_not_duplicate`) sont des **rustines pairwise** ; l'**Œuvre** est la réponse
> structurelle.
> **Session** : Doublons d'autorité & i18n erreurs catalogue.

## 0. En une phrase

Introduire une couche **Œuvre** (le texte intellectuel) au-dessus des notices **`books`** (les
*manifestations* = éditions), pour **regrouper les éditions d'un même classique**, les distinguer
des vrais doublons, et afficher « autres éditions » à l'OPAC.

## 1. Besoin

`books` est déjà une **manifestation** : `edicao`, `ano`, `editora`, `isbn`, `paginas`,
`local_publicacao`, `cover_object_path`… sont propres à une édition. Manque la maille **Œuvre**
(titre uniforme + auteur·rice principal·e) qui rassemble ces éditions. Conséquences actuelles :
- dédoublonnage qui confond éditions et doublons (corrigé partiellement par P1a/P1b) ;
- impossible d'afficher « 3 éditions de cette œuvre » à l'OPAC ;
- pas de point d'ancrage pour le titre uniforme / l'autorité d'œuvre.

**Volumétrie (prod 20/06)** : 2675 notices ; **153 œuvres multi-éditions** (≈344 notices, jusqu'à
6 éditions/œuvre) ; le reste mono-édition.

## 2. Modèle — FRBR-léger (Œuvre → Manifestation)

FRBR complet = Œuvre → Expression (langue/version) → Manifestation (édition) → Item (exemplaire).
AnarBib a déjà **Manifestation** (`books`) et **Item** (`exemplares`/`book_holdings`). On ajoute
**Œuvre**. L'**Expression** (traductions = versions linguistiques) est **reportée en v2** : en v1
une œuvre regroupe toutes ses éditions, traductions comprises (`idioma` reste sur la notice).

**Option retenue — table `works` + `books.work_id`** (vs. simple `work_group_id` auto-référent) :
porte un **titre uniforme** + un **lien d'autorité d'œuvre** (auteur·rice principal·e), permet une
page œuvre OPAC et des requêtes propres « éditions de l'œuvre X ». Plus structurant qu'un simple
groupe, justifié par le fonds (nombreux classiques réédités).

> ⚠️ **Relation avec P1b** : une fois deux notices rattachées à la **même œuvre**, elles ne sont
> plus jamais des doublons → l'Œuvre **subsume** le drapeau `book_not_duplicate` pour les cas
> groupés. On garde `book_not_duplicate` comme filet pour les paires non encore rattachées à une œuvre.

## 3. Schéma proposé (esquisse)

```sql
create table public.works (
  id              bigint generated always as identity primary key,
  uniform_title   text not null,            -- titre uniforme (forme retenue)
  sort_title      text,                     -- pour tri (article initial écarté)
  primary_author_id bigint references public.authors(id) on delete set null,
  notes           text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.books add column work_id bigint references public.works(id) on delete set null;
create index on public.books(work_id);
-- RLS works : lecture publique (OPAC) / écriture staff catalogage. RLS books inchangée.
```

- `works` est une **autorité d'œuvre** légère ; `uniform_title` + `primary_author_id` = sa clé
  intellectuelle. Les champs édition (ano/editora/isbn/edicao/cover…) **restent sur `books`**.
- `work_id` **nullable** : une notice peut rester sans œuvre (mono-édition non encore groupée).

## 4. Backfill heuristique (conservateur)

- Créer **une œuvre par groupe** (titre normalisé `fn_normalize_name(titulo)` + auteur·rice
  principal·e `book_authors role=autor` min(ord)) **ayant ≥ 2 notices** → ~153 œuvres, 344 notices
  rattachées. `uniform_title` = titre de l'édition la plus complète/ancienne (à définir : ex. la
  plus ancienne `ano`, ou la mieux remplie).
- **Mono-éditions laissées `work_id = NULL`** en v1 (création paresseuse : œuvre créée quand une 2ᵉ
  édition apparaît, ou à la demande). Évite 2300+ œuvres triviales d'emblée.
- Idempotent ; groupes ambigus (auteur·rice nulle, homonymie) **exclus** → rattachement manuel.

## 5. Intégrations OBLIGATOIRES (sinon régressions)

- **merge_author** ⚠️ : `works.primary_author_id` devient une **7ᵉ FK vers `authors`**. `merge_author`
  DOIT repointer `works.primary_author_id` (sinon fusion d'auteur·rice casse/oriente mal des œuvres).
  Idem `discard_author` (garde) — voir [[fusion-autorites-pas-doutil-merge]].
- **merge_book** : gérer `work_id` du perdant (le gagnant garde le sien ; si divergence, conserver
  celui du canonique). Pas de FK cassée (`book_id` reste).
- **Dédoublonnage** (`suggest_book_duplicates`/`suggest_draft_duplicates`) : exclure les notices de
  **même `work_id`** (= éditions, jamais doublons) — complète P1a/P1b.
- **OPAC** : `BookPage` → section « Autres éditions de cette œuvre » (notices de même `work_id`).
- **MV catalogue** : exposer `work_id` (regroupement / facette « œuvre »).

## 6. RPC + UI (v1)

Backend (SECURITY DEFINER, RLS, search_path, grants, hints `error.catalog.work.*` — cf.
[[localizeerror-hint-error-prefix]]) :
- `assign_book_to_work(p_book_id, p_work_id)` / `detach_book_from_work(p_book_id)`.
- `create_work_from_book(p_book_id)` → crée l'œuvre depuis la notice + l'y rattache.
- `group_books_as_editions(p_book_ids bigint[])` → crée/assigne une œuvre commune (remplace
  l'usage « Pas un doublon » par « ce sont des éditions »).

Front (onglet Documento + CatalogPanel) :
- Bloc « Œuvre » dans `BookDraftForm` : œuvre rattachée (titre uniforme + N éditions) + actions
  rattacher / détacher / créer.
- Dans la liste de doublons (`BookDraftForm`, `DuplicateCompareModal`) : à côté de « Fusionner »
  et « Pas un doublon », ajouter **« Éditions de la même œuvre »** → `group_books_as_editions`.
- OPAC : « Autres éditions » sur la fiche.

## 7. Phasage

- **v1 (ce chantier)** : table `works` + `books.work_id` + backfill multi-éditions + RPC
  assign/detach/create/group + intégration dédoublonnage + **mise à jour merge_author/merge_book** +
  bloc UI catalogage. i18n des libellés/erreurs ×10.
- **v2** : section OPAC « autres éditions » + page œuvre ; Expression (langue) ; titre uniforme
  comme autorité (alias d'œuvre) ; auto-suggestion de regroupement ; facette « œuvre » au catalogue.

## 8. Tests d'acceptation (v1)

- Backfill : les 153 groupes deviennent 153 œuvres ; 344 notices rattachées ; mono-éditions intactes.
- Dédoublonnage : deux notices de même `work_id` ne se signalent plus jamais.
- `merge_author` : fusionner deux autorités repointe `works.primary_author_id` (aucune œuvre orpheline).
- `merge_book` : fusionner deux éditions conserve un `work_id` cohérent.
- RLS : OPAC lit les œuvres ; seul·e le staff écrit.
- Rattacher/détacher/grouper : effets attendus, idempotents, gardés staff.

## 9. Garde-fous doctrine
Migration horodatée à la seconde (UTC réel) ; `works` avec RLS + GRANT (doctrine `_TEMPLATE`) ;
RPC SECURITY DEFINER + `set search_path` + `REVOKE`/`GRANT` ; backfill idempotent ; **ne pas oublier
la 7ᵉ FK dans merge_author/discard_author**. Cf. audit `AUDIT_catalogacao_tables_vues_2026-06-20.md`
et mémoire [[catalog-dedup-covers-audit]].
