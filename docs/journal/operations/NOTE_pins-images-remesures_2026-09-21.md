# NOTE — Les pins GoTrue et Storage remesurés : la production avait monté seule

**21/09/2026.** Un plan de marche de la fin août a été relu contre les pièces :
quatre chantiers et un préalable. Trois étaient déjà faits et documentés ; le
quatrième l'est pour sa moitié. Mais en vérifiant le second — « aligner l'image
GoTrue » — la mesure a montré qu'il s'était **rouvert tout seul**.

---

## 1 · Le plan relu contre les faits

| Point du plan | État constaté le 21/09 | Pièce |
|---|---|---|
| Témoin de sauvegarde : exposer l'hôte, purger les semis | **Fait.** Le statut expose `host`, `temoin_amorcage`, `snapshot_id` ; les semis sont purgés. En production : `backup_heartbeats` ne porte plus que l'hôte réel, pour les trois flux (`long` : 7 témoins `ok`, `storage` : 8, tous avec instantané). La nuance « un témoin prouve que le script est allé au bout, pas qu'un instantané existe » est écrite dans le commentaire de la fonction. | migrations `20260820012343`, `20260826170000` |
| Aligner l'image GoTrue | Fait le 26/08 (v2.192.0 → 77)… **et périmé depuis** : voir §2. | `NOTE_bootstrap-premiere-execution_2026-08-26` §3 |
| Première exécution de `bootstrap.sh` | **Fait** le 26/08 (trois passes, huit défauts). Refait ce jour aux nouveaux pins : §3. | même note |
| Découpler la CI | **Fait pour le backend** : `scripts/ci/deployer-backend.sh`, que `ci.yml` appelle (commit `3fab3741`) ; `deploy/deploy.sh` pour une instance auto-hébergée. **Pas pour le front** : §5. | `ci.yml` job `backend` |
| Préalable : connexion authentifiée en local | **Fait** le 26/08 (§5 de la note). Refait ce jour : §4. | même note |

Une contradiction à lever au backlog : `I21` dit encore « la connexion
authentifiée sur la pile locale jamais retestée depuis le retrait de
Turnstile ». La note du 26/08 la décrit faite, et elle vient d'être refaite.

## 2 · Ce que la mesure a trouvé

L'hébergeur actuel met à jour GoTrue et Storage de lui-même, sans prévenir.
Relevé en production le 21/09 :

| | 26/08 | 21/09 | version servie |
|---|---|---|---|
| lignes `auth.schema_migrations` | 77, dernière `20260625000000` | **82**, dernière `20260831180000` | GoTrue **v2.197.0** (`/auth/v1/health`) |
| lignes `storage.migrations` | 65 | **68**, dernière `objects-null-version-index` | Storage **1.73.1** (`/storage/v1/version`) |

Les deux pins de `deploy/` (v2.192.0, v1.70.7) étaient donc repassés **sous**
la production. La règle « image ≥ production, jamais l'inverse » était violée
depuis une date inconnue, et rien ne pouvait le dire : le contrôle (e) de
`bootstrap.sh` comparait à un « 77 » écrit en dur, c'est-à-dire à la production
du 20 août.

Banc refait, même méthode que le 26/08 — une base vierge
(`supabase/postgres:17.6.1.136`) par palier, l'image lancée seule contre elle,
lecture du décompte une fois stabilisé :

| GoTrue | lignes | dernière |
|---|---|---|
| v2.192.0 *(témoin)* | 77 | 20260625000000 |
| v2.193.0, v2.193.1, v2.194.0, v2.195.0, v2.196.0 | 77 | 20260625000000 |
| **v2.197.0** | **82** | **20260831180000** |

| Storage | migrations | dernière |
|---|---|---|
| v1.70.7 *(témoin)*, v1.71.0 | 65 | fix-search-by-timestamp-sqli |
| **v1.72.0** | **68** | **objects-null-version-index** |
| v1.72.11, v1.73.0, v1.73.1 | 68 | objects-null-version-index |

Les deux témoins rendent exactement les chiffres du 26/08 : le banc est le
même instrument. Minimums nécessaires : **`GOTRUE_TAG=v2.197.0`** (les cinq
migrations neuves arrivent toutes avec lui — c'est aussi la version de la
production) et **`STORAGE_TAG=v1.72.0`**, dont les migrations 61 à 68 portent
les noms de la production, un pour un.

Concordance des colonnes, pile GoTrue v2.197.0 + Storage v1.72.0 sur base
vierge : les **342 colonnes** des schémas `auth` et `storage` de la production
s'y retrouvent, nom et type, même empreinte md5 des deux côtés. L'image crée en
plus `storage.iceberg_namespaces` et `storage.iceberg_tables` (18 colonnes),
absentes de la production : sur-ensemble, sans effet sur un dump.

## 3 · L'épreuve : `bootstrap.sh` aux nouveaux pins

```
./bootstrap.sh --depuis-le-depot --sel-jetable      → vert, 45 secondes
```

Volumes vierges, pile de développement laissée debout à côté. 325/325
migrations en 21 s ; 0 table publique sans RLS ; 24 tables RLS sans policy,
conformes ; vues matérialisées peuplées ; **GoTrue 82 / Storage 68** ; trois
`200` à travers Caddy. Pile démontée ensuite (`down -v`) : Docker est revenu à
ses trois volumes, les douze conteneurs de dev n'ont pas bougé.

Ce que cette passe ne prouve pas : la restauration d'un **dump réel** sous ces
deux images. La concordance des colonnes la rend probable ; seule la passe
`--depuis-une-sauvegarde` la prouvera.

## 4 · Le préalable, refait sur cette pile

| Étape | Résultat |
|---|---|
| Création d'un compte jetable (API admin GoTrue) | HTTP 200 |
| Connexion directe GoTrue (`grant_type=password`) | HTTP 200, jeton émis |
| **Connexion par l'Edge Function `login`** | **HTTP 200, jeton émis** |
| Mauvais mot de passe par le même chemin | HTTP 401 |
| Le jeton lit `rest/v1/libraries` | HTTP 200 |
| « cloudflare » ou « turnstile » dans les journaux des six conteneurs | **0** |

## 5 · Ce qui reste réellement

1. **Le seuil ne doit plus pouvoir périmer en silence.** Ce jour, les deux
   seuils de `bootstrap.sh` portent leur date et le script la répète à l'écran ;
   le contrôle couvre désormais Storage, qu'il ignorait. C'est une rustine
   honnête, pas un remède : la dérive n'est vue que si quelqu'un remesure. Le
   remède serait que la sonde de santé compare chaque jour la production à un
   chiffre attendu et alerte quand elle le dépasse — à arbitrer.
2. **Le front n'a pas de chemin hors forge.** `npm run deploy` est retiré
   depuis la bascule git-pages ; la publication passe par une action Codeberg
   vers `codeberg.page`. Une suspension de la forge emporte donc à la fois le
   moyen de publier *et* l'hébergement du front. Côté pile auto-hébergée, Caddy
   sert `dist/` : la réponse existe, elle est à I2.
3. **La passe sur dump réel** sous les nouvelles images (§3).
4. **Le `deploy/.env` du poste** porte encore les anciens tags : il n'est pas
   versionné, il ne suit pas `.env.example`. À réaligner avant le prochain essai
   local.
