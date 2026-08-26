# NOTE — Ce que le témoin de sauvegarde prouve, et ce qu'il ne prouve pas

**26/08/2026.** Clôture du point 7.1 du plan de marche (« témoin des flux `long`
et `storage` »), ouvert le 20/08 avec une échéance au ~28/08. Migration
`20260826170000_temoin_purge_amorcage_et_portee_instantane`.

---

## 1 · L'échéance n'a pas eu lieu, et c'est mesuré

Le constat du 20/08 était : `long` et `storage` n'avaient **aucun témoin réel**,
ils étaient tenus en vert par une ligne de semis posée par la migration
d'amorçage. L'alarme n'était pas cassée, elle était aveugle.

État relevé en base le 26/08 avant d'écrire une ligne :

| flux | dernier témoin `ok` | hôte | `snapshot_id` |
|---|---|---|---|
| `court` | 26/08 07:36:38 UTC | ACCATTONE | `4359105d` |
| `long` | 26/08 07:35:43 UTC | ACCATTONE | `5740d6a6` |
| `storage` | 26/08 07:48:49 UTC | ACCATTONE | `3a36373d` |

Les trois flux ont parlé pour de vrai, depuis l'hôte réel, avec un identifiant
d'instantané. `long` et `storage` ont même chacun **quatre** témoins réels
depuis le 22/08. La condition posée le 20/08 pour purger — « pas avant qu'un
témoin réel soit arrivé pour chaque flux » — est donc remplie, et c'est la
seule raison pour laquelle la purge se fait maintenant.

Les trois autres demandes du point 7.1 étaient déjà satisfaites, vérification
faite plutôt que refaite :

- **`host` exposé** : depuis `20260820012343`, et la production tourne bien
  cette version (contrôlé sur `pg_get_functiondef`).
- **`snapshot_id` renseigné** : depuis BG2-15, par `snapshot_id_de()` dans
  `deploy/ops/anarbib-bg2.sh`, qui relit le dépôt restic après le tir.
- **témoin réel pour `long` et `storage`** : présent, cf. tableau.

## 2 · La portée du témoin, écrite noir sur blanc

C'est la question laissée ouverte le 20/08. Réponse :

- Un témoin `ok` prouve que **le script est allé au bout** de son flux.
- Avec un `snapshot_id`, il prouve **en plus** qu'un instantané portant cette
  étiquette était **listable dans le dépôt restic juste après le tir** — ce
  n'est pas rien : c'est une relecture effective du dépôt, pas une déclaration
  du script sur lui-même.
- Il ne prouve **pas** que cet instantané est **restaurable**. Seul le
  `restore-test` mensuel le prouve. **Un témoin vert n'est jamais une garantie
  de restauration**, et c'est la phrase à retenir le jour où on lira ce tableau
  pour de vrai.
- Une ligne `phase='started'` porte légitimement `snapshot_id` à `NULL` : au
  départ, l'instantané n'existe pas encore.

## 3 · Ce que la migration change

1. **Purge des semis** des flux ayant un témoin réel. Le prédicat est
   générique — « tout flux ayant un `ok` réel » — et non une liste d'identifiants :
   rejouée sur une base reconstruite où les témoins réels n'existent pas encore,
   elle ne supprime rien. Elle est donc sûre dans les **deux ordres de rejeu**,
   ce qui compte pour la bascule auto-hébergée.

   Aucun comportement d'alarme ne change : la fonction ignore déjà les semis
   depuis le 20/08. Ce qui disparaît, c'est une ligne qui **ment à la lecture
   directe de la table** — le genre de ligne qu'on relit un jour de restauration
   en croyant qu'un tir a eu lieu le 19/08 à 14:53.

2. **Nouveau champ `instantane_atteste`**, informatif. Il dit si le dernier
   témoin d'arrivée retenu porte un identifiant d'instantané. Sa raison d'être
   est le jour où `snapshot_id` **redeviendra** nul — `restic snapshots` muet,
   dépôt injoignable à la relecture : aujourd'hui la fonction n'y verrait rien,
   le témoin partirait quand même, `ok` resterait vrai, et l'information se
   perdrait jusqu'au jour de la restauration.

   Comme `temoin_amorcage`, il **ne bascule pas `ok`**. Un instantané non
   attesté n'est pas une panne de sauvegarde, c'est un angle mort — et on
   n'apprend pas aux gens à ignorer une alarme.

`health-probe` n'a pas besoin d'être modifié : les champs qu'il consomme
(`ok`, `flux[].muet`, `.flow`, `.age_heures`, `.raison`, `.interrompu`,
`.temoin_amorcage`) sont tous conservés à l'identique, et la migration le
vérifie par un `DO` bloquant.

## 4 · Épreuve, faite avant de livrer

Sur une base jetable dans le conteneur Postgres local — ni la production ni la
base de dev n'ont été touchées. La chaîne complète des cinq migrations du
témoin a été rejouée **dans l'ordre du dépôt**, puis la nouvelle :

| Ce qu'on voulait prouver | Résultat |
|---|---|
| Les six migrations rejouent sur une base vierge | 6/6 OK |
| Reconstruction neuve : les semis **survivent** (aucun tir réel) | 3 semis conservés, `ok=true` |
| État façon production : la purge retire les semis | 3 lignes supprimées, 0 survivant |
| Rejeu de la migration sur cet état (idempotence) | OK, 0 ligne supprimée |
| Un `ok` sans instantané ne bascule pas `ok` | `instantane_atteste=false`, `ok=true` |
| L'alarme se déclenche toujours (silence forcé sur `long`) | `ok=false`, « long muet depuis 240.0 h » |

## 5 · Un piège relevé au passage, à ne pas reproduire

La migration `20260821050000` se termine par un `raise exception` si `ok` n'est
pas vrai. **Là où elle est, c'est sans danger** : elle s'exécute après
l'amorçage, sur des témoins frais. Mais c'est un motif à ne pas généraliser —
le jour où l'on rejoue le dépôt sur une base restaurée depuis un dump ancien,
les témoins y sont vieux, `ok` est faux **à bon droit**, et la reconstruction
s'arrêterait sur une alarme en train de faire exactement son travail. Sur la
chaîne de bascule, ce serait une panne de reprise causée par le dispositif de
surveillance.

La nouvelle migration vérifie donc la **structure** et la cohérence de la purge,
jamais la valeur de `ok`.

## 6 · Ce qui reste ouvert

- **Dimensionnement de `storage`** (déjà porté au plan de marche le 20/08) :
  11 min 18 s pour 430 Mo, contre 11 à 27 Go visés par la numérisation. À cette
  échelle le flux dépassera le `TimeoutStartSec=1800`, systemd le tuera, et
  l'alarme sonnera — **correctement**, mais toutes les semaines.
- Le témoin ne dira jamais si un instantané est restaurable. C'est le
  `restore-test` mensuel qui porte cette preuve, et lui seul.
