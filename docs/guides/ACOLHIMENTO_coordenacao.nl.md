# Welkom in het netwerk AnarBib

**Welkomstgids voor de coördinaties — de eerste dertig dagen**

*Versie 1.0 — 16 september 2026 · Licentie AGPLv3 · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Vooraf: wat aanvaard is, en wat nog niet

De kandidatuur van jouw bibliotheek is aanvaard door de coördinatie van het netwerk. Dat
betekent twee dingen, en alleen die twee:

1. Het netwerk erkent jouw bibliotheek als deel van de anarchistische en libertaire
   familie die het onthaalt, en het heeft voor jou de weg naar de oprichting geopend.
2. Jouw account is geen account meer van wie zich kandidaat stelt: het is een account van
   een **coördinatie in oprichting**.

Wat **nog niet** gebeurd is: jouw bibliotheek is niet actief. Ze verschijnt niet in de
gemeenschappelijke catalogus, ze ontvangt geen lezers, ze wisselt niets uit met de andere
bibliotheken. Ze is **pre-actief**, en jij bent degene die haar daaruit haalt — niet
alleen, en niet op één dag.

> **De belofte van deze gids.** Je hoeft geen bibliothecaris te zijn. Je hoeft geen
> verstand te hebben van informatica. Je moet weten wat jouw collectief wil, en iemand
> hebben aan wie je het kan vragen als je het niet weet. De rest is klikken.
>
> **En de gouden regel: klik maar, er gaat niets stuk.** De software toont de onmogelijke
> overgangen niet, schakelt met een uitleg de knoppen uit die een regel zou blokkeren, en
> weigert in de databank de onmogelijke combinaties. De zeldzame handelingen die echt
> niet terug te draaien zijn, staan opgesomd in hoofdstuk 9.

**De persoon met wie je praat.** Op elk moment van dit traject, vóór je beslist en niet
erna: `anarbib@proton.me`. Het netwerk houdt het als principe dat een beslissing over
de oprichting eerst met een kameraad besproken wordt voor ze een formulier wordt.
Schrijven is geen bekentenis van zwakte — het is de normale werking.

---

## 1. Dag 1 — Inloggen, en begrijpen waar je bent

### 1.1 Inloggen

De aanmeldpagina is `/login` (knop **Aanmelden**). Het adres `/cadastro` leidt er alleen maar naartoe: als
een oud document je daarheen stuurt, is dat niet jouw fout.

Als je nog het voorlopige wachtwoord gebruikt dat je per e-mail kreeg, **verander het dan
vóór al de rest**. Zolang het niet veranderd is, blijven verschillende acties geblokkeerd
— dat is een passief bewijs dat het account echt door een persoon in handen is genomen.

### 1.2 De twee huizen

Dit is het belangrijkste van de hele gids, en het loont om het vanbuiten te kennen.

| Als de vraag is… | Dan ga je naar… |
|---|---|
| “wat hebben we beslist?” | **`/biblioteca`** — het collectieve huis |
| “wat doe ik met deze persoon voor mij?” | **`/painel`** — de balie |

In `/biblioteca` wonen de publieke identiteit, het reglement, het team, het
adoptieprofiel, de overgangen en de vertrouwelijkheid: alles wat het collectief heeft
beraadslaagd. In `/painel` woont het werk van elke dag: uitleningen, innames,
raadplegingen, reserveringen, accounts die op validatie wachten.

Dat is geen willekeurige ordening. Veel bibliotheeksoftware vermengt de twee, en het
resultaat is dat de politieke configuratie verstopt raakt in een back-office van een
beheerder. Hier staat de beraadslaging aan de ene kant en de uitvoering aan de andere.

### 1.3 De routes die je gaat gebruiken

| Route | Wat het is | Voor wie |
|---|---|---|
| `/criar-conta` | inschrijving — **de enige toegangsdeur, voor iedereen** | om het even wie |
| `/conta` | de persoonlijke ruimte van elke lezer — negen tabbladen | ieder, de eigen ruimte |
| `/atelier` | de ateliers: oprichting en autoriteiten | coördinatie in oprichting |
| `/painel` | de balie, het werk van de dag | team (librarian, coördinatie) |
| `/biblioteca` | het collectieve huis, de beslissingen | team, met bevoegdheden per rol |
| `/catalogacao` | catalogiseren en importeren | team |
| `/rede` | beheer van het netwerk | alleen netwerkadmins |

De pagina **Federação** en de publieke pagina's — catalogus, Werk, Tijdschrift, Onderwerp,
Bibliotheken, Cartografie, FICEDL-thesaurus — maken het geheel af. De routes worden niet
vertaald: ze zijn dezelfde in de tien talen.

> **Je stapt nooit in het account van iemand anders.** Alles wat het team voor een lezer
> moet doen, staat in het painel. Betrap je jezelf erop dat je “als iemand wil inloggen”,
> dan staat wat je zoekt in het painel, tabblad **Lezer** (`leitor`).

---

## 2. Dag 1 tot 3 — Het oprichtingsatelier

De oprichting is een traject in `/atelier`. Je kan op elk moment opslaan en later
terugkomen: er gaat niets verloren tussen twee sessies. **Je hebt 60 dagen**, en op de
45ste komt er een herinnering per e-mail.

### 2.1 Stap 0 — het adoptieprofiel, de stichtende daad

Vóór alle andere luiken vraagt de software waar jouw bibliotheek zich plaatst op **vier
onafhankelijke assen**. Geen enkele is een kwaliteitsniveau: het zijn manieren van
bestaan, en een kleine bibliotheek die overal de eenvoudige modus kiest is geen
onafgewerkte bibliotheek.

**As 1 — `catalog_mode`, de catalogus**

- `local_only` — de collectie blijft thuis, niet blootgesteld aan het netwerk. Nuttig
  tijdens een inloopperiode, of wanneer een deel van de collectie nog niet klaar is om
  gepubliceerd te worden.
- `network_published` — de collectie komt in de gemeenschappelijke catalogus AnarBib.

**As 2 — `circulation_mode`, de circulatie**

- `off` — geen enkele circulatie beheerd in de software: catalogus alleen. Dat is het
  geval van een erfgoedcollectie voor raadpleging.
- `informal` — eenvoudige circulatie, zonder lidmaatschapsbijdrage of strikte regels. Het
  typische geval van een kleine militante bibliotheek waar iedereen elkaar kent.
- `full_sigb` — volledige circulatie: regels, reserveringen, bijdragen, schorsingen.

**As 3 — `network_mode`, de federatie**

- `isolated` — de bibliotheek bestaat in AnarBib maar wisselt niets uit.
- `observer` — ze ontvangt de stromen van het netwerk, ze draagt nog niet bij.
- `federated` — ze neemt volwaardig deel.

**As 4 — `governance_mode`, het bestuur**

- `informal` — geen enkele aparte teamrol: iedereen is lezer. Geen coöptatie, geen
  wachttermijn, geen auditlogboek.
- `staff_roles` — de rollen `librarian` en `coordenador` (coördinatie) bestaan, coöptatie
  vereenvoudigd.
- `full_governance` — het geheel: coöptatie, wachttermijn, auditlogboek, crons.

### 2.2 Wat elke keuze aansteekt in het painel

Deze tabel is de reden waarom stap 0 vóór al de rest komt. De tabbladen van de balie
verschijnen al dan niet naargelang de as van de circulatie:

| Tabblad van het painel | Verschijnt als |
|---|---|
| **Werk van de dag** (`trabalho-do-dia`) | altijd |
| **Acties** (`acoes`) | altijd |
| **Lezer** (`leitor`) | altijd |
| **Geschiedenis** (`historico`) | altijd |
| **Raadplegingen ter plaatse** (`consultas-locais`) | circulatie `informal` of `full_sigb` |
| **Uitleningen** (`emprestimos-livro`) | circulatie `informal` of `full_sigb` |
| **Reserveringen** (`reservas`) | circulatie `full_sigb` |
| **Uitleningen in bulk** (`emprestimos-lote`) | circulatie `full_sigb` |
| **Bijdragen** (`contribuicoes`) | lidmaatschapsbijdrage geactiveerd **en** circulatie verschillend van `off` |

Als een tabblad bij jou niet verschijnt, is dat geen storing: het is het profiel dat jouw
collectief heeft gekozen. En als het profiel tijdens de sessie verandert, keert het painel
vanzelf terug naar het **Werk van de dag**.

> **Keuzes zijn geen gevangenissen.** Elke as heeft haar eigen overgangsleer — sommige
> snel, sommige traag, sommige onomkeerbaar. Het tabblad **Overgangen** staat in
> `/biblioteca`, en niet in het painel: van profiel veranderen is een collectieve
> beslissing, geen handeling aan de balie. Bepaalde overgangen die verschillende assen
> doorkruisen gaan langs de validatie van de netwerkadmins.

### 2.3 De tien luiken

Na stap 0 toont het atelier alleen de luiken die jouw profiel relevant maakt. Een
bibliotheek in `circulation_mode = off` zal het luik circulatie niet zien: er ontbreekt
niets, die vraag stelt zich gewoon niet bij jullie.

| Luik | Wat er beslist wordt | Voorwaarde |
|---|---|---|
| 1 | Identiteit — naam, korte naam, adres, contact | altijd |
| 2 | Openingsuren en permanenties | altijd |
| 3 | Verantwoordelijke personen | volgens het bestuur |
| 4 | Catalogiseringsbeleid | altijd |
| 5 | Circulatiebeleid | als de circulatie niet `off` is |
| 6 | Toelatingsbeleid voor lezers | volgens bestuur en circulatie |
| 7 | E-mailbeleid | altijd |
| 8 | Zichtbaarheid en deelname aan het netwerk | als het netwerk niet `isolated` is |
| 9 | Gegevens en vertrouwelijkheid | altijd |
| 10 | Aanmaak van het reglement | altijd |

**Geen van deze luiken is een vraag van informatica.** Het zijn tien vragen voor de
assemblee, gepresenteerd in de volgorde waarin ze zich goed laten beantwoorden. Vul ze in
met wat het collectief al beslist heeft; waar het niet beslist heeft, stop je en breng je
de vraag naar de volgende vergadering. Het atelier wacht.

### 2.4 Luik 10 — het skelet van een reglement

Op het einde maakt de software een vooraf ingevulde PDF met al jouw keuzes. **Die PDF is
geen certificaat.** Het is een skelet om te bespreken: een grondstof voor beraadslaging.
De secties die debat verdienen, zijn als dusdanig gemarkeerd.

Het verwachte traject is: downloaden, meenemen naar de assemblee, vrij amenderen, en het
geamendeerde document opnieuw uploaden als officieel reglement van de bibliotheek. Zolang
het niet opnieuw geüpload is, blijft de bibliotheek pre-actief.

> **Een punt van eerlijkheid.** “De oprichting afronden” staat vandaag niet gelijk aan de
> automatische activering van de bibliotheek. Dat is een gekende lacune van de software,
> geen fout van jou. Wanneer je aan het einde van de luiken komt, schrijf dan naar
> `anarbib@proton.me` zodat de activering gedaan wordt — en dring aan als niemand binnen
> een paar dagen antwoordt.

---

## 3. Dag 3 tot 7 — De pagina Biblioteca, het collectieve huis

Zodra de oprichting afgerond is, wordt `/biblioteca` de plek waar wat beslist is
ingeschreven blijft staan en standhoudt. Daar kijk je als iemand vraagt “maar wat hadden
we nu afgesproken?”.

- **Publieke identiteit** — wat het netwerk en het publiek van jouw bibliotheek zien.
- **Reglement** — het document dat jullie hebben aangenomen, en de versies ervan.
- **Team** — wie wat is, en via welk circuit (hoofdstuk 4).
- **Profiel** — de vier assen, zoals ze vandaag staan.
- **Overgangen** — de voorstellen tot profielwijziging en de stemming erover.
- **Vertrouwelijkheid** — bewaring van de gegevens, automatische opschoning, AVG/LGPD.

**De beslissingen die deze week uitgeklaard moeten worden**, allemaal in `/biblioteca`:

1. **De zichtbaarheid van de collectie** — publieke catalogus of niet, verschijnen in de
   galerij van bibliotheken van `anarbib.org`, aanwezigheid op de cartografie van het
   netwerk. Op de cartografie heeft een collectief dat kiest om niet te verschijnen daar
   zijn redenen voor: de software respecteert die, en jij ook.
2. **Het e-mailbeleid** — welke gebeurtenissen een bericht naar de lezer op gang brengen
   (uitleencyclus, herinneringen vóór de vervaldag, aanmaningen bij te laat) en of het
   team er een kopie van krijgt. Dat alles gaat aan en uit per bibliotheek.
3. **De bewaring van de gegevens** — hoelang de uitleengeschiedenis van een persoon
   bewaard blijft na de inname. Dat is evenzeer een politieke als een wettelijke vraag: in
   een militante bibliotheek is een geschiedenis een lijst van lectuur van geïdentificeerde
   personen. Er weinig van bijhouden is een vorm van bescherming.
4. **De lidmaatschapsbijdrage**, als die bij jullie bestaat — en daarmee het tabblad
   **Bijdragen** van het painel.
5. **De lezerskaart** — als jullie die activeren. Ze draagt geen enkele naam: alleen de
   korte naam van de bibliotheek en een ondoorzichtige QR, en het is de lezer zelf die ze
   aanmaakt en opnieuw aanmaakt. Ze is met opzet zo ontworpen, zodat een verloren kaart
   niets vertelt over wie ze bij zich droeg.

> **Over het tabblad Vertrouwelijkheid.** Het kan twee berichten tonen die elkaar
> tegenspreken over de automatische opschoning. Dat is een gekend weergavegebrek. Vóór je
> besluit dat de opschoning actief of inactief is, vraag het aan het netwerk.

---

## 4. Dag 5 tot 10 — Het team samenstellen

### 4.1 Drie rollen, en alleen drie

`lezer` · `librarian` (bibliothecaris) · `coordenador` (coördinatie).

De lokale rol “beheerder” is in mei 2026 ingetrokken. Als je die ergens vermeld vindt, is
het document verouderd. “Beheer van het netwerk AnarBib” bestaat, maar dat is een
**transversaal statuut** — het is niet de volgende trede van de trap, en je komt er niet
door lang genoeg te coördineren. Het is een ander politiek mechanisme, met zijn eigen
coöptatie.

### 4.2 De valkuil die duur uitvalt

**Niemand schrijft zich twee keer in.** Iedereen komt één enkele keer binnen via
`/criar-conta`, als lezer — ook wie van het team zal zijn.

Team worden is geen nieuwe inschrijving: het is een coöptatie, en die gebeurt op het
account dat al bestaat. Wie zich opnieuw inschrijft in de mening zo “als team binnen te
komen”, maakt alleen een tweede account en een probleem dat de coördinatie zal moeten
ontwarren.

**Dus het enige wat je moet vragen aan wie in het team komt, is: “stuur me jouw publieke
ID”.**

### 4.3 Het circuit in drie stappen

Geen enkele promotie is eenzijdig. Drie verschillende personen, drie handelingen:

1. **Voorstellen** — de coördinatie stelt iemand voor via de publieke ID, voor de rol
   `librarian` of `coordenador`.
2. **Bekrachtigen** — iemand anders van het team bekrachtigt. De betrokken persoon is
   uitgesloten van het quorum: zodra het team twee andere actieve personen telt, zijn twee
   bekrachtigingen vereist.
3. **Aanvaarden** — de voorgestelde persoon aanvaardt. Zonder die toestemming gebeurt er
   niets.

Het voorstel **vervalt na 30 dagen**. Een lezersregel sluit, die van bibliothecaris opent:
één enkele actieve rol per bibliotheek, en de geschiedenis blijft.

> **De collegiale sprong.** Standaard moet je eerst bibliothecaris geweest zijn om in de
> kring van de coördinatie te komen. Voor een horizontaal collectief komt die
> tussenliggende trede met niets overeen: één enkele beslissing van de assemblee vroeg
> twee circuits in de software. Vandaar de sprong — iemand rechtstreeks van lezer naar de
> coördinatie voorstellen — die bestaat als **optie van de bibliotheek**, standaard
> uitgeschakeld, die jouw collectief activeert als het dat wil. Hij maakt de trap korter,
> nooit de toestemmingen.

### 4.4 Het team verlaten

- **Wachttermijn van 7 dagen** — een vertrek uit het team is niet onmiddellijk; de persoon
  gaat langs een tussentoestand, en dat laat tijd om met elkaar te praten.
- **Inactiviteit** — een teamaccount dat al lang niet meer inlogt, gaat er automatisch uit,
  met een bericht aan de persoon 30 dagen vooraf en 7 dagen vooraf. Het bericht van 7 dagen
  gaat ook naar de coördinatie, en het wordt doorgeschoven naar de netwerkadmins als de
  inactieve persoon de laatste coördinatie van het huis is.
- **Het stokje doorgeven** — de coördinatie aan iemand anders overdragen gebeurt via
  hetzelfde circuit in drie stappen, vóór je vertrekt. Laat het niet voor de laatste dag.

---

## 5. Dag 7 tot 20 — De collectie

### 5.1 De drie woorden die je nodig hebt

- **Werk** (*obra*) — de gedeelde beschrijving: het boek als werk, hetzelfde voor het hele
  netwerk.
- **Holding** — het feit dat jouw bibliotheek dat werk bezit.
- **Exemplaar** — het fysieke object op de plank, met zijn etiket, zijn staat, zijn
  geschiedenis.

Drie collectieven kunnen hetzelfde boek hebben: één werk, drie holdings, meerdere
exemplaren. Daarom komt het verbeteren van een beschrijving het hele netwerk ten goede, en
daarom verbeter je een beschrijving met zorg.

### 5.2 Drie beschrijvingsniveaus, en geen enkel is het verkeerde

| Niveau | Geest |
|---|---|
| **Simples** | militante bibliotheek, zonder academische pretentie: type, titel, auteursvermelding, jaar, uitgever, taal, plaatskenmerk, standaardcirculatie, omslag, ISBN |
| **Avançado** | werk van bibliothecaris zonder MARC: ondertitel, editie, reeks, plaats, pagina's, getypeerde bijdragen, onderwerpen, noten |
| **Completo** | uitputtend: ISBD-zones, MARC, identificatoren van autoriteiten, volledige herkomst |

**Van niveau veranderen verliest niets.** Een veld dat door een lager niveau verborgen
wordt, behoudt zijn waarde. Doe de test één keer, met je eigen ogen: dat is wat overtuigt.

**Begin in Simples.** Vijf beschrijvingen per week in Simples zijn meer waard dan één
perfecte beschrijving per maand. De collectie bestaat pas als ze gecatalogiseerd is.

### 5.3 De enige eis die het netwerk echt stelt

**Geen enkel nieuw exemplaar zonder verwervingswijze.** Waar het vandaan komt, wanneer,
geschonken door wie, na welke gebeurtenis.

Dat is geen geleerd detail. In een militante bibliotheek is de herkomst de geschiedenis
van het collectief. Zonder haar wordt de collectie in één generatie een anonieme stapel.
Het netwerk vraagt je niet het retroactieve inhaalwerk te doen — het vraagt dat de schuld
vanaf nu ophoudt te groeien.

### 5.4 De rest van `/catalogacao`, wanneer je die nodig hebt

Massa-imports, ontdubbelingsassistent in drie stappen, zoeken naar omslagen, externe
bronnen van metadata, opladen met OCR in de browser, inventaris door de QR-etiketten te
lezen, tijdschriften en hun collectiestaten. Niets daarvan is nodig in de eerste week. Het
staat er wanneer het moment daar is.

### 5.5 Onderwerpen en de FICEDL-thesaurus

AnarBib draagt de **FICEDL-thesaurus** met zich mee: 462 termen, vertaald in de tien
talen, meegeleverd met de software. Het is een gemeengoed van de federatie, en hij komt al
ingevuld aan — het is geen taak voor jou.

De **lokale onderwerpen** daarentegen behoren aan elk huis toe: het is jouw collectie,
jouw vocabulaire, jouw redactionele keuzes. En jouw onderwerpen **afstemmen** op de
FICEDL-termen is een daad van het collectief, geen technische operatie: zeggen dat jouw
“strafrechtelijk abolitionisme” overeenkomt met de gemeenschappelijke term “gevangenis” is
een documentaire stellingname. Daarom komt de afstemming niet kant-en-klaar aan.

---

## 6. Dag 10 tot 25 — De balie

Vier stromen, en het painel ordent ze:

- **Uitlening** — uitgifte, inname (ook gedeeltelijk), verlenging. De verlenging kan item
  per item gebeuren: als de persoon twee van de drie boeken uit heeft, wordt alleen het
  derde verlengd.
- **Inname** — volledig of regel per regel. Een actie in bulk mislukt nooit in stilte: wat
  niet doorging, wordt opgesomd met de reden.
- **Raadpleging ter plaatse** — de persoon wil iets ter plaatse bekijken, er wordt een
  tijdslot afgesproken. **De onderhandeling stopt na drie keer heen en weer**: daarna
  stuurt de software jullie naar de telefoon. Dat is met opzet — een onderhandeling die
  daaroverheen gaat is geen probleem van de software.
- **Reservering** — tot aan de effectieve afhaling, die de reservering in een uitlening
  verandert.

Daarnaast, in het painel: de **validaties** van de inschrijvingen van lezers (hier
beslissen jullie wie binnenkomt), de **waarborg** als jullie huis die hanteert, de
**bijdragen**, de **leesnotities**, de **evenementen**.

> **Een gekend gebrek.** De knop “Uitleningen openen” van bepaalde taken van het Werk van
> de dag leidt naar een leeg tabblad. Het ligt niet aan jou. Ga rechtstreeks langs het
> tabblad **Uitleningen** (`emprestimos-livro`).

---

## 7. Dag 20 tot 30 — De federatie

De pagina **Federação** heeft acht tabbladen: **Início**, **Círculos**, **Diretório**,
**Assembleias**, het blad **Rizoma**, **Carta/Boletim**, **Apoio mútuo** en **Comuns**.

Dat is het deel van de software dat geen SIGB is. Het bestaat omdat het project geen “SaaS
voor bibliotheken” wil zijn: in AnarBib binnenkomen is binnenkomen in een gemeenschappelijk
politiek project, en een netwerk dat alleen bibliografische beschrijvingen uitwisselt is
geen netwerk.

Wat er deze laatste week te doen valt, zonder haast:

1. **Van `observer` naar `federated` gaan**, als jullie dat beslist hebben — en alleen dan.
   Enkele maanden in waarnemersmodus in het netwerk komen is een respectabele keuze.
2. **Jullie fiche in de Diretório invullen**, zodat de andere huizen weten wie jullie zijn
   en hoe ze met jullie kunnen praten.
3. **Beslissen over de cartografie** — verschijnen met een precies adres, alleen met de
   stad, of niet verschijnen. Geen van de drie antwoorden hoeft verantwoord te worden.
4. **De Círculos en de Assembleias bekijken**, om te weten waar de beslissingen van het
   netwerk genomen worden.
5. **Als jullie de catalogus publiceren**, met het netwerk bekijken wat het OAI-PMH-punt
   voor jullie betekent — daarlangs kunnen andere catalogi de jullie oogsten.

De pagina `/rede` is het eigenlijke beheer van het netwerk, voorbehouden aan de
netwerkadmins. Een bibliotheek coördineren geeft daar geen toegang toe, en dat is gewild.

---

## 8. De tien beslissingen die niet technisch zijn

Knip deze lijst uit en neem ze mee naar de assemblee. Geen van deze antwoorden zit in de
software: de software registreert alleen wat jullie zullen antwoorden.

1. Waar plaatsen wij ons op de vier assen van het profiel?
2. Is onze catalogus publiek?
3. Lenen wij uit, en onder welke voorwaarden?
4. Wie kan zich inschrijven als lezer, en wie valideert?
5. Hebben wij een lidmaatschapsbijdrage? Een waarborg?
6. Hoelang houden wij de leesgeschiedenis van de personen bij?
7. Wie is van het team, en activeren wij de collegiale sprong?
8. Verschijnen wij op de cartografie, en met welke precisie?
9. Nemen wij deel aan de assemblees van het netwerk, en wie vertegenwoordigt ons daar?
10. Hoe stemmen wij onze onderwerpen af op de gemeenschappelijke thesaurus — en wat
    weigeren wij af te stemmen?

---

## 9. Wat niets stukmaakt, en wat een tweede lezing vraagt

**Maakt niets stuk:** overal klikken, alle tabbladen openen, het beschrijvingsniveau
veranderen om te zien, een luik half opslaan, iemand voorstellen en het voorstel laten
vervallen, de collegiale sprong aan- en uitzetten, van `observer` naar `federated` gaan,
een beschrijving verbeteren.

**Vraagt een tweede lezing, omdat het niet terug te draaien is of duur uitvalt:**

- Een account **opheffen** — en let op: in het Portugees onderscheidt de software
  **APAGAR** (de geschiedenis leegmaken) van **EXCLUIR** (het account opheffen), met twee
  verschillende bevestigingswoorden. In de negen andere talen vallen de twee op hetzelfde
  woord — in het Nederlands is dat **VERWIJDEREN**. Lees de hele zin vóór je typt, niet
  alleen het gevraagde woord.
- Een geschiedenis wissen — de gegevens komen niet terug.
- De profielovergangen die in het tabblad Overgangen als onomkeerbaar gemarkeerd staan.
- Een collectie in het netwerk publiceren die het collectief niet beslist heeft te
  publiceren.
- Iemand uit het team halen — de wachttermijn van 7 dagen bestaat precies daarvoor.

---

## 10. Waar hulp vragen, en hoe teruggeven

**Hulp vragen:** `anarbib@proton.me`. Zeg op welk scherm je bent en wat je verwachtte te
zien. Er bestaat geen domme vraag: de software is geschreven door één persoon, en elke “ik
heb het niet gevonden” die naar boven komt, is een geïdentificeerd gebrek.

**Een ritueel dat werkt.** Een half uur per week, met het team, drie vaste vragen:

> wat heb ik niet gevonden op het scherm? · wat heb ik gedaan zonder het te begrijpen? ·
> wat ontbrak er in de software?

De antwoorden voeden een blad met lacunes dat de volgende agenda wordt — en een materiaal
om aan het project bij te dragen. Het is het enige mechanisme dat het gebruik tot bij de
code laat opklimmen.

**Teruggeven, zonder te programmeren.** Het bestand `AIDER.md`, in de wortel van de
repository, somt de open taken op die geen code vragen: vertaling, nalezing van inclusief
schrijven, documentatie, afstemming van onderwerpen, testen van schermen. AnarBib staat
onder AGPLv3 en heeft vandaag maar één enkele maintainer — dat is zijn voornaamste
kwetsbaarheid, en ze wordt uitgesproken in plaats van verzwegen.

---

## 11. De dertig dagen op één pagina

| Wanneer | Wat | Waar |
|---|---|---|
| Dag 1 | Inloggen, het wachtwoord veranderen, rondkijken zonder iets te veranderen | `/login`, `/conta` |
| Dag 1–3 | Stap 0: de vier assen, collectief beslist | `/atelier` |
| Dag 3–5 | Luiken 1 tot 9 | `/atelier` |
| Dag 5 | Luik 10: het skelet van het reglement downloaden | `/atelier` |
| Dag 5–10 | Het reglement naar de assemblee brengen, amenderen, opnieuw uploaden | assemblee, dan `/atelier` |
| Dag 5–10 | De publieke ID's verzamelen, de coöptatiecircuits openen | `/biblioteca`, tabblad Team |
| Dag 7–20 | Eerste beschrijvingen in modus Simples, allemaal met herkomst | `/catalogacao` |
| Dag 10–25 | Eerste dag zelfstandig aan de balie | `/painel` |
| Dag 20–30 | Fiche in de diretório, cartografie, netwerkmodus | Federação, `/biblioteca` |
| Dag 30 | Naar het netwerk schrijven: wat ontbrak, wat misleidde | `anarbib@proton.me` |

---

*Deze gids bestaat in tien talen: pt-BR, fr, es, en, it, de, ca, eo, nl, el. Hij beschrijft
de staat van de software in september 2026 en zal gecorrigeerd worden wanneer de software
verandert — als een scherm niet overeenkomt met wat hier staat, is het de gids die
ongelijk heeft, en dat zeggen is een bijdrage.*

**Welkom.**
