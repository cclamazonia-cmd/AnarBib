# Paquet 26 — Phase 3 consultations — Doc d'arbitrage

> **Statut** : décisions figées 13/05/2026 en début de session, avant rédaction des 4 livrables.
> **Spec de référence** : `docs/spec-flux-consultations.md` v2, sections §5.2 (matrice transitions), §7 (triggers et notifications).
> **Phases amont closes** : Phase 0 (audit 11/05), Phase 1 (helpers + invariant, paquet 24 du 12/05), Phase 2 (wrappers `api.*`, paquet 25 du 12/05).

---

## 1. Périmètre du paquet 26

Pose la couche notifications consultations de zéro, sur le pattern v3 réservations (paquet 5 du 07/05). 4 livrables, dans cet ordre :

| L | Contenu | Effort | Risque |
|---|---|---|---|
| L1 | Migration toggles (8 colonnes `library_notification_policies`) | ~120 lignes SQL | Faible |
| L2 | Migration triggers (2 trigger functions + 2 triggers + smoke tests) | ~280 lignes SQL | Moyen (correctness sémantique) |
| L3 | i18n mails (~55 clés × 6 locales, préfixe `con.*`) | +320 lignes TS | Faible (linéaire mais volumineux) |
| L4 | Handlers + bundles + policies + events normalizers | ~400 lignes TS | Élevé (decode payload, format mail, i18n binding) |

---

## 2. Décisions consolidées (15 items)

| # | Décision | Source |
|---|---|---|
| 1 | **2 triggers distincts** : `trg_notify_consulta_lifecycle` sur `consulta_linhas_v2`, `trg_notify_consulta_workflow` sur `consulta_item_workflow_v2` | spec §7.2 |
| 2 | **6 events** au total : `consulta_v2_criada / _realizada / _cancelada / _expirada / _agendada / _resposta_creneau` | spec §7.2 |
| 3 | Naming events : **snake_case** `consulta_v2_*`, calque exact de `reserva_v2_*` et `emprestimo_v2_*` | `dispatch.ts` réel |
| 4 | Pas d'event distinct `nao_compareceu` : reclassé staff vers `cancelada_biblioteca` → tombe sous `consulta_v2_cancelada` | matrice §5.2 |
| 5 | **Toggles Option B granulaire** (8 flags) dépasse spec §7.4 (qui en prévoyait 3). Décision politique : finesse anti-spam | sondage |
| 6 | **Master switch préexistant** `local_consultation_enabled` conservé comme garde en amont des 8 flags | DB existant (Livre blanc v13 §7.2) |
| 7 | Default `consulta_mail_realizada_enabled` = **false** (calque anti-spam de `reservation_mail_liberada_para_circulacao_enabled`). Le lecteur sait que sa consultation a eu lieu puisqu'il était sur place. L'event existe quand même pour log côté biblio sur biblios qui activeraient le flag. | sondage 13/05 |
| 8 | Architecture handlers : **`_shared/domain/consultas.ts`** (PAS `handlers/consultas.ts` du prompt de reprise, qui se trompait) | arborescence repo réelle |
| 9 | 3 fonctions exportées : `handleConsultaCriadaV2(recordId)`, `handleConsultaV2LifecycleEvent(recordId, event, payload)`, `handleConsultaV2WorkflowEvent(recordId, event, payload)` | calque structure reservas.ts |
| 10 | Bundle data : créer **`_shared/data/consultas.ts`** avec `getConsultaV2Bundle`, `getConsultaWorkflowBundle` | calque data/reservas.ts |
| 11 | Policies helpers : 8 helpers à ajouter dans `_shared/context/policies.ts` (`consultaCriadaEnabled`, `consultaAgendadaEnabled`, ..., `consultaAdminCopyEnabled`) | calque policies réservations |
| 12 | Events normalizers : 2 fonctions à ajouter dans `_shared/shared/events.ts` (`normalizeConsultaLifecycleEvent`, `normalizeConsultaWorkflowEvent`) | calque events.ts |
| 13 | i18n : préfixe **`con.*`** (calque ultra-court `res.*` du code réel, PAS `mail.consulta.*` de la spec) | code réel `mail-strings.ts` ligne 294 |
| 14 | Timezone créneau : lue dans `library_service_state.consultation_timezone`, fallback `DEFAULT_NOTIFICATION_TIMEZONE`. Helper `formatDateTimeInZone` du `shared/format.ts` | Phase 2 (paquet 25) + `shared/format.ts` |
| 15 | Discriminant `cancelled_by ∈ {leitor, biblioteca}` passé en payload via le trigger lifecycle, lu par le handler pour routing destinataire + clé i18n | spec §7.2 |
| 16 | Locale biblio : `ctx.default_locale` (fallback `pt-BR`) — calque patch paquet 6 inline dans `reservas.ts` | code réel reservas.ts ligne 18-21 |

---

## 3. Les 8 flags de l'Option B

| Flag | Default | Justification |
|---|---|---|
| `consulta_mail_criada_enabled` | true | Création visible côté lecteur + biblio. Comme `reservation_mail_solicitada_enabled`. |
| `consulta_mail_agendada_enabled` | true | Créneau proposé / re-proposé. Information critique au lecteur. |
| `consulta_mail_resposta_creneau_enabled` | true | Confirmation ou refus du créneau par le lecteur. Information critique à la biblio pour préparer la séance. |
| `consulta_mail_realizada_enabled` | **false** | Log biblio uniquement. Le lecteur sait, il était sur place. Calque anti-spam de `reservation_mail_liberada_para_circulacao_enabled`. |
| `consulta_mail_cancelada_enabled` | true | Annulation des deux côtés (lecteur ou biblio). |
| `consulta_mail_expirada_enabled` | true | Expiration automatique. Lecteur + biblio. |
| `consulta_reminders_enabled` | true | Placeholder paquet ultérieur (§7.5 future). |
| `admin_copy_consultas_enabled` | true | Active la copie admin biblio pour TOUS les events. Calque `admin_copy_reservations_enabled`. |

Master switch `local_consultation_enabled` (préexistant) reste en amont : si false, aucun mail consulta n'est dispatché indépendamment des 8 flags.

---

## 4. Hiérarchie de lecture côté trigger DB + côté handler

```
[trigger DB]
  ↓ 1. lit library_notification_policies pour la library_id
  ↓ 2. SI local_consultation_enabled = false → skip silencieux (NEW return, pas d'http_post)
  ↓ 3. SI consulta_mail_<event>_enabled = false → skip silencieux
  ↓ 4. SINON → pg_net.http_post vers notify-event avec event_type + record_id + payload
       (payload contient cancelled_by pour discrimination cancelada)

[handler TS]
  ↓ 1. relit policies pour double-vérification (defensive : trigger peut être désactivé en debug)
  ↓ 2. SI local_consultation_enabled = false → return skippedEmailResult("local_consultation_disabled")
  ↓ 3. user_result = consultaXxxEnabled(ctx) ? safeSendEmail(...) : skippedEmailResult(...)
  ↓ 4. admin_result = consultaXxxEnabled(ctx) && consultaAdminCopyEnabled(ctx) ? safeSendEmail(...) : skippedEmailResult(...)
```

Le pattern double-garde est emprunté à `handleReservaCriadaV2` (ligne ~80-95 de reservas.ts). C'est défensif mais peu coûteux.

---

## 5. Risques identifiés et mitigations

| Risque | Mitigation |
|---|---|
| **Doublon lifecycle vs workflow** (event émis 2× si `item_status` ET `workflow_stage` changent dans la même transaction) | Les 2 triggers émettent des events DISJOINTS : lifecycle = {criada, realizada, cancelada, expirada}, workflow = {agendada, resposta_creneau}. Pas de chevauchement sémantique. |
| **Stale code v2 vs v3** (cf. paquet 6 où test contre stale code) | Forcer `supabase functions deploy notify-event --no-verify-jwt` après chaque modif et vérifier `supabase functions list` montre une version incrémentée. Documenter dans le bilan. |
| **CLI 2.98.2 incompatible** | `.woodpecker.yml` pin v2.98.1 inchangé. Local Xavier reste 2.98.1. |
| **Préfixe i18n incohérent** | Décision actée : `con.*` (calque `res.*`). Tous les `tMail(locale, "con.xxx")` cohérents dans handler. |
| **Timezone manquante** | Fallback `DEFAULT_NOTIFICATION_TIMEZONE` du `shared/format.ts`, déjà éprouvé par reservas. |
| **Migration appliquée 2× par CI** | `ADD COLUMN IF NOT EXISTS` rend la migration rejouable. Sanity check final via `DO $$ ... $$` détecte toute colonne manquante. |
| **Test prod** | À ajouter à la fin de Phase 3 : créer une consultation BLMF de Lívia → Xavier confirme un créneau → Lívia répond → Xavier marque réalisée. 6 events couverts en 1 scénario. |

---

## 6. Backlog post-paquet 26

À garder en mémoire pour Phases 4-6 et au-delà :

- **Phase 4** (AccountPage lecteur) : 3 RPC à migrer vers `api.*`, 2 nouveaux blocs UI (créneau proposé + créneau confirmé), ~25 clés i18n frontend
- **Phase 5** (PanelPage biblio) : 4 RPC à migrer vers `api.advance_consulta`, bouton no-show, fix bug L1520 (date manquante), ~15 clés i18n frontend
- **Phase 6** (Tests runtime end-to-end) : 9 scénarios à exécuter
- **§7.5 rappels** : à spécifier puis livrer en paquet 27 ou plus (`consulta_reminders_enabled` est le placeholder posé en L1)
- **Item backlog v7 #91** (score 12) : ce paquet 26 le clôt.

---

*Rédigé le 13/05/2026 avant rédaction L1, à valider avant push.*
