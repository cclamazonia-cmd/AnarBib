---
description: Commit d'une modification FRONTEND (JSX, i18n, styles). Garde-fou npm run build. PAS de [CI SKIP]. S'arrete avant le push.
---
Tu vas committer une modification FRONTEND (composants JSX, locales i18n, styles).

Etapes :
1. GARDE-FOU : lance `npm run build`. Si le build echoue, ARRETE immediatement, montre-moi l'erreur, ne commit rien.
2. Si la modif touche l'i18n : verifie la parite des 10 locales (toute cle ajoutee/modifiee existe dans ca, de, el, en, eo, es, fr, it, nl, pt-BR) et le respect de la charte (notes-audit/anarbib-charte-langage-inclusif-v1.md). Signale-moi tout ecart ou cle manquante avant de continuer.
3. Lance `git status --short` et montre-le-moi.
4. `git add` uniquement les fichiers front concernes.
5. Commit avec un message Conventional Commits adapte (`feat(...)`, `fix(...)`, `i18n(...)`, `style(...)`...), en ASCII pur (PAS d'accents), et SANS `[CI SKIP]` : le pipeline build et deploie les Pages.
   Description fournie par moi : $ARGUMENTS
6. NE POUSSE PAS. Affiche `git diff --stat HEAD~1` et la commande `git push` exacte, puis attends que je la lance moi-meme.
