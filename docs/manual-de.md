# AnarBib — Benutzer*innenhandbuch
## Netzwerk libertärer Bibliotheken

*Version 1.1 — September 2026*

---

## 1. Erste Schritte

### Anmelden
Rufe die URL deiner AnarBib-Instanz auf und klicke auf **Entrar** (oder die
Anmeldeschaltfläche in der Sprache deiner Benutzeroberfläche). Gib deine
E-Mail-Adresse und dein Passwort ein.

### Sprache ändern
Die Sprachauswahl befindet sich oben rechts auf jeder Seite (🇧🇷🇵🇹 / 🇫🇷 / 🇪🇸 / 🇬🇧 / 🇮🇹 / 🇩🇪 / 🇳🇱 / 🇬🇷 / Català / Esperanto).
Die Auswahl wird lokal gespeichert.

### Im Katalog suchen
Der **Katalog** zeigt eine Zeile je Werk, in der Sprache deiner Oberfläche, sobald der Titel übersetzt wurde: Autor*in, Titel, Zahl der Ausgaben und die Bibliotheken, die es besitzen.
1. Klicke auf **Ausgaben anzeigen** (das „+“ der Zeile): jede Ausgabe erscheint darunter, mit Cover, Verlag und Jahr. Die Bände eines mehrbändigen Werks sind nummeriert und sortiert.
2. Klicke auf **Exemplare je Bibliothek**: die Verfügbarkeit erscheint Bibliothek für Bibliothek. Bist du angemeldet, ist „deine Bibliothek“ markiert; was anderswo verfügbar ist, aber nicht für dich, wird genau so gesagt.
3. Die Schaltfläche **Flache Liste** kehrt zu einer Zeile je Ausgabe zurück; die Wahl wird gemerkt.

---

## 2. Leser*in — Mein Konto

### Ein Dokument vormerken
1. Suche das Dokument im **Katalog**
2. Klicke auf seine Karteikarte
3. Ist das Dokument verfügbar, klicke auf **Ausleihe vormerken**
4. Du kannst auch in den Reiter **Vormerkungen** deines Kontos gehen und die
   lokale Signatur eingeben

### Ausleihungen verfolgen
Der Reiter **Laufende Ausleihungen** zeigt deine aktiven Ausleihungen mit:
- Ausleihdatum und Rückgabefrist
- Einer Schaltfläche **Verlängern** (wenn Verlängerung erlaubt ist)
- Hinweis auf eine eventuelle Überschreitung der Frist

### Eine Ausleihung verlängern
Klicke auf **Verlängern** in der Liste deiner Ausleihungen. Die Verlängerung
kann verweigert werden, wenn:
- Die Ausleihung bereits einmal verlängert wurde
- Die Ausleihung überfällig ist
- Eine andere Leser*in dasselbe Dokument vorgemerkt hat

### Kontostatusleiste
Oben auf der Seite **Mein Konto** zeigt eine farbige Leiste den Status deines
Kontos:
- ✓ **Grün** : Konto aktiv, alles in Ordnung
- ⚠ **Orange** : Achtung (überfällige Ausleihung, Passwort muss geändert werden)
- ⛔ **Rot** : Konto eingeschränkt (kontaktiere deine Bibliothek)

### Verlauf
Der Reiter **Verlauf** listet deine früheren Vormerkungen und Ausleihungen auf.
Du kannst auf den Titel klicken, um die Karteikarte des Dokuments zu sehen, und
Einträge **Ausblenden**, die du nicht mehr sehen möchtest.

### Dein Konto schützen: die Zwei-Faktor-Authentifizierung
Nach dem Passwort kann AnarBib einen sechsstelligen Code abfragen, der sich alle 30 Sekunden ändert. Der Code kommt aus einer freien Authentifizierungs-App, die offline funktioniert: Aegis oder FreeOTP+ unter Android, FreeOTP oder 2FAS auf dem iPhone, KeePassXC auf dem Computer. Keine SMS, kein externer Dienst.

**Ab dem 1. Januar 2027 Pflicht für die Teams** (Netzwerkverwaltung, Koordinationen, Bibliotheksteams); für Lesekonten freiwillig.

So aktivierst du sie:
1. Öffne **Mein Konto → Persönliche Daten**. Klicke unter der Passwortänderung auf **Zwei-Faktor-Authentifizierung aktivieren**.
2. Gib dem Gerät einen Namen (zum Beispiel „Telefon“) und scanne den QR-Code mit der App. Ohne Kamera gibst du den angezeigten Schlüssel von Hand ein.
3. Gib den **sechsstelligen Code** aus der App ein und klicke auf **Bestätigen**.

Danach fragt AnarBib bei jeder Anmeldung nach dem Passwort den Code ab. Hast du mehrere Geräte eingerichtet, wähle das, das du gerade zur Hand hast.

- **Richte ein zweites Gerät ein** (zum Beispiel KeePassXC zusätzlich zum Telefon): Nur so sperrst du dich nicht aus, wenn du eines verlierst.
- **Gerät verloren?** Wende dich an die Netzwerkverwaltung (Matrix oder anarbib@proton.me). Nachdem sie deine Identität auf anderem Weg geprüft hat, entfernt sie deine Geräte; bei der nächsten Anmeldung richtest du ein neues ein.
- Um ein Gerät zu entfernen, klicke neben seinem Namen auf **Entfernen**.
- Ein Teamkonto ohne Gerät muss nach dem 1. Januar 2027 bei der Anmeldung zuerst eines einrichten.
- Niemand von AnarBib wird dich je nach deinem Code oder deinem QR-Code fragen.

---

## 3. Bibliothekar*in — Dashboard

### Tagesarbeit
Das Dashboard generiert automatisch die Prioritätsaufgaben:
- Heute geplante Abholungen
- Neu einzubearbeitende Vormerkungen
- Vormerkungen, die zur Abholung bereit sind
- Überfällige Ausleihungen
- Heute erwartete Rückgaben
- Zu bearbeitende Lesesaalbestellungen

### Vormerkungen verwalten
Der Reiter **Vormerkungen** ermöglicht es:
- Mehrere Vormerkungen auszuwählen (Kontrollkästchen)
- Einen Schritt im Stapel anzuwenden (vorbereiten, Abholung einplanen, bestätigen)
- Vormerkungen zu stornieren

### Ausleihungen verwalten
- **Ausleihung anlegen** : ID oder E-Mail der Leser*in + lokale Signaturen eingeben
- **Vollständige Rückgabe** : ID der Ausleihung eingeben
- **Teilrückgabe** : IDs der einzelnen Exemplare eingeben
- **Gruppenausleihungen** : zusammenfassende Ansicht nach Ausleihung

### Eine Leser*in verwalten
Der Reiter **Leser*in verwalten** ermöglicht es:
- Nach öffentlicher ID, E-Mail oder Name zu suchen
- Das Profil zu ändern (Name, E-Mail, Telefon, Geschlecht, Adresse)
- Den **Zugang einzuschränken** (mit Begründung: Nichtrückgabe usw.)
- Die **Einschränkung aufzuheben**

---

## 4. Katalogisierung

### Eine Dokumentkarteikarte anlegen
1. Gehe zu **Katalogisierung** > Reiter **Dokument**
2. Wähle den **Materialtyp** (Buch, Zeitschrift, Flugblatt, Audio usw.)
3. Fülle die Felder aus (der Einfachmodus zeigt das Wesentliche, der Vollständigmodus
   alle Felder)
4. Benutze **Metadaten suchen**, um über ISBN vorzubefüllen
5. **Entwurf speichern**

### Werk, Ausgaben und Bände
Ein Werk vereint alle Ausgaben desselben Textes. In der Karteikarte eines Dokuments erlaubt der Block **Werk**:
- **Einem anderen Werk zuordnen**: das Werk über den Titel suchen, dann **Zuordnen**. Das verlassene Werk verschwindet, wenn es leer bleibt.
- **Titel je Sprache**: ein Titel je Oberflächensprache. Titel mit dem Vermerk „maschinelle Übersetzung — bitte korrigieren“ hat die Maschine vorgeschlagen: lies sie nach und klicke **Speichern**, um sie zu bestätigen.
- **Einheitstitel**: der Referenztitel des Werks, in der Originalsprache des Werks selbst geschrieben, nicht in der einer Übersetzung.
- **Band**: die Bandnummer, wenn das Werk mehrere Bände umfasst. Die Bände bleiben in einem einzigen Werk.

### Dubletten-Assistent: gespaltene Werke und Bände
Im **Dubletten-Assistent** (Katalogisierung) ergänzen zwei Reiter die Dubletten von Aufnahmen:
- **Gespaltene Werke**: zwei Werke, die derselbe Text zu sein scheinen. **Zusammenführen in „…“** vereint sie; **Getrennt lassen** merkt sich die Entscheidung, das Paar kommt nicht wieder.
- **Bände**: Aufnahmen, die die Bände eines Werks zu sein scheinen. Hake **Diese Aufnahme zusammenführen** für jeden gewählten Band an, trage seine Nummer ein und bestätige; eine erledigte Gruppe kommt nicht wieder.

Keine Zusammenführung und keine Bandnummer wird von der Maschine gesetzt: jede Handlung ist deine.

### Dokumenttypen und Spezialfelder
Jeder Dokumenttyp zeigt angepasste Felder:
- **Zeitschrift** : Band, Nummer, Heft, Erscheinungsweise, ISSN
- **Flugblatt** : Kampagne, herausgebende Organisation, ungefähres Datum, physisches Format
- **Audio** : Dauer, Träger, technisches Format, Mitwirkende
- **Audiovisuell** : Dauer, Regie, Untertitel
- **Digitale Ressource** : URL, Zugangsbedingung, Einschränkung
- **Dossier** : Umfang, Zeitraum, Organisationen, politischer Kontext

### Autor*innenbiografien übersetzen
Im Reiter **Autor*in**, wenn du eine veröffentlichte Autor*in bearbeitest:
1. Öffne das Panel **Biografieübersetzungen**
2. Gib die Biografie in jeder gewünschten Sprache ein
3. Klicke auf **Übersetzungen speichern**

### Etiketten drucken
Im Reiter **Indexierung**, unter dem Exemplarenformular:
1. Exemplare filtern und auswählen
2. Auf **X Etikett(en) drucken** klicken
3. Ein A4-Dokument öffnet sich mit 21 Etiketten pro Seite (7×3)

---

## 5. Administration

### Bibliotheksverwaltung
Die Seite **Bibliotheksverwaltung** ermöglicht die Konfiguration von:
- Identität (Name, Stadt, Kontakt)
- Kommunikation (E-Mails, Versandarten, Benachrichtigungstypen)
- Regelwerk (PDF hochladen, Ausleihregeln)
- Team, Leihverkehr zwischen Bibliotheken, Berichte

### Netzwerkverwaltung
Die Seite **Netzwerk** (zugänglich für Koordinator*innen und Administrator*innen) ermöglicht es:
- Die Gesamtübersicht zu sehen (globale Statistiken)
- Bibliotheksanträge zu verwalten
- Netzwerkmitglieder zu verwalten
- Administrator*innen zu ernennen

### Zwei-Faktor-Authentifizierung der Teams
Der Reiter **Zwei-Faktor-Authentifizierung** auf der Seite **Netzwerk**, nur für die Netzwerkverwaltung, listet die aktiven Teamkonten und die Konten, die die Zwei-Faktor-Authentifizierung gewählt haben, mit ihren Rollen und der Zahl ihrer Geräte; Konten ohne Gerät stehen oben. Er zeigt auch die geltende Anforderung.

Um einer Person zu helfen, die ihr Gerät verloren hat: Prüfe zuerst ihre Identität auf anderem Weg (persönlich, Matrix), klicke dann auf **Geräte entfernen**, gib den Grund an (wie die Identität geprüft wurde) und klicke auf **Entfernen und abmelden**. Das Konto wird überall abgemeldet, und das Entfernen wird protokolliert. Dafür muss deine eigene Sitzung den Code durchlaufen haben.

---

## 6. Verfügbare Sprachen

Die Benutzeroberfläche ist in 10 Sprachen verfügbar:
- 🇧🇷🇵🇹 Português (Referenzsprache)
- 🇫🇷 Français
- 🇪🇸 Castellano
- 🇬🇧 English
- 🇮🇹 Italiano
- 🇩🇪 Deutsch
- 🇳🇱 Nederlands
- 🇬🇷 Ελληνικά
- Català
- Esperanto

Autor*innenbiografien können in jeder Sprache unabhängig übersetzt werden.

Die Werktitel werden automatisch in die zehn Sprachen vorübersetzt; sie tragen den Vermerk „bitte korrigieren“, bis eine Person sie nachgelesen hat.

---

*AnarBib — Netzwerk libertärer Bibliotheken*
*Freie Software für die kooperative Verwaltung militanten Wissens*
