---
name: anarbib-i18n
description: A appliquer pour TOUTE tache i18n d'AnarBib -- ajout ou modification de cles de traduction, libelles, internationalisation de composants, audit de parite, langage inclusif. Encode la doctrine : 10 locales, fichiers plats, parite obligatoire, conventions inclusives par langue, methode d'edition sure. La charte du depot reste la source unique d'autorite.
---

# Doctrine i18n AnarBib

## Locales (10, toujours toutes)
ca, de, el, en, eo, es, fr, it, nl, pt-BR. **pt-BR = locale par defaut** (fallback synchrone).
Toute cle ajoutee ou modifiee DOIT exister dans les 10 locales. Pas d'exception : livrer une cle, c'est la livrer partout.
Fichiers de locale : **plats** (cles type "account.loans.renew"), **LF sans BOM**, **indentation 2 espaces**.

## Source d'autorite (a lire AVANT de produire des libelles inclusifs)
`notes-audit/anarbib-charte-langage-inclusif-v1.md` est la **source unique de verite** pour le langage inclusif.
La lire avant de rediger ou corriger des libelles. Le resume ci-dessous est un aide-memoire, pas l'autorite ;
en cas de doute, la charte tranche.

## Conventions inclusives (aide-memoire)
- **es** : e neutre argentin (le / les / une...).
- **fr** : point median (adherent·e).
- **de** : Genderstern (Genoss*in) + tutoiement.
- **it** : asterisque (compagn*, attiv*). Cas particulier lettore/lettrice : paire irreguliere, traitee a part
  (cf. pipeline #940) -- ne pas asterisquer mecaniquement.
- **pt-BR** : triple forme o / a / e.
- **en** : epicene.
- **ca / eo / nl / el** : suivre la charte / le README i18n. nl en formes neutres (hen/hun), provisoire.
- **REGLE DURE, sans exception** : jamais "camerata" / "camerati".

## Parite et residus
- Verifier la parite des 10 locales : toute cle d'une locale existe dans les 9 autres.
- Detecter le texte en dur non internationalise : `node scan_i18n_residual.js`.
- Note : `i18n.test.js` ne couvre actuellement que 8 locales (nl et el non testees) -- a garder en tete (backlog).

## Methode d'edition (sure)
- **Ajout de cles** : script `.cjs` **additif purement textuel** -- insertion avant le `}` final du fichier,
  **idempotent**. Validation apres : `node -e "JSON.parse(require('fs').readFileSync(path,'utf8'))"`.
- **INTERDIT** : `ConvertFrom-Json` + reserialisation pour patcher du JSON -- ca transforme les `\n` et casse
  le fichier (Vite / JSON.parse strict plante).
- Livraison a Xavier : rendre les **fichiers complets patches**, jamais des instructions a coller
  (Xavier ne patche pas les fichiers lui-meme).

## A ne pas confondre : libelles d'e-mail
Les libelles d'e-mail vivent dans les Edge Functions (`_shared/i18n/mail-strings.ts`, helper `tMail`, 8 locales/cle),
PAS dans les locales React. Ne pas melanger les deux systemes.
