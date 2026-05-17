# QA manuelle Réservations — v1

**Date :** [à compléter à la passation]
**Spec de référence :** `docs/specs/spec-workflow-reservation.md` (à confirmer) + `reservation.stage.*` dans `src/i18n/locales/*.json`
**Contexte :** alternative aux tests E2E Playwright (reportés). QA manuelle structurée à dérouler après chaque livraison majeure touchant le flux réservations. Modèle calqué sur `QA_MANUELLE_consultations-2026-05-15.md`.
**Opérateur :** Xavier
**Environnement :** prod (app.anarbib.org)

---

## Résumé exécutif

À compléter à la passation. Format suggéré :

- **Scénarios déroulés :** X + Y sous-scénarios
- **Bugs fonctionnels détectés :** liste avec sévérité
- **Décalages spec ↔ prod :** liste numérotée
- **Doctrines politiques émergées :** réflexions à inscrire en spec

---

## Prérequis

- ✅ Livre catalogué disponible à la réservation sur BLMF (`bib_ref` de test)
- ✅ Compte lecteur·rice de test (rôle `leitor`)
- ✅ Compte coordenador·a·e de test (rôle `coordenador`)
- ✅ Au moins 1 exemplaire de l'item de test en état `disponivel` (ou réservable selon politique)
- ✅ Boîte mail accessible pour les 2 comptes (vérifier réception)
- ⚠️ Vérifier en amont les toggles `library_notification_policies.reservation_mail_*_enabled` pour cette biblio

### Sondage état initial (SQL)

```sql
-- Voir les réservations actives existantes pour BLMF avant tests
SELECT 
  rl.reserva_id, rl.line_no, rl.item_status,
  rl.bib_ref, rl.titulo_cache,
  r.user_id, r.created_at
FROM reserva_linhas_v2 rl
JOIN reservas_v2 r ON r.id = rl.reserva_id
WHERE r.library_id = '<BLMF_LIBRARY_ID>'
  AND rl.item_status = 'ativa'
ORDER BY r.created_at DESC
LIMIT 10;
```

---

## Scénario 1 — Création d'une réservation par le lecteur·rice

**Acteurs :** lecteur·rice
**Précondition :** Au moins 1 exemplaire en état réservable sur BLMF
**RPC visée :** `fn_v2_create_reserva_by_holdings`

**Étapes :**
1. Compte lecteur·rice connecté
2. Aller sur la page d'un livre catalogué (avec exemplaires disponibles)
3. Cliquer « Réserver » (ou équivalent i18n)
4. Confirmer dans la modal éventuelle

**Résultats attendus :**
- ✅ Redirection vers `/conta` onglet « Reservas e consultas »
- ✅ Statut côté lecteur·rice : « Ativa » avec libellé `reservation.stage.solicitada` ou équivalent visible
- ✅ Mail reçu par la biblio (coordenador·a·e) avec sujet équivalent à « Nova reserva solicitada »
- ⚠️ **À documenter** : mail reçu par le lecteur·rice ? (cf. doctrine D3 consultations — accusé réception explicite)
- ✅ Ligne créée dans `reserva_linhas_v2` avec `item_status = 'ativa'`
- ✅ Workflow stage effectif : `solicitada`

**Vérification DB :**

```sql
SELECT 
  rl.reserva_id, rl.line_no, rl.item_status,
  w.workflow_stage, w.workflow_note,
  r.created_at, r.library_id
FROM reserva_linhas_v2 rl
JOIN reservas_v2 r ON r.id = rl.reserva_id
LEFT JOIN reserva_item_workflow_v2 w 
  ON w.reserva_id = rl.reserva_id AND w.line_no = rl.line_no
ORDER BY rl.id DESC
LIMIT 1;
```

**Résultat :** À compléter

---

## Scénario 2 — Proposition de créneau de retrait par la biblio

**Acteurs :** coordenador·a·e
**Précondition :** Réservation du scénario 1 en stage `solicitada`
**RPC visée :** `fn_propose_pickup_slot_as_library` (ou via `advance_reservation`)

**Étapes :**
1. Compte coord connecté, aller sur PanelPage onglet « Réservations »
2. Sélectionner la réservation du scénario 1
3. Cliquer « Proposer un créneau de retrait » (ou équivalent)
4. Saisir date + horaire de retrait + note workflow optionnelle
5. Valider

**Résultats attendus :**
- ✅ Statut passe à « Aguardando retirada » ou équivalent
- ✅ `workflow_stage` passe à `pickup_proposed` (à vérifier nom exact)
- ✅ `pickup_scheduled_for` rempli en DB
- ✅ Mail reçu par le lecteur·rice avec créneau proposé bien formaté (vérifier que le bug B1 consultas n'existe pas ici)
- ⚠️ Mail reçu par la biblio (traçabilité coordination, cf. doctrine R8) ?
- ✅ Pastille `Aguardando confirmação` côté PanelPage

**Vérification DB :**

```sql
SELECT 
  w.workflow_stage, w.workflow_note,
  w.pickup_scheduled_for, w.pickup_reply_status,
  w.updated_at
FROM reserva_item_workflow_v2 w
WHERE w.reserva_id = <RESERVA_ID>
ORDER BY w.id DESC
LIMIT 1;
```

**Résultat :** À compléter

---

## Scénario 3 — Confirmation du créneau par le lecteur·rice

**Acteurs :** lecteur·rice
**Précondition :** Scénario 2 OK, créneau proposé en attente
**RPC visée :** `fn_confirm_pickup_slot_as_reader`

**Étapes :**
1. Compte lecteur·rice connecté, `/conta`
2. Voir le bloc bleu de proposition de créneau
3. Cliquer « Confirmer »

**Résultats attendus :**
- ✅ Bloc bleu disparaît, remplacé par pastille verte « Confirmé pour [date/horaire] »
- ✅ `pickup_reply_status = 'confirmado_leitor'`
- ✅ Mail reçu par la biblio (« Leitor·a·e confirmou o horário »)
- ✅ Côté PanelPage, pastille passe au vert ✓

**Résultat :** À compléter

---

## Scénario 4 — Refus du créneau + contre-proposition par le lecteur·rice

**Acteurs :** lecteur·rice puis coordenador·a·e
**RPC visées :** `fn_propose_pickup_slot_as_reader` (contre-proposition lecteur), puis itération biblio

**Étapes (refus simple) :**
1. Nouvelle réservation, scénarios 1 + 2 jusqu'au créneau proposé
2. Compte lecteur·rice, refuser le créneau avec motif (`pickup_reply_note`)
3. Vérifier propagation motif côté biblio

**Résultats attendus :**
- ✅ Modal exige motif obligatoire (≥ N chars selon doctrine — à vérifier)
- ✅ Bloc bleu disparaît
- ✅ Pastille « Recusado » apparaît côté lecteur·rice (cf. bug B4 consultas — vérifier que le pattern est meilleur ici)
- ✅ `pickup_reply_status = 'recusado_leitor'` + `pickup_reply_note` rempli
- ✅ Mail reçu par la biblio avec **le motif présent dans le corps** (vérifier que le bug B3 consultas n'existe pas ici)
- ✅ Bouton « Proposer un autre créneau » apparaît côté PanelPage

**Variante : contre-proposition lecteur :**
- ✅ Lecteur peut proposer SON créneau via `fn_propose_pickup_slot_as_reader`
- ✅ Compteur `negotiation_iteration_count` incrémenté

**Résultat :** À compléter

---

## Scénario 5 — Annulation de la réservation par le lecteur·rice

**Acteurs :** lecteur·rice
**RPC visée :** `cancel_my_reservation`

### 5a — Depuis `solicitada`

**Étapes :**
1. Compte lecteur, `/conta`, réservation en `ativa` / `solicitada`
2. Cliquer « Annuler »
3. Saisir note libre dans modal

**Résultats attendus :**
- ✅ Modal de confirmation avec note libre (optionnelle)
- ✅ `item_status` passe à `cancelada_leitor`
- ✅ Ligne disparaît du tab actif, va dans l'historique (onglet Historique #143 si déployé)
- ✅ Mail reçu par la biblio

### 5b — Depuis `pickup_proposed` (créneau proposé)

**Étapes :** idem mais sur réservation en cours de négociation créneau

**Résultats attendus :**
- ✅ Annulation fonctionne aussi
- ✅ Mail biblio reçu

**Résultat :** À compléter

---

## Scénario 6 — Annulation de la réservation par la biblio (avec motif obligatoire)

**Acteurs :** coordenador·a·e
**RPC visée :** `cancel_reservation_as_library`
**Doctrine de référence :** spec §x.y (motif obligatoire ≥ 5 chars — cohérent avec doctrine 141.2.E pour consultas)

**Étapes :**
1. Compte coord, PanelPage, sélectionner réservation
2. Cliquer « Anular »
3. **Vérifier que la modal de motif obligatoire apparaît** (cf. bug B6 consultas)
4. Saisir motif (≥ 5 chars)
5. Valider

**Résultats attendus :**
- ✅ Modal exige motif (validation frontend ET backend)
- ✅ Tentative sans motif → erreur explicite
- ✅ `item_status` passe à `cancelada_biblioteca`
- ✅ `workflow_note` contient le motif
- ✅ Mail reçu par le lecteur·rice **avec motif dans le corps** (cohérent avec fix #141.2.E + #141.2.F)
- ✅ Mail reçu par la coordination (cohérent avec chantier #142 R8)
- ✅ Ligne disparaît du tab actif côté lecteur, bloc « Annulée par biblio » avec motif visible

**Variante dismiss lecteur (post #132) :**
- ✅ Bouton « Accuser réception » côté lecteur·rice apparaît
- ✅ Clic → RPC `dismiss_consulta_cancelled` style équivalent pour réservations (à vérifier nom exact)
- ✅ `dismissed_by_reader_at` rempli en DB
- ✅ Bloc disparaît

**Résultat :** À compléter

---

## Scénario 7 — Expiration automatique d'une réservation

**Acteurs :** système (cron)
**Précondition :** Réservation avec `expires_at` dans le passé

**Étapes :**
1. Setup SQL : créer une réservation puis forcer `UPDATE reserva_linhas_v2 SET expires_at = now() - interval '1 day'`
2. Attendre l'exécution du cron d'expiration (ou déclencher manuellement la fonction si elle existe)

**Résultats attendus :**
- ✅ `item_status` passe à `expirada`
- ✅ Mail reçu par le lecteur·rice (« Sua reserva expirou »)
- ✅ Mail reçu par la coordination ?

**Résultat :** À compléter

---

## Scénario 8 — No-show (réservation non retirée au créneau)

**Acteurs :** coordenador·a·e
**RPC visée :** `mark_no_show`
**Précondition :** Réservation confirmée pour un créneau passé, lecteur·rice non venu·e

**Étapes :**
1. Setup SQL : créneau passé via `UPDATE reserva_item_workflow_v2 SET pickup_scheduled_for = now() - interval '2 hours'`
2. PanelPage, sélectionner cette réservation
3. Cliquer « Marquer non-retrait »

**Résultats attendus :**
- ✅ Bouton « Marcar não comparecimento » bien visible (uniquement si créneau passé)
- ✅ `workflow_stage` passe à `nao_compareceu`
- ✅ Mail reçu par le lecteur·rice (rappel d'engagement réciproque, cf. doctrine R8 consultas)
- ✅ Mail reçu par la coordination

**Résultat :** À compléter

---

## Scénario 9 — Conversion en emprunt (retrait effectif)

**Acteurs :** coordenador·a·e
**RPC visée :** `confirm_pickup_v1`
**Précondition :** Réservation confirmée, lecteur·rice présent·e pour retirer

**Étapes :**
1. PanelPage, sélectionner réservation `confirmado_leitor`
2. Cliquer « Effectuer le retrait » (ou équivalent)
3. Valider

**Résultats attendus :**
- ✅ `item_status` passe à `convertida_em_emprestimo`
- ✅ Nouveau record dans `emprestimos_v2` créé
- ✅ `emprestimo_item_id` rempli sur la `reserva_linha_v2`
- ✅ La réservation va dans l'historique
- ✅ L'emprunt apparaît dans l'onglet « Emprunts » de PanelPage
- ✅ Mail reçu par le lecteur·rice (« Emprestimo criado, prazo de devolução : ... »)

**Résultat :** À compléter

---

## Scénario 10 — Libération pour circulation (file d'attente)

**Acteurs :** système (suite à scénario d'annulation/expiration)
**Précondition :** 2 réservations en file d'attente sur le même item

**Étapes :**
1. Setup : 2 lecteurs ont réservé le même item, le 1er en `ativa`, le 2e en `liberada_para_circulacao` (à vérifier vocabulaire exact)
2. Annuler la réservation du lecteur 1 (scénario 5a)
3. Observer le comportement de la réservation suivante

**Résultats attendus :**
- ✅ La réservation suivante passe automatiquement de `liberada_para_circulacao` à `ativa` / `solicitada`
- ✅ Mail reçu par le 2e lecteur·rice (« Votre tour est arrivé, vous pouvez retirer l'item »)

**Résultat :** À compléter (test plus complexe — éventuellement reporter)

---

## Bugs détaillés

Format suggéré, à remplir à la passation :

| ID | Scénario | Sévérité | Description |
|---|---|---|---|
| Br1 | | 🔴 / 🟠 / 🟡 | |
| Br2 | | | |

(Préfixe `Br` pour « Bug réservations » et éviter confusion avec les `B*` consultations)

---

## Décalages spec ↔ prod

| ID | Description | Décision |
|---|---|---|
| Dr1 | | |

(Préfixe `Dr` idem)

---

## Doctrine politique émergée

À identifier au déroulé. Points d'attention :

- **Accusé de réception lecteur** : faut-il un mail au lecteur à la création de la réservation ? (cf. D3 consultations — décision politique « on garde »)
- **Traçabilité coordination R8** : appliquer la même doctrine que pour les consultas — mails de coordination sur toutes les actions biblio (proposition créneau, annulation, no-show)
- **Note obligatoire annulation biblio** : cohérent avec doctrine 141.2.E (≥ 5 chars) ?

---

## Conclusion

À rédiger à la passation. Format suggéré :

- État global du workflow (opérationnel bout-en-bout ou non ?)
- Liste des fixes ciblés à prioriser
- Recommandation de chantier suivant

---

*Document QA déroulée le [DATE]. Trace conservée pour les futures sessions.*
