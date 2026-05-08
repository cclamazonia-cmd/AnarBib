<!--
  Section à insérer dans docs/livre-blanc-v0.1.md
  Position suggérée : après la section sur la cataloguation,
  ou dans la partie "Architecture frontend" si elle existe.
  À adapter selon le ton et la structure du Livre Blanc actuel.
-->

## Lecteur multi-format

### Contexte et choix politique

AnarBib propose une expérience de lecture en ligne **immersive et politiquement consciente** des contenus numériques mis à disposition par les bibliothèques du réseau. Le lecteur est conçu pour respecter trois principes simultanés :

1. **Accessibilité totale aux militant·es** : aucune barrière technique, formats variés (texte, audio, vidéo, image), interface multilingue avec conventions inclusives.
2. **Respect de la confiance** plutôt que DRM : on attribue les fuites par filigrane email/timestamp, on ne tente pas de les empêcher mécaniquement (ce qui serait à la fois techniquement vain et politiquement contradictoire).
3. **Code unique pour toute l'application** : un seul composant `ReaderPage`, branché sur tous les formats, accessible par une URL stable `/ler/:id`.

### Formats supportés

Le `viewer_kind` est calculé côté Edge Function (`read-digital-asset`) à partir du `resource_type` et du `mime_type` de la ressource :

| Format | Composant | Capacités |
|---|---|---|
| **PDF** | `ReaderPage` (rendu interne) | Scroll continu, IntersectionObserver, filigrane diagonal, fit-width, plein écran, navigation par numéro de page |
| **Audio** | `<AudioPlayer />` | Scrub, vitesse cyclique 0.5×–2×, saut ±10s, bookmark localStorage, filigrane décoratif |
| **Vidéo** | `<VideoPlayer />` | Idem audio + sous-titres `.vtt` (API prête), filigrane sur l'image, auto-hide contrôles en plein écran |
| **Image** | `<ImageViewer />` | Zoom mollette/boutons/double-click, pan, reset, dimensions natives, filigrane sur l'image |
| **Lien externe** | Notice + redirection | Avertissement "site externe" avant ouverture |
| **Type non reconnu** | Fallback | Ouverture nouvelle fenêtre |

### Architecture technique

```
URL : /ler/:id  ou  /ler-recurso?asset_id=X
        │
        ▼
┌──────────────────────────────────────────────┐
│  ReaderPage  (src/pages/public/ReaderPage)   │
│  ─ Récupère le titre du livre                │
│  ─ Appelle l'Edge Function read-digital-asset│
│  ─ Reçoit { viewer_kind, access_url, asset } │
└──────────────────────────────────────────────┘
        │
        ▼ dispatch sur viewer_kind
        │
        ├──── pdf       → rendu interne (scroll continu)
        ├──── audio     → <AudioPlayer />
        ├──── video     → <VideoPlayer />
        ├──── image     → <ImageViewer />
        ├──── ext_link  → notice + bouton ouvrir
        └──── generic   → fallback ouvrir
```

Tous les viewers respectent un **moule commun** :
- Chargement en blob (l'URL signée Supabase n'est jamais exposée au DOM)
- Scope d'anti-copie limité au conteneur viewer (clic droit / Ctrl+S / drag)
- Filigrane optionnel (`AnarBib · {libraryName} · {userEmail}`)
- i18n complète × 6 locales avec conventions militantes
- CSS cohérent (variables `--brand-*`, ratio 16:9 quand applicable)

### Migration depuis ResourcePage

Avant cette refonte, AnarBib avait deux pages de lecture :
- `ReaderPage` : lecteur PDF avec scroll continu et filigrane (UX immersive)
- `ResourcePage` : "lecteur multi-format" générique mais qui ne testait que le PDF

Cette dualité a été résolue en mai 2026 par la promotion de `ReaderPage` au rang de lecteur multi-format unique. `ResourcePage` a été déprécié et supprimé du repo. Les routes `/ler/:id` et `/ler-recurso?asset_id=X` pointent désormais toutes les deux vers `ReaderPage`, garantissant la rétro-compatibilité des liens existants.

### Stockage et contraintes

Les ressources sont stockées dans Supabase Storage :

- **`anarbib-pdf-public`** / **`pdf-restrito`** : PDF
- **`anarbib-media-public`** / **`anarbib-media-restricted`** : audio, vidéo, image

La cohérence `asset_kind` ↔ `bucket_name` est garantie au niveau base par la contrainte CHECK `digital_assets_kind_bucket_chk` (impossible de mettre un MP3 dans un bucket PDF par accident).

### État au jalon Livre Blanc v0.1

- ✅ Code des 4 viewers (PDF, Audio, Vidéo, Image) en place et testé sur PDF en production
- ✅ Edge Function `read-digital-asset` opérationnelle (8 versions déployées)
- ✅ Migration SQL appliquée (`asset_kind` élargi à 8 valeurs, contraintes cohérentes)
- ✅ i18n complète : 46 nouvelles clés × 6 locales pour les viewers, 14 pour `reader.*`
- ⏳ Aucun asset audio/vidéo/image en base (uniquement PDF) — tests en attente d'usages réels
- ⏳ Cataloguation manuelle pour ces formats (extension `CatalogacaoPage` au backlog)
- ⏳ EPUB et archive : viewers à créer (epub.js, ~1 j de dev)
- ⏳ Sous-titres vidéo : API frontend prête, schéma base à étendre

### Limites assumées

Le filigrane et l'anti-copie ne sont **pas** des protections absolues. Une personne déterminée peut toujours :
- Capturer l'écran (PrintScreen, outils OS)
- Enregistrer la vidéo/l'audio via un enregistreur d'écran
- Extraire le contenu via DevTools

Ce choix est politique : on attribue les fuites par filigrane (responsabilité collective) plutôt que de les empêcher (DRM, qui serait à la fois techniquement contournable et idéologiquement opposé à la libre circulation des savoirs militants). La confiance entre les bibliothèques et leurs lectrices·eurs reste le pilier de l'éthique de partage.
