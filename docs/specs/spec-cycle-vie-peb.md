# Spécification — Cycle de vie du prêt interbibliothèques (`#ILL-lifecycle`)

**Statut** : spécification, à implémenter
**Chantier** : `#ILL-lifecycle` (backlog v14)
**Date de cadrage** : 23/05/2026
**Pré-requis** : aucun. Ce chantier est autonome.
**Documents liés** : `spec-flux-consultations.md` (modèle de référence pour les
machines à états) ; backlog v14 (items `#ILL-lifecycle`, `#ILL-overdue` à créer).

---

## 1. Problème

Le cycle de vie d'un PEB n'est pas verrouillé. Deux manques distincts, mis au
jour par le test du retour partiel (session du 22/05).

### 1.1 Manque A — la propagation `status_global` → `item_status`

Aucun trigger ne propage les changements de `status_global` (l'en-tête du PEB)
vers les `item_status` des exemplaires (`interlibrary_loan_items_v2`). Quand un
PEB passe « expédié » (`status_global = 'emprestado'`), rien ne fait passer ses
exemplaires de `reservado_para_saida` à `emprestado`. Les colonnes
`dispatched_at` et `returned_at` de l'en-tête ne sont jamais renseignées.

Conséquence visible : un mail de retour partiel affiche `reservado_para_saida`
(« réservé au départ ») pour des documents non encore pointés — statut absurde
dans un mail de retour, parce que les exemplaires ne sont jamais passés par
`emprestado`.

### 1.2 Manque B — l'absence de verrouillage des transitions

Rien n'empêche de sauter des étapes. `fn_peb_update_status` exécute
`SET status_global = p_new_status` sans aucun contrôle : n'importe quel statut
peut remplacer n'importe quel autre. On peut pointer un retour sur un PEB jamais
expédié.

### 1.3 Constat sur l'existant

Au 23/05/2026, les 8 PEB en base sont **tous** `devolvido`, **tous** avec
`dispatched_at` ET `returned_at` à NULL. Aucun PEB n'a jamais traversé un cycle
de vie propre : tous ont été créés puis marqués `devolvido` directement. Le
manque est donc systématique, pas accidentel. Ces 8 PEB sont des données de
test sans valeur (cf. §6).

---

## 2. La machine à états

### 2.1 Les huit statuts

`status_global` (CHECK existant `interlibrary_loans_v2_status_chk`) :
`preparacao`, `aguardando_saida`, `emprestado`, `parcialmente_devolvido`,
`em_devolucao`, `devolvido`, `cancelado`, `atrasado`.

### 2.2 Graphe des transitions licites

```
preparacao ──→ aguardando_saida ──→ emprestado ──→ em_devolucao ──→ devolvido
    │                  │                │
    │                  │                ├──→ parcialmente_devolvido ──→ devolvido
    │                  │                │              │
    │                  │                │              └──→ emprestado   (marche arrière)
    │                  │                │
    │                  │                └──→ atrasado ──→ em_devolucao
    │                  │                                 ├──→ parcialmente_devolvido
    │                  │                                 └──→ devolvido
    │                  │
    └──→ cancelado ←────┘
```

Table des transitions autorisées (état courant → états cibles permis) :

| État courant              | Cibles permises                                                         |
|---------------------------|--------------------------------------------------------------------------|
| `preparacao`              | `aguardando_saida`, `cancelado`                                          |
| `aguardando_saida`        | `emprestado`, `cancelado`, `preparacao`                                  |
| `emprestado`              | `em_devolucao`, `parcialmente_devolvido`, `atrasado`, `devolvido`        |
| `atrasado`                | `em_devolucao`, `parcialmente_devolvido`, `devolvido`                    |
| `parcialmente_devolvido`  | `devolvido`, `emprestado`                                                |
| `em_devolucao`            | `devolvido`, `parcialmente_devolvido`                                    |
| `devolvido`               | (état terminal — aucune transition sortante)                             |
| `cancelado`               | (état terminal — aucune transition sortante)                             |

Notes sur les choix (arbitrés au cadrage du 23/05) :

- **`aguardando_saida → preparacao`** : retour au brouillon autorisé (on n'a pas
  encore expédié, on peut vouloir rouvrir la préparation).
- **`emprestado → devolvido` direct** : autorisé. Un PEB dont tous les
  exemplaires sont réglés en une seule fois passe directement à `devolvido`
  sans étape `em_devolucao` (cohérent avec le trigger de consolidation
  existant, qui peut conclure `devolvido` d'emblée).
- **`parcialmente_devolvido → emprestado`** : marche arrière autorisée
  (arbitrage 1a). Permet de corriger un pointage de retour erroné.
- **`atrasado`** : traité comme un statut **manuel** licite depuis `emprestado`.
  Le calcul *automatique* du retard (un PEB `emprestado` dont la `due_date` est
  dépassée est de fait en retard) n'entre PAS dans ce chantier — il fait l'objet
  d'un item séparé `#ILL-overdue` (cf. §7).
- **`cancelado`** : accessible **uniquement** depuis `preparacao` et
  `aguardando_saida` — on annule un prêt qui n'est pas encore parti (arbitrage
  1c). Un PEB déjà `emprestado` ne s'annule pas : il suit le cycle de retour
  (les exemplaires perdus en transit sont marqués `perdido` au pointage).
- **États terminaux** : `devolvido` et `cancelado` n'ont aucune transition
  sortante. Un PEB terminé ou annulé est définitif.
- **Transition « immobile »** (`X → X`, statut inchangé) : tolérée — un UPDATE
  qui ne change pas `status_global` ne doit pas être rejeté (il peut modifier
  d'autres colonnes).

---

## 3. Architecture — deux triggers séparés

Arbitrage 2 et 3a : le verrouillage et la propagation sont portés par **deux
triggers distincts** sur `interlibrary_loans_v2`, séparant la validation (qui
peut annuler) de l'effet de bord (qui s'exécute une fois la transition admise).

### 3.1 Trigger `BEFORE UPDATE` — verrouillage des transitions (manque B)

`trg_peb_validate_status_transition`, `BEFORE UPDATE` sur
`interlibrary_loans_v2`, `FOR EACH ROW`.

- Ne fait quelque chose que si `NEW.status_global IS DISTINCT FROM
  OLD.status_global` (transition immobile tolérée).
- Vérifie que le couple `(OLD.status_global, NEW.status_global)` figure dans la
  table des transitions licites du §2.2.
- Si la transition est illicite : `RAISE EXCEPTION` explicite (nommant l'état
  courant, l'état refusé, et les cibles permises). L'exception annule l'UPDATE.

Ce trigger est le **rempart unique**. Il attrape `fn_peb_update_status`, le
trigger de consolidation `fn_peb_consolidate_loan_status`, et tout UPDATE
direct. `fn_peb_update_status` n'a donc PAS besoin de sa propre validation —
le trigger la couvre. (`fn_peb_update_status` reste inchangée.)

Implémentation recommandée : la table des transitions sous forme d'une
structure interne au trigger (paires autorisées), ou d'une vraie table de
référence `interlibrary_loan_status_transitions`. La seconde forme est plus
auditable et plus facile à faire évoluer ; à trancher à l'implémentation.

### 3.2 Trigger `AFTER UPDATE` — propagation des jalons (manque A)

`trg_peb_propagate_status`, `AFTER UPDATE` sur `interlibrary_loans_v2`,
`FOR EACH ROW`. Ne s'exécute que si `status_global` a changé.

- **Transition vers `emprestado`** (depuis `aguardando_saida`) :
  - poser `dispatched_at = now()` sur l'en-tête si NULL ;
  - passer les `interlibrary_loan_items_v2` du prêt qui sont
    `reservado_para_saida` à `emprestado`.
- **Transition vers `devolvido`** :
  - poser `returned_at = now()` sur l'en-tête si NULL.
- **Transition `parcialmente_devolvido → emprestado`** (marche arrière 1a) :
  - point à trancher à l'implémentation : faut-il « dé-pointer » les
    exemplaires ? Recommandation : NON — la marche arrière du statut global
    n'annule pas les pointages d'exemplaires déjà saisis (un exemplaire
    réglé reste réglé). La marche arrière sert à rouvrir l'en-tête, pas à
    effacer le travail de pointage. À confirmer.

Attention `dispatched_at` / `returned_at` : poser la valeur **seulement si
NULL**, pour qu'une éventuelle correction de statut ne réécrase pas une date de
jalon déjà enregistrée.

### 3.3 Interaction avec le trigger de consolidation existant

`fn_peb_consolidate_loan_status` (sur `interlibrary_loan_items_v2`) recalcule
`status_global` à partir des `item_status`. Ce trigger fait lui-même des
transitions de `status_global` — il sera donc soumis au trigger de validation
§3.1. Vérifier à l'implémentation que **toutes** les transitions que la
consolidation produit (`emprestado → parcialmente_devolvido`,
`emprestado → devolvido`, etc.) sont bien dans la table des transitions
licites. Elles le sont dans le graphe du §2.2 — mais à re-vérifier une fois le
code de consolidation relu.

---

## 4. Périmètre — ce qui est inclus

- Table / structure des transitions licites.
- Trigger `BEFORE UPDATE` de validation des transitions.
- Trigger `AFTER UPDATE` de propagation (`item_status`, `dispatched_at`,
  `returned_at`).
- Vérification de compatibilité avec `fn_peb_consolidate_loan_status`.
- Bloc `DO` de vérification en fin de migration (présence des deux triggers ;
  test qu'une transition illicite est bien refusée en contexte simulé).
- Nettoyage des 8 PEB de test (§6).

## 5. Périmètre — ce qui est exclu

- **Calcul automatique du retard** → item séparé `#ILL-overdue` (§7).
- **Mails intermédiaires en rafale** (arbitrage 5) : un PEB réglé en plusieurs
  pointages émet plusieurs mails. Mis de côté volontairement — à traiter APRÈS
  `#ILL-lifecycle`, quand le comportement réel du cycle verrouillé sera
  observable. Ne pas l'oublier : à réinscrire au backlog v15.
- Toute modification du frontend : ce chantier est entièrement base de données.
  Si le verrouillage révèle que le frontend propose des transitions devenues
  illicites (boutons menant à des sauts d'étapes), un ajustement frontend
  pourra suivre — mais hors de cette spec.

---

## 6. Migration de l'existant

Les 8 PEB actuels sont tous `devolvido` sans jalons — données de test sans
valeur (arbitrage 4). Action : **suppression** des 8 PEB en SQL Editor (rôle
`postgres`, qui bypasse la RLS), avant ou après l'application des triggers,
peu importe. La FK `ON DELETE CASCADE` emporte les `interlibrary_loan_items_v2`.

```sql
-- Nettoyage des PEB de test — SQL Editor, role postgres.
DELETE FROM interlibrary_loans_v2;  -- les 8 sont tous des tests
```

Si certains PEB doivent être conservés pour d'autres essais en cours, restreindre
le DELETE par `id`. À l'implémentation, vérifier d'abord l'état réel
(`SELECT id, status_global FROM interlibrary_loans_v2`) avant de supprimer.

La table repart vierge pour tester le cycle de vie complet sur des PEB neufs.

---

## 7. Item de suite à créer — `#ILL-overdue`

À inscrire au backlog v15.

**`#ILL-overdue`** — calcul automatique du retard d'un PEB. Aujourd'hui le
statut `atrasado` n'est posé par rien (il ne deviendra, après `#ILL-lifecycle`,
qu'une transition manuelle licite). Or un PEB `emprestado` dont la `due_date`
est dépassée *est* en retard, que quelqu'un l'ait marqué ou non. À cadrer : un
job cron qui passe les PEB `emprestado` échus à `atrasado` ? un calcul dérivé à
l'affichage sans toucher `status_global` ? Arbitrage à faire au lancement de
l'item. Score indicatif : moyen.

---

## 8. Ordre d'implémentation recommandé

1. Écrire la table / structure des transitions licites.
2. Écrire le trigger `BEFORE UPDATE` de validation.
3. Relire `fn_peb_consolidate_loan_status` et vérifier que toutes ses
   transitions sont licites ; ajuster la table si besoin.
4. Écrire le trigger `AFTER UPDATE` de propagation.
5. Bloc `DO` de vérification (présence des triggers + refus d'une transition
   illicite en contexte simulé `BEGIN/ROLLBACK`).
6. Pousser la migration ; laisser Woodpecker appliquer.
7. Nettoyer les 8 PEB de test (SQL Editor).
8. Test fonctionnel : créer un PEB neuf, le faire passer par tout le cycle
   (`preparacao → aguardando_saida → emprestado → ...`), vérifier que les sauts
   d'étapes sont refusés et que `dispatched_at` / `returned_at` se posent.

---

## 9. Risques et points de vigilance

- **Le trigger de consolidation pourrait être bloqué par le trigger de
  validation** si une transition qu'il produit n'est pas dans la table licite.
  D'où l'étape 3 ci-dessus, impérative.
- **Ordre des triggers `BEFORE`** : s'assurer qu'aucun autre trigger `BEFORE
  UPDATE` n'entre en conflit. À ce jour `interlibrary_loans_v2` n'a qu'un
  trigger (`trg_interlibrary_loan_enqueue_notifications`, `AFTER`) — pas de
  conflit attendu, mais à reconfirmer à l'implémentation.
- **Doctrine « tests de vérification »** (cf. backlog `#80`) : le bloc `DO`
  doit chercher des motifs robustes — présence des triggers par leur nom exact,
  test de transition réel — jamais une chaîne au format incertain.
- **PEB existants** : ne pas appliquer les triggers en comptant sur l'absence
  de données incohérentes — d'où le nettoyage §6. Si le nettoyage est fait
  APRÈS, un UPDATE sur un des 8 PEB `devolvido` (état terminal) serait refusé
  par le trigger de validation : sans gravité puisqu'on les supprime, mais à
  garder en tête.
