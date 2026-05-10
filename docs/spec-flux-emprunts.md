# Spec — Flux des emprunts

> **Statut** : rédaction du 10/05/2026 — base pour implémentation phasée
> **Périmètre** : circulation locale (emprestimos_v2 + emprestimo_itens_v2). Hors périmètre : prêt inter-bibliothèques (interlibrary_loans_v2), couvert par sa propre chaîne.
> **Spec sœur** : spec-flux-consultation-locale.md (chaîne parallèle pour les consultations sur place).
> **Spec amont** : spec-workflow-reservation.md (la chaîne qui produit l'un des deux chemins de création d'un emprunt).

---

## 1. Contexte et objectif politique

Dans une bibliothèque militante anarchiste, l'emprunt n'est pas un acte administratif : c'est le moment où un livre quitte le rayon pour aller travailler dans une lutte, une lecture personnelle, un cercle d'études. Le SIGB doit refléter cette dignité : peu de friction au comptoir, autonomie maximale du lecteur quand c'est possible, intervention bibliothécaire claire quand c'est nécessaire, et lisibilité totale des règles (date de retour, renouvellement possible ou non, motif de refus) pour ne jamais transformer une règle de circulation en pouvoir opaque.

Cette spec couvre le cycle de vie d'un emprunt local depuis sa création jusqu'à sa clôture, en prenant en compte deux chemins de création (réservation confirmée et prêt comptoir direct), le renouvellement bilatéral (lecteur ou bibliothécaire), le retour total ou partiel, et les notifications associées.

L'objectif n'est pas de réécrire le backend — il est largement en place — mais d'aligner les invariants, combler les manques identifiés (statut intermédiaire `parcialmente_devolvido`, bug dans `fn_renew_my_loan`, vérifications de règles bloquantes côté lecteur), et stabiliser les surfaces UI.

---

## 2. État de l'existant au 10/05/2026

### 2.1 Tables (CHECK constraints actuels)

**`emprestimos_v2`** — agrégat de tête.

| colonne | type | défaut | rôle |
|---|---|---|---|
| `id` | bigint | — | PK |
| `user_id` | uuid | — | lecteur (FK profiles) |
| `library_id` | uuid | — | biblio (FK libraries) |
| `notes` | text | — | note libre |
| `status_global` | text | `'aberto'` | **CHECK actuel : `aberto`/`encerrado` uniquement** |
| `due_at` | date | — | date prévue de retour |
| `extended_once` | boolean | `false` | flag "déjà prolongé une fois" |
| `extended_at` | timestamptz | — | date de prolongation |
| `created_at`, `updated_at` | timestamptz | `now()` | |

**`emprestimo_itens_v2`** — lignes (un item par exemplaire emprunté).

| colonne | type | défaut | rôle |
|---|---|---|---|
| `id`, `emprestimo_id`, `line_no`, `sub_id` | — | — | identifiants |
| `book_id`, `item_id`, `holding_id` | bigint | — | livre, exemplaire, holding |
| `reserva_id`, `reserva_line_no` | bigint | nullable | trace du chemin réservation si applicable |
| `bib_ref`, `rotulo_cache`, `titulo_cache`, `autor_cache`, `editora_cache`, `ano_cache` | text | — | snapshot bibliographique |
| `item_status` | text | `'aberto'` | **CHECK : `aberto`/`devolvido`** |
| `due_at` | date | — | date de retour de cette ligne |
| `extended_until` | date | — | date après prolongation |
| `extension_note` | text | — | trace de la prolongation |
| `returned_at`, `return_scheduled_for`, `return_scheduled_by`, `return_scheduled_at`, `return_completed_at`, `return_missed_at` | timestamptz/uuid | — | sous-workflow d'agendamento de retour |
| `return_schedule_status` | text | `'sem_agendamento'` | **CHECK : `sem_agendamento` / `devolucao_agendada` / `devolucao_realizada` / `devolucao_nao_realizada` / `emprestimo_prorrogado`** |

### 2.2 Fonctions PL/pgSQL existantes

| Fonction | Rôle | Sécurité |
|---|---|---|
| `fn_v2_create_emprestimo_by_holdings(p_user_id, p_holding_ids[], p_due_at, p_notes)` | Création directe par bibliothécaire (prêt comptoir) | DEFINER, vérifie `can_access_painel`, cotisation, exclusion réservation active, calcul de `due_at` via `api.resolve_circulation_rule` |
| `fn_v2_convert_reserva_linhas_to_emprestimo(p_reserva_id, p_line_nos[], p_due_at, p_notes)` | Création depuis une réservation (utilisée par `api.confirm_pickup_v1`) | DEFINER |
| `fn_v2_return_emprestimo_total(p_emprestimo_id, p_notes)` | Retour de toutes les lignes ouvertes | DEFINER |
| `fn_v2_return_emprestimo_linhas(p_emprestimo_id, p_line_nos[], p_notes)` | Retour partiel par ligne | DEFINER |
| `fn_v2_extend_emprestimo_once(p_emprestimo_id)` | Prolongation par bibliothécaire (utilise les règles) | DEFINER |
| `fn_renew_my_loan(p_emprestimo_id)` | Renouvellement par le lecteur | DEFINER, retourne jsonb `{ok, reason, new_due_date}` |
| `fn_v2_refresh_emprestimo_status_global(p_emprestimo_id)` | Recalcul du statut de tête | DEFINER, **logique actuelle binaire `aberto`/`encerrado`** |
| `fn_v2_recompute_from_emprestimo_lines(p_emprestimo_id, p_line_nos[])` | Propagation post-action sur les lignes | DEFINER |
| `fn_v2_schedule_emprestimo_return / clear_emprestimo_return_schedule / mark_emprestimo_return_missed` | Sous-workflow d'agendamento de retour | DEFINER |
| `fn_is_loan_blocked_by_dues(p_user_id, p_library_id)` | Vérification cotisation à jour | DEFINER |
| `api.get_due_date_for_loan / get_due_date_after_renewal / get_remaining_renewals / get_batch_loan_projection` | Calculs publics utilisés par le frontend pour afficher les projections de dates | DEFINER |

### 2.3 Triggers de notification

| Trigger | Table | Événements émis |
|---|---|---|
| `trg_notify_emprestimo_lifecycle` | `emprestimo_itens_v2` | `emprestimo_v2_criado` (INSERT), `emprestimo_v2_devolvido` (item_status `aberto` → `devolvido`) |
| `trg_notify_emprestimo_prorrogacao` | `emprestimos_v2` | `emprestimo_v2_prorrogado` (extended_once `false` → `true`) |

Le routage côté Edge Function `notify-event` consomme ces événements (handler `handleEmprestimoV2`).

### 2.4 Toggles de notification (`library_notification_policies`)

Trois toggles directement liés aux emprunts :

- `loan_lifecycle_enabled` — création/retour/prorogation
- `loan_reminders_enabled` — rappels J-5, J-3, jour J avant échéance
- `loan_overdue_enabled` — relances J+1, J+7, J+30 après échéance
- `admin_copy_loans_enabled` — copie carbone aux bibliothécaires

Default : tous à `true`.

### 2.5 Surfaces UI existantes

**Côté lecteur (`AccountPage.jsx`)** : onglet `Empréstimos em curso` — affiche les emprunts actifs avec date de retour et bouton de renouvellement (appelle `rpc('fn_renew_my_loan', {...})`). Onglet `Histórico` — emprunts clôturés.

**Côté bibliothécaire (`PanelPage.jsx`)** : onglet emprunts — création (prêt comptoir, sélection de holdings), retour total/partiel, renouvellement (prorrogação), agendamento de retour. Le code production est largement opérationnel.

### 2.6 Constats critiques relevés à la lecture du code

1. **Statut intermédiaire absent.** Le CHECK constraint sur `emprestimos_v2.status_global` ne couvre que `aberto`/`encerrado`, et `fn_v2_refresh_emprestimo_status_global` retourne aussi seulement ces deux valeurs. Pour un emprunt multi-items dont une partie a été rendue, le statut tête reste `aberto` sans signal de retour partiel. Q3 confirmée par toi : on veut un `parcialmente_devolvido`.

2. **Bug dans `fn_renew_my_loan` (ligne 6192 du dump).** La fonction joint `reserva_itens_v2` qui n'existe pas — la table réelle est `reserva_linhas_v2`. Conséquence : la vérification "réservé par un autre lecteur" échoue silencieusement (ou plus probablement raise une erreur SQL bloquant tout renouvellement par lecteur). À fixer.

3. **`fn_renew_my_loan` ne lit pas la règle de circulation.** Elle prend la première règle `renewable=true` du premier policy_set actif, sans contextualisation par lecteur/livre/holding/quantité. Pas catastrophique mais incohérent avec `fn_v2_extend_emprestimo_once` (côté biblio) qui passe par `api.resolve_circulation_rule`. À aligner pour que les règles bloquantes soient les mêmes des deux côtés.

4. **`fn_renew_my_loan` ne vérifie pas le quota de renouvellements (`renewal_max_count`).** Elle se contente du flag `extended_once` (booléen). Si une biblio configure `renewal_max_count = 3`, le lecteur reste limité à 1. À aligner.

5. **Aucune vue api.* listée pour les emprunts côté lecteur** dans la sortie SQL. Il y a `api.emprestimo_itens_ui`, `api.emprestimo_itens_painel_ui`, `api.emprestimo_lotes_painel_ui`, mais pas de `api.my_loans_active_v2` symétrique à `api.my_reservations_active_v2`. À confirmer (peut-être qu'`emprestimo_itens_ui` joue ce rôle), à formaliser dans la spec.

6. **Pas de wrapper `api.*` côté lecteur pour le renouvellement.** Le frontend appelle directement `fn_renew_my_loan` (SECURITY DEFINER, schéma `public`). Cohérent avec le pattern actuel mais à vérifier en termes de sécurité (la fonction filtre bien sur `auth.uid() = e.user_id`).

---

## 3. Vocabulaire et libellés

### 3.1 Libellés humains (PT-BR canonique)

| Statut machine | PT-BR (lecteur) | PT-BR (biblio) | Couleur sémantique |
|---|---|---|---|
| `aberto` (item) | Em meu poder | Em circulação | neutre |
| `devolvido` (item) | Devolvido | Devolvido | neutre |
| `aberto` (tête, tous items dehors) | Empréstimo em curso | Empréstimo aberto | bleu |
| `parcialmente_devolvido` (tête, **nouveau**) | Devolução parcial | Devolução parcial | jaune |
| `encerrado` (tête, tous items rendus) | Empréstimo encerrado | Empréstimo encerrado | gris |

État dérivé pour l'UI lecteur :
- `normal` — `due_at >= today + 5j`
- `bientôt à rendre` — `due_at` dans les 5 jours
- `em atraso` — `due_at < today` ET au moins une ligne `aberto`

### 3.2 Motifs de refus de renouvellement (`fn_renew_my_loan` returns)

| `reason` | PT-BR | EN | FR |
|---|---|---|---|
| `not_authenticated` | Sessão expirada. Faça login. | Session expired. Please log in. | Session expirée. Reconnecte-toi. |
| `not_found` | Empréstimo não encontrado. | Loan not found. | Emprunt introuvable. |
| `already_extended` | Já renovado uma vez. | Already renewed once. | Déjà renouvelé une fois. |
| `quota_exceeded` (**nouveau**) | Limite de renovações atingida. | Renewal limit reached. | Limite de renouvellements atteinte. |
| `overdue` | Empréstimo em atraso. Devolva antes de renovar. | Loan overdue. Return before renewing. | Emprunt en retard. Rends avant de renouveler. |
| `reserved_by_other` | Reservado por outra pessoa. | Reserved by another reader. | Réservé par un⋅e autre lecteur⋅rice. |
| `not_renewable` (**nouveau**) | Item não renovável segundo a política. | Item not renewable per policy. | Document non renouvelable selon le règlement. |
| `dues_blocked` (**nouveau**) | Contribuição em atraso ou ausente. | Membership dues unpaid. | Cotisation en retard ou non versée. |

### 3.3 Clés i18n à ajouter (× 6 locales : pt-BR, fr, es, en, it, de)

```
account.loan.status.em_curso
account.loan.status.parcialmente_devolvido
account.loan.status.encerrado
account.loan.state.normal
account.loan.state.dueSoon
account.loan.state.overdue
account.loan.action.renew
account.loan.action.renew.confirm
account.loan.renew.success
account.loan.renew.denied.{reason}    # 8 reasons
panel.loan.status.aberto
panel.loan.status.parcialmente_devolvido
panel.loan.status.encerrado
panel.loan.action.create
panel.loan.action.return.total
panel.loan.action.return.partial
panel.loan.action.extend
panel.loan.create.dueDateAuto
panel.loan.create.dueDateOverride
```

Total estimé : ~25 nouvelles clés × 6 locales = 150 traductions.

Conventions militantes appliquées :
- pt-BR : forme triple `do/da/de` pour les références personnelles (cf. backlog #77)
- fr : point médian `lecteur·rice`
- es : neutre `e` argentin (`lectore`)
- it : épicène `compagn*o` (jamais `camerati`)
- de : Genderstern `Genoss*in`

---

## 4. Modèle de données — évolutions

### 4.1 Migration `emprestimos_v2.status_global` — ajout de `parcialmente_devolvido`

```sql
-- Migration : 20260510_emprestimo_status_partial.sql
ALTER TABLE public.emprestimos_v2
  DROP CONSTRAINT IF EXISTS emprestimos_v2_status_global_chk;

ALTER TABLE public.emprestimos_v2
  ADD CONSTRAINT emprestimos_v2_status_global_chk
  CHECK (status_global = ANY (ARRAY[
    'aberto'::text,
    'parcialmente_devolvido'::text,
    'encerrado'::text
  ]));
```

### 4.2 Réécriture de `fn_v2_refresh_emprestimo_status_global`

```sql
CREATE OR REPLACE FUNCTION public.fn_v2_refresh_emprestimo_status_global(p_emprestimo_id bigint)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_total int := 0;
  v_open  int := 0;
  v_new_status text;
BEGIN
  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE item_status = 'aberto')
    INTO v_total, v_open
  FROM public.emprestimo_itens_v2
  WHERE emprestimo_id = p_emprestimo_id;

  IF v_total = 0 THEN
    v_new_status := 'encerrado';
  ELSIF v_open = 0 THEN
    v_new_status := 'encerrado';
  ELSIF v_open = v_total THEN
    v_new_status := 'aberto';
  ELSE
    v_new_status := 'parcialmente_devolvido';
  END IF;

  UPDATE public.emprestimos_v2
     SET status_global = v_new_status,
         updated_at = now()
   WHERE id = p_emprestimo_id;

  RETURN v_new_status;
END;
$$;
```

Cette logique reproduit exactement le pattern de `fn_v2_refresh_reserva_status_global` (qui sait déjà gérer `parcialmente_encerrada`).

### 4.3 Migration `emprestimos_v2.renewals_used` — compteur explicite

Pour supporter `renewal_max_count > 1` (multi-renouvellements selon politique de circulation), ajouter un compteur dédié plutôt que de dériver d'un booléen.

```sql
-- Migration : 20260510_emprestimo_renewals_used.sql
ALTER TABLE public.emprestimos_v2
  ADD COLUMN IF NOT EXISTS renewals_used int NOT NULL DEFAULT 0;

-- Backfill : si extended_once = true, renewals_used = 1
UPDATE public.emprestimos_v2
   SET renewals_used = 1
 WHERE extended_once = true AND renewals_used = 0;

-- Trigger qui maintient extended_once en sync avec renewals_used
-- (rétrocompat : le frontend peut continuer à lire extended_once pendant la transition)
CREATE OR REPLACE FUNCTION public.trg_sync_extended_once_from_renewals()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.extended_once := (COALESCE(NEW.renewals_used, 0) >= 1);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_emprestimo_sync_extended_once
BEFORE INSERT OR UPDATE OF renewals_used ON public.emprestimos_v2
FOR EACH ROW EXECUTE FUNCTION trg_sync_extended_once_from_renewals();
```

**Conséquence pour les fonctions** :
- `fn_renew_my_loan` et `fn_v2_extend_emprestimo_once` font `renewals_used = renewals_used + 1` au lieu de `extended_once = true`. Le trigger met `extended_once` à jour automatiquement.
- Le frontend peut continuer à lire `extended_once` (transition douce) ou basculer sur `renewals_used` (préféré à terme).

### 4.4 Aucune autre évolution structurelle nécessaire

Les colonnes existantes (`extended_until`, `return_schedule_status`, `holding_id`, etc.) couvrent l'ensemble des besoins fonctionnels.

---

## 5. Matrice des transitions

### 5.1 Cycle de vie d'un emprunt (vue agrégée)

```
                   [création directe]                [via réservation]
                   PanelPage              api.confirm_pickup_v1
                   fn_v2_create…              fn_v2_convert_reserva…
                            \                   /
                             \                 /
                              ▼               ▼
                          ┌──────────────────────┐
                          │  status_global =     │
                          │  'aberto'            │
                          │  (au moins 1 item    │
                          │   item_status =      │
                          │   'aberto')          │
                          └──────────┬───────────┘
                                     │
                ┌────────────────────┼────────────────────┐
                │                    │                    │
                ▼                    ▼                    ▼
      [renouvellement]     [retour partiel]     [retour total]
      fn_v2_extend_         fn_v2_return_         fn_v2_return_
      emprestimo_once       emprestimo_linhas     emprestimo_total
      OU                    (un sous-ensemble     (toutes lignes)
      fn_renew_my_loan      des lignes)
                                     │                    │
                                     ▼                    │
                            ┌──────────────────┐          │
                            │ status_global =  │          │
                            │ 'parcialmente_   │          │
                            │  devolvido'      │          │
                            └────────┬─────────┘          │
                                     │                    │
                                     ▼                    ▼
                           [retour des lignes      ┌─────────────┐
                            restantes]             │ status_     │
                                     │             │ global =    │
                                     └────────────►│ 'encerrado' │
                                                   └─────────────┘
```

### 5.2 Règles de renouvellement (lecteur ET bibliothécaire — Q1 = mêmes règles)

Toutes les conditions doivent être vraies pour qu'un renouvellement soit autorisé :

| Condition | Source | Si faux : `reason` retourné |
|---|---|---|
| Lecteur authentifié | `auth.uid() IS NOT NULL` | `not_authenticated` |
| Emprunt existe et appartient au lecteur (côté lecteur) ou est dans la biblio active (côté biblio) | jointure user_id / library_id | `not_found` |
| Cotisation à jour | `fn_is_loan_blocked_by_dues = false` | `dues_blocked` |
| Règle de circulation a `renewable = true` | `api.resolve_circulation_rule(p_mode='loan_renewal')` | `not_renewable` |
| Quota non épuisé : `renewals_used < renewal_max_count` (avec `renewal_max_count` issu de la règle de circulation, default 1) | `api.get_remaining_renewals` | `quota_exceeded` |
| Pas en retard : `COALESCE(extended_until, due_at) >= CURRENT_DATE` | calcul direct | `overdue` |
| Aucune réservation active sur le même `book_id` dans la même biblio par un autre lecteur | `reserva_linhas_v2` joint avec `reservas_v2 status_global IN ('ativa', 'parcialmente_encerrada')` | `reserved_by_other` |

**Effet en cas de succès** :
- `renewals_used` incrémenté de 1 (le trigger met `extended_once` à jour automatiquement pour rétrocompat)
- `extended_until` calculé via `api.get_due_date_after_renewal`
- `extension_note` = `'renewal_by_reader'` ou `'renewal_by_library'`
- Trigger `trg_notify_emprestimo_prorrogacao` se déclenche

### 5.3 Règles de retour (total ou partiel)

Aucune règle bloquante côté retour : le retour est toujours autorisé. Effets en cascade :

1. `emprestimo_itens_v2.item_status` passe à `'devolvido'`, `returned_at = now()`
2. Le trigger `trg_notify_emprestimo_lifecycle` émet `emprestimo_v2_devolvido`
3. `fn_v2_recompute_from_emprestimo_lines` est appelée
4. `fn_v2_refresh_emprestimo_status_global` recalcule le statut tête (`aberto` / `parcialmente_devolvido` / `encerrado`)
5. Le compteur `book_holdings.available_count` est incrémenté
6. Si une réservation `solicitada` existe sur le même book_id, la mise en disponibilité peut déclencher la transition `solicitada → em_preparacao` (hors périmètre de cette spec, voir spec-workflow-reservation.md)

### 5.4 Création directe (prêt comptoir)

`fn_v2_create_emprestimo_by_holdings` (déjà en prod) effectue les validations suivantes :

1. Authentification + `can_access_painel = true`
2. `library_id` cohérente entre actor et tous les holdings
3. Cotisation du lecteur cible à jour (`fn_is_loan_blocked_by_dues`)
4. Tous les holdings existent et appartiennent à la biblio active
5. Tous les holdings sont prêtables (`loanable = true`)
6. Pas de réservation active concurrente sur ces holdings
7. Au moins un exemplaire libre par holding (pas déjà emprunté ni réservé sur l'item précis)
8. Calcul de `due_at` via `api.resolve_circulation_rule(p_mode='loan')`, fallback legacy 21/30/38 jours selon quantité

Tout cela est **conservé tel quel**.

### 5.5 Création depuis réservation

`api.confirm_pickup_v1` (couvert par spec-workflow-reservation.md) appelle en interne `fn_v2_convert_reserva_linhas_to_emprestimo`. La spec emprunts ne touche pas à ce chemin, sauf à vérifier que les `reserva_id` et `reserva_line_no` sont bien remplis dans les `emprestimo_itens_v2` créés (traçabilité).

---

## 6. RPC publiques — contrats

### 6.1 Renouvellement lecteur — `fn_renew_my_loan` (à corriger)

**Signature** : `fn_renew_my_loan(p_emprestimo_id bigint) RETURNS jsonb`

**Contrat retour** :
```jsonc
{
  "ok": true | false,
  "reason": "renewed" | "not_authenticated" | "not_found" |
            "already_extended" | "quota_exceeded" | "overdue" |
            "reserved_by_other" | "not_renewable" | "dues_blocked",
  "new_due_date": "2026-05-31"  // uniquement si ok=true
}
```

**Corrections à appliquer** (Phase 1) :
1. Remplacer `reserva_itens_v2` (inexistante) par `reserva_linhas_v2` ligne 6192 du dump
2. Ajouter le check `fn_is_loan_blocked_by_dues`
3. Passer par `api.resolve_circulation_rule(p_mode='loan_renewal')` au lieu de prendre la première règle renewable
4. Lire `renewal_max_count` et comparer à `renewals_used` (nouvelle colonne, cf. §4.3)
5. Calculer `new_due_date` via `api.get_due_date_after_renewal` plutôt qu'une addition naïve
6. Incrémenter `renewals_used = renewals_used + 1` au lieu de `extended_once = true` (le trigger §4.3 maintient `extended_once` en sync)

### 6.2 Renouvellement bibliothécaire — `fn_v2_extend_emprestimo_once`

Existe déjà. À aligner pour qu'elle :
1. Retourne le même contrat jsonb que `fn_renew_my_loan` (pour symétrie d'UX)
2. Applique les mêmes 8 règles bloquantes (cf. §5.2)

À déplacer dans `api.*` sous le nom `api.extend_loan_as_library(p_emprestimo_id bigint) RETURNS jsonb` pour cohérence avec les wrappers réservation.

### 6.3 Création directe — `api.create_loan_at_counter`

**Nouveau wrapper** côté `api.*`, qui appelle `fn_v2_create_emprestimo_by_holdings` :

```sql
CREATE OR REPLACE FUNCTION api.create_loan_at_counter(
  p_user_id uuid,
  p_holding_ids bigint[],
  p_due_at date DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER
AS $$
  SELECT jsonb_build_object(
    'ok', r.ok,
    'emprestimo_id', r.emprestimo_id,
    'due_at', r.due_at,
    'message', r.message
  )
  FROM public.fn_v2_create_emprestimo_by_holdings(
    p_user_id, p_holding_ids, p_due_at, p_notes
  ) r;
$$;
```

### 6.4 Retour total — `api.return_loan_total`

Wrapper `api.*` autour de `fn_v2_return_emprestimo_total`. Idempotent : si tout est déjà rendu, retourne `{ok: true, returned_count: 0}`.

### 6.5 Retour partiel — `api.return_loan_lines`

Wrapper `api.*` autour de `fn_v2_return_emprestimo_linhas`. Vérifie que les `line_nos` appartiennent bien à l'emprunt et sont actuellement `aberto`.

### 6.6 Annulation lecteur d'un renouvellement — non supporté

Volontairement non couvert. Une fois renouvelé, c'est renouvelé. Le bibliothécaire peut toujours annuler manuellement via une RPC d'urgence (à créer si besoin se présente, hors spec).

---

## 7. Triggers et notifications

### 7.1 Triggers existants — conservés tels quels

| Trigger | Évolution | Note |
|---|---|---|
| `trg_notify_emprestimo_lifecycle` | Aucune | OK pour création + retour |
| `trg_notify_emprestimo_prorrogacao` | Aucune | OK pour les deux chemins de prorogation |

### 7.2 Événement `emprestimo_v2_parcialmente_devolvido` — à créer

Quand un retour partiel fait passer un emprunt de `aberto` à `parcialmente_devolvido`, un événement dédié doit être émis pour informer le lecteur (« il vous reste 2 livres à rendre, voici la liste »).

**Implémentation** : étendre `trg_notify_emprestimo_lifecycle` pour détecter le changement d'agrégat. Comme le trigger est sur les items et pas sur la tête, deux options :

**Option A — Trigger AFTER UPDATE sur `emprestimos_v2.status_global`** (préférée, propre).
**Option B — Logique dans `fn_v2_recompute_from_emprestimo_lines`** (couplage fonction/trigger, moins propre).

Option A retenue.

```sql
CREATE OR REPLACE FUNCTION public.trg_notify_emprestimo_status_change()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status_global IS DISTINCT FROM NEW.status_global THEN
    IF NEW.status_global = 'parcialmente_devolvido' THEN
      PERFORM fn_dispatch_circulation_notify_event('emprestimo_v2_parcialmente_devolvido', NEW.id);
    ELSIF NEW.status_global = 'encerrado' AND OLD.status_global = 'parcialmente_devolvido' THEN
      -- Retour de la dernière ligne d'un emprunt déjà partiellement rendu :
      -- pas de notif spécifique, le lifecycle l'a déjà émise au niveau de l'item
      NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_emprestimo_status_change
AFTER UPDATE OF status_global ON public.emprestimos_v2
FOR EACH ROW EXECUTE FUNCTION trg_notify_emprestimo_status_change();
```

### 7.3 Handler Edge Function

Dans `notify-event/handlers/emprestimos.ts` (existant), ajouter le case `emprestimo_v2_parcialmente_devolvido` qui mobilise un nouveau bloc i18n :

```
mail.emprestimo.partialReturn.subject
mail.emprestimo.partialReturn.body
mail.emprestimo.partialReturn.remainingTitle
mail.emprestimo.partialReturn.remainingItem      (× n items)
mail.emprestimo.partialReturn.dueDateNote
```

× 6 locales = 30 nouvelles clés.

### 7.4 Toggle dédié

Ajouter à `library_notification_policies` :

```sql
ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS loan_partial_return_enabled boolean NOT NULL DEFAULT true;
```

Lu par le trigger `trg_notify_emprestimo_status_change` avant émission.

---

## 8. Surfaces UI

### 8.1 AccountPage.jsx — `Empréstimos em curso`

Pour chaque emprunt actif, affiche :

- Couverture (miniature `holdings.cover_url` ou fallback)
- Titre, auteur, biblio (avec lien vers `livro.html?bookId=…&libraryId=…`)
- Date de prêt + date de retour (avec `extended_until` prioritaire si présent)
- État dérivé : `normal` / `bientôt à rendre` / `em atraso`
- Bouton **Renovar**, désactivé avec tooltip explicatif si l'une des règles bloque (cf. §5.2). Le tooltip doit afficher la `reason` traduite.
- Si `status_global = 'parcialmente_devolvido'` : badge jaune "Devolução parcial" + liste des items déjà rendus en gris

**Pré-affichage des règles bloquantes** : avant que le lecteur ne clique sur Renovar, on appelle au chargement `api.get_remaining_renewals` pour chaque emprunt afin de pré-désactiver le bouton et afficher la `reason`. Cela évite l'effet « je clique, je suis refusé » et expose les règles à la lecture.

### 8.2 AccountPage.jsx — `Histórico` (déjà couvert §2.1 du doc Dunkerque)

Pas d'évolution dans cette spec, mais s'assurer que `parcialmente_devolvido` ne pollue pas l'historique : le filtre actif/historique se fait sur `status_global IN ('aberto', 'parcialmente_devolvido')` côté actif et `= 'encerrado'` côté historique.

### 8.3 PanelPage.jsx — onglet emprunts

- Création d'emprunt comptoir : recherche lecteur, sélection holdings (multi-select), bouton "Registrar empréstimo". Le `due_at` proposé est calculé en temps réel via `api.get_batch_loan_projection`, modifiable par le bibliothécaire avant validation.
- Liste des emprunts actifs : colonnes Lecteur, Items, Date emprunt, Date retour, État. Tri par date de retour (les plus urgents en haut).
- Actions par ligne :
  - **Devolver tudo** (`api.return_loan_total`)
  - **Devolver itens selecionados** (`api.return_loan_lines`)
  - **Prorrogar** (`api.extend_loan_as_library`) — désactivé avec tooltip si une règle bloque
  - **Agendar devolução** (sous-workflow existant)
- Filtre par statut : `aberto` / `parcialmente_devolvido` / `encerrado` (filtre clair sur le badge couleur).

### 8.4 livro.html — disponibilité reflétée

Si un exemplaire est en `emprestimo_itens_v2.item_status = 'aberto'`, il est affiché comme indisponible avec date de retour estimée (`COALESCE(extended_until, due_at)`). Si un emprunt parent passe à `parcialmente_devolvido`, les items déjà rendus redeviennent disponibles automatiquement (via `book_holdings.available_count` recalculé par `fn_v2_recompute_from_emprestimo_lines`). Pas de logique frontend spécifique nécessaire.

---

## 9. Phases d'implémentation

### Phase 1 — Corrections critiques DB (1 demi-journée)

1. Migration `20260510_emprestimo_status_partial.sql` : étend le CHECK + réécrit `fn_v2_refresh_emprestimo_status_global`
2. Migration `20260510_emprestimo_renewals_used.sql` : ajout colonne `renewals_used` + backfill + trigger sync `extended_once`
3. Migration `20260510_fn_renew_my_loan_fixes.sql` : corrige le bug `reserva_itens_v2` → `reserva_linhas_v2`, ajoute `dues_blocked`, branche `api.resolve_circulation_rule`, utilise `renewals_used`
4. Migration `20260510_fn_v2_extend_emprestimo_once_align.sql` : aligne le wrapper biblio sur les mêmes 8 règles et le compteur
5. Tests SQL : 6 cas de retour partiel + 8 cas de renouvellement (un par `reason`) + 2 cas multi-renouvellement (max=3)

### Phase 2 — Wrappers api.* (1 demi-journée)

1. `api.create_loan_at_counter` (wrap autour de `fn_v2_create_emprestimo_by_holdings`)
2. `api.return_loan_total`, `api.return_loan_lines`
3. `api.extend_loan_as_library` (renomme et harmonise `fn_v2_extend_emprestimo_once`)
4. Tests SQL pour chaque wrapper

### Phase 3 — Notification retour partiel (1 demi-journée)

1. Migration : ajout `loan_partial_return_enabled` + trigger `trg_notify_emprestimo_status_change`
2. Edge Function : handler `emprestimo_v2_parcialmente_devolvido` dans `notify-event/handlers/emprestimos.ts`
3. i18n : 30 clés × 6 locales dans `_shared/i18n/mail-strings.ts`
4. Test e2e : retour partiel d'un emprunt 3-items, vérifier mail reçu avec liste des items restants

### Phase 4 — Frontend lecteur (1 journée)

1. AccountPage — pré-chargement `api.get_remaining_renewals` au mount
2. AccountPage — affichage badge `parcialmente_devolvido` + tooltip sur Renovar désactivé
3. AccountPage — bascule des `reason` sur `account.loan.renew.denied.{reason}` (8 clés × 6 locales)
4. AccountPage — historique : filtre sur `status_global = 'encerrado'` uniquement

### Phase 5 — Frontend bibliothécaire (1 journée)

1. PanelPage — refactor liste emprunts pour gérer le nouveau statut intermédiaire
2. PanelPage — pré-calcul du `due_at` en création via `api.get_batch_loan_projection`
3. PanelPage — pré-désactivation Prorrogar avec tooltip si règle bloque

### Phase 6 — Tests runtime (1 demi-journée)

Scénarios à dérouler en prod sur la base wipée du 07/05 :

1. Création comptoir 1 item → confirmation, vérif mail lecteur + copie biblio
2. Création comptoir 3 items, retour de 1 item → vérif `parcialmente_devolvido` + mail
3. Renouvellement lecteur sur emprunt sain → succès
4. Renouvellement lecteur sur emprunt déjà renouvelé → `already_extended`
5. Renouvellement lecteur sur emprunt avec réservation concurrente → `reserved_by_other`
6. Renouvellement biblio avec quota épuisé (configurer `renewal_max_count = 1`) → `quota_exceeded`
7. Création comptoir avec lecteur cotisation expirée → bloqué, message clair
8. Retour total d'emprunt déjà partiellement rendu → `encerrado` direct, pas de double notif

### Phase 7 — Commit et déploiement

Commit unique : `spec flux emprunts phases 1-6 : DB + api wrappers + notification retour partiel + frontend`. Push Codeberg + GitHub.

---

## 10. Points ouverts pour discussion future

### 10.1 Compteur explicite de renouvellements — décision retenue

Décision (10/05/2026) : **colonne dédiée `renewals_used int NOT NULL DEFAULT 0`**, avec trigger qui maintient `extended_once` en sync pour ne pas casser le frontend qui le consulte. Les fonctions `fn_renew_my_loan` et `fn_v2_extend_emprestimo_once` incrémentent `renewals_used`. Permet d'honorer les politiques de circulation où `renewal_max_count > 1`. Détails d'implémentation en §4.3.

### 10.2 Rappels de fin de prêt et relances de retard

Hors périmètre de cette spec : il existe déjà `fn_cron_notify_*` et les toggles `loan_reminders_enabled` / `loan_overdue_enabled`. Dette à confirmer dans une session ultérieure : sont-ils branchés et testés ?

### 10.3 Import historique

Demandé par toi en première itération de cadrage, **non retenu** pour cette spec. Si une biblio (CIRA Marseille, BLMF) en exprime le besoin, ouvrir une spec dédiée `spec-import-historique-emprunts.md` avec format CSV, idempotence, traçabilité de provenance.

### 10.4 Annulation d'emprunt par erreur

Aucun chemin actuel : si un bibliothécaire crée un emprunt par erreur, il doit faire un retour total immédiat. Acceptable pour l'instant, à formaliser si besoin.

---

## 11. Risques et invariants

### 11.1 Invariants à préserver

1. **`available_count` cohérent en tout temps** : tout passage `aberto` ↔ `devolvido` recalcule via `fn_v2_recompute_from_emprestimo_lines`.
2. **Pas de double emprunt sur le même item** : la création vérifie qu'aucun `emprestimo_itens_v2` ouvert n'existe pour l'`item_id`.
3. **Cotisation à jour vérifiée à la création ET au renouvellement** : `fn_is_loan_blocked_by_dues` aux deux endroits.
4. **Notification au plus une fois par transition** : les triggers utilisent `IS DISTINCT FROM` pour éviter les doublons.
5. **`status_global` toujours dérivé des items** : aucun UPDATE direct sur `status_global`, uniquement via `fn_v2_refresh_emprestimo_status_global`.

### 11.2 Risques identifiés

- **Risque #1** : la correction de `fn_renew_my_loan` peut casser le frontend AccountPage qui s'attend au format jsonb actuel. Mitigation : la signature et le contrat `{ok, reason, new_due_date}` sont préservés, on étend uniquement la liste des `reason` possibles. Les nouveaux `reason` doivent être ajoutés à `account.loan.renew.denied.*` AVANT déploiement DB.
- **Risque #2** : changement du CHECK sur `status_global` peut faire échouer des UPDATE en cours si une transaction longue est ouverte. Mitigation : exécuter la migration en heure creuse, vérifier `pg_stat_activity` au préalable.
- **Risque #3** : les `loan_id` retournés par `api.confirm_pickup_v1` pourraient être affichés différemment selon `status_global` initial. À tester en Phase 6 cas 1.

---

## 12. Cohérence avec les autres specs

| Spec | Lien |
|---|---|
| spec-workflow-reservation.md | Définit le chemin de création d'emprunt depuis une réservation (`api.confirm_pickup_v1`). Cette spec récupère le résultat sans le redéfinir. |
| spec-flux-consultation-locale.md | Chaîne sœur indépendante. Aucune interaction sauf via la règle de circulation : un même holding ne peut pas avoir simultanément un emprunt actif ET une consulta active (vérifié par les deux fonctions de création). |
| spec-gouvernance-roles.md | `can_access_painel`, `librarian`/`coordenador` mobilisés dans les vérifications de rôle. Pas d'évolution. |
| spec-validation-physique.md | Indépendante. Le `user_id` utilisé doit être validé physiquement, mais la spec emprunts ne re-vérifie pas (déléguée). |

---

*Spec rédigée le 10/05/2026. À implémenter en 6 phases sur ~3 jours de travail si pris en continu. Les corrections de Phase 1 sont prioritaires : `fn_renew_my_loan` est cassée en prod sur la branche `reserva_itens_v2`.*
