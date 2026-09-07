# CADRAGE — Un rejeu depuis zéro fidèle à la production : le privilège par défaut se retire avant le socle

*Trace de cadrage (`docs/journal/cadrages/`), non normative. Ce qui fait foi : REGISTRE `DOC-GRANT-1`, `DOC-GRANT-2` ; backlog `I17` (dont cette page est la « spec », décision D7 du 06/09 : nous l'écrivons, on la propose à Bastien après la fusion de la PR #28).*

- **Date :** 7 septembre 2026, matin. Session `reprise-pr28-revoke-anon-2026-09-06`.
- **Pour qui :** la personne qui fera `I17` — Bastien (`ASR2026`) si elle prend le morceau, nous sinon. Écrite pour être exécutée sans cette session.
- **Ce qu'elle ne fait pas :** rien en production. La production est saine (constat du 06/09) ; tout ce qui suit concerne le **chemin de rejeu** — la pile auto-hébergée, et le banc CI par ricochet.
- **Toutes les mesures ci-dessous sont datées du 07/09** : production interrogée en lecture seule (`uflwmikiyjfnikiphtcp`), image `supabase/postgres:17.6.1.136` lancée à vide dans un conteneur jetable puis détruit, dépôt au commit `fb64c996`.

---

## 1. Le problème, en une phrase mesurée

Le socle `20260510000000_baseline_live` est un `pg_dump` : il porte **163 `GRANT … TO anon`** sur des fonctions et **zéro `REVOKE … FROM anon`**. Sur une image Supabase, `pg_default_acl` accorde `EXECUTE` à `anon` sur **toute fonction créée dans `public`**, avant même que le socle ne s'exécute. Les fonctions du socle naissent donc ouvertes ; les 163 `GRANT` ne rouvrent rien, ils sont redondants ; et rien ne ferme les autres. En production, **595 des 676** fonctions de `public` sont fermées à `anon`. Un rejeu depuis zéro les ouvre toutes, et les migrations du 29/08 — les premières à vérifier l'ACL de ce qu'elles remplacent — lèvent. Le banc CI ne le voit pas parce qu'il crée sa base depuis `template0`, où `pg_default_acl` est vide (`DOC-GRANT-2`).

## 2. Ce que l'image pose à vide (mesuré)

Conteneur `supabase/postgres:17.6.1.136` lancé avec `POSTGRES_PASSWORD` seul, interrogé après ses scripts d'initialisation :

| Rôle | superuser | bypassrls | createrole | createdb |
|---|---|---|---|---|
| `postgres` | **non** | oui | oui | oui |
| `supabase_admin` | oui | oui | oui | oui |
| `anon`, `authenticated`, `service_role`, `authenticator` | non | (`authenticated`, `service_role` : oui) | non | non |

`pg_default_acl` de la base `postgres`, schéma `public`, objets **fonctions** :

| Rôle propriétaire du défaut | ACL par défaut |
|---|---|
| `postgres` | `{postgres=X, anon=X, authenticated=X, service_role=X}` |
| `supabase_admin` | `{postgres=X, anon=X, authenticated=X, service_role=X}` |

Les mêmes deux lignes existent pour les tables (`arwdDxtm` à `anon`) et les séquences (`rwU`). `supabase_admin` porte en plus des défauts pour `graphql`, `graphql_public`, `extensions`, `realtime` ; `postgres` pour `storage`.

Deux faits qui décident de la suite, vérifiés à blanc (`BEGIN … ROLLBACK`) :
- **`postgres` peut `CREATE EXTENSION pg_cron`** dans l'image (extension de confiance) ;
- **`postgres` ne peut pas modifier le défaut de `supabase_admin`** (`permission denied to change default privileges`). Il peut modifier le sien.

## 3. Qui applique les migrations, et sous quel défaut

| Chemin | Rôle qui applique | Ligne de `pg_default_acl` qui s'applique | `anon` à la naissance d'une fonction du socle |
|---|---|---|---|
| Production (Supabase hébergé, `supabase db push`) | `postgres` | `postgres` | non concerné : le socle *est* le dump de la prod, les fonctions existaient déjà |
| Banc CI (`scripts/ci/run-sql-suites.sh`, image `public.ecr.aws/supabase/postgres:17.6.1.084`) | `postgres` (`PGUSER` par défaut) | **aucune** : base créée `TEMPLATE template0` | **fermée** — d'où le vert |
| Pile auto-hébergée (`deploy/scripts/run-migrations.sh`, `apply-pending-migrations.sh` de la PR #28) | **`supabase_admin`** (premier candidat de la boucle) | `supabase_admin` | **ouverte** — d'où le rouge de Bastien |

Le banc CI prouve une chose que le 17/08 n'avait pas vue : **les 308 migrations s'appliquent entièrement sous `postgres` non superutilisateur, sur cette image** — extensions, rôles et objets compris. Le motif « `postgres` n'est pas superutilisateur » qui a fait choisir `supabase_admin` dans `run-migrations.sh` ne tient pas pour les migrations ; il tient pour `01-roles.sh` (les rôles réservés comme `authenticator` exigent un superutilisateur), et c'est déjà là qu'on l'utilise.

Deux différences de trajectoire, à connaître avant de choisir :
- **Le socle rétablit lui-même le défaut de `postgres` à sa fin** (lignes 61206-61218 : `ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon"`, idem séquences). Donc, quel que soit le nettoyage fait avant le socle, une fonction créée par `postgres` **après** le socle naît ouverte à `anon` jusqu'à `20260831105114` (`DOC-GRANT-1`, qui retire `anon` de la ligne `postgres`). C'est exactement la trajectoire de la production et du banc CI.
- **Rien ne touche jamais la ligne `supabase_admin`** : ni le socle, ni `20260831105114`. Sous ce rôle, une fonction naît ouverte à `anon` avant *et* après le 31/08, pour toujours.

## 4. Ce que la production a réellement ouvert à `anon` (mesuré, 07/09)

133 fonctions des schémas `public`, `api`, `private`, `ingest` sont exécutables par `anon`. Elles se répartissent en deux classes qui ne se réparent pas de la même façon.

**Classe A — `anon` figure dans l'ACL** (98 fonctions : 76 `public`, 19 `api`, 3 `private`). Pour **86** d'entre elles, un `GRANT … TO anon` écrit existe dans le dépôt (socle ou migration nominative) : le rejeu les rouvrira quoi qu'il arrive. Pour **12**, aucun `GRANT` n'est écrit nulle part : elles ne sont ouvertes que par le privilège par défaut du moment de leur création.

| Fonction (`public.`) | Créée par | DEFINER | Dans `T10` | Usage relevé |
|---|---|---|---|---|
| `fn_book_restricted_pdf_state` | socle, recréée | oui | oui | front (2 fichiers) |
| `fn_book_restricted_pdf_state_for_current_user` | socle, recréée | oui | oui | front (2 fichiers) |
| `fn_current_user_is_member_of_holding_library` | `20260821000000` | oui | oui | interne |
| `fn_reading_notes_enabled_for` | `20260804113000` | oui | oui | interne |
| `fn_book_drafts_serial_id_requires_periodico` | `20260827163600` | non | — | trigger |
| `fn_books_serial_id_requires_periodico` | `20260827163000` | non | — | trigger |
| `fn_serial_issue_key` | `20260827163000` | non | — | interne |
| `fn_serials_autoslug` | `20260827163000` | non | — | trigger |
| `fn_serials_filiation_no_cycle` | `20260827163000` | non | — | trigger |
| `fn_serials_filiation_symmetry` | `20260827163000` | non | — | trigger |
| `fn_title_sans_volume` | `20260904170000` | non | — | interne |
| `fn_volume_rank` | `20260904170000` | non | — | interne |

Les quatre DEFINER sont dans la liste nommée `T10` de `tests/sql/grants_herites_tests.sql` — **le test atteste qu'elles sont ouvertes, mais aucune ligne du dépôt ne les ouvre**. Sur un rejeu qui fermerait le défaut sans autre geste, `T10` deviendrait rouge pour « attendue mais fermée ». C'est le seul endroit où le rejeu et la prod divergent *à cause du dépôt* et non de l'image.

**Classe B — `anon` n'est pas dans l'ACL, la fonction est ouverte par `PUBLIC`** (35 fonctions) : `=X` explicite sur 10 RPC de circulation de `api` (`advance_consulta`, `create_loan_at_counter`, `return_loan_total`…), 17 helpers et triggers d'`ingest`, 5 de `public` (`fn_assert_*`, `fn_conv_est_non_agent`, `fn_title_lisible_sans_volume`) ; ACL nulle (défaut natif de PostgreSQL) sur `api.extend_loan_item_as_library`, `api.renew_my_loan_item`, `private.fn_book_work_id`. Toutes SECURITY INVOKER : sous `anon`, la RLS fait son travail, et le lint 0028 ne les voit pas. **Hors périmètre d'`I17`** — un `pg_default_acl` n'y change rien — mais une RPC de prêt appelable par un visiteur anonyme, même si elle refuse ensuite, est une surface qu'on ne laisse pas par oubli : backlog `B22`.

## 5. La règle à obtenir

> **Après un rejeu complet sur une image Supabase, l'ensemble des fonctions exécutables par `anon` est le même qu'en production**, à la seule différence des fonctions qui n'existent que d'un côté. Les trois migrations du 29/08 passent sans `REVOKE` nominatif ajouté. `T10` est vert.

Ce qui rend la règle atteignable sans réécrire le socle : **le socle est fidèle par construction dès que rien n'accorde `anon` à la création**. Les 163 `GRANT` explicites rouvrent alors exactement ce que la prod ouvrait en mai ; les migrations suivantes rejouent l'histoire — ouvertures par défaut jusqu'au 31/08 comprises, puisque le socle rétablit lui-même ce défaut pour `postgres`.

## 6. Le choix : deux options, une recommandée

### Option A (recommandée) — la pile auto-hébergée applique les migrations sous `postgres`, comme la production et la CI

1. **Dans `deploy/init-db/01-roles.sh`** (il s'exécute en `supabase_admin` au premier démarrage d'un volume vierge, *avant* tout rejeu — c'est le bon endroit, celui où Bastien a mis `pg_cron`) : retirer `anon` du défaut **des deux rôles**, pour les fonctions, **sans jamais vider une entrée** (une entrée `pg_default_acl` vide est supprimée par Postgres et le défaut natif `PUBLIC=X` revient — c'est le piège de `DOC-GRANT-1`) :
   ```sql
   ALTER DEFAULT PRIVILEGES FOR ROLE postgres       IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;
   ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;
   ```
   puis vérifier, dans le même script, que les deux entrées existent encore et ne contiennent plus `anon=` (le bloc `DO` de `20260831105114` est le modèle). Le rôle `supabase_admin` est traité aussi pour que la ligne ne reste pas une porte dérobée : rien ne doit créer d'objet sous ce rôle, mais s'il en crée un, il naît fermé.
2. **`run-migrations.sh` et `apply-pending-migrations.sh`** : mettre `postgres` en premier candidat, `supabase_admin` en repli **signalé** (un message qui dit sous quel rôle on applique, et pourquoi le premier a été refusé — pas un silence). Les objets sont alors possédés par `postgres` comme en prod ; les blocs de vérification qui tolèrent `supabase_admin` (`20260830090000`, `20260830130000`, `20260902100917`, ajoutés par la PR #28) deviennent sans objet, et peuvent rester.
3. **Ne rien changer aux migrations.** Les trois `REVOKE` nominatifs de la PR #28 restent : redondants, inoffensifs, et ils disent ce qu'on attend.
4. **Le socle rétablit le défaut de `postgres` à sa fin** : c'est voulu, c'est la prod. `20260831105114` le referme en son temps.

Pourquoi A : c'est la seule option qui donne **la même trajectoire** que la prod et la CI, rôle compris ; elle supprime en même temps la seconde divergence relevée le 06/09 (objets possédés par `supabase_admin`) ; et le banc CI prouve déjà que `postgres` suffit pour les 308 migrations sur cette image.

Ce qu'elle demande de vérifier, et c'est l'essentiel de l'expérience du §7 : que la base `postgres` de l'image (celle que la pile utilise, avec ses extensions et ses défauts posés par l'init) se comporte comme la base `template0` du banc pour un `postgres` non superutilisateur. Le seul point où ça peut différer : une migration qui exigerait un superutilisateur **et** que le banc ne rencontre pas parce que `template0` n'a pas l'objet. Le rejeu le dira à la première erreur.

### Option B — garder `supabase_admin`, et rejouer à la main ce que le socle fait pour `postgres`

Même retrait avant le socle ; puis, **après** le socle, rétablir `anon` sur la ligne `supabase_admin` (pour reproduire les naissances ouvertes de mai à août) et le retirer au moment de `20260831105114` — c'est-à-dire modifier cette migration pour qu'elle traite aussi `supabase_admin`. Deux gestes de plus, un rôle propriétaire qui n'est pas celui de la prod, et une migration du dépôt qui se met à parler d'un rôle que la prod n'utilise pas. Écartée sauf si A casse pour une raison qu'on ne peut pas lever.

### Dans les deux cas — les 12 fonctions sans `GRANT` écrit

Elles ne sont pas un problème de rejeu tant que le défaut est rétabli après le socle (elles naissent ouvertes, comme en prod). Elles sont un problème de **doctrine** : `DOC-GRANT-1` dit qu'une ouverture est un acte écrit. Une migration à part, hors `I17`, doit trancher pour chacune : `GRANT EXECUTE … TO anon` explicite si l'ouverture sert (les deux `fn_book_restricted_pdf_state*` sont appelées par le front, à confirmer sous session anonyme ; les quatre DEFINER sont dans `T10`), `REVOKE` sinon (les six triggers et helpers de périodiques et de tomes n'ont aucune raison d'être appelables par `anon` — mais **chercher les vues et les policies avant** : une vue `security_invoker` appelle sous le rôle du lecteur, REGISTRE « avant un REVOKE, chercher les vues »). Item `B22`, avec la classe B.

## 7. L'expérience qui tranche (une soirée, aucun risque)

Sur une machine avec Docker, dépôt à jour, **sans** la PR #28 (pour mesurer l'état de `main`) puis **avec** (pour mesurer ce que la PR change) :

1. Volume vierge ; `01-roles.sh` modifié selon A.1 ; `run-migrations.sh` modifié selon A.2. `docker compose up -d db`, attendre `pg_isready`, puis rejeu complet. **Attendu** : 308 migrations vertes, dont les trois du 29/08 sans `REVOKE` ajouté. **Si rouge** : noter la migration et le message exact ; si c'est un besoin de superutilisateur, le nommer et **seulement alors** considérer B.
2. Dans la base rejouée, relever la liste des fonctions exécutables par `anon` :
   ```sql
   select n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname in ('public','api','private','ingest') and p.prokind='f'
     and has_function_privilege('anon', p.oid, 'EXECUTE') order by 1;
   ```
   La même requête en production (lecture seule). **Attendu** : la différence symétrique ne contient que des fonctions absentes d'un côté (`\dx`, objets de test). Toute autre ligne est un défaut du dépôt, à traiter par une migration nominative — pas par un réglage du rejeu.
3. `tests/sql/grants_herites_tests.sql` sur la base rejouée : `T8` à `T11` verts, `T10` en particulier.
4. Compter `pg_default_acl` : les lignes `postgres`/`public`/`f` et `supabase_admin`/`public`/`f` existent, sans `anon=` (l'entrée `postgres` a été rétablie par le socle puis refermée par `20260831105114` — vérifier que c'est bien le cas, c'est la preuve que la trajectoire est la bonne).
5. Consigner les quatre résultats dans `docs/journal/operations/` (une note datée), et fermer `I17` sur ce constat, pas sur le code.

## 8. Ce que ça change ailleurs

- **`I18` (un rejeu CI sur image réelle)** devient bon marché : le service `sql-tests` lance déjà l'image ; il suffit d'un second job qui rejoue les migrations **dans la base `postgres`** du service au lieu d'en créer une depuis `template0`, avec A.1 appliqué avant. Rouge = un contributeur extérieur cassera au même endroit.
- **`I19` (`pg_cron`)** : l'expérience du §7 le vérifie au passage — `postgres` peut créer l'extension, l'init de la PR #28 doit s'arrêter si ça échoue (pas de `if` silencieux).
- **`deploy/README.md`** : dire en une phrase que la pile applique les migrations sous `postgres` comme la production, et pourquoi `01-roles.sh` reste en `supabase_admin`.
- **`DOC-GRANT-1`** ne change pas ; cette page en est l'application au chemin de rejeu. Si l'expérience confirme A, une ligne `DOC-GRANT-2` « corollaire » suffit au REGISTRE.

## 9. Ce qui est proposé à Bastien, et ce qui reste à nous

Après la fusion de la PR #28 (décision D7, 06/09) : lui proposer les points A.1 et A.2 avec cette page, parce que `01-roles.sh` est déjà l'endroit qu'il a choisi pour `pg_cron` et que le rejeu complet est son terrain. L'expérience du §7 peut être faite par lui ou par nous ; la comparaison avec la production (§7.2) demande un accès en lecture à la prod, donc elle est à nous. `B22` est à nous.
