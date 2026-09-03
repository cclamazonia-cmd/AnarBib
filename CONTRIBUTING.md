# Contribuer à AnarBib / Contributing to AnarBib

AnarBib est un SIGB libre (AGPLv3) pour bibliothèques libertaires en réseau. Le dépôt qui fait foi est sur **Codeberg** — `https://codeberg.org/anarbib/anarbib`. Le dépôt GitHub en est un miroir : les tickets et les demandes d'intégration se traitent sur Codeberg.

*English version below.*

> **Vous ne comptez pas ecrire de code ?** Cette page parle de `git` et de `npm`. Les trois chantiers les plus utiles au projet aujourd'hui n'en demandent pas : ils sont dans [`AIDER.md`](AIDER.md), avec ce qu'ils demandent, ce qu'ils apportent, et ou ils en sont.

---

## En un mot

**Le projet n'a aujourd'hui qu'un seul mainteneur.** C'est sa fragilité principale, et nous préférons l'écrire que la taire. Toute contribution qui réduit cette dépendance vaut plus qu'une fonctionnalité de plus.

Si vous ne savez pas par où commencer, `docs/CHANTIERS_OUVERTS.md` propose des points d'entrée, du plus court au plus engageant. Le premier ne demande aucune coordination avec qui que ce soit.

---

## Avant de toucher au code

### 1. Lire le REGISTRE

`docs/specs/REGISTRE_decisions.md` est le foyer des décisions transverses. Il fait foi, et il prime sur tout le reste. La règle de préséance du corpus est simple :

> **Font foi** : le REGISTRE, puis la spec courante du domaine, puis le backlog courant.
> **Trace historique, qui n'arbitre pas** : tout ce qui est dans `docs/journal/` — cadrages, chantiers, sessions, bilans, audits.

En cas de contradiction apparente entre deux documents, le REGISTRE tranche. Une spec qui dit « 6 locales » quand le registre en dit 10 est une trace périmée, pas une consigne.

`docs/INDEX.md` est la porte d'entrée du reste de la documentation.

### 2. Selon ce que vous touchez

| Vous touchez à… | Lisez d'abord |
|---|---|
| l'i18n, les libellés, l'interface | `docs/notes-audit/anarbib-charte-langage-inclusif-v2.md` |
| le SQL, la base, les migrations | les doctrines actives dans `docs/journal/` |
| le catalogage, les notices | `docs/guides/guide-conventions-catalografia-*.md` |
| le déploiement, la pile auto-hébergée | `deploy/README.md` puis `deploy/REPETITION.md` |

### 3. Ce qui ne doit jamais entrer au dépôt

`deploy/.env` et `deploy/functions.env` contiennent des secrets et sont ignorés par git. La `SERVICE_ROLE_KEY` n'a sa place ni dans le dépôt, ni dans le front, ni dans un message. Si vous pensez en avoir commis une, dites-le tout de suite : une clé qu'on révoque coûte cinq minutes, une clé qu'on ignore coûte le reste.

### 4. Une dépendance des Edge Functions s'épingle en un seul endroit

`supabase-js` est importé par toutes les fonctions **depuis `supabase/functions/_shared/deps.ts`**, et nulle part ailleurs — jamais `esm.sh/...@2` ni `npm:...@2` dans une fonction. Ce module épingle **une version exacte** ; la monter est un geste daté (changer le nombre, redéployer tout, noter la date). Le banc `src/tests/supabase-js-epingle.test.js` refuse tout import direct. Décision `I16` du 03/09/2026 : un régime mixte — une épinglée, trente flottantes — donne le pire des deux, on l'a payé le 01/09.

---

## Mettre en route

Sous **Linux**, ou sous **WSL2** si vous êtes sur Windows.

```bash
git clone https://codeberg.org/anarbib/anarbib.git
cd anarbib
npm ci          # et non « npm install » : le lock fait foi
npm run dev     # front de développement
npm test        # suite Vitest
npm run lint
```

`npm ci` et pas `npm install <paquet>@latest` : le `package-lock.json` fixe les versions, et les faire dériver silencieusement casse des choses ailleurs.

Pour reconstruire la pile complète — Postgres, PostgREST, authentification, stockage, exécution des fonctions, proxy — voir `deploy/README.md`. **Elle se rebâtit depuis le dépôt seul**, sans aucun secret venu d'ailleurs.

---

## Le rythme du travail

1. **Fork** sur Codeberg, puis une **branche par chantier**.
2. **Commits clairs**, préfixés `feat:` `fix:` `docs:` `chore:`, avec un trailer `Session: <nom>`.
3. **Demande d'intégration vers `main`**, avec le périmètre décrit.
4. Pour un chantier d'ampleur, **ouvrir un ticket avant de coder**. Deux personnes qui écrivent le même correctif, c'est une soirée perdue pour l'une des deux.

**Livrables** : des correctifs complets, éprouvés sur un clone propre, ou des fichiers entiers. Jamais d'instructions « remplacez la ligne 42 par ceci ».

**Production** : aucune migration n'est appliquée sans validation explicite. Le travail se fait en local ou sur une base d'essai.

### Sur les tests

La suite Vitest doit rester verte. Les dix locales sont à **parité stricte de clés**, vérifiée par l'intégration continue : ajouter une clé dans une langue et pas dans les neuf autres fait échouer la construction. C'est voulu.

*Note* : l'intégration continue tourne sur **Forgejo Actions**, avec un exécuteur auto-hébergé sur la machine du mainteneur — rien ne se construit tant qu'elle est éteinte. Si un workflow échoue sans rapport avec votre travail, ce n'est probablement pas vous. *(Woodpecker a été remplacé le 11/06/2026.)*

---

## Sur l'usage de l'IA

AnarBib a été écrit avec l'aide d'un assistant, et le README le dit publiquement. Nous ne cachons ni ne défendons ce choix : nous cherchons à en sortir vers un outillage qui tourne sur nos propres machines. Contribuer avec ou sans assistance ne regarde que vous ; ce qui compte est que vous compreniez et assumiez ce que vous proposez, parce que c'est vous qui répondrez des questions en relecture.

---

## Licences

Le code est sous **AGPLv3** (`LICENSE`). La documentation a sa propre licence (`LICENSE-docs`). En contribuant, vous acceptez que votre travail soit diffusé sous ces termes.

---
---

# Contributing to AnarBib (EN)

> **Not planning to write code?** This page is about `git` and `npm`. The three most useful pieces of work on the project today need neither: see [`AIDER.md`](AIDER.md).

AnarBib is a free-software ILS (AGPLv3) for libertarian libraries working as a network. The canonical repository is on **Codeberg** — `https://codeberg.org/anarbib/anarbib`. The GitHub repository is a mirror; issues and pull requests are handled on Codeberg.

## In short

**The project currently has a single maintainer.** That is its main fragility, and we would rather write it down than hide it. Any contribution that reduces this dependency is worth more than one more feature.

If you don't know where to start, `docs/CHANTIERS_OUVERTS.md` lists entry points, from the shortest to the most demanding. The first one requires no coordination with anyone.

## Before touching the code

**Read the REGISTER first.** `docs/specs/REGISTRE_decisions.md` holds the cross-cutting decisions and overrides everything else. Precedence: the REGISTER, then the current spec for the domain, then the current backlog. Everything under `docs/journal/` is historical record — valuable, but it does not arbitrate. `docs/INDEX.md` is the entry point to the rest.

Then, depending on what you touch: the inclusive-language charter for i18n (`docs/notes-audit/anarbib-charte-langage-inclusif-v2.md`), the active doctrines in `docs/journal/` for SQL and migrations, the cataloguing guides in `docs/guides/`, and `deploy/README.md` for the self-hosted stack.

**Never commit secrets.** `deploy/.env` and `deploy/functions.env` are gitignored. The `SERVICE_ROLE_KEY` belongs neither in the repository, nor in the front end, nor in a message. If you think you committed one, say so immediately.

**One place pins Edge Function dependencies.** Every function imports `supabase-js` from `supabase/functions/_shared/deps.ts` — never `esm.sh/...@2` or `npm:...@2` directly. That module pins an exact version; bumping it is a dated act (change the number, redeploy everything, note the date). `src/tests/supabase-js-epingle.test.js` rejects any direct import (decision `I16`, 2026-09-03).

## Getting started

On **Linux**, or **WSL2** on Windows: `git clone`, then `npm ci` (not `npm install`, the lockfile is authoritative), `npm run dev`, `npm test`, `npm run lint`. To rebuild the full stack, see `deploy/README.md` — it rebuilds from the repository alone, with no secret from anywhere else.

## Working rhythm

Fork on Codeberg, one branch per work item, clear commits prefixed `feat:` `fix:` `docs:` `chore:` with a `Session: <name>` trailer, and a pull request to `main` describing the scope. For anything substantial, open an issue before coding.

Deliverables are complete patches tested on a clean clone, or whole files — never "replace line 42 with this". No migration reaches production without explicit validation.

The Vitest suite must stay green. All ten locales are at **strict key parity**, enforced by CI: adding a key in one language and not the other nine fails the build. That is intentional. CI runs on **Forgejo Actions** with a self-hosted runner on the maintainer's machine — nothing builds while that machine is off. A failure unrelated to your work is probably not yours. *(Woodpecker was replaced on 2026-06-11.)*

## On AI usage

AnarBib was written with assistance, and the README says so publicly. We neither hide nor defend that choice: we are working towards tooling that runs on our own machines. Whether you contribute with or without assistance is your business; what matters is that you understand and stand behind what you propose, because you are the one who will answer questions in review.

## Licences

Code is **AGPLv3** (`LICENSE`); documentation has its own licence (`LICENSE-docs`). By contributing you agree to your work being distributed under those terms.
