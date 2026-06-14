# CADRAGE — EX-3 : Réception d'un lot de fonds (ré-import du ZIP)

| | |
|---|---|
| **Genre** | cadrage (framing — non normatif tant que non ratifié au REGISTRE) |
| **Date** | 14 juin 2026 |
| **Statut** | 🟢 v0.2 — **TRANCHÉ (Xavier 14/06)** : **piste A** retenue ; la **brique « création/attache d'asset » est sortie en chantier dédié** (« gestion des fichiers numériques »). EX-3 livre donc les étapes 1–4 de A (réception + dépôt + parking des fichiers) ; l'attache au livre suit. Implémenté commit ⟨EX-3⟩. |
| **Chantier** | Importações/Exportações — face **Import**, réception du niveau 2 (lots) |
| **Réfère à** | `CADRAGE_export_fonds_numeriques_2026-06-12.md` (P4 : ZIP → ré-import manuel) ; pipeline `ingest` ; EF `export-fonds-bundle` (producteur du ZIP) ; table `digital_assets`. |

## 0. Rappel — ce que produit l'export (EX-2)
L'EF `export-fonds-bundle` produit un ZIP `anarbib-fonds-export/v1` :
- `notices.<ext>` — notices sérialisées (CSV / MARCXML / JSON), via `serialize.ts`.
- `manifest.json` — `{ schema, library_id, eligibility, notice_count, file_count, truncated,
  records:[ { …notice…, assets:[ { asset_id, kind, title, mime, rights_status, checksum_sha256,
  source_name, source_license_name, attribution_text, file:"files/<asset_id>_<nom>" } ] } ] }`.
- `files/<asset_id>_<nom>` — les fichiers numériques (uniquement `public_domain_confirmed`, P3).

## 1. État des briques (cartographie 14/06)
### ✅ Réutilisable tel quel — le volet NOTICES
Le pipeline d'import partenaire est mûr et **ré-importe déjà les notices sans une ligne de code neuve** :
`fn_import_create` → `fn_import_dispatch` → EF `process-partner-catalog-import` (parse CSV/MARCXML/RIS/JSON
→ `ingest.partner_catalog_staging_rows`) → matching ISBN (`fn_match_partner_catalog_run`) → revue →
`fn_import_promote` → `fn_bulk_create_book_drafts_from_run` → `public.book_drafts`. Le `notices.<ext>`
du ZIP est un fichier catalogue standard : il **passe dans le wizard actuel** (`/importacoes/novo`).

### ❌ Greenfield — le volet FICHIERS / `digital_assets`
Trois constats durs (vérifiés 14/06) :
1. **Le pipeline import ne crée jamais de `digital_assets`** ni ne dépose de fichier (que des métadonnées).
2. **Il n'existe AUCUN point d'entrée applicatif pour *créer* un `digital_asset`** : zéro `INSERT INTO
   digital_assets` en SQL, zéro insert frontend (le front ne fait que **lire** les assets —
   `get_book_primary_public_digital_asset_v2` — et `fn_ill_transmit` consomme un asset *existant*).
   ⇒ la création d'asset est aujourd'hui hors-app (dashboard / import historique). **Il n'y a donc
   pas de « flux catalogação » d'attache de fichier sur lequel se brancher proprement.**
3. **Contrainte de séquencement** : `digital_assets.book_id → public.books(id)` (bigint), pas
   `book_drafts`. Un asset ne peut être créé/lié **qu'après promotion du draft en livre**.
4. **Contrainte de bucket** : `digital_assets.bucket_name` est limité par CHECK aux **4 buckets finaux**
   (`pdf-restrito`, `anarbib-pdf-public`, `anarbib-media-restricted`, `anarbib-media-public`) + un CHECK
   `asset_kind ↔ bucket`. Le bucket de réception `partner-catalog-deposits` (existant) **ne peut pas**
   porter un `digital_asset` → un fichier reçu doit transiter par le dépôt **puis être déplacé** vers
   un bucket final au moment de la création de l'asset.

## 2. Décisions transverses (quelle que soit la piste)
- **D-A — `rights_status` à la réception.** Le manifeste affirme `public_domain_confirmed` (P3 côté
  source). À la réception : **(i)** l'accepter tel quel (confiance fédérale, zéro friction) **ou**
  **(ii) forcer `to_review`** → la réceptrice re-confirme avant publication (prudent, cohérent ILL-5
  « cataloguer = affirmer libre de droits »). **Reco : (ii)**.
- **D-B — Bucket de réception.** Les fichiers du ZIP atterrissent dans `partner-catalog-deposits`
  (staging), puis sont déplacés vers `anarbib-pdf-public` / `anarbib-media-public` (public, P3) à la
  création de l'asset. **Reco : oui**.
- **D-C — Provenance.** Le manifeste porte `source_name / source_license_name / attribution_text` :
  la provenance **voyage avec** le lot (cohérent cadrage §5) et doit être recopiée dans l'asset.

## 3. Les trois pistes
### Piste A — « Dépôt + report en catalogação » (MVP, colle à P4)
Le wizard accepte le ZIP : détecte `manifest.json`, ré-importe `notices.<ext>` par le pipeline existant
(→ `book_drafts`, **inchangé**) ; les `files/` sont **déposés dans `partner-catalog-deposits`** et les
métadonnées d'asset du manifeste sont **portées dans le staging/draft** (`raw_payload` /
`provenance_note`). La création du `digital_asset` (déplacement vers bucket final + insert) se fait
**plus tard**, à la finalisation du livre.
- **Neuf** : extension parse-ZIP (détecter+extraire manifest+files), dépôt des fichiers, transport des
  métadonnées d'asset dans le staging. **+ il faut quand même bâtir l'étape d'attache** (cf. constat
  #2 : elle n'existe pas) — ce qui rapproche A de B sur ce point.
- **Effort** : moyen. **Risque** : faible-moyen. **Limite** : sans flux d'attache existant, la promesse
  « report en catalogação » suppose de **créer** ce flux (mini-RPC `fn_create_digital_asset` + UI bouton
  « attacher le fichier reçu » sur la fiche). À chiffrer.

### Piste B — Réception 100 % automatisée (EF dédiée)
EF `receive-fonds-bundle` : dézippe, stage les notices, dépose les fichiers, **et auto-crée les
`digital_assets`** en se branchant sur la promotion draft→livre (hook : à la création du `book`,
matcher les assets en attente par `asset_id` et les attacher + déplacer vers bucket final).
- **Neuf** : EF d'orchestration + table d'assets-en-attente (staging d'assets) + hook de promotion +
  RPC de création d'asset + gestion buckets/SHA/idempotence.
- **Effort** : élevé. **Risque** : élevé (surface bug, storage, séquencement). **Atout** : zéro geste
  manuel côté réceptrice ; pose aussi la **brique de création d'asset** qui manque globalement à l'app.

### Piste C — Notices seules (interim, zéro code)
On **documente** que la réception MVP = la companheira ré-importe `notices.<ext>` par le wizard actuel ;
les `files/` sont traités plus tard/manuellement (téléversés à la main). Débloque l'usage immédiatement.
- **Effort** : nul (doc). **Risque** : nul. **Limite** : la valeur du niveau 2 (fichiers) reste manuelle.

## 4. Recommandation
**A** comme cible, mais en assumant qu'elle **inclut la création de la brique d'attache d'asset** (qui
n'existe pas) — donc A ≈ « B allégé sans hook de promotion auto ». Concrètement : (1) parse-ZIP +
dépôt fichiers + métadonnées en staging ; (2) **nouvelle** RPC `fn_create_digital_asset` (déplacement
dépôt→bucket final + insert, `rights_status='to_review'`, provenance recopiée) ; (3) petit bouton UI
« attacher les fichiers reçus » sur la fiche livre. Si l'on veut livrer vite : **C maintenant**, **A
ensuite**. **B** seulement si Xavier veut le zéro-geste et accepte le coût.

## 5. À trancher (Xavier)
- Piste **A / B / C** ?
- D-A : `rights_status` reçu = `to_review` (reco) ou accepté tel quel ?
- Périmètre de la brique « création d'asset » (la construire dans EX-3, ou la sortir en chantier
  « gestion des fichiers numériques » distinct, vu qu'elle manque à toute l'app) ?
