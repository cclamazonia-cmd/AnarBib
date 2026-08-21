# NOTE — Le prune sort du tir de sauvegarde (BG2-17)

**21/08/2026.** Le `forget --prune` des trois flux #BG2 devient un tir mensuel
autonome. Cette note dit ce qui change, la mesure qui l'a motivé, ce que le
report coûte, et comment le vérifier. Elle porte aussi quatre constats faits le
même jour, dont une correction à un chiffre du plan de marche.

---

## 1 · Ce qui change

| Avant | Après |
|---|---|
| `restic forget … --prune` dans chacun des trois flux | `restic forget … --no-prune` dans chacun des trois flux |
| Le prune tombait au hasard d'un tir de sauvegarde | Unité `anarbib-backup-prune`, le **1er du mois à 22:30 Europe/Paris** |

Trois fichiers touchés :

- `deploy/ops/anarbib-bg2.sh` — les trois `--prune` deviennent `--no-prune`,
  une fonction `prune_repos()` est ajoutée, et la commande `prune` entre au
  `case` principal. Usage : `anarbib-bg2.sh {check | backup … | prune | restore-test}`.
- `deploy/ops/systemd/anarbib-backup-prune.service` — `TimeoutStartSec=5400`.
- `deploy/ops/systemd/anarbib-backup-prune.timer` — `OnCalendar=*-*-01 22:30:00 Europe/Paris`.

Installés sur le poste par lien symbolique depuis `~/.config/systemd/user/`,
même convention que les sept unités existantes : une seule copie, celle du
dépôt, aucune divergence possible.

**`forget` reste dans chaque flux.** Il ne touche que des métadonnées, il est
quasi instantané, et la politique de rétention 7/4/6 continue donc de
s'appliquer à chaque tir. Seule la **récupération d'espace** est différée.

**Le prune n'écrit aucun témoin de vie.** Ce n'est pas une sauvegarde. L'alarme
de silence ne doit pas le compter comme telle, sous peine de tenir un flux pour
vivant alors que seul son ménage a tourné.

---

## 2 · La mesure qui l'a motivé

Durées relevées dans le journal systemd du flux `storage`, sur quatorze jours :

| Date | Durée | Prune ? | Résultat |
|---|---|---|---|
| 09/08 | **11 min 18 s** | non | `Finished` |
| 16/08 | 21 s | — | ⚠️ `Failed with result 'signal'` |
| 20/08 | **22 min 56 s** | **oui** | `Finished` |

La borne `TimeoutStartSec` du flux `storage` est à **30 minutes**. Le tir du
20/08 en a consommé 23, et **pas un document numérisé n'est encore versé**.

La décomposition dit où passe le temps : sauvegarde de 23:37 à 23:54 (~17 min),
puis `forget` + `prune` de 23:54:57 à 00:00:07 (~6 min). Le prune ne se
déclenche que lorsque la rétention retire un instantané — d'où une durée
**bimodale**, ~17 min d'ordinaire, ~23 quand le prune tombe. Face à une borne
fixe, c'est le pire cas qui compte, et il ne se produit qu'une fois de temps en
temps : le genre de défaut qui attend d'être en production pour se manifester.

Second enseignement, moins attendu : entre le 09 et le 20/08, le volume a
augmenté de **2,6 %** (448,9 → 460,3 Mio) pour **+55 %** de durée de sauvegarde.
Le coût n'est donc pas dans le volume local mais dans la **synchronisation des
16 seaux** depuis Supabase. C'est utile à savoir pour la numérisation : le temps
ne suivra pas proportionnellement les octets.

### Ce que la correction ne touche pas, et pourquoi

Ni `TimeoutStartSec`, ni le seuil d'alarme d'une heure. Ces deux nombres sont
**couplés** : le seuil vaut le double du timeout, si bien qu'un tir légitime ne
peut jamais l'atteindre — systemd le tue avant — et c'est précisément ce qui
rend le faux positif impossible. Les relever aurait exigé de les relever
**ensemble**, sous peine de casser l'alarme en silence. Sortir le prune évite
ce nœud entièrement.

C'est aussi pourquoi l'unité de prune peut se permettre un `TimeoutStartSec` de
90 minutes : le temps long a désormais un endroit où vivre, et cet endroit n'est
adossé à aucun seuil d'alarme.

---

## 3 · Ce que le report coûte

Jusqu'à **un mois de données non réclamées** dans les trois dépôts. La
déduplication restic rend le surcoût modeste, mais il n'est pas nul, et il
grandira avec la numérisation. À surveiller au même titre que le reste : si
l'espace chez Herbes Folles devient contraint, la fréquence du prune est le
premier levier — passer au bimensuel coûte deux tirs au lieu d'un.

---

## 4 · Comment vérifier

```bash
# le minuteur est armé et daté
systemctl --user list-timers --all | grep prune

# un prune manuel, hors calendrier
~/anarbib-ops/anarbib-bg2.sh prune

# le journal du dernier tir mensuel
journalctl --user -u anarbib-backup-prune.service --since "2 months ago"
```

Contrôle qui compte le mois prochain : après le tir du 1er, vérifier que les
trois dépôts ont bien été traités — la sortie porte une ligne `Prune de …` par
dépôt, puis `=== Prune des trois dépôts terminé. ===`. Un prune qui échoue sur
un dépôt tue le script (`die`), donc l'absence de la ligne finale est le signal.

### Premier tir manuel — 21/08/2026

Lancé à la main juste après la livraison, pour éprouver le chemin neuf avant que
le calendrier ne s'en charge. Les trois dépôts traités, sortie 0, ligne finale
présente.

| Dépôt | Restant après prune | Récupéré | Parcours des paquets |
|---|---|---|---|
| `anarbib-long` | 94 blobs / 19,0 Mio | 0 | non relevé (voir ci-dessous) |
| `anarbib-court` | 42 blobs / 309 Kio | 0 | 3 min 57 (6 paquets) |
| `anarbib-storage` | 3 787 blobs / 404 Mio | 0 | 4 min 01 (28 paquets) |

La durée du premier dépôt manque parce que la commande avait été tuyautée dans
`tail -40` : le début de la sortie a été coupé. Défaut d'observation, pas du
dispositif — mais il vaut d'être noté, parce qu'il aurait aussi bien pu masquer
une erreur au lieu d'un chiffre. **Ne pas tronquer la sortie d'un tir qu'on
lance pour l'éprouver.**

Rien à récupérer, et c'est normal : le tir du 20/08 avait déjà pruné `storage`,
les deux autres étaient propres. Ce tir valide donc le **chemin**, pas le gain.

**Mais les durées disent autre chose, et c'est la vraie trouvaille.**
`anarbib-court` pèse 309 Kio et son prune a pris 3 min 57 ; `anarbib-storage`
pèse 404 Mio — mille trois cents fois plus — et a pris 4 min 01. Six paquets et
vingt-huit paquets coûtent le même temps. **Le prune n'est pas borné par le
volume, il est borné par les allers-retours réseau vers Herbes Folles.**

Deux conséquences pratiques. D'abord, les ~6 minutes que le prune ajoutait au
tir de sauvegarde étaient essentiellement de la latence, pas du calcul : les
sortir était le bon geste, et le gain restera stable quelle que soit la taille
des dépôts. Ensuite, le tir complet a duré **une douzaine de minutes** — mesuré,
fin à 09:46:23 pour un lancement vers 09:34 — soit trois dépôts à ~4 minutes
chacun, **sans rien avoir à récupérer**. C'est donc un plancher, pas un pic : la
fenêtre de 90 minutes est largement dimensionnée et le restera longtemps, y
compris après la numérisation.

Corollaire pour plus tard : si l'espace devient contraint et qu'on veut pruner
plus souvent, le coût marginal d'un tir supplémentaire est connu et modeste.
C'est la fréquence qui se règle, pas la durée.

---

## 5 · Quatre constats du même jour

### 5.1 La pile `deploy/` est tombée avec la VM WSL

La VM WSL a redémarré à **11:57:39 UTC**. Les conteneurs ont été marqués morts
à **11:59:35 UTC**, tous à la même seconde, en **code 127**. Leurs journaux sont
normaux jusqu'à la dernière ligne : Postgres faisait ses checkpoints, Caddy
servait des requêtes, `functions` avait monté ses 46 fonctions.

Le code 127 évoque le piège CRLF documenté au runbook — c'est une fausse piste.
Les trois points d'entrée sont des binaires (`postgres`, `caddy`,
`edge-runtime`), pas des scripts shell. Trois conteneurs qui meurent ensemble
sans rien dire, c'est le sol qui se dérobe, pas un défaut d'image.

**Ce qui mérite d'être retenu**, parce que ça se reproduira : tous portent
`restart=unless-stopped`, mais seuls `auth` et `storage` ont retenté — **66 et
33 fois** — tournant en boucle à chercher un `db` qui n'était jamais revenu.
`db`, `functions` et `caddy` ne se sont pas relevés du tout. Une pile à moitié
debout est plus trompeuse qu'une pile éteinte : `docker ps` montre des
conteneurs « Up », et rien ne fonctionne. Le volume `anarbib_db-data` était
intact ; `docker compose up -d` a tout remis d'aplomb.

### 5.2 RAM au repos : 442 Mio, et aucun plafond configuré

Relevé après redémarrage, les six conteneurs : `storage` 246 Mio, `db` 104,
`rest` 46, `functions` 22, `caddy` 14, `auth` 9 — **442 Mio au total**, contre
les **360 Mio** mesurés le 20/08. Le repos lui-même n'est donc pas un chiffre
stable.

Plus important pour le dimensionnement : `deploy/compose.yml` ne contient
**aucun `mem_limit`** et **aucun réglage Postgres** — ni `shared_buffers`, ni
`work_mem`, ni `max_connections`. Rien ne borne la consommation.

Ça déplace la question posée à Herbes Folles. « Combien la pile consomme-t-elle
sous charge ? » n'a pas de réponse stable tant que rien ne la borne. La réponse
sur laquelle on peut s'engager est un **plafond configuré** : poser `mem_limit`
et les réglages Postgres, annoncer ce chiffre-là, et se servir de la mesure pour
vérifier qu'on tient dessous — pas pour le découvrir.

À noter aussi : le harnais `scripts/loadtest/anarbib-loadtest.mjs` vise la
**production** en dur (`BASE`, ligne 8), sans variable d'environnement. Il ne
peut pas servir tel quel à charger la pile locale.

### 5.3 Témoins de sauvegarde : `storage` a parlé, `long` attend le 23/08

État de `backup_heartbeats` au 21/08 :

- `court` — réel, `ACCATTONE`, dernier `ok` le 20/08 à 20:46 UTC, snapshot `b4d37058`.
- `storage` — **réel désormais**, `ACCATTONE`, `ok` le 21/08 à 03:00 UTC,
  snapshot `88f1699f`. La ligne d'amorçage subsiste mais ne commande plus rien.
- `long` — **toujours `amorcage-migration`**, 19/08 14:53.

`long` n'est pas en panne : il tourne correctement (6 min 14 s le 16/08). Il
n'a simplement pas retiré depuis que le témoin existe, son dernier passage
précédant BG2-16. Le tir du **dimanche 23/08 à 15:00** devrait clore l'item sans
rien à corriger. L'échéance de silence du ~28/08 tient donc, et c'est ce tir-là
qui la lèvera.

### 5.4 Les captures de numérisation ne tiendront pas sur le VPS

Élément pour le point ouvert « trancher le sort des captures » du profil de
numérisation. Ordre de grandeur, à confirmer sur les dix ouvrages d'essai :

Une page A5 en gris à 300 ppp fait ~4,4 Mpx, soit ~0,5 Mo en JPEG de qualité
correcte. Un ouvrage de 300 pages : **150 à 600 Mo de captures**, quand le PDF
bitonal dérivé tient dans ~15 Mo. Les captures pèsent **10 à 40 fois** le
livrable.

Sur les 900 à 2 250 ouvrages en domaine public de l'estimation retenue, cela
donne **300 à 700 Go de captures** — face aux 20 Go demandés à Herbes Folles et
aux 50 Go à trois-cinq ans.

**Conséquence** : la question n'est pas « archiver ou effacer » mais « sur quel
support hors ligne, ou effacer ». Les captures ne peuvent vivre sur le VPS dans
aucun scénario. Ce qui valide au passage la demande faite à Herbes Folles :
elle est dimensionnée sur les seuls PDF dérivés, et elle est juste.

L'arbitrage qui reste est irréductible : **une capture effacée ne se refait
qu'en reprenant le livre en main.** Si le profil de dérivation évolue, ou si un
bitonal s'avère illisible sur des gravures, sans capture il faut rescanner.
Trois options se tiennent — effacement après validation, archivage hors ligne
systématique (~700 Go à terme, sur disques externes), ou archivage sélectif des
seuls ouvrages à gravures, affiches et couvertures, qui divise le volume par
cinq à dix.

---

## 6 · Une correction au plan de marche

Le §11 du plan de marche donne « durée d'un tir `storage` : **21 s à 11 min
18 s** ». Les 21 secondes ne sont pas un tir rapide : c'est le tir du 16/08
**tué en cours** (`Failed with result 'signal'`), celui-là même que le journal
attribue par ailleurs à une session démontée. La borne basse du tableau est donc
un échec pris pour une performance.

La fourchette réelle est **11 à 23 minutes**, et elle est bimodale selon que le
prune tombe ou non — jusqu'à aujourd'hui.

C'est la même famille d'erreur que celles du §14 : non pas une source non lue,
mais une valeur extraite d'un journal sans regarder la ligne d'à côté qui disait
comment le tir s'était terminé. **Une durée n'a de sens qu'accompagnée de son
issue.**
