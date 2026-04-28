# Charte de langage inclusif d'AnarBib

**Version** : 1.0
**Date** : 2026-04-28
**Statut** : référence du projet

Ce document fixe les conventions de langage inclusif adoptées dans les six locales d'AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`). Il s'applique à toute traduction nouvelle, à toute relecture, et à toute contribution future. Il est destiné aux personnes qui contribuent aux fichiers `src/i18n/locales/*.json` et à toute traduction générée par la suite.

---

## Sommaire

1. [Pourquoi ce document](#pourquoi-ce-document)
2. [Principe directeur : cohérence interne par langue](#principe-directeur--cohérence-interne-par-langue)
3. [Charte par langue](#charte-par-langue)
   - [Français (fr)](#français-fr)
   - [Allemand (de)](#allemand-de)
   - [Anglais (en)](#anglais-en)
   - [Portugais brésilien (pt-BR)](#portugais-brésilien-pt-br)
   - [Espagnol castillan (es)](#espagnol-castillan-es)
   - [Italien (it)](#italien-it)
4. [Termes politiques de référence](#termes-politiques-de-référence)
5. [Termes proscrits](#termes-proscrits)
6. [Procédure pour les ajouts futurs](#procédure-pour-les-ajouts-futurs)
7. [Évolution de la charte](#évolution-de-la-charte)

---

## Pourquoi ce document

AnarBib est un système intégré de gestion de bibliothèques pensé pour les bibliothèques militantes anarchistes. Une bibliothèque militante n'est pas une bibliothèque comme les autres : elle n'archive pas seulement des documents, elle constitue **une mémoire collective**, et le langage de son interface fait partie de cette mémoire. Une interface qui parle de « lecteur » au masculin générique reproduit le geste effacement qu'une bibliothèque féministe ou queer cherche précisément à défaire ; une interface qui dit « compagn·e·s » signale dès la première seconde à quel mouvement elle appartient.

Mais le langage inclusif n'est pas une norme universelle. Chaque langue a sa propre histoire, ses propres conventions militantes, ses propres terrains politiques minés. **Il n'existe pas de « bonne » écriture inclusive transversale** : il existe des choix locaux situés, défendus par des communautés militantes situées. Cette charte respecte ces situations locales tout en garantissant qu'à l'intérieur d'une même langue, AnarBib parle d'une seule voix.

Trois objectifs concrets :

1. **Cohérence**. À l'intérieur d'un même fichier de locale, la même position de genre s'écrit toujours de la même façon. Pas de mélange `(a)` / `(a/e)` / `e` neutre dans un même fichier.
2. **Respect des cultures militantes locales**. Pas d'imposition d'une convention française aux germanophones, ni d'une convention anglo-saxonne aux hispanophones.
3. **Lisibilité par non-spécialistes**. Une bibliothécaire militante qui découvre AnarBib doit pouvoir s'en servir sans être experte en typographie inclusive. Le fonctionnement passe avant le militantisme typographique.

---

## Principe directeur : cohérence interne par langue

Chaque langue d'AnarBib applique **sa propre convention typographique d'écriture inclusive**, héritée de l'usage militant local. Aucune convention transversale n'est imposée.

Concrètement :

- Le français utilise le **point médian** (`·`).
- L'allemand utilise le **Genderstern** (`*`).
- L'anglais privilégie les **termes épicènes**.
- Le portugais brésilien utilise la **forme triple `(o/a/e)`**.
- L'espagnol castillan utilise le ***`e`* neutre seul** (convention argentine).
- L'italien conserve provisoirement le **slash `/`** en attente d'un choix militant local.

À l'intérieur d'une langue, **ces conventions sont obligatoires et exclusives** : un fichier `fr.json` ne mélange pas le médian avec des `(e)` ; un fichier `pt-BR.json` ne mélange pas `(a/e)` avec `(a)`. Les choix faits dans cette charte sont la **forme officielle** d'AnarBib pour cette langue.

---

## Charte par langue

### Français (fr)

**Convention adoptée** : point médian (`·`).

**Forme générique** : pour un mot ayant une forme masculine et une forme féminine distinctes, on écrit la racine commune suivie du point médian et de la terminaison féminine.

| Forme masculine | Forme féminine | Forme inclusive AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| bibliothécaire | bibliothécaire | **bibliothécaire** *(épicène)* |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Pluriel** : on ajoute le `·s` final.

- Singulier : `lecteur·rice`
- Pluriel : `lecteur·rice·s`

**Mots déjà épicènes** : on ne marque rien.

- `bibliothécaire`, `camarade`, `responsable`, `personne` → restent inchangés.

**Caractère typographique** : le point médian est le caractère Unicode `U+00B7` (`·`), pas le point ordinaire `.` ni la puce `•`. Sur clavier français : `Alt+Maj+F` sous macOS, `Alt+0183` sous Windows, `Compose+.+.` sous Linux.

**Justification militante** : le point médian est aujourd'hui la convention dominante dans l'édition militante francophone (Lundi matin, Terrestres, Éditions Divergences, La Fabrique, etc.). Il a remplacé progressivement le tiret `-e` et la parenthèse `(e)` au cours des années 2010-2020. C'est aussi la convention recommandée par le Haut Conseil à l'Égalité et adoptée par de nombreuses associations féministes francophones.

### Allemand (de)

**Convention adoptée** : Genderstern (`*`).

**Forme générique** : pour un nom ayant une forme masculine et une forme féminine, on insère un astérisque entre la racine et le suffixe féminin.

| Forme masculine | Forme féminine | Forme inclusive AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Koordinator | Koordinatorin | **Koordinator*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Pluriel** : on remplace `in` par `innen`.

- Singulier : `Genoss*in`
- Pluriel : `Genoss*innen`

**Caractère typographique** : astérisque ASCII standard (`*`, `U+002A`). Pas de Mediopunkt `·`, pas de double-points `:innen` (autre convention valable mais non retenue ici par cohérence avec l'écosystème militant anarchiste germanophone).

**Cas particulier — `Genoss*in`** : le néologisme hispanophone *« Compas »*, parfois utilisé en français militant, **ne se traduit jamais tel quel en allemand**. La forme à utiliser systématiquement est `Genoss*in` (singulier) ou `Genoss*innen` (pluriel), forme attestée dans le mouvement libertaire germanophone.

**Justification militante** : le Genderstern est la convention dominante dans l'écosystème militant féministe, queer et libertaire germanophone depuis les années 2000-2010 (taz, Jungle World, Edition Assemblage, Unrast Verlag). C'est aussi la forme officiellement recommandée par de nombreuses universités allemandes et autrichiennes, et par le Conseil Suisse de l'Égalité. Plus diffusée que le Mediopunkt `·`, plus accessible que le double-points `:innen`.

### Anglais (en)

**Convention adoptée** : termes épicènes par défaut, `they/them` au singulier comme pronom neutre.

**Stratégie générale** : la grammaire anglaise est largement épicène par nature — la plupart des noms de fonctions n'ont pas de forme genrée. On utilise systématiquement la **forme neutre déjà existante** dans la langue, sans aucun marquage typographique inclusif.

| Concept | Forme inclusive AnarBib |
|---|---|
| reader | **reader** *(épicène)* |
| librarian | **librarian** *(épicène)* |
| author | **author** *(épicène)* |
| administrator | **administrator** *(épicène)* |
| comrade | **comrade** *(épicène)* |
| coordinator | **coordinator** *(épicène)* |
| user | **user** *(épicène)* |

**Cas des termes genrés** : pour les rares termes qui ont un genre marqué (`actress`, `waitress`), on choisit systématiquement la **forme épicène** (`actor`, `server`).

**Pronoms** : `they/them/their` au singulier pour toute personne dont le genre n'est pas spécifié ou qui ne s'identifie pas au binaire (usage attesté en anglais depuis le XIVᵉ siècle, officiellement validé par le *Merriam-Webster* en 2019). **Ne pas utiliser `he/she`, `s/he`, `he or she`** — toutes ces formes sont à proscrire.

**Justification militante** : la simplicité grammaticale de l'anglais permet une inclusivité **sans marquage visible**. C'est une force, pas une faiblesse politique : le militantisme typographique n'est pas le seul mode du militantisme linguistique. La généralisation du `they` singulier dans les milieux queer anglophones est un choix linguistique aussi politique que le médian français.

### Portugais brésilien (pt-BR)

**Convention adoptée** : forme triple `(o/a/e)` ou `(a/e)` selon la grammaire du mot.

**Forme générique** : pour un mot ayant des formes genrées distinctes, on inclut explicitement les trois positions — féminin, masculin, **non-binaire**.

| Forme masculine | Forme féminine | Forme inclusive AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Règle pratique** : dans la parenthèse, on liste les terminaisons distinctes par ordre alphabétique. Les mots en `-or` ne nécessitent que `(a/e)` (la forme masculine étant la racine). Les mots en `-o` nécessitent `(o/a/e)`.

**Pluriel** : on accorde la parenthèse au pluriel.

- Singulier : `leitor(a/e)`
- Pluriel : `leitor(a/e)s` ou `leitores/leitoras/leitores`

**Mots déjà épicènes** : on ne marque rien.

- `camarada`, `colega`, `responsável`, `pessoa` → restent inchangés.

**Termes proscrits** :
- ❌ `(a)` seul ou `/a` ou `/o` : forme bureaucratique administrative (mairies, universités) — non militante.
- ❌ `@` (arroba) : convention obsolète, problèmes d'accessibilité (lecteurs d'écran).
- ❌ `x` : remplacée par `e` neutre dans l'usage militant brésilien actuel.

**Justification militante** : la forme triple `(o/a/e)` reconnaît explicitement les trois positions de genre — c'est la convention promue par les milieux LGBTQIA+, féministes et libertaires brésiliens depuis ~2018-2020. Visible chez Mídia Ninja, N-1 Edições, dans les universités fédérales engagées (UFBA, UFMG, UnB) et l'écosystème militant lusophone élargi. Le `e` final, qui apparaît dans la parenthèse, est la marque non-binaire (`leitore` est une forme neutre attestée dans le mouvement non-binaire lusophone).

### Espagnol castillan (es)

**Convention adoptée** : `e` neutre (convention argentine militante).

**Forme générique** : pour un nom ayant des formes genrées distinctes, on remplace systématiquement la voyelle de genre par `e` (forme neutre prononçable).

| Forme masculine | Forme féminine | Forme inclusive AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| coordinador | coordinadora | **coordinadore** |
| usuario | usuaria | **usuarie** |

**Règle pratique** : on remplace la voyelle finale du mot (`-o` ou `-a`) par `-e`. Pour les noms en `-or` (qui ont `-or`/`-ora`), on ajoute `-e` à la racine masculine : `lector → lectore`.

**Pluriel** : on ajoute `-s`.

- Singulier : `compañere`
- Pluriel : `compañeres`

**Articles et déterminants** : `le` (singulier neutre), `les` (pluriel neutre) — convention reconnue dans le mouvement non-binaire hispanophone. Pour les démonstratifs : `este`, `estes` (forme commune existante en espagnol) ou `aquelle`, `aquelles` (formes neutralisées).

**Mots déjà épicènes** : on ne marque rien.

- `camarada`, `colega`, `responsable`, `persona` → restent inchangés.

**Termes proscrits** :
- ❌ `(a)`, `/a`, `/o` : formes bureaucratiques (mairies, ministères latino-américains) — non militantes.
- ❌ `@` (arroba) : convention obsolète, problèmes d'accessibilité.
- ❌ `x` : convention chicano/queer des années 2000-2010, supplantée par le `e` dans l'écosystème militant hispanophone contemporain.

**Justification militante** : le `e` neutre est la convention diffusée à partir d'Argentine vers 2017-2018 dans les milieux féministes et LGBTQIA+, popularisée par la Marea Verde et adoptée par l'éditorialisme militant ibéro-américain (Página/12, LatFem, Anfibia, Editorial Marea, Pepitas de calabaza, Traficantes de sueños). Prononçable, lisible par lecteurs d'écran, militairement marquée sans être disruptive. C'est aujourd'hui la convention dominante dans les milieux libertaires et autonomes hispanophones.

### Italien (it)

**Convention adoptée — provisoire** : slash `/` (statu quo prudent).

**Statut** : cette convention est **transitoire**. Elle sera renégociée dès que des relais militants italianophones rejoindront le projet AnarBib pour faire un choix de leur cru. En attendant, on adopte la forme administrativement neutre du slash, qui n'exclut pas mais ne prend pas non plus position politiquement.

**Forme générique** : on accole la forme féminine après slash.

| Forme masculine | Forme féminine | Forme inclusive AnarBib (provisoire) |
|---|---|---|
| lettore | lettrice | **lettore/lettrice** *(ou lettore/trice)* |
| bibliotecario | bibliotecaria | **bibliotecario/a** |
| autore | autrice | **autore/autrice** |
| amministratore | amministratrice | **amministratore/amministratrice** |
| compagno | compagna | **compagno/a** |
| coordinatore | coordinatrice | **coordinatore/coordinatrice** |
| utente | utente | **utente** *(épicène)* |

**Pluriel** :

- Singulier : `compagno/a`
- Pluriel : `compagni/e`

**Mots déjà épicènes** : on ne marque rien.

- `utente`, `responsabile`, `persona`, `collega` → restent inchangés.

**⚠️ Termes formellement proscrits** :

- 🚫 **`camerata` / `camerati` / `cameratesco`** : terme **lourdement marqué politiquement**. Adopté par le fascisme mussolinien dès les années 1920 comme adresse interne du Parti National Fasciste, en remplacement du `compagno` socialiste qu'ils voulaient s'approprier symboliquement. Aujourd'hui encore, `Camerati!` reste le salut typique des rassemblements néofascistes (CasaPound, Forza Nuova, MSI, Fratelli d'Italia). **L'utiliser dans une bibliothèque anarchiste serait à la fois fautif politiquement et activement insultant pour les compagn·e·s italien·ne·s**. Aucun automatisme ni IA traduisant pour AnarBib ne doit jamais produire ce terme.

- ❌ `(a)` ou `(o)` parenthèses : formes administratives sans valeur militante.

**Pistes futures** : lors de l'arrivée de relais italianophones, plusieurs conventions militantes seront envisageables :

- `compagn*` (asterisco/Genderstern italien) — convention attestée dans les milieux anarchistes et autonomes (Carmilla, DinamoPress, InfoAut, Wu Ming).
- `compagnə` (schwa) — convention promue par la linguiste Vera Gheno et l'éditeur Effequ.
- `compagne` (e neutre) — convention plus rare mais existante.

**Aucune de ces conventions ne sera adoptée sans participation militante italianophone au projet** — pour éviter d'imposer un choix politique d'en haut.

---

## Termes politiques de référence

Cette section fixe la traduction officielle d'AnarBib pour les termes à charge politique. Toute traduction qui s'en écarte doit être révisée.

### Camarade / Compagn·e

| Langue | Forme officielle AnarBib | Pluriel |
|---|---|---|
| 🇫🇷 fr | `camarade` *(épicène)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(épicène)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(épicène)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagno/a` | `compagni/e` |

**Note** : en pt-BR et fr, `camarada/camarade` est nativement épicène — pas de marquage nécessaire. C'est la forme la plus simple et la plus militante.

### Lecteur·rice

| Langue | Forme officielle AnarBib |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/lettrice` |

### Bibliothécaire

| Langue | Forme officielle AnarBib |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(épicène)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecario/a` |

### Auteur·rice

| Langue | Forme officielle AnarBib |
|---|---|
| 🇫🇷 fr | `auteur·rice` |
| 🇩🇪 de | `Autor*in` |
| 🇬🇧 en | `author` |
| 🇧🇷 pt-BR | `autor(a/e)` |
| 🇪🇸 es | `autore` |
| 🇮🇹 it | `autore/autrice` |

### Administrateur·rice

| Langue | Forme officielle AnarBib |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/amministratrice` |

---

## Termes proscrits

Cette liste rassemble les formes **interdites** dans les fichiers de locale d'AnarBib, toutes langues confondues.

### Termes politiquement marqués (proscription absolue)

| Terme | Langue | Raison |
|---|---|---|
| `camerata` / `camerati` | 🇮🇹 it | Adresse interne fasciste (PNF, MSI, CasaPound, Forza Nuova, FdI). |
| `Compas` *(non traduit)* | 🇩🇪 de | Néologisme hispanophone laissé tel quel — utiliser `Genoss*in/innen`. |

### Conventions typographiques bureaucratiques

| Forme | Langues concernées | Pourquoi |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es | Forme administrative, non militante. |
| `@` (arroba) | pt-BR, es | Obsolète, problème d'accessibilité (lecteurs d'écran). |
| `x` (Latinx) | es | Supplantée par `e` neutre dans l'usage militant contemporain. |
| `(e)`, `-e` séparé | fr | Convention pré-2010, remplacée par le médian. |
| `Genderdoppelpunkt` (`:innen`) | de | Valable mais non retenue par cohérence avec `*`. |
| `he/she`, `s/he`, `(s)he` | en | Préférer `they/them` singulier. |

---

## Procédure pour les ajouts futurs

### Quand on ajoute une nouvelle clé i18n

1. **Identifier le mot/expression à traduire**. S'agit-il d'un terme à genrer ?
2. **Si oui, choisir la forme épicène quand elle existe**. Ex. : `camarada` en pt-BR, `responsable` en fr, `utente` en it, etc.
3. **Sinon, appliquer la convention de la langue** définie dans la charte ci-dessus.
4. **Vérifier la cohérence avec le reste du fichier** : la même forme génère le même marquage typographique.
5. **Renseigner les 6 locales en une seule passe**. Une clé partiellement traduite est un bug.

### Quand on relit une traduction existante

1. Repérer les marqueurs **proscrits** (`(a)`, `/a`, `@`, `camerata`, etc.).
2. Les remplacer par la forme officielle de la langue.
3. Vérifier la cohérence singulier/pluriel.
4. Vérifier la **cohérence avec les autres locales** pour la même clé : sens identique, ton équivalent.

### Quand on demande une traduction à une IA

Toujours fournir cette charte en contexte du prompt, et **vérifier le résultat** avant intégration. Les IA ont tendance à produire des formes bureaucratiques (`compañero/a`) ou inappropriées (`Genoss·innen` au lieu de `Genoss*in/innen`) si on ne précise pas la convention attendue.

**Modèle de prompt recommandé** :

```
Tu traduis pour AnarBib (SIGB de bibliothèques militantes anarchistes).
Convention de langage inclusif obligatoire pour [LANGUE] : [CONVENTION].
Ne jamais utiliser : [TERMES PROSCRITS].
Privilégier les formes épicènes quand elles existent.

Texte à traduire : [...]
```

---

## Évolution de la charte

Cette charte est un document vivant. Elle peut être modifiée selon les principes suivants :

- **Ajouts de termes politiques de référence** : par décision collective documentée dans le repo (issue ou pull request).
- **Changement de convention d'une langue** : nécessite la participation d'au moins une personne militante locuteur·rice native de la langue concernée. Le changement doit être motivé politiquement et techniquement (cohérence d'ensemble, accessibilité, lisibilité).
- **Ajout d'une nouvelle langue** : suit le même protocole — un choix typographique militant local, justifié, intégré à la charte.

Le cas italien est un exemple type : la convention slash actuelle est explicitement **provisoire**, dans l'attente que des relais italianophones rejoignent le projet pour proposer une convention militante locale (asterisco `*`, schwa `ə`, ou e neutre).

---

*Charte rédigée au cours de la phase 2 du chantier i18n d'AnarBib (avril 2026). Document de référence à commiter dans `docs/` du dépôt.*
