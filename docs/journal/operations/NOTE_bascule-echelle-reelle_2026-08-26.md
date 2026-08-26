# NOTE — La bascule éprouvée sur les vraies données

**26/08/2026.** Troisième et dernière passe de la journée : dump de la
production, restauration sur une pile neuve, fichiers des buckets remis en
place, et un objet servi octet pour octet. Destinée à la section
« reconstruction » du runbook de migration.

Les deux passes précédentes (dépôt seul, puis dump synthétique) avaient prouvé
le *mécanisme*. Celle-ci prouve la *chaîne*, et elle a trouvé **deux défauts de
plus** qu'aucune répétition à vide ne pouvait voir.

---

## 1 · Les chiffres qui manquaient au plan de marche

| étape | durée | volume |
|---|---|---|
| `supabase db dump` (schéma) | **249 s** | 2,8 Mo — 71 538 lignes, 208 tables |
| `supabase db dump` (données) | **314 s** | 19 Mo — 63 861 lignes |
| **restauration complète** | **15 s** | |
| versement des fichiers | 5 s | 806 fichiers, 458 Mo |

**Le dump domine largement : 9 min 23 s contre 15 s de restauration.** C'est lui
qu'il faut border le jour J, pas la restauration.

⚠️ Mesures prises **depuis ce poste vers sa-east-1**. Sur la VM de l'hébergeur
elles seront différentes — plus proches du serveur, mais sur un lien et un
disque qu'on ne connaît pas encore. À refaire une fois l'hôte connu ; ces
chiffres-ci donnent l'ordre de grandeur et le rapport entre les étapes.

## 2 · Défaut A — Storage était en retard sur la production

```
ERROR: column "versioning_status" of relation "buckets" does not exist
```

La production porte **65 migrations Storage** ; le pin `v1.60.4` n'en construit
que **61** et ignore `versioning_status`. Le chargement des données mourait donc
à la première ligne de buckets — **c'est-à-dire sur tout dump réel**, puisque la
production a seize buckets.

C'est exactement le problème de GoTrue traité le 26/08 au matin, sur un autre
service : *image ≥ production, jamais l'inverse*. GoTrue avait été vérifié,
Storage non.

| tag | migrations | `versioning_status` |
|---|---|---|
| v1.60.4 | 61 | non |
| v1.67.29 | 61 | non |
| v1.69.0 | 62 | non |
| v1.69.11 | 62 | non |
| v1.70.0 | 63 | **oui** — mais sous la production |
| **v1.70.7** | **65** | **oui — identique à la production** |
| v1.71.0 | 65 | oui (inutile de monter plus haut) |

`v1.70.0` suffirait au dump du jour, mais reste **sous** la production : la règle
tranche pour `v1.70.7`. Concordance vérifiée **table par table** sur `buckets`,
`objects`, `buckets_analytics` et les deux `s3_multipart_*` : jeux de colonnes
égaux, et `vector-buckets` — la dernière migration côté production — est bien
présente.

## 3 · Défaut B — « rsync depuis la sauvegarde storage » était faux

L'en-tête de `bootstrap.sh` l'affirmait depuis le début. Les deux dispositions
n'ont rien à voir :

```
sauvegarde : covers/books/0000046/1773334818127-41Tq7ZVw2KL.jpg
             └─ un fichier ordinaire, tel que `supabase storage cp` le pose

service    : anarbib/anarbib/covers/essai/photo.png/86fefe96-c622-4e1a-…
             └ s3 ┘└ tenant ┘└bucket┘└─ nom = DOSSIER ─┘└ fichier = UUID version ┘
```

Le **nom de l'objet devient un dossier**, et le fichier porte l'**UUID de
version**. Un `rsync` aurait donc produit une arborescence que le service ne lit
pas : **404 sur une base pourtant complète** — un catalogue sans une seule
couverture, et rien pour le signaler.

Trouvé en observant plutôt qu'en supposant : téléverser un objet par l'API, puis
regarder où il atterrit sur le disque.

**Conséquence d'ordre, et elle est structurelle.** Le lien entre les deux
dispositions est `storage.objects.version`, qui vit **dans la base**. Les
fichiers se remettent donc **après** elle, jamais avant. C'est le troisième
défaut d'ordre de la journée, de la même famille que les cinq déjà documentés.

D'où [`deploy/ops/anarbib-storage-restore.py`](../../../deploy/ops/anarbib-storage-restore.py),
qui fait la transposition, lit `TENANT_ID` et `GLOBAL_S3_BUCKET` dans le compose
plutôt que de les deviner, et signale les deux écarts qui comptent.

## 4 · Deux écarts à connaître, relevés par l'outil

- **7 objets sans fichier.** La base connaît un objet dont la sauvegarde n'a pas
  le fichier. Rien d'anormal ici : la sauvegarde `storage` datait de 09:48, le
  dump de 16:00 — **les deux ne sont pas prises au même instant et elles
  dérivent**. Le jour de la bascule : les prendre au plus près l'une de l'autre,
  et lire ce compteur.
- **88 fichiers orphelins.** L'inverse — des fichiers que plus aucune ligne ne
  désigne. Sans gravité, ils ne sont pas versés.

## 5 · Concordance avec la production : sept compteurs sur sept

| | production | restaurée |
|---|---|---|
| notices | 2 676 | **2 676** |
| bibliothèques | 5 | **5** |
| comptes | 15 | **15** |
| subjects | 54 | **54** |
| buckets | 16 | **16** |
| objets | 812 | **812** |
| exemplaires | 2 741 | **2 741** |

0 table publique sans RLS. Vues matérialisées peuplées. Les **cinq** buckets sans
plafond sont exactement ceux de la production. Et
`✓ L'API rend des bibliothèques sur une base qui en contient 5.`

**Preuve de bout en bout** : une image téléchargée par l'API publique est
identique à l'octet près à l'original de la sauvegarde — SHA-256 concordant,
12 176 octets.

## 6 · Le sel, tiré de la copie froide

La restauration a été faite avec le **vrai** sel de pseudonymisation, extrait du
dépôt restic **hors ligne** (21 secrets du Vault), pas avec un sel fabriqué. Le
fichier a été effacé du disque aussitôt après injection. C'est donc aussi une
épreuve de la copie froide : elle sert à quelque chose, et on l'a vérifié.

## 7 · Ce qui reste

- **Refaire les chronos sur l'hôte réel**, une fois connu. Ceux-ci ne
  transfèrent pas.
- **Les données personnelles.** Dump et pile de répétition effacés en fin de
  passe (le dossier `deploy/dumps/` porte son `LISEZ-MOI` : *effacer après
  usage*).
- Rien n'a été fait sur le DNS ni les certificats : Caddy a servi en
  `https://localhost`, certificat auto-signé.
