# EA-13 — Inventaire du recensement (étape 1 de la méthode)
**Date** : 27/05/2026
**Document de cadrage** : `PAINEL_etat_des_lieux_et_cadrage_EA-13_2026-05-26.docx`
**Méthode** : recensement systématique de PanelPage.jsx (2930 lignes) onglet par onglet,
suivi du crible « est-ce un mot de bibliothéconomie ou d'informatique ? ».

---

## 1. Vrais cas EA-13 confirmés (à corriger)

Quatre points dans le code laissent affleurer une valeur technique brute non-i18n
à l'utilisateur·rice. Tous sont des **fallbacks** sur une valeur de colonne DB.

### Cas A — Réservations file active, colonne « Étape » (ligne 1706)
```jsx
<span ... data-stage={r.workflow_stage_effective}>
  {WORKFLOW_LABELS[r.workflow_stage_effective] || r.item_status || '—'}
</span>
```
**Risque** : si `WORKFLOW_LABELS` ne contient pas la clé `workflow_stage_effective`
(stage inattendu remonté par la DB), fallback sur `r.item_status` brut. Dans la file
active, `item_status` vaut typiquement `'ativa'` → affiché brut.

**Trigger en production** : faible (tous les stages connus sont dans WORKFLOW_LABELS),
mais le fallback est la principale source de jargon possible.

### Cas B — Consultations file active, colonne « Étape » (ligne 1852)
```jsx
<span ... data-stage={c.workflow_stage_effective}>
  {CONSULT_WORKFLOW[c.workflow_stage_effective] || c.item_status || '—'}
</span>
```
**Même schéma que cas A**, sur `CONSULT_WORKFLOW`.

### Cas C — Emprunts groupés, en-tête de groupe (ligne 2004)
```jsx
<div>
  <strong>#{g.emprestimo_id}</strong> · {g.user_name || ...} · {g.items.length} {t({id:'panel.loan.items'},...)} · {t({id:'panel.task.detail.deadline'})}: {fmtD(g.due_at)} · {g.emprestimo_status}
</div>
```
**Le plus grave** : `g.emprestimo_status` est affiché **directement, sans aucune
i18n, sans aucune protection**. Valeurs possibles selon le schéma DB : `'aberto'`,
`'fechado'`, `'cancelado'`, `'arquivado'`. Visible **systématiquement** sur
chaque emprunt groupé (pas un cas de fallback rare).

**Trigger en production** : systématique. C'est le seul cas EA-13 garanti d'apparaître.

### Cas D — Composant StageFilterBar, libellé de pill (ligne 2856)
```jsx
{(labels && labels[stage]) || stage} ({n})
```
**Risque structurel** : si une clé n'est pas dans le dico `labels` passé en prop,
on affiche `stage` brut comme libellé de bouton de filtre. Concerne les pills
des onglets Réservations et Consultations (mêmes dicos que cas A et B).

**Trigger en production** : équivalent à cas A et B (faible, mais possible).

---

## 2. Sources secondaires — risque mineur

### S1 — Tooltip du select des transitions (ligne 1617)
```jsx
const stageList = distinctStages
  .map(st => WORKFLOW_LABELS[st] || st)
  .join(', ');
```
Utilisé dans un `title=` (tooltip) d'option `<option>` désactivée. Fallback brut
visible seulement au survol d'une option grisée. Marginal.

### S2 — Historique emprunts, colonne « Type » (ligne 2489)
```jsx
{t({ id: `panel.history.type.${e.loan_type}`, defaultMessage: e.loan_type })}
```
Fallback `defaultMessage` vers `loan_type` brut. Les deux valeurs connues
(`groupe`, `uni`) ont leur clé i18n. Risque marginal sur valeurs inattendues.

### S3 — Genre lecteur (ligne 2053)
```jsx
{readerProfile.gender ? t({id:`gender.${gender}`, defaultMessage: gender}) : '—'}
```
Mêmes 4 valeurs définies dans le `<select>` plus bas. Risque marginal.

### S4 — Historique résa/consulta, colonne « Statut » (lignes 2347, 2418)
```jsx
{t({ id: `reservation.stage.${r.item_status}`, defaultMessage: r.item_status })}
{t({ id: `consultation.stage.${c.item_status}`, defaultMessage: c.item_status })}
```
Toutes les valeurs terminales d'`item_status` (cancelada_*, expirada,
liberada_para_circulacao, convertida_em_emprestimo, consultada) ont leur clé i18n.
Risque marginal sur valeurs inattendues.

---

## 3. Cas analysés et écartés (faux positifs)

| Zone | Raison de l'écart |
| --- | --- |
| L1424, L1457, L1459 | Compteurs `c.item_status === 'ativa'` → uniquement comparaison, jamais affichée |
| L1498, L1076 | Ternaire i18n explicite pour `tk.status` — défaut logique latent (concluida/cancelada non couverts) mais hors vocabulaire jargonné |
| L1505-1506 | Ternaire i18n complet pour `tk.priority` |
| L1523-1526, L2114-2117, L2653-2659, L2918-2920 | Options `<select>` : chaque `<option value>` a son libellé i18n |
| L1630 | `${s.label} ✗` — `s.label` vient de RES_STAGES (lui-même i18n) |
| L1706, L1852, L1857-1878 | `data-stage`/comparaisons internes — pas affichées |
| L1954 | Ternaire i18n explicite `aberto` → open, sinon → returned |
| L1957, L1999, L2028 | Comparaisons `l.item_status === 'aberto'` — pas affichées |
| L2028 | Ternaire i18n explicite `aberto` → inProgress, sinon → returned |
| L2191, L2211, L2225 | `err.message` brut — message externe (Postgres/Supabase), hors EA-13 |
| L2255 | `${p.amount_paid} ${p.currency}` — donnée standard (BRL, USD), pas du jargon |
| L2585 | Idem — `m.last_currency` |
| L2882 | `tk.kind` — toutes ses valeurs viennent de `t()` (cf. buildDailyTasks) |
| data-stage / data-status / data-type | Attributs CSS HTML, jamais affichés |
| Commentaires JSDoc/inline | Pas affichés à l'utilisateur·rice |
| 67 setters de message d'état (setActionMsg, setLoanMsg, etc.) | Tous wrappés de `t({})` |
| Pas d'`alert()`, `confirm()`, `notifyError()`, `throw new Error()` avec chaîne en dur | Vérifié exhaustivement |

---

## 4. Synthèse — décision pour l'étape 2 (arbitrage)

Le recensement révèle un travail **plus modeste que craint** : EA-05 et EA-09
ont déjà fait un grand ménage. Quatre cas de fallback (A, B, C, D) et quatre
cas marginaux (S1-S4). C'est tout.

**Découpage proposé** : EA-13 reste un seul lot, court. Pas besoin de découper.

**Cas C est l'urgence** : c'est le seul jargon affleurant **systématiquement**
en production. Les trois autres cas principaux (A, B, D) sont des fallbacks
défensifs.

**Approche de fond pour A, B, C, D** : transformer les fallbacks bruts en
fallbacks i18n. Plusieurs stratégies possibles :
1. Ajouter dans les dicos `WORKFLOW_LABELS` / `CONSULT_WORKFLOW` les clés
   manquantes (`ativa`, autres item_status), puis garantir que le fallback
   `|| '—'` n'affleure pas une valeur DB.
2. Passer les fallbacks par `t({id: 'panel.stage.unknown', defaultMessage: '—'})`
   ou similaire — solution simple, propre, mais qui masque l'information.
3. Pour le cas C précisément : ajouter un dictionnaire `EMPRESTIMO_STATUS_LABELS`
   sur le modèle de `WORKFLOW_LABELS` + clés i18n `loan.status.*` (déjà existante
   pour `open` et `returned`, à compléter pour `fechado`, `cancelado`, `arquivado`).

**Question d'arbitrage à trancher** (étape 2) :
- pour les **stages non i18n possiblement remontés** (cas A/B/D), affiche-t-on
  « — » (silence) ou « valeur inconnue » (signalement explicite) ou
  un toast d'erreur (sevoir technique) ?
- pour les **statuts d'emprunt** (cas C), quels mots militants pour
  `aberto/fechado/cancelado/arquivado` en pt-BR + 7 autres langues ?
