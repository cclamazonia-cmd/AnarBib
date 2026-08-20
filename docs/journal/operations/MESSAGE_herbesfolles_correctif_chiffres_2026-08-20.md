# Message à Herbes Folles — correctif de chiffres

> **PRÊT À ENVOYER** (20/08, 19 h 20). La RAM est mesurée : **360 Mo au repos**
> pour les six conteneurs (`storage` 196, `db` 70, `rest` 53, `functions` 22,
> `caddy` 11, `auth` 8). La consigne de relecture est levée — 360 Mo est très
> loin des 4 Go au-delà desquels il ne fallait pas envoyer.
>
> ⚠️ **Le chiffre de disque a été RETIRÉ du message, délibérément.** Le brouillon
> annonçait « 20 Go pour démarrer, jusqu'à 50 sur trois à cinq ans ». Or la
> décision « troisième voie » du 20/08 — numérisation intégrale des ouvrages sous
> droits *détenus*, lisible par les seuls membres de la bibliothèque détentrice —
> périme ce chiffrage, et le dit elle-même : *« Cette voie change le
> dimensionnement du §8 […] plusieurs dizaines de Go, non deux. À rechiffrer
> avant l'appel Herbes Folles. »* Envoyer 20/50 Go aurait été refaire exactement
> l'erreur qu'on corrige : donner un chiffre qu'on sait déjà faux. Le message dit
> donc que le volume est en cours de rechiffrage, et promet un taux et une pente
> pour l'appel — ce que le §5.3 demande de toute façon.
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
| « ~20 Go dédiés » | **en cours de rechiffrage** — voir ci-dessous | trop léger, ampleur inconnue |

**Sur la RAM.** 360 Mo est une mesure **au repos** : aucun trafic, Postgres n'a
pas gonflé ses caches. C'est un plancher, pas une taille de VM — et le message le
dit, plutôt que de laisser croire à une mesure qu'on n'a pas faite. Ce qu'il
affirme est exactement ce qu'on sait : l'ordre de grandeur n'est pas celui
annoncé, et une machine à 8 Go est inutile.

**Sur le disque, on ne donne plus de chiffre.** Le brouillon annonçait 20 Go puis
50 sur trois à cinq ans. La décision « troisième voie » du 20/08 périme ce
chiffrage — les ouvrages sous droits *détenus* deviennent numérisables en
intégral, là où le calcul ne leur accordait qu'une couverture — et la décision le
signale elle-même comme **à rechiffrer avant l'appel**. Donner 20/50 Go
aujourd'hui reviendrait à répéter l'erreur qu'on corrige. Le message annonce donc
le sens (ça grandira, lentement, borné par la vitesse humaine) et promet un taux
et une pente pour l'appel — ce que le §5.3 réclame de toute façon, et qui vaut
mieux qu'un nombre unique déjà vieilli.

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
> Sur le disque, je préfère ne pas vous donner de chiffre aujourd'hui plutôt que
> de vous en donner un faux. Nous venons d'arrêter une règle de numérisation, et
> elle élargit le volume par rapport à ce que le premier mail annonçait : nous
> sommes en train de le rechiffrer. Ce que je peux dire dès maintenant, c'est que
> **ça grandira** — lentement, borné par la vitesse à laquelle des humains
> numérisent, pas par la taille des fonds. Je vous apporterai un taux et une
> pente à l'appel, pas un nombre unique qui aurait vieilli entre-temps.
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
