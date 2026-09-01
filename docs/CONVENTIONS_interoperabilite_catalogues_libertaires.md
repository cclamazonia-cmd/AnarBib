# Conventions minimales d'interopérabilité
## entre catalogues et archives libertaires

> **Brouillon soumis à discussion — 26/08/2026.**
> Ce texte n'engage personne. Il est fait pour être découpé, contesté et réécrit
> par celles et ceux qui tiennent des catalogues.

---

## Ce que ce texte est, et n'est pas

**Ce n'est pas** une charte, une adhésion, une structure. Il n'y a rien à
rejoindre, personne à qui demander l'autorisation, aucun échelon au-dessus.

**Ce n'est pas** une invitation à adopter le logiciel de quelqu'un d'autre.
Aucune des conventions ci-dessous ne suppose de changer d'outil, de partager du
code, ni de modifier son catalogue.

**C'est** une liste de quatre choses que des catalogues peuvent faire chacun
de leur côté, et qui, faites par plusieurs, les rendent capables de se parler.
On les applique unilatéralement. On les abandonne de même.

**Et ce n'est le texte de personne en particulier.** Il est proposé par un
projet parmi d'autres, à partir de ce que ce projet a déjà mis en œuvre — pas
depuis une position de surplomb. S'il devient utile, il devra cesser d'être
celui de qui l'a écrit.

---

## Le constat, en trois phrases

La FICEDL a produit un thésaurus de 620 descripteurs traduits en dix langues, et
chacun de ses termes renvoie déjà vers les catalogues qui l'emploient — CIRA de
Lausanne, CIRA de Marseille, CCL, archives du *Monde libertaire*, Placard,
Cartoliste. Le travail éditorial de coordination a donc **déjà eu lieu**, sur des
décennies.

Mais il n'existe que sous forme de pages web : lisibles par une personne,
illisibles par un programme. Aucun catalogue ne peut savoir qu'un autre détient
le même ouvrage, ni proposer à une lectrice le texte intégral qui existe
ailleurs.

Ce qui manque n'est pas un vocabulaire, ni une volonté, ni une organisation.
**C'est une expression machine de ce qui existe déjà.**

---

## Les quatre conventions

### 1. Exposer son catalogue en OPDS

Un flux OPDS est une liste de notices lisible par un programme. C'est le format
déjà employé par le réseau ALN et par plusieurs bibliothèques numériques
libertaires.

*Ce que ça coûte* : quelques heures sur un catalogue existant.
*Ce que ça permet* : qu'un autre catalogue puisse citer le vôtre.

### 2. Publier ses correspondances vers le thésaurus FICEDL, en SKOS

Vous gardez **votre** vocabulaire, votre graphie, vos choix éditoriaux — y
compris votre écriture inclusive, que le thésaurus commun n'impose pas et ne
doit pas imposer. Vous déclarez seulement, terme à terme, à quoi ils
correspondent dans le commun : `skos:exactMatch` quand c'est le même concept,
`skos:closeMatch` quand c'est voisin.

Un alignement partiel vaut mieux que pas d'alignement. Dix termes alignés sont
utiles ; il n'est pas nécessaire d'attendre d'avoir tout fait.

*Ce que ça coûte* : une soirée pour un petit vocabulaire.
*Ce que ça permet* : qu'une recherche dans une langue trouve un document indexé
dans une autre — le thésaurus étant déjà traduit en dix langues, l'alignement
vaut d'un coup pour toutes.

### 3. Permettre à une notice de pointer ailleurs

Qu'une notice de livre papier puisse indiquer où le texte intégral est
consultable, quand il l'est. Qu'une notice d'affiche puisse renvoyer vers
l'archive qui la conserve.

*Ce que ça coûte* : un champ.
*Ce que ça permet* : le seul bénéfice directement visible par une lectrice.

### 4. Accepter d'être pointé en retour

Un catalogue qui renvoie vers les autres accepte que les autres renvoient vers
lui, et publie ce qu'il faut pour ça — une clé stable par notice ou par
descripteur.

C'est la convention la moins technique et la plus politique : sans elle, les
renvois vont toujours des petits vers les grands.

---

## Ce que ce texte demande à la FICEDL

Une seule chose, et elle est le verrou de toutes les autres :

> **Que le thésaurus partagé soit publié dans un format machine-lisible — SKOS,
> RDF ou même un simple CSV — en plus de ses pages web actuelles.**

Aujourd'hui, tout outil qui veut s'appuyer sur le vocabulaire commun doit
l'aspirer page par page. Chacun refait ce travail dans son coin, avec ses
propres erreurs, sans savoir si sa copie est à jour. Un export officiel supprime
ce problème pour tout le monde, définitivement.


---

## Comment ce texte se modifie

Il n'a pas de propriétaire, donc pas de procédure. Quiconque l'applique peut
proposer d'en changer. Si une convention se révèle inapplicable, elle tombe ;
si elle manque, on l'ajoute.

Il n'y a pas de liste de signataires à tenir : appliquer une convention se
constate en regardant un catalogue, pas en consultant un registre.
