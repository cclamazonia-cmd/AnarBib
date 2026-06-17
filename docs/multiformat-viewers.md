# Viewer multi-format AnarBib

> *Dernière mise à jour : 2026-05-08*
> *État : opérationnel pour PDF en production. Audio / vidéo / image disponibles côté code, à activer en cataloguation.*

## Vue d'ensemble

`ReaderPage` (route `/ler/:id` ou `/ler-recurso?asset_id=X`) est le **lecteur multi-format unique** d'AnarBib. Il s'adapte automatiquement au type d'asset numérique stocké en base :

| `asset_kind` (base) | `viewer_kind` (Edge Function) | Composant frontend | Statut |
|---|---|---|---|
| `pdf` | `pdf` | `<ReaderPage>` (rendu interne, scroll continu, filigrane) | ✅ Production |
| `audio` | `audio` | `<AudioPlayer />` | ✅ Code prêt, pas d'asset en base |
| `video` | `video` | `<VideoPlayer />` | ✅ Code prêt, pas d'asset en base |
| `image` | `image` | `<ImageViewer />` | ✅ Code prêt, pas d'asset en base |
| `epub` | `epub` | `<EpubReader />` (moteur partagé `epubEngine` + epub.js ; filigrane, anti-copie, reprise serveur) | ✅ Branche `lecteur-epub` (17/06/2026) |
| `archive` | (mappé sur `generic`) | Fallback "télécharger" | ⏳ Viewer à créer |
| `external_link` | `external_link` | Notice + bouton "ouvrir le site" | ✅ Code prêt |
| `generic` | `generic` | Fallback "ouvrir dans nouvel onglet" | ✅ Code prêt |

## Architecture des données

### Tables impliquées

- **`book_digital_resources`** (table active, 7 lignes en production) : la table que la cataloguation et la lecture utilisent réellement. Champ `resource_type` accepte : `pdf_publico`, `pdf_restrito`, `audio`, `video`, `image`, `link_externo`, `recurso_digital`.

- **`digital_assets`** (table héritée, 1 ligne, **non utilisée**) : fragment d'une refonte abandonnée. À supprimer du schéma quand on aura le temps. Notre migration session 3 (2026-05-08) a élargi ses contraintes pour cohérence, mais sans effet pratique.

### Buckets Supabase Storage

| Bucket | Visibilité | Types acceptés |
|---|---|---|
| `anarbib-pdf-public` | Public | PDF |
| `pdf-restrito` | Restreint (RLS) | PDF |
| `anarbib-media-public` | Public | Audio, vidéo, image |
| `anarbib-media-restricted` | Restreint (RLS) | Audio, vidéo, image |

Une contrainte `digital_assets_kind_bucket_chk` garantit la cohérence `asset_kind` ↔ `bucket_name` au niveau base (impossible de mettre un MP3 dans un bucket PDF par accident).

## Cataloguer un asset audio / vidéo / image

> ⚠ Cette procédure est manuelle pour l'instant. La page `CatalogacaoPage` ne propose pas encore d'upload pour ces formats. Voir le backlog "extension cataloguation multi-format".

### Étape 1 — Uploader le fichier dans Supabase Storage

Via le dashboard Supabase Storage :

- Choisir le bucket adapté : `anarbib-media-public` pour les contenus libres, `anarbib-media-restricted` pour les contenus à diffusion contrôlée
- Convention de chemin : `books/{slug-du-livre}/{nom-du-fichier}.{ext}`
- Formats supportés : `.mp3`, `.ogg`, `.flac`, `.m4a` (audio) ; `.mp4`, `.webm` (vidéo) ; `.jpg`, `.png`, `.webp`, `.gif` (image)

### Étape 2 — Insérer une ligne dans `book_digital_resources`

```sql
INSERT INTO public.book_digital_resources (
  book_id,
  resource_type,        -- 'audio', 'video' ou 'image'
  usage_type,           -- 'escuta_online' (audio), 'visualizacao_online' (vidéo/image)
  access_scope,         -- 'publico' ou 'conta_ativa'
  status,               -- 'active'
  is_active,            -- true
  storage_bucket,       -- 'anarbib-media-public' ou 'anarbib-media-restricted'
  storage_path,         -- 'books/{slug}/{file}.{ext}'
  mime_type,            -- 'audio/mpeg', 'video/mp4', 'image/png', etc.
  label,                -- libellé affiché dans le viewer
  language_code,        -- 'pt-BR', 'fr', etc.
  source_name,          -- ex: 'Radio Libertaire'
  source_url,           -- URL de l'enregistrement original si applicable
  attribution_text,     -- texte d'attribution complet
  rights_status,        -- 'public_domain_confirmed', 'source_reuse_allowed', etc.
  is_primary,           -- true si c'est la ressource principale du livre
  bibliographic_match_validated  -- true (sinon RPC primary_public ne le retournera pas)
) VALUES (
  ...
);
```

### Étape 3 — Vérifier en frontend

Naviguer vers `/ler/{book_id}?asset_id={resource_id}` ou `/ler/{book_id}` (RPC primary). Le bon viewer doit s'afficher selon le type.

## Capacités des viewers

### `<AudioPlayer />`

- Chargement en blob (URL signée jamais exposée au DOM)
- Contrôles : play/pause, scrub, volume, mute, vitesse cyclique (0.5× → 2×), saut ±10s
- Bookmark de position : sauvegarde toutes les 2s en `localStorage` (clé `anarbib.audio.{asset-id}`)
- Filigrane optionnel (texte répété en arrière-plan)
- Plein écran
- i18n : 16 clés × 6 locales

### `<VideoPlayer />`

- Idem audio + visualisation vidéo (ratio 16:9 par défaut, `object-fit: contain`)
- Filigrane **par-dessus l'image** (capturable avec n'importe quelle capture d'écran)
- Auto-hide des contrôles en plein écran après 2.5s d'inactivité
- API sous-titres `.vtt` prête (champ `tracks` non encore exposé en cataloguation)
- `playsInline` pour iOS Safari
- i18n : 18 clés × 6 locales

### `<ImageViewer />`

- Zoom : mollette (centré sur curseur), boutons +/−, double-click toggle 1×↔2×
- Pan : glisser-déposer quand zoomé
- Reset : retour à l'échelle 1 centrée
- Plein écran
- Affichage des dimensions natives
- i18n : 12 clés × 6 locales

## Anti-DRM honnête

Tous les viewers AnarBib appliquent les **mêmes principes** de décourageant, jamais présentés comme un DRM :

**Ce qui est en place** :
- Chargement en blob (URL signée jamais visible)
- Clic droit / `Ctrl+S` / drag bloqués sur la zone du viewer (mais libres ailleurs sur la page)
- `controlsList="nodownload"` sur `<audio>` et `<video>` (Chrome/Edge respectent)
- `disablePictureInPicture` sur `<video>`
- `draggable=false` sur `<img>`
- Filigrane email/timestamp sur les contenus restreints

**Ce qui n'est PAS bloquable** (et qu'on ne prétend pas bloquer) :
- F12, capture d'écran, enregistrement d'écran, hooks WebAudio/MediaRecorder, etc.
- Les utilisateur·rices déterminé·es peuvent toujours capturer le contenu

Le filigrane est l'élément central : il **attribue** une fuite à la personne connectée, ce qui est cohérent avec une éthique militante — la confiance est rétablie par responsabilité, pas par chaîne technique.

## Limites connues

1. **Soft reload de langue sur ReaderPage** : la position de scroll dans le PDF (`.ab-reader-canvas-container`) n'est pas restaurée au changement de langue (seul `window.scrollY` l'est). Backlog : convention `data-scroll-restore="key"`.

2. **PDF page-par-page non disponible dans ReaderPage** : seul le scroll continu est implémenté. `<PdfViewer />` (utilisé en composant détaché) propose le mode page-par-page mais pas le scroll continu. Backlog : fusionner les deux logiques dans un composant unique avec switch.

3. **Sous-titres vidéo** : l'API existe (prop `tracks`) mais n'est pas branchée à `book_digital_resources` (pas de colonne pour les `.vtt`). Backlog : ajouter `subtitle_tracks JSONB`.

4. **EPUB** : ✅ livré (branche `lecteur-epub`, 17/06/2026). `<EpubReader />` (`src/components/viewers/`) sur le **moteur partagé** `src/lib/reader/epubEngine.js` (epub.js, framework-agnostic) : filigrane + anti-copie dans l'iframe, sommaire, thèmes/polices/marges, notes cross-file, double-page/zen/plein écran, et **reprise de lecture côté serveur** (`public.reading_progress` + RPC `api.fn_get/upsert_reading_progress`). Le même moteur alimentera la version standalone CCLA (Phase 2). **Archive** : tombe encore en `generic` — décompression côté client ou téléchargement direct (à arbitrer).

## Conventions militantes i18n

Toutes les clés des viewers sont traduites dans 6 locales avec respect des conventions :

- **pt-BR** : triple `(o/a/e)`, `dest(e/a)`, `d(o/a/e)` ; mots épicènes inchangés
- **fr** : point médian, accord total
- **es** : voseo argentin + neutre `e` (`compas`, `bibliotecarie`, `les autores`)
- **it** : `compagno o una compagna`, jamais `camerata`/`camerati`
- **de** : Genderstern (`Bibliothekar*in`, `Genoss*in`, `Autor*innen`), jamais "Compas" non traduit
- **en** : neutre quand possible, sinon `they/them`

## Voir aussi

- `docs/livre-blanc-v0.1.md` : section "Lecteur multi-format"
- `src/components/viewers/` : code source des composants
- `supabase/functions/read-digital-asset/` : Edge Function qui sert les URLs signées
