# Spec : Séparation administrateur réseau / staff local

**Version** : 0.2
**Date** : 11/05/2026 (révision complète)
**Auteur·rice** : Xavier (lead dev) + Claude (assistant·e)
**Statut** : brouillon, en attente de validation politique

**Historique de version** :
- v0.1 (11/05/2026, première rédaction, 846 lignes) : pose la séparation conceptuelle, l'architecture cible, la séquence de 6 paquets (A à F).
- v0.2 (11/05/2026, refonte complète) : intègre les décisions politiques du 11/05 matin (sémantique « page = périmètre » des compteurs, nouvelle vue `api.network_overview`, prise en compte du membership coordenador BLMF de Xavier inscrit le 11/05/2026), met à jour les décisions ouvertes Q1-Q6 (certaines tranchées), ouvre la question de l'accélération du retrait de `'administrador'`.

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
2. Sémantique des compteurs *(nouveau §, central dans la v0.2)*
3. Architecture cible
   - 3.1 La table `network_administrators`
   - 3.2 Table d'audit
   - 3.3 Tables de propositions et votes
   - 3.4 Nouveaux helpers SQL
   - 3.5 Modifications de `user_library_memberships`
4. Logique de cooptation à l'unanimité
5. Mapping des modifications nécessaires
6. Plan d'implémentation par paquets
7. Implications UI détaillées
8. Risques et contre-mesures
9. Cas particulier : situation de Xavier au 11/05/2026 *(MAJ v0.2)*
10. Calendrier prévisionnel
11. Décisions ouvertes *(MAJ v0.2)*
12. Annexes

---

## 1. Objectifs et non-objectifs

### 1.1 Objectifs

1. **Séparer la table** : créer `network_administrators` distincte de `user_library_memberships`. Le rôle `administrador` disparaît à terme de cette dernière.
2. **Centraliser l'autorisation** : remplacer les 22 sous-SELECT inline dans les RLS par 2-3 helpers SQL qui consolident « staff local » et « admin réseau ».
3. **Acter la cooptation à l'unanimité** : implémenter en base la garantie qu'un administrateur réseau ne peut être ajouté qu'avec l'accord explicite de tous les administrateurs en place.
4. **Préserver les droits d'intervention** : un administrateur réseau peut toujours agir comme staff local sur n'importe quelle biblio (lecture, écriture, opérationnel) — c'est son droit politique transverse.
5. **Garantir la traçabilité** : tout ajout/retrait d'administrateur réseau est audité avec la liste des votes de cooptation.
6. **(Nouveau v0.2)** **Clarifier la sémantique des compteurs** : chaque vue affiche les engagements de son périmètre, sans calcul croisé entre local et réseau.

### 1.2 Non-objectifs

1. **Modifier la sémantique des rôles locaux** : `reader`, `librarian`, `coordenador` restent inchangés.
2. **Toucher au cycle de vie des memberships locaux** : les transitions `active` → `pending_removal` → `removed` de la spec gouvernance restent comme posées le 5/05/2026 (avec l'élargissement du CHECK fait le 11/05).
3. **Implémenter une hiérarchie réseau** : il n'y a pas de « super-admin » au-dessus des administrateurs réseau. Les administrateurs sont en pair·e·s.
4. **Imposer une durée de mandat** : les administrateurs réseau ne sont pas révocables par majorité, mais ils peuvent se retirer eux-mêmes ou être retirés à l'unanimité.

---

## 2. Sémantique des compteurs *(nouveau §, central dans la v0.2)*

C'est la section qui distingue le plus la v0.2 de la v0.1. Elle pose la grammaire de tous les compteurs militants de l'application, pour qu'on ne se reperde plus dans des calculs croisés ambigus.

### 2.1 La règle, en une phrase

**Chaque page raconte l'histoire de son périmètre. Un compteur compte ce qui est inscrit dans son périmètre, ni plus, ni moins.**

Périmètre d'une biblio : les memberships locaux de cette biblio (`reader`, `librarian`, `coordenador`).
Périmètre du réseau : les administrateurs réseau (`network_administrators`).

Les deux périmètres sont **disjoints** par définition (une fois la séparation complète). Une même personne peut être inscrite dans les deux, mais ce sont **deux inscriptions politiques distinctes**, comptées chacune dans leur périmètre.

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

**Important** : il n'y a pas de compteur « équipe réseau » au sens « toutes les personnes engagées quelque part ». Ce concept n'a pas de sens politique dans la v0.2 — chaque biblio a sa propre équipe, et le réseau a ses administrateurs. Ce sont des engagements politiquement distincts, pas une masse à agréger.

#### Page `/rede` onglet « Bibliotecas » (cartes/lignes par biblio)

Chaque ligne reflète une biblio. Les compteurs par ligne sont **locaux**, comme dans `/biblioteca/<slug>`. La ligne BLMF montre l'équipe locale BLMF, pas « les personnes qui peuvent intervenir sur BLMF ».

#### Page `/rede` onglet « Administradores »

Nouveau dans la v0.2. Liste des administrateurs réseau, alimentée par `api.network_administrators_public_v1`. Aucune information par biblio ici — c'est l'inverse, on regarde le réseau depuis son centre.

### 2.3 Implémentation : deux vues distinctes

Pour soutenir cette sémantique sans calcul croisé, on a besoin de **deux vues principales** au lieu d'une seule mélangée :

**Vue locale par biblio** : `api.library_circulation_stats` (existante, à simplifier)
- Tous les compteurs sont **strictement locaux**
- `librarians_active` ne compte que `role IN ('librarian','coordenador')`, plus aucune mention de `'administrador'` (= changement par rapport à v0.1 qui gardait `administrador` dans le ARRAY pendant la coexistence)
- `readers_active` reste tel quel

**Vue globale réseau** : `api.network_overview` (nouvelle)
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

## 3. Architecture cible

### 3.1 La table `network_administrators`

Inchangée par rapport à la v0.1, déjà créée par le paquet A appliqué le 11/05/2026.

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

### 3.2 Table d'audit

Inchangée par rapport à la v0.1, déjà créée par le paquet A.

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

Inchangées par rapport à la v0.1, déjà créées par le paquet A.

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
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
    CONSTRAINT motivation_not_too_short CHECK (length(trim(motivation)) >= 20)
);

CREATE TABLE public.network_administrator_cooptation_votes (
    proposal_id uuid NOT NULL REFERENCES public.network_administrator_cooptation_proposals(id) ON DELETE CASCADE,
    voter_user_id uuid NOT NULL REFERENCES auth.users(id),
    vote text NOT NULL CHECK (vote IN ('favorable', 'opposed', 'abstain')),
    voted_at timestamptz NOT NULL DEFAULT now(),
    rationale text,
    PRIMARY KEY (proposal_id, voter_user_id)
);
```

### 3.4 Nouveaux helpers SQL

Trois helpers centralisent l'autorisation. Toutes les RLS s'appuieront sur eux. Déjà créés par le paquet A.

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

Le CHECK sur `role` reste pour l'instant à `('reader', 'librarian', 'coordenador', 'administrador')`. La question de son rétrécissement à `('reader', 'librarian', 'coordenador')` est ouverte — voir §11 décisions ouvertes Q7 (nouvelle).

```sql
-- À exécuter UNIQUEMENT en phase finale, après bascule complète des consommateurs
-- ET après migration vers network_administrators de toutes les lignes administrador.
ALTER TABLE public.user_library_memberships
    DROP CONSTRAINT user_library_memberships_role_check;

ALTER TABLE public.user_library_memberships
    ADD CONSTRAINT user_library_memberships_role_check 
    CHECK (role IN ('reader', 'librarian', 'coordenador'));
```

---

## 4. Logique de cooptation à l'unanimité

Inchangée par rapport à la v0.1, intégralement implémentée dans le paquet A.

### 4.1 Schéma général

```
┌──────────────────────────────────────────────────────────┐
│ 1. Un admin existant propose la cooptation d'une personne │
│    → INSERT dans network_administrator_cooptation_proposals│
│    → status='open', expires_at=NOW()+30j                  │
│    → Le proposeur vote automatiquement 'favorable'        │
│    → Mail militant aux autres admins actifs               │
└──────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│ 2. Chaque admin actif vote                                │
│    → INSERT dans network_administrator_cooptation_votes    │
│    → vote ∈ {favorable, opposed, abstain}                 │
│    → 'opposed' = veto immédiat                            │
│    → 'abstain' = ne compte pas dans l'unanimité (bloque)  │
└──────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│ 3. Trigger vérifie après chaque vote :                    │
│    - SI un vote='opposed' → status='rejected', stop       │
│    - SI tous les admins actifs ont voté 'favorable'       │
│      → status='completed' + INSERT dans                   │
│         network_administrators (status='active')          │
│      → Mail à la personne cooptée                         │
│      → Mail récap aux admins                              │
└──────────────────────────────────────────────────────────┘
```

### 4.2 RPC implémentées par le paquet A

| RPC | Rôle | Statut |
|---|---|---|
| `fn_network_admin_propose_cooptation(p_user_id, p_motivation)` | Proposer une nouvelle personne | Opérationnel |
| `fn_network_admin_vote_cooptation(p_proposal_id, p_vote, p_rationale)` | Voter | Opérationnel |
| `fn_network_admin_self_remove(p_reason)` | Auto-retrait | Opérationnel |
| `fn_network_admin_request_removal(p_target_user_id, p_reason)` | Demander retrait d'un autre | **Stub** : marque pending_removal, workflow complet de vote miroir à implémenter au paquet D |

### 4.3 Cas particulier : premier administrateur

Le système suppose au moins un administrateur réseau pour qu'il y ait cooptation. Le **premier administrateur** ne peut pas être coopté (il n'y a personne pour voter). Solution :

- À la migration initiale (paquet B), on insère manuellement la première ligne dans `network_administrators` pour **Xavier** avec `coopted_by_unanimity_of = ARRAY[]::uuid[]` (vide) et `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`.
- Cette manipulation est tracée dans `network_administrator_audit` avec `event_type='foundational_admin_added'` et `metadata.foundational=true`.
- Une fois ce socle posé, toute cooptation ultérieure passe par le workflow normal.

### 4.4 Retrait

**Auto-retrait** (`fn_network_admin_self_remove`) : un administrateur réseau peut quitter ses fonctions à tout moment, sans l'accord des autres. C'est un acte unilatéral. Garde-fou : s'il est le dernier admin actif, transition en `pending_removal` avec carence de 30 jours.

**Retrait collectif** (`fn_network_admin_request_removal`) : workflow miroir de la cooptation, à compléter au paquet D.

---

## 5. Mapping des modifications nécessaires

### 5.1 Fonctions à remplacer (table de correspondance)

| Fonction actuelle | Statut | Action |
|---|---|---|
| `fn_caller_is_administrador()` | DEPRECATED | Remplacée par `fn_caller_is_network_admin()`. Conserver en wrapper pendant la coexistence. |
| `user_has_library_staff_role(uuid, uuid)` | À ÉTENDRE | Doit interroger aussi `network_administrators`. Devient un wrapper de `user_can_act_as_staff_on_library`. |
| `user_can_manage_library(uuid)` | À ÉTENDRE | Doit interroger aussi `network_administrators`. Devient un wrapper de `user_can_engage_library`. |
| `can_manage_document_requests_for_library(uuid)` | AUDIT | Vérifier qu'elle s'appuie sur les helpers, sinon refactorer. |
| `can_manage_library_circulation_policies(uuid)` | AUDIT | Idem. |
| `can_manage_library_contact_profile(uuid)` | AUDIT | Idem. |
| `can_manage_library_document_governance(uuid)` | AUDIT | Idem. |
| `can_manage_library_regulation_documents(uuid)` | AUDIT | Idem. |
| `user_can_manage_library_notifications(uuid)` | AUDIT | Idem. |
| `circulation_reader_scope(uuid, uuid)` | AUDIT | À vérifier, ne devrait pas être impacté. |
| `fn_check_loan_action(text, text, text)` | AUDIT | Probablement OK, utilise un param `actor_role` passé en argument. |
| `fn_resolve_caller_role_for_library(uuid)` | À MODIFIER | Doit retourner `'network_admin'` comme rôle virtuel si l'appelant est admin réseau. |
| `fn_record_membership_payment(...)` | AUDIT | Vérifier les checks d'autorisation internes. |
| `fn_set_retention_policy(...)` | AUDIT | Idem. |
| `fn_team_list_memberships(text, uuid)` | À MODIFIER | Le scope `network` doit lister à la fois les admins réseau et les memberships staff. |
| `fn_team_promote_to_administrador(uuid, uuid)` | DEPRECATED | Remplacée par `fn_network_admin_propose_cooptation`. |
| `fn_team_request_remove_member(uuid, uuid, text, text)` | À MODIFIER | Doit refuser de retirer un admin réseau (passer par les RPC dédiées). |
| `fn_team_self_demote(uuid, text, text)` | À MODIFIER | Idem. |
| `fn_team_suspend_member(uuid, uuid, text, text)` | À MODIFIER | Idem. |
| `api.cancel_reservation_as_library(...)` | AUDIT | Vérifier les checks internes. |

### 5.2 Vues à modifier

| Vue | Modification |
|---|---|
| `api.library_circulation_stats` | Paquet 22 (déjà fait, 11/05) : suppression du WHERE EXISTS. Paquet 23 (déjà fait, 11/05) : COUNT(DISTINCT user_id) sur `librarians_active` et `readers_active`. **v0.2 : au paquet B/F, retirer `'administrador'` du ARRAY de `librarians_active`** (cohérence avec la sémantique « page = périmètre local »). |
| `api.my_access` | Doit consolider `network_administrators` ET `user_library_memberships` pour `can_access_painel` et `can_access_catalogacao`. Réécriture conséquente : voir §6.2. |

### 5.3 Nouvelles vues à créer

| Vue | Rôle | Statut |
|---|---|---|
| `api.network_administrators_public_v1` | Liste publique-réseau des admins réseau actifs | Créée par paquet A |
| `api.my_network_admin_status` | Statut admin réseau de l'appelant courant | Créée par paquet A |
| `api.network_overview` *(nouveau v0.2)* | Indicateurs globaux du réseau (compteurs réseau pour `/rede`) | Paquet B |

#### Spécification de `api.network_overview`

Vue agrégée pour le bandeau « Vue d'ensemble du réseau ». Une seule ligne retournée, contenant les indicateurs globaux. Ne fait **aucun** calcul croisé personnes×biblios — la spec v0.2 acte que ce calcul croisé n'a pas de sens politique.

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

Volontairement minimaliste. Pas de compteur « équipe réseau » au sens « toutes les personnes engagées quelque part » : ce concept n'existe pas dans la sémantique v0.2.

### 5.4 RLS à modifier

Les 22 policies identifiées dans l'audit du 11/05 se répartissent en trois catégories :

**Catégorie A — « staff local + admin réseau » (15 policies)** : doivent basculer sur `user_can_act_as_staff_on_library(library_id)`.

Tables : `author_translations`, `libraries`, `library_retention_policies` (×2), `library_service_state` (×3), `painel_internal_tasks` (×4), `painel_internal_task_invites`, `painel_internal_task_invitation_outbox`, `painel_internal_task_notification_outbox`, `storage.objects` (privacy ×3).

**Catégorie B — « engagement politique de la biblio » (4 policies)** : doivent basculer sur `user_can_engage_library(library_id)`.

Tables : `library_membership_rules`, `library_retention_policies` (modify), `membership_payments` (×2).

**Catégorie C — « administrateur réseau pur » (1 policy)** : `ulm_select_all_for_administrador` doit basculer sur `fn_caller_is_network_admin()`.

---

## 6. Plan d'implémentation par paquets

### 6.1 Paquet A — Infrastructure DB *(LIVRÉ le 11/05/2026)*

**Statut : ✅ Appliqué en production.**

Contenu livré :
- 4 tables (`network_administrators`, audit, proposals, votes)
- 3 helpers (`fn_caller_is_network_admin`, `user_can_act_as_staff_on_library`, `user_can_engage_library`)
- 4 RPC (propose, vote, self_remove, request_removal en stub)
- 1 trigger de complétion automatique des cooptations
- 2 vues (`api.network_administrators_public_v1`, `api.my_network_admin_status`)
- 4 policies RLS sur les nouvelles tables
- Audit immuable garanti par triggers `BEFORE UPDATE/DELETE`

**Impact prod confirmé** : aucun. Toutes les RLS, fonctions et vues existantes intactes.

### 6.2 Paquet B — Migration fondatrice + réécriture `api.my_access` + création `api.network_overview`

**Objectif** : faire entrer Xavier dans `network_administrators` comme administrateur fondateur, consolider `api.my_access` pour utiliser à la fois les memberships locaux et les admins réseau, créer la vue réseau.

**Contenu** :

1. **INSERT manuel** d'une ligne fondatrice :
   ```sql
   INSERT INTO public.network_administrators 
       (user_id, status, coopted_at, coopted_by_unanimity_of, notes)
   VALUES (
       'd6710372-e5e5-4608-800b-99a26817c677',  -- Xavier
       'active',
       now(),
       ARRAY[]::uuid[],
       'Fondateur du réseau AnarBib, cooptation hors workflow (paquet B)'
   );
   
   INSERT INTO public.network_administrator_audit
       (user_id, event_type, actor_user_id, target_user_id, metadata)
       VALUES (...'foundational_admin_added'..., jsonb_build_object('foundational', true));
   ```

2. **Réécriture de `api.my_access`** pour consolider les deux sources de droits :
   - `can_access_painel` = `true` si membership staff local actif (n'importe quelle biblio) **OU** admin réseau actif
   - `can_access_catalogacao` = idem
   - Conserve la sémantique « effective_membership » pour la biblio par défaut

3. **Création de `api.network_overview`** comme défini ci-dessus.

4. **Modification de `fn_resolve_caller_role_for_library`** pour retourner `'network_admin'` comme rôle virtuel si l'appelant est admin réseau (avec priorité sur le rôle local si présent).

5. **Question politique à trancher dans ce paquet** :
   - **Q7 (nouvelle, v0.2)** : doit-on supprimer immédiatement la ligne `administrador` de Xavier dans `user_library_memberships` (puisqu'il a maintenant son `coordenador` BLMF inscrit politiquement + va recevoir son admin réseau dans `network_administrators`) ? Ou attendre la phase finale paquet F ?

**Impact prod** : modéré. La réécriture de `my_access` est délicate (vue utilisée par 3 RLS critiques). Tests en staging recommandés si possible, sinon vérification immédiate après application.

**Tests de validation post-application** :
- Xavier en tant qu'admin réseau peut accéder à /painel et /catalogacao pour toutes les biblios
- Patricia en tant que coord BTL peut accéder à /painel BTL uniquement (inchangé)
- `api.network_overview` retourne 1 ligne avec `network_admins_active = 1`, `libraries_active = 2`

### 6.3 Paquet C — Bascule progressive des RLS

**Objectif** : remplacer les 22 sous-SELECT inline par les nouveaux helpers, table par table.

**Découpage** :

- **C.1** — `painel_internal_tasks` + outbox (4 policies). Bascule sur `user_can_act_as_staff_on_library`. Les plus testées, sans risque.
- **C.2** — `library_service_state` (3 policies), `libraries` (1 policy). Politiques structurelles.
- **C.3** — `library_retention_policies` (2 policies), `library_membership_rules` (1 policy), `membership_payments` (2 policies). Politiques d'engagement.
- **C.4** — `storage.objects` (3 policies). Uploads privacy.
- **C.5** — `user_library_memberships` (2 policies). Le plus délicat, à garder pour la fin.

À chaque sous-paquet, validation manuelle avec scénario test concret en tant qu'admin réseau **et** en tant que staff local.

### 6.4 Paquet D — Refactorisation RPC + workflow retrait complet

**Objectif** : nettoyer les helpers `can_manage_*` et compléter le workflow de retrait collectif.

**Contenu** :
1. Audit des 5 helpers `can_manage_*` et refactorisation pour appel direct aux nouveaux centralisés.
2. Modification des `fn_team_*` pour refuser les opérations sur les admins réseau.
3. Suppression de `fn_team_promote_to_administrador` (remplacée par `fn_network_admin_propose_cooptation`).
4. Implémentation complète du workflow de retrait collectif (vote miroir de la cooptation).

### 6.5 Paquet E — UI

**Objectif** : exposer les nouvelles fonctionnalités aux administrateurs réseau.

**Contenu** :
1. Refonte onglet « Administradores » de /rede : consommation de `network_administrators` + bouton « Propor cooptação ».
2. Nouvel onglet « Propostas em curso » : liste des proposals ouvertes + boutons de vote.
3. Composant `NetworkAdminBadge` pour profil utilisateur.
4. Mise à jour de `LibraryContext` pour exposer `isNetworkAdmin`, `effectiveRole`, `hasStaffAccess`.
5. **Application de la sémantique v0.2 des compteurs** : retrait de `'administrador'` du ARRAY dans `library_circulation_stats.librarians_active`, branchement de `network_overview` sur le bandeau /rede.
6. i18n des nouveaux events `network.cooptation_*` × 6 locales.

### 6.6 Paquet F — Phase finale

**Objectif** : retirer le rôle `'administrador'` du schéma `user_library_memberships`.

**Contenu** :
1. DELETE éventuelles lignes `user_library_memberships.role='administrador'` restantes (si non déjà fait au paquet B).
2. ALTER CHECK pour retirer `'administrador'` du domaine de `role`.
3. Suppression des wrappers deprecated (`fn_caller_is_administrador`, anciens helpers).
4. Mise à jour de la spec gouvernance des rôles (cohérence sémantique).
5. Documentation dans le Livre Blanc.

**Pré-requis pour exécution** :
- Au moins 30 jours d'observation sans incident depuis le paquet E.
- Aucune référence à `'administrador'` dans le code frontend.
- Aucune référence à `'administrador'` dans les helpers DB (vérifié par requête `pg_get_functiondef`).
- Aucune RLS résiduelle qui mentionne `'administrador'` (vérifié par requête `pg_policies`).

### 6.7 Question d'accélération (v0.2)

La séquence A → F décrite ci-dessus est conservatrice : elle prévoit une coexistence longue (4-8 semaines) entre l'ancien rôle et le nouveau modèle. C'était justifié dans la v0.1 par la peur de casser la prod.

**Question ouverte (Q8, nouvelle v0.2)** : maintenant que :
- Xavier a son `coordenador` BLMF inscrit politiquement (paquet 23bis appliqué)
- L'audit a montré qu'il n'y a qu'**une seule ligne** `administrador` à migrer dans toute la base
- Les helpers centralisés sont opérationnels (paquet A)

Pourrait-on **fusionner les paquets B + C + une partie de F en un seul gros paquet** ? Avantages : moins de coexistence à maintenir, moins de risque d'incohérence entre deux mécanismes. Inconvénient : un paquet plus gros = plus de surface de bug à attraper d'un coup.

Décision à prendre au moment d'écrire le paquet B. Mon biais (Claude) : la séquence conservatrice reste plus sûre, mais l'argument de l'unique ligne à migrer est très fort. À débattre avec un cerveau frais.

---

## 7. Implications UI détaillées

### 7.1 `LibraryContext`

Aujourd'hui, `LibraryContext` expose un `role` calculé à partir du membership de l'utilisateur sur la biblio courante. Demain, il doit aussi exposer :

- `isNetworkAdmin: boolean` — l'utilisateur est-il administrateur réseau actif ?
- `effectiveRole: 'reader' | 'librarian' | 'coordenador' | 'network_admin' | null` — rôle effectif. `network_admin` prime sur le rôle local pour les autorisations transverses.
- `hasStaffAccess: boolean` — calculé via `user_can_act_as_staff_on_library`.
- `hasEngagementAccess: boolean` — calculé via `user_can_engage_library`.

**Migration progressive** : ajouter les nouveaux champs sans retirer `role`. Les composants existants continuent de fonctionner. Les nouveaux composants utilisent les nouveaux champs.

### 7.2 Badges et étiquettes

- **Aujourd'hui** : un seul badge `<RoleBadge role={role} />` qui affiche pt-BR « Administrador(a/e) » si `role='administrador'`.
- **Demain** : deux badges distincts possibles :
  - `<LocalRoleBadge>` pour le rôle dans la biblio courante (Leitor·a·e / Bibliotecária·o / Coordenadora·or)
  - `<NetworkAdminBadge>` pour le statut administrateur réseau

Les deux peuvent s'afficher en même temps (ex. dans le cas de Xavier : « Coordenador BLMF » + « Admin AnarBib »).

### 7.3 /rede onglet « Vue d'ensemble » — application sémantique v0.2

**Avant** (état actuel pré-v0.2) : bandeau avec « EQUIPE » et « LEITORES » globaux qui agrègent des memberships locaux dans tout le réseau (sémantique floue).

**Après** :
- « ADMINISTRADORES » (nombre d'admins réseau actifs)
- « BIBLIOTECAS » (nombre de biblios actives)
- « DOCUMENTOS », « AUTORIDADES », « EXEMPLARES » (catalogue agrégé)
- « EMPRÉSTIMOS ABERTOS », « RESERVAS ATIVAS », « EM ATRASO » (circulation agrégée)
- **Plus de compteur « EQUIPE » global** : ce concept n'a pas de sens politique au niveau réseau.
- **Plus de compteur « LEITORES » global** : idem.

Source : `api.network_overview`.

### 7.4 /rede onglet « Bibliotecas » (cartes/lignes par biblio)

Chaque ligne reste avec ses compteurs locaux (Leitores, Equipe, Exemplares, Emprestimos, etc.), consommés depuis `api.library_circulation_stats`. La sémantique v0.2 garantit que `librarians_active` ne compte plus que `librarian + coordenador`, plus de mention `administrador`.

Conséquence visible pour Xavier après paquet B + paquet E : la carte BLMF affichera `Equipe = 1` (lui seul, en tant que coordenador). Son statut d'admin réseau est invisible depuis cette carte, conformément à la règle « page = périmètre ».

### 7.5 /rede onglet « Administradores »

**Avant** : `AdminsPanel` actuel, qui faisait UPDATE direct sur `user_library_memberships.role`.

**Après** :
- Liste des administrateurs réseau actifs (consommation de `api.network_administrators_public_v1`)
- Bouton « Propor cooptação » → modal avec champ email + champ motivation (>=20 chars). Appel à `fn_network_admin_propose_cooptation`.
- Section « Propostas em curso » : liste des proposals en `status='open'`, avec boutons « Votar favorável / Votar contra / Abster-se ».
- Section « Histórico » : consommation de `network_administrator_audit`.

### 7.6 /biblioteca onglet « Equipe »

Le `TeamPanel scope="library"` reste centré sur les memberships locaux (`librarian`, `coordenador`). **Les administrateurs réseau ne sont pas listés ici**, sauf s'ils ont aussi un membership staff local sur cette biblio.

Pour Xavier après paquet B : il apparaîtra dans `/biblioteca/blmf` onglet Equipe au titre de son `coordenador`. Son statut admin réseau est affiché par un badge supplémentaire, pas par une ligne supplémentaire.

### 7.7 Notifications mail militantes

Nouveaux events à internationaliser × 6 locales :

- `network.cooptation_proposed`
- `network.cooptation_voted`
- `network.cooptation_completed`
- `network.cooptation_rejected`
- `network.cooptation_expired`
- `network.self_removal`
- `network.removal_completed`
- `network.foundational_admin_added` (informatif, paquet B)

Tonalité militante stricte (École 1) avec point médian inclusif pour fr, triple o/a/e pour pt-BR, e neutre pour es, Genderstern pour de.

---

## 8. Risques et contre-mesures

### 8.1 Risque : perte d'accès accidentelle pendant la bascule

**Scénario** : un administrateur perd ses droits sur une biblio parce qu'une RLS a été basculée sur le nouveau helper avant que sa ligne soit migrée dans `network_administrators`.

**Contre-mesure** : le paquet B migre Xavier **avant** que le paquet C ne touche aux RLS. Pendant la coexistence, l'ancienne ligne `administrador` dans `user_library_memberships` reste tant que le paquet F n'a pas été exécuté. Les RLS basculées s'appuient sur les helpers qui interrogent `network_administrators` ; les RLS non encore basculées continuent à fonctionner avec l'ancien rôle. Double mécanisme = pas de fenêtre de perte d'accès.

### 8.2 Risque : duplication de logique pendant la coexistence

**Scénario** : Xavier a une ligne `administrador` dans `user_library_memberships` ET une ligne dans `network_administrators`. Si on retire l'une sans l'autre, incohérence.

**Contre-mesure** : ce cas est temporaire (de paquet B à paquet F). Pendant cette période, ne pas modifier le rôle administrador via le panneau frontend. Si modification nécessaire, passer par les nouvelles RPC qui gèrent les deux côtés.

### 8.3 Risque : la cooptation à l'unanimité bloque le réseau

**Scénario** : un administrateur réseau devient inactif (ne se connecte plus) mais reste en `status='active'`. Toute nouvelle cooptation est bloquée.

**Contre-mesure** : ajouter un cron `pg_cron` qui passe automatiquement à `status='inactive'` tout admin réseau dont `last_seen_at < now() - interval '6 months'`. Les admins inactifs ne sont pas comptés dans l'unanimité requise.

### 8.4 Risque : perte du dernier administrateur

**Scénario** : le dernier admin réseau se retire. Plus personne ne peut coopter.

**Contre-mesure** : le RPC `fn_network_admin_self_remove` détecte ce cas et passe l'admin en `status='pending_removal'` avec une carence de 30 jours pendant lesquels il peut revenir. Workflow de récupération de réseau à spécifier dans une spec ultérieure (cooptation amorcée par les coordenadores des biblios actives).

### 8.5 Risque : abus de l'administrateur réseau

**Scénario** : un administrateur réseau utilise son droit d'intervention opérationnelle pour modifier des données d'une biblio sans concertation avec son staff local.

**Contre-mesure** : **traçabilité maximale**. Toutes les actions des administrateurs réseau sur des biblios où ils ne sont pas staff local seront auditées dans une table `network_admin_cross_library_actions` (à spécifier dans le paquet C.5). Le staff local de la biblio est notifié par mail. Le mécanisme protège politiquement sans empêcher techniquement.

### 8.6 (Nouveau v0.2) Risque : incohérence de compteurs pendant la coexistence

**Scénario** : entre le paquet B (Xavier dans `network_administrators`) et le paquet E (frontend met à jour la sémantique des compteurs), les compteurs « équipe » de BLMF et le bandeau /rede peuvent afficher des chiffres incohérents.

**Contre-mesure** : la sémantique v0.2 sera appliquée d'abord côté DB (vue `library_circulation_stats` simplifiée au paquet B ou E) puis côté frontend. Documenter le mismatch éventuel dans le journal de session. Privilégier l'application simultanée DB+UI au paquet E pour éviter toute fenêtre incohérente visible par l'utilisateur.

---

## 9. Cas particulier : situation de Xavier au 11/05/2026 *(MAJ v0.2)*

État actuel des memberships de Xavier dans `user_library_memberships` :

| role | library_id | status | is_primary | created_at |
|---|---|---|---|---|
| administrador | BLMF | active | true | 2026-03-24 |
| coordenador | BLMF | active | false | 2026-05-11 (paquet 23bis) |

**Lecture politique** :
- Le `coordenador` BLMF reflète l'engagement réel de Xavier dans l'animation quotidienne de BLMF.
- L'`administrador` BLMF est un **artefact** du modèle ancien : il représente politiquement « Xavier admin réseau », mais il est techniquement rattaché à BLMF parce que le modèle ne prévoyait pas de rôle réseau pur.

**Trajectoire cible** après bascule complète :

| Table | Ligne |
|---|---|
| `user_library_memberships` | `coordenador` BLMF, status='active', is_primary=true |
| `network_administrators` | Xavier, status='active', cooptation fondatrice |

L'ancien `administrador` BLMF disparaît à terme. La question du moment exact de sa suppression est l'objet de la décision ouverte **Q7** (voir §11).

**Note sur `is_primary`** : actuellement `administrador` est primaire et `coordenador` ne l'est pas. Après le paquet B/F, comme il ne restera que la ligne `coordenador`, elle devrait passer `is_primary=true`. À gérer dans la migration du paquet B.

---

## 10. Calendrier prévisionnel

| Paquet | Durée estimée | Dépendances | Statut |
|---|---|---|---|
| A — Infrastructure | 1 session intensive (~6h) | Aucune | ✅ **Livré 11/05/2026** |
| B — Migration Xavier + my_access + network_overview | 1-2 sessions (~4-6h) | A | À faire |
| C — Bascule RLS (C.1 à C.5) | 3-5 sessions sur 2-4 semaines | B | À faire |
| D — Refactorisation RPC | 1-2 sessions | C complet | À faire |
| E — UI | 2-3 sessions | A + B + propositions accessibles | À faire |
| F — Phase finale | 1 session | E + 30j d'observation | À faire |

**Total restant** : environ 8-12 sessions de travail, étalées sur 4-8 semaines avec coexistence en production permanente.

**Hypothèse alternative (Q8)** : fusion paquets B+C+F si décision d'accélération → 3-5 sessions sur 1-2 semaines, plus de risque mais moins de coexistence à maintenir.

---

## 11. Décisions ouvertes

Mises à jour v0.2 : certaines questions de la v0.1 sont **tranchées** par les décisions de ce matin, d'autres sont conservées, deux nouvelles sont introduites.

**Q1 (tranchée le 11/05)** : ~~Les administrateurs réseau peuvent-ils être membres staff de plusieurs biblios à la fois ?~~ **Réponse : oui, c'est légitime politiquement. La sémantique « page = périmètre » garantit qu'aucun compteur ne le pénalise.**

**Q2** — Doit-on créer une table `network_admin_cross_library_actions_log` au paquet C.5 ou est-ce trop intrusif ? *Reste ouvert.*

**Q3** — Quel délai d'expiration pour les propositions de cooptation : 30 jours ou 14 jours ? *Posé à 30 jours par défaut dans le paquet A, reste discutable.*

**Q4** — Le mail au proposé en cas de rejet de cooptation : on transmet la rationale des opposants ou on garde l'opposition anonyme ? *Reste ouvert.*

**Q5** — La carence avant retrait définitif d'un administrateur retiré collectivement : immédiate, 7 jours, 30 jours ? *Posée à 30 jours pour le self-removal du dernier admin. À harmoniser pour le retrait collectif au paquet D.*

**Q6** — On notifie le staff local d'une biblio quand un admin réseau y fait une action ? Mail immédiat ou digest hebdomadaire ? *Reste ouvert, dépendant de Q2.*

**Q7 (NOUVEAU v0.2)** — Doit-on supprimer la ligne `user_library_memberships` `administrador` BLMF de Xavier dès le paquet B (puisqu'il a son `coordenador` BLMF politiquement inscrit + va recevoir son admin réseau dans `network_administrators`) ? Ou attendre le paquet F ?

**Arguments pour la suppression précoce (paquet B)** :
- Cohérence sémantique immédiate : pas de double engagement local
- La sémantique v0.2 « page = périmètre » devient pleinement opérationnelle
- Réduit la confusion pendant la coexistence
- Simplifie le paquet F (qui devient quasi vide pour Xavier)

**Arguments pour attendre (paquet F)** :
- Préserve le mécanisme de double-filet de sécurité décrit en 8.1
- Permet de tester progressivement les RLS basculées sans risque de perte d'accès
- Respect du principe de coexistence longue (paranoïaque vs ambitieux)

*Préférence personnelle (Claude) : suppression précoce paquet B, dans la même transaction que l'INSERT fondateur. L'argument du double-filet n'est pas pertinent ici car Xavier sera dans `network_administrators` au même moment.*

**Q8 (NOUVEAU v0.2)** — Compte tenu qu'il n'y a qu'une seule ligne `administrador` à migrer (Xavier), pourrait-on fusionner les paquets B + C + une partie de F en un seul paquet « grand bond » ?

**Arguments pour** :
- Réduction drastique du temps de coexistence (1-2 semaines au lieu de 4-8)
- Moins de surface d'incohérence
- Économies de sessions de travail

**Arguments contre** :
- Paquet plus volumineux = plus de risque d'erreur d'un coup
- Moins de checkpoints intermédiaires de validation
- Pas de tests progressifs des RLS basculées

*À débattre au moment d'attaquer le paquet B, en cerveau frais.*

---

## 12. Annexes

### 12.1 Glossaire

- **Administrateur réseau** (alias *network admin*, *administrador AnarBib*) : personne membre du réseau de coordination AnarBib, avec autorité transverse sur toutes les biblios.
- **Staff local** : ensemble des `librarian` + `coordenador` actifs d'une biblio donnée.
- **Cooptation** : processus d'ajout d'une nouvelle personne au réseau d'administrateurs, à l'unanimité des administrateurs en place.
- **Engagement politique** : capacité de modifier les paramètres structurels d'une biblio (règlement, politique de circulation, identité). Réservé aux `coordenador` et aux administrateurs réseau.
- **Intervention opérationnelle** : capacité de réaliser des actions quotidiennes (prêt, retour, réservation au nom d'un lecteur). Réservé au staff local et aux administrateurs réseau.
- **(v0.2) Périmètre** : ensemble des engagements politiquement situés sur un même objet (une biblio, ou le réseau). Sert de cadre pour la sémantique des compteurs.

### 12.2 Requêtes d'audit utilisées pour la rédaction

Voir les bilans de session du 11/05/2026 :
- 4 requêtes d'inventaire initial (fonctions, RLS, vues, données) qui ont fondé la cartographie complète du chantier
- Requête de diagnostic du WHERE EXISTS de `library_circulation_stats` (paquet 22)
- Requête de détection des doublons de memberships staff (a révélé la ligne BLMF du 7/05)
- Audit RLS du 11/05 (a confirmé que le retrait du WHERE EXISTS était safe)

### 12.3 Références internes

- `docs/spec-gouvernance-roles.md` (5/05/2026) : sémantique des rôles locaux, transitions de status. Ce chantier en est le prolongement logique.
- Migration `2026_05_05_user_can_manage_library_remove_phantom_roles.sql` : nettoyage des rôles fantômes du 5/05 sur lequel ce chantier s'appuie.
- Paquet 22 (11/05/2026) : fix de `api.library_circulation_stats` qui a révélé la nécessité de cette séparation.
- Paquet 23 (11/05/2026) : COUNT(DISTINCT) + alignement vocabulaire status sur `network_administrators`.
- Paquet 23bis (11/05/2026) : nettoyage politique de la ligne BLMF fantôme + inscription du vrai coordenador BLMF de Xavier.
- Paquet A (11/05/2026) : infrastructure DB du modèle network_administrators.

### 12.4 Changelog v0.1 → v0.2

**Sections ajoutées** :
- §2 Sémantique des compteurs (nouvelle section centrale, ~150 lignes)
- §5.3 Spécification de `api.network_overview`
- §6.7 Question d'accélération
- §7.3 Application sémantique v0.2 au bandeau /rede
- §8.6 Risque d'incohérence de compteurs pendant la coexistence
- §11 Q7 et Q8 (nouvelles décisions ouvertes)
- §12.4 Ce changelog

**Sections mises à jour** :
- §6.1 (paquet A marqué livré)
- §6.2 (paquet B enrichi : Xavier au lieu de toute migration, `network_overview` ajouté)
- §6.5 (paquet E enrichi : application sémantique compteurs)
- §9 Cas particulier Xavier (situation actuelle au 11/05 documentée)
- §10 Calendrier (paquet A marqué livré, hypothèse Q8 mentionnée)
- §11 (Q1 marquée tranchée, Q7 et Q8 ajoutées)

**Sections inchangées** :
- §3 Architecture cible (sauf §3.5 mineur)
- §4 Logique de cooptation
- §5.1 Mapping fonctions
- §5.4 RLS

---

*Fin du document. Spec ouverte à amendement.*
