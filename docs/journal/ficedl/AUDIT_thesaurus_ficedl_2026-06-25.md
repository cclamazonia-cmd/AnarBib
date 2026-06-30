> ⚠️ **USAGE INTERNE AnarBib — NE PAS DIFFUSER TEL QUEL.**
>
> Outil de travail interne, généré par `scripts/ficedl_thesaurus_scrape.mjs` (2026-06-25).
> Les corrections au thésaurus FICEDL se reversent **à la main, progressivement, dans le
> circuit collectif** souhaité par Claude/CCL (anti-fork) — **jamais en bloc**, jamais
> présenté comme une sortie automatique. Le portugais est déjà très bon ; l'effort utile
> porte surtout sur nl/en/ca/de.

---

# Audit du thésaurus FICEDL — POC harvest + coquilles multilingues

Source : https://thesaurus.ficedl.info (SPIP). Récupération par scraping HTML (aucun export SKOS/RDF/CSV exposé).

## Couverture

- Descripteurs ciblés : **620** — sujets 228, géo 235, dates 158.
- Fiches parsées avec bloc 10 langues : **462**.
- Sans bloc de traduction détecté : 158 (mot515, mot516, mot517, mot518, mot519, mot520, mot521, mot522, mot523, mot524, mot525, mot526…).
- Erreurs réseau : 0.

## Synthèse des anomalies (par type)

| Type | Occurrences |
|---|---|
| eq_fr | 313 |
| el_no_roman | 4 |
| de_no_caps | 3 |
| pt_old_ortho | 3 |
| missing_lang | 3 |
| tag_fixed | 2 |
| english_leak | 1 |
| dup_lang | 1 |
| dup_lang_conflict | 1 |
| el_no_greek | 1 |

## Langues non traduites (libellé = français), segmenté par facette

_Sur **géo** et **dates**, « = fr » est souvent légitime (noms propres : Angola, 1936…). Le signal « non-traduit » à corriger est surtout celui de la colonne **sujets**._

| Langue | sujets (/228) | géo (/235) | dates (/0) | vide |
|---|---|---|---|---|
| fr | 0 | 0 | 0 | 0 |
| ca | 15 | 35 | 0 | 0 |
| de | 15 | 28 | 0 | 0 |
| el | 0 | 1 | 0 | 0 |
| en | 17 | 53 | 0 | 0 |
| eo | 1 | 2 | 0 | 0 |
| es | 1 | 28 | 0 | 0 |
| it | 3 | 28 | 0 | 0 |
| nl | 28 | 34 | 0 | 0 |
| pt | 2 | 22 | 0 | 0 |

### Sujets non traduits (= fr) — détail

- [mot6](https://thesaurus.ficedl.info/spip.php?mot6) « alternative » → recopié en : de, en, it
- [mot8](https://thesaurus.ficedl.info/spip.php?mot8) « anarchisme » → recopié en : nl
- [mot9](https://thesaurus.ficedl.info/spip.php?mot9) « animal » → recopié en : ca, en, pt
- [mot11](https://thesaurus.ficedl.info/spip.php?mot11) « antimilitarisme » → recopié en : ca, nl
- [mot13](https://thesaurus.ficedl.info/spip.php?mot13) « architecture » → recopié en : en
- [mot37](https://thesaurus.ficedl.info/spip.php?mot37) « autonomie » → recopié en : de, nl
- [mot40](https://thesaurus.ficedl.info/spip.php?mot40) « bibliographie » → recopié en : de
- [mot41](https://thesaurus.ficedl.info/spip.php?mot41) « biologie » → recopié en : de, nl
- [mot42](https://thesaurus.ficedl.info/spip.php?mot42) « bureaucratie » → recopié en : nl
- [mot47](https://thesaurus.ficedl.info/spip.php?mot47) « collectivisme » → recopié en : nl
- [mot48](https://thesaurus.ficedl.info/spip.php?mot48) « colonialisme » → recopié en : ca
- [mot49](https://thesaurus.ficedl.info/spip.php?mot49) « communalisme » → recopié en : nl
- [mot55](https://thesaurus.ficedl.info/spip.php?mot55) « communisme » → recopié en : nl
- [mot64](https://thesaurus.ficedl.info/spip.php?mot64) « contestation » → recopié en : en
- [mot68](https://thesaurus.ficedl.info/spip.php?mot68) « corporatisme » → recopié en : nl
- [mot71](https://thesaurus.ficedl.info/spip.php?mot71) « culture » → recopié en : en
- [mot80](https://thesaurus.ficedl.info/spip.php?mot80) « doctrine » → recopié en : en, nl
- [mot153](https://thesaurus.ficedl.info/spip.php?mot153) « individualisme » → recopié en : ca, nl
- [mot157](https://thesaurus.ficedl.info/spip.php?mot157) « internationalisme » → recopié en : nl
- [mot160](https://thesaurus.ficedl.info/spip.php?mot160) « justice » → recopié en : en
- [mot194](https://thesaurus.ficedl.info/spip.php?mot194) « marxisme » → recopié en : ca, nl
- [mot198](https://thesaurus.ficedl.info/spip.php?mot198) « mort » → recopié en : ca
- [mot205](https://thesaurus.ficedl.info/spip.php?mot205) « nationalisme » → recopié en : nl
- [mot206](https://thesaurus.ficedl.info/spip.php?mot206) « nature » → recopié en : en
- [mot207](https://thesaurus.ficedl.info/spip.php?mot207) « naturisme » → recopié en : ca
- [mot209](https://thesaurus.ficedl.info/spip.php?mot209) « nihilisme » → recopié en : ca, nl
- [mot213](https://thesaurus.ficedl.info/spip.php?mot213) « organisation » → recopié en : de
- [mot216](https://thesaurus.ficedl.info/spip.php?mot216) « pacifisme » → recopié en : ca, nl
- [mot220](https://thesaurus.ficedl.info/spip.php?mot220) « patriotisme » → recopié en : ca
- [mot222](https://thesaurus.ficedl.info/spip.php?mot222) « philosophie » → recopié en : de
- [mot224](https://thesaurus.ficedl.info/spip.php?mot224) « police » → recopié en : en
- [mot233](https://thesaurus.ficedl.info/spip.php?mot233) « presse » → recopié en : de
- [mot235](https://thesaurus.ficedl.info/spip.php?mot235) « prison » → recopié en : en
- [mot243](https://thesaurus.ficedl.info/spip.php?mot243) « provo » → recopié en : ca, de, en, eo, es, it, nl, pt
- [mot245](https://thesaurus.ficedl.info/spip.php?mot245) « psychiatrie » → recopié en : de, nl
- [mot246](https://thesaurus.ficedl.info/spip.php?mot246) « psychologie » → recopié en : de, nl
- [mot254](https://thesaurus.ficedl.info/spip.php?mot254) « sabotage » → recopié en : de, en, nl
- [mot257](https://thesaurus.ficedl.info/spip.php?mot257) « science » → recopié en : en
- [mot263](https://thesaurus.ficedl.info/spip.php?mot263) « socialisme » → recopié en : ca, nl
- [mot264](https://thesaurus.ficedl.info/spip.php?mot264) « sociologie » → recopié en : nl
- [mot268](https://thesaurus.ficedl.info/spip.php?mot268) « sport » → recopié en : de, en, it, nl
- [mot269](https://thesaurus.ficedl.info/spip.php?mot269) « squat » → recopié en : en
- [mot271](https://thesaurus.ficedl.info/spip.php?mot271) « syndicalisme » → recopié en : nl
- [mot273](https://thesaurus.ficedl.info/spip.php?mot273) « technologie » → recopié en : de, nl
- [mot275](https://thesaurus.ficedl.info/spip.php?mot275) « terrorisme » → recopié en : ca, nl
- [mot277](https://thesaurus.ficedl.info/spip.php?mot277) « torture » → recopié en : en
- [mot280](https://thesaurus.ficedl.info/spip.php?mot280) « trotskisme » → recopié en : ca, nl
- [mot281](https://thesaurus.ficedl.info/spip.php?mot281) « urbanisme » → recopié en : ca
- [mot282](https://thesaurus.ficedl.info/spip.php?mot282) « utopie » → recopié en : de, nl
- [mot285](https://thesaurus.ficedl.info/spip.php?mot285) « violence » → recopié en : en
- [mot511](https://thesaurus.ficedl.info/spip.php?mot511) « piraterie » → recopié en : de

## Portugais (réponse à la question « pas trop mal traduit ? »)

- Fiches où le **pt = fr** (probable non-traduit) : **24** / 462 (5.2%).
- Fiches en **graphie pré-réforme** (acção, directo, óptimo…) : **3** 
- Fuites d'anglais dans le champ pt : 1.

Graphies pt à revoir :

- [mot51](https://thesaurus.ficedl.info/spip.php?mot51) — « comunicação (aspectos gerais) * » (fr : communication (généralités))
- [mot133](https://thesaurus.ficedl.info/spip.php?mot133) — « guerra (aspectos gerais) » (fr : guerre (généralités))
- [mot181](https://thesaurus.ficedl.info/spip.php?mot181) — « literatura: romances de ficção científica? » (fr : littérature : science-fiction)

## Fuites d'anglais (champ non-EN contenant un mot anglais)

- [mot44](https://thesaurus.ficedl.info/spip.php?mot44) — **pt** : « capitalismo e anti capitalism »

## Allemand non capitalisé (nom commun en minuscule)

- [mot10](https://thesaurus.ficedl.info/spip.php?mot10) — de : « anthropologie und ehtnologie » (fr : anthropologie et ethnologie)
- [mot115](https://thesaurus.ficedl.info/spip.php?mot115) — de : « studenten » (fr : étudiants)
- [mot272](https://thesaurus.ficedl.info/spip.php?mot272) — de : « anarchosyndikalismus » (fr : syndicalisme : anarchosyndicalisme)

## Grec

- Sans écriture grecque : 1 (mot444)
- Sans romanisation : 4

## Normalisations appliquées à l'import (à signaler À LA SOURCE)

_Politique anti-fork : on **range** la donnée (re-route une balise erronée vers la bonne langue, libellé **inchangé**), jamais on ne ré-écrit. Ces points doivent être corrigés à la source par le/la mainteneur·euse — AnarBib ne fait que les contourner en lecture._

- [mot24](https://thesaurus.ficedl.info/spip.php?mot24) « art : courants : surréalisme » — balise `[ne]` → `[nl]` (valeur « kunst: kunststromingen: surrealisme » remise dans la bonne langue, non modifiée)
- [mot75](https://thesaurus.ficedl.info/spip.php?mot75) « désobéissance civile » — balise `[il]` → `[it]` (valeur « disobbedienza civile » remise dans la bonne langue, non modifiée)

## Coquilles structurelles (balises de langue)

_Fiches récupérées par le parseur tolérant : balise mal orthographiée (ex. `[il]`→`[it]`), dupliquée, ou langue absente._

Langues manquantes (balise absente) : fr:0  ca:2  de:0  el:1  en:0  eo:0  es:0  it:0  nl:0  pt:0

- [mot120](https://thesaurus.ficedl.info/spip.php?mot120) (sujets) « fédéralisme » — dup_lang:de
- [mot174](https://thesaurus.ficedl.info/spip.php?mot174) (sujets) « littérature : Mémoires » — missing_lang:ca
- [mot177](https://thesaurus.ficedl.info/spip.php?mot177) (sujets) « littérature : poésie » — dup_lang_conflict:eo · missing_lang:ca
- [mot651](https://thesaurus.ficedl.info/spip.php?mot651) (geo) « Tchéquie (République tchèque) » — missing_lang:el

## 25 fiches les plus problématiques

- [mot243](https://thesaurus.ficedl.info/spip.php?mot243) (sujets) — 8 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:eo · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot462](https://thesaurus.ficedl.info/spip.php?mot462) (geo) — 8 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:eo · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot413](https://thesaurus.ficedl.info/spip.php?mot413) (geo) — 7 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot435](https://thesaurus.ficedl.info/spip.php?mot435) (geo) — 7 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot442](https://thesaurus.ficedl.info/spip.php?mot442) (geo) — 7 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot444](https://thesaurus.ficedl.info/spip.php?mot444) (geo) — 7 drapeaux : eq_fr:ca · eq_fr:el · eq_fr:en · eq_fr:eo · eq_fr:it · eq_fr:pt · el_no_greek:Doukhobors
- [mot463](https://thesaurus.ficedl.info/spip.php?mot463) (geo) — 7 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot499](https://thesaurus.ficedl.info/spip.php?mot499) (geo) — 7 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot502](https://thesaurus.ficedl.info/spip.php?mot502) (geo) — 7 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot503](https://thesaurus.ficedl.info/spip.php?mot503) (geo) — 7 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot319](https://thesaurus.ficedl.info/spip.php?mot319) (geo) — 6 drapeaux : eq_fr:ca · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot376](https://thesaurus.ficedl.info/spip.php?mot376) (geo) — 6 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl
- [mot385](https://thesaurus.ficedl.info/spip.php?mot385) (geo) — 6 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:nl · eq_fr:pt
- [mot386](https://thesaurus.ficedl.info/spip.php?mot386) (geo) — 6 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:nl · eq_fr:pt
- [mot406](https://thesaurus.ficedl.info/spip.php?mot406) (geo) — 6 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl
- [mot443](https://thesaurus.ficedl.info/spip.php?mot443) (geo) — 6 drapeaux : eq_fr:ca · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot449](https://thesaurus.ficedl.info/spip.php?mot449) (geo) — 6 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl
- [mot450](https://thesaurus.ficedl.info/spip.php?mot450) (geo) — 6 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:nl · eq_fr:pt
- [mot453](https://thesaurus.ficedl.info/spip.php?mot453) (geo) — 6 drapeaux : eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl · eq_fr:pt
- [mot483](https://thesaurus.ficedl.info/spip.php?mot483) (geo) — 6 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:nl · eq_fr:pt
- [mot405](https://thesaurus.ficedl.info/spip.php?mot405) (geo) — 5 drapeaux : eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl
- [mot454](https://thesaurus.ficedl.info/spip.php?mot454) (geo) — 5 drapeaux : eq_fr:ca · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:pt
- [mot459](https://thesaurus.ficedl.info/spip.php?mot459) (geo) — 5 drapeaux : eq_fr:ca · eq_fr:de · eq_fr:en · eq_fr:it · eq_fr:nl
- [mot477](https://thesaurus.ficedl.info/spip.php?mot477) (geo) — 5 drapeaux : eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl
- [mot478](https://thesaurus.ficedl.info/spip.php?mot478) (geo) — 5 drapeaux : eq_fr:de · eq_fr:en · eq_fr:es · eq_fr:it · eq_fr:nl

