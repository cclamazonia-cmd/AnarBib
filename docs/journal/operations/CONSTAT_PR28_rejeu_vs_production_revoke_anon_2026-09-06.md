# CONSTAT — PR #28 : la production est saine, c'est le rejeu depuis zéro qui ment

*Trace non normative (`docs/journal/operations/`). Ce qui fait foi : `REGISTRE_decisions.md` → `DOC-GRANT-2` (§0), inscrit le même jour.*

- **Date :** 6 septembre 2026, après-midi.
- **Session :** `reprise-pr28-revoke-anon-2026-09-06` (reprise sur fiche `REPRISE_claude_code_2026-09-06_PR28_1.md`).
- **Objet :** la PR #28 (`codeberg.org/anarbib/anarbib/pulls/28`, Bastien — compte `ASR2026`, **première contribution extérieure au projet**) ajoute des `REVOKE … FROM public, anon` à trois migrations du 29/08. Question posée : la production porte-t-elle le trou que ces `REVOKE` referment ?
- **Réponse courte : non.** Rien n'a été appliqué en production. Le défaut est celui du **chemin de rejeu depuis zéro**, et il est structurel — pas propre à ces trois migrations.
- **Rien n'a été écrit en production, aucun commentaire n'a été posté sur la PR.** Tout ce qui suit est lecture seule (MCP `execute_sql`, `get_advisors`) et lecture du dépôt.

---

## 1. Ce que la PR change réellement sur les migrations

Le diff (`pulls/28.diff`, commit `81117888a8`, 06/09 13:53) ne touche les trois migrations que pour y ajouter, juste avant le bloc de vérification, **deux fonctions** :

| Migration | Ligne ajoutée |
|---|---|
| `20260829060000_supprimer_un_run_ne_laisse_pas_son_lot` | `revoke execute on function public.fn_import_delete_run(bigint) from public, anon;` + `grant … to authenticated;` |
| `20260829100000_la_biblio_de_destination_ne_se_choisit_pas_par_accident` | idem sur `public.publish_book_draft(bigint)` |
| `20260829160000_destination_lisible_et_regle_unique` | idem sur `public.publish_book_draft(bigint)` |

Les trois migrations portent déjà, en fin de fichier, un bloc `DO $verif$` qui **lève** si `information_schema.routine_privileges` montre `anon` ou `PUBLIC` sur la fonction remplacée. C'est ce bloc que Bastien a vu lever au rejeu, et c'est lui qui a dicté ses `REVOKE`. (La troisième migration crée aussi `fn_book_draft_destination_library(bigint)` — déjà fermée à anon dans le fichier d'origine — et la vue `v_book_draft_destination`.)

## 2. Mesures en production (`uflwmikiyjfnikiphtcp`, lecture seule)

### 2.1 Les deux fonctions

```sql
select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid), p.prosecdef, p.proacl::text,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('public', p.oid, 'EXECUTE')        as public_exec
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.proname in ('fn_import_delete_run', 'publish_book_draft');
```

| Fonction | SECURITY DEFINER | ACL | anon | authenticated | PUBLIC |
|---|---|---|---|---|---|
| `public.fn_import_delete_run(p_run_id bigint)` | oui | `{postgres=X, authenticated=X, service_role=X}` | **non** | oui | **non** |
| `public.publish_book_draft(p_draft_id bigint)` | oui | `{postgres=X, authenticated=X, service_role=X}` | **non** | oui | **non** |

Une seule surcharge de chaque. **Le trou n'existe pas en production.**

### 2.2 Le paysage `anon`, pour situer

```sql
select n.nspname, count(*) total,
       count(*) filter (where has_function_privilege('anon', p.oid, 'EXECUTE')) anon_exec,
       count(*) filter (where p.prosecdef) secdef,
       count(*) filter (where p.prosecdef and has_function_privilege('anon', p.oid, 'EXECUTE')) secdef_anon
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','api','private','ingest') and p.prokind = 'f' group by 1;
```

| Schéma | Fonctions | exécutables par anon | dont SECURITY DEFINER |
|---|---|---|---|
| `public` | 676 | 81 | 25 |
| `api` | 188 | 31 | 3 |
| `private` | 8 | 4 | 4 |
| `ingest` | 34 | 17 | 0 |

Les 25 + 3 = **28** SECURITY DEFINER ouvertes à anon sont exactement la liste nommée du `T10` (`AUDIT_execute_anon_2026-08-30.md`). L'advisor « security » du jour (463 lints, 0 ERROR) le confirme : lint `anon_security_definer_function_executable` = 28, nom pour nom ; `fn_import_delete_run` et `publish_book_draft` n'apparaissent que dans le lint `authenticated` (0029), comme depuis le 20/08. Aucun lint nouveau côté anon depuis le constat du 30/08. (Les 17 fonctions d'`ingest` exécutables par anon sont des helpers/triggers non DEFINER d'un schéma non exposé par PostgREST — hors sujet ici, noté pour mémoire.)

Les grants de tables d'`anon` ont aussi été relevés (`information_schema.role_table_grants`) : le tableau est celui connu — vues `api.*_public_*`, tables de référentiel en `SELECT`, et les tables où anon porte encore `INSERT/UPDATE/DELETE` sous RLS (héritage documenté à `20260829140000`). Rien n'y concerne les objets des trois migrations.

### 2.3 Le privilège par défaut

```sql
select r.rolname, n.nspname, d.defaclobjtype, d.defaclacl::text
from pg_default_acl d join pg_roles r on r.oid = d.defaclrole left join pg_namespace n on n.oid = d.defaclnamespace;
```

| Rôle | Schéma | Objets | ACL par défaut |
|---|---|---|---|
| `postgres` | `public` | fonctions | `{postgres=X, authenticated=X, service_role=X}` — **anon retiré** (migration `20260831105114`) |
| `supabase_admin` | `public` | fonctions | `{postgres=X, anon=X, authenticated=X, service_role=X}` — **anon toujours là** (non modifiable en hébergé, documenté dans la migration) |

## 3. Pourquoi le rejeu casse alors que la prod tient — et que la CI est verte

Trois faits, tous vérifiés dans le dépôt :

1. **Le socle est un `pg_dump`.** `20260510000000_baseline_live.sql` contient **163** `GRANT … ON FUNCTION … TO "anon"` et **zéro** `REVOKE … FROM "anon"`. Un dump exprime ce qui est accordé ; il ne sait pas dire « non accordé par le privilège par défaut ». Pour nos deux fonctions il émet `REVOKE ALL … FROM PUBLIC` puis `GRANT … TO authenticated, service_role` — ce qui est fidèle à la prod **à condition que rien n'accorde anon à la création**.
2. **Sur une image Supabase, le privilège par défaut est posé avant le socle.** L'image `supabase/postgres` installe `ALTER DEFAULT PRIVILEGES … IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role` à l'initialisation. Chaque `CREATE FUNCTION` du socle matérialise donc `anon=X` dans l'ACL. Les ~600 fonctions du socle **naissent ouvertes à anon**, y compris les 595 (sur 676 dans `public`) que la production n'a jamais ouvertes. Les `CREATE OR REPLACE` ultérieurs **préservent** cette ACL — donc les migrations du 29/08 trouvent anon en place et leur bloc de vérification lève. Ce n'est pas un défaut de ces trois migrations : ce sont simplement les **premières à vérifier** ce qu'elles remplacent. `20260831105114` retourne le défaut, mais **trop tard dans la séquence** pour les fonctions déjà nées, et seulement pour la ligne `FOR ROLE postgres`.
3. **Le banc CI ne rejoue pas sur une image Supabase.** `scripts/ci/run-sql-suites.sh` crée `anarbib_test` par `CREATE DATABASE … TEMPLATE template0` (choix motivé dans son en-tête : pas d'event triggers hérités). Or `pg_default_acl` est un catalogue **par base** : la base de test n'a aucun privilège par défaut, les fonctions y naissent avec l'ACL exacte du dump, et la vérification passe. **Le vert de `sql-tests` n'atteste donc pas qu'une image réelle rejoue le dépôt.** C'est la même limite structurelle que `DOC-MIGR-1` (le banc ne voit pas les données héritées), prise par l'autre bout (le banc ne voit pas les défauts hérités).

Une **seconde divergence** apparaît au passage, à instruire au retour : sur le chemin auto-hébergé, `deploy/scripts/run-migrations.sh` — et `apply-pending-migrations.sh` de la PR, qui en reprend la mécanique — appliquent les migrations en **`supabase_admin`** (premier candidat de la boucle), là où la prod les applique en `postgres`. Conséquences : les objets sont possédés par `supabase_admin` (superutilisateur), c'est **sa** ligne de `pg_default_acl` qui s'applique, et `20260831105114` — qui altère et vérifie explicitement la ligne `FOR ROLE postgres` — passe sans rien fermer pour lui. Sur une pile auto-hébergée, **une fonction continue donc de naître ouverte à anon** après le 31/08, en silence.

Le chiffre de la PR — « les 218 migrations » — correspond exactement au dépôt au 29/08 (218 fichiers ≤ `20260829…` ; 316 au 06/09). Son auteur l'a lui-même retiré (« d'autres migrations en échec après retest ») ; il ne doit être repris nulle part.

## 4. Décision

- **Production : rien à appliquer.** Pas de migration nouvelle, pas de `REVOKE`. Le gel du 8 septembre n'est pas entamé.
- **Les `REVOKE` nominatifs de la PR sont justes et nécessaires** pour le chemin de rejeu, et sans effet en prod (déjà appliquées, ACL préservée). Ils traitent le symptôme sur deux fonctions ; le mécanisme du §3 dit que le même symptôme attend derrière chaque migration qui vérifiera un jour l'ACL d'une fonction du socle.
- **La réparation de fond** n'est pas fonction par fonction : c'est retirer `anon` du privilège par défaut **du rôle qui applique les migrations, avant le socle**, sur le chemin auto-hébergé (`deploy/init-db/` est l'endroit naturel). Les 163 `GRANT` explicites du dump rouvrent alors exactement ce que la prod ouvrait : le rejeu devient fidèle. C'est une proposition, pas une consigne — la PR est à son auteur.

## 5. Les deux remarques d'exécution sur `install.sh` — vérifiées dans le code, pas à l'écran

La fiche de reprise décrivait une exécution locale d'`install.sh` (étapes 1 à 3). **Aucune trace n'en a été retrouvée sur ce poste** : pas de fichier `install.sh` plus récent que le 05/09 (Windows ni WSL), aucun conteneur créé aujourd'hui (`docker ps -a` ne montre que la pile de répétition `anarbib-selfhost` du 27/08, `db` arrêté depuis le 03/09), et les deux `deploy/.env` présents (WSL, 26/08 ; clone Windows `Codeberg/anarbib`, 27/08) n'ont pas été modifiés. Les deux points ont donc été **relus dans le code**, où ils se vérifient tous les deux — et ils précèdent la PR :

1. **Écrasement de valeurs dans un `.env` existant.** `install.sh` détecte le `.env` existant, le garde, puis appelle `genkeys.mjs --local` sans condition en mode local. `genkeys.mjs` (déjà dans `main`) ne réécrit pas un secret présent (`POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY` — c'est le point le plus important, et il est bien traité), mais **force** `API_DOMAIN`, `API_EXTERNAL_URL`, `SITE_URL`, `URI_ALLOW_LIST` (`{ force: true }`), sans copie préalable ni affichage de l'ancienne valeur. Sur les deux `.env` de ce poste, les valeurs étaient déjà celles de localhost : pas de perte ici. Suggestion : une copie horodatée `deploy/.env.bak.<date>` avant `genkeys`, ou n'écrire que si la valeur diffère, en disant laquelle.
2. **L'édition manuelle du Caddyfile est un message périmé, pas une étape restante.** `genkeys.mjs` (lignes 124-126) et `deploy/REPETITION.md` (l. 126-132) demandent de remplacer `{$API_DOMAIN} {` par `http://localhost {`. Or le `Caddyfile` courant lit `{$API_DOMAIN}, http://caddy {` et son propre en-tête prévoit `API_DOMAIN=http://localhost` en répétition. La PR pose justement `API_DOMAIN=http://localhost` dans `genkeys.mjs --local` (au lieu de `localhost`) : **cette ligne rend l'édition manuelle inutile** — il reste à retirer le message qui la réclame, et à aligner `REPETITION.md`. C'est un bon point pour Bastien, pas un reproche.

## 6. Proposition de commentaire pour la PR — *non posté*

À poster par Xavier s'il le souhaite (ou à me demander explicitement). En français, comme la PR.

> Merci pour cette PR — c'est la première contribution extérieure au projet, et elle fait exactement ce que « Éprouver la reconstruction » demandait : rebâtir depuis le dépôt seul et écrire ce qui casse.
>
> J'ai vérifié aujourd'hui, en lecture seule, ce que tes `REVOKE` laissaient craindre côté production : `fn_import_delete_run(bigint)` et `publish_book_draft(bigint)` y ont pour ACL `{postgres, authenticated, service_role}` — `anon` et `PUBLIC` n'y sont pas, et le lint Supabase « DEFINER exécutable par anon » rend exactement les 28 fonctions attendues. Rien à corriger en prod : tes `REVOKE` sont justes et nécessaires pour le rejeu, et sans effet sur la base qui tourne.
>
> Ce que ton rejeu a mis au jour est plus large que ces deux fonctions, et ça vaut la peine de le dire ici. Le socle `20260510000000_baseline_live` est un `pg_dump` : 163 `GRANT … TO anon` sur des fonctions, zéro `REVOKE … FROM anon` — un dump ne sait pas exprimer « non accordé par le privilège par défaut ». Sur une image Supabase, `ALTER DEFAULT PRIVILEGES … ON FUNCTIONS TO anon` est déjà en place quand le socle s'exécute, donc **toutes** les fonctions du socle naissent ouvertes à anon (en prod, 595 des 676 fonctions de `public` sont fermées). Les migrations du 29/08 sont simplement les premières à vérifier l'ACL de ce qu'elles remplacent. Et notre CI ne le voit pas parce que son banc crée la base depuis `template0`, où `pg_default_acl` est vide — le vert de `sql-tests` ne prouve pas qu'une image réelle rejoue le dépôt. Tu es donc la première personne à avoir mesuré ça.
>
> Conséquence pratique, à toi de voir si tu veux la prendre dans cette PR ou la laisser pour une suivante : la réparation de fond n'est pas fonction par fonction, c'est retirer `anon` du privilège par défaut **avant** le socle sur le chemin auto-hébergé (`deploy/init-db/` semble l'endroit) — les 163 `GRANT` explicites du dump rouvrent alors exactement ce que la prod ouvrait. Point lié : `run-migrations.sh` et ton `apply-pending-migrations.sh` appliquent les migrations en `supabase_admin` alors que la prod le fait en `postgres` ; c'est la ligne `supabase_admin` de `pg_default_acl` qui s'applique alors, et `20260831105114` ne touche que la ligne `postgres`. Ce n'est pas bloquant pour cette PR, mais c'est la même famille de divergence.
>
> Deux remarques sur `install.sh`, relues dans le code :
> - `genkeys.mjs --local` force `API_DOMAIN`, `API_EXTERNAL_URL`, `SITE_URL`, `URI_ALLOW_LIST` dans un `.env` existant sans copie ni affichage de l'ancienne valeur (les secrets, eux, sont bien préservés — c'est le point qui compte, merci). Une copie horodatée avant, ou n'écrire que ce qui change en le disant, éviterait une surprise à la prochaine répétition.
> - Ton `API_DOMAIN=http://localhost` rend inutile l'édition manuelle du Caddyfile (il lit déjà `{$API_DOMAIN}` avec le schéma) — mais `genkeys.mjs` (fin de script) et `deploy/REPETITION.md` demandent encore de la faire. Tu peux retirer ce message et aligner le runbook : « une seule commande » sera alors vrai.
>
> Comme annoncé : pas de fusion avant le 14 septembre (démonstration publique sur la production pendant la rencontre, gel à partir du 8). Quand tu repousses, la chose la plus utile que tu puisses joindre, c'est la liste ordonnée des migrations qui échouent avec le message exact de chacune — deux machines qui cassent au même endroit, c'est un défaut du dépôt ; à des endroits différents, c'est l'environnement.

## 7. Ce qui n'a pas été fait, et pourquoi

- **Pas de revue ligne à ligne** de `deploy.sh`, `apply-pending-migrations.sh`, `deploy/tunnel/` : la PR est en révision par son auteur, le contenu va changer.
- **Pas de rejeu local** : `install.sh` n'est pas dans `main` et son exécution décrite par la fiche n'a pas laissé de trace sur ce poste ; la méthode directe a suffi et ne dépendait pas du rejeu.
- **Pas de commentaire posté**, pas de fusion, pas de modification des trois migrations côté `main` : les correctifs appartiennent à Bastien.
- **Rien en production** : deux requêtes de lecture sur `pg_proc`/`pg_default_acl`, une sur `information_schema.role_table_grants`, un passage d'advisor.

## 8. État de la pile de répétition sur le poste (constaté en passant)

`docker compose ls` : un seul projet, `anarbib-selfhost`, dossier `/mnt/c/Users/accat/Codeberg/anarbib/deploy` (clone Windows sur `main`, `effb6e99`). Conteneurs créés le 27/08 ; `db`, `caddy`, `functions` sortis en 127 le 03/09 20:01 UTC (arrêt du démon, pas une panne de Postgres : le journal montre un `fast shutdown` propre) ; `rest` relancé au démarrage de Docker Desktop ce matin (09:47 UTC), `auth` et `storage` en redémarrage permanent faute de base. Rien à faire avant le retour ; à remonter d'un `docker compose up -d` le jour où la répétition reprend.
