# Spec — Flux des consultations sur place

> **Statut** : v2.2 du 20/05/2026 — **chantier entièrement livré en production**, Phases 0-5 closes (paquets 24, 25, 26, 27). Phase 6 (tests E2E) reportée au profit d'une QA manuelle structurée. Hardening notifications du paquet 141 (16/05/2026) **intégré normativement** dans cette version.
> **Périmètre** : consultations sur place (`consultas_locais_v2` + `consulta_linhas_v2` + `consulta_item_workflow_v2`). Hors périmètre : prêt inter-bibliothèques, emprunts à domicile.
> **Spec sœur** : spec-flux-emprunts.md (chaîne parallèle pour les emprunts).
> **Spec amont** : spec-workflow-reservation.md (modèle de négociation de créneau dont s'inspire la phase d'agendamento de consultation).
> **Specs liées (v0.4 et v2.0 du 20/05)** : `spec-administrateur-reseau.md v0.4` et `spec-onboarding-biblioteca.md v2.0` portent la doctrine anti-méga-machine. Cette doctrine **ne touche pas directement** les flux consultas (mécanique de circulation, hors champ humain proactif), mais elle s'articule indirectement via la doctrine R8 traçabilité coordination généralisée à toute action staff (cf. §11.2 R10 nouveau).
> **Changelog v1 → v2** : audit Phase 0 ajouté §2.4-§2.8 (aucun trigger, aucune clé mail, aucun handler, UI staff partielle avec bug latent L1520, UI lecteur incomplète, invariant emprunt-vs-consulta non garanti). Phase 1 et Phase 5 ajustées en conséquence.
> **Changelog v2 → v2.1** : refonte post-implémentation. Toutes les phases marquées closes avec leurs commits de référence. Raffinements doctrinaux R1-R6 inscrits.
> **Changelog v2.1 → v2.2** *(20/05/2026)* : intégration normative des doctrines techniques issues du chantier #141 (hardening notifications consultas du 16/05/2026, 7 bugs résolus en prod). Raffinements R7-R11 ajoutés en §11.2 : **R7 ordre UPDATE narrative-avant-état** (#141.2.E), **R8 distinction `workflow_note` vs `schedule_reply_note`** (#141.2.C), **R9 traçabilité coordination R8 généralisée** (mail biblio sur action staff annulation/no-show), **R10 cohérence handler vs trigger** (signature payload), **R11 mojibake UTF-8 i18n** (doctrine technique PowerShell + propagation). Cf. §14.5 changelog détaillé.

---

## 1. Contexte et objectif politique

Dans une bibliothèque militante anarchiste, la consultation sur place couvre les matériaux qui ne sortent pas : périodiques rares, brochures fragiles, fonds patrimoniaux, archives militantes, mémoires. C'est un acte différent de l'emprunt — il suppose un temps partagé dans l'espace de la biblio, souvent un échange avec un·e bibliothécaire qui ouvre l'armoire ou apporte le document.

L'objectif de cette spec est de reconnaître cette spécificité dans le SIGB : ne pas réduire la consultation à un sous-cas d'emprunt mais lui donner un workflow propre, avec une **négociation de créneau** entre lecteur·rice et bibliothécaire, le respect des horaires d'ouverture, et une lisibilité totale des règles (qui peut faire quoi à quel stade, pourquoi le créneau est refusé, comment l'annuler).

La spec couvre le cycle de vie d'une consultation depuis sa création jusqu'à sa clôture, en alignant les patterns architecturaux sur les emprunts (wrappers `api.*` SECURITY INVOKER, helper de matrice de transitions, tests SQL d'acceptation) pour faciliter la maintenance par toute personne contribuant au code.

L'objectif n'est pas de réécrire le backend — les 8 fonctions DEFINER existent depuis longtemps et fonctionnent — mais d'exposer une couche `api.*` propre, de documenter formellement les invariants, et d'écrire les tests qui manquent pour détecter les bugs critiques comme celui de `fn_resolve_caller_role_for_library` découvert lors du paquet 20.

**Bilan d'implémentation (v2.1)** : objectif intégralement atteint. La couche `api.*` est en prod (5 wrappers), les invariants sont garantis par contrainte DB, le frontend lecteur et bibliothécaire utilisent exclusivement les wrappers, et le workflow consultations est opérationnel bout-en-bout avec mails militants à chaque transition.

---

## 2. État de l'existant au 11/05/2026 *(état initial avant chantier)*

> Cette section décrit l'état avant le démarrage du chantier (Phase 0 d'audit). Pour l'état final post-implémentation, voir §10 et §13.

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
| `consultation_scheduled_for` | timestamptz | — | date/heure de la consultation (créneau ponctuel, legacy) |
| `consultation_starts_at`, `consultation_ends_at` | timestamptz | — | fenêtre [début, fin] (modèle privilégié depuis paquet 27) |
| `consultation_timezone` | text | — | timezone de la biblio au moment où le créneau a été fixé |
| `schedule_reply_status` | text | — | **CHECK : `confirmado_leitor` / `recusado_leitor`** (nullable) |
| `schedule_reply_note`, `schedule_reply_at` | text/timestamptz | — | trace de la réponse du lecteur |
| `updated_at`, `updated_by` | timestamptz/uuid | — | dernière modification |

**Observation architecturale** : contrairement aux emprunts (`item_status` directement sur `emprestimo_itens_v2`), les consultations utilisent un **modèle event-log** : l'état métier est sur `consulta_linhas_v2.item_status` (5 valeurs) mais le workflow détaillé (avec créneau + réponse lecteur) est sur `consulta_item_workflow_v2.workflow_stage` (8 valeurs). Ce découplage permet une négociation de créneau plus riche.

### 2.2 Fonctions PL/pgSQL existantes (avant Phase 2)

| Fonction | Rôle | Sécurité |
|---|---|---|
| `fn_v2_create_consulta_local_by_holdings(p_user_id, p_holding_ids[], p_expires_at, p_notes)` | Création par le lecteur OU le bibliothécaire | DEFINER |
| `fn_v2_set_consulta_linhas_workflow(p_consulta_id, p_line_nos[], p_workflow_stage, p_workflow_note, p_consultation_scheduled_for)` | Transition de workflow par le staff (créneau ponctuel legacy) | DEFINER, valide les 6 stages staff |
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
| `api.consulta_itens_followup_ui` | staff | Suivi par la biblio (similaire à `reserva_itens_followup_ui`). **Enrichie au paquet 26** avec `consultation_starts_at`, `consultation_ends_at`, `schedule_reply_status`, `schedule_reply_note`, `workflow_note`, `workflow_stage_effective`. |

### 2.4 Triggers de notification *(avant Phase 3 du paquet 26)*

**Audit Phase 0 (11/05/2026)** : **aucun trigger** sur les 3 tables consultations. La requête `SELECT tgname FROM pg_trigger WHERE tgrelid::regclass::text LIKE '%consulta%'` retournait 0 ligne. Aucune notification mail n'était émise automatiquement.

Conséquence : Phase 3 a créé ces triggers de zéro (cf. §7).

### 2.5 Toggles de notification (`library_notification_policies`)

**Audit Phase 0 (11/05/2026)** : seul `local_consultation_enabled` (boolean, default true) existait — c'est un toggle "feature on/off" (autoriser la consultation sur place dans cette biblio), **pas** un toggle de notification.

Ajoutés en Phase 3 (paquet 26) :
- `consulta_lifecycle_enabled` — création, agendamento, réalisation, annulation
- `consulta_reminders_enabled` — rappels J-1 / jour J du créneau (mécanique livrée mais cron dormant)
- `admin_copy_consultas_enabled` — copie carbone aux bibliothécaires

Le toggle `local_consultation_enabled` reste indépendant et est lu en amont par le frontend pour afficher (ou non) le bouton "Demander une consultation".

### 2.6 Surfaces UI existantes *(avant Phase 4/5)*

**Audit Phase 0 (11/05/2026)** :

**Côté lecteur (`AccountPage.jsx`)** :
- Création : OK via le formulaire mutualisé réservation/consultation (`isConsultation ? 'fn_v2_create_consulta_local_by_holdings' : 'fn_v2_create_reserva_by_holdings'`, L258)
- Affichage des consultations actives via `api.my_consultas_active_v2` : ✓ existant
- **Annulation par le lecteur : NON implémentée** → ajoutée au paquet 27.A.2
- **Réponse à un créneau proposé : NON implémentée** → ajoutée au paquet 27.A.5
- **Fermeture (dismiss) d'une annulation biblio : NON implémentée** → à terminer (point 4.2 §8.1 ci-dessous)

**Côté bibliothécaire (`PanelPage.jsx`)** : 24 occurrences `consulta`, largement branché :
- Onglet `consultas-locais` (L1485)
- Affichage via `consulta_itens_followup_ui` (L352)
- Tri par colonne (paquet 18 appliqué, L1496)
- Hero avec compteurs : "Consultations actives" + "Consultations en attente" (L1126, L1159)
- Helper `setConsultaWorkflow(consultaId, lineNo, stage, note)` qui appelle `fn_v2_set_consulta_linhas_workflow` (L745-754)
- 4 boutons d'action :
  - **Préparer** (`em_preparacao`) — L1517
  - **Agender** (`consulta_agendada`) — L1520 (avec bug latent, cf. ci-dessous)
  - **Marquer réalisé** (`consulta_realizada`) — L1523
  - **Annuler côté biblio** (`cancelada_biblioteca`) — L1526
- Tâche dans le panel quotidien (`buildDailyTasks`) si stage `solicitada` (L839-840)

**Bug latent détecté L1520 (résolu au paquet 27.A.4 / 5.B)** : le bouton "Agender" appelait `setConsultaWorkflow(consultaId, lineNo, 'consulta_agendada')` **sans passer de date** (`p_consultation_scheduled_for`). La fn DEFINER raisait alors `Informe a data e hora da consulta agendada`. Bug passé inaperçu car peu de consultations existaient en base. **Fixé** par le modal Agendar avec date+heure début+heure fin+note (paquet 27.A.4).

### 2.7 Audit Phase 0 — terminé

Audit conduit le 11/05/2026. Résultats récapitulés dans §2.4-§2.6 et §2.8. La conclusion principale : la couche backend de notifications consultations est entièrement à créer ; côté frontend, l'UI staff est partiellement en place (avec un bug latent) et l'UI lecteur a 3 fonctionnalités manquantes.

**Statut** : ✅ Phase 0 close 11/05/2026.

### 2.8 Constats critiques consolidés (Phase 0)

1. **Aucun trigger de notification** sur les 3 tables consultations. **→ Phase 3 = création complète (paquet 26).** ✅ Résolu
2. **Aucune clé i18n mail `consulta.*`** dans `mail-strings.ts` (1639 lignes auditées, 0 occurrence). **→ Phase 3 = ~60 clés × 6 locales = 360 traductions.** ✅ Résolu (paquet 26 L3)
3. **Aucun handler `consultations.ts`** dans `notify-event/handlers/`. **→ Phase 3 = création complète.** ✅ Résolu (paquet 26 L4)
4. **Pas de wrappers `api.*` pour les consultations.** Le frontend appelle directement les fonctions DEFINER. **→ Phase 2 = créer 5 wrappers SECURITY INVOKER.** ✅ Résolu (paquet 25)
5. **`fn_v2_set_consulta_linhas_workflow` ne lit pas de matrice de transitions formalisée.** **→ Phase 1 = créer `fn_check_consulta_transition` + l'utiliser dans le wrapper `api.advance_consulta`.** ✅ Résolu (paquet 24)
6. **Invariant emprunt-vs-consulta NON garanti côté backend.** Pas de vérification croisée dans `fn_v2_create_emprestimo_by_holdings`. **→ Patch en Phase 1.** ✅ Résolu (paquet 24)
7. **Bug latent UI staff (PanelPage L1520)** : "Agender" sans date. **→ Fix en Phase 5.** ✅ Résolu (paquet 27.A.4 / 5.B)
8. **UI lecteur incomplète** : annulation, réponse créneau, dismiss non implémentées. **→ Phase 4.** ✅ Résolu (paquets 27.A.2 et 27.A.5)
9. **Aucun test SQL d'acceptation** pour les consultations. **→ Phases 1 et 2 = ~45 tests.** ✅ Livrés

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

| Reply | PT-BR (lecteur) | PT-BR (biblio) | Pastille v2.1 (PanelPage) |
|---|---|---|---|
| `confirmado_leitor` | Confirmado | Confirmado pelo·a·e leitor·a·e | ✓ vert |
| `recusado_leitor` | Recusado | Recusado pelo·a·e leitor·a·e | ✗ orange + motif italique |
| (null) | Aguardando resposta | Aguardando resposta | ⏳ gris |

### 3.2 Motifs de refus d'action

| `reason` machine | PT-BR | EN | FR |
|---|---|---|---|
| `not_authenticated` | Sessão expirada. Faça login. | Session expired. Please log in. | Session expirée. |
| `not_found` | Consulta não encontrada. | Consultation not found. | Consultation introuvable. |
| `not_owner` | Você só pode agir sobre suas próprias consultas. | You can only act on your own consultations. | Tu ne peux agir que sur tes consultations. |
| `not_authorized` | Ação não autorizada para o seu papel. | Action not authorized for your role. | Action non autorisée pour ton rôle. |
| `invalid_stage` | Transição inválida desde a etapa atual. | Invalid transition from current stage. | Transition invalide depuis l'étape actuelle. |
| `schedule_window_invalid` | Horário fora do período de funcionamento da biblioteca. | Time outside library opening hours. | Horaire hors période d'ouverture. |
| `schedule_missing` *(v2.1, doctrine confirmée)* | Informe a data, hora de início **e** hora de término. | Provide date, start **and** end times. | Indique la date, l'heure de début **et** l'heure de fin. |
| `terminal_state` | Esta consulta já foi encerrada. | This consultation is already closed. | Cette consultation est déjà clôturée. |

**Note v2.1** : le motif `schedule_missing` a été précisé suite au hotfix 5.D (cf. §5.4 et §11.2 R1). Le backend exige **les trois éléments** ensemble (date + starts_at + ends_at), pas seulement la date.

### 3.3 Clés i18n ajoutées (× 6 locales)

**Clés mail** *(paquet 26 L3, ~60 × 6 = 360 traductions)* :

```
mail.consulta.criada.subject / body
mail.consulta.agendada.subject / body  (avec date+heure+timezone)
mail.consulta.resposta_creneau.subject / body  (à la biblio)
mail.consulta.realizada.subject / body
mail.consulta.cancelada.subject / body  (avec discriminant lecteur/biblio)
mail.consulta.expirada.subject / body
```

**Clés UI lecteur** *(paquets 27.A.2 et 27.A.5, AccountPage)* :

```
account.consulta.status.{ativa,consultada,cancelada_leitor,cancelada_biblioteca,expirada}
account.consulta.workflow.{solicitada,em_preparacao,consulta_agendada,consulta_realizada,nao_compareceu}
account.consulta.reply.{confirmado_leitor,recusado_leitor,pending}
account.consulta.action.{cancel,confirmSchedule,refuseSchedule,dismissCancelled}
account.consulta.scheduleProposedTitle
account.consulta.scheduleConfirmedTitle
account.consulta.refuseReason
account.consulta.cancelConfirm
account.consulta.denied.{reason}    # 8 reasons
```

**Clés UI biblio** *(paquets 27.A.4 et 27.A.6, PanelPage)* :

```
panel.consulta.status.{...} (5 clés)
panel.consulta.workflow.{...} (8 clés)
panel.consulta.action.advance
panel.consulta.action.proposeSchedule
panel.consulta.action.proposeAnother   # v2.1, paquet 27.A.6 (reproposition après refus)
panel.consulta.action.markRealized
panel.consulta.action.markNoShow
panel.consulta.action.cancelAsLibrary
panel.consulta.replyStatus.{confirmed,refused,pending}
panel.consulta.refuseReason   # v2.1
panel.consulta.noShowConfirm
panel.consulta.noShowReason
panel.consulta.schedule.{dateLabel,startsAtLabel,endsAtLabel,noteLabel,submit,cancel}
panel.consulta.schedule.errorRequired
panel.consulta.schedule.errorEndBeforeStart
panel.consulta.create.expiresAt
```

**Total final** : ~240 clés × 6 locales = ~1440 entrées (vs ~40 × 6 = 240 prévu en v2).

Conventions militantes appliquées (cf. `notes-audit/anarbib-charte-langage-inclusif-v1.md`) :
- pt-BR : forme triple `do/da/de` ou `leitor·a·e`
- fr : point médian `lecteur·rice`
- es : neutre `e` argentin (`lectore`)
- it : épicène `compagn*o` (jamais `camerati`)
- de : Genderstern `Genoss*in`

### 3.4 *(Nouveau v2.1)* Helper partagé `scheduleFormat.js`

Suite à la duplication observée entre AccountPage et PanelPage (deux copies presque identiques d'une fonction de formatage de créneau), un helper partagé a été extrait au paquet 27.A.6 :

```javascript
// src/lib/scheduleFormat.js
export function formatSchedule(c) {
  if (!c) return '';
  const starts = c.consultation_starts_at || c.consultation_scheduled_for;
  const ends = c.consultation_ends_at;
  if (!starts) return '';
  try {
    const startDate = new Date(starts);
    const dateStr = startDate.toLocaleDateString(undefined, {
      weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
    });
    const startTime = startDate.toLocaleTimeString(undefined, {
      hour: '2-digit', minute: '2-digit',
    });
    if (ends) {
      const endTime = new Date(ends).toLocaleTimeString(undefined, {
        hour: '2-digit', minute: '2-digit',
      });
      return `${dateStr} \u2014 ${startTime}\u2013${endTime}`;
    }
    return `${dateStr} \u2014 ${startTime}`;
  } catch {
    return starts;
  }
}
```

**Signature** : accepte un objet avec `consultation_starts_at`, `consultation_ends_at`, ou `consultation_scheduled_for` (legacy). Retourne une chaîne formatée selon la locale du navigateur (`undefined` → locale par défaut). Format : `« lundi 15 mai 2026 — 14:00–15:30 »` ou `« lundi 15 mai 2026 — 14:00 »` si pas d'heure de fin.

Importé dans `AccountPage.jsx` et `PanelPage.jsx`. Locale du navigateur utilisée silencieusement (timezone biblio stockée dans `consultation_timezone` mais non utilisée à l'affichage, à voir si besoin futur de l'expliciter).

---

## 4. Modèle de données — évolutions

### 4.1 Aucune évolution structurelle majeure

Les 3 tables existantes (`consultas_locais_v2`, `consulta_linhas_v2`, `consulta_item_workflow_v2`) couvrent l'ensemble des besoins fonctionnels avec un degré de richesse comparable aux réservations (event log + état métier). Le chantier n'a pas nécessité de nouvelle table.

### 4.2 Compteur `negotiation_iteration_count` — décision : NON retenu

Initialement envisagé en v2 pour brider la négociation de créneau (similaire au paquet 5c côté réservations). **Décision en cours d'implémentation** : non retenu en Phase 2 car les itérations de reproposition sont volontairement laissées libres pour les consultations sur place (volume très faible en pratique, pas de risque de boucle abusive).

Si besoin se manifeste, ajout futur possible :

```sql
ALTER TABLE public.consulta_item_workflow_v2
  ADD COLUMN IF NOT EXISTS negotiation_iteration_count int NOT NULL DEFAULT 0;
```

### 4.3 Colonne `pickup_proposed_by` — décision : NON retenu

Initialement envisagé en v2 pour tracer qui a proposé le créneau courant. **Décision en cours d'implémentation** : non retenu car la doctrine consultas n'autorise pas la contre-proposition par le lecteur (cf. §10.2). Le créneau est toujours proposé par la biblio, donc cette colonne serait toujours `'biblio'`. Aucun gain informationnel.

Le bouton « Confirmer / Refuser ce créneau » s'affiche côté lecteur dès que `workflow_stage = 'consulta_agendada'` ET `schedule_reply_status IS NULL`, sans condition supplémentaire.

---

## 5. Matrice des transitions

### 5.1 Cycle de vie d'une consultation (vue agrégée) *(actualisé v2.1)*

```
                  [création par lecteur]                [création par staff]
                  AccountPage                            PanelPage
                  api.create_consulta_local              api.create_consulta_local
                            \                                  /
                             \                                /
                              ▼                              ▼
                          ┌────────────────────────────────────┐
                          │  workflow_stage = 'solicitada'     │
                          │  item_status = 'ativa'             │
                          │  status_global = 'ativa'           │
                          │  → mail biblio                     │
                          └─────────────────┬──────────────────┘
                                            │
                                            │ staff prépare
                                            ▼
                          ┌────────────────────────────────────┐
                          │  workflow_stage = 'em_preparacao'  │
                          │  → mail lecteur "demande prise     │
                          │     en compte"                     │
                          └─────────────────┬──────────────────┘
                                            │
                                            │ staff propose créneau
                                            │ (modal Agendar :
                                            │  date + starts_at + ends_at
                                            │  obligatoires + note)
                                            ▼
                          ┌────────────────────────────────────┐
                          │  workflow_stage = 'consulta_agendada'│
                          │  schedule_reply_status = NULL       │
                          │  → mail lecteur avec créneau formaté│
                          └─────────┬──────────────────┬───────┘
                                    │                  │
                       lecteur confirme           lecteur refuse
                       (clic direct)              (modal avec motif obligatoire)
                       reply = 'confirmado_leitor' reply = 'recusado_leitor'
                       → mail biblio              → mail biblio
                                    │                  │
                                    │                  │ staff propose
                                    │                  │ "outro horário"
                                    │                  │ (clic bouton dédié,
                                    │                  │  modal pré-rempli demain 14:00→15:00)
                                    │                  ▼
                                    │           ┌─────────────────────┐
                                    │           │ workflow_stage =    │
                                    │           │ 'consulta_agendada' │
                                    │           │ schedule_reply_*    │
                                    │           │ remis à NULL        │
                                    │           │ → mail lecteur      │
                                    │           └──────────┬──────────┘
                                    │                      │
                                    │                      └─► nouveau cycle réponse lecteur
                                    │                          (itérations libres, pas de plafond v2.1)
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
        │  → mail lecteur        │    │  → mail lecteur        │
        └────────────────────────┘    └────────────────────────┘

Transitions latérales possibles à tous les stades non-terminaux :
  → cancelada_leitor (par lecteur via api.cancel_consulta_as_reader)
       avec modal de confirmation (paquet 27.A.2)
       → mail biblio
  → cancelada_biblioteca (par staff via api.advance_consulta)
       avec note obligatoire
       → mail lecteur, qui peut "fermer" la ligne via api.dismiss_consulta_cancelled
  → expirada (par system/cron sur expires_at)
       → mail lecteur
```

### 5.2 Matrice détaillée : qui peut faire quoi depuis quel stage

| from \ to | em_preparacao | consulta_agendada | consulta_realizada | nao_compareceu | cancelada_leitor | cancelada_biblioteca | expirada |
|---|---|---|---|---|---|---|---|
| `solicitada` | staff | — | — | — | **lecteur** | staff | system |
| `em_preparacao` | — | staff | — | — | **lecteur** | staff | system |
| `consulta_agendada` | — | staff* | staff** | staff*** | **lecteur** | staff | system |
| `consulta_realizada` | — | — | — | — | — | — | — |
| `nao_compareceu` | — | — | — | — | — | staff | — |
| `cancelada_leitor` | — | — | — | — | — | — | — |
| `cancelada_biblioteca` | — | — | — | — | — | — | — |
| `expirada` | — | — | — | — | — | — | — |

Légende :
- **staff** = `librarian` / `coordenador` (rôle `administrador` supprimé au paquet F admin réseau, cf. spec admin réseau v0.3.1)
- **lecteur** = propriétaire de la consultation uniquement (vérifié par ownership)
- **staff*** = **reproposition de créneau après refus du lecteur** : bouton « Propor outro horário » conditionné par `schedule_reply_status = 'recusado_leitor'` (paquet 27.A.6, R3 §11.2)
- **staff** = possibilité de reclasser un no-show en annulation biblio si erreur de pointage
- **staff** = peut marquer no-show **uniquement si** `consultation_starts_at < now()` ET `schedule_reply_status <> 'recusado_leitor'` (paquet 27.A.6, R4 §11.2)
- **system** = jobs cron (expiration sur `expires_at`)
- `—` = transition non autorisée

### 5.3 Règles de transitions par acteur

**Lecteur** :
- Peut **annuler** sa consultation (`cancelada_leitor`) depuis tout stage non-terminal — paquet 27.A.2
- Peut **répondre** à une proposition de créneau (`confirmado_leitor` / `recusado_leitor`) uniquement quand `workflow_stage = 'consulta_agendada'` ET `schedule_reply_status IS NULL` — paquet 27.A.5
  - Confirmer : clic direct
  - Refuser : modal avec **motif obligatoire** (paquet 27.A.5)
- Peut **fermer** (dismiss) une ligne annulée par la biblio (action UI sans changement d'état métier, juste un `dismissed_by_reader_at = now()`)
- Ne peut **pas** changer d'autres stages
- Ne peut **pas** contre-proposer un créneau (cf. §10.2 — doctrine v1 retenue)

**Staff (librarian / coordenador)** :
- Peut **avancer** une consultation depuis `solicitada` vers `em_preparacao`
- Peut **proposer un créneau** (`em_preparacao` → `consulta_agendada`) via le modal Agendar avec date + heure début + heure fin **toutes obligatoires** (paquet 27.A.4 + hotfix 5.D) + note workflow
- Peut **reproposer un créneau** (`consulta_agendada` → `consulta_agendada` si refus lecteur) via le bouton « Propor outro horário » (paquet 27.A.6)
- Peut **marquer réalisée** (`consulta_agendada` → `consulta_realizada`)
- Peut **marquer no-show** (`consulta_agendada` → `nao_compareceu`) conditionné par `starts_at < now()` ET reply `<> recusado` (paquet 27.A.6)
- Peut **annuler côté biblio** (`*` → `cancelada_biblioteca`) avec note obligatoire
- Ne peut **pas** "fermer" pour le lecteur (le dismiss est une action lecteur)

**System (jobs cron)** :
- Peut **expirer** une consultation non terminale dont `consulta_linhas_v2.expires_at < now()`
- Aucune autre transition

### 5.4 Validation du créneau de consultation

À chaque transition vers `consulta_agendada`, validation via `fn_validate_consulta_schedule_window` :

1. Le créneau (`consultation_starts_at` ET `consultation_ends_at`, depuis paquet 27) est dans les **horaires d'ouverture** de la biblio (`library_opening_hours`)
2. Le créneau n'est pas dans le **passé**
3. Le créneau ne **chevauche** pas une autre consultation `consulta_agendada` du même `holding_id` (pour les fonds limités à 1 exemplaire physique)
4. Le créneau est dans une **plage raisonnable** (par défaut : entre +1h et +60j)

Si une règle échoue, raise `schedule_window_invalid` avec le détail.

### 5.5 *(Nouveau v2.1)* Invariant `schedule_missing` : créneau complet obligatoire

**Doctrine R1 figée au hotfix 5.D (paquet 27.A.7)** :

Le wrapper `api.advance_consulta` exige que `p_consultation_starts_at` ET `p_consultation_ends_at` soient fournis **ensemble** pour toute transition vers `consulta_agendada`. La règle est implémentée côté backend (raise `schedule_missing` si l'un est NULL et l'autre non), et le frontend doit la respecter explicitement plutôt que de la masquer.

**Côté frontend (PanelPage modal Agendar)** :
- Pré-remplissage automatique : `startsAt = '14:00'`, `endsAt = '15:00'` (cohérent, modifiable)
- Validation : `!date || !startsAt || !endsAt` → erreur affichée `panel.consulta.schedule.errorRequired`
- Libellé du champ « Heure de fin » : sans mention « (optionnel) / (facultatif) » dans les 6 locales (paquet 27.A.7 a retiré ce libellé partout)

**Justification politique** : un créneau de consultation est défini par sa fenêtre (début + fin), pas par un point. Imposer la fenêtre complète :
1. Reflète la réalité de la pratique (le lecteur sait combien de temps réserver, la biblio sait combien de temps mobiliser l'espace)
2. Permet la vérification de chevauchement (§5.4 point 3) qui exige une fenêtre, pas un point
3. Évite les bugs runtime silencieux (l'erreur backend `schedule_missing` éclatait au moment du submit, mauvaise UX)

---

## 6. RPC publiques — contrats

### 6.1 Création — `api.create_consulta_local` ✅ Livré paquet 25

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
    IF v_actor_role NOT IN ('librarian', 'coordenador') THEN  -- v2.1 : 'administrador' retiré
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

**Note v2.1** : `'administrador'` retiré du CHECK des rôles autorisés (cohérent avec paquet F admin réseau qui a supprimé ce rôle local). Les admins réseau passent par `fn_resolve_caller_role_for_library` qui retourne `'network_admin'` virtuel, à inclure dans la liste si décision politique de les autoriser à créer des consultations transverses (à trancher).

### 6.2 Avancer le workflow par le staff — `api.advance_consulta` ✅ Livré paquet 25

Wrapper unifié pour les transitions staff `solicitada → em_preparacao`, `em_preparacao → consulta_agendada`, `consulta_agendada → consulta_realizada` / `nao_compareceu` / `cancelada_biblioteca`.

```sql
CREATE OR REPLACE FUNCTION api.advance_consulta(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_target_stage text,
  p_workflow_note text DEFAULT NULL,
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

  -- v2.1 : invariant schedule_missing — starts_at et ends_at obligatoires ENSEMBLE
  IF p_target_stage = 'consulta_agendada' THEN
    IF p_consultation_starts_at IS NULL OR p_consultation_ends_at IS NULL THEN
      RAISE EXCEPTION 'schedule_missing: p_consultation_ends_at obrigatorio com p_consultation_starts_at'
        USING ERRCODE = 'P0001';
    END IF;
    
    v_updated := public.fn_v2_set_consulta_linhas_workflow_slot(
      p_consulta_id, p_line_nos, p_target_stage, p_workflow_note,
      to_char(p_consultation_starts_at, 'YYYY-MM-DD'),
      to_char(p_consultation_starts_at, 'HH24:MI'),
      to_char(p_consultation_ends_at, 'HH24:MI'),
      p_consultation_timezone
    );
  ELSE
    v_updated := public.fn_v2_set_consulta_linhas_workflow(
      p_consulta_id, p_line_nos, p_target_stage, p_workflow_note, NULL
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'updated_count', v_updated);
END;
$$;
```

**Note v2.1** :
- Le paramètre `p_consultation_scheduled_for` (legacy, créneau ponctuel) a été retiré de la signature publique. Seul le modèle fenêtre `[starts_at, ends_at]` est exposé.
- L'invariant `schedule_missing` est **explicite** en début de bloc `consulta_agendada` (raise dédié), pas seulement émis par `fn_v2_set_consulta_linhas_workflow_slot` (qui peut lever d'autres erreurs liées à la fenêtre temporelle).

### 6.3 Réponse du lecteur à un créneau — `api.reply_consulta_schedule` ✅ Livré paquet 25

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

**Note v2.1** : côté UX, le motif (`p_note`) est **obligatoire** pour `recusado_leitor` (forcé dans le modal AccountPage). Côté backend, c'est une recommandation pas une contrainte (NULL accepté).

### 6.4 Annulation par le lecteur — `api.cancel_consulta_as_reader` ✅ Livré paquet 25

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

### 6.5 Fermeture (dismiss) par le lecteur — `api.dismiss_consulta_cancelled` ✅ Livré paquet 25

Action UI : le lecteur "ferme" la ligne d'une consultation annulée par la biblio (set `dismissed_by_reader_at`). Pas de changement d'état métier.

Wrapper analogue avec ownership check.

### 6.6 Pas de wrapper pour `fn_validate_consulta_schedule_window`

Cette fonction reste un helper interne appelé depuis `fn_v2_set_consulta_linhas_workflow*`. Pas d'exposition publique.

### 6.7 Helpers créés ✅ Livré paquet 24

**`fn_check_consulta_transition(p_from text, p_to text, p_actor_role text) RETURNS boolean`** :

Implémente la matrice §5.2. IMMUTABLE. Fail-closed sur arguments inconnus. Utilisé par `api.advance_consulta` et par les tests d'acceptation.

**`fn_get_consulta_context(p_consulta_id bigint) RETURNS TABLE(library_id uuid, leitor_user_id uuid, status_global text)`** :

Analogue à `fn_get_loan_context`. STABLE. Permet aux wrappers de résoudre rapidement le contexte avant la vérification de rôle.

---

## 7. Triggers et notifications ✅ Livré paquet 26

### 7.1 Audit initial

L'audit Phase 0 a confirmé : **aucun trigger** sur les 3 tables consultations, **aucune clé i18n** mail.consulta.*, **aucun handler** `consultations.ts`. Tout a été créé from scratch au paquet 26.

### 7.2 Triggers créés au paquet 26

**`trg_notify_consulta_lifecycle`** sur `consulta_linhas_v2` (item_status DISTINCT FROM) :
- INSERT → `consulta_v2_criada`
- UPDATE item_status `ativa → consultada` → `consulta_v2_realizada`
- UPDATE item_status `ativa → cancelada_*` → `consulta_v2_cancelada` (avec discriminant lecteur/biblio)
- UPDATE item_status `ativa → expirada` → `consulta_v2_expirada`

**`trg_notify_consulta_workflow`** sur `consulta_item_workflow_v2` (workflow_stage transition) :
- workflow_stage transition vers `em_preparacao` → `consulta_v2_em_preparacao` (mail lecteur "demande prise en compte")
- workflow_stage transition vers `consulta_agendada` → `consulta_v2_agendada` (mail lecteur avec créneau formaté)
- schedule_reply_status DISTINCT FROM (nouveau) → `consulta_v2_resposta_creneau` (mail à la biblio)

#### 7.2bis *(Nouveau v2.2)* Doctrine d'ordre des UPDATEs dans les RPC

**Internalisée pendant le chantier #141 (16/05/2026)**, cf. §11.2 R7 pour la formulation normative.

Quand une RPC modifie **plusieurs tables liées par des triggers AFTER UPDATE** — typiquement `consulta_item_workflow_v2` (porte la note narrative `workflow_note` ou `schedule_reply_note`) **et** `consulta_linhas_v2` (porte l'état `item_status` qui fire les notifications) — il faut **TOUJOURS** UPDATE la source de vérité narrative **AVANT** la source d'état.

**Pourquoi** : le trigger lifecycle qui fire sur le changement d'`item_status` lit la note pour construire le payload du mail. Si on UPDATE l'état avant la note, le trigger voit l'ancienne note (NULL ou la note précédente) et le mail est mal renseigné.

**Exemple `cancel_consulta_as_reader`** (v2.1) :
```sql
-- ❌ MAUVAIS ORDRE — bug observé pré-#141 :
UPDATE consulta_linhas_v2 SET item_status = 'cancelada_leitor' WHERE id = ...;
-- ⬆ trigger fire ici, lit workflow_note NULL → mail sans motif
UPDATE consulta_item_workflow_v2 SET workflow_note = p_motivo WHERE consulta_linha_id = ...;

-- ✅ BON ORDRE — appliqué post-#141 :
INSERT INTO consulta_item_workflow_v2 (..., workflow_note) VALUES (..., p_motivo);
-- (ou UPDATE avec workflow_note en premier)
UPDATE consulta_linhas_v2 SET item_status = 'cancelada_leitor' WHERE id = ...;
-- ⬆ trigger fire ici, lit workflow_note correct → mail avec motif
```

Cette doctrine s'applique à **toutes** les RPC métier qui touchent à la fois aux tables narratives et aux tables d'état dans une même transaction. Audit recommandé sur `cancel_consulta_as_reader`, `cancelar_consulta_biblioteca`, et toute nouvelle RPC similaire.

### 7.3 Handler Edge Function `notify-event` ✅ Livré paquet 26 L4

Handler `handlers/consultas.ts` créé sur le modèle de `handlers/reservas.ts`. Pattern : `fetchConsulta` + `fetchConsultaProfile`, `renderEmail(layout)`, `safeSendEmail`. **Principe SIGB** : on notifie celui qui n'a **pas** initié l'action :
- Lecteur crée → biblio notifiée
- Biblio prépare → lecteur notifié
- Biblio agende → lecteur notifié (avec créneau formaté en utilisant `consultation_starts_at` + `consultation_ends_at` + `consultation_timezone`)
- Lecteur confirme/refuse → biblio notifiée
- Biblio marque réalisé / no-show / annule → lecteur notifié
- Lecteur annule → biblio notifiée
- Cron expirer → lecteur notifié

#### 7.3bis *(Nouveau v2.2)* Doctrine R8 traçabilité coordination — extension actions staff

**Internalisée pendant le chantier #142 (17/05/2026)**, cf. §11.2 R9 pour la formulation normative.

Toute action initiée par le **staff biblio** sur un item lecteur génère un mail à `library_commons.coordination_email` **en plus** du mail au lecteur. C'est la **doctrine R8 traçabilité coordination**, héritée de la spec admin réseau v0.4.

**Couvre actuellement** :
- `cancelada_biblioteca` — annulation par la biblio → mail lecteur + mail coordination
- `nao_compareceu` — marquage no-show par la biblio → mail lecteur + mail coordination

**À étendre (TODO)** : extensions, renouvellements, retours, toute action staff sur un emprunt ou une réservation. Sera traité dans une version dédiée des specs concernées.

**Pattern technique** : le handler `handlers/consultas.ts` détecte le contexte staff via `actor_kind = 'staff'` (déterminé par le RPC d'origine), enrichit le payload avec `coordination_mail_enabled = true`, et l'EF `notify-event` envoie deux mails — un au lecteur (ton relationnel) et un à `coordination_email` (ton technique, traçabilité interne staff).

**Doctrine politique** : R8 reflète la prémisse anarchiste de **transparence interne** au sein de l'équipe staff. Si un·e librarian agit unilatéralement sur le compte d'un·e lecteur·rice (annulation, no-show), les autres membres staff peuvent en prendre connaissance via le mail de coordination, sans dépendre d'une trace orale ou d'un journal séparé.

### 7.4 Clés i18n mails ✅ Livré paquet 26 L3

Clés ajoutées dans `_shared/i18n/mail-strings.ts` × 6 locales :

```
mail.consulta.criada.subject / body
mail.consulta.em_preparacao.subject / body
mail.consulta.agendada.subject / body  (avec date+heure+timezone)
mail.consulta.resposta_creneau.subject / body  (à la biblio)
mail.consulta.realizada.subject / body
mail.consulta.nao_compareceu.subject / body
mail.consulta.cancelada.subject / body  (avec discriminant lecteur/biblio)
mail.consulta.expirada.subject / body
```

Total : ~60 nouvelles clés × 6 locales = 360 traductions.

### 7.5 Toggles ✅ Livré paquet 26 L1

Ajoutés à `library_notification_policies` :

```sql
ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS consulta_lifecycle_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS consulta_reminders_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS admin_copy_consultas_enabled boolean NOT NULL DEFAULT true;
```

Lus par les triggers avant émission.

---

## 8. Surfaces UI

### 8.1 AccountPage.jsx — onglet "Consultations sur place" ✅ Livré paquets 27.A.1, 27.A.2, 27.A.5

**Migrations frontend appliquées** :

| Appel d'origine | Appel cible (livré) | Paquet |
|---|---|---|
| `supabase.rpc('fn_v2_create_consulta_local_by_holdings', ...)` | `supabase.schema('api').rpc('create_consulta_local', ...)` | 27.A.1 |
| `supabase.rpc('fn_v2_cancel_consulta_linhas_as_leitor', ...)` | `supabase.schema('api').rpc('cancel_consulta_as_reader', ...)` | 27.A.2 |
| `supabase.rpc('fn_v2_dismiss_consulta_cancelled_as_leitor', ...)` | `supabase.schema('api').rpc('dismiss_consulta_cancelled', ...)` | 27.A.5 (bloc Annulée biblio) |
| (nouveau) | `supabase.schema('api').rpc('reply_consulta_schedule', ...)` | 27.A.5 |

**UI livrées** :

- **Bouton « Cancelar »** sur consultas ativas dans onglet « Reservas e consultas » + modal de confirmation avec note libre. Appelle `api.cancel_consulta_as_reader`. Paquet 27.A.2.

- **Bloc « Horário proposto pela biblioteca »** : en haut du tab Reservas, bordure bleue (`#2563eb`). Affichage du créneau formaté via `formatSchedule(c)` + note workflow staff + 2 boutons : **Confirmar** (clic direct, appelle `api.reply_consulta_schedule('confirmado_leitor')`) et **Recusar este horário** (modal avec note obligatoire, appelle `api.reply_consulta_schedule('recusado_leitor')`). Paquet 27.A.5.

- **Pastille verte ✓ « Confirmado para {date} »** dans le bloc ativas après confirmation. Paquet 27.A.5.

- **Bloc « Annulée par biblio »** : quand `item_status = 'cancelada_biblioteca'` ET `dismissed_by_reader_at IS NULL`, affichage de la note de la biblio + bouton « Fermer » (appelle `api.dismiss_consulta_cancelled`). Implémenté dans la même série de paquets.

**Clés i18n** : ~80 clés × 6 locales pour le bouton Annuler, le bloc créneau et les pastilles.

### 8.2 PanelPage.jsx — onglet « Consultas » ✅ Livré paquets 27.A.3, 27.A.4, 27.A.6, 27.A.7

L'onglet `consultas-locais` de `PanelPage.jsx` était déjà branché en amont (24 occurrences `consulta`). Le travail a consisté à enrichir l'existant.

**Migrations frontend appliquées** :

- **Migration du helper `setConsultaWorkflow`** : passe de `fn_v2_set_consulta_linhas_workflow` à `api.advance_consulta` (paquet 27.A.3 / 5.A). Signature externe inchangée pour les 4 boutons existants, ajout d'un 5e paramètre `scheduleParams = { startsAt, endsAt, timezone }` optionnel.

- **Modal Agendar** : remplace l'appel direct sans date du bouton « Agender » (bug latent L1520) par un modal date + heure début + heure fin + note 300 chars (paquet 27.A.4 / 5.B). Pré-remplissage `startsAt='14:00'`, `endsAt='15:00'` (paquet 27.A.7 / 5.D). Timezone navigateur silencieuse via `Intl.DateTimeFormat().resolvedOptions().timeZone`. Validation date + startsAt + endsAt obligatoires (R1 §11.2).

- **Colonne « Planification » refactorée** (paquet 27.A.6 / 5.C) :
  - Créneau formaté via `formatSchedule(c)` (helper partagé, cf. §3.4)
  - Pastilles statut selon `schedule_reply_status` :
    - `confirmado_leitor` → ✓ vert
    - `recusado_leitor` → ✗ orange + motif italique
    - NULL en stage agendada → ⏳ gris
  - Fallback `fmtD(consultation_scheduled_for)` si pas de créneau détaillé (héritage legacy)

- **Nouveaux boutons dans la colonne Actions** (paquet 27.A.6) :
  - **Propor outro horário** : visible si `stage='consulta_agendada'` ET `schedule_reply_status='recusado_leitor'`. Rouvre le modal Agendar pré-rempli demain 14:00→15:00.
  - **Marcar não comparecimento** : visible si `stage='consulta_agendada'` ET `consultation_starts_at < now()` ET `schedule_reply_status <> 'recusado_leitor'`. `window.confirm` puis `api.advance_consulta(stage='nao_compareceu', workflow_note=t('panel.consulta.noShowReason'))`.
  - **Marcar como realizada** : conserve l'ancien bouton, masqué si `reply='recusado_leitor'`.
  - **Anular** : conserve l'ancien bouton avec note obligatoire.

- **Création de consultation par staff pour un lecteur** : appel `api.create_consulta_local` avec `p_user_id` choisi (hors paquet 27, à implémenter si besoin futur — la fonctionnalité n'a pas été remontée comme prioritaire).

**Clés i18n** : ~144 clés × 6 locales pour le modal Agendar (24 clés × 6), ~12 clés × 6 pour les pastilles et nouveaux boutons.

### 8.3 Catalogue (livro.html)

Si un holding est `consultable_only = true`, afficher un bouton « Demander une consultation » au lieu de « Réserver l'emprunt ». L'action redirige vers `/conta` avec préfill du bib_ref. *(Statut : non modifié pendant le chantier, fonctionnalité existante préservée.)*

---

## 9. Phases d'implémentation

> Toutes les phases sont closes. Section conservée pour traçabilité historique. Voir §10 pour la chronologie effective.

### Phase 0 — Audit ✅ Livré 11/05/2026

Audit conduit, écarts documentés. Cf. §2.4-§2.8.

### Phase 1 — Helpers + matrice de transitions + invariant emprunt/consulta ✅ Livré paquet 24 (12/05/2026)

Migrations livrées :
- `consulta_helpers.sql` : `fn_check_consulta_transition`, `fn_get_consulta_context`
- `invariant_emprestimo_vs_consulta.sql` : patch de `fn_v2_create_emprestimo_by_holdings` pour vérifier l'absence de `consulta_linhas_v2.item_status = 'ativa'`, et inversement étendre `fn_v2_create_consulta_local_by_holdings`

Tests SQL d'acceptation livrés.

### Phase 2 — Wrappers `api.*` ✅ Livré paquet 25 (12/05/2026)

Migration `consulta_workflow_wrappers.sql` :
- `api.create_consulta_local`
- `api.advance_consulta`
- `api.reply_consulta_schedule`
- `api.cancel_consulta_as_reader`
- `api.dismiss_consulta_cancelled`

Tests SQL d'acceptation livrés.

### Phase 3 — Notifications ✅ Livré paquet 26 (13/05/2026)

5 sous-paquets livrés (L1 à L5) :
- L1 : toggles `library_notification_policies` (3 colonnes)
- L2 : triggers `trg_notify_consulta_lifecycle` + `trg_notify_consulta_workflow`
- L3 : ~60 clés i18n mail × 6 locales = 360 traductions
- L4 : handler `notify-event/handlers/consultas.ts`
- L5 : ajustements UI et libellés de stages

**Note** : incident recovery 14/05 matin (5 fichiers écrasés par auto-revert IDE, 5h de récupération) — n'a pas affecté le contenu livré, juste le timing.

### Phase 4 — Frontend lecteur ✅ Livré paquets 27.A.1, 27.A.2, 27.A.5 (14/05/2026)

- 27.A.1 : migration `api.create_consulta_local`
- 27.A.2 : bouton Annuler + modal confirmation (18 clés i18n)
- 27.A.5 : bloc « Horário proposto pela biblioteca » + boutons Confirmar/Recusar + pastille verte ✓ confirmé (66 clés i18n)

### Phase 5 — Frontend bibliothécaire ✅ Livré paquets 27.A.3, 27.A.4, 27.A.6, 27.A.7 (14/05/2026)

- 27.A.3 (5.A) : migration `setConsultaWorkflow` vers `api.advance_consulta`
- 27.A.4 (5.B) : modal Agendar date+heures début/fin+note (144 clés i18n)
- 27.A.6 (5.C) : pastilles statut + reproposition + bouton no-show + refactor DRY `scheduleFormat.js` (12 clés i18n)
- 27.A.7 (5.D) : hotfix `schedule_missing`, endsAt obligatoire, libellés "(opcional)" retirés

### Phase 6 — Tests runtime ⏸️ Reportée — décision de QA manuelle

**Décision en cours d'implémentation (14/05/2026 soir)** : Phase 6 reportée au profit d'une **QA manuelle structurée**.

**Justification** : pas de framework E2E (Playwright) installé. L'installation et la mise en place de scénarios robustes (helpers `loginAs`, fixtures DB cleanup, pipeline CI headless) sont estimées à 6-8h sur 2-3 sessions. Pour un projet 1 dev avec base utilisateur réduite, l'investissement E2E est disproportionné à ce stade.

**Alternative retenue** : checklist de 9 scénarios à dérouler manuellement en prod après chaque livraison majeure :

1. Lecteur crée consultation → mail biblio reçu
2. Biblio passe `solicitada → em_preparacao` → mail lecteur reçu
3. Biblio propose créneau (date + starts + ends + note) → mail lecteur avec créneau formaté
4. Lecteur confirme créneau → mail biblio
5. Jour J : biblio marque `consulta_realizada` → mail lecteur de confirmation
6. **Scénario refus** : lecteur refuse créneau (modal motif obligatoire) → biblio reçoit mail → biblio re-propose via « Propor outro horário » → cycle reprend
7. **Scénario no-show** : créneau passé, biblio marque `nao_compareceu` via bouton conditionné (visible si `starts_at < now()`)
8. **Scénario annulation lecteur** depuis stages variés (solicitada, agendada)
9. **Scénario annulation biblio** avec note → lecteur dismiss → ligne disparaît de l'UI

**Reprise possible plus tard** : si la base utilisateur grandit (5+ biblios actives, 50+ consultations/mois), formaliser E2E Playwright dans un chantier dédié (~1 semaine).

### Phase 7 — Commit et déploiement ✅ Livré au fil de l'eau

Commits par phase, push Codeberg via Woodpecker CI. Tous les paquets sont en prod stable.

---

## 10. Chronologie effective du chantier

| Date | Paquet | Phase | Livraisons clés |
|---|---|---|---|
| 11/05/2026 | Spec v2 + audit | 0 | Spec rédigée, audit terminé |
| 12/05/2026 | 24 | 1 | Helpers `fn_check_consulta_transition` + `fn_get_consulta_context` + invariant emprunt/consulta |
| 12/05/2026 | 25 | 2 | 5 wrappers `api.*` SECURITY INVOKER + ~30 tests SQL |
| 13/05/2026 | 26 (L1-L5) | 3 | Triggers + handler `consultas.ts` + 60 clés i18n mails × 6 locales + toggles |
| 14/05/2026 matin | Recovery | — | 5 fichiers écrasés par IDE, 5h de récupération sur mail-strings.ts + events.ts + library-notification-context.ts + policies.ts + dispatch.ts |
| 14/05/2026 soir | 27.A.1 | 4 | Migration `api.create_consulta_local` côté AccountPage |
| 14/05/2026 soir | 27.A.2 | 4 | Bouton Annuler côté lecteur + modal confirmation (18 clés × 6) |
| 14/05/2026 soir | 27.A.3 (5.A) | 5 | Migration `setConsultaWorkflow` vers `api.advance_consulta` |
| 14/05/2026 soir | 27.A.4 (5.B) | 5 | Modal Agendar biblio (144 clés × 6) |
| 14/05/2026 soir | 27.A.5 (4.3+4.4) | 4 | Bloc « Horário proposto pela biblioteca » + Confirmar/Recusar (66 clés × 6) |
| 14/05/2026 soir | 27.A.6 (5.C) | 5 | Pastilles statut + reproposition + bouton no-show + refactor DRY `scheduleFormat.js` (12 clés × 6) |
| 14/05/2026 soir | 27.A.7 (5.D) | 5 | Hotfix `schedule_missing` : endsAt obligatoire + libellés "(opcional)" retirés |
| 15/05/2026 | Spec v2.1 | — | Consignation des raffinements doctrinaux post-implémentation |

**Bilan** : chantier entièrement livré en 4 jours calendaires (11/05 → 14/05) au lieu des 5 jours prévus en v2 — la Phase 6 ayant été remplacée par une décision de QA manuelle.

---

## 11. Points ouverts et raffinements doctrinaux

### 11.1 Points ouverts conservés

**Compteur de négociation** : non retenu (cf. §4.2). Les itérations de reproposition restent libres. Si abus observé en prod, ajouter `negotiation_iteration_count` dans un paquet ultérieur.

**Contre-proposition par le lecteur** : non retenu pour v1 (cf. §10.2). Le lecteur refuse et commente, la biblio repropose. Si besoin se manifeste, ajouter dans un chantier dédié.

**Rappels de créneau (J-1, jour J)** : hors périmètre de cette spec. Mécanique livrée au paquet 26 (toggle `consulta_reminders_enabled`) mais cron dormant. À activer dans un paquet ultérieur si besoin.

**Multi-items dans une même consultation** : la table `consulta_linhas_v2` supporte plusieurs items, le workflow aussi. UI lecteur actuelle traite une consultation comme une seule ligne. Multi-items réservé au staff (création depuis PanelPage), implémentation à venir si besoin.

**Annulation par erreur côté staff** : aucun chemin actuel pour "rouvrir" une consultation annulée. Acceptable si l'erreur est rare ; à formaliser via `api.reopen_consulta` (network_admin uniquement) si besoin.

### 11.2 *(Nouveau v2.1)* Raffinements doctrinaux figés en cours d'implémentation

**R1 — Invariant `schedule_missing` : créneau complet obligatoire** (cf. §5.5, §6.2)

Le wrapper `api.advance_consulta` exige `p_consultation_starts_at` ET `p_consultation_ends_at` ensemble pour toute transition vers `consulta_agendada`. Raise `schedule_missing` si l'un est NULL et l'autre non. Frontend respecte la règle (validation + pré-remplissage), ne la masque pas.

**R2 — Helper partagé `scheduleFormat.js`** (cf. §3.4)

Factorisation entre AccountPage et PanelPage d'une fonction de formatage de créneau. Importé dans les deux fichiers. Format `« lundi 15 mai 2026 — 14:00–15:30 »` avec em-dash et en-dash unicode. Locale du navigateur via `toLocaleDateString(undefined, ...)`.

**R3 — Workflow de reproposition après refus** (cf. §5.1, §5.2)

Quand `schedule_reply_status='recusado_leitor'`, la biblio peut reproposer un créneau via le bouton dédié « Propor outro horário ». Le clic rouvre le modal Agendar pré-rempli (demain 14:00→15:00), le submit appelle `api.advance_consulta(stage='consulta_agendada', ...)` qui **reset** `schedule_reply_status` à NULL. Cycle libre, pas de plafond d'itération en v2.1.

**R4 — Bouton no-show conditionné temporel** (cf. §5.3)

Le bouton « Marcar não comparecimento » côté biblio est conditionné par 3 critères simultanés :
- `workflow_stage = 'consulta_agendada'`
- `consultation_starts_at < now()` (le créneau est passé)
- `schedule_reply_status <> 'recusado_leitor'` (cohérence : ne pas pouvoir marquer no-show une consultation refusée par le lecteur)

Si critères réunis, le clic déclenche `window.confirm` puis `api.advance_consulta(stage='nao_compareceu', workflow_note=t('panel.consulta.noShowReason'))`.

**R5 — Principe SIGB de notification** (cf. §7.3)

Validé et confirmé pendant les tests fonctionnels du paquet 27 : **on notifie celui qui n'a pas initié l'action**, pas celui qui agit. Cohérent avec la doctrine admin réseau v0.3.1 §4.2.4. Le lecteur qui confirme un créneau ne reçoit pas de mail de confirmation à lui-même.

**R6 — Phase 6 E2E reportée au profit d'une QA manuelle** (cf. §9 Phase 6)

Décision pragmatique pour un projet 1 dev avec base utilisateur réduite. Checklist de 9 scénarios à dérouler manuellement après chaque livraison majeure. Reprise possible plus tard si la base utilisateur grandit.

### 11.3 *(Nouveau v2.2)* Doctrines techniques internalisées au chantier hardening #141 (16-17/05/2026)

Le chantier #141 « hardening notifications consultas » du 16/05/2026 a résolu 7 bugs en production sur la chaîne de notifications consultas (mojibakes, mauvais routage `em_preparacao`/`nao_compareceu`, motif refus non propagé, motif annulation biblio absent, endsAt incorrect, title non interpolé). Les fixes ont fait émerger 5 doctrines techniques qui s'inscrivent normativement dans cette spec v2.2.

**R7 — Ordre UPDATE narrative-avant-état (doctrine #141.2.E)** (cf. §7.2bis encadré pédagogique)

Dans toute RPC métier modifiant **plusieurs tables liées par triggers AFTER UPDATE**, UPDATE la source de vérité narrative (`consulta_item_workflow_v2.workflow_note` ou `schedule_reply_note`) **AVANT** la source d'état (`consulta_linhas_v2.item_status` qui fire les notifications). Sinon le trigger lifecycle voit l'ancienne note et le mail est mal renseigné.

**Pattern à appliquer** :
- Pour les RPC d'**annulation** lecteur ou biblio : INSERT/UPDATE `workflow_v2` (avec motif) AVANT UPDATE `linhas_v2` (avec `item_status`)
- Pour les RPC de **réponse au créneau** (lecteur accepte/refuse) : UPDATE `schedule_reply_note` AVANT UPDATE `schedule_reply_status`
- Pour les RPC de **transition de stage** sans note narrative : ordre libre, mais conserver le pattern pour cohérence d'audit

**Audit recommandé** : passer en revue toutes les RPC qui touchent `consulta_item_workflow_v2` ET `consulta_linhas_v2` dans la même transaction. Bug #141.2.E observé sur `cancelar_consulta_biblioteca` (motif absent dans mail) résolu en inversant l'ordre.

**R8 — Distinction `workflow_note` (staff) vs `schedule_reply_note` (lecteur) (doctrine #141.2.C)**

Deux colonnes **distinctes** dans `consulta_item_workflow_v2` :
- `workflow_note` : note narrative côté staff (motif annulation biblio, instruction préparation, etc.)
- `schedule_reply_note` : note narrative côté lecteur (motif refus créneau, etc.)

**Conséquences** :
- Les triggers doivent propager **les 2 colonnes distinctement** dans les payloads — un seul champ `motif` agglomérant les deux est un anti-pattern.
- Les handlers doivent lire **les 2 colonnes** et les exposer dans des champs i18n distincts (`{workflowNote}` vs `{scheduleReplyNote}`).
- Les RPC qui modifient l'une **NE doivent PAS** écraser l'autre (utiliser des UPDATE sélectifs).

**Bug observé pré-#141** : `cancel_consulta_as_reader` mettait à jour `workflow_note` au lieu de `schedule_reply_note`, donc le mail biblio voyait du contenu staff mélangé avec du contenu lecteur. Résolu.

**R9 — Traçabilité coordination R8 généralisée (doctrine #142, 17/05/2026)** (cf. §7.3bis encadré pédagogique)

Toute action initiée par le **staff biblio** sur un item lecteur génère un mail à `library_commons.coordination_email` **en plus** du mail au lecteur. Couverture actuelle :
- `cancelada_biblioteca` (depuis #142, application du pattern existant)
- `nao_compareceu` (depuis #141.2.G)

**À étendre** (TODO post-v2.2) : extensions, renouvellements, retours sur emprunts (à inscrire dans `spec-flux-emprunts.md`).

**Doctrine politique** : transparence interne staff sans dépendance à un journal séparé. Inscrite normativement dans `spec-administrateur-reseau.md v0.4 §Préambule politique` comme principe transverse.

**Pattern technique de propagation** :
1. RPC métier signale `actor_kind = 'staff'` dans le payload trigger
2. Trigger ajoute `coordination_mail_enabled = true` au payload event si toggle activé
3. Handler `handlers/consultas.ts` détecte le flag et envoie deux mails : un au lecteur (ton relationnel) et un à `library_commons.coordination_email` (ton technique)

**R10 — Cohérence handler vs trigger : signature payload stable**

Le handler `handlers/consultas.ts` lit le payload **exactement** dans la forme produite par le trigger. Toute évolution de payload doit être faite **simultanément** trigger + handler, dans la même migration / le même PR.

**Bug observé pré-#141** : un payload trigger contenait `schedule_reply_note` côté DB mais le handler lisait `motif` côté TS, le motif refus n'était jamais propagé dans le mail. Résolu en alignant.

**Audit recommandé** : tableau de correspondance entre `_shared/i18n/mail-strings.ts` (clés ICU), handlers (clés TS), triggers (clés payload SQL). À tenir à jour.

**R11 — Doctrine UTF-8 PowerShell sur scripts d'i18n**

**Internalisée pendant le chantier #141.3** : sur Windows FR PowerShell, deux pièges symétriques sur les fichiers UTF-8 :
- **Écriture** : `Get-Content -Raw` lit en CP1252 et corrompt UTF-8 avec Unicode (accents, em-dash, etc.). Réécriture ensuite = double-encodage, fichier mojibake intégral.
- **Lecture/affichage** : `Get-Content` peut **afficher** des mojibakes (`â€"`, `Â·`) à la console alors que le fichier est en réalité UTF-8 valide. Toujours vérifier avec `[System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))` ou Node `.cjs` avant de conclure à un bug.

**Conséquence pour cette spec** : tous les scripts d'édition de `mail-strings.ts` (et plus généralement de fichiers i18n) doivent passer par Node `.cjs` ou par la méthode UTF-8 explicite PowerShell. Toute mojibake détectée à la console **doit être vérifiée** avant intervention (incident #145 du 17/05 = faux positif après vérification).

Cette doctrine n'est pas spécifique aux consultations mais elle a émergé pendant le chantier #141 lors du fix mojibake R11. Elle s'applique à **tous** les fichiers i18n du projet.

---

## 12. Risques et invariants

### 12.1 Invariants préservés

1. **`item_status` toujours dérivé**. Aucun UPDATE direct sur `consulta_linhas_v2.item_status` hors des fns DEFINER. Le wrapper `api.*` ne fait que valider et déléguer.
2. **Workflow log immuable** (par convention) : `consulta_item_workflow_v2` enregistre l'historique des transitions. Le UPDATE existant ne réécrit que la ligne courante (clé `(consulta_id, line_no)`).
3. **Ownership lecteur strict** : toute action lecteur vérifie `auth.uid() = consultas_locais_v2.user_id` dans le wrapper `api.*` (et pas seulement dans la fn DEFINER, pour éviter de réintroduire le bug du paquet 20 v2).
4. **`status_global` toujours dérivé** : aucun UPDATE direct, recalcul via `fn_v2_refresh_consulta_status_global`.
5. **Créneau toujours validé** : avant tout passage à `consulta_agendada`, `fn_validate_consulta_schedule_window` est appelée.
6. **Invariant emprunt-vs-consulta croisé** : `fn_v2_create_emprestimo_by_holdings` vérifie l'absence de consulta active, `fn_v2_create_consulta_local_by_holdings` vérifie l'absence d'emprunt actif ET de réservation active. Garanti depuis paquet 24.
7. ***(Nouveau v2.1)* Invariant `schedule_missing`** : `api.advance_consulta` rejette toute transition vers `consulta_agendada` sans la paire complète `(starts_at, ends_at)`.

### 12.2 Risques évalués post-implémentation

- **Risque #1 (wrapper `api.advance_consulta` conditionnel)** : initialement signalé en v2 comme surface de bug potentielle. **Évaluation v2.1** : aucun bug remonté en prod, tests SQL exhaustifs ont tenu, le hotfix 5.D `schedule_missing` était une amélioration UX et non un bug de logique.

- **Risque #2 (Phase 3 longue si rien n'existe)** : confirmé en Phase 0, Phase 3 a effectivement été un gros morceau (5 sous-paquets L1-L5), mais sans dépassement majeur. Incident recovery 14/05 matin (fichiers écrasés par IDE) est une cause externe, pas un risque doctrinal.

- **Risque #3 (incohérence `item_status` ↔ `workflow_stage`)** : aucun cas observé en prod. La logique implicite (CASE WHEN) de `fn_v2_set_consulta_linhas_workflow` tient. À documenter clairement si refacto future.

- **Risque #4 (bug analogue au paquet 20 v2)** : aucun cas observé. Le wrapper `api.create_consulta_local` teste explicitement le rôle de l'appelant et délègue à `fn_resolve_caller_role_for_library`.

- ***(Nouveau v2.1)* Risque #5 (changement `consultation_scheduled_for` → `consultation_starts_at`)** : la transition du modèle « créneau ponctuel » au modèle « fenêtre [start, end] » a été gérée par fallback dans `formatSchedule` (le helper accepte les deux). Aucune migration de données nécessaire (les anciennes lignes en `consultation_scheduled_for` continuent à s'afficher correctement). À monitorer si des consultations très anciennes (avant paquet 27) remontent dans des rapports.

---

## 13. Cohérence avec les autres specs

| Spec | Version | Lien |
|---|---|---|
| spec-flux-emprunts.md | (à mettre à jour) | Chaîne sœur. Interaction directe via la règle « un même holding ne peut pas avoir simultanément un emprunt actif ET une consultation active » (garantie par invariant croisé depuis paquet 24, cf. §12.1 invariant #6). **TODO v2.2** : propager la doctrine R8 traçabilité coordination aux emprunts (extensions, renouvellements, retours) et la doctrine R7 ordre UPDATE aux RPC d'emprunts symétriques. |
| spec-workflow-reservation.md | v3 (semantique) | Modèle de négociation de créneau (matrice from→to, schedule_reply) que cette spec reproduit pour les consultations. Différence v2.1 : pas de compteur de négociation côté consultas (cf. §4.2), itérations libres. **TODO v2.2** : audit pour appliquer doctrines R7-R11 aux RPC réservations si pertinent. |
| **spec-administrateur-reseau.md v0.4** *(20/05/2026)* | v0.4 | `librarian` / `coordenador` mobilisés dans les vérifications de rôle via `fn_resolve_caller_role_for_library`. Rôle `administrador` local supprimé au paquet F admin réseau (13/05/2026) : la liste autorisée dans `api.create_consulta_local` est `('librarian', 'coordenador')`. La v0.4 inscrit la **doctrine R8 traçabilité coordination** comme principe transverse (§Préambule politique), dont la version §7.3bis de cette spec est l'application concrète aux consultations. |
| spec-gouvernance-roles.md | v1.1 | Cohérence maintenue : la matrice §5.2 utilise les 3 rôles staff locaux (`librarian`, `coordenador`) et le « system » (cron). Aucune mention de `'administrador'` qui n'existe plus. |
| **spec-profils-bibliotheque.md v0.7** *(19/05/2026, clôture chantier)* | v0.7 | Doctrine compatible : une biblio en `circulation_mode = off` n'a pas d'onglet Consultations dans son painel. Une biblio en `informal` peut avoir des consultations simples sans cotisations. Une biblio en `full_sigb` a le workflow complet. **Vérifié en prod** : BLMF (`full_sigb`), BTL (`informal`), BLT-test (`informal`) — comportements adaptatifs validés au paquet E.0-E.5 du chantier profils. |
| **spec-onboarding-biblioteca.md v2.0** *(20/05/2026)* | v2.0 | Indirectement liée via la doctrine anti-méga-machine §1.4 inscrite normativement dans la v2.0 onboarding. Les flux consultas eux-mêmes sont **hors champ humain proactif** (c'est de la mécanique de circulation), mais la doctrine R9 traçabilité coordination s'articule avec l'éthos « transparence interne staff » porté par la v2.0 onboarding §1.4.2 exigence 3. |
| spec-validation-physique.md | (à rédiger) | Indépendante. Le `user_id` utilisé doit être validé physiquement, mais la spec consultations ne re-vérifie pas (déléguée). |

---

## 14. Annexes

### 14.1 Glossaire

- **Consultation sur place** : acte de consulter un document sans l'emprunter, dans l'espace de la biblio. S'oppose à l'emprunt (qui sort le document) et à la consultation à distance (numérique).
- **Créneau** *(v2.1)* : fenêtre temporelle `[consultation_starts_at, consultation_ends_at]` proposée par la biblio pour la consultation. Toujours définie par début + fin (invariant `schedule_missing`).
- **Reproposition** *(v2.1)* : nouvelle proposition de créneau par la biblio après un refus du lecteur. Cycle libre, pas de plafond d'itération.
- **No-show** : le lecteur ne s'est pas présenté à un créneau confirmé. Stage `nao_compareceu`. L'`item_status` reste `ativa` (transition non terminale).
- **Dismiss** : action UI du lecteur pour "fermer" une ligne annulée par la biblio (set `dismissed_by_reader_at`). Ne change pas l'état métier.

### 14.2 Références implémentation

- **Phase 0 (audit)** : 11/05/2026
- **Paquet 24** (helpers + invariant) : commits 12/05/2026
- **Paquet 25** (wrappers api.*) : commits 12/05/2026
- **Paquet 26** (L1 à L5, notifications) : commits 13/05/2026 (avec recovery 14/05 matin sur 5 fichiers)
- **Paquet 27.A.1 à 27.A.7** (frontend lecteur + biblio + hotfix) : commits 14/05/2026

### 14.3 Changelog v1 → v2 (rappel)

Audit Phase 0 ajouté §2.4-§2.8 (aucun trigger, aucune clé mail, aucun handler, UI staff partielle avec bug latent L1520, UI lecteur incomplète, invariant emprunt-vs-consulta non garanti). Phase 1 et Phase 5 ajustées en conséquence.

### 14.4 *(Nouveau)* Changelog v2 → v2.1

**Objet de la version** : refonte post-implémentation. Toutes les phases sont marquées closes avec leurs commits de référence. La spec devient un document de référence de l'état du système en production au 14/05/2026, pas une cible à atteindre.

**Sections ajoutées** :
- §3.4 Helper partagé `scheduleFormat.js` (R2)
- §4.2, §4.3 actualisées : `negotiation_iteration_count` et `pickup_proposed_by` non retenus (décision documentée)
- §5.5 Invariant `schedule_missing` : créneau complet obligatoire (R1)
- §10 Chronologie effective du chantier
- §11.2 Raffinements doctrinaux figés en cours d'implémentation (R1-R6)
- §12.1 invariant #6 et #7 ajoutés
- §14.4 Ce changelog

**Sections refondues** :
- En-tête statut : v2.1 entièrement livrée
- §1 Contexte : ajout bilan d'implémentation
- §2 État de l'existant : sections marquées « (avant Phase X) » pour clarifier qu'il s'agit du point de départ
- §2.8 : chaque constat marqué ✅ Résolu avec paquet de référence
- §3.1 : pastille v2.1 (PanelPage) ajoutée aux libellés `schedule_reply_status`
- §3.2 : motif `schedule_missing` précisé (les 3 éléments)
- §3.3 : exhaustivité réelle des clés i18n livrées (~240 vs ~40 prévues), réparties par paquet
- §5.1 : cycle de vie actualisé avec mails à chaque transition, cycle de reproposition
- §5.2 : matrice enrichie avec conditions temporelles (no-show) et de reply (reproposition)
- §5.3 : règles par acteur enrichies (modal de confirmation côté lecteur, motif obligatoire au refus, etc.)
- §6 entière : RPC marquées livrées avec paquet, `api.advance_consulta` enrichi de l'invariant `schedule_missing` explicite, `'administrador'` retiré des CHECK
- §7 entière : triggers et handler décrits comme livrés
- §8 entière : UI lecteur et biblio décrits comme livrés avec paquets de référence
- §9 entière : phases marquées closes avec dates et paquets
- §10 et §11 : entièrement nouveaux ou restructurés
- §13 : cohérence avec spec admin réseau v0.3.1 et spec profils v0.3 explicitées

**Sections inchangées** :
- §1 Contexte politique (préambule)
- §2.1, §2.2, §2.3 (description structurelle des tables, fonctions, vues — décrivent le point de départ)
- §3.2 (motifs de refus) sauf précision sur `schedule_missing`
- §10.1, §10.2, §10.3, §10.4, §10.5 (devenues §11.1 mais contenu conservé)

**Bilan v2.1** : la spec est désormais un **document de référence post-implémentation**. Elle décrit ce qui tourne en prod, avec les raffinements doctrinaux figés au fil du codage. Toute évolution future passera par une v2.2 ou v3 dédiée (par exemple : ajout de la contre-proposition par le lecteur, activation des rappels de créneau, formalisation E2E Playwright).

### 14.5 *(Nouveau v2.2)* Changelog v2.1 → v2.2

**Objet de la version** : intégration normative des doctrines techniques issues du **chantier hardening #141** (16/05/2026) et du **chantier #142** (17/05/2026). Ces chantiers ont résolu 7+1 bugs en production sur la chaîne de notifications consultas et fait émerger 5 doctrines techniques (R7 à R11) qui restaient inscrites uniquement en mémoire d'équipe et dans le code, sans inscription normative.

**Origine** : sessions des 16/05 (hardening #141) et 17/05 (#142 mail coordination + #143 onglet Historique) — cf. `docs/decisions/SESSION_141-hardening-notifications-consultas_2026-05-16.docx` (référence externe).

**Sections ajoutées** :
- En-tête : référence au chantier #141 intégré, mention specs liées v0.4/v2.0/v0.7 du 20/05
- §7.2bis : encadré pédagogique « Doctrine d'ordre des UPDATEs dans les RPC » avec exemples ❌/✅
- §7.3bis : encadré pédagogique « Doctrine R8 traçabilité coordination — extension actions staff »
- §11.3 entière : doctrines techniques R7 à R11 internalisées au chantier #141 (5 doctrines détaillées)
- Cette §14.5 (ce changelog)

**Sections mises à jour** :
- §13 cohérence avec autres specs : tableau enrichi avec versions à jour (admin réseau v0.4, profils v0.7, onboarding v2.0). TODO de propagation des doctrines R7-R11 aux specs sœurs (emprunts, réservations) inscrit.

**Sections inchangées (par rapport à v2.1)** :
- §1 contexte politique (intact)
- §2 état de l'existant (intact, point de départ historique)
- §3 vocabulaire et libellés
- §4 modèle de données
- §5 matrice des transitions
- §6 RPC publiques — contrats
- §7.1 audit initial
- §7.2 triggers (description structurelle inchangée, §7.2bis vient en complément)
- §7.3 handler EF (description structurelle inchangée, §7.3bis vient en complément)
- §7.4 clés i18n mails
- §7.5 toggles
- §8 surfaces UI complètes
- §9 phases d'implémentation
- §10 chronologie effective
- §11.1 points ouverts conservés
- §11.2 raffinements R1-R6 (v2.1)
- §12 risques et invariants
- §14.1 à §14.4 (annexes antérieures)

**Doctrines R7-R11 résumées** :

| Doctrine | Origine | Articulation |
|---|---|---|
| **R7** Ordre UPDATE narrative-avant-état | #141.2.E | RPC métier multi-tables |
| **R8** Distinction `workflow_note` / `schedule_reply_note` | #141.2.C | Colonnes DB + handler propagation |
| **R9** Traçabilité coordination R8 généralisée | #142 | Pattern transverse, doctrine politique |
| **R10** Cohérence handler vs trigger : payload stable | #141 (général) | Discipline d'évolution |
| **R11** Doctrine UTF-8 PowerShell sur scripts i18n | #141.3 + #145 (faux positif) | Workflow d'édition |

**Effort d'implémentation v2.2** : **aucun nouveau code**. Cette version est purement doctrinale — elle fige par écrit ce qui est déjà en prod depuis le 16-17/05. La valeur ajoutée est la **transmission** des doctrines : un·e nouveau·elle contributeur·rice peut désormais lire ces 5 doctrines dans la spec plutôt que de devoir les reconstituer depuis les commits ou la mémoire d'équipe.

**TODO post-v2.2** :
- Propager R7 (ordre UPDATE) à `spec-flux-emprunts.md` et `spec-workflow-reservation.md` (audit symétrique nécessaire)
- Propager R8 (distinction notes) à `spec-flux-emprunts.md` si pertinent (à vérifier : structure différente)
- Propager R9 (traçabilité coordination) à tous les flux où une action staff impacte un compte lecteur : emprunts (extensions, renouvellements, retours), réservations (annulations staff), etc.
- R10 et R11 sont doctrines transverses, à inscrire dans un futur `doctrines-techniques-generales.md` quand le corpus le justifiera

**Bilan v2.2** : la spec consultas est désormais le **document de référence le plus complet** du projet AnarBib. Elle couvre tout le cycle de vie d'une consultation (création, négociation de créneau, réponse lecteur, exécution, no-show, annulation, expiration), avec 11 doctrines techniques formalisées (invariant `schedule_missing`, helpers, reproposition, no-show conditionnel, principe SIGB, E2E reportée, ordre UPDATE, distinction notes, traçabilité coordination, cohérence trigger/handler, UTF-8 PowerShell). Elle sert de **modèle de structure** pour les autres specs de flux du projet.

---

*Spec rédigée le 11/05/2026, refonte v2.1 le 15/05/2026, enrichissement doctrinal v2.2 le 20/05/2026. Chantier consultations entièrement livré en prod en 4 jours calendaires (paquets 24-27), hardening en 1 jour (chantier #141), enrichissement traçabilité en 1/2 jour (chantier #142).*
