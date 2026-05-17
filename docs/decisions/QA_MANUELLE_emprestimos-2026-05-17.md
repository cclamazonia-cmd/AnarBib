# QA manuelle Emprunts — v1

**Date :** [à compléter à la passation]
**Spec de référence :** `docs/specs/spec-flux-emprunts.md` (table des matières §1-6)
**Contexte :** alternative aux tests E2E Playwright (reportés). QA manuelle structurée à dérouler après chaque livraison majeure touchant le flux emprunts. Modèle calqué sur `QA_MANUELLE_consultations-2026-05-15.md`.
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

- ✅ Livre catalogué disponible à l'emprunt sur BLMF (`bib_ref` de test)
- ✅ Compte lecteur·rice de test (rôle `leitor`)
- ✅ Compte coordenador·a·e de test (rôle `coordenador`)
- ✅ Au moins 2 exemplaires de l'item de test (pour scénarios groupés)
- ✅ Boîte mail accessible pour les 2 comptes
- ✅ Toggle `library_notification_policies.loan_*` vérifiés (cf. spec §2.4)
- ⚠️ Vérifier l'état des migrations spec emprunts §4.1 (`parcialmente_devolvido` ajouté à `emprestimos_v2.status_global` CHECK) et §4.3 (`renewals_used` compteur explicite)

### Sondage état initial (SQL)

```sql
-- Voir les emprunts actifs existants pour BLMF avant tests
SELECT 
  e.id AS emprestimo_id,
  e.status_global,
  e.due_at,
  e.renewals_used,
  e.extended_once,
  count(ei.id) AS items_count,
  e.user_id,
  e.created_at
FROM emprestimos_v2 e
LEFT JOIN emprestimo_itens_v2 ei ON ei.emprestimo_id = e.id
WHERE e.library_id = '<BLMF_LIBRARY_ID>'
  AND e.status_global IN ('ativo', 'parcialmente_devolvido')
GROUP BY e.id
ORDER BY e.created_at DESC
LIMIT 10;
```

---

## Scénario 1 — Création directe (prêt comptoir) — 1 item

**Acteurs :** coordenador·a·e
**Précondition :** Lecteur·rice présent·e physiquement, item disponible
**RPC visée :** `create_loan_at_counter`
**Référence spec :** §5.4 + §6.3

**Étapes :**
1. Compte coord connecté, aller sur PanelPage onglet « Empréstimos »
2. Cliquer « Nouveau prêt comptoir » (ou équivalent)
3. Sélectionner ou rechercher le lecteur·rice
4. Sélectionner l'item (par `bib_ref` ou recherche catalogue)
5. Valider

**Résultats attendus :**
- ✅ Nouvel emprunt créé dans `emprestimos_v2` avec `status_global = 'ativo'`
- ✅ Nouvelle ligne dans `emprestimo_itens_v2` avec `book_id`, `bib_ref`, `titulo_cache`, `autor_cache`
- ✅ `due_at` rempli (par défaut : created_at + délai politique biblio)
- ✅ `renewals_used = 0`, `extended_once = false`
- ✅ Mail reçu par le lecteur·rice avec date de retour
- ⚠️ Mail reçu par la coordination (traçabilité R8) — vérifier policy
- ✅ Apparaît dans PanelPage onglet « Empréstimos » du coord
- ✅ Apparaît dans `/conta` onglet « Mes emprunts » du lecteur·rice

**Vérification DB :**

```sql
SELECT 
  e.id, e.status_global, e.due_at, 
  e.renewals_used, e.extended_once,
  ei.line_no, ei.bib_ref, ei.titulo_cache, ei.status
FROM emprestimos_v2 e
JOIN emprestimo_itens_v2 ei ON ei.emprestimo_id = e.id
WHERE e.id = <EMPRESTIMO_ID>
ORDER BY ei.line_no;
```

**Résultat :** À compléter

---

## Scénario 2 — Création directe groupée (multi-items)

**Acteurs :** coordenador·a·e
**Précondition :** Lecteur·rice physiquement présent·e, ≥ 2 items disponibles
**RPC visée :** `create_loan_at_counter` avec multiple items

**Étapes :**
1. PanelPage, « Nouveau prêt comptoir »
2. Sélectionner le lecteur·rice
3. Ajouter 2 ou 3 items différents
4. Valider

**Résultats attendus :**
- ✅ 1 seul record dans `emprestimos_v2` (l'emprunt regroupe les items)
- ✅ N records dans `emprestimo_itens_v2` avec `line_no = 1, 2, 3`
- ✅ Tous les items ont `due_at` cohérent (même date ou par item ? — à confirmer politique)
- ✅ 1 seul mail au lecteur·rice listant tous les items (vérifier que le pluriel/singulier est correct)
- ✅ Dans PanelPage : 1 ligne avec badge « Agrupado » + count items (cf. vue `painel_loans_history_v1` du #143)
- ✅ `loan_type = 'groupe'` dans la vue history

**Résultat :** À compléter

---

## Scénario 3 — Création depuis réservation (post-conversion)

**Acteurs :** coordenador·a·e
**Précondition :** Réservation en `confirmado_leitor` (cf. scénario 9 du doc QA réservations)
**RPC visée :** `confirm_pickup_v1`
**Référence spec :** §5.5

**Étapes :**
1. PanelPage onglet Réservations, sélectionner réservation confirmée
2. Cliquer « Effectuer le retrait »
3. Valider

**Résultats attendus :**
- ✅ Cf. scénario 9 du doc QA réservations
- ✅ Pas de double-création (un seul emprunt même si on clique 2 fois)
- ✅ `emprestimo_item_id` rempli sur la `reserva_linha_v2`
- ✅ Mail conversion reçu par le lecteur·rice

**Résultat :** À compléter

---

## Scénario 4 — Renouvellement par le lecteur·rice

**Acteurs :** lecteur·rice
**Précondition :** Emprunt actif, non encore renouvelé
**RPC visée :** `renew_my_loan`
**Référence spec :** §5.2 + §6.1 (à corriger selon spec — état de fix en prod à vérifier)

**Étapes :**
1. Compte lecteur, `/conta`, onglet « Mes emprunts »
2. Sélectionner emprunt actif
3. Cliquer « Renouveler »

**Résultats attendus :**
- ✅ `renewals_used` incrémenté
- ✅ `extended_once` passe à `true` (compatibilité legacy)
- ✅ `due_at` repoussé (par délai politique biblio)
- ✅ `extended_at` rempli
- ✅ Mail reçu par le lecteur·rice (nouvelle date de retour)
- ⚠️ Mail reçu par la coordination (traçabilité R8) ?

**Variante : limite max atteinte**

**Précondition :** `renewals_used >= max_renewals` (politique biblio)

**Étapes :** idem

**Résultats attendus :**
- ✅ RPC retourne erreur explicite (motif `max_renewals_reached` ou équivalent — cf. spec §3.2)
- ✅ Toast ou message d'erreur côté UI
- ✅ Pas de modification DB

**Résultat :** À compléter

---

## Scénario 5 — Extension par la biblio

**Acteurs :** coordenador·a·e
**Précondition :** Emprunt actif
**RPC visée :** `extend_loan_as_library`
**Référence spec :** §6.2

**Étapes :**
1. PanelPage onglet Empréstimos, sélectionner emprunt
2. Cliquer « Etendre » (ou équivalent)
3. Saisir nouvelle date ou délai

**Résultats attendus :**
- ✅ `due_at` mis à jour à la nouvelle date
- ✅ `extended_once = true`, `extended_at` rempli
- ✅ Mail reçu par le lecteur·rice (nouvelle date de retour) avec mention "extension par la biblio"

**Résultat :** À compléter

---

## Scénario 6 — Retour total

**Acteurs :** coordenador·a·e
**Précondition :** Emprunt actif avec N items
**RPC visée :** `return_loan_total`
**Référence spec :** §5.3 + §6.4

**Étapes :**
1. PanelPage onglet Empréstimos, sélectionner emprunt
2. Cliquer « Retour total »
3. Valider

**Résultats attendus :**
- ✅ `emprestimos_v2.status_global` passe à `encerrado`
- ✅ Tous les `emprestimo_itens_v2.status` passent à `devolvido`
- ✅ `returned_at` rempli sur tous les items
- ✅ Emprunt quitte l'onglet actif, va dans l'historique (cf. vue `painel_loans_history_v1` du #143)
- ✅ Mail reçu par le lecteur·rice (« Retour confirmé »)

**Résultat :** À compléter

---

## Scénario 7 — Retour partiel (multi-items)

**Acteurs :** coordenador·a·e
**Précondition :** Emprunt groupé (≥ 2 items) actif
**RPC visée :** `return_loan_partial`
**Référence spec :** §5.3 + §6.5
**Décalage prod possible :** migration §4.1 (`parcialmente_devolvido`) appliquée ?

**Étapes :**
1. PanelPage, sélectionner emprunt groupé
2. Cliquer « Retour partiel »
3. Cocher les items rendus, laisser les autres
4. Valider

**Résultats attendus :**
- ✅ `emprestimos_v2.status_global` passe à `parcialmente_devolvido` (si migration §4.1 OK)
- ⚠️ Si migration non appliquée : status reste `ativo` jusqu'au retour complet ?
- ✅ Items rendus : `status = devolvido`, `returned_at` rempli
- ✅ Items non rendus : `status = ativo`, `returned_at = NULL`
- ✅ Emprunt reste dans l'onglet actif (pas dans l'historique)
- ✅ Mail reçu par le lecteur·rice (« Retour partiel : X items rendus, Y restants »)

**Vérification DB :**

```sql
SELECT 
  e.status_global,
  ei.line_no, ei.bib_ref, ei.status, ei.returned_at
FROM emprestimos_v2 e
JOIN emprestimo_itens_v2 ei ON ei.emprestimo_id = e.id
WHERE e.id = <EMPRESTIMO_ID>
ORDER BY ei.line_no;
```

**Résultat :** À compléter

---

## Scénario 8 — Emprunt en retard (overdue)

**Acteurs :** lecteur·rice + coordenador·a·e (vues)
**Précondition :** Emprunt avec `due_at` dans le passé
**Logique :** déclenchée par cron ou calculée dynamiquement

**Étapes :**
1. Setup SQL : `UPDATE emprestimos_v2 SET due_at = now() - interval '2 days' WHERE id = <EMPRESTIMO_ID>`
2. Recharger `/conta` côté lecteur et PanelPage côté coord

**Résultats attendus :**
- ✅ Côté lecteur : badge rouge « En retard » ou équivalent
- ✅ Côté coord : badge ou tri par retard
- ⚠️ Mail de rappel envoyé au lecteur·rice ? (cf. policy `loan_overdue_mail_*` si elle existe)
- ⚠️ Mail loan_midpoint envoyé à mi-emprunt ? (cf. `loan_midpoint_message_log`)

**Résultat :** À compléter

---

## Scénario 9 — Tentative emprunt sur item indisponible

**Acteurs :** coordenador·a·e
**Précondition :** Item déjà emprunté ou marqué indisponible

**Étapes :**
1. Tenter create_loan_at_counter sur cet item
2. Observer comportement

**Résultats attendus :**
- ✅ Erreur explicite renvoyée par RPC
- ✅ Toast ou message UI
- ✅ Pas de modification DB

**Résultat :** À compléter

---

## Scénario 10 — Vérification invariant emprunt-vs-consulta

**Précondition :** Item ayant à la fois un emprunt actif et une consulta active (situation à empêcher)

**Étapes :**
1. Setup SQL : créer un emprunt actif sur un item
2. Tenter de créer une consulta locale sur ce même item via UI
3. Observer

**Résultats attendus :**
- ✅ Création bloquée (invariant emprunt-vs-consulta cf. paquet 24 chantier consultations)
- ✅ Message d'erreur explicite

**Résultat :** À compléter

---

## Bugs détaillés

Format suggéré, à remplir à la passation :

| ID | Scénario | Sévérité | Description |
|---|---|---|---|
| Be1 | | 🔴 / 🟠 / 🟡 | |

(Préfixe `Be` pour « Bug emprunts »)

---

## Décalages spec ↔ prod

| ID | Description | Décision |
|---|---|---|
| De1 | | |

(Préfixe `De` pour « Décalage emprunts »)

---

## Doctrine politique émergée

À identifier au déroulé. Points d'attention :

- **`parcialmente_devolvido`** : la migration spec §4.1 est-elle bien en prod ? Si non, quelle UX dégradée ?
- **Notifications loan_midpoint** : utile ou intrusif politiquement ? (cf. table `loan_midpoint_message_log` qui existe en prod)
- **Limite renouvellements max** : politique biblio ou globale ? Comment surfacer l'info à l'avance pour le lecteur·rice ?
- **Traçabilité coordination R8** : mails sur retour, extension, renouvellement ?

---

## Conclusion

À rédiger à la passation. Format suggéré :

- État global du workflow (opérationnel bout-en-bout ou non ?)
- Liste des fixes ciblés à prioriser
- État de la migration §4.1 (parcialmente_devolvido)
- Recommandation de chantier suivant

---

*Document QA déroulée le [DATE]. Trace conservée pour les futures sessions.*
