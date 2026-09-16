# Bonvenon en la reton AnarBib

**Akcepta gvidilo por la kunordigoj — la unuaj tridek tagoj**

*Versio 1.0 — 16-a de septembro 2026 · Permesilo AGPLv3 · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Antaŭ ĉio: kio estas akceptita, kaj kio ankoraŭ ne

La kandidatiĝo de via biblioteko estis akceptita de la kunordigo de la reto. Tio signifas
du aferojn, kaj nur du:

1. La reto rekonas vian bibliotekon kiel parton de la anarkiisma kaj liberecana familio
   kiun ĝi akceptas, kaj ĝi malfermis al vi la vojon de la konstituiĝo.
2. Via konto ne plu estas konto de petanto: ĝi estas konto de **kunordigo en
   konstituiĝo**.

Kio ankoraŭ **ne** okazis: via biblioteko ne estas aktiva. Ĝi ne aperas en la komuna
katalogo, ĝi ne ricevas legantojn, ĝi interŝanĝas nenion kun la aliaj bibliotekoj. Ĝi
estas **antaŭaktiva**, kaj estas vi kiu eltiros ĝin el tie — ne sola, kaj ne en unu tago.

> **La promeso de ĉi tiu gvidilo.** Vi ne bezonas esti bibliotekisto. Vi ne bezonas esti
> komputilisto. Vi bezonas scii kion via kolektivo volas, kaj havi iun kiun demandi kiam
> vi ne scias. La cetero estas klaki.
>
> **Kaj la ora regulo: klaku, nenio rompiĝos.** La programo ne montras la neeblajn
> transirojn, malaktivigas kun klarigo la butonojn kiujn regulo blokus, kaj rifuzas en la
> datumbazo la neeblajn kombinojn. La malmultaj gestoj kiuj vere ne reireblas estas
> listigitaj en ĉapitro 9.

**La persono al kiu paroli.** En ajna momento de ĉi tiu vojo, antaŭ ol decidi kaj ne
poste: `anarbib@proton.me`. La reto havas kiel principon ke decido pri konstituiĝo
diskutiĝas kun kamarado antaŭ ol fariĝi formularo. Skribi ne estas konfeso de malforteco
— ĝi estas la normala funkciado.

---

## 1. Tago 1 — Eniri, kaj kompreni kie vi estas

### 1.1 Konektiĝi

La konektpaĝo estas `/login` (butono **Ensaluti**). La adreso `/cadastro` nur alidirektas al ĝi: se malnova
dokumento sendas vin tien, tio ne estas via eraro.

Se vi ankoraŭ uzas la provizoran pasvorton ricevitan retpoŝte, **ŝanĝu ĝin antaŭ ĉio
alia**. Dum ĝi ne estas ŝanĝita, pluraj agoj restas blokitaj — tio estas pasiva pruvo ke
la konto vere estis prenita en manojn de persono.

### 1.2 La du domoj

Tio estas la plej grava afero de la tuta gvidilo, kaj ĝi indas esti lernita parkere.

| Se la demando estas… | Vi iras al… |
|---|---|
| « kion ni decidis? » | **`/biblioteca`** — la kolektiva domo |
| « kion mi faras kun ĉi tiu persono antaŭ mi? » | **`/painel`** — la giĉeto |

En `/biblioteca` loĝas la publika identeco, la regularo, la teamo, la adopta profilo, la
transiroj kaj la privateco: ĉio kion la kolektivo pridiskutis. En `/painel` loĝas la
ĉiutaga laboro: pruntoj, redonoj, konsultoj, rezervoj, kontoj atendantaj validigon.

Tio ne estas arbitra ordigo. Multaj bibliotekaj programoj miksas la du, kaj la rezulto
estas ke la politika agordo finiĝas kaŝita en administranta fonoficejo. Ĉi tie, la
pridiskutado estas unuflanke kaj la funkciado aliflanke.

### 1.3 La vojoj kiujn vi uzos

| Vojo | Kio ĝi estas | Por kiu |
|---|---|---|
| `/criar-conta` | aliĝo — **la sola enirpordo, por ĉiuj** | iu ajn |
| `/conta` | la persona spaco de ĉiu leganto — naŭ langetoj | ĉiu persono, nur la sian |
| `/atelier` | la metiejoj: konstituiĝo kaj aŭtoritatoj | kunordigo en konstituiĝo |
| `/painel` | la giĉeto, la taga laboro | teamo (librarian, kunordigo) |
| `/biblioteca` | la kolektiva domo, la decidoj | teamo, kun povoj laŭ rolo |
| `/catalogacao` | katalogi kaj importi | teamo |
| `/rede` | administrado de la reto | nur retaj administrantoj |

La paĝo **Federação** kaj la publikaj paĝoj — katalogo, Verko, Periodaĵo, Temo,
Bibliotekoj, Kartografio, Tezaŭro FICEDL — kompletigas la tuton. La vojoj ne estas
tradukitaj: ili estas la samaj en la dek lingvoj.

> **Vi neniam eniras la konton de alia persono.** Ĉio kion la teamo devas fari por
> leganto troviĝas en la painel. Se vi kaptis vin volanta « eniri kiel » iu, tio kion vi
> serĉas estas en la painel, langeto **Leganto** (`leitor`).

---

## 2. Tagoj 1 ĝis 3 — La metiejo de konstituiĝo

La konstituiĝo estas vojo en `/atelier`. Vi povas konservi en ajna momento kaj reveni
poste: nenio perdiĝas inter du seancoj. **Vi havas 60 tagojn**, kaj memorigo retpoŝta
alvenas je la 45-a.

### 2.1 Etapo 0 — la adopta profilo, la fonda akto

Antaŭ ĉiuj aliaj sekcioj, la programo demandas kie via biblioteko sin metas sur **kvar
sendependaj aksoj**. Neniu el ili estas nivelo de kvalito: temas pri manieroj ekzisti, kaj
malgranda biblioteko kiu elektas la simplan reĝimon ĉie ne estas nefinita biblioteko.

**Akso 1 — `catalog_mode`, la katalogo**

- `local_only` — la kolekto restas hejme, ne elmetita al la reto. Utila dum enkuriĝa
  periodo, aŭ kiam parto de la kolekto ne estas preta por publikigo.
- `network_published` — la kolekto eniras la komunan katalogon AnarBib.

**Akso 2 — `circulation_mode`, la cirkulado**

- `off` — neniu cirkulado mastrumata en la programo: nur katalogo. Tio estas la kazo de
  heredaĵa kolekto por surloka konsulto.
- `informal` — simpla cirkulado, sen kotizo nek striktaj reguloj. La tipa kazo de
  malgranda batalema biblioteko kie ĉiuj konas unu la alian.
- `full_sigb` — plena cirkulado: reguloj, rezervoj, kotizoj, suspendoj.

**Akso 3 — `network_mode`, la federacio**

- `isolated` — la biblioteko ekzistas en AnarBib sed interŝanĝas nenion.
- `observer` — ĝi ricevas la fluojn de la reto, ĝi ankoraŭ ne kontribuas.
- `federated` — ĝi plene partoprenas.

**Akso 4 — `governance_mode`, la mastrumado**

- `informal` — neniu aparta teama rolo: ĉiuj estas legantoj. Neniu kooptado, neniu
  atendoperiodo, neniu revizia protokolo.
- `staff_roles` — la roloj `librarian` kaj `kunordiganto` ekzistas, kooptado
  simpligita.
- `full_governance` — la tuto: kooptado, atendoperiodo, revizia protokolo, crons.

### 2.2 Kion ĉiu elekto ŝaltas en la painel

Ĉi tiu tabelo estas la kialo pro kiu la etapo 0 venas antaŭ ĉio alia. La langetoj de la
giĉeto aperas aŭ ne laŭ la akso de cirkulado:

| Langeto de la painel | Aperas se |
|---|---|
| **Taga laboro** (`trabalho-do-dia`) | ĉiam |
| **Agoj** (`acoes`) | ĉiam |
| **Leganto** (`leitor`) | ĉiam |
| **Historio** (`historico`) | ĉiam |
| **Surlokaj konsultoj** (`consultas-locais`) | cirkulado `informal` aŭ `full_sigb` |
| **Pruntoj** (`emprestimos-livro`) | cirkulado `informal` aŭ `full_sigb` |
| **Rezervoj** (`reservas`) | cirkulado `full_sigb` |
| **Amasaj pruntoj** (`emprestimos-lote`) | cirkulado `full_sigb` |
| **Kontribuoj** (`contribuicoes`) | kotizo aktivigita **kaj** cirkulado malsama ol `off` |

Se langeto ne aperas ĉe vi, tio ne estas paneo: tio estas la profilo kiun via kolektivo
elektis. Kaj se la profilo ŝanĝiĝas dum la seanco, la painel revenas per si mem al la
**Taga laboro**.

> **La elektoj ne estas malliberejoj.** Ĉiu akso havas sian doktrinon de transiro — iuj
> rapidaj, iuj malrapidaj, iuj neinversigeblaj. La langeto **Transiroj** estas en
> `/biblioteca`, kaj ne en la painel: ŝanĝi profilon estas kolektiva decido, ne gesto de
> giĉeto. Iuj transiroj kiuj trairas plurajn aksojn pasas tra la validigo de la retaj
> administrantoj.

### 2.3 La dek sekcioj

Post la etapo 0, la metiejo montras nur la sekciojn kiujn via profilo faras pertinentaj.
Biblioteko en `circulation_mode = off` ne vidos la sekcion pri cirkulado: nenio mankas,
simple tiu demando ne stariĝas ĉe vi.

| Sekcio | Kio decidiĝas | Kondiĉo |
|---|---|---|
| 1 | Identeco — nomo, mallonga nomo, adreso, kontakto | ĉiam |
| 2 | Horaroj kaj deĵoroj | ĉiam |
| 3 | Respondecaj personoj | laŭ la mastrumado |
| 4 | Politiko pri katalogado | ĉiam |
| 5 | Politiko pri cirkulado | se la cirkulado ne estas `off` |
| 6 | Politiko pri aliĝo de legantoj | laŭ mastrumado kaj cirkulado |
| 7 | Politiko pri retmesaĝoj | ĉiam |
| 8 | Videbleco kaj partopreno en la reto | se la reto ne estas `isolated` |
| 9 | Datumoj kaj konfidenceco | ĉiam |
| 10 | Generado de la regularo | ĉiam |

**Neniu el ĉi tiuj sekcioj estas demando pri komputiko.** Temas pri dek demandoj de
asembleo, prezentitaj en la ordo en kiu ili bone respondiĝas. Plenigu ilin per tio kion la
kolektivo jam decidis; tie kie ĝi ne decidis, haltu kaj portu la demandon al la venonta
kunveno. La metiejo atendas.

### 2.4 La sekcio 10 — la skeleto de regularo

Fine, la programo produktas PDF-on antaŭplenigitan per ĉiuj viaj elektoj. **Tiu PDF ne
estas atestilo.** Ĝi estas skeleto por diskuti: krudmaterialo de pridiskutado. La partoj
kiuj meritas debaton estas markitaj kiel tiaj.

La atendata vojo estas: elŝuti, porti al la asembleo, libere amendi, kaj realŝuti la
amenditan dokumenton kiel oficialan regularon de la biblioteko. Dum ĝi ne estas realŝutita,
la biblioteko restas antaŭaktiva.

> **Punkto de honesteco.** « Konkludi la konstituiĝon » ne valoras, hodiaŭ, aŭtomatan
> aktivigon de la biblioteko. Tio estas konata manko de la programo, ne eraro via. Kiam vi
> alvenas al la fino de la sekcioj, skribu al `anarbib@proton.me` por ke la aktivigo
> estu farita — kaj insistu se neniu respondas post kelkaj tagoj.

---

## 3. Tagoj 3 ĝis 7 — La paĝo Biblioteca, la kolektiva domo

Post la fino de la konstituiĝo, `/biblioteca` fariĝas la loko kie tio kio estis decidita
restas enskribita kaj tenas sin. Tien oni rigardas kiam iu demandas « sed kion ni
interkonsentis? ».

- **Publika identeco** — tio kion la reto kaj la publiko vidas de via biblioteko.
- **Regularo** — la dokumento kiun vi adoptis, kaj ĝiaj versioj.
- **Teamo** — kiu estas kio, kaj tra kiu cirkvito (ĉapitro 4).
- **Profilo** — la kvar aksoj, tiaj kiaj ili estas hodiaŭ.
- **Transiroj** — la proponoj de profilŝanĝo kaj ilia voĉdono.
- **Privateco** — konservado de la datumoj, aŭtomata forviŝo, LGPD/RGPD.

**La decidoj pritrakteblaj ĉi-semajne**, ĉiuj en `/biblioteca`:

1. **La videbleco de la kolekto** — publika katalogo aŭ ne, apero en la galerio de
   bibliotekoj de `anarbib.org`, ĉeesto sur la kartografio de la reto. Sur la kartografio,
   kolektivo kiu elektas ne aperi havas siajn kialojn: la programo respektas ilin, kaj vi
   ankaŭ.
2. **La politiko pri retmesaĝoj** — kiuj okazaĵoj ekigas mesaĝon al la leganta persono
   (ciklo de prunto, memorigoj antaŭ la limdato, rememorigoj pri malfruo) kaj ĉu la teamo
   ricevas kopion. Ĉio tio ŝaltiĝas kaj malŝaltiĝas laŭ biblioteko.
3. **La konservado de la datumoj** — kiom da tempo la prunthistorio de persono restas
   gardita post la redono. Tio estas demando politika tiom kiom leĝa: en batalema
   biblioteko, historio estas listo de legaĵoj de identigitaj personoj. Gardi malmulte
   estas formo de protekto.
4. **La kotizo**, se ĝi ekzistas ĉe vi — kaj kun ĝi la langeto **Kontribuoj** de la painel.
5. **La legantkarto** — se vi aktivigas ĝin. Ĝi portas neniun nomon: nur la mallongan
   nomon de la biblioteko kaj opakan QR-on, kaj estas la leganta persono mem kiu generas
   kaj regeneras ĝin. Ĝi estas desegnita tiel intence, por ke perdita karto rakontu nenion
   pri tiu kiu portis ĝin.

> **Pri la langeto Privateco.** Ĝi povas montri du mesaĝojn kiuj kontraŭdiras unu la alian
> koncerne la aŭtomatan forviŝon. Tio estas konata montra difekto. Antaŭ ol konkludi ke la
> forviŝo estas aktiva aŭ neaktiva, demandu al la reto.

---

## 4. Tagoj 5 ĝis 10 — Konstitui la teamon

### 4.1 Tri roloj, kaj nur tri

`leganto` · `librarian` (bibliotekisto) · `kunordiganto` (kunordigo).

La loka rolo « administranto » estis forigita en majo 2026. Se vi trovas ĝin citita ie, la
dokumento estas malaktuala. « Administranto de la reto AnarBib » ekzistas, sed tio estas
**transversa statuso** — ĝi ne estas la sekva ŝtupo de la ŝtuparo, kaj oni ne alvenas tien
kunordigante sufiĉe longe. Ĝi estas alia politika mekanismo, kun sia propra kooptado.

### 4.2 La kaptilo kiu multe kostas

**Neniu aliĝas dufoje.** Ĉiuj eniras unu solan fojon per `/criar-conta`, kiel leganto —
inkluzive de tiuj kiuj estos de la teamo.

Fariĝi teamo ne estas nova aliĝo: tio estas kooptado, kaj ĝi okazas sur la konto kiu jam
ekzistas. Kiu realiĝas kredante tiel « eniri kiel teamo » nur kreas duan konton kaj
problemon kiun la kunordigo devos malfari.

**Do la sola afero petenda al tiu kiu eniros la teamon estas: « sendu al mi vian publikan
ID ».**

### 4.3 La cirkvito en tri tempoj

Neniu promocio estas unuflanka. Tri apartaj personoj, tri gestoj:

1. **Proponi** — la kunordigo proponas iun per ties publika ID, por la rolo `librarian` aŭ
   `kunordiganto`.
2. **Subteni** — alia persono de la teamo ratifas. La koncernata persono estas ekskludita
   el la kvorumo: ekde kiam la teamo nombras du aliajn aktivajn personojn, du ratifoj
   estas postulataj.
3. **Akcepti** — la proponita persono akceptas. Sen tiu konsento, nenio okazas.

La propono **eksvalidiĝas post 30 tagoj**. Linio de leganto fermiĝas, tiu de bibliotekisto
malfermiĝas: unu sola aktiva rolo por biblioteko, kaj la historio restas.

> **La kolegia salto.** Defaŭlte, por eniri la rondon de la kunordigo necesas esti pasinta
> tra bibliotekisto. Por horizontala kolektivo, tiu intera ŝtupo respondas al nenio: unu
> sola decido de asembleo postulis du cirkvitojn en la programo. De tie la salto — proponi
> iun rekte de leganto al la kunordigo — kiu ekzistas kiel **opcio de biblioteko**,
> malaktivigita defaŭlte, kiun via kolektivo aktivigas se ĝi volas. Ĝi mallongigas la
> ŝtuparon, neniam la konsentojn.

### 4.4 Eliri el la teamo

- **Atendoperiodo de 7 tagoj** — eliro el teamo ne estas tuja; la persono pasas tra intera
  stato, kaj tio lasas tempon por interparoli.
- **Neaktiveco** — teama konto kiu ne plu konektiĝas de longe eliras aŭtomate, kun averto
  al la persono 30 tagojn antaŭe kaj 7 tagojn antaŭe. La averto je 7 tagoj iras ankaŭ al
  la kunordigo, kaj ĝi eskaladas al la retaj administrantoj se la neaktiva persono estas
  la lasta kunordigo de la domo.
- **Transdoni la taskon** — transdoni la kunordigon al alia persono fariĝas per la sama
  cirkvito en tri tempoj, antaŭ ol foriri. Ne lasu tion al la lasta tago.

---

## 5. Tagoj 7 ĝis 20 — La kolekto

### 5.1 La tri vortoj kiujn vi bezonas

- **Verko** (*obra*) — la kunhavigita skedo: la libro kiel verko, la sama por la tuta
  reto.
- **Holding** — la fakto ke via biblioteko posedas tiun verkon.
- **Ekzemplero** — la fizika objekto sur la breto, kun sia etikedo, sia stato, sia
  historio.

Tri kolektivoj povas havi la saman libron: unu verko, tri holdings, pluraj ekzempleroj.
Tial korekti skedon profitas al la tuta reto, kaj tial skedo korektiĝas zorge.

### 5.2 Tri niveloj de skedo, kaj neniu estas la malbona

| Nivelo | Spirito |
|---|---|
| **Simples** | batalema biblioteko, sen akademia pretendo: tipo, titolo, aŭtoreco, jaro, eldonejo, lingvo, signaturo, defaŭlta cirkulado, kovrilo, ISBN |
| **Avançado** | laboro de bibliotekisto sen MARC: subtitolo, eldono, serio, loko, paĝoj, tipigitaj kontribuoj, temoj, notoj |
| **Completo** | elĉerpa: ISBD-zonoj, MARC, identigiloj de aŭtoritato, kompleta deveno |

**Ŝanĝi nivelon perdas nenion.** Kampo kaŝita de pli malalta nivelo konservas sian
valoron. Faru la provon unufoje, per viaj propraj okuloj: tio estas kio konvinkas.

**Komencu per Simples.** Kvin skedoj semajne en Simples valoras pli ol unu perfekta skedo
monate. La kolekto ekzistas nur katalogita.

### 5.3 La sola postulo kiun la reto vere faras

**Neniu nova ekzemplero sen akirmaniero.** De kie ĝi venas, kiam, donacita de kiu, post
kiu okazaĵo.

Tio ne estas erudicia detalo. En batalema biblioteko, la deveno estas la historio de la
kolektivo. Sen ĝi, la kolekto fariĝas anonima stako en unu generacio. La reto ne petas ke
vi faru la retroaktivan reakiron — ĝi petas ke la ŝuldo ĉesu kreski ekde nun.

### 5.4 La cetero de `/catalogacao`, kiam vi bezonos ĝin

Amasaj importoj, asistanto de malduobligo en tri tempoj, serĉo de kovriloj, eksteraj
fontoj de metadatumoj, deponado kun OCR en la retumilo, inventaro per legado de la
QR-etikedoj, periodaĵoj kaj iliaj kolektostatoj. Nenio el ĉio tio estas necesa en la unua
semajno. Ĝi estas tie kiam venos la momento.

### 5.5 Temoj kaj tezaŭro FICEDL

AnarBib kunportas la **tezaŭron FICEDL**: 462 terminoj, tradukitaj en la dek lingvojn,
liveritaj kun la programo. Ĝi estas komunaĵo de la federacio, kaj ĝi alvenas jam plenigita
— tio ne estas tasko por vi.

La **lokaj temoj**, male, apartenas al ĉiu domo: temas pri via kolekto, via vortprovizo,
viaj eldonaj elektoj. Kaj **akordigi** viajn temojn al la FICEDL-terminoj estas akto de la
kolektivo, ne teknika operacio: diri ke via « puna abolicionismo » respondas al la komuna
termino « malliberejo » estas dokumentada pozicio. Tial la akordigo ne alvenas tute
farita.

---

## 6. Tagoj 10 ĝis 25 — La giĉeto

Kvar fluoj, kaj la painel organizas ilin:

- **Prunto** — eliro, redono (inkluzive parta), plilongigo. La plilongigo povas fariĝi
  ero post ero: se la persono finis du el la tri libroj, nur la tria estas plilongigita.
- **Redono** — tuta aŭ linio post linio. Amasa ago neniam fiaskas silente: tio kio ne
  pasis estas listigita kun sia kialo.
- **Surloka konsulto** — la persono volas vidi ion surloke, oni negocas horan fendon. **La
  negocado haltas je tri iroj-revenoj**: preter tio, la programo resendas vin al la
  telefono. Tio estas intenca — negocado kiu superas tion ne estas problemo de programo.
- **Rezervo** — ĝis la efektiva forpreno, kiu transformas la rezervon en prunton.

Apud tio, en la painel: la **validigoj** de la aliĝoj de legantoj (ĉi tie vi decidas kiu
eniras), la **kaŭcio** se via domo praktikas ĝin, la **kontribuoj**, la **legonotoj**, la
**okazaĵoj**.

> **Konata difekto.** La butono « Malfermi la pruntojn » de iuj taskoj de la Taga laboro
> kondukas al malplena langeto. Tio ne estas vi. Pasu rekte tra la langeto **Pruntoj**
> (`emprestimos-livro`).

---

## 7. Tagoj 20 ĝis 30 — La federacio

La paĝo **Federação** havas ok langetojn: **Início**, **Círculos**, **Diretório**,
**Assembleias**, la gazeto **Rizoma**, **Carta/Boletim**, **Apoio mútuo** kaj **Comuns**.

Tio estas la parto de la programo kiu ne estas SIGB. Ĝi ekzistas ĉar la projekto ne volas
esti « SaaS por bibliotekoj »: eniri en AnarBib estas eniri en komunan politikan projekton,
kaj reto kiu interŝanĝas nur bibliografiajn registrojn ne estas reto.

Kion fari ĉi tiun lastan semajnon, senhaste:

1. **Pasi de `observer` al `federated`**, se tio estas kion vi decidis — kaj nur tiam.
   Eniri la reton en observanta reĝimo dum kelkaj monatoj estas respektinda elekto.
2. **Plenigi vian skedon en la Diretório**, por ke la aliaj domoj sciu kiuj vi estas kaj
   kiel paroli al vi.
3. **Decidi pri la kartografio** — aperi kun preciza adreso, nur kun la urbo, aŭ ne aperi.
   Neniu el la tri respondoj devas esti pravigita.
4. **Rigardi la Círculos kaj la Assembleias**, por scii kie la decidoj de la reto estas
   prenataj.
5. **Se vi publikigas la katalogon**, vidi kun la reto kion la OAI-PMH-punkto signifas por
   vi — per ĝi aliaj katalogoj povas rikolti la vian.

La paĝo `/rede` estas la administrado de la reto propradire, rezervita al la retaj
administrantoj. Kunordigi bibliotekon ne donas aliron al ĝi, kaj tio estas intenca.

---

## 8. La dek decidoj kiuj ne estas teknikaj

Eltranĉu ĉi tiun liston kaj portu ĝin al la asembleo. Neniu el tiuj respondoj estas en la
programo: la programo nur registras tion kion vi respondos.

1. Kien ni metas nin sur la kvar aksoj de la profilo?
2. Ĉu nia katalogo estas publika?
3. Ĉu ni pruntedonas, kaj sub kiuj kondiĉoj?
4. Kiu povas aliĝi kiel leganto, kaj kiu validigas?
5. Ĉu ni havas kotizon? Kaŭcion?
6. Kiom da tempo ni gardas la leghistorion de la personoj?
7. Kiu estas de la teamo, kaj ĉu ni aktivigas la kolegian salton?
8. Ĉu ni aperas sur la kartografio, kaj kun kiu precizeco?
9. Ĉu ni partoprenas la asembleojn de la reto, kaj kiu reprezentas nin tie?
10. Kiel ni akordigas niajn temojn al la komuna tezaŭro — kaj kion ni rifuzas akordigi?

---

## 9. Kio rompas nenion, kaj kio postulas duan legadon

**Rompas nenion:** klaki ĉie, malfermi ĉiujn langetojn, ŝanĝi la nivelon de skedo por
vidi, konservi sekcion duonplenan, proponi personon kaj lasi la proponon eksvalidiĝi,
aktivigi kaj malaktivigi la kolegian salton, pasi de `observer` al `federated`, korekti
skedon.

**Postulas duan legadon, ĉar tio ne reireblas aŭ multe kostas:**

- **Forigi** konton — kaj atentu: en la portugala, la programo distingas **APAGAR**
  (malplenigi la historion) kaj **EXCLUIR** (forigi la konton), per du malsamaj
  konfirmvortoj. En la naŭ aliaj lingvoj ambaŭ falas sur la saman vorton — en Esperanto,
  **FORIGI**. Legu la tutan frazon antaŭ ol tajpi, ne nur la petitan vorton.
- Forviŝi historion — la datumoj ne revenas.
- La profiltransiroj markitaj kiel neinversigeblaj en la langeto Transiroj.
- Publikigi en la reton kolekton kiun la kolektivo ne decidis publikigi.
- Eltiri iun el la teamo — la atendoperiodo de 7 tagoj ekzistas ĝuste por tio.

---

## 10. Kie peti helpon, kaj kiel redoni

**Peti helpon:** `anarbib@proton.me`. Diru sur kiu ekrano vi estas kaj kion vi atendis
vidi. Ne ekzistas stulta demando: la programo estis skribita de unu persono, kaj ĉiu « mi
ne trovis » kiu supreniras estas identigita difekto.

**Rito kiu funkcias.** Duonhoro semajne, kun la teamo, tri fiksaj demandoj:

> kion mi ne trovis sur la ekrano? · kion mi faris sen kompreni? · kio mankis al la
> programo?

La respondoj nutras folion de mankoj kiu fariĝas la sekva tagordo — kaj materialon de
kontribuo al la projekto. Tio estas la sola dispozitivo kiu igas la uzon supreniri al la
kodo.

**Redoni, sen programi.** La dosiero `AIDER.md`, ĉe la radiko de la deponejo, listigas la
malfermajn taskojn kiuj ne postulas kodon: tradukado, relegado de inkluziva skribo,
dokumentado, akordigo de temoj, testado de ekranoj. AnarBib estas sub AGPLv3 kaj havas
hodiaŭ nur unu solan prizorganton — tio estas ĝia ĉefa fragileco, kaj ĝi diriĝas anstataŭ
sin silenti.

---

## 11. La tridek tagoj sur unu paĝo

| Kiam | Kio | Kie |
|---|---|---|
| Tago 1 | Konektiĝi, ŝanĝi la pasvorton, promeni sen ŝanĝi ion ajn | `/login`, `/conta` |
| Tagoj 1–3 | Etapo 0: la kvar aksoj, deciditaj kolektive | `/atelier` |
| Tagoj 3–5 | Sekcioj 1 ĝis 9 | `/atelier` |
| Tago 5 | Sekcio 10: elŝuti la skeleton de regularo | `/atelier` |
| Tagoj 5–10 | Porti la regularon al la asembleo, amendi, realŝuti | asembleo, poste `/atelier` |
| Tagoj 5–10 | Kolekti la publikajn ID-ojn, malfermi la kooptadajn cirkvitojn | `/biblioteca`, langeto Teamo |
| Tagoj 7–20 | Unuaj skedoj en reĝimo Simples, ĉiuj kun deveno | `/catalogacao` |
| Tagoj 10–25 | Unua tago de giĉeto en memstareco | `/painel` |
| Tagoj 20–30 | Skedo en la diretório, kartografio, reta reĝimo | Federação, `/biblioteca` |
| Tago 30 | Skribi al la reto: kio mankis, kio trompis | `anarbib@proton.me` |

---

*Ĉi tiu gvidilo ekzistas en dek lingvoj: pt-BR, fr, es, en, it, de, ca, eo, nl, el. Ĝi
priskribas la staton de la programo en septembro 2026 kaj estos korektita kiam la programo
ŝanĝiĝos — se ekrano ne respondas al tio kio estas skribita ĉi tie, estas la gvidilo kiu
malpravas, kaj diri tion estas kontribuo.*

**Bonvenon.**
