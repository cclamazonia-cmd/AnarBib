# Spec — Module capas (couverture)

- **Version :** 0.2 (C1–C3 actés + 4ᵉ source `og:image`)
- **Date :** 2026-06-01
- **Statut :** 🟡 Spécification, à implémenter — lot #3 du chantier Catalogação (Q1 du cadrage)
- **Périmètre :** stockage stable de la couverture, recherche automatique de candidates (EF `cover_lookup`), UI de sélection/aperçu, anti-tracking.
- **Auteur :** Xavier (coordination AnarBib) — rédaction assistée
- **Méthode :** parité fonctionnelle + qualitative + audit doctrinal (même grille que #BIBLIO / Importações / Catalogação)
- **Référence visuelle :** `maquette_fiche_catalogacao_v2.html` (emplacement capa + bouton « Buscar capa » réservés).

**Dépendances entrantes :**
- `CADRAGE_catalogacao_parite_et_module_capas_2026-06-01` (§5 module capas ; Q2 sources, Q8 chemin)
- `spec-catalogacao-fiche-et-paliers` v0.4 (§5.3 — l'emplacement capa et l'ancre `cover_object_path` sont réservés)
- EF existante `catalog_metadata_lookup` (`index.ts`) — agrégateur de **métadonnées textuelles** (BNE, BnF, DNB, ICCU ; LoC désactivé), qui **ne renvoie pas de couverture** → d'où une EF jumelle.
- EF existante `fetch-url-metadata` — extrait déjà `og:image` (réutilisée comme 4ᵉ source de capa, §4.2).

**Dépendances sortantes :**
- `spec-exemplaires-circulation` (le flux doublon→exemplaire : rattacher un exemplaire à une fiche partagée **ne re-uploade pas** de capa — §3.4)

---

## 1. Objet & posture

La couverture est un *greenfield* à deux voies complémentaires :
- **l'upload manuel**, qui **existe déjà** (bucket `covers`) mais souffre d'un **bug de collision de chemin** ;
- **la recherche automatique**, **nouvelle**, qui propose des candidates issues de sources ouvertes.

Posture : sobre et **éthique**. La couverture sert le catalogue, pas le pistage : toute image externe est **récupérée côté serveur** et **stockée localement** — jamais de hotlink qui fuiterait l'IP/agent du lecteur vers un tiers. Même doctrine anti-tracking que la carte-lecteur (token opaque, PNG/PDF locaux).

---

## 2. Périmètre

**Dans le périmètre :**
- Le **chemin de stockage stable** de la capa (correction du bug de collision, clé `bib_ref` + repli, save préalable).
- L'**EF `cover_lookup`** (jumelle de `catalog_metadata_lookup`) et ses sources.
- L'**UI** de recherche / galerie de candidates / sélection / aperçu / retrait.
- L'**anti-tracking** (fetch serveur, stockage local) et l'**attribution de source/licence**.

**Hors périmètre (renvoyé ailleurs) :**
- La **fiche** elle-même et le registre de champs → `spec-catalogacao-fiche-et-paliers`.
- Les **métadonnées textuelles** → `catalog_metadata_lookup` (existante, inchangée).
- La **destination/doublons** → `spec-exemplaires-circulation` (on en respecte seulement l'articulation, §3.4).

---

## 3. Stockage & chemin (Q8)

### 3.1 Le bug actuel

Le portage React écrit la capa à `books/${draftId}/front.${ext}`. Quand `draftId` vaut `new` (ou est absent avant le premier save), **tous les nouveaux rascunhos écrivent à `books/new/front.png`** et s'écrasent mutuellement. C'est la cause directe des capas perdues/mélangées.

### 3.2 Le chemin cible

- Clé de chemin = **`bib_ref`** (la « Referência local ») si renseignée, **repli sur l'identifiant de rascunho réel** (UUID stable du `book_draft`, **jamais `new`**).
- **Exiger le save avant upload** : un rascunho doit avoir un id réel (et idéalement un `bib_ref`) avant qu'on autorise l'upload. L'UI désactive « Buscar capa » / upload tant que le rascunho n'est pas sauvegardé.
- Chemin : `covers/books/${bib_ref || stableDraftId}/front.${ext}`. L'ancre `cover_object_path` (réservée spec #1 §5.3) stocke ce chemin sur `book_drafts` / `books`.

### 3.3 Compatibilité ascendante

Les capas déjà stockées (anciens chemins) **restent valides** : leur `cover_object_path` est conservé tel quel ; seuls les **nouveaux** uploads adoptent la clé corrigée. Aucune migration d'objets de stockage n'est nécessaire.

### 3.4 Articulation modèle fédéré (lien spec #2)

La couverture appartient à la **fiche partagée** (`book_id`), pas à la biblio. Conséquences :
- À la **publication**, l'ancre `cover_object_path` est portée par la notice publiée (`book_id`).
- Dans le flux **doublon → « Criar um exemplar aqui »** (spec #2 §7), on **ne re-uploade pas** de capa : la fiche partagée a déjà la sienne.

---

## 4. EF `cover_lookup` (jumelle de `catalog_metadata_lookup`)

### 4.1 Rôle

EF dédiée, **séparée** de `catalog_metadata_lookup` (qui reste un agrégateur de métadonnées textuelles). `cover_lookup` prend une clé (ISBN, et/ou titre+autorité, et/ou **URL** de ressource, et/ou un PDF de ressource numérique) et renvoie une **liste de candidates** (vignettes), chacune avec sa **source** et, si connue, sa **licence**.

### 4.2 Sources retenues (Q2)

- **Open Library** (couvertures par ISBN/OLID) ;
- **Wikimedia / Wikidata** (image liée à l'entité, souvent domaine public / CC) ;
- **Page 1 du PDF** pour les ressources numériques natives (rendu serveur de la première page comme candidate) — **sous-paquet différé P3** (§9) ;
- **`og:image` via `fetch-url-metadata`** pour toute ressource portant une **URL** (ressource numérique native, ou fiche avec URL source) : l'EF `fetch-url-metadata` extrait déjà `og:image` (cf. spec #4 §3) → **on réutilise cette extraction**, candidate gratuite et peu coûteuse.
- **Exclus : Amazon et Google** (pistage, conditions d'usage).

> **Réutilisation, pas duplication.** `cover_lookup` n'implémente pas un nouveau parseur HTML : pour la source `og:image`, il s'appuie sur `fetch-url-metadata` (déjà en prod). La vignette ainsi obtenue passe par le même fetch+stockage serveur que les autres (§4.3) pour tenir l'anti-tracking.

### 4.3 Anti-tracking

- **Fetch côté serveur** : l'EF télécharge les vignettes ; le navigateur (staff comme lecteur) ne contacte jamais directement Open Library/Wikimedia.
- À la **sélection**, l'image pleine est **téléchargée côté serveur et écrite dans le bucket `covers`** (jamais un hotlink stocké). Le catalogue public n'affiche que l'URL de notre bucket.
- **Attribution** : on enregistre la **source** et la **licence** de la capa choisie (champs `cover_source` / `cover_license` — **`text` nullable, créés (C1)**) — exigence éthique et de conformité.

---

## 5. UI

- Emplacement capa **déjà réservé** (spec #1 §5.3) : cadre « Sem capa » + bouton **« Buscar capa »** + actions « Escolher imagem » (upload manuel) / « Remover capa ».
- **« Buscar capa »** ouvre une **galerie de candidates** (vignettes par source, avec mention de la source/licence), choix en un clic → stockage serveur → aperçu.
- États : chargement (skeleton), « Nenhuma capa encontrada nas fontes consultadas », erreur réseau (toast).
- Boutons désactivés tant que le rascunho n'est pas sauvegardé (§3.2).

---

## 6. Anti-tracking — doctrine

Reprend la doctrine de la carte-lecteur : aucune ressource tierce chargée dans le navigateur, fetch serveur, stockage local, pas de hotlink. La capa publiée est **toujours** servie depuis le bucket `covers`.

---

## 7. Gardes Storage / RPC

- **Upload** : via **Storage API** `supabase.storage.from('covers')` — hors périmètre RPC (doctrine v3, point 3 : Storage natif). Écriture protégée par **RLS du bucket** (staff actif de la biblio : `status='active' AND role IN ('librarian','coordenador')`).
- **EF `cover_lookup`** : lecture seule de sources publiques, aucune donnée utilisateur ; **posture d'auth alignée sur `catalog_metadata_lookup`** (mêmes réglages `verify_jwt` que sa jumelle).
- **Sélection → stockage serveur** : l'étape « télécharger + écrire dans `covers` » s'exécute côté serveur (dans l'EF ou un endpoint dédié), jamais dans le navigateur, pour tenir l'anti-tracking.

---

## 8. i18n

- Existants réutilisés : `catalogacao.ui.chooseCover` (« Escolher imagem »), `catalogacao.ui.noCover` (« Sem capa »), `catalogacao.field.coverUpload` (« Capa »), `catalogacao.field.coverRemove` (« Remover capa »).
- À ajouter : « Buscar capa », libellés de la galerie (source, licence), « Nenhuma capa encontrada », états de chargement/erreur.
- **8 locales en une passe** (pt-BR, fr, es, it, de, en, ca, eo) ; flat, LF sans BOM, 2 espaces ; PT-BR strict.

---

## 9. Implémentation & déploiement

Séquence de paquets :
1. **P1 — Correction du chemin (bug).** Clé `bib_ref` + repli UUID rascunho stable + save préalable ; fin de la collision `books/new/`. Indépendant, corrige un bug réel **tout de suite**.
2. **P2 — EF `cover_lookup` (Open Library + Wikimedia + `og:image`) + UI galerie.** Sources HTTP légères ; `og:image` réutilise `fetch-url-metadata` (pas de nouveau parseur) ; sélection → fetch+stockage serveur ; attribution source/licence.
3. **P3 — Source « page 1 du PDF ».** **Sous-paquet à part** : le rendu serveur d'une page de PDF est le point lourd (lib de rasterisation, taille de bundle). **Différable** ; à isoler pour ne pas alourdir l'EF.
4. **P4 — i18n** (8 locales).

**Déploiement EF (doctrine, rappels) :**
- Déploiement par **`git push` → Woodpecker** (`deploy-edge-functions`). **Jamais** MCP `deploy_edge_function`, jamais SQL Editor.
- **Surveiller la taille du bundle** : si `cover_lookup` (surtout avec P3) dépasse la limite (~150 ko, cas connu de `notify-event`), bascule en déploiement **CLI** ; sinon Woodpecker standard.

---

## 10. Risques & vigilance

- **Rendu page-1-PDF côté serveur** : risque taille de bundle + CPU dans une EF Deno. Mitigation : sous-paquet isolé (P3), rasteriseur léger ou runtime dédié, **différable** sans bloquer Bologne.
- **Propriété de la capa en modèle fédéré** : la capa appartient à la fiche partagée, pas à la biblio. Mitigation : clé sur `book_id` après publication ; `bib_ref`/draft-id seulement pendant le brouillon ; pas de re-upload au rattachement d'exemplaire (§3.4).
- **Licences des images** : Wikimedia/Open Library portent des licences variées (DP, CC). Mitigation : **enregistrer source + licence** de la capa choisie (`cover_source` / `cover_license`) — exigence éthique du projet.
- **Anti-tracking** : tout hotlink résiduel (vignette tierce chargée dans le navigateur) trahirait la doctrine. Mitigation : fetch serveur **systématique**, vérifié à la revue.

---

## 11. Liens

- **Cadrage parent :** `CADRAGE_catalogacao_parite_et_module_capas_2026-06-01.md` (§5, Q2, Q8)
- **Spec fiche :** `spec-catalogacao-fiche-et-paliers` v0.3 (§5.3 emplacement + ancre `cover_object_path`)
- **Spec exemplaires :** `spec-exemplaires-circulation` (§7 doublon → pas de re-upload)
- **EF jumelle :** `catalog_metadata_lookup` (`index.ts`, métadonnées textuelles)
- **Référence visuelle :** `maquette_fiche_catalogacao_v2.html`

---

*Fin v0.2. Arbitrages actés : C1 — champs `cover_source` / `cover_license` créés (`text` nullable) ; C2 — « page 1 du PDF » en sous-paquet **P3 différé** ; C3 — endpoint sélection→stockage **dans `cover_lookup`** (scinder seulement si la taille l'impose). Ajout : 4ᵉ source de capa **`og:image`** via réutilisation de `fetch-url-metadata` (§4.2).*
