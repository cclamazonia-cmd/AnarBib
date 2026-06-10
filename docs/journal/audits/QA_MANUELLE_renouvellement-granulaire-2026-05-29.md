# QA MANUELLE — Renouvellement / prolongation granulaires (Phase 5)

**Date :** 2026-05-29
**Chantier :** granularité (ex-EA-14) — backend 1a/1b/2/3a (prod, Woodpecker vert) + front 3b (conta lecteur) + Phase 4 (painel staff) + refonte conta (regroupement par emprunt).
**Bibliothèque :** BLMF (`1234825f-a0f9-4fbd-a875-6551c30ea4ca`)
**Lecteur de test :** Xavier (`d6710372-e5e5-4608-800b-99a26817c677`) — emprunteur de #50 et #51, donc testable des **deux** côtés (conta + painel).

> ⚠️ **Premier vrai test d'exécution du backend.** Jusqu'ici : compilation `_synttest`, simulation de décision, court-circuit d'auth — **jamais** d'écriture réelle. `fn_v2_extend_core` boucle pour la première fois sur de vraies données ici.

## Discipline de test
- **Un scénario à la fois.** Vérifier la DB après chacun avant d'enchaîner.
- Tester en **navigation privée** quand on bascule lecteur/staff.
- Les blocs `-- SETUP` et `-- RESET` sont des **UPDATE de données de test** (pas des migrations) : à coller dans le SQL Editor **délibérément**. La règle « jamais de SQL avant push » vise le **DDL/migrations**, pas les données de test.
- Les blocs `-- VÉRIF` sont en **lecture seule**.

## Points de vigilance (à surveiller pendant toute la QA)
1. **Synchro header** (`trg_sync_header_renewals`) : après renouvellement d'un item, `emprestimos_v2.renewals_used` doit valoir le **MAX** des `renewals_used` des items ouverts.
2. **Bouton « Prolonger » maître post-granulaire** : la ligne maîtresse staff gate sur `extended_once` / `extended_until`. Observer son comportement quand seuls **certains** items d'un lot ont été renouvelés (cas BUG-lote-extend).
3. **Affichage de divergence (conta)** : après renouvellement d'**un seul** item d'un lot, l'en-tête doit basculer sur la **prochaine échéance la plus proche** du lot (les items non renouvelés), pas sur la date renouvelée.
4. **Cohérence conta ↔ painel** : un item renouvelé d'un côté doit apparaître renouvelé de l'autre.

---

## Ligne de base (état réel au 29/05/2026)

| sub_id | book_id | statut | échéance | renew. utilisés | restant | échéance attendue après 1 renew |
|--------|---------|--------|----------|-----------------|---------|----------------------------------|
| 50.1 | 2453 | aberto | 06/07/2026 | 0 | 1 | **13/07/2026** |
| 50.2 | 2321 | aberto | 06/07/2026 | 0 | 1 | **13/07/2026** |
| 50.3 | 2323 | aberto | 06/07/2026 | 0 | 1 | **13/07/2026** |
| 50.4 | 2327 | aberto | 06/07/2026 | 0 | 1 | **13/07/2026** |
| 51.1 | 2330 | aberto | 19/06/2026 | 0 | 1 | **26/06/2026** |

Règle commune : « Base legada — 1 prorrogação de 7 dias » → 1 seul renouvellement possible, +7 jours.
Header #50 et #51 : `renewals_used=0`, `extended_once=false`, `extended_at=null`, non archivés.

**VÉRIF baseline (à relancer entre les scénarios) :**
```sql
select i.sub_id, i.item_status, i.due_at, i.extended_until,
       coalesce(i.renewals_used,0) as item_renew,
       v.can_renew, v.renewals_remaining, v.blocking_reason
from public.emprestimo_itens_v2 i
left join api.staff_loans_renewal_status_by_item_v1 v
  on v.emprestimo_id=i.emprestimo_id and v.line_no=i.line_no
where i.emprestimo_id in (50,51)
order by i.sub_id;

select id, renewals_used, extended_once, extended_at
from public.emprestimos_v2 where id in (50,51);
```

---

## Scénarios

### S1 — Renouvellement PAR ITEM (lecteur · conta)
**Objet :** premier vrai appel `api.renew_my_loan_item`.
**Étapes :** conta → onglet « Empréstimos em curso ». Lot #50 (4 livres). Bouton **Renovar** sur **50.1** uniquement.
**Attendu UI :** alerte « renouvelé jusqu'au **13/07/2026** ». Au reload : 50.1 affiche 13/07 + étiquette « renouvelé », **plus de bouton** sur 50.1 ; 50.2/50.3/50.4 inchangés (06/07, bouton présent). En-tête : échéance la plus proche devient **06/07** (items non renouvelés) — *point de vigilance 3*.
**VÉRIF DB :**
```sql
select sub_id, due_at, extended_until, renewals_used from public.emprestimo_itens_v2
where emprestimo_id=50 order by line_no;
select id, renewals_used from public.emprestimos_v2 where id=50;  -- attendu : 1 (MAX), point 1
```
☐ Résultat : __________

### S2 — Prolongation PAR ITEM (staff · painel)
**Objet :** premier vrai appel `api.extend_loan_item_as_library`. **Résout BUG-lote-extend.**
**Étapes :** painel BLMF → onglet « Empréstimos ». Déplier #50. Bouton **Prorrogar** sur **50.2** uniquement (à côté de Devolver).
**Attendu UI :** toast succès ; au reload, 50.2 → 13/07, bouton Prorrogar disparu sur 50.2 ; les autres inchangés.
**VÉRIF DB :** idem S1 (50.2 → renewals_used=1, extended_until=13/07 ; header reste 1).
☐ Résultat : __________

### S3 — « Renovar tudo » (lecteur · conta, lot entier)
> Pré-requis : repartir de la baseline (`-- RESET` plus bas) pour avoir un lot #50 entièrement renouvelable.
**Étapes :** conta → lot #50 → bouton **Renovar tudo** sur l'en-tête.
**Attendu UI :** alerte « renouvelé jusqu'au 13/07 ». Reload : **les 4 items** → 13/07, tous étiquetés « renouvelé », plus aucun bouton item ni « Renovar tudo » (lot épuisé). En-tête : 13/07.
**VÉRIF DB :** 50.1–50.4 → renewals_used=1, extended_until=13/07 ; header #50 renewals_used=1.
☐ Résultat : __________

### S4 — « Prolonger » ligne maîtresse (staff · painel, lot entier)
> Pré-requis : `-- RESET`.
**Étapes :** painel → #50 → bouton **Prorrogar** de la **ligne maîtresse** (`api.extend_loan_as_library`).
**Attendu UI :** toast succès ; les 4 items → 13/07.
**VÉRIF DB :** comme S3. Observer *point de vigilance 2* : après ce renouvellement de lot, le bouton maître se grise/disparaît au reload (lot déjà prolongé).
☐ Résultat : __________

### S5 — Quota épuisé (1 seul renouvellement autorisé)
> Pré-requis : un item déjà renouvelé (ex. sortie de S1 : 50.1 à renewals_used=1).
**Étapes :** observer 50.1 (déjà renouvelé) côté conta **et** painel.
**Attendu UI :** **aucun** bouton Renovar/Prorrogar sur 50.1 ; étiquette « renouvelé » (conta). `blocking_reason='already_extended'`, `can_renew=false`.
**VÉRIF DB :**
```sql
select sub_id, can_renew, renewals_remaining, blocking_reason
from api.staff_loans_renewal_status_by_item_v1 where emprestimo_id=50 and line_no=1;
```
☐ Résultat : __________

### S6 — Lot mixte : un item inéligible, les autres passent
> Pré-requis : `-- RESET`, puis `-- SETUP overdue` ci-dessous (rend **50.4** échu).
```sql
-- SETUP overdue (mutation données de test)
update public.emprestimo_itens_v2
set due_at = current_date - 1, extended_until = null
where emprestimo_id=50 and line_no=4;
```
**Étapes :** conta → #50 → **Renovar tudo**.
**Attendu UI :** alerte « renouvelé jusqu'au 13/07 ». Reload : 50.1/50.2/50.3 → 13/07 + « renouvelé » ; **50.4 reste échu** (badge « en retard », pas de bouton, date inchangée). Le lecteur voit visuellement que 50.4 n'a pas suivi.
> Limitation connue (non bloquante) : l'alerte « Renovar tudo » ne détaille pas les items ignorés (`skipped`) — l'info passe par l'affichage (badge en retard). Candidat d'amélioration future.
**VÉRIF DB :**
```sql
select sub_id, due_at, extended_until, renewals_used from public.emprestimo_itens_v2
where emprestimo_id=50 order by line_no;  -- 50.1-3 renouvelés, 50.4 non
```
Puis `-- RESET`.
☐ Résultat : __________

### S7 — Item en retard (overdue)
> Pré-requis : `-- RESET`, puis `-- SETUP overdue` sur **51.1** :
```sql
update public.emprestimo_itens_v2
set due_at = current_date - 1, extended_until = null
where emprestimo_id=51 and line_no=1;
```
**Attendu UI :** conta → 51.1 : badge **en retard**, **pas** de bouton Renovar. Painel → idem (pas de Prorrogar). `blocking_reason='overdue'`, `can_renew=false`.
Puis `-- RESET`.
☐ Résultat : __________

### S8 — Réservation concurrente (reserved_by_other) *(optionnel)*
**Principe :** si un **autre** lecteur a une réservation active sur le `book_id` d'un item, cet item devient non renouvelable (`blocking_reason='reserved_by_other'`, pas de bouton).
**Mise en place :** soit réserver le livre via l'UI avec un **second compte**, soit insérer une réservation de test. → **Dis-moi si tu veux ce scénario** : je t'inspecte le schéma `reservas_v2`/`reserva_linhas_v2` et je te fournis le SQL de setup + cleanup exact.
☐ Résultat : __________

### S9 — Conversion réservation → emprunt *(observationnel)*
**Objet :** vérifier qu'un emprunt **issu d'une conversion** démarre à `renewals_used=0` et est renouvelable normalement (le moteur de règle est agnostique).
**Étapes :** dérouler le flux réservation → retrait → conversion en emprunt sur un livre, puis tester un renouvellement par item dessus.
☐ Résultat : __________

### S10 — Cohérence conta ↔ painel
**Étapes :** renouveler 50.3 **côté painel** (Prorrogar), puis ouvrir la **conta** du lecteur.
**Attendu :** 50.3 apparaît renouvelé (13/07 + « renouvelé ») côté conta sans action supplémentaire. Inverse aussi valable (renouveler côté conta → visible côté painel).
☐ Résultat : __________

---

## RESET (retour baseline — mutation données de test)
À exécuter entre les scénarios qui le demandent, et à la fin de la QA.
```sql
-- VÉRIF du périmètre avant d'écrire
select emprestimo_id, line_no, item_status, due_at, extended_until, renewals_used
from public.emprestimo_itens_v2 where emprestimo_id in (50,51) order by 1,2;

-- RESET items
update public.emprestimo_itens_v2
set renewals_used   = 0,
    extended_until  = null,
    extension_note  = null,
    item_status     = 'aberto',
    returned_at     = null,
    due_at          = case emprestimo_id when 50 then date '2026-07-06'
                                         when 51 then date '2026-06-19' end,
    updated_at      = now()
where emprestimo_id in (50,51);

-- RESET headers
update public.emprestimos_v2
set renewals_used = 0, extended_once = false, extended_at = null, updated_at = now()
where id in (50,51);
```
> Si un test de **retour** a positionné des champs `return_schedule_status` / `return_*` ou changé `item_status`, vérifie-les après reset (`item_status='aberto'`, pas de planification de retour résiduelle).

---

## Récapitulatif / sign-off

| # | Scénario | Statut | Notes |
|---|----------|--------|-------|
| S1 | Renew item (lecteur) | ✅ | |
| S2 | Prolong item (staff) — BUG-lote-extend | ✅ | résolu |
| S3 | Renovar tudo (lecteur) | ✅ | |
| S4 | Prolonger maître (staff) | ✅ | |
| S5 | Quota épuisé | ✅ | |
| S6 | Lot mixte (skipped) | ✅ | exerce le chemin overdue→skipped |
| S7 | Overdue (isolé) | ➖ | couvert en substance par S6 ; non rejoué isolément |
| S8 | Réservation concurrente (`reserved_by_other`) | ⏳ | résiduel — chemin de garde non exercé, à confirmer opportunément |
| S9 | Conversion réserva→emprunt | ➖ | observationnel, non joué |
| S10 | Cohérence conta↔painel | ➖ | faible risque (même DB), non rejoué isolément |

**Bugs relevés :**
- **#NOTIFY-prorrogacao** (notification de prorrogação header-centrée, aveugle à la granularité) — diagnostiqué, cadré dans `docs/specs/spec-notify-prorrogacao-granulaire.md`. N'affecte pas le cœur renouvellement (données + UI corrects).
- Affichage painel des échéances effectives — **corrigé** le 29/05 (effective due dans l'en-tête + par item).

**Décision de clôture Phase 5 :** cœur granularité (renouvellement/prolongation par item et par lot, lecteur et staff, quota, lot mixte) **VALIDÉ** sur S1–S6. Résiduels assumés : S8 (`reserved_by_other`) à confirmer plus tard ; S7/S9/S10 à faible risque. Le défaut de notification est traité séparément (chantier B).
