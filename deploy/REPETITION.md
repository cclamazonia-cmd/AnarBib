# AnarBib — la répétition, étape par étape

**Utiliser `AnarBibdeploy_1.zip`** (celui qui contient `main/index.ts`).
L'autre est une version antérieure, sans le routeur — jetez-la.

**Où faire la répétition : chez vous, pas sur un VPS.** Vous avez déjà Docker
Desktop installé (il est apparu dans `wsl -l -v`). Ça ne coûte rien, ça se
recommence autant de fois qu'on veut, et ça répond exactement à la question
qu'on veut trancher. Le VPS jetable ne servira qu'à la confirmation finale.

Comptez deux ou trois heures la première fois, et **attendez-vous à ce que ça
casse**. C'est le but : chaque erreur rencontrée ici est une erreur qui
n'arrivera pas chez Herbes Folles.

---

## Étape 1 — Poser les fichiers au bon endroit

Le `compose.yml` va chercher `../supabase/migrations` et
`../supabase/config.toml`. Il doit donc vivre dans un dossier `deploy/` **à la
racine du dépôt**.

```powershell
cd C:\Users\accat\Codeberg\anarbib
mkdir deploy
# Dézippez AnarBibdeploy_1.zip dans ce dossier deploy\
# Puis déplacez le routeur à sa vraie place :
mkdir supabase\functions\main
move deploy\main\index.ts supabase\functions\main\index.ts
rmdir deploy\main
rename deploy\env.example.txt .env.example
```

Vous devez obtenir :

```
anarbib\
  deploy\        compose.yml, Caddyfile, README.md, .env.example
  supabase\
    functions\
      main\index.ts        ← le routeur
    config.toml
    migrations\            ← 120 fichiers
```

**Ajoutez tout de suite `deploy/.env` et `deploy/functions.env` au
`.gitignore`.** Ils contiendront vos secrets, ils ne doivent jamais partir sur
Codeberg.

---

## Étape 2 — Épingler les versions

Les six tags dans `.env` sont vides. Récupérez-les depuis le `docker-compose.yml`
officiel de Supabase (dépôt `supabase/supabase`, dossier `docker`) : cherchez les
lignes `image:` des services `db`, `rest`, `auth`, `storage`, `functions`, et
recopiez le tag qui suit les deux-points. Pour Caddy, prenez la dernière version
stable annoncée sur leur site.

Exemple de ce que ça donne (les valeurs sont à vous de les relever, ne recopiez
pas celles-ci) :

```
POSTGRES_TAG=15.8.1.xxx
POSTGREST_TAG=v12.x.x
GOTRUE_TAG=v2.xxx.x
STORAGE_TAG=v1.xx.x
EDGE_RUNTIME_TAG=v1.xx.x
CADDY_TAG=2.x
```

---

## Étape 3 — Fabriquer les secrets

```powershell
cd C:\Users\accat\Codeberg\anarbib\deploy
copy .env.example .env
```

Puis, dans un terminal WSL ou Git Bash :

```bash
openssl rand -base64 36    # → POSTGRES_PASSWORD
openssl rand -base64 48    # → JWT_SECRET
```

Reportez les deux valeurs dans `.env`.

### Les deux clés dérivées

`ANON_KEY` et `SERVICE_ROLE_KEY` ne sont pas des mots de passe : ce sont des
jetons JWT signés avec votre `JWT_SECRET`. Créez `deploy/genkeys.mjs` :

```js
import crypto from 'node:crypto';
const secret = process.argv[2];
if (!secret) { console.error('usage: node genkeys.mjs <JWT_SECRET>'); process.exit(1); }
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const exp = now + 60 * 60 * 24 * 365 * 10;          // 10 ans
const make = (role) => {
  const h = b64({ alg: 'HS256', typ: 'JWT' });
  const p = b64({ role, iss: 'supabase', iat: now, exp });
  const s = crypto.createHmac('sha256', secret).update(`${h}.${p}`).digest('base64url');
  return `${h}.${p}.${s}`;
};
console.log('ANON_KEY=' + make('anon'));
console.log('SERVICE_ROLE_KEY=' + make('service_role'));
```

```powershell
node genkeys.mjs "<votre JWT_SECRET>"
```

Collez les deux lignes obtenues dans `.env`.

> `ANON_KEY` est publique (elle finit dans le bundle du navigateur).
> `SERVICE_ROLE_KEY` ouvre tout : jamais dans le front, jamais dans le dépôt.

### En local, les domaines changent

Pour la répétition sur votre machine, mettez dans `.env` :

```
API_DOMAIN=localhost
API_EXTERNAL_URL=http://localhost
SITE_URL=http://localhost:5173
URI_ALLOW_LIST=http://localhost:5173,http://localhost:5173/*
```

Et dans le `Caddyfile`, remplacez la première ligne `{$API_DOMAIN} {` par
`http://localhost {` — sinon Caddy tentera d'obtenir un certificat Let's Encrypt
pour `localhost` et échouera.

### Les secrets des fonctions

Créez `deploy/functions.env` à partir du `.env.example` **du dépôt** (celui qui
liste `RESEND_API_KEY`, les `WEBHOOK_SECRET_*`, etc.). Pour la répétition, vous
pouvez mettre des valeurs bidon partout **sauf** là où vous voulez tester
réellement l'envoi de courriels.

---

## Étape 4 — Démarrer

```powershell
cd C:\Users\accat\Codeberg\anarbib\deploy
docker compose up -d
docker compose ps
```

Les six services doivent apparaître. `db` doit passer en `healthy` (comptez
trente secondes à une minute au premier démarrage).

Si un service redémarre en boucle :

```powershell
docker compose logs --tail=50 <nom du service>
```

**Le premier à surveiller est `functions`.** S'il refuse de démarrer en disant
`config.toml illisible`, c'est le montage qui ne passe pas — sous Windows,
vérifiez que le partage de fichiers Docker Desktop couvre bien
`C:\Users\accat\Codeberg`.

---

## Étape 5 — Les quatre tests du routeur

**Faites-les avant tout le reste.** Tant qu'ils ne passent pas, brancher la base
et le front ne sert à rien.

```bash
# 1. Nom inexistant → attendu : 404
curl -i http://localhost/functions/v1/nexiste-pas

# 2. Fonction dispensée de JWT → attendu : 200 (ou une erreur métier, pas 401)
curl -i http://localhost/functions/v1/health-probe

# 3. Fonction protégée SANS jeton → attendu : 401
curl -i http://localhost/functions/v1/cover_lookup

# 4. La même AVEC le jeton anon → attendu : autre chose que 401
curl -i http://localhost/functions/v1/cover_lookup \
  -H "Authorization: Bearer <ANON_KEY>"
```

Le test n°3 est le plus important de toute la répétition. S'il renvoie autre
chose que 401, une fonction qui devrait être protégée ne l'est pas — **arrêtez
tout et corrigez** avant d'aller plus loin.

---

## Étape 6 — La base

Deux chemins, et il faut les essayer tous les deux, car ils répondent à deux
questions différentes.

### A. Rejouer les migrations — « puis-je rebâtir depuis le dépôt seul ? »

```powershell
docker compose exec -T db bash -lc 'for f in /migrations/*.sql; do echo "== $f"; psql -v ON_ERROR_STOP=1 -U postgres -d postgres -f "$f" || exit 1; done'
```

Ça s'arrête à la première erreur en vous disant laquelle. **Notez chaque
migration qui casse** : c'est la liste des endroits où votre historique n'est
pas rejouable, et c'est une information précieuse indépendamment de
l'hébergement.

### B. Restaurer un dump — « puis-je récupérer après un sinistre ? »

Depuis un volume vierge (`docker compose down -v` puis `up -d`) :

```powershell
supabase db dump --db-url "<URL de votre base Supabase>" -f dump.sql
docker compose exec -T db psql -U postgres -d postgres < dump.sql
```

C'est ce chemin-là qui compte le jour d'une panne réelle.

---

## Étape 7 — Le front pour de vrai

C'est le seul test qui prouve quelque chose. À la racine du dépôt, créez
`.env.local` :

```
VITE_SUPABASE_URL=http://localhost
VITE_SUPABASE_ANON_KEY=<ANON_KEY>
```

Puis :

```powershell
cd C:\Users\accat\Codeberg\anarbib
npm install
npm run dev
```

Ouvrez `http://localhost:5173` et **connectez-vous avec un vrai compte**. Si la
connexion passe, si le catalogue s'affiche, si une couverture apparaît — la
bascule est démontrée.

---

## Étape 8 — Ce que vous notez

Le chiffre à rapporter à Herbes Folles n'est pas « le compose démarre », c'est
**le temps entre une machine vide et une connexion réussie depuis un front
reconstruit**. Notez :

- la durée totale ;
- ce qui a cassé, et comment vous l'avez réparé ;
- les migrations non rejouables, s'il y en a ;
- les points où vous avez dû improviser — ce sont vos zones d'ombre réelles,
  et elles valent mieux que n'importe quelle auto-évaluation.

Ce document devient alors la première version de votre runbook.

---

## Deux pièges Windows

**Fins de ligne.** Si Git convertit en CRLF, le `Caddyfile` et les scripts shell
peuvent se comporter bizarrement. Au moindre doute :

```powershell
git config core.autocrlf false
```

**Partage de fichiers Docker Desktop.** Les montages `../supabase/...` ne
fonctionnent que si le lecteur est autorisé dans Docker Desktop →
Settings → Resources → File sharing.
