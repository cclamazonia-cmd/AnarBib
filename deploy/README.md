# AnarBib — pile auto-hébergée : mode d'emploi

Trois fichiers : `compose.yml`, `Caddyfile`, `.env` (depuis `.env.example`).
**Six conteneurs** : cinq briques reprises du compose officiel Supabase (qui en
déclare treize) et Caddy substitué à Kong. Justification service par service :
[`AUDIT_pile_minimale_2026-08-26`](../docs/journal/audits/AUDIT_pile_minimale_2026-08-26.md).

**État au 04/09/2026 — ce qui a tourné, et ce qui n'a pas tourné.** La pile
a été montée trois fois le 26/08/2026 par `bootstrap.sh`, en trois passes
(commits `57321385`, `35c03dd5`, `90266600`) :

- sur volumes vierges, depuis le dépôt seul : 183/183 migrations en 12 s,
  184 tables publiques, 0 sans RLS, 77 migrations GoTrue (la production
  exactement), trois `200` à travers Caddy, code de sortie 0 ;
- sur un jeu de données factice restauré par `--depuis-une-sauvegarde`,
  aller-retour exact ;
- sur **un dump réel de la production**, fichiers des buckets remis en place et
  un objet Storage servi octet pour octet.

**Huit défauts ont été trouvés et corrigés en chemin** — aucun ne se voyait à
la lecture : collision du nom de projet Docker avec la pile de dev (`down -v`
démontait l'autre), `--wait` qui n'attend que les services dotés d'une sonde,
faux vert de l'étape 8 (plafonds « posés » sans vérification de l'effet), les
buckets que **aucune** migration ne crée (ils arrivent avec le dump), Storage
démarré *après* la restauration alors qu'il produit du schéma (`storage.buckets`),
image Storage en retard sur la production (`v1.60.4` → `v1.70.7`, colonne
`versioning_status`), et la disposition des fichiers Storage sur disque qui
n'est pas celle de la sauvegarde (`<bucket>/<nom>` d'un côté,
`<s3>/<tenant>/<bucket>/<nom>/<version>` de l'autre — un `rsync` direct était
faux). D'où la doctrine d'ordre, désormais dans `bootstrap.sh` : base seule →
rôles → GoTrue **et** Storage → schéma + données → vues → et seulement ensuite
les services qui *lisent* le schéma. Le script compte **huit étapes plus une
« 7 bis »** (attente d'un fait, jamais d'un délai) et une vérification finale.

**Ce qui n'a pas tourné** : la bascule elle-même chez Herbes Folles, le routeur
`main` en conditions réelles (item I3, gelé jusqu'au 14/09), et un front
reconstruit pointé sur un vrai domaine (étapes 7 et 8 de la liste de
répétition, plus bas). C'est là que se joue le chiffre à rapporter.

---

## Ce qui reste à faire avant que ça démarre

### 1. Le routeur `main` — écrit, à relire et à tester

Fourni : `main/index.ts`, **à copier dans `supabase/functions/main/`** du dépôt.

Sur la plateforme Supabase, chaque Edge Function est déployée séparément et
`config.toml` impose son `verify_jwt`. Hors plateforme, rien de tout ça
n'existe : `edge-runtime` passe toutes les requêtes à un service unique.

Deux partis pris méritent votre relecture, parce qu'ils portent la sécurité des
44 fonctions :

- **Le routeur lit `config.toml` lui-même**, au démarrage. Il n'y a donc aucune
  liste recopiée à maintenir en parallèle : la politique reste à un seul
  endroit, et elle ne peut pas diverger. C'est pourquoi `compose.yml` monte
  `config.toml` dans le conteneur.

- **Refus par défaut.** `config.toml` déclare 28 fonctions en
  `verify_jwt = false` et **aucune** en `true` — les 16 autres reposent sur le
  défaut de la plateforme. Le routeur lit donc uniquement les dispenses et exige
  un JWT pour tout le reste. Une fonction nouvelle, oubliée ou mal orthographiée
  se retrouve protégée, jamais ouverte.

Corollaire à garder en tête : **une fonction retirée de `config.toml` devient
protégée**, ce qui peut casser un webhook. C'est le bon sens de l'erreur, mais
il faut le savoir avant de toucher au fichier.

Si `config.toml` est illisible, le routeur **refuse de démarrer** plutôt que de
choisir un comportement par défaut. Panne franche au déploiement plutôt
qu'ouverture silencieuse en production.

**Ce qu'il reste à faire dessus** : le tester. Trois cas au minimum — une
fonction protégée sans en-tête `Authorization` (attendu : 401), la même avec un
JWT valide (200), et une fonction dispensée comme `health-probe` sans JWT (200).
Plus un nom inexistant (404).

### 2. Épingler les versions

Les tags de `.env` sont vides à dessein. Les récupérer depuis le compose
officiel de Supabase (dépôt `supabase/supabase`, dossier `docker`), qui est la
seule référence à jour, puis les recopier tels quels.

Une fois la pile validée, remplacer chaque tag par son digest :

```bash
docker compose config --images | while read -r img; do
  docker image inspect "$img" --format '{{index .RepoDigests 0}}'
done
```

Un tag peut être redéplacé sur une autre image ; un digest, jamais. C'est la
différence entre « à peu près la même pile » et « la même pile ».

### 3. Générer les clés

`ANON_KEY` et `SERVICE_ROLE_KEY` sont des JWT signés avec `JWT_SECRET`, portant
respectivement `role: anon` et `role: service_role`. Supabase fournit un
générateur dans sa documentation self-hosting ; sinon n'importe quel outil JWT
fait l'affaire, la charge utile étant :

```json
{ "role": "anon", "iss": "supabase", "iat": <maintenant>, "exp": <dans 10 ans> }
```

`SERVICE_ROLE_KEY` ne doit jamais atteindre le front ni le dépôt.

### 4. Les rôles Postgres

`compose.yml` se connecte avec `authenticator`, `supabase_auth_admin` et
`supabase_storage_admin`. L'image `supabase/postgres` les crée, mais leurs mots
de passe doivent être posés — la migration baseline du dépôt en présuppose
peut-être certains. **À vérifier au premier démarrage**, c'est un point de
friction classique.

---

## Points à confirmer avant bascule

- **GoTrue et le courriel.** La configuration pose `MAILER_AUTOCONFIRM=true`, en
  partant du principe que les liens sont produits par `admin.generateLink` dans
  vos Edge Functions et expédiés par Resend. Si une seule route d'auth compte
  encore sur le mailer interne de GoTrue, il faudra lui donner un SMTP — ce qui
  contredirait ce que vous annoncez à hfo. **À vérifier en premier.**

- **`PGRST_DB_SCHEMAS`.** Mis à `public,api,storage` par déduction. Comparer avec
  le réglage réel du projet Supabase (Settings → API → Exposed schemas).

- **`notify-cross-library-digest`.** ~~Appelée depuis une migration, absente du
  dépôt.~~ **Clos (04/09/2026)** : la fonction est au dépôt,
  `supabase/functions/notify-cross-library-digest/`, et se déploie avec les
  autres. Rien n'existe qu'en production.

- **Le rejeu des migrations.** ~~`bootstrap.sh` devra distinguer les deux cas.~~
  **Fait** : l'étape 5 a deux branches — rejeu depuis le dépôt sur volume vide,
  ou `--depuis-une-sauvegarde` — éprouvées toutes deux le 26/08. Le montage
  `docker-entrypoint-initdb.d` ne s'exécute qu'au tout premier démarrage ; pour
  une mise à jour ultérieure, c'est la CLI.

- **`CADDY_TAG=2`.** Seule entorse à « aucun `latest`, jamais » : un tag majeur
  flottant. Justification écrite dans `.env.example` — Caddy est le seul service
  sans schéma ni données, une mineure ne change rien à la reconstruction. À
  épingler au tag exact le jour de la répétition finale, avec la valeur que
  `docker image inspect` aura donnée.

---

## Ce que ça donne côté frontend

**Aucune modification de code.** Le `Caddyfile` reproduit les chemins de l'API
Supabase (`/rest/v1`, `/auth/v1`, `/storage/v1`, `/functions/v1`), donc seule la
variable de build `VITE_SUPABASE_URL` change, de `https://<ref>.supabase.co`
vers `https://api.anarbib.org`.

C'est ce qui rend la bascule réversible : si quelque chose se passe mal, on
remet l'ancienne valeur et on redéploie le front.

---

## Ce qu'on a supprimé, et pourquoi

| Service | Raison |
|---|---|
| `realtime` | aucun usage dans le front — pas un `.channel(`, pas un `postgres_changes` |
| `imgproxy` | aucune transformation d'image demandée à Storage — **vrai depuis le 26/08 seulement** : la grille du catalogue en demandait depuis le 17/06, voir l'audit |
| `studio` | administration par migrations ; jamais en production |
| `analytics` / `vector` | logs dans journald |
| `meta` | outil de Studio |
| `kong` | remplacé par Caddy |
| `supavisor` | pooler sans objet à cette charge |

---

## Ordre de la répétition

1. VM jetable, Docker installé.
2. `.env` rempli, tags épinglés.
3. Écrire et relire le routeur `main`.
4. `docker compose up -d`, observer les healthchecks.
5. Restaurer un dump de production dans `db`.
6. Vérifier dans l'ordre : `/auth/v1/health` → une RPC `api.*` → un fichier
   Storage → une Edge Function du chemin critique (`login`).
7. Pointer un build du front sur le nouveau domaine et se connecter pour de vrai.
8. **Chronométrer le tout**, et noter ce qui a cassé.

Le chiffre à rapporter à hfo est celui de l'étape 8 — pas celui d'un compose qui
démarre, mais celui d'une connexion réussie depuis un front reconstruit.

---

## `bg2-known-tables.txt` — le classement des tables pour la sauvegarde

Liste plate et triée de **toutes** les tables de `public`. C'est le « filet » de
la chaîne de sauvegarde #BG2 : `anarbib-bg2.sh` compare les tables réellement
présentes en base à cette liste et **s'arrête** (`die`, pas un avertissement) dès
qu'il en trouve une qu'il ne sait pas classer. Une table oubliée ici, et plus
aucune sauvegarde ne part.

**Ce fichier est la source de vérité.** `~/anarbib-ops/bg2-known-tables.txt` est
un lien symbolique vers lui : il n'existe qu'une copie, elle ne peut pas
diverger.

Deux autres listes complètent le classement et vivent, elles, dans
`~/anarbib-ops/` — elles nomment des données personnelles, ce dépôt est public :

| Fichier | Ce qu'il désigne |
|---|---|
| `bg2-denylist.txt` | données personnelles effaçables : exclues du flux long, incluses au court (rétention 7 j) |
| `bg2-exclude-long.txt` | données transitoires sans valeur de restauration : ni long, ni court |

Une table listée dans l'une des deux **reste** dans `bg2-known-tables.txt` : la
première dit *où* sauvegarder, la seconde dit seulement que la table est connue.

**Ajouter une table ici fait partie de la migration qui la crée.** Le job
`sql-tests` reconstruit le schéma depuis les migrations et compare : une table
non classée rend le run rouge, sur le commit fautif. Avant ce garde-fou
(19/08/2026), la règle n'était qu'une discipline — `altcha_consumed_challenges`
est arrivée non classée et toutes les sauvegardes ont échoué en silence, sans
autre filet que l'alarme de silence, 36 h plus tard.
