# Kaart — Een naam schrijven, een titel schrijven

> **Vertaling ter nalezing.** Deze versie is uit het Frans vertaald zodat ze nu
> bestaat en niet pas over zes maanden. Lees je deze taal beter dan de
> vertaling haar schrijft, verbeter haar dan: dit is een gemeengoed, geen
> afgesloten tekst.

> **Voor wie deze kaart is.** Voor jou die catalogiseert. Ze verzamelt wat je
> beslist op het moment van invoeren: hoe een naam wordt geschreven, waar je
> een tussenvoegsel afbreekt, wat je met een collectief doet, en waarom een
> leeg veld meer waard is dan een geraden veld.
>
> Het uitvoerige *waarom* staat elders, in het beslissingenregister, sectie
> `CONV`. Hier wordt gecatalogiseerd.

## De regel, in één zin

**Eén enkele waarheid in de database, meerdere weergaven.** Jij voert de
catalogiseervorm in; hoofdletters, de volgorde voornaam-achternaam en
bibliografische opmaak worden **berekend** bij weergave en export. Typ ze nooit
met de hand.

Daar komt alle wanorde vandaan die we aan het herstellen zijn: de ingang, de
weergavevorm en de exportvorm werden **in hetzelfde veld** ondergebracht, op
verschillende momenten, door verschillende handen.

---

## 1. De naam van een persoon

### De sorteervorm telt

Het veld **«Sorteervorm»** is de waarheid. De **«Standaardvorm»** wordt daar
automatisch uit afgeleid, door de komma eenvoudig om te draaien. Nooit
andersom.

| Je schrijft in «Sorteervorm» | De app toont |
|---|---|
| `Kropotkin, Peter` | Peter Kropotkin |
| `Malatesta, Errico` | Errico Malatesta |

### Natuurlijke schrijfwijze, nooit in kapitalen

**`Kropotkin, Peter` — nooit `KROPOTKIN, Peter`.**

Kapitalen bij de achternaam zijn een **bibliografische verwijzingsnorm**
(ABNT), geen gegeven. Ze worden bij export toegevoegd, ter plekke. Ze zelf
typen maakt ze niet waarder: het vernietigt de informatie over hoofdletters,
die daarna niet meer te herstellen is — `de Sousa` en `De Sousa` zijn niet
langer te onderscheiden zodra alles in kapitalen staat.

### Waar afbreken: het tussenvoegsel

**De taal van de NAAM beslist, niet het geboorteland.** Iemand uit Argentinië
kan een Italiaanse naam dragen.

| Taal van de naam | Het tussenvoegsel… | Voorbeeld |
|---|---|---|
| Portugees, Frans | **gaat naar achteren**, na de voornaam | `Sousa, Manuel Joaquim de`<br>`Beauvoir, Simone de`<br>`Jong, Rudolf de` |
| modern Italiaans, Afrikaans | **blijft vooraan** | `Di Filippo, Luis`<br>`De Amicis, Edmondo`<br>`Van der Walt, Lucien` |

Luis Di Filippo is het schoolvoorbeeld: Argentijn, Italiaanse naam, dus
`Di Filippo, Luis` — en niet `Filippo, Luis Di`.

> **In het Nederlands** wordt het tussenvoegsel bij het sorteren achter de
> voornaam geplaatst: `Jong, Rudolf de`. In het Vlaams gebruik blijft het
> vaker vooraan (`De Clercq, Jan`) — volg de vorm die de persoon zelf voert,
> en noteer het in de opmerking als je twijfelt.

### Wat het gereedschap niet kan beslissen

**Dubbele achternaam of samengestelde voornaam?** `García Lorca` is een
Spaanse dubbele achternaam (niet afbreken); `Jean-Marie` is een samengestelde
voornaam. Geen enkele functie ziet het verschil. Bij twijfel: **vraag het**
in plaats van te beslissen — precies zulke gevallen gaan naar de
controlelijst.

---

## 2. Een collectief is geen persoon

**Een collectiefnaam heeft geen omgekeerde vorm.**

| ✅ | ❌ |
|---|---|
| `Grupo Krisis` | `Krisis, Grupo` |
| `Instituto de Estudos Libertários` | `Libertários, Instituto de Estudos` |
| `CIRA Marseille` | `Marseille, CIRA` |

### Vul «Autoriteitstype» in

Het veld bestaat en het **stuurt de regel aan**. Op *Collectief* gezet,
voorkomt het omkering. Leeg gelaten beschermt niets het record: het wordt als
persoon behandeld bij de eerste keer dat gereedschap eroverheen gaat.

Drie seconden invullen die drie maanden corrigeren besparen.

### Als het record MEERDERE personen bevat

Het gebeurt — de import heeft zulke gevallen gemaakt. `KAISER, William Young
and David E.` is niet één Kaiser met twee voornamen: het zijn **William
Young** *en* **David E. Kaiser**, twee auteurs van hetzelfde boek.

**Repareer het niet ter plekke.** Een autoriteitsrecord wordt door het hele
netwerk gedeeld: hernoemen verplaatst de fout alleen maar. Ga via het
Autoriteitenatelier, voorstel van het type **Splitsing**: het oorspronkelijke
record blijft bestaan, de andere worden aangemaakt, en de verbindingen met de
boeken volgen. Beraadslagingstermijn: veertien dagen, zoals bij een
samenvoeging.

---

## 3. De titel

### De schrijfwijze hangt af van de taal van de titel

Er is **geen** universele regel. Het Duits schrijft zijn zelfstandige
naamwoorden met een hoofdletter: dat is zijn **spelling**, geen typefout.

Het normalisatiegereedschap verlaagt alleen de **functiewoorden van de taal
van de titel**, op een niet-beginpositie. Het bewaart:

- het **eerste woord**;
- woorden na **sterke interpunctie** (`.` `:` `;` `?` `!` en het
  ondertitelstreepje);
- **afkortingen**.

**Het verwijdert een importartefact, het «herschrijft» de titel niet.** Wanneer
het een correctie voorstelt, blijf jij degene die beoordeelt of een woord een
eigennaam is — het gereedschap weet dat niet.

| Vóór | Na |
|---|---|
| `Antologia Do Movimento Operário Gaúcho` | `Antologia do Movimento Operário Gaúcho` |
| `Der Einzige Und Sein Eigentum` | `Der Einzige und sein Eigentum` |

### Het beginlidwoord: verminkt nooit de titel

`De Arbeiders` schrijf je als **`De Arbeiders`**. Niet `Arbeiders, De` — dat is
een overblijfsel van de kaartenbak — en niet `Arbeiders` alleen.

Het sorteren wordt geregeld met een **teller van niet-sorterende tekens** (hier:
3, voor `De `), die de titel intact laat.

---

## 4. De taal en het land

| Veld | Formaat | Voorbeelden |
|---|---|---|
| **Taal** (van het document) | BCP-47-code | `pt-BR`, `fr`, `es`, `de`, `it` |
| **Land** (van de autoriteit) | ISO 3166-1 α-2-code | `BR`, `FR`, `ES`, `NL` |

Niet `Nederlands`, niet `Nederland`, niet `nld`. De keuzelijst van de app geeft
je de juiste code: gebruik die in plaats van te typen.

**Leeg blijft leeg.** Ken je de taal niet, laat het veld dan open. Een
onbekende taal is eerlijke informatie; een verkeerde taal stuurt vervolgens de
schrijfwijze van de titel en de ingangsregel van de naam aan — ze verspreidt de
fout in plaats van hem in te dammen.

---

## 5. De datums

Twee gehele getallen en een **kwalificator**:

| Kwalificator | Wanneer |
|---|---|
| `exact` | de datum staat vast |
| `circa` | bij benadering («rond 1876») |
| `uncertain` | de bronnen wijken af |
| `unknown` | niet bekend |
| `living` | **de persoon leeft** |

`living` is geen comfortdetail: zonder deze werden «leeft nog» en «sterfdatum
onbekend» door elkaar gehaald — wat erop neerkwam dat mensen in de catalogus
werden doodverklaard.

Zijn geboorte en overlijden allebei onbekend, gebruik dan de **werkzame
periode** («werkzaam 1900-1910»). En spreken de bronnen elkaar tegen, schrijf
dat dan in de **datumnotitie**: dat is historiografisch herstel, geen opvulling.

---

## 6. Wat jij niet alleen beslist

Het autoriteitencorpus wordt **door het hele netwerk gedeeld**. Eén record
wijzigen betekent de catalogus van meerdere bibliotheken wijzigen.

| Handeling | Waar het gebeurt |
|---|---|
| een tikfout in een record verbeteren | rechtstreeks |
| twee dubbele records **samenvoegen** | Atelier — voorstel, 14 dagen |
| een record **splitsen** dat er twee bevat | Atelier — voorstel, 14 dagen |
| een door het gereedschap voorgestelde schrijfwijze of naamsvorm beslissen | controlelijst |

In het Atelier blijft een voorstel open zolang andere bibliotheken bezwaar
kunnen maken. Die termijn is geen bureaucratische traagheid: hij is wat het
corpus gemeenschappelijk houdt.

---

## Bij twijfel

**Laat het leeg in plaats van te raden.**

Een leeg veld stelt een vraag — iemand ziet haar en beantwoordt haar. Een fout
veld beantwoordt een vraag die niemand gesteld heeft, en het ziet er juist uit.
Dat is het veld dat we drie maanden later terugvinden, gekopieerd in vijf
catalogi.
