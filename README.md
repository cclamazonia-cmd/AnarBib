# AnarBib

**Système intégré de gestion de bibliothèques (SIGB) pour bibliothèques militantes anarchistes.**

Frontend React + Vite hébergé sur Codeberg, déployé sur Codeberg Pages, connecté à un backend Supabase.

- Repo principal : <https://codeberg.org/anarbib/anarbib>
- Miroir GitHub (legacy) : <https://github.com/cclamazonia-cmd/AnarBib>
- Application en production : <https://app.anarbib.org>

## Démarrage rapide

```bash
npm install
npm run dev
```

L'application tourne sur `http://localhost:5173/`.

## Déploiement sur Codeberg Pages

Le site `app.anarbib.org` est servi par Codeberg Pages depuis la branche de publication du repo Codeberg.

### Option 1 — Déploiement manuel (actuel)

```bash
npm run deploy
```

Cette commande build le projet (`vite build`) puis publie le dossier `dist/` via `gh-pages`. Les remotes du repo doivent être configurés ainsi :

```
codeberg → https://codeberg.org/anarbib/anarbib.git    (push principal)
origin   → https://github.com/cclamazonia-cmd/AnarBib   (miroir, optionnel)
```

Pour pousser le code source sur les deux remotes après un commit :

```bash
git push codeberg main
git push origin main   # miroir GitHub, optionnel
```

### Option 2 — CI/CD (à venir)

Un workflow Woodpecker CI sur Codeberg pourra déployer automatiquement à chaque push sur `main`. À configurer.

## Configuration

### Supabase

Les clés Supabase sont configurées dans `src/lib/supabase.js` avec des valeurs par défaut qui pointent vers le projet staging. Pour un environnement différent, créer un `.env.local` :

```env
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

### Custom domain et base URL

Le site est servi sur `app.anarbib.org` (custom domain configuré dans Codeberg Pages). En conséquence :

- `vite.config.js` : `base: '/'`
- `src/App.jsx` : `<BrowserRouter basename="/">`

Pour un déploiement sous-chemin (ex: `codeberg.io/anarbib/anarbib/`), il faudrait ajuster ces deux valeurs.

## Architecture

```
src/
├── components/
│   ├── layout/          # PageShell, Topbar, Hero, Footer, ProtectedRoute
│   ├── ui/              # Button, Input, Card, Sheet, Pill, StatusBadge, etc.
│   └── forms/           # CountrySelect, PhoneInput, StateSelect, countryData
├── contexts/
│   ├── AuthContext.jsx   # État d'authentification Supabase
│   └── LibraryContext.jsx # Bibliothèque active, memberships
├── hooks/               # (à venir) Hooks personnalisés
├── i18n/
│   ├── index.js          # Configuration react-intl + détection navigateur
│   └── locales/
│       ├── pt-BR.json    # Locale de référence
│       ├── fr.json
│       ├── es.json
│       ├── en.json
│       ├── it.json
│       └── de.json
├── lib/
│   ├── supabase.js       # Client Supabase
│   ├── theme.js          # Chargement dynamique de thème (manifests JSON)
│   └── countries.js      # Helper noms de pays (i18n-iso-countries)
├── pages/
│   ├── public/           # Catalogue, fiche livre, fiche auteur, login, signup
│   ├── account/          # Compte lecteur
│   ├── painel/           # Tableau de bord bibliothécaire
│   ├── biblioteca/       # Configuration bibliothèque
│   ├── catalogacao/      # Catalogage (livres, auteurs, exemplaires, drafts)
│   ├── importacoes/      # Import de catalogues partenaires
│   └── rede/             # Dashboard réseau inter-bibliothèques
├── styles/
│   ├── theme-base.css    # Variables CSS de marque
│   └── catalog.css       # Grille du catalogue
├── App.jsx               # Router + Providers
└── main.jsx              # Point d'entrée

notes-audit/              # Documentation de référence
├── anarbib-charte-langage-inclusif-v1.md
├── anarbib-i18n-audit-2026-04-28.md
└── ...

scripts/
└── apply-patch.ps1       # Outil d'application de patches (Windows PowerShell)
```

## Stratégie de migration

Cette application remplace deux repos monolithiques :

- `anarbib-staging` (catalogue public, ~61 000 lignes)
- `anarbib-conta-staging` (espace connecté, ~26 000 lignes)

### État de la migration

| Page | Statut |
|---|---|
| Catalogue public (recherche, résultats) | ✅ |
| Fiche livre | ✅ |
| Fiche auteur | ✅ |
| Login | ✅ |
| Création de compte | ✅ |
| Compte lecteur (réservations, prêts) | ✅ |
| Painel (structure à onglets) | ✅ |
| Biblioteca (configuration) | ✅ |
| Importações (import de catalogues partenaires) | ✅ |
| Catalogação (formulaire de catalogage) | ✅ (module avancé en cours) |
| Rede (dashboard réseau) | ✅ |
| Sollicitation réseau | ✅ |
| Lecteur de ressources numériques | ✅ |

La migration des pages principales est complète. Restent quelques chantiers ciblés : module de catalogage avancé, optimisations de performance, couverture i18n résiduelle.

### Coexistence avec l'ancien frontend

Pendant la migration, les pages non encore migrées peuvent pointer vers les anciennes URL via un `<a href="...">`. À ce stade la quasi-totalité des pages sont natives à AnarBib v3.

## i18n — Internationalisation

L'interface est disponible en **6 langues** :

| Locale | Statut | Convention de langage inclusif |
|---|---|---|
| `pt-BR` | Locale de référence | Forme triple `(o/a/e)` ou `(a/e)` |
| `fr` | Cohérente | Point médian (`lecteur·rice`) |
| `es` | Cohérente | `e` neutre argentin (`compañere`) + articles neutres (`le`, `les`, `une`) |
| `en` | Cohérente | Termes épicènes par défaut |
| `it` | Cohérente | Slash (`compagno/a`) — convention provisoire |
| `de` | Cohérente | Genderstern (`Genoss*in`) |

L'application détecte automatiquement la langue du navigateur. Un sélecteur permet de la changer manuellement (avec rechargement).

### Documents de référence

Avant toute traduction ou ajout de clé, consulter **obligatoirement** :

- [`notes-audit/anarbib-charte-langage-inclusif-v1.md`](notes-audit/anarbib-charte-langage-inclusif-v1.md) — Charte v1.0 fixant les conventions inclusives par langue, les termes politiques de référence et **les termes proscrits** (notamment `camerata` en italien et `Compas` non traduit en allemand).
- [`notes-audit/anarbib-i18n-audit-2026-04-28.md`](notes-audit/anarbib-i18n-audit-2026-04-28.md) — Rapport d'audit de cohérence i18n (clés manquantes, orphelines, asymétries).

### Workflow d'ajout d'une nouvelle clé

1. **Ajouter la clé dans le code** : utiliser `t({id:'mon.nouveau.label'})` (jamais de chaîne en dur).
2. **Définir la clé dans `pt-BR.json`** (référence).
3. **Traduire dans les 5 autres locales** en respectant la charte de langage inclusif.
4. **Lancer les tests** : `npm test` — le test `i18n.test.js` vérifie automatiquement que toutes les clés du code sont définies dans toutes les locales.

Une clé partiellement traduite est un bug — le test fera échouer le build.

### Modèle de prompt pour traduction par IA

Si tu utilises une IA (Claude, GPT…) pour traduire, **toujours fournir la charte en contexte** :

```
Tu traduis pour AnarBib (SIGB de bibliothèques militantes anarchistes).
Convention de langage inclusif obligatoire pour [LANGUE] : voir notes-audit/anarbib-charte-langage-inclusif-v1.md.
Ne jamais utiliser : camerata/camerati (italien, fasciste), Compas non traduit (allemand),
formes bureaucratiques /a ou (a) seul (espagnol et portugais).
Privilégier les formes épicènes quand elles existent.

Texte à traduire : [...]
```

### Ajouter une nouvelle langue

1. Créer `src/i18n/locales/xx.json` (copier `pt-BR.json` et traduire).
2. Ajouter la locale dans `src/i18n/index.js` (`SUPPORTED_LOCALES` + `MESSAGES`).
3. Ajouter l'enregistrement de la locale `i18n-iso-countries` dans `src/lib/countries.js`.
4. Compléter la section "Charte par langue" du document `notes-audit/anarbib-charte-langage-inclusif-v1.md` avec la convention typographique militante locale.
5. Lancer `npm test` pour vérifier la couverture complète.

### Tests de garde-fou

`i18n.test.js` exécute trois familles de tests :

- **Cohérence inter-locales** : toutes les locales ont le même ensemble de clés que `pt-BR.json`.
- **Couverture code ↔ locales** : toute clé `t({id:'...'})` utilisée dans `src/` est définie dans toutes les locales. Empêche le merge de toute clé manquante.
- **Conformité à la charte** : aucune occurrence de `camerata` en italien, aucun `Compas` non traduit en allemand, pas de formes bureaucratiques en pt-BR/es au-delà d'un seuil de tolérance.

Lancer avec : `npm test` ou `npx vitest`.

## Noms de pays — i18n-iso-countries

Les noms de pays sont localisés dynamiquement via le package `i18n-iso-countries` plutôt que d'être stockés dans les fichiers locale (qui auraient nécessité ~1500 entrées). Le helper `src/lib/countries.js` centralise l'enregistrement des 6 locales et expose :

- `getCountryName(input, locale)` — retourne le nom localisé d'un pays. Accepte un code ISO 3166-1 (`'BR'`) **ou** un nom textuel (`'Brasil'`, `'France'`, `'E.U.A.'`) pour tolérer les données legacy.
- `getCountryNames(locale)` — retourne le map complet `{code: name}` pour les sélecteurs.
- `intlToIsoLocale(intlLocale)` — convertit une locale react-intl (`'pt-BR'`) vers le code i18n-iso-countries (`'pt'`).

Tout composant qui affiche un nom de pays doit utiliser ces helpers, jamais des clés `country.*` dans les locales JSON.

## Système de thèmes

Le thème de chaque bibliothèque est un manifest JSON stocké dans Supabase Storage (`library-ui-assets/themes/{slug}/manifest.json`). Il contrôle les couleurs, polices, images de fond et layout via des variables CSS.

Le hook `useTheme(slug)` dans `src/lib/theme.js` charge le manifest au runtime et injecte les variables CSS. Fallback automatique vers le thème `default` en cas d'erreur.

## Outillage de développement

### Application de patches

Le script `scripts/apply-patch.ps1` (PowerShell, Windows) automatise l'application de patches structurés au format AnarBib :

```
patches/<phase>/
├── manifest.json
└── files/
    └── src/...      (fichiers à remplacer ou créer)
```

Usage :

```powershell
.\scripts\apply-patch.ps1 -PatchDir "C:\path\to\patches\phaseX" -DryRun  # simulation
.\scripts\apply-patch.ps1 -PatchDir "C:\path\to\patches\phaseX"          # application
```

Le script crée un snapshot de rollback dans `%TEMP%` avant toute modification.

⚠️ **Encodage** : ne pas utiliser PowerShell 5 pour traiter des fichiers contenant des caractères non-ASCII (accents, etc.). PowerShell 5 lit en CP-1252 par défaut et corrompt l'UTF-8. Préférer `git apply` ou des éditeurs UTF-8 natifs pour ces cas. Voir aussi `notes-audit/` pour les conventions adoptées suite aux incidents.

## Licence

Ce projet est développé pour la communauté des bibliothèques libertaires mondiales (FICEDL, RebAL, etc.).
