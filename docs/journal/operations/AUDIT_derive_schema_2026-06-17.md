# AUDIT — dérive schéma migrations ↔ live (lecture seule)

> Date : 2026-06-17. Réf : Audit 360° P1-3 (« dérive de schéma : ~150 fonctions
> créées hors migrations ; un `db reset` ne reconstruit pas la base »).
> **Audit lecture seule — aucune modification appliquée.** Objet : savoir
> précisément par où reprendre le chantier baseline « le jour où ».

## A. Niveau versions/fichiers — PARITÉ OK (bonne nouvelle)

Sur le **clone canonique WSL** (`~/anarbib`) :

- **434 fichiers** de migration (`supabase/migrations/*.sql`, hors `_TEMPLATE`).
- **434 versions** dans `supabase_migrations.schema_migrations`.
- Mêmes `min` (`20260510183000`) et `max` (`20260617202358`).

→ **Aucune dérive de version sur le clone canonique.** La « dérive 430 vs ~393 »
du rapport d'audit était un **artefact** : il comparait le **clone Windows
périmé** (~393 fichiers, J-2) à la base live (430 trackées). Le clone WSL, lui,
est à parité. L'historique de fichiers est complet.

## B. Niveau objets — DÉRIVE RÉELLE, non chiffrable en lecture seule

Le vrai problème de reconstructibilité est **indépendant du compte de versions** :
des objets créés **hors migration** (via MCP / éditeur SQL, qui ne touchent pas
`schema_migrations`) existent en live mais ne seraient **pas** recréés par un
`db reset` (rejeu des 434 fichiers sur une base vide).

- ~**669** noms de fonctions distincts en live (public 509, api 129, ingest 31,
  private 4) vs ~**441** noms « créés-en-migration » détectés par grep
  (heuristique : **plancher**, rate les `CREATE` multi-lignes ou via `EXECUTE`).
- L'écart brut (~228) **surestime largement** la dérie : sur 15 fonctions
  échantillonnées, **11 sont bien créées en migration**. Mon grep a trop de faux
  positifs/négatifs → **il ne peut pas chiffrer la dérive de façon fiable**.

**Objets orphelins CONFIRMÉS** (en live, dans AUCUNE migration) :

| Objet | Type | Statut |
|---|---|---|
| `mv_books_catalog_list_v1` | materialized view | **ABSENT des migrations** |
| `catalog_list_anon_v1` | view (OPAC public) | **ABSENT des migrations** |
| `search_catalog_v1`, `get_due_date_after_renewal`, `refresh_mv_books_catalog_list_v1` | functions | « mentionnées seulement » → à confirmer (probables orphelines) |

→ La dérive est **centrée sur la couche catalogue/découverte (OPAC)** — cohérent
avec la note mémoire « la MV catalogue vit hors migration ». À l'inverse,
`v_book_authors_canonical`, `v_active_memberships`, et la grande majorité des
fonctions métier SONT bien en migration.

## C. Par où recommencer (le chantier baseline)

**Le chiffrage exact n'est PAS le préalable** — l'outil autoritatif est
`supabase db diff` (CLI + creds, ce que fait la CI), pas un grep. Plan :

1. **Vérité terrain** : depuis une session WSL avec `supabase` connecté (linked),
   ```
   supabase db diff --linked --schema public,api,ingest,private,storage
   ```
   → liste EXACTE des objets en live non reproduits par les migrations. Remplace
   l'heuristique de cet audit par du sûr.
2. **Baseline / squash** : `supabase db dump` du schéma live → **une migration
   baseline** qui supersede l'historique (ou baseline + forward). Après ça, un
   `db reset`/rejeu reproduit fidèlement la live → la dérive est dissoute.
   (L'audit note « baseline du 11/06 existe partiellement » → vérifier/étendre.)
3. **Filet bas-coût intermédiaire** (si on ne fait pas le squash tout de suite) :
   capturer au moins les orphelins confirmés (`mv_books_catalog_list_v1`,
   `catalog_list_anon_v1`, + ce que `db diff` remonte) dans une **nouvelle
   migration idempotente**, pour qu'ils soient au moins versionnés.

## ⚠️ Risque — à faire à tête reposée

Remplacer/squasher l'historique de migrations est l'**opération risquée** du
chantier (peut casser la chaîne). À faire : sur une **branche Supabase de dev**
d'abord, avec un `db reset` de validation AVANT de toucher `main`, plan de
rollback clair. **Jamais en fin de session / dans la précipitation.**

## MISE À JOUR (même soir) — racine confirmée par un `db reset`

Un `supabase db reset` **local** (stack Docker, **prod intacte**) échoue sur la
**1re migration** (`20260510183000`) : `relation "public.book_holdings" does not
exist`. Vérifié : **aucune migration ne crée** `book_holdings`, `books`,
`profiles`, `libraries`, `exemplares` — toute la **base socle préexiste à
l'historique** (qui démarre le 2026-05-10). La dérive n'est donc pas « ~150
fonctions » mais **le socle entier non capturé** (tables fondatrices + MV/vues
catalogue + fonctions hors-migration).

**Correctif au plan ci-dessus** :
- `supabase db diff` et `db reset` **ne peuvent PAS tourner** tant que la baseline
  n'existe pas (ils reconstruisent depuis les migrations → même mur). Ne pas
  s'appuyer dessus. (L'étape ①/`db diff` ci-dessus est donc inopérante en l'état.)
- Artefact à produire = **`supabase db dump --linked -f docs/db/schema_live_*.sql`**
  : il lit la live directement (ignore les migrations) → **marche**, et c'est la
  matière de la baseline.
- Reprise : transformer ce dump en **migration baseline placée AVANT
  `20260510183000`** (ou squash de tout l'historique en une baseline). Ensuite
  `db reset` rejoue : socle → migrations → live reproductible.

---
*Audit produit en lecture seule le 17/06/2026 (session « Audit 360 — correctifs P0 »).*
