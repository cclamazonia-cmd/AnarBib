# Willkommen im AnarBib-Netz

**Willkommensleitfaden für Koordinationen — die ersten dreißig Tage**

*Version 1.0 — 16. September 2026 · Lizenz AGPLv3 · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Zuallererst: was angenommen ist, und was noch nicht

Die Bewerbung deiner Bibliothek wurde von der Koordination des Netzes angenommen. Das
heißt zweierlei, und nur zweierlei:

1. Das Netz erkennt deine Bibliothek als Teil der anarchistischen und libertären Familie
   an, die es beherbergt, und hat dir den Weg der Gründung geöffnet.
2. Dein Konto ist kein Konto einer Antragsteller*in mehr: es ist ein Konto einer
   **Koordination in Gründung**.

Was **noch nicht** geschehen ist: deine Bibliothek ist nicht aktiv. Sie erscheint nicht
im gemeinsamen Katalog, sie nimmt keine Leser*innen auf, sie tauscht nichts mit den
anderen Bibliotheken aus. Sie ist **vor-aktiv**, und du bist es, die sie da herausholt —
nicht allein, und nicht an einem Tag.

> **Das Versprechen dieses Leitfadens.** Du musst keine Bibliothekar*in sein. Du musst
> keine Informatiker*in sein. Du musst wissen, was dein Kollektiv will, und jemanden
> haben, den du fragen kannst, wenn du es nicht weißt. Der Rest ist Klicken.
>
> **Und die goldene Regel: klick ruhig, es geht nichts kaputt.** Die Software zeigt
> unmögliche Übergänge gar nicht erst an, deaktiviert mit einer Erklärung die Knöpfe, die
> eine Regel blockieren würde, und weist unmögliche Kombinationen in der Datenbank zurück.
> Die wenigen Handgriffe, die wirklich nicht rückgängig zu machen sind, stehen in
> Kapitel 9.

**Die Person, mit der du sprichst.** Zu jedem Zeitpunkt dieses Wegs, vor dem Entscheiden
und nicht danach: `anarbib@proton.me`. Das Netz hält es für einen Grundsatz, dass eine
Gründungsentscheidung mit einer Genoss*in besprochen wird, bevor sie zu einem Formular
wird. Zu schreiben ist kein Eingeständnis von Schwäche — es ist der normale Ablauf.

---

## 1. Tag 1 — Anmelden, und verstehen, wo du bist

### 1.1 Sich anmelden

Die Anmeldeseite ist `/login` (Schaltfläche **Anmelden**). Die Adresse `/cadastro` leitet nur dorthin weiter:
wenn ein altes Dokument dich dorthin schickt, ist das nicht dein Fehler.

Wenn du noch das per E-Mail erhaltene vorläufige Passwort benutzt, **ändere es vor allem
anderen**. Solange es nicht geändert ist, bleiben mehrere Aktionen gesperrt — das ist ein
passiver Nachweis, dass das Konto wirklich von einer Person übernommen wurde.

### 1.2 Die zwei Häuser

Das ist das Wichtigste im ganzen Leitfaden, und es lohnt sich, es auswendig zu lernen.

| Wenn die Frage lautet… | gehst du nach… |
|---|---|
| „was haben wir beschlossen?" | **`/biblioteca`** — das kollektive Haus |
| „was mache ich mit dieser Person vor mir?" | **`/painel`** — die Theke |

In `/biblioteca` wohnen die öffentliche Identität, die Geschäftsordnung, das Team, das
Adoptionsprofil, die Übergänge und der Datenschutz: alles, worüber das Kollektiv beraten
hat. In `/painel` wohnt die tägliche Arbeit: Ausleihen, Rückgaben, Einsichten vor Ort,
Vormerkungen, Konten, die auf Freigabe warten.

Das ist keine willkürliche Ordnung. Viele Bibliotheksprogramme vermischen beides, und das
Ergebnis ist, dass die politische Konfiguration in einem Admin-Backoffice versteckt
endet. Hier ist die Beratung auf der einen Seite und der Betrieb auf der anderen.

### 1.3 Die Routen, die du benutzen wirst

| Route | Was es ist | Für wen |
|---|---|---|
| `/criar-conta` | Anmeldung — **die einzige Eingangstür, für alle** | jede Person |
| `/conta` | der persönliche Bereich jeder Leser*in — neun Reiter | jede Person, ihr eigener |
| `/atelier` | die Werkstätten: Gründung und Normdaten | Koordination in Gründung |
| `/painel` | die Theke, die Arbeit des Tages | Team (librarian, Koordination) |
| `/biblioteca` | das kollektive Haus, die Entscheidungen | Team, mit Rechten je Rolle |
| `/catalogacao` | katalogisieren und importieren | Team |
| `/rede` | Verwaltung des Netzes | nur Netz-Admins |

Die Seite **Federação** und die öffentlichen Seiten — Katalog, Werk, Zeitschrift,
Schlagwort, Bibliotheken, Kartografie, FICEDL-Thesaurus — vervollständigen das Ganze. Die
Routen werden nicht übersetzt: sie sind in allen zehn Sprachen dieselben.

> **Du gehst nie in das Konto einer anderen Person.** Alles, was das Team für eine
> Leser*in tun muss, findet sich im Painel. Wenn du dich dabei ertappst, dich „anmelden
> als" jemand zu wollen, dann ist das, was du suchst, im Painel, Reiter **Leser*in**
> (`leitor`).

---

## 2. Tage 1 bis 3 — Die Gründungswerkstatt

Die Gründung ist ein Weg in `/atelier`. Du kannst jederzeit speichern und später
zurückkommen: zwischen zwei Sitzungen geht nichts verloren. **Du hast 60 Tage**, und eine
Erinnerung per E-Mail kommt am 45.

### 2.1 Etappe 0 — das Adoptionsprofil, der Gründungsakt

Vor allen anderen Abschnitten fragt die Software, wo sich deine Bibliothek auf **vier
unabhängigen Achsen** verortet. Keine davon ist eine Qualitätsstufe: es sind Weisen zu
existieren, und eine kleine Bibliothek, die überall den einfachen Modus wählt, ist keine
unfertige Bibliothek.

**Achse 1 — `catalog_mode`, der Katalog**

- `local_only` — der Bestand bleibt zu Hause, dem Netz nicht ausgesetzt. Nützlich während
  einer Einlaufphase, oder wenn ein Teil des Bestands noch nicht veröffentlicht werden soll.
- `network_published` — der Bestand geht in den gemeinsamen AnarBib-Katalog ein.

**Achse 2 — `circulation_mode`, der Ausleihbetrieb**

- `off` — keine in der Software verwaltete Ausleihe: nur Katalog. Das ist der Fall eines
  Archivbestands zur Einsicht.
- `informal` — einfache Ausleihe, ohne Mitgliedsbeitrag und ohne strenge Regeln. Der
  typische Fall einer kleinen militanten Bibliothek, in der alle einander kennen.
- `full_sigb` — vollständige Ausleihe: Regeln, Vormerkungen, Mitgliedsbeiträge, Sperren.

**Achse 3 — `network_mode`, die Föderation**

- `isolated` — die Bibliothek existiert in AnarBib, tauscht aber nichts aus.
- `observer` — sie empfängt die Ströme des Netzes, sie trägt noch nichts bei.
- `federated` — sie nimmt voll teil.

**Achse 4 — `governance_mode`, die Governance**

- `informal` — keine eigenen Team-Rollen: alle sind Leser*innen. Keine Kooptation, keine
  Karenzzeit, kein Auditprotokoll.
- `staff_roles` — die Rollen `librarian` und `coordenador*a` existieren, vereinfachte
  Kooptation.
- `full_governance` — das Ganze: Kooptation, Karenzzeit, Auditprotokoll, Crons.

### 2.2 Was jede Wahl im Painel anschaltet

Diese Tabelle ist der Grund, warum Etappe 0 vor allem anderen kommt. Die Reiter der Theke
erscheinen oder nicht, je nach der Achse des Ausleihbetriebs:

| Reiter des Painel | Erscheint wenn |
|---|---|
| **Tagesarbeit** (`trabalho-do-dia`) | immer |
| **Aktionen** (`acoes`) | immer |
| **Leser*in** (`leitor`) | immer |
| **Verlauf** (`historico`) | immer |
| **Einsichten vor Ort** (`consultas-locais`) | Ausleihbetrieb `informal` oder `full_sigb` |
| **Ausleihen** (`emprestimos-livro`) | Ausleihbetrieb `informal` oder `full_sigb` |
| **Vormerkungen** (`reservas`) | Ausleihbetrieb `full_sigb` |
| **Sammelausleihen** (`emprestimos-lote`) | Ausleihbetrieb `full_sigb` |
| **Beiträge** (`contribuicoes`) | Mitgliedsbeitrag aktiviert **und** Ausleihbetrieb anders als `off` |

Wenn ein Reiter bei dir nicht erscheint, ist das keine Störung: es ist das Profil, das
dein Kollektiv gewählt hat. Und wenn sich das Profil während der Sitzung ändert, kehrt
das Painel von selbst zur **Tagesarbeit** zurück.

> **Die Entscheidungen sind keine Gefängnisse.** Jede Achse hat ihre Übergangsdoktrin —
> manche schnell, manche langsam, manche unumkehrbar. Der Reiter **Übergänge** ist in
> `/biblioteca` und nicht im Painel: das Profil zu wechseln ist eine kollektive
> Entscheidung, kein Handgriff an der Theke. Manche Übergänge, die mehrere Achsen kreuzen,
> gehen über die Freigabe der Netz-Admins.

### 2.3 Die zehn Abschnitte

Nach Etappe 0 zeigt die Werkstatt nur die Abschnitte an, die dein Profil einschlägig
macht. Eine Bibliothek mit `circulation_mode = off` wird den Abschnitt zum Ausleihbetrieb
nicht sehen: es fehlt nichts, diese Frage stellt sich bei euch einfach nicht.

| Abschnitt | Was entschieden wird | Bedingung |
|---|---|---|
| 1 | Identität — Name, Kurzname, Adresse, Kontakt | immer |
| 2 | Öffnungszeiten und Dienste | immer |
| 3 | Verantwortliche Personen | je nach Governance |
| 4 | Katalogisierungspolitik | immer |
| 5 | Politik des Ausleihbetriebs | wenn der Ausleihbetrieb nicht `off` ist |
| 6 | Politik der Aufnahme von Leser*innen | je nach Governance und Ausleihbetrieb |
| 7 | Politik der E-Mails | immer |
| 8 | Sichtbarkeit und Teilnahme im Netz | wenn das Netz nicht `isolated` ist |
| 9 | Daten und Datenschutz | immer |
| 10 | Erzeugung der Geschäftsordnung | immer |

**Keiner dieser Abschnitte ist eine Frage der Informatik.** Es sind zehn Fragen für die
Versammlung, in der Reihenfolge vorgelegt, in der sie sich gut beantworten lassen. Füll
sie mit dem aus, was das Kollektiv schon beschlossen hat; wo es nichts beschlossen hat,
halt an und trag die Frage in die nächste Sitzung. Die Werkstatt wartet.

### 2.4 Der Abschnitt 10 — das Gerüst der Geschäftsordnung

Am Ende erzeugt die Software ein vorausgefülltes PDF mit all deinen Entscheidungen.
**Dieses PDF ist keine Urkunde.** Es ist ein Gerüst zum Diskutieren: ein Rohstoff der
Beratung. Die Abschnitte, die eine Debatte verdienen, sind als solche markiert.

Der erwartete Weg ist: herunterladen, in die Versammlung tragen, frei ändern, und das
geänderte Dokument als offizielle Geschäftsordnung der Bibliothek wieder hochladen.
Solange es nicht wieder hochgeladen ist, bleibt die Bibliothek vor-aktiv.

> **Ein Punkt der Ehrlichkeit.** „Die Gründung abschließen" bedeutet heute keine
> automatische Aktivierung der Bibliothek. Das ist eine bekannte Lücke der Software, kein
> Fehler von dir. Wenn du am Ende der Abschnitte angekommen bist, schreib an
> `anarbib@proton.me`, damit die Aktivierung gemacht wird — und hak nach, wenn nach
> einigen Tagen niemand antwortet.

---

## 3. Tage 3 bis 7 — Die Seite Biblioteca, das kollektive Haus

Ist die Gründung einmal abgeschlossen, wird `/biblioteca` zu dem Ort, wo das Beschlossene
eingeschrieben bleibt und Bestand hat. Dort schaut man nach, wenn jemand fragt „was
hatten wir denn ausgemacht?".

- **Öffentliche Identität** — was das Netz und die Öffentlichkeit von deiner Bibliothek sehen.
- **Geschäftsordnung** — das Dokument, das ihr angenommen habt, und seine Fassungen.
- **Team** — wer was ist, und über welchen Weg (Kapitel 4).
- **Profil** — die vier Achsen, so wie sie heute stehen.
- **Übergänge** — die Vorschläge zum Profilwechsel und ihre Abstimmung.
- **Datenschutz** — Aufbewahrung der Daten, automatische Bereinigung, DSGVO/LGPD.

**Die Entscheidungen, die diese Woche zu treffen sind**, alle in `/biblioteca`:

1. **Die Sichtbarkeit des Bestands** — öffentlicher Katalog oder nicht, Auftauchen in der
   Bibliotheksgalerie von `anarbib.org`, Präsenz auf der Kartografie des Netzes. Auf der
   Kartografie hat ein Kollektiv, das sich entscheidet nicht zu erscheinen, seine Gründe:
   die Software respektiert sie, und du auch.
2. **Die Politik der E-Mails** — welche Ereignisse eine Nachricht an die lesende Person
   auslösen (Ausleihzyklus, Erinnerungen vor Fälligkeit, Mahnungen bei Verzug) und ob das
   Team eine Kopie erhält. All das lässt sich je Bibliothek an- und ausschalten.
3. **Die Aufbewahrung der Daten** — wie lange der Ausleihverlauf einer Person nach der
   Rückgabe gespeichert bleibt. Das ist ebenso eine politische wie eine rechtliche Frage:
   in einer militanten Bibliothek ist ein Verlauf eine Liste von Lektüren identifizierter
   Personen. Wenig davon aufzubewahren ist eine Form von Schutz.
4. **Der Mitgliedsbeitrag**, wenn es ihn bei euch gibt — und mit ihm der Reiter
   **Beiträge** im Painel.
5. **Der Leser*innenausweis** — ob ihr ihn aktiviert. Er trägt keinen Namen: nur den
   Kurznamen der Bibliothek und einen undurchsichtigen QR-Code, und es ist die lesende
   Person selbst, die ihn erzeugt und neu erzeugt. Das ist mit Absicht so entworfen, damit
   ein verlorener Ausweis nichts darüber erzählt, wer ihn getragen hat.

> **Zum Reiter Datenschutz.** Er kann zwei Meldungen anzeigen, die sich hinsichtlich der
> automatischen Bereinigung widersprechen. Das ist ein bekannter Anzeigefehler. Bevor du
> schließt, dass die Bereinigung aktiv oder inaktiv ist, frag beim Netz nach.

---

## 4. Tage 5 bis 10 — Das Team bilden

### 4.1 Drei Rollen, und nur drei

`Leser*in` · `librarian` (Bibliothekar*in) · `coordenador*a` (Koordination).

Die lokale Rolle „Administrator" wurde im Mai 2026 abgeschafft. Wenn du sie irgendwo
zitiert findest, ist das Dokument veraltet. „Administrator*in des AnarBib-Netzes"
existiert, aber das ist ein **querliegender Status** — es ist nicht die nächste Stufe der
Treppe, und man kommt nicht dorthin, indem man lange genug koordiniert. Es ist ein anderer
politischer Mechanismus, mit eigener Kooptation.

### 4.2 Die Falle, die teuer kommt

**Niemand meldet sich zweimal an.** Alle kommen ein einziges Mal über `/criar-conta`
herein, als Leser*in — auch diejenigen, die zum Team gehören werden.

Team zu werden ist keine neue Anmeldung: es ist eine Kooptation, und sie findet auf dem
bereits bestehenden Konto statt. Wer sich neu anmeldet im Glauben, so „als Team
hereinzukommen", schafft nur ein zweites Konto und ein Problem, das die Koordination
wieder auflösen muss.

**Also ist das Einzige, was du von einer künftigen Team-Person erbitten musst: „schick mir
deine öffentliche ID".**

### 4.3 Der Weg in drei Schritten

Keine Beförderung ist einseitig. Drei verschiedene Personen, drei Handgriffe:

1. **Vorschlagen** — die Koordination schlägt jemanden über die öffentliche ID vor, für
   die Rolle `librarian` oder `coordenador*a`.
2. **Mitzeichnen** — eine andere Person aus dem Team bestätigt. Die betroffene Person ist
   vom Quorum ausgeschlossen: sobald das Team zwei weitere aktive Personen zählt, sind
   zwei Bestätigungen erforderlich.
3. **Annehmen** — die vorgeschlagene Person nimmt an. Ohne diese Zustimmung geschieht
   nichts.

Der Vorschlag **läuft nach 30 Tagen ab**. Eine Zeile als Leser*in schließt sich, die als
Bibliothekar*in öffnet sich: eine einzige aktive Rolle je Bibliothek, und der Verlauf
bleibt.

> **Der kollegiale Sprung.** Standardmäßig muss man, um in den Kreis der Koordination zu
> kommen, durch die Bibliothekar*innen-Rolle gegangen sein. Für ein horizontales Kollektiv
> entspricht diese Zwischenstufe nichts: eine einzige Entscheidung der Versammlung
> verlangte zwei Wege in der Software. Daher der Sprung — jemanden direkt von Leser*in in
> die Koordination vorzuschlagen —, den es als **Option der Bibliothek** gibt,
> standardmäßig deaktiviert, die dein Kollektiv aktiviert, wenn es will. Er verkürzt die
> Treppe, nie die Zustimmungen.

### 4.4 Das Team verlassen

- **Karenzzeit von 7 Tagen** — ein Austritt aus dem Team ist nicht sofort wirksam; die
  Person geht durch einen Zwischenzustand, und das lässt Zeit, miteinander zu reden.
- **Inaktivität** — ein Team-Konto, das sich lange nicht mehr anmeldet, scheidet
  automatisch aus, mit einem Hinweis an die Person 30 Tage vorher und 7 Tage vorher. Der
  Hinweis nach 7 Tagen geht auch an die Koordination, und er wird an die Netz-Admins
  eskaliert, wenn die inaktive Person die letzte Koordination des Hauses ist.
- **Weitergeben** — die Koordination an jemand anderen zu übergeben geschieht über denselben
  Weg in drei Schritten, vor dem Gehen. Lass das nicht bis zum letzten Tag liegen.

---

## 5. Tage 7 bis 20 — Der Bestand

### 5.1 Die drei Wörter, die du brauchst

- **Werk** (*obra*) — der geteilte Datensatz: das Buch als Werk, dasselbe für das ganze
  Netz.
- **Holding** — die Tatsache, dass deine Bibliothek dieses Werk besitzt.
- **Exemplar** — der physische Gegenstand im Regal, mit seinem Etikett, seinem Zustand,
  seiner Geschichte.

Drei Kollektive können dasselbe Buch haben: ein Werk, drei Holdings, mehrere Exemplare.
Deshalb kommt das Korrigieren eines Datensatzes dem ganzen Netz zugute, und deshalb
korrigiert man einen Datensatz mit Sorgfalt.

### 5.2 Drei Stufen des Datensatzes, und keine davon ist die falsche

| Stufe | Geist |
|---|---|
| **Simples** | militante Bibliothek, ohne akademischen Anspruch: Art, Titel, Urheberschaft, Jahr, Verlag, Sprache, Signatur, Standardausleihe, Cover, ISBN |
| **Avançado** | Arbeit einer Bibliothekar*in ohne MARC: Untertitel, Auflage, Reihe, Ort, Seiten, typisierte Beiträge, Schlagwörter, Anmerkungen |
| **Completo** | erschöpfend: ISBD-Zonen, MARC, Normdaten-Identifikatoren, vollständige Provenienz |

**Die Stufe zu wechseln verliert nichts.** Ein von einer niedrigeren Stufe verborgenes Feld
behält seinen Wert. Mach den Test einmal, mit eigenen Augen: das ist es, was überzeugt.

**Fang mit Simples an.** Fünf Datensätze pro Woche in Simples sind mehr wert als ein
perfekter Datensatz pro Monat. Der Bestand existiert nur katalogisiert.

### 5.3 Die einzige Anforderung, die das Netz wirklich stellt

**Kein neues Exemplar ohne Erwerbungsart.** Woher es kommt, wann, gespendet von wem, nach
welchem Ereignis.

Das ist kein gelehrtes Detail. In einer militanten Bibliothek ist die Provenienz die
Geschichte des Kollektivs. Ohne sie wird der Bestand in einer Generation zu einem anonymen
Stapel. Das Netz verlangt von dir nicht, rückwirkend nachzuarbeiten — es verlangt, dass
die Schuld von jetzt an aufhört zu wachsen.

### 5.4 Der Rest von `/catalogacao`, wenn du ihn brauchst

Massenimporte, Dublettenassistent in drei Schritten, Cover-Suche, externe
Metadatenquellen, Upload mit OCR im Browser, Inventur durch Einlesen der QR-Etiketten,
Zeitschriften und ihre Bestandsangaben. Nichts davon ist in der ersten Woche nötig. Es ist
da, wenn es so weit ist.

### 5.5 Schlagwörter und FICEDL-Thesaurus

AnarBib bringt den **FICEDL-Thesaurus** mit: 462 Begriffe, in alle zehn Sprachen
übersetzt, mit der Software ausgeliefert. Er ist ein Gemeingut der Föderation, und er
kommt schon gefüllt an — das ist keine Aufgabe für dich.

Die **lokalen Schlagwörter** gehören umgekehrt jedem Haus: das ist dein Bestand, dein
Vokabular, deine redaktionellen Entscheidungen. Und deine Schlagwörter den FICEDL-Begriffen
**zuzuordnen** ist ein Akt des Kollektivs, kein technischer Vorgang: zu sagen, dass dein
„Gefängnisabolitionismus" dem gemeinsamen Begriff „Gefängnis" entspricht, ist eine
dokumentarische Position. Deshalb kommt die Zuordnung nicht fertig an.

---

## 6. Tage 10 bis 25 — Die Theke

Vier Abläufe, und das Painel ordnet sie:

- **Ausleihe** — Ausgabe, Rückgabe (auch teilweise), Verlängerung. Die Verlängerung kann
  Stück für Stück erfolgen: wenn die Person zwei der drei Bücher beendet hat, wird nur das
  dritte verlängert.
- **Rückgabe** — vollständig oder Zeile für Zeile. Eine Massenaktion scheitert nie
  stillschweigend: was nicht durchging, wird mit seinem Grund aufgelistet.
- **Einsicht vor Ort** — die Person will etwas an Ort und Stelle sehen, man handelt einen
  Termin aus. **Die Aushandlung endet nach drei Hin und Her**: darüber hinaus schickt euch
  die Software ans Telefon. Das ist so gewollt — eine Aushandlung, die darüber hinausgeht,
  ist kein Softwareproblem.
- **Vormerkung** — bis zur tatsächlichen Abholung, die die Vormerkung in eine Ausleihe
  verwandelt.

Daneben, im Painel: die **Freigaben** der Anmeldungen von Leser*innen (hier entscheidet
ihr, wer hereinkommt), die **Kaution**, wenn euer Haus sie praktiziert, die **Beiträge**,
die **Lesenotizen**, die **Veranstaltungen**.

> **Ein bekannter Fehler.** Der Knopf „Ausleihen öffnen" bei bestimmten Aufgaben der
> Tagesarbeit führt zu einem leeren Reiter. Das liegt nicht an dir. Geh direkt über den
> Reiter **Ausleihen** (`emprestimos-livro`).

---

## 7. Tage 20 bis 30 — Die Föderation

Die Seite **Federação** hat acht Reiter: **Início**, **Círculos**, **Diretório**,
**Assembleias**, die Zeitung **Rizoma**, **Carta/Boletim**, **Apoio mútuo** und **Comuns**.

Das ist der Teil der Software, der kein SIGB ist. Er existiert, weil das Projekt kein
„SaaS für Bibliotheken" sein will: in AnarBib einzutreten heißt, in ein gemeinsames
politisches Projekt einzutreten, und ein Netz, das nur bibliografische Datensätze
austauscht, ist kein Netz.

Was es in dieser letzten Woche zu tun gibt, ohne Eile:

1. **Von `observer` zu `federated` wechseln**, wenn ihr das beschlossen habt — und nur
   dann. Einige Monate im Beobachtungsmodus ins Netz einzutreten ist eine achtbare
   Entscheidung.
2. **Euren Eintrag im Diretório ausfüllen**, damit die anderen Häuser wissen, wer ihr seid
   und wie sie mit euch sprechen können.
3. **Über die Kartografie entscheiden** — mit genauer Adresse erscheinen, nur mit der
   Stadt, oder nicht erscheinen. Keine der drei Antworten muss begründet werden.
4. **Die Círculos und die Assembleias anschauen**, um zu wissen, wo die Entscheidungen des
   Netzes fallen.
5. **Wenn ihr den Katalog veröffentlicht**, mit dem Netz klären, was der OAI-PMH-Punkt für
   euch bedeutet — über ihn können andere Kataloge euren abernten.

Die Seite `/rede` ist die Verwaltung des Netzes im eigentlichen Sinne, den Netz-Admins
vorbehalten. Eine Bibliothek zu koordinieren gibt keinen Zugang dazu, und das ist gewollt.

---

## 8. Die zehn Entscheidungen, die nicht technisch sind

Schneid diese Liste aus und trag sie in die Versammlung. Keine dieser Antworten steckt in
der Software: die Software zeichnet nur auf, was ihr antwortet.

1. Wo verorten wir uns auf den vier Achsen des Profils?
2. Ist unser Katalog öffentlich?
3. Leihen wir aus, und zu welchen Bedingungen?
4. Wer kann sich als Leser*in anmelden, und wer gibt frei?
5. Haben wir einen Mitgliedsbeitrag? Eine Kaution?
6. Wie lange bewahren wir den Leseverlauf der Personen auf?
7. Wer gehört zum Team, und aktivieren wir den kollegialen Sprung?
8. Erscheinen wir auf der Kartografie, und mit welcher Genauigkeit?
9. Nehmen wir an den Versammlungen des Netzes teil, und wer vertritt uns dort?
10. Wie ordnen wir unsere Schlagwörter dem gemeinsamen Thesaurus zu — und was weigern wir
    uns zuzuordnen?

---

## 9. Was nichts kaputtmacht, und was ein zweites Lesen verlangt

**Macht nichts kaputt:** überall klicken, alle Reiter öffnen, die Stufe des Datensatzes
wechseln, um zu sehen, einen Abschnitt halb speichern, eine Person vorschlagen und den
Vorschlag ablaufen lassen, den kollegialen Sprung aktivieren und deaktivieren, von
`observer` zu `federated` wechseln, einen Datensatz korrigieren.

**Verlangt ein zweites Lesen, weil es nicht rückgängig zu machen ist oder teuer kommt:**

- **Ein Konto löschen** — und Achtung: auf Portugiesisch unterscheidet die Software
  **APAGAR** (den Verlauf leeren) und **EXCLUIR** (das Konto entfernen), mit zwei
  verschiedenen Bestätigungswörtern. In den neun anderen Sprachen fallen beide auf dasselbe
  Wort — auf Deutsch auf **LÖSCHEN**. Lies den ganzen Satz, bevor du tippst, nicht nur das
  verlangte Wort.
- Einen Verlauf löschen — die Daten kommen nicht zurück.
- Die Profilübergänge, die im Reiter Übergänge als unumkehrbar markiert sind.
- Einen Bestand im Netz veröffentlichen, den das Kollektiv nicht zu veröffentlichen
  beschlossen hat.
- Jemanden aus dem Team entfernen — die Karenzzeit von 7 Tagen existiert genau dafür.

---

## 10. Wo um Hilfe bitten, und wie zurückgeben

**Um Hilfe bitten:** `anarbib@proton.me`. Sag, auf welchem Bildschirm du bist und was du
zu sehen erwartet hast. Es gibt keine dumme Frage: die Software wurde von einer Person
geschrieben, und jedes „ich habe es nicht gefunden", das ankommt, ist ein erkannter Fehler.

**Ein Ritual, das funktioniert.** Eine halbe Stunde pro Woche, mit dem Team, drei feste
Fragen:

> was habe ich auf dem Bildschirm nicht gefunden? · was habe ich getan, ohne es zu
> verstehen? · was hat der Software gefehlt?

Die Antworten speisen eine Lückenliste, die zur nächsten Tagesordnung wird — und ein
Material zum Beitrag für das Projekt. Es ist die einzige Vorrichtung, die den Gebrauch bis
zum Code hinaufträgt.

**Zurückgeben, ohne zu programmieren.** Die Datei `AIDER.md`, im Wurzelverzeichnis des
Repositoriums, listet die offenen Aufgaben auf, die keinen Code verlangen: Übersetzung,
Korrekturlesen der inklusiven Schreibweise, Dokumentation, Zuordnung von Schlagwörtern,
Testen von Bildschirmen. AnarBib steht unter AGPLv3 und hat heute nur eine einzige
Maintainer*in — das ist seine wichtigste Verletzlichkeit, und sie wird ausgesprochen statt
verschwiegen.

---

## 11. Die dreißig Tage auf einer Seite

| Wann | Was | Wo |
|---|---|---|
| Tag 1 | Anmelden, das Passwort ändern, umherspazieren ohne etwas zu ändern | `/login`, `/conta` |
| Tage 1–3 | Etappe 0: die vier Achsen, im Kollektiv entschieden | `/atelier` |
| Tage 3–5 | Abschnitte 1 bis 9 | `/atelier` |
| Tag 5 | Abschnitt 10: das Gerüst der Geschäftsordnung herunterladen | `/atelier` |
| Tage 5–10 | Die Geschäftsordnung in die Versammlung tragen, ändern, wieder hochladen | Versammlung, dann `/atelier` |
| Tage 5–10 | Die öffentlichen IDs sammeln, die Kooptationswege eröffnen | `/biblioteca`, Reiter Team |
| Tage 7–20 | Erste Datensätze im Modus Simples, alle mit Provenienz | `/catalogacao` |
| Tage 10–25 | Erster Tag an der Theke in Eigenständigkeit | `/painel` |
| Tage 20–30 | Eintrag im Diretório, Kartografie, Netzmodus | Federação, `/biblioteca` |
| Tag 30 | Ans Netz schreiben: was gefehlt hat, was getäuscht hat | `anarbib@proton.me` |

---

*Diesen Leitfaden gibt es in zehn Sprachen: pt-BR, fr, es, en, it, de, ca, eo, nl, el. Er
beschreibt den Stand der Software im September 2026 und wird korrigiert, wenn sich die
Software ändert — wenn ein Bildschirm nicht dem entspricht, was hier steht, dann irrt der
Leitfaden, und das zu sagen ist ein Beitrag.*

**Willkommen.**
