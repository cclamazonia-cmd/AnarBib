# Recherche : les index trigramme empruntés — B33, 27/09/2026

*Item B33 du backlog v34 : « Recherche : des index trigramme que la forme des requêtes empêche d'emprunter ». Constaté pendant B10 (audit `AUDIT_performance_B10_2026-09-27.md`, §5, grappes 2 et 4, « Surprises » 2 et 8). Trois critères : `search_catalog_v1` emprunte ses index trigramme (plan à l'appui) ; la publication d'une notice ne parcourt plus `publishers` ; les index restés sans lecteur sont retirés, raison écrite.*

Migrations : `20260927193314_b33_les_recherches_empruntent_leurs_index_trigramme.sql` (réécritures et index alignés), `20260927193315_b33_index_restes_sans_lecteur.sql` (retraits). Garde : `tests/sql/recherche_index_trigramme_tests.sql` (8 tests).

## 1. Point de départ, relevé en production le 27/09

**Aucun des index visés n'avait servi depuis le redémarrage du 02/09** (`pg_stat_user_indexes.idx_scan = 0`) : l'index des alias, les deux index `f_normalize_search` d'`authors`, `authors_fn_normalize_name_trgm_idx`, le GIN sur `publishers.name`, `idx_authors_external_ids`, `idx_books_autor_trgm`, les deux index de `serials`, et les index trigramme des deux vues matérialisées.

**Coût des recherches** (`pg_stat_statements`, depuis le 02/09) :

| RPC | appels | moyenne | volume lu |
|---|---:|---:|---|
| `api.search_catalog_v1` (autocomplétion publique) | 40 | 177 ms | 2 634 notices, 1 503 autorités, 1 644 alias |
| `search_authors_by_name` (catalogage) | 16 | 166 ms | 1 503 autorités |
| `search_publishers_by_name` (catalogage) | 22 | 85 ms | 1 190 éditeurs |

Ces temps croissent linéairement avec le catalogue : chaque appel parcourt toute la table et calcule `f_normalize_search` ou `fn_normalize_name` sur chaque ligne — deux fonctions munies d'un `SET search_path`, donc jamais insérées en ligne : chaque appel est une requête à part entière.

**Un défaut visible en production, en plus.** Relevé du 27/09 (banque de requêtes figée, empreinte `1f647edc`) : `c++ anarquia` et `[anarquia` levaient `2201B` (« invalid regular expression ») dans l'autocomplétion publique — les jetons de la requête entraient bruts dans une expression régulière.

## 2. Deux règles de lecture, dont une qui manquait à B10

**Un `OR` n'emprunte un index que si chacune de ses branches le peut** (règle déjà écrite dans l'audit B10). `search_catalog_v1` écrivait `… % v OR … LIKE v || '%' OR EXISTS (SELECT … FROM unnest(v_tokens) … ~ …)` : la branche `EXISTS` corrélée condamnait les deux autres au parcours séquentiel.

**Derrière une policy RLS, seul un opérateur *leakproof* devient condition d'index.** C'est la règle qui manquait. PostgreSQL applique les conditions d'une requête sur une table sous RLS *après* celles des policies, sauf si l'opérateur ne peut rien divulguer (`proleakproof`). Or `textlike`, `texticlike`, `textregexeq` et `similarity_op` — `LIKE`, `ILIKE`, `~`, `%` — ne le sont pas (vérifié en production). Conséquence : **un index trigramme sur une table sous RLS ne sert que les fonctions `SECURITY DEFINER` dont le propriétaire possède la table** (il échappe aux policies). Une recherche faite par PostgREST, ou par une fonction `INVOKER`, ne l'emprunte jamais — quelle que soit la forme de son `OR`. C'est le cas de l'onglet Catalogue du catalogage (`CatalogPanel`, `ilike` sur `books`) et de `fn_peb_search_exemplares`.

## 3. Ce qui change

| Fonction | Avant | Après |
|---|---|---|
| `api.search_catalog_v1` | `OR EXISTS (… unnest(v_tokens) … ~ ('(^|\s)' \|\| tok))` ; `f_normalize_search(COALESCE(sort_name, ''))` ; jetons bruts dans l'expression régulière | un seul motif `~ '(^|\s)(t1|t2|…)'`, que gin_trgm sait servir ; `f_normalize_search(sort_name)` (l'expression de l'index) ; jetons échappés |
| `search_authors_by_name` | `similarity(np, q) >= 0.30 OR similarity(ns, q) >= 0.30` | `np % q OR ns % q`, seuil 0.3 posé dans la fonction ; index neuf sur `fn_normalize_name(sort_name)` |
| `search_publishers_by_name` | `similarity(fn_normalize_name(name), q) >= 0.30` | `fn_normalize_name(name) % q`, même seuil ; index neuf sur `fn_normalize_name(name)` |
| `fn_sync_publisher_id_on_publish` (déclencheur de `books` et `book_drafts`) | `lower(p.name) = lower(trim(NEW.editora))` sans index | index neuf sur `lower(name)` |

**Pourquoi ces réécritures ne changent pas les résultats.**
- `EXISTS (jeton t : x ~ '(^|\s)' || t)` vaut `x ~ '(^|\s)(t1|…|tn)'` dès lors que les jetons sont des littéraux : c'est le rôle de l'échappement.
- Retirer le `COALESCE` d'un `WHERE` ne change rien : `sort_name` nul donnait `''`, qui ne vérifie ni `%`, ni `LIKE q%` (q non vide), ni le motif ; et le nom préféré porte les mêmes branches dans le même `OR`.
- `%` rend `similarity(a, b) >= seuil` : `similarity_op` compare le `real` de `similarity` au seuil `double` par `>=`, exactement comme `similarity(…) >= 0.30` (opérateur `float48ge`). Le seuil est posé à 0.3 dans la fonction (`set_config(…, true)`, idiome des fonctions de dédoublonnage) : une session qui l'aurait relevé ne fait plus disparaître de candidats (T6).
- Seul changement voulu : **un jeton porteur d'un métacaractère d'expression régulière est cherché tel quel**. `c++` ou `[` levaient une erreur ; `.` valait « n'importe quel caractère », `(1936)` valait `1936`, `a|b` valait `a` ou `b`.

Corps patchés depuis leur définition **réelle** (`pg_get_functiondef`), chaque ancre trouvée une fois et une seule, jamais recopiés (DOC-MSG-1) ; le corps de `search_catalog_v1` est enregistré en CRLF, les ancres prennent sa fin de ligne. Droits comparés avant/après, `SECURITY DEFINER` et `search_path` vérifiés par la garde de sortie. Banc et production portaient le même md5 (`3dd267b9…`, `31bc0413…`, `6b7fd2e0…`).

## 4. Preuves

### 4.1 Équivalence, sur une base synthétique à l'échelle ×8

Base jetable clonée du banc : 20 000 autorités, 28 717 alias (formes relevées en production : `manual`, `canonical_*`, `catalog_seed_*`, `variant`), 3 000 éditeurs, 20 003 notices présentes dans les deux vues matérialisées. Ancienne version gardée sous un autre nom, comparaison ligne à ligne sur des requêtes tirées des données : noms, noms complets, formes de tri, prénoms, mots et débuts de titre, fautes de frappe, préfixes, variantes sans accents ou en majuscules, métacaractères.

| Cas | Requêtes | Identiques | Écarts | Erreurs avant → après |
|---|---:|---:|---|---|
| autorités (catalogage) | 100 | **100** | — | 0 → 0 |
| éditeurs (catalogage) | 80 | **80** | — | 0 → 0 |
| autocomplétion, sans compte | 259 | 249 | 7 : métacaractères (voulu) | **3 → 0** |
| autocomplétion, adhérent·e | 259 | 238 | 7 : métacaractères ; 11 : départage d'homonymes | **3 → 0** |

Les 11 derniers écarts ont **les mêmes rangs et les mêmes libellés** avant et après : seul change *quel* homonyme (plusieurs autorités « Gustav Luz » de même rang) occupe la dixième place. L'ancienne fonction trie par `rank DESC, label ASC`, sans identifiant : le départage suivait déjà l'ordre du plan.

### 4.2 Plans réels (choix naturel du planificateur, 20 000 notices)

- `search_catalog_v1` — **avant** : parcours séquentiels d'`author_name_aliases`, d'`authors` et de la vue matérialisée, la sous-requête `unnest` exécutée 28 372, 19 885 et 19 938 fois. **Après** : trois `BitmapOr` (3 parcours de l'index des alias, 6 des deux index d'`authors`, 3 de l'index des titres) ; la sous-requête de comptage ne tourne plus que sur les candidats (164, 115, 1 223).
- `search_authors_by_name` — **avant** : `Seq Scan`, 19 892 lignes écartées par filtre. **Après** : `BitmapOr` sur `authors_fn_normalize_name_trgm_idx` et `authors_sort_name_fn_normalize_name_trgm_idx`.
- `search_publishers_by_name` — **avant** : `Seq Scan`, 2 777 écartées. **Après** : `BitmapOr` sur `publishers_fn_normalize_name_trgm_idx`.

### 4.3 Chronométrage

**À méthode égale, sur la base synthétique** (ancienne version gardée à côté, mêmes requêtes) : « reclus memória », machine au repos, **2 182 → 125 ms** ; vingt requêtes tirées de la banque, machine chargée par un autre banc (charge moyenne 26), **5 820 → 334 ms** par appel. Même rapport, ×17 : le coût ne dépend plus de la taille des tables, mais du nombre de candidats.

**En production, après** (28/09, meilleur de trois appels, côté serveur) : autocomplétion **19 ms** (vingt requêtes de la banque), autorités **2,7 ms**, éditeurs **9,5 ms** (dix chacune). Les moyennes d'avant venaient de `pg_stat_statements` sur le trafic réel (177, 166 et 85 ms) : méthodes différentes, l'ordre de grandeur seul se compare.

### 4.4 La garde

`tests/sql/recherche_index_trigramme_tests.sql` coupe parcours séquentiels et parcours d'index complets (`enable_seqscan`, `enable_indexscan`, `enable_indexonlyscan`) : il ne reste que les parcours bitmap. Le compteur de la transaction (`pg_stat_get_xact_numscans`) dit alors si chaque index a servi ; l'ancienne forme retombe en parcours séquentiel, compteur inchangé — vérifié au banc avant d'écrire la suite. Elle couvre aussi : jetons à métacaractères (« c++ b33x » trouve sa notice), autorité trouvée par sa seule forme de tri, seuil tenu quand la session l'a relevé, publication qui trouve l'éditeur par son index.

**Le piège des index partiels**, rencontré deux fois. Un index partiel dont le prédicat figure dans la requête (`is_active`) peut être parcouru **en entier, sans condition** — un parcours bitmap lui aussi, compteur compris, et souvent le moins cher sur une petite table. `author_name_aliases` en porte trois : le GIN lui-même, `uq_author_name_aliases_norm_active`, `author_name_aliases_author_id_idx`.
- Au banc complet du 27/09, le planificateur préférait les deux btree partiels au GIN : arbitrage de coût légitime (à 28 000 alias, le GIN l'emportait sans réglage).
- La parade suivante — exiger du GIN moins d'entrées rendues que d'alias actifs — a tenu au banc et rougi au CI du 28/09 : parcours sans condition du GIN lui-même, 201 entrées vivantes plus 2 entrées mortes laissées par les suites précédentes. Compter des entrées ne prouve rien là où des suites ont écrit avant.

La preuve retenue : dans la transaction du test, annulée à la fin, T1 retire les index partiels de la table et recrée le GIN **sans prédicat**. Un index non partiel ne se parcourt que par une condition de la requête ; s'il sert, c'est la forme qui l'autorise. Contre-épreuve dans l'état exact laissé par les suites du CI : nouvelle forme, 3 parcours ; ancienne forme, 0 (parcours séquentiel).

### 4.5 Production, avant et après

**Déploiement.** Poussé le 27/09 au soir (`6bdd4331`), déployé le 28/09 à 11 h 46 (Paris) : l'arrêt du poste qui porte le runner avait interrompu le premier passage du CI. `20260927193314` et `20260927193315` inscrites par le CI (`created_by` nul). Forme vérifiée : quatre `~ v_motif`, plus aucun `OR EXISTS`, droits de l'autocomplétion inchangés (`=X`, `anon=X`, `authenticated=X`), `%` dans les deux recherches du catalogage, trois index neufs valides, les cinq retirés absents.

**Empreintes des résultats**, banque figée de 159 + 74 + 49 requêtes tirées des vraies données (`1f647edc`), relevées le 27/09 à 19 h 55 UTC puis le 28/09 après déploiement :

| Recherche | Identiques | Écarts |
|---|---:|---|
| éditeurs (personnel) | **49/49** | — |
| autorités (personnel) | 71/74 | 3, tous dus à C9 (voir ci-dessous) |
| autocomplétion, sans compte | 154/159 | 4 voulus (métacaractères) ; 1 dû à C9 |
| autocomplétion, adhérent·e | 154/159 | idem |

Écarts voulus : `c++ anarquia` et `[anarquia` levaient `2201B` et rendent des résultats ; `anarquia?` et `Kropotkin (Piotr)` sont cherchés tels quels. Les quatre autres (« Costa », « Antonio Gutiérrez D. Org. », « Sacchetti », « Bivar, Antonio ») viennent des **données** : la migration C9 d'une autre session, déployée à 20 h 06 UTC — après le relevé d'avant — a scindé les fiches à plusieurs personnes (10 autorités créées, 21 modifiées). « Sacchetti » ne rend plus l'ancienne fiche collective 11420 (« Giorgio Sacchetti, Augusto Gayubas, … »), scindée ; les résultats des trois autres contiennent des fiches créées ou modifiées par C9 (11359, 11567).

**Index empruntés depuis le déploiement** (tous à 0 depuis le 02/09) : `authors_preferred_name_norm_trgm_idx` et `authors_sort_name_norm_trgm_idx` 945 parcours chacun, titres des deux vues matérialisées 474 et 471, `authors_fn_normalize_name_trgm_idx` et `authors_sort_name_fn_normalize_name_trgm_idx` 154, `publishers_fn_normalize_name_trgm_idx` 98.

**Plans relevés en production.** La recherche du déclencheur de publication passe par `publishers_lower_name_idx` (`Index Scan`, `lower(name) = 'boitempo'`). La branche des alias reste en lecture séquentielle (1 644 lignes, coût 56 : le moins cher à cette taille) ; le GIN des alias prendra le relais quand la table grossira, comme à 28 000 alias au banc.

**Le CI rouge du 28/09.** `sql-tests` a rougi sur `6bdd4331` : T1 exigeait de l'index des alias moins d'entrées rendues que d'alias actifs, et le CI en a compté 203 pour 201 — un parcours sans condition de l'index partiel, plus deux entrées mortes laissées par les suites précédentes. Reproduit à l'identique au banc en rejouant la séquence complète du CI ; T1 recrée désormais le GIN sans prédicat dans sa transaction (§4.4). La production n'était pas en cause : le déploiement ne dépend que du job `app`.

## 5. Index retirés, raison écrite

| Index | Table | Pourquoi il ne pouvait servir |
|---|---|---|
| `idx_publishers_name_trgm` | `publishers` | GIN sur le nom **brut** ; ses deux lecteurs possibles écrivent `fn_normalize_name(name)` et `lower(name)`, désormais indexées. |
| `idx_authors_external_ids` | `authors` | GIN `jsonb_ops`, posé en juin pour « chercher une autorité par MBID » — jamais câblé. GIN ne sert que `@>`, `?`, `?|`, `?&` ; les usages réels sont `->>` sur une ligne déjà trouvée (`fn_oai_harvestable_records`) et des `NOT ?` d'enrichissement. Un dédoublonnage par QID demanderait un index d'expression sur `external_ids->>'wikidata'`. |
| `serials_issn_idx` | `serials` | btree sur l'ISSN brut ; toutes les comparaisons portent sur sa forme réduite aux chiffres. |
| `serials_uniform_title_trgm` | `serials` | son seul `%` (`suggest_serial_duplicates`) est OU-é avec l'égalité des ISSN réduits, non indexable ; `fn_serial_search` écrit une autre expression, sous RLS. 4 périodiques. |
| `idx_books_autor_trgm` | `books` | ses lecteurs lisent `books` sous RLS (`CatalogPanel` par PostgREST, `fn_peb_search_exemplares` INVOKER) : `ILIKE` n'y est jamais condition d'index. Le seul lecteur DEFINER (`api.capas_photo_liste`) l'enferme dans un `CASE`. |

Gardés et désormais lus : `author_name_aliases_alias_norm_trgm_idx`, `authors_preferred_name_norm_trgm_idx`, `authors_sort_name_norm_trgm_idx`, `authors_fn_normalize_name_trgm_idx`, `mv_books_catalog_list_v1_titulo_norm_trgm_idx` et son jumeau réseau. `idx_books_titulo_trgm` servait déjà (92 810 parcours, l'auto-jointure `b.titulo % a.titulo` de `suggest_catalog_duplicates`). Les autres index trigramme des vues matérialisées relèvent de B32.

## 6. Ce qui reste, hors de B33

- **La recherche de l'onglet Catalogue** (`CatalogPanel`) et celle du PEB lisent `books` sous RLS : aucun index trigramme ne peut les servir. À grande échelle, leur coût est celui de la policy calculée ligne à ligne — c'est B32.
- **Départage des homonymes** dans l'autocomplétion : `ORDER BY rank DESC, label ASC` sans identifiant. Sans conséquence (même rang, même libellé), mais non déterministe.
- **`suggest_serial_duplicates`** compare toutes les paires de périodiques (`JOIN … ON b.uniform_title % a.uniform_title OR <ISSN>`) : négligeable à 4 fiches ; à quelques milliers, couper la jointure en deux (`UNION`) et recréer l'index trigramme.
- **`search_works_for_link`** filtre `works` par `similarity() >= 0.4` sans index : table petite, recherche rare ; à reprendre avec le même geste si `works` grossit.
