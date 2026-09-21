# Chantiers ouverts — par où commencer

*Document d'orientation, mis à jour le 21 septembre 2026. **Il n'arbitre rien** : la préséance documentaire reste celle de `docs/INDEX.md` — le REGISTRE fait foi, puis la spec du domaine, puis le backlog. Cette page ne fait que dire où des bras seraient utiles.*

Chaque entrée dit ce qu'elle demande et ce qu'elle apporte, pour que chacune et chacun choisisse sans avoir à demander.

*Trois des sept entrées ci-dessous ne demandent aucune compétence technique. Si c'est ce que vous cherchez, [`AIDER.md`](../AIDER.md) les reprend avec les chiffres du jour, en français, portugais et anglais.*

---

## 1. Refaire la reconstruction, chez vous — *le meilleur premier pas*

**Ce qui a été éprouvé.** Pendant longtemps cette entrée a dit : « personne n'a jamais vérifié que ce projet est reprenable par quelqu'un d'autre que celui qui l'a écrit ». Entre le 6 et le 15 septembre 2026, quelqu'un l'a vérifié. Un camarade de l'ASR (compte `ASR2026`, première contribution au projet) a rebâti la pile complète sur sa machine, depuis le dépôt seul, et il en a tiré un installateur : `install.sh`, fusionné le 15 septembre (PR #28). La réponse est donc oui — et elle a coûté ce qu'on attendait d'elle : une liste de ce qui ne marchait que sur une seule machine.

**Ce qui a cassé, et ce que c'est devenu.** `pg_cron` absent au démarrage d'un volume vierge ; un schéma à initialiser sous le rôle propriétaire ; des droits manquants sur `supabase_migrations` ; la langue au premier prompt ; un port à libérer. Tout cela est corrigé dans `deploy/`. Et un écart de fond, que personne n'aurait trouvé autrement : rejouer les migrations depuis zéro ouvrait au visiteur anonyme des fonctions que la production n'ouvre pas (REGISTRE `DOC-GRANT-2`). Il est réparé à la racine (`DOC-GRANT-3`) : le 7 septembre, un rejeu complet sur volume vierge a rendu, pour les fonctions ouvertes à l'anonyme, la même empreinte que la production, relevée à la même minute. Depuis le 16 septembre, la forge refait ce rejeu sur une image Supabase à chaque poussée.

**Ce qui reste, et que vous pouvez faire.** Une reconstruction par son auteur et une par l'auteur de l'installateur, cela fait deux machines. La troisième est la vôtre : lancer `install.sh` sur une machine vierge, en suivant `deploy/README.md` et rien d'autre, et écrire ce qui casse.

**Ce que ça demande.** Docker, une machine, une soirée. Aucun secret, aucun accès, aucune coordination. L'installateur parle les dix langues du projet.

**Ce que ça apporte.** La première reconstruction a dit que le projet est reprenable ; la vôtre dira si l'installateur l'est. C'est l'une des huit conditions à réunir avant de quitter l'hébergeur actuel (entrée 2), et par définition elle ne peut pas venir de nous. Un rapport d'échec détaillé vaut toujours plus qu'un correctif.

*— Le mainteneur, le 21 septembre 2026.*

---

## 2. Achever la bascule vers l'auto-hébergement

**Ce que c'est.** Aligner l'image GoTrue sur l'état réel des migrations, découpler la chaîne de déploiement de l'intégration continue, et poser un proxy inverse avec tunnel devant la pile.

**Ce que ça demande.** De l'administration système, du réseau, des conteneurs. C'est le chantier le plus technique et le plus autonome du lot.

**Ce que ça apporte.** La fin de la dépendance à un hébergeur tiers. C'est l'objectif que le projet s'est donné et qu'il n'a pas encore atteint.

> **État au 21/09/2026.** Le gel du mainteneur a pris fin le 14 septembre. Ce qui doit être vrai avant la bascule chez Les Herbes Folles tient en huit conditions, aucune techniquement difficile, listées au backlog (`I21`) ; `install.sh` sur une machine tierce vierge — l'entrée 1 — en fait partie.

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
