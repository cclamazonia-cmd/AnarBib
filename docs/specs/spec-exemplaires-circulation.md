---
Genre : référence
Statut : 🟡 cadrée (à implémenter — coordonnée #MODEL-item-grain + acquisition)
Décisions : incarne CAT-B1..B7 ; cite DOC-MODELE-1, ITEM-Q1..Q5, ACQ-Q1
Supersédé par : —
---

# Spec — Exemplaires : circulation, visibilité & doublons fédérés

- **Version :** 0.2 (arbitrages B1–B7 actés)
- **Date :** 2026-06-01
- **Statut :** 🟡 Spécification, à implémenter — lot #2 du chantier Catalogação (Q1 du cadrage), **coordonnée** avec `#MODEL-item-grain` et `spec-acquisition-provenance`
- **Périmètre :** la **couche destination** de l'exemplaire (`circulation_policy` + `visibility`), son articulation avec le *padrão* de la fiche, le flux **doublon → exemplaire** fédéré, le filtre catalogue public et les gardes RPC/RLS.
- **Auteur :** Xavier (coordination AnarBib) — rédaction assistée
- **Méthode :** parité fonctionnelle + qualitative + audit doctrinal (même grille que #BIBLIO / Importações / Catalogação)
- **Référence visuelle :** `maquette_fiche_catalogacao_v2.html` (le sélecteur « Circulação local padrão » et la note de visibilité préfigurent §5/§6).

**Dépendances entrantes :**
- `CADRAGE_catalogacao_parite_et_module_capas_2026-06-01` (8.A doublons, 8.D circulation par exemplaire ; Q9, Q10)
- `spec-granularite-item` (`#MODEL-item-grain`) — couche **trace** (item_id sur tous les circuits)
- `spec-acquisition-provenance-v0_1` — couche **provenance** (§5.1 colonnes sur `exemplares`)
- `spec-catalogacao-fiche-et-paliers` v0.2 — le champ fiche « Circulação local padrão » (§5.6)

**Dépendances sortantes :**
- *spec module capas*, *spec sources externes* (lots #3, #4 — sans interaction directe)

---

## 1. Objet & posture

Un exemplaire matériel n'est pas qu'une copie : c'est un objet qui a une **destination** — ce qu'il autorise (prêt ? consultation ? ni l'un ni l'autre, archive ?) et qui peut le voir (lecteur ? équipe seulement ?). Aujourd'hui, AnarBib **ne sait pas** porter cette destination au niveau de l'exemplaire : la circulation est décidée au niveau de la **fiche** (« Circulação local padrão »), ce qui interdit le cas pourtant banal d'une biblio qui réserve certains exemplaires d'un même titre au prêt et d'autres à la consultation.

Cette spec pose la couche manquante : deux attributs durables sur l'exemplaire, `circulation_policy` et `visibility`, le *padrão* de la fiche n'étant plus qu'une **valeur de pré-remplissage** que l'exemplaire peut surcharger. Elle pose aussi le flux **doublon → exemplaire** qui découle directement du modèle fédéré (« une fiche partagée, N exemplaires »).

Posture : sobre et orthogonale. On n'invente pas un workflow de circulation — on ajoute deux propriétés et on les fait respecter par les bons garde-fous.

---

## 2. Les trois couches de l'exemplaire

L'exemplaire se décrit sur trois couches **distinctes et complémentaires**. Deux sont déjà cadrées ; cette spec pose la troisième.

> **Vocabulaire (cf. registre `DOC-MODELE-1`).** Ces trois « couches » sont des **facettes de l'exemplaire** (axe horizontal, au niveau exemplaire). À distinguer des **niveaux de granularité** œuvre → holding → exemplaire (les « Camadas » de `spec-acquisition-provenance`, axe vertical). La couche *provenance* ci-dessous correspond aux propriétés d'acquisition portées à ce niveau.

| Couche | Question répondue | Porteur (colonnes / tables) | Spec |
|---|---|---|---|
| **Trace** | *Quel* exemplaire circule, et *quand* ? | `emprestimo_itens_v2.item_id`, `reserva_linhas_v2.item_id`, `consulta_linhas_v2.item_id` *(ajouté)* | `#MODEL-item-grain` |
| **Provenance** | *D'où vient* l'exemplaire ? | `exemplares.{acquisition_mode, acquisition_date, provenance_note, owner_library, holder_library, partner_source…}` | `spec-acquisition-provenance` §5.1 |
| **Destination** | *Ce que* l'exemplaire autorise, et *qui* le voit ? | `exemplares.{circulation_policy, visibility}` | **cette spec** |

> **Le fil rouge — le cas BTL.** Le compagnon de la Biblioteca Terra Livre a posé l'exemple fondateur : *quatre exemplaires d'un même ouvrage, deux au prêt et deux en consultation.* Il n'est représentable que si les trois couches coexistent : la **destination** (ici) dit « ces deux-là sont `consulta`, ces deux-là `emprestavel` » ; la **trace** (item-grain) dit « c'est l'exemplaire n°3 qui est en consultation en ce moment » ; le **frontend de consultation** (item-grain §6.1) laisse choisir l'exemplaire. Cette spec fournit la première brique.

---

## 3. Périmètre

**Dans le périmètre :**
- Les deux colonnes de destination (`circulation_policy`, `visibility`) sur `exemplares` et `exemplar_drafts`.
- L'articulation *padrão* (fiche) → *seed* → *override* (exemplaire).
- Le flux **doublon → exemplaire** au moment du publish (blocage dur sur ISBN déjà publié dans le réseau).
- Le **filtre catalogue public** et la **matrice d'actions** lecteur (emprunter / consulter / rien).
- Les **gardes RPC/RLS** des écritures de destination et de l'attachement d'exemplaire.

**Hors périmètre (renvoyé ailleurs) :**
- La **trace** transactionnelle et la résolution de disponibilité par exemplaire → `#MODEL-item-grain` (cœur + §6.2).
- La **provenance** et la chaîne d'acquisition → `spec-acquisition-provenance`.
- Le **frontend de consultation** (choix d'exemplaire côté lecteur) → `#MODEL-item-grain` §6.1.
- La logique fine du PEB → `#ILL-availability`.

---

## 4. Modèle cible

### 4.1 Colonnes ajoutées (sur `exemplares` **et** `exemplar_drafts`)

| Colonne | Type | Valeurs | Défaut | Sens |
|---|---|---|---|---|
| `circulation_policy` | `text` + CHECK | `emprestavel` \| `consulta` \| `ambos` | *seed* du padrão fiche | Ce que l'exemplaire autorise |
| `visibility` | `text` + CHECK | `public` \| `staff_only` | `public` | Qui voit l'exemplaire ; `staff_only` = **arquivo** |

> **`text` + CHECK plutôt qu'`enum` PostgreSQL (arbitrage B1, acté)** : ajouter une valeur à un enum PG est une migration lourde et non transactionnelle ; un CHECK est plus simple à faire évoluer et reste contraignant.

`circulation_policy` et `visibility` sont **orthogonaux**, avec une règle : un exemplaire `visibility = staff_only` (arquivo) n'est ni emprunté ni consulté par un lecteur, quelle que soit sa `circulation_policy` (qui reste descriptive de l'usage prévu s'il ressort un jour des archives).

### 4.2 — Backfill de l'existant *(amendé par DOC-CIRC-1, 03/06/2026)*

À la migration, `circulation_policy` est dérivé de l'empruntabilité actuelle de la fiche
(`books.loanable`) :

- fiche **empruntable** → `'ambos'` (prêt **et** consultation sur place) ;
- fiche **non empruntable** → `'consulta'`.

`visibility` est initialisé à `'public'` pour tout l'existant.

> **Note (DOC-CIRC-1).** Le défaut est `'ambos'`, **non** `'emprestavel'` : il préserve
> #consulta-loanable — la consultation sur place reste un droit d'accès par défaut pour
> tout ouvrage en circulation. `'emprestavel'` (prêt-seul, non consultable) ne s'obtient
> que par un choix **délibéré** au niveau de l'exemplaire (cf. §6.1, cas BTL).
---

## 5. Padrão (fiche) ↔ destination (exemplaire)

- La fiche conserve « **Circulação local padrão** » (§5.6 de la spec fiche) à **3 valeurs** alignées sur `circulation_policy` : `emprestavel` / `consulta` / `ambos`.
- Ce padrão **n'est qu'une graine** : à la création d'un exemplaire, sa `circulation_policy` est **pré-remplie** depuis le padrão de la fiche, puis **librement surchargée** par l'équipe sur l'exemplaire.
- **`arquivo` n'est pas un padrão de fiche** : c'est une visibilité par copie (`visibility = staff_only`), réglée sur l'exemplaire, jamais comme défaut de fiche.

---

## 6. Le cas BTL résolu & matrice d'actions

### 6.1 Résolution BTL

« A Conquista do Pão » à la BTL, 4 exemplaires :

| Exemplaire | `circulation_policy` | `visibility` |
|---|---|---|
| ex. 1, 2 | `emprestavel` | `public` |
| ex. 3, 4 | `consulta` | `public` |

Une demande de **prêt** se résout sur un exemplaire `emprestavel` libre ; une **consultation** sur un exemplaire `consulta` libre — **sans que l'une bloque l'autre**. Ce resserrement n'est effectif que lorsque la **trace** (item-grain) fournit l'`item_id` côté consultation (aujourd'hui la règle prudente `#ILL-availability` bloque tout le fonds — cf. item-grain §6.2).

### 6.2 Matrice d'actions lecteur

| Action | Conditions sur l'exemplaire |
|---|---|
| Voir au catalogue public | `visibility = public` |
| Emprunter | `visibility = public` **ET** `policy ∈ {emprestavel, ambos}` **ET** disponible *(trace)* |
| Consulter sur place | `visibility = public` **ET** `policy ∈ {consulta, ambos}` **ET** disponible *(trace)* |
| (aucune — usage interne) | `visibility = staff_only` |

La **disponibilité** (« libre maintenant ? ») reste résolue par `#MODEL-item-grain` ; cette spec ne décide que de l'**autorisé** et du **visible**.

---

## 7. Doublons fédérés (8.A / Q10)

Le réseau suit le modèle **« une fiche partagée, N exemplaires »** : une notice (`books`) est commune au réseau, chaque biblio y rattache ses propres `exemplares` (`owner_library`).

### 7.1 Blocage au publish

- À la **publication** d'un rascunho portant un **ISBN**, si une notice **déjà publiée** dans le réseau porte le **même ISBN normalisé**, la publication est **bloquée dur** (la RPC de publication lève une exception avec `hint` localisé lu par `localizeError`).
- Le frontend affiche alors le bandeau « possível duplicata » (préfiguré dans la maquette) avec les actions :
  - **Abrir a ficha existente** (lecture seule).
  - **Criar um exemplar aqui** → `api.attach_exemplar(book_id, …)` : crée un exemplaire `owner_library = biblio courante` sur la notice partagée, avec sa `circulation_policy` / `visibility` / provenance.
  - **Revisar o ISBN** (fermer pour corriger — cf. B5 ci-dessous).
- **« Revisar o ISBN » (arbitrage B5, acté)** : pas d'échappatoire self-service. Le cas « même ISBN, œuvre vraiment différente » est rarissime (ISBN mal saisi le plus souvent) ; le bouton ferme le bandeau pour corriger l'ISBN. Un override staff justifié reste une **option différée** (si un vrai cas d'ISBN réémis surgit). Le défaut reste **bloquer + rattacher**, jamais un cul-de-sac, jamais une fiche jumelle créée en self-service.

### 7.2 Matériels sans ISBN

Pas de blocage dur pour les types sans ISBN (zine, cartaz, panfleto, dossiê…). Un indice doux sur `titre + autorité` est **possible mais différé** (réflexion ouverte, non bloquant pour Bologne).

---

## 8. Gardes RPC & RLS

- **Écritures par RPC** (doctrine v3) : `circulation_policy` / `visibility` modifiées via la **RPC d'édition d'exemplaire** (arbitrage B4 : intégration plutôt que RPC dédiée — réglées au même moment que le reste de l'exemplaire), jamais via `supabase.from().update()`. Un wrapper « Archiver en un clic » pourra s'ajouter plus tard si besoin.
- **`api.attach_exemplar`** et la garde doublon dans la RPC de publish : `SECURITY DEFINER`, `search_path` fixe, **`REVOKE … FROM PUBLIC, anon, authenticated, service_role`** ; validation de l'appelant = staff actif (`status='active' AND role IN ('librarian','coordenador')` sur `user_library_memberships`).
- **Lecture catalogue public** : filtre `visibility = 'public'` porté par la vue/RLS du catalogue (lecture simple `supabase.from()` admise si protégée par RLS).
- **Tests** : `SET LOCAL ROLE <role>` **+** `SET LOCAL "request.jwt.claims"`, en `BEGIN/ROLLBACK` ; DO-block de chemin critique en contexte anon simulé.

---

## 9. Frontend Catalogação → Exemplaires

- La **destination** se règle dans l'onglet **Exemplaires** de Catalogação (par exemplaire), pas sur la fiche : sélecteur `circulation_policy` (pré-rempli du padrão) + bascule `visibility` (Público / Somente equipe — arquivo).
- Depuis la **fiche**, un lien sortant vers la liste des exemplaires (la fiche ne porte que le *padrão*).
- Le bandeau **doublon** (§7) s'affiche à la tentative de publish, avec ses actions (abrir / criar exemplar / revisar o ISBN).

---

## 10. i18n

- Libellés `circulation_policy` : « Emprestável » / « Somente consulta local » / « Empréstimo + consulta » (les deux premiers existent déjà : `catalogacao.field.loanable`, `catalogacao.ui.consultOnly`).
- Libellés `visibility` : « Público » / « Somente equipe (arquivo) ».
- Bandeau doublon : titre, corps, et les 3 actions (abrir / criar exemplar / **revisar o ISBN**) ; `hint` de l'exception de publish (lu par `localizeError`).
- **8 locales en une passe** (pt-BR, fr, es, it, de, en, ca, eo) ; flat, LF sans BOM, 2 espaces.

---

## 11. Implémentation & rétro-compatibilité

**Ordre de coordination (impératif) :**
1. **`#MODEL-item-grain` cœur** d'abord (item_id partout) — sinon la matrice d'actions §6 ne peut pas se resserrer.
2. **Migration mutualisée** (colonnes provenance + destination) — co-rédigée avec acquisition §5.1, une seule vague.
3. **Padrão → seed → override** : câblage du pré-remplissage + UI destination par exemplaire.
4. **Doublon** : garde au publish (RAISE + hint) + `api.attach_exemplar`.
5. **Filtre public + matrice d'actions** : coordonné avec item-grain §6.2 (resserrement `#ILL-availability`).
6. **i18n** (8 locales) puis **frontend**.

**Rétro-compat :** aucune fiche/exemplaire existant cassé — backfill sûr (`visibility=public`, `policy` dérivé du padrón fiche). `book_holdings` conservé (item-grain Q4).

---

## 12. Risques & vigilance

- **Backfill `circulation_policy`** sur 2 461 exemplaires : un mauvais dérivé fausse la circulation. Mitigation : dériver du champ fiche existant, défaut prudent, DO-block de contrôle.
- **Blocage doublon trop zélé** : un ISBN erroné pourrait bloquer à tort. Mitigation : normaliser l'ISBN, ne bloquer que sur **match exact parmi les notices publiées**, et **toujours** offrir le rattachement (le blocage n'est jamais un cul-de-sac). Inversement, le blocage *est* le comportement voulu pour le cas fédéré (éviter les fiches jumelles).
- **Coordination migration** avec acquisition : deux specs, mêmes tables → **une seule migration co-rédigée**, sinon double vague et risque `relation already exists`. Point de vigilance explicite à la planification.
- **Dépendance d'ordre** : §6 (matrice) inopérante tant que item-grain cœur n'est pas livré. Ne pas livrer §6 isolément.

---

## 13. Liens

- **Cadrage parent :** `CADRAGE_catalogacao_parite_et_module_capas_2026-06-01.md` (8.A, 8.D, Q9, Q10)
- **Couches sœurs :** `spec-granularite-item` (trace), `spec-acquisition-provenance-v0_1` (provenance)
- **Spec fiche :** `spec-catalogacao-fiche-et-paliers` v0.2 (§5.6 padrão)
- **Règle liée :** `#ILL-availability` (resserrement via item-grain §6.2)
- **Référence visuelle :** `maquette_fiche_catalogacao_v2.html`

---

*Fin v0.2. Arbitrages actés : B1 `text`+CHECK ; B2 `ambos` conservé ; B3 `visibility` binaire ; B4 RPC intégrée à l'édition d'exemplaire ; B5 « Revisar o ISBN » (pas d'override self-service, override staff différé) ; B6 migration mutualisée avec acquisition §5.1 ; B7 ordre impératif (item-grain cœur d'abord). Reste à co-rédiger la migration avec acquisition §5.1 au moment de l'implémentation.*
