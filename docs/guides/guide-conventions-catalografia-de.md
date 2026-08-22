# Merkblatt — Einen Namen schreiben, einen Titel schreiben

> **Übersetzung zur Durchsicht.** Diese Fassung wurde aus dem Französischen
> übersetzt, damit sie jetzt existiert und nicht erst in sechs Monaten. Wenn du
> diese Sprache besser liest, als die Übersetzung sie schreibt, korrigiere sie:
> das hier ist ein Gemeingut, kein abgeschlossener Text.

> **An wen sich dieses Merkblatt richtet.** An dich, die oder der
> katalogisiert. Es sammelt, was im Moment der Eingabe entschieden wird: wie
> ein Name geschrieben wird, wo ein Namenspartikel abgetrennt wird, was mit
> einer Körperschaft geschieht, und warum ein leeres Feld mehr wert ist als ein
> geratenes.
>
> Das ausführliche *Warum* steht anderswo, im Entscheidungsregister, Abschnitt
> `CONV`. Hier wird katalogisiert.

## Die Regel in einem Satz

**Eine einzige Wahrheit in der Datenbank, mehrere Darstellungen.** Du gibst die
Katalogisierungsform ein; Großschreibung, die Reihenfolge Vorname-Nachname und
bibliografische Formatierungen werden bei Anzeige und Export **berechnet**.
Gib sie niemals von Hand ein.

Daher kommt die ganze Unordnung, die wir gerade beheben: Zugangspunkt,
Anzeigeform und Exportform wurden **in dasselbe Feld** gelegt, zu
unterschiedlichen Zeiten, von unterschiedlichen Händen.

---

## 1. Der Name einer Person

### Die Sortierform gilt

Das Feld **«Sortierform»** ist die Wahrheit. Die **«Standardform»** leitet sich
automatisch daraus ab, durch einfaches Umdrehen an der Komma-Stelle. Niemals
umgekehrt.

| Du schreibst in «Sortierform» | Die App zeigt |
|---|---|
| `Kropotkin, Pjotr` | Pjotr Kropotkin |
| `Malatesta, Errico` | Errico Malatesta |

### Natürliche Schreibung, nie in Versalien

**`Kropotkin, Pjotr` — nie `KROPOTKIN, Pjotr`.**

Versalien beim Nachnamen sind eine **bibliografische Zitierkonvention** (ABNT),
kein Datum. Sie werden beim Export ergänzt, zur Laufzeit. Sie selbst zu tippen
macht sie nicht wahrer: es zerstört die Information über die Groß- und
Kleinschreibung, die sich danach nicht rekonstruieren lässt — `de Sousa` und
`De Sousa` sind nicht mehr unterscheidbar, wenn alles in Versalien steht.

### Wo trennen: das Namenspartikel

**Entscheidend ist die Sprache des NAMENS, nicht das Geburtsland.** Eine
argentinische Person kann einen italienischen Namen tragen.

| Sprache des Namens | Das Partikel… | Beispiel |
|---|---|---|
| Portugiesisch, Französisch | **wandert ans Ende**, hinter den Vornamen | `Sousa, Manuel Joaquim de`<br>`Beauvoir, Simone de`<br>`Jong, Rudolf de` |
| modernes Italienisch, Afrikaans, Niederländisch | **bleibt davor** | `Di Filippo, Luis`<br>`De Amicis, Edmondo`<br>`Van der Walt, Lucien` |

Luis Di Filippo ist der Lehrbuchfall: Argentinier, italienischer Name, also
`Di Filippo, Luis` — und nicht `Filippo, Luis Di`.

> **Im Deutschen** bleibt das Adelspartikel beim Nachnamen und wird nicht zum
> Ordnungswort: `Humboldt, Alexander von`.

### Was das Werkzeug nicht entscheiden kann

**Doppelnachname oder Doppelvorname?** `García Lorca` ist ein spanischer
Doppelnachname (nicht trennen); `Jean-Marie` ist ein Doppelvorname. Keine
Funktion unterscheidet beides. Im Zweifel **frag nach**, statt zu entscheiden:
genau solche Fälle gehen in die Prüfliste.

---

## 2. Eine Körperschaft ist keine Person

**Ein Körperschaftsname hat keine invertierte Form.**

| ✅ | ❌ |
|---|---|
| `Grupo Krisis` | `Krisis, Grupo` |
| `Instituto de Estudos Libertários` | `Libertários, Instituto de Estudos` |
| `CIRA Marseille` | `Marseille, CIRA` |

### Fülle «Normdatentyp» aus

Das Feld existiert und **steuert die Regel**. Auf *Körperschaft* gesetzt,
verhindert es die Inversion. Leer gelassen, schützt nichts den Datensatz: er
wird beim ersten Durchlauf eines Werkzeugs wie eine Person behandelt.

Drei Sekunden Eingabe, die drei Monate Korrektur ersparen.

### Wenn der Datensatz MEHRERE Personen enthält

Das kommt vor — der Import hat solche Fälle erzeugt. `KAISER, William Young
and David E.` ist nicht ein Kaiser mit zwei Vornamen: es sind **William Young**
*und* **David E. Kaiser**, zwei Autoren desselben Buchs.

**Repariere es nicht an Ort und Stelle.** Ein Normdatensatz wird vom ganzen
Netz geteilt: ihn umzubenennen verschiebt den Fehler nur. Geh über die
Normdaten-Werkstatt, Vorschlag vom Typ **Aufspaltung**: der ursprüngliche
Datensatz bleibt erhalten, die anderen werden angelegt, und die Verknüpfungen
zu den Büchern folgen. Beratungsfrist: vierzehn Tage, wie bei einer
Zusammenführung.

---

## 3. Der Titel

### Die Schreibung hängt von der Sprache des Titels ab

Es gibt **keine** universelle Regel. Das Deutsche schreibt seine Substantive
groß: das ist seine **Rechtschreibung**, kein Eingabefehler.

Das Normalisierungswerkzeug setzt nur die **Funktionswörter der Titelsprache**
klein, in nicht-anfänglicher Position. Es bewahrt:

- das **erste Wort**;
- Wörter nach **starker Interpunktion** (`.` `:` `;` `?` `!` und dem
  Untertitel-Gedankenstrich);
- **Abkürzungen und Siglen**.

**Es entfernt ein Import-Artefakt, es schreibt den Titel nicht um.** Wenn es
eine Korrektur vorschlägt, bleibst du diejenige oder derjenige, die oder der
beurteilt, ob ein Wort ein Eigenname ist — das Werkzeug weiß es nicht.

| Vorher | Nachher |
|---|---|
| `Antologia Do Movimento Operário Gaúcho` | `Antologia do Movimento Operário Gaúcho` |
| `Der Einzige Und Sein Eigentum` | `Der Einzige und sein Eigentum` |

### Der Anfangsartikel: verstümmle den Titel nie

`Die Arbeiter` schreibt sich **`Die Arbeiter`**. Nicht `Arbeiter, Die` — das
ist ein Überbleibsel des Zettelkatalogs — und nicht `Arbeiter` allein.

Die Sortierung wird über einen **Zähler nicht-sortierender Zeichen** geregelt
(hier: 4, für `Die `), der den Titel unangetastet lässt.

---

## 4. Sprache und Land

| Feld | Format | Beispiele |
|---|---|---|
| **Sprache** (des Dokuments) | BCP-47-Code | `pt-BR`, `fr`, `es`, `de`, `it` |
| **Land** (der Normdatei) | ISO-3166-1-α-2-Code | `BR`, `FR`, `ES`, `NL` |

Nicht `Deutsch`, nicht `Deutschland`, nicht `deu`. Die Auswahlliste der App
gibt dir den richtigen Code: nutze sie, statt zu tippen.

**Leer bleibt leer.** Wenn du die Sprache nicht kennst, lass das Feld frei.
Eine unbekannte Sprache ist eine ehrliche Information; eine falsche Sprache
steuert anschließend die Schreibung des Titels und die Ansetzungsregel des
Namens — sie verbreitet den Fehler, statt ihn einzugrenzen.

---

## 5. Die Daten

Zwei ganze Zahlen und ein **Qualifikator**:

| Qualifikator | Wann |
|---|---|
| `exact` | das Datum steht fest |
| `circa` | ungefähr («um 1876») |
| `uncertain` | die Quellen weichen ab |
| `unknown` | unbekannt |
| `living` | **die Person lebt** |

`living` ist keine Bequemlichkeit: ohne ihn wurden «lebt noch» und
«Sterbedatum unbekannt» verwechselt — was darauf hinauslief, Menschen im
Katalog sterben zu lassen.

Wenn Geburt und Tod beide unbekannt sind, nutze den **Wirkungszeitraum**
(«tätig 1900-1910»). Und wenn die Quellen sich widersprechen, schreib es in die
**Datumsnotiz**: das ist historiografische Reparatur, keine Füllarbeit.

---

## 6. Was du nicht allein entscheidest

Der Normdatenbestand wird **vom ganzen Netz geteilt**. Einen Datensatz zu
ändern heißt, den Katalog mehrerer Bibliotheken zu ändern.

| Handlung | Wo sie geschieht |
|---|---|
| einen Tippfehler in einem Datensatz beheben | direkt |
| zwei doppelte Datensätze **zusammenführen** | Werkstatt — Vorschlag, 14 Tage |
| einen Datensatz **aufspalten**, der zwei enthält | Werkstatt — Vorschlag, 14 Tage |
| eine vom Werkzeug vorgeschlagene Schreibung oder Ansetzung entscheiden | Prüfliste |

In der Werkstatt bleibt ein Vorschlag so lange offen, dass andere Bibliotheken
Einspruch erheben können. Diese Frist ist keine Verwaltungsträgheit: sie ist
das, was den Bestand gemeinsam bleiben lässt.

---

## Im Zweifelsfall

**Lass es leer, statt zu raten.**

Ein leeres Feld stellt eine Frage — jemand wird sie sehen und beantworten. Ein
falsches Feld beantwortet eine Frage, die niemand gestellt hat, und es sieht
richtig aus. Genau dieses finden wir drei Monate später wieder, kopiert in fünf
Katalogen.
