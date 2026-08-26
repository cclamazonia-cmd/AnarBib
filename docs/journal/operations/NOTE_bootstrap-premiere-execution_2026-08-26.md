# NOTE — Première exécution complète de `bootstrap.sh`

**26/08/2026.** Le script avait été lancé une fois, le 20/08, et s'était arrêté
tôt (la leçon en est restée dans `run-migrations.sh` : le garde-fou « la base
n'est PAS vierge »). Il n'était jamais allé au bout. C'est fait : deux passes,
six défauts relevés, tous corrigés, **exécution finale verte de bout en bout**.

Destinée à devenir la section « reconstruction » du runbook de migration, une
fois l'hôte connu.

---

## 1 · Le résultat

```
./bootstrap.sh --depuis-le-depot --sel-jetable      → code de sortie 0
```

| Mesure | Valeur |
|---|---|
| Migrations rejouées | **183 / 183**, en **12 secondes** |
| Tables publiques | 184 |
| Tables publiques sans RLS | **0** |
| Fonctions `api.*` | 173 |
| Migrations GoTrue construites | **77** — la production exactement |
| Vues matérialisées vides | 0 |
| Chaîne HTTP (`auth`, `storage`, `rest`) | 3 × 200 via Caddy |

Conditions : volumes vierges, Docker sous WSL2, aucune donnée de production
restaurée, sel de pseudonymisation jetable.

## 2 · Les six défauts, et ce qu'ils coûtaient

### a. Le projet Docker entrait en collision avec la pile de développement

`deploy/compose.yml` déclarait `name: anarbib`. Or le CLI Supabase nomme **son**
projet Compose d'après `supabase/config.toml`, où `project_id = "anarbib"`. Les
deux piles vivaient donc dans le même projet Docker.

Conséquence directe : le `docker compose down -v` que `bootstrap.sh` recommande
en tête pour « repartir vraiment de zéro » **démontait la pile de dev de la
personne qui l'exécutait**, sans le dire. C'est la commande qu'on tape un jour
de sinistre, sur un poste qu'on ne connaît pas forcément.

Corrigé : `name: anarbib-selfhost`, avec en commentaire la raison de ne pas
revenir en arrière. Vérifié : après le démontage complet de la pile d'essai, la
pile de dev était toujours debout.

### b. `--wait` n'attend pas ce qu'on croit

`docker compose up -d --wait` n'attend une sonde que **là où il y en a une**, et
`compose.yml` n'en déclare qu'**une seule** : celle de `db`. Pour les cinq
autres services, il rend la main dès que le conteneur est « running ».

Deux dégâts en cascade, tous deux constatés à la passe 1 :

- l'étape 8 trouvait `storage.buckets` absent et s'abstenait ;
- le contrôle HTTP prenait un **502 sur Storage**, service parfaitement sain,
  simplement pas encore là.

Un 502 dans un journal de reconstruction envoie chercher une panne de routage
qui n'existe pas. Mesuré après correction : Storage met **4 secondes** à
construire son schéma après que `--wait` a rendu la main.

Corrigé : étape « 7 bis », qui attend un **fait** (`storage.buckets` existe),
comme l'étape 4 le fait déjà pour GoTrue.

### c. L'étape 8 annonçait un succès qu'elle n'avait pas vérifié

La migration écrivait `storage.buckets absent : plafonds NON appliqués`, et le
script répondait `✓ Plafonds et types autorisés posés sur les buckets` deux
lignes plus bas. **Faux vert sur la seule étape qui borne la taille des fichiers
téléversés.**

Et le corriger sans regarder aurait fabriqué le défaut suivant : la migration
**lève une exception** si un bucket attendu manque. Une fois (b) réparé,
`storage.buckets` existe mais est **vide** en mode dépôt — la rejouer telle
quelle aurait tué le script à l'étape 8. Chaque correction se vérifie sur la
suivante.

### d. Aucune migration ne crée les buckets

Constat de fond, découvert en réparant (c) : les migrations ne font
qu'`update storage.buckets`. **Aucune ne crée de bucket.** Une reconstruction
« depuis le dépôt seul » produit donc une instance à **zéro bucket** — les
seize de la production arrivent avec le dump, et leurs fichiers par `rsync`
depuis la sauvegarde `storage`.

L'en-tête du script affirmait le contraire (« les PLAFONDS des buckets, eux,
sont posés »). C'est vrai en mode sauvegarde, faux en mode dépôt. L'étape 8 le
dit désormais explicitement au lieu de le passer sous silence.

### e. Le contrôle « RLS sans policy » n'avait jamais fonctionné

Il rougissait **toujours**, dans les deux sens à la fois : les quinze tables
apparaissaient « en trop » *et* « manquantes ».

Cause : le `tr` retirait un **saut de ligne littéral** au lieu d'un retour
chariot. Les quinze noms arrivaient collés en une seule chaîne, que `comm`
comparait à une liste de quinze lignes.

Le soin mis à écrire ce contrôle — « une LISTE et non un compte », pour qu'il
nomme la table au lieu de la faire chercher — était donc entièrement perdu. Un
contrôle rouge par construction s'apprend vite à ignorer, c'est-à-dire qu'il ne
contrôle plus rien. Corrigé (`tr -d '\r'`) : **✓ conformes à la liste attendue (15)**.

### f. `--depuis-le-depot` ne pouvait aboutir sur aucune base vierge

Le script exigeait `pseudonym_salt` au Vault dans **les deux modes**, et
s'arrêtait sinon — correctement, code 1. Mais le sel n'est reconstructible
depuis rien : sur une base vraiment vierge, sans Vault sous la main,
`--depuis-le-depot` **ne pouvait jamais aboutir**. Le mode censé répondre à la
question de l'hébergeur (« peut-on reconstruire depuis le dépôt seul ? »)
répondait donc « non, jamais ».

Or le danger n'est pas le sel neuf : c'est le sel neuf **posé sur des données
anciennes**. Sur une installation neuve, aucun jeton n'existe encore.

Corrigé : `--sel-jetable`, explicite, bruyant, et **refusé d'emblée** en
combinaison avec `--depuis-une-sauvegarde` — la seule combinaison qui produit la
corruption silencieuse.

### bonus. Deux chiffres périmés

- l'aide promettait « rejeu des migrations (158) » ; il y en a 183 ;
- le contrôle de version GoTrue portait « image v2.189.0 → 69 ». Faux :
  69 comptait des **fichiers embarqués**, 77 des **lignes en base**. Remplacé
  par les mesures réelles (§3).

## 3 · Mesure des paliers GoTrue, refaite au banc

Une base vierge par palier, image lancée seule contre elle :

| tag | lignes `auth.schema_migrations` | dernière version | contient `20260625000000` |
|---|---|---|---|
| v2.189.0 | 76 | 20260302000000 | non |
| v2.190.0 | 76 | 20260302000000 | non |
| v2.191.0 | 76 | 20260302000000 | non |
| **v2.192.0** | **77** | **20260625000000** | **oui** |

Production : 77 lignes, dernière `20260625000000`. Le pin `GOTRUE_TAG=v2.192.0`
est donc le **minimum nécessaire** — 190 et 191 ne suffisent pas — et non un
saut de confort. La règle « image ≥ production, jamais l'inverse » est tenue.

## 4 · Ce que cette exécution ne prouve pas

- **Rien sur les données.** Aucun dump restauré : 0 notice, 0 bibliothèque. Le
  contrôle « le catalogue n'est pas vide » n'avait pas d'objet, et c'est
  justement celui qui attrape le sinistre « PostgREST a lu le schéma avant les
  données ». Il reste à éprouver en mode `--depuis-une-sauvegarde`.
- **Rien sur les fichiers Storage** (~430 Mo), ni sur les buckets eux-mêmes.
- **Rien sur le sel réel.** Le sel utilisé est jetable. Une bascule véritable
  exige les trois choses, pas deux : le dépôt, une sauvegarde, **et** les
  secrets du Vault.
- **Rien sur le DNS ni les certificats** : Caddy a servi en `https://localhost`,
  certificat auto-signé, `curl -k`.

## 5 · La connexion authentifiée en local est débloquée

Vérifié sur cette même pile, parce que le plan de marche en faisait un préalable
à toute location de VM. Le blocage du 04/07 — le conteneur résolvait
`challenges.cloudflare.com` en IPv6 seulement, sans route IPv6 — a bien disparu
de lui-même : Turnstile a été retiré (AR-2/AR-3, remplacé par ALTCHA, qui ne
sort pas du réseau). Il n'en reste que des commentaires historiques dans le code.

| Étape | Résultat |
|---|---|
| Création d'un compte (API admin GoTrue, clé de service) | HTTP 200 |
| Connexion directe GoTrue (`grant_type=password`) | HTTP 200, jeton émis |
| **Connexion par le chemin de l'application** (Edge Function `login`) | **HTTP 200, jeton émis** |
| Appels à `challenges.cloudflare.com` dans les journaux | **0** |

Le troisième point est celui qui compte : il traverse le routeur `main` de
`edge-runtime` (46 fonctions montées, 30 dispensées de JWT), donc il prouve que
la brique Edge Functions de la pile auto-hébergée fonctionne, pas seulement
GoTrue.

**Cinq minutes qui épargnent une VM montée pour rien**, comme le plan
l'espérait.

## 6 · Suite

1. Rejouer en `--depuis-une-sauvegarde` sur un dump réel : c'est la passe qui
   éprouve (d), le contrôle « catalogue non vide », et l'ordre PostgREST.
2. Décider si les buckets doivent être créés par une migration idempotente —
   aujourd'hui ils n'existent que dans le dump.
3. Envisager de vraies sondes dans `compose.yml` pour les cinq services qui
   n'en ont pas ; l'attente ajoutée à l'étape 7 bis les compense, elle ne les
   remplace pas.
