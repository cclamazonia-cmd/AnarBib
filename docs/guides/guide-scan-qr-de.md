# Anleitung — Scan und QR-Code in AnarBib

> **Für wen ist diese Anleitung.** Für jede*n Genoss*in in der Bibliothek, die
> die Kamera des Handys (oder des Computers) nutzen möchte, um Zeit zu sparen:
> eine lesende Person am Ausweis erkennen, die Daten eines Buches per Barcode
> abrufen oder den Bestand prüfen. Auf Wunsch verfasst — und für das **Gemeingut**
> des Netzwerks.
>
> **Geist.** Hier überwacht und bewertet dich nichts. Das Lesen der Codes geschieht
> **100 % auf deinem Gerät**: kein Kamerabild wird irgendwo hingesendet. Die
> Werkzeuge sind da, um dir Autonomie zu geben, nicht um dich zu fesseln. Wenn
> etwas nicht funktioniert, **bricht der Katalog niemals zusammen** — im
> schlimmsten Fall tippst du einfach per Hand.
>
> Teil des **Wissens-Gemeinguts** der gegenseitigen Hilfe (vgl. das Rahmenpapier
> « gegenseitige Hilfe bei der Katalogisierung »). Diese Anleitung entsteht in der
> Sprachgemeinschaft: Wer eine Version in einer anderen Sprache möchte, erstellt
> sie parallel — nicht als Top-down-Übersetzung.

---

## Was sich scannen lässt

AnarBib hat **nur einen Kamera-Scanner**, der an drei Stellen wiederverwendet wird:

| Wo | Was gescannt wird | Wozu |
|---|---|---|
| **Dashboard › Leser*in verwalten** | QR des **Ausweises** | Lesende Person auf Anhieb identifizieren |
| **Katalogisierung** (Buchkarte) | **ISBN-Barcode** | Titel/Autor*innenschaft automatisch abrufen |
| **Dashboard › Inventur** | QR der **Exemplar-Etiketten** | Bestand prüfen (Inventur) |

In allen Fällen: Die Kamera öffnet sich innerhalb von AnarBib, liest den Code —
fertig. Es muss keine App installiert werden. Wer möchte, kann **AnarBib zum
Startbildschirm hinzufügen** (Browsermenü › « Zum Startbildschirm hinzufügen »):
Es öffnet sich dann wie eine App im Vollbild, bleibt aber die Website.

---

## 1. Leser*innen-Ausweis

**Wer den Ausweis erstellt:** die lesende Person selbst, in ihrem Konto
(`/conta`), wenn die Bibliothek diese Funktion aktiviert hat. Sie erzeugt einen
QR-Code und kann ihn als PNG oder PDF herunterladen. Der QR enthält nur einen
**opaken Code** — keinen Namen, keine persönlichen Daten.

**So verwendest du ihn an der Theke:**

1. Geh zu **Dashboard › Leser*in verwalten**.
2. Klicke auf **« Karte scannen »** und richte die Kamera auf den QR des Ausweises.
3. AnarBib löst den Code auf und zeigt, **wer** die Person ist (und ob eine aktive
   Einschränkung vorliegt). Bereit für Ausleihe, Rückgabe usw.

> **« Karte nicht erkannt »?** Fast immer ist es ein **alter Ausweis**.
> Wenn eine Person einen neuen Ausweis erzeugt, wird der vorherige **widerrufen**
> (Sicherheitsmaßnahme). Bitte sie, den aktuellen Ausweis zu erzeugen/herunterzuladen.
> Seit dem 15.06 weist das System in diesem Fall selbst darauf hin: « Ausweis ersetzt,
> bitte einen neuen erzeugen ».

---

## 2. ISBN beim Katalogisieren scannen

Beim Erfassen eines Buches mit Barcode (ISBN) lässt sich das manuelle Eintippen
vermeiden:

1. Öffne in der Buchkarte (Katalogisierung) das Panel zur **Metadatensuche**.
2. Klicke auf **« ISBN scannen »** und richte die Kamera auf den **Barcode** auf
   der Rückseite des Buches.
3. Die Nummer wird automatisch ins ISBN-Feld übernommen und AnarBib **sucht die
   Daten** (Titel, Autor*innenschaft…) in öffentlichen Quellen. Du prüfst und
   passt an — der Katalog gehört euch.

> **Tipp zum Gerät.** Barcodes sind « anspruchsvoller » als QR-Codes. **Das Handy
> liest in der Regel viel besser** als die Webcam eines Schreibtischcomputers
> (Fokus und Kameraauflösung). Wenn die Webcam nichts erfasst, nicht hartnäckig
> bleiben: ISBN per Hand eintippen — das Ergebnis ist dasselbe.

---

## 3. Bestandsinventur

Exemplar für Exemplar prüfen, was tatsächlich im Regal steht — und das mit dem
vergleichen, was das System für die Bibliothek vermerkt hat.

**Vorher:** Die Exemplar-Etiketten müssen **QR-Codes** enthalten. Drucke die
Etiketten mit QR unter **Katalogisierung › Etiketten** (dort gibt es eine Option
« QR-Codes einschließen »). Jeder QR verweist auf das jeweilige Exemplar.

**Inventur durchführen:**

1. Geh zu **Dashboard › Inventur** (sichtbar für *Bibliothekar*in* und
   *Koordinator*in*).
2. **« Inventur starten »** — öffnet eine Sitzung und zeigt, wie viele Exemplare
   die Bibliothek hat.
3. Die Kamera bleibt geöffnet: **gehe die Exemplare durch**, einen QR nach dem
   anderen. Bei jedem Scan ertönt ein **Piepton** und der Zähler steigt. Die
   Kamera muss zwischen zwei Büchern nicht geschlossen und wieder geöffnet werden.
   - ✓ grün = Exemplar gehört zum Bestand, gezählt.
   - « Bereits gescannt » = dieses Exemplar wurde schon erfasst (kein Problem,
     wird nicht doppelt gezählt).
   - ⚠ « Nicht im Bestand » = ein Exemplar, das **nicht** zu dieser Bibliothek
     gehört (Fremdexemplar).
4. Wenn ein QR beschädigt ist, kann die **URL des Etiketts oder die Exemplar-ID
   per Hand eingegeben** werden.
5. **« Abschließen und Bericht anzeigen »** — schließt die Sitzung und zeigt:
   - **Vorhanden** (gescannt und im Bestand),
   - **Fehlend** (im Bestand, aber nicht gescannt → suchen / aussondern),
   - **Fremd** (gescannt, aber von einer anderen Bibliothek / unbekannt).
6. Exportiere das Ergebnis als **CSV** (für eine Tabelle) oder **PDF** (um die
   Fehlendenliste auszudrucken und die Regale abzusuchen).

> **Pausieren und fortsetzen.** Große Inventur? Du kannst die Sitzung später
> abschließen. Wenn du mittendrin aufhörst, bleibt die Sitzung **in Bearbeitung**
> und erscheint unter « Laufende Sitzungen », um von dort **fortzusetzen**.

---

## Praktische Fragen

**Muss ich etwas installieren?** Nein. Es ist die Website selbst. Optional:
« Zum Startbildschirm hinzufügen », um sie wie eine App zu öffnen.

**Funktioniert es in meinem Browser?** Ja. In Chrome/Android wird der native
Scanner verwendet (schneller). In **Brave**, **iOS/Safari** und **Firefox** lädt
AnarBib automatisch einen alternativen Scanner — es **funktioniert also auch dort**.
Falls beim ISBN-Scannen in einem dieser Browser « Scannen nicht unterstützt »
erscheint, die Seite neu laden: Der alternative Scanner startet von selbst.

**Die Kamera öffnet sich nicht.** Prüfe, ob du der Website die
**Kamera-Berechtigung** erteilt hast (Schloss in der Adressleiste). Der Browser
gibt die Kamera nur über **HTTPS** frei — `app.anarbib.org` ist es bereits.

**Datenschutz.** Die Dekodierung erfolgt **lokal**. Das Kamerabild wird **an
keinen Server gesendet**. Der QR des Ausweises enthält nur einen opaken Code;
der QR des Etiketts enthält nur die Adresse des Exemplars. Sensible Bestände
(BTL u. ä.) bleiben durch die üblichen Regeln geschützt.

---

## In einem Satz

Die Kamera ist **die ausgestreckte Hand**, die dir das Eintippen und Prüfen
erspart — keine Pflicht. Nutze sie, wenn sie hilft; ignoriere sie, wenn nicht.
Und wenn es hakt, ist die Tastatur immer da.

---

*Gemeingut-Dokument von AnarBib. Verbesserungen und Versionen in anderen Sprachen
sind willkommen — parallel von der jeweiligen Sprachgemeinschaft verfasst.*
