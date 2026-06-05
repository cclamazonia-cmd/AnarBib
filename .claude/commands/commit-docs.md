---
description: Commit d'une modification de DOCUMENTATION (.md, specs, backlog, CLAUDE.md). Ajoute [CI SKIP]. S'arrete avant le push.
---
Tu vas committer une modification de DOCUMENTATION (Markdown, specs, backlog, CLAUDE.md, REGISTRE_decisions).

Etapes :
1. Lance `git status --short` et montre-moi ce qui est stage / non stage.
2. Verifie que les changements sont bien de la doc (pas de code applicatif, pas de migration SQL). Si tu vois du code ou une migration melanges, ARRETE et signale-le-moi.
3. `git add` uniquement les fichiers de doc concernes (demande-moi si c'est ambigu).
4. Commit avec un message Conventional Commits de type `docs:` (ou `docs(scope):`), en ASCII pur (PAS d'accents -> evite le mojibake PowerShell), et AVEC le suffixe ` [CI SKIP]` (la doc n'a pas besoin du pipeline).
   Description fournie par moi : $ARGUMENTS
5. NE POUSSE PAS. Affiche `git diff --stat HEAD~1` et la commande exacte `git push`, puis attends que je la lance moi-meme.
