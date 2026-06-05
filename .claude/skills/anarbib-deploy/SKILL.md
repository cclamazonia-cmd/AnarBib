---
name: anarbib-deploy
description: A appliquer pour TOUTE tache de deploiement / git / CI d'AnarBib -- commit, push, dual-push Codeberg+GitHub, pipeline Woodpecker, Edge Functions, diagnostic d'echec CI. Encode la doctrine de deploiement. REGISTRE_decisions.md reste la source d'autorite.
---

# Doctrine deploiement AnarBib

## Forge et remotes
- **Codeberg** primaire (`codeberg.org/anarbib/anarbib`, CI Woodpecker) ; **GitHub** miroir (`cclamazonia-cmd/AnarBib`).
- `origin` a **deux URLs de push** (dual-push). Alias : `git publish-app`.
- Production : `https://app.anarbib.org/`.

## Le pipeline (push sur main)
lint -> test -> build -> deploy Pages (branche `pages`) -> miroir GitHub -> deploy Edge Functions -> deploy migrations (`supabase db push --linked`).

## Decision [CI SKIP] (par type d'objet)
- **Doc** (.md, specs, backlog) : commit **AVEC** ` [CI SKIP]` (pas besoin du pipeline).
- **Migration** : **SANS** [CI SKIP] (Woodpecker doit l'appliquer).
- **Front** (JSX, i18n, styles) : **SANS** [CI SKIP] (le pipeline build + deploie les Pages) ; `npm run build` en garde-fou AVANT le push.

## Commits
- Messages en **ASCII pur** (pas d'accents -> mojibake PowerShell 5). Conventional Commits.
- `git status --short` (sans filtre) **avant** chaque commit. Nouveaux = `??`, modifies = `M`.
- **Une modification logique par commit.**
- Commiter immediatement quand un paquet est fonctionnel ; ne jamais croire "c'est fait" sans `Get-Item` / `Select-String`.

## Edge Functions
- Deployees par Woodpecker au push. **JAMAIS** `deploy_edge_function` via MCP.
- `notify-event` (>150 Ko) : hors perimetre MCP, CLI `--no-verify-jwt` obligatoire.

## Verifier l'etat reel du remote (independant du navigateur)
`git fetch origin` puis `git log --oneline origin/main -5`.

## Diagnostic d'echec CI
- Message "could not load config from forge: context deadline exceeded" = **panne infra**, jamais un probleme de code. Verifier `status.codeberg.org` avant tout diagnostic.
- Hook pre-commit `.githooks/pre-commit.ps1` : faux positif sur `SECURITY DEFINER` en commentaire -> `--no-verify` documente (#80).

## Windows / PowerShell 5
- Chemins relatifs depuis `anarbib-app` (apostrophe dans `Claude's AnarBib`).
- Sequences operationnelles : blocs-checkpoints un par un, `$ErrorActionPreference='Stop'`, verifier `$LASTEXITCODE`.
- Encodage : ne pas reecrire le contenu via `Get-Content -Raw`/`Set-Content` (CP1252) ; `Move-Item` est sur (ne touche pas au contenu).

## Livraison a Xavier
Rendre les **fichiers complets** (Xavier ne patche pas lui-meme) et donner les sequences git/PS **copiables d'emblee**. Le `git push` reste un geste delibere : preparer le commit, s'arreter, montrer la commande de push.
