# Spec — Flux des consultations sur place

> **Statut** : rédaction du 10/05/2026 — spec de fermeture (backend largement présent, manques ciblés)
> **Périmètre** : consultations locales (consultas_locais_v2 + consulta_linhas_v2 + consulta_item_workflow_v2). Hors périmètre : prêt local (emprestimos_v2) et prêt inter-bibliothèques.
> **Spec sœur** : spec-flux-emprunts.md (chaîne parallèle pour les emprunts).
> **Doc de référence amont** : `AnarBib_synthese_technique_consultation_holdings.docx` du 30/03/2026.

---

## 1. Contexte et objectif politique

Toute bibliothèque militante héberge des fonds qui ne sortent pas : périodiques rares, dossiers d'archives, brochures fragiles, livres uniques, documents en restauration, ouvrages portés par des contrats de don qui interdisent le prêt. Ces documents constituent souvent le cœur patrimonial d'une biblio anarchiste — la mémoire du mouvement n'a pas vocation à dormir, elle a vocation à être consultée sur place, dans un cadre où la biblio peut accompagner, contextualiser, signaler les précautions de manipulation.

La spec emprunts a sa logique propre : on prend, on ramène. La spec consultation sur place a une logique différente : on annonce sa venue, on convient d'un créneau si la biblio le demande, on consulte sur place, on rentre. C'est une chaîne distincte qui ne doit ni mimer la réservation de prêt, ni s'appuyer sur les mêmes RPC.

L'objectif politique sous-jacent : ne pas laisser les bibliothèques militantes en marge des outils numériques modernes, mais ne pas non plus copier-coller les patterns des SIGB d'institutions publiques où la consultation sur place est traitée comme une variante mineure du prêt. Pour beaucoup de fonds militants, c'est l'inverse : la consultation est l'usage primaire, le prêt l'exception.

**Diagnostic actuel** (issu du Livre blanc v13) : la consultation locale dispose **d'un appareillage SQL complet** (3 tables, 4 vues api, 8 fonctions opérationnelles). Ce qui manque est principalement du **branchement** : trigger de notification absent, handler `notify-event` absent, UI lecteur non câblée, validation Q2 (collision avec réservation) à compléter, helper de validation des transitions à introduire.

Cette spec n'invente donc presque rien sur le plan structurel. Elle stabilise, comble, branche.

---

## 2. État de l'existant au 10/05/2026

### 2.1 Tables

**`consultas_locais_v2`** — agrégat de tête.

| colonne | type | défaut | rôle |
|---|---|---|---|
| `id`, `user_id`, `library_id`, `notes` | bigint/uuid/text | — | identifiants et note libre |
| `status_global` | text | `'ativa'` | **CHECK : `ativa` / `parcialmente_encerrada` / `encerrada`** ✓ |
| `created_at`, `updated_at` | timestamptz | `timezone('utc', now())` | |

**`consulta_linhas_v2`** — lignes (un item par holding demandé).

| colonne | type | défaut | rôle |
|---|---|---|---|
| `id`, `consulta_id`, `line_no`, `sub_id` | — | — | identifiants |
| `book_id`, `holding_id`, `bib_ref` | bigint/text | — | livre, holding (NOT NULL), ref locale |
| `titulo_cache`, `autor_cache`, `editora_cache`, `ano_cache` | text | — | snapshot bibliographique |
| `item_status` | text | `'ativa'` | **CHECK : `ativa` / `consultada` / `cancelada_leitor` / `cancelada_biblioteca` / `expirada`** |
| `expires_at` | timestamptz | — | échéance de validité de la demande |
| `cancelled_at`, `consulted_at`, `expired_at`, `dismissed_by_reader_at` | timestamptz | — | timestamps de transition (avec CHECK de cohérence) |
| `notes` | text | — | note libre |

**`consulta_item_workflow_v2`** — sous-workflow de planification.

| colonne | type | défaut | rôle |
|---|---|---|---|
| `id`, `consulta_id`, `line_no` | — | — | identifiants (UNIQUE sur (consulta_id, line_no)) |
| `workflow_stage` | text | `'solicitada'` | **CHECK : `solicitada` / `em_preparacao` / `consulta_agendada` / `consulta_realizada` / `nao_compareceu` / `cancelada_leitor` / `cancelada_biblioteca` / `expirada`** |
| `workflow_note` | text | — | |
| `consultation_scheduled_for` | timestamptz | — | créneau initialement proposé (single timestamp) |
| `consultation_starts_at`, `consultation_ends_at` | timestamptz | — | fenêtre précise (avec CHECK ends > starts) |
| `schedule_reply_status` | text | — | **CHECK : `confirmado_leitor` / `recusado_leitor`** (nullable) |
| `schedule_reply_note`, `schedule_reply_at` | text/timestamptz | — | trace de la réponse lecteur |
| `updated_at`, `updated_by` | timestamptz/uuid | — | audit |

### 2.2 Configuration biblio (`library_service_state` — déjà couvert §2.4 spec emprunts)

Pertinent pour cette spec :
- `service_mode` : `funcionamento_normal` / `somente_consulta` / `pausada`
- `consultation_timezone` (default `'America/Belem'`)
- `max_simultaneous_consultations` (default 1)
- `consultation_schedule_struct` (jsonb des plages horaires de consultation)
- `service_schedule_text` (jsonb des messages d'ouverture publique)

Ces colonnes sont **déjà en place** et alimentées par la page `BibliotecaPage` (configuration biblio).

### 2.3 Fonctions PL/pgSQL existantes

| Fonction | Rôle | Sécurité |
|---|---|---|
| `fn_v2_create_consulta_local_by_holdings(p_user_id, p_holding_ids[], p_expires_at, p_notes)` | **Création publique** par lecteur | DEFINER, vérifie auth, mode biblio (`pausada`/`allows_new_reservations=false`), holdings cohérents, doublon, règle de circulation |
| `fn_v2_cancel_consulta_linhas_as_leitor(p_consulta_id, p_line_nos[], p_notes)` | Annulation lecteur | DEFINER |
| `fn_v2_dismiss_consulta_cancelled_as_leitor(p_consulta_id, p_line_nos[], p_note)` | Lecteur masque une consulta annulée par la biblio (de l'historique actif) | DEFINER |
| `fn_v2_set_consulta_linhas_workflow(p_consulta_id, p_line_nos[], p_workflow_stage, p_workflow_note, p_consultation_scheduled_for)` | Avancement workflow biblio (ancien path, créneau simple) | DEFINER, **sans helper de transition** |
| `fn_v2_set_consulta_linhas_workflow_slot(...)` | Avancement workflow biblio avec fenêtre date+heures locales | DEFINER |
| `fn_v2_set_consulta_linhas_schedule_reply(p_consulta_id, p_line_nos[], p_reply_status, p_note)` | Réponse du lecteur au créneau proposé | DEFINER |
| `fn_validate_consulta_schedule_window(p_library_id, p_consulta_id, p_starts_at, p_ends_at)` | Vérifie qu'un créneau tombe dans une plage `consultation_schedule_struct` | DEFINER |
| `fn_v2_refresh_consulta_status_global(p_consulta_id)` | Recalcul statut tête | DEFINER |

### 2.4 Vues api.* existantes

| Vue | Usage | État |
|---|---|---|
| `api.my_consultas_active_v2` | Compte lecteur — consultations actives | ✓ existe |
| `api.my_consultas_history_v2` | Compte lecteur — historique | ✓ existe |
| `api.consulta_itens_ui` | Painel — liste de base | ✓ existe |
| `api.consulta_itens_followup_ui` | Painel — vue de suivi (statuts + actions) | ✓ existe |

### 2.5 Constats critiques

1. **Aucun trigger de notification.** Le dump confirme : pas de `trg_notify_consulta_*`. Les transitions de workflow ne déclenchent aucun événement vers `notify-event`.

2. **Aucun handler dans `notify-event`.** À confirmer en lisant le code TS de l'Edge Function — mais le toggle `local_consultation_enabled` existe dans `library_notification_policies` sans consommateur SQL ni handler côté Edge Function.

3. **Helper de validation des transitions absent.** `fn_v2_set_consulta_linhas_workflow` accepte une whitelist plate de stages cibles (`'em_preparacao'`, `'consulta_agendada'`, `'consulta_realizada'`, `'nao_compareceu'`, `'cancelada_biblioteca'`, `'expirada'`) sans contrôler le stage source. Conséquence : un bibliothécaire peut passer une consulta de `solicitada` directement à `consulta_realizada`, ce qui est métiergquement absurde.

4. **Q2 non implémentée.** `fn_v2_create_consulta_local_by_holdings` vérifie le doublon de consulta sur le même holding pour le même utilisateur, mais ne vérifie pas qu'aucune réservation active existe sur ce holding (Q2 = oui parallèlement, mais pas si une réservation existe sur le même holding). À ajouter.

5. **Q1 non implémentée (mode biblio détermine si créneau obligatoire).** Aucune logique conditionnée par `service_mode = 'somente_consulta'` qui forcerait `consultation_scheduled_for IS NOT NULL`. Pour l'instant `fn_v2_set_consulta_linhas_workflow` impose le créneau seulement si on cible `consulta_agendada`. À étendre.

6. **Pas de cron d'expiration.** Pas de job pg_cron `fn_expire_solicitada_consultas` symétrique à celui des réservations. Si une consulta `solicitada` reste sans réponse, elle n'expire jamais automatiquement.

7. **Pas de wrappers `api.*` pour les actions de transition.** Le frontend appelle directement `fn_v2_set_consulta_linhas_workflow*`. À encapsuler pour cohérence avec le pattern `api.*` adopté pour les réservations.

8. **UI lecteur partiellement câblée — création OK, suivi à compléter.** Audit du frontend (10/05/2026) :
   - `AccountPage.jsx` charge bien `apiQuery('my_consultas_active_v2')` et affiche les consultations dans un sous-bloc de l'onglet `reservar` (ligne 782, titre `account.consultations.active`).
   - **Le parcours de création est unifié et fonctionnel** (lignes 159-256) : un même bouton bascule entre `fn_v2_create_reserva_by_holdings` et `fn_v2_create_consulta_local_by_holdings` selon `mode === 'consult'`.
   - **Manquent côté lecteur** : (a) onglet dédié `Consultas no local` séparé de `reservar` (décision 10/05 : on sépare, cf. doc Dunkerque §7.3), (b) badge stage par item, (c) sous-workflow `schedule_reply` (boutons Confirmer / Recusar horário), (d) action terminale `Cancelar pedido` côté lecteur.

9. **UI bibliothécaire câblée a minima — workflow basique seulement.** Audit du frontend :
   - `PanelPage.jsx` a un onglet `consultas-locais` (ligne 883) qui consomme `api.consulta_itens_followup_ui` (ligne 278).
   - Une seule RPC consulta câblée : `fn_v2_set_consulta_linhas_workflow` via la fonction `setConsultaWorkflow` (ligne 606-608).
   - Stages cibles atteignables depuis l'UI actuelle : `em_preparacao`, `consulta_agendada` (avec timestamp simple, pas de fenêtre), `consulta_realizada`, `cancelada_biblioteca`.
   - **Manquent côté biblio** : (a) appel à `fn_v2_set_consulta_linhas_workflow_slot` pour proposer une fenêtre date/heures structurée, (b) bouton `nao_compareceu`, (c) lecture/affichage du `schedule_reply_status` du lecteur (la biblio ne sait pas si le lecteur a confirmé ou refusé), (d) grisage des transitions invalides (réplique JS de `fn_check_consulta_workflow_transition`).

---

## 3. Vocabulaire et libellés

### 3.1 Mapping stage → libellé public PT-BR (canonique)

| `workflow_stage` | Libellé lecteur | Libellé bibliothécaire | Couleur |
|---|---|---|---|
| `solicitada` | Pedido enviado | Solicitada | bleu |
| `em_preparacao` | Pedido em preparação | Em preparação | bleu |
| `consulta_agendada` | Consulta agendada para [date] | Consulta agendada | jaune |
| `consulta_realizada` | Consulta realizada | Consulta realizada | gris |
| `nao_compareceu` | Não compareceu na data combinada | Não compareceu | rouge |
| `cancelada_leitor` | Você cancelou este pedido | Cancelada pelo(a/e) leitor(a/e) | gris |
| `cancelada_biblioteca` | Pedido cancelado pela biblioteca | Cancelada pela biblioteca | gris |
| `expirada` | Pedido expirado sem resposta | Expirada | gris |

État dérivé pour le lecteur : si `schedule_reply_status IS NULL` ET `workflow_stage IN ('em_preparacao', 'consulta_agendada')` ET `consultation_scheduled_for IS NOT NULL` → afficher **« Resposta necessária »** + boutons Confirmar / Recusar.

### 3.2 Boutons UI

| Action | Lecteur | Bibliothécaire |
|---|---|---|
| Créer une demande | « Reservar consulta » (livro.html, index.html) | n/a (le lecteur crée) |
| Confirmer un créneau proposé | « Confirmar horário » | — |
| Refuser un créneau proposé | « Recusar horário » | — |
| Annuler une demande | « Cancelar pedido » | — |
| Avancer le workflow | — | « Mover para em preparação » / « Propor horário » / « Marcar como realizada » / « Marcar como não compareceu » |
| Proposer/reprogrammer un créneau | — | « Propor horário » / « Reagendar » |
| Annuler côté biblio | — | « Cancelar (biblioteca) » |

### 3.3 Clés i18n à ajouter (× 6 locales)

**Clés déjà présentes** (audit 10/05/2026, locale pt-BR) — à ne PAS dupliquer :
`account.consultations.active`, `account.consultations.empty`, `account.reserve.creatingConsult`, `account.reserve.consultationRegistered`, `account.reserve.consultationOnlyHint`, `account.reserve.maxConsult`, `account.reserve.noteConsult`, `account.reserve.pasteHintConsult`, `account.service.consultOnly`, `panel.consultations.active`, `panel.consultation.cancelledByPanel`, `panel.openConsultations`, `panel.summary.pendingConsultations`, `panel.tab.consultations`, `panel.tab.consultations.hint`, `panel.task.consultToProcess`, `panel.workflow.scheduled`, `panel.workflow.done`, `notif.type.local_consultation`, `privacy.retention.consultations`.

**Clés à ajouter** :

```
# Lecteur (nouvel onglet dédié)
account.tab.consultations                    # libellé de l'onglet
account.tab.consultations.hint               # tooltip de l'onglet
account.consultation.status.{stage}          # 8 stages (solicitada, em_preparacao,
                                              # consulta_agendada, consulta_realizada,
                                              # nao_compareceu, cancelada_leitor,
                                              # cancelada_biblioteca, expirada)
account.consultation.action.confirmSlot
account.consultation.action.refuseSlot
account.consultation.action.cancel
account.consultation.scheduleReply.required
account.consultation.scheduleReply.confirmed
account.consultation.scheduleReply.refused
account.consultation.window.format           # "{date} de {start} a {end}"

# Bibliothécaire — enrichissement de l'onglet existant
panel.consultation.status.{stage}            # 8 stages (cohérence avec lecteur)
panel.consultation.action.proposeSlot        # popup date+heures
panel.consultation.action.reschedule
panel.consultation.action.markNoShow
panel.consultation.action.cancel.askReason
panel.consultation.transitionBlocked         # avec interpolation {stages}
panel.consultation.scheduleWindow.outOfBounds
panel.consultation.scheduleReply.confirmed
panel.consultation.scheduleReply.refused
panel.consultation.scheduleReply.pending

# Catalogue public (sur livro / index)
book.action.reserveConsultation
book.consultation.modeOnlyAvailable
book.consultation.requiresSchedule

# Mails
mail.consulta.created.subject / .body
mail.consulta.em_preparacao.subject / .body
mail.consulta.agendada.subject / .body / .scheduleNote
mail.consulta.realizada.subject / .body
mail.consulta.naoCompareceu.subject / .body
mail.consulta.canceladaBiblioteca.subject / .body
mail.consulta.canceladaLeitor.subject / .body
mail.consulta.expirada.subject / .body
mail.consulta.scheduleReplied.subject / .body  # vers la biblio
```

Total estimé : ~40 nouvelles clés × 6 locales = ~240 traductions.

Conventions militantes appliquées (cf. spec emprunts §3.3) : pt-BR triple `do/da/de`, fr point médian, es neutre `e`, it épicène `compagn*o`, de Genderstern.

---

## 4. Modèle de données — évolutions

### 4.1 Helper de transitions — `fn_check_consulta_workflow_transition`

Symétrique à `fn_check_workflow_transition` (réservations). SQL pur, IMMUTABLE, PARALLEL SAFE.

```sql
CREATE OR REPLACE FUNCTION public.fn_check_consulta_workflow_transition(
  p_from text,
  p_to text,
  p_actor_role text
) RETURNS boolean
LANGUAGE sql IMMUTABLE PARALLEL SAFE
SET search_path TO 'public'
AS $$
  WITH normalized AS (
    SELECT p_from AS f, p_to AS t, p_actor_role AS r
  )
  SELECT CASE
    WHEN f IS NULL OR t IS NULL OR r IS NULL THEN false

    -- États terminaux : aucune transition sortante
    WHEN f IN ('consulta_realizada', 'cancelada_leitor',
               'cancelada_biblioteca', 'expirada', 'nao_compareceu') THEN false

    -- Lecteur : annulation à toute étape non-terminale
    WHEN r = 'lecteur' AND t = 'cancelada_leitor' AND f IN (
      'solicitada', 'em_preparacao', 'consulta_agendada'
    ) THEN true

    -- Lecteur : confirmation du créneau (consulta_agendada → consulta_agendada
    -- avec schedule_reply_status flippé). La transition de stage reste la
    -- même mais le wrapper api.* met à jour schedule_reply_status.
    -- (PAS une transition de stage à proprement parler — gérée par le wrapper)
    WHEN r = 'lecteur' THEN false

    -- System : expiration sans réponse depuis solicitada/em_preparacao
    WHEN r = 'system' AND t = 'expirada' AND f IN (
      'solicitada', 'em_preparacao'
    ) THEN true

    -- System : passage automatique en nao_compareceu après consultation_ends_at
    WHEN r = 'system' AND t = 'nao_compareceu' AND f = 'consulta_agendada' THEN true

    WHEN r = 'system' THEN false

    -- Librarian/coordenador : transitions opérationnelles
    WHEN f = 'solicitada' AND t IN (
      'em_preparacao', 'cancelada_biblioteca'
    ) AND r IN ('librarian', 'coordenador') THEN true

    WHEN f = 'em_preparacao' AND t IN (
      'consulta_agendada', 'cancelada_biblioteca'
    ) AND r IN ('librarian', 'coordenador') THEN true

    WHEN f = 'consulta_agendada' AND t IN (
      'consulta_agendada',  -- reprogrammation (boucle)
      'consulta_realizada',
      'nao_compareceu',
      'cancelada_biblioteca'
    ) AND r IN ('librarian', 'coordenador') THEN true

    ELSE false
  END
  FROM normalized;
$$;

COMMENT ON FUNCTION public.fn_check_consulta_workflow_transition IS
'Source de vérité de la matrice de transitions du workflow consultation locale v2 (rédigée 2026-05-10). Symétrique à fn_check_workflow_transition (réservations) mais simplifiée : pas de stage retirada_a_combinar (la négociation passe par le sous-workflow schedule_reply, pas par un stage dédié). consulta_realizada / nao_compareceu / cancelada_* / expirada sont terminaux.';
```

### 4.2 Q2 — Vérification anti-collision avec réservation active

Ajout dans `fn_v2_create_consulta_local_by_holdings`, après le check de doublon de consulta, avant le check `available_count` :

```sql
-- Q2 : pas de consultation si réservation active sur même holding
IF EXISTS (
  SELECT 1
  FROM public.reserva_linhas_v2 rl
  JOIN public.reservas_v2 r ON r.id = rl.reserva_id
  WHERE rl.holding_id = v_row.holding_id
    AND rl.item_status = 'ativa'
    AND r.library_id = v_row.library_id
    AND r.status_global IN ('ativa', 'parcialmente_encerrada')
) THEN
  v_reserved := array_append(v_reserved, v_holding_id);
  CONTINUE;
END IF;
```

Avec ajout d'une nouvelle erreur de sortie :

```sql
IF cardinality(v_reserved) > 0 THEN
  RAISE EXCEPTION 'Holding(s) com reserva ativa para empréstimo, consulta indisponível: %',
    array_to_string(v_reserved, ', ');
END IF;
```

### 4.3 Q1 — Mode biblio détermine si créneau obligatoire

Ajout dans `fn_v2_set_consulta_linhas_workflow` (passage en `em_preparacao` ou directement vers `consulta_agendada`) :

```sql
-- Lire le mode de service pour cette consulta
SELECT s.service_mode
  INTO v_service_mode
FROM public.library_service_state s
WHERE s.library_id = v_library_id;

-- Q1 : si mode somente_consulta, le créneau est obligatoire dès em_preparacao
IF v_service_mode = 'somente_consulta'
   AND v_stage IN ('em_preparacao', 'consulta_agendada')
   AND p_consultation_scheduled_for IS NULL THEN
  RAISE EXCEPTION 'No modo "somente_consulta", o horário da consulta é obrigatório.';
END IF;

-- Sinon, créneau seulement obligatoire pour consulta_agendada (logique existante)
IF v_stage = 'consulta_agendada' AND p_consultation_scheduled_for IS NULL THEN
  RAISE EXCEPTION 'Informe a data e hora da consulta agendada.';
END IF;
```

### 4.4 Validation des transitions — branchement du helper

Réécrire `fn_v2_set_consulta_linhas_workflow` pour qu'elle :
1. Lise le stage courant de chaque ligne avant l'UPDATE
2. Appelle `fn_check_consulta_workflow_transition(stage_courant, p_workflow_stage, role_actor)` pour chaque ligne
3. Refuse l'opération entière si une transition est invalide

Pseudocode :

```sql
-- Avant l'UPDATE, charger les stages courants et l'actor role
v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);

FOR v_line IN
  SELECT cl.line_no, cw.workflow_stage AS current_stage
  FROM public.consulta_linhas_v2 cl
  LEFT JOIN public.consulta_item_workflow_v2 cw
    ON cw.consulta_id = cl.consulta_id AND cw.line_no = cl.line_no
  WHERE cl.consulta_id = p_consulta_id
    AND cl.line_no = ANY(p_line_nos)
LOOP
  IF NOT public.fn_check_consulta_workflow_transition(
    v_line.current_stage,
    v_stage,
    v_actor_role
  ) THEN
    RAISE EXCEPTION 'Transição inválida para a linha %: % -> % (papel: %)',
      v_line.line_no, v_line.current_stage, v_stage, v_actor_role;
  END IF;
END LOOP;
```

### 4.5 Toggles de notification — colonnes à ajouter

Symétriques aux flags réservation existants :

```sql
ALTER TABLE public.library_notification_policies ADD COLUMN IF NOT EXISTS
  consultation_solicitada_timeout_days int NOT NULL DEFAULT 14,
  consultation_no_show_timeout_hours int NOT NULL DEFAULT 24,

  consulta_mail_solicitada_enabled boolean NOT NULL DEFAULT true,
  consulta_mail_em_preparacao_enabled boolean NOT NULL DEFAULT true,
  consulta_mail_agendada_enabled boolean NOT NULL DEFAULT true,
  consulta_mail_realizada_enabled boolean NOT NULL DEFAULT true,
  consulta_mail_nao_compareceu_enabled boolean NOT NULL DEFAULT true,
  consulta_mail_cancelada_biblioteca_enabled boolean NOT NULL DEFAULT true,
  consulta_mail_cancelada_leitor_enabled boolean NOT NULL DEFAULT false,
  consulta_mail_expirada_enabled boolean NOT NULL DEFAULT true;
```

(Le toggle `local_consultation_enabled` existait déjà mais n'avait aucun consommateur — il devient le toggle maître, et les 8 nouveaux toggles fins permettent un réglage par stage.)

---

## 5. Matrice des transitions (vue déroulée)

```
                       [création publique par lecteur]
                       fn_v2_create_consulta_local_by_holdings
                                     │
                                     ▼
                          ┌──────────────────────┐
                          │     solicitada       │
                          └──────────┬───────────┘
                                     │
                  ┌──────────────────┼─────────────────────┐
                  │                  │                     │
        ┌─────────▼─────┐    ┌──────▼──────┐    ┌─────────▼─────────┐
        │em_preparacao  │    │cancelada_   │    │   expirada        │
        │ (par biblio)  │    │ leitor      │    │   (cron, après    │
        └─────────┬─────┘    └─────────────┘    │   timeout_days)   │
                  │                              └───────────────────┘
                  │
                  ├────────────────┬──────────────┐
                  │                │              │
                  ▼                ▼              ▼
        ┌──────────────┐    [proposer un    [annuler côté
        │consulta_     │     créneau]        biblio]
        │agendada      │     reste sur
        │ (avec créneau│     em_preparacao
        │  + reply)    │     ou direct
        └──────┬───────┘     vers agendada
               │
               │ (confirmé OU pas de réponse + cron)
               │
               ├─────────────┬──────────────────┬──────────────────┐
               │             │                  │                  │
               ▼             ▼                  ▼                  ▼
       [consulta_      [nao_compareceu      [reagendamento     [cancelada_
        realizada]      par cron 24h après   - boucle sur        biblioteca]
        par biblio      consultation_ends_at consulta_agendada]
        ou par lecteur  ou par biblio]
        si autoservice]
```

**Note importante** : le sous-workflow `schedule_reply_status` (lecteur confirme/refuse un créneau proposé) est **orthogonal** au stage. Confirmer un créneau ne change pas le stage `consulta_agendada`, ça met `schedule_reply_status = 'confirmado_leitor'` et `schedule_reply_at = now()`. Refuser un créneau le met à `'recusado_leitor'` et la biblio doit alors reproposer (transition `consulta_agendada → consulta_agendada` avec nouveau `consultation_scheduled_for` et `schedule_reply_*` réinitialisés).

---

## 6. RPC publiques — contrats

### 6.1 Création — déjà exposée

`fn_v2_create_consulta_local_by_holdings` est déjà appelable par `authenticated`. À encapsuler dans `api.create_local_consultation(p_holding_ids bigint[], p_notes text DEFAULT NULL) RETURNS jsonb` (le `p_user_id` est dérivé de `auth.uid()`, c'est plus sûr).

### 6.2 Annulation lecteur

Wrapper `api.cancel_my_consultation(p_consulta_id bigint, p_line_nos integer[] DEFAULT NULL, p_notes text DEFAULT NULL) RETURNS jsonb` autour de `fn_v2_cancel_consulta_linhas_as_leitor`. Si `p_line_nos IS NULL`, annuler toutes les lignes actives.

### 6.3 Réponse lecteur au créneau proposé

Wrapper `api.reply_to_consultation_slot(p_consulta_id bigint, p_line_nos integer[], p_reply text, p_note text DEFAULT NULL) RETURNS jsonb` :
- `p_reply IN ('confirm', 'refuse')`
- En cas de `confirm`, met `schedule_reply_status = 'confirmado_leitor'`
- En cas de `refuse`, met `'recusado_leitor'` et déclenche notification à la biblio

### 6.4 Avancement workflow biblio

Wrapper `api.advance_consultation(p_consulta_id bigint, p_line_nos integer[], p_workflow_stage text, p_workflow_note text DEFAULT NULL, p_consultation_scheduled_for timestamptz DEFAULT NULL) RETURNS jsonb` autour de `fn_v2_set_consulta_linhas_workflow`. Le wrapper :
1. Sanity-check de la transition via `fn_check_consulta_workflow_transition`
2. Appelle la fonction sous-jacente
3. Retourne `{ok, updated_count, current_stage}`

### 6.5 Proposition de créneau biblio (forme date+heures locales)

Wrapper `api.propose_consultation_slot(p_consulta_id, p_line_nos, p_date_local, p_start_local, p_end_local, p_timezone, p_note)` autour de `fn_v2_set_consulta_linhas_workflow_slot`. Validation préalable via `fn_validate_consulta_schedule_window` (vérifie que le créneau tombe dans `consultation_schedule_struct`).

### 6.6 Annulation biblio

Wrapper `api.cancel_consultation_as_library(p_consulta_id, p_line_nos[], p_reason text) RETURNS jsonb`. Le `p_reason` est obligatoire et de longueur minimale 5 (cohérent avec ce que la spec réservation impose pour `cancel_reservation_as_library`).

### 6.7 Marquer réalisée / non venu

Wrappers `api.mark_consultation_realized` et `api.mark_consultation_no_show`. Utilisés dans le cron mais aussi exposables manuellement.

---

## 7. Triggers et notifications

### 7.1 Trigger principal — `trg_notify_consulta_workflow_change`

Symétrique à `trg_notify_reserva_workflow_change` (cf. §15750 du dump pour le modèle), mais sur `consulta_item_workflow_v2`. Mapping stage → événement :

| `workflow_stage` | événement émis | flag toggle |
|---|---|---|
| `solicitada` (INSERT) | `consulta_v2_criada` | `consulta_mail_solicitada_enabled` |
| `em_preparacao` | `consulta_v2_em_preparacao` | `consulta_mail_em_preparacao_enabled` |
| `consulta_agendada` | `consulta_v2_agendada` | `consulta_mail_agendada_enabled` |
| `consulta_realizada` | `consulta_v2_realizada` | `consulta_mail_realizada_enabled` |
| `nao_compareceu` | `consulta_v2_nao_compareceu` | `consulta_mail_nao_compareceu_enabled` |
| `cancelada_biblioteca` | `consulta_v2_cancelada_biblioteca` | `consulta_mail_cancelada_biblioteca_enabled` |
| `cancelada_leitor` | `consulta_v2_cancelada_leitor` | `consulta_mail_cancelada_leitor_enabled` |
| `expirada` | `consulta_v2_expirada` | `consulta_mail_expirada_enabled` |

Bloc supplémentaire : changement de `schedule_reply_status` (NULL → `confirmado_leitor` ou `recusado_leitor`) émet `consulta_v2_schedule_replied` qui notifie la biblio (pas le lecteur — c'est lui qui vient de répondre).

Sur le toggle maître `local_consultation_enabled = false`, le trigger fait un skip silencieux de toutes les notifications consulta. Sur `*_enabled = false` au niveau fin, idem mais sélectif.

Fail-open par défaut : si la lecture du flag échoue, on émet quand même.

### 7.2 Handler Edge Function `notify-event/handlers/consultas.ts` (nouveau)

Symétrique à `handlers/reservas.ts` mais avec routage des 8 événements consulta. Templates HTML i18n × 6 locales. Inline images via le helper existant `_shared/mail/inline-images.ts`.

### 7.3 Crons d'expiration et de no-show

```sql
-- Cron 1 : expiration des solicitada/em_preparacao après timeout
CREATE OR REPLACE FUNCTION public.fn_expire_solicitada_consultas()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_expired_count int := 0;
  v_row record;
BEGIN
  FOR v_row IN
    SELECT cw.consulta_id, cw.line_no, cl.expires_at,
           cw.workflow_stage, c.library_id,
           lnp.consultation_solicitada_timeout_days AS timeout_days
    FROM public.consulta_item_workflow_v2 cw
    JOIN public.consulta_linhas_v2 cl
      ON cl.consulta_id = cw.consulta_id AND cl.line_no = cw.line_no
    JOIN public.consultas_locais_v2 c ON c.id = cw.consulta_id
    LEFT JOIN public.library_notification_policies lnp
      ON lnp.library_id = c.library_id
    WHERE cw.workflow_stage IN ('solicitada', 'em_preparacao')
      AND cl.item_status = 'ativa'
      AND (
        cl.expires_at IS NOT NULL AND cl.expires_at < now()
        OR cl.created_at < now() - make_interval(days => COALESCE(lnp.consultation_solicitada_timeout_days, 14))
      )
  LOOP
    BEGIN
      IF public.fn_check_consulta_workflow_transition(
        v_row.workflow_stage, 'expirada', 'system'
      ) THEN
        UPDATE public.consulta_item_workflow_v2
           SET workflow_stage = 'expirada', updated_at = now()
         WHERE consulta_id = v_row.consulta_id AND line_no = v_row.line_no;
        UPDATE public.consulta_linhas_v2
           SET item_status = 'expirada', expired_at = now()
         WHERE consulta_id = v_row.consulta_id AND line_no = v_row.line_no;
        v_expired_count := v_expired_count + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Erro ao expirar consulta %/%: %', v_row.consulta_id, v_row.line_no, SQLERRM;
    END;
  END LOOP;

  RETURN v_expired_count;
END;
$$;

-- Cron 2 : détection no-show après consultation_ends_at + timeout
CREATE OR REPLACE FUNCTION public.fn_detect_no_show_consultas()
-- même pattern, déclenche transition consulta_agendada → nao_compareceu
-- pour les workflows dont consultation_ends_at + timeout_hours < now()
-- ET schedule_reply_status != 'recusado_leitor' (sinon ce n'est pas un no-show)
$$;
```

Programmer avec pg_cron :

```sql
SELECT cron.schedule(
  'anarbib-consulta-expire-solicitada',
  '5 * * * *',  -- horaire à HH:05
  $$ SELECT public.fn_expire_solicitada_consultas(); $$
);

SELECT cron.schedule(
  'anarbib-consulta-detect-no-show',
  '15 * * * *', -- horaire à HH:15
  $$ SELECT public.fn_detect_no_show_consultas(); $$
);
```

---

## 8. Surfaces UI

### 8.1 livro.html / index.html

**index.html** : pour chaque ligne de résultat, si la règle de circulation le permet (`consultation_allowed = true`), afficher le bouton **« Reservar consulta »** à côté ou en remplacement de **« Reservar »** selon que le document est aussi prêtable. Si seul `consultation_only = true`, seul le bouton consulta apparaît.

**livro.html** : même logique sur la fiche détaillée. Si la biblio est en mode `somente_consulta`, afficher un bandeau d'info « Esta biblioteca está atualmente em modo somente consulta » au-dessus de l'action.

L'action déclenche `api.create_local_consultation(p_holding_ids := [holding_id_courant])`. En cas de succès, redirection vers `conta.html#consultas`.

### 8.2 AccountPage.jsx — nouvel onglet dédié `Consultas no local`

**Décision UX (10/05/2026)** : option a retenue — onglet séparé de `reservar` (cf. doc Dunkerque §7.3 « Ne pas mélanger la consultation locale avec l'onglet existant réservé aux réservations de prêt sans distinction claire »). L'onglet `reservar` reste le parcours **de création unifié** existant (ligne 159-256, mode = 'reserve' ou 'consult'), ce qui ne change pas. La nouveauté est l'onglet **dédié au suivi**.

**Insertion dans le tableau d'onglets actuel** (ligne 437-442 de AccountPage.jsx) :

```jsx
const TABS = [
  { key: 'perfil', ... },
  { key: 'reservar', ... },
  { key: 'curso', ... },
  { key: 'consultas', label: t({ id: 'account.tab.consultations' }),
    hint: t({ id: 'account.tab.consultations.hint' }) },  // NOUVEAU
  { key: 'historico', ... },
  { key: 'avisos', ... },
  { key: 'desejos', ... },
];
```

**Contenu de l'onglet** : déplacer le sous-bloc consultations actuel (lignes 782-787 de AccountPage.jsx) depuis l'onglet `reservar` vers le nouvel onglet `consultas`, et l'enrichir.

Pour chaque consulta active :
- Titre, auteur, biblio, ref locale
- Statut lecteur (mapping §3.1, badge couleur)
- Si créneau proposé non répondu (`workflow_stage = 'consulta_agendada'` ET `schedule_reply_status IS NULL`) : bloc d'action **« Resposta necessária »** avec :
  - Affichage du créneau formaté : « 12/05/2026 das 14h às 16h (America/Belem) »
  - Boutons **Confirmar horário** (`api.reply_to_consultation_slot` avec `confirm`) / **Recusar horário** (avec `refuse`)
  - Champ optionnel de note
- Si créneau confirmé : badge vert « Horário confirmado : [date] » + bouton Cancelar (annulation reste possible)
- Bouton **Cancelar pedido** disponible tant que le stage n'est pas terminal — appelle `api.cancel_my_consultation`

### 8.3 PanelPage.jsx — onglet consultations

Liste des consultations actives via `api.consulta_itens_followup_ui`. Colonnes :
- Lecteur (nom + email)
- Item (titre, ref locale)
- Stage actuel (badge couleur)
- Créneau proposé / confirmé
- Réponse lecteur (icône check/cross/sablier)
- Actions : `<select>` avec stages cibles autorisés (grisés pour transitions non autorisées via la matrice §5)

Mode sélection multi-lignes pour les actions batch (typiquement « Mover seleção para em_preparacao »).

Pour proposer un créneau : popup avec datepicker date + 2 timepickers (start/end) + select timezone (default `library_service_state.consultation_timezone`). Validation côté frontend + côté DB (`fn_validate_consulta_schedule_window`).

### 8.4 BibliotecaPage — déjà couvert

La configuration des plages de consultation (`consultation_schedule_struct`) et des toggles (`consulta_mail_*_enabled`) doit apparaître dans la page de configuration biblio. Si ce n'est pas déjà fait, à formaliser dans un audit séparé (hors spec).

---

## 9. Phases d'implémentation

### Phase 1 — DB : helper de transitions + corrections (1 demi-journée)

1. Migration `20260510_consulta_workflow_helper.sql` : crée `fn_check_consulta_workflow_transition`
2. Migration `20260510_consulta_q1_q2_fixes.sql` :
   - Q2 dans `fn_v2_create_consulta_local_by_holdings`
   - Q1 dans `fn_v2_set_consulta_linhas_workflow`
   - Branchement du helper dans `fn_v2_set_consulta_linhas_workflow` et `_workflow_slot`
3. Tests SQL : matrice de transitions (toutes combinaisons stage × actor × cible), 2 tests Q1, 2 tests Q2

### Phase 2 — Wrappers api.* (1 demi-journée)

1. `api.create_local_consultation`
2. `api.cancel_my_consultation`
3. `api.reply_to_consultation_slot`
4. `api.advance_consultation`
5. `api.propose_consultation_slot`
6. `api.cancel_consultation_as_library`
7. `api.mark_consultation_realized`, `api.mark_consultation_no_show`
8. Tests SQL pour chaque wrapper (auth, roles, paramètres invalides)

### Phase 3 — Notifications DB + Edge Function (1 journée)

1. Migration `20260510_consulta_notification_policies.sql` : ajoute les 8 toggles fins + 2 timeouts
2. Migration `20260510_trg_notify_consulta_workflow.sql` : trigger principal calqué sur reserva
3. Edge Function : nouveau handler `notify-event/handlers/consultas.ts` + routage dans `dispatch.ts`
4. i18n : 50 clés × 6 locales dans `_shared/i18n/mail-strings.ts` (~300 traductions)
5. Test e2e : créer une consulta depuis un compte test, vérifier mail de création reçu

### Phase 4 — Crons d'expiration et no-show (1 demi-journée)

1. Migration `20260510_consulta_crons.sql` : `fn_expire_solicitada_consultas`, `fn_detect_no_show_consultas`, 2 jobs pg_cron
2. Test SQL en mode dry-run (créer une consulta antidatée, lancer le cron manuellement)

### Phase 5 — Frontend lecteur : ajustements en diff (1/2 journée)

L'audit du 10/05/2026 montre que le **parcours de création est déjà câblé** (AccountPage.jsx lignes 159-256, basculement automatique entre RPC réserva/consulta). Il s'agit donc d'**ajuster**, pas de créer.

1. AccountPage : ajouter le 4e onglet `consultas` au tableau `TABS` (ligne 437-442)
2. AccountPage : déplacer le sous-bloc consultations actuel (lignes 782-787) depuis l'onglet `reservar` vers le bloc `{activeTab === 'consultas' && ...}`
3. AccountPage : composant `<ConsultationCard>` qui gère le sous-workflow `schedule_reply` :
   - Affichage du badge stage avec couleur sémantique
   - Si `consulta_agendada` + `schedule_reply_status IS NULL` : bloc d'action `Resposta necessária`
   - Boutons Confirmar / Recusar / Cancelar appelant les nouveaux wrappers `api.*`
4. Bouton `Reservar consulta` : déjà présent en pratique via `mode === 'consult'`, vérifier juste que les libellés i18n sont bien à jour
5. Bandeau « somente consulta » sur livro.html quand pertinent — à auditer (les pages catalogue n'étaient pas dans cet audit, à confirmer en Phase 5)
6. i18n : ~17 clés frontend lecteur × 6 locales

### Phase 6 — Frontend bibliothécaire : ajustements en diff (1 journée)

L'audit montre que **l'onglet `consultas-locais` existe** (PanelPage.jsx ligne 883), avec une RPC `fn_v2_set_consulta_linhas_workflow` câblée pour 4 transitions (em_preparacao, consulta_agendada, consulta_realizada, cancelada_biblioteca). Manquent : workflow_slot, no_show, lecture schedule_reply, validation transitions.

1. PanelPage : refactor `setConsultaWorkflow` pour appeler les nouveaux wrappers `api.*` au lieu de `fn_v2_set_consulta_linhas_workflow` directement
2. PanelPage : ajouter une popup pour `api.propose_consultation_slot` (datepicker + 2 timepickers + select timezone)
3. PanelPage : ajouter le bouton `nao_compareceu` dans la liste d'actions de l'onglet consultations
4. PanelPage : afficher le `schedule_reply_status` dans la colonne adéquate (icône check/cross/sablier sur la ligne)
5. PanelPage : grisage des transitions invalides via réplique JS de `fn_check_consulta_workflow_transition` (cohérence avec ce qui a été fait pour les réservations)
6. PanelPage : popup `cancel_consultation_as_library` avec champ raison ≥5 chars (cohérence réservation)
7. i18n : ~13 clés panel × 6 locales

### Phase 7 — Tests runtime (1 demi-journée)

Scénarios sur prod (base contient déjà 6 consultas, à wiper si besoin) :

1. Lecteur crée une consulta sur un holding dans biblio en mode normal → succès, mail créé reçu
2. Biblio passe à em_preparacao → mail reçu lecteur
3. Biblio propose un créneau → mail reçu, action « Resposta necessária » visible côté lecteur
4. Lecteur confirme → mail reçu biblio
5. Biblio marque réalisée → mail reçu lecteur, status_global passe à `parcialmente_encerrada` ou `encerrada`
6. Tentative de transition invalide (solicitada → consulta_realizada direct) → erreur claire
7. Création de consulta sur holding avec réservation active → bloqué avec message explicite
8. Mode `somente_consulta` activé : tentative de em_preparacao sans créneau → bloqué
9. Cron d'expiration sur consulta vieille de 15 jours → expirada + mail lecteur
10. No-show : créneau passé +24h sans réalisation → nao_compareceu + mail

### Phase 8 — Commit et déploiement

Commit unique : `spec flux consultation locale phases 1-7 : DB + api wrappers + crons + notifications + frontend`. Push Codeberg + GitHub.

---

## 10. Risques et invariants

### 10.1 Invariants à préserver

1. **`status_global` toujours dérivé des lignes** : aucun UPDATE direct, uniquement via `fn_v2_refresh_consulta_status_global`.
2. **Mutual exclusion holding/réservation** : un holding actif en réservation ne peut pas avoir une consulta active simultanée (contrainte appliquée à la création).
3. **Créneau toujours dans une plage publiée** : `fn_validate_consulta_schedule_window` appelée systématiquement.
4. **Pas de double notification par transition** : trigger sur `IS DISTINCT FROM`.
5. **Schedule_reply_status réinitialisé à chaque reprogrammation** : déjà géré dans `fn_v2_set_consulta_linhas_workflow` (cf. lignes 12109-12120 du dump, le ON CONFLICT DO UPDATE le fait correctement).

### 10.2 Risques identifiés

- **Risque #1** : le branchement du helper de transition peut casser des appels frontend qui auraient marché jusqu'ici par chance. Mitigation : auditer les appels existants à `fn_v2_set_consulta_linhas_workflow` dans PanelPage.jsx avant déploiement Phase 1.
- **Risque #2** : la matrice de transitions est rédigée à plat dans `fn_check_consulta_workflow_transition`. Une modification ultérieure doit être synchronisée avec le helper JS côté frontend (comme pour les réservations). Mitigation : commentaire SQL explicite + check-list dans la spec.
- **Risque #3** : les 6 consultas actuellement en base ne respectent pas forcément la nouvelle matrice. Mitigation : audit + correction manuelle ou wipe de cette table avant Phase 1, en cohérence avec la stratégie wipe du 07/05.
- **Risque #4** : ajout de 8 colonnes à `library_notification_policies` modifie le schéma d'une table déjà alimentée. Migration idempotente avec `ADD COLUMN IF NOT EXISTS` + valeurs par défaut. Aucun backfill nécessaire.
- **Risque #5** : asymétrie volontaire (10/05/2026). La création de consulta vérifie qu'aucune réservation active n'existe sur le même holding, mais l'inverse n'est pas vrai : la création d'une réservation ne vérifie pas les consultas. Choix politique : **la réservation prime sur la consulta**. Un lecteur qui veut emprunter passe avant un lecteur qui veut consulter sur place — la lecture itinérante (avec emprunt) est privilégiée par défaut. Si une biblio veut l'inverse, ce sera un toggle ultérieur (hors spec).

---

## 11. Cohérence avec les autres specs

| Spec | Lien |
|---|---|
| spec-flux-emprunts.md | Chaîne sœur indépendante. Mutual exclusion sur les holdings (cf. Risque #5 à trancher). |
| spec-workflow-reservation.md | Mutual exclusion (Q2). Le helper de transition consulta s'inspire mais ne réutilise pas `fn_check_workflow_transition` (matrice différente). |
| spec-onboarding-biblioteca.md | La configuration `consultation_schedule_struct` et le toggle `local_consultation_enabled` font partie du formulaire de configuration biblio. |
| spec-validation-physique.md | Indépendante. La création de consulta se fait au nom de `auth.uid()`, qui doit être un compte validé physiquement. |

---

## 12. Annexe — Q ouvertes pour discussion future

### 12.1 Auto-arrivée du lecteur

Faut-il permettre au lecteur de marquer lui-même `consulta_realizada` quand il arrive à la biblio ? Plusieurs scénarios :
- Bibliothèque associative à faible présence : lecteur arrive pendant une permanence courte, signe lui-même son arrivée
- Bibliothèque où la présence d'un⋅e responsable n'est pas garantie : auto-check-in fait sens

Cohérent avec valeurs anarchistes (autonomie, refus de contrôle excessif). À évaluer : l'inclure dans une future Phase 9, ou laisser ça à un toggle biblio.

### 12.2 Multiple créneaux successifs

Pour des consultations longues (recherche en archives), faut-il permettre de planifier plusieurs créneaux pour la même consulta ? Aujourd'hui, le sous-workflow ne stocke qu'un seul `consultation_starts_at`/`ends_at`. Pour des consultations multi-séances : ouvrir une nouvelle consulta à chaque fois (workaround actuel) ou étendre le modèle (table `consulta_sessions`)? Hors périmètre, à reformaliser si besoin se présente.

### 12.3 Sortie sur place de l'item

Quand un item est en consulta_agendada, est-ce qu'il sort virtuellement du `available_count` ? Aujourd'hui non (la création de consulta vérifie `available_count >= 1` sans le décrémenter). Risque : double-réservation par d'autres lecteurs en parallèle. Mitigation actuelle : `max_simultaneous_consultations` limite la pression. À auditer en exploitation réelle.

---

*Spec rédigée le 10/05/2026. Implémentation en 7 phases sur ~5 jours de travail si pris en continu. Le backend SQL est largement en place (estimation v13 : « presque close, manque le branchement notification »). Cette spec formalise la fermeture de cette branche.*
