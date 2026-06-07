---
title: "Governance-gids van AnarBib"
subtitle: "Voor coordinatoren van bibliotheken en beheerders van het netwerk"
author: "Projet AnarBib"
date: "Versie 1.1 — 5 juni 2026"
lang: nl
---

# Voorwoord

Deze gids is bestemd voor personen die binnen het AnarBib-netwerk een coördinerende functie vervullen — of het nu gaat om het coördineren van een lokale bibliotheek of om het beheren van het netwerk. De gids heeft een dubbel doel:

- **De politieke logica uitleggen** van de regels die in het AnarBib-SIGB zijn vastgelegd, en hun verwantschap met het project van collectieve emancipatie dat aan de basis ligt van de anarchistische bibliotheken;
- **De dagelijkse praktijk ondersteunen** door concrete vragen te beantwoorden die coordinatoren tegenkomen bij het gebruik van de software.

## Een politieke afspraak

Deze gids is niet het reglement van het netwerk, en heeft geen hogere autoriteit dan de beslissingen van de collectieven die er deel van uitmaken. Wat erin staat heeft alleen kracht omdat mensen op een bepaald moment hebben afgesproken de dingen zo te laten werken. Als de praktijken evolueren, zal deze tekst mee moeten evolueren, of worden tegengesproken, of verscheurd. Het gebruik dat de collectieven ervan maken zal zijn lot bepalen.

De technische regels die het AnarBib-SIGB handhaaft — de wachttermijnen, de coöptatiewerkwijzen, de statussen van lidmaatschappen, enz. — zijn ook afspraken. Ze zijn op bepaalde momenten door kameraden geschreven om specifieke problemen op te lossen. Ze zijn vastgelegd in **specificatiebestanden** (de `spec-*.md` van het depot), gedateerd en ondertekend, die zelf amendementen toelaten. Wie deze gids leest, leest de stand van een debat op een bepaald moment. Dit is geen grondwet.

## Hoe deze gids is georganiseerd

De gids bestaat uit twee delen:

- **Deel I — Het waarom.** Vier hoofdstukken die het politieke kader schetsen: waartoe dient een anarchistisch SIGB, wat zijn de grondbeginselen, hoe verhouden de twee niveaus (lokale bibliotheek en netwerk) zich tot elkaar, en hoe kunnen de regels zelf worden gewijzigd.

- **Deel II — Het hoe.** Zes praktische hoofdstukken die elk een grote operationele vraag behandelen: coöpteren, uitsluiten, omgaan met escalaties, de functie van netwerkbeheerder uitoefenen, transparantie waarborgen, en een laatste hoofdstuk met concrete casussen van begin tot eind.

Aan het einde van elk praktisch hoofdstuk staat een rubriek **"Als de regel u hindert"** die aangeeft waar het besproken kan worden en hoe een amendement kan worden voorgesteld. Dat is belangrijk omdat deze regels alleen zin hebben als ze amendeerbaar zijn.

De bijlagen aan het einde van het boek dienen als snelle naslagwerken: woordenlijst, index van technische functies met hun politieke vertaling, model voor een amendementsvoorstel, en links naar de bronspecificaties.

## Hoe deze gids te lezen

Men kan hem in één keer lezen, maar dat is waarschijnlijk niet het beste gebruik. Drie manieren om de tekst in te gaan, naargelang de behoeften:

- **Om de geest van het project te begrijpen** voordat men een functie opneemt: deel I lezen (hoofdstukken 1 tot 4).
- **Bij een concrete situatie**: direct naar het betrokken praktische hoofdstuk springen (5 tot 10).
- **Om zich voor te bereiden op een AV** waar een bestuursvraag aan de orde komt: het betrokken hoofdstuk lezen, plus de bijbehorende rubriek "Als de regel u hindert", en de bronspecificatie in bijlage D raadplegen.

Wat hier geschreven staat, steunt op vier specificatiedocumenten:

- `spec-gouvernance-roles.md` (5 mei 2026) — rollen, statussen, overgangen;
- `spec-administrateur-reseau.md` (11 mei 2026) — scheiding lokaal/netwerk, coöptatie bij unanimiteit;
- `spec-validation-physique.md` (3 mei 2026) — manieren om `reader`-accounts te ontvangen;
- `spec-refactor-v3-semantique.md` (9 mei 2026) — semantiek van de reserveringsworkflow (terzijde vermeld).

Verwijzingen naar deze specificaties staan doorheen de tekst in de vorm `(cf. spec-gouvernance, §3.4)` om verder onderzoek mogelijk te maken.

## Een noot over de stem

De tekst wisselt tussen **men** (het AnarBib-collectief, waarvan de auteur en de lezer ook deel uitmaken), **u** (wanneer een specifieke coordinator of beheerder wordt aangesproken die een keuze moet maken), en **wij** (wanneer gesproken wordt over de kameraden die de regels hebben geschreven, op een bepaald moment, die anders kunnen zijn dan wie ze leest). Dat is bewust. Er is hier geen institutionele neutraliteit: deze tekst wordt gedragen door kameraden, en richt zich tot kameraden.

\newpage

# Deel I — Het waarom

\newpage

# 1. Wat betekent een anarchistisch SIGB?

## 1.1. Het SIGB is niet de AV

Het eerste principe om vast te houden, en het moeilijkste, is dit: **het SIGB registreert de beslissingen van het collectief, het neemt ze niet**. Die zin klinkt onschuldig. In werkelijkheid is het de spil waarrond al het andere zich organiseert.

Elke keer dat het AnarBib-SIGB de schijn wekt van een autoriteit — wanneer het een promotie weigert, wanneer het een wachttermijn van zeven dagen oplegt, wanneer het een statusovergang blokkeert — doet het niets anders dan **uitvoerbaar maken** wat de collectieven zichzelf als regel hebben opgelegd. De regel is ergens geschreven, in een specificatie, na bespreking. Iemand heeft het herlezen en bekritiseerd. Een versie is vastgelegd en ingezet. En nu, op het moment dat u op de knop klikt, past de software gewoon toe wat is afgesproken.

Als u de regel dom, contraproductief of onrechtvaardig vindt, is het niet het SIGB dat bestreden moet worden. Het is de specificatie die gewijzigd moet worden. Zie hoofdstuk 4.

## 1.2. De aanvaarde spanning

Elke software die machtigingen beheert is, per definitie, een instrument van hiërarchisering. Iemand moet immers een inschrijving kunnen valideren, de publieke identiteit van een bibliotheek kunnen wijzigen, toegang kunnen hebben tot persoonlijke gegevens van een lezer. Die technische noodzaak staat in ogenschijnlijke spanning met het horizontaliteitsideaal dat de anarchistische bibliotheken bezielt.

AnarBib **erkent deze spanning** in plaats van haar te maskeren. Het politieke compromis dat is gevonden, bestaat uit twee punten:

- **Rollen zijn geen rangen.** Het zijn **functies** die tijdelijk door het collectief worden gedelegeerd aan bepaalde leden om specifieke technische taken uit te voeren. Niemand is voor altijd coordinator. Niemand is uit de aard der zaak netwerkbeheerder. Deze functies worden uitgeleend en kunnen worden teruggevraagd.

- **De mechanismen van terugtrekking** tellen even zwaar als de mechanismen van aanstelling. Het SIGB voorziet expliciet hoe iemand uit een functie treedt — door zelfterugtreding, door een collectief verzoek met wachttermijn, door zelfterugtrekking uit het netwerk, door collectieve terugtrekking bij unanimiteit. Een functie die niet verlaten kan worden is geen functie, maar een toe-eigening.

## 1.3. Delegatie en rotatie

Het centrale idee is dat van **delegatie met rotatie**. Een collectief delegeert aan bepaalde leden de uitvoering van technische taken (leningen beheren in het SIGB, de zichtbaarheid van de bibliotheek aanpassen, een nieuw lid in het team ontvangen). Deze delegatie is:

- **Expliciet**: ze krijgt gestalte in een coöptatiehandeling die in het auditlog is vastgelegd;
- **Omkeerbaars**: de gedelegeerde persoon kan de functie verlaten wanneer die dat wil, en het collectief kan dit vragen volgens gedefinieerde modaliteiten;
- **Van nature tijdelijk**: ook al legt het SIGB geen termijn op, de politieke cultuur van het netwerk is dat functies rouleren en men er zich niet in nestelt.

Het is die rotatie van functies die het verschil maakt tussen een "delegatie" (anarchistisch) en een "hiërarchie" (statelijk of kapitalistisch). Als men zich in een functie nestelt, wordt men een trede op een ladder. Als men er regelmatig uitstapt, blijft men een kamerad die een dienst verleent.

## 1.4. De acht grondbeginselen

De spec voor rollen-governance (`spec-gouvernance-roles.md`, §2) geeft acht grondbeginselen weer. Ze worden hier opgesomd om er later in de gids naar te verwijzen; elk praktisch hoofdstuk van deel II verwijst ernaar.

**P1 — Delegatie, geen hiërarchie.** Geen enkele rol is een titel. Alle rollen zijn van nature tijdelijk en herroepbaar.

**P2 — Coöptatie voor staffuncties.** Toetreden tot een team (worden als `librarian` of `coordenador`) gebeurt via coöptatie door de bestaande `coordenadores`. Het is aan het collectief om te beslissen wie wordt toegelaten; de coordinator is slechts de hand die de beslissing uitvoert in het SIGB.

**P3 — Vrijwillige terugtreding altijd mogelijk.** Elke persoon met een staffunctie kan zichzelf op elk moment terugtreden, zonder overleg. "Ik geef het stokje door" is een grondrecht.

**P4 — Uitsluiting geregeld door een wachttermijn.** De onvrijwillige uitsluiting van een `librarian` door een `coordenador` gaat gepaard met een wachttermijn van zeven dagen vóór inwerkingtreding. Die termijn maakt collectieve beraadslaging mogelijk en een eventuele annulering door een andere `coordenador`.

**P5 — Maximale transparantie.** Het auditlog van rolwijzigingen is leesbaar voor alle actieve stafleden van de bibliotheek, niet alleen door de `coordenadores`. Het voorkomen van ondoorzichtige manipulaties maakt deel uit van de politieke cultuur van informationele horizontaliteit.

**P6 — Systematische meldingen.** Elke rolwijziging triggert een e-mail aan de betrokken persoon en aan de volledige coördinatie. Niemand kan zonder het te weten in diens rol worden gewijzigd, en de coördinatie is altijd op de hoogte.

**P7 — Lokale soevereiniteit van bibliotheken.** Rolwijzigingen in bibliotheek A hebben geen effect op bibliotheek B, zelfs niet voor dezelfde persoon. Elke bibliotheek is soeverein over haar interne delegaties.

**P8 — Het SIGB modelleert de AV niet.** Het SIGB voert beslissingen uit, het neemt ze niet. Het bevat geen enkel mechanisme voor stemming, quorum of beraadslaging. Die dingen vinden collectief plaats, buiten de software.

## 1.5. Wat het SIGB niet doet

Het is nuttig om de keuzes voor **niet-modellering** expliciet te maken:

- Het SIGB **definieert niet** wat een "goede" coördinatie is. Een bibliotheek kan beslissen in een cirkel, in een plenaire AV, via roulatie, via loting, via consensus, via meerderheid. Het SIGB is dat om het even.
- Het SIGB **meet niet** de politieke legitimiteit van een coöptatie. Als een coordinator klikt op "X promoveren tot `librarian`", registreert het SIGB dat. Het is aan het collectief om te zorgen dat de beslissing correct is genomen, en die zekerheid schuilt in de politieke cultuur van het collectief.
- Het SIGB **beslist niet** over conflicten. Wanneer iets escaleert, biedt het SIGB hulpmiddelen (onmiddellijke schorsing, terugtrekkingsverzoek, leesbaar auditlog), maar de politieke beslissing blijft buiten de software.

Deze bescheidenheid is geen gebrek, het is een eis. Een SIGB dat de politieke structuur van een collectief zou willen modelleren, zou — ipso facto — autoritair zijn: het zou zijn visie opleggen van wat een "goede" beslissing is. AnarBib weigert die helling.

## 1.6. En het respect voor digitale vrijheden?

Drie verduidelijkingen, omdat de vraag steeds terugkomt:

- **Persoonsgegevens**: de `reader`-accounts bevatten wat de persoon zelf heeft ingevoerd. Bibliotheken hebben alleen toegang tot de gegevens die strikt noodzakelijk zijn voor hun werking. Lidmaatschappen bij andere bibliotheken zijn, per constructie, van elkaar afgeschermd (P7).

- **Auditlog**: het log is publiek **voor het actieve staf** van de bibliotheek, niet voor lezers noch voor de rest van het netwerk. Deze interne transparantie dient om ondoorzichtige manipulaties tussen coördinaties te voorkomen; het is geen panopticum gericht tegen lezers.

- **Cross-bibliotheeklogs**: wanneer een netwerkbeheerder ingrijpt op een bibliotheek (geval gedekt door de `spec-administrateur-reseau`, §6.3.1), wordt de handeling opgeslagen in een specifieke tabel met een kriticiteitsniveau. Dit is leesbaar door de netwerkbeheerders en door de coördinatie van de betrokken bibliotheek. Transparantie in beide richtingen.

\newpage

# 2. De twee niveaus: lokale bibliotheek en netwerk

## 2.1. Waarom deze scheiding

Het AnarBib-netwerk is geen keten van bibliotheken met een centraal hoofdkantoor. Het is een **federatie van autonome collectieven**. Die politieke realiteit heeft zich uiteindelijk opgelegd in de structuur van het SIGB zelf.

Aanvankelijk, in de eerste versies, was de rol "AnarBib-beheerder" gekoppeld aan een specifieke bibliotheek in de tabel `user_library_memberships`. Die modellering suggereerde — zonder het te zeggen — dat een AnarBib-beheerder *een bibliotheek beheerde*. Dat was politiek niet juist: een netwerkbeheerder coördineert de inter-bibliotheekcoördinatie, die beheert geen enkele bibliotheek in het bijzonder.

De spec `spec-administrateur-reseau.md` (11 mei 2026) heeft de scheiding vastgelegd. Voortaan kent het SIGB **twee afzonderlijke niveaus**:

- **Het lokale staf** van een bibliotheek (rollen `reader`, `librarian`, `coordenador`), opgeslagen in `user_library_memberships`. Diens politieke autoriteit situeert zich **binnen het bibliotheekdomein**.

- **Het netwerkbeheer** (tabel `network_administrators`), zonder koppeling aan een bibliotheek. Diens politieke autoriteit is **transversaal**, maar vervangt nooit de lokale autonomie.

## 2.2. Wat elk niveau doet

**Het lokale staf** beheert de dagelijkse werking van een bibliotheek: leningen, retourzendingen, reserveringen, validatie van inschrijvingen, aanpassing van het reglement, het circulatiebeleid, de publieke identiteit van de bibliotheek. Alles wat het functioneren van **één** bibliotheek betreft, wordt geregeld op het niveau van het lokale staf.

**Het netwerkbeheer** zorgt voor de inter-bibliotheekcoördinatie: activering van nieuwe bibliotheken, moderatie van de gedeelde catalogus, technisch onderhoud van het platform, onthaal van nieuwe collectieven, en uitzonderlijke tussenkomst wanneer een bibliotheek vastloopt (geen actieve coordinator, groot conflict, enz.). Alles wat het **netwerk** betreft, wordt geregeld op het niveau van het netwerkbeheer.

## 2.3. De regel van niet-overlapping

Een eenvoudige politieke regel stuurt alle tellers en alle weergaven van het SIGB:

> **Elke pagina vertelt het verhaal van haar domein. Een teller telt wat in haar domein is ingeschreven, niet meer en niet minder.**

Concreet:

- De pagina van een bibliotheek telt haar lokale lidmaatschappen. Punt. Netwerkbeheerders verschijnen niet in die tellers, ook al kunnen ze technisch ingrijpen op de bibliotheek.
- De pagina van het netwerk telt haar netwerkbeheerders. Punt.

Als iemand tegelijk `coordenador` van een bibliotheek **en** netwerkbeheerder is (het geval van Xavier op 11 mei 2026), verschijnt die in beide tellers, **één keer in elk**, zonder kruisdeduplicatie. Het zijn **twee afzonderlijke politieke inschrijvingen**, elk geteld in hun domein.

Waarom deze regel politiek gezond is, in vier punten:

- **Eerlijkheid**: uw lokale inzet wordt geteld in de bibliotheek waar u actief bent; uw netwerkinzet wordt geteld op netwerkniveau. Niemand telt u "1,5 keer".
- **Leesbaarheid**: een militant die de fiche van een bibliotheek bekijkt, ziet onmiddellijk hoeveel mensen **lokaal** betrokken zijn, zonder zich af te vragen of "externe" netwerkbeheerders de teller opdrijven.
- **Robuustheid**: als morgen tussenliggende rollen worden toegevoegd (hulpmedewerker, stagiair, waarnemer), blijft de regel "pagina = domein" helder.
- **Politieke coherentie**: de scheiding tussen netwerkbeheerder en lokaal staf is een **politieke beslissing**, geen modelleringsdetail. De tellers moeten die weerspiegelen.

## 2.4. Het transversale recht van de netwerkbeheerder

Dit punt verdient goed begrip omdat het gemakkelijk verkeerd geïnterpreteerd kan worden.

**Een netwerkbeheerder kan technisch ingrijpen op elke bibliotheek.** Die kan bijvoorbeeld de catalogus van een `private` bibliotheek lezen, de zichtbaarheid ervan aanpassen, of — in uitzonderlijke gevallen — lidmaatschappen aanmaken of wijzigen. Dat is wat de spec het **transversale interventierecht** noemt.

Dit recht bestaat om twee redenen:

- **Onderhoud**: iemand moet een bibliotheek kunnen deblokkeren die vastgelopen is (geen coordinator, kapotte configuratie, enz.).
- **Bemiddeling**: wanneer een ernstig conflict een bibliotheek doorkruist en het lokale collectief verhindert te functioneren, is er een beroepsmogelijkheid nodig.

Maar dit recht maakt de netwerkbeheerder **geen** hiërarchische meerdere van de lokale coördinatie. De doctrine van het netwerk, vastgelegd in deze gids:

> **Een interventie van de netwerkbeheerder op een lokale bibliotheek moet worden voorafgegaan door informatie aan de betrokken lokale coördinatie**, behalve bij vitale urgentie (actieve compromittering, lopend intimidatieprocedure, aanval op het platform). De voorafgaande informatie is geen verzoek om toestemming: de netwerkbeheerder heeft het recht te handelen. Maar het is een **blijk van respect** voor de autonomie van de bibliotheek, en het bewaart de mogelijkheid van een andere regeling (bijvoorbeeld: "laat me dit eerst zelf proberen op te lossen, ik houd u op de hoogte").

De technische traceerbaarheid bestaat overigens: alle cross-bibliotheekacties van een netwerkbeheerder worden bijgehouden in de tabel `cross_library_actions_log` met een kriticiteitsniveau, achteraf leesbaar door de lokale coördinatie.

## 2.5. De lokale soevereiniteit is onschendbaar

Een laatste politieke verduidelijking, die voortvloeit uit het principe **P7 — Lokale soevereiniteit van bibliotheken**.

De bibliotheken van het AnarBib-netwerk **erkennen elkaar wederzijds**. Wanneer BLMF een nieuwe lezer fysiek valideert (cf. `spec-validation-physique.md`), geldt die validatie voor alle `network`-bibliotheken van het netwerk. Dat is een **impliciet circuleerpact** tussen bibliotheken die genoeg politieke cultuur delen om elkaar te vertrouwen.

Maar die wederzijdse erkenning geeft **geen enkel recht van inmenging** van de ene bibliotheek in de andere. De coördinatie van bibliotheek A kan de lidmaatschappen van bibliotheek B niet wijzigen. Ze kan de persoonsgegevens van de lezers van B niet inzien (behalve die ook bij haar zijn ingeschreven). Ze kan het reglement van B niet aanpassen.

Elke bibliotheek blijft **soeverein over haar interne delegaties**, haar ontvangstbeleid, haar validatiemethode, haar contributieregels, haar intern reglement. Het netwerk zegt niet hoe ze moeten functioneren. Het zegt alleen met wie ze zich erkennen.

\newpage

# 3. Statussen, rollen, overgangen: de grammatica van het SIGB

Dit hoofdstuk is wat droger dan de andere. Hierin leggen we het technische vocabulaire vast dat door de hele gids wordt gebruikt. Als je het bij de eerste lezing overslaat, kun je er altijd op terugkomen wanneer nodig.

## 3.1. De vier rollen

Het SIGB AnarBib gebruikt vier rollen, gedeclareerd in de database door de beperking `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` op de tabel `user_library_memberships`.

**`reader`** — Basis lezerAccount. Geen beheerbevoegdheden. Rechten: de catalogus raadplegen (afhankelijk van de zichtbaarheid van de bibliotheek), lenen, reserveren, zaalraadpleging, eigen persoonlijke gegevens wijzigen, migratie of verwijdering van het account aanvragen.

**`librarian`** — Operationeel personeel. Beheert de dagelijkse taken: leningen, reserveringen, retouren, validatie van inschrijvingen (afhankelijk van de modus van de bibliotheek), wijziging van catalogusgegevens, toegang tot persoonlijke gegevens van de lezers van de bibliotheek. **Alleen-lezen** op de teamlijst. Ontvangt meldingen van rolwijzigingen en kan het auditlog van het team lezen (P5).

**`coordenador`** — Coördinatiepersoneel. Alles wat een `librarian` heeft, plus: de publieke identiteit van de bibliotheek wijzigen (naam, logo, contact, enz.), de configuratie wijzigen (leenbeleid, reglement), contributieregelingen beheren, **en alle teambestuursacties**: coöpteren, een verwijdering aanvragen, schorsen, een schorsing opheffen, een verwijderingsaanvraag annuleren.

**`administrador`** — Historische rol, in de uitfasering. Bestond om "beheerrechten over meerdere bibliotheken" aan te geven maar gekoppeld aan een `library_id`. Vervangen door de **netwerkbeheerders** opgeslagen in de tabel `network_administrators` (zie hoofdstuk 2). De spec admin-netwerk voorziet in geleidelijke migratie en definitieve verwijdering van deze rol uit de tabel `user_library_memberships`.

## 3.2. De vijf statussen van een lidmaatschap

Elke rij in de tabel `user_library_memberships` heeft een **status** die de staat van de delegatie op een bepaald moment uitdrukt. Vijf statussen zijn mogelijk:

**`active`** — Normale toestand. De persoon heeft zijn/haar/diens rol en oefent die uit.

**`pending`** — Voorbehouden aan de spec fysieke validatie. Het lidmaatschap is aangemaakt maar wacht op een fysieke ontmoeting met een `librarian+` van de inschrijfbibliotheek. Geen toegang tot de functies van de rol zolang deze status actief is.

**`suspended`** — **Conservatoire maatregel** genomen door een `coordenador`. Geen toegang. Gebruik: gemeld intimidatiegedrag in afwachting van onderzoek, gecompromitteerd account, conflict in mediatieprocedure. **Onbepaalde duur**; opheffing is handmatig, door een coördinator (terug naar `active`) of door feitelijke afzetting.

**`pending_removal`** — **Wachttijd van zeven dagen** vóór feitelijke uitsluiting. Geen toegang gedurende deze periode. Mogelijke verdere ontwikkeling: annulering door een andere coördinator (terug naar `active`), zelf-degradatie door de persoon zelf (kortsluiting), of automatische overgang naar `inactive` op dag +7.

**`inactive`** — Gesloten lidmaatschap. De persoon is niet meer in het team. Geen toegang. Meerdere mogelijke oorzaken: vrijwillig vertrek, einde wachttijd, verlaten account (automatisch na 9 maanden).

## 3.3. Het transitieschema

Het SIGB staat niet elke overgang tussen statussen toe. Hier, vereenvoudigd, het toegestane schema:

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
              │ opheffing      │ annulering
              └────────────────┴────────────┐
                               │            │
                               ▼ (dag+7)    ▼
                        ┌──────────────┐
                        │   inactive   │
                        └──────────────┘
```

Enkele kernregels:

- Men kan **niet** rechtstreeks van `active` naar `inactive` gaan voor een `librarian` door een eenzijdige beslissing van een andere coördinator. Er moet via `pending_removal` worden gegaan en de wachttijd worden afgewacht (of de persoon degradeert zichzelf).
- Men kan **altijd** van de eigen `active` status naar `inactive` gaan (zelfdegradatie, recht P3).
- `suspended` heeft **geen** maximale duur. Het is geen wachttijd vóór uitsluiting, het is een conservatoire maatregel — die duurt zolang de beraadslaging loopt.
- Van `inactive` keert men **niet terug** naar `active`. Om iemand te herintegreren, maakt men een nieuwe lidmaatschapsrij aan. De geschiedenis blijft bewaard.

## 3.4. De negen overgangen: wie mag wat

De spec rollenbestuur formaliseert negen overgangen, hier beknopt weergegeven. De operationele details staan in deel II.

| # | Overgang | Wie | Mechanisme |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coördinator+ | Coöptatie |
| T2 | `librarian` → `coordenador` | Coördinator+ | Coöptatie |
| T3 | `coordenador` → `librarian` | Zichzelf OF andere coördinatoren | Zelfdegradatie OF collegiaal terugtrekken met wachttijd |
| T4 | `librarian` → `reader` (vrijwillig) | Zichzelf | Zelfdegradatie |
| T5 | `librarian` → `reader` (collectief) | Coördinator+ | `pending_removal` met wachttijd 7 dagen |
| T6 | Onmiddellijke schorsing | Coördinator+ | Overgang naar `suspended` |
| T7 | Opheffing schorsing | Coördinator+ | Terug `suspended` → `active` |
| T8 | Annulering van een verwijderingsaanvraag | Coördinator+ | Terug `pending_removal` → `active` |
| T9 | Automatisch vertrek (verlaten account) | Cron | Overgang naar `inactive` na 9 maanden zonder inloggen |

Drie principes structureren deze tabel:

- **Toetreding verloopt via coöptatie** (T1, T2). Niemand promoveert zichzelf.
- **Vrijwillig vertrek is altijd mogelijk** (T3 zelf, T4). Niemand blijft gevangen in een functie die die persoon niet meer wil uitoefenen.
- **Opgelegde uittreding wordt vertraagd door de wachttijd** (T5). Zeven dagen om eventueel collegiaal terugkomen mogelijk te maken.

## 3.5. Netbeheer: een tweelingschema

Het netwerkbeheer (tabel `network_administrators`) heeft zijn eigen levenscyclus, structureel zeer vergelijkbaar maar met twee bijzonderheden:

- **Coöptatie met unanimiteit**: om een nieuwe netwerkbeheerder toe te voegen, wordt een voorstel geopend door een actieve beheerder, en **alle andere actieve beheerders** moeten `favorable` stemmen. Eén stem `opposed` (met verplichte motivering van minimaal 20 tekens) blokkeert het voorstel. Een onthouding blokkeert ook zolang die niet is omgezet in een stem.

- **Collectief terugtrekken met unanimiteit**: om een netwerkbeheerder tegen diens wil te verwijderen, geldt dezelfde workflow spiegelbeeldig. Met een wachttijd van **zeven dagen** na unanime instemming (veld `pending_collective_removal_until`).

Zelfterugtrekking is **unilateraal en altijd mogelijk** (tenzij men de enige actieve beheerder is, in welk geval de overgang via `pending_removal` loopt met een wachttijd van 30 dagen, en een waarschuwingsmail naar de andere beheerders).

Volledige details in hoofdstuk 8.

\newpage

# 4. Omkeerbaarheid en wijzigbaarheid

Dit korte hoofdstuk behandelt een cruciale politieke vraag: **hoe kunnen deze regels worden gewijzigd?** Als dat niet mogelijk zou zijn, zou het SIGB een autoriteit zijn, en zou de rest van deze gids een leugen zijn.

## 4.1. Drie niveaus van wijzigbaarheid

Er moeten drie niveaus van regels worden onderscheiden, die niet op dezelfde manier worden gewijzigd:

**De lokale praktijken van een bibliotheek** — ontvangstbeleid, modus van fysieke validatie (`open` of `manual_validation`), huishoudelijk reglement, frequentie van algemene vergaderingen, coöptatiewijzen. Deze praktijken zijn **intern aan elke bibliotheek**. Het netwerk bemoeit zich er niet mee. Ze worden gewijzigd in de AV van de bibliotheek, of volgens de procedure die het collectief zichzelf heeft gegeven.

**De regels van het netwerk** — scheiding lokaal/netwerk, principe van coöptatie met unanimiteit voor netwerkbeheerders, doctrine van voorafgaande informatie bij een cross-bibliotheek interventie, activeringswijzen van nieuwe bibliotheken. Deze regels zijn **inter-bibliotheek**. Ze worden gewijzigd in netwerkcoördinatie, na overleg tussen netwerkbeheerders en betrokken lokale coördinaties.

**De politieke grondslagen van het project** — de acht principes (P1 tot P8 van hoofdstuk 1), het idee dat het SIGB de AV niet modelleert, de beleden bescheidenheid van de software tegenover het politieke leven van de collectieven. Deze grondslagen kunnen worden gewijzigd, maar ze zijn structurerend: ze wijzigen betekent waarschijnlijk wijzigen wat men "AnarBib" in brede zin noemt. Een herziening van deze omvang zou verlopen via een collectieve bespreking in het hele netwerk, waarschijnlijk bij gelegenheid van een evenement (jaarlijkse ontmoeting, enz.).

## 4.2. Hoe een wijziging voorstellen

Er is niet één manier van handelen — elk niveau heeft de zijne — maar hier het algemene patroon dat het netwerk de neiging heeft te volgen:

1. **De betrokken spec identificeren**. De regels van het SIGB zijn vastgelegd in `spec-*.md` bestanden in het repository. Zoek degene die de regel bevat die u wilt wijzigen (bijlage D geeft de overeenkomsten).

2. **Een wijzigingsnota opstellen**. Vrij formaat, maar die antwoordt op: welke regel, waarom die een probleem vormt, welke wijziging men voorstelt, welke technische en politieke gevolgen men anticipeert. Bijlage C stelt een model voor.

3. **De nota laten circuleren**. Afhankelijk van het niveau:
   - **Lokaal**: in de AV van de bibliotheek, of op het discussiekanaal van het collectief.
   - **Netwerk**: op het inter-bibliotheek coördinatiekanaal (Matrix `#anarbib`), door de netwerkbeheerders en de relevante lokale coördinaties te taggen.
   - **Grondslagen**: op alle kanalen, en waarschijnlijk op de agenda van een ontmoeting.

4. **Bespreken, aanpassen, een versie aannemen**. Het SIGB zegt niet hoe deze stap moet verlopen. Dat is het werk van de collectieven.

5. **Als de beslissing is genomen**: een netwerkbeheerder of een ontwikkelaar (vaak dezelfde of dezelfden) implementeert de wijziging in de overeenkomstige spec, dan in de code. De nieuwe versie wordt ingezet volgens de gebruikelijke procedure (changelog, communicatie, enz.).

## 4.3. Als de technische beslissing problemen oplevert

Het gebeurt dat men het politiek eens is over een regel, maar dat de technische vertaling ervan ingewikkeld, zwaar of met ongewenste neveneffecten gepaard gaat. Dat is normaal. De bestaande specs zitten vol met notities zoals "deze politieke beslissing impliceert 22 sub-SELECT-statements in de RLS aan te raken, wat een voorafgaand refactoring rechtvaardigt". De politieke/technische dialoog is permanent.

Wanneer u een wijziging voorstelt, doe dat gerust ook als u geen idee heeft van de technische moeilijkheidsgraad. De ontwikkelaars van het netwerk zullen u vertellen wat het kost. En als het erg duur is, kunt u collectief beslissen of de politieke inzet de technische kosten waard is. Omgekeerd maakt een schijnbaar onbeduidende politieke wijziging soms een enorme vereenvoudiging van de codebase mogelijk.

## 4.4. Deze gids is zelf wijzigbaar

Deze gids is geversioneerd. De huidige versie staat op de omslag. Als u vindt dat die iets verkeerd zegt, een geval heeft vergeten, of een standpunt inneemt dat niet meer overeenkomt met de doctrine van het netwerk, **zeg dat**. Open een bespreking, stel een wijziging voor, of herschrijf het betreffende passage en dien het in.

Een gids die niet kan worden gewijzigd is geen gids, het is een dogma. Het project AnarBib heeft niet de ambitie dogma's te produceren.

\newpage

# Deel II — Het hoe

\newpage

# 5. Iemand coöpteren in het team

Dit hoofdstuk behandelt de overgangen T1 (`reader` → `librarian`) en T2 (`librarian` → `coordenador`), dat wil zeggen de **twee instapmomenten** in een bibliotheekteam. De fysieke validatie van een nieuwe `reader` (die geen coöptatie in politieke zin is maar een technische ontvangstoperatie) wordt apart behandeld in §5.5.

## 5.1. Het politieke principe

> **P2 — Coöptatie voor personeelsrollen.** Toetreding tot een team gebeurt door coöptatie van de bestaande coördinatoren. Het is aan het politieke collectief om te beslissen wie wordt toegelaten; de coördinator is slechts de hand die de beslissing in het SIGB uitvoert.

Dit betekent dat **klikken op "Promoveren"** geen persoonlijke beslissing is van de coördinator die klikt. Het is de **technische uitvoering** van een beslissing die is genomen — of moet worden genomen — door het politieke collectief van de bibliotheek. De doctrine van het netwerk over "wanneer precies" de beslissing moet worden genomen is opzettelijk niet beslecht door deze gids: elke bibliotheek maakt haar eigen doctrine (zie §5.4).

## 5.2. Iemand als `librarian` laten intreden (T1)

### Voorwaarden

- De persoon heeft een AnarBib-account (die persoon is ergens in het netwerk ingeschreven).
- Die persoon heeft nog geen actief `librarian`- of `coordenador`-lidmaatschap in dezelfde bibliotheek.
- Die persoon kan al dan niet een actief `reader`-lidmaatschap in dezelfde bibliotheek hebben. Zo ja, dit bestaande lidmaatschap blijft parallel actief (meervoudig lidmaatschap toegestaan).

### Procedure in het SIGB

1. Ga naar `/biblioteca`, tabblad **Team** (zichtbaar voor `coordenador+`).
2. Als de persoon al lezer van de bibliotheek is, klik **"Uitnodigen in het team"** op diens rij. Als die persoon nog geen lezer is, gebruik de zoekbalk bovenaan of — als die nog geen account heeft — gebruik de workflow voor uitnodiging per e-mail (binnenkort beschikbaar, zie `spec-invitation-equipe.md`).
3. Kies de rol `librarian`.
4. Bevestig de modal. Een veld "Reden" is optioneel — het dient om in het auditlog de context van de coöptatie te vermelden (bijvoorbeeld "beslissing AV van 04/05", of "coöptatie in kleine kring, te valideren op de volgende AV").
5. Het SIGB voert uit:
   - Aanmaken van een rij `user_library_memberships` met `role='librarian'`, `status='active'`.
   - E-mail aan de betrokken persoon: "Je bent benoemd als librarian van [bibliotheek] door [u]".
   - E-mail aan alle actieve coördinatoren van de bibliotheek.
   - Invoer in het auditlog: `action='promoted_to_librarian'`.

### Onmiddellijk effect

De persoon ontvangt, zonder vertraging, de rechten van `librarian`: beheer van leningen, validatie van inschrijvingen, toegang tot persoonlijke gegevens van de lezers van de bibliotheek, enz. Die persoon ontvangt niet de rechten om de publieke identiteit of de configuratie te wijzigen — die zijn voorbehouden aan `coordenador+`.

### Technische kant

Betrokken RPC: `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.3. Een `librarian` promoveren tot `coordenador` (T2)

### Voorwaarden

- De persoon heeft een actief `librarian`-lidmaatschap (`active`) in de bibliotheek.
- Die persoon heeft nog geen actief `coordenador`-lidmaatschap in dezelfde bibliotheek.

### Procedure in het SIGB

1. Ga naar `/biblioteca`, tabblad **Team**.
2. Klik op de rij van de persoon **"Promoveren"** → **"coordenador"**.
3. Bevestig de modal. Het veld "Reden" is optioneel.
4. Het SIGB voert uit:
   - Aanmaken (of reactivering) van een `coordenador`-rij `active`. De oude `librarian`-rij blijft parallel actief (meervoudig lidmaatschap; zie §5.6).
   - E-mail aan de persoon.
   - E-mail aan alle actieve coördinatoren.
   - Invoer in het auditlog: `action='promoted_to_coordenador'`.

### Onmiddellijk effect

De persoon ontvangt, bovenop de rechten van `librarian`, de coördinatierechten: wijziging van de publieke identiteit, de configuratie, de contributieregelingen, en alle teambestuursacties.

### Technische kant

Betrokken RPC: `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.4. De politieke vraag: wanneer klikken?

Dit is de vraag die elke coördinator zich de eerste keer stelt. Het netwerk AnarBib **heeft deze vraag opzettelijk niet beslecht** op gidsniveau: elke bibliotheek maakt haar eigen doctrine, omdat de politieke cultuur van een anarchistisch collectief niet op het niveau van een generieke gids wordt besloten.

Hier zijn de drie doctrines die men in het netwerk aantreft, zonder oordeel:

**Doctrine 1 — Strikte wachttijd.** Er wordt alleen geklikt **na** een geregistreerde beslissing van het collectief (AV, kring, formele consensus, de modaliteit doet er niet toe). De coördinator voert slechts uit. Voordeel: maximalisering van de horizontaliteit, sterke politieke traceerbaarheid. Nadeel: kan traag zijn, met name wanneer de bibliotheek in de opstartfase zit of het collectief verspreid is.

**Doctrine 2 — Afgebakende anticipatie.** De coördinator kan anticiperen op een beslissing die die persoon zeker acht ("het is duidelijk dat Voltairine zal worden gecoöpteerd, die komt al zes maanden elke week"), **op voorwaarde dat dit expliciet in het auditlog wordt vermeld**: reden = "anticipatie onder mijn verantwoordelijkheid, te valideren op de volgende AV". De beslissing kan achteraf worden betwist, en het terugtrekken blijft altijd mogelijk. Voordeel: praktische soepelheid. Nadeel: verplaatst een deel van de politieke verantwoordelijkheid naar de coördinator die klikt.

**Doctrine 3 — Coördinatorkring.** De coöptatie wordt genomen door overeenstemming tussen de actieve coördinatoren van de bibliotheek, zonder door de plenaire AV te gaan. Argument: de coördinatie is zelf een delibererend collectief, en het heeft het mandaat om te handelen. Voordeel: tussenliggend tussen 1 en 2. Nadeel: kan ondoorzichtig worden als de coördinatie zelf niet wordt vernieuwd.

**Onze aanbeveling** (en niet meer dan dat): **kies expliciet** een doctrine, schrijf die in het reglement van uw bibliotheek, en vermeld die in het veld "Reden" van het auditlog bij elke coöptatie (bijv. "doctrine 2 — anticipatie onder mijn verantwoordelijkheid"). Ondoorzichtigheid is zelden goed in de politiek.

## 5.5. Bijzonder geval: de fysieke validatie van een `reader`

De **komst** van een `reader` naar een bibliotheek is een andere operatie dan een coöptatie in politieke zin. Ze wordt gedekt door de spec `spec-validation-physique.md`.

Twee mogelijke modi, gekozen door elke bibliotheek in haar configuratie:

**Modus `open`** — De validatie is **automatisch** bij inschrijving. Zodra het account is aangemaakt en het e-mailadres is bevestigd, heeft de `reader` onmiddellijk toegang tot de `public`- en `network`-catalogi. Geschikt voor bibliotheken met weinig politieke blootstelling.

**Modus `manual_validation`** — Het account wordt online aangemaakt maar blijft **in afwachting** totdat er een **fysieke ontmoeting** plaatsvindt tussen de `reader` en een `librarian+` van de inschrijfbibliotheek. Geschikt voor blootgestelde bibliotheken (gespannen politieke context, gevoelige collecties, kwetsbare locaties, enz.).

### Procedure voor fysieke validatie (modus `manual_validation`)

1. De persoon schrijft zich online in en kiest uw bibliotheek als thuisbibliotheek.
2. Diens account wordt aangemaakt met `status='pending'`. Die persoon ontvangt een e-mail met uitleg dat die zich fysiek bij de bibliotheek moet melden.
3. Wanneer die persoon komt, ontmoet een `librarian+` die persoon, verifieert wat te verifiëren valt (de doctrine van wat "verifiëren" betekent is lokaal), en klikt **"Valideren"** op diens rij in het tabblad **Team** → sectie **Accounts in afwachting**.
4. Een optioneel veld "Notitie" maakt het mogelijk een context te vermelden ("ontmoeting van 12/05 tijdens de permanentie, voorgesteld door Emma").
5. Het account gaat naar `status='active'`. De persoon ontvangt een welkomst-e-mail.

### Politiek belangrijk

- De fysieke validatie van een bibliotheek **geldt voor het hele netwerk** van `network`-bibliotheken (P7 genuanceerd: lokale soevereiniteit betreft interne delegaties, maar wederzijdse erkenning is een expliciet pact).
- Wat men "verifieert" bij een fysieke validatie is **geen** identiteitscontrole in administratieve zin. Het is een ontmoeting. Elke bibliotheek bepaalt de politieke betekenis ervan. Voor sommigen is het "we wisselen even om te controleren dat die persoon geen politieagent of fascist is". Voor anderen is het "we stellen de bibliotheek voor, haar werking, haar regels". Voor weer anderen is het gewoon "we ontmoeten elkaar in het echt zodat de relatie belichaamd is".
- Een bibliotheek kan **van modus wisselen** op elk moment (`coordenador+`). De wijziging maakt bestaande validaties niet ongeldig.

## 5.6. Het meervoudig lidmaatschap: aandachtspunt

Een technische bijzonderheid om te begrijpen: een persoon kan **meerdere rijen** lidmaatschap hebben in dezelfde bibliotheek, met verschillende rollen. Voltairine kan bijvoorbeeld tegelijk `reader` en `librarian` zijn van BLMF. Dit wordt mogelijk gemaakt door de UNIQUE-beperking op het drietal `(user_id, library_id, role)`.

**Waarom deze mogelijkheid**: ze bewaart de geschiedenis. Als Voltairine morgen van `librarian` naar `reader` degradeert, gaat diens `librarian`-rij naar `inactive` maar de `reader`-rij blijft — zonder een nieuwe inschrijving vanaf nul te hoeven aanmaken.

**Praktisch gevolg**: in de UI wordt de persoon **één keer** weergegeven, met diens **hoogste actieve rol** (administrador > coordenador > librarian > reader). In het auditlog wordt echter elke rij afzonderlijk getoond.

## 5.7. Fouten en veiligheidsmechanismen

Enkele gevallen die men regelmatig tegenkomt:

**"Het SIGB zegt me dat de persoon al librarian is."** Dat klopt waarschijnlijk. Controleer het tabblad **Team**: als de persoon er al als librarian in staat, probeert u die te promoveren naar hetzelfde niveau; het SIGB geeft een stille succesmelding terug (`{ok: true, no_change: true}`) omdat er niets te doen is.

**"Ik zie die persoon niet in de lijst."** Drie mogelijke gevallen: (a) die heeft nog geen AnarBib-account (de workflow voor uitnodiging per e-mail gebruiken, binnenkort beschikbaar); (b) die heeft een account maar is bij geen enkele bibliotheek ingeschreven (die moet zich eerst als `reader` bij uw bibliotheek inschrijven); (c) die bevindt zich in het netwerk maar is gefilterd door de zoekfunctie — probeer met het exacte e-mailadres.

**"Ik heb per ongeluk op Promoveren geklikt."** Geen paniek. Gebruik **"Verwijdering aanvragen"** om een wachttijd van 7 dagen te openen (zie hoofdstuk 6), of vraag de persoon om op **"Ik doe een stap terug"** te klikken (onmiddellijke zelfdegradatie). Vermeld "manipulatiefout" als reden.

**"De persoon ontvangt de e-mail niet."** Controleer eerst de spelling van diens e-mailadres in diens profiel, en vraag die om de spammap te controleren. Als het probleem aanhoudt, meldt dit aan een netwerkbeheerder: het is waarschijnlijk een e-mailconfiguratieprobleem dat moet worden onderzocht.

## 5.8. Als de regel u stoort

Verschillende dingen in dit hoofdstuk zijn mogelijk niet naar uw wens:

- **Het principe van coöptatie zelf** (P2). U vindt dat elke betrokken `reader` vrij moet kunnen overstappen naar `librarian` zonder coöptatie nodig te hebben. Dit is een fundamenteel politiek debat, dat raakt aan principe P1. Te bespreken op het netwerkcoördinatiekanaal en waarschijnlijk te bespreken in een ontmoeting.

- **Het ontbreken van een besliste doctrine over "wanneer klikken"** (§5.4). U vindt dat de gids één doctrine zou moeten aanbevelen. Of omgekeerd, u vindt dat die er te veel suggereert. Een wijziging van dit hoofdstuk voorstellen, met argumentatie.

- **De modi voor fysieke validatie** (§5.5). U vindt dat er een derde nodig is ("uitgestelde validatie", "validatie op afstand", anders). Te bespreken via `spec-validation-physique.md`.

- **Het meervoudig lidmaatschap** (§5.6). U vindt het onnodig complex en dat er één rol per persoon per bibliotheek zou moeten zijn. Dit is een gegevensmodellingsbeslissing, meer structurerend dan het lijkt. Te bespreken met de ontwikkelaars.

Zie hoofdstuk 4 voor de algemene wijzigingsprocedure, en bijlage C voor het notamodel.

\newpage

# 6. De functie overdragen, terugtrekken, schorsen

Dit hoofdstuk behandelt de transities T3 tot T8 — dat wil zeggen **alles waarmee iemand een team verlaat**, of tijdelijk op pauze wordt gezet. Politiek gezien is dit waarschijnlijk het belangrijkste hoofdstuk van de handleiding, omdat de terugtrekkingsmechanismen centraal staan in het anarchistische project (zie hoofdstuk 1, §1.2).

## 6.1. De politieke principes

Drie principes structureren dit hoofdstuk :

> **P3 — Vrijwillige terugtreding altijd mogelijk.** Ieder persoon met een staffrol kan zichzelf op elk moment terugzetten, zonder overleg. « Ik draag over » is een fundamenteel recht.

> **P4 — Uitsluiting begeleid door een wachttermijn.** De niet-vrijwillige uitsluiting van een `librarian` door een `coordenador` verloopt via een wachttermijn van zeven dagen voor de inwerkingtreding. Die termijn maakt collectieve beraadslaging en eventuele annulering door een andere `coordenador` mogelijk.

> **P6 — Systematische meldingen.** Elke rolwijziging activeert een e-mail aan de betrokken persoon en aan de volledige coördinatie.

Het basisidee is dat iemand nooit « als verrassing » of « in stilte » uit een team wordt gezet. Ofwel beslist de persoon zelf (en is het onmiddellijk van kracht), ofwel vraagt het collectief het (en is het traceerbaar, gemeld en beraadslaagbaar tot op het laatste moment).

## 6.2. De functie overdragen : zelf terugzetten (T3 en T4)

Dit is het **meest fundamentele recht** in het governancesysteem van AnarBib. Ieder persoon die een stafffunctie uitoefent kan die op elk moment, zonder enig overleg, neerleggen.

### Wanneer gebruiken

- Je hebt niet langer de tijd om de functie te vervullen.
- Je herkent jezelf niet meer in de beslissingen van de coördinatie.
- Je bent het niet eens met een beslissing en wil je er niet mee solidariseren.
- Je wil de functie gewoon laten rouleren.
- Je hebt behoefte aan een pauze.
- Geen reden vereist, eigenlijk. Het recht om te vertrekken is onvoorwaardelijk.

### Procedure

1. Ga naar `/biblioteca`, tabblad **Equipe**.
2. Klik op **je eigen rij** op **« Ik draag over »**.
3. Kies het niveau van terugzetting :
   - Als je `coordenador` bent, kun je kiezen voor « teruggaan naar librarian » (je blijft in het team als `librarian`) of « het team verlaten » (je wordt opnieuw `reader`).
   - Als je `librarian` bent, kun je kiezen voor « het team verlaten » (je wordt opnieuw `reader`).
4. De modal herinnert aan de gevolgen. Bevestigen.

### Onmiddellijk effect

- Je huidige membership (`librarian` of `coordenador`) gaat naar `inactive`.
- Als je de doelmembership (`reader` of `librarian`) nog niet had, wordt die aangemaakt op `active`.
- E-mail aan de volledige coördinatie + aan jezelf (bevestiging).
- Auditlog : `action='self_demoted'`.

### Bijzonder geval : jij bent de enige actieve `coordenador`

Het SIGB **laat je vertrekken**, maar waarschuwt je :

> ⚠️ LET OP : je bent de enige actieve `coordenador` van [biblio]. De biblio komt zonder coördinatie te staan. De AnarBib-beheerders worden ingelicht. Doorgaan?

Als je bevestigt :
- Je coord-membership gaat naar `inactive`.
- De biblio gaat in **degraded mode** : `librarian`s kunnen blijven lenen beheren, inschrijvingen valideren, enz., maar geen wijziging van de publieke identiteit of de configuratie is mogelijk totdat een nieuwe coord wordt gecoöpteerd.
- E-mail aan alle netwerkbeheerders : « Biblio X heeft geen `coordenador` meer. Dit zijn de actieve `librarian`s : ... »

Politiek gezien is dit belangrijk : het SIGB **belet je vertrek niet**. Maar het informeert het netwerk, zodat een netwerkbeheerder, als je dat wenst en als het lokale collectief er behoefte aan heeft, contact kan opnemen om de transitie te helpen organiseren. Dit is de functierotering in de praktijk.

### Technische kant

RPC : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

## 6.3. Het terugtrekken van een `librarian` aanvragen (T5)

Wanneer het collectief beslist dat iemand het team moet verlaten, en die persoon zichzelf niet terugzet, wordt een **terugtrekkingsverzoek met een wachttermijn van zeven dagen** geopend.

### Voorwaarden

- Je bent actieve `coordenador+` van de biblio.
- De doelpersoon heeft een `librarian`- of `coordenador`-membership met status `active`.
- Je bent niet de doelpersoon zelf (gebruik anders §6.2).

### Procedure

1. Ga naar `/biblioteca`, tabblad **Equipe**.
2. Klik op de rij van de persoon op **« Terugtrekking aanvragen »**.
3. De modal die opent is **rood en nadrukkelijk**. Ze herinnert aan :
   - De wachttermijn : « Dit verzoek treedt in werking op [datum J+7] tenzij het wordt geannuleerd door een andere `coordenador`. »
   - Het omkeerbare karakter : « Annuleerbaar door elke coordinator tot de inwerkingsdatum. »
   - Het collegiale karakter : « Alle actieve coordinatoren worden ingelicht. »
4. Een veld **« Reden »** is verplicht — minimaal 20 tekens. Geen stille terugtrekking. De reden kan politiek zijn (« beslissing AV van 04/05 ») of praktisch (« aangekondigd geografisch vertrek »). Ze zal leesbaar zijn voor al het actieve staffpersoneel in het auditlog.
5. Bevestigen.

### Onmiddellijk effect

- De membership gaat naar `pending_removal`.
- Veld `pending_removal_until` = `now() + 7 days`.
- Veld `pending_removal_requested_by` = jij.
- **Geen toegang** voor de persoon tijdens de wachttermijn (de membership is bevroren als `suspended`).
- E-mail aan de betrokken persoon : « De coördinatie heeft je terugtrekking uit het team [biblio] aangevraagd (opzegtermijn tot [datum]). Deze beslissing maakt deel uit van het organische leven van het collectief [biblio] ; voor elk gesprek, wend je tot de coördinatie. »
- E-mail aan alle actieve `coordenador`s : met jouw naam en de reden.
- Auditlog : `action='removal_requested'` met jouw `actor_user_id` en het veld `reason`.

### Effect op J+7 (automatische cron)

Als het verzoek niet werd geannuleerd of kortgesloten :
- De membership gaat naar `inactive`.
- Definitieve e-mail aan de persoon en de coördinatie : « Terugtrekking effectief. »
- Auditlog : `action='removal_completed'`.

### Technische kant

RPC : `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron : `cron_team_pending_removal_complete` (dagelijks uitgevoerd).

## 6.4. Een terugtrekkingsverzoek annuleren (T8)

De **collegiale bescherming** van het systeem. Elke coordinator — niet noodzakelijk degene die het verzoek deed — kan een terugtrekkingsverzoek annuleren tijdens de wachttermijn.

### Wanneer gebruiken

- Het collectieve overleg heeft geleid tot een andere beslissing (bemiddeling, tijdelijke schorsing in plaats daarvan, enz.).
- Het oorspronkelijke verzoek werd in de hitte van het moment ingediend en de coördinatie wil collegiaal hervatten.
- De doelpersoon is uiteindelijk bereikt en de situatie is ontsnapt.

### Procedure

1. Ga naar `/biblioteca`, tabblad **Equipe**, sectie **Lopende schorsingen en opzegtermijnen**.
2. Klik op de rij van de persoon in `pending_removal` op **« Verzoek annuleren »**.
3. Eenvoudige bevestigingsmodal. Veld « Reden » optioneel.
4. Bevestigen.

### Onmiddellijk effect

- De membership gaat terug naar `active`.
- Veld `pending_removal_until` teruggezet op NULL.
- E-mail aan de persoon : « Het terugtrekkingsverzoek is geannuleerd. Je herwint je bevoegdheden. »
- E-mail aan de volledige coördinatie.
- Auditlog : `action='removal_cancelled'` met jouw `actor_user_id`.

### Politiek gezien

De annulering is bewust zeer eenvoudig te activeren. Het is een mechanisme van **collegiale herbalancering** : als een coordinator een terugtrekking in de hitte van het moment aanvroeg, kan elke andere coordinator de uitvoering opschorten terwijl het collectief beraadslaagt. Dit maakt terugtrekkingsverzoeken minder zwaar (geen onomkeerbaar drama) maar ook minder lichtzinnig (iedereen kan je tegenspreken). Dat is het voordeel van de wachttermijn.

### Technische kant

RPC : `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Onmiddellijke schorsing : de bewarende maatregel (T6 en T7)

De schorsing is een **ander instrument** dan het terugtrekkingsverzoek. Ze is **onmiddellijk**, zonder wachttermijn, en **zonder maximale duur**. Het is geen uitsluiting, het is een **pauze**.

### Wanneer gebruiken

Typegevallen voorzien door de spec :

- **Gecompromitteerd account** : er zijn redenen om te denken dat het wachtwoord van de persoon is uitgelekt. Men schorst in afwachting dat die persoon het wachtwoord wijzigt.
- **Gemeld urgent pestgedrag** : een lezer meldt misbruikend gedrag van een stafflid. Men schorst in afwachting van het collectieve onderzoek.
- **Manifeste misbruik** rechtstreeks waargenomen : men schorst totdat de coördinatie bijeenkomt.
- **Conflict in bemiddeling** : de persoon wordt vrijwillig op pauze gezet totdat de bemiddeling afgerond is.

### Procedure

1. Ga naar `/biblioteca`, tabblad **Equipe**.
2. Klik op de rij van de persoon op **« Schorsen »**.
3. Modal met een **verplicht veld « Reden van schorsing »** (minimaal 20 tekens). Deze reden zal leesbaar zijn in het auditlog voor al het actieve staffpersoneel.
4. Bevestigen.

### Onmiddellijk effect

- De membership gaat naar `suspended`.
- **Geen toegang** voor de persoon. De nominale rol blijft bewaard (die wordt nog steeds weergegeven als « geschorste `librarian` ») maar die kan niets meer doen.
- E-mail aan de betrokken persoon : urgent, met de reden, en — in het geval van een gecompromitteerd account — een uitnodiging om het wachtwoord te wijzigen.
- E-mail aan de volledige coördinatie.
- Auditlog : `action='suspended'` met jouw `actor_user_id` en het veld `reason`.

### Opheffing van de schorsing

Wanneer de situatie is opgelost (account opnieuw beveiligd, bemiddeling afgerond, onderzoek afgesloten, enz.) :

1. Tabblad **Equipe** → sectie **Lopende schorsingen en opzegtermijnen**.
2. Klik op de geschorste rij op **« Schorsing opheffen »**.
3. Eenvoudige modal. Reden optioneel maar aanbevolen om de episode politiek af te sluiten.
4. Bevestigen.

Effect : terugkeer naar `active`, e-mails, auditlog `action='unsuspended'`.

### Belangrijk : schorsing vs. terugtrekking

Het onderscheid is cruciaal :

| | Schorsing (T6) | Terugtrekking (T5) |
|---|---|---|
| Effect | Onmiddellijk | Uitgesteld (J+7) |
| Duur | Onbepaald | 7 dagen dan `inactive` |
| Omkeerbaar door | Expliciete opheffing | Annulering tijdens wachttermijn |
| Typisch gebruik | Bewarende maatregel | Uitsluitingsbeslissing |
| Onderliggende politiek | « We geven ons de tijd om te begrijpen » | « We hebben beslist dat deze persoon vertrekt » |

Het SIGB **weigert** een membership rechtstreeks van `suspended` naar `pending_removal` te laten gaan (de overgang is niet toegestaan door de matrix). Waarom : dit zijn twee politiek onderscheiden tijdshorizonten. Om van de ene naar de andere te gaan, moet men expliciet **de schorsing eerst opheffen** (terug naar `active`), en daarna de terugtrekking aanvragen (`pending_removal`). Deze dubbele stap is bewust : ze dwingt het collectief de overgang expliciet te bevestigen.

### Technische kant

RPC schorsen : `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC opheffen : `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Een andere `coordenador` terugzetten (T3 collectief)

Een enigszins bijzonder geval : wat te doen wanneer de coördinatie een `coordenador` wil **terugzetten** die zichzelf niet spontaan terugzet?

De governancespec behandelt dit geval als een **terugtrekkingsverzoek met wachttermijn** gericht op de `coordenador`-membership. Concreet gebruik je dezelfde procedure als in §6.3 (« Terugtrekking aanvragen »), maar je selecteert de rol `coordenador`. De persoon gaat naar `pending_removal` op zijn/haar/diens `coordenador`-membership ; op J+7 gaat die membership naar `inactive`. Als die persoon een parallelle `librarian`-membership had, blijft die actief (en « valt » de persoon terug als `librarian`). Anders wordt die opnieuw gewone `reader`.

Dit is bewust hetzelfde mechanisme als voor `librarian`s, met dezelfde beschermingen. **Geen enkele andere coordinator heeft een bijzondere macht** over zijn/haar/diens collega's : de procedure verloopt via de wachttermijn en de collegialiteit.

## 6.7. Verlaten account : automatisch vertrek (T9)

Het SIGB bevat een mechanisme van **automatisch vertrek** voor accounts die lange tijd geen verbinding hebben gehad.

### De drempel

Het SIGB kijkt naar het veld `last_sign_in_at` aan de kant van Supabase. Als een staffmembership een gebruiker heeft wiens laatste verbinding meer dan **9 maanden** geleden is, wordt het account geleidelijk beëindigd :

- **J-30 dagen** (8 maanden na de laatste verbinding) : waarschuwingsmail aan de persoon (« je membership wordt binnen 30 dagen gedeactiveerd zonder verbinding »).
- **J-7 dagen** : herinneringsmail.
- **J = 9 maanden** : automatisch overgezet naar `inactive`. Definitieve mail aan de persoon + aan de volledige coördinatie.

### Waarom deze regel

Dit is een compromis tussen twee vereisten :

- **Spookmemberships** niet eindeloos laten bestaan die de teams kunstmatig opblazen.
- Een persoon die gewoon even pauze had en van plan is terug te keren niet **bruusk wegjagen**.

Een eenvoudige verbinding volstaat om de teller te resetten. Geen actie nodig, gewoon inloggen.

### Bijzonder geval : de enige coordinator verlaat het account

Als de automatisch vertrekkende persoon de **enige actieve `coordenador`** van de biblio is, escaleert de cron naar een netwerkbeheerder **voor** de uitvoering van het vertrek. De netwerkbeheerder wordt per mail ingelicht, kan contact opnemen met de coördinatie (als er nog een fragment is) of met de `librarian`s van de biblio, en de transitie coördineren.

Politiek gezien is dit coherent met wat er gedaan wordt wanneer de enige coordinator zichzelf expliciet terugzet (§6.2) : het vertrek wordt niet geblokkeerd, maar het netwerk wordt gewaarschuwd zodat het kan helpen indien nodig.

## 6.8. Enkele randgevallen om te kennen

**Een persoon in `pending_removal` die onmiddellijk wil vertrekken.** Dat kan. Het volstaat zelf « Ik draag over » te gebruiken (zelf-terugtrekking T4). Effect : onmiddellijk overgaan naar `inactive`, de wachttermijn wordt kortgesloten. Politiek gezien is dit coherent : het recht P3 (zelf-terugtrekking) is onvoorwaardelijk.

**Een persoon in `suspended` die men definitief wil uitsluiten.** Zie §6.5 « Belangrijk : schorsing vs. terugtrekking ». Men moet de schorsing eerst opheffen, dan de terugtrekking aanvragen.

**Iemand vraagt de eigen terugtrekking via « Terugtrekking aanvragen ».** Het SIGB weigert met een expliciet bericht : « Gebruik de optie "Ik draag over" (zelf-terugtrekking) om het team te verlaten. » Dit is bewust : een persoonlijke beslissing verwarren met een collectieve beslissing zou de politieke semantiek vertroebelen.

**Poging om een netwerkbeheerder terug te zetten.** Systematisch geweigerd. De rol van netwerkbeheerder kan alleen worden gewijzigd via de specifieke mechanismen van de admin-reseau-spec (zie hoofdstuk 8). Geen enkele lokale coordinator kan een netwerkbeheerder afzetten.

## 6.9. Als de regel je hindert

**De wachttermijn van 7 dagen lijkt je te lang of te kort.** Voor te leggen in `spec-gouvernance-roles.md`, §4.4 en §5.6.

**Je vindt dat schorsing zonder maximale duur een deur opent naar willekeur.** Dit is een ernstig politiek vraagstuk. Men kan overwegen een termijn toe te voegen waarna een schorsing moet worden omgezet in een terugtrekking of opgeheven. Te bespreken in netwerkcoördinatie, daarna voor te leggen in de spec.

**Je vindt dat de verplichting een reden op te geven voor de schorsing overdreven bureaucratie is.** Of je vindt het minimum van 20 tekens te kort. Voor te leggen in de spec.

**Je vindt dat het automatisch vertrek na 9 maanden te snel of te traag is.** De drempel is configureerbaar, maar is vandaag voor alle biblio's in het netwerk hetzelfde. Moet hij per biblio configureerbaar worden? Te bespreken.

Zie hoofdstuk 4 en bijlage C voor de wijzigingsprocedure.

\newpage

# 7. Wanneer iets misgaat

Dit hoofdstuk behandelt **uitzonderlijke situaties**, daar waar de gewone bestuursmechanismen niet volstaan, of wel werken maar politiek inzicht vereisen. Het is ook het hoofdstuk waar we openlijk spreken over **bibliotheken zonder (of niet meer met) een deliberatief collectief leven**, omdat stilte hierover meer kwaad doet dan eerlijkheid.

## 7.1. Bibliotheek zonder AV of met weinig leden

Het geval komt vaker voor dan het lijkt. Een bibliotheek in oprichting, met twee of drie personen. Een bibliotheek waarvan het collectief in de loop der tijd geslonken is door vertrekken. Een bibliotheek waarvan de AV al een tijdje niet meer bijeenkomt, bij gebrek aan mensen of door ontmoediging.

Het SIGB bemoeit zich niet met het politieke leven van een collectief. Maar deze gids moet eerlijk zeggen wat er verandert wanneer dat collectieve leven zwak is.

### Wat er concreet verandert

**Het woord « coöptatie » wordt dubbelzinnig.** Met twee personen: wie coöpteert wie? Als de enige coordinator Voltairine in het team wil opnemen, beslist die « alleen » in politieke zin. Het SIGB zal het toestaan (een coordinator+ kan coöpteren), maar dit is niet langer de samenwerking van een politiek collectief, het is een persoonlijke beslissing in vermomming. Dat is noch goed noch slecht, het is simpelweg iets om te erkennen.

**Beraadslagingen zijn theoretisch.** Een verzoek tot uitschrijving met 7 dagen wachttijd, in een bibliotheek met 2 personen, heeft niemand anders om tegenin te gaan dan degene die het aangevraagd heeft. Het « collegiale vangnet » wordt een zelfreflectie.

**Het risico op personalisering neemt toe.** Wanneer een beslissing niet meer collectief is, hangt ze af van het karakter, de beschikbaarheid en de helderheid van één of twee personen. Dat is op zich niet catastrofaal, maar het is kwetsbaarder.

### Onze expliciete aanbevelingen

**1. Erken de situatie.** Doe niet alsof je een groot delibererend collectief bent als je met zijn tweeën bent. Politiek gezien is het gezonder om « beslissing alleen genomen, ter validering wanneer het collectief groter wordt » te schrijven in het veld « Reden » van het auditlogboek, dan « beslissing AV » te schrijven voor een AV die niet bestaat.

**2. Zoek dialoog buiten.** Als je alleen bent of met zijn tweeën, en er een belangrijke beslissing genomen moet worden (coöptatie, uitschrijving, schorsing), maak er dan een gewoonte van om dat te bespreken met medewerkers van andere bibliotheken in het netwerk, of met een netwerkbeheerder. Niet om hun toestemming te vragen — zij hoeven de interne beslissingen van jouw bibliotheek niet te valideren — maar om externe kritische terugkoppeling te krijgen. Het Matrix-netwerk van AnarBib is daar voor bedoeld.

**3. Geef de voorkeur aan omkeerbare overgangen.** Wanneer je collectief klein is, vermijd indien mogelijk onomkeerbare beslissingen. Een schorsing is omkeerbaar dan een uitschrijving. Een uitschrijving doorloopt 7 dagen gedurende welke je van gedachten kunt veranderen. Een coöptatie is annuleerbaar. Geef jezelf de tijd.

**4. Documenteer wat er gebeurt.** Het veld « Reden » van het auditlogboek is je beste vriend. Hoe meer context je erin stopt (« coöptatie van Voltairine, alleen beslist, ter validering op de volgende permanentie »), hoe meer de beslissing later contextualiseerbaar is, door jezelf en door een nieuw lid van het collectief.

**5. Als je echt geïsoleerd bent, vraag om hulp.** Een bibliotheek met één persoon is politiek in gevaar. Het SIGB detecteert dit op het moment dat de laatste coordinator zichzelf degradeert (§6.2) of de bibliotheek verlaat (§6.7), en waarschuwt de netwerkbeheerders. Je kunt ook zelf het initiatief nemen: stuur een mail naar de netwerkcoordinatie om de situatie uit te leggen. Verscheidene bibliotheken in het netwerk hebben stille periodes doorgemaakt en zijn geholpen om zich te herorganiseren.

### Wat de gids niet doet

Hij biedt **geen** speciale procedure voor kleine bibliotheken. Dat is bewust. De regels van het SIGB gelden uniform — wat verandert zijn de politieke omstandigheden waarin ze worden toegepast. Het erkennen van deze nuance maakt deel uit van de politieke rijpheid van een coordinator.

## 7.2. Interpersoonlijk conflict in een coordinatie

Er breekt een conflict uit tussen twee staffleden. Het werk verloopt niet meer goed, de sfeer verslechtert, lezers merken de spanning.

### Wat het SIGB kan doen

Niet veel, direct. Het SIGB bemiddelt geen conflicten. Maar het biedt **bruikbare hulpmiddelen**:

- **Tijdelijke schorsing (T6)** van een of beide personen, totdat het conflict bemiddeld is. Dit is wat de spec expliciet noemt als legitiem gebruiksgeval van de schorsing voor « conflict in bemiddeling ».
- **Zelf-degradatie (T3/T4)** — als een van de twee personen kiest om een stap terug te doen, is dat onmiddellijk.
- **Auditlogboek leesbaar door alle stafleden** — stelt het volledige personeel in staat te zien wie wat heeft gedaan, en manipulaties te vermijden door een coordinator die het conflict stilletjes wil oplossen door de ander er stil uit te werken.

### Wat het collectief moet doen

- **Bemiddeling**. Het SIGB bemiddelt niet. Er is een vertrouwde derde persoon nodig, buiten het conflict. Afhankelijk van de configuratie: een andere coordinator van de bibliotheek, een medewerker van een andere bibliotheek, een netwerkbeheerder.
- **Collectieve beslissing**. Als de bemiddeling leidt tot een beslissing (een van de twee personen verlaat de coordinatie, of er wordt een herzien werkkader vastgesteld), zal het SIGB deze beslissing uitvoeren via de normale RPCs.
- **Politieke trace**. Als de beslissing is om iemand te verwijderen, zou het veld « Reden » het bemiddelingsproces moeten vermelden (« verwijdering na bemiddeling op DD/MM, collectieve beslissing ») om de geschiedenis later niet te herschrijven.

### Wat vermeden moet worden

- **Een schorsing als wapen gebruiken** in het conflict. De schorsing is bedoeld om te pauzeren, niet om een machtstrijd te winnen. Als een coordinator de ander schorst zonder bemiddelingsproces, is dat zichtbaar in het auditlogboek, en dat is politiek problematisch.
- **De carentie omzeilen** via technische manoeuvres (schorsen en vervolgens via andere middelen « versnellen »). Alles is getraceerd, en het netwerk zal het merken.
- **Zwijgen over het auditlogboek**. Alle stafleden zien wat er gebeurt (P5). Als je het conflict probeert te verbergen, verraad je de transparantie van het collectief.

## 7.3. Gemeld intimidatiegedrag

Een lezer meldt dat een staflid zich intimiderend gedraagt (seksuele intimidatie, machtsmisbruik, racistisch gedrag, enz.).

### Aanbevolen aanpak

**1. De melding serieus nemen**, onmiddellijk, ook als de meldende persoon geïsoleerd is en ook als de gemelde persoon « bekend en gewaardeerd » is door de coordinatie. De reflex om de melding te verwerpen als « waarschijnlijk overdreven » is de meest voorkomende fout.

**2. Onmiddellijke schorsing (T6)** van de gemelde persoon, **als voorzorgsmaatregel**, in afwachting van het onderzoek. Het veld « Reden » zou iets moeten zeggen als « Voorzorgsschorsing na melding ontvangen op DD/MM, in afwachting van collectief onderzoek ». De schorsing is **geen** beschuldiging, het is een pauze.

**3. Een onderzoeksgroep samenstellen**. Buiten de software om. Minimaal: medewerkers buiten de directe machtspositie, in staat om beide kanten aan te horen zonder vooringenomenheid. Deze groep kan medewerkers van andere bibliotheken omvatten als de bibliotheek klein is of als alle coordinatoren bij de zaak betrokken zijn.

**4. Communiceren met de meldende persoon**. Die heeft behoefte aan de wetenschap dat dit serieus genomen wordt, en dat er maatregelen worden getroffen. Laat die persoon niet in onzekerheid.

**5. Tot een beslissing komen**. Afhankelijk van wat het onderzoek onthult:
   - Opheffing van de schorsing (T7) als de melding niet bevestigd wordt.
   - Definitieve verwijdering (T5 met carentie) als de melding bevestigd wordt en de beslissing is de persoon te verwijderen.
   - Tussenliggende sanctie (herzien werkkader, vorming, uitsluiting van bepaalde functies) als de situatie genuanceerder is.

**6. Politiek traceren**. Het veld « Reden » in het auditlogboek zou de collectieve beslissing moeten weerspiegelen. Geen details over het slachtoffer (AVG), maar een formulering die de beslissing leesbaar maakt.

### Wat niet gedaan moet worden

- **Rechtstreeks uitschrijving aanvragen** zonder voorafgaande schorsing, terwijl de situatie urgent is. Gedurende 7 dagen zou de gemelde persoon haar rechten behouden, wat tegenstrijdig is met de urgentie van een misbruikmelding.
- **Onbepaald schorsen zonder beslissing** onder het mom dat « men er niet uit komt ». Een schorsing die meerdere maanden duurt zonder beslissing wordt zelf geweld (tegenover de geschorste persoon, die zich niet kan verdedigen, en tegenover de meldende persoon, die geen antwoord krijgt).
- **Intern regelen zonder het netwerk**. Als je een kleine bibliotheek bent en de situatie je boven het hoofd groeit, vraag dan om hulp aan de netwerkbeheerders. Je staat er niet alleen voor.

## 7.4. Gecompromitteerd account

Een staflid ziet zijn of haar account gecompromitteerd (wachtwoord gelekt, vermoeden van ongeautoriseerde toegang).

### Onmiddellijke procedure

**1. Onmiddellijke schorsing (T6)** van het account, met expliciete reden: « Vermoeden van compromittering, wachtwoord waarschijnlijk gelekt, verificatie gaande ».

**2. Communicatie met de betrokken persoon**. Die ontvangt automatisch een urgente mail met de schorsing en de uitnodiging om het wachtwoord te wijzigen. De coordinator die schorst zou ook rechtstreeks contact moeten opnemen (telefoon, ander beveiligd kanaal) om te bevestigen.

**3. Snel onderzoek.** Wat is er gebeurd? Heeft het account ongebruikelijke acties uitgevoerd in het auditlogboek (vreemde coöptaties, configuratiewijzigingen, enz.)? Zo ja, onmiddellijk een netwerkbeheerder inlichten om te helpen analyseren.

**4. Opheffing van de schorsing (T7)** zodra:
   - Het wachtwoord gewijzigd is.
   - De eventuele schade vastgesteld en hersteld is (annulering van misbruikacties, herstel van gegevens, enz.).
   - De persoon digitaal veilig is.

### Politiek gezien

Een schorsing wegens gecompromitteerd account **is geen blaam**. Het is wederzijdse bescherming: we beschermen de persoon (door te verhinderen dat die door een aanvaller gebruikt wordt) en de bibliotheek (door te verhinderen dat er in haar naam schade wordt aangericht). De mail aan de persoon zou het **niet-disciplinaire** karakter moeten benadrukken.

## 7.5. Bibliotheek zonder actieve coordinator of `librarian`

Het rampenscenario: geen enkel actief staflid meer. Dit kan gebeuren door gecumuleerde automatische uitschrijving (alle stafleden hebben tegelijkertijd hun account verlaten), door collectief ontslag (zeldzaam maar mogelijk), of door een reeks verwijderingen.

### Gevolgen

- De bibliotheek blijft **technisch actief** (de zichtbaarheid, de catalogus blijven toegankelijk volgens de gewone RLS).
- Maar **geen beheersactie** kan meer via de normale UI worden uitgevoerd: geen validering van inschrijvingen, geen beheer van uitleningen, geen wijziging van de configuratie.
- **Urgente mail aan de netwerkbeheerders** van de cron die de situatie detecteert.

### Herstartprocedure

Buiten de spec, maar dit is de praktijk:

**1. Contact opnemen** door een netwerkbeheerder met het lokale collectief, via alle beschikbare kanalen (het of de lezeraccounts die nog ingeschreven zijn, de externe contactgegevens van de bibliotheek indien beschikbaar, het lokale kennisnetwerk).

**2. Politieke verificatie**: bestaat het collectief nog? Wil het blijven bestaan? Als er leden zijn die gewoon de technische functies hebben laten varen, kan nieuw personeel buiten de workflow gecoöpteerd worden.

**3. Coöptatie buiten de workflow** door de netwerkbeheerder, via directe SQL of via de UI (een netwerkbeheerder heeft het recht om op te treden als coordinator+ van welke bibliotheek dan ook, cf. hoofdstuk 2). De coöptatie buiten de workflow moet worden getraceerd in het auditlogboek met een expliciete reden: « Hervatting coordinatie na vacature, na contact met het collectief op DD/MM, door netwerkbeheerder X ». En — een sleutelpunt van de doctrine — **voorafgaande informatie aan de lokale coordinatie is verplicht**, tenzij de bibliotheek helemaal geen levend staflid meer heeft, in welk geval de informatie via de resterende actieve `reader`s loopt (cf. §7.6).

**4. Als het collectief niet meer bestaat**: opening van een discussie over de **correcte sluiting** van de bibliotheek. Welke gegevens bewaren, welke verwijderen, hoe te communiceren met de lezers, enz. Dit is een workflow die apart geformaliseerd moet worden.

## 7.6. De interventie van een netwerkbeheerder in een lokale bibliotheek

Een geval dat al in hoofdstuk 2 aan bod komt, maar dat een praktische uitwerking verdient in dit hoofdstuk over uitzonderlijke situaties.

### De netwerkleer

> **Een interventie van een netwerkbeheerder in een lokale bibliotheek moet worden voorafgegaan door informatie aan de betrokken lokale coordinatie, behalve in geval van vitale urgentie.**

De voorafgaande informatie **is geen verzoek om toestemming**. De netwerkbeheerder heeft het recht te handelen (dat is de betekenis van het transversale recht). Maar het is een blijk van respect voor de lokale autonomie, en het bewaart de mogelijkheid van een andere regeling.

### Wat « vitale urgentie » is

Dit is bewust restrictief. Typische gevallen:

- **Actieve compromittering**: een lopende actie bedreigt de integriteit van de bibliotheek of het netwerk (aanvallend account dat in realtime lidmaatschappen wijzigt, enz.).
- **Lopend intimidatiegedrag**: een staflid misbruikt actief zijn of haar functies, het gevaar voor de lezers is onmiddellijk.
- **Aanval op het platform**: poging tot inbraak, exfiltratie van gegevens, enz.

Buiten deze gevallen **neemt men de tijd om te informeren**.

### Hoe te informeren

Vóór de interventie (of tijdens, als de urgentie dat achteraf rechtvaardigt):

- **Mail aan de lokale coordinatie** die uitlegt wat er gedaan gaat worden, waarom, en met welke traceerbaarheid.
- **Vermelding in de tabel `cross_library_actions_log`** met een criticiteitsniveau dat de aard van de actie aangeeft. Alle actieve coordinatoren van de bibliotheek ontvangen een melding.
- **Beschikbaarheid voor dialoog**: de lokale coordinatie moet vragen kunnen stellen, verduidelijking kunnen vragen, of zelfs kunnen onderhandelen over een andere regeling (« laat ons het eerst proberen »).

### Wat vermeden moet worden

- **Stille interventie**: handelen in de bibliotheek zonder de coordinatie te informeren. Zelfs als het technisch getraceerd is, is het politiek een schending van de lokale soevereiniteit.
- **Het gebruik van het transversale recht als surveillance-macht**: gaan kijken « wat er gaande is » in een bibliotheek zonder operationele reden. Het transversale recht bestaat voor gevallen van onderhoud of bemiddeling, niet voor nieuwsgierigheid.
- **Het opleggen van politieke beslissingen**: een netwerkbeheerder kan een bibliotheek niet vertellen hoe zij haar coöptaties moet doen, hoe zij haar interne conflicten moet beheren, of welk ontvangstbeleid zij moet kiezen. Het transversale recht is technisch, niet politiek.

## 7.7. Als de regel je hindert

**Je vindt dat de doctrine van voorafgaande informatie te soepel is** (een netwerkbeheerder zou de « vitale urgentie » kunnen misbruiken). Te bespreken: is een striktere definitie van urgentie nodig? Is een tweede netwerkbeheerder nodig die de urgentie bevestigt?

**Je vindt de doctrine te strikt** (soms moet je snel handelen zonder alles uit te leggen). Te bespreken: moeten er meerdere niveaus van interventie worden onderscheiden, met verschillende informatieregels naargelang de criticiteit?

**Je vindt dat het stilzwijgen over de correcte sluiting van een bibliotheek problematisch is** (§7.5). Je hebt gelijk. Een aparte spec moet waarschijnlijk geschreven worden. Aan het netwerk voor te leggen.

**Je vindt dat dit hoofdstuk te veel ruimte laat voor improvisatie** in gevallen van intimidatie (§7.3). Dat klopt waarschijnlijk. Een aparte spec over bemiddelings- en onderzoeksprocessen zou nuttig kunnen zijn. Aan het netwerk voor te leggen.

Zie hoofdstuk 4 en bijlage C.

\newpage

# 8. De rol van netwerkbeheerder

Dit hoofdstuk richt zich specifiek tot netwerkbeheerders (huidige en toekomstige), en tot lokale coördinaties die willen begrijpen hoe het netwerk zich op een hoger niveau zelf organiseert. Het vormt een aanvulling op en verdieping van de hoofdstukken 2 en 7.

## 8.1. Een afzonderlijke politieke functie

Allereerst: **netwerkbeheerder** zijn is geen rang, geen erkenning en geen titel. Het is een **transversale functie** die het collectief van netwerkbeheerders delegeert aan bepaalde leden, op basis van unanimiteit van de reeds aanwezige beheerders, en die op elk moment verlaten kan worden.

Het politieke doel van de functie is **de inter-bibliotheekcoördinatie levend houden**: nieuwe bibliotheken verwelkomen die bij het netwerk aansluiten, discussies begeleiden over technische en politieke ontwikkelingen van het SIGB, het platform technisch onderhouden, ingrijpen wanneer een bibliotheek vastloopt. Dit is geen directiefunctie. Het is een animatie- en dienstverleningsfunctie.

### Wat een netwerkbeheerder (politiek) kan doen

- Een nieuwe bibliotheek activeren die een aanvraag heeft ingediend om bij het netwerk te komen.
- Inter-bibliotheekdiscussies begeleiden (het Matrix-kanaal `#anarbib`, bijeenkomsten, interne mailinglijsten).
- De evoluties van het platform coördineren (specs, releases, communicaties).
- Op elke bibliotheek ingrijpen bij technische blokkades (transversaal recht).
- Bemiddelen tussen twee bibliotheken bij conflicten (als de coördinaties dat wensen).
- Een voorstel doen of stemmen over de coöptatie en collectief ontslag van andere netwerkbeheerders.

### Wat een netwerkbeheerder (politiek) niet kan doen

- Een bibliotheek aansturen.
- Een politieke beslissing opleggen aan een bibliotheek (ontvangstbeleid, validatiemethode, interne coöptaties, enz.).
- Een lokale coordinator wegsturen tegen de wil van diens bibliotheek.
- Alleen de regels van het netwerk wijzigen (dit vereist een collectieve discussie van de beheerders en idealiter van de coördinaties).

## 8.2. Coöptatie bij unanimiteit: waarom

De netwerkbeheerder wordt niet bij meerderheid toegevoegd, maar bij **unanimiteit** van de zittende beheerders. Deze regel kan verrassen — waarom niet een gewone meerderheid, een gekwalificeerde meerderheid of een quorum?

De politieke reden is eenvoudig: de macht van een netwerkbeheerder is **transversaal**. Die kan op elke bibliotheek ingrijpen. Daarom moet **elke actief zittende netwerkbeheerder** bereid zijn om met de nieuwe persoon samen te werken. Als er één diep meningsverschil is, wordt de samenwerking vergiftigd — beter om dat dan niet op te leggen.

Deze regel heeft een belangrijke praktische consequentie: **het veto is gemakkelijk**. Één enkel `opposed`-stem volstaat. Dat is opzettelijk. Men verkiest dat een coöptatie niet slaagt, boven een situatie waarbij een bestaande beheerder duurzaam in een lastige positie blijft.

## 8.3. Coöptatiewerkstroom, in detail

### Stap 1 — Voorstel

Een actieve netwerkbeheerder klikt via de interface `/rede/administradores` (te verschijnen in pakket D) op **« Een coöptatie voorstellen »**.

- Voert de identiteit in van de voorgestelde persoon (zoekt in de AnarBib-gebruikersdatabank).
- Voert een verplichte **motivatie** in van **minimaal 20 tekens**. Deze motivatie is leesbaar voor alle beheerders, en zal — bij succes — worden opgenomen in de kennisgeving aan de gecoöpteerde persoon.
- Bevestigt.

Het SIGB:
- Maakt een rij aan in `network_administrator_cooptation_proposals` met `status='open'`, `expires_at = now() + 30 dagen`.
- Registreert automatisch de `favorable`-stem van de indiener.
- Stuurt een militante e-mail naar alle andere actieve beheerders om hen uit te nodigen te stemmen.

### Stap 2 — Stemmen

Elke andere actieve beheerder heeft 30 dagen om te stemmen. Drie opties:

- **`favorable`**: die accepteert de coöptatie.
- **`opposed`**: die legt een veto. **Verplichte rationale** van minimaal 20 tekens. Deze rationale wordt bij afwijzing meegedeeld aan de voorgestelde persoon en aan de indiener.
- **`abstain`**: die onthoudt zich. **Onthouding blokkeert**: het voorstel slaagt alleen bij unanimiteit van `favorable`-stemmen. Een niet-ingetrokken onthouding heeft praktisch hetzelfde effect als een veto, behalve dat die later omgezet kan worden in `favorable` als de persoon van gedachten verandert.

### Detail v0.3 — Bekendmaking van identiteit

Een optie **« Mijn identiteit bekendmaken bij afwijzing »** is standaard aangevinkt. Als u `opposed` stemt, zal uw identiteit worden meegedeeld aan de voorgestelde persoon en aan de indiener, naast uw rationale.

U kunt deze optie **uitvinken** om anoniem te blijven. In dat geval wordt de rationale doorgegeven zonder uw naam (« een tegenstander heeft aangevoerd: ... »).

Politiek gezien beantwoordt **transparantie als standaard** aan de militante cultuur van het innemen van standpunten. Maar anonimiteit blijft mogelijk voor gevallen waarin een oppositie de tegenstander aan onevenredige persoonlijke kosten zou blootstellen.

### Automatische herinneringen

De cron stuurt herinneringen naar beheerders die nog niet gestemd hebben:
- **Dag +14**: « Je hebt nog niet gestemd over de coöptatie van X. »
- **Dag +25**: « Dit voorstel verloopt over 5 dagen, neem een standpunt in. »

### Stap 3 — Afsluiting

**Als iemand `opposed` stemt**: het voorstel gaat onmiddellijk naar `status='rejected'`. De voorgestelde persoon en de indiener ontvangen een e-mail met uitleg over de afwijzing, inclusief de rationale (en de identiteit van de tegenstander als die instemde met bekendmaking).

**Als alle actieve beheerders `favorable` hebben gestemd**: het voorstel gaat naar `status='completed'`. Er wordt automatisch een rij ingevoegd in `network_administrators` met `status='active'` en `coopted_by_unanimity_of = ARRAY[<lijst van stemgerechtigden>]`. De persoon ontvangt een welkomstmail en een samenvatting wordt verstuurd aan alle beheerders.

**Als 30 dagen verstrijken zonder dat men een consensus bereikt**: het voorstel gaat naar `status='expired'`. Geen coöptatie. Men moet ofwel een nieuw voorstel beginnen, ofwel vaststellen dat het netwerk momenteel niet klaar is om deze persoon op te nemen.

## 8.4. Collectief ontslag bij unanimiteit

Het **collectief ontslag** is de spiegel van de coöptatie: om een netwerkbeheerder tegen diens wil te ontslaan, is de unanimiteit van de andere actieve beheerders vereist.

### Werkstroom

1. **Ontslagvoorstel** door een actieve netwerkbeheerder, verplichte motivatie ≥ 20 tekens.
2. **Stemmen** van de andere beheerders (favorable / opposed / abstain), met rationales bij `opposed`.
3. **Bij unanimiteit `favorable`**: het lidmaatschap van de beoogde persoon gaat naar `pending_removal`, met `pending_collective_removal_until = now() + 7 dagen`.
4. **Gedurende de 7 dagen wachttijd**: de beoogde persoon behoudt diens operationele rechten, maar ontvangt een duidelijke e-mail over het geplande vertrek. Die kan eventueel een laatste discussie aangaan. **Die kan het ontslag niet eenzijdig annuleren**: alleen de unanimiteit van de andere beheerders kan terugkomen op de beslissing (door een « annulering van ontslag » voor te stellen, een spiegelwerkstroom).
5. **Op dag +7**: overgang naar `status='removed'`, `removed_at=now()`.

### Politiek gezien

Het **dubbele slot** (unanimiteit + wachttijd van 7 dagen) maakt het collectief ontslag van een netwerkbeheerder bijzonder moeilijk. Dat is opzettelijk. De macht van een netwerkbeheerder is transversaal — die wordt niet lichtvaardig ingetrokken.

Omgekeerd **blijft zelf-ontslag altijd mogelijk en eenvoudig** (zie §8.5). Dit is de politieke asymmetrie: vertrekken is eenvoudig, weggestuurd worden is moeilijk. Dit beantwoordt aan de anarchistische cultuur: men respecteert de persoonlijke beslissing om een functie te verlaten, en omkadering stelt men in voor de collectieve beslissing om die te beëindigen.

## 8.5. Zelf-ontslag

Een netwerkbeheerder kan diens functie op elk moment verlaten, zonder instemming van de anderen. Het is een **unilaterale en onvoorwaardelijke** handeling (P3 toegepast op netwerkniveau).

### Procedure

Via `/rede/administradores`, op de eigen rij, klikken op **« Mijn netwerkbeheerderfunctie verlaten »**. Bevestigingsmodaal, optionele reden.

### Effect

- De rij gaat naar `status='inactive'` (of `removed` afhankelijk van de context, te verduidelijken in pakket D).
- E-mail naar alle andere actieve beheerders.
- Auditlog `event_type='self_removal_requested'`.

### Speciaal geval: de enige actieve beheerder

Als u de enige actieve beheerder bent en u wilt vertrekken, activeert het SIGB een **speciale wachttijd van 30 dagen**. Gedurende deze periode:
- Blijft u actieve beheerder met alle rechten.
- Wordt een dringende e-mail gestuurd aan alle voormalige beheerders (`status='inactive'` of `removed`) om hen op de hoogte te stellen van de situatie.
- Heeft het netwerk 30 dagen om ofwel een nieuwe beheerder te coöpteren (normale coöptatiewerkstroom, waarbij u de enige stemgerechtigde bent), ofwel een andere overgang te organiseren.

Op dag +30, als er niets ondernomen is, vertrekt u effectief en bevindt het netwerk zich **zonder actieve beheerder**. Het SIGB blijft technisch functioneren, maar geen enkele beheerderhandeling (activering van bibliotheek, coöptatie, enz.) is meer mogelijk tot manuele tussenkomst.

Deze procedure is ontworpen om de ontbinding van het netwerk te **vertragen** mochten de laatste beheerder vertrekken, zonder dat vertrek echter te **verhinderen**. De vrijheid om te vertrekken blijft volledig.

## 8.6. Het transversale recht in de dagelijkse praktijk

Het **transversale recht** is wat de netwerkbeheerder politiek onderscheidt van het lokale personeel: die kan handelen als `coord+` op elke bibliotheek, diens catalogus lezen (ook als de zichtbaarheid `private` is), diens lidmaatschappen wijzigen, enz.

### Wanneer het te gebruiken

- **Activering van een nieuwe bibliotheek**: normale werkstroom, dit is het primaire gebruiksscenario van het transversale recht.
- **Onderhoud**: een bibliotheek heeft een kapotte configuratie, een verkeerd ingestelde parameter, een blokkerende bug. U kunt ingrijpen om dit te corrigeren.
- **Politieke blokkade**: de bibliotheek heeft geen coordinator meer (zie §7.5), men moet opnieuw coöpteren om te herstarten.
- **Bemiddeling op verzoek**: de lokale coördinatie doet expliciet een beroep op u om te helpen bij het arbitreren van een conflict of het nemen van een moeilijke beslissing.
- **Onderzoek na een netwerkmelding**: een lezer meldt een groot probleem in een bibliotheek, en de lokale coördinatie reageert niet of maakt zelf deel uit van het probleem.

### Wanneer het niet te gebruiken

- **Uit nieuwsgierigheid**: niet « gaan kijken wat er gaande is » in een bibliotheek zonder operationele reden. Dat is surveillance, geen beheer.
- **Om een politieke beslissing op te leggen**: als u het niet eens bent met het beleid van een bibliotheek (validatiemethode, reglement, enz.), kunt u daarover discussiëren, maar niet opleggen.
- **Om een collectief debat te omzeilen**: als het netwerk een evolutie bespreekt en u het er niet mee eens bent, kunt u uw transversale recht niet gebruiken om uw standpunt via een voldongen feit op te leggen.

### Verplichte voorafgaande informatie

Dit is de netwerkleer (hoofdstuk 2, §2.4; hoofdstuk 7, §7.6): **elke interventie van een netwerkbeheerder op een lokale bibliotheek moet worden voorafgegaan door een informatieverstrekking aan de lokale coördinatie**, behalve in geval van vitale urgentie.

Concreet:
- **E-mail aan de lokale coördinatie** met uitleg over wat er gedaan zal worden en waarom.
- **Wachten op een antwoord** behalve bij urgentie: 24 tot 72 uur afhankelijk van de aard van de handeling.
- **Als er geen antwoord is en de handeling niet urgent is**: één keer opvolgen, en doorgaan met explicitering in het log dat de lokale coördinatie werd geïnformeerd maar niet reageerde.
- **Bij vitale urgentie**: handelen, en de informatie onmiddellijk daarna versturen met uitleg waarom de urgentie de handeling zonder wachten rechtvaardigde.

Elke handeling wordt bijgehouden in `cross_library_actions_log` met kriticiteitsniveau, leesbaar door de lokale coördinatie achteraf.

## 8.7. Het geval van de eerste beheerder en Xavier

Het systeem veronderstelt minstens één actieve netwerkbeheerder opdat coöptatie mogelijk is. De **eerste beheerder** kan niet gecoöpteerd worden (er is niemand om te stemmen), waarvoor een uitzondering is voorzien.

Op 11 mei 2026 is **Xavier** ingeschreven als **stichtend netwerkbeheerder** via directe INSERT in `network_administrators`, met `coopted_by_unanimity_of = ARRAY[]::uuid[]` (lege tabel) en `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. Deze handeling is bijgehouden in het auditlog met `event_type='foundational_admin_added'` en `metadata.foundational=true`.

Deze handeling is **politiek transparant**: ze is gedocumenteerd, uitgelegd en openbaar. Ze is geen zwakte van het systeem — ze is de onmisbare aanloop. Eenmaal deze basis gelegd, verloopt elke latere coöptatie via de normale werkstroom van §8.3.

Naarmate nieuwe beheerders gecoöpteerd worden, zal de initiële « eenzaamheid » vervagen. Het netwerk streeft ernaar **meerdere actieve beheerders** te hebben (het politieke doel is doorgaans een kring van 3 tot 5 personen, bij voorkeur een oneven aantal om blokkades te vermijden bij stemmen over bepaalde aanverwante onderwerpen buiten de spec).

## 8.8. Als de regel u stoort

**U vindt unanimiteit te veeleisend** (« we slagen er nooit in te coöpteren, een veto blokkeert alles »). Dit is een fundamenteel debat over de aard van het collectief van netwerkbeheerders. Moet men versoepelen naar een gekwalificeerde meerderheid? Moet er een her-stemmingsmechanisme zijn? Ter bespreking in het netwerk, en mogelijk te formaliseren in een herziening van de spec.

**U vindt unanimiteit te laks** (« men zou ook de lokale coördinaties moeten raadplegen vóór de coöptatie van een beheerder »). Dit is een andere politieke optie: de lokale coördinaties raadplegen vóór de coöptatie van een netwerkbeheerder. Ter bespreking. Dit zou de beslissende kring vergroten maar de procedure verzwaren.

**U vindt de wachttijd van 7 dagen voor collectief ontslag te lang of te kort.** Ter bespreking in de spec.

**U vindt de leer van voorafgaande informatie onvoldoende omgekaderd**: wat is precies een « vitale urgentie »? Moet er een canonieke definitie zijn? Ter bespreking.

**U vindt dat de netwerkbeheerderfunctie te veel macht heeft** (transversaal recht te uitgebreid) of te weinig (zou bepaalde conflicten moeten kunnen beslechten). Dit is een fundamentele politieke vraag. Ter bespreking tijdens de jaarlijkse bijeenkomst.

Zie hoofdstuk 4 en bijlage C.

\newpage

# 9. Transparantie in de praktijk

Dit hoofdstuk behandelt de concrete werking van **transparantie** in AnarBib: wie ziet wat, hoe, en waarom. Dit is de toepassing van principe P5 (maximale transparantie) en P6 (systematische meldingen).

## 9.1. Het principe

> **P5 — Maximale transparantie.** Het auditlog van rolwijzigingen is leesbaar door al het actieve personeel van de bibliotheek.
> **P6 — Systematische meldingen.** Elke rolwijziging triggert een e-mail aan de betrokken persoon en aan de gehele coördinatie.

Het politieke idee: **ondoorzichtige manipulaties onmogelijk maken**. Als alles bijgehouden en leesbaar is, kan men niet stilletjes iemand van de ene naar de andere status overzetten zonder dat andere personeelsleden dat zien.

## 9.2. Wie ziet wat: matrix

### Op bibliotheeksniveau

| Informatie | reader | librarian | coordenador | Netwerkbeheerder |
|---|---|---|---|---|
| Lijst van het team (actieve rollen) | gedeeltelijk (alleen openbare namen) | volledig | volledig | volledig |
| Statussen (`suspended`, `pending_removal`) | nee | ja | ja | ja |
| Volledig auditlog van het team | nee | ja | ja | ja |
| Auditlog: redenen van handelingen | nee | ja | ja | ja |
| Lopend ontslagverzoek: wie heeft gevraagd | nee | ja | ja | ja |
| Persoonsgegevens van andere lezers | nee | ja (van deze bibliotheek) | ja | ja |

### Op netwerkniveau

| Informatie | reader | Bibliotheekpersoneel | Netwerkbeheerder |
|---|---|---|---|
| Lijst van actieve netwerkbeheerders | ja (openbare pagina `/rede`) | ja | ja |
| Netwerktellers (aantal bibliotheken, enz.) | ja | ja | ja |
| Netwerkauditlog (coöptaties, ontslagen van beheerders) | nee | nee | ja |
| Lopende coöptatievoorstellen | nee | nee | ja |
| Cross-bibliotheeklogs (netwerkbeheerderhandelingen op bibliotheek X) | nee | ja (van hun bibliotheek) | ja |

## 9.3. Het teamauditlog in de praktijk

Dit is het belangrijkste transparantiemiddel. Het is raadpleegbaar via `/biblioteca` → tabblad **Team** → sectie **Teamgeschiedenis**.

### Wat men erin ziet

Elke vermelding toont:
- Datum en tijd.
- Handeling (« bevorderd tot librarian », « zelf teruggetreden », « ontslag aangevraagd », « geschorst », « heringetreden na schorsing », « automatische overgang naar inactief na 9 maanden », enz.).
- Betrokken persoon (target).
- Uitvoerder van de handeling (actor) — voor menselijke handelingen. Leeg voor automatische handelingen (cron).
- Reden (indien ingevuld).
- Rol en statussen voor/na.

### Waartoe dit politiek dient

- **Collectief geheugen**: men kan de geschiedenis van de coördinatie reconstrueren, zien hoe ze is samengesteld en geëvolueerd.
- **Bescherming tegen ondoorzichtigheid**: als een coordinator dubieuze handelingen heeft gesteld (vreemde coöptaties, ongerechtvaardigde schorsingen), is dat zichtbaar voor iedereen.
- **Deliberatie-instrument**: bij debat (« we hadden gezegd dat we de coördinators zouden laten rouleren! ») geeft het log feitelijke elementen.
- **Overgangsinstument**: wanneer een nieuwe coordinator aankomt, kan die het log lezen om de recente geschiedenis te begrijpen zonder iedereen te moeten ondervragen.

### Wat men ermee moet doen

- **Regelmatig lezen**. Niet elke dag, maar eens per maand, bijvoorbeeld tijdens een coördinatievergadering.
- **Bespreken wat vreemd is**. Als een handeling u onbegrijpelijk of onredelijk lijkt, vraag dan uitleg aan de uitvoerder.
- **Niet als wapen gebruiken**. Het log is een instrument van collectieve transparantie, geen middel tot interpersoonlijke surveillance.

## 9.4. De kennisgevings-e-mails

Elke bestuurshandeling triggert **een of meerdere** automatische e-mails. Dit is geen spam: het is opzettelijk, omdat niemand door een rolwijziging getroffen mag worden zonder ervan op de hoogte te zijn.

### Wie ontvangt wat

| Gebeurtenis | Betrokken persoon | Actieve lokale coördinatoren | Netwerkbeheerders |
|---|---|---|---|
| Coöptatie (T1, T2) | ✅ | ✅ | — |
| Zelf-degradatie (T3, T4) | ✅ bevestiging | ✅ | — |
| Ontslagverzoek (T5) | ✅ | ✅ | — |
| Annulering verzoek (T8) | ✅ | ✅ | — |
| Einde wachttijd (Dag+7) | ✅ | ✅ | — |
| Schorsing (T6) | ✅ urgent | ✅ | — |
| Opheffing schorsing (T7) | ✅ | ✅ | — |
| Automatisch vertrek na 9 maanden (T9) | ✅ herinneringen + finaal | ✅ (alleen finaal) | — |
| Laatste coordinator vertrekt | ✅ | ✅ (de betrokkene) | ✅ waarschuwing |
| Coöptatie netwerkbeheerder (voorstel) | — | — | ✅ |
| Coöptatie netwerkbeheerder (succes) | ✅ welkom | — | ✅ samenvatting |
| Coöptatie netwerkbeheerder (afwijzing) | ✅ met rationale | — | ✅ |
| Collectief ontslag netwerkbeheerder | ✅ | — | ✅ |
| Cross-bibliotheekinterventie | — | ✅ (coördinatoren van de bibliotheek) | ✅ (de uitvoerder) |

### De toon van de e-mails

De bestuurs-e-mails volgen de militante conventies van het netwerk (zie intern geheugen): soberheid, duidelijkheid, toegankelijkheid (gemeenschappelijke taal zonder jargon), inclusieve formulering en onthiërarchiseerd schrijven. Geen officiële formules, geen bureaucratische ondertekeningen.

Voorbeeldtype voor een ontslagverzoek:
> Hoi Karl,
>
> De coördinatie van de BLMF heeft je ontslag uit het team aangevraagd (rol: librarian), naar aanleiding van: « beslissing AV van 04/05 ».
>
> Dit opzegtermijn treedt in werking op **12 mei 2026** (over 7 dagen), tenzij een andere coordinator dit annuleert vóór die datum.
>
> Gedurende deze periode heb je geen toegang meer tot de librarian-functies. Voor elke discussie, neem contact op met de coördinatie van de BLMF — deze beslissing maakt deel uit van het organisch leven van het lokale collectief en wordt niet beheerd via het SIGB.
>
> AnarBib

De toon beoogt feitelijk te informeren zonder te dramatiseren of te minimaliseren.

### Vertrouwelijkheid van e-mails — anti-trackingbescherming

De bestuurs-e-mails, zoals alle meldingen van het SIGB, worden verstuurd via **Resend**, de verzendingsonderaannemer van het netwerk (zie verwerkingsregister en DPA). Twee politieke garanties kaderen deze verzending:

- **Geen tracking.** Het opvolgen van openingen en klikken — dat het IP-adres, de locatie, het apparaat en de e-mailclient van de bestemmeling zou verzamelen — is een optie die **uitgeschakeld** is op de AnarBib-instantie. Een bestuurs-e-mail ontvangen laat geen technische sporen na aan de kant van het netwerk.
- **Minimalisering.** Alleen de strikt noodzakelijke gegevens voor de verzending worden doorgegeven (e-mailadres, voornaam voor personalisering, inhoud van de melding). Geen gevoelige gegevens worden doorgegeven.

Deze bescherming is doctrinair: ze verlengt de non-trackingverbintenis van het netwerk tot in de e-maillaag. Ze is gedocumenteerd in het verwerkingsregister (art. 30 AVG) en in de DPA; elke wijziging van e-mailonderaannemer wordt gemeld aan de aangesloten bibliotheken (DPA art. 5.4).

## 9.5. Het geval van « cross-bibliotheek »-meldingen

Wanneer een netwerkbeheerder op een bibliotheek ingrijpt (zie §8.6), worden twee meldingen geproduceerd:

- **Voorafgaande melding** (manueel): de beheerder stuurt een e-mail aan de lokale coördinatie vóór te handelen. Vrij formaat.
- **Automatische melding** (door het SIGB): bij de uitvoering van de handeling schrijft het systeem in `cross_library_actions_log` met kriticiteitsniveau, en stuurt een e-mail aan de actieve coördinatoren van de betrokken bibliotheek.

Deze dubbele melding (manueel + automatisch) garandeert dat de lokale coördinatie **politiek** vooraf en **technisch** achteraf wordt ingelicht. De technische spoor is achteraf leesbaar in het tabblad **Team** → sectie **Netwerkinterventies** (te verschijnen in pakket D).

## 9.6. Grenzen van de transparantie

De transparantie van AnarBib heeft grenzen die men dient te expliciteren:

**`reader`s zien het teamauditlog niet.** Dat is opzettelijk (P5 spreekt van « actief personeel »). `reader`s zien niet wie wie heeft gecoöpteerd, wie geschorst is, enz. Transparantie speelt **binnen de coördinatie**, niet naar de gebruikers.

**Een bibliotheek ziet het auditlog van een andere bibliotheek niet.** Lokale soevereiniteit (P7). Rolwijzigingen in bibliotheek A zijn strikt ondoorzichtig voor bibliotheek B, behalve via het menselijke kanaal (discussie tussen coördinatoren van de twee bibliotheken).

**Het netwerkauditlog (coöptaties en ontslagen van beheerders) is niet openbaar.** Alleen leesbaar door netwerkbeheerders. Een lokale bibliotheek kan de lijst van huidige netwerkbeheerders zien (pagina `/rede`), maar niet de geschiedenis van coöptaties noch de rationales van tegenstemmen.

Deze grenzen zijn geen hypocrisie. Ze beantwoorden aan een evenwicht tussen **transparantie** (binnen het delibererende personeel) en **vertrouwelijkheid** (ten opzichte van gebruikers en tussen perimeters). Als u het evenwicht slecht geplaatst vindt, is dit amendeerbaar (hoofdstuk 4).

## 9.7. Als de regel u stoort

**U denkt dat `reader`s het teamauditlog zouden moeten zien** (radicale transparantie naar de gebruikers). Dit is een verdedigbaar standpunt, maar het heeft consequenties (interne conflicten worden openbaar, het politieke leven van het collectief wordt blootgesteld). Ter bespreking in het netwerk.

**U denkt omgekeerd dat het auditlog te zichtbaar is** (een discrete librarian zou niet de handelingen van de coördinatoren moeten kunnen « bespioneren »). Dat is ook verdedigbaar. Maar dit is in tegenspraak met P5. Ter bespreking.

**U vindt de e-mails te talrijk of onvoldoende expliciet.** De inhoud is geconfigureerd in `mail-strings.ts` × 10 locales. Elke wijziging van een e-mail is amendeerbaar als een codewijziging. Ter bespreking met de developers.

**U denkt dat het netwerkauditlog minstens openbaar zou moeten zijn voor de lokale coördinatoren** (zodat die kunnen zien wie wat beslist op netwerkniveau). Dit is een interessante optie. Ter bespreking.

Zie hoofdstuk 4 en bijlage C.

\newpage

# 10. Concrete uitgewerkte voorbeelden

Tot slot zes volledige scenario's. Elk illustreert een combinatie van mechanismen en laat het SIGB in de praktijk zien. De namen (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) zijn die van historische kameraden uit het libertaire denken; ze dienen hier als fictieve typegevallen.

## 10.1. Voltairine wordt coöpteerd als librarian

> **Context.** Emma is coordinator bij de BLMF. Voltairine komt al acht maanden naar de permanenties, neemt deel aan het leven van de bib en heeft duidelijk het profiel om in het team te stappen. Het lokale collectief heeft dit in een AV op 4 mei besproken en de coöptatie bekrachtigd.

**Procedure.**

1. Emma logt in op 5 mei om 14:30 uur. Gaat naar `/biblioteca`, tabblad **Equipe**.
2. Zoekt Voltairine op in de lijst van `reader` van de bib (ze heeft een AnarBib-account sinds februari).
3. Klikt op **"Uitnodigen in het team"** → kiest **librarian**.
4. Veld "Reden": "beslissing AV van 04/05" (doctrine 1, strikte vereiste).
5. Bevestigt.

**Onmiddellijk effect.**

- Voltairine ontvangt een e-mail: "Hoi Voltairine, je bent benoemd als librarian van de BLMF door Emma G. naar aanleiding van: "beslissing AV van 04/05". Je nieuwe rechten zijn actief. Welkom in het team."
- De andere actieve coordinatoren van de BLMF (Lucy en Piotr) ontvangen een informerende e-mail.
- Auditlog: `2026-05-05 14:30 — Emma G. heeft Voltairine d.C. bevorderd tot librarian (reden: beslissing AV van 04/05)`.

**Commentaar.**

Het eenvoudigste geval. Het SIGB voert de beslissing van het collectief correct uit. Emma heeft politiek niets beslist — ze heeft geklikt om uit te voeren wat buiten de software is beslist.

**Wat het SIGB niet heeft gedaan:** controleren of de AV echt heeft plaatsgevonden, of de beslissing werkelijk is genomen, of Voltairine het er werkelijk mee eens is. Die dingen vallen **buiten de software**. Als Emma over de AV had gelogen, had het SIGB niets gezien. De politieke cultuur van de BLMF is wat zo'n leugen voorkomt (en het log maakt het achteraf traceerbaar).

## 10.2. Lucy geeft het stokje door

> **Context.** Lucy is coordinator bij de BLMF, maar ze kan de taak dit semester niet meer aan (ze begint aan een doctoraatsonderzoek). Ze wil "teruggaan naar librarian" om in het team te blijven maar haar verantwoordelijkheden te verlichten.

**Procedure.**

1. Lucy gaat naar `/biblioteca`, tabblad **Equipe**.
2. Op haar eigen rij (status `coordenador`) klikt ze op **"Ik geef het stokje door"**.
3. Keuze: "teruggaan naar librarian".
4. Bevestigingsvenster herinnert eraan dat ze de coördinatiebevoegdheden onmiddellijk verliest.
5. Lucy bevestigt. Optionele reden: "start doctoraatsonderzoek, tijdelijke verlichting".

**Onmiddellijk effect.**

- Haar membership `coordenador` gaat naar `inactive`.
- Haar membership `librarian` (die parallel bestond) blijft `active`.
- Lucy ontvangt een bevestigingsmail: "Je bent nu librarian van de BLMF. Je behoudt je operationele bevoegdheden."
- De hele coordinatie (Emma, Piotr) ontvangt een e-mail: "Lucy P. heeft het stokje doorgegeven en is geen coordinator meer. Ze blijft librarian van het team."
- Auditlog: `2026-05-05 18:42 — Lucy P. heeft zichzelf gedegradeerd van coordenador → librarian (reden: start doctoraatsonderzoek, tijdelijke verlichting)`.

**Commentaar.**

Dit is het voorbeeldige gebruik van recht P3. Lucy hoefde niemand om toestemming te vragen. Haar zelfverlaging is onmiddellijk. Ze blijft bijdragen aan de bib, maar met een intensiteit aangepast aan haar huidige beschikbaarheid.

**Politiek gezien**: dit is precies het soort roulatie dat men wil bevorderen. Lucy gaat niet verloren, ze neemt gewoon een andere rol aan. Over zes maanden of een jaar, als ze de coördinatie wil hervatten, kan het collectief haar hercoöpteren (T2). Geen enkele beslissing is definitief.

## 10.3. Karl moet vertrekken

> **Context.** Karl is librarian bij de BLMF. Zijn gedrag tegenover bepaalde lezers heeft problemen veroorzaakt (paternalisme, ongepaste opmerkingen). Het collectief heeft dit besproken in een AV op 4 mei en besloten dat hij het team moest verlaten.

**Procedure.**

1. Piotr (coordinator) — door de AV aangewezen om de beslissing uit te voeren — gaat naar `/biblioteca`, tabblad **Equipe**.
2. Op Karls rij klikt hij op **"Terugtrekking aanvragen"**.
3. Rood venster met expliciete vermelding van de termijn van 7 dagen.
4. Verplichte reden: "Na AV van 04/05, onbehoorlijk gedrag tegenover meerdere lezers gemeld over meerdere maanden, collectieve beslissing tot uitsluiting."
5. Expliciete bevestiging: "Ik begrijp dat dit verzoek van kracht wordt op 12 mei 2026, tenzij het door een andere coordinator wordt geannuleerd."

**Onmiddellijk effect.**

- Karls membership gaat naar `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl verliest onmiddellijk toegang** tot alle librarian-functies (de membership is bevroren).
- Karl ontvangt een e-mail:
  > "Hoi Karl, de coordinatie van de BLMF heeft je terugtrekking uit het team aangevraagd (rol: librarian), naar aanleiding van: "Na AV van 04/05, onbehoorlijk gedrag tegenover meerdere lezers gemeld over meerdere maanden, collectieve beslissing tot uitsluiting." Deze opzegtermijn wordt van kracht op 12 mei 2026 (over 7 dagen), tenzij een andere coordinator dit vóór die tijd annuleert. Voor enig overleg, wend je tot de coordinatie van de BLMF."
- Emma en Lucy (andere coordinatoren) ontvangen de informerende e-mail.
- Auditlog: `2026-05-05 — Piotr K. heeft de terugtrekking van Karl M. aangevraagd (rol: librarian, reden: ...)`.

**Verloop.**

- 6 mei om 9 uur: Lucy leest de e-mail. Ze is het eens met de beslissing en grijpt niet in.
- 7 mei: Emma heeft een gesprek met Karl (die haar schrijft om zich te verklaren). Emma concludeert dat de beslissing stand houdt. Grijpt niet in.
- 8-11 mei: niets.
- **12 mei om 00:00**: de cron `cron_team_pending_removal_complete` wordt uitgevoerd. Karl gaat naar `inactive`.
- Afsluitmails aan Karl en aan de coordinatie.
- Auditlog: `2026-05-12 — automatische overgang naar inactief (reden: pending_removal verlopen, cron) — actor: NULL`.

**Commentaar.**

Dit is het geval van collectieve uitsluiting. Drie politieke elementen om op te wijzen:

- **Het verval heeft als mogelijk vangnet gefunctioneerd**, zonder gebruikt te worden. Lucy en Emma hadden kunnen annuleren; ze hebben dat niet gedaan. Het feit dat niemand heeft geannuleerd is zelf een **impliciete beraadslaging**.
- **Karl bleef geïnformeerd** zonder verrassingen. Geen stille uitsluiting.
- **Het auditlog is leesbaar** voor het hele personeel en maakt het mogelijk om later op deze beslissing terug te komen als iemand zich afvraagt waarom Karl is vertrokken.

**Politiek gevoelig**: de reden in het veld "Reden" is leesbaar voor het hele personeel. Het zou geen details over de slachtoffers mogen bevatten (AVG, waardigheid), maar duidelijk genoeg moeten zijn om de beslissing politiek te kunnen verdedigen. De juiste dosering vinden is een coordinatievaardigheid.

## 10.4. Gecompromitteerd account: onmiddellijke schorsing

> **Context.** Op 5 mei om 19:30 uur merkt Emma in de activiteitslogs op dat Friedrich (librarian) 47 wijzigingen aan catalogusfiches heeft aangebracht in 3 minuten, waaronder meerdere aberrante (boeken gemarkeerd als "vermist" terwijl ze in de rekken staan, enz.). Het patroon lijkt op onbevoegde toegang.

**Procedure.**

1. Emma gaat naar `/biblioteca`, tabblad **Equipe**.
2. Op Friedrichs rij klikt ze op **"Schorsen"**.
3. Venster met **verplichte** reden (≥ 20 tekens).
4. Emma typt: "Vermoeden gecompromitteerd account, abnormale activiteit (47 cataloguswijzigingen in 3 min), verificatie aan de gang."
5. Bevestigt.

**Onmiddellijk effect (19:32).**

- Friedrich gaat naar `status='suspended'`.
- **Geen toegang** voor Friedrich.
- Friedrich ontvangt een dringende e-mail: "Je AnarBib-account is bij de BLMF preventief geschorst. Reden: vermoeden dat je account gecompromitteerd is. We raden je sterk aan om **je wachtwoord onmiddellijk te wijzigen**. Neem zodra je account beveiligd is contact op met de coordinatie van de BLMF zodat de schorsing opgeheven kan worden."
- De coordinatie (Lucy, Piotr) ontvangt een e-mail.
- Auditlog: `2026-05-05 19:32 — Emma G. heeft Friedrich E. geschorst (rol: librarian, reden: ...)`.

**Verloop.**

- **19:35**: Emma belt Friedrich (kanaal buiten het SIGB). Friedrich bevestigt dat hij deze handelingen niet heeft verricht. Hij had zijn computer open gelaten in een gedeelde ruimte.
- **19:40**: Friedrich wijzigt zijn wachtwoord via de herstellingsprocedure.
- **20:00**: Emma controleert de verdachte handelingen in het auditlog van de bib (het catalogusaudit, niet het teamaudit). Identificeert de 47 wijzigingen. Annuleert ze handmatig of vraagt een rollback aan de netwerkbeheerder indien nodig.
- **20:15**: Emma gaat terug naar het tabblad Equipe en heft de schorsing van Friedrich op.
- Friedrich ontvangt een bevestigingsmail. Auditlog: `2026-05-05 20:15 — Emma G. heeft de schorsing van Friedrich E. opgeheven`.

**Commentaar.**

Typisch geval waarbij de schorsing wordt gebruikt als **conservatoire maatregel**, niet als uitsluiting. Friedrich heeft niets misdaan — het is zijn account dat gecompromitteerd was. De schorsing heeft 43 minuten geduurd, de tijd om het te beveiligen.

**Politiek belangrijk**: Friedrich is niet "beschuldigd". De e-mail vermeldt dit uitdrukkelijk ("preventief"). Wanneer de situatie is opgelost, wordt de schorsing opgeheven, en het incident is vastgelegd in het log als een incident, niet als een blaam.

## 10.5. Errico is de enige coordinator en wil vertrekken

> **Context.** De BLMF heeft nog maar één actieve coordinator, Errico. Lucy heeft het stokje doorgegeven, Emma is verhuisd en is niet meer actief. Piotr heeft zichzelf begin van het jaar gedegradeerd. Errico moet vertrekken (verhuizing naar het buitenland, geen tijd meer).

**Procedure.**

1. Errico gaat naar `/biblioteca`, tabblad **Equipe**, klikt op **"Ik geef het stokje door"**.
2. Er opent zich een **speciaal** venster:
   > ⚠️ **LET OP**: je bent de enige actieve coordinator van de BLMF. De bib zal zonder coordinatie komen te zitten. De netwerkbeheerders van AnarBib zullen worden geïnformeerd. De BLMF kan blijven functioneren (de librarians blijven operationeel) maar er kunnen geen configuratiewijzigingen worden doorgevoerd totdat een nieuwe coordinator is gecoöpteerd. Doorgaan?
3. Errico bevestigt. Reden: "Verhuizing naar het buitenland, geen beschikbaarheid meer voor de coordinatie."

**Onmiddellijk effect.**

- Membership coordenador van Errico gaat naar `inactive`.
- E-mail aan Errico (bevestiging).
- E-mail aan de hele coordinatie van de BLMF — maar die bestaat niet meer, dus in de praktijk zijn het de resterende actieve `librarian` die een melding ontvangen.
- **Dringende e-mail aan de netwerkbeheerders**: "De BLMF heeft geen actieve coordinator meer. Hier zijn de resterende actieve librarians: Voltairine d.C., Friedrich E., ..."
- Auditlog: `2026-05-05 — Errico M. heeft zichzelf gedegradeerd van coordenador → reader (reden: ..., waarschuwing: last_coordinator_leaving)`.

**Verloop buiten de software.**

- 6 mei: Xavier (netwerkbeheerder) neemt contact op met Voltairine en Friedrich, de resterende actieve `librarian`. Ze bevestigen dat het collectief van de BLMF nog bestaat en dat ze willen doorgaan.
- 7-15 mei: intern overleg van het collectief van de BLMF, dat in een AV besluit Voltairine te coöpteren als coordinator.
- 16 mei: Xavier (of een andere coordinator van de BLMF die in dit geval niet meer bestaat, dus Xavier vanuit zijn transversaal recht) coöpteert Voltairine als coordinator. **Verplichte voorafgaande informatie**: Xavier heeft 2 dagen eerder aan Friedrich en Voltairine geschreven om de actie aan te kondigen. Eenmaal uitgevoerd wordt de actie vastgelegd in `cross_library_actions_log` met het kriticiteitsniveau "hoog" (wijziging van de coordinatie van een bib door een netwerkbeheerder).

**Commentaar.**

Politiek gevoelig geval: de bib gaat door een kwetsbare periode (tussen 5 en 16 mei heeft ze geen coordinatie). Maar het SIGB heeft het vertrek van Errico **niet verhinderd** — zijn recht P3 is onvoorwaardelijk. Het SIGB heeft enkel **het netwerk gewaarschuwd** zodat dat kon helpen.

Xaviers interventie illustreert het **correcte** gebruik van het transversale recht: hij werd (impliciet, door de automatische melding) aangesproken, hij heeft de voorafgaande informatie gerespecteerd, hij heeft zijn handeling vastgelegd. Hij heeft Voltairine niet opgelegd; het collectief van de BLMF heeft haar gekozen. Xavier heeft de beslissing enkel **technisch uitgevoerd**.

## 10.6. Een coöptatie van een netwerkbeheerder die misloopt

> **Context.** Xavier is oprichtend netwerkbeheerder. In de loop van de tijd zijn Maria, Patricia en Diego gecoöpteerd als netwerkbeheerders naarmate het netwerk zich uitbreidde. Op 20 mei 2026 bestaat het collectief van beheerders uit: Xavier, Maria, Patricia, Diego (vier actieve beheerders).
>
> Maria stelt de coöptatie voor van Mohammed, die ze kent in een Italiaanse bib die bij het netwerk aansluit.

**Procedure.**

1. Maria klikt vanuit `/rede/administradores` op **"Een coöptatie voorstellen"**.
2. Voert Mohammeds identiteit in (AnarBib-account aangemaakt twee weken eerder).
3. Motivatie: "Mohammed coördineert de BLA (Bologna), een bib die deze maand bij het netwerk aansluit. Hij heeft de politieke integratie van de BLA in AnarBib gedragen en is sterk betrokken bij de Italiaanse coordinatie. Zijn coöptatie als netwerkbeheerder zal de geografische diversiteit van het collectief versterken en de animatie aan Italiaanse kant vergemakkelijken."
4. Bevestigt.

**Onmiddellijk effect.**

- Voorstel aangemaakt, `status='open'`, `expires_at = 19 juni 2026`.
- Automatische stem `favorable` van Maria vastgelegd.
- E-mails aan Xavier, Patricia, Diego met het voorstel.

**Verloop.**

- 22 mei: **Diego** stemt `favorable`. Geen rationale (optioneel bij favorable).
- 25 mei: **Patricia** stemt `opposed`. Rationale: "Mohammed heeft geen anciënniteit in het netwerk. Zijn coöptatie gaat sneller dan die van de BLA, die nog niet de kans heeft gehad lang genoeg als AnarBib-bib te functioneren. Ik stel voor 6 maanden te wachten totdat de BLA haar draai heeft gevonden, en Mohammed dan opnieuw voor te stellen." Patricia vinkt "Mijn identiteit bekendmaken" aan.

**Onmiddellijk effect van de opposed-stem.**

- Voorstel gaat naar `status='rejected'`.
- E-mail aan Mohammed: "Hoi Mohammed, je voorstel tot coöptatie als netwerkbeheerder van AnarBib is niet doorgegaan. Patricia X. heeft het volgende bezwaar geuit: "[volledige rationale]". Je kunt met haar of met Maria, die je had voorgesteld, overleggen. De coöptatie kan later opnieuw worden voorgesteld."
- E-mail aan Maria (voorsteller): samenvatting met de rationale van Patricia.
- E-mail aan Xavier en Diego: info dat het voorstel is afgewezen, met de rationale.
- Netwerkauditlog: `2026-05-25 — coöptatie afgewezen: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Commentaar.**

Illustratief geval van unanimiteit **in actie**. Patricia heeft een veto, ze gebruikt het, haar rationale is expliciet en constructief ("wacht 6 maanden"). Ze heeft gekozen haar identiteit bekend te maken, wat Mohammed en Maria de mogelijkheid geeft rechtstreeks met haar te overleggen in plaats van te speculeren over de anonieme tegenstemmer.

**Politiek gezien**: coöptatie met unanimiteit is geen garantie voor een permanent blok. Patricia zegt niet "nooit" maar "nu nog niet". Als de BLA over 6 maanden goed is geïntegreerd en Patricia van gedachten verandert, kan een nieuw voorstel doorgaan. Het is deze **omkeerbaarheid in de tijd** die unanimiteit hanteerbaar maakt.

Het alternatief — Mohammed coöpteren met een meerderheid tegen de mening van Patricia in — had een kring van beheerders gecreëerd waarin Patricia zich in een lastige positie had bevonden. Beter wachten.

\newpage

# Bijlagen

\newpage

# Bijlage A — Woordenlijst

**AV** — Algemene vergadering. Collectieve besluitvormingsvergadering van een bib. Het SIGB modelleert de AV niet (P8). De modaliteit ervan (quorum, frequentie, deliberatiemethode) wordt volledig door elke bib bepaald.

**Auditlog** — Journal van bestuursdaden, opgeslagen in `library_membership_audit` (op bibniveau) en `network_administrator_audit` (op netwerkniveau). Leesbaar door het actieve personeel (op bibniveau) en door de netwerkbeheerders (op netwerkniveau).

**Zelfdegradatie** — Handeling waarbij een personeelslid zichzelf degradeert naar een lagere rol. Recht P3, onvoorwaardelijk.

**Bib `private`** — Bib waarvan de catalogus alleen zichtbaar is voor ingeschreven leden. Modus geschikt voor politiek kwetsbare bibs.

**Bib `network`** — Bib waarvan de catalogus zichtbaar is voor alle gevalideerde `reader` van het AnarBib-netwerk. Standaardmodus voor de meeste bibs.

**Bib `public`** — Bib waarvan de catalogus voor iedereen zichtbaar is, inclusief anonieme bezoekers.

**Verval** — Opgelegd uitstel tussen een beslissing en het effect ervan. Zeven dagen voor collectieve terugtrekkingen van lokaal personeel en van netwerkbeheerders. Dertig dagen voor het zelfontslag van de enige actieve netwerkbeheerder.

**Coöptatie** — Mechanisme voor toetreding tot een team (lokaal personeel) of tot het collectief van netwerkbeheerders. Voor lokaal personeel: beslissing van een coordinator+. Voor het netwerk: unanimiteit van de actieve beheerders.

**Cross-bibs** — Kwalificeert een handeling uitgevoerd door een netwerkbeheerder op een bib waarvan die geen lokaal personeelslid is. Vastgelegd in `cross_library_actions_log`.

**Cron** — Automatische taak die periodiek door het SIGB wordt uitgevoerd. Zonder menselijke actor. Voorbeelden: `cron_team_pending_removal_complete` (overgang van `pending_removal` naar `inactive` op dag +7), `cron_team_inactive_cleanup` (automatisch vertrek na 9 maanden).

**Delegatie** — Daad waarmee een collectief tijdelijk een functie aan een van zijn leden toevertrouwt, met de mogelijkheid om deze terug te nemen. Centraal concept, onderscheiden van "hiërarchie".

**Membership** — Rij in de tabel `user_library_memberships` die de verbondenheid van een persoon met een bib in een bepaalde rol uitdrukt. Een persoon kan meerdere memberships in een bib hebben (multi-membership).

**Multi-membership** — Mogelijkheid om meerdere membership-rijen te hebben voor dezelfde persoon in dezelfde bib, met verschillende rollen.

**Netwerk** — Het collectief van bibs die elkaar wederzijds erkennen en het AnarBib-platform delen. Geen centrale organisatie, een federatie.

**RPC** — *Remote Procedure Call*. SQL-functie aangeroepen door de gebruikersinterface om een handeling uit te voeren. Alle bestuursdaden verlopen via RPC's genaamd `fn_team_*` (lokaal personeel) of `fn_network_admin_*` (netwerk).

**Lokale soevereiniteit** — Principe P7 volgens hetwelk elke bib soeverein is over haar interne delegaties. Rolwijzigingen in een bib hebben geen invloed op een andere bib.

**Spec** — Specificatiedocument (`spec-*.md`) dat het functioneren van een SIGB-functionaliteit gedetailleerd beschrijft. Technische en politieke bron van waarheid. Versioned, gedateerd, amendeerbaar.

**Unanimiteit** — Modaliteit voor coöptatie en collectief ontslag van netwerkbeheerders. Alle stemmen moeten `favorable` zijn; één enkele `opposed` of een niet-opgeheven onthouding blokkeert.

**Fysieke validatie** — Procedure waarbij een librarian+ een `reader`-account valideert na een fysieke ontmoeting. Geldt voor het hele netwerk (wederzijds erkenningspact).

**Veto** — Stem `opposed` bij een coöptatie of een collectief ontslag van een netwerkbeheerder. Onmiddellijk effect: afwijzing van het voorstel. Verplichte rationale van minimaal 20 tekens.

\newpage

# Bijlage B — Index van technische functies

Deze bijlage geeft, voor elke in de gids vermelde RPC, de politieke vertaling en de betrokken overgang. Ze dient als snelle referentie.

## Functies voor lokaal personeel

| RPC SQL | Overgang | Politieke vertaling |
|---|---|---|
| `fn_team_promote_to_librarian` | T1 | Coöptatie `reader` → `librarian` |
| `fn_team_promote_to_coordenador` | T2 | Coöptatie `librarian` → `coordenador` |
| `fn_team_self_demote` | T3, T4 | Zelfdegradatie ("ik geef het stokje door") |
| `fn_team_request_remove_member` | T5 | Terugtrekkingsverzoek met verval van 7 dagen |
| `fn_team_cancel_remove_member` | T8 | Annulering van een terugtrekkingsverzoek |
| `fn_team_suspend_member` | T6 | Onmiddellijke schorsing (conservatoire maatregel) |
| `fn_team_unsuspend_member` | T7 | Opheffing van schorsing |
| `fn_validate_physical_account` | — | Fysieke validatie van een `reader` |
| `cron_team_pending_removal_complete` | T5 (vervolg) | Cron: overgang naar `inactive` op dag +7 |
| `cron_team_inactive_cleanup` | T9 | Cron: automatisch vertrek na 9 maanden |

## Functies voor netwerkbeheerder

| RPC SQL | Stap | Politieke vertaling |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Coöptatie: voorstel | Een beheerder stelt een nieuwe voor |
| `fn_network_admin_vote_cooptation` | Coöptatie: stem | Stem favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Zelfontslag | Zijn functies als netwerkbeheerder verlaten |
| `fn_network_admin_request_removal` | Collectief ontslag | Spiegelworkflow van de coöptatie |

## Autorisatiehulpfuncties (gebruikt door de RLS)

| Helper SQL | Politieke betekenis |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | Kan deze persoon als personeel optreden in deze bib? (actief lokaal personeel OF netwerkbeheerder) |
| `user_can_engage_library(library_id)` | Kan deze persoon deze bib politiek verbinden? (actieve lokale coordinator OF netwerkbeheerder) |
| `fn_caller_is_network_admin()` | Is de aanroeper een actieve netwerkbeheerder? |
| `fn_library_visible_to_caller(library_id)` | Is de catalogus van deze bib zichtbaar voor de aanroeper? |

## Hoofdtabellen

| Tabel | Politieke betekenis |
|---|---|
| `user_library_memberships` | De lokale delegaties (wie is personeel van welke bib) |
| `network_administrators` | De beheerders van het netwerk |
| `library_membership_audit` | Journal van lokale bestuursdaden |
| `network_administrator_audit` | Journal van netwerkbestuursdaden |
| `network_administrator_cooptation_proposals` | Lopende coöptatievoorstellen |
| `network_administrator_cooptation_votes` | Individuele stemmen van de beheerders |
| `cross_library_actions_log` | Registratie van netwerkbeheerderacties op bibs |

\newpage

# Bijlage C — Model voor een amendementsnota

Wanneer u een amendement wilt voorstellen op een regel van het SIGB of op deze gids, volgt hier een model om uw voorstel te structureren. Vrij formaat, u kunt het aanpassen.

---

## Voorstel tot amendement op [naam van de spec of de gids]

**Auteur(s):** [uw voornamen / pseudoniemen]
**Datum:** [DD/MM/JJJJ]
**Werkingssfeer:** [lokale bib / netwerk / grondbeginselen]

### 1. Betrokken regel

Citeer de te amenderen regel of alinea woordelijk, met de verwijzing in de bronspec.

> *Voorbeeld:* "`spec-gouvernance-roles.md`, §5.6, T5: De vervaltermijn vóór effectieve uitsluiting bedraagt 7 dagen."

### 2. Vastgesteld probleem

Beschrijf in enkele zinnen wat er problematisch is aan de huidige regel. Indien mogelijk met een concreet geval dat zich heeft voorgedaan.

> *Voorbeeld:* "In de praktijk is 7 dagen te kort wanneer de volgende AV van de bib pas over 15 dagen plaatsvindt. Een terugtrekkingsbeslissing die in een opwelling is genomen, heeft soms niet de tijd om collectief besproken te worden vóór het automatische effect."

### 3. Voorgesteld amendement

Beschrijf de gewenste wijziging, bij voorkeur met een formulering die klaar is om in de spec te worden opgenomen.

> *Voorbeeld:* "De vervaltermijn van 7 naar 14 dagen brengen, OF de termijn per bib configureerbaar maken (tussen 7 en 30 dagen), met een standaardwaarde van 14 dagen."

### 4. Voorziene technische gevolgen

Als u een idee heeft van wat dit inhoudt qua code, dat vermelden. Zo niet, dat ook zeggen ("ik weet het niet, te bekijken met de ontwikkelaars").

> *Voorbeeld:* "De vaste waarde aanpassen in de SQL-code van `fn_team_request_remove_member` en `cron_team_pending_removal_complete`. Als configureerbaar per bib, een kolom toevoegen aan `libraries`."

### 5. Voorziene politieke gevolgen

Beschrijf wat er verandert in de collectieve praktijk, en eventuele nevenwerkingen.

> *Voorbeeld:* "Meer tijd voor beraadslaging, maar ook meer tijd gedurende welke de persoon in `pending_removal` geschorst blijft (zonder toegang). Kan als zwaarder worden ervaren."

### 6. Overwogen alternatieven

Vermeld de andere pistes die u hebt overwogen, en waarom u ze verwerpt (of niet).

> *Voorbeeld:* "Alternatief: de termijn op 7 dagen laten maar een 'expliciete verlenging' door een andere coordinator mogelijk maken. Moeilijker te implementeren en te begrijpen. Verkieslijk om de standaard te wijzigen."

### 7. Gewenste discussie

Waar en hoe wilt u dat het voorstel wordt besproken?

> *Voorbeeld:* "Discussie op het Matrix-kanaal `#anarbib`, dan bij consensus integratie in de spec bij het volgende beheerspakket."

---

Eenmaal opgesteld, de nota verspreiden volgens de werkingssfeer (zie hoofdstuk 4, §4.2).

\newpage

# Bijlage D — Bronspecs en referenties

Deze gids steunt op de volgende documenten, raadpleegbaar in het projectarchief:

## Hoofdspecs

**`spec-gouvernance-roles.md`** — Grondleggende spec voor het beheer van lokale personeelsrollen. Versie 1.0 van 5 mei 2026. 1231 regels. Beschrijft de 4 rollen, de 5 statussen, de 9 overgangen, het auditlog, de meldingen, de UI, en 15 referentiegebruiksgevallen.

**`spec-administrateur-reseau.md`** — Scheiding tussen lokaal personeel en netwerkbeheerder. Versie 0.3 van 11 mei 2026. 975 regels. Beschrijft de tabel `network_administrators`, de unanimiteitscoöptatie, het collectief ontslag, het transversale recht, de semantiek van de tellers "pagina = werkingssfeer".

**`spec-validation-physique.md`** — Ontvangstmodi voor lezersaccounts (`open` vs `manual_validation`). Vastgelegd op 3 mei 2026. Beschrijft de accountstatussen, het DB-schema, de workflows.

**`spec-refactor-v3-semantique.md`** — Refactor van de semantiek van de reserveringsworkflow. Niet centraal voor het bestuur maar marginaal geciteerd voor de algehele coherentie van het SIGB.

## Verwante specs vermeld (te schrijven of in voorbereiding)

- `spec-migration-compte.md` — Migratie van een account van een bib naar een andere. 940 regels, vastgelegd op 3 mei 2026.
- `spec-invitation-equipe.md` — Uitnodigingsworkflow per e-mail voor personen zonder AnarBib-account. Te schrijven.
- `spec-fermeture-biblio.md` — Procedure voor de ordelijke sluiting van een bib. Te schrijven.
- `spec-mediation-conflits.md` — Formeel kader voor bemiddeling en onderzoek na een melding. Te schrijven (voorgesteld door de huidige gids).

## Meer informatie

De specs en de broncode staan in het Codeberg-archief van het project, GitHub-spiegel. De technische en politieke discussie vindt plaats op het Matrix-kanaal `#anarbib` van het netwerk.

Voor elk voorstel tot amendement aan deze gids of de specs, zie hoofdstuk 4 en bijlage C.

---

*Einde van de gids. Versie 1.0, 11 mei 2026.*

*Deze gids is zelf amendeerbaar. Als u vindt dat hij iets onjuist stelt, een geval heeft overgeslagen of een standpunt inneemt dat niet meer overeenkomt met de doctrine van het netwerk, zeg het dan.*

