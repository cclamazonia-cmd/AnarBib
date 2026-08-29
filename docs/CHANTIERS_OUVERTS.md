# Chantiers ouverts — par où commencer

*Document d'orientation, mis à jour le 28 août 2026. **Il n'arbitre rien** : la préséance documentaire reste celle de `docs/INDEX.md` — le REGISTRE fait foi, puis la spec du domaine, puis le backlog. Cette page ne fait que dire où des bras seraient utiles.*

Chaque entrée dit ce qu'elle demande et ce qu'elle apporte, pour que chacune et chacun choisisse sans avoir à demander.

*Trois des sept entrées ci-dessous ne demandent aucune compétence technique. Si c'est ce que vous cherchez, [`AIDER.md`](../AIDER.md) les reprend avec les chiffres du jour, en français, portugais et anglais.*

---

## 1. Éprouver la reconstruction — *le meilleur premier pas*

**Ce que c'est.** Cloner le dépôt sur une machine qui n'est pas celle du mainteneur, monter la pile complète en suivant `deploy/README.md`, et écrire ce qui casse.

**Ce que ça demande.** Docker, une machine, une soirée. Aucun secret, aucun accès, aucune coordination : la pile se rebâtit depuis le dépôt seul.

**Ce que ça apporte.** La réponse à la seule question qui décide de tout le reste : *ce projet est-il reprenable par quelqu'un d'autre que celui qui l'a écrit ?* Personne ne l'a jamais vérifié. Un rapport d'échec détaillé vaut ici plus qu'un correctif : c'est la liste de ce qui ne marche que sur une seule machine.

---

## 2. Achever la bascule vers l'auto-hébergement

**Ce que c'est.** Aligner l'image GoTrue sur l'état réel des migrations, découpler la chaîne de déploiement de l'intégration continue, et poser un proxy inverse avec tunnel devant la pile.

**Ce que ça demande.** De l'administration système, du réseau, des conteneurs. C'est le chantier le plus technique et le plus autonome du lot.

**Ce que ça apporte.** La fin de la dépendance à un hébergeur tiers. C'est l'objectif que le projet s'est donné et qu'il n'a pas encore atteint.

> **Gelé jusqu'au 14 septembre 2026** pour le mainteneur : une démonstration publique tourne sur la production, et une migration d'infrastructure entamée deux semaines avant est le meilleur moyen d'arriver avec un système cassé. Le gel porte sur la production, pas sur le travail en environnement d'essai.

---

## 3. Le matériel éphémère

**Ce que c'est.** Tracts, affiches, autocollants, zines, bulletins ronéotés, périodiques militants. Une part énorme de nos fonds, et le besoin le plus mal couvert — y compris par AnarBib.

**Pourquoi c'est difficile.** Ce matériel n'a ni ISBN, ni éditeur, souvent ni auteur ni titre. Il est visuel autant que textuel : une affiche ne se résume pas à son océrisation. Il n'entre dans aucune notion de notice héritée de la bibliothéconomie du livre.

**Ce que ça demande.** Autant de réflexion documentaire que de code. Ce n'est pas un chantier pour quelqu'un qui veut seulement écrire des fonctions.

---

## 4. Interopérabilité — sortir vers les autres catalogues

**Ce que c'est.** Exposer le catalogue en OPDS, et publier en SKOS les correspondances entre les matières locales et les descripteurs du thésaurus de la FICEDL.

**Ce que ça demande.** Quelques heures pour un premier flux. Un alignement partiel vaut mieux que pas d'alignement.

**Ce que ça apporte.** Qu'un fonds catalogué avec un vocabulaire local reste trouvable par qui ne connaît pas ce vocabulaire — et dans dix langues, puisque le thésaurus est déjà traduit.

---

## 5. Les conventions néerlandaise et grecque

**Ce que c'est.** Les dix locales sont à parité stricte de clés, vérifiée par l'intégration continue. Mais les **conventions** de deux d'entre elles ne sont pas tranchées : le néerlandais est à l'état de brouillon, le grec reste à définir. Le test de parité ne voit pas ça — il compte les clés, pas leur justesse.

**Ce que ça demande.** D'être locutrice ou locuteur natif. Aucune compétence technique.

**Ce que ça apporte.** Deux langues qui cessent d'être des traductions approximatives.

---

## 6. Le vocabulaire des questions LGBTQI+

**Ce que c'est.** Le vocabulaire commun a vieilli sur ce sujet — et le constat ne vient pas de nous, il a été formulé par celles et ceux qui tiennent le thésaurus. La littérature concernée entre de plein droit dans nos bibliothèques et y est aujourd'hui mal décrite.

**Ce que ça demande.** Une discussion collective, pas un correctif. Ça ne se tranche pas dans un logiciel.

---

## 7. Des administrateurs réseau

**Ce que c'est.** Le réseau n'a aujourd'hui **qu'un seul administrateur**. Des décisions fédérales — l'admission d'une bibliothèque, par exemple — sont volontairement différées faute de pouvoir être prises à plusieurs.

**Ce que ça demande.** De la disponibilité et de la confiance, pas des compétences techniques.

**Ce que ça apporte.** Que le réseau cesse d'être suspendu à une seule personne. C'est le point le plus important de cette page, et le seul qu'aucun code ne réglera.

---

## Ce qui n'est pas ouvert

Les chantiers en cours par le mainteneur, listés dans le backlog courant de `docs/backlogs/`. Avant de vous lancer sur l'un d'eux, **ouvrez un ticket** : deux personnes qui écrivent le même correctif, c'est une soirée perdue pour l'une des deux.
