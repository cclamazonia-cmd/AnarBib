# AnarBib — pile auto-hébergée : mode d'emploi

Trois fichiers : `compose.yml`, `Caddyfile`, `.env` (depuis `.env.example`).
Six services au lieu des douze du compose officiel Supabase. Justification de
chaque suppression : voir `AUDIT_pile_minimale_2026-08-17`.

**Ce document décrit un état à atteindre, pas un état atteint.** Rien de tout
ceci n'a encore tourné : c'est la matière de la répétition sur machine jetable.

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

- **`notify-cross-library-digest`.** Appelée depuis une migration, absente du
  dépôt. `supabase functions list` tranchera. Si elle n'existe qu'en production,
  elle disparaît à la première reconstruction.

- **Le rejeu des migrations.** Le montage `docker-entrypoint-initdb.d` ne
  s'exécute qu'au tout premier démarrage, sur un volume vide. Pour une
  reconstruction, c'est ce qu'on veut ; pour une mise à jour, il faut passer par
  la CLI. `bootstrap.sh` devra distinguer les deux cas.

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
| `imgproxy` | aucune transformation d'image demandée à Storage |
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
