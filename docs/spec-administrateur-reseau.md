# Spec : Séparation administrateur réseau / staff local

**Version** : 0.1
**Date** : 11/05/2026
**Auteur·rice** : Xavier (lead dev) + Claude (assistant·e)
**Statut** : brouillon, en attente de validation politique

---

## Préambule politique

AnarBib n'est pas une chaîne de bibliothèques avec un siège central. C'est un réseau fédéré de collectifs autonomes. La structure des rôles dans le SIGB doit refléter cette réalité politique, pas la masquer.

Aujourd'hui, le rôle `administrador` est rattaché à une `library_id` dans la table `user_library_memberships`. Cette modélisation suggère implicitement qu'un administrateur AnarBib *administre une biblio*. Ce n'est pas vrai politiquement : un administrateur réseau anime la coordination inter-biblios, il ne dirige aucune biblio particulière. Chaque biblio reste autonome dans son fonctionnement, ses règles, ses adhésions.

Cette spec acte la séparation entre :

- **Le staff local** d'une biblio : les personnes qui animent au quotidien une biblio donnée (`librarian`, `coordenador`). Leur autorité politique se situe dans le périmètre de leur biblio.
- **L'administration du réseau** : les personnes qui assurent la coordination inter-biblios, la modération du catalogue partagé, l'accueil des nouvelles biblios, la maintenance technique. Leur autorité politique est transverse, mais elle ne se substitue jamais à l'autonomie locale.

Cette distinction n'est pas administrative, elle est politique. Elle évite la confusion entre « qui anime cette biblio » et « qui anime le réseau », confusion qui pourrait laisser penser qu'un administrateur réseau est un échelon supérieur dans une hiérarchie. Il n'en est rien : les biblios sont autonomes, le réseau est leur lieu de coordination, pas leur direction.

---

## 1. Objectifs et non-objectifs

### 1.1 Objectifs

1. **Séparer la table** : créer `network_administrators` distincte de `user_library_memberships`. Le rôle `administrador` disparaît de cette dernière.
2. **Centraliser l'autorisation** : remplacer les 22 sous-SELECT inline dans les RLS par 2-3 helpers SQL qui consolident « staff local » et « admin réseau ».
3. **Acter la cooptation à l'unanimité** : implémenter en base la garantie qu'un administrateur réseau ne peut être ajouté qu'avec l'accord explicite de tous les administrateurs en place.
4. **Préserver les droits actuels** : un administrateur réseau peut toujours faire tout ce qu'un staff local peut faire, dans n'importe quelle biblio (lecture, écriture, opérationnel).
5. **Garantir la traçabilité** : tout ajout/retrait d'administrateur réseau est audité avec la liste des votes de cooptation.

### 1.2 Non-objectifs

1. **Modifier la sémantique des rôles locaux** : `reader`, `librarian`, `coordenador` restent inchangés.
2. **Toucher au cycle de vie des memberships locaux** : les transitions `active` → `pending_removal` → `removed` de la spec gouvernance restent comme posées le 5/05/2026.
3. **Implémenter une hiérarchie réseau** : il n'y a pas de « super-admin » au-dessus des administrateurs réseau. Les administrateurs sont en pair·e·s.
4. **Imposer une durée de mandat** : les administrateurs réseau ne sont pas révocables par majorité, mais ils peuvent se retirer eux-mêmes ou être retirés à l'unanimité.

---

## 2. Architecture cible

### 2.1 La table `network_administrators`

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

COMMENT ON TABLE public.network_administrators IS 
'Personnes qui animent la coordination du réseau AnarBib. Cooptation à l''unanimité des administrateurs en place. Aucune library_id : leur autorité est transverse au réseau, jamais située dans une biblio particulière.';

COMMENT ON COLUMN public.network_administrators.coopted_by_unanimity_of IS 
'Liste des user_id des administrateurs qui ont voté favorablement à la cooptation. Doit être égal à l''ensemble des administrateurs actifs au moment de la cooptation.';

CREATE INDEX network_administrators_status_idx 
    ON public.network_administrators(status) 
    WHERE status = 'active';
```

**Notes de conception** :

- **Pas de `library_id`** : c'est le cœur de la séparation. La table n'a aucun rattachement biblio.
- **Une seule ligne par personne** : `user_id` est PRIMARY KEY. On ne peut pas être deux fois administrateur réseau.
- **`status` calqué sur la spec gouvernance** : on réutilise le vocabulaire (`active`, `pending_removal`, `removed`, `inactive`) pour la cohérence sémantique avec `user_library_memberships`.
- **`coopted_by_unanimity_of`** : tableau des user_id des votants. Vérifié par trigger (cf. §3.4).
- **`last_seen_at`** : optionnel, peut servir pour une logique d'inactivité (sortie auto à 9 mois comme dans la spec gouvernance des rôles locaux).
- **Pas de `is_primary`** : sans rattachement biblio, la notion n'a pas de sens.

### 2.2 Table d'audit

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
            'self_removal_requested', 
            'removal_requested', 
            'removal_completed', 
            'inactivity_marked'
        )),
    actor_user_id uuid REFERENCES auth.users(id),
    target_user_id uuid REFERENCES auth.users(id),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.network_administrator_audit IS 
'Journal immuable des événements liés aux administrateurs réseau. INSERT only, jamais UPDATE ni DELETE.';

CREATE INDEX network_administrator_audit_user_id_idx 
    ON public.network_administrator_audit(user_id, created_at DESC);
CREATE INDEX network_administrator_audit_event_type_idx 
    ON public.network_administrator_audit(event_type, created_at DESC);
```

### 2.3 Table des propositions de cooptation en cours

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
    UNIQUE (proposed_user_id, status) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE public.network_administrator_cooptation_votes (
    proposal_id uuid NOT NULL REFERENCES public.network_administrator_cooptation_proposals(id) ON DELETE CASCADE,
    voter_user_id uuid NOT NULL REFERENCES auth.users(id),
    vote text NOT NULL CHECK (vote IN ('favorable', 'opposed', 'abstain')),
    voted_at timestamptz NOT NULL DEFAULT now(),
    rationale text,
    PRIMARY KEY (proposal_id, voter_user_id)
);

COMMENT ON TABLE public.network_administrator_cooptation_proposals IS 
'Propositions de cooptation en cours. Une seule proposition active par personne proposée (UNIQUE partial). Expiration automatique à 30 jours.';

COMMENT ON TABLE public.network_administrator_cooptation_votes IS 
'Votes des administrateurs réseau actifs sur une proposition. Une voix par personne. Une seule opposition suffit à bloquer (unanimité requise).';
```

### 2.4 Les nouveaux helpers SQL

Trois helpers centralisent l'autorisation. Toutes les RLS s'appuieront sur eux.

#### 2.4.1 `fn_caller_is_network_admin()` — successeur de `fn_caller_is_administrador()`

```sql
CREATE OR REPLACE FUNCTION public.fn_caller_is_network_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.network_administrators
        WHERE user_id = auth.uid() AND status = 'active'
    );
$$;

COMMENT ON FUNCTION public.fn_caller_is_network_admin() IS 
'Retourne TRUE si l''appelant courant est un administrateur réseau actif. Remplace fn_caller_is_administrador().';

GRANT EXECUTE ON FUNCTION public.fn_caller_is_network_admin() TO authenticated;
```

#### 2.4.2 `user_can_act_as_staff_on_library(p_library_id)` — successeur élargi de `user_has_library_staff_role`

```sql
CREATE OR REPLACE FUNCTION public.user_can_act_as_staff_on_library(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
    SELECT 
        -- Soit administrateur réseau (droit transverse)
        EXISTS (
            SELECT 1 FROM public.network_administrators
            WHERE user_id = auth.uid() AND status = 'active'
        )
        OR
        -- Soit staff local actif sur cette biblio
        EXISTS (
            SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid()
              AND m.library_id = p_library_id
              AND m.status = 'active'
              AND m.role = ANY (ARRAY['librarian', 'coordenador'])
        );
$$;

COMMENT ON FUNCTION public.user_can_act_as_staff_on_library(uuid) IS 
'Retourne TRUE si l''appelant peut agir comme membre du staff sur la biblio donnée. Inclut les administrateurs réseau (droit transverse) et le staff local actif.';

GRANT EXECUTE ON FUNCTION public.user_can_act_as_staff_on_library(uuid) TO authenticated;
```

#### 2.4.3 `user_can_engage_library(p_library_id)` — successeur de `user_can_manage_library`

```sql
CREATE OR REPLACE FUNCTION public.user_can_engage_library(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
    SELECT 
        -- Soit administrateur réseau
        EXISTS (
            SELECT 1 FROM public.network_administrators
            WHERE user_id = auth.uid() AND status = 'active'
        )
        OR
        -- Soit coordenador local actif (les librarian ne peuvent pas engager politiquement)
        EXISTS (
            SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid()
              AND m.library_id = p_library_id
              AND m.status = 'active'
              AND m.role = 'coordenador'
        );
$$;

COMMENT ON FUNCTION public.user_can_engage_library(uuid) IS 
'Retourne TRUE si l''appelant peut engager politiquement la biblio (modifications structurelles, règlement, politique de circulation). Inclut administrateurs réseau et coordenadores locaux.';

GRANT EXECUTE ON FUNCTION public.user_can_engage_library(uuid) TO authenticated;
```

### 2.5 Modifications de la table `user_library_memberships`

```sql
-- À exécuter UNIQUEMENT en phase finale, après bascule complète des consommateurs.
ALTER TABLE public.user_library_memberships
    DROP CONSTRAINT user_library_memberships_role_check;

ALTER TABLE public.user_library_memberships
    ADD CONSTRAINT user_library_memberships_role_check 
    CHECK (role IN ('reader', 'librarian', 'coordenador'));
```

**Note** : ne PAS exécuter cette ALTER tant qu'il existe encore des lignes `role='administrador'` dans la table. La phase finale du chantier inclut la suppression de ces lignes après migration.

---

## 3. Logique de cooptation à l'unanimité

### 3.1 Schéma général

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

### 3.2 RPC `fn_network_admin_propose_cooptation`

```sql
CREATE OR REPLACE FUNCTION public.fn_network_admin_propose_cooptation(
    p_user_id uuid,
    p_motivation text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_proposal_id uuid;
    v_caller_id uuid := auth.uid();
BEGIN
    -- Garde 1 : l'appelant doit être admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can propose cooptation';
    END IF;
    
    -- Garde 2 : la personne proposée ne doit pas déjà être admin réseau actif
    IF EXISTS (
        SELECT 1 FROM network_administrators 
        WHERE user_id = p_user_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'already_admin: this person is already an active network administrator';
    END IF;
    
    -- Garde 3 : pas de proposition en cours pour cette personne
    IF EXISTS (
        SELECT 1 FROM network_administrator_cooptation_proposals
        WHERE proposed_user_id = p_user_id AND status = 'open'
    ) THEN
        RAISE EXCEPTION 'proposal_exists: an open proposal already exists for this person';
    END IF;
    
    -- Garde 4 : motivation non vide
    IF length(trim(coalesce(p_motivation, ''))) < 20 THEN
        RAISE EXCEPTION 'motivation_too_short: motivation must be at least 20 characters';
    END IF;
    
    -- Création de la proposition
    INSERT INTO network_administrator_cooptation_proposals
        (proposed_user_id, proposed_by, motivation)
        VALUES (p_user_id, v_caller_id, p_motivation)
        RETURNING id INTO v_proposal_id;
    
    -- Vote automatique favorable du proposeur
    INSERT INTO network_administrator_cooptation_votes
        (proposal_id, voter_user_id, vote, rationale)
        VALUES (v_proposal_id, v_caller_id, 'favorable', 'Proposeur, vote implicite');
    
    -- Audit
    INSERT INTO network_administrator_audit (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (p_user_id, 'cooptation_proposed', v_caller_id, p_user_id, 
                jsonb_build_object('proposal_id', v_proposal_id, 'motivation', p_motivation));
    
    -- Notification (dispatch vers Edge Function — réutilise pattern team.* events)
    PERFORM fn_team_notify_event('network.cooptation_proposed', 
        jsonb_build_object('proposal_id', v_proposal_id, 'proposed_user_id', p_user_id));
    
    RETURN v_proposal_id;
END;
$$;
```

### 3.3 RPC `fn_network_admin_vote_cooptation`

```sql
CREATE OR REPLACE FUNCTION public.fn_network_admin_vote_cooptation(
    p_proposal_id uuid,
    p_vote text,
    p_rationale text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_proposal record;
BEGIN
    -- Garde 1 : l'appelant doit être admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can vote';
    END IF;
    
    -- Garde 2 : le vote doit être valide
    IF p_vote NOT IN ('favorable', 'opposed', 'abstain') THEN
        RAISE EXCEPTION 'invalid_vote: vote must be favorable, opposed, or abstain';
    END IF;
    
    -- Garde 3 : la proposition doit exister et être ouverte
    SELECT * INTO v_proposal FROM network_administrator_cooptation_proposals
        WHERE id = p_proposal_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'proposal_not_found';
    END IF;
    
    IF v_proposal.status <> 'open' THEN
        RAISE EXCEPTION 'proposal_closed: proposal is no longer open (status=%)', v_proposal.status;
    END IF;
    
    IF v_proposal.expires_at < now() THEN
        RAISE EXCEPTION 'proposal_expired';
    END IF;
    
    -- Garde 4 : on ne vote pas sur soi-même
    IF v_proposal.proposed_user_id = v_caller_id THEN
        RAISE EXCEPTION 'self_vote_forbidden: you cannot vote on your own cooptation';
    END IF;
    
    -- Vote (UPSERT : on peut changer son vote tant que la proposition est ouverte)
    INSERT INTO network_administrator_cooptation_votes 
        (proposal_id, voter_user_id, vote, rationale, voted_at)
        VALUES (p_proposal_id, v_caller_id, p_vote, p_rationale, now())
    ON CONFLICT (proposal_id, voter_user_id) 
    DO UPDATE SET vote = EXCLUDED.vote, rationale = EXCLUDED.rationale, voted_at = now();
    
    -- Audit
    INSERT INTO network_administrator_audit (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (v_proposal.proposed_user_id, 'cooptation_voted', v_caller_id, v_proposal.proposed_user_id, 
                jsonb_build_object('proposal_id', p_proposal_id, 'vote', p_vote));
    
    -- Le trigger trg_check_cooptation_completion s'occupe du reste
END;
$$;
```

### 3.4 Trigger de complétion automatique

```sql
CREATE OR REPLACE FUNCTION public.trg_check_cooptation_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_proposal record;
    v_total_admins integer;
    v_favorable_votes integer;
    v_opposed_votes integer;
    v_voter_ids uuid[];
BEGIN
    -- Récupère la proposition
    SELECT * INTO v_proposal FROM network_administrator_cooptation_proposals
        WHERE id = NEW.proposal_id;
    
    -- Comptes : admins actifs (hors proposé)
    SELECT count(*) INTO v_total_admins FROM network_administrators
        WHERE status = 'active' AND user_id <> v_proposal.proposed_user_id;
    
    -- Votes favorables et opposés
    SELECT 
        count(*) FILTER (WHERE vote = 'favorable'),
        count(*) FILTER (WHERE vote = 'opposed'),
        array_agg(voter_user_id) FILTER (WHERE vote = 'favorable')
    INTO v_favorable_votes, v_opposed_votes, v_voter_ids
    FROM network_administrator_cooptation_votes
    WHERE proposal_id = NEW.proposal_id;
    
    -- Cas 1 : un opposé → veto, proposition rejetée
    IF v_opposed_votes > 0 THEN
        UPDATE network_administrator_cooptation_proposals
            SET status = 'rejected', completed_at = now()
            WHERE id = NEW.proposal_id;
        
        INSERT INTO network_administrator_audit (user_id, event_type, target_user_id, metadata)
            VALUES (v_proposal.proposed_user_id, 'cooptation_rejected', v_proposal.proposed_user_id, 
                    jsonb_build_object('proposal_id', NEW.proposal_id, 'opposed_count', v_opposed_votes));
        
        PERFORM fn_team_notify_event('network.cooptation_rejected', 
            jsonb_build_object('proposal_id', NEW.proposal_id));
        
        RETURN NEW;
    END IF;
    
    -- Cas 2 : tous les admins actifs ont voté favorable → cooptation effective
    IF v_favorable_votes >= v_total_admins THEN
        -- Insertion dans network_administrators
        INSERT INTO network_administrators 
            (user_id, status, coopted_at, coopted_by_unanimity_of)
            VALUES (v_proposal.proposed_user_id, 'active', now(), v_voter_ids);
        
        -- Clôture de la proposition
        UPDATE network_administrator_cooptation_proposals
            SET status = 'completed', completed_at = now()
            WHERE id = NEW.proposal_id;
        
        INSERT INTO network_administrator_audit (user_id, event_type, target_user_id, metadata)
            VALUES (v_proposal.proposed_user_id, 'cooptation_completed', v_proposal.proposed_user_id, 
                    jsonb_build_object('proposal_id', NEW.proposal_id, 'voters', v_voter_ids));
        
        PERFORM fn_team_notify_event('network.cooptation_completed', 
            jsonb_build_object('proposal_id', NEW.proposal_id, 'new_admin_user_id', v_proposal.proposed_user_id));
    END IF;
    
    -- Cas 3 : votes encore manquants → on attend
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_cooptation_completion_after_vote
AFTER INSERT OR UPDATE ON network_administrator_cooptation_votes
FOR EACH ROW
EXECUTE FUNCTION trg_check_cooptation_completion();
```

### 3.5 Cas particulier : premier administrateur

Le système suppose au moins un administrateur réseau pour qu'il y ait cooptation. Le **premier administrateur** ne peut pas être coopté (il n'y a personne pour voter). Solution :

- À la migration initiale, on insère manuellement la (les) première(s) ligne(s) dans `network_administrators` avec `coopted_by_unanimity_of = ARRAY[]::uuid[]` (vide) et `notes = 'Fondateur·rice du réseau, cooptation hors workflow'`.
- Cette manipulation est tracée dans `network_administrator_audit` avec `event_type='cooptation_completed'` et `metadata.foundational=true`.
- Une fois ce socle posé, toute cooptation ultérieure passe par le workflow normal.

### 3.6 Retrait

Deux modes :

**Auto-retrait** (`fn_network_admin_self_remove`) : un administrateur réseau peut quitter ses fonctions à tout moment, sans l'accord des autres. C'est un acte unilatéral. Garde-fou : s'il est le dernier, transition en `pending_removal` avec alerte aux coordenadores des biblios pour mise en place d'un nouveau processus de cooptation.

**Retrait collectif** (`fn_network_admin_request_removal`) : pour retirer quelqu'un sans son consentement, il faut l'unanimité des autres administrateurs actifs (même processus que la cooptation, en miroir).

Ces RPC sont décrites en annexe technique mais ne sont pas le cœur de la spec.

---

## 4. Mapping des modifications nécessaires

### 4.1 Fonctions à remplacer (table de correspondance)

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

### 4.2 Vues à modifier

| Vue | Modification |
|---|---|
| `api.library_circulation_stats` | Patch déjà en partie fait (paquet 22). Le compteur `librarians_active` reste `librarian + coordenador + administrador` pendant la coexistence ; en phase finale, `administrador` est retiré du ARRAY et on documente que ce compteur ne couvre que le staff local. Les admins réseau sont comptés séparément ailleurs (cf. nouvelle vue `api.network_overview`). |
| `api.my_access` | Doit consolider `network_administrators` ET `user_library_memberships` pour `can_access_painel` et `can_access_catalogacao`. Réécriture conséquente : voir §5.2. |

### 4.3 Nouvelles vues à créer

| Vue | Rôle |
|---|---|
| `api.network_administrators_public_v1` | Liste publique-réseau des admins réseau actifs (pour /rede onglet Administrateurs). Filtre sur status='active'. RLS authenticated. |
| `api.network_overview` | Indicateurs réseau globaux : nombre d'admins, propositions en cours, etc. |
| `api.my_network_admin_status` | Pour l'appelant courant : suis-je admin réseau actif ? Statut, date de cooptation, etc. |

### 4.4 RLS à modifier

Les 22 policies identifiées dans l'audit du 11/05 se répartissent en trois catégories :

**Catégorie A — « staff local + admin réseau » (15 policies)** : doivent basculer sur `user_can_act_as_staff_on_library(library_id)`.

Tables concernées : `author_translations`, `libraries`, `library_retention_policies` (×2), `library_service_state` (×3), `painel_internal_tasks` (×4), `painel_internal_task_invites`, `painel_internal_task_invitation_outbox`, `painel_internal_task_notification_outbox`, `storage.objects` (privacy ×3).

Exemple de bascule pour `library_service_state_update_team` :

```sql
-- AVANT
USING (EXISTS ( SELECT 1
   FROM user_library_memberships m
  WHERE ((m.user_id = auth.uid()) 
    AND (m.library_id = library_service_state.library_id) 
    AND (m.status = 'active'::text) 
    AND (lower(m.role) = ANY (ARRAY['librarian'::text, 'coordenador'::text, 'administrador'::text])))))

-- APRÈS
USING (user_can_act_as_staff_on_library(library_service_state.library_id))
```

**Catégorie B — « engagement politique de la biblio » (4 policies)** : doivent basculer sur `user_can_engage_library(library_id)`.

Tables concernées : `library_membership_rules`, `library_retention_policies` (version modify), `membership_payments` (×2), `storage.objects` (privacy modify ×3).

**Catégorie C — « administrateur réseau pur » (1 policy)** : `ulm_select_all_for_administrador` doit basculer sur `fn_caller_is_network_admin()`.

---

## 5. Plan d'implémentation par paquets

La stratégie de coexistence longue (sem./mois) permet de découper le chantier en paquets autonomes qui peuvent être commités et déployés séparément. **Aucune phase ne casse la prod.**

### 5.1 Paquet A — Infrastructure (DB seulement, pas de bascule)

**Objectif** : poser les tables, helpers et triggers sans toucher aux consommateurs existants.

**Contenu** :
1. Création de `network_administrators`, `network_administrator_audit`, `network_administrator_cooptation_proposals`, `network_administrator_cooptation_votes`.
2. Création des helpers `fn_caller_is_network_admin()`, `user_can_act_as_staff_on_library()`, `user_can_engage_library()`.
3. Création du trigger `trg_check_cooptation_completion`.
4. Création des RPC `fn_network_admin_propose_cooptation`, `fn_network_admin_vote_cooptation`, `fn_network_admin_self_remove`, `fn_network_admin_request_removal`.
5. Création des vues `api.network_administrators_public_v1`, `api.my_network_admin_status`.
6. RLS sur toutes les nouvelles tables.
7. i18n des nouveaux events `network.cooptation_*` × 6 locales (~12 chaînes militantes).
8. Handler Edge Function pour les nouveaux events réseau.

**Impact prod** : zéro. Tout est créé en parallèle, rien n'est branché.

**Test de validation** : insertion manuelle d'une première ligne fondatrice (toi), vérification que les helpers retournent les bonnes valeurs pour ton compte.

### 5.2 Paquet B — Migration de données et réécriture de `api.my_access`

**Objectif** : faire vivre la nouvelle table en cohérence avec l'ancien rôle, sans encore basculer les consommateurs.

**Contenu** :
1. Migration des lignes `user_library_memberships.role='administrador'` vers `network_administrators` (dans ton cas, 1 seule ligne).
2. Les lignes sont laissées dans `user_library_memberships` avec un nouveau status `migrated_to_network` (ajout au CHECK) pour ne rien casser dans l'immédiat.
3. Réécriture de `api.my_access` pour consolider les deux sources :
   - `can_access_painel` = membership staff actif **OU** admin réseau actif
   - `can_access_catalogacao` = idem
4. Modification de `fn_resolve_caller_role_for_library` pour retourner `'network_admin'` si admin réseau (priorité sur le rôle local).

**Impact prod** : compatibilité ascendante. Toutes les RLS qui mentionnent `'administrador'` continuent de fonctionner (la ligne est toujours là), et l'admin réseau a accès via le double mécanisme.

**Test de validation** : tu peux toujours accéder à toutes les biblios via /painel et /rede.

### 5.3 Paquet C — Bascule progressive des RLS

**Objectif** : remplacer les 22 sous-SELECT inline par les nouveaux helpers, une biblio à la fois si nécessaire, mais réaliste : table par table.

**Contenu découpé** :

- **C.1** — RLS sur `painel_internal_tasks` + ses outbox (les plus testées). Bascule sur `user_can_act_as_staff_on_library`.
- **C.2** — RLS sur `library_service_state`, `libraries` (les politiques structurelles).
- **C.3** — RLS sur `library_retention_policies`, `library_membership_rules`, `membership_payments` (les politiques d'engagement).
- **C.4** — RLS sur `storage.objects` (les uploads privacy).
- **C.5** — RLS sur `user_library_memberships` elle-même (la plus délicate, gardée pour la fin).

**Impact prod** : à chaque sous-paquet, validation manuelle des actions concernées. Pas de bascule en masse.

**Test de validation par sous-paquet** : pour chaque table touchée, scénario test concret (créer une tâche, modifier service_state, etc.) en tant qu'admin réseau **et** en tant que staff local.

### 5.4 Paquet D — Refactorisation des RPC et helpers `can_manage_*`

**Objectif** : nettoyer les helpers `can_manage_*` pour qu'ils utilisent les nouveaux centralisés.

**Contenu** :
1. Audit du code de chaque `can_manage_*` (5 fonctions).
2. Refactorisation pour appel direct à `user_can_engage_library` ou `user_can_act_as_staff_on_library`.
3. Modification de `fn_team_*` pour refuser les opérations sur les admins réseau (qui passent par les RPC dédiées).
4. Suppression de `fn_team_promote_to_administrador` (replacée par `fn_network_admin_propose_cooptation`).

**Impact prod** : faible, surtout du nettoyage.

### 5.5 Paquet E — UI : nouvelle section /rede

**Objectif** : exposer les nouvelles fonctionnalités aux administrateurs réseau.

**Contenu** :
1. Onglet « Administrateurs » de /rede : remplacement de l'actuel `AdminsPanel` qui faisait UPDATE direct par un panneau qui consomme `network_administrators` + propose le bouton « Proposer une cooptation ».
2. Nouvel onglet « Propositions en cours » : liste des `network_administrator_cooptation_proposals` ouvertes, votes en attente, action « voter ».
3. Composant `NetworkAdminStatusBadge` : affiche le statut admin réseau d'un user dans /biblioteca, /panel, etc.
4. Mise à jour des labels i18n militants.

**Impact prod** : UX, pas de risque DB.

### 5.6 Paquet F — Phase finale (à n'exécuter qu'après stabilisation)

**Objectif** : retirer le rôle `administrador` du schéma `user_library_memberships`.

**Contenu** :
1. DELETE des lignes `user_library_memberships.role='administrador'` (déjà migrées, on les supprime).
2. ALTER CHECK pour retirer `'administrador'` du domaine de `role`.
3. Suppression du wrapper `fn_caller_is_administrador()` (deprecated).
4. Suppression du wrapper sur `user_has_library_staff_role` (devenu simple alias).
5. Mise à jour de la spec gouvernance des rôles (cohérence sémantique).
6. Documentation de la nouvelle architecture dans le Livre Blanc.

**Impact prod** : aucun si les paquets A à E ont été correctement appliqués et testés. La phase est purement cosmétique à ce stade.

**Pré-requis pour exécution** :
- Au moins 30 jours d'observation sans incident depuis le paquet E.
- Aucune référence à `'administrador'` dans le code frontend.
- Aucune référence à `'administrador'` dans les helpers DB (vérifié par requête `pg_get_functiondef`).
- Aucune RLS résiduelle qui mentionne `'administrador'` (vérifié par requête `pg_policies`).

---

## 6. Implications UI détaillées

### 6.1 `LibraryContext`

Aujourd'hui, `LibraryContext` expose un `role` calculé à partir du membership de l'utilisateur sur la biblio courante. Demain, il doit aussi exposer :

- `isNetworkAdmin: boolean` — l'utilisateur est-il administrateur réseau ?
- `effectiveRole: 'reader' | 'librarian' | 'coordenador' | 'network_admin' | null` — le rôle effectif (network_admin prime sur le rôle local pour les autorisations transverses).
- `hasStaffAccess: boolean` — calculé via `user_can_act_as_staff_on_library`.

**Migration progressive** : ajouter les nouveaux champs sans retirer `role`. Les composants existants continuent de fonctionner. Les nouveaux composants utilisent les nouveaux champs.

### 6.2 Badges et étiquettes

- Aujourd'hui : un seul badge `<RoleBadge role={role} />` qui affiche pt-BR « Administrador(a/e) » si role='administrador'.
- Demain : deux badges distincts possibles : `<LocalRoleBadge>` pour le rôle dans la biblio courante (Leitor·a·e / Bibliotecária·o / Coordenadora·or), et `<NetworkAdminBadge>` pour le statut administrateur réseau. Les deux peuvent s'afficher en même temps (ex. tu serais « Coordenador BLMF » + « Admin AnarBib »).

### 6.3 /rede onglet « Administrateurs »

**Avant** : `AdminsPanel` actuel, qui faisait UPDATE direct sur `user_library_memberships.role`.

**Après** :
- Liste des administrateurs réseau actifs (consommation de `api.network_administrators_public_v1`).
- Bouton « Proposer une cooptation » → modal avec champ email + champ motivation (>=20 chars). Appel à `fn_network_admin_propose_cooptation`.
- Section « Propositions en cours » : liste des proposals en status='open', avec bouton « Voter favorable / Voter contre / S'abstenir » → appel à `fn_network_admin_vote_cooptation`.
- Section « Historique des cooptations et retraits » : consommation de `network_administrator_audit`.

### 6.4 /biblioteca onglet « Equipe »

Le `TeamPanel scope="library"` reste centré sur les memberships locaux (`librarian`, `coordenador`). Les administrateurs réseau ne sont pas listés ici, **sauf** s'ils ont aussi un membership staff local sur cette biblio.

### 6.5 Notifications mail militantes

Nouveaux events à internationaliser × 6 locales :

- `network.cooptation_proposed` (mail aux admins existants : « Une cooptation est proposée, ton vote est attendu »)
- `network.cooptation_voted` (mail au proposeur quand un vote est enregistré)
- `network.cooptation_completed` (mail à la personne cooptée + récap aux admins)
- `network.cooptation_rejected` (mail au proposeur + au proposé, avec rationale des opposants si fournie)
- `network.cooptation_expired` (mail aux admins quand une proposition atteint 30 jours sans unanimité)
- `network.self_removal` (mail aux admins quand quelqu'un se retire)
- `network.removal_completed` (mail à la personne retirée + récap aux autres)
- `network.foundational_admin_added` (event spécial pour la migration initiale, mail informatif)

---

## 7. Risques et contre-mesures

### 7.1 Risque : perte d'accès accidentelle pendant la bascule

**Scénario** : un administrateur perd ses droits sur une biblio parce qu'une RLS a été basculée sur le nouveau helper avant que sa ligne soit migrée dans `network_administrators`.

**Contre-mesure** : le paquet B migre les données **avant** que le paquet C ne touche aux RLS. Pendant toute la coexistence, les RLS répondent vrai si soit l'ancien membership administrador existe, soit la nouvelle ligne network_administrators existe. Pas de fenêtre de perte d'accès.

### 7.2 Risque : duplication de logique pendant la coexistence

**Scénario** : pendant les semaines/mois de coexistence, on peut avoir des incohérences entre la ligne `user_library_memberships.role='administrador'` et la ligne `network_administrators` (ex. l'un est passé à status='inactive' mais pas l'autre).

**Contre-mesure** : pendant le paquet B, un trigger de cohérence vérifie qu'une mise à jour de l'un déclenche la même mise à jour de l'autre. Ce trigger est retiré au paquet F.

### 7.3 Risque : la cooptation à l'unanimité bloque le réseau

**Scénario** : un administrateur réseau devient inactif (ne se connecte plus) mais reste en status='active'. Toute nouvelle cooptation est bloquée parce qu'il ne vote pas.

**Contre-mesure** : ajouter un cron `pg_cron` qui passe automatiquement à `status='inactive'` tout admin réseau dont `last_seen_at < now() - interval '6 months'`. Les admins inactifs ne sont pas comptés dans l'unanimité requise.

### 7.4 Risque : perte du dernier administrateur

**Scénario** : le dernier admin réseau se retire (`fn_network_admin_self_remove`). Plus personne ne peut coopter.

**Contre-mesure** : le RPC `fn_network_admin_self_remove` détecte ce cas et passe l'admin en `status='pending_removal'` avec une carence de 30 jours pendant lesquels il peut revenir, OU une nouvelle cooptation peut être amorcée par les coordenadores des biblios actives (workflow de récupération de réseau, à spécifier dans une spec ultérieure).

### 7.5 Risque : abus de l'administrateur réseau qui peut tout faire partout

**Scénario** : un administrateur réseau utilise son droit d'intervention opérationnelle pour modifier des données d'une biblio sans concertation avec son staff local.

**Contre-mesure** : **traçabilité maximale**. Toutes les actions des administrateurs réseau sur des biblios qui ne sont pas la leur sont auditées dans une table `network_admin_cross_library_actions` (à spécifier dans le paquet C.5). Le staff local de la biblio est notifié par mail. Le mécanisme protège politiquement les biblios sans empêcher techniquement l'action.

---

## 8. Cas particulier : ton membership BLMF actuel

Au démarrage du chantier, ton membership `coordenador` BLMF du 07/05/2026 sera nettoyé manuellement (paquet 23bis évoqué hier soir, finalement intégré ici).

**Question politique à trancher avant le paquet B** :

Tu es actuellement :
- `administrador` BLMF du 24/03/2026 (avant la spec gouvernance des rôles)
- `coordenador` BLMF du 07/05/2026 (effet de bord)

Une fois la séparation faite, tu deviendras :
- **Option α** : `coordenador` BLMF (rôle local effectif) + admin réseau (rôle transverse). Cohérent si tu animes vraiment la BLMF au quotidien.
- **Option β** : pas de rôle local + admin réseau. Cohérent si la BLMF est animée par d'autres et que tu n'es là qu'en tant qu'administrateur AnarBib.
- **Option γ** : `librarian` BLMF + admin réseau. Tu fais des permanences mais tu n'engages pas politiquement la biblio (les décisions de règlement etc. sont prises par d'autres coordenadores).

Cette décision est à prendre avec les autres coordenadores de la BLMF, hors du présent document.

---

## 9. Calendrier prévisionnel

| Paquet | Durée estimée | Dépendances |
|---|---|---|
| A — Infrastructure | 1 session intensive (~6h) | Aucune |
| B — Migration données + my_access | 1 session (~4h) | A |
| C — Bascule RLS (sous-paquets C.1 à C.5) | 3-5 sessions sur 2-4 semaines | B |
| D — Refactorisation RPC | 1-2 sessions | C complet |
| E — UI | 2-3 sessions | A + B + propositions accessibles |
| F — Phase finale | 1 session (essentiellement vérification) | E + 30j d'observation |

**Total** : environ 9-13 sessions de travail, étalées sur 4-8 semaines avec coexistence en production permanente.

---

## 10. Décisions ouvertes (à trancher en cours de chantier)

Certains points sont laissés ouverts intentionnellement, pour décision politique ou technique en cours d'implémentation.

**Q1** — Les administrateurs réseau peuvent-ils être membres staff (`librarian`, `coordenador`) de plusieurs biblios à la fois ? (le système l'autorise techniquement, c'est une question politique)

**Q2** — Doit-on créer une table `network_administrator_cross_library_actions_log` au paquet C.5 ou est-ce trop intrusif ?

**Q3** — Quel délai d'expiration pour les propositions de cooptation : 30 jours (proposé) ou 14 jours pour forcer une décision rapide ?

**Q4** — Le mail au proposé en cas de rejet de cooptation : on transmet la rationale des opposants ou on garde l'opposition anonyme ?

**Q5** — La carence avant retrait définitif d'un administrateur retiré collectivement : immédiate, 7 jours, 30 jours ?

**Q6** — On notifie le staff local d'une biblio quand un admin réseau y fait une action ? Mail immédiat ou digest hebdomadaire ?

---

## Annexes

### Annexe A — Glossaire

- **Administrateur réseau** (alias *network admin*, *administrador AnarBib*) : personne membre du réseau de coordination AnarBib, avec autorité transverse sur toutes les biblios.
- **Staff local** : ensemble des `librarian` + `coordenador` actifs d'une biblio donnée.
- **Cooptation** : processus d'ajout d'une nouvelle personne au réseau d'administrateurs, à l'unanimité des administrateurs en place.
- **Engagement politique** : capacité de modifier les paramètres structurels d'une biblio (règlement, politique de circulation, identité). Réservé aux `coordenador` et aux administrateurs réseau.
- **Intervention opérationnelle** : capacité de réaliser des actions quotidiennes (prêt, retour, réservation au nom d'un lecteur). Réservé au staff local et aux administrateurs réseau.

### Annexe B — Requêtes d'audit utilisées pour la rédaction

Voir le bilan de session du 11/05/2026 : 4 requêtes d'inventaire (fonctions, RLS, vues, données) qui ont fondé la cartographie complète du chantier.

### Annexe C — Références internes

- `docs/spec-gouvernance-roles.md` (5/05/2026) : sémantique des rôles locaux, transitions de status. Ce chantier en est le prolongement logique.
- Migration `2026_05_05_user_can_manage_library_remove_phantom_roles.sql` : nettoyage des rôles fantômes du 5/05 sur lequel ce chantier s'appuie.
- Paquet 22 (11/05/2026) : fix de `api.library_circulation_stats` qui a révélé la nécessité de cette séparation.

---

*Fin du document. Spec ouverte à amendement.*
