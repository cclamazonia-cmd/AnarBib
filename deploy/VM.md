# AnarBib sur une VM : ce qui s'installe seul, ce qui se saisit, ce qui se télécharge

> Page écrite le 12/10/2026 pour la VM d'essai montée par ASR2026 (Debian minimale en
> installation automatique, premier démarrage qui lance `install.sh`). Elle complète
> `deploy/README.md` (la pile, ses six conteneurs, la restauration) sans le répéter :
> ici, seulement ce qu'une machine neuve demande à la personne qui l'installe.

## 1. Ce qu'une instance est, et n'est pas

Une AnarBib installée est **un réseau à elle seule** (`FED-O11`, README § « Une instance = un
réseau ») : sa base, ses bibliothèques, ses comptes. Elle n'entre pas dans le réseau hébergé
sur `app.anarbib.org` ; elle peut échanger des notices avec lui par OAI-PMH.

Pour la VM d'essai d'octobre 2026 : **la production reste sur le cloud**. La VM sert de
miroir et de banc, et c'est la première exécution d'`install.sh` hors de chez son auteur
(backlog `I21`). Ce qu'elle casse est une information, pas un échec.

## 2. Dimensionnement

| Ressource | Minimum | Pourquoi |
|---|---|---|
| RAM | 4 Go | `compose.yml` borne Postgres pour une VM de 4 Go (`shared_buffers 512M`, `mem_limit 1536m`) ; les cinq autres conteneurs tiennent dans le reste |
| vCPU | 2 | une pour Postgres, une pour le reste ; la construction du front (`npm run build`) prend plusieurs minutes sur une seule |
| Disque système | 20 Go | Debian, Docker, les images (≈ 3 Go), le dépôt et ses `node_modules` (≈ 1,5 Go) |
| Disque données | selon les fichiers | les fichiers des buckets (≈ 450 Mo en production, hors fond de carte) **plus le fond de carte** : 18 Go en zoom 12, 36 Go en zoom 13 (celui de la production) ; prévoir le double pour une mise à jour sans coupure |
| Réseau | sortant libre | images Docker, dépôt Codeberg, Resend (courriel), planet Protomaps (fond de carte) ; entrant : 80 et 443 si la machine est exposée |

## 3. Ce que le premier démarrage peut faire seul

Sur une Debian avec Docker (paquet `docker-ce` + `docker-compose-plugin`), Node 22 et git :

```bash
git clone https://codeberg.org/anarbib/anarbib.git /opt/anarbib
cd /opt/anarbib
./install.sh --prod essai.exemple.org        # ou ./install.sh --local pour un banc sans domaine
```

`install.sh` génère les secrets de la pile (`deploy/.env` : mots de passe Postgres, `JWT_SECRET`,
clés dérivées), construit le front, démarre les six conteneurs par `bootstrap.sh
--depuis-le-depot --sel-jetable`, rejoue les migrations (qui **créent les dix-sept buckets**),
pose l'adresse des fonctions de cette instance, et crée le compte admin réseau dont le mot de
passe s'affiche une seule fois. Rien de tout cela ne demande de saisie, sauf l'adresse de
courriel de l'admin (question interactive, ou `admin@DOMAINE` par défaut).

`--sel-jetable` : le sel de pseudonymisation du Vault est **fabriqué**. C'est juste pour une
instance neuve. Il ne l'est plus dès qu'on restaure une sauvegarde (§ 6).

## 4. Ce qui se saisit à la main (et où)

Tout vit dans `deploy/functions.env` (créé par `install.sh` depuis `functions.env.example`,
ignoré par git). Sans ces valeurs, l'application tourne, mais :

| Variable | Sans elle | Où l'obtenir |
|---|---|---|
| `RESEND_API_KEY`, `SENDER_EMAIL` | **aucun courriel ne part** (inscriptions, invitations, alertes), et chaque envoi ouvre un incident — c'est voulu, `DOC-SILENCE-1` | un compte Resend ; `SENDER_EMAIL` sur un domaine dont on contrôle le DNS (SPF/DKIM). Une box résidentielle ne peut pas émettre en direct (port 25, pas de rDNS) |
| `ALTCHA_HMAC_SECRET` | inscription et formulaires publics refusés (anti-robot, échec fermé) | `openssl rand -hex 32` |
| `WEBHOOK_SECRET_*`, `GAZETTE_CRON_SECRET` | les dépêches base → fonctions (événements, prêts, gazette) sont refusées | `openssl rand -hex 32` chacun ; **la même valeur doit exister côté base** (secrets du Vault, 21 en production, exportés par le flux de sauvegarde `long`). `install.sh` ne les pose pas aujourd'hui et `bootstrap.sh` ne fabrique que le sel : sur une instance neuve, c'est un point à éprouver (§ 7) ; après restauration, ce sont les valeurs du dump qui comptent |
| `HEALTH_ALERT_CC`, `NETWORK_ADMIN_CC` | les alertes de la sonde (`health-probe`) ne vont qu'aux admins réseau en base | adresses de qui lit les alertes — pour la VM d'essai, ASR2026 |
| `ANTHROPIC_API_KEY` | la gazette ne se compose ni ne se traduit automatiquement | optionnel ; à déclarer si on l'active (LLM en production) |
| `NOMINATIM_URL` | la cartographie ne géocode pas les adresses | optionnel ; `scripts/nominatim/` pour un Nominatim auto-hébergé (lourd) |
| `APP_BASE_URL`, `SITE_BASE_URL`, `APP_ALLOWED_ORIGINS` | liens des courriels vers `app.anarbib.org` au lieu de l'instance ; CORS | l'adresse de l'instance |

Dans `deploy/.env` (généré) : `API_DOMAIN`, `API_EXTERNAL_URL`, `SITE_URL`, `URI_ALLOW_LIST`
suivent le domaine donné à `install.sh --prod`. `STORAGE_FILE_SIZE_LIMIT` est le plafond global
du service Storage : il doit rester au moins égal au plus gros bucket (80 Gio pour le fond de
carte), c'est la valeur de `.env.example`.

## 5. Ce qui se télécharge

| Quoi | Taille | Comment |
|---|---|---|
| Le fond de carte (`map-tiles`, un fichier PMTiles) | 18 Go (z12) à 36 Go (z13) | `scripts/maptiles/README.md` : `extraire-planet.sh` depuis le planet Protomaps, puis `televerser-tus.mjs` vers le bucket `map-tiles` de l'instance. Sans lui, les cartes sont vides mais tout le reste marche |
| Les fichiers des buckets d'une sauvegarde | ≈ 450 Mo | `deploy/ops/anarbib-storage-restore.py --source <sauvegarde storage> --deploy deploy/` **après** la base (le lien est `storage.objects.version`) |

## 6. Exposer, sauvegarder, mettre à jour, restaurer

- **Domaine et TLS** : Caddy obtient le certificat seul si la VM a une IP publique, un
  enregistrement `A` (et `AAAA` seulement si l'IPv6 de la VM est réellement joignable) vers
  elle, et les ports 80 et 443 entrants. Sinon, `deploy/tunnel/README.md` : un VPS frontal
  en passage TCP brut, sans secret. Une seule machine sert le front et l'API (`Caddyfile`,
  `{$API_DOMAIN}`) : un seul nom suffit.
  Pour la VM d'essai d'octobre 2026, le nom est **`essai.anarbib.is`** (zone chez ISNIC,
  hors juridiction américaine). Ce nom est une instance à part, **pas une route de repli de
  la production** : il n'entre ni dans `.domains` de la vitrine, ni dans les sites de
  `ci.yml`, ni dans `URI_ALLOW_LIST` du projet hébergé.
- **Sauvegardes** : [`deploy/ops/vm/`](ops/vm/README.md) — un script lancé par des unités
  système sur la machine elle-même : chaque jour les trois fichiers que `restore.sh` attend
  (recette exacte du CLI Supabase) plus les secrets du Vault, chaque dimanche le volume des
  fichiers, vers un dépôt restic **hors de la machine** ; témoins en base lus par la sonde de
  l'instance. Installation en dix lignes, restauration documentée. (La chaîne `deploy/ops/`
  d'à côté, elle, sauvegarde la production hébergée depuis le poste de maintenance.)
- **Mise à jour** : `deploy/deploy.sh` (git pull, migrations en attente, vues, fonctions,
  front, contrôle de santé). Pas de forge, pas de CI.
- **Restauration d'une sauvegarde réelle** : README § « À lire avant » — le dépôt, les trois
  dumps **et le sel du Vault**. `bootstrap.sh --depuis-une-sauvegarde` refuse de continuer sans
  lui, et refuse `--sel-jetable`. Mesurer les pins GoTrue/Storage avant (`banc-paliers.sh`) :
  l'hébergeur de la production les monte sans prévenir.

## 7. Ce qu'on attend de la VM d'essai

1. `install.sh` sur une machine tierce vierge : ce qui manque, ce qui casse, le temps total.
2. Les dix-sept buckets présents après le rejeu (`bootstrap.sh`, étape 8, est rouge sinon).
3. Une connexion réussie avec le compte admin, une notice créée, une couverture versée.
4. Un courriel réel parti (Resend configuré) ou l'incident de transport ouvert (non configuré).
