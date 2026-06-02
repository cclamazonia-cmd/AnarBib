---
Genre : référence
Statut : 🟡 cadrée (arbitrages à confirmer)
Décisions : incarne ACQ-Q1..Q4 ; cite DOC-MODELE-1, CAT-B6, DOC-DEPLOY-1, DOC-RPC-3
Supersédé par : —
---

# Spec — Acquisition & provenance

- **Version :** 0.1 (cadrage)
- **Date :** 2026-06-01
- **Statut :** 🟠 Cadrage — arbitrages Q1–Q6 à confirmer avant toute migration
- **Périmètre :** chaîne d'entrée en collection (desiderata → réception → provenance de l'exemplaire), articulation avec Catalogação et Importações
- **Auteur :** Xavier (coordination AnarBib) — cadrage assisté
- **Méthode :** parité fonctionnelle + qualitative + audit doctrinal (même grille que #BIBLIO / Importações / Catalogação)

---

## 1. Constat — pourquoi maintenant

L'acquisition (constitution du fonds) est une fonction vitale d'une bibliothèque
et n'avait jamais été cadrée dans AnarBib. L'intuition initiale — « un ou deux
modules dans Importações suffiraient-ils ? » — s'est révélée fausse après audit :
le problème n'est pas un trou à combler, mais une **capacité latente, jamais
câblée, et logée au mauvais étage du modèle documentaire**.

Le chantier arrive au bon moment : la méthode parité+audit doit s'étendre à
Importações puis Catalogação, or l'acquisition est précisément la couture entre
ces deux pages. La poser maintenant évite de recâbler deux fois.

---

## 2. Audit de l'existant (schéma de production, 2026-06-01)

État réel mesuré sur le projet de prod (`uflwmikiyjfnikiphtcp`, sa-east-1) :

| Constat | Mesure |
| --- | --- |
| Notices publiées (`books`) | 2 450 |
| Notices avec `acquisition_mode` renseigné | **0** |
| Notices avec `provenance_note` renseignée | **0** |
| Exemplaires (`exemplares`) | 2 461 |
| Holdings (`book_holdings`) | 2 451 → quasi mono-exemplaire (×1,004) |
| Lots de catalogage (`catalog_batches`) | 7 |
| Brouillons (`book_drafts`) | 497 |
| Wishlist lecteur (`user_wishlist`) | 1 |
| Bibliothèques | 3 |

### 2.1 Le vocabulaire de provenance existe déjà — et il est riche

Présent **à l'identique** sur `book_drafts` et `books` (publié) :
`acquisition_mode`, `acquisition_date`, `provenance_note`, `owner_library`,
`holder_library`, `partner_source`, `source_record_id`, `source_record_url`,
`source_label`, `catalog_source`, `mutualization_status`, `import_format`,
`import_method`.

Référentiel `catalog_ref_acquisition_modes` (actif, `code` / `label` / `sort_order` / `is_active`) :

| code | label (pt-BR) |
| --- | --- |
| `donation` | Doação |
| `purchase` | Compra |
| `exchange` | Troca |
| `deposit` | Depósito |
| `long_loan` | Empréstimo longo |
| `transfer` | Transferência |
| `external_import` | Importação externa |

> Note : `external_import` comme *mode d'acquisition* fait littéralement le pont
> import ↔ acquisition — la couture est déjà pensée dans le référentiel.

### 2.2 La provenance est au niveau **notice**, pas **exemplaire**

`exemplares` ne porte **aucun** champ d'acquisition : `id`, `bib_ref`, `tombo`
(NOT NULL), `shelf_location`, `label_*_override`, `notes`, `library_id`,
`holding_id`. La provenance vit donc sur `books` (Camada 1, l'œuvre partagée),
pas sur l'objet physique (Camada 3).

### 2.3 La machinerie d'import est mature et séparée

`partner_source_records` / `partner_source_items` / `partner_source_holdings`,
`catalog_partners` (+ `_capabilities`, `_probe_runs`), `book_draft_import_events`,
`catalog_ref_source_partners` / `_source_systems` / `_source_formats` /
`_import_methods`. C'est le back-end d'Importações : ingestion de **données**
bibliographiques depuis sources externes/partenaires, périmètre **réseau**
(page `restricted` aux coordinateur·rices). Distinct de l'acquisition locale.

### 2.4 L'amont (desiderata) et la réception n'existent pas

- `user_wishlist` (1 ligne) : `user_id` + `book_id` + `library_id` + `note`.
  C'est un **marque-page lecteur sur un livre déjà catalogué**, pas une
  proposition d'acquérir un titre absent. ≠ desiderata.
- `catalog_batches` : `published_at`, `published_by`, `status` → lot de
  **publication éditoriale**, pas événement de **réception**.
- `library_requests` : onboarding d'une biblio dans le réseau. Sans rapport.

---

## 3. Diagnostic — les quatre écarts

- **EA-ACQ-1 — Capacité latente non câblée.** Les champs existent mais 0/2450
  les utilise. Le formulaire les expose (« Aquisição e proveniência ») sans
  raison ni geste qui pousse à les remplir. *Le manque n'est pas le champ, c'est
  l'usage.*
- **EA-ACQ-2 — Mauvais étage documentaire.** La provenance est posée sur la
  notice commune (Camada 1, partageable entre biblios), alors qu'elle est une
  propriété de l'exemplaire (Camada 3). Contresens en contexte fédéré : deux
  biblios partageant une notice mais détenant chacune un exemplaire de
  provenance différente ne peuvent pas le distinguer.
- **EA-ACQ-3 — Pas d'amont.** Aucune trace de ce qu'on *souhaite* acquérir, ni
  de la *décision collective* d'intégrer (dimension politiquement structurante
  pour une biblio militante).
- **EA-ACQ-4 — Réception confondue avec publication.** Pas de notion
  d'événement d'entrée (don de N ouvrages le J par X) distincte du lot éditorial.

---

## 4. Arbitrages de cadrage (à confirmer)

### Q1 — Granularité de la provenance : **recommandation = l'exemplaire**

La provenance est une propriété de l'objet physique (ce don précis, cette troca
précise), pas de l'œuvre. Cohérent avec la doctrine des Camadas : Camada 1
(notice) = œuvre partagée → garde `catalog_source` / `mutualization_status`
(propriétés de la *notice*) ; Camada 3 (exemplaire) = objet matériel → reçoit
`acquisition_mode` / `acquisition_date` / `provenance_note` /
`source_library`.

> **Vocabulaire (cf. registre `DOC-MODELE-1`).** « Camadas » = **niveaux de granularité** (œuvre/notice → holding → exemplaire), un axe *vertical*. À ne pas confondre avec les **trois couches** de l'exemplaire — trace / provenance / destination (`spec-exemplaires-circulation` §2) — qui sont des *facettes* du niveau exemplaire (axe horizontal). La couche **provenance** correspond précisément aux propriétés d'acquisition portées au niveau exemplaire (Camada 3).

- **Recommandation :** ajouter les champs d'acquisition à `exemplares` (et
  `exemplar_drafts`). Conserver les champs sur `books` à titre de **valeur par
  défaut / héritage au catalogage** (pré-remplissage de l'exemplaire), puis
  marquer leur usage *acquisition* comme déprécié sur la notice (à terme :
  COMMENT SQL de dépréciation, pas de DROP).
- **Coût de migration : quasi nul** — 0/2450 notice ne porte de donnée
  d'acquisition à déplacer.
- **Alternative (école B) :** rester au niveau notice. Plus simple à court
  terme, mais reconduit EA-ACQ-2 et bloquera le fédéré. **Déconseillée.**

### Q2 — Desiderata : **recommandation = nouvel objet léger, library-scoped**

Table `acquisition_desiderata` minimale : `library_id`, `status`
(`suggested` → `accepted` → `acquired` / `declined`), texte libre (titre/auteur/
ISBN si connus) + lien optionnel vers `books`/`authors`, `suggested_by`,
`motivation`, horodatages. Pas de tunnel fournisseur (hors réalité militante).

- **Suggestion lecteur** (un·e lecteur·rice propose une acquisition) : **suite**,
  pas cœur. Politiquement résonnant mais non bloquant pour Bologna.
- **Ne pas réutiliser `user_wishlist`** : sémantique différente (marque-page sur
  l'existant). Les garder distincts.

### Q3 — Réception : **recommandation = différer l'événement, cœur minimal**

Ne **pas** surcharger `catalog_batches` (sémantique publication). Pour v1, la
« réception » = renseigner la provenance par exemplaire + note de lot optionnelle.
Un vrai objet `reception_event` (lot de provenance liant origine + date + lot
d'exemplaires résultants) est une **suite**, justifiée quand les dons groupés
deviendront fréquents.

- **Alternative :** créer `reception_event` dès le cœur. Plus complet mais
  alourdit Bologna sans nécessité (mono-exemplaire, 3 biblios).

### Q4 — Placement UI : **confirmé**

- **Ingestion technique** (ISBN/URL/MARC/catalogue partenaire) → reste
  **Importações** (déjà sa vocation, périmètre réseau/coordination).
- **Provenance / entrée en collection** → **Catalogação**, onglet/section
  Exemplaires (Camada 3), là où le `tombo` est déjà saisi.
- **Desiderata** → module léger distinct, en tête de Catalogação ou adossé au
  catalogue ; **pas** dans Importações.
- *Conclusion sur la question d'origine :* Importações héberge une facette (et
  l'héberge déjà), mais n'est pas le centre de gravité de l'acquisition.

### Q5 — Rôle / RBAC : **recommandation**

Saisie de provenance et desiderata = niveau **bibliothécaire** local
(`role IN ('librarian','coordenador')`, `status='active'`), pas réservé
coordination réseau (≠ Importações). RLS par `user_library_memberships`.

### Q6 — i18n : **8 locales en une passe**

pt-BR (défaut), fr, es, en, it, de, ca, eo. Clés plates, LF sans BOM, indent
2 espaces. Le référentiel `catalog_ref_acquisition_modes.label` est en pt-BR
seul aujourd'hui → décider : traduire via clés i18n côté front (recommandé,
`acq.mode.<code>`) plutôt que dupliquer des colonnes `label_xx` en base.

---

## 5. Modèle cible (sous réserve Q1–Q3)

### 5.1 `exemplares` / `exemplar_drafts` — colonnes ajoutées (Q1)

```
acquisition_mode    text     NULL  -- FK logique → catalog_ref_acquisition_modes.code
acquisition_date    date     NULL
provenance_note     text     NULL
source_library      text     NULL  -- biblio/collectif/personne d'origine (troca, don)
```

- Validation `acquisition_mode` ∈ référentiel : trigger ou CHECK via fonction
  (référence croisée → privilégier trigger `SECURITY DEFINER` + `search_path`).
- Héritage : au catalogage, pré-remplir l'exemplaire depuis les champs `books`
  s'ils sont présents (compat ascendante), sinon saisie directe.

### 5.2 `acquisition_desiderata` — nouvelle table (Q2)

```
id              bigint   PK
library_id      uuid     NOT NULL   -- FK libraries
status          text     NOT NULL   -- suggested|accepted|acquired|declined
title_hint      text     NULL
author_hint     text     NULL
isbn_hint       text     NULL
linked_book_id  bigint   NULL       -- FK books (si déjà au catalogue)
motivation      text     NULL
suggested_by    uuid     NULL       -- FK auth.users
created_at      timestamptz NOT NULL
updated_at      timestamptz NOT NULL
resolved_at     timestamptz NULL
resolved_by     uuid     NULL
```

### 5.3 Référentiel des statuts desiderata

Optionnel : `catalog_ref_desiderata_statuses` sur le patron des autres
`catalog_ref_*` (`code`, `label`, `sort_order`, `is_active`). Sinon CHECK simple.

---

## 6. Périmètre — cœur (Bologna) vs suites

**Cœur `#ACQ-grain` :**
1. Migration : ajouter les colonnes d'acquisition à `exemplares` + `exemplar_drafts` (Q1).
2. RPC d'écriture de la provenance d'exemplaire (création + édition).
3. Héritage notice → exemplaire au catalogage (pré-remplissage).
4. Câblage front Catalogação (section Exemplaires) — la provenance devient un
   geste réel, plus un champ mort.
5. `acquisition_desiderata` minimal + RPC + module front léger (Q2).
6. i18n 8 locales (Q6).

**Suites (explicitement hors cœur) :**
- `reception_event` (lot de provenance) — Q3.
- Suggestion d'acquisition côté lecteur·rice.
- Échange réseau d'exemplaires (articulation PEB / `mutualization_status` /
  `library_partnerships`).
- Dépréciation effective de l'usage *acquisition* sur `books`.
- Analytics d'acquisition (entrées par mode/période).

---

## 7. Doctrine d'implémentation (rappels actés)

- **Déploiement :** `git push` → Woodpecker (`supabase db push --linked` +
  `deploy-edge-functions`). **Jamais** `apply_migration` MCP (timestamp
  mismatch), **jamais** SQL Editor avant push, **jamais** CLI manuelle (sauf
  `notify-event`). Migrations horodatées **UTC** — vérifier avant de choisir.
- **RPC v3 :** écritures (insert/update + validation métier) via RPC ;
  `supabase.from()` toléré pour lectures simples sous RLS ; storage hors RPC.
- **Création d'objets v2 :** `REVOKE … FROM PUBLIC, anon, authenticated,
  service_role` sur fonctions privées ; triggers non-DEFINER appelant des
  fonctions DEFINER REVOKE-ées → patcher le trigger en `SECURITY DEFINER` +
  `search_path` figé **avant** le REVOKE ; bloc DO de vérification en fin de
  migration (`RAISE EXCEPTION` = rollback). `CREATE OR REPLACE` qui change la
  signature crée une surcharge → **DROP + CREATE**.
- **RLS :** périmètre par `user_library_memberships` (rôle local) ; tests
  toujours `SET LOCAL ROLE` **+** `SET LOCAL "request.jwt.claims"` en
  `BEGIN/ROLLBACK`.
- **i18n :** 8 locales en une passe, clés plates, LF sans BOM.
- **Méthode :** « close before open » — committer/vérifier chaque paquet avant
  le suivant ; `npm run build` (capté via `& npm run build; $code = $LASTEXITCODE`)
  avant chaque push.

---

## 8. Articulation backlog & risques

- **#60** (import CSV/OPF/JSON) et la cible parité+audit d'Importações : ce
  chantier *clarifie la frontière* import (données, réseau) vs acquisition
  (objet physique, local). À mener en cohérence, pas en concurrence.
- **#58** (refonte Catalogação) : le cœur #ACQ-grain atterrit dans la page
  Catalogação → séquencer avec la cible parité+audit de cette page.
- **Mutualization / PEB :** la provenance d'exemplaire est le socle propre pour
  l'échange réseau futur — à ne pas court-circuiter en restant au niveau notice.
- **Risque principal :** retomber dans l'école B (provenance sur la notice) par
  facilité. Reconduit l'écart fédéral. Trancher Q1 explicitement avant migration.
- **Risque secondaire :** champs morts bis — ajouter des colonnes à `exemplares`
  sans câbler le geste de saisie reproduirait EA-ACQ-1. Le câblage front (cœur §6.4)
  n'est pas optionnel.

---

## 9. Décisions à prendre (avant passage en spec v0.2 / implémentation)

1. **Q1** — Acter l'exemplaire comme étage de la provenance (école A) ? *(reco : oui)*
2. **Q2** — Créer `acquisition_desiderata` au cœur, suggestion lecteur en suite ? *(reco : oui)*
3. **Q3** — Différer `reception_event` en suite ? *(reco : oui)*
4. **Q4** — Placement (Importações = ingestion ; Catalogação = provenance + desiderata) confirmé ?
5. **Q5** — RBAC bibliothécaire local (hors coordination réseau) confirmé ?
6. **Q6** — Traduire les modes via clés i18n `acq.mode.<code>` plutôt que colonnes `label_xx` ?

Une fois Q1–Q6 tranchées, la v0.2 fige le modèle, les signatures de RPC et le
plan de migration (timestamps UTC, bloc DO de vérification).
