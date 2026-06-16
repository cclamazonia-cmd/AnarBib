# CADRAGE — Chantier « Version mobile / responsive » d'AnarBib

> **Date** : 2026-06-16
> **Auteur** : Claude (assistant·e)
> **Session** : Chantier mobile / responsive — cadrage *(nom provisoire, à confirmer par la coordination)*
> **Statut** : Cadrage ouvert — diagnostic posé, **rien n'est encore implémenté**.
> **Préséance** : ce document **cadre** un chantier (liste de manques + plan). Ce qui
> fait **doctrine** reste dans [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md).
> Toute décision d'architecture (tokens de breakpoint, menu mobile, go/no-go PWA)
> devra y être actée avant d'être considérée comme normative.

---

## 0. Avertissement de méthode (à lire avant de coder)

- **Le diagnostic ci-dessous a été établi par audit de code statique** (4 passes
  parallèles : infrastructure CSS, app shell/navigation, écrans denses/tableaux,
  formulaires/modales/boutons), **pas** par test navigateur sur appareil réel.
  Chaque item porte une référence `fichier:ligne` à vérifier.
- **Les référentiels consultés étaient périmés — à deux niveaux** (incident de
  traçabilité noté pour mémoire). La copie Windows (HEAD 9 juin, `behind 188`) **et** la
  ref `codeberg/main` d'abord fetchée (15 juin 18:06) étaient en retard. Après `git fetch`
  frais, le **vrai HEAD est `ad2cee8` (15 juin 23:51)**. Le diagnostic a été
  **re-confirmé contre ce HEAD réel** : `Modal.css`, `ui.css`, `layout.css`,
  `CatalogPage.css`, `PanelPage.css`, `TeamPanel.css` y sont **identiques** à l'état audité
  → **M1, M3, M6–M10, M12, M14 confirmés**. Deux fichiers ont bougé depuis l'audit
  (`BookDraftForm.jsx` +215 l., `ImportacoesPage.css` +28 l.) → **M4 et M5 sont à
  re-confirmer sur le HEAD** (lignes possiblement décalées). **Toute implémentation se
  fait sur la copie à jour (WSL2 / `codeberg/main`), jamais sur la checkout du 9 juin**
  (collision / rebase forcé — règle d'or `CLAUDE.md`).
- **Ce cadrage est un axe COMPLÉMENTAIRE d'un chantier mobile déjà actif.** Le chantier
  « MOBILE » en cours (Paquets 0→4, moteur **FICEDL Bologne 09/2026**) traite le **mode
  terrain fonctionnel** : socle **PWA installable livré le 15/06** (Paquet 0, commit
  `0fe66b9`), **scanner caméra** carte-lecteur + ISBN (Paquets 2/2b, commits jusqu'à
  `ad2cee8`). Voir `docs/journal/arbitrages/DECISION_chantier_mobile_arbitrages_2026-05-28`.
  **Ce que ce chantier ne traite PAS** — et c'est l'objet du présent cadrage — c'est la
  **mise en page adaptative / les débordements**.
- **Constat structurant** : il n'existe **aucun commit de « passe responsive / CSS
  mobile »** dans l'historique. AnarBib est un **pur desktop-first** à qui on a ajouté des
  rustines `max-width` page par page (et, récemment, des fonctionnalités terrain). La
  **mise en page** mobile n'a jamais été traitée comme un mode de premier rang — d'où les
  débordements signalés.

---

## 1. Contexte & enjeu

AnarBib est susceptible d'être consulté **majoritairement sur téléphone** dans les
contextes où les ordinateurs de bureau sont rares (collectifs autogérés, Amérique
latine, permanences de terrain). L'OPAC public (catalogue) et les écrans staff du
quotidien (réservations, consultations, emprunts) doivent donc être pleinement
utilisables sur un écran de **360–400 px de large**.

Signalement utilisateur à l'origine du chantier : **« des boutons qui débordent de
l'écran »**. Le diagnostic confirme que c'est un symptôme d'un problème systémique
(barres d'action et modales à largeur fixe sans repli), pas un cas isolé.

---

## 2. État des lieux de l'architecture responsive

| Critère | État |
|---|---|
| Viewport meta | ✅ `width=device-width, initial-scale=1` (correct, `user-scalable` laissé libre → accessibilité préservée) |
| Approche CSS | CSS global + variables `--brand-*` (pas de CSS Modules, pas de Tailwind) |
| Stratégie | ❌ **100 % desktop-first** : que des `@media (max-width: …)`, **zéro `min-width`** |
| Breakpoints | ⚠️ **Ad hoc** : 540 / 600 / 640 / 720 / 768 / 800 / 820 / 900 / 1100 px, **sans tokens partagés** — chaque page définit les siens |
| Unités | ✅ Police majoritairement en `rem` ; largeurs en `px` + responsive |
| Primitives | ✅ Bon usage de `repeat(auto-fill, minmax())`, `clamp()`, `flex-wrap` par endroits |
| Safe-area (encoche) | ❌ Aucun `env(safe-area-inset-*)` **ni `viewport-fit=cover`** — d'autant plus gênant que l'app tourne maintenant en **standalone** (cf. PWA) |
| PWA | ✅ **Câblée** (socle Paquet 0, 15/06) : `public/manifest.webmanifest`, `public/sw.js` (SW maison, ne cache jamais l'API Supabase), `<link rel="manifest">` + metas iOS. App **installable**. |

---

## 3. Cartographie des manques — priorisée

> Légende sévérité : 🔴 **P0** = débordement horizontal direct · 🟠 **P1** = utilisable
> mais cassé/pénible · 🟡 **P2** = confort / robustesse / dette.

### 🔴 P0 — Débordements horizontaux directs

| # | Problème | Localisation | Détail |
|---|---|---|---|
| M1 | **Barres d'action sans `flex-wrap`** | `src/components/ui/Modal.css:95` (`.ab-modal__actions`) · `src/components/team/TeamPanel.css:474` (`.ab-team-modal-actions`) | `flex; justify-content:flex-end` sans wrap → 2-3 boutons à libellés longs (traductions DE/CA = +30 %) débordent. **Symptôme principal signalé.** |
| M2 | **Boutons d'action inline codés en dur sans wrap** | Toutes les modales `src/components/rede/*Modal.jsx` (ex. `ProposeCooptationModal.jsx:226`) | `style={{display:'flex', gap:8, justifyContent:'flex-end'}}` répété, jamais de `flexWrap`. |
| M3 | **Modales à largeur fixe > écran** | `src/components/ui/Modal.css:48-50` (`--small:400`, `--medium:560`, `--large:800`) + inline `maxWidth:560` (modales Rede) | Pas de `width: min(560px, 100% - 2rem)` ni media query. `medium`/`large` débordent sur 360-400 px. |
| M4 ⚠️à reconfirmer | **Grilles de formulaire codées en dur inline** | `src/pages/catalogacao/BookDraftForm.jsx` (audité v. 09/06 lignes ~2642 `'1fr 1fr'` · ~2686 `repeat(3,1fr)` zones ISBD) | Pas de breakpoint → champs écrasés/débordants. **Fichier modifié depuis l'audit (+215 l.) → re-localiser sur le HEAD.** (Les grilles *via classe* `.cat-book-grid` s'effondrent bien à 820 px — c'est le inline qui pèche.) |
| M5 ⚠️à reconfirmer | **Tableaux d'import sans conteneur de scroll** | `src/pages/importacoes/ImportacoesPage.css` (`.imp-queue`, `.imp-map`) | Pas de wrapper `overflow-x:auto` → débordement brut. **Fichier modifié depuis l'audit (+28 l.) → re-vérifier si déjà corrigé.** |

### 🟠 P1 — Utilisable mais cassé/pénible

| # | Problème | Localisation | Détail |
|---|---|---|---|
| M6 | **Pas de menu mobile (hamburger / drawer)** | `src/components/layout/index.jsx:65-159` · `layout.css:17-92` | La topbar `flex-wrap` se replie sur 2-3 lignes et mange une grosse part de l'écran. Aucun repli en menu. **Plus gros manque de navigation.** |
| M7 | **Tables actives du Painel non transformées en cartes** | `src/pages/painel/PanelPage.css` | Le pattern « table → cartes » existe mais **uniquement pour l'onglet Historique** (`@768px`, ~ligne 360). Réservations / Consultations / Emprunts — les **écrans staff quotidiens** — restent en scroll horizontal. |
| M8 | **OPAC : colonne actions tronquée** | `src/pages/public/CatalogPage.css:330` puis `:421` (110px → 80px) | Réserver + Consulter + Favori serrés dans 80 px → icônes/texte coupés. L'OPAC est l'écran **le plus consulté sur mobile**. |
| M9 | **Cibles tactiles sous le seuil** | `src/components/ui/ui.css:13` (boutons 42 px) · `:38` (`--mini` 34 px) | < 44 px recommandé (WCAG / iOS / Android). `--mini` très utilisé dans les formulaires. |
| M10 | **Inputs déclenchent le zoom auto iOS** | `src/components/ui/ui.css:105` (`font-size:0.95rem` ≈ 15 px) + champs inline `.85rem` (BookDraftForm) | < 16 px → iOS zoome au focus et casse le layout. |

### 🟡 P2 — Confort / robustesse / dette

| # | Problème | Localisation | Détail |
|---|---|---|---|
| M11 ⬆️ | **Aucun `env(safe-area-inset-*)` ni `viewport-fit=cover`** | `index.html` + global | Pas de protection encoche / Dynamic Island / barre gestuelle. **Désormais actif** : l'app étant installable (PWA livrée), elle s'ouvre en **standalone** → le contenu et les barres d'action collées en bas/haut peuvent passer sous l'encoche. *(Frontière P1/P2 — à remonter si l'install PWA est promue.)* |
| M12 | **Breakpoints ad hoc, sans tokens** | tous les `*.css` | 9 valeurs différentes. Incohérences (un écran casse à 640, le voisin à 720). Maintenance fragile. |
| M14 | **Squelette de chargement à colonnes fixes** | `src/pages/public/CatalogPage.css:231` (`grid-template-columns:80px 2fr 1.4fr 60px`) | Pas de fallback < 320 px. |

> **M13 — PWA : ✅ RÉSOLU avant ce cadrage.** Le socle PWA installable est livré
> (Paquet 0, 15/06). Reste le volet **safe-area / `viewport-fit`** → traité en M11, dont
> l'importance monte justement parce que l'app est maintenant standalone.

---

## 4. Acquis à généraliser (ne pas refaire)

- ✅ Grilles `repeat(auto-fill, minmax(280px,1fr))` du catalogue — s'adaptent **sans**
  media query (`src/styles/catalog.css`). **Modèle pour toute nouvelle grille.**
- ✅ `clamp()` sur les titres hero (`src/components/layout/layout.css:149`).
- ✅ Onglets Catalogação / Biblioteca en scroll horizontal `-webkit-overflow-scrolling:touch`.
- ✅ **Pattern « table → cartes » du Painel Historique** (`PanelPage.css` ~360) — **c'est
  le gabarit à répliquer** sur les tables staff (M7).
- ✅ Le catalogue encapsule son tableau dans `.ab-table-wrap{overflow:auto; max-height:70vh}`
  (`CatalogPage.css:118`) — **gabarit à répliquer** sur les tables d'import (M5).

---

## 5. Plan de traitement proposé

### Phase A — Quick wins transversaux (fort levier, peu de lignes)
Beaucoup de P0 se règlent dans **un seul fichier `src/styles/mobile.css` global + une
poignée d'edits ciblés** :
1. `flex-wrap: wrap` sur **toutes** les barres d'action (M1, M2).
2. `width: min(Xpx, 100% - 2rem)` sur les classes de modale (M3).
3. Wrapper `overflow-x:auto` sur les tableaux d'import (M5), en réutilisant le gabarit
   `.ab-table-wrap`.
4. `min-height: 44px` sur boutons + `font-size: 16px` sur inputs (M9, M10).
5. Remplacer les grilles inline `repeat(3,1fr)` / `1fr 1fr` de `BookDraftForm.jsx` par une
   classe responsive (M4).
6. Créer `src/styles/breakpoints.css` avec tokens (`--bp-sm:640px`, etc.) et migrer
   progressivement les `@media` (M12).

### Phase B — Chantiers de fond
7. **Menu mobile** (drawer / hamburger) sous le breakpoint mobile (M6) — *décision UX à trancher*.
8. **Tables staff → cartes** : appliquer le pattern Historique aux Réservations /
   Consultations / Emprunts du Painel (M7).
9. **OPAC colonne actions** : repenser en pile verticale ou menu « … » sur mobile (M8).

### Phase C — Finition « standalone » (la PWA est déjà livrée)
10. `viewport-fit=cover` dans `index.html` + `env(safe-area-inset-*)` sur les conteneurs
    collés aux bords (topbar, barres d'action, boutons flottants `ScrollButtons`) (M11).
    **C'est le complément manquant du socle PWA** : sans lui, le mode standalone passe sous
    l'encoche. À articuler avec le chantier mobile actif
    ([`../specs/spec-carte-lecteur-v0_2.md`](../specs/spec-carte-lecteur-v0_2.md), Paquets terrain).

---

## 6. Points à trancher (décisions ouvertes pour le REGISTRE)

- **D1 — Menu mobile** : drawer latéral, bottom-sheet, ou simple repli en pile ? (M6)
- **D2 — Tables staff sur mobile** : conversion en cartes (pattern Historique) vs scroll
  horizontal assumé ? (M7)
- ~~**D3 — Go/no-go PWA**~~ : **tranché** — socle PWA livré le 15/06. Reste à décider si on
  promeut activement l'installation (→ priorise M11 safe-area) ou si on la laisse passive.
- **D4 — Tokens de breakpoint** : adopter un jeu de tokens partagé et figer les valeurs
  (640 / 768 / 1100 ?) avant de migrer les `@media`. (M12)
- **D5 — Stratégie globale** : refonte mobile-first incrémentale vs patches ciblés
  desktop-first. (Le présent cadrage propose : **patches ciblés d'abord** — Phase A —,
  refonte mobile-first seulement si justifiée ensuite.)

---

## 7. Liens

- Doctrine : [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md)
- Spec carte-lecteur (mobile / terrain) : [`../specs/spec-carte-lecteur-v0_2.md`](../specs/spec-carte-lecteur-v0_2.md)
- Cadrage OPAC (écran le plus mobile) : [`CADRAGE_OPAC_chantier_2026-06-07.md`](CADRAGE_OPAC_chantier_2026-06-07.md)
