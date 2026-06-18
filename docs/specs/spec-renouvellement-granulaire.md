---
Genre : référence
Statut : ✅ implémentée en prod (phases 1-5) — référence consolidée a posteriori (18/06)
Décisions : incarne RENOV-1, RENOV-2, RENOV-3 ; cite NPRO-D1/D4, DOC-I18N-1
Supersédé par : —
---

# Spec — Renouvellement granulaire par item

**Statut** : v1.0 — référence (chantier **livré en prod** ; consolidé a posteriori le 18/06).
**Date** : 29/05/2026 (cadrage) · 18/06/2026 (consolidation).
**Origine** : chantier #PAINEL E.3/EA-07 (fusion onglets Empréstimos). En testant la fusion, constat que le bouton « Prolonger » agit sur l'emprunt entier, sans possibilité de prolonger un item précis d'un emprunt groupé.
**Périmètre** : backend (modèle + fonctions de circulation), parcours lecteur (AccountPage), Painel (TabEmprestimos).

> ✅ **LIVRÉ EN PROD — les 5 phases ci-dessous sont implémentées** (vérifié dans le baseline). Compteur par item `emprestimo_itens_v2.renewals_used` (source de vérité ; header `emprestimos_v2.renewals_used` conservé = MAX des items, garde-fou transitoire) ; cœur `public.fn_v2_extend_core(p_emprestimo_id, p_line_nos[], p_require_self_only)` + `fn_v2_extend_emprestimo_item_once` / `fn_v2_extend_emprestimo_once` ; wrappers `api.extend_loan_item_as_library` (staff) / `public.fn_renew_my_loan_item` (lecteur) + leurs variantes « emprunt entier » ; vues `api.my_loans_renewal_status_v1` / `api.staff_loans_renewal_status_v1` ; UI lecteur (AccountPage) + Painel. **Tests** : `tests/sql/paquet_renouvellement_granulaire_tests.sql` (9/9), exécutés en CI (workflow `Tests SQL`). Les points ouverts du §9 sont **clôturés** (voir §9). Le texte des phases est conservé comme **trace de conception**. ⚠️ Le verrou §6.1 (revérification de l'appartenance au renouvellement) s'appuie sur `fn_v2_extend_core` → `fn_membership_can_engage_circulation` (cf. `spec-cotisation` COTIS-5).

---

## 1. Origine et motivation

Le modèle de circulation actuel compte les renouvellements **au niveau de l'emprunt** (`emprestimos_v2.renewals_used`). Les fonctions d'extension (`fn_v2_extend_emprestimo_once` côté staff, `fn_renew_my_loan` côté lecteur) appliquent une nouvelle échéance à **tous les items ouverts** de l'emprunt en une fois, et incrémentent le compteur unique du header.

Conséquence : impossible de prolonger un seul item d'un emprunt groupé sans toucher aux autres. Un workflow alternatif existe (rendre les autres items d'abord via retour partiel, puis prolonger l'emprunt qui ne contient plus qu'un item ouvert), mais il échoue dans le cas frontal « le lecteur veut prolonger un livre précis sans rendre les autres maintenant, qu'il n'a pas avec lui ».

Le modèle de données porte **déjà** l'échéance par item (`emprestimo_itens_v2.due_at` et `extended_until` existent), mais **pas** le compteur de renouvellement par item. C'est ce dernier qu'il faut granulariser.

## 2. Décisions politiques actées (29/05/2026)

**Décision 1 — Quota par item.** Le quota de renouvellement (ex. « 1 renouvellement autorisé » selon la politique de circulation) s'applique désormais **par item**, non par emprunt. Chaque item dispose de son propre compteur et de son propre quota. Cela résout nativement l'incohérence du compteur partagé (prolonger l'item A puis l'item B ne consomme plus deux unités d'un quota commun, mais une unité sur chacun).

**Décision 2 — Granulaire des deux côtés.** Le renouvellement par item est offert **au lecteur** (depuis son compte) **et au staff** (depuis le Painel). Le lecteur conserve aussi une action « tout renouveler » pour le confort, mais peut désormais renouveler livre par livre.

## 3. Modèle de données cible

Ajout d'une colonne de comptage au niveau item :

- `emprestimo_itens_v2.renewals_used integer NOT NULL DEFAULT 0`

Le header `emprestimos_v2.renewals_used` est **conservé** transitoirement comme valeur de compatibilité (cache = MAX des items, ou déprécié à terme), pour ne pas casser d'un coup les vues et fonctions non encore migrées. La cible à terme est que la source de vérité du quota devienne le compteur par item ; le header pourra être retiré dans une phase ultérieure une fois tous les consommateurs migrés.

Colonnes déjà présentes et réutilisées telles quelles (aucun changement) : `emprestimo_itens_v2.due_at`, `emprestimo_itens_v2.extended_until`, `emprestimo_itens_v2.extension_note`.

## 4. Inventaire d'impact

Recensé le 29/05/2026 par audit des références à `renewals_used`.

### 4.1 Fonctions (14)

| Fonction | Rôle | Action prévue |
|---|---|---|
| `public.fn_v2_extend_emprestimo_once` | Extension staff (emprunt entier) | Refondre : boucle par item, incrémente compteur par item |
| `public.fn_renew_my_loan` | Renouvellement lecteur (emprunt entier) | Refondre idem ; jumeau de la précédente, factoriser un cœur commun |
| **(nouveau)** `public.fn_v2_extend_emprestimo_item_once` | Extension d'un item précis | Créer |
| `api.extend_loan_as_library` | Wrapper staff emprunt | Conserver (délègue au cœur, mode « tous items ») |
| **(nouveau)** `api.extend_loan_item_as_library` | Wrapper staff item | Créer |
| `api.get_due_date_after_renewal` | Calcul nouvelle échéance + quota restant | Alimenter avec `renewals_used` par item ; logique interne probablement inchangée (prend déjà `p_renewals_used` + `p_quantity` en paramètres) |
| `api.get_remaining_renewals` | Quota restant | Adapter pour raisonner par item |
| `api.get_due_date_for_loan` | Échéance courante | Vérifier dépendance au compteur |
| `api.get_batch_loan_projection` | Projection au comptoir | Vérifier ; alimente la preview de sortie |
| `api.get_future_availability` | Disponibilité future | Vérifier dépendance |
| `api.resolve_circulation_rule` | Résolution règle | Vérifier ; cœur du moteur de règles |
| `public.fn_v2_create_emprestimo_by_holdings` | Création emprunt | Initialiser `renewals_used` par item à 0 |
| `public.fn_v2_convert_reserva_linhas_to_emprestimo` | Conversion réservation→emprunt | Idem init par item |
| `public.fn_v2_create_consulta_local_by_holdings` | Création consultation | Vérifier (consultation ≠ emprunt, possible faux positif) |
| `public.fn_v2_create_reserva_by_holdings` | Création réservation | Vérifier (faux positif probable) |
| `public.trg_emprestimo_sync_extended_once` | Trigger sync `extended_once` | Adapter à la logique par item |
| `public.trg_notify_emprestimo_prorrogacao` | Trigger notification prolongation | Vérifier le déclenchement par item vs emprunt |

### 4.2 Vues (4)

| Vue | Lue par | Action prévue |
|---|---|---|
| `api.my_loans_renewal_status_v1` | AccountPage (statut renouvellement lecteur) | Exposer le compteur + quota par item |
| `api.staff_loans_renewal_status_v1` | Painel | Idem côté staff |
| `api.my_loans_history_v1` | AccountPage (historique) | Vérifier ; affichage seul, faible risque |
| `api.painel_loans_history_v1` | Painel (historique) | Idem |

## 5. Découpage en phases

Chaque phase est livrable, testable, et poussée + validée Woodpecker avant la suivante (discipline de clôture itérative habituelle du projet).

### Phase 1 — Modèle + cœur d'extension (backend)
- Migration : `ALTER TABLE emprestimo_itens_v2 ADD COLUMN renewals_used integer NOT NULL DEFAULT 0`.
- Copie des données existantes : `renewals_used` du header propagé sur chaque item ouvert.
- Factorisation d'un cœur commun `fn_v2_extend_core(p_emprestimo_id, p_line_nos integer[] DEFAULT NULL, p_actor_kind text)` :
  - `p_line_nos = NULL` → tous les items ouverts (comportement « emprunt entier »).
  - `p_line_nos = {n}` → seulement cet item.
  - Le quota et la nouvelle échéance sont évalués **par item** ; un item dont le quota est épuisé est ignoré et signalé dans le retour JSON (`skipped`), les autres sont étendus.
  - Incrémente `emprestimo_itens_v2.renewals_used` du/des item(s) traité(s).
- Réécriture de `fn_v2_extend_emprestimo_once` et `fn_renew_my_loan` comme appelants du cœur (mode « tous items »).
- Nouvelle `fn_v2_extend_emprestimo_item_once` (mode « un item »).
- Wrappers `api.extend_loan_as_library` (conservé) + `api.extend_loan_item_as_library` (nouveau).
- Doctrine SECURITY DEFINER : REVOKE/GRANT explicites + DO-block de vérification.
- **Garde-fou** : le header `emprestimos_v2.renewals_used` est maintenu synchronisé (= MAX des items ouverts) pour ne pas casser les consommateurs des phases suivantes.

### Phase 2 — Vues + moteur de règles
- Adapter `api.get_remaining_renewals` et le cas échéant `get_due_date_after_renewal`, `get_due_date_for_loan`, `resolve_circulation_rule`, `get_batch_loan_projection`, `get_future_availability` pour lire le compteur par item.
- Adapter les 4 vues (`my_loans_renewal_status_v1`, `staff_loans_renewal_status_v1`, `my_loans_history_v1`, `painel_loans_history_v1`) pour exposer le statut par item.

### Phase 3 — Parcours lecteur (AccountPage)
- Nouveau RPC consommé : `fn_renew_my_loan_item(p_emprestimo_id, p_line_no)` (ou paramètre optionnel sur l'existant).
- AccountPage : bouton « Renouveler » par item (en plus du « tout renouveler » conservé), avec affichage du quota restant par item issu de `my_loans_renewal_status_v1`.

### Phase 4 — Painel (TabEmprestimos)
- Handler `extendLoanItem(empId, lineNo)` dans PanelPage.
- Bouton « Prolonger » sur chaque sous-ligne du bloc déplié (à côté de « Devolver »), affiché si l'item est `aberto` et éligible (quota non épuisé).
- Le bouton « Prolonger » de la ligne maîtresse continue d'étendre tous les items ouverts éligibles (mode « tous items »).

### Phase 5 — Tests
- QA manuelle : renouvellement global lecteur, renouvellement item lecteur, extension globale staff, extension item staff, quota épuisé sur un item (signalé, les autres passent), conversion réservation→emprunt (init compteur par item), emprunt en retard (refus), réservation concurrente (refus).
- Vérification DB par requêtes ciblées sur `renewals_used` par item.

## 6. Stratégie de migration des données

Au moment de l'ajout de colonne, propager la valeur du header sur les items **ouverts** uniquement (les items déjà rendus n'ont plus de pertinence de renouvellement) :

```sql
UPDATE emprestimo_itens_v2 i
   SET renewals_used = e.renewals_used
  FROM emprestimos_v2 e
 WHERE i.emprestimo_id = e.id
   AND i.item_status = 'aberto'
   AND COALESCE(e.renewals_used, 0) > 0;
```

Les items rendus conservent le `DEFAULT 0` (sans incidence puisqu'ils ne sont plus renouvelables).

## 7. Sémantique de l'extension « tous items »

L'extension globale (emprunt entier) devient une **boucle d'extensions par item**. Chaque item est évalué indépendamment contre son propre quota :

- Items éligibles → étendus, compteur item incrémenté.
- Items au quota épuisé → ignorés et listés dans le retour (`skipped` avec la raison).

Cohérent avec l'esprit « signalement par catégorie » adopté pour les retours (BUG-retour-partiel-faux-succès, EA-03) : une action de masse ne doit jamais échouer silencieusement ni masquer un sous-ensemble non traité.

## 8. Risques et points d'attention

- **Cœur de circulation en production.** 14 fonctions + 4 vues, déploiement unique via Woodpecker par phase. Chaque phase doit passer `npm run build` (front) et le DO-block de vérification (backend) avant push.
- **Faux positifs de l'inventaire.** `fn_v2_create_consulta_local_by_holdings` et `fn_v2_create_reserva_by_holdings` référencent `renewals_used` mais concernent consultations/réservations — à vérifier, possiblement hors périmètre.
- **Cohérence header/item pendant la transition.** Tant que des consommateurs lisent le header, maintenir la synchronisation header = MAX(items ouverts). Ne retirer le header qu'après migration complète de tous les consommateurs (phase ultérieure, hors de ce chantier).
- **Doctrine migration.** Fichier dans `supabase/migrations/` avec timestamp futur, push, application par Woodpecker. Jamais d'`apply_migration` via MCP ni de SQL collé en éditeur avant push.
- **Triggers.** `trg_emprestimo_sync_extended_once` et `trg_notify_emprestimo_prorrogacao` doivent rester cohérents : une prolongation par item doit-elle notifier ? Probablement oui, mais à arbitrer en phase 2.

## 9. Points ouverts — clôturés (état livré)

- **Header `renewals_used` (RENOV-1) — clôturé : conservé comme cache transitoire.** Le header `emprestimos_v2.renewals_used` est **maintenu = MAX des items ouverts** (commentaire SQL en prod) ; la source de vérité du quota est le compteur **par item** `emprestimo_itens_v2.renewals_used`. Retrait éventuel du header = phase ultérieure, une fois tous les consommateurs migrés.
- ~~La notification de prolongation doit-elle distinguer « prolongation d'un item » de « prolongation de l'emprunt » ?~~ **Résolu** par le chantier #NOTIFY-prorrogacao (clos 30/05) : émission **par item** depuis `fn_v2_extend_core`, trigger header `trg_notify_emprestimo_prorrogacao` **retiré**, texte « par exemplaire » × 8 locales. Cf. `spec-notify-prorrogacao-granulaire` D1/D4/D5 (registre `NPRO`).
- **Bouton « tout renouveler » (RENOV-3) — clôturé : cohabitation livrée.** Le lecteur·rice garde « tout renouveler » **et** le renouvellement par item (Décision 2).
