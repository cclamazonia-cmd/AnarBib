# Message à Herbes Folles — correctif de chiffres

> **PRÊT À ENVOYER** (20/08, 19 h 20). La RAM est mesurée : **360 Mo au repos**
> pour les six conteneurs (`storage` 196, `db` 70, `rest` 53, `functions` 22,
> `caddy` 11, `auth` 8). La consigne de relecture est levée — 360 Mo est très
> loin des 4 Go au-delà desquels il ne fallait pas envoyer.
>
> **Le chiffre de disque est CONSERVÉ** — après un aller-retour qu'il vaut mieux
> raconter. Je l'avais d'abord retiré, croyant le brouillon périmé par la
> décision « troisième voie » du 20/08, dont le §1 réclamait un rechiffrage
> « avant l'appel Herbes Folles ». **Le rechiffrage avait déjà eu lieu**, au §8
> du même document, et sa conclusion est l'inverse : *« Ce chiffre reste juste
> […] il ne faut donc rien retirer de ce qui a été dit ; il faut seulement ne
> plus le présenter comme un plafond. »* J'avais lu l'avertissement sans vérifier
> s'il avait été levé — le §1 le réclamait encore alors que le §8 l'avait fait.
>
> Ce que le rechiffrage établit : le fonds éligible passe à **72–135 Go** (2 674
> ouvrages catalogués, **tous détenus**, zéro orphelin — « sous droits non
> détenu » est une catégorie vide en pratique), mais **la pente est inchangée**,
> bornée par la main-d'œuvre et non par l'éligibilité. Les 20 Go / 50 Go tiennent
> donc comme *trajectoire* ; ce qui disparaît, c'est le palier.
>
> **Pourquoi ce message existe.** Le mail de dimensionnement
> ([`MESSAGE_herbesfolles_dimensionnement_vps_2026-07-03`](MESSAGE_herbesfolles_dimensionnement_vps_2026-07-03.md))
> est parti mi-août **tel qu'il avait été rédigé le 03/07**, avec les chiffres
> d'alors. Herbes Folles a accusé réception et **se consulte en interne** — donc
> délibère en ce moment sur ces chiffres-là.
>
> Or ils sont faux **dans les deux sens** : trop lourds sur la RAM et les
> conteneurs, trop légers sur la croissance du disque. Le risque n'est pas
> l'imprécision, c'est qu'ils concluent « trop lourd pour nous » ou chiffrent une
> VM à 8 Go sur une estimation de juillet.
>
> **Fenêtre :** avant que leur consultation aboutisse. Ils ont écrit « nous nous
> consultons entre nous et te disons lorsqu'il est possible de se capter » — la
> date de l'appel n'est plus la nôtre.

---

## Ce qui est à corriger

| Ce qu'ils ont lu (mail du 03/07) | Ce qui est mesuré | Sens de l'erreur |
|---|---|---|
| « ≈ 10 conteneurs » | **6** | trop lourd |
| « base ~100 Mo », « ~530 Mo au total » | **20 Mo** de base, ~430 Mo de fichiers | trop lourd |
| « RAM ~4 Go minimum, 8 Go confortable » | **360 Mo au repos** pour les six | trop lourd d'un facteur ~11 |
| « ~20 Go dédiés » | **juste** — 20 Go au départ, ~50 à 3–5 ans (rechiffré §8) | exact, mais ce n'est plus un plafond |

**Sur la RAM.** 360 Mo est une mesure **au repos** : aucun trafic, Postgres n'a
pas gonflé ses caches. C'est un plancher, pas une taille de VM — et le message le
dit, plutôt que de laisser croire à une mesure qu'on n'a pas faite. Ce qu'il
affirme est exactement ce qu'on sait : l'ordre de grandeur n'est pas celui
annoncé, et une machine à 8 Go est inutile.

**Sur le disque, le chiffre tient — et le message le confirme au lieu de le
retirer.** Le rechiffrage du §8 est fait : le fonds éligible explose (72–135 Go,
tous les ouvrages étant détenus), mais la pente ne bouge pas, parce qu'elle est
bornée par le nombre de personnes qui numérisent, pas par le nombre de livres
numérisables. Une personne assidue produit 2 à 4 Go/an ; trois bibliothèques
équipées, une dizaine. Et **aucun scanner n'est encore en service** : la pente
n'a pas commencé.

Ce que le message ajoute, et qui les concerne : les 50 Go ne sont plus un point
d'arrivée. Avant, la croissance s'arrêtait le domaine public épuisé. Désormais
elle continue. Ce n'est pas un volume à annoncer, c'est un **critère de choix**
— mieux vaut un hébergement qui puisse croître doucement après cinq ans qu'un
hébergement calibré sur un maximum.

Le §5.3 demande « un taux et une pente plutôt qu'un chiffre unique » : c'est
exactement ce que le message donne maintenant, et le chiffre unique y reste
comme repère, pas comme promesse.

---

## Le message

> Salut,
>
> Merci pour votre réponse — et pas de précipitation, prenez le temps qu'il vous
> faut.
>
> Une précision avant que vous vous décidiez : depuis le mail que je vous ai
> envoyé, j'ai mesuré au lieu d'estimer, et **la machine demandée est plus petite
> que ce que je vous ai annoncé**. Pas dix conteneurs mais **six**, et une base
> de **20 Mo** et non 100.
>
> Côté mémoire, les six conteneurs tiennent dans **360 Mo au repos** — là où je
> vous demandais 4 Go minimum et 8 Go confortables. Je précise **au repos** :
> personne ne consultait le catalogue pendant la mesure, et je n'ai pas encore
> mesuré sous charge. Ce n'est donc pas un chiffre sur lequel dimensionner, c'est
> un plancher. Mais l'ordre de grandeur est clair, et il n'est pas celui que je
> vous ai donné : si vous aviez commencé à chercher une machine à 8 Go, ce n'est
> pas la peine.
>
> Sur le disque en revanche, **le chiffre que je vous ai donné tient** : 20 Go
> pour démarrer, une cinquantaine à trois-cinq ans. Je le confirme après l'avoir
> refait, parce qu'une décision prise cette semaine a élargi ce que nous nous
> autorisons à numériser — et je voulais m'assurer que ça ne vous engageait pas
> au-delà de ce qui vous avait été dit. Ça ne change pas la trajectoire : ce qui
> borne le remplissage, ce n'est pas le nombre de livres, c'est le nombre de
> personnes qui scannent. Une personne assidue produit **2 à 4 Go par an** ;
> trois bibliothèques équipées, une dizaine de Go par an. C'est une pente lente,
> et à ce jour **aucun scanner n'est encore en service** : elle n'a pas commencé.
>
> Une seule nuance, et elle vous concerne plus que nous : ces 50 Go ne sont plus
> un point d'arrivée. Avant, la croissance s'arrêtait d'elle-même une fois le
> domaine public épuisé. Maintenant elle continue tant que quelqu'un numérise.
> Rien à absorber dans l'immédiat, donc — mais si vous nous hébergez, autant
> choisir quelque chose qui puisse **continuer à grandir doucement** après cinq
> ans, plutôt que quelque chose de calibré sur un maximum.
>
> À bientôt,

---

## Notes de relecture

- **Ne pas rouvrir** la co-exploitation (ils ont répondu), ni le débat sur l'IA
  (traité par écrit le 17/08). Ce message ne fait qu'une chose : corriger des
  chiffres.
- **Ne pas s'excuser** de la taille du projet. Six conteneurs et 20 Mo, ce n'est
  pas lourd — le dire platement suffit.
- **Ne pas proposer de date d'appel.** Ils ont dit qu'ils reviendraient vers
  nous ; leur forcer un créneau contredit leur message.
- Si la RAM mesurée s'avère **supérieure** à 4 Go, ne pas envoyer ce message :
  il n'y aurait plus de correction à la baisse, et il ne resterait qu'une
  mauvaise nouvelle sur le disque. Dans ce cas, garder les deux corrections pour
  l'appel, de vive voix.
