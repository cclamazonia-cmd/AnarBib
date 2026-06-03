# Clôture & réalignement — `#MODEL-item-grain`

> **Genre** : Note de clôture + réalignement corpus (couche *trace*).
> **Statut** : ✅ Chantier constaté livré en production — 03/06/2026.
> **Décisions citées** : `ITEM-Q1..Q5` (registre §7) · `DOC-MODELE-1`, `DOC-CLOSE-1`.
> **Supersède** : `CHANTIER_MODEL-item-grain_ouverture_2026-06-03.md` (dossier d'ouverture devenu sans objet — voir §4).

**Objet** : constater, preuves à l'appui, que le chantier `#MODEL-item-grain` est **déjà en production** ; réaligner la couche référence (spec, backlog, registre, INDEX/INVENTAIRE) sur cet état.
**Source de la preuve** : dump de schéma de prod `anarbib_schema_03-06-2026.sql` (projet `uflwmikiyjfnikiphtcp`, PostgreSQL 17.6).

---

## 1. Constat

La spec `spec-granularite-item.md` (v1, 23/05) porte « à implémenter » et le backlog v26 (02/06) liste `#MODEL-item-grain` en 🟡 CADRÉ (#MODEL, score 15). Le schéma de prod du 03/06 montre que le **cœur** et la **suite §6.2** sont **livrés**. L'implémentation a atterri entre le 23/05 et le 03/06 **sans réaligner la couche référence** — drift à corriger (d'autant plus notable après la session anti-drift du 02/06).

## 2. Preuves (schéma 03/06)

**Cœur (`spec-granularite-item §5`) — livré :**
- `consulta_linhas_v2.item_id bigint NOT NULL` ; les 30 lignes sont donc migrées (le `NOT NULL` est actif). — `ITEM-Q1` (école A) ✅, `ITEM-Q3` ✅
- FK `consulta_linhas_v2_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.exemplares(id) ON DELETE RESTRICT` — patron `emprestimo_itens_v2` à l'identique.
- `holding_id bigint NOT NULL` conservé comme référence de confort. — `ITEM-Q4` ✅
- `COMMENT ON COLUMN consulta_linhas_v2.item_id` mentionne explicitement `#MODEL-item-grain`.
- Helper `fn_v2_resolve_consulta_exemplar(p_holding_id)` (`SQL STABLE SECURITY DEFINER`, `search_path` figé) : résout **côté serveur** un exemplaire libre du holding en croisant les 4 circuits (emprunt, réservation, PEB, **consultation désormais à l'`item_id`**).
- `fn_v2_create_consulta_local_by_holdings` résout via le helper, **insère `item_id`**, et lève `P0001` si aucun exemplaire n'est libre. La cohérence `item_id`↔`holding_id` est donc **par construction** (résolution depuis le holding) — pas de classe d'incohérence possible. — `ITEM-Q2` réglé.

**Suite §6.2 `#ILL-availability` — livrée :**
- `fn_peb_search_exemplares` joint la consultation par `cl.item_id = e.id` (et non plus `holding_id`), commentaire à l'appui : *« #MODEL-item-grain : jointure a l'item_id (regle resserree — auparavant jointure au holding, faute d'item_id) »*.

**Suite §6.1 (frontend consultation) — dépendance bloquante dissoute :**
- La résolution étant **serveur-depuis-holding**, le frontend continue de passer des `holding_ids` ; le circuit n'est pas cassé (le risque « RPC exige un `item_id` que le front ne fournit pas » n'existe pas). Reste, **non bloquant**, un éventuel geste UX « afficher / choisir l'exemplaire retenu » — qui ne devient pertinent qu'avec la **couche destination** (le fil rouge BTL, `spec-exemplaires-circulation` §6). À traiter dans la Phase 1/2, pas ici.

## 3. État final des arbitrages `ITEM`

| ID | Énoncé | État constaté |
|---|---|---|
| `ITEM-Q1` | `item_id` NOT NULL (école A) | ✅ livré |
| `ITEM-Q2` | Exemplaire choisi par la biblio, résolu à l'insertion | ✅ livré — résolution **serveur** à l'insertion (`fn_v2_resolve_consulta_exemplar`) ; le « moment exact à caler » est réglé |
| `ITEM-Q3` | Migration des 30 lignes | ✅ livré (NOT NULL actif) |
| `ITEM-Q4` | `book_holdings` conservé | ✅ livré |
| `ITEM-Q5` | Cœur + suites | Cœur ✅ ; suite §6.2 ✅ ; suite §6.1 = dépendance dissoute, UX optionnelle reportée Phase 1/2 |

## 4. Actions de réalignement (« le statut est le fil-piège », `DOC-CLOSE-1`)

1. **Backlog** : sortir `#MODEL-item-grain` du tableau actif (#MODEL) → **section E (Acquis)**, daté, mode de clôture = « constaté en prod via schéma 03/06 ».
2. **Spec** : poser une **note de clôture en blockquote** en tête de `spec-granularite-item.md` (chantier livré en prod, cœur + §6.2 ; §6.1 dissoute) — sans toucher au corps. Passe en 🔵 référence historique à l'INDEX.
3. **Registre §7 `ITEM`** : marquer `ITEM-Q2` et `ITEM-Q5` **livrés** (cf. §3) ; les autres déjà ✅.
4. **INDEX / INVENTAIRE** : statut de `spec-granularite-item` 🟡 → 🔵 ; mettre à jour la ligne « Modélisation structurelle ».
5. **Dossier d'ouverture** `CHANTIER_MODEL-item-grain_ouverture_2026-06-03.md` : **sans objet** — superséder (ou supprimer), il ouvrait une phase déjà close.

## 5. Conséquence stratégique

Le cœur étant posé, le **garde-fou n°2** (« jamais la matrice d'actions avant le cœur `#MODEL-item-grain` ») est satisfait. La pierre angulaire restante du chemin critique Catalogação est la **Phase 1 — vague mutualisée `exemplares`** (provenance + destination). Voir `CHANTIER_exemplares-phase1_ouverture_2026-06-03.md`.

---

*Fin de la clôture `#MODEL-item-grain`. Trace non-normative — la spec et le registre font foi une fois réalignés.*
