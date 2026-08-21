# Fiche d'appel — Herbes Folles

> À avoir sous les yeux pendant l'appel. Une page, rien à lire pendant que
> quelqu'un parle. Préparée le 20/08/2026.
>
> **Date : inconnue.** Ils ont écrit « nous nous consultons entre nous et te
> disons lorsqu'il est possible de se capter par tel. » L'appel peut tomber avec
> un jour de préavis — d'où cette fiche, prête d'avance.

## La phrase à avoir en tête en décrochant

**Ce n'est pas une première rencontre, c'est une extension.** Herbes Folles
héberge déjà les sauvegardes d'AnarBib depuis le 01/07 (`bricolage.herbesfolles.org`),
et la chaîne tourne. On ne demande pas à entrer : on demande à aller plus loin
avec des gens qui nous connaissent déjà.

---

## Les quatre choses à rapporter

L'appel est réussi même s'il ne donne rien d'autre.

1. **La taille réelle de la VM** qu'ils peuvent proposer — RAM, disque, et si
   Docker + Compose avec un shell est possible chez eux.
2. **Le délai réaliste quand ça casse chez eux.** Pas leur engagement affiché :
   ce qui se passe vraiment un dimanche soir.
3. **Comment leur verser de l'argent.** Moyen concret, coordonnées, périodicité.
4. **Leur tolérance à la croissance du disque — et surtout, ce qui se passe
   après cinq ans.** La question n'est plus « 50 Go, ça passe ? » : c'est
   « est-ce qu'on peut continuer à demander ? ». Depuis le rechiffrage du 20/08,
   la croissance n'a plus de palier connu dans l'horizon considéré (voir plus
   bas). Ce qu'on cherche à savoir : y a-t-il un mur, de principe ou de capacité,
   et où ?

> **Attention sur le point 3.** Sans structure qui reçoive et qui verse, leur
> réponse ne sert à rien. La délibération CCLA n'a pas eu lieu ; les coordonnées
> PIX / Liberapay / Wise au nom du CCLA n'existent pas encore. Si la question
> vient, **dire où on en est** plutôt que promettre un virement le mois prochain.

---

## Les chiffres corrigés, à dire soi-même

Le mail parti annonce des estimations de juillet. **Corriger d'emblée, sans
attendre qu'ils chiffrent dessus.**

| Ils ont lu | Dire |
|---|---|
| ≈ 10 conteneurs | **6** |
| base ~100 Mo, ~530 Mo au total | **20 Mo** de base, ~430 Mo de fichiers |
| RAM 4 Go min., 8 Go confortable | **Une VM de 4 Go suffit.** Pile bornée à **3,4 Go** de plafonds configurés, **0,36 Go** constaté au repos |
| ~20 Go dédiés | **20 Go au départ, ~50 Go à 3–5 ans**, pente ~3 Go/an et par personne qui numérise — **une trajectoire, pas un palier** |

Corriger à la baisse sur trois lignes et à la hausse sur la quatrième, dans la
même phrase : ça ne se lit pas comme un rétropédalage, ça se lit comme quelqu'un
qui mesure.

### Sur la RAM — dire exactement ceci, et pas plus (mesuré le 21/08)

Les six conteneurs portent depuis le 21/08 des **plafonds mémoire explicites** :
`db` 1536 Mo, `storage` 768, `functions` 512, `rest` 384, `auth` 192, `caddy`
128 — **3,4 Go au total**. Postgres est réglé pour cette cible (`shared_buffers`
512 Mo, `effective_cache_size` 1536 Mo). Au repos, l'ensemble consomme **358 Mo**.

**Ce qui n'est pas mesuré : la consommation sous charge réelle.** Si la question
vient, ne pas l'inventer. La bonne réponse est celle-ci : *« on ne l'a pas
laissée libre de grossir — elle est bornée à 3,4 Go, et on a vérifié qu'elle
démarre et tourne dans ces bornes. »* Un plafond choisi vaut mieux qu'une mesure
d'un jour : la même pile mesurée au repos donnait 360 Mo le 20/08 et 442 Mo le
21/08, sans que rien ait changé d'autre qu'un redémarrage.

C'est le chiffre qui décide de la moitié de la liste d'hébergeurs : à 4 Go,
Koumbit à ~80 €/mois plus 100 $ d'entrée sort du champ, et les offres à 8–15 €
reviennent.

### Sur le disque — le chiffre tient, le mot « plafond » ne tient plus

Ne rien retirer de ce qui a été annoncé : **20 Go au départ, ~50 Go à trois-cinq
ans reste juste.** C'est une trajectoire bornée par la vitesse de numérisation
humaine — une personne assidue traite ~250 ouvrages par an, soit 2 à 4 Go ; trois
bibliothèques équipées, une dizaine de Go par an.

Ce qui a changé le 20/08, c'est qu'il n'y a **plus de palier**. La mesure du
catalogue donne 2 674 ouvrages, **tous détenus par une bibliothèque, zéro
orphelin** : « sous droits, non détenu » est une catégorie vide, donc tout le
fonds devient éligible à la numérisation intégrale, et le plafond passe de ~30 Go
à **75–135 Go**. Avant, la croissance s'arrêtait d'elle-même une fois le domaine
public épuisé. Plus maintenant.

**Ne pas annoncer 135 Go.** Ce n'est pas un chiffre à donner, c'est un critère de
choix : l'hébergement doit pouvoir *continuer à croître après cinq ans*, au lieu
d'atteindre un maximum connu. C'est ce qui transforme le point 4 ci-dessus.

**Autres faits utiles s'ils demandent** : 2 674 ouvrages catalogués, tous détenus
· 15 comptes · 4 bibliothèques · reconstruction complète de la pile en 25 minutes,
restauration d'une sauvegarde en 17 secondes · PostgreSQL 17.6 · aucun relais SMTP
(GoTrue tourne en *noop mail client*, vérifié dans les journaux) · le catalogue
n'est rempli qu'au tiers (~9000 ouvrages estimés), donc **c'est la saisie qui
borne la numérisation avant le disque**.

---

## Les cinq choses à ne pas faire

1. **Redemander la co-exploitation.** Ils ont répondu.
2. **S'excuser de la taille du projet.** 20 Mo, six conteneurs, 2677 notices —
   ce n'est pas lourd, et se justifier laisse croire le contraire.
3. **Promettre une date de bascule.** Elle dépend d'eux, pas de nous.
4. **Donner un chiffre unique de disque.** Un taux et une pente, jamais un
   nombre seul — c'est l'erreur du mail de juillet, ne pas la refaire à l'oral.
5. **Rouvrir le débat sur l'IA.** Traité par écrit le 17/08. Y revenir de
   vive voix rouvre une discussion close, sans rien gagner.

---

## Après l'appel

Noter les quatre réponses **avant de faire autre chose**, tant qu'elles sont
fraîches. Elles verrouillent la suite : les phases 0 à 4 du runbook de migration
se figent une fois l'hôte connu, et la moitié de la liste d'hébergeurs se
tranche sur la seule taille de VM qu'ils annoncent.
