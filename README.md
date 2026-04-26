# AnarBib

**Système intégré de gestion de bibliothèques (SIGB) pour bibliothèques militantes anarchistes.**

Frontend React + Vite déployé sur GitHub Pages, connecté à un backend Supabase.

## Démarrage rapide

```bash
npm install
npm run dev
```

L'application tourne sur `http://localhost:5173/anarbib/`.

## Déploiement sur GitHub Pages

### Option 1 — GitHub Actions (recommandé)

Le workflow `.github/workflows/deploy.yml` déploie automatiquement à chaque push sur `main`. Il suffit d'activer GitHub Pages avec la source "GitHub Actions" dans les settings du repo.

### Option 2 — Déploiement manuel

```bash
npm run deploy
```

Utilise `gh-pages` pour publier le dossier `dist/` sur la branche `gh-pages`.

## Configuration

### Supabase

Les clés Supabase sont configurées dans `src/lib/supabase.js` avec des valeurs par défaut qui pointent vers le projet staging. Pour un environnement différent, créer un `.env.local` :

```env
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

### Base URL GitHub Pages

Dans `vite.config.js`, ajuster la valeur `base` selon le nom du repo :

```js
base: '/anarbib/',  // ← nom du repo GitHub
```

Et dans `src/App.jsx`, le `basename` du `BrowserRouter` doit correspondre :

```jsx
<BrowserRouter basename="/anarbib">
```

## Architecture

```
src/
├── components/
│   ├── layout/          # PageShell, Topbar, Hero, Footer, ProtectedRoute
│   ├── ui/              # Button, Input, Card, Sheet, Pill, StatusBadge, etc.
│   ├── catalog/         # (à venir) Composants spécifiques au catalogue
│   ├── circulation/     # (à venir) Composants de circulation
│   └── admin/           # (à venir) Composants d'administration
├── contexts/
│   ├── AuthContext.jsx   # État d'authentification Supabase
│   └── LibraryContext.jsx # Bibliothèque active, memberships
├── hooks/               # (à venir) Hooks personnalisés
├── i18n/
│   ├── index.js          # Configuration react-intl
│   └── locales/
│       └── pt-BR.json    # Traductions portugais du Brésil
├── lib/
│   ├── supabase.js       # Client Supabase
│   └── theme.js          # Chargement dynamique de thème (manifests JSON)
├── pages/
│   ├── public/           # Catalogue, fiche livre, fiche auteur, login
│   ├── account/          # Compte lecteur
│   ├── painel/           # Tableau de bord bibliothécaire
│   └── rede/             # (à venir) Pages réseau
├── styles/
│   ├── theme-base.css    # Variables CSS de marque
│   └── catalog.css       # Grille du catalogue
├── App.jsx               # Router + Providers
└── main.jsx              # Point d'entrée
```

## Stratégie de migration

Cette application remplace deux repos monolithiques :

- `anarbib-staging` (catalogue public, ~61 000 lignes)
- `anarbib-conta-staging` (espace connecté, ~26 000 lignes)

### Migration progressive

La migration se fait **page par page**, en commençant par les plus simples :

1. ✅ Catalogue public (recherche, résultats)
2. ✅ Fiche livre
3. ✅ Fiche auteur
4. ✅ Login
5. ✅ Compte lecteur (réservations, prêts)
6. ✅ Painel (structure à onglets)
7. ⬜ Catalogação (formulaire de catalogage)
8. ⬜ Importações (import de catalogues partenaires)
9. ⬜ Biblioteca (configuration)
10. ⬜ Rede (dashboard réseau)
11. ⬜ Création de compte
12. ⬜ Sollicitation réseau
13. ⬜ Lecteur de ressources numériques

Chaque onglet du painel (réservations, emprunts, catalogage, imports, tâches, interbibliotecas) sera migré comme un composant indépendant chargé en lazy-loading.

### Coexistence avec l'ancien frontend

Pendant la migration, les pages non encore migrées peuvent pointer vers les anciennes URL GitHub Pages. Le composant `<a href="...">` classique suffit pour les liens sortants vers l'ancien site.

## i18n — Internationalisation

L'interface est en **portugais du Brésil** (`pt-BR`). Toutes les chaînes visibles par l'utilisateur sont dans `src/i18n/locales/pt-BR.json`.

Pour ajouter une langue :

1. Créer `src/i18n/locales/xx.json` (copier pt-BR.json et traduire)
2. Ajouter la locale dans `src/i18n/index.js` (SUPPORTED_LOCALES + MESSAGES)
3. L'application détecte automatiquement la langue du navigateur

## Système de thèmes

Le thème de chaque bibliothèque est un manifest JSON stocké dans Supabase Storage (`library-ui-assets/themes/{slug}/manifest.json`). Il contrôle les couleurs, polices, images de fond et layout via des variables CSS.

Le hook `useTheme(slug)` dans `src/lib/theme.js` charge le manifest au runtime et injecte les variables CSS. Fallback automatique vers le thème `default` en cas d'erreur.

## Licence

Ce projet est développé pour la communauté des bibliothèques libertaires.


