# DÉCISION — G2 : l'écart P2/P8 sur la promotion est tranché, le texte s'aligne sur le code

**Date** : 2 septembre 2026, au soir
**Décideur** : Xavier — **en mode dégradé assumé** (voir « Forme de la décision »)
**Objet** : backlog v34, item G2 · REGISTRE `GOUV-18` · spec gouvernance v1.11
**Fenêtre d'objection** : présentée à la **formation du 13 septembre 2026** (coordinations BLMF) ; toute objection y rouvre la question.

---

## Le problème

La migration `20260826120000` est en production depuis le 26 août et applique une
collégialité stricte à la promotion `coordenador·a` : proposition → ratification
par une autre personne du staff → acceptation par l'intéressé·e, quorums
d'endossement, repli à une signature quand il n'y a qu'une coordination,
exclusion de la personne promue du décompte. La BTL exerce ce circuit depuis le
1ᵉʳ septembre.

**Mais la décision politique n'avait jamais été prise**, et les textes la
contredisaient : P8 (« Le SIGB ne modélise pas l'AG ») écrivait *« la spec ne
contient aucun mécanisme de vote, quorum »*, et P2 faisait d'un·e coordenador·a
*« la main qui exécute »* — au singulier.

## Les trois options écrites, et le choix

1. **Ne rien changer au code, aligner les textes** ← **retenue**
2. Étendre le chemin A dans les textes (même réalité, généalogie différente)
3. Rouvrir une promotion directe visible avec délai d'objection (rouvrirait du
   code à dix jours de Bologne, pour un besoin que personne n'a exprimé)

**Motif du choix** : la pratique vivante est la bonne. Le circuit tourne, la BTL
l'a activé, la formation du 13 va l'enseigner — un système où texte et code
disent la même chose s'enseigne ; un écart s'excuse. Et la clarification ne
sacrifie rien de P8 : les quorums du code ne sont **pas des votes**, ce sont des
**garanties d'exécution** — une ratification atteste qu'une décision collective
existe hors logiciel, elle ne la remplace pas. La frontière reformulée : *«
modéliser la délibération, jamais ; exiger plusieurs mains pour exécuter,
toujours. »*

## Forme de la décision — le mode dégradé, dit et daté

Personne ne s'est encore saisi d'AnarBib comme outil de gestion : le « collectif »
qui pourrait trancher, aujourd'hui, c'est une personne. Plutôt que d'habiller ça
en consultation, la décision est prise **seule, en le disant** — c'est la forme
que la spec onboarding donne elle-même au démarrage (auto-confirmation sous le
quorum de 3 admins réseau), et la leçon de `DOC-GEL-1` : une règle tenue par une
personne ne survit que si elle est écrite. D'où cette page, le code `GOUV-18`,
et la **fenêtre d'objection du 13 septembre** : le jour où le collectif existe,
il trouve une décision contestable — pas un état de fait muet.

## Ce qui change

- `docs/specs/spec-gouvernance-roles.md` → **v1.11** : P2 dit que l'exécution
  elle-même est collégiale ; P8 clarifie la frontière. **Aucune ligne de code.**
- REGISTRE v0.15 : `GOUV-18` acté ; `GOUV-17b` bascule à livré au passage (le
  rappel avant péremption est en production depuis le matin, item F8 clos).
- Backlog v34 : G2 clos.
