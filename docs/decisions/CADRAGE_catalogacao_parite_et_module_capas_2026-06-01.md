# CADRAGE — CatalogaçãoPage : parité fonctionnelle (legacy `catalogacao.html` → React) + micro-module « capas »

> **Statut :** niveau 1 cartographique (recensement exhaustif + diagnostic de parité), avant spec d'implémentation.
> **Date :** 2026-06-01 · **Auteur :** session de cadrage AnarBib (panne Codeberg, travail hors-push).
> **Chantier-cadre :** arc *parité fonctionnelle + qualitative + audit doctrinal* — étape **CatalogaçãoPage** (après BibliotecaPage et ImportaçõesPage).

---

## 0. Méthode & corpus lu

Sources examinées intégralement :

| Fichier | Lignes | Rôle |
|---|---:|---|
| `catalogacao.html` | 24 712 | Référence legacy (DOM+CSS 1→4989, moteur JS 4991→24710) |
| `CatalogacaoPage.jsx` | 467 | Coquille React (onglets, mode, stats, lots) |
| `BookDraftForm.jsx` | 1 949 | Ficha documento (le plus avancé) |
| `AuthorDraftForm.jsx` | 650 | Ficha autoria |
| `ExemplarDraftForm.jsx` | 469 | Exemplar **+ rótulo fusionnés** |
| `QueuePanel.jsx` | 379 | Fila editorial + lixeira |
| `CatalogPanel.jsx` | 228 | Catálogo publicado |
| `LabelSheetPrinter.jsx` | 219 | Planche d'étiquettes A4 |
| `CatalogacaoPage.css` | 183 | Styles |

Le moteur JS legacy contient **≈ 760 fonctions** ; le recensement ci-dessous travaille au niveau « capacité utilisateur » (fonctionnalité / option / action), pas ligne à ligne.

---

## 1. Note de périmètre — `partnerCatalogsPanel` est du code mort

Point décisif pour ne pas sur-dimensionner le chantier.

Le DOM legacy contient un huitième panneau, `partnerCatalogsPanel` (≈ ligne 4192), accompagné d'environ **6 000 lignes de JS** (toutes les fonctions `partner*`, `incomingCatalog*`, `compareWorkspace`, `importWorkspace`, gouvernance inter-bibliothèques, matrice de droits, run history d'import…). Or :

```html
<section id="partnerCatalogsPanel" class="panel"
         style="display:none !important;" aria-hidden="true"
         data-importacoes-bridge="hidden">
```

- Il n'est **pas** dans la barre d'onglets (`getAvailableCatalogacaoTabs()` ne lit que les `.tab-btn` ; ce panneau n'en a pas).
- Il est masqué de force et marqué `data-importacoes-bridge="hidden"`.

**Conclusion :** la fédération / l'import partenaire **relève d'ImportaçõesPage**, pas de CatalogaçãoPage. Les ≈6 000 lignes `partner*` ne sont **pas** une régression à porter ici, je les sors du périmètre.

> **✅ Confirmé (01/06) par `ImportacoesPage.jsx`** (608 l.) : la page React Importações porte exactement ce flux — onglets `reception / url / rss / history`, consommant `partner_catalog_sources_ui`, `partner_catalog_import_runs_ui`, `partner_catalog_import_rows_ui`. La fédération est donc bien chez Importações. **Q5 close.**

Le périmètre **réel** de catalogação legacy = 7 onglets actifs :
`booksPanel · authorsPanel · exemplarsPanel · labelsPanel · queuePanel · batchesPanel · catalogPanel` (+ lien sortant `Importações`).

---

## 2. Architecture comparée des onglets

| Legacy (7 onglets actifs) | React (`TABS`) | Remarque |
|---|---|---|
| `booksPanel` | `booksPanel` → `BookDraftForm` | OK |
| `authorsPanel` | `authorsPanel` → `AuthorDraftForm` | OK |
| `exemplarsPanel` | **fusionné** dans `indexPanel` | `ExemplarDraftForm` |
| `labelsPanel` | **fusionné** dans `indexPanel` | `ExemplarDraftForm` (overrides + aperçu) **+** `LabelSheetPrinter` (planche) |
| `queuePanel` | `queuePanel` → `QueuePanel` | OK |
| `batchesPanel` | `batchesPanel` → `BatchesPanel` (inline) | Très réduit (cf. §3.7) |
| `catalogPanel` | `catalogPanel` → `CatalogPanel` | Réduit (cf. §3.8) |
| (lien) `Importações` | — | À recâbler (cf. Q4) |

**Choix structurant déjà acté côté React :** la fusion *Exemplares + Rótulos* en un seul onglet « Indexação ». C'est cohérent UX (un exemplaire ⇒ son rótulo), mais cette fusion a **absorbé une partie** des capacités du `labelsPanel` legacy et en a **perdu** d'autres (cf. §3.5).

---

## 3. Cartographie exhaustive du legacy (panneau par panneau)

Légende d'état React : **✅ porté** · **🟡 partiel** · **❌ absent** · **➖ hors-périmètre (Importações)**.

### 3.1 Barre globale (hors onglet)

| Capacité legacy | État React |
|---|---|
| Bascule **mode simple / completo** (persistée localStorage) | ✅ |
| 4 stats (lotes abertos / rascunhos / livros / autores) cliquables → onglet | ✅ |
| Pills **session e-mail + rôle** (`userEmail`, `rolePill`) | 🟡 (porté via `UserHeroBadge`, à vérifier) |
| Bouton **Atualizar** global | ✅ |
| Liens hero **Painel / Catálogo / Manual** | 🟡 (`HeroDocumentationActions`, à vérifier les cibles) |
| Message global positionné/ancré (`positionMessage`, `repositionVisibleMessages`) | ❌ (messages locaux par formulaire seulement) |

### 3.2 `booksPanel` — Ficha documento

C'est le panneau le mieux porté. **Présents en React :** upload capa + aperçu, panneau lookup ISBN, lote, **type de matériel + guide contextuel**, champs cœur, **contributeurs typés** (auteur/co-auteur/organisation, rôle, primaire), ISBN/ISSN + ouvertures externes (BN, WorldCat, portail ISSN), champs **périodique**, pages + circulation (`loanable`), **aperçu cote/étiquette**, sujets + notes, **sous-formulaires par matériel** (tract, áudio, audiovisual, digital nativo, dossiê), **pont d'acquisition** (acquisition_mode/date, mutualization, owner/holder, partner_source, source_record_id/url, import_format/method, provenance_note), **recursos digitais** (CRUD), **MARC JSON**, **painel de revisão** (resumo / arquitetura / saída pública / pacote ISBD zones 0–8), garde-fou **doublon** ISBN+titre/auteur.

Capacités legacy **non reportées** :

| Capacité legacy | Fonctions legacy | État |
|---|---|---|
| **Suggestion CDD** automatique depuis métadonnées | `suggestCDD`, `applySuggestedCDD` | ❌ |
| **Suggestion de coleção/série** | `detectCollectionSuggestion`, `applySuggestedCollection` | ❌ |
| **Suggestions de sujets** (copier / appliquer sélection) | `renderSubjectSuggestions`, `copy/applySelectedSubjectSuggestions` | ❌ |
| **Ouvrir / lire** un recurso digital lié (PDF + reader) | `openBookDigitalPdfFromForm`, `openBookDigitalReader` | ❌ (CRUD oui, lecture non) |
| **Visionneuse universelle** multiformat | `openBookDigitalUniversalViewer` (+ `multiformat-viewers.md`) | ❌ |
| Synchro recurso digital → asset publié | `syncBookDraftDigitalResourceToPublishedAsset` | ❌ à vérifier |
| **Gouvernance inter-bib** d'une ficha (strip de droits, comparer/importer depuis partenaire, hint de politique) | `bookRightsActionStrip`, `renderBookPartnerActionStrip`, `openCompareWorkspace`, `openImportWorkspace`, `refreshBookPartnerGovernanceUi` | ➖ (Importações — champs présents, machinerie non) |
| Bascule **bucket public/privé** d'un recurso digital | `syncBookDigitalBucketFromToggle` | ❌ à vérifier |
| Aperçu **fiche publique** double (catálogo + ficha) avec holdings/accès | `buildBookPublicSurfacePreview` | 🟡 (résumé présent, double-carte à vérifier) |

> **Note :** côté *champs*, le portage Book est quasi-complet. Les manques sont surtout des **assistances** (suggestions CDD/coleção/sujets) et la **lecture** des recursos digitais.

### 3.3 `authorsPanel` — Ficha autoria

**Présents en React :** types d'autorité (5), assistant de nom (`buildSortName` particules), source_kind / label / url, VIAF / ISNI / Wikidata, photo, **biographie multilingue 8 locales** (`author_translations`), méta structurées packées dans `notes`, aperçu « arquitetura documental ».

| Capacité legacy | Fonctions legacy | État |
|---|---|---|
| **Prévisualisation** du nom assisté avant application | `previewAuthorAssist` / `renderAuthorAssistPreview` | 🟡 (React applique sans étape preview) |
| **Suggestion de sigle** (acronyme) | `buildAuthorityAcronymSuggestion` | ❌ |
| **Garde-fou doublon autorité** | `guardAuthorDuplicateBeforeSaveOrPublish`, `findExistingPublishedAuthorMatch`, `buildAuthorDuplicateSignature` | ❌ |
| **Guide contextuel** par type d'autorité | `applyAuthorAuthorityUiProfile`, `authorAuthorityGuideText` | 🟡 |
| Aperçu structuré « signaux/source/sortie publique » (pills) | `updateAuthorStructurePreview` | 🟡 (statique en mode complet) |

### 3.4 `exemplarsPanel` — Exemplares

**Présents en React :** résolution **ficha mère** via `bib_ref` (auto-remplit le rótulo), tombo, **localisation structurée** (biblioteca/setor/estante/prateleira/obs), notes, sauvegarde/publication.

| Capacité legacy | Fonctions legacy | État |
|---|---|---|
| **Chargement d'un lot d'import** d'exemplaires + recherche dans le lot | `loadExemplarBatchQueue`, `exemplarLotImportId`, `exemplarBatchSearchInput` | ❌ |
| **Validation en masse** des lignes visibles d'un lot | `validateVisibleImportedExemplarRows` | ❌ |
| **File d'exemplaires en rascunho** (pill + liste active) | `renderExemplarActiveDraftsSummary`, `exemplarActiveDraftsWrap` | ❌ |
| **Garde-fou conflit de tombo** | `findExemplarTomboConflict`, `guardExemplarTomboBeforePersist` | ❌ |
| **Comptage d'exemplaires demandés** vs publiés pour une `bib_ref` | `getRequestedExemplarCount`, `countPublishedExemplarsForBibRef` | ❌ |
| **Tombo suggéré** | `buildSuggestedTombo` | ❌ |
| Aperçu « contexte / structure » (pills) | `updateExemplarContextPreview`, `updateExemplarStructurePreview` | 🟡 (arquitetura statique) |

> **Régression notable :** tout le **flux par lot** d'exemplaires (charger un lot → filtrer → valider en masse) a disparu. C'est le mode de travail « production » sur volume.

### 3.5 `labelsPanel` — Rótulos

En React, le rótulo vit en deux morceaux : champs override + aperçu visuel (trigramme) dans `ExemplarDraftForm`, et impression planche dans `LabelSheetPrinter`. Capacités legacy perdues :

| Capacité legacy | Fonctions legacy | État |
|---|---|---|
| **Moteur de suggestion de cote** (ligne `CDD / TRIGRAMME` + raison) | `buildShelfLabelSuggestion`, `renderLabelSuggestion`, `applyLabelSuggestion` (« sans écraser les champs remplis ») | ❌ (React calcule un trigramme d'aperçu, mais pas la *shelfLine* ni l'application non-destructive) |
| **File de rótulos en rascunho** (charger lot, filtrer, valider lignes visibles) | `loadLabelDraftQueue`, `validateVisibleLabelDraftRows`, `labelLotImportId` | ❌ |
| **Aperçu d'un rótulo isolé** + impression **étiquette unique** | `updateLabelPreview`, `getLabelPages`, `labelPreview` | 🟡 (aperçu oui dans Exemplar ; impression unitaire ❌) |
| **Aperçu planche** depuis un lot précis (`labelBatchPreviewId`) | `loadLabelSheetPreview`, `renderLabelSheet` | 🟡 (planche oui via `v_exemplar_labels`, sélection par lot ❌) |
| États de cycle de vie du rótulo (pending/ready/printed) lisibles | `getLabelLifecycleStateLabel`, `updateLabelFlowPreview` | 🟡 (`label_status` ready oui, « printed » ❌) |

> `LabelSheetPrinter` dépend de la vue `v_exemplar_labels` et de **clés i18n `labels.*`** — vérifier qu'elles existent dans les 8 locales (cf. Q3).

### 3.6 `queuePanel` — Fila editorial + lixeira

Le mieux porté après Book. **Présents :** filtres type/statut/action + recherche, sélection multiple, **publier / descartar / marquer prêt / attribuer à un lote** en masse, **lixeira** (restaurer / supprimer / vider).

| Capacité legacy | Fonctions legacy | État |
|---|---|---|
| Filtre **par origine** (`queueOriginFilter`) | — | ❌ |
| **Édition directe** d'un rascunho depuis la file (ouvre le bon formulaire) | `fetchDraftAndEdit` | ❌ (la file React liste/agit en masse mais n'ouvre pas un draft dans son formulaire) |
| Résumés pédagogiques flow/structure/action/scope | `updateQueueFlowSummary`, `updateQueueStructureSummary`… | ❌ (doctrinal, faible priorité) |
| Fusion des **exemplaires de lot** comme items synthétiques de la file | `mergeActiveExemplarDraftRowsIntoQueue`, `buildSyntheticExemplarQueueItem` | ❌ |
| Audit de clôture de workflow | `renderWorkflowClosureAudit` | ❌ (doctrinal) |

> **Manque fonctionnel réel :** « cliquer un rascunho de la file pour l'éditer ». Aujourd'hui React publie/jette en masse mais ne ré-ouvre pas l'item dans son formulaire.

### 3.7 `batchesPanel` — Lotes

Legacy : formulaire riche (name, **purpose**, **origin**, **intent**, notes) + résumés de composition/travail/publication + stats par purpose/intent + publication de lot. React `BatchesPanel` (inline) : **création (name + notes)**, fermeture, publication, liste ouverts/fermés.

| Capacité legacy | État |
|---|---|
| Champs **purpose / origin / intent** du lote | ❌ |
| **Composition du lote** (combien de books/authors/exemplars) | ❌ |
| Résumés travail/publication par lote | ❌ |
| Notes structurées du lote (`parseBatchStructuredMeta`) | ❌ |

> Acceptable si la doctrine « lote = simple regroupement nommé » est assumée. À statuer (Q6).

### 3.8 `catalogPanel` — Catálogo publicado

Legacy : 4 surfaces (books / **outros documentos** / authors / exemplares), **cartes d'état de rascunho lié** par item (un draft existe-t-il déjà ?), résumés par couche (notice/holding/exemplar/digital), cellules **droits inter-bib**, **signaux de proximité d'autorité**, filtres autorité (type + signal), **retomada** pour les 3 types. React `CatalogPanel` : 3 sous-onglets (documents/autoridades/exemplares), recherche, pagination, **retomada** (RPC `create_*_draft_from_*`), **descartar** (DELETE direct).

| Capacité legacy | Fonctions legacy | État |
|---|---|---|
| Séparation **livres / autres documents** | `renderCatalogBooks` / `renderCatalogOtherDocuments` | ❌ (tout dans « documents ») |
| **Badge « rascunho déjà ouvert »** par item | `getCatalogDraftStateMeta`, `fetchActive*DraftLinks` | ❌ |
| Cellules **droits inter-bib / digital / compat** | `renderCatalogBookRightsCell`, `…DigitalCell`, `…CompatCell` | ➖ / ❌ |
| Filtres autorité (type + signal de proximité) | `catalogAuthorAuthorityFilter`, `getCatalogAuthorProximityMeta` | ❌ |
| Résumés par couche (`renderCatalogPanelLayerSummary`) | — | ❌ (doctrinal) |

> ⚠️ **Point doctrinal :** `CatalogPanel.descartItem()` fait un `supabase.from(table).delete()` **direct** sur `books`/`authors`/`exemplares`. Cela contrevient à la **doctrine RPC v3 §1** (delete = RPC obligatoire) et court-circuite tout garde-fou (intégrité référentielle exemplaires↔books, traçabilité). À corriger via un RPC `discard_published_*` ou au minimum à statuer.

---

## 4. Synthèse priorisée des absences (hors-doctrinal pur)

**P1 — fonctionnel bloquant / mode production :**
1. Exemplares : flux **par lot** (charger / filtrer / valider en masse) — §3.4.
2. Queue : **éditer un rascunho** depuis la file — §3.6.
3. CatalogPanel : `delete` direct → **RPC** (doctrine v3) — §3.8.

**P2 — assistances qui font le « SIGB complet » :**
4. Suggestions **CDD / coleção / sujets** dans Book — §3.2.
5. **Moteur de suggestion de cote** (shelfLine) + application non-destructive — §3.5.
6. **Garde-fous doublons** : autorité (§3.3) et conflit de tombo (§3.4).
7. **Lecture** des recursos digitais (PDF/reader + viewer universel) — §3.2.

**P3 — confort / lisibilité :**
8. Impression **étiquette unique** + sélection planche par lot — §3.5.
9. Badge « rascunho déjà ouvert » dans CatalogPanel — §3.8.
10. Champs lote purpose/origin/intent + composition — §3.7.
11. Filtre origine + items exemplaires synthétiques dans la file — §3.6.

**Doctrinal / pédagogique (P4, optionnel) :** tous les `*StructureSummary`, `*FlowSummary`, `renderWorkflowClosureAudit`, résumés par couche. Ils servaient la posture « commons en construction » ; à reproduire seulement si tu veux conserver ce registre explicatif à Bologne.

---

## 5. Le micro-module « capas » (objectif central)

### 5.1 Existant (à conserver comme socle)

- Upload **manuel** : `uploadFileToBucket('covers', file, path)` ; chemin `books/${storageFolderKey}/${Date.now()}-${safeName}` ; `upsert:true`, `cacheControl:3600`.
- Champ caché `cover_object_path` (→ colonne `cover_object_path` du book) ; aperçu via URL publique `…/storage/v1/object/public/covers/<path>`.
- Côté React : `handleCoverFileChange` + `uploadCover` (présents dans `BookDraftForm`).
- **Important :** le lookup bibliographique actuel **ne renvoie pas d'image de couverture**. Le module est donc **greenfield** côté image.

> **✅ EF `catalog_metadata_lookup` lue (01/06, `index.ts` 1137 l.).** C'est un **agrégateur SRU/MARC propre** : registre de sources `{ id, label, enabled (env), buildUrl, parser }` → BNE, BnF, DNB, ICCU/SBN (LoC désactivé par défaut) ; chaque source `buildUrl → fetchText(timeout+UA) → parser → candidates` ; fusion `dedupeAndRank`. Schéma candidat = `title, subtitle, contributors, responsibility_statement, isbn, issn, classification, subjects, notes, authority_ids, source_url, source_record_id, sources` — **aucun champ `cover`/`thumbnail`/`image`**. Réponse : `{ ok, mode, query, total, sources[], candidates[], summary }`.
>
> **Conséquence d'architecture :** le module capas se construit en **jumeau** de cette EF (même patron registre+parser, même `_shared/cors.ts`, même `fetchText`, mêmes toggles `envBool`), pas en parallèle bricolé. Infra réutilisable telle quelle : `_shared/cors.ts` (origine via `CATALOG_METADATA_ALLOW_ORIGIN`, POST/OPTIONS), `fetchText`, `clampInt`, `envBool`, `jsonResponse`.

### 5.1b Convention de stockage des capas — divergence à trancher (nouveau, 01/06)

Le chemin du fichier capa **diffère** entre legacy et React :

| | Chemin | Clé |
|---|---|---|
| Legacy | `books/${storageFolderKey}/${Date.now()}-${safeName}` | identité **stable** du livre (`getCurrentBookStorageFolderKey` ≈ bib_ref/compat ref) |
| React (`uploadCover`) | `books/${draftId}/front.${ext}`, `upsert:true` | `draftId = f('id') \|\| 'new'` |

Deux problèmes côté React :

1. **Clé = id de rascunho**, pas identité du livre. Après publication puis *retomada* (nouveau draft id), le chemin ne correspond plus → capa potentiellement orpheline ou re-uploadée ailleurs. Le legacy keyait justement sur une identité stable pour survivre au cycle draft→publié→retomada.
2. **`draftId = 'new'`** avant la 1ʳᵉ sauvegarde → tout le monde écrit dans `books/new/front.*` → **collision** entre rascunhos / utilisateurs. Bug latent.

`LibraryContext.jsx` (lu 01/06) **n'expose aucune `storageFolderKey`** (il porte `libraryId`, `librarySlug`, `role`, les 4 axes profil, `reader_cards_enabled`). Il faudra donc **reconstruire** la clé de dossier capa côté Book, à partir de `bib_ref` (ou `published_book_id` à défaut), avant de livrer le module — sinon on bâtit le module capas sur un socle de chemin instable. **→ décision Q8.**

### 5.2 Contraintes propres à AnarBib (politiques avant techniques)

1. **Aucun pistage des lecteurs/biblios.** Toute requête vers une source externe doit partir **du serveur (Edge Function)**, jamais du navigateur du lecteur ni du poste bibliothécaire → l'IP de l'usager ne fuite pas vers un tiers. C'est la même posture que les QR « token opaque » de la carte-lecteur.
2. **Auto-hébergement, pas de hotlink.** On télécharge l'image côté serveur puis on la **ré-upload dans le bucket `covers`**. Avantages : résilience (pas de dépendance à la dispo d'un tiers), pas de fuite de Referer, pas de takedown qui casse l'affichage public, cohérence « commons ».
3. **Droits.** Une couverture est souvent une œuvre graphique sous droits (éditeur). Pour une biblio militante, cadrer : (a) usage documentaire/identification, (b) traçabilité de la source dans `provenance_note` / `marc_json`, (c) capacité de **retrait** facile. Ne pas présenter le module comme « libre de droits » par défaut.
4. **Sources « non-tracées ou péril mineur »** — exclure d'emblée : Amazon, Google Books (ToS + tracking), Syndetics/Content Café (commercial). 

### 5.3 Sources candidates (à confirmer/tester quand Codeberg revient)

| Source | Accès | Tracking | Couverture | Licence image | Verdict |
|---|---|---|---|---|---|
| **Open Library Covers** (`covers.openlibrary.org/b/isbn/{ISBN}-L.jpg?default=false`) | sans clé | quasi nul | bonne (ISBN courants) | variable (souvent éditeur) | **socle** |
| **Wikimedia Commons / Wikidata `P18`** | API/SPARQL | nul | faible (livres) | libre/CC | **éthique++**, complément |
| **Page 1 d'un recurso digital** déjà détenu (PDF→thumbnail) | local | **nul** | = fonds numérisé | = celle du PDF | **idéal** (zéro tiers) |
| BN Brasil (Sophia) / CBL / Gallica | scraping fragile | variable | moyenne | variable | secours, à éviter en auto |

> Recommandation : **Open Library en source primaire** + **génération depuis page 1** pour le fonds numérisé + **Wikimedia** en complément éthique. Tout le reste = ouverture manuelle (comme aujourd'hui pour BN/WorldCat).

### 5.4 Architecture proposée (à spec en niveau 2)

EF **`cover_lookup`** construite en **jumeau strict de `catalog_metadata_lookup`** : même registre `{ id, label, enabled(env), buildUrl, parser }`, même `fetchText`, même `_shared/cors.ts`, mêmes `clampInt/envBool/jsonResponse`. Sources = `openlibrary` (primaire), `wikidata` (option, P18). Schéma candidat capa : `{ source, image_url, provenance, license_hint, width, height }`.

```
[Bouton "Buscar capa"]  (BookDraftForm, à côté de l'upload manuel)
        │  isbn / titre+autor
        ▼
EF  cover_lookup           ← server-side (pas d'IP lecteur exposée)
   ├─ Open Library by ISBN
   ├─ (option) Wikidata P18
   └─ retourne candidates[] : { source, image_url, provenance, license_hint, w, h }
        │
        ▼
[Galerie de vignettes] → choix d'une candidate
        │
        ▼
EF  cover_fetch_store      ← télécharge les bytes + ré-upload bucket `covers`
   └─ path: books/${storageFolderKey}/${Date.now()}-cover-<source>.<ext>
        │
        ▼
set('cover_object_path', path) + provenance dans marc_json + aperçu
```

Variante « page 1 » : EF (ou client) rasterise la 1ʳᵉ page du PDF déjà stocké → upload `covers`. Zéro dépendance externe.

### 5.5 Doctrine d'intégration (rappels qui s'appliquent)

- **Fetch externe = Edge Function**, jamais le client (CORS + privacy).
- **Stockage = `supabase.storage.from('covers')`** : hors périmètre RPC (doctrine RPC v3 §3). ✅
- **Déploiement des nouvelles EF** : `git push` → Woodpecker (`deploy-edge-functions`). **Jamais** le MCP `deploy_edge_function`, **jamais** SQL Editor manuel. Vérifier la taille du bundle (la limite ~150 KB qui a piégé `notify-event`).
- **i18n** : tous les libellés du module dans les **8 locales** en une passe (pt-BR, fr, es, it, de, en, ca, eo), fichiers plats LF sans BOM.
- **REVOKE** sur toute fonction privée éventuelle (doctrine création d'objets sécurisés v2).

---

## 6. Composants legacy — état (mis à jour 01/06)

**✅ Reçus et intégrés à ce cadrage :**

1. ~~`library-context.js`~~ → fourni `LibraryContext.jsx` (React). N'expose **pas** de `storageFolderKey` : à reconstruire (cf. §5.1b, Q8).
2. ~~EF `catalog_metadata_lookup`~~ → `index.ts` lu : agrégateur SRU/MARC, gabarit du futur `cover_lookup` (cf. §5.1, §5.4). `cors.ts` aussi reçu.
3. ~~`ImportacoesPage`~~ → confirme le scoping fédération (Q5 close, §1).

**Encore utiles pour la spec niveau 2 (selon décisions §7) :**

4. **`multiformat-viewers.md`** (dans le projet) + code de `openBookDigitalUniversalViewer` — si on spec la **lecture** des recursos digitais (P2 #7).
5. **La vue `v_exemplar_labels`** (SQL) — pour la parité étiquettes.
6. **Signatures des RPC** `create_*_draft_from_*`, `publish_*_draft`, `publish_catalog_batch` — pour spec les garde-fous doublons/tombo et le futur `discard_published_*`.
7. **Le routeur React** (fichier de routes) — pour Q4 (comment Importações est routée, garde de rôle).

---

## 7. Décisions à statuer avant la spec (Q1→Q7)

- **Q1 — Périmètre du chantier capas :** on livre d'abord *uniquement* le module capas (objectif que tu énonces), ou on traite la parité P1 (exemplaires-lot, édition depuis la file, delete→RPC) **dans la même salve** ? Je recommande : **P1 d'abord** (court, débloque la prod), **capas ensuite** (le morceau créatif).
- **Q2 — Sources capas :** valides-tu Open Library (primaire) + page-1-du-PDF + Wikimedia, en excluant Amazon/Google ? Une source supplémentaire que tu juges acceptable (péril mineur) ?
- **Q3 — Étiquettes :** les clés i18n `labels.*` existent-elles déjà dans les 8 locales, ou faut-il les créer ?
- **Q4 — Lien Importações :** `ImportacoesPage` est une **page sœur** (route dédiée), pas un onglet de catalogação. Faut-il un lien sortant depuis catalogação (comme le legacy `importacoesLinkBtn`) ? Si oui, me fournir le routeur pour la cible exacte.
- **Q5 — Partner/fédération :** ~~à confirmer~~ → **close** : fédération chez Importações (§1). 
- **Q6 — Lotes :** doctrine « lote = regroupement nommé » (React actuel) assumée, ou on réintroduit purpose/origin/intent + composition ?
- **Q7 — Registre doctrinal P4 :** garde-t-on les panneaux pédagogiques (flow/structure/scope summaries) pour la posture Bologne, ou UI plus sobre ?
- **Q8 — Chemin de stockage capas (nouveau) :** on adopte quelle clé de dossier stable ? Proposition : `books/${bib_ref || 'unref'}/cover-${Date.now()}.<ext>` (survit au cycle draft→publié→retomada, pas de collision `new/`). À valider **avant** de livrer le module, car il en est le socle.

---

## 8. Extension de périmètre (01/06) — couche qualitative & nouvelles fonctionnalités

Demandes formulées par Xavier le 01/06. Elles constituent la **couche qualitative** de l'arc (parité → **qualitatif** → audit doctrinal) et débordent le simple module capas. Chaque item : *existant · cible · design · décisions/tensions*.

### 8.A — Module « doublons potentiels » renforcé, bloquant à la publication

- **Existant.** React `checkDuplicateBeforeSave` : (1) ISBN via `ilike`, (2) titre+auteur normalisés (NFD, sans diacritiques). C'est un **avertissement non bloquant** (`confirm()` → override libre). Legacy plus riche : `findDuplicateBookByIsbn`, `findDuplicateBookByCoreIdentity` (titre+année+éditeur), `findDuplicateBookByTitleAuthor`, `guardBookDuplicateBeforeSaveOrPublish`. Aucune des deux versions n'est cross-lingue ni bloquante à la publication.
- **Cible.** Détection multi-signaux + **blocage dur à la publication** sur vrai doublon + sortie « créer un exemplaire à la place » (cf. 8.D).
- **Design.**
  - Signaux + score de confiance : (1) **ISBN/ISSN exact** normalisé = quasi-certain ; (2) **identité-cœur** (titre+auteur+année, ± éditeur) normalisée = fort ; (3) **identifiant d'autorité + titre normalisé** = cross-lingue (cf. 8.B).
  - Politique en deux temps : **au save** = avertissement (un brouillon de variante légitime reste permis) ; **à la publication** = **blocage** si ISBN identique à une fiche déjà publiée du même périmètre, avec sortie obligatoire — soit *lier comme exemplaire*, soit déclarer *édition distincte* (qui suppose un ISBN différent : si l'ISBN est identique, ce n'est pas une édition distincte → blocage maintenu).
  - UI : panneau « doublons potentiels » listant les fiches publiées proches + actions `[Ouvrir l'existante]` · `[Créer un exemplaire ici → 8.D]` · `[Ce n'est pas un doublon → continuer]` (override **tracé** dans `marc_json`/provenance).
- **Tensions.** Faux positifs (rééditions, fac-similés, recueils) → d'où le score + override tracé, jamais un blocage aveugle hors ISBN-identique-publié.

### 8.B — Rattachement d'autorité certain, quelle que soit la langue

- **Problème.** Contrôle d'autorité **multilingue** : *Piotr / Pyotr / Petr / Pierre / Пётр Кропоткин* doivent pointer une seule autorité ; idem œuvres (*A Conquista do Pão / La Conquête du pain / The Conquest of Bread*).
- **Existant.** Champs VIAF / ISNI / Wikidata + `author_translations` (biographie par locale) + `variant_names`/`pseudonyms` (legacy). **Mais aucun résolveur** et **aucun matching par identifiant** : le rapprochement se fait sur la chaîne (signature normalisée + trigramme), donc casse entre langues.
- **Design.**
  - **EF `authority_lookup`** (jumelle de `catalog_metadata_lookup`) interrogeant **VIAF + Wikidata** par nom → candidats **clusterisés** : `{ viaf_id, wikidata_id, isni, preferred_name, variant_names[] (toutes langues), birth/death, country }`.
  - À la saisie d'un auteur : bouton « Identifier l'autorité » → choix d'un cluster → on **stocke l'identifiant pivot** et on peut auto-remplir `variant_names`/`pseudonyms`.
  - Liaison document→autorité : matcher **par identifiant** d'abord (même `viaf_id`/`wikidata_id` ⇒ proposer le rattachement même si la graphie diffère) ; fallback signature+trigramme si pas d'identifiant.
  - Indexer les variantes de graphie → **résout aussi la recherche lecteur multilingue** côté catalogue public.
- **Périmètre v1 vs v2.** v1 = niveau **autorité** (VIAF/Wikidata). v2 (backlog) = niveau **œuvre** (Wikidata QID d'œuvre / OCLC work-id) pour clusteriser les traductions d'un même titre. Ne pas mêler les deux en v1.
- **Tensions.** Couverture VIAF/Wikidata inégale pour militant·es obscur·es, collectifs anonymes, pseudonymes → **garder le chemin manuel** + variantes saisies à la main ; identifiant **jamais obligatoire**.

### 8.C — Couverture des catalogues nationaux : état & extension

- **État actuel (`index.ts`).** 4 actifs — **BNE** (ES), **BnF** (FR), **DNB** (DE), **ICCU/SBN** (IT) — tous SRU/MARC ; **LoC** (US) codé mais `enabled:false`. **BN Brasil absente** de l'automatique (lien manuel seulement). Aucune couche union/cross-lingue.
- **Extension (même patron adapter, toggles env → activable sans refonte) :**
  1. **Activer LoC** (déjà codé).
  2. **Ajouter BN Brasil** (priorité projet pt-BR) — adapter à investiguer : SRU si exposé, sinon Z39.50 / API Sophia. *À sonder quand le réseau revient.*
  3. **Couche union / cross-lingue** : **Wikidata** (SPARQL — sert aussi 8.B), **Open Library** (ISBN — sert aussi le module capas), puis selon besoin **WorldCat** (clé OCLC), **K10plus**, **SUDOC**.
  4. Pour le **russe** (Kropotkine en VO) : RGB/RNB si SRU dispo — à sonder.
- **Prudence.** Certains endpoints évoluent ou disparaissent (ex. British Library : longue indisponibilité après l'incident de 2023 — **vérifier avant d'investir**). Les toggles env permettent d'activer/désactiver **source par source**.
- **Synergie clé.** Trois EF **jumelles** sur un seul patron : `catalog_metadata_lookup` (métadonnées SRU) · `authority_lookup` (VIAF/Wikidata, 8.B) · `cover_lookup` (Open Library/Wikidata, §5). Open Library et Wikidata servent **plusieurs** modules à la fois.

### 8.D — Doublon → exemplaire(s) + catégories de circulation

> **Articulation doctrinale (révisée 01/06 après lecture de `spec-granularite-item.md`).** Le cas concret BTL — *4 exemplaires d'un même ouvrage, 2 à l'emprunt, 2 en consultation* — est l'**exemple fondateur** du chantier déjà cadré **`#MODEL-item-grain`** (23/05). Il faut distinguer **deux couches** qui se composent **sans** 3ᵉ source de vérité :
>
> - **Couche 1 — destination (intention de catalogage)** : attribut **durable de l'exemplaire** (« cette copie est destinée à l'emprunt / la consultation / les deux / l'archive »). **N'existe pas encore** : aujourd'hui `loanable` est au niveau **fiche** (`bookLoanable`), incapable d'exprimer « 2 oui / 2 non » sur une même fiche. **C'est l'incrément de 8.D.**
> - **Couche 2 — trace de transaction** (`#MODEL-item-grain`) : « tel exemplaire *est actuellement* en consultation ». Emprunt + réservation descendent déjà à `item_id` ; la consultation non → ajout `consulta_linhas_v2.item_id` (NOT NULL, FK RESTRICT). **Chantier déjà spécifié.**
>
> Composition : la destination (couche 1) = ce qui est *permis* ; la trace (couche 2) = ce qui se *passe* ; les RPC lisent la destination comme **garde** et écrivent la trace.

- **Modèle.** Une **fiche bibliographique partagée** (`books`), **N exemplaires locaux** (`exemplares`) par biblio. BTL = 1 fiche + 4 exemplaires distincts. Doublon détecté lors d'un catalogage ⇒ « ne pas recréer la fiche, **créer un exemplaire ici** » (8.A).
- **Définition — sur quelle page :** **Catalogação → onglet « Exemplaires » (`ExemplarDraftForm`)**, par exemplaire. C'est le « point névralgique » désigné par `#MODEL-item-grain`. Saisi par le **personnel** (jamais le lecteur — arbitrage Q2 de la spec granularité).
- **Couche 1 — modélisation (nouveau).** 2 axes orthogonaux portés par l'**exemplaire** :
  - `circulation_policy` ∈ `{loanable, consultation_only, loan_and_consultation}`
  - `visibility` ∈ `{public, staff_only}` — *archive* = `staff_only`.
  - UI : un menu à 4 entrées (empruntable / consultation seulement / les deux / archive) **mappé sur 2 colonnes** (extensible, RLS plus simple). Le `bookLoanable` fiche-niveau devient **dérivé/secondaire**.
- **Résolution — où ça s'applique :**
  - **Base (vérité) :** `fn_v2_resolve_consulta_exemplar` (consultation) + chaîne emprunt/réservation (`item_id`) ; les RPC de création **refusent un emprunt sur un exemplaire `consultation_only`**.
  - **Public** (`BookPage`/`CatalogPage`) : bouton « emprunt » actif ssi ≥ 1 exemplaire `loanable` disponible ; consultation = **file indépendante** (comportement actuel déjà conforme) ; affichage agrégé « 4 exemplaires — 2 empruntables, 2 consultation ». Vue publique filtre `visibility='public'` (RLS).
  - **Staff** (PanelPage) : voit/choisit l'exemplaire précis.
- **Ce qu'il faut pour que BTL fonctionne réellement (ensemble) :** (1) cœur `#MODEL-item-grain` (`consulta_linhas_v2.item_id`) — *prérequis structurel* ; (2) couche destination sur `exemplares` (8.D) ; (3) frontend consultation choisissant l'exemplaire (suite §6.1 de la spec granularité) ; (4) gardes RPC + filtre catalogue public.
- **Alignements obligatoires :** `spec-flux-consultations` (#91–94, invariant emprunt-vs-consulta), `spec-granularite-item` (#MODEL-item-grain), axe biblio `circulation_mode`. Migration `exemplares` + RLS `staff_only` → **déploiement Woodpecker**.
- **Décision.** 2 colonnes (`circulation_policy` + `visibility`) plutôt qu'un enum unique à 4 — recommandé. **→ Q9.**

### 8.E — Modèle de champs & paliers (registre déclaratif)

- **Existant.** Visibilité par `data-catalog-mode` (binaire) + classe `.mode-complete-only` + `isComplete` épars dans le JSX. Difficile à maintenir, hétérogène, peu lisible.
- **Cible.** Un **registre de champs déclaratif** : chaque champ tagué `{ tier: simple|avance|complet, group, materialTypes?: [...] }`. Le rendu lit *registre × palier courant × type de matériel*. Bénéfices : cohérence, lisibilité, i18n centralisée, maintenance, et **socle de la refonte CSS (8.G)** en un seul passage de rendu.
- **Mode MARC.** En *complet* : zones ISBD (déjà là) + MARC JSON (déjà là) + identifiants d'autorité — **pas** d'éditeur MARC tag-par-tag (touffu). On garde l'approche legacy « champs structurés qui *génèrent* l'ISBD/MARC ».

### 8.F — Documents non-livres

- **Existant.** Sous-formulaires tract / áudio / audiovisual / digital_native / dossiê / periódico ; types tese/artigo/relatório/zine/cartaz peu dotés.
- **Cible.** *Simple* = cas courants (zine, tract, périodique, cartaz, áudio) avec 3–6 champs ; *complet* = exhaustif par type, **sans sous-catégories inutiles**.
- **Design.** Le registre (8.E) porte `materialTypes` → n'affiche que les champs pertinents au type choisi, au palier choisi. Définir par type un set *simple* et un set *complet*. S'appuyer sur **spec-granularite-item** et **multiformat-viewers.md** pour ne pas réinventer. Garder une **liste de types maîtrisée** (alignée catalogue public + filtres).

### 8.G — Lisibilité / refonte CSS (sur la base du CSS fourni)

Diagnostic du `CatalogacaoPage.css` actuel :
- **Labels** `.85rem` en `--brand-muted (#bbb)` → contraste faible, hiérarchie molle.
- **Champs** stylés en **inline** (`rgba(0,0,0,.3)` fond, bordure `rgba(255,255,255,.12)` quasi invisible) → la « mise en relief » est absente ; peu thémable.
- **Grille** `cat-book-grid` 3 colonnes / gap 12px → serrée sur libellés longs.
- Pas d'état **focus-visible** explicite (accessibilité).

Recommandations (à faire **en même temps** que 8.E) :
- Échelle typographique nette ; labels plus lisibles (poids + contraste) ; **bordure de repos visible** sur les champs + **anneau de focus** accessible ; padding/line-height accrus.
- Promouvoir des classes `.cat-input / .cat-select / .cat-textarea / .cat-section` (réduire l'inline, thémables via `--brand-*`).
- **Largeur de lecture maîtrisée** pour les zones texte ; sections en cartes avec en-têtes clairs.
- *Je peux produire une maquette visuelle de la fiche redessinée (3 paliers + relief des champs) sur demande.*

### 8.H — Toggle 3 paliers : simple / avancé / complet

**Recommandé — judicieux**, à 3 conditions : définitions nettes, persistance (déjà localStorage), et registre de champs (8.E). Migration `data-catalog-mode` `simple|complete` → `simple|avance|complet` ; `.mode-complete-only` → sélecteurs par palier minimal ; **rétro-compat** : ancien `complete` → `complet`.

**Définition proposée des paliers :**

| Palier | Esprit | Contenu (livre) |
|---|---|---|
| **Simple** | Biblio militante, sans prétention académique | Titre · auteur(s) · année · éditeur · ISBN · CDD/cote · langue · **politique de circulation (8.D)** · capa |
| **Avancé** | « Bon·ne bibliothécaire » sans MARC | + sous-titre · édition · collection/série · lieu · pages · sujets · notes · contributeurs typés · ISSN/périodique de base · acquisition de base |
| **Complet** | Exhaustif, non touffu | + zones ISBD · MARC JSON · identifiants d'autorité (VIAF/ISNI/Wikidata) · sous-formulaires matériels complets · provenance/mutualisation · recursos digitais |

---

## 9. Séquencement proposé des chantiers (parité + qualitatif + capas)

Quatre lots cohérents (dépendances entre parenthèses) ; ordre à arbitrer (Q1) :

1. **Lot UX / champs** — 8.E (registre) + 8.G (CSS) + 8.H (3 paliers) + 8.F (non-livres). *Un seul passage de rendu ; débloque la lisibilité ; pré-requis propre de tout le reste.*
2. **Lot circulation & doublons** — 8.A (doublons bloquants) + 8.D (destination par exemplaire + catégories). *Prérequis structurel : le cœur `#MODEL-item-grain` (`consulta_linhas_v2.item_id`) doit être posé d'abord — c'est lui qui rend le cas BTL représentable.* Dépend aussi d'une migration `exemplares` (circulation_policy + visibility) + RLS catalogue public + alignement spec-flux-consultations + frontend consultation (suite §6.1 de la spec granularité). Recouvre la parité **P1** (flux exemplaires-lot, édition depuis la file, delete→RPC).
3. **Lot sources externes** — 8.C (activer LoC, ajouter BN Brasil + Wikidata/Open Library) + 8.B (authority_lookup cross-lingue) + **module capas** (§5, `cover_lookup`). *Trois EF jumelles, un patron ; Open Library/Wikidata mutualisés.*
4. **Lot assistances Book restantes** (P2) — suggestions CDD/coleção/sujets, lecture des recursos digitais.

> **Dépendances DB / doctrine à ne pas oublier :** migrations (circulation_policy + visibility sur `exemplares` ; éventuel index variantes d'autorité) → **déploiement Woodpecker**, pas MCP ; **RLS** archive `staff_only` ; **REVOKE** sur fonctions privées ; **i18n 8 locales** pour chaque libellé nouveau ; alignement **spec-flux-consultations** pour 8.D.

---

## 10. Questions ouvertes (mise à jour)

Q1–Q8 ci-dessus (§7) + :

- **Q9 — Circulation :** modèle 2 colonnes (`circulation_policy` + `visibility`) validé, ou enum unique à 4 ? Et : l'« archive staff_only » est-elle bien une **visibilité** (peut rester empruntable en interne ?) ou un état figé non-circulant ?
- **Q10 — Doctrine doublon :** blocage **dur** confirmé sur *ISBN identique déjà publié dans le périmètre* ? Et le périmètre = biblio locale, ou réseau entier (fiche commune partagée) ?
- **Q11 — Paliers :** valides-tu le découpage simple/avancé/complet du tableau 8.H, ou ajustements ?
- **Q12 — Sources prioritaires :** au-delà de LoC + BN Brasil + Wikidata + Open Library, lesquelles veux-tu en cible (WorldCat clé OCLC ? K10plus ? SUDOC ? RGB/RNB russe ?) ?
- **Q13 — Maquette :** veux-tu que je produise une **maquette visuelle** de la fiche redessinée (paliers + relief des champs) avant la spec niveau 2 ?

---

*Fin du cadrage. Prochaine étape sur tes arbitrages (Q1, Q9–Q13) : spec niveau 2 du/des lot(s) retenu(s).*
