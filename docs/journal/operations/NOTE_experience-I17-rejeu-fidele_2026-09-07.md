# Note d'opération — Expérience §7 du cadrage I17 : un rejeu depuis zéro fidèle à la production

*Note d'opération (`docs/journal/operations/`), non normative. Ce qui fait foi : REGISTRE `DOC-GRANT-1`, `DOC-GRANT-2` ; backlog `I17` (clos sur cette note), `I19`, `B22`. Spec exécutée : `journal/cadrages/CADRAGE_rejeu_fidele_privileges_par_defaut_2026-09-07.md`, §7.*

- **Date :** 7 septembre 2026, 16 h 52 à 17 h 00. Dépôt `main` à `c28baac0`, **sans la PR #28**.
- **Où :** poste du mainteneur, WSL, Docker. Pile compose isolée sous `COMPOSE_PROJECT_NAME=anarbib-i17`, image `supabase/postgres:17.6.1.136`, volume vierge, secrets locaux par `genkeys.mjs --local`, `API_DOMAIN=http://localhost`. La pile de développement n'a pas été touchée.
- **Production :** interrogée en lecture seule, deux fois, pour la comparaison. Rien n'y a été écrit.
- **Ce qui a été modifié, dans un worktree non committé** (diff conservé hors dépôt, 118 lignes) :
  - **A.1** dans `deploy/init-db/01-roles.sh` : `ALTER DEFAULT PRIVILEGES FOR ROLE postgres | supabase_admin IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon`, puis un bloc `DO` qui vérifie que les deux entrées de `pg_default_acl` existent encore et ne portent plus `anon=` (modèle `20260831105114`) ;
  - **A.2** dans `deploy/scripts/run-migrations.sh` : `postgres` premier candidat (socket, puis TCP avec le mot de passe de l'image), `supabase_admin` en repli signalé ;
  - le montage du script d'init renommé `zz-roles.sh` dans `compose.yml` et `bootstrap.sh` (voir « ordre des scripts » plus bas).
- **Commande :** `./bootstrap.sh --depuis-le-depot --sel-jetable`, puis les mesures des étapes 2, 3 et 4 du §7.

## Résultats

| Étape | Attendu (§7) | Mesuré |
|---|---|---|
| 1. Rejeu complet | Migrations vertes, les trois du 29/08 sans `REVOKE` ajouté | **310/310 vertes sous `postgres`.** `20260829060000`, `20260829100000`, `20260829160000` : OK sans rafistolage. `20260830090000`, `20260830130000`, `20260902100917`, `20260904121500` : OK sans les tolérances ajoutées par la PR #28. Un seul arrêt, à la 288e (`20260904130100`, `cron.job` absent), levé par `CREATE EXTENSION pg_cron` sous `postgres` — voir I19. Les 676 fonctions de `public` sont possédées par `postgres`. |
| 2. Fonctions exécutables par `anon` | Différence symétrique réduite aux objets absents d'un côté | **133 fonctions, empreinte `md5(string_agg(… order by 1))` = `56ed10b70dfd69e8436b6a4e818093ef`, identique à la production interrogée à la même minute.** Aucune différence, pas même un objet absent d'un côté. Les 12 fonctions « sans `GRANT` écrit » du §4 sont ouvertes à `anon` au rejeu comme en prod. |
| 3. `tests/sql/grants_herites_tests.sql` | T8 à T11 verts, T10 en particulier | **10/11 : T8, T9, T10, T11 verts.** Le seul rouge est **T7**, hors périmètre du §7 — voir plus bas. |
| 4. `pg_default_acl` | Les deux entrées `public`/fonctions existent, sans `anon=` ; l'entrée `postgres` rétablie par le socle puis refermée par `20260831105114` | `postgres` : `{postgres=X,authenticated=X,service_role=X}` ; `supabase_admin` : idem. Les deux entrées existent, aucune ne porte `anon=`. Le socle a rétabli `anon` pour `postgres` (l. 61217) et `20260831105114` l'a retiré : la trajectoire de la production est reproduite. |

Autres mesures : zéro table publique sans RLS ; 191 tables ; 188 fonctions `api` ; job `anarbib-work-titles-autofill` planifié.

**Conclusion : la règle du §5 est atteinte avec l'option A, sans toucher à une seule migration.** L'option B n'a pas eu à être considérée. `I17` est clos sur ce constat ; le code (A.1, A.2) reste à proposer à Bastien après la fusion de la PR #28, décision D7.

## Deux choses apprises en chemin

**1. L'ordre des scripts d'initialisation.** L'entrypoint de l'image traite `/docker-entrypoint-initdb.d/*` dans l'ordre du glob, où `99-roles.sh` passe **avant** `migrate.sh` : les chiffres trient avant les lettres. À ce passage, aucun rôle Supabase n'existe encore ; et comme le fichier est monté sans bit d'exécution, il est *sourcé* : un `exit 1` dedans tue l'entrypoint, la base repart au redémarrage suivant en « sautant l'initialisation », sans aucun rôle, et le healthcheck la déclare `unhealthy`. C'est arrivé au premier passage de cette expérience. Le commentaire « le préfixe 99 garantit l'exécution après les scripts de l'image » de `deploy/compose.yml` est donc faux ; sur `main` ça ne se voit pas parce que `bootstrap.sh` rejoue le script à l'étape 2, une fois les rôles là. Parade appliquée pour le second passage : A.1 tolère l'absence d'`anon` (message, retrait différé au passage suivant) et le montage est renommé `zz-roles.sh`. À reporter dans `deploy/README.md` et dans les points proposés à Bastien : son `01-roles.sh`, qui crée `pg_cron` et s'arrête en cas d'échec, a le même problème.

**2. I19 confirmé.** L'image précharge la bibliothèque `pg_cron` (le planificateur démarre) mais ne crée pas l'extension dans la base `postgres` : `cron.job` n'existe pas, et `20260904130100` s'arrête. `CREATE EXTENSION IF NOT EXISTS pg_cron` sous `postgres`, non superutilisateur, réussit (extension de confiance ; propriétaire relevé `supabase_admin`) ; `postgres` a `USAGE` sur `cron` et `EXECUTE` sur `cron.schedule`. Les 23 migrations suivantes passent en une seconde. Le correctif de Bastien (`CREATE EXTENSION` dans `01-roles.sh`) est le bon geste ; il doit s'arrêter si ça échoue, et tenir compte du point 1.

## Ce qui reste rouge, et pourquoi c'est un autre item

**T7** : cinq vues du socle sans `security_invoker` sont lisibles par `anon` et `authenticated` au rejeu : `v_author_alias_candidates_unique`, `v_author_alias_worklist`, `v_author_seed_candidates`, `v_terra_livre_books_ready`, `v_terra_livre_books_ready_stats`. En production, leur ACL est `anon=m, authenticated=m` (MAINTAIN seul, pas de SELECT). Mécanisme : le même qu'I17, côté **relations**. Le défaut de l'image pour les tables donne `anon=arwdm` aux deux rôles ; les vues du socle naissent lisibles ; le dump ne porte pas de `GRANT SELECT` pour elles mais rien dans le dépôt ne le retire non plus (`20260830110000` ne retire qu'`insert, update, delete` ; `20260829140000` que `truncate, references, trigger`). Le `REVOKE SELECT` qui a laissé `m` en production n'est écrit nulle part : un acte non écrit, au sens de `DOC-GRANT-1`. Deux voies, à trancher dans `B22` : étendre A.1 aux tables (retirer `anon` et `authenticated` du défaut des relations avant le socle, et laisser les `GRANT` explicites du dump rouvrir ce que la prod ouvrait), ou une migration nominative qui écrit le `REVOKE SELECT` sur ces cinq vues. Dans les deux cas, chercher les vues et les policies avant (REGISTRE).

## Ce que ça change (§8, confirmé)

- `I18` : le second job CI peut rejouer dans la base `postgres` du service avec A.1 avant le socle et un `CREATE EXTENSION pg_cron` : il sera vert.
- `deploy/README.md` : une phrase sur « les migrations s'appliquent sous `postgres` comme en production ; `01-roles.sh` reste en `supabase_admin` », et la correction du commentaire sur l'ordre des scripts.
- REGISTRE : une ligne « corollaire » sous `DOC-GRANT-2`, si le mainteneur le souhaite.

## Reproduire

Le diff A.1/A.2/`zz-roles.sh`, le journal complet des deux passages, la liste des 133 fonctions et la sortie de la suite sont conservés hors dépôt (dossier de reprise du 14/09). La requête de l'étape 2 est celle du §7 du cadrage ; l'empreinte se calcule par `select count(*), md5(string_agg(f, E'\n' order by f))` sur son résultat, des deux côtés.
