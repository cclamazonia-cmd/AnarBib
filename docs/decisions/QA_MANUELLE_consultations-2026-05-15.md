# QA manuelle Consultations — Résultats du 15/05/2026

**Date :** 15 mai 2026
**Spec de référence :** `docs/specs/spec-flux-consultations.md` v2.1 §9 Phase 6 + §11.2 R6
**Contexte :** alternative aux tests E2E Playwright (reportés). QA manuelle structurée à dérouler après chaque livraison majeure.
**Opérateur :** Xavier
**Environnement :** prod (app.anarbib.org)

---

## Résumé exécutif

**Scénarios déroulés :** 9 + 1 sous-scénario (3bis)

**Résultats :**
- **Workflow fonctionne bout-en-bout** : création → préparation → agender → confirmer → réaliser, ainsi que les variantes (refus + reproposition, no-show, annulations)
- **7 bugs fonctionnels détectés** (cf. §Bugs détaillés)
- **6 décalages spec ↔ prod** identifiés (cf. §Décalages)
- **1 doctrine politique émergée** : distinction traçabilité individuelle vs traçabilité collective

**Pas de bug bloquant** : la circulation des consultas marche, les bugs touchent surtout les notifications et le feedback visuel.

---

## Prérequis

- ✅ Livre catalogué avec holding consultable sur BLMF (`bib_ref` de test)
- ✅ Compte lecteur·rice de test disponible
- ⚠️ **Toggle global `consulta_lifecycle_enabled` n'existe pas** : la prod a 8 toggles fins par event (D6, cf. décalages)

---

## Scénario 1 — Création par le lecteur·rice, mail biblio

**Étapes** : compte lecteur connecté, page livre, « Demander une consultation », confirmer.

- ✅ Redirection vers `/conta` onglet Reservas e consultas
- ⚠️ **D2** Workflow stage côté lecteur·rice : seul « ativa » + bouton « Cancelar » visibles. Pas d'affichage du stage « Aguardando análise »
- ✅ Mail reçu par la biblio avec sujet équivalent à `Nova consulta solicitada`
- ⚠️ **D3** Mail reçu par le lecteur·rice : c'est un **accusé de réception**. Contradiction apparente avec SIGB R5, mais **décision politique : on garde cette fonctionnalité comme accusé de réception explicite**

**Résultat :** ✅ Workflow OK / ⚠️ 2 observations doctrinales

---

## Scénario 2 — Biblio prépare, mail lecteur·rice

**Étapes** : coordenador clique « Preparar » sur la consulta du scénario 1.

- ✅ Statut passe à « Em preparação »
- ❌ **B2 Bug fonctionnel** : pas de mail reçu par le lecteur·rice alors qu'attendu
- ✅ Aucun mail reçu par la biblio (cohérent SIGB R5)

**Résultat :** ❌ KO (mail manquant)

---

## Scénario 3 — Biblio propose un créneau

**Étapes** : modal Agendar, date demain 10:00–11:30, note saisie, « Agendar ».

- ✅ Date pré-remplie, `startsAt='14:00'` et `endsAt='15:00'` pré-remplis
- ✅ Note workflow optionnelle
- ✅ Statut passe à « Agendada para ... »
- ✅ Créneau correctement formaté **côté UI**
- ❌ **B1 Bug fonctionnel critique** : mail reçu par le lecteur·rice mais **créneau mal formaté dans le corps** : `"A biblioteca propôs um horário para sua consulta local: 16/05/2026, das às às às (UTC). Confirme se este horário funciona para você."` — placeholder cassé dans le template i18n
- ⚠️ **D4** Mail aussi envoyé à la biblio (traçabilité coordination, à inscrire en spec v2.2)
- ✅ Pastille gris ⏳ « Aguardando resposta » dans PanelPage

**Résultat :** ❌ KO (template i18n cassé)

---

## Scénario 3bis — Validation invariant `schedule_missing`

**Étapes** : nouvelle consulta, agender avec `endsAt` vidé.

- ✅ Validation frontend bloque le submit avec erreur `errorRequired`
- ✅ Pas d'appel backend
- ✅ Backend raise `schedule_missing` si contournement via devtools (testé indirectement par la cohérence)

**Résultat :** ✅ OK (invariant R1 fonctionnel)

---

## Scénario 4 — Lecteur·rice confirme créneau

**Étapes** : compte lecteur·rice, `/conta`, bloc bleu, « Confirmar ».

- ✅ Bloc bleu disparaît
- ✅ Pastille verte ✓ « Confirmado para ... » apparaît
- ✅ Mail reçu par la biblio (`Leitor·a·e confirmou o horário`)
- ✅ Côté PanelPage, pastille passe à ✓ vert

**Résultat :** ✅ OK

---

## Scénario 5 — Biblio marque réalisé

**Étapes** : coordenador clique « Marcar como realizada ».

- ✅ Statut passe à « Consultada »
- ❌ **D1** Pas d'onglet « historique consultations/réservations/emprunts » dans PanelPage — la ligne reste dans le même onglet
- ❌ **B5/D5** Pas de mail reçu par le lecteur·rice. Note : `consulta_mail_realizada_enabled = false` par défaut, cohérent SIGB R5 (lecteur·rice présent·e). Décision : **on garde le DEFAULT à false**, à documenter en spec v2.2

**Résultat :** ✅ Workflow OK / ⚠️ UX incomplète (pas d'onglet historique)

---

## Scénario 6 — Refus créneau + reproposition

**Étapes** : nouvelle consulta, agender, refuser avec motif, biblio repropose.

- ✅ Modal exige motif obligatoire
- ✅ Le bloc bleu disparaît côté lecteur·rice
- ❌ **B4 Bug mineur** : pas de pastille rouge « Recusado » côté lecteur·rice après refus (feedback visuel manquant)
- ✅ Mail reçu par la biblio (`Leitor·a·e recusou o horário`)
- ❌ **B3 Bug fonctionnel** : le motif rédigé n'apparaît pas dans le corps du mail biblio
- ✅ Pastille ✗ orange « Recusado pelo·a·e leitor·a·e » + motif italique côté PanelPage
- ✅ Bouton « Propor outro horário » apparaît
- ✅ Modal Agendar pré-rempli demain 14:00–15:00
- ✅ Pastille repasse à ⏳ gris après reproposition
- ✅ Le cycle peut reprendre
- ❌ **B1** Mail nouveau créneau toujours mal formaté

**Résultat :** ❌ KO (motif manquant dans mail + B1 répété + B4)

---

## Scénario 7 — No-show conditionné temporel

**Étapes** : créneau dans le passé via SQL UPDATE direct, bouton no-show.

- ✅ Bouton « Marcar não comparecimento » bien visible
- ✅ Bouton n'apparaît pas pour consultas refusées
- ✅ `workflow_stage` passe à `nao_compareceu`
- ❌ **D1** `item_status` reste `ativa`, mais sans onglet historique l'item reste de toute façon dans la liste (impact UX mineur)
- ❌ **B5 Bug fonctionnel** : pas de mail reçu par le lecteur·rice

**Résultat :** ❌ KO (mail manquant)

---

## Scénario 8 — Annulations par le lecteur·rice

### 8a — Depuis `solicitada`

- ✅ Modal de confirmation avec note libre
- ✅ Ligne disparaît du tab actif, va dans l'historique avec statut « Cancelada por mim »
- ✅ Mail reçu par la biblio

### 8b — Depuis `consulta_agendada`

- ✅ Idem : disparaît du tab actif, mail biblio reçu

**Résultat :** ✅ OK (les deux variantes fonctionnent)

---

## Scénario 9 — Annulation biblio + dismiss lecteur·rice

**Étapes** : nouvelle consulta, biblio clique « Anular ».

- ❌ **B6 Bug fonctionnel critique** : pas de modal, le clic « Anular » suffit. **Pas de note obligatoire saisie**. **Contradiction directe avec la spec consultas v2.1 §6.2 et §8.1 qui exigent une note obligatoire pour les annulations biblio**.
- ❌ **D1** Ligne reste dans le même onglet (pas d'historique)
- ✅ Mail reçu par le lecteur·rice
- ✅ Bloc « Annulée par biblio » visible côté lecteur·rice avec note de la biblio
- ❌ **B7 Bug fonctionnel critique** : bouton « Accuser réception » (dismiss) ne fonctionne pas. `dismissed_by_reader_at` reste à `null` après clic.
- ❌ Le bloc ne disparaît pas après clic dismiss
- ❌ La ligne ne quitte pas le tab actif

**Vérification DB après tentative dismiss** :
```
| consulta_id | line_no | dismissed_by_reader_at |
|     19      |    1    |          null          |
```

**Résultat :** ❌ KO (2 bugs critiques)

---

## Bugs détaillés

| ID | Scénario | Sévérité | Description |
|---|---|---|---|
| **B1** | 3, 6 | 🔴 Haute | Mail proposition créneau mal formaté : `"16/05/2026, das às às às (UTC)"`. Placeholder cassé dans template i18n `mail.consulta.agendada.body` |
| **B2** | 2 | 🟠 Moyenne | Mail `em_preparacao` non envoyé au lecteur·rice (trigger `trg_notify_consulta_workflow` ou handler manquant pour cet event) |
| **B3** | 6 | 🟠 Moyenne | Mail de refus créneau ne contient pas le motif rédigé par le lecteur·rice — payload event incomplet ou template i18n n'utilise pas la clé |
| **B4** | 6 | 🟡 Mineure | Pas de pastille rouge « Recusado » côté lecteur·rice après refus (bloc bleu disparaît sans remplacement visuel persistant) |
| **B5** | 7 | 🟠 Moyenne | Mail no-show non envoyé au lecteur·rice (trigger ou handler manquant pour `consulta.nao_compareceu`) |
| **B6** | 9 | 🔴 Haute | Annulation biblio sans modal ni note obligatoire — contradiction spec v2.1 §6.2 (note obligatoire) et §8.1 |
| **B7** | 9 | 🔴 Haute | Bouton « Accuser réception » côté lecteur ne fonctionne pas : `dismissed_by_reader_at` reste `null`. La RPC `api.dismiss_consulta_cancelled` n'est pas appelée ou échoue silencieusement |

---

## Décalages spec ↔ prod

| ID | Description | Décision |
|---|---|---|
| **D1** | Onglet historique inexistant dans PanelPage (consultas réalisées/annulées restent dans le même onglet) | Ajouter au chantier UX général (#137) |
| **D2** | Workflow stage ne s'affiche pas côté lecteur dans `/conta` (seul « ativa » + bouton « Cancelar » visibles) | Mineur, ajouter (#138) |
| **D3** | Mail de réception envoyé au lecteur·rice à la création (apparente contradiction principe SIGB R5) | **Décision politique : on garde**. Doctrine à amender en spec v2.2 : SIGB R5 admet exception « accusé de réception explicite » |
| **D4** | Mail à la biblio au scénario 3 (proposition créneau, action initiée par la biblio) | Traçabilité coordination — bonne pratique à inscrire en spec v2.2 |
| **D5** | `consulta_mail_realizada_enabled = false` par défaut | **Cohérent** avec principe « lecteur·rice était présent·e » — à documenter en spec v2.2 |
| **D6** | Spec v2.1 §7.5 mentionne 3 toggles globaux, prod en a 8 (6 fins par event + 2 transverses) | La prod est meilleure que la spec — à corriger en v2.2 (#139) |

---

## Doctrine politique émergée

**Distinction traçabilité individuelle vs traçabilité collective** (réflexion à partir du scénario 9) :

Le principe SIGB R5 (« on notifie qui n'a pas initié ») s'applique à la **personne qui clique**, mais ne couvre pas la **mémoire collective de la coordination**. Dans une biblio militante avec gouvernance horizontale, les autres coordenadores doivent pouvoir voir l'action a posteriori sans avoir à ouvrir le panel.

**Distinction à formaliser en spec v2.2** :
- **Notification individuelle au destinataire principal** : selon principe SIGB R5
- **Trace coordination collective** : à `library_commons.coordination_email` (ou équivalent) pour toutes les actions initiées par le staff biblio sur des consultas

Le toggle `admin_copy_consultas_enabled = true` est probablement le mécanisme correct, à vérifier que le handler `consultas.ts` l'exploite bien.

---

## Conclusion

**Workflow consultations entièrement opérationnel bout-en-bout côté circulation**, mais nécessite **7 fixes ciblés** (un chantier dédié patches consultas, ~1 journée) + **un chantier UX** (~3 jours) pour rejoindre la pleine intention politique de la spec v2.1.

Aucun bug ne bloque la circulation. Les bugs touchent les notifications et le feedback visuel. Le bug le plus politique est **B6** (annulation biblio sans note obligatoire) qui contredit la doctrine collective inscrite dans la spec.

**Prochaine étape recommandée** : chantier « patches consultas » (B1-B7) avec spec v2.2 livrée en fin de chantier pour acter les décisions D3-D6.

---

*Checklist QA déroulée le 15/05/2026. Trace conservée pour les futures sessions de QA.*
