# Kaderstelling — Onderlinge hulp bij catalogisering (tabblad « Onderlinge hulp » van de Federatie)

**Datum** : 2026-06-15
**Status** : **kaderstelling / ontwerp** — verkennende reflectie die de *visie*,
de *architectuur* en de *principebeslissingen* vastlegt. **Dit is nog geen uit te bouwen spec** :
te bespreken, te beproeven en dan uit te werken in specs.
**Ethisch fundament** : [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
(« de uitgestoken hand »). **Elk scherm hieronder is getoetst aan het raster « uitsteken of
grijpen ? ».** Deze kaderstelling is in zekere zin de eerste concrete toetsing van het charter.

---

## 1. De behoefte

Catalogiseren is het pijnpunt van beginnende bibliotheken (cf. de werven autoriteiten,
materieindexering, discoverywizard). Een bibliotheek die alleen staat tegenover autoriteiten,
onderwerpen en classificatie, raakt geïntimideerd. Het tabblad « Onderlinge hulp » beantwoordt
precies aan deze behoefte — maar anarchistisch catalogiseren is niet neutraal : gangbare
trefwoorden pathologiseren, wissen, benoemen verkeerd. **De onderlinge hulp draagt een
*politiek ambacht* over dat noch standaarden noch een AI kunnen coderen.**

Transversaal principe : **de hulpvraag is generiek** (onderlinge hulp bij *elk* technisch
heikel onderwerp), het **catalogiseren is het eerste gekoppelde domein**.

## 2. Drie graden van onderlinge hulp — een ladder, door subsidiariteit

Niet « het één OF het ander » maar drie *intensiteiten* ; de hulpvraag is het scharnier,
het antwoord neemt een van de drie vormen aan, van het lichtste naar het zwaarste :

1. **De kennengemeenschap** (vademecums, casussen, thesaurus) — nulkosten, nuldependentie,
   100 % tussen gelijken. De duurzame basis.
2. **Mini-wizards** — begeleiden de bibliotheek zodat ze het *zelf doet* (autonomiserend,
   niet afhankelijkheidsscheppend).
3. **Directe menselijke hulp** (oproep → antwoord → eventueel videogesprek) — het meest
   relationele, voor wanneer de gemeenschap en de wizard niet volstaan.

**De neergaande lus** : een hard geval opgelost in graad 3 → samenvatting → wordt een casus/wizard
van graad 1-2 → de volgende keer volstaat de wizard. *De kennis daalt de graden af met de tijd ;
het netwerk wordt met elk episode slimmer en zelfvoorzienender.*

## 3. De kennengemeenschap — de autonomielaag

Drie lagen, en de diepste is **het vocabulaire zelf** :

- **De thesaurus, politiek hart.** Geen woordenlijst : een *conceptgraph*. De politiek leeft
  in de **termen**, de **relaties** (broader/narrower/related) en de **toepassingsnoten**
  (die micro-vademecums zijn). Bouwen op **SKOS** (vrije standaard) — een norm overdragen,
  geen bricolage. Een zaad bestaat (thesaurus ~30 categorieën).
- **Casussen & vademecums** — uitgewerkte voorbeelden, bewerkbaar, opduikend *op het moment
  van behoefte*.
- **Wizards in *data*, niet in *code*** — *de autonomiegok* : als een wizard code is, zijn
  we voor altijd afhankelijk van ontwikkelaars ; als hij een **gestructureerd document** is
  (boom van vraagkaarten → eindkaarten) dat een eenmalig-geschreven motor uitrolt, **kan
  elke bibliotheek er een schrijven zonder te coderen**. Vangrails zodat het geen vermomd
  programmeertaal wordt : geen variabelen/berekening/vrije conditie ; enige toestand = het
  afgelegde pad ; eventuele condities uit een gesloten lijst ; **de wizard *adviseert*, schrijft
  *nooit*** (ergste mislukking = « niet nuttig », nooit « catalogus kapotgemaakt ») ; kleine,
  monothematische wizards.

**Meertalig zonder AI** : de i18n-schil (10 talen) draagt de interface ; de *inhoud*
(termen, casussen) wordt **per taalgemeenschap geschreven** (parallelle cross-linked schrijfwijze,
geen top-down vertaling) — traag maar duurzaam en gratis. **Governance** : toevoeging/wijziging
van een term via de **instemming/bezwaar**-stroom van de kringen ; politieke schuifregelaar
« toegelaten varianten vs convergentie » te plaatsen door het netwerk.

## 4. Het activeringsmoment — op het punt van behoefte (charter ③)

**De trigger is het *veld*, het *gegeven*, of de *vraag* — nooit bewaking van de persoon.**
Gedragssignalen verbieden (« 5 min op het veld », aarzelingen) : dat is Clippy *en* bewaking
van het werk. Drie eerlijke triggers :
- **intrinsiek aan het veld** (onderwerpen/autoriteit zijn moeilijk *voor iedereen* → hulp
  altijd aanwezig) ;
- **afgeleid van het gegeven** (geen ISBN, ambigue auteur → het boek signaleert, niet de
  persoon) ;
- **expliciete vraag** (« help » rustig, altijd binnen handbereik).

De hulp klimt **de ladder één-klik-verder** (inline → wizard → kring), **discreet maar
vindbaar** (betrouwbare plaatsing, nooit modaal/gegamificeerd), met een **aanwezigheid in
curve per domein** (iets meer uitnodigend bij leeg veld + klein aantal records ; verdwijnt
naarmate de beheersing groeit ; altijd handmatig in te klappen).

## 5. Twee schermen al getoetst aan het raster

### 5.1 — Het « ? » onder een moeilijk veld (catalogisering)
Aanwezig *omdat het veld lastig is voor iedereen* (inkadering als waardigheid, niet « u lijkt
moeite te hebben »). Als men het opent : thesaurussuggesties inline + casussen uit de gemeenschap
→ « begeleide weg » (wizard) → « vraag aan de kring » (graad 3, moment van instemming).
**Het raster heeft twee verleidelijke features gedood** : ❌ aarzeling detecteren om hulp voor
te stellen (bewaking, facet ③) ; ❌ badges/reeksen/balk naar « deskundige » (facet ⑥).
**Aangehouden standaarden** : het scherm « eerste keer ? begeleide weg » *aangeboden maar in
aanbodsregister* ; « ? » altijd zichtbaar, suggesties **uitgevouwen bij klik** (discreet + vindbaar).

### 5.2 — De afsluiting van de episode + vastlegging voor de gemeenschap
Einde **geïnitieerd door de geholpene** (geen auto-close, geen afsluiting door de helper).
Sober « dankjewel »-scherm, **niets eraan gehaakt** (anti-schuldkoppeling). **Plumhaak**
« contact houden ? » symmetrisch, negeerbaar, maakt niets aan tenzij dubbel-ja.
**Vastlegging voor de gemeenschap zonder schuld** : men nodigt de **helper** uit (die de nieuwe
kennis bezit), niet de geholpene ; **micro-bijdrage gehaakt aan het object** (noot bij een
term/veld), **aangedreven door de trace** van de episode ; dan wordt **de geholpene uitgenodigd
om te herlezen/verrijken** (« wat echt moeilijk was ») — *haar stem, af te wijzen, nooit een
oordeel van de helper*, en **niet-blokkerend** (de noot staat alleen).
**Het raster heeft gedood** : ❌ « beoordeel je ervaring » (vermomd klassement) ; ❌ voltooiingsbadge.

## 6. Vertrouwelijkheid

De catalogusdata is *minder* gevoelig dan de lezerdata (metagegevens over *boeken*, nooit
exemplaren/leningen/identiteiten), **maar niet nul** (de fondsen van een anarchistische bibliotheek
kunnen politiek gevoelig zijn ; cf. het onderscheid `visibility_level='network'` / BTL). Dus :
- **opt-in per item** (nooit een dump), **BTL/gevoelig standaard uitgesloten** ;
- **de helper *stelt voor*, de eigenaar *valideert*** — nooit rechtstreeks schrijven door een derde ;
  toegang **gescopet, herroepbaar, geauditeerd** ;
- de stap **« vraag aan de kring » IS het moment van instemming** (« je gaat deze items tonen
  aan bibliotheek X — hier is wat naar buiten gaat ») ;
- **de gemeenschap legt *generiek gede-identificeerd ambacht* vast, geen *identificerende casussen*** ;
  bijzonderheden worden gestript of ingestemd.

Antwoord op de vraag « absoluut recht om te delegeren ? » : **ja op autonomie, maar instemming
*verlicht en gekaderd*, geen blanco cheque** — het risico klein maken en bewust laten nemen.

## 7. Koppeling & rijping in partnerschap

- **Zachte sortering, geen harde filter.** In een verspreid netwerk is een EN (zelfde taal EN
  geo EN beschikbaar EN deskundig) = lege verzameling. Men **sorteert** op affiniteit (taal ↑,
  tijdzone ↑, vrijwilliger ↑) zonder **uit te sluiten** ; subsidiariteit **kring eerst → netwerk
  bij stilte**. De **relevante kring hangt af van het type hulp** (catalogisering → linguïstisch ;
  materieel/repressie → geografisch).
- **Eerste gebaar zonder voorafgaande** : vrijwillig zijn voor *één* actie vereist geen kring
  noch profiel. **Lidmaatschap accumuleert door gebaren** (erkend instemming, nooit etiket).
- **Anti-hiërarchie** : geen individuele reputatie, geen marktplaats ; opgegeven beschikbaarheid,
  zichtbare wederkerigheid zonder score, rotatie.
- **Rijping in partnerschap (§21)** — *tweede fase die de schaarste oplost* : een goed episode
  kan **rijpen** tot partnerschap → toekomstige hulp is *vooraf gekoppeld* (taal, tijdzone,
  instemming al gegeven) ; het netwerk **verdicht**. **Ontkoppeld** van de episode (nooit in
  het moment = schuld) ; **na herhaling** (erkenning, niet creatie) ; **symmetrisch dubbel-opt-in** ;
  **diepteladder** (0 → contact-houden → gezelschap → formeel partnerschap) ;
  **schuldomkering** (het partnerschap is een *cadeau* aan de geholpene : « een kameraad om
  opnieuw te bellen zonder opnieuw toestemming te vragen », geen verschuldigde terugbetaling) ;
  altijd **opzegbaar**.

## 8. Het videogesprekplugin (graad 3)

De menselijke hulp koppelen aan een **Jitsi-videogesprek** (synchroon = efficiënte overdracht) ;
vijver = **linguïstische kring**. **Async eerst, videogesprek als optionele turbo** (de meest
precaire persoon heeft een slechte verbinding → graden 0-2 in tekst/offline).
Technisch, « gratis » : **de integratie eenmalig coderen via de iframe API met het `domain`
in de config** → nooit vergrendeld aan een leverancier. Standaard verwijzen naar een **militante
Jitsi-instantie** (meest in lijn met de doctrine, gratis, geen GAFAM) ; bij gebrek `meet.jit.si`
(met aanvaarding van de auth van de kameraaoprichter). Kamers **efemeer, niet-raadbare naam,
lobby**. **Nul server, nul geheim, nul terugkerende kosten.** Zelf-gehoste blijft *parking*
(VPS afgewezen).

## 9. Kosten & autonomie

Alles (gemeenschap, wizards, panelen, matching, videogespreklink) **draait op de bestaande stack**
(Supabase + statisch front) : **nul marginale kosten, zonder AI om te draaien**. AI blijft een
**optionele en ontkoppelbare versneller** (pre-catalogisering van het *neutrale* enkel ;
het politieke blijft tussen kameraden). **De organen bestaan al** : thesauruszaad, discoverywizard,
i18n 10 talen, instemming/bezwaar-stroom van de kringen, §21 partnerschap. **Deze kaderstelling
verbindt bestaande organen — vandaar haar bescheidenheid, en haar onafhankelijkheid van kosten
en externe afhankelijkheden.**

## 10. Genomen beslissingen / openstaande vragen

**Genomen (in de loop van de reflectie) :**
- Drie graden in ladder + neergaande kennislus.
- Gemeenschap = thesaurus (SKOS, politiek hart) + casussen + **wizards in data**.
- Activering door veld/gegeven/vraag, **nooit bewaking** ; ladder één-klik ;
  aanwezigheid in curve per domein.
- Scherm « ? » : standaarden (aanbod, suggesties bij klik) ; geweigerd (hezitatingdetectie,
  gamificatie).
- Afsluiting : geholpene sluit ; **helper schrijft → geholpene verrijkt** (nulschuld) ;
  gemeenschap = **generiek ambacht** ; governance **additief = 2 personen / vocabulaire = collectief**.
- Matching **zachte sortering + kring eerst** ; kring **naar type hulp** ; eerste gebaar zonder
  voorafgaande ; **lidmaatschap door het gebaar**.
- Rijping §21 **ontkoppeld, na herhaling, dubbel-opt-in, diepteladder, schuldomkering, opzegbaar**.
- Videogesprek **Jitsi `domain` configureerbaar**, async-first, nul infra/geheim.
- (Mailherinnering, al gekoppeld buiten deze kaderstelling) taal van de ontvanger = **zijn persoonlijke voorkeur**.

**Open (politieke schuifregelaars te plaatsen door het netwerk) :**
- **Initieel onthaalsniveau** (gastvrijheid) en **wie het bepaalt** : netwerk / kring / bibliotheek /
  persoon. Piste : de nieuwkomer *vragen* naar haar ontvangst (instemming) + subsidiariteit
  (het hogere vult alleen de stilte) + optie *persoonlijk peterschap* door een vrijwilliger van de kring.
- Niveau van **aanwezigheid van de plumhaak** en de uitnodiging tot de gemeenschap (aangeboden vs
  beschikbaar) — grotendeels ontmijnd door de **semantiek** (aanbodsregister ≠ gebod).
- Concrete vorm van de **editor van de wizard-in-data** (hoe ver zonder code te worden).
- Schuifregelaar **varianten vs convergentie** van de thesaurus.

## 11. Status

Kaderstelling om **te bespreken en te beproeven**, geen bouworder. Wanneer een onderdeel rijp
is, wordt het uitgewerkt als spec, en elk scherm wordt opnieuw getoetst aan het **raster van
het relationele charter**.
