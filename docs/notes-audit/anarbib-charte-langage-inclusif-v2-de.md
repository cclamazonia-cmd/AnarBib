# AnarBib — Charta des inklusiven Sprachgebrauchs

**Version** : 2.0
**Datum** : 2026-06-05
**Status** : Projektreferenz (einzige Autoritätsquelle)
**Ersetzt** : `anarbib-charte-langage-inclusif-v1.md` (v1.0, 2026-04-28), nunmehr **veraltet**

Dieses Dokument legt die Konventionen des inklusiven Sprachgebrauchs fest, die in den **zehn
Sprachversionen** von AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`,
`el`) angenommen wurden. Es gilt für alle neuen Übersetzungen, alle Korrekturen und alle
künftigen Beiträge. Es richtet sich an Personen, die zu den Dateien
`src/i18n/locales/*.json`, den Zeichenketten der E-Mail-Benachrichtigungen
(`supabase/functions/_shared/i18n/mail-strings.ts`) und zu allen künftig erstellten
Übersetzungen beitragen.

> **Entwicklung seit v1** : Die v1 deckte nur sechs Sprachversionen ab (`pt-BR`, `fr`,
> `es`, `en`, `it`, `de`). Die v2 fügt `ca`, `eo`, `nl`, `el` hinzu und **offizialisiert
> die italienische Konvention** (Asterisk für reguläre Paare, Schrägstrich für irreguläre
> Paare), die den provisorischen Schrägstrich der v1 ablöst.

---

## Inhaltsverzeichnis

1. [Warum dieses Dokument](#warum-dieses-dokument)
2. [Leitprinzip: sprachinterne Kohärenz](#leitprinzip-sprachinterne-kohärenz)
3. [Statustabelle](#statustabelle)
4. [Charta nach Sprache](#charta-nach-sprache)
   - [Französisch (fr)](#französisch-fr)
   - [Deutsch (de)](#deutsch-de)
   - [Englisch (en)](#englisch-en)
   - [Brasilianisches Portugiesisch (pt-BR)](#brasilianisches-portugiesisch-pt-br)
   - [Kastilisches Spanisch (es)](#kastilisches-spanisch-es)
   - [Italienisch (it)](#italienisch-it)
   - [Katalanisch (ca)](#katalanisch-ca)
   - [Esperanto (eo)](#esperanto-eo)
   - [Niederländisch (nl)](#niederländisch-nl)
   - [Griechisch (el)](#griechisch-el)
5. [Politische Referenzbegriffe](#politische-referenzbegriffe)
6. [Verbotene Begriffe](#verbotene-begriffe)
7. [Verfahren für künftige Ergänzungen](#verfahren-für-künftige-ergänzungen)
8. [Testabdeckung (CI)](#testabdeckung-ci)
9. [Weiterentwicklung der Charta](#weiterentwicklung-der-charta)

---

## Warum dieses Dokument

AnarBib ist ein integriertes Bibliotheksmanagementsystem, das für anarchistische militante
Bibliotheken konzipiert wurde. Eine militante Bibliothek ist keine Bibliothek wie jede
andere: sie archiviert nicht nur Dokumente, sie konstituiert **ein kollektives Gedächtnis**,
und die Sprache ihrer Benutzeroberfläche ist Teil dieses Gedächtnisses. Eine Benutzeroberfläche,
die vom „Leser" im generischen Maskulinum spricht, reproduziert die Auslöschungsgeste, die
eine feministische oder queere Bibliothek gerade zu überwinden sucht; eine Benutzeroberfläche,
die „Genoss*innen" sagt, signalisiert von der ersten Sekunde an, zu welcher Bewegung sie
gehört.

Aber inklusiver Sprachgebrauch ist keine universelle Norm. Jede Sprache hat ihre eigene
Geschichte, ihre eigenen militanten Konventionen, ihre eigenen politisch vermintes Terrain.
**Es gibt keine „gute" sprachübergreifende inklusive Schreibweise**: es gibt lokale,
situierte Entscheidungen, die von situierten militanten Gemeinschaften vertreten werden.
Diese Charta respektiert diese lokalen Situationen, während sie gleichzeitig garantiert,
dass AnarBib innerhalb einer Sprache mit einer einzigen Stimme spricht.

Drei konkrete Ziele:

1. **Kohärenz**. Innerhalb einer Sprachdatei wird dieselbe Genusposition immer auf dieselbe
   Weise geschrieben.
2. **Respekt der lokalen militanten Kulturen**. Keine Aufdrängen einer Konvention von einer
   Sprache auf eine andere.
3. **Lesbarkeit für Nicht-Spezialist*innen**. Eine militante Bibliothekar*in, die AnarBib
   entdeckt, soll es benutzen können, ohne Expert*in in inklusiver Typografie zu sein.

---

## Leitprinzip: sprachinterne Kohärenz

Jede Sprache von AnarBib wendet **ihre eigene typografische Konvention des inklusiven
Schreibens** an, die aus dem lokalen militanten Gebrauch stammt. Es wird keine
sprachübergreifende Konvention aufgezwungen.

Innerhalb einer Sprache sind **diese Konventionen obligatorisch und exklusiv**: Eine Datei
`fr.json` mischt nicht den Mediopunkt mit `(e)`; eine Datei `it.json` mischt nicht den
Asterisk mit dem Mediopunkt. Die in dieser Charta getroffenen Entscheidungen sind die
**offizielle Form** von AnarBib für diese Sprache.

---

## Statustabelle

| Sprachversion | Konvention | Status |
|---|---|---|
| `pt-BR` | Dreifachform `(o/a/e)` | **Angenommen** (Referenz) |
| `fr` | Mediopunkt `·` | **Angenommen** |
| `es` | Neutrales `e` (argentinische Konvention) | **Angenommen** |
| `en` | Epicoen + singuläres `they` | **Angenommen** |
| `de` | Genderstern `*` | **Angenommen** |
| `it` | Asterisk (regulär) / Schrägstrich (irregulär) | **Angenommen** |
| `ca` | Dreifache Endung `-a-e` + Artikel `le` | **Angenommen** |
| `eo` | Infix `-in-` durch Bindestriche sichtbar gemacht + Pronomen `ri` | **Angenommen** |
| `nl` | Neutrale Rollenformen | **Provisorisch** — von der Gemeinschaft zu validieren |
| `el` | — | **Festzulegen** mit einer griechischsprachigen militanten Person |

---

## Charta nach Sprache

### Französisch (fr)

**Angenommene Konvention** : Mediopunkt (`·`, U+00B7).

**Generische Form** : gemeinsame Wurzel + Mediopunkt + feminine Endung.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Plural** : `·s` wird angehängt (`lecteur·rice·s`).
**Kombinierte Artikel / Determinierer** : `le·la`, `du·de la`, `au·à la`, `un·e`,
`le·la SEUL·E`, `actif·ve`.
**Bereits epicoene Wörter** : unverändert (`bibliothécaire`, `camarade`, `responsable`,
`personne`).
**Verboten** : `(e)`, getrenntes `-e` (Konventionen vor 2010), gewöhnlicher Punkt `.` oder
Aufzählungspunkt `•` anstelle des Mediopunkts.

### Deutsch (de)

**Angenommene Konvention** : Genderstern (`*`, ASCII-Asterisk U+002A).

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Plural** : `*innen` (`Genoss*innen`, `Leser*innen`).
**Verboten** : Mediopunkt `·`, Genderdoppelpunkt `:innen`, und der hispanophone Neologismus
*„Compas"* unübersetzt gelassen (immer `Genoss*in`/`Genoss*innen`).

### Englisch (en)

**Angenommene Konvention** : standardmäßig epicoene Begriffe, `they/them/their` im
Singular als neutrales Pronomen.

Die englische Grammatik ist weitgehend epicoen: man verwendet systematisch die vorhandene
neutrale Form (`reader`, `librarian`, `author`, `administrator`, `comrade`, `coordinator`,
`user`), ohne typografische Markierung. Bei den seltenen genusmarkierten Begriffen wählt
man die epicoene Form (`actor` statt `actress`, `server` statt `waitress`).
**Verboten** : `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Brasilianisches Portugiesisch (pt-BR)

**Angenommene Konvention** : Dreifachform `(o/a/e)` oder `(a/e)` je nach Grammatik,
die ausdrücklich alle drei Positionen einschließt (feminin, maskulin, nicht-binär).
**Dies ist die Referenzsprachversion des Projekts.**

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Regel** : Wörter auf `-or` → `(a/e)` ; Wörter auf `-o` → `(o/a/e)`. Endungen in
alphabetischer Reihenfolge innerhalb der Klammern.
**Zusammenziehungen Artikel-Präposition** : `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`,
`(o/a/e)s`.
**Bereits epicoene Wörter** : unverändert (`camarada`, `colega`, `responsável`,
`pessoa`).
**Verboten** : `(a)` allein, `/a`, `/o`, `@` (arroba), `x`. Achtung auf den
**falschen Freund `camarade`** (französische Form) : auf pt-BR lautet es **`camarada`**.

### Kastilisches Spanisch (es)

**Angenommene Konvention** : Neutrales `e` (argentinische militante Konvention).

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Regel** : Die Genusendung (`-o`/`-a`) wird durch `-e` ersetzt; Wörter auf
`-or` → Wurzel + `-e` (`lector → lectore`).
**Plural** : `-s` (`compañeres`).
**Artikel / Determinierer** : `le` (neutraler Singular), `les` (neutraler Plural).
**Kongruente Partizipien** : `informade`, `conectade`, `active`.
**Bereits epicoene Wörter** : unverändert (`camarada`, `colega`, `responsable`,
`persona`).
**Verboten** : `(a)`, `/a`, `/o`, **die Dreifachform `(o/a/e)` des pt-BR**
(das Spanische verwendet NUR das neutrale `e`), `@` (arroba), `x` (Latinx), und der
**Mediopunkt `·`** (französische Konvention, im Spanischen nicht zu verwenden).

### Italienisch (it)

**Angenommene — offizielle Konvention** : **Asterisk `*` für reguläre Paare,
abgekürzter Schrägstrich für irreguläre Paare.** Diese Konvention ersetzt den
provisorischen Schrägstrich der v1.

#### Reguläre Paare (gemeinsame Wurzel auf `-o`/`-a`) → Asterisk `*`

Wenn Maskulinum und Femininum **dieselbe Wurzel** teilen, wird die Genusendung durch
einen Asterisk ersetzt, in Kohärenz mit dem deutschen Genderstern.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(déjà épicène au sing.)* |

Gilt auch für **Partizipien und kongruente Adjektive**: `stat*` (stato/a),
`ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a),
`benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*`
(questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Irreguläre Paare (verschiedene Wurzeln, Typ `-tore`/`-trice`) → abgekürzter Schrägstrich

Wenn das Femininum nicht die Wurzel des Maskulinums teilt (`lettore` → `lettric-e`),
ist der Asterisk **fehlerhaft** (`lettor*` würde ein nicht existierendes Femininum
`lettora` suggerieren). Man verwendet daher die **abgekürzte Schrägstrichform**, den im
Depot attestierten *House Style*.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Irregulärer Plural** : `lettori/trici`, `amministratori/trici`,
`coordinatori/trici`.
**Artikel** : `il/la`, `del/la`, `al/la`, `dal/la` (abgekürzte Form), `un*` für
`uno/una`.
**Bereits epicoene Wörter** : unverändert (`utente`, `responsabile`, `persona`,
`collega`).

#### Hinweis zum Zeichen `·`

Der Mediopunkt `·` ist **kein** inklusives Markierungszeichen im Italienischen: er dient
ausschließlich als **typografischer Trenner** in E-Mail-Betreffzeilen und Metadatenzeilen
(`Email · ID · Genere`). Er ist niemals zur Genusmarkierung zu verwenden.

**🚫 Absolut verboten** : **`camerata` / `camerati` / `cameratesco`** — faschistische
interne Anrede (PNF, MSI, CasaPound, Forza Nuova, FdI). `compagn*` und seine Varianten
verwenden. **Dieses Verbot wird in der CI getestet** (`i18n.test.js` und
`mail-strings.test.ts`).
**Weitere verbotene Formen** : `(a)`/`(o)` Klammern, Dreifach-`/trice/e`, Suffix
`/x`, Mediopunkt `·` als Genusmarkierung.

**Militante Begründung** : Der Asterisk (*asterisco*) ist in anarchistischen und autonomen
italophonen Milieus belegt (Carmilla, DinamoPress, InfoAut, Wu Ming) und bietet visuelle
Kohärenz mit dem deutschen Genderstern. Der abgekürzte Schrägstrich für irreguläre Paare
vermeidet fehlerhafte Feminina und bleibt dabei lesbar.

### Katalanisch (ca)

**Angenommene Konvention** : Dreifache Suffix-Endung `-a-e` + neutraler Artikel `le`.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Akzeptierte Klammerform** für Zusammenziehungen:
`lector(a/e)`, `coordinador(a/e)`.
**Neutraler Determinierer** : `le` (`le lector-a-e`).
**Plural** : `-s` oder kombinierte Form `els-les-les` / `als-a les-a les`.
**Bereits epicoene Wörter** : unverändert.

> Das Katalanische verwendet auch den Punt volat `·` in der **Geminate `l·l`**
> (`col·lectiu`, `cancel·lada`, `sol·licitud`): das ist eine **Standardorthografie des
> Katalanischen**, die nichts mit Inklusivität zu tun hat. Sie ist nicht zu ändern.

### Esperanto (eo)

**Angenommene Konvention** : Infix `-in-` durch Bindestriche sichtbar gemacht + neutrales
Pronomen `ri`.

| Base | Forme AnarBib |
|---|---|
| leganto (lecteur·rice) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Nicht-binäre Variante** : Suffix `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Neutrales Pronomen** : `ri`.
**Plural** : `-j` (`legant-in-oj`).

### Niederländisch (nl)

**Status: PROVISORISCH — von der Gemeinschaft zu validieren.**

**Provisorische Ausrichtung** : Vorhandene **neutrale Rollenformen** bevorzugen statt
typografischer Markierung.

| Concept | Forme provisoire |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Provisorische Regeln** : genusmarkierte Suffixe `-ster`/`-e` vermeiden, wenn eine neutrale
Form vorhanden ist; nicht-binäres Pronomen `die` (oder `hen`/`hun`) — **Gebrauch noch nicht
festgelegt**.

> ⚠️ Diese Konvention ist **nicht** endgültig. Sie muss von niederländischsprachigen
> militanten Sprecher*innen validiert werden, bevor sie festgeschrieben wird. Bis dahin
> bei den neutralen Formen bleiben.

### Griechisch (el)

**Status: KONVENTION FESTZULEGEN.**

Es gibt **keinen typografischen Konsensstandard** für inklusive Schreibweise im
Griechischen. **Keinen Marker von Amts wegen vorschlagen.** Die Konvention wird
**mit einer griechischsprachigen militanten Person** festgelegt, die dem Projekt
beitritt.

**Übergangsansatz** (in der Zwischenzeit) : Doppelformen oder vorhandene neutrale Formen
(`αναγνώστης/στρια`, `συντονιστής/στρια`), monotonisches Griechisch, 2. Person Singular
für das Duzen der Leser*in (Siezen für das Team). Akronym DSGVO → `ΓΚΠΔ`.

> ⚠️ Jeder Vorschlag eines systematischen inklusiven typografischen Markers für das
> Griechische ist **verfrüht**, solange keine hellenophonen militanten Kontaktpersonen
> dem Projekt beigetreten sind.

---

## Politische Referenzbegriffe

### Genoss*in / Camarade / Compagn·e

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

### Leser*in / Lecteur·rice

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

### Bibliothekar*in / Bibliothécaire

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

### Administrator*in / Administrateur·rice

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

## Verbotene Begriffe

### Politisch markiert (absolutes Verbot)

| Begriff | Sprache | Grund |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Faschistische interne Anrede (PNF, MSI, CasaPound, Forza Nuova, FdI). **In CI getestet.** |
| `Compas` *(unübersetzt)* | 🇩🇪 de | Hispanopher Neologismus unübersetzt gelassen — `Genoss*in`/`Genoss*innen` verwenden. |

### Bürokratische oder ungeeignete typografische Konventionen

| Form | Betroffene Sprachen | Warum |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Verwaltungsform, nicht militant. |
| `@` (arroba) | pt-BR, es | Veraltet, Problem mit Barrierefreiheit (Screenreader). |
| `x` (Latinx) | es, pt-BR | Durch neutrales `e` im zeitgenössischen militanten Gebrauch abgelöst. |
| `(e)`, getrenntes `-e` | fr | Konvention vor 2010, durch den Mediopunkt ersetzt. |
| `Genderdoppelpunkt` (`:innen`) | de | Gültig, aber aus Kohärenzgründen mit `*` nicht übernommen. |
| `he/she`, `s/he`, `(s)he` | en | `they/them` im Singular bevorzugen. |
| Dreifach `(o/a/e)` | es | Dem pt-BR vorbehalten; das Spanische verwendet nur das neutrale `e`. |
| Mediopunkt `·` als Genusmarkierung | es, it, ca | Französische Konvention; andernorts ist `·` nur ein Trenner (oder die Geminate `l·l` im ca). |
| Dreifach `/trice/e`, Suffix `/x` | it | Fehlerhafte Formen; abgekürzten Schrägstrich `/trice` verwenden. |

---

## Verfahren für künftige Ergänzungen

### Beim Hinzufügen eines neuen i18n-Schlüssels

1. **Identifizieren** des zu übersetzenden Worts/Ausdrucks. Handelt es sich um einen
   genusmarkierten Begriff?
2. **Wenn ja, die epicoene Form wählen, wenn sie vorhanden ist** (`camarada` pt-BR,
   `responsable` fr, `utente` it…).
3. **Andernfalls die oben festgelegte Sprachkonvention anwenden**.
4. **Für das Italienische**: reguläres Paar (Asterisk) und irreguläres Paar (abgekürzter
   Schrägstrich) unterscheiden.
5. **Die Kohärenz** mit dem Rest der Datei prüfen.
6. **Alle 10 Sprachversionen in einem einzigen Durchgang ausfüllen.** Ein teilweise
   übersetzter Schlüssel ist ein Fehler. Die **Schlüsselparität** zwischen den 10
   Sprachversionen ist obligatorisch.

### Beim Gegenlesen einer bestehenden Übersetzung

1. Die **verbotenen** Marker erkennen (`(a)`, `@`, `camerata`, Mediopunkt außerhalb
   fr/ca-Geminate, Dreifach-`/trice/e`…).
2. Sie durch die offizielle Form der Sprache ersetzen.
3. Die Kohärenz Singular/Plural prüfen.
4. Die sprachübergreifende Kohärenz für denselben Schlüssel prüfen.

### Beim Anfordern einer Übersetzung von einer KI

Diese Charta immer als Kontext mitliefern, die erwartete Konvention für die Zielsprache
und die verbotenen Begriffe angeben, die epicoenen Formen bevorzugen, und das Ergebnis
**vor der Integration überprüfen**.

---

## Testabdeckung (CI)

- `src/tests/i18n.test.js` testet die **Schlüsselparität** und die **Konformität** von
  **8 Sprachversionen** : `pt-BR, fr, en, de, it, es, ca, eo`. Es enthält den blockierenden
  Test „das Italienische darf niemals camerata/camerati enthalten".
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) testet die
  E-Mail-Zeichenketten: Parität, verbotene Begriffe (camerata), Interpolation, Fallback.
- ⚠️ **`nl` und `el` werden NICHT vom CI-Gate abgedeckt**: ihre Schlüsselparität und
  ihre Konformität sind nicht automatisch garantiert. **Backlog**: sie zu `i18n.test.js`
  hinzufügen, sobald ihre Konventionen festgelegt sind.

---

## Weiterentwicklung der Charta

Diese Charta ist ein lebendiges Dokument. Sie kann nach folgenden Grundsätzen geändert
werden:

- **Ergänzung politischer Referenzbegriffe** : durch kollektiven, im Depot dokumentierten
  Beschluss (Issue oder Pull Request).
- **Änderung der Konvention einer Sprache** : erfordert die Beteiligung von mindestens einer
  militanten Muttersprachler*in der betreffenden Sprache. Die Änderung muss politisch und
  technisch begründet sein.
- **Festlegung der provisorischen (`nl`) oder noch zu definierenden (`el`) Konventionen** :
  folgt demselben Protokoll — eine lokale, begründete, von einheimischen Kontaktpersonen
  validierte militante typografische Entscheidung, dann in diese Charta reversiert und zum
  CI-Gate hinzugefügt.
- **Hinzufügen einer neuen Sprache** : gleiches Protokoll.

---

*Charta v2 verfasst am 2026-06-05 nach dem Audit des inklusiven Sprachgebrauchs der
zehn Sprachversionen und der E-Mail-Zeichenketten. Referenzdokument, das in
`notes-audit/` des Depots zu committen ist. Ersetzt die v1.0 vom 2026-04-28.*
