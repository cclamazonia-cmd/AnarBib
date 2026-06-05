# Charte de langage inclusif d'AnarBib

**Version** : 2.0
**Date** : 2026-06-05
**Statut** : référence du projet (source unique d'autorité)
**Remplace** : `anarbib-charte-langage-inclusif-v1.md` (v1.0, 2026-04-28), désormais **dépréciée**

Ce document fixe les conventions de langage inclusif adoptées dans les **dix
locales** d'AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`,
`el`). Il s'applique à toute traduction nouvelle, à toute relecture, et à toute
contribution future. Il est destiné aux personnes qui contribuent aux fichiers
`src/i18n/locales/*.json`, aux chaînes des notifications mail
(`supabase/functions/_shared/i18n/mail-strings.ts`), et à toute traduction
générée par la suite.

> **Évolution depuis la v1** : la v1 ne couvrait que six locales (`pt-BR`, `fr`,
> `es`, `en`, `it`, `de`). La v2 ajoute `ca`, `eo`, `nl`, `el`, et **officialise
> la convention italienne** (astérisque pour les paires régulières, slash pour
> les paires irrégulières) qui remplace le slash provisoire de la v1.

---

## Sommaire

1. [Pourquoi ce document](#pourquoi-ce-document)
2. [Principe directeur : cohérence interne par langue](#principe-directeur--cohérence-interne-par-langue)
3. [Tableau des statuts](#tableau-des-statuts)
4. [Charte par langue](#charte-par-langue)
   - [Français (fr)](#français-fr)
   - [Allemand (de)](#allemand-de)
   - [Anglais (en)](#anglais-en)
   - [Portugais brésilien (pt-BR)](#portugais-brésilien-pt-br)
   - [Espagnol castillan (es)](#espagnol-castillan-es)
   - [Italien (it)](#italien-it)
   - [Catalan (ca)](#catalan-ca)
   - [Espéranto (eo)](#espéranto-eo)
   - [Néerlandais (nl)](#néerlandais-nl)
   - [Grec (el)](#grec-el)
5. [Termes politiques de référence](#termes-politiques-de-référence)
6. [Termes proscrits](#termes-proscrits)
7. [Procédure pour les ajouts futurs](#procédure-pour-les-ajouts-futurs)
8. [Couverture des tests (CI)](#couverture-des-tests-ci)
9. [Évolution de la charte](#évolution-de-la-charte)

---

## Pourquoi ce document

AnarBib est un système intégré de gestion de bibliothèques pensé pour les
bibliothèques militantes anarchistes. Une bibliothèque militante n'est pas une
bibliothèque comme les autres : elle n'archive pas seulement des documents, elle
constitue **une mémoire collective**, et le langage de son interface fait partie
de cette mémoire. Une interface qui parle de « lecteur » au masculin générique
reproduit le geste d'effacement qu'une bibliothèque féministe ou queer cherche
précisément à défaire ; une interface qui dit « compagn·e·s » signale dès la
première seconde à quel mouvement elle appartient.

Mais le langage inclusif n'est pas une norme universelle. Chaque langue a sa
propre histoire, ses propres conventions militantes, ses propres terrains
politiques minés. **Il n'existe pas de « bonne » écriture inclusive
transversale** : il existe des choix locaux situés, défendus par des communautés
militantes situées. Cette charte respecte ces situations locales tout en
garantissant qu'à l'intérieur d'une même langue, AnarBib parle d'une seule voix.

Trois objectifs concrets :

1. **Cohérence**. À l'intérieur d'un même fichier de locale, la même position de
   genre s'écrit toujours de la même façon.
2. **Respect des cultures militantes locales**. Pas d'imposition d'une convention
   d'une langue à une autre.
3. **Lisibilité par non-spécialistes**. Une bibliothécaire militante qui découvre
   AnarBib doit pouvoir s'en servir sans être experte en typographie inclusive.

---

## Principe directeur : cohérence interne par langue

Chaque langue d'AnarBib applique **sa propre convention typographique d'écriture
inclusive**, héritée de l'usage militant local. Aucune convention transversale
n'est imposée.

À l'intérieur d'une langue, **ces conventions sont obligatoires et exclusives** :
un fichier `fr.json` ne mélange pas le médian avec des `(e)` ; un fichier
`it.json` ne mélange pas l'astérisque avec le point médian. Les choix faits dans
cette charte sont la **forme officielle** d'AnarBib pour cette langue.

---

## Tableau des statuts

| Locale | Convention | Statut |
|---|---|---|
| `pt-BR` | Forme triple `(o/a/e)` | **Adoptée** (référence) |
| `fr` | Point médian `·` | **Adoptée** |
| `es` | `e` neutre (convention argentine) | **Adoptée** |
| `en` | Épicène + `they` singulier | **Adoptée** |
| `de` | Genderstern `*` | **Adoptée** |
| `it` | Astérisque (réguliers) / slash (irréguliers) | **Adoptée** |
| `ca` | Terminaison triple `-a-e` + article `le` | **Adoptée** |
| `eo` | Infixe `-in-` visibilisé par tirets + pronom `ri` | **Adoptée** |
| `nl` | Formes de rôle neutres | **Provisoire** — à valider en communauté |
| `el` | — | **À définir** avec une personne locutrice grecque militante |

---

## Charte par langue

### Français (fr)

**Convention adoptée** : point médian (`·`, U+00B7).

**Forme générique** : racine commune + point médian + terminaison féminine.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Pluriel** : on ajoute `·s` (`lecteur·rice·s`).
**Articles / déterminants combinés** : `le·la`, `du·de la`, `au·à la`, `un·e`,
`le·la SEUL·E`, `actif·ve`.
**Mots déjà épicènes** : inchangés (`bibliothécaire`, `camarade`, `responsable`,
`personne`).
**Proscrit** : `(e)`, `-e` séparé (conventions pré-2010), point ordinaire `.` ou
puce `•` à la place du médian.

### Allemand (de)

**Convention adoptée** : Genderstern (`*`, astérisque ASCII U+002A).

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Pluriel** : `*innen` (`Genoss*innen`, `Leser*innen`).
**Proscrit** : Mediopunkt `·`, Genderdoppelpunkt `:innen`, et le néologisme
hispanophone *« Compas »* laissé non traduit (toujours `Genoss*in`/`Genoss*innen`).

### Anglais (en)

**Convention adoptée** : termes épicènes par défaut, `they/them/their` au
singulier comme pronom neutre.

La grammaire anglaise est largement épicène : on utilise systématiquement la
forme neutre existante (`reader`, `librarian`, `author`, `administrator`,
`comrade`, `coordinator`, `user`), sans marquage typographique. Pour les rares
termes genrés, on choisit la forme épicène (`actor` plutôt qu'`actress`,
`server` plutôt que `waitress`).
**Proscrit** : `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Portugais brésilien (pt-BR)

**Convention adoptée** : forme triple `(o/a/e)` ou `(a/e)` selon la grammaire,
incluant explicitement les trois positions (féminin, masculin, non-binaire).
**C'est la locale de référence du projet.**

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Règle** : mots en `-or` → `(a/e)` ; mots en `-o` → `(o/a/e)`. Terminaisons par
ordre alphabétique dans la parenthèse.
**Contractions article-préposition** : `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`,
`(o/a/e)s`.
**Mots déjà épicènes** : inchangés (`camarada`, `colega`, `responsável`,
`pessoa`).
**Proscrit** : `(a)` seul, `/a`, `/o`, `@` (arroba), `x`. Attention au
**faux ami `camarade`** (forme française) : en pt-BR, c'est **`camarada`**.

### Espagnol castillan (es)

**Convention adoptée** : `e` neutre (convention argentine militante).

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Règle** : on remplace la voyelle de genre finale (`-o`/`-a`) par `-e` ; mots en
`-or` → racine + `-e` (`lector → lectore`).
**Pluriel** : `-s` (`compañeres`).
**Articles / déterminants** : `le` (singulier neutre), `les` (pluriel neutre).
**Participes accordés** : `informade`, `conectade`, `active`.
**Mots déjà épicènes** : inchangés (`camarada`, `colega`, `responsable`,
`persona`).
**Proscrit** : `(a)`, `/a`, `/o`, **la forme triple `(o/a/e)` du pt-BR**
(l'espagnol n'utilise QUE le `e` neutre), `@` (arroba), `x` (Latinx), et le
**point médian `·`** (convention française, à ne pas employer en espagnol).

### Italien (it)

**Convention adoptée — officielle** : **astérisque `*` pour les paires
régulières, slash abrégé pour les paires irrégulières.** Cette convention
remplace le slash provisoire de la v1.

#### Paires régulières (racine commune en `-o`/`-a`) → astérisque `*`

Quand le masculin et le féminin partagent la **même racine**, on remplace la
terminaison de genre par un astérisque, par cohérence avec le Genderstern
allemand.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(déjà épicène au sing.)* |

S'applique aussi aux **participes et adjectifs accordés** : `stat*` (stato/a),
`ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a),
`benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*`
(questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Paires irrégulières (racines différentes, type `-tore`/`-trice`) → slash abrégé

Quand le féminin ne partage pas la racine du masculin (`lettore` → `lettric-e`),
l'astérisque est **fautif** (`lettor*` laisserait entendre un féminin inexistant
`lettora`). On emploie donc la **forme slash abrégée**, qui est le *house style*
attesté dans le dépôt.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Pluriel irrégulier** : `lettori/trici`, `amministratori/trici`,
`coordinatori/trici`.
**Articles** : `il/la`, `del/la`, `al/la`, `dal/la` (forme abrégée), `un*` pour
`uno/una`.
**Mots déjà épicènes** : inchangés (`utente`, `responsabile`, `persona`,
`collega`).

#### Point sur le caractère `·`

Le point médian `·` n'est **pas** un marqueur inclusif en italien : il sert
uniquement de **séparateur typographique** dans les sujets de mail et les lignes
de métadonnées (`Email · ID · Genere`). Ne jamais l'employer pour marquer le
genre.

**🚫 Proscrit absolu** : **`camerata` / `camerati` / `cameratesco`** — adresse
interne fasciste (PNF, MSI, CasaPound, Forza Nuova, FdI). Utiliser `compagn*` et
ses variantes. **Cette proscription est testée en CI** (`i18n.test.js` et
`mail-strings.test.ts`).
**Autres formes proscrites** : `(a)`/`(o)` parenthèses, triple `/trice/e`, suffixe
`/x`, point médian `·` comme marqueur de genre.

**Justification militante** : l'astérisque (*asterisco*) est attesté dans les
milieux anarchistes et autonomes italophones (Carmilla, DinamoPress, InfoAut,
Wu Ming), et offre la cohérence visuelle avec le Genderstern allemand. Le slash
abrégé pour les paires irrégulières évite les féminins fautifs tout en restant
lisible.

### Catalan (ca)

**Convention adoptée** : terminaison triple suffixe `-a-e` + article neutre `le`.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Variante parenthésée** acceptée pour les contractions :
`lector(a/e)`, `coordinador(a/e)`.
**Déterminant neutre** : `le` (`le lector-a-e`).
**Pluriel** : `-s` ou forme combinée `els-les-les` / `als-a les-a les`.
**Mots déjà épicènes** : inchangés.

> Le catalan emploie aussi le point volat `·` dans la **géminée `l·l`**
> (`col·lectiu`, `cancel·lada`, `sol·licitud`) : c'est une **graphie standard du
> catalan**, sans rapport avec l'inclusivité. Ne pas la modifier.

### Espéranto (eo)

**Convention adoptée** : infixe `-in-` visibilisé par des tirets + pronom neutre
`ri`.

| Base | Forme AnarBib |
|---|---|
| leganto (lecteur·rice) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Variante non-binaire** : suffixe `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Pronom neutre** : `ri`.
**Pluriel** : `-j` (`legant-in-oj`).

### Néerlandais (nl)

**Statut : PROVISOIRE — à valider en communauté.**

**Orientation provisoire** : privilégier les **formes de rôle neutres**
existantes plutôt qu'un marquage typographique.

| Concept | Forme provisoire |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Règles provisoires** : éviter les suffixes genrés `-ster`/`-e` quand une forme
neutre existe ; pronom non-binaire `die` (ou `hen`/`hun`) — **usage non encore
arrêté**.

> ⚠️ Cette convention n'est **pas** définitive. Elle doit être validée par des
> locuteur·rices néerlandophones militant·es avant d'être figée. En attendant,
> rester sur les formes neutres.

### Grec (el)

**Statut : CONVENTION À DÉFINIR.**

Il n'existe **pas de standard typographique consensuel** pour l'écriture
inclusive en grec. **Ne pas proposer de marqueur d'office.** La convention sera
arrêtée **avec une personne locutrice grecque militante** rejoignant le projet.

**Approche transitoire** (en attendant) : doublets ou formes neutres existantes
(`αναγνώστης/στρια`, `συντονιστής/στρια`), grec monotonique, 2ᵉ personne du
singulier pour le tutoiement lecteur·rice (vouvoiement pour l'équipe). Sigle
RGPD → `ΓΚΠΔ`.

> ⚠️ Toute proposition de marqueur typographique inclusif systématique pour le
> grec est **prématurée** tant qu'aucun relais hellénophone militant n'a rejoint
> le projet.

---

## Termes politiques de référence

### Camarade / Compagn·e

| Langue | Forme officielle | Pluriel |
|---|---|---|
| 🇫🇷 fr | `camarade` *(épicène)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(épicène)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(épicène)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagn*` | `compagn*` |
| ca | `camarada` *(épicène)* | `camarades` |
| eo | `kamarad-in-o` | `kamarad-in-oj` |
| nl | `kameraad` *(provisoire)* | `kameraden` |
| el | `σύντροφος` *(à confirmer)* | — |

### Lecteur·rice

| Langue | Forme officielle |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/trice` |
| ca | `lector-a-e` |
| eo | `legant-in-o` |
| nl | `lezer` *(provisoire)* |
| el | `αναγνώστης/στρια` *(transitoire)* |

### Bibliothécaire

| Langue | Forme officielle |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(épicène)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecari*` |
| ca | `bibliotecari-ària-e` |
| eo | `bibliotekist-in-o` |
| nl | `bibliothecaris` *(provisoire)* |
| el | `βιβλιοθηκάριος` *(à confirmer)* |

### Administrateur·rice

| Langue | Forme officielle |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/trice` |
| ca | `administrador-a-e` |
| eo | `administrant-in-o` |
| nl | `beheerder` *(provisoire)* |
| el | *(à définir)* |

---

## Termes proscrits

### Politiquement marqués (proscription absolue)

| Terme | Langue | Raison |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Adresse interne fasciste (PNF, MSI, CasaPound, Forza Nuova, FdI). **Testé en CI.** |
| `Compas` *(non traduit)* | 🇩🇪 de | Néologisme hispanophone laissé tel quel — utiliser `Genoss*in`/`Genoss*innen`. |

### Conventions typographiques bureaucratiques ou inadaptées

| Forme | Langues concernées | Pourquoi |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Forme administrative, non militante. |
| `@` (arroba) | pt-BR, es | Obsolète, problème d'accessibilité (lecteurs d'écran). |
| `x` (Latinx) | es, pt-BR | Supplantée par `e` neutre dans l'usage militant contemporain. |
| `(e)`, `-e` séparé | fr | Convention pré-2010, remplacée par le médian. |
| `Genderdoppelpunkt` (`:innen`) | de | Valable mais non retenue par cohérence avec `*`. |
| `he/she`, `s/he`, `(s)he` | en | Préférer `they/them` singulier. |
| Triple `(o/a/e)` | es | Réservé au pt-BR ; l'espagnol n'utilise que le `e` neutre. |
| Point médian `·` comme marqueur de genre | es, it, ca | Convention française ; ailleurs, `·` n'est qu'un séparateur (ou la géminée `l·l` en ca). |
| Triple `/trice/e`, suffixe `/x` | it | Formes malformées ; utiliser slash abrégé `/trice`. |

---

## Procédure pour les ajouts futurs

### Quand on ajoute une nouvelle clé i18n

1. **Identifier** le mot/expression à traduire. S'agit-il d'un terme à genrer ?
2. **Si oui, choisir la forme épicène quand elle existe** (`camarada` pt-BR,
   `responsable` fr, `utente` it…).
3. **Sinon, appliquer la convention de la langue** définie ci-dessus.
4. **Pour l'italien** : distinguer paire régulière (astérisque) et paire
   irrégulière (slash abrégé).
5. **Vérifier la cohérence** avec le reste du fichier.
6. **Renseigner les 10 locales en une seule passe.** Une clé partiellement
   traduite est un bug. La **parité des clés** entre les 10 locales est
   obligatoire.

### Quand on relit une traduction existante

1. Repérer les marqueurs **proscrits** (`(a)`, `@`, `camerata`, point médian hors
   fr/ca-géminée, triple `/trice/e`…).
2. Les remplacer par la forme officielle de la langue.
3. Vérifier la cohérence singulier/pluriel.
4. Vérifier la cohérence inter-locales pour la même clé.

### Quand on demande une traduction à une IA

Toujours fournir cette charte en contexte, préciser la convention attendue pour
la langue cible et les termes proscrits, privilégier les formes épicènes, et
**vérifier le résultat** avant intégration.

---

## Couverture des tests (CI)

- `src/tests/i18n.test.js` teste la **parité des clés** et la **conformité** de
  **8 locales** : `pt-BR, fr, en, de, it, es, ca, eo`. Il inclut le test bloquant
  « l'italien ne doit jamais contenir camerata/camerati ».
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) teste les
  chaînes mail : parité, termes proscrits (camerata), interpolation, fallback.
- ⚠️ **`nl` et `el` ne sont PAS couverts par le gate CI** : leur parité de clés
  et leur conformité ne sont pas garanties automatiquement. **Backlog** : les
  ajouter à `i18n.test.js` une fois leurs conventions arrêtées.

---

## Évolution de la charte

Cette charte est un document vivant. Elle peut être modifiée selon les principes
suivants :

- **Ajouts de termes politiques de référence** : par décision collective
  documentée dans le dépôt (issue ou pull request).
- **Changement de convention d'une langue** : nécessite la participation d'au
  moins une personne militante locuteur·rice native de la langue concernée. Le
  changement doit être motivé politiquement et techniquement.
- **Arrêt des conventions provisoires (`nl`) ou à définir (`el`)** : suit le même
  protocole — un choix typographique militant local, justifié, validé par des
  relais natifs, puis reversé dans cette charte et ajouté au gate CI.
- **Ajout d'une nouvelle langue** : même protocole.

---

*Charte v2 rédigée le 2026-06-05 à la suite de l'audit de langage inclusif des
dix locales et des chaînes mail. Document de référence à committer dans
`notes-audit/` du dépôt. Remplace la v1.0 du 2026-04-28.*
