# CADRAGE — Fusion d'autorités (dédoublonnage propre)

> **Date** : 2026-06-19 · **Statut** : cadrage (à valider, puis implémenter).
> **Origine** : incident de catalogage réel (doublon `Fabio LUZ` / `Fábio LUZ`). La fusion
> manuelle a été faite en SQL ce jour (voir §6) ; ce document cadre l'outillage pour ne plus
> jamais repasser par du SQL à la main.
> **Session** : Doublons d'autorité & i18n erreurs catalogue.

## 0. En une phrase

Un·e catalogueur·euse choisit une autorité doublon et **« Fusionner dans… »** une autorité cible :
toutes les références (œuvres, contributeurs, brouillons, alias) **basculent** vers la cible, le
doublon est **supprimé**, avec **snapshot d'audit** restaurable — en une action, sans SQL.

## 1. Le problème observé

Le panneau autorités sait **ajouter** un auteur à une œuvre, mais **pas remplacer/fusionner** deux
fiches. Conséquence vécue :

1. Deux fiches pour la même personne (`10165 = Fábio LUZ` correcte ; `10829 = Fabio LUZ` doublon).
2. La catalogueuse complète la bonne fiche et **rattache l'œuvre** à `10165` via les contributeurs.
   Le trigger `fn_sync_book_authors_from_contributor` ajoute bien `10165` dans `book_authors`…
3. …mais **ne retire pas** le lien hérité du doublon : la ligne `book_authors (livre, 10829)` est
   un **« fantôme »** sans contributeur correspondant → aucun trigger ne la voit.
4. `discard_author` refuse la suppression tant qu'**une** ligne `book_authors` subsiste
   (`book_authors_author_id_fkey` en `ON DELETE RESTRICT` + garde explicite). **Blocage total.**
5. Effet de bord : ce fantôme fait apparaître le doublon comme **2ᵉ auteur dans l'OPAC**.

Diagnostic : il manque une **opération de fusion**. « Ajouter à A » n'a aucune raison de « retirer
de B » — ce sont deux faits indépendants. Tant qu'aucun outil ne réaffecte explicitement les
références de B vers A, chaque doublon = intervention SQL manuelle.

## 2. Portée — toutes les références à `public.authors(id)`

Six FK pointent sur `authors(id)` (vérifié en prod le 19/06). La fusion **doit** toutes les traiter :

| Table / colonne | `ON DELETE` actuel | Traitement à la fusion |
|---|---|---|
| `book_authors.author_id` | RESTRICT | réaffecter vers la cible ; **si collision** (la cible couvre déjà `(book_id, role, ord)`) → supprimer la ligne du doublon |
| `book_contributors.author_id` | SET NULL | réaffecter (pas de contrainte par auteur ; unique sur `(book_id, position)` non touchée) |
| `book_draft_contributors.author_id` | SET NULL | réaffecter |
| `author_name_aliases.author_id` | CASCADE | réaffecter, **dédoublonner par `alias_norm`** ; ajouter le `preferred_name` du doublon comme alias de la cible s'il n'y est pas |
| `author_translations.author_id` | CASCADE | réaffecter, dédoublonner par `(author_id, lang)` (unique) |
| `author_drafts.published_author_id` | SET NULL | repointer vers la cible ; les brouillons **ouverts** (`status='draft'`) du doublon → corbeille (`cancelled`) pour ne pas réécraser la cible |

> ⚠️ Tout nouvel objet référençant `authors(id)` devra être ajouté ici **et** dans la RPC.
> Idée d'auto-garde : un test SQL qui échoue si une FK vers `authors` n'est pas couverte par la RPC.

## 3. Proposition backend — `api.fn_merge_authors(p_from, p_into)`

- **Schéma `api`**, `SECURITY DEFINER`, `SET search_path`, `REVOKE … FROM public/anon`,
  `GRANT EXECUTE TO authenticated` (doctrine `_TEMPLATE.sql`). Appel front via `apiRpc`
  (cf. `[[frontend-api-rpc-apirpc-not-supabase-rpc]]`), pas `supabase.rpc`.
- **Garde RBAC** identique à `discard_author` : `librarian`/`coordenador` actif.
- **Garde-fous logiques** : `p_from <> p_into` ; les deux existent ; refus si l'un est introuvable.
- **Snapshot d'audit avant suppression** : ligne complète du doublon (`to_jsonb`) +
  `merged_into` dans `catalog_audit_log.details` (doctrine snapshot row-level, cf.
  `20260604190944_catalog_discard_full_snapshot.sql`). Idéalement, snapshot **aussi des lignes
  filles** réaffectées (book_authors/contributors/aliases) pour une vraie réversibilité.
- **Transaction unique** : réaffectations + dédoublonnage + delete, tout ou rien.
- **Refresh catalogue** : déclencher `refresh_mv_books_catalog_list_v1()` pour purger l'OPAC.
- **`hint` machine** sur chaque `RAISE EXCEPTION`, **préfixé `error.`** (sinon non localisé, cf.
  [[localizeerror-hint-error-prefix]]) — p. ex. `error.catalog.merge.*`.

Esquisse (non définitive) :

```sql
-- book_authors : réaffecter sans collision, sinon supprimer la ligne redondante
update public.book_authors ba set author_id = p_into
  where ba.author_id = p_from
    and not exists (select 1 from public.book_authors x
                    where x.book_id=ba.book_id and x.author_id=p_into
                      and x.role=ba.role and x.ord=ba.ord);
delete from public.book_authors where author_id = p_from;  -- restantes = collisions déjà couvertes
-- … idem contributeurs (réaffecter), aliases/translations (réaffecter + dédoublonner),
-- author_drafts (repointer publiés, corbeille les ouverts), puis delete authors where id=p_from.
```

## 4. Proposition UI — bouton « Fusionner dans… »

- Dans `CatalogPanel` (vue **Autorités**), action par ligne « Fusionner dans… » qui ouvre un
  sélecteur d'autorité cible (réutiliser l'autocomplete d'autorités existant).
- **Confirmation explicite** récapitulant : « N œuvres, M contributeurs, K alias seront rattachés
  à *cible* ; *doublon* sera supprimé. Action irréversible. »
- Message de succès : « *doublon* fusionné dans *cible*. »
- Garde anti-bêtise : interdire de fusionner une fiche dans elle-même ; avertir si les dates
  vitales divergent (possible faux doublon — ex. `Fábio Luz FILHO` ≠ `Fábio LUZ`).

## 5. i18n des erreurs `discard` — ✅ FAIT (19/06)

Les `RAISE EXCEPTION` des RPC `discard_*` posaient des `hint` machine `catalog_discard_*` (sans
préfixe `error.`) → `src/lib/localizeError.js` (Cas 1 : `hint.startsWith('error.')`) ne les
traduisait pas ; pour un `P0001` (message délibéré) le helper retombait au Cas 3 et affichait le
`message` **brut pt-BR**.

Corrigé par la migration `20260619160150_catalog_discard_i18n_hints.sql` : les 3 RPC re-créées à
l'identique avec `hint = 'error.catalog.discard.*'`, + 7 clés `error.catalog.discard.*` ×10 locales
(formulées sans noms de rôle genrés). **Zéro changement front** — `localizeError` traduit le hint.
**À reproduire** pour `fn_merge_authors` : poser des `hint` `error.catalog.merge.*` dès l'écriture.

## 6. Le correctif manuel déjà appliqué (référence)

Fusion `10829 → 10165` exécutée en prod (transaction, audit-loggée) : suppression de la ligne
`book_authors` fantôme (livre 254), suppression de l'alias redondant, repointage du brouillon
publié `#65`, mise en corbeille du brouillon ouvert `#66`, suppression du doublon, refresh des MV.
Vérifié : OPAC ne résout plus que « LUZ, Fábio ».

## 7. Tests d'acceptation (à écrire avec la RPC)

- Fusion nominale : toutes les références basculent, doublon supprimé, snapshot présent.
- Collision `book_authors` : la cible couvre déjà l'œuvre → pas d'erreur, ligne du doublon retirée.
- Alias/translations en double → dédoublonnés, pas de violation d'unicité.
- Brouillon ouvert du doublon → `cancelled`, ne peut plus réécraser la cible.
- RBAC : un compte non staff est refusé (`hint` mappé).
- `p_from = p_into` → refus propre.
