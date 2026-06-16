# Rahmenplanung — Gegenseitige Hilfe bei der Katalogisierung (Reiter „Entraide" der Föderation)

**Datum** : 2026-06-15
**Status** : **Rahmenplanung / Entwurf** — explorative Reflexion, die die *Vision*,
die *Architektur* und die *Grundsatzentscheidungen* festlegt. **Dies ist noch keine
zu bauende Spezifikation**: zu diskutieren, zu erproben und dann in Spezifikationen
auszuarbeiten.
**Ethische Grundlage** : [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
(„die ausgestreckte Hand"). **Jeder unten beschriebene Bildschirm wurde am Raster „Streckt
es die Hand aus oder greift es zu?" geprüft.** Diese Rahmenplanung ist gewissermaßen die
erste konkrete Bewährungsprobe der Charta.

---

## 1. Der Bedarf

Die Katalogisierung ist der Schmerzpunkt der Einsteiger-Bibliotheken (vgl. die Baustellen
Autoritäten, Sacherschließung, Entdeckungs-Wizard). Eine Bibliothek allein vor den
Autoritäten, den Schlagwörtern, der Klassifikation, fühlt sich eingeschüchtert. Der Reiter
„Entraide" antwortet auf diesen konkreten Bedarf — doch anarchistische Katalogisierung ist
nicht neutral: die Mainstream-Schlagwörter pathologisieren, löschen aus, benennen falsch.
**Die gegenseitige Hilfe überträgt ein *politisches Handwerk*, das weder Standards noch eine
KI kodieren können.**

Durchgehendes Prinzip: **der Hilferuf ist generisch** (Unterstützung bei *jedem* heiklen
technischen Thema), die **Katalogisierung ist der erste angeschlossene Bereich**.

## 2. Drei Stufen gegenseitiger Hilfe — eine Stufenleiter nach Subsidiarität

Nicht „das eine ODER das andere", sondern drei *Intensitäten*; der Hilferuf ist das
Scharnier, die Antwort nimmt eine der drei Formen an, vom Leichtesten zum Schwersten:

1. **Das Wissens-Gemeingut** (Vademekums, Fälle, Thesaurus) — null Kosten, null Abhängigkeit,
   100 % unter Gleichen. Die dauerhafte Grundlage.
2. **Mini-Wizards** — führen die Bibliothek so, dass sie *selbst* handelt (autonomisierend,
   nicht abhängig machend).
3. **Direkte menschliche Hilfe** (Ruf → Antwort → eventuelle Videokonferenz) — die
   relationalste Stufe, für wenn das Gemeingut und der Wizard nicht ausreichen.

**Die absteigende Schleife**: ein schwieriger Fall, der auf Stufe 3 gelöst wurde → Zusammenfassung
→ wird ein Fall/Wizard der Stufe 1-2 → beim nächsten Mal reicht der Wizard. *Das Wissen steigt
mit der Zeit auf den Stufen herab; das Netzwerk wird mit jeder Episode klüger und selbstständiger.*

## 3. Das Wissens-Gemeingut — die Autonomieschicht

Drei Schichten, und die tiefste ist **das Vokabular selbst**:

- **Der Thesaurus, das politische Herzstück.** Keine Wortliste: ein *Konzeptgraph*. Die
  Politik lebt darin in den **Begriffen**, den **Relationen** (broader/narrower/related) und den
  **Anwendungshinweisen** (die Mikro-Vademekums sind). Auf **SKOS** aufbauen (offener Standard)
  — einen Norm vererben, kein Bastelwerk. Ein Keim existiert (Thesaurus ~30 Kategorien).
- **Fälle & Vademekums** — ausgearbeitete, bearbeitbare Beispiele, die *am Bedarfspunkt*
  erscheinen.
- **Wizards als *Daten*, nicht als *Code*** — *die Autonomiewette*: ist ein Wizard Code, ist
  man für immer auf Entwickler*innen angewiesen; ist er ein **strukturiertes Dokument** (Baum
  aus Fragekarten → Endkarten), das eine einmal geschriebene Engine abspielt, **schreibt jede
  Bibliothek einen davon, ohne zu coden**. Schutzmechanismen, damit er keine verkleidete
  Programmiersprache wird: keine freien Variablen/Berechnungen/Bedingungen; einziger Zustand =
  der zurückgelegte Weg; eventuelle Bedingungen aus einer geschlossenen Liste; **der Wizard
  *rät*, *schreibt* nie** (schlechtester Ausfall = „nicht nützlich", nie „Katalog beschädigt");
  kleine Einzel-Themen-Wizards.

**Mehrsprachig ohne KI**: die i18n-Hülle (10 Sprachversionen) trägt die Benutzeroberfläche;
die *Substanz* (Begriffe, Fälle) wird **von der Sprachgemeinschaft** geschrieben
(paralleles, kreuzverknüpftes Schreiben, keine absteigende Übersetzung) — langsam, aber dauerhaft
und kostenfrei. **Governance**: Hinzufügen/Ändern eines Begriffs über den
**Zustimmungs-/Einwands-Fluss** der Kreise; politischer Regler „zugelassene Varianten vs.
Konvergenz" vom Netzwerk zu setzen.

## 4. Die Auslösung — am Bedarfspunkt (Charta ③)

**Der Auslöser ist das *Feld*, die *Daten* oder die *Anfrage* — niemals die Überwachung
der Person.** Verhaltenssignale verbannen („5 Min am Feld", Zögerlichkeit): das ist Clippy
*und* Arbeitsüberwachung. Drei ehrliche Auslöser:
- **dem Feld innewohnend** (Schlagwörter/Autorität sind für alle schwierig → Hilfe ist immer da);
- **aus den Daten abgeleitet** (keine ISBN, mehrdeutige Autor*in → das Buch signalisiert, nicht die
  Person);
- **explizite Anfrage** („zu Hilfe" ruhig, jederzeit greifbar).

Die Hilfe steigt **die Stufenleiter einen-Klick-weiter** (Inline → Wizard → Kreis),
**diskret aber auffindbar** (verlässliche Platzierung, niemals modal/gamifiziert), mit einer
**Anwesenheitskurve nach Bereich** (etwas zugänglicher, wenn Feld leer + geringe Anzahl
Katalogisate; zieht sich mit der Meisterschaft zurück; jederzeit von Hand faltbar).

## 5. Zwei Bildschirme, die bereits am Raster geprüft wurden

### 5.1 — Das „?" unter einem schwierigen Feld (Katalogisierung)
Vorhanden *weil das Feld für alle mühsam ist* (Würdekadrage, nicht „du scheinst Schwierigkeiten
zu haben"). Beim Öffnen: Thesaurus-Vorschläge inline + Fälle aus dem Gemeingut → „geführter Weg"
(Wizard) → „den Kreis fragen" (Stufe 3, Moment der Zustimmung).
**Das Raster hat zwei verlockende Features getötet**: ❌ Zögerlichkeit erkennen, um Hilfe
anzubieten (Überwachung, Facette ③); ❌ Abzeichen/Serien/Balken in Richtung „Expert*in"
(Facette ⑥).
**Beibehaltene Standards**: Netz „zum ersten Mal? geführter Weg" *angeboten aber im Angebotsregister*;
„?" immer sichtbar, Vorschläge **beim Klick entfaltet** (diskret + auffindbar).

### 5.2 — Der Episodenabschluss + Erfassung des Gemeinguts
Ende **von der Unterstützten initiiert** (kein Auto-Close, kein Abschluss durch die
helfende Person). „Danke"-Bildschirm schlicht, **nichts angehakt** (Anti-Schuld-Entkopplung).
„Kontakt behalten?" **symmetrischer Handlauf**, ignorierbar, erzeugt nichts außer beidseitigem
Ja.
**Erfassung des Gemeinguts ohne Schuld**: die **helfende Person** wird eingeladen (sie hat das
neue Wissen), nicht die Unterstützte; **Mikro-Beitrag am Objekt angehakt** (Notiz zu einem
Begriff/Feld), **aus der Spur der Episode angebahnt**; dann wird die **Unterstützte eingeladen,
zu lesen/anzureichern** („was wirklich schwierig war") — *ihre Stimme, abwählbar, kein Urteil
der helfenden Person*, und **nicht-blockierend** (die Notiz hält allein).
**Das Raster hat getötet**: ❌ „bewerte deine Erfahrung" (verkleidete Bewertung); ❌ Abzeichen
für Fertigstellung.

## 6. Vertraulichkeit

Die Katalogdaten sind *weniger* sensibel als die Leser*innen-Daten (Metadaten zu *Büchern*,
nie zu Exemplaren/Ausleihen/Identitäten), **aber nicht null** (die Bestände einer anarchistischen
Bibliothek können politisch sensibel sein; vgl. die Unterscheidung
`visibility_level='network'` / BTL). Daher:
- **Opt-in pro Eintrag** (kein Dump), **BTL/Sensibles standardmäßig ausgeschlossen**;
- **die helfende Person *schlägt vor*, die Eigentümer*in *bestätigt*** — niemals direktes
  Schreiben durch Dritte; Zugang **eingegrenzt, widerruflich, geprüft**;
- der Schritt **„den Kreis fragen" IST der Moment der Zustimmung** („du wirst diese Einträge
  der Bibliothek X zeigen — hier ist, was rausgeht");
- **das Gemeingut erfasst generisches, de-identifiziertes *Handwerk*, keine identifizierenden
  *Fälle***; Besonderheiten werden entfernt oder eingewilligt.

Antwort auf die Frage „absolutes Recht zu delegieren?": **ja zur Autonomie, aber *informierte
und gerahmte* Zustimmung, kein Blankocheck** — das Risiko klein machen und es in voller
Kenntnis eingehen lassen.

## 7. Zuordnung & Reifung zur Partnerschaft

- **Sanfte Sortierung, kein harter Filter.** In einem weitläufigen Netzwerk ist ein UND
  (gleiche Sprache UND Geo UND Verfügbarkeit UND Expert*in) = leere Menge. Man **ordnet**
  nach Affinität (Sprache ↑, Zeitzone ↑, Freiwillige*r ↑) ohne **auszuschließen**;
  Subsidiarität **Kreis zuerst → Netzwerk bei Schweigen**. Der **relevante Kreis hängt vom
  Hilfetyp ab** (Katalogisierung → linguistisch; Material/Repression → geographisch).
- **Erster Schritt ohne Voraussetzung**: sich für *eine* Handlung freiwillig zu melden
  erfordert keinen Kreis und kein Profil. **Zugehörigkeit akkretiert sich aus Gesten**
  (eingewilligte Anerkennung, nie Etikett).
- **Anti-Hierarchie**: keine individuelle Reputation, kein Marktplatz; erklärte Verfügbarkeit,
  sichtbare Gegenseitigkeit ohne Score, Rotation.
- **Reifung zur Partnerschaft (§21)** — *zweite Phase, die die Knappheit auflöst*: eine
  gute Episode kann **reifen** zu einer Partnerschaft → die künftige Hilfe ist *vorher
  zugeordnet* (Sprache, Zeitzone, Zustimmung bereits gegeben); das Netzwerk **verdichtet
  sich**. **Entkoppelt** von der Episode (nie im Augenblick = Schuld); **nach Wiederholung**
  (Anerkennung, nicht Schöpfung); **symmetrisches beidseitiges Opt-in**; **Tiefenskala**
  (0 → Kontakt-behalten → Begleitung → formale Partnerschaft); **Schuldenumkehr** (die
  Partnerschaft ist ein *Geschenk* an die Unterstützte: „eine Genoss*in, die man anrufen
  kann, ohne neu einzuwilligen", keine Pflicht); immer **trennbar**.

## 8. Das Videokonferenz-Modul (Stufe 3)

Die menschliche Hilfe mit einer **Jitsi-Videokonferenz** koppeln (synchron = effiziente
Übertragung); Pool = **linguistischer Kreis**. **Erst asynchron, Videokonferenz als optionaler
Turbo** (die am stärksten gefährdete Person ist schlecht vernetzt → Stufen 0-2 als Text/Offline).
Technisch, „gratis": **Integration einmal über die iframe API mit dem `domain` in der Konfiguration
coden** → nie an einen Anbieter gebunden. Standardmäßig auf eine **militante Jitsi-Instanz**
verweisen (am doktrinkonformsten, kostenlos, kein GAFAM); andernfalls `meet.jit.si` (mit
Übernahme der Auth des Raumerstellers). **Ephemere** Räume, **nicht-erratbarer Name, Lobby**.
**Null Server, null Secret, null laufende Kosten.** Das Selbst-Gehostete bleibt *geparkt*
(VPS ausgeschlossen).

## 9. Kosten & Autonomie

Alles (Gemeingut, Wizards, Panels, Matching, Videokonferenz-Link-Out) **läuft auf dem
bestehenden Stack** (Supabase + statisches Frontend): **null Grenzkosten, kein Betrieb mit
KI**. KI bleibt ein **optionaler und abkoppelbarer Beschleuniger** (Vor-Katalogisierung des
*Neutralen* nur; das Politische bleibt unter Genoss*innen). **Die Organe sind bereits da**:
Thesauruskeim, Entdeckungs-Wizard, i18n 10 Sprachversionen, Zustimmungs-/Einwands-Fluss
der Kreise, §21 Partnerschaft. **Diese Rahmenplanung verbindet bestehende Organe — daher ihre
Bescheidenheit und ihre Unabhängigkeit von Kosten und externen Abhängigkeiten.**

## 10. Beschlossene Punkte / Offene Fragen

**Beschlossen (im Lauf der Reflexion):**
- Drei Stufen als Stufenleiter + absteigende Wissensschleife.
- Gemeingut = Thesaurus (SKOS, politisches Herzstück) + Fälle + **Wizards als Daten**.
- Auslösung durch Feld/Daten/Anfrage, **nie Überwachung**; Ein-Klick-Stufenleiter;
  Anwesenheitskurve nach Bereich.
- Bildschirm „?": Standards (Angebot, Vorschläge beim Klick); Ablehnungen
  (Zögerungs-Erkennung, Gamification).
- Abschluss: Unterstützte schließt ab; **helfende Person verfasst → Unterstützte reichert an**
  (null Schuld); Gemeingut = **generisches Handwerk**; Governance **Ergänzung = 2 Personen /
  Vokabular = kollektiv**.
- Matching **sanfte Sortierung + Kreis zuerst**; Kreis **je nach Hilfetyp**; erster Schritt
  ohne Voraussetzung; **Zugehörigkeit durch die Geste**.
- Reifung §21 **entkoppelt, nach Wiederholung, beidseitiges Opt-in, Tiefenskala,
  Schuldenumkehr, trennbar**.
- Videokonferenz **Jitsi `domain` konfigurierbar**, asynchron-zuerst, null Infrastruktur/Secret.
- (E-Mail-Erinnerung, bereits außerhalb dieser Rahmenplanung angeschlossen) Sprachversion der
  Empfänger*in = **ihre persönliche Präferenz**.

**Offen (politische Regler vom Netzwerk zu setzen):**
- **Anfangliches Empfangsniveau** (Gastfreundschaft) und **wer es setzt**: Netzwerk / Kreis /
  Bibliothek / Person. Ansatz: die neue Ankömmling *fragen* nach ihrem Empfang (Zustimmung)
  + Subsidiarität (die obere Ebene füllt nur die Stille) + Option *verkörperte Patenschaft*
  durch eine*n Freiwillige*n des Kreises.
- Niveau der **Anwesenheit des Handlaufs** und der Einladung zum Gemeingut (angeboten vs.
  verfügbar) — weitgehend durch die **Semantik** entschärft (Angebotsregister ≠ Weisung).
- Konkrete Form des **Editors des Daten-Wizards** (bis wohin ohne zu Code zu werden).
- Regler **Varianten vs. Konvergenz** des Thesaurus.

## 11. Status

Rahmenplanung zum **Diskutieren und Erproben**, kein Bauauftrag. Wenn ein Bereich reif ist,
wird er zu einer Spezifikation ausgearbeitet, und jeder Bildschirm wird erneut am **Raster
der relationalen Charta** geprüft.
