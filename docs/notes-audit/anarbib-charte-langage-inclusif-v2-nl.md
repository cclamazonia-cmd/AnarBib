# Inclusieve-taalcharter van AnarBib

**Versie** : 2.0
**Datum** : 2026-06-05
**Status** : referentiedocument van het project (enige gezaghebbende bron)
**Vervangt** : `anarbib-charte-langage-inclusif-v1.md` (v1.0, 2026-04-28), voortaan **verouderd**

Dit document legt de inclusieve-taalconventies vast die zijn aangenomen in de **tien
talen** van AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`,
`el`). Het is van toepassing op elke nieuwe vertaling, elke revisie en elke toekomstige
bijdrage. Het richt zich tot iedereen die bijdraagt aan de bestanden
`src/i18n/locales/*.json`, aan de mailnotificatieteksten
(`supabase/functions/_shared/i18n/mail-strings.ts`), en aan elke daarna gegenereerde
vertaling.

> **Evolutie ten opzichte van v1** : v1 behandelde slechts zes talen (`pt-BR`, `fr`,
> `es`, `en`, `it`, `de`). V2 voegt `ca`, `eo`, `nl`, `el` toe, en **officieel maakt
> de Italiaanse conventie** (asterisk voor regelmatige paren, slash voor onregelmatige
> paren) die de voorlopige slash van v1 vervangt.

---

## Inhoud

1. [Waarom dit document](#waarom-dit-document)
2. [Leidend principe : interne consistentie per taal](#leidend-principe--interne-consistentie-per-taal)
3. [Statustabel](#statustabel)
4. [Charter per taal](#charter-per-taal)
   - [Frans (fr)](#frans-fr)
   - [Duits (de)](#duits-de)
   - [Engels (en)](#engels-en)
   - [Braziliaans Portugees (pt-BR)](#braziliaans-portugees-pt-br)
   - [Castiliaans Spaans (es)](#castiliaans-spaans-es)
   - [Italiaans (it)](#italiaans-it)
   - [Catalaans (ca)](#catalaans-ca)
   - [Esperanto (eo)](#esperanto-eo)
   - [Nederlands (nl)](#nederlands-nl)
   - [Grieks (el)](#grieks-el)
5. [Politieke referentiebegrippen](#politieke-referentiebegrippen)
6. [Verboden termen](#verboden-termen)
7. [Procedure voor toekomstige toevoegingen](#procedure-voor-toekomstige-toevoegingen)
8. [Testdekking (CI)](#testdekking-ci)
9. [Evolutie van het charter](#evolutie-van-het-charter)

---

## Waarom dit document

AnarBib is een geïntegreerd bibliotheekmanagementsysteem ontworpen voor militante
anarchistische bibliotheken. Een militante bibliotheek is geen gewone bibliotheek : ze
archiveert niet alleen documenten, ze vormt **een collectief geheugen**, en de taal van
haar interface maakt deel uit van dat geheugen. Een interface die « lecteur » gebruikt
als generiek mannelijk reproduceert precies het uitwisgebaar dat een feministische of
queer bibliotheek wil ontbinden ; een interface die « compagn·e·s » zegt, signaleert
bij de allereerste seconde tot welke beweging ze behoort.

Maar inclusieve taal is geen universele norm. Elke taal heeft haar eigen geschiedenis,
haar eigen militante conventies, haar eigen politiek gemijnde terreinen. **Er bestaat
geen « correcte » transversale inclusieve schrijfwijze** : er bestaan lokale, gesitueerde
keuzes, verdedigd door gesitueerde militante gemeenschappen. Dit charter respecteert
die lokale situaties en garandeert tegelijkertijd dat AnarBib binnen één en dezelfde
taal met één stem spreekt.

Drie concrete doelen :

1. **Consistentie.** Binnen hetzelfde taalbestand wordt dezelfde genderpositie altijd op
   dezelfde manier geschreven.
2. **Respect voor lokale militante culturen.** Geen conventie van de ene taal opleggen
   aan de andere.
3. **Leesbaarheid door niet-specialisten.** Een militante bibliothecaris die AnarBib
   ontdekt, moet het kunnen gebruiken zonder expert in inclusieve typografie te zijn.

---

## Leidend principe : interne consistentie per taal

Elke taal van AnarBib past **zijn eigen typografische conventie voor inclusief schrijven**
toe, ontleend aan het lokale militante gebruik. Geen transversale conventie wordt opgelegd.

Binnen een taal zijn **deze conventies verplicht en exclusief** : een `fr.json`-bestand
mengt de middenpunt niet met `(e)`'s ; een `it.json`-bestand mengt de asterisk niet met
de middenpunt. De keuzes in dit charter zijn de **officiële vorm** van AnarBib voor
die taal.

---

## Statustabel

| Taal | Conventie | Status |
|---|---|---|
| `pt-BR` | Drievoudige vorm `(o/a/e)` | **Aangenomen** (referentie) |
| `fr` | Middenpunt `·` | **Aangenomen** |
| `es` | Neutraal `e` (Argentijnse conventie) | **Aangenomen** |
| `en` | Epiceen + enkelvoudig `they` | **Aangenomen** |
| `de` | Genderstern `*` | **Aangenomen** |
| `it` | Asterisk (regelmatig) / slash (onregelmatig) | **Aangenomen** |
| `ca` | Drievoudige uitgang `-a-e` + lidwoord `le` | **Aangenomen** |
| `eo` | Infix `-in-` zichtbaar gemaakt door koppeltekens + voornaamwoord `ri` | **Aangenomen** |
| `nl` | Neutrale rolvormen | **Voorlopig** — te valideren in gemeenschap |
| `el` | — | **Te bepalen** met een Griekssprekende militante medewerker |

---

## Charter per taal

### Frans (fr)

**Aangenomen conventie** : middenpunt (`·`, U+00B7).

**Generieke vorm** : gemeenschappelijke stam + middenpunt + vrouwelijke uitgang.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Meervoud** : men voegt `·s` toe (`lecteur·rice·s`).
**Gecombineerde lidwoorden / bepalers** : `le·la`, `du·de la`, `au·à la`, `un·e`,
`le·la SEUL·E`, `actif·ve`.
**Reeds epicene woorden** : ongewijzigd (`bibliothécaire`, `camarade`, `responsable`,
`personne`).
**Verboden** : `(e)`, afzonderlijk `-e` (conventies van vóór 2010), gewone punt `.` of
opsommingsteken `•` in plaats van de middenpunt.

### Duits (de)

**Aangenomen conventie** : Genderstern (`*`, ASCII-asterisk U+002A).

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Meervoud** : `*innen` (`Genoss*innen`, `Leser*innen`).
**Verboden** : Mediopunkt `·`, Genderdoppelpunkt `:innen`, en het Spaanstalige neologisme
*« Compas »* onvertaald laten (altijd `Genoss*in`/`Genoss*innen`).

### Engels (en)

**Aangenomen conventie** : epicene termen als standaard, `they/them/their` in het
enkelvoud als neutraal voornaamwoord.

De Engelse grammatica is grotendeels epiceen : men gebruikt stelselmatig de bestaande
neutrale vorm (`reader`, `librarian`, `author`, `administrator`,
`comrade`, `coordinator`, `user`), zonder typografische markering. Voor de zeldzame
gegenderde termen kiest men de epicene vorm (`actor` in plaats van `actress`,
`server` in plaats van `waitress`).
**Verboden** : `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Braziliaans Portugees (pt-BR)

**Aangenomen conventie** : drievoudige vorm `(o/a/e)` of `(a/e)` naargelang de
grammatica, waarbij expliciet de drie posities worden opgenomen (vrouwelijk, mannelijk,
niet-binair). **Dit is de referentietaal van het project.**

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Regel** : woorden op `-or` → `(a/e)` ; woorden op `-o` → `(o/a/e)`. Uitgangen in
alfabetische volgorde binnen de haakjes.
**Samentrekkingen lidwoord-voorzetsel** : `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`,
`(o/a/e)s`.
**Reeds epicene woorden** : ongewijzigd (`camarada`, `colega`, `responsável`,
`pessoa`).
**Verboden** : `(a)` alleen, `/a`, `/o`, `@` (arroba), `x`. Let op het
**valse vriend `camarade`** (Franse vorm) : in pt-BR is het **`camarada`**.

### Castiliaans Spaans (es)

**Aangenomen conventie** : neutraal `e` (Argentijnse militante conventie).

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Regel** : men vervangt de gendervocaal aan het einde (`-o`/`-a`) door `-e` ; woorden
op `-or` → stam + `-e` (`lector → lectore`).
**Meervoud** : `-s` (`compañeres`).
**Lidwoorden / bepalers** : `le` (enkelvoud neutraal), `les` (meervoud neutraal).
**Vervoegde deelwoorden** : `informade`, `conectade`, `active`.
**Reeds epicene woorden** : ongewijzigd (`camarada`, `colega`, `responsable`,
`persona`).
**Verboden** : `(a)`, `/a`, `/o`, **de drievoudige vorm `(o/a/e)` van pt-BR**
(Spaans gebruikt ENKEL het neutrale `e`), `@` (arroba), `x` (Latinx), en de
**middenpunt `·`** (Franse conventie, niet te gebruiken in het Spaans).

### Italiaans (it)

**Aangenomen conventie — officieel** : **asterisk `*` voor regelmatige paren,
afgekorte slash voor onregelmatige paren.** Deze conventie vervangt de voorlopige
slash van v1.

#### Regelmatige paren (gemeenschappelijke stam op `-o`/`-a`) → asterisk `*`

Wanneer de mannelijke en vrouwelijke vorm **dezelfde stam** delen, vervangt men de
genderuitgang door een asterisk, voor consistentie met de Duitse Genderstern.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(déjà épicène au sing.)* |

Van toepassing ook op **vervoegde deelwoorden en adjectieven** : `stat*` (stato/a),
`ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a),
`benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*`
(questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Onregelmatige paren (verschillende stammen, type `-tore`/`-trice`) → afgekorte slash

Wanneer het vrouwelijke de stam van het mannelijke niet deelt (`lettore` → `lettric-e`),
is de asterisk **foutief** (`lettor*` zou een niet-bestaande vrouwelijke vorm
`lettora` suggereren). Men gebruikt daarom de **afgekorte slashvorm**, die de *house style*
is die in het depot is vastgelegd.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Onregelmatig meervoud** : `lettori/trici`, `amministratori/trici`,
`coordinatori/trici`.
**Lidwoorden** : `il/la`, `del/la`, `al/la`, `dal/la` (afgekorte vorm), `un*` voor
`uno/una`.
**Reeds epicene woorden** : ongewijzigd (`utente`, `responsabile`, `persona`,
`collega`).

#### Noot over het teken `·`

De middenpunt `·` is **geen** inclusief markeerteken in het Italiaans : hij dient
uitsluitend als **typografisch scheidingsteken** in mailonderwerpen en metadataregels
(`Email · ID · Genere`). Gebruik hem nooit als gendermarkering.

**🚫 Absoluut verboden** : **`camerata` / `camerati` / `cameratesco`** — fascistische
interne aanspreking (PNF, MSI, CasaPound, Forza Nuova, FdI). Gebruik `compagn*` en zijn
varianten. **Dit verbod wordt getest in CI** (`i18n.test.js` en
`mail-strings.test.ts`).
**Andere verboden vormen** : `(a)`/`(o)` haakjes, drievoudig `/trice/e`, suffix
`/x`, middenpunt `·` als gendermarkering.

**Militante motivering** : de asterisk (*asterisco*) is gedocumenteerd in Italiaanstalige
anarchistische en autonome kringen (Carmilla, DinamoPress, InfoAut,
Wu Ming), en biedt visuele consistentie met de Duitse Genderstern. De afgekorte slash
voor onregelmatige paren vermijdt onjuiste vrouwelijke vormen en blijft leesbaar.

### Catalaans (ca)

**Aangenomen conventie** : drievoudig suffix `-a-e` + neutraal lidwoord `le`.

| Masculin | Féminin | Forme AnarBib |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Haakjesvariant** aanvaard voor samentrekkingen :
`lector(a/e)`, `coordinador(a/e)`.
**Neutraal bepaler** : `le` (`le lector-a-e`).
**Meervoud** : `-s` of gecombineerde vorm `els-les-les` / `als-a les-a les`.
**Reeds epicene woorden** : ongewijzigd.

> Het Catalaans gebruikt ook de punt volat `·` in de **geminaat `l·l`**
> (`col·lectiu`, `cancel·lada`, `sol·licitud`) : dit is een **standaard Catalaanse
> spellingsregel**, zonder verband met inclusiviteit. Niet aanpassen.

### Esperanto (eo)

**Aangenomen conventie** : infix `-in-` zichtbaar gemaakt door koppeltekens + neutraal
voornaamwoord `ri`.

| Base | Forme AnarBib |
|---|---|
| leganto (lecteur·rice) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Niet-binaire variant** : suffix `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Neutraal voornaamwoord** : `ri`.
**Meervoud** : `-j` (`legant-in-oj`).

### Nederlands (nl)

**Status : VOORLOPIG — te valideren in gemeenschap.**

**Voorlopige oriëntatie** : de voorkeur geven aan bestaande **neutrale rolvormen**
boven typografische markering.

| Concept | Forme provisoire |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Voorlopige regels** : gendergebonden achtervoegsels `-ster`/`-e` vermijden wanneer
een neutrale vorm bestaat ; niet-binair voornaamwoord `die` (of `hen`/`hun`) — **gebruik
nog niet vastgesteld**.

> ⚠️ Deze conventie is **niet** definitief. Ze moet worden gevalideerd door
> Nederlandssprekende militante medewerkers vóór ze wordt vastgelegd. Tot die tijd
> bij de neutrale vormen blijven.

### Grieks (el)

**Status : TE BEPALEN CONVENTIE.**

Er bestaat **geen consensuele typografische standaard** voor inclusief schrijven in het
Grieks. **Geen markering bij voorbaat voorstellen.** De conventie zal worden vastgesteld
**met een Griekssprekende militante medewerker** die bij het project aansluit.

**Overgangsbenadering** (in afwachting) : doubletten of bestaande neutrale vormen
(`αναγνώστης/στρια`, `συντονιστής/στρια`), monotonisch Grieks, 2de persoon enkelvoud
voor tutoyering van de lezer (vousvoyering voor het team). Afkorting AVG → `ΓΚΠΔ`.

> ⚠️ Elke voorgestelde systematische inclusieve typografische markering voor het Grieks
> is **voorbarig** zolang geen Griekssprekende militante medewerker bij het project is
> aangesloten.

---

## Politieke referentiebegrippen

### Kameraad / Compagn·e

| Langue | Forme officielle | Pluriel |
|---|---|---|
| 🇫🇷 fr | `camarade` *(épicène)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(épicène)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(épicène)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagn*` | `compagn*` |
| ca | `camarada` *(épicène)* | `camarades` |
| eo | `kamarad-in-o` | `kamarad-in-oj` |
| nl | `kameraad` *(provisoire)* | `kameraden` |
| el | `σύντροφος` *(à confirmer)* | — |

### Lezer

| Langue | Forme officielle |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/trice` |
| ca | `lector-a-e` |
| eo | `legant-in-o` |
| nl | `lezer` *(provisoire)* |
| el | `αναγνώστης/στρια` *(transitoire)* |

### Bibliothecaris

| Langue | Forme officielle |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(épicène)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecari*` |
| ca | `bibliotecari-ària-e` |
| eo | `bibliotekist-in-o` |
| nl | `bibliothecaris` *(provisoire)* |
| el | `βιβλιοθηκάριος` *(à confirmer)* |

### Beheerder

| Langue | Forme officielle |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/trice` |
| ca | `administrador-a-e` |
| eo | `administrant-in-o` |
| nl | `beheerder` *(provisoire)* |
| el | *(à définir)* |

---

## Verboden termen

### Politiek geladen (absoluut verbod)

| Term | Taal | Reden |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Fascistische interne aanspreking (PNF, MSI, CasaPound, Forza Nuova, FdI). **Getest in CI.** |
| `Compas` *(onvertaald)* | 🇩🇪 de | Spaanstalig neologisme ongewijzigd gelaten — gebruik `Genoss*in`/`Genoss*innen`. |

### Bureaucratische of ongeschikte typografische conventies

| Vorm | Betrokken talen | Waarom |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Administratieve vorm, niet militant. |
| `@` (arroba) | pt-BR, es | Verouderd, toegankelijkheidsprobleem (schermlezers). |
| `x` (Latinx) | es, pt-BR | Vervangen door neutraal `e` in hedendaags militant gebruik. |
| `(e)`, afzonderlijk `-e` | fr | Conventie van vóór 2010, vervangen door de middenpunt. |
| `Genderdoppelpunkt` (`:innen`) | de | Geldig maar niet gekozen voor consistentie met `*`. |
| `he/she`, `s/he`, `(s)he` | en | De voorkeur geven aan enkelvoudig `they/them`. |
| Drievoudig `(o/a/e)` | es | Voorbehouden aan pt-BR ; Spaans gebruikt enkel het neutrale `e`. |
| Middenpunt `·` als gendermarkering | es, it, ca | Franse conventie ; elders is `·` slechts een scheidingsteken (of de geminaat `l·l` in ca). |
| Drievoudig `/trice/e`, suffix `/x` | it | Misvormde vormen ; gebruik afgekorte slash `/trice`. |

---

## Procedure voor toekomstige toevoegingen

### Wanneer een nieuwe i18n-sleutel wordt toegevoegd

1. **Identificeer** het te vertalen woord/uitdrukking. Betreft het een term die gegenderd moet worden?
2. **Zo ja, kies de epicene vorm waar die bestaat** (`camarada` pt-BR,
   `responsable` fr, `utente` it…).
3. **Zo niet, pas de conventie van de taal toe** zoals hierboven bepaald.
4. **Voor het Italiaans** : maak onderscheid tussen regelmatig paar (asterisk) en
   onregelmatig paar (afgekorte slash).
5. **Controleer de consistentie** met de rest van het bestand.
6. **Vul alle 10 talen in één doorgang in.** Een gedeeltelijk vertaalde sleutel is een bug. De **pariteit van sleutels** tussen de 10 talen is verplicht.

### Wanneer een bestaande vertaling wordt gelezen

1. Spoor de **verboden** markeringen op (`(a)`, `@`, `camerata`, middenpunt buiten
   fr/ca-geminaat, drievoudig `/trice/e`…).
2. Vervang ze door de officiële vorm van de taal.
3. Controleer de consistentie enkelvoud/meervoud.
4. Controleer de consistentie tussen talen voor dezelfde sleutel.

### Wanneer een vertaling aan een AI wordt gevraagd

Geef dit charter altijd mee als context, specificeer de verwachte conventie voor de
doeltaal en de verboden termen, geef de voorkeur aan epicene vormen, en **controleer het
resultaat** vóór integratie.

---

## Testdekking (CI)

- `src/tests/i18n.test.js` test de **pariteit van sleutels** en de **conformiteit** van
  **8 talen** : `pt-BR, fr, en, de, it, es, ca, eo`. Het bevat de blokkerende test
  « Italiaans mag nooit camerata/camerati bevatten ».
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) test de
  mailstrings : pariteit, verboden termen (camerata), interpolatie, fallback.
- ⚠️ **`nl` en `el` worden NIET gedekt door de CI-gate** : hun sleutelpariteit
  en conformiteit worden niet automatisch gegarandeerd. **Backlog** : ze toevoegen aan
  `i18n.test.js` zodra hun conventies zijn vastgesteld.

---

## Evolutie van het charter

Dit charter is een levend document. Het kan worden aangepast volgens de volgende
principes :

- **Toevoegingen van politieke referentiebegrippen** : door een collectieve beslissing
  gedocumenteerd in het depot (issue of pull request).
- **Wijziging van de conventie van een taal** : vereist de deelname van ten minste één
  militante moedertaalspreker van de betrokken taal. De wijziging moet politiek en
  technisch gemotiveerd zijn.
- **Vaststelling van voorlopige (`nl`) of te bepalen (`el`) conventies** : volgt
  hetzelfde protocol — een lokale militante typografische keuze, gemotiveerd, gevalideerd
  door moedertaalsprekers, dan opgenomen in dit charter en toegevoegd aan de CI-gate.
- **Toevoeging van een nieuwe taal** : zelfde protocol.

---

*Charter v2 opgesteld op 2026-06-05 na de audit van inclusief taalgebruik in de
tien talen en de mailstrings. Referentiedocument te committen in
`notes-audit/` van het depot. Vervangt v1.0 van 2026-04-28.*
