# AnarBib

Système intégré de gestion de bibliothèques (SIGB) pour bibliothèques anarchistes. Integrated library management system (ILMS) for anarchist libraries.

Frontend React 19 + Vite 6 hébergé sur Codeberg, déployé sur Codeberg Pages via **Forgejo Actions** (CI/CD native Codeberg, runner auto-hébergé), backend Supabase (Postgres + Edge Functions Deno) en zone sa-east-1. Application multilingue (10 locales en parité de clés) en production, installable en PWA.

React 19 + Vite 6 frontend hosted on Codeberg, deployed to Codeberg Pages via **Forgejo Actions** (Codeberg-native CI/CD, self-hosted runner), Supabase backend (Postgres + Deno Edge Functions) in sa-east-1 region. Multilingual application (10 locales at key parity) in production, installable as a PWA.

Repo principal / Main repository : https://codeberg.org/anarbib/anarbib
Miroir GitHub (gelé, non synchronisé) / GitHub mirror (frozen, not synced) : https://github.com/cclamazonia-cmd/AnarBib
Application en production / Production app : https://app.anarbib.org
Site vitrine / Project website : https://anarbib.org

L'application est en production et utilisée par la Biblioteca Libertária Maxwell Ferreira (BLMF, Belém do Pará, Brésil). Le réseau fédéré est en cours de construction (outils fédéralistes : Communs, Entraide, Annuaire des collectifs). D'autres bibliothèques (Biblioteca Terra Livre, CIRA Marseille, Maloca Libertária) ont été sondées pour rejoindre le réseau.

The application is in production and used by the Biblioteca Libertária Maxwell Ferreira (BLMF, Belém do Pará, Brazil). The federated network is under construction (federalist tools: Commons, Mutual aid, Directory of collectives). Other libraries (Biblioteca Terra Livre, CIRA Marseille, Maloca Libertária) have been approached to join the network.

---

## Sommaire / Table of contents

- État au 24 juin 2026 / State as of 24 June 2026
- Démarrage rapide / Quick start
- Architecture
- Configuration
- Déploiement / Deployment
- Doctrines internalisées / Internalized doctrines
- Internationalisation / Internationalization
- Tests
- PWA / Progressive Web App
- Système de thèmes / Theming system
- Noms de pays / Country names
- Outillage de développement / Development tooling
- Backlog et historique / Backlog and history
- Articulation des specs / Spec articulation
- Licence / License
- Contribuer / Contributing

---

## État au 24 juin 2026 / State as of 24 June 2026

### État au 24 juin 2026 (FR)

Chantiers livrés depuis la mi-juin 2026 (15 → 24 juin) — vérifiés sur le backend de production :

- **Modèle Œuvre / Éditions / Expressions (FRBR-léger)** — Regroupement des éditions d'une même œuvre, suggestion d'éditions liées, vue publique d'œuvre et traducteurs par expression (migrations `works_model_lot1..4`, `works_v2_lotA..C`, `works_v3_expressions`, `works_v3_translators_per_expression`).
- **Support des médias audio** — Empreinte acoustique (`audio_fingerprint_lookup`, type AcoustID + `recording_mbid` MusicBrainz), sous-couche pistes/segments, exposition du MBID dans OAI (migrations `audio_p0..p5`).
- **Cartographie réseau livrée** — Schéma + RPC + soumissions publiques + géocodage (`submit-cartography-entry`, `geocode`), édition et flag PEB sur la carte des collectifs (l'onglet Annuaire n'est plus seulement verrouillé).
- **Gazette fédérée & lettre d'information** — Contributions (`submit-gazette-contribution`), build mensuel (`gazette-monthly-build`), abonnement/désabonnement (`lettre-confirm`, `lettre-unsubscribe`), digest réseau (`notify-rede-digest`).
- **Échange de fonds inter-bibliothèques** — Export/réception de *bundles* de fonds, dépôt direct, rattachement et révocation d'assets reçus, GC des dépôts (`export-fonds-bundle`, `receive-fonds-bundle`, `deposit-fonds-direct`, `attach-received-asset`, `revoke-digital-asset`, `gc-deposits`).
- **Fournisseur OAI-PMH** — `oai-pmh-provider` + notification d'ouverture (`notify-oai-opening`) : le catalogue est moissonnable.
- **Cycle de vie des adhésions lecteur** — Workflow d'adhésion (en attente, refus « two-strike », réactivation), application de l'adhésion active à la circulation, suggestion de numéro de lecteur, inscription publique optionnelle par bibliothèque (`reader_membership_lifecycle_log`, `enforce_active_membership_circulation`, `refusal_two_strike`, `signup_list_requires_*`).
- **Conformité RGPD** — Anonymisation du compte à la suppression (`fn_delete_my_account`).
- **Invitations d'équipe & onboarding** — Flux d'invitation du staff biblio (`invitation_equipe` + RPC + notification), évaluation collaborative d'onboarding.
- **Réconciliation catalogue / disponibilité** — Filet cron nocturne de réconciliation des compteurs de disponibilité (`holdings_availability_reconcile_cron`).
- **Backend porté à 41 Edge Functions** (contre 18 à la mi-juin) et **57 fichiers de migration** SQL (baseline + incréments), appliqués jusqu'au **23/06/2026** ; suite de tests Vitest verte (87 tests).

Chantiers structurants consolidés (mai–juin 2026) :

- **Migration CI/CD Woodpecker → Forgejo Actions (11/06/2026)** — Woodpecker hébergé étant devenu instable (~22 % d'uptime), la CI est passée aux **Forgejo Actions** natives de Codeberg (`.forgejo/workflows/ci.yml`), sur un **runner auto-hébergé** (`anarbib-local`, service systemd sur le WSL2 du mainteneur). Deux jobs séquentiels : `app` (install → lint bloquant → test bloquant → build Vite → déploiement Codeberg Pages) puis `backend` (`needs: app` → déploiement des Edge Functions → `supabase db push`). Le fichier `.woodpecker.yml` a été retiré.
- **Consolidation des remotes git sur Codeberg (12/06/2026)** — Fin du dual-push GitHub. `origin` **et** `codeberg` pointent désormais tous deux sur `codeberg.org/AnarBib/anarbib`. Le miroir GitHub `cclamazonia-cmd/AnarBib` n'est plus alimenté par git et reste en retard tant que l'auth GitHub (PAT/SSH) n'est pas rétablie — **sans impact** sur prod/CI/déploiement.
- **Socle PWA installable — MOBILE Paquet 0** — `manifest.webmanifest`, service worker (`public/sw.js`), jeu d'icônes (favicon, apple-touch-icon, icônes 192/512), métadonnées iOS/Android dans `index.html`. L'application est désormais installable sur l'écran d'accueil.
- **Outils fédéralistes (federacao)** — Mise en avant sur l'accueil des onglets **Communs**, **Entraide** et **Annuaire** (carte des collectifs, désormais alimentée par la cartographie). Spec : `docs/specs/spec-outils-federalistes.md` v0.2.
- **Internationalisation à 10 locales en parité stricte** — `pt-BR` (référence) + `fr, es, en, it, de, ca, eo, nl, el`, toutes câblées et chargées en lazy, parité de clés gardée par la CI. Charte de langage inclusif **v2** (2026-06-05) couvrant les 10 locales (la v1 est dépréciée).
- **Réorganisation de la documentation** — `docs/decisions/` renommé en `docs/journal/` (sous-dossiers typés), `notes-audit/` déplacé sous `docs/notes-audit/`. Corpus : `docs/governance/` (guide de gouvernance traduit en 10 langues), `docs/cartographie/`, `docs/schema/` (snapshot baseline), `docs/db/`.

Chantiers de fond hérités (toujours en production) : Admin réseau (cooptation/retrait collectif à l'unanimité), Profils d'adoption (4 axes politiques orthogonaux : `catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode`), workflow des consultations sur place. Leurs specs ont été révisées (voir Articulation des specs).

Le détail des chantiers en cours, des dettes et des priorités vit dans le backlog courant (`docs/backlogs/`, voir `INDEX.md` pour la version courante) et le `REGISTRE_decisions.md` des specs.

### State as of 24 June 2026 (EN)

Work delivered since mid-June 2026 (15 → 24 June) — verified against the production backend:

- **Work / Editions / Expressions model (light FRBR)** — Grouping editions of a single work, suggesting related editions, public work view and per-expression translators (migrations `works_model_lot1..4`, `works_v2_lotA..C`, `works_v3_expressions`, `works_v3_translators_per_expression`).
- **Audio media support** — Acoustic fingerprinting (`audio_fingerprint_lookup`, AcoustID + MusicBrainz `recording_mbid`), tracks/segments sublayer, MBID exposed in OAI (migrations `audio_p0..p5`).
- **Network cartography delivered** — Schema + RPC + public submissions + geocoding (`submit-cartography-entry`, `geocode`), editing and ILL flag on the collectives map (the Directory tab is no longer merely locked).
- **Federated gazette & newsletter** — Contributions (`submit-gazette-contribution`), monthly build (`gazette-monthly-build`), subscribe/unsubscribe (`lettre-confirm`, `lettre-unsubscribe`), network digest (`notify-rede-digest`).
- **Inter-library fonds exchange** — Export/receive fonds bundles, direct deposit, attach and revoke received assets, deposit GC (`export-fonds-bundle`, `receive-fonds-bundle`, `deposit-fonds-direct`, `attach-received-asset`, `revoke-digital-asset`, `gc-deposits`).
- **OAI-PMH provider** — `oai-pmh-provider` + opening notification (`notify-oai-opening`): the catalogue is harvestable.
- **Reader membership lifecycle** — Membership workflow (pending, "two-strike" refusal, reactivation), active-membership enforcement on circulation, next-reader-number suggestion, optional per-library public signup (`reader_membership_lifecycle_log`, `enforce_active_membership_circulation`, `refusal_two_strike`, `signup_list_requires_*`).
- **GDPR compliance** — Account anonymization on deletion (`fn_delete_my_account`).
- **Team invitations & onboarding** — Library-staff invitation flow (`invitation_equipe` + RPC + notification), collaborative onboarding evaluation.
- **Catalogue / availability reconciliation** — Nightly cron net reconciling availability counters (`holdings_availability_reconcile_cron`).
- **Backend grown to 41 Edge Functions** (up from 18 in mid-June) and **57 migration files** (baseline + increments) applied through **2026-06-23**; Vitest suite green (87 tests).

Structural work consolidated (May–June 2026):

- **CI/CD migration Woodpecker → Forgejo Actions (11/06/2026)** — Hosted Woodpecker having become unstable (~22% uptime), CI moved to Codeberg-native **Forgejo Actions** (`.forgejo/workflows/ci.yml`) on a **self-hosted runner** (`anarbib-local`, a systemd service on the maintainer's WSL2). Two sequential jobs: `app` (install → blocking lint → blocking test → Vite build → Codeberg Pages deploy) then `backend` (`needs: app` → Edge Functions deploy → `supabase db push`). The `.woodpecker.yml` file was removed.
- **Git remotes consolidated on Codeberg (12/06/2026)** — End of GitHub dual-push. `origin` **and** `codeberg` now both point to `codeberg.org/AnarBib/anarbib`. The GitHub mirror `cclamazonia-cmd/AnarBib` is no longer fed by git and stays behind until GitHub auth (PAT/SSH) is restored — **no impact** on prod/CI/deployment.
- **Installable PWA foundation — MOBILE Package 0** — `manifest.webmanifest`, service worker (`public/sw.js`), icon set (favicon, apple-touch-icon, 192/512 icons), iOS/Android metadata in `index.html`. The app is now installable to the home screen.
- **Federalist tools (federacao)** — Homepage surfaces the **Commons**, **Mutual aid** and **Directory** tabs (collectives map, now fed by the cartography). Spec: `docs/specs/spec-outils-federalistes.md` v0.2.
- **Internationalization at 10 locales at strict parity** — `pt-BR` (reference) + `fr, es, en, it, de, ca, eo, nl, el`, all wired and lazy-loaded, key parity enforced by CI. Inclusive language charter **v2** (2026-06-05) covering all 10 locales (v1 deprecated).
- **Documentation reorganized** — `docs/decisions/` renamed to `docs/journal/` (typed subfolders), `notes-audit/` moved under `docs/notes-audit/`. Corpora: `docs/governance/` (governance guide translated into 10 languages), `docs/cartographie/`, `docs/schema/` (baseline snapshot), `docs/db/`.

Inherited core work (still in production): Network admin (unanimous co-optation/collective removal), Adoption profiles (4 orthogonal political axes: `catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode`), on-site consultation workflow. Their specs have been revised (see Spec articulation).

The detail of work in progress, debts and priorities lives in the current backlog (`docs/backlogs/`, see `INDEX.md` for the current version) and the specs' `REGISTRE_decisions.md`.

---

## Démarrage rapide / Quick start

### Démarrage rapide (FR)

```
npm install
npm run dev
```

L'application tourne sur http://localhost:5173/. Les variables d'environnement Supabase ont des valeurs par défaut pointant vers le projet de production — pour une connexion à un autre projet, voir Configuration.

> ⚠️ Le dépôt se travaille **exclusivement depuis WSL2** (clone canonique unique `~/anarbib`). Voir Outillage de développement.

Tests rapides :

```
npm test     # vitest run (i18n, helpers, composants)
npx vitest   # mode watch
```

Pour les tests SQL d'acceptation, voir Tests.

Build local (quality gate avant push — le déploiement réel passe par Forgejo Actions) :

```
npm run build
```

### Quick start (EN)

```
npm install
npm run dev
```

The application runs at http://localhost:5173/. Supabase environment variables have default values pointing to the production project — to connect to a different project, see Configuration.

> ⚠️ The repo is worked on **exclusively from WSL2** (single canonical clone `~/anarbib`). See Development tooling.

Quick tests:

```
npm test     # vitest run (i18n, helpers, components)
npx vitest   # watch mode
```

For SQL acceptance tests, see Tests.

Local build (quality gate before push — real deployment goes through Forgejo Actions):

```
npm run build
```

---

## Architecture

### Architecture (FR)

```
anarbib/
├── .claude/                # Commandes et skills pour Claude Code
├── .forgejo/
│   └── workflows/
│       └── ci.yml          # CI/CD Forgejo Actions (jobs app + backend)
├── .githooks/
│   └── pre-commit.ps1      # Garde-fou doctrine SQL (REVOKE, SECURITY DEFINER, RLS, security_invoker)
├── public/
│   ├── manifest.webmanifest # Manifest PWA
│   ├── sw.js                # Service worker
│   ├── img/                 # Icônes (favicon, apple-touch, 192/512, og-image)
│   ├── fonts/               # Polices auto-hébergées (Fira Sans, Bitter…)
│   ├── vendor/              # Assets tiers
│   ├── 404.html / CNAME / .domains  # Routage SPA + custom domain Codeberg Pages
│   └── favicon.ico
├── scripts/                 # apply-patch.ps1, cleanup-specs-corpus.sh, cleanup-docs-corpus.sh…
├── src/
│   ├── components/
│   │   ├── layout/         # PageShell, Topbar, Hero, Footer, ProtectedRoute, Skeleton
│   │   ├── ui/             # Button, Input, Card, Sheet, Pill, StatusBadge, SortHeader, NetworkAdminBadge
│   │   └── forms/          # CountrySelect, PhoneInput, StateSelect, countryData
│   ├── contexts/
│   │   ├── AuthContext.jsx     # État d'authentification Supabase
│   │   └── LibraryContext.jsx  # Bibliothèque active, memberships, rôle effectif, isNetworkAdmin
│   ├── hooks/
│   │   └── useSort.js          # Tri par colonnes
│   ├── i18n/
│   │   ├── index.js            # SUPPORTED_LOCALES + LOADERS (pt-BR statique, 9 autres en lazy)
│   │   └── locales/            # 10 fichiers : ca, de, el, en, eo, es, fr, it, nl, pt-BR (.json)
│   ├── lib/
│   │   ├── supabase.js         # Client Supabase
│   │   ├── theme.js            # Chargement dynamique de thème
│   │   ├── countries.js        # Helper noms de pays (i18n-iso-countries)
│   │   ├── scheduleFormat.js   # Helper formatSchedule pour créneaux consultas
│   │   └── roles.js            # Hiérarchie ROLE_RANK + STAFF_ROLES + effectiveRole
│   ├── pages/
│   │   ├── public/         # Catalogue, fiche livre, fiche auteur, login, signup, accueil fédéraliste
│   │   ├── account/        # Espace lecteur (réservations, prêts, consultas, profil)
│   │   ├── painel/         # Tableau de bord bibliothécaire
│   │   ├── biblioteca/     # Configuration bibliothèque (règlement, équipe, stats)
│   │   ├── catalogacao/    # Catalogage (livres, auteurs, exemplaires, autorités, drafts)
│   │   ├── importacoes/    # Import/export de catalogues partenaires
│   │   └── rede/           # Dashboard réseau inter-bibliothèques + AdminsPanel
│   ├── styles/
│   │   ├── theme-base.css  # Variables CSS de marque
│   │   ├── fonts.css       # Déclarations @font-face (polices auto-hébergées)
│   │   └── catalog.css     # Grille du catalogue
│   ├── tests/              # Tests Vitest (dont i18n.test.js, parité des 10 locales)
│   ├── App.jsx             # Router + Providers
│   └── main.jsx            # Point d'entrée
│
├── supabase/
│   ├── migrations/         # 57 fichiers (baseline 20260510 + migrations incrémentales jusqu'au 23/06/2026, _TEMPLATE.sql inclus)
│   └── functions/          # 41 Edge Functions Deno (hors _shared/)
│       ├── notify-event/   # Routeur d'événements + handlers de domaine (team.*, network.*, consultas.*…)
│       │   └── _shared/    # domain/, mail/ (layout.ts : renderEmail + actionBox), i18n/ (mail-strings.ts)
│       ├── register/ login/ request-password-reset/  # Inscription / auth / reset mot de passe
│       ├── bn_isbn_lookup/ catalog_metadata_lookup/ fetch-url-metadata/ cover_lookup/  # Catalogage / métadonnées / couvertures
│       ├── authority_lookup/ author_portrait_lookup/ audio_fingerprint_lookup/  # Autorités, portraits d'auteurs, empreinte audio
│       ├── notify-*/        # Notifications lecteur, biblio, réseau, PEB, rapports hebdo, digest réseau
│       ├── probe-partner-catalog/ process-partner-catalog-import/ export-catalog-lote/  # Catalogues partenaires + export
│       ├── export-fonds-bundle/ receive-fonds-bundle/ deposit-fonds-direct/ attach-received-asset/ gc-deposits/  # Échange de fonds inter-biblio
│       ├── oai-pmh-provider/ notify-oai-opening/  # Fournisseur OAI-PMH
│       ├── submit-cartography-entry/ geocode/  # Cartographie réseau + géocodage
│       ├── submit-gazette-contribution/ gazette-monthly-build/ lettre-confirm/ lettre-unsubscribe/  # Gazette fédérée + lettre d'info
│       ├── read-pdf/ read-digital-asset/ read-ill-shared-asset/ revoke-digital-asset/  # Lecture PDF / assets / PEB
│       └── mail-i18n-test/  # Outil de test i18n des mails
│
├── tests/
│   └── sql/                # Tests SQL d'acceptation (paquet19, 24, 25, 26, A, A1…)
│
├── docs/
│   ├── specs/              # Specs de chantiers + INDEX.md, INVENTAIRE.md, REGISTRE_decisions.md
│   ├── journal/            # Journal de décisions (ex-decisions/, sous-dossiers typés)
│   ├── backlogs/           # Backlogs versionnés + archive/ + INDEX.md + ETAT-AVANCEMENT-multisessions.md
│   ├── governance/         # Guide de gouvernance (traduit en 10 langues)
│   ├── cartographie/ db/ schema/ GLB/   # Corpus complémentaires (schéma baseline, cartographie réseau…)
│   ├── notes-audit/        # Charte de langage inclusif (v2) + audits i18n
│   └── legal/              # Documents juridiques (RGPD, licence CC-BY-SA)
│
├── .gitignore             # Ignore .bak.*, create-*.cjs, fix-*.cjs (scripts one-shot)
├── package.json / package-lock.json
├── eslint.config.js / vite.config.js / vitest.config.js
├── restart.sh             # Purge cache Vite + relance dev
├── CLAUDE.md              # Guide de travail des agents (état vérifié du dépôt)
├── LICENSE / LICENSE-docs # AGPL-3.0 (code) / CC-BY-SA-4.0 (docs)
└── README.md             # Ce fichier
```

### Architecture (EN)

The codebase mirrors the structure above. Key directories:

- `src/` — React 19 + Vite 6 frontend (react-router-dom 7, react-intl 7) with React Context for auth and library state, react-intl for i18n across 10 locales, themed UI components.
- `supabase/migrations/` — 57 versioned migration files (baseline `20260510000000_baseline_live` + increments, latest applied 2026-06-23) applied automatically by the Forgejo `backend` job on push to `main`.
- `supabase/functions/` — 41 Deno Edge Functions (transactional mail via `notify-event`; ISBN / metadata / cover / authority / audio-fingerprint lookups; partner-catalog import & export; inter-library fonds exchange; OAI-PMH provider; network cartography + geocoding; federated gazette + newsletter; PDF/asset reads; login / register / password-reset; etc.). `_shared/` is a shared module excluded from deployment.
- `docs/` — Specifications (in French), decision journal (`journal/`), versioned backlogs, governance guide, inclusive-language charter (`notes-audit/`), legal documents.
- `.forgejo/workflows/ci.yml` — Forgejo Actions CI/CD (replaces the former `.woodpecker.yml`).
- `.githooks/pre-commit.ps1` — Doctrinal SQL guardrail (activate with `git config core.hooksPath .githooks`).

---

## Configuration

### Configuration (FR)

**Supabase** — Le projet utilise un fallback hardcodé pointant vers le projet de production dans `src/lib/supabase.js` (`uflwmikiyjfnikiphtcp`). Pour un environnement différent (staging, test) :

```
# .env.local
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

Les clés (`anon`, `service_role`) vivent dans `.env`/`.env.local`, **jamais** dans le code. La project ref n'est pas committée (voir `supabase/config.toml` pour le `verify_jwt` par fonction).

**Domaine et base URL** — Le site est servi sur `app.anarbib.org` (custom domain configuré dans Codeberg Pages, fichiers `public/CNAME` + `public/.domains`). Configuration en place : `vite.config.js` → `base: '/'`, alias `@` → `src/` ; `src/App.jsx` → `<BrowserRouter basename="/">`.

### Configuration (EN)

**Supabase** — The project uses a hardcoded fallback pointing to the production project in `src/lib/supabase.js` (`uflwmikiyjfnikiphtcp`). For a different environment (staging, test):

```
# .env.local
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

Keys (`anon`, `service_role`) live in `.env`/`.env.local`, **never** in code. The project ref is not committed (see `supabase/config.toml` for per-function `verify_jwt`).

**Domain and base URL** — The site is served at `app.anarbib.org` (custom domain configured in Codeberg Pages, files `public/CNAME` + `public/.domains`). In place: `vite.config.js` → `base: '/'`, `@` alias → `src/`; `src/App.jsx` → `<BrowserRouter basename="/">`.

---

## Déploiement / Deployment

### Déploiement (FR)

Le déploiement est automatisé via **Forgejo Actions** sur Codeberg (`.forgejo/workflows/ci.yml`), déclenché sur `push`/`workflow_dispatch` de `main`. Le workflow tourne sur un **runner auto-hébergé** (`anarbib-local`, `forgejo-runner` en service systemd sur le WSL2 du mainteneur) : il ne tourne donc que lorsque la machine est allumée ; hors ligne, les runs **attendent**. Bypass CI : `[CI SKIP]` / `[skip ci]` dans le message de commit.

Deux jobs séquentiels (le découpage est imposé par la limite ~5 min/job des runners) :

- **`app`** : install → **lint bloquant** → **test bloquant** → build Vite → déploiement Codeberg Pages (branche `pages`, commit orphelin force-push).
- **`backend`** (`needs: app`) : déploiement des Edge Functions → `supabase db push --linked --include-all`. Utilise la **CLI Supabase v2.98.1**.

Garde-fous Forgejo : `concurrency: cicd-main` (`cancel-in-progress: false`) **sérialise** les runs sur `main`, et le runner traite **un job à la fois** — deux runs ne s'exécutent jamais en parallèle.

> ⚠️ **Migration depuis Woodpecker (11/06/2026)** : Woodpecker hébergé étant devenu instable (~22 % d'uptime), la CI est passée à Forgejo Actions. Le fichier `.woodpecker.yml` a été retiré.

**Convention pour les migrations SQL** — Toute migration doit être placée dans `supabase/migrations/` avec un nom au format `YYYYMMDDHHMMSS_description.sql`. Le pipeline l'applique automatiquement au push suivant.

> 🛑 **Horodatage à l'heure UTC EXACTE, jamais approximative.** `supabase db push` applique les fichiers par **ordre lexicographique strict** ; un préfixe arrondi ou inventé entre en collision avec une autre migration (surtout en sessions parallèles) → migration sautée, dépendances cassées ou doublon. Procédure : lire l'horloge UTC réelle, vérifier que le préfixe est strictement supérieur au max présent, sinon prendre `max + 1 seconde`.

**Doctrine de création d'objets backend sécurisés** (voir `docs/journal/`) :

- Fonctions : `SECURITY DEFINER` + `SET search_path = public` + `REVOKE EXECUTE FROM PUBLIC` + `GRANT EXECUTE TO authenticated` explicite.
- Tables : `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + GRANT explicites + policies dédiées.
- Vues : `security_invoker = on` (sauf cas exceptionnel documenté).
- Toute migration doit inclure un DO-block de vérification en fin de transaction.

⚠️ **Piège Supabase identifié (17/05/2026)** : `ALTER DEFAULT PRIVILEGES` octroie automatiquement `EXECUTE` à `anon, authenticated, service_role` sur toute nouvelle fonction dans `public`. `REVOKE FROM PUBLIC` seul ne suffit pas. Pour une fonction réellement isolée (cron/postgres uniquement) :

```sql
REVOKE EXECUTE ON FUNCTION public.fn_xxx() FROM PUBLIC, anon, authenticated, service_role;
```

Le hook `.githooks/pre-commit.ps1` enforce la doctrine (à activer : `git config core.hooksPath .githooks`). Bypass légitime : `git commit --no-verify`.

**Secrets Forgejo** (niveau organisation Codeberg) — token d'API Supabase, project ref (`uflwmikiyjfnikiphtcp`), mot de passe de connexion directe Postgres.

**Déploiement des Edge Functions** — Désormais **automatique** via le job `backend` (plus besoin de déploiement manuel systématique). En manuel, depuis le clone WSL :

```
supabase functions deploy notify-event --no-verify-jwt
supabase functions deploy register --no-verify-jwt
```

⚠️ Le MCP Supabase fourni par Anthropic a une limite de taille qui empêche le déploiement de `notify-event` (bundle volumineux, 20+ fichiers). Utiliser exclusivement la CLI — c'est ce que fait la CI.

### Deployment (EN)

Deployment is automated through **Forgejo Actions** on Codeberg (`.forgejo/workflows/ci.yml`), triggered on `push`/`workflow_dispatch` of `main`, running on a **self-hosted runner** (`anarbib-local`, `forgejo-runner` systemd service on the maintainer's WSL2): it only runs while that machine is on; offline, runs **wait**. CI bypass: `[CI SKIP]` / `[skip ci]` in the commit message.

Two sequential jobs (the split is imposed by the ~5 min/job runner limit):

- **`app`**: install → **blocking lint** → **blocking test** → Vite build → Codeberg Pages deploy (`pages` branch, orphan commit force-push).
- **`backend`** (`needs: app`): Edge Functions deploy → `supabase db push --linked --include-all`. Uses **Supabase CLI v2.98.1**.

Forgejo guardrails: `concurrency: cicd-main` (`cancel-in-progress: false`) **serializes** runs on `main`, and the runner processes **one job at a time** — two runs never run in parallel.

> ⚠️ **Migrated from Woodpecker (11/06/2026)**: hosted Woodpecker became unstable (~22% uptime), so CI moved to Forgejo Actions. The `.woodpecker.yml` file was removed.

**SQL migrations convention** — Every migration must be placed in `supabase/migrations/` with a name following `YYYYMMDDHHMMSS_description.sql`. The pipeline applies it automatically on the next push.

> 🛑 **EXACT UTC timestamp, never approximate.** `supabase db push` applies files in **strict lexicographic order**; a rounded or invented prefix collides with another migration (especially across parallel sessions) → skipped migration, broken dependencies or duplicate. Procedure: read the real UTC clock, verify the prefix is strictly greater than the current max, otherwise use `max + 1 second`.

**Secure backend object creation doctrine** (see `docs/journal/`):

- Functions: `SECURITY DEFINER` + `SET search_path = public` + `REVOKE EXECUTE FROM PUBLIC` + explicit `GRANT EXECUTE TO authenticated`.
- Tables: `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + explicit GRANTs + dedicated policies.
- Views: `security_invoker = on` (unless exceptional case documented).
- Every migration must include a verification DO-block at the end of the transaction.

⚠️ **Supabase pitfall (17/05/2026)**: `ALTER DEFAULT PRIVILEGES` automatically grants `EXECUTE` to `anon, authenticated, service_role` on every new function in `public`. `REVOKE FROM PUBLIC` alone is not enough. For a truly isolated function (cron/postgres only):

```sql
REVOKE EXECUTE ON FUNCTION public.fn_xxx() FROM PUBLIC, anon, authenticated, service_role;
```

The `.githooks/pre-commit.ps1` hook enforces the doctrine (activate: `git config core.hooksPath .githooks`). Legitimate bypass: `git commit --no-verify`.

**Forgejo secrets** (Codeberg organization level) — Supabase API token, project ref (`uflwmikiyjfnikiphtcp`), direct Postgres connection password.

**Edge Functions deployment** — Now **automatic** via the `backend` job (no longer a systematic manual step). Manually, from the WSL clone:

```
supabase functions deploy notify-event --no-verify-jwt
supabase functions deploy register --no-verify-jwt
```

⚠️ The Anthropic-provided Supabase MCP has a size limit preventing deployment of `notify-event` (large bundle, 20+ files). Use the CLI exclusively — that is what CI does.

---

## Doctrines internalisées / Internalized doctrines

### Doctrines internalisées (FR)

Ces doctrines ont émergé des chantiers récents et s'appliquent à tout nouveau code. Elles sont consignées dans `docs/journal/`.

**Ordre des UPDATEs en RPC métier (doctrine #141.2.E)** — Quand un RPC modifie plusieurs tables liées par triggers AFTER UPDATE, toujours UPDATE la source de vérité narrative (ex. `workflow_v2.workflow_note`) AVANT la source d'état (ex. `linhas_v2.item_status` qui déclenche les notifications). Sinon le trigger lifecycle voit l'ancienne note.

**Distinction `workflow_note` / `schedule_reply_note`** — Dans `consulta_item_workflow_v2` : `workflow_note` = staff (motif d'action côté biblio), `schedule_reply_note` = lecteur (réponse au créneau proposé). Les deux colonnes sont distinctes ; triggers et handlers doivent propager les deux selon le contexte.

**Traçabilité coordination R8 généralisée** — Toute action initiée par le staff biblio sur un item lecteur génère un mail à `library_commons.coordination_email` en plus du mail au lecteur.

**Proposeur silencieux après 1er vote (admin réseau)** — Le proposeur d'une cooptation est notifié uniquement au 1er vote (signal de démarrage), puis reste silencieux jusqu'au résultat (`voteCount === 1`).

**Mails militants : qui notifier ?** — Principe directeur : notifier celui qui n'a pas initié l'action, pas celui qui agit.

**Contrat `actionBox` (`renderEmail`)** — Le paramètre `actionBox` de `renderEmail` (`_shared/mail/layout.ts`) attend `{ kind: 'action' | 'info', title, ctaUrl, ctaLabel }` — **PAS** `{ kind, label, url }`. Mauvais contrat → bug runtime `Cannot read properties of undefined (reading 'replace')`. Toujours lire `layout.ts` avant de consommer `actionBox`.

**UTF-8 sur Windows PowerShell** — Écriture : `Get-Content -Raw` lit en CP1252 et corrompt l'UTF-8 ; méthode sûre `[System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))` ou scripts Node `.cjs`. Lecture : `Get-Content` peut afficher des mojibakes alors que le fichier est valide ; toujours vérifier avec `ReadAllText` UTF-8 explicite avant de croire à un bug.

**`onAuthStateChange` Supabase** — JAMAIS d'`async`/`await` dans le callback de `supabase.auth.onAuthStateChange` : tout appel API Supabase y provoque un deadlock. Workaround obligatoire :

```js
supabase.auth.onAuthStateChange((event, session) => {
  setTimeout(() => {
    // appels async ici, hors du contexte du callback
  }, 0);
});
```

### Internalized doctrines (EN)

These doctrines emerged from recent work and apply to all new code. They are recorded in `docs/journal/`.

**UPDATE order in business RPCs (doctrine #141.2.E)** — When an RPC modifies multiple tables linked by AFTER UPDATE triggers, always UPDATE the narrative source of truth (e.g. `workflow_v2.workflow_note`) BEFORE the state source (e.g. `linhas_v2.item_status` which triggers notifications). Otherwise the lifecycle trigger sees the old note.

**`workflow_note` / `schedule_reply_note` distinction** — In `consulta_item_workflow_v2`: `workflow_note` = staff (library-side action motive), `schedule_reply_note` = reader (reply to proposed slot). The two columns are distinct; triggers and handlers must propagate both depending on context.

**Generalized R8 coordination traceability** — Any action initiated by library staff on a reader's item generates a mail to `library_commons.coordination_email` in addition to the mail to the reader.

**Silent proposer after first vote (network admin)** — The proposer of a co-optation is notified only on the first vote (start signal), then remains silent until the result (`voteCount === 1`).

**Militant mails: who to notify?** — Guiding principle: notify the one who did not initiate the action, not the one acting.

**`actionBox` contract (`renderEmail`)** — The `actionBox` parameter of `renderEmail` (`_shared/mail/layout.ts`) expects `{ kind: 'action' | 'info', title, ctaUrl, ctaLabel }` — **NOT** `{ kind, label, url }`. Wrong contract → runtime bug `Cannot read properties of undefined (reading 'replace')`. Always read `layout.ts` before consuming `actionBox`.

**UTF-8 on Windows PowerShell** — Writing: `Get-Content -Raw` reads in CP1252 and corrupts UTF-8; safe method `[System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))` or Node `.cjs` scripts. Reading: `Get-Content` can display mojibakes while the file is actually valid; always verify with explicit `ReadAllText` UTF-8 before assuming a bug.

**Supabase `onAuthStateChange`** — NEVER use `async`/`await` inside the `supabase.auth.onAuthStateChange` callback: any Supabase API call there causes a deadlock. Required workaround:

```js
supabase.auth.onAuthStateChange((event, session) => {
  setTimeout(() => {
    // async calls here, outside the callback context
  }, 0);
});
```

---

## Internationalisation / Internationalization

### Internationalisation (FR)

L'application est entièrement multilingue : `src/i18n/locales/` contient **10 fichiers** — `pt-BR` (référence, importée statiquement et fallback) + `fr, es, en, it, de, ca, eo, nl, el` (chargées en lazy via `import()`). Les 10 sont câblées dans `src/i18n/index.js` (`SUPPORTED_LOCALES` + `LOADERS`) et **maintenues en parité stricte de clés** (5493 clés, gardée par la CI). Les Edge Functions de notification mail utilisent le même système via `_shared/i18n/mail-strings.ts`.

**Charte de langage inclusif** — La **source unique** des conventions est `docs/notes-audit/anarbib-charte-langage-inclusif-v2.md` (v2, 2026-06-05, couvre les 10 locales). **La v1 est dépréciée** (conservée pour historique). Le fichier `src/i18n/README-i18n-section.md` est **obsolète** (6 locales, ~1393 clés) : ne plus s'y référer.

> 🔴 **Terme proscrit, testé en CI** : ne JAMAIS employer `camerata`/`camerati` (italien, connotation fasciste). Utiliser `compagn*`. Le test « Italian must never contain camerata/camerati » de `i18n.test.js` fait échouer le build si le terme apparaît.

État et conventions par locale :

| Locale | Convention principale | Statut / source |
|---|---|---|
| `pt-BR` | Référence. Forme triple `(o/a/e)` / `(a/e)` ; `@` proscrit ; reformuler via mot épicène (`pessoas`) plutôt qu'empiler les marques | Charte v2 |
| `fr` | Point médian (`lecteur·rice`, `compas`) | Charte v2 |
| `es` | `e` neutre argentin (`compañere`) ; articles `le`/`les` ; jamais `x` ni `@` | Charte v2 |
| `en` | Termes épicènes par défaut, singular `they` | Charte v2 |
| `it` | **Astérisque** sur paires régulières en `-o`/`-a` (`compagn*`, `attiv*`, `bibliotecari*`) ; **slash abrégé** sur paires irrégulières `-tore`/`-trice` (`lettore/trice`) ; jamais `camerata`/`camerati` | Charte v2 |
| `de` | Genderstern (`Genoss*in`) — astérisque ASCII ; umlauts conservés ; jamais `Compas` non traduit | Charte v2 |
| `ca` | Terminaison triple `lector-a-e` + article neutre `le` ; géminée `l·l` = graphie standard (non inclusive) | Charte v2 |
| `eo` | Infixe `-in-` par tirets (`legant-in-o`, `aŭtor-in-o`, `uzant-in-o`) + pronom neutre `ri` | Charte v2 |
| `nl` | **Provisoire** : formes de rôle neutres (`lezer`, `bibliothecaris`…), éviter `-ster`/`-e` quand une forme neutre existe, `hen`/`hun` pour le non-binaire. **À valider en communauté.** | Provisoire |
| `el` | **Convention inclusive à définir** avec une personne locutrice grecque militante (pas de standard typographique consensuel). **Ne pas proposer de marqueur d'office.** | À définir |

> Les **clés** des 10 locales sont en parité stricte (gardée par la CI). Les **conventions** `nl` (provisoire) et `el` (à définir) restent à arrêter avec des relais natifs — ce que le test de parité ne vérifie pas.

**Workflow d'ajout de clé** — (1) `t({ id: 'ma.cle' })` dans le code (jamais de chaîne en dur) ; (2) définir la clé dans `pt-BR.json` ; (3) traduire dans **toutes** les autres locales selon la charte ; (4) `npm test` (test i18n bloquant en CI).

**Mails multilingues** — Les Edge Functions utilisent `tMail(locale, key, params)` (lit `_shared/i18n/mail-strings.ts`). Locale résolue : mails lecteur depuis `profile.preferred_language`, mails biblio depuis `libraries.default_locale`. Fallback systématique vers `pt-BR`.

Modèle de prompt pour traduction par IA :

```
Tu traduis pour AnarBib (SIGB de bibliothèques anarchistes).
Convention de langage inclusif obligatoire pour [LANGUE] : voir
docs/notes-audit/anarbib-charte-langage-inclusif-v2.md.
Ne jamais utiliser : camerata/camerati (italien, fasciste),
Kamerad/en non traduit (allemand, fasciste), formes bureaucratiques
/a ou (a) seul (espagnol et portugais).
Privilégier les formes épicènes quand elles existent.

Texte à traduire : [...]
```

### Internationalization (EN)

The application is fully multilingual: `src/i18n/locales/` contains **10 files** — `pt-BR` (reference, statically imported and fallback) + `fr, es, en, it, de, ca, eo, nl, el` (lazy-loaded via `import()`). All 10 are wired in `src/i18n/index.js` (`SUPPORTED_LOCALES` + `LOADERS`) and **kept at strict key parity** (5493 keys, enforced by CI). Mail notification Edge Functions use the same system via `_shared/i18n/mail-strings.ts`.

**Inclusive language charter** — The **single source** of conventions is `docs/notes-audit/anarbib-charte-langage-inclusif-v2.md` (v2, 2026-06-05, covering all 10 locales). **v1 is deprecated** (kept for history). The file `src/i18n/README-i18n-section.md` is **obsolete** (6 locales, ~1393 keys): do not rely on it.

> 🔴 **Banned term, tested in CI**: NEVER use `camerata`/`camerati` (Italian, fascist-coded). Use `compagn*`. The "Italian must never contain camerata/camerati" test in `i18n.test.js` fails the build if the term appears.

See the table above for per-locale conventions (charter v2). Keys for all 10 locales are at strict parity (CI-enforced); the `nl` (draft) and `el` (to be defined) **conventions** still need to be settled with native contributors — which the parity test does not check.

**Key addition workflow** — (1) `t({ id: 'my.key' })` in code (never hardcoded); (2) define the key in `pt-BR.json`; (3) translate to **all** other locales per the charter; (4) `npm test` (blocking i18n test in CI).

**Multilingual emails** — Edge Functions use `tMail(locale, key, params)` (reads `_shared/i18n/mail-strings.ts`). Locale resolution: reader mails from `profile.preferred_language`, library mails from `libraries.default_locale`. Systematic fallback to `pt-BR`.

---

## Tests

### Tests (FR)

**Tests JavaScript** (`src/tests/`, Vitest) :

```
npm test     # vitest run
npx vitest   # mode watch
```

Couverture : i18n (cohérence, charte, couverture code ↔ locales, parité des 10 locales, garde anti-`camerata`), helpers, composants critiques. Le test i18n est **bloquant en CI**. Pas encore de tests end-to-end automatisés (au backlog).

**Tests SQL** — Les tests SQL d'acceptation sont dans `tests/sql/` et lancés manuellement depuis le SQL Editor Supabase. Architecture : un seul bloc `DO $$` avec accumulateurs, qui raise une EXCEPTION finale avec le bilan (`BILAN OK : N/N tests passes`).

Lancement : ouvrir `https://supabase.com/dashboard/project/uflwmikiyjfnikiphtcp/sql/new`, coller le contenu du fichier, cliquer Run. Voir `tests/sql/README.md` pour les fixtures (UUIDs des comptes test) et conventions.

Actuellement disponibles : `paquet19_loan_wrappers_tests.sql`, `paquet24_consulta_helpers_tests.sql`, `paquet25_consulta_wrappers_tests.sql`, `paquet26_consulta_notification_triggers_tests.sql`, `paquetA_profils_tests.sql`, `paquetA1_cancel_note_required_tests.sql`, `cleanup-frt-2026-05-15.sql`.

**QA manuelle** — Plans de test manuels structurés à dérouler en prod pour identifier les bugs concrets et planifier des chantiers de hardening (voir `docs/journal/`).

**Protocole de test RLS PostgREST simulé** — Pour tester les policies RLS dans le SQL Editor, toujours combiner `SET LOCAL ROLE` avec `SET LOCAL "request.jwt.claims"`. Sans le `SET ROLE`, Postgres tourne en `postgres` (BYPASSRLS). Sans le `SET JWT`, le contexte est infidèle.

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

### Tests (EN)

**JavaScript tests** (`src/tests/`, Vitest):

```
npm test     # vitest run
npx vitest   # watch mode
```

Coverage: i18n (consistency, charter, code ↔ locales coverage, 10-locale parity, anti-`camerata` guard), helpers, critical components. The i18n test is **blocking in CI**. No automated end-to-end tests yet (in backlog).

**SQL tests** — SQL acceptance tests live in `tests/sql/` and are run manually from the Supabase SQL Editor. Architecture: a single `DO $$` block with accumulators, raising a final EXCEPTION with the summary (`BILAN OK: N/N tests passed`).

Running: open `https://supabase.com/dashboard/project/uflwmikiyjfnikiphtcp/sql/new`, paste the file content, click Run. See `tests/sql/README.md` for fixtures (test account UUIDs) and conventions.

Currently available: `paquet19_loan_wrappers_tests.sql`, `paquet24_consulta_helpers_tests.sql`, `paquet25_consulta_wrappers_tests.sql`, `paquet26_consulta_notification_triggers_tests.sql`, `paquetA_profils_tests.sql`, `paquetA1_cancel_note_required_tests.sql`, `cleanup-frt-2026-05-15.sql`.

**Manual QA** — Structured manual test plans to run in production to find concrete bugs and plan hardening work (see `docs/journal/`).

**Simulated PostgREST RLS testing protocol** — To test RLS policies in the SQL Editor, always combine `SET LOCAL ROLE` with `SET LOCAL "request.jwt.claims"`. Without `SET ROLE`, Postgres runs as `postgres` (BYPASSRLS). Without `SET JWT`, the context is unfaithful (see SQL block above).

---

## PWA / Progressive Web App

### PWA (FR)

L'application est installable (socle MOBILE Paquet 0) :

- `public/manifest.webmanifest` — manifest PWA (nom, icônes, theme-color `#b32025`, display).
- `public/sw.js` — service worker.
- `index.html` — `<link rel="manifest">`, balises iOS (`apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`, `apple-mobile-web-app-title`) et Android (`mobile-web-app-capable`), jeu d'icônes (`favicon-32`, `icon-192`, `icon-512`, `apple-touch-icon`).
- Métadonnées Open Graph / Twitter Card pour les aperçus de lien (WhatsApp, Signal, Telegram, Mastodon…).
- Optimisations : `preconnect`/`dns-prefetch` vers Supabase, `preload` des 2 polices critiques (Fira Sans, Bitter, auto-hébergées).

### PWA (EN)

The app is installable (MOBILE Package 0 foundation): `public/manifest.webmanifest`, service worker `public/sw.js`, and the relevant `<link rel="manifest">` / iOS / Android meta + icon set in `index.html`. Open Graph / Twitter Card metadata power link previews; `preconnect`/`dns-prefetch` to Supabase and `preload` of the two critical self-hosted fonts (Fira Sans, Bitter) improve first paint.

---

## Système de thèmes / Theming system

### Système de thèmes (FR)

Le thème de chaque bibliothèque est un manifest JSON stocké dans Supabase Storage (`library-ui-assets/themes/{slug}/manifest.json`). Il contrôle couleurs, polices, images de fond et layout via des variables CSS. Le hook `useTheme(slug)` (`src/lib/theme.js`) charge le manifest au runtime et injecte les variables CSS. Fallback automatique vers le thème `default` en cas d'erreur.

### Theming system (EN)

Each library's theme is a JSON manifest stored in Supabase Storage (`library-ui-assets/themes/{slug}/manifest.json`). It controls colors, fonts, background images and layout via CSS variables. The `useTheme(slug)` hook (`src/lib/theme.js`) loads the manifest at runtime and injects CSS variables. Automatic fallback to the `default` theme on error.

---

## Noms de pays / Country names

### Noms de pays (FR)

Les noms de pays sont localisés dynamiquement via `i18n-iso-countries` plutôt que stockés dans les fichiers locale (qui auraient nécessité ~1500 entrées par langue). Le helper `src/lib/countries.js` centralise l'enregistrement des locales :

- `getCountryName(input, locale)` — accepte un code ISO 3166-1 (`'BR'`) ou un nom textuel (`'Brasil'`, `'France'`, `'E.U.A.'`)
- `getCountryNames(locale)` — retourne le map complet
- `intlToIsoLocale(intlLocale)` — convertit `'pt-BR'` → `'pt'`

Tout composant qui affiche un nom de pays doit utiliser ces helpers.

### Country names (EN)

Country names are dynamically localized via `i18n-iso-countries` rather than stored in locale files (which would have required ~1500 entries per language). The `src/lib/countries.js` helper centralizes locale registration: `getCountryName(input, locale)` (accepts an ISO 3166-1 code or a textual name), `getCountryNames(locale)` (full map), `intlToIsoLocale(intlLocale)` (`'pt-BR'` → `'pt'`). Any component displaying a country name must use these helpers.

---

## Outillage de développement / Development tooling

### Outillage de développement (FR)

> 🐧 **RÈGLE D'OR — toutes les sessions travaillent EXCLUSIVEMENT sous WSL2.** Clone canonique unique : `~/anarbib` (WSL2). Lui seul fait tourner `npm run dev` (localhost:5173) et pousse vers Codeberg. **Le clone Windows a été supprimé — ne jamais le recréer** : une session lancée côté Windows recrée un clone fantôme désynchronisé (cause racine de l'incident du 12/06/2026). Lancer Claude depuis WSL : `cd ~/anarbib && claude`.

**Stack** — React 19, react-dom 19, react-router-dom 7, react-intl 7, Vite 6. Dépendances notables : `@supabase/supabase-js ^2.49`, `i18n-iso-countries`, `jspdf` (génération PDF), `jszip`, `qrcode`, `@marsidev/react-turnstile` (captcha Cloudflare Turnstile), `react-markdown`, `react-phone-number-input`. Dev : ESLint 9 (flat config), Vitest 4, jsdom, `@testing-library/react`, `gh-pages`.

**Supabase CLI** — Version utilisée par la CI : **v2.98.1**. Installation locale via gestionnaire de paquets. Commandes courantes :

```
supabase db push --linked                       # applique les migrations
supabase functions download <name>              # télécharge une Edge Function
supabase functions deploy <name> --no-verify-jwt # déploie une Edge Function
```

**Workflow migrations** ⚠️ Conventions critiques (apprises sur incidents) :

- NE PAS coller de SQL dans le SQL Editor avant push (risque `relation already exists`).
- NE PAS utiliser `apply_migration` via le MCP Supabase (timestamp = moment de l'appel, mismatch avec le fichier local → pipeline planté).
- Workflow propre : fichier dans `supabase/migrations/` avec horodatage **UTC exact** → push → laisser Forgejo Actions appliquer.
- Si bug : `git mv` au timestamp réel ou `migration repair --status applied` (non-destructif).

**Scripts du dépôt** — `scripts/apply-patch.ps1` (applique un patch frontend complet : copie `.jsx` + merge de clés locale UTF-8 sans BOM + build + commit + push + `npm run deploy`) ; `scripts/cleanup-specs-corpus.sh` / `cleanup-docs-corpus.sh` (nettoyage de corpus) ; `restart.sh` (purge cache Vite + relance dev). ⚠️ `apply-patch.ps1` fait `npm run deploy` en plus du push → doublon possible avec le déploiement Pages de Forgejo.

**Scripts one-shot** — Les sessions de dev génèrent souvent des `.cjs` éphémères pour patcher des migrations ; ils sont ignorés par git (`create-*.cjs`, `fix-*.cjs`). À supprimer manuellement après usage.

**Signature de session** — Plusieurs sessions travaillent en parallèle : chaque commit porte un trailer `Session: <nom>` (en plus de `Co-Authored-By`), et les fichiers à en-tête (migrations SQL, scripts) portent une ligne `Session : <nom>`. Cela permet `git log --grep='Session: …'` et `git blame` pour remonter à la session d'origine.

> ⚠️ **Jamais deux push concurrents.** Avant tout `git push` : `git fetch`, vérifier que le local n'est pas en retard sur `origin/main`, s'assurer qu'aucune autre session ne pousse, et **attendre la fin du run Forgejo précédent** avant d'enchaîner. Filets Forgejo (`concurrency: cicd-main`, runner mono-job) sérialisent les runs, mais n'empêchent pas une collision d'horodatage de migration.

### Development tooling (EN)

> 🐧 **GOLDEN RULE — all sessions work EXCLUSIVELY under WSL2.** Single canonical clone: `~/anarbib` (WSL2). It alone runs `npm run dev` (localhost:5173) and pushes to Codeberg. **The Windows clone was deleted — never recreate it**: a Windows-side session recreates a desynchronized phantom clone (root cause of the 12/06/2026 incident). Launch Claude from WSL: `cd ~/anarbib && claude`.

**Stack** — React 19, react-dom 19, react-router-dom 7, react-intl 7, Vite 6. Notable deps: `@supabase/supabase-js ^2.49`, `i18n-iso-countries`, `jspdf`, `jszip`, `qrcode`, `@marsidev/react-turnstile` (Cloudflare Turnstile), `react-markdown`, `react-phone-number-input`. Dev: ESLint 9 (flat config), Vitest 4, jsdom, `@testing-library/react`, `gh-pages`.

**Supabase CLI** — Version used by CI: **v2.98.1**. Common commands: `supabase db push --linked`, `supabase functions download <name>`, `supabase functions deploy <name> --no-verify-jwt`.

**Migration workflow** ⚠️ Critical conventions (learned from incidents): do not paste SQL into the SQL Editor before push (`relation already exists` risk); do not use `apply_migration` via the Supabase MCP (timestamp = call moment, mismatch → broken pipeline); clean workflow = file in `supabase/migrations/` with **exact UTC** timestamp → push → let Forgejo Actions apply; if buggy, `git mv` to the real timestamp or `migration repair --status applied` (non-destructive).

**Repo scripts** — `scripts/apply-patch.ps1` (full frontend patch in one command), `scripts/cleanup-*.sh` (corpus cleanup), `restart.sh` (Vite cache purge + dev restart). ⚠️ `apply-patch.ps1` also runs `npm run deploy` → possible duplicate with Forgejo's Pages deploy.

**Session signature** — Multiple sessions work in parallel: each commit carries a `Session: <name>` trailer (plus `Co-Authored-By`), and header files (SQL migrations, scripts) carry a `Session: <name>` line — enabling `git log --grep` / `git blame` to trace the originating session.

> ⚠️ **Never two concurrent pushes.** Before any `git push`: `git fetch`, verify local is not behind `origin/main`, ensure no other session is pushing, and **wait for the previous Forgejo run to finish** before chaining. Forgejo safety nets (`concurrency: cicd-main`, single-job runner) serialize runs but do not prevent a migration timestamp collision.

---

## Backlog et historique / Backlog and history

### Backlog et historique (FR)

**Backlog actuel** — version courante **v33** (`docs/backlogs/`, voir `INDEX.md` qui pointe le fichier exact). Convention de scoring = importance politique (1-10) + urgence technique (1-10). `docs/backlogs/INDEX.md` pointe la version courante ; `docs/backlogs/ETAT-AVANCEMENT-multisessions.md` suit l'avancement multi-sessions.

> 📦 **RÈGLE — archiver l'obsolète.** Une seule version courante à la racine de `docs/backlogs/`. Toute nouvelle version rend la précédente obsolète → la déplacer aussitôt dans `docs/backlogs/archive/` (`git mv`) et tenir `INDEX.md` à jour. Quand on solde une spec ou modifie un module ayant des conséquences sur le backlog, on émet **aussitôt** une nouvelle version datée annotant les items touchés (✅ / partiel + renvoi au commit) — pas de livraison silencieuse.

**Notes de décisions** — Les décisions importantes vivent dans `docs/journal/` (anciennement `docs/decisions/`, réorganisé en sous-dossiers typés) : doctrines durables, comptes rendus de session, bugs avec diagnostic, passations inter-sessions. Le `REGISTRE_decisions.md` des specs consigne les décisions transverses.

### Backlog and history (EN)

**Current backlog** — current version **v33** (`docs/backlogs/`, see `INDEX.md` which points to the exact file). Scoring = political importance (1-10) + technical urgency (1-10). `docs/backlogs/INDEX.md` points to the current version; `docs/backlogs/ETAT-AVANCEMENT-multisessions.md` tracks multi-session progress.

> 📦 **RULE — archive the obsolete.** Only one current version at the root of `docs/backlogs/`. Every new version makes the previous one obsolete → move it to `docs/backlogs/archive/` (`git mv`) and keep `INDEX.md` up to date. When closing a spec or changing a module with backlog consequences, immediately issue a new dated version annotating the affected items (✅ / partial + commit reference) — no silent delivery.

**Decision notes** — Important decisions live in `docs/journal/` (formerly `docs/decisions/`, reorganized into typed subfolders): durable doctrines, session reports, diagnosed bugs, inter-session handoffs. The specs' `REGISTRE_decisions.md` records cross-cutting decisions.

---

## Articulation des specs / Spec articulation

### Articulation des specs (FR)

Les specs vivent dans `docs/specs/`, avec `INDEX.md` (hiérarchie de référence), `INVENTAIRE.md` (état prod vérifié) et `REGISTRE_decisions.md`. Principales specs structurantes (versions courantes) :

- `spec-administrateur-reseau-v0.4.md` — Admin réseau (implémenté en prod).
- `spec-profils-bibliotheque-v0_7.md` — Profils d'adoption (4 axes politiques).
- `spec-flux-consultations-v2.2.md` — Consultations sur place (intègre doctrines #141 + R8).
- `spec-onboarding-biblioteca-v2.0.md` — Onboarding bibliothèque.
- `spec-onboarding-criar-conta.md` — Onboarding lectrice (3 cas à l'inscription).
- `spec-outils-federalistes.md` v0.2 — Outils fédéralistes (Communs, Entraide, Annuaire, cartographie, gouvernance des autorités).
- `spec-gouvernance-roles.md` — Gouvernance & rôles.

Chantiers complémentaires couverts par des specs dédiées : autorités (atelier-autorites, notice-autorite-enrichie, autorites-notes-bio-multilingues, sources-externes-autorites), PEB / partage numérique (cycle-vie-peb, flux-partage-numerique, partenariat-biblios), flux d'emprunts/réservations/renouvellements (flux-emprunts, workflow-reservation(-v2-negotiation), renouvellement-granulaire, notify-prorrogacao-granulaire), catalogue de découverte, cartographie réseau, acquisition/provenance, OAI provider, granularité d'item, refactor v3 sémantique.

> En cas de contradiction, se référer à `docs/specs/INDEX.md` (hiérarchie de référence). Les chantiers à venir commencent par mettre à jour les specs périmées avant d'attaquer le code.

### Spec articulation (EN)

Specs live in `docs/specs/`, with `INDEX.md` (reference hierarchy), `INVENTAIRE.md` (verified prod state) and `REGISTRE_decisions.md`. Main structuring specs (current versions): `spec-administrateur-reseau-v0.4.md`, `spec-profils-bibliotheque-v0_7.md`, `spec-flux-consultations-v2.2.md`, `spec-onboarding-biblioteca-v2.0.md`, `spec-onboarding-criar-conta.md`, `spec-outils-federalistes.md` v0.2, `spec-gouvernance-roles.md`.

Additional work is covered by dedicated specs: authority records, ILL / digital sharing, loan/reservation/renewal flows, discovery catalogue, network cartography, acquisition/provenance, OAI provider, item granularity, semantic v3 refactor. In case of contradiction, refer to `docs/specs/INDEX.md`. Upcoming work starts by updating obsolete specs before tackling code.

---

## Licence / License

### Licence (FR)

AnarBib est un logiciel libre développé pour la communauté des bibliothèques libertaires mondiales (FICEDL, RebAL, etc.). Le projet utilise deux licences libres distinctes :

- **Code source** : GNU Affero General Public License v3.0 (AGPL-3.0) — copyleft fort adapté au logiciel serveur. Toute personne déployant une version modifiée (en SaaS ou autrement) est tenue de publier ses modifications sous la même licence. Fichier : `LICENSE`.
- **Documentation** (notamment `docs/legal/`) : Creative Commons Attribution-ShareAlike 4.0 International (CC-BY-SA-4.0). Fichier : `LICENSE-docs`.

Les bibliothèques adhérentes sont explicitement encouragées à forker, adapter, traduire et republier le code et la documentation pour leur propre contexte, à condition de redistribuer leurs adaptations sous les mêmes licences.

### License (EN)

AnarBib is free software developed for the worldwide community of libertarian libraries (FICEDL, RebAL, etc.). It uses two distinct free licenses:

- **Source code**: GNU Affero General Public License v3.0 (AGPL-3.0) — strong copyleft for server-side software. Anyone deploying a modified version (SaaS or otherwise) must publish their modifications under the same license. File: `LICENSE`.
- **Documentation** (notably `docs/legal/`): Creative Commons Attribution-ShareAlike 4.0 International (CC-BY-SA-4.0). File: `LICENSE-docs`.

Member libraries are explicitly encouraged to fork, adapt, translate, and republish both code and documentation for their own context, provided adaptations are redistributed under the same licenses.

---

## Contribuer / Contributing

### Contribuer (FR)

Le projet est porté par un collectif restreint mais accueille les contributions ponctuelles ou régulières. Pour contribuer :

1. Fork sur Codeberg : https://codeberg.org/anarbib/anarbib
2. Travailler **depuis WSL2** (voir Outillage de développement).
3. Lire la charte de langage inclusif (`docs/notes-audit/anarbib-charte-langage-inclusif-v2.md`) avant tout travail i18n.
4. Lire les doctrines actives dans `docs/journal/` avant tout travail SQL/DB.
5. Branche dédiée par chantier, commits clairs (`feat:`, `fix:`, `docs:`, `chore:`) avec trailer `Session: <nom>`.
6. PR vers `main` avec description du périmètre.

Pour discuter d'un chantier important avant de coder, ouvrir une issue sur Codeberg ou contacter le mainteneur principal via le repo.

### Contributing (EN)

The project is carried by a small collective but welcomes occasional or regular contributions. To contribute: fork on Codeberg, work **from WSL2**, read the inclusive language charter (`docs/notes-audit/anarbib-charte-langage-inclusif-v2.md`) before any i18n work, read active doctrines in `docs/journal/` before any SQL/DB work, use a dedicated branch per work item with clear commits (`feat:`, `fix:`, `docs:`, `chore:`) and a `Session: <name>` trailer, and open a PR to `main` describing the scope. To discuss significant work before coding, open an issue on Codeberg or contact the main maintainer via the repo.

---

Dernière mise à jour / Last updated : 24 juin 2026 / 24 June 2026 — modèle Œuvre/Éditions (FRBR-léger), support des médias audio, cartographie réseau + géocodage, gazette fédérée + lettre d'info, échange de fonds inter-bibliothèques, fournisseur OAI-PMH, cycle de vie des adhésions lecteur, conformité RGPD ; backend porté à 41 Edge Functions, migrations appliquées jusqu'au 23/06/2026. / Work/Editions model (light FRBR), audio media support, network cartography + geocoding, federated gazette + newsletter, inter-library fonds exchange, OAI-PMH provider, reader membership lifecycle, GDPR compliance; backend now 41 Edge Functions, migrations applied through 2026-06-23.
