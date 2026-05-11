# Spec — Flux des consultations sur place

> **Statut** : v2 du 11/05/2026 (Phase 0 d'audit close, écarts intégrés) — base pour implémentation phasée
> **Périmètre** : consultations sur place (`consultas_locais_v2` + `consulta_linhas_v2` + `consulta_item_workflow_v2`). Hors périmètre : prêt inter-bibliothèques, emprunts à domicile.
> **Spec sœur** : spec-flux-emprunts.md (chaîne parallèle pour les emprunts).
> **Spec amont** : spec-workflow-reservation.md (modèle de négociation de créneau dont s'inspire la phase d'agendamento de consultation).
> **Changelog v1 → v2** : audit Phase 0 ajouté §2.4-§2.8 (aucun trigger, aucune clé mail, aucun handler, UI staff partielle avec bug latent L1520, UI lecteur incomplète, invariant emprunt-vs-consulta non garanti). Phase 1 et Phase 5 ajustées en conséquence.

---

## 1. Contexte et objectif politique

Dans une bibliothèque militante anarchiste, la consultation sur place couvre les matériaux qui ne sortent pas : périodiques rares, brochures fragiles, fonds patrimoniaux, archives militantes, mémoires. C'est un acte différent de l'emprunt — il suppose un temps partagé dans l'espace de la biblio, souvent un échange avec un·e bibliothécaire qui ouvre l'armoire ou apporte le document.

L'objectif de cette spec est de reconnaître cette spécificité dans le SIGB : ne pas réduire la consultation à un sous-cas d'emprunt mais lui donner un workflow propre, avec une **négociation de créneau** entre lecteur·rice et bibliothécaire, le respect des horaires d'ouverture, et une lisibilité totale des règles (qui peut faire quoi à quel stade, pourquoi le créneau est refusé, comment l'annuler).

La spec couvre le cycle de vie d'une consultation depuis sa création jusqu'à sa clôture, en alignant les patterns architecturaux sur les emprunts (wrappers `api.*` SECURITY INVOKER, helper de matrice de transitions, tests SQL d'acceptation) pour faciliter la maintenance par toute personne contribuant au code.

L'objectif n'est pas de réécrire le backend — les 8 fonctions DEFINER existent depuis longtemps et fonctionnent — mais d'exposer une couche `api.*` propre, de documenter formellement les invariants, et d'écrire les tests qui manquent pour détecter les bugs critiques comme celui de `fn_resolve_caller_role_for_library` découvert lors du paquet 20.

---

## 2. État de l'existant au 11/05/2026

### 2.1 Tables (CHECK constraints actuels)

**`consultas_locais_v2`** — agrégat de tête.

| colonne | type | défaut | rôle |
|---|---|---|---|
| `id` | bigint | — | PK |
| `user_id` | uuid | — | lecteur (FK profiles) |
| `library_id` | uuid | — | biblio (FK libraries) |
| `notes` | text | — | note libre |
| `status_global` | text | `'ativa'` | **CHECK : `ativa` / `parcialmente_encerrada` / `encerrada`** |
| `created_at`, `updated_at` | timestamptz | `now()` | |

**`consulta_linhas_v2`** — lignes (un item par holding consulté).

| colonne | type | défaut | rôle |
|---|---|---|---|
| `id`, `consulta_id`, `line_no`, `sub_id` | — | — | identifiants |
| `book_id`, `holding_id` | bigint | — | livre et holding ciblés |
| `bib_ref`, `titulo_cache`, `autor_cache`, `editora_cache`, `ano_cache` | text | — | snapshot bibliographique |
| `item_status` | text | `'ativa'` | **CHECK : `ativa` / `consultada` / `cancelada_leitor` / `cancelada_biblioteca` / `expirada`** |
| `expires_at` | timestamptz | — | date limite globale de la demande |
| `cancelled_at`, `consulted_at`, `expired_at` | timestamptz | — | dates de transitions terminales |
| `dismissed_by_reader_at` | timestamptz | — | date où le lecteur a "fermé" une ligne annulée |
| `notes` | text | — | note libre |
| `created_at`, `updated_at` | timestamptz | `now()` | |

**`consulta_item_workflow_v2`** — historique des transitions de workflow (event log).

| colonne | type | défaut | rôle |
|---|---|---|---|
| `id`, `consulta_id`, `line_no` | — | — | clés |
| `workflow_stage` | text | — | **CHECK : `solicitada` / `em_preparacao` / `consulta_agendada` / `consulta_realizada` / `nao_compareceu` / `cancelada_leitor` / `cancelada_biblioteca` / `expirada`** |
| `workflow_note` | text | — | note de l'auteur·ice de la transition |
| `consultation_scheduled_for` | timestamptz | — | date/heure de la consultation (créneau ponctuel) |
| `consultation_starts_at`, `consultation_ends_at` | timestamptz | — | fenêtre élargie (alternative au scheduled_for ponctuel) |
| `consultation_timezone` | text | — | timezone de la biblio au moment où le créneau a été fixé |
| `schedule_reply_status` | text | — | **CHECK : `confirmado_leitor` / `recusado_leitor`** (nullable) |
| `schedule_reply_note`, `schedule_reply_at` | text/timestamptz | — | trace de la réponse du lecteur |
| `updated_at`, `updated_by` | timestamptz/uuid | — | dernière modification |

**Observation architecturale** : contrairement aux emprunts (`item_status` directement sur `emprestimo_itens_v2`), les consultations utilisent un **modèle event-log** : l'état métier est sur `consulta_linhas_v2.item_status` (5 valeurs) mais le workflow détaillé (avec créneau + réponse lecteur) est sur `consulta_item_workflow_v2.workflow_stage` (8 valeurs). Ce découplage permet une négociation de créneau plus riche.

### 2.2 Fonctions PL/pgSQL existantes

| Fonction | Rôle | Sécurité |
|---|---|---|
| `fn_v2_create_consulta_local_by_holdings(p_user_id, p_holding_ids[], p_expires_at, p_notes)` | Création par le lecteur OU le bibliothécaire | DEFINER |
| `fn_v2_set_consulta_linhas_workflow(p_consulta_id, p_line_nos[], p_workflow_stage, p_workflow_note, p_consultation_scheduled_for)` | Transition de workflow par le staff (créneau ponctuel) | DEFINER, valide les 6 stages staff |
| `fn_v2_set_consulta_linhas_workflow_slot(...)` | Variante avec fenêtre [start, end] + timezone | DEFINER |
| `fn_v2_set_consulta_linhas_schedule_reply(p_consulta_id, p_line_nos[], p_reply_status, p_note)` | Réponse du lecteur à une proposition de créneau (`confirmado_leitor` / `recusado_leitor`) | DEFINER |
| `fn_v2_cancel_consulta_linhas_as_leitor(p_consulta_id, p_line_nos[], p_notes)` | Annulation par le lecteur | DEFINER |
| `fn_v2_dismiss_consulta_cancelled_as_leitor(p_consulta_id, p_line_nos[], p_note)` | Fermeture (mise sous le tapis) par le lecteur d'une ligne annulée par la biblio | DEFINER |
| `fn_v2_refresh_consulta_status_global(p_consulta_id)` | Recompute le statut tête à partir des items | DEFINER |
| `fn_validate_consulta_schedule_window(p_library_id, p_consulta_id, p_consultation_starts_at, p_consultation_ends_at)` | Validation business du créneau (horaires d'ouverture, conflits) | DEFINER |

**Note** : `fn_v2_set_consulta_linhas_workflow` ne couvre QUE les transitions staff. Les transitions lecteur passent par les fonctions dédiées (`cancel`, `dismiss`, `schedule_reply`). C'est cohérent avec une séparation claire des responsabilités, mais cela signifie qu'il n'y a pas de fonction unifiée de "transition" (à la `fn_check_workflow_transition` pour les réservations).

### 2.3 Vues `api.*` existantes

| Vue | Audience | Description |
|---|---|---|
| `api.my_consultas_active_v2` | lecteur | Consultations en cours (non-terminales) du lecteur courant |
| `api.my_consultas_history_v2` | lecteur | Consultations terminées du lecteur courant |
| `api.consulta_itens_ui` | tous | Vue détaillée par item, joint workflow + status |
| `api.consulta_itens_followup_ui` | staff | Suivi par la biblio (similaire à `reserva_itens_followup_ui`) |

### 2.4 Triggers de notification

**Audit Phase 0 (11/05/2026)** : **aucun trigger** sur les 3 tables consultations. La requête `SELECT tgname FROM pg_trigger WHERE tgrelid::regclass::text LIKE '%consulta%'` retourne 0 ligne. Aucune notification mail n'est émise automatiquement pour les consultations.

Conséquence : Phase 3 doit créer ces triggers **de zéro** (cf. §7).

### 2.5 Toggles de notification (`library_notification_policies`)

**Audit Phase 0 (11/05/2026)** : seul `local_consultation_enabled` (boolean, default true) existe — c'est un toggle "feature on/off" (autoriser la consultation sur place dans cette biblio), **pas** un toggle de notification.

À ajouter en Phase 3 :
- `consulta_lifecycle_enabled` — création, agendamento, réalisation, annulation
- `consulta_reminders_enabled` — rappels J-1 / jour J du créneau
- `admin_copy_consultas_enabled` — copie carbone aux bibliothécaires

Le toggle `local_consultation_enabled` existant reste indépendant et est lu en amont par le frontend pour afficher (ou non) le bouton "Demander une consultation".

### 2.6 Surfaces UI existantes

**Audit Phase 0 (11/05/2026)** :

**Côté lecteur (`AccountPage.jsx`)** :
- Création : OK via le formulaire mutualisé réservation/consultation (`isConsultation ? 'fn_v2_create_consulta_local_by_holdings' : 'fn_v2_create_reserva_by_holdings'`, L258)
- Affichage des consultations actives via `api.my_consultas_active_v2` : ✓ existant
- **Annulation par le lecteur : NON implémentée** (pas d'appel `fn_v2_cancel_consulta_linhas_as_leitor`)
- **Réponse à un créneau proposé : NON implémentée** (pas d'appel `fn_v2_set_consulta_linhas_schedule_reply`)
- **Fermeture (dismiss) d'une annulation biblio : NON implémentée** (pas d'appel `fn_v2_dismiss_consulta_cancelled_as_leitor`)

**Côté bibliothécaire (`PanelPage.jsx`)** : 24 occurrences `consulta`, largement branché :
- Onglet `consultas-locais` (L1485)
- Affichage via `consulta_itens_followup_ui` (L352)
- Tri par colonne (paquet 18 appliqué, L1496)
- Hero avec compteurs : "Consultations actives" + "Consultations en attente" (L1126, L1159)
- Helper `setConsultaWorkflow(consultaId, lineNo, stage, note)` qui appelle `fn_v2_set_consulta_linhas_workflow` (L745-754)
- 4 boutons d'action :
  - **Préparer** (`em_preparacao`) — L1517
  - **Agender** (`consulta_agendada`) — L1520
  - **Marquer réalisé** (`consulta_realizada`) — L1523
  - **Annuler côté biblio** (`cancelada_biblioteca`) — L1526
- Tâche dans le panel quotidien (`buildDailyTasks`) si stage `solicitada` (L839-840)

**Bug latent détecté L1520** : le bouton "Agender" appelle `setConsultaWorkflow(consultaId, lineNo, 'consulta_agendada')` **sans passer de date** (`p_consultation_scheduled_for`). La fn DEFINER `fn_v2_set_consulta_linhas_workflow` raise alors `Informe a data e hora da consulta agendada`. Ce bug est probablement passé inaperçu car peu de consultations existent en base (1 seule, `encerrada`). À fixer dans Phase 5.

### 2.7 Audit Phase 0 — terminé

Audit conduit le 11/05/2026. Résultats récapitulés dans §2.4-§2.6 et §2.8. La conclusion principale : la couche backend de notifications consultations est entièrement à créer ; côté frontend, l'UI staff est partiellement en place (avec un bug latent) et l'UI lecteur a 3 fonctionnalités manquantes.

### 2.8 Constats critiques consolidés (Phase 0)

1. **Aucun trigger de notification** sur les 3 tables consultations. Phase 3 = création complète.

2. **Aucune clé i18n mail `consulta.*`** dans `mail-strings.ts` (1639 lignes auditées, 0 occurrence). Phase 3 = ~60 clés × 6 locales = 360 traductions.

3. **Aucun handler `consultations.ts`** dans `notify-event/handlers/`. Phase 3 = création complète sur le modèle de `internal-task.ts` (pattern : `fetchConsulta` + `fetchConsultaProfile`, `renderEmail(layout)`, `safeSendEmail`).

4. **Pas de wrappers `api.*` pour les consultations.** Le frontend appelle directement les fonctions DEFINER. Phase 2 = créer 5 wrappers SECURITY INVOKER.

5. **`fn_v2_set_consulta_linhas_workflow` ne lit pas de matrice de transitions formalisée.** La fonction valide uniquement le stage cible. Phase 1 = créer `fn_check_consulta_transition` + l'utiliser dans le wrapper `api.advance_consulta`.

6. **Invariant emprunt-vs-consulta NON garanti côté backend.** L'audit de `fn_v2_create_emprestimo_by_holdings` (Phase 0) montre que la fonction vérifie les réservations actives sur un holding mais **pas** les consultations actives. Conséquence : on peut techniquement créer un emprunt sur un holding qui est en `consulta_linhas_v2.item_status = 'ativa'`. À patcher en Phase 1.

7. **Bug latent UI staff (PanelPage L1520)** : le bouton "Agender" appelle `setConsultaWorkflow` sans date. À fixer en Phase 5 en intégrant un formulaire de proposition de créneau (date+heure+timezone+fenêtre optionnelle).

8. **UI lecteur incomplète** : annulation, réponse créneau, dismiss non implémentées dans `AccountPage.jsx`. À ajouter en Phase 4.

9. **Aucun test SQL d'acceptation** pour les consultations. Phases 1 et 2 doivent en livrer ~45.

---

## 3. Vocabulaire et libellés

### 3.1 Libellés humains (PT-BR canonique)

**`consulta_linhas_v2.item_status`** :

| Statut machine | PT-BR (lecteur) | PT-BR (biblio) | Couleur sémantique |
|---|---|---|---|
| `ativa` | Pedido em curso | Pedido em curso | bleu |
| `consultada` | Consultada | Consultada | vert |
| `cancelada_leitor` | Cancelada por mim | Cancelada por leitor·a·e | gris |
| `cancelada_biblioteca` | Cancelada pela biblioteca | Cancelada pela biblioteca | rouge |
| `expirada` | Expirada | Expirada | rouge clair |

**`consulta_item_workflow_v2.workflow_stage`** (lu dans les UI de détail) :

| Stage | PT-BR (lecteur) | PT-BR (biblio) | Couleur |
|---|---|---|---|
| `solicitada` | Aguardando análise | Solicitada | bleu |
| `em_preparacao` | Em preparação | Em preparação | bleu |
| `consulta_agendada` | Agendada para {date} | Agendada para {date} | violet |
| `consulta_realizada` | Consultada em {date} | Consultada em {date} | vert |
| `nao_compareceu` | Não compareceu | Não compareceu | rouge |
| `cancelada_leitor` | Cancelada por mim | Cancelada por leitor·a·e | gris |
| `cancelada_biblioteca` | Cancelada pela biblioteca | Cancelada pela biblioteca | rouge |
| `expirada` | Expirada | Expirada | rouge clair |

**`consulta_item_workflow_v2.schedule_reply_status`** (réponse du lecteur à une proposition) :

| Reply | PT-BR (lecteur) | PT-BR (biblio) |
|---|---|---|
| `confirmado_leitor` | Confirmado | Confirmado pelo·a·e leitor·a·e |
| `recusado_leitor` | Recusado | Recusado pelo·a·e leitor·a·e |
| (null) | Aguardando resposta | Aguardando resposta |

### 3.2 Motifs de refus d'action

| `reason` machine | PT-BR | EN | FR |
|---|---|---|---|
| `not_authenticated` | Sessão expirada. Faça login. | Session expired. Please log in. | Session expirée. |
| `not_found` | Consulta não encontrada. | Consultation not found. | Consultation introuvable. |
| `not_owner` | Você só pode agir sobre suas próprias consultas. | You can only act on your own consultations. | Tu ne peux agir que sur tes consultations. |
| `not_authorized` | Ação não autorizada para o seu papel. | Action not authorized for your role. | Action non autorisée pour ton rôle. |
| `invalid_stage` | Transição inválida desde a etapa atual. | Invalid transition from current stage. | Transition invalide depuis l'étape actuelle. |
| `schedule_window_invalid` | Horário fora do período de funcionamento da biblioteca. | Time outside library opening hours. | Horaire hors période d'ouverture. |
| `schedule_missing` | Indique a data e hora propostas. | Provide the proposed date and time. | Indique la date et l'heure proposées. |
| `terminal_state` | Esta consulta já foi encerrada. | This consultation is already closed. | Cette consultation est déjà clôturée. |

### 3.3 Clés i18n à ajouter (× 6 locales)

```
account.consulta.status.ativa
account.consulta.status.consultada
account.consulta.status.cancelada_leitor
account.consulta.status.cancelada_biblioteca
account.consulta.status.expirada

account.consulta.workflow.solicitada
account.consulta.workflow.em_preparacao
account.consulta.workflow.consulta_agendada
account.consulta.workflow.consulta_realizada
account.consulta.workflow.nao_compareceu

account.consulta.reply.confirmado_leitor
account.consulta.reply.recusado_leitor
account.consulta.reply.pending

account.consulta.action.cancel
account.consulta.action.confirmSchedule
account.consulta.action.refuseSchedule
account.consulta.action.dismissCancelled

account.consulta.denied.{reason}    # 8 reasons

panel.consulta.status.* (5 clés)
panel.consulta.workflow.* (8 clés)
panel.consulta.action.advance
panel.consulta.action.proposeSchedule
panel.consulta.action.markRealized
panel.consulta.action.markNoShow
panel.consulta.action.cancelAsLibrary
panel.consulta.create.expiresAt
```

Total estimé : ~40 nouvelles clés × 6 locales = 240 traductions.

Conventions militantes appliquées (cf. `notes-audit/anarbib-charte-langage-inclusif-v1.md`) :
- pt-BR : forme triple `do/da/de` ou `leitor·a·e`
- fr : point médian `lecteur·rice`
- es : neutre `e` argentin (`lectore`)
- it : épicène `compagn*o` (jamais `camerati`)
- de : Genderstern `Genoss*in`

---

## 4. Modèle de données — évolutions

### 4.1 Aucune évolution structurelle nécessaire

Les 3 tables existantes (`consultas_locais_v2`, `consulta_linhas_v2`, `consulta_item_workflow_v2`) couvrent l'ensemble des besoins fonctionnels avec un degré de richesse comparable aux réservations (event log + état métier).

### 4.2 Ajout du compteur `negotiation_iteration_count` (optionnel, Phase 2)

Pour brider la négociation de créneau (similaire à ce qui a été fait pour les réservations au paquet 5c), ajouter :

```sql
ALTER TABLE public.consulta_item_workflow_v2
  ADD COLUMN IF NOT EXISTS negotiation_iteration_count int NOT NULL DEFAULT 0;
```

Incrementé à chaque cycle `consulta_agendada` → `recusado_leitor` → nouvelle proposition. Empêche les boucles infinies de contre-propositions. Limite par défaut : 3.

Décision à confirmer en session : retient-on ce garde-fou maintenant ou en Phase 5+ (hors spec) ?

### 4.3 Colonne `pickup_proposed_by` pour la traçabilité (optionnel)

À l'image du paquet 5c côté réservations, marquer qui a proposé le créneau courant :

```sql
ALTER TABLE public.consulta_item_workflow_v2
  ADD COLUMN IF NOT EXISTS schedule_proposed_by text
    CHECK (schedule_proposed_by IS NULL OR schedule_proposed_by IN ('biblio', 'leitor'));
```

Utile pour l'UI lecteur : si `schedule_proposed_by = 'biblio'`, afficher les boutons "Confirmer" / "Refuser" ; si `'leitor'`, afficher "En attente de la biblio".

---

## 5. Matrice des transitions

### 5.1 Cycle de vie d'une consultation (vue agrégée)

```
                  [création par lecteur]                [création par staff]
                  AccountPage                            PanelPage (à venir)
                  fn_v2_create_consulta…                fn_v2_create_consulta…
                            \                                  /
                             \                                /
                              ▼                              ▼
                          ┌────────────────────────────────────┐
                          │  workflow_stage = 'solicitada'     │
                          │  item_status = 'ativa'             │
                          │  status_global = 'ativa'           │
                          └─────────────────┬──────────────────┘
                                            │
                                            │ staff prépare
                                            ▼
                          ┌────────────────────────────────────┐
                          │  workflow_stage = 'em_preparacao'  │
                          └─────────────────┬──────────────────┘
                                            │
                                            │ staff propose créneau
                                            │ (consultation_scheduled_for OU
                                            │  consultation_starts_at/_ends_at)
                                            ▼
                          ┌────────────────────────────────────┐
                          │  workflow_stage = 'consulta_agendada'│
                          │  schedule_proposed_by = 'biblio'    │
                          │  schedule_reply_status = NULL       │
                          └─────────┬──────────────────┬───────┘
                                    │                  │
                       lecteur confirme           lecteur refuse
                       (schedule_reply_status     (schedule_reply_status
                        = 'confirmado_leitor')    = 'recusado_leitor')
                                    │                  │
                                    │                  └─► nouveau cycle agendamento
                                    │                      (boucle limitée par
                                    │                       negotiation_iteration_count)
                                    │
                       jour J : staff marque
                                    │
                          ┌─────────┴────────────────┐
                          │                          │
                          ▼                          ▼
        ┌────────────────────────┐    ┌────────────────────────┐
        │  workflow_stage =      │    │  workflow_stage =      │
        │  'consulta_realizada'  │    │  'nao_compareceu'      │
        │  item_status =         │    │  item_status reste     │
        │  'consultada'          │    │  'ativa' (workflow log │
        │  consulted_at = now()  │    │  uniquement)           │
        └────────────────────────┘    └────────────────────────┘

Transitions latérales possibles à tous les stades non-terminaux :
  → cancelada_leitor (par lecteur via fn_v2_cancel_consulta_linhas_as_leitor)
  → cancelada_biblioteca (par staff via fn_v2_set_consulta_linhas_workflow)
  → expirada (par system/cron sur expires_at)
```

### 5.2 Matrice détaillée : qui peut faire quoi depuis quel stage

| from \ to | em_preparacao | consulta_agendada | consulta_realizada | nao_compareceu | cancelada_leitor | cancelada_biblioteca | expirada |
|---|---|---|---|---|---|---|---|
| `solicitada` | staff | — | — | — | **lecteur** | staff | system |
| `em_preparacao` | — | staff | — | — | **lecteur** | staff | system |
| `consulta_agendada` | — | staff* | staff | staff | **lecteur** | staff | system |
| `consulta_realizada` | — | — | — | — | — | — | — |
| `nao_compareceu` | — | — | — | — | — | staff** | — |
| `cancelada_leitor` | — | — | — | — | — | — | — |
| `cancelada_biblioteca` | — | — | — | — | — | — | — |
| `expirada` | — | — | — | — | — | — | — |

Légende :
- **staff** = `librarian` / `coordenador` / `administrador`
- **lecteur** = propriétaire de la consultation uniquement (vérifié par ownership)
- **staff*** = re-proposition de créneau après refus du lecteur (boucle limitée par `negotiation_iteration_count < 3`)
- **staff** = possibilité de reclasser un no-show en annulation biblio si erreur de pointage
- **system** = jobs cron (expiration sur `expires_at`)
- `—` = transition non autorisée

### 5.3 Règles de transitions par acteur

**Lecteur** :
- Peut **annuler** sa consultation (`cancelada_leitor`) depuis tout stage non-terminal
- Peut **répondre** à une proposition de créneau (`confirmado_leitor` / `recusado_leitor`) uniquement quand `workflow_stage = 'consulta_agendada'` ET `schedule_proposed_by = 'biblio'`
- Peut **fermer** (dismiss) une ligne annulée par la biblio (action UI sans changement d'état métier, juste un `dismissed_by_reader_at = now()`)
- Ne peut **pas** changer d'autres stages

**Staff (librarian / coordenador / administrador)** :
- Peut **avancer** une consultation depuis `solicitada` vers `em_preparacao`
- Peut **proposer un créneau** (`em_preparacao` → `consulta_agendada` OU `consulta_agendada` → `consulta_agendada` si re-proposition)
- Peut **marquer réalisée** (`consulta_agendada` → `consulta_realizada`)
- Peut **marquer no-show** (`consulta_agendada` → `nao_compareceu`)
- Peut **annuler côté biblio** (`*` → `cancelada_biblioteca`) avec note obligatoire
- Ne peut **pas** "fermer" pour le lecteur (le dismiss est une action lecteur)

**System (jobs cron)** :
- Peut **expirer** une consultation non terminale dont `consulta_linhas_v2.expires_at < now()`
- Aucune autre transition

### 5.4 Validation du créneau de consultation

À chaque transition vers `consulta_agendada`, valider via `fn_validate_consulta_schedule_window` :

1. Le créneau (`consultation_scheduled_for` OU `[starts_at, ends_at]`) est dans les **horaires d'ouverture** de la biblio (`library_opening_hours`)
2. Le créneau n'est pas dans le **passé**
3. Le créneau ne **chevauche** pas une autre consultation `consulta_agendada` du même `holding_id` (pour les fonds limités à 1 exemplaire physique)
4. Le créneau est dans une **plage raisonnable** (par défaut : entre +1h et +60j)

Si une règle échoue, raise `schedule_window_invalid` avec le détail.
---

## 6. RPC publiques — contrats

### 6.1 Création — `api.create_consulta_local`

Wrapper `api.*` SECURITY INVOKER autour de `fn_v2_create_consulta_local_by_holdings`. Accessible aux lecteurs (qui créent leur propre demande) et au staff (qui peut créer une demande pour un lecteur depuis `PanelPage`).

```sql
CREATE OR REPLACE FUNCTION api.create_consulta_local(
  p_user_id uuid,           -- pour le staff : lecteur cible ; pour le lecteur : doit = auth.uid()
  p_holding_ids bigint[],
  p_expires_at timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_library_id uuid;
  v_actor_role text;
  v_consulta_id bigint;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  -- Si le lecteur cree pour lui-meme, ok ; si le staff cree pour un autre, verifier role
  IF p_user_id <> v_caller_uid THEN
    SELECT library_id INTO v_library_id FROM public.book_holdings WHERE id = p_holding_ids[1];
    v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);
    IF v_actor_role NOT IN ('librarian', 'coordenador', 'administrador') THEN
      RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
    END IF;
  END IF;

  v_consulta_id := public.fn_v2_create_consulta_local_by_holdings(
    p_user_id, p_holding_ids, p_expires_at, p_notes
  );

  RETURN jsonb_build_object('ok', true, 'consulta_id', v_consulta_id);
END;
$$;
```

### 6.2 Avancer le workflow par le staff — `api.advance_consulta`

Wrapper unifié pour les transitions staff `solicitada → em_preparacao`, `em_preparacao → consulta_agendada`, `consulta_agendada → consulta_realizada` / `nao_compareceu` / `cancelada_biblioteca`.

```sql
CREATE OR REPLACE FUNCTION api.advance_consulta(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_target_stage text,
  p_workflow_note text DEFAULT NULL,
  p_consultation_scheduled_for timestamptz DEFAULT NULL,
  p_consultation_starts_at timestamptz DEFAULT NULL,
  p_consultation_ends_at timestamptz DEFAULT NULL,
  p_consultation_timezone text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
  v_current_stage text;
  v_updated int;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found: consulta % nao encontrada', p_consulta_id USING ERRCODE = 'P0001';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  -- Recuperer le stage courant (premier line_no pour reference)
  SELECT workflow_stage INTO v_current_stage
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id AND line_no = p_line_nos[1];

  IF NOT public.fn_check_consulta_transition(v_current_stage, p_target_stage, v_actor_role) THEN
    RAISE EXCEPTION 'invalid_stage: transicao % -> % nao permitida para %', 
      v_current_stage, p_target_stage, v_actor_role
      USING ERRCODE = '42501';
  END IF;

  -- Si on planifie un creneau, choisir la bonne fn DEFINER
  IF p_target_stage = 'consulta_agendada' AND p_consultation_starts_at IS NOT NULL THEN
    v_updated := public.fn_v2_set_consulta_linhas_workflow_slot(
      p_consulta_id, p_line_nos, p_target_stage, p_workflow_note,
      to_char(p_consultation_starts_at, 'YYYY-MM-DD'),
      to_char(p_consultation_starts_at, 'HH24:MI'),
      to_char(p_consultation_ends_at, 'HH24:MI'),
      p_consultation_timezone
    );
  ELSE
    v_updated := public.fn_v2_set_consulta_linhas_workflow(
      p_consulta_id, p_line_nos, p_target_stage, p_workflow_note, p_consultation_scheduled_for
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'updated_count', v_updated);
END;
$$;
```

### 6.3 Réponse du lecteur à un créneau — `api.reply_consulta_schedule`

```sql
CREATE OR REPLACE FUNCTION api.reply_consulta_schedule(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_reply text,            -- 'confirmado_leitor' OU 'recusado_leitor'
  p_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_updated int;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found: consulta %', p_consulta_id USING ERRCODE = 'P0001';
  END IF;

  -- Seul le proprietaire peut repondre
  IF v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_owner: voce so pode responder sobre suas consultas' USING ERRCODE = '42501';
  END IF;

  IF p_reply NOT IN ('confirmado_leitor', 'recusado_leitor') THEN
    RAISE EXCEPTION 'invalid_stage: reply % invalide', p_reply USING ERRCODE = 'P0001';
  END IF;

  v_updated := public.fn_v2_set_consulta_linhas_schedule_reply(
    p_consulta_id, p_line_nos, p_reply, p_note
  );

  RETURN jsonb_build_object('ok', true, 'updated_count', v_updated);
END;
$$;
```

### 6.4 Annulation par le lecteur — `api.cancel_consulta_as_reader`

Wrapper `api.*` SECURITY INVOKER autour de `fn_v2_cancel_consulta_linhas_as_leitor`, avec vérification d'ownership explicite dans le wrapper.

```sql
CREATE OR REPLACE FUNCTION api.cancel_consulta_as_reader(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_updated int;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0001';
  END IF;

  IF v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_owner: voce so pode cancelar suas proprias consultas' USING ERRCODE = '42501';
  END IF;

  v_updated := public.fn_v2_cancel_consulta_linhas_as_leitor(p_consulta_id, p_line_nos, p_notes);
  RETURN jsonb_build_object('ok', true, 'cancelled_count', v_updated);
END;
$$;
```

### 6.5 Fermeture (dismiss) par le lecteur — `api.dismiss_consulta_cancelled`

Action UI : le lecteur "ferme" la ligne d'une consultation annulée par la biblio (set `dismissed_by_reader_at`). Pas de changement d'état métier.

Wrapper analogue avec ownership check.

### 6.6 Pas de wrapper pour `fn_validate_consulta_schedule_window`

Cette fonction reste un helper interne appelé depuis `fn_v2_set_consulta_linhas_workflow*`. Pas d'exposition publique.

### 6.7 Helpers à créer

**`fn_check_consulta_transition(p_from text, p_to text, p_actor_role text) RETURNS boolean`** :

Implémente la matrice §5.2. IMMUTABLE. Fail-closed sur arguments inconnus. Sera utilisé par `api.advance_consulta` et par les tests d'acceptation.

**`fn_get_consulta_context(p_consulta_id bigint) RETURNS TABLE(library_id uuid, leitor_user_id uuid, status_global text)`** :

Analogue à `fn_get_loan_context`. STABLE. Permet aux wrappers de résoudre rapidement le contexte avant la vérification de rôle.

---

## 7. Triggers et notifications

### 7.1 État à auditer en Phase 0

Lancer :

```sql
SELECT 
  tgname, 
  CASE WHEN tgrelid::regclass::text LIKE '%consulta%' THEN tgrelid::regclass::text END AS table_name,
  pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE NOT tgisinternal
  AND tgrelid::regclass::text LIKE '%consulta%'
ORDER BY tgname;
```

Selon le résultat :
- Si triggers existent → documenter les événements émis, vérifier qu'ils sont consommés côté Edge Function
- Si aucun trigger → en créer (cf. §7.2)

### 7.2 Triggers cibles (à créer si absents)

**`trg_notify_consulta_lifecycle`** sur `consulta_linhas_v2` (item_status DISTINCT FROM) :
- INSERT → `consulta_v2_criada`
- UPDATE item_status `ativa → consultada` → `consulta_v2_realizada`
- UPDATE item_status `ativa → cancelada_*` → `consulta_v2_cancelada` (avec discriminant lecteur/biblio)
- UPDATE item_status `ativa → expirada` → `consulta_v2_expirada`

**`trg_notify_consulta_workflow`** sur `consulta_item_workflow_v2` (workflow_stage transition) :
- workflow_stage transition vers `consulta_agendada` → `consulta_v2_agendada` (mail au lecteur avec créneau)
- schedule_reply_status DISTINCT FROM (nouveau) → `consulta_v2_resposta_creneau` (mail à la biblio)

### 7.3 Handler Edge Function `notify-event`

Créer ou étendre `handlers/consultas.ts` pour traiter ces 5 événements. Inspiration directe : `handlers/reservas.ts` qui gère déjà les négociations de créneau.

Clés i18n à ajouter dans `_shared/i18n/mail-strings.ts` :

```
mail.consulta.criada.subject / body
mail.consulta.agendada.subject / body  (avec date+heure+timezone)
mail.consulta.resposta_creneau.subject / body  (à la biblio)
mail.consulta.realizada.subject / body
mail.consulta.cancelada.subject / body  (avec discriminant lecteur/biblio)
mail.consulta.expirada.subject / body
```

× 6 locales = ~60 nouvelles clés.

### 7.4 Toggles

Ajouter à `library_notification_policies` :

```sql
ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS consulta_lifecycle_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS consulta_reminders_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS admin_copy_consultas_enabled boolean NOT NULL DEFAULT true;
```

Lus par les triggers avant émission.

---

## 8. Surfaces UI

### 8.1 AccountPage.jsx — onglet "Consultations sur place"

Migrations frontend depuis les fns DEFINER directes vers les wrappers `api.*` :

| Appel actuel | Appel cible |
|---|---|
| `supabase.rpc('fn_v2_create_consulta_local_by_holdings', ...)` | `supabase.schema('api').rpc('create_consulta_local', ...)` |
| `supabase.rpc('fn_v2_cancel_consulta_linhas_as_leitor', ...)` | `supabase.schema('api').rpc('cancel_consulta_as_reader', ...)` |
| `supabase.rpc('fn_v2_dismiss_consulta_cancelled_as_leitor', ...)` | `supabase.schema('api').rpc('dismiss_consulta_cancelled', ...)` |
| (nouveau) | `supabase.schema('api').rpc('reply_consulta_schedule', ...)` |

Nouvelles UI à intégrer :
- **Bloc "Créneau proposé"** : quand `workflow_stage = 'consulta_agendada'` ET `schedule_reply_status IS NULL` ET `schedule_proposed_by = 'biblio'`, afficher la date+heure+timezone proposée + boutons "Confirmer" / "Refuser ce créneau"
- **Bloc "Créneau confirmé"** : quand `schedule_reply_status = 'confirmado_leitor'`, afficher "Rendez-vous le {date} à {heure}"
- **Bloc "Annulée par la biblio"** : quand `item_status = 'cancelada_biblioteca'` ET `dismissed_by_reader_at IS NULL`, afficher la note de la biblio + bouton "Fermer" (appelle `api.dismiss_consulta_cancelled`)

### 8.2 PanelPage.jsx — onglet "Consultations" (à créer ou à étendre)

Liste des consultations actives, filtrable par stage. Actions par ligne :

- **Avancer** (dropdown stage) → `api.advance_consulta`
- **Proposer un créneau** (formulaire date + heure début + heure fin + timezone) → `api.advance_consulta` avec target `consulta_agendada`
- **Marquer réalisée** → `api.advance_consulta` avec target `consulta_realizada`
- **Marquer no-show** → `api.advance_consulta` avec target `nao_compareceu`
- **Annuler côté biblio** → `api.advance_consulta` avec target `cancelada_biblioteca` (note obligatoire)

Filtre par stage avec compteurs (cf. pattern hero emprunts).

### 8.3 Catalogue (livro.html)

Si un holding est `consultable_only = true`, afficher un bouton "Demander une consultation" au lieu de "Réserver l'emprunt". L'action redirige vers `/conta` avec préfill du bib_ref.

---

## 9. Phases d'implémentation

Estimation totale : ~5 jours de travail.

### Phase 0 — Audit (1 demi-journée)

1. Lister triggers de notification existants sur les 3 tables consultations
2. Vérifier toggles `library_notification_policies`
3. Grep `mail-strings.ts` pour les clés `consulta.*`
4. Grep `PanelPage.jsx` pour identifier les appels déjà branchés
5. Vérifier structure de `api.my_consultas_active_v2` (colonnes exposées)
6. Documenter les écarts entre l'observé et la cible §7

**Livrable** : section §2.4 et §2.7 mises à jour avec les vraies données. Pas de code, juste un audit pour cadrer la suite.

### Phase 1 — Helpers + matrice de transitions + invariant emprunt/consulta (1 journée)

1. Migration `YYYYMMDDHHMMSS_consulta_helpers.sql` :
   - `fn_check_consulta_transition(from, to, role)` — matrice §5.2
   - `fn_get_consulta_context(consulta_id)` — lookup

2. **Migration `YYYYMMDDHHMMSS_invariant_emprestimo_vs_consulta.sql` (Phase 0 ajout)** : patch de `fn_v2_create_emprestimo_by_holdings` pour vérifier l'absence de `consulta_linhas_v2.item_status = 'ativa'` sur le holding cible (analogue à la vérification réservations actives déjà présente). Inversement, étendre `fn_v2_create_consulta_local_by_holdings` pour vérifier l'absence d'emprunt actif ET de réservation active sur le holding.

3. Tests SQL d'acceptation pour les helpers + invariant (~20 tests dans `tests/sql/paquetXX_consulta_helpers_tests.sql`).

### Phase 2 — Wrappers `api.*` (1 journée)

1. Migration `YYYYMMDDHHMMSS_consulta_workflow_wrappers.sql` :
   - `api.create_consulta_local`
   - `api.advance_consulta`
   - `api.reply_consulta_schedule`
   - `api.cancel_consulta_as_reader`
   - `api.dismiss_consulta_cancelled`

2. Tests SQL d'acceptation (~30 tests : auth + rôle + stage + ownership + happy path) dans `tests/sql/paquetXX_consulta_wrappers_tests.sql`

### Phase 3 — Notifications (1 journée)

1. Audit + création éventuelle des triggers (`trg_notify_consulta_lifecycle`, `trg_notify_consulta_workflow`)
2. Toggles `library_notification_policies` (3 colonnes si absentes)
3. Handler `notify-event/handlers/consultas.ts` (création ou extension)
4. Clés i18n mails (~60 clés × 6 locales) dans `_shared/i18n/mail-strings.ts`
5. Test e2e : créer consultation → recevoir mail, biblio agende → recevoir mail avec créneau, etc.

### Phase 4 — Frontend lecteur (1 demi-journée)

1. AccountPage — migration appels `fn_v2_*` vers `api.*` (3 sites)
2. AccountPage — nouveau bloc "Créneau proposé" avec boutons confirmer/refuser → `api.reply_consulta_schedule`
3. AccountPage — bloc "Annulée par biblio" avec bouton Fermer → `api.dismiss_consulta_cancelled`
4. AccountPage — clés i18n `account.consulta.*` (~25 clés × 6 locales)

### Phase 5 — Frontend bibliothécaire (1 demi-journée — UI déjà en place)

L'audit Phase 0 a montré que l'onglet `consultas-locais` de `PanelPage.jsx` est déjà largement branché (24 occurrences, 4 boutons d'action). Le travail consiste à enrichir l'existant plutôt qu'à le créer.

1. **Fix bug latent L1520** : le bouton "Agender" appelle `setConsultaWorkflow(consultaId, lineNo, 'consulta_agendada')` sans date. Remplacer par un formulaire modal qui collecte : date, heure début, heure fin optionnelle, timezone par défaut (celle de la biblio), note workflow. Appel `api.advance_consulta` avec `target_stage='consulta_agendada'` + params créneau.

2. Migration des 4 appels `setConsultaWorkflow` existants vers `api.advance_consulta` :
   - Préparer → `api.advance_consulta(target='em_preparacao')`
   - Agender → `api.advance_consulta(target='consulta_agendada', consultation_*)` (cf. point 1)
   - Marquer réalisé → `api.advance_consulta(target='consulta_realizada')`
   - Annuler côté biblio → `api.advance_consulta(target='cancelada_biblioteca', workflow_note=obligatoire)`

3. Nouveau bouton **Marquer no-show** (`nao_compareceu`) — manquant dans l'UI actuelle, à ajouter à côté de "Marquer réalisé" (visible uniquement si stage = `consulta_agendada`).

4. Affichage de la réponse du lecteur sur le créneau proposé (colonne ou pastille selon `schedule_reply_status` : `confirmado_leitor` / `recusado_leitor` / NULL).

5. Création de consultation par staff pour un lecteur (analogue à la création d'emprunt depuis l'onglet "Ações"). Appelle `api.create_consulta_local` avec `p_user_id` choisi.

6. Clés i18n `panel.consulta.*` (~15 clés × 6 locales).

### Phase 6 — Tests runtime (1 demi-journée)

Scénarios à dérouler en prod :

1. Lecteur crée consultation → mail biblio reçu
2. Biblio passe `solicitada → em_preparacao` → mail lecteur reçu
3. Biblio propose créneau → mail lecteur avec date+heure
4. Lecteur confirme créneau → mail biblio
5. Jour J : biblio marque `consulta_realizada` → mail lecteur de confirmation
6. Scénario refus : lecteur refuse créneau → biblio re-propose (boucle iteration_count++)
7. Scénario no-show : créneau passé, biblio marque `nao_compareceu`
8. Scénario annulation lecteur depuis stages variés (solicitada, agendada)
9. Scénario annulation biblio avec note → lecteur dismiss → ligne disparaît de l'UI

### Phase 7 — Commit et déploiement

Commits par phase pour traçabilité. Push Codeberg + GitHub.

---

## 10. Points ouverts pour discussion future

### 10.1 Compteur de négociation

Question : retient-on `negotiation_iteration_count` (cf. §4.2) maintenant ou plus tard ? Côté réservations, ce garde-fou a été utile pour éviter des boucles infinies de contre-propositions. Côté consultations, le volume est plus faible donc le risque moindre, mais le pattern reste pertinent. **Recommandation** : inclure en Phase 2 (effort marginal).

### 10.2 Contre-proposition par le lecteur

Côté réservations, le lecteur peut contre-proposer un créneau (`retirada_a_combinar → retirada_a_combinar` avec `pickup_proposed_by = 'leitor'`). Côté consultations, on n'a pas prévu ce chemin dans la matrice §5.2 — seul `schedule_reply_status = 'recusado_leitor'` est possible.

Question : permet-on au lecteur de proposer activement un autre créneau, ou il refuse et attend la biblio ?

**Recommandation** : pour la v1, refuse seulement (le lecteur peut commenter via `schedule_reply_note` mais ne propose pas). Si besoin se manifeste, ajouter en Phase 5+.

### 10.3 Rappels de créneau (J-1, jour J)

Hors périmètre de cette spec. À couvrir via `fn_cron_notify_consulta_reminders` analogue aux rappels d'emprunt.

### 10.4 Multi-items dans une même consultation

La table `consulta_linhas_v2` supporte plusieurs items (`line_no`). Le workflow le supporte aussi (chaque line_no a son propre stage). Mais l'UI lecteur actuelle traite une consultation comme une seule ligne. À clarifier : peut-on grouper plusieurs holdings dans une seule consultation (ex. consulter 3 numéros d'une revue en une session) ?

**Recommandation** : oui, mais réserver le multi-items au staff (création depuis PanelPage). Le lecteur depuis AccountPage crée une consultation par holding. Pattern simple, UI déjà fonctionnelle.

### 10.5 Annulation d'une consultation par erreur (côté staff)

Aucun chemin actuel pour "rouvrir" une consultation annulée. Acceptable si l'erreur est rare ; à formaliser en cas de besoin via un wrapper `api.reopen_consulta` (uniquement administrador).

---

## 11. Risques et invariants

### 11.1 Invariants à préserver

1. **`item_status` toujours dérivé**. Aucun UPDATE direct sur `consulta_linhas_v2.item_status` hors des fns DEFINER. Le wrapper `api.*` ne fait que valider et déléguer.
2. **Workflow log immuable** (par convention) : `consulta_item_workflow_v2` enregistre l'historique des transitions. Le UPDATE existant ne réécrit que la ligne courante (clé `(consulta_id, line_no)`) ; pour conserver vraiment l'historique, il faudrait passer en INSERT only — décision à prendre en Phase 0.
3. **Ownership lecteur strict** : toute action lecteur vérifie `auth.uid() = consultas_locais_v2.user_id` dans le wrapper `api.*` (et pas seulement dans la fn DEFINER, pour éviter de réintroduire le bug du paquet 20 v2).
4. **`status_global` toujours dérivé** : aucun UPDATE direct, recalcul via `fn_v2_refresh_consulta_status_global`.
5. **Créneau toujours validé** : avant tout passage à `consulta_agendada`, `fn_validate_consulta_schedule_window` est appelée.

### 11.2 Risques identifiés

- **Risque #1** : la création d'un wrapper `api.advance_consulta` qui appelle conditionnellement `fn_v2_set_consulta_linhas_workflow` ou `fn_v2_set_consulta_linhas_workflow_slot` selon présence des params crée une surface de bug. Mitigation : tests SQL exhaustifs en Phase 2.

- **Risque #2** : si Phase 0 révèle qu'aucun trigger de notification n'existe, la Phase 3 devient plus longue (création de zéro). Mitigation : prévoir +1 journée pour Phase 3 dans ce cas.

- **Risque #3** : le découplage `item_status` ↔ `workflow_stage` peut créer des incohérences si on modifie l'un sans l'autre. Exemple : `workflow_stage = 'consulta_realizada'` mais `item_status` reste `'ativa'`. La fn `fn_v2_set_consulta_linhas_workflow` gère ce sync mais avec une logique implicite (CASE WHEN). À documenter clairement dans la spec et à tester.

- **Risque #4** : bug analogue à celui du paquet 20 v2 (`fn_resolve_caller_role_for_library` retourne NULL pour les lecteurs purs) — DÉJÀ FIXÉ au paquet 20 v2 mais les wrappers consultations devront tester ce cas dès le départ pour éviter une régression silencieuse.

---

## 12. Cohérence avec les autres specs

| Spec | Lien |
|---|---|
| spec-flux-emprunts.md | Chaîne sœur. Aucune interaction directe sauf via la règle "un même holding ne peut pas avoir simultanément un emprunt actif ET une consultation active" (à vérifier en Phase 0, probablement déjà géré par les fns de création). |
| spec-workflow-reservation.md | Modèle de négociation de créneau (matrice from→to, schedule_reply, compteur de négociation) que cette spec reproduit pour les consultations. Pas de RPC partagée. |
| spec-gouvernance-roles.md | `librarian` / `coordenador` / `administrador` mobilisés dans les vérifications de rôle via `fn_resolve_caller_role_for_library` (fixé au paquet 20 v2 pour aussi retourner `'leitor'`). |
| spec-validation-physique.md | Indépendante. Le `user_id` utilisé doit être validé physiquement, mais la spec consultations ne re-vérifie pas (déléguée). |

---

*Spec rédigée le 11/05/2026. À implémenter en 7 phases sur ~5 jours de travail si pris en continu. Phase 0 (audit) prioritaire avant tout codage.*
