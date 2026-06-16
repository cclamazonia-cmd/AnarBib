# Cadrage — Thésaurus matière **v2** : trouvable, multilingue vivant, interopérable

- **Statut :** validé (16/06/2026) — v2 par étapes ; on démarre par le modèle des libellés
- **Date :** 2026-06-16
- **Session :** Fédération — Communs & Entraide
- **Filiation :** prolonge le **v1** (`CADRAGE_thesaurus_matiere_2026-06-15.md`,
  étapes 1→2c livrées) et OPAC-ATL1. Charte relationnelle « la main tendue ».

## 0. En une phrase

Le v1 a donné au thésaurus une **gouvernance** (proposto/ativo, soupape mots-clés,
file d'activation) et un **picker enrichi**. Le v2 le rend **vraiment trouvable**
(synonymes), **multilingue vivant** (édition de libellés par communauté de
langue), **outillé** (suggestions au catalogage), et **interopérable** (SKOS) —
toujours dans l'esprit « ça tend, ça ne saisit pas ».

## 1. Point de départ — ce que le v1 a livré

- `subjects.status` (proposto/ativo/depreciado) + `api.fn_subject_set_status`
  (gate coordination) + onglet **Matière** (file d'activation).
- Picker : badge « proposé », `scope_note` en guidage, drapeau ⚐ « libellé
  manquant dans ta langue ».
- **Deux registres** : `subjects` contrôlé (picker) + champ **Mots-clés** libre.
- `api.search_subjects` → `status` + `scope_note`, exclut `depreciado`.
- `label_i18n` multilingue (10 locales en cours de complétion via Cowork).
- Vademecum « Indexer un sujet » (Communs).

## 2. Les axes v2

### Axe E — Synonymes (la vraie findabilité)
Aujourd'hui le typeahead ne trouve que par **pref label** (un par locale) + slug.
On rate « autodéfense » ↔ « autodefesa », les sigles (CNT, FAI), les variantes
historiques. **Ajouter** `altLabel` (synonymes affichables) + `hiddenLabel`
(variantes de recherche, non affichées).

- **Modèle (décision E1 — ✅ tranchée 16/06)** : colonnes **sœurs**
  `subjects.alt_i18n` + `subjects.hidden_i18n` (`{locale: [synonymes]}`),
  **additives** — `label_i18n` reste les *pref* (zéro casse OPAC / picker /
  export Cowork). Recherche, éditeur et SKOS lisent les trois. *(Écarté :
  transformer `label_i18n` en `{pref, alt, hidden}` — même résultat, mais gros
  rayon de casse [OPAC facettes/nuages/pages, picker, réimport] ; table SKOS
  dédiée — réservée si export RDF prématuré.)*
- `search_subjects` parcourt `pref + alt + hidden` (déjà la forme, à étendre).
- Saisie des synonymes : via l'**éditeur de libellés** (axe H).

### Axe F — Notation CDD (pont vers le vademecum cotation)
Ajouter `subjects.notation text` (code de la **grille CDD anarchiste** du
vademecum cotation). Usage : aide au rangement/tri, lien explicite picker↔cotation,
et — plus tard — navigation OPAC par classe.
- **Décision F1** : juste stocker + afficher, ou aussi navigation OPAC par classe ?

### Axe G — Suggestions assistées au catalogage (« ça tend » injecté)
Proposer des sujets pendant la saisie, que la·le catalogueur·euse **accepte ou
rejette** (jamais imposé). Sources possibles :
- (a) **métadonnées d'import** (sujets OpenLibrary/OAI déjà captés) mappés au tesauro ;
- (b) **livres similaires** (le scoring similar-books persistant existe) → leurs sujets ;
- (c) les **135 livres pré-identifiés** (mémoire indexation-sujets) en amorçage.
- **Décision G1** : quelle(s) source(s) pour le v2 (reco : b + c d'abord, a ensuite).

### Axe H — Écran de gouvernance riche (au-delà de l'activation)
- **Éditeur de libellés multilingue** : remplir/corriger `label_i18n` (pref) +
  `alt_i18n` + `hidden_i18n` par locale (branche le drapeau ⚐ + le workflow
  Cowork). C'est ce qui fait *vivre* le multilingue. **Gate (tranché 16/06) :
  coordination seule** (`fn_is_catalog_coordinator`). L'ouverture aux
  contributeur·rices (qui éditent déjà les *autorités* dans leur langue) sur les
  sujets/mots-clés = **après décision d'une première AG réseau**, pas avant.
- **Fusion de doublons** (l'outil `ate_o3` existe) surfacé en action gouvernée + tracée.
- **Dépréciation avec redirection** : déprécier un terme **réaffecte** ses
  `book_subjects` vers un remplaçant (pas de notice orpheline).
- **Décision H1** : périmètre v2 (reco : éditeur de libellés **d'abord** — c'est
  le cœur vivant ; fusion + redirection ensuite).

### Axe I — Relations associatives (SKOS `related`)
« Voir aussi » entre concepts (Anarcossindicalismo ~ Sindicalismo). Table
`subject_relations(subject_id, related_id, kind)`. UI : « voir aussi » au picker
+ à l'OPAC.
- **Décision I1** : v2 ou v3 ? (reco : v3 — pas bloquant.)

### Axe J — Export SKOS / RDF (interopérabilité)
Sérialiser le tesauro en **SKOS** (Turtle / JSON-LD) en lecture seule, pour
l'échange avec d'autres catalogues anar (CIRA…) et le web sémantique. Un RPC/endpoint.
- **Décision J1** : v2 ou v3 ? (reco : v3, mais le **modèle** doit le permettre
  — d'où l'importance de trancher E1 en gardant la voie SKOS ouverte.)

## 3. Gouvernance (charte — inchangée, étendue)
- L'**éditeur de libellés** est *communautaire* : chaque langue écrit la sienne,
  jamais de traduction d'autorité. Le drapeau ⚐ est l'invitation.
- Les **suggestions** sont « tend » : on propose, on n'impose pas (accept/reject).
- **Fusion / dépréciation / redirection** = actes **gouvernés et tracés**
  (coordination), avec le défaut « oui, et » plutôt que « non ».
- Conçu pour la·le plus précaire : suggestions + libellé dans sa langue +
  vademecum, jamais un référentiel fermé.

## 4. Décisions — tranchées avec Xavier (16/06/2026)
- **E1. ✅ Colonnes sœurs** `alt_i18n` + `hidden_i18n` (additif, zéro casse).
- **F1.** `notation` CDD : stocker + afficher ; navigation OPAC par classe → v3.
- **G1.** Suggestions : **b (similaires) + c (les 135)** d'abord ; import (a) ensuite.
- **H1.** Gouvernance riche : **éditeur de libellés d'abord** ; fusion/redirection ensuite.
- **I1.** Relations associatives → **v3**.
- **J1.** Export SKOS/RDF → **v3** (modèle gardé compatible).
- **Priorité v2 :** ✅ on **démarre par le modèle des libellés** (le plus
  structurant — recherche, éditeur, suggestions, export en dépendent).

## 5. Périmètre — v2 (proposé) vs v3 (différé)
**v2** : (E) synonymes alt/hidden + search étendu ; (H-1) **éditeur de libellés
multilingue** (le cœur vivant, branché sur Cowork/⚐) ; (G) suggestions assistées
(similaires + 135) ; (F) `notation` stockée/affichée.

**v3 (différé)** : fusion/redirection riche ; relations associatives ; export
SKOS/RDF ; navigation OPAC par classe ; suggestions depuis l'import.
