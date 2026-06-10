# BUG — Réservation en état terminal classée active dans la file

**Date** : 26/05/2026 (session nocturne, reprise du chantier audit UX Painel)
**Statut** : corrigé en production — migration `20260526010000_migration_fix_liberate_no_show.sql`
**Sévérité** : moyenne (incohérence de données, pas de perte ; 1 ligne touchée)
**Révélé par** : chantier audit UX Painel (filtre P1 `item_status = 'ativa'`)

---

## Symptôme

Dans l'onglet Réservations du Painel (BLMF), la réservation 29.1
(« O Anarquismo no Banco dos Reús ») apparaissait dans la file **active** avec
l'étape « Remise en circulation » (`liberada_para_circulacao`). Tenter de
l'annuler via l'interface produisait :

> `Erreur : cancelada_biblioteca refusée depuis liberada_para_circulacao pour rôle coordenador`

Le refus backend était correct (`liberada_para_circulacao` est un état
terminal). Le vrai défaut : une réservation **terminée** restait comptée et
affichée comme **active**.

## Cause racine

Les deux colonnes qui décrivent l'état d'une ligne de réservation viennent de
deux tables distinctes et avaient **divergé** :

- `reserva_linhas_v2.item_status` = `'ativa'`
- `reserva_item_workflow_v2.workflow_stage` = `'liberada_para_circulacao'`

La vue `api.reserva_itens_followup_ui` dérive `workflow_stage_effective` en
priorité depuis la table workflow ; `item_status`, lui, vient de la table des
lignes. La file active (Painel comme espace lecteur) filtre sur
`item_status = 'ativa'` — donc une ligne dont `item_status` ment y reste.

Le trou est dans la fonction de trigger
`trg_auto_liberate_after_no_show_change()` : déclenchée après un no-show, elle
faisait **un seul** `UPDATE`, sur `reserva_item_workflow_v2.workflow_stage`.
Elle ne propageait jamais l'état terminal à `reserva_linhas_v2.item_status`.
Aucune des fonctions qui synchronisent `item_status`
(`cancel_reservation_as_library`, `cancel_my_reservation`, la fonction `CASE`
paramétrée) n'est sur le chemin no-show déclenché par cron.

Chaîne complète du bug :

```
cron fn_detect_no_show_reservations
  → workflow_stage = 'retirada_no_show'
      → trigger trg_auto_liberate_after_no_show
          → workflow_stage = 'liberada_para_circulacao'
          → [FIN — reserva_linhas_v2 jamais touché]
```

## Correctif appliqué

Migration `20260526010000_migration_fix_liberate_no_show.sql`, en une
transaction :

1. `CREATE OR REPLACE` de `trg_auto_liberate_after_no_show_change()` — ajout de
   la propagation à `reserva_linhas_v2`, conditionnée par `item_status = 'ativa'`.
   Ce garde-fou garantit qu'on ne touche que les lignes encore actives :
   no-show → ligne `'ativa'` → propagation ; annulation biblio → ligne déjà
   `'cancelada_biblioteca'` (posée en amont par `cancel_reservation_as_library`)
   → exclue, intacte.
2. `UPDATE` de rattrapage de la résa 29.1 (`reserva_item_id = 19`), idempotent.
3. Bloc `DO` de vérification : `RAISE EXCEPTION` → rollback si la ligne 19
   n'est pas réparée ou s'il subsiste une autre ligne incohérente.

Permissions de la fonction remises en conformité doctrine §5.2 : `REVOKE EXECUTE
... FROM PUBLIC, anon, authenticated, service_role`, sans `GRANT` (fonction
interne de trigger).

## Vérification restante

Le cas `cancelada_biblioteca` du trigger n'a pas produit le bug observé (la
résa 29.1 est un no-show ; une seule ligne incohérente recensée en prod). Le
raisonnement « `cancel_reservation_as_library` pose `item_status` avant la
bascule workflow, donc le `WHERE = 'ativa'` exclut la ligne » repose sur la
lecture du code, **pas sur un test en condition réelle**.

À valider à froid : un cycle complet d'annulation par la bibliothèque, pour
confirmer que la ligne reste bien en `cancelada_biblioteca` et n'est pas
réécrite en `liberada_para_circulacao` par le trigger.

## Leçon

Un audit UX parti d'une remarque sur des onglets encombrés a débusqué une
incohérence de données backend présente depuis plusieurs semaines. Le filtre
`item_status = 'ativa'` introduit par le chantier a agi en révélateur : il a
fait remonter la seule ligne dont `item_status` était faux. Le chantier n'a pas
créé le bug — il l'a rendu visible.

Quand une opération touche deux tables liées (ici workflow + ligne), la
propagation doit couvrir les deux. C'est l'application du même principe que la
doctrine #141.2.E (ordre des UPDATE quand des triggers sont impliqués).
