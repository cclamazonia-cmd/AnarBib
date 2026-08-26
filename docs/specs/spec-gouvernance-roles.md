# Spécification : Gouvernance des rôles dans AnarBib

**Version** : 1.4 — 2026-08-26 (T2 passe à la cooptation collégiale)
**Statut** : Spec validée politiquement, **partiellement implémentée en production** (cf. §14)
**Contexte** : Roadmap Bologna sept 2026
**Auteur·ices** : Xavier (cadrage politique) + Claude (rédaction)

**Historique** :
- v1.0 (2026-05-05) : première rédaction. Modèle 4 rôles (`reader`, `librarian`, `coordenador`, `administrador`), 9 transitions T1-T9, audit log, notifications, cron pending_removal et inactivity cleanup. Implémentation en lots 1-7.
- **v1.1 (2026-05-15)** : refonte cohérence après la livraison complète du chantier admin réseau (paquets A-F + #114, 11-14/05/2026). Le rôle `administrador` **local** a été supprimé du schéma `user_library_memberships.role` (CHECK constraint rétréci au paquet F), remplacé par la table `network_administrators` (cf. spec admin réseau v0.3.1). Cette spec gouvernance perd donc tout ce qui concernait l'administrador local. Ajout du périmètre d'activation : cette spec décrit le mode `governance_mode = 'full_governance'` de la spec profils v0.3 ; les profils plus simples (`informal`, `staff_roles`) en activent des sous-ensembles. Implémentation reflétée dans §14.
- **v1.2 (2026-05-20)** : doctrine « **rôle exclusif** » actée et implémentée en production. Une personne ne peut avoir qu'**un seul rôle actif** par bibliothèque ; une promotion ferme le membership de rang inférieur (`status='removed'`), une rétrogradation réactive celui du cran en dessous. La v1.1 recommandait le multi-membership (cumul de lignes actives) « pour préserver l'historique » : cet argument ne tient pas — l'historique est intégralement porté par l'audit log et par les lignes `removed`, sans cumul de lignes `active`. Le multi-membership n'apportait que de l'ambiguïté (toute requête `WHERE role=...` devait se demander laquelle fait foi). Sections amendées : §5.3, §6.5, §10.3 ; précisions §5.6 et §12.1. Voir Annexe E (changelog) et Annexe D (décision cadrée). Implémentation : hotfix promotion librarian (20/05) + migration doctrine rôle exclusif promote_coordenador/cron (20/05).
- **v1.3 (2026-05-24)** : amendement TM-A (issu de l'audit #153 des contenus de mails). Le seuil d'inactivité J-7 (`team.inactive_warning_7d`) notifie désormais la coordination en copie, et non plus la seule personne concernée ; si la personne inactive est le·la dernier·e coordenador·a, la copie est escaladée aux administrateur·rices du réseau (même mécanisme que §6.1). Cet amendement entérine le comportement déjà en production dans `team.ts` plutôt que de l'aligner sur l'ancienne règle. Sections amendées : §5.10, §8.2 ; traçage Annexe Q7. Le seuil J-30 reste inchangé (personne uniquement).

- **v1.4 (2026-08-26)** : **T2 (`librarian` → `coordenador`) cesse d'être unilatérale.** La promotion reposait sur la seule autorisation `user_can_manage_library()` : un·e coordenador·a pouvait en faire un·e autre, seul·e et sans le consentement de l'intéressé·e — ce qui contredisait P2 (cooptation pour **les deux** rôles staff) et P3 (une charge s'accepte, elle ne s'impose pas). Elle emprunte désormais le circuit d'invitation déjà en place : proposition → ratification par une autre personne du staff → acceptation par la personne concernée. `fn_team_promote_to_coordenador` est conservée mais lève `collegiality_required` : un échec bruyant vaut mieux qu'un succès qui ne promeut plus rien. Sections amendées : §5.1, §5.3, §6.1, §6.5, §7.3, §8.2, §8.3, §11.2, §12.3, §15. §14 **entièrement refait** — l'état des lots datait du 15/05/2026 et annonçait « à faire » des objets déjà livrés au 10/05. Implémentation : migrations `20260826120000` et `20260826130000`, front `feat(team)` du 26/08. Registre : `GOUV-1` à `GOUV-6`.

---

## Sommaire

1. [Préambule politique](#1-préambule-politique)
2. [Principes fondateurs](#2-principes-fondateurs)
3. [Modèle des rôles](#3-modèle-des-rôles)
4. [Modèle des status](#4-modèle-des-status)
5. [Transitions et autorisations](#5-transitions-et-autorisations)
6. [Cas-limites et garde-fous](#6-cas-limites-et-garde-fous)
7. [Audit log](#7-audit-log)
8. [Notifications mail](#8-notifications-mail)
9. [Interface utilisateur·rice](#9-interface-utilisatricerice)
10. [Modèle de données](#10-modèle-de-données)
11. [API : RPC SECURITY DEFINER](#11-api--rpc-security-definer)
12. [Cron jobs](#12-cron-jobs)
13. [Rôle administrador AnarBib → renvoi spec dédiée](#13-rôle-administrador-anarbib--renvoi-spec-dédiée)
14. [Plan d'implémentation](#14-plan-dimplémentation)
15. [Cas d'usage de référence](#15-cas-dusage-de-référence)

---

## 1. Préambule politique

AnarBib est un **système intégré de gestion de bibliothèques (SIGB)** destiné à un réseau de bibliothèques **militantes anarchistes et libertaires**. Dans ce contexte, la question de la « gouvernance des rôles » est intrinsèquement politique : elle touche à la délégation de pouvoir, à la transparence, à la responsabilité collective.

### 1.1. La tension à assumer

Tout SIGB doit gérer techniquement **qui peut faire quoi** : qui valide les inscriptions, qui modifie l'identité publique de la biblio, qui consulte les données personnelles des emprunteur·euses. Cette nécessité technique entre en tension apparente avec l'idéal d'horizontalité revendiqué par les bibliothèques anarchistes.

Cette spec **assume la tension** plutôt que la cacher. Le SIGB ne **modélise pas l'AG**, il **enregistre les décisions du collectif**. La culture politique du collectif ne tient pas dans le code, elle vit dans les pratiques et les assemblées.

### 1.2. Principe directeur : **délégation avec rotation des fonctions**

Les rôles dans AnarBib **ne sont pas des grades**. Ce sont des **fonctions** que le collectif délègue temporairement à certain·es de ses membres pour exécuter des tâches techniques précises (valider une inscription, modifier l'identité publique de la biblio, etc.). Une coordination « à vie » n'est pas anarchiste : la spec prévoit explicitement la **rotation** des fonctions, et les **mécanismes de retrait** (volontaire ou par le collectif) sont aussi importants que les mécanismes de nomination.

### 1.3. Périmètre de cette spec

**Couvert** :
- Nomination, promotion, rétrogradation, exclusion des membres d'une équipe de biblio
- Modèle de données (tables, status, contraintes)
- API technique (RPCs) pour exposer ces actions
- Notifications, audit log, interface

**Hors périmètre** (specs séparées) :
- **Administration du réseau AnarBib** (cooptation, retrait collectif, droits transverses) : couvert par `spec-administrateur-reseau.md v0.3.1` (chantier clos 14/05/2026)
- Validation physique d'un compte lecteur·rice (cf. `spec-validation-physique.md` à rédiger)
- Migration de compte entre biblios (cf. `spec-migration-compte.md` cadrée le 03/05/2026)
- Workflow d'invitation initiale d'un·e librarian (à cadrer dans une spec dédiée)

### 1.4. *(Nouveau v1.1)* Périmètre d'activation : mode `full_governance` des profils d'adoption

Cette spec décrit le **mode `governance_mode = 'full_governance'`** défini par la spec profils d'adoption v0.3 (cf. `spec-profils-bibliotheque.md`). Le `governance_mode` est l'un des 4 axes orthogonaux de configuration d'une biblio :

- `governance_mode = 'informal'` : pas de rôles staff distincts. Tout le monde est `reader`. La biblio fonctionne par confiance directe, sans workflow de cooptation. Cette spec **ne s'applique pas**.
- `governance_mode = 'staff_roles'` : rôles `librarian` + `coordenador` actifs, mais pas de cycle de carence/suspension/audit log. Cooptation simplifiée. Cette spec s'applique en mode **dégradé** (T1, T2, T4 actifs ; T5, T6, T7 désactivés).
- **`governance_mode = 'full_governance'`** : doctrine intégrale de cette spec. Tous les rôles, toutes les transitions, audit log complet, notifications systématiques, crons actifs.

**Conséquence opérationnelle** : les RPC de cette spec vérifient en début d'exécution le `governance_mode` de la biblio cible et rejettent les transitions non autorisées dans le mode courant. La doctrine politique reste identique ; seul l'activation des mécanismes varie.

**Implémentation** : à prévoir au paquet F de la spec profils (livraison du `governance_mode` opérationnel). Tant que la spec profils n'est pas livrée, toutes les biblios fonctionnent implicitement en mode `full_governance` (équivalent à v1.0).

---

## 2. Principes fondateurs

### P1 — Délégation, pas hiérarchie

Aucun rôle n'est un titre. Tous les rôles sont **temporaires par nature** et **révocables** selon les règles définies dans cette spec.

### P2 — Cooptation pour les rôles staff

L'entrée dans une équipe (devenir librarian, devenir coordenador) se fait par **cooptation des coordenadores existant·es**. Ce choix politique repose sur l'idée que c'est au collectif politique (qui se réunit en AG ou équivalent **hors logiciel**) de décider qui est admis, et qu'un·e coordenador·a n'est que la main qui exécute la décision dans le SIGB.

### P3 — Rétrogradation volontaire toujours possible

Toute personne avec un rôle staff peut **se rétrograder elle-même à tout moment**, sans consultation. « Je passe la main » est un droit fondamental.

### P4 — Exclusion encadrée par un délai de carence

L'exclusion non volontaire d'un·e librarian par un·e coordenador·a passe par un **délai de carence de 7 jours** avant effet. Ce délai permet la délibération collective et l'éventuelle annulation par un·e autre coordenador·a. C'est le compromis entre la nécessité d'agir vite (urgence, conflit) et la collégialité de la décision.

### P5 — Transparence maximale

L'**audit log** des changements de rôle est **public au staff actif** de la biblio (pas seulement aux coordenadores). Cela empêche les manipulations opaques, conformément à la culture politique d'horizontalité informationnelle.

### P6 — Notifications systématiques

Tout changement de rôle déclenche un **email à la personne concernée et à toute la coordination**. Personne ne peut être modifié·e dans son rôle sans le savoir, et la coordination est toujours informée.

### P7 — Souveraineté locale des biblios

Les changements de rôle dans la biblio A n'affectent **rien** dans la biblio B, même pour la même personne. Chaque biblio est souveraine sur ses délégations internes.

**Articulation v1.1 avec admin réseau** : les administrateurs du réseau AnarBib (cf. spec admin réseau v0.3.1) ont un droit politique transverse d'**intervention opérationnelle** sur n'importe quelle biblio (via les helpers `user_can_act_as_staff_on_library` et `user_can_engage_library`). Cette intervention transverse est **tracée** dans `network_admin_cross_library_actions_log` (paquet C.5), avec notification au staff local pour les actions critiques. La souveraineté locale reste donc politiquement intacte : l'admin réseau ne remplace pas la coordination locale, il intervient si elle est défaillante ou empêchée.

### P8 — Le SIGB ne modélise pas l'AG

Le SIGB exécute les décisions, il ne les prend pas. La spec ne contient aucun mécanisme de vote, quorum, etc. Ces choses se passent en collectif, hors logiciel.

---

## 3. Modèle des rôles

AnarBib utilise un modèle à **3 rôles locaux** (réduit de 4 à 3 au paquet F admin réseau, 13/05/2026). Ces rôles existent en base via le CHECK constraint sur `user_library_memberships.role` :

```sql
-- Depuis le paquet F (13/05/2026) :
CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador']))
```

**Évolution v1.0 → v1.1** : le rôle `administrador` qui figurait dans cette liste en v1.0 a été **retiré** du CHECK constraint au paquet F. Il était politiquement ambigu (cf. préambule politique spec admin réseau) : techniquement rattaché à une `library_id`, mais sémantiquement transverse. Sa fonction est désormais portée par la table `network_administrators` (cf. spec admin réseau v0.3.1 §3.1).

### 3.1. `reader`

**Définition** : compte lecteur·rice de base. Aucun pouvoir d'administration sur la biblio.

**Permissions** :
- Consulter le catalogue (selon la visibility de la biblio)
- Emprunter, réserver, consulter en salle
- Modifier ses propres données personnelles
- Demander la migration ou suppression de son compte

**Contexte spec** : ce rôle est concerné par cette spec uniquement comme **point de départ et d'arrivée** (entrée dans l'équipe = passage reader→librarian, sortie = passage librarian→reader).

### 3.2. `librarian`

**Définition** : staff opérationnel de la biblio. Gère le quotidien (emprunts, réservations, validation des inscriptions).

**Permissions techniques actuelles** (via le helper `user_can_act_as_staff_on_library` — wrapper depuis le paquet C admin réseau, cf. annexe B) :
- Tout ce qu'a un reader
- Gérer les emprunts, réservations, retours
- Valider les inscriptions (selon le mode `validation_mode` de la biblio)
- Modifier les données catalogues (selon RLS)
- Accéder aux données personnelles des lecteur·rices de la biblio
- **Lecture** seule sur la liste de l'équipe (onglet team de `/biblioteca`)

**Permissions ajoutées par cette spec** :
- Pouvoir lire l'audit log de l'équipe (P5)
- Recevoir les notifications de changements de rôle de l'équipe (P6)

### 3.3. `coordenador`

**Définition** : staff de coordination. Délégation administrative donnée par le collectif.

**Permissions actuelles** (via le helper `user_can_engage_library` — wrapper depuis le paquet C admin réseau, cf. annexe B) :
- Tout ce qu'a un librarian
- Modifier l'identité publique de la biblio (`library_commons` : nom, logo, contact mail, etc.)
- Modifier la configuration de la biblio (politiques d'emprunt, règlement, etc.)
- Gérer les règles de cotisation

**Permissions ajoutées par cette spec** :
- **Promouvoir** un reader → librarian
- **Promouvoir** un librarian → coordenador
- **Rétrograder** un autre coordenador (avec accord de l'intéressé·e ou en collégialité)
- **Demander l'exclusion** d'un librarian (déclenche le délai de carence 7j)
- **Annuler la demande d'exclusion** d'un autre coordenador (avant les 7j)
- **Suspendre** immédiatement un·e librarian (mesure conservatoire)

### 3.4. *(Refonte v1.1)* Rôle d'administration du réseau → spec dédiée

**Le rôle `administrador` local a été supprimé au paquet F admin réseau (13/05/2026)** : il n'existe plus dans `user_library_memberships.role`. Sa fonction politique (autorité transverse sur le réseau AnarBib) est désormais portée par la table dédiée `network_administrators`.

**Pour l'autorité transverse, voir** : `spec-administrateur-reseau.md v0.3.1`. Cette spec gouvernance se limite désormais strictement aux rôles **locaux** d'une biblio.

**Articulation avec cette spec** :
- Un·e administrateur·rice réseau actif·ve passe le helper `fn_caller_is_network_admin()` → considéré comme **staff** sur toute biblio via les helpers `user_can_act_as_staff_on_library` et `user_can_engage_library` (paquet C admin réseau)
- Ses actions transverses sont tracées dans `network_admin_cross_library_actions_log` (paquet C.5 admin réseau) avec notification au staff local pour les actions critiques (modifications de règlement, suspensions, etc.)
- `fn_resolve_caller_role_for_library` retourne `'network_admin'` comme rôle virtuel pour ces personnes
- Le `LibraryContext` du frontend expose `isNetworkAdmin`, `effectiveRole`, `hasStaffAccess` (paquet E.3 admin réseau)

**Conséquence pour le tableau des transitions §5** : « administrador » disparaît de la colonne « Qui peut le faire » de toutes les transitions T1-T9. La capacité d'intervention reste portée par les administrateurs du réseau, via les helpers d'autorisation centralisés.

---

## 4. Modèle des status

Le CHECK constraint actuel sur `user_library_memberships.status` (élargi par le paquet 23 du 11/05/2026 pour cohérence avec `network_administrators`) :

```sql
CHECK (status = ANY (ARRAY['active', 'inactive', 'pending', 'pending_removal', 'suspended', 'removed']))
```

**Note v1.1** : la valeur `'removed'` ajoutée par le paquet 23 pour aligner sur `network_administrators` n'est pas utilisée par les RPC de cette spec (qui s'arrêtent à `'inactive'`). Elle est réservée à des usages futurs (purge RGPD, par exemple).

### 4.1. `active`

État normal d'une membership. La personne a son rôle et l'exerce.

### 4.2. `pending`

**Réservé à la spec validation physique** (hors périmètre de cette spec). Membership en attente de validation par un·e librarian+ de la biblio d'inscription. Cette spec **ne touche pas** à ce statut.

### 4.3. `suspended`

**Mesure conservatoire** prise par un·e coordenador·a. La membership est gelée (le rôle nominal est conservé en base mais ne donne aucun accès tant que le statut est `suspended`).

**Usage** : harcèlement signalé en attente d'investigation, compte compromis, conflit en cours de médiation, etc.

**Durée** : indéfinie. La levée se fait manuellement par un·e coordenador·a (retour à `active`) ou par destitution effective (passage à `inactive`).

**Effet** : aucun accès aux fonctions du rôle. La personne reste affichée dans l'équipe avec un badge « suspendue ».

### 4.4. `pending_removal`

**Période de carence de 7 jours** avant exclusion effective.

**Déclenchement** : un·e coordenador·a demande l'exclusion d'un·e librarian (RPC `fn_team_request_remove_member`).

**Effet immédiat** :
- Le rôle nominal est conservé mais **aucun accès** tant que le statut est `pending_removal`
- La personne est notifiée par mail (cf. §8)
- La coordination est notifiée par mail
- Audit log enregistré

**Évolution** :
- **Annulation** : un·e autre coordenador·a (ou la même) peut annuler la demande dans les 7 jours via `fn_team_cancel_remove_member`. Retour à `active`.
- **Auto-rétro de la personne concernée** : la personne peut elle-même se rétrograder via `fn_team_self_demote` pour court-circuiter le délai (sortie volontaire).
- **Effet automatique** : à J+7, un cron passe le statut à `inactive` (cf. §12).

### 4.5. `inactive`

Membership fermée. La personne **n'est plus dans l'équipe**.

**Lectures multiples possibles** :
- Sortie volontaire (`fn_team_self_demote`)
- Carence expirée (`pending_removal` → `inactive`)
- Compte abandonné (cron J-9 mois)

**Effet** :
- Aucun accès aux fonctions du rôle
- Disparaît de l'affichage par défaut dans `/biblioteca` onglet `team`
- Visible dans l'audit log et dans une vue « historique de l'équipe »

**Réversibilité** : aucune réversibilité directe. Pour ré-intégrer une personne, on **crée une nouvelle ligne** de membership (workflow standard via cooptation). L'historique est ainsi préservé et lisible.

### 4.6. Schéma de transitions des status

```
                    ┌──────────────┐
                    │   active     │ ◄──────────────────────────┐
                    └──────┬───────┘                            │
                           │                                    │
            ┌──────────────┼──────────────┐                     │
            ▼              ▼              ▼                     │
    ┌──────────────┐ ┌─────────────────┐ ┌──────────────┐       │
    │  suspended   │ │ pending_removal │ │   inactive   │       │
    └──────┬───────┘ └────────┬────────┘ └──────────────┘       │
           │                  │                                  │
           │ levée            │ annulation                       │
           └──────────────────┴──────────────────────────────────┘
                              │
                              ▼ (J+7 sans annulation)
                       ┌──────────────┐
                       │   inactive   │
                       └──────────────┘
```


---

## 5. Transitions et autorisations

### 5.1. Tableau récapitulatif *(v1.1 : « administrador » retiré, « network_admin » mentionné)*

| # | Transition | Qui peut le faire | Mécanisme |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coordenador local **OU** admin réseau actif | Cooptation (P2) |
| T2 | `librarian` → `coordenador` | **Trois personnes distinctes** *(v1.4)* : qui propose (coordenador local **OU** admin réseau actif), qui ratifie (autre membre du staff), qui accepte (l'intéressé·e) | Cooptation collégiale (P2), via le circuit d'invitation |
| T3 | `coordenador` → `librarian` | Soi-même + autres coordenadores locaux | Auto-rétro ou retrait collégial |
| T4 | `librarian` → `reader` (volontaire) | Soi-même | Auto-rétro (P3) |
| T5 | `librarian` → `reader` (par le collectif) | Coordenador local **OU** admin réseau (avec carence 7j) | `pending_removal` |
| T6 | Suspension immédiate (urgence) | Coordenador local **OU** admin réseau | Passage à `suspended` |
| T7 | Levée de suspension | Coordenador local **OU** admin réseau | Retour `suspended` → `active` |
| T8 | Annulation d'une demande de retrait | Coordenador local **OU** admin réseau | Retour `pending_removal` → `active` |
| T9 | Sortie automatique (compte abandonné) | Cron | Passage à `inactive` après 9 mois sans login + mails J-30 et J-7 |

**Note v1.1** : « admin réseau actif » signifie une personne dont `fn_caller_is_network_admin()` retourne TRUE. L'autorité transverse passe par les helpers centralisés (`user_can_act_as_staff_on_library`, `user_can_engage_library`), pas par une mention explicite dans les RPC. Les actions transverses sont tracées (cf. P7 v1.1).

**Note v1.1 — Transition T10 supprimée** : la transition `coordenador → administrador` qui figurait conceptuellement dans la v1.0 (sans être numérotée) est désormais explicitement hors périmètre. La cooptation au réseau d'administrateurs passe par `fn_network_admin_propose_cooptation` + vote à l'unanimité (cf. spec admin réseau v0.3.1 §4). Ce n'est pas une transition de rôle local, c'est une inscription **politique distincte** dans le périmètre réseau.

### 5.2. Détail de T1 — `reader` → `librarian` (cooptation)

**Qui** : un·e coordenador·a local·e **OU** un·e administrateur·rice réseau actif·ve, **avec autorisation `user_can_engage_library` sur la biblio cible**.

**Précondition** :
- La personne cible existe en tant qu'utilisateur·rice AnarBib (a un compte)
- La personne cible n'a pas déjà une membership `active` ou `pending_removal` ou `suspended` dans cette biblio avec un rôle staff (`librarian`/`coordenador`)
- La personne cible a typiquement une membership `reader` `active` dans cette biblio (cas nominal : on promeut un·e lecteur·rice). Cette ligne `reader` sera fermée par la promotion (cf. Effet).

**Effet** *(actualisé v1.2 — doctrine rôle exclusif)* :
- Création d'une nouvelle ligne `user_library_memberships` avec `role='librarian'`, `status='active'` (ou réactivation si une ligne `librarian` existait en `removed`/`inactive`)
- **Fermeture du membership `reader`** de la même biblio : la ligne `reader` passe à `status='removed'`. Les rôles sont exclusifs au sein d'une biblio — le rôle `librarian` englobe les capacités du `reader` (cf. §3.2). Une entrée d'audit `removal_completed` sur le rôle `reader` trace la fermeture.
- Mail à la personne concernée + à tous les coordenadores actifs de la biblio
- Audit log (entrée `promoted_to_librarian`)

**Note v1.1 (cross-library)** : si l'acteur·rice est admin réseau **sans** membership staff local sur la biblio cible, l'action est tracée dans `network_admin_cross_library_actions_log` (cf. spec admin réseau v0.3.1 §6.3.1 — action critique : promotion staff). Mail immédiat au staff local de la biblio.

**RPC** : `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid)`

### 5.3. Détail de T2 — `librarian` → `coordenador` (cooptation collégiale) *(refondu v1.4)*

> **Ce qui change en v1.4.** Jusqu'au 26/08/2026, T2 était un geste **unilatéral** : une seule
> personne, autorisée par `user_can_manage_library()`, en promouvait une autre, sur-le-champ et
> sans lui demander son avis. C'était le seul endroit du modèle où un rôle staff s'obtenait sans
> cooptation — P2 la prescrit pourtant pour **les deux** rôles — et le seul où une charge
> s'imposait sans consentement, alors que P3 fait de son abandon un droit. La transition emprunte
> désormais le circuit d'invitation existant (`library_team_invitations`), plutôt qu'un second
> appareil monté en parallèle.

**Qui** : trois personnes distinctes interviennent, et aucune ne peut en tenir deux à la fois.

1. **Qui propose** : un·e coordenador·a local·e **OU** un·e administrateur·rice réseau actif·ve
   (`user_can_manage_library` — proposer la coordination reste un acte de coordination). Nul ne
   peut se proposer soi-même.
2. **Qui ratifie** : un·e autre membre du staff actif de la biblio. La personne qui propose
   compte pour un endossement, enregistré d'office. La **voie médiane** s'applique : au moins un
   endossement doit venir de la coordination.
3. **Qui accepte** : la personne concernée, et elle seule.

**Quorum** *(règle existante du circuit d'invitation, conservée telle quelle)* :

| Situation | Endossements requis |
|---|---|
| `team_admission_mode = 'coordenador_seul'` | 1 |
| moins de 2 membres du staff **hors personne visée** | 1 |
| sinon | 2 |

La personne visée est **exclue du décompte** : elle est déjà staff, et l'inclure rendrait le
quorum inatteignable dans une équipe de deux — elle accepte, elle ne ratifie pas. Corollaire
pratique, à connaître avant de s'étonner : dans une petite équipe, la proposition peut passer
directement à `ready` sans qu'un second geste soit visible. Ce n'est pas un contournement du
principe, c'est le quorum tel qu'il a toujours été défini.

**Préconditions** :

- La personne cible a une membership `librarian` `active` dans cette biblio — on ne saute pas de
  `reader` à `coordenador` (précondition héritée de l'ancienne RPC).
- Elle n'a pas déjà une membership `coordenador` `active` dans cette biblio.
- Aucune invitation vivante (`pending_ratification` / `ready`) ne la concerne déjà sur cette biblio.

**Effet de la proposition** : **aucun changement de rôle.** Une ligne `library_team_invitations`
est créée avec `role_proposed = 'coordenador'`, `status = 'pending_ratification'` et
`expires_at = now() + 30 jours`. L'acte de coordination est tracé **à ce moment** dans
`network_admin_cross_library_actions_log` si l'acteur·rice est transverse (`stage: 'proposed'`),
et non à l'acceptation — celle-ci est le fait de la personne visée, pas un acte de gouvernance.
Event `team.invitation_proposed`, ou `team.invitation_ready` si le quorum est déjà atteint, avec
`role_proposed` au payload.

**Effet de l'acceptation** *(inchangé depuis la v1.2 — doctrine rôle exclusif)* :

- Création (ou réactivation) d'une ligne `coordenador` `active`
- **Fermeture du membership `librarian`** : passage à `status='removed'`, avec une entrée d'audit
  `removal_completed` sur le rôle `librarian`
- Audit log : entrée `promoted_to_coordenador`, `metadata.via = 'team_invitation_accepted'`, avec
  `invitation_id`, `proposed_by` et `required_ratifications` — la trace dit désormais *par quel
  chemin* la promotion est passée, pas seulement qu'elle a eu lieu
- Event `team.promoted_to_coordenador` — personne + coordenadores

**Péremption** : une proposition non aboutie expire au bout de 30 jours, balayée par le cron
`anarbib-team-invitations-expire` (cf. §12.3). Ne rien faire est donc une réponse : la proposition
se referme d'elle-même, sans que personne ait à la refuser explicitement — ce qui, dans un
collectif, coûte souvent plus cher que de laisser filer.

**RPCs** : `fn_team_propose_invitation(p_library_id uuid, p_invited_public_id text, p_role text
DEFAULT 'librarian')` → `fn_team_ratify_invitation(p_invitation_id uuid)` →
`fn_team_accept_invitation(p_invitation_id uuid)`, ou `fn_team_decline_invitation`.

⚠️ **`fn_team_promote_to_coordenador` ne promeut plus.** Elle est conservée — signature, droits,
références — mais lève `collegiality_required` (`ERRCODE 0A000`) en désignant explicitement le
chemin collégial. La supprimer aurait cassé ses appelants sur une erreur muette de PostgREST ;
une fonction qui répond « pas comme ça, mais comme ceci » les instruit.

**Note d'implémentation** *(v1.2, conservée)* : la contrainte UNIQUE `(user_id, library_id, role)`
est conservée — elle reste utile pour porter l'historique (une même personne peut avoir une ligne
`librarian` en `removed` *et* une ligne `coordenador` en `active`, ce qui retrace son parcours).
Mais la **doctrine « rôle exclusif »** impose qu'au plus **une seule ligne soit en
`status='active'`** par couple `(user_id, library_id)`. Une promotion ferme systématiquement le
rôle de rang inférieur ; une rétrogradation (T3, T5, cron) réactive le rôle du cran en dessous.
L'historique est ainsi intégralement préservé par les lignes non-actives (`removed`, `inactive`)
et par l'audit log, sans jamais cumuler deux lignes `active`. La v1.1 recommandait le
multi-membership actif (« filtrer à l'affichage le rôle de plus haut niveau ») : cette
recommandation est **abandonnée** — masquer en permanence une complexité à l'affichage est le
signe que cette complexité ne devait pas exister.

### 5.4. Détail de T3 — `coordenador` → `librarian`

**Qui** :
- **Soi-même** : sans validation tierce (P3)
- **Autres coordenadores locaux** : la rétrogradation par un·e autre coordenador·a est traitée comme une demande de retrait avec carence (7j), via `fn_team_request_remove_member` ciblant la membership `coordenador`. Le statut passe à `pending_removal`. Cf. T5.

**RPC pour auto-rétro** : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`

**Effet self-demote** :
- La membership `coordenador` actuelle passe à `inactive` (avec `restricted_reason='self_demoted'` ou métadonnée équivalente)
- Si la personne avait déjà une membership `librarian` active, elle est conservée
- Sinon, une nouvelle membership `librarian` est créée
- Mail à toute la coordination + à la personne (confirmation)
- Audit log

**Note v1.1** : la branche « last admin lockdown » qui figurait dans la v1.0 de `fn_team_self_demote` (refus si dernier·e coordenador·a actif·ve) a été **supprimée au paquet F.3 admin réseau** (13/05/2026). La sortie est désormais inconditionnellement autorisée, avec escalade aux admins réseau si elle laisse la biblio sans coordination (cf. §6.1). Cohérent avec P1 (rotation des fonctions) et la souveraineté politique du collectif local.

### 5.5. Détail de T4 — `librarian` → `reader` (auto-rétro)

**Qui** : la personne elle-même.

**Effet** :
- La membership `librarian` passe à `inactive`
- La membership `reader` (qui doit exister) reste `active`. Si elle n'existe pas, elle est créée.
- Mail à toute la coordination + à la personne
- Audit log

**RPC** : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'reader')`

### 5.6. Détail de T5 — `librarian` → `reader` (par le collectif, avec carence)

**Qui** : un·e coordenador·a local·e **OU** un·e administrateur·rice réseau actif·ve.

**Précondition** :
- La personne cible a une membership `librarian` `active` dans cette biblio
- L'auteur·rice de la demande n'est pas la personne cible (sinon utiliser T4)

**Effet immédiat** :
- La membership passe à `pending_removal`
- Champ `pending_removal_until` rempli avec `now() + interval '7 days'`
- Champ `pending_removal_requested_by` rempli avec `auth.uid()`
- Mail à la personne concernée + à tous les coordenadores actifs
- Audit log
- Si admin réseau cross-library : log dans `network_admin_cross_library_actions_log` + mail immédiat staff local

**Effet à J+7** (cron, cf. §12) *(actualisé v1.2)* :
- Si toujours `pending_removal` : la membership passe à `status='removed'`
- **Rétrogradation d'un cran** : la personne n'est pas exclue de la biblio, elle redescend au rôle inférieur. Pour un retrait `librarian`, le membership `reader` est réactivé (ou créé s'il n'existe pas) en `active`. Pour un retrait `coordenador` (même mécanisme via T3 collectif), c'est le membership `librarian` qui est réactivé. Ceci respecte la doctrine rôle exclusif : à tout instant, une seule ligne `active` par `(user_id, library_id)`.
- Mail confirmation à la personne + à toute la coordination
- Audit log : entrée `removal_completed` sur le rôle retiré + entrée traçant la réactivation du rôle inférieur

**RPC** : `fn_team_request_remove_member(p_user_id uuid, p_library_id uuid, p_role text, p_reason text DEFAULT NULL)`

### 5.7. Détail de T6 — Suspension immédiate (urgence)

**Qui** : un·e coordenador·a local·e **OU** un·e administrateur·rice réseau actif·ve.

**Cas d'usage** :
- Harcèlement signalé urgent
- Compte compromis (mot de passe leaké)
- Comportement manifestement abusif

**Effet** :
- La membership passe à `suspended`
- Aucun accès jusqu'à levée
- Mail à la personne + à toute la coordination
- Audit log
- Si admin réseau cross-library : log + mail immédiat staff local (action critique selon spec admin réseau §6.3.1)

**Durée** : indéfinie. La suspension n'est **pas** un délai de carence avant exclusion ; c'est une mesure conservatoire qui peut durer le temps nécessaire à la délibération collective.

**RPC** : `fn_team_suspend_member(p_user_id uuid, p_library_id uuid, p_role text, p_reason text)`

**Note** : cette RPC requiert un `p_reason` non null (justification obligatoire). Le champ est journalisé dans l'audit log et le mail.

### 5.8. Détail de T7 — Levée de suspension

**Qui** : un·e coordenador·a local·e **OU** un·e administrateur·rice réseau actif·ve (pas obligatoirement celui·celle qui a suspendu).

**Effet** :
- Retour à `active`
- Mail à la personne + à toute la coordination
- Audit log

**RPC** : `fn_team_unsuspend_member(p_user_id uuid, p_library_id uuid, p_role text)`

### 5.9. Détail de T8 — Annulation d'une demande de retrait

**Qui** : un·e coordenador·a local·e **OU** un·e administrateur·rice réseau actif·ve (mécanisme de contrôle collégial).

**Effet** :
- La membership en `pending_removal` repasse à `active`
- Champ `pending_removal_until` remis à NULL
- Mail à la personne + à toute la coordination
- Audit log

**RPC** : `fn_team_cancel_remove_member(p_user_id uuid, p_library_id uuid, p_role text)`

### 5.10. Détail de T9 — Sortie automatique (compte abandonné)

**Critère** : le user n'a pas eu de session active depuis **9 mois**.

**Source du critère** : `auth.users.last_sign_in_at` côté Supabase. À auditer en implémentation pour s'assurer que ce champ est bien mis à jour à chaque login.

**Workflow** :

1. **J-9 mois - 30 jours** : mail d'avertissement à la personne (« votre membership va être désactivée dans 30 jours sans connexion »).
2. **J-9 mois - 7 jours** : mail de rappel à la personne **et copie à la coordination** (tous les `coordenador` actifs de la biblio). *(amendé v1.3)* Si la personne inactive est elle-même le·la **dernier·e coordenador·a** de la biblio — donc s'il n'existe aucun·e autre coordenador·a à mettre en copie —, la copie est **escaladée aux administrateur·rices du réseau** (table `network_administrators` `status='active'`), selon le même mécanisme que l'escalade « dernier·e coordenador·a » de §6.1.
3. **J-9 mois** : passage à `inactive` automatique. Mail final à la personne + à toute la coordination.

**Important** :
- Cette sortie automatique s'applique aussi aux `coordenador`. Si c'est le·la dernier·e coordenador·a, le cron escalade aux administrateurs **réseau** avant exécution (cf. §6.1).
- Une simple **connexion** suffit à réinitialiser le compteur (le cron lit `last_sign_in_at`).

**Cron** : `cron_team_inactive_cleanup` (cf. §12.2).


---

## 6. Cas-limites et garde-fous

### 6.1. Biblio avec un·e seul·e coordenador·a qui démissionne

**Scénario** : la personne déclenche `fn_team_self_demote` ou tente une action qui ferait passer la biblio à 0 coordenador·a actif·ve.

**Comportement** *(actualisé v1.1)* :

1. **Avertissement** : la RPC vérifie qu'on est dans ce cas et **autorise** l'opération mais retourne un avertissement structuré (`{warning: 'last_coordinator_leaving'}`).
2. **Sortie effective** : la biblio se retrouve avec 0 coordenador·a. Les librarians peuvent continuer à fonctionner sur leurs prérogatives (gestion emprunts, validation inscriptions, etc.) mais aucune modification de l'identité publique ou de la configuration n'est possible.
3. **Escalade automatique** : un mail est envoyé aux **administrateurs du réseau AnarBib** (table `network_administrators` `status='active'`), indiquant que la biblio X est en mode « sans coord ». Iels peuvent intervenir pour aider le collectif à désigner un·e nouveau·elle coordenador·a — *(v1.4)* en **proposant** la promotion via `fn_team_propose_invitation` (rôle `coordenador`), la proposition restant soumise à ratification puis acceptation (cf. §5.3) : le droit transverse permet de proposer, plus de promouvoir seul·e — ou aider à fermer proprement la biblio.

**Note politique** : ce comportement respecte la souveraineté du collectif (le SIGB ne bloque pas la décision) tout en évitant le chaos silencieux (escalade explicite). Notez que la branche « last admin lockdown » qui bloquait techniquement la sortie en v1.0 a été supprimée au paquet F.3 (13/05/2026).

### 6.2. Auto-promotion impossible

Personne ne peut se promouvoir lui-même à un rôle supérieur. Toutes les RPC de promotion vérifient `p_user_id != auth.uid()`.

### 6.3. *(Supprimée v1.1)* Coordenador→administrador interdite via UI

Cette section devient sans objet : le rôle `administrador` local n'existe plus dans `user_library_memberships.role`. La cooptation au réseau d'administrateurs est un mécanisme **politique distinct** (cf. spec admin réseau v0.3.1 §4), pas une transition de rôle local.

La RPC `fn_team_promote_to_administrador` qui existait en v1.0 a été **dépréciée** au paquet D.8 admin réseau (13/05/2026) puis **supprimée** au paquet F. Toute tentative d'appel retourne une erreur de fonction inexistante.

### 6.4. Biblio sans aucun staff (cas pathologique)

**Scénario** : tous les staff actifs (librarians + coordenadores) deviennent `inactive` simultanément.

**Comportement** *(actualisé v1.1)* :
- La biblio reste « active » techniquement (sa visibility, ses livres, sont accessibles selon RLS)
- Mais aucune action de gestion locale ne peut plus être faite par le staff local
- Mail urgent aux administrateurs du réseau AnarBib
- Les administrateurs réseau peuvent intervenir directement via leur droit transverse pour : (a) *(v1.4)* **proposer** une membership `coordenador` via `fn_team_propose_invitation` (rôle `coordenador`) après validation politique du collectif local — la proposition doit ensuite être ratifiée puis acceptée (§5.3), ou (b) accompagner la fermeture de la biblio (procédure hors-spec)

**Différence avec v1.0** : la v1.0 mentionnait « modification SQL directe » par un admin AnarBib. Depuis le paquet D admin réseau, cette action passe par la RPC normale, simplement appelée par un·e admin réseau (autorisée par les helpers `user_can_act_as_staff_on_library` et `user_can_engage_library`). Plus de bypass SQL, tracé dans `network_admin_cross_library_actions_log`.

### 6.5. Plusieurs lignes de membership pour la même personne *(refonte v1.2)*

**Principe — doctrine « rôle exclusif »** : au sein d'une même biblio, une personne n'a **qu'un seul rôle actif** à la fois. Il ne peut jamais y avoir deux lignes `user_library_memberships` en `status='active'` pour un même couple `(user_id, library_id)`.

**Ce que la contrainte UNIQUE autorise** : la contrainte `(user_id, library_id, role)` permet techniquement plusieurs *lignes* pour une même personne dans une même biblio — mais c'est pour porter l'**historique**, pas pour cumuler des rôles actifs. Exemple typique d'une personne promue deux fois : une ligne `reader` en `status='removed'`, une ligne `librarian` en `status='removed'`, une ligne `coordenador` en `status='active'`. Trois lignes, une seule active : son parcours est lisible, son rôle courant est sans ambiguïté.

**Transitions** : une promotion ferme le rôle inférieur (`removed`) ; une rétrogradation ou un retrait par le collectif réactive le rôle du cran en dessous. Cf. §5.3, §5.6, §12.1.

**Règle d'affichage** :
- Dans l'UI onglet `team`, la personne apparaît une seule fois, avec son unique rôle actif (plus besoin de « filtrer le plus haut niveau » : il n'y en a qu'un)
- Si la personne est aussi admin réseau, un `<NetworkAdminBadge>` supplémentaire s'affiche à côté du badge local (cf. spec admin réseau v0.3.1 §7.2), sans ligne supplémentaire
- L'audit log affiche les changements ligne par ligne (chaque membership a son histoire)

**Règle de RPC** : les RPCs `fn_team_*` opèrent sur une membership précise, identifiée par `(user_id, library_id, role)`. Pas d'ambiguïté.

**Note v1.2** : la v1.1 décrivait ici le multi-membership actif (`reader` + `librarian` simultanément `active`) comme un « cas accepté ». Ce n'est plus le cas — voir Annexe D pour la décision et son argumentaire.

### 6.6. Interactions entre suspension et pending_removal

**Cas 1** : une personne est `suspended`. On veut l'exclure définitivement.
→ La RPC `fn_team_request_remove_member` n'autorise pas le passage `suspended` → `pending_removal` (les deux sont des états « bloqués »). Pour exclure, il faut d'abord lever la suspension (`fn_team_unsuspend_member`) puis demander le retrait. Cette double étape est **volontaire** : elle force le collectif à acter explicitement la transition.

**Cas 2** : une personne est en `pending_removal`. Un·e coordenador·a veut accélérer.
→ Pas autorisé. Le délai de 7 jours est un garde-fou politique, pas une option. La seule façon d'aller plus vite est : (a) la personne se retire elle-même (T4) ; (b) la suspension immédiate (T6) si l'urgence le justifie (et auquel cas le `pending_removal` initial doit d'abord être annulé).

### 6.7. Tentative de demander le retrait de soi-même

**Comportement** : la RPC retourne une erreur explicite : « pour quitter l'équipe, utilisez l'option "Je passe la main" (auto-rétrogradation) ». Cette distinction est intentionnelle : la spec ne permet pas de confondre une décision personnelle (T4) et une décision collective (T5).

### 6.8. Tentative de promouvoir une personne déjà au même niveau

**Comportement** : retour idempotent (succès silencieux). La RPC vérifie l'état avant action ; si la personne est déjà `librarian` actif, la RPC `fn_team_promote_to_librarian` ne fait rien et retourne `{ok: true, no_change: true}`.

### 6.9. *(Refonte v1.1)* Tentative d'agir sur un·e administrateur·rice réseau via les RPC `fn_team_*`

**Comportement** : les RPC `fn_team_request_remove_member`, `fn_team_self_demote`, `fn_team_suspend_member` ont été **modifiées au paquet C admin réseau (11/05/2026)** pour refuser toute action sur des admins réseau. Si la cible (`p_user_id`) est dans `network_administrators` avec `status='active'`, la RPC retourne une erreur explicite : « cette personne est administrateur·rice du réseau ; le retrait passe par les RPC dédiées (cf. spec admin réseau v0.3.1) ».

Le retrait d'un·e admin réseau passe par :
- **Auto-retrait** : `fn_network_admin_self_remove` (cf. spec admin réseau §4.4)
- **Retrait collectif** : `fn_network_admin_propose_collective_removal` + vote à l'unanimité (cf. spec admin réseau §4.2.2)

Cette séparation reflète la séparation politique : le staff local d'une biblio n'a pas pouvoir politique sur l'inscription réseau d'une personne, même si elle agit sur leur biblio.

### 6.10. Impact sur les emprunts en cours d'un·e librarian destitué·e

**Scénario** : un·e librarian a des emprunts en cours d'un·e lecteur·rice, et est destitué·e (passage à `inactive`).

**Comportement** :
- Les emprunts en cours **persistent** (ils sont liés au lecteur·rice, pas au librarian qui les a saisis)
- L'historique des actions du librarian dans le système est conservé (audit logs des emprunts, etc.)
- La personne peut redevenir membre plus tard (nouvelle ligne de membership) sans que ses anciens emprunts soient affectés

### 6.11. *(Nouveau v1.1)* Articulation avec le `governance_mode` de la spec profils

Les RPC de cette spec vérifient en début d'exécution le `governance_mode` de la biblio cible (champ ajouté par le paquet A spec profils, à venir) :

- `governance_mode = 'informal'` : toutes les RPC `fn_team_*` retournent une erreur explicite : « cette biblio fonctionne en mode informel, il n'y a pas de rôles staff distincts à gérer ». L'UI n'expose simplement pas l'onglet Équipe.
- `governance_mode = 'staff_roles'` : RPC `fn_team_promote_to_librarian`, `fn_team_self_demote` actives. RPC `fn_team_request_remove_member`, `fn_team_suspend_member`, `fn_team_cancel_remove_member`, `fn_team_unsuspend_member` retournent une erreur : « les mécanismes de carence/suspension ne sont pas activés dans ce mode ; passez en `full_governance` ou agissez hors logiciel ».
- `governance_mode = 'full_governance'` : doctrine intégrale, toutes les RPC actives.

**Implémentation** : à prévoir au paquet F de la spec profils. En attendant, toutes les biblios fonctionnent implicitement en `full_governance`.

---

## 7. Audit log

### 7.1. Principe (P5 — Transparence maximale)

Tous les changements de rôle et de status sont **journalisés** dans une table dédiée. La consultation est :

- **Public au staff actif de la biblio** : tout `librarian`, `coordenador` actif·ve dans la biblio peut lire l'audit log de cette biblio. **Les administrateurs réseau** y ont aussi accès au titre de leur droit transverse (via le helper `user_can_act_as_staff_on_library`).
- **Privé au reader** : un·e reader ne voit pas l'audit log de l'équipe (ce n'est pas une donnée publique du catalogue).
- **Privé inter-biblios** : les staff d'une biblio A ne voient pas l'audit de la biblio B (sauf admin réseau via droit transverse).

### 7.2. Contenu d'une entrée

Chaque action génère **une entrée** dans `library_membership_audit` :

| Champ | Type | Description |
|---|---|---|
| `id` | uuid PK | identifiant unique de l'entrée |
| `library_id` | uuid FK | biblio concernée |
| `target_user_id` | uuid FK | personne dont la membership a changé |
| `actor_user_id` | uuid FK | personne qui a effectué l'action (NULL si cron) |
| `action` | text | code de l'action (cf. §7.3) |
| `role` | text | rôle concerné (`reader`, `librarian`, `coordenador`) — `'administrador'` retiré v1.1 |
| `status_before` | text | status avant (peut être NULL pour création) |
| `status_after` | text | status après |
| `reason` | text | justification (peut être NULL ; obligatoire pour suspend, optionnelle ailleurs) |
| `metadata` | jsonb | données contextuelles (ex : pending_removal_until, cross_library_action flag, etc.) |
| `created_at` | timestamptz | horodatage de l'action |

### 7.3. Codes d'action

| Code | Description | RPC source |
|---|---|---|
| `promoted_to_librarian` | T1 | `fn_team_promote_to_librarian` |
| `promoted_to_coordenador` | T2 | `fn_team_accept_invitation` *(v1.4 ; auparavant `fn_team_promote_to_coordenador`)* |
| `self_demoted` | T3 (auto-rétro coord) ou T4 (auto-rétro librarian) | `fn_team_self_demote` |
| `removal_requested` | T5 (déclenchement carence) | `fn_team_request_remove_member` |
| `removal_cancelled` | T8 (annulation) | `fn_team_cancel_remove_member` |
| `removal_completed` | T5 (fin carence, J+7) | cron `cron_team_pending_removal_complete` |
| `suspended` | T6 | `fn_team_suspend_member` |
| `unsuspended` | T7 | `fn_team_unsuspend_member` |
| `inactive_warning_30d` | T9 (mail J-30) | cron `cron_team_inactive_cleanup` |
| `inactive_warning_7d` | T9 (mail J-7) | cron `cron_team_inactive_cleanup` |
| `inactive_auto` | T9 (sortie auto J-9 mois) | cron `cron_team_inactive_cleanup` |

**Note v1.1** : les actions transverses d'un·e admin réseau (par exemple `fn_team_suspend_member` appelé par un admin réseau sans staff local sur la biblio) génèrent **2 entrées** d'audit complémentaires :
- Une entrée dans `library_membership_audit` (cette table) avec `metadata.cross_library = true` et `metadata.actor_role = 'network_admin'`
- Une entrée dans `network_admin_cross_library_actions_log` (table d'audit réseau, paquet C.5 admin réseau)

La duplication intentionnelle garantit la visibilité côté staff local **et** côté audit réseau, sans dépendre d'une jointure complexe.

### 7.4. Écriture

L'écriture est faite **directement par les RPCs SECURITY DEFINER** (pas via trigger). Cela permet de capturer le contexte applicatif (`actor_user_id`, `reason`) qui ne serait pas accessible dans un trigger.

### 7.5. RLS de la table audit

```sql
-- Lecture : staff actif de la biblio uniquement (inclut admin réseau via le helper)
CREATE POLICY library_membership_audit_staff_read
ON public.library_membership_audit
FOR SELECT
TO authenticated
USING (
  public.user_can_act_as_staff_on_library(library_id)  -- v1.1 : helper centralisé
);

-- Écriture : aucune policy. Seules les RPCs SECURITY DEFINER y accèdent.
```

**Note v1.1** : le helper `user_has_library_staff_role` qui figurait en v1.0 a été **refactoré au paquet C admin réseau** comme wrapper de `user_can_act_as_staff_on_library`. La RLS continue de fonctionner, et inclut désormais les admins réseau (cohérent avec la transparence collective).

### 7.6. Rétention

Les entrées d'audit sont **conservées indéfiniment**. Elles font partie de l'histoire collective de la biblio.

Cas de suppression : si une biblio ferme (cf. workflow de fermeture, hors spec), les audit logs sont archivés ou supprimés selon la politique RGPD applicable.


---

## 8. Notifications mail

### 8.1. Principe (P6 — Notifications systématiques)

**Tout changement de rôle déclenche un email** :
- À la **personne concernée** (toujours)
- À **tous les coordenadores actifs** de la biblio (toujours)
- Aux **administrateurs du réseau AnarBib** dans certains cas critiques (compte abandonné détecté sur le·la dernier·e coord, biblio sans staff, actions cross-library critiques, etc.)

### 8.2. Pattern d'event types

Les events suivent le préfixe `team.*` (cohérent avec `loan.*`, `res.*`, `wf.*` existants).

| Event type | Déclenché par | Destinataires |
|---|---|---|
| `team.promoted_to_librarian` | T1 | personne + coordenadores |
| `team.promoted_to_coordenador` | T2 | personne + coordenadores |
| `team.self_demoted` | T3, T4 | personne + coordenadores |
| `team.removal_requested` | T5 | personne + coordenadores |
| `team.removal_cancelled` | T8 | personne + coordenadores |
| `team.removal_completed` | T5 (J+7) | personne + coordenadores |
| `team.invitation_proposed` *(T2 depuis v1.4)* | T1/T2 — proposition déposée | coordenadores de la biblio, à endosser |
| `team.invitation_ready` *(T2 depuis v1.4)* | T1/T2 — quorum atteint | la personne concernée, à accepter |
| `team.suspended` | T6 | personne + coordenadores |
| `team.unsuspended` | T7 | personne + coordenadores |
| `team.inactive_warning_30d` | T9 (J-30) | personne uniquement |
| `team.inactive_warning_7d` | T9 (J-7) | personne + coordenadores *(amendé v1.3)* |
| `team.inactive_auto` | T9 (J-9 mois) | personne + coordenadores |
| `team.last_coordinator_leaving` | §6.1 | administrateurs du réseau uniquement |

**Note v1.1** : pour les events liés à une action transverse (admin réseau sur biblio dont il n'est pas staff local), le mail au staff local mentionne explicitement « action réalisée par un·e administrateur·rice du réseau AnarBib » (clé i18n dédiée). Cohérent avec la transparence du droit transverse.

**Note v1.3** : le seuil J-7 (`inactive_warning_7d`) notifie désormais la coordination en copie, et non plus la seule personne concernée — afin que la coordination soit alertée d'une inactivité critique avant la sortie automatique. Si la personne inactive est le·la dernier·e coordenador·a, la copie est escaladée aux administrateur·rices du réseau (cf. §5.10 et §6.1). Le seuil J-30 (`inactive_warning_30d`) reste, lui, adressé à la personne uniquement : un mois avant l'échéance, l'information est encore strictement individuelle.

### 8.3. Clés i18n nécessaires

Les chaînes i18n pour les mails sont dans `supabase/functions/_shared/i18n/mail-strings.ts` × 6 locales (pt-BR, fr, es, en, it, de) selon les conventions militantes établies.

**Liste minimale** (le détail des chaînes sera précisé à l'implémentation) :

```
team.promoted_to_librarian.intro       (corps du mail à la personne promue)
team.promoted_to_librarian.sub         (sous-titre / contexte)
team.promoted_to_librarian.coord_intro (corps du mail aux coordenadores)
team.promoted_to_coordenador.intro
...
```

Soit environ **40-60 clés × 10 locales = 400 à 600 chaînes** *(corrigé v1.4 — le « 6 » est une trace périmée, cf. `DOC-I18N-1` du registre : pt-BR, fr, es, it, de, en, ca, eo, nl, el)*. Les mails du passage à la coordination ont leurs propres clés, distinctes de celles de l'accueil : `team.invitation_coord_proposed.*` et `team.invitation_coord_ready.*` — accueillir quelqu'un et lui confier la coordination ne sont pas le même acte, et les deux textes ne doivent pas se ressembler.

### 8.4. Gabarit type

Pour chaque event, le mail contient :

- **Salutation** (`greeting.named` existant, prénom de la personne)
- **Sujet de la notification** (« Tu as été nommé·e librarian de la biblio X », « La coordination te demande de quitter l'équipe (préavis 7 jours) », etc.)
- **Contexte / explication** (les conséquences pratiques)
- **Mention de l'auteur·rice de la décision** (« nommé·e par <prénom du coord>, le <date> »)
- **Le cas échéant, raison/justification** (si fournie, ex pour suspension)
- **Le cas échéant, action attendue** (« Tu peux annuler en répondant à ce mail OU en utilisant l'option dédiée dans /biblioteca »)
- **Footer standard** (`layout.footerContact`, `layout.keepMsg` existants)

### 8.5. Intégration dans `notify-event`

Le pattern actuel de `notify-event` est :
1. Trigger DB ou RPC INSERT dans `team_notification_outbox`
2. Edge Function `notify-event` lit l'outbox et dispatche via les handlers
3. Mail envoyé avec les chaînes i18n correspondantes

**Pour cette spec** :
- Les RPCs `fn_team_*` insèrent dans l'outbox via `fn_team_notify_event` (helper symétrique à `fn_network_notify_event`, cf. paquet D.6bis admin réseau)
- Pattern doctrinal : **un INSERT par event**, fan-out réalisé par l'Edge Function en lisant le payload JSONB

---

## 9. Interface utilisateur·rice

### 9.1. Localisation

Toutes les actions sont dans **`/biblioteca`, onglet `team`**.

L'onglet `team` existe déjà et affiche actuellement la liste des membres en lecture seule. Cette spec **enrichit** cet onglet sans changer sa localisation.

### 9.2. Visibilité de l'onglet

L'onglet `team` est visible :
- En **lecture seule** pour les `librarian` actifs (peuvent voir l'équipe, l'audit log, mais pas agir)
- En **mode action** pour les `coordenador` actifs **OU** les administrateurs réseau actifs (peuvent promouvoir, retirer, suspendre, etc.)

### 9.3. Structure proposée

```
┌─────────────────────────────────────────────────────────────┐
│ /biblioteca - onglet "Equipe"                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─ Membres actifs ────────────────────────────────────┐   │
│  │                                                       │   │
│  │  Emma G.          librarian       [Promouvoir] [Retirer] │   │
│  │  emma@blmf.org                                       │   │
│  │                                                       │   │
│  │  Voltairine d.C. coordenador  [Admin réseau]   [Rétrograder] │
│  │  voltairine@blmf.org                                 │   │
│  │                                                       │   │
│  │  ...                                                  │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                             │
│  [+ Inviter quelqu'un dans l'équipe]                        │
│                                                             │
│  ┌─ Suspensions et préavis en cours ────────────────────┐   │
│  │  Karl M.  suspended (raison: ...)   [Lever suspension] │   │
│  │  Lucy P.  pending_removal jusqu'au 12/05  [Annuler]   │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─ Historique de l'équipe ─────────────────────────────┐   │
│  │  05/05 11:23 - Voltairine a promu Emma librarian     │   │
│  │  03/05 18:45 - Lucy a auto-rétrogradé coordenador→…  │   │
│  │  ...                                                   │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Note v1.1** : le badge `[Admin réseau]` ajouté à côté du badge local (cf. exemple Voltairine ci-dessus) reflète la séparation politique. Implémenté via `<NetworkAdminBadge>` (paquet E.3 admin réseau).

### 9.4. Comportements UI précis *(refonte v1.1)*

**Pour un·e librarian actif·ve** (lecture seule) :
- Voit la liste des membres avec leurs rôles
- Voit la section « Suspensions et préavis en cours » (transparence P5)
- Voit l'audit log
- Pas de boutons d'action (sauf « Je passe la main » sur sa propre ligne)

**Pour un·e coordenador·a actif·ve** :
- Tout ce que voit un·e librarian
- Boutons d'action sur chaque membre (sauf eux·elles-mêmes pour les actions interdites par §6.2)
- Bouton « Inviter quelqu'un dans l'équipe » (workflow d'invitation cf. spec future)
- Action « Je passe la main » sur sa propre ligne (auto-rétro)

**Pour un·e administrateur·rice réseau actif·ve** (v1.1) :
- Tout ce que voit un·e coordenador·a, **sur n'importe quelle biblio du réseau**
- Visibilité : badge `[Admin réseau]` affiché à côté du badge local sur sa propre ligne (s'il/elle a aussi un membership local)
- Pas d'action spéciale supplémentaire dans l'UI de cet onglet (les actions réseau sont dans `/rede` onglet Administradores, cf. spec admin réseau v0.3.1 §7.5)

### 9.5. Modales de confirmation

Toute action **non triviale** ouvre une modale de confirmation :

- **Promouvoir** : modale simple « Êtes-vous sûr·e de vouloir promouvoir <nom> à <rôle> ? » + champ optionnel « Raison » + boutons [Confirmer] / [Annuler].
- **Suspendre** : modale avec champ **obligatoire** « Raison de la suspension » + alerte « La personne sera notifiée par mail ».
- **Demander l'exclusion** : modale forte, rouge, avec mention du délai de carence 7j explicite, raison optionnelle, et confirmation explicite « Je comprends que cette demande prendra effet le <date J+7> sauf annulation par un·e autre coordenador·a ».
- **Lever suspension / Annuler exclusion** : modales simples « Êtes-vous sûr·e ? ».
- **Auto-rétrogradation** : modale **obligatoire** avec mention claire des conséquences (« Vous perdrez les permissions de coordenador·a immédiatement. Cette action est réversible uniquement par un·e autre coordenador·a »).

**Note v1.1** : la phrase rituelle « last admin lockdown » qui figurait dans la modale d'auto-rétrogradation en v1.0 a été **supprimée au paquet F.3** en même temps que la branche de blocage dans la RPC. Le coordenador·a sortant·e n'a plus à valider de mention spéciale ; l'escalade admin réseau est silencieuse côté UI (mail aux admins réseau).

### 9.6. États visuels

Les badges de statut affichés sur chaque ligne :

| Status DB | Badge UI | Couleur |
|---|---|---|
| `active` | rôle (ex « librarian ») | vert / neutre |
| `suspended` | « suspendu·e » | orange |
| `pending_removal` | « préavis jusqu'au <date> » | rouge |
| `inactive` | (n'apparaît pas dans la liste par défaut) | n/a |

Badge complémentaire :

| Condition | Badge UI |
|---|---|
| `isNetworkAdmin = true` (v1.1) | « Admin réseau » à côté du badge local |

### 9.7. Internationalisation

Toutes les chaînes UI utilisent le pattern i18n existant (`useIntl`, `t({id: 'biblioteca.team.*'})`). Les clés nécessaires (~40 clés × 6 locales = 240 chaînes), à livrer en un seul lot via un script Python idempotent.


---

## 10. Modèle de données

### 10.1. Modifications de la table existante *(actualisé v1.1)*

**Table `user_library_memberships`** : modifications appliquées en plusieurs paquets entre le 5/05/2026 et le 13/05/2026.

```sql
-- 1. Élargissement du CHECK constraint sur status (paquet 23 du 11/05/2026)
ALTER TABLE public.user_library_memberships
  DROP CONSTRAINT user_library_memberships_status_check;

ALTER TABLE public.user_library_memberships
  ADD CONSTRAINT user_library_memberships_status_check
  CHECK (status IN ('active', 'inactive', 'pending', 'pending_removal', 'suspended', 'removed'));
  -- 'removed' ajouté pour cohérence avec network_administrators

-- 2. Ajout des colonnes pour le délai de carence (paquet 1 spec gouvernance)
ALTER TABLE public.user_library_memberships
  ADD COLUMN IF NOT EXISTS pending_removal_until timestamptz,
  ADD COLUMN IF NOT EXISTS pending_removal_requested_by uuid REFERENCES public.profiles(id);

COMMENT ON COLUMN public.user_library_memberships.pending_removal_until IS
  'Date à laquelle le passage automatique en inactive aura lieu. NULL si pas en cours.';
COMMENT ON COLUMN public.user_library_memberships.pending_removal_requested_by IS
  'User qui a demandé le retrait, pour traçabilité audit.';

-- 3. Index pour le cron (recherche rapide des memberships en pending_removal)
CREATE INDEX IF NOT EXISTS idx_ulm_pending_removal_until
  ON public.user_library_memberships (pending_removal_until)
  WHERE status = 'pending_removal';

-- 4. Rétrécissement du CHECK constraint sur role (paquet F admin réseau du 13/05/2026)
ALTER TABLE public.user_library_memberships
  DROP CONSTRAINT user_library_memberships_role_check;

ALTER TABLE public.user_library_memberships
  ADD CONSTRAINT user_library_memberships_role_check 
  CHECK (role IN ('reader', 'librarian', 'coordenador'));
  -- 'administrador' retiré : remplacé par la table network_administrators
```

### 10.2. Nouvelle table `library_membership_audit`

```sql
CREATE TABLE public.library_membership_audit (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id      uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  target_user_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_user_id   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action          text NOT NULL CHECK (action IN (
                    'promoted_to_librarian',
                    'promoted_to_coordenador',
                    'self_demoted',
                    'removal_requested',
                    'removal_cancelled',
                    'removal_completed',
                    'suspended',
                    'unsuspended',
                    'inactive_warning_30d',
                    'inactive_warning_7d',
                    'inactive_auto'
                  )),
  role            text NOT NULL CHECK (role IN ('reader', 'librarian', 'coordenador')),  -- v1.1 : 'administrador' retiré
  status_before   text,
  status_after    text NOT NULL,
  reason          text,
  metadata        jsonb DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_lma_library_created
  ON public.library_membership_audit (library_id, created_at DESC);

CREATE INDEX idx_lma_target_user
  ON public.library_membership_audit (target_user_id);

ALTER TABLE public.library_membership_audit ENABLE ROW LEVEL SECURITY;

-- Lecture : staff actif de la biblio (inclut admin réseau via le helper centralisé)
CREATE POLICY library_membership_audit_staff_read
ON public.library_membership_audit
FOR SELECT
TO authenticated
USING (
  public.user_can_act_as_staff_on_library(library_id)  -- v1.1 : helper centralisé
);

-- Pas de policy d'écriture : seules les RPC SECURITY DEFINER y accèdent
COMMENT ON TABLE public.library_membership_audit IS
  'Journal des changements de rôle/status dans les équipes de biblio. Lecture pour le staff actif (transparence P5). Écriture uniquement via RPC SECURITY DEFINER.';
```

### 10.3. Pas de modification de la contrainte UNIQUE *(actualisé v1.2)*

La contrainte `(user_id, library_id, role)` est conservée telle quelle. Elle permet de garder, pour une même personne dans une biblio, plusieurs lignes de rôles différents — ce qui sert à **porter l'historique** : les rôles passés restent en base avec `status='removed'` (ou `inactive`), tandis qu'un seul rôle est `active`.

**La contrainte n'autorise pas le multi-membership *actif*.** L'unicité de la ligne `active` n'est pas garantie par une contrainte SQL mais par la **doctrine « rôle exclusif »** (v1.2), appliquée par les RPC : toute promotion ferme le rôle inférieur, toute rétrogradation réactive le cran en dessous. L'invariant « au plus une ligne `active` par `(user_id, library_id)` » est donc maintenu *par la logique applicative*, pas par le schéma.

*(Note : une contrainte d'exclusion partielle de type `EXCLUDE … WHERE (status = 'active')` pourrait à terme matérialiser cet invariant au niveau SQL. Non retenu en v1.2 — la doctrine est jeune, mieux vaut laisser les RPC la porter et observer ; à reconsidérer si un bug de double-membership actif réapparaissait malgré les RPC. Noté comme piste, pas comme dette.)*

---

## 11. API : RPC SECURITY DEFINER

### 11.1. Conventions

Toutes les RPCs respectent les règles suivantes :

- Préfixe : `fn_team_*`
- `LANGUAGE plpgsql SECURITY DEFINER`
- `SET search_path = public, pg_temp`
- Vérifications d'autorisation explicites en début de fonction (pattern `IF NOT user_can_engage_library(...) THEN RAISE EXCEPTION 'unauthorized' END IF` — v1.1 : helper centralisé)
- Retournent `jsonb` structuré : `{ok: true|false, action: '...', warnings: [], errors: []}`
- Écrivent dans `library_membership_audit` à chaque action réussie
- Émettent un event `team.*` via `fn_team_notify_event` (helper INSERT outbox) à chaque action réussie
- **(v1.1)** Si l'acteur·rice est admin réseau cross-library : `PERFORM fn_log_cross_library_action` après audit local et avant notification mail (cf. spec admin réseau v0.3.1 §6.3.1, NOOP automatique si non-transverse)
- `GRANT EXECUTE` accordé à `authenticated` uniquement (pas à `anon`)

### 11.2. Liste des RPCs *(actualisée v1.1)*

| RPC | Signature | Autorisation requise | Statut |
|---|---|---|---|
| `fn_team_promote_to_librarian` | `(p_user_id uuid, p_library_id uuid)` | `user_can_engage_library` | ✅ Existante |
| `fn_team_promote_to_coordenador` | `(p_user_id uuid, p_library_id uuid)` | — | ⛔ **Neutralisée v1.4 (26/08/2026)** — lève `collegiality_required`, cf. §5.3 |
| `fn_team_propose_invitation` | `(p_library_id uuid, p_invited_public_id text, p_role text DEFAULT 'librarian')` | staff actif ; `user_can_manage_library` en plus si `p_role='coordenador'` | ✅ Élargie au rôle `coordenador` en v1.4 |
| `fn_team_ratify_invitation` | `(p_invitation_id uuid)` | staff actif de la biblio | ✅ Existante |
| `fn_team_accept_invitation` | `(p_invitation_id uuid)` | la personne invitée | ✅ Étendue au rôle `coordenador` en v1.4 |
| `fn_team_expire_invitations` | `()` | `service_role` (cron) | ✅ Créée en v1.4 |
| ~~`fn_team_promote_to_administrador`~~ | ~~obsolète~~ | — | ❌ **Supprimée au paquet F (13/05/2026)** |
| `fn_team_self_demote` | `(p_library_id uuid, p_target_role text)` | staff actif (auto) | ✅ Existante, branche « last admin lockdown » supprimée au paquet F.3 |
| `fn_team_request_remove_member` | `(p_user_id uuid, p_library_id uuid, p_role text, p_reason text)` | `user_can_engage_library` + refus si cible admin réseau | ✅ Existante, refacto C |
| `fn_team_cancel_remove_member` | `(p_user_id uuid, p_library_id uuid, p_role text)` | `user_can_engage_library` | ✅ Existante |
| `fn_team_suspend_member` | `(p_user_id uuid, p_library_id uuid, p_role text, p_reason text)` | `user_can_engage_library` + refus si cible admin réseau | ✅ Existante, refacto F.3 |
| `fn_team_unsuspend_member` | `(p_user_id uuid, p_library_id uuid, p_role text)` | `user_can_engage_library` | ✅ Existante |
| `fn_team_list_memberships` | `(p_scope text, p_library_id uuid)` | varie selon scope | ✅ Refactorée au paquet D.8 sur `fn_caller_is_network_admin` |

**Note v1.1** : `fn_caller_is_administrador` qui figurait en v1.0 comme helper a été **dépréciée au paquet D.8** puis **supprimée au paquet F** (cohérent avec la suppression du rôle `administrador` local). Tous les appelants ont été refactorés sur `fn_caller_is_network_admin` (cf. spec admin réseau v0.3.1).

### 11.3. Pattern type d'une RPC (exemple : promote_to_librarian) *(actualisé v1.1)*

```sql
CREATE OR REPLACE FUNCTION public.fn_team_promote_to_librarian(
  p_user_id uuid,
  p_library_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
BEGIN
  -- 1. Vérifier authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Vérifier que l'acteur·rice peut engager la biblio (coord local OU admin réseau)
  IF NOT public.user_can_engage_library(p_library_id) THEN  -- v1.1 : helper centralisé
    RAISE EXCEPTION 'unauthorized: only coordenador local or network admin can promote';
  END IF;

  -- 3. Vérifier que l'acteur·rice ne se promeut pas lui·elle-même
  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'forbidden: cannot self-promote';
  END IF;

  -- 4. Vérifier que la personne cible existe
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'not_found: target user does not exist';
  END IF;

  -- 5. Idempotence : si déjà librarian active, ne rien faire
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = 'librarian'
    AND status = 'active';

  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'no_change', true, 'reason', 'already_librarian');
  END IF;

  -- 6. INSERT ou UPDATE
  INSERT INTO public.user_library_memberships
    (user_id, library_id, role, status)
  VALUES
    (p_user_id, p_library_id, 'librarian', 'active')
  ON CONFLICT (user_id, library_id, role) DO UPDATE
    SET status = 'active',
        updated_at = now();

  -- 7. Audit log local
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_librarian', 'librarian',
     COALESCE(v_existing.status, NULL), 'active');

  -- 8. v1.1 : log cross-library si admin réseau sans staff local sur cette biblio
  PERFORM public.fn_log_cross_library_action(
    p_actor_user_id := v_actor_id,
    p_library_id := p_library_id,
    p_action_type := 'team_promote_to_librarian',
    p_is_critical := true,  -- promotion staff = critique
    p_target_entity_type := 'user_library_membership',
    p_target_entity_id := p_user_id,
    p_payload := jsonb_build_object('promoted_role', 'librarian')
  );
  -- NOOP automatique si v_actor_id est staff local de p_library_id

  -- 9. Notification mail
  PERFORM public.fn_team_notify_event('team.promoted_to_librarian',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id
    ));

  RETURN jsonb_build_object('ok', true, 'action', 'promoted_to_librarian');
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_team_promote_to_librarian(uuid, uuid) TO authenticated;
COMMENT ON FUNCTION public.fn_team_promote_to_librarian(uuid, uuid) IS
  'Promeut un user au rôle librarian dans une biblio. Cooptation par coordenador local ou admin réseau. Cf. spec-gouvernance-roles.md v1.1 §5.2.';
```

Les autres RPCs suivent le même pattern, avec leurs vérifications spécifiques.

### 11.4. Helper d'envoi des notifications

Fonction helper `fn_team_notify_event(p_event text, p_payload jsonb)` :
- Pattern unifié depuis le paquet D.6bis admin réseau : **un INSERT par event** dans `team_notification_outbox`, fan-out par l'Edge Function `notify-event` en lisant le payload JSONB
- Symétrie totale avec `fn_network_notify_event` (events `network.*`)

---

## 12. Cron jobs

Les crons sont implémentés via `pg_cron`.

### 12.1. `fn_cron_team_pending_removal_complete`

**Fréquence** : toutes les heures.

**Action** *(actualisée v1.2)* : finalise les retraits dont la carence de 7 jours a expiré, en appliquant la doctrine de **rétrogradation d'un cran**.

Pour chaque membership en `status='pending_removal'` dont `pending_removal_until <= now()` :
1. Le membership est clos : `status='removed'`, champs `pending_removal_*` vidés.
2. La personne **redescend d'un cran**, elle n'est pas exclue : le rôle immédiatement inférieur est réactivé (ou créé) en `status='active'` — `coordenador` retiré → `librarian` réactivé ; `librarian` retiré → `reader` réactivé. Ceci maintient l'invariant « une seule ligne `active` par `(user_id, library_id)` » (doctrine rôle exclusif, §5.3 / §10.3).
3. Deux entrées d'audit : `removal_completed` sur le rôle retiré (`status_before='pending_removal'`), et une entrée traçant la réactivation du rôle inférieur.
4. Event `team.removal_completed` déposé dans `team_notification_outbox` (payload enrichi du champ `demoted_to`).

**Note d'implémentation v1.2** : le code de référence est la fonction `fn_cron_team_pending_removal_complete` telle qu'établie par la migration `20260520230000_doctrine_role_exclusif_coordenador_cron.sql`. Cette migration a aussi corrigé un **bug pré-existant** : la version antérieure filtrait `status='active'` dans sa boucle, alors que `fn_team_request_remove_member` pose `status='pending_removal'` — le cron ne ramassait donc jamais aucun membership à finaliser (bug dormant, le flux de retrait avec carence n'ayant jamais été exercé en conditions réelles avant le 20/05). La spec ne reproduit pas le corps SQL complet de la fonction : le code en base fait foi.

### 12.2. `cron_team_inactive_cleanup`

**Fréquence** : quotidienne (1× par jour).

**Action** :
1. Pour chaque membership `active` d'un user dont `last_sign_in_at` est à exactement J-9mois - 30 jours : envoyer `team.inactive_warning_30d` à la personne, audit log.
2. Idem pour J-9mois - 7 jours : `team.inactive_warning_7d`.
3. Pour chaque membership `active` dont `last_sign_in_at` est à >= J-9mois : passage à `inactive`, mail + audit log + escalade admins réseau si c'est le·la dernier·e coord (cf. §6.1).

**Garde-fou** : si `last_sign_in_at` est NULL (compte jamais utilisé), le critère ne s'applique pas (sinon, on virerait des comptes tout neufs en attente de validation). À adapter selon l'audit du champ.

### 12.3. `fn_team_expire_invitations` *(nouveau v1.4)*

**Fréquence** : quotidienne, 03 h 20 UTC (`anarbib-team-invitations-expire`).

**Action** : passe à `status='expired'` toute invitation d'équipe encore en
`pending_ratification` ou `ready` dont `expires_at` est dépassé, en horodatant `resolved_at` et
en suffixant `resolution_note`. Retourne le nombre de lignes touchées.

**Lacune qu'elle comble** : `expires_at` était renseigné depuis l'origine du circuit
(19/06/2026), mais **aucune tâche ne le faisait respecter** — les invitations restaient
indéfiniment `pending_ratification`. Tant que le circuit ne servait qu'à l'accueil et n'avait
jamais tourné (zéro ligne en base au 26/08/2026), la lacune était sans effet. Elle cesse de
l'être dès lors que T2 en dépend : une proposition de coordination qui ne se referme jamais
laisse ouverte, indéfiniment, une question à laquelle personne n'a répondu.

**Droits** : `REVOKE EXECUTE` sur `PUBLIC`, `anon`, `authenticated` ; `GRANT` au seul
`service_role`.

### 12.4. Programmation et monitoring

Les crons sont déclarés dans `pg_cron` et leurs exécutions tracées dans `cron.job_run_details`. À monitorer :

- Échecs de cron (`status = 'failed'`)
- Durées anormales (un cron qui prend > 5 min)
- Volume d'actions générées par exécution (alerte si > N actions, signe d'une anomalie)

---

## 13. Rôle administrador AnarBib → renvoi spec dédiée

*(Section refondue intégralement v1.1)*

L'administration du réseau AnarBib (cooptation à l'unanimité, retrait collectif à l'unanimité, auto-retrait unilatéral, audit cross-library, etc.) est traitée par **`spec-administrateur-reseau.md v0.3.1`**, chantier entièrement livré en production entre le 11/05/2026 et le 14/05/2026 (paquets A-F + #114 mails militants).

**Cette spec gouvernance ne s'occupe plus du tout du rôle d'administration du réseau** : elle se limite strictement aux rôles **locaux** d'une biblio (`reader`, `librarian`, `coordenador`). L'articulation entre les deux niveaux passe par les helpers centralisés `user_can_act_as_staff_on_library`, `user_can_engage_library`, et `fn_caller_is_network_admin` (cf. annexe B).

**Note historique** : la v1.0 de cette spec contenait une section §13 dédiée à un rôle `administrador` local hypothétique, avec une transition `coordenador → administrador` envisagée. Ces éléments sont devenus sans objet le 13/05/2026 quand le paquet F a supprimé le rôle `administrador` du CHECK constraint de `user_library_memberships.role`. Toute autorité transverse passe désormais par la table `network_administrators` et son workflow politique de cooptation unanime.

---

## 14. Plan d'implémentation *(refait v1.4 — état réel constaté)*

> ⚠️ **Ce qui suit remplace intégralement l'état des lots daté du 15/05/2026.** Celui-ci annonçait
> « ⏸️ à faire » un ensemble d'objets qui étaient **déjà en production au moment où il a été
> écrit** : la table `library_membership_audit`, les colonnes de carence `pending_removal_until` /
> `pending_removal_requested_by`, l'index `idx_ulm_pending_removal_until`,
> `fn_team_cancel_remove_member`, `fn_team_unsuspend_member` et `fn_team_notify_event` figurent
> tous dans le dump de référence `20260510000000_baseline_live.sql` — antérieur de **cinq jours**
> à cette liste. Une liste de tâches qui décrit le passé est plus nuisible qu'une liste absente :
> elle fait re-cadrer, re-chiffrer et parfois ré-implémenter ce qui tourne déjà, et elle
> décrédibilise les lignes qui, elles, étaient exactes.

### 14.1. État réel au 26/08/2026

| Lot | Objet | État | Constaté sur |
|---|---|---|---|
| 1 | Infrastructure DB — audit, colonnes de carence, index | ✅ **en production** | `20260510000000_baseline_live.sql` |
| 2 | RPCs cooptation T1 / T2 | ✅ **en production** ; T2 refondu le 26/08 (cf. §5.3) | baseline + `20260826120000` |
| 3 | RPCs retraits T3–T8 | ✅ **en production**, `fn_team_cancel_remove_member` et `fn_team_unsuspend_member` comprises — que la v1.1 disait « à vérifier / à implémenter si absente » | baseline |
| 4 | Crons | ✅ **en production** : `anarbib-team-pending-removal-complete` (horaire) et `anarbib-team-inactive-cleanup` (04 h 00), rejoints le 26/08 par `anarbib-team-invitations-expire` (03 h 20) | lecture de `cron.job`, 26/08/2026 |
| 5 | Notifications mail `team.*` | ✅ **en production** : `supabase/functions/_shared/domain/team.ts` chargé par `notify-event`, chaînes dans `_shared/i18n/mail-strings.ts`, **10 locales** | dépôt |
| 6 | UI onglet équipe | ✅ **en production** : `TeamPanel.jsx`, `TeamActionModal.jsx`, `src/lib/roles.js`, historique d'équipe | dépôt |
| 7 | Workflow d'invitation | ✅ **en production** depuis le 19/06/2026 — et c'est lui qui porte désormais T2 | `20260619125325`, `20260619135226`, `20260619143201` |

**Autrement dit : les sept lots sont livrés.** Ce qui restait à faire au titre de cette spec, au
26/08/2026, ce n'était aucune des lignes ci-dessus : c'était la mise en conformité de T2 avec P2,
objet de la v1.4.

Une remarque qui vaut au-delà de ce §14 : le circuit d'invitation était livré depuis deux mois et
n'avait **jamais servi** — zéro ligne dans `library_team_invitations` au 26/08/2026. « Livré » et
« éprouvé » sont deux états distincts, et cette table ne dit que le premier. C'est aussi pourquoi
la lacune de péremption (§12.3) a pu rester invisible si longtemps.

### 14.2. Ce que cette révision n'a pas vérifié

Deux affirmations héritées de la v1.1 ne sont **pas** contrôlées ici et sont laissées telles
quelles : l'articulation avec le **paquet F de la spec profils d'adoption** (§14.3 ci-dessous) et
l'état des tests d'acceptation du lot 2. Les marquer comme non vérifiées vaut mieux que de les
recopier comme si elles l'étaient — c'est exactement le mécanisme qui a produit le §14 précédent.

### 14.3. Articulation avec la spec profils d'adoption v0.3

Le déploiement complet de cette spec gouvernance dépend du **paquet F de la spec profils** qui activera le `governance_mode` par biblio. Tant que ce paquet n'est pas livré, toutes les biblios fonctionnent implicitement en mode `full_governance`.

**Séquence recommandée** :
1. Spec profils paquets A-E (champs DB + RLS + UI choix profil)
2. Cette spec gouvernance Lots 1-6 (mécanismes complets en `full_governance`)
3. Spec profils paquet F (activation conditionnelle des mécanismes selon `governance_mode`)

### 14.4. Points d'attention transverses

- **i18n** : respect des conventions militantes (cf. mémoire). Toutes les locales en une fois, jamais de fallback temporaire.
- **Tests** : prévoir des tests d'intégration sur scénarios complets (cf. §15 cas d'usage).
- **Migrations** : versionnées avec date dans `supabase/migrations/YYYYMMDDHHMMSS_*.sql`, idempotentes (DROP IF EXISTS / CREATE OR REPLACE), commitées sur le repo. Le `git push` sur `main` déclenche **Forgejo Actions** (`.forgejo/workflows/ci.yml`), qui déploie les edge functions puis applique les migrations — *migré de Woodpecker le 11/06/2026, cf. `DOC-DEPLOY-1` du registre*.
- **Rollback** : chaque migration doit avoir un script de rollback testé.

---

## 15. Cas d'usage de référence

### 15.1. Voltairine cooptée librarian

> Emma est coordenador·a de la BLMF. Elle veut accueillir Voltairine dans l'équipe (Voltairine est déjà reader inscrite à la BLMF).
>
> 1. Emma va dans `/biblioteca`, onglet `team`
> 2. Elle cherche Voltairine dans la liste des readers de la biblio (recherche par nom/email)
> 3. Elle clique sur « Inviter dans l'équipe », sélectionne « librarian », confirme la modale
> 4. Voltairine reçoit un mail : « Tu as été nommée librarian de la BLMF par Emma »
> 5. La coordination de la BLMF reçoit aussi un mail informationnel
> 6. L'audit log enregistre : « 05/05 14:30 - Emma a promu Voltairine librarian »

### 15.2. Lucy passe la main

> Lucy est coordenador·a de la BLMF, mais elle ne peut plus assurer la charge ce semestre.
>
> 1. Lucy va dans `/biblioteca`, onglet `team`
> 2. Sur sa propre ligne (statut coordenador), elle clique « Je passe la main » → « Repasser librarian »
> 3. Modale de confirmation simple, Lucy confirme
> 4. Sa membership coordenador passe à `inactive`, sa membership `librarian` (qui existait peut-être déjà ; sinon créée) reste/devient active
> 5. Toute la coordination reçoit un mail : « Lucy a passé la main, n'est plus coordenador·a »
> 6. Lucy reçoit un mail de confirmation
> 7. Audit log : « 05/05 18:42 - Lucy a auto-rétrogradé coordenador→librarian »

### 15.3. Karl doit partir

> Karl est librarian de la BLMF, mais son comportement avec les lecteur·rices a posé problème. Le collectif a discuté en AG et décidé qu'il devait quitter l'équipe.
>
> 1. Piotr (coord, choisi par l'AG pour exécuter la décision) va dans `/biblioteca`, onglet `team`
> 2. Sur la ligne de Karl, il clique « Demander le retrait »
> 3. Modale rouge avec délai 7j, raison optionnelle (« décision AG du 04/05 »), confirmation explicite
> 4. La membership de Karl passe à `pending_removal`, `pending_removal_until = 12/05`
> 5. Karl reçoit un mail : « La coordination a demandé ton retrait de l'équipe BLMF (préavis jusqu'au 12/05). Cette décision relève de la vie organique du collectif BLMF ; pour toute discussion, adresse-toi à la coordination. »
> 6. Toute la coordination reçoit un mail
> 7. Audit log : « 05/05 - Piotr a demandé le retrait de Karl (raison: décision AG du 04/05) »
> 8. **Sept jours passent**. Aucune annulation.
> 9. Le 12/05 le cron passe automatiquement Karl à `inactive`. Mails de confirmation. Audit log « removal_completed ».

### 15.4. Compte compromis : suspension immédiate

> Une coordenadora remarque que le mot de passe de Friedrich (librarian) semble compromis (activité anormale dans les logs).
>
> 1. La coordenadora va dans `/biblioteca`, onglet `team`
> 2. Clique « Suspendre » sur la ligne de Friedrich
> 3. Modale obligatoire « Raison de la suspension » : elle tape « Soupçon compte compromis, vérification en cours »
> 4. Confirmation, la membership passe à `suspended` immédiatement
> 5. Friedrich reçoit un mail urgent + invitation à changer son mot de passe
> 6. Toute la coordination reçoit un mail
> 7. Audit log : `suspended` avec raison
> 8. **Plus tard**, après vérification (mot de passe changé, pas de dégât) : un·e coord clique « Lever la suspension », membership repasse à `active`

### 15.5. L'ultime coord part *(actualisé v1.1)*

> La BLMF n'a plus qu'un seul coord, Errico. Il doit partir (déménagement, plus de temps).
>
> 1. Errico va dans `/biblioteca`, onglet `team`, clique « Je passe la main »
> 2. Modale de confirmation simple (sans phrase rituelle « last admin lockdown » qui figurait en v1.0, supprimée au paquet F.3) : « Vous perdrez les permissions de coordenador·a immédiatement. »
> 3. Errico confirme. Sa membership coordenador passe à `inactive` sans blocage technique.
> 4. Le SIGB détecte que la BLMF n'a plus de coordenador·a actif·ve → mail aux **administrateurs réseau actifs** (table `network_administrators` `status='active'`)
> 5. La BLMF continue à fonctionner en mode dégradé (les librarians peuvent gérer les emprunts, etc., mais pas la config)
> 6. Hors-logiciel, l'équipe d'admin réseau prend contact avec le collectif BLMF pour aider à désigner un·e nouveau·elle coord
> 7. Quand le collectif a décidé, un·e admin réseau **propose** la promotion via `fn_team_propose_invitation` (rôle `coordenador`, autorisé par le droit transverse) ; elle est ensuite ratifiée par un·e membre du staff de BLMF, puis acceptée par la personne visée *(v1.4)*. L'action est tracée dans `network_admin_cross_library_actions_log` (action critique : promotion staff) + mail immédiat aux librarians de BLMF.

**Différence avec v1.0** : en v1.0, le scénario mentionnait une « modification SQL directe » par Xavier (admin AnarBib). Depuis le paquet F admin réseau, l'admin réseau passe par la RPC normale, avec autorisation transparente et trace automatique. Plus de bypass SQL, plus de phrase rituelle bloquante.

---

## Annexe A : Glossaire

- **AG** : Assemblée Générale (réunion collective de prise de décision)
- **Cooptation** : nomination par les membres existants
- **Multi-membership** : présence de plusieurs lignes `user_library_memberships` pour une même personne dans une même biblio. Depuis la doctrine « rôle exclusif » (v1.2), au plus **une** de ces lignes est en `status='active'` ; les autres (`removed`, `inactive`) portent l'historique des rôles passés.
- **Carence** : délai entre une décision et son effet (ici 7 jours pour les exclusions)
- **RebAL** : Réseau de Bibliothèques Alternatives Libertaires
- **(v1.1) Administrateur·rice réseau** : personne inscrite dans `network_administrators` avec `status='active'`. Autorité politique transverse, cooptée à l'unanimité (cf. spec admin réseau v0.3.1).
- **(v1.1) Action cross-library** : action d'un·e admin réseau sur une biblio dont il/elle n'est pas staff local. Tracée dans `network_admin_cross_library_actions_log`.

## Annexe B : Glossaire des fonctions techniques *(actualisé v1.1)*

**Helpers centralisés (paquet C admin réseau, 11/05/2026)** :

- **`user_can_act_as_staff_on_library(p_library_id uuid) RETURNS boolean`** : TRUE si l'appelant·e peut agir comme membre du staff sur la biblio donnée. Inclut le staff local actif (`librarian` + `coordenador`) **ET** les administrateurs réseau actifs. Pilier de la catégorie A des RLS (15 policies au total).

- **`user_can_engage_library(p_library_id uuid) RETURNS boolean`** : TRUE si l'appelant·e peut engager politiquement la biblio (modifications structurelles, règlement, politique de circulation). Inclut `coordenador` local actif **ET** administrateurs réseau actifs. Pilier de la catégorie B des RLS (4 policies).

- **`fn_caller_is_network_admin() RETURNS boolean`** : TRUE si l'appelant·e est dans `network_administrators` avec `status='active'`. Pilier de la catégorie C des RLS (1 policy).

**Helpers historiques (v1.0) refactorés comme wrappers** :

- `user_has_library_staff_role(user_id, library_id)` : wrapper de `user_can_act_as_staff_on_library` depuis le paquet C admin réseau (11/05/2026)
- `user_can_manage_library(library_id)` : wrapper de `user_can_engage_library` depuis le paquet C admin réseau (11/05/2026)
- `fn_library_visible_to_caller(library_id)` : helper de visibilité (public/network/private). Existe depuis le 02/05/2026, intact.

**Helpers supprimés au paquet F (13/05/2026)** :

- ~~`fn_caller_is_administrador()`~~ : remplacée par `fn_caller_is_network_admin()`
- ~~`fn_team_promote_to_administrador(uuid, uuid)`~~ : remplacée par `fn_network_admin_propose_cooptation` (workflow politique distinct, cf. spec admin réseau)

## Annexe C : Références aux specs cousines *(actualisé v1.1)*

- **`spec-administrateur-reseau.md v0.3.1`** (chantier clos 14/05/2026, 1037 lignes) : administration du réseau AnarBib (cooptation unanime, retrait collectif, audit cross-library, mails militants). **Spec sœur indispensable**.
- **`spec-flux-consultations.md v2.1`** (chantier clos 14/05/2026, 1083 lignes) : workflow de consultations sur place. Utilise les helpers `user_can_act_as_staff_on_library` et `user_can_engage_library` pour les autorisations staff.
- **`spec-profils-bibliotheque.md v0.3`** (13/05/2026, 934 lignes) : doctrine des 4 axes orthogonaux de profils d'adoption (`catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode`). Cette spec gouvernance décrit le mode `governance_mode = 'full_governance'`.
- `spec-validation-physique.md` (à rédiger) : validation physique des comptes lecteur·rices
- `spec-migration-compte.md` (940 lignes, cadrée le 03/05/2026) : migration d'un compte d'une biblio à une autre
- `spec-onboarding-biblioteca.md v1.1` (refonte en cours) : workflow d'invitation pour les personnes sans compte AnarBib

## Annexe D : Décisions politiques cadrées *(actualisé v1.1)*

Cette spec consigne les décisions prises lors d'une session de cadrage avec Xavier le 05/05/2026, complétées par les refontes post-implémentation :

| Q | Décision v1.0 | Statut v1.1 |
|---|---|---|
| Q1 (vision politique) | Délégation avec rotation des fonctions | ✅ Conservée |
| Q2 (reader→librarian) | Coordenador+ uniquement (cooptation) | ✅ Conservée (« + » désigne admin réseau via helpers) |
| Q3 (librarian→coordenador) | Coordenador+ uniquement (cooptation) | ✅ Conservée |
| Q4 (rétrograder coord) | Soi-même + autres coordenadores | ✅ Conservée |
| Q5 (librarian→reader) | Soi-même + coordenadores | ✅ Conservée |
| Q6 (modèle exclusion) | 3 états avec délai de carence 7j | ✅ Conservée |
| Q7 (compte abandonné) | Sortie auto à 9 mois + mails J-30 et J-7 | ✏️ Amendée v1.3 — le mail J-7 notifie aussi la coordination (escalade réseau si dernier·e coord) ; le J-30 reste individuel |
| Q8 (audit log visibilité) | Public au staff | ✅ Conservée, étendue aux admins réseau via helper |
| Q9 (notifications) | Personne concernée + toute la coordination | ✅ Conservée, mention « action transverse » si applicable |
| Q10 (UI) | Onglet « Equipe » dans /biblioteca | ✅ Conservée, ajout `<NetworkAdminBadge>` |
| Q11 (dernier coord part) | Avertir + autoriser + escalader administrador | ✅ **Branche bloquante supprimée au paquet F.3.** Escalade vers admins réseau. |
| Q12 (multi-membership) | Strictement local (biblio par biblio) | ✅ Conservée |
| Q13 (coord→admin) | Non, écrit comme principe | ✅ **Renforcée v1.1** : transition impossible, l'administration réseau est un mécanisme politique distinct (cooptation unanime, cf. spec admin réseau v0.3.1) |
| Q14 (succession admin) | Cercle 1/3/5 (impair), modalités à formaliser ailleurs | ✅ **Résolue v1.1** : workflow complet livré dans la spec admin réseau v0.3.1 (cooptation à l'unanimité, retrait collectif à l'unanimité, auto-retrait unilatéral, quorum minimum ≥ 3 admins) |
| Q15 (rôle exclusif) | *(non posée en v1.0 — la v1.1 recommandait le multi-membership actif)* | 🆕 **Actée v1.2 (20/05/2026)** : une personne n'a qu'**un seul rôle actif** par biblio. Une promotion ferme le rôle inférieur (`status='removed'`) ; une rétrogradation réactive le cran en dessous. Argumentaire : la v1.1 justifiait le multi-membership actif par « préserver l'historique et la flexibilité » — l'historique est en réalité intégralement porté par l'audit log et les lignes `removed`, sans cumul de lignes `active` ; et la « flexibilité » du cumul n'était qu'une ambiguïté (toute requête `WHERE role=…` devait arbitrer laquelle fait foi, toute vue devait penser à `DISTINCT`). Décision révélée par deux bugs jumeaux en production : `fn_team_promote_to_librarian` et `fn_team_promote_to_coordenador` créaient des doubles memberships actifs. Doctrine cohérente avec P1 (délégation, pas hiérarchie) : retirer un rôle ne bannit pas la personne, elle redescend d'un cran. |

## Annexe E : *(Nouveau v1.1)* Changelog v1.0 → v1.1

**Objet de la version** : refonte cohérence après la livraison complète du chantier admin réseau (paquets A-F + #114, 11-14/05/2026). Le rôle `administrador` **local** a été supprimé du schéma, remplacé par la table `network_administrators` portée par une spec dédiée. Cette spec gouvernance est désormais strictement limitée aux rôles **locaux** d'une biblio. Ajout du périmètre d'activation : cette spec décrit le mode `governance_mode = 'full_governance'` de la spec profils v0.3.

**Sections ajoutées** :
- §1.4 Périmètre d'activation (mode `full_governance` de la spec profils)
- §6.11 Articulation avec le `governance_mode` de la spec profils
- Annexe E (ce changelog)

**Sections refondues intégralement** :
- §3.4 : « administrador » local → renvoi vers spec admin réseau v0.3.1
- §6.3 : Coordenador→administrador devient sans objet
- §6.9 : Tentative d'action sur admin réseau via `fn_team_*` (refus systématique, refacto paquet C/F)
- §13 : intégralement remplacée par un renvoi vers la spec admin réseau v0.3.1

**Sections mises à jour** :
- Préambule + en-tête : version 1.1, statut « partiellement implémenté »
- §1.3 Périmètre : ajout du non-périmètre « administration du réseau » (renvoi spec admin réseau)
- §3 (chapeau) : passage de 4 à 3 rôles locaux, mention du paquet F
- §3.2, §3.3 : références aux helpers centralisés `user_can_act_as_staff_on_library`, `user_can_engage_library`
- §4 (chapeau) : CHECK constraint actualisé avec `'removed'` (paquet 23)
- §5.1 tableau T1-T9 : « administrador » retiré, mention « OU admin réseau » sur les transitions T1, T2, T5-T8 ; mention explicite de la suppression de la transition T10 (`coordenador → administrador`)
- §5.2, §5.3, §5.6, §5.7, §5.8, §5.9 : « OU admin réseau » + mention action cross-library tracée
- §5.4 : branche « last admin lockdown » supprimée au paquet F.3
- §5.10 : escalade vers admins réseau (au lieu d'administradores locaux)
- §6.1 : escalade vers admins réseau, plus de blocage technique
- §6.4 : « modification SQL directe » remplacée par RPC normale appelée par admin réseau
- §6.5 : ajout du `<NetworkAdminBadge>` sur les lignes admin réseau
- §7 : helper RLS centralisé, mention de la double trace audit (local + réseau) pour les actions cross-library
- §8.2 : event `team.last_coordinator_leaving` → destinataires = admins réseau (au lieu d'administradores)
- §9.2, §9.4 : visibilité onglet team étendue aux admins réseau
- §9.3 : exemple UI avec `[Admin réseau]` badge
- §9.5 : phrase rituelle modale auto-rétro supprimée
- §10.1, §10.2 : CHECK constraints actualisés (status élargi à `removed`, role rétréci à 3 valeurs)
- §11.1 : pattern enrichi avec `fn_log_cross_library_action`
- §11.2 : liste des RPC actualisée avec statut d'implémentation et notes sur les RPC supprimées
- §11.3 : exemple pattern type avec `user_can_engage_library` et `fn_log_cross_library_action`
- §14 : tous les lots marqués avec leur statut réel d'implémentation
- §15.5 : scénario « ultime coord part » actualisé sans phrase rituelle ni bypass SQL
- Annexe B : helpers centralisés explicités, helpers historiques marqués comme wrappers, helpers supprimés listés
- Annexe C : références aux specs sœurs livrées (admin réseau v0.3.1, consultas v2.1, profils v0.3)
- Annexe D : Q11 marquée « branche bloquante supprimée », Q13 renforcée, Q14 résolue par spec admin réseau

**Sections inchangées (par rapport à v1.0)** :
- §2 Principes fondateurs (sauf P7 enrichi de l'articulation transverse)
- §3.1 reader (rôle inchangé)
- §4.1-4.6 status (sauf §4 chapeau)
- §6.2, §6.6, §6.7, §6.8, §6.10 cas-limites locaux
- §7 audit log (sauf §7.5 helper RLS)
- §8.1, §8.3, §8.4 notifications
- §9.1, §9.6, §9.7 UI
- §11.4 helper de notifications
- §12 cron jobs (descriptif technique)
- §15.1, §15.2, §15.3, §15.4 cas d'usage

**Bilan v1.1** : la spec est désormais **alignée sur l'état du système en production au 14/05/2026**, intégralement compatible avec la spec admin réseau v0.3.1, et préparée pour l'activation conditionnelle par `governance_mode` de la spec profils v0.3. Les lots d'implémentation restants (1 partiellement, 4, 5, 6, 7) restent à livrer dans un chantier dédié, qui pourra démarrer après la livraison du paquet A de la spec profils.

---

## Annexe F : *(Nouveau v1.2)* Changelog v1.1 → v1.2

**Objet** : acter la doctrine « **rôle exclusif** » — une personne n'a qu'un seul rôle actif par bibliothèque.

**Origine** : deux bugs jumeaux découverts en production le 20/05/2026, en testant pour la première fois en conditions réelles les flux de promotion. `fn_team_promote_to_librarian` puis `fn_team_promote_to_coordenador` faisaient un `INSERT ... ON CONFLICT` sur la clé `(user_id, library_id, role)` ; le rôle cible différant du rôle existant, aucun conflit n'était détecté, d'où un `INSERT` pur créant un **second membership actif** au lieu d'une transition. Une personne promue se retrouvait `reader`+`librarian` ou `librarian`+`coordenador` simultanément actifs.

**Sections amendées** :
- En-tête : version 1.2, entrée d'historique.
- §5.3 (T2 `librarian`→`coordenador`) : l'« Effet » et la « Note d'implémentation » décrivent désormais la fermeture du rôle inférieur ; la recommandation v1.1 de multi-membership actif est explicitement abandonnée.
- §5.6 (T5, effet à J+7) : la finalisation du cron est une **rétrogradation d'un cran** (réactivation du rôle inférieur), pas une exclusion sèche.
- §6.5 : refondue — « rôle exclusif », l'invariant « une seule ligne `active` par `(user_id, library_id)` » remplace le multi-membership.
- §10.3 : la contrainte UNIQUE est conservée pour l'historique, mais ne garantit pas l'unicité du rôle actif — celle-ci est portée par les RPC ; piste d'une contrainte `EXCLUDE` partielle évoquée, non retenue en v1.2.
- §12.1 : le pseudo-code SQL obsolète est remplacé par une description du comportement réel + renvoi à la migration ; mention du bug pré-existant du `WHERE status='active'` corrigé.
- Annexe D : ajout de la décision Q15 avec son argumentaire.

**Implémentation** : livrée en production le 20/05/2026 — hotfix `fn_team_promote_to_librarian` (ferme le `reader`), puis migration `20260520230000_doctrine_role_exclusif_coordenador_cron.sql` (`fn_team_promote_to_coordenador` ferme le `librarian` ; `fn_cron_team_pending_removal_complete` corrigé sur deux points : le `WHERE` ramasse enfin les `pending_removal`, et la finalisation rétrograde d'un cran). `fn_team_self_demote` et `fn_team_request_remove_member` étaient déjà cohérentes, non modifiées.

**Reste à faire** : pas de chantier ouvert par cette doctrine — elle est entièrement appliquée. Point de vigilance pour un futur audit : vérifier qu'aucune vue ou requête frontend ne suppose encore le multi-membership actif (le compteur `librarians_active` de `library_circulation_stats` utilise `count(DISTINCT user_id)`, donc déjà robuste).

---

*Spec rédigée le 05/05/2026 (v1.0), refondue le 15/05/2026 (v1.1) pour intégrer la séparation admin réseau et l'articulation avec les profils d'adoption, amendée le 20/05/2026 (v1.2) pour acter la doctrine « rôle exclusif ».*
