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
4. **Leur tolérance à la croissance du disque** — 20 Go qui deviennent 50 sur
   trois à cinq ans, est-ce que ça leur pose un problème de principe ou de
   capacité ?

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
| RAM 4 Go min., 8 Go confortable | **⟨RAM mesurée⟩** — le chiffre qui décide |
| ~20 Go dédiés | **20 Go au départ, ~50 Go à 3–5 ans**, pente ~3 Go/an et par personne qui numérise |

Corriger à la baisse sur trois lignes et à la hausse sur la quatrième, dans la
même phrase : ça ne se lit pas comme un rétropédalage, ça se lit comme quelqu'un
qui mesure.

**Autres faits utiles s'ils demandent** : 2677 notices · 15 comptes · 4
bibliothèques · reconstruction complète de la pile en 25 minutes, restauration
d'une sauvegarde en 17 secondes · PostgreSQL 17.6 · aucun relais SMTP (GoTrue
tourne en *noop mail client*, vérifié dans les journaux).

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
