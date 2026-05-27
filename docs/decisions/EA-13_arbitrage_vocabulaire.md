# EA-13 — Arbitrage du vocabulaire (étape 2 de la méthode)
**Date** : 27/05/2026
**À valider avant application** dans PanelPage.jsx + 8 locales.

---

## Clés à créer — 7 clés × 8 locales = 56 entrées

### A. Fallback filet de sécurité (cas A, B, D + S2-S4)

| `panel.stage.unknown` | (sens) Étape ou statut inconnu — n'apparaît qu'en cas de valeur DB imprévue par le frontend |
|---|---|
| pt-BR | Etapa desconhecida |
| fr | Étape inconnue |
| es (Argentine) | Etapa desconocida |
| it | Fase sconosciuta |
| de | Unbekannte Phase |
| en | Unknown stage |
| eo | Nekonata etapo |
| ca | Etapa desconeguda |

**Justification** : terme neutre, sobre, militant accessible. Pas de jargon. Le mot
« étape » (équivalent du « stage » DB) est la traduction naturellement utilisée
dans le reste de l'UI (cf. `panel.table.step` = « Etapa »). Pas de point médian
ni de schwa — le mot n'a pas de genre humain.

---

### B. Cas C — `panel.loan.status.devolvido` (état transitoire de l'emprunt rendu)

| pt-BR | Devolvido |
|---|---|
| fr | Restitué |
| es (Argentine) | Devuelto |
| it | Restituito |
| de | Zurückgegeben |
| en | Returned |
| eo | Redonita |
| ca | Tornat |

**Justification** : alignement strict sur la clé `panel.loan.status.returned` qui
existe déjà avec les mêmes traductions (vérifié ligne à ligne). C'est le même
concept — un item rendu — mais sur le **groupe** d'emprunt entier. En français
militant, « restitué » est légèrement plus respectueux que « retourné » (qui
peut sonner administratif). À noter : la clé déjà présente `panel.loan.status.returned`
dit « Retourné » en fr. **Décision à trancher** : on harmonise sur « Restitué »
(qui serait plus militant) ou sur « Retourné » (cohérence avec l'existant) ?

→ **Ma préférence** : aligner sur l'existant (« Retourné ») pour ne pas créer
de divergence. Le grand chantier de wording militant des mails de #153.D et la
suite logique pourra réviser l'ensemble plus tard.

---

### C. Fallbacks défensifs réservation — pour combler `WORKFLOW_LABELS`

#### `reservation.stage.ativa`
Cas où `item_status='ativa'` affleurerait via le fallback ligne 1706/2347/2856.

| pt-BR | Em curso |
|---|---|
| fr | En cours |
| es (Argentine) | En curso |
| it | In corso |
| de | Laufend |
| en | Active |
| eo | Aktiva |
| ca | En curs |

**Justification** : alignement sur `panel.loan.status.aberto` qui est déjà la
locution « Em curso / En cours / etc. » pour les 8 langues. Pour l'anglais et
l'esperanto, on s'aligne sur le `status.aberto` qui dit « Open / En kurso »
mais « Active / Aktiva » est plus juste sémantiquement pour une **réservation**
(une réservation active ≠ une porte ouverte). Je choisis « Active / Aktiva ».

#### `reservation.stage.re-retirada_agendada`
Stage déprécié (fossile), conservé par sécurité. Ne devrait jamais apparaître à l'utilisateur·rice.

| pt-BR | Retirada reagendada |
|---|---|
| fr | Retrait reprogrammé |
| es (Argentine) | Retiro reagendado |
| it | Ritiro riprogrammato |
| de | Abholung neu geplant |
| en | Pickup rescheduled |
| eo | Reorganizita retiro |
| ca | Recollida reprogramada |

**Justification** : reproduit `reservation.stage.retirada_agendada` qui dit « Retirada
agendada / Retrait planifié / etc. » avec le préfixe « re- » (reprogrammé). Pour
le pt-BR, la clé `reservation.stage.re_retirada_agendada` (sans tiret) existe
déjà avec « Retirada reagendada » : je m'aligne dessus.

#### `reservation.stage.retirada_no_show`
Stage canonique du no-show (le code utilise `nao_retirada` comme alias historique).
Cf. commentaire L148-150.

| pt-BR | Não retirada |
|---|---|
| fr | Non retirée |
| es (Argentine) | No retirada |
| it | Non ritirata |
| de | Nicht abgeholt |
| en | Not picked up |
| eo | Ne retirita |
| ca | No recollida |

**Justification** : alignement strict sur `reservation.stage.nao_retirada` qui
porte exactement ce sens et est déjà traduit dans les 8 locales. Une copie
fonctionnellement identique.

---

### D. Fallbacks défensifs consultation — pour combler `CONSULT_WORKFLOW`

#### `consultation.stage.ativa`

| pt-BR | Em curso |
|---|---|
| fr | En cours |
| es (Argentine) | En curso |
| it | In corso |
| de | Laufend |
| en | Active |
| eo | Aktiva |
| ca | En curs |

**Justification** : identique à `reservation.stage.ativa`.

#### `consultation.stage.consulta_realizada`
Workflow stage technique (état d'une consultation effectivement réalisée).
La clé `consultation.stage.consultada` existe déjà avec « Consultada » côté pt-BR.

| pt-BR | Consultada |
|---|---|
| fr | Consultée |
| es (Argentine) | Consultada |
| it | Consultata |
| de | Eingesehen |
| en | Consulted |
| eo | Konsultita |
| ca | Consultada |

**Justification** : alignement strict sur `consultation.stage.consultada` qui dit
le même concept (état terminal après consultation), avec les mêmes traductions.

---

## Trois questions d'arbitrage avant que j'applique

1. **`panel.loan.status.devolvido` — fr** : on dit « Retourné » (cohérent avec
   `status.returned` qui existe) ou « Restitué » (plus militant) ?

2. **`reservation.stage.ativa` et `consultation.stage.ativa` — en/eo** : on dit
   « Active / Aktiva » (sémantiquement juste pour réservation) ou « Open / En kurso »
   (cohérent avec `panel.loan.status.aberto` qui existe) ?

3. **Pour le reste** (les autres clés) : c'est un alignement direct sur des clés
   existantes ou des paires sœurs. À valider en bloc.

Dès validation, j'applique :
- PanelPage.jsx : 4 patchs (cas A 1706, B 1852, C 2004 + dico EMPRESTIMO_STATUS_LABELS,
  D 2856, S1 1617, S2 2489, S3 2053, S4 2347/2418).
- 8 locales : ajout de 7 clés à chacune (56 entrées au total).
- Validation JSON.parse stricte de chaque locale.
- Mention dans le code des CHECK constraints qui justifient l'exhaustivité.
- npm run build comme quality gate final.
