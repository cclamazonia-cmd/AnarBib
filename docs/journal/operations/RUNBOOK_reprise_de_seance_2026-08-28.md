# Runbook — reprise de séance

*28/08/2026. Écrit après une demi-journée perdue sur un diagnostic faux. Trois
gestes avant de mesurer quoi que ce soit, un quatrième si la mesure sort mauvaise,
et une règle qui les résume : **on ne tire aucune conclusion d'un clone qu'on n'a
pas rafraîchi**.*

---

## 1 · `git fetch` — toujours, et en premier

Plusieurs mains poussent sur `main` le même jour : une session locale, une
session Cowork, le runner. Un clone de travail peut être en retard de plusieurs
dizaines de commits sans que rien ne le signale — `git status` ne dit « à jour »
que par rapport à la dernière référence connue, pas par rapport à la forge.

```bash
git fetch https://codeberg.org/anarbib/anarbib.git main
git log --oneline HEAD..FETCH_HEAD          # vide = à jour ; sinon on est en retard
```

L'URL explicite plutôt que `origin` : `origin` porte deux URL de push et une
seule référence de suivi, qui peut être empoisonnée par un push partiel (voir
CLAUDE.md, « le piège du dual-push »).

## 2 · L'état du dépôt se lit sur `FETCH_HEAD`, jamais sur le disque

Le clone de travail est un point de vue, pas une source. Ce qui fait foi, c'est
la référence qu'on vient de récupérer — `FETCH_HEAD` après l'étape 1, et non
`origin/main`, qui est justement la référence que le dual-push peut empoisonner.
Un fichier peut traîner sur le disque sans être suivi, un fichier suivi peut
manquer au disque : ni l'un ni l'autre ne dit quoi que ce soit de ce que porte le
dépôt.

```bash
git ls-tree -r --name-only FETCH_HEAD supabase/migrations   # ce que le dépôt porte
ls supabase/migrations                                       # ce que ce poste porte
```

## 3 · Le contrôle dépôt ↔ production, dans le bon sens

**Se rebaser d'abord.** Le contrôle qui suit compare le disque à la base, et
c'est exactement l'erreur du 28/08 s'il tourne sur un clone en retard :

```bash
git rebase --no-fork-point FETCH_HEAD
```

Ensuite seulement, la comparaison — le CLI la fait de lui-même, en deux
colonnes :

```bash
supabase migration list --linked
```

Une version dans `Remote` sans son `Local`, ou l'inverse, est l'écart cherché.
Si le projet n'est pas lié (`supabase link` non fait, ou pas de réseau), la
version à la main, en collant dans l'éditeur SQL de Supabase :

```sql
select string_agg(version, chr(10) order by version)
  from supabase_migrations.schema_migrations;
```

puis, la sortie enregistrée dans `/tmp/prod.txt` :

```bash
git ls-tree -r --name-only FETCH_HEAD supabase/migrations \
  | sed -E 's#.*/([0-9]{14}).*#\1#' | grep -E '^[0-9]{14}$' | sort -u > /tmp/depot.txt

comm -13 /tmp/depot.txt /tmp/prod.txt   # en production, absente du dépôt
comm -23 /tmp/depot.txt /tmp/prod.txt   # commitée, pas encore déployée
```

- **Premier sens non vide** : quelque chose tourne en production sans exister au
  dépôt. Tant que c'est le cas, on ne dit pas « l'installation se reconstruit
  depuis le dépôt seul » — c'est la phrase la plus forte du dossier, elle ne se
  prête pas.
- **Second sens non vide** : une migration attend son déploiement. C'est le sens
  acceptable des deux.

État constaté le 28/08/2026 : **213 migrations de part et d'autre**, une seule
ligne d'écart et dans le bon sens.

## 4 · Si le mauvais sens n'est pas vide

**D'abord douter du clone, pas du dépôt.** Neuf fois sur dix c'est l'étape 1 qui
a été sautée. Le 28/08, les onze migrations « manquantes » étaient au dépôt
depuis des heures.

```bash
git log --oneline HEAD..FETCH_HEAD          # doit être vide avant d'aller plus loin
```

**Si l'écart tient après ça**, il est réel : une migration a été appliquée
directement sur la base sans qu'un fichier soit écrit. Le registre conserve le
SQL intégral, donc le fichier se reconstitue — et la reconstitution se vérifie
plutôt qu'elle ne se croit :

```sql
select name, array_to_string(statements, chr(59) || chr(10) || chr(10)) as sql,
       length(array_to_string(statements, chr(59) || chr(10) || chr(10))) as taille
  from supabase_migrations.schema_migrations where version = '<version>';
```

Écrire le résultat dans `supabase/migrations/<version>_<name>.sql`, puis
confronter le compte de caractères — `wc -m` doit rendre `taille + 1`, le saut
de ligne final. Tant que ce compte ne tombe pas juste, le fichier n'est pas une
copie de ce qui tourne, c'est une paraphrase.

Deux pièges vus le 28/08 :

- la jointure des instructions ajoute une ligne vide et perd le `;` final du
  `commit` — cosmétique, mais le compte de caractères le voit ;
- un fichier reconstitué **n'est pas rejoué** au déploiement : sa version est
  déjà au registre. Il rattrape le dépôt, il ne touche pas la base.

---

## Ce que cette page a coûté

Le 28/08, le registre de la production a été comparé au **clone local**, en
retard de 26 commits. Conclusion tirée : onze migrations tourneraient en
production sans exister au dépôt, et l'installation ne se reconstruirait plus
depuis le dépôt seul. C'était faux — `origin/main` et la production étaient
identiques.

Deux coûts, très inégaux. Une demi-journée à reconstituer depuis le registre des
fichiers qui existaient déjà : récupérable. Et une phrase fausse, prête à partir
dans un compte rendu à un hébergeur, qui aurait mis en cause la tenue du projet
sur le seul point où elle est vérifiable : ça, non.

**La leçon n'est pas « faire attention »**, c'est que la fraîcheur d'un clone se
vérifie par une commande, pas par un sentiment — et que la commande passe avant
la mesure, pas après.
