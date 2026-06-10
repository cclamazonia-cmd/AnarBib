# spec — Détection & fusion de doublons (autorités + documents)

> **🔵 Clôture (2026-06-10) — implémentée en production, spec archivée.** Fusion autorités + documents livrée (CAT-H1). Référence historique (corps non modifié). Preuves : [`AUDIT backlog v29 vs prod`](../../journal/audits/AUDIT_backlog-v29-vs-prod_2026-06-10.md).

> **Statut** : mini-spec (à valider) · v0.1 · 2026-06-05
> **Chantier** : qualité du catalogue — repérer et fusionner les fiches en double.
> **Périmètre** : autorités (auteurs) **et** documents (livres). Décision Xavier
> du 05/06 : élargir aux documents dès la spec (implémentation possiblement
> phasée : autorités d'abord, documents ensuite — voir §7).
> **Préséance** : proposition. Le REGISTRE fait foi une fois acté.

## 1. Contexte & besoin

Le catalogue accumule des **fiches en double** :

- **Autorités** : constaté le 05/06, 4 clusters par nom normalisé —
  Castoriadis (10008+10116), Abad de Santillán (24+10036), Cappelletti
  (10027 « Angel » + 10044 « Ángel »), Tolstoï (10108 « Tolstoi » + 10109
  « Tolstói »). La normalisation (`fn_normalize_name`) capte déjà les variantes
  d'accent/ordre/casse. On a dû nettoyer les doublons LENOIR **à la main** (cf.
  migration `20260605220000`) — exactement ce qu'un outil de fusion éviterait.
- **Documents** : doublons par ISBN identique, ou titre+auteur très proches
  (ex. « Educar Para Emancipar » présent en plusieurs notices).

Aujourd'hui, **aucun outil** ne repère ni ne fusionne ces doublons a posteriori.
*(Côté livres, il n'existe qu'un blocage ISBN au moment de publier — CAT-B5 —
mais rien de rétroactif.)*

## 2. Principe

Un bouton **« Doublons possibles »** sur la fiche (auteur **et** document) →
panneau listant les candidats (exact-normalisé + trigramme, badge + score) →
**fusion assistée** : le staff choisit le **canonique**, une RPC réassigne
**toutes** les références du doublon vers le canonique puis supprime le doublon.
**Validation humaine obligatoire** (jamais de fusion automatique : homonymes,
éditions distinctes d'un même titre).

Réutilise l'acquis du chantier liaison : `fn_normalize_name`, `pg_trgm`
(`similarity`, seuil ~0.45), gating staff (librarian/coordenador), trigger de
synchro `book_contributors`→`book_authors`.

## 3. Détection des candidats

### 3.1 Autorités
- Exact : même `fn_normalize_name(preferred_name)` (ou sort_name, variantes).
- Approchant : `similarity` ≥ seuil sur les formes normalisées.
- RPC `suggest_author_duplicates(p_author_id)` → autres autorités au nom
  proche, avec score + nb de livres liés (pour aider à choisir le canonique).

### 3.2 Documents
- Exact : même ISBN normalisé (chiffres only) — signal fort.
- Approchant : `fn_normalize_name(titulo)` proche **et** auteur proche.
- RPC `suggest_book_duplicates(p_book_id)` → autres livres candidats + score +
  nb d'exemplaires/holdings (pour choisir le canonique).

## 4. Fusion — RPC (SECURITY DEFINER, gating staff, validation humaine)

### 4.1 `merge_author(p_canonical_id, p_duplicate_id)`
Réassigne TOUTES les FK vers `authors.id` du doublon → canonique, puis supprime
le doublon. Tables à traiter (audit FK requis avant impl) :
- `book_contributors.author_id` → update dup→canonique (le trigger propage
  `book_authors`).
- `book_authors` → réassigner ; gérer conflit PK `(book_id,author_id,role,ord)`
  (ON CONFLICT DO NOTHING puis suppression des lignes du doublon).
- `author_translations` → **conflit `UNIQUE(author_id,lang)`** : règle =
  conserver la traduction du canonique ; ne déplacer que les langues absentes
  chez le canonique (les bios en double du doublon sont supprimées, ou
  signalées). *(Q-A1.)*
- Auditer toute autre FK référencant `authors` (ex. drafts
  `published_author_id`) avant suppression (FK RESTRICT bloquerait sinon).
- Garde-fou : refuser si `p_canonical_id = p_duplicate_id` ; journaliser.

### 4.2 `merge_book(p_canonical_id, p_duplicate_id)` — **plus lourd / phasé**
Beaucoup plus de dépendances : `book_holdings`, `exemplares`/`exemplar_drafts`,
`book_contributors`, `book_authors`, ressources numériques
(`book_digital_resources`), `book_drafts.published_book_id`, etc. Risque élevé
(les exemplaires portent des prêts/consultas en cours). → **audit FK exhaustif
obligatoire** ; envisager un mode « rattacher les exemplaires du doublon au
canonique » plutôt qu'une fusion totale. *(Q-D1 : périmètre exact de la fusion
document.)*

## 5. Frontend
- **Fiche auteur** (`AuthorDraftForm`) : bouton « Doublons possibles » →
  `suggest_author_duplicates` → liste (nom, score, nb livres) → choix canonique
  + confirmation → `merge_author`.
- **Fiche document** (`BookDraftForm`) : idem avec `suggest_book_duplicates` /
  `merge_book`.
- Confirmation explicite (modale « Fusionner X dans Y — irréversible »).

## 6. Problèmes liés (hors périmètre, à traiter séparément)

- **#FICHE-AUTEURS-INCOMPLETE (débusqué 05/06)** : la fiche livre publique
  (`BookPage`, l.498) affiche les auteurs depuis `author_chips`/`authors_json`,
  construits depuis `book_authors` (autorités **liées** seulement). Les
  contributeurs **sans autorité** (`book_contributors.author_id IS NULL`)
  n'apparaissent pas. Ex. « Maio de 68 » (1628) : 4 contributeurs en notice, 2
  sur la fiche (Joyeux + Lenoir liés ; Duteuil + Hernandez non liés → masqués).
  → Correctif : `BookPage` doit afficher **tous** les `book_contributors`
  (liés en `<Link>`, non liés en texte), au lieu de se limiter aux autorités
  liées. Même angle mort que la liaison (contributeur non lié = seconde classe).
  *(À régler indépendamment de la fusion.)*

## 7. Questions ouvertes

- **Q-A1** — Conflit `author_translations` à la fusion : conserver le canonique
  et jeter les bios en double du doublon, ou les garder en « à arbitrer » ?
- **Q-D1** — Fusion document : fusion totale vs simple rattachement des
  exemplaires/holdings du doublon au canonique ?
- **Q-2** — Détection : exact-normalisé seul, ou + trigramme (reco : +
  trigramme, marqué « approchant », jamais auto-fusionné).
- **Q-3** — Canonique : choix manuel par le staff (reco) vs suggestion auto
  (le plus de liens/exemplaires) pré-sélectionnée.
- **Q-4** — Traçabilité : journaliser les fusions (table d'audit `merge_log`) ?
- **Q-5** — Phasage : autorités d'abord (faible risque) puis documents ?

## 8. Séquencement proposé

1. Arbitrer §7 → acter au REGISTRE.
2. **Autorités** : audit FK `authors` + migration `suggest_author_duplicates`
   + `merge_author` (doctrine SECURITY DEFINER / gating staff) + bouton fiche
   auteur + modale de confirmation.
3. **Documents** : audit FK `books` exhaustif + `suggest_book_duplicates` +
   `merge_book` (ou rattachement exemplaires) + bouton fiche document.
4. (Lié, indépendant) corriger `BookPage` pour afficher tous les contributeurs
   (#FICHE-AUTEURS-INCOMPLETE, §6).

---

*Doctrine : migrations via fichier horodaté → push → Woodpecker (jamais MCP).
Fusion = destructif → garde-fous, validation humaine, journalisation. Cette spec
ne committe aucun code.*
