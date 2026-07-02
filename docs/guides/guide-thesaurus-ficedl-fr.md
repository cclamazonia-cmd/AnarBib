# Le thésaurus FICEDL dans AnarBib — consulter un vocabulaire commun

> **Pour qui ?** Pour tout·e camarade qui catalogue et veut relier ses livres au
> **vocabulaire matière partagé** du mouvement — celui que maintient la FICEDL. Ce
> guide explique ce qu'est ce thésaurus, à quelles conditions AnarBib s'y branche,
> à quoi il sert, et comment s'en servir au quotidien.
>
> **Esprit.** AnarBib **consulte** le thésaurus ; il ne se l'approprie pas. Le
> vocabulaire reste celui de la FICEDL, qui en est la source **qui fait foi**. Rien
> ici ne crée une version concurrente : notre copie n'est qu'un *reflet* fidèle.

---

## Qu'est-ce que le thésaurus FICEDL ?

La **FICEDL** — Fédération internationale des centres d'études et de documentation
libertaires — fédère depuis 1979 des CIRA, athénées, CCL et bibliothèques
anarchistes du monde entier. Elle maintient un **thésaurus** : un *vocabulaire
contrôlé* de la documentation libertaire — une liste raisonnée de **termes-matière**
(les sujets), organisés et traduits, pour décrire ce dont *parlent* les documents. Il
couvre les mêmes **dix langues** qu'AnarBib (exactement celles que propose le CIRA de
Lausanne) et rassemble plusieurs centaines de termes (de l'ordre de six cents). Il est
consultable publiquement sur `thesaurus.ficedl.info`.

Un thésaurus n'est pas un simple dictionnaire : c'est un **graphe de concepts**. Les
termes s'y relient (plus large · plus étroit · associé) et portent des **notes
d'application** qui disent comment les employer. AnarBib s'appuie sur **SKOS**, le
standard libre du web sémantique pour ce type de vocabulaire.

## À quelles conditions il est entré dans AnarBib

Adopter un vocabulaire commun est d'abord une **décision politique** — celle de
collectifs qui choisissent de parler la même langue documentaire — et la technique s'y
conforme. Concrètement, AnarBib a repris le thésaurus **depuis le site de la FICEDL**
(`thesaurus.ficedl.info`) **autour du 24 juin 2026**, en important ses **termes** et
ses **lieux** (les entrées géographiques) — en laissant de côté les **dates** (les
entrées chronologiques). Ce branchement suit quelques **principes clairs**, qui sont
les *bases de l'accord* :

1. **Source canonique unique.** Le thésaurus qui *fait foi* est celui de la FICEDL.
   AnarBib ne détient pas *le* thésaurus : il en tient une copie de travail.
2. **Pas de fork.** Notre copie est un **reflet** de la version FICEDL, jamais une
   version rivale. L'interopérabilité que la FICEDL appelle de ses vœux est ainsi
   garantie *par construction*.
3. **Consulter, pas modifier.** AnarBib **ne touche pas** aux mots choisis par la
   FICEDL. Une seule liberté, et de notre seul côté : **remettre à sa place une
   étiquette de langue mal rangée** (une traduction classée sous un mauvais code de
   langue), uniquement pour ne pas *perdre* une traduction qui existe déjà — sans
   jamais changer le terme lui-même.
4. **Signaler, pas corriger.** Toute autre anomalie — une langue manquante, une
   coquille dans un terme — n'est **pas** rectifiée chez nous : elle est **signalée**
   à la FICEDL, qui corrige *sa* version de référence.
5. **Re-synchronisation.** Après les corrections de la FICEDL, AnarBib
   **re-synchronise** sa copie. Le reflet se met à jour ; il ne diverge jamais.
6. **Vocabulaire libre et partagé.** Le thésaurus est **librement partageable** (aucun
   droit propriétaire ne le verrouille). Son évolution se fait **collectivement**,
   précisément pour *limiter les forks* et préserver l'interopérabilité entre
   bibliothèques.
7. **Évolution portée par le collectif.** Certaines zones du vocabulaire demandent à
   être actualisées (par exemple les catégories liées aux thématiques LGBTQI+). Ces
   évolutions ne se décrètent pas d'en haut : elles se discutent **au sein de la
   fédération**.

En somme : le thésaurus reste **à 100 % celui de la FICEDL** ; AnarBib en est un
miroir loyal, et un **relais** qui remonte ce qu'il repère.

## À quoi il sert

- **Décrire par le sujet.** Au catalogage, le champ **« Sujets » (autorité matière)**
  relie un document à un ou plusieurs termes du thésaurus. C'est ce qui permet de
  retrouver un livre par **ce dont il parle**, pas seulement par son titre ou son
  autrice.
- **Naviguer par thème.** Ces termes alimentent les **facettes** et la navigation
  thématique du catalogue public.
- **Parler dix langues d'un coup.** Un même concept porte son étiquette dans chacune
  des dix langues : une lectrice hispanophone et un lecteur grécophone tombent sur *le
  même sujet*, chacun·e dans sa langue.
- **Relier les bibliothèques.** Parce que tout le monde s'appuie sur le **même**
  vocabulaire, les catalogues deviennent comparables et échangeables — c'est le socle
  de la mutualisation (doublets, prêts inter-bibliothèques, méta-catalogue).

## Comment l'utiliser concrètement

1. **Cherche un terme dans « Sujets ».** Au catalogage, commence à taper dans le champ
   **Sujets** : AnarBib propose les termes du thésaurus, avec leur hiérarchie.
   Réutilise l'existant plutôt que d'inventer.
2. **Choisis la bonne granularité.** Ni trop large, ni trop étroit : le terme que
   *quelqu'un utiliserait pour chercher* ce livre. Deux à quatre sujets suffisent en
   général.
3. **Lis la note d'application** si le terme en a une : elle dit comment l'employer.
4. **Étiquette manquante dans ta langue (⚐).** Si un sujet n'a pas encore de libellé
   **dans ta langue**, il s'affiche par **repli** (souvent dans une autre langue) avec
   un ⚐. Ce n'est pas un bug : c'est une **lacune de la version de référence**. On ne
   la bricole pas chez nous — voir ci-dessous.
5. **Une erreur, une lacune ? Signale, ne corrige pas.** Terme fautif, traduction
   absente : **remonte-le à la coordination**, qui le transmet à la FICEDL. La
   correction se fait sur la source canonique, puis nous revient par re-synchronisation.
   *(Seule exception, déjà dite : une étiquette de langue simplement mal rangée peut
   être remise à sa place de notre côté, sans toucher au mot.)*
6. **Besoin d'un terme qui n'existe pas ?** Le thésaurus ne s'enrichit pas *localement*.
   Dans l'immédiat, les **mots-clés libres** (texte libre, propres à la fiche) sont la
   soupape — voir le guide « Indexer par sujet ». À moyen terme, une proposition
   d'ajout **remonte au collectif** de la FICEDL.

## L'esprit : consulter, pas capturer

Ce branchement est une **main tendue**, pas une prise : AnarBib *emprunte* un
vocabulaire commun sans se l'accaparer, le *reflète* sans le *figer*, et *rend* à la
FICEDL ce qu'il y observe. Le thésaurus reste vivant là où il doit l'être — dans la
fédération qui le porte — et notre catalogue en profite sans jamais le concurrencer.
C'est, au niveau des mots, la même éthique que partout dans AnarBib : **offrir et
relier, jamais capter**.

> Voir aussi : le guide **« Indexer par sujet »** (le geste concret au catalogage) et
> le cadrage **« Entraide au catalogage »** (le commun de savoir dont ce vocabulaire
> est le cœur). Le thésaurus de référence est consultable sur `thesaurus.ficedl.info`
> — source canonique qui fait foi.

*Document du commun AnarBib. Le thésaurus lui-même est l'œuvre de la FICEDL ; ce guide
en explique seulement l'usage dans AnarBib.*
