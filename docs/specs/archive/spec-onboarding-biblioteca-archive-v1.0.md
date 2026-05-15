# Spec — Onboarding d'une bibliothèque dans le réseau AnarBib

**Statut** : Cadrée le 05/05/2026, en attente d'implémentation
**Cible** : Bologna FICEDL, septembre 2026
**Auteur·rices** : Xavier (spec et arbitrages) + Claude (rédaction)
**Dépendances** :
  - `docs/spec-validation-physique.md` (s'applique aux comptes lecteur·rice rattachés à une biblio existante)
  - `docs/spec-migration-compte.md` (s'applique aux migrations entre biblios existantes — distinct du présent parcours)

---

## Sommaire

1. [Contexte et objectif](#1-contexte-et-objectif)
2. [Modèle conceptuel](#2-modèle-conceptuel)
3. [Schéma DB](#3-schéma-db)
4. [UX dans `/conta` selon l'état du compte](#4-ux-dans-conta-selon-létat-du-compte)
5. [Workflow de validation côté admins](#5-workflow-de-validation-côté-admins)
6. [Parcours obligatoire de constitution (10 volets)](#6-parcours-obligatoire-de-constitution-10-volets)
7. [Notifications mail](#7-notifications-mail)
8. [Cas particuliers](#8-cas-particuliers)
9. [Hors scope](#9-hors-scope)
10. [Checklist d'implémentation](#10-checklist-dimplémentation)

---

## 1. Contexte et objectif

### Contexte

AnarBib est un réseau de bibliothèques militantes. Pour qu'une bibliothèque rejoigne le réseau, il faut une démarche **explicite, validée et constitutive**, pas une simple inscription technique. Le projet refuse le modèle « SaaS pour bibliothèques » : entrer dans AnarBib, c'est s'inscrire dans un projet politique commun, pas activer un produit.

### Objectif

Définir le parcours complet d'onboarding d'une nouvelle bibliothèque dans le réseau, depuis l'inscription du futur·e coordinateur·rice jusqu'à l'activation effective de la bibliothèque, en passant par la sollicitation institutionnelle, la validation par les admins réseau, et la constitution obligatoire du règlement.

### Principes directeurs

1. **Un compte lecteur·rice sans bibliothèque est un état transitoire**, pas un mode de fonctionnement par défaut. Il n'existe que pour permettre la sollicitation d'une nouvelle adhésion ou comme conséquence d'une fermeture de biblio (limbo de migration, hors scope ici).

2. **Toute nouvelle bibliothèque dans le réseau procède d'un acte d'auto-définition collective**. La validation administrative ne suffit pas : la biblio doit constituer son règlement et ses règles avant d'être opérationnelle.

3. **La validation physique du·de la coordinateur·rice initial·e est intégrée à l'évaluation de la demande**. La validation physique standard (rencontre avec un·e librarian d'une biblio existante AnarBib) ne s'applique pas aux solicitantes — par définition leur biblio n'existe pas encore. La coordination réseau évalue l'ensemble de la démarche en bloc.

4. **La coordination du réseau (rôle `administrador`) évalue les demandes** sur la base d'un formulaire détaillé et de tout échange complémentaire jugé nécessaire, avec validation à deux yeux (un·e admin propose, un·e autre confirme) et traçabilité complète.

5. **Souveraineté de la bibliothèque créée** sur la définition de ses propres règles. Le wizard de constitution structure cette définition mais ne l'impose pas : chaque biblio choisit ses propres modalités dans le cadre AnarBib.

---

## 2. Modèle conceptuel

### 2.1 — Acteurs en présence

Quatre types d'acteurs interviennent dans le parcours d'onboarding :

- **Le·la futur·e coordinateur·rice** : la personne qui s'inscrit comme lectrice et soumet la demande, mandatée par son collectif local.
- **Le collectif portant la biblio** : entité morale qui décide collectivement d'adhérer à AnarBib. Pas représenté techniquement dans le système, mais présent symboliquement (le formulaire demande de confirmer « représente une biblio réelle »).
- **La coordination du réseau (administradores)** : un·e ou plusieurs admins qui évaluent et valident les demandes.
- **Le réseau AnarBib** lui-même : entité collective qui accueille (ou non) la nouvelle biblio.

### 2.2 — États possibles d'un compte lecteur·rice sans bibliothèque

| État | Origine | Durée | Capacités |
|---|---|---|---|
| `solicitante_inicial` | Inscription via `/criar-conta` avec « Não encontrei minha biblioteca » | 90 jours max (cf. 2.4) | Catalogue commun en lecture, profil minimal éditable, accès au formulaire `/solicitar-biblioteca`. Pas de réservation, pas d'emprunt. |
| `solicitante_pendente` | A soumis le formulaire de demande | Variable (typiquement 7-14 jours pour évaluation) | Idem `solicitante_inicial`, plus suivi du statut de la demande. Plus d'accès en écriture au formulaire. |
| `solicitante_recusada` | Demande refusée par la coordination | 90 jours puis suppression | Lecture seule + récap motif refus + possibilité de re-soumettre une demande corrigée. |
| `coordenador_em_constituicao` | Demande validée, parcours de règlement en cours | 60 jours puis gel ou révocation (TODO §10) | Accès au wizard de constitution. Pas encore reader actif. |
| `limbo_fechamento` | Sa biblio a fermé, en attente de migration | Limité (cf. spec migration) | **Hors scope de cette spec** |

**Note importante** : un état `sem_biblio_orphan` (compte sans biblio sans démarche active) est explicitement exclu par cette spec. Il doit être bloqué structurellement par les triggers DB et les contraintes UX. Pas de biblio possible sans engagement explicite dans une démarche d'adhésion.

### 2.3 — Conditions d'éligibilité pour soumettre une demande

**Règle UX (visible)** : le lien `/solicitar-biblioteca` n'apparaît dans `/conta` que pour les comptes en état `solicitante_inicial` (sans biblio rattachée et sans demande active).

**Règle backend (souple)** : la page `/solicitar-biblioteca` est accessible par URL directe et accepte les soumissions de toute personne authentifiée avec mot de passe modifié, indépendamment de son état de rattachement à une biblio.

Ce compromis (Option B des arbitrages) maintient la cohérence UX (les utilisateur·rices nominaux ne voient pas le lien) tout en autorisant des cas légitimes peu fréquents (un·e coordinateur·rice d'une biblio existante mandaté·e par son collectif pour faire la jonction avec une biblio sœur dans une autre ville).

Quand la demande est soumise par un·e utilisateur·rice rattaché·e à une biblio existante, ce contexte est visible des admins lors de l'évaluation comme **information contextuelle**, pas comme obstacle.

### 2.4 — Conditions techniques préalables

Pour soumettre une demande via `/solicitar-biblioteca`, il faut :

- Être authentifié·e avec un compte actif
- Avoir modifié son mot de passe provisoire (preuve passive de prise en main)

La validation physique standard ne s'applique pas (cf. principe 3) : pour les solicitantes, la validation est consubstantielle à l'évaluation de la demande.

### 2.5 — Pression sur les comptes `solicitante_inicial`

Pour éviter l'accumulation de comptes sans suite, le compte en état `solicitante_inicial` est soumis à une pression graduée :

- **0-30 jours** : pression douce (bandeau permanent dans `/conta`)
- **30-60 jours** : pression moyenne (rappel par email à J+30)
- **60-90 jours** : pression forte (rappel par email à J+60 + avis de suppression imminente à J+83)
- **90 jours** : suppression automatique du compte avec notification

Le calendrier détaillé des mails est en section 7.

### 2.6 — La coordination du réseau (administradores)

Le rôle `administrador` est défini dans le modèle 4 rôles d'AnarBib (cf. notes internes du projet). Sa promotion (cooptation) est gérée hors de cette spec.

**Validation à deux yeux** : pour qu'une demande soit acceptée ou refusée, il faut qu'un·e admin propose la décision et qu'un·e second·e admin la confirme.

**Mode dégradé « seul·e admin »** : tant qu'il n'y a qu'un·e seul·e admin actif·ve dans le réseau (cas typique du démarrage), le mécanisme à deux yeux est désactivé : l'admin auto-confirme ses propres propositions. Le mécanisme s'active automatiquement dès qu'un·e second·e admin est actif·ve.

### 2.7 — Catégories de refus

En cas de refus, l'admin choisit une catégorie dans une liste fermée et peut compléter par un motif libre facultatif.

| Catégorie | Description |
|---|---|
| `info_insuffisante` | Informations soumises trop vagues ou incomplètes |
| `non_verifiable` | Impossible de vérifier l'existence réelle du collectif |
| `desalignement_politique` | Projet ne s'inscrivant pas dans les valeurs du réseau anarchiste/militant |
| `doublon` | Biblio déjà présente dans le réseau ou très similaire à une existante |
| `prematuré` | Projet trop embryonnaire (à re-soumettre quand plus avancé) |
| `repeticao_sem_evolucao` | Re-soumission d'une demande refusée sans correction substantielle |
| `autre` | Motif libre uniquement |

La catégorie est visible de la personne refusée. Le motif libre est visible **si et seulement si** il a été rédigé.

---

## 3. Schéma DB

### 3.1 — Tables impactées

**Table existante à étendre** : `library_requests`

Nouveaux statuts (en plus de `pendente` qui existe) :
- `aguardando_info` (admin a demandé un complément, en attente de réponse)
- `proposta_aprovacao` (un·e admin a proposé l'acceptation)
- `proposta_recusa` (un·e admin a proposé le refus)
- `aprovada` (acceptation confirmée)
- `recusada` (refus confirmé)
- `expirada` (demande expirée sans suite)
- `cancelada` (annulée par la personne solicitante)

Nouveaux champs :
- `proposed_by_admin_id` (UUID, FK profiles)
- `proposed_at` (timestamp)
- `proposed_decision` ('aprovacao' | 'recusa')
- `confirmed_by_admin_id` (UUID, FK profiles)
- `confirmed_at` (timestamp)
- `refusal_category` (enum cf. 2.7)
- `refusal_reason` (text, nullable)

**Nouvelle table** : `library_request_comments`

Commentaires admins internes sur une demande, visibles uniquement par les admins.

```
- id (uuid, pk)
- request_id (uuid, fk library_requests)
- author_admin_id (uuid, fk profiles)
- content (text)
- created_at (timestamp)
```

**Nouvelle table** : `library_request_messages`

Échanges complément/réponse avec la personne solicitante.

```
- id (uuid, pk)
- request_id (uuid, fk library_requests)
- author_id (uuid, fk profiles) — admin ou solicitante
- direction ('admin_to_solicitante' | 'solicitante_to_admin')
- content (text)
- created_at (timestamp)
- read_at (timestamp, nullable)
```

**Nouveau champ sur `profiles`** :

- `solicitante_state` (enum, nullable) : valeurs cf. 2.2. Null pour les comptes standards rattachés à une biblio.

**Nouvelle table** : `library_constitution_progress`

Suit l'avancement du wizard de constitution pour une demande validée.

```
- id (uuid, pk)
- request_id (uuid, fk library_requests, unique)
- coordenador_id (uuid, fk profiles)
- started_at (timestamp)
- deadline_at (timestamp) — calculé à started_at + 60 jours
- completed_at (timestamp, nullable)
- volet_1_identite_done (boolean, default false)
- volet_2_horaires_done (boolean, default false)
- volet_3_pessoas_done (boolean, default false)
- volet_4_catalogacao_done (boolean, default false)
- volet_5_circulacao_done (boolean, default false)
- volet_6_adhesion_done (boolean, default false)
- volet_7_emails_done (boolean, default false)
- volet_8_visibilidade_done (boolean, default false)
- volet_9_dados_done (boolean, default false)
- volet_10_regimento_done (boolean, default false)
- regimento_pdf_url (text, nullable)
```

### 3.2 — RLS

- **Solicitantes** : voient leurs propres demandes (`submitted_by_user_id = auth.uid()`), leurs propres messages, leur propre `constitution_progress`. Ne voient pas les commentaires admins.
- **Admins** (`administrador`) : voient toutes les demandes, tous les commentaires admins, tous les messages, tous les `constitution_progress`.
- **Public** : ne voit rien des `library_requests` (les demandes ne sont pas publiques).

### 3.3 — Triggers

- À la transition `pendente` → `aprovada` : créer automatiquement un row dans `library_constitution_progress` avec deadline = now() + 60 days.
- À l'expiration deadline `solicitante_inicial` (90j) : trigger DB de suppression du compte (avec notification mail préalable).
- À l'expiration deadline `coordenador_em_constituicao` (60j) : à arbitrer (cf. TODO §10).
- À l'expiration deadline `solicitante_recusada` (90j) : suppression du compte.

---

## 4. UX dans `/conta` selon l'état du compte

### 4.1 — Compte standard (rattaché à une biblio)

Page `/conta` actuelle, telle quelle. Aucun lien spontané vers `/solicitar-biblioteca`. La page accessible par URL directe reste fonctionnelle (option B de §2.3) mais n'est pas mise en avant.

### 4.2 — État `solicitante_inicial`

L'utilisateur·rice vient d'être inscrit·e sans biblio.

**UX** :
- Onglets standards désactivés (réservation, emprunts, historique, notifications, wishlist)
- **Onglet unique** : « Ma demande »
- **Bandeau d'appel à l'action très visible** en haut de page :
  > « Bienvenue ! Vous avez créé un compte sans bibliothèque rattachée. Pour rejoindre le réseau AnarBib, complétez maintenant la demande d'adhésion de votre bibliothèque. »
  > **[Bouton primaire : Soumettre la demande d'adhésion]** → `/solicitar-biblioteca`
- Profil éditable en mode minimal (champs perso uniquement, pas d'adresse postale liée à une biblio)

### 4.3 — État `solicitante_pendente`

Demande soumise, en cours d'évaluation par les admins.

**UX** :
- Onglet unique « Ma demande »
- Bandeau persistant : « Votre demande est en cours d'évaluation par la coordination AnarBib. Vous serez notifié·e par email dès qu'une décision sera prise. Délai indicatif : 7-14 jours. »
- Récapitulatif des informations soumises (lecture seule)
- Section « Échanges avec la coordination » : affiche les éventuelles demandes de complément + interface de réponse
- Profil éditable en mode minimal

### 4.4 — État `solicitante_recusada`

Demande refusée, délai de grâce de 90 jours.

**UX** :
- Onglet unique « Ma demande »
- Bandeau : « Votre demande a été refusée. Vous pouvez soumettre une nouvelle demande corrigée, ou laisser le compte se supprimer automatiquement à J+90. »
- Section « Motif du refus » : affiche la catégorie + motif libre s'il existe
- Bouton : « Soumettre une nouvelle demande corrigée » → `/solicitar-biblioteca` (réinitialise le statut à `solicitante_pendente`)
- Profil éditable en mode minimal

### 4.5 — État `coordenador_em_constituicao`

Demande validée, parcours de constitution en cours.

**UX** :
- Onglet unique « Constitution de ma bibliothèque »
- Bandeau : « Votre demande a été acceptée ! Complétez maintenant les 10 volets de constitution. Délai : 60 jours. »
- **Wizard multi-étapes** détaillé en section 6
- Possibilité de sauvegarder à tout moment et reprendre plus tard
- Indicateur de progression (X/10 volets complétés)
- Profil éditable en mode minimal

---

## 5. Workflow de validation côté admins

### 5.1 — Emplacement de l'interface

Section « Demandes d'adhésion » dans la page `/rede` (déjà admin-only).

### 5.2 — Vue liste

- Demandes filtrables par statut, par date, par catégorie de refus (pour les archivées)
- Indicateur de priorité (demandes nouvelles, demandes attendant confirmation à deux yeux, demandes en `aguardando_info` depuis longtemps)
- Compteur d'événements non lus

### 5.3 — Vue détaillée d'une demande

- Récapitulatif complet du formulaire soumis
- Contexte de l'utilisateur·rice (compte rattaché à une biblio existante ? si oui, laquelle ? depuis quand ?)
- Historique chronologique des actions (proposition, confirmation, commentaires, échanges avec la solicitante)
- Section commentaires admins (visibles uniquement entre admins)
- Section échanges avec la solicitante (visibles des deux côtés)
- Boutons d'action selon l'état actuel

### 5.4 — Actions disponibles

**Actions individuelles (un·e seul·e admin agit)** :
- **Commenter** : note interne admin (visible des autres admins, pas de la solicitante)
- **Demander complément d'information** : envoie un mail à la solicitante, demande passe en `aguardando_info`
- **Proposer l'acceptation** : statut → `proposta_aprovacao`, attend confirmation
- **Proposer le refus** : statut → `proposta_recusa`, avec catégorie et motif optionnel

**Actions à deux yeux** :
- **Confirmer une proposition** : statut → `aprovada` ou `recusada` selon la proposition
- **Objecter à une proposition** : statut revient à `pendente` avec commentaire obligatoire de l'objecteur·rice

**Actions exceptionnelles** :
- **Annuler sa propre proposition** : possible tant qu'aucun·e second·e admin n'a confirmé
- **Reprise d'une demande gelée** : un·e admin peut « réveiller » une demande expirée (`aguardando_info` sans réponse, ou parcours de constitution expiré)

### 5.5 — Mode dégradé « seul·e admin »

Tant qu'il n'y a qu'un·e seul·e admin actif·ve dans le réseau, l'admin peut auto-confirmer ses propres propositions. Le mécanisme à deux yeux s'active automatiquement dès qu'un·e second·e admin existe.

### 5.6 — Traçabilité

**À tracer obligatoirement** :
- Date et auteur·rice de chaque proposition
- Date et auteur·rice de chaque confirmation/objection
- Date et contenu de chaque commentaire admin
- Date et contenu de chaque demande de complément
- Date et contenu de chaque réponse de la solicitante

**Visibilité** :
- Admins : voient l'intégralité (commentaires inclus)
- Solicitantes : voient leurs soumissions, demandes de complément, statut final + catégorie + motif si fourni
- Public : aucun accès

**Conservation** :
- Demandes acceptées : conservées indéfiniment
- Demandes refusées : 90 jours après le refus puis archivées en mode anonymisé (statistiques préservées, données personnelles supprimées)

---

## 6. Parcours obligatoire de constitution (10 volets)

### 6.1 — Forme du parcours

**Modulaire avec deadline 60 jours**.

La personne peut sauvegarder à n'importe quel moment et revenir plus tard. La progression est visible (X/10 volets complétés). Un rappel mail est envoyé à J+45.

À J+60 sans complétion : **TODO** (cf. §10) — gel, révocation ou avertissement seul.

Tant que les 10 volets ne sont pas complétés, la biblio reste en mode **pré-actif** : pas visible dans le catalogue commun, ne reçoit pas de lecteur·rices.

### 6.2 — Les 10 volets

**Volet 1 — Identité de la bibliothèque**
- Nom complet, sigle/nom court, logo
- Description publique (texte affiché aux visiteurs anonymes)
- Adresse physique
- Coordonnées de contact (email, téléphone)
- Réseaux sociaux et sites externes (optionnel)

**Volet 2 — Horaires et permanences**
- Jours et heures d'ouverture
- Modalités de présence physique (permanences fixes, sur rendez-vous, etc.)
- Exceptions saisonnières (fermetures vacances, événements)

**Volet 3 — Personnes responsables**
- Coordinateur·rice principal·e (la personne qui fait la démarche, par défaut)
- Possibilité d'ajouter d'autres coordinateurs/librarians par invitation email
- Définition des rôles dans l'équipe initiale

**Volet 4 — Politique de catalogage**
- Système de classification (Dewey, CDU, classification anarchiste à définir collectivement, custom)
- Normes bibliographiques utilisées
- Règles d'indexation spécifiques à la biblio

**TODO** : décider si liste fermée ou choix libre. Choix libre risque d'incohérence du catalogue commun ; liste fermée nécessite un travail amont de catégorisation collective.

**Volet 5 — Politique de circulation**
- Modèle de prêt : durée par défaut, nombre max d'emprunts simultanés, possibilité de prolongation
- Modèle de réservation : oui/non, durée de la réservation, comportement en cas de no-show
- Consultation sur place : autorisée ou non, conditions
- Service mode par défaut (`funcionamento_normal`, `somente_consulta`, etc.)

**Volet 6 — Politique d'adhésion lecteur·rice**
- Mode physique : `aberto` (n'importe qui peut s'inscrire) ou `validacao_manual` (rencontre obligatoire)
- Cotisation : oui/non, montants suggérés, périodicité
- Règlement spécifique à signer à l'inscription (oui/non, document à uploader)

**Volet 7 — Politique des e-mails**
- Adresse expéditrice (par défaut générique AnarBib, ou custom propre à la biblio)
- Templates personnalisés (oui/non, ou hérités du défaut)
- Signature au pied des mails (logo, devise, horaires)

**Volet 8 — Visibilité et participation au réseau**
- Visible dans le catalogue commun ? (par défaut oui)
- Participe à RebAL (harvesting OAI-PMH) ? (par défaut oui si biblio brésilienne)
- Tags / appartenances multiples (FICEDL, RebAL, autres réseaux)

**Volet 9 — Données et confidentialité**
- Politique en complément du cadre RGPD/LGPD du réseau
- Durée de conservation des données d'emprunt après retour
- Partage de stats agrégées au réseau
- Gestion des consentements pour newsletters spécifiques
- Archivage des historiques de prêts

**Volet 10 — Génération du règlement**
- L'application génère un PDF pré-rempli avec tous les choix précédents (« squelette de règlement »)
- Le coordinateur·rice télécharge, fait valider en réunion collective, amende librement, et re-uploade comme document `regimento` officiel
- Tant que ce document n'est pas uploadé, la biblio reste pré-active

### 6.3 — Activation effective

À la complétion du volet 10 (PDF de règlement uploadé), la biblio passe en mode actif :
- Visible dans le catalogue commun (selon volet 8)
- Peut recevoir des inscriptions de lecteur·rices
- Le compte du·de la coordinateur·rice initial·e quitte l'état `coordenador_em_constituicao` et devient un compte standard rattaché (rôle `coordenador` sur cette biblio)

---

## 7. Notifications mail

### 7.1 — Stratégie d'envoi

**Mails relationnels** (ton chaleureux, ancré dans le projet) : confirmations, demandes de complément, validations, refus.

**Mails techniques** (courts et factuels) : rappels automatiques, notifications admin, confirmations de suppression.

**Pour les events admin** :
- **In-app temps réel** dans `/rede` : tous les events admin
- **Mail individuel à chaque admin** : uniquement les events critiques (`solicitacao_nova_admin`, `solicitacao_proposta_admin`, `solicitacao_complemento_resposta_admin`)
- **In-app uniquement** pour les events purement informationnels (`solicitacao_decisao_admin`)

### 7.2 — Cartographie des 16 events

#### Phase 1 — Inscription et soumission

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `signup_solicitante` | Solicitante | Inscription via `/criar-conta` sans biblio | Relationnel |
| `solicitacao_recebida` | Solicitante | Soumission du formulaire | Relationnel |
| `solicitacao_nova_admin` | Tous admins | Soumission du formulaire | Technique |

#### Phase 2 — Évaluation

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `solicitacao_complemento` | Solicitante | Admin demande complément | Relationnel |
| `solicitacao_complemento_resposta_admin` | Tous admins | Solicitante répond | Technique |
| `solicitacao_proposta_admin` | Autres admins | Admin propose décision | Technique |

#### Phase 3 — Décision finale

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `solicitacao_aprovada` | Solicitante | Acceptation confirmée | Relationnel |
| `solicitacao_recusada` | Solicitante | Refus confirmé | Relationnel |
| `solicitacao_decisao_admin` | Tous admins (in-app uniquement) | Décision finale | Technique |

#### Phase 4 — Rappels compte sans demande

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `solicitante_rappel_30j` | Solicitante | J+30 sans demande | Technique |
| `solicitante_rappel_60j` | Solicitante | J+60 sans demande | Technique |
| `solicitante_suppression_avis` | Solicitante | J+83 sans demande | Technique |
| `solicitante_supprime` | Solicitante | J+90, suppression effective | Technique |

#### Phase 5 — Parcours de constitution

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `constituicao_rappel_45j` | Coordinateur·rice | J+45 parcours non terminé | Technique |
| `constituicao_expiree` | Coord. + admins | J+60 parcours non terminé | Technique |

#### Phase 6 — Compte refusé

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `recusada_rappel_60j` | Solicitante refusée | J+60 après refus, pas de re-soumission | Technique |
| `recusada_supprime` | Solicitante refusée | J+90 après refus | Technique |

### 7.3 — Multilingue

Tous les mails sont disponibles dans les 6 locales du projet (pt-BR, fr, es, en, it, de). Les conventions linguistiques d'AnarBib s'appliquent (cf. notes internes : Genoss*in en allemand, compagno/a/e en italien, neutre *e* argentin en espagnol, triple form pt-BR).

---

## 8. Cas particuliers

### 8.1 — Multi-soumission concurrente

Deux personnes différentes soumettent indépendamment une demande pour la même biblio (cas typique : deux membres d'un même collectif qui n'ont pas coordonné leur démarche).

**Détection** : par les admins lors de l'évaluation, sur la base du nom de biblio, ville, contact email principal. Pas de détection automatique côté DB (trop de risque de faux positifs).

**Résolution** : la coordination met les deux demandes en `aguardando_info`, demande aux deux personnes de se concerter. Une seule sera retenue après concertation explicite (l'autre est marquée comme `cancelada` avec mention du lien).

### 8.2 — Re-soumission après refus

Une personne refusée resoumet une demande corrigée.

**Pas de cooldown ni de limite stricte** sur le nombre de re-soumissions. Si une demande est ressoumise à l'identique sans correction substantielle, l'admin peut utiliser la catégorie de refus `repeticao_sem_evolucao`.

### 8.3 — Solicitante qui décède ou disparaît pendant le parcours

Compte abandonné en cours de constitution. Géré automatiquement par les deadlines et rappels (J+45, J+60). Pas de mécanisme spécial requis.

### 8.4 — Solicitante qui veut annuler sa demande en cours

Action utilisateur·rice possible depuis `/conta`. Statut → `cancelada`. Le compte revient à l'état `solicitante_inicial` : la personne peut soumettre une nouvelle demande, ou laisser le compte expirer naturellement à J+90.

### 8.5 — Biblio acceptée mais coordinateur·rice initial·e se désiste

Cas complexe : la demande a été acceptée, mais pendant le parcours de constitution la personne coordinatrice initiale ne peut plus assumer.

**Possibilité de transfert du mandat** à un·e autre membre du collectif si on a son contact. Sinon, retour à un état d'attente jusqu'à ce que quelqu'un d'autre du collectif prenne le relais (action manuelle d'un admin).

**TODO** : cadrer plus finement le mécanisme de transfert technique. Ne sera implémenté qu'au moment du Lot 5.

---

## 9. Hors scope

- **Migration de compte entre biblios existantes** → `docs/spec-migration-compte.md`
- **Validation physique standard** (lecteur·rice s'inscrivant dans une biblio existante) → `docs/spec-validation-physique.md`
- **Promotion d'autres admins** (cooptation) → autre chantier à définir
- **Modification du règlement après création** (la biblio existe déjà, son règlement évolue) → workflow différent à cadrer plus tard
- **Fermeture définitive d'une biblio existante** → autre chantier (cf. spec migration pour le limbo des lecteur·rices)
- **Fusion de deux biblios** → cas exotique, à traiter ad hoc si jamais ça arrive

---

## 10. Checklist d'implémentation

**Stratégie retenue** : implémentation séquentielle stricte, lot par lot.

### Lot 1 — Schéma DB et états des comptes (fondation)

- [ ] Étendre `library_requests` avec les nouveaux statuts et champs (cf. 3.1)
- [ ] Créer `library_request_comments`
- [ ] Créer `library_request_messages`
- [ ] Ajouter `solicitante_state` sur `profiles`
- [ ] Créer `library_constitution_progress`
- [ ] Mettre en place RLS pour les 3 acteurs (solicitante / admin / public)
- [ ] Triggers DB pour transitions automatiques (création progress à acceptation, suppression compte à expiration)

### Lot 2 — Petits fixes UX préalables

- [ ] i18n complet de `SolicitarBibliotecaPage.jsx` (toutes chaînes en clés `useIntl`)
- [ ] Traductions × 6 locales pour `SolicitarBibliotecaPage`
- [ ] Remplacer les 2 liens `to="/cadastro"` résiduels par `to="/login"` (lignes 122 et 127)
- [ ] Wrapper `SolicitarBibliotecaPage` dans `<ProtectedRoute>`

### Lot 3 — UX `/conta` adaptative

- [ ] Détection de `solicitante_state` au chargement de `/conta`
- [ ] Onglet unique « Ma demande » dans tous les états sans biblio
- [ ] Bandeau adaptatif au top de la page selon l'état
- [ ] Bouton CTA `/solicitar-biblioteca` ostensible dans `solicitante_inicial`
- [ ] Récap statut + données soumises en `solicitante_pendente`
- [ ] Affichage motif refus + bouton « re-soumettre » en `solicitante_recusada`
- [ ] Lancement du wizard de constitution depuis `coordenador_em_constituicao`

### Lot 4 — Interface admin `/rede` section « Demandes d'adhésion »

- [ ] Vue liste avec filtres (statut, date, catégorie de refus)
- [ ] Vue détaillée d'une demande
- [ ] Actions individuelles : commenter, demander complément, proposer
- [ ] Actions à deux yeux : confirmer, objecter
- [ ] Mode dégradé seul·e admin (auto-confirmation si pas d'autre admin)
- [ ] Notifications in-app temps réel

### Lot 5 — Wizard de constitution (10 volets)

- [ ] Infrastructure du wizard (navigation, sauvegarde modulaire, deadline 60j)
- [ ] Volet 1 — Identité
- [ ] Volet 2 — Horaires et permanences
- [ ] Volet 3 — Personnes responsables (avec invitation email)
- [ ] Volet 4 — Politique de catalogage (**TODO** : choix libre vs liste fermée)
- [ ] Volet 5 — Politique de circulation
- [ ] Volet 6 — Politique d'adhésion lecteur·rice
- [ ] Volet 7 — Politique des e-mails
- [ ] Volet 8 — Visibilité et participation au réseau
- [ ] Volet 9 — Données et confidentialité
- [ ] Volet 10 — Génération du PDF de règlement
- [ ] Activation effective de la biblio à la fin du parcours

### Lot 6 — Notifications mail et automation

- [ ] 16 templates mail × 6 locales (32 × 6 = 96 templates en comptant ton relationnel/technique distinct selon mêmes events ? non, 16 × 6 = 96)
- [ ] Implémenter Edge Function de relance (cron quotidien) pour les rappels J+30/45/60/83/90
- [ ] Triggers DB pour events temps réel
- [ ] Système in-app de notifications admin pour `/rede`

---

## TODO ouverts (à arbitrer plus tard)

- **TODO 1** : Que se passe-t-il à l'expiration des 60 jours du parcours de constitution ?
  - Option a : avertissement à J+45, gel à J+60 (réveillable par admin)
  - Option b : avertissement à J+45, révocation à J+60 (compte → `solicitante_recusada`)
  - Option c : avertissement uniquement, jamais de gel auto
- **TODO 2** : Volet 4 (catalogage) — choix libre du système de classification ou liste fermée à définir collectivement ?
- **TODO 3** : Mécanisme technique de transfert du mandat coordinateur·rice (cas 8.5)

---

**Fin de la spec.**
