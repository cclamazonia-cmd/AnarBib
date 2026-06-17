# 📋 INDEX des backlogs — AnarBib

**Dernière mise à jour** : 17 juin 2026 — **v33 promu version courante** (audit de la **longue traîne OPAC** : très largement livrée en prod ; + 5 livrables de session en sandbox hors worktree, à intégrer) ; **v32 archivée**. *(Amendé le 17/06 par la session « Fédération — AG » : §0ter intègre la vague multi-sessions hors OPAC — mobile/fédération/assembleias/thésaurus/gazette livrés — et corrige #FED/#MOBILE ; §32 `AG` au REGISTRE.)* *(Amendé le 17/06 — session « Gazette Rizoma & Lettre » : **#PUBLIB livré en prod** — annuaire/fiche publics + opt-in fin + carte OSM + logos ; reste `PUBLIB-SCHED-1`.)* Le backlog vit en Markdown ; les `.docx` historiques (v8→v29) sont dans `archive/`. Source vivante de l'avancement : [`ETAT-AVANCEMENT-multisessions.md`](ETAT-AVANCEMENT-multisessions.md).
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce dossier contient les versions successives du **backlog technique** d'AnarBib. Une seule version est vivante à la fois ; les précédentes sont conservées dans `archive/` pour la traçabilité.

> **Préséance** : le backlog courant fait foi pour la liste des items et le séquencement, mais **ce qui fait doctrine** est dans [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md). Si une ligne du backlog cite une décision (`HYGIENE-SPECS-0106`, `Option D`…), le registre porte la version normative.

---

## ✅ Version courante

➡️ **`AnarBib-Backlog-2026-06-17-v33.md`**

Backlog **v33** du 17 juin 2026 — reporte le **v32** (12/06). Apporte l'**audit complet de la longue traîne OPAC** (item #14) : la plupart des items que le v32 listait « ouverts » (#OPAC4/6/9/10, #AUT1-4, #61, #58/#62) sont **en fait livrés en prod** (vérifié en lecture seule) ; #14 passe de « partiel avancé » à **quasi complet**. Intègre **5 livrables de session** produits **hors worktree** (sandbox `~/anarbib-traine`, non déployés) : recherche **multi-mots** (1a), **formes du nom** sur la fiche auteur (2), **traduction des 30 sujets ×10 locales**, **enrichissement `variant_forms`** de 9 auteur·rices (Wikidata), et un **brouillon (1b)** recherche accents/pertinence. Le reste OPAC = données (indexation 72 % du public sans sujet, enrichissement ~1-2 %) délégué à Baqueiro. Le **vrai reste ouvert** (§2, après amendement §0ter) : **finitions #MOBILE** (P3 permanence/P5 push), **#MM**, cotisations, sécurité/Bologne, i18n rollout, **suites AG** (P3b/v0.2), **#PUBLIB-SCHED-1** (consolidation horaires). *(#FED, #THES, #GAZ, #ASSEMBLEIAS v0.1→P3, **#PUBLIB** sont **livrés** — cf. §0ter.)*

> **Format.** Depuis le 10/06, le backlog vit en **Markdown** (git-tracké, diffable). Les anciennes versions `.docx` (v8→v29) sont conservées dans `archive/` comme snapshots historiques. Le contenu « à intégrer » des sessions des 05-08/06 (Track A/D, capas, liaison, doublons, clôtures #BIBLIO/#110/#NOTIFY, MULTI/VALID/#CL.10) est **livré et reflété dans le v30** — voir l'audit prod et le REGISTRE pour le détail normatif.

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
