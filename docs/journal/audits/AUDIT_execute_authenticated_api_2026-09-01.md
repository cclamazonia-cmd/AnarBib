# Audit — les 138 fonctions `SECURITY DEFINER` de `api` exécutables par `authenticated`

**1er septembre 2026** · base `uflwmikiyjfnikiphtcp` interrogée en lecture seule · item **B14**, première prise
**Critère repris de l'audit du 18/05/2026, ajusté au rôle** : *que peut demander
une inconnue qui s'est simplement inscrite ?* Un compte `authenticated` s'obtient
en trois clics ; il ne prouve l'appartenance à aucune bibliothèque. La forme à
chercher en priorité, celle des cinq failles de mai : **un identifiant en
paramètre, une donnée nominative en retour.**

---

## Méthode, et ce qu'elle ne peut pas voir

Recensement du 01/09 : **138 fonctions** `SECURITY DEFINER` dans `api`
exécutables par `authenticated` (sur 142 — le compte du 30/08 tient).

Le triage mécanique a d'abord menti, et c'est documenté parce que c'est la
leçon `DOC-RECENS-1` : un premier vocabulaire de gardes (`fn_caller_is_*`,
`user_can_act*`, `auth.uid()`…) classait 24 fonctions « sans garde visible ».
Onze d'entre elles étaient gardées par des prédicats que le vocabulaire ne
connaissait pas — `user_can_manage_library`, `fn_is_catalog_coordinator`,
`fn_constitution_guard`. Le vocabulaire a donc été **extrait des corps
eux-mêmes** (regex sur les appels `public.*`/`api.*` des 138 sources) avant de
reclasser :

| Pile | Compte |