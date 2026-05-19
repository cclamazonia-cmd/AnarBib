# CHANTIER — Harmonisation des héros des pages d'AnarBib

**Date :** 19 mai 2026
**Auteur·rice :** Xavier (coord BLMF, admin réseau)
**Statut :** doctrine actée, prêt à exécution
**Périmètre :** frontend SPA, 7 pages, 1 composant nouveau, 1 hook nouveau, 3 clés i18n × 6 locales

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

### 2.2 Code couleur des rôles — invariant

| Rôle effectif sur la page | Ramp | Hex (light mode) | Sémantique |
|---|---|---|---|
| `leitor` | `c-amber` | fond `#FAEEDA`, bordure `#BA7517`, texte `#633806` | usager·e de base |
| `librarian` ou `coordenador` | `c-blue` | fond `#E6F1FB`, bordure `#185FA5`, texte `#0C447C` | staff local engagé·e |
| `administrador` de rede | `c-green` | fond `#EAF3DE`, bordure `#3B6D11`, texte `#27500A` | autorité transverse |

Ces classes existent déjà dans `theme-base.css` sous les noms `cat-pill-amber`, `cat-pill-info`, `cat-pill-ok` à vérifier en début de chantier (cf. §5.1). Si elles n'existent pas, on les crée.

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

À stocker dans des constantes `MANUAL_URLS` en haut du composant `<HeroDocumentationActions>` :

```js
const MANUAL_URLS = {
  reader: 'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/manuals/network/published/Manual%20Leitor-a-e.pdf',
  complete: 'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/manuals/network/published/Manual_do_AnarBib.pdf',
  governance: 'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/manuals/network/published/Guia_de_governanca_AnarBib.pdf',
};
```

Le PDF de gouvernance fourni le 19/05/2026 (v1.0, 11 mai 2026) sera uploadé dans le bucket Supabase `library-ui-assets/manuals/network/published/Guia_de_governanca_AnarBib.pdf` avant le déploiement.

À terme (chantier ultérieur), ces URLs basculeront en i18n quand les versions traduites du manuel complet seront disponibles. Le manuel lecteur reste monolithique multilingue, donc une seule URL.

---

## 3. Architecture technique

### 3.1 Composant `<UserHeroBadge />`

**Emplacement :** `src/components/UserHeroBadge.jsx` + `src/components/UserHeroBadge.css`

**Props :** aucune. Le composant lit son contexte via `useEffectiveScope()`.

**Responsabilité :** rendre le bloc identité (nom, rôle, ID public, sigle biblio, statut compte) conformément à la doctrine §2.1.

**Cas limites :**
- Si non connecté·e : ne rend rien (`return null`).
- Si profil pas encore chargé : ne rend rien (évite le flash sans nom).
- Sur `/conta`, accepte une prop optionnelle `accountStatus={'active'|'attention'|'blocked'}` pour la pill statut.

### 3.2 Composant `<HeroDocumentationActions />`

**Emplacement :** `src/components/HeroDocumentationActions.jsx`

**Props :** aucune. Lit `useEffectiveScope()` pour déterminer quels boutons afficher.

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
  roleColorClass: 'cat-pill-amber' | 'cat-pill-info' | 'cat-pill-ok' | null,
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
1. Lit `useAuth()` pour `user` et `profile` (full_name, public_id).
2. Lit `useLibrary()` pour `role`, `isNetworkAdmin`, `libraryName` (sigle), `libraryId`.
3. Lit `useLocation()` (de react-router-dom) pour connaître la page courante.
4. Calcule `effectiveRole` selon §2.3.
5. Calcule `documents` selon §2.5.
6. Calcule `showLibraryAcronym` : `false` si pathname commence par `/rede`, `true` sinon.

### 3.4 Avantage architectural

Le hook centralise toute la logique de doctrine. Si demain on décide qu'une admin réseau visitant `/painel` doit voir un badge spécial « administradora de rede consultando como coordenadora local », on modifie une seule fonction. Les 7 pages ne savent rien de la doctrine, elles importent juste les deux composants.

---

## 4. Plan de mise en œuvre

### Phase A — Composants partagés (autonome, sans toucher aux pages)

- A.1 : créer `src/hooks/useEffectiveScope.js`
- A.2 : créer `src/components/UserHeroBadge.jsx` + `.css`
- A.3 : créer `src/components/HeroDocumentationActions.jsx`
- A.4 : ajouter les 3 nouvelles clés i18n × 6 locales (12 entrées par locale soit 18 entrées au total cf. §5)
- A.5 : ajouter les libellés des rôles i18n × 6 locales s'ils n'existent pas déjà
- A.6 : uploader le PDF guide-gouvernance dans le bucket Supabase

**Critère de succès A :** `npm run build` passe, aucune page ne change visuellement (les composants existent mais ne sont importés nulle part).

### Phase B — Intégration page par page

À traiter dans cet ordre, une page par session de patch, avec test de non-régression entre chaque :

- B.1 : `/catálogo` (CatalogPage.jsx) — la plus complexe car aussi accessible aux anonymes
- B.2 : `/conta` (AccountPage.jsx) — déjà a un bloc identité riche, à remplacer
- B.3 : `/painel` (PanelPage.jsx) — vide actuellement, premier ajout
- B.4 : `/biblioteca` (BibliotecaPage.jsx) — a juste le rôle, à enrichir
- B.5 : `/catalogação` (CatalogacaoPage.jsx) — vide
- B.6 : `/importações` (ImportacoesPage.jsx) — vide
- B.7 : `/rede` (RedePage.jsx) — a juste le rôle, à enrichir + nouveau bouton guide

**Critère de succès B :** à chaque B.n, build OK, test visuel manuel OK, commit + push.

### Phase C — Fermeture

- C.1 : audit visuel comparatif des 7 pages
- C.2 : retrait des éventuels morceaux de code dupliqué/obsolète identifiés pendant le chantier
- C.3 : note de session `SESSION_harmonisation_heros_2026-05-XX.docx` dans `docs/decisions/`

---

## 5. Clés i18n à ajouter

### 5.1 Documentation (3 clés × 6 locales = 18 entrées)

```json
// pt-BR
"nav.manual.reader": "Manual do(a/e) leitor(a/e)",
"nav.manual.complete": "Manual completo",
"nav.governance.guide": "Guia de governança",

// fr
"nav.manual.reader": "Manuel lecteur·rice",
"nav.manual.complete": "Manuel complet",
"nav.governance.guide": "Guide de gouvernance",

// es
"nav.manual.reader": "Manual lectora·or",
"nav.manual.complete": "Manual completo",
"nav.governance.guide": "Guía de gobernanza",

// en
"nav.manual.reader": "Reader manual",
"nav.manual.complete": "Full manual",
"nav.governance.guide": "Governance guide",

// it
"nav.manual.reader": "Manuale lettor*rice",
"nav.manual.complete": "Manuale completo",
"nav.governance.guide": "Guida di governance",

// de
"nav.manual.reader": "Leser*innen-Handbuch",
"nav.manual.complete": "Vollständiges Handbuch",
"nav.governance.guide": "Governance-Leitfaden"
```

### 5.2 Rôles dans le hero (4 clés × 6 locales = 24 entrées)

À vérifier d'abord si elles existent déjà (probablement oui partiellement). Clés cibles :

```json
"role.leitor": "Leitor(a/e)" // etc.
"role.librarian": "Bibliotecário(a/e)" // etc.
"role.coordenador": "Coordenador(a/e)" // etc.
"role.network_admin": "Administrador(a/e) da rede AnarBib" // etc.
```

Voir §2.4 pour les valeurs dans chaque locale.

### 5.3 Statut du compte (3 clés × 6 locales = 18 entrées)

Probablement déjà existantes (`account.status.active`, etc.). À vérifier.

---

## 6. Risques et points d'attention

### 6.1 Risque CSS

Les classes `cat-pill-amber`, `cat-pill-info`, `cat-pill-ok` doivent exister. Si elles n'existent pas (seule `cat-pill ok/info/warn` à classes composites existe selon nos sessions passées), prévoir un mini-patch CSS dédié dans `UserHeroBadge.css` avec sélecteurs locaux.

### 6.2 Risque ID public

Vérifier que `profile.public_id` est bien disponible dans `AuthContext`. Sinon, ajouter une requête depuis le hook ou enrichir `AuthContext` (chantier annexe à scinder).

### 6.3 Risque doctrine multi-membership

Le guide de gouvernance §5.6 (p.20) acte qu'une personne peut avoir plusieurs lignes de membership avec des rôles différents dans la même biblio. Notre doctrine actuelle affiche le rôle « de plus haut niveau actif » via `useLibrary().role`. Le hook `useEffectiveScope` ne fait pas autre chose : il s'aligne sur cette doctrine déjà actée. Pas de risque nouveau.

### 6.4 Risque pages mobile

Les héros sont déjà responsive sur les autres pages. Le composant `<UserHeroBadge>` utilise `flex-wrap`, donc les pills s'enroulent automatiquement sur mobile. À vérifier visuellement quand même en phase B.

### 6.5 Risque ordre i18n

Les clés `nav.manual.reader` existaient déjà avant ce chantier (cf. session du 12/05/2026, paquet réglement). Vérifier que la valeur actuelle correspond à la doctrine §5.1 avant de patcher (ne pas écraser une traduction déjà militante par une traduction générée).

---

## 7. Définition de fin de chantier

Le chantier est clos lorsque :

1. Les 7 pages affichent un hero conforme à §2.1 (bloc identité complet + boutons doc selon §2.5).
2. Le code couleur §2.2 est respecté visuellement sur les 7 pages.
3. Le composant `<UserHeroBadge>` est utilisé partout, aucune logique d'affichage du badge dupliquée dans les pages.
4. Le PDF guide-gouvernance est dans le bucket et accessible via les boutons.
5. Les 6 locales sont à parité sur les nouvelles clés.
6. `npm run build` passe sans warning nouveau.
7. La session est tracée dans `docs/decisions/`.

---

## 8. Prérequis bloquants

Aucun. Toutes les dépendances backend (table `network_administrators`, vue `api.network_administrators_public_v1`, `LibraryContext.isNetworkAdmin`) sont déjà en prod (cf. paquet F admin réseau bouclé le 13/05/2026).

---

*Fin du document de chantier.*
