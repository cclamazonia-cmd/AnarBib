---
description: Commit d'une MIGRATION Supabase. PAS de [CI SKIP]. Horodatage strictement superieur au max du dossier. S'arrete avant le push.
---
Tu vas committer une MIGRATION Supabase.

Etapes :
1. Determine le MAX des horodatages (prefixe YYYYMMDDHHMMSS) deja presents dans supabase/migrations/.
2. Verifie que le nouveau fichier a un horodatage STRICTEMENT SUPERIEUR a ce max.
   - Si oui : ne touche pas au nom.
   - Si non : renomme-le (Move-Item) vers un horodatage strictement superieur au max.
     REGLE : nouveau = le PLUS GRAND entre (date-heure courante) et (max du dossier + 1 seconde).
     NE PAS rehorodater vers l'heure courante si celle-ci est INFERIEURE au max -- piege classique :
     certaines migrations anterieures ont parfois un horodatage "dans le futur".
3. Lance `git status --short supabase/migrations/` et montre-le-moi. Il ne doit y avoir QUE le(s)
   nouveau(x) fichier(s) de migration en `??`. Si autre chose apparait, ARRETE et signale-le-moi.
4. `git add supabase/migrations/`.
5. Commit avec un message Conventional Commits (`fix(...)` ou `feat(...)`), en ASCII pur (PAS d'accents),
   et SANS `[CI SKIP]` : Woodpecker DOIT tourner pour appliquer la migration (`supabase db push --linked`).
   Description fournie par moi : $ARGUMENTS
6. NE POUSSE PAS. Rappelle-moi que le push declenchera Woodpecker, qui appliquera la migration en
   production. Affiche la commande `git push` exacte, puis attends que je la lance moi-meme.
