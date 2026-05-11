---
title: "Guide de gouvernance d'AnarBib"
subtitle: "À l'usage des coordinateur·rices de biblio et des administrateur·rices du réseau"
author: "Projet AnarBib"
date: "Version 1.0 — 11 mai 2026"
lang: fr
---

# Avant-propos

Ce guide s'adresse aux personnes qui, dans le réseau AnarBib, exercent une fonction de coordination — qu'il s'agisse de coordonner une biblio locale ou d'administrer le réseau. Il a un double objectif :

- **Expliquer la logique politique** des règles inscrites dans le SIGB AnarBib, et leur filiation avec le projet d'émancipation collective qui a donné naissance aux bibliothèques anarchistes ;
- **Outiller les pratiques** au quotidien, en répondant aux questions concrètes que les coordinations rencontrent quand elles utilisent le logiciel.

## Une convention politique

Ce guide n'est pas le règlement du réseau, et il n'a aucune autorité supérieure aux décisions des collectifs qui le composent. Ce qu'il contient n'a de force que parce que des humain·es se sont mis d'accord pour faire fonctionner les choses ainsi à un moment donné. Si les pratiques évoluent, ce texte devra évoluer avec elles, ou être contredit, ou être déchiré. C'est l'usage qui en sera fait par les collectifs qui décidera de son sort.

Les règles techniques que le SIGB AnarBib fait respecter — les délais de carence, les workflows de cooptation, les statuts des memberships, etc. — sont elles aussi des conventions. Elles ont été écrites par des camarades à des dates précises, pour résoudre des problèmes précis. Elles sont consignées dans des **fichiers de spécification** (les `spec-*.md` du dépôt), datés et signés, qui sont eux-mêmes amendables. Quand on lit ce guide, on lit l'état d'un débat à un instant donné. Ce n'est pas une constitution.

## Comment ce guide est organisé

Le guide est en deux parties :

- **Partie I — Le pourquoi.** Quatre chapitres qui posent le cadre politique : à quoi sert un SIGB anarchiste, quels sont ses principes fondateurs, comment s'articulent les deux périmètres (biblio locale et réseau), et comment les règles elles-mêmes peuvent être amendées.

- **Partie II — Le comment.** Six chapitres pratiques qui traitent chacun une grande question opérationnelle : coopter, retirer, gérer les situations qui dérapent, exercer une fonction d'admin réseau, garantir la transparence, et un dernier chapitre qui commente des cas concrets de bout en bout.

À la fin de chaque chapitre pratique, une rubrique **« Si la règle vous gêne »** rappelle où en discuter et comment proposer un amendement. C'est important parce que ces règles n'ont de sens qu'amendables.

Les annexes en fin de volume servent de référence rapide : glossaire, index des fonctions techniques avec leur traduction politique, modèle de proposition d'amendement, et liens vers les specs sources.

## Comment lire ce guide

On peut le lire d'un trait, mais ce n'est probablement pas le meilleur usage. Trois façons d'entrer dans le texte selon les besoins :

- **Pour comprendre l'esprit du projet** avant de prendre une fonction : lire la partie I (chapitres 1 à 4).
- **Face à une situation concrète** : sauter directement au chapitre pratique concerné (5 à 10).
- **Pour s'informer en vue d'une AG** où une question de gouvernance va être posée : lire le chapitre concerné plus la rubrique « Si la règle vous gêne » correspondante, et consulter la spec source en annexe D.

Ce qui est écrit ici s'appuie sur quatre documents de spécification :

- `spec-gouvernance-roles.md` (5 mai 2026) — rôles, statuts, transitions ;
- `spec-administrateur-reseau.md` (11 mai 2026) — séparation locale/réseau, cooptation à l'unanimité ;
- `spec-validation-physique.md` (3 mai 2026) — modes d'accueil des comptes lecteur·rices ;
- `spec-refactor-v3-semantique.md` (9 mai 2026) — sémantique du workflow réservation (mentionné en marge).

Les références à ces specs sont rappelées au fil du texte sous la forme `(cf. spec-gouvernance, §3.4)` pour permettre de creuser.

## Une note sur la voix

Le texte alterne entre **on** (le collectif AnarBib, dont l'auteur·rice et le·la lecteur·rice font également partie), **vous** (quand on s'adresse à un·e coord ou admin précis·e qui doit faire un choix), et **nous** (quand on parle des camarades qui ont écrit les règles, à un moment donné, et qui pourraient être différent·es de qui les lit). C'est volontaire. Il n'y a pas de neutralité institutionnelle ici : ce texte est porté par des camarades, et il s'adresse à des camarades.

\newpage

# Partie I — Le pourquoi

\newpage

# 1. Une SIGB anarchiste, ça veut dire quoi ?

## 1.1. Le SIGB n'est pas l'AG

Le premier principe à tenir, et le plus difficile, c'est celui-ci : **le SIGB enregistre les décisions du collectif, il ne les prend pas**. Cette phrase a l'air anodine. Elle est en réalité le pivot autour duquel tout le reste s'organise.

Toutes les fois où le SIGB AnarBib prend l'air d'une autorité — quand il refuse une promotion, quand il impose un délai de carence de sept jours, quand il bloque une transition de statut — il ne fait que **rendre exécutable** une règle que les collectifs se sont donnée. La règle a été écrite quelque part, dans une spec, après discussion. Quelqu'un a relu et critiqué. Une version a été figée et déployée. Et maintenant, dans l'instant où vous cliquez sur le bouton, le logiciel se contente d'appliquer ce qui a été convenu.

Si vous trouvez la règle bête, contre-productive, ou injuste, ce n'est pas le SIGB qu'il faut combattre. C'est la spec qu'il faut amender. Voir chapitre 4.

## 1.2. La tension assumée

Tout logiciel qui gère des permissions est, par construction, un dispositif de hiérarchisation. Il faut bien que quelqu'un puisse valider une inscription, modifier l'identité publique d'une biblio, accéder aux données personnelles d'un·e lecteur·rice. Cette nécessité technique est en tension apparente avec l'idéal d'horizontalité qui anime les bibliothèques anarchistes.

AnarBib **assume cette tension** plutôt que la masquer. Le compromis politique qu'on a trouvé tient en deux points :

- Les **rôles ne sont pas des grades**. Ce sont des **fonctions** temporairement déléguées par le collectif à certain·es de ses membres pour exécuter des tâches techniques précises. Personne n'est coordinateur·rice « à vie ». Personne n'est admin réseau « par essence ». Ces fonctions sont prêtées, et elles peuvent être reprises.

- Les **mécanismes de retrait** comptent autant que les mécanismes de nomination. Le SIGB prévoit explicitement comment quelqu'un sort d'une fonction — par auto-rétrogradation, par demande collective avec délai de carence, par auto-retrait du réseau, par retrait collectif à l'unanimité. Une fonction qui ne peut être quittée n'est pas une fonction, c'est une captation.

## 1.3. Délégation et rotation

L'idée centrale est celle de la **délégation avec rotation**. Un collectif délègue à certains de ses membres l'exécution de tâches techniques (gérer les emprunts dans le SIGB, modifier la visibilité de la biblio, accueillir un nouveau membre dans l'équipe). Cette délégation est :

- **Explicite** : elle s'incarne dans un acte de cooptation tracé dans l'audit log ;
- **Réversible** : la personne déléguée peut quitter la fonction quand elle veut, et le collectif peut le lui demander selon des modalités cadrées ;
- **Temporaire de nature** : même si aucune durée n'est imposée par le SIGB, la culture politique du réseau est qu'on fait tourner les fonctions, et on ne s'y installe pas.

C'est cette rotation des fonctions qui fait la différence entre une « délégation » (anarchiste) et une « hiérarchie » (étatique ou capitaliste). Si on s'installe dans une fonction, on devient un échelon. Si on en sort régulièrement, on reste un·e camarade qui rend un service.

## 1.4. Les huit principes fondateurs

La spec gouvernance des rôles (`spec-gouvernance-roles.md`, §2) explicite huit principes fondateurs. On les liste ici pour s'y référer dans la suite du guide ; chaque chapitre pratique de la partie II y renverra.

**P1 — Délégation, pas hiérarchie.** Aucun rôle n'est un titre. Tous les rôles sont temporaires par nature et révocables.

**P2 — Cooptation pour les rôles staff.** L'entrée dans une équipe (devenir librarian ou coordenador) se fait par cooptation des coordenadores existant·es. C'est au collectif de décider qui est admis ; le·la coordenador·a n'est que la main qui exécute la décision dans le SIGB.

**P3 — Rétrogradation volontaire toujours possible.** Toute personne avec un rôle staff peut se rétrograder elle-même à tout moment, sans consultation. « Je passe la main » est un droit fondamental.

**P4 — Exclusion encadrée par un délai de carence.** L'exclusion non volontaire d'un·e librarian par un·e coordenador·a passe par un délai de carence de sept jours avant effet. Ce délai permet la délibération collective et l'éventuelle annulation par un·e autre coordenador·a.

**P5 — Transparence maximale.** L'audit log des changements de rôle est lisible par l'ensemble du staff actif de la biblio, pas seulement par les coordenadores. Empêcher les manipulations opaques fait partie de la culture politique d'horizontalité informationnelle.

**P6 — Notifications systématiques.** Tout changement de rôle déclenche un email à la personne concernée et à toute la coordination. Personne ne peut être modifié·e dans son rôle sans le savoir, et la coordination est toujours informée.

**P7 — Souveraineté locale des biblios.** Les changements de rôle dans la biblio A n'affectent rien dans la biblio B, même pour la même personne. Chaque biblio est souveraine sur ses délégations internes.

**P8 — Le SIGB ne modélise pas l'AG.** Le SIGB exécute les décisions, il ne les prend pas. Il ne contient aucun mécanisme de vote, de quorum, ou de délibération. Ces choses se passent en collectif, hors logiciel.

## 1.5. Ce que le SIGB ne fait pas

Il est utile de rendre explicites les choix de **non-modélisation** :

- Le SIGB **ne définit pas** ce qu'est une « bonne » coordination. Une biblio peut décider en cercle, en AG plénière, par roulement, par tirage au sort, par consensus, par majorité. Le SIGB s'en moque.
- Le SIGB **ne mesure pas** la légitimité politique d'une cooptation. Si un·e coord clique sur « promouvoir X librarian », le SIGB enregistre. C'est au collectif de s'assurer que la décision a été prise correctement, et c'est dans la culture politique du collectif que se joue cette assurance.
- Le SIGB **n'arbitre pas** les conflits. Quand quelque chose dérape, le SIGB fournit des outils (suspension immédiate, demande de retrait, audit log lisible) mais la décision politique reste hors logiciel.

Cette modestie n'est pas un défaut, c'est une exigence. Un SIGB qui prétendrait modéliser la vie politique d'un collectif serait, ipso facto, autoritaire — il imposerait sa vision de ce qu'est une « bonne » décision. AnarBib refuse cette pente.

## 1.6. Et le respect des libertés numériques ?

Trois précisions, parce que la question revient :

- **Données personnelles** : les comptes lecteur·rices contiennent ce que la personne a bien voulu y mettre. Les biblios n'ont accès qu'aux données strictement nécessaires à leur fonctionnement. Les memberships dans d'autres biblios sont, par construction, étanches (P7).

- **Audit log** : le log est public **au staff actif** de la biblio, pas aux lecteur·rices ni au reste du réseau. Cette transparence interne sert à empêcher les manipulations opaques entre coordinations ; elle n'est pas un panopticon dirigé contre les lecteur·rices.

- **Logs cross-biblios** : quand un·e admin réseau intervient sur une biblio (cas couvert par la spec admin-reseau, §6.3.1), l'action est tracée dans une table dédiée avec niveau de criticité. C'est lisible par les admins réseau et par la coordination de la biblio concernée. La transparence dans les deux sens.

\newpage

# 2. Les deux périmètres : biblio locale et réseau

## 2.1. Pourquoi cette séparation

Le réseau AnarBib n'est pas une chaîne de bibliothèques avec un siège central. C'est une **fédération de collectifs autonomes**. Cette réalité politique a fini par s'imposer dans la structure du SIGB lui-même.

Initialement, dans les premières versions, le rôle d'« administrateur AnarBib » était rattaché à une biblio précise dans la table `user_library_memberships`. Cette modélisation suggérait — sans le dire — qu'un·e admin AnarBib *administrait une biblio*. Ce n'était pas vrai politiquement : un·e admin réseau anime la coordination inter-biblios, iel ne dirige aucune biblio en particulier.

La spec `spec-administrateur-reseau.md` (11 mai 2026) a acté la séparation. Désormais le SIGB connaît **deux périmètres distincts** :

- **Le staff local** d'une biblio (rôles `reader`, `librarian`, `coordenador`), stocké dans `user_library_memberships`. Son autorité politique se situe **dans le périmètre de la biblio**.

- **L'administration du réseau** (table `network_administrators`), sans rattachement à une biblio. Son autorité politique est **transverse**, mais elle ne se substitue jamais à l'autonomie locale.

## 2.2. Ce que chaque périmètre fait

**Le staff local** gère le quotidien d'une biblio : emprunts, retours, réservations, validation des inscriptions, modification du règlement, des politiques de circulation, de l'identité publique de la biblio. Tout ce qui concerne le fonctionnement d'**une** biblio se règle au niveau du staff local.

**L'administration du réseau** assure la coordination inter-biblios : activation des nouvelles biblios, modération du catalogue partagé, maintenance technique de la plateforme, accueil des nouveaux collectifs, et intervention exceptionnelle quand une biblio se retrouve en blocage (plus de coord actif·ve, conflit majeur, etc.). Tout ce qui concerne le **réseau** se règle au niveau de l'administration réseau.

## 2.3. La règle du non-recouvrement

Une règle politique simple guide tous les compteurs et toutes les vues du SIGB :

> **Chaque page raconte l'histoire de son périmètre. Un compteur compte ce qui est inscrit dans son périmètre, ni plus, ni moins.**

Concrètement :

- La page d'une biblio compte ses memberships locaux. Point. Les admins réseau n'apparaissent pas dans ces compteurs, même s'iels peuvent techniquement intervenir sur la biblio.
- La page du réseau compte ses administrateur·rices réseau. Point.

Si une personne est à la fois `coordenador` d'une biblio **et** administrateur·rice réseau (le cas de Xavier au 11 mai 2026), elle apparaît dans les deux compteurs, **une fois dans chaque**, sans dédoublonnage croisé. Ce sont **deux inscriptions politiques distinctes**, comptées chacune dans leur périmètre.

Pourquoi cette règle est politiquement saine, en quatre points :

- **Honnêteté** : ton engagement local est compté dans la biblio où tu animes ; ton engagement réseau est compté au niveau réseau. Personne ne te compte « 1,5 fois ».
- **Lisibilité** : un·e militant·e qui regarde la fiche d'une biblio voit immédiatement combien de personnes sont engagées **localement**, sans avoir à se demander si des admins réseau « extérieur·es » gonflent le compteur.
- **Robustesse** : si demain on ajoute des rôles intermédiaires (auxiliaire, stagiaire, observateur·rice), la règle « page = périmètre » reste claire.
- **Cohérence politique** : la séparation entre admin réseau et staff local est une **décision politique**, pas un détail de modélisation. Les compteurs doivent la refléter.

## 2.4. Le droit transverse de l'admin réseau

Ce point mérite d'être bien compris parce qu'il est facile à mal interpréter.

**Un·e admin réseau peut techniquement intervenir sur n'importe quelle biblio.** Iel peut, par exemple, lire le catalogue d'une biblio `private`, modifier sa visibilité, ou — dans des cas exceptionnels — créer ou modifier des memberships. C'est ce que la spec appelle le **droit d'intervention transverse**.

Ce droit existe pour deux raisons :

- **Maintenance** : il faut bien que quelqu'un·e puisse débloquer une biblio qui s'est mise en panne (plus de coord, configuration cassée, etc.).
- **Médiation** : quand un conflit grave traverse une biblio et empêche le collectif local de fonctionner, il faut un recours.

Mais ce droit ne fait **pas** de l'admin réseau un·e supérieur·e hiérarchique de la coordination locale. La doctrine du réseau, posée dans ce guide :

> **Une intervention d'admin réseau sur une biblio locale doit être précédée d'une information à la coordination locale concernée**, sauf urgence vitale (compromission active, harcèlement en cours, attaque contre la plateforme). L'information préalable n'est pas une demande d'autorisation : l'admin réseau a le droit d'agir. Mais elle est une **marque de respect** envers l'autonomie de la biblio, et elle préserve la possibilité d'un autre arrangement (par exemple : « laisse-moi essayer de régler ça d'abord, je te tiens au courant »).

La traçabilité technique existe par ailleurs : toutes les actions cross-biblios d'un·e admin réseau sont tracées dans la table `cross_library_actions_log` avec un niveau de criticité, lisibles par la coordination locale a posteriori.

## 2.5. La souveraineté locale est inviolable

Une dernière précision politique, qui découle du principe **P7 — Souveraineté locale des biblios**.

Les biblios du réseau AnarBib **se reconnaissent mutuellement**. Quand BLMF valide physiquement un·e nouveau·elle lecteur·rice (cf. `spec-validation-physique.md`), cette validation vaut pour toutes les biblios `network` du réseau. C'est un **pacte de circulation implicite** entre biblios qui partagent assez de culture politique pour se faire confiance.

Mais cette reconnaissance mutuelle **ne donne aucun droit d'ingérence** d'une biblio dans une autre. La coordination de la biblio A ne peut pas modifier les memberships de la biblio B. Elle ne peut pas voir les données personnelles des lecteur·rices de B (sauf ceux qui sont aussi inscrit·es chez elle). Elle ne peut pas changer le règlement de B.

Chaque biblio reste **souveraine sur ses délégations internes**, sa politique d'accueil, son mode de validation, ses règles de cotisation, son règlement intérieur. Le réseau ne dit pas comment elles doivent fonctionner. Il dit seulement avec qui elles se reconnaissent.

\newpage

# 3. Statuts, rôles, transitions : la grammaire du SIGB

Ce chapitre est un peu plus aride que les autres. On y pose le vocabulaire technique qui sera utilisé tout au long du guide. Si vous le sautez à la première lecture, vous pourrez y revenir au besoin.

## 3.1. Les quatre rôles

Le SIGB AnarBib utilise quatre rôles, déclarés dans la base de données par la contrainte `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` sur la table `user_library_memberships`.

**`reader`** — Compte lecteur·rice de base. Pas de pouvoir d'administration. Permissions : consulter le catalogue (selon la visibilité de la biblio), emprunter, réserver, consulter en salle, modifier ses propres données personnelles, demander la migration ou suppression de son compte.

**`librarian`** — Staff opérationnel·le. Gère le quotidien : emprunts, réservations, retours, validation des inscriptions (selon le mode de la biblio), modification des données catalogue, accès aux données personnelles des lecteur·rices de la biblio. **Lecture seule** sur la liste de l'équipe. Reçoit les notifications de changements de rôle et peut lire l'audit log de l'équipe (P5).

**`coordenador`** — Staff de coordination. Tout ce qu'a un·e librarian, plus : modifier l'identité publique de la biblio (nom, logo, contact, etc.), modifier la configuration (politiques d'emprunt, règlement), gérer les règles de cotisation, **et toutes les actions de gouvernance d'équipe** : coopter, demander un retrait, suspendre, lever une suspension, annuler une demande de retrait.

**`administrador`** — Rôle historique, en voie de disparition. Existait pour signifier « droit d'administration cross-biblios » mais rattaché à une `library_id`. Désormais remplacé par les **administrateur·rices réseau** stocké·es dans la table `network_administrators` (cf. chapitre 2). La spec admin-reseau prévoit la migration progressive et le retrait final de ce rôle de la table `user_library_memberships`.

## 3.2. Les cinq statuts d'une membership

Chaque ligne de la table `user_library_memberships` a un **statut** qui exprime l'état de la délégation à un instant donné. Cinq statuts sont possibles :

**`active`** — État normal. La personne a son rôle et l'exerce.

**`pending`** — Réservé à la spec validation physique. La membership est créée mais en attente d'une rencontre physique avec un·e librarian+ de la biblio d'inscription. Pas d'accès aux fonctions du rôle tant que ce statut.

**`suspended`** — **Mesure conservatoire** prise par un·e coordenador·a. Aucun accès. Usage : harcèlement signalé en attente d'investigation, compte compromis, conflit en cours de médiation. **Durée indéfinie** ; la levée est manuelle, par un·e coord (retour à `active`) ou par destitution effective.

**`pending_removal`** — **Période de carence de sept jours** avant exclusion effective. Aucun accès pendant cette période. Évolution possible : annulation par un·e autre coord (retour `active`), auto-rétrogradation par la personne elle-même (court-circuit), ou passage automatique à `inactive` à J+7.

**`inactive`** — Membership fermée. La personne n'est plus dans l'équipe. Aucun accès. Plusieurs origines possibles : sortie volontaire, fin de carence, compte abandonné (auto à 9 mois).

## 3.3. Le schéma de transitions

Le SIGB n'autorise pas n'importe quelle transition entre statuts. Voici, simplifié, le schéma autorisé :

```
                       ┌──────────────┐
                       │   active     │ ◄──────────┐
                       └──────┬───────┘            │
                              │                    │
              ┌───────────────┼───────────────┐    │
              ▼               ▼               ▼    │
       ┌─────────────┐  ┌─────────────┐  ┌─────────┴────┐
       │  suspended  │  │ pending_    │  │  inactive    │
       │             │  │ removal     │  │              │
       └──────┬──────┘  └──────┬──────┘  └──────────────┘
              │                │
              │ levée          │ annulation
              └────────────────┴────────────┐
                               │            │
                               ▼ (J+7)      ▼
                        ┌──────────────┐
                        │   inactive   │
                        └──────────────┘
```

Quelques règles clés :

- On ne peut **pas** passer directement de `active` à `inactive` pour un·e librarian par décision unilatérale d'un·e autre coord. Il faut passer par `pending_removal` et attendre la carence (ou que la personne se rétrograde elle-même).
- On peut **toujours** passer de son propre statut `active` à `inactive` (auto-rétro, droit P3).
- `suspended` n'a **pas** de durée maximale. Ce n'est pas une carence avant exclusion, c'est une mesure conservatoire — elle dure le temps de la délibération.
- De `inactive`, on **ne revient pas** à `active`. Pour réintégrer une personne, on crée une nouvelle ligne de membership. L'historique est préservé.

## 3.4. Les neuf transitions, qui peut faire quoi

La spec gouvernance des rôles formalise neuf transitions, listées ici de manière condensée. Le détail opérationnel est dans la partie II.

| # | Transition | Qui | Mécanisme |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coord+ | Cooptation |
| T2 | `librarian` → `coordenador` | Coord+ | Cooptation |
| T3 | `coordenador` → `librarian` | Soi-même OU autres coords | Auto-rétro OU retrait collégial avec carence |
| T4 | `librarian` → `reader` (volontaire) | Soi-même | Auto-rétro |
| T5 | `librarian` → `reader` (collectif) | Coord+ | `pending_removal` avec carence 7j |
| T6 | Suspension immédiate | Coord+ | Passage à `suspended` |
| T7 | Levée de suspension | Coord+ | Retour `suspended` → `active` |
| T8 | Annulation d'une demande de retrait | Coord+ | Retour `pending_removal` → `active` |
| T9 | Sortie automatique (compte abandonné) | Cron | Passage à `inactive` après 9 mois sans login |

Trois principes architecturent ce tableau :

- **L'entrée passe par la cooptation** (T1, T2). Personne ne se promeut soi-même.
- **La sortie volontaire est toujours possible** (T3 auto, T4). Personne ne reste pris·e dans une fonction qu'iel ne veut plus exercer.
- **La sortie imposée est ralentie par la carence** (T5). Sept jours pour permettre l'éventuel rétro-pédalage collégial.

## 3.5. Côté admin réseau : un schéma jumeau

L'administration réseau (table `network_administrators`) a son propre cycle de vie, structurellement très proche mais avec deux spécificités :

- **Cooptation à l'unanimité** : pour ajouter un·e nouveau·elle admin réseau, une proposition est ouverte par un·e admin actif·ve, et **tous les autres admins actif·ves** doivent voter `favorable`. Un seul vote `opposed` (avec rationale obligatoire de 20 caractères minimum) bloque la proposition. Une abstention bloque aussi tant qu'elle n'est pas convertie en vote.

- **Retrait collectif à l'unanimité** : pour retirer un·e admin réseau contre son gré, le même workflow s'applique en miroir. Avec un délai de carence de **sept jours** après accord unanime (champ `pending_collective_removal_until`).

L'auto-retrait, lui, est **unilatéral et toujours possible** (sauf si on est l'unique admin actif·ve, auquel cas la transition passe par `pending_removal` avec une carence de 30 jours, et un mail d'alerte aux autres admins).

Détails complets au chapitre 8.

\newpage

# 4. Réversibilité et amendabilité

Ce chapitre court traite d'une question politique cruciale : **comment ces règles peuvent-elles être modifiées ?** Si elles ne pouvaient pas l'être, le SIGB serait une autorité, et tout le reste de ce guide serait un mensonge.

## 4.1. Trois niveaux d'amendabilité

Il faut distinguer trois niveaux de règles, qui ne s'amendent pas de la même façon :

**Les pratiques locales d'une biblio** — politique d'accueil, mode de validation physique (`open` ou `manual_validation`), règlement intérieur, fréquence des AG, modalités de cooptation. Ces pratiques sont **internes à chaque biblio**. Le réseau ne s'en mêle pas. Elles s'amendent en AG de biblio, ou selon la procédure que le collectif s'est donnée.

**Les règles du réseau** — séparation locale/réseau, principe de cooptation à l'unanimité pour les admins réseau, doctrine d'information préalable lors d'une intervention cross-biblios, modalités d'activation des nouvelles biblios. Ces règles sont **inter-biblios**. Elles s'amendent en coordination réseau, après discussion entre admins réseau et coordinations locales concernées.

**Les fondements politiques du projet** — les huit principes (P1 à P8 du chapitre 1), l'idée que le SIGB ne modélise pas l'AG, la modestie revendiquée du logiciel face à la vie politique des collectifs. Ces fondements peuvent être amendés, mais ils sont structurants : les modifier, c'est probablement modifier ce qu'on appelle « AnarBib » au sens large. Une remise en cause de cette ampleur passerait par une discussion collective dans tout le réseau, probablement à l'occasion d'un événement (rencontre annuelle, etc.).

## 4.2. Comment proposer un amendement

Il n'y a pas une seule façon de faire — chaque niveau a la sienne — mais voici le pattern général que le réseau a tendance à pratiquer :

1. **Identifier la spec concernée**. Les règles du SIGB sont consignées dans des fichiers `spec-*.md` du dépôt. Trouvez celle qui contient la règle que vous voulez amender (l'annexe D donne les correspondances).

2. **Rédiger une note d'amendement**. Format libre, mais qui répond à : quelle règle, pourquoi elle pose problème, quelle modification on propose, quelles conséquences techniques et politiques on anticipe. L'annexe C propose un modèle.

3. **Faire circuler la note**. Selon le niveau :
   - **Local** : en AG de biblio, ou sur le canal de discussion du collectif.
   - **Réseau** : sur le canal de coordination inter-biblios (Matrix `#anarbib`), en taggant les admins réseau et les coordinations locales pertinentes.
   - **Fondements** : sur tous les canaux, et probablement à l'ordre du jour d'une rencontre.

4. **Discuter, amender, retenir une version**. Le SIGB ne dit pas comment cette étape doit se dérouler. C'est le métier des collectifs.

5. **Si la décision est prise** : un·e admin réseau ou un·e dev (souvent le ou les mêmes) implémente la modification dans la spec correspondante, puis dans le code. La nouvelle version est déployée selon la procédure habituelle (changelog, communication, etc.).

## 4.3. Si la décision technique pose problème

Il arrive qu'on tombe d'accord politiquement sur une règle, mais que sa traduction technique soit compliquée, lourde, ou ait des effets de bord indésirables. C'est normal. Les specs existantes sont pleines de notes du genre « cette décision politique implique de toucher à 22 sous-SELECT dans les RLS, ce qui justifie un refactoring préalable ». Le dialogue politique / technique est permanent.

Quand vous proposez un amendement, n'hésitez pas à le faire même si vous n'avez pas idée de la difficulté technique. Les dev du réseau vous diront ce que ça coûte. Et si c'est très cher, vous pourrez décider collectivement si l'enjeu politique vaut le coût technique. Inversement, parfois un changement politique anodin permet de simplifier énormément la base de code.

## 4.4. Ce guide est lui-même amendable

Ce guide est versionné. La version courante est indiquée sur la page de couverture. Si vous trouvez qu'il dit faux, qu'il a oublié un cas, ou qu'il prend une position qui ne correspond plus à la doctrine du réseau, **dites-le**. Ouvrez une discussion, proposez une modification, ou réécrivez le passage et soumettez-le.

Un guide qui ne peut pas être modifié n'est pas un guide, c'est un dogme. Le projet AnarBib n'a pas vocation à produire des dogmes.

\newpage

# Partie II — Le comment

\newpage

# 5. Coopter quelqu'un dans son équipe

Ce chapitre couvre les transitions T1 (`reader` → `librarian`) et T2 (`librarian` → `coordenador`), c'est-à-dire les **deux mouvements d'entrée** dans une équipe de biblio. La validation physique d'un·e nouveau·elle `reader` (qui n'est pas une cooptation au sens politique mais une opération technique d'accueil) est traitée séparément en §5.5.

## 5.1. Le principe politique

> **P2 — Cooptation pour les rôles staff.** L'entrée dans une équipe se fait par cooptation des coordenadores existant·es. C'est au collectif politique de décider qui est admis ; le·la coordenador·a n'est que la main qui exécute la décision dans le SIGB.

Cela signifie que **cliquer sur « Promouvoir »** n'est pas une décision personnelle du·de la coord qui clique. C'est l'**exécution technique** d'une décision qui a été prise — ou doit être prise — par le collectif politique de la biblio. La doctrine du réseau sur le « quand exactement » la décision doit être prise n'est volontairement pas tranchée par ce guide : chaque biblio fait sa propre doctrine (voir §5.4).

## 5.2. Pour faire entrer quelqu'un en tant que `librarian` (T1)

### Préconditions

- La personne a un compte AnarBib (elle est inscrite quelque part dans le réseau).
- Elle n'a pas déjà une membership `librarian` ou `coordenador` active dans la même biblio.
- Elle peut, ou non, avoir déjà une membership `reader` dans la même biblio. Si oui, cette membership existante restera active en parallèle (multi-membership autorisé).

### Procédure dans le SIGB

1. Aller dans `/biblioteca`, onglet **Equipe** (visible aux `coordenador+`).
2. Si la personne est déjà reader de la biblio, cliquer **« Inviter dans l'équipe »** sur sa ligne. Si elle n'est pas encore reader, utiliser la recherche dans la barre supérieure ou — si elle n'a pas encore de compte — passer par le workflow d'invitation par email (à venir, cf. `spec-invitation-equipe.md`).
3. Choisir le rôle `librarian`.
4. Confirmer la modale. Un champ « Raison » est optionnel — il sert à inscrire dans l'audit log le contexte de la cooptation (par exemple « décision AG du 04/05 », ou « cooptation en cercle restreint, à valider à la prochaine AG »).
5. Le SIGB exécute :
   - Création d'une ligne `user_library_memberships` avec `role='librarian'`, `status='active'`.
   - Email à la personne concernée : « Tu as été nommée librarian de [biblio] par [vous] ».
   - Email à tou·tes les coordenadores actif·ves de la biblio.
   - Entrée dans l'audit log : `action='promoted_to_librarian'`.

### Effet immédiat

La personne reçoit, sans délai, les permissions de `librarian` : gestion des emprunts, validation des inscriptions, accès aux données personnelles des lecteur·rices de la biblio, etc. Elle ne reçoit pas les permissions de modification de l'identité publique ni de la configuration — celles-ci sont réservées aux `coordenador+`.

### Côté technique

RPC concernée : `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.3. Pour promouvoir un·e `librarian` en `coordenador` (T2)

### Préconditions

- La personne a une membership `librarian` `active` dans la biblio.
- Elle n'a pas déjà une membership `coordenador` active dans la même biblio.

### Procédure dans le SIGB

1. Aller dans `/biblioteca`, onglet **Equipe**.
2. Sur la ligne de la personne, cliquer **« Promouvoir »** → **« coordenador »**.
3. Confirmer la modale. Le champ « Raison » est optionnel.
4. Le SIGB exécute :
   - Création (ou réactivation) d'une ligne `coordenador` `active`. L'ancienne ligne `librarian` reste active en parallèle (multi-membership ; voir §5.6).
   - Email à la personne.
   - Email à tou·tes les coordenadores actif·ves.
   - Entrée dans l'audit log : `action='promoted_to_coordenador'`.

### Effet immédiat

La personne reçoit, en plus de ses permissions de `librarian`, les permissions de coordination : modification de l'identité publique, de la configuration, des règles de cotisation, et toutes les actions de gouvernance d'équipe.

### Côté technique

RPC concernée : `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.4. La question politique : quand cliquer ?

C'est la question que tout·e coord se pose la première fois. Le réseau AnarBib **n'a volontairement pas tranché** cette question au niveau du guide : chaque biblio fait sa propre doctrine, parce que la culture politique d'un collectif anarchiste ne se décide pas à l'échelle d'un guide générique.

Voici les trois doctrines qu'on rencontre dans le réseau, sans jugement :

**Doctrine 1 — Attente stricte.** On ne clique qu'**après** une décision actée du collectif (AG, cercle, consensus formel, peu importe la modalité). Le coord ne fait qu'exécuter. Avantage : maximalisation de l'horizontalité, traçabilité politique forte. Inconvénient : peut être lent, particulièrement quand la biblio est en démarrage ou que le collectif est dispersé.

**Doctrine 2 — Anticipation balisée.** Le·la coord peut anticiper une décision qu'iel estime certaine (« c'est évident que Voltairine va être cooptée, ça fait six mois qu'elle vient toutes les semaines »), **à condition de l'expliciter dans l'audit log** : raison = « anticipation sous ma responsabilité, à valider à la prochaine AG ». La décision peut être contestée a posteriori, et le retrait reste toujours possible. Avantage : souplesse pratique. Inconvénient : déplace une part de responsabilité politique sur le·la coord qui clique.

**Doctrine 3 — Cercle de coord.** La cooptation est prise par accord entre les coords actif·ves de la biblio, sans passer par l'AG plénière. Argument : la coordination est elle-même un collectif délibérant, et elle a le mandat d'agir. Avantage : intermédiaire entre 1 et 2. Inconvénient : peut devenir opaque si la coordination n'est pas elle-même renouvelée.

**Notre recommandation** (et pas plus) : **choisissez explicitement** une doctrine, écrivez-la dans le règlement de votre biblio, et indiquez-la dans le champ « Raison » de l'audit log à chaque cooptation (« doctrine 2 — anticipation sous ma responsabilité » par exemple). L'opacité est rarement bonne en politique.

## 5.5. Cas particulier : la validation physique d'un·e `reader`

L'**arrivée** d'un·e `reader` dans une biblio est une opération différente d'une cooptation au sens politique. Elle est couverte par la spec `spec-validation-physique.md`.

Deux modes possibles, choisis par chaque biblio dans sa configuration :

**Mode `open`** — La validation est **automatique** à l'inscription. Une fois le compte créé et l'email confirmé, le·la `reader` a immédiatement accès aux catalogues `public` et `network`. Adapté aux biblios peu exposées politiquement.

**Mode `manual_validation`** — Le compte est créé en ligne mais reste **en attente** jusqu'à une **rencontre physique** entre le·la `reader` et un·e `librarian+` de la biblio d'inscription. Adapté aux biblios exposées (contexte politique tendu, fonds sensibles, locaux fragiles, etc.).

### Procédure de validation physique (mode `manual_validation`)

1. La personne s'inscrit en ligne et choisit votre biblio comme biblio d'attache.
2. Son compte est créé avec `status='pending'`. Elle reçoit un mail expliquant qu'elle doit venir se présenter physiquement à la biblio.
3. Quand elle vient, un·e `librarian+` la rencontre, vérifie ce qu'il y a à vérifier (la doctrine de ce que « vérifier » signifie est locale), et clique **« Valider »** sur sa ligne dans l'onglet **Equipe** → section **Comptes en attente**.
4. Un champ « Note » optionnel permet d'inscrire un contexte (« rencontre du 12/05 lors de la permanence, présentée par Emma »).
5. Le compte passe à `status='active'`. La personne reçoit un mail de bienvenue.

### Important politique

- La validation physique d'une biblio **vaut pour tout le réseau** des biblios `network` (P7 nuancé : la souveraineté locale concerne les délégations internes, mais la reconnaissance mutuelle est un pacte explicite).
- Ce qu'on « vérifie » lors d'une validation physique n'est **pas** un contrôle d'identité au sens administratif. C'est une rencontre. Chaque biblio en définit le sens politique. Pour certaines, c'est « on échange un peu pour vérifier que la personne n'est pas un·e flic ou un·e fasciste ». Pour d'autres, c'est « on présente la biblio, son fonctionnement, ses règles ». Pour d'autres encore, c'est juste « on se voit en vrai pour que la relation soit incarnée ».
- Une biblio peut **changer de mode** à tout moment (`coordenador+`). Le changement n'invalide pas les validations existantes.

## 5.6. Le multi-membership, point d'attention

Une particularité technique à comprendre : une personne peut avoir **plusieurs lignes** de membership dans la même biblio, avec des rôles différents. Par exemple, Voltairine peut être à la fois `reader` et `librarian` de BLMF. C'est rendu possible par la contrainte UNIQUE sur le triplet `(user_id, library_id, role)`.

**Pourquoi cette possibilité :** elle préserve l'historique. Si demain Voltairine se rétrograde de `librarian` à `reader`, sa ligne `librarian` passe à `inactive` mais la ligne `reader` reste — sans avoir à recréer une nouvelle inscription depuis zéro.

**Conséquence pratique :** dans l'UI, on affiche la personne **une seule fois**, avec son rôle **de plus haut niveau actif** (administrador > coordenador > librarian > reader). Dans l'audit log, en revanche, on voit chaque ligne séparément.

## 5.7. Erreurs et garde-fous

Quelques cas qu'on rencontre régulièrement :

**« Le SIGB me dit que la personne est déjà librarian. »** C'est probablement vrai. Vérifiez l'onglet **Equipe** : si la personne y figure déjà comme librarian, vous essayez de la promouvoir au même niveau, le SIGB renvoie un succès silencieux (`{ok: true, no_change: true}`) parce que rien à faire.

**« Je ne vois pas la personne dans la liste. »** Trois cas possibles : (a) elle n'a pas encore de compte AnarBib (utiliser le workflow d'invitation par mail à venir) ; (b) elle a un compte mais n'est inscrite dans aucune biblio (elle doit s'inscrire à votre biblio comme `reader` d'abord) ; (c) elle est dans le réseau mais filtrée par la recherche — essayer avec son email exact.

**« J'ai cliqué par erreur sur Promouvoir. »** Pas de panique. Utiliser **« Demander le retrait »** pour ouvrir une période de carence de 7 jours (cf. chapitre 6), ou demander à la personne de cliquer **« Je passe la main »** (auto-rétrogradation immédiate). Mentionner « erreur de manipulation » en raison.

**« La personne ne reçoit pas le mail. »** Vérifier d'abord l'orthographe de son email dans son profil, et lui demander de regarder ses spams. Si le problème persiste, en parler à un·e admin réseau : c'est probablement un problème de configuration mail à investiguer.

## 5.8. Si la règle vous gêne

Plusieurs choses peuvent ne pas vous convenir dans ce chapitre :

- **Le principe de cooptation lui-même** (P2). Vous pensez que toute personne `reader` engagée devrait pouvoir basculer librement en `librarian` sans avoir besoin de cooptation. C'est un débat politique de fond, qui touche au principe P1. À porter sur le canal de coordination réseau et probablement à discuter en rencontre.

- **L'absence de doctrine tranchée sur le « quand cliquer »** (§5.4). Vous pensez que le guide devrait recommander une seule doctrine. Ou au contraire vous trouvez qu'il en suggère trop. Proposer un amendement à ce chapitre, en argumentant.

- **Les modes de validation physique** (§5.5). Vous pensez qu'il en faudrait un troisième (« validation différée », « validation à distance », autre). À porter sur `spec-validation-physique.md`.

- **Le multi-membership** (§5.6). Vous pensez que c'est inutilement complexe et qu'il faudrait un seul rôle par personne par biblio. C'est une décision de modèle de données, plus structurante qu'il n'y paraît. À porter avec les dev.

Voir chapitre 4 pour la procédure générale d'amendement, et annexe C pour le modèle de note.

\newpage

# 6. Passer la main, retirer, suspendre

Ce chapitre couvre les transitions T3 à T8 — c'est-à-dire **tout ce qui sort une personne d'une équipe**, ou la met en pause. Politiquement, c'est probablement le chapitre le plus important du guide, parce que les mécanismes de retrait sont au cœur du projet anarchiste (cf. chapitre 1, §1.2).

## 6.1. Les principes politiques

Trois principes structurent ce chapitre :

> **P3 — Rétrogradation volontaire toujours possible.** Toute personne avec un rôle staff peut se rétrograder elle-même à tout moment, sans consultation. « Je passe la main » est un droit fondamental.

> **P4 — Exclusion encadrée par un délai de carence.** L'exclusion non volontaire d'un·e librarian par un·e coordenador·a passe par un délai de carence de sept jours avant effet. Ce délai permet la délibération collective et l'éventuelle annulation par un·e autre coordenador·a.

> **P6 — Notifications systématiques.** Tout changement de rôle déclenche un email à la personne concernée et à toute la coordination.

L'idée de fond est qu'on ne sort jamais quelqu'un d'une équipe « par surprise » ou « en silence ». Soit la personne décide elle-même (et c'est immédiat), soit le collectif demande (et c'est tracé, notifié, et délibérable jusqu'à la dernière seconde).

## 6.2. Passer la main : auto-rétrogradation (T3 et T4)

C'est le **droit le plus fondamental** dans le système de gouvernance d'AnarBib. Toute personne qui exerce une fonction staff peut, à tout moment, sans aucune consultation, la quitter.

### Quand l'utiliser

- Vous n'avez plus le temps d'assurer la fonction.
- Vous ne vous reconnaissez plus dans les décisions de la coordination.
- Vous êtes en désaccord avec une décision et vous voulez vous en désolidariser.
- Vous voulez simplement faire tourner la fonction.
- Vous avez besoin d'une pause.
- Pas de raison à donner, en fait. Le droit de partir est inconditionnel.

### Procédure

1. Aller dans `/biblioteca`, onglet **Equipe**.
2. Sur **votre propre ligne**, cliquer **« Je passe la main »**.
3. Choisir le niveau de rétrogradation :
   - Si vous êtes `coordenador`, vous pouvez choisir « repasser librarian » (vous restez dans l'équipe en tant que librarian) ou « quitter l'équipe » (vous repassez reader).
   - Si vous êtes `librarian`, vous pouvez choisir « quitter l'équipe » (vous repassez reader).
4. La modale rappelle les conséquences. Confirmer.

### Effet immédiat

- Votre membership actuelle (`librarian` ou `coordenador`) passe à `inactive`.
- Si vous n'aviez pas déjà la membership cible (`reader` ou `librarian`), elle est créée à `active`.
- Mail à toute la coordination + à vous-même (confirmation).
- Audit log : `action='self_demoted'`.

### Cas spécial : vous êtes l'unique coordenador·a actif·ve

Le SIGB **vous laisse partir**, mais il vous prévient :

> ⚠️ ATTENTION : tu es l'unique coordenador·a actif·ve de [biblio]. La biblio se retrouvera sans coordination. Les administrateur·rices AnarBib seront notifié·es. Continuer ?

Si vous confirmez :
- Votre membership coord passe à `inactive`.
- La biblio passe en **mode dégradé** : les `librarian` peuvent continuer à gérer les emprunts, valider les inscriptions, etc., mais aucune modification de l'identité publique ou de la configuration n'est possible jusqu'à la cooptation d'un·e nouveau·elle coord.
- Mail à tous les admins réseau : « La biblio X n'a plus de coordenador·a. Voici les librarians actifs : ... »

Politiquement, c'est important : le SIGB **n'empêche pas** votre départ. Mais il informe le réseau, pour qu'un·e admin réseau puisse, si vous le souhaitez et si le collectif local en a besoin, prendre contact pour aider à organiser la transition. C'est la rotation des fonctions en action.

### Côté technique

RPC : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

## 6.3. Demander le retrait d'un·e librarian (T5)

Quand le collectif décide qu'une personne doit quitter l'équipe, et que cette personne ne se rétrograde pas elle-même, on ouvre une **demande de retrait avec carence de sept jours**.

### Préconditions

- Vous êtes `coordenador+` actif·ve de la biblio.
- La personne cible a une membership `librarian` ou `coordenador` `active`.
- Vous n'êtes pas la personne cible (sinon utiliser §6.2).

### Procédure

1. Aller dans `/biblioteca`, onglet **Equipe**.
2. Sur la ligne de la personne, cliquer **« Demander le retrait »**.
3. La modale qui s'ouvre est **rouge et insistante**. Elle rappelle :
   - Le délai de carence : « Cette demande prendra effet le [date J+7] sauf annulation par un·e autre coordenador·a. »
   - Le caractère réversible : « Annulable par n'importe quel·le coord jusqu'à la date d'effet. »
   - Le caractère collégial : « Tou·tes les coords actif·ves seront notifié·es. »
4. Un champ **« Raison »** est obligatoire — minimum 20 caractères. Pas de retrait silencieux. La raison peut être politique (« décision AG du 04/05 ») ou pratique (« départ géographique annoncé »). Elle sera lisible par tou·te le staff dans l'audit log.
5. Confirmer.

### Effet immédiat

- La membership passe à `pending_removal`.
- Champ `pending_removal_until` = `now() + 7 days`.
- Champ `pending_removal_requested_by` = vous.
- **Aucun accès** pour la personne pendant la carence (la membership est gelée comme `suspended`).
- Mail à la personne concernée : « La coordination a demandé ton retrait de l'équipe [biblio] (préavis jusqu'au [date]). Cette décision relève de la vie organique du collectif [biblio] ; pour toute discussion, adresse-toi à la coordination. »
- Mail à tou·tes les coordenadores actif·ves : avec votre nom et la raison.
- Audit log : `action='removal_requested'` avec votre `actor_user_id` et le champ `reason`.

### Effet à J+7 (cron automatique)

Si la demande n'a été ni annulée ni court-circuitée :
- La membership passe à `inactive`.
- Mail final à la personne et à la coordination : « Retrait effectif. »
- Audit log : `action='removal_completed'`.

### Côté technique

RPC : `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron : `cron_team_pending_removal_complete` (s'exécute quotidiennement).

## 6.4. Annuler une demande de retrait (T8)

Le **garde-fou collégial** du système. N'importe quel·le coord — pas obligatoirement celui·celle qui a demandé — peut annuler une demande de retrait pendant la période de carence.

### Quand l'utiliser

- La discussion collective a abouti à une autre décision (médiation, suspension temporaire à la place, etc.).
- La demande initiale a été faite à chaud et la coordination veut reprendre la main collégialement.
- La personne cible a finalement été rejointe et la situation est désamorcée.

### Procédure

1. Aller dans `/biblioteca`, onglet **Equipe**, section **Suspensions et préavis en cours**.
2. Sur la ligne de la personne en `pending_removal`, cliquer **« Annuler la demande »**.
3. Modale simple de confirmation. Champ « Raison » optionnel.
4. Confirmer.

### Effet immédiat

- La membership repasse à `active`.
- Champ `pending_removal_until` remis à NULL.
- Mail à la personne : « La demande de retrait a été annulée. Tu retrouves tes prérogatives. »
- Mail à toute la coordination.
- Audit log : `action='removal_cancelled'` avec votre `actor_user_id`.

### Politiquement

L'annulation est volontairement très simple à activer. C'est un mécanisme de **rééquilibrage collégial** : si un·e coord a demandé un retrait à chaud, n'importe quel·le autre coord peut suspendre l'exécution le temps que le collectif délibère. Cela rend les demandes de retrait moins lourdes (pas de drame irréversible) mais aussi moins légères (n'importe qui peut vous contredire). C'est l'intérêt de la carence.

### Côté technique

RPC : `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Suspension immédiate : la mesure conservatoire (T6 et T7)

La suspension est un outil **différent** de la demande de retrait. Elle est **immédiate**, sans carence, et **sans durée maximale**. Ce n'est pas une exclusion, c'est une **mise en pause**.

### Quand l'utiliser

Cas-types prévus par la spec :

- **Compte compromis** : on a des raisons de penser que le mot de passe de la personne a fuité. On suspend en attendant qu'elle change son mot de passe.
- **Harcèlement signalé urgent** : un·e lecteur·rice signale un comportement abusif d'un·e membre staff. On suspend en attendant l'investigation collective.
- **Comportement manifestement abusif** observé en direct : on suspend le temps que la coordination se réunisse.
- **Conflit en cours de médiation** : la personne est mise en pause volontairement le temps que la médiation aboutisse.

### Procédure

1. Aller dans `/biblioteca`, onglet **Equipe**.
2. Sur la ligne de la personne, cliquer **« Suspendre »**.
3. Modale avec un champ **« Raison de la suspension » obligatoire** (minimum 20 caractères). Cette raison sera lisible dans l'audit log par tou·te le staff actif.
4. Confirmer.

### Effet immédiat

- La membership passe à `suspended`.
- **Aucun accès** pour la personne. Le rôle nominal est conservé (elle reste affichée comme « librarian suspendu·e ») mais elle ne peut plus rien faire.
- Mail à la personne concernée : urgent, avec la raison, et — dans le cas d'un compte compromis — une invitation à changer son mot de passe.
- Mail à toute la coordination.
- Audit log : `action='suspended'` avec votre `actor_user_id` et le champ `reason`.

### Levée de la suspension

Quand la situation est réglée (compte rebloqué, médiation aboutie, investigation conclue, etc.) :

1. Onglet **Equipe** → section **Suspensions et préavis en cours**.
2. Sur la ligne suspendue, cliquer **« Lever la suspension »**.
3. Modale simple. Champ raison optionnel mais recommandé pour clore politiquement l'épisode.
4. Confirmer.

Effet : retour à `active`, mails, audit log `action='unsuspended'`.

### Important : suspension vs retrait

La distinction est cruciale :

| | Suspension (T6) | Retrait (T5) |
|---|---|---|
| Effet | Immédiat | Différé (J+7) |
| Durée | Indéfinie | 7 jours puis `inactive` |
| Réversible par | Levée explicite | Annulation pendant la carence |
| Usage typique | Mesure conservatoire | Décision d'exclusion |
| Politique sous-jacente | « On se laisse le temps de comprendre » | « On a décidé que cette personne sort » |

Le SIGB **refuse** de faire passer une membership de `suspended` directement à `pending_removal` (la transition n'est pas autorisée par la matrice). Pourquoi : ce sont deux temporalités politiques distinctes. Pour passer de l'une à l'autre, il faut explicitement **lever la suspension** d'abord (retour `active`), puis demander le retrait (`pending_removal`). Cette double étape est volontaire : elle force le collectif à acter explicitement la transition.

### Côté technique

RPC suspendre : `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC lever : `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Rétrograder un·e autre `coordenador` (T3 collectif)

Un cas un peu particulier : que faire quand la coordination veut **rétrograder un·e coordenador·a** qui ne se rétrograde pas spontanément ?

La spec gouvernance traite ce cas comme une **demande de retrait avec carence** ciblant la membership `coordenador`. Concrètement, vous utilisez la même procédure qu'au §6.3 (« Demander le retrait »), mais en sélectionnant le rôle `coordenador`. La personne passe en `pending_removal` sur sa membership `coordenador` ; à J+7, cette membership passe à `inactive`. Si elle avait une membership `librarian` parallèle, celle-ci reste active (et la personne « retombe » librarian). Sinon, elle redevient simple `reader`.

C'est volontairement le même mécanisme que pour les `librarian`, avec les mêmes garde-fous. **Aucune autre coord n'a un pouvoir spécial** sur ses collègues : la procédure passe par la carence et la collégialité.

## 6.7. Compte abandonné : sortie automatique (T9)

Le SIGB inclut un mécanisme de **sortie automatique** pour les comptes qui n'ont pas eu de connexion depuis longtemps.

### Le seuil

Le SIGB regarde le champ `last_sign_in_at` côté Supabase. Si une membership staff a un user dont la dernière connexion remonte à plus de **9 mois**, le compte est progressivement sorti :

- **J-30 jours** (8 mois après la dernière connexion) : mail d'avertissement à la personne (« ta membership va être désactivée dans 30 jours sans connexion »).
- **J-7 jours** : mail de rappel.
- **J = 9 mois** : passage automatique à `inactive`. Mail final à la personne + à toute la coordination.

### Pourquoi cette règle

C'est un compromis entre deux exigences :

- Ne pas laisser **trainer indéfiniment** des memberships fantômes qui gonflent artificiellement les équipes.
- Ne pas **chasser** brutalement une personne qui aurait juste pris une pause et compte revenir.

Une simple connexion suffit à réinitialiser le compteur. Pas besoin d'effectuer une action, juste se connecter.

### Cas spécial : l'unique coord abandonne

Si la personne sortie automatiquement est l'**unique coordenador·a actif·ve** de la biblio, le cron escalade à un·e admin réseau **avant** d'exécuter la sortie. L'admin réseau est notifié·e par mail, peut entrer en contact avec la coordination (s'il en reste un fragment) ou avec les `librarian` de la biblio, et coordonner la transition.

Politiquement, c'est cohérent avec ce qu'on fait quand l'unique coord se rétrograde explicitement (§6.2) : on ne bloque pas la sortie, mais on alerte le réseau pour qu'il puisse aider si besoin.

## 6.8. Quelques cas-limites à connaître

**Une personne en `pending_removal` qui demande à partir tout de suite.** Elle peut. Il lui suffit d'utiliser elle-même « Je passe la main » (auto-rétro T4). Effet : passage immédiat à `inactive`, court-circuit de la carence. Politiquement, c'est cohérent : le droit P3 (auto-rétrogradation) est inconditionnel.

**Une personne en `suspended` qu'on veut exclure définitivement.** Voir §6.5 « Important : suspension vs retrait ». Il faut lever la suspension d'abord, puis demander le retrait.

**Quelqu'un demande son propre retrait via « Demander le retrait ».** Le SIGB refuse avec un message explicite : « Pour quitter l'équipe, utilisez l'option "Je passe la main" (auto-rétrogradation). » C'est volontaire : confondre une décision personnelle avec une décision collective brouillerait la sémantique politique.

**Tentative de rétrograder un·e admin réseau.** Refusée systématiquement. Le rôle d'admin réseau ne peut être modifié que via les mécanismes spécifiques de la spec admin-reseau (cf. chapitre 8). Aucun·e coord local·e ne peut destituer un·e admin réseau.

## 6.9. Si la règle vous gêne

**Le délai de carence de 7 jours vous semble trop long ou trop court.** À porter sur `spec-gouvernance-roles.md`, §4.4 et §5.6.

**Vous trouvez que la suspension sans durée maximale est une porte ouverte à l'arbitraire.** C'est un sujet politique sérieux. On peut envisager d'ajouter un délai au-delà duquel une suspension doit être convertie en retrait ou levée. À discuter en coordination réseau, puis à porter sur la spec.

**Vous trouvez que l'obligation de raison sur la suspension est un excès de bureaucratie.** Ou au contraire vous trouvez que le minimum de 20 caractères est trop court. À porter sur la spec.

**Vous trouvez que la sortie auto à 9 mois est trop rapide ou trop lente.** Le seuil est paramétrable, mais il est aujourd'hui le même pour toutes les biblios du réseau. Faut-il le rendre configurable par biblio ? À discuter.

Voir chapitre 4 et annexe C pour la procédure d'amendement.

\newpage

# 7. Quand quelque chose va mal

Ce chapitre traite des **situations exceptionnelles**, là où les mécanismes ordinaires de gouvernance ne suffisent pas, ou bien fonctionnent mais demandent du discernement politique. C'est aussi le chapitre où l'on parle franchement des **biblios qui n'ont pas (ou plus) de vie collective délibérante**, parce que le silence sur ce sujet ferait plus de tort que la franchise.

## 7.1. Biblio sans AG ou avec peu de membres

Le cas est plus fréquent qu'il n'y paraît. Une biblio en démarrage, à deux ou trois personnes. Une biblio qui a vu son collectif se réduire au fil des départs. Une biblio dont l'AG ne se tient plus depuis un moment, par manque de monde ou par découragement.

Le SIGB ne se mêle pas de la vie politique d'un collectif. Mais ce guide doit dire franchement ce qui change quand cette vie collective est faible.

### Ce qui change concrètement

**Le mot « cooptation » devient ambigu.** À deux personnes, qui coopte qui ? Si l'unique coord souhaite faire entrer Voltairine dans l'équipe, iel décide « seul·e » au sens politique du terme. Le SIGB l'autorisera (un·e coord+ peut coopter), mais ce n'est plus la coopération d'un collectif politique, c'est une décision personnelle déguisée. Ce n'est ni mal ni bien, c'est simplement à reconnaître.

**Les délibérations sont théoriques.** Une demande de retrait à 7 jours, dans une biblio à 2 personnes, n'a personne d'autre pour la contredire que celui·celle qui l'a demandée. Le « garde-fou collégial » devient une auto-réflexion.

**Le risque de personnalisation augmente.** Quand une décision n'est plus collective, elle dépend du caractère, de la disponibilité, et de la lucidité d'une ou deux personnes. Ce n'est pas catastrophique en soi, mais c'est plus fragile.

### Nos recommandations explicites

**1. Reconnaissez la situation.** Ne faites pas semblant que vous êtes un grand collectif délibérant si vous êtes deux. Politiquement, c'est plus sain d'écrire « décision prise par moi seul·e, à valider quand le collectif s'étoffera » dans le champ « Raison » de l'audit log, que d'écrire « décision AG » à une AG qui n'existe pas.

**2. Cherchez du dialogue à l'extérieur.** Si vous êtes seul·e ou à deux, et qu'une décision importante doit être prise (cooptation, retrait, suspension), prenez l'habitude d'en parler à des camarades d'autres biblios du réseau, ou à un·e admin réseau. Pas pour leur demander une autorisation — ils n'ont pas à valider les décisions internes de votre biblio — mais pour avoir un retour critique externe. Le réseau Matrix d'AnarBib est fait pour ça.

**3. Privilégiez les transitions réversibles.** Quand votre collectif est petit, évitez si possible les décisions irréversibles. Une suspension est plus réversible qu'un retrait. Un retrait passe par 7 jours pendant lesquels vous pouvez changer d'avis. Une cooptation est annulable. Donnez-vous du temps.

**4. Documentez ce qui se passe.** Le champ « Raison » de l'audit log est votre meilleur ami. Plus vous y mettez de contexte (« cooptation de Voltairine, décidée seul·e, à valider à la prochaine permanence »), plus la décision sera contextualisable plus tard, par vous-même comme par un·e nouveau·elle membre du collectif.

**5. Si vous êtes vraiment isolé·e, demandez de l'aide.** Une biblio à une personne est en péril politiquement. Le SIGB le détecte au moment où la dernière coord se rétrograde (§6.2) ou abandonne (§6.7), et alerte les admins réseau. Vous pouvez aussi prendre l'initiative : envoyez un mail à la coordination réseau pour expliquer la situation. Plusieurs biblios du réseau ont traversé des passages à vide et ont été aidées à se reconstituer.

### Ce que le guide ne fait pas

Il ne fournit **pas** de procédure spéciale pour les petites biblios. C'est volontaire. Les règles du SIGB s'appliquent uniformément — ce qui change, ce sont les conditions politiques dans lesquelles elles s'appliquent. Reconnaître cette nuance fait partie de la maturité politique d'un·e coord.

## 7.2. Conflit interpersonnel dans une coordination

Un conflit éclate entre deux membres staff. Le travail ne se fait plus correctement, l'ambiance se dégrade, des lecteur·rices perçoivent la tension.

### Ce que le SIGB peut faire

Pas grand-chose, directement. Le SIGB n'arbitre pas les conflits. Mais il fournit des **outils utilisables** :

- **Suspension provisoire (T6)** d'une ou des deux personnes, le temps que le conflit soit médié. C'est ce que la spec appelle explicitement « conflit en cours de médiation » comme cas d'usage légitime de la suspension.
- **Auto-rétrogradation (T3/T4)** — si une des deux personnes choisit de prendre du recul, c'est immédiat.
- **Audit log lisible par tout le staff** — permet à l'ensemble du staff de voir qui a fait quoi, et d'éviter les manipulations opaques d'un·e coord qui chercherait à régler le conflit en sortant l'autre en douce.

### Ce que le collectif doit faire

- **Médiation**. Le SIGB ne médie pas. Il faut une personne tierce de confiance, en dehors du conflit. Selon les configurations : un·e autre coord de la biblio, un·e camarade d'une autre biblio, un·e admin réseau.
- **Décision collective**. Si la médiation aboutit à une décision (l'une des deux personnes quitte la coordination, ou bien on définit un cadre de travail revu), le SIGB exécutera cette décision via les RPCs normales.
- **Trace politique**. Si la décision est de retirer quelqu'un, le champ « Raison » devrait mentionner le processus de médiation (« retrait suite à médiation du JJ/MM, décision collective ») pour ne pas réécrire l'histoire plus tard.

### Ce qu'il faut éviter

- **Utiliser une suspension comme arme** dans le conflit. La suspension est faite pour mettre en pause, pas pour gagner un rapport de force. Si un·e coord suspend l'autre sans processus de médiation, c'est observable dans l'audit log, et c'est politiquement problématique.
- **Court-circuiter la carence** par des manœuvres techniques (suspendre puis « accélérer » par d'autres moyens). Tout est tracé, et le réseau s'en apercevra.
- **Faire silence sur l'audit log**. Tout le staff voit ce qui se passe (P5). Si vous tentez de cacher le conflit, vous trahissez la transparence du collectif.

## 7.3. Harcèlement signalé

Un·e lecteur·rice signale qu'un·e membre staff a un comportement abusif (harcèlement sexuel, abus de pouvoir, comportement raciste, etc.).

### Démarche recommandée

**1. Prendre le signalement au sérieux**, immédiatement, même si la personne signalante est isolée et même si la personne signalée est « connue et appréciée » de la coordination. Le réflexe d'écarter le signalement comme « probablement exagéré » est l'erreur la plus courante.

**2. Suspension immédiate (T6)** de la personne signalée, **à titre conservatoire**, en attendant l'investigation. Le champ « Raison » devrait dire quelque chose comme « Suspension conservatoire suite à signalement reçu le JJ/MM, en attente d'investigation collective ». La suspension n'est **pas** une accusation, c'est une mise en pause.

**3. Constituer un groupe d'investigation**. Hors logiciel. Au minimum : des camarades hors de la situation de pouvoir directe, capables d'entendre les deux côtés sans biais. Ce groupe peut inclure des camarades d'autres biblios si la biblio est petite ou si tous les coords sont compromis dans l'affaire.

**4. Communiquer avec la personne signalante**. Elle a besoin de savoir que c'est pris au sérieux, et que des mesures sont en cours. Ne pas la laisser dans l'incertitude.

**5. Aboutir à une décision**. Selon ce que l'investigation révèle :
   - Levée de la suspension (T7) si le signalement n'est pas confirmé.
   - Retrait définitif (T5 avec carence) si le signalement est confirmé et la décision est de sortir la personne.
   - Sanction intermédiaire (cadre de travail revu, formation, mise à l'écart de certaines fonctions) si la situation est plus nuancée.

**6. Tracer politiquement**. Le champ « Raison » dans l'audit log devrait refléter la décision collective. Pas de détails sur la victime (RGPD), mais une formulation qui rend la décision lisible.

### Ce qu'il ne faut pas faire

- **Demander un retrait directement** sans suspension préalable, alors que la situation est urgente. Pendant 7 jours la personne signalée conserverait ses droits, ce qui est contradictoire avec l'urgence d'un signalement d'abus.
- **Suspendre indéfiniment sans décision** sous prétexte que « on n'arrive pas à trancher ». Une suspension qui dure plusieurs mois sans décision devient elle-même une violence (envers la personne suspendue, qui ne peut pas se défendre, et envers la personne signalante, qui ne reçoit pas de réponse).
- **Régler en interne sans le réseau**. Si vous êtes une petite biblio et que la situation vous dépasse, demandez de l'aide aux admins réseau. Vous n'êtes pas seul·es.

## 7.4. Compte compromis

Une personne staff voit son compte compromis (mot de passe leaké, suspicion d'accès non autorisé).

### Procédure immédiate

**1. Suspension immédiate (T6)** du compte, avec raison explicite : « Suspicion de compromission, MP probablement leaké, vérification en cours ».

**2. Communication avec la personne concernée**. La personne reçoit automatiquement un mail urgent indiquant la suspension et l'invitant à changer son mot de passe. Le·la coord qui suspend devrait aussi prendre contact directement (téléphone, autre canal sécurisé) pour confirmer.

**3. Investigation rapide.** Que s'est-il passé ? Le compte a-t-il fait des actions inhabituelles dans l'audit log (cooptations bizarres, modifications de configuration, etc.) ? Si oui, prévenir immédiatement un·e admin réseau pour aider à analyser.

**4. Levée de la suspension (T7)** une fois que :
   - Le mot de passe est changé.
   - L'éventuel dommage est constaté et réparé (annulation des actions abusives, restauration des données, etc.).
   - La personne est en sécurité numériquement.

### Politiquement

Une suspension pour compte compromis **n'est pas un blâme**. C'est une protection mutuelle : on protège la personne (en empêchant qu'elle soit utilisée par un·e attaquant·e) et la biblio (en empêchant que des dégâts soient faits en son nom). Le mail à la personne devrait insister sur ce caractère **non-disciplinaire**.

## 7.5. Biblio sans coord ni librarian actif·ves

Le scénario catastrophe : plus aucun·e staff actif·ve. Cela peut arriver par sortie auto cumulée (tous les membres staff ont abandonné leur compte simultanément), par démission collective (rare mais possible), ou par succession de retraits.

### Conséquences

- La biblio reste **techniquement active** (sa visibilité, son catalogue restent accessibles selon les RLS habituelles).
- Mais **aucune action de gestion** ne peut plus être faite via l'UI normale : pas de validation d'inscription, pas de gestion d'emprunt, pas de modification de la configuration.
- **Mail urgent aux admins réseau** par le cron qui détecte la situation.

### Procédure de redémarrage

Hors-spec, mais voici ce qui se pratique :

**1. Prise de contact** par un·e admin réseau avec le collectif local, par tous les canaux disponibles (le ou les comptes lecteur·rice qui restent inscrit·es, les coordonnées externes de la biblio si elles existent, le réseau de connaissances local).

**2. Vérification politique** : est-ce que le collectif existe encore ? Veut-il continuer à exister ? S'il y a des membres mais qu'iels ont juste laissé tomber les fonctions techniques, on peut recoopter de nouveaux staff par cooptation hors-workflow.

**3. Cooptation hors-workflow** par l'admin réseau, via SQL direct ou via l'UI (un·e admin réseau a le droit d'agir comme coord+ sur n'importe quelle biblio, cf. chapitre 2). La cooptation hors-workflow doit être tracée dans l'audit log avec une raison explicite : « Reprise de coordination après vacance, suite à contact du collectif du JJ/MM, par admin réseau X ». Et — point clé de doctrine — **information préalable à la coordination locale obligatoire**, sauf si la biblio n'a plus aucun·e membre staff vivant·e auquel cas l'information passe par les `reader` actif·ves restant·es (cf. §7.6).

**4. Si le collectif n'existe plus** : ouverture d'une discussion sur la **fermeture propre** de la biblio. Quelles données conserver, lesquelles supprimer, comment communiquer aux lecteur·rices, etc. C'est un workflow à formaliser séparément.

## 7.6. L'intervention d'un·e admin réseau sur une biblio locale

Un cas qu'on touche déjà dans le chapitre 2, mais qui mérite un développement pratique dans ce chapitre des situations exceptionnelles.

### La doctrine du réseau

> **Une intervention d'admin réseau sur une biblio locale doit être précédée d'une information à la coordination locale concernée, sauf urgence vitale.**

L'information préalable **n'est pas une demande d'autorisation**. L'admin réseau a le droit d'agir (c'est le sens du droit transverse). Mais elle est une marque de respect envers l'autonomie locale, et elle préserve la possibilité d'un autre arrangement.

### Ce qu'est une « urgence vitale »

C'est volontairement restrictif. Cas-types :

- **Compromission active** : une action en cours menace l'intégrité de la biblio ou du réseau (compte attaquant qui modifie des memberships en temps réel, etc.).
- **Harcèlement en cours** : un·e membre staff abuse activement de ses fonctions, le danger pour les lecteur·rices est immédiat.
- **Attaque contre la plateforme** : tentative d'intrusion, exfiltration de données, etc.

Hors de ces cas, **on prend le temps d'informer**.

### Comment informer

Avant l'intervention (ou pendant, si l'urgence le justifie a posteriori) :

- **Mail à la coordination locale** expliquant ce qui va être fait, pourquoi, et avec quelle traçabilité.
- **Mention dans la table `cross_library_actions_log`** avec un niveau de criticité indiquant la nature de l'action. Tous les coords actif·ves de la biblio reçoivent une notification.
- **Disponibilité au dialogue** : la coordination locale doit pouvoir poser des questions, demander des précisions, voire négocier un autre arrangement (« laisse-nous essayer d'abord »).

### Ce qu'il faut éviter

- **L'intervention silencieuse** : agir sur la biblio sans en informer la coordination. Même si techniquement c'est tracé, politiquement c'est une violation de la souveraineté locale.
- **L'usage du droit transverse comme un pouvoir de surveillance** : aller voir « ce qui se passe » dans une biblio sans raison opérationnelle. Le droit transverse existe pour des cas de maintenance ou de médiation, pas pour de la curiosité.
- **L'imposition de décisions politiques** : un·e admin réseau ne peut pas dire à une biblio comment faire ses cooptations, comment gérer ses conflits internes, ou quelle politique d'accueil choisir. Le droit transverse est technique, pas politique.

## 7.7. Si la règle vous gêne

**Vous trouvez que la doctrine d'information préalable est trop souple** (un·e admin réseau pourrait abuser de l'« urgence vitale »). À discuter : faut-il une définition plus stricte de l'urgence ? Faut-il un second admin réseau qui confirme l'urgence ?

**Vous trouvez la doctrine trop stricte** (parfois on a besoin d'agir vite sans tout expliquer). À discuter : faut-il distinguer plusieurs niveaux d'intervention, avec des règles d'information différentes selon la criticité ?

**Vous trouvez que le silence sur la fermeture propre d'une biblio est problématique** (§7.5). Vous avez raison. Une spec dédiée est probablement à écrire. À porter au réseau.

**Vous trouvez que ce chapitre laisse trop de place à l'improvisation** dans les cas de harcèlement (§7.3). C'est sans doute vrai. Une spec dédiée sur les processus de médiation et d'investigation pourrait être bénéfique. À porter au réseau.

Voir chapitre 4 et annexe C.

\newpage

# 8. Le rôle d'administrateur·rice réseau

Ce chapitre s'adresse spécifiquement aux administrateur·rices réseau (présent·es ou futur·es), et aux coordinations locales qui veulent comprendre comment le réseau s'auto-organise au niveau supérieur. Il complète et approfondit les chapitres 2 et 7.

## 8.1. Une fonction politique distincte

Avant tout : être **admin réseau** n'est ni un grade, ni une consécration, ni un titre. C'est une **fonction transverse** que le collectif des admins réseau délègue à certain·es de ses membres, sur la base d'un accord unanime des admins déjà en place, et qui peut être quittée à tout moment.

Le projet politique de la fonction est de **faire vivre la coordination inter-biblios** : accueillir les nouvelles biblios qui rejoignent le réseau, animer les discussions sur les évolutions techniques et politiques du SIGB, maintenir la plateforme techniquement, intervenir quand une biblio se retrouve en blocage. Ce n'est pas une fonction de direction. C'est une fonction d'animation et de service.

### Ce qu'un·e admin réseau peut faire (politiquement)

- Activer une nouvelle biblio qui a fait sa demande d'inscription au réseau.
- Animer les discussions inter-biblios (le canal Matrix `#anarbib`, les rencontres, les listes mails internes).
- Coordonner les évolutions de la plateforme (specs, releases, communications).
- Intervenir sur n'importe quelle biblio en cas de blocage technique (droit transverse).
- Médier entre deux biblios en cas de conflit (si les coordinations le souhaitent).
- Proposer ou voter sur la cooptation et le retrait collectif d'autres admins réseau.

### Ce qu'un·e admin réseau ne peut pas faire (politiquement)

- Diriger une biblio.
- Imposer une décision politique à une biblio (politique d'accueil, mode de validation, cooptations internes, etc.).
- Évincer un·e coord local·e contre l'avis de sa biblio.
- Modifier seul·e les règles du réseau (cela passe par une discussion collective des admins et idéalement des coordinations).

## 8.2. La cooptation à l'unanimité : pourquoi

L'admin réseau n'est pas ajouté·e à la majorité, mais à l'**unanimité** des admins en place. Cette règle peut surprendre — pourquoi pas une majorité simple, une majorité qualifiée, ou un quorum ?

La raison politique est simple : le pouvoir d'un·e admin réseau est **transverse**. Iel peut intervenir sur n'importe quelle biblio. Il faut donc que **chaque admin réseau actuellement actif·ve** soit prêt·e à travailler avec la nouvelle personne. S'il y a un seul désaccord profond, la coopération sera empoisonnée — autant ne pas l'imposer.

Cette règle a une conséquence pratique importante : **le veto est facile**. Un seul vote `opposed` suffit. C'est volontaire. On préfère qu'une cooptation n'aboutisse pas, plutôt qu'elle laisse un·e admin existant·e en porte-à-faux durable.

## 8.3. Workflow de cooptation, en détail

### Étape 1 — Proposition

Un·e admin réseau actif·ve, depuis l'interface `/rede/administradores` (à venir au paquet D), clique **« Proposer une cooptation »**.

- Saisit l'identité de la personne proposée (cherche dans la base des users AnarBib).
- Saisit une **motivation** obligatoire de **minimum 20 caractères**. Cette motivation est lisible par tou·tes les admins, et — en cas de réussite — sera incluse dans la notification à la personne cooptée.
- Confirme.

Le SIGB :
- Crée une ligne dans `network_administrator_cooptation_proposals` avec `status='open'`, `expires_at = now() + 30 jours`.
- Enregistre automatiquement le vote `favorable` du proposeur.
- Envoie un mail militant à tou·tes les autres admins actif·ves les invitant à voter.

### Étape 2 — Votes

Chaque autre admin actif·ve a 30 jours pour voter. Trois options :

- **`favorable`** : iel accepte la cooptation.
- **`opposed`** : iel met son veto. **Rationale obligatoire** de minimum 20 caractères. Cette rationale sera communiquée à la personne proposée et au proposeur en cas de rejet.
- **`abstain`** : iel s'abstient. **L'abstention bloque** : la proposition n'aboutit qu'à l'unanimité des votes `favorable`. Une abstention non levée a le même effet pratique qu'un veto, sauf qu'elle peut être convertie en favorable plus tard si la personne change d'avis.

### Détail v0.3 — Divulgation d'identité

Une option **« Révéler mon identité en cas de rejet »** est cochée par défaut. Si vous votez `opposed`, votre identité sera communiquée à la personne proposée et au proposeur, en plus de votre rationale.

Vous pouvez **décocher** cette option pour rester anonyme. Dans ce cas, la rationale sera transmise sans votre nom (« un·e opposant·e a soulevé : ... »).

Politiquement, la **transparence par défaut** correspond à la culture militante d'assomption des positions. Mais l'anonymat reste possible pour les cas où une opposition exposerait l'opposant·e à un coût personnel disproportionné.

### Rappels automatiques

Le cron envoie des rappels aux admins qui n'ont pas encore voté :
- **J+14 jours** : « Tu n'as pas encore voté sur la cooptation de X. »
- **J+25 jours** : « Cette proposition expire dans 5 jours, prends position. »

### Étape 3 — Conclusion

**Si quelqu'un vote `opposed`** : la proposition passe immédiatement à `status='rejected'`. La personne proposée et le proposeur reçoivent un mail expliquant le rejet, avec la rationale (et l'identité de l'opposant·e si elle a accepté la divulgation).

**Si tou·tes les admins actif·ves ont voté `favorable`** : la proposition passe à `status='completed'`. Une ligne est insérée automatiquement dans `network_administrators` avec `status='active'` et `coopted_by_unanimity_of = ARRAY[<liste des voteurs>]`. La personne reçoit un mail de bienvenue et un récap est envoyé à tou·tes les admins.

**Si 30 jours s'écoulent sans qu'on aboutisse à un consensus** : la proposition passe à `status='expired'`. Pas de cooptation. Il faut soit recommencer une nouvelle proposition, soit considérer que le réseau n'est pas prêt à accueillir cette personne pour l'instant.

## 8.4. Le retrait collectif à l'unanimité

Le **retrait collectif** est le miroir de la cooptation : pour retirer un·e admin réseau contre son gré, il faut l'unanimité des autres admins actif·ves.

### Workflow

1. **Proposition de retrait** par un·e admin réseau actif·ve, motivation obligatoire ≥ 20 caractères.
2. **Votes** des autres admins (favorable / opposed / abstain), avec rationales si `opposed`.
3. **Si unanimité `favorable`** : la membership de la personne visée passe à `pending_removal`, avec `pending_collective_removal_until = now() + 7 jours`.
4. **Pendant les 7 jours de carence** : la personne visée conserve ses droits opérationnels, mais reçoit un mail clair sur sa sortie programmée. Elle peut éventuellement engager une dernière discussion. **Elle ne peut pas annuler le retrait unilatéralement** : seul·e l'unanimité des autres admins peut revenir en arrière (en proposant une « annulation de retrait », workflow miroir).
5. **À J+7** : passage à `status='removed'`, `removed_at=now()`.

### Politiquement

Le **double verrou** (unanimité + carence 7j) rend le retrait collectif d'un·e admin réseau particulièrement difficile. C'est voulu. Le pouvoir d'un·e admin réseau étant transverse, on ne le révoque pas à la légère.

Inversement, **l'auto-retrait reste toujours possible et facile** (cf. §8.5). C'est là la dissymétrie politique : il est simple de partir, il est difficile d'être chassé·e. Cela correspond à la culture anarchiste : on respecte la décision personnelle de quitter une fonction, on encadre fortement la décision collective de la retirer.

## 8.5. Auto-retrait

Un·e admin réseau peut quitter ses fonctions à tout moment, sans l'accord des autres. C'est un acte **unilatéral et inconditionnel** (P3 appliqué au niveau réseau).

### Procédure

Depuis `/rede/administradores`, sur sa propre ligne, cliquer **« Quitter mes fonctions d'admin réseau »**. Modale de confirmation, raison optionnelle.

### Effet

- La ligne passe à `status='inactive'` (ou `removed` selon le contexte, à clarifier au paquet D).
- Mail à tou·tes les autres admins actif·ves.
- Audit log `event_type='self_removal_requested'`.

### Cas spécial : l'unique admin actif·ve

Si vous êtes le·la seul·e admin actif·ve et que vous voulez partir, le SIGB déclenche une **carence spéciale de 30 jours**. Pendant cette période :
- Vous restez admin actif·ve avec tous vos droits.
- Un mail urgent est envoyé à tou·tes les anciens admins (`status='inactive'` ou `removed`) leur indiquant la situation.
- Le réseau a 30 jours pour soit recoopter un·e nouveau·elle admin (workflow normal de cooptation, vous étant le seul votant), soit organiser une transition différente.

À J+30, si rien n'a été fait, vous sortez effectivement et le réseau se retrouve **sans admin actif·ve**. Le SIGB continue de fonctionner techniquement, mais aucune action d'admin (activation de biblio, cooptation, etc.) n'est plus possible jusqu'à intervention manuelle.

Cette procédure est conçue pour **ralentir** la dissolution du réseau au cas où un·e dernier·e admin partirait, sans pour autant **empêcher** ce départ. La liberté de partir reste entière.

## 8.6. Le droit transverse au quotidien

Le **droit transverse** est ce qui distingue politiquement l'admin réseau du staff local : iel peut agir comme `coord+` sur n'importe quelle biblio, lire son catalogue (même si visibilité `private`), modifier ses memberships, etc.

### Quand l'utiliser

- **Activation d'une nouvelle biblio** : workflow normal, c'est le cas d'usage premier du droit transverse.
- **Maintenance** : une biblio a une configuration cassée, un paramètre mal réglé, un bug bloquant. Vous pouvez intervenir pour corriger.
- **Blocage politique** : la biblio n'a plus de coord (cf. §7.5), il faut recoopter pour redémarrer.
- **Médiation à la demande** : la coordination locale vous sollicite explicitement pour aider à arbitrer un conflit ou prendre une décision difficile.
- **Investigation suite à un signalement réseau** : un·e lecteur·rice signale un problème majeur dans une biblio, et la coordination locale ne répond pas ou est elle-même partie du problème.

### Quand ne pas l'utiliser

- **Par curiosité** : ne pas aller « voir ce qui se passe » dans une biblio sans raison opérationnelle. C'est de la surveillance, pas de l'administration.
- **Pour imposer une décision politique** : si vous n'êtes pas d'accord avec la politique d'une biblio (mode de validation, règlement, etc.), vous pouvez en discuter, mais pas l'imposer.
- **Pour court-circuiter un débat collectif** : si le réseau discute d'une évolution et que vous n'êtes pas d'accord, vous ne pouvez pas utiliser votre droit transverse pour imposer votre vue par fait accompli.

### Information préalable obligatoire

C'est la doctrine du réseau (chapitre 2, §2.4 ; chapitre 7, §7.6) : **toute intervention d'admin réseau sur une biblio locale doit être précédée d'une information à la coordination locale**, sauf en cas d'urgence vitale.

Concrètement :
- **Mail à la coordination locale** expliquant ce qui sera fait et pourquoi.
- **Attente d'une réponse** sauf urgence : 24 à 72 heures selon la nature de l'action.
- **Si pas de réponse et action non urgente** : relancer une fois, et procéder en explicitant dans le log que la coordination locale a été informée mais n'a pas répondu.
- **Si urgence vitale** : agir, et envoyer l'information immédiatement après en expliquant pourquoi l'urgence a justifié l'action sans attente.

Chaque action est tracée dans `cross_library_actions_log` avec niveau de criticité, lisible par la coordination locale a posteriori.

## 8.7. Le cas du premier admin et de Xavier

Le système suppose au moins un·e admin réseau actif·ve pour que la cooptation soit possible. Le **premier admin** ne pouvant pas être coopté (il n'y a personne pour voter), une exception est prévue.

Au 11 mai 2026, **Xavier** est inscrit·e comme **admin réseau fondateur·rice** par INSERT direct dans `network_administrators`, avec `coopted_by_unanimity_of = ARRAY[]::uuid[]` (tableau vide) et `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. Cette manipulation est tracée dans l'audit log avec `event_type='foundational_admin_added'` et `metadata.foundational=true`.

Cette manipulation est **transparente politiquement** : elle est documentée, expliquée, et publique. Elle n'est pas une faiblesse du système — elle est l'amorçage indispensable. Une fois ce socle posé, toute cooptation ultérieure passe par le workflow normal de §8.3.

Au fur et à mesure que de nouveaux admins seront coopté·es, la « solitude » initiale s'effacera. Le réseau a vocation à avoir **plusieurs admins actif·ves** (l'objectif politique est généralement un cercle de 3 à 5 personnes, en nombre impair pour éviter les blocages en cas de vote sur certains sujets connexes hors-spec).

## 8.8. Si la règle vous gêne

**Vous trouvez l'unanimité trop exigeante** (« on n'arrive jamais à coopter, un veto bloque tout »). C'est un débat de fond sur la nature du collectif des admins réseau. Faut-il assouplir vers une majorité qualifiée ? Faut-il un mécanisme de surveote ? À porter en discussion réseau, et possiblement à formaliser dans une révision de la spec.

**Vous trouvez l'unanimité trop laxiste** (« il faudrait aussi consulter les coordinations locales avant de coopter un·e admin »). C'est une autre option politique : consulter les coordinations locales avant la cooptation d'un·e admin réseau. À discuter. Cela élargirait le cercle décideur mais alourdirait la procédure.

**Vous trouvez la carence de 7j pour le retrait collectif trop longue ou trop courte.** À porter sur la spec.

**Vous trouvez que la doctrine d'information préalable est insuffisamment cadrée** : qu'est-ce qu'une « urgence vitale » exactement ? Doit-il y avoir une définition canonique ? À discuter.

**Vous trouvez que la fonction d'admin réseau a trop de pouvoir** (droit transverse trop étendu) ou pas assez (devrait pouvoir trancher certains conflits). C'est une question politique fondamentale. À discuter en rencontre annuelle.

Voir chapitre 4 et annexe C.

\newpage

# 9. La transparence en pratique

Ce chapitre traite du fonctionnement concret de la **transparence** dans AnarBib : qui voit quoi, comment, et pourquoi. C'est l'application du principe P5 (transparence maximale) et de P6 (notifications systématiques).

## 9.1. Le principe

> **P5 — Transparence maximale.** L'audit log des changements de rôle est lisible par tout le staff actif de la biblio.
> **P6 — Notifications systématiques.** Tout changement de rôle déclenche un email à la personne concernée et à toute la coordination.

L'idée politique : **rendre les manipulations opaques impossibles**. Si tout est tracé et lisible, on ne peut pas en silence faire passer une personne d'un statut à un autre sans que ce soit vu par les autres membres du staff.

## 9.2. Qui voit quoi : matrice

### Au niveau d'une biblio

| Information | reader | librarian | coordenador | admin réseau |
|---|---|---|---|---|
| Liste de l'équipe (rôles actifs) | partielle (les noms publics seulement) | complète | complète | complète |
| Statuts (`suspended`, `pending_removal`) | non | oui | oui | oui |
| Audit log complet de l'équipe | non | oui | oui | oui |
| Audit log : raisons des actions | non | oui | oui | oui |
| Demande de retrait en cours : qui a demandé | non | oui | oui | oui |
| Données personnelles des autres lecteur·rices | non | oui (de cette biblio) | oui | oui |

### Au niveau du réseau

| Information | reader | staff biblio | admin réseau |
|---|---|---|---|
| Liste des admins réseau actif·ves | oui (page publique `/rede`) | oui | oui |
| Compteurs réseau (nombre de biblios, etc.) | oui | oui | oui |
| Audit log réseau (cooptations, retraits d'admins) | non | non | oui |
| Propositions de cooptation en cours | non | non | oui |
| Logs cross-biblios (actions d'admin réseau sur biblio X) | non | oui (de leur biblio) | oui |

## 9.3. L'audit log d'équipe en pratique

C'est l'outil de transparence le plus important. Il est consultable depuis `/biblioteca` → onglet **Equipe** → section **Historique de l'équipe**.

### Ce qu'on y voit

Chaque entrée affiche :
- Date et heure.
- Action (« promu·e librarian », « auto-rétrogradé·e », « retrait demandé », « suspendu·e », « réintégré·e après suspension », « passage automatique en inactif après 9 mois », etc.).
- Personne concernée (target).
- Auteur·rice de l'action (actor) — pour les actions humaines. Vide pour les actions automatiques (cron).
- Raison (si renseignée).
- Rôle et statuts avant/après.

### À quoi ça sert politiquement

- **Mémoire collective** : on peut reconstituer l'histoire de la coordination, voir comment elle s'est constituée et a évolué.
- **Garde-fou contre l'opacité** : si un·e coord a fait des actions douteuses (cooptations bizarres, suspensions injustifiées), c'est visible par tou·tes.
- **Outil de délibération** : en cas de débat (« on avait dit qu'on ferait tourner les coords ! »), le log donne des éléments factuels.
- **Outil de transition** : quand un·e nouveau·elle coord arrive, iel peut lire le log pour comprendre l'histoire récente sans avoir à interroger tout le monde.

### Ce qu'il faut faire avec

- **Le lire régulièrement**. Pas tous les jours, mais une fois par mois, lors d'une réunion de coordination par exemple.
- **Discuter ce qui est étrange**. Si une action vous semble incompréhensible ou injustifiée, demandez à son auteur·rice.
- **Ne pas l'utiliser comme arme**. Le log est un outil de transparence collective, pas un instrument de surveillance interpersonnelle.

## 9.4. Les emails de notification

Chaque action de gouvernance déclenche **un ou plusieurs emails** automatiques. Ce n'est pas du spam : c'est volontaire, parce que personne ne doit être affecté·e par un changement de rôle sans en être informé·e.

### Qui reçoit quoi

| Événement | Personne concernée | Coords locaux actif·ves | Admins réseau |
|---|---|---|---|
| Cooptation (T1, T2) | ✅ | ✅ | — |
| Auto-rétrogradation (T3, T4) | ✅ confirmation | ✅ | — |
| Demande de retrait (T5) | ✅ | ✅ | — |
| Annulation de demande (T8) | ✅ | ✅ | — |
| Fin de carence (J+7) | ✅ | ✅ | — |
| Suspension (T6) | ✅ urgent | ✅ | — |
| Levée de suspension (T7) | ✅ | ✅ | — |
| Sortie auto à 9 mois (T9) | ✅ rappels + final | ✅ (final seulement) | — |
| Dernier·e coord part | ✅ | ✅ (le·la concerné·e) | ✅ alerte |
| Cooptation admin réseau (proposition) | — | — | ✅ |
| Cooptation admin réseau (succès) | ✅ bienvenue | — | ✅ récap |
| Cooptation admin réseau (rejet) | ✅ avec rationale | — | ✅ |
| Retrait collectif admin réseau | ✅ | — | ✅ |
| Intervention cross-biblios | — | ✅ (coords de la biblio) | ✅ (l'auteur·rice) |

### Le ton des emails

Les emails de gouvernance suivent les conventions militantes du réseau (cf. mémoire interne) : sobriété, clarté, accessibilité (langue commune sans jargon), formulation inclusive et écriture désacralisée. Pas de formules officielles, pas de signatures bureaucratiques.

Exemple type pour une demande de retrait :
> Salut Karl,
>
> La coordination de la BLMF a demandé ton retrait de l'équipe (rôle : librarian), suite à : « décision AG du 04/05 ».
>
> Ce préavis prendra effet le **12 mai 2026** (dans 7 jours), sauf annulation par un·e autre coord d'ici là.
>
> Pendant cette période, tu n'as plus accès aux fonctions de librarian. Pour toute discussion, adresse-toi à la coordination de la BLMF — cette décision relève de la vie organique du collectif local et ne se gère pas via le SIGB.
>
> AnarBib

Le ton vise à informer factuellement sans dramatiser ni minorer.

## 9.5. Le cas des notifications « cross-biblios »

Quand un·e admin réseau intervient sur une biblio (cf. §8.6), deux notifications sont produites :

- **Notification préalable** (manuelle) : l'admin envoie un mail à la coordination locale avant d'agir. Format libre.
- **Notification automatique** (par le SIGB) : à l'exécution de l'action, le système écrit dans `cross_library_actions_log` avec niveau de criticité, et envoie un mail aux coords actif·ves de la biblio concernée.

Cette double notification (manuelle + automatique) garantit que la coordination locale est avertie **avant** politiquement et **après** techniquement. La trace technique est lisible a posteriori dans l'onglet **Equipe** → section **Interventions réseau** (à venir au paquet D).

## 9.6. Limites de la transparence

La transparence d'AnarBib a des limites, qu'il faut expliciter :

**Les `reader` ne voient pas l'audit log de l'équipe.** C'est volontaire (P5 parle de « staff actif »). Les `reader` ne voient pas qui a coopté qui, qui a été suspendu·e, etc. La transparence joue **dans la coordination**, pas vers les usager·es.

**Une biblio ne voit pas l'audit log d'une autre biblio.** Souveraineté locale (P7). Les changements de rôle dans la biblio A sont strictement opaques pour la biblio B, sauf via le canal humain (discussion entre coords des deux biblios).

**L'audit log réseau (cooptations et retraits d'admins) n'est pas public.** Lisible par les admins réseau seul·es. Une biblio locale peut voir la liste des admins réseau actuel·les (page `/rede`), mais pas l'historique des cooptations ni les rationales des votes opposés.

Ces limites ne sont pas des hypocrisies. Elles correspondent à un équilibre entre **transparence** (au sein du staff délibérant) et **confidentialité** (vis-à-vis des usager·es et entre périmètres). Si vous trouvez l'équilibre mal placé, c'est amendable (chapitre 4).

## 9.7. Si la règle vous gêne

**Vous pensez que les `reader` devraient voir l'audit log de l'équipe** (transparence radicale envers les usager·es). C'est une position défendable, mais elle a des conséquences (les conflits internes deviennent publics, la vie politique du collectif s'expose). À discuter en réseau.

**Vous pensez à l'inverse que l'audit log est trop visible** (un·e librarian discret·e ne devrait pas pouvoir « espionner » les actions des coords). C'est aussi défendable. Mais cela contredit P5. À discuter.

**Vous trouvez les emails trop nombreux ou pas assez explicites.** Le contenu est paramétré dans `mail-strings.ts` × 6 locales. Toute modification d'un mail est amendable comme une modification de code. À porter avec les dev.

**Vous pensez que l'audit log réseau devrait être public au moins aux coords locaux** (pour qu'iels puissent voir qui décide quoi au niveau réseau). C'est une option intéressante. À discuter.

Voir chapitre 4 et annexe C.

\newpage

# 10. Cas concrets commentés

Pour finir, six scénarios complets. Chacun illustre une combinaison de mécanismes et permet de voir le SIGB en action. Les noms (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) sont ceux des camarades historiques de la pensée libertaire ; ils servent ici de cas-types fictifs.

## 10.1. Voltairine est cooptée librarian

> **Contexte.** Emma est coordenadora à la BLMF. Voltairine vient depuis huit mois aux permanences, participe à la vie de la biblio, et a clairement le profil pour entrer dans l'équipe. Le collectif local en a discuté en AG le 4 mai et a acté sa cooptation.

**Procédure.**

1. Emma se connecte le 5 mai à 14h30. Va dans `/biblioteca`, onglet **Equipe**.
2. Cherche Voltairine dans la liste des `reader` de la biblio (elle a un compte AnarBib depuis février).
3. Clique **« Inviter dans l'équipe »** → choisit **librarian**.
4. Champ « Raison » : « décision AG du 04/05 » (doctrine 1, attente stricte).
5. Confirme.

**Effet immédiat.**

- Voltairine reçoit un mail : « Salut Voltairine, tu as été nommée librarian de la BLMF par Emma G. suite à : "décision AG du 04/05". Tes nouveaux droits sont actifs. Bienvenue dans l'équipe. »
- Les autres coords actives de la BLMF (Lucy et Piotr) reçoivent un mail informationnel.
- Audit log : `2026-05-05 14:30 — Emma G. a promu Voltairine d.C. librarian (raison: décision AG du 04/05)`.

**Commentaire.**

Cas le plus simple. Le SIGB exécute proprement la décision du collectif. Emma n'a rien décidé politiquement — elle a cliqué pour exécuter ce qui a été décidé hors logiciel.

**Ce que le SIGB n'a pas fait :** vérifier que l'AG a vraiment eu lieu, que la décision a vraiment été prise, que Voltairine est vraiment d'accord. Ces choses sont **hors logiciel**. Si Emma avait menti sur l'AG, le SIGB n'aurait rien vu. La culture politique de la BLMF est ce qui empêche ce mensonge (et le log le rend a posteriori traçable).

## 10.2. Lucy passe la main

> **Contexte.** Lucy est coordenadora à la BLMF, mais elle ne peut plus assurer la charge ce semestre (elle commence une thèse). Elle souhaite « repasser librarian » pour rester dans l'équipe mais alléger ses responsabilités.

**Procédure.**

1. Lucy va dans `/biblioteca`, onglet **Equipe**.
2. Sur sa propre ligne (statut `coordenador`), clique **« Je passe la main »**.
3. Choix : « repasser librarian ».
4. Modale de confirmation rappelle qu'elle perdra les permissions de coordination immédiatement.
5. Lucy confirme. Raison optionnelle : « démarrage thèse, allègement temporaire ».

**Effet immédiat.**

- Sa membership `coordenador` passe à `inactive`.
- Sa membership `librarian` (qui existait en parallèle) reste `active`.
- Lucy reçoit un mail de confirmation : « Tu es désormais librarian de la BLMF. Tu gardes tes permissions opérationnelles. »
- Toute la coordination (Emma, Piotr) reçoit un mail : « Lucy P. a passé la main, n'est plus coordenadora. Elle reste librarian de l'équipe. »
- Audit log : `2026-05-05 18:42 — Lucy P. a auto-rétrogradé coordenador → librarian (raison: démarrage thèse, allègement temporaire)`.

**Commentaire.**

C'est l'usage exemplaire du droit P3. Lucy n'a eu à demander d'autorisation à personne. Son auto-rétrogradation est immédiate. Elle continue de contribuer à la biblio, mais à une intensité ajustée à sa disponibilité actuelle.

**Politiquement** : c'est exactement le genre de rotation qu'on cherche à favoriser. On ne perd pas Lucy, elle prend juste un autre rôle. Dans six mois ou un an, si elle veut reprendre la coordination, le collectif pourra la recoopter (T2). Aucune décision n'est définitive.

## 10.3. Karl doit partir

> **Contexte.** Karl est librarian à la BLMF. Son comportement avec certain·es lecteur·rices a posé problème (paternalisme, remarques déplacées). Le collectif en a discuté en AG le 4 mai et a décidé qu'il devait quitter l'équipe.

**Procédure.**

1. Piotr (coord) — choisi par l'AG pour exécuter la décision — va dans `/biblioteca`, onglet **Equipe**.
2. Sur la ligne de Karl, clique **« Demander le retrait »**.
3. Modale rouge avec délai 7j explicite.
4. Raison obligatoire : « Suite à AG du 04/05, comportement inadéquat avec plusieurs lecteur·rices signalé sur plusieurs mois, décision collective d'exclusion. »
5. Confirmation explicite : « Je comprends que cette demande prendra effet le 12 mai 2026 sauf annulation par un·e autre coord. »

**Effet immédiat.**

- Membership de Karl passe à `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl perd l'accès** immédiatement à toutes les fonctions de librarian (la membership est gelée).
- Karl reçoit un mail :
  > « Salut Karl, la coordination de la BLMF a demandé ton retrait de l'équipe (rôle: librarian), suite à: "Suite à AG du 04/05, comportement inadéquat avec plusieurs lecteur·rices signalé sur plusieurs mois, décision collective d'exclusion." Ce préavis prendra effet le 12 mai 2026 (dans 7 jours), sauf annulation par un·e autre coord d'ici là. Pour toute discussion, adresse-toi à la coordination de la BLMF. »
- Emma et Lucy (autres coords) reçoivent le mail informationnel.
- Audit log : `2026-05-05 — Piotr K. a demandé le retrait de Karl M. (rôle: librarian, raison: ...)`.

**Évolution.**

- 6 mai à 9h : Lucy lit le mail. Elle est d'accord avec la décision et n'intervient pas.
- 7 mai : Emma a un échange avec Karl (qui lui écrit pour s'expliquer). Emma conclut que la décision tient. N'intervient pas.
- 8-11 mai : rien.
- **12 mai à 00h00** : le cron `cron_team_pending_removal_complete` s'exécute. Karl passe à `inactive`.
- Mail final à Karl + à la coordination.
- Audit log : `2026-05-12 — passage automatique en inactif (raison: pending_removal expiré, cron) — actor: NULL`.

**Commentaire.**

C'est le cas de l'exclusion collective. Trois éléments politiques à noter :

- **La carence a fonctionné comme garde-fou possible**, sans être utilisée. Lucy et Emma auraient pu annuler ; elles ne l'ont pas fait. Le fait que personne n'ait annulé est lui-même une **délibération implicite**.
- **Karl est resté informé** sans surprise. Pas d'exclusion silencieuse.
- **L'audit log est lisible** par l'ensemble du staff et permet de revenir sur cette décision si plus tard quelqu'un se demande pourquoi Karl est parti.

**Politiquement délicat** : la raison écrite dans le champ « Raison » est lisible par tout le staff. Elle ne devrait pas contenir de détails sur les victimes (RGPD, dignité), mais devrait être assez claire pour que la décision soit défendable politiquement. Trouver le bon dosage est une compétence de coord.

## 10.4. Compte compromis : suspension immédiate

> **Contexte.** Le 5 mai à 19h30, Emma remarque dans les logs d'activité que Friedrich (librarian) a effectué 47 modifications de fiches catalogue en 3 minutes, dont plusieurs aberrantes (livres marqués comme « disparus » alors qu'ils sont en rayon, etc.). Le pattern ressemble à un accès non autorisé.

**Procédure.**

1. Emma va dans `/biblioteca`, onglet **Equipe**.
2. Sur la ligne de Friedrich, clique **« Suspendre »**.
3. Modale avec raison **obligatoire** (≥ 20 caractères).
4. Emma tape : « Suspicion compte compromis, activité anormale (47 modifs catalogue en 3 min), vérification en cours. »
5. Confirme.

**Effet immédiat (19h32).**

- Friedrich passe à `status='suspended'`.
- **Aucun accès** pour Friedrich.
- Friedrich reçoit un mail urgent : « Ton compte AnarBib a été suspendu à titre conservatoire à la BLMF. Raison: suspicion de compromission de ton compte. Nous te suggérons fortement de **changer ton mot de passe immédiatement**. Une fois ton compte sécurisé, contacte la coordination de la BLMF pour que la suspension soit levée. »
- La coordination (Lucy, Piotr) reçoit un mail.
- Audit log : `2026-05-05 19:32 — Emma G. a suspendu Friedrich E. (rôle: librarian, raison: ...)`.

**Évolution.**

- **19h35** : Emma appelle Friedrich (canal hors-SIGB). Friedrich confirme qu'il n'a pas fait ces actions. Il avait laissé son ordi ouvert dans un espace partagé.
- **19h40** : Friedrich change son mot de passe via la procédure de réinitialisation.
- **20h00** : Emma vérifie les actions douteuses dans l'audit log de la biblio (l'audit catalogue, pas l'audit team). Identifie les 47 modifications. Les annule manuellement ou demande un rollback à un·e admin réseau si besoin.
- **20h15** : Emma retourne dans l'onglet Equipe, lève la suspension de Friedrich.
- Friedrich reçoit un mail de confirmation. Audit log : `2026-05-05 20:15 — Emma G. a levé la suspension de Friedrich E.`.

**Commentaire.**

Cas typique où la suspension est utilisée comme **mesure conservatoire**, pas comme exclusion. Friedrich n'est pas en faute — c'est son compte qui a été compromis. La suspension a duré 43 minutes, le temps de sécuriser.

**Important politiquement** : Friedrich n'a pas été « accusé ». Le mail le précise clairement (« à titre conservatoire »). Quand la situation est réglée, la suspension est levée, et l'épisode est tracé dans le log comme un incident, pas comme un blâme.

## 10.5. Errico est l'ultime coord et veut partir

> **Contexte.** La BLMF n'a plus qu'un seul coord actif·ve, Errico. Lucy a passé la main, Emma a déménagé et n'est plus active. Piotr s'est rétrogradé en début d'année. Errico doit partir (déménagement à l'étranger, plus de temps).

**Procédure.**

1. Errico va dans `/biblioteca`, onglet **Equipe**, clique **« Je passe la main »**.
2. Modale **spéciale** s'ouvre :
   > ⚠️ **ATTENTION** : tu es l'unique coordenador·a actif·ve de la BLMF. La biblio se retrouvera sans coordination. Les admins réseau d'AnarBib seront notifié·es. La BLMF pourra continuer à fonctionner (les librarians restent opérationnel·les) mais aucune modification de la configuration ne sera possible jusqu'à la cooptation d'un·e nouveau·elle coord. Continuer ?
3. Errico confirme. Raison : « Déménagement à l'étranger, plus de disponibilité pour la coordination. »

**Effet immédiat.**

- Membership coordenador d'Errico passe à `inactive`.
- Mail à Errico (confirmation).
- Mail à toute la coordination de la BLMF — mais il n'y en a plus, donc en pratique c'est les `librarian` actif·ves restant·es qui reçoivent une notification.
- **Mail urgent aux admins réseau** : « La BLMF n'a plus de coordenador·a actif·ve. Voici les librarians actif·ves restant·es : Voltairine d.C., Friedrich E., ... »
- Audit log : `2026-05-05 — Errico M. a auto-rétrogradé coordenador → reader (raison: ..., warning: last_coordinator_leaving)`.

**Évolution hors-logiciel.**

- 6 mai : Xavier (admin réseau) prend contact avec Voltairine et Friedrich, les `librarian` actif·ves restant·es. Iels confirment que le collectif BLMF existe encore, et qu'iels veulent continuer.
- 7-15 mai : discussion interne du collectif BLMF, qui décide en AG de coopter Voltairine au rôle de coordenadora.
- 16 mai : Xavier (ou un·e autre coord BLMF qui n'existe plus en l'occurrence, donc Xavier dans son droit transverse) coopte Voltairine en coordenadora. **Information préalable obligatoire** : Xavier a écrit à Friedrich et Voltairine 2 jours avant pour annoncer l'action. Une fois faite, l'action est tracée dans `cross_library_actions_log` avec niveau de criticité « élevé » (modification de coordination d'une biblio par admin réseau).

**Commentaire.**

Cas politiquement délicat : la biblio passe par une période de fragilité (entre le 5 et le 16 mai, elle n'a pas de coordination). Mais le SIGB **n'a pas empêché** le départ d'Errico — son droit P3 est inconditionnel. Le SIGB a juste **alerté le réseau** pour que celui-ci puisse aider.

L'intervention de Xavier illustre l'usage **propre** du droit transverse : il a été sollicité (implicitement, par l'alerte automatique), il a respecté l'information préalable, il a tracé son action. Il n'a pas imposé Voltairine ; c'est le collectif BLMF qui l'a choisie. Xavier a juste **exécuté techniquement** la décision.

## 10.6. Une cooptation d'admin réseau qui tombe à l'eau

> **Contexte.** Xavier est admin réseau fondateur. Au fil du temps, Maria, Patricia et Diego ont été coopté·es admins réseau au fur et à mesure que le réseau s'est élargi. Au 20 mai 2026, le collectif des admins est : Xavier, Maria, Patricia, Diego (quatre admins actif·ves).
>
> Maria propose la cooptation de Mohammed, qu'elle connaît dans une biblio italienne qui rejoint le réseau.

**Procédure.**

1. Maria, depuis `/rede/administradores`, clique **« Proposer une cooptation »**.
2. Saisit l'identité de Mohammed (compte AnarBib créé deux semaines plus tôt).
3. Motivation : « Mohammed coordonne la BLA (Bologna), une biblio qui rejoint le réseau ce mois-ci. Il a porté l'intégration politique de la BLA dans AnarBib et est très impliqué dans la coordination italienne. Sa cooptation comme admin réseau renforcera la diversité géographique du collectif et facilitera l'animation côté Italie. »
4. Confirme.

**Effet immédiat.**

- Proposition créée, `status='open'`, `expires_at = 19 juin 2026`.
- Vote automatique `favorable` de Maria enregistré.
- Mails à Xavier, Patricia, Diego avec la proposition.

**Évolution.**

- 22 mai : **Diego** vote `favorable`. Pas de rationale (optionnel pour favorable).
- 25 mai : **Patricia** vote `opposed`. Rationale : « Mohammed n'a aucune ancienneté dans le réseau. Sa cooptation va plus vite que celle de la BLA, qui n'a pas encore eu l'occasion de fonctionner comme biblio AnarBib pendant assez de temps. Je propose d'attendre 6 mois pour que la BLA ait pris ses marques, puis de reproposer Mohammed à ce moment-là. » Patricia coche « Révéler mon identité ».

**Effet immédiat du vote opposed.**

- Proposition passe à `status='rejected'`.
- Mail à Mohammed : « Bonjour Mohammed, ta proposition de cooptation comme admin réseau d'AnarBib n'a pas abouti. Patricia X. a soulevé l'objection suivante: "[rationale complète]". Tu peux échanger avec elle ou avec Maria, qui t'avait proposé·e. La cooptation pourra être reproposée ultérieurement. »
- Mail à Maria (proposeuse) : récap avec la rationale de Patricia.
- Mail à Xavier et Diego : info que la proposition est rejetée, avec la rationale.
- Audit log réseau : `2026-05-25 — cooptation rejetée: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Commentaire.**

Cas illustratif de l'unanimité **en action**. Patricia a un veto, elle l'utilise, sa rationale est explicite et constructive (« attendons 6 mois »). Elle a choisi de révéler son identité, ce qui permet à Mohammed et Maria de discuter avec elle directement plutôt que de spéculer sur l'opposant·e anonyme.

**Politiquement** : la cooptation à l'unanimité n'est pas une garantie de blocage permanent. Patricia ne dit pas « jamais » mais « pas maintenant ». Si dans 6 mois la BLA est bien intégrée et que Patricia change d'avis, une nouvelle proposition pourra aboutir. C'est cette **réversibilité dans le temps** qui rend l'unanimité supportable.

L'alternative — coopter Mohammed à la majorité contre l'avis de Patricia — aurait créé un cercle d'admins où Patricia se serait sentie en porte-à-faux. Mieux vaut attendre.

\newpage

# Annexes

\newpage

# Annexe A — Glossaire

**AG** — Assemblée générale. Réunion collective de prise de décision d'une biblio. Le SIGB ne modélise pas l'AG (P8). Sa modalité (quorum, fréquence, mode de délibération) est entièrement décidée par chaque biblio.

**Audit log** — Journal des actions de gouvernance, stocké dans `library_membership_audit` (au niveau d'une biblio) et `network_administrator_audit` (au niveau réseau). Lisible par le staff actif (au niveau biblio) et par les admins réseau (au niveau réseau).

**Auto-rétrogradation** — Action par laquelle une personne staff se rétrograde elle-même à un rôle inférieur. Droit P3, inconditionnel.

**Biblio `private`** — Biblio dont le catalogue n'est visible que par ses membres inscrits. Mode adapté aux biblios exposées politiquement.

**Biblio `network`** — Biblio dont le catalogue est visible par tou·tes les `reader` validé·es du réseau AnarBib. Mode par défaut pour la majorité des biblios.

**Biblio `public`** — Biblio dont le catalogue est visible par tout le monde, y compris les visiteur·es anonymes.

**Carence** — Délai imposé entre une décision et son effet. Sept jours pour les retraits collectifs de staff local et de admin réseau. Trente jours pour l'auto-retrait de l'unique admin réseau actif·ve.

**Cooptation** — Mécanisme d'entrée dans une équipe (staff local) ou dans le collectif d'admins réseau. Pour le staff local : décision d'un·e coord+. Pour le réseau : unanimité des admins actif·ves.

**Cross-biblios** — Qualifie une action effectuée par un·e admin réseau sur une biblio dont iel n'est pas membre staff local. Tracée dans `cross_library_actions_log`.

**Cron** — Tâche automatique exécutée périodiquement par le SIGB. Sans actor humain·e. Exemples : `cron_team_pending_removal_complete` (passage de `pending_removal` à `inactive` à J+7), `cron_team_inactive_cleanup` (sortie auto à 9 mois).

**Délégation** — Acte par lequel un collectif confie temporairement une fonction à un·e de ses membres, en gardant la possibilité de la reprendre. Concept central, distingué de « hiérarchie ».

**Membership** — Ligne de la table `user_library_memberships` qui exprime le rattachement d'une personne à une biblio dans un rôle donné. Une personne peut avoir plusieurs memberships dans une biblio (multi-membership).

**Multi-membership** — Possibilité d'avoir plusieurs lignes de membership pour une même personne dans une même biblio, avec des rôles différents.

**Réseau** — Le collectif des biblios qui se reconnaissent mutuellement et partagent la plateforme AnarBib. Pas une organisation centrale, une fédération.

**RPC** — *Remote Procedure Call*. Fonction SQL appelée par l'interface utilisateur·rice pour exécuter une action. Toutes les actions de gouvernance passent par des RPC nommées `fn_team_*` (staff local) ou `fn_network_admin_*` (réseau).

**Souveraineté locale** — Principe P7 selon lequel chaque biblio est souveraine sur ses délégations internes. Les changements de rôle dans une biblio n'affectent rien dans une autre.

**Spec** — Document de spécification (`spec-*.md`) qui décrit en détail le fonctionnement d'une fonctionnalité du SIGB. Source de vérité technique et politique. Versionnée, datée, amendable.

**Unanimité** — Modalité de cooptation et de retrait collectif des admins réseau. Tous les votes doivent être `favorable` ; un seul `opposed` ou une abstention non levée bloque.

**Validation physique** — Procédure par laquelle un·e librarian+ valide un compte `reader` après une rencontre physique. Vaut pour tout le réseau (pacte de reconnaissance mutuelle).

**Veto** — Vote `opposed` lors d'une cooptation ou d'un retrait collectif d'admin réseau. Effet immédiat : rejet de la proposition. Rationale obligatoire de 20 caractères minimum.

\newpage

# Annexe B — Index des fonctions techniques

Cette annexe donne, pour chaque RPC mentionnée dans le guide, sa traduction politique et la transition concernée. Elle sert de référence rapide.

## Fonctions de staff local

| RPC SQL | Transition | Traduction politique |
|---|---|---|
| `fn_team_promote_to_librarian` | T1 | Cooptation `reader` → `librarian` |
| `fn_team_promote_to_coordenador` | T2 | Cooptation `librarian` → `coordenador` |
| `fn_team_self_demote` | T3, T4 | Auto-rétrogradation (« je passe la main ») |
| `fn_team_request_remove_member` | T5 | Demande de retrait avec carence 7j |
| `fn_team_cancel_remove_member` | T8 | Annulation d'une demande de retrait |
| `fn_team_suspend_member` | T6 | Suspension immédiate (mesure conservatoire) |
| `fn_team_unsuspend_member` | T7 | Levée de suspension |
| `fn_validate_physical_account` | — | Validation physique d'un·e `reader` |
| `cron_team_pending_removal_complete` | T5 (suite) | Cron : passage à `inactive` à J+7 |
| `cron_team_inactive_cleanup` | T9 | Cron : sortie auto à 9 mois |

## Fonctions d'admin réseau

| RPC SQL | Étape | Traduction politique |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Cooptation : proposition | Un·e admin propose un·e nouveau·elle |
| `fn_network_admin_vote_cooptation` | Cooptation : vote | Vote favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Auto-retrait | Quitter ses fonctions d'admin réseau |
| `fn_network_admin_request_removal` | Retrait collectif | Workflow miroir de la cooptation |

## Helpers d'autorisation (utilisés par les RLS)

| Helper SQL | Sens politique |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | Cette personne peut-elle agir comme staff sur cette biblio ? (staff local actif OU admin réseau) |
| `user_can_engage_library(library_id)` | Cette personne peut-elle engager politiquement cette biblio ? (coord local actif OU admin réseau) |
| `fn_caller_is_network_admin()` | L'appelant·e est-iel un·e admin réseau actif·ve ? |
| `fn_library_visible_to_caller(library_id)` | Le catalogue de cette biblio est-il visible pour l'appelant·e ? |

## Tables principales

| Table | Sens politique |
|---|---|
| `user_library_memberships` | Les délégations locales (qui est staff de quelle biblio) |
| `network_administrators` | Les administrateur·rices du réseau |
| `library_membership_audit` | Journal des actions de gouvernance locale |
| `network_administrator_audit` | Journal des actions de gouvernance réseau |
| `network_administrator_cooptation_proposals` | Propositions de cooptation en cours |
| `network_administrator_cooptation_votes` | Votes individuels des admins |
| `cross_library_actions_log` | Trace des actions d'admin réseau sur biblios |

\newpage

# Annexe C — Modèle de note d'amendement

Quand vous voulez proposer un amendement à une règle du SIGB ou à ce guide, voici un modèle de note pour structurer votre proposition. Format libre, vous pouvez l'adapter.

---

## Proposition d'amendement à [nom de la spec ou du guide]

**Auteur·rice·s :** [vos prénoms / pseudos]
**Date :** [JJ/MM/AAAA]
**Périmètre :** [local biblio / réseau / fondements]

### 1. Règle concernée

Citer textuellement la règle ou le paragraphe à amender, avec sa référence dans la spec source.

> *Exemple :* « `spec-gouvernance-roles.md`, §5.6, T5 : Le délai de carence avant exclusion effective est de 7 jours. »

### 2. Problème identifié

Décrire en quelques phrases ce qui pose problème dans la règle actuelle. Si possible avec un cas concret rencontré.

> *Exemple :* « Dans la pratique, 7 jours est trop court quand l'AG suivante de la biblio se tient dans 15 jours. Une décision de retrait prise à chaud n'a parfois pas le temps d'être discutée collectivement avant l'effet automatique. »

### 3. Amendement proposé

Décrire la modification souhaitée, dans la mesure du possible avec une formulation prête à intégrer à la spec.

> *Exemple :* « Passer le délai de carence de 7 à 14 jours, OU rendre le délai configurable par biblio (entre 7 et 30 jours), avec une valeur par défaut à 14 jours. »

### 4. Conséquences techniques anticipées

Si vous avez une idée de ce que ça implique côté code, le dire. Sinon, le dire aussi (« je ne sais pas, à voir avec les dev »).

> *Exemple :* « Modifier la valeur dure dans le code SQL de `fn_team_request_remove_member` et `cron_team_pending_removal_complete`. Si configurable par biblio, ajouter une colonne à `libraries`. »

### 5. Conséquences politiques anticipées

Décrire ce qui change dans la pratique collective, et les éventuels effets de bord.

> *Exemple :* « Plus de temps pour la délibération, mais aussi plus de temps pendant lequel la personne en `pending_removal` reste suspendue (sans accès). Peut être perçu comme plus lourd. »

### 6. Alternatives envisagées

Mentionner les autres pistes auxquelles vous avez pensé, et pourquoi vous les écartez (ou pas).

> *Exemple :* « Alternative : laisser le délai à 7 jours mais permettre une "prolongation explicite" par un·e autre coord. Plus complexe à implémenter et à comprendre. Préférable de modifier le défaut. »

### 7. Discussion souhaitée

Où et comment souhaitez-vous que la proposition soit discutée ?

> *Exemple :* « Discussion sur le canal Matrix `#anarbib`, puis si consensus, intégration à la spec lors du prochain paquet de gouvernance. »

---

Une fois rédigée, faire circuler la note selon le périmètre (cf. chapitre 4, §4.2).

\newpage

# Annexe D — Specs sources et références

Ce guide s'appuie sur les documents suivants, consultables dans le dépôt du projet :

## Specs principales

**`spec-gouvernance-roles.md`** — Spec fondatrice de la gouvernance des rôles staff local. Version 1.0 du 5 mai 2026. 1231 lignes. Détaille les 4 rôles, les 5 statuts, les 9 transitions, l'audit log, les notifications, l'UI, et 15 cas d'usage de référence.

**`spec-administrateur-reseau.md`** — Séparation entre staff local et admin réseau. Version 0.3 du 11 mai 2026. 975 lignes. Détaille la table `network_administrators`, la cooptation à l'unanimité, le retrait collectif, le droit transverse, la sémantique des compteurs « page = périmètre ».

**`spec-validation-physique.md`** — Modes d'accueil des comptes lecteur·rices (`open` vs `manual_validation`). Cadrée le 3 mai 2026. Détaille les états du compte, le schéma DB, les workflows.

**`spec-refactor-v3-semantique.md`** — Refactor de la sémantique du workflow de réservation. Non central pour la gouvernance mais cité en marge pour la cohérence d'ensemble du SIGB.

## Specs cousines mentionnées (à rédiger ou en cours)

- `spec-migration-compte.md` — Migration d'un compte d'une biblio à une autre. 940 lignes, cadrée le 3 mai 2026.
- `spec-invitation-equipe.md` — Workflow d'invitation par email pour les personnes sans compte AnarBib. À rédiger.
- `spec-fermeture-biblio.md` — Procédure de fermeture propre d'une biblio. À rédiger.
- `spec-mediation-conflits.md` — Cadre formalisé de médiation et investigation suite à signalement. À rédiger (suggéré par le présent guide).

## Pour en savoir plus

Les specs et le code source sont sur le dépôt Codeberg du projet, miroir GitHub. La discussion technique et politique se déroule sur le canal Matrix `#anarbib` du réseau.

Pour toute proposition d'amendement à ce guide ou aux specs, voir chapitre 4 et annexe C.

---

*Fin du guide. Version 1.0, 11 mai 2026.*

*Ce guide est lui-même amendable. Si vous trouvez qu'il dit faux, qu'il a oublié un cas, ou qu'il prend une position qui ne correspond plus à la doctrine du réseau, dites-le.*
