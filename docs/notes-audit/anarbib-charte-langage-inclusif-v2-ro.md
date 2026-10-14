# Carta de limbaj incluziv a AnarBib

**Versiune**: 2.0
**Data**: 5 iunie 2026
**Statut**: document de referință al proiectului (singura sursă de autoritate)
**Înlocuiește**: `anarbib-charte-langage-inclusif-v1.md` (v1.0, 28 aprilie 2026), de acum **depreciată**

Acest document stabilește convențiile de limbaj incluziv adoptate în cele **zece
limbi** ale AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`,
`el`). Se aplică oricărei traduceri noi, oricărei recitiri și oricărei
contribuții viitoare. Se adresează persoanelor care contribuie la fișierele
`src/i18n/locales/*.json`, la șirurile notificărilor prin e-mail
(`supabase/functions/_shared/i18n/mail-strings.ts`) și la orice traducere
generată ulterior.

> **Evoluția față de v1**: v1 acoperea doar șase limbi (`pt-BR`, `fr`,
> `es`, `en`, `it`, `de`). v2 adaugă `ca`, `eo`, `nl`, `el` și **oficializează
> convenția italiană** (asterisc pentru perechile regulate, bară oblică pentru
> perechile neregulate), care înlocuiește bara oblică provizorie din v1.

---

## Cuprins

1. [De ce acest document](#de-ce-acest-document)
2. [Principiu director: coerență internă în fiecare limbă](#principiu-director-coerență-internă-în-fiecare-limbă)
3. [Tabelul statuturilor](#tabelul-statuturilor)
4. [Carta pe limbi](#carta-pe-limbi)
   - [Franceză (fr)](#franceză-fr)
   - [Germană (de)](#germană-de)
   - [Engleză (en)](#engleză-en)
   - [Portugheză braziliană (pt-BR)](#portugheză-braziliană-pt-br)
   - [Spaniolă castiliană (es)](#spaniolă-castiliană-es)
   - [Italiană (it)](#italiană-it)
   - [Catalană (ca)](#catalană-ca)
   - [Esperanto (eo)](#esperanto-eo)
   - [Neerlandeză (nl)](#neerlandeză-nl)
   - [Greacă (el)](#greacă-el)
   - [Română (ro)](#română-ro)
5. [Termeni politici de referință](#termeni-politici-de-referință)
6. [Termeni interziși](#termeni-interziși)
7. [Procedura pentru adăugirile viitoare](#procedura-pentru-adăugirile-viitoare)
8. [Acoperirea testelor (CI)](#acoperirea-testelor-ci)
9. [Evoluția cartei](#evoluția-cartei)

---

## De ce acest document

AnarBib este un sistem integrat de gestiune a bibliotecilor gândit pentru
bibliotecile militante anarhiste. O bibliotecă militantă nu este o bibliotecă
ca oricare alta: nu arhivează doar documente, ci constituie **o memorie
colectivă**, iar limbajul interfeței sale face parte din această memorie. O
interfață care vorbește despre „cititor” la masculinul generic reproduce gestul
de ștergere pe care o bibliotecă feministă sau queer încearcă tocmai să-l
desfacă; o interfață care spune „compagn·e·s” semnalează din prima secundă
cărei mișcări îi aparține.

Dar limbajul incluziv nu este o normă universală. Fiecare limbă are propria
istorie, propriile convenții militante, propriile terenuri politice minate.
**Nu există o scriere incluzivă transversală „bună”**: există alegeri locale
situate, apărate de comunități militante situate. Această cartă respectă aceste
situații locale, garantând totodată că, în interiorul aceleiași limbi, AnarBib
vorbește cu o singură voce.

Trei obiective concrete:

1. **Coerență**. În interiorul aceluiași fișier de limbă, aceeași poziție de
   gen se scrie mereu în același fel.
2. **Respectul culturilor militante locale**. Nicio convenție a unei limbi nu
   este impusă alteia.
3. **Lizibilitate pentru persoanele nespecialiste**. O bibliotecară militantă
   care descoperă AnarBib trebuie să se poată folosi de el fără să fie expertă
   în tipografie incluzivă.

---

## Principiu director: coerență internă în fiecare limbă

Fiecare limbă a AnarBib aplică **propria convenție tipografică de scriere
incluzivă**, moștenită din uzul militant local. Nu se impune nicio convenție
transversală.

În interiorul unei limbi, **aceste convenții sunt obligatorii și exclusive**:
un fișier `fr.json` nu amestecă punctul median cu `(e)`; un fișier
`it.json` nu amestecă asteriscul cu punctul median. Alegerile făcute în
această cartă sunt **forma oficială** a AnarBib pentru limba respectivă.

---

## Tabelul statuturilor

| Limbă | Convenție | Statut |
|---|---|---|
| `pt-BR` | Forma triplă `(o/a/e)` | **Adoptată** (referință) |
| `fr` | Punct median `·` | **Adoptată** |
| `es` | `e` neutru (convenția argentiniană) | **Adoptată** |
| `en` | Epicen + `they` la singular | **Adoptată** |
| `de` | Genderstern `*` | **Adoptată** |
| `it` | Asterisc (regulate) / bară oblică (neregulate) | **Adoptată** |
| `ca` | Terminație triplă `-a-e` + articolul `le` | **Adoptată** |
| `eo` | Infixul `-in-` vizibilizat prin cratime + pronumele `ri` | **Adoptată** |
| `nl` | Forme de rol neutre | **Provizorie** — de validat în comunitate |
| `el` | — | **De definit** împreună cu o persoană militantă vorbitoare de greacă |
| `ro` | Reformulare epicenă mai întâi, altfel dublet cu bară oblică (`cititor/cititoare`) | **De validat** prin recitirea unei persoane vorbitoare de română |

---

## Carta pe limbi

### Franceză (fr)

**Convenție adoptată**: punctul median (`·`, U+00B7).

**Forma generică**: rădăcina comună + punct median + terminația feminină.

| Masculin | Feminin | Forma AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Plural**: se adaugă `·s` (`lecteur·rice·s`).
**Articole / determinanți combinați**: `le·la`, `du·de la`, `au·à la`, `un·e`,
`le·la SEUL·E`, `actif·ve`.
**Cuvinte deja epicene**: neschimbate (`bibliothécaire`, `camarade`, `responsable`,
`personne`).
**Interzis**: `(e)`, `-e` separat (convenții de dinainte de 2010), punctul
obișnuit `.` sau bulina `•` în locul punctului median.

### Germană (de)

**Convenție adoptată**: Genderstern (`*`, asteriscul ASCII U+002A).

| Masculin | Feminin | Forma AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Plural**: `*innen` (`Genoss*innen`, `Leser*innen`).
**Interzis**: Mediopunkt `·`, Genderdoppelpunkt `:innen` și neologismul
hispanofon *„Compas”* lăsat netradus (întotdeauna `Genoss*in`/`Genoss*innen`).

### Engleză (en)

**Convenție adoptată**: termeni epiceni în mod implicit, `they/them/their` la
singular ca pronume neutru.

Gramatica engleză este în mare parte epicenă: se folosește sistematic forma
neutră existentă (`reader`, `librarian`, `author`, `administrator`,
`comrade`, `coordinator`, `user`), fără marcaj tipografic. Pentru rarii
termeni marcați de gen, se alege forma epicenă (`actor` în loc de `actress`,
`server` în loc de `waitress`).
**Interzis**: `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Portugheză braziliană (pt-BR)

**Convenție adoptată**: forma triplă `(o/a/e)` sau `(a/e)` după gramatică,
care include explicit cele trei poziții (feminin, masculin, non-binar).
**Este limba de referință a proiectului.**

| Masculin | Feminin | Forma AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Regulă**: cuvintele în `-or` → `(a/e)`; cuvintele în `-o` → `(o/a/e)`.
Terminațiile, în ordine alfabetică în paranteză.
**Contracții articol-prepoziție**: `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`,
`(o/a/e)s`.
**Cuvinte deja epicene**: neschimbate (`camarada`, `colega`, `responsável`,
`pessoa`).
**Interzis**: `(a)` singur, `/a`, `/o`, `@` (arroba), `x`. Atenție la
**falsul prieten `camarade`** (forma franceză): în pt-BR este **`camarada`**.

### Spaniolă castiliană (es)

**Convenție adoptată**: `e` neutru (convenția militantă argentiniană).

| Masculin | Feminin | Forma AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Regulă**: se înlocuiește vocala finală de gen (`-o`/`-a`) cu `-e`; cuvintele
în `-or` → rădăcină + `-e` (`lector → lectore`).
**Plural**: `-s` (`compañeres`).
**Articole / determinanți**: `le` (singular neutru), `les` (plural neutru).
**Participii acordate**: `informade`, `conectade`, `active`.
**Cuvinte deja epicene**: neschimbate (`camarada`, `colega`, `responsable`,
`persona`).
**Interzis**: `(a)`, `/a`, `/o`, **forma triplă `(o/a/e)` din pt-BR**
(spaniola folosește DOAR `e` neutru), `@` (arroba), `x` (Latinx) și
**punctul median `·`** (convenție franceză, de nefolosit în spaniolă).

### Italiană (it)

**Convenție adoptată — oficială**: **asterisc `*` pentru perechile
regulate, bară oblică prescurtată pentru perechile neregulate.** Această
convenție înlocuiește bara oblică provizorie din v1.

#### Perechi regulate (rădăcină comună în `-o`/`-a`) → asterisc `*`

Când masculinul și femininul au **aceeași rădăcină**, terminația de gen se
înlocuiește cu un asterisc, pentru coerență cu Genderstern-ul german.

| Masculin | Feminin | Forma AnarBib |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(deja epicen la singular)* |

Se aplică și **participiilor și adjectivelor acordate**: `stat*` (stato/a),
`ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a),
`benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*`
(questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Perechi neregulate (rădăcini diferite, de tipul `-tore`/`-trice`) → bară oblică prescurtată

Când femininul nu are aceeași rădăcină cu masculinul (`lettore` → `lettric-e`),
asteriscul este **greșit** (`lettor*` ar sugera un feminin inexistent
`lettora`). Se folosește deci **forma prescurtată cu bară oblică**, care este
*house style*-ul atestat în depozit.

| Masculin | Feminin | Forma AnarBib |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Plural neregulat**: `lettori/trici`, `amministratori/trici`,
`coordinatori/trici`.
**Articole**: `il/la`, `del/la`, `al/la`, `dal/la` (formă prescurtată), `un*`
pentru `uno/una`.
**Cuvinte deja epicene**: neschimbate (`utente`, `responsabile`, `persona`,
`collega`).

#### Despre caracterul `·`

Punctul median `·` **nu** este un marcaj incluziv în italiană: servește doar ca
**separator tipografic** în subiectele e-mailurilor și în rândurile de metadate
(`Email · ID · Genere`). Nu-l folosi niciodată pentru a marca genul.

**🚫 Interdicție absolută**: **`camerata` / `camerati` / `cameratesco`** — formă
de adresare internă fascistă (PNF, MSI, CasaPound, Forza Nuova, FdI). Folosește
`compagn*` și variantele sale. **Această interdicție este testată în CI**
(`i18n.test.js` și `mail-strings.test.ts`).
**Alte forme interzise**: parantezele `(a)`/`(o)`, triplul `/trice/e`, sufixul
`/x`, punctul median `·` ca marcaj de gen.

**Justificare militantă**: asteriscul (*asterisco*) este atestat în mediile
anarhiste și autonome italofone (Carmilla, DinamoPress, InfoAut,
Wu Ming) și oferă coerență vizuală cu Genderstern-ul german. Bara oblică
prescurtată pentru perechile neregulate evită femininele greșite, rămânând
totodată lizibilă.

### Catalană (ca)

**Convenție adoptată**: terminație triplă cu sufixul `-a-e` + articolul neutru `le`.

| Masculin | Feminin | Forma AnarBib |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Varianta cu paranteză**, acceptată pentru contracții:
`lector(a/e)`, `coordinador(a/e)`.
**Determinant neutru**: `le` (`le lector-a-e`).
**Plural**: `-s` sau forma combinată `els-les-les` / `als-a les-a les`.
**Cuvinte deja epicene**: neschimbate.

> Catalana folosește și punctul suspendat `·` în **geminata `l·l`**
> (`col·lectiu`, `cancel·lada`, `sol·licitud`): este o **grafie standard a
> catalanei**, fără legătură cu incluziunea. Nu o modifica.

### Esperanto (eo)

**Convenție adoptată**: infixul `-in-` vizibilizat prin cratime + pronumele
neutru `ri`.

| Bază | Forma AnarBib |
|---|---|
| leganto (cititor/cititoare) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Variantă non-binară**: sufixul `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Pronume neutru**: `ri`.
**Plural**: `-j` (`legant-in-oj`).

### Neerlandeză (nl)

**Statut: PROVIZORIU — de validat în comunitate.**

**Orientare provizorie**: se preferă **formele de rol neutre** existente în
locul unui marcaj tipografic.

| Concept | Formă provizorie |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Reguli provizorii**: evită sufixele marcate de gen `-ster`/`-e` când există o
formă neutră; pronumele non-binar `die` (sau `hen`/`hun`) — **uz încă
nestabilit**.

> ⚠️ Această convenție **nu** este definitivă. Trebuie validată de persoane
> militante vorbitoare de neerlandeză înainte de a fi fixată. Până atunci,
> rămâi la formele neutre.

### Greacă (el)

**Statut: CONVENȚIE DE DEFINIT.**

**Nu există un standard tipografic consensual** pentru scrierea incluzivă în
greacă. **Nu propune din oficiu niciun marcaj.** Convenția va fi stabilită
**împreună cu o persoană militantă vorbitoare de greacă** care se alătură
proiectului.

**Abordare de tranziție** (până atunci): dublete sau forme neutre existente
(`αναγνώστης/στρια`, `συντονιστής/στρια`), greaca monotonică, persoana a II-a
singular pentru tutuirea cititorului/cititoarei (persoana a II-a plural pentru
echipă). Sigla RGPD → `ΓΚΠΔ`.

> ⚠️ Orice propunere de marcaj tipografic incluziv sistematic pentru greacă
> este **prematură** cât timp nicio persoană militantă vorbitoare de greacă nu
> s-a alăturat proiectului.

### Română (ro)

**Statut: CONVENȚIE DE VALIDAT prin recitirea unei persoane vorbitoare de română.**

Nici româna nu are **un marcaj tipografic incluziv consensual**. AnarBib aplică
două reguli, în această ordine, până când o persoană militantă vorbitoare nativă
de română le confirmă sau le corectează:

1. **Mai întâi reformularea epicenă**: se numește funcția, grupul sau persoana,
   nu genul (`persoanele care citesc`, `persoana care citește`, `echipa de
   coordonare`, `echipa bibliotecii`, `cine catalogează`, `persoana responsabilă`).
2. **Altfel, dubletul cu bară oblică**, masculinul întâi, cu ambele forme scrise
   întreg:

| Masculin | Feminin | Forma AnarBib |
|---|---|---|
| cititor | cititoare | **cititor/cititoare** |
| bibliotecar | bibliotecară | **bibliotecar/bibliotecară** |
| autor | autoare | **autor/autoare** |
| administrator | administratoare | **administrator/administratoare** |
| coordonator | coordonatoare | **coordonator/coordonatoare** |
| tovarăș | tovarășă | **tovarăș/tovarășă** *(de confirmat)* |

**Plural**: `cititori/cititoare`, `bibliotecari/bibliotecare`,
`coordonatori/coordonatoare`, `tovarăși/tovarășe`.
**Adresare**: tutuire fără excepție (`Introdu`, `Alege`, `Salvează`; posesivele
`tău`/`ta`); niciodată `dumneavoastră`, `dvs.` sau persoana a II-a plural pentru
o singură persoană. Pluralul rămâne posibil când fraza se adresează unui grup
(o adunare, o echipă).

**Cazuri particulare**:

- **Diacritice**: `ș ț` cu virgulă dedesubt (U+0219, U+021B; majusculele
  U+0218, U+021A), niciodată formele cu sedilă (U+015F, U+0163); **o gardă CI
  verifică acest lucru**. Întotdeauna `ă â î`.
- **Ghilimele**: `„…”`, niciodată `« … »`.
- **`camarade`**: `tovarăș/tovarășă` (uzul mediilor anarhiste din România) —
  **de confirmat**: cuvântul păstrează o conotație din epoca comunistă;
  alternativa avută în vedere este `camarad/camaradă`.
- **Sigla** RGPD → `GDPR`.
- **Interzis**: punctul median `·`, sufixul `-x`.

> ⚠️ Această convenție **nu** este definitivă. Trebuie validată prin recitirea
> unei persoane militante vorbitoare nativă de română înainte de a fi fixată.
> Până atunci, rămâi la formulările epicene și la dubletele de mai sus.

---

## Termeni politici de referință

### Tovarăș/tovarășă

| Limbă | Formă oficială | Plural |
|---|---|---|
| 🇫🇷 fr | `camarade` *(epicen)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(epicen)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(epicen)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagn*` | `compagn*` |
| ca | `camarada` *(epicen)* | `camarades` |
| eo | `kamarad-in-o` | `kamarad-in-oj` |
| nl | `kameraad` *(provizoriu)* | `kameraden` |
| el | `σύντροφος` *(de confirmat)* | — |
| ro | `tovarăș/tovarășă` *(de confirmat; alternativă: `camarad/camaradă`)* | `tovarăși/tovarășe` |

### Cititor/cititoare

| Limbă | Formă oficială |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/trice` |
| ca | `lector-a-e` |
| eo | `legant-in-o` |
| nl | `lezer` *(provizoriu)* |
| el | `αναγνώστης/στρια` *(de tranziție)* |
| ro | `cititor/cititoare` *(formă epicenă: `persoana care citește`)* |

### Bibliotecar/bibliotecară

| Limbă | Formă oficială |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(epicen)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecari*` |
| ca | `bibliotecari-ària-e` |
| eo | `bibliotekist-in-o` |
| nl | `bibliothecaris` *(provizoriu)* |
| el | `βιβλιοθηκάριος` *(de confirmat)* |
| ro | `bibliotecar/bibliotecară` |

### Administrator/administratoare

| Limbă | Formă oficială |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/trice` |
| ca | `administrador-a-e` |
| eo | `administrant-in-o` |
| nl | `beheerder` *(provizoriu)* |
| el | *(de definit)* |
| ro | `administrator/administratoare` |

---

## Termeni interziși

### Marcați politic (interdicție absolută)

| Termen | Limbă | Motiv |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Formă de adresare internă fascistă (PNF, MSI, CasaPound, Forza Nuova, FdI). **Testat în CI.** |
| `Compas` *(netradus)* | 🇩🇪 de | Neologism hispanofon lăsat ca atare — folosește `Genoss*in`/`Genoss*innen`. |

### Convenții tipografice birocratice sau nepotrivite

| Formă | Limbi vizate | De ce |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Formă administrativă, nemilitantă. |
| `@` (arroba) | pt-BR, es | Învechită, problemă de accesibilitate (cititoare de ecran). |
| `x` (Latinx) | es, pt-BR | Înlocuită de `e` neutru în uzul militant contemporan. |
| `(e)`, `-e` separat | fr | Convenție de dinainte de 2010, înlocuită de punctul median. |
| `Genderdoppelpunkt` (`:innen`) | de | Validă, dar nereținută din coerență cu `*`. |
| `he/she`, `s/he`, `(s)he` | en | Preferă `they/them` la singular. |
| Triplul `(o/a/e)` | es | Rezervat pentru pt-BR; spaniola folosește doar `e` neutru. |
| Punctul median `·` ca marcaj de gen | es, it, ca | Convenție franceză; în rest, `·` este doar un separator (sau geminata `l·l` în ca). |
| Triplul `/trice/e`, sufixul `/x` | it | Forme malformate; folosește bara oblică prescurtată `/trice`. |

---

## Procedura pentru adăugirile viitoare

### Când adaugi o cheie i18n nouă

1. **Identifică** cuvântul/expresia de tradus. Este un termen care trebuie marcat după gen?
2. **Dacă da, alege forma epicenă când există** (`camarada` pt-BR,
   `responsable` fr, `utente` it…).
3. **Altfel, aplică convenția limbii** definită mai sus.
4. **Pentru italiană**: deosebește perechea regulată (asterisc) de perechea
   neregulată (bară oblică prescurtată).
5. **Verifică coerența** cu restul fișierului.
6. **Completează cele 10 limbi într-o singură trecere.** O cheie tradusă
   parțial este un bug. **Paritatea cheilor** între cele 10 limbi este
   obligatorie.

### Când recitești o traducere existentă

1. Caută marcajele **interzise** (`(a)`, `@`, `camerata`, punctul median în afara
   fr/geminatei din ca, triplul `/trice/e`…).
2. Înlocuiește-le cu forma oficială a limbii.
3. Verifică coerența singular/plural.
4. Verifică coerența între limbi pentru aceeași cheie.

### Când ceri o traducere unei IA

Furnizează întotdeauna această cartă drept context, precizează convenția
așteptată pentru limba țintă și termenii interziși, preferă formele epicene și
**verifică rezultatul** înainte de integrare.

---

## Acoperirea testelor (CI)

- `src/tests/i18n.test.js` testează **paritatea cheilor** și **conformitatea**
  a **8 limbi**: `pt-BR, fr, en, de, it, es, ca, eo`. Include testul blocant
  „italiana nu trebuie să conțină niciodată camerata/camerati”.
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) testează
  șirurile pentru e-mail: paritate, termeni interziși (camerata), interpolare, fallback.
- ⚠️ **`nl` și `el` NU sunt acoperite de gate-ul CI**: paritatea cheilor și
  conformitatea lor nu sunt garantate automat. **Backlog**: adăugarea lor în
  `i18n.test.js` după ce convențiile lor vor fi stabilite.

---

## Evoluția cartei

Această cartă este un document viu. Poate fi modificată după următoarele
principii:

- **Adăugarea de termeni politici de referință**: prin decizie colectivă
  documentată în depozit (issue sau pull request).
- **Schimbarea convenției unei limbi**: necesită participarea a cel puțin unei
  persoane militante vorbitoare native a limbii respective. Schimbarea trebuie
  motivată politic și tehnic.
- **Stabilirea convențiilor provizorii (`nl`) sau de definit (`el`)**: urmează
  același protocol — o alegere tipografică militantă locală, justificată,
  validată de persoane vorbitoare native, apoi transpusă în această cartă și
  adăugată în gate-ul CI.
- **Adăugarea unei limbi noi**: același protocol.

---

*Carta v2, redactată pe 5 iunie 2026 în urma auditului de limbaj incluziv al
celor zece limbi și al șirurilor pentru e-mail. Document de referință de pus în
commit în `notes-audit/` din depozit. Înlocuiește v1.0 din 28 aprilie 2026.*
