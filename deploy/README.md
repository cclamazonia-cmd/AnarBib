# AnarBib — Pile auto-hébergée : mode d'emploi

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
les services qui *lisent* le schéma. Le script compte **huit étapes plus une
« 7 bis »** (attente d'un fait, jamais d'un délai) et une vérification finale.

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
- `./install.sh --rebuild` : réinitialise les volumes de la base avant réinstallation.
- `./install.sh --stop` : arrête l'ensemble des conteneurs et services.
- `./install.sh --sans-start` : prépare les secrets et l'environnement sans démarrer de conteneur.
- `./install.sh --prod DOMAINE` : configure pour un domaine public (ex: `api.anarbib.org`).

### Compte administrateur initial

Lors d'une nouvelle installation avec une base vierge, `./install.sh` provisionne automatiquement un compte administrateur réseau :
- **Mode local** : `admin@anarbib.local` / mot de passe : `anarbib-admin`
- **Mode production** : `admin@DOMAINE` avec un mot de passe aléatoire sécurisé de 16 caractères affiché à l'écran.

Ce compte dispose des rôles de gestionnaire de réseau (`network_administrators`), de coordinateur et de bibliothécaire sur la bibliothèque de démonstration, donnant un accès immédiat aux panneaux de gestion (`/painel`, `/biblioteca`, `/rede`, `/catalogacao`).


### Gestion des clés et secrets

| Environnement | Où mettre les clés ? | Comment ça marche ? |
|---|---|---|
| **Auto-hébergement (Production ou Local)** | `deploy/.env` et `deploy/functions.env` | `deploy/.env` (clés d'infrastructure Postgres, JWT, Anon) est généré automatiquement par `deploy/genkeys.mjs`. `deploy/functions.env` contient les clés des services tiers (Resend pour les e-mails, Altcha pour l'anti-robot). Aucun compte Supabase Cloud requis. |
| **Supabase Cloud (Hébergement distant)** | `.env.local` (local) ou Secrets CI/CD (Codeberg/GitHub) | Renseigner `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`. Le code bascule automatiquement sur le Cloud sans aucune modification. |

Les deux modes coexistent sans interférence : le frontend détecte automatiquement s'il parle à une URL cloud distante ou à la passerelle Caddy locale/réseau.

---

## 2. Architecture de la pile (6 conteneurs)

| Conteneur | Image | Rôle |
|---|---|---|
| `db` | `supabase/postgres:17.6.1.136` | Base PostgreSQL 17 + Vault + pg_net + extensions |
| `rest` | `postgrest/postgrest:v14.12` | API REST & RPC `api.*` |
| `auth` | `supabase/gotrue:v2.192.0` | Serveur d'authentification GoTrue (77 migrations) |
| `storage` | `supabase/storage-api:v1.70.7` | Stockage d'objets et gestion des buckets |
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
./deploy/deploy.sh             # git pull + migrations incrémentales + reload fonctions + santé
./deploy/deploy.sh --sans-pull # applique sur l'état local du code
./deploy/deploy.sh --controle  # vérifie la santé de chaque brique
```

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

## 7. Sauvegarde et Restauration (#BG2)

La stratégie de sauvegarde militante #BG2 (trois flux restic `court`, `long`, `storage`) et la procédure de restauration sont documentées dans [`deploy/ops/README.md`](ops/README.md).
