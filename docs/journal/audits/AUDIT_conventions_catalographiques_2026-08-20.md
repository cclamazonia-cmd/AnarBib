# 🔎 AUDIT — Conventions d'écriture des autorités et des titres

- **Date :** 20 août 2026
- **Base auditée :** `anarbib-staging-rede` (`uflwmikiyjfnikiphtcp`), lecture seule
- **Périmètre :** `public.authors` (1 300 fiches) · `public.books` (2 674 notices)
- **Statut :** rapport de constat. **Aucune écriture n'a été faite.** Les corrections
  proposées sont dans `supabase/migrations/20260821T04*_conventions_*.sql`, non appliquées.
- **Spec de référence :** `spec-conventions-catalographiques.md` (`docs/specs/`)
- **Décisions :** `REGISTRE_decisions.md` **§37 `CONV`** (`CONV-1` à `CONV-7`) + **`DOC-CONV-1`** en §0

> **Lecture du tableau de bord.** Trois familles de défauts, de nature différente :
> les **erreurs de découpage du nom** (bibliothéconomiques — il faut un œil humain),
> les **artefacts d'import** (mécaniques — corrigeables en masse), et les
> **référentiels non normalisés** (`country`, `idioma` — prérequis technique aux deux autres).

---

## 0. Tableau de bord

| Domaine | Constat | Effectif | Mécanisable ? |
|---|---|---|---|
| **A1** | `preferred_name` en forme inversée (`Nom, Prénom`) au lieu de la forme directe | **68** / 1 300 | ✅ oui |
| **A2** | Point d'accès pris sur une **particule** initiale (`DE OLIVEIRA…`) | **13** | ⚠️ semi (dépend de la langue) |
| **A3** | Point d'accès pris sur un **suffixe de filiation** (`FILHO, …`) | **9** | ✅ oui |
| **A4** | Découpage hispanique suspect (double patronyme scindé) | **22** signalés, **~19** avérés | ❌ revue humaine |
| **A5** | Sous-détection A4 faute de `country` renseigné | **722** fiches sans pays | — |
| **A6** | Collectivités logées dans `authors` faute de table dédiée | **6** | ❌ décision de modèle |
| **A7** | Autorités sans date de naissance | **726** / 1 300 (56 %) | ❌ documentaire |
| **A8** | Autorités sans aucun identifiant externe (VIAF/ISNI/Wikidata) | **~1 272** (98 %) | ❌ Atelier |
| **A9** | `variant_forms` vide | **1 275** (98 %) | ❌ Atelier |
| **T1** | Titres capitalisant une conjonction ou une préposition | **216** | ⚠️ semi |
| **T2** | Titres intégralement en capitales | **7** | ✅ oui |
| **T3** | Titres à **article rejeté en fin** (pratique de fiche cartonnée) | **10** | ✅ oui |
| **T4** | Dates dont le tiret a disparu à l'import (`1868 1910`) | **12** | ✅ oui |
| **T5** | Sous-titre collé au titre par ` - ` ou ` : ` alors que `subtitulo` existe | **~75** à trier | ⚠️ semi |
| **T6** | Diacritiques perdus / capitalisation cassée (`EducaÇao`, `Concepçao`) | à recenser | ⚠️ semi |
| **R1** | `country` : 47 valeurs pour ~40 pays (codes ISO + libellés en clair) | **722** nuls, **12** en clair | ✅ oui |
| **R2** | `idioma` : 11 valeurs pour 8 langues | **471** nuls | ✅ oui |

---

## A. Autorités

### A1 — Deux générations d'import dans `preferred_name`

`sort_name` est rempli à 100 % et homogène (`NOM, Prénom`). En revanche
`preferred_name`, qui est le champ **d'affichage**, contient deux formes :

| Forme | Effectif | Exemple | Fiches |
|---|---|---|---|
| Directe, patronyme capitalisé | 1 232 | `Élisée RECLUS` | ids 1–~2000 |
| Inversée (fuite du point d'accès) | 68 | `Makhno, Nestor` | ids 10028–10112 principalement |

Deux fiches supplémentaires portent une virgule parasite dans la forme directe :

- `34` — `Edson, PASSETTI` → `Edson Passetti`
- `10065` — `SILVEIRA, Ênio` (rangée à tort en collectivité, cf. A6) → `Ênio Silveira`

**Mécanisable.** La forme directe se reconstruit depuis `sort_name` :
`split_part(sort_name,', ',2) || ' ' || split_part(sort_name,', ',1)`.

### A2 — Point d'accès pris sur la particule

La règle dépend de la **langue du nom**, pas d'un principe universel. Les entrées
ci-dessous sont **correctes** et ne doivent pas être touchées :

| id | `sort_name` | Aire | Verdict |
|---|---|---|---|
| 10167 | `VAN DER WALT, Lucien` | Afrikaans / Afrique du Sud | ✅ conserver |
| 10487 | `DE AMICIS, Edmondo` | Italien moderne | ✅ conserver |
| 10499 | `DI PAOLO, Pasquale` | Italien moderne | ✅ conserver |
| 10492 | `DE GREEF, Guillaume` | Belge francophone | ✅ conserver |

Les entrées ci-dessous sont **fautives** (portugais et français rejettent la particule) :

| id | Actuel | Proposé |
|---|---|---|
| 18 | `DE OLIVEIRA BRINGEL, Fabiano` | `BRINGEL, Fabiano de Oliveira` |
| 19 | `DE OLIVEIRA MACEDO, Cátia` | `MACEDO, Cátia de Oliveira` |
| 10154 | `DE SOUSA, Manuel Joaquim` | `SOUSA, Manuel Joaquim de` |
| 10164 | `DE CARVALHO, Florentino` | `CARVALHO, Florentino de` ¹ |
| 10180 | `DE JONG, Rudolf` | `JONG, Rudolf de` ² |
| 10488 | `DE BEAUVOIR, Simone` | `BEAUVOIR, Simone de` |
| 10489 | `DE CASTRO, Paulo` | `CASTRO, Paulo de` |
| 10493 | `DE LIMA PEREIRA, Almir` | `PEREIRA, Almir de Lima` |

¹ Pseudonyme de Primitivo Soares — à traiter aussi comme renvoi (cf. spec §6.3).
² Néerlandais : entrée après le préfixe, sauf préfixe `Ver`.

### A3 — Point d'accès pris sur le suffixe de filiation

**Le défaut le plus grave du lot** : `Filho`, `Júnior`, `Neto`, `Sobrinho` font
partie du patronyme, ils ne sont jamais l'élément d'entrée. Ranger sous `FILHO`
revient à créer une autorité « Monsieur Fils ».

| id | Actuel | Proposé |
|---|---|---|
| 10593 | `FILHO, Alípio de Sousa` | `SOUSA FILHO, Alípio de` |
| 10594 | `FILHO, Fábio Luz` | `LUZ FILHO, Fábio` |
| 10595 | `FILHO, Olavo Cabral Ramos` | `RAMOS FILHO, Olavo Cabral` |
| 10743 | `JÚNIOR, Hilário Franco` | `FRANCO JÚNIOR, Hilário` |
| 10952 | `NETO, Adalberto Coutinho de Araujo` | `ARAUJO NETO, Adalberto Coutinho de` |
| 10953 | `NETO, Candido de Mello` | `MELLO NETO, Candido de` |
| 10954 | `NETO, Oscar Farinha` | `FARINHA NETO, Oscar` |
| 28 | `CORREA DE AQUINO JÚNIOR, Paulo Olivio` | `AQUINO JÚNIOR, Paulo Olivio Correa de` |
| 10078 | `REIS FILHO, Daniel Aarão` | ✅ correct, ne pas toucher |

### A4 — Double patronyme hispanique scindé

L'import a appliqué « dernier mot = patronyme ». En espagnol, l'entrée se fait au
**premier** patronyme et **les deux sont conservés**.

| id | Pays | Actuel | Proposé | Verdict |
|---|---|---|---|---|
| 10059 | ES | `MOSCARDÓ, Cristina Escrivá` | `ESCRIVÁ MOSCARDÓ, Cristina` | ✅ à corriger |
| 10074 | ES | `CASAS, Juan Gómez` | `GÓMEZ CASAS, Juan` | ✅ |
| 10079 | AR | `FILIPPO, Luis Di` | `DI FILIPPO, Luis` | ✅ |
| 10110 | ES | `TRUJILLO, Fernando López` | `LÓPEZ TRUJILLO, Fernando` | ✅ |
| 10212 | ES | `ABELLA, Isidro Guardia` | `GUARDIA ABELLA, Isidro` | ✅ |
| 10384 | ES | `CALVO, Agustín García` | `GARCÍA CALVO, Agustín` | ✅ |
| 10392 | AR | `CANCLINI, Néstor García` | `GARCÍA CANCLINI, Néstor` | ✅ |
| 10411 | MX | `CASSANOVA, Pablo González` | `GONZÁLEZ CASANOVA, Pablo` | ✅ + coquille `Cassanova` |
| 10442 | ES | `COLOMER, Eduardo Comin` | `COMÍN COLOMER, Eduardo` | ✅ + accent |
| 10582 | ES | `FERRER, Alejandro Tiana` | `TIANA FERRER, Alejandro` | ✅ |
| 10708 | ES | `IBÁÑES, Vicente Blasco` | `BLASCO IBÁÑEZ, Vicente` | ✅ + coquille `Ibáñes` |
| 10729 | AR | `JIMENEZ, Francisco Garcia` | `GARCÍA JIMÉNEZ, Francisco` | ✅ + accents |
| 10840 | MX | `MAGÓN, Ricardo Flores` | `FLORES MAGÓN, Ricardo` | ✅ **important** |
| 10866 | ES | `MARTÍNEZ, Beltrán Roca` | `ROCA MARTÍNEZ, Beltrán` | ✅ |
| 10901 | ES | `MIRAMAR, José Luis Carretero` | `CARRETERO MIRAMAR, José Luis` | ✅ |
| 10925 | ES | `MORYÓN, Félix García` | `GARCÍA MORYÓN, Félix` | ✅ |
| 11080 | MX | `RAMÍREZ, Manuel Gonzalez` | `GONZÁLEZ RAMÍREZ, Manuel` | ✅ + accent |
| 11128 | ES | `RUIZ, Benjamín Cano` | `CANO RUIZ, Benjamín` | ✅ |
| 10381 | ES | `CAJAL, Santiago Ramon y` | `RAMÓN Y CAJAL, Santiago` | ✅ cas `y` (règle 1.2.5) |
| 33 | UY | `MECHOSO, Juan Carlos` | — | ❌ **faux positif** (prénom composé) |
| 10070 | AR | `BORGES, Jorge Luis` | — | ❌ **faux positif** (prénom composé) |
| 10856 | MX | `MARCOS, Sous commandant insurgé` | `MARCOS, Subcomandante Insurgente` | ⚠️ qualificatif, pas un prénom |

> **Pourquoi une revue humaine est indispensable :** 3 faux positifs sur 22, soit
> 14 %. Aucune heuristique ne distingue `Juan Carlos Mechoso` (prénom composé) de
> `Juan Gómez Casas` (double patronyme). C'est la limite structurelle de
> l'automatisation sur ce point.

### A5 — Angle mort : le pays n'est pas renseigné

La détection A4 s'appuie sur `country`. Or **722 fiches sur 1 300 (55 %) ont
`country` à NULL**, et **441 fiches** ont une partie « prénoms » de plus d'un mot.
Autrement dit : les 22 signalements ci-dessus sont un **plancher**, pas un total.

**Séquence recommandée :** renseigner `country` (ou mieux, la langue du nom) →
rejouer la détection → revoir. Le pays peut être moissonné en masse depuis Wikidata
pour les autorités déjà appariées.

### A6 — Six collectivités logées dans `authors`

Faute de table d'autorité collectivité (décision **D7** ouverte dans
`spec-notice-autorite-enrichie` §7), six organisations sont enregistrées comme
personnes physiques, reconnaissables à `sort_name = preferred_name` :

| id | Nom | Nature |
|---|---|---|
| 10115 | `Confederación Nacional del Trabajo` | syndicat |
| 10175 | `CrimethInc.` | collectif d'édition |
| 10507 | `Le Monde Diplomatique` | périodique (≠ collectivité : c'est un **titre**) |
| 10724 | `Federação Anarquista do Rio de Janeiro` | organisation |
| 10791 | `Federación Ibérica de Juventudes Libertárias` | organisation |
| 11322 | `Centro de Cultura Libertária da Amazônia` | organisation |

Deux faux positifs dans le même filtre : `10065` (`SILVEIRA, Ênio`, cf. A1) et
`10111` (`Volin`, mononyme légitime).

> `Le Monde Diplomatique` en autorité est une erreur de nature : un périodique est
> une **œuvre**, pas un agent. À reclasser au moment du chantier collectivités.

### A7 — Dates : ce que la table ne sait pas dire

| | Effectif |
|---|---|
| Avec `birth_year` | 574 / 1 300 |
| Avec `death_year` | 442 / 1 300 |
| Sans date de naissance | **726 (56 %)** |

Le modèle actuel (deux entiers) ne distingue pas *« date inconnue »* de *« encore
vivant·e »*, et ne peut exprimer ni `ca. 1870`, ni `18..?`, ni *« actif·ve
1900-1910 »*. Or `spec-notice-autorite-enrichie` §1 pose que faire des autorités
libertaires correctes est un **acte de réparation historiographique** : les
compagnons dont les dates sont incertaines sont précisément ceux que les SIGB
institutionnels ont mal documentés. Le modèle doit pouvoir dire l'incertitude
plutôt que de la taire par un NULL.

→ Correctif retenu (CONV-5) : entiers conservés + colonne de qualificatif.

### A8 / A9 — Identifiants et formes variantes

| Champ | Rempli |
|---|---|
| `viaf_id` | 28 |
| `isni` | 23 |
| `wikidata_id` | 28 |
| `variant_forms` | 25 |

**~2 %.** Toute la couche autorité de `spec-sources-externes-autorites` §5 est
donc **spécifiée mais non alimentée**. C'est le principal travail de fond de
l'Atelier autorités — et c'est aussi ce qui rend la question des capitales
décisive : un point d'accès en capitales ne s'apparie pas à VIAF sans normalisation.

---

## B. Titres

### T1 — 216 titres capitalisent une conjonction ou une préposition

Signature d'un *title-casing* automatique passé sur un import. Aucune convention
ne le prescrit dans aucune langue :

- `Cinema E Anarquia` · `Arte E Anarquismo` · `Deus E O Estado`
- `Educación Libertaria Y Revolución Social` · `Amor Y Anarquia` · `Cine Y Anarquismo`
- `Viaje A Través de Utopía` · `El Quilombo De Los Palmares` · `Palabras De Un Rebelde`
- `A People's History Of The United States` (l'anglais lui-même veut `of the`)
- `Le Mouvement Anarchiste En France` · `L'affaire Sacco Et Vanzetti`
- `Gli Anarchismi. Una Breve Introduzione` · `La Miseria E I Delitti`

Répartition brute : **243** titres majoritairement capitalisés contre **406**
en casse de phrase — aucun régime dominant, deux imports superposés.

Cas particulier repéré : `Processo De Luis Xvi, O` — le title-casing a même
mangé le chiffre romain (`XVI` → `Xvi`).

### T2 — Titres en capitales intégrales (7)

Dont `2452` `BIOPODER E TECNOLOGIAS REPRODUTIVAS` et `2736`
`MOVIMENTO ANARCO-PUNK EM BELEM/PA` (ce dernier cumule capitales et perte de
diacritique : `BELEM` pour `Belém`).

### T3 — Dix titres à article rejeté en fin

Vestige de la fiche cartonnée, où l'article initial était renvoyé après le titre
pour permettre le classement alphabétique :

| id | Actuel | Rétabli |
|---|---|---|
| 68 | `Trabalhadores, Os` | `Os trabalhadores` |
| 667 | `Bomba, A` | `A bomba` |
| 690 | `Anarquistas Julgam Marx, Os` | `Os anarquistas julgam Marx` |
| 1134 | `Estado E Seu Papel Historico, O` | `O Estado e seu papel histórico` |
| 1173 | `Entresijos Del Anarquismo, Los` | `Los entresijos del anarquismo` |
| 1833 | `Moral Anarquista, A` | `A moral anarquista` |
| 1850 | `Processo De Luis Xvi, O` | `O processo de Luís XVI` |
| 1858 | `Princípio Anarquista e Outros Ensaios, O` | `O princípio anarquista e outros ensaios` |
| 1976 | `Reino De Deus Esta Em Vos, O` | `O reino de Deus está em vós` |
| 2061 | `Sociedade Contra O Estado, A` | `A sociedade contra o Estado` |

> **Ces dix fiches sont la preuve par l'exemple** qu'il faut traiter l'article
> non-classant comme une **propriété de tri** (`title_nonfiling`) et non en
> mutilant le titre. Sans ce champ, quelqu'un refera un jour la même chose.

### T4 — Douze titres dont le tiret de date a disparu

`(1868 1910)`, `1900 - 1930`, `1870 1937`… L'import a perdu le trait d'union.
Liste complète : `158`, `188`, `291`, `316`, `580`, `671`, `725`, `890`, `1062`,
`1357`, `1533`, `1564`. Correction mécanique sûre (`\d{4} \d{4}` → `\d{4}-\d{4}`).

### T5 — Sous-titres collés au titre

75 titres contiennent `:`, dont 3 seulement en ponctuation ISBD ` : `. Le champ
`subtitulo` existe pourtant et est rempli 1 030 fois sur 2 674. Exemples à trier :

- `Tolstói - A Biografia` → titre `Tolstói`, sous-titre `a biografia`
- `Estampas de la injusticia - la Guerra Civil del 36…`
- `Anarquismo: Uma Introdução Filosófica e Política`
- `Le Mouvement anarchiste en France - 2.` → mention de **volume**, pas sous-titre
- `Cadernos de formação:1 - Anarquismo e sindicalismo` → **collection + numéro**

⚠️ Cette famille **n'est pas mécanisable** : elle mélange sous-titres, mentions de
volume, numéros de collection et vrais titres à deux-points (`Brasil: nunca mais`).

### T6 — Diacritiques et casse cassés

`Trajetorias Historicas Da EducaÇao` · `Bourdieu E A EducaÇao` ·
`Concepçao Anarquista Do Sindicalismo` · `Da Escravidao Nos Estados Unidos` ·
`Um Pequeno Sim E Um Grande Nao` · `Teatro E Pulsao Anarquica` ·
`Semana Trágica: A Greve Geeral Anarquista de 1917` (coquille `Geeral`).

`EducaÇao` est instructif : le title-caser a capitalisé le `ç` **après** que le
`ã` a été perdu. Deux dégâts superposés, donc deux passes distinctes.

---

## C. Référentiels

### R1 — `country` : 47 valeurs pour ~40 pays

722 NULL. Codes ISO majoritaires (`BR` 107, `FR` 99, `US` 65, `ES` 48…) mais
libellés en clair résiduels : `España` (5), `Brasil` (4), `France` (3), `Russie` (1).
→ Normaliser en **ISO 3166-1 alpha-2**, `getCountryName()` existant fait déjà le rendu.

### R2 — `idioma` : 11 valeurs pour 8 langues

| Valeur | n | | Valeur | n |
|---|---|---|---|---|
| `Português` | 1 248 | | `pt-BR` | 23 |
| `Espanhol` | 605 | | `es` | 8 |
| `Francês` | 113 | | `fr` | 5 |
| `Inglês` | 107 | | `it` | 8 |
| `Italiano` | 81 | | `Esperanto` | 3 |
| `Alemão` | 2 | | **(null)** | **471** |

→ Normaliser en **BCP-47**. **C'est un prérequis dur** : la règle de casse des
titres (CONV-3) est pilotée par la langue du titre. Sans `idioma` fiable, elle
n'est pas applicable — et 471 notices (18 %) n'ont aucune langue.

---

## D. Ordre d'exécution recommandé

Les dépendances sont réelles, l'ordre n'est pas indifférent.

1. **R2 puis R1** — normaliser `idioma` et `country`. Prérequis de tout le reste.
   Mécanique, sans risque, réversible.
2. **T4, T3, T2** — artefacts d'import à correction sûre (34 notices). Mécanique.
3. **A1** — reconstruire `preferred_name` (70 fiches). Mécanique.
4. **A3** — suffixes de filiation (8 fiches). Mécanique, liste close ci-dessus.
5. **A2** — particules, en respectant la règle par aire linguistique (8 fiches
   fautives, 4 à ne surtout pas toucher).
6. **T1** — casse des titres, une langue à la fois, **après** R2. Relecture
   d'échantillon obligatoire avant passage en masse.
7. **A4** — double patronyme : **revue humaine fiche par fiche**, 22 signalements
   dont 3 faux positifs connus.
8. **A5** — renseigner `country`, rejouer A4, revoir le nouveau lot.
9. **T5, T6** — tri manuel, pas de passe automatique.
10. **A6, A7, A8, A9** — chantiers de modèle et d'Atelier, hors correctif.

---

## E. Ce que cet audit ne dit pas

- Il ne couvre **pas** le champ libre `books.autor`, qui coexiste toujours avec la
  table `authors` et porte les mêmes défauts en pire (`identificado, Não` pour
  « Não identificado », `GARCÍA, Luis Lamela`, `ARNS, Dom Paulo Evaristo`,
  `REICH, Hilhem` pour Wilhelm Reich, `Rosamund Bartlett (Org.)` avec la mention
  de rôle dans le nom). Sa résorption relève de **INV-4** (« autorités = entités
  liées, pas chaînes ») de `spec-notice-autorite-enrichie`.
- Il ne couvre **pas** les autorités matière, qui n'ont pas de table (D7).
- Les effectifs A4 sont un **plancher** (cf. A5).
- La détection T1 repose sur une liste finie de mots-outils : elle rate les
  titres en langues non couvertes et les mots-outils absents de la liste.
