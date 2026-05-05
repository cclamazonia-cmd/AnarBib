# Spec — Workflow de réservation

**Statut** : Cadrée le 04/05/2026, en attente d'implémentation
**Cible** : Bologna FICEDL, septembre 2026
**Auteur·rices** : Xavier (spec et arbitrages) + Claude (rédaction, diagnostic)
**Dépendances** : aucune (peut être implémenté indépendamment des specs validation physique et migration de compte)

---

## Sommaire

1. [Contexte et objectif](#1-contexte-et-objectif)
2. [Diagnostic préalable](#2-diagnostic-préalable)
3. [Modèle conceptuel](#3-modèle-conceptuel)
4. [États et transitions](#4-états-et-transitions)
5. [Schéma DB](#5-schéma-db)
6. [RPCs et triggers](#6-rpcs-et-triggers)
7. [Mails et notifications](#7-mails-et-notifications)
8. [Interfaces utilisateur](#8-interfaces-utilisateur)
9. [Migration des données existantes](#9-migration-des-données-existantes)
10. [Hors scope](#10-hors-scope)
11. [Checklist d'implémentation](#11-checklist-dimplémentation)
12. [Tests d'acceptation](#12-tests-dacceptation)

---

## 1. Contexte et objectif

### Contexte

Le système de réservation AnarBib repose sur trois tables principales :
- `reservas_v2` : réservation parente (1 lecteur·rice + 1 biblio + n livres)
- `reserva_linhas_v2` : lignes individuelles (1 livre = 1 ligne, parce qu'une réservation peut porter sur plusieurs livres)
- `reserva_item_workflow_v2` : état courant du workflow par ligne

Aujourd'hui, le système souffre d'un **workflow simplifié à l'extrême** : seuls 4 stages terminaux sont effectivement utilisés (`cancelada_leitor`, `cancelada_biblioteca`, `retirada_efetivada`, `liberada_para_circulacao`). Les stages intermédiaires (`solicitada`, `em_preparacao`, `retirada_agendada`, `pronta_para_retirada`) **ne sont jamais écrits en DB**, alors que toute l'infrastructure technique (triggers, fonction de dispatch HTTP vers notify-event, code Edge Function) est déjà en place.

### Objectif

Implémenter le workflow complet à 6 états + branches latérales, avec :
- Transitions correctement écrites en DB
- Mails contextuels par transition (ce que l'infra DB sait déjà faire)
- UI staff dans `/painel` pour effectuer les transitions
- UI lecteur dans `/conta` pour suivre l'état et confirmer/refuser les créneaux
- Configuration par biblio (timeouts, mails individuellement désactivables)
- Détection automatique des no-shows
- Conversion atomique `retirada_efetivada` → emprunt actif

### Principes directeurs

> 1. **Souveraineté des biblios** sur leur configuration (timeouts, mails désactivables individuellement, modes de retrait).
> 2. **Souveraineté du lecteur** sur sa propre réservation (peut toujours annuler avant retrait effectif).
> 3. **Atomicité des opérations critiques** (conversion en emprunt = transaction unique).
> 4. **Transparence** : timeline visuelle pour le lecteur, journal d'audit pour la biblio.

---

## 2. Diagnostic préalable

### Découvertes de la session 04/05/2026

1. **Triggers DB en place et fonctionnels** :
   - `trg_notify_reserva_workflow` sur INSERT/UPDATE de `reserva_item_workflow_v2`
   - Appelle `fn_dispatch_circulation_notify_event` qui fait un POST HTTP vers notify-event Edge Function
   - Mapping correct des `workflow_stage` → events : `re-retirada_agendada`→`retirada_reagendada`, `nao_retirada`→`reserva_nao_retirada`, etc.

2. **Edge Function notify-event en place** :
   - `supabase/functions/_shared/core/dispatch.ts` : route correctement les events workflow
   - `supabase/functions/_shared/domain/reservas.ts` : génère les mails par event

3. **Cause racine** : le frontend (et les RPCs côté Supabase) **ne déclenchent jamais** les transitions intermédiaires. Probablement parce que :
   - Pas d'UI staff pour passer une réservation de `solicitada` à `em_preparacao` ou `retirada_agendada`
   - Pas de RPC dédiée à chaque transition (juste des UPDATE directs vers les états terminaux)
   - Pas de cron pour `retirada_no_show`

4. **Flag `reservation_workflow_enabled`** : présent dans `library_notification_policies` (true par défaut sur les 2 biblios actives). Lu côté Edge Function mais ne semble pas filtrer activement.

### Inventaire actuel

```
reserva_item_workflow_v2 — distribution actuelle :
- cancelada_leitor : 5
- retirada_efetivada : 3
- cancelada_biblioteca : 1
- liberada_para_circulacao : 1
- TOUS les autres stages : 0

Triggers actuels sur reservas_v2 :
- trg_reservas_v2_touch_updated_at (juste utilitaire updated_at)

Triggers sur reserva_item_workflow_v2 :
- trg_notify_reserva_workflow (BIEN PRÉSENT)
- trg_reserva_item_workflow_v2_touch_updated_at
```

---

## 3. Modèle conceptuel

### Cycle de vie d'une réservation

```
                  ┌──────────────────┐
                  │   solicitada     │  ← création par lecteur·rice
                  │   (étape 1)      │
                  └────────┬─────────┘
                           │
                           │  staff prend en charge (optionnel)
                           ▼
                  ┌──────────────────┐
                  │  em_preparacao   │  ← optionnel, sautable
                  │   (étape 2)      │
                  └────────┬─────────┘
                           │
                           │  staff fixe le retrait
                           ├──────────────────┐
                           ▼                  ▼
              ┌──────────────────┐   ┌──────────────────┐
              │ retirada_agendada│   │retirada_a_combinar│
              │   (étape 3a)     │   │   (étape 3b)      │
              │ pickup_scheduled │   │ pickup_scheduled  │
              │ obligatoire      │   │ flou (J+7 indic.) │
              └────┬─────────────┘   └────┬──────────────┘
                   │                      │
                   │  lecteur peut accepter│ ou refuser
                   │  (pickup_reply_status)│
                   │                      │
                   │  refus → biblio reagende
                   │  (re-retirada_agendada)
                   │                      │
                   ▼                      ▼
                  ┌──────────────────────────┐
                  │  pronta_para_retirada    │
                  │   (étape 4)              │
                  │   livre physiquement     │
                  │   prêt à l'accueil       │
                  └──────────┬───────────────┘
                             │
                             │  lecteur vient
                             ▼
                  ┌──────────────────────────┐
                  │   retirada_efetivada     │  ← ÉTAT FINAL
                  │   (étape 5)              │     conversion en
                  │                          │     empréstimo via
                  │                          │     RPC atomique
                  └──────────────────────────┘
```

### États d'échec / branches latérales

À tout moment avant `retirada_efetivada` :

| État | Déclencheur | Source |
|---|---|---|
| `cancelada_leitor` | Lecteur·rice annule depuis `/conta` | Lecteur·rice |
| `cancelada_biblioteca` | Biblio annule (raison obligatoire si stage ≥ retirada_agendada) | Coordenador |
| `expirada` | `solicitada` dépasse `reservation_solicitada_timeout_days` | Job pg_cron |
| `retirada_no_show` (= `nao_retirada`) | Lecteur·rice n'est pas venu·e après pickup_scheduled_for + `reservation_no_show_timeout_hours` | Job pg_cron OU staff manuellement |
| `re-retirada_agendada` | Suite à refus lecteur (pickup_reply_status='recusado_leitor'), biblio repropose | Coordenador |
| `liberada_para_circulacao` | Suite à no_show ou cancelada_biblioteca, livre repasse en circulation | Trigger automatique |

### Acteurs

- **Lecteur·rice** : crée la réservation (`solicitada`), confirme/refuse les créneaux (`pickup_reply_status`), annule à tout moment avant `retirada_efetivada`.
- **Librarian** (≥) : peut effectuer les transitions `solicitada` → `em_preparacao` → `retirada_agendada/a_combinar` → `pronta_para_retirada`. Peut marquer `retirada_efetivada` (avec création emprunt) et `retirada_no_show` (manuel).
- **Coordenador** (≥) : tout ce qu'un librarian fait, plus `cancelada_biblioteca` (avec raison) à n'importe quelle étape.
- **Job pg_cron** : déclenche `expirada` et `retirada_no_show` automatiquement.

---

## 4. États et transitions

### États possibles (workflow_stage)

| Stage | Description | Terminal ? | UI lecteur | UI staff |
|---|---|---|---|---|
| `solicitada` | Lecteur a créé la réservation | non | "Demande envoyée" | "À traiter" |
| `em_preparacao` | Biblio prépare (sortie des étagères, vérification) | non | "En préparation" | "En cours" |
| `retirada_agendada` | Créneau de retrait fixé (date précise) | non | "Retrait prévu le X" + boutons | "Retrait fixé" |
| `retirada_a_combinar` | Retrait à voir au cas par cas (date butoir) | non | "Retrait à combiner avant le X" | "À combiner" |
| `re-retirada_agendada` | Créneau reprogrammé | non | "Nouveau créneau le X" + boutons | "Reagendée" |
| `pronta_para_retirada` | Livre prêt à l'accueil | non | "Prête, viens la chercher" | "Attente lecteur" |
| `retirada_efetivada` | Lecteur·rice est venu·e | OUI | "Retrait effectué le X (devenu emprunt)" | "Effectuée" |
| `cancelada_leitor` | Lecteur·rice a annulé | OUI | "Vous avez annulé" | "Annulée par lecteur" |
| `cancelada_biblioteca` | Biblio a annulé | OUI | "Annulée par biblio : [raison]" | "Annulée par biblio" |
| `expirada` | Timeout solicitada | OUI | "Expirée par non-prise en charge" | "Expirée" |
| `retirada_no_show` (= `nao_retirada`) | Lecteur·rice non venu·e | OUI | "Non venu·e, livre libéré" | "No-show" |
| `liberada_para_circulacao` | Livre remis en circulation (post-no_show ou cancel) | OUI | (n/a, déjà annulée) | "Livre libéré" |

### Matrice des transitions autorisées

```
DEPUIS                         | TRANSITIONS AUTORISÉES                                     | QUI
-------------------------------|-----------------------------------------------------------|---------
solicitada                     | em_preparacao | retirada_agendada | retirada_a_combinar    | librarian
                               | cancelada_leitor                                          | lecteur
                               | cancelada_biblioteca                                      | coordenador
                               | expirada                                                  | cron
em_preparacao                  | retirada_agendada | retirada_a_combinar                   | librarian
                               | cancelada_leitor                                          | lecteur
                               | cancelada_biblioteca                                      | coordenador
retirada_agendada              | re-retirada_agendada | pronta_para_retirada               | librarian
                               | cancelada_leitor                                          | lecteur
                               | cancelada_biblioteca                                      | coordenador
retirada_a_combinar            | retirada_agendada | re-retirada_agendada                  | librarian
                               | pronta_para_retirada                                      | librarian
                               | cancelada_leitor                                          | lecteur
                               | cancelada_biblioteca                                      | coordenador
re-retirada_agendada           | pronta_para_retirada | re-retirada_agendada               | librarian
                               | cancelada_leitor                                          | lecteur
                               | cancelada_biblioteca                                      | coordenador
pronta_para_retirada           | retirada_efetivada (RPC atomique avec INSERT emprestimos) | librarian
                               | retirada_no_show                                          | librarian | cron
                               | cancelada_leitor                                          | lecteur
                               | cancelada_biblioteca                                      | coordenador
retirada_no_show               | liberada_para_circulacao (auto-déclenchée par trigger)    | trigger
                               | (état terminal après cette transition)                    |
cancelada_*, expirada,         | (états terminaux, aucune transition possible)             |
retirada_efetivada,            |                                                           |
liberada_para_circulacao       |                                                           |
```

### Cas particulier : `pickup_reply_status`

Indépendant du `workflow_stage`. Quand le stage est `retirada_agendada` ou `re-retirada_agendada`, le lecteur peut répondre via la colonne `pickup_reply_status` :
- `confirmado_leitor` : "OK, je peux à ce créneau"
- `recusado_leitor` : "Non, je ne peux pas"

Le trigger DB `trg_notify_reserva_workflow_change` détecte ce changement et envoie le mail correspondant à la biblio. Si refus, la biblio peut alors transitionner vers `re-retirada_agendada` avec un nouveau `pickup_scheduled_for`.

---

## 5. Schéma DB

### Tables existantes (rappel)

```sql
public.reservas_v2 (
  id bigserial PRIMARY KEY,
  user_id uuid,
  library_id uuid,
  notes text,
  status_global text DEFAULT 'ativa', -- ativa | finalizada | cancelada
  created_at, updated_at
);

public.reserva_linhas_v2 (
  reserva_id bigint, line_no int,
  -- ... (référence vers le livre, exemplaire, etc.)
);

public.reserva_item_workflow_v2 (
  id bigserial PRIMARY KEY,
  reserva_id bigint,
  line_no int,
  workflow_stage text,
  workflow_note text,
  pickup_scheduled_for timestamptz,
  pickup_reply_status text, -- null | confirmado_leitor | recusado_leitor
  pickup_reply_note text,
  pickup_reply_at timestamptz,
  updated_at, updated_by uuid,
  UNIQUE (reserva_id, line_no)
);
```

### Modifications à apporter

#### 1. Contraintes CHECK sur workflow_stage

```sql
ALTER TABLE public.reserva_item_workflow_v2
  ADD CONSTRAINT chk_workflow_stage CHECK (workflow_stage IN (
    'solicitada',
    'em_preparacao',
    'retirada_agendada',
    'retirada_a_combinar',
    're-retirada_agendada',
    'pronta_para_retirada',
    'retirada_efetivada',
    'retirada_no_show',
    'nao_retirada',  -- alias historique de retirada_no_show, à conserver pour compat
    'cancelada_leitor',
    'cancelada_biblioteca',
    'expirada',
    'liberada_para_circulacao'
  ));

ALTER TABLE public.reserva_item_workflow_v2
  ADD CONSTRAINT chk_pickup_scheduled_for_required CHECK (
    workflow_stage NOT IN ('retirada_agendada', 're-retirada_agendada', 'retirada_a_combinar')
    OR pickup_scheduled_for IS NOT NULL
  );
```

#### 2. Nouveaux flags dans `library_notification_policies`

```sql
ALTER TABLE public.library_notification_policies
  ADD COLUMN reservation_solicitada_timeout_days int NOT NULL DEFAULT 14,
  ADD COLUMN reservation_no_show_timeout_hours int NOT NULL DEFAULT 24,

  -- Mails désactivables individuellement (default true = on envoie)
  ADD COLUMN reservation_mail_solicitada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_em_preparacao_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_retirada_agendada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_retirada_a_combinar_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_pronta_para_retirada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_retirada_reagendada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_retirada_no_show_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_expirada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_cancelada_leitor_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_cancelada_biblioteca_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_liberada_para_circulacao_enabled boolean NOT NULL DEFAULT false;
  -- liberada_para_circulacao false par défaut = pas la peine de spammer le lecteur déjà annulé
  -- (option d'activation pour celles qui veulent dire "votre livre est dispo si vous voulez le re-réserver")

-- Constraints raisonnables
ALTER TABLE public.library_notification_policies
  ADD CONSTRAINT chk_solicitada_timeout CHECK (reservation_solicitada_timeout_days BETWEEN 7 AND 60),
  ADD CONSTRAINT chk_no_show_timeout CHECK (reservation_no_show_timeout_hours BETWEEN 12 AND 168);
```

#### 3. Index pour les jobs cron

```sql
-- Pour expiration rapide
CREATE INDEX idx_riw_expiry_check ON public.reserva_item_workflow_v2 (workflow_stage, updated_at)
  WHERE workflow_stage = 'solicitada';

-- Pour no_show rapide
CREATE INDEX idx_riw_no_show_check ON public.reserva_item_workflow_v2 (workflow_stage, pickup_scheduled_for)
  WHERE workflow_stage IN ('pronta_para_retirada', 'retirada_agendada', 're-retirada_agendada');
```

#### 4. Trigger pour `liberada_para_circulacao` automatique post-no_show

```sql
CREATE OR REPLACE FUNCTION public.trg_auto_liberate_after_no_show()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Si on passe en retirada_no_show ou cancelada_biblioteca,
  -- on insert immédiatement un nouvel évènement liberada_para_circulacao
  -- pour que le livre soit dispo en circulation à nouveau.
  IF NEW.workflow_stage IN ('retirada_no_show', 'nao_retirada', 'cancelada_biblioteca') THEN
    -- (logique applicative à définir : faut-il INSERT une nouvelle ligne, ou plutôt
    --  émettre l'event sans changer le stage qui restait sur retirada_no_show ?)
    -- À discuter à l'implémentation : event d'info plutôt que mutation de stage.
    PERFORM fn_dispatch_circulation_notify_event(
      'liberada_para_circulacao',
      NEW.reserva_id,
      jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no))
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_liberate_after_no_show
  AFTER UPDATE ON public.reserva_item_workflow_v2
  FOR EACH ROW
  WHEN (NEW.workflow_stage IS DISTINCT FROM OLD.workflow_stage)
  EXECUTE FUNCTION trg_auto_liberate_after_no_show();
```

**Note d'implémentation** : à raffiner. La sémantique exacte de `liberada_para_circulacao` doit être tranchée — est-ce un nouveau stage (qui remplace `retirada_no_show`), ou un event d'information sans mutation du stage ? Ma proposition : c'est un event d'information distinct du stage final `retirada_no_show`/`cancelada_biblioteca`. Le stage reste celui qui a déclenché la libération.

---

## 6. RPCs et triggers

### RPCs frontend → DB

Une RPC par transition métier, plutôt que des UPDATEs directs. Garantit :
- Validation des transitions (refus si transition illégale)
- Audit trail (updated_by)
- Atomicité (transactions)

```sql
-- Côté lecteur·rice
api.create_reservation(book_id, library_id, notes) -> bigint
  -- Crée reservas_v2 + reserva_linhas_v2 + reserva_item_workflow_v2 (workflow_stage='solicitada')

api.cancel_my_reservation(reserva_id) -> void
  -- Vérifie que c'est bien la réservation du caller
  -- Refuse si workflow_stage = 'retirada_efetivada' (déjà devenue emprunt)
  -- UPDATE workflow_stage = 'cancelada_leitor'

api.confirm_pickup_slot(reserva_id, line_no) -> void
  -- Vérifie ownership
  -- Vérifie workflow_stage IN ('retirada_agendada', 're-retirada_agendada', 'retirada_a_combinar')
  -- UPDATE pickup_reply_status = 'confirmado_leitor', pickup_reply_at = now()

api.refuse_pickup_slot(reserva_id, line_no, reason text) -> void
  -- UPDATE pickup_reply_status = 'recusado_leitor', pickup_reply_note = reason

-- Côté staff (≥ librarian)
api.advance_reservation(reserva_id, line_no, target_stage text, options jsonb) -> void
  -- Vérifie role et que la transition est autorisée depuis stage actuel
  -- UPDATE workflow_stage selon target_stage
  -- Pour retirada_agendada/a_combinar/re-retirada_agendada : pickup_scheduled_for OBLIGATOIRE dans options

api.confirm_pickup_v1(reserva_id, line_no, loan_options jsonb) -> bigint
  -- Atomique : INSERT emprestimos_v2 + reserva_item_workflow_v2.workflow_stage = 'retirada_efetivada'
  -- Retourne l'id du nouvel emprunt

api.mark_no_show(reserva_id, line_no) -> void
  -- Manuel : staff constate que lecteur n'est pas venu
  -- workflow_stage = 'retirada_no_show'

-- Côté coordenador
api.cancel_reservation_as_library(reserva_id, line_no, reason text) -> void
  -- Vérifie role coordenador+
  -- Si stage >= retirada_agendada, reason OBLIGATOIRE (CHECK)
  -- workflow_stage = 'cancelada_biblioteca'
```

### Jobs pg_cron

```sql
-- Job 1 : expiration des solicitada
CREATE OR REPLACE FUNCTION public.fn_expire_solicitada_reservations()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count int := 0;
BEGIN
  -- Pour chaque biblio, on récupère son timeout dans library_notification_policies
  WITH expired AS (
    SELECT riw.reserva_id, riw.line_no
    FROM public.reserva_item_workflow_v2 riw
    JOIN public.reservas_v2 r ON r.id = riw.reserva_id
    JOIN public.library_notification_policies lnp ON lnp.library_id = r.library_id
    WHERE riw.workflow_stage = 'solicitada'
      AND riw.updated_at < (now() - (lnp.reservation_solicitada_timeout_days || ' days')::interval)
  )
  UPDATE public.reserva_item_workflow_v2
  SET workflow_stage = 'expirada', updated_at = now()
  FROM expired
  WHERE reserva_item_workflow_v2.reserva_id = expired.reserva_id
    AND reserva_item_workflow_v2.line_no = expired.line_no;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

SELECT cron.schedule(
  'expire-solicitada-reservations',
  '0 */6 * * *',  -- toutes les 6h
  'SELECT fn_expire_solicitada_reservations()'
);

-- Job 2 : détection no_show
CREATE OR REPLACE FUNCTION public.fn_detect_no_show_reservations()
RETURNS int
-- Similaire : sélectionne les reserva_item_workflow_v2 en pronta_para_retirada/retirada_agendada
-- dont pickup_scheduled_for + reservation_no_show_timeout_hours < now()
-- et passe en workflow_stage = 'retirada_no_show'.
$$;

SELECT cron.schedule(
  'detect-no-show-reservations',
  '0 * * * *',  -- toutes les heures
  'SELECT fn_detect_no_show_reservations()'
);
```

### Trigger DB existant à conserver

`trg_notify_reserva_workflow_change` reste tel quel : il détecte les changements de `workflow_stage` et de `pickup_reply_status`, et envoie l'event à notify-event Edge Function. Pas de modification.

**Petite amélioration possible** : faire que ce trigger consulte le flag `reservation_mail_*_enabled` correspondant avant d'appeler `fn_dispatch_circulation_notify_event`. Si flag = false, skip silencieusement. À implémenter dans la fonction trigger.

---

## 7. Mails et notifications

### Mails par transition

| Transition | Lecteur·rice reçoit | Biblio reçoit | Flag de désactivation |
|---|---|---|---|
| `solicitada` (création) | "Votre réservation est enregistrée" | "Nouvelle réservation à traiter" | `reservation_mail_solicitada_enabled` |
| → `em_preparacao` | "Votre livre est en préparation" | (rien, c'est elle qui agit) | `reservation_mail_em_preparacao_enabled` |
| → `retirada_agendada` | "Retrait prévu le X — confirmer/refuser" | (rien) | `reservation_mail_retirada_agendada_enabled` |
| → `retirada_a_combinar` | "Retrait à combiner avant le X — contacter biblio" | (rien) | `reservation_mail_retirada_a_combinar_enabled` |
| → `re-retirada_agendada` | "Nouveau créneau le X — confirmer/refuser" | (rien) | `reservation_mail_retirada_reagendada_enabled` |
| `pickup_reply` confirmado | (rien) | "Lecteur·rice confirme" | (toujours actif, géré par trigger) |
| `pickup_reply` recusado | (rien) | "Lecteur·rice refuse" | (toujours actif) |
| → `pronta_para_retirada` | "Livre prêt, viens la chercher" | (rien) | `reservation_mail_pronta_para_retirada_enabled` |
| → `retirada_efetivada` | "Retrait effectué, devenu emprunt jusqu'au X" | (rien, sauf `admin_copy_loans_enabled`) | (utilise les mails emprunt) |
| → `retirada_no_show` (auto ou manuel) | "Vous n'êtes pas venu·e, réservation annulée, livre dispo" | "Lecteur·rice no-show" (event critique) | `reservation_mail_retirada_no_show_enabled` |
| → `cancelada_leitor` | "Votre annulation est enregistrée" | (rien, sauf `admin_copy_reservations_enabled`) | `reservation_mail_cancelada_leitor_enabled` |
| → `cancelada_biblioteca` | "Biblio a annulé : [raison]" | (rien) | `reservation_mail_cancelada_biblioteca_enabled` |
| → `expirada` | "Votre réservation a expiré" | "Réservation expirée" (event critique) | `reservation_mail_expirada_enabled` |
| → `liberada_para_circulacao` | (optionnel selon flag) | (rien) | `reservation_mail_liberada_para_circulacao_enabled` (default false) |

### Copies admin biblio

Conformément à `admin_copy_reservations_enabled` :
- **Events critiques** (toujours copiés au coord biblio si flag = true) :
  - `solicitada` (nouvelle commande à traiter)
  - `expirada` (info comportement système)
  - `retirada_no_show` (info comportement lecteur)
  - `cancelada_leitor` après `pronta_para_retirada` uniquement (info comportement)

- **Events non critiques** (jamais copiés au coord) :
  - `em_preparacao`, `retirada_agendada`, `pronta_para_retirada`, `retirada_efetivada`, autres
  - (raison : déjà déclenchés par la biblio elle-même)

### Conventions militantes (rappel)

Toutes les nouvelles clés i18n des mails de réservation doivent être **livrées en 6 locales d'un coup** (pt-BR, fr, es, en, it, de) selon les conventions existantes (cf. mémoire i18n).

Estimation : ~20 nouvelles clés × 6 locales = ~120 traductions militantes (sujets + corps de mail).

---

## 8. Interfaces utilisateur

### 8.1 — Côté lecteur·rice (`/conta`)

**Section "Mes réservations en cours"** : liste des réservations non-terminales (toutes sauf cancelada/expirada/retirada_efetivada).

Pour chaque réservation, affichage :

```
┌─ Réservation #42 — "L'État, c'est nous" ────────────────┐
│                                                          │
│  Timeline :                                              │
│   ✅ 1. Demande envoyée — 12/03/2026                    │
│   ✅ 2. En préparation — 13/03/2026                     │
│   ⏳ 3. Retrait prévu mardi 18/03 à 18h                 │
│       [✅ Je confirme]  [❌ Je ne peux pas]             │
│   ⬜ 4. Livre prêt à l'accueil                          │
│   ⬜ 5. Retrait effectué                                │
│                                                          │
│  [ Annuler ma réservation ]                              │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

Code couleur :
- ✅ **Vert** : étape déjà passée (grisée, juste à titre informatif)
- ⏳ **Animation** : étape courante
- ⬜ **Gris pâle** : étape future
- 🚫 **Rouge** : étape d'échec si applicable (annulation, expiration, no_show)

Pour `retirada_a_combinar`, indiquer "À combiner avec biblio avant le X". Pour les `re-retirada_agendada`, marquer la première date barrée avec la nouvelle au-dessus.

**Section "Réservations terminées"** : collapsible, juste une liste compacte avec dernière date et état terminal.

### 8.2 — Côté staff (`/painel`)

**Onglet "Réservations à traiter"** : sortable par stage, filterable par état actuel.

Pour chaque ligne, un bouton qui ouvre une **modale de transition** :

```
┌─ Avancer la réservation #42 ─────────────────────────────┐
│  État actuel : retirada_agendada                         │
│                                                          │
│  Transitions possibles :                                 │
│   ⚪ ✅ retirada_agendada (état actuel)                   │ ← grisé
│   ⚪ 📅 re-retirada_agendada (reprogrammer)               │
│   ⚪ 📚 pronta_para_retirada (livre prêt)                 │
│   ⚪ ❌ cancelada_biblioteca (annuler avec raison)        │
│                                                          │
│  [ Si retirada_agendada nouveau ou re- ] :               │
│   Date de retrait : [date picker]                        │
│   Note : [optional]                                      │
│                                                          │
│  [ Si cancelada_biblioteca ] :                           │
│   Raison (obligatoire) : [textarea]                      │
│                                                          │
│  [ Annuler ] [ Confirmer ]                               │
└──────────────────────────────────────────────────────────┘
```

**Important** :
- Les **étapes déjà passées** sont **affichées mais grisées** (visuellement présentes pour le contexte chronologique).
- Les **étapes interdites depuis l'état courant** sont **non affichées**.
- Les **étapes accessibles** sont **cliquables**.

**Bouton spécial "Retrait effectué"** : visible uniquement si stage = `pronta_para_retirada`. Ouvre une modale "Création de l'emprunt" qui demande la date d'échéance (default = +X jours selon politique biblio) et confirme l'INSERT atomique via `api.confirm_pickup_v1`.

**Bouton "No-show manuel"** : visible si stage = `pronta_para_retirada` et `pickup_scheduled_for` < now(). Permet à la biblio de devancer le job cron.

### 8.3 — Helpers UI à fournir

Composant React `<ReservationTimeline>` réutilisable :

```jsx
<ReservationTimeline 
  currentStage="retirada_agendada"
  history={[
    { stage: 'solicitada', at: '2026-03-12' },
    { stage: 'em_preparacao', at: '2026-03-13' },
  ]}
  pickupScheduledFor="2026-03-18T18:00"
  onConfirm={() => /* api.confirm_pickup_slot */}
  onRefuse={(reason) => /* api.refuse_pickup_slot */}
  onCancel={() => /* api.cancel_my_reservation */}
  mode="reader" // "reader" | "staff"
/>
```

Mode `reader` : affiche les boutons côté lecteur·rice. Mode `staff` : affiche les boutons de transition pour ≥ librarian.

---

## 9. Migration des données existantes

### Inventaire (rappel diagnostic)

```
3 retirada_efetivada
5 cancelada_leitor
1 liberada_para_circulacao
1 cancelada_biblioteca
0 stages intermédiaires
```

### Stratégie : pas de migration nécessaire

Tous les `workflow_stage` existants sont déjà des **stages terminaux** valides du nouveau workflow. Aucun n'est dans un état intermédiaire qui nécessiterait un "retournement" du flow. Donc :

1. Aucun UPDATE rétroactif nécessaire.
2. Les nouvelles réservations utiliseront immédiatement les nouvelles transitions.
3. Les RPCs front respectent les états existants (les `retirada_efetivada` ont déjà un emprunt associé, on ne les retouche pas).

### Vérification de cohérence à faire

Une seule chose à vérifier au déploiement :

```sql
-- Les 3 retirada_efetivada ont-elles bien un emprunt correspondant en emprestimos_v2 ?
SELECT riw.reserva_id, riw.line_no, riw.workflow_stage, e.id as loan_id
FROM public.reserva_item_workflow_v2 riw
LEFT JOIN public.emprestimo_itens_v2 e ON e.reserva_id = riw.reserva_id AND e.line_no = riw.line_no
WHERE riw.workflow_stage = 'retirada_efetivada';
-- Si l'un n'a pas de loan_id, c'est une incohérence à investiguer (créer manuellement ou marquer en erreur).
```

---

## 10. Hors scope

- **Système de file d'attente** : si plusieurs lecteur·rices réservent le même livre, un seul peut l'avoir. Une vraie file d'attente avec priorité serait utile, mais c'est une feature distincte. Pour l'instant : on accepte juste la première réservation et on refuse les suivantes côté API.
- **Notifications push / SMS** : seulement mails pour cette spec. Push/SMS = autre chantier.
- **Chat lecteur ↔ biblio** : on garde `workflow_note` pour mots libres unidirectionnels. Pour un vrai chat bilatéral, autre chantier.
- **Rapports statistiques** : "combien de no_show par mois", "temps moyen entre solicitada et retirada_efetivada", etc. — utile mais pas pour Bologna.

---

## 11. Checklist d'implémentation

### Phase 1 — Schéma DB (2-3h)

- [ ] Migration SQL : CHECK constraints, nouveaux index, nouveaux flags dans `library_notification_policies`
- [ ] Trigger `trg_auto_liberate_after_no_show` (ou pattern équivalent)
- [ ] Vérification cohérence existant (`retirada_efetivada` ↔ emprestimos_v2)

### Phase 2 — RPCs (4-6h)

- [ ] `api.create_reservation()` 
- [ ] `api.cancel_my_reservation()`
- [ ] `api.confirm_pickup_slot()` / `api.refuse_pickup_slot()`
- [ ] `api.advance_reservation()` (transition générique avec validation)
- [ ] `api.confirm_pickup_v1()` (transaction atomique avec INSERT emprestimos_v2)
- [ ] `api.mark_no_show()` (manuel staff)
- [ ] `api.cancel_reservation_as_library()` (avec raison conditionnelle)

### Phase 3 — Jobs pg_cron (2h)

- [ ] `fn_expire_solicitada_reservations()` + cron 6h
- [ ] `fn_detect_no_show_reservations()` + cron 1h
- [ ] Test manuel de chaque job

### Phase 4 — Mails i18n (4-6h)

- [ ] ~20 nouvelles clés × 6 locales = ~120 traductions militantes
- [ ] Mise à jour `mail-strings.ts`
- [ ] Lecture des flags `reservation_mail_*_enabled` dans le trigger ou dispatch
- [ ] Test Deno mail-strings.test.ts

### Phase 5 — Frontend lecteur (3-4h)

- [ ] Composant `<ReservationTimeline>` (mode reader)
- [ ] Section "Mes réservations" dans `/conta` avec timeline
- [ ] Boutons confirmer/refuser/annuler
- [ ] Tests de chaque branche

### Phase 6 — Frontend staff (4-6h)

- [ ] Onglet "Réservations" dans `/painel`
- [ ] Modale de transition avec validation des états autorisés
- [ ] Bouton spécial "Retrait effectué" + modale création emprunt
- [ ] Bouton "No-show manuel"
- [ ] Composant `<ReservationTimeline>` mode staff

### Phase 7 — Tests d'acceptation

(cf. section 12)

**Estimation totale : 4-6 jours de travail effectif**, étalés sur 2-3 semaines.

---

## 12. Tests d'acceptation

### Tests fonctionnels (T1-T8)

- [ ] **T1** : Lecteur réserve livre → solicitada → biblio passe em_preparacao → retirada_agendada → lecteur confirme → pronta_para_retirada → biblio clique "Retrait effectué" → retirada_efetivada + emprunt créé. Tous les mails partent.
- [ ] **T2** : Idem mais lecteur refuse le créneau → biblio repropose (re-retirada_agendada) → lecteur confirme.
- [ ] **T3** : Lecteur annule sa réservation à différents stages, vérifie que c'est bien `cancelada_leitor`, refus si stage = `retirada_efetivada`.
- [ ] **T4** : Biblio annule sans raison sur stage `solicitada` (OK), avec raison sur stage `retirada_agendada` (OK), sans raison sur stage `retirada_agendada` (REFUS).
- [ ] **T5** : Réservation reste `solicitada` 14 jours sans action → cron passe en `expirada` + mail.
- [ ] **T6** : Réservation est `pronta_para_retirada` avec pickup_scheduled_for = il y a 25h → cron passe en `retirada_no_show` + livre libéré.
- [ ] **T7** : Biblio désactive `reservation_mail_em_preparacao_enabled` → transitions vers em_preparacao n'envoient plus de mail au lecteur, mais le stage est bien mis à jour.
- [ ] **T8** : Multi-livres : lecteur réserve 3 livres dans une seule réservation → chacun a sa propre ligne workflow indépendante.

### Tests de transition (T9-T15)

- [ ] **T9** : Tentative de transition illégale (ex: `solicitada` → `pronta_para_retirada` direct) → RPC refuse.
- [ ] **T10** : Tentative de transition avec mauvais rôle (reader → `em_preparacao`) → REFUS RLS.
- [ ] **T11** : Création de `retirada_agendada` sans `pickup_scheduled_for` → CHECK constraint refuse.
- [ ] **T12** : `retirada_efetivada` est appelé via `api.confirm_pickup_v1` avec un livre déjà emprunté ailleurs → la transaction rollback.
- [ ] **T13** : Job cron expirada tourne en concurrence avec une action manuelle staff → atomic update, un seul gagne, pas de doublon mail.
- [ ] **T14** : Tous les flags `reservation_mail_*_enabled` à false → aucun mail ne part mais les stages avancent.
- [ ] **T15** : Transitions sur réservation d'une biblio dont `reservation_workflow_enabled = false` → comportement à définir (skip mails ? bloquer transitions ? juste skip mails est probablement le bon comportement).

### Tests UI (U1-U6)

- [ ] **U1** : Timeline lecteur : étapes passées grisées, étape courante animée, étapes futures en gris pâle.
- [ ] **U2** : Timeline staff : modale ne propose pas les transitions illégales depuis l'état actuel.
- [ ] **U3** : Bouton "Annuler ma réservation" disponible jusqu'à pronta_para_retirada inclus, désactivé sur retirada_efetivada.
- [ ] **U4** : Bouton "Confirmer le créneau" / "Refuser le créneau" visible uniquement quand stage IN ('retirada_agendada', 're-retirada_agendada').
- [ ] **U5** : Mode `retirada_a_combinar` affiche correctement la date butoir J+7 plutôt qu'un horaire précis.
- [ ] **U6** : `pickup_reply_status` change → notification visible côté biblio en temps réel (refresh ou WebSocket).

### Tests audit (L1-L3)

- [ ] **L1** : Toute transition est journalisée avec `updated_by` correct.
- [ ] **L2** : `pickup_reply_at` correctement mis à jour quand le lecteur répond.
- [ ] **L3** : Logs notify-event Edge Function montrent un POST par transition (ou 0 si flag désactivé).

---

## Annexes

### A — Glossaire

- **Workflow stage** : état actuel d'une ligne de réservation, stocké dans `reserva_item_workflow_v2.workflow_stage`.
- **Transition** : passage d'un workflow_stage à un autre, déclenché par lecteur, biblio, ou job automatique.
- **Pickup reply** : réponse du lecteur à un créneau proposé (confirmation ou refus).
- **No-show** : lecteur·rice n'est pas venu·e chercher le livre dans le délai imparti.

### B — Récap des décisions

| Question | Décision |
|---|---|
| Linéarité workflow | Hybride (em_preparacao optionnel, autres obligatoires) |
| Mode retrait | Choix par réservation (agendada vs a_combinar) |
| Détection no_show | Auto (pg_cron) + manuel (bouton staff) |
| Refus créneau lecteur | Biblio reagende (4b) |
| Annulation biblio | Différenciée selon état (raison obligatoire ≥ retirada_agendada) |
| Annulation lecteur | À tout moment sauf retirada_efetivada |
| Timeout solicitada | Configurable par biblio (default 14j) |
| Timeout no_show | Configurable par biblio (default 24h) |
| pickup_scheduled_for | Obligatoire pour stages retrait, nullable avant |
| UI lecteur | Timeline visuelle complète |
| Conversion → emprunt | Manuel + atomique (RPC unique) |
| Migration données | Aucune (états existants déjà conformes) |
| Mails désactivables | Individuellement par biblio (12 flags) |
| Copie admin biblio | Events critiques uniquement |

### C — Décisions à prendre lors de l'implémentation

- [ ] Sémantique exacte de `liberada_para_circulacao` : event d'info ou nouveau stage qui remplace ?
- [ ] Pour multi-livres avec disponibilités différentes : peut-on avoir un line en `retirada_efetivada` et un autre en `em_preparacao` dans la même réservation parente ? (Probablement oui, à valider.)
- [ ] WebSocket / realtime pour notifier la biblio des `pickup_reply_status` ? Ou juste refresh manuel ? (Probablement WebSocket pour Bologna.)
- [ ] Comportement précis quand une biblio a `reservation_workflow_enabled = false` : skip mails ? Bloquer les transitions au-delà de `solicitada` ? Juste loguer un warning ? (À trancher en début d'implé.)

---

**Spec close. Prochaine étape : implémentation — commencer par la phase 1 (schéma DB).**
