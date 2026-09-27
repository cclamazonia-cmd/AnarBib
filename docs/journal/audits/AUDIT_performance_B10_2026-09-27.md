# Hygiène de performance — B10, 27/09/2026

*Item B10 du backlog v34 : « 170 index inutilisés, 38 clés étrangères non indexées, 24 policies permissives en double ». Trois passes distinctes, à ne pas mélanger (fiche) : fusionner les paires de policies permissives ; indexer les clés étrangères qui servent réellement ; ne supprimer un index inutilisé que si l'on comprend pourquoi il avait été créé.*

Migrations : `20260927180000` (passe 1), `20260927180030` (passe 1 bis), `20260927180100` (passe 2), `20260927180200` (passe 3), `20260927180300` (passe 3 bis). Gardes : `tests/sql/policies_permissives_uniques_tests.sql`, `tests/sql/fk_sans_index_garde_tests.sql` (B21, liste réécrite), `tests/sql/index_redondants_garde_tests.sql`.

## 1. Point de départ, mesuré le 27/09 avant tout geste

**Avis de performance Supabase** (`get_advisors`, recalcul frais) : 25 `multiple_permissive_policies` (WARN), 38 `unindexed_foreign_keys`, 284 `unused_index`, 8 `no_primary_key`, 1 `auth_db_connections_absolute` (INFO).

**Compteurs d'usage.** PostgreSQL 17.6. Le serveur a redémarré le 02/09 à 19 h 15 UTC ; le `last_idx_scan` le plus ancien date de 19 h 37 le même jour. Tous les compteurs cités (scans d'index, suppressions) couvrent donc **25 jours d'exploitation réelle**, pas davantage — et à ce volume (2 634 notices, 20 comptes réels), un compteur à zéro ne prouve pas l'inutilité (DOC du 04/09, `pg_stat` n'est pas une donnée).

**Coût de lecture sous RLS** — `count(*)` sur toute la table, meilleur de trois, production, avant la passe 1 :

| identité | books | exemplares | authors |
|---|---:|---:|---:|
| anon | 88,5 ms | 94,6 ms | 191,7 ms |
| admin réseau | 39,0 ms | 39,5 ms | 0,6 ms |
| bibliothécaire | 208,7 ms | 168,7 ms | 0,6 ms |
| lecteur·rice | 208,0 ms | 176,7 ms | 194,6 ms |

Lecture : un compte lecteur payait plus du double de l'anonyme sur `books` et `exemplares`. La branche staff de la policy y était essayée **avant** la branche publique, ligne à ligne — PostgreSQL combine des policies permissives par un OU dont l'ordre suit l'ordre inverse de leurs noms (`books_staff_read` > `books_public_read`), et ne réordonne pas un OU. Environ 80 µs par notice : à 100 000 notices, le délai de 8 s du rôle `authenticated` serait atteint.

## 2. Passe 1 et 1 bis — une policy permissive par (rôle, commande)

**Les 25 tables** (détecteur de la suite = avis Supabase, à l'unité, vérifié en production) se rangent en trois formes :

- **A — lecture publique (anon, authenticated) + lecture staff (authenticated)** : `authors`, `books`, `exemplares`, `lettre_issues`, `library_circulation_policy_rules`, `library_circulation_policy_sets`, `library_commons`, `library_document_governance`, `library_opening_hours`, `library_public_contact`, `library_regulation_documents`, `serial_holdings`, `serials`. La lecture publique passe à `anon` seul, texte inchangé ; `authenticated` reçoit `<table>_select_authenticated` = publique OU staff.
- **B — lecture + écriture FOR ALL (qui donnait aussi à lire)** : le FOR ALL est scindé en INSERT / UPDATE / DELETE aux conditions identiques. La lecture de `authenticated` devient publique OU écriture là où la lecture publique ne vaut pas `true` (`book_digital_resources`, `digital_assets`, `gazette_issue_locales`, `gazette_issues`, `lettre_issue_locales`) ; elle reste seule quand elle vaut `true` (`catalog_ref_audio_recording_types`, `subjects`, `work_expressions`, `works`) ou quand elle contient déjà la condition d'écriture en branche OU (`library_deposit_rules`).
- **C — deux policies du même rôle et de la même commande** : `profiles` (SELECT : mon profil et ceux de mes bibliothèques, OU la gouvernance en cours) et `book_reading_notes` (UPDATE : autrice OU staff, USING et WITH CHECK). PostgreSQL combine de toute façon les permissives par OU, USING et WITH CHECK chacun de leur côté : la fusion ne change rien à qui voit ou écrit quoi.

**Méthode.** Les expressions sont **recopiées** des définitions réelles (`pg_get_expr`) par un script, jamais à la main ; le banc et la production portaient les 69 mêmes policies au md5 près (`0723f907…`). La migration refuse de s'appliquer si cette signature a changé, et vérifie en sortie l'état éprouvé au banc. Seule retouche d'expression : `fn_caller_is_network_admin()` et `fn_caller_is_staff()`, sans argument, enveloppées en `(SELECT …)` (InitPlan, calculées une fois par requête).

**Passe 1 bis — l'ordre du OU.** La passe 1 a mis la lecture publique en tête : juste pour les lecteurs, faux pour le staff quand sa branche **ne dépend pas de la ligne** (EXISTS non corrélé, fonction sans argument). Expérience en production, une bibliothécaire sur `authors` : **0,4 ms** condition « une fois » d'abord, **47 ms** lecture publique d'abord. La passe 1 étant déjà en file de déploiement, une seconde migration a réordonné dix policies selon la règle :

1. ce qui ne dépend pas de la ligne (calculé une fois) ;
2. la lecture publique (vraie pour presque toutes les lignes) ;
3. le staff évalué ligne à ligne.

**Ce qui ne change pas, exprès.** Les policies d'`anon` gardent leur texte — y compris trois qui **lèvent une erreur au lieu de rendre zéro ligne** (constat du 27/09, antérieur à B10) : `library_circulation_policy_sets` et `_rules` appellent `fn_library_has_full_sigb`, fermée à `anon` depuis le socle du 10/05 ; `library_deposit_rules_select` (TO public) lit `user_library_memberships`, que `anon` ne lit pas. Latent : ces tables ne sont lues que par des écrans connectés (`RegimeStateBox`, `PolicySetManager`, `LoanDepositPanel`), qui avalent d'ailleurs l'erreur. Corriger change un comportement : c'est un autre item.

**Ce qui tient l'invariant.** `policies_permissives_uniques_tests.sql` (33 tests) : T1 aucune paire dans aucun schéma applicatif (liste fermée vide) ; T2 le détecteur mord (FOR ALL compris) ; T3 la lecture publique vit désormais en deux copies — la policy `anon` et une branche de `<table>_select_authenticated` — et doit y figurer texte pour texte (sinon une personne connectée verrait moins qu'un visiteur) ; T4-T5 trente lectures et écritures réelles sous anon, lectrice, intrus·e, coordination, admin réseau et `network_staff`, sur des fixtures propres à la suite. `vues_api_definer_tests.sql` T2/T4 regardent le contenu de la policy consolidée de `profiles`.

## 3. Passe 2 — les clés étrangères dont le parent est supprimé

Une clé étrangère sans index ne coûte qu'à la suppression de son **parent** : PostgreSQL parcourt alors toute la table enfant pour vérifier, mettre à NULL ou supprimer en cascade. La question n'est donc pas « la table est-elle petite » mais « le parent est-il supprimé en exploitation ». Du 02/09 au 27/09 : **146 œuvres** supprimées (fusions), **37 autorités**, **21 notices**, **2 comptes** (et `profiles`), aucune bibliothèque ; et chaque brouillon purgé par la corbeille ou « Supprimer le lot » coûtait deux parcours complets de `ingest.partner_catalog_staging_rows` (11 Mo), ses deux colonnes de brouillon étant en SET NULL.

**Indexées (21)** : les rattachements d'import (`partner_catalog_staging_rows` ×4, `partner_catalog_row_to_draft.batch_id`) ; le côté « b » des tables de paires, la clé primaire couvrant « a » (`author_not_duplicate`, `authority_duplicate_reports`, `catalog_duplicate_reports`, `serial_not_duplicate`) ; `book_drafts.work_id` ; les colonnes d'acteur vers les comptes.

**Assumées (17)**, motif écrit en tête de la liste de B21 : les 15 FK vers les tables de codes `catalog_ref_*`, `book_drafts.initial_copies_library_id` (une bibliothèque se désactive, ne se supprime pas) et `ingest.partner_catalog_sources.catalog_partner_id` (3 partenaires).

## 4. Passe 3 — les index inutilisés

Ventilation des 283 index non uniques à zéro scan (schémas `public`, `ingest`) :

- **174 servent une clé étrangère** — gardés par doctrine (B21 : une FK a son index) ;
- **32 sont redondants au sens strict** — colonnes-clés préfixe exact d'un autre index valide de la même table, mêmes classes d'opérateurs, collations et ordres, même prédicat, sans INCLUDE (banc et production identiques) :
  - **10 jamais empruntés : retirés** (passe 3), raison relue un par un dans l'en-tête de la migration — huit du socle du 10/05, un index sur la colonne de tête d'une UNIQUE ou d'un index composé déjà présent ; deux des périodiques du 27/08, créés dans la même migration que l'index composé qui les couvrait ;
  - **22 empruntés : gardés**, nommés avec leurs compteurs dans `index_redondants_garde_tests.sql` (jusqu'à 10,8 millions de scans pour `book_holdings_book_id_idx`) — les retirer déplacerait des plans chauds vers l'index couvrant : cela se mesure avant de se décider ;
- **le reste** : inventaire à la section 5.

`index_redondants_garde_tests.sql` refuse désormais tout nouvel index redondant (T3 éprouve aussi les trois faux positifs à éviter : autre classe d'opérateurs, autre prédicat, INCLUDE).

## 5. Les 108 index inutilisés restants : inventaire et décisions

**Méthode.** Relevé du 27/09 entre 16 h 30 et 17 h 05 UTC, confié à un agent en lecture seule stricte (SELECT seulement, aucun EXPLAIN), puis recoupé par mes propres requêtes pour tout ce qui a été retiré. Périmètre : index non uniques, non PK, à zéro scan, qui ne servent aucune clé étrangère et ne sont pas redondants — **108 index, 28 Mo**. Pour chacun : migration d'origine, puis tout ce qui pourrait l'emprunter — `pg_stat_statements` (remis à zéro au redémarrage du 02/09, `track = top`, **aucune éviction** : toutes les requêtes de premier niveau depuis le 02/09 y sont), les corps de fonctions (`pg_proc.prosrc`), vues, policies, crons, le front, les Edge Functions et les scripts. Un effet de bord, relevé par l'agent lui-même : sa requête de comptage a posé un scan sur `catalog_audit_log_actor_idx` (gardé).

**Verdicts de l'inventaire** : 42 GARDER (29 servent un motif réel, 6 « faibles », 6 « bloqués » par la forme de leur requête, 1 « prévu ») et 66 SUPPRIMER proposés.

**Décision B10 — 12 retirés, 54 gardés exprès :**

- **retirés (passe 3 bis, `20260927180300`)** : les 12 qui pèsent sur un chemin d'écriture — 6 sur `books` (27 index, 6,5 Mo, pour 3,8 Mo de données), 4 sur `book_drafts`, `idx_shp_endpoint` (3,5 Mo, maintenu toutes les cinq minutes, jamais lu), le partiel `idx_reader_card_tokens_hash`. Pièces recoupées : `pg_stat_statements` (ces colonnes n'y apparaissent que dans des COPY, des UPDATE … SET et du DDL), prédicats dans les fonctions et vues (seulement `IS DISTINCT FROM` et `IS NOT NULL` bornés par `batch_id`), front (deux `ILIKE '%…%'` sur `isbn`, qu'un btree ne sert pas), et le `s` de `catalog_works_v1` qui est bien la source `__VIEW__`, pas `books` ;
- **gardés, renvoyés à B32** : les 19 index secondaires des deux vues matérialisées. Inatteignables depuis SECU-MV-FIX2 (15/06), mais leur sort dépend de la refonte de la lecture du catalogue : une lecture paramétrée qui filtre dans la fonction en réemploierait une partie ;
- **gardés, renvoyés à B33** : 4 index de recherche dont l'expression ou l'opérateur ne correspond pas aux requêtes (`authors_sort_name_norm_trgm_idx`, `idx_publishers_name_trgm`, `idx_authors_external_ids`, `serials_issn_idx`) — la requête se corrige, l'index se réaligne ou se remplace alors ;
- **gardés sans suite** : 31 index de petites tables (journaux, files d'envoi, métadonnées JSON, réglages) — de 8 à 96 ko chacun, les retirer n'apporterait rien de mesurable ; leurs verdicts restent écrits ci-dessous pour qui voudra les solder.

### Conclusion sur les deux vues matérialisées

**`mv_books_catalog_list_v1` et `mv_books_catalog_list_network_v1` sont VIVANTES : lues à chaque page du catalogue et rafraîchies toutes les 15 minutes. Mais 19 de leurs 21 index secondaires du périmètre sont INACCESSIBLES : aucune requête ne peut les emprunter.**

- **Rafraîchissement** : cron `refresh-mv-books-catalog-list` (`*/15 * * * *`, actif) → `public.refresh_mv_books_catalog_list_v1()` = `REFRESH MATERIALIZED VIEW CONCURRENTLY` des deux vues puis `ANALYZE`. Même chemin par le bouton staff `public.request_catalog_refresh()` (verrou consultatif 792025001). Le job est aussi déclaré dans `private.fn_crons_attendus` (migration C6 du 27/09, `20260927121437_c6_la_file_de_verification_s_alimente_seule.sql:173`).
- **Lecteurs** (recherche dans `pg_proc.prosrc`, `pg_views`, `pg_matviews`, front, EF, scripts) :
  1. `private.fn_catalog_public_rows()` = `SELECT * FROM public.mv_books_catalog_list_v1` et `private.fn_catalog_network_rows()` = `SELECT * FROM public.mv_books_catalog_list_network_v1`. Les deux sont `LANGUAGE sql`, `STABLE`, **`SECURITY DEFINER`** et portent **`SET search_path = public, pg_catalog`**. PostgreSQL n'insère jamais en ligne (`inline_set_returning_function`) une fonction SECURITY DEFINER ou munie d'un `SET` : c'est une barrière d'optimisation. Chaque appel matérialise **toute** la vue par un parcours séquentiel ; les filtres et tris posés au-dessus s'appliquent ensuite au résultat, jamais à la vue.
  2. Au-dessus de ces enveloppes : les vues `api.catalog_list_anon_v1` et `api.catalog_list_session_v1`, lues par `api.catalog_works_v1` (catalogue par œuvre, `EXECUTE` dynamique sur la vue), `api.catalog_facets_v1`, `api.catalog_search_ids_v1`, la liste plate du front (`CatalogPage.jsx:447`, `ORDER BY titulo LIMIT` : 459 + 102 + 14 appels), `AuthorPage.jsx:151`, `scripts/build-catalogue-snapshot.mjs`, et la sonde `health-probe` toutes les 5 min (`catalog_search_ids_v1` et `catalog_works_v1`).
  3. Seul lecteur **direct** : `api.search_catalog_v1` (l'autocomplétion, 40 appels, 177 ms en moyenne), qui ne touche la vue que par `m.book_id` (index unique, hors périmètre, 166 scans) et par `f_normalize_search(m.titulo)` (voir plus bas, « bloqué »).
  4. Personne d'autre : `anon`, `authenticated` et `authenticator` n'ont **aucun** `SELECT` sur les deux vues (seul `service_role` en a), `pg_graphql` n'est pas installé, et aucune ligne de `src/`, `supabase/functions/`, `scripts/`, `deploy/` ne nomme les vues.
- **Statistiques** (`pg_stat_user_tables`) : v1 `seq_scan = 20 828` (55,2 M tuples lus, dernier à 16:30:03 aujourd'hui), `idx_scan = 167` (166 sur l'index unique, 1 sur `tipo_material` le 20/09 à 12:05, vraisemblablement une requête manuelle : aucun code ne filtre la vue par `tipo_material`). Network : `seq_scan = 2 791` (7,4 M tuples), `idx_scan = 0`, y compris son index unique. `n_tup_ins = 666` et `n_tup_del = 686` sur chacune depuis le 02/09 : ce sont les écarts appliqués par le `CONCURRENTLY`, donc chaque rafraîchissement maintient bien les 11 et 12 index.
- **Pourquoi ces index existent** (socle, sans commentaire ; l'histoire est dans le dépôt) : ils servaient le dessin d'origine, où les vues de l'API lisaient la MV directement, si bien que les filtres PostgREST (`titulo`/`autor`/`editora` en ILIKE, brut ou via `f_normalize_search`) et les tris (`titulo`, `autor`, `ano`, `created_at`) ainsi que `tipo_material` et `library_slug` descendaient jusqu'à la MV. Le **paquet SECU-MV-FIX2 du 15/06/2026** a sorti les MV de l'API derrière les enveloppes SECDEF. Les pièces : le commentaire du schéma `private` (`20260510000000_baseline_live.sql:45`) et ceux des deux fonctions (`baseline:9876`, `baseline:9992` : « Wrapper SECDEF de la MV catalogue publique. Permet a la vue invoker catalog_list_anon_v1 de lire la MV sans GRANT direct »). Depuis ce jour, ces index ne peuvent plus servir.
- **Ce que coûtent les deux MV** : 9,8 et 10,0 Mo, dont **7,6 et 7,7 Mo d'index** pour 2,2 Mo de données chacune. Supprimer les 19 index inaccessibles libère 11,6 Mo et allège le `CONCURRENTLY`. Cela **ne corrige rien** au vrai coût, qui est de relire toute la MV à chaque page.
- **Les 2 index gardés** : `…_titulo_norm_trgm_idx` sur chaque vue (`f_normalize_search(titulo)`). `search_catalog_v1` lit les MV directement avec exactement cette expression, mais l'index lui est interdit par sa clause `OR EXISTS (…)` (voir « bloqué »).

### Règles de lecture appliquées

- **Index d'expression** : il ne sert que si une requête écrit **exactement** la même expression. Exemple : `f_normalize_search(COALESCE(sort_name,''))` n'est pas `f_normalize_search(sort_name)`.
- **GIN `jsonb_ops`** : il ne sert que `@>`, `?`, `?|`, `?&`, `@?`, `@@`. Ni `->>`, ni `jsonb_each_text`, ni `NOT (x ? k)`.
- **Btree texte** à l'opclass par défaut sous la collation ICU `en-US` de la base : aucun `LIKE`/`ILIKE`, préfixe compris ; seulement `=`, `IN`, les bornes et `ORDER BY`.
- **GIN trigramme** : `%`, `LIKE`/`ILIKE`, `~`, et `=` depuis pg_trgm 1.6 (la version installée). La **fonction** `similarity(a, b) >= x` n'est pas indexable.
- **`OR`** : un plan BitmapOr exige que **chaque** branche soit indexable. Une seule branche non indexable (un `EXISTS` corrélé, une colonne sans index trigramme, une autre table) impose un parcours séquentiel.
- **Fonction SQL SECURITY DEFINER ou munie d'un `SET`** : jamais insérée en ligne. Les prédicats posés au-dessus n'atteignent pas la table.
- **Verdict** : je SUPPRIME seulement si j'établis qu'aucune requête (fonction, vue, policy RLS, cron, front, EF, script) ne peut emprunter l'index. Les cas couverts : colonne ou expression jamais filtrée ni triée, opérateur incompatible, accès seulement à travers une barrière opaque, doublon fonctionnel strict. Tout le reste est GARDÉ, qualifié « faible », « bloqué » ou « prévu » selon le cas.

Abréviation : **socle** = `supabase/migrations/20260510000000_baseline_live.sql`, un dump du live (le contenu va jusqu'à mi-juin : il porte SECU-MV-FIX2 du 15/06). Un index « socle:NNNNN » n'a ni commentaire ni histoire dans le dépôt.
Colonne « lignes » : `reltuples` de la table ; « ~ » signale une table jamais analysée (`reltuples = -1`), donc vide ou minuscule.

---

### 1. Vues matérialisées du catalogue (21)

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| mv_books_catalog_list_v1_titulo_norm_trgm_idx | 1 624 kB | 2 634 | socle:51569 | `search_catalog_v1` : `f_normalize_search(m.titulo) % v_q_norm OR … LIKE v_q_norm‖'%' OR EXISTS (SELECT 1 FROM unnest(v_tokens) … ~ …)` | **GARDER · bloqué** | Seul prédicat direct sur la MV, et c'est l'expression exacte ; la branche `OR EXISTS` interdit le BitmapOr, donc l'index ne servira pas davantage à 100 000 notices tant que la requête reste ainsi. |
| mv_books_catalog_list_network_v1_titulo_norm_trgm_idx | 1 632 kB | 2 634 | socle:51521 | idem (branche `v_is_member`) | **GARDER · bloqué** | idem |
| mv_books_catalog_list_v1_titulo_trgm_idx | 1 688 kB | 2 634 | socle:51573 | `titulo ILIKE` n'existe qu'au-dessus des enveloppes (`catalog_facets_v1`) | proposé, **gardé** → B32 | Inaccessible : toute lecture filtrante passe par `private.fn_catalog_public_rows()` (SECDEF + SET, jamais insérée en ligne). |
| mv_books_catalog_list_v1_autor_trgm_idx | 1 256 kB | 2 634 | socle:51541 | `autor ILIKE` au-dessus des enveloppes (`catalog_works_v1`, `catalog_facets_v1`) | proposé, **gardé** → B32 | idem |
| mv_books_catalog_list_v1_autor_norm_trgm_idx | 1 224 kB | 2 634 | socle:51537 | aucun : `f_normalize_search(autor)` n'est écrit nulle part | proposé, **gardé** → B32 | Expression écrite par personne, et de toute façon derrière l'enveloppe. |
| mv_books_catalog_list_v1_editora_trgm_idx | 1 128 kB | 2 634 | socle:51553 | `editora ILIKE` au-dessus des enveloppes | proposé, **gardé** → B32 | Inaccessible. |
| mv_books_catalog_list_v1_titulo_idx | 240 kB | 2 634 | socle:51565 | front `catalog_list_anon_v1 … ORDER BY titulo LIMIT` (459 + 102 + 14 appels), au-dessus de l'enveloppe | proposé, **gardé** → B32 | Le tri porte sur la sortie de la Function Scan ; 0 scan malgré 575 tris par titre. |
| mv_books_catalog_list_v1_autor_idx | 152 kB | 2 634 | socle:51533 | tri `autor.asc` dans `catalog_works_v1` (sur la vue) | proposé, **gardé** → B32 | Inaccessible. |
| mv_books_catalog_list_v1_ano_idx | 56 kB | 2 634 | socle:51529 | `s.ano = p.year_exact` et bornes d'année dans `catalog_works_v1` (sur la vue) | proposé, **gardé** → B32 | Inaccessible. |
| mv_books_catalog_list_v1_created_at_idx | 56 kB | 2 634 | socle:51549 | tri `created_at.desc` dans `catalog_works_v1` (sur la vue) | proposé, **gardé** → B32 | Inaccessible. |
| mv_books_catalog_list_v1_library_slug_idx | 72 kB | 2 634 | socle:51557 | `c.library_slug = p.library` dans `catalog_facets_v1` (sur la vue) | proposé, **gardé** → B32 | Inaccessible. |
| mv_books_catalog_list_network_v1_titulo_trgm_idx | 1 688 kB | 2 634 | socle:51525 | au-dessus de `private.fn_catalog_network_rows()` | proposé, **gardé** → B32 | Inaccessible ; la MV réseau n'a aucun scan d'index en 25 jours, y compris son index unique. |
| mv_books_catalog_list_network_v1_autor_trgm_idx | 1 264 kB | 2 634 | socle:51493 | idem | proposé, **gardé** → B32 | idem |
| mv_books_catalog_list_network_v1_autor_norm_trgm_idx | 1 224 kB | 2 634 | socle:51489 | aucun | proposé, **gardé** → B32 | Expression écrite par personne. |
| mv_books_catalog_list_network_v1_editora_trgm_idx | 1 152 kB | 2 634 | socle:51505 | au-dessus de l'enveloppe | proposé, **gardé** → B32 | Inaccessible. |
| mv_books_catalog_list_network_v1_titulo_idx | 280 kB | 2 634 | socle:51517 | au-dessus de l'enveloppe | proposé, **gardé** → B32 | idem |
| mv_books_catalog_list_network_v1_autor_idx | 168 kB | 2 634 | socle:51485 | au-dessus de l'enveloppe | proposé, **gardé** → B32 | idem |
| mv_books_catalog_list_network_v1_tipo_material_idx | 72 kB | 2 634 | socle:51513 | `s.tipo_material = p.material` au-dessus de l'enveloppe | proposé, **gardé** → B32 | idem |
| mv_books_catalog_list_network_v1_ano_idx | 56 kB | 2 634 | socle:51481 | au-dessus de l'enveloppe | proposé, **gardé** → B32 | idem |
| mv_books_catalog_list_network_v1_created_at_idx | 64 kB | 2 634 | socle:51501 | au-dessus de l'enveloppe | proposé, **gardé** → B32 | idem |
| mv_books_catalog_list_network_v1_library_slug_idx | 56 kB | 2 634 | socle:51509 | au-dessus de l'enveloppe | proposé, **gardé** → B32 | idem |

Si la lecture du catalogue devient un jour une RPC paramétrée qui lit la MV directement, avec les filtres écrits dedans, il faudra recréer **sélectivement** les index que cette RPC écrira. Les formes actuelles (`(p.x IS NULL OR col ILIKE '%'‖p.x‖'%')`, meule de foin concaténée de `catalog_search_ids_v1`) ne les emprunteraient de toute façon pas.

### 2. `books` (13)

Pour les colonnes « héritées » (`holder_library`, `owner_library`, `partner_source`, `mutualization_status`, en texte) sur `books` et `book_drafts`, la réponse est non : **elles ne sont plus lues comme filtre**. On les écrit ou on les copie : `publish_book_draft`, `create_book_draft_from_book`, le déclencheur `sync_book_native_provenance_bridge` (normalisation), `tg_drafts_library_fixed` (remplit `owner_library` depuis `owner_library_id`), `network_admin_reassign_book_to_library`, `fn_batch_reassign_library`, `fn_import_promote`. Le formulaire `BookDraftForm` (niveau 3 de `fieldRegistry.js:353-356`) les affiche. Les FK portent sur les colonnes `*_id` (`books_holder_library_id_fkey`, etc.), servies par `ix_books_*_library_id`. Les deux seules occurrences en prédicat sont inindexables et bornées par `batch_id` : `d.owner_library IS DISTINCT FROM v_lib.name` (`fn_batch_reassign_library`) et `d.partner_source is not null` dans un `OR` (`fn_batch_is_imported`).

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| idx_books_isbn_norm | 64 kB | 2 646 | socle:50929 | `ingest.fn_match_partner_catalog_row` : `and ingest.fn_normalize_isxn(b.isbn) = v_isbn_norm` (garde `v_isbn_norm is not null`) | GARDER | Expression exacte, rapprochement des imports (s'exécute par lot, d'où 0 scan). |
| idx_books_issn_norm | 48 kB | 2 646 | socle:50937 | idem, `fn_normalize_isxn(b.issn) = v_issn_norm` | GARDER | idem (l'index jumeau `idx_bd_issn_norm` a servi 7 fois). |
| idx_books_tit_aut_norm | 376 kB | 2 646 | socle:50957 | idem, `fn_match_normalize_text(b.titulo) = … and fn_match_normalize_text(b.autor) = …` | GARDER | Couple d'expressions exact. |
| idx_books_tipo_material | 64 kB | 2 646 | socle:50953 | front `SerialDetailEditor.jsx:164-168` : `books … .is('serial_id', null).in('tipo_material', ['periodico','artigo']).ilike('titulo', …)` | GARDER | `tipo_material = ANY(…)` directement sur `books`, sélectif à grande échelle. |
| idx_books_autor_trgm | 1 176 kB | 2 646 | socle:50909 | front `CatalogPanel.jsx:100` : `or(titulo.ilike, autor.ilike, isbn.ilike, bib_ref.ilike)` (28 appels) ; `fn_peb_search_exemplares` : `b.titulo ILIKE … OR b.autor ILIKE … OR e.tombo ILIKE … OR b.bib_ref ILIKE …` | **GARDER · bloqué** | Le prédicat existe, mais chaque `OR` contient une branche sans index trigramme (`isbn`, `bib_ref`, `e.tombo` sur une autre table) : pas de BitmapOr possible. |
| idx_books_ano | 56 kB | 2 646 | socle:50901 | `api.serial_issues_v1` : `WHERE b.serial_id = p_serial_id ORDER BY b.ano NULLS LAST, b.issue_key, b.titulo` | GARDER · faible | Seul usage de `ano` brut ; `serial_id` est le chemin naturel (`books_serial_id_idx`). Tous les autres usages portent sur `substring(ano …)::int` ou passent par la vue. |
| books_title_sort_idx | 264 kB | 2 646 | `20260821042000_conventions_02_colonnes.sql:125` (« Index de tri (le parcours alphabétique #OPAC10 en dépend) ») | aucune requête n'écrit `lower(substr(titulo, title_nonfiling + 1))`. Commentaire de colonne (l.88-92) : « Consommateur prévu : parcours alphabétique #OPAC10 — la colonne n'est pas encore exposée par les vues du catalogue » ; `docs/specs/INVENTAIRE.md:701` : « CONV-4 n'est pas encore consommable … #OPAC10 trie toujours sur titulo.asc » | **GARDER · prévu** | Consommateur documenté il y a 5 semaines, pas encore câblé. Il ne servira que si ce consommateur lit `books` directement avec l'expression exacte : derrière la vue du catalogue, il resterait inutilisable. |
| idx_books_editora_trgm | 1 080 kB | 2 646 | socle:50917 | aucun prédicat sur `books.editora` (les `editora ILIKE` de `catalog_works_v1` et `catalog_facets_v1` portent sur la vue, via la MV) ; aucune requête PostgREST ne le fait (`pg_stat_statements`) | **RETIRÉ** (passe 3 bis) | Colonne jamais filtrée directement sur `books`. |
| idx_books_isbn | 64 kB | 2 646 | socle:50925 | seulement `ILIKE '%…%'` : `BookDraftForm.jsx:548` et l'`OR` de `CatalogPanel` ; aucun `isbn =` dans les fonctions, vues ou requêtes | **RETIRÉ** (passe 3 bis) | Un btree ne sert pas un `ILIKE` à joker initial (collation ICU). Les rapprochements passent par `idx_books_isbn_norm`. |
| idx_books_issn | 48 kB | 2 646 | socle:50933 | aucun prédicat sur `books.issn` | **RETIRÉ** (passe 3 bis) | Jamais filtrée ; rapprochement par `idx_books_issn_norm`. |
| idx_books_holder_library | 48 kB | 2 646 | socle:50921 | écriture et copie seulement | **RETIRÉ** (passe 3 bis) | Colonne héritée jamais filtrée ; la FK est sur `holder_library_id`. |
| idx_books_owner_library | 48 kB | 2 646 | socle:50945 | écriture et copie seulement | **RETIRÉ** (passe 3 bis) | idem (`owner_library_id`) |
| idx_books_partner_source | 48 kB | 2 646 | socle:50949 | écriture et copie seulement | **RETIRÉ** (passe 3 bis) | Jamais filtrée. |

### 3. `book_drafts` (6)

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| idx_bd_isbn_norm | 64 kB | 2 250 | socle:50773 | `fn_match_partner_catalog_row` : `ingest.fn_normalize_isxn(d.isbn) = v_isbn_norm` | GARDER | Expression exacte, rapprochement des imports. |
| idx_bd_tit_aut_norm | 480 kB | 2 250 | socle:50781 | idem, `fn_match_normalize_text(d.titulo)` et `(d.autor)` | GARDER | idem |
| idx_book_drafts_holder_library | 72 kB | 2 250 | socle:50877 | écriture et copie seulement | **RETIRÉ** (passe 3 bis) | Colonne héritée jamais filtrée. |
| idx_book_drafts_owner_library | 120 kB | 2 250 | socle:50885 | `d.owner_library IS DISTINCT FROM v_lib.name` dans un UPDATE borné par `batch_id` | **RETIRÉ** (passe 3 bis) | `IS DISTINCT FROM` n'est pas indexable et `batch_id` pilote. |
| idx_book_drafts_partner_source | 104 kB | 2 250 | socle:50889 | `d.partner_source is not null` dans un `OR`, à l'intérieur d'un `EXISTS` borné par `batch_id` (`fn_batch_is_imported`) | **RETIRÉ** (passe 3 bis) | Aucun chemin d'accès possible par cette colonne. |
| idx_book_drafts_mutualization_status | 72 kB | 2 250 | socle:50881 | écriture et copie seulement | **RETIRÉ** (passe 3 bis) | Jamais filtrée. |

Hors périmètre, pour mémoire : les index `*_code` et `*_library_id` de `book_catalog_context` et `book_draft_catalog_context` sont eux aussi à 0 scan (10 index). Ils soutiennent des FK et relèvent donc de l'autre famille.

### 4. Autorités : `authors`, `author_name_aliases`, `publishers`, `serials`, `subjects` (9)

Sur les trois GIN trigramme d'`authors`, **un seul est servi par une recherche réelle** : `fn_normalize_name(preferred_name)`. Celui en `f_normalize_search(preferred_name)` est visé par `search_catalog_v1`, qui s'en interdit l'usage. Celui en `f_normalize_search(sort_name)` n'est écrit par personne, car `search_catalog_v1` écrit `f_normalize_search(COALESCE(a.sort_name, ''))`.

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| authors_fn_normalize_name_trgm_idx | 456 kB | 1 505 | `20260821130003_balayage_global_des_autorites.sql:58` (« L'index qui rend le balayage possible » + `COMMENT ON INDEX` l.62) | `suggest_authority_duplicates` : `fn_normalize_name(b.preferred_name) % fo.f` ; `link_book_contributors_to_authors` : `fn_normalize_name(a.preferred_name) = v_row.norm_name` (égalité servie par gin_trgm_ops) | GARDER | Raison de création documentée, et deux motifs réels. |
| authors_preferred_name_norm_trgm_idx | 1 104 kB | 1 505 | socle:50533 | `search_catalog_v1` : `f_normalize_search(a.preferred_name) % v OR … LIKE v‖'%' OR … OR EXISTS (… ~ …)` | **GARDER · bloqué** | Expression exacte, mais le `OR EXISTS` interdit l'index. |
| authors_sort_name_norm_trgm_idx | 1 104 kB | 1 505 | socle:50537 | aucun : `search_catalog_v1` écrit `f_normalize_search(COALESCE(a.sort_name, ''))`, et rien d'autre n'utilise `f_normalize_search(sort_name)` | proposé, **gardé** → B33 | Expression écrite par personne. Si l'on corrige un jour `search_catalog_v1`, y écrire `f_normalize_search(a.sort_name)` (le `COALESCE` ne sert à rien dans un WHERE) et le recréer. |
| idx_authors_external_ids | 256 kB | 1 505 | `20260621162441_audio_p0_mbid_external_ids_and_fingerprint.sql:51` (« recherche d'une autorité par identifiant externe (ex. par MBID) ») | aucun `@>` ni `?` positif sur `authors.external_ids`. Les usages réels sont `a.external_ids->>'musicbrainz'` (`fn_oai_harvestable_records`) et `NOT (a.external_ids ? 'wikidata_releve' / 'idref' / 'lccn')` dans les migrations d'enrichissement du 26-27/09 | proposé, **gardé** → B33 | La recherche par MBID n'a jamais été câblée, et GIN ne sert ni `->>` ni une négation. Pour dédoublonner par QID, il faudrait un index d'expression sur `external_ids->>'wikidata'`. |
| author_name_aliases_alias_norm_trgm_idx | 656 kB | 1 610 | socle:50525 | `search_catalog_v1` : `ana.is_active = true AND (ana.alias_norm % v OR ana.alias_norm LIKE v‖'%' OR EXISTS …)` | **GARDER · bloqué** | Prédicat exact, prédicat partiel `is_active = true` satisfait ; `OR EXISTS` bloquant. L'égalité de `v_author_alias_candidates_unique` passe par l'unique `uq_author_name_aliases_norm_active`. |
| idx_publishers_name_trgm | 704 kB | 1 190 | socle:51249 | `search_publishers_by_name` travaille sur `fn_normalize_name(pub.name)` (`LIKE` et `similarity()`) ; `fn_sync_publisher_id_on_publish` : `lower(p.name) = lower(trim(NEW.editora))` | proposé, **gardé** → B33 | Aucune requête sur `name` brut avec un opérateur trigramme. |
| serials_uniform_title_trgm | 24 kB | ~(jamais analysée) | `20260827163000_periodiques_p1_serials.sql:203` | `suggest_serial_duplicates` : `JOIN serials b ON b.id > a.id AND (b.uniform_title % a.uniform_title OR <égalité des ISSN réduits aux chiffres>)` ; `fn_serial_search` écrit `f_normalize_search(s.uniform_title)` (autre expression) | **GARDER · bloqué** | Le `%` exact existe, mais il est `OR`é avec une expression regexp non indexée. |
| serials_issn_idx | 16 kB | ~ | `20260827163000_periodiques_p1_serials.sql:205` | toutes les comparaisons portent sur `regexp_replace(coalesce(issn,''),'\D','','g')` (`fn_serial_search`, `suggest_serial_duplicates`) ; aucun `issn =` brut | proposé, **gardé** → B33 | Expression différente. Le besoin (ISSN) est réel, mais porte sur la forme normalisée. |
| subjects_label_i18n_gin | 80 kB | 89 | socle:51673 | `search_subjects` : `EXISTS (SELECT 1 FROM jsonb_each_text(s.label_i18n) …)` ; ailleurs `label_i18n->>'pt-BR'` (tri, affichage) | proposé, gardé (petite table) | Aucun opérateur GIN jsonb (`@>`, `?`) nulle part. |

### 5. Fonds et exemplaires : `book_holdings`, `exemplar_drafts`, `digital_assets`, `book_digital_resources` (6)

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| digital_assets_rights_status_idx | 16 kB | ~ | socle:50637 | `fn_export_fonds_eligible_count` et `fn_export_fonds_records` : `da.rights_status = 'public_domain_confirmed'` | GARDER | Filtre réel (fonds exportables). |
| digital_assets_is_public_idx | 16 kB | ~ | socle:50633 | policy RLS `digital_assets_public_read` (anon, authenticated) : `is_public = true AND bucket_name = … AND EXISTS …` | GARDER · faible | Prédicat RLS réel ; booléen peu sélectif. |
| digital_assets_bib_ref_idx | 16 kB | ~ | socle:50621 | aucun filtre sur `digital_assets.bib_ref` (lien par `book_id`) | proposé, gardé (petite table) | Colonne jamais filtrée. |
| book_holdings_local_bib_ref_idx | 168 kB | 2 696 | socle:50561 | égalités toujours bornées par bibliothèque : `ExchangeProposalForm.jsx:216-222` `.eq('library_id').in('local_bib_ref')`, servie par l'unique `(library_id, local_bib_ref)`. Hors bibliothèque, seulement `trim(coalesce(h.local_bib_ref,'')) = …` (`resolve_library_holding_bridge`, `tg_exemplares_ensure_holding`, `fn_book_restricted_pdf_state`) | proposé, gardé (petite table) | Couvert par `book_holdings_library_local_bib_ref_uidx`. Le reste écrit une autre expression. |
| idx_exemplar_drafts_label_status | 16 kB | 19 | socle:51061 | écrit (imports, publication) ou projeté (`v_exemplar_drafts_resolved`), affiché dans le formulaire ; jamais filtré | proposé, gardé (petite table) | Colonne jamais filtrée. |
| idx_bdr_acoustid_id | 8 kB | 18 | `20260621162441_audio_p0_…sql:73` (« dédoublonnage / lookup par AcoustID ») | seulement `SET acoustid_id = …` (`api.audio_resource_set_fingerprint`) ; `AudioFingerprintTool` filtre `book_id` et `resource_type` | proposé, gardé (petite table) | Recherche par AcoustID jamais câblée (elle passe par l'API externe, et le dédoublonnage interne par `chromaprint_fp`). |

### 6. Import (`ingest`) (3)

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| partner_catalog_import_dispatch_log_request_id_idx | 16 kB | jamais analysée | socle:50433 | `update … set request_id = v_request_id … where id = v_log_id` (`fn_dispatch_oai_harvest`, `fn_dispatch_partner_catalog_import`) ; personne ne lit par `request_id` | proposé, gardé (petite table) | Colonne écrite, jamais lue. |
| partner_catalog_match_candidates_candidate_idx | 72 kB | 28 | socle:50461 | insertion par `fn_match_partner_catalog_row` ; les vues `*_match_ui` et `*_workflow_ui` lisent par `staging_row_id` (LATERAL) puis rejoignent `books` par sa clé primaire | proposé, gardé (petite table) | Aucune recherche inverse « quelles lignes ont désigné ce livre ». |
| partner_catalog_sources_relation_idx | 16 kB | 3 | socle:50481 | `relation_status` seulement écrite ou projetée ; `fn_cron_import_harvest_oai` filtre `s.import_enabled` seul (2ᵉ colonne ; pas de skip scan en PG17) | proposé, gardé (petite table) | La colonne de tête n'est jamais filtrée. |

### 7. Supervision (`service_health_*`) (3)

Pour `idx_shp_endpoint`, voici qui lit les sondes, et comment. L'EF `health-probe` fait, à chaque tour de 5 min, `SELECT checked_at, ok … ORDER BY checked_at DESC LIMIT n` (7 168 appels), un `INSERT` en lot (7 168) et `DELETE … WHERE checked_at < $1` (purge à 30 jours, 7 168 appels). Les requêtes manuelles (MCP) filtrent `checked_at > now() - interval … ORDER BY checked_at DESC, endpoint`. **Aucune requête ne filtre ni ne trie d'abord par `endpoint`.** Tout est servi par `idx_shp_checked_at` (19 081 scans). `endpoint` ne prend que 5 libellés courts (`health-probe/index.ts:58-96`).

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| idx_shp_endpoint | **3 568 kB** | 36 277 | `20260817142739_service_health_probes.sql:33` (créé avec `idx_shp_checked_at`, sans commentaire) | aucun (voir ci-dessus) | **RETIRÉ** (passe 3 bis) | Aucune requête par `endpoint` ; coût pur à chaque insertion. Il pèse 3,5 fois `idx_shp_checked_at` (1 032 kB) : c'est un gonflement structurel, voir « Surprises ». |
| service_health_incidents_kind_open_idx | 16 kB | 3 (32 lignes réelles) | `20260820100000_temoin_de_vie_sauvegardes.sql:213` | EF : `WHERE kind = $1 AND closed_at IS NULL ORDER BY opened_at DESC LIMIT` (24 719 appels) et `WHERE kind = $1 AND closed_at IS NULL LIMIT` (2 × 7 167) | GARDER | Correspondance exacte avec la requête la plus fréquente de la table. |
| idx_shi_ouverts | 16 kB | 3 | `20260817142739_service_health_probes.sql:46` | mêmes requêtes : l'index partiel des incidents ouverts, trié par `opened_at DESC`, les sert aussi | GARDER | Motif réel. Il recouvre en partie `kind_open_idx` (créé 3 jours après, avec `kind`), sans en être un doublon strict. |

### 8. Files d'attente et événements de notification (8)

L'envoi se fait **ligne par ligne, par déclencheur** (`tg_bug_report_outbox_dispatch`, `tg_cartography_outbox_dispatch`, etc. → `notify-event`), et l'EF relit la ligne **par `id`** (`WHERE id = $1`, visible dans `pg_stat_statements`). Deux crons balaient les files, et aucun ne peut prendre un index partiel `status = 'queued'` ou `'pending'`. Le rejeu `private.fn_outbox_rejouer` (cron `*/15`, SQL dynamique sur les 5 files) filtre `status = 'failed'`. La sonde `fn_healthcheck_notifications` (SQL dynamique sur toute table `%outbox%`) filtre `coalesce(status,'') not in ('sent','skipped') and created_at < now() - 15 min`. Les statuts présents en production : team `sent = 62, skipped = 4` ; lettre `sent = 12` ; bug `sent = 1` ; cartographie vide.

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| idx_task_notification_outbox_status | 16 kB | 2 | socle:51297 | `dispatch_task_notification_outbox` : `where o.dispatch_status = 'queued'` ; cron `fn_cron_reconcile_task_dispatch` (`*/5`) : `o.dispatch_status = 'sent'` | GARDER | Cette file-ci est bien relevée par statut. |
| bug_report_outbox_queued_idx | 16 kB | jamais analysée | `20260924201133_e14_signaler_un_probleme.sql:77` | aucun `status = 'queued'` lu | proposé, gardé (petite table) | Modèle « worker qui tire les queued » absent (envoi par déclencheur). |
| cartography_submission_outbox_queued_idx | 16 kB | ~ | `20260618182516_cartography_submissions.sql:74`, recréé `20260618234207_cartography_notify_wiring.sql:36` | idem | proposé, gardé (petite table) | idem |
| lettre_notification_outbox_queued_idx | 16 kB | ~ | socle:51433 | idem (index sur `status` lui-même, partiel `= 'queued'`) | proposé, gardé (petite table) | idem |
| idx_team_notification_outbox_pending | 16 kB | 44 | socle:51305 | aucun `status = 'pending'` lu (le rejeu lit `failed`, servi par `idx_team_notification_outbox_failed`) | proposé, gardé (petite table) | idem |
| idx_doc_perm_notify_events_type | 16 kB | ~ | socle:51025 | seulement `INSERT` et `update … set pgnet_request_id … where id = v_queue_row_id` (`fn_enqueue_document_permission_request_notification`) ; aucun lecteur (fonction, vue, front, EF) | proposé, gardé (petite table) | `event_type` jamais filtré ; l'historique par demande passe par `idx_doc_perm_notify_events_request`. |
| idx_library_request_notification_events_type | 16 kB | ~ | socle:51141 | idem (`fn_enqueue_library_request_notification`) | proposé, gardé (petite table) | idem (`…_events_request`) |
| gazette_sources_active_idx | 16 kB | 12 | socle:50717, et `20260702205146_gazette_sources.sql:26` (IF NOT EXISTS) | EF `gazette-monthly-build` : `.eq('active', true)` (`WHERE active = $1`) | GARDER | Correspondance exacte avec l'index partiel. |

### 9. Journaux (7)

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| catalog_audit_log_actor_idx | 32 kB | 1 686 (1 749 réelles, 1 seul acteur) | socle:50573 | les 9 fonctions qui écrivent ne font que des `INSERT` ; le front lit `WHERE action = $1 ORDER BY occurred_at DESC` ; la purge filtre `action = 'delete' and occurred_at < …`. Mais `fn_delete_my_account` pseudonymise l'acteur dans `library_unarchive_log`, `network_admin_cross_library_actions_log` et `network_administrator_audit`, **pas** dans `catalog_audit_log` (pas de FK sur `actor_id`) | GARDER (doute) | Pas de lecteur aujourd'hui. Le correctif RGPD probable (`UPDATE … WHERE actor_id = v_user_id`) en ferait le chemin naturel. Le seul scan observé vient de ma requête du 27/09 16:56. |
| catalog_audit_log_entity_idx | 96 kB | 1 686 | socle:50577 | aucun filtre `entity_type`/`entity_id` ; la restauration lit par la clé primaire (`fn_restore_deleted_draft` : `where id = p_audit_id`) | proposé, gardé (petite table) | Pas d'« historique d'une notice » câblé. |
| library_unarchive_log_record_idx | 16 kB | ~ | socle:51465 | `INSERT` (`fn_unarchive_transaction`) et RGPD `UPDATE … WHERE unarchived_by = …` ; `fn_check_unarchive_eligibility` ne lit pas ce journal | proposé, gardé (petite table) | Jamais lu par `(table_name, record_id)`. |
| ix_mvl_library | 16 kB | ~ | socle:51397 | `INSERT` seulement (`api.validate_membership`, `reject_membership`, `resubmit_membership`) ; aucun lecteur malgré la policy SELECT du staff | proposé, gardé (petite table) | Table écrite, jamais lue. |
| network_admin_cross_lib_log_critical_idx | 16 kB | ~ | socle:51581 | le digest (`notify-cross-library-digest/index.ts:172-178`) filtre une plage de `created_at` ; RGPD par `actor_user_id` | proposé, gardé (petite table) | `is_critical` jamais filtré. |
| network_administrator_audit_event_type_idx | 16 kB | 3 | socle:51589 | 9 fonctions en `INSERT` ; RGPD par `user_id`, `actor_user_id`, `target_user_id` | proposé, gardé (petite table) | Jamais lu par `event_type`. |
| idx_lph_axis | 16 kB | ~ | socle:51181 | aucun `FROM`, `JOIN`, `UPDATE` ni `DELETE` sur `library_profile_history` dans les fonctions (le `AND axis = p_axis` de `fn_propose_library_profile_change` vise la table des propositions) ; ni vue ni front | proposé, gardé (petite table) | Table écrite, jamais lue. |

### 10. Circulation, règlements, invitations (14)

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| reserva_item_workflow_v2_stage_idx | 16 kB | 17 | socle:51633 | crons `fn_expire_solicitada_reservations` (`workflow_stage = 'solicitada'`), `fn_expire_negotiation_timeout` et `fn_detect_no_show_reservations` (`workflow_stage IN (…)`) | GARDER | Motifs réels, horaires. |
| reserva_item_workflow_v2_pickup_idx | 16 kB | 17 | socle:51629 | `fn_detect_no_show_reservations` : `pickup_scheduled_for IS NOT NULL AND pickup_scheduled_for < now() - …` | GARDER | idem |
| reserva_linhas_v2_item_idx | 16 kB | 20 | socle:51649 | `fn_peb_search_exemplares` et `fn_v2_resolve_consulta_exemplar` : `rl.item_id = e.id AND rl.item_status = 'ativa'` | GARDER | Exact. |
| reserva_linhas_v2_bib_ref_status_idx | 16 kB | 20 | socle:51637 | aucun filtre sur `reserva_linhas_v2.bib_ref` (le seul `bib_ref =` voisin, `fn_v2_convert_reserva_linhas_to_emprestimo`, filtre `exemplares` : `e.bib_ref = v_line.bib_ref`) | proposé, gardé (petite table) | Reliquat de l'époque où les réservations se rattachaient par `bib_ref` ; elles se rattachent désormais par `item_id`. |
| consultas_locais_v2_archived_idx | 16 kB | 21 | socle:50617 | `api.library_archived_transactions` : `WHERE c.archived_at IS NOT NULL`, plus le filtre `library_id` du front | GARDER | Exact (index partiel). |
| interlibrary_loans_v2_archived_idx | 16 kB | 2 | socle:51373 | `api.peb_history_v1` : `WHERE ll.archived_at IS NOT NULL ORDER BY ll.archived_at DESC` | GARDER | Exact. |
| ill_digital_shares_state_idx | 16 kB | ~ | socle:51341 | front `LibraryDigitalSharesSection` : `(requester OR source) AND flux_state = ANY($3)` ; EF `notify-weekly-report` : `.in('flux_state', …)` | GARDER | Motifs réels. |
| idx_library_circulation_policy_sets_status | 16 kB | 2 | socle:51113 | `api.resolve_circulation_rule` et `fn_v2_extend_core` : `s.library_id = … AND s.is_active AND s.status = 'active'` | GARDER · faible | Prédicat résiduel ; `library_id` est le chemin naturel. |
| idx_library_circulation_policy_sets_effective_from | 16 kB | 2 | socle:51101 | idem : `(s.effective_from IS NULL OR s.effective_from <= …)` | GARDER · faible | idem |
| idx_library_circulation_policy_sets_metadata_gin | 24 kB | 2 | socle:51109 | `metadata` lu entière ou écrite, jamais `@>`/`?` | proposé, gardé (petite table) | Aucun opérateur GIN. |
| idx_library_circulation_policy_rules_metadata_gin | 24 kB | ~ | socle:51089 | idem | proposé, gardé (petite table) | idem |
| idx_library_circulation_policy_rules_applies_when_gin | 24 kB | ~ | socle:51085 | `applies_when` projeté (`get_library_circulation_policy_rules_ui`) ou écrit (`upsert_library_circulation_policy_rule`) | proposé, gardé (petite table) | idem |
| idx_library_regulation_documents_metadata_gin | 24 kB | ~ | socle:51121 | `metadata` projeté ou écrit ; le front filtre `library_id`, `is_active`, `publication_status`, `doc_kind` | proposé, gardé (petite table) | idem |
| idx_library_request_claims_open_window | 16 kB | 1 | socle:51129 | `fn_consume_library_request_claim` et `fn_get_library_request_claim_context` : `c.claim_purpose = 'library_request' and c.used_at is null and c.expires_at > now()` ; purge (cron) : `used_at is null and expires_at < now() - …` | GARDER | Exact (index partiel). |

### 11. Gouvernance, réseau, cartographie, divers (18)

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| authority_duplicate_reports_status_idx | 16 kB | ~ | `20260821130001_signaler_un_doublon_d_autorite.sql:66` | `list_authority_reports` : `WHERE r.status = 'open'` ; graines `fn_conv_lot_autorite_*` : `r.status = 'open'` | GARDER | Motif réel. |
| catalog_duplicate_reports_status_idx | 8 kB | ~ | `20260821020002_arbitrage_doublons_reserve_coordination.sql:119` | `list_duplicate_reports` : `WHERE r.status = 'open'` | GARDER | idem |
| idx_catalog_batches_status | 16 kB | 1 | socle:50969 | front `CatalogacaoPage.jsx:105` : `.eq('status', 'open')` avec compte exact (321 appels) | GARDER | Exact. |
| circles_directory_idx | 16 kB | 2 | socle:50609 | `api.circles_directory_v1` : `WHERE is_open = true AND status = 'ativo'`, et même prédicat dans la policy RLS `circles_select` | GARDER | Exact (index partiel). |
| oai_opening_requests_status_idx | 16 kB | 4 | socle:51613 | `fn_oai_harvestable_libraries` : `kind = 'network' AND status = 'open'` ; cron `fn_oai_resolve_expired_votes` : `status = 'pending_vote' AND vote_deadline <= now()` | GARDER | Motifs réels. |
| bug_reports_open_idx | 16 kB | ~ | `20260924201133_e14_signaler_un_probleme.sql:50` | `api.fn_bug_report_list` : `WHERE r.status = 'open' ORDER BY r.created_at` | GARDER | Exact. |
| cartography_submissions_pending_idx | 16 kB | ~ | `20260618182516_cartography_submissions.sql:51` | `api.fn_cartography_submission_list` : `WHERE s.status = 'pending' ORDER BY s.created_at` | GARDER | Exact. |
| idx_library_requests_created_at | 16 kB | ~ | socle:51145 | front `RedePage.jsx:208` : `.order('created_at', {ascending:false})` (54 appels) | GARDER | Exact. |
| idx_ulm_pending_removal_until | 16 kB | 35 | socle:51309 | cron horaire `fn_cron_team_pending_removal_complete` : `pending_removal_until <= now() AND status = 'pending_removal' … ORDER BY pending_removal_until` | GARDER | Exact. |
| idx_network_staff_active_role | 16 kB | 1 | socle:51217 | `api.fn_gazette_broadcast` : `from network_staff ns where ns.is_active` ; `fn_current_user_network_role` : `user_id = auth.uid() and is_active` | GARDER · faible | Colonne de tête filtrée ; table d'une ligne. |
| idx_network_staff_dashboard | 16 kB | 1 | socle:51221 | `fn_current_user_can_access_network_dashboard` : `user_id = auth.uid() and is_active = true and can_access_network_dashboard = true` | GARDER · faible | Les deux colonnes filtrées ; `user_id` est le chemin naturel. |
| assembleias_status_idx | 16 kB | ~ | socle:50521 | fonctions par `id` ; `fn_lettre_draft_create` filtre `scheduled_at` ; front `AssembleiasTab.jsx:68` : `assembleias_v1` trié par `created_at.desc` ; la vue projette `status` sans filtre | proposé, gardé (petite table) | `status` jamais filtré. |

Les SUPPRIMER divers qui restent :

| index | taille | lignes | origine | motif de requête trouvé | verdict | raison |
|---|---|---|---|---|---|---|
| cartography_entries_categorie_idx | 16 kB | 187 | `20260618142238_cartography_schema.sql:70` | toute lecture passe par `private.fn_cartography_public_rows()` et `…_network_rows()` (SQL, SECURITY DEFINER, SET : non insérables en ligne) sous `api.cartography_public_v1` et `…_network_v1` ; accès directs par `id` (`fn_cartography_get_for_edit` : `WHERE ce.id = p_entry_id`) | proposé, gardé (petite table) | Inaccessible, même schéma que les MV. |
| cartography_entries_slug_idx | 16 kB | 187 | même fichier, l.72 | idem ; aucune recherche par `slug` (index non unique) | proposé, gardé (petite table) | idem |
| idx_library_requests_library_name_lower | 16 kB | ~ | socle:51149 | personne n'écrit `lower(library_name)` : 0 fonction, 0 vue, aucune migration depuis le socle, rien côté front ni EF | proposé, gardé (petite table) | Expression écrite par personne. |
| fonds_export_runs_status_idx | 16 kB | 1 | socle:50705 | seule l'EF `export-fonds-bundle` touche la table (insertion, mise à jour par `id`) | proposé, gardé (petite table) | `status` jamais filtré. |
| idx_auth_rate_limits_blocked_until | 8 kB | 0 | socle:50733 | les EF (`_shared/core/rate-limit.ts:51-66`, `login/index.ts:117-218`) lisent par la clé primaire `(kind, key)` et comparent `blocked_until` en TypeScript ; aucune purge ; dans les migrations, `blocked_until` n'apparaît qu'au socle | proposé, gardé (petite table) | Colonne jamais filtrée en SQL. |
| idx_reader_card_tokens_hash | 16 kB | ~ | socle:51253 | `api.resolve_reader_card` : `WHERE token_hash = v_hash ORDER BY (status = 'active') DESC` (sans prédicat de statut) ; l'unique **`reader_card_tokens_token_hash_key (token_hash)`** existe | **RETIRÉ** (passe 3 bis) | Doublon fonctionnel strict de l'index unique (que la détection du périmètre ne voit pas, les prédicats partiels différant). |

---

### Surprises

1. **Le catalogue relit toute la MV à chaque page.** Les enveloppes SECDEF (SECU-MV-FIX2, 15/06) font de chaque lecture de `catalog_list_*_v1`, `catalog_works_v1`, `catalog_facets_v1` ou `catalog_search_ids_v1` un parcours complet de la MV : 20 828 parcours séquentiels de la MV publique en 25 jours, dont une bonne part vient de la sonde `health-probe` toutes les 5 min. Le coût croît avec le nombre de notices, par construction. C'est le mécanisme de fond de **B27** (`catalog_works_v1` au-delà des 3 s du rôle anon). Supprimer les 19 index ne change rien à ce coût.
2. **`search_catalog_v1` ne peut utiliser aucun de ses 5 index trigramme.** La clause `OR EXISTS (SELECT 1 FROM unnest(v_tokens) … ~ ('(^|\s)'‖tok))` interdit le BitmapOr sur `authors`, `author_name_aliases` et les deux MV. S'y ajoute pour `sort_name` le décalage d'expression dû au `COALESCE`. Elle coûte déjà **177 ms en moyenne** (40 appels) pour 2 600 notices et 1 500 autorités. Réécrire la branche en un seul motif regexp (`~ '(^|\s)(tok1|tok2)'`, que gin_trgm sait indexer) débloquerait 4 index gardés, et 5 si l'on retire le `COALESCE`.
3. **`idx_shp_endpoint`** : 3,48 Mo pour 36 277 lignes, soit 3,5 fois `idx_shp_checked_at` (1,01 Mo) et 3,4 fois la clé primaire (1,03 Mo). Les insertions arrivent au milieu de l'index (5 points d'insertion, tri DESC), donc les pages se coupent en deux ; la purge à 30 jours vide l'autre bout. C'est un gonflement structurel, pour un index que rien ne lit et que chaque tour de sonde maintient.
4. **`reader_card_tokens`** : l'index partiel sur `token_hash` double l'index unique ; la redondance échappe à la requête de périmètre parce que leurs prédicats diffèrent. D'autres paires partiel/non partiel du même genre peuvent exister ailleurs.
5. **Trou RGPD probable** : `fn_delete_my_account` pseudonymise l'acteur dans trois journaux mais pas `catalog_audit_log.actor_id` (sans FK). C'est la raison du GARDER sur `catalog_audit_log_actor_idx`.
6. **Colonnes héritées** `holder_library`, `owner_library`, `partner_source` et `mutualization_status` (texte, sur `books` et `book_drafts`) : encore écrites par deux déclencheurs et trois RPC, encore affichées au niveau 3 du formulaire, jamais filtrées. Leurs 7 index sont du coût pur.
7. **Index pensés pour des fonctionnalités jamais câblées** (juin, lot audio P0) : `idx_authors_external_ids` (recherche par MBID) et `idx_bdr_acoustid_id` (recherche par AcoustID). Les usages réels d'`external_ids` (enrichissement Wikidata, LC, IdRef du 26-27/09) prennent des formes que le GIN ne sert pas.
8. `fn_sync_publisher_id_on_publish` (déclencheur à chaque publication de notice) cherche l'éditeur par `lower(p.name) = lower(trim(NEW.editora))`, et **aucun index ne la sert** : c'est un parcours séquentiel de `publishers` à chaque publication. Le GIN trigramme sur `name` brut, lui, ne sert personne.
9. `digital_assets` : le lien historique par `bib_ref` n'est plus filtré nulle part (tout passe par `book_id`).
10. Aucun des 66 SUPPRIMER n'a pris le moindre scan pendant l'enquête (le maximum relu à 17:00 UTC vaut 0). Le seul compteur que j'ai fait bouger, `catalog_audit_log_actor_idx`, figure parmi les GARDER.



## 6. Après — relevé du 27/09 en production

**Déploiement.** Les cinq migrations sont inscrites par la CI (`created_by` vide) : `20260927180000` à 17 h 34 UTC, `…180030`, `…180100` et `…180200` à 17 h 52, `…180300` à 18 h 10. Le premier essai de la passe 3 bis (run #1394, 18 h 02) a échoué : son `DROP INDEX` sur `books` a attendu le `pg_dump` de la sauvegarde hebdomadaire « flux long » (dimanche 20 h, heure de Paris), connecté à 18 h 01 min 28 s, puis a été annulé au bout du délai de 2 minutes (`57014`). Transaction annulée, rien d'appliqué ; le run suivant l'a appliquée une fois la sauvegarde terminée. Diagnostic : `postgres_logs` (« still waiting for AccessExclusiveLock… Process holding the lock: 2793652 ») → `supavisor_logs` (connexion de ce processus à 18:01:28) → timer `anarbib-backup-long` et journal `anarbib-bg2.sh` (fin à 20 h 06).

**Avis de performance** (recalculés) : `multiple_permissive_policies` **25 → 0** ; `unindexed_foreign_keys` **38 → 17** (les assumées de B21) ; `unused_index` 284 → 281 (22 retirés, 21 index de FK posés qui n'ont pas encore servi, quelques compteurs qui ont bougé). Hors périmètre : `no_primary_key` (8 — les tables de sauvegarde `conv_backup.*` du 20/08 et les deux tables de l'import BLMF) et `auth_db_connections_absolute` (réglage du service Auth, geste de tableau de bord).

**Qui voit quoi : inchangé.** Empreinte md5 des clés visibles, table par table, pour `anon` et chacun des 20 comptes réels (21 identités × 25 tables) : identique avant, après la passe 1 et après la passe 1 bis.

**Coût de lecture** — `count(*)`, meilleur de trois :

| identité | books avant → après | exemplares avant → après | authors avant → après |
|---|---:|---:|---:|
| anon | 88,5 → 90,3 ms | 94,6 → 95,8 ms | 191,7 → 195,9 ms |
| admin réseau | 39,0 → **1,4 ms** | 39,5 → **0,9 ms** | 0,6 → 0,6 ms |
| bibliothécaire | 208,7 → **89,4 ms** | 168,7 → **95,8 ms** | 0,6 → 0,9 ms |
| lecteur·rice | 208,0 → **89,5 ms** | 176,7 → **100,0 ms** | 194,6 → 195,2 ms |

Entre la passe 1 et la passe 1 bis (18 minutes), le staff a payé l'ordre « publique d'abord » : admin `books` 89 ms, staff `authors` 193 ms — mesuré, puis corrigé. Le coût anonyme et le coût lecteur d'`authors` ne bougent pas : c'est celui de la lecture publique elle-même (`fn_library_visible_to_caller` par exemplaire), l'objet de **B32**.

**Index.** `books` : 27 index (6,5 Mo) → **20 (5,1 Mo)** ; `book_drafts` : 16 → 13 (un index de FK posé, quatre retirés) ; `service_health_probes` : 5,6 → **2,1 Mo** d'index. 21 index de clé étrangère posés, 22 retirés.

**Journaux.** Aucune erreur applicative pendant la fenêtre de déploiement : toutes les erreurs Postgres viennent du rôle `postgres` (diagnostics de cette passe et des sessions voisines) ; aucun refus RLS, aucun `permission denied` pour `anon` ou `authenticated` ; réponses REST uniquement 200/201/204.

## 7. Écart tracé à `DOC-DEPLOY-4`

Les cinq migrations de B10 enfreignent `DOC-DEPLOY-4` (« une migration s'horodate à la seconde UTC réelle, jamais à l'heure ronde »), sur ses deux règles bloquantes : `20260927180000` est à l'heure ronde, et **les cinq** ont été datées dans le futur — 18 h UTC, pour des fichiers écrits entre 16 h 30 et 17 h 10. Les créneaux avaient été choisis « franchement à l'écart » pour éviter une collision entre sessions : c'est précisément la pratique que la doctrine interdit, parce qu'elle revient à choisir de mémoire dans quelques créneaux par jour.

**Ce que l'écart a coûté.** Aucune collision (contrôle `uniq -d` des versions à chaque push). Une migration voisine, `20260927164619` (remplacement de `publish_book_draft`), est tombée dans la fenêtre : elle trie avant les miennes en CI et s'applique après la passe 1 en production. Elle ne touche ni policy ni index du périmètre de B10 : l'ordre est sans effet ici. **Pourquoi ne pas renommer** : `20260927180000` était déjà inscrite en production sous cette version, et les runs en file allaient appliquer les suivantes sous leur nom ; un renommage aurait fait échouer tous les déploiements suivants (« Remote migration versions not found in local migrations directory »).

**Pourquoi rien ne l'a arrêté.** Le hook `.githooks/pre-commit` porte ces règles, mais n'est actif que dans le checkout Windows (`core.hooksPath = .githooks`) : ni `~/anarbib` ni ses worktrees WSL, où travaillent les sessions depuis le 21/08, ne le règlent, et son lanceur appelle `powershell.exe`. Mesure du 27/09 : **15 des 129 migrations** versées depuis le 31/08 sont à l'heure ronde. I9 avait été clos le 30/08 « par une règle, pas par une correction » : la règle ne tourne pas là où l'on travaille. Ouvert en **I28**.
