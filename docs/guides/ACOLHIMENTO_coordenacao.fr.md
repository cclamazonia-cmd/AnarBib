# Bienvenue dans le réseau AnarBib

**Guide d'accueil des coordinations — les trente premiers jours**

*Version 1.0 — 16 septembre 2026 · Licence AGPLv3 · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Avant tout : ce qui est accepté, et ce qui ne l'est pas encore

La candidature de ta bibliothèque a été acceptée par la coordination du réseau. Cela veut
dire deux choses, et deux seulement :

1. Le réseau reconnaît ta bibliothèque comme faisant partie de la famille anarchiste et
   libertaire qu'il accueille, et il t'a ouvert le chemin de la constitution.
2. Ton compte n'est plus un compte de demandeur·se : c'est un compte de **coordination en
   constitution**.

Ce qui n'a **pas** encore eu lieu : ta bibliothèque n'est pas active. Elle n'apparaît pas
dans le catalogue commun, elle ne reçoit pas de lecteur·rices, elle n'échange rien avec
les autres bibliothèques. Elle est **pré-active**, et c'est toi qui vas l'en sortir — pas
seul·e, et pas en une journée.

> **La promesse de ce guide.** Tu n'as pas besoin d'être bibliothécaire. Tu n'as pas
> besoin d'être informaticien·ne. Tu as besoin de savoir ce que ton collectif veut, et
> d'avoir quelqu'un à qui demander quand tu ne sais pas. Le reste, c'est cliquer.
>
> **Et la règle d'or : clique, ça ne cassera rien.** Le logiciel n'affiche pas les
> transitions impossibles, désactive avec une explication les boutons qu'une règle
> bloquerait, et refuse en base les combinaisons impossibles. Les rares gestes qui ne
> reviennent vraiment pas en arrière sont listés au chapitre 9.

**La personne à qui parler.** À n'importe quel moment de ce parcours, avant de décider et
non après : `anarbib@proton.me`. Le réseau tient pour principe qu'une décision de
constitution se discute avec un·e camarade avant de devenir un formulaire. Écrire n'est
pas un aveu de faiblesse — c'est le fonctionnement normal.

---

## 1. Jour 1 — Entrer, et comprendre où tu es

### 1.1 Se connecter

La page de connexion est `/login` (bouton **Se connecter**). L'adresse `/cadastro` ne fait que rediriger
vers elle : si un vieux document t'y envoie, ce n'est pas ton erreur.

Si tu utilises encore le mot de passe provisoire reçu par courriel, **change-le avant
toute autre chose**. Tant qu'il n'est pas changé, plusieurs actions restent bloquées —
c'est une preuve passive que le compte a réellement été pris en main par une personne.

### 1.2 Les deux maisons

C'est la chose la plus importante de tout le guide, et elle vaut d'être apprise par cœur.

| Si la question est… | Tu vas dans… |
|---|---|
| « qu'est-ce qu'on a décidé ? » | **`/biblioteca`** — la maison collective |
| « qu'est-ce que je fais avec cette personne devant moi ? » | **`/painel`** — le comptoir |

Dans `/biblioteca` vivent l'identité publique, le règlement, l'équipe, le profil
d'adoption, les transitions et la confidentialité : tout ce que le collectif a délibéré.
Dans `/painel` vit le travail de tous les jours : emprunts, retours, consultations,
réservations, comptes en attente de validation.

Ce n'est pas un rangement arbitraire. Beaucoup de logiciels de bibliothèque mélangent les
deux, et le résultat est que la configuration politique finit cachée dans un back-office
d'administrateur. Ici, la délibération est d'un côté et l'opération de l'autre.

### 1.3 Les routes que tu vas utiliser

| Route | Ce que c'est | Pour qui |
|---|---|---|
| `/criar-conta` | inscription — **la seule porte d'entrée, pour tout le monde** | n'importe qui |
| `/conta` | l'espace personnel de chaque lecteur·rice — neuf onglets | chacun·e, le sien |
| `/atelier` | les ateliers : constitution et autorités | coordination en constitution |
| `/painel` | le comptoir, le travail du jour | équipe (librarian, coordination) |
| `/biblioteca` | la maison collective, les décisions | équipe, avec des pouvoirs par rôle |
| `/catalogacao` | cataloguer et importer | équipe |
| `/rede` | administration du réseau | admins réseau uniquement |

La page **Federação** et les pages publiques — catalogue, Œuvre, Périodique, Sujet,
Bibliothèques, Cartographie, Thésaurus FICEDL — complètent l'ensemble. Les routes ne sont
pas traduites : elles sont les mêmes dans les dix langues.

> **Tu n'entres jamais dans le compte de quelqu'un d'autre.** Tout ce que l'équipe doit
> faire pour un·e lecteur·rice se trouve dans le painel. Si tu t'es surpris·e à vouloir
> « entrer en tant que » quelqu'un, ce que tu cherches est dans le painel, onglet
> **Lecteur·rice** (`leitor`).

---

## 2. Jours 1 à 3 — L'atelier de constitution

La constitution est un parcours dans `/atelier`. Tu peux enregistrer à n'importe quel
moment et revenir plus tard : rien ne se perd entre deux sessions. **Tu as 60 jours**, et
un rappel par courriel arrive au 45ᵉ.

### 2.1 Étape 0 — le profil d'adoption, l'acte fondateur

Avant tous les autres volets, le logiciel demande où ta bibliothèque se place sur
**quatre axes indépendants**. Aucun n'est un niveau de qualité : ce sont des façons
d'exister, et une petite bibliothèque qui choisit le mode simple partout n'est pas une
bibliothèque inachevée.

**Axe 1 — `catalog_mode`, le catalogue**

- `local_only` — le fonds reste à la maison, non exposé au réseau. Utile pendant une
  période de rodage, ou quand une partie du fonds n'est pas prête à être publiée.
- `network_published` — le fonds entre dans le catalogue commun AnarBib.

**Axe 2 — `circulation_mode`, la circulation**

- `off` — aucune circulation gérée dans le logiciel : catalogue seul. C'est le cas d'un
  fonds patrimonial de consultation.
- `informal` — circulation simple, sans cotisation ni règles strictes. Le cas typique
  d'une petite bibliothèque militante où tout le monde se connaît.
- `full_sigb` — circulation complète : règles, réservations, cotisations, suspensions.

**Axe 3 — `network_mode`, la fédération**

- `isolated` — la bibliothèque existe dans AnarBib mais n'échange rien.
- `observer` — elle reçoit les flux du réseau, elle ne contribue pas encore.
- `federated` — elle participe pleinement.

**Axe 4 — `governance_mode`, la gouvernance**

- `informal` — aucun rôle d'équipe distinct : tout le monde est lecteur·rice. Pas de
  cooptation, pas de carence, pas de journal d'audit.
- `staff_roles` — les rôles `librarian` et `coordenador·a` existent, cooptation
  simplifiée.
- `full_governance` — l'ensemble : cooptation, carence, journal d'audit, crons.

### 2.2 Ce que chaque choix allume dans le painel

Ce tableau est la raison pour laquelle l'étape 0 vient avant tout le reste. Les onglets
du comptoir apparaissent ou non selon l'axe de circulation :

| Onglet du painel | Apparaît si |
|---|---|
| **Travail du jour** (`trabalho-do-dia`) | toujours |
| **Actions** (`acoes`) | toujours |
| **Lecteur·rice** (`leitor`) | toujours |
| **Historique** (`historico`) | toujours |
| **Consultations locales** (`consultas-locais`) | circulation `informal` ou `full_sigb` |
| **Emprunts** (`emprestimos-livro`) | circulation `informal` ou `full_sigb` |
| **Réservations** (`reservas`) | circulation `full_sigb` |
| **Emprunts en lot** (`emprestimos-lote`) | circulation `full_sigb` |
| **Contributions** (`contribuicoes`) | cotisation activée **et** circulation différente de `off` |

Si un onglet n'apparaît pas chez toi, ce n'est pas une panne : c'est le profil que ton
collectif a choisi. Et si le profil change en cours de session, le painel revient de
lui-même sur le **Travail du jour**.

> **Les choix ne sont pas des prisons.** Chaque axe a sa doctrine de transition —
> certaines rapides, certaines lentes, certaines irréversibles. L'onglet **Transitions**
> est dans `/biblioteca`, et non dans le painel : changer de profil est une décision
> collective, pas un geste de comptoir. Certaines transitions qui traversent plusieurs
> axes passent par la validation des admins réseau.

### 2.3 Les dix volets

Après l'étape 0, l'atelier n'affiche que les volets que ton profil rend pertinents. Une
bibliothèque en `circulation_mode = off` ne verra pas le volet circulation : il ne manque
rien, c'est que cette question ne se pose pas chez vous.

| Volet | Ce qui se décide | Condition |
|---|---|---|
| 1 | Identité — nom, nom court, adresse, contact | toujours |
| 2 | Horaires et permanences | toujours |
| 3 | Personnes responsables | selon la gouvernance |
| 4 | Politique de catalogage | toujours |
| 5 | Politique de circulation | si la circulation n'est pas `off` |
| 6 | Politique d'adhésion des lecteur·rices | selon gouvernance et circulation |
| 7 | Politique des courriels | toujours |
| 8 | Visibilité et participation au réseau | si le réseau n'est pas `isolated` |
| 9 | Données et confidentialité | toujours |
| 10 | Génération du règlement | toujours |

**Aucun de ces volets n'est une question d'informatique.** Ce sont dix questions
d'assemblée, présentées dans l'ordre où elles se répondent bien. Remplis-les avec ce que
le collectif a déjà décidé ; là où il n'a pas décidé, arrête-toi et porte la question à
la prochaine réunion. L'atelier attend.

### 2.4 Le volet 10 — le squelette de règlement

À la fin, le logiciel produit un PDF pré-rempli avec tous tes choix. **Ce PDF n'est pas un
certificat.** C'est un squelette à discuter : une matière première de délibération. Les
sections qui méritent débat sont marquées comme telles.

Le parcours attendu est : télécharger, porter en assemblée, amender librement, et
re-téléverser le document amendé comme règlement officiel de la bibliothèque. Tant qu'il
n'est pas re-téléversé, la bibliothèque reste pré-active.

> **Un point d'honnêteté.** « Conclure la constitution » ne vaut pas, aujourd'hui,
> activation automatique de la bibliothèque. C'est une lacune connue du logiciel, pas une
> erreur de ta part. Quand tu arrives au bout des volets, écris à `anarbib@proton.me`
> pour que l'activation soit faite — et insiste si personne ne répond en quelques jours.

---

## 3. Jours 3 à 7 — La page Biblioteca, la maison collective

Une fois la constitution terminée, `/biblioteca` devient l'endroit où ce qui a été décidé
reste inscrit et se tient. C'est là qu'on regarde quand quelqu'un demande « mais on avait
convenu quoi ? ».

- **Identité publique** — ce que le réseau et le public voient de ta bibliothèque.
- **Règlement** — le document que vous avez adopté, et ses versions.
- **Équipe** — qui est quoi, et par quel circuit (chapitre 4).
- **Profil** — les quatre axes, tels qu'ils sont aujourd'hui.
- **Transitions** — les propositions de changement de profil et leur vote.
- **Confidentialité** — rétention des données, purge automatique, RGPD/LGPD.

**Les décisions à arbitrer cette semaine**, toutes dans `/biblioteca` :

1. **La visibilité du fonds** — catalogue public ou non, apparition dans la galerie de
   bibliothèques d'`anarbib.org`, présence sur la cartographie du réseau. Sur la
   cartographie, un collectif qui choisit de ne pas apparaître a ses raisons : le
   logiciel les respecte, et toi aussi.
2. **La politique des courriels** — quels événements déclenchent un message à la personne
   lectrice (cycle d'emprunt, rappels avant échéance, relances de retard) et si l'équipe
   en reçoit copie. Tout cela s'allume et s'éteint par bibliothèque.
3. **La rétention des données** — combien de temps l'historique d'emprunt d'une personne
   reste conservé après le retour. C'est une question politique autant que légale : dans
   une bibliothèque militante, un historique est une liste de lectures de personnes
   identifiées. En garder peu est une forme de protection.
4. **La cotisation**, si elle existe chez vous — et avec elle l'onglet **Contributions**
   du painel.
5. **La carte de lecteur·rice** — si vous l'activez. Elle ne porte aucun nom : seulement
   le nom court de la bibliothèque et un QR opaque, et c'est la personne lectrice
   elle-même qui la génère et la régénère. C'est dessiné ainsi exprès, pour qu'une carte
   perdue ne raconte rien sur qui la portait.

> **À propos de l'onglet Confidentialité.** Il peut afficher deux messages qui se
> contredisent au sujet de la purge automatique. C'est un défaut d'affichage connu. Avant
> de conclure que la purge est active ou inactive, demande au réseau.

---

## 4. Jours 5 à 10 — Constituer l'équipe

### 4.1 Trois rôles, et trois seulement

`lecteur·rice` · `librarian` (bibliothécaire) · `coordenador·a` (coordination).

Le rôle local « administrateur » a été retiré en mai 2026. Si tu le trouves cité quelque
part, le document est périmé. « Administrateur·rice du réseau AnarBib » existe, mais c'est
un **statut transversal** — ce n'est pas l'échelon suivant de l'escalier, et on n'y arrive
pas en coordonnant assez longtemps. C'est un autre mécanisme politique, avec sa propre
cooptation.

### 4.2 Le piège qui coûte cher

**Personne ne s'inscrit deux fois.** Tout le monde entre une seule fois par
`/criar-conta`, comme lecteur·rice — y compris celles et ceux qui seront de l'équipe.

Devenir équipe n'est pas une nouvelle inscription : c'est une cooptation, et elle a lieu
sur le compte qui existe déjà. Qui se réinscrit en croyant « entrer comme équipe » ne crée
qu'un second compte et un problème que la coordination devra défaire.

**Donc la seule chose à demander à qui va entrer dans l'équipe, c'est : « envoie-moi ton
ID public ».**

### 4.3 Le circuit en trois temps

Aucune promotion n'est unilatérale. Trois personnes distinctes, trois gestes :

1. **Proposer** — la coordination propose quelqu'un par son ID public, pour le rôle
   `librarian` ou `coordenador·a`.
2. **Endosser** — une autre personne de l'équipe ratifie. La personne visée est exclue du
   quorum : dès que l'équipe compte deux autres personnes actives, deux ratifications
   sont requises.
3. **Accepter** — la personne proposée accepte. Sans ce consentement, rien ne se passe.

La proposition **expire à 30 jours**. Une ligne de lecteur·rice se ferme, celle de
bibliothécaire s'ouvre : un seul rôle actif par bibliothèque, et l'historique reste.

> **Le saut collégial.** Par défaut, pour entrer dans le cercle de la coordination il faut
> être passé·e par bibliothécaire. Pour un collectif horizontal, cette marche
> intermédiaire ne correspond à rien : une seule décision d'assemblée demandait deux
> circuits dans le logiciel. D'où le saut — proposer quelqu'un directement de lecteur·rice
> à la coordination — qui existe comme **option de bibliothèque**, désactivée par défaut,
> que ton collectif active s'il le veut. Il raccourcit l'escalier, jamais les
> consentements.

### 4.4 Sortir de l'équipe

- **Carence de 7 jours** — une sortie d'équipe n'est pas immédiate ; la personne passe par
  un état intermédiaire, et cela laisse le temps de se parler.
- **Inactivité** — un compte d'équipe qui ne se connecte plus depuis longtemps sort
  automatiquement, avec un avis à la personne 30 jours avant et 7 jours avant. L'avis à
  7 jours part aussi à la coordination, et il est escaladé aux admins réseau si la
  personne inactive est la dernière coordination de la maison.
- **Passer la main** — transmettre la coordination à quelqu'un d'autre se fait par le même
  circuit en trois temps, avant de partir. Ne le laisse pas au dernier jour.

---

## 5. Jours 7 à 20 — Le fonds

### 5.1 Les trois mots dont tu as besoin

- **Œuvre** (*obra*) — la fiche partagée : le livre en tant qu'œuvre, la même pour tout le
  réseau.
- **Holding** — le fait que ta bibliothèque possède cette œuvre.
- **Exemplaire** — l'objet physique sur l'étagère, avec son étiquette, son état, son
  histoire.

Trois collectifs peuvent avoir le même livre : une œuvre, trois holdings, plusieurs
exemplaires. C'est pour cela que corriger une fiche profite à tout le réseau, et pour cela
qu'une fiche se corrige avec soin.

### 5.2 Trois niveaux de fiche, et aucun n'est le mauvais

| Niveau | Esprit |
|---|---|
| **Simples** | bibliothèque militante, sans prétention académique : type, titre, autorité, année, éditeur, langue, cote, circulation par défaut, couverture, ISBN |
| **Avançado** | travail de bibliothécaire sans MARC : sous-titre, édition, collection, lieu, pages, contributions typées, sujets, notes |
| **Completo** | exhaustif : zones ISBD, MARC, identifiants d'autorité, provenance complète |

**Changer de niveau ne perd rien.** Un champ masqué par un niveau plus bas garde sa
valeur. Fais le test une fois, de tes propres yeux : c'est ce qui convainc.

**Commence en Simples.** Cinq fiches par semaine en Simples valent mieux qu'une fiche
parfaite par mois. Le fonds n'existe que catalogué.

### 5.3 La seule exigence que le réseau demande vraiment

**Aucun exemplaire nouveau sans mode d'acquisition.** D'où il vient, quand, donné par qui,
après quel événement.

Ce n'est pas un détail érudit. Dans une bibliothèque militante, la provenance est
l'histoire du collectif. Sans elle, le fonds devient une pile anonyme en une génération.
Le réseau ne te demande pas de faire le rattrapage rétroactif — il demande que la dette
cesse de croître à partir de maintenant.

### 5.4 Le reste de `/catalogacao`, quand tu en auras besoin

Importations en masse, assistant de dédoublonnage en trois temps, recherche de
couvertures, sources externes de métadonnées, dépôt avec OCR dans le navigateur,
inventaire par lecture des étiquettes QR, périodiques et leurs états de collection. Rien
de tout cela n'est nécessaire la première semaine. C'est là quand ce sera le moment.

### 5.5 Sujets et thésaurus FICEDL

AnarBib embarque le **thésaurus FICEDL** : 462 termes, traduits dans les dix langues,
livrés avec le logiciel. C'est un bien commun de la fédération, et il arrive déjà rempli —
ce n'est pas une tâche pour toi.

Les **sujets locaux**, à l'inverse, appartiennent à chaque maison : c'est ton fonds, ton
vocabulaire, tes choix éditoriaux. Et **aligner** tes sujets sur les termes FICEDL est un
acte du collectif, pas une opération technique : dire que ton « abolitionnisme pénal »
correspond au terme commun « prison » est une position documentaire. C'est pourquoi
l'alignement n'arrive pas tout fait.

---

## 6. Jours 10 à 25 — Le comptoir

Quatre flux, et le painel les organise :

- **Emprunt** — sortie, retour (y compris partiel), prorogation. La prorogation peut se
  faire item par item : si la personne a fini deux des trois livres, seul le troisième est
  prorogé.
- **Retour** — total ou ligne par ligne. Une action en masse n'échoue jamais en silence :
  ce qui n'est pas passé est listé avec sa raison.
- **Consultation locale** — la personne veut voir quelque chose sur place, on négocie un
  créneau. **La négociation s'arrête à trois allers-retours** : au-delà, le logiciel vous
  renvoie au téléphone. C'est délibéré — une négociation qui dépasse cela n'est pas un
  problème de logiciel.
- **Réservation** — jusqu'au retrait effectif, qui transforme la réservation en emprunt.

À côté de cela, dans le painel : les **validations** des inscriptions de lecteur·rices
(c'est ici que vous décidez qui entre), la **caution** si votre maison la pratique, les
**contributions**, les **notes de lecture**, les **événements**.

> **Un défaut connu.** Le bouton « Ouvrir les emprunts » de certaines tâches du Travail du
> jour mène à un onglet vide. Ce n'est pas toi. Passe directement par l'onglet **Emprunts**
> (`emprestimos-livro`).

---

## 7. Jours 20 à 30 — La fédération

La page **Federação** a huit onglets : **Início**, **Círculos**, **Diretório**,
**Assembleias**, la gazette **Rizoma**, **Carta/Boletim**, **Apoio mútuo** et **Comuns**.

C'est la partie du logiciel qui n'est pas un SIGB. Elle existe parce que le projet ne veut
pas être un « SaaS pour bibliothèques » : entrer dans AnarBib, c'est entrer dans un projet
politique commun, et un réseau qui n'échange que des notices n'est pas un réseau.

Ce qu'il y a à faire cette dernière semaine, sans hâte :

1. **Passer d'`observer` à `federated`**, si c'est ce que vous avez décidé — et seulement
   si. Entrer dans le réseau en mode observateur pendant quelques mois est un choix
   respectable.
2. **Remplir votre fiche dans le Diretório**, pour que les autres maisons sachent qui vous
   êtes et comment vous parler.
3. **Décider de la cartographie** — apparaître avec une adresse précise, seulement avec la
   ville, ou ne pas apparaître. Aucune des trois réponses n'a à être justifiée.
4. **Regarder les Círculos et les Assembleias**, pour savoir où les décisions du réseau se
   prennent.
5. **Si vous publiez le catalogue**, voir avec le réseau ce que le point OAI-PMH signifie
   pour vous — c'est par lui que d'autres catalogues peuvent moissonner le vôtre.

La page `/rede` est l'administration du réseau proprement dite, réservée aux admins
réseau. Coordonner une bibliothèque n'y donne pas accès, et c'est voulu.

---

## 8. Les dix décisions qui ne sont pas techniques

Découpe cette liste et porte-la en assemblée. Aucune de ces réponses n'est dans le
logiciel : le logiciel ne fait qu'enregistrer ce que vous répondrez.

1. Où nous plaçons-nous sur les quatre axes du profil ?
2. Notre catalogue est-il public ?
3. Prêtons-nous, et à quelles conditions ?
4. Qui peut s'inscrire comme lecteur·rice, et qui valide ?
5. Avons-nous une cotisation ? Une caution ?
6. Combien de temps gardons-nous l'historique de lecture des personnes ?
7. Qui est de l'équipe, et activons-nous le saut collégial ?
8. Apparaissons-nous sur la cartographie, et avec quelle précision ?
9. Participons-nous aux assemblées du réseau, et qui nous y représente ?
10. Comment alignons-nous nos sujets sur le thésaurus commun — et qu'est-ce que nous
    refusons d'aligner ?

---

## 9. Ce qui ne casse rien, et ce qui demande une deuxième lecture

**Ne casse rien :** cliquer partout, ouvrir tous les onglets, changer le niveau de fiche
pour voir, enregistrer un volet à moitié, proposer une personne et laisser la proposition
expirer, activer et désactiver le saut collégial, passer d'`observer` à `federated`,
corriger une fiche.

**Demande une deuxième lecture, parce que cela ne revient pas en arrière ou coûte cher :**

- **Supprimer** un compte — et attention : en portugais, le logiciel distingue **APAGAR**
  (vider l'historique) et **EXCLUIR** (supprimer le compte), avec deux mots de
  confirmation différents. Dans les neuf autres langues, les deux tombent sur le même mot.
  Lis la phrase entière avant de taper, pas seulement le mot demandé.
- Effacer un historique — les données ne reviennent pas.
- Les transitions de profil marquées irréversibles dans l'onglet Transitions.
- Publier en réseau un fonds que le collectif n'a pas décidé de publier.
- Retirer quelqu'un de l'équipe — le délai de carence de 7 jours existe précisément pour
  cela.

---

## 10. Où demander de l'aide, et comment rendre

**Demander de l'aide :** `anarbib@proton.me`. Dis sur quel écran tu es et ce que tu
t'attendais à voir. Il n'y a pas de question bête : le logiciel a été écrit par une
personne, et chaque « je n'ai pas trouvé » qui remonte est un défaut identifié.

**Un rituel qui marche.** Une demi-heure par semaine, avec l'équipe, trois questions
fixes :

> qu'est-ce que je n'ai pas trouvé à l'écran ? · qu'est-ce que j'ai fait sans comprendre ?
> · qu'est-ce qui manquait au logiciel ?

Les réponses alimentent une feuille de lacunes qui devient l'ordre du jour suivant — et un
matériau de contribution au projet. C'est le seul dispositif qui fasse remonter l'usage
vers le code.

**Rendre, sans programmer.** Le fichier `AIDER.md`, à la racine du dépôt, liste les tâches
ouvertes qui ne demandent pas de code : traduction, relecture d'écriture inclusive,
documentation, alignement de sujets, test d'écrans. AnarBib est sous AGPLv3 et n'a
aujourd'hui qu'un·e seul·e mainteneur·se — c'est sa principale fragilité, et elle se dit
au lieu de se taire.

---

## 11. Les trente jours en une page

| Quand | Quoi | Où |
|---|---|---|
| Jour 1 | Se connecter, changer le mot de passe, se promener sans rien changer | `/login`, `/conta` |
| Jours 1–3 | Étape 0 : les quatre axes, décidés en collectif | `/atelier` |
| Jours 3–5 | Volets 1 à 9 | `/atelier` |
| Jour 5 | Volet 10 : télécharger le squelette de règlement | `/atelier` |
| Jours 5–10 | Porter le règlement en assemblée, amender, re-téléverser | assemblée, puis `/atelier` |
| Jours 5–10 | Recueillir les ID publics, ouvrir les circuits de cooptation | `/biblioteca`, onglet Équipe |
| Jours 7–20 | Premières fiches en mode Simples, toutes avec provenance | `/catalogacao` |
| Jours 10–25 | Première journée de comptoir en autonomie | `/painel` |
| Jours 20–30 | Fiche au diretório, cartographie, mode de réseau | Federação, `/biblioteca` |
| Jour 30 | Écrire au réseau : ce qui a manqué, ce qui a trompé | `anarbib@proton.me` |

---

*Ce guide existe en dix langues : pt-BR, fr, es, en, it, de, ca, eo, nl, el. Il décrit
l'état du logiciel en septembre 2026 et sera corrigé quand le logiciel changera — si un
écran ne correspond pas à ce qui est écrit ici, c'est le guide qui a tort, et le dire est
une contribution.*

**Bienvenue.**
