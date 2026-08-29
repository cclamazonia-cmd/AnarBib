# Runbook — reprise de séance

*28/08/2026. Écrit après une demi-journée perdue sur un diagnostic faux. Trois
gestes avant de mesurer quoi que ce soit, et une règle qui les résume : **on ne
tire aucune conclusion d'un clone qu'on n'a pas rafraîchi**.*

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

## 2 · L'état du dépôt se lit sur `origin/main`, jamais sur le disque

Le clone de travail est un point de vue, pas une source. Ce qui fait foi, c'est
la référence fraîchement récupérée. Un fichier peut traîner sur le disque sans
être suivi, un fichier suivi peut manquer au disque : ni l'un ni l'autre ne dit
quoi que ce soit de ce que porte le dépôt.

## 3 · Le contrôle dépôt ↔ production, dans le bon sens

Il se fait entre `origin/main` et le registre de la base — pas entre le disque
et la base.

```bash
git ls-tree -r --name-only origin/main supabase/migrations \
  | sed -E 's#.*/([0-9]{14}).*#\1#' | grep -E '^[0-9]{14}$' | sort -u > /tmp/depot.txt

# les versions de supabase_migrations.schema_migrations, une par ligne -> /tmp/prod.txt

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
