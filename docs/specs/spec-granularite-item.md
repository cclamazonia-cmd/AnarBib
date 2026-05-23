# Spécification — Unifier la granularité du modèle sur l'exemplaire (`#MODEL-item-grain`)

**Statut** : spécification, à implémenter
**Chantier** : `#MODEL-item-grain` (backlog v14 — absorbe l'ancien `#J`)
**Date de cadrage** : 23/05/2026
**Nature** : chantier structurel — pierre angulaire du modèle
**Documents liés** : `spec-flux-consultations.md` ; backlog v14.

---

## 1. Problème

Le modèle AnarBib raisonne aujourd'hui à **deux granularités** selon le circuit
de circulation :

- l'**emprunt** (`emprestimo_itens_v2`) et la **réservation**
  (`reserva_linhas_v2`) descendent à l'`item_id` — l'exemplaire matériel,
  l'objet réel ;
- la **consultation** (`consulta_linhas_v2`, `consulta_item_workflow_v2`)
  raisonne au `holding_id` — le fonds, une abstraction de catalogage.

`consulta_linhas_v2` porte `holding_id` (NOT NULL) et `book_id`, mais **aucun
`item_id`**. `consulta_item_workflow_v2` n'a ni l'un ni l'autre (elle s'arrime
par `consulta_id` + `line_no`). L'exemplaire précis concerné par une
consultation n'est donc résolu **nulle part** dans le circuit.

### 1.1 Conséquence

AnarBib ne peut pas dire « tel exemplaire précis est en consultation ». Le cas
soulevé en réunion par un compagnon de la BTL — quatre exemplaires d'un même
ouvrage, deux à l'emprunt et deux en consultation — n'est pas représentable
côté consultation.

Conséquence concrète déjà rencontrée (`#ILL-availability`, 22/05) : la règle de
disponibilité d'un exemplaire pour un PEB a pu être écrite exactement pour trois
circuits sur quatre ; pour la consultation, faute d'`item_id`, elle a dû être
posée de façon volontairement prudente — *une consultation active bloque tout le
fonds*. Cette règle provisoire ne pourra se resserrer que lorsque la
consultation aura un `item_id` ferme.

### 1.2 Pourquoi maintenant — l'enjeu fédéré

État au 23/05/2026 : sur 2451 holdings, **2444 n'ont qu'un seul exemplaire**, 7
en ont deux, aucun davantage. Autrement dit, dans 99,7 % des cas, « le holding »
et « l'exemplaire » désignent aujourd'hui la même chose physique.

C'est précisément ce qui a permis au modèle de fonctionner jusqu'ici en
confondant les deux niveaux — et c'est le piège. La fédération du réseau va
faire éclater ce ratio : lorsque plusieurs bibliothèques apporteront chacune
leur propre exemplaire d'un même ouvrage (p. ex. *Dieu et l'État* de Bakounine),
un holding portera couramment plusieurs exemplaires. Raisonner par exemplaire
cessera d'être une finition pour devenir la condition de cohérence du catalogue
fédéré. Le point névralgique est l'onglet « exemplaires » de la page
Catalogação : c'est là que la granularité `item` doit être irréprochable.

Le chantier doit donc être mené **avant** que le réel rende le défaut visible
partout, pas après.

---

## 2. Objectif

Faire raisonner le circuit consultation à l'exemplaire (`item_id`), comme
l'emprunt et la réservation. Concrètement : doter `consulta_linhas_v2` d'un
`item_id`, et adapter le circuit en conséquence.

---

## 3. Le modèle cible

Patron de référence — `emprestimo_itens_v2` (contraintes existantes) :

- FK `item_id → exemplares(id)` en `ON DELETE RESTRICT` : un exemplaire engagé
  dans une circulation ne peut pas être supprimé. C'est la **référence forte**.
- FK `holding_id → book_holdings(id)` en `ON DELETE SET NULL` : le fonds est une
  **référence de confort** (regrouper, afficher, requêter par fonds).

`consulta_linhas_v2` doit adopter ce patron : gagner `item_id` comme référence
forte, **conserver** `holding_id` comme référence de confort (arbitrage Q4 —
on ne retire pas `holding_id`).

---

## 4. Arbitrages de cadrage (23/05/2026)

### Q1 — `item_id` obligatoire : **école A**

`consulta_linhas_v2.item_id` sera **NOT NULL**. Toute consultation vise un
exemplaire précis. Motif : l'objectif du chantier est d'*unifier* la
granularité ; laisser `item_id` nullable maintiendrait un circuit à demi au
`holding` et empêcherait le resserrement de la règle de disponibilité. La
consultation rejoint pleinement le modèle emprunt/réservation.

### Q2 — l'exemplaire est choisi par **la bibliothèque**

C'est la **bibliothèque** (le personnel), et non le lecteur, qui désigne
l'exemplaire précis. Reste à préciser à l'implémentation le moment exact dans
le circuit : à la création de la consultation, ou à une étape de validation
précoce. Compte tenu de l'école A (`item_id` NOT NULL dès la ligne), l'exemplaire
doit être résolu **au plus tard à l'insertion de la `consulta_linha`**. Si le
circuit permet au lecteur de formuler une demande « sur le titre » avant
qu'un·e bibliothécaire ne la concrétise, alors la résolution de l'exemplaire est
l'acte par lequel la bibliothèque transforme la demande en `consulta_linha` —
à cadrer finement en lisant les RPC de création du circuit.

### Q3 — migration des 30 lignes existantes : **résolution automatique**

État : 30 consultations, 30 lignes, 30 workflows, dont **2 lignes actives**. 28
sont closes (annulées / consultées / expirées).

Méthode : pour chaque `consulta_linha`, déduire `item_id` du `holding_id`.
- Holding mono-exemplaire (cas quasi général) : `item_id` = l'unique exemplaire,
  sans ambiguïté.
- Holding multi-exemplaires (7 holdings à 2 exemplaires) : cas ambigu. Le script
  de migration les **signale** pour traitement manuel. Vu les volumes (2 lignes
  actives seulement), il y a probablement zéro consultation tombant sur ces 7
  holdings — à vérifier au moment de la migration.

Le script de migration résout automatiquement les holdings mono-exemplaire et
liste les éventuels cas ambigus. Pour les lignes closes dont le holding serait
ambigu, un `item_id` arbitraire parmi les exemplaires du holding est acceptable
(la ligne est close, l'exactitude n'a pas d'enjeu) — à confirmer.

### Q4 — `book_holdings` après le chantier : **conservé**

`holding_id` reste dans `consulta_linhas_v2`, comme référence de confort, à côté
du nouvel `item_id` qui devient la référence forte. On suit exactement le patron
`emprestimo_itens_v2` (`item_id` RESTRICT + `holding_id` SET NULL). On ne retire
`holding_id` d'aucune table. Le `holding` reste une convention utile de
catalogage et de regroupement ; il cesse seulement d'être la maille de
circulation.

### Q5 — périmètre : cœur vs suites

**Cœur du chantier `#MODEL-item-grain`** (cf. §5) : colonne `item_id`, FK,
migration des données, adaptation des RPC du circuit consultation.

**Suites** (cf. §6) — à faire APRÈS, listées explicitement, ne font PAS partie
du cœur : le frontend de consultation (lecteur et bibliothèque), et le
resserrement de la règle de disponibilité `#ILL-availability`.

---

## 5. Périmètre du chantier — le cœur

1. **Colonne `item_id`** ajoutée à `consulta_linhas_v2`, `bigint`.
2. **FK** `item_id → exemplares(id)` en `ON DELETE RESTRICT` (patron
   `emprestimo_itens_v2`).
3. **Migration des données** : script résolvant `item_id` depuis `holding_id`
   pour les 30 lignes existantes (cf. Q3). Cette migration doit précéder la
   pose de la contrainte `NOT NULL`.
4. **Contrainte `NOT NULL`** sur `item_id`, posée APRÈS le remplissage par le
   script — sinon la migration échoue sur les lignes existantes.
5. **Cohérence `item_id` / `holding_id`** : un `CHECK` ou un trigger garantissant
   que l'`item_id` appartient bien au `holding_id` indiqué (l'exemplaire est un
   exemplaire de ce fonds). À trancher à l'implémentation : `CHECK` impossible
   directement (référence croisée entre tables) → probablement un trigger de
   validation, ou la confiance dans les RPC. À cadrer.
6. **RPC du circuit consultation** : les fonctions de création et de workflow
   doivent accepter, valider et propager `item_id`. À recenser à
   l'implémentation (fonctions `fn_consulta_*` ou équivalent) — leur liste n'est
   pas établie dans cette spec, première tâche du chantier.
7. **Bloc `DO`** de vérification en fin de migration (présence de la colonne, de
   la FK, du `NOT NULL` ; aucune ligne avec `item_id` orphelin).

### Ordre d'implémentation impératif

L'ordre est contraint par la contrainte `NOT NULL` :

1. Ajouter la colonne `item_id` **nullable**.
2. Exécuter le script de migration qui remplit `item_id` pour les 30 lignes.
3. Vérifier qu'aucune ligne n'a `item_id` NULL (traiter les cas ambigus).
4. Poser la contrainte `NOT NULL` et la FK.
5. Adapter les RPC.
6. Bloc `DO` de vérification.

Faire l'inverse (NOT NULL avant remplissage) fait échouer la migration.

---

## 6. Suites — hors du cœur, à documenter et à planifier

Ces trois points ne font pas partie du chantier `#MODEL-item-grain` lui-même
mais en sont les conséquences directes. À inscrire au backlog comme items de
suite.

### 6.1 Frontend de consultation

Les écrans du circuit consultation — côté **lecteur** (demande) et côté
**bibliothèque** (traitement, confirmation de créneau) — doivent permettre de
choisir et d'afficher l'exemplaire précis. Tant que ce n'est pas fait, le
frontend continuera de raisonner au `holding` ; les RPC adaptées (cœur, §5.6)
devront accepter un `item_id` que le frontend devra leur fournir — donc le
frontend doit être traité peu après le cœur, sous peine de circuit cassé.
**Dépendance forte : à enchaîner juste après le cœur.**

### 6.2 Resserrement de la règle de disponibilité `#ILL-availability`

Une fois `consulta_linhas_v2` doté d'`item_id`, la règle de disponibilité d'un
exemplaire pour un PEB (`fn_peb_search_exemplares` et la garde de
`fn_peb_create_loan_with_items`) peut être resserrée : une consultation active
ne bloquera plus *tout le holding* mais seulement *l'exemplaire précis*. La
règle actuelle est explicitement provisoire (cf. `spec` / commentaires de la
migration `20260522090000`). Item de suite : remplacer la jointure
`consulta_linhas_v2.holding_id = e.holding_id` par
`consulta_linhas_v2.item_id = e.id`.

### 6.3 Clarification du rôle de `book_holdings` (réflexion ouverte)

Le chantier acte que le `holding` cesse d'être la maille de circulation pour
n'être plus qu'une convention de catalogage et de regroupement. Une réflexion
plus large sur le rôle exact de `book_holdings` dans le modèle — et son
articulation avec l'onglet « exemplaires » de Catalogação dans le contexte
fédéré — pourra suivre. Pas un chantier en soi à ce stade ; noté pour mémoire.

---

## 7. Volume concerné

- `consultas_locais_v2` : 30 lignes
- `consulta_linhas_v2` : 30 lignes (dont 2 actives)
- `consulta_item_workflow_v2` : 30 lignes
- Holdings : 2451 (2444 mono-exemplaire, 7 à 2 exemplaires)

Volume de migration très faible. Le risque de cas ambigu est minime (2 lignes
actives, 7 holdings multi-exemplaires).

---

## 8. Risques et points de vigilance

- **Ordre NOT NULL / remplissage** : cf. §5. Erreur classique — la contrainte
  doit venir après le script de migration.
- **`consulta_item_workflow_v2`** : la spec ajoute `item_id` à
  `consulta_linhas_v2`. Vérifier à l'implémentation si la table de workflow a,
  elle aussi, besoin de l'`item_id` (elle s'arrime par `consulta_id` + `line_no`
  à la ligne, donc l'`item_id` y est accessible par jointure — a priori pas
  besoin de l'y dupliquer, mais à confirmer en relisant les RPC de workflow).
- **RPC non recensées** : la liste exacte des fonctions du circuit consultation
  à adapter (§5.6) n'est pas dans cette spec. Premier travail du chantier :
  les recenser (`pg_proc` filtré sur `consulta`).
- **Cohérence `item_id`/`holding_id`** : décider tôt du mécanisme de garantie
  (trigger de validation vs confiance RPC) — §5.5.
- **Dépendance frontend** : ne pas livrer le cœur (RPC exigeant `item_id`) sans
  enchaîner rapidement le frontend (§6.1), sous peine de circuit consultation
  cassé en production.
- **Doctrine « tests de vérification »** (`#80`) : bloc `DO` cherchant des
  motifs robustes.
- **Migration de données = script séparé** : suivre la doctrine — pas de SQL
  exécuté à la main avant push ; le remplissage de `item_id` est une étape de
  migration à part entière, horodatée, appliquée par Woodpecker.

---

## 9. Articulation avec les autres chantiers

- **`#ILL-availability`** : `#MODEL-item-grain` débloque le resserrement de sa
  règle de disponibilité (§6.2). Lien de dépendance : availability resserré
  *après* item-grain.
- **`#ILL-lifecycle`** : indépendant. Les deux chantiers ne se croisent pas.
- **Onglet « exemplaires » de Catalogação** : `#MODEL-item-grain` est la
  condition de solidité de cet onglet dans le contexte fédéré (§1.2).
- **`#ILL-archive`** : indépendant.

L'ordre conseillé entre les deux chantiers structurels (`#ILL-lifecycle` et
`#MODEL-item-grain`) n'est pas contraint : ils sont autonomes l'un de l'autre.
`#ILL-lifecycle` est plus circonscrit ; `#MODEL-item-grain` a davantage de
ramifications (suites §6). À l'arbitrage du mainteneur selon l'énergie
disponible et l'urgence ressentie de l'enjeu fédéré.
