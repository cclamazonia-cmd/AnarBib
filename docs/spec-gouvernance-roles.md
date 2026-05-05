# Spécification : Gouvernance des rôles dans AnarBib

**Version** : 1.0 — 2026-05-05
**Statut** : Spec validée politiquement, en attente d'implémentation
**Contexte** : Roadmap Bologna sept 2026
**Auteur·ices** : Xavier (cadrage politique) + assistant IA (rédaction)

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
13. [Rôle administrador AnarBib](#13-rôle-administrador-anarbib)
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
- Validation physique d'un compte lecteur·rice (cf. `spec-validation-physique.md` à rédiger)
- Migration de compte entre biblios (cf. `spec-migration-compte.md` cadrée le 03/05/2026)
- Workflow d'invitation initiale d'un·e librarian (à cadrer dans une spec dédiée)

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

### P8 — Le SIGB ne modélise pas l'AG

Le SIGB exécute les décisions, il ne les prend pas. La spec ne contient aucun mécanisme de vote, quorum, etc. Ces choses se passent en collectif, hors logiciel.

---

## 3. Modèle des rôles

AnarBib utilise un modèle à **4 rôles** (cadré le 03/05/2026, mémoire #25). Ces rôles existent en base via le CHECK constraint sur `user_library_memberships.role` :

```sql
CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))
```

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

**Permissions techniques actuelles** (helpers `user_has_library_staff_role`) :
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

**Permissions actuelles** (helpers `user_can_manage_library`) :
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

### 3.4. `administrador`

**Définition** : rôle exceptionnel cross-biblios, spécifique à AnarBib (pas à une biblio donnée).

**Permissions** :
- Tout ce qu'a un coordenador, dans **toutes les biblios**
- Activation de nouvelles biblios (workflow `fn_activate_approved_library_request`)
- Intervention en cas de blocage (cf. §6 cas-limites)
- Gestion technique de la plateforme (modèle de données, RLS, etc.)

**Cette spec** ne couvre **pas** la gestion du rôle administrador (cf. §13 pour les contours et la note de spec future).

---

## 4. Modèle des status

Le CHECK constraint actuel sur `user_library_memberships.status` autorise :

```sql
CHECK (status = ANY (ARRAY['active', 'inactive', 'pending', 'suspended']))
```

Cette spec **ajoute un 5ème status** : `'pending_removal'`.

### 4.1. `active`

État normal d'une membership. La personne a son rôle et l'exerce.

### 4.2. `pending`

**Réservé à la spec validation physique** (hors périmètre de cette spec). Membership en attente de validation par un·e librarian+ de la biblio d'inscription. Cette spec **ne touche pas** à ce statut.

### 4.3. `suspended`

**Mesure conservatoire** prise par un·e coordenador·a. La membership est gelée (le rôle nominal est conservé en base mais ne donne aucun accès tant que le statut est `suspended`).

**Usage** : harcèlement signalé en attente d'investigation, compte compromis, conflit en cours de médiation, etc.

**Durée** : indéfinie. La levée se fait manuellement par un·e coordenador·a (retour à `active`) ou par destitution effective (passage à `inactive`).

**Effet** : aucun accès aux fonctions du rôle. La personne reste affichée dans l'équipe avec un badge « suspendue ».

### 4.4. `pending_removal` (NOUVEAU)

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

### 5.1. Tableau récapitulatif

| # | Transition | Qui peut le faire | Mécanisme |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coordenador+ | Cooptation (P2) |
| T2 | `librarian` → `coordenador` | Coordenador+ | Cooptation (P2) |
| T3 | `coordenador` → `librarian` | Soi-même + autres coordenadores | Auto-rétro ou retrait collégial |
| T4 | `librarian` → `reader` (volontaire) | Soi-même | Auto-rétro (P3) |
| T5 | `librarian` → `reader` (par le collectif) | Coordenador (avec carence 7j) | `pending_removal` |
| T6 | Suspension immédiate (urgence) | Coordenador | Passage à `suspended` |
| T7 | Levée de suspension | Coordenador | Retour `suspended` → `active` |
| T8 | Annulation d'une demande de retrait | Coordenador | Retour `pending_removal` → `active` |
| T9 | Sortie automatique (compte abandonné) | Cron | Passage à `inactive` après 9 mois sans login + mails J-30 et J-7 |

### 5.2. Détail de T1 — `reader` → `librarian` (cooptation)

**Qui** : un·e coordenador·a OU un·e administrador·a, **membre actif·ve** de la biblio cible.

**Précondition** :
- La personne cible existe en tant qu'utilisateur·rice AnarBib (a un compte)
- La personne cible n'a pas déjà une membership `active` ou `pending_removal` ou `suspended` dans cette biblio avec un rôle staff (`librarian`/`coordenador`)
- Une membership `reader` existante peut coexister avec le nouveau rôle (multi-membership autorisé par la contrainte UNIQUE `(user_id, library_id, role)`)

**Effet** :
- Création d'une nouvelle ligne `user_library_memberships` avec `role='librarian'`, `status='active'`
- L'ancienne membership `reader` reste active (la personne reste reader ET devient librarian)
- Mail à la personne concernée + à tous les coordenadores actifs de la biblio
- Audit log

**RPC** : `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid)`

### 5.3. Détail de T2 — `librarian` → `coordenador` (cooptation)

**Qui** : un·e coordenador·a OU un·e administrador·a, **membre actif·ve** de la biblio cible.

**Précondition** :
- La personne cible a une membership `librarian` `active` dans cette biblio
- La personne cible n'a pas déjà une membership `coordenador` `active` dans cette biblio

**Effet** :
- Création d'une ligne `coordenador` `active` (la membership `librarian` reste, multi-membership)
- OU mise à jour de la ligne existante si on suit un modèle « unique role per user_id+library_id » (à arbitrer en implémentation)
- Mail à la personne + à tous les coordenadores
- Audit log

**RPC** : `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid)`

**Note d'implémentation** : la contrainte UNIQUE actuelle est sur `(user_id, library_id, role)`, ce qui autorise le multi-membership avec rôles différents. Cette spec recommande de **garder** ce comportement (multi-membership) pour préserver l'historique et la flexibilité, mais de **filtrer à l'affichage** dans l'UI pour ne montrer que le rôle de plus haut niveau.

### 5.4. Détail de T3 — `coordenador` → `librarian`

**Qui** :
- **Soi-même** : sans validation tierce (P3)
- **Autres coordenadores** : la rétrogradation par un·e autre coordenador·a est traitée comme une demande de retrait avec carence (7j), via `fn_team_request_remove_member` ciblant la membership `coordenador`. Le statut passe à `pending_removal`. Cf. T5.

**RPC pour auto-rétro** : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`

**Effet self-demote** :
- La membership `coordenador` actuelle passe à `inactive` (avec `restricted_reason='self_demoted'` ou métadonnée équivalente)
- Si la personne avait déjà une membership `librarian` active, elle est conservée
- Sinon, une nouvelle membership `librarian` est créée
- Mail à toute la coordination + à la personne (confirmation)
- Audit log

### 5.5. Détail de T4 — `librarian` → `reader` (auto-rétro)

**Qui** : la personne elle-même.

**Effet** :
- La membership `librarian` passe à `inactive`
- La membership `reader` (qui doit exister) reste `active`. Si elle n'existe pas, elle est créée.
- Mail à toute la coordination + à la personne
- Audit log

**RPC** : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'reader')`

### 5.6. Détail de T5 — `librarian` → `reader` (par le collectif, avec carence)

**Qui** : un·e coordenador·a OU un·e administrador·a.

**Précondition** :
- La personne cible a une membership `librarian` `active` dans cette biblio
- L'auteur·rice de la demande n'est pas la personne cible (sinon utiliser T4)

**Effet immédiat** :
- La membership passe à `pending_removal`
- Champ `pending_removal_until` rempli avec `now() + interval '7 days'`
- Champ `pending_removal_requested_by` rempli avec `auth.uid()`
- Mail à la personne concernée + à tous les coordenadores actifs
- Audit log

**Effet à J+7** (cron, cf. §12) :
- Si toujours `pending_removal` : passage à `inactive`
- Mail confirmation à la personne + à toute la coordination
- Audit log « pending_removal_completed »

**RPC** : `fn_team_request_remove_member(p_user_id uuid, p_library_id uuid, p_role text, p_reason text DEFAULT NULL)`

### 5.7. Détail de T6 — Suspension immédiate (urgence)

**Qui** : un·e coordenador·a OU un·e administrador·a.

**Cas d'usage** :
- Harcèlement signalé urgent
- Compte compromis (mot de passe leaké)
- Comportement manifestement abusif

**Effet** :
- La membership passe à `suspended`
- Aucun accès jusqu'à levée
- Mail à la personne + à toute la coordination
- Audit log

**Durée** : indéfinie. La suspension n'est **pas** un délai de carence avant exclusion ; c'est une mesure conservatoire qui peut durer le temps nécessaire à la délibération collective.

**RPC** : `fn_team_suspend_member(p_user_id uuid, p_library_id uuid, p_role text, p_reason text)`

**Note** : cette RPC requiert un `p_reason` non null (justification obligatoire). Le champ est journalisé dans l'audit log et le mail.

### 5.8. Détail de T7 — Levée de suspension

**Qui** : un·e coordenador·a OU un·e administrador·a (n'importe lequel·le, pas obligatoirement celui·celle qui a suspendu).

**Effet** :
- Retour à `active`
- Mail à la personne + à toute la coordination
- Audit log

**RPC** : `fn_team_unsuspend_member(p_user_id uuid, p_library_id uuid, p_role text)`

### 5.9. Détail de T8 — Annulation d'une demande de retrait

**Qui** : un·e coordenador·a OU un·e administrador·a (n'importe lequel·le ; mécanisme de contrôle collégial).

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
2. **J-9 mois - 7 jours** : mail de rappel.
3. **J-9 mois** : passage à `inactive` automatique. Mail final à la personne + à toute la coordination.

**Important** :
- Cette sortie automatique s'applique aussi aux `coordenador`. Si c'est le·la dernier·e coordenador·a, le cron escalade à un·e administrador AnarBib avant exécution (cf. §6.1).
- Une simple **connexion** suffit à réinitialiser le compteur (le cron lit `last_sign_in_at`).

**Cron** : `cron_team_inactive_cleanup` (cf. §12.2).


---

## 6. Cas-limites et garde-fous

### 6.1. Biblio avec un·e seul·e coordenador·a qui démissionne

**Scénario** : la personne déclenche `fn_team_self_demote` ou tente une action qui ferait passer la biblio à 0 coordenador·a actif·ve.

**Comportement** :

1. **Avertissement** : la RPC vérifie qu'on est dans ce cas et **autorise** l'opération mais retourne un avertissement structuré (`{warning: 'last_coordinator_leaving'}`).
2. **Sortie effective** : la biblio se retrouve avec 0 coordenador·a. Les librarians peuvent continuer à fonctionner sur leurs prérogatives (gestion emprunts, validation inscriptions, etc.) mais aucune modification de l'identité publique ou de la configuration n'est possible.
3. **Escalade automatique** : un mail est envoyé aux administradores AnarBib, indiquant que la biblio X est en mode « sans coord ». Iels peuvent intervenir pour aider le collectif à désigner un·e nouveau·elle coordenador·a, ou aider à fermer proprement la biblio.

**Note politique** : ce comportement respecte la souveraineté du collectif (le SIGB ne bloque pas la décision) tout en évitant le chaos silencieux (escalade explicite).

### 6.2. Auto-promotion impossible

Personne ne peut se promouvoir lui-même à un rôle supérieur. Toutes les RPC de promotion vérifient `p_user_id != auth.uid()`.

### 6.3. Coordenador→administrador interdite via UI

**Principe** : l'accès au rôle `administrador` ne peut **jamais** être obtenu via les RPCs de cette spec. Aucune RPC `fn_team_promote_to_administrador` n'est exposée.

L'attribution du rôle `administrador` se fait **hors UI**, par modification SQL directe (par un·e administrador existant·e), selon les règles définies dans le §13.

### 6.4. Biblio sans aucun staff (cas pathologique)

**Scénario** : tous les staff actifs (librarians + coordenadores) deviennent `inactive` simultanément.

**Comportement** :
- La biblio reste « active » techniquement (sa visibility, ses livres, sont accessibles selon RLS)
- Mais aucune action de gestion ne peut plus être faite via l'UI
- Mail urgent aux administradores AnarBib
- Procédure manuelle de redémarrage à définir hors-spec (probablement : créer une nouvelle membership `coordenador` via SQL direct, après validation du collectif)

### 6.5. Multi-membership de la même personne

**Cas accepté** : une personne peut avoir plusieurs lignes `user_library_memberships` dans la même biblio (ex : `reader` + `librarian`), grâce à la contrainte UNIQUE `(user_id, library_id, role)`.

**Règle d'affichage** :
- Dans l'UI onglet `team`, la personne est affichée **une seule fois**, avec son rôle de plus haut niveau actif (ordre : `administrador` > `coordenador` > `librarian` > `reader`).
- L'audit log affiche les changements ligne par ligne (chaque membership a son histoire).

**Règle de RPC** : les RPCs `fn_team_*` opèrent sur une membership précise, identifiée par `(user_id, library_id, role)`. Pas d'ambiguïté.

### 6.6. Interactions entre suspension et pending_removal

**Cas 1** : une personne est `suspended`. On veut l'exclure définitivement.
→ La RPC `fn_team_request_remove_member` n'autorise pas le passage `suspended` → `pending_removal` (les deux sont des états « bloqués »). Pour exclure, il faut d'abord lever la suspension (`fn_team_unsuspend_member`) puis demander le retrait. Cette double étape est **volontaire** : elle force le collectif à acter explicitement la transition.

**Cas 2** : une personne est en `pending_removal`. Un·e coordenador·a veut accélérer.
→ Pas autorisé. Le délai de 7 jours est un garde-fou politique, pas une option. La seule façon d'aller plus vite est : (a) la personne se retire elle-même (T4) ; (b) la suspension immédiate (T6) si l'urgence le justifie (et auquel cas le `pending_removal` initial doit d'abord être annulé).

### 6.7. Tentative de demander le retrait de soi-même

**Comportement** : la RPC retourne une erreur explicite : « pour quitter l'équipe, utilisez l'option "Je passe la main" (auto-rétrogradation) ». Cette distinction est intentionnelle : la spec ne permet pas de confondre une décision personnelle (T4) et une décision collective (T5).

### 6.8. Tentative de promouvoir une personne déjà au même niveau

**Comportement** : retour idempotent (succès silencieux). La RPC vérifie l'état avant action ; si la personne est déjà `librarian` actif, la RPC `fn_team_promote_to_librarian` ne fait rien et retourne `{ok: true, no_change: true}`.

### 6.9. Tentative de rétrograder un·e administrador

**Comportement** : refusée systématiquement. Le rôle `administrador` ne peut être modifié que par les administradores eux·elles-mêmes, via mécanismes hors-spec (cf. §13).

### 6.10. Impact sur les emprunts en cours d'un·e librarian destitué·e

**Scénario** : un·e librarian a des emprunts en cours d'un·e lecteur·rice, et est destitué·e (passage à `inactive`).

**Comportement** :
- Les emprunts en cours **persistent** (ils sont liés au lecteur·rice, pas au librarian qui les a saisis)
- L'historique des actions du librarian dans le système est conservé (audit logs des emprunts, etc.)
- La personne peut redevenir membre plus tard (nouvelle ligne de membership) sans que ses anciens emprunts soient affectés

---

## 7. Audit log

### 7.1. Principe (P5 — Transparence maximale)

Tous les changements de rôle et de status sont **journalisés** dans une table dédiée. La consultation est :

- **Public au staff actif de la biblio** : tout `librarian`, `coordenador`, `administrador` actif·ve dans la biblio peut lire l'audit log de cette biblio.
- **Privé au reader** : un·e reader ne voit pas l'audit log de l'équipe (ce n'est pas une donnée publique du catalogue).
- **Privé inter-biblios** : les staff d'une biblio A ne voient pas l'audit de la biblio B.

### 7.2. Contenu d'une entrée

Chaque action génère **une entrée** dans `library_membership_audit` :

| Champ | Type | Description |
|---|---|---|
| `id` | uuid PK | identifiant unique de l'entrée |
| `library_id` | uuid FK | biblio concernée |
| `target_user_id` | uuid FK | personne dont la membership a changé |
| `actor_user_id` | uuid FK | personne qui a effectué l'action (NULL si cron) |
| `action` | text | code de l'action (cf. §7.3) |
| `role` | text | rôle concerné (`reader`, `librarian`, `coordenador`) |
| `status_before` | text | status avant (peut être NULL pour création) |
| `status_after` | text | status après |
| `reason` | text | justification (peut être NULL ; obligatoire pour suspend, optionnelle ailleurs) |
| `metadata` | jsonb | données contextuelles (ex : pending_removal_until, etc.) |
| `created_at` | timestamptz | horodatage de l'action |

### 7.3. Codes d'action

| Code | Description | RPC source |
|---|---|---|
| `promoted_to_librarian` | T1 | `fn_team_promote_to_librarian` |
| `promoted_to_coordenador` | T2 | `fn_team_promote_to_coordenador` |
| `self_demoted` | T3 (auto-rétro coord) ou T4 (auto-rétro librarian) | `fn_team_self_demote` |
| `removal_requested` | T5 (déclenchement carence) | `fn_team_request_remove_member` |
| `removal_cancelled` | T8 (annulation) | `fn_team_cancel_remove_member` |
| `removal_completed` | T5 (fin carence, J+7) | cron `cron_team_pending_removal_complete` |
| `suspended` | T6 | `fn_team_suspend_member` |
| `unsuspended` | T7 | `fn_team_unsuspend_member` |
| `inactive_warning_30d` | T9 (mail J-30) | cron `cron_team_inactive_cleanup` |
| `inactive_warning_7d` | T9 (mail J-7) | cron `cron_team_inactive_cleanup` |
| `inactive_auto` | T9 (sortie auto J-9 mois) | cron `cron_team_inactive_cleanup` |

### 7.4. Écriture

L'écriture est faite **directement par les RPCs SECURITY DEFINER** (pas via trigger). Cela permet de capturer le contexte applicatif (`actor_user_id`, `reason`) qui ne serait pas accessible dans un trigger.

### 7.5. RLS de la table audit

```sql
-- Lecture : staff actif de la biblio uniquement
CREATE POLICY library_membership_audit_staff_read
ON public.library_membership_audit
FOR SELECT
TO authenticated
USING (
  public.user_has_library_staff_role(auth.uid(), library_id)
);

-- Écriture : aucune policy. Seules les RPCs SECURITY DEFINER y accèdent.
```

### 7.6. Rétention

Les entrées d'audit sont **conservées indéfiniment**. Elles font partie de l'histoire collective de la biblio.

Cas de suppression : si une biblio ferme (cf. workflow de fermeture, hors spec), les audit logs sont archivés ou supprimés selon la politique RGPD applicable.


---

## 8. Notifications mail

### 8.1. Principe (P6 — Notifications systématiques)

**Tout changement de rôle déclenche un email** :
- À la **personne concernée** (toujours)
- À **tous les coordenadores actifs** de la biblio (toujours)
- Aux **administradores AnarBib** dans certains cas critiques (compte abandonné détecté sur le·la dernier·e coord, biblio sans staff, etc.)

### 8.2. Pattern d'event types

Les nouveaux events suivent le préfixe `team.*` (cohérent avec `loan.*`, `res.*`, `wf.*` existants).

| Event type | Déclenché par | Destinataires |
|---|---|---|
| `team.promoted_to_librarian` | T1 | personne + coordenadores |
| `team.promoted_to_coordenador` | T2 | personne + coordenadores |
| `team.self_demoted` | T3, T4 | personne + coordenadores |
| `team.removal_requested` | T5 | personne + coordenadores |
| `team.removal_cancelled` | T8 | personne + coordenadores |
| `team.removal_completed` | T5 (J+7) | personne + coordenadores |
| `team.suspended` | T6 | personne + coordenadores |
| `team.unsuspended` | T7 | personne + coordenadores |
| `team.inactive_warning_30d` | T9 (J-30) | personne uniquement |
| `team.inactive_warning_7d` | T9 (J-7) | personne uniquement |
| `team.inactive_auto` | T9 (J-9 mois) | personne + coordenadores |
| `team.last_coordinator_leaving` | §6.1 | administradores AnarBib uniquement |

### 8.3. Clés i18n nécessaires

Les chaînes i18n pour les mails seront ajoutées dans `supabase/functions/_shared/i18n/mail-strings.ts` × 6 locales (pt-BR, fr, es, en, it, de) selon les conventions militantes déjà établies (cf. mémoire interne).

**Liste minimale** (le détail des chaînes sera précisé à l'implémentation) :

```
team.promoted_to_librarian.intro       (corps du mail à la personne promue)
team.promoted_to_librarian.sub         (sous-titre / contexte)
team.promoted_to_librarian.coord_intro (corps du mail aux coordenadores)
team.promoted_to_coordenador.intro
...
```

Soit environ **40-60 nouvelles clés × 6 locales = 240 à 360 chaînes**. À traiter via un script Python idempotent (pattern `add-pageTitle-keys.py` du 05/05).

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
1. Trigger DB envoie un payload via webhook
2. Edge Function reçoit, dispatche via `dispatchNotifyEvent(event, recordId, payload)`
3. Mail envoyé avec les chaînes i18n correspondantes

**Pour cette spec** :
- Les RPCs `fn_team_*` envoient explicitement les events (pas via triggers DB), pour avoir un contexte applicatif riche (qui a déclenché, raison, etc.).
- Implémentation : appel direct depuis la RPC à `pg_net.http_post()` vers `notify-event`, OU passage par une table de queue (`notification_outbox`) avec un cron léger qui déclenche `notify-event`. À arbitrer en implémentation selon ce qui existe déjà.

---

## 9. Interface utilisateur·rice

### 9.1. Localisation

Toutes les actions sont dans **`/biblioteca`, onglet `team`**.

L'onglet `team` existe déjà et affiche actuellement la liste des membres en lecture seule. Cette spec **enrichit** cet onglet sans changer sa localisation.

### 9.2. Visibilité de l'onglet

L'onglet `team` est visible :
- En **lecture seule** pour les `librarian` actifs (peuvent voir l'équipe, l'audit log, mais pas agir)
- En **mode action** pour les `coordenador` et `administrador` actifs (peuvent promouvoir, retirer, suspendre, etc.)

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
│  │  Voltairine d.C. coordenador     [Rétrograder]       │   │
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

### 9.4. Comportements UI précis

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

**Pour un·e administrador·a** :
- Tout ce que voit un·e coordenador·a
- Plus quelques actions spéciales accessibles uniquement aux admins (intervention en cas de blocage)

### 9.5. Modales de confirmation

Toute action **non triviale** ouvre une modale de confirmation :

- **Promouvoir** : modale simple « Êtes-vous sûr·e de vouloir promouvoir <nom> à <rôle> ? » + champ optionnel « Raison » + boutons [Confirmer] / [Annuler].
- **Suspendre** : modale avec champ **obligatoire** « Raison de la suspension » + alerte « La personne sera notifiée par mail ».
- **Demander l'exclusion** : modale forte, rouge, avec mention du délai de carence 7j explicite, raison optionnelle, et confirmation explicite « Je comprends que cette demande prendra effet le <date J+7> sauf annulation par un·e autre coordenador·a ».
- **Lever suspension / Annuler exclusion** : modales simples « Êtes-vous sûr·e ? ».
- **Auto-rétrogradation** : modale **obligatoire** avec mention claire des conséquences (« Vous perdrez les permissions de coordenador·a immédiatement. Cette action est réversible uniquement par un·e autre coordenador·a »).

### 9.6. États visuels

Les badges de statut affichés sur chaque ligne :

| Status DB | Badge UI | Couleur |
|---|---|---|
| `active` | rôle (ex « librarian ») | vert / neutre |
| `suspended` | « suspendu·e » | orange |
| `pending_removal` | « préavis jusqu'au <date>` | rouge |
| `inactive` | (n'apparaît pas dans la liste par défaut) | n/a |

### 9.7. Internationalisation

Toutes les chaînes UI utilisent le pattern i18n existant (`useIntl`, `t({id: 'biblioteca.team.*'})`). Les nouvelles clés à créer (estimation : ~40 clés × 6 locales = 240 chaînes), à livrer en un seul lot via un script Python idempotent.


---

## 10. Modèle de données

### 10.1. Modifications de la table existante

**Table `user_library_memberships`** : la structure actuelle est largement compatible. Modifications minimales :

```sql
-- 1. Élargir le CHECK constraint pour ajouter 'pending_removal'
ALTER TABLE public.user_library_memberships
  DROP CONSTRAINT user_library_memberships_status_check;

ALTER TABLE public.user_library_memberships
  ADD CONSTRAINT user_library_memberships_status_check
  CHECK (status IN ('active', 'inactive', 'pending', 'pending_removal', 'suspended'));

-- 2. Ajouter les colonnes pour le délai de carence
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
  role            text NOT NULL CHECK (role IN ('reader', 'librarian', 'coordenador', 'administrador')),
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

-- Lecture : staff actif de la biblio
CREATE POLICY library_membership_audit_staff_read
ON public.library_membership_audit
FOR SELECT
TO authenticated
USING (
  public.user_has_library_staff_role(auth.uid(), library_id)
);

-- Pas de policy d'écriture : seules les RPC SECURITY DEFINER y accèdent
COMMENT ON TABLE public.library_membership_audit IS
  'Journal des changements de rôle/status dans les équipes de biblio. Lecture pour le staff actif (transparence P5). Écriture uniquement via RPC SECURITY DEFINER.';
```

### 10.3. Pas de modification de la contrainte UNIQUE

La contrainte actuelle `(user_id, library_id, role)` est conservée telle quelle. Elle permet le multi-membership d'une même personne dans une biblio (par exemple `reader` + `librarian` simultanés), ce qui est utile pour préserver l'historique lors des promotions/rétrogradations.

---

## 11. API : RPC SECURITY DEFINER

### 11.1. Conventions

Toutes les RPCs respectent les règles suivantes :

- Préfixe : `fn_team_*`
- `LANGUAGE plpgsql SECURITY DEFINER`
- `SET search_path = public, pg_temp`
- Vérifications d'autorisation explicites en début de fonction (pattern `IF NOT user_can_manage_library(...) THEN RAISE EXCEPTION 'unauthorized' END IF`)
- Retournent `jsonb` structuré : `{ok: true|false, action: '...', warnings: [], errors: []}`
- Écrivent dans `library_membership_audit` à chaque action réussie
- Émettent un event `team.*` via `notify-event` à chaque action réussie
- `GRANT EXECUTE` accordé à `authenticated` uniquement (pas à `anon`)

### 11.2. Liste des RPCs

| RPC | Signature | Rôle requis (auth.uid()) |
|---|---|---|
| `fn_team_promote_to_librarian` | `(p_user_id uuid, p_library_id uuid)` | coordenador+ |
| `fn_team_promote_to_coordenador` | `(p_user_id uuid, p_library_id uuid)` | coordenador+ |
| `fn_team_self_demote` | `(p_library_id uuid, p_target_role text)` | staff actif (auto) |
| `fn_team_request_remove_member` | `(p_user_id uuid, p_library_id uuid, p_role text, p_reason text)` | coordenador+ |
| `fn_team_cancel_remove_member` | `(p_user_id uuid, p_library_id uuid, p_role text)` | coordenador+ |
| `fn_team_suspend_member` | `(p_user_id uuid, p_library_id uuid, p_role text, p_reason text)` | coordenador+ |
| `fn_team_unsuspend_member` | `(p_user_id uuid, p_library_id uuid, p_role text)` | coordenador+ |

### 11.3. Pattern type d'une RPC (exemple : promote_to_librarian)

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

  -- 2. Vérifier que l'acteur·rice est coordenador+ de la biblio cible
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can promote';
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

  -- 7. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_librarian', 'librarian',
     COALESCE(v_existing.status, NULL), 'active');

  -- 8. Notification mail
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
  'Promeut un user au rôle librarian dans une biblio. Cooptation par coordenador+. Cf. spec-gouvernance-roles.md §5.2.';
```

Les autres RPCs suivent le même pattern, avec leurs vérifications spécifiques.

### 11.4. Helper d'envoi des notifications

Une fonction helper `fn_team_notify_event(p_event text, p_payload jsonb)` est créée pour centraliser l'envoi des events team vers `notify-event`. Elle peut, selon l'arbitrage d'implémentation :

- **Option A** : faire un `pg_net.http_post()` direct vers l'Edge Function `notify-event` avec le payload
- **Option B** : INSERT dans une table `notification_outbox` puis cron léger qui dispatche

L'option B est plus robuste (résilience aux pannes momentanées) et recommandée si l'infrastructure existe.

---

## 12. Cron jobs

Les crons sont implémentés via `pg_cron` (déjà en place pour le rafraîchissement du catalogue, cf. mémoire #5).

### 12.1. `cron_team_pending_removal_complete`

**Fréquence** : toutes les heures.

**Action** : passe les memberships `pending_removal` dont `pending_removal_until <= now()` à `inactive`.

```sql
CREATE OR REPLACE FUNCTION public.cron_team_pending_removal_complete()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_membership record;
BEGIN
  FOR v_membership IN
    SELECT *
    FROM public.user_library_memberships
    WHERE status = 'pending_removal'
      AND pending_removal_until <= now()
  LOOP
    UPDATE public.user_library_memberships
    SET status = 'inactive',
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now()
    WHERE id = v_membership.id;

    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, metadata)
    VALUES
      (v_membership.library_id, v_membership.user_id, NULL,
       'removal_completed', v_membership.role, 'pending_removal', 'inactive',
       jsonb_build_object('originally_requested_by', v_membership.pending_removal_requested_by));

    PERFORM public.fn_team_notify_event('team.removal_completed',
      jsonb_build_object('library_id', v_membership.library_id,
                         'target_user_id', v_membership.user_id,
                         'role', v_membership.role));
  END LOOP;
END;
$$;

-- Programmation hourly
SELECT cron.schedule(
  'cron_team_pending_removal_complete_hourly',
  '0 * * * *',
  'SELECT public.cron_team_pending_removal_complete();'
);
```

### 12.2. `cron_team_inactive_cleanup`

**Fréquence** : quotidienne (1× par jour).

**Action** :
1. Pour chaque membership `active` d'un user dont `last_sign_in_at` est à exactement J-9mois - 30 jours : envoyer `team.inactive_warning_30d` à la personne, audit log.
2. Idem pour J-9mois - 7 jours : `team.inactive_warning_7d`.
3. Pour chaque membership `active` dont `last_sign_in_at` est à >= J-9mois : passage à `inactive`, mail + audit log + escalade administrador AnarBib si c'est le·la dernier·e coord (cf. §6.1).

**Garde-fou** : si `last_sign_in_at` est NULL (compte jamais utilisé), le critère ne s'applique pas (sinon, on virerait des comptes tout neufs en attente de validation). À adapter selon l'audit du champ.

### 12.3. Programmation et monitoring

Les crons sont déclarés dans `pg_cron` et leurs exécutions tracées dans `cron.job_run_details`. À monitorer :

- Échecs de cron (`status = 'failed'`)
- Durées anormales (un cron qui prend > 5 min)
- Volume d'actions générées par exécution (alerte si > N actions, signe d'une anomalie)

---

## 13. Rôle administrador AnarBib

### 13.1. Cadre actuel (transitoire)

Au 05/05/2026, **un·e seul·e administrador** existe : Xavier (auteur·ice de cette spec). Cette spec **ne touche pas** à ce rôle, qui reste géré hors-UI par modification SQL directe.

### 13.2. Cadre cible (à formaliser dans une spec ultérieure)

La gouvernance du rôle `administrador` AnarBib est elle-même un sujet politique. Cadrage validé le 05/05/2026 :

- **Cercle restreint** : 1, 3 ou 5 administradores maximum
- **Nombre impair** : pour permettre les départages en cas de décision difficile
- **Nomination** : cooptation entre administradores existant·es, selon des règles internes à formaliser
- **Hors UI** : aucune RPC `fn_team_promote_to_administrador` n'est jamais exposée
- **Modalités de décision** : à définir (consensus, majorité simple, etc.)

### 13.3. Disposition transitoire (cadre minimal)

Tant que le rôle `administrador` est tenu par une seule personne (situation au 05/05/2026), la **désignation d'un·e successeur·e** se fait **en accord avec les coordenadores des biblios actives** d'AnarBib. Ce mécanisme transitoire :

- préserve la souveraineté des biblios fédérées (elles sont consultées, leur avis compte)
- évite la rupture de service (un·e successeur·e est toujours désigné·e à l'avance)
- génère une **vie organique** au sein de la communauté AnarBib qui pourra inspirer la spec future
- reste **hors-UI** : la passation se fait par accord politique puis modification SQL directe par l'administrador sortant·e

Cette disposition transitoire reste valide jusqu'à la rédaction et l'adoption d'une spec dédiée `spec-administrador-anarbib.md`.

### 13.4. Note de spec future

Une spec dédiée `spec-administrador-anarbib.md` devra :

- Définir le mode de désignation des administradores (qui propose, qui valide, comment)
- Définir les règles de fonctionnement collégial (quorum, scrutin, etc.)
- Définir les modalités de retrait d'un·e administrador (volontaire ou collégial)
- Définir les rapports avec le réseau RebAL et les biblios fédérées

Cette spec future devra être **rédigée collectivement** (pas seul·e), idéalement dans le cadre d'une rencontre du réseau (Bologna sept 2026 par exemple).

---

## 14. Plan d'implémentation

### 14.1. Découpage en lots

L'implémentation peut se faire en lots indépendants, déployables progressivement.

#### Lot 1 — Infrastructure DB (estimation : 1/2 journée)

- Migration : élargissement du CHECK constraint sur `status`
- Migration : ajout des colonnes `pending_removal_until`, `pending_removal_requested_by`
- Migration : création de `library_membership_audit`
- Migration : création de l'index `idx_ulm_pending_removal_until`
- Test : insertion + sélection d'une ligne d'audit, vérif RLS

#### Lot 2 — RPCs cooptation (T1, T2) (estimation : 1 journée)

- `fn_team_promote_to_librarian`
- `fn_team_promote_to_coordenador`
- Helper `fn_team_notify_event`
- Tests : promotion réussie, idempotence, refus si non coord, refus auto-promo

#### Lot 3 — RPCs retraits (T3-T8) (estimation : 1 journée)

- `fn_team_self_demote`
- `fn_team_request_remove_member`
- `fn_team_cancel_remove_member`
- `fn_team_suspend_member`
- `fn_team_unsuspend_member`
- Tests : carence 7j, annulation, suspension/levée, refus tentatives interdites

#### Lot 4 — Crons (estimation : 1/2 journée)

- `cron_team_pending_removal_complete` (hourly)
- `cron_team_inactive_cleanup` (daily)
- Tests : forcer un cas avec `pending_removal_until` dans le passé, vérifier le passage à inactive

#### Lot 5 — Notifications mail (estimation : 1 journée)

- Nouvelles clés i18n × 6 locales (~240-360 chaînes) via script Python idempotent
- Adaptation de `notify-event` pour gérer les events `team.*`
- Tests : envoi de chaque type d'event, réception correcte par les destinataires

#### Lot 6 — UI : enrichissement onglet `team` (estimation : 1-2 journées)

- Nouvelles clés i18n UI × 6 locales (~240 chaînes)
- Composants : boutons d'action, modales de confirmation
- Sections : « Suspensions et préavis en cours », « Historique de l'équipe »
- Tests : parcours complet pour coordenador, parcours lecture seule pour librarian

#### Lot 7 — Workflow d'invitation (estimation : à cadrer)

Cf. spec future `spec-invitation-equipe.md`. Concerne le cas où on veut ajouter à l'équipe une personne qui n'a pas encore de compte AnarBib (mail d'invitation, lien de signup pré-affilié, etc.).

### 14.2. Ordre de déploiement recommandé

1. Lot 1 (DB) en premier, déployable seul (ne change rien fonctionnellement)
2. Lots 2 et 3 (RPCs) ensemble, mais testables sans UI via curl/SQL
3. Lot 5 (notifications) avant Lot 6 (UI), pour que les actions UI envoient déjà des mails dès le premier déploiement
4. Lot 6 (UI) en dernier
5. Lot 4 (crons) à activer une fois Lot 6 testé en prod, pour ne pas avoir de carences automatiques sans UI pour annuler

### 14.3. Points d'attention transverses

- **i18n** : respect des conventions militantes (cf. mémoire). Toutes les locales en une fois, jamais de fallback temporaire.
- **Tests** : prévoir des tests d'intégration sur scénarios complets (cf. §15 cas d'usage).
- **Migrations** : versionnées avec date dans `db/migrations/YYYY_MM_DD_*.sql`, idempotentes (DROP IF EXISTS / CREATE OR REPLACE), commitées sur le repo.
- **Rollback** : chaque migration doit avoir un script de rollback testé (DROP des nouvelles colonnes/contraintes).

---

## 15. Cas d'usage de référence

### 15.1. Voltairine coopté·e librarian

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
> 3. Modale de confirmation, Lucy confirme
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

### 15.5. L'ultime coord part

> La BLMF n'a plus qu'un seul coord, Errico. Il doit partir (déménagement, plus de temps).
>
> 1. Errico va dans `/biblioteca`, onglet `team`, clique « Je passe la main »
> 2. Modale spéciale : « **ATTENTION** : tu es l'unique coordenador·a actif·ve. La biblio se retrouvera sans coordination. Les administradores AnarBib seront notifié·es. Continuer ? »
> 3. Errico confirme
> 4. Sa membership coordenador passe à `inactive`
> 5. Mail à tous les administradores AnarBib : « La BLMF n'a plus de coordenador·a. Voici les librarians actifs : … »
> 6. La BLMF continue à fonctionner en mode dégradé (les librarians peuvent gérer les emprunts, etc., mais pas la config)
> 7. Hors-logiciel, Xavier (admin AnarBib) prend contact avec le collectif BLMF pour aider à désigner un·e nouveau·elle coord
> 8. Quand le collectif a décidé, Xavier exécute la promotion via SQL direct OU via la même UI (s'il a accès en tant qu'admin)

---

## Annexe A : Glossaire

- **AG** : Assemblée Générale (réunion collective de prise de décision)
- **Cooptation** : nomination par les membres existants
- **Multi-membership** : possibilité d'avoir plusieurs lignes de membership pour une même personne dans une même biblio
- **Carence** : délai entre une décision et son effet (ici 7 jours pour les exclusions)
- **RebAL** : Réseau de Bibliothèques Alternatives Libertaires

## Annexe B : Glossaire des fonctions techniques

- `user_has_library_staff_role(user_id, library_id)` : helper retournant true si l'utilisateur·rice a un rôle librarian, coordenador ou administrador actif dans la biblio. Existe depuis le 04/05/2026.
- `user_can_manage_library(library_id)` : helper retournant true si auth.uid() a un rôle coordenador ou administrador actif dans la biblio. Existe depuis le 04/05/2026.
- `fn_library_visible_to_caller(library_id)` : helper de visibilité (public/network/private). Existe depuis le 02/05/2026.

## Annexe C : Références aux specs cousines

- `spec-validation-physique.md` (à rédiger) : validation physique des comptes lecteur·rices
- `spec-migration-compte.md` (940 lignes, cadrée le 03/05/2026) : migration d'un compte d'une biblio à une autre
- `spec-invitation-equipe.md` (à rédiger) : workflow d'invitation par email pour les personnes sans compte AnarBib

## Annexe D : Décisions politiques cadrées

Cette spec consigne les décisions prises lors d'une session de cadrage avec Xavier le 05/05/2026 :

| Q | Décision |
|---|---|
| Q1 (vision politique) | Délégation avec rotation des fonctions (rôles = fonctions temporairement déléguées) |
| Q2 (reader→librarian) | Coordenador+ uniquement (cooptation) |
| Q3 (librarian→coordenador) | Coordenador+ uniquement (cooptation) |
| Q4 (rétrograder coord) | Soi-même + autres coordenadores |
| Q5 (librarian→reader) | Soi-même + coordenadores |
| Q6 (modèle exclusion) | 3 états avec délai de carence 7j |
| Q7 (compte abandonné) | Sortie auto à 9 mois + mails J-30 et J-7 |
| Q8 (audit log visibilité) | Public au staff |
| Q9 (notifications) | Personne concernée + toute la coordination |
| Q10 (UI) | Onglet « Equipe » dans /biblioteca |
| Q11 (dernier coord part) | Avertir + autoriser + escalader administrador |
| Q12 (multi-membership) | Strictement local (biblio par biblio) |
| Q13 (coord→admin) | Non, écrit comme principe |
| Q14 (succession admin) | Cercle 1/3/5 (impair), modalités à formaliser ailleurs |

---

*Fin du document.*
