# CLAUDE.md — AnarBib

> Guide de travail pour les agents (Claude Code) sur ce dépôt.
> **Tout ce qui suit a été vérifié dans le dépôt.** Les rares incertitudes
> résiduelles sont marquées « À CONFIRMER ».

## Présentation

AnarBib est un **SIGB (système intégré de gestion de bibliothèques) pour
bibliothèques anarchistes**. Frontend React 19 + Vite, backend Supabase
(Postgres + Edge Functions Deno). Application multilingue en production.

- Repo principal : `https://codeberg.org/anarbib/anarbib` (**source de vérité**)
- Miroir : `https://github.com/cclamazonia-cmd/AnarBib`
- `package.json` : nom `anarbib`, `version 0.1.0`, `private`, `type: module`
- Structure `src/` réelle : `components/`, `contexts/`, `hooks/`, `i18n/`,
  `lib/`, `pages/`, `styles/`, `tests/`.

### Licences (contenu des fichiers vérifié)

- **`LICENSE`** = **GNU Affero General Public License v3** (AGPL-3.0) → code source.
- **`LICENSE-docs`** = **Creative Commons Attribution-ShareAlike 4.0
  International** (CC-BY-SA-4.0) → documentation.

## Stack & déploiement

- **Frontend** : React 19, react-dom 19, react-router-dom 7, react-intl 7,
  Vite 6. Dépendances notables : `@supabase/supabase-js ^2.49`,
  `i18n-iso-countries`, `jspdf`, `jszip`, `qrcode`, `@marsidev/react-turnstile`,
  `react-markdown`, `react-phone-number-input`.
- **Outils dev** : ESLint 9 (flat config), Vitest 4, jsdom,
  `@testing-library/react`, `gh-pages`.
- **CI/CD** : Woodpecker CI sur Codeberg (`.woodpecker.yml`), déclenché sur
  `push`/`manual` de `main`. Pipeline : install → **lint (bloquant)** →
  **test (bloquant)** → build Vite → deploy Codeberg Pages (branche `pages`,
  commit orphelin force-push) → miroir GitHub (force-push) → deploy Edge
  Functions → deploy migrations SQL.
- Bypass CI : `[CI SKIP]` dans le message de commit.
- CI utilise la **CLI Supabase v2.98.1** (téléchargée dans le pipeline).
- `vite.config.js` : `base: '/'`, alias `@` → `src/`, `pdfjs-dist` exclu de
  l'optimizeDeps, `manualChunks` (react/supabase/i18n/phone vendors).

## Commandes essentielles (réelles, depuis `package.json`)

| Commande | Effet réel |
|---|---|
| `npm run dev` | `vite` (serveur de dev) |
| `npm run build` | `vite build` |
| `npm run preview` | `vite preview` |
| `npm test` | `vitest run` |
| `npm run lint` | `eslint .` |
| `npm run deploy` | `vite build && gh-pages -d dist -r https://codeberg.org/anarbib/anarbib.git -b pages --dotfiles` |
| `npm run deploy:github-mirror` | `vite build && gh-pages -d dist` |

`restart.sh` (bash) : purge `node_modules/.vite` puis `npx vite --force`.

> ⚠️ En usage normal le déploiement passe par **Woodpecker** (push sur `main`).
> Les scripts `npm run deploy*` sont des déploiements manuels alternatifs.

## Workflow Git (état réel vérifié)

**Remotes** (`git remote -v`) :

```
codeberg  https://codeberg.org/anarbib/anarbib.git        (fetch + push)
origin    https://github.com/cclamazonia-cmd/AnarBib.git  (fetch)
origin    https://github.com/cclamazonia-cmd/AnarBib.git  (push)
origin    https://codeberg.org/anarbib/anarbib.git        (push)
```

- `origin` **fetch depuis GitHub**, mais a **deux URLs de push** (GitHub *et*
  Codeberg). La branche `main` suit `origin/main` → un simple `git push` (sur
  `main`) pousse vers les deux URLs de `origin`.
- Codeberg = source de vérité (déclenche Woodpecker) ; GitHub = miroir
  (force-pushé par la CI → tout commit fait directement sur GitHub est écrasé).

**Alias** (`git config --get-regexp ^alias\.`) — un seul :

```
alias.publish-app = !git push codeberg main && git push origin main
```

**Connectivité réelle constatée** (`git ls-remote --heads`, lecture seule) :

- `codeberg` : **répond** — `main` + branche `pages`. `main` synchronisé avec le
  HEAD local au moment du contrôle.
- `origin` (GitHub) : **répond** — `main` + branche `gh-pages`. `main`
  synchronisé avec le HEAD local au moment du contrôle.
- ⚠️ Côté pages déployées, les deux remotes diffèrent : Codeberg = branche
  `pages`, GitHub = branche `gh-pages`.
- Le README signale que l'auth Codeberg via Windows Credential Manager peut
  casser périodiquement — au moment du contrôle, aucun problème.

**Convention de commits** (historique + README) : Conventional Commits —
`feat(scope):`, `fix:`, `docs:`, `chore:`, `i18n …`.

## i18n

### Liste EXACTE des locales présentes

`src/i18n/locales/` contient **10 fichiers** (vérifié) :

```
ca.json  de.json  el.json  en.json  eo.json
es.json  fr.json  it.json  nl.json  pt-BR.json
```

Les **10** sont câblées dans `src/i18n/index.js` (`SUPPORTED_LOCALES` +
`LOADERS`). `pt-BR` = locale par défaut (importée statiquement, fallback) ; les
9 autres sont chargées en lazy via `import()`. **Les 10 locales sont maintenues
en parité de clés.**

Compter les clés par locale (au lieu de figer un nombre) :

```bash
node -e "const fs=require('fs');for(const f of fs.readdirSync('src/i18n/locales')){console.log(f, Object.keys(JSON.parse(fs.readFileSync('src/i18n/locales/'+f))).length)}"
```

### Source unique des conventions

**`notes-audit/anarbib-charte-langage-inclusif-v1.md` est la SOURCE UNIQUE des
conventions de langage inclusif.** En cas de doute, c'est elle qui fait foi.

> ⚠️ **`src/i18n/README-i18n-section.md` est OBSOLÈTE/DÉPRÉCIÉ** (indique 6
> locales, slash pour l'italien, ~1393 clés). **Ne plus s'y référer.**

### Règle dure — terme proscrit

**Ne JAMAIS employer « camerata » / « camerati »** (italien, connotation
fasciste). Utiliser `compagn*` et ses variantes. Cette proscription est
**testée en CI** : `i18n.test.js` (test « Italian must never contain
camerata/camerati ») fait échouer le build si le terme apparaît.

### Conventions par locale

| Locale | Convention | Statut / source |
|---|---|---|
| `pt-BR` | Référence. Forme triple `(o/a/e)` / `(a/e)` ; `@` proscrit | Charte |
| `fr` | Point médian `·` (`lecteur·rice`) | Charte |
| `es` | `e` neutre argentin ; articles `le`/`les` ; jamais `x` ni `@` | Charte |
| `en` | Termes épicènes par défaut, singular `they` | Charte |
| `it` | **Astérisque final** sur paires régulières en `-o`/`-a` (`compagn*`, `attiv*`, `militant*`), cohérent avec le Genderstern allemand ; jamais `camerata`/`camerati` | Officiel |
| `de` | Genderstern `*` ASCII (`Genoss*in`) ; jamais `Compas` non traduit | Charte |
| `ca` | Terminaison triple `lector-a-e` | Documentée au README, **à reverser dans la charte v2** |
| `eo` | Suffixe (`legant-in-e`, `aŭtor-in-o`, `uzant-in-e`) | Documentée au README, **à reverser dans la charte v2** |
| `nl` | **Provisoire** : privilégier les formes de rôle neutres (`lezer`, `bibliothecaris`…), éviter les suffixes genrés `-ster`/`-e` quand une forme neutre existe, `hen`/`hun` pour le non-binaire. **À valider en communauté.** | Provisoire, non arrêtée |
| `el` | **Convention inclusive à définir** avec une personne locutrice grecque militante (pas de standard typographique consensuel en grec). **Ne pas proposer de marqueur d'office.** | À définir |

### Workflow d'ajout de clé

1. `t({ id: 'ma.cle' })` dans le code (jamais de chaîne en dur).
2. Définir la clé dans `pt-BR.json`.
3. Traduire dans **toutes** les autres locales selon la charte.
4. `npm test` (test i18n bloquant en CI).

> ⚠️ **Piège vérifié** : `src/tests/i18n.test.js` n'importe que **8 locales**
> (`pt-BR, fr, en, de, it, es, ca, eo`). Il **ne teste ni `nl` ni `el`** : leur
> parité de clés et leur conformité ne sont **pas** garanties par le gate CI.

## Backend Supabase

- `supabase/config.toml` : fixe `verify_jwt` par fonction. **La project ref
  n'est pas dans le dépôt** → voir config locale ; les clés (`anon`,
  `service_role`) vivent dans `.env`/`.env.local`, **jamais** dans le code.
- **18 Edge Functions** (sous-dossiers de `supabase/functions/`, hors `_shared/`) :
  `bn_isbn_lookup`, `catalog_metadata_lookup`, `fetch-url-metadata`, `login`,
  `mail-i18n-test`, `notify-document-permission-request`, `notify-event`,
  `notify-interlibrary-loan`, `notify-internal-task`, `notify-library-request`,
  `notify-mid-loan-reading`, `notify-network-weekly-report`,
  `notify-weekly-report`, `probe-partner-catalog`,
  `process-partner-catalog-import`, `read-digital-asset`, `read-pdf`, `register`.
  `_shared/` = module partagé (exclu du déploiement).
- **193 migrations** `.sql` dans `supabase/migrations/`, format
  `YYYYMMDDHHMMSS_nom.sql`, + `_TEMPLATE.sql` (doctrine création d'objets
  sécurisés).
- Déploiement functions **et** migrations : **automatique par Woodpecker** au
  push sur `main` (`supabase functions deploy` / `supabase db push --linked
  --include-all`).
- Tests SQL d'acceptation : `tests/sql/*.sql` (lancés manuellement). Présents :
  `paquet19_loan_wrappers_tests`, `paquet24_consulta_helpers_tests`,
  `paquet25_consulta_wrappers_tests`,
  `paquet26_consulta_notification_triggers_tests`,
  `paquetA1_cancel_note_required_tests`, `paquetA_profils_tests`,
  `cleanup-frt-2026-05-15` (+ `README.md`).

## Conventions de code

- **ESLint flat config** (`eslint.config.js`) : `@eslint/js` recommended +
  `eslint-plugin-react` + `eslint-plugin-react-hooks`. Règles notables :
  `react/prop-types` off, `react/react-in-jsx-scope` off, `no-unused-vars` warn
  (ignore préfixe `^_`), `no-undef` error, `react-hooks/exhaustive-deps` warn.
  **Ignorés** : `dist`, `node_modules`, `public`, `supabase/functions`,
  `scripts`, `docs`, `notes-audit`, `*.config.js`, `i18n.test.js`.
- **Pas de `.editorconfig`** ni de config Prettier dans le dépôt (vérifié
  absent). Indentation 2 espaces observée dans les configs JS. *(Note :
  `scripts/apply-patch.ps1` réécrit les locales en 2 espaces « Prettier default »
  mais Prettier n'est pas une dépendance.)*
- ESM partout (`type: module`). Alias d'import `@` → `src/`.
- Edge Functions en TypeScript/Deno.

## Scripts du dépôt (.ps1 / .sh)

- `scripts/apply-patch.ps1` : applique un patch frontend complet en une commande
  (copie `.jsx` + merge de clés locale tri alphabétique en UTF-8 sans BOM +
  `npm run build` + `git add/commit` + `git push origin` + `npm run deploy`).
  Options `-SkipBuild`, `-SkipDeploy`, `-DryRun`. Snapshot rollback dans `%TEMP%`.
- `.githooks/pre-commit.ps1` : garde-fou doctrine SQL. Bloque les `.sql` stagés
  contenant `SECURITY DEFINER` sans `SET search_path`, sans `REVOKE EXECUTE FROM
  PUBLIC`, `CREATE TABLE public.*` sans RLS / sans GRANT, `CREATE VIEW` sans
  `security_invoker = true`. Bypass : `git commit --no-verify`. **À activer
  manuellement** : `git config core.hooksPath .githooks`.
- `restart.sh` : purge cache Vite + relance dev.
- `scripts/cleanup-specs-corpus.sh`, `scripts/cleanup-docs-corpus.sh` : nettoyage
  de corpus (specs / `docs/`).

## Pièges connus / backlog

1. **`it.json` non conforme à la convention astérisque** : il contient des
   **formes fléchies** (ex. `lettrice`). De plus, les **paires irrégulières**
   type `lettore`/`lettrice` **ne se réduisent pas proprement à un astérisque**
   (`lettor*` ne couvre pas la racine `lettric-`). → **Définir le traitement de
   ces paires irrégulières + prévoir un audit d'alignement de `it.json`** sur la
   convention `compagn*`.
2. **`nl` et `el` non couverts par le test i18n** → parité/conformité non
   garanties par la CI (voir section i18n). Conventions encore provisoires
   (`nl`) ou à définir (`el`).
3. **Backlog i18n** : ajouter `nl` et `el` à `src/tests/i18n.test.js` pour que le
   gate CI garantisse la parité des **10** locales (gap identifié au point 2).
4. **Documentation des locales en retard sur le code** : 10 locales en prod ;
   charte v1 = 6 ; `ca`/`eo` à reverser en charte v2 ; `nl`/`el` à arrêter.
5. **`README-i18n-section.md` obsolète** : ne pas s'y fier (voir i18n).
6. **Hook pre-commit non actif par défaut** : nécessite
   `git config core.hooksPath .githooks`.
7. **Miroir GitHub force-pushé par la CI** : tout commit poussé directement sur
   GitHub est écrasé au prochain push Codeberg→main.
8. **MCP Supabase limité en taille** : ne peut pas déployer `notify-event`
   (bundle volumineux). Utiliser la CLI (c'est ce que fait la CI).
9. **`apply-patch.ps1` fait `npm run deploy`** en plus du push : doublon possible
   avec le déploiement Pages de Woodpecker.
10. Doctrines internalisées documentées dans `README.md` / `docs/decisions/`
    (à respecter) : ordre des UPDATE en RPC, distinction
    `workflow_note`/`schedule_reply_note`, pas d'`async` dans
    `supabase.auth.onAuthStateChange`, pièges UTF-8 sous PowerShell Windows,
    contrat `actionBox` de `renderEmail`.
