# Dossier d'ouverture — chantier `#MODEL-item-grain`

> ⚠️ **Document supersédé (03/06/2026).** Ce dossier a ouvert une phase qui s'est avérée **déjà livrée en production** : la vérification P0.0 (dump schéma 03/06) a montré que le cœur item-grain **et** la suite `#ILL-availability` étaient déjà en base. Il est **conservé comme trace** du raisonnement à l'instant T (« rien ne sort sans trace »), mais sans valeur opérationnelle. Voir `CLOTURE_MODEL-item-grain_2026-06-03.md`.

> **Genre** : Dossier d'ouverture de chantier (couche *trace*, non-normative).
> **Statut** : 🔵 Supersédé — ouvrait une phase déjà livrée.
> **Décisions citées** : `ITEM-Q1..Q5` (registre §7) · `DOC-DEPLOY-1`, `DOC-DEPLOY-3`, `DOC-OBJ-2`, `DOC-RLS-1`, `DOC-MODELE-1`, `DOC-CLOSE-1` (registre §0).
> **Supersédé par** : `CLOTURE_MODEL-item-grain_2026-06-03.md`

**Spec de référence** : `docs/specs/spec-granularite-item.md` (v1, 23/05/2026 — couche *référence*, fait foi sur le design).
**Place destinée** : `docs/decisions/`.
**Préséance** : ce dossier est une *trace*. En cas de conflit, le registre et la spec priment. On **cite** les IDs de décision, on ne les reformule pas.

---

## 1. Pourquoi ce chantier, maintenant

`#MODEL-item-grain` est la **Phase 0** — la pierre angulaire — du chemin critique du chantier Catalogação (`INVENTAIRE.md` § « Ordre de mise en œuvre »). C'est le nœud du corpus dont l'aval bloqué est le plus profond :

- il lève le garde-fou dur n°2 (« jamais la matrice d'actions par exemplaire avant le cœur `#MODEL-item-grain` ») ;
- il conditionne la **Phase 1** (vague `exemplares` provenance + destination), puis la **Phase 2** (circulation effective + matrice d'actions + filtre catalogue public), puis l'aval lecteur : `spec-catalogue-decouverte` et `spec-notice-autorite-enrichie` (cluster #OPAC), qui consomment le filtre `visibility` ; et le `#ILL-digital` (verrou libre-de-droits sur `visibility`/`CAT-B3`) ;
- il débloque directement le resserrement de `#ILL-availability` (spec §6.2).

Et il est **totalement indépendant de la migration mail #110**. La fenêtre avant le 05/06 (R.6) est donc bien employée ici : rien n'attend Resend. Après R.6, l'attention bascule naturellement vers `#BIBLIO` étape 8 et `#NOTIFY-Painel-acts` — d'où l'intérêt de poser la fondation maintenant.

**Vocabulaire** (`DOC-MODELE-1`) : le chantier opère sur l'axe **vertical** des *Camadas* (granularité œuvre/notice → holding → exemplaire). Il ne touche pas les *couches* (facettes provenance/destination de l'exemplaire) — celles-ci relèvent de la Phase 1.

---

## 2. Périmètre

### 2.1 Le cœur de CE chantier (Phase 0) — `spec-granularite-item §5`

Doter le circuit **consultation** d'une granularité exemplaire, comme l'emprunt et la réservation l'ont déjà. Concrètement, sur la seule table `consulta_linhas_v2` :

1. colonne `item_id bigint` ;
2. FK `item_id → exemplares(id)` en `ON DELETE RESTRICT` (patron `emprestimo_itens_v2`) ;
3. migration des 30 lignes existantes (résolution `item_id` depuis `holding_id`) ;
4. contrainte `NOT NULL` posée **après** le remplissage ;
5. garantie de cohérence `item_id` ↔ `holding_id` (mécanisme à trancher — §4.2 ci-dessous) ;
6. adaptation des RPC du circuit consultation (accepter / valider / propager `item_id`) ;
7. bloc `DO` de vérification en fin de migration.

**Isolement confirmé** : la Phase 0 *référence* `exemplares` (FK) mais ne l'**altère pas**. Elle ne déclenche donc pas le garde-fou « une seule vague sur `exemplares` » (qui ne concerne que la Phase 1). Point d'arrêt naturellement net après le §2.1 + le frontend de suite (§2.3).

### 2.2 Décisions de cadrage déjà actées — *citer, ne pas rejouer*

| ID | Objet | Où c'est tranché |
|---|---|---|
| `ITEM-Q1` | `consulta_linhas_v2.item_id` **NOT NULL** (école A) | registre §7 / spec §4.1 |
| `ITEM-Q2` | L'exemplaire est choisi par la **bibliothèque**, résolu au plus tard à l'insertion de la `consulta_linha` (moment exact à caler en impl.) | registre §7 / spec §4.2 |
| `ITEM-Q3` | Migration des 30 lignes : résolution auto (mono-exemplaire) + signalement des holdings ambigus | registre §7 / spec §4.3 |
| `ITEM-Q4` | `book_holdings` **conservé** (`item_id` fort RESTRICT + `holding_id` confort SET NULL) | registre §7 / spec §4.4 |
| `ITEM-Q5` | Périmètre = cœur (colonne + FK + migration + RPC consulta) ; suites = frontend + resserrement `#ILL-availability` | registre §7 / spec §4.5 |

### 2.3 Suites — *hors cœur*, à inscrire au backlog (`spec §6`)

- **Frontend consultation** (lecteur + bibliothèque) : choisir/afficher l'exemplaire précis. **Dépendance forte : à enchaîner juste après le cœur**, sous peine de circuit cassé en prod (la RPC exigera un `item_id` que le frontend doit fournir).
- **Resserrement `#ILL-availability`** (§6.2) : remplacer la jointure `consulta_linhas_v2.holding_id = e.holding_id` par `… .item_id = e.id` dans `fn_peb_search_exemplares` et la garde de `fn_peb_create_loan_with_items`. Lève la règle provisoire « une consultation active bloque tout le holding ».
- **Clarification de `book_holdings`** (§6.3) : réflexion ouverte, pas un chantier à ce stade.

---

## 3. Ce qui n'est PAS dans ce chantier — hand-off vers la Phase 1

La **vague `exemplares` mutualisée** (provenance acquisition §5.1 + destination `circulation_policy`/`visibility` exemplaires §4.2, `CAT-B1..B6`, `ACQ-Q1`) est la **Phase 1**, distincte. Elle vit dans `spec-exemplaires-circulation` + `spec-acquisition-provenance`, sur une **autre table** (`exemplares`/`exemplar_drafts`).

Garde-fou pour la Phase 1 (à respecter le moment venu) : **une seule migration** combinant provenance ET destination — jamais deux `ALTER exemplares` séparés (sinon `relation already exists` / collision). Co-rédaction obligatoire.

> **Ce dont j'ai besoin pour co-rédiger la Phase 1** (non disponible dans le corpus que j'ai sous la main aujourd'hui) : `spec-exemplaires-circulation` §4.2 (liste des colonnes destination + CHECK) et `spec-acquisition-provenance` §5.1 (liste des colonnes provenance). Fournis-les à l'ouverture de la Phase 1 et je produis la migration unique + le DO-block d'un seul tenant.

---

## 4. Points laissés ouverts par la spec — à trancher à l'ouverture

La spec signale explicitement quatre points « à cadrer à l'implémentation ». Recommandations ci-dessous (à confirmer) :

### 4.1 Inventaire des RPC consultation (spec §5.6) — *tâche n°1*

La liste des fonctions du circuit n'est pas dans la spec. **Première action** : `pg_proc` filtré sur `consulta` (et croisé avec les 5 wrappers `api.*` documentés dans `spec-flux-consultations-v2.2`). Cible : repérer (a) la/les fonction(s) qui **insèrent** une `consulta_linha` (pour y exiger `item_id`), (b) les fonctions de **workflow**. Rien d'autre ne peut être cadré tant que cet inventaire n'est pas fait.

### 4.2 Moment de résolution + mécanisme de cohérence (spec §4.2 + §5.5)

- **Moment** (`ITEM-Q2`) : résoudre `item_id` **à l'insertion de la `consulta_linha`**, côté **staff** (la bibliothèque désigne l'exemplaire). Si le circuit permet une demande lectrice « sur le titre », c'est l'acte staff de concrétisation qui porte la résolution. `item_id` devient donc un **paramètre requis** de la RPC créatrice.
- **Cohérence `item_id` ↔ `holding_id`** : `CHECK` impossible (référence croisée). Reco : faire **dériver `holding_id` depuis `item_id`** dans la RPC créatrice (source unique = `item_id`) → cohérence par construction, pas de classe d'incohérence possible. Trigger de validation seulement si des écritures directes hors-RPC restent possibles — auquel cas `SECURITY DEFINER` + `search_path` figé + `REVOKE` (`DOC-OBJ-2`). Invariant vérifié dans le DO-block de migration.

### 4.3 `consulta_item_workflow_v2` (spec §8)

Reco : **ne pas** y dupliquer `item_id`. La table s'arrime par `consulta_id` + `line_no` ; l'`item_id` est accessible par jointure sur `consulta_linhas_v2`. À confirmer en lisant les RPC de workflow (4.1).

### 4.4 Cas ambigus de migration (spec §4.3)

7 holdings à 2 exemplaires, 2 lignes actives seulement. Vérifier au moment de la migration qu'aucune ligne (active ou close) ne tombe sur ces 7 holdings ; pour une éventuelle ligne **close** ambiguë, un `item_id` arbitraire du holding est acceptable (`ITEM-Q3`). Le script **liste** les ambigus ; il ne devine pas un cas actif.

---

## 5. Plan d'exécution — Phase 0

**Ordre impératif** (contraint par le `NOT NULL`, spec §5) — une seule migration horodatée, appliquée par Woodpecker :

1. `ALTER TABLE consulta_linhas_v2 ADD COLUMN item_id bigint` (**nullable**).
2. Remplissage des 30 lignes : `UPDATE` dérivant `item_id` du `holding_id` (mono-exemplaire) ; `RAISE`/log des ambigus.
3. Vérifier `COUNT(*) WHERE item_id IS NULL = 0` (traiter les ambigus avant de continuer).
4. `SET NOT NULL` + FK `→ exemplares(id) ON DELETE RESTRICT`.
5. (Si retenu en 4.2) trigger de cohérence `SECURITY DEFINER` + `search_path` figé, posé **avant** tout `REVOKE`.
6. Adaptation des RPC (4.1) : `DROP + CREATE` si la signature change (`DOC-OBJ-2`), pas `CREATE OR REPLACE`.
7. Bloc `DO` final : présence colonne + FK + `NOT NULL` ; zéro `item_id` orphelin ; invariant `item_id ∈ holding_id`.

**Discipline de déploiement** (`DOC-DEPLOY-1`, `DOC-DEPLOY-3`) : le remplissage des 30 lignes est une **étape de migration à part entière**, horodatée **UTC** (vérifier avant de choisir le timestamp) — jamais de SQL collé en SQL Editor avant push. `git push` → Woodpecker applique migration + EF. `npm run build` (capture `& npm run build; $code = $LASTEXITCODE`) **avant** chaque push.

**Tests RPC** (`DOC-RLS-1`) : valider les RPC adaptées en `BEGIN/ROLLBACK` avec `SET LOCAL ROLE` **+** `SET LOCAL "request.jwt.claims"` (sinon contexte postgres BYPASSRLS, infidèle).

**Close before open** (`DOC-CLOSE-1`) : committer dès que le cœur backend est fonctionnel ; ne pas laisser de code fonctionnel non commité ; nettoyer scripts/backups à la racine après la phase.

---

## 6. Découpage en paquets

| Paquet | Contenu | Sortie attendue | Statut |
|---|---|---|---|
| **P0.0** | Inventaire RPC consultation (`pg_proc` ~ `consulta`) + lecture des RPC de création/workflow ; trancher 4.2/4.3 | Note de cadrage interne (RPC ciblées, mécanisme cohérence retenu) | 🟢 PRÊT |
| **P0.1** | Migration : colonne nullable → remplissage 30 lignes → vérif → `NOT NULL` + FK → (trigger) → DO-block | Migration verte (Woodpecker), 0 `item_id` NULL | ⬜ |
| **P0.2** | Adaptation RPC création/workflow (`DROP+CREATE`, exige `item_id`) + tests RLS `BEGIN/ROLLBACK` | RPC exigeant `item_id`, tests passants | ⬜ |
| **P0.3 (suite)** | Frontend consultation (lecteur + biblio) — choisir/afficher l'exemplaire ; i18n 8 locales (`DOC-I18N-1`, scripts `.cjs`/UTF-8 `DOC-PS-1`) | Circuit complet en prod, non cassé | ⬜ (à enchaîner) |

> **Point d'arrêt propre** : après P0.2, le backend consultation raisonne à l'exemplaire et la migration est isolée (aucune altération d'`exemplares`). P0.3 (frontend) doit suivre rapidement (dépendance forte) mais peut être planifié sereinement. La Phase 1 (`exemplares`) n'ouvre qu'ensuite, sur fourniture des deux specs couplées (§3).

---

## 7. Garde-fous & critères de clôture

**Garde-fous** : ordre `NOT NULL`-après-remplissage (l'erreur classique) ; migration = fichier horodaté, jamais SQL Editor (`DOC-DEPLOY-3`) ; `DROP+CREATE` sur changement de signature (`DOC-OBJ-2`) ; ne pas livrer P0.2 sans enchaîner P0.3 (circuit cassé sinon, spec §8) ; ne **rien** altérer sur `exemplares` ici (réservé à la vague Phase 1).

**Critères de clôture du cœur** :
- `consulta_linhas_v2.item_id` : présent, `NOT NULL`, FK `RESTRICT`, cohérent avec `holding_id` ;
- 30 lignes migrées, 0 orphelin, ambigus traités ;
- RPC création/workflow exigent et propagent `item_id`, testées RLS ;
- DO-block de vérification passant ;
- frontend consultation (P0.3) livré → circuit non cassé en prod ;
- suites `#ILL-availability` (§6.2) inscrites au backlog comme item de suite distinct.

---

*Fin du dossier d'ouverture `#MODEL-item-grain`. Trace non-normative — la spec `spec-granularite-item.md` et le registre font foi.*
