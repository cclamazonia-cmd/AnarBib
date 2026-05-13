# Spec — Workflow de réservation

**Statut** : Cadrée le 04/05/2026, en attente d'implémentation
**Cible** : Bologna FICEDL, septembre 2026
**Auteur·rices** : Xavier (spec et arbitrages) + Claude (rédaction, diagnostic)
**Dépendances** : aucune (peut être implémenté indépendamment des specs validation physique et migration de compte)

\---

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

\---

## 1\. Contexte et objectif

### Contexte

Le système de réservation AnarBib repose sur trois tables principales :

* `reservas\_v2` : réservation parente (1 lecteur·rice + 1 biblio + n livres)
* `reserva\_linhas\_v2` : lignes individuelles (1 livre = 1 ligne, parce qu'une réservation peut porter sur plusieurs livres)
* `reserva\_item\_workflow\_v2` : état courant du workflow par ligne

Aujourd'hui, le système souffre d'un **workflow simplifié à l'extrême** : seuls 4 stages terminaux sont effectivement utilisés (`cancelada\_leitor`, `cancelada\_biblioteca`, `retirada\_efetivada`, `liberada\_para\_circulacao`). Les stages intermédiaires (`solicitada`, `em\_preparacao`, `retirada\_agendada`, `pronta\_para\_retirada`) **ne sont jamais écrits en DB**, alors que toute l'infrastructure technique (triggers, fonction de dispatch HTTP vers notify-event, code Edge Function) est déjà en place.

### Objectif

Implémenter le workflow complet à 6 états + branches latérales, avec :

* Transitions correctement écrites en DB
* Mails contextuels par transition (ce que l'infra DB sait déjà faire)
* UI staff dans `/painel` pour effectuer les transitions
* UI lecteur dans `/conta` pour suivre l'état et confirmer/refuser les créneaux
* Configuration par biblio (timeouts, mails individuellement désactivables)
* Détection automatique des no-shows
* Conversion atomique `retirada\_efetivada` → emprunt actif

### Principes directeurs

> 1. \*\*Souveraineté des biblios\*\* sur leur configuration (timeouts, mails désactivables individuellement, modes de retrait).
> 2. \*\*Souveraineté du lecteur\*\* sur sa propre réservation (peut toujours annuler avant retrait effectif).
> 3. \*\*Atomicité des opérations critiques\*\* (conversion en emprunt = transaction unique).
> 4. \*\*Transparence\*\* : timeline visuelle pour le lecteur, journal d'audit pour la biblio.

\---

## 2\. Diagnostic préalable

### Découvertes de la session 04/05/2026

1. **Triggers DB en place et fonctionnels** :

   * `trg\_notify\_reserva\_workflow` sur INSERT/UPDATE de `reserva\_item\_workflow\_v2`
   * Appelle `fn\_dispatch\_circulation\_notify\_event` qui fait un POST HTTP vers notify-event Edge Function
   * Mapping correct des `workflow\_stage` → events : `re-retirada\_agendada`→`retirada\_reagendada`, `nao\_retirada`→`reserva\_nao\_retirada`, etc.
2. **Edge Function notify-event en place** :

   * `supabase/functions/\_shared/core/dispatch.ts` : route correctement les events workflow
   * `supabase/functions/\_shared/domain/reservas.ts` : génère les mails par event
3. **Cause racine** : le frontend (et les RPCs côté Supabase) **ne déclenchent jamais** les transitions intermédiaires. Probablement parce que :

   * Pas d'UI staff pour passer une réservation de `solicitada` à `em\_preparacao` ou `retirada\_agendada`
   * Pas de RPC dédiée à chaque transition (juste des UPDATE directs vers les états terminaux)
   * Pas de cron pour `retirada\_no\_show`
4. **Flag `reservation\_workflow\_enabled`** : présent dans `library\_notification\_policies` (true par défaut sur les 2 biblios actives). Lu côté Edge Function mais ne semble pas filtrer activement.

### Inventaire actuel

```
reserva\_item\_workflow\_v2 — distribution actuelle :
- cancelada\_leitor : 5
- retirada\_efetivada : 3
- cancelada\_biblioteca : 1
- liberada\_para\_circulacao : 1
- TOUS les autres stages : 0

Triggers actuels sur reservas\_v2 :
- trg\_reservas\_v2\_touch\_updated\_at (juste utilitaire updated\_at)

Triggers sur reserva\_item\_workflow\_v2 :
- trg\_notify\_reserva\_workflow (BIEN PRÉSENT)
- trg\_reserva\_item\_workflow\_v2\_touch\_updated\_at
```

\---

## 3\. Modèle conceptuel

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
                  │  em\_preparacao   │  ← optionnel, sautable
                  │   (étape 2)      │
                  └────────┬─────────┘
                           │
                           │  staff fixe le retrait
                           ├──────────────────┐
                           ▼                  ▼
              ┌──────────────────┐   ┌──────────────────┐
              │ retirada\_agendada│   │retirada\_a\_combinar│
              │   (étape 3a)     │   │   (étape 3b)      │
              │ pickup\_scheduled │   │ pickup\_scheduled  │
              │ obligatoire      │   │ flou (J+7 indic.) │
              └────┬─────────────┘   └────┬──────────────┘
                   │                      │
                   │  lecteur peut accepter│ ou refuser
                   │  (pickup\_reply\_status)│
                   │                      │
                   │  refus → biblio reagende
                   │  (re-retirada\_agendada)
                   │                      │
                   ▼                      ▼
                  ┌──────────────────────────┐
                  │  pronta\_para\_retirada    │
                  │   (étape 4)              │
                  │   livre physiquement     │
                  │   prêt à l'accueil       │
                  └──────────┬───────────────┘
                             │
                             │  lecteur vient
                             ▼
                  ┌──────────────────────────┐
                  │   retirada\_efetivada     │  ← ÉTAT FINAL
                  │   (étape 5)              │     conversion en
                  │                          │     empréstimo via
                  │                          │     RPC atomique
                  └──────────────────────────┘
```

### États d'échec / branches latérales

À tout moment avant `retirada\_efetivada` :

|État|Déclencheur|Source|
|-|-|-|
|`cancelada\_leitor`|Lecteur·rice annule depuis `/conta`|Lecteur·rice|
|`cancelada\_biblioteca`|Biblio annule (raison obligatoire si stage ≥ retirada\_agendada)|Coordenador|
|`expirada`|`solicitada` dépasse `reservation\_solicitada\_timeout\_days`|Job pg\_cron|
|`retirada\_no\_show` (= `nao\_retirada`)|Lecteur·rice n'est pas venu·e après pickup\_scheduled\_for + `reservation\_no\_show\_timeout\_hours`|Job pg\_cron OU staff manuellement|
|`re-retirada\_agendada`|Suite à refus lecteur (pickup\_reply\_status='recusado\_leitor'), biblio repropose|Coordenador|
|`liberada\_para\_circulacao`|Suite à no\_show ou cancelada\_biblioteca, livre repasse en circulation|Trigger automatique|

### Acteurs

* **Lecteur·rice** : crée la réservation (`solicitada`), confirme/refuse les créneaux (`pickup\_reply\_status`), annule à tout moment avant `retirada\_efetivada`.
* **Librarian** (≥) : peut effectuer les transitions `solicitada` → `em\_preparacao` → `retirada\_agendada/a\_combinar` → `pronta\_para\_retirada`. Peut marquer `retirada\_efetivada` (avec création emprunt) et `retirada\_no\_show` (manuel).
* **Coordenador** (≥) : tout ce qu'un librarian fait, plus `cancelada\_biblioteca` (avec raison) à n'importe quelle étape.
* **Job pg\_cron** : déclenche `expirada` et `retirada\_no\_show` automatiquement.

\---

## 4\. États et transitions

### États possibles (workflow\_stage)

|Stage|Description|Terminal ?|UI lecteur|UI staff|
|-|-|-|-|-|
|`solicitada`|Lecteur a créé la réservation|non|"Demande envoyée"|"À traiter"|
|`em\_preparacao`|Biblio prépare (sortie des étagères, vérification)|non|"En préparation"|"En cours"|
|`retirada\_agendada`|Créneau de retrait fixé (date précise)|non|"Retrait prévu le X" + boutons|"Retrait fixé"|
|`retirada\_a\_combinar`|Retrait à voir au cas par cas (date butoir)|non|"Retrait à combiner avant le X"|"À combiner"|
|`re-retirada\_agendada`|Créneau reprogrammé|non|"Nouveau créneau le X" + boutons|"Reagendée"|
|`pronta\_para\_retirada`|Livre prêt à l'accueil|non|"Prête, viens la chercher"|"Attente lecteur"|
|`retirada\_efetivada`|Lecteur·rice est venu·e|OUI|"Retrait effectué le X (devenu emprunt)"|"Effectuée"|
|`cancelada\_leitor`|Lecteur·rice a annulé|OUI|"Vous avez annulé"|"Annulée par lecteur"|
|`cancelada\_biblioteca`|Biblio a annulé|OUI|"Annulée par biblio : \[raison]"|"Annulée par biblio"|
|`expirada`|Timeout solicitada|OUI|"Expirée par non-prise en charge"|"Expirée"|
|`retirada\_no\_show` (= `nao\_retirada`)|Lecteur·rice non venu·e|OUI|"Non venu·e, livre libéré"|"No-show"|
|`liberada\_para\_circulacao`|Livre remis en circulation (post-no\_show ou cancel)|OUI|(n/a, déjà annulée)|"Livre libéré"|

### Matrice des transitions autorisées

```
DEPUIS                         | TRANSITIONS AUTORISÉES                                     | QUI
-------------------------------|-----------------------------------------------------------|---------
solicitada                     | em\_preparacao | retirada\_agendada | retirada\_a\_combinar    | librarian
                               | cancelada\_leitor                                          | lecteur
                               | cancelada\_biblioteca                                      | coordenador
                               | expirada                                                  | cron
em\_preparacao                  | retirada\_agendada | retirada\_a\_combinar                   | librarian
                               | cancelada\_leitor                                          | lecteur
                               | cancelada\_biblioteca                                      | coordenador
retirada\_agendada              | re-retirada\_agendada | pronta\_para\_retirada               | librarian
                               | cancelada\_leitor                                          | lecteur
                               | cancelada\_biblioteca                                      | coordenador
retirada\_a\_combinar            | retirada\_agendada | re-retirada\_agendada                  | librarian
                               | pronta\_para\_retirada                                      | librarian
                               | cancelada\_leitor                                          | lecteur
                               | cancelada\_biblioteca                                      | coordenador
re-retirada\_agendada           | pronta\_para\_retirada | re-retirada\_agendada               | librarian
                               | cancelada\_leitor                                          | lecteur
                               | cancelada\_biblioteca                                      | coordenador
pronta\_para\_retirada           | retirada\_efetivada (RPC atomique avec INSERT emprestimos) | librarian
                               | retirada\_no\_show                                          | librarian | cron
                               | cancelada\_leitor                                          | lecteur
                               | cancelada\_biblioteca                                      | coordenador
retirada\_no\_show               | liberada\_para\_circulacao (auto-déclenchée par trigger)    | trigger
                               | (état terminal après cette transition)                    |
cancelada\_\*, expirada,         | (états terminaux, aucune transition possible)             |
retirada\_efetivada,            |                                                           |
liberada\_para\_circulacao       |                                                           |
```

### Cas particulier : `pickup\_reply\_status`

Indépendant du `workflow\_stage`. Quand le stage est `retirada\_agendada` ou `re-retirada\_agendada`, le lecteur peut répondre via la colonne `pickup\_reply\_status` :

* `confirmado\_leitor` : "OK, je peux à ce créneau"
* `recusado\_leitor` : "Non, je ne peux pas"

Le trigger DB `trg\_notify\_reserva\_workflow\_change` détecte ce changement et envoie le mail correspondant à la biblio. Si refus, la biblio peut alors transitionner vers `re-retirada\_agendada` avec un nouveau `pickup\_scheduled\_for`.

\---

## 5\. Schéma DB

### Tables existantes (rappel)

```sql
public.reservas\_v2 (
  id bigserial PRIMARY KEY,
  user\_id uuid,
  library\_id uuid,
  notes text,
  status\_global text DEFAULT 'ativa', -- ativa | finalizada | cancelada
  created\_at, updated\_at
);

public.reserva\_linhas\_v2 (
  reserva\_id bigint, line\_no int,
  -- ... (référence vers le livre, exemplaire, etc.)
);

public.reserva\_item\_workflow\_v2 (
  id bigserial PRIMARY KEY,
  reserva\_id bigint,
  line\_no int,
  workflow\_stage text,
  workflow\_note text,
  pickup\_scheduled\_for timestamptz,
  pickup\_reply\_status text, -- null | confirmado\_leitor | recusado\_leitor
  pickup\_reply\_note text,
  pickup\_reply\_at timestamptz,
  updated\_at, updated\_by uuid,
  UNIQUE (reserva\_id, line\_no)
);
```

### Modifications à apporter

#### 1\. Contraintes CHECK sur workflow\_stage

```sql
ALTER TABLE public.reserva\_item\_workflow\_v2
  ADD CONSTRAINT chk\_workflow\_stage CHECK (workflow\_stage IN (
    'solicitada',
    'em\_preparacao',
    'retirada\_agendada',
    'retirada\_a\_combinar',
    're-retirada\_agendada',
    'pronta\_para\_retirada',
    'retirada\_efetivada',
    'retirada\_no\_show',
    'nao\_retirada',  -- alias historique de retirada\_no\_show, à conserver pour compat
    'cancelada\_leitor',
    'cancelada\_biblioteca',
    'expirada',
    'liberada\_para\_circulacao'
  ));

ALTER TABLE public.reserva\_item\_workflow\_v2
  ADD CONSTRAINT chk\_pickup\_scheduled\_for\_required CHECK (
    workflow\_stage NOT IN ('retirada\_agendada', 're-retirada\_agendada', 'retirada\_a\_combinar')
    OR pickup\_scheduled\_for IS NOT NULL
  );
```

#### 2\. Nouveaux flags dans `library\_notification\_policies`

```sql
ALTER TABLE public.library\_notification\_policies
  ADD COLUMN reservation\_solicitada\_timeout\_days int NOT NULL DEFAULT 14,
  ADD COLUMN reservation\_no\_show\_timeout\_hours int NOT NULL DEFAULT 24,

  -- Mails désactivables individuellement (default true = on envoie)
  ADD COLUMN reservation\_mail\_solicitada\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_em\_preparacao\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_retirada\_agendada\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_retirada\_a\_combinar\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_pronta\_para\_retirada\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_retirada\_reagendada\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_retirada\_no\_show\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_expirada\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_cancelada\_leitor\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_cancelada\_biblioteca\_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation\_mail\_liberada\_para\_circulacao\_enabled boolean NOT NULL DEFAULT false;
  -- liberada\_para\_circulacao false par défaut = pas la peine de spammer le lecteur déjà annulé
  -- (option d'activation pour celles qui veulent dire "votre livre est dispo si vous voulez le re-réserver")

-- Constraints raisonnables
ALTER TABLE public.library\_notification\_policies
  ADD CONSTRAINT chk\_solicitada\_timeout CHECK (reservation\_solicitada\_timeout\_days BETWEEN 7 AND 60),
  ADD CONSTRAINT chk\_no\_show\_timeout CHECK (reservation\_no\_show\_timeout\_hours BETWEEN 12 AND 168);
```

#### 3\. Index pour les jobs cron

```sql
-- Pour expiration rapide
CREATE INDEX idx\_riw\_expiry\_check ON public.reserva\_item\_workflow\_v2 (workflow\_stage, updated\_at)
  WHERE workflow\_stage = 'solicitada';

-- Pour no\_show rapide
CREATE INDEX idx\_riw\_no\_show\_check ON public.reserva\_item\_workflow\_v2 (workflow\_stage, pickup\_scheduled\_for)
  WHERE workflow\_stage IN ('pronta\_para\_retirada', 'retirada\_agendada', 're-retirada\_agendada');
```

#### 4\. Trigger pour `liberada\_para\_circulacao` automatique post-no\_show

```sql
CREATE OR REPLACE FUNCTION public.trg\_auto\_liberate\_after\_no\_show()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Si on passe en retirada\_no\_show ou cancelada\_biblioteca,
  -- on insert immédiatement un nouvel évènement liberada\_para\_circulacao
  -- pour que le livre soit dispo en circulation à nouveau.
  IF NEW.workflow\_stage IN ('retirada\_no\_show', 'nao\_retirada', 'cancelada\_biblioteca') THEN
    -- (logique applicative à définir : faut-il INSERT une nouvelle ligne, ou plutôt
    --  émettre l'event sans changer le stage qui restait sur retirada\_no\_show ?)
    -- À discuter à l'implémentation : event d'info plutôt que mutation de stage.
    PERFORM fn\_dispatch\_circulation\_notify\_event(
      'liberada\_para\_circulacao',
      NEW.reserva\_id,
      jsonb\_build\_object('line\_nos', jsonb\_build\_array(NEW.line\_no))
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg\_auto\_liberate\_after\_no\_show
  AFTER UPDATE ON public.reserva\_item\_workflow\_v2
  FOR EACH ROW
  WHEN (NEW.workflow\_stage IS DISTINCT FROM OLD.workflow\_stage)
  EXECUTE FUNCTION trg\_auto\_liberate\_after\_no\_show();
```

**Note d'implémentation** : à raffiner. La sémantique exacte de `liberada\_para\_circulacao` doit être tranchée — est-ce un nouveau stage (qui remplace `retirada\_no\_show`), ou un event d'information sans mutation du stage ? Ma proposition : c'est un event d'information distinct du stage final `retirada\_no\_show`/`cancelada\_biblioteca`. Le stage reste celui qui a déclenché la libération.

\---

## 6\. RPCs et triggers

### RPCs frontend → DB

Une RPC par transition métier, plutôt que des UPDATEs directs. Garantit :

* Validation des transitions (refus si transition illégale)
* Audit trail (updated\_by)
* Atomicité (transactions)

```sql
-- Côté lecteur·rice
api.create\_reservation(book\_id, library\_id, notes) -> bigint
  -- Crée reservas\_v2 + reserva\_linhas\_v2 + reserva\_item\_workflow\_v2 (workflow\_stage='solicitada')

api.cancel\_my\_reservation(reserva\_id) -> void
  -- Vérifie que c'est bien la réservation du caller
  -- Refuse si workflow\_stage = 'retirada\_efetivada' (déjà devenue emprunt)
  -- UPDATE workflow\_stage = 'cancelada\_leitor'

api.confirm\_pickup\_slot(reserva\_id, line\_no) -> void
  -- Vérifie ownership
  -- Vérifie workflow\_stage IN ('retirada\_agendada', 're-retirada\_agendada', 'retirada\_a\_combinar')
  -- UPDATE pickup\_reply\_status = 'confirmado\_leitor', pickup\_reply\_at = now()

api.refuse\_pickup\_slot(reserva\_id, line\_no, reason text) -> void
  -- UPDATE pickup\_reply\_status = 'recusado\_leitor', pickup\_reply\_note = reason

-- Côté staff (≥ librarian)
api.advance\_reservation(reserva\_id, line\_no, target\_stage text, options jsonb) -> void
  -- Vérifie role et que la transition est autorisée depuis stage actuel
  -- UPDATE workflow\_stage selon target\_stage
  -- Pour retirada\_agendada/a\_combinar/re-retirada\_agendada : pickup\_scheduled\_for OBLIGATOIRE dans options

api.confirm\_pickup\_v1(reserva\_id, line\_no, loan\_options jsonb) -> bigint
  -- Atomique : INSERT emprestimos\_v2 + reserva\_item\_workflow\_v2.workflow\_stage = 'retirada\_efetivada'
  -- Retourne l'id du nouvel emprunt

api.mark\_no\_show(reserva\_id, line\_no) -> void
  -- Manuel : staff constate que lecteur n'est pas venu
  -- workflow\_stage = 'retirada\_no\_show'

-- Côté coordenador
api.cancel\_reservation\_as\_library(reserva\_id, line\_no, reason text) -> void
  -- Vérifie role coordenador+
  -- Si stage >= retirada\_agendada, reason OBLIGATOIRE (CHECK)
  -- workflow\_stage = 'cancelada\_biblioteca'
```

### Jobs pg\_cron

```sql
-- Job 1 : expiration des solicitada
CREATE OR REPLACE FUNCTION public.fn\_expire\_solicitada\_reservations()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v\_count int := 0;
BEGIN
  -- Pour chaque biblio, on récupère son timeout dans library\_notification\_policies
  WITH expired AS (
    SELECT riw.reserva\_id, riw.line\_no
    FROM public.reserva\_item\_workflow\_v2 riw
    JOIN public.reservas\_v2 r ON r.id = riw.reserva\_id
    JOIN public.library\_notification\_policies lnp ON lnp.library\_id = r.library\_id
    WHERE riw.workflow\_stage = 'solicitada'
      AND riw.updated\_at < (now() - (lnp.reservation\_solicitada\_timeout\_days || ' days')::interval)
  )
  UPDATE public.reserva\_item\_workflow\_v2
  SET workflow\_stage = 'expirada', updated\_at = now()
  FROM expired
  WHERE reserva\_item\_workflow\_v2.reserva\_id = expired.reserva\_id
    AND reserva\_item\_workflow\_v2.line\_no = expired.line\_no;
  
  GET DIAGNOSTICS v\_count = ROW\_COUNT;
  RETURN v\_count;
END;
$$;

SELECT cron.schedule(
  'expire-solicitada-reservations',
  '0 \*/6 \* \* \*',  -- toutes les 6h
  'SELECT fn\_expire\_solicitada\_reservations()'
);

-- Job 2 : détection no\_show
CREATE OR REPLACE FUNCTION public.fn\_detect\_no\_show\_reservations()
RETURNS int
-- Similaire : sélectionne les reserva\_item\_workflow\_v2 en pronta\_para\_retirada/retirada\_agendada
-- dont pickup\_scheduled\_for + reservation\_no\_show\_timeout\_hours < now()
-- et passe en workflow\_stage = 'retirada\_no\_show'.
$$;

SELECT cron.schedule(
  'detect-no-show-reservations',
  '0 \* \* \* \*',  -- toutes les heures
  'SELECT fn\_detect\_no\_show\_reservations()'
);
```

### Trigger DB existant à conserver

`trg\_notify\_reserva\_workflow\_change` reste tel quel : il détecte les changements de `workflow\_stage` et de `pickup\_reply\_status`, et envoie l'event à notify-event Edge Function. Pas de modification.

**Petite amélioration possible** : faire que ce trigger consulte le flag `reservation\_mail\_\*\_enabled` correspondant avant d'appeler `fn\_dispatch\_circulation\_notify\_event`. Si flag = false, skip silencieusement. À implémenter dans la fonction trigger.

\---

## 7\. Mails et notifications

### Mails par transition

|Transition|Lecteur·rice reçoit|Biblio reçoit|Flag de désactivation|
|-|-|-|-|
|`solicitada` (création)|"Votre réservation est enregistrée"|"Nouvelle réservation à traiter"|`reservation\_mail\_solicitada\_enabled`|
|→ `em\_preparacao`|"Votre livre est en préparation"|(rien, c'est elle qui agit)|`reservation\_mail\_em\_preparacao\_enabled`|
|→ `retirada\_agendada`|"Retrait prévu le X — confirmer/refuser"|(rien)|`reservation\_mail\_retirada\_agendada\_enabled`|
|→ `retirada\_a\_combinar`|"Retrait à combiner avant le X — contacter biblio"|(rien)|`reservation\_mail\_retirada\_a\_combinar\_enabled`|
|→ `re-retirada\_agendada`|"Nouveau créneau le X — confirmer/refuser"|(rien)|`reservation\_mail\_retirada\_reagendada\_enabled`|
|`pickup\_reply` confirmado|(rien)|"Lecteur·rice confirme"|(toujours actif, géré par trigger)|
|`pickup\_reply` recusado|(rien)|"Lecteur·rice refuse"|(toujours actif)|
|→ `pronta\_para\_retirada`|"Livre prêt, viens la chercher"|(rien)|`reservation\_mail\_pronta\_para\_retirada\_enabled`|
|→ `retirada\_efetivada`|"Retrait effectué, devenu emprunt jusqu'au X"|(rien, sauf `admin\_copy\_loans\_enabled`)|(utilise les mails emprunt)|
|→ `retirada\_no\_show` (auto ou manuel)|"Vous n'êtes pas venu·e, réservation annulée, livre dispo"|"Lecteur·rice no-show" (event critique)|`reservation\_mail\_retirada\_no\_show\_enabled`|
|→ `cancelada\_leitor`|"Votre annulation est enregistrée"|(rien, sauf `admin\_copy\_reservations\_enabled`)|`reservation\_mail\_cancelada\_leitor\_enabled`|
|→ `cancelada\_biblioteca`|"Biblio a annulé : \[raison]"|(rien)|`reservation\_mail\_cancelada\_biblioteca\_enabled`|
|→ `expirada`|"Votre réservation a expiré"|"Réservation expirée" (event critique)|`reservation\_mail\_expirada\_enabled`|
|→ `liberada\_para\_circulacao`|(optionnel selon flag)|(rien)|`reservation\_mail\_liberada\_para\_circulacao\_enabled` (default false)|

### Copies admin biblio

Conformément à `admin\_copy\_reservations\_enabled` :

* **Events critiques** (toujours copiés au coord biblio si flag = true) :

  * `solicitada` (nouvelle commande à traiter)
  * `expirada` (info comportement système)
  * `retirada\_no\_show` (info comportement lecteur)
  * `cancelada\_leitor` après `pronta\_para\_retirada` uniquement (info comportement)
* **Events non critiques** (jamais copiés au coord) :

  * `em\_preparacao`, `retirada\_agendada`, `pronta\_para\_retirada`, `retirada\_efetivada`, autres
  * (raison : déjà déclenchés par la biblio elle-même)

### Conventions militantes (rappel)

Toutes les nouvelles clés i18n des mails de réservation doivent être **livrées en 6 locales d'un coup** (pt-BR, fr, es, en, it, de) selon les conventions existantes (cf. mémoire i18n).

Estimation : \~20 nouvelles clés × 6 locales = \~120 traductions militantes (sujets + corps de mail).

\---

## 8\. Interfaces utilisateur

### 8.1 — Côté lecteur·rice (`/conta`)

**Section "Mes réservations en cours"** : liste des réservations non-terminales (toutes sauf cancelada/expirada/retirada\_efetivada).

Pour chaque réservation, affichage :

```
┌─ Réservation #42 — "L'État, c'est nous" ────────────────┐
│                                                          │
│  Timeline :                                              │
│   ✅ 1. Demande envoyée — 12/03/2026                    │
│   ✅ 2. En préparation — 13/03/2026                     │
│   ⏳ 3. Retrait prévu mardi 18/03 à 18h                 │
│       \[✅ Je confirme]  \[❌ Je ne peux pas]             │
│   ⬜ 4. Livre prêt à l'accueil                          │
│   ⬜ 5. Retrait effectué                                │
│                                                          │
│  \[ Annuler ma réservation ]                              │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

Code couleur :

* ✅ **Vert** : étape déjà passée (grisée, juste à titre informatif)
* ⏳ **Animation** : étape courante
* ⬜ **Gris pâle** : étape future
* 🚫 **Rouge** : étape d'échec si applicable (annulation, expiration, no\_show)

Pour `retirada\_a\_combinar`, indiquer "À combiner avec biblio avant le X". Pour les `re-retirada\_agendada`, marquer la première date barrée avec la nouvelle au-dessus.

**Section "Réservations terminées"** : collapsible, juste une liste compacte avec dernière date et état terminal.

### 8.2 — Côté staff (`/painel`)

**Onglet "Réservations à traiter"** : sortable par stage, filterable par état actuel.

Pour chaque ligne, un bouton qui ouvre une **modale de transition** :

```
┌─ Avancer la réservation #42 ─────────────────────────────┐
│  État actuel : retirada\_agendada                         │
│                                                          │
│  Transitions possibles :                                 │
│   ⚪ ✅ retirada\_agendada (état actuel)                   │ ← grisé
│   ⚪ 📅 re-retirada\_agendada (reprogrammer)               │
│   ⚪ 📚 pronta\_para\_retirada (livre prêt)                 │
│   ⚪ ❌ cancelada\_biblioteca (annuler avec raison)        │
│                                                          │
│  \[ Si retirada\_agendada nouveau ou re- ] :               │
│   Date de retrait : \[date picker]                        │
│   Note : \[optional]                                      │
│                                                          │
│  \[ Si cancelada\_biblioteca ] :                           │
│   Raison (obligatoire) : \[textarea]                      │
│                                                          │
│  \[ Annuler ] \[ Confirmer ]                               │
└──────────────────────────────────────────────────────────┘
```

**Important** :

* Les **étapes déjà passées** sont **affichées mais grisées** (visuellement présentes pour le contexte chronologique).
* Les **étapes interdites depuis l'état courant** sont **non affichées**.
* Les **étapes accessibles** sont **cliquables**.

**Bouton spécial "Retrait effectué"** : visible uniquement si stage = `pronta\_para\_retirada`. Ouvre une modale "Création de l'emprunt" qui demande la date d'échéance (default = +X jours selon politique biblio) et confirme l'INSERT atomique via `api.confirm\_pickup\_v1`.

**Bouton "No-show manuel"** : visible si stage = `pronta\_para\_retirada` et `pickup\_scheduled\_for` < now(). Permet à la biblio de devancer le job cron.

### 8.3 — Helpers UI à fournir

Composant React `<ReservationTimeline>` réutilisable :

```jsx
<ReservationTimeline 
  currentStage="retirada\_agendada"
  history={\[
    { stage: 'solicitada', at: '2026-03-12' },
    { stage: 'em\_preparacao', at: '2026-03-13' },
  ]}
  pickupScheduledFor="2026-03-18T18:00"
  onConfirm={() => /\* api.confirm\_pickup\_slot \*/}
  onRefuse={(reason) => /\* api.refuse\_pickup\_slot \*/}
  onCancel={() => /\* api.cancel\_my\_reservation \*/}
  mode="reader" // "reader" | "staff"
/>
```

Mode `reader` : affiche les boutons côté lecteur·rice. Mode `staff` : affiche les boutons de transition pour ≥ librarian.

\---

## 9\. Migration des données existantes

### Inventaire (rappel diagnostic)

```
3 retirada\_efetivada
5 cancelada\_leitor
1 liberada\_para\_circulacao
1 cancelada\_biblioteca
0 stages intermédiaires
```

### Stratégie : pas de migration nécessaire

Tous les `workflow\_stage` existants sont déjà des **stages terminaux** valides du nouveau workflow. Aucun n'est dans un état intermédiaire qui nécessiterait un "retournement" du flow. Donc :

1. Aucun UPDATE rétroactif nécessaire.
2. Les nouvelles réservations utiliseront immédiatement les nouvelles transitions.
3. Les RPCs front respectent les états existants (les `retirada\_efetivada` ont déjà un emprunt associé, on ne les retouche pas).

### Vérification de cohérence à faire

Une seule chose à vérifier au déploiement :

```sql
-- Les 3 retirada\_efetivada ont-elles bien un emprunt correspondant en emprestimos\_v2 ?
SELECT riw.reserva\_id, riw.line\_no, riw.workflow\_stage, e.id as loan\_id
FROM public.reserva\_item\_workflow\_v2 riw
LEFT JOIN public.emprestimo\_itens\_v2 e ON e.reserva\_id = riw.reserva\_id AND e.line\_no = riw.line\_no
WHERE riw.workflow\_stage = 'retirada\_efetivada';
-- Si l'un n'a pas de loan\_id, c'est une incohérence à investiguer (créer manuellement ou marquer en erreur).
```

\---

## 10\. Hors scope

* **Système de file d'attente** : si plusieurs lecteur·rices réservent le même livre, un seul peut l'avoir. Une vraie file d'attente avec priorité serait utile, mais c'est une feature distincte. Pour l'instant : on accepte juste la première réservation et on refuse les suivantes côté API.
* **Notifications push / SMS** : seulement mails pour cette spec. Push/SMS = autre chantier.
* **Chat lecteur ↔ biblio** : on garde `workflow\_note` pour mots libres unidirectionnels. Pour un vrai chat bilatéral, autre chantier.
* **Rapports statistiques** : "combien de no\_show par mois", "temps moyen entre solicitada et retirada\_efetivada", etc. — utile mais pas pour Bologna.

\---

## 11\. Checklist d'implémentation

### Phase 1 — Schéma DB (2-3h)

* \[ ] Migration SQL : CHECK constraints, nouveaux index, nouveaux flags dans `library\_notification\_policies`
* \[ ] Trigger `trg\_auto\_liberate\_after\_no\_show` (ou pattern équivalent)
* \[ ] Vérification cohérence existant (`retirada\_efetivada` ↔ emprestimos\_v2)

### Phase 2 — RPCs (4-6h)

* \[ ] `api.create\_reservation()`
* \[ ] `api.cancel\_my\_reservation()`
* \[ ] `api.confirm\_pickup\_slot()` / `api.refuse\_pickup\_slot()`
* \[ ] `api.advance\_reservation()` (transition générique avec validation)
* \[ ] `api.confirm\_pickup\_v1()` (transaction atomique avec INSERT emprestimos\_v2)
* \[ ] `api.mark\_no\_show()` (manuel staff)
* \[ ] `api.cancel\_reservation\_as\_library()` (avec raison conditionnelle)

### Phase 3 — Jobs pg\_cron (2h)

* \[ ] `fn\_expire\_solicitada\_reservations()` + cron 6h
* \[ ] `fn\_detect\_no\_show\_reservations()` + cron 1h
* \[ ] Test manuel de chaque job

### Phase 4 — Mails i18n (4-6h)

* \[ ] \~20 nouvelles clés × 6 locales = \~120 traductions militantes
* \[ ] Mise à jour `mail-strings.ts`
* \[ ] Lecture des flags `reservation\_mail\_\*\_enabled` dans le trigger ou dispatch
* \[ ] Test Deno mail-strings.test.ts

### Phase 5 — Frontend lecteur (3-4h)

* \[ ] Composant `<ReservationTimeline>` (mode reader)
* \[ ] Section "Mes réservations" dans `/conta` avec timeline
* \[ ] Boutons confirmer/refuser/annuler
* \[ ] Tests de chaque branche

### Phase 6 — Frontend staff (4-6h)

* \[ ] Onglet "Réservations" dans `/painel`
* \[ ] Modale de transition avec validation des états autorisés
* \[ ] Bouton spécial "Retrait effectué" + modale création emprunt
* \[ ] Bouton "No-show manuel"
* \[ ] Composant `<ReservationTimeline>` mode staff

### Phase 7 — Tests d'acceptation

(cf. section 12)

**Estimation totale : 4-6 jours de travail effectif**, étalés sur 2-3 semaines.

\---

## 12\. Tests d'acceptation

### Tests fonctionnels (T1-T8)

* \[ ] **T1** : Lecteur réserve livre → solicitada → biblio passe em\_preparacao → retirada\_agendada → lecteur confirme → pronta\_para\_retirada → biblio clique "Retrait effectué" → retirada\_efetivada + emprunt créé. Tous les mails partent.
* \[ ] **T2** : Idem mais lecteur refuse le créneau → biblio repropose (re-retirada\_agendada) → lecteur confirme.
* \[ ] **T3** : Lecteur annule sa réservation à différents stages, vérifie que c'est bien `cancelada\_leitor`, refus si stage = `retirada\_efetivada`.
* \[ ] **T4** : Biblio annule sans raison sur stage `solicitada` (OK), avec raison sur stage `retirada\_agendada` (OK), sans raison sur stage `retirada\_agendada` (REFUS).
* \[ ] **T5** : Réservation reste `solicitada` 14 jours sans action → cron passe en `expirada` + mail.
* \[ ] **T6** : Réservation est `pronta\_para\_retirada` avec pickup\_scheduled\_for = il y a 25h → cron passe en `retirada\_no\_show` + livre libéré.
* \[ ] **T7** : Biblio désactive `reservation\_mail\_em\_preparacao\_enabled` → transitions vers em\_preparacao n'envoient plus de mail au lecteur, mais le stage est bien mis à jour.
* \[ ] **T8** : Multi-livres : lecteur réserve 3 livres dans une seule réservation → chacun a sa propre ligne workflow indépendante.

### Tests de transition (T9-T15)

* \[ ] **T9** : Tentative de transition illégale (ex: `solicitada` → `pronta\_para\_retirada` direct) → RPC refuse.
* \[ ] **T10** : Tentative de transition avec mauvais rôle (reader → `em\_preparacao`) → REFUS RLS.
* \[ ] **T11** : Création de `retirada\_agendada` sans `pickup\_scheduled\_for` → CHECK constraint refuse.
* \[ ] **T12** : `retirada\_efetivada` est appelé via `api.confirm\_pickup\_v1` avec un livre déjà emprunté ailleurs → la transaction rollback.
* \[ ] **T13** : Job cron expirada tourne en concurrence avec une action manuelle staff → atomic update, un seul gagne, pas de doublon mail.
* \[ ] **T14** : Tous les flags `reservation\_mail\_\*\_enabled` à false → aucun mail ne part mais les stages avancent.
* \[ ] **T15** : Transitions sur réservation d'une biblio dont `reservation\_workflow\_enabled = false` → comportement à définir (skip mails ? bloquer transitions ? juste skip mails est probablement le bon comportement).

### Tests UI (U1-U6)

* \[ ] **U1** : Timeline lecteur : étapes passées grisées, étape courante animée, étapes futures en gris pâle.
* \[ ] **U2** : Timeline staff : modale ne propose pas les transitions illégales depuis l'état actuel.
* \[ ] **U3** : Bouton "Annuler ma réservation" disponible jusqu'à pronta\_para\_retirada inclus, désactivé sur retirada\_efetivada.
* \[ ] **U4** : Bouton "Confirmer le créneau" / "Refuser le créneau" visible uniquement quand stage IN ('retirada\_agendada', 're-retirada\_agendada').
* \[ ] **U5** : Mode `retirada\_a\_combinar` affiche correctement la date butoir J+7 plutôt qu'un horaire précis.
* \[ ] **U6** : `pickup\_reply\_status` change → notification visible côté biblio en temps réel (refresh ou WebSocket).

### Tests audit (L1-L3)

* \[ ] **L1** : Toute transition est journalisée avec `updated\_by` correct.
* \[ ] **L2** : `pickup\_reply\_at` correctement mis à jour quand le lecteur répond.
* \[ ] **L3** : Logs notify-event Edge Function montrent un POST par transition (ou 0 si flag désactivé).

\---

## Annexes

### A — Glossaire

* **Workflow stage** : état actuel d'une ligne de réservation, stocké dans `reserva\_item\_workflow\_v2.workflow\_stage`.
* **Transition** : passage d'un workflow\_stage à un autre, déclenché par lecteur, biblio, ou job automatique.
* **Pickup reply** : réponse du lecteur à un créneau proposé (confirmation ou refus).
* **No-show** : lecteur·rice n'est pas venu·e chercher le livre dans le délai imparti.

### B — Récap des décisions

|Question|Décision|
|-|-|
|Linéarité workflow|Hybride (em\_preparacao optionnel, autres obligatoires)|
|Mode retrait|Choix par réservation (agendada vs a\_combinar)|
|Détection no\_show|Auto (pg\_cron) + manuel (bouton staff)|
|Refus créneau lecteur|Biblio reagende (4b)|
|Annulation biblio|Différenciée selon état (raison obligatoire ≥ retirada\_agendada)|
|Annulation lecteur|À tout moment sauf retirada\_efetivada|
|Timeout solicitada|Configurable par biblio (default 14j)|
|Timeout no\_show|Configurable par biblio (default 24h)|
|pickup\_scheduled\_for|Obligatoire pour stages retrait, nullable avant|
|UI lecteur|Timeline visuelle complète|
|Conversion → emprunt|Manuel + atomique (RPC unique)|
|Migration données|Aucune (états existants déjà conformes)|
|Mails désactivables|Individuellement par biblio (12 flags)|
|Copie admin biblio|Events critiques uniquement|

### C — Décisions à prendre lors de l'implémentation

* \[ ] Sémantique exacte de `liberada\_para\_circulacao` : event d'info ou nouveau stage qui remplace ?
* \[ ] Pour multi-livres avec disponibilités différentes : peut-on avoir un line en `retirada\_efetivada` et un autre en `em\_preparacao` dans la même réservation parente ? (Probablement oui, à valider.)
* \[ ] WebSocket / realtime pour notifier la biblio des `pickup\_reply\_status` ? Ou juste refresh manuel ? (Probablement WebSocket pour Bologna.)
* \[ ] Comportement précis quand une biblio a `reservation\_workflow\_enabled = false` : skip mails ? Bloquer les transitions au-delà de `solicitada` ? Juste loguer un warning ? (À trancher en début d'implé.)

\---

**Spec close. Prochaine étape : implémentation — commencer par la phase 1 (schéma DB).**

