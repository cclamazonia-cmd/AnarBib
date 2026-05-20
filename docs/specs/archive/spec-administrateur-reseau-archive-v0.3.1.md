# Spec : Séparation administrateur réseau / staff local

**Version** : 0.3.1
**Date** : 15/05/2026 (consignation des raffinements d'implémentation)
**Auteur·rice** : Xavier (lead dev) + Claude (assistant·e)
**Statut** : **doctrine complète, implémentation entièrement livrée en production**

**Historique de version** :
- v0.1 (11/05/2026, première rédaction, 846 lignes) : pose la séparation conceptuelle, l'architecture cible, la séquence de 6 paquets (A à F).
- v0.2 (11/05/2026, refonte complète) : sémantique « page = périmètre » des compteurs, nouvelle vue `api.network_overview`, prise en compte du membership coordenador BLMF de Xavier inscrit le 11/05/2026, MAJ des décisions ouvertes, ouverture des questions Q7-Q8.
- v0.3 (11/05/2026, consignation des décisions) : toutes les questions Q2-Q8 tranchées. Doctrine politique complète. Ajout des spécifications techniques détaillées (`disclose_identity`, rationale obligatoire pour opposed, rappels J+14/J+25, carence 7j retrait collectif, table `cross_library_actions_log` avec criticité, digest hebdomadaire + notifications immédiates). Séquence v0.1 conservatrice confirmée (pas de grand bond).
- **v0.3.1 (15/05/2026, consignation des raffinements d'implémentation)** : doctrines des notifications inscrites au fil de l'implémentation des paquets D-F et du chantier #114 (mails militants). Tous les paquets A-F livrés en production. Mise à jour des sections concernées pour refléter ce qui a effectivement été implémenté, avec les divergences mineures par rapport à v0.3 et les doctrines raffinées en cours de codage. La spec ne décrit plus une cible : elle décrit l'état du système en production au 14/05/2026 soir.

---

## Préambule politique

AnarBib n'est pas une chaîne de bibliothèques avec un siège central. C'est un réseau fédéré de collectifs autonomes. La structure des rôles dans le SIGB doit refléter cette réalité politique, pas la masquer.

Aujourd'hui, le rôle `administrador` est rattaché à une `library_id` dans la table `user_library_memberships`. Cette modélisation suggère implicitement qu'un administrateur AnarBib *administre une biblio*. Ce n'est pas vrai politiquement : un administrateur réseau anime la coordination inter-biblios, il ne dirige aucune biblio particulière. Chaque biblio reste autonome dans son fonctionnement, ses règles, ses adhésions.

Cette spec acte la séparation entre :

- **Le staff local** d'une biblio : les personnes qui animent au quotidien une biblio donnée (`librarian`, `coordenador`). Leur autorité politique se situe dans le périmètre de leur biblio.
- **L'administration du réseau** : les personnes qui assurent la coordination inter-biblios, la modération du catalogue partagé, l'accueil des nouvelles biblios, la maintenance technique. Leur autorité politique est transverse, mais elle ne se substitue jamais à l'autonomie locale.

Cette distinction n'est pas administrative, elle est politique. Elle évite la confusion entre « qui anime cette biblio » et « qui anime le réseau », confusion qui pourrait laisser penser qu'un administrateur réseau est un échelon supérieur dans une hiérarchie. Il n'en est rien : les biblios sont autonomes, le réseau est leur lieu de coordination, pas leur direction.

### Décision politique additionnelle (11/05/2026 matin)

La v0.1 envisageait que les compteurs « équipe » d'une biblio puissent englober les administrateurs réseau (parce qu'ils peuvent intervenir partout). La v0.2 retient une règle plus simple et plus honnête politiquement : **chaque page raconte l'histoire de son périmètre, sans calcul croisé**.

Concrètement :
- La page d'une biblio compte ses memberships locaux. Point.
- La page du réseau compte ses administrateurs réseau. Point.
- Une personne engagée dans les deux périmètres apparaîtra dans les deux pages, une fois dans chaque, sans dédoublonnage croisé.

Cette règle se justifie politiquement : chaque périmètre a sa propre identité, son propre récit. Mélanger les deux dans un compteur unique masquerait précisément ce que la séparation cherche à clarifier.

---

## Table des matières

1. Objectifs et non-objectifs
2. Sémantique des compteurs *(section centrale v0.2, conservée v0.3 et v0.3.1)*
3. Architecture cible *(v0.3.1 : décrit l'état en prod)*
4. Logique de cooptation à l'unanimité *(v0.3.1 : doctrine des notifications raffinée par #114)*
5. Mapping des modifications nécessaires
6. Plan d'implémentation par paquets *(v0.3.1 : tous livrés en production)*
7. Implications UI détaillées *(v0.3.1 : décrit l'UI en prod après paquet E)*
8. Risques et contre-mesures
9. Cas particulier : situation de Xavier au 11/05/2026 → résolue au paquet F
10. Calendrier prévisionnel → calendrier réel
11. Décisions tranchées *(v0.3.1 : ajout des raffinements de notification)*
12. Annexes *(v0.3.1 : changelog v0.3 → v0.3.1)*

---

## 1. Objectifs et non-objectifs

### 1.1 Objectifs *(tous atteints au 14/05/2026)*

1. **Séparer la table** : créer `network_administrators` distincte de `user_library_memberships`. Le rôle `administrador` disparaît de cette dernière. **✅ Atteint au paquet F (13/05).**
2. **Centraliser l'autorisation** : remplacer les 22 sous-SELECT inline dans les RLS par 2-3 helpers SQL qui consolident « staff local » et « admin réseau ». **✅ Atteint au paquet C (47 RLS alignées au 11/05).**
3. **Acter la cooptation à l'unanimité** : implémenter en base la garantie qu'un administrateur réseau ne peut être ajouté qu'avec l'accord explicite de tous les administrateurs en place. **✅ Atteint au paquet D (workflow complet, mails militants livrés par #114).**
4. **Préserver les droits d'intervention** : un administrateur réseau peut toujours agir comme staff local sur n'importe quelle biblio (lecture, écriture, opérationnel) — c'est son droit politique transverse. **✅ Atteint via les helpers `user_can_act_as_staff_on_library` et `user_can_engage_library`.**
5. **Garantir la traçabilité** : tout ajout/retrait d'administrateur réseau est audité avec la liste des votes de cooptation. **✅ Atteint via `network_administrator_audit` (immuable) + `network_admin_cross_library_actions_log` pour les actions transverses (C.5).**
6. **(Nouveau v0.2)** **Clarifier la sémantique des compteurs** : chaque vue affiche les engagements de son périmètre, sans calcul croisé entre local et réseau. **✅ Atteint au paquet E (UI calée sur `api.network_overview` et `api.library_circulation_stats` redéfinies).**

### 1.2 Non-objectifs

1. **Modifier la sémantique des rôles locaux** : `reader`, `librarian`, `coordenador` restent inchangés.
2. **Toucher au cycle de vie des memberships locaux** : les transitions `active` → `pending_removal` → `removed` de la spec gouvernance restent comme posées le 5/05/2026 (avec l'élargissement du CHECK fait le 11/05).
3. **Implémenter une hiérarchie réseau** : il n'y a pas de « super-admin » au-dessus des administrateurs réseau. Les administrateurs sont en pair·e·s.
4. **Imposer une durée de mandat** : les administrateurs réseau ne sont pas révocables par majorité, mais ils peuvent se retirer eux-mêmes ou être retirés à l'unanimité.

---

## 2. Sémantique des compteurs *(section centrale, conservée v0.3.1)*

C'est la section qui distingue le plus la v0.2 de la v0.1. Elle pose la grammaire de tous les compteurs militants de l'application, pour qu'on ne se reperde plus dans des calculs croisés ambigus.

### 2.1 La règle, en une phrase

**Chaque page raconte l'histoire de son périmètre. Un compteur compte ce qui est inscrit dans son périmètre, ni plus, ni moins.**

Périmètre d'une biblio : les memberships locaux de cette biblio (`reader`, `librarian`, `coordenador`).
Périmètre du réseau : les administrateurs réseau (`network_administrators`).

Les deux périmètres sont **disjoints** par construction depuis le paquet F (suppression du rôle `administrador` local). Une même personne peut être inscrite dans les deux, mais ce sont **deux inscriptions politiques distinctes**, comptées chacune dans leur périmètre.

### 2.2 Conséquences pratiques

#### Page `/biblioteca/<slug>` (vue d'une biblio donnée)

Tous les compteurs sont **locaux** par construction. Ils interrogent uniquement `user_library_memberships` filtré sur cette biblio.

| Compteur | Définition |
|---|---|
| Bibliotecárias·os ativas·os | `COUNT(DISTINCT user_id) WHERE role IN ('librarian','coordenador') AND status='active' AND library_id=<>` |
| Leitoras·es ativas·es | `COUNT(DISTINCT user_id) WHERE role='reader' AND status='active' AND library_id=<>` |
| Exemplares | inventaire de cette biblio |
| Empréstimos abertos | circulation de cette biblio |
| etc. | tous filtrés par `library_id` |

Les administrateurs réseau **n'apparaissent pas** dans ces compteurs, même s'ils peuvent techniquement intervenir sur cette biblio. Leur existence est invisible depuis la page d'une biblio.

#### Page `/rede` onglet « Vue d'ensemble »

Mélange judicieusement deux types d'indicateurs : ceux du réseau lui-même (admins réseau) et ceux qui agrègent par biblio (mais sans calcul croisé).

| Compteur | Définition | Source |
|---|---|---|
| Administradores da rede | `COUNT(DISTINCT user_id) WHERE status='active'` | `network_administrators` |
| Bibliotecas ativas | `COUNT(*) WHERE is_active=true` | `libraries` |
| Documentos | `COUNT(*)` | `books` |
| Autoridades | `COUNT(*)` | `authors` |
| Exemplares (réseau) | somme sur toutes les biblios | `library_circulation_stats` |
| Empréstimos abertos (réseau) | somme sur toutes les biblios | `library_circulation_stats` |
| Reservas ativas (réseau) | somme sur toutes les biblios | `library_circulation_stats` |

**Important** : il n'y a pas de compteur « équipe réseau » au sens « toutes les personnes engagées quelque part ». Ce concept n'a pas de sens politique — chaque biblio a sa propre équipe, et le réseau a ses administrateurs. Ce sont des engagements politiquement distincts, pas une masse à agréger.

#### Page `/rede` onglet « Bibliotecas » (cartes/lignes par biblio)

Chaque ligne reflète une biblio. Les compteurs par ligne sont **locaux**, comme dans `/biblioteca/<slug>`. La ligne BLMF montre l'équipe locale BLMF, pas « les personnes qui peuvent intervenir sur BLMF ».

#### Page `/rede` onglet « Administradores »

Liste des administrateurs réseau, alimentée par `api.network_administrators_public_v1` (vue à 7 colonnes créée au paquet E, cf. §3.3bis). Aucune information par biblio ici — c'est l'inverse, on regarde le réseau depuis son centre.

### 2.3 Implémentation : deux vues distinctes

Pour soutenir cette sémantique sans calcul croisé, on a **deux vues principales** au lieu d'une seule mélangée :

**Vue locale par biblio** : `api.library_circulation_stats`
- Tous les compteurs sont **strictement locaux**
- `librarians_active` ne compte que `role IN ('librarian','coordenador')`, plus aucune mention de `'administrador'` (depuis le paquet F qui a retiré ce rôle du CHECK constraint)
- `readers_active` reste tel quel

**Vue globale réseau** : `api.network_overview`
- Compteurs au niveau du réseau : nombre d'admins, nombre de biblios, etc.
- Pas de calcul croisé personnes×biblios

### 2.4 Pourquoi cette règle est politiquement saine

1. **Honnêteté** : si tu animes BLMF, ton engagement local est compté dans BLMF. Si tu animes la coordination AnarBib, ton engagement réseau est compté au niveau réseau. Personne ne te compte « 1.5 fois » parce que tu es engagé·e aux deux niveaux. Chaque inscription a son lieu de compte.

2. **Lisibilité** : un militant qui regarde la carte BLMF dans `/rede` voit immédiatement « 3 personnes engagées localement », sans avoir à se demander si parmi ces 3 il y a des administrateurs réseau « extérieurs » qui gonflent le compteur.

3. **Robustesse à l'évolution** : si demain on ajoute des rôles intermédiaires (auxiliaire, stagiaire, observateur·rice), la règle « page = périmètre » reste claire et n'a pas à arbitrer entre cumul et dédoublonnage.

4. **Cohérence avec la séparation politique** : la spec dit que admin réseau et staff local sont deux choses distinctes. Les compteurs doivent le refléter, pas le masquer dans un agrégat.

### 2.5 Cas limite : une personne sans engagement local mais admin réseau

Si une personne est uniquement administratrice réseau (pas membre staff d'une biblio), elle :
- N'apparaît dans aucun compteur de biblio (`/biblioteca/<slug>` ou cartes `/rede`)
- Apparaît dans le compteur `Administradores da rede` de `/rede`
- Apparaît dans la liste de l'onglet `/rede` Administradores
- Peut techniquement intervenir sur toutes les biblios (via les helpers d'autorisation), mais cette capacité n'est pas reflétée dans les compteurs « équipe » des biblios

Ce comportement est volontaire et reflète la décision politique : l'administrateur réseau a un pouvoir transverse, mais il n'« occupe » aucune biblio.

### 2.6 Cas limite : une personne avec engagement local **et** admin réseau

Si une personne est `coordenador` de BLMF **et** administratrice réseau (le cas de Xavier après le paquet B) :
- Apparaît dans le compteur `Bibliotecárias·os` de BLMF (au titre de son membership local)
- Apparaît dans le compteur `Administradores da rede` (au titre de son inscription réseau)
- N'apparaît qu'**une fois** dans chaque compteur (pas de double-comptage)
- Apparaît dans la liste équipe BLMF **et** dans la liste admins réseau

Donc dans `/rede` vue d'ensemble, si Xavier est seul admin réseau et coord BLMF, et Patricia est coord BTL : `Administradores = 1`, `Bibliotecas = 2`, et la carte BLMF affiche `Equipe = 1`, la carte BTL aussi.

---

## 3. Architecture cible *(décrite à l'état en prod au 14/05/2026)*

### 3.1 La table `network_administrators`

Créée par le paquet A appliqué le 11/05/2026, enrichie au paquet D du champ de carence (Q5).

```sql
CREATE TABLE public.network_administrators (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
    status text NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'pending_removal', 'removed', 'inactive')),
    coopted_at timestamptz NOT NULL DEFAULT now(),
    coopted_by_unanimity_of uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
    removal_requested_at timestamptz,
    removal_reason text,
    removed_at timestamptz,
    last_seen_at timestamptz,
    pending_collective_removal_until timestamptz,  -- v0.3 : carence 7j retrait collectif (Q5)
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
```

**Notes de conception** :

- **Pas de `library_id`** : c'est le cœur de la séparation.
- **Une seule ligne par personne** : `user_id` est PRIMARY KEY.
- **`status` aligné sur `user_library_memberships`** : les deux tables utilisent désormais le même vocabulaire (`active`, `pending_removal`, `removed`, `inactive`) depuis le paquet 23 qui a élargi le CHECK de la table locale. Cohérence conceptuelle inter-table.
- **`coopted_by_unanimity_of`** : tableau des user_id des votants. Vérifié par trigger.
- **`last_seen_at`** : peut servir pour une logique d'inactivité (sortie auto à 9 mois comme dans la spec gouvernance des rôles locaux).
- **Pas de `is_primary`** : sans rattachement biblio, la notion n'a pas de sens.
- **`pending_collective_removal_until`** : timestamp d'effectivité du retrait collectif après unanimité (carence 7j fixes depuis `unanimous_at`).

### 3.2 Table d'audit

Créée par le paquet A.

```sql
CREATE TABLE public.network_administrator_audit (
    id bigserial PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id),
    event_type text NOT NULL 
        CHECK (event_type IN (
            'cooptation_proposed', 
            'cooptation_voted', 
            'cooptation_completed', 
            'cooptation_rejected',
            'cooptation_expired',
            'self_removal_requested', 
            'removal_requested', 
            'removal_completed', 
            'inactivity_marked',
            'foundational_admin_added'
        )),
    actor_user_id uuid REFERENCES auth.users(id),
    target_user_id uuid REFERENCES auth.users(id),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);
```

Immuabilité garantie par deux triggers `BEFORE UPDATE/DELETE` qui RAISE EXCEPTION.

### 3.3 Tables de propositions et votes

Créées par le paquet A pour les cooptations, complétées au paquet D par les tables symétriques de retrait collectif.

#### 3.3.1 Cooptations

```sql
CREATE TABLE public.network_administrator_cooptation_proposals (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    proposed_user_id uuid NOT NULL REFERENCES auth.users(id),
    proposed_by uuid NOT NULL REFERENCES auth.users(id),
    proposed_at timestamptz NOT NULL DEFAULT now(),
    motivation text NOT NULL,
    status text NOT NULL DEFAULT 'open' 
        CHECK (status IN ('open', 'completed', 'rejected', 'cancelled', 'expired')),
    completed_at timestamptz,
    unanimous_at timestamptz,  -- v0.3 : timestamp d'unanimité atteinte
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '60 days'),  -- v0.3 : 60j (D.6)
    CONSTRAINT motivation_not_too_short CHECK (length(trim(motivation)) >= 50)  -- v0.3 : 50 chars
);

CREATE TABLE public.network_administrator_cooptation_votes (
    proposal_id uuid NOT NULL REFERENCES public.network_administrator_cooptation_proposals(id) ON DELETE CASCADE,
    voter_user_id uuid NOT NULL REFERENCES auth.users(id),
    vote text NOT NULL CHECK (vote IN ('favorable', 'opposed', 'abstain')),
    voted_at timestamptz NOT NULL DEFAULT now(),
    rationale text,
    disclose_identity boolean NOT NULL,  -- v0.3 : choix de divulgation (Q4), pas de DEFAULT
    PRIMARY KEY (proposal_id, voter_user_id),
    CONSTRAINT rationale_required_for_opposed CHECK (
        vote <> 'opposed' OR (rationale IS NOT NULL AND length(trim(rationale)) >= 20)
    )
);
```

**Notes v0.3** :
- `disclose_identity` détermine si le nom du votant est révélé à la personne proposée et au proposeur en cas de rejet (vote `opposed` avec véto). **Pas de DEFAULT** : choix politique conscient imposé à chaque vote, pas de comportement « par accident ».
- La rationale reste affichée même quand `disclose_identity=false` (mais anonymisée : « un·e opposant·e a soulevé : ... »).
- Pour les votes `favorable` et `abstain`, `disclose_identity` n'a pas d'effet en pratique (pas de mail détaillant les votes individuels en cas de succès ou d'abstention).
- **Quorum minimum** : ≥ 3 admins actifs requis pour qu'une cooptation puisse réussir. Xavier étant actuellement seul admin actif, le workflow est dormant en prod.

#### 3.3.2 Retraits collectifs *(structure symétrique, créée au paquet D)*

```sql
CREATE TABLE public.network_admin_collective_removal_proposals (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id uuid NOT NULL REFERENCES auth.users(id),
    proposed_by uuid NOT NULL REFERENCES auth.users(id),
    proposed_at timestamptz NOT NULL DEFAULT now(),
    motivation text NOT NULL,
    status text NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'completed', 'rejected', 'cancelled', 'expired')),
    unanimous_at timestamptz,
    executed_at timestamptz,  -- v0.3.1 : calculé par EF après carence 7j
    cancelled_at timestamptz,
    was_unanimous boolean NOT NULL DEFAULT false,  -- v0.3.1 : flag pour cancelled_handler
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '60 days'),
    CONSTRAINT motivation_not_too_short_removal CHECK (length(trim(motivation)) >= 50)
);

CREATE TABLE public.network_admin_collective_removal_votes (
    proposal_id uuid NOT NULL REFERENCES public.network_admin_collective_removal_proposals(id) ON DELETE CASCADE,
    voter_user_id uuid NOT NULL REFERENCES auth.users(id),
    vote text NOT NULL CHECK (vote IN ('favorable', 'opposed', 'abstain')),
    voted_at timestamptz NOT NULL DEFAULT now(),
    rationale text,
    disclose_identity boolean NOT NULL,
    PRIMARY KEY (proposal_id, voter_user_id),
    CONSTRAINT rationale_required_for_opposed_removal CHECK (
        vote <> 'opposed' OR (rationale IS NOT NULL AND length(trim(rationale)) >= 20)
    )
);
```

Doctrine identique à la cooptation : motivation ≥ 50 chars, rationale opposed ≥ 20 chars, `disclose_identity` sans DEFAULT, unanimité requise. La seule différence sémantique : `was_unanimous` est un flag dédié pour distinguer une annulation avant unanimité (target jamais notifié) d'une annulation post-unanimité (target déjà notifié, doit recevoir le mail de cancellation).

### 3.3bis Vue publique des admins réseau *(v0.3.1, paquet E)*

Créée au paquet E pour servir de source canonique au composant `AdminsPanel`.

```sql
CREATE OR REPLACE VIEW api.network_administrators_public_v1 AS
SELECT
    na.user_id,
    p.public_id,
    p.first_name,
    p.last_name,
    p.email,
    na.coopted_at,
    na.last_seen_at
FROM public.network_administrators na
JOIN public.profiles p ON p.id = na.user_id
WHERE na.status = 'active';

GRANT SELECT ON api.network_administrators_public_v1 TO authenticated;
```

**7 colonnes**, RLS filtre les admins réseau actifs. Pas de `library_id` ni de `role` (transverse). Source canonique de l'`AdminsPanel`.

### 3.4 Nouveaux helpers SQL

Trois helpers centralisent l'autorisation. Toutes les RLS s'appuient sur eux. Créés au paquet A.

#### 3.4.1 `fn_caller_is_network_admin()`

Retourne TRUE si l'appelant courant est un administrateur réseau actif.

```sql
CREATE OR REPLACE FUNCTION public.fn_caller_is_network_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.network_administrators
        WHERE user_id = auth.uid() AND status = 'active'
    );
$$;
```

#### 3.4.2 `user_can_act_as_staff_on_library(p_library_id)`

Retourne TRUE si l'appelant peut agir comme membre du staff sur la biblio donnée. Inclut les administrateurs réseau (droit transverse) et le staff local actif (`librarian` + `coordenador`).

C'est le pilier d'autorisation de la **catégorie A** des RLS (15 policies).

#### 3.4.3 `user_can_engage_library(p_library_id)`

Retourne TRUE si l'appelant peut engager politiquement la biblio (modifications structurelles, règlement, politique de circulation). Inclut administrateurs réseau et coordenadores locaux. Les `librarian` ne peuvent pas engager politiquement.

C'est le pilier d'autorisation de la **catégorie B** des RLS (4 policies).

### 3.5 Modifications de `user_library_memberships`

Le CHECK sur `status` a été élargi par le paquet 23 (11/05) à `('active', 'pending_removal', 'removed', 'inactive')` pour aligner sur `network_administrators`.

Le CHECK sur `role` a été **rétréci** à `('reader', 'librarian', 'coordenador')` au paquet F (13/05/2026). La valeur `'administrador'` n'existe plus dans le schéma.

```sql
-- Appliqué au paquet F le 13/05/2026
ALTER TABLE public.user_library_memberships
    DROP CONSTRAINT user_library_memberships_role_check;

ALTER TABLE public.user_library_memberships
    ADD CONSTRAINT user_library_memberships_role_check 
    CHECK (role IN ('reader', 'librarian', 'coordenador'));
```

---

## 4. Logique de cooptation à l'unanimité *(doctrine notifications raffinée v0.3.1)*

Intégralement implémentée dans les paquets A, D et #114 (mails militants).

### 4.1 Schéma général

```
┌──────────────────────────────────────────────────────────┐
│ 1. Un admin existant propose la cooptation d'une personne │
│    → INSERT dans network_administrator_cooptation_proposals│
│    → status='open', expires_at=NOW()+60j (v0.3)           │
│    → Le proposeur vote automatiquement 'favorable'        │
│    → Mail militant aux autres admins actifs               │
│    → (v0.3.1) Le proposeur N'EST PAS notifié à ce stade   │
└──────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│ 2. Chaque admin actif vote                                │
│    → INSERT dans network_administrator_cooptation_votes    │
│    → vote ∈ {favorable, opposed, abstain}                 │
│    → 'opposed' = veto immédiat (rationale ≥ 20 chars)     │
│    → 'abstain' = ne compte pas dans l'unanimité (bloque)  │
│    → (v0.3.1) Mail à tous les AUTRES admins actifs        │
│    → (v0.3.1) Mail AU PROPOSEUR UNIQUEMENT au 1er vote    │
│              (voteCount===1, signal de démarrage), puis   │
│              silencieux jusqu'au résultat                 │
└──────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│ 3. Trigger vérifie après chaque vote :                    │
│    - SI un vote='opposed' → status='rejected', stop       │
│      → Mail target+proposeur+autres admins                │
│      → (v0.3.1) Rationale opposed diffusé SSI             │
│         disclose_identity=true (cohérent §3.3.1)          │
│    - SI tous les admins actifs ont voté 'favorable'       │
│      → status='completed', unanimous_at=now()             │
│      → INSERT dans network_administrators (status='active')│
│      → Mail à la personne cooptée (target_intro)          │
│      → Mail récap symétrique à tous les admins            │
└──────────────────────────────────────────────────────────┘
```

### 4.2 RPC implémentées

| RPC | Rôle | Paquet | Statut |
|---|---|---|---|
| `fn_network_admin_propose_cooptation(p_user_id, p_motivation)` | Proposer une nouvelle personne | A | ✅ En prod |
| `fn_network_admin_vote_cooptation(p_proposal_id, p_vote, p_rationale, p_disclose_identity)` | Voter | A puis enrichie en D | ✅ En prod (signature finale ci-dessous) |
| `fn_network_admin_self_remove(p_reason)` | Auto-retrait | A | ✅ En prod |
| `fn_network_admin_propose_collective_removal(p_target_user_id, p_motivation)` | Proposer retrait | D | ✅ En prod |
| `fn_network_admin_vote_collective_removal(p_proposal_id, p_vote, p_rationale, p_disclose_identity)` | Voter retrait | D | ✅ En prod |
| `fn_network_notify_event(p_event_type, p_payload jsonb)` | Helper d'INSERT outbox | D.6bis | ✅ En prod |

**Note doctrine D.6bis** : un INSERT par event dans `team_notification_outbox`, fan-out par l'Edge Function `notify-event`. Symétrie avec `fn_team_notify_event` (events `team.*`).

### 4.2.1 Signature finale de `fn_network_admin_vote_cooptation` *(paquet D)*

```sql
CREATE OR REPLACE FUNCTION public.fn_network_admin_vote_cooptation(
    p_proposal_id uuid,
    p_vote text,
    p_rationale text DEFAULT NULL,
    p_disclose_identity boolean  -- v0.3.1 : pas de DEFAULT, choix politique conscient
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth, pg_temp
-- ... gardes-fous : appelant doit être admin actif, proposal en 'open', etc.
-- Garde : rationale obligatoire et ≥ 20 chars pour 'opposed'
IF p_vote = 'opposed' AND (p_rationale IS NULL OR length(trim(p_rationale)) < 20) THEN
    RAISE EXCEPTION 'rationale_required_for_opposed: voting opposed requires a written rationale of at least 20 characters'
        USING ERRCODE = '22023';
END IF;
-- ... reste de la logique : INSERT vote, trigger check_cooptation_completion ...
```

**Note v0.3.1** : `p_disclose_identity` n'a **pas de DEFAULT**. C'est une décision politique consciente prise à chaque vote — ni « toujours révéler par accident », ni « jamais révéler par flemme ». Le frontend doit présenter le choix explicitement.

Cohérent avec la spec gouvernance des rôles (05/05) qui imposait déjà des rationales d'au moins 20 caractères pour les exclusions de membres staff.

### 4.2.2 Workflow complet de retrait collectif *(paquet D)*

`fn_network_admin_propose_collective_removal` et `fn_network_admin_vote_collective_removal` sont des miroirs structurels des fonctions de cooptation, sur les tables `network_admin_collective_removal_*` (cf. §3.3.2).

Doctrine doctrine :

1. Un admin actif propose le retrait d'un autre admin (motivation obligatoire ≥ 50 chars)
2. Une proposition est créée dans `network_admin_collective_removal_proposals`
3. Les autres admins actifs votent (`favorable`, `opposed`, `abstain`)
4. Un vote `opposed` → rejet immédiat
5. Unanimité `favorable` → `unanimous_at = now()` + admin retiré passe en `pending_removal` avec `pending_collective_removal_until = unanimous_at + interval '7 days'`
6. **Cron daily (paquet D)** : tous les admins en `pending_removal` dont `pending_collective_removal_until < now()` → `status='removed'`, `removed_at=now()`. L'Edge Function `notify-event` reçoit l'event `network.collective_removal_executed` et **calcule `executed_at` au moment du traitement** *(raffinement v0.3.1)*.
7. Pendant les 7 jours de carence, l'admin retiré conserve ses droits opérationnels mais reçoit un mail clair sur sa sortie programmée. Il peut éventuellement engager une dernière discussion. Il ne peut pas annuler le retrait unilatéralement (seul le collectif peut décider, à nouveau à l'unanimité).
8. **Annulation pendant la carence** : si le collectif décide d'annuler (`status='cancelled'`), le mail `collective_removal_cancelled` est diffusé. **Le flag `was_unanimous` détermine si le target est notifié** *(raffinement v0.3.1)* :
   - `was_unanimous = false` (annulation avant unanimité) → target jamais notifié de la proposition initiale, donc pas notifié de l'annulation non plus
   - `was_unanimous = true` (annulation post-unanimité) → target déjà notifié de la décision de retrait, doit recevoir le mail d'annulation

### 4.2.3 Système de rappels automatiques *(paquet D.7)*

Mécanisme implémenté au paquet D.7, **inactif en production** tant que le quorum minimum de 3 admins actifs n'est pas atteint.

- Cron daily qui interroge `network_administrator_cooptation_proposals` en `status='open'`
- À **J+14 jours** après `proposed_at` : envoi d'un mail aux admins actifs n'ayant pas encore voté
- À **J+25 jours** (5 jours avant expiration 30j initiaux — note : avec passage à 60j de v0.3, les rappels restent calés sur J+14/J+25 pour cohérence avec la doctrine D.6 originale)
- À **J+expiration** : passage automatique en `status='expired'`

**Raffinement v0.3.1 — `cooptation_reminder` = 2 mails distincts** :

À chaque échéance (J+14 et J+25), deux mails sont émis :
- Aux retardataires n'ayant pas voté : clé `mail.network.cooptation_reminder.intro` — « vous devez voter »
- Au proposeur (signal politique sur l'état de sa proposition) : clé `mail.network.cooptation_reminder.proposer_intro` — « votre proposition s'enlise »

Cette distinction reflète deux situations politiques différentes : le retardataire doit agir, le proposeur doit savoir que son initiative patine.

Pour les propositions de retrait collectif, mêmes échéances J+14 et J+25 par symétrie.

### 4.2.4 Doctrine des notifications du proposeur *(raffinement v0.3.1)*

**Le proposeur d'une cooptation ou d'un retrait collectif est notifié uniquement au premier vote intermédiaire**, puis reste silencieux jusqu'au résultat (unanimité, rejet, ou expiration). Cette doctrine vaut aussi bien pour `cooptation_voted` que pour `collective_removal_vote_cast`.

**Justification politique** : éviter le flot continu de mails au proposeur sur chaque vote intermédiaire (potentiellement N-1 mails par proposition). Le 1er vote suffit comme signal politique de démarrage de la délibération. Les rappels J+14/J+25 prennent ensuite le relais si la proposition stagne. Le résultat final déclenche un mail dédié (`cooptation_completed`, `cooptation_rejected`, `cooptation_expired`).

**Implémentation** : détection via `voteCount === 1` au moment du fan-out dans `notify-event`, sur les tables `network_administrator_cooptation_votes` et `network_admin_collective_removal_votes`. Validé en prod EF #114.A (cooptation_voted) et #114.B-3b (collective_removal_vote_cast).

### 4.3 Cas particulier : premier administrateur

Le système suppose au moins un administrateur réseau pour qu'il y ait cooptation. Le **premier administrateur** ne peut pas être coopté (il n'y a personne pour voter). Solution appliquée au paquet B :

- INSERT manuel d'une ligne fondatrice dans `network_administrators` pour **Xavier** avec `coopted_by_unanimity_of = ARRAY[]::uuid[]` (vide) et `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`.
- Cette manipulation est tracée dans `network_administrator_audit` avec `event_type='foundational_admin_added'` et `metadata.foundational=true`.
- Une fois ce socle posé, toute cooptation ultérieure passe par le workflow normal.

### 4.4 Retrait

**Auto-retrait** (`fn_network_admin_self_remove`) : un administrateur réseau peut quitter ses fonctions à tout moment, sans l'accord des autres. C'est un acte unilatéral. Garde-fou : s'il est le dernier admin actif, transition en `pending_removal` avec carence de 30 jours pendant lesquels il peut revenir (workflow d'urgence à spécifier en cas de besoin).

**Retrait collectif** (`fn_network_admin_propose_collective_removal` + vote) : workflow miroir de la cooptation, livré au paquet D, mails militants livrés par #114.B.

### 4.5 Liste des events `network.*` implémentés *(paquet D + #114)*

Dix events transitent par `team_notification_outbox` et sont routés par `notify-event` vers les handlers correspondants :

**Cooptation (5 events)** :
- `network.cooptation_proposed` — destinataires : autres admins actifs
- `network.cooptation_voted` — destinataires : autres admins actifs (qui n'ont pas encore voté) + proposeur **uniquement au 1er vote**
- `network.cooptation_rejected` — destinataires : target + proposeur + autres admins (avec rationale opposed si `disclose_identity=true`)
- `network.cooptation_completed` — destinataires : target + tous admins (symétrique avec `target_intro` côté target)
- `network.cooptation_reminder` — destinataires : retardataires (`.intro`) + proposeur (`.proposer_intro`) à J+14 et J+25

**Retrait collectif (5 events)** :
- `network.collective_removal_proposed` — destinataires : autres admins actifs (target non notifié à ce stade)
- `network.collective_removal_vote_cast` — destinataires : autres admins actifs + proposeur **uniquement au 1er vote**
- `network.collective_removal_unanimous` — destinataires : target + tous admins (déclenche carence 7j)
- `network.collective_removal_cancelled` — destinataires : tous admins + target **uniquement si `was_unanimous=true`**
- `network.collective_removal_executed` — destinataires : tous admins ex-membres + target ; **`executed_at` calculé par l'EF** au moment du traitement (post-carence)

Toutes ces clés i18n existent dans `_shared/i18n/mail-strings.ts` × 6 locales (pt-BR, fr, es, en, it, de) depuis E.1bis.

### 4.6 Cosmétique du `vote_cast` *(v0.3.1)*

Si une proposition de retrait collectif est supprimée alors qu'un mail `collective_removal_vote_cast` est en cours d'émission, le mail affiche **« ? »** à la place du nom de la cible (placeholder hotfix #114.B-3c). Pas un défaut bloquant, simplement une imperfection cosmétique liée au timing du fan-out.

---

## 5. Mapping des modifications nécessaires *(toutes appliquées)*

### 5.1 Fonctions remplacées (table de correspondance)

| Fonction d'origine | Action effective | Date |
|---|---|---|
| `fn_caller_is_administrador()` | DÉPRÉCIÉE puis SUPPRIMÉE au paquet F | 13/05/2026 |
| `user_has_library_staff_role(uuid, uuid)` | Refactorée pour interroger aussi `network_administrators` | Paquet C |
| `user_can_manage_library(uuid)` | Refactorée comme wrapper de `user_can_engage_library` | Paquet C |
| `can_manage_document_requests_for_library(uuid)` | Audit + refacto sur helpers | Paquet C |
| `can_manage_library_circulation_policies(uuid)` | Idem | Paquet C |
| `can_manage_library_contact_profile(uuid)` | Idem | Paquet C |
| `can_manage_library_document_governance(uuid)` | Idem | Paquet C |
| `can_manage_library_regulation_documents(uuid)` | Idem | Paquet C |
| `user_can_manage_library_notifications(uuid)` | Idem | Paquet C |
| `circulation_reader_scope(uuid, uuid)` | Audité, pas impacté | Paquet C |
| `fn_check_loan_action(text, text, text)` | Audité, OK (param `actor_role` passé en argument) | Paquet C |
| `fn_resolve_caller_role_for_library(uuid)` | Modifiée pour retourner `'network_admin'` virtuel | Paquet B |
| `fn_record_membership_payment(...)` | Audit + refacto | Paquet C |
| `fn_set_retention_policy(...)` | Idem | Paquet C |
| `fn_team_list_memberships(text, uuid)` | Refactorée sur `fn_caller_is_network_admin` | Paquet D.8 |
| `fn_team_promote_to_administrador(uuid, uuid)` | DÉPRÉCIÉE puis SUPPRIMÉE | Paquet D.8 puis F |
| `fn_team_request_remove_member(uuid, uuid, text, text)` | Refusée sur admins réseau (passer par RPC dédiées) | Paquet C |
| `fn_team_self_demote(uuid, text, text)` | Idem + suppression branche A « last admin lockdown » | Paquet F |
| `fn_team_suspend_member(uuid, uuid, text, text)` | Idem | Paquet F |
| `api.cancel_reservation_as_library(...)` | Audit + checks internes alignés | Paquet C |

### 5.2 Vues modifiées

| Vue | Modification | Statut |
|---|---|---|
| `api.library_circulation_stats` | Paquet 22 : suppression du WHERE EXISTS. Paquet 23 : COUNT(DISTINCT user_id). Paquet F : retrait définitif de `'administrador'` du ARRAY de `librarians_active`. | ✅ Livré |
| `api.my_access` | Consolide `network_administrators` ET `user_library_memberships` pour `can_access_painel` et `can_access_catalogacao`. | ✅ Livré paquet B |

### 5.3 Nouvelles vues créées

| Vue | Rôle | Paquet |
|---|---|---|
| `api.network_administrators_public_v1` | Liste publique-réseau des admins réseau actifs (7 colonnes) | A (initial), enrichie E |
| `api.my_network_admin_status` | Statut admin réseau de l'appelant courant | A |
| `api.network_overview` | Indicateurs globaux du réseau (compteurs réseau pour `/rede`) | B |
| `api.collective_removal_overview` | Liste des propositions de retrait collectif en cours, pour AdminsPanel | E.4.c |

#### Spécification de `api.network_overview`

```sql
CREATE OR REPLACE VIEW api.network_overview AS
SELECT
    (SELECT count(*) FROM public.network_administrators WHERE status = 'active') AS network_admins_active,
    (SELECT count(*) FROM public.network_administrator_cooptation_proposals WHERE status = 'open') AS open_proposals,
    (SELECT count(*) FROM public.libraries WHERE is_active = true) AS libraries_active,
    (SELECT count(*) FROM public.books) AS books_total,
    (SELECT count(*) FROM public.authors) AS authors_total,
    (SELECT count(*) FROM public.exemplares) AS exemplars_total,
    (SELECT coalesce(sum(loans_open), 0) FROM api.library_circulation_stats) AS loans_open_total,
    (SELECT coalesce(sum(loans_overdue), 0) FROM api.library_circulation_stats) AS loans_overdue_total,
    (SELECT coalesce(sum(reservations_active), 0) FROM api.library_circulation_stats) AS reservations_active_total;
```

Volontairement minimaliste. Pas de compteur « équipe réseau ».

### 5.4 RLS modifiées

47 policies au total alignées sur le nouveau modèle au paquet C (sur les 22 initialement recensées, le nombre a augmenté en cours d'audit avec la prise en compte du chantier linter Supabase 12/05).

**Catégorie A — « staff local + admin réseau » (15 policies)** : bascule sur `user_can_act_as_staff_on_library(library_id)`.

Tables : `author_translations`, `libraries`, `library_retention_policies` (×2), `library_service_state` (×3), `painel_internal_tasks` (×4), `painel_internal_task_invites`, `painel_internal_task_invitation_outbox`, `painel_internal_task_notification_outbox`, `storage.objects` (privacy ×3).

**Catégorie B — « engagement politique de la biblio » (4 policies)** : bascule sur `user_can_engage_library(library_id)`.

Tables : `library_membership_rules`, `library_retention_policies` (modify), `membership_payments` (×2).

**Catégorie C — « administrateur réseau pur » (1 policy)** : `ulm_select_all_for_administrador` basculée sur `fn_caller_is_network_admin()`.

**Catégorie D — actions transverses (audit)** : 2 nouvelles policies créées sur `network_admin_cross_library_actions_log` (table immutable, INSERT only) au paquet C.5.

---

## 6. Plan d'implémentation par paquets *(tous livrés en prod au 14/05/2026)*

### 6.1 Paquet A — Infrastructure DB ✅ Livré 11/05/2026

Contenu livré :
- 4 tables (`network_administrators`, audit, proposals, votes)
- 3 helpers (`fn_caller_is_network_admin`, `user_can_act_as_staff_on_library`, `user_can_engage_library`)
- 4 RPC initiales (propose, vote, self_remove, request_removal en stub)
- 1 trigger de complétion automatique des cooptations
- 2 vues initiales (`api.network_administrators_public_v1`, `api.my_network_admin_status`)
- 4 policies RLS sur les nouvelles tables
- Audit immuable garanti par triggers `BEFORE UPDATE/DELETE`

**Impact prod confirmé** : aucun. Toutes les RLS, fonctions et vues existantes intactes.

### 6.2 Paquet B — Migration fondatrice + `api.my_access` + `api.network_overview` ✅ Livré 11/05/2026

Contenu livré :

1. **INSERT manuel** de la ligne fondatrice de Xavier dans `network_administrators` avec event `foundational_admin_added`.
2. **Réécriture de `api.my_access`** pour consolider les deux sources de droits (`can_access_painel` et `can_access_catalogacao` couvrent maintenant les admins réseau).
3. **Création de `api.network_overview`** (compteurs réseau).
4. **Modification de `fn_resolve_caller_role_for_library`** pour retourner `'network_admin'` virtuel.

### 6.3 Paquet C — Bascule progressive des RLS ✅ Livré 11/05/2026

9 sous-paquets (C.1 à C.5c-bis) livrés en une session intensive le 11/05. 47 RLS alignées.

- **C.1** — `painel_internal_tasks` + outbox (4 policies)
- **C.2** — `library_service_state` (3 policies), `libraries` (1 policy)
- **C.3** — `library_retention_policies` (2 policies), `library_membership_rules` (1 policy), `membership_payments` (2 policies)
- **C.4** — `storage.objects` (3 policies) — hotfix C.4bis pour les sous-requêtes corrélées (qualifier `storage.objects.name`)
- **C.5** — `user_library_memberships` (2 policies) + création de `network_admin_cross_library_actions_log` + helpers de logging + trigger event critique + job pg_cron digest hebdomadaire (inactif jusqu'à #78 + secret vault) — sous-paquets C.5a/b/c-bis pour les ajustements doctrinaux.

#### 6.3.1 Spécification de `network_admin_cross_library_actions_log`

Table d'audit dédiée aux actions transverses des admins réseau, créée au paquet C.5.

```sql
CREATE TABLE public.network_admin_cross_library_actions_log (
    id bigserial PRIMARY KEY,
    actor_user_id uuid NOT NULL REFERENCES auth.users(id),
    library_id uuid NOT NULL REFERENCES public.libraries(id),
    action_type text NOT NULL,
    is_critical boolean NOT NULL DEFAULT false,
    target_entity_type text,
    target_entity_id uuid,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.network_admin_cross_library_actions_log IS 
'Journal des actions effectuées par un administrateur réseau sur une bibliothèque dont il n''est pas staff local. Garantit la transparence politique des interventions transverses. INSERT only, immuable.';
```

**Liste limitative des actions critiques** *(v0.3, Q6)* :
- Modification de `libraries` (slug, name, identité)
- Modification de `library_membership_rules`
- Modification de `library_retention_policies`
- Modification de `library_service_state`
- Appel à `fn_team_suspend_member`
- Appel à `fn_team_request_remove_member`
- Modification de `library_circulation_policies`

**Actions routinières** — digest hebdomadaire seulement :
- Consultations de données (SELECT)
- Création/modification d'emprunts, réservations, consultations sur place, retours
- Génération de rapports
- Toute autre action non listée comme critique

**Mécanisme de notification** :
- Pattern `PERFORM fn_log_cross_library_action` après audit local et avant notification mail dans les RPC team. NOOP automatique si non-transverse (l'actor est staff local).
- Si action critique → INSERT dans outbox d'event `network.cross_library_critical_action` → mail immédiat aux coordenadores actifs de la biblio
- Cron hebdomadaire dimanche minuit (job inactif tant que #78 + secret vault non livrés) : agrège toutes les actions transverses de la semaine par biblio et envoie un digest aux coordenadores actifs

### 6.4 Paquet D — Refactorisation RPC + workflow retrait complet ✅ Livré 13/05/2026

8 sous-paquets (D.1 à D.8) :
- **D.1 à D.5** : tables `network_admin_collective_removal_*`, RPC `fn_network_admin_propose_collective_removal` + `fn_network_admin_vote_collective_removal`, trigger d'unanimité, etc.
- **D.6 (doctrine v0.3 §Q5 figée)** : tables proposals+votes symétriques, carence absolue 7j depuis `unanimous_at`, motivation ≥ 50 chars, rationale opposed ≥ 20 chars, expiration 60j
- **D.6bis** : `fn_network_notify_event` + correction outbox (un INSERT par event)
- **D.7** : rappels cooptation J+14/J+25 via event `network.cooptation_reminder` (job inactif tant que quorum minimum non atteint)
- **D.8** : refacto `fn_team_list_memberships` sur `fn_caller_is_network_admin` + dépréciations `fn_caller_is_administrador` + `fn_team_promote_to_administrador`

### 6.5 Paquet E — UI ✅ Livré 13/05/2026

10/10 sous-paquets livrés :
- **E.1** — i18n 6 events D.6/D.7 (clés `mail.network.*`)
- **E.1bis** — Notifications cooptation 4 events DB + i18n × 6 locales
- **E.5** — `api.library_circulation_stats` sans `administrador` (retrait du ARRAY)
- **E.2** — i18n frontend 55 clés × 6 locales (additif rede.admins.*)
- **E.3** — `LibraryContext` enrichi (`isNetworkAdmin`, `effectiveRole`, `hasStaffAccess`) + `NetworkAdminBadge`
- **E.4.a** — `AdminsPanel` v0.3 (consommation de `api.network_administrators_public_v1`)
- **E.4.b** — `ProposeCooptationModal` + `VoteCooptationModal` + section Propositions en cours, RPC D.5
- **E.4.c** — 3 modals retrait collectif Propose/Vote/Cancel sur RPC D.6 + vue `api.collective_removal_overview`
- **E.4.d** — cleanup 30 clés i18n `rede.admins.*` obsolètes × 6 locales

Test fonctionnel de cooptation Patricia bout-en-bout réussi puis nettoyé.

### 6.6 Paquet F — Phase finale ✅ Livré 13/05/2026

4 sous-paquets livrés :
- **F.1** — DELETE ligne `ulm` Xavier administrador BLMF + ALTER CHECK `user_library_memberships.role` retrait de `'administrador'` + ALTER vue `api.my_access` + ALTER 2 RLS policies dépendantes
- **F.2.bis** — Refacto de 14 fonctions mécaniques (Type A/B/C) : retrait `administrador` des ARRAYs, IN transformés en égalités sur `coordenador` (la F.2 initiale était buggée — DO block matchait les commentaires SQL contenant `administrador`)
- **F.3** — Refacto 3 fonctions politiques : `fn_team_request_remove_member`, `fn_team_self_demote` (suppression de la branche A « last admin lockdown » + phrase rituelle), `fn_team_suspend_member`. Suppression côté frontend du wrapper `quitAdminFunctions` / `promoteToAdministrador` + case `quit_admin_functions` dans `TeamActionModal`.
- **F.4 v2 hotfix doctrine `roles.js`** — Suppression `isAdmin()` et `canManageNetworkTeam()`. **Refonte `canSeeRede` pour prendre `isNetworkAdmin` booléen** au lieu de `role` (la F.4 v1 avait cassé le build en supprimant statusBadgeKind et availableTeamActions par audit incomplet — rollback puis v2 corrigée). Patch chirurgical `layout/index.jsx` pour récupérer `isNetworkAdmin` du `LibraryContext` et l'utiliser pour `canSeeRede`.

Test fonctionnel post-déploiement : lien Rede visible dans header pour Xavier, `AdminsPanel` affiche admin + sections cooptation et retrait collectif fonctionnelles.

### 6.7 Chantier #114 — Mails militants ✅ Livré 14/05/2026

Le paquet D a livré la mécanique DB des events `network.*` (`fn_network_notify_event`, INSERT outbox), mais l'Edge Function `notify-event` ne savait pas les router. Conséquence empirique : test cooptation Patricia 13/05 avait généré tous les events DB mais 0 mail militant.

#114 a livré 10 sous-handlers `network.*` dans l'EF `notify-event` :
- **#114.A** (commit 8e60718) — `cooptation_proposed`, `cooptation_voted`
- **#114.B-3a** — `cooptation_rejected`, `cooptation_completed`, `cooptation_reminder`
- **#114.B-3b** — `collective_removal_proposed`, `collective_removal_vote_cast`, `collective_removal_unanimous`, `collective_removal_cancelled`, `collective_removal_executed`
- **#114.B-3c** — hotfix placeholder `?` pour vote_cast quand proposition supprimée

Test fumée Niveau A passé sur les 10 events. Spec v0.3.1 (ce document) consigne les doctrines de notification raffinées en cours d'implémentation : proposeur notifié au 1er vote uniquement, rationale diffusée si `disclose_identity=true`, reminder = 2 mails distincts, cancelled selon `was_unanimous`, `executed_at` calculé par EF.

---

## 7. Implications UI détaillées *(décrites à l'état en prod après paquet E)*

### 7.1 `LibraryContext`

Le `LibraryContext` expose désormais :

- `isNetworkAdmin: boolean` — l'utilisateur est-il administrateur réseau actif ?
- `effectiveRole: 'reader' | 'librarian' | 'coordenador' | 'network_admin' | null` — rôle effectif. `network_admin` prime sur le rôle local pour les autorisations transverses. Ajoute `'network_admin'` à la hiérarchie `ROLE_RANK`.
- `hasStaffAccess: boolean` — calculé via `STAFF_ROLES` (set des rôles staff).
- `hasEngagementAccess: boolean` — calculé via `user_can_engage_library`.

L'ancien champ `role` est conservé pour compatibilité. Les nouveaux composants utilisent les nouveaux champs.

### 7.2 Badges et étiquettes

- `<LocalRoleBadge>` pour le rôle dans la biblio courante (Leitor·a·e / Bibliotecária·o / Coordenadora·or)
- `<NetworkAdminBadge>` pour le statut administrateur réseau (prop `compact`, classe CSS `cat-pill info`)

Les deux peuvent s'afficher en même temps (ex. dans le cas de Xavier : « Coordenador BLMF » + « Admin AnarBib »).

### 7.3 /rede onglet « Vue d'ensemble »

Bandeau alimenté par `api.network_overview` :
- « ADMINISTRADORES » (nombre d'admins réseau actifs)
- « BIBLIOTECAS » (nombre de biblios actives)
- « DOCUMENTOS », « AUTORIDADES », « EXEMPLARES » (catalogue agrégé)
- « EMPRÉSTIMOS ABERTOS », « RESERVAS ATIVAS », « EM ATRASO » (circulation agrégée)
- Pas de compteur « EQUIPE » global, pas de compteur « LEITORES » global.

### 7.4 /rede onglet « Bibliotecas »

Chaque ligne avec ses compteurs locaux (Leitores, Equipe, Exemplares, Empréstimos, etc.), consommés depuis `api.library_circulation_stats`. La sémantique v0.2 garantit que `librarians_active` ne compte plus que `librarian + coordenador`, aucune mention `administrador` (rôle supprimé au paquet F).

### 7.5 /rede onglet « Administradores »

`AdminsPanel` :
- Liste des administrateurs réseau actifs (consommation de `api.network_administrators_public_v1` à 7 colonnes)
- Bouton « Propor cooptação » → `ProposeCooptationModal` avec email + motivation (≥ 50 chars) → appel `fn_network_admin_propose_cooptation`
- Section « Propostas em curso » : liste des proposals en `status='open'` avec `VoteCooptationModal` (favorable/contre/abstention + rationale ≥ 20 chars si contre + choix `disclose_identity`)
- Section « Retraits collectifs en cours » : alimentée par `api.collective_removal_overview` avec les 3 modals dédiés (Propose/Vote/Cancel)
- Section « Histórico » : consommation de `network_administrator_audit`

### 7.6 /biblioteca onglet « Equipe »

Le `TeamPanel scope="library"` reste centré sur les memberships locaux (`librarian`, `coordenador`). Les administrateurs réseau ne sont pas listés ici, sauf s'ils ont aussi un membership staff local sur cette biblio.

Pour Xavier : il apparaît dans `/biblioteca/blmf` onglet Equipe au titre de son `coordenador`. Son statut admin réseau est affiché par un `<NetworkAdminBadge>` supplémentaire, pas par une ligne supplémentaire.

### 7.7 Notifications mail militantes

10 events `network.*` internationalisés × 6 locales (cf. §4.5). Tonalité militante stricte (École 1) avec point médian inclusif pour fr, triple o/a/e pour pt-BR, e neutre pour es, Genderstern pour de.

---

## 8. Risques et contre-mesures *(évaluation post-implémentation)*

### 8.1 Risque : perte d'accès accidentelle pendant la bascule

**Constat post-implémentation** : aucun incident en prod pendant la bascule. Le double mécanisme (coexistence entre paquet B et paquet F) a fonctionné comme prévu. Les RLS basculées s'appuyaient sur les helpers qui interrogeaient `network_administrators` ; les RLS non encore basculées continuaient à fonctionner avec l'ancien rôle. Pas de fenêtre de perte d'accès observée.

### 8.2 Risque : duplication de logique pendant la coexistence

**Constat post-implémentation** : la coexistence a duré du paquet B (11/05) au paquet F (13/05). Aucune incohérence remontée. La ligne `administrador` de Xavier dans `user_library_memberships` a été supprimée au paquet F sans complication.

### 8.3 Risque : la cooptation à l'unanimité bloque le réseau

**Statut** : risque résiduel actif. Xavier est actuellement seul admin réseau actif, donc le workflow de cooptation reste **dormant** en pratique. Quorum minimum de 3 admins requis pour une vraie unanimité. Le cron `pg_cron` de marquage d'inactivité à 6 mois est en place.

### 8.4 Risque : perte du dernier administrateur

**Contre-mesure en place** : `fn_network_admin_self_remove` détecte ce cas et passe l'admin en `status='pending_removal'` avec une carence de 30 jours. Workflow de récupération de réseau (cooptation amorcée par les coordenadores des biblios actives) reste à spécifier dans une spec ultérieure (non urgente tant qu'un seul admin réseau).

### 8.5 Risque : abus de l'administrateur réseau

**Contre-mesure livrée** : `network_admin_cross_library_actions_log` créée au paquet C.5. Toutes les actions des administrateurs réseau sur des biblios où ils ne sont pas staff local sont auditées dans cette table. Les actions critiques (modifications de règlement, suspensions, etc.) déclenchent un mail immédiat ; les actions routinières remonteront dans un digest hebdomadaire dès activation du cron (item #78 + secret vault).

### 8.6 Risque : incohérence de compteurs pendant la coexistence

**Constat post-implémentation** : le passage simultané DB+UI au paquet E + retrait `administrador` au paquet F ont évité toute fenêtre incohérente visible par l'utilisateur.

### 8.7 *(Nouveau v0.3.1)* Risque : doctrines de notification en mauvaise position

**Constat post-implémentation** : les raffinements (proposeur 1er vote, rationale conditionné, reminder dual, cancelled conditionné, `executed_at` EF) ont été figés en cours d'implémentation. Sans cette spec v0.3.1, ils restent uniquement dans le code et la mémoire d'équipe. Inscription dans la spec fait foi.

---

## 9. Cas particulier : situation de Xavier — résolue au paquet F

État initial des memberships de Xavier dans `user_library_memberships` (avant paquet F) :

| role | library_id | status | is_primary | created_at |
|---|---|---|---|---|
| administrador | BLMF | active | true | 2026-03-24 |
| coordenador | BLMF | active | false | 2026-05-11 (paquet 23bis) |

**État final** après paquet F (13/05/2026) :

| Table | Ligne |
|---|---|
| `user_library_memberships` | `coordenador` BLMF, status='active', is_primary=true |
| `network_administrators` | Xavier, status='active', cooptation fondatrice |

L'ancienne ligne `administrador` BLMF a été supprimée par DELETE explicite au paquet F.1, et le CHECK constraint a été rétréci en même temps.

---

## 10. Calendrier prévisionnel → calendrier réel

| Paquet | Durée estimée v0.3 | Statut réel |
|---|---|---|
| A — Infrastructure | 1 session intensive | ✅ Livré 11/05/2026 |
| B — Migration Xavier + my_access + network_overview | 1-2 sessions | ✅ Livré 11/05/2026 |
| C — Bascule RLS (C.1 à C.5c-bis) | 3-5 sessions sur 2-4 semaines | ✅ Livré 11/05/2026 en 1 session intensive |
| D — Refactorisation RPC + workflow retrait | 1-2 sessions | ✅ Livré 13/05/2026 (8 sous-paquets) |
| E — UI | 2-3 sessions | ✅ Livré 13/05/2026 (10 sous-paquets) |
| F — Phase finale | 1 session | ✅ Livré 13/05/2026 (4 sous-paquets incl. F.4 v2 hotfix) |
| **#114 — Mails militants** | non chiffré v0.3 | ✅ Livré 14/05/2026 (10 sous-handlers) |

**Bilan** : chantier admin réseau entièrement livré en 4 jours calendaires (11/05 → 14/05), soit beaucoup plus rapide que les 4-8 semaines prévues en v0.1. Cela tient à la décision de fusionner les sessions et à l'absence d'incident bloquant sur la bascule des RLS.

---

## 11. Décisions tranchées

### 11.1 Décisions politiques (Q1-Q8, v0.2 et v0.3)

**Q1 (tranchée v0.2)** : ~~Les administrateurs réseau peuvent-ils être membres staff de plusieurs biblios à la fois ?~~ → **Oui, c'est légitime politiquement. La sémantique « page = périmètre » garantit qu'aucun compteur ne le pénalise.**

**Q2 (tranchée v0.3)** : ~~Doit-on créer une table `network_admin_cross_library_actions_log` au paquet C.5 ?~~ → **Oui, table créée au paquet C.5. Traçabilité politique maximale des actions transverses.**

**Q3 (tranchée v0.3)** : ~~Quel délai d'expiration pour les propositions de cooptation ?~~ → **60 jours en v0.3 (passage de 30 à 60 lors de l'implémentation D.6), avec rappels automatiques à J+14 et J+25.**

**Q4 (tranchée v0.3)** : ~~Anonymat ou transparence des opposants en cas de rejet ?~~ → **Choix de chaque opposant (champ `disclose_identity`) + rationale obligatoire pour les votes `opposed`.** *(Raffinement v0.3.1 : pas de DEFAULT sur `disclose_identity`, choix politique conscient à chaque vote.)*

**Q5 (tranchée v0.3)** : ~~Carence avant retrait définitif (retrait collectif) ?~~ → **7 jours de carence fixes** (`pending_collective_removal_until = unanimous_at + interval '7 days'`). L'auto-retrait reste immédiat sauf cas du dernier admin (30 jours).

**Q6 (tranchée v0.3)** : ~~Notifications du staff local sur actions transverses ?~~ → **Digest hebdomadaire par défaut + mail immédiat pour actions critiques.** Liste limitative des actions critiques (modifications de règlement, suspensions, etc.).

**Q7 (tranchée v0.3)** : ~~Retrait précoce de la ligne `administrador` BLMF de Xavier dès le paquet B ?~~ → **Non, attendre le paquet F.** Confirmé : la ligne a été supprimée au paquet F.1 sans incident.

**Q8 (tranchée v0.3)** : ~~Fusion paquets B+C+F en un seul « grand bond » ?~~ → **Non, séquence v0.1 conservatrice maintenue.** Confirmé : la séquence par paliers a permis une bascule sans incident.

### 11.2 *(Nouveau v0.3.1)* Raffinements doctrinaux de notification

Les doctrines suivantes ont été figées en cours d'implémentation des paquets D-F et du chantier #114, et sont consignées ici :

**R1 — Notification du proposeur au 1er vote uniquement** (cf. §4.2.4) : le proposeur est notifié uniquement au premier vote intermédiaire d'une proposition (cooptation ou retrait collectif), puis silencieux jusqu'au résultat. Validé en prod EF #114.A et #114.B-3b.

**R2 — Rationale opposed diffusé conditionnellement** : dans le mail `cooptation_rejected`, la rationale de l'opposant n'est diffusée que si `disclose_identity=true`. Si `false`, le mail mentionne uniquement « un·e opposant·e a soulevé : » suivi du texte de la rationale sans nom (anonymisation partielle, le texte reste visible mais pas l'identité). Patch DB 9d3ae6b enrichit `trg_check_cooptation_completion`.

**R3 — `cooptation_reminder` = 2 mails distincts** (cf. §4.2.3) : aux retardataires (`.intro`) et au proposeur (`.proposer_intro`) en J+14/J+25.

**R4 — `collective_removal_cancelled` selon `was_unanimous`** (cf. §4.2.2 point 8) : le target est notifié de l'annulation **uniquement si** `was_unanimous=true` (annulation post-unanimité, le target avait déjà été notifié de la décision). Si annulation avant unanimité, target jamais impliqué.

**R5 — `executed_at` calculé par EF** (cf. §4.2.2 point 6) : pour `collective_removal_executed`, le timestamp d'exécution est calculé par l'Edge Function `notify-event` au moment du traitement de l'event, pas par un trigger DB. Cela permet de capturer le moment réel d'envoi du mail post-carence, pas le moment d'éligibilité théorique.

**R6 — `disclose_identity` sans DEFAULT** : ni dans les tables `network_administrator_cooptation_votes` ni dans `network_admin_collective_removal_votes`. Choix politique conscient imposé à chaque vote.

**R7 — Cosmétique `vote_cast` avec proposition supprimée** : placeholder `?` à la place du nom de la cible si proposition supprimée pendant le fan-out (hotfix #114.B-3c). Imperfection cosmétique tolérée.

### 11.3 Décisions résiduelles ouvertes

Aucune décision politique majeure n'est ouverte. La spec est complète et entièrement implémentée.

Quelques **détails à implémenter** restent :

- **Q9 (mineure)** : faut-il un champ `restrictive` pour les actions transverses ? → toujours ouvert, à trancher si besoin
- **Q10 (mineure)** : faut-il une notification au staff local lors de l'**ajout** d'un nouvel admin réseau, pour qu'iels sachent qui peut intervenir ? → à trancher quand un 2e admin réseau sera coopté
- **Item backlog #78 + #79** : activation du cron digest hebdomadaire + création du secret vault `WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST`. Job dormant en attendant.

---

## 12. Annexes

### 12.1 Glossaire

- **Administrateur réseau** (alias *network admin*, *administrador AnarBib*) : personne membre du réseau de coordination AnarBib, avec autorité transverse sur toutes les biblios.
- **Staff local** : ensemble des `librarian` + `coordenador` actifs d'une biblio donnée.
- **Cooptation** : processus d'ajout d'une nouvelle personne au réseau d'administrateurs, à l'unanimité des administrateurs en place.
- **Engagement politique** : capacité de modifier les paramètres structurels d'une biblio (règlement, politique de circulation, identité). Réservé aux `coordenador` et aux administrateurs réseau.
- **Intervention opérationnelle** : capacité de réaliser des actions quotidiennes (prêt, retour, réservation au nom d'un lecteur). Réservé au staff local et aux administrateurs réseau.
- **Périmètre** *(v0.2)* : ensemble des engagements politiquement situés sur un même objet (une biblio, ou le réseau). Sert de cadre pour la sémantique des compteurs.
- **Quorum minimum** : ≥ 3 admins réseau actifs requis pour qu'une cooptation puisse réussir. Tant que ce seuil n'est pas atteint, le workflow est dormant en pratique.

### 12.2 Références implémentation

- Paquets A, B : commits 11/05/2026
- Paquets C, C.1 à C.5c-bis : commits 11/05/2026
- Paquets D.1 à D.8 : commits 13/05/2026
- Paquets E.1, E.1bis, E.2, E.3, E.4.a, E.4.b, E.4.c, E.4.d, E.5 : commits 13/05/2026
- Paquets F.1, F.2.bis, F.3, F.4 v2 : commits 13/05/2026 (incident F.2 et F.4 v1 → hotfix v2)
- Paquet 22 : commit 11/05/2026 (api.library_circulation_stats fix WHERE EXISTS)
- Paquet 23, 23bis : commits 11/05/2026 (CHECK élargi + ligne coordenador BLMF Xavier)
- Chantier #114 (commits #114.A 8e60718, #114.B-3a, #114.B-3b, #114.B-3c) : 14/05/2026

### 12.3 Références internes

- `docs/specs/spec-gouvernance-roles.md` v1.0 (05/05/2026) : sémantique des rôles locaux, transitions de status. À mettre à jour en v1.1 pour aligner sur le retrait du rôle `administrador` local (cf. Plan d'action 15/05).
- `docs/specs/spec-profils-bibliotheque.md` v0.3 (13/05/2026) : doctrine des 4 axes orthogonaux. La spec admin réseau v0.3.1 est compatible : `governance_mode = full_governance` active le workflow décrit ici, les autres modes simplifient.
- Migration `2026_05_05_user_can_manage_library_remove_phantom_roles.sql` : nettoyage des rôles fantômes du 5/05 sur lequel ce chantier s'appuie.

### 12.4 Changelog v0.1 → v0.2

**Sections ajoutées** :
- §2 Sémantique des compteurs (nouvelle section centrale, ~150 lignes)
- §5.3 Spécification de `api.network_overview`
- §6.7 Question d'accélération
- §7.3 Application sémantique v0.2 au bandeau /rede
- §8.6 Risque d'incohérence de compteurs pendant la coexistence
- §11 Q7 et Q8 (nouvelles décisions ouvertes)

**Sections mises à jour** :
- §6.1 (paquet A marqué livré)
- §6.2 (paquet B enrichi)
- §6.5 (paquet E enrichi)
- §9 (situation Xavier documentée)
- §10 (calendrier ajusté)
- §11 (Q1 tranchée, Q7-Q8 ajoutées)

### 12.5 Changelog v0.2 → v0.3

**Décisions tranchées** : Q2, Q3, Q4, Q5, Q6, Q7, Q8.

**Sections ajoutées** :
- §4.2.1 Évolutions de `fn_network_admin_vote_cooptation` au paquet D (Q4)
- §4.2.2 Workflow complet de retrait collectif au paquet D (Q5)
- §4.2.3 Système de rappels automatiques (Q3)
- §6.3.1 Spécification de `network_admin_cross_library_actions_log` (Q2 + Q6)
- §11.1 Décisions résiduelles ouvertes

**Sections mises à jour** :
- §3.1 (ajout colonne `pending_collective_removal_until`, Q5)
- §3.3 (ajout colonne `disclose_identity`, Q4)
- §4.2 (tableau RPC marqué « à enrichir au paquet D »)
- §6.3 (paquet C.5 enrichi avec `cross_library_actions_log`)
- §8.5 (contre-mesure abus admin réseau pointe vers §6.3.1)
- §11 (refonte totale, toutes les questions tranchées)

### 12.6 *(Nouveau)* Changelog v0.3 → v0.3.1

**Objet de la version** : refonte complète pour décrire l'état du système en production au 14/05/2026 (chantier admin réseau entièrement livré, paquets A-F + chantier #114). Inscription des doctrines de notification raffinées en cours d'implémentation.

**Sections ajoutées** :
- §3.3.1 et §3.3.2 (subdivision des tables proposals/votes en cooptation et retrait collectif, avec tables symétriques détaillées et flag `was_unanimous`)
- §3.3bis (spécification de la vue publique `api.network_administrators_public_v1` à 7 colonnes, paquet E)
- §4.2.4 Doctrine des notifications du proposeur (R1)
- §4.5 Liste exhaustive des 10 events `network.*` avec destinataires
- §4.6 Cosmétique du `vote_cast` (R7)
- §6.7 Chantier #114 — Mails militants (paquet hors-séquence A-F)
- §8.7 Risque : doctrines de notification en mauvaise position
- §11.2 Raffinements doctrinaux de notification (R1-R7)

**Sections refondues** :
- §1 Objectifs : chaque objectif marqué ✅ avec paquet de livraison
- §3 Architecture : décrite à l'état en prod, plus comme cible
- §3.3 : montée des tables votes avec contraintes CHECK explicites (rationale, motivation), pas de DEFAULT sur `disclose_identity`, expiration à 60j, motivation à 50 chars
- §3.5 : retrait du rôle `administrador` du CHECK constraint marqué comme livré (paquet F)
- §4 entière : raffinements de notification intégrés au schéma général et au workflow détaillé
- §4.2 : tableau des RPC enrichi (`fn_network_admin_propose_collective_removal` + `fn_network_admin_vote_collective_removal` + `fn_network_notify_event`)
- §5.1 : table de correspondance des fonctions marquée avec actions effectives et dates
- §5.3 : ajout de `api.collective_removal_overview` (paquet E.4.c)
- §5.4 : 47 RLS alignées (vs 22 initialement recensées) + nouvelle catégorie D
- §6 entière : tous les paquets marqués livrés avec contenu effectif, sous-paquets détaillés
- §7 entière : décrit l'UI en prod après paquet E
- §8 entière : évaluation post-implémentation des risques
- §9 : situation Xavier marquée résolue au paquet F
- §10 : calendrier réel vs prévisionnel
- §11 entière : restructuration en 11.1 (décisions politiques tranchées) / 11.2 (raffinements R1-R7) / 11.3 (résiduelles ouvertes)

**Sections inchangées** :
- Préambule politique (intact)
- §2 Sémantique des compteurs (intact, doctrine stable)
- §3.2 (audit table inchangée)
- §3.4 (helpers SQL inchangés)
- §12.1 (glossaire enrichi mais structure stable)
- §12.4 et §12.5 (changelogs v0.1→v0.2 et v0.2→v0.3 conservés)

**Bilan v0.3.1** : la spec est désormais **un document de référence post-implémentation**, pas une cible à atteindre. Elle décrit ce qui tourne en production, avec les doctrines de notification raffinées au fil du codage. Toute évolution future passera par une v0.4 dédiée (par exemple : workflow de récupération de réseau en cas de perte du dernier admin, ou élargissement de la liste des actions critiques).

---

*Fin du document. Spec ouverte à amendement.*
