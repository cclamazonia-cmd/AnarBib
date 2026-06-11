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
- **CI/CD** : **Forgejo Actions** (natif Codeberg, fichier
  `.forgejo/workflows/ci.yml`), déclenché sur `push`/`workflow_dispatch` de `main`.
  **Migré depuis Woodpecker le 11/06/2026** (Woodpecker hébergé devenu instable,
  ~22 % d'uptime). **Deux jobs** (la limite ~5 min/job des runners mutualisés
  imposait le découpage) : **`app`** (install → **lint bloquant** → **test
  bloquant** → build Vite → deploy Codeberg Pages, branche `pages`, commit
  orphelin force-push) puis **`backend`** (`needs: app` → edge functions →
  `supabase db push`). Le **miroir GitHub n'est plus une étape CI** : il est tenu
  à jour par le **dual-push `origin`** (cf. Workflow Git).
- **Runner : `anarbib-local` — AUTO-HÉBERGÉ** (`forgejo-runner` sur le WSL2 de
  Xavier, service systemd, depuis le 11/06). Tourne quand sa machine est allumée
  (seul dev) ; hors ligne → les runs **attendent**. Runbook :
  `docs/journal/operations/SETUP_runner_wsl2_2026-06-11.md`.
- Bypass CI : `[CI SKIP]` / `[skip ci]` dans le message de commit.
- CI utilise la **CLI Supabase v2.98.1** (téléchargée dans le job `backend`).
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

> ⚠️ En usage normal le déploiement passe par **Forgejo Actions** (push sur `main`).
> Les scripts `npm run deploy*` sont des déploiements manuels alternatifs.

## Workflow Git (état réel vérifié)

> 🥇 **RÈGLE D'OR — jamais deux push concurrents.** **Avant** tout `git push`,
> vérifier qu'**aucun autre push n'est déjà en cours** (autre session/agent, ou
> run Forgejo pas encore terminé). Deux push concurrents sur `main` =
> collisions (rebase forcé, horodatages de migration qui s'entrechoquent,
> pipeline rouge — cf. la règle d'horodatage exact et le piège des sessions
> parallèles). Procédure **avant de pousser** : (1) `git fetch` et vérifier que
> le local n'est **pas en retard** sur `origin/main`/`codeberg main` (sinon
> intégrer d'abord) ; (2) s'assurer qu'aucune autre session n'est en train de
> committer/pousser (chips spawnés, agents parallèles) ; (3) ne lancer le push
> que la voie libre. Un push lancé « à l'aveugle » pendant qu'un autre tourne
> est un incident, pas un détail.
>
> 🔁 **Corollaire — sérialiser ses PROPRES push consécutifs.** La règle vaut
> aussi pour soi-même : ne **jamais** enchaîner un second `git push` tant que le
> run Forgejo du push précédent n'est **pas terminé** (vert). Cas typique :
> pousser une **migration** puis enchaîner aussitôt un push **frontend** « par
> dessus » → deux pipelines concurrents, deux `supabase db push` qui se
> chevauchent. Procédure : push migration → **attendre la fin du pipeline**
> (vert) → push suivant. Si plusieurs lots sont prêts en même temps, les pousser
> **un par un**, chaque fois run précédent terminé.
>
> *(Filets de sécurité Forgejo : le workflow porte `concurrency: cicd-main`
> [`cancel-in-progress: false`] qui **sérialise** les runs sur `main`, et le runner
> auto-hébergé traite **un job à la fois** — donc deux runs ne s'exécutent pas en
> parallèle. Mais la discipline `git fetch`-avant-push + horodatage exact reste
> requise : ces filets n'empêchent pas une collision d'horodatage de migration.)*

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
- Codeberg = source de vérité (déclenche Forgejo Actions) ; GitHub = miroir
  tenu à jour par le **dual-push `origin`** (un `git push origin main` pousse vers
  les deux URLs). ⚠️ Le miroir n'est **plus une étape CI** (retirée le 11/06 ;
  Codeberg bloque par ailleurs les miroirs natifs) → un commit poussé **uniquement**
  sur `codeberg` (sans `origin`) laisse GitHub **en retard**. Pousser via `origin`
  (ou l'alias `publish-app`).

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

> 🪪 **Signature de session (traçabilité multi-sessions).** Plusieurs sessions
> Claude travaillent **en parallèle** sur ce dépôt (cf. règle d'or sur les push).
> Pour identifier sans ambiguïté quelle session est à l'origine d'une modif :
> - **Chaque commit** porte un trailer `Session: <nom de session>` **en plus** du
>   `Co-Authored-By`. Ainsi `git log --grep='Session: …'` et `git blame`
>   permettent de remonter à la session d'origine d'une ligne ou d'un fichier.
> - Les **fichiers à en-tête** (migrations SQL, scripts `.ps1`/`.sh`/`.cjs`)
>   portent une ligne `Session : <nom>` dans leur bandeau d'en-tête, à côté de
>   `Auteur`.
> - Le **nom de session** est un titre court et stable, fixé par la coordination
>   (ex. « Catalogação work completion », « Exemplaires & nettoyage catalogue »).
>   En cas de doute sur le nom à employer, demander à la coordination plutôt que
>   d'en inventer un.

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

**`notes-audit/anarbib-charte-langage-inclusif-v2.md` est la SOURCE UNIQUE des
conventions de langage inclusif.** En cas de doute, c'est elle qui fait foi. La
v2 (2026-06-05) couvre les **10 locales** et officialise la convention italienne
(astérisque pour les paires régulières, slash abrégé pour les irrégulières). La
**v1 est dépréciée** et conservée pour l'historique uniquement.

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
| `it` | **Astérisque** sur paires régulières en `-o`/`-a` (`compagn*`, `attiv*`, `bibliotecari*`), cohérent avec le Genderstern allemand ; **slash abrégé** sur paires irrégulières `-tore`/`-trice` (`lettore/trice`, `amministratore/trice`) ; jamais `camerata`/`camerati` | Charte v2 |
| `de` | Genderstern `*` ASCII (`Genoss*in`) ; jamais `Compas` non traduit | Charte |
| `ca` | Terminaison triple `lector-a-e` + article neutre `le` ; géminée `l·l` = graphie standard (non inclusive) | Charte v2 |
| `eo` | Infixe `-in-` par tirets (`legant-in-o`, `aŭtor-in-o`, `uzant-in-o`) + pronom neutre `ri` | Charte v2 |
| `nl` | **Provisoire** : privilégier les formes de rôle neutres (`lezer`, `bibliothecaris`…), éviter les suffixes genrés `-ster`/`-e` quand une forme neutre existe, `hen`/`hun` pour le non-binaire. **À valider en communauté.** | Provisoire, non arrêtée |
| `el` | **Convention inclusive à définir** avec une personne locutrice grecque militante (pas de standard typographique consensuel en grec). **Ne pas proposer de marqueur d'office.** | À définir |

### Workflow d'ajout de clé

1. `t({ id: 'ma.cle' })` dans le code (jamais de chaîne en dur).
2. Définir la clé dans `pt-BR.json`.
3. Traduire dans **toutes** les autres locales selon la charte.
4. `npm test` (test i18n bloquant en CI).

> ✅ **Résolu (05/06/2026)** : `src/tests/i18n.test.js` couvre désormais les
> **10 locales** (`nl` et `el` ajoutés ; les 10 sont à parité exacte, 3286 clés).
> La parité des 10 est gardée par la CI. *(Avant : seules 8 étaient testées —
> `nl`/`el` non gardés.)*

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
  > 🛑 **RÈGLE DURE — horodatage à l'heure EXACTE, jamais approximative.**
  > Le `YYYYMMDDHHMMSS` d'une migration **doit** être l'horodatage **UTC réel**
  > du moment de création, **indexé à la seconde près** — **jamais** un nombre
  > « arrondi », fabriqué ou incrémenté à la louche (pas de `...300000`,
  > `...310000` choisis de tête). Un horodatage approximatif **entre en
  > collision** avec une autre migration (notamment quand plusieurs sessions
  > travaillent en parallèle) : `supabase db push` applique les fichiers par
  > **ordre lexicographique strict**, deux préfixes identiques ou mal ordonnés
  > → migration **sautée, dépendances cassées, ou doublon appliqué**. Procédure
  > obligatoire **avant** de nommer le fichier : (1) lire l'horloge UTC exacte ;
  > (2) lister le dossier et vérifier que le préfixe choisi est **strictement
  > supérieur** au max présent ; (3) si l'heure réelle est ≤ au max (sessions
  > concurrentes), prendre `max + 1 seconde`, pas un saut arbitraire. Une
  > collision d'horodatage est un incident, pas un détail.
- Déploiement functions **et** migrations : **automatique par Forgejo Actions**
  (job `backend`) au push sur `main` (`supabase functions deploy` / `supabase db
  push --linked --include-all`).
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
2. **`nl` et `el` : parité de clés désormais gardée par la CI** (ajoutés au
   test le 05/06/2026, point 3 ci-dessous ✅). Reste que leurs **conventions
   inclusives** sont encore provisoires (`nl`) ou à définir (`el`) — ce que le
   test de parité ne vérifie pas (il garde les clés, pas la conformité charte).
3. ✅ **Fait (05/06/2026)** : `nl` et `el` ajoutés à `src/tests/i18n.test.js` —
   le gate CI garantit la parité des **10** locales (3286 clés chacune).
4. **Documentation des locales** : charte v2 (2026-06-05) couvre les 10 locales
   (`ca`/`eo` reversées, `it` officialisée). Reste à **arrêter `nl`** (provisoire)
   et **`el`** (à définir) avec des relais natifs.
5. **`README-i18n-section.md` obsolète** : ne pas s'y fier (voir i18n).
6. **Hook pre-commit non actif par défaut** : nécessite
   `git config core.hooksPath .githooks`.
7. **Miroir GitHub via dual-push `origin`** (plus d'étape CI depuis le 11/06) :
   pousser via `origin` (ou `publish-app`) garde GitHub synchro ; un push
   `codeberg`-seul le laisse en retard. Un commit fait *directement* sur GitHub
   est écrasé au prochain `git push origin main`.
8. **MCP Supabase limité en taille** : ne peut pas déployer `notify-event`
   (bundle volumineux). Utiliser la CLI (c'est ce que fait la CI).
9. **`apply-patch.ps1` fait `npm run deploy`** en plus du push : doublon possible
   avec le déploiement Pages de Forgejo Actions.
10. Doctrines internalisées documentées dans `README.md` / `docs/journal/`
    (à respecter) : ordre des UPDATE en RPC, distinction
    `workflow_note`/`schedule_reply_note`, pas d'`async` dans
    `supabase.auth.onAuthStateChange`, pièges UTF-8 sous PowerShell Windows,
    contrat `actionBox` de `renderEmail`.
