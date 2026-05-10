# AnarBib

**Système intégré de gestion de bibliothèques (SIGB) pour bibliothèques militantes anarchistes.**

Frontend React + Vite hébergé sur Codeberg, déployé sur Codeberg Pages via Woodpecker CI, backend Supabase (Postgres + Edge Functions Deno) en zone `sa-east-1`.

* Repo principal : [https://codeberg.org/anarbib/anarbib](https://codeberg.org/anarbib/anarbib)
* Miroir GitHub (legacy) : [https://github.com/cclamazonia-cmd/AnarBib](https://github.com/cclamazonia-cmd/AnarBib)
* Application en production : [https://app.anarbib.org](https://app.anarbib.org)

L'application est **en production** et utilisée par la Biblioteca Libertária Maxwell Ferreira (BLMF, Belém do Pará, Brésil). D'autres bibliothèques (CIRA Marseille, Biblioteca Terra Livre, Maloca Libertária) ont été sondées pour participer au projet.

## Démarrage rapide

```bash
npm install
npm run dev
```

L'application tourne sur `http://localhost:5173/`. Les variables d'environnement Supabase ont des valeurs par défaut pointant vers le projet de staging — pour une connexion à un autre projet, voir [Configuration](#configuration).

### Tests

```bash
npm test
```

Lance la suite vitest (tests JavaScript). Pour les tests SQL d'acceptation, voir [Tests SQL](#tests-sql).

### Build et déploiement local

Le déploiement en production passe par Woodpecker CI (voir [Déploiement](#déploiement)). Le build local sert principalement de quality gate avant push :

```bash
npm run build
```

## Architecture

```
anarbib-app/
├── src/
│   ├── components/
│   │   ├── layout/          # PageShell, Topbar, Hero, Footer, ProtectedRoute, Skeleton
│   │   ├── ui/              # Button, Input, Card, Sheet, Pill, StatusBadge, SortHeader, etc.
│   │   └── forms/           # CountrySelect, PhoneInput, StateSelect, countryData
│   ├── contexts/
│   │   ├── AuthContext.jsx       # État d'authentification Supabase
│   │   └── LibraryContext.jsx    # Bibliothèque active, memberships, rôle
│   ├── hooks/
│   │   └── useSort.js            # Tri par colonnes (paquet 18)
│   ├── i18n/
│   │   ├── index.js              # Configuration react-intl + détection navigateur
│   │   └── locales/
│   │       ├── pt-BR.json        # Locale de référence (\~1700 clés)
│   │       ├── fr.json
│   │       ├── es.json
│   │       ├── en.json
│   │       ├── it.json
│   │       └── de.json
│   ├── lib/
│   │   ├── supabase.js           # Client Supabase
│   │   ├── theme.js              # Chargement dynamique de thème
│   │   └── countries.js          # Helper noms de pays (i18n-iso-countries)
│   ├── pages/
│   │   ├── public/               # Catalogue, fiche livre, fiche auteur, login, signup
│   │   ├── account/              # Espace lecteur (réservations, prêts, profil)
│   │   ├── painel/               # Tableau de bord bibliothécaire
│   │   ├── biblioteca/           # Configuration bibliothèque (règlement, équipe, stats)
│   │   ├── catalogacao/          # Catalogage (livres, auteurs, exemplaires, drafts)
│   │   ├── importacoes/          # Import de catalogues partenaires
│   │   └── rede/                 # Dashboard réseau inter-bibliothèques
│   ├── styles/
│   │   ├── theme-base.css        # Variables CSS de marque
│   │   └── catalog.css           # Grille du catalogue
│   ├── App.jsx                   # Router + Providers
│   └── main.jsx                  # Point d'entrée
│
├── supabase/
│   └── migrations/               # Migrations SQL versionnées (format YYYYMMDDHHMMSS\_\*.sql)
│
├── tests/
│   └── sql/                      # Tests SQL d'acceptation (lancés manuellement, hors CI)
│       ├── README.md
│       └── paquet19\_loan\_wrappers\_tests.sql
│
├── notes-audit/                  # Documentation de référence
│   ├── anarbib-charte-langage-inclusif-v1.md
│   └── anarbib-i18n-audit-2026-04-28.md
│
├── docs/                         # Documentation projet (specs, décisions)
│   ├── specs/                    # Specs de chantiers (workflow réservation, emprunts, gouvernance, etc.)
│   ├── decisions/                # Notes de décisions de session
│   └── legal/                    # Documents juridiques
│
├── scripts/
│   └── apply-patch.ps1           # Outil historique (largement remplacé par le workflow Claude direct)
│
├── .woodpecker.yml               # Configuration CI Codeberg
└── CHANGELOG.md                  # Historique des paquets déployés (à générer)
```

Les **Edge Functions** Deno (`notify-event`, `register`, `mail-i18n-test`) sont gérées hors de ce repo, dans un projet séparé (`C:\\Users\\accat\\AnarBib-functions`). Elles sont déployées via la CLI Supabase (`supabase functions deploy <name> --no-verify-jwt`).

## Configuration

### Supabase

Le projet utilise un fallback hardcodé pointant vers le projet de staging dans `src/lib/supabase.js`. Pour un environnement différent, créer un `.env.local` à la racine :

```env
VITE\_SUPABASE\_URL=https://xxxxx.supabase.co
VITE\_SUPABASE\_ANON\_KEY=eyJ...
```

### Domaine et base URL

Le site est servi sur `app.anarbib.org` (custom domain configuré dans Codeberg Pages). Configuration en place :

* `vite.config.js` : `base: '/'`
* `src/App.jsx` : `<BrowserRouter basename="/">`

Pour un déploiement sous-chemin (ex: `codeberg.io/anarbib/anarbib/`), il faudrait ajuster ces deux valeurs.

## Déploiement

Le déploiement est **automatisé** via Woodpecker CI sur Codeberg. Chaque push sur `main` déclenche :

1. **`mirror-to-github`** : push vers le miroir GitHub (legacy, conservé pour visibilité)
2. **`deploy-migrations`** : exécute `supabase db push --linked --include-all` pour appliquer toute migration SQL présente dans `supabase/migrations/`
3. **Build et publication frontend** sur Codeberg Pages

### Convention pour les migrations SQL

Toute migration doit être placée dans `supabase/migrations/` avec un nom au format :

```
YYYYMMDDHHMMSS\_description.sql
```

Exemples :

```
20260510183000\_paquet15\_format\_holding\_refs\_in\_errors.sql
20260511010000\_paquet20v2\_resolve\_caller\_role\_leitor\_fix.sql
```

La migration est exécutée automatiquement par le pipeline CI au push suivant. Toute migration **doit être idempotente** (`CREATE OR REPLACE FUNCTION`, `CREATE TABLE IF NOT EXISTS`, etc.) pour permettre des replays sans casser la base.

### Secrets Woodpecker

Trois secrets sont configurés au niveau de l'organisation Codeberg :

* `supabase\_access\_token` : token d'API Supabase
* `supabase\_project\_ref` : `uflwmikiyjfnikiphtcp`
* `supabase\_db\_password` : mot de passe de connexion directe Postgres

### Helper PowerShell pour push double remote

Le projet supporte aussi un push manuel vers les deux remotes si nécessaire :

```bash
git push codeberg main
git push origin main   # miroir GitHub
```

Un alias `git publish-app` est défini en local pour combiner les deux push.

### Déploiement des Edge Functions

Les Edge Functions ne sont **pas** déployées automatiquement par Woodpecker (limitation actuelle, item au backlog). Pour les mettre à jour :

```bash
cd C:\\Users\\accat\\AnarBib-functions
supabase functions deploy notify-event --no-verify-jwt
```

## Backend Supabase

### Organisation des schémas

* **`public`** : tables métier, vues, fonctions PL/pgSQL internes. Toutes les fonctions DEFINER critiques (`fn\_v2\_\*`) y résident.
* **`api`** : couche d'API publique exposée à `authenticated`. Wrappers `SECURITY INVOKER` qui valident l'authentification, le rôle de l'appelant, et les transitions de workflow avant de déléguer aux fonctions DEFINER.
* **`auth`** : géré par Supabase, lecture seule.

### Pattern des wrappers `api.\*`

Tous les workflows métier (réservations, emprunts, etc.) passent par des wrappers `api.\*` :

1. `auth.uid()` obligatoire (rejet `28000` sinon)
2. Lecture du contexte (library, ownership) via helpers (`fn\_get\_loan\_context`, etc.)
3. Résolution du rôle via `fn\_resolve\_caller\_role\_for\_library(library\_id)` → `coordenador` / `administrador` / `librarian` / `leitor` / `NULL`
4. Vérification d'autorisation via helper d'action ou de transition :

   * `fn\_check\_workflow\_transition(from, to, role)` pour les réservations
   * `fn\_check\_loan\_action(action, status, role)` pour les emprunts
5. Délégation à la fonction DEFINER (`fn\_v2\_\*`)
6. Retour structuré pour le frontend

Cette architecture centralise le contrôle d'accès dans la couche `api.\*`, garde la logique métier dans les fonctions DEFINER, et permet aux frontends de raisonner en termes métiers (`api.create\_loan\_at\_counter` au lieu de `fn\_v2\_create\_emprestimo\_by\_holdings`).

### Edge Functions

Trois fonctions Deno hébergées chez Supabase :

* **`notify-event`** : router de notifications mail. Reçoit un événement (création d'emprunt, échéance proche, réservation prête, etc.) et dispatche vers le bon template multilingue selon le destinataire (lecteur vs biblio).
* **`register`** : inscription publique. Crée le profil + membership lecteur, lit `preferred\_language` depuis `raw\_user\_meta\_data`.
* **`mail-i18n-test`** : utilitaire de prévisualisation des templates mail dans toutes les locales via paramètre URL.

Les chaînes mail sont centralisées dans `\_shared/i18n/mail-strings.ts` (37+ clés × 6 langues). La locale du destinataire est résolue depuis `profile.preferred\_language` (avec fallback pt-BR), ou pour les mails biblio depuis `libraries.default\_locale`.

## i18n — Internationalisation

L'interface est disponible en **6 langues**, avec un engagement de **langage inclusif militant** par langue :

|Locale|Statut|Convention de langage inclusif|
|-|-|-|
|`pt-BR`|Locale de référence|Forme triple `(o/a/e)` ou `(a/e)` — pas de formes `@`, `x` ou `e` seul|
|`fr`|Cohérente|Point médian (`lecteur·rice`, `compas`)|
|`es`|Cohérente|`e` neutre argentin (`compañere`) + articles neutres (`le`, `les`, `une`)|
|`en`|Cohérente|Termes épicènes par défaut, singular `they`|
|`it`|Cohérente|Slash (`compagno/a`) — convention provisoire en attendant arbitrage du collectif italien|
|`de`|Cohérente|Genderstern (`Genoss\*in`)|

L'application détecte automatiquement la langue du navigateur. Un sélecteur permet de la changer manuellement.

### Documents de référence

Avant toute traduction ou ajout de clé, consulter **obligatoirement** :

* [`notes-audit/anarbib-charte-langage-inclusif-v1.md`](notes-audit/anarbib-charte-langage-inclusif-v1.md) — Charte v1.0 fixant les conventions par langue et **les termes proscrits** (notamment `camerata`/`camerati` en italien et `Compas` non traduit en allemand, tous deux à connotation fasciste historique).
* [`notes-audit/anarbib-i18n-audit-2026-04-28.md`](notes-audit/anarbib-i18n-audit-2026-04-28.md) — Audit de cohérence i18n.

### Workflow d'ajout de clé

1. Utiliser `t({id:'mon.nouveau.label'})` dans le code (jamais de chaîne en dur).
2. Définir la clé dans `pt-BR.json` (locale de référence).
3. Traduire dans les 5 autres locales en respectant la charte.
4. Lancer `npm test` — le test `i18n.test.js` vérifie la couverture complète.

### Modèle de prompt pour traduction par IA

Toujours fournir la charte en contexte :

```
Tu traduis pour AnarBib (SIGB de bibliothèques militantes anarchistes).
Convention de langage inclusif obligatoire pour \[LANGUE] : voir
notes-audit/anarbib-charte-langage-inclusif-v1.md.
Ne jamais utiliser : camerata/camerati (italien, fasciste), Compas
non traduit (allemand, fasciste), formes bureaucratiques /a ou (a)
seul (espagnol et portugais).
Privilégier les formes épicènes quand elles existent.

Texte à traduire : \[...]
```

### Mails multilingues

Les Edge Functions utilisent le helper `tMail(locale, key, params)` qui lit depuis `\_shared/i18n/mail-strings.ts`. La locale est résolue :

* Pour les mails lecteur : depuis `profile.preferred\_language`
* Pour les mails biblio : depuis `libraries.default\_locale`

Fallback systématique vers pt-BR si la locale n'est pas trouvée.

### Tests i18n

`i18n.test.js` exécute trois familles de garde-fous :

* **Cohérence inter-locales** : toutes les locales ont les mêmes clés que `pt-BR.json`
* **Couverture code ↔ locales** : toute clé `t({id:'...'})` utilisée dans `src/` est définie dans toutes les locales
* **Conformité à la charte** : absence de `camerata`, `Compas`, et formes bureaucratiques au-delà d'un seuil

## Tests

### Tests JavaScript

```bash
npm test          # vitest run
npx vitest        # mode watch
```

Couverture : i18n (couverture, cohérence, charte), helpers, quelques composants critiques. Pas encore de tests end-to-end (au backlog).

### Tests SQL

Les tests SQL d'acceptation sont dans `tests/sql/` et sont à lancer **manuellement** (hors flow CI auto). Architecture : un seul bloc `DO $$` avec accumulateurs, qui raise une `EXCEPTION` finale avec le bilan (`BILAN OK : N/N tests passes`).

**Lancement** :

1. Ouvrir https://supabase.com/dashboard/project/uflwmikiyjfnikiphtcp/sql/new
2. Coller le contenu du fichier de tests
3. Cliquer Run

Voir [`tests/sql/README.md`](tests/sql/README.md) pour les détails, fixtures (UUIDs des comptes test) et conventions.

Actuellement disponibles :

* **`paquet19\_loan\_wrappers\_tests.sql`** — 45 tests pour les wrappers `api.\*` d'emprunts (helpers `fn\_check\_loan\_action` + `fn\_get\_loan\_context`, 8 wrappers, couverture auth + rôle + statut + ownership)

À ajouter au fur et à mesure : tests pour les wrappers réservations (Phase 2), tests pour les RPCs `api.search\_catalog\_v1` et `api.library\_circulation\_stats`, tests RLS des vues `api.my\_\*\_v2`.

## Système de thèmes

Le thème de chaque bibliothèque est un manifest JSON stocké dans Supabase Storage (`library-ui-assets/themes/{slug}/manifest.json`). Il contrôle les couleurs, polices, images de fond et layout via des variables CSS.

Le hook `useTheme(slug)` dans `src/lib/theme.js` charge le manifest au runtime et injecte les variables CSS. Fallback automatique vers le thème `default` en cas d'erreur.

## Noms de pays — i18n-iso-countries

Les noms de pays sont localisés dynamiquement via le package `i18n-iso-countries` plutôt que d'être stockés dans les fichiers locale (qui auraient nécessité \~1500 entrées). Le helper `src/lib/countries.js` centralise l'enregistrement des 6 locales et expose :

* `getCountryName(input, locale)` — retourne le nom localisé d'un pays. Accepte un code ISO 3166-1 (`'BR'`) **ou** un nom textuel (`'Brasil'`, `'France'`, `'E.U.A.'`) pour tolérer les données legacy.
* `getCountryNames(locale)` — retourne le map complet `{code: name}` pour les sélecteurs.
* `intlToIsoLocale(intlLocale)` — convertit une locale react-intl (`'pt-BR'`) vers le code i18n-iso-countries (`'pt'`).

Tout composant qui affiche un nom de pays doit utiliser ces helpers, jamais des clés `country.\*` dans les locales JSON.

## Outillage de développement

### Supabase CLI

Installation via Scoop sur Windows :

```powershell
scoop install supabase
```

Version utilisée actuellement : `v2.95.4`.

Commandes utilisées au quotidien :

* `supabase db push --linked` : applique les migrations locales sur le projet linké
* `supabase functions download <name>` : télécharge une Edge Function depuis le projet
* `supabase functions deploy <name> --no-verify-jwt` : déploie une Edge Function

⚠️ Le MCP Supabase fourni par Anthropic a une limite de taille qui empêche le déploiement de `notify-event` (\~150 KB bundled). Utiliser la CLI directement.

### Encodage Windows

PowerShell 5 lit les fichiers en CP-1252 par défaut, ce qui corrompt les fichiers UTF-8 contenant des accents. Pour les opérations qui touchent à des fichiers i18n ou des chaînes accentuées, **utiliser exclusivement** :

* PowerShell 7+
* VS Code (édition UTF-8 native)
* `git apply` pour les patches

Les commits messages avec des accents posent aussi problème en PowerShell : préférer un message ASCII (sans accents), ou passer par un fichier intermédiaire `git commit -F message.txt` créé en UTF-8 explicite.

### Credentials Codeberg

L'authentification git via Windows Credential Manager peut casser périodiquement. Pour réparer :

```powershell
control.exe /name Microsoft.CredentialManager
```

Puis supprimer les credentials Codeberg en cache et re-saisir le token au prochain push.

### Application de patches (legacy)

Le script `scripts/apply-patch.ps1` automatisait l'application de patches structurés au format AnarBib. Il est conservé pour référence historique, mais le workflow actuel utilise des PowerShell scripts ad-hoc générés par session Claude (modifications directes via `Copy-Item`, vérifications via `Select-String`, etc.).

## Backlog et historique

* **Backlog technique** : maintenu dans le document partagé `AnarBib-Backlog-2026-05-09.docx` (révision la plus récente). 77 items numérotés priorisés par score Impact × Effort. Couvre la sécurité, les chantiers fonctionnels (cotisations, BTL, gouvernance), l'UX, l'i18n résiduel, les tests et la documentation.
* **Historique des paquets déployés** : voir [`CHANGELOG.md`](./CHANGELOG.md) (à générer).
* **Notes de décisions** : `docs/decisions/SESSION\_YYYY-MM-DD.md` pour les sessions importantes.

## Licence

AnarBib est un logiciel libre développé pour la communauté des bibliothèques libertaires mondiales (FICEDL, RebAL, etc.).

Le projet utilise une **double licence** :

* **Code source** : [GNU Affero General Public License v3.0 (AGPL-3.0)](./LICENSE) — copyleft fort adapté au logiciel serveur. Toute personne déployant une version modifiée d'AnarBib (en SaaS ou autrement) est tenue de publier ses modifications sous la même licence.
* **Documentation** (notamment `docs/legal/`) : [Creative Commons Attribution-ShareAlike 4.0 International (CC-BY-SA-4.0)](./LICENSE-docs) — licence adaptée aux œuvres textuelles, avec la même logique copyleft. Voir [`docs/legal/README.md`](./docs/legal/README.md) pour le détail et les invitations à adapter / traduire.

Les bibliothèques adhérentes sont explicitement encouragées à forker, adapter, traduire et republier le code et la documentation pour leur propre contexte, à condition de redistribuer leurs adaptations sous les mêmes licences.

## Contribuer

Le projet est porté par un collectif restreint mais accueille les contributions ponctuelles ou régulières.

Pour contribuer :

1. Fork sur Codeberg : [https://codeberg.org/anarbib/anarbib](https://codeberg.org/anarbib/anarbib)
2. Lire la [charte de langage inclusif](notes-audit/anarbib-charte-langage-inclusif-v1.md) avant tout travail i18n
3. Branche dédiée par chantier, commits clairs (`feat:`, `fix:`, `docs:`)
4. PR vers `main` avec description du périmètre

Pour discuter d'un chantier important avant de coder, ouvrir une issue sur Codeberg ou contacter le mainteneur principal via le repo.

