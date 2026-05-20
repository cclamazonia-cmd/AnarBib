# Spec — Onboarding d'une bibliothèque dans le réseau AnarBib

**Version** : 2.0 — 2026-05-20 (enrichissement post-clôture chantier profils + doctrine anti-méga-machine)
**Cible** : Bologna FICEDL, septembre 2026
**Auteur·rices** : Xavier (spec et arbitrages) + Claude (rédaction)
**Statut** : Cadrée le 05/05/2026 (v1.0), refondue le 15/05/2026 (v1.1), enrichie le 20/05/2026 (v2.0). **En attente d'implémentation pour les volets 1-10 (chantier #111, perspective Q3 2026)**. Le volet 0 a été livré le 19/05/2026 dans le cadre du chantier profils d'adoption (paquet F.3).

**Dépendances** :
  - **`docs/specs/spec-administrateur-reseau.md v0.4`** (v0.3.1 enrichie le 20/05 avec la doctrine anti-méga-machine + bouton « proposer un échange ») — workflow de gouvernance des administrateurs du réseau (cooptation unanime, retrait collectif). Cette spec onboarding utilise les admins réseau comme évaluateur·rices.
  - **`docs/specs/spec-gouvernance-roles.md v1.1`** (refonte 15/05/2026) — rôles locaux. À l'activation, le·la coordinateur·rice initial·e reçoit le rôle `coordenador` local de sa biblio.
  - **`docs/specs/spec-profils-bibliotheque-v0_7.md`** (clôture chantier 19/05/2026) — 4 axes orthogonaux de profil d'adoption. **Le volet 0 du wizard de constitution est livré en prod** sous forme du composant `LibraryProfileWizard.jsx` (330 lignes) intégré dans `SolicitarBibliotecaPage.jsx`.
  - **`docs/decisions/RIFLEXION_articulation_onboarding_profils_2026-05-20.md`** (345 lignes) — capture conversationnelle de la session marathon 19-20/05 qui a fait émerger la doctrine anti-méga-machine. Cette spec v2.0 intègre normativement la doctrine.
  - `docs/specs/spec-validation-physique.md` (à rédiger) — s'applique aux comptes lecteur·rice rattachés à une biblio existante
  - `docs/specs/spec-migration-compte.md` (940 lignes, cadrée 03/05/2026) — s'applique aux migrations entre biblios existantes (distinct du présent parcours)

**Historique** :
- v1.0 (05/05/2026) : première rédaction. Modèle 4 rôles (incluant `administrador` local), validation à deux yeux, 16 events mail, 10 volets de constitution, 6 lots d'implémentation.
- v1.1 (15/05/2026) : refonte cohérence. (a) Le rôle `administrador` local n'existe plus, remplacé par la table `network_administrators` (chantier clos 14/05). La « validation à deux yeux » est remplacée par le workflow politique de **cooptation unanime** des admins réseau (cohérence avec leur propre mode de fonctionnement). (b) Le wizard de constitution intègre un **volet 0** qui demande à la biblio en constitution de choisir son profil d'adoption parmi les 4 axes orthogonaux définis par la spec profils v0.3 (`catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode`). Les volets suivants sont alors **conditionnés** par les choix du volet 0.
- **v2.0 (20/05/2026)** : enrichissement doctrinal. (a) Intégration normative de la **doctrine anti-méga-machine** (§1.4 nouveau), actée pendant la session marathon de clôture du chantier profils (19-20/05). (b) Nouveau mécanisme « bouton proposer un échange » côté admins réseau (§5.7) pour rendre le canal humain proactif et pas seulement réactif. (c) Encadré canal humain dans chaque volet du wizard de constitution (§6.5). (d) Refonte doctrinale du volet 10 : le PDF de règlement est désormais positionné comme **artefact de délibération collective**, pas certificat technique (§6.6). (e) Section ouverte sur l'idée alternative d'un parcours d'entrée sur `anarbib.org` plutôt que sur `app.anarbib.org` (§6.7). (f) Scénario pédagogique Émile-Henry en annexe normative. (g) 2 nouveaux events mail (`onboarding.echange_propose_admin`, `onboarding.echange_accepte_solicitante`), passage de 17 à 19 events. (h) Nouveau Lot 7 dans la checklist d'implémentation pour les 5 items anti-méga-machine indépendants du chantier #111 (MM1-MM5 du backlog v8).

---

## Sommaire

1. [Contexte et objectif](#1-contexte-et-objectif)
2. [Modèle conceptuel](#2-modèle-conceptuel)
3. [Schéma DB](#3-schéma-db)
4. [UX dans `/conta` selon l'état du compte](#4-ux-dans-conta-selon-létat-du-compte)
5. [Workflow d'évaluation côté admins réseau](#5-workflow-dévaluation-côté-admins-réseau)
6. [Parcours obligatoire de constitution (volet 0 + 10 volets)](#6-parcours-obligatoire-de-constitution-volet-0--10-volets)
7. [Notifications mail](#7-notifications-mail)
8. [Cas particuliers](#8-cas-particuliers)
9. [Hors scope](#9-hors-scope)
10. [Checklist d'implémentation](#10-checklist-dimplémentation)

**Sections enrichies en v2.0** : §1.4 (doctrine anti-méga-machine), §5.7 (bouton « proposer un échange »), §6.5 (encadré canal humain par volet), §6.6 (PDF règlement comme artefact de délibération), §6.7 (parcours d'entrée sur anarbib.org — section ouverte), Annexe — Scénario Émile-Henry.

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

4. *(Refonte v1.1)* **Les administrateur·rices du réseau évaluent les demandes** sur la base d'un formulaire détaillé et de tout échange complémentaire jugé nécessaire. La décision est prise selon le workflow de cooptation unanime des admins réseau (cf. spec admin réseau v0.3.1 §4) : un·e admin propose l'acceptation ou le refus, les autres admins votent à l'unanimité (favorable / opposé avec rationale obligatoire / abstention). **Mode dégradé seul·e admin** : tant qu'il n'y a pas le quorum minimum de 3 admins réseau actifs (cas typique du démarrage en 2026), l'admin auto-confirme ses propres propositions, cohérent avec le workflow dormant de la spec admin réseau.

5. **Souveraineté de la bibliothèque créée** sur la définition de ses propres règles. Le wizard de constitution structure cette définition mais ne l'impose pas : chaque biblio choisit ses propres modalités dans le cadre AnarBib, **en commençant par son profil d'adoption** (cf. spec profils v0.3 et §6.2 volet 0 de cette spec).

6. *(Nouveau v1.1)* **Le profil d'adoption est l'acte fondateur du règlement**. La biblio en constitution choisit explicitement son `catalog_mode` (catalogage local-only ou network-published), son `circulation_mode` (off / informal / full_sigb), son `network_mode` (isolated / observer / federated), et son `governance_mode` (informal / staff_roles / full_governance). Ces choix conditionnent les volets suivants et le mode d'activation effective de la biblio.

7. *(Nouveau v2.0)* **Le SIGB est second, le canal humain est premier**. La complexité technique légitime d'AnarBib n'est jamais un prétexte pour faire disparaître les camarades de la fédération derrière une interface auto-suffisante. À chaque endroit où une décision configurante doit être prise, le collectif doit voir un canal humain disponible — pas un FAQ caché, pas un tooltip, mais un appel explicite à l'échange : « écris à `anarbib@proton.me` ou rejoins-nous sur Matrix `#anarbib:libreflux.fr` ». Voir §1.4 pour la doctrine complète.

---

## 1.4 *(Nouveau v2.0)* Doctrine anti-méga-machine

### 1.4.1 — Formulation politique

> Plus le SIGB grossit en complexité, plus le canal humain doit s'épaissir.
>
> La complexité technique légitime d'AnarBib (8-12 onglets sur Painel, autant sur Biblioteca, plus le catalogage à venir) n'est pas un signal qu'il faut **lisser l'UX au point de cacher cette complexité**, ni un signal qu'il faut **enterrer le collectif sous des manuels**. C'est un signal qu'il faut **rendre visibles les humains de la fédération** qui peuvent débroussailler.
>
> Le SIGB AnarBib n'est pas une plateforme téléphonique avec un sous-menu « parler à quelqu'un » caché au niveau 7. C'est une **fédération outillée par un SIGB**, dans laquelle le canal direct humain (email collectif, Matrix) est **premier** et le SIGB est **second**.

### 1.4.2 — Trois exigences qui en découlent

1. **Canal humain visible à chaque décision configurante.** À chaque endroit où le collectif doit prendre une décision qui engage durablement sa biblio (choix de profil, politique de circulation, politique d'adhésion, génération du règlement, transition entre profils), un encadré inline doit rendre visible le canal humain. Pas un FAQ, pas un tooltip, pas un footer générique — un appel explicite à l'échange préalable, positionné comme **égal** et non comme fallback.

2. **Jamais positionné comme fallback.** Le wording « si vous êtes vraiment perdu·e » est interdit. Le wording correct est « parlons-en avant de cliquer », « on peut en discuter ensemble », « écrivez-nous, on est là pour ça ». Le canal humain n'est pas une porte de secours ; c'est la porte principale, dont le SIGB est l'outil d'accompagnement.

3. **Les admins réseau sont des camarades, pas une hotline.** Cette doctrine est en cohérence avec la spec admin réseau v0.4 (qui en sera enrichie en miroir). Les admins réseau ne sont pas des modérateur·rices ou des technicien·nes : ce sont des camarades qui connaissent bien l'outil et qui sont là pour partager cette connaissance. Politique exactement opposée à une hotline.

### 1.4.3 — Articulation avec la spec onboarding v1.1

La v1.1 décrivait déjà un canal humain via mail au moment de l'évaluation (§5.4 : commentaires admins, demandes de complément, rationale de veto) et après refus (motif communiqué). Mais elle ne décrivait pas explicitement le canal humain :

- **Pendant** le parcours de constitution (volets 1-10) : un·e coordinateur·rice bloqué·e sur le volet 5 n'avait pas de bouton « appeler à l'aide » — la doctrine v2.0 (§6.5) y répond en imposant un encadré canal humain dans chaque volet.
- **Après activation** : la spec onboarding cesse de s'appliquer (la biblio est en régime normal), mais la doctrine continue de s'appliquer via les items MM1-MM5 du backlog v8 (footer global, encadrés inline sur Biblioteca, page `/conversemos`).
- **Pour les biblios existantes** : la doctrine s'applique via les items MM1, MM3, MM5 du backlog v8 (enrichissement banner G, encadrés inline, bandeau SolicitarBibliotecaPage).

La doctrine anti-méga-machine **complète** la spec onboarding v1.1 sans la contredire, en exigeant que le canal humain soit **constamment visible** et pas seulement au moment de l'évaluation initiale.

### 1.4.4 — Illustration par le scénario Émile-Henry

L'annexe normative de cette spec présente le scénario pédagogique Émile-Henry, repris du RIFLEXION du 19-20/05. Il montre concrètement pourquoi le canal humain visible n'est pas un luxe d'UX mais une condition de fonctionnement de la fédération pour des collectifs au caractère informel souvent prononcé.

---

## 2. Modèle conceptuel

### 2.1 — Acteurs en présence

Quatre types d'acteurs interviennent dans le parcours d'onboarding :

- **Le·la futur·e coordinateur·rice** : la personne qui s'inscrit comme lectrice et soumet la demande, mandatée par son collectif local.
- **Le collectif portant la biblio** : entité morale qui décide collectivement d'adhérer à AnarBib. Pas représenté techniquement dans le système, mais présent symboliquement (le formulaire demande de confirmer « représente une biblio réelle »).
- **Les administrateur·rices du réseau AnarBib** *(refonte v1.1)* : une ou plusieurs personnes inscrites dans la table `network_administrators` avec `status='active'`. Cooptées entre pair·e·s à l'unanimité (cf. spec admin réseau v0.3.1 §4). Évaluent et valident les demandes d'adhésion selon leur propre workflow politique.
- **Le réseau AnarBib** lui-même : entité collective qui accueille (ou non) la nouvelle biblio.

### 2.2 — États possibles d'un compte lecteur·rice sans bibliothèque

| État | Origine | Durée | Capacités |
|---|---|---|---|
| `solicitante_inicial` | Inscription via `/criar-conta` avec « Não encontrei minha biblioteca » | 90 jours max (cf. 2.4) | Catalogue commun en lecture, profil minimal éditable, accès au formulaire `/solicitar-biblioteca`. Pas de réservation, pas d'emprunt. |
| `solicitante_pendente` | A soumis le formulaire de demande | Variable (typiquement 7-14 jours pour évaluation) | Idem `solicitante_inicial`, plus suivi du statut de la demande. Plus d'accès en écriture au formulaire. |
| `solicitante_recusada` | Demande refusée par la coordination réseau | 90 jours puis suppression | Lecture seule + récap motif refus + possibilité de re-soumettre une demande corrigée. |
| `coordenador_em_constituicao` | Demande validée, parcours de règlement en cours | 60 jours puis gel ou révocation (TODO §10) | Accès au wizard de constitution. Pas encore reader actif. |
| `limbo_fechamento` | Sa biblio a fermé, en attente de migration | Limité (cf. spec migration) | **Hors scope de cette spec** |

**Note importante** : un état `sem_biblio_orphan` (compte sans biblio sans démarche active) est explicitement exclu par cette spec. Il doit être bloqué structurellement par les triggers DB et les contraintes UX. Pas de biblio possible sans engagement explicite dans une démarche d'adhésion.

### 2.3 — Conditions d'éligibilité pour soumettre une demande

**Règle UX (visible)** : le lien `/solicitar-biblioteca` n'apparaît dans `/conta` que pour les comptes en état `solicitante_inicial` (sans biblio rattachée et sans demande active).

**Règle backend (souple)** : la page `/solicitar-biblioteca` est accessible par URL directe et accepte les soumissions de toute personne authentifiée avec mot de passe modifié, indépendamment de son état de rattachement à une biblio.

Ce compromis (Option B des arbitrages) maintient la cohérence UX (les utilisateur·rices nominaux ne voient pas le lien) tout en autorisant des cas légitimes peu fréquents (un·e coordinateur·rice d'une biblio existante mandaté·e par son collectif pour faire la jonction avec une biblio sœur dans une autre ville).

Quand la demande est soumise par un·e utilisateur·rice rattaché·e à une biblio existante, ce contexte est visible des admins réseau lors de l'évaluation comme **information contextuelle**, pas comme obstacle.

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

### 2.6 — *(Refonte v1.1)* La coordination du réseau (admins réseau)

L'administration du réseau AnarBib est portée par la table `network_administrators` (cf. spec admin réseau v0.3.1 §3.1). Toute personne inscrite dans cette table avec `status='active'` est un·e administrateur·rice réseau actif·ve.

**Cooptation et retrait** : la cooptation et le retrait des admins réseau passent par les workflows politiques propres à cette spec sœur (cooptation à l'unanimité, retrait collectif à l'unanimité, auto-retrait unilatéral). Ces mécanismes sont **entièrement hors périmètre** de la spec onboarding.

**Évaluation des demandes d'adhésion** : pour qu'une demande d'adhésion d'une nouvelle biblio soit acceptée ou refusée, un·e admin réseau propose la décision, et les autres admins réseau actifs votent. La décision est validée à **l'unanimité** des admins ayant voté favorablement (cohérent avec le workflow des cooptations entre admins eux-mêmes).

**Mode dégradé « seul·e admin » ou < 3 admins** : tant qu'il n'y a pas le quorum minimum de 3 admins réseau actifs requis par la spec admin réseau, l'admin propose et **auto-confirme** ses propres propositions. C'est le cas typique du démarrage du réseau en 2026 (Xavier est seul admin actif au 14/05/2026, workflow dormant).

**Doctrine de divulgation** : par symétrie avec les votes de cooptation (cf. spec admin réseau §3.3.1, doctrine `disclose_identity`), chaque admin qui propose ou s'oppose à une demande d'adhésion choisit explicitement si son identité est révélée au·à la solicitante. Pas de DEFAULT. La rationale opposed reste affichée même si l'identité n'est pas révélée (anonymisation partielle).

### 2.7 — Catégories de refus

En cas de refus, l'admin réseau choisit une catégorie dans une liste fermée et peut compléter par un motif libre facultatif.

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
- `proposta_aprovacao` (un·e admin réseau a proposé l'acceptation)
- `proposta_recusa` (un·e admin réseau a proposé le refus)
- `aprovada` (acceptation confirmée à l'unanimité ou auto-confirmée en mode dégradé)
- `recusada` (refus confirmé à l'unanimité ou auto-confirmé en mode dégradé)
- `expirada` (demande expirée sans suite)
- `cancelada` (annulée par la personne solicitante)

Nouveaux champs *(actualisés v1.1)* :
- `proposed_by_admin_id` (UUID, FK profiles) — admin réseau ayant proposé
- `proposed_at` (timestamp)
- `proposed_decision` ('aprovacao' | 'recusa')
- `proposed_disclose_identity` (boolean, NOT NULL, **pas de DEFAULT**) — choix politique conscient du·de la proposeur·euse, cohérent avec doctrine R6 spec admin réseau
- `refusal_category` (enum cf. 2.7)
- `refusal_reason` (text, nullable)

**Note v1.1** : les anciens champs `confirmed_by_admin_id` / `confirmed_at` (single confirmation à deux yeux v1.0) sont remplacés par une **table de votes** symétrique à `network_administrator_cooptation_votes` (cf. spec admin réseau §3.3.1).

**Nouvelle table v1.1** : `library_request_votes`

Workflow de vote à l'unanimité des admins réseau, symétrique aux votes de cooptation.

```sql
CREATE TABLE public.library_request_votes (
  request_id uuid NOT NULL REFERENCES public.library_requests(id) ON DELETE CASCADE,
  voter_admin_id uuid NOT NULL REFERENCES public.network_administrators(user_id),
  vote text NOT NULL CHECK (vote IN ('favorable', 'opposed', 'abstain')),
  voted_at timestamptz NOT NULL DEFAULT now(),
  rationale text,
  disclose_identity boolean NOT NULL,  -- pas de DEFAULT, doctrine R6
  PRIMARY KEY (request_id, voter_admin_id),
  CONSTRAINT rationale_required_for_opposed CHECK (
    vote <> 'opposed' OR (rationale IS NOT NULL AND length(trim(rationale)) >= 20)
  )
);
```

**Nouvelle table** : `library_request_comments`

Commentaires admins réseau internes sur une demande, visibles uniquement par les admins.

```
- id (uuid, pk)
- request_id (uuid, fk library_requests)
- author_admin_id (uuid, fk profiles) — doit être admin réseau actif au moment de l'écriture
- content (text)
- created_at (timestamp)
```

**Nouvelle table** : `library_request_messages`

Échanges complément/réponse avec la personne solicitante.

```
- id (uuid, pk)
- request_id (uuid, fk library_requests)
- author_id (uuid, fk profiles) — admin réseau ou solicitante
- direction ('admin_to_solicitante' | 'solicitante_to_admin')
- content (text)
- created_at (timestamp)
- read_at (timestamp, nullable)
```

**Nouveau champ sur `profiles`** :

- `solicitante_state` (enum, nullable) : valeurs cf. 2.2. Null pour les comptes standards rattachés à une biblio.

**Nouvelle table** : `library_constitution_progress` *(actualisée v1.1 — ajout volet 0)*

Suit l'avancement du wizard de constitution pour une demande validée.

```
- id (uuid, pk)
- request_id (uuid, fk library_requests, unique)
- coordenador_id (uuid, fk profiles)
- started_at (timestamp)
- deadline_at (timestamp) — calculé à started_at + 60 jours
- completed_at (timestamp, nullable)
- volet_0_profil_done (boolean, default false) — v1.1 : choix du profil d'adoption
- volet_0_catalog_mode (text) — 'local_only' | 'network_published'
- volet_0_circulation_mode (text) — 'off' | 'informal' | 'full_sigb'
- volet_0_network_mode (text) — 'isolated' | 'observer' | 'federated'
- volet_0_governance_mode (text) — 'informal' | 'staff_roles' | 'full_governance'
- volet_1_identite_done (boolean, default false)
- volet_2_horaires_done (boolean, default false)
- volet_3_pessoas_done (boolean, default false)
- volet_4_catalogacao_done (boolean, default false) — conditionnel sur catalog_mode != 'local_only'
- volet_5_circulacao_done (boolean, default false) — conditionnel sur circulation_mode != 'off'
- volet_6_adhesion_done (boolean, default false)
- volet_7_emails_done (boolean, default false)
- volet_8_visibilidade_done (boolean, default false) — conditionnel sur network_mode != 'isolated'
- volet_9_dados_done (boolean, default false)
- volet_10_regimento_done (boolean, default false)
- regimento_pdf_url (text, nullable)
```

### 3.2 — RLS *(actualisé v1.1)*

- **Solicitantes** : voient leurs propres demandes (`submitted_by_user_id = auth.uid()`), leurs propres messages, leur propre `constitution_progress`. Ne voient pas les commentaires admins.
- **Admins réseau actifs** (`fn_caller_is_network_admin()` retourne TRUE) : voient toutes les demandes, tous les commentaires admins, tous les messages, tous les `constitution_progress`, tous les votes.
- **Public** : ne voit rien des `library_requests` (les demandes ne sont pas publiques).

**Note v1.1** : la RLS de la v1.0 mentionnait « `administrador` » directement. Avec la suppression du rôle `administrador` local au paquet F (13/05/2026), toutes les policies sont basculées sur `fn_caller_is_network_admin()` (helper centralisé). C'est cohérent avec le paquet C admin réseau (47 RLS alignées).

```sql
-- Exemple RLS sur library_requests
CREATE POLICY library_requests_solicitante_read
ON public.library_requests
FOR SELECT
TO authenticated
USING (submitted_by_user_id = auth.uid());

CREATE POLICY library_requests_admin_read
ON public.library_requests
FOR SELECT
TO authenticated
USING (public.fn_caller_is_network_admin());  -- v1.1
```

### 3.3 — Triggers

- À la transition `pendente` → `aprovada` : créer automatiquement un row dans `library_constitution_progress` avec deadline = now() + 60 days. **Le volet 0 est laissé en `done=false` :** le·la coordinateur·rice doit explicitement faire le choix de profil au début du wizard.
- À l'expiration deadline `solicitante_inicial` (90j) : trigger DB de suppression du compte (avec notification mail préalable).
- À l'expiration deadline `coordenador_em_constituicao` (60j) : à arbitrer (cf. TODO §10).
- À l'expiration deadline `solicitante_recusada` (90j) : suppression du compte.
- *(Nouveau v1.1)* À chaque INSERT dans `library_request_votes` : trigger `trg_check_request_unanimity` qui vérifie si tous les admins réseau actifs ont voté favorablement → transition automatique `proposta_aprovacao` → `aprovada` (ou `proposta_recusa` → `recusada`). Cohérent avec le mécanisme de la cooptation admin réseau.

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

Demande soumise, en cours d'évaluation par les admins réseau.

**UX** :
- Onglet unique « Ma demande »
- Bandeau persistant : « Votre demande est en cours d'évaluation par la coordination du réseau AnarBib. Vous serez notifié·e par email dès qu'une décision sera prise. Délai indicatif : 7-14 jours. »
- Récapitulatif des informations soumises (lecture seule)
- Section « Échanges avec la coordination » : affiche les éventuelles demandes de complément + interface de réponse
- Profil éditable en mode minimal

### 4.4 — État `solicitante_recusada`

Demande refusée, délai de grâce de 90 jours.

**UX** :
- Onglet unique « Ma demande »
- Bandeau : « Votre demande a été refusée. Vous pouvez soumettre une nouvelle demande corrigée, ou laisser le compte se supprimer automatiquement à J+90. »
- Section « Motif du refus » : affiche la catégorie + motif libre s'il existe + identité de l'opposant·e **si `disclose_identity=true`** (sinon anonymisée en « un·e administrateur·rice du réseau »)
- Bouton : « Soumettre une nouvelle demande corrigée » → `/solicitar-biblioteca` (réinitialise le statut à `solicitante_pendente`)
- Profil éditable en mode minimal

### 4.5 — État `coordenador_em_constituicao`

Demande validée, parcours de constitution en cours.

**UX** :
- Onglet unique « Constitution de ma bibliothèque »
- Bandeau : « Votre demande a été acceptée ! Complétez maintenant le choix de profil (volet 0) puis les volets de constitution applicables à votre profil. Délai : 60 jours. »
- **Wizard multi-étapes** détaillé en section 6 : commence par le volet 0 (profil), puis affiche dynamiquement les volets restants selon les choix du volet 0
- Possibilité de sauvegarder à tout moment et reprendre plus tard
- Indicateur de progression (X/N volets complétés où N dépend du profil choisi)
- Profil éditable en mode minimal

**Canal humain permanent *(nouveau v2.0)*** :

Un bandeau supplémentaire est affiché en permanence pendant tout le parcours de constitution, **distinct du wizard lui-même** et **non-fermable** (la doctrine anti-méga-machine §1.4.2 exigence 2 interdit que le canal humain soit positionné comme accessoire ou optionnel). Wording (pt-BR canonique, à traduire × 6 locales) :

> **On est là pour vous accompagner.**
> Cette constitution est un acte politique, pas seulement un formulaire administratif. À chaque étape, si vous voulez discuter de vos choix avec un·e camarade du réseau avant de cliquer : écrivez à **anarbib@proton.me** ou rejoignez-nous sur Matrix **#anarbib:libreflux.fr**. Vous pouvez aussi demander qu'un·e admin réseau vienne en discuter avec vous sur un appel collectif.
> **[Bouton secondaire : Demander un échange avec un·e admin réseau]** → ouvre un formulaire léger (sujet libre + date proposée) qui crée un événement `onboarding.echange_demande_solicitante` notifié à tous·tes les admins réseau actif·ves.

Ce bouton est le **symétrique côté solicitante** du bouton « Proposer un échange » côté admin réseau (cf. §5.7). Les deux mécanismes permettent l'initiation du dialogue dans les deux sens, sans hiérarchie.

---

## 5. Workflow d'évaluation côté admins réseau *(refonte v1.1)*

### 5.1 — Emplacement de l'interface

Section « Demandes d'adhésion » dans la page `/rede`. Visible uniquement par les admins réseau actifs (gated par `fn_caller_is_network_admin()`).

**Articulation v1.1 avec l'AdminsPanel** : la page `/rede` héberge déjà l'onglet « Administradores » livré au paquet E admin réseau, avec ses sections de cooptation et de retrait collectif. La section « Demandes d'adhésion » est un nouvel onglet **complémentaire**, dédié aux demandes externes (vs les votes internes admin réseau).

### 5.2 — Vue liste

- Demandes filtrables par statut, par date, par catégorie de refus (pour les archivées)
- Indicateur de priorité (demandes nouvelles, demandes attendant des votes, demandes en `aguardando_info` depuis longtemps)
- Compteur d'événements non lus

### 5.3 — Vue détaillée d'une demande

- Récapitulatif complet du formulaire soumis
- Contexte de l'utilisateur·rice (compte rattaché à une biblio existante ? si oui, laquelle ? depuis quand ?)
- Historique chronologique des actions (proposition, votes, commentaires, échanges avec la solicitante)
- Section commentaires admins (visibles uniquement entre admins réseau)
- Section échanges avec la solicitante (visibles des deux côtés)
- **Section votes en cours** *(nouveau v1.1)* : liste des admins réseau actifs avec leur statut de vote (favorable / opposé + rationale / abstention / pas encore voté)
- Boutons d'action selon l'état actuel et le statut de l'appelant·e

### 5.4 — Actions disponibles *(refonte v1.1)*

**Actions individuelles (un·e seul·e admin agit)** :
- **Commenter** : note interne admin (visible des autres admins réseau, pas de la solicitante)
- **Demander complément d'information** : envoie un mail à la solicitante, demande passe en `aguardando_info`
- *(Nouveau v2.0)* **Proposer un échange** : envoie un mail à la solicitante l'invitant à un échange (Matrix, appel, ou mail approfondi) sur sa demande ou son parcours de constitution. Détaillé en §5.7. Disponible aux deux moments charnières du parcours : (a) pendant l'évaluation d'une demande nouvelle (`pendente` ou `aguardando_info`) si l'admin estime qu'un dialogue ferait gagner du temps ; (b) pendant le parcours de constitution d'une biblio en `coordenador_em_constituicao` qui semble bloquée (par exemple sans progression depuis 14+ jours).
- **Proposer l'acceptation** : statut → `proposta_aprovacao`, attend votes des autres admins réseau ; le·la proposeur·euse vote automatiquement `favorable` avec `disclose_identity` choisi explicitement
- **Proposer le refus** : statut → `proposta_recusa`, avec catégorie obligatoire et motif optionnel ; le·la proposeur·euse vote automatiquement `favorable` (au refus) avec `disclose_identity` choisi

**Actions de vote à l'unanimité** *(refonte v1.1)* :
- **Voter favorable** : ajoute un vote `favorable` dans `library_request_votes` avec choix `disclose_identity`. Si tous les admins réseau actifs ont voté favorablement, trigger `trg_check_request_unanimity` passe la demande en `aprovada` (ou `recusada` selon la proposition initiale).
- **Voter opposé** : ajoute un vote `opposed` avec **rationale obligatoire ≥ 20 chars** + choix `disclose_identity`. Veto immédiat : la proposition repasse en `pendente`. Le·la proposeur·euse est notifié·e (mail individuel détaillant la rationale, anonymisée si `disclose_identity=false`).
- **Voter abstain** : ajoute un vote `abstain`. Bloque l'unanimité sans constituer un veto. L'abstention ne fait pas avancer la décision.

**Actions exceptionnelles** :
- **Annuler sa propre proposition** : possible tant qu'aucun·e admin n'a voté `opposed` et que l'unanimité n'est pas encore atteinte
- **Reprise d'une demande gelée** : un·e admin réseau peut « réveiller » une demande expirée (`aguardando_info` sans réponse, ou parcours de constitution expiré)

**Note** : la rationale (pour `opposed`) suit la même doctrine que celle du workflow cooptation admin réseau (cf. spec admin réseau §4.2.1, hard limit ≥ 20 chars).

### 5.5 — Mode dégradé « seul·e admin » ou < 3 admins

Tant que le quorum minimum de 3 admins réseau actifs n'est pas atteint (cas typique du démarrage en 2026), le mécanisme à l'unanimité est en **auto-confirmation** : l'admin propose une décision et la confirme immédiatement (pas de fenêtre de vote ouverte). C'est cohérent avec le workflow dormant des cooptations entre admins eux·elles-mêmes (cf. spec admin réseau §3.3.1 quorum minimum).

**Activation automatique** : dès qu'un·e troisième admin réseau est coopté·e, le mécanisme à l'unanimité s'active pour les nouvelles propositions. Les propositions en cours conservent leur mode initial pour éviter les confusions.

### 5.6 — Traçabilité

**À tracer obligatoirement** :
- Date et auteur·rice de chaque proposition (avec choix `disclose_identity`)
- Date et auteur·rice de chaque vote (avec choix `disclose_identity`)
- Date et contenu de chaque commentaire admin réseau
- Date et contenu de chaque demande de complément
- Date et contenu de chaque réponse de la solicitante
- *(Nouveau v2.0)* Date et auteur·rice de chaque « invitation à un échange » émise (que l'invitation soit acceptée ou non)
- *(Nouveau v2.0)* Date et contenu de chaque « demande d'échange » émise par une solicitante (symétrique du bouton admin)

**Visibilité** :
- Admins réseau actifs : voient l'intégralité (commentaires inclus, votes individuels avec identités si `disclose_identity=true`, anonymisés sinon)
- Solicitantes : voient leurs soumissions, demandes de complément, statut final + catégorie + motif si fourni + rationale opposed anonymisée ou nominale selon `disclose_identity`
- Public : aucun accès

### 5.7 — *(Nouveau v2.0)* Canal humain proactif : « Proposer un échange »

**Doctrine** : la doctrine anti-méga-machine §1.4.2 exigence 1 impose un canal humain visible à chaque décision configurante. Mais elle implique aussi un **canal proactif** côté admins réseau : il ne suffit pas que la solicitante puisse appeler à l'aide, il faut que les admins réseau puissent **initier** le dialogue quand ils·elles voient qu'un collectif est bloqué.

C'est l'objet de cette section : décrire le mécanisme « Proposer un échange » qui rend ce canal proactif explicite, traçable et politiquement assumé.

#### 5.7.1 — Quand l'utiliser

Trois moments-types où un·e admin réseau peut estimer qu'un échange ferait gagner du temps :

1. **Demande nouvelle en `pendente` ou `aguardando_info` depuis > 7 jours**, avec un formulaire qui semble révéler une incompréhension du modèle AnarBib (par exemple : profil D coché par défaut alors que les autres champs suggèrent un fonctionnement plus informel). Proposer un échange avant de voter `opposed` ou de demander un complément formel.

2. **Parcours de constitution `coordenador_em_constituicao` sans progression depuis 14+ jours**. Le·la coordinateur·rice semble bloqué·e (peut-être sur le volet 5 « politique de circulation » qui demande des choix techniques engageants). Proposer un échange avant que la deadline 60 jours ne se rapproche.

3. **Volet 0 (profil d'adoption) complété d'une manière qui semble incohérente avec le récit de la demande**. Par exemple : profil A pré-câblé alors que le formulaire mentionne « on prête nos livres en chuchotant pendant les réunions et on note ça sur un cahier » (cas Émile-Henry, cf. annexe). Proposer un échange pour traduire la pratique réelle en quadruplet d'axes.

#### 5.7.2 — Mécanique technique

**Table dédiée** : `library_request_invitations`

```sql
CREATE TABLE public.library_request_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES library_requests(id) ON DELETE CASCADE,
  invited_by_user_id uuid NOT NULL REFERENCES profiles(id),
  invited_by_kind text NOT NULL CHECK (invited_by_kind IN ('admin', 'solicitante')),
  -- 'admin' : admin réseau invite la solicitante
  -- 'solicitante' : solicitante demande un échange aux admins réseau (cf. §4.5)
  subject text NOT NULL CHECK (length(trim(subject)) >= 10),
  message text,
  proposed_channel text CHECK (proposed_channel IN ('matrix', 'mail', 'call', 'libre')),
  proposed_dates jsonb DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'completed', 'expired')),
  response_message text,
  responded_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
```

**RPC publiques** :
- `api.fn_propose_request_exchange(p_request_id uuid, p_subject text, p_message text, p_proposed_channel text, p_proposed_dates jsonb)` — utilisable par un·e admin réseau actif·ve ou par la solicitante elle-même (selon `auth.uid()`). Crée l'invitation et déclenche l'event mail correspondant.
- `api.fn_respond_request_exchange(p_invitation_id uuid, p_response text, p_response_message text)` — l'invité·e accepte/refuse, transition de statut, mail de réponse à l'auteur·rice de l'invitation.
- `api.fn_mark_request_exchange_completed(p_invitation_id uuid, p_summary text)` — l'admin marque l'échange comme effectué et résume ce qui en est ressorti (visible des admins réseau seulement).

#### 5.7.3 — Workflow

1. Admin réseau clique « Proposer un échange » sur une demande
2. Modal s'ouvre : sujet (champ obligatoire, min 10 chars), message libre, canal proposé (Matrix / mail / appel / libre), dates proposées (optionnel)
3. À la soumission : INSERT dans `library_request_invitations` + event `onboarding.echange_propose_admin` créé dans l'outbox + fan-out par `notify-event` → mail à la solicitante
4. La solicitante reçoit le mail, clique sur le lien : page dédiée `/conta/echange/{invitation_id}` qui affiche le détail et propose d'accepter (avec contre-proposition de date possible) ou de décliner avec un mot
5. Sa réponse génère un mail retour aux admins réseau (event `onboarding.echange_reponse_solicitante`)
6. Une fois l'échange effectué, un·e admin marque l'échange complété avec un résumé interne admin (visible des autres admins, pas de la solicitante)

**Symétrique côté solicitante** : la solicitante peut elle aussi cliquer « Demander un échange » depuis son `/conta` (cf. §4.5). Le mécanisme est identique, juste `invited_by_kind = 'solicitante'`. La doctrine anti-méga-machine §1.4.2 exigence 2 impose qu'aucun des deux côtés ne soit positionné comme fallback ; les deux directions du dialogue sont des égales.

#### 5.7.4 — UI côté admin réseau

Dans la vue détaillée d'une demande (§5.3), un nouveau bouton secondaire **« Proposer un échange »** est placé en haut de la zone d'actions, **avant** les actions de proposition/vote. Cette position est politique : on suggère le dialogue *avant* la formalisation de la délibération.

Section « Historique chronologique » enrichie pour afficher les invitations émises, leur statut et les résumés post-échange.

#### 5.7.5 — Cohérence avec la spec admin réseau

Cette section est en miroir d'une section équivalente à ajouter dans la spec admin réseau v0.4 (qui sera produite séparément ce soir). Les deux specs se renvoient l'une à l'autre :
- Cette spec onboarding décrit le mécanisme **spécifique aux demandes externes** (relations admins réseau ↔ solicitantes)
- La spec admin réseau v0.4 décrira un mécanisme **équivalent pour les biblios membres** (relations admins réseau ↔ coordenadores de biblios existantes en difficulté, par exemple pour les transitions de profil)

Les deux mécanismes partagent la même doctrine anti-méga-machine §1.4 et le même pattern technique (table `*_invitations`, RPC `fn_propose_exchange`, event mail dédié).

**Conservation** :
- Demandes acceptées : conservées indéfiniment
- Demandes refusées : 90 jours après le refus puis archivées en mode anonymisé (statistiques préservées, données personnelles supprimées)

---

## 6. Parcours obligatoire de constitution (volet 0 + 10 volets) *(refonte v1.1)*

### 6.1 — Forme du parcours

**Modulaire avec deadline 60 jours**, démarrant obligatoirement par le **volet 0** (choix du profil d'adoption).

La personne peut sauvegarder à n'importe quel moment et revenir plus tard. La progression est visible (X/N volets complétés où N dépend du profil choisi au volet 0). Un rappel mail est envoyé à J+45.

À J+60 sans complétion : **TODO** (cf. §10) — gel, révocation ou avertissement seul.

Tant que les volets applicables ne sont pas tous complétés, la biblio reste en mode **pré-actif** : pas visible dans le catalogue commun, ne reçoit pas de lecteur·rices.

### 6.2 — *(Nouveau v1.1)* Volet 0 — Choix du profil d'adoption

**Doctrine** : ce volet est obligatoire et précède tous les autres. Il définit les 4 axes orthogonaux qui détermineront quels volets suivants sont applicables.

Référence : `docs/specs/spec-profils-bibliotheque.md v0.3`. Cette spec définit 3 profils-types A/C, B, D et la doctrine des transitions entre profils. Le volet 0 est l'**acte d'engagement initial** : le collectif choisit explicitement où se placer sur chaque axe, avec la possibilité de migrer ultérieurement selon les doctrines de transition.

**Les 4 axes à choisir** :

**Axe 1 — `catalog_mode`** :
- `local_only` : le catalogue de la biblio reste local, pas exposé au réseau (utile pour une biblio en phase de rodage ou avec un fonds sensible non encore prêt à être publié)
- `network_published` : le catalogue est exposé dans le catalogue commun AnarBib (mode standard)

**Axe 2 — `circulation_mode`** :
- `off` : la biblio ne gère pas de circulation dans le SIGB (uniquement catalogue + consultations sur place sans tracking ; cas typique d'une bibliothèque-musée ou d'un fonds patrimonial purement consultatif)
- `informal` : circulation simple, sans cotisations ni règles strictes (cas typique d'une petite biblio militante où on se connaît tous·tes)
- `full_sigb` : circulation complète avec règles, cotisations, suspensions, etc. (mode standard SIGB)

**Axe 3 — `network_mode`** :
- `isolated` : pas d'interaction inter-biblios via le SIGB (la biblio existe dans AnarBib mais ne participe pas aux échanges)
- `observer` : reçoit les flux mais ne contribue pas (passivement intégrée)
- `federated` : pleinement intégrée, contribue et reçoit (mode standard)

**Axe 4 — `governance_mode`** :
- `informal` : pas de rôles staff distincts. Tout le monde est `reader`. Pas de cooptation, pas de carence, pas d'audit log. Cf. spec gouvernance v1.1 §1.4.
- `staff_roles` : rôles `librarian` + `coordenador` actifs, cooptation simplifiée. Pas de cycle carence/suspension/audit log complet.
- `full_governance` : doctrine intégrale de la spec gouvernance v1.1 (carence 7j, audit log, notifications systématiques, crons actifs)

**UI** : pour chaque axe, présenter une explication militante des 3 options (avec exemples concrets de biblios qui choisiraient chaque option), un bouton de sélection unique, et un récap final avant validation. La personne peut revenir sur ses choix tant que les volets ultérieurs ne sont pas commencés.

**Conséquence sur les volets suivants** :
- Si `catalog_mode = 'local_only'` : volet 8 (visibilité réseau) simplifié (la biblio n'apparaît pas au catalogue commun, choix limité)
- Si `circulation_mode = 'off'` : **volet 5 sauté** (politique de circulation sans objet)
- Si `circulation_mode = 'informal'` : volet 5 simplifié (pas de cotisations)
- Si `network_mode = 'isolated'` : **volet 8 sauté** (visibilité réseau sans objet)
- Si `governance_mode = 'informal'` : volet 3 simplifié (pas de rôles staff distincts à définir)

### 6.3 — Les volets 1-10 *(conservés v1.0 avec ajustements de conditionnalité)*

**Volet 1 — Identité de la bibliothèque** *(toujours obligatoire)*
- Nom complet, sigle/nom court, logo
- Description publique (texte affiché aux visiteurs anonymes)
- Adresse physique
- Coordonnées de contact (email, téléphone)
- Réseaux sociaux et sites externes (optionnel)

**Volet 2 — Horaires et permanences** *(toujours obligatoire)*
- Jours et heures d'ouverture
- Modalités de présence physique (permanences fixes, sur rendez-vous, etc.)
- Exceptions saisonnières (fermetures vacances, événements)

**Volet 3 — Personnes responsables** *(conditionnel selon governance_mode)*
- Coordinateur·rice principal·e (la personne qui fait la démarche, par défaut)
- Si `governance_mode = 'staff_roles'` ou `'full_governance'` : possibilité d'ajouter d'autres coordinateurs/librarians par invitation email + définition des rôles dans l'équipe initiale
- Si `governance_mode = 'informal'` : champ simplifié « personnes engagées dans le projet » (sans rôles staff distincts)

**Volet 4 — Politique de catalogage** *(toujours obligatoire mais paramétré par catalog_mode)*
- Système de classification (Dewey, CDU, classification anarchiste à définir collectivement, custom)
- Normes bibliographiques utilisées
- Règles d'indexation spécifiques à la biblio
- Si `catalog_mode = 'network_published'` : alignement avec les conventions de catalogage du réseau (validation par les admins lors de la publication)

**TODO** : décider si liste fermée ou choix libre. Choix libre risque d'incohérence du catalogue commun ; liste fermée nécessite un travail amont de catégorisation collective.

**Volet 5 — Politique de circulation** *(conditionnel — sauté si circulation_mode = 'off')*
- Modèle de prêt : durée par défaut, nombre max d'emprunts simultanés, possibilité de prolongation
- Modèle de réservation : oui/non, durée de la réservation, comportement en cas de no-show
- Consultation sur place : autorisée ou non, conditions (cohérent avec spec consultas v2.1)
- Service mode par défaut (`funcionamento_normal`, `somente_consulta`, etc.)
- Si `circulation_mode = 'informal'` : version simplifiée (pas de cotisations, pas de suspensions)

**Volet 6 — Politique d'adhésion lecteur·rice** *(conditionnel selon governance_mode et circulation_mode)*
- Mode physique : `aberto` (n'importe qui peut s'inscrire) ou `validacao_manual` (rencontre obligatoire)
- Cotisation : oui/non, montants suggérés, périodicité (n'apparaît que si `circulation_mode = 'full_sigb'`)
- Règlement spécifique à signer à l'inscription (oui/non, document à uploader)

**Volet 7 — Politique des e-mails** *(toujours obligatoire)*
- Adresse expéditrice (par défaut générique AnarBib, ou custom propre à la biblio)
- Templates personnalisés (oui/non, ou hérités du défaut)
- Signature au pied des mails (logo, devise, horaires)

**Volet 8 — Visibilité et participation au réseau** *(conditionnel — sauté si network_mode = 'isolated')*
- Visible dans le catalogue commun ? (par défaut oui si `network_mode = 'federated'`)
- Participe à RebAL (harvesting OAI-PMH) ? (par défaut oui si biblio brésilienne et `network_mode = 'federated'`)
- Tags / appartenances multiples (FICEDL, RebAL, autres réseaux)

**Volet 9 — Données et confidentialité** *(toujours obligatoire)*
- Politique en complément du cadre RGPD/LGPD du réseau
- Durée de conservation des données d'emprunt après retour (sans objet si `circulation_mode = 'off'`)
- Partage de stats agrégées au réseau (sans objet si `network_mode = 'isolated'`)
- Gestion des consentements pour newsletters spécifiques
- Archivage des historiques de prêts (sans objet si `circulation_mode = 'off'`)

**Volet 10 — Génération du règlement** *(toujours obligatoire)*
- L'application génère un PDF pré-rempli avec tous les choix précédents (« squelette de règlement »), y compris le profil choisi au volet 0
- Le coordinateur·rice télécharge, fait valider en réunion collective, amende librement, et re-uploade comme document `regimento` officiel
- Tant que ce document n'est pas uploadé, la biblio reste pré-active

### 6.4 — Activation effective *(actualisée v1.1)*

À la complétion du volet 10 (PDF de règlement uploadé), la biblio passe en mode actif :
- Le profil d'adoption choisi au volet 0 est inscrit dans `libraries.catalog_mode`, `libraries.circulation_mode`, `libraries.network_mode`, `libraries.governance_mode` (champs DB à créer par le paquet A spec profils)
- Visible dans le catalogue commun selon les volets 8 et 0 (`catalog_mode` + `network_mode`)
- Peut recevoir des inscriptions de lecteur·rices selon `circulation_mode` et `governance_mode`
- Le compte du·de la coordinateur·rice initial·e quitte l'état `coordenador_em_constituicao` et devient un compte standard rattaché (rôle `coordenador` sur cette biblio, cohérent avec spec gouvernance v1.1)
- Les mécanismes activés (cooptation staff local, audit log, crons de carence, etc.) sont conditionnés par `governance_mode` (cf. spec gouvernance v1.1 §1.4)

### 6.5 — *(Nouveau v2.0)* Encadré canal humain dans chaque volet

**Doctrine** : la doctrine anti-méga-machine §1.4.2 exigence 1 impose un canal humain visible à chaque décision configurante. Chaque volet du wizard de constitution est une telle décision. Donc chaque volet doit comporter un encadré canal humain.

#### 6.5.1 — Composant frontend

Un composant React partagé `<HumanChannelInlineCallout volet={voletId} />` doit être créé et intégré dans chaque volet du wizard. Il affiche :

- Une accroche en gras, contextuelle au volet (cf. ci-dessous le wording par volet)
- Le canal mail `anarbib@proton.me` (cliquable, ouvre le client mail)
- Le canal Matrix `#anarbib:libreflux.fr` (cliquable, ouvre Element web ou l'app Matrix installée)
- Un bouton secondaire **« Demander un échange »** qui appelle la RPC `api.fn_propose_request_exchange` (côté solicitante) en pré-remplissant le sujet avec le nom du volet

**Position dans le volet** : en haut du volet, **avant** les champs à remplir. Pas en bas, pas en footer. La doctrine §1.4.2 exigence 2 impose que le canal humain ne soit pas positionné comme accessoire.

**Comportement** : non-fermable. La doctrine §1.4.2 interdit que le collectif puisse « cacher » le canal humain — il doit rester visible tant que le volet est ouvert.

#### 6.5.2 — Wording par volet (pt-BR canonique, à traduire × 6 locales)

**Volet 0 — Choix du profil d'adoption** :

> **Esse volet é o ato fundador da sua biblioteca no AnarBib.**
> Os 4 eixos que você vai escolher determinam como sua biblio funcionará. Eles podem ser modificados depois, mas com um processo coletivo. Antes de clicar, conversemos: **anarbib@proton.me** ou Matrix **#anarbib:libreflux.fr**. A gente pode te ajudar a traduzir o funcionamento real do seu coletivo em eixos.
> [Pedir uma conversa com um·a admin da rede]

**Volet 1 — Identité** : encadré court, accroche plus légère (le volet est peu configurant) :

> **Identidade da biblio.**
> Tudo aqui é modificável depois. Mas se você quer conversar sobre a forma como vai apresentar sua biblio publicamente (nome, descrição, etc.), escreva pra gente: **anarbib@proton.me**.

**Volet 2 — Horaires** : encadré court :

> **Horários e permanências.**
> Sua biblio pode ter funcionamentos atípicos (reuniões hebdo, presença sob demanda, etc.). Se você não tem certeza de como representar isso aqui, conversemos: **anarbib@proton.me**.

**Volet 3 — Personnes responsables** : encadré contextuel :

> **As pessoas que se engajam.**
> Sua biblio é informal (`governance_mode = 'informal'`)? Você não precisa nomear coordenador·a/librarian. Mas se você está em dúvida sobre como representar o coletivo, conversemos: **anarbib@proton.me** ou Matrix **#anarbib:libreflux.fr**.
> [Pedir uma conversa com um·a admin da rede]

**Volet 4 — Politique de catalogage** : encadré contextuel :

> **A política de catalogação é uma decisão política.**
> Que sistema de classificação? Que normas? Como nomear os autores·as autônomos·as? Essas decisões engajam o coletivo de longa duração. Antes de clicar, conversemos: **anarbib@proton.me**.
> [Pedir uma conversa com um·a admin da rede]

**Volet 5 — Politique de circulation** : encadré fort :

> **Aqui você define como os livros circulam.**
> Empréstimo? Consulta no local? Cotação? Reservas? Essas decisões mudam profundamente a relação entre sua biblio e os leitor·as. Antes de clicar, conversemos com um·a camarada da rede: **anarbib@proton.me**.
> [Pedir uma conversa com um·a admin da rede]

**Volet 6 — Politique d'adhésion lecteur·rice** : encadré contextuel.

**Volet 7 — Politique des e-mails** : encadré court.

**Volet 8 — Visibilité réseau** : encadré court.

**Volet 9 — Données et confidentialité** : encadré fort, lié à la RGPD/LGPD :

> **Dados pessoais é um terreno político.**
> Você vai conservar quais dados sobre seus·suas leitor·as? Por quanto tempo? Você sabe a regulação aplicável (LGPD se você é no Brasil, RGPD se você é na Europa)? A rede AnarBib tem um quadro mínimo mas você pode (e deve) reforçá-lo. Antes de clicar, conversemos: **anarbib@proton.me**.
> [Pedir uma conversa com um·a admin da rede]

**Volet 10 — Génération du règlement** : encadré spécifique (cf. §6.6) :

> **O regulamento que você vai gerar aqui é um esqueleto. Ele tem que ser discutido em assembleia.**
> Não é um certificado de conclusão técnica do wizard. É um documento político que sua biblio se dá. Se você quer que a gente releia o esqueleto antes da assembleia, escreva: **anarbib@proton.me**.
> [Pedir uma conversa com um·a admin da rede]

#### 6.5.3 — i18n

Le composant `<HumanChannelInlineCallout>` doit être traduit en 6 locales (pt-BR, fr, es, en, it, de) selon la convention inclusive établie pour le projet. Estimation : ~11 clés (1 par volet + 1 commune) × 6 locales = ~66 strings militantes.

#### 6.5.4 — Articulation avec MM3

Cette section est étroitement liée à l'item MM3 du backlog v8 (« Encadrés inline 'parlons-en avant' sur pages Biblioteca sensibles »). La différence est de portée :
- MM3 cible les pages **Biblioteca** d'une biblio en régime normal (gouvernance, profil, transitions, regimento)
- Cette §6.5 cible le **wizard de constitution** d'une biblio en formation

Les deux peuvent partager le même composant `<HumanChannelInlineCallout>` (avec un paramètre `context` qui détermine le wording). Cohérence d'implémentation à viser.

### 6.6 — *(Nouveau v2.0)* Le PDF règlement comme artefact de délibération collective

**Doctrine** : le PDF de règlement généré au volet 10 n'est **pas un certificat de complétion technique du wizard**. C'est un **artefact de délibération collective** que la biblio se donne. Cette doctrine doit être rendue visible dans le wording du volet 10 et dans le PDF lui-même.

#### 6.6.1 — Reformulation du volet 10

Le volet 10 actuel (cf. §6.3) dit : *« L'application génère un PDF pré-rempli avec tous les choix précédents (« squelette de règlement »), y compris le profil choisi au volet 0. Le coordinateur·rice télécharge, fait valider en réunion collective, amende librement, et re-uploade comme document `regimento` officiel »*.

Ce wording est techniquement correct mais doctrinalement insuffisant. Refonte v2.0 :

> **Volet 10 — Génération du squelette de règlement** *(toujours obligatoire)*
>
> Vous arrivez à la fin du parcours de constitution. AnarBib va générer un **squelette de règlement** qui reprend tous vos choix précédents (profil, identité, horaires, politiques, etc.). Ce document est un point de départ — **pas un point d'arrivée**.
>
> Voici ce que vous devez faire avec :
>
> 1. **Téléchargez-le** et lisez-le attentivement.
> 2. **Discutez-le en assemblée** avec votre collectif. C'est un document politique que vous vous donnez collectivement, pas un formulaire administratif à valider d'un clic.
> 3. **Amendez-le librement.** Vous pouvez modifier ce qu'AnarBib a généré automatiquement — c'est même attendu. Le réseau respecte la souveraineté de chaque biblio sur son règlement.
> 4. **Re-uploadez la version finale** quand votre collectif l'a validée.
>
> Si vous voulez qu'un·e camarade du réseau relise votre squelette avant l'assemblée, écrivez à **anarbib@proton.me**. On est là pour ça.
>
> Tant que le PDF amendé n'est pas re-uploadé, votre biblio reste en mode **pré-actif** : pas visible au catalogue, ne reçoit pas de lecteur·rices. Mais il n'y a pas de précipitation — prenez le temps de discuter collectivement.

#### 6.6.2 — Contenu du PDF généré

Le PDF généré doit refléter la doctrine § 6.6. En particulier :

- **Page de garde** : titre « Squelette de règlement de la bibliothèque {nom} » + sous-titre **« document à discuter en assemblée — pas un règlement final »**
- **Préambule** : court paragraphe expliquant que ce document est généré par AnarBib comme aide à la constitution, mais que **toute amendement collectif est légitime et attendu**
- **Sections** : reprises des volets 1-9 dans l'ordre, avec mention explicite de chaque choix de profil (volet 0)
- **Pied de page** de chaque section : marque « [À DISCUTER] » subtile pour rappeler le statut de squelette
- **Annexe finale** : section « Modifications collectives apportées en assemblée » initialement vide, à remplir par le coordinateur·rice après assemblée

#### 6.6.3 — Articulation avec MM2 (footer global)

Indépendamment de la doctrine §6.6, le footer global persistant (MM2 du backlog v8) doit aussi apparaître sur la page de génération du PDF du volet 10, rappelant le canal humain.

### 6.7 — *(Nouveau v2.0)* Section ouverte : parcours d'entrée sur `anarbib.org` plutôt que `app.anarbib.org`

**Statut** : section **ouverte**, c'est-à-dire qu'elle décrit une idée à creuser au moment du chantier #111, sans engagement définitif. Repris du RIFLEXION §4.4.

#### 6.7.1 — L'idée

Aujourd'hui, le parcours d'inscription d'une nouvelle biblio se déroule entièrement dans l'app `app.anarbib.org` :
- Page `/criar-conta` (création de compte)
- Page `/solicitar-biblioteca` (formulaire de demande)
- Page `/conta` (suivi du statut, wizard de constitution)

Cette concentration sur l'app a un effet de bord politique : **elle expose le futur collectif à la complexité technique de l'outil avant même qu'il·elle ait compris le projet politique**. Une personne curieuse arrive sur `app.anarbib.org`, voit une interface de SaaS-pour-bibliothèques (formulaires, login, sélecteurs de pays, etc.), et peut se sentir intimidée.

L'idée alternative : **déplacer le chemin éditorial vers `anarbib.org`** (le site militant 6 locales, plus simple, avec sa charte explicite et ses portes d'entrée différenciées), et ne garder dans `app.anarbib.org` que le **formulaire technique** une fois la décision politique d'adhérer prise.

#### 6.7.2 — Articulation avec la doctrine anti-méga-machine

Cette idée est cohérente avec la doctrine §1.4 : en plaçant le chemin éditorial sur le site militant, on **rend plus naturel le canal humain comme porte d'entrée première**. Le visiteur·euse découvre :

1. La charte AnarBib (`anarbib.org/charte`)
2. Une page d'invitation à l'échange humain (`anarbib.org/conversemos`, équivalent du MM4 backlog v8)
3. Une intuition du fonctionnement de la fédération (qui sont les biblios membres, quelle gouvernance, etc.)
4. **Seulement à la fin du chemin éditorial**, un lien vers le formulaire `app.anarbib.org/solicitar-biblioteca`

Cette progression respecte la doctrine : le SIGB ne se présente qu'**après** que le canal humain et la compréhension politique ont eu lieu. Le SIGB est l'outil, pas la porte.

#### 6.7.3 — Points à trancher au moment du chantier #111

- Comment articuler les 6 locales d'`anarbib.org` avec les 6 locales d'`app.anarbib.org` (cohérence de translation) ?
- Faut-il maintenir le formulaire `/solicitar-biblioteca` dans l'app, ou le déplacer aussi sur `anarbib.org` (dans ce cas comment authentifier la soumission) ?
- Comment gérer la transition : faut-il un redirect doux depuis `/criar-conta` vers `anarbib.org/comment-rejoindre-anarbib` ?
- Quelle place donner à `app.anarbib.org/criar-conta` réécrit (cas Karina, cf. `spec-onboarding-criar-conta.md`) dans cette nouvelle architecture ?

À discuter collectivement au moment du cadrage du chantier #111 (Q3 2026).

#### 6.7.4 — Décision de cette spec v2.0

Cette spec **n'engage pas** la migration éditoriale sur `anarbib.org` — elle l'inscrit comme idée à examiner. La doctrine anti-méga-machine s'applique de toute façon **avec ou sans** cette migration : les enrichissements §6.5 (encadrés canal humain) et §6.6 (PDF règlement comme artefact) sont valables que le parcours reste dans l'app ou pas.

---

## 7. Notifications mail

### 7.1 — Stratégie d'envoi *(actualisée v1.1)*

**Mails relationnels** (ton chaleureux, ancré dans le projet) : confirmations, demandes de complément, validations, refus.

**Mails techniques** (courts et factuels) : rappels automatiques, notifications admin réseau, confirmations de suppression.

**Pour les events admin réseau** :
- **In-app temps réel** dans `/rede` : tous les events admin réseau
- **Mail individuel à chaque admin réseau actif** : les events critiques (`solicitacao_nova_admin`, `solicitacao_proposta_admin`, `solicitacao_voto_intermediario_admin`, `solicitacao_complemento_resposta_admin`)
- **In-app uniquement** pour les events purement informationnels (`solicitacao_decisao_admin`)

**Doctrine de notification du proposeur (v1.1, héritée de la spec admin réseau §4.2.4)** : le·la proposeur·euse d'une décision (acceptation ou refus) est notifié·e individuellement uniquement au **premier vote intermédiaire** (signal politique de démarrage de la délibération), puis reste silencieux·euse jusqu'au résultat final. Les rappels J+14/J+25 (si activés) prennent ensuite le relais si la délibération stagne. Cohérent avec la doctrine R1 de la spec admin réseau.

**Pattern d'INSERT outbox (v1.1, héritée de la spec admin réseau §4.2)** : un INSERT par event dans `team_notification_outbox`, fan-out par l'Edge Function `notify-event`. Les events de cette spec onboarding utilisent le préfixe `onboarding.*` pour ne pas se confondre avec `team.*` (gouvernance locale) ni `network.*` (admin réseau interne).

### 7.2 — Cartographie des 16 events *(actualisée v1.1)*

#### Phase 1 — Inscription et soumission

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `onboarding.signup_solicitante` | Solicitante | Inscription via `/criar-conta` sans biblio | Relationnel |
| `onboarding.solicitacao_recebida` | Solicitante | Soumission du formulaire | Relationnel |
| `onboarding.solicitacao_nova_admin` | Tous admins réseau actifs | Soumission du formulaire | Technique |

#### Phase 2 — Évaluation *(actualisée v1.1 : ajout d'un event vote intermédiaire)*

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `onboarding.solicitacao_complemento` | Solicitante | Admin demande complément | Relationnel |
| `onboarding.solicitacao_complemento_resposta_admin` | Tous admins réseau actifs | Solicitante répond | Technique |
| `onboarding.solicitacao_proposta_admin` | Autres admins réseau actifs (pas le·la proposeur·euse) | Admin propose décision | Technique |
| `onboarding.solicitacao_voto_intermediario_admin` *(nouveau v1.1)* | Autres admins réseau + **proposeur·euse uniquement au 1er vote** | Vote intermédiaire (favorable ou opposed) | Technique |

#### Phase 3 — Décision finale

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `onboarding.solicitacao_aprovada` | Solicitante | Acceptation confirmée (unanimité ou auto-confirmation mode dégradé) | Relationnel |
| `onboarding.solicitacao_recusada` | Solicitante (avec rationale opposed nominale ou anonymisée selon `disclose_identity`) | Refus confirmé | Relationnel |
| `onboarding.solicitacao_decisao_admin` | Tous admins réseau (in-app uniquement) | Décision finale | Technique |

#### Phase 4 — Rappels compte sans demande

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `onboarding.solicitante_rappel_30j` | Solicitante | J+30 sans demande | Technique |
| `onboarding.solicitante_rappel_60j` | Solicitante | J+60 sans demande | Technique |
| `onboarding.solicitante_suppression_avis` | Solicitante | J+83 sans demande | Technique |
| `onboarding.solicitante_supprime` | Solicitante | J+90, suppression effective | Technique |

#### Phase 5 — Parcours de constitution

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `onboarding.constituicao_rappel_45j` | Coordinateur·rice | J+45 parcours non terminé | Technique |
| `onboarding.constituicao_expiree` | Coord. + admins réseau | J+60 parcours non terminé | Technique |

#### Phase 6 — Compte refusé

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `onboarding.recusada_rappel_60j` | Solicitante refusée | J+60 après refus, pas de re-soumission | Technique |
| `onboarding.recusada_supprime` | Solicitante refusée | J+90 après refus | Technique |

#### Phase 7 — *(Nouveau v2.0)* Canal humain proactif (« Proposer un échange »)

| Event | Destinataire | Déclencheur | Ton |
|---|---|---|---|
| `onboarding.echange_propose_admin` | Solicitante | Admin réseau clique « Proposer un échange » | Relationnel |
| `onboarding.echange_demande_solicitante` | Tous admins réseau actifs | Solicitante clique « Demander un échange » (depuis `/conta`) | Relationnel |
| `onboarding.echange_reponse_solicitante` | Admin réseau proposeur·euse | Solicitante accepte ou décline une invitation | Technique |
| `onboarding.echange_reponse_admin` | Solicitante | Admin réseau répond à une demande d'échange | Technique |

**Note v2.0** : passage de 17 à **21 events** (ajout des 4 events de la phase 7 « canal humain proactif »). Tous ces events sont en ton **relationnel** pour les notifications initiales (le canal humain est par nature relationnel) et **technique** pour les confirmations de réponse.

**Note v1.1** *(historique)* : passage de 16 à 17 events (ajout de `solicitacao_voto_intermediario_admin`). Les préfixes ont été uniformisés en `onboarding.*` pour le routage propre dans l'Edge Function `notify-event` (cohérent avec les conventions `team.*` et `network.*` adoptées par les autres specs).

### 7.3 — Multilingue

Tous les mails sont disponibles dans les 6 locales du projet (pt-BR, fr, es, en, it, de). Les conventions linguistiques d'AnarBib s'appliquent (cf. notes internes : Genoss*in en allemand, compagno/a/e en italien, neutre *e* argentin en espagnol, triple form pt-BR).

Toutes les clés sont stockées dans `supabase/functions/_shared/i18n/mail-strings.ts` × 6 locales (~17 events × 2-3 clés × 6 = ~250 chaînes).

### 7.4 — *(Nouveau v1.1)* Compatibilité avec le handler `notify-event`

Le handler `onboarding.ts` à créer dans `supabase/functions/notify-event/handlers/` suit le pattern adopté au paquet 26 spec consultas (handler `consultas.ts`) et au chantier #114 spec admin réseau (10 sous-handlers `network.*`) :

- Lecture du payload JSONB de l'event
- Fan-out vers les destinataires selon la doctrine de notification (notifier celui qui n'a pas initié l'action, doctrine R5 spec consultas)
- Rendu du mail via `renderEmail(layout)` avec les clés i18n
- Envoi via `safeSendEmail`

**Principe SIGB** (cf. spec consultas v2.1 §11.2 R5) : on notifie celui qui n'a **pas** initié l'action. Concrètement :
- Solicitante soumet → admins réseau notifiés
- Admin réseau propose → autres admins réseau notifiés (pas le·la proposeur·euse)
- Admin réseau vote intermédiaire → autres admins + proposeur·euse au 1er vote seulement
- Unanimité atteinte → solicitante notifié·e + tous admins réseau (symétrique)

---

## 8. Cas particuliers

### 8.1 — Multi-soumission concurrente

Deux personnes différentes soumettent indépendamment une demande pour la même biblio (cas typique : deux membres d'un même collectif qui n'ont pas coordonné leur démarche).

**Détection** : par les admins réseau lors de l'évaluation, sur la base du nom de biblio, ville, contact email principal. Pas de détection automatique côté DB (trop de risque de faux positifs).

**Résolution** : la coordination réseau met les deux demandes en `aguardando_info`, demande aux deux personnes de se concerter. Une seule sera retenue après concertation explicite (l'autre est marquée comme `cancelada` avec mention du lien).

### 8.2 — Re-soumission après refus

Une personne refusée resoumet une demande corrigée.

**Pas de cooldown ni de limite stricte** sur le nombre de re-soumissions. Si une demande est ressoumise à l'identique sans correction substantielle, l'admin réseau peut utiliser la catégorie de refus `repeticao_sem_evolucao`.

### 8.3 — Solicitante qui décède ou disparaît pendant le parcours

Compte abandonné en cours de constitution. Géré automatiquement par les deadlines et rappels (J+45, J+60). Pas de mécanisme spécial requis.

### 8.4 — Solicitante qui veut annuler sa demande en cours

Action utilisateur·rice possible depuis `/conta`. Statut → `cancelada`. Le compte revient à l'état `solicitante_inicial` : la personne peut soumettre une nouvelle demande, ou laisser le compte expirer naturellement à J+90.

### 8.5 — Biblio acceptée mais coordinateur·rice initial·e se désiste

Cas complexe : la demande a été acceptée, mais pendant le parcours de constitution la personne coordinatrice initiale ne peut plus assumer.

**Possibilité de transfert du mandat** à un·e autre membre du collectif si on a son contact. Sinon, retour à un état d'attente jusqu'à ce que quelqu'un d'autre du collectif prenne le relais (action manuelle d'un·e admin réseau).

**TODO** : cadrer plus finement le mécanisme de transfert technique. Ne sera implémenté qu'au moment du Lot 5.

### 8.6 — *(Nouveau v1.1)* Veto d'un·e admin réseau pendant la délibération

Une demande est en `proposta_aprovacao`. Un·e admin réseau vote `opposed` avec rationale ≥ 20 chars.

**Comportement** :
- La demande **repasse en `pendente`** (annulation de la proposition)
- Mail au·à la proposeur·euse : « votre proposition a été contestée par {nom ou anonyme selon disclose_identity} avec la rationale suivante : {texte} »
- Mail aux autres admins réseau actifs : « une opposition a été soulevée, la délibération reprend » (rationale incluse, identité selon `disclose_identity`)
- Les votes `favorable` déjà émis sont **invalidés** : si un·e admin propose une nouvelle décision, le cycle de vote redémarre à zéro

**Cohérence politique** : symétrique au mécanisme de cooptation admin réseau (cf. spec admin réseau §4.1). Un veto ne tue pas la demande, il la renvoie en délibération.

### 8.7 — *(Nouveau v1.1)* Inhibition par disqualification d'admin réseau

Un·e admin réseau a proposé une décision, puis perd son statut (auto-retrait, retrait collectif, inactivité 6 mois) avant que l'unanimité ne soit atteinte.

**Comportement** :
- La proposition reste valide tant qu'aucun nouveau veto n'est émis
- Le vote `favorable` automatique du·de la proposeur·euse reste valide (capture du moment de la proposition)
- Si la délibération aboutit après la disqualification, le nom de l'ex-proposeur·euse est mentionné comme « {nom}, ancien·ne admin réseau » dans la décision finale

**Justification** : la proposition est un acte politique daté ; la disqualification ultérieure du·de la proposeur·euse ne l'invalide pas rétroactivement. Cohérent avec la doctrine d'immuabilité de l'audit (cf. spec admin réseau §3.2).

---

## 9. Hors scope

- **Migration de compte entre biblios existantes** → `docs/specs/spec-migration-compte.md`
- **Validation physique standard** (lecteur·rice s'inscrivant dans une biblio existante) → `docs/specs/spec-validation-physique.md`
- **Cooptation des admins réseau** *(actualisé v1.1)* → `docs/specs/spec-administrateur-reseau.md v0.3.1` (chantier clos 14/05/2026)
- **Modification du règlement après création** (la biblio existe déjà, son règlement évolue) → workflow différent à cadrer plus tard
- **Migration entre profils d'adoption** *(nouveau v1.1)* → `docs/specs/spec-profils-bibliotheque.md v0.3` (doctrine des transitions par type 1-4)
- **Fermeture définitive d'une biblio existante** → autre chantier (cf. spec migration pour le limbo des lecteur·rices)
- **Fusion de deux biblios** → cas exotique, à traiter ad hoc si jamais ça arrive

---

## 10. Checklist d'implémentation *(actualisée v1.1)*

**Stratégie retenue** : implémentation séquentielle stricte, lot par lot. **Prérequis bloquant** : paquet A de la spec profils v0.3 (champs DB `catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode` sur `libraries`) doit être livré avant le Lot 5.

### Lot 1 — Schéma DB et états des comptes (fondation)

- [ ] Étendre `library_requests` avec les nouveaux statuts et champs (cf. 3.1) — actualisé v1.1 avec `proposed_disclose_identity`
- [ ] Créer `library_request_votes` *(nouveau v1.1)* — table symétrique aux votes admin réseau
- [ ] Créer `library_request_comments`
- [ ] Créer `library_request_messages`
- [ ] Ajouter `solicitante_state` sur `profiles`
- [ ] Créer `library_constitution_progress` *(actualisé v1.1)* — ajout des 4 colonnes volet_0_*
- [ ] Mettre en place RLS pour les 3 acteurs (solicitante / admin réseau / public) — utilise `fn_caller_is_network_admin()` (helper centralisé spec admin réseau)
- [ ] Triggers DB pour transitions automatiques (création progress à acceptation, suppression compte à expiration)
- [ ] *(Nouveau v1.1)* Trigger `trg_check_request_unanimity` symétrique à celui des cooptations admin réseau

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
- [ ] Affichage motif refus + bouton « re-soumettre » en `solicitante_recusada` (avec gestion de l'anonymisation `disclose_identity`)
- [ ] Lancement du wizard de constitution depuis `coordenador_em_constituicao`

### Lot 4 — Interface admin réseau `/rede` section « Demandes d'adhésion » *(refonte v1.1, enrichie v2.0)*

- [ ] Vue liste avec filtres (statut, date, catégorie de refus)
- [ ] Vue détaillée d'une demande avec section votes en cours
- [ ] Actions individuelles : commenter, demander complément
- [ ] Actions de proposition : proposer acceptation / proposer refus (avec choix `disclose_identity`)
- [ ] Actions de vote : voter favorable / opposed (avec rationale ≥ 20 chars + choix `disclose_identity`) / abstain
- [ ] Mode dégradé seul·e admin (auto-confirmation si < 3 admins réseau actifs)
- [ ] Notifications in-app temps réel
- [ ] Réutilisation des composants ModalConfirm/Vote du paquet E.4 admin réseau (pattern modal Proposer/Voter/Cancel déjà livré)
- [ ] *(Nouveau v2.0)* Bouton « Proposer un échange » dans la vue détaillée, **positionné avant** les actions de proposition/vote (doctrine §1.4.2 : suggérer le dialogue avant la formalisation)
- [ ] *(Nouveau v2.0)* Table `library_request_invitations` (cf. §5.7.2) + RLS appropriées
- [ ] *(Nouveau v2.0)* RPC `api.fn_propose_request_exchange`, `api.fn_respond_request_exchange`, `api.fn_mark_request_exchange_completed`
- [ ] *(Nouveau v2.0)* Page `/conta/echange/{invitation_id}` côté solicitante pour répondre à une invitation
- [ ] *(Nouveau v2.0)* Historique chronologique enrichi : afficher les invitations émises, leur statut et résumés post-échange

### Lot 5 — Wizard de constitution (volet 0 + 10 volets) *(refonte v1.1, enrichie v2.0)*

**Prérequis bloquant** : paquet A spec profils v0.3 livré (champs DB profil sur `libraries`). ✅ **Livré 19/05/2026** dans le chantier profils d'adoption clos.
**Statut v2.0** : volet 0 livré dans le composant `LibraryProfileWizard.jsx` (chantier profils paquet F.3). Les volets 1-10 restent à implémenter dans le chantier #111.

- [x] Infrastructure du wizard (navigation, sauvegarde modulaire, deadline 60j) — **livré paquet F**
- [x] *(Nouveau v1.1)* Volet 0 — Choix du profil d'adoption (4 axes orthogonaux) — **livré paquet F.3**
- [ ] *(Nouveau v2.0)* Composant React partagé `<HumanChannelInlineCallout volet={voletId} />` (cf. §6.5.1)
- [ ] *(Nouveau v2.0)* Intégrer `<HumanChannelInlineCallout>` dans **chaque volet** (volets 0 inclus s'il faut rétroactivement enrichir le composant `LibraryProfileWizard` livré 19/05)
- [ ] *(Nouveau v2.0)* i18n × 6 locales pour les ~11 clés du composant (~66 strings militantes)
- [ ] Volet 1 — Identité
- [ ] Volet 2 — Horaires et permanences
- [ ] Volet 3 — Personnes responsables *(conditionnel governance_mode)*
- [ ] Volet 4 — Politique de catalogage *(TODO : choix libre vs liste fermée)*
- [ ] Volet 5 — Politique de circulation *(conditionnel circulation_mode != 'off')*
- [ ] Volet 6 — Politique d'adhésion lecteur·rice *(conditionnel governance_mode + circulation_mode)*
- [ ] Volet 7 — Politique des e-mails
- [ ] Volet 8 — Visibilité et participation au réseau *(conditionnel network_mode != 'isolated')*
- [ ] Volet 9 — Données et confidentialité
- [ ] Volet 10 — Génération du PDF de règlement
- [ ] *(Nouveau v2.0)* Volet 10 refondu : wording présentant le PDF comme **artefact de délibération collective**, pas certificat technique (cf. §6.6.1)
- [ ] *(Nouveau v2.0)* PDF généré : page de garde « squelette à discuter », préambule politique, marque « [À DISCUTER] » en pied de section, annexe « Modifications collectives apportées en assemblée » (cf. §6.6.2)
- [ ] Activation effective de la biblio à la fin du parcours (avec inscription DB du profil)

### Lot 6 — Notifications mail et automation *(actualisée v1.1, enrichie v2.0)*

- [ ] **21 templates mail × 6 locales** (vs 17 en v1.1 — ajout des 4 events Phase 7 « canal humain proactif » `onboarding.echange_*`)
- [ ] Implémenter Edge Function de relance (cron quotidien) pour les rappels J+30/45/60/83/90
- [ ] Triggers DB pour events temps réel (pattern `team_notification_outbox` + INSERT outbox + fan-out par `notify-event`)
- [ ] Handler `notify-event/handlers/onboarding.ts` (création) avec doctrine R5 (notifier celui qui n'a pas initié)
- [ ] Doctrine R1 héritée : proposeur notifié au 1er vote intermédiaire uniquement
- [ ] Système in-app de notifications admin réseau pour `/rede`
- [ ] *(Nouveau v2.0)* Sous-handler `onboarding.echange_*` dans `onboarding.ts` pour les 4 nouveaux events Phase 7

### Lot 7 — *(Nouveau v2.0)* Implémentation anti-méga-machine globale (MM1-MM5 du backlog v8)

**Articulation avec le chantier #111** : ces 5 items peuvent être livrés **indépendamment** du chantier #111. Ils propagent la doctrine §1.4 anti-méga-machine dans toute l'app, pas seulement dans l'onboarding biblio. Les 5 items sont scorés au backlog v8 (~8-10h cumulées) :

- [ ] **MM1** (score 15, 30 min) — Enrichir banner G sur BibliotecaPage : « ... ou écrivez-nous pour qu'on en parle ensemble » + lien `anarbib@proton.me`
- [ ] **MM5** (score 15, 1h) — Bandeau anti-méga-machine sur `SolicitarBibliotecaPage` (page publique d'inscription) : « vous pouvez aussi nous écrire pour qu'on en discute avant »
- [ ] **MM2** (score 14, 2-3h) — Footer global persistant `<HumanChannelFooter>` sur toutes pages staff (Painel, Biblioteca, NetworkAdmin, AdminsPanel) avec mail collectif + Matrix
- [ ] **MM3** (score 11, 2-3h) — Encadrés inline `<HumanChannelInlineCallout>` (composant partagé avec Lot 5) sur pages Biblioteca sensibles : gouvernance, profil, transitions, regimento
- [ ] **MM4** (score 10, 3-4h) — Page `/conversemos` (ou `/ajuda`) qui présente le canal humain comme premier et les guides comme second. Doctrine §1.4.2 exigence 3.

**Ordre d'exécution recommandé** : MM1 + MM5 (1h30) en premier (gains rapides visibles), puis MM2 (composant footer global, structure réutilisable), puis MM3 (partage du composant `<HumanChannelInlineCallout>` avec Lot 5) et MM4 ensemble.

**Cohérence d'implémentation Lot 5 ↔ Lot 7** : le composant `<HumanChannelInlineCallout>` est partagé entre les deux lots. Si Lot 5 (chantier #111) attend Q3 2026, MM3 peut être livré dès maintenant en créant le composant avec un paramètre `context` qui distingue les usages.

---

## TODO ouverts (à arbitrer plus tard)

- **TODO 1** : Que se passe-t-il à l'expiration des 60 jours du parcours de constitution ?
  - Option a : avertissement à J+45, gel à J+60 (réveillable par admin réseau)
  - Option b : avertissement à J+45, révocation à J+60 (compte → `solicitante_recusada`)
  - Option c : avertissement uniquement, jamais de gel auto
- **TODO 2** : Volet 4 (catalogage) — choix libre du système de classification ou liste fermée à définir collectivement ?
- **TODO 3** : Mécanisme technique de transfert du mandat coordinateur·rice (cas 8.5)
- **TODO 4** *(nouveau v1.1)* : pendant le wizard de constitution, faut-il permettre à la biblio de **modifier son profil** (volet 0) après avoir commencé les volets suivants ? Si oui, comment gérer les données déjà saisies dans des volets devenus sans objet ?
- **TODO 5** *(nouveau v1.1)* : faut-il un mécanisme de notification spécifique aux admins réseau quand une nouvelle biblio est acceptée et démarre son wizard, ou les rappels J+45 / J+60 suffisent-ils ?
- **TODO 6** *(nouveau v2.0)* : doit-on bloquer la soumission d'un volet tant qu'aucun échange humain n'a eu lieu, dans certains cas critiques (par exemple le volet 0 si le profil choisi semble incohérent avec le récit de la demande) ? Plutôt non par défaut, car ce serait paternaliste — mais à discuter au moment du chantier #111.
- **TODO 7** *(nouveau v2.0)* : faut-il prévoir une **statistique anti-méga-machine** dans le tableau de bord admin réseau ? Par exemple : nombre d'invitations émises sur les 30 derniers jours, taux d'acceptation, durée moyenne d'un échange. Pour mesurer si la doctrine est effectivement appliquée et pour identifier les biblios qui n'utilisent jamais le canal humain (signe potentiel de difficulté silencieuse). À discuter.

---

## Annexe — *(Nouveau v1.1)* Changelog v1.0 → v1.1

**Objet de la version** : refonte cohérence après la livraison complète du chantier admin réseau (paquets A-F + #114, 11-14/05/2026) et l'établissement de la spec profils d'adoption v0.3 (13/05/2026). La doctrine de validation à deux yeux est remplacée par le workflow politique de cooptation unanime des admins réseau ; le wizard de constitution intègre un volet 0 pour le choix du profil d'adoption.

**Sections refondues intégralement** :
- §1 principe directeur #4 : « administrador » → « administrateurs du réseau » avec workflow de cooptation unanime
- §2.6 : workflow politique réseau, mode dégradé recalibré sur quorum < 3
- §5 entière : « validation à deux yeux » → « votes à l'unanimité avec disclose_identity », réutilisation du pattern admin réseau

**Sections ajoutées** :
- §1 principe directeur #6 : profil d'adoption comme acte fondateur
- §3.1 : nouvelle table `library_request_votes` symétrique aux votes admin réseau
- §6.2 : volet 0 du wizard (choix du profil d'adoption sur 4 axes orthogonaux)
- §6.4 actualisée : activation effective avec inscription du profil en DB
- §7.4 : compatibilité avec le handler `notify-event` (doctrine R5 et R1 héritées)
- §8.6 : cas du veto pendant délibération
- §8.7 : cas de disqualification d'admin réseau pendant délibération
- §9 : ajout de la migration entre profils dans le hors scope
- TODO 4 et TODO 5 ajoutés
- Annexe (ce changelog)

**Sections mises à jour** :
- En-tête : version 1.1, dépendances actualisées (admin réseau v0.3.1, gouvernance v1.1, profils v0.3)
- §2.1 acteurs : « administradores » → « administrateurs du réseau » avec référence à `network_administrators`
- §2.7 catégories de refus : choix `disclose_identity` côté admin proposant
- §3.1 : champs `proposed_disclose_identity` (pas de DEFAULT), `confirmed_by_admin_id` supprimés, table votes ajoutée
- §3.1 `library_constitution_progress` : ajout 4 colonnes `volet_0_*` et 1 booléen `volet_0_profil_done`
- §3.2 RLS : `fn_caller_is_network_admin()` au lieu de mention directe « administrador »
- §3.3 triggers : ajout `trg_check_request_unanimity` symétrique aux cooptations admin réseau
- §4.4 état `solicitante_recusada` : affichage rationale opposed selon `disclose_identity`
- §4.5 état `coordenador_em_constituicao` : bandeau mentionne le volet 0
- §6.1 forme du parcours : démarrage obligatoire par volet 0
- §6.3 volets 1-10 : conditionnalités selon les axes du volet 0
- §7.1 stratégie : doctrine R1 (proposeur 1er vote) et R5 (notifier qui n'a pas initié) héritées de la spec admin réseau et spec consultas
- §7.2 cartographie : passage de 16 à 17 events, préfixe `onboarding.*` uniformisé
- §8 cas particuliers : ajout 8.6 et 8.7 (veto et disqualification)
- §10 checklist : tous les lots actualisés avec les modifications v1.1, prérequis bloquant paquet A spec profils mentionné

**Sections inchangées (par rapport à v1.0)** :
- §1 contexte, objectif, principes 1, 2, 3, 5
- §2.2 états (sauf wording « par la coordination du réseau » vs « admins »)
- §2.3, §2.4, §2.5 conditions d'éligibilité et techniques
- §2.7 catégories de refus (sauf ajout disclose_identity dans 5.4)
- §4.1, §4.2, §4.3 UX comptes standard / solicitante_inicial / solicitante_pendente
- §6 wizard sauf intro et conditionnalités (les volets 1-3, 7, 9, 10 sont structurellement identiques)
- §8.1, §8.2, §8.3, §8.4, §8.5 cas particuliers
- §9 hors scope (sauf ajouts)

**Bilan v1.1** : la spec est désormais **alignée avec les 3 specs sœurs** déjà refondues ce matin (admin réseau v0.3.1, consultas v2.1, gouvernance v1.1) et la spec profils v0.3. Elle reste en attente d'implémentation : les Lots 1-6 sont à livrer dans un chantier dédié, qui pourra démarrer après le paquet A de la spec profils.

---

## Annexe — *(Nouveau v2.0)* Scénario pédagogique Émile-Henry

**Statut** : annexe normative. Reprise depuis le RIFLEXION du 19-20/05/2026 (`docs/decisions/RIFLEXION_articulation_onboarding_profils_2026-05-20.md` §3) pour donner une illustration vivante de la doctrine anti-méga-machine §1.4.

### A.1 — Le cas

**Émile-Henry**, à Lyon, demande sa création sur AnarBib le 25/05/2026. Camille (future coordenadora) remplit le wizard F.3 sur `SolicitarBibliotecaPage` et **clique le profil D pré-câblé** sans le modifier — par sentiment de pression, par manque de temps de lire les libellés, par choix par défaut « ça doit être bon ». Le réseau valide la demande en 3 jours.

Une semaine plus tard, l'assemblée Émile-Henry réalise collectivement :

> *« En fait nous, on prête nos livres en chuchotant pendant nos réunions hebdo et on note ça sur un cahier. On ne veut pas d'un SIGB complet. On veut juste un catalogue qu'on partage avec d'autres biblios anars d'Europe. »*

Le bon profil pour eux serait probablement **B** (`local_only / informal / federated / informal`), pas D.

### A.2 — Sans la doctrine anti-méga-machine (état v1.1)

État technique post-validation, sans aucun mécanisme de canal humain proactif :

- Banner G s'affiche sur leur `BibliotecaPage` (livré 19/05) avec un wording neutre type *« utilisez le mécanisme de vote collectif pour reconfigurer votre profil »*
- Camille clique sur l'onglet Transições → voit qu'il faut faire **4 propositions distinctes** (`catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode`)
- Chaque proposition a son propre type de transition (rapide, lente, irréversible), donc **au minimum 8 semaines de procédure** pour réaligner les 4 axes
- Risque concret qu'Émile-Henry abandonne en chemin par fatigue ou que le collectif perde son énergie politique sur de la mécanique procédurale

### A.3 — Avec la doctrine anti-méga-machine (état v2.0)

Mêmes faits, mais avec les enrichissements doctrinaux v2.0 + les items MM1-MM5 du backlog v8 en prod :

1. **Pendant le parcours initial** (volet 0 du wizard F.3) : l'encadré canal humain (cf. §6.5.2 wording volet 0) affichait clairement *« A gente pode te ajudar a traduzir o funcionamento real do seu coletivo em eixos »*. Camille aurait peut-être cliqué et la confusion aurait été évitée en amont.

2. **Si elle n'a pas cliqué** (cas réel : pression, distraction) : sur sa `BibliotecaPage` post-validation, le **footer global persistant** (MM2) reste visible avec `anarbib@proton.me`. Sur l'onglet Profil d'adoption spécifiquement, l'**encadré inline** (MM3) appelle au dialogue.

3. **Banner G enrichi** (MM1) : *« Sua biblio acabou de aderir ao AnarBib. Se você quer reconfigurar seu profil ou refletir sobre ele, escreva-nos: anarbib@proton.me — a gente pode discutir antes de qualquer voto. »*

4. **Côté admin réseau** : Xavier (ou autre admin) voit dans `/rede` qu'Émile-Henry est validée mais n'a rien fait depuis 14 jours. Il clique **« Proposer un échange »** (§5.7) → mail à Camille : *« On a vu que vous êtes en train de découvrir le système, on a une heure de dispo cette semaine pour en discuter sur Matrix si vous voulez. »*

5. Camille répond, l'échange a lieu, Xavier (ou un·e autre admin) **traduit la pratique réelle d'Émile-Henry en quadruplet d'axes** (« toi tu dis que vous prêtez en chuchotant, donc circulation_mode informal pas full_sigb »).

6. À l'issue de la conversation, le collectif **comprend ses axes**, peut **voter collectivement** en assemblée le re-choix avec consentement éclairé.

7. Le mécanisme de vote E.5 reste celui qui formalise techniquement, mais **la délibération de fond a eu lieu avant**, **hors SIGB**, **avec un·e camarade**.

### A.4 — Ce que ce scénario montre

Le SIGB ne remplace pas la fédération, il l'outille. Le canal humain n'est pas un luxe d'UX mais une **condition de fonctionnement** de la fédération pour des collectifs au caractère informel souvent prononcé (très majoritaires dans le monde militant anarchiste).

Sans la doctrine anti-méga-machine :
- 8 semaines de procédure → risque d'abandon
- Confusion sur les choix techniques → choix par défaut subi
- Sentiment d'enfermement dans une machine → perte de l'énergie politique

Avec la doctrine anti-méga-machine :
- 1 échange humain de 30-60 min → traduction politique + choix éclairé
- Vote E.5 mécanique simplifié car la délibération de fond a déjà eu lieu
- Sentiment d'appartenance à une fédération qui accompagne → renforcement politique

---

## Annexe — *(Nouveau v2.0)* Changelog v1.1 → v2.0

**Objet de la version** : enrichissement doctrinal post-clôture du chantier profils d'adoption (paquets E.0-E.5, F.0-F.4, G livrés en marathon 19-20/05/2026). Intégration normative de la **doctrine anti-méga-machine** émergée pendant cette session marathon et capturée dans `docs/decisions/RIFLEXION_articulation_onboarding_profils_2026-05-20.md` (345 lignes).

**Origine politique de la v2.0** : la session marathon a livré la fondation backend + frontend du modèle profils d'adoption (4 axes orthogonaux, transitions, wizard volet 0). En réfléchissant à l'articulation avec le futur chantier #111 (wizard onboarding biblio complet, volets 1-10), une doctrine politique nouvelle a émergé : la complexité technique légitime d'AnarBib ne doit jamais effacer le canal humain de la fédération. Le SIGB est un outil ; les camarades qui s'en servent sont l'horizon.

**Sections ajoutées** :
- **§1.4 entière** : doctrine anti-méga-machine (formulation politique, 3 exigences, articulation avec v1.1, illustration par Émile-Henry)
- §1 principe directeur **#7** : « Le SIGB est second, le canal humain est premier »
- §5.7 entière : canal humain proactif côté admins réseau (« Proposer un échange »), 5 sous-sections
- §6.5 entière : encadré canal humain dans chaque volet (composant, wording par volet, i18n, articulation avec MM3)
- §6.6 entière : PDF règlement comme artefact de délibération collective (refonte du volet 10, contenu du PDF, articulation avec MM2)
- §6.7 entière : section ouverte sur le parcours d'entrée `anarbib.org` vs `app.anarbib.org` (statut « à creuser au chantier #111 »)
- Phase 7 mail : 4 nouveaux events `onboarding.echange_*` (passage 17 → 21 events)
- Lot 7 checklist : implémentation anti-méga-machine globale MM1-MM5 (référence backlog v8)
- TODO 6 et TODO 7
- Annexe : scénario pédagogique Émile-Henry (normatif)
- Annexe : ce changelog

**Sections mises à jour** :
- En-tête : v2.0, dépendance spec admin réseau v0.4 (à produire en miroir), dépendance spec profils v0.7 (cloture chantier), référence RIFLEXION
- Sommaire : mention des sections nouvelles
- §4.5 état `coordenador_em_constituicao` : ajout du bandeau canal humain permanent + symétrique du bouton admin
- §5.4 actions disponibles : ajout de l'action « Proposer un échange » (référence §5.7)
- §5.6 traçabilité : ajout des événements invitation/demande d'échange
- §7.2 cartographie : ajout phase 7 mail, passage 17 → 21 events
- Lot 4 checklist : ajout 5 items v2.0 (bouton + table + RPC + page solicitante + historique enrichi)
- Lot 5 checklist : marque volets 0 et infrastructure comme **livrés 19/05**, ajout composant `<HumanChannelInlineCallout>` + i18n × 6 locales + volet 10 refondu + PDF artefact
- Lot 6 checklist : passage 17 → 21 templates mail, ajout sous-handler `onboarding.echange_*`

**Sections inchangées (par rapport à v1.1)** :
- §1 contexte, objectif, principes 1, 2, 3, 4, 5, 6
- §2 modèle conceptuel complet
- §3 schéma DB (sauf ajout table `library_request_invitations` mentionné dans §5.7.2)
- §4.1-4.4 UX comptes standard / solicitante_inicial / solicitante_pendente / solicitante_recusada
- §5.1-5.6 sauf compléments mentionnés
- §6.1-6.3 forme du parcours et volets 1-10 (les conditionnalités v1.1 sont conservées)
- §6.4 activation effective
- §7.1, §7.3, §7.4 stratégie mail, multilingue, handler
- §8 cas particuliers complet
- §9 hors scope
- Lots 1, 2, 3 checklist

**Bilan v2.0** : la spec est désormais **alignée avec la doctrine anti-méga-machine** qui doit s'étendre à toute l'app (cf. items MM1-MM5 du backlog v8 + futur enrichissement spec admin réseau v0.4 en miroir). Elle est prête à servir de référence normative pour le chantier #111 (perspective Q3 2026, ~2-3 semaines) qui implémentera les volets 1-10 du wizard de constitution avec les enrichissements anti-méga-machine intégrés.

Le **wizard volet 0** étant déjà en prod (paquet F.3 du chantier profils), un effort de rétrofit est à prévoir pour y ajouter le composant `<HumanChannelInlineCallout>` avec le wording §6.5.2 volet 0. Cet effort peut être inclus dans le Lot 7 (MM3 partiellement) ou attendre le chantier #111.

---

**Fin de la spec.**
