# RIFLEXION — Articulation onboarding/wizard ↔ profils d'adoption

**Date** : 19-20 mai 2026 (session marathon clôture chantier profils v0.7)
**Auteur** : Xavier (réflexion guidée par Claude)
**Statut** : capture conversationnelle, à enrichir lors du chantier #111

---

## Pourquoi ce document

À la clôture du chantier profils d'adoption (spec v0.7, 20/05/2026), Xavier a
demandé d'examiner comment ce qui vient d'être livré (wizard F.3 + transitions
E.5) **s'articule** avec ce qui était cadré antérieurement dans
`spec-onboarding-biblioteca.md v1.1` et avec le chantier #111 (wizard
onboarding biblio, perspective Q3 2026, backlog v8 du 13/05/2026).

L'échange a fait émerger une **doctrine politique nouvelle** que ces specs ne
capturent pas explicitement, et qui doit être prise en compte pour la
conception du wizard complet du chantier #111.

---

## 1. Trois visions qui se croisent

### 1.1 Vision spec-onboarding-biblioteca v1.1 (mai 2026, antérieure)

Cadre conceptuel complet du parcours d'une biblio depuis sa demande
d'adhésion jusqu'à son activation effective. **Vision riche et structurée** :

- États du compte côté solicitante : `solicitante_inicial`,
  `solicitante_pendente`, `solicitante_recusada`, `coordenador_em_constituicao`
- Workflow d'évaluation côté admins réseau (proposition + votes à
  l'unanimité, refonte v1.1 après livraison admin réseau)
- **Parcours obligatoire de constitution : Volet 0 + 10 volets** (§6)
- Activation effective à la fin du Volet 10 (PDF de règlement uploadé)

Doctrine centrale du §6 :
- Démarre **après** validation admin réseau (statut `coordenador_em_constituicao`)
- Modulaire : sauvegarde + reprise possible
- Deadline 60 jours, rappel J+45
- Biblio en **pré-actif** tant que pas terminé (pas visible au catalogue, ne
  reçoit pas de lecteurs)
- À la fin : PDF de règlement pré-rempli, à amender en assemblée, à
  uploader pour activation effective

Les **11 volets** :

| Volet | Sujet | Conditionnel |
|---|---|---|
| 0 | Choix profil d'adoption (4 axes) | obligatoire |
| 1 | Identité de la biblio | toujours |
| 2 | Horaires et permanences | toujours |
| 3 | Personnes responsables | conditionnel `governance_mode` |
| 4 | Politique de catalogage | toujours, paramétré |
| 5 | Politique de circulation | conditionnel `circulation_mode` |
| 6 | Politique d'adhésion lecteur·rice | conditionnel `governance` + `circulation` |
| 7 | Politique des e-mails | toujours |
| 8 | Visibilité réseau | conditionnel `network_mode` |
| 9 | Données et confidentialité | toujours |
| 10 | Génération PDF règlement | toujours |

### 1.2 Ce qui a été livré cette session (F.3, mai 2026)

Le **wizard F.3** dans `LibraryProfileWizard.jsx` (330 lignes) couvre
**uniquement le Volet 0** (choix du profil d'adoption sur 4 axes) :

- Intégré dans `SolicitarBibliotecaPage.jsx` (formulaire public de demande)
- **Avant** validation admin réseau (à la soumission), pas après
- Pas de sauvegarde modulaire (un seul écran multi-étapes)
- Pas de génération de PDF

### 1.3 Vision #111 (backlog v8, 13/05/2026, perspective Q3 2026)

Item #111 cadre un futur **wizard onboarding biblio post-validation** :

> « Après validation admin d'une demande de biblio, le coordenador arrive sur
> BibliotecaPage **écrasante** (dizaines de formulaires, choix techniques).
> Proposition : wizard multi-étapes au premier login post-validation,
> regroupement thématique des décisions, valeurs par défaut anarchistes
> raisonnables, génération automatique d'un règlement intérieur exportable
> PDF et réutilisable comme "règlement type" partageable. »

Et une **idée alternative à reconsidérer** au moment du chantier :

> « Site statique pour le parcours d'inscription biblio (anarbib.org au lieu
> de app.anarbib.org). »

Score 12 dans le backlog v8. Postérieur au chantier profils #98 dans le
séquencement.

### 1.4 Cohérence des trois visions

Les 3 visions disent la **même chose** avec des focales différentes :
- spec onboarding v1.1 décrit la **structure conceptuelle** (11 volets)
- F.3 livré implémente le **premier volet seulement**, à un moment du cycle
  de vie différent que prévu (avant validation au lieu d'après)
- #111 reformule la **vision opérationnelle** en pointant explicitement le
  problème ressenti (BibliotecaPage écrasante)

Donc : **le chantier #111 = implémentation des volets 1-10 de la spec
onboarding v1.1, déclenché après validation admin réseau**. Le wizard F.3
livré cette session est un acompte qu'on a partiellement décalé en amont du
cycle (à la soumission au lieu de l'après-validation).

---

## 2. Doctrine actée cette session : anti-méga-machine

L'échange a fait émerger une doctrine politique nouvelle qui ne figure
**explicitement** dans aucune des 3 visions ci-dessus, et qui doit être
intégrée au chantier #111 (et au-delà).

### 2.1 Formulation

> Plus le SIGB grossit en complexité, plus le canal humain doit s'épaissir.
>
> La complexité technique légitime (8-12 onglets sur Painel, autant sur
> Biblioteca, plus le catalogage à venir) n'est pas un signal qu'il faut
> **lisser l'UX au point de cacher cette complexité**, ni un signal qu'il
> faut **enterrer le collectif sous des manuels**. C'est un signal qu'il
> faut **rendre visibles les humains de la fédération** qui peuvent
> débroussailler.
>
> Le SIGB AnarBib n'est pas une plateforme téléphonique avec un sous-menu
> « parler à quelqu'un » caché au niveau 7. C'est une **fédération outillée
> par un SIGB**, dans laquelle le canal direct humain (email collectif,
> Matrix) est **premier** et le SIGB est **second**.

### 2.2 Trois exigences qui en découlent

1. **À chaque endroit où une décision configurante doit être prise**, le
   collectif doit voir un canal humain disponible — pas un FAQ, pas un
   tooltip, mais un vrai « écris à `anarbib@proton.me` ou rejoins-nous sur
   Matrix `#anarbib:libreflux.fr` ».

2. **Le canal humain n'est jamais positionné comme un fallback** (« si vous
   êtes vraiment perdu·e ») mais comme un égal (« parlons-en avant de
   cliquer »).

3. **Les admins réseau ne sont pas des modérateurs ou des techniciens**. Ce
   sont des **camarades qui connaissent bien l'outil et qui sont là pour
   partager cette connaissance** — politique exactement opposée à une
   hotline.

### 2.3 Articulation avec la spec onboarding v1.1

La spec onboarding v1.1 décrit déjà un **canal humain via mail** au moment
de l'évaluation (§5.4 : commentaires admins, demandes de complément,
rationale de veto) et après refus (motif communiqué). Mais elle ne décrit
pas explicitement le canal humain :
- **Pendant** le parcours de constitution (volets 1-10) → un coordenador
  bloqué·e sur le volet 5 n'a pas de bouton "appeler à l'aide"
- **Après activation** → le banner G (paquet livré) renvoie au mécanisme de
  vote collectif, pas à un canal humain
- **Pour les biblios existantes** → BibliotecaPage et PanelPage n'ont pas
  de footer global avec coordonnées

La doctrine anti-méga-machine **complète** la spec onboarding v1.1 sans
la contredire, en exigeant que le canal humain soit **constamment visible**
et pas seulement au moment de l'évaluation initiale.

---

## 3. Scénario pédagogique : Bibliothèque Émile-Henry

Pour rendre la doctrine concrète, voici le scénario travaillé pendant la
discussion :

**Émile-Henry**, à Lyon, demande sa création sur AnarBib le 25/05/2026.
Camille (future coordenadora) remplit le wizard F.3 sur
`SolicitarBibliotecaPage`, et **clique profil D pré-câblé** sans le
modifier (sentiment de pression, pas le temps de lire les libellés, choix
par défaut). Le réseau valide en 3 jours.

Une semaine plus tard, l'assemblée Émile-Henry réalise :
> « En fait nous, on prête nos livres en chuchotant pendant nos réunions
> hebdo et on note ça sur un cahier. On ne veut pas de SIGB. On veut juste
> un catalogue qu'on partage avec d'autres biblios anars d'Europe. »

Le bon profil pour eux serait probablement **B** (`local_only/informal/federated/informal`).

**Sans la doctrine anti-méga-machine** (état actuel) :
- Banner G s'affiche sur leur BibliotecaPage
- Lecture du banner : « utilisez le mécanisme de vote collectif »
- Clic sur l'onglet Transições → 4 propositions à faire (`catalog_mode`,
  `circulation_mode`, `network_mode`, `governance_mode`), chacune avec son
  type de transition, donc **8 semaines minimum de procédure**
- Risque qu'ils abandonnent en chemin par fatigue

**Avec la doctrine anti-méga-machine** (proposition Q3 2026 ↔ #111 enrichi) :
- Banner G enrichi : « ... ou écrivez-nous pour qu'on en discute ensemble »
- Camille envoie un mail à `anarbib@proton.me`
- Un·e admin réseau (Xavier ou autre) répond, propose un appel Matrix,
  **traduit leur pratique réelle en quadruplet d'axes** (pédagogie située :
  « toi tu dis que vous prêtez en chuchotant, donc circulation_mode informal
  pas full_sigb », etc.)
- À l'issue de la conversation, le collectif **comprend ses axes**, peut
  voter collectivement en assemblée le re-choix
- Le mécanisme de vote E.5 reste celui qui formalise techniquement, mais la
  délibération de fond a eu lieu avant, **hors SIGB**, **avec un·e camarade**

Le SIGB ne remplace pas la fédération, il l'outille.

---

## 4. Implications pour le chantier #111

Quand le chantier #111 sera lancé (perspective Q3 2026), il devra
intégrer la spec onboarding-biblioteca v1.1 §6 (volets 1-10) **enrichi** de
la doctrine anti-méga-machine. Quelques principes :

### 4.1 Le wizard doit avoir un canal humain *intégré*

Chaque volet du wizard de constitution doit comporter un encadré persistant
type :

> « Cette étape configure {sujet}. Si vous voulez en discuter avant de
> remplir : **anarbib@proton.me** ou Matrix `#anarbib:libreflux.fr`. On
> peut vous accompagner sur un appel collectif. »

Pas un tooltip caché, pas une mention en bas de page. **Visible, militant,
normalisé**.

### 4.2 Les admins réseau doivent disposer d'un canal vers la biblio en
constitution

Aujourd'hui (spec v1.1 §5.4), le canal admins → solicitante est unilatéral :
demande de complément d'information. Il faudrait permettre aux admins
réseau de **proposer eux·elles-mêmes un échange** pendant le parcours de
constitution (« on a vu que vous êtes au volet 5 depuis 2 semaines, voulez-vous
qu'on en discute ? »).

Implémentation possible : bouton « Proposer un échange » dans l'interface
admins réseau pour les demandes en `coordenador_em_constituicao` depuis
> N jours.

### 4.3 Le PDF de règlement (Volet 10) doit être un *artefact de
délibération collective*

Pas un « certificat de complétion technique » mais un **document à
discuter en assemblée**. Le wizard doit le présenter explicitement comme tel :

> « Téléchargez ce squelette, discutez-en en assemblée. Vous pouvez le
> modifier librement avant de le re-uploader. Si vous voulez nous le faire
> relire avant assemblée, écrivez-nous. »

### 4.4 L'idée alternative « site statique pour l'inscription » mérite
d'être réexaminée

Backlog v8 mentionne : « site statique pour le parcours d'inscription
biblio (anarbib.org au lieu de app.anarbib.org), à reconsidérer au moment
du chantier ».

Avec la doctrine anti-méga-machine, cette idée prend du sens : un parcours
d'entrée sur **anarbib.org** (le site militant 8 locales avec sa charte,
ses portes d'entrée différenciées) plutôt que sur **app.anarbib.org** (le
SIGB qui peut intimider) **rendrait plus naturel le canal humain comme
porte d'entrée première**.

Le formulaire de demande resterait sur l'app, mais le **chemin éditorial**
qui y mène (lecture de la charte, intuition du fonctionnement de la
fédération, choix de la porte d'entrée) se ferait sur le site marketing.

À creuser au moment du chantier #111.

---

## 5. Cinq implémentations concrètes à backlogger

Ces items s'ajoutent au backlog technique (v0.7 §11, qui devient §11
post-RIFLEXION) ou attendent le chantier #111 :

| # | Item | Priorité | Échéance |
|---|---|---|---|
| 1 | Footer global persistant sur toutes les pages staff (Painel, Biblioteca, NetworkAdmin, AdminsPanel) avec `anarbib@proton.me` + Matrix | Moyenne | Indépendante #111 (peut être faite avant) |
| 2 | Page `/conversemos` (ou `/ajuda`) courte qui présente le canal humain comme premier, et les guides comme second | Moyenne | Indépendante #111 |
| 3 | Encadré inline « parlons-en avant de modifier » sur les pages Biblioteca (gouvernance, profil, transitions, regimento) | Moyenne | Indépendante #111 |
| 4 | Bandeau encadré sur SolicitarBibliotecaPage avant le formulaire : « vous pouvez aussi nous écrire pour qu'on en discute avant » | Basse | Peut être fait avant #111 (gain immédiat) |
| 5 | Enrichissement du banner G : « ... ou écrivez-nous pour qu'on en parle ensemble » | Basse | Peut être fait rapidement (1 modif simple) |

Et pour le chantier #111 lui-même :

| # | Item | Échéance |
|---|---|---|
| 6 | Implémenter les volets 1-10 de spec-onboarding-biblioteca v1.1 §6 | Chantier #111 (Q3 2026) |
| 7 | Intégrer encadré « parlons-en avant de remplir » dans chaque volet | Chantier #111 |
| 8 | Bouton « Proposer un échange » côté admins réseau pour biblios en `coordenador_em_constituicao` | Chantier #111 |
| 9 | Reconsidérer parcours d'entrée sur anarbib.org plutôt que app.anarbib.org | Chantier #111 |
| 10 | Doctrine PDF règlement comme artefact de délibération, pas certificat technique | Chantier #111 |

---

## 6. Question ouverte (non tranchée ce soir)

**Wizard de redéfinition collective pour les biblios existantes** ?

C'était la question initiale qui a déclenché la discussion. La réponse
qui émerge :
- Pas de wizard de redéfinition **séparé** des transitions E.5
- Mais peut-être : à l'occasion du chantier #111, **étendre le wizard
  d'onboarding** pour qu'il puisse aussi servir de wizard de
  **redéfinition** post-création, sous condition de vote collectif
- Le déclencheur n'est plus « 30 jours après la création » mais « le
  collectif demande explicitement à reconfigurer son profil de fond »
- L'idée est portée par #111, pas par un chantier séparé

À reformuler proprement au moment du cadrage de #111.

---

## 7. Conclusion provisoire

Ce que ce soir a permis de poser :

1. La spec onboarding-biblioteca v1.1 est **plus riche** que je
   (Claude) ne l'avais en mémoire. Le wizard F.3 livré est seulement le
   Volet 0 de cette vision plus large.

2. Le chantier #111 du backlog v8 doit être pensé comme l'implémentation
   des Volets 1-10 de cette spec, mais **enrichi** de la doctrine
   anti-méga-machine.

3. La doctrine anti-méga-machine est nouvelle et doit être propagée
   dans tout le SIGB, pas seulement dans l'onboarding (footer global,
   encadrés inline, etc.). Plusieurs implémentations concrètes peuvent
   être faites **avant** le chantier #111.

4. Le scénario Émile-Henry montre que le **canal humain** n'est pas un
   luxe d'UX mais une **condition de fonctionnement** de la fédération
   pour des collectifs au caractère informel souvent prononcé.

5. L'idée alternative « parcours d'entrée sur anarbib.org plutôt que
   app.anarbib.org » mérite d'être prise au sérieux : elle est cohérente
   avec la doctrine.

À reprendre au moment du cadrage du chantier #111 (Q3 2026), idéalement
avec relecture commune de :
- Cette RIFLEXION
- `spec-onboarding-biblioteca.md v1.1`
- `spec-profils-bibliotheque-v0.7.md` §13 (articulation onboarding ↔ profils)
- Backlog item #111

---

*Capture en fin de session marathon 19-20 mai 2026, 23h30.*
