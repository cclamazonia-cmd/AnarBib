---
title: "Governance-Leitfaden von AnarBib"
subtitle: "Für Koordinator*innen von Bibliotheken und Administrator*innen des Netzwerks"
author: "Projekt AnarBib"
date: "Version 1.1 — 5. Juni 2026"
lang: de
---

# Vorwort

Dieser Leitfaden richtet sich an Personen, die im AnarBib-Netzwerk eine Koordinationsfunktion ausüben — sei es als Koordinator*in einer lokalen Bibliothek oder als Administrator*in des Netzwerks. Er verfolgt ein doppeltes Ziel:

- **Die politische Logik** der im SIGB AnarBib verankerten Regeln zu erläutern und ihre Verbindung zum Projekt kollektiver Emanzipation aufzuzeigen, aus dem die anarchistischen Bibliotheken hervorgegangen sind;
- **Die alltägliche Praxis zu unterstützen**, indem konkrete Fragen beantwortet werden, denen Koordinationen bei der Nutzung der Software begegnen.

## Eine politische Vereinbarung

Dieser Leitfaden ist nicht das Regelwerk des Netzwerks und hat keinerlei übergeordnete Autorität gegenüber den Entscheidungen der Kollektive, die es bilden. Was er enthält, hat nur Gültigkeit, weil Menschen sich zu einem bestimmten Zeitpunkt darauf geeinigt haben, die Dinge so zu handhaben. Wenn sich die Praktiken weiterentwickeln, muss sich dieser Text mit ihnen weiterentwickeln, oder er wird widerlegt, oder er wird zerrissen. Es ist der Gebrauch, den die Kollektive davon machen werden, der über sein Schicksal entscheidet.

Die technischen Regeln, die das SIGB AnarBib durchsetzt — Karenzfristen, Kooptations-Workflows, Mitgliedschafts-Status usw. — sind ebenfalls Vereinbarungen. Sie wurden von Genoss*innen zu bestimmten Zeitpunkten verfasst, um bestimmte Probleme zu lösen. Sie sind in **Spezifikationsdateien** festgehalten (den `spec-*.md` des Repositorys), datiert und unterzeichnet, die ihrerseits geändert werden können. Wenn man diesen Leitfaden liest, liest man den Stand einer Debatte zu einem bestimmten Zeitpunkt. Er ist keine Verfassung.

## Wie dieser Leitfaden aufgebaut ist

Der Leitfaden besteht aus zwei Teilen:

- **Teil I — Das Warum.** Vier Kapitel, die den politischen Rahmen abstecken: wozu ein anarchistisches SIGB dient, welches seine Gründungsprinzipien sind, wie sich die beiden Bereiche (lokale Bibliothek und Netzwerk) zueinander verhalten, und wie die Regeln selbst geändert werden können.

- **Teil II — Das Wie.** Sechs praktische Kapitel, die jeweils eine wichtige operative Frage behandeln: kooptieren, abberufen, mit eskalierenden Situationen umgehen, eine Netzwerk-Admin-Funktion ausüben, Transparenz gewährleisten, und ein letztes Kapitel, das konkrete Fälle von Anfang bis Ende bespricht.

Am Ende jedes praktischen Kapitels erinnert eine Rubrik **„Wenn die Regel Sie stört"** daran, wo man sie diskutieren und wie man eine Änderung vorschlagen kann. Das ist wichtig, weil diese Regeln nur dann Sinn ergeben, wenn sie änderbar sind.

Die Anhänge am Ende des Bandes dienen als schnelle Referenz: Glossar, Index der technischen Funktionen mit ihrer politischen Übersetzung, Vorlage für Änderungsvorschläge und Links zu den Quell-Specs.

## Wie man diesen Leitfaden liest

Man kann ihn am Stück lesen, aber das ist wahrscheinlich nicht der beste Umgang damit. Drei Einstiegswege je nach Bedarf:

- **Um den Geist des Projekts zu verstehen**, bevor man eine Funktion übernimmt: Teil I lesen (Kapitel 1 bis 4).
- **Bei einer konkreten Situation**: direkt zum betreffenden praktischen Kapitel springen (5 bis 10).
- **Zur Information vor einer Vollversammlung**, auf der eine Governance-Frage gestellt werden soll: das betreffende Kapitel plus die entsprechende Rubrik „Wenn die Regel Sie stört" lesen und die Quell-Spec in Anhang D konsultieren.

Was hier geschrieben steht, stützt sich auf vier Spezifikationsdokumente:

- `spec-gouvernance-roles.md` (5. Mai 2026) — Rollen, Status, Übergänge;
- `spec-administrateur-reseau.md` (11. Mai 2026) — Trennung lokal/Netzwerk, Kooptation mit Einstimmigkeit;
- `spec-validation-physique.md` (3. Mai 2026) — Aufnahmemodi für Leser*innen-Konten;
- `spec-refactor-v3-semantique.md` (9. Mai 2026) — Semantik des Reservierungs-Workflows (am Rande erwähnt).

Die Verweise auf diese Specs werden im Laufe des Textes in der Form `(cf. spec-gouvernance, §3.4)` angegeben, um ein Vertiefen zu ermöglichen.

## Eine Anmerkung zur Stimme

Der Text wechselt zwischen **man** (das AnarBib-Kollektiv, dem Autor*in und Leser*in gleichermaßen angehören), **Sie** (wenn man sich an eine bestimmte Coord oder Admin wendet, die eine Entscheidung treffen muss), und **wir** (wenn von den Genoss*innen die Rede ist, die die Regeln zu einem bestimmten Zeitpunkt geschrieben haben und die sich von denjenigen unterscheiden könnten, die sie lesen). Das ist beabsichtigt. Es gibt hier keine institutionelle Neutralität: Dieser Text wird von Genoss*innen getragen und richtet sich an Genoss*innen.

\newpage

# Teil I — Das Warum

\newpage

# 1. Was bedeutet ein anarchistisches SIGB?

## 1.1. Das SIGB ist nicht die Vollversammlung

Das erste und schwierigste Prinzip ist dieses: **Das SIGB erfasst die Entscheidungen des Kollektivs, es trifft sie nicht**. Dieser Satz klingt harmlos. Er ist in Wirklichkeit der Dreh- und Angelpunkt, um den sich alles andere organisiert.

Jedes Mal, wenn das SIGB AnarBib den Anschein einer Autorität erweckt — wenn es eine Beförderung ablehnt, wenn es eine Karenzfrist von sieben Tagen auferlegt, wenn es einen Status-Übergang blockiert — setzt es nur eine Regel **vollziehbar um**, die sich die Kollektive gegeben haben. Die Regel wurde irgendwo in einer Spec niedergeschrieben, nach Diskussion. Jemand hat sie gelesen und kritisiert. Eine Version wurde eingefroren und eingesetzt. Und jetzt, in dem Moment, in dem Sie auf den Button klicken, wendet die Software schlicht das an, was vereinbart wurde.

Wenn Sie die Regel für dumm, kontraproduktiv oder ungerecht halten, ist nicht das SIGB zu bekämpfen. Es ist die Spec, die geändert werden muss. Siehe Kapitel 4.

## 1.2. Die offen anerkannte Spannung

Jede Software, die Berechtigungen verwaltet, ist per Konstruktion ein Hierarchisierungsinstrument. Irgendjemand muss eine Anmeldung validieren, die öffentliche Identität einer Bibliothek ändern, auf die persönlichen Daten eines*einer Leser*in zugreifen können. Diese technische Notwendigkeit steht in scheinbarem Widerspruch zum Ideal der Horizontalität, das die anarchistischen Bibliotheken beseelt.

AnarBib **erkennt diese Spannung an**, anstatt sie zu verschleiern. Der politische Kompromiss, den man gefunden hat, lässt sich in zwei Punkten zusammenfassen:

- **Rollen sind keine Ränge**. Es sind **Funktionen**, die das Kollektiv vorübergehend an bestimmte Mitglieder delegiert, um bestimmte technische Aufgaben auszuführen. Niemand ist „auf Lebenszeit" Koordinator*in. Niemand ist „von Natur aus" Netzwerk-Admin. Diese Funktionen werden verliehen, und sie können zurückgenommen werden.

- Die **Abberufungsmechanismen** zählen genauso viel wie die Berufungsmechanismen. Das SIGB sieht ausdrücklich vor, wie jemand eine Funktion verlässt — durch freiwillige Herabstufung, durch Kollektivantrag mit Karenzfrist, durch freiwilligen Netzwerk-Austritt, durch einstimmigen kollektiven Rückzug. Eine Funktion, die nicht verlassen werden kann, ist keine Funktion, sondern eine Aneignung.

## 1.3. Delegation und Rotation

Der zentrale Gedanke ist der der **Delegation mit Rotation**. Ein Kollektiv delegiert an bestimmte Mitglieder die Ausführung technischer Aufgaben (Ausleihen im SIGB verwalten, die Sichtbarkeit der Bibliothek ändern, ein neues Mitglied im Team aufnehmen). Diese Delegation ist:

- **Explizit**: Sie verkörpert sich in einem Kooptationsakt, der im Audit-Log nachvollzogen wird;
- **Reversibel**: Die delegierte Person kann die Funktion jederzeit verlassen, und das Kollektiv kann es ihr nach einem geregelten Verfahren nahelegen;
- **Von Natur aus vorübergehend**: Auch wenn das SIGB keine Dauer vorschreibt, ist die politische Kultur des Netzwerks, dass man die Funktionen rotieren lässt und sich nicht darin einrichtet.

Diese Rotation der Funktionen ist der Unterschied zwischen einer (anarchistischen) „Delegation" und einer (staatlichen oder kapitalistischen) „Hierarchie". Wenn man sich in einer Funktion einrichtet, wird man zu einem Dienstgrad. Wenn man regelmäßig herausgeht, bleibt man ein*e Genoss*in, der/die einen Dienst leistet.

## 1.4. Die acht Gründungsprinzipien

Die Rollen-Governance-Spec (`spec-gouvernance-roles.md`, §2) legt acht Gründungsprinzipien dar. Wir listen sie hier auf, um sie im weiteren Verlauf des Leitfadens darauf beziehen zu können; jedes praktische Kapitel von Teil II wird darauf zurückverweisen.

**P1 — Delegation, nicht Hierarchie.** Keine Rolle ist ein Titel. Alle Rollen sind von Natur aus vorübergehend und widerruflich.

**P2 — Kooptation für Staff-Rollen.** Der Eintritt in ein Team (Leser*in in `librarian` oder `coordenador` werden) erfolgt durch Kooptation der bestehenden `coordenadores`. Es ist Sache des Kollektivs zu entscheiden, wer aufgenommen wird; der/die `coordenador*a` ist nur die Hand, die die Entscheidung im SIGB ausführt.

**P3 — Freiwillige Herabstufung immer möglich.** Jede Person mit einer Staff-Rolle kann sich jederzeit ohne Rücksprache selbst herabstufen. „Ich übergebe" ist ein Grundrecht.

**P4 — Ausschluss durch Karenzfrist geregelt.** Der unfreiwillige Ausschluss eines*einer `librarian` durch einen*eine `coordenador*a` unterliegt einer Karenzfrist von sieben Tagen vor Wirksamwerden. Diese Frist ermöglicht kollektive Beratung und eventuelle Aufhebung durch einen*eine andere*n `coordenador*a`.

**P5 — Maximale Transparenz.** Das Audit-Log der Rollenänderungen ist für das gesamte aktive Staff der Bibliothek lesbar, nicht nur für die `coordenadores`. Die Verhinderung undurchsichtiger Manipulationen gehört zur politischen Kultur der informationellen Horizontalität.

**P6 — Systematische Benachrichtigungen.** Jede Rollenänderung löst eine E-Mail an die betroffene Person und an die gesamte Koordination aus. Niemand kann in seiner/ihrer Rolle verändert werden, ohne es zu wissen, und die Koordination ist stets informiert.

**P7 — Lokale Souveränität der Bibliotheken.** Rollenänderungen in Bibliothek A haben keine Auswirkungen auf Bibliothek B, auch für dieselbe Person nicht. Jede Bibliothek ist souverän über ihre internen Delegationen.

**P8 — Das SIGB modelliert nicht die Vollversammlung.** Das SIGB führt Entscheidungen aus, es trifft sie nicht. Es enthält keinerlei Mechanismus für Abstimmungen, Quorum oder Beratung. Diese Dinge finden im Kollektiv statt, außerhalb der Software.

## 1.5. Was das SIGB nicht tut

Es ist nützlich, die Entscheidungen zur **Nicht-Modellierung** explizit zu machen:

- Das SIGB **definiert nicht**, was eine „gute" Koordination ist. Eine Bibliothek kann im Kreis, in einer Vollversammlung, im Rotationsverfahren, per Losverfahren, durch Konsens oder durch Mehrheitsentscheid entscheiden. Das SIGB ist gleichgültig.
- Das SIGB **misst nicht** die politische Legitimität einer Kooptation. Wenn eine*r Coord auf „X zu `librarian` befördern" klickt, erfasst das SIGB. Es ist Sache des Kollektivs sicherzustellen, dass die Entscheidung korrekt getroffen wurde, und in der politischen Kultur des Kollektivs spielt sich diese Gewissheit ab.
- Das SIGB **schlichtet keine** Konflikte. Wenn etwas entgleist, stellt das SIGB Werkzeuge bereit (sofortige Sperrung, Abberufungsantrag, lesbares Audit-Log), aber die politische Entscheidung bleibt außerhalb der Software.

Diese Bescheidenheit ist kein Mangel, sie ist eine Anforderung. Ein SIGB, das vorgibt, das politische Leben eines Kollektivs zu modellieren, wäre ipso facto autoritär — es würde seine Vision davon aufzwingen, was eine „gute" Entscheidung ist. AnarBib lehnt diese Tendenz ab.

## 1.6. Und der Schutz digitaler Freiheiten?

Drei Klarstellungen, weil die Frage immer wieder auftaucht:

- **Persönliche Daten**: Die Leser*innen-Konten enthalten, was die Person dort freiwillig hinterlegt hat. Die Bibliotheken haben nur Zugang zu den Daten, die für ihren Betrieb unbedingt erforderlich sind. Die Mitgliedschaften in anderen Bibliotheken sind per Konstruktion abgeschottet (P7).

- **Audit-Log**: Das Log ist **dem aktiven Staff** der Bibliothek öffentlich zugänglich, nicht den Leser*innen und nicht dem Rest des Netzwerks. Diese interne Transparenz dient dazu, undurchsichtige Manipulationen zwischen Koordinationen zu verhindern; sie ist kein Panoptikum, das gegen die Leser*innen gerichtet ist.

- **Bibliotheksübergreifende Logs**: Wenn eine*e Netzwerk-Admin*in in eine Bibliothek eingreift (Fall aus der `spec-administrateur-reseau`, §6.3.1), wird die Aktion in einer dedizierten Tabelle mit Kritikalitätsstufe erfasst. Das ist für die Netzwerk-Administrator*innen und für die Koordination der betroffenen Bibliothek lesbar. Transparenz in beide Richtungen.

\newpage

# 2. Die zwei Bereiche: lokale Bibliothek und Netzwerk

## 2.1. Warum diese Trennung

Das AnarBib-Netzwerk ist keine Bibliothekskette mit einer Zentrale. Es ist eine **Föderation autonomer Kollektive**. Diese politische Realität hat sich schließlich in der Struktur des SIGB selbst durchgesetzt.

Ursprünglich, in den ersten Versionen, war die Rolle „AnarBib-Administrator*in" einer bestimmten Bibliothek in der Tabelle `user_library_memberships` zugeordnet. Diese Modellierung legte — ohne es zu sagen — nahe, dass eine*e AnarBib-Admin*in *eine Bibliothek verwaltet*. Das stimmte politisch nicht: Eine*e Netzwerk-Admin*in animiert die Koordination zwischen Bibliotheken, sie leitet keine bestimmte Bibliothek.

Die Spec `spec-administrateur-reseau.md` (11. Mai 2026) hat die Trennung festgeschrieben. Seitdem kennt das SIGB **zwei verschiedene Bereiche**:

- **Das lokale Staff** einer Bibliothek (Rollen `reader`, `librarian`, `coordenador`), gespeichert in `user_library_memberships`. Seine politische Autorität liegt **im Bereich der Bibliothek**.

- **Die Netzwerkverwaltung** (Tabelle `network_administrators`), ohne Zuordnung zu einer Bibliothek. Ihre politische Autorität ist **transversal**, aber sie ersetzt niemals die lokale Autonomie.

## 2.2. Was jeder Bereich tut

**Das lokale Staff** verwaltet den Alltag einer Bibliothek: Ausleihen, Rückgaben, Reservierungen, Validierung von Anmeldungen, Änderung des Reglements, der Ausleihpolitik, der öffentlichen Identität der Bibliothek. Alles, was den Betrieb **einer** Bibliothek betrifft, wird auf Ebene des lokalen Staffs geregelt.

**Die Netzwerkverwaltung** gewährleistet die Koordination zwischen Bibliotheken: Aktivierung neuer Bibliotheken, Moderation des gemeinsamen Katalogs, technische Wartung der Plattform, Aufnahme neuer Kollektive und außerordentliche Intervention, wenn eine Bibliothek in eine Blockade gerät (kein*e aktive*r Coord mehr, schwerwiegender Konflikt usw.). Alles, was das **Netzwerk** betrifft, wird auf Ebene der Netzwerkverwaltung geregelt.

## 2.3. Die Nicht-Überschneidungsregel

Eine einfache politische Regel leitet alle Zähler und alle Ansichten des SIGB:

> **Jede Seite erzählt die Geschichte ihres Bereichs. Ein Zähler zählt, was in seinem Bereich eingetragen ist, nicht mehr und nicht weniger.**

Konkret:

- Die Seite einer Bibliothek zählt ihre lokalen Mitgliedschaften. Punkt. Netzwerk-Administrator*innen erscheinen nicht in diesen Zählern, auch wenn sie technisch in der Bibliothek eingreifen können.
- Die Netzwerkseite zählt ihre Netzwerk-Administrator*innen. Punkt.

Wenn eine Person sowohl `coordenador` einer Bibliothek **als auch** Netzwerk-Administrator*in ist (der Fall von Xavier am 11. Mai 2026), erscheint sie in beiden Zählern, **einmal in jedem**, ohne bereichsübergreifende Deduplizierung. Das sind **zwei verschiedene politische Einschreibungen**, die jeweils in ihrem Bereich gezählt werden.

Warum diese Regel politisch gesund ist, in vier Punkten:

- **Ehrlichkeit**: Dein lokales Engagement wird in der Bibliothek gezählt, in der du tätig bist; dein Netzwerkengagement wird auf Netzwerkebene gezählt. Niemand zählt dich „1,5 Mal".
- **Lesbarkeit**: Ein*e Aktivist*in, der/die die Karte einer Bibliothek anschaut, sieht sofort, wie viele Personen **lokal** engagiert sind, ohne sich fragen zu müssen, ob Netzwerk-Administrator*innen „von außen" den Zähler aufblähen.
- **Robustheit**: Wenn morgen Zwischenrollen hinzugefügt werden (Hilfskraft, Praktikant*in, Beobachter*in), bleibt die Regel „Seite = Bereich" klar.
- **Politische Kohärenz**: Die Trennung zwischen Netzwerk-Admin und lokalem Staff ist eine **politische Entscheidung**, kein Modellierungsdetail. Die Zähler müssen das widerspiegeln.

## 2.4. Das transversale Recht der Netzwerk-Admin

Dieser Punkt verdient ein gutes Verständnis, weil er leicht falsch interpretiert werden kann.

**Eine*e Netzwerk-Admin*in kann technisch in jede Bibliothek eingreifen.** Sie kann zum Beispiel den Katalog einer `private`-Bibliothek lesen, ihre Sichtbarkeit ändern oder — in Ausnahmefällen — Mitgliedschaften erstellen oder ändern. Das ist, was die Spec als **transversales Interventionsrecht** bezeichnet.

Dieses Recht existiert aus zwei Gründen:

- **Wartung**: Irgendjemand muss in der Lage sein, eine Bibliothek zu entsperren, die in Panne geraten ist (kein Coord mehr, kaputte Konfiguration usw.).
- **Mediation**: Wenn ein schwerwiegender Konflikt eine Bibliothek durchzieht und das lokale Kollektiv am Funktionieren hindert, muss es einen Rückgriff geben.

Aber dieses Recht macht die Netzwerk-Admin**in** **nicht** zu einer hierarchisch übergeordneten Person gegenüber der lokalen Koordination. Die Doktrin des Netzwerks, in diesem Leitfaden dargelegt:

> **Ein Eingriff einer Netzwerk-Admin in eine lokale Bibliothek muss von einer Information an die betreffende lokale Koordination begleitet werden**, außer bei vitaler Dringlichkeit (aktive Kompromittierung, laufende Belästigung, Angriff auf die Plattform). Die vorherige Information ist keine Genehmigungsanfrage: Die Netzwerk-Admin hat das Recht zu handeln. Aber sie ist ein **Zeichen des Respekts** gegenüber der Autonomie der Bibliothek und bewahrt die Möglichkeit einer anderen Regelung (zum Beispiel: „Lass mich versuchen, das zuerst zu regeln, ich halte dich auf dem Laufenden").

Die technische Rückverfolgbarkeit existiert darüber hinaus: Alle bibliotheksübergreifenden Aktionen einer Netzwerk-Admin*in werden in der Tabelle `cross_library_actions_log` mit einer Kritikalitätsstufe erfasst, die für die lokale Koordination im Nachhinein lesbar sind.

## 2.5. Die lokale Souveränität ist unantastbar

Eine letzte politische Klarstellung, die aus dem Prinzip **P7 — Lokale Souveränität der Bibliotheken** folgt.

Die Bibliotheken des AnarBib-Netzwerks **erkennen sich gegenseitig an**. Wenn BLMF eine*n neue*n Leser*in physisch validiert (cf. `spec-validation-physique.md`), gilt diese Validierung für alle `network`-Bibliotheken des Netzwerks. Das ist ein **implizites Zirkulationspakt** zwischen Bibliotheken, die genug politische Kultur teilen, um sich gegenseitig zu vertrauen.

Aber diese gegenseitige Anerkennung **gibt kein Einmischungsrecht** einer Bibliothek in eine andere. Die Koordination der Bibliothek A kann nicht die Mitgliedschaften der Bibliothek B ändern. Sie kann nicht die persönlichen Daten der Leser*innen von B einsehen (außer denen, die auch bei ihr eingeschrieben sind). Sie kann nicht das Reglement von B ändern.

Jede Bibliothek bleibt **souverän über ihre internen Delegationen**, ihre Aufnahmepolitik, ihre Validierungsweise, ihre Beitragsregeln, ihre interne Ordnung. Das Netzwerk sagt nicht, wie sie funktionieren sollen. Es sagt nur, mit wem sie sich gegenseitig anerkennen.

\newpage

# 3. Status, Rollen, Übergänge: die Grammatik des SIGB

Dieses Kapitel ist etwas trockener als die anderen. Hier wird das technische Vokabular eingeführt, das im gesamten Leitfaden verwendet wird. Wenn Sie es beim ersten Lesen überspringen, können Sie bei Bedarf darauf zurückkommen.

## 3.1. Die vier Rollen

Das SIGB AnarBib verwendet vier Rollen, die in der Datenbank durch die Bedingung `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` auf der Tabelle `user_library_memberships` deklariert sind.

**`reader`** — Einfaches Leser*innenkonto. Keine Verwaltungsbefugnis. Berechtigungen: Katalog einsehen (gemäß der Sichtbarkeit der Bibliothek), ausleihen, vormerken, im Lesesaal nutzen, eigene persönliche Daten ändern, Migration oder Löschung des eigenen Kontos beantragen.

**`librarian`** — Operatives Personal. Erledigt den Alltag: Ausleihen, Vorbestellungen, Rückgaben, Validierung von Anmeldungen (je nach Modus der Bibliothek), Änderung von Katalogdaten, Zugang zu personenbezogenen Daten der Leser*innen der Bibliothek. **Lesezugriff** auf die Teamliste. Erhält Benachrichtigungen über Rollenänderungen und kann das Audit-Log des Teams lesen (P5).

**`coordenador`** — Koordinierendes Personal. Alles, was ein*e librarian hat, plus: öffentliche Identität der Bibliothek ändern (Name, Logo, Kontakt usw.), Konfiguration ändern (Ausleihrichtlinien, Reglement), Beitragsregeln verwalten, **und alle Governance-Aktionen des Teams**: kooptieren, einen Rückzug beantragen, suspendieren, eine Suspendierung aufheben, einen Rückzugsantrag annullieren.

**`administrador`** — Historische Rolle, im Auslaufen. War gedacht, um „bibliotheksübergreifende Verwaltungsrechte" zu bezeichnen, aber an eine `library_id` gebunden. Mittlerweile ersetzt durch die **Netzwerkadministrator*innen**, die in der Tabelle `network_administrators` gespeichert sind (vgl. Kapitel 2). Die Spec admin-reseau sieht die schrittweise Migration und die endgültige Entfernung dieser Rolle aus der Tabelle `user_library_memberships` vor.

## 3.2. Die fünf Status einer Membership

Jede Zeile der Tabelle `user_library_memberships` hat einen **Status**, der den Zustand der Delegation zu einem bestimmten Zeitpunkt ausdrückt. Fünf Status sind möglich:

**`active`** — Normalzustand. Die Person hat ihre Rolle und übt sie aus.

**`pending`** — Vorbehalten für die Spec physische Validierung. Die Membership ist erstellt, wartet aber auf ein physisches Treffen mit einem*einer librarian+ der Anmeldebibliothek. Kein Zugang zu den Rollenrechten, solange dieser Status gilt.

**`suspended`** — **Konservative Maßnahme**, die von einem*einer coordenador*a ergriffen wird. Kein Zugang. Verwendung: gemeldetes Harassment in laufender Untersuchung, kompromittiertes Konto, laufende Mediation. **Unbegrenzte Dauer**; die Aufhebung erfolgt manuell, durch ein*e coord (Rückkehr zu `active`) oder durch effektive Absetzung.

**`pending_removal`** — **Siebentägige Wartefrist** vor effektivem Ausschluss. Kein Zugang während dieser Zeit. Mögliche Entwicklungen: Annullierung durch ein*e andere coord (Rückkehr zu `active`), Selbstrückstufung durch die Person selbst (Kurzschluss), oder automatischer Übergang zu `inactive` am Tag +7.

**`inactive`** — Membership geschlossen. Die Person ist nicht mehr im Team. Kein Zugang. Mehrere mögliche Ursprünge: freiwilliger Austritt, Ende der Wartefrist, verlassenes Konto (automatisch nach 9 Monaten).

## 3.3. Das Übergangschema

Das SIGB erlaubt nicht jeden beliebigen Übergang zwischen Status. Hier, vereinfacht, das erlaubte Schema:

```
                       ┌──────────────┐
                       │   active     │ ◄──────────┐
                       └──────┬───────┘            │
                              │                    │
              ┌───────────────┼───────────────┐    │
              ▼               ▼               ▼    │
       ┌─────────────┐  ┌─────────────┐  ┌─────────┴────┐
       │  suspended  │  │ pending_    │  │  inactive    │
       │             │  │ removal     │  │              │
       └──────┬──────┘  └──────┬──────┘  └──────────────┘
              │                │
              │ Aufhebung      │ Annullierung
              └────────────────┴────────────┐
                               │            │
                               ▼ (Tag+7)    ▼
                        ┌──────────────┐
                        │   inactive   │
                        └──────────────┘
```

Einige Schlüsselregeln:

- Man kann **nicht** direkt von `active` zu `inactive` für ein*e librarian durch eine einseitige Entscheidung einer anderen coord wechseln. Es muss über `pending_removal` gegangen werden und die Wartefrist abgewartet werden (oder die Person stuft sich selbst zurück).
- Man kann **jederzeit** vom eigenen Status `active` zu `inactive` wechseln (Selbstrückstufung, Recht P3).
- `suspended` hat **keine** maximale Dauer. Es ist keine Wartefrist vor dem Ausschluss, sondern eine konservative Maßnahme — sie dauert so lange wie die Beratung.
- Von `inactive` kehrt man **nicht** zu `active` zurück. Um eine Person wieder aufzunehmen, wird eine neue Membership-Zeile erstellt. Die Geschichte bleibt erhalten.

## 3.4. Die neun Übergänge: wer darf was

Die Spec Rollengovernance formalisiert neun Übergänge, hier in gekürzter Form aufgelistet. Das operative Detail findet sich in Teil II.

| # | Übergang | Wer | Mechanismus |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coord+ | Kooptation |
| T2 | `librarian` → `coordenador` | Coord+ | Kooptation |
| T3 | `coordenador` → `librarian` | Selbst ODER andere coords | Selbstrückstufung ODER kollegialer Rückzug mit Wartefrist |
| T4 | `librarian` → `reader` (freiwillig) | Selbst | Selbstrückstufung |
| T5 | `librarian` → `reader` (kollektiv) | Coord+ | `pending_removal` mit Wartefrist 7 Tage |
| T6 | Sofortsuspendierung | Coord+ | Übergang zu `suspended` |
| T7 | Aufhebung der Suspendierung | Coord+ | Rückkehr `suspended` → `active` |
| T8 | Annullierung eines Rückzugsantrags | Coord+ | Rückkehr `pending_removal` → `active` |
| T9 | Automatischer Austritt (verlassenes Konto) | Cron | Übergang zu `inactive` nach 9 Monaten ohne Login |

Drei Prinzipien strukturieren diese Tabelle:

- **Der Eintritt erfolgt durch Kooptation** (T1, T2). Niemand befördert sich selbst.
- **Der freiwillige Austritt ist immer möglich** (T3 auto, T4). Niemand bleibt in einer Funktion gefangen, die er*sie nicht mehr ausüben möchte.
- **Der erzwungene Austritt wird durch die Wartefrist verlangsamt** (T5). Sieben Tage, um ein eventuelles kollegiales Rückrudern zu ermöglichen.

## 3.5. Auf Netzwerkadmin-Seite: ein Zwillingsschema

Die Netzwerkverwaltung (Tabelle `network_administrators`) hat ihren eigenen Lebenszyklus, strukturell sehr ähnlich, aber mit zwei Besonderheiten:

- **Kooptation durch Einstimmigkeit**: Um ein*e neue*n Netzwerkadministrator*in hinzuzufügen, wird ein Vorschlag von einem*einer aktiven Admin eröffnet, und **alle anderen aktiven Admins** müssen mit `favorable` stimmen. Eine einzige Stimme `opposed` (mit einer obligatorischen Begründung von mindestens 20 Zeichen) blockiert den Vorschlag. Eine Enthaltung blockiert ebenfalls, solange sie nicht in eine Stimme umgewandelt wird.

- **Kollektiver Rückzug durch Einstimmigkeit**: Um ein*e Netzwerkadministrator*in gegen ihren*seinen Willen zu entfernen, gilt derselbe Ablauf spiegelbildlich. Mit einer Wartefrist von **sieben Tagen** nach einstimmiger Einigung (Feld `pending_collective_removal_until`).

Der Selbstrückzug seinerseits ist **unilateral und immer möglich** (außer wenn man die einzige aktive Admin-Person ist, in welchem Fall der Übergang über `pending_removal` mit einer Wartefrist von 30 Tagen erfolgt und eine Warn-E-Mail an die anderen Admins ausgelöst wird).

Vollständige Details in Kapitel 8.

\newpage

# 4. Reversibilität und Änderbarkeit

Dieses kurze Kapitel behandelt eine entscheidende politische Frage: **Wie können diese Regeln geändert werden?** Wenn sie es nicht könnten, wäre das SIGB eine Autorität, und der Rest dieses Leitfadens wäre eine Lüge.

## 4.1. Drei Ebenen der Änderbarkeit

Es müssen drei Ebenen von Regeln unterschieden werden, die sich nicht auf dieselbe Weise ändern lassen:

**Die lokalen Gepflogenheiten einer Bibliothek** — Aufnahmerichtlinien, Modus der physischen Validierung (`open` oder `manual_validation`), internes Reglement, Häufigkeit der VV, Kooptationsmodalitäten. Diese Gepflogenheiten sind **intern für jede Bibliothek**. Das Netzwerk mischt sich nicht ein. Sie werden in der Bibliotheks-VV geändert, oder gemäß dem Verfahren, das sich das Kollektiv gegeben hat.

**Die Netzwerkregeln** — Trennung lokal/Netzwerk, Prinzip der einstimmigen Kooptation für Netzwerkadmins, Doktrin der vorherigen Information bei einem bibliotheksübergreifenden Eingriff, Modalitäten der Aktivierung neuer Bibliotheken. Diese Regeln sind **bibliotheksübergreifend**. Sie werden in der Netzwerkkoordination geändert, nach Diskussion zwischen Netzwerkadmins und betroffenen lokalen Koordinationen.

**Die politischen Grundlagen des Projekts** — die acht Prinzipien (P1 bis P8 aus Kapitel 1), die Idee, dass das SIGB die VV nicht modelliert, die bewusste Bescheidenheit der Software gegenüber dem politischen Leben der Kollektive. Diese Grundlagen können geändert werden, aber sie sind strukturgebend: sie zu ändern bedeutet wahrscheinlich, das zu ändern, was im weiteren Sinne „AnarBib" genannt wird. Eine Infragestellung dieser Tragweite würde eine kollektive Diskussion im gesamten Netzwerk erfordern, wahrscheinlich anlässlich einer Veranstaltung (Jahrestreffen usw.).

## 4.2. Wie man einen Änderungsantrag einreicht

Es gibt nicht nur eine Vorgehensweise — jede Ebene hat ihre eigene — aber hier ist das allgemeine Muster, das das Netzwerk tendenziell praktiziert:

1. **Die betroffene Spec identifizieren**. Die Regeln des SIGB sind in Dateien `spec-*.md` des Repositorys niedergelegt. Finden Sie diejenige, die die Regel enthält, die Sie ändern möchten (Anhang D gibt die Entsprechungen).

2. **Eine Änderungsnotiz verfassen**. Freies Format, aber mit Antworten auf: welche Regel, warum sie problematisch ist, welche Änderung vorgeschlagen wird, welche technischen und politischen Konsequenzen antizipiert werden. Anhang C bietet eine Vorlage.

3. **Die Notiz in Umlauf bringen**. Je nach Ebene:
   - **Lokal**: in der Bibliotheks-VV, oder auf dem Diskussionskanal des Kollektivs.
   - **Netzwerk**: auf dem bibliotheksübergreifenden Koordinationskanal (Matrix `#anarbib`), mit Tag an die Netzwerkadmins und die betroffenen lokalen Koordinationen.
   - **Grundlagen**: auf allen Kanälen, und wahrscheinlich auf der Tagesordnung eines Treffens.

4. **Diskutieren, amendieren, eine Version verabschieden**. Das SIGB sagt nicht, wie dieser Schritt ablaufen soll. Das ist das Metier der Kollektive.

5. **Wenn die Entscheidung getroffen ist**: ein*e Netzwerkadmin oder ein*e Entwickler*in (oft dieselbe Person oder dieselben Personen) implementiert die Änderung in der entsprechenden Spec, dann im Code. Die neue Version wird gemäß dem üblichen Verfahren bereitgestellt (Changelog, Kommunikation usw.).

## 4.3. Wenn die technische Entscheidung Probleme bereitet

Es kommt vor, dass man sich politisch auf eine Regel einigt, aber ihre technische Umsetzung kompliziert, aufwendig oder mit unerwünschten Nebeneffekten verbunden ist. Das ist normal. Die bestehenden Specs sind voll mit Hinweisen wie „diese politische Entscheidung erfordert Eingriffe in 22 Unter-SELECT in den RLS, was ein vorheriges Refactoring rechtfertigt". Der politisch-technische Dialog ist dauerhaft.

Wenn Sie einen Änderungsantrag einreichen, zögern Sie nicht, ihn auch dann einzureichen, wenn Sie keine Ahnung von der technischen Schwierigkeit haben. Die Entwickler*innen des Netzwerks werden Ihnen sagen, was es kostet. Und wenn es sehr teuer ist, können Sie kollektiv entscheiden, ob das politische Anliegen die technischen Kosten wert ist. Umgekehrt kann eine scheinbar nebensächliche politische Änderung manchmal die Codebasis erheblich vereinfachen.

## 4.4. Dieser Leitfaden ist selbst änderbar

Dieser Leitfaden ist versioniert. Die aktuelle Version ist auf der Titelseite angegeben. Wenn Sie der Meinung sind, dass er etwas Falsches sagt, einen Fall vergessen hat, oder eine Position einnimmt, die nicht mehr der Doktrin des Netzwerks entspricht, **sagen Sie es**. Eröffnen Sie eine Diskussion, schlagen Sie eine Änderung vor, oder schreiben Sie die Passage neu und reichen Sie sie ein.

Ein Leitfaden, der nicht geändert werden kann, ist kein Leitfaden, sondern ein Dogma. Das Projekt AnarBib hat nicht den Anspruch, Dogmen zu produzieren.

\newpage

# Teil II — Das Wie

\newpage

# 5. Jemanden in sein Team kooptieren

Dieses Kapitel behandelt die Übergänge T1 (`reader` → `librarian`) und T2 (`librarian` → `coordenador`), das heißt die **beiden Eintrittsbewegungen** in ein Bibliotheksteam. Die physische Validierung eines*einer neuen `reader` (die keine Kooptation im politischen Sinne ist, sondern eine technische Aufnahmeoperation) wird separat in §5.5 behandelt.

## 5.1. Das politische Prinzip

> **P2 — Kooptation für Personalrollen.** Der Eintritt in ein Team erfolgt durch Kooptation der bestehenden Koordinator*innen. Es ist Sache des politischen Kollektivs, zu entscheiden, wer aufgenommen wird; der*die coordenador*a ist nur die Hand, die die Entscheidung im SIGB ausführt.

Das bedeutet, dass **auf „Befördern" klicken** keine persönliche Entscheidung des*der klickenden coord ist. Es ist die **technische Ausführung** einer Entscheidung, die getroffen wurde — oder getroffen werden muss — vom politischen Kollektiv der Bibliothek. Die Netzwerkdoktrin zum „wann genau" die Entscheidung getroffen sein muss, wird von diesem Leitfaden bewusst nicht festgelegt: Jede Bibliothek macht ihre eigene Doktrin (siehe §5.4).

## 5.2. Um jemanden als `librarian` aufzunehmen (T1)

### Vorbedingungen

- Die Person hat ein AnarBib-Konto (sie ist irgendwo im Netzwerk registriert).
- Sie hat noch keine aktive `librarian`- oder `coordenador`-Membership in derselben Bibliothek.
- Sie kann, oder kann nicht, bereits eine `reader`-Membership in derselben Bibliothek haben. Falls ja, bleibt diese bestehende Membership parallel aktiv (Multi-Membership erlaubt).

### Verfahren im SIGB

1. Zu `/biblioteca` gehen, Reiter **Equipe** (sichtbar für `coordenador+`).
2. Wenn die Person bereits reader der Bibliothek ist, auf **„In das Team einladen"** auf ihrer Zeile klicken. Wenn sie noch kein reader ist, die Suche in der oberen Leiste verwenden, oder — wenn sie noch kein Konto hat — den E-Mail-Einladungsablauf verwenden (folgt, vgl. `spec-invitation-equipe.md`).
3. Die Rolle `librarian` wählen.
4. Die Modale bestätigen. Ein Feld „Grund" ist optional — es dient dazu, den Kontext der Kooptation im Audit-Log festzuhalten (zum Beispiel „Entscheidung VV vom 04.05." oder „Kooptation im kleinen Kreis, bei der nächsten VV zu bestätigen").
5. Das SIGB führt aus:
   - Erstellung einer Zeile `user_library_memberships` mit `role='librarian'`, `status='active'`.
   - E-Mail an die betroffene Person: „Du wurdest von [Sie] zur librarian von [Bibliothek] ernannt".
   - E-Mail an alle aktiven Koordinator*innen der Bibliothek.
   - Eintrag im Audit-Log: `action='promoted_to_librarian'`.

### Sofortige Wirkung

Die Person erhält ohne Verzögerung die Berechtigungen als `librarian`: Ausleihverwaltung, Validierung von Anmeldungen, Zugang zu personenbezogenen Daten der Leser*innen der Bibliothek usw. Sie erhält nicht die Berechtigungen zur Änderung der öffentlichen Identität oder der Konfiguration — diese sind den `coordenador+` vorbehalten.

### Technische Seite

Betroffene RPC: `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.3. Um ein*e `librarian` zu `coordenador` zu befördern (T2)

### Vorbedingungen

- Die Person hat eine aktive `librarian`-Membership `active` in der Bibliothek.
- Sie hat noch keine aktive `coordenador`-Membership in derselben Bibliothek.

### Verfahren im SIGB

1. Zu `/biblioteca` gehen, Reiter **Equipe**.
2. Auf der Zeile der Person auf **„Befördern"** → **„coordenador"** klicken.
3. Die Modale bestätigen. Das Feld „Grund" ist optional.
4. Das SIGB führt aus:
   - Erstellung (oder Reaktivierung) einer Zeile `coordenador` `active`. Die alte Zeile `librarian` bleibt parallel aktiv (Multi-Membership; siehe §5.6).
   - E-Mail an die Person.
   - E-Mail an alle aktiven Koordinator*innen.
   - Eintrag im Audit-Log: `action='promoted_to_coordenador'`.

### Sofortige Wirkung

Die Person erhält, zusätzlich zu ihren `librarian`-Berechtigungen, die Koordinationsberechtigungen: Änderung der öffentlichen Identität, der Konfiguration, der Beitragsregeln, und alle Governance-Aktionen des Teams.

### Technische Seite

Betroffene RPC: `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.4. Die politische Frage: Wann klicken?

Das ist die Frage, die sich jede*r coord beim ersten Mal stellt. Das Netzwerk AnarBib hat diese Frage auf Leitfadenebene **bewusst nicht entschieden**: Jede Bibliothek macht ihre eigene Doktrin, weil die politische Kultur eines anarchistischen Kollektivs nicht auf der Ebene eines allgemeinen Leitfadens festgelegt werden kann.

Hier sind die drei Doktrinen, die man im Netzwerk antrifft, ohne Wertung:

**Doktrin 1 — Strikte Wartezeit.** Man klickt erst **nach** einer protokollierten Entscheidung des Kollektivs (VV, Kreis, formaler Konsens, egal welche Modalität). Der*die coord führt nur aus. Vorteil: Maximierung der Horizontalität, starke politische Rückverfolgbarkeit. Nachteil: Kann langsam sein, besonders wenn die Bibliothek im Aufbau ist oder das Kollektiv verstreut ist.

**Doktrin 2 — Begrenzte Antizipation.** Der*die coord kann eine Entscheidung antizipieren, die er*sie für sicher hält („Es ist offensichtlich, dass Voltairine kooptiert wird, sie kommt seit sechs Monaten jede Woche"), **unter der Bedingung, dies im Audit-Log explizit festzuhalten**: Grund = „Antizipation unter meiner Verantwortung, bei der nächsten VV zu bestätigen". Die Entscheidung kann im Nachhinein angefochten werden, und der Rückzug ist immer möglich. Vorteil: praktische Flexibilität. Nachteil: verlagert einen Teil der politischen Verantwortung auf den*die klickende*n coord.

**Doktrin 3 — Koordinationskreis.** Die Kooptation wird durch Einigung zwischen den aktiven coords der Bibliothek getroffen, ohne durch die Vollversammlung zu gehen. Argument: Die Koordination ist selbst ein beratendes Kollektiv und hat das Mandat zu handeln. Vorteil: Zwischenlösung zwischen 1 und 2. Nachteil: Kann undurchsichtig werden, wenn die Koordination selbst nicht erneuert wird.

**Unsere Empfehlung** (und nicht mehr): **Entscheiden Sie sich explizit** für eine Doktrin, schreiben Sie sie in das Reglement Ihrer Bibliothek, und geben Sie sie bei jeder Kooptation im Feld „Grund" des Audit-Logs an (z. B. „Doktrin 2 — Antizipation unter meiner Verantwortung"). Undurchsichtigkeit ist in der Politik selten gut.

## 5.5. Sonderfall: die physische Validierung einer*eines `reader`

Die **Aufnahme** einer*eines `reader` in eine Bibliothek ist eine andere Operation als eine Kooptation im politischen Sinne. Sie wird durch die Spec `spec-validation-physique.md` abgedeckt.

Zwei mögliche Modi, die von jeder Bibliothek in ihrer Konfiguration gewählt werden:

**Modus `open`** — Die Validierung erfolgt **automatisch** bei der Anmeldung. Sobald das Konto erstellt und die E-Mail bestätigt ist, hat der*die `reader` sofortigen Zugang zu den Katalogen `public` und `network`. Geeignet für Bibliotheken mit geringem politischen Risiko.

**Modus `manual_validation`** — Das Konto wird online erstellt, bleibt aber **in Wartestellung**, bis ein **physisches Treffen** zwischen dem*der `reader` und einem*einer `librarian+` der Anmeldebibliothek stattgefunden hat. Geeignet für exponierte Bibliotheken (angespannte politische Lage, sensible Bestände, gefährdete Räumlichkeiten usw.).

### Verfahren der physischen Validierung (Modus `manual_validation`)

1. Die Person meldet sich online an und wählt Ihre Bibliothek als Stammbibliothek.
2. Ihr Konto wird mit `status='pending'` erstellt. Sie erhält eine E-Mail, die erklärt, dass sie sich physisch in der Bibliothek vorstellen muss.
3. Wenn sie kommt, trifft sie ein*e `librarian+`, der*die überprüft, was zu überprüfen ist (die Doktrin dessen, was „überprüfen" bedeutet, ist lokal), und klickt auf **„Validieren"** auf ihrer Zeile im Reiter **Equipe** → Abschnitt **Ausstehende Konten**.
4. Ein optionales Feld „Hinweis" ermöglicht es, einen Kontext festzuhalten („Treffen vom 12.05. während der Offenzeit, vorgestellt von Emma").
5. Das Konto wechselt zu `status='active'`. Die Person erhält eine Willkommens-E-Mail.

### Politisch wichtig

- Die physische Validierung einer Bibliothek **gilt für das gesamte Netzwerk** der Bibliotheken `network` (P7 nuanciert: die lokale Souveränität betrifft die internen Delegationen, aber die gegenseitige Anerkennung ist ein expliziter Pakt).
- Was bei einer physischen Validierung „überprüft" wird, ist **kein** Identitätsnachweis im administrativen Sinne. Es ist eine Begegnung. Jede Bibliothek definiert ihren politischen Sinn. Für manche bedeutet es „wir tauschen uns kurz aus, um sicherzustellen, dass die Person kein*e Polizist*in oder Faschist*in ist". Für andere bedeutet es „wir stellen die Bibliothek, ihre Funktionsweise und ihre Regeln vor". Für noch andere bedeutet es schlicht „wir treffen uns persönlich, damit die Beziehung verkörpert ist".
- Eine Bibliothek kann den Modus **jederzeit wechseln** (`coordenador+`). Der Wechsel macht bestehende Validierungen nicht ungültig.

## 5.6. Die Multi-Membership, ein Punkt zur Aufmerksamkeit

Eine technische Besonderheit, die es zu verstehen gilt: Eine Person kann **mehrere Zeilen** der Membership in derselben Bibliothek haben, mit verschiedenen Rollen. Zum Beispiel kann Voltairine gleichzeitig `reader` und `librarian` von BLMF sein. Dies wird ermöglicht durch die UNIQUE-Bedingung auf dem Triplett `(user_id, library_id, role)`.

**Warum diese Möglichkeit:** Sie bewahrt die Geschichte. Wenn Voltairine sich morgen von `librarian` zu `reader` zurückstuft, wechselt ihre `librarian`-Zeile zu `inactive`, aber die `reader`-Zeile bleibt — ohne eine neue Anmeldung von Grund auf neu erstellen zu müssen.

**Praktische Konsequenz:** In der Oberfläche wird die Person **einmal angezeigt**, mit ihrer **höchsten aktiven Rolle** (administrador > coordenador > librarian > reader). Im Audit-Log hingegen wird jede Zeile separat angezeigt.

## 5.7. Fehler und Sicherheitsvorkehrungen

Einige Fälle, die regelmäßig vorkommen:

**„Das SIGB sagt mir, dass die Person bereits librarian ist."** Das stimmt wahrscheinlich. Überprüfen Sie den Reiter **Equipe**: Wenn die Person dort bereits als librarian aufgeführt ist, versuchen Sie, sie auf dasselbe Niveau zu befördern, und das SIGB gibt einen stillen Erfolg zurück (`{ok: true, no_change: true}`), weil nichts zu tun ist.

**„Ich sehe die Person nicht in der Liste."** Drei mögliche Fälle: (a) Sie hat noch kein AnarBib-Konto (den künftigen E-Mail-Einladungsablauf verwenden); (b) Sie hat ein Konto, ist aber in keiner Bibliothek angemeldet (sie muss sich zuerst als `reader` in Ihrer Bibliothek anmelden); (c) Sie ist im Netzwerk, aber durch die Suche gefiltert — mit ihrer genauen E-Mail-Adresse suchen.

**„Ich habe versehentlich auf Befördern geklickt."** Keine Panik. **„Rückzug beantragen"** verwenden, um eine Wartefrist von 7 Tagen zu eröffnen (vgl. Kapitel 6), oder die Person bitten, auf **„Ich übergebe"** zu klicken (sofortige Selbstrückstufung). „Versehen" als Grund angeben.

**„Die Person erhält keine E-Mail."** Zunächst die Schreibweise ihrer E-Mail-Adresse in ihrem Profil überprüfen und sie bitten, ihren Spam-Ordner zu prüfen. Wenn das Problem anhält, eine*n Netzwerkadmin ansprechen: Das ist wahrscheinlich ein zu untersuchendes E-Mail-Konfigurationsproblem.

## 5.8. Wenn die Regel Sie stört

Mehrere Aspekte dieses Kapitels könnten Ihnen nicht zusagen:

- **Das Kooptationsprinzip selbst** (P2). Sie denken, dass jede*r engagierte `reader` frei zu `librarian` wechseln können sollte, ohne Kooptation zu benötigen. Das ist eine grundlegende politische Debatte, die Prinzip P1 berührt. Auf den Netzwerkkoordinationskanal bringen und wahrscheinlich auf einem Treffen diskutieren.

- **Das Fehlen einer entschiedenen Doktrin zum „wann klicken"** (§5.4). Sie denken, der Leitfaden sollte nur eine Doktrin empfehlen. Oder umgekehrt finden Sie, er legt zu viele nahe. Einen Änderungsantrag zu diesem Kapitel einreichen, mit Begründung.

- **Die Modi der physischen Validierung** (§5.5). Sie denken, es bräuchte einen dritten Modus („verzögerte Validierung", „Fernvalidierung", anderes). Auf `spec-validation-physique.md` bringen.

- **Die Multi-Membership** (§5.6). Sie denken, das sei unnötig komplex und es sollte nur eine Rolle pro Person pro Bibliothek geben. Das ist eine Datenmodellentscheidung, strukturgebender als es scheint. Mit den Entwickler*innen besprechen.

Siehe Kapitel 4 für das allgemeine Änderungsverfahren und Anhang C für die Notizenvorlage.

\newpage

# 6. Übergeben, Austreten, Suspendieren

Dieses Kapitel behandelt die Übergänge T3 bis T8 — d. h. **alles, was eine Person aus einem Team herauslöst** oder sie pausiert. Politisch ist dies vermutlich das wichtigste Kapitel des Leitfadens, da die Ausschlussmechanismen im Kern des anarchistischen Projekts stehen (vgl. Kapitel 1, §1.2).

## 6.1. Die politischen Grundsätze

Drei Grundsätze strukturieren dieses Kapitel :

> **P3 — Freiwillige Rückstufung jederzeit möglich.** Jede Person mit einer Staff-Rolle kann sich jederzeit selbst zurückstufen, ohne Absprache. „Ich übergebe" ist ein Grundrecht.

> **P4 — Ausschluss mit geregelter Wartefrist.** Der unfreiwillige Ausschluss einer*s `librarian` durch eine*n `coordenador*a` ist mit einer siebentägigen Wartefrist vor Inkrafttreten verbunden. Diese Frist ermöglicht kollektive Beratung und eventuelle Aufhebung durch eine*n anderen `coordenador*a`.

> **P6 — Systematische Benachrichtigungen.** Jede Rollenänderung löst eine E-Mail an die betroffene Person und an die gesamte Koordination aus.

Der grundlegende Gedanke ist, dass niemand jemals „überraschend" oder „still" aus einem Team entfernt wird. Entweder entscheidet die Person selbst (und das wirkt sofort), oder das Kollektiv fordert es (und das ist dokumentiert, benachrichtigt und bis zur letzten Sekunde beratbar).

## 6.2. Übergeben : Selbst-Rückstufung (T3 und T4)

Dies ist das **fundamentalste Recht** im Governance-System von AnarBib. Jede Person, die eine Staff-Funktion ausübt, kann diese jederzeit, ohne jegliche Absprache, niederlegen.

### Wann anwenden

- Du hast keine Zeit mehr, die Funktion zu übernehmen.
- Du erkennst dich nicht mehr in den Entscheidungen der Koordination wieder.
- Du bist mit einer Entscheidung nicht einverstanden und möchtest dich davon distanzieren.
- Du möchtest die Funktion einfach rotieren lassen.
- Du brauchst eine Pause.
- Kein Grund muss angegeben werden. Das Recht zu gehen ist bedingungslos.

### Verfahren

1. Zu `/biblioteca` gehen, Reiter **Equipe**.
2. Auf **deiner eigenen Zeile** auf **„Ich übergebe"** klicken.
3. Das Rückstufungsniveau auswählen :
   - Wenn du `coordenador` bist, kannst du wählen „zu `librarian` zurückkehren" (du bleibst im Team als `librarian`) oder „das Team verlassen" (du wirst wieder `reader`).
   - Wenn du `librarian` bist, kannst du wählen „das Team verlassen" (du wirst wieder `reader`).
4. Der Modal-Dialog erinnert an die Folgen. Bestätigen.

### Sofortwirkung

- Deine aktuelle Mitgliedschaft (`librarian` oder `coordenador`) wechselt zu `inactive`.
- Falls du die Zielmitgliedschaft (`reader` oder `librarian`) noch nicht hattest, wird sie als `active` angelegt.
- E-Mail an die gesamte Koordination + an dich selbst (Bestätigung).
- Audit-Log : `action='self_demoted'`.

### Sonderfall : du bist die*der einzige aktive `coordenador*a`

Das SIGB **lässt dich gehen**, warnt dich aber :

> ⚠️ ACHTUNG : Du bist die*der einzige aktive `coordenador*a` von [Bibliothek]. Die Bibliothek wird ohne Koordination dastehen. Die AnarBib-Administrator*innen werden benachrichtigt. Fortfahren?

Wenn du bestätigst :
- Deine Koordinations-Mitgliedschaft wechselt zu `inactive`.
- Die Bibliothek tritt in einen **eingeschränkten Modus** : die `librarian` können weiterhin Ausleihen verwalten, Anmeldungen bestätigen usw., aber keine Änderungen an der öffentlichen Identität oder Konfiguration sind möglich, bis eine*n neue*n Koordinator*in kooptiert wird.
- E-Mail an alle Netzwerk-Administrator*innen : „Die Bibliothek X hat keine*n `coordenador*a` mehr. Folgende Bibliothekar*innen sind aktiv : ..."

Politisch ist das wichtig : das SIGB **verhindert nicht** dein Gehen. Aber es informiert das Netzwerk, damit eine*n Netzwerk-Administrator*in — wenn du es möchtest und wenn das lokale Kollektiv es braucht — Kontakt aufnehmen kann, um die Übergabe zu unterstützen. Das ist die Rotation der Funktionen in Aktion.

### Technische Seite

RPC : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

## 6.3. Den Austritt einer*s `librarian` beantragen (T5)

Wenn das Kollektiv entscheidet, dass eine Person das Team verlassen soll, und diese Person sich nicht selbst zurückstuft, wird ein **Austrittsantrag mit siebentägiger Wartefrist** eröffnet.

### Voraussetzungen

- Du bist aktive*r `coordenador+` der Bibliothek.
- Die Zielperson hat eine `librarian`- oder `coordenador`-Mitgliedschaft mit Status `active`.
- Du bist nicht die Zielperson (sonst §6.2 verwenden).

### Verfahren

1. Zu `/biblioteca` gehen, Reiter **Equipe**.
2. Auf der Zeile der Person auf **„Austritt beantragen"** klicken.
3. Der sich öffnende Modal-Dialog ist **rot und nachdrücklich**. Er erinnert an :
   - Die Wartefrist : „Dieser Antrag tritt am [Datum T+7] in Kraft, sofern er nicht von einer*einem anderen `coordenador*a` aufgehoben wird."
   - Den reversiblen Charakter : „Annullierbar durch jede*n Koordinator*in bis zum Wirksamkeitsdatum."
   - Den kollegialen Charakter : „Alle aktiven Koordinator*innen werden benachrichtigt."
4. Ein Feld **„Grund"** ist obligatorisch — mindestens 20 Zeichen. Kein stiller Austritt. Der Grund kann politisch sein („Beschluss der Vollversammlung vom 04/05") oder praktisch („angekündigter geografischer Wegzug"). Er ist im Audit-Log für das gesamte aktive Staff lesbar.
5. Bestätigen.

### Sofortwirkung

- Die Mitgliedschaft wechselt zu `pending_removal`.
- Feld `pending_removal_until` = `now() + 7 days`.
- Feld `pending_removal_requested_by` = du.
- **Kein Zugang** für die Person während der Wartefrist (die Mitgliedschaft ist eingefroren wie bei `suspended`).
- E-Mail an die betroffene Person : „Die Koordination hat deinen Austritt aus dem Team [Bibliothek] beantragt (Vorankündigung bis [Datum]). Diese Entscheidung gehört zum organischen Leben des Kollektivs [Bibliothek] ; für jede Diskussion wende dich an die Koordination."
- E-Mail an alle aktiven Koordinator*innen : mit deinem Namen und dem Grund.
- Audit-Log : `action='removal_requested'` mit deiner `actor_user_id` und dem Feld `reason`.

### Wirkung an T+7 (automatischer Cron)

Falls der Antrag weder annulliert noch kurzgeschlossen wurde :
- Die Mitgliedschaft wechselt zu `inactive`.
- Abschließende E-Mail an die Person und die Koordination : „Austritt vollzogen."
- Audit-Log : `action='removal_completed'`.

### Technische Seite

RPC : `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron : `cron_team_pending_removal_complete` (läuft täglich).

## 6.4. Einen Austrittsantrag annullieren (T8)

Das **kollegiale Sicherheitsnetz** des Systems. Jede*r Koordinator*in — nicht notwendigerweise diejenige*derjenige, die*der den Antrag gestellt hat — kann einen Austrittsantrag während der Wartefrist annullieren.

### Wann anwenden

- Die kollektive Diskussion hat zu einer anderen Entscheidung geführt (Mediation, temporäre Suspension statt Austritt usw.).
- Der ursprüngliche Antrag wurde im Affekt gestellt, und die Koordination möchte kollegial neu übernehmen.
- Die Zielperson wurde schließlich erreicht und die Situation ist entschärft.

### Verfahren

1. Zu `/biblioteca` gehen, Reiter **Equipe**, Abschnitt **Suspensionen und laufende Vorankündigungen**.
2. Auf der Zeile der Person mit `pending_removal` auf **„Antrag annullieren"** klicken.
3. Einfacher Bestätigungs-Modal-Dialog. Feld „Grund" optional.
4. Bestätigen.

### Sofortwirkung

- Die Mitgliedschaft kehrt zu `active` zurück.
- Feld `pending_removal_until` wird auf NULL zurückgesetzt.
- E-Mail an die Person : „Der Austrittsantrag wurde annulliert. Du erhältst deine Befugnisse zurück."
- E-Mail an die gesamte Koordination.
- Audit-Log : `action='removal_cancelled'` mit deiner `actor_user_id`.

### Politisch

Die Annullierung ist bewusst sehr einfach zu aktivieren. Es ist ein Mechanismus des **kollegialen Gleichgewichts** : Wenn eine*n Koordinator*in im Affekt einen Austritt beantragt hat, kann jede*r andere Koordinator*in die Vollstreckung aussetzen, bis das Kollektiv beraten hat. Das macht Austrittsanträge weniger schwerwiegend (kein irreversibles Drama), aber auch weniger leichtfertig (jede*r kann dir widersprechen). Das ist der Sinn der Wartefrist.

### Technische Seite

RPC : `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Sofortige Suspension : die Sicherungsmaßnahme (T6 und T7)

Die Suspension ist ein **anderes** Werkzeug als der Austrittsantrag. Sie ist **sofort wirksam**, ohne Wartefrist, und **ohne maximale Dauer**. Sie ist kein Ausschluss, sondern eine **Pausierung**.

### Wann anwenden

Vorgesehene Typfälle gemäß der Spezifikation :

- **Kompromittiertes Konto** : Es gibt Grund zu der Annahme, dass das Passwort der Person durchgesickert ist. Man suspendiert, bis die Person ihr Passwort geändert hat.
- **Dringend gemeldete Belästigung** : Eine*n Leser*in meldet missbräuchliches Verhalten eines*einer Staff-Mitglieds. Man suspendiert, bis die kollektive Untersuchung abgeschlossen ist.
- **Direkt beobachtetes offensichtlich missbräuchliches Verhalten** : Man suspendiert, bis die Koordination zusammentritt.
- **Laufender Mediationskonflikt** : Die Person wird freiwillig pausiert, bis die Mediation abgeschlossen ist.

### Verfahren

1. Zu `/biblioteca` gehen, Reiter **Equipe**.
2. Auf der Zeile der Person auf **„Suspendieren"** klicken.
3. Modal-Dialog mit einem **obligatorischen Feld „Grund der Suspension"** (mindestens 20 Zeichen). Dieser Grund ist im Audit-Log für das gesamte aktive Staff lesbar.
4. Bestätigen.

### Sofortwirkung

- Die Mitgliedschaft wechselt zu `suspended`.
- **Kein Zugang** für die Person. Die nominelle Rolle bleibt erhalten (sie wird weiterhin als „suspendierte*r `librarian`" angezeigt), aber sie kann nichts mehr tun.
- E-Mail an die betroffene Person : dringend, mit dem Grund, und — im Falle eines kompromittierten Kontos — mit der Aufforderung, das Passwort zu ändern.
- E-Mail an die gesamte Koordination.
- Audit-Log : `action='suspended'` mit deiner `actor_user_id` und dem Feld `reason`.

### Aufhebung der Suspension

Wenn die Situation gelöst ist (Konto wieder gesichert, Mediation abgeschlossen, Untersuchung beendet usw.) :

1. Reiter **Equipe** → Abschnitt **Suspensionen und laufende Vorankündigungen**.
2. Auf der suspendierten Zeile auf **„Suspension aufheben"** klicken.
3. Einfacher Modal-Dialog. Begründungsfeld optional, aber empfohlen, um den Vorfall politisch abzuschließen.
4. Bestätigen.

Wirkung : Rückkehr zu `active`, E-Mails, Audit-Log `action='unsuspended'`.

### Wichtig : Suspension vs. Austritt

Die Unterscheidung ist entscheidend :

| | Suspension (T6) | Austritt (T5) |
|---|---|---|
| Wirkung | Sofort | Verzögert (T+7) |
| Dauer | Unbestimmt | 7 Tage, dann `inactive` |
| Reversibel durch | Explizite Aufhebung | Annullierung während der Wartefrist |
| Typische Verwendung | Sicherungsmaßnahme | Ausschlussentscheidung |
| Zugrunde liegende Politik | „Wir nehmen uns Zeit zum Verstehen" | „Wir haben entschieden, dass diese Person geht" |

Das SIGB **weigert sich**, eine Mitgliedschaft direkt von `suspended` zu `pending_removal` zu überführen (der Übergang ist von der Matrix nicht erlaubt). Warum : Es sind zwei politisch unterschiedliche Zeitlichkeiten. Um von einer zur anderen zu wechseln, muss man zunächst explizit **die Suspension aufheben** (Rückkehr zu `active`), dann den Austritt beantragen (`pending_removal`). Dieser doppelte Schritt ist beabsichtigt : Er zwingt das Kollektiv, den Übergang explizit zu vollziehen.

### Technische Seite

RPC suspendieren : `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC aufheben : `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Eine*n anderen `coordenador` zurückstufen (kollektives T3)

Ein etwas besonderer Fall : Was tun, wenn die Koordination eine*n `coordenador*a` **zurückstufen** möchte, die*der sich nicht spontan zurückstuft ?

Die Governance-Spezifikation behandelt diesen Fall als **Austrittsantrag mit Wartefrist**, der auf die `coordenador`-Mitgliedschaft abzielt. Konkret verwendest du dasselbe Verfahren wie in §6.3 („Austritt beantragen"), wählst aber die Rolle `coordenador`. Die Person wechselt bei ihrer `coordenador`-Mitgliedschaft zu `pending_removal` ; an T+7 wechselt diese Mitgliedschaft zu `inactive`. Wenn sie parallel eine `librarian`-Mitgliedschaft hatte, bleibt diese aktiv (und die Person „fällt zurück" auf `librarian`). Andernfalls wird sie wieder einfache*r `reader`.

Es ist bewusst derselbe Mechanismus wie für `librarian`, mit denselben Sicherheitsnetzen. **Keine andere Koordinator*in hat eine besondere Macht** über ihre Kolleg*innen : Das Verfahren durchläuft die Wartefrist und die Kollegialität.

## 6.7. Verlassenes Konto : automatischer Austritt (T9)

Das SIGB enthält einen Mechanismus für den **automatischen Austritt** bei Konten, die seit langer Zeit keine Verbindung hatten.

### Der Schwellenwert

Das SIGB prüft das Feld `last_sign_in_at` auf Supabase-Seite. Wenn eine Staff-Mitgliedschaft eine*n Nutzer*in hat, dessen*deren letzte Verbindung mehr als **9 Monate** zurückliegt, wird das Konto schrittweise ausgeschieden :

- **T-30 Tage** (8 Monate nach der letzten Verbindung) : Warnungs-E-Mail an die Person („deine Mitgliedschaft wird in 30 Tagen ohne Verbindung deaktiviert").
- **T-7 Tage** : Erinnerungs-E-Mail.
- **T = 9 Monate** : Automatischer Wechsel zu `inactive`. Abschließende E-Mail an die Person + an die gesamte Koordination.

### Warum diese Regel

Es ist ein Kompromiss zwischen zwei Anforderungen :

- Keine **Phantommitgliedschaften** unbegrenzt schleifen lassen, die die Teams künstlich aufblähen.
- Eine Person, die nur eine Pause gemacht hat und zurückkehren möchte, nicht **brutal vertreiben**.

Eine einfache Verbindung genügt, um den Zähler zurückzusetzen. Es muss keine Aktion durchgeführt werden, einfach einloggen.

### Sonderfall : die*der einzige Koordinator*in verlässt das System

Wenn die automatisch ausgeschiedene Person die **einzige aktive `coordenador*a`** der Bibliothek ist, eskaliert der Cron an eine*n Netzwerk-Administrator*in **vor** der Durchführung des Austritts. Die Netzwerk-Administrator*in wird per E-Mail benachrichtigt, kann Kontakt mit der Koordination aufnehmen (falls noch ein Fragment vorhanden ist) oder mit den `librarian` der Bibliothek, und die Übergabe koordinieren.

Politisch ist das kohärent mit dem Vorgehen, wenn die*der einzige Koordinator*in sich explizit zurückstuft (§6.2) : Der Austritt wird nicht blockiert, aber das Netzwerk wird alarmiert, damit es helfen kann, wenn nötig.

## 6.8. Einige Grenzfälle, die man kennen sollte

**Eine Person in `pending_removal`, die sofort gehen möchte.** Sie kann. Es genügt, dass sie selbst „Ich übergebe" verwendet (Selbst-Rückstufung T4). Wirkung : sofortiger Wechsel zu `inactive`, Kurzschluss der Wartefrist. Politisch ist das kohärent : das Recht P3 (Selbst-Rückstufung) ist bedingungslos.

**Eine Person in `suspended`, die man dauerhaft ausschließen möchte.** Siehe §6.5 „Wichtig : Suspension vs. Austritt". Die Suspension muss zuerst aufgehoben werden, dann der Austritt beantragt werden.

**Jemand beantragt den eigenen Austritt über „Austritt beantragen".** Das SIGB lehnt dies mit einer expliziten Meldung ab : „Um das Team zu verlassen, verwende die Option ‚Ich übergebe' (Selbst-Rückstufung)." Das ist beabsichtigt : Eine persönliche Entscheidung mit einer kollektiven Entscheidung zu verwechseln würde die politische Semantik verwischen.

**Versuch, eine*n Netzwerk-Administrator*in zurückzustufen.** Systematisch abgelehnt. Die Rolle der Netzwerk-Administrator*in kann nur über die spezifischen Mechanismen der `admin-reseau`-Spezifikation geändert werden (vgl. Kapitel 8). Keine*n lokale*r Koordinator*in kann eine*n Netzwerk-Administrator*in absetzen.

## 6.9. Wenn die Regel dich stört

**Die Wartefrist von 7 Tagen erscheint dir zu lang oder zu kurz.** Auf `spec-gouvernance-roles.md` einbringen, §4.4 und §5.6.

**Du findest, dass die Suspension ohne maximale Dauer ein Einfallstor für Willkür ist.** Das ist ein ernstes politisches Thema. Man könnte erwägen, eine Frist hinzuzufügen, nach der eine Suspension in einen Austritt umgewandelt oder aufgehoben werden muss. In der Netzwerk-Koordination besprechen, dann auf die Spezifikation einbringen.

**Du findest, dass die Begründungspflicht bei der Suspension ein bürokratischer Überschuss ist.** Oder umgekehrt findest du, dass das Minimum von 20 Zeichen zu kurz ist. Auf die Spezifikation einbringen.

**Du findest, dass der automatische Austritt nach 9 Monaten zu schnell oder zu langsam ist.** Der Schwellenwert ist konfigurierbar, ist aber heute für alle Bibliotheken im Netzwerk gleich. Soll er pro Bibliothek konfigurierbar gemacht werden ? Zu besprechen.

Siehe Kapitel 4 und Anhang C für das Änderungsverfahren.

\newpage

# 7. Wenn etwas schiefläuft

Dieses Kapitel behandelt **Ausnahmesituationen**, in denen die gewöhnlichen Governance-Mechanismen nicht ausreichen oder zwar funktionieren, aber politisches Urteilsvermögen erfordern. Es ist auch das Kapitel, in dem offen über **Bibliotheken gesprochen wird, die kein (oder kein aktives) kollektives Beratungsleben haben**, weil das Schweigen darüber mehr Schaden anrichten würde als die Offenheit.

## 7.1. Bibliothek ohne Vollversammlung oder mit wenigen Mitgliedern

Dieser Fall ist häufiger als es scheint. Eine Bibliothek in der Gründungsphase mit zwei oder drei Personen. Eine Bibliothek, deren Kollektiv durch Abgänge geschrumpft ist. Eine Bibliothek, deren Vollversammlung aus Personalmangel oder Entmutigung schon eine Weile nicht mehr stattgefunden hat.

Das SIGB mischt sich nicht in das politische Leben eines Kollektivs ein. Aber dieser Leitfaden muss offen sagen, was sich ändert, wenn dieses kollektive Leben schwach ist.

### Was sich konkret ändert

**Das Wort „Kooptation" wird mehrdeutig.** Bei zwei Personen: Wer kooptiert wen? Wenn die einzige Koordinator*in Voltairine ins Team aufnehmen möchte, entscheidet sie im politischen Sinne „allein". Das SIGB lässt das zu (eine Koordinator*in+ kann kooptieren), aber es ist nicht mehr die Kooperation eines politischen Kollektivs, sondern eine als solche verkleidete persönliche Entscheidung. Das ist weder gut noch schlecht — es muss einfach anerkannt werden.

**Beratungen sind theoretisch.** Ein Rückzugsantrag mit 7-tägiger Frist in einer Bibliothek mit 2 Personen hat niemanden, der ihn widerlegen könnte, außer der Person, die ihn gestellt hat. Die „kollegiale Sicherheitsschranke" wird zur Selbstreflexion.

**Das Risiko der Personalisierung steigt.** Wenn eine Entscheidung nicht mehr kollektiv ist, hängt sie vom Charakter, der Verfügbarkeit und der Klarheit ein oder zwei Personen ab. Das ist nicht per se katastrophal, aber fragiler.

### Unsere expliziten Empfehlungen

**1. Erkennt die Situation an.** Tut nicht so, als wärt ihr ein großes beratendes Kollektiv, wenn ihr zu zweit seid. Politisch ist es gesünder, im Feld „Begründung" des Audit-Logs zu schreiben „Entscheidung allein getroffen, zur Bestätigung wenn das Kollektiv gewachsen ist", als dort „VV-Entscheidung" einzutragen für eine VV, die nicht stattgefunden hat.

**2. Sucht Dialog nach außen.** Wenn ihr allein oder zu zweit seid und eine wichtige Entscheidung ansteht (Kooptation, Rückzug, Suspension), gewöhnt euch an, mit Genoss*innen anderer Bibliotheken im Netzwerk oder mit einer Netzwerk-Administrator*in darüber zu sprechen. Nicht um sie um Erlaubnis zu bitten — sie haben keine internen Entscheidungen eurer Bibliothek zu bestätigen — sondern um ein kritisches externes Feedback zu bekommen. Das AnarBib-Matrix-Netzwerk ist genau dafür da.

**3. Bevorzugt reversible Übergänge.** Wenn euer Kollektiv klein ist, vermeidet nach Möglichkeit irreversible Entscheidungen. Eine Suspension ist reversibler als ein Rückzug. Ein Rückzug hat eine 7-tägige Frist, in der ihr eure Meinung ändern könnt. Eine Kooptation ist rückgängig zu machen. Gebt euch Zeit.

**4. Dokumentiert, was passiert.** Das Feld „Begründung" im Audit-Log ist eure beste Freundin. Je mehr Kontext ihr dort eingebt (z. B. „Kooptation von Voltairine, allein entschieden, bei der nächsten Schicht zu bestätigen"), desto besser kann die Entscheidung später eingeordnet werden — von euch selbst wie von einem*einer neuen Mitglied des Kollektivs.

**5. Wenn ihr wirklich isoliert seid, bittet um Hilfe.** Eine Bibliothek mit einer Person ist politisch in der Krise. Das SIGB erkennt das, wenn die letzte Koordinator*in sich zurückstuft (§6.2) oder aufgibt (§6.7), und alarmiert die Netzwerk-Administrator*innen. Ihr könnt auch selbst die Initiative ergreifen: Schickt eine Mail an die Netzwerkkoordination, um die Situation zu erklären. Mehrere Bibliotheken im Netzwerk haben Tiefphasen durchlebt und wurden bei der Neuaufstellung unterstützt.

### Was dieser Leitfaden nicht tut

Er bietet **kein** Sonderverfahren für kleine Bibliotheken. Das ist Absicht. Die SIGB-Regeln gelten einheitlich — was sich ändert, sind die politischen Bedingungen, unter denen sie gelten. Diese Nuance zu erkennen, gehört zur politischen Reife einer Koordinator*in.

## 7.2. Interpersoneller Konflikt in einer Koordination

Ein Konflikt bricht zwischen zwei Staff-Mitgliedern aus. Die Arbeit läuft nicht mehr richtig, die Atmosphäre verschlechtert sich, Leser*innen nehmen die Spannung wahr.

### Was das SIGB tun kann

Nicht viel, direkt. Das SIGB schlichtet keine Konflikte. Aber es stellt **nutzbare Werkzeuge** bereit:

- **Vorläufige Suspension (T6)** einer oder beider Personen, bis der Konflikt mediiert ist. Das ist, was die Spec explizit als legitimen Anwendungsfall der Suspension für „laufende Mediation bei Konflikten" benennt.
- **Selbst-Rückstufung (T3/T4)** — wenn eine der beiden Personen beschließt, einen Schritt zurückzutreten, geht das sofort.
- **Für das gesamte Staff einsehbares Audit-Log** — ermöglicht es dem gesamten Staff zu sehen, wer was getan hat, und verhindert undurchsichtige Manipulationen durch eine Koordinator*in, die versucht, den Konflikt durch das stille Entfernen der anderen Person zu lösen.

### Was das Kollektiv tun muss

- **Mediation**. Das SIGB mediiert nicht. Es braucht eine vertrauenswürdige Drittpartei außerhalb des Konflikts. Je nach Situation: eine andere Koordinator*in der Bibliothek, eine Genoss*in einer anderen Bibliothek, eine Netzwerk-Administrator*in.
- **Kollektive Entscheidung**. Wenn die Mediation zu einer Entscheidung führt (eine der beiden Personen verlässt die Koordination, oder es wird ein überarbeiteter Arbeitsrahmen festgelegt), wird das SIGB diese Entscheidung über die normalen RPCs ausführen.
- **Politische Spur**. Wenn die Entscheidung lautet, jemanden zurückzuziehen, sollte das Feld „Begründung" den Mediationsprozess erwähnen (z. B. „Rückzug nach Mediation vom JJ/MM, kollektive Entscheidung"), um die Geschichte später nicht umzuschreiben.

### Was zu vermeiden ist

- **Eine Suspension als Waffe** im Konflikt einsetzen. Die Suspension dient dazu, eine Pause einzulegen, nicht dazu, ein Kräfteverhältnis zu gewinnen. Wenn eine Koordinator*in die andere ohne Mediationsprozess suspendiert, ist das im Audit-Log sichtbar und politisch problematisch.
- **Die Handlungsunfähigkeit durch technische Manöver umgehen** (suspendieren und dann mit anderen Mitteln „beschleunigen"). Alles wird aufgezeichnet, und das Netzwerk wird es bemerken.
- **Das Audit-Log totschweigen**. Das gesamte Staff sieht, was passiert (P5). Wenn ihr versucht, den Konflikt zu verbergen, verratet ihr die Transparenz des Kollektivs.

## 7.3. Gemeldete Belästigung

Eine Leser*in meldet, dass ein Staff-Mitglied ein missbräuchliches Verhalten zeigt (sexuelle Belästigung, Machtmissbrauch, rassistisches Verhalten usw.).

### Empfohlenes Vorgehen

**1. Die Meldung sofort ernst nehmen**, auch wenn die meldende Person allein dasteht und auch wenn die gemeldete Person „bekannt und geschätzt" in der Koordination ist. Der Reflex, die Meldung als „wahrscheinlich übertrieben" abzutun, ist der häufigste Fehler.

**2. Sofortige Suspension (T6)** der gemeldeten Person **als Schutzmaßnahme**, bis die Untersuchung abgeschlossen ist. Das Feld „Begründung" sollte so etwas sagen wie: „Schutz-Suspension nach Meldung vom JJ/MM, ausstehende kollektive Untersuchung". Die Suspension ist **keine** Anschuldigung, sondern eine Pause.

**3. Eine Untersuchungsgruppe zusammenstellen**. Außerhalb der Software. Mindestens: Genoss*innen außerhalb der direkten Machtsituation, die in der Lage sind, beide Seiten vorurteilsfrei zu hören. Diese Gruppe kann Genoss*innen anderer Bibliotheken umfassen, wenn die Bibliothek klein ist oder alle Koordinator*innen in die Sache verwickelt sind.

**4. Mit der meldenden Person kommunizieren**. Sie muss wissen, dass die Sache ernst genommen wird und dass Maßnahmen ergriffen werden. Sie nicht im Ungewissen lassen.

**5. Zu einer Entscheidung kommen**. Je nachdem, was die Untersuchung ergibt:
   - Aufhebung der Suspension (T7), wenn die Meldung nicht bestätigt wird.
   - Dauerhafter Rückzug (T5 mit Handlungsunfähigkeit), wenn die Meldung bestätigt wird und die Entscheidung ist, die Person zu entfernen.
   - Zwischenmaßnahme (überarbeiteter Arbeitsrahmen, Schulung, Ausschluss aus bestimmten Funktionen), wenn die Situation differenzierter ist.

**6. Politisch dokumentieren**. Das Feld „Begründung" im Audit-Log sollte die kollektive Entscheidung widerspiegeln. Keine Details zur betroffenen Person (DSGVO), aber eine Formulierung, die die Entscheidung nachvollziehbar macht.

### Was nicht getan werden darf

- **Einen Rückzug direkt beantragen**, ohne vorherige Suspension, obwohl die Situation dringend ist. Während der 7 Tage würde die gemeldete Person ihre Rechte behalten, was der Dringlichkeit einer Missbrauchsmeldung widerspricht.
- **Auf unbestimmte Zeit suspendieren ohne Entscheidung** mit dem Vorwand, „keine Einigung zu finden". Eine Suspension, die monatelang ohne Entscheidung andauert, wird selbst zur Gewalt (gegen die suspendierte Person, die sich nicht verteidigen kann, und gegen die meldende Person, die keine Antwort erhält).
- **Intern regeln ohne das Netzwerk**. Wenn ihr eine kleine Bibliothek seid und die Situation euch überfordert, bittet die Netzwerk-Administrator*innen um Hilfe. Ihr seid nicht allein.

## 7.4. Kompromittiertes Konto

Ein Staff-Mitglied stellt fest, dass sein Konto kompromittiert wurde (Passwort geleakt, Verdacht auf unbefugten Zugriff).

### Sofortiges Vorgehen

**1. Sofortige Suspension (T6)** des Kontos mit expliziter Begründung: „Verdacht auf Kompromittierung, Passwort wahrscheinlich geleakt, Überprüfung läuft".

**2. Kommunikation mit der betroffenen Person**. Die Person erhält automatisch eine dringende Mail mit dem Hinweis auf die Suspension und der Aufforderung, ihr Passwort zu ändern. Die suspendierende Koordinator*in sollte auch direkt Kontakt aufnehmen (Telefon, anderer sicherer Kanal), um dies zu bestätigen.

**3. Schnelle Untersuchung.** Was ist passiert? Hat das Konto ungewöhnliche Aktionen im Audit-Log vorgenommen (seltsame Kooptationen, Konfigurationsänderungen usw.)? Falls ja, sofort eine Netzwerk-Administrator*in informieren, um bei der Analyse zu helfen.

**4. Aufhebung der Suspension (T7)**, sobald:
   - Das Passwort geändert wurde.
   - Etwaige Schäden festgestellt und behoben wurden (Rückgängigmachen missbräuchlicher Aktionen, Wiederherstellung von Daten usw.).
   - Die Person digital in Sicherheit ist.

### Politisch

Eine Suspension wegen eines kompromittierten Kontos **ist kein Tadel**. Es ist gegenseitiger Schutz: Man schützt die Person (indem man verhindert, dass sie von einer Angreifer*in benutzt wird) und die Bibliothek (indem man verhindert, dass Schäden in ihrem Namen angerichtet werden). Die Mail an die Person sollte diesen **nicht-disziplinarischen** Charakter betonen.

## 7.5. Bibliothek ohne aktive Koordinator*in oder Bibliothekar*in

Das Katastrophenszenario: keinerlei aktive Staff-Person mehr. Das kann durch kumulierten Auto-Austritt geschehen (alle Staff-Mitglieder haben ihre Konten gleichzeitig aufgegeben), durch kollektive Kündigung (selten, aber möglich) oder durch eine Abfolge von Rückzügen.

### Konsequenzen

- Die Bibliothek bleibt **technisch aktiv** (ihre Sichtbarkeit, ihr Katalog bleiben gemäß den üblichen RLS zugänglich).
- Aber **keine Verwaltungsaktionen** können mehr über die normale UI durchgeführt werden: keine Anmeldungsbestätigung, keine Ausleihverwaltung, keine Konfigurationsänderung.
- **Dringende Mail an die Netzwerk-Administrator*innen** durch den Cron, der die Situation erkennt.

### Neustart-Verfahren

Außerhalb der Spec, aber folgendes wird praktiziert:

**1. Kontaktaufnahme** durch eine Netzwerk-Administrator*in mit dem lokalen Kollektiv über alle verfügbaren Kanäle (die verbleibenden Leser*innen-Konten, externe Kontaktdaten der Bibliothek, falls vorhanden, das lokale Beziehungsnetzwerk).

**2. Politische Überprüfung**: Existiert das Kollektiv noch? Will es weiter bestehen? Wenn es Mitglieder gibt, die nur die technischen Funktionen haben fallen lassen, kann neues Staff durch Kooptation außerhalb des Workflows kooptiert werden.

**3. Kooptation außerhalb des Workflows** durch die Netzwerk-Administrator*in, per direktem SQL oder über die UI (eine Netzwerk-Administrator*in hat das Recht, als Koordinator*in+ in jeder Bibliothek zu handeln, vgl. Kapitel 2). Die außerplanmäßige Kooptation muss im Audit-Log mit einer expliziten Begründung festgehalten werden: „Wiederaufnahme der Koordination nach Vakanz, nach Kontakt mit dem Kollektiv vom JJ/MM, durch Netzwerk-Administrator*in X". Und — ein zentraler Doktrinpunkt — **vorherige Information der lokalen Koordination ist obligatorisch**, außer wenn die Bibliothek keinerlei lebende Staff-Mitglieder mehr hat, in welchem Fall die Information über die verbleibenden aktiven `reader` läuft (vgl. §7.6).

**4. Wenn das Kollektiv nicht mehr existiert**: Einleitung einer Diskussion über die **geordnete Schließung** der Bibliothek. Welche Daten aufbewahren, welche löschen, wie man die Leser*innen informiert usw. Das ist ein Workflow, der separat formalisiert werden muss.

## 7.6. Die Intervention einer Netzwerk-Administrator*in in einer lokalen Bibliothek

Ein Fall, der bereits in Kapitel 2 behandelt wird, der aber in diesem Kapitel über Ausnahmesituationen eine praktische Entfaltung verdient.

### Die Netzwerkdoktrin

> **Eine Intervention einer Netzwerk-Administrator*in in einer lokalen Bibliothek muss von einer Information an die betroffene lokale Koordination begleitet werden, außer bei vitaler Dringlichkeit.**

Die vorherige Information **ist keine Genehmigungsanfrage**. Die Netzwerk-Administrator*in hat das Recht zu handeln (das ist der Sinn des transversalen Rechts). Aber sie ist ein Zeichen des Respekts gegenüber der lokalen Autonomie und erhält die Möglichkeit einer anderen Regelung.

### Was eine „vitale Dringlichkeit" ist

Das ist bewusst restriktiv gehalten. Typische Fälle:

- **Aktive Kompromittierung**: Eine laufende Aktion gefährdet die Integrität der Bibliothek oder des Netzwerks (angreifende Konto ändert gerade in Echtzeit Mitgliedschaften usw.).
- **Laufende Belästigung**: Ein Staff-Mitglied missbraucht aktiv seine Funktionen, die Gefahr für die Leser*innen ist unmittelbar.
- **Angriff auf die Plattform**: Einbruchsversuch, Datenexfiltration usw.

Außerhalb dieser Fälle **nimmt man sich die Zeit zu informieren**.

### Wie man informiert

Vor der Intervention (oder währenddessen, wenn die Dringlichkeit dies im Nachhinein rechtfertigt):

- **Mail an die lokale Koordination** mit Erklärung, was getan werden soll, warum und mit welcher Rückverfolgbarkeit.
- **Eintrag in der Tabelle `cross_library_actions_log`** mit einem Kritikalitätsniveau, das die Art der Aktion anzeigt. Alle aktiven Koordinator*innen der Bibliothek erhalten eine Benachrichtigung.
- **Gesprächsbereitschaft**: Die lokale Koordination muss Fragen stellen, Klärungen verlangen und sogar eine andere Regelung aushandeln können (z. B. „Lasst uns erst selbst versuchen").

### Was zu vermeiden ist

- **Die stille Intervention**: In der Bibliothek handeln, ohne die Koordination zu informieren. Auch wenn es technisch nachverfolgbar ist, ist es politisch eine Verletzung der lokalen Souveränität.
- **Die Ausübung des transversalen Rechts als Überwachungsmacht**: Nachschauen, „was passiert" in einer Bibliothek ohne operativen Grund. Das transversale Recht existiert für Wartungs- oder Mediationsfälle, nicht aus Neugier.
- **Die Auferlegung politischer Entscheidungen**: Eine Netzwerk-Administrator*in kann einer Bibliothek nicht vorschreiben, wie sie ihre Kooptationen gestalten, ihre internen Konflikte regeln oder welche Aufnahmepolitik sie wählen soll. Das transversale Recht ist technisch, nicht politisch.

## 7.7. Wenn euch die Regel stört

**Ihr findet die Doktrin der vorherigen Information zu locker** (eine Netzwerk-Administrator*in könnte die „vitale Dringlichkeit" missbrauchen). Zur Diskussion: Braucht es eine strengere Definition der Dringlichkeit? Braucht es eine zweite Netzwerk-Administrator*in, die die Dringlichkeit bestätigt?

**Ihr findet die Doktrin zu streng** (manchmal muss man schnell handeln, ohne alles zu erklären). Zur Diskussion: Sollte man mehrere Interventionsebenen unterscheiden, mit unterschiedlichen Informationsregeln je nach Kritikalität?

**Ihr findet, dass das Schweigen über die geordnete Schließung einer Bibliothek problematisch ist** (§7.5). Ihr habt Recht. Eine eigene Spec ist wahrscheinlich zu schreiben. Ans Netzwerk tragen.

**Ihr findet, dass dieses Kapitel bei Belästigungsfällen zu viel Raum für Improvisation lässt** (§7.3). Das stimmt wahrscheinlich. Eine eigene Spec zu Mediations- und Untersuchungsprozessen könnte nützlich sein. Ans Netzwerk tragen.

Siehe Kapitel 4 und Anhang C.

\newpage

# 8. Die Rolle der Netzwerk-Administrator*in

Dieses Kapitel richtet sich insbesondere an (gegenwärtige oder zukünftige) Netzwerk-Administrator*innen sowie an lokale Koordinationen, die verstehen möchten, wie das Netzwerk sich auf übergeordneter Ebene selbst organisiert. Es ergänzt und vertieft die Kapitel 2 und 7.

## 8.1. Eine eigenständige politische Funktion

Zunächst: **Netzwerk-Admin** zu sein ist weder ein Rang, noch eine Auszeichnung, noch ein Titel. Es ist eine **übergreifende Funktion**, die das Kollektiv der Netzwerk-Administrator*innen bestimmten Mitgliedern überträgt — auf Basis einstimmiger Zustimmung der bereits aktiven Administrator*innen —, und die jederzeit niedergelegt werden kann.

Das politische Ziel der Funktion besteht darin, **die Koordination zwischen den Bibliotheken lebendig zu halten**: neue Bibliotheken willkommen zu heißen, die dem Netzwerk beitreten, Diskussionen über technische und politische Weiterentwicklungen des SIGB anzustoßen, die Plattform technisch zu pflegen und einzugreifen, wenn eine Bibliothek in eine Sackgasse gerät. Es ist keine Leitungsfunktion. Es ist eine Animierungs- und Dienstleistungsfunktion.

### Was eine Netzwerk-Administrator*in (politisch) tun kann

- Eine neue Bibliothek aktivieren, die ihren Beitrittsantrag gestellt hat.
- Diskussionen zwischen Bibliotheken moderieren (den Matrix-Kanal `#anarbib`, Treffen, interne Mailinglisten).
- Die Weiterentwicklung der Plattform koordinieren (Specs, Releases, Kommunikation).
- Bei technischen Blockaden in jeder beliebigen Bibliothek eingreifen (übergreifendes Recht).
- Zwischen zwei Bibliotheken vermitteln, wenn es Konflikte gibt (sofern die Koordinationen dies wünschen).
- Die Kooptation und den kollektiven Entzug anderer Netzwerk-Administrator*innen vorschlagen oder darüber abstimmen.

### Was eine Netzwerk-Administrator*in (politisch) nicht tun kann

- Eine Bibliothek leiten.
- Einer Bibliothek eine politische Entscheidung aufzwingen (Aufnahmepolitik, Validierungsform, interne Kooptationen usw.).
- Eine*n lokale*n Koordinator*in gegen den Willen ihrer*seiner Bibliothek entfernen.
- Die Regeln des Netzwerks allein ändern (das erfordert eine kollektive Diskussion der Administrator*innen und idealerweise der Koordinationen).

## 8.2. Die Kooptation durch Einstimmigkeit: warum

Die Netzwerk-Administrator*in wird nicht per Mehrheitsentscheid aufgenommen, sondern mit **Einstimmigkeit** der aktiven Administrator*innen. Diese Regel mag überraschen — warum nicht eine einfache Mehrheit, eine qualifizierte Mehrheit oder ein Quorum?

Der politische Grund ist einfach: Die Macht einer Netzwerk-Administrator*in ist **übergreifend**. Sie kann in jeder beliebigen Bibliothek eingreifen. Daher muss **jede*r aktuell aktive Netzwerk-Administrator*in** bereit sein, mit der neuen Person zusammenzuarbeiten. Gibt es eine einzige tiefe Meinungsverschiedenheit, wird die Zusammenarbeit vergiftet — besser, man zwingt sie niemandem auf.

Diese Regel hat eine wichtige praktische Konsequenz: **Das Veto ist einfach**. Ein einziger `opposed`-Stimmzettel genügt. Das ist gewollt. Man nimmt lieber in Kauf, dass eine Kooptation scheitert, als eine*n bestehende*n Administrator*in dauerhaft in eine Zwangslage zu bringen.

## 8.3. Kooptations-Workflow im Detail

### Schritt 1 — Vorschlag

Eine*r aktive*r Netzwerk-Administrator*in klickt über die Oberfläche `/rede/administradores` (ab Paket D verfügbar) auf **„Kooptation vorschlagen"**.

- Gibt die Identität der vorgeschlagenen Person ein (sucht in der AnarBib-Nutzendenbasis).
- Gibt eine obligatorische **Begründung** von **mindestens 20 Zeichen** ein. Diese Begründung ist für alle Administrator*innen lesbar und wird — bei Erfolg — in die Benachrichtigung an die kooptierte Person aufgenommen.
- Bestätigt.

Das SIGB:
- Legt eine Zeile in `network_administrator_cooptation_proposals` an mit `status='open'`, `expires_at = now() + 30 Tage`.
- Trägt automatisch die `favorable`-Stimme der vorschlagenden Person ein.
- Sendet eine Aktivist*innen-E-Mail an alle anderen aktiven Administrator*innen und lädt sie zum Abstimmen ein.

### Schritt 2 — Abstimmungen

Jede*r andere aktive Administrator*in hat 30 Tage Zeit zu stimmen. Drei Optionen:

- **`favorable`**: Sie akzeptiert die Kooptation.
- **`opposed`**: Sie legt ihr Veto ein. **Obligatorische Begründung** von mindestens 20 Zeichen. Diese Begründung wird der vorgeschlagenen Person und der vorschlagenden Person im Falle einer Ablehnung mitgeteilt.
- **`abstain`**: Sie enthält sich. **Enthaltung blockiert**: Der Vorschlag führt nur bei Einstimmigkeit der `favorable`-Stimmen zum Erfolg. Eine nicht aufgehobene Enthaltung hat praktisch dieselbe Wirkung wie ein Veto, außer dass sie später in `favorable` umgewandelt werden kann, wenn die Person ihre Meinung ändert.

### Detail v0.3 — Offenlegung der Identität

Eine Option **„Meine Identität im Falle einer Ablehnung offenlegen"** ist standardmäßig aktiviert. Wenn Sie `opposed` stimmen, wird Ihre Identität der vorgeschlagenen Person und der vorschlagenden Person zusammen mit Ihrer Begründung mitgeteilt.

Sie können diese Option **deaktivieren**, um anonym zu bleiben. In diesem Fall wird die Begründung ohne Ihren Namen übermittelt („eine*r der Gegenstimmen hat vorgebracht: …").

Politisch entspricht die **Transparenz als Standard** der aktivistischen Kultur der Übernahme eigener Positionen. Anonymität bleibt jedoch möglich für Fälle, in denen eine Opposition die Opponentin oder den Opponenten einem unverhältnismäßig hohen persönlichen Risiko aussetzen würde.

### Automatische Erinnerungen

Der Cron sendet Erinnerungen an Administrator*innen, die noch nicht abgestimmt haben:
- **Tag +14**: „Du hast noch nicht über die Kooptation von X abgestimmt."
- **Tag +25**: „Dieser Vorschlag läuft in 5 Tagen ab, bitte beziehe Stellung."

### Schritt 3 — Abschluss

**Wenn jemand `opposed` stimmt**: Der Vorschlag wechselt sofort zu `status='rejected'`. Die vorgeschlagene Person und die vorschlagende Person erhalten eine E-Mail, die die Ablehnung erklärt, mit der Begründung (und der Identität der opponierenden Person, sofern diese der Offenlegung zugestimmt hat).

**Wenn alle aktiven Administrator*innen `favorable` gestimmt haben**: Der Vorschlag wechselt zu `status='completed'`. Eine Zeile wird automatisch in `network_administrators` eingetragen mit `status='active'` und `coopted_by_unanimity_of = ARRAY[<Liste der Abstimmenden>]`. Die Person erhält eine Willkommens-E-Mail und eine Zusammenfassung wird an alle Administrator*innen geschickt.

**Wenn 30 Tage vergehen, ohne dass ein Konsens erreicht wird**: Der Vorschlag wechselt zu `status='expired'`. Keine Kooptation. Es muss entweder ein neuer Vorschlag gemacht werden, oder das Netzwerk akzeptiert, dass es derzeit nicht bereit ist, diese Person aufzunehmen.

## 8.4. Der kollektive Entzug durch Einstimmigkeit

Der **kollektive Entzug** ist das Spiegelbild der Kooptation: Um eine*r Netzwerk-Administrator*in gegen ihren/seinen Willen zu entziehen, bedarf es der Einstimmigkeit der anderen aktiven Administrator*innen.

### Workflow

1. **Entzugsvorschlag** durch eine*r aktive*r Netzwerk-Administrator*in, obligatorische Begründung ≥ 20 Zeichen.
2. **Abstimmungen** der anderen Administrator*innen (favorable / opposed / abstain), mit Begründungen bei `opposed`.
3. **Bei Einstimmigkeit `favorable`**: Die Mitgliedschaft der Zielperson wechselt zu `pending_removal`, mit `pending_collective_removal_until = now() + 7 Tage`.
4. **Während der 7-tägigen Karenzzeit**: Die Zielperson behält ihre operativen Rechte, erhält aber eine klare E-Mail über ihre geplante Entlassung. Sie kann ggf. eine letzte Diskussion initiieren. **Sie kann den Entzug nicht einseitig annullieren**: Nur die Einstimmigkeit der anderen Administrator*innen kann zurückrudern (indem sie eine „Annullierung des Entzugs" vorschlagen — Spiegelworkflow).
5. **An Tag +7**: Wechsel zu `status='removed'`, `removed_at=now()`.

### Politisch

Der **doppelte Riegel** (Einstimmigkeit + 7-tägige Karenz) macht den kollektiven Entzug einer Netzwerk-Administrator*in besonders schwierig. Das ist gewollt. Da die Macht einer Netzwerk-Administrator*in übergreifend ist, wird sie nicht leichtfertig widerrufen.

Umgekehrt **bleibt der Selbstrückzug stets möglich und einfach** (vgl. §8.5). Das ist die politische Asymmetrie: Es ist einfach zu gehen, es ist schwer, hinausgeworfen zu werden. Das entspricht der anarchistischen Kultur: Man respektiert die persönliche Entscheidung, eine Funktion zu verlassen; man umrahmt stark die kollektive Entscheidung, sie zu entziehen.

## 8.5. Selbstrückzug

Eine*r Netzwerk-Administrator*in kann ihre*seine Funktion jederzeit ohne Zustimmung der anderen niederlegen. Es ist ein **einseitiger und bedingungsloser** Akt (P3 auf Netzwerkebene angewendet).

### Vorgehensweise

Über `/rede/administradores`, in der eigenen Zeile, auf **„Meine Funktion als Netzwerk-Administrator*in niederlegen"** klicken. Bestätigungsmodal, optionale Begründung.

### Wirkung

- Die Zeile wechselt zu `status='inactive'` (oder `removed` je nach Kontext, zu klären in Paket D).
- E-Mail an alle anderen aktiven Administrator*innen.
- Audit-Log `event_type='self_removal_requested'`.

### Sonderfall: die einzige aktive Administrator*in

Wenn Sie die einzige aktive Administrator*in sind und gehen möchten, löst das SIGB eine **spezielle Karenzzeit von 30 Tagen** aus. Während dieser Zeit:
- Bleiben Sie aktive*r Administrator*in mit allen Ihren Rechten.
- Eine dringende E-Mail wird an alle ehemaligen Administrator*innen (`status='inactive'` oder `removed`) geschickt und informiert sie über die Lage.
- Das Netzwerk hat 30 Tage Zeit, entweder eine*n neue*n Administrator*in zu kooptieren (normaler Kooptations-Workflow, wobei Sie die einzige stimmberechtigte Person sind) oder einen anderen Übergang zu organisieren.

An Tag +30, wenn nichts geschehen ist, treten Sie effektiv aus und das Netzwerk findet sich **ohne aktive*n Administrator*in** wieder. Das SIGB funktioniert technisch weiterhin, aber keine administrativen Aktionen (Bibliotheksaktivierung, Kooptation usw.) sind mehr möglich bis zu einem manuellen Eingriff.

Diese Vorgehensweise ist darauf ausgelegt, die Auflösung des Netzwerks zu **verlangsamen**, falls eine letzte Administrator*in gehen würde, ohne diesen Abgang jedoch zu **verhindern**. Die Freiheit zu gehen bleibt vollständig.

## 8.6. Das übergreifende Recht im Alltag

Das **übergreifende Recht** ist das, was die Netzwerk-Administrator*in politisch vom lokalen Staff unterscheidet: Sie kann wie `coord+` in jeder beliebigen Bibliothek handeln, deren Katalog einsehen (auch wenn die Sichtbarkeit auf `private` gestellt ist), deren Mitgliedschaften ändern usw.

### Wann es anwenden

- **Aktivierung einer neuen Bibliothek**: normaler Workflow, das ist der erste Verwendungszweck des übergreifenden Rechts.
- **Wartung**: Eine Bibliothek hat eine fehlerhafte Konfiguration, einen schlecht eingestellten Parameter, einen blockierenden Bug. Sie können eingreifen, um das zu korrigieren.
- **Politische Blockade**: Die Bibliothek hat keine*n Koordinator*in mehr (vgl. §7.5), eine Neuwahl der Kooptation ist nötig, um wieder anzufangen.
- **Vermittlung auf Anfrage**: Die lokale Koordination wendet sich ausdrücklich an Sie, um bei der Schlichtung eines Konflikts oder einer schwierigen Entscheidung zu helfen.
- **Untersuchung nach einer Netzwerkmeldung**: Eine*r Leser*in meldet ein schwerwiegendes Problem in einer Bibliothek, und die lokale Koordination antwortet nicht oder ist selbst Teil des Problems.

### Wann nicht anwenden

- **Aus Neugier**: Nicht „nachschauen, was passiert" in einer Bibliothek ohne operativen Grund. Das ist Überwachung, keine Verwaltung.
- **Um eine politische Entscheidung aufzuzwingen**: Wenn Sie mit der Politik einer Bibliothek nicht einverstanden sind (Validierungsform, Regelung usw.), können Sie darüber diskutieren, aber nicht erzwingen.
- **Um eine kollektive Debatte zu umgehen**: Wenn das Netzwerk eine Weiterentwicklung diskutiert und Sie nicht einverstanden sind, können Sie Ihr übergreifendes Recht nicht nutzen, um Ihre Sichtweise durch vollendete Tatsachen durchzusetzen.

### Obligatorische Vorabinformation

Das ist die Doktrin des Netzwerks (Kapitel 2, §2.4; Kapitel 7, §7.6): **Jeder Eingriff einer Netzwerk-Administrator*in in eine lokale Bibliothek muss von einer Information an die lokale Koordination begleitet werden** — außer bei vitalen Notfällen.

Konkret:
- **E-Mail an die lokale Koordination**, in der erklärt wird, was getan werden wird und warum.
- **Warten auf eine Antwort**, außer bei Dringlichkeit: 24 bis 72 Stunden je nach Art der Aktion.
- **Wenn keine Antwort und nicht dringende Aktion**: Einmal nachfragen, dann handeln und im Log explizit festhalten, dass die lokale Koordination informiert wurde, aber nicht geantwortet hat.
- **Bei vitalem Notfall**: Handeln und die Information unmittelbar danach senden, mit Erläuterung, warum der Notfall das Handeln ohne Wartezeit gerechtfertigt hat.

Jede Aktion wird in `cross_library_actions_log` mit Kritikalitätsstufe protokolliert, nachträglich lesbar für die lokale Koordination.

## 8.7. Der Fall der ersten Administrator*in und von Xavier

Das System setzt mindestens eine*n aktive*n Netzwerk-Administrator*in voraus, damit Kooptationen möglich sind. Da die **erste Administrator*in** nicht kooptiert werden kann (niemand ist da, um abzustimmen), ist eine Ausnahme vorgesehen.

Am 11. Mai 2026 ist **Xavier** durch direktes INSERT in `network_administrators` als **gründende*r Netzwerk-Administrator*in** eingetragen, mit `coopted_by_unanimity_of = ARRAY[]::uuid[]` (leeres Array) und `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. Diese Manipulation ist im Audit-Log nachgewiesen mit `event_type='foundational_admin_added'` und `metadata.foundational=true`.

Diese Manipulation ist **politisch transparent**: Sie ist dokumentiert, erklärt und öffentlich. Sie ist keine Schwäche des Systems — sie ist die unverzichtbare Initialisierung. Sobald dieses Fundament gelegt ist, läuft jede spätere Kooptation über den normalen Workflow aus §8.3.

Mit der Zeit, da neue Administrator*innen kooptiert werden, wird die anfängliche „Einsamkeit" verblassen. Das Netzwerk ist darauf ausgelegt, **mehrere aktive Administrator*innen** zu haben (das politische Ziel ist in der Regel ein Kreis von 3 bis 5 Personen, in ungerader Zahl, um Blockaden bei Abstimmungen zu bestimmten verwandten Themen außerhalb der Spec zu vermeiden).

## 8.8. Wenn die Regel Sie stört

**Sie finden die Einstimmigkeit zu anspruchsvoll** („wir kommen nie zu einer Kooptation, ein Veto blockiert alles"). Das ist eine grundlegende Debatte über die Natur des Kollektivs der Netzwerk-Administrator*innen. Soll man hin zu einer qualifizierten Mehrheit gehen? Braucht es einen Überabstimmungsmechanismus? Als Netzwerkdiskussion einbringen und ggf. in einer Überarbeitung der Spec formalisieren.

**Sie finden die Einstimmigkeit zu lax** („man sollte auch die lokalen Koordinationen befragen, bevor man eine*n Admin kooptiert"). Das ist eine andere politische Option: die lokalen Koordinationen vor der Kooptation einer Netzwerk-Administrator*in konsultieren. Zu diskutieren. Das würde den entscheidungsberechtigten Kreis erweitern, aber das Verfahren erschweren.

**Sie finden die 7-tägige Karenz für den kollektiven Entzug zu lang oder zu kurz.** In der Spec einbringen.

**Sie finden, dass die Doktrin der Vorabinformation unzureichend gerahmt ist**: Was ist genau ein „vitaler Notfall"? Sollte es eine kanonische Definition geben? Zu diskutieren.

**Sie finden, dass die Funktion der Netzwerk-Administrator*in zu viel Macht hat** (übergreifendes Recht zu weitreichend) oder zu wenig (sollte bestimmte Konflikte schlichten können). Das ist eine grundlegende politische Frage. Bei einem Jahrestreffen zu diskutieren.

Siehe Kapitel 4 und Anhang C.

\newpage

# 9. Transparenz in der Praxis

Dieses Kapitel behandelt das konkrete Funktionieren der **Transparenz** in AnarBib: Wer sieht was, wie und warum. Es ist die Anwendung des Prinzips P5 (maximale Transparenz) und von P6 (systematische Benachrichtigungen).

## 9.1. Das Prinzip

> **P5 — Maximale Transparenz.** Das Audit-Log der Rollenänderungen ist für das gesamte aktive Staff der Bibliothek lesbar.
> **P6 — Systematische Benachrichtigungen.** Jede Rollenänderung löst eine E-Mail an die betroffene Person und an die gesamte Koordination aus.

Die politische Idee: **Undurchsichtige Manipulationen unmöglich machen**. Wenn alles protokolliert und lesbar ist, kann man nicht schweigend eine Person von einem Status in einen anderen überführen, ohne dass das von den anderen Staffmitgliedern gesehen wird.

## 9.2. Wer sieht was: Matrix

### Auf Bibliotheksebene

| Information | reader | librarian | coordenador | Netzwerk-Admin |
|---|---|---|---|---|
| Teamliste (aktive Rollen) | teilweise (nur die öffentlichen Namen) | vollständig | vollständig | vollständig |
| Status (`suspended`, `pending_removal`) | nein | ja | ja | ja |
| Vollständiges Audit-Log des Teams | nein | ja | ja | ja |
| Audit-Log: Begründungen der Aktionen | nein | ja | ja | ja |
| Laufender Entzugsantrag: wer hat ihn gestellt | nein | ja | ja | ja |
| Persönliche Daten anderer Leser*innen | nein | ja (dieser Bibliothek) | ja | ja |

### Auf Netzwerkebene

| Information | reader | Bibliotheksstaff | Netzwerk-Admin |
|---|---|---|---|
| Liste der aktiven Netzwerk-Administrator*innen | ja (öffentliche Seite `/rede`) | ja | ja |
| Netzwerkzähler (Anzahl der Bibliotheken usw.) | ja | ja | ja |
| Netzwerk-Audit-Log (Kooptationen, Entzüge von Administrator*innen) | nein | nein | ja |
| Laufende Kooptationsvorschläge | nein | nein | ja |
| Bibliotheksübergreifende Logs (Aktionen von Netzwerk-Admin in Bibliothek X) | nein | ja (ihrer Bibliothek) | ja |

## 9.3. Das Team-Audit-Log in der Praxis

Es ist das wichtigste Transparenzwerkzeug. Einsehbar über `/biblioteca` → Tab **Team** → Abschnitt **Teamhistorie**.

### Was man darin sieht

Jeder Eintrag zeigt:
- Datum und Uhrzeit.
- Aktion („befördert zu librarian", „selbst zurückgestuft", „Entzug beantragt", „suspendiert", „nach Suspension wiedereingegliedert", „automatischer Übergang zu inaktiv nach 9 Monaten" usw.).
- Betroffene Person (target).
- Urheber*in der Aktion (actor) — für menschliche Aktionen. Leer für automatische Aktionen (Cron).
- Begründung (sofern angegeben).
- Rolle und Status davor/danach.

### Wozu das politisch dient

- **Kollektives Gedächtnis**: Man kann die Geschichte der Koordination rekonstruieren, sehen, wie sie sich gebildet und entwickelt hat.
- **Schutz gegen Intransparenz**: Wenn eine*r Koordinator*in zweifelhafte Aktionen durchgeführt hat (merkwürdige Kooptationen, ungerechtfertigte Suspensionen), ist das für alle sichtbar.
- **Beratungswerkzeug**: Bei Debatten („hatten wir nicht gesagt, dass wir die Koordination rotieren lassen?") liefert das Log faktische Elemente.
- **Übergangswerkzeug**: Wenn eine neue Koordinator*in antritt, kann sie das Log lesen, um die jüngere Geschichte zu verstehen, ohne alle befragen zu müssen.

### Was man damit tun sollte

- **Es regelmäßig lesen.** Nicht täglich, aber einmal im Monat, etwa bei einem Koordinationstreffen.
- **Merkwürdiges ansprechen.** Wenn Ihnen eine Aktion unverständlich oder ungerechtfertigt erscheint, fragen Sie bei der Urheberin oder dem Urheber nach.
- **Es nicht als Waffe benutzen.** Das Log ist ein Werkzeug kollektiver Transparenz, kein Instrument interpersoneller Überwachung.

## 9.4. Die Benachrichtigungs-E-Mails

Jede Governance-Aktion löst **eine oder mehrere** automatische E-Mails aus. Das ist kein Spam: Es ist gewollt, denn niemand soll von einer Rollenänderung betroffen sein, ohne darüber informiert zu werden.

### Wer was erhält

| Ereignis | Betroffene Person | Aktive lokale Koordinator*innen | Netzwerk-Administrator*innen |
|---|---|---|---|
| Kooptation (T1, T2) | ✅ | ✅ | — |
| Selbstrückstufung (T3, T4) | ✅ Bestätigung | ✅ | — |
| Entzugsantrag (T5) | ✅ | ✅ | — |
| Annullierung des Antrags (T8) | ✅ | ✅ | — |
| Ende der Karenz (Tag +7) | ✅ | ✅ | — |
| Suspension (T6) | ✅ dringend | ✅ | — |
| Aufhebung der Suspension (T7) | ✅ | ✅ | — |
| Automatisches Ausscheiden nach 9 Monaten (T9) | ✅ Erinnerungen + final | ✅ (nur final) | — |
| Letzte*r Koordinator*in geht | ✅ | ✅ (die betreffende Person) | ✅ Alarm |
| Kooptation Netzwerk-Admin (Vorschlag) | — | — | ✅ |
| Kooptation Netzwerk-Admin (Erfolg) | ✅ Willkommen | — | ✅ Zusammenfassung |
| Kooptation Netzwerk-Admin (Ablehnung) | ✅ mit Begründung | — | ✅ |
| Kollektiver Entzug Netzwerk-Admin | ✅ | — | ✅ |
| Bibliotheksübergreifender Eingriff | — | ✅ (Koordinator*innen der Bibliothek) | ✅ (die*der Urheber*in) |

### Der Ton der E-Mails

Die Governance-E-Mails folgen den aktivistischen Konventionen des Netzwerks (vgl. internes Gedächtnis): Schlichtheit, Klarheit, Zugänglichkeit (gemeinsame Sprache ohne Fachjargon), inklusive Formulierung und entbürokratisiertes Schreiben. Keine offiziellen Formeln, keine bürokratischen Unterschriften.

Beispiel für einen Entzugsantrag:
> Hallo Karl,
>
> Die Koordination der BLMF hat deinen Entzug aus dem Team beantragt (Rolle: librarian), mit folgender Begründung: „Beschluss der VV vom 04/05".
>
> Diese Kündigungsfrist tritt am **12. Mai 2026** (in 7 Tagen) in Kraft, sofern sie nicht vorher von einer anderen Koordinator*in annulliert wird.
>
> Während dieser Zeit hast du keinen Zugriff mehr auf die librarian-Funktionen. Für jede Diskussion wende dich an die Koordination der BLMF — diese Entscheidung betrifft das organische Leben des lokalen Kollektivs und wird nicht über das SIGB geregelt.
>
> AnarBib

Der Ton zielt darauf ab, sachlich zu informieren, ohne zu dramatisieren oder zu verharmlosen.

### Vertraulichkeit der E-Mails — Schutz vor Tracking

Governance-E-Mails werden wie alle Benachrichtigungen des SIGB über **Resend** versendet, den E-Mail-Dienstleister des Netzwerks (vgl. Verzeichnis der Verarbeitungstätigkeiten und DPA). Zwei politische Garantien rahmen diesen Versand:

- **Kein Tracking.** Die Verfolgung von Öffnungen und Klicks — die die IP-Adresse, den Standort, das Gerät und den Mail-Client der empfangenden Person erfassen würde — ist eine Option, die auf der AnarBib-Instanz **deaktiviert** ist. Eine Governance-E-Mail zu erhalten hinterlässt keine technische Spur auf Netzwerkseite.
- **Datensparsamkeit.** Nur die für den Versand streng notwendigen Daten werden übertragen (E-Mail-Adresse, Vorname für die Personalisierung, Inhalt der Benachrichtigung). Keine sensiblen Daten werden weitergegeben.

Dieser Schutz ist doktrinär: Er verlängert das Nicht-Tracking-Engagement des Netzwerks bis in die E-Mail-Schicht. Er ist im Verzeichnis der Verarbeitungstätigkeiten (Art. 30 DSGVO) und im DPA dokumentiert; jeder Wechsel des E-Mail-Dienstleisters wird den Mitgliedsbibliotheken gemeldet (DPA Art. 5.4).

## 9.5. Der Fall der „bibliotheksübergreifenden" Benachrichtigungen

Wenn eine Netzwerk-Administrator*in in eine Bibliothek eingreift (vgl. §8.6), werden zwei Benachrichtigungen erzeugt:

- **Vorab-Benachrichtigung** (manuell): Die*Der Administrator*in sendet vor der Aktion eine E-Mail an die lokale Koordination. Freies Format.
- **Automatische Benachrichtigung** (durch das SIGB): Bei der Ausführung der Aktion schreibt das System in `cross_library_actions_log` mit Kritikalitätsstufe und sendet eine E-Mail an die aktiven Koordinator*innen der betroffenen Bibliothek.

Diese doppelte Benachrichtigung (manuell + automatisch) stellt sicher, dass die lokale Koordination **vorher** politisch und **nachher** technisch informiert wird. Die technische Spur ist nachträglich lesbar im Tab **Team** → Abschnitt **Netzwerkeingriffe** (ab Paket D verfügbar).

## 9.6. Grenzen der Transparenz

Die Transparenz von AnarBib hat Grenzen, die expliziert werden müssen:

**Die `reader` sehen das Team-Audit-Log nicht.** Das ist gewollt (P5 spricht von „aktivem Staff"). Die `reader` sehen nicht, wer wen kooptiert hat, wer suspendiert wurde usw. Die Transparenz spielt **innerhalb der Koordination**, nicht gegenüber den Nutzenden.

**Eine Bibliothek sieht nicht das Audit-Log einer anderen Bibliothek.** Lokale Souveränität (P7). Rollenänderungen in Bibliothek A sind für Bibliothek B strikt undurchsichtig, außer über den menschlichen Kanal (Diskussion zwischen den Koordinator*innen beider Bibliotheken).

**Das Netzwerk-Audit-Log (Kooptationen und Entzüge von Administrator*innen) ist nicht öffentlich.** Nur von Netzwerk-Administrator*innen lesbar. Eine lokale Bibliothek kann die Liste der aktuellen Netzwerk-Administrator*innen einsehen (Seite `/rede`), aber nicht die Geschichte der Kooptationen noch die Begründungen der Gegenstimmen.

Diese Grenzen sind keine Heucheleien. Sie entsprechen einem Gleichgewicht zwischen **Transparenz** (innerhalb des beratenden Staffs) und **Vertraulichkeit** (gegenüber den Nutzenden und zwischen Bereichen). Wenn Sie das Gleichgewicht falsch gesetzt finden, ist es änderbar (Kapitel 4).

## 9.7. Wenn die Regel Sie stört

**Sie finden, dass die `reader` das Team-Audit-Log sehen sollten** (radikale Transparenz gegenüber den Nutzenden). Das ist eine vertretbare Position, hat aber Konsequenzen (interne Konflikte werden öffentlich, das politische Leben des Kollektivs liegt offen). Im Netzwerk diskutieren.

**Sie finden umgekehrt, dass das Audit-Log zu sichtbar ist** (eine diskrete*r librarian sollte nicht in der Lage sein, die Aktionen der Koordinator*innen zu „bespitzeln"). Das ist ebenfalls vertretbar. Aber es widerspricht P5. Zu diskutieren.

**Sie finden die E-Mails zu zahlreich oder nicht aussagekräftig genug.** Der Inhalt ist in `mail-strings.ts` × 10 Locales konfiguriert. Jede Änderung einer E-Mail ist änderbar wie eine Code-Änderung. Mit den Entwickler*innen einbringen.

**Sie finden, dass das Netzwerk-Audit-Log zumindest für die lokalen Koordinator*innen öffentlich sein sollte** (damit sie sehen können, wer auf Netzwerkebene was entscheidet). Das ist eine interessante Option. Zu diskutieren.

Siehe Kapitel 4 und Anhang C.

\newpage

# 10. Kommentierte Fallbeispiele

Zum Abschluss sechs vollständige Szenarien. Jedes illustriert eine Kombination von Mechanismen und zeigt das SIGB in Aktion. Die Namen (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) sind die unserer historischen Genoss*innen des libertären Denkens; sie dienen hier als fiktive Beispielfälle.

## 10.1. Voltairine wird als librarian kooptiert

> **Kontext.** Emma ist coordenadora an der BLMF. Voltairine kommt seit acht Monaten zu den Öffnungszeiten, beteiligt sich am Bibliotheksleben und hat eindeutig das Profil, um ins Team aufgenommen zu werden. Das lokale Kollektiv hat dies in der AG vom 4. Mai besprochen und ihre Kooptation beschlossen.

**Verfahren.**

1. Emma meldet sich am 5. Mai um 14:30 Uhr an. Navigiert zu `/biblioteca`, Reiter **Equipe**.
2. Sucht Voltairine in der Liste der `reader` der Bibliothek (sie hat seit Februar ein AnarBib-Konto).
3. Klickt auf **„Ins Team einladen"** → wählt **librarian**.
4. Feld „Begründung": „Beschluss der AG vom 04/05" (Doktrin 1, strenge Erwartung).
5. Bestätigt.

**Sofortige Wirkung.**

- Voltairine erhält eine E-Mail: „Hallo Voltairine, du wurdest von Emma G. als librarian der BLMF ernannt aufgrund von: „Beschluss der AG vom 04/05". Deine neuen Rechte sind aktiv. Willkommen im Team."
- Die anderen aktiven Koordinator*innen der BLMF (Lucy und Piotr) erhalten eine Informations-E-Mail.
- Audit-Log: `2026-05-05 14:30 — Emma G. hat Voltairine d.C. zur librarian befördert (Begründung: Beschluss der AG vom 04/05)`.

**Kommentar.**

Einfachster Fall. Das SIGB führt die Entscheidung des Kollektivs ordnungsgemäß aus. Emma hat politisch nichts entschieden — sie hat geklickt, um auszuführen, was außerhalb der Software entschieden wurde.

**Was das SIGB nicht getan hat:** überprüfen, ob die AG wirklich stattgefunden hat, ob die Entscheidung wirklich getroffen wurde, ob Voltairine wirklich einverstanden ist. Diese Dinge liegen **außerhalb der Software**. Wenn Emma über die AG gelogen hätte, hätte das SIGB nichts gesehen. Die politische Kultur der BLMF ist das, was diese Lüge verhindert (und das Log macht sie im Nachhinein nachvollziehbar).

## 10.2. Lucy gibt ab

> **Kontext.** Lucy ist coordenadora an der BLMF, kann aber dieses Semester die Aufgabe nicht mehr wahrnehmen (sie beginnt eine Doktorarbeit). Sie möchte „zurück zur librarian wechseln", um im Team zu bleiben, aber ihre Verantwortlichkeiten zu verringern.

**Verfahren.**

1. Lucy navigiert zu `/biblioteca`, Reiter **Equipe**.
2. Auf ihrer eigenen Zeile (Status `coordenador`), klickt sie auf **„Ich gebe ab"**.
3. Wahl: „zurück zur librarian wechseln".
4. Bestätigungsmodal erinnert daran, dass sie die Koordinationsrechte sofort verliert.
5. Lucy bestätigt. Optionale Begründung: „Beginn der Doktorarbeit, vorübergehende Entlastung".

**Sofortige Wirkung.**

- Ihre `coordenador`-Mitgliedschaft wechselt zu `inactive`.
- Ihre `librarian`-Mitgliedschaft (die parallel bestand) bleibt `active`.
- Lucy erhält eine Bestätigungs-E-Mail: „Du bist jetzt librarian der BLMF. Du behältst deine operativen Rechte."
- Die gesamte Koordination (Emma, Piotr) erhält eine E-Mail: „Lucy P. hat abgegeben, ist nicht mehr coordenadora. Sie bleibt librarian des Teams."
- Audit-Log: `2026-05-05 18:42 — Lucy P. hat sich selbst von coordenador zu librarian zurückgestuft (Begründung: Beginn der Doktorarbeit, vorübergehende Entlastung)`.

**Kommentar.**

Dies ist der beispielhafte Gebrauch des Rechts P3. Lucy musste niemanden um Erlaubnis bitten. Ihre Selbst-Rückstufung ist sofort wirksam. Sie leistet weiterhin ihren Beitrag zur Bibliothek, jedoch in einer Intensität, die ihrer aktuellen Verfügbarkeit angepasst ist.

**Politisch gesehen**: genau diese Art von Rotation möchte man fördern. Lucy geht nicht verloren, sie übernimmt einfach eine andere Rolle. In sechs Monaten oder einem Jahr, wenn sie die Koordination wieder aufnehmen möchte, kann das Kollektiv sie neu kooptieren (T2). Keine Entscheidung ist endgültig.

## 10.3. Karl muss gehen

> **Kontext.** Karl ist librarian an der BLMF. Sein Verhalten gegenüber einigen Leser*innen hat Probleme verursacht (Paternalismus, unangemessene Bemerkungen). Das Kollektiv hat dies in der AG vom 4. Mai besprochen und entschieden, dass er das Team verlassen muss.

**Verfahren.**

1. Piotr (Koordinator) — von der AG zur Ausführung der Entscheidung bestimmt — navigiert zu `/biblioteca`, Reiter **Equipe**.
2. Auf Karls Zeile klickt er auf **„Ausschluss beantragen"**.
3. Rotes Modal mit ausdrücklicher 7-Tage-Frist.
4. Pflichtbegründung: „Im Anschluss an die AG vom 04/05, unangemessenes Verhalten gegenüber mehreren Leser*innen über mehrere Monate gemeldet, kollektiver Ausschlussbeschluss."
5. Ausdrückliche Bestätigung: „Ich verstehe, dass dieser Antrag am 12. Mai 2026 wirksam wird, sofern er nicht von einer anderen Koordinator*in abgebrochen wird."

**Sofortige Wirkung.**

- Karls Mitgliedschaft wechselt zu `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl verliert sofort** den Zugang zu allen librarian-Funktionen (die Mitgliedschaft ist eingefroren).
- Karl erhält eine E-Mail:
  > „Hallo Karl, die Koordination der BLMF hat deinen Ausschluss aus dem Team beantragt (Rolle: librarian), aufgrund von: „Im Anschluss an die AG vom 04/05, unangemessenes Verhalten gegenüber mehreren Leser*innen über mehrere Monate gemeldet, kollektiver Ausschlussbeschluss." Diese Frist wird am 12. Mai 2026 (in 7 Tagen) wirksam, sofern sie nicht bis dahin von einer anderen Koordinator*in abgebrochen wird. Für jede Rücksprache wende dich an die Koordination der BLMF."
- Emma und Lucy (andere Koordinator*innen) erhalten die Informations-E-Mail.
- Audit-Log: `2026-05-05 — Piotr K. hat den Ausschluss von Karl M. beantragt (Rolle: librarian, Begründung: ...)`.

**Entwicklung.**

- 6. Mai um 9 Uhr: Lucy liest die E-Mail. Sie ist mit der Entscheidung einverstanden und greift nicht ein.
- 7. Mai: Emma hat einen Austausch mit Karl (der ihr schreibt, um sich zu erklären). Emma kommt zu dem Schluss, dass die Entscheidung gilt. Greift nicht ein.
- 8.-11. Mai: nichts.
- **12. Mai um 00:00 Uhr**: der Cron `cron_team_pending_removal_complete` wird ausgeführt. Karl wechselt zu `inactive`.
- Abschließende E-Mail an Karl und an die Koordination.
- Audit-Log: `2026-05-12 — automatischer Wechsel zu inaktiv (Begründung: pending_removal abgelaufen, Cron) — actor: NULL`.

**Kommentar.**

Dies ist der Fall des kollektiven Ausschlusses. Drei politisch zu beachtende Punkte:

- **Die Säumnis hat als mögliche Sicherung funktioniert**, ohne genutzt zu werden. Lucy und Emma hätten abbrechen können; sie haben es nicht getan. Die Tatsache, dass niemand abgebrochen hat, ist selbst eine **implizite Beratung**.
- **Karl blieb informiert** ohne Überraschungen. Kein stiller Ausschluss.
- **Das Audit-Log ist lesbar** für das gesamte Personal und ermöglicht es, zu dieser Entscheidung zurückzukehren, wenn sich später jemand fragt, warum Karl gegangen ist.

**Politisch heikel**: die im Feld „Begründung" eingetragene Begründung ist für das gesamte Personal lesbar. Sie sollte keine Details über die Betroffenen enthalten (DSGVO, Würde), aber klar genug sein, damit die Entscheidung politisch vertretbar ist. Die richtige Balance zu finden ist eine Fähigkeit der Koordination.

## 10.4. Kompromittiertes Konto: sofortige Sperrung

> **Kontext.** Am 5. Mai um 19:30 Uhr stellt Emma in den Aktivitätslogs fest, dass Friedrich (librarian) in 3 Minuten 47 Änderungen an Katalogeinträgen vorgenommen hat, darunter mehrere abstruse (als „verschwunden" markierte Bücher, die sich im Regal befinden, usw.). Das Muster ähnelt einem unbefugten Zugriff.

**Verfahren.**

1. Emma navigiert zu `/biblioteca`, Reiter **Equipe**.
2. Auf Friedrichs Zeile klickt sie auf **„Sperren"**.
3. Modal mit **Pflichtbegründung** (≥ 20 Zeichen).
4. Emma tippt: „Verdacht auf kompromittiertes Konto, anomale Aktivität (47 Katalogänderungen in 3 Min.), Überprüfung läuft."
5. Bestätigt.

**Sofortige Wirkung (19:32 Uhr).**

- Friedrich wechselt zu `status='suspended'`.
- **Kein Zugang** für Friedrich.
- Friedrich erhält eine dringende E-Mail: „Dein AnarBib-Konto wurde vorsorglich bei der BLMF gesperrt. Begründung: Verdacht auf Kompromittierung deines Kontos. Wir empfehlen dir dringend, **dein Passwort sofort zu ändern**. Sobald dein Konto gesichert ist, wende dich an die Koordination der BLMF, um die Sperrung aufheben zu lassen."
- Die Koordination (Lucy, Piotr) erhält eine E-Mail.
- Audit-Log: `2026-05-05 19:32 — Emma G. hat Friedrich E. gesperrt (Rolle: librarian, Begründung: ...)`.

**Entwicklung.**

- **19:35 Uhr**: Emma ruft Friedrich an (Kanal außerhalb des SIGB). Friedrich bestätigt, dass er diese Aktionen nicht durchgeführt hat. Er hatte seinen Computer in einem gemeinsam genutzten Raum offen gelassen.
- **19:40 Uhr**: Friedrich ändert sein Passwort über das Zurücksetzungsverfahren.
- **20:00 Uhr**: Emma überprüft die fragwürdigen Aktionen im Audit-Log der Bibliothek (das Katalog-Audit, nicht das Team-Audit). Identifiziert die 47 Änderungen. Macht sie manuell rückgängig oder beantragt bei einer Netzwerk-Administrator*in ein Rollback, falls nötig.
- **20:15 Uhr**: Emma kehrt zum Reiter „Equipe" zurück und hebt die Sperrung von Friedrich auf.
- Friedrich erhält eine Bestätigungs-E-Mail. Audit-Log: `2026-05-05 20:15 — Emma G. hat die Sperrung von Friedrich E. aufgehoben`.

**Kommentar.**

Typischer Fall, in dem die Sperrung als **Vorsichtsmaßnahme** und nicht als Ausschluss eingesetzt wird. Friedrich ist nicht schuldig — sein Konto wurde kompromittiert. Die Sperrung dauerte 43 Minuten, die Zeit, die zur Absicherung benötigt wurde.

**Politisch wichtig**: Friedrich wurde nicht „beschuldigt". Die E-Mail macht dies ausdrücklich deutlich („vorsorglich"). Als die Situation geklärt ist, wird die Sperrung aufgehoben, und die Episode wird im Log als Zwischenfall und nicht als Tadel vermerkt.

## 10.5. Errico ist die letzte Koordinator*in und möchte gehen

> **Kontext.** Die BLMF hat nur noch eine aktive Koordinator*in, Errico. Lucy hat abgegeben, Emma ist weggezogen und nicht mehr aktiv. Piotr hat sich zu Beginn des Jahres zurückgestuft. Errico muss gehen (Umzug ins Ausland, keine Zeit mehr).

**Verfahren.**

1. Errico navigiert zu `/biblioteca`, Reiter **Equipe**, klickt auf **„Ich gebe ab"**.
2. Ein **spezielles** Modal öffnet sich:
   > ⚠️ **ACHTUNG**: Du bist die einzige aktive Koordinator*in der BLMF. Die Bibliothek wird ohne Koordination sein. Die Netzwerk-Administrator*innen von AnarBib werden benachrichtigt. Die BLMF kann weiter funktionieren (die Bibliothekar*innen bleiben operativ), aber keine Konfigurationsänderung ist möglich, bis eine neue Koordinator*in kooptiert wurde. Fortfahren?
3. Errico bestätigt. Begründung: „Umzug ins Ausland, keine Verfügbarkeit mehr für die Koordination."

**Sofortige Wirkung.**

- Erricos coordenador-Mitgliedschaft wechselt zu `inactive`.
- E-Mail an Errico (Bestätigung).
- E-Mail an die gesamte Koordination der BLMF — da es keine mehr gibt, erhalten in der Praxis die verbleibenden aktiven `librarian` eine Benachrichtigung.
- **Dringende E-Mail an die Netzwerk-Administrator*innen**: „Die BLMF hat keine aktive Koordinator*in mehr. Hier sind die verbleibenden aktiven Bibliothekar*innen: Voltairine d.C., Friedrich E., ..."
- Audit-Log: `2026-05-05 — Errico M. hat sich selbst von coordenador zu reader zurückgestuft (Begründung: ..., Warnung: last_coordinator_leaving)`.

**Entwicklung außerhalb der Software.**

- 6. Mai: Xavier (Netzwerk-Administrator) nimmt Kontakt zu Voltairine und Friedrich auf, den verbleibenden aktiven `librarian`. Sie bestätigen, dass das BLMF-Kollektiv noch existiert und weiterarbeiten möchte.
- 7.-15. Mai: interne Diskussion des BLMF-Kollektivs, das in der AG beschließt, Voltairine zur coordenadora zu kooptieren.
- 16. Mai: Xavier (oder eine andere BLMF-Koordinator*in, die in diesem Fall nicht mehr existiert, also Xavier in seinem transversalen Recht) kooptiert Voltairine zur coordenadora. **Pflicht zur vorherigen Information**: Xavier hat Friedrich und Voltairine 2 Tage vorher geschrieben, um die Aktion anzukündigen. Einmal durchgeführt, wird die Aktion in `cross_library_actions_log` mit der Kritikalitätsstufe „hoch" eingetragen (Änderung der Koordination einer Bibliothek durch eine Netzwerk-Administrator*in).

**Kommentar.**

Politisch heikler Fall: die Bibliothek durchläuft eine Phase der Fragilität (zwischen dem 5. und dem 16. Mai hat sie keine Koordination). Aber das SIGB **hat Erricos Abgang nicht verhindert** — sein Recht P3 ist bedingungslos. Das SIGB hat nur **das Netzwerk alarmiert**, damit es helfen kann.

Xaviers Eingreifen illustriert den **ordnungsgemäßen** Gebrauch des transversalen Rechts: er wurde (implizit durch den automatischen Alarm) eingeladen zu handeln, er hat die vorherige Information respektiert, er hat seine Aktion dokumentiert. Er hat Voltairine nicht aufgezwungen; das BLMF-Kollektiv hat sie gewählt. Xavier hat nur **technisch ausgeführt**, was entschieden wurde.

## 10.6. Eine Netzwerk-Admin-Kooptation, die scheitert

> **Kontext.** Xavier ist gründende Netzwerk-Administrator*in. Im Laufe der Zeit wurden Maria, Patricia und Diego als Netzwerk-Administrator*innen kooptiert, während sich das Netzwerk erweiterte. Am 20. Mai 2026 besteht das Adminkollektiv aus: Xavier, Maria, Patricia, Diego (vier aktive Administrator*innen).
>
> Maria schlägt die Kooptation von Mohammed vor, den sie aus einer italienischen Bibliothek kennt, die dem Netzwerk beitritt.

**Verfahren.**

1. Maria klickt von `/rede/administradores` aus auf **„Eine Kooptation vorschlagen"**.
2. Gibt Mohammeds Identität ein (AnarBib-Konto vor zwei Wochen erstellt).
3. Begründung: „Mohammed koordiniert die BLA (Bologna), eine Bibliothek, die diesen Monat dem Netzwerk beitritt. Er hat die politische Integration der BLA in AnarBib getragen und ist sehr stark in der italienischen Koordination engagiert. Seine Kooptation als Netzwerk-Administrator wird die geografische Vielfalt des Kollektivs stärken und die Animation auf der Seite Italiens erleichtern."
4. Bestätigt.

**Sofortige Wirkung.**

- Vorschlag erstellt, `status='open'`, `expires_at = 19. Juni 2026`.
- Automatische `favorable`-Abstimmung von Maria eingetragen.
- E-Mails an Xavier, Patricia, Diego mit dem Vorschlag.

**Entwicklung.**

- 22. Mai: **Diego** stimmt `favorable`. Keine Begründung (für favorable optional).
- 25. Mai: **Patricia** stimmt `opposed`. Begründung: „Mohammed hat keine Amtszeit im Netzwerk. Seine Kooptation geht schneller als die der BLA, die noch keine Gelegenheit hatte, lange genug als AnarBib-Bibliothek zu funktionieren. Ich schlage vor, 6 Monate zu warten, damit die BLA sich eingespielt hat, und Mohammed dann erneut vorzuschlagen." Patricia hakt „Meine Identität offenlegen" an.

**Sofortige Wirkung der opposed-Stimme.**

- Vorschlag wechselt zu `status='rejected'`.
- E-Mail an Mohammed: „Hallo Mohammed, dein Kooptationsvorschlag als Netzwerk-Administrator*in von AnarBib ist nicht zustande gekommen. Patricia X. hat folgenden Einwand erhoben: „[vollständige Begründung]". Du kannst dich mit ihr oder mit Maria austauschen, die dich vorgeschlagen hatte. Die Kooptation kann zu einem späteren Zeitpunkt erneut vorgeschlagen werden."
- E-Mail an Maria (Vorschlagende): Zusammenfassung mit Patricias Begründung.
- E-Mail an Xavier und Diego: Information, dass der Vorschlag abgelehnt wurde, mit der Begründung.
- Netzwerk-Audit-Log: `2026-05-25 — Kooptation abgelehnt: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Kommentar.**

Illustrativer Fall des Einstimmigkeitsprinzips **in Aktion**. Patricia hat ein Veto, sie nutzt es, ihre Begründung ist explizit und konstruktiv („warten wir 6 Monate"). Sie hat gewählt, ihre Identität offenzulegen, was Mohammed und Maria ermöglicht, direkt mit ihr zu sprechen, anstatt über die anonyme opponierende Person zu spekulieren.

**Politisch gesehen**: die Kooptation durch Einstimmigkeit ist keine Garantie für eine dauerhafte Blockade. Patricia sagt nicht „niemals", sondern „nicht jetzt". Wenn die BLA in 6 Monaten gut integriert ist und Patricia ihre Meinung ändert, kann ein neuer Vorschlag erfolgreich sein. Es ist diese **Umkehrbarkeit in der Zeit**, die die Einstimmigkeit erträglich macht.

Die Alternative — Mohammed mit Mehrheit gegen Patricias Meinung zu kooptieren — hätte einen Adminkreis geschaffen, in dem Patricia sich deplatziert gefühlt hätte. Besser abwarten.

\newpage

# Anhänge

\newpage

# Anhang A — Glossar

**AG** — Vollversammlung. Kollektive Entscheidungssitzung einer Bibliothek. Das SIGB modelliert die AG nicht (P8). Ihre Modalität (Beschlussfähigkeit, Häufigkeit, Beratungsmodus) wird von jeder Bibliothek vollständig selbst bestimmt.

**Audit-Log** — Journal der Governance-Aktionen, gespeichert in `library_membership_audit` (auf Bibliotheksebene) und `network_administrator_audit` (auf Netzwerkebene). Lesbar durch aktives Personal (auf Bibliotheksebene) und durch Netzwerk-Administrator*innen (auf Netzwerkebene).

**Selbst-Rückstufung** — Aktion, durch die eine Personalmitglied sich selbst auf eine niedrigere Rolle zurückstuft. Recht P3, bedingungslos.

**Bibliothek `private`** — Bibliothek, deren Katalog nur für ihre eingetragenen Mitglieder sichtbar ist. Modus geeignet für politisch exponierte Bibliotheken.

**Bibliothek `network`** — Bibliothek, deren Katalog für alle validierten `reader` des AnarBib-Netzwerks sichtbar ist. Standardmodus für die meisten Bibliotheken.

**Bibliothek `public`** — Bibliothek, deren Katalog für alle sichtbar ist, einschließlich anonymer Besucher*innen.

**Säumnis** — Frist zwischen einer Entscheidung und ihrer Wirkung. Sieben Tage für kollektive Ausschlüsse von lokalem Personal und von Netzwerk-Administrator*innen. Dreißig Tage für den Selbst-Rückzug der einzigen aktiven Netzwerk-Administrator*in.

**Kooptation** — Aufnahmemechanismus in ein Team (lokales Personal) oder in das Netzwerk-Adminkollektiv. Für lokales Personal: Entscheidung einer Koordinator*in+. Für das Netzwerk: Einstimmigkeit der aktiven Administrator*innen.

**Cross-biblios** — Bezeichnet eine Aktion, die von einer Netzwerk-Administrator*in an einer Bibliothek durchgeführt wird, in der sie kein lokales Personalmitglied ist. Eingetragen in `cross_library_actions_log`.

**Cron** — Automatische Aufgabe, die vom SIGB regelmäßig ausgeführt wird. Ohne menschliche Handelnde. Beispiele: `cron_team_pending_removal_complete` (Wechsel von `pending_removal` zu `inactive` an J+7), `cron_team_inactive_cleanup` (automatischer Austritt nach 9 Monaten).

**Delegation** — Akt, durch den ein Kollektiv vorübergehend eine Funktion an eines seiner Mitglieder überträgt und die Möglichkeit behält, sie zurückzunehmen. Zentrales Konzept, unterschieden von „Hierarchie".

**Mitgliedschaft** — Zeile der Tabelle `user_library_memberships`, die die Zugehörigkeit einer Person zu einer Bibliothek in einer bestimmten Rolle ausdrückt. Eine Person kann mehrere Mitgliedschaften in einer Bibliothek haben (Multi-Mitgliedschaft).

**Multi-Mitgliedschaft** — Möglichkeit, mehrere Mitgliedschaftszeilen für dieselbe Person in derselben Bibliothek mit unterschiedlichen Rollen zu haben.

**Netzwerk** — Das Kollektiv der Bibliotheken, die sich gegenseitig anerkennen und die AnarBib-Plattform teilen. Keine zentrale Organisation, sondern eine Föderation.

**RPC** — *Remote Procedure Call*. SQL-Funktion, die von der Benutzer*innenoberfläche aufgerufen wird, um eine Aktion auszuführen. Alle Governance-Aktionen laufen über RPCs namens `fn_team_*` (lokales Personal) oder `fn_network_admin_*` (Netzwerk).

**Lokale Souveränität** — Grundsatz P7, wonach jede Bibliothek souverän über ihre internen Delegationen ist. Rollenänderungen in einer Bibliothek wirken sich auf keine andere aus.

**Spec** — Spezifikationsdokument (`spec-*.md`), das detailliert beschreibt, wie eine SIGB-Funktion funktioniert. Technische und politische Quelle der Wahrheit. Versioniert, datiert, änderbar.

**Einstimmigkeit** — Modalität der Kooptation und des kollektiven Rückzugs der Netzwerk-Administrator*innen. Alle Stimmen müssen `favorable` sein; ein einziges `opposed` oder eine nicht aufgehobene Enthaltung blockiert.

**Physische Validierung** — Verfahren, durch das eine Bibliothekar*in+ ein `reader`-Konto nach einer persönlichen Begegnung validiert. Gilt für das gesamte Netzwerk (gegenseitiger Anerkennungspakt).

**Veto** — `opposed`-Stimme bei einer Kooptation oder einem kollektiven Rückzug einer Netzwerk-Administrator*in. Sofortige Wirkung: Ablehnung des Vorschlags. Pflichtbegründung von mindestens 20 Zeichen.

\newpage

# Anhang B — Index der technischen Funktionen

Dieser Anhang gibt für jede im Leitfaden erwähnte RPC ihre politische Übersetzung und den betreffenden Übergang an. Er dient als schnelle Referenz.

## Funktionen für lokales Personal

| SQL-RPC | Übergang | Politische Übersetzung |
|---|---|---|
| `fn_team_promote_to_librarian` | T1 | Kooptation `reader` → `librarian` |
| `fn_team_promote_to_coordenador` | T2 | Kooptation `librarian` → `coordenador` |
| `fn_team_self_demote` | T3, T4 | Selbst-Rückstufung („ich gebe ab") |
| `fn_team_request_remove_member` | T5 | Ausschlussantrag mit 7-Tage-Frist |
| `fn_team_cancel_remove_member` | T8 | Abbruch eines Ausschlussantrags |
| `fn_team_suspend_member` | T6 | Sofortige Sperrung (Vorsichtsmaßnahme) |
| `fn_team_unsuspend_member` | T7 | Aufhebung einer Sperrung |
| `fn_validate_physical_account` | — | Physische Validierung einer `reader`-Person |
| `cron_team_pending_removal_complete` | T5 (Fortsetzung) | Cron: Wechsel zu `inactive` an J+7 |
| `cron_team_inactive_cleanup` | T9 | Cron: automatischer Austritt nach 9 Monaten |

## Funktionen für Netzwerk-Administrator*innen

| SQL-RPC | Schritt | Politische Übersetzung |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Kooptation: Vorschlag | Eine Administrator*in schlägt eine neue vor |
| `fn_network_admin_vote_cooptation` | Kooptation: Abstimmung | Stimme favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Selbst-Rückzug | Aus dem Amt der Netzwerk-Administrator*in ausscheiden |
| `fn_network_admin_request_removal` | Kollektiver Rückzug | Spiegelworkflow der Kooptation |

## Autorisierungs-Helpers (genutzt von den RLS)

| SQL-Helper | Politische Bedeutung |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | Kann diese Person als Personal dieser Bibliothek agieren? (aktives lokales Personal ODER Netzwerk-Administrator*in) |
| `user_can_engage_library(library_id)` | Kann diese Person die Bibliothek politisch einbinden? (aktive lokale Koordinator*in ODER Netzwerk-Administrator*in) |
| `fn_caller_is_network_admin()` | Ist die aufrufende Person eine aktive Netzwerk-Administrator*in? |
| `fn_library_visible_to_caller(library_id)` | Ist der Katalog dieser Bibliothek für die aufrufende Person sichtbar? |

## Haupttabellen

| Tabelle | Politische Bedeutung |
|---|---|
| `user_library_memberships` | Die lokalen Delegationen (wer ist Personal welcher Bibliothek) |
| `network_administrators` | Die Administrator*innen des Netzwerks |
| `library_membership_audit` | Journal der lokalen Governance-Aktionen |
| `network_administrator_audit` | Journal der Netzwerk-Governance-Aktionen |
| `network_administrator_cooptation_proposals` | Laufende Kooptationsvorschläge |
| `network_administrator_cooptation_votes` | Individuelle Stimmen der Administrator*innen |
| `cross_library_actions_log` | Spur der Aktionen von Netzwerk-Administrator*innen an Bibliotheken |

\newpage

# Anhang C — Muster einer Änderungsnotiz

Wenn Sie eine Änderung an einer SIGB-Regel oder an diesem Leitfaden vorschlagen möchten, finden Sie hier ein Muster, um Ihren Vorschlag zu strukturieren. Freies Format, Sie können es anpassen.

---

## Änderungsvorschlag zu [Name der Spec oder des Leitfadens]

**Autor*innen:** [Ihre Vornamen / Pseudonyme]
**Datum:** [TT/MM/JJJJ]
**Geltungsbereich:** [lokale Bibliothek / Netzwerk / Grundlagen]

### 1. Betreffende Regel

Den Text der Regel oder des zu ändernden Absatzes wörtlich zitieren, mit seiner Referenz in der Quell-Spec.

> *Beispiel:* „`spec-gouvernance-roles.md`, §5.6, T5: Die Frist vor dem Wirksamwerden des Ausschlusses beträgt 7 Tage."

### 2. Identifiziertes Problem

In wenigen Sätzen beschreiben, was an der aktuellen Regel problematisch ist. Wenn möglich mit einem konkreten erlebten Fall.

> *Beispiel:* „In der Praxis sind 7 Tage zu kurz, wenn die nächste AG der Bibliothek in 15 Tagen stattfindet. Eine in der Hitze des Gefechts getroffene Ausschlussentscheidung hat manchmal keine Zeit, vor dem automatischen Wirksamwerden kollektiv besprochen zu werden."

### 3. Vorgeschlagene Änderung

Die gewünschte Änderung beschreiben, nach Möglichkeit mit einer Formulierung, die bereit zur Integration in die Spec ist.

> *Beispiel:* „Die Säumnisfrist von 7 auf 14 Tage verlängern, ODER die Frist durch die Bibliothek konfigurierbar machen (zwischen 7 und 30 Tagen), mit einem Standardwert von 14 Tagen."

### 4. Antizipierte technische Konsequenzen

Falls Sie eine Vorstellung davon haben, was dies code-seitig bedeutet, dies angeben. Andernfalls ebenfalls angeben („ich weiß es nicht, muss mit den Entwickler*innen geklärt werden").

> *Beispiel:* „Den festen Wert im SQL-Code von `fn_team_request_remove_member` und `cron_team_pending_removal_complete` ändern. Wenn durch die Bibliothek konfigurierbar, eine Spalte zu `libraries` hinzufügen."

### 5. Antizipierte politische Konsequenzen

Beschreiben, was sich in der kollektiven Praxis ändert und mögliche Nebeneffekte.

> *Beispiel:* „Mehr Zeit für die Beratung, aber auch mehr Zeit, während der die Person in `pending_removal` gesperrt bleibt (ohne Zugang). Kann als belastender wahrgenommen werden."

### 6. Erwogene Alternativen

Die anderen Wege erwähnen, über die Sie nachgedacht haben, und warum Sie sie ausschließen (oder nicht).

> *Beispiel:* „Alternative: die Frist bei 7 Tagen belassen, aber eine „explizite Verlängerung" durch eine andere Koordinator*in ermöglichen. Komplexer zu implementieren und zu verstehen. Vorzuziehen ist es, den Standardwert zu ändern."

### 7. Gewünschte Diskussion

Wo und wie möchten Sie, dass der Vorschlag diskutiert wird?

> *Beispiel:* „Diskussion im Matrix-Kanal `#anarbib`, dann bei Konsens Integration in die Spec beim nächsten Governance-Paket."

---

Nach der Abfassung die Notiz entsprechend dem Geltungsbereich zirkulieren lassen (vgl. Kapitel 4, §4.2).

\newpage

# Anhang D — Quell-Specs und Referenzen

Dieser Leitfaden stützt sich auf folgende Dokumente, die im Projektrepository einsehbar sind:

## Hauptspecs

**`spec-gouvernance-roles.md`** — Gründungs-Spec der Governance der lokalen Personalrollen. Version 1.0 vom 5. Mai 2026. 1231 Zeilen. Detailliert die 4 Rollen, die 5 Statuswerte, die 9 Übergänge, das Audit-Log, die Benachrichtigungen, die UI und 15 Referenz-Anwendungsfälle.

**`spec-administrateur-reseau.md`** — Trennung zwischen lokalem Personal und Netzwerk-Administrator*innen. Version 0.3 vom 11. Mai 2026. 975 Zeilen. Detailliert die Tabelle `network_administrators`, die Kooptation durch Einstimmigkeit, den kollektiven Rückzug, das transversale Recht, die Semantik der Zähler „Seite = Perimeter".

**`spec-validation-physique.md`** — Aufnahme-Modi für Leser*innen-Konten (`open` vs `manual_validation`). Festgelegt am 3. Mai 2026. Detailliert die Kontostatus, das DB-Schema, die Workflows.

**`spec-refactor-v3-semantique.md`** — Refactor der Semantik des Reservierungs-Workflows. Für die Governance nicht zentral, aber am Rande für die Gesamtkohärenz des SIGB zitiert.

## Erwähnte verwandte Specs (noch zu schreiben oder in Bearbeitung)

- `spec-migration-compte.md` — Migration eines Kontos von einer Bibliothek zu einer anderen. 940 Zeilen, festgelegt am 3. Mai 2026.
- `spec-invitation-equipe.md` — Einladungs-Workflow per E-Mail für Personen ohne AnarBib-Konto. Noch zu schreiben.
- `spec-fermeture-biblio.md` — Verfahren zur ordnungsgemäßen Schließung einer Bibliothek. Noch zu schreiben.
- `spec-mediation-conflits.md` — Formalisierter Mediations- und Untersuchungsrahmen nach Meldungen. Noch zu schreiben (durch diesen Leitfaden vorgeschlagen).

## Weiterführende Informationen

Die Specs und der Quellcode befinden sich im Codeberg-Repository des Projekts, GitHub-Spiegel. Die technische und politische Diskussion findet im Matrix-Kanal `#anarbib` des Netzwerks statt.

Für jeden Änderungsvorschlag zu diesem Leitfaden oder zu den Specs, siehe Kapitel 4 und Anhang C.

---

*Ende des Leitfadens. Version 1.0, 11. Mai 2026.*

*Dieser Leitfaden ist selbst änderbar. Wenn Sie der Meinung sind, dass er etwas Falsches sagt, einen Fall vergessen hat oder eine Position einnimmt, die nicht mehr der Doktrin des Netzwerks entspricht, sagen Sie es.*

