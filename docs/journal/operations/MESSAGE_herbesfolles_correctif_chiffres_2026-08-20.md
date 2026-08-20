# Message à Herbes Folles — correctif de chiffres

> **Brouillon. NE PAS ENVOYER tant que la RAM n'est pas mesurée** (§5.2 du plan
> de marche : `docker stats --no-stream` sur les six conteneurs, pendant une
> répétition). Le message n'a d'intérêt que s'il apporte le chiffre manquant.
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
| « RAM ~4 Go minimum, 8 Go confortable » | **⟨à mesurer⟩** | probablement trop lourd |
| « ~20 Go dédiés » | 20 Go au départ, **~50 Go à 3–5 ans** | **trop léger** |

La dernière ligne est la seule qui aille vers le haut, et c'est elle qui doit
être dite le plus clairement : la numérisation est la cause, elle est décidée et
chiffrée (profil de numérisation du 20/08, pente ~3 Go/an par personne qui
scanne). Annoncer un chiffre unique sans pente est précisément ce que le plan de
marche range dans les choses à ne pas faire.

---

## Le message

> Salut,
>
> Merci pour votre réponse — et pas de précipitation, prenez le temps qu'il vous
> faut.
>
> Une précision avant que vous vous décidiez : depuis le mail que je vous ai
> envoyé, j'ai mesuré au lieu d'estimer, et **c'est plus léger que ce que je vous
> ai annoncé**. Pas dix conteneurs mais **six**, et une base de **20 Mo** et non
> 100. Côté mémoire, la pile tourne avec **⟨RAM_MESURÉE⟩ Go** — là où je vous
> demandais 4 Go minimum et 8 Go confortables. Si ça change quelque chose à ce
> que vous pouvez proposer, ou à ce que ça coûte, autant que vous le sachiez
> maintenant.
>
> En revanche, une correction dans l'autre sens, et je préfère vous la dire tout
> de suite plutôt que de revenir vous voir dans deux ans : **le disque va
> grandir**. On a arrêté un profil de numérisation, et les bibliothèques du
> réseau vont numériser leur domaine public. Ça donne **20 Go pour démarrer et
> jusqu'à ~50 Go sur trois à cinq ans**, à raison d'environ 3 Go par an et par
> personne qui numérise. Ce n'est pas un pic, c'est une pente lente et bornée par
> la vitesse humaine — mais elle existe, et je ne veux pas vous vendre 20 Go pour
> en redemander plus tard.
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
