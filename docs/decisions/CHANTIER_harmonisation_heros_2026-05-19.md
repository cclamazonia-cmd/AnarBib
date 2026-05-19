# CHANTIER — Harmonisation des héros des pages d'AnarBib

**Date d'ouverture :** 19 mai 2026
**Date de clôture :** 20 mai 2026 (session unique)
**Auteur·rice :** Xavier (coord BLMF, admin réseau)
**Statut :** **BOUCLÉ** — 7/7 pages en prod
**Périmètre exécuté :** 1 hook, 2 composants, 1 CSS, 7 pages frontend, 42 clés i18n × 6 locales

---

## 1. Problème identifié

Audit visuel des 5 pages principales d'AnarBib au 19/05/2026 (captures héros `/catálogo`, `/conta`, `/painel`, `/biblioteca`, `/rede`) :

1. **Bouton documentation incohérent** : « Manual completo » présent uniquement sur `/catálogo`, alors qu'il devrait apparaître partout selon le contexte (manuel lecteur pour les pages lectrice·eur, manuel complet pour les pages staff, guide de gouvernance pour la page réseau et les pages staff politiques).

2. **Bloc identité fragmentaire** : nom + prénom + ID public + sigle biblio + rôle visibles seulement sur `/conta`. Sur `/biblioteca`, seul le rôle apparaît (sans nom ni ID). Sur `/rede`, idem mais avec un libellé d'administrateur. Sur `/painel` et `/catálogo`, rien.

3. **Code couleur des rôles non respecté** : la doctrine déjà actée (cf. session RGPD du 12/05/2026) prévoit `c-amber` pour leitor, `c-blue` pour bibliotecárie·io et coordenador·a, `c-green` pour administrador·a de rede. Or sur `/conta` le badge actuel mélange statut (vert = compte actif) et rôle (Coordenador·a) dans une seule pill verte, ce qui prête à confusion. Sur `/biblioteca`, « COORDENADOR(A/E) » apparaît en vert au lieu de bleu. Sur `/rede`, « ADMINISTRADOR(A/E) » apparaît en jaune/amber au lieu de vert.

4. **Documentation pertinente manquante côté gouvernance** : le *Guide de gouvernance d'AnarBib* (v1.0, 11 mai 2026) s'adresse explicitement *« aux coordinateur·rices de biblio et aux administrateur·rices du réseau »* mais n'est accessible nulle part dans l'UI.

---

## 2. Doctrine actée

### 2.1 Bloc identité — invariant des héros

Présent sur les 7 pages où l'usager·e connecté·e peut se trouver, dans cet ordre fixe :

| # | Élément | Couleur | Présence |
|---|---|---|---|
| 1 | Nom complet (prénom + NOM) | rôle effectif (amber/blue/green) | **toujours quand connecté·e** |
| 2 | Rôle effectif sur la page | rôle effectif | **toujours quand connecté·e** |
| 3 | ID public (`U0000030`) | neutre (mono, fond translucide) | **toujours quand connecté·e** |
| 4 | Sigle biblio | neutre | **toujours, sauf `/rede`** |
| 5 | Statut du compte | semantic (ok/warn/danger) | **uniquement `/conta`** |

Sur `/catálogo` quand l'usager·e n'est pas connecté·e, le bloc identité est masqué (la page reste accessible aux anonymes).

### 2.2 Code couleur des rôles — palette inversée DÉFINITIVE

**Décision actée le 20/05/2026 après test visuel sur prod** : palette inversée (fond foncé + texte clair) pour lisibilité optimale sur le fond rouge profond AnarBib du hero (`linear-gradient(145deg, rgba(120,10,18,.97), rgba(18,2,5,1))`, cf. `layout.css`).

| Rôle effectif sur la page | Ramp | Fond (hex) | Texte (hex) | Bordure (hex) |
|---|---|---|---|---|
| `leitor` | `c-amber` (inversé) | `#412402` | `#FAC775` | `#BA7517` |
| `librarian` ou `coordenador` | `c-blue` (inversé) | `#042C53` | `#85B7EB` | `#185FA5` |
| `administrador` de rede | `c-green` (inversé) | `#173404` | `#C0DD97` | `#3B6D11` |

**Justification du choix inversé** : la palette initiale (fond clair stop 100 + texte foncé stop 800) testée sur prod le 19/05 a révélé un contraste insuffisant sur le fond rouge AnarBib (la pill `#EAF3DE` avec texte `#27500A` se distinguait à peine du fond rouge). La doctrine reste fidèle aux **mêmes ramps** (c-amber, c-blue, c-green) — seuls les stops choisis dans chaque ramp ont changé (900/200 au lieu de 100/800). Ce pattern « stops foncés en fond + clairs en texte » est cohérent avec les boutons "Atualizar dados" et "Guia de governança" qui sont déjà parfaitement lisibles sur le hero.

**Couleurs des badges contextuels (neutre + statuts compte)** :

| Variante | Fond | Texte | Bordure |
|---|---|---|---|
| Neutre (ID public, sigle biblio) | `rgba(245,233,216,.08)` | `#d9c9b0` | `rgba(245,233,216,.2)` |
| Statut compte `active` | `rgba(99,153,34,.18)` | `#C0DD97` | `rgba(99,153,34,.5)` |
| Statut compte `attention` | `rgba(186,117,23,.18)` | `#FAC775` | `rgba(186,117,23,.5)` |
| Statut compte `blocked` | `rgba(226,75,74,.18)` | `#F09595` | `rgba(226,75,74,.5)` |

**Implémentation : styles inline JSX obligatoires** (cf. §7bis L.2) — pas en CSS externe, parce que `theme.js` injecte des variables `--brand-*` en setProperty inline qui surchargent toute règle CSS externe, même avec `!important`. Seul un autre inline style peut les battre.

### 2.3 Rôle effectif — règle « page = scope »

Conformément à la doctrine déjà actée (mémoire AnarBib + guide de gouvernance §2.3 p.10-11), chaque page affiche **le rôle pertinent pour son périmètre**, pas un rôle global :

| Page | Rôle effectif affiché | Source |
|---|---|---|
| `/catálogo` | rôle local (`role` de `LibraryContext`) | `useLibrary().role` |
| `/conta` | rôle local | `useLibrary().role` |
| `/painel` | rôle local | `useLibrary().role` |
| `/biblioteca` | rôle local | `useLibrary().role` |
| `/catalogação` | rôle local | `useLibrary().role` |
| `/importações` | rôle local | `useLibrary().role` |
| `/rede` | rôle transverse `network_admin` | `useLibrary().isNetworkAdmin` |

Cela résout proprement le cas multi-rôle (admin réseau + coordenador local) : chaque page affiche le rôle pertinent pour son scope, sans cross-calculation, conformément à la doctrine du guide de gouvernance §2.3.

### 2.4 Libellés inclusifs des rôles

Charte langage inclusif AnarBib (Paquet 21, mai 2026) : forme triple en pt-BR.

| Rôle effectif | pt-BR | fr | es | en | it | de |
|---|---|---|---|---|---|---|
| leitor | Leitor(a/e) | Lecteur·rice | Lectora·or | Reader | Lettor*rice | Leser*in |
| librarian | Bibliotecário(a/e) | Bibliothécaire | Bibliotecaria·o | Librarian | Bibliotecari*a | Bibliothekar*in |
| coordenador | Coordenador(a/e) | Coordinateur·rice | Coordinadora·or | Coordinator | Coordinator*rice | Koordinator*in |
| administrador de rede | Administrador(a/e) da rede AnarBib | Administrateur·rice du réseau AnarBib | Administradora·or de la red AnarBib | AnarBib network administrator | Amministrator*rice della rete AnarBib | Netzwerkadministrator*in von AnarBib |

### 2.5 Bouton documentation — table de mapping

| Page | Lecteur·rice (non-staff) | Staff local | Admin réseau |
|---|---|---|---|
| `/catálogo` | Manuel lecteur | Manuel lecteur *(scope page prime sur rôle)* | Manuel lecteur |
| `/conta` | Manuel lecteur | Manuel lecteur | Manuel lecteur |
| `/painel` | n/a | Manuel complet **+** Guide de gouvernance | idem |
| `/biblioteca` | n/a | Manuel complet **+** Guide de gouvernance | idem |
| `/catalogação` | n/a | Manuel complet | idem |
| `/importações` | n/a | Manuel complet | idem |
| `/rede` | n/a | n/a | Guide de gouvernance |

**Justification de l'option 2** (deux boutons sur `/painel` et `/biblioteca`) : le guide de gouvernance s'adresse explicitement aux coordinateur·rices ; il doit être à un clic au moment où elles font une cooptation, une suspension ou une demande de retrait. C'est exactement ces moments-là qui ont besoin du guide. Cacher le guide derrière `/rede` créerait du friction au pire moment.

**Justification de l'absence sur `/catalogação` et `/importações`** : ce sont des outils techniques, pas des espaces de gouvernance. Le manuel complet suffit.

### 2.6 URLs des documents

Bucket Supabase `library-ui-assets/manuals/network/published/` :
- `Manual%20Leitor-a-e.pdf` (multilingue intégré)
- `Manual_do_AnarBib.pdf` (manuel complet, future bascule i18n)
- `Guia_de_governanca_AnarBib.pdf` (v1.0 du 11/05/2026, uploadé le 19/05/2026 par Xavier)

Constantes définies dans `HeroDocumentationActions.jsx`.

---

## 3. Architecture technique mise en œuvre

### 3.1 Composant `<UserHeroBadge />`

**Emplacement :** `src/components/UserHeroBadge.jsx` + `src/components/UserHeroBadge.css`

**Props :**
- `accountStatus?: 'active' | 'attention' | 'blocked' | null` — seulement utilisé sur `/conta`

**Responsabilité :** rendre le bloc identité (nom, rôle, ID public, sigle biblio, statut compte) conformément à la doctrine §2.1.

**Implémentation technique notable :**
- Couleurs en **inline style** sur chaque `<span>` (pas en CSS) — voir §2.2
- `color: 'inherit'` explicite sur les `<span>` enfants — voir §7bis L.3
- `return null` si non authentifié·e ou profil pas encore chargé (UX flash-free)

### 3.2 Composant `<HeroDocumentationActions />`

**Emplacement :** `src/components/HeroDocumentationActions.jsx`

**Props :**
- `extraActions?: React.ReactNode` — boutons additionnels spécifiques à la page (Atualizar, Exportar PDF/CSV, compteurs métier, etc.), rendus AVANT les boutons documentation

**Responsabilité :** rendre la rangée de boutons documentation conformément à la table §2.5.

### 3.3 Hook `useEffectiveScope()`

**Emplacement :** `src/hooks/useEffectiveScope.js`

**Retour :**
```js
{
  isAuthenticated: boolean,
  fullName: string | null,
  publicId: string | null,
  effectiveRole: 'leitor' | 'librarian' | 'coordenador' | 'network_admin' | null,
  roleVariant: 'leitor' | 'staff' | 'admin' | null,
  roleLabelKey: string | null,
  libraryAcronym: string | null,
  showLibraryAcronym: boolean,
  documents: {
    showReaderManual: boolean,
    showCompleteManual: boolean,
    showGovernanceGuide: boolean,
  },
}
```

**Logique interne :**
1. Lit `useAuth()` pour `user` et `profile` (first_name, last_name, public_id).
2. Lit `useLibrary()` pour `role`, `isNetworkAdmin`, `libraryName` (sigle).
3. Lit `useLocation()` (de react-router-dom) pour connaître la page courante.
4. Calcule `effectiveRole` selon §2.3.
5. Calcule `documents` selon §2.5.
6. Calcule `showLibraryAcronym` : `false` si pathname commence par `/rede`, `true` sinon.

**Avantage architectural** : le hook centralise toute la logique de doctrine. Modifier un comportement = une seule fonction à toucher, pas 7 pages.

---

## 4. Plan de mise en œuvre — EXÉCUTÉ

### Phase A — Composants partagés ✅ (19/05/2026, commit `02b788b`)

- ✅ A.1 : `src/hooks/useEffectiveScope.js`
- ✅ A.2 : `src/components/UserHeroBadge.jsx` + `.css`
- ✅ A.3 : `src/components/HeroDocumentationActions.jsx`
- ✅ A.4 : 7 nouvelles clés i18n × 6 locales (42 entrées via script Node.js `phaseA_patch_i18n.cjs`)
- ✅ A.5 : libellés des rôles i18n × 6 locales
- ✅ A.6 : PDF `Guia_de_governanca_AnarBib.pdf` uploadé dans le bucket Supabase

### Phase B — Intégration page par page ✅

Ordre exécuté (option 1 cycle court : du plus particulier au plus simple, puis croissant en taille) :

| # | Page | Lignes | Particularités | Statut |
|---|---|---|---|---|
| B.1 | RedePage | 368 | Cas le plus particulier (vert admin, pas de sigle biblio, palette inversée découverte ici) | ✅ |
| B.2 | CatalogacaoPage | 426 | Logo + email + cat-pill ok supprimés | ✅ |
| B.3 | ImportacoesPage | 545 | Hero principal vide, Hero restricted préservé | ✅ |
| B.4 | BibliotecaPage | 1290 | Logo retiré, doctrine couleurs corrigée (bleu et non plus vert), 5 stats préservés | ✅ |
| B.5 | PanelPage | 2643 | 3 Hero distincts (loading initial / loading données / ready), 3 pills compteurs préservées | ✅ |
| B.6 | CatalogPage | 921 | Page publique (anonymes), prop `actions={}` transformée en children, 2 constantes URLs supprimées | ✅ |
| B.7 | AccountPage | 1858 | Prop `accountStatus` propagée, 2 Hero, bandeaux RGPD/serviceState préservés intacts | ✅ |

### Phase C — Fermeture ✅ (20/05/2026)

- ✅ C.1 : audit visuel des 7 pages
- ✅ C.2 : nettoyage scripts/backups
- ✅ C.3 : ce document de doctrine mis à jour avec décisions finales
- ⏳ C.4 : note de session pour le Grand Livre Blanc (à faire dans la foulée)

---

## 5. Clés i18n ajoutées

42 entrées au total (7 clés × 6 locales). Toutes via script Node.js `phaseA_patch_i18n.cjs` (lecture/écriture UTF-8 native, parsing JSON sécurisé, backup automatique).

Clés ajoutées : `nav.governance.guide`, `role.leitor`, `role.librarian`, `role.coordenador`, `role.network_admin`, `account.status.blocked`, `hero.identity.aria`.

Clés préservées (déjà en prod) : `nav.manual.reader`, `nav.manual.complete`, `account.status.active`, `account.status.attention`, `roles.*` (anciennes, encore référencées en marge sur quelques pages).

---

## 6. Risques anticipés — bilan

### 6.1 Risque CSS — RÉSOLU

Le risque que les classes `cat-pill-amber/info/ok` n'existent pas s'est confirmé. Approche d'isolation totale (option 3) avec CSS dédié `ab-hero-badge-*` adoptée. Mais découverte en cours de chantier : **theme.js surcharge même ces classes en cascade**, d'où la migration vers styles inline JSX (§2.2).

### 6.2 Risque ID public — NON CONFIRMÉ

`profile.public_id` était bien disponible dans `AuthContext` (audit Phase A confirmé). Aucune adaptation nécessaire.

### 6.3 Risque doctrine multi-membership — NON DÉCLENCHÉ

Le hook s'aligne sur `useLibrary().role` qui retourne déjà le rôle de plus haut niveau actif. Aucun cas-limite rencontré pendant le chantier (mais Xavier est seul·e usager·e de prod actuellement).

### 6.4 Risque pages mobile — NON TESTÉ

À tester en post-chantier. Le CSS prévoit déjà des breakpoints `@media (max-width: 640px)` pour réduire les pills.

### 6.5 Risque ordre i18n — RÉSOLU

Audit Phase A a confirmé que `nav.manual.reader/complete` et `account.status.active/attention` existaient déjà. Le script Node a sauté ces clés sans les écraser (0 conflits).

---

## 7. Définition de fin de chantier — ATTEINTE

1. ✅ Les 7 pages affichent un hero conforme à §2.1
2. ✅ Le code couleur §2.2 (palette inversée) est respecté visuellement sur les 7 pages
3. ✅ Le composant `<UserHeroBadge>` est utilisé partout, aucune logique d'affichage du badge dupliquée
4. ✅ Le PDF guide-gouvernance est dans le bucket et accessible via les boutons
5. ✅ Les 6 locales sont à parité sur les nouvelles clés
6. ✅ `npm run build` passe sans warning nouveau (warning AccountPage > 500 KB préexistant, item de backlog distinct)
7. ✅ La session est tracée dans ce document

---

## 7bis. Bilan de fermeture — Leçons techniques transférables

### L.1 — DevTools FIRST quand un patch CSS semble sans effet

Quand après un patch CSS le rendu ne change pas, **ouvrir les DevTools du navigateur avant** de relancer un autre patch en aveugle. La capture de la cascade CSS lors du chantier B.1 a permis d'identifier que les inline styles JSX étaient *bien appliqués* (computed color = `rgb(39, 80, 10)`, vert foncé doctrine) — et donc que le problème était un manque de contraste sur le fond rouge, pas un override CSS. Sans DevTools j'aurais probablement enchaîné des patches de spécificité inutiles.

**Coût d'opportunité perdu sans DevTools** : ≈ 3 patches en aveugle (B.1.css, B.1.inline-styles, B.1.text-color) qui auraient été évitables. Doctrine actée : **DevTools avant 2e patch**.

### L.2 — Styles inline JSX pour battre `theme.js`

Le fichier `theme.js` (`src/lib/theme.js`) injecte des variables CSS `--brand-*` via `document.documentElement.style.setProperty()`. Ces injections créent des **inline styles sur l'élément racine** qui ont une spécificité égale aux inline styles JSX, mais qui sont **prioritaires sur toute règle CSS externe**, même avec `!important`.

**Conséquence** : pour battre cette cascade sur le hero AnarBib (fond rouge profond), le seul moyen est d'utiliser `style={{...}}` directement dans le JSX. Notre `UserHeroBadge.jsx` applique donc les 3 couleurs (bg/fg/border) en inline, et le `UserHeroBadge.css` gère uniquement la mise en page (gap, padding, margin, border-radius).

**À retenir pour les futurs composants** : tout ce qui s'affiche dans le `.ab-hero` doit gérer ses couleurs en inline si la palette dévie de `--brand-*`.

### L.3 — `color: 'inherit'` explicite sur les enfants

Même avec un inline style `style={{ color: '#XXXXXX' }}` sur un `<span>` parent, les `<span>` enfants **ne héritent pas automatiquement** de la couleur — parce que `theme.js` injecte une cascade `--brand-text` qui réassigne `color` sur tous les éléments du hero via une règle CSS plus spécifique.

**Solution** : `<span style={{ color: 'inherit' }}>...</span>` sur chaque enfant qui doit prendre la couleur du parent. C'est l'inverse de ce qu'on attendrait de CSS classique, mais nécessaire dans ce contexte. Pattern appliqué systématiquement dans `UserHeroBadge.jsx`.

### L.4 — Patches JSX par bornes d'indices (`IndexOf` + `Substring`)

Les longues heredocs PowerShell (`@"..."@`) contenant des caractères ambigus pour PS — backticks `` ` `` (template literals JavaScript, hex `60`), `$` (variables PS), accolades `${...}` (interpolation) — sont **systématiquement risquées** : PS interprète des séquences que JSX traite littéralement, et les patches échouent silencieusement ou produisent des chaînes corrompues.

**Solution adoptée à partir de B.4** : **bornes d'indices** plutôt que matching de contenu :
```powershell
$openIdx = $content.IndexOf("<MarqueurDebut>")
$closeIdx = $content.IndexOf("</MarqueurFin>", $openIdx)
$before = $content.Substring(0, $openIdx)
$after = $content.Substring($closeIdx + "</MarqueurFin>".Length)
$content = $before + $nouveauContenu + $after
```

Plus robuste, indépendant du contenu interne, lisible. Pattern appliqué dans B.4, B.5, B.6, B.7.

### L.5 — ASCII strict pur dans tous les scripts PowerShell

Pas seulement accents et emojis. **Aussi** les caractères typographiques apparemment innocents :
- `§` (section sign, U+00A7)
- `—` (em dash, U+2014)
- `«»` (guillemets français, U+00AB / U+00BB)
- `…` (ellipsis, U+2026)
- `·` (point médian, U+00B7)
- `→` (right arrow, U+2192)

Tous cassent le parsing PowerShell sous Windows FR, **même quand ils sont uniquement dans des commentaires** `#`. Doctrine actée : **ASCII strict pur pour tous les `.ps1`**.

**Exception nécessaire** : quand la heredoc PS contient du code JSX avec accents légitimes (commentaires `// héros`, libellés FR, etc.), ajouter un **BOM UTF-8** au début du fichier `.ps1` (3 octets `EF BB BF`) pour que PS le lise en UTF-8 et non en CP1252. Ou bascule sur **script Node.js `.cjs`** (Node lit UTF-8 nativement, le piège disparaît).

### L.6 — `$LASTEXITCODE` + `Tee-Object` peu fiable

Capture du code de sortie de `npm run build` via `Tee-Object` produit des faux négatifs (le pic-vert Phase A a été initialement annoncé en rouge alors que le build avait réussi). À utiliser sans pipeline intermédiaire :

```powershell
& npm run build
$code = $LASTEXITCODE  # capture immediate, fiable
```

Pas de `2>&1`, pas de `Tee-Object`, pas de `Out-Host` entre les deux instructions. Pattern appliqué dans tous les scripts B.

### L.7 — Composer en cycle court plutôt qu'en cycle long

Le chantier a été exécuté en option 1 (cycle court : 7 pages en une seule session). Bilan : **gagnant**. Chaque patch B.n bénéficiait des leçons des patches précédents (L.2/L.3/L.4 actées au fur et à mesure), et les composants partagés étaient déjà validés en prod dès B.1. Si on avait fait B.1 puis attendu plusieurs jours, on aurait perdu le bénéfice du momentum et des leçons fraîches.

**Doctrine actée pour les futurs chantiers d'harmonisation UI** : si les composants partagés sont autonomes (Phase A close), enchaîner les pages en cycle court tant que possible. Une page = 30-60 min en moyenne avec les patterns L.4 + L.6.

---

## 8. Prérequis bloquants

Aucun. Toutes les dépendances backend (table `network_administrators`, vue `api.network_administrators_public_v1`, `LibraryContext.isNetworkAdmin`) étaient déjà en prod (cf. paquet F admin réseau bouclé le 13/05/2026).

---

## 9. État du backlog post-chantier

**Items résolus implicitement** par ce chantier :
- Affichage incohérent du rôle entre les 7 pages → résolu (composant partagé)
- Bouton "Manual completo" présent uniquement sur `/catálogo` → résolu (mapping par page)
- Doctrine couleurs `c-amber/c-blue/c-green` non respectée sur `/biblioteca` et `/rede` → résolu (palette inversée appliquée partout)

**Items créés par ce chantier** :
- (aucun bug, aucune régression visuelle observée)

**Items pré-existants confirmés non affectés** :
- Code-splitting `AccountPage.jsx` (warning Vite > 500 KB) → toujours ouvert, item de backlog distinct
- `(nulld, nullx)` display bug → non touché
- Top books 90-day block → non touché

---

*Document de chantier final. Version 1.1 du 20 mai 2026.*

*Ce guide est lui-même amendable. Toute correction ou ajout est bienvenu·e via les canaux habituels.*
