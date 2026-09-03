# 🔎 AUDIT — Les autorités en profondeur, deux semaines après les conventions

- **Date :** 3 septembre 2026 (soir), cadrage `REPRISE_audit_autorites_en_profondeur_2026-09-03.md`
- **Base auditée :** `anarbib-staging-rede` (`uflwmikiyjfnikiphtcp`) — **c'est la production** ; lecture seule par `execute_sql`
- **Périmètre :** `public.authors` (1 532 fiches) · `public.book_contributors` (3 053 lignes) · `public.books` (2 659 notices) · la file `catalog_review_queue`
- **Statut :** rapport de constat. **Aucune écriture n'a été faite pour l'établir.** Les corrections
  sont classées en §E et livrées ensuite, chacune par migration testée ou par lot de la file — jamais par `UPDATE` direct.
- **Référence :** `AUDIT_conventions_catalographiques_2026-08-20.md` (dont les requêtes sont **rejouées** ici, section par section),
  REGISTRE §37 `CONV`, `DECISIONS_bloc3_cinq_questions_2026-09-03.md`

> **Lecture du tableau de bord.** Les dix-neuf migrations `conventions_*` du 21/08 ont fait
> ce qu'elles annonçaient : les référentiels sont normalisés, les dix titres à article
> rejeté sont rétablis, les vingt et un points d'accès fautifs (particules, filiations,
> doubles patronymes) sont corrigés. **Ce que le tableau montre de neuf, c'est un effet de
> bord** : le lot `autor_sans_autorite`, tranché le 03/09 à 16 h, a créé **227 autorités en
> deux minutes** à partir de transcriptions brutes — et parmi elles **des doublons des
> fiches que le 21/08 venait de corriger**, parce que la recherche d'homonyme se fait sur
> la forme exacte, et que la forme exacte avait justement changé. Le second effet de bord
> est plus discret : quinze fiches dont le point d'accès a été corrigé ont gardé leur
> **forme d'affichage en capitales** (`Simone DE BEAUVOIR` sous `Beauvoir, Simone de`).
> Rien de tout cela n'est une faute de jugement : ce sont des chemins de code qui n'avaient
> jamais été empruntés dans cet ordre.

---

## 0. Tableau de bord — 20/08 → 03/09

| Domaine | Constat | 20/08 | **03/09** | Mouvement | Mécanisable ? |
|---|---|---|---|---|---|
| **A1** | `preferred_name` en forme inversée | 68 | **4** | ✅ corrigé (les 4 = 3 fiches doubles + 1 fixture) | — |
| **A1′** | `preferred_name` ≠ forme dérivée de `sort_name`, **à la casse près** (`Simone DE BEAUVOIR`) | — | **20** | ⚠️ **nouveau** : résidu de la correction du 21/08 | ✅ oui (17 sûres) |
| **A2** | Point d'accès sur une particule | 13 (8 fautifs) | **7** dont 4 légitimes (it/af/nl), **3 doublons C5** | ✅ corrigé ; les 3 restants sont des doublons, pas des coupes | ❌ fusion |
| **A3** | Point d'accès sur un suffixe de filiation | 9 (8 fautifs) | **5** : 3 `Jr.`/`Jr` **jamais vus** + 1 C5 + 1 fixture | ⚠️ le 20/08 ne cherchait pas `Jr.` | ⚠️ lot |
| **A4** | Double patronyme hispanique scindé | 22 (19 avérés) | **0** avéré (19 corrigés ; 10825, 11163 corrects) | ✅ soldé | — |
| **A5** | Fiches sans `country` | 722 / 1 300 | **953 / 1 532** (dont 227 C5 à `NULL`) | ↘ en proportion pour le stock, ↗ en valeur | ❌ documentaire |
| **A6** | Collectivités : typées / repérées mais non typées | 6 | **19 typées** ; **~34 non typées** dont 14 inversées | ⚠️ le motif de repérage rate les radicaux fléchis | ✅ motif + lot |
| **A7** | Sans `birth_year` | 726 (56 %) | **955 (62 %)** ; qualificatifs posés : 574 / 442 | = pour le stock ; 227 C5 sans date | ❌ documentaire |
| **A8** | Aucun identifiant externe | ~1 272 (98 %) | **1 503 (98 %)** ; `external_ids` jamais rempli | = | ❌ Atelier |
| **A9** | `variant_forms` vide | 1 275 | **1 507** | = | ❌ Atelier |
| **N1** | Autorités nées du lot C5 (`source_kind = 'conv_revue'`), non relues | — | **227** : 95 sans virgule, 48 en capitales, 8 multi-personnes, 7 mentions de rôle, ~20 collectivités | **nouveau** | ⚠️ lot |
| **N2** | Doublons **exacts** (sans casse, sans accents, ou forme directe = forme inversée) | 2 (cadrage) | **13 paires** (9 dues à C5, 4 aux fixtures de formation) ; **~25 paires approchées** | **nouveau** | ❌ fusion (`merge_author`) |
| **N3** | Fiches doubles (deux personnes dans une fiche) | 3 (O8) | **12** : 3 + 3 anciennes non vues + 6 C5 | ⚠️ le seuil « quatrième occurrence » de `CONV-O8` est franchi | ❌ à la main |
| **N4** | Non-agents dans `authors` (« ?? », « identificado, Não », un titre, un périodique, un éditeur) | 1 (`Le Monde Diplomatique`) | **7** | **nouveau** | ❌ à la main (`discard_author`) |
| **N5** | Fixtures de la formation BLMF (`source_label = 'formacao-e*'`) en production | — | **5 autorités + 5 notices** (biblio `blmf-teste`) | **nouveau** : polluent T2, T3, T6, A1, A2, A3, N2 | ⚠️ décision |
| **N6** | Contributeurs nommés **sans autorité** (« secondes personnes ») | — | **333** lignes, **231** livres (217 ont déjà une autorité liée) ; **23** liables à une fiche existante | **nouveau** | ⚠️ 23 mécanisables |
| **N7** | Autorités orphelines (aucun lien) | 6 (cadrage) | **3** (10512, 10589, 10663) | recompté | ❌ à la main |
| **N8** | Livres sans aucune autorité | 464 → 18 | **23** = 18 écartés + 5 à `autor` NULL | recompté | — |
| **T1** | Mots-outils capitalisés | 216 | **213** brut / **177** par `fn_conv_lower_stopwords` | = ; 174 encore `a_revoir` dans la file | ⚠️ lot (en cours) |
| **T2** | Titres en capitales | 7 | **3** dont 1 fixture | ✅ | — |
| **T3** | Article rejeté en fin | 10 | **1** (fixture 2741) ; `title_nonfiling` posé sur 802 notices | ✅ soldé | — |
| **T4** | Tiret de date perdu | 12 | **0** | ✅ soldé | — |
| **T5** | Sous-titre collé | ~75 | **81** (` - `, ` : `, `:x`) | = | ❌ tri manuel |
| **T6** | Diacritiques perdus | à recenser | **6** dont 1 fixture | recensé | ⚠️ semi |
| **R1** | `country` hors ISO | 12 en clair | **0** ; 41 codes | ✅ soldé | — |
| **R2** | `idioma` hors BCP-47 | 11 valeurs | **0** ; 7 codes, **452 NULL** (18 → 17 %) | ✅ soldé (les NULL restent NULL, CONV-7) | — |

---

## A. Autorités — les requêtes du 20/08, rejouées

### A1 — Forme inversée dans `preferred_name` : soldé, mais un résidu à la casse

Quatre fiches ont encore `preferred_name` contenant `, ` : 10429, 10748, 10859 (les
trois fiches doubles de `CONV-O8`, dont la forme est indécidable) et 11329 (fixture de
formation, `preferred_name = sort_name`). Le stock de 68 est résorbé.

**Ce que le 20/08 ne pouvait pas voir** (A1′) : après le 21/08, **20 fiches** ont un
`preferred_name` égal à la forme dérivée de `sort_name` *sans casse* mais pas *à la
lettre*. Deux populations :

| Population | n | Exemple | Cause |
|---|---|---|---|
| Point d'accès corrigé le 21/08 (particule, filiation, `A1` virgule parasite), forme d'affichage laissée telle quelle | **17** | `Beauvoir, Simone de` → `Simone DE BEAUVOIR` ; `Luz Filho, Fábio` → `Fábio Luz FILHO` ; `Sade, Marquis de` → `Marquis DE SADE` | la migration `10` a réécrit `sort_name` ; `preferred_name` avait été dérivé de l'**ancien** `sort_name` en capitales |
| Fixtures de formation (`sort_name` en capitales, `preferred_name` propre) | 3 | `FILHO, Fábio Luz` / `Fábio Luz Filho` | voulu : c'est l'exercice |

Ids de la première population : 18, 19, 28, 10154, 10164, 10180, 10199, 10488, 10489,
10493, 10593, 10594, 10595, 10743, 10952, 10953, 10954.

**Mécanisable et sûr** (CONV-2 : `preferred_name` dérive de `sort_name`) à une
condition : ne réécrire que lorsque `sort_name` est **en casse naturelle** (aucun mot de
deux capitales ou plus). Sinon on dériverait `Fábio Luz FILHO` depuis `FILHO, Fábio Luz`
— et on abîmerait les trois fixtures. → **migration `A1′`**, 17 fiches.

### A2 — Particules : corrigé, et re-créé

Les huit coupes fautives du 20/08 sont corrigées (`Sousa, Manuel Joaquim de`,
`Beauvoir, Simone de`…). Les quatre entrées légitimes (`Van Der Walt`, `De Amicis`,
`Di Paolo`, `De Greef`) sont intactes **et portent désormais `name_lang`** (`af`, `it`,
`it`, `fr`) — la règle CONV-6 est calculable sur elles.

Restent sept fiches dont le point d'accès commence par une particule :

| id | `sort_name` | Statut |
|---|---|---|
| 10079 | `Di Filippo, Luis` | ✅ correct (italien) — écarté au lot casse |
| 10993 | `Van Paassen, Pierre` | NL : entrée après le préfixe attendue (`Paassen, Pierre van`) — **à revoir** |
| 11041 | `De Serpa Pimentel, Antonio` | PT : particule rejetée attendue (`Serpa Pimentel, Antonio de`) — **à revoir** |
| 11147 | `De Sario, Beppe` | italien moderne : ✅ conserver ; `name_lang` à poser |
| 11293 | `Van Vogt, A. E.` | anglophone (CA) : ✅ conserver |
| **11367, 11383, 11417** | `DE JONG, Rudolf`, `DE FREITAS, Allan`, `DE CARVALHO, Florentino` | **doublons créés par C5** des fiches 10180, 10622, 10164 corrigées le 21/08 — **à fusionner**, pas à recouper |

Les trois dernières sont le cas d'école de cet audit : la transcription `books.autor`
portait l'ancienne forme (`DE CARVALHO, Florentino`), la recherche d'homonyme de
`conv_revue_appliquer` compare `lower(sort_name)` et `lower(preferred_name)` à la lettre,
la fiche corrigée s'écrit `Carvalho, Florentino de` / `Florentino DE CARVALHO`… et la
comparaison échoue à cause des **capitales de `preferred_name`** (A1′). Sans A1′, la
recherche aurait trouvé `Florentino de Carvalho`. **A1′ et N2 sont le même défaut vu
de deux côtés.**

### A3 — Filiation : huit corrigées, cinq que le 20/08 ne voyait pas

Les huit `FILHO/JÚNIOR/NETO, …` sont recoupées (`Luz Filho, Fábio`, `Franco Júnior,
Hilário`…). Mais le motif du 20/08 (`filho|júnior|junior|neto|sobrinho`) ignorait
l'abréviation **`Jr.`**, et la vue de contrôle `private.v_conv_controle_qualite` l'ignore
toujours :

| id | `sort_name` | Proposé |
|---|---|---|
| 10736 | `Jr, Paulo José da Costa` | `Costa Jr., Paulo José da` |
| 10737 | `Jr., Armando Boito` | `Boito Jr., Armando` |
| 10738 | `Jr., Paulo Ghiraldelli` | `Ghiraldelli Jr., Paulo` |
| 11333 | `Filho, Edson Gonçalves` (C5) | `Gonçalves Filho, Edson` |
| 11326 | `FILHO, Fábio Luz` (fixture) | — (doublon de 10594, N5) |

→ **lot** (jugement : `Costa Jr.` ou `Costa Júnior` ?) et **motif de la vue à élargir**.

### A4 — Double patronyme : soldé

Les dix-neuf corrections sont en base (`Flores Magón, Ricardo`, `Gómez Casas, Juan`,
`Ramón y Cajal, Santiago`…), les trois faux positifs sont intacts (`Mechoso, Juan
Carlos`, `Borges, Jorge Luis`, `Marcos, Subcomandante Insurgente`). La détection
rejouée sur `country` hispanophone ne remonte plus que six fiches, toutes correctes.
Mais — comme le disait A5 — c'est un plancher : **11337 `CASAS, Juan Gómez`** (C5) est
un doublon **de la forme fautive** de 10074 `Gómez Casas, Juan`, corrigée le 21/08.

### A5 — Pays et langue du nom

953 fiches sans `country` (62 %), dont les 227 de C5. `name_lang` est renseigné sur
**22 fiches** (les cas A2 du 20/08) : la règle CONV-6 vit, mais ne s'applique encore
qu'à ces vingt-deux. Rien à mécaniser (CONV-7 : on ne devine pas).

### A6 — Collectivités : le motif de repérage a un trou

19 fiches sont typées `collective` (les 14 du lot `autorite_collectivite` + 5 typées au
formulaire). Deux restent `a_revoir` dans le lot (10503 `Dieese, CESIT` = deux organismes ;
11176 hiérarchie sous la virgule) — verdicts humains, rien à faire ici.

**Ce que le lot n'a pas vu.** La fonction `private.conv_motifs_collectivite()` encadre
ses radicaux de `\y…\y` — une **frontière de mot des deux côtés**. `federa` ne prend donc
ni `Federação` ni `Federation` ni `Federazione` ; `comit` ne prend ni `Comité` ni `Comitê` ;
`organiza` ne prend pas `Organização`. Quatorze collectivités **inversées comme des
personnes** sont restées hors du lot :

| id | `sort_name` | Nature |
|---|---|---|
| 10244 | `Annecy, Groupe 1er Mai-` | groupe |
| 10359 | `Bragado, Comité Pro Libertad de los presos de` | comité |
| 10362 | `Brasil, República Federativa do` | État (collectivité publique) |
| 10552 | `Espanha, Coordenação dos Grupos Autónomos da` | coordination |
| 10565 | `Federation, Anarchist Communist` | fédération |
| 10616 | `Francófona, Federação Anarquista` | fédération |
| 10715 | `International, Congrès Anarchiste` | **congrès** (`congress`, pas `collective`) |
| 10718 | `Italiana, Federazione Anarchica` | fédération |
| 10792 | `Libertário, Organização Anarquista Socialismo` | organisation |
| 10793 | `Libertarios, Fundación de Estudios` | fondation |
| 11254 | `Uruguai, Federação Anarquista` | fédération |
| 11466 | `Popular, Universidade` (C5) | université |
| 11478 | `Roorda, Association Des Amis De Henri` (C5) | association |
| 11534 | `Students, Federation of Libertarian` (C5) | fédération |

Et une vingtaine de collectivités **non inversées mais non typées**, nées de C5 :
`Fédération Anarchiste`, `Comitê de Resistência Curda`, `Comitê de Solidariedade à
Resistência curda de Sâo Paulo`, `Grupo Anarquista 1º de Maio`, `Centro de Memória
Sindical`, `Núcleo de Sociabilidade Libertária - NU-SOL`, `MOVIMENTO - Centro de Cultura
e Autoformação`, `DIELO TRUDA - Grupo de Anarquistas Russos no Estrangeiro`,
`Biblioteca Terra Livre e Núcleo de Estudos Libertários Carlo Aldegheri (Org.)`,
`Lesbianas y feministas por la descriminalización del aborto`, `CrimethInc. Writers'
Bloc`, `Serviço Nacional d Informações – SNI`, `Imprensa Marginal`, et les sigles
`DIEESE`, `ANTEAG`, `ENFF`, `CNA`. Sur celles-là, la décision n'est pas « dé-inverser »
mais « **typer** » — la branche `autorite_collectivite` de `conv_revue_appliquer` le fait
déjà (elle écrit `authority_type` + le jsonb + le point d'accès) ; il suffit que la
proposition soit le nom lui-même.

→ **migration** : motif à radical ouvert (`\m(federa|comit|…)` sans frontière fermante,
et `organiza[çc]` pour ne pas prendre `Organizador`) + la vue de repérage étendue aux non
inversées + **re-semis idempotent** du lot (`on conflict do nothing` : les 16 verdicts
existants sont intouchés). Un essai du motif ouvert remonte deux faux positifs à écarter
du motif : `casa` (prend `Casas`, `Casanova`) et `cira` nu (prend `Cirano`).

### A7 — Dates

577 fiches avec `birth_year` (38 %), 445 avec `death_year`. Les qualificatifs CONV-5
sont posés sur tout le stock daté (574 / 442) ; `activity_period` n'a **jamais** été
utilisé. Les 227 fiches C5 n'ont aucune date. Une seule porte des dates **dans son nom** :
11398 `Hakim Bey 1945-2022` — qui est un doublon de 10334 `Bey, Hakim` (N2).

### A8 / A9 — Identifiants et formes variantes

28 VIAF, 23 ISNI, 28 Wikidata, 25 `variant_forms` : **exactement les chiffres du 20/08**.
Rien n'a bougé en deux semaines ; `external_ids` (jsonb) n'a jamais reçu une valeur. La
couche autorité de `spec-sources-externes-autorites` §5 reste spécifiée, non alimentée.

---

## B. Ce que le 20/08 n'a pas vu — ou qui n'existait pas encore

### N1 — Les 227 autorités du lot C5, à relire

Créées le 03/09 entre 16 h 08 et 16 h 10 par `conv_revue_appliquer('autor_sans_autorite')`,
`sort_name = preferred_name = la transcription` dans 98 cas, **aucune n'est typée**,
aucune n'a de pays ni de date, 14 portent déjà plusieurs liens. Classées par la forme :

| Classe | n | Exemples | Ce que la relecture décide |
|---|---|---|---|
| Forme inversée correcte | **98** | `Ellul, Jacques`, `Holloway, John`, `Sacco, Nicola` | rien — sauf `name_lang`/`country` au fil de l'eau |
| **Forme directe, plusieurs mots** (« Prénom Nom ») | **~45** | `Daniel Rodrigues Aurélio`, `Mark Bray`, `Fabio López López`, `Newton Stadler de Souza` | où couper : `Aurélio, Daniel Rodrigues` (pt) ; `López López, Fabio` (es) — **jugement** |
| **Mononymes / pseudonymes** | **35** | `Volin`-like : `Voltaire`, `Gramsci`, `Henfil`, `Starhawk`, `Stepniak`, `Ratgreb`, `Meltzer`, `Louÿs`, `Platão` | confirmer le mononyme, ou compléter (`Meltzer, Albert` existe : 11438 ; `Louÿs, Pierre`) |
| **Patronyme en capitales** | **39** (+9 tout en capitales) | `BONANNO, Alfredo`, `DAVRANCHE, Guillaume`, `LÊNIN, Vladimir Illitch`, `ZAMENHOF, L. L.` | CONV-1 → **lot `autorite_casse`**, second semis |
| Collectivités non typées | **~20** | voir A6 | typer → lot `autorite_collectivite` |
| **Mention de rôle dans le nom** | **7** | `Kauan Willian dos Santos (Org.)`, `Golarons, Ricard de Vargas (org.)`, `LUDMILA, Aline (et al.)`, `MC CABE Mary Alice (Org,)` | retirer la mention, inverser ; le rôle va sur `book_contributors.role` |
| **Plusieurs personnes dans une fiche** | **8** | `Giorgio Sacchetti, Augusto Gayubas, Manuel Vicent Balaguer, Ignacio Donézar, José Luis Gutiérrez Molina` ; `Antonio Serra & Cristina Pereira` ; `Bookchin, Janet Biehl/Murray` | **N3** — pas la file |
| Dates dans le nom | 1 | `Hakim Bey 1945-2022` | doublon de 10334 → fusion |
| Bruit | 1 | `??` (11366, lié à 1 livre) | non-agent → N4 |
| Non-agent | 2 | `identificado, Não` (11431, **2 liens**), `Piccolo Dizionario degli Orrori` (un titre) | N4 |

Deux leçons pour l'outil, mécanisables :

- `fn_conv_autor_proposition` filtre `n[ãa]o identific` mais la transcription était
  **inversée** (`identificado, Não`) : le filtre doit s'appliquer aux deux formes, et
  refuser aussi `??`, `S/A`, `s.n.`, `Autores, Vários`.
- la recherche d'homonyme de `conv_revue_appliquer` doit comparer **sans accents**
  et sur la **forme dérivée** en plus des deux formes stockées — sinon la prochaine
  application du lot recréera `Platao` à côté de `Platão`.

### N2 — Doublons : 13 paires exactes, ~25 approchées

Paires **exactes** (même clé après `lower(unaccent())`, sur `sort_name`, `preferred_name`,
ou forme directe de l'une = forme inversée de l'autre) :

| Fiche à conserver | Doublon | Origine du doublon | Liens du doublon |
|---|---|---|---|
| 1 `Reclus, Élisée` (61 liens) | 11330 | fixture formation | 0 |
| 10029 `Makhno, Nestor` (7) | 11329 | fixture formation | 0 |
| 18 `Bringel, Fabiano de Oliveira` | 11327 `DE OLIVEIRA BRINGEL, Fabiano` | fixture formation | 1 (livre 2741, `blmf-teste`) |
| 10594 `Luz Filho, Fábio` | 11326 `FILHO, Fábio Luz` | fixture formation | 1 (2740) |
| 10840 `Flores Magón, Ricardo` | 11328 `MAGÓN, Ricardo Flores` | fixture formation | 1 (2742) |
| 10074 `Gómez Casas, Juan` | 11337 `CASAS, Juan Gómez` | **C5** | 2 |
| 10164 `Carvalho, Florentino de` | 11417 `DE CARVALHO, Florentino` | **C5** | 1 |
| 10180 `Jong, Rudolf de` (0 lien !) | 11367 `DE JONG, Rudolf` | **C5** | 1 |
| 10622 `Freitas, Allan de` | 11383 `DE FREITAS, Allan` | **C5** | 1 |
| 10167 `Van Der Walt, Lucien` | 11553 `Walt, Lucien van der` | **C5** | 1 |
| 10676 `Guattari, Félix` | 11391 `Guattari, Felix` | **C5** (accent) | 1 |
| 10819 `López, Fábio López` | 11371 `Fabio López López` | **C5** (forme directe) | 1 |
| 11447 `Platao` | 11471 `Platão` | **C5 × 2** | 1 / 1 |

Paires **approchées** (trigrammes ≥ 0,5, à confirmer une par une) : `D'Auria` / `D´Auria`
(11340/10472, apostrophe typographique), `Pigault-Lebrun` / `Lebrun, Pigault` (11445/10775),
`J.M.Raynaud` / `Raynaud, J. M.` (11470/11083), `ZAMENHOF, L. L.` / `Zamenhof, L.L.`
(11536/11554, **deux créations C5 pour la même personne**), `BONANNO, Alfredo` /
`BONANNO, Alfredo M.` / `Bonanno, Alfredo María` (11347/11378/10349), `René Gertz` /
`Gertz, René E.`, `PLANCHE, Fernand` / `Planche, Fernando`, `GUYAU, M.` / `GUYAU, Juan
Maria` / `Guyau, J. M.` / `Guyau, Jean-Marie` (11409/11406/10085/10686 — **quatre fiches**
pour Jean-Marie Guyau), `BAUER, Augustín Souchy` / `Bauer, Agustín Souchy` / `Souchy,
Agustín`, `LOPREATO, Christina Roquette` / `Lopreato, Christina Da Silva Roquette`,
`MAGNANI, Silvia` / `Magnani, Silvia Lang`, `SOUZA LOBO, Elizabeth` / `Lobo, Elisabeth
Souza`, `BOUDELAIRE, Charles` / `Baudelaire, Charles` (coquille), `Subcomandante Marcos` /
`Marcos, Subcomandante Insurgente`, `LÊNIN, Vladimir Illitch` / `Lênin, Vladimir Ilich`,
`Miguel Bodea` / `Bodela, Miguel`, `Marcos Cesar (Grito)` / `Cesar, Marcos`, `VEGA,
Mercier` / `Mercier-Vega, Louis`, `MORAIS, Wallace` / `Moraes, Wallace`, `Hakim Bey
1945-2022` / `Bey, Hakim`, `RATGEB` / `Ratgreb` (le pseudonyme de Vaneigem, deux
graphies, l'une fausse), `Meltzer` / `Meltzer, Albert`, `Archinov` / `Archinov, Piotr`,
`LIMA, Adolpho` / `Lima, Adolfo`, `Rogério Nascimento` / `Nascimento, Rogério Humberto
Zeferino` / `Nasciemnto, Rogério H. Z.` (coquille dans la troisième), `Guàrdia, Francesc
Ferrer I.` / `Ferrer Y Guardia, Francisco`.

**Aucune de ces paires ne se fusionne par script.** Le dépôt a `merge_author` (fusion),
`preview_merge_author` (aperçu), `report_authority_pair` (signalement dans
`authority_duplicate_reports`, lu par l'Atelier), et le circuit de propositions
`fn_authority_propose(kind = 'fusion')` avec ses quatorze jours. **La bonne porte est le
signalement** : il met la paire devant un œil sans rien écrire.

### N3 — Fiches doubles : le seuil de `CONV-O8` est franchi

Le 21/08 en comptait trois (10748, 10859, 10429) et actait : « pas de fonction de
scission avant la quatrième ». Il y en a **douze** :

| id | `sort_name` | Origine |
|---|---|---|
| 10748 | `KAISER, William Young and David E.` | import (connue) |
| 10859 | `MARIA AMÉLIA DE ALMEIDA TELES, Mônica de Melo` | import (connue) |
| 10429 | `CHRISTIAN BAY, Charles Walter` | import (connue) |
| 10709 | `Ibáñez, Salvador Gurucharri y Tomás` | import — **non vue** |
| 10942 | `Musté, Ignacio Vidal y Pedro Costa` | import — **non vue** |
| 11035 | `Philopat, Duka e Marco` | import — **non vue** (`Philopat, Marco` existe : 11037) |
| 11359 | `Antonio Serra & Cristina Pereira` | C5 |
| 11376 | `Bookchin, Janet Biehl/Murray` | C5 (`Bookchin, Murray` = id 10) |
| 11389 | `Doris Accioly e Silva, Sonia Alem Marrach (Org.)` | C5 |
| 11420 | `Giorgio Sacchetti, Augusto Gayubas, Manuel Vicent Balaguer, Ignacio Donézar, José Luis Gutiérrez Molina` | C5 (cinq personnes) |
| 11424 | `Durval Muniz de Albuquerque Júnior, Alfredo Veiga-Neto, Alípio de Souza Filho (orgs.)` | C5 (trois ; `Sousa Filho, Alípio de` = 10593) |
| 11475 | `MORAES, Carla Kelen de Andrade. Acioli, Edane de Jesus França et al.` | C5 |
| 11510 | `PHILOPAT, Duka e Marco PhilopatMarco` | C5 (doublon de 11035, en pire) |

La machinerie `fn_authority_split` **existe** depuis la migration `17` et le verdict du
03/09 disait « pas de fonction… à la main jusqu'à la quatrième ». Douze, c'est la
quatrième trois fois. **Ce n'est pas à cette session de trancher** : c'est une décision
de gouvernance (`CONV-O8`), remontée au REGISTRE. Ces fiches **ne vont pas dans la file**
(c'est écrit dans O8) ; le nouveau lot les liste sans proposition, avec la note qui
renvoie à l'Atelier.

### N4 — Sept non-agents

| id | `sort_name` | Nature | Liens |
|---|---|---|---|
| 11366 | `??` | bruit | 1 |
| 11431 | `identificado, Não` | « non identifié » inversé — **le filtre de C5 ne le voyait pas** | **2** |
| 11511 | `Piccolo Dizionario degli Orrori` | un **titre** (et 10512 `Dizionario, Piccolo`, orpheline, est le même titre) | 1 |
| 10512 | `Dizionario, Piccolo` | idem, orpheline | 0 |
| 10507 | `Le Monde Diplomatique` | périodique (déjà noté le 20/08 ; typé `collective` depuis) | 1 |
| 11457 | `Noir et Rouge` | périodique / groupe éditeur — **à qualifier** (un titre de revue est une œuvre, le groupe est une collectivité) | 1 |
| 11549 | `UFRGS, Revista do IFCH /` | périodique inversé | 1 |

Retirer une autorité liée demande : délier (`unlink_author_book`), puis `discard_author`
(qui refuse une fiche encore liée). Deux gestes à la main, par une personne staff.

### N5 — La formation BLMF a ses fixtures en production

Cinq autorités (`source_label = 'formacao-e1'` à `'e5'`, `created_by` NULL, créées le
26/08 à 07 h 00 en une transaction) et cinq notices (2740–2744) dans la bibliothèque
`blmf-teste`, **délibérément fautives** pour l'exercice : `FILHO, Fábio Luz`, `Moral
Anarquista, A` (T3), `REGENERACIÓN E A REVOLUÇÃO MEXICANA` (T2), `EducaÇao libertária e
concepçao de mundo` (T6), `Makhno, Nestor` avec `preferred_name = sort_name`. C'est un
bac à sable dans la base réelle : les autorités sont dans le **corpus partagé** (elles
sortent dans `search_authors_by_name` pour toutes les bibliothèques), et elles comptent
dans chaque indicateur de cet audit. **Ne pas les corriger** — ce sont les cas de la
séance du 08/09. Les exclure des semis (`source_label not like 'formacao-%'`) et
décider, après la formation, de les retirer.

### N6 — Les secondes personnes : 333 contributeurs sans autorité

Le lot C5 a lié **la première** personne de chaque chaîne. Il reste **333 lignes**
`book_contributors` à `author_id` NULL sur **231 livres**, dont **217 ont déjà une
autorité** pour un autre contributeur. Les noms sont majoritairement bien formés
(`Almeida, Maria Hermínia Tavares de`, `Hall, Michael M.`) ; **23** correspondent
exactement (sans casse ni accents) à une fiche existante (`Addor, Carlos Augusto` ↔
10215 ; `BETTO, Frei` ↔ 10333) ; une poignée est du bruit d'import (`1959. ), George
Grosz (1893`, `/ Miroel Silveira`, `can., Miguel`, `BEZERRA, BEZERRA Sheila`). Vingt
lignes portent un rôle autre qu'`autor` (`organizador`, `tradutor`, `editor`, `outro`).

Ce n'est pas le lot C5 (qui travaille par livre, sur `books.autor`). C'est un lot **par
contributeur** — dont la proposition est « lier à la fiche homonyme » quand elle existe,
« créer » sinon — et il reproduira le défaut N2 tant que la recherche d'homonyme n'est
pas corrigée. **Ordre** : d'abord la recherche d'homonyme, ensuite ce lot. Il n'est pas
livré dans cette session ; le formulaire de catalogage le fait déjà ligne à ligne.

### N7 — Orphelines

Trois fiches sans aucun lien : 10512 `Dizionario, Piccolo` (N4), 10589 `Ferroa, Piero`,
10663 `González Pacheco, Rodolfo` (un auteur réel dont la notice a sans doute été
fusionnée). `discard_author` les accepte telles quelles ; à voir une par une.

### N8 — Les vingt-trois livres sans autorité

18 écartés au lot C5 (anonymes, collectifs, `AA. VV.` — c'est le verdict), et **5 à
`autor` NULL** que le semis n'a jamais vus (il exige `autor` non vide) : 2541, 2553,
2554, 2614 (catalogues d'exposition, recueils — sans contributeur) et 2737 (un éditeur
comme seul contributeur). Rien à corriger.

---

## C. Titres — état au 03/09

- **T1** : 213 titres portent encore un mot-outil capitalisé (177 selon
  `fn_conv_lower_stopwords`, qui ne juge que les titres à `idioma` connu). Le lot
  `titre_casse` a 174 lignes `a_revoir`, 37 appliquées. C'est le travail de la file, il
  avance à son rythme.
- **T2** : 3 (2452, 2736, et la fixture 2742). **T3** : 1 (fixture 2741) — les dix du
  20/08 sont rétablis et `title_nonfiling` est posé sur 802 notices. **T4** : 0.
- **T5** : 81 titres avec ` - `, ` : ` ou `:x` — tri manuel, inchangé.
- **T6** : 6 — `Um Pequeno Sim E Um Grande Nao` (2164), `Semana Trágica: A Greve Geeral…`
  (2696), `Trajetorias Historicas Da EducaÇao` (56), `Bourdieu e a EducaÇao` (661),
  `Concepçao Anarquista Do Sindicalismo` (857), et la fixture 2744. Cinq notices : à la
  main dans le formulaire, ce n'est pas un lot.

## D. Référentiels — soldés

`country` : 41 codes ISO, 0 libellé en clair. `idioma` : 7 codes BCP-47 (`pt-BR` 1 277,
`es` 612, `fr` 116, `en` 108, `it` 89, `eo` 3, `de` 2), 0 hors référentiel, **452 NULL**
(17 %) — ils restent NULL, c'est CONV-7. Les deux CHECK sont validées.

## E. La file de vérification au 03/09

| Lot | `a_revoir` | `valide` | `corrige` | `ecarte` | appliquées |
|---|---|---|---|---|---|
| `autor_sans_autorite` | 0 | 446 | 0 | 18 | 446 |
| `autorite_casse` | **3** (les fiches doubles) | 42 | 15 | 1 | 57 |
| `autorite_collectivite` | **2** | 14 | 0 | 0 | 14 |
| `autorite_patronyme` | 0 | 20 | 0 | 2 | 20 |
| `titre_casse` | **174** | 33 | 4 | 0 | 37 |

Les tables `conv_backup.*` du 20/08 sont intactes (211 titres, 1 274 casses dont 61 non
appliquées = les 61 versées dans la file, 22 patronymes) : ce sont des instantanés.

---

## F. Classement des défauts, et ce qui est livré

| # | Défaut | Nature | Voie | Livré dans cette session |
|---|---|---|---|---|
| 1 | **A1′** — 17 `preferred_name` figés en capitales après correction du point d'accès | mécanique, sûre (CONV-2 ; garde : `sort_name` en casse naturelle) | **migration** + suite | ✅ |
| 2 | **A6** — motif collectivités à frontière fermante ; 14 inversées + ~20 non typées hors lot | mécanique (le motif) + jugement (les verdicts) | **migration** (motif, vue étendue, re-semis idempotent) + suite | ✅ |
| 3 | **N1** — `fn_conv_autor_proposition` aveugle aux anonymes inversés ; recherche d'homonyme à la lettre | mécanique | **migration** (fonction + recherche `unaccent` + forme dérivée) + suite | ✅ |
| 4 | **N1** — 48 capitales nées de C5 | jugement | **second semis du lot `autorite_casse`** (proposition `initcap` du patronyme, comme le 20/08) | ✅ |
| 5 | **N1/A2/A3** — ~45 formes directes, 35 mononymes, 7 mentions de rôle, 5 filiations/particules, 8 fiches doubles listées | jugement | **nouveau lot `autorite_forme`** (CHECK, semis, branche d'application, carte, i18n ×10) + suite | ✅ |
| 6 | **N2** — 13 paires exactes | fusion (`merge_author`) | **signalement** dans `authority_duplicate_reports` des **8** paires hors fixtures de formation (les 5 paires « formacao-e* » sont exclues à dessein, voir N5) — aucune écriture sur les fiches | ✅ dans la migration du point 3 (8 signalements ouverts en production le 03/09 au soir) |
| 7 | **N3** — 12 fiches doubles | gouvernance (`CONV-O8`) | REGISTRE : le seuil est franchi, décision à prendre | ✅ REGISTRE |
| 8 | **N4** — 7 non-agents | à la main (`unlink` + `discard_author`) | liste ci-dessus | ❌ hors session |
| 9 | **N5** — fixtures de formation | décision | exclues des semis ; à retirer après le 08/09 | ✅ exclusion |
| 10 | **N6** — 333 secondes personnes | jugement | lot par contributeur, **après** le point 3 | ❌ hors session |
| 11 | **T6** (5), **T5** (81), **N7** (3) | à la main | — | ❌ |

**Ordre d'exécution** : 1 → 3 → 2 → 4 → 5. Le point 3 avant les semis 4 et 5, parce que
c'est lui qui empêche les lots de recréer des doublons.

---

## G. Ce que cet audit ne dit pas

- Il ne juge **aucune** des 227 fiches : il les classe par forme pour que la relecture
  aille vite. Une forme directe peut être un pseudonyme voulu (`Filósofo da Selva`).
- Les paires approchées de N2 sont des **candidates**, pas des doublons : `GUYAU, Juan
  Maria` et `Guyau, Jean-Marie` sont bien la même personne, `Carneiro, Daniela` et
  `Carneiro, Daniele` peut-être pas.
- Il ne couvre pas les autorités matière (thésaurus FICEDL, H1 clos, source externe qu'on
  ne corrige pas chez nous).
- Les effectifs de N6 sont bruts : parmi les 333, une partie est du bruit d'import qu'il
  faudra écarter, pas lier.
- Il ne mesure pas `books.autor` lui-même (la transcription reste, C5 = B).
