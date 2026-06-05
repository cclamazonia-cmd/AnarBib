# 📋 INDEX des backlogs — AnarBib

**Dernière mise à jour** : 5 juin 2026 (session tard) — Track D complet + liaison préventive + notes bio UI + gate i18n 10 locales livrés (cf. note ci-dessous, foyer `REGISTRE` §12 `CAT-D5a…d, CAT-G3, CAT-I2`) à **intégrer dans une v27** ; version courante reste **v26** tant que le `.docx` v27 n'est pas promu par le lead. Précédemment : 3 juin 2026 (version courante v26 du 02/06, historique reconstruit v8→v25, note sur le glissement de convention de nommage des archives)
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce dossier contient les versions successives du **backlog technique** d'AnarBib. Une seule version est vivante à la fois ; les précédentes sont conservées dans `archive/` pour la traçabilité.

> **Préséance** : le backlog courant fait foi pour la liste des items et le séquencement, mais **ce qui fait doctrine** est dans [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md). Si une ligne du backlog cite une décision (`HYGIENE-SPECS-0106`, `Option D`…), le registre porte la version normative.

---

## ✅ Version courante

➡️ **`AnarBib-Backlog-2026-06-02-v26.docx`**

Backlog v26 du 2 juin 2026. Cette version s'inscrit dans la dynamique post-**audit de cohérence du corpus du 02/06** (`../decisions/AUDIT_coherence_corpus_2026-06-02.md`) qui a institué le REGISTRE des décisions et la règle de préséance documentaire.

> **À intégrer dans v27 — session du 05/06 (soir).** Livré en prod (foyer normatif : `../specs/REGISTRE_decisions.md` §12 `CAT-E7…E9, CAT-C5, CAT-G1/G2, CAT-H1, CAT-I1`) : **Track A catalogação complet** (Lots 1→6 + 3b) ; **module capas P1/P2/P3** (P3 page-1-PDF côté client) ; **liaison autorités↔œuvres** (matching + outil « Rattacher aux œuvres ») ; **fusion de doublons** autorités **et** documents (`merge_log`/`merge_author`/`merge_book`) ; **flux contributeurs** brouillon→publié + fiche livre complète ; **socle Ateliers** (`author_translations` étendue). 3 specs nouvelles dans `../specs/`.
>
> **À intégrer aussi — session du 05/06 (tard) : le « reste backlog » ci-dessus est désormais LIVRÉ.** Foyer normatif `REGISTRE_decisions.md` §12 : **Track D complet** (`CAT-D5a` réactivation LoC post-FOLIO ; `CAT-D5b` adaptateurs REST Open Library + Wikidata ; `CAT-D5c` BN Brasil fédéré dans « Buscar metadados » ; `CAT-D5d` EF `authority_lookup` + Atelier autorités + seed `variant_forms` au publish) ; **liaison volet préventif** (`CAT-G3` : sélecteur d'autorité par contributeur au form livre, RPC `search_authors_by_name`, `book_draft_contributors.author_id`) ; **notes bio multilingues — UI de revue** (`CAT-I2` : statut draft/reviewed par langue, RPC `set_author_translation_review`, seed bio locale UI au publish). Hors §12 : **gate CI i18n étendu aux 10 locales** (`nl`/`el` ajoutés à `i18n.test.js`) ; règle dure horodatage migrations exact dans `CLAUDE.md`. **Reste backlog** : dédoublonnage des clusters d'autorités restants (Abad de Santillán 24/10036, Cappelletti 10027/10044, Tolstoï 10108/10109 — *traité dans une session dédiée*). *(Le `.docx` v27 reste à produire par le lead — cet INDEX en trace le contenu ; un fichier `AnarBib-Backlog-2026-06-05-v27.docx` existe déjà à la racine mais la version courante listée reste v26 tant que le lead ne l'a pas promu.)*

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

**Cadence d'incrémentation** : v8 → v26 en 13 jours, soit ≈1,4 version/jour. Le rythme s'explique par la pratique « un arbitrage acté ⇒ un incrément » : le backlog porte les décisions courantes (par exemple `HYGIENE-SPECS-0106` ou les choix d'option d'un chantier), qui passent ensuite dans le REGISTRE. La règle « numéro strictement croissant, peu importe la date » est respectée — deux versions le même jour (v20/v21 le 29/05, v23/v24 le 31/05) sont normales.

---

## 🔧 Maintenance

Quand une nouvelle version du backlog est produite :
1. **Déplacer** la version courante actuelle dans `archive/` (en conservant son nom d'origine `AnarBib-Backlog-<date>-<version>`, conforme à la pratique en cours).
2. **Placer** la nouvelle version à la racine de `backlogs/`.
3. **Mettre à jour** cet index (version courante + ligne dans le tableau d'historique).
4. Si l'incrément introduit une **décision normative** (doctrine, arbitrage transverse), inscrire l'ID au [`REGISTRE`](../specs/REGISTRE_decisions.md). Le backlog porte le travail à faire ; le registre porte ce qui fait foi.

**Convention de nommage** : `AnarBib-Backlog-<YYYY-MM-DD>-v<N>.docx`. Numéro strictement croissant — plusieurs versions le même jour sont autorisées et normales si elles tracent des incréments distincts.

---

*Fin de l'index des backlogs. Pour la navigation générale, voir [`../INDEX.md`](../INDEX.md). Pour ce qui fait doctrine, voir [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md).*
