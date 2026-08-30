# 📋 INDEX des backlogs — AnarBib

**Dernière mise à jour** : 29 août 2026 — **v34 promu version courante** ; **v33 archivée**. Le v34 est une **réécriture intégrale sur état vérifié** : chaque affirmation d'état a été relue le 29/08 contre la base de production (lecture seule) et contre le dépôt au commit `1d00ed2c`. Il remplace un v33 dont **216 des 221 migrations appliquées lui étaient postérieures**. Il existe en deux langues et en page consultable, **engendrées** depuis `backlog-v34.json` par `scripts/build-backlog.cjs`. Source vivante de l'avancement : [`ETAT-AVANCEMENT-multisessions.md`](ETAT-AVANCEMENT-multisessions.md) — **périmée sur plusieurs points, cf. §Écarts du v34**.
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce dossier contient les versions successives du **backlog technique** d'AnarBib. Une seule version est vivante à la fois ; les précédentes sont conservées dans `archive/` pour la traçabilité.

> **Préséance** : le backlog courant fait foi pour la liste des items et le séquencement, mais **ce qui fait doctrine** est dans [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md). Si une ligne du backlog cite une décision (`HYGIENE-SPECS-0106`, `Option D`…), le registre porte la version normative.

---

## ✅ Version courante

➡️ **`AnarBib-Backlog-2026-08-29-v34.md`** (français) · **`AnarBib-Backlog-2026-08-29-v34.pt-BR.md`** (portugais) · **`backlog-v34.html`** (page consultable, filtrable)

Backlog **v34**, écrit le 29 août 2026 et **tenu à jour** au fil des clôtures — **réécriture, pas report** (dernière passe le 30/08). Le fichier garde son nom : c'est un permalien, référencé depuis cinq endroits. La date de mise à jour vit dans `meta.maj` du JSON et s'affiche en tête des trois rendus. 90 items sur 11 domaines, chacun avec son état vérifié, ce que c'est, pourquoi ça compte, ce qui compte comme fini, ce que ça demande et ce dont ça dépend. Le document ouvre sur deux choses que le v33 ne pouvait plus donner : une **photo chiffrée** de la base et du dépôt au 29/08, et une table des **écarts entre le réel et l'écrit** — qui vont dans les deux sens. Onze chantiers déclarés ouverts étaient livrés (les 19 migrations `conventions_*`, la collégialité, les périodiques P1→P9, Altcha AR-3/AR-4, les crons dits inactifs…) ; à l'inverse, **62 tables métier n'ont jamais reçu la moindre insertion** — sept blocs fonctionnels entiers sont écrits, déployés, et jamais empruntés. Les cinq items **P0** ne sont pas du code : administrateur·rices réseau, reconstruction éprouvée par un tiers, runner hors du poste du mainteneur, usage réel des circuits, acte de création du fonds. *(A5 — la configuration git à deux URL de poussée — a été retiré des items le 29/08 après lecture de `.git/config` : le correctif était déjà appliqué. Il figure aux clôtures, identifiant conservé. **B1** — les huit tables du schéma `ingest` sans RLS — a été livré et soldé le 29/08 au soir : migration `20260830140000`, suite `ingest_ferme_tests.sql`, hook `pre-commit` étendu. La vérification des droits a corrigé le diagnostic au passage — rien n'était atteignable, le paquet est un second verrou. **A4** — la porte d'entrée pour qui veut aider sans coder — a suivi le même soir : `AIDER.md` à la racine, en trois langues, avec les chiffres du jour. **B3** — les sept vues `api` restées hors des policies — et **J5** — les incohérences du corpus — ont été soldés dans la nuit et versés aux clôtures. **I7** a été réécrit plutôt que clos : la réactivation des six suites SQL oubliées a produit 35 échecs pour quatre causes, dont **une seule tenait au produit** — le reste était le banc d'essai qui ne savait ni simuler un appel anonyme, ni fournir un emprunt, ni dire son succès dans la forme que lit la CI. Deux items neufs en sont sortis, dont l'un a été soldé dans la foulée : **I14** — la sixième règle du hook, qui refuse dans `tests/sql/` tout identifiant d'apparence réelle absent du seed, doctrine `DOC-FIXT-1` — et **I15**, la réécriture des trois suites de circulation d'avant la CI, qui hérite des onze SKIP restants. **La CI est verte de bout en bout sur 45 suites** : I7 et I14 rejoignent les clôtures, qui comptent 27 lignes. Cinq items soldés dans la journée, dont trois qui n'existaient pas le matin. Le 30/08, **B2** a été réécrit sur pièces : les 500 avertissements du Security Advisor sont **deux lints et rien d'autre** — 36 fonctions ouvertes à `anon`, 464 à `authenticated`. Sur les 36, **cinq portent 107 policies RLS** et ne doivent jamais perdre leur `EXECUTE` ; une vingtaine servent des pages publiques réelles ; **trois seulement sont des grants morts**, que leur propre corps refuse déjà. Le tri des 464 est sorti dans un item neuf, **B14**. Une seconde lecture, le même jour, a corrigé le constat sur un point qui le renverse : ces ouvertures ne sont pas des décisions, elles sont le **défaut du schéma `public`** — `ALTER DEFAULT PRIVILEGES … GRANT ALL ON FUNCTIONS TO anon`, hérité du socle Supabase et présent dans le baseline. Toute fonction créée dans `public` naît ouverte à `anon` ; les **141 lignes `REVOKE … anon`** du dépôt sont la trace d'une lutte menée à la main contre une cause jamais retournée. B2 compte désormais quatre lots, dont une décision de doctrine. **Les lots 1 et 2 ont été livrés dans la foulée** — migration `20260830181207`, tests `T8`/`T9` dans `grants_herites_tests.sql`, CI verte, déployé : trois grants que la fonction elle-même contredisait sont retirés, et les cinq fonctions qu'il ne faut jamais fermer portent désormais leur raison en commentaire. Le compteur de l'advisor est passé de **500 à 497** : trois exactement, comme annoncé. B2 passe à *en cours*.)*

> **Format.** Le v34 est **engendré** : la source unique est `backlog-v34.json`, et `node scripts/build-backlog.cjs` produit les deux `.md` et la page HTML. **Ne modifiez pas les `.md` à la main** — ils sont écrasés. Si cette mécanique gêne, elle se jette sans dommage : les `.md` engendrés sont autonomes.

---

## 📦 Historique (dossier `archive/`)

### Note sur la convention de nommage

L'INDEX du 20/05 prescrivait de renommer les versions archivées avec le préfixe `AnarBib-Backlog-archive-<date>-<version>`. **En pratique, depuis le 20/05, les versions archivées conservent leur nom d'origine** `AnarBib-Backlog-<date>-<version>` sans préfixe `-archive-`. Les deux conventions coexistent donc dans `archive/`. Le **préfixe daté** reste la référence fiable pour identifier une version (la date entre les deux pour la convention ancienne, l'unique date pour la convention récente). Si tu souhaites trancher entre les deux conventions, c'est une décision à acter — en l'absence, le présent index décrit l'état réel.

### Lignée principale (du 13 mai au 2 juin 2026)

| Version | Date | Note |
|---|---|---|
| `AnarBib-Backlog-archive-2026-05-13-v8.docx` | 13/05 | Lignée « v8 historique » (à ne pas confondre avec le v8 du 20/05 qui a fusionné les lignées). Convention `-archive-`. |
| `AnarBib-Backlog-archive-2026-05-14-v10.md` | 14/05 | Lignée session par session, format Markdown. |
| `AnarBib-Backlog-archive-2026-05-14-v11.md` | 14/05 | — |
| `AnarBib-Backlog-archive-2026-05-15-v12.md` | 15/05 | — |
| `AnarBib-Backlog-archive-2026-05-15-v13.md` | 15/05 | — |
| `AnarBib-Backlog-archive-2026-05-15-v14.md` | 15/05 | — |
| `AnarBib-Backlog-archive-2026-05-17-v15.md` | 17/05 | Dernière version de la lignée session par session. |
| `AnarBib-Backlog-archive-2026-05-18-v6.docx` | 18/05 | Lignée « v6 historique » (numérotation 1-81). |
| `BACKLOG_chantiers_H_I_J_issus_reunion_BTL_archive-2026-05-18.md` | 18/05 | Chantiers H/I/J issus de la réunion BTL — intégrés dans le v8 du 20/05. |
| `AnarBib-Backlog-2026-05-20-v8.docx` | 20/05 | Version unifiée fusionnant les lignées. Bascule vers la nouvelle convention. |
| `AnarBib-Backlog-2026-05-20-v8.1.docx` | 20/05 | Correctif mineur du v8. |
| `AnarBib-Backlog-2026-05-21-v9.docx` | 21/05 | — |
| `AnarBib-Backlog-2026-05-21-v10.docx` | 21/05 | — |
| `AnarBib-Backlog-2026-05-21-v11.docx` | 21/05 | — |
| `AnarBib-Backlog-2026-05-22-v12.docx` | 22/05 | — |
| `AnarBib-Backlog-2026-05-22-v13.docx` | 22/05 | — |
| `AnarBib-Backlog-2026-05-22-v14.docx` | 22/05 | — |
| `AnarBib-Backlog-2026-05-23-v15.docx` | 23/05 | Session étape 10 chantier-cadre Biblioteca (EA-11 + EA-20). |
| `AnarBib-Backlog-2026-05-24-v16.docx` | 24/05 | — |
| `AnarBib-Backlog-2026-05-25-v17.docx` | 25/05 | — |
| `AnarBib-Backlog-2026-05-27-v18.docx` | 27/05 | — |
| `AnarBib-Backlog-2026-05-28-v19.docx` | 28/05 | — |
| `AnarBib-Backlog-2026-05-29-v20.docx` | 29/05 | — |
| `AnarBib-Backlog-2026-05-29-v21.docx` | 29/05 | Version actée par `DECISION_arbitrages_backlog_v21_glb_v17_2026-05-29.md`. |
| `AnarBib-Backlog-2026-05-30-v22.docx` | 30/05 | — |
| `AnarBib-Backlog-2026-05-31-v23.docx` | 31/05 | — |
| `AnarBib-Backlog-2026-05-31-v24.docx` | 31/05 | — |
| `AnarBib-Backlog-2026-06-01-v25.docx` | 01/06 | Réinjection du chantier catalogue (cf. `specs/INDEX.md`). |
| `AnarBib-Backlog-2026-06-02-v26.docx` | 02/06 | Institution du REGISTRE des décisions + règle de préséance (audit cohérence corpus 02/06). |
| `AnarBib-Backlog-2026-06-05-v27.docx` | 05/06 | Track A/D catalogação + capas livrés ; FED & Importações cadrés ; passe advisors P1-P4. |
| `AnarBib-Backlog-2026-06-08-v28.docx` | 08/06 | Clôtures #BIBLIO / #110 / #NOTIFY-Painel-acts ; #HYG-rapports-consultas. |
| `AnarBib-Backlog-2026-06-10-v29.docx` | 10/06 | MULTI / VALID / #CL.10 livrés. **Gravement désynchronisé de la prod → remplacé par le v30 (réécriture critique, cf. audit).** |
| `AnarBib-Backlog-2026-06-10-v30.md` | 10/06 | Réécriture critique sur base prod vérifiée (309 migrations, 21 EF). **Reporté au v31 le 11/06** (CI auto-hébergé, notifs §21 PARTNER, baseline schéma). |
| `AnarBib-Backlog-2026-06-11-v31.md` | 11/06 | Report du v30 + livraisons 11/06 (CI auto-hébergé, §21 PARTNER, snapshot schéma). **Reporté au v32 le 12/06** (détection + fusion de doublons en file éditoriale). |
| `AnarBib-Backlog-2026-06-12-v32.md` | 12/06 | Détection et fusion de doublons en file éditoriale. *(Ligne rétablie le 29/08 : elle manquait à ce tableau depuis juin.)* |
| `AnarBib-Backlog-2026-06-17-v33.md` | 17/06 | Audit de la longue traîne OPAC + 5 livrables de session en sandbox. **Remplacé par le v34 le 29/08** — réécriture sur état vérifié, 216 des 221 migrations lui étaient postérieures. |

**Cadence d'incrémentation** : v8 → v26 en 13 jours, soit ≈1,4 version/jour. Le rythme s'explique par la pratique « un arbitrage acté ⇒ un incrément » : le backlog porte les décisions courantes (par exemple `HYGIENE-SPECS-0106` ou les choix d'option d'un chantier), qui passent ensuite dans le REGISTRE. La règle « numéro strictement croissant, peu importe la date » est respectée — deux versions le même jour (v20/v21 le 29/05, v23/v24 le 31/05) sont normales.

---

## 🔧 Maintenance

Quand une nouvelle version du backlog est produite :
1. **Déplacer** la version courante actuelle dans `archive/` (en conservant son nom d'origine `AnarBib-Backlog-<date>-<version>`, conforme à la pratique en cours).
2. **Placer** la nouvelle version à la racine de `backlogs/`.
3. **Mettre à jour** cet index (version courante + ligne dans le tableau d'historique).
4. Si l'incrément introduit une **décision normative** (doctrine, arbitrage transverse), inscrire l'ID au [`REGISTRE`](../specs/REGISTRE_decisions.md). Le backlog porte le travail à faire ; le registre porte ce qui fait foi.

**Convention de nommage** : `AnarBib-Backlog-<YYYY-MM-DD>-v<N>.md` (**Markdown depuis v30** ; `.docx` pour les versions historiques ≤ v29, conservées dans `archive/`). Numéro strictement croissant — plusieurs versions le même jour sont autorisées et normales si elles tracent des incréments distincts.

---

*Fin de l'index des backlogs. Pour la navigation générale, voir [`../INDEX.md`](../INDEX.md). Pour ce qui fait doctrine, voir [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md).*
