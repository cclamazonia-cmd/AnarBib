# CADRAGE — Lecteur ePub : intégration à AnarBib + version CCLA conservée

> **Date** : 2026-06-16
> **Auteur** : Claude (assistant·e)
> **Session** : Lecteur ePub — intégration AnarBib/CCLA — cadrage *(nom provisoire, à confirmer par la coordination)*
> **Statut** : Cadrage ouvert — diagnostic posé + 3 décisions de principe prises avec Xavier (§3). **Rien n'est encore implémenté ; la Phase 1 est explicitement bloquée tant que Xavier n'a pas dit « voie libre ».**
> **Préséance** : ce document **cadre** un chantier (état des lieux + archi cible + plan). Ce qui fait **doctrine** reste dans [`../../specs/REGISTRE_decisions.md`](../../specs/REGISTRE_decisions.md). Toute décision d'architecture (modèle de persistance, valeurs `resource_type`, bucket ePub, moteur) devra y être actée avant d'être considérée comme normative.

---

## 0. Avertissement de méthode (à lire avant de coder)

- **Diagnostic établi par audit de code statique** sur les deux dépôts :
  - **AnarBib** : `src/pages/public/ReaderPage.jsx`, `src/components/viewers/*`, `supabase/functions/read-digital-asset/index.ts`, `docs/multiformat-viewers.md`.
  - **CCLA** : dépôt `github.com/cclamazonia-cmd/editora-ccla` (analyse de `index.html` + `epub.min.js` + `jszip.min.js`).
- **Référentiel canonique = WSL2 `~/anarbib` sur `main`.** Au moment de l'audit, le repo WSL est `main ahead 1` (commit `f1e1af15`), working tree sale d'une **autre session** (`pt-BR.json` modifié + `_handoff/`). La **copie Windows** (`C:\Users\accat\…`) est **divergente et périmée** (branche `mobile-phase-a`, remotes encore configurés sur GitHub, dossier `docs/decisions/` fantôme) — **ne pas s'y fier ni y écrire** (règle d'or `CLAUDE.md`, mémoire « copie Windows souvent périmée »).
- **Le dossier `docs/decisions/` est DÉPRÉCIÉ** (commit `829e3f8b docs: reorganize decisions/ -> journal/ with strict type subfolders`). Les cadrages vivent dans `docs/journal/cadrages/` — d'où l'emplacement de ce fichier.
- **Séquencement gated.** Phase 1 (AnarBib) ne démarre **que** sur feu vert explicite de Xavier (sérialisation des push, autres sessions actives sur `main`). Phase 2 (CCLA) seulement après Phase 1 éprouvée en prod.

---

## 1. Contexte & enjeu

Xavier a conçu il y a quelques mois un **lecteur ePub pour le CCLA** (dépôt `editora-ccla`), aujourd'hui autonome et déployé sur le blog CCLA (« Biblioteca »). Objectif du chantier :

1. **Intégrer intelligemment** ce lecteur à AnarBib — concrètement, combler le **trou ePub** de la page de lecture `/ler` (`ReaderPage`), déjà documenté comme « viewer à créer » dans `docs/multiformat-viewers.md` (l. 16 et 137).
2. **Le rendre plus propre et fonctionnel** (refactor du moteur monolithique en un module réutilisable).
3. **Conserver une version standalone pour le CCLA** (le blog garde son lecteur avec catalogue + accès par mot de passe).

L'enjeu « propreté » est explicite : on veut que **les deux** soient le plus propres possible — d'où le choix d'un **cœur partagé** (§3).

---

## 2. État des lieux — les deux pièces

### 2.1 `editora-ccla` (le lecteur CCLA actuel)

Un seul `index.html` + `epub.min.js` (epub.js) + `jszip.min.js`. **Zéro build, zéro backend, tout en `localStorage`.** Malgré l'emballage minimal, le **moteur de lecture est riche** :

| Capacité | Détail |
|---|---|
| Rendu | epub.js, rendition paginée (CFI), iframe |
| Navigation | clavier (flèches/espace), zones tap gauche/droite, chapitre début/fin, TOC en tiroir |
| Préférences | taille police (80–200 %), interligne, marges (3 modes), serif/sans, justification, césure |
| Thème | clair/sombre via variables CSS + **injection CSS « dure » dans l'iframe** (mate le CSS de l'éditeur) |
| Progression | index de *locations* CFI, barre + slider, % et page X/Y, reprise de position |
| Temps de lecture | accumulation par tranches de 30 s, persistée par livre |
| Notes | détection des renvois, **modale de note** (style Calibre), pile de retour |
| Confort | mode zen (auto-hide UI), plein écran, double-page desktop (≥ 980 px) |

**CCLA-spécifique (à NE PAS porter tel quel dans AnarBib)** : catalogue intégré (BOOKS_PUBLIC/PRIVATE), **mot de passe SHA-256 côté client**, bouton retour-blog, tout en `localStorage`.

### 2.2 AnarBib — `ReaderPage` (lecteur multi-format unique, v3.0)

`/ler/:id` (ou `/ler-recurso?asset_id=X`). *Dispatch* sur `viewer_kind` renvoyé par l'Edge Function `read-digital-asset` :

| `viewer_kind` | Composant | Statut |
|---|---|---|
| `pdf` | rendu pdf.js interne (scroll continu, filigrane) | ✅ prod |
| `audio` / `video` / `image` | `AudioPlayer` / `VideoPlayer` / `ImageViewer` | ✅ code prêt |
| `external_link` / `generic` | notice + lien | ✅ |
| **`epub`** | **— (tombe en `generic`, fallback « ouvrir ») —** | ⏳ **trou** |

Ce qu'AnarBib apporte et que le CCLA n'a pas :
- **Contrôle d'accès serveur** : RPC `get_accessible_digital_asset_by_id_v2` (permission/scope/compte actif) + **URL signée** (TTL 900 s).
- **Filigrane** `AnarBib · {biblio} · {email}` — *élément central* de l'anti-DRB honnête (`multiformat-viewers.md` §« Anti-DRM honnête »).
- **Hook anti-copie** scopé au viewer (`useViewerCopyProtection`).
- **i18n** : à ce jour **10 locales** (DOC-I18N-1 ; le `multiformat-viewers.md` dit « 6 » → trace périmée).
- Thème de l'app, `LocaleSwitcher`.

### 2.3 Modèle de données (corrigé après lecture de `multiformat-viewers.md`)

- **Table active = `book_digital_resources`** (7 lignes prod). `resource_type` ∈ `{pdf_publico, pdf_restrito, audio, video, image, link_externo, recurso_digital}`. **Pas de valeur `epub`.**
- `digital_assets` = table héritée morte (1 ligne, non utilisée) — malgré le nom de la RPC `get_accessible_digital_asset_by_id_v2`, le dispatch lit bien `book_digital_resources` (les valeurs `resource_type` de `inferViewerKind` le confirment).
- Buckets Storage : `anarbib-pdf-public`, `pdf-restrito`, `anarbib-media-public`, `anarbib-media-restricted`. Contrainte `…_kind_bucket_chk` (cohérence kind ↔ bucket). **Aucun bucket ePub.**

➡️ **Conséquence** : activer l'ePub de bout en bout n'est PAS « 1 ligne ». Le *dispatch* l'est (§4.3) ; mais **cataloguer** un ePub exige une **migration** (valeur(s) `resource_type` + bucket + contrainte), et la persistance serveur (§3) ajoute une table + RPC.

---

## 3. Décisions de principe prises avec Xavier (16/06)

> Ces trois choix orientent l'archi. Ils restent **non-normatifs** tant que non actés au REGISTRE (§7).

- **D-EPUB-1 — Cœur partagé (moteur/coquille), séquencé en 2 phases.** *Reco de l'assistant·e validée.* On n'extrait PAS « un composant partagé » (couplage) mais on isole un **moteur de lecture pur** (epub.js, sans React ni dépendance AnarBib/CCLA), avec **deux coquilles minces** par-dessus (AnarBib React + CCLA vanilla). On séquence : **AnarBib d'abord** (le moteur s'éprouve en prod), **CCLA s'aligne ensuite** (vendore le moteur buildé, dégraisse son `index.html`). Argument clé : la persistance (serveur chez AnarBib, `localStorage` chez CCLA) devient **une affaire de coquille, pas de moteur** → le choix D-EPUB-2 *renforce* la pertinence du cœur partagé.
- **D-EPUB-2 — Persistance de lecture CÔTÉ SERVEUR par utilisateur·rice.** Reprise multi-appareils (vraie fonctionnalité « bibliothèque »). Implique migration + table + RLS + RPC (§4.4). Le CCLA, lui, reste en `localStorage` (sa coquille).
- **D-EPUB-3 — Port COMPLET d'emblée.** La v1 intégrée vise la parité fonctionnelle avec le CCLA (TOC, thèmes, polices, **notes en modale**, **temps de lecture**, zen, **double-page**, progression/reprise), pas un sous-ensemble.

---

## 4. Architecture cible

### 4.1 Le moteur — `src/lib/reader/epubEngine.js` (pur, réutilisable)

ESM pur, **aucun** import React / AnarBib / CCLA. Source de vérité dans AnarBib (Codeberg). N'expose que :

- **Commandes** : `mount(container, bookSource)`, `destroy()`, `applyTheme({bg, fg, link})`, `applyPrefs({fontPct, lineHeight, margin, fontMode, justify, hyphen})`, `goTo(cfiOrHref)`, `next()`, `prev()`, `chapterStart()`, `chapterEnd()`, `ensureLocations()`, `getToc()`.
- **Événements** : `onReady`, `onRelocate({cfi, percent, page, total})`, `onTick(seconds)`, `onNote(html)`.
- Reprise du **CSS dur** + hooks iframe du CCLA (langue, override de style, détection des notes).

Tout ce qui touche **persistance / auth / i18n / filigrane / catalogue / mot de passe = HORS moteur** → coquilles.

### 4.2 Coquille AnarBib — `src/components/viewers/EpubReader.jsx`

Frère de `AudioPlayer`/`VideoPlayer`/`ImageViewer`/`PdfViewer`. Monte le moteur et :
- injecte **filigrane + anti-copie DANS l'iframe** (la zone de texte epub.js est une iframe : le filigrane email/timestamp doit y être superposé — c'est l'élément central de l'anti-DRB honnête) ;
- mappe le thème sur les tokens AnarBib, traduit les libellés (react-intl, **10 locales**) ;
- **persiste la position côté serveur** (débouncé) via les events `onRelocate`/`onTick` → RPC (§4.4).
- Branché dans `ReaderPage` sur `viewerKind === 'epub' && accessUrl`.

> Nom retenu : `EpubReader` (cohérent avec `docs/multiformat-viewers.md` l.137). Les frères sont des `*Player`/`*Viewer` ; `EpubReader` est acceptable et déjà nommé dans la doc.

### 4.3 Backend — dispatch (le vrai « 1 ligne »)

Dans `inferViewerKind` (`supabase/functions/read-digital-asset/index.ts:30`) :

```ts
if (mt === "application/epub+zip" || su.endsWith(".epub")) return "epub";
```

Toute la machinerie d'URL signée + permissions marche déjà pour n'importe quel fichier de Storage.

### 4.4 Backend — cataloguage ePub + persistance serveur (migration)

Conforme à la doctrine SQL (DOC-OBJ-2, DOC-RPC-3, `_TEMPLATE.sql`, skill `anarbib-sql`) :

1. **`resource_type` ePub** : ajouter la/les valeur(s) à la contrainte de `book_digital_resources` (cf. décision ouverte D-EPUB-A) + cohérence `…_kind_bucket_chk`.
2. **Bucket ePub** : décider du couple de buckets (cf. D-EPUB-B).
3. **Table de progression** (D-EPUB-2) — proposition : générique pour servir aussi audio/vidéo demain.
   - `public.reading_progress (user_id, resource_id, book_id, position jsonb /* {cfi, percent, page, total} */, reading_seconds int, updated_at)`, clé `(user_id, resource_id)`.
   - **RLS** stricte : chacun·e ne voit/écrit que ses lignes (tests DOC-RLS-1 : `SET LOCAL ROLE` + `request.jwt.claims`).
   - **RPC** `upsert_reading_progress(...)` / `get_reading_progress(p_resource_id)` (écritures par RPC — DOC-RPC-3), `SECURITY DEFINER` + `search_path` figé + `REVOKE … FROM PUBLIC, anon, service_role` (DOC-OBJ-2).
4. **Horodatage UTC exact** du fichier de migration, vérifié contre le max du dossier (règle dure `CLAUDE.md` ; mémoire « piège horodatage sessions parallèles »).
5. **Déploiement** : push → **Forgejo Actions** déploie migration + edge (DOC-DEPLOY-1 ; le REGISTRE dit encore « Woodpecker » → migré le 11/06). **Jamais** `apply_migration` MCP ni SQL Editor avant push (DOC-DEPLOY-3).

### 4.5 Coquille CCLA (Phase 2) — `index.html` allégé

Vendore le moteur buildé (Vite émet un fichier unique ESM, chargé en `<script type="module">` → le CCLA garde sa simplicité « page statique »). Garde **sa** coquille : catalogue + mot de passe SHA-256 + `localStorage`. Zéro duplication du cœur.

---

## 5. Plan de traitement proposé

> Discipline DOC-CLOSE-1 (« close before open ») : chaque paquet committé + vérifié (`npm run build`, test i18n) avant le suivant ; push sérialisés (jamais 2 concurrents).

### Phase 1 — AnarBib (sur feu vert explicite, branche dédiée depuis `main`)

| # | Paquet | Contenu |
|---|---|---|
| P1 | **Moteur** | `src/lib/reader/epubEngine.js` extrait du CCLA, *shared-ready*, dépendance npm `epubjs`. Banc d'essai avec un `.epub` d'exemple. |
| P2 | **Coquille React** | `src/components/viewers/EpubReader.jsx` + CSS : filigrane/anti-copie dans l'iframe, thème, i18n (clés `reader.epub.*` × 10 locales), toolbar (port complet : TOC, polices, thème, notes, temps, zen, double-page). |
| P3 | **Dispatch** | +1 ligne `inferViewerKind` + branche `viewerKind === 'epub'` dans `ReaderPage.jsx`. |
| P4 | **Backend cataloguage + persistance** | Migration : `resource_type` ePub + bucket + `reading_progress` + RPC (RLS, doctrine). Câblage `onRelocate`/`onTick` → RPC. |
| P5 | **Vérif + doc** | Test navigateur sur `.epub` réel ; MAJ `docs/multiformat-viewers.md` (l.16/137) ; entrée REGISTRE pour les décisions actées ; MAJ backlog. |

### Phase 2 — CCLA (après Phase 1 éprouvée en prod)

| # | Paquet | Contenu |
|---|---|---|
| P6 | **Build moteur** | Cible Vite émettant le moteur en fichier unique pour vendoring CCLA. |
| P7 | **Dégraissage CCLA** | `index.html` réduit à sa coquille (catalogue + mot de passe + `localStorage`), lecture déléguée au moteur partagé. |

---

## 6. Risques connus

1. **epub.js + Vite** : lib un peu ancienne (globals, JSZip) — à valider en build dès P1.
2. **Filigrane/anti-copie dans l'iframe** : la zone epub.js est une iframe ; le filigrane doit y être injecté (le CCLA fait déjà l'injection CSS dure → on s'appuie dessus). À tester explicitement.
3. **URL signée 900 s** : OK car epub.js *fetch* le fichier immédiatement ; vérifier qu'aucune relecture tardive du blob n'est nécessaire.
4. **Sessions parallèles sur `main`** : push sérialisés, horodatage de migration exact, staging explicite de ses seuls fichiers (mémoire « worktree partagé — git add sweep »).
5. **Cross-repo (Phase 2)** : packaging GitHub(CCLA) ↔ Codeberg(AnarBib) — dé-risqué par le séquencement (vendoring d'un artefact buildé, pas de submodule/monorepo).

---

## 7. Points à trancher (décisions ouvertes pour le REGISTRE)

- **D-EPUB-A — Nommage `resource_type`** : `epub` unique + `access_scope` (comme audio/vidéo/image) **vs** paire `epub_publico`/`epub_restrito` (comme PDF) ? → 🟢 **Reco retenue (Xavier, 17/06, sauf objection) : `epub` unique + `access_scope`** — aligné sur audio/vidéo/image, aucun enjeu de sécurité (pure cohérence de catalogage).
- **D-EPUB-B — Bucket ePub** : nouveau couple `anarbib-epub-public` / `anarbib-epub-restricted` **vs** réutiliser les buckets `media` ? → ✅ **Tranché 17/06 (Xavier) — couple dédié**, priorité anti-fuite : `anarbib-epub-restricted` RLS-gated + garde-fou kind↔bucket. *(Doctrine anti-DRM honnête maintenue : gating d'accès + filigrane attributif, jamais présenté comme DRM absolu.)*
- **D-EPUB-C — Granularité de la progression** : clé sur `resource_id` (un CFI n'a de sens que pour un fichier ePub précis) avec `book_id` dénormalisé pour l'UX « reprendre ». *(Reco : oui, clé `resource_id`.)*
- **D-EPUB-D — Généraliser la persistance serveur** aux bookmarks audio/vidéo (aujourd'hui en `localStorage`) ? *(Reco : table `reading_progress` générique dès maintenant, migration audio/vidéo plus tard hors périmètre.)*
- **D-EPUB-E — Moteur** : rester sur **epub.js** (réutilise le CCLA) vs migrer vers **foliate-js** (plus moderne) ? *(Reco : epub.js — réutilisation directe, le « propre » vient du découpage moteur/coquille, pas du changement de lib.)*

---

## 8. Liens

- Doctrine : [`../../specs/REGISTRE_decisions.md`](../../specs/REGISTRE_decisions.md)
- Viewer multi-format (trou ePub déjà tracé) : [`../../multiformat-viewers.md`](../../multiformat-viewers.md)
- Cadrage mobile (même journée, axe distinct) : [`CADRAGE_mobile_responsive_2026-06-16.md`](CADRAGE_mobile_responsive_2026-06-16.md)
- Code : `src/pages/public/ReaderPage.jsx` · `src/components/viewers/` · `supabase/functions/read-digital-asset/index.ts`
- Dépôt CCLA : `github.com/cclamazonia-cmd/editora-ccla`

---

## 9. Mise à jour — sonde de validation (2026-06-17) : **archi VALIDÉE, API figée**

Une **sonde React+Vite hors-worktree** (`~/epub-react`) a été construite et éprouvée (Chrome-MCP) : moteur pur `epubEngine.js` (factory + événements) + coquille `EpubReader.jsx` calquée sur `AudioPlayer`. **Xavier a validé le découpage moteur/coquille et l'API le 17/06 → API figée.**

**Vérifié bout en bout** (sur `riacho.epub` + `economia-libertaria.epub`) : rendu, navigation, thème clair/sombre (chrome + iframe), polices/justif/césure/marges, sommaire cliquable, progression (saut % correct), reprise de position, double-page/plein écran/zen, **filigrane + anti-copie injectés dans l'iframe via `onContent`**, et surtout **notes cross-file** (renvoi → résolution dans un autre fichier → modale, avec nettoyage DOM des liens de retour `[←1]`).

**Enseignements à reporter en Phase 1 :**
- ✅ `epubjs@0.3.93` s'installe et bundle dans **Vite 6** sans souci (warns transitifs `@xmldom/xmldom@0.7.13` → revue sécu).
- ⚠️ epub.js pilote sa file de rendu via **`requestAnimationFrame`** → `display()` **gèle dans un onglet masqué** (artefact de vérif automatisée/CDP ; **bénin** en prod, onglet visible). Ne PAS conclure « bug » sans vérifier la visibilité.
- ⚠️ **Ne pas** mettre `define:{global:'globalThis'}` dans `vite.config` (inutile, casse la détection d'env de libs).
- Le nettoyage des liens de retour de notes via **suppression DOM sur clone** (back-link `doc-backlink`/flèches `←1`/`retour`/`voltar`/marqueurs `[1]`) est plus robuste que le regex d'origine — corrigé dans le moteur.

**Décisions confirmées** : D-EPUB-1/2/3 (cœur partagé 2 phases · persistance serveur · port complet). Filigrane réel = `AnarBib · {biblio} · {email}`. Icônes nues de la sonde → **libellés/tooltips i18n 10 locales** en Phase 1.

**Reste (Phase 1, worktree — GELÉ jusqu'au « voie libre » de Xavier)** : branche dédiée depuis `main` ; promotion `epubEngine.js` (sans échafaudage : shim rAF, logs, `window.__epubEngine`) + `EpubReader.jsx` (i18n, filigrane réel, persistance serveur) dans `src/` ; +1 ligne `inferViewerKind` ; migration `resource_type` epub + bucket + table `reading_progress` (RLS/RPC, cf. §7) ; MAJ `multiformat-viewers.md` + entrée REGISTRE.
