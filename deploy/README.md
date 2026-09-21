# AnarBib — Pile auto-hébergée : mode d'emploi

> ## À lire avant de toucher à quoi que ce soit
>
> **Une reconstruction demande trois choses, pas deux : le dépôt, une
> sauvegarde, et les secrets du Vault.** C'est la leçon de méthode la plus
> chère du chantier.
>
> La migration de pseudonymisation refuse de s'appliquer sans le sel
> `pseudonym_salt`, qui n'est **reconstructible depuis rien**. Et restaurer
> avec un sel différent **ne produit aucune erreur visible** : cela rend
> simplement incohérents tous les jetons produits auparavant — corruption
> silencieuse de données personnelles (RGPD). Les secrets du Vault voyagent
> dans le flux de sauvegarde `long`, exportés en appels `vault.create_secret`
> rejouables ; `bootstrap.sh` s'arrête à l'étape 3 tant que le sel manque, et
> refuse `--sel-jetable` dès qu'il s'agit de restaurer une sauvegarde.
>
> S'y ajoutent, hors base, **les fichiers des buckets Storage** : le dump ne
> porte que les *lignes* de `storage.buckets` et `storage.objects`, jamais les
> fichiers eux-mêmes. Ils viennent du flux de sauvegarde `storage`, et aucune
> migration ne crée les buckets — une reconstruction depuis le dépôt seul
> donne une instance à zéro bucket.
>
> Toute personne qui héberge ou administre une instance lit ce paragraphe
> d'abord. Le reste de cette page suppose qu'il est acquis.

Trois fichiers de configuration : `compose.yml`, `Caddyfile`, `.env` (depuis `.env.example`).
**Six conteneurs** : cinq briques reprises du compose officiel Supabase et Caddy substitué à Kong. Justification service par service :
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
les services qui *lisent* le schéma. Le script compte **huit étapes plus deux
« bis »** — la « 5 bis » pose l'adresse des Edge Functions de cette instance
(`anarbib.functions_base_url`, I20 du 07/09/2026 : sans elle, les dépêches
partiraient vers le projet cloud du mainteneur), la « 7 bis » attend un fait,
jamais un délai — et une vérification finale.

**Première reconstruction extérieure (06–15/09/2026, A2).** La pile a été
rebâtie par quelqu'un d'autre que le mainteneur : un camarade de l'ASR (compte
`ASR2026`, première contribution au projet) l'a montée chez lui depuis le dépôt seul, en
a écrit l'installateur (`install.sh`, PR #28, fusionnée le 15/09) et a laissé
dans ses commits ce qui cassait — `pg_cron` absent au démarrage d'un volume
vierge, schéma à initialiser sous `supabase_admin` (propriétaire), `GRANT` sur
`supabase_migrations` aux deux rôles, `LANG_CODE` au premier prompt, port 5173
à libérer. Deux écarts structurels sont sortis de cette relecture et ont leurs
notes : le rejeu depuis zéro ne reproduit pas les privilèges par défaut de la
production (`journal/operations/CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`,
`DOC-GRANT-2`) et la réparation au privilège par défaut avant le socle
(`journal/operations/NOTE_experience-I17-rejeu-fidele_2026-09-07`, `DOC-GRANT-3`).
Depuis, ses correctifs partent d'une instance qui tourne chez lui et sont relus
puis fusionnés ici. Ce que la pile n'a **pas** encore éprouvé hors de chez son
auteur : `install.sh` lancé sur une machine tierce vierge (I21) et le routeur
`main` (I3). Le rejeu sur une image Supabase, lui, tourne en CI à chaque poussée
depuis le 16/09 (job `rejeu-image`, I18).

**Pins remesurés le 21/09/2026 — la production monte seule.** L'hébergeur
actuel met à jour GoTrue et Storage sans prévenir : entre le 26/08 et le 21/09
la production est passée de 77 à 82 migrations `auth` (GoTrue v2.197.0) et de
65 à 68 migrations Storage (1.73.1), et les deux pins de cette pile étaient
repassés **sous** la production sans que rien le signale — le contrôle de
`bootstrap.sh` comparait à un chiffre écrit en dur. Remesuré au banc, une base
vierge par palier : `GOTRUE_TAG=v2.197.0` (193 à 196 restent à 77) et
`STORAGE_TAG=v1.72.0` (v1.71.0 reste à 65) sont les minimums nécessaires ; les
342 colonnes des schémas `auth` et `storage` de la production s'y retrouvent,
même empreinte. Détail dans `.env.example`. **Un pin mesuré un jour ne vaut que
ce jour-là : à refaire avant toute restauration d'un dump réel.**

---

## 1. Démarrage rapide (Installation en une commande)

À la racine du dépôt :

```bash
./install.sh                           # Installation complète en local (Backend + Frontend)
./install.sh --rebuild                 # Réinitialisation complète et remise à neuf des volumes
./install.sh --stop                    # Arrête l'application web et les conteneurs
./install.sh --prod api.domaine.org    # Installation en mode production
```

Le script centralisé `./install.sh` effectue de manière 100 % autonome et sans intervention manuelle :
1. **Prérequis** : Vérification de `docker`, `docker compose`, `node`.
2. **Secrets & Clés** : Génération cryptographique des clés JWT et secrets locaux via `deploy/genkeys.mjs` (`deploy/.env` et `deploy/functions.env`).
3. **Liaison & Build Frontend** : Création automatique de `.env.local`, installation des dépendances (`npm ci`) et compilation statique (`npm run build` dans `dist/`).
4. **Déploiement Docker (6 conteneurs)** : Démarrage des conteneurs avec amorçage initial ou rejeu des migrations incrémentales. Caddy sert à la fois les API backend et l'application web sur les ports 80 et 5173.
5. **Résolution universelle (IP / Domaine / Localhost)** : L'application s'adapte dynamiquement à l'hôte accédé dans le navigateur (`window.location.origin`). Elle est immédiatement fonctionnelle sur une adresse IP locale (ex: `http://192.168.x.x:5173`), un domaine personnalisé ou `localhost`.

Options disponibles :
- `./install.sh` : installation et démarrage complet (Backend + Frontend).
- `./install.sh --lang fr|en|pt|es|it|de|ca|eo|nl|el` : force la langue d'affichage (détection automatique depuis `$LANG` par défaut). Une valeur inconnue est refusée avec la liste des codes.
- `./install.sh --rebuild` : réinitialise les volumes de la base avant réinstallation.
- `./install.sh --stop` : arrête l'ensemble des conteneurs et services.
- `./install.sh --sans-start` : prépare les secrets et l'environnement sans démarrer de conteneur.
- `./install.sh --prod DOMAINE` : configure pour un domaine public (ex: `api.anarbib.org`).

### Compte administrateur initial

Lors d'une nouvelle installation avec une base vierge, `./install.sh` provisionne automatiquement un compte administrateur réseau :
- **Email admin** : demandé interactivement lors de l'installation (par défaut `admin@DOMAINE` en production, `admin@anarbib.local` en local).
- **Mot de passe** : généré aléatoirement (16 caractères), affiché une seule fois à l'écran à la fin de l'installation, puis supprimé.

Ce compte dispose des rôles de gestionnaire de réseau (`network_administrators`), de coordinateur et de bibliothécaire sur la bibliothèque de démonstration, donnant un accès immédiat aux panneaux de gestion (`/painel`, `/biblioteca`, `/rede`, `/catalogacao`).

### Une instance = un réseau (`FED-O11`)

Installée chez vous, votre AnarBib est un réseau à elle seule — sa base, ses bibliothèques, ses admins, ses assemblées. Entre instances, seul le catalogue traverse, par le protocole OAI-PMH : chaque instance sert le sien (`oai-pmh-provider`) et peut moissonner celui d'une autre (`harvest-oai-pmh`), sur décision de ses admins. Les comptes, les appartenances, les prêts entre bibliothèques, la gouvernance et la gazette ne traversent pas. Installer le logiciel ne fait donc pas rejoindre le réseau hébergé sur `app.anarbib.org` : c'est en créer un autre, qui peut échanger des notices avec lui. Aucun annuaire des instances n'existe, et aucune fédération de protocole n'est annoncée (REGISTRE `FED-O11`, tranché le 06/09/2026 ; le guide d'auto-hébergement du site le dit dans les mêmes termes, dix langues).

### Transport des e-mails (Resend aujourd'hui ; SMTP et simulation à venir)

**Aujourd'hui, un seul transport fonctionne : l'API Resend.** Renseignez `RESEND_API_KEY` et `SENDER_EMAIL` dans `deploy/functions.env` (ou choisissez l'option 2 de `./install.sh`). Sans clé, chaque envoi de courriel échoue avec « RESEND_API_KEY absente » — bruyamment, jamais en silence (`DOC-SILENCE-1`) : l'application tourne, mais aucune notification, invitation ou relance ne part.

À venir, avec le transport hybride (backlog `F7`) :
1. **Serveur SMTP standard** (votre propre boîte mail : OVH, Gandi, Infomaniak, Postfix local…) — les variables `SMTP_*` de `functions.env` et l'option 1 de l'installateur existent déjà, mais **les fonctions serveur ne les lisent pas encore** ; l'installateur le dit et ne configure rien.
2. **Simulation locale** (courriels journalisés) — uniquement sur `MAIL_TRANSPORT=mock` explicite, jamais par défaut : un transport absent doit lever, pas se taire.

Ce transport hybride était la PR #29 (16/09/2026), fermée par son auteur sans remplacement ; la reprise est planifiée (`F7`).


### Gestion des clés et secrets

| Environnement | Où mettre les clés ? | Comment ça marche ? |
|---|---|---|
| **Auto-hébergement (Production ou Local)** | `deploy/.env` et `deploy/functions.env` | `deploy/.env` (clés d'infrastructure Postgres, JWT, Anon) est généré automatiquement par `deploy/genkeys.mjs`. `deploy/functions.env` contient les réglages des services tiers (SMTP standard ou Resend pour les e-mails, Altcha pour l'anti-robot). Aucun compte Supabase Cloud requis. |
| **Supabase Cloud (Hébergement distant)** | `.env.local` (local) ou Secrets CI/CD (Codeberg/GitHub) | Renseigner `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`. Le code bascule automatiquement sur le Cloud sans aucune modification. |

Les deux modes coexistent sans interférence : le frontend détecte automatiquement s'il parle à une URL cloud distante ou à la passerelle Caddy locale/réseau.

---

## 2. Architecture de la pile (6 conteneurs)

| Conteneur | Image | Rôle |
|---|---|---|
| `db` | `supabase/postgres:17.6.1.136` | Base PostgreSQL 17 + Vault + pg_net + extensions |
| `rest` | `postgrest/postgrest:v14.12` | API REST & RPC `api.*` |
| `auth` | `supabase/gotrue:v2.197.0` | Serveur d'authentification GoTrue (82 migrations, relevé du 21/09/2026) |
| `storage` | `supabase/storage-api:v1.72.0` | Stockage d'objets et gestion des buckets (68 migrations, relevé du 21/09/2026) |
| `functions` | `supabase/edge-runtime:v1.74.0` | Routeur `main` et exécution des 48 Edge Functions |
| `caddy` | `caddy:2` | Passerelle API, sécurité HTTP et terminaison TLS automatique |

---

## 3. Sécurité & Routeur `main`

Le routeur Deno (`supabase/functions/main/index.ts`) est le point d'entrée unique de `edge-runtime` :

- **Lecture dynamique de `config.toml`** : Aucune liste en double. Les fonctions déclarées avec `verify_jwt = false` sont dispensées de jeton ; toutes les autres exigent un JWT valide (`Authorization: Bearer <TOKEN>`).
- **Refus par défaut** : Toute fonction non explicitement dispensée ou nouvellement créée est automatiquement protégée.
- **Vérification cryptographique** : Les signatures JWT sont validées localement avec le `JWT_SECRET`.

---

## 4. Déploiement et mise à jour autonome (hors CI)

Pour mettre à jour une instance en production ou en essai sans dépendre de la forge ni de l'API Supabase Cloud :

```bash
./deploy/deploy.sh             # git pull + migrations incrémentales + reload fonctions + front + santé
./deploy/deploy.sh --sans-pull # applique sur l'état local du code
./deploy/deploy.sh --front     # reconstruit le front servi par Caddy, et rien d'autre
./deploy/deploy.sh --controle  # vérifie la santé de chaque brique
```

**Le front suit, depuis le 21/09/2026.** Jusque-là ce script mettait à jour la
base et les fonctions, jamais l'interface : `install.sh` construit `dist/` une
fois, et une instance mise à jour servait donc le front du jour de son
installation contre un backend du jour. Désormais `deploy.sh` reconstruit le
front quand le commit a changé (`dist/.version-front` porte le commit
construit), dans un dossier à part, puis synchronise `dist/` — Caddy monte ce
dossier, on ne le remplace donc jamais — et le contrôle de santé dit si ce que
Caddy sert est en retard sur le dépôt. Si la construction échoue, l'ancien
front reste servi et le script le dit.

**Et côté projet hébergé** (front sur Codeberg Pages) :
`scripts/ci/publier-front.sh` rejoue hors forge ce que fait le job `app` de la
CI — construire, puis publier sur les trois sites par `git-pages-cli`, l'image
que l'action de la forge appelle elle-même. `--simulation` ne publie rien,
`--essai` fait vérifier l'autorisation par le serveur sans rien publier,
`--vers-dossier` produit un `dist/` pour n'importe quel serveur de fichiers
statiques. Pendant du `scripts/ci/deployer-backend.sh` du backend.

### Application des migrations incrémentales

Le script `deploy/scripts/apply-pending-migrations.sh` :
- Vérifie `supabase_migrations.schema_migrations`.
- N'applique que les nouvelles migrations dans l'ordre lexicographique.
- Notifie PostgREST (`NOTIFY pgrst, 'reload schema'`) pour actualiser le cache de schéma sans coupure de service.

---

## 5. Exposition et Tunnel (Reverse Proxy)

Si la machine hôte n'a pas d'IP publique directe ou est située derrière un NAT / pare-feu :
- Voir le guide complet et les configurations dans [`deploy/tunnel/README.md`](tunnel/README.md).
- **Doctrine L4 (Passthrough TCP)** : Le VPS frontal public ne détient aucun certificat TLS ni secret. Il redirige les flux TCP bruts (ports 80/443) via **WireGuard** ou **Rathole** vers Caddy, qui assure seul la terminaison TLS.

---

## 6. Points à confirmer avant bascule

- **GoTrue et le courriel.** La configuration pose `MAILER_AUTOCONFIRM=true`, en
  partant du principe que les liens sont produits par `admin.generateLink` dans
  vos Edge Functions et expédiés par Resend. Si une seule route d'auth compte
  encore sur le mailer interne de GoTrue, il faudra lui donner un SMTP — ce qui
  contredirait ce que vous annoncez à hfo. **À vérifier en premier.**

- **`PGRST_DB_SCHEMAS`.** Mis à `public,api,storage` par déduction. Comparer avec
  le réglage réel du projet Supabase (Settings → API → Exposed schemas).

- **`notify-cross-library-digest`.** **Clos (04/09/2026)** : la fonction est au dépôt,
  `supabase/functions/notify-cross-library-digest/`, et se déploie avec les
  autres. Rien n'existe qu'en production.

- **Le rejeu des migrations.** **Fait** : l'étape 5 a deux branches — rejeu depuis le dépôt sur volume vide,
  ou `--depuis-une-sauvegarde` — éprouvées toutes deux le 26/08. Pour les mises à jour ultérieures, `apply-pending-migrations.sh` et `deploy.sh` prennent le relais.

- **`CADDY_TAG=2`.** Seule entorse à « aucun `latest`, jamais » : un tag majeur
  flottant. Justification écrite dans `.env.example` — Caddy est le seul service
  sans schéma ni données, une mineure ne change rien à la reconstruction.

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

## 7. Sauvegarde et Restauration (#BG2)

La stratégie de sauvegarde militante #BG2 (trois flux restic `court`, `long`, `storage`) et la procédure de restauration sont documentées dans [`deploy/ops/README.md`](ops/README.md).

### `bg2-known-tables.txt` — le classement des tables pour la sauvegarde

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

## L'ordre des scripts d'initialisation — ce que le préfixe 99 ne garantit pas

Mesuré le 07/09/2026 (expérience d'`I17`,
`journal/operations/NOTE_experience-I17-rejeu-fidele_2026-09-07`). L'entrypoint
de l'image traite `/docker-entrypoint-initdb.d/*` **dans l'ordre du glob**, où
`99-roles.sh` passe **avant** `migrate.sh` : les chiffres trient avant les
lettres. Au premier démarrage d'un volume vierge, notre script tourne donc
avant que l'image ait créé le moindre rôle de service : il les trouve
« absents », ne pose rien, et rend la main. Ce qui pose réellement les mots de
passe, c'est son rejeu à l'**étape 2** de `bootstrap.sh`, une fois la base
saine — c'est pour cela que l'étape existe et qu'elle n'est pas facultative.

Deux conséquences pour qui écrit un script d'initialisation :

- **Ne jamais quitter en erreur à ce premier passage.** Le fichier est monté
  sans bit d'exécution, donc *sourcé* par l'entrypoint : un `exit 1` tue
  l'initialisation entière, le conteneur redémarre en « sautant
  l'initialisation », et la base tourne **sans aucun rôle** tout en se
  déclarant malade au healthcheck. Un script qui a besoin des rôles de l'image
  doit constater leur absence et différer, pas échouer.
- **Ce qui doit précéder le socle se pose à l'étape 2**, pas dans `initdb.d` :
  le retrait d'`anon` du privilège par défaut (`DOC-GRANT-3`), comme la création
  de `pg_cron` (`I19`), passent par le même rejeu.
- **La forge rejoue ces deux scripts tels quels.** Le job `rejeu-image` de
  `sql-tests.yml` (`scripts/ci/run-image-replay.sh`, backlog `I18`, 16/09/2026)
  lance `01-roles.sh` puis `run-migrations.sh` contre la base `postgres` de
  l'image `supabase/postgres`, par `PGHOST` au lieu du socket, après avoir posé
  ce que la pile obtient de ses services avant de migrer (sel au Vault,
  `auth.jwt()` et colonnes récentes d'`auth.users`, `storage.buckets` — voir
  `tests/sql/_ci_setup_image_services_stub.sql`). Un changement dans l'un des
  deux scripts qui casse le rejeu casse la CI au même endroit, avant la pile.

Si l'on tient à ce que le script passe *après* `migrate.sh` dès le premier
démarrage, le nom du montage doit trier après lui (`zz-roles.sh`, éprouvé le
07/09) ; la correction du commentaire seule ne change pas l'ordre.
