# AnarBib

**Système intégré de gestion de bibliothèques (SIGB) pour bibliothèques anarchistes.**
**Integrated library management system (ILMS) for anarchist libraries.**

Frontend React + Vite hébergé sur Codeberg, déployé sur Codeberg Pages via Woodpecker CI, backend Supabase (Postgres + Edge Functions Deno) en zone `sa-east-1`. Application multilingue (6 locales) en production.

React + Vite frontend hosted on Codeberg, deployed to Codeberg Pages via Woodpecker CI, Supabase backend (Postgres + Deno Edge Functions) in `sa-east-1` region. Multilingual application (6 locales) in production.

* Repo principal / Main repository : [https://codeberg.org/anarbib/anarbib](https://codeberg.org/anarbib/anarbib)
* Miroir GitHub / GitHub mirror : [https://github.com/cclamazonia-cmd/AnarBib](https://github.com/cclamazonia-cmd/AnarBib)
* Application en production / Production app : [https://app.anarbib.org](https://app.anarbib.org)
* Site vitrine / Project website : [https://anarbib.org](https://anarbib.org)

L'application est **en production** et utilisée par la Biblioteca Libertária Maxwell Ferreira (BLMF, Belém do Pará, Brésil) et la Biblioteca Terra Livre (BTL). D'autres bibliothèques (CIRA Marseille, Maloca Libertária) ont été sondées pour rejoindre le réseau fédéré.

The application is **in production** and used by the Biblioteca Libertária Maxwell Ferreira (BLMF, Belém do Pará, Brazil) and the Biblioteca Terra Livre (BTL). Other libraries (CIRA Marseille, Maloca Libertária) have been approached to join the federated network.

---

## Sommaire / Table of contents

* [État au 17 mai 2026 / State as of 17 May 2026](#état-au-17-mai-2026--state-as-of-17-may-2026)
* [Démarrage rapide / Quick start](#démarrage-rapide--quick-start)
* [Architecture](#architecture)
* [Configuration](#configuration)
* [Déploiement / Deployment](#déploiement--deployment)
* [Doctrines internalisées / Internalized doctrines](#doctrines-internalisées--internalized-doctrines)
* [Internationalisation / Internationalization](#internationalisation--internationalization)
* [Tests](#tests)
* [Système de thèmes / Theming system](#système-de-thèmes--theming-system)
* [Noms de pays / Country names](#noms-de-pays--country-names)
* [Outillage de développement / Development tooling](#outillage-de-développement--development-tooling)
* [Backlog et historique / Backlog and history](#backlog-et-historique--backlog-and-history)
* [Articulation des specs / Spec articulation](#articulation-des-specs--spec-articulation)
* [Licence / License](#licence--license)
* [Contribuer / Contributing](#contribuer--contributing)

---

## État au 17 mai 2026 / State as of 17 May 2026

### État au 17 mai 2026 *(FR)*

**Chantiers structurants livrés (mai 2026)** :

* **Admin réseau v0.3** — Séparation staff local / admin réseau transverse. Cooptation et retrait collectif à l'unanimité. Workflow complet sur 7 paquets (A à F) + 10 sous-handlers `network.*` dans la fonction `notify-event`. Spec : `docs/specs/spec-administrateur-reseau.md` v0.3 (974 lignes).
* **Workflow consultations sur place v2** — Spec bout-en-bout sur 6 phases. Phases 1-5 livrées : helpers, wrappers `api.*`, triggers, frontend lecteur et biblio, modal de planification, réponse créneau, reproposition. Spec : `docs/specs/spec-flux-consultations.md` v2 (871 lignes).
* **Onglet Historique du Panel biblio (#143)** — 6 sous-paquets : tabs 2 lignes, structure pills, 3 vues `api.painel_*_history_v1` security_invoker, i18n 20 clés × 6 locales, fetch paginé 50 items.
* **Hardening notifications consultations (#141)** — 7 bugs résolus en prod : mojibake, ordre des UPDATE narrative-avant-état, distinction `workflow_note` / `schedule_reply_note`, motifs propagés, interpolation des titres.
* **Linter Supabase** — 270 alertes → 184, 18 ERRORs → 0 (1 maintenue volontairement et documentée). 11 paquets de migration L.1 à L.11.

**Chantier en cours** : **Profils d'adoption (#98)** — 7 paquets A à G permettant à chaque bibliothèque de se positionner sur 4 axes politiques orthogonaux (`catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode`). Spec : `docs/specs/spec-profils-bibliotheque.md` v0.3 (934 lignes).

* Paquet A (infrastructure DB dormante) : ✅ livré
* Paquet B (transitions de profils — 6 sous-paquets) : **4/6 livrés** (B.1 tables d'audit, B.2 helpers de classification, B.3 RPC métier, B.4 jobs pg_cron). Reste B.5 (handler EF) et B.6 (i18n).
* Paquets C à G : à venir

### State as of 17 May 2026 *(EN)*

**Structural work delivered (May 2026)**:

* **Network admin v0.3** — Separation of local staff / transverse network admin. Unanimous co-optation and collective removal. Full workflow across 7 packages (A to F) + 10 `network.*` sub-handlers in the `notify-event` function. Spec: `docs/specs/spec-administrateur-reseau.md` v0.3 (974 lines).
* **On-site consultation workflow v2** — End-to-end spec across 6 phases. Phases 1-5 delivered: helpers, `api.*` wrappers, triggers, reader and library frontends, scheduling modal, slot reply, re-proposal. Spec: `docs/specs/spec-flux-consultations.md` v2 (871 lines).
* **Library Panel History tab (#143)** — 6 sub-packages: 2-line tabs, pills structure, 3 `api.painel_*_history_v1` security_invoker views, i18n 20 keys × 6 locales, paginated fetch 50 items.
* **Consultation notifications hardening (#141)** — 7 bugs resolved in production: mojibake, narrative-before-state UPDATE order, `workflow_note` / `schedule_reply_note` distinction, motive propagation, title interpolation.
* **Supabase linter** — 270 alerts → 184, 18 ERRORs → 0 (1 kept deliberately and documented). 11 migration packages L.1 to L.11.

**Work in progress**: **Adoption profiles (#98)** — 7 packages A to G allowing each library to position itself on 4 orthogonal political axes (`catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode`). Spec: `docs/specs/spec-profils-bibliotheque.md` v0.3 (934 lines).

* Package A (dormant DB infrastructure): ✅ delivered
* Package B (profile transitions — 6 sub-packages): **4/6 delivered** (B.1 audit tables, B.2 classification helpers, B.3 business RPCs, B.4 pg_cron jobs). Remaining: B.5 (EF handler) and B.6 (i18n).
* Packages C to G: upcoming

---

## Démarrage rapide / Quick start

### Démarrage rapide *(FR)*

```bash
npm install
npm run dev
```

L'application tourne sur `http://localhost:5173/`. Les variables d'environnement Supabase ont des valeurs par défaut pointant vers le projet de production — pour une connexion à un autre projet, voir [Configuration](#configuration).

#### Tests rapides

```bash
npm test           # vitest run (i18n, helpers, composants)
npx vitest         # mode watch
```

Pour les tests SQL d'acceptation, voir [Tests](#tests). Pour les tests QA manuels, voir la sous-section QA manuelle.

#### Build local

Le déploiement passe par Woodpecker CI (voir [Déploiement](#déploiement--deployment)). Le build local sert de quality gate avant push :

```bash
npm run build
```

### Quick start *(EN)*

```bash
npm install
npm run dev
```

The application runs at `http://localhost:5173/`. Supabase environment variables have default values pointing to the production project — to connect to a different project, see [Configuration](#configuration).

#### Quick tests

```bash
npm test           # vitest run (i18n, helpers, components)
npx vitest         # watch mode
```

For SQL acceptance tests, see [Tests](#tests). For manual QA testing, see the manual QA subsection.

#### Local build

Deployment goes through Woodpecker CI (see [Deployment](#déploiement--deployment)). Local builds serve as a quality gate before push:

```bash
npm run build
```

---

## Architecture

### Architecture *(FR)*

```
anarbib-app/
├── src/
│   ├── components/
│   │   ├── layout/          # PageShell, Topbar, Hero, Footer, ProtectedRoute, Skeleton
│   │   ├── ui/              # Button, Input, Card, Sheet, Pill, StatusBadge, SortHeader, NetworkAdminBadge
│   │   └── forms/           # CountrySelect, PhoneInput, StateSelect, countryData
│   ├── contexts/
│   │   ├── AuthContext.jsx       # État d'authentification Supabase
│   │   └── LibraryContext.jsx    # Bibliothèque active, memberships, rôle effectif, isNetworkAdmin
│   ├── hooks/
│   │   └── useSort.js            # Tri par colonnes
│   ├── i18n/
│   │   ├── index.js              # Configuration react-intl + détection navigateur
│   │   └── locales/
│   │       ├── pt-BR.json        # Locale de référence (~1700 clés)
│   │       ├── fr.json
│   │       ├── es.json
│   │       ├── en.json
│   │       ├── it.json
│   │       └── de.json
│   ├── lib/
│   │   ├── supabase.js           # Client Supabase
│   │   ├── theme.js              # Chargement dynamique de thème
│   │   ├── countries.js          # Helper noms de pays (i18n-iso-countries)
│   │   ├── scheduleFormat.js     # Helper formatSchedule pour créneaux consultas
│   │   └── roles.js              # Hiérarchie ROLE_RANK + STAFF_ROLES + effectiveRole
│   ├── pages/
│   │   ├── public/               # Catalogue, fiche livre, fiche auteur, login, signup
│   │   ├── account/              # Espace lecteur (réservations, prêts, consultas, profil)
│   │   ├── painel/               # Tableau de bord bibliothécaire
│   │   ├── biblioteca/           # Configuration bibliothèque (règlement, équipe, stats)
│   │   ├── catalogacao/          # Catalogage (livres, auteurs, exemplaires, drafts)
│   │   ├── importacoes/          # Import de catalogues partenaires
│   │   └── rede/                 # Dashboard réseau inter-bibliothèques + AdminsPanel
│   ├── styles/
│   │   ├── theme-base.css        # Variables CSS de marque
│   │   └── catalog.css           # Grille du catalogue
│   ├── App.jsx                   # Router + Providers
│   └── main.jsx                  # Point d'entrée
│
├── supabase/
│   ├── migrations/               # Migrations SQL versionnées (YYYYMMDDHHMMSS_*.sql)
│   │   ├── _TEMPLATE.sql         # Template doctrine création objets sécurisés
│   │   └── (~70 migrations)      # Paquets historiques 15-26, A-F admin réseau, L.1-L.11 linter, #141, B.1-B.4 profils
│   └── functions/
│       ├── notify-event/         # Routeur d'événements + handlers de domaine
│       │   ├── index.ts          # Registre des domaines (team.*, network.*)
│       │   └── _shared/
│       │       ├── domain/       # network.ts, consultas.ts, library_profile.ts (à venir B.5)
│       │       ├── mail/         # layout.ts (renderEmail + actionBox)
│       │       └── i18n/         # mail-strings.ts (toutes locales)
│       ├── register/             # Inscription nouvelles bibliothèques + welcome email
│       └── mail-i18n-test/       # Outil de test i18n des mails
│
├── tests/
│   └── sql/                      # Tests SQL d'acceptation
│
├── docs/
│   ├── specs/                    # Specs de chantiers
│   ├── decisions/                # Notes de décisions (CHANTIER_*, SESSION_*, QA_MANUELLE_*, Prompt-Reprise-*)
│   ├── backlogs/                 # Backlogs versionnés (AnarBib-Backlog-AAAA-MM-JJ-vN.md)
│   └── legal/                    # Documents juridiques
│
├── notes-audit/                  # Charte de langage inclusif + audit i18n
│
├── .githooks/
│   └── pre-commit                # Garde-fou doctrine SQL (REVOKE, SECURITY DEFINER, search_path)
│
├── .gitignore                    # Ignore .bak.*, create-*.cjs, fix-*.cjs (scripts Claude one-shot)
├── .woodpecker.yml               # Configuration CI Codeberg
└── README.md                     # Ce fichier
```

### Architecture *(EN)*

The codebase mirrors the structure above. Key directories:

* `src/` — React + Vite frontend with React Context for auth and library state, react-intl for i18n across 6 locales, themed UI components
* `supabase/migrations/` — Versioned SQL migrations applied automatically by Woodpecker CI on push to `main`
* `supabase/functions/` — Deno Edge Functions for transactional emails (`notify-event` is the main router), new library signups (`register`), and i18n testing (`mail-i18n-test`)
* `docs/` — Specifications (in French), decision logs, versioned backlogs, legal documents
* `notes-audit/` — Inclusive language charter (mandatory reading before any i18n work) and i18n audit logs
* `.githooks/pre-commit` — Doctrinal SQL guardrail that blocks commits violating the security object creation doctrine

---

## Configuration

### Configuration *(FR)*

#### Supabase

Le projet utilise un fallback hardcodé pointant vers le projet de production dans `src/lib/supabase.js` (`uflwmikiyjfnikiphtcp`). Pour un environnement différent (staging, test) :

```env
# .env.local
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

#### Domaine et base URL

Le site est servi sur `app.anarbib.org` (custom domain configuré dans Codeberg Pages). Configuration en place :

* `vite.config.js` : `base: '/'`
* `src/App.jsx` : `<BrowserRouter basename="/">`

### Configuration *(EN)*

#### Supabase

The project uses a hardcoded fallback pointing to the production project in `src/lib/supabase.js` (`uflwmikiyjfnikiphtcp`). For a different environment (staging, test):

```env
# .env.local
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

#### Domain and base URL

The site is served at `app.anarbib.org` (custom domain configured in Codeberg Pages). Configuration in place:

* `vite.config.js`: `base: '/'`
* `src/App.jsx`: `<BrowserRouter basename="/">`

---

## Déploiement / Deployment

### Déploiement *(FR)*

Le déploiement est **automatisé** via Woodpecker CI sur Codeberg. Chaque push sur `main` déclenche :

1. **`mirror-to-github`** : push vers le miroir GitHub
2. **`deploy-migrations`** : exécute `supabase db push --linked --include-all`
3. **Build et publication frontend** sur Codeberg Pages

#### Convention pour les migrations SQL

Toute migration doit être placée dans `supabase/migrations/` avec un nom au format `YYYYMMDDHHMMSS_description.sql`. Le pipeline CI l'applique automatiquement au push suivant.

**Doctrine de création d'objets backend sécurisés** (voir `docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md`) :

* Fonctions : `SECURITY DEFINER` + `SET search_path = public` + `REVOKE EXECUTE FROM PUBLIC` + `GRANT EXECUTE TO authenticated` explicite
* Tables : `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` + GRANT explicites + policies dédiées
* Vues : `security_invoker = on` (sauf cas exceptionnel documenté)
* Toute migration doit inclure un `DO`-block de vérification en fin de transaction

**⚠️ Piège Supabase identifié (17/05/2026)** : `ALTER DEFAULT PRIVILEGES` octroie automatiquement `EXECUTE` à `anon`, `authenticated`, `service_role` sur toute nouvelle fonction dans `public`. **`REVOKE FROM PUBLIC` seul ne suffit pas** pour rendre une fonction privée. Pour une fonction réellement isolée (cron/postgres uniquement) :

```sql
REVOKE EXECUTE ON FUNCTION public.fn_xxx() FROM PUBLIC, anon, authenticated, service_role;
```

Le hook `.githooks/pre-commit` enforce automatiquement la doctrine. Bypass légitime : `git commit --no-verify`.

#### Secrets Woodpecker

Trois secrets configurés au niveau de l'organisation Codeberg :

* `supabase_access_token` : token d'API Supabase
* `supabase_project_ref` : `uflwmikiyjfnikiphtcp`
* `supabase_db_password` : mot de passe de connexion directe Postgres

#### Configuration git double remote

Le repo a 2 URLs en push (Codeberg + GitHub) sur le remote `origin`. `git push` simple pousse aux deux remotes. Codeberg = déploiement principal (Woodpecker), GitHub = miroir. Alias `git publish-app` en fallback.

#### Déploiement des Edge Functions

Les Edge Functions ne sont **pas** déployées automatiquement par Woodpecker (item #118 du backlog). Pour les mettre à jour :

```bash
cd anarbib-app
supabase functions deploy notify-event --no-verify-jwt
supabase functions deploy register --no-verify-jwt
```

⚠️ Le MCP Supabase fourni par Anthropic a une limite de taille qui empêche le déploiement de `notify-event` (~150 KB bundlé, 20+ fichiers). Utiliser exclusivement la CLI.

### Deployment *(EN)*

Deployment is **automated** through Woodpecker CI on Codeberg. Every push to `main` triggers:

1. **`mirror-to-github`**: push to the GitHub mirror
2. **`deploy-migrations`**: runs `supabase db push --linked --include-all`
3. **Frontend build and publication** on Codeberg Pages

#### SQL migrations convention

Every migration must be placed in `supabase/migrations/` with a name following the `YYYYMMDDHHMMSS_description.sql` format. The CI pipeline applies it automatically on the next push.

**Secure backend object creation doctrine** (see `docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md`):

* Functions: `SECURITY DEFINER` + `SET search_path = public` + `REVOKE EXECUTE FROM PUBLIC` + explicit `GRANT EXECUTE TO authenticated`
* Tables: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` + explicit GRANTs + dedicated policies
* Views: `security_invoker = on` (unless exceptional case documented)
* Every migration must include a verification `DO`-block at the end of the transaction

**⚠️ Supabase pitfall identified (17/05/2026)**: `ALTER DEFAULT PRIVILEGES` automatically grants `EXECUTE` to `anon`, `authenticated`, `service_role` on every new function in `public`. **`REVOKE FROM PUBLIC` alone is not enough** to make a function private. For a truly isolated function (cron/postgres only):

```sql
REVOKE EXECUTE ON FUNCTION public.fn_xxx() FROM PUBLIC, anon, authenticated, service_role;
```

The `.githooks/pre-commit` hook automatically enforces the doctrine. Legitimate bypass: `git commit --no-verify`.

#### Woodpecker secrets

Three secrets configured at the Codeberg organization level:

* `supabase_access_token`: Supabase API token
* `supabase_project_ref`: `uflwmikiyjfnikiphtcp`
* `supabase_db_password`: direct Postgres connection password

#### Git double remote setup

The repo has 2 push URLs (Codeberg + GitHub) on the `origin` remote. A plain `git push` pushes to both remotes. Codeberg = primary deployment (Woodpecker), GitHub = mirror. `git publish-app` alias as fallback.

#### Edge Functions deployment

Edge Functions are **not** automatically deployed by Woodpecker (backlog item #118). To update them:

```bash
cd anarbib-app
supabase functions deploy notify-event --no-verify-jwt
supabase functions deploy register --no-verify-jwt
```

⚠️ The Supabase MCP provided by Anthropic has a size limit that prevents deploying `notify-event` (~150 KB bundled, 20+ files). Use the CLI exclusively.

---

## Doctrines internalisées / Internalized doctrines

### Doctrines internalisées *(FR)*

Ces doctrines ont émergé des chantiers récents et s'appliquent à tout nouveau code. Elles sont consignées dans `docs/decisions/`.

#### Ordre des UPDATEs en RPC métier (doctrine #141.2.E)

Quand un RPC modifie plusieurs tables liées par triggers `AFTER UPDATE`, toujours UPDATE la **source de vérité narrative** (ex. `workflow_v2.workflow_note`) AVANT la **source d'état** (ex. `linhas_v2.item_status` qui déclenche les notifications). Sinon le trigger lifecycle voit l'ancienne note.

Application au chantier profils B.3 : `fn_execute_library_profile_change` INSERT `library_profile_history` AVANT UPDATE `libraries.*_mode`.

#### Distinction `workflow_note` / `schedule_reply_note`

Dans `consulta_item_workflow_v2` :

* `workflow_note` = staff (motif d'action côté biblio)
* `schedule_reply_note` = lecteur (réponse au créneau proposé)

Les deux colonnes sont distinctes, les triggers et handlers doivent propager les deux selon le contexte.

#### Traçabilité coordination R8 généralisée (post #142)

Toute action initiée par le staff biblio sur un item lecteur génère un mail à `library_commons.coordination_email` en plus du mail au lecteur. Couvre `cancelada_biblioteca`, `nao_compareceu`, et probablement à terme extensions/renouvellements/retours.

#### Proposeur silencieux après 1er vote (admin réseau v0.3.1)

Le proposeur d'une cooptation est notifié **uniquement au 1er vote** (signal de démarrage), puis reste silencieux jusqu'au résultat. Implémenté via `voteCount === 1` sur `network_administrator_cooptation_votes` et `network_admin_collective_removal_votes`.

#### Mails militants : qui notifier ?

Principe directeur du SIGB : **notifier celui qui n'a pas initié l'action, pas celui qui agit**. Validé sur tous les workflows consultas et admin réseau.

#### Contrat `actionBox` (renderEmail)

Le paramètre `actionBox` de `renderEmail` (`_shared/mail/layout.ts:20-28`) attend :

```typescript
{ kind: 'action' | 'info', title: string, ctaUrl: string, ctaLabel: string }
```

**PAS** `{ kind, label, url }`. Mauvais contrat → bug runtime `Cannot read properties of undefined (reading 'replace')`. Toujours lire `layout.ts` avant de consommer `actionBox` dans un nouveau handler.

#### UTF-8 sur Windows PowerShell

Deux pièges symétriques sur Windows FR :

* **Écriture** : `Get-Content -Raw` lit en CP1252 et **corrompt** les fichiers UTF-8 avec caractères Unicode. Méthode sûre : `[System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))`, ou scripts Node `.cjs` qui utilisent `fs` UTF-8 par défaut.
* **Lecture/affichage** : `Get-Content` peut **afficher** des mojibakes (`â€"`, `Â·`) alors que le fichier est en réalité UTF-8 valide. Toujours vérifier avec `ReadAllText UTF-8` explicite avant de croire à un bug.

#### `onAuthStateChange` Supabase

**JAMAIS d'`async/await` dans le callback de `supabase.auth.onAuthStateChange`** : tout appel API Supabase y provoque un **deadlock** sur le prochain appel ailleurs dans l'app. Workaround obligatoire :

```javascript
supabase.auth.onAuthStateChange((event, session) => {
  setTimeout(() => {
    // appels async ici, hors du contexte du callback
  }, 0);
});
```

### Internalized doctrines *(EN)*

These doctrines emerged from recent work and apply to all new code. They are recorded in `docs/decisions/`.

#### UPDATE order in business RPCs (doctrine #141.2.E)

When an RPC modifies multiple tables linked by `AFTER UPDATE` triggers, always UPDATE the **narrative source of truth** (e.g. `workflow_v2.workflow_note`) BEFORE the **state source** (e.g. `linhas_v2.item_status` which triggers notifications). Otherwise the lifecycle trigger sees the old note.

Applied in profiles work B.3: `fn_execute_library_profile_change` INSERTs `library_profile_history` BEFORE UPDATE on `libraries.*_mode`.

#### `workflow_note` / `schedule_reply_note` distinction

In `consulta_item_workflow_v2`:

* `workflow_note` = staff (library-side action motive)
* `schedule_reply_note` = reader (reply to proposed slot)

The two columns are distinct, triggers and handlers must propagate both depending on context.

#### Generalized R8 coordination traceability (post #142)

Any action initiated by library staff on a reader's item generates a mail to `library_commons.coordination_email` in addition to the mail to the reader. Covers `cancelada_biblioteca`, `nao_compareceu`, and probably extensions/renewals/returns in the future.

#### Silent proposer after first vote (network admin v0.3.1)

The proposer of a co-optation is notified **only on the first vote** (start signal), then remains silent until the result. Implemented via `voteCount === 1` on `network_administrator_cooptation_votes` and `network_admin_collective_removal_votes`.

#### Militant mails: who to notify?

Guiding principle of the ILMS: **notify the one who did not initiate the action, not the one acting**. Validated across all consultation and network admin workflows.

#### `actionBox` contract (renderEmail)

The `actionBox` parameter of `renderEmail` (`_shared/mail/layout.ts:20-28`) expects:

```typescript
{ kind: 'action' | 'info', title: string, ctaUrl: string, ctaLabel: string }
```

**NOT** `{ kind, label, url }`. Wrong contract → runtime bug `Cannot read properties of undefined (reading 'replace')`. Always read `layout.ts` before consuming `actionBox` in a new handler.

#### UTF-8 on Windows PowerShell

Two symmetrical pitfalls on French Windows:

* **Writing**: `Get-Content -Raw` reads in CP1252 and **corrupts** UTF-8 files with Unicode characters. Safe method: `[System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))`, or Node `.cjs` scripts which use `fs` in UTF-8 by default.
* **Reading/display**: `Get-Content` can **display** mojibakes (`â€"`, `Â·`) while the file is actually valid UTF-8. Always verify with explicit `ReadAllText UTF-8` before assuming a bug exists.

#### Supabase `onAuthStateChange`

**NEVER use `async/await` inside the `supabase.auth.onAuthStateChange` callback**: any Supabase API call there causes a **deadlock** on the next call elsewhere in the app. Required workaround:

```javascript
supabase.auth.onAuthStateChange((event, session) => {
  setTimeout(() => {
    // async calls here, outside the callback context
  }, 0);
});
```

---

## Internationalisation / Internationalization

### Internationalisation *(FR)*

L'application est entièrement multilingue (pt-BR référence + fr, es, en, it, de). Les Edge Functions de notification mail utilisent le même système de clés via `_shared/i18n/mail-strings.ts`.

#### Charte de langage inclusif

Voir **obligatoirement** avant tout travail i18n :

* `notes-audit/anarbib-charte-langage-inclusif-v1.md` — Charte v1 fixant conventions par langue et **termes proscrits** (notamment `camerata`/`camerati` en italien et `Compas` non traduit en allemand, tous deux à connotation fasciste historique)
* `notes-audit/anarbib-i18n-audit-2026-04-28.md` — Audit de cohérence

État par locale :

| Locale | Cohérence | Convention principale |
|--------|-----------|----------------------|
| `pt-BR` | Référence | Suffixe `@` pluriel (`compañer@s`) + articles `xs`/`x` (`xs leitorxs`) |
| `fr` | Cohérente | Point médian (`lecteur·rice`, `compas`) |
| `es` | Cohérente | `e` neutre argentin (`compañere`) + articles neutres (`le`, `les`, `une`) |
| `en` | Cohérente | Termes épicènes par défaut, singular `they` |
| `it` | Cohérente | Slash (`compagno/a`) — convention provisoire |
| `de` | Cohérente | Genderstern (`Genoss*in`) |

#### Workflow d'ajout de clé

1. Utiliser `t({id:'mon.nouveau.label'})` dans le code (jamais de chaîne en dur)
2. Définir la clé dans `pt-BR.json`
3. Traduire dans les 5 autres locales en respectant la charte
4. `npm test` — `i18n.test.js` vérifie la couverture complète

#### Mails multilingues

Les Edge Functions utilisent `tMail(locale, key, params)` qui lit depuis `_shared/i18n/mail-strings.ts`. La locale est résolue :

* Mails lecteur : depuis `profile.preferred_language`
* Mails biblio : depuis `libraries.default_locale`

Fallback systématique vers pt-BR.

#### Modèle de prompt pour traduction par IA

```
Tu traduis pour AnarBib (SIGB de bibliothèques anarchistes).
Convention de langage inclusif obligatoire pour [LANGUE] : voir
notes-audit/anarbib-charte-langage-inclusif-v1.md.
Ne jamais utiliser : camerata/camerati (italien, fasciste), Compas
non traduit (allemand, fasciste), formes bureaucratiques /a ou (a)
seul (espagnol et portugais).
Privilégier les formes épicènes quand elles existent.

Texte à traduire : [...]
```

### Internationalization *(EN)*

The application is fully multilingual (pt-BR reference + fr, es, en, it, de). Mail notification Edge Functions use the same key system via `_shared/i18n/mail-strings.ts`.

#### Inclusive language charter

**Mandatory reading** before any i18n work:

* `notes-audit/anarbib-charte-langage-inclusif-v1.md` — Charter v1 fixing conventions per language and **banned terms** (notably `camerata`/`camerati` in Italian and untranslated `Compas` in German, both historically fascist-coded)
* `notes-audit/anarbib-i18n-audit-2026-04-28.md` — Consistency audit

State per locale:

| Locale | Consistency | Main convention |
|--------|-------------|----------------|
| `pt-BR` | Reference | Plural `@` suffix (`compañer@s`) + neutral articles `xs`/`x` (`xs leitorxs`) |
| `fr` | Consistent | Middle dot (`lecteur·rice`, `compas`) |
| `es` | Consistent | Argentinian neutral `e` (`compañere`) + neutral articles (`le`, `les`, `une`) |
| `en` | Consistent | Default epicene terms, singular `they` |
| `it` | Consistent | Slash (`compagno/a`) — provisional convention |
| `de` | Consistent | Genderstern (`Genoss*in`) |

#### Key addition workflow

1. Use `t({id:'my.new.label'})` in code (never hardcoded strings)
2. Define the key in `pt-BR.json`
3. Translate to the 5 other locales respecting the charter
4. `npm test` — `i18n.test.js` verifies complete coverage

#### Multilingual emails

Edge Functions use `tMail(locale, key, params)` which reads from `_shared/i18n/mail-strings.ts`. Locale is resolved:

* Reader mails: from `profile.preferred_language`
* Library mails: from `libraries.default_locale`

Systematic fallback to pt-BR.

#### AI translation prompt template

```
You are translating for AnarBib (an ILMS for anarchist libraries).
Inclusive language convention mandatory for [LANGUAGE]: see
notes-audit/anarbib-charte-langage-inclusif-v1.md.
Never use: camerata/camerati (Italian, fascist), untranslated Compas
(German, fascist), bureaucratic forms /a or (a) alone (Spanish and
Portuguese). Prefer epicene forms when they exist.

Text to translate: [...]
```

---

## Tests

### Tests *(FR)*

#### Tests JavaScript

```bash
npm test          # vitest run
npx vitest        # mode watch
```

Couverture : i18n (cohérence, charte, couverture code ↔ locales), helpers, quelques composants critiques. Pas encore de tests end-to-end automatisés (au backlog).

#### Tests SQL

Les tests SQL d'acceptation sont dans `tests/sql/` et sont lancés **manuellement** depuis le SQL Editor Supabase. Architecture : un seul bloc `DO $$` avec accumulateurs, qui raise une `EXCEPTION` finale avec le bilan (`BILAN OK : N/N tests passes`).

**Lancement** :

1. Ouvrir https://supabase.com/dashboard/project/uflwmikiyjfnikiphtcp/sql/new
2. Coller le contenu du fichier de tests
3. Cliquer Run

Voir `tests/sql/README.md` pour les détails, fixtures (UUIDs des comptes test) et conventions.

Actuellement disponibles :

* `paquet19_loan_wrappers_tests.sql` — 45 tests pour les wrappers `api.*` d'emprunts

#### QA manuelle

Plans de test manuels structurés à dérouler en prod pour identifier les bugs concrets et planifier des chantiers de hardening (sur le modèle de #141) :

* `docs/decisions/QA_MANUELLE_reservations-2026-05-17.md` — 10 scénarios réservations
* `docs/decisions/QA_MANUELLE_emprestimos-2026-05-17.md` — 10 scénarios emprunts

À dérouler en sessions dédiées (1-2h par doc). Sortie : liste de bugs `Br*` / `De*` à prioritiser dans le backlog.

#### Protocole de test RLS PostgREST simulé

Pour tester les policies RLS dans le SQL Editor, **toujours combiner** `SET LOCAL ROLE` avec `SET LOCAL "request.jwt.claims"`. Sans le `SET ROLE`, Postgres tourne en `postgres` (BYPASSRLS). Sans le `SET JWT`, le contexte est infidèle.

```sql
BEGIN;
-- Anon :
SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" = '{}';
-- ... tests ...

-- Authenticated :
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"<UUID>","role":"authenticated"}';
-- ... tests ...

ROLLBACK;
```

### Tests *(EN)*

#### JavaScript tests

```bash
npm test          # vitest run
npx vitest        # watch mode
```

Coverage: i18n (consistency, charter, code ↔ locales coverage), helpers, some critical components. No automated end-to-end tests yet (in backlog).

#### SQL tests

SQL acceptance tests live in `tests/sql/` and are run **manually** from the Supabase SQL Editor. Architecture: a single `DO $$` block with accumulators, raising a final `EXCEPTION` with the summary (`BILAN OK: N/N tests passed`).

**Running them**:

1. Open https://supabase.com/dashboard/project/uflwmikiyjfnikiphtcp/sql/new
2. Paste the test file content
3. Click Run

See `tests/sql/README.md` for details, fixtures (UUIDs of test accounts) and conventions.

Currently available:

* `paquet19_loan_wrappers_tests.sql` — 45 tests for the `api.*` loan wrappers

#### Manual QA

Structured manual test plans to run in production to identify concrete bugs and plan hardening work (modeled on #141):

* `docs/decisions/QA_MANUELLE_reservations-2026-05-17.md` — 10 reservation scenarios
* `docs/decisions/QA_MANUELLE_emprestimos-2026-05-17.md` — 10 loan scenarios

To be run in dedicated sessions (1-2h per doc). Output: list of `Br*` / `De*` bugs to prioritize in the backlog.

#### Simulated PostgREST RLS testing protocol

To test RLS policies in the SQL Editor, **always combine** `SET LOCAL ROLE` with `SET LOCAL "request.jwt.claims"`. Without `SET ROLE`, Postgres runs as `postgres` (BYPASSRLS). Without `SET JWT`, the context is unfaithful.

```sql
BEGIN;
-- Anon:
SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" = '{}';
-- ... tests ...

-- Authenticated:
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"<UUID>","role":"authenticated"}';
-- ... tests ...

ROLLBACK;
```

---

## Système de thèmes / Theming system

### Système de thèmes *(FR)*

Le thème de chaque bibliothèque est un manifest JSON stocké dans Supabase Storage (`library-ui-assets/themes/{slug}/manifest.json`). Il contrôle les couleurs, polices, images de fond et layout via des variables CSS.

Le hook `useTheme(slug)` dans `src/lib/theme.js` charge le manifest au runtime et injecte les variables CSS. Fallback automatique vers le thème `default` en cas d'erreur.

### Theming system *(EN)*

Each library's theme is a JSON manifest stored in Supabase Storage (`library-ui-assets/themes/{slug}/manifest.json`). It controls colors, fonts, background images and layout via CSS variables.

The `useTheme(slug)` hook in `src/lib/theme.js` loads the manifest at runtime and injects CSS variables. Automatic fallback to the `default` theme on error.

---

## Noms de pays / Country names

### Noms de pays *(FR)*

Les noms de pays sont localisés dynamiquement via `i18n-iso-countries` plutôt que d'être stockés dans les fichiers locale (qui auraient nécessité ~1500 entrées). Le helper `src/lib/countries.js` centralise l'enregistrement des 6 locales :

* `getCountryName(input, locale)` — accepte un code ISO 3166-1 (`'BR'`) ou un nom textuel (`'Brasil'`, `'France'`, `'E.U.A.'`)
* `getCountryNames(locale)` — retourne le map complet
* `intlToIsoLocale(intlLocale)` — convertit `'pt-BR'` → `'pt'`

Tout composant qui affiche un nom de pays doit utiliser ces helpers.

### Country names *(EN)*

Country names are dynamically localized via `i18n-iso-countries` rather than being stored in locale files (which would have required ~1500 entries). The `src/lib/countries.js` helper centralizes registration of the 6 locales:

* `getCountryName(input, locale)` — accepts an ISO 3166-1 code (`'BR'`) or a textual name (`'Brasil'`, `'France'`, `'E.U.A.'`)
* `getCountryNames(locale)` — returns the complete map
* `intlToIsoLocale(intlLocale)` — converts `'pt-BR'` → `'pt'`

Any component displaying a country name must use these helpers.

---

## Outillage de développement / Development tooling

### Outillage de développement *(FR)*

#### Supabase CLI

Installation via Scoop sur Windows :

```powershell
scoop install supabase
```

Version utilisée : `v2.95.4+`. Commandes courantes :

* `supabase db push --linked` : applique les migrations locales
* `supabase functions download <name>` : télécharge une Edge Function
* `supabase functions deploy <name> --no-verify-jwt` : déploie une Edge Function

#### Workflow migrations

⚠️ **Conventions critiques** (apprises sur incidents) :

* **NE PAS** coller de SQL dans le SQL Editor avant push (risque `relation already exists`)
* **NE PAS** utiliser `apply_migration` via le MCP Supabase (le timestamp = moment de l'appel, mismatch avec le fichier local → Woodpecker plante)
* **Workflow propre** : fichier dans `supabase/migrations/` avec timestamp futur → push → laisser Woodpecker appliquer
* Si bug : `git mv` au timestamp réel ou `migration repair --status applied` (non-destructif)

#### Credentials Codeberg

L'authentification git via Windows Credential Manager peut casser périodiquement. Pour réparer :

```powershell
control.exe /name Microsoft.CredentialManager
```

Puis supprimer les credentials Codeberg en cache et re-saisir le token au prochain push.

#### Scripts one-shot

Les sessions de développement avec Claude génèrent souvent des scripts Node.js `.cjs` éphémères pour créer/patcher des migrations. Ces scripts sont **ignorés par git** via `.gitignore` (pattern `create-*.cjs`, `fix-*.cjs`). Convention : les supprimer manuellement après usage (`Remove-Item create-*.cjs`).

### Development tooling *(EN)*

#### Supabase CLI

Install via Scoop on Windows:

```powershell
scoop install supabase
```

Version in use: `v2.95.4+`. Common commands:

* `supabase db push --linked`: applies local migrations
* `supabase functions download <name>`: downloads an Edge Function
* `supabase functions deploy <name> --no-verify-jwt`: deploys an Edge Function

#### Migration workflow

⚠️ **Critical conventions** (learned from incidents):

* **DO NOT** paste SQL into the SQL Editor before push (risk of `relation already exists`)
* **DO NOT** use `apply_migration` via the Supabase MCP (timestamp = call moment, mismatch with local file → Woodpecker fails)
* **Clean workflow**: file in `supabase/migrations/` with future timestamp → push → let Woodpecker apply
* If buggy: `git mv` to the real timestamp or `migration repair --status applied` (non-destructive)

#### Codeberg credentials

Git authentication via Windows Credential Manager can break periodically. To repair:

```powershell
control.exe /name Microsoft.CredentialManager
```

Then remove cached Codeberg credentials and re-enter the token on the next push.

#### One-shot scripts

Development sessions with Claude often generate ephemeral Node.js `.cjs` scripts to create/patch migrations. These scripts are **ignored by git** via `.gitignore` (pattern `create-*.cjs`, `fix-*.cjs`). Convention: delete them manually after use (`Remove-Item create-*.cjs`).

---

## Backlog et historique / Backlog and history

### Backlog et historique *(FR)*

#### Backlog actuel

Le backlog est maintenu dans `docs/backlogs/AnarBib-Backlog-2026-05-17-v15.md`. Convention de scoring = importance politique (1-10) + urgence technique (1-10).

**Items prioritaires en cours ou à venir** :

* **#98-B à G** (score 20) — Suite chantier profils d'adoption. Paquet B en cours (4/6 sous-paquets livrés).
* **#110** (score 15) — Migration mail Brevo → Resend (cohérence anti-tracking militant).
* **#144** (score 12) — Dérouler les QA manuelles réservations + emprunts pour planifier le prochain chantier de hardening.
* **#139** (score 11) — Spec consultations v2.2 (intégrer doctrines #141 + R8).
* **#140** (score 8) — Spec admin réseau v0.3.2 (intégrer doctrine proposeur silencieux + R8 généralisée).

#### Notes de décisions

Les décisions importantes de chaque session sont consignées dans `docs/decisions/` :

* `CHANTIER_*.md` pour les doctrines durables (création objets sécurisés, transitions profils, etc.)
* `SESSION_*.docx` pour les comptes rendus de session
* `BUG_*.md` pour les bugs avec diagnostic
* `Prompt-Reprise-*.md` pour les passations entre sessions

### Backlog and history *(EN)*

#### Current backlog

The backlog is maintained in `docs/backlogs/AnarBib-Backlog-2026-05-17-v15.md`. Scoring convention = political importance (1-10) + technical urgency (1-10).

**Priority items in progress or upcoming**:

* **#98-B to G** (score 20) — Continuation of adoption profiles work. Package B in progress (4/6 sub-packages delivered).
* **#110** (score 15) — Brevo → Resend mail migration (militant anti-tracking consistency).
* **#144** (score 12) — Run manual QAs for reservations + loans to plan the next hardening work.
* **#139** (score 11) — Consultations spec v2.2 (integrate #141 doctrines + R8).
* **#140** (score 8) — Network admin spec v0.3.2 (integrate silent proposer + generalized R8 doctrines).

#### Decision notes

Important decisions from each session are recorded in `docs/decisions/`:

* `CHANTIER_*.md` for durable doctrines (secure object creation, profile transitions, etc.)
* `SESSION_*.docx` for session reports
* `BUG_*.md` for bugs with diagnosis
* `Prompt-Reprise-*.md` for inter-session handoffs

---

## Articulation des specs / Spec articulation

### Articulation des specs *(FR)*

Quatre specs principales structurent le projet. Hiérarchie de référence en cas de contradiction :

1. **`spec-administrateur-reseau.md` v0.3** — Implémentée en prod, fait foi
2. **`spec-profils-bibliotheque.md` v0.3** — Doctrine la plus récente, chantier en cours
3. **`spec-flux-consultations.md` v2** — Implémentée (sauf phase 6 tests E2E)
4. **`spec-gouvernance-roles.md` v1.0** — Partiellement périmée, à réviser en v1.1
5. **`spec-onboarding-biblioteca.md`** — Partiellement périmée, à réviser en v1.1

Les chantiers à venir doivent commencer par mettre à jour les specs périmées avant d'attaquer le code (Phase 0 du plan d'action 15/05).

### Spec articulation *(EN)*

Four main specs structure the project. Reference hierarchy in case of contradiction:

1. **`spec-administrateur-reseau.md` v0.3** — Implemented in production, authoritative
2. **`spec-profils-bibliotheque.md` v0.3** — Most recent doctrine, work in progress
3. **`spec-flux-consultations.md` v2** — Implemented (except phase 6 E2E tests)
4. **`spec-gouvernance-roles.md` v1.0** — Partially obsolete, to be revised as v1.1
5. **`spec-onboarding-biblioteca.md`** — Partially obsolete, to be revised as v1.1

Upcoming work should start by updating obsolete specs before tackling code (Phase 0 of the 15/05 action plan).

---

## Licence / License

### Licence *(FR)*

AnarBib est un logiciel libre développé pour la communauté des bibliothèques libertaires mondiales (FICEDL, RebAL, etc.).

Le projet utilise une **double licence** :

* **Code source** : [GNU Affero General Public License v3.0 (AGPL-3.0)](./LICENSE) — copyleft fort adapté au logiciel serveur. Toute personne déployant une version modifiée (en SaaS ou autrement) est tenue de publier ses modifications sous la même licence.
* **Documentation** (notamment `docs/legal/`) : [Creative Commons Attribution-ShareAlike 4.0 International (CC-BY-SA-4.0)](./LICENSE-docs).

Les bibliothèques adhérentes sont explicitement encouragées à forker, adapter, traduire et republier le code et la documentation pour leur propre contexte, à condition de redistribuer leurs adaptations sous les mêmes licences.

### License *(EN)*

AnarBib is free software developed for the global community of libertarian libraries (FICEDL, RebAL, etc.).

The project uses **dual licensing**:

* **Source code**: [GNU Affero General Public License v3.0 (AGPL-3.0)](./LICENSE) — strong copyleft suited to server software. Anyone deploying a modified version (as SaaS or otherwise) is required to publish their modifications under the same license.
* **Documentation** (notably `docs/legal/`): [Creative Commons Attribution-ShareAlike 4.0 International (CC-BY-SA-4.0)](./LICENSE-docs).

Adhering libraries are explicitly encouraged to fork, adapt, translate and republish the code and documentation for their own context, provided they redistribute their adaptations under the same licenses.

---

## Contribuer / Contributing

### Contribuer *(FR)*

Le projet est porté par un collectif restreint mais accueille les contributions ponctuelles ou régulières.

Pour contribuer :

1. Fork sur Codeberg : [https://codeberg.org/anarbib/anarbib](https://codeberg.org/anarbib/anarbib)
2. Lire la [charte de langage inclusif](notes-audit/anarbib-charte-langage-inclusif-v1.md) avant tout travail i18n
3. Lire les doctrines actives dans `docs/decisions/CHANTIER_*.md` avant tout travail SQL/DB
4. Branche dédiée par chantier, commits clairs (`feat:`, `fix:`, `docs:`, `chore:`)
5. PR vers `main` avec description du périmètre

Pour discuter d'un chantier important avant de coder, ouvrir une issue sur Codeberg ou contacter le mainteneur principal via le repo.

### Contributing *(EN)*

The project is carried by a small collective but welcomes occasional or regular contributions.

To contribute:

1. Fork on Codeberg: [https://codeberg.org/anarbib/anarbib](https://codeberg.org/anarbib/anarbib)
2. Read the [inclusive language charter](notes-audit/anarbib-charte-langage-inclusif-v1.md) before any i18n work
3. Read the active doctrines in `docs/decisions/CHANTIER_*.md` before any SQL/DB work
4. Dedicated branch per work item, clear commits (`feat:`, `fix:`, `docs:`, `chore:`)
5. PR to `main` with description of the scope

To discuss significant work before coding, open an issue on Codeberg or contact the main maintainer via the repo.

---

*Dernière mise à jour / Last updated: 17 mai 2026 / 17 May 2026 — fin de session B.4 paquet profils d'adoption / end of B.4 session in adoption profiles work.*
