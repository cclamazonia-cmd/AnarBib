---
Genre : référence
Statut : 🟡 cadrée
Décisions : incarne DOC-CONV-1 (REGISTRE §0) + CONV-1…CONV-7 et CONV-O1…O4 (REGISTRE §37) ; cite DOC-I18N-1, DOC-DEPLOY-1/3, DOC-ADDR-1, CAT-B1, CAT-D4/D6, INV-4, D7
Supersédé par : —
---

# 📐 spec-conventions-catalographiques

- **Version :** v0.1 — 20 août 2026
- **Statut :** 🟡 cadrée, non implémentée
- **Domaine :** conventions d'écriture des points d'accès (autorités) et des titres
- **Dépendances entrantes :**
  `spec-sources-externes-autorites` (couche autorité, `variant_forms`, CAT-D4/D6) ·
  `spec-notice-autorite-enrichie` (INV-4, D7) ·
  `spec-catalogacao-fiche-et-paliers` (champs et paliers de saisie) ·
  `REGISTRE_decisions.md` (DOC-I18N-1, DOC-DEPLOY-1/3, DOC-ADDR-1)
- **Dépendances sortantes :**
  `spec-catalogue-decouverte` (#OPAC10 parcours alphabétique) ·
  `spec-notice-autorite-enrichie` (#AUT3 exports, D2) ·
  tout futur chantier **Atelier autorités**
- **Rapport de constat associé :** `AUDIT_conventions_catalographiques_2026-08-20.md`

---

## 1. Pourquoi cette spec

AnarBib catalogue depuis deux ans sans convention écrite. Le résultat n'est pas
l'anarchie — c'est **la sédimentation silencieuse de conventions contradictoires**,
héritées d'imports successifs que personne n'a arbitrées. L'audit du 20/08 en
recense huit familles.

Le problème n'est pas esthétique. Une convention non écrite se réinvente à chaque
saisie, diverge entre bibliothèques du réseau, et rend impossible les deux choses
que le projet a déjà spécifiées :

- le **dédoublonnage fédéré** (deux biblios doivent pouvoir reconnaître qu'elles
  pointent la même autorité — `spec-sources-externes-autorites` §5.2) ;
- l'**appariement externe** VIAF / ISNI / Wikidata / BN Brasil, sur lequel repose
  toute la couche autorité (§5.1 de la même spec, aujourd'hui alimentée à 2 %).

Il y a aussi un enjeu politique, déjà posé par `spec-notice-autorite-enrichie` §1 :
les SIGB institutionnels ont mal documenté les compagnons du mouvement libertaire.
Écrire une convention, c'est se donner les moyens de *dire ce qu'on sait et ce
qu'on ignore* — au lieu de laisser un NULL décider à notre place.

**Contrainte de conception.** Les catalogueur·ses d'AnarBib ne sont ni
bibliothécaires ni informaticien·nes. Une convention qu'il faut avoir apprise pour
respecter est une convention qui ne sera pas respectée. **Toute règle de cette spec
doit donc être soit invisible (calculée), soit assistée (proposée et confirmée),
jamais un savoir préalable exigé à la saisie.** C'est le critère d'acceptation n°1
(§8).

---

## 2. La doctrine : trois plans, jamais confondus

C'est le principe unique dont découle tout le reste.

| Plan | Ce que c'est | Où ça vit | Exemple |
|---|---|---|---|
| **Donnée** | le fait documentaire | colonnes typées | `Reclus` · `Élisée` · `1830` · `1905` |
| **Tri / point d'accès** | la clé de classement et d'appariement | `sort_name`, `title_sort` | `Reclus, Élisée` |
| **Présentation** | ce que voit la lectrice | couche de rendu | `RECLUS, Élisée (1830-1905)` |

> **DOC-CONV-1 — Une seule vérité en base, plusieurs rendus.**
> La base ne stocke jamais une décision typographique. Les capitales, les
> parenthèses, le tiret de dates, la ponctuation ISBD sont **générés à
> l'affichage**. Corollaire : on ne concatène jamais une date dans une chaîne de
> nom, et on ne mutile jamais un titre pour le faire trier.

### 2.1 Ce que ça règle concrètement

La proposition intuitive `NOM, Prénom(s), 1923-1998` fusionne les trois plans dans
une chaîne. Elle est lisible, mais elle interdit ce qui suit :

- **apparier** avec VIAF/ISNI, qui écrivent `Reclus, Élisée` — la chaîne
  concaténée n'apparie rien sans normalisation à chaque appel ;
- **trier** proprement (une date au milieu d'une clé de tri est du bruit) ;
- **traduire l'affichage** (une biblio du réseau peut vouloir la forme directe) ;
- **dire l'incertitude** (`ca. 1870` dans une chaîne n'est plus une date).

MARC21 sépare d'ailleurs le nom (`100 $a`) des dates (`100 $d`) pour exactement
ces raisons. AnarBib fait déjà mieux que la chaîne : `birth_year` / `death_year`
sont des entiers. **Cet acquis ne doit pas être perdu.**

### 2.2 Le cas des capitales — pourquoi deux normes coexistent, légitimement

L'habitude brésilienne d'écrire `SOBRENOME, Nome` vient de la **NBR 6023**, norme
ABNT des *références bibliographiques* : c'est ce que tout le monde a appris à
l'école. Elle est parfaitement valide **dans son domaine**, qui est la citation.

Le **point d'accès de catalogue** relève d'une autre tradition (AACR2 / RDA,
appliquée par la BN Brasil comme par VIAF), qui écrit `Reclus, Élisée`.

Les deux ont raison, sur deux objets différents. D'où la résolution :

> **CONV-1.** Le point d'accès est stocké en **casse naturelle** (`Reclus, Élisée`).
> Les capitales du patronyme sont une **option d'affichage** de l'interface, et la
> forme ABNT `RECLUS, Élisée` est **générée** par le module d'export de citation.

Bénéfice latéral : ça donne son contenu à la décision ouverte **D2**
(`spec-notice-autorite-enrichie` §7, formats d'export). ABNT devient un format
d'export de première classe, aux côtés de BibTeX et RIS — et c'est le format que
les usagers brésiliens attendent réellement.

---

## 3. Autorités personne : où couper le nom

C'est le point délicat. Pas la casse — **l'élément d'entrée**.

### 3.1 La règle est linguistique, jamais universelle

L'import historique a appliqué « dernier mot = patronyme ». C'est faux pour les
deux populations les plus représentées dans un fonds anarchiste lusophone.

| Aire | Règle d'entrée | Exemple |
|---|---|---|
| **Portugais (BR/PT)** | **dernier** patronyme ; particules (`de`, `da`, `do`, `dos`, `e`) rejetées après les prénoms | `Fabiano de Oliveira Bringel` → `Bringel, Fabiano de Oliveira` |
| **Portugais — suffixes** | `Filho`, `Júnior`, `Neto`, `Sobrinho` **font partie du patronyme** | `Fábio Luz Filho` → `Luz Filho, Fábio` |
| **Espagnol** | **premier** patronyme ; les **deux** conservés | `Juan Gómez Casas` → `Gómez Casas, Juan` |
| **Espagnol — liaison `y`** | le `y` est intégré au composé | `Santiago Ramón y Cajal` → `Ramón y Cajal, Santiago` |
| **Français** | particule rejetée (`de`, `d'`), **sauf** article ou contraction (`Le`, `La`, `Du`, `Des`) | `Simone de Beauvoir` → `Beauvoir, Simone de` · `Charles Le Brun` → `Le Brun, Charles` |
| **Italien moderne** | particule **conservée** en entrée | `Edmondo De Amicis` → `De Amicis, Edmondo` |
| **Néerlandais** | entrée **après** le préfixe, sauf `Ver` | `Rudolf de Jong` → `Jong, Rudolf de` |
| **Afrikaans / Afrique du Sud** | préfixe **conservé** | `Lucien van der Walt` → `Van der Walt, Lucien` |
| **Allemand** | `von`, `zu` rejetés | `Max von Nettlau` → `Nettlau, Max von` |
| **Anglais** | dernier élément ; particules conservées si l'usage les porte | `Colin Ward` → `Ward, Colin` |

**Conséquence de modèle.** La règle applicable dépend de l'**aire linguistique du
nom**, pas du pays de naissance ni de la langue de l'ouvrage. Un `name_lang`
(BCP-47) sur l'autorité est donc nécessaire — c'est lui qui pilote l'assistant de
saisie (§7) et qui rend la règle *vérifiable*. `country` ne peut pas jouer ce rôle
(un Argentin peut porter un nom italien, cf. `Luis Di Filippo`).

### 3.2 Ordre d'écriture du point d'accès

```
sort_name = <élément d'entrée>, <reste des prénoms et particules rejetées>
```

Sans dates, sans qualificatif, sans capitales. `Bringel, Fabiano de Oliveira`.

### 3.3 Forme d'affichage

```
preferred_name = <prénoms> <élément d'entrée>
```

Forme directe, casse naturelle : `Fabiano de Oliveira Bringel`. Elle se **dérive**
de `sort_name` ; elle n'est saisie à la main que dans les cas irréguliers
(mononymes, pseudonymes, noms non occidentaux).

> **CONV-2.** `sort_name` est la vérité. `preferred_name` en est dérivé et peut
> être surchargé. L'inverse n'est jamais vrai.

---

## 4. Titres : la langue du titre décide

### 4.1 Le principe

ISBD et RDA reposent sur la **transcription** : on reprend le titre de la source,
et on normalise la casse selon **l'orthographe de la langue du titre lui-même**.
Il n'y a donc pas de « style maison » des titres — il y a autant de règles que de
langues, et c'est la donnée `idioma` qui les départage.

| Langue | Règle | Exemple |
|---|---|---|
| **pt · es · fr · it · ca** | casse de phrase : majuscule au premier mot et aux noms propres | `História do movimento macknovista` · `Le mouvement anarchiste en France` |
| **en** | *title case* : mots principaux capitalisés, articles / conjonctions / prépositions courtes en minuscules | `A People's History of the United States` |
| **de** | majuscule à tous les substantifs (orthographe allemande) | `Nationalismus und Kultur` |
| **eo** | casse de phrase | `La misio de Esperanto` |
| **nl · el** | casse de phrase | — |

> **Note.** L'intuition « majuscule aux substantifs, minuscule au reste » est
> l'orthographe **allemande**. Elle est juste — pour l'allemand. L'appliquer au
> portugais ou au français produirait une graphie que ni ISBD, ni l'ABNT, ni
> l'usage éditorial ne reconnaissent.

### 4.2 Ce qu'on ne fait jamais

- **Reprendre les capitales de la couverture.** La typographie de couverture est
  une décision graphique de l'éditeur, pas une donnée.
- **Capitaliser les mots-outils** (`E`, `Y`, `De`, `Of`, `The`…). 216 notices le
  font aujourd'hui — artefact d'un *title-casing* automatique.
- **Rejeter l'article en fin de titre** (`Moral Anarquista, A`). Vestige de la
  fiche cartonnée. Le classement est un problème de tri, pas de titre (§4.4).
- **Stocker la ponctuation ISBD.** Le ` : ` entre titre et sous-titre est
  **généré** ; `titulo` et `subtitulo` restent propres. Le générateur ISBD existe
  déjà (`buildIsbdStatement` / `buildIsbdZones`).

### 4.3 Titre, sous-titre, volume, collection

Quatre choses distinctes qui finissent aujourd'hui dans `titulo` :

| Cas rencontré | Découpage correct |
|---|---|
| `Tolstói - A Biografia` | `titulo` = `Tolstói` · `subtitulo` = `a biografia` |
| `Le Mouvement anarchiste en France - 2.` | `titulo` + mention de **volume** (`volume`) |
| `Cadernos de formação:1 - Anarquismo e sindicalismo` | **collection** + numéro + titre |
| `Brasil: nunca mais` | vrai deux-points d'auteur → **conserver tel quel** |

Ce tri **n'est pas mécanisable** — il demande de regarder la page de titre.
La spec pose la règle ; l'exécution est un travail de catalogage.

### 4.4 Article non-classant

`A revolução sexual` doit se classer à **R**, pas à **A**. Deux implémentations
possibles ; la seconde est retenue :

- ❌ mutiler le titre (`Revolução sexual, A`) — c'est ce qui a produit les 10 cas
  de l'audit T3 ;
- ✅ **`title_nonfiling` (smallint)** : nombre de caractères initiaux à ignorer au
  tri, exactement comme l'indicateur 2 de la zone MARC 245. `A revolução sexual`
  → `2`. Rempli par défaut à partir de la langue, surchargeable.

> **CONV-4.** Le titre n'est jamais altéré pour les besoins du classement.
> Le classement est porté par `title_nonfiling`.

Ça débloque directement le **parcours alphabétique #OPAC10** de
`spec-catalogue-decouverte`, qui sinon classera tous les ouvrages lusophones sous
A, O et As.

---

## 5. Dates : dire l'incertitude

### 5.1 Modèle retenu

`birth_year` / `death_year` restent des entiers. On ajoute un **qualificatif** :

| Colonne | Type | Valeurs |
|---|---|---|
| `birth_year_qualifier` | text + CHECK | `exact` · `circa` · `uncertain` · `unknown` |
| `death_year_qualifier` | text + CHECK | idem, + `living` |
| `activity_period` | text | libre et court : `ativo 1900-1910` |
| `dates_note` | text | note documentaire (source, désaccord entre sources) |

Convention `text` + CHECK plutôt qu'un enum PG, par cohérence avec **CAT-B1**.

### 5.2 Pourquoi pas EDTF

EDTF (ISO 8601-2, `1870~`, `18XX`, `1923/1998`) est plus rigoureux et
s'interopère nativement avec Wikidata. Il a été écarté pour v0.1 pour une raison
d'usage : il demande une grammaire à apprendre et un parseur à écrire, contre une
population de catalogueur·ses non-spécialistes (§1). Le modèle retenu couvre les
cas réels du corpus sans nouvelle syntaxe.

> **Porte laissée ouverte.** `exact`/`circa`/`uncertain`/`unknown` se projettent
> sans perte vers EDTF (`1870`, `1870~`, `1870?`, `∅`). Une bascule ultérieure est
> un mapping, pas une reprise. À rouvrir si le moissonnage Wikidata devient massif.

### 5.3 Rendu

| Cas | Affichage pt-BR |
|---|---|
| exact / exact | `(1830-1905)` |
| exact / living | `(n. 1953)` |
| circa / exact | `(c. 1870-1932)` |
| unknown / unknown + période | `(ativo 1900-1910)` |
| tout inconnu | rien — **pas de parenthèses vides** |

Le tiret est un **tiret demi-cadratin** (–), généré. Jamais stocké.

---

## 6. Les cas que le fonds impose

Un fonds militant n'a pas la même démographie d'autorités qu'une bibliothèque
universitaire. Ces quatre cas sont majoritaires chez nous et absents des manuels.

### 6.1 Mononymes

`Volin`, `Archinov`, `Marcos`. **Pas d'inversion, pas de virgule** :
`sort_name = preferred_name = Volin`. Le nom civil, s'il est connu, va en forme
variante — pas en point d'accès, sauf décision de l'Atelier.

### 6.2 Pseudonymes militants

`Florentino de Carvalho` (Primitivo Soares), `Neno Vasco`, `Victor Serge`
(Viktor Kibaltchitch), `Volin` (Vsevolod Eichenbaum).

**Règle : entrée à la forme la plus connue du mouvement**, renvoi depuis le nom
civil. Ce n'est pas une facilité — c'est un choix documentaire assumé : le nom
sous lequel quelqu'un a milité et publié est le nom sous lequel on le cherche.

Le nom civil est enregistré en forme variante avec un type explicite, jamais
écrasé ni omis (il porte souvent la seule trace d'une répression).

### 6.3 Translittérations

`Kropotkin` / `Kropotkine` / `Kropotkin, Piotr` / `Кропоткин` / `Peter Kropotkin`.
Une seule autorité, un point d'accès privilégié, **N formes variantes typées par
langue** — c'est exactement l'objet de `variant_forms` (CAT-D4), aujourd'hui
rempli à 2 %.

Forme privilégiée : celle de la **langue de base de l'instance** (pt-BR par
défaut), l'UI pouvant afficher la forme localisée (`spec-sources-externes-autorites`
§5.2).

Structure minimale proposée pour `variant_forms` :

```json
[
  { "form": "Kropotkine, Pierre", "lang": "fr",  "type": "translitteration" },
  { "form": "Кропоткин, Пётр",     "lang": "ru",  "type": "forme_originale" },
  { "form": "Kibaltchitch, Viktor", "lang": "ru", "type": "nom_civil" }
]
```

Types : `translitteration` · `forme_originale` · `nom_civil` · `pseudonyme` ·
`forme_developpee` · `forme_abregee`.

### 6.4 Collectivités

Six organisations sont aujourd'hui logées dans `authors` faute de table dédiée
(audit A6). Conventions proposées, à confirmer au chantier **D7** :

- **Forme développée** telle qu'elle se nomme elle-même :
  `Confederación Nacional del Trabajo`, pas `CNT`.
- **Sigle en forme variante**, jamais en point d'accès — c'est le sigle qu'on
  tape, mais c'est le nom développé qui désambiguïse (`FAU` est à la fois
  uruguayenne et brésilienne).
- **Pas de hiérarchie à la LC** (`Espagne. Ministère de…`). Une fédération
  anarchiste n'a pas de structure de subordination administrative, et lui en
  imposer une en catalogage serait une contradiction dans les termes. Le lien
  entre organisations relève de la **cartographie réseau**, pas du point d'accès.
- **Pas d'inversion, pas de capitales.**
- Un périodique (`Le Monde Diplomatique`) n'est **pas** une collectivité : c'est
  une œuvre. À reclasser.

---

## 7. Mise en œuvre côté saisie

Le principe de §1 — invisible ou assisté, jamais exigé — se décline ainsi.

### 7.1 Assistant de découpage du nom

À la saisie d'une nouvelle autorité, la catalogueuse tape le nom **comme elle le
dit** : `Fabiano de Oliveira Bringel`. L'assistant propose :

```
Ponto de acesso proposto :  Bringel, Fabiano de Oliveira
Exibição :                  Fabiano de Oliveira Bringel
                            [ Confirmar ]  [ Corrigir ]  [ É pseudônimo / nome único ]
```

Trois exigences non négociables :

1. **Proposer, jamais imposer.** Le découpage automatique se trompe 14 % du temps
   sur le corpus réel (audit A4). Un bouton « Corrigir » qui laisse choisir
   l'élément d'entrée mot par mot est indispensable.
2. **Expliquer en une ligne**, dans la langue de l'interface : *« Em português, a
   entrada é pelo último sobrenome. »* La règle s'apprend en catalogant, pas avant.
3. **Ne jamais bloquer.** Un avertissement doux, jamais une validation dure. Une
   biblio militante ne peut pas se permettre qu'une fiche ne parte pas parce
   qu'une règle de catalogage n'est pas satisfaite.

### 7.2 Normalisation de casse des titres

Bouton **« Normalizar maiúsculas »** à côté du champ titre, actif seulement si la
langue est renseignée, avec **aperçu avant / après** et annulation. Jamais
automatique à la frappe : un titre peut légitimement contredire la règle
(`bell hooks`, titres typographiquement composés, sigles).

### 7.3 Contrôles de cohérence en arrière-plan

Sans bloquer, alimentant une file de vérification pour l'Atelier :

- point d'accès commençant par une particule alors que `name_lang` la rejette ;
- point d'accès commençant par `Filho` / `Júnior` / `Neto` / `Sobrinho` ;
- `preferred_name` contenant une virgule ;
- titre contenant un mot-outil capitalisé pour sa langue ;
- titre finissant par `, O` / `, A` / `, Los`… ;
- `idioma` ou `country` hors référentiel.

### 7.4 Palier de saisie

Rien de tout ceci n'ajoute de champ au palier **Simples** : l'assistant travaille
sur les champs existants. `name_lang`, les qualificatifs de date et
`title_nonfiling` apparaissent au palier **Avançado**, et sont **calculés par
défaut** partout ailleurs. Conforme à `spec-catalogacao-fiche-et-paliers` §4.

---

## 8. Critères d'acceptation

1. **Aucune règle de cette spec n'exige un savoir préalable à la saisie.** Chaque
   règle est soit calculée, soit proposée avec explication d'une ligne.
2. Chaque règle est **testable** par une requête SQL — les requêtes de l'audit
   deviennent la suite de tests de non-régression.
3. Le rendu (`RECLUS, Élisée (1830-1905)`) est produit par **une** fonction, côté
   frontend, et par **aucune** donnée stockée.
4. L'export ABNT produit `RECLUS, Élisée` sans que la base contienne de capitales.
5. Le parcours alphabétique #OPAC10 classe `A revolução sexual` à **R**.
6. Une autorité peut exprimer *« né vers 1870, mort à une date inconnue »* sans
   NULL muet.

---

## 9. Décisions

Portées au registre **§37 `CONV`** (`CONV-1` à `CONV-7`, points ouverts `CONV-O1…O4`), la
doctrine `DOC-CONV-1` étant inscrite en **§0** parmi les doctrines transverses. *(Le cadrage
visait « §17 » : créneau déjà occupé par `IMP` depuis le 05/06 — `#HYG-REG-1` s'applique,
les sections nouvelles prennent les numéros suivants.)*

| ID | Décision | Statut |
|---|---|---|
| **DOC-CONV-1** | Une seule vérité en base, plusieurs rendus | ✅ acté 20/08 |
| **CONV-1** | Point d'accès en casse naturelle ; capitales à l'affichage ; ABNT à l'export | ✅ acté 20/08 |
| **CONV-2** | `sort_name` fait foi, `preferred_name` en dérive | ✅ acté 20/08 |
| **CONV-3** | Casse des titres pilotée par la langue du titre | ✅ acté 20/08 |
| **CONV-4** | Article non-classant porté par `title_nonfiling`, jamais par mutilation | ✅ acté 20/08 |
| **CONV-5** | Dates = entiers + qualificatif ; EDTF différé mais compatible | ✅ acté 20/08 |
| **CONV-6** | `name_lang` (BCP-47) sur l'autorité pilote la règle d'entrée | 🟡 à confirmer |
| **CONV-7** | Normalisation `idioma` (BCP-47) et `country` (ISO 3166-1 α-2) = **prérequis dur** | ✅ acté 20/08 |

### Points ouverts

- **CONV-O1** — Faut-il un `name_lang` distinct de `country` ? (recommandé : oui,
  cf. §3.1 ; coût : une colonne + un moissonnage.)
- **CONV-O2** — Conventions collectivités : à confirmer avec **D7**
  (`spec-notice-autorite-enrichie`). Cette spec ne fait que proposer.
- **CONV-O3** — Le champ libre `books.autor` doit-il être déprécié maintenant ou
  au chantier Atelier ? (INV-4 le prescrit ; l'audit §E montre qu'il porte les
  mêmes défauts en pire.)
- **CONV-O4** — Bascule EDTF : critère de déclenchement à définir.

---

## 10. Périmètre exclu

- Les autorités **matière** (pas de table — D7).
- Les vedettes de **collection** et les titres uniformes.
- La classification (CDD) et l'indexation matière.
- La résorption du champ libre `books.autor` (CONV-O3).
- L'exécution des corrections : elle relève du script de migration
  `20260820T*_conventions_*.sql`, **non appliqué**, à passer par
  `git push` → Woodpecker conformément à **DOC-DEPLOY-1**.
