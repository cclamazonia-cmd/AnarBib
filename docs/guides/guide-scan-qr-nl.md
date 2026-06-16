# Handleiding — Scan en QR-code in AnarBib

> **Voor wie is deze handleiding.** Voor elke kameraad van een bibliotheek die
> de camera van de telefoon (of computer) wil gebruiken om tijd te besparen:
> een lezer identificeren via de lezerskaart, de gegevens van een boek ophalen
> via de streepjescode, of de collectie controleren. Op verzoek geschreven — en
> voor het **gemeengoed** van het netwerk.
>
> **Geest.** Niets hier houdt je in de gaten of beoordeelt je. Het lezen van
> codes gebeurt **100 % op jouw apparaat**: geen enkel camerabeeld verlaat het
> toestel. De tools zijn er om je autonomie te geven, niet om je vast te zetten.
> Als iets niet werkt, **breekt de catalogus nooit** — in het ergste geval typ
> je gewoon met de hand.
>
> Onderdeel van het **gemeengoed van kennis** van de wederzijdse hulp (zie de
> omkadering « wederzijdse hulp bij het catalogiseren »). Geschreven per
> taalgemeenschap: als je een versie in een andere taal wil, komt die er naast
> deze, niet als vertaling van bovenaf.

---

## Wat je kunt scannen

AnarBib heeft **één cameralezer**, hergebruikt op drie plaatsen:

| Waar | Wat je scant | Waarvoor |
|---|---|---|
| **Dashboard › Lezer beheren** | QR van de **lezerskaart** | De lezer onmiddellijk identificeren |
| **Catalogiseren** (fiche van het boek) | **ISBN-streepjescode** | Titel/auteur automatisch ophalen |
| **Dashboard › Inventarisatie** | QR van de **exemplaretiketten** | Collectie controleren (inventarisatie) |

In alle gevallen: de camera opent binnen AnarBib, leest de code, en klaar. Er
hoeft niets te worden geïnstalleerd. Desgewenst kun je **AnarBib aan het
startscherm toevoegen** op de telefoon (menu van de browser › « Toevoegen aan
startscherm ») : het opent dan als een volschermapp, maar het blijft de
website.
---

## 1. Lezerskaart

**Wie maakt de kaart aan:** de lezer zelf, in de eigen account
(`/conta`), wanneer de bibliotheek de functie heeft ingeschakeld. Die genereert
een QR-code en kan die downloaden als PNG of PDF. De QR bevat enkel een
**ondoorzichtige code** — geen naam, geen persoonsgegevens.

**Hoe jij, aan de balie, te werk gaat:**

1. Ga naar **Dashboard › Lezer beheren**.
2. Klik op **« Kaart scannen »** en richt de camera op de QR van de lezerskaart.
3. AnarBib lost de code op en toont **wie** de lezer is (en of er een actieve
   beperking is). Klaar om uit te lenen, terug te nemen, enz.

> **« Deze kaart is vervangen door een nieuwere »?** Bijna altijd gaat het om
> een **oude kaart**. Wanneer de lezer een nieuwe kaart aanmaakt, wordt de
> vorige **ingetrokken** (veiligheidsmaatregel). Vraag om de actuele kaart te
> genereren of te downloaden. Sinds 15/06 meldt het systeem zelf « kaart
> vervangen door een nieuwere, vraag om een actuele kaart » in dat geval.

---

## 2. ISBN scannen bij het catalogiseren

Bij het opvoeren van een boek met streepjescode (ISBN) hoef je niet alles met
de hand te typen:

1. Open in de boekfiche (catalogiseren) het paneel voor **metagegevens zoeken**.
2. Klik op **« ISBN scannen »** en richt op de **streepjescode** op de
   achterflap van het boek.
3. Het nummer verschijnt automatisch in het ISBN-veld en AnarBib **zoekt de
   gegevens** (titel, auteur…) op in publieke bronnen. Jij bekijkt en past aan —
   de catalogus is van jou.

> **Tip over het apparaat.** Een streepjescode is veeleisender dan een QR. **De
> telefoon leest doorgaans veel beter** dan de webcam van een desktopcomputer
> (scherpstelling en cameraresolutie). Als de webcam het niet oppikt, niet
> aandringen: typ het ISBN met de hand — het resultaat is hetzelfde.

---

## 3. Inventarisatie van de collectie

Exemplaar voor exemplaar nagaan wat er werkelijk in de rekken staat — en dat
vergelijken met wat het systeem denkt dat de bibliotheek heeft.

**Eerst:** de exemplaretiketten moeten een **QR-code** hebben. Druk etiketten
met QR af via **Catalogiseren › Etiketten** (er is een optie « QR-codes
opnemen »). Elke QR verwijst naar het exemplaar.

**De inventarisatie uitvoeren:**

1. Ga naar **Dashboard › Inventarisatie** (zichtbaar voor *bibliothecaris* en
   *coördinator*).2. **« Inventarisatie starten »** — opent een sessie en toont hoeveel exemplaren
   de bibliotheek heeft.
3. De camera blijft open: **ga de exemplaren langs**, de ene QR na de andere. Bij
   elke lezing klinkt een **piep** en loopt de teller op. De camera hoeft niet
   gesloten en heropend te worden tussen de boeken.
   - ✓ groen = exemplaar van de collectie, geteld.
   - « Al gescand » = je had dit exemplaar al gehad (geen probleem, telt niet
     dubbel).
   - ⚠ « Buiten de collectie » = een exemplaar dat **niet** van deze bibliotheek
     is (vreemd).
4. Als een QR beschadigd is, kun je **met de hand typen** (etiket-URL of het
   exemplaarnummer).
5. **« Afronden en rapport bekijken »** — sluit de sessie en toont:
   - **Aanwezig** (gescand en van de collectie),
   - **Ontbrekend** (van de collectie, maar niet gescand → zoeken / afschrijven),
   - **Vreemd** (gescand, maar van een andere bibliotheek / onbekend).
6. Exporteer het resultaat als **CSV** (voor een rekenblad) of **PDF** (om de
   lijst van ontbrekende exemplaren af te drukken en de rekken af te gaan).

> **Pauzeren en hervatten.** Grote inventarisatie? Je kunt later afronden. Als
> je halverwege stopt, blijft de sessie **lopend** en verschijnt ze bij
> « Lopende sessies » om te **hervatten** waar je gestopt was.

---

## Praktische vragen

**Moet ik iets installeren?** Nee. Het is de website zelf. Optioneel: « Toevoegen
aan startscherm » om als app te openen.
**Werkt het in mijn browser?** Ja. In Chrome/Android wordt de ingebouwde lezer
gebruikt (sneller). In **Brave**, **iOS/Safari** en **Firefox** laadt AnarBib
automatisch een alternatieve lezer — het **werkt dus ook** in die browsers. Als
er « scannen wordt niet ondersteund door deze browser » verschijnt bij het
scannen van een ISBN in een van die browsers, ververs de pagina: de alternatieve
lezer laadt vanzelf.

**De camera opent niet.** Controleer of je de website **cameratoegang** hebt
gegeven (slotje in de adresbalk). De browser geeft de camera alleen vrij via
**HTTPS** — `app.anarbib.org` is dat al.

**Privacy.** Het decoderen gebeurt **lokaal**. Het camerabeeld **wordt niet
naar een server gestuurd**. De QR van de lezerskaart bevat enkel een
ondoorzichtige code; de QR van het etiket bevat enkel het adres van het
exemplaar. Gevoelige collecties (BTL en dergelijke) vallen onder dezelfde
beschermingsregels als altijd.

---

## In één zin

De camera is **een uitgestoken hand** om jou typewerk en controlewerk te
besparen — geen verplichting. Gebruik hem wanneer hij helpt; negeer hem wanneer
dat niet zo is. En als hij vastloopt, is het toetsenbord er altijd.

---

*Document van het AnarBib-gemeengoed. Verbeteringen en versies in andere talen
zijn welkom, parallel geschreven door de gemeenschap van elke taal.*
