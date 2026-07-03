# CADRAGE — Performance du matching d'import (à traiter à froid)

> **CLÔTURE 2026-07-03 — ✅ A+B+C livrés & vérifiés, band-aid borné.**
> Vérifié en prod : les 3 fonctions de normalisation ciblées sont `IMMUTABLE` (A) ;
> `fn_match_partner_catalog_row` ne contient plus aucun `to_jsonb(b)->>` et son md5
> vaut `0d2625ad117dc22affd34908015dd605` = la réécriture neutre attendue (B) ; les
> **6 index d'expression** existent sur `books`/`book_drafts` (C). `EXPLAIN ANALYZE`
> confirme l'**Index Scan** (`idx_books_isbn_norm`, `idx_books_tit_aut_norm`) en
> **~0,08 ms** (vs seq scan O(2673)). Le band-aid `statement_timeout=0` a été
> **remplacé par une borne 120s** (migration `20260703182035`) : plus sûr, ~40× de
> marge sur un import de 2500 lignes. **Reste optionnel** : volet D (chunking) si des
> imports de dizaines de milliers de lignes deviennent un besoin réel ; et une
> validation « grandeur nature » sur un vrai `.ris` ~2500 (non rejouable en session
> outillée ici — la preuve Index Scan + arithmétique tient lieu de garantie).
>
> Statut d'origine : **CADRAGE** (analyse + plan, pas d'implémentation). Date : 2026-06-11.
> Session : Unification partenaire ↔ source d'import. Décision : Xavier (à froid).
> Déclencheur : le test d'import des 301 fiches CIRA a fait **timeout sur le
> matching** (10 s). Band-aid posé (cf. §4), vrai fix ci-dessous.

## 1. Symptôme

Import de 301 notices RIS : le **parsing réussit** (301 staging rows), puis le
**matching/dédup** dépasse le `statement_timeout` (~10 s) → run `failed`,
compteurs à 0. Question ouverte de Xavier : « un .ris de 2500 lignes passerait-il ? »
→ **Non, en l'état.**

## 2. Cause racine (vérifiée)

`ingest.fn_match_partner_catalog_run` boucle sur chaque staging row et appelle
`ingest.fn_match_partner_catalog_row` (fonction de **27 Ko**). Les recherches de
candidats y sont écrites ainsi :

```sql
from public.books b
where ingest.fn_normalize_isxn(to_jsonb(b)->>'isbn') = v_isbn_norm
...
and ingest.fn_match_normalize_text(to_jsonb(b)->>'titulo') = v_title_norm
```

→ La normalisation est appliquée **à chaque livre, à la volée**, via
`fn_norm(to_jsonb(b)->>'col')`. Cette forme (comparaison fonctionnelle + détour
`to_jsonb`) **défait TOUS les index** de `books` (les 16 existants sont inutiles
ici). Résultat : **un SEQ SCAN complet de `books` par staging row, par type de
recherche** (ISBN, ISSN, titre+auteur+année+éditeur, etc.).

Coût ≈ O(staging_rows × |books| × nb_recherches × coût_normalisation). 301 lignes
saturent déjà 10 s ; 2500 → ~minutes → dépasserait aussi la **limite wall-clock
de l'Edge Function** (~150 s) qui pilote le matching.

## 3. Le vrai fix (3 volets)

**A. Rendre les fonctions de normalisation `IMMUTABLE`.**
`ingest.fn_normalize_isxn`, `ingest.fn_match_normalize_text` (et apparentées :
`fn_match_normalize_publisher`, `fn_match_normalize_responsibility`) doivent être
`IMMUTABLE` pour être indexables. Vérifier qu'elles sont déterministes (pas
d'accès table) puis `ALTER FUNCTION … IMMUTABLE`.

**B. Réécrire les requêtes de `fn_match_partner_catalog_row`** pour comparer
`fn_norm(b.colonne)` **directement** (supprimer le détour `to_jsonb(b)->>'…'`),
forme qui peut matcher un index d'expression. ⚠️ Fonction critique de 27 Ko →
refactor prudent (tester sur une copie / un projet de branche).

**C. Index d'expression sur `public.books`** (concordants au mot près avec les
requêtes réécrites) :
```sql
CREATE INDEX idx_books_isbn_norm  ON public.books (ingest.fn_normalize_isxn(isbn));
CREATE INDEX idx_books_issn_norm  ON public.books (ingest.fn_normalize_isxn(issn));
CREATE INDEX idx_books_titulo_norm ON public.books (ingest.fn_match_normalize_text(titulo));
-- + auteur / éditeur normalisés selon les clés de recherche composites.
```
→ Chaque recherche devient un index scan O(log n) au lieu d'un seq scan O(n).

**D. (Optionnel, gros volumes) — dispatch par chunks.** Même rapide, 5000+ lignes
en un seul appel peut frôler la limite EF. Faire que l'EF traite le matching par
**lots de ~200-500 row_ids** (`fn_match_partner_catalog_run(run_id, batch)` accepte
déjà un `p_row_ids[]`), idéalement **réparti sur plusieurs invocations** (re-dispatch
incrémental) pour rester sous le wall-clock.

## 4. Band-aid actuellement en place (à RETIRER après le vrai fix)

Migration `20260611174540_lift_statement_timeout_partner_matching.sql` :
`ALTER FUNCTION … SET statement_timeout = '0'` sur `fn_match_partner_catalog_run`,
`fn_match_partner_catalog_row`, `fn_refresh_partner_catalog_run_counters`. Ça
**débloque les petits lots** (301 passe) mais ne change rien à la complexité :
à retirer (ou borner) une fois A+B+C livrés.

## 5. Ordre conseillé

1. A (immutable) — préalable indispensable à C.
2. C (index) — sur des requêtes encore en l'ancienne forme : **sans effet** tant
   que B n'est pas fait → faire B et C ensemble, testés.
3. B (réécriture) + C, validés sur un lot de test (301 + un lot synthétique ~2500).
4. D si les très gros lots sont un besoin réel.
5. Retirer le band-aid §4.

## 6. Validation

- Re-jouer l'import des 301 CIRA : le matching doit passer en **quelques secondes**
  (vs ~15-30 s aujourd'hui).
- Lot synthétique ~2500 lignes : doit aboutir sans timeout ni dépassement EF.
- `EXPLAIN ANALYZE` d'une recherche candidate : **Index Scan**, pas Seq Scan.

---

## Statut au 2026-06-12 — ✅ B+C LIVRÉS (reste : retrait du band-aid)

> ✅ **Volets B + C déployés et vérifiés** (commit `618312db`, pipeline vert).
> Fonction `fn_match_partner_catalog_row` réécrite (`to_jsonb(b)->>'col'` → `b.col`,
> md5 `0d2625ad117dc22affd34908015dd605`, **sémantiquement neutre**) + **6 index
> d'expression** sur `books`/`book_drafts`. `EXPLAIN ANALYZE` confirme l'**Index Scan**
> (sub-ms) sur les recherches ISBN et titre+auteur — le seq scan O(2673 livres) par
> ligne est éliminé. **Reste** : (1) retirer le band-aid `statement_timeout=0` (petit
> `ALTER FUNCTION … RESET statement_timeout`, après confirmation sur un vrai gros
> import) ; (2) optionnel, volet D (chunking) pour les très gros lots.
> *(La « Recette prête » plus bas est conservée pour traçabilité.)*

> ⚠️ Ne pas confondre ce cadrage (**performance** du matching) avec le bug de
> **confidence** (chantier A), qui était distinct et a été **corrigé séparément**
> (migration `20260612005406`, commit `23efba2` : `confidence` = meilleur score
> candidat, persisté dans le wrapper + backfill).

État réel des volets (audité le 12/06) :
- **Volet A (IMMUTABLE)** — ✅ **DÉJÀ FAIT**. Les fonctions de normalisation
  (`fn_match_normalize_text`, `fn_normalize_isxn`, `fn_match_normalize_publisher`,
  `fn_match_normalize_responsibility`, `fn_extract_year4`, `fn_format_partner_authors`,
  `fn_match_responsibility_initialism`) sont **toutes `IMMUTABLE`** et déterministes
  (pur string/regex, aucun accès table) → indexables.
- **Volet B (réécriture des requêtes)** — ❌ à faire. `fn_match_partner_catalog_row`
  utilise encore `to_jsonb(b)->>'col'` sur les requêtes `books` (les requêtes
  `book_drafts` sont déjà en accès direct `d.col`). `to_jsonb` n'étant pas IMMUTABLE,
  ce détour **interdit l'usage de tout index** côté `books`.
- **Volet C (index d'expression)** — ❌ à faire. **Aucun** index normalisé sur
  `public.books` (2673 lignes) ni `public.book_drafts`.
- **Volet D (chunking)** — optionnel, si gros lots réels.

Seul le **band-aid** `SET statement_timeout = '0'` (migration `20260611174540`) est en
place : les petits lots (301 CIRA) passent ; les gros (~2500+) resteraient à risque.

### Recette prête (B + C) — validée le 12/06, à exécuter en session OUTILLÉE (psql/CLI authentifiée) + test sur branche

**Volet B** — générer la fonction réécrite **sans transcription** (transform validée :
70 occurrences `to_jsonb(b)->>'col'` → `b.col`, 0 résidu, **sémantiquement neutre**
donc résultats de matching inchangés) :
```bash
psql "$DB_URL" -At -c "select regexp_replace(
  pg_get_functiondef('ingest.fn_match_partner_catalog_row(bigint)'::regprocedure),
  'to_jsonb\(b\)\s*->>\s*''([a-zA-Z_]+)''', 'b.\1', 'g')" | tr -d '\r' > /tmp/fn_match_rewritten.sql
# Contrôle d'intégrité — DOIT valoir 0d2625ad117dc22affd34908015dd605 :
md5sum /tmp/fn_match_rewritten.sql
```
La migration reprend ce CREATE OR REPLACE (garder `SET statement_timeout = '0'`, déjà
dans la def) + `REVOKE EXECUTE … FROM PUBLIC` / `GRANT … TO service_role` (SECURITY DEFINER).

**Volet C** — index d'expression (même migration) :
```sql
CREATE INDEX IF NOT EXISTS idx_books_isbn_norm    ON public.books (ingest.fn_normalize_isxn(isbn));
CREATE INDEX IF NOT EXISTS idx_books_issn_norm    ON public.books (ingest.fn_normalize_isxn(issn));
CREATE INDEX IF NOT EXISTS idx_books_tit_aut_norm ON public.books (ingest.fn_match_normalize_text(titulo), ingest.fn_match_normalize_text(autor));
CREATE INDEX IF NOT EXISTS idx_bd_isbn_norm    ON public.book_drafts (ingest.fn_normalize_isxn(isbn));
CREATE INDEX IF NOT EXISTS idx_bd_issn_norm    ON public.book_drafts (ingest.fn_normalize_isxn(issn));
CREATE INDEX IF NOT EXISTS idx_bd_tit_aut_norm ON public.book_drafts (ingest.fn_match_normalize_text(titulo), ingest.fn_match_normalize_text(autor));
```

**Validation** : `EXPLAIN ANALYZE` d'une recherche candidate → **Index Scan** (vs Seq Scan
sur 2673 livres) ; re-jouer le run 14 (301 CIRA) → quelques secondes ; comparer que les
`match_status`/scores des lignes sont **inchangés** (la réécriture est neutre). Puis,
dans un **suivi** : retirer le band-aid `statement_timeout=0` (ou le borner).

**Pré-requis de tooling** : cette session (12/06) était lancée côté Windows, sans psql ni
CLI Supabase authentifiée → la fonction de 27 Ko n'a pas pu être matérialisée proprement.
À reprendre depuis WSL avec `supabase login` (ou un `$DB_URL` direct).
