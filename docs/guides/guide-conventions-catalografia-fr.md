# Fiche — Écrire un nom, écrire un titre

> **À qui s'adresse cette fiche.** À toi qui catalogues. Elle rassemble ce qui se
> décide au moment de saisir : comment s'écrit un nom, où couper une particule,
> ce qu'on fait d'une collectivité, et pourquoi un champ vide vaut mieux qu'un
> champ deviné.
>
> Le *pourquoi* détaillé est ailleurs, dans le registre des décisions, section
> `CONV`. Ici, on saisit.

## La règle, en une phrase

**Une seule vérité en base, plusieurs rendus.** Tu saisis la forme de
catalogage ; les capitales, l'ordre prénom-nom et les mises en forme
bibliographiques sont **calculés** à l'affichage et à l'export. Ne les saisis
jamais à la main.

C'est de là que vient tout le désordre qu'on répare depuis deux jours : le
point d'accès, la forme d'affichage et la forme d'export ont été logés **dans
la même case**, à des moments différents, par des mains différentes.

---

## 1. Le nom d'une personne

### La forme de tri fait foi

Le champ **« Forme de tri »** est la vérité. La **« Forme standard »** en
dérive automatiquement, par simple inversion de la virgule. Jamais l'inverse.

| Tu écris dans « Forme de tri » | L'app affiche |
|---|---|
| `Kropotkine, Pierre` | Pierre Kropotkine |
| `Malatesta, Errico` | Errico Malatesta |

### Casse naturelle, jamais de capitales

**`Kropotkine, Pierre` — jamais `KROPOTKINE, Pierre`.**

Les capitales du patronyme sont une **norme de référence bibliographique**
(ABNT), pas une donnée. Elles sont ajoutées à l'export, à la volée. Les taper
toi-même ne les rend pas plus vraies : ça détruit l'information de casse, qui
ne se reconstitue pas ensuite — `de Sousa` et `De Sousa` ne sont plus
distinguables une fois tout en capitales.

### Où couper : la particule

**C'est la langue du NOM qui décide, pas le pays de naissance.** Un·e
Argentin·e peut porter un nom italien.

| Langue du nom | La particule… | Exemple |
|---|---|---|
| portugais, français | **se rejette** après le prénom | `Sousa, Manuel Joaquim de`<br>`Beauvoir, Simone de`<br>`Jong, Rudolf de` |
| italien moderne, afrikaans, néerlandais | **se conserve** devant | `Di Filippo, Luis`<br>`De Amicis, Edmondo`<br>`Van der Walt, Lucien` |

Luis Di Filippo est le cas d'école : argentin, nom italien, donc `Di Filippo,
Luis` — et non `Filippo, Luis Di`.

### Ce que l'outil ne sait pas décider

**Double patronyme ou prénom composé ?** `García Lorca` est un double
patronyme espagnol (on ne coupe pas) ; `Jean-Marie` est un prénom composé.
Aucune fonction ne fait la différence. En cas de doute, **demande** plutôt que
de trancher : c'est exactement ce genre de cas qui part en file de
vérification.

---

## 2. Une collectivité n'est pas une personne

**Un nom de collectif n'a pas de forme inversée.**

| ✅ | ❌ |
|---|---|
| `Grupo Krisis` | `Krisis, Grupo` |
| `Instituto de Estudos Libertários` | `Libertários, Instituto de Estudos` |
| `CIRA Marseille` | `Marseille, CIRA` |

### Renseigne « Type d'autorité »

Le champ existe et il **pilote la règle**. Mis sur *Collectivité*, il empêche
l'inversion. Laissé vide, rien ne protège la fiche : elle sera traitée comme
une personne au premier passage d'outillage.

C'est un champ de trois secondes qui évite une correction de trois mois.

### Si la fiche contient PLUSIEURS personnes

Ça arrive — l'import en a fabriqué. `KAISER, William Young and David E.` n'est
pas un Kaiser à deux prénoms : c'est **William Young** *et* **David E.
Kaiser**, deux auteurs d'un même livre.

**Ne le répare pas sur place.** Une fiche d'autorité est partagée par tout le
réseau : la renommer ne fait que déplacer l'erreur. Passe par l'Atelier des
autorités, proposition de type **Scission** : la fiche d'origine est conservée,
les autres sont créées, et les liens vers les livres suivent. Délai de
délibération : quatorze jours, comme une fusion.

---

## 3. Le titre

### La casse dépend de la langue du titre

Il n'y a **pas** de règle universelle. L'allemand capitalise ses substantifs :
c'est son **orthographe**, pas une faute de saisie.

L'outil de normalisation n'abaisse que les **mots-outils de la langue du
titre**, en position non initiale. Il préserve :

- le **premier mot** ;
- les mots après une **ponctuation forte** (`.` `:` `;` `?` `!` et le tiret de
  sous-titre) ;
- les **sigles**.

**Il retire un artefact d'import, il ne « recasse » pas le titre.** Quand il te
propose une correction, tu restes seul·e juge de savoir si un mot est un nom
propre — l'outil, lui, ne le sait pas.

| Avant | Après |
|---|---|
| `Antologia Do Movimento Operário Gaúcho` | `Antologia do Movimento Operário Gaúcho` |
| `Der Einzige Und Sein Eigentum` | `Der Einzige und sein Eigentum` |

### L'article initial : ne mutile jamais le titre

`Os Trabalhadores` s'écrit **`Os Trabalhadores`**. Pas `Trabalhadores, Os` —
c'est un vestige de la fiche cartonnée — et pas `Trabalhadores` tout court.

Le classement se règle par un **compteur de caractères non classants** (ici :
3, pour `Os `), qui laisse le titre intact.

---

## 4. La langue et le pays

| Champ | Format | Exemples |
|---|---|---|
| **Langue** (du document) | code BCP-47 | `pt-BR`, `fr`, `es`, `de`, `it` |
| **Pays** (de l'autorité) | code ISO 3166-1 α-2 | `BR`, `FR`, `ES`, `NL` |

Pas `português`, pas `Brasil`, pas `bra`. Le sélecteur de l'app te donne le bon
code : sers-t'en plutôt que de taper.

**Un NULL reste un NULL.** Si tu ne connais pas la langue, laisse vide. Une
langue inconnue est une information honnête ; une langue fausse pilote ensuite
la casse du titre et la règle d'entrée du nom — elle propage l'erreur au lieu
de la contenir.

---

## 5. Les dates

Deux entiers et un **qualificatif** :

| Qualificatif | Quand |
|---|---|
| `exact` | la date est établie |
| `circa` | approximative (« vers 1876 ») |
| `uncertain` | les sources divergent |
| `unknown` | on ne sait pas |
| `living` | **la personne est vivante** |

`living` n'est pas un détail de confort : sans lui, « encore vivant·e » et
« date de mort inconnue » se confondaient — ce qui revenait à faire mourir des
gens dans le catalogue.

Quand naissance et mort sont toutes deux inconnues, utilise la **période
d'activité** (« actif·ve 1900-1910 »). Et quand les sources se contredisent,
écris-le dans la **note de dates** : c'est une réparation historiographique,
pas du remplissage.

---

## 6. Ce qui n'est pas à toi de trancher seul·e

Le corpus d'autorités est **partagé par tout le réseau**. Modifier une fiche,
c'est modifier le catalogue de plusieurs bibliothèques.

| Geste | Où ça se passe |
|---|---|
| corriger une coquille sur une fiche | directement |
| **fusionner** deux fiches en doublon | Atelier — proposition, 14 jours |
| **scinder** une fiche qui en contient deux | Atelier — proposition, 14 jours |
| trancher une casse ou un patronyme proposé par l'outil | file de vérification |

Dans l'Atelier, une proposition reste ouverte le temps que les autres
bibliothèques puissent objecter. Ce délai n'est pas une lenteur administrative :
c'est ce qui fait que le corpus reste commun.

---

## En cas de doute

**Laisse vide plutôt que de deviner.**

Un champ vide pose une question — quelqu'un la verra et y répondra. Un champ
faux répond à une question que personne n'a posée, et il a l'air juste. C'est
lui qu'on retrouve trois mois plus tard, recopié dans cinq catalogues.
