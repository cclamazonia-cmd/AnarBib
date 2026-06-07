---
title: "Gvidilo pri Regado de AnarBib"
subtitle: "Por la koordinant-in-oj de bibliotekoj kaj la administrant-in-oj de la reto"
author: "Projet AnarBib"
date: "Versio 1.1 — 5-a de junio 2026"
lang: eo
---

# Antaŭparolo

Ĉi tiu gvidilo estas adresita al tiuj personoj, kiuj en la reto AnarBib plenumas funkcion de koordinado — ĉu por koordini lokan bibliotekon, ĉu por administri la reton. Ĝi havas duoblan celon:

- **Klarigi la politikan logikon** de la reguloj enkodigitaj en la SIGB AnarBib, kaj ilian filiacion kun la projekto pri kolektiva emancipiĝo, kiu naskis la anarkiistajn bibliotekojn;
- **Doni ilojn por ĉiutaga praktiko**, respondante al la konkretaj demandoj, kiujn la koordinadoj renkontas kiam ili uzas la programaron.

## Politika konvencio

Ĉi tiu gvidilo ne estas la regularo de la reto, kaj ĝi ne havas supera aŭtoritato ol la decidoj de la kolektivoj, kiuj ĝin konsistigas. Kion ĝi enhavas, tio havas forton nur ĉar homoj-in-oj interkonsentis pri ĉi tia funkciado iam. Se la praktikoj evoluas, ĉi tiu teksto devos evolui kun ili, aŭ esti kontraŭdirita, aŭ esti disŝirita. La uzo, kiun la kolektivoj faros el ĝi, decidos pri ĝia sorto.

La teknikaj reguloj, kiujn la SIGB AnarBib respektigas — la karencotempon, la kunoptadajn laborflujojn, la membrecstatusojn, ktp. — estas ankaŭ konvencioj. Ili estis skribitaj de kamarad-in-oj en precizaj datoj, por solvi precizajn problemojn. Ili estas registritaj en **specifaj dosieroj** (la `spec-*.md` de la deponejo), datitaj kaj subskribitaj, kiuj mem estas ŝanĝeblaj. Kiam oni legas ĉi tiun gvidlion, oni legas la staton de debato en difinita momento. Ĝi ne estas konstitucio.

## Kiel ĉi tiu gvidilo estas organizita

La gvidilo konsistas el du partoj:

- **Parto I — La kial.** Kvar ĉapitroj, kiuj starigis la politikan kadron: kion servas anarkiisma SIGB, kuj estas ĝiaj fundamentaj principoj, kiel artikuliĝas la du perimetroj (loka biblioteko kaj reto), kaj kiel la reguloj mem povas esti modifitaj.

- **Parto II — La kiel.** Ses praktikaj ĉapitroj, ĉiu traktanta gravan operacian demandon: kunopti, malpromocii, administri situaciojn, kiuj malordas, plenumi funkcion de reta administ-in-o, garantii travideblecon, kaj lasta ĉapitro, kiu komentadas konkretajn kazojn de komenco ĝis fino.

Ĉe la fino de ĉiu praktika ĉapitro, sekcio **« Se la regulo generas al vi problemojn »** memorigas kie diskuti pri ĝi kaj kiel proponi modifo. Tio estas grava, ĉar ĉi tiuj reguloj havas sencon nur se ili estas ŝanĝeblaj.

La aneksoj ĉe la fino de la volumo funkcias kiel rapida referenco: glosaro, indekso de teknikaj funkcioj kun ilia politika traduko, modelo de modifpropono, kaj ligiloj al la fontaj specifoj.

## Kiel legi ĉi tiun gvidlion

Oni povas legi ĝin unuipe, sed tio verŝajne ne estas la plej bona uzo. Tri manieroj eniri la tekston laŭ la bezonoj:

- **Por kompreni la spiriton de la projekto** antaŭ ol preni funkcion: legi parton I (ĉapitroj 1 ĝis 4).
- **Fronte al konkreta situacio**: salti rekte al la koncerna praktika ĉapitro (5 ĝis 10).
- **Por informiĝi antaŭ Ĝenerala Asembleo**, kie oni traktos governaddemandon: legi la koncernan ĉapitron plus la sekcion « Se la regulo generas al vi problemojn » korespondantan, kaj konsulti la fontspecon en anekso D.

Kio estas skribita ĉi tie apogas sin sur kvar specifaj dokumentoj:

- `spec-gouvernance-roles.md` (5-a de majo 2026) — roloj, statusoj, transiroj;
- `spec-administrateur-reseau.md` (11-a de majo 2026) — loka/reta apartigo, kunoptado per unanimeco;
- `spec-validation-physique.md` (3-a de majo 2026) — manieroj akcepti legant-in-ajn kontojn;
- `spec-refactor-v3-semantique.md` (9-a de majo 2026) — semantiko de la rezervada laborfluo (menciita en la marĝeno).

La referencoj al ĉi tiuj specifoj estas rememorataj laŭ la teksto en la formo `(cf. spec-gouvernance, §3.4)` por permesi pli profundan enketon.

## Noto pri la voĉo

La teksto alterne uzas **oni** (la kolektivo AnarBib, al kiu apartenas ankaŭ la aŭtor-in-o kaj la legant-in-o), **vi** (kiam oni adreso al preciza koordinant-in-o aŭ administ-in-o, kiu devas fari elekton), kaj **ni** (kiam oni parolas pri la kamarad-in-oj, kiuj skribis la regulojn iam, kaj kiuj povus esti aliaj ol tiuj, kiuj legas ilin). Tio estas intenca. Ne ekzistas institucia neŭtraleco ĉi tie: ĉi tiu teksto estas portata de kamarad-in-oj, kaj ĝi estas adresita al kamarad-in-oj.

\newpage

# Parto I — La kial

\newpage

# 1. Kion signifas anarkiisma SIGB?

## 1.1. La SIGB ne estas la Ĝenerala Asembleo

La unua principo, kiun oni devas teni, kaj la plej malfacila, estas ĉi tiu: **la SIGB registras la decidojn de la kolektivo, ĝi ne faras ilin**. Ĉi tiu frazo aspektas senkulpa. Ĝi estas, efektive, la pivoto, ĉirkaŭ kiu ĉio alia organiziĝas.

Ĉiufoje ke la SIGB AnarBib prenas la aspekton de aŭtoritato — kiam ĝi rifuzas promociigon, kiam ĝi trudas karenctempoon de sep tagoj, kiam ĝi blokas statustransion — ĝi nur **plenumas** regulon, kiun la kolektivoj sin donis. La regulo estis skribita ie, en specifo, post diskuto. Iu rerigardis kaj kritikas ĝin. Versio estis fiksita kaj deplojita. Kaj nun, en la momento kiam vi klakos sur la butonon, la programaro simple aplikos tion, kion oni interkonsentis.

Se vi trovas la regulon stulta, kontraŭproduktiva, aŭ maljusta, ne estas la SIGB, kontraŭ kiu vi devas batali. Estas la specifon, kiun vi devas modifi. Vidu ĉapitron 4.

## 1.2. La agnoskita tensio

Ajna programaro, kiu administras permesojn, estas, per konstruo, aparato de hierarkiigo. Necesas ke iu povu validigi skribiĝon, modifi la publikan identecon de biblioteko, aliri la personajn datumojn de legant-in-o. Ĉi tiu teknika neceseco estas en ŝajne tensio kun la idealo de horizontaleco, kiu animacas la anarkiistajn bibliotekojn.

AnarBib **agnoskas ĉi tiun tension** anstataŭ kaŝi ĝin. La politika kompromiso, kiun oni trovis, konsistas el du punktoj:

- La **roloj ne estas rangoj**. Ili estas **funkcioj** provizore delegitaj de la kolektivo al iuj el ĝiaj membroj por plenumi precizajn teknikajn taskojn. Neniu estas koordinant-in-o « dumvive ». Neniu estas reta administ-in-o « esence ». Ĉi tiuj funkcioj estas pruntedonitaj, kaj ili povas esti reprenita.

- La **mekanismoj por eligo** estas same gravaj kiel la mekanismoj por nomumado. La SIGB eksplicite antaŭvidas kiel iu forlasas funkcion — per memvolontula malpromocio, per kolektiva peto kun karenctemmo, per memvolontula ĉesiĝo de la reto, per kolektiva eligo per unanimeco. Funkcio, kiun oni ne povas forlasi, ne estas funkcio, ĝi estas kapto.

## 1.3. Delegado kaj rotacio

La centra ideo estas tiu de **delegado kun rotacio**. Kolektivo delegas al iuj el siaj membroj la plenumion de teknikaj taskoj (administri pruntojn en la SIGB, modifi la videblecon de la biblioteko, akcepti novan membron en la teamon). Ĉi tiu delegado estas:

- **Eksplicita**: ĝi estas korpigita en kunoptada ago spurita en la reviziolistato;
- **Revokebla**: la delegita persono povas forlasi la funkcion kiam ajn ŝi volas, kaj la kolektivo povas peti tion laŭ kadritaj manieroj;
- **Provizora laŭnaturo**: eĉ se la SIGB trudas neniun daŭrecon, la politika kulturo de la reto estas ke oni rotacias la funkciojn, kaj oni ne enloĝiĝas en ili.

Estas ĉi tiu rotacio de funkcioj, kiu faras la diferencon inter « delegado » (anarkiisma) kaj « hierarkio » (ŝtata aŭ kapitalista). Se oni enloĝiĝas en funkcio, oni fariĝas hierarkia paŝero. Se oni eliras el ĝi regule, oni restas kamarad-in-o, kiu plenumas servon.

## 1.4. La ok fundamentaj principoj

La specifo pri rolregado (`spec-gouvernance-roles.md`, §2) eksplicitas ok fundamentajn principojn. Oni listigas ilin ĉi tie por referenco en la resto de la gvidilo; ĉiu praktika ĉapitro de parto II referencos al ili.

**P1 — Delegado, ne hierarkio.** Neniu rolo estas titulo. Ĉiuj roloj estas provizore naturo kaj revokindaj.

**P2 — Kunoptado por la dungistaj roloj.** La eniro en teamon (fariĝi librarian aŭ coordenador) okazas per kunoptado de la ekzistantaj coordenadores. Estas la kolektivo, kiu decidas kiu estas akceptita; la koordinant-in-o estas nur la mano, kiu plenumas la decidon en la SIGB.

**P3 — Memvolontula malpromocio ĉiam ebla.** Ajna persono kun dungista rolo povas memmalprociigi sin en ajna momento, sen konsulto. « Mi transdonas la respondecon » estas fundamenta rajto.

**P4 — Eligo kadrita per karenctemmo.** La nelemvolontula eligo de librarian de coordenador·a trapasas karenctempon de sep tagoj antaŭ efektiviĝo. Ĉi tiu prokrasto ebligas la kolektivan konsulton kaj eventualan nuligon de alia coordenador·a.

**P5 — Maksimuma travidebleco.** La reviziolistato de rolŝanĝoj estas legebla de la tuta aktiva dungistaro de la biblioteko, ne nur de la coordenadores. Malhelpi opakajn manipuladojn estas parto de la politika kulturo de informa horizontaleco.

**P6 — Sistemaj sciigoj.** Ajna rolŝanĝo ekigas retpoŝton al la koncerna persono kaj al la tuta koordinado. Neniu povas esti modifita en sia rolo sen scii tion, kaj la koordinado estas ĉiam informita.

**P7 — Loka suvereneco de la bibliotekoj.** Rolŝanĝoj en biblioteko A nenion influas en biblioteko B, eĉ por la sama persono. Ĉiu biblioteko estas suverena pri siaj internaj delegadoj.

**P8 — La SIGB ne modeligas la Ĝeneralan Asembleon.** La SIGB plenumas decidojn, ĝi ne faras ilin. Ĝi ne enhavas ajnan mekanismon de voĉdonado, kvorumo aŭ konsultado. Tiuj aferoj okazas kolektive, ekster la programaro.

## 1.5. Kion la SIGB ne faras

Estas utile eksplicite prezenti la elektojn de **nemodeligado**:

- La SIGB **ne difinas** kion estas « bona » koordinado. Biblioteko povas decidi en cirklo, en plenuma Ĝenerala Asembleo, per rotacio, per loto, per interkonsento, per majoreco. La SIGB ne zorgas pri tio.
- La SIGB **ne mezuras** la politikan legitimon de kunoptado. Se koordinant-in-o klakos sur « promocii X librarian », la SIGB registros. Estas la kolektivo, kiu devas certigi, ke la decido estis farita ĝuste, kaj estas en la politika kulturo de la kolektivo, ke ĉi tiu certigo realiĝas.
- La SIGB **ne arbitracias** konfliktojn. Kiam io misfunkcías, la SIGB provizas ilojn (tuja suspendado, peticio pri eligo, legebla reviziolistato) sed la politika decido restas ekster la programaro.

Ĉi tiu modesteco ne estas manko, ĝi estas postulo. SIGB, kiu pretendus modeligi la politikan vivon de kolektivo, estus, ipso facto, aŭtoritata — ĝi trudus sian vizion pri kio estas « bona » decido. AnarBib rifuzas ĉi tiun inkliniĝon.

## 1.6. Kaj la respekto de ciferecaj liberecoj?

Tri klarigoj, ĉar la demando reirevenas:

- **Personaj datumoj**: la kontoj de legant-in-oj enhavas tion, kion la persono bone volis meti en ilin. La bibliotekoj havas aliron nur al datumoj strikte necesaj por ilia funkciado. La membrecoj en aliaj bibliotekoj estas, per konstruo, hermete fermitaj (P7).

- **Reviziolistato**: la listato estas publike al la **aktiva dungistaro** de la biblioteko, ne al la legant-in-oj nek al la resto de la reto. Ĉi tiu interna travidebleco servas por malhelpi opakajn manipuladojn inter koordinadoj; ĝi ne estas panoptikono direktita kontraŭ legant-in-ojn.

- **Transbibliotekaj listatok**: kiam reta administ-in-o intervenas sur bibliotekon (kazo kovrita de la spec admin-reseau, §6.3.1), la ago estas spurita en dediĉita tabelo kun gravecnivelo. Tio estas legebla de la retaj administ-in-oj kaj de la koordinado de la koncerna biblioteko. Travidebleco en ambaŭ direktoj.

\newpage

# 2. La du perimetroj: loka biblioteko kaj reto

## 2.1. Kial ĉi tiu apartiĝo

La reto AnarBib ne estas bibliotekĉeno kun centra sidejo. Ĝi estas **federacio de aŭtonomaj kolektivoj**. Ĉi tiu politika realeco fine trudis sin en la strukturon de la SIGB mem.

Komence, en la unuaj versioj, la rolo de « administrant-in-o de AnarBib » estis ligita al preciza biblioteko en la tabelo `user_library_memberships`. Ĉi tiu modeligo sugestis — sen diri tion — ke reta administ-in-o *administras bibliotekon*. Tio ne estis politike vera: reta administ-in-o animacas la inter-bibliotekan koordinadon, ri ne gvidas ajnan bibliotekon aparte.

La specifo `spec-administrateur-reseau.md` (11-a de majo 2026) akceptis la apartiĝon. De nun la SIGB konas **du apartajn perimetrojn**:

- **La loka dungistaro** de biblioteko (roloj `reader`, `librarian`, `coordenador`), stokita en `user_library_memberships`. Ĝia politika aŭtoritato situas **ene de la perimetro de la biblioteko**.

- **La reta administrado** (tabelo `network_administrators`), sen ligo al biblioteko. Ĝia politika aŭtoritato estas **transversa**, sed ĝi neniam anstataŭas lokan aŭtonomion.

## 2.2. Kion ĉiu perimetro faras

**La loka dungistaro** administras la ĉiutagaĵon de biblioteko: pruntojn, redonojn, rezervadojn, validigon de skribiĝoj, modifon de la regularo, de la cirkuladopolitikoj, de la publika identeco de la biblioteko. Ĉio, kio koncernas la funkcionadon de **unu** biblioteko, estas aranĝata ĉe la nivelo de la loka dungistaro.

**La reta administrado** certigas la inter-bibliotekan koordinadon: aktivigon de novaj bibliotekoj, moderadon de la komuna katalogo, teknikumajn prizorgadojn de la platformo, akcepton de novaj kolektivoj, kaj esceptan intervenon kiam biblioteko troviĝas en blokado (plu da aktiva koordinant-in-o, majora konflikto, ktp.). Ĉio, kio koncernas la **reton**, estas aranĝata ĉe la nivelo de la reta administrado.

## 2.3. La regulo de nekovriĝo

Simpla politika regulo gvidas ĉiujn kalkulilojn kaj ĉiujn vidojn de la SIGB:

> **Ĉiu paĝo rakontas la historion de sia perimetro. Kalkulilo kalkulas tion, kio estas enregistrita en sia perimetro, nek pli, nek malpli.**

Konkrete:

- La paĝo de biblioteko kalkulas ĝiajn lokajn membrecojn. Punkto. La retaj administ-in-oj ne aperas en ĉi tiuj kalkuliloj, eĉ se ili povas teknike interveni sur la bibliotekon.
- La paĝo de la reto kalkulas ĝiajn retajn administrant-in-ojn. Punkto.

Se persono estas samtempe `coordenador` de biblioteko **kaj** reta administrant-in-o (la kazo de Xavier la 11-an de majo 2026), ri aperas en ambaŭ kalkuliloj, **unufoje en ĉiu**, sen krucdeduplikiĝo. Estas **du apartaj politikaj enregistroj**, ĉiu kalkulita en sia perimetro.

Kial ĉi tiu regulo estas politike sana, en kvar punktoj:

- **Honesteco**: via loka engaĝiĝo estas kalkulita en la biblioteko, kie vi animacas; via reta engaĝiĝo estas kalkulita ĉe la retnivelo. Neniu kalkulas vin « 1,5-foje ».
- **Legebleco**: aktivul-in-o, kiu rigardas la ficon de biblioteko, tuj vidas kiom da personoj estas engaĝitaj **loke**, sen devi demandi sin, ĉu « eksteraj » retaj administ-in-oj ŝveligos la kalkulilon.
- **Fortikeco**: se morgaŭ oni aldonos mezajn rolojn (helpant-in-o, praktikant-in-o, observant-in-o), la regulo « paĝo = perimetro » restas klara.
- **Politika kohereco**: la apartiĝo inter reta administ-in-o kaj loka dungistaro estas **politika decido**, ne modeligo-detalo. La kalkuliloj devas reflekti ĝin.

## 2.4. La transversa rajto de la reta administ-in-o

Ĉi tiu punkto meritas esti bone komprenita, ĉar ĝi estas facile miskomprenita.

**Reta administ-in-o povas teknike interveni sur ajna bibliotekon.** Ri povas, ekzemple, legi la katalogon de `private` biblioteko, modifi ĝian videblecon, aŭ — en esceptaj kazoj — krei aŭ modifi membrecojn. Tio estas, kion la specifo nomas la **transversa intervena rajto**.

Ĉi tiu rajto ekzistas pro du kialoj:

- **Prizorgado**: necesas ke iu·iu povu malbloki bibliotekon, kiu paneis (plu da koordinant-in-o, difektita agordo, ktp.).
- **Mediaciado**: kiam grava konflikto trairas bibliotekon kaj malhelpas la lokan kolektivon funkcii, necesas remedilo.

Sed ĉi tiu rajto **ne** faras la retan administ-in-on hierarkian suprul-in-on de la loka koordinado. La doktrino de la reto, starigita en ĉi tiu gvidilo:

> **Interveno de reta administ-in-o sur loka biblioteko devas esti antaŭita de informo al la koncerna loka koordinado**, krom en vitala urĝeco (aktiva kompromito, daŭranta ĉikano, atako kontraŭ la platformo). La antaŭa informo ne estas peto pri permeso: la reta administ-in-o havas la rajton agi. Sed ĝi estas **signo de respekto** al la aŭtonomio de la biblioteko, kaj ĝi konservas la eblon de alia aranĝo (ekzemple: « lasu min provi solvi tion unue, mi tenos vin informata »).

La teknika spurado ekzistas aldone: ĉiuj trans-bibliotekkaj agoj de reta administ-in-o estas spuritaj en la tabelo `cross_library_actions_log` kun gravecnivelo, legeblaj de la loka koordinado a posteriori.

## 2.5. La loka suvereneco estas netuŝebla

Lasta politika klarigo, kiu deriviĝas de la principo **P7 — Loka suvereneco de bibliotekoj**.

La bibliotekoj de la reto AnarBib **reciproke rekonas sin**. Kiam BLMF fizike validigas nov-in-an legant-in-on (cf. `spec-validation-physique.md`), ĉi tiu validigo validas por ĉiuj `network` bibliotekoj de la reto. Tio estas **implica cirkulada pakto** inter bibliotekoj, kiuj dividas sufiĉan politikan kulturon por fidi unu la alian.

Sed ĉi tiu reciproka rekono **donas neniun ingerencan rajton** de unu biblioteko en alian. La koordinado de biblioteko A ne povas modifi la membrecojn de biblioteko B. Ri ne povas vidi la personajn datumojn de la legant-in-oj de B (krom tiuj, kiuj estas ankaŭ enskribita ĉe ri). Ri ne povas ŝanĝi la regularon de B.

Ĉiu biblioteko restas **suverena pri siaj internaj delegadoj**, sia akceptpolitiko, sia validiga maniero, siaj kotizaj reguloj, sia interna regularo. La reto ne diras kiel ili devas funkcii. Ĝi diras nur kun kiuj ili rekonscias.

\newpage

# 3. Statoj, roloj, transiroj: la gramatiko de la SIGB

Ĉi tiu ĉapitro estas iom pli arida ol la aliaj. Ĝi fiksas la teknikan vortprovizon uzatan tra la tuta gvidilo. Se vi preteriras ĝin en la unua legado, vi povos reveni al ĝi laŭbezone.

## 3.1. La kvar roloj

La SIGB AnarBib uzas kvar rolojn, deklaritajn en la datumbazo per la limo `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` sur la tabelo `user_library_memberships`.

**`reader`** — Baza legant-in-o-konto. Sen administra povo. Permesoj: konsulti la katalogun (laŭ la videbleco de la biblioteko), prunti, rezervi, konsulti en la ĉambro, modifi siajn proprajn personajn datumojn, peti la migradon aŭ forigon de sia konto.

**`librarian`** — Operacia staff-an-in-o. Administras la ĉiutagon: pruntoj, rezervoj, redonoj, validado de aliĝoj (laŭ la reĝimo de la biblioteko), modifo de katalogaj datumoj, aliro al personaj datumoj de la legant-in-oj de la biblioteko. **Nur-lega** aliro al la teama listo. Ricevas sciigojn pri rolŝanĝoj kaj povas legi la teaman revizian protokolon (P5).

**`coordenador`** — Koordinada staff-an-in-o. Ĉion, kion havas librarian, plus: modifi la publikan identecon de la biblioteko (nomo, emblemo, kontakto, k.t.p.), modifi la agordon (pruntpolitikoj, regularo), administri la kotizan regulojn, **kaj ĉiujn teaman regadan agojn**: koopti, peti forigon, suspendi, levi suspendon, nuligi forigpeton.

**`administrador`** — Historia rolo, en forigo-procezo. Ekzistis por signifi «trans-biblioteka administra rajto» sed ligita al `library_id`. Nun anstataŭigita de la **ret-administrant-in-oj** stokitaj en la tabelo `network_administrators` (cf. ĉapitro 2). La spec admin-reseau planas la laŭgradan migradon kaj la fian forigon de ĉi tiu rolo el la tabelo `user_library_memberships`.

## 3.2. La kvin statoj de membreco

Ĉiu linio de la tabelo `user_library_memberships` havas **staton** esprimante la staton de la delegacio en donita momento. Kvin statoj estas eblaj:

**`active`** — Normala stato. La persono havas sian rolon kaj ekzercas ĝin.

**`pending`** — Rezervita por la fizika validada spec. La membreco estas kreita sed atendas fizikan renkontiĝon kun librarian+ de la aliĝo-biblioteko. Neniu aliro al rolaj funkcioj dum ĉi tiu stato.

**`suspended`** — **Konservativa rimedo** prenita de koordinad-in-o. Neniu aliro. Uzo: raporta ĝenado atendanta esploron, kompromitita konto, konflikto en mediaciprocezo. **Nedifinia daŭro**; la levado estas manlibra, de koordinad-in-o (reveno al `active`) aŭ per efika ekoficiigo.

**`pending_removal`** — **Sep-taga karenco** antaŭ efika ekskludo. Neniu aliro dum ĉi tiu periodo. Ebla evoluo: nuligado de alia koordinad-in-o (reveno al `active`), aŭtomata retrograde de la persono mem (kurtvojo), aŭ aŭtomata transiro al `inactive` je J+7.

**`inactive`** — Fermita membreco. La persono ne estas plu en la teamo. Neniu aliro. Pluraj eblaj originoj: libervola eliro, fino de karenco, forlasita konto (aŭtomata post 9 monatoj).

## 3.3. La transirskepo

La SIGB ne permesas ajnan transiron inter statoj. Jen, simpligite, la permesita skemo:

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
              │ levado          │ nuligado
              └────────────────┴────────────┐
                               │            │
                               ▼ (J+7)      ▼
                        ┌──────────────┐
                        │   inactive   │
                        └──────────────┘
```

Kelkaj ŝlosilaj reguloj:

- Oni **ne** povas rekte transiri de `active` al `inactive` por librarian per unuflanka decido de alia koordinad-in-o. Oni devas trairi `pending_removal` kaj atendi la karencperiodpon (aŭ ke la persono mem retrogradu sin).
- Oni ĉiam povas transiri de sia propra stato `active` al `inactive` (aŭtoretrogrado, rajto P3).
- `suspended` havas **neniun** maksimuman daŭron. Ĝi ne estas karenco antaŭ ekskludo, ĝi estas konservativa rimedo — ĝi daŭras dum la deliberado.
- De `inactive`, oni **ne reiras** al `active`. Por reintegri personon, oni kreas novan membreclinion. La historio estas konservita.

## 3.4. La naŭ transiroj, kiu povas fari kion

La rolorega spec formaligas naŭ transirojn, listita ĉi tie kompakte. La operacia detalo estas en Parto II.

| # | Transiro | Kiu | Mekanismo |
|---|---|---|---|
| T1 | `reader` → `librarian` | Koordinad-in-o+ | Kooptado |
| T2 | `librarian` → `coordenador` | Koordinad-in-o+ | Kooptado |
| T3 | `coordenador` → `librarian` | Mem AŬ aliaj koordinad-in-oj | Aŭtoretrogrado AŬ kolegifa forigo kun karenco |
| T4 | `librarian` → `reader` (libervola) | Mem | Aŭtoretrogrado |
| T5 | `librarian` → `reader` (kolektiva) | Koordinad-in-o+ | `pending_removal` kun 7-taga karenco |
| T6 | Tuja suspendo | Koordinad-in-o+ | Transiro al `suspended` |
| T7 | Levado de suspendo | Koordinad-in-o+ | Reveno `suspended` → `active` |
| T8 | Nuligado de forigpeto | Koordinad-in-o+ | Reveno `pending_removal` → `active` |
| T9 | Aŭtomata eliro (forlasita konto) | Cron | Transiro al `inactive` post 9 monatoj sen ensaluto |

Tri principoj strukturas ĉi tiun tabelon:

- **La eniro okazas per kooptado** (T1, T2). Neniu mem-promociigas sin.
- **La libervola eliro estas ĉiam ebla** (T3 aŭto, T4). Neniu restas kaptita en funkcio, kiun ri ne volas plu ekzerci.
- **La devigata eliro estas malakcelata per karenco** (T5). Sep tagoj por permesi eventualan kolektivan ŝanĝon de trakto.

## 3.5. Reta administra flanko: duobla skemo

La reta administrado (tabelo `network_administrators`) havas sian propran vivociklon, strukture tre proksiman sed kun du specifikaĵoj:

- **Kooptado per unanimeco**: por aldoni novan ret-administrant-in-on, propono estas malfermita de aktiva administrant-in-o, kaj **ĉiuj aliaj aktivaj administrant-in-oj** devas voĉdoni `favorable`. Eĉ unu voto `opposed` (kun deviga 20-karaktera argumentaro) blokas la proponon. Sindeteno ankaŭ blokas tiom longe kiam ĝi ne estas transformita en voton.

- **Kolektiva forigo per unanimeco**: por forigi ret-administrant-in-on kontraŭ ria volo, la sama laborflumo aplikas spegule. Kun 7-taga karencperiodo post unanima interkonsento (kampo `pending_collective_removal_until`).

La aŭtoretiro mem estas **unuflanka kaj ĉiam ebla** (krom se oni estas la sola aktiva administrant-in-o; en tiu kazo la transiro trairas `pending_removal` kun 30-taga karenco kaj alerta retmesaĝo al la aliaj administrant-in-oj).

Plenaj detaloj en ĉapitro 8.

\newpage

# 4. Reveturebleco kaj amendeblo

Ĉi tiu mallonga ĉapitro traktas krucan politikan demandon: **kiel tiuj reguloj povas esti moditaj?** Se ili ne povus esti moditaj, la SIGB estus aŭtoritato, kaj la cetero de ĉi tiu gvidilo estus mensogo.

## 4.1. Tri niveloj de amendeblo

Oni devas distingi tri nivelojn de reguloj, kiujn oni ne amandas sammaniere:

**La lokaj praktikoj de biblioteko** — akcepta politiko, fizika validada reĝimo (`open` aŭ `manual_validation`), interna regularo, frecvento de ĝeneralaj kunvenoj, kooptadaj modaloj. Tiuj praktikoj estas **internaj al ĉiu biblioteko**. La reto ne intervenas. Ili estas amendataj en bibliotekan ĝeneralan kunvenon, aŭ laŭ la proceduro, kiun la kolektivo mem difinis.

**La reguloj de la reto** — loka/reta apartigado, principo de unanima kooptado por retaj administrant-in-oj, doktriino de antaŭinforma sciigo dum trans-bibliotekan interveno, aktivigmodaloj de novaj bibliotekoj. Tiuj reguloj estas **inter-bibliotekoj**. Ili estas amendataj en reta koordinado, post diskuto inter retaj administrant-in-oj kaj koncernataj lokaj koordinadoj.

**La politikaj fundamentoj de la projekto** — la ok principoj (P1 ĝis P8 el ĉapitro 1), la ideo, ke la SIGB ne modeligas la ĝeneralan kunvenon, la revendikata modesteco de la programaro antaŭ la politika vivo de la kolektivoj. Tiuj fundamentoj povas esti amendataj, sed ili estas strukturaj: modifi ilin estas verŝajne modifi tion, kion oni nomas «AnarBib» en la vasta senco. Tia re-pridubado pasus per kolektiva diskuto en la tuta reto, verŝajne okaze de evento (jara renkontiĝo, ktp.).

## 4.2. Kiel proponi amendon

Ne ekzistas unu sola maniero — ĉiu nivelo havas sian — sed jen la ĝenerala modelo, kiun la reto tendencas praktiki:

1. **Identigu la koncernan spec-on**. La reguloj de la SIGB estas konsignitaj en `spec-*.md`-dosieroj de la deponejo. Trovu tiun, kiu enhavas la regulon, kiun vi volas amandi (anekso D donas la korespondojn).

2. **Verku amendan noton**. Libera formato, sed kiu respondas al: kiu regulo, kial ĝi estigas problemon, kian modifon vi proponas, kiajn teknikajn kaj politikajn konsekvencojn vi antaŭvidas. Anekso C proponas modelon.

3. **Cirkuligu la noton**. Laŭ la nivelo:
   - **Loka**: en bibliotekan ĝeneralan kunvenon, aŭ sur la diskutkanalo de la kolektivo.
   - **Reta**: sur la inter-bibliotekan koordinadkanalon (Matrix `#anarbib`), etikedante retajn administrant-in-ojn kaj la koncernatajn lokajn koordinadojn.
   - **Fundamentoj**: sur ĉiuj kanaloj, kaj verŝajne sur la tagordo de renkontiĝo.

4. **Diskutu, amandu, elektu version**. La SIGB ne diras kiel ĉi tiu paŝo devas okazi. Tio estas la metio de la kolektivoj.

5. **Se la decido estas prenita**: ret-administrant-in-o aŭ programist-in-o (ofte la samaj) efektivigas la modifon en la koncerna spec, poste en la kodo. La nova versio estas deplojita laŭ la kutima proceduro (ŝanĝoregistro, komunikado, ktp.).

## 4.3. Se la teknika decido estigas problemon

Okazas, ke oni politike interkonsenti pri regulo, sed ke ĝia teknika traduko estas komplika, peza, aŭ havas nedeziratajn kromefikojn. Tio estas normala. La ekzistantaj spec-oj estas plenaj de notoj kiel «ĉi tiu politika decido implicas tuŝi 22 sub-SELECT en la RLS-politikoj, kio pravigas antaŭan refaktoradon». La politika/teknika dialogo estas konstanta.

Kiam vi proponas amendon, ne hezitu fari tion eĉ se vi ne havas ideon pri la teknika malfacileco. La reto-programist-in-oj diros al vi, kion ĝi kostas. Kaj se ĝi estas tre kara, vi povos kolektive decidi ĉu la politika tasko valoras la teknikan koston. Male, foje politike bagatela ŝanĝo permesas grandege simpligi la kodbazon.

## 4.4. Ĉi tiu gvidilo mem estas amendebla

Ĉi tiu gvidilo estas versiigita. La aktuala versio estas indikita sur la titolpaĝo. Se vi trovas, ke ĝi diras ion malĝustan, ke ĝi forgesis kazon, aŭ ke ĝi prenas pozicion, kiu ne plu konformas al la doktriino de la reto, **diru ĝin**. Malfermu diskuton, proponu modifon, aŭ rescribu la pasaĵon kaj submetu ĝin.

Gvidilo, kiu ne povas esti modifita, ne estas gvidilo, ĝi estas dogmo. La projekto AnarBib ne celas produkti dogmojn.

\newpage

# Parto II — La kiel

\newpage

# 5. Koopti iun en sian teamon

Ĉi tiu ĉapitro kovras la transirojn T1 (`reader` → `librarian`) kaj T2 (`librarian` → `coordenador`), tio estas la **du enirajn movojn** en bibliotekan teamon. La fizika validado de nova `reader` (kiu ne estas kooptado en la politika senco sed teknika akceptoperacio) estas traktata aparte en §5.5.

## 5.1. La politika principo

> **P2 — Kooptado por staff-roloj.** La eniro en teamon okazas per kooptado de la ekzistantaj koordinad-in-oj. La politika kolektivo decidas, kiu estas akceptita; la koordinad-in-o estas nur la mano, kiu plenumas la decidon en la SIGB.

Tio signifas, ke **alklaki «Promocii»** ne estas persona decido de la koordinad-in-o, kiu alklakas. Ĝi estas la **teknika plenumado** de decido, kiu estis prenita — aŭ devas esti prenita — de la politika kolektivo de la biblioteko. La doktriino de la reto pri «kiam ekzakte» la decido devas esti prenita estas intencie ne difinita de ĉi tiu gvidilo: ĉiu biblioteko faras sian propran doktrinecon (vidu §5.4).

## 5.2. Por enkonduki iun kiel `librarian` (T1)

### Antaŭkondiĉoj

- La persono havas AnarBib-konton (ri estas aliĝita ie en la reto).
- Ri ne jam havas aktivan `librarian` aŭ `coordenador`-membreclinion en la sama biblioteko.
- Ri povas, aŭ ne, jam havi `reader`-membreclinion en la sama biblioteko. Se jes, ĉi tiu ekzistanta membreco restos aktiva paralele (plurobla membreco permesata).

### Proceduro en la SIGB

1. Iri al `/biblioteca`, langeto **Equipe** (videbla al `coordenador+`).
2. Se la persono jam estas reader de la biblioteko, alklaki **«Inviti en la teamon»** sur ria linio. Se ri ankoraŭ ne estas reader, uzi la serĉon en la supera strio aŭ — se ri ankoraŭ ne havas konton — uzadi la invitadon per retmesaĝa laborflumo (venonta, cf. `spec-invitation-equipe.md`).
3. Elekti la rolon `librarian`.
4. Konfirmi la modalan fenestron. Kampo «Kialo» estas laŭvola — ĝi servas por enskribigi en la revizian protokolon la kuntekston de la kooptado (ekz. «AG-decido de 04/05», aŭ «kooptado en malgranda cirklo, konfirmenda ĉe la venonta ĠK»).
5. La SIGB plenumas:
   - Kreo de `user_library_memberships`-linio kun `role='librarian'`, `status='active'`.
   - Retmesaĝo al la koncerna persono: «Vi estis nomumita librarian de [biblioteko] de [vi]».
   - Retmesaĝo al ĉiuj aktivaj koordinad-in-oj de la biblioteko.
   - Eniro en la revizian protokolon: `action='promoted_to_librarian'`.

### Tuja efiko

La persono ricevas, sen prokrasto, la permesojn de `librarian`: pruntadministrado, aliĝvalidado, aliro al personaj datumoj de la legant-in-oj de la biblioteko, ktp. Ri ne ricevas la permesojn por modifi la publikan identecon nek la agordon — tiuj estas rezervitaj al `coordenador+`.

### Teknika flanko

Koncernata RPC: `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.3. Por promocii librarian al `coordenador` (T2)

### Antaŭkondiĉoj

- La persono havas `librarian`-membreclinion `active` en la biblioteko.
- Ri ne jam havas aktivan `coordenador`-membreclinion en la sama biblioteko.

### Proceduro en la SIGB

1. Iri al `/biblioteca`, langeto **Equipe**.
2. Sur la linio de la persono, alklaki **«Promocii»** → **«coordenador»**.
3. Konfirmi la modalan fenestron. Kampo «Kialo» estas laŭvola.
4. La SIGB plenumas:
   - Kreo (aŭ reaktivigo) de `coordenador`-linio `active`. La malnova `librarian`-linio restas aktiva paralele (plurobla membreco; vidu §5.6).
   - Retmesaĝo al la persono.
   - Retmesaĝo al ĉiuj aktivaj koordinad-in-oj.
   - Eniro en la revizian protokolon: `action='promoted_to_coordenador'`.

### Tuja efiko

La persono ricevas, aldone al siaj `librarian`-permesoj, la koordinajn permesojn: modifo de la publika identeco, de la agordado, de la kotizaj reguloj, kaj ĉiujn teaman regadan agojn.

### Teknika flanko

Koncernata RPC: `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.4. La politika demando: kiam alklaki?

Tio estas la demando, kiun ĉiu koordinad-in-o faras al si la unuan fojon. La reto AnarBib **intence ne difinitaj** ĉi tiun demandon je la nivelo de la gvidilo: ĉiu biblioteko faras sian propran doktrinecon, ĉar la politika kulturo de anarĥia kolektivo ne estas decidata je la nivelo de ĝenerala gvidilo.

Jen la tri doktrinoj renkontitaj en la reto, sen juĝo:

**Doktrino 1 — Strikta atendo.** Oni alklakas nur **post** registrita decido de la kolektivo (ĢK, cirklo, formala konsento, sendepende de la modalo). La koordinad-in-o nur plenumas. Avantaĝo: maksimumigo de horizontaleco, forta politika traceblo. Malavantaĝo: povas esti malrapida, precipe kiam la biblioteko estas en la komenca fazo aŭ kiam la kolektivo estas dispersita.

**Doktrino 2 — Balizada antaŭago.** La koordinad-in-o povas antaŭagi decidon, kiun ri konsideras certan («estas evidenta, ke Voltairine estos kooptata, ĉar ri venis ĉiusemajne dum ses monatoj»), **kondiĉe ke ri klarigos tion en la revizian protokolon**: kialo = «antaŭago sub mia respondeco, konfirmenda ĉe la venonta ĢK». La decido povas esti poste kontestataj, kaj la forigo restas ĉiam ebla. Avantaĝo: praktika souplesse. Malavantaĝo: movas parto de la politika respondeco sur la koordinad-in-on, kiu alklakas.

**Doktrino 3 — Koordinada cirklo.** La kooptado estas prenita per interkonsento inter la aktivaj koordinad-in-oj de la biblioteko, sen trapasi la plenuman ĜK. Argumento: la koordinado mem estas deliberanta kolektivo kaj havas la mandaton agi. Avantaĝo: meza pozicio inter 1 kaj 2. Malavantaĝo: povas fariĝi opaka se la koordinado mem ne estas renovigita.

**Nia rekomendo** (nenio pli): **elektu eksplicite** doktrinecon, skribu ĝin en la regularon de via biblioteko, kaj indiku ĝin en la kampo «Kialo» de la revizian protokolon ĉe ĉiu kooptado («doktrino 2 — antaŭago sub mia respondeco» ekz.). Opakeco estas malofte bona en politiko.

## 5.5. Aparta kazo: la fizika validado de `reader`

La **alveno** de `reader` en biblioteko estas operacio diferenca de kooptado en la politika senco. Ĝi estas kovrata de la spec `spec-validation-physique.md`.

Du eblaj reĝimoj, elektitaj de ĉiu biblioteko en sia agordado:

**Reĝimo `open`** — La validado estas **aŭtomata** ĉe aliĝo. Post kreo de konto kaj konfirmo de retmesaĝadreso, la `reader` tuj havas aliron al la katalogoj `public` kaj `network`. Taŭga por bibliotekoj politike malmulte eksponitaj.

**Reĝimo `manual_validation`** — La konto estas kreita rete sed restas **atendanta** ĝis **fizika renkontiĝo** inter la `reader` kaj librarian+ de la aliĝ-biblioteko. Taŭga por eksponitaj bibliotekoj (streĉa politika kunteksto, sentemaj fondusoj, fragila lokalo, ktp.).

### Proceduro de fizika validado (reĝimo `manual_validation`)

1. La persono aliĝas rete kaj elektas vian bibliotekon kiel sian ĉefan bibliotekon.
2. Ria konto estas kreita kun `status='pending'`. Ri ricevas retmesaĝon klarigante, ke ri devas veni fizike prezentiĝi al la biblioteko.
3. Kiam ri venas, librarian+ renkontas rin, kontrolas kion oni devas kontroli (la doktriino pri tio, kion «kontroli» signifas, estas loka), kaj alklakas **«Validigi»** sur ria linio en la langeto **Equipe** → sekcio **Atendantaj kontoj**.
4. Laŭvola «Noto»-kampo permesas enskribigi kuntekston («renkontiĝo de 12/05 dum la permanenta servo, prezentita de Emma»).
5. La konto transiras al `status='active'`. La persono ricevas bonvenon-retmesaĝon.

### Politike gravas

- La fizika validado de biblioteko **validas por la tuta reto** de `network`-bibliotekoj (P7 nuancita: la loka suvereneco koncernas internajn delegaciojn, sed la reciproka rekono estas eksplicita pakto).
- Tio, kion oni «kontrolas» dum fizika validado, **ne** estas identeca kontrolo en la administra senco. Ĝi estas renkontiĝo. Ĉiu biblioteko difinas ĝian politikan signifon. Por kelkaj, ĝi estas «oni interŝanĝas iom por kontroli, ke la persono ne estas flik-in-o aŭ faŝist-in-o». Por aliaj, ĝi estas «oni prezentas la bibliotekon, ĝian funkcionadon, ĝiajn regulojn». Por ankoraŭ aliaj, ĝi estas simple «oni renkontiĝas vere, por ke la rilato estu enkorpigita».
- Biblioteko povas **ŝanĝi reĝimon** ĉiutempe (`coordenador+`). La ŝanĝo ne invalidacias ekzistantajn validadojn.

## 5.6. La plurobla membreco, atentpunkto

Teknika apecialeco por kompreni: persono povas havi **plurajn liniojn** de membreco en la sama biblioteko kun malsamaj roloj. Ekzemple, Voltairine povas esti samtempe `reader` kaj `librarian` de BLMF. Tion ebligas la UNIQUE-limo sur la trioplo `(user_id, library_id, role)`.

**Kial tiu eblo:** ĝi konservas la historion. Se morgaŭ Voltairine retrograde sin de `librarian` al `reader`, ria `librarian`-linio transiras al `inactive` sed la `reader`-linio restas — sen neceso rekrei novan aliĝon de nulo.

**Praktika konsekvence:** en la uzantinterfaco, oni montras la personon **unufoje**, kun ria **plej alta aktiva rolo** (administrador > coordenador > librarian > reader). En la revizian protokolon, aliflanke, oni vidas ĉiun linion aparte.

## 5.7. Eraroj kaj gardrimedoj

Kelkaj kazoj, kiujn oni renkontas regule:

**«La SIGB diras, ke la persono jam estas librarian.»** Tio verŝajne estas vera. Kontrolu la langedon **Equipe**: se la persono jam aperas tie kiel librarian, vi provas promocii rin al la sama nivelo, la SIGB redonas siletan sukceson (`{ok: true, no_change: true}`) ĉar nenio estas farenda.

**«Mi ne vidas la personon en la listo.»** Tri eblaj kazoj: (a) ri ankoraŭ ne havas AnarBib-konton (uzu la invitad-per-retmesaĝa laborfluo venonta); (b) ri havas konton sed ne estas aliĝita en neniu biblioteko (ri devas aliĝi al via biblioteko kiel `reader` unue); (c) ri estas en la reto sed filtrita de la serĉo — provu per ria ekzakta retpoŝtadreso.

**«Mi erare alklikis Promocii.»** Ne paniku. Uzu **«Peti forigon»** por malfermi 7-tagan karencperiodon (cf. ĉapitro 6), aŭ petu la personon alklaki **«Mi transdonu»** (tuja aŭtoretrogrado). Mencii «manipula eraro» kiel kialon.

**«La persono ne ricevas la retmesaĝon.»** Unue kontrolu la literumadon de ria retpoŝtadreso en ria profilo, kaj petu rin rigardi la spaman dosierujon. Se la problemo persistas, parolu kun ret-administrant-in-o: ĝi estas verŝajne retpoŝta konfiguracia problemo por esplori.

## 5.8. Se la regulo ĝenas vin

Pluraj aferoj povas ne konveni al vi en ĉi tiu ĉapitro:

- **La kooptadprincipon mem** (P2). Vi pensas, ke ĉia engaĝita `reader` devus povi libere transiri al `librarian` sen bezonata kooptado. Tio estas fundamenta politika debato, tuŝanta la principon P1. Porti ĝin sur la reta koordinadkanalon kaj verŝajne diskuti ĉe renkontiĝo.

- **La mankon de difinita doktriino pri «kiam alklaki»** (§5.4). Vi pensas, ke la gvidilo devus rekomendi nur unu doktrinecon. Aŭ kontraŭe, vi trovas, ke ĝi sugestas tro multajn. Proponi amendon al ĉi tiu ĉapitro, argumentante.

- **La fizikaj validadreĝimoj** (§5.5). Vi pensas, ke oni bezonas trionon («prokrastita validado», «fora validado», alia). Porti tion al `spec-validation-physique.md`.

- **La plurobla membreco** (§5.6). Vi pensas, ke ĝi estas nenecese kompleksa kaj ke devus ekzisti unu sola rolo por persono por biblioteko. Tio estas datumodela decido, pli struktura ol ĝi ŝajnas. Porti tion kun la programist-in-oj.

Vidu ĉapitron 4 por la ĝenerala amendada proceduro, kaj anekson C por la notan modelon.

\newpage

# 6. Transdoni, eligi, suspendi

Ĉi tiu ĉapitro traktas la transiraĵojn T3 ĝis T8 — tio estas **ĉion, kio eliras person-in-on el teamo**, aŭ metas ri-n en paŭzon. Politike, tio estas verŝajne la plej grava ĉapitro de la gvidilo, ĉar la mekanismoj de eligo troviĝas en la koro de la anarĥista projekto (cf. ĉapitro 1, §1.2).

## 6.1. La politikaj principoj

Tri principoj strukturas ĉi tiun ĉapitron :

> **P3 — Volontula malaltrangigo ĉiam eblas.** Ĉiu person-in-o kun rolo staff povas malaltrangi si-n mem en iu ajn momento, sen konsultiĝo. « Mi transdonegas la manon » estas fundamenta rajto.

> **P4 — Ekskludo kadrita per kvarenta periodo.** La nevolontula ekskludo de `librarian` fare de `coordenador` postulas kvarentan periodon de sep tagoj antaŭ efektiviĝo. Ĉi tiu periodo permesas kolektivan deliberadon kaj eventualan nuligon fare de alia `coordenador`.

> **P6 — Sistemaj sciigoj.** Ĉia ŝanĝo de rolo ekigas retpoŝton al la koncernit-in-o kaj al la tuta koordinado.

La fundamenta ideo estas, ke oni neniam eliras iun el teamo « surprize » aŭ « silente ». Aŭ la person-in-o decidas si-n mem (kaj tio estas tuja), aŭ la kolektivo petas (kaj tio estas spurita, sciigita, kaj deliberebla ĝis la lasta sekundo).

## 6.2. Transdoni la manon : mem-malaltrangigo (T3 kaj T4)

Tio estas la **plej fundamenta rajto** en la registara sistemo de AnarBib. Ĉiu person-in-o kiu ekzercas staff-funkcion povas, en iu ajn momento, sen ia ajn konsultiĝo, forlasi ĝin.

### Kiam uzi ĝin

- Vi ne havas plu la tempon por plenumi la funkcion.
- Vi ne plu rekonas vin en la decidoj de la koordinado.
- Vi malkonsentas kun decido kaj volas desolidariĝi el ĝi.
- Vi volas simple rotacii la funkcion.
- Vi bezonas paŭzon.
- Ne necesas doni kialon, fakte. La rajto foriri estas senkondica.

### Proceduro

1. Iri al `/biblioteca`, langeto **Equipe**.
2. Sur **via propra linio**, klaki **« Mi transdonegas la manon »**.
3. Elekti la nivelon de malaltrangigo :
   - Se vi estas `coordenador`, vi povas elekti « reiri al librarian » (vi restas en la teamo kiel `librarian`) aŭ « forlasi la teamon » (vi refaras `reader`).
   - Se vi estas `librarian`, vi povas elekti « forlasi la teamon » (vi refaras `reader`).
4. La modalo memorigas la sekvojn. Konfirmi.

### Tuja efiko

- Via aktuala membreco (`librarian` aŭ `coordenador`) iras al `inactive`.
- Se vi ne havis jam la celitan membreecon (`reader` aŭ `librarian`), ĝi estas kreata kiel `active`.
- Retpoŝto al la tuta koordinado + al vi mem (konfirmo).
- Revizioregistro : `action='self_demoted'`.

### Speciala kazo : vi estas la sola aktiv-in-a `coordenador`

La SIGB **permesas al vi foriri**, sed ĝi avertas vin :

> ⚠️ ATENTU : vi estas la sola aktiv-in-a `coordenador` de [biblio]. La biblio restos sen koordinado. La administrant-in-oj de AnarBib estos sciigit-in-oj. Daŭrigi ?

Se vi konfirmas :
- Via `coord`-membreco iras al `inactive`.
- La biblio eniras **degraditan reĝimon** : la `librarian`-oj povas daŭre administri pruntojn, validigi membriĝojn, ktp., sed nenia modifado de la publika identeco aŭ de la agordo estas ebla ĝis la kooptado de nova `coord`.
- Retpoŝto al ĉiuj ret-administrant-in-oj : « La biblio X ne havas plu `coordenador`. Jen la aktivaj `librarian`-oj : ... »

Politike, tio estas grava : la SIGB **ne malhelpas** vian forladon. Sed ĝi informas la reton, por ke ret-administrant-in-o povu, se vi tion deziras kaj se la loka kolektivo bezonas ĝin, kontakti por helpi organizi la transiron. Tio estas la funkcia rotacio en ago.

### Teknika flanko

RPC : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

## 6.3. Peti la elirejon de `librarian` (T5)

Kiam la kolektivo decidas, ke iu person-in-o devas forlasi la teamon, kaj tiu person-in-o ne malaltrangiĝas si-n mem, oni malfermas **elirpeton kun sep-taga kvarento**.

### Antaŭkondiĉoj

- Vi estas aktiv-in-a `coordenador+` de la biblio.
- La celita person-in-o havas `librarian`- aŭ `coordenador`-membreecon `active`.
- Vi ne estas la celita person-in-o (alie uzi §6.2).

### Proceduro

1. Iri al `/biblioteca`, langeto **Equipe**.
2. Sur la linio de la person-in-o, klaki **« Peti la elirejon »**.
3. La modalo kiu malfermiĝas estas **ruĝa kaj insista**. Ĝi memorigas :
   - La kvarentan periodon : « Ĉi tiu peto efektiviĝos la [dato J+7] krom se nuligita fare de alia `coordenador`. »
   - La reverseblan karakteron : « Nuligebla de iu ajn `coord` ĝis la dato de efiko. »
   - La kolegialan karakteron : « Ĉiuj aktivaj `coord`-oj estos sciigit-in-oj. »
4. Kampo **« Kialo »** estas deviga — minimume 20 signoj. Nenia silenta elirpeto. La kialo povas esti politika (« decido de AG la 04/05 ») aŭ praktika (« anoncita geografia foriro »). Ĝi estos legebla de ĉiu staff-in-o en la revizioregistro.
5. Konfirmi.

### Tuja efiko

- La membreco iras al `pending_removal`.
- Kampo `pending_removal_until` = `now() + 7 days`.
- Kampo `pending_removal_requested_by` = vi.
- **Nenia aliro** por la person-in-o dum la kvarento (la membreco estas frostigita kiel `suspended`).
- Retpoŝto al la koncernit-in-o : « La koordinado petis vian elirejon el la teamo [biblio] (antaŭaverto ĝis [dato]). Ĉi tiu decido rilatas al la organika vivo de la kolektivo [biblio] ; por ia ajn diskuto, turniĝu al la koordinado. »
- Retpoŝto al ĉiuj aktivaj `coordenador`-oj : kun via nomo kaj la kialo.
- Revizioregistro : `action='removal_requested'` kun via `actor_user_id` kaj la kampo `reason`.

### Efiko je J+7 (aŭtomata cron)

Se la peto ne estis nek nuligita nek trarondita :
- La membreco iras al `inactive`.
- Fina retpoŝto al la person-in-o kaj al la koordinado : « Elirejo efektiviĝis. »
- Revizioregistro : `action='removal_completed'`.

### Teknika flanko

RPC : `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron : `cron_team_pending_removal_complete` (efektiviĝas ĉiutage).

## 6.4. Nuligi elirpeton (T8)

La **kolegiana gardostaro** de la sistemo. Iu ajn `coord` — ne nepre tiu kiu petis — povas nuligi elirpeton dum la kvarenta periodo.

### Kiam uzi ĝin

- La kolektiva diskuto kondukis al alia decido (pereigo, provizora suspendo anstataŭe, ktp.).
- La komenca peto estis farita varm-kape kaj la koordinado volas repreni la manon kolegialie.
- La celita person-in-o estis fine atingita kaj la situacio estas malstreĉigita.

### Proceduro

1. Iri al `/biblioteca`, langeto **Equipe**, sekcio **Suspendoj kaj aktualaj antaŭavertoj**.
2. Sur la linio de la person-in-o en `pending_removal`, klaki **« Nuligi la peton »**.
3. Simpla konfirma modalo. Kampo « Kialo » nedeviga.
4. Konfirmi.

### Tuja efiko

- La membreco reiras al `active`.
- Kampo `pending_removal_until` restarigita al NULL.
- Retpoŝto al la person-in-o : « La elirpeto estis nuligita. Vi retrovas viajn prerogativojn. »
- Retpoŝto al la tuta koordinado.
- Revizioregistro : `action='removal_cancelled'` kun via `actor_user_id`.

### Politike

La nuligado estas volonte tre simple aktivegebla. Tio estas mekanismo de **kolegiana rebalancigo** : se `coord` petis elirejon varm-kape, iu ajn alia `coord` povas suspendi la efektivigon dum la kolektivo deliberas. Tio igas elirpetojn malpli pezajn (nenia nereversebla dramo) sed ankaŭ malpli facilajn (iu ajn povas kontraŭdiri vin). Tio estas la intereso de la kvarento.

### Teknika flanko

RPC : `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Tuja suspendo : la konservativa mezuro (T6 kaj T7)

La suspendo estas **malsama** ilo ol la elirpeto. Ĝi estas **tuja**, sen kvarento, kaj **sen maksimuma daŭro**. Ĝi ne estas ekskludo, ĝi estas **paŭzigo**.

### Kiam uzi ĝin

Tipaj kazoj priskribataj de la spec :

- **Kompromitita konto** : oni havas kialojn pensi, ke la pasvorto de la person-in-o foriris. Oni suspendigas en atendo ke ri ŝanĝu sian pasvorton.
- **Urĝe raportita ĉikano** : legant-in-o raportas misuzan konduton de staff-membr-in-o. Oni suspendigas en atendo de la kolektiva esploro.
- **Manifeste misuzema konduto** observata rekte : oni suspendigas dum la koordinado kunvenas.
- **Konflikto dum mediacio** : la person-in-o estas volontule paŭzigita dum la mediacio atingas konkluzion.

### Proceduro

1. Iri al `/biblioteca`, langeto **Equipe**.
2. Sur la linio de la person-in-o, klaki **« Suspendi »**.
3. Modalo kun **deviga kampo « Kialo de la suspendo »** (minimume 20 signoj). Ĉi tiu kialo estos legebla en la revizioregistro de ĉiu aktiv-in-a staff-in-o.
4. Konfirmi.

### Tuja efiko

- La membreco iras al `suspended`.
- **Nenia aliro** por la person-in-o. La nomina rolo estas konservita (ri estas ankoraŭ montrat-in-a kiel « suspendit-in-a `librarian` ») sed ri ne povas plu fari ion ajn.
- Retpoŝto al la koncernit-in-o : urĝa, kun la kialo, kaj — en la kazo de kompromitita konto — invito ŝanĝi sian pasvorton.
- Retpoŝto al la tuta koordinado.
- Revizioregistro : `action='suspended'` kun via `actor_user_id` kaj la kampo `reason`.

### Levado de la suspendo

Kiam la situacio estas solvita (konto reblokita, mediacio atingita, esploro konkluzita, ktp.) :

1. Langeto **Equipe** → sekcio **Suspendoj kaj aktualaj antaŭavertoj**.
2. Sur la suspenditaj linio, klaki **« Levi la suspendon »**.
3. Simpla modalo. Kampo kialo nedeviga sed rekomendita por politike fermi la episodon.
4. Konfirmi.

Efiko : reveno al `active`, retpoŝtoj, revizioregistro `action='unsuspended'`.

### Grave : suspendo kontraŭ elirejo

La distingo estas decida :

| | Suspendo (T6) | Elirejo (T5) |
|---|---|---|
| Efiko | Tuja | Prokrastita (J+7) |
| Daŭro | Senlima | 7 tagoj poste `inactive` |
| Reversebla de | Eksplicita levado | Nuligado dum la kvarento |
| Tipa uzo | Konservativa mezuro | Ekskluda decido |
| Subesta politiko | « Ni donas al ni la tempon kompreni » | « Ni decidis, ke ĉi tiu person-in-o eliras » |

La SIGB **rifuzas** transdoni membreecon de `suspended` rekte al `pending_removal` (la transiro ne estas permesata de la matrico). Kial : tiuj estas du malsamaj politikaj temporalecoj. Por transiri de unu al la alia, oni devas eksplicite **levi la suspendon** unue (reveno al `active`), poste peti la elirejon (`pending_removal`). Ĉi tiu duobla paŝo estas volunta : ĝi devigas la kolektivon eksplicite registri la transiron.

### Teknika flanko

RPC suspendi : `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC levi : `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Malaltrangi alian `coordenador` (T3 kolegiana)

Iom aparta kazo : kion fari kiam la koordinado volas **malaltrangi `coordenador`-in-on** kiu ne malaltrangiĝas spontanee ?

La registara spec traktas ĉi tiun kazon kiel **elirpeton kun kvarento** celanta la `coordenador`-membreecon. Konkrete, oni uzas la saman proceduron kiel en §6.3 (« Peti la elirejon »), sed elektante la rolon `coordenador`. La person-in-o eniras `pending_removal` sur sia `coordenador`-membreco ; je J+7, ĉi tiu membreco iras al `inactive`. Se ri havis paralelan `librarian`-membreecon, ĝi restas aktiva (kaj la person-in-o « refalas » `librarian`). Alie, ri refaras simplan `reader`.

Tio estas volonte la sama mekanismo kiel por la `librarian`-oj, kun la samaj gardstoraroj. **Neniu alia `coord` havas specialan potencon** super siaj kolegoj : la proceduro trairas la kvarentan periodon kaj la kolegiecon.

## 6.7. Forlasita konto : aŭtomata eliro (T9)

La SIGB inkluzivas mekanismon de **aŭtomata eliro** por kontoj kiuj ne havis konekton de longa tempo.

### La sojlo

La SIGB rigardas la kampon `last_sign_in_at` flanke de Supabase. Se staff-membreco havas uzant-in-on kies lasta konekto datas de pli ol **9 monatoj**, la konto estas progrese elirinta :

- **J-30 tagoj** (8 monatoj post la lasta konekto) : avertretpoŝto al la person-in-o (« via membreco estos malaktivigita en 30 tagoj sen konekto »).
- **J-7 tagoj** : memorigretpoŝto.
- **J = 9 monatoj** : aŭtomata transiro al `inactive`. Fina retpoŝto al la person-in-o + al la tuta koordinado.

### Kial ĉi tiu regulo

Tio estas kompromiso inter du postuloj :

- Ne lasi **senfine treni** fantomajn membrecojn kiuj artefarite ŝveligas la teamojn.
- Ne **krude elpeli** person-in-on kiu estus nur preninta paŭzon kaj intencas reveni.

Simpla konekto sufiĉas por reinicialigi la komptanton. Ne necesas efektivigi agon, nur konektiĝi.

### Speciala kazo : la sola `coord` forlasas

Se la aŭtomate elirinta person-in-o estas la **sola aktiv-in-a `coordenador`** de la biblio, la cron eskalas al ret-administrant-in-o **antaŭ** efektivigi la elirejon. La ret-administrant-in-o estas sciigit-in-a per retpoŝto, povas kontakti la koordinadon (se iu fragmento restas) aŭ la `librarian`-ojn de la biblio, kaj koordini la transiron.

Politike, tio konformas al tio, kion oni faras kiam la sola `coord` malaltrangiĝas eksplicite (§6.2) : oni ne blokas la elirejon, sed oni alarmas la reton por ke ĝi povu helpi se bezonata.

## 6.8. Kelkaj limlokaj kazoj sciindaj

**Person-in-o en `pending_removal` kiu petas foriri tuj.** Ri povas. Ri nur bezonas uzi si-mem « Mi transdonegas la manon » (mem-malaltranigo T4). Efiko : tuja transiro al `inactive`, trarondo de la kvarento. Politike, tio estas kohera : la rajto P3 (mem-malaltranigo) estas senkondica.

**Person-in-o en `suspended` kiun oni volas definititve ekskludi.** Vidu §6.5 « Grave : suspendo kontraŭ elirejo ». Oni devas levi la suspendon unue, poste peti la elirejon.

**Iu petas sian propran elirejon per « Peti la elirejon ».** La SIGB rifuzas per eksplicita mesaĝo : « Por forlasi la teamon, uzu la opcion "Mi transdonegas la manon" (mem-malaltranigo). » Tio estas volunta : konfuzi personan decidon kun kolektiva decido neklarigus la politikan semantikon.

**Provo malaltrangi ret-administrant-in-on.** Sisteme rifuzita. La rolo de ret-administrant-in-o povas esti modifata nur per la specifaj mekanismoj de la spec admin-reseau (cf. ĉapitro 8). Neniu loka `coord` povas detroni ret-administrant-in-on.

## 6.9. Se la regulo vin ĝenas

**La 7-taga kvarenta periodo ŝajnas al vi tro longa aŭ tro mallonga.** Porti sur `spec-gouvernance-roles.md`, §4.4 kaj §5.6.

**Vi trovas, ke la suspendo sen maksimuma daŭro estas malfermita pordo al arbitro.** Tio estas serioza politika temo. Oni povas enkonsideri aldoni limdaŭron, preter kiu suspendo devas esti konvertita al elirejo aŭ levita. Por diskuti en ret-koordinado, poste porti sur la spec.

**Vi trovas, ke la deviga kialo sur suspendo estas troo da burokratio.** Aŭ inverse vi trovas, ke la minimumo de 20 signoj estas tro mallonga. Por porti sur la spec.

**Vi trovas, ke la aŭtomata eliro je 9 monatoj estas tro rapida aŭ tro malrapida.** La sojlo estas parametrebla, sed ĝi estas hodiaŭ la sama por ĉiuj biblioj de la reto. Ĉu necesas igi ĝin agordebla laŭ biblio ? Por diskuti.

Vidu ĉapitron 4 kaj anekson C por la amendoproceduron.

\newpage

# 7. Kiam io misfunkciigas

Ĉi tiu ĉapitro traktas **esceptajn situaciojn**, kie la ordinaraj mekanismoj de regado ne sufiĉas, aŭ funkcias sed postulas politikan saĝon. Estas ankaŭ la ĉapitro, kie oni parolas malkaŝe pri **bibliotek-in-oj sen (aŭ ne plu kun) kolektiva delibera vivo**, ĉar la silento pri ĉi tiu temo kaŭzus pli da damaĝo ol la malkaŝeco.

## 7.1. Biblioteko sen ĜK aŭ kun malmultaj membroj

La kazo estas pli ofta ol ŝajnas. Komencanta biblioteko kun du aŭ tri person-in-oj. Biblioteko kies kolektivo malkreskis pro sinsekva eliro. Biblioteko kies ĜK ne plu kunvenas de iom da tempo, pro manko de person-in-oj aŭ pro senkuraĝiĝo.

La SIGB ne enmiksiĝas en la politikan vivon de kolektivo. Sed ĉi tiu gvidilo devas diri malkaŝe, kio ŝanĝiĝas kiam tiu kolektiva vivo estas malforta.

### Kio ŝanĝiĝas konkrete

**La vorto "kooptado" fariĝas ambigua.** Ĉe du person-in-oj, kiu kooptas kiun? Se la sola koordinant-in-o volas enigi Voltairine en la teamon, ri decidas "sola" en la politika senco de la vorto. La SIGB permesos ĝin (koordinant-in-o+ povas koopti), sed tio ne plu estas la kunlaboro de politika kolektivo — ĝi estas persona decido kamuflita. Ĝi estas nek malbona nek bona, sed simple agnoskenda.

**La deliberoj estas teoriaj.** Peto pri forigo ĉe 7 tagoj, en biblioteko kun 2 person-in-oj, ne havas iun alian por kontraŭdiri ĝin krom tiu-in-o, kiu petis ĝin. La "kolektiva gardisto" fariĝas mem-reflekto.

**La risko de personigado kreskas.** Kiam decido ne plu estas kolektiva, ĝi dependas de la karaktero, la disponebleco, kaj la luciditeco de unu aŭ du person-in-oj. Tio ne estas katastrofo en si mem, sed ĝi estas pli fragila.

### Niaj eksplicitaj rekomendoj

**1. Agnoski la situacion.** Ne ŝajnigu, ke vi estas granda deliberanta kolektivo, se vi estas du. Politike, estas pli sane skribi "decido farita de mi sola, por validigi kiam la kolektivo kreskos" en la kampo "Kialo" de la revizio-protokolo, ol skribi "decido ĜK" ĉe ĜK kiu ne ekzistas.

**2. Serĉi dialogon ekstere.** Se vi estas sola-in-o aŭ du-in-oj, kaj grava decido devas esti farita (kooptado, forigo, suspenso), kutimiĝu paroli pri ĝi kun kamarad-in-oj el aliaj bibliotekoj de la reto, aŭ kun ret-administrant-in-o. Ne por peti permesson de ili — ili ne devas validigi la internajn decidojn de via biblioteko — sed por ricevi eksteran kritikan reagpon. La Matrix-reto de AnarBib estas kreita por tio.

**3. Preferi reversiblajn transirojn.** Kiam via kolektivo estas malgranda, evitu se eble nereversiblajn decidojn. Suspenso estas pli reversibla ol forigo. Forigo pasas tra 7 tagoj dum kiuj vi povas ŝanĝi opinion. Kooptado estas nuligebla. Donu al vi tempon.

**4. Dokumenti kio okazas.** La kampo "Kialo" de la revizio-protokolo estas via plej bona amiko. Ju pli da kunteksto vi metas en ĝin ("kooptado de Voltairine, decidita sola, por validigi ĉe la venonta permanento"), des pli la decido estos kuntekstigebla poste, de vi mem same kiel de nova-in-o membro de la kolektivo.

**5. Se vi estas vere sola-in-o, petu helpon.** Biblioteko kun unu person-in-o estas politike en danĝero. La SIGB detektas tion en la momento, kiam la lasta koordinant-in-o retrogradas sin (§6.2) aŭ forlasas (§6.7), kaj alarmas la ret-administrant-in-ojn. Vi ankaŭ povas preni la iniciaton: sendu retpoŝton al la reta koordinado por klarigi la situacion. Pluraj bibliotekoj de la reto travivis malplenigojn kaj ricevis helpon por rekonstituiĝi.

### Kion la gvidilo ne faras

Ĝi **ne** provizas specialan proceduron por malgrandaj bibliotekoj. Tio estas intenca. La reguloj de la SIGB aplikatas uniforme — kio ŝanĝiĝas estas la politikaj kondiĉoj, en kiuj ili aplikiĝas. Agnoski ĉi tiun nuancon estas parto de la politika matureco de koordinant-in-o.

## 7.2. Interpersona konflikto en koordinado

Konflikto eksplodas inter du staff-membroj. La laboro ne plu estas farata ĝuste, la etoso malboneneras, legant-in-oj perceptas la tension.

### Kion la SIGB povas fari

Ne multon, rekte. La SIGB ne arbitracias konfliktojn. Sed ĝi provizas **uzeblaajn ilojn**:

- **Provizoran suspenso (T6)** de unu aŭ ambaŭ person-in-oj, dum la konflikto estas mediaciata. Ĉi tion la spec eksplicite nomas "konflikto dum mediaciado" kiel legitiman uzkazon de la suspenso.
- **Mem-retrogradigon (T3/T4)** — se iu el la du person-in-oj elektas retiri sin, tio estas tuja.
- **Revizio-protokolo legebla de ĉiu staff-in-o** — permesas al la tuta staff-aro vidi, kiu faris kion, kaj eviti opakajn manipuladojn de koordinant-in-o, kiu celus solvi la konflikton forirante la alian kaŝe.

### Kion la kolektivo devas fari

- **Mediaciado.** La SIGB ne mediacias. Necesas fidinda tria person-in-o, ekster la konflikto. Laŭ la konfiguracioj: alia koordinant-in-o de la biblioteko, kamarad-in-o el alia biblioteko, ret-administrant-in-o.
- **Kolektiva decido.** Se la mediaciado rezultas en decido (unu el la du person-in-oj forlasas la koordinadon, aŭ oni difinas reviditan laborkadroon), la SIGB ekzekutos tiun decidon per la normalaj RPC-oj.
- **Politika spuro.** Se la decido estas forigi iun-in, la kampo "Kialo" devus mencii la mediacion-procezon ("forigo post mediaciado de TT/MM, kolektiva decido") por ne reverki la historion poste.

### Kion oni devas eviti

- **Uzi suspenso kiel armilon** en la konflikto. La suspenso estas farita por paŭzigi, ne por gajni rilaton de forto. Se koordinant-in-o suspendas la alian sen mediaciado-proceso, tio estas observebla en la revizio-protokolo, kaj ĝi estas politike problematika.
- **Mallongcirkuiti la karencon** per teknikaj manovraoj (suspensi, poste "akceli" per aliaj rimedoj). Ĉio estas spurita, kaj la reto tion rimarkos.
- **Silenti pri la revizio-protokolo.** Ĉiu staff-in-o vidas kio okazas (P5). Se vi provas kaŝi la konflikton, vi perfidas la travideblon de la kolektivo.

## 7.3. Signalita ĝenado

Legant-in-o signalas, ke staff-membro kondutas abuzeme (seksa ĝenado, misuzado de potenco, rasisma konduto, ktp.).

### Rekomendata aliro

**1. Preni la signalon serioze**, tuj, eĉ se la signalanta person-in-o estas izolita kaj eĉ se la signalit-in-o estas "konata kaj ŝatata" de la koordinado. La reflekso forŝovi la signalon kiel "verŝajne troigitan" estas la plej ofta eraro.

**2. Tuja suspenso (T6)** de la signalit-in-o, **konserve**, atendante la esploran komisionon. La kampo "Kialo" devus diri ion kiel "Konserva suspenso post signalo ricevita TT/MM, atendante kolektivan esploron". La suspenso **ne** estas akuzo — ĝi estas paŭzigo.

**3. Konstitui esploron-grupon.** Ekster la programaro. Minimume: kamarad-in-oj ekster la rekta potenco-situacio, kapablaj aŭskulti ambaŭ flankojn sen biaso. Tiu grupo povas inkludi kamarad-in-ojn el aliaj bibliotekoj, se la biblioteko estas malgranda aŭ se ĉiuj koordinant-in-oj estas implikataj en la afero.

**4. Komuniki kun la signalanta person-in-o.** Ri bezonas scii, ke la afero estas prenita serioze, kaj ke mezuroj estas en toko. Ne lasi rin en necerteco.

**5. Atingi decidon.** Laŭ tio, kion la esploro malkaŝas:
   - Levigo de la suspenso (T7) se la signalo ne estas konfirmita.
   - Definitiva forigo (T5 kun karencio) se la signalo estas konfirmita kaj la decido estas forigi la person-in-on.
   - Meza sankciado (revidita laborkadroo, trejnado, malproksimigo de certaj funkcioj) se la situacio estas pli nuancita.

**6. Politike spuri.** La kampo "Kialo" en la revizio-protokolo devus reflekti la kolektivan decidon. Sen detaloj pri la viktimo (GDPR), sed kun formulaĵo, kiu igas la decidon legebla.

### Kion oni ne devas fari

- **Peti forigo rekte** sen antaŭa suspenso, kiam la situacio estas urĝa. Dum 7 tagoj la signalit-in-o konservus siajn rajtojn, kio estas kontraŭdira al la urĝeco de ĝenad-signalo.
- **Suspendi senfine sen decido** sub la preteksto, ke "oni ne sukcesas tranĉi". Suspenso, kiu daŭras plurajn monatojn sen decido, mem fariĝas perfortado (kontraŭ la suspendit-in-o, kiu ne povas defendi sin, kaj kontraŭ la signalant-in-o, kiu ne ricevas respondon).
- **Solvi interne sen la reto.** Se vi estas malgranda biblioteko kaj la situacio superas vin, petu helpon de ret-administrant-in-oj. Vi ne estas sola-in-oj.

## 7.4. Kompromitita konto

Staff-person-in-o vidas sian konton kompromitita (pasdorto likita, suspektado de neaŭtorizita aliro).

### Tuja procedo

**1. Tuja suspenso (T6)** de la konto, kun eksplicita kialo: "Suspektado de kompromitado, PP verŝajne likita, kontrolo en toko".

**2. Komunikado kun la koncernata person-in-o.** La person-in-o aŭtomate ricevas urĝan retpoŝton indikante la suspendon kaj invitante rin ŝanĝi sian pasdorton. La koordinant-in-o kiu suspendas devus ankaŭ kontakti rekte (telefono, alia sekura kanalo) por konfirmi.

**3. Rapida esploro.** Kio okazis? Ĉu la konto faris nekutimajn agojn en la revizio-protokolo (strangaj kooptadoj, konfiguracio-modifoj, ktp.)? Se jes, tuj avizi ret-administrant-in-on por helpi analizi.

**4. Levigo de la suspenso (T7)** kiam:
   - La pasdorto estas ŝanĝita.
   - La eventuala damaĝo estas konstata kaj riparata (nuligado de abuzaj agoj, restaŭrado de datumoj, ktp.).
   - La person-in-o estas cifere sekura.

### Politike

Suspenso pro kompromitita konto **ne estas kulpigo**. Ĝi estas reciproka protekto: oni protektas la person-in-on (malhelpante, ke ri estu uzata de atakant-in-o) kaj la bibliotekon (malhelpante, ke damaĝoj estu farataj en ĝia nomo). La retpoŝto al la person-in-o devus emfazi ĉi tiun **ne-disciplinan** karakteron.

## 7.5. Biblioteko sen aktiv-in-a koordinant-in-o nek librarian

La katastrofa scenaro: ne plu iu ajn aktiv-in-a staff-in-o. Tio povas okazi per akumulita aŭtomata eliro (ĉiuj staff-membroj forlasis siajn kontojn samtempe), per kolektiva eksigo (malofta sed ebla), aŭ per sinsekvaj forigoj.

### Konsekvencoj

- La biblioteko restas **teknika aktiva** (ĝia videbleco, ĝia katalogo restas alireblaj laŭ la normalaj RLS-reguloj).
- Sed **nenia administra ago** povas plu esti farata per la normala UI: neniu validigo de enskribigo, neniu pruntadministrado, nenia modifado de la konfiguracio.
- **Urĝa retpoŝto al ret-administrant-in-oj** de la kron-tasko, kiu detektas la situacion.

### Restartigo-procedo

Ekster-spec, sed jen kio estas praktikata:

**1. Kontaktado** de ret-administrant-in-o kun la loka kolektivo, per ĉiuj disponeblaj kanaloj (la restantaj enskribita-in-aj legant-in-oj, la eksteraj koordinatoj de la biblioteko se ili ekzistas, la loka konatarreto).

**2. Politika kontrolo**: ĉu la kolektivo ankoraŭ ekzistas? Ĉu ĝi volas daŭrigi sian ekziston? Se estas membroj sed ili simple lasis fali la teknikajn funkciojn, oni povas rekoopti novajn staff-in-ojn per ekster-laborflua kooptado.

**3. Ekster-laborflua kooptado** de ret-administrant-in-o, per rekta SQL aŭ per la UI (ret-administrant-in-o rajtas agi kiel koordinant-in-o+ sur iu ajn biblioteko, cf. ĉapitro 2). La ekster-laborflua kooptado devas esti spurita en la revizio-protokolo kun eksplicita kialo: "Repreno de koordinado post vakanco, post kontakto kun la kolektivo de TT/MM, de ret-administrant-in-o X". Kaj — ŝlosila doktrina punkto — **antaŭa informado al la loka koordinado estas deviga**, krom se la biblioteko ne plu havas iun ajn vivant-in-an staff-membron, en kiu kazo la informado iras al la restantaj aktivaj `reader`-in-oj (cf. §7.6).

**4. Se la kolektivo ne plu ekzistas**: malfermo de diskuto pri la **deca fermiĝo** de la biblioteko. Kiajn datumojn konservi, kiujn forigi, kiel komuniki al la legant-in-oj, ktp. Tio estas laborfluo, kiu devas esti formalizita aparte.

## 7.6. La interveno de ret-administrant-in-o sur loka biblioteko

Kazo, kiun oni jam tuŝas en ĉapitro 2, sed kiu meritas praktikan disvolviĝon en ĉi tiu ĉapitro pri esceptaj situacioj.

### La doktrino de la reto

> **Interveno de ret-administrant-in-o sur loka biblioteko devas esti antaŭita de informado al la koncernata loka koordinado, krom en kazo de esenca urĝeco.**

La antaŭa informado **ne estas peto pri permesado**. La ret-administrant-in-o rajtas agi (tio estas la senco de la transversa rajto). Sed ĝi estas marko de respekto al la loka aŭtonomio, kaj ĝi konservas la eblecon de alia aranĝo.

### Kio estas "esenca urĝeco"

Tio estas volonte restriktiva. Tipaj kazoj:

- **Aktiva kompromitado**: en-toka ago minacas la integrecon de la biblioteko aŭ de la reto (atakanta konto, kiu modifas membrecojn en realtempo, ktp.).
- **Ĝenado en toko**: staff-membro aktive misuzas siajn funkciojn, la danĝero por legant-in-oj estas tuja.
- **Atako kontraŭ la platformo**: infiltra provo, eksfiltrado de datumoj, ktp.

Ekster ĉi tiuj kazoj, **oni prenas tempon por informi**.

### Kiel informi

Antaŭ la interveno (aŭ dum ĝi, se la urĝeco postposte pravigas tion):

- **Retpoŝto al la loka koordinado** klarigante, kio estos farata, kial, kaj kun kia spureblo.
- **Mencio en la tabelo `cross_library_actions_log`** kun kritikeco-nivelo indikante la naturon de la ago. Ĉiuj aktivaj koordinant-in-oj de la biblioteko ricevas sciigon.
- **Disponebleco al dialogo**: la loka koordinado devas povi demandi, peti klarigojn, eĉ negoci alian aranĝon ("lasu nin unue provi").

### Kion oni devas eviti

- **La silenta interveno**: agi sur la bibliotekon sen informi la koordinadon. Eĉ se teknika ĝi estas spurita, politike ĝi estas malobservo de la loka suvereneco.
- **La uzo de la transversa rajto kiel nadzpovo**: iri vidi "kio okazas" en biblioteko sen operacia kialo. La transversa rajto ekzistas por kazoj de prizorgado aŭ mediaciado, ne por scivolemo.
- **La trudado de politikaj decidoj**: ret-administrant-in-o ne povas diri al biblioteko, kiel fari siajn kooptadojn, kiel administri siajn internajn konfliktojn, aŭ kian akceptan politikon elekti. La transversa rajto estas teknika, ne politika.

## 7.7. Se la regulo ĝenas vin

**Vi trovas, ke la doktrino pri antaŭa informado estas tro malstroga** (ret-administrant-in-o povus misuzadi la "esencan urĝecon"). Por diskuto: ĉu necesas pli strikta difino de la urĝeco? Ĉu necesas dua ret-administrant-in-o, kiu konfirmas la urĝecon?

**Vi trovas la doktrinon tro strikta** (foje oni bezonas agi rapide sen ĉion klarigi). Por diskuto: ĉu necesas distingi plurajn intervenajn nivelojn, kun malsamaj informadaj reguloj laŭ la kritikeco?

**Vi trovas, ke la silento pri la deca fermiĝo de biblioteko estas problematika** (§7.5). Vi pravas. Dediĉita spec probable devas esti skribita. Por porti al la reto.

**Vi trovas, ke ĉi tiu ĉapitro lasas tro da loko al improvizado** en la kazoj de ĝenado (§7.3). Verŝajne vera. Dediĉita spec pri la mediaciado- kaj esploro-procezoj povus esti utila. Por porti al la reto.

Vidu ĉapitron 4 kaj anekson C.

\newpage

# 8. La rolo de ret-administrant-in-o

Tiu ĉi ĉapitro estas specife adresita al ret-administrant-in-oj (nunaj aŭ estontaj), kaj al lokaj koordinant-in-oj kiuj volas kompreni kiel la reto mem-organiziĝas sur la supra nivelo. Ri kompletigas kaj aprofundigas ĉapitrojn 2 kaj 7.

## 8.1. Politike aparta funkcio

Antaŭ ĉio : esti **ret-administrant-in-o** ne estas rango, nek konsekrado, nek titolo. Temas pri **transversa funkcio** kiun la kolektivo de ret-administrant-in-oj delege donas al iuj el siaj membroj, surbaze de unuanima interkonsento de la jam-aktiv-ant-in-oj, kaj kiu povas esti forlasita iam ajn.

La politika projekto de la funkcio estas **vivigi la inter-biblioTekan koordinadon** : akcepti novajn bibliotekojn aliĝantajn al la reto, animacii diskutojn pri teknikaj kaj politikaj evoluoj de la SIGB, teknike prizorgi la platformon, interveni kiam iu biblioteko trovas sin en blokiĝo. Ne estas ĝi direkta funkcio. Estas ĝi animacia kaj servada funkcio.

### Kion ret-administrant-in-o rajtas fari (politike)

- Aktivigi novan bibliotekon kiu faris sian aliĝ-peton al la reto.
- Animacii inter-bibliotekan diskutadon (la kanalo Matrix `#anarbib`, renkontiĝoj, internaj dissendlistoj).
- Koordini platformajn evoluojn (specifoj, eldonoj, komunikadoj).
- Interveni en ajna biblioteko okaze de teknika blokiĝo (transversa rajto).
- Peri inter du bibliotekoj okaze de konflikto (se la koordinant-in-oj tion deziras).
- Proponi aŭ voĉdoni pri kooptado kaj kolektiva forigo de aliaj ret-administrant-in-oj.

### Kion ret-administrant-in-o ne rajtas fari (politike)

- Direkti bibliotekon.
- Trudi politikan decidon al biblioteko (akcepta politiko, validumad-reĝimo, internaj kooptadoj, ktp.).
- Forpuŝi lokan koordinant-in-on kontraŭ la volo de sia biblioteko.
- Unuflanka ŝanĝi la regulojn de la reto (tio trairas kolektivan diskuton de la administrant-in-oj kaj ideale de la koordinant-in-oj).

## 8.2. Kooptado per unanimo : kial

La ret-administrant-in-o ne estas aldonata per plimulto, sed per **unanimo** de la jam-aktiv-ant-in-oj. Tiu regulo povas surprizi — kial ne simpla plimulto, kvalifikita plimulto, aŭ kvorumo ?

La politika kialo estas simpla : la potenco de ret-administrant-in-o estas **transversa**. Ri povas interveni en ajna biblioteko. Necesas do, ke **ĉiu nuntempe aktiv-anta ret-administrant-in-o** pretu kunlabori kun la nova persono. Se ekzistas eĉ unu profunda malkonsenTo, la kunlaboro estos venenigita — prefere ne trudi tion.

Tiu regulo havas gravan praktikan sekvaĵon : **la veto estas facila**. Unu sola voĉo `opposed` sufiĉas. Tio estas volonta. Preferiĝas ke kooptado ne sukcesas, ol ke ĝi lasas jam-aktiv-ant-in-on en daŭra malfacila situacio.

## 8.3. Kooptada laborflujo, detale

### Etapo 1 — Propono

Aktiv-anta ret-administrant-in-o, el la interfaco `/rede/administradores` (venonta en paketo D), klakas **« Proponi kooptadon »**.

- Enigas la identecon de la proponata persono (serĉas en la datumbazo de uzant-in-oj de AnarBib).
- Enigas devigan **motivon** de **minimumo 20 signoj**. Tiu motivo estas legebla de ĉiuj administrant-in-oj, kaj — okaze de sukceso — estos inkludita en la sciigo al la kooptata persono.
- Konfirmas.

La SIGB :
- Kreas linion en `network_administrator_cooptation_proposals` kun `status='open'`, `expires_at = now() + 30 tagoj`.
- Aŭtomate registras la voĉon `favorable` de la proponanto.
- Sendas militan retmesaĝon al ĉiuj aliaj aktiv-antaj administrant-in-oj invitante ilin voĉdoni.

### Etapo 2 — Voĉdooj

Ĉiu alia aktiv-anta administrant-in-o havas 30 tagojn por voĉdoni. Tri elektoj :

- **`favorable`** : ri akceptas la kooptadon.
- **`opposed`** : ri metas sian veton. **Deviga pravigo** de minimumo 20 signoj. Tiu pravigo estos komunikata al la proponata persono kaj al la proponanto okaze de malakcepto.
- **`abstain`** : ri abstenas. **La absteno blokas** : la propono sukcesas nur per unanimo de `favorable` voĉoj. Nelevita absteno havas la saman praktikan efikon kiel veto, krom ke ĝi povas poste esti konvertita en `favorable` se la persono ŝanĝas opinion.

### Detalo v0.3 — Identec-malkaŝo

Elekto **« Malkaŝi mian identecon okaze de malakcepto »** estas defaŭlte markita. Se vi voĉdonas `opposed`, via identeco estos komunikata al la proponata persono kaj al la proponanto, aldone al via pravigo.

Vi povas **malmarki** tiun elekton por resti anonima. En tiu kazo, la pravigo estos transdonita sen via nomo (« iu oponent-in-o levis : ... »).

Politike, la **defaŭlta travidebleco** respondas al la milita kulturo de sinresponsigo de pozicioj. Sed la anonimeco restas ebla por kazoj kie opono eksponis la opont-in-on al misproporcia persona kosto.

### Aŭtomataj memorigoj

La cron sendas memorigojn al administrant-in-oj kiuj ankoraŭ ne voĉdonis :
- **T+14 tagoj** : « Vi ankoraŭ ne voĉdonis pri la kooptado de X. »
- **T+25 tagoj** : « Tiu propono eksvalidiĝas post 5 tagoj, prenu pozicion. »

### Etapo 3 — Konkludo

**Se iu voĉdonas `opposed`** : la propono tuj transiras al `status='rejected'`. La proponata persono kaj la proponanto ricevas retmesaĝon kiu klarigas la malakcepton, kun la pravigo (kaj la identeco de la opont-in-o se ri akceptis la malkaŝon).

**Se ĉiuj aktiv-antaj administrant-in-oj voĉdonis `favorable`** : la propono transiras al `status='completed'`. Linio estas aŭtomate enigata en `network_administrators` kun `status='active'` kaj `coopted_by_unanimity_of = ARRAY[<listo de voĉdontoj>]`. La persono ricevas bonvenon per retmesaĝo kaj resumo estas sendita al ĉiuj administrant-in-oj.

**Se 30 tagoj pasos sen atingi konsensumon** : la propono transiras al `status='expired'`. Neniu kooptado. Necesas aŭ rekomenci novan proponon, aŭ konsideri ke la reto ankoraŭ ne pretas akcepti tiun personon.

## 8.4. Kolektiva forigo per unanimo

La **kolektiva forigo** estas la spegulo de la kooptado : por forigi ret-administrant-in-on kontraŭ ria volo, necesas la unanimo de la aliaj aktiv-antaj administrant-in-oj.

### Laborflujo

1. **Propono de forigo** de aktiv-anta ret-administrant-in-o, deviga motivo ≥ 20 signoj.
2. **Voĉdooj** de la aliaj administrant-in-oj (favorable / opposed / abstain), kun pravigoj se `opposed`.
3. **Se unanimo `favorable`** : la membreco de la celata persono transiras al `pending_removal`, kun `pending_collective_removal_until = now() + 7 tagoj`.
4. **Dum la 7 tagoj de karenco** : la celata persono konservas siajn operaciajn rajtojn, sed ricevas klaran retmesaĝon pri sia planita eliro. Ri eventuale povas engaĝiĝi en lastan diskuton. **Ri ne povas unuflanka nuligi la forigon** : nur la unanimo de la aliaj administrant-in-oj povas iri reen (proponante « nuligon de forigo », spegula laborflujo).
5. **Je T+7** : transiro al `status='removed'`, `removed_at=now()`.

### Politike

La **duobla riglilo** (unanimo + 7-taga karenco) igas la kolektivan forigon de ret-administrant-in-o aparte malfacila. Tio estas volonta. Ĉar la potenco de ret-administrant-in-o estas transversa, oni ne revokos ĝin malserioze.

Inverse, **la mem-forigo restas ĉiam ebla kaj facila** (cf. §8.5). Jen la politika malregulaĵo : estas simple foriri, estas malfacile esti elpelita. Tio respondas al la anarkiisma kulturo : oni respektas la personan decidon foriri de funkcio, oni forte enkadrumas la kolektivan decidon forigi ĝin.

## 8.5. Mem-forigo

Ret-administrant-in-o povas forlasi siajn funkciojn iam ajn, sen la interkonsento de la aliaj. Temas pri **unuflanka kaj senkondiĉa** ago (P3 aplikata sur la reto-nivelo).

### Proceduro

El `/rede/administradores`, sur sia propra linio, klaki **« Forlasi miajn funkciojn de ret-administrant-in-o »**. Konfirma modalo, nedeviga kialo.

### Efiko

- La linio transiras al `status='inactive'` (aŭ `removed` laŭ la kunteksto, por klarigi en paketo D).
- Retmesaĝo al ĉiuj aliaj aktiv-antaj administrant-in-oj.
- Aŭdit-ŝtuparo `event_type='self_removal_requested'`.

### Speciala kazo : la unusola aktiv-anta administrant-in-o

Se vi estas la **nur**-a aktiv-anta administrant-in-o kaj vi volas foriri, la SIGB ekigas **specialan karencon de 30 tagoj**. Dum tiu periodo :
- Vi restas aktiv-anta administrant-in-o kun ĉiuj viaj rajtoj.
- Urĝa retmesaĝo estas sendita al ĉiuj antaŭaj administrant-in-oj (`status='inactive'` aŭ `removed`) sciigante pri la situacio.
- La reto havas 30 tagojn aŭ rekoopti nov-an administrant-in-on (normala kooptada laborflujo, vi estante la unusola voĉdont-in-o), aŭ organizi malsaman transiron.

Je T+30, se nenio estis farita, vi efektive eliras kaj la reto trovos sin **sen aktiv-anta administrant-in-o**. La SIGB daŭros teknike funkciadi, sed neniu administrant-in-a ago (biblioteka aktivigo, kooptado, ktp.) estos plu ebla ĝis mana interveno.

Tiu proceduro estas desegnita por **malrapidigi** la dissolviĝon de la reto se la lasta administrant-in-o forirus, sen tamen **malhelpi** tiun foririn. La libereco foriri restas plena.

## 8.6. La transversa rajto en ĉiutaga vivo

La **transversa rajto** estas tio kio politike distingas la ret-administrant-in-on de la loka stabo : ri povas agi kiel `coord+` en ajna biblioteko, legi ĝian katalogon (eĉ se videbleco estas `private`), modifi ĝiajn membrecojn, ktp.

### Kiam uzi ĝin

- **Aktivigo de nova biblioteko** : normala laborflujo, tio estas la ĉefa uzkazo de la transversa rajto.
- **Prizorgado** : biblioteko havas rompitan agordon, malĝustan parametron, blokigan cimon. Vi povas interveni por korekti.
- **Politika blokiĝo** : la biblioteko ne plu havas koordinant-in-on (cf. §7.5), necesas rekoopti por rekomenci.
- **Perizado laŭ peto** : la loka koordinado eksplicite petas vin helpi arbitracii konflikton aŭ preni malfacilan decidon.
- **Esplorado post reta signalo** : legant-in-o signalas gravan problemon en biblioteko, kaj la loka koordinado ne respondas aŭ estas mem parto de la problemo.

### Kiam ne uzi ĝin

- **Pro scivolemo** : ne iri « vidi kio okazas » en biblioteko sen operacia kialo. Tio estas spionado, ne administrado.
- **Por trudi politikan decidon** : se vi malkonsentas kun la politiko de biblioteko (validumad-reĝimo, regularo, ktp.), vi povas diskuti pri ĝi, sed ne trudi ĝin.
- **Por ŝtopi kolektivan debaton** : se la reto diskutas evoluon kaj vi malkonsentas, vi ne povas uzi vian transversan rajton por trudi vian vidpunkton per farita fakto.

### Deviga antaŭa informado

Jen la doktrino de la reto (ĉapitro 2, §2.4 ; ĉapitro 7, §7.6) : **ĉia interveno de ret-administrant-in-o en loka biblioteko devas esti antaŭita de informo al la loka koordinado**, krom okaze de vitala urĝeco.

Konkrete :
- **Retmesaĝo al la loka koordinado** klariganta kio estos farata kaj kial.
- **Atendo de respondo** krom urĝeco : 24 ĝis 72 horoj laŭ la naturo de la ago.
- **Se neniu respondo kaj la ago ne estas urĝa** : reveni foje, kaj procedi eksplicite notante en la ŝtuparo ke la loka koordinado estis informita sed ne respondis.
- **Se vitala urĝeco** : agi, kaj tuj poste sendi la informon klarigante kial la urĝeco pravigas la agon sen atendo.

Ĉiu ago estas spurita en `cross_library_actions_log` kun kritikeco-nivelo, legebla de la loka koordinado aposteriore.

## 8.7. La kazo de la unua administrant-in-o kaj de Xavier

La sistemo supozas almenaŭ unu aktiv-antan ret-administrant-in-on por ke la kooptado estu ebla. La **unuan administrant-in-on** ne povas koopti (neniu ekzistas por voĉdoni), do esceptaĵo estas previzita.

La 11-an de majo 2026, **Xavier** estas registrita kiel **fondint-anta ret-administrant-in-o** per rekta INSERT en `network_administrators`, kun `coopted_by_unanimity_of = ARRAY[]::uuid[]` (malplena tabelo) kaj `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. Tiu manipulado estas spurita en la aŭdit-ŝtuparo kun `event_type='foundational_admin_added'` kaj `metadata.foundational=true`.

Tiu manipulado estas **politike travidebla** : ĝi estas dokumentita, klarigita, kaj publika. Ĝi ne estas malforteco de la sistemo — ĝi estas la neevitebla ekfunkciigo. Post kiam tiu fundamento estas farita, ĉia posta kooptado trairas la normalan laborflujon de §8.3.

Laŭmezure ke novaj administrant-in-oj estos kooptataj, la komenca « soleco » malaperos. La reto havas celon havi **plurajn aktiv-antajn administrant-in-ojn** (la politika celo estas ĝenerale cirklo de 3 ĝis 5 personoj, en nepara nombro por eviti blokiĝojn okaze de voĉdono pri iaj ligitaj temoj ekster la specifo).

## 8.8. Se la regulo vin ĝenas

**Vi trovAs la unanimon tro postulema** (« oni neniam sukcesas koopti, unu veto blokas ĉion »). Temas pri funda debato pri la naturo de la kolektivo de ret-administrant-in-oj. Ĉu mildigi al kvalifikita plimulto ? Ĉu havi mekanismon de supervoĉdono ? Al retdiskuto, kaj eventuale formalizi en revizio de la specifo.

**Vi trovAs la unanimon tro laksisma** (« oni devus ankaŭ konsulti lokajn koordinant-in-ojn antaŭ koopti administrant-in-on »). Tio estas alia politika elekto : konsulti lokajn koordinant-in-ojn antaŭ la kooptado de ret-administrant-in-o. Al diskuto. Tio plilarĝigus la decidantan cirklon sed pezigus la proceduron.

**Vi trovAs la 7-tagan karencon por kolektiva forigo tro longa aŭ tro mallonga.** Al la specifo.

**Vi trovAs ke la doktrino de antaŭa informado estas nesufiĉe kadrumita** : kio ekzakte estas « vitala urĝeco » ? Ĉu bezonas difino kanonikan ? Al diskuto.

**Vi trovAs ke la funkcio de ret-administrant-in-o havas tro da potenco** (transversa rajto tro ampleksa) aŭ ne sufiĉe (devus povi tranĉi iujn konfliktojn). Temas pri fundamenta politika demando. Al diskuto en la ĉiujara renkontiĝo.

Vidu ĉapitron 4 kaj anekson C.

\newpage

# 9. Travidebleco en praktiko

Tiu ĉi ĉapitro traktas la konkretan funkciadon de la **travidebleco** en AnarBib : kiu vidas kion, kiel, kaj kial. Temas pri la apliko de principo P5 (maksimuma travidebleco) kaj P6 (sistemaj sciigoj).

## 9.1. La principo

> **P5 — Maksimuma travidebleco.** La aŭdit-ŝtuparo de rolo-ŝanĝoj estas legebla de ĉiu aktiv-anta stabo de la biblioteko.
> **P6 — Sistemaj sciigoj.** Ĉia rolo-ŝanĝo ekigas retmesaĝon al la koncernata persono kaj al ĉiu koordinant-in-o.

La politika ideo : **fari maltravideblan manipuladon neebla**. Se ĉio estas spurita kaj legebla, oni ne povas silente transdoni personon de unu statuso al alia sen ke tio estu vidita de la aliaj stab-membroj.

## 9.2. Kiu vidas kion : matrico

### Sur la nivelo de biblioteko

| Informo | reader | librarian | coordenador | ret-administrant-in-o |
|---|---|---|---|---|
| Listo de la teamo (aktivaj roloj) | parta (nur la publikaj nomoj) | kompleta | kompleta | kompleta |
| Statusoj (`suspended`, `pending_removal`) | ne | jes | jes | jes |
| Kompleta aŭdit-ŝtuparo de la teamo | ne | jes | jes | jes |
| Aŭdit-ŝtuparo : kialoj de agoj | ne | jes | jes | jes |
| Kuranta forigpeto : kiu petis | ne | jes | jes | jes |
| Personaj datumoj de aliaj legant-in-oj | ne | jes (de tiu biblioteko) | jes | jes |

### Sur la nivelo de la reto

| Informo | reader | biblioteka stabo | ret-administrant-in-o |
|---|---|---|---|
| Listo de aktiv-antaj ret-administrant-in-oj | jes (publika paĝo `/rede`) | jes | jes |
| Retaj nombroj (kvanto de bibliotekoj, ktp.) | jes | jes | jes |
| Reta aŭdit-ŝtuparo (kooptadoj, forigoj de administrant-in-oj) | ne | ne | jes |
| Kurante kooptadaj proponoj | ne | ne | jes |
| Trans-bibliotekai registroj (agoj de ret-administrant-in-o en biblioteko X) | ne | jes (de sia biblioteko) | jes |

## 9.3. La teama aŭdit-ŝtuparo en praktiko

Tio estas la plej grava travideblec-ilo. Ĝi estas konsultebla el `/biblioteca` → langeto **Teamo** → sekcio **Historia de la teamo**.

### Kion oni vidas

Ĉiu enskribo montras :
- Dato kaj horo.
- Ago (« promociit-a librarian », « mem-retrogradita », « peto pri forigo », « suspendit-a », « reintegrit-a post suspendo », « aŭtomata transiro al neaktiva post 9 monatoj », ktp.).
- Koncernata persono (celo).
- Aŭtor-in-o de la ago (aktoro) — por homaj agoj. Malplena por aŭtomataj agoj (cron).
- Kialo (se enigita).
- Rolo kaj statusoj antaŭe/poste.

### Por kio ĝi politike utilas

- **Kolektiva memoro** : oni povas rekonstrui la historion de la koordinado, vidi kiel ĝi estis konsistigita kaj evoluis.
- **Gardilo kontraŭ maltravebleco** : se koordinant-in-o faris dubiajn agojn (strangaj kooptadoj, nepravigataj suspendoj), tio estas videbla de ĉiuj.
- **Deliber-ilo** : okaze de debato (« ni diris ke ni rotacigos la koordinant-in-ojn ! »), la ŝtuparo donas faktojn.
- **Transira ilo** : kiam nov-a koordinant-in-o alvenus, ri povas legi la ŝtuparojn por kompreni la lastatempan historion sen devi demandi ĉiujn.

### Kion fari per ĝi

- **Legi ĝin regule**. Ne ĉiutage, sed unufoje monate, dum koordinada kunveno ekzemple.
- **Diskuti kio estas stranga**. Se ago ŝajnas al vi nekompreneblA aŭ nepravigita, demandu al ĝia aŭtor-in-o.
- **Ne uzi ĝin kiel armilon**. La ŝtuparo estas kolektiva travideblec-ilo, ne interpersona gvatada instrumento.

## 9.4. La sciig-retmesaĝoj

Ĉia administrada ago ekigas **unu aŭ plurajn** aŭtomatajn retmesaĝojn. Tio ne estas spamo : tio estas volonta, ĉar neniu devas esti trafita de rolo-ŝanĝo sen esti informita pri ĝi.

### Kiu ricevas kion

| Evento | Koncernata persono | Aktivaj lokaj koordinant-in-oj | Ret-administrant-in-oj |
|---|---|---|---|
| Kooptado (T1, T2) | ✅ | ✅ | — |
| Mem-retrogradiĝo (T3, T4) | ✅ konfirmo | ✅ | — |
| Forigpeto (T5) | ✅ | ✅ | — |
| Nuligo de peto (T8) | ✅ | ✅ | — |
| Fino de karenco (J+7) | ✅ | ✅ | — |
| Suspendo (T6) | ✅ urĝe | ✅ | — |
| Fino de suspendo (T7) | ✅ | ✅ | — |
| Aŭtomata eliro ĉe 9 monatoj (T9) | ✅ memorigoj + fina | ✅ (nur fina) | — |
| La lasta koordinant-in-o foriras | ✅ | ✅ (la koncernita) | ✅ alarmo |
| Ret-administrant-in-a kooptado (propono) | — | — | ✅ |
| Ret-administrant-in-a kooptado (sukceso) | ✅ bonveno | — | ✅ resumo |
| Ret-administrant-in-a kooptado (malakcepto) | ✅ kun pravigo | — | ✅ |
| Kolektiva forigo de ret-administrant-in-o | ✅ | — | ✅ |
| Trans-biblioteka interveno | — | ✅ (koordinant-in-oj de la biblioteko) | ✅ (la aŭtor-in-o) |

### La tono de la retmesaĝoj

La administradaj retmesaĝoj sekvas la militajn konvenciojn de la reto (cf. interna memoro) : sobrieco, klareco, alirebleco (komuna lingvo sen jargono), inkluziva formulado kaj desacralizita skribmaniero. Neniaj oficialaj formuloj, neniaj burokratiaj subskriboj.

Tipa ekzemplo por forigpeto :
> Salut Karl,
>
> La koordinado de la BLMF petis vian fortigon el la teamo (rolo : librarian), pro : « AG-decido de la 04/05 ».
>
> Tiu antaŭaverto efikos la **12-an de majo 2026** (post 7 tagoj), krom se ĝi estas nuligita de alia koordinant-in-o antaŭ tiam.
>
> Dum tiu periodo, vi ne plu havas aliron al librarian-funkcioj. Por ajna diskuto, turnu vin al la koordinado de la BLMF — tiu decido apartenas al la organika vivo de la loka kolektivo kaj ne administriĝas per la SIGB.
>
> AnarBib

La tono celas fakte informi sen dramatizado nek minimumigo.

### Konfidenceco de retmesaĝoj — gardilo kontraŭ spurado

La administradaj retmesaĝoj, kiel ĉiuj sciigoj de la SIGB, estas senditaj per **Resend**, la send-subkontraktisto de la reto (cf. traktad-registro kaj DPA). Du politikaj garantioj encadruemas tiun sendon :

- **Neniu spurado.** La spurado de malfermaĵoj kaj klakoj — kiu kolektus la IP-adreson, la lokadon, la aparaton kaj la retmesaĝ-klienton de la ricevanta persono — estas opcio **malŝaltita** sur la AnarBib-instanco. Ricevi administradan retmesaĝon ne lasas teknikan postsignon flanke de la reto.
- **Minimumigo.** Nur la strikte necesaj datumoj por sendi transiras (retmesaĝ-adreso, antaŭnomo por personigo, enhavo de la sciigo). Neniu sentiva datumoj estas transdonata.

Tiu gardilo estas doktrina : ĝi etendas la ne-spurad-engaĝiĝon de la reto ĝis la retmesaĝ-tavolo. Ĝi estas dokumentita en la traktad-registro (art. 30 de RGPD) kaj en la DPA ; ĉia ŝanĝo de retmesaĝ-subkontraktisto estas sciigata al aliĝintaj bibliotekoj (DPA art. 5.4).

## 9.5. La kazo de « trans-bibliotekai » sciigoj

Kiam ret-administrant-in-o intervenas en biblioteko (cf. §8.6), du sciigoj estas produktataj :

- **Antaŭa sciigo** (mana) : la administrant-in-o sendas retmesaĝon al la loka koordinado antaŭ agi. Libera formato.
- **Aŭtomata sciigo** (per la SIGB) : dum la plenumado de la ago, la sistemo skribas en `cross_library_actions_log` kun kritikeco-nivelo, kaj sendas retmesaĝon al la aktivaj koordinant-in-oj de la koncernata biblioteko.

Tiu duobla sciigo (mana + aŭtomata) garantias ke la loka koordinado estas avertita **antaŭe** politike kaj **poste** teknike. La teknika postsigno estas legebla aposteriore en la langeto **Teamo** → sekcio **Retaj intervenoj** (venonta en paketo D).

## 9.6. Limoj de la travidebleco

La travidebleco de AnarBib havas limojn, kiujn necesas ekspliciti :

**La `reader`-oj ne vidas la aŭdit-ŝtuparojn de la teamo.** Tio estas volonta (P5 parolas pri « aktiva stabo »). La `reader`-oj ne vidas kiu kooptis kiun, kiu estis suspendit-a, ktp. La travidebleco funkcias **inter la koordinant-in-oj**, ne al la uzant-in-oj.

**Biblioteko ne vidas la aŭdit-ŝtuparojn de alia biblioteko.** Loka suvereneco (P7). Rolo-ŝanĝoj en biblioteko A estas strikte maltravidebaj por biblioteko B, krom per la homa kanalo (diskuto inter koordinant-in-oj de la du bibliotekoj).

**La reta aŭdit-ŝtuparo (kooptadoj kaj forigoj de administrant-in-oj) ne estas publika.** Legebla nur de ret-administrant-in-oj. Loka biblioteko povas vidi la liston de nunaj ret-administrant-in-oj (paĝo `/rede`), sed ne la historian de kooptadoj nek la pravigojn de kontraŭaj voĉoj.

Tiuj limoj ne estas hipokritaĵoj. Ili respondas al ekvilibro inter **travidebleco** (ene de la deliberanta stabo) kaj **konfidenceco** (al uzant-in-oj kaj inter perimetroj). Se vi trovAs la ekvilibron malĝuste situita, tio estas amendebla (ĉapitro 4).

## 9.7. Se la regulo vin ĝenas

**Vi pensAs ke la `reader`-oj devus vidi la aŭdit-ŝtuparojn de la teamo** (radikala travidebleco al uzant-in-oj). Tio estas defendebla pozicio, sed havas sekvaĵojn (la internaj konfliktoj fariĝas publikaj, la politika vivo de la kolektivo ekspoziĝas). Al diskuto en la reto.

**Vi pensAs inverse ke la aŭdit-ŝtuparo estas tro videbla** (diskreta librarian-in-o ne devus povi « spioni » la agojn de koordinant-in-oj). Tio ankaŭ estas defendebla. Sed ĝi kontraŭdiras P5. Al diskuto.

**Vi trovAs la retmesaĝojn tro multaj aŭ ne sufiĉe klaraj.** La enhavo estas paramétrita en `mail-strings.ts` × 10 lokaĵoj. Ĉia modifi de retmesaĝo estas amendebla kiel koda modifi. Al la programist-in-oj.

**Vi pensAs ke la reta aŭdit-ŝtuparo devus esti publika almenaŭ al lokaj koordinant-in-oj** (por ke ilin povu vidi kiu decidas kion sur la reta nivelo). Tio estas interesa opcio. Al diskuto.

Vidu ĉapitron 4 kaj anekson C.

\newpage

# 10. Konkretaj komentitaj kazoj

Por fini, ses kompletaj scenaroj. Ĉiu ilustras kombinaĵon de mekanismoj kaj ebligas vidi la SIGB en ago. La nomoj (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) estas tiuj de la historiaj kamaradoj de la libertema penso ; ili servas ĉi tie kiel fikciaj tipaj kazoj.

## 10.1. Voltairine estas kooptita librarian

> **Kunteksto.** Emma estas koordinant-in-o en la BLMF. Voltairine venas ekde ok monatoj al la permanencoj, partoprenas la vivon de la biblio, kaj havas klare la profilon por eniri la teamon. La loka kolektivo diskutis tion en AG la 4an de majo kaj akceptis rian kooptadon.

**Proceduro.**

1. Emma konektiĝas la 5an de majo je la 14h30. Iras al `/biblioteca`, langeto **Equipe**.
2. Serĉas Voltairine en la listo de `reader` de la biblio (ri havas konton AnarBib ekde februaro).
3. Klakas **« Inviter dans l'équipe »** → elektas **librarian**.
4. Kampo « Raison » : « décision AG du 04/05 » (doktrino 1, strikta atendo).
5. Konfirmas.

**Tuja efekto.**

- Voltairine ricevas retpoŝton : « Saluton Voltairine, vi estis nomita librarian de la BLMF de Emma G. laŭ : "décision AG du 04/05". Viaj novaj rajtoj estas aktivaj. Bonvenon en la teamon. »
- La aliaj aktivaj koordinant-in-oj de la BLMF (Lucy kaj Piotr) ricevas informan retpoŝton.
- Revizia protokolo : `2026-05-05 14:30 — Emma G. a promu Voltairine d.C. librarian (raison: décision AG du 04/05)`.

**Komento.**

Plej simpla kazo. La SIGB plenumas prave la decidon de la kolektivo. Emma nenion decidis politike — ri klakis por plenumi tion, kio estis decidita ekster la programaro.

**Kion la SIGB ne faris :** kontroli ke la AG vere okazis, ke la decido vere estis prenita, ke Voltairine vere konsentas. Tiuj aferoj estas **ekster la programaro**. Se Emma estus mensoginta pri la AG, la SIGB nenion vidus. La politika kulturo de la BLMF estas tio, kio malhelpas tiun menson (kaj la protokolo igas ĝin a posteriori spurebla).

## 10.2. Lucy transdonas la rolon

> **Kunteksto.** Lucy estas koordinant-in-o en la BLMF, sed ri ne plu povas plenumi la ŝarĝon ĉi tiun semestron (ri komencas tezon). Ri volas « repreni librarian-rolon » por resti en la teamo sed malpezigi siajn respondecojn.

**Proceduro.**

1. Lucy iras al `/biblioteca`, langeto **Equipe**.
2. En sia propra linio (statuso `coordenador`), klakas **« Je passe la main »**.
3. Elekto : « repreni librarian-rolon ».
4. Konfirmmodalo memorigas ke ri tuj perdos la koordinad-permesojn.
5. Lucy konfirmas. Nedeviga kialo : « démarrage thèse, allègement temporaire ».

**Tuja efekto.**

- Ria membership `coordenador` ŝanĝiĝas al `inactive`.
- Ria membership `librarian` (kiu ekzistis paralele) restas `active`.
- Lucy ricevas konfirman retpoŝton : « Vi estas nun librarian de la BLMF. Vi konservas viajn operaciajn permesojn. »
- La tuta koordinado (Emma, Piotr) ricevas retpoŝton : « Lucy P. transdonis la rolon, ne plu estas koordinant-in-o. Ri restas librarian de la teamo. »
- Revizia protokolo : `2026-05-05 18:42 — Lucy P. a auto-rétrogradé coordenador → librarian (raison: démarrage thèse, allègement temporaire)`.

**Komento.**

Ĉi tio estas la ekzempla uzo de la rajto P3. Lucy ne devis peti permeson de iu ajn. Ria mem-malaltigo estas tuja. Ri daŭre kontribuas al la biblio, sed laŭ intenseco adaptita al sia nuna disponeblo.

**Politike** : tio estas ĝuste la tipo de rotacio kiun ni volas favorigi. Ni ne perdas Lucy, ri simple prenas alian rolon. Post ses monatoj aŭ jaro, se ri volas repreni la koordinadon, la kolektivo povos rekoopti rin (T2). Neniu decido estas definitiva.

## 10.3. Karl devas foriri

> **Kunteksto.** Karl estas librarian en la BLMF. Lia konduto kun certaj legant-in-oj kaŭzis problemon (paternalismo, malkonvenaj rimarkigoj). La kolektivo diskutis tion en AG la 4an de majo kaj decidis ke li devas forlasi la teamon.

**Proceduro.**

1. Piotr (koordinant-o) — elektita de la AG por plenumi la decidon — iras al `/biblioteca`, langeto **Equipe**.
2. En la linio de Karl, klakas **« Demander le retrait »**.
3. Ruĝa modalo kun eksplicita 7-taga prokrasto.
4. Deviga kialo : « Suite à AG du 04/05, comportement inadéquat avec plusieurs lecteur·rices signalé sur plusieurs mois, décision collective d'exclusion. »
5. Eksplicita konfirmo : « Mi komprenas ke ĉi tiu peto efektiviĝos la 12an de majo 2026 krom se anulita de alia koordinant-o. »

**Tuja efekto.**

- La membership de Karl ŝanĝiĝas al `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl tuj perdas aliron** al ĉiuj librarian-funkcioj (la membership estas frostigita).
- Karl ricevas retpoŝton :
  > « Saluton Karl, la koordinado de la BLMF petis vian forigon el la teamo (rolo: librarian), laŭ: "Suite à AG du 04/05, comportement inadéquat avec plusieurs lecteur·rices signalé sur plusieurs mois, décision collective d'exclusion." Ĉi tiu antaŭavizo efektiviĝos la 12an de majo 2026 (post 7 tagoj), krom se anulita de alia koordinant-o antaŭ tiam. Por ia diskuto, turnu vin al la koordinado de la BLMF. »
- Emma kaj Lucy (aliaj koordinant-in-oj) ricevas la informan retpoŝton.
- Revizia protokolo : `2026-05-05 — Piotr K. a demandé le retrait de Karl M. (rôle: librarian, raison: ...)`.

**Evoluo.**

- La 6an de majo je la 9h : Lucy legas la retpoŝton. Ri konsentas kun la decido kaj ne intervenas.
- La 7an de majo : Emma interŝanĝas kun Karl (kiu skribas al ri por klarigi sin). Emma konkludas ke la decido estas valida. Ne intervenas.
- La 8-11an de majo : nenio.
- **La 12an de majo je la 00h00** : la cron `cron_team_pending_removal_complete` plenumas. Karl ŝanĝiĝas al `inactive`.
- Fina retpoŝto al Karl + al la koordinado.
- Revizia protokolo : `2026-05-12 — passage automatique en inactif (raison: pending_removal expiré, cron) — actor: NULL`.

**Komento.**

Ĉi tio estas la kazo de kolektiva ekskludo. Tri politikaj elementoj por noti :

- **La karencio funkciis kiel ebla gardostopo**, sen esti uzata. Lucy kaj Emma povus estis anulintaj ; ili ne faris tion. La fakto ke neniu anulas estas mem **implica deliberado**.
- **Karl restis informita** sen surprizo. Neniu silenta ekskludo.
- **La revizia protokolo estas legebla** de la tuta stabo kaj permesas reveni al ĉi tiu decido se poste iu demandas kial Karl foriris.

**Politike delikata** : la kialo skribita en la kampo « Raison » estas legebla de la tuta stabo. Ĝi ne devus enhavi detalojn pri la viktimoj (RGPD, digno), sed devus esti sufiĉe klara por ke la decido estu politike defendebla. Trovi la ĝustan dozon estas kompetento de koordinant-in-o.

## 10.4. Kompromitita konto : tuja suspenso

> **Kunteksto.** La 5an de majo je la 19h30, Emma rimarkas en la agadaj protokoloj ke Friedrich (librarian) efektivigis 47 modifojn de katalogfiŝoj en 3 minutoj, el kiuj pluraj estas aberrantaj (libroj markitaj kiel « malaperintaj » kvankam ili estas sur la bretaro, ktp.). La padrono similas al neaŭtorizita aliro.

**Proceduro.**

1. Emma iras al `/biblioteca`, langeto **Equipe**.
2. En la linio de Friedrich, klakas **« Suspendre »**.
3. Modalo kun **deviga** kialo (≥ 20 signoj).
4. Emma tajpas : « Suspicion compte compromis, activité anormale (47 modifs catalogue en 3 min), vérification en cours. »
5. Konfirmas.

**Tuja efekto (19h32).**

- Friedrich ŝanĝiĝas al `status='suspended'`.
- **Neniu aliro** por Friedrich.
- Friedrich ricevas urĝan retpoŝton : « Via konto AnarBib estis suspendita konservative en la BLMF. Kialo: suspekto de kompromitado de via konto. Ni forte sugestas al vi **tuj ŝanĝi vian pasvorton**. Post kiam via konto estos sekurigita, kontaktu la koordinadon de la BLMF por ke la suspenso estu levita. »
- La koordinado (Lucy, Piotr) ricevas retpoŝton.
- Revizia protokolo : `2026-05-05 19:32 — Emma G. a suspendu Friedrich E. (rôle: librarian, raison: ...)`.

**Evoluo.**

- **19h35** : Emma telefonas al Friedrich (kanalo ekster-SIGB). Friedrich konfirmas ke li ne faris tiujn agojn. Li estis lasinta sian komputilon malferma en komuna spaco.
- **19h40** : Friedrich ŝanĝas sian pasvorton per la restartigproceduro.
- **20h00** : Emma kontrolas la suspektindajn agojn en la revizioprotokolo de la biblio (la kataloga revizio, ne la teama revizio). Identigas la 47 modifojn. Anulas ilin mane aŭ petas rulimalon de ret-administrant-in-o se necese.
- **20h15** : Emma revenas al la langeto Equipe, levas la suspenson de Friedrich.
- Friedrich ricevas konfirman retpoŝton. Revizia protokolo : `2026-05-05 20:15 — Emma G. a levé la suspension de Friedrich E.`.

**Komento.**

Tipa kazo kie la suspenso estas uzata kiel **konservativa mezuro**, ne kiel ekskludo. Friedrich ne kulpas — lia konto estis kompromitita. La suspenso daŭris 43 minutojn, la tempon por sekurigi.

**Politike grave** : Friedrich ne estis « akuzita ». La retpoŝto tion klare precizas (« à titre conservatoire »). Kiam la situacio estas solvita, la suspenso estas levita, kaj la epizodo estas spurita en la protokolo kiel incidento, ne kiel riproĉo.

## 10.5. Errico estas la lasta koordinant-o kaj volas foriri

> **Kunteksto.** La BLMF havas nur unu aktivan koordinant-in-on, Errico. Lucy transdonis la rolon, Emma translokiĝis kaj ne plu estas aktiva. Piotr mem-malaltis sin komence de la jaro. Errico devas foriri (translokiĝo eksterlanden, ne plu havas tempon).

**Proceduro.**

1. Errico iras al `/biblioteca`, langeto **Equipe**, klakas **« Je passe la main »**.
2. **Speciala** modalo malfermiĝas :
   > ⚠️ **ATENTO** : vi estas la sola aktiva koordinant-in-o de la BLMF. La biblio restos sen koordinado. La ret-administrant-in-oj de AnarBib estos sciigitaj. La BLMF povos daŭre funkcii (la librarian-oj restas operacivaj) sed neniu konfiguracioŝanĝo estos ebla ĝis la kooptado de nova koordinant-in-o. Daŭrigi ?
3. Errico konfirmas. Kialo : « Déménagement à l'étranger, plus de disponibilité pour la coordination. »

**Tuja efekto.**

- La koordinant-o-membership de Errico ŝanĝiĝas al `inactive`.
- Retpoŝto al Errico (konfirmo).
- Retpoŝto al la tuta koordinado de la BLMF — sed ĝi ne plu ekzistas, do en praktiko la aktivaj `librarian`-oj restantaj ricevas sciigon.
- **Urĝa retpoŝto al la ret-administrant-in-oj** : « La BLMF ne havas plu aktivan koordinant-in-on. Jen la aktivaj librarian-oj restantaj : Voltairine d.C., Friedrich E., ... »
- Revizia protokolo : `2026-05-05 — Errico M. a auto-rétrogradé coordenador → reader (raison: ..., warning: last_coordinator_leaving)`.

**Evoluo ekster-la-programara.**

- La 6an de majo : Xavier (ret-administrant-o) kontaktas Voltairine kaj Friedrich, la aktivajn `librarian`-ojn restantajn. Ili konfirmas ke la kolektivo BLMF daŭre ekzistas, kaj ke ili volas daŭrigi.
- La 7-15an de majo : interna diskuto de la kolektivo BLMF, kiu en AG decidas koopti Voltairine al la rolo de koordinant-in-o.
- La 16an de majo : Xavier (aŭ alia koordinant-in-o BLMF kiu ne ekzistas plu en ĉi tiu okazo, do Xavier per sia transversa rajto) kooptas Voltairine kiel koordinant-in-o. **Deviga antaŭa informado** : Xavier skribis al Friedrich kaj Voltairine 2 tagojn antaŭe por anonci la agon. Post kiam ĝi estas farita, la ago estas spurita en `cross_library_actions_log` kun kritikeco-nivelo « alta » (koordinadoŝanĝo de biblio de ret-administrant-o).

**Komento.**

Politike delikata kazo : la biblio trairas fragecan periodon (inter la 5a kaj la 16a de majo, ĝi havas neniun koordinadon). Sed la SIGB **ne malhelpis** la foriradon de Errico — ria rajto P3 estas senkondiĉa. La SIGB simple **alarmis la reton** por ke ĝi povu helpi.

La interveno de Xavier ilustras la **ĝustan** uzon de la transversa rajto : ri estis petita (implicite, per la aŭtomata alarmo), ri respektis la antaŭan informadon, ri spuris sian agon. Ri ne trudis Voltairine ; la kolektivo BLMF elektis rin. Xavier simple **teknikiste plenumis** la decidon.

## 10.6. Kooptado de ret-administrant-o kiu fiaske finiĝas

> **Kunteksto.** Xavier estas fondinta ret-administrant-o. Kun la tempo, Maria, Patricia kaj Diego estis kooptitaj kiel ret-administrant-in-oj laŭmezure kiam la reto etendiĝis. La 20an de majo 2026, la kolektivo de administrant-in-oj estas : Xavier, Maria, Patricia, Diego (kvar aktivaj administrant-in-oj).
>
> Maria proponas la kooptadon de Mohammed, kiun ri konas en itala biblio kiu aliĝas al la reto.

**Proceduro.**

1. Maria, de `/rede/administradores`, klakas **« Proposer une cooptation »**.
2. Enigas la identecon de Mohammed (konto AnarBib kreita du semajnojn pli frue).
3. Motivado : « Mohammed koordinas la BLA (Bologna), bibliotekon kiu aliĝas al la reto ĉi-monate. Ri portis la politikan integriĝon de la BLA en AnarBib kaj estas tre implikita en la itala koordinado. Ria kooptado kiel ret-administrant-o fortigos la geografian diversecon de la kolektivo kaj faciligos la animadon flanke Italio. »
4. Konfirmas.

**Tuja efekto.**

- Propono kreita, `status='open'`, `expires_at = 19 juin 2026`.
- Aŭtomata `favorable` voĉdono de Maria registrita.
- Retpoŝtoj al Xavier, Patricia, Diego kun la propono.

**Evoluo.**

- La 22an de majo : **Diego** voĉdotas `favorable`. Neniu racio (nedeviga por favora).
- La 25an de majo : **Patricia** voĉdotas `opposed`. Racio : « Mohammed havas neniun longecon en la reto. Lia kooptado iras pli rapide ol tiu de la BLA, kiu ankoraŭ ne havis la okazon funkcii kiel biblio AnarBib dum sufiĉe da tempo. Mi proponas atendi 6 monatojn por ke la BLA establiĝu, tiam reproponii Mohammed en tiu momento. » Patricia markas « Révéler mon identité ».

**Tuja efekto de la opposed-voĉdono.**

- Propono ŝanĝiĝas al `status='rejected'`.
- Retpoŝto al Mohammed : « Bonjour Mohammed, ta proposition de cooptation comme admin réseau d'AnarBib n'a pas abouti. Patricia X. a soulevé l'objection suivante: "[rationale complète]". Tu peux échanger avec elle ou avec Maria, qui t'avait proposé·e. La cooptation pourra être reproposée ultérieurement. »
- Retpoŝto al Maria (proponint-o) : resumo kun la racio de Patricia.
- Retpoŝto al Xavier kaj Diego : informo ke la propono estas rifuzita, kun la racio.
- Reta revizia protokolo : `2026-05-25 — cooptation rejetée: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Komento.**

Ilustra kazo de la unanimeco **en ago**. Patricia havas vetoon, ri uzas ĝin, ria racio estas eksplicita kaj konstruiva (« atendu 6 monatojn »). Ri elektis malkaŝi sian identecon, kio permesas al Mohammed kaj Maria diskuti kun ri rekte anstataŭ spekulativi pri la anonima kontraŭul-in-o.

**Politike** : la unanimeca kooptado ne estas garantio de permanenta blokado. Patricia ne diras « neniam » sed « ne nun ». Se post 6 monatoj la BLA estas bone integrita kaj Patricia ŝanĝas opinion, nova propono povos sukcesi. Estas ĉi tiu **reversibleco en la tempo** kiu igas la unanimecon tolereblaj.

La alternativo — koopti Mohammed per plimulto kontraŭ la opinio de Patricia — estus kreinta cirklon de administrant-in-oj kie Patricia sentus sin en malkomforta pozicio. Pli bone atendi.

\newpage

# Aldoneoj

\newpage

# Aldoneo A — Glosaro

**AG** — Assemblée générale (Ĝenerala Kunveno). Kolektiva kunveno de decidprendo de biblio. La SIGB ne modeligas la AG (P8). Ĝia modaleco (kvorumo, ofteco, deliberadmaniero) estas tute decidita de ĉiu biblio.

**Revizia protokolo** — Ĵurnalo de regadaj agoj, stokita en `library_membership_audit` (ĉe biblionivelaj) kaj `network_administrator_audit` (ĉe retonivelo). Legebla de la aktiva stabo (ĉe biblionivelaj) kaj de la ret-administrant-in-oj (ĉe retonivelo).

**Mem-malaltigo** — Ago per kiu stab-membro sin mem malaltgas al malpli alta rolo. Rajto P3, senkondiĉa.

**Biblio `private`** — Biblio kies katalogo estas videbla nur de riaj aliĝintaj membroj. Reĝimo taŭga por politike eksponataj bibliotekoj.

**Biblio `network`** — Biblio kies katalogo estas videbla de ĉiuj `reader` validitaj en la reto AnarBib. Defaŭlta reĝimo por la plimulto de bibliotekoj.

**Biblio `public`** — Biblio kies katalogo estas videbla de ĉiuj, inkluzive anonimajn vizitant-in-ojn.

**Karencio** — Prokrasto trudita inter decido kaj ĝia efekto. Sep tagoj por kolektivaj forigoj de loka stabo kaj de ret-administrant-o. Tridek tagoj por la mem-foriro de la sola aktiva ret-administrant-in-o.

**Kooptado** — Mekanismo de eniro en teamon (loka stabo) aŭ en la kolektivon de ret-administrant-in-oj. Por la loka stabo : decido de koordinant-in-o aŭ supera. Por la reto : unanimeco de la aktivaj administrant-in-oj.

**Transversa** — Kvalifikas agon efektivigitan de ret-administrant-in-o en biblio de kiu ri ne estas loka stab-membro. Spurita en `cross_library_actions_log`.

**Cron** — Aŭtomata tasko plenumita periode de la SIGB. Sen homa agant-in-o. Ekzemploj : `cron_team_pending_removal_complete` (transiro de `pending_removal` al `inactive` ĉe J+7), `cron_team_inactive_cleanup` (aŭtomata eliro ĉe 9 monatoj).

**Delegado** — Ago per kiu kolektivo provizore konfidas funkcion al iu el siaj membroj, konservante la eblecon repreni ĝin. Centra koncepto, distingita de « hierarkio ».

**Membership** — Linio de la tabelo `user_library_memberships` kiu esprimas la apartenadon de persono al biblio en donita rolo. Persono povas havi plurajn membership-ojn en biblio (plur-membership).

**Plur-membership** — Ebleco havi plurajn membership-liniojn por sama persono en sama biblio, kun malsamaj roloj.

**Reto** — La kolektivo de bibliotekoj kiuj reciproke rekonas unu la alian kaj dividas la platformon AnarBib. Ne centra organizo, sed federacio.

**RPC** — *Remote Procedure Call*. SQL-funkcio vokita de la uzant-in-a interfaco por plenumi agon. Ĉiuj regadagoj pasas tra RPC-oj nomitaj `fn_team_*` (loka stabo) aŭ `fn_network_admin_*` (reto).

**Loka suvereneco** — Principo P7 laŭ kiu ĉiu biblio estas suverena sur siaj internaj delegadoj. Rolŝanĝoj en biblio nenion influas en alia.

**Spec** — Specifikadokumento (`spec-*.md`) kiu detale priskribas la funkciadan de funkciaĵo de la SIGB. Teknika kaj politika fonto de vero. Versiigita, datita, amendingebla.

**Unanimeco** — Modaleco de kooptado kaj kolektiva forigo de ret-administrant-in-oj. Ĉiuj voĉdonoj devas esti `favorable` ; unu sola `opposed` aŭ nelevia sindeteno blokas.

**Fizika validado** — Proceduro per kiu librarian aŭ superulo validas `reader`-konton post fizika renkontiĝo. Validas por la tuta reto (pakto de reciproka rekono).

**Veto** — Voĉdono `opposed` dum kooptado aŭ kolektiva forigo de ret-administrant-in-o. Tuja efekto : malakcepto de la propono. Deviga racio de almenaŭ 20 signoj.

\newpage

# Aldoneo B — Indekso de teknikaj funkcioj

Ĉi tiu aldoneo donas, por ĉiu RPC menciita en la gvidilo, ĝian politikan tradukon kaj la koncernan transiron. Ĝi servas kiel rapida referenco.

## Funkcioj de loka stabo

| RPC SQL | Transiro | Politika traduko |
|---|---|---|
| `fn_team_promote_to_librarian` | T1 | Kooptado `reader` → `librarian` |
| `fn_team_promote_to_coordenador` | T2 | Kooptado `librarian` → `coordenador` |
| `fn_team_self_demote` | T3, T4 | Mem-malaltigo (« mi transdonas la rolon ») |
| `fn_team_request_remove_member` | T5 | Forigo-peto kun 7-taga karencio |
| `fn_team_cancel_remove_member` | T8 | Nuligo de forigo-peto |
| `fn_team_suspend_member` | T6 | Tuja suspenso (konservativa mezuro) |
| `fn_team_unsuspend_member` | T7 | Suspenslevigo |
| `fn_validate_physical_account` | — | Fizika validado de `reader` |
| `cron_team_pending_removal_complete` | T5 (daŭrigo) | Cron : transiro al `inactive` ĉe J+7 |
| `cron_team_inactive_cleanup` | T9 | Cron : aŭtomata eliro ĉe 9 monatoj |

## Funkcioj de ret-administrant-o

| RPC SQL | Etapo | Politika traduko |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Kooptado : propono | Administrant-in-o proponas novan |
| `fn_network_admin_vote_cooptation` | Kooptado : voĉdono | Voĉdono favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Mem-foriro | Forlasi siajn funkciojn de ret-administrant-o |
| `fn_network_admin_request_removal` | Kolektiva forigo | Spegula laborflumo de la kooptado |

## Rajtigo-helpiloj (uzataj de la RLS-oj)

| SQL-helpilo | Politika senco |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | Ĉu ĉi tiu persono povas agi kiel stabo en ĉi tiu biblio ? (aktiva loka stabo AŬ ret-administrant-o) |
| `user_can_engage_library(library_id)` | Ĉu ĉi tiu persono povas politike impliki ĉi tiun bibliotekon ? (aktiva loka koordinant-in-o AŬ ret-administrant-o) |
| `fn_caller_is_network_admin()` | Ĉu la vokantin-o estas aktiva ret-administrant-in-o ? |
| `fn_library_visible_to_caller(library_id)` | Ĉu la katalogo de ĉi tiu biblio estas videbla por la vokantin-o ? |

## Ĉefaj tabeloj

| Tabelo | Politika senco |
|---|---|
| `user_library_memberships` | La lokaj delegadoj (kiu estas stabo de kiu biblio) |
| `network_administrators` | La administrant-in-oj de la reto |
| `library_membership_audit` | Ĵurnalo de lokaj regadagoj |
| `network_administrator_audit` | Ĵurnalo de rettnivelaj regadagoj |
| `network_administrator_cooptation_proposals` | Aktualaj kooptado-proponoj |
| `network_administrator_cooptation_votes` | Individuaj voĉdonoj de administrant-in-oj |
| `cross_library_actions_log` | Spuro de agoj de ret-administrant-in-oj en bibliotekoj |

\newpage

# Aldoneo C — Modelo de amendinota

Kiam vi volas proponi amendon al regulo de la SIGB aŭ al ĉi tiu gvidilo, jen modelo de noto por strukturigi vian proponon. Libera formato, vi povas adapti ĝin.

---

## Propono pri amendo al [nomo de la spec aŭ de la gvidilo]

**Aŭtor-in-o(j) :** [viaj antaŭnomoj / pseŭdonimoj]
**Dato :** [JJ/MM/JJJJ]
**Amplekso :** [loka biblio / reto / fundamentoj]

### 1. Koncerna regulo

Citi laŭvorte la regulon aŭ la alineon por amendi, kun sia referenco en la fontspecifilo.

> *Ekzemplo :* « `spec-gouvernance-roles.md`, §5.6, T5 : La karencia prokrasto antaŭ efektiva ekskludo estas 7 tagoj. »

### 2. Identigita problemo

Priskribi en kelkaj frazoj kio estas problematika en la nuna regulo. Se eble kun konkretan kazon renkontitan.

> *Ekzemplo :* « En praktiko, 7 tagoj estas tro mallonga kiam la sekva AG de la biblio okazas post 15 tagoj. Forigo-decido farita impetege foje ne havas tempon esti kolektive diskutita antaŭ la aŭtomata efekto. »

### 3. Proponita amendo

Priskribi la dezirata modifon, kiel eble kun formulado preta integri en la specifon.

> *Ekzemplo :* « Ŝanĝi la karencian prokraston de 7 al 14 tagoj, AŬ fari la prokraston agordebla laŭ biblio (inter 7 kaj 30 tagoj), kun defaŭlta valoro je 14 tagoj. »

### 4. Antaŭvidataj teknikaj konsekvencoj

Se vi havas ideon pri tio kion ĝi implicus flanke kodo, diri tion. Se ne, ankaŭ diri tion (« mi ne scias, vidu kun la programist-in-oj »).

> *Ekzemplo :* « Modifi la malmolan valoron en la SQL-kodo de `fn_team_request_remove_member` kaj `cron_team_pending_removal_complete`. Se agordebla laŭ biblio, aldoni kolumnon al `libraries`. »

### 5. Antaŭvidataj politikaj konsekvencoj

Priskribi kio ŝanĝiĝas en la kolektiva praktiko, kaj la eventualajn kromefikojn.

> *Ekzemplo :* « Pli da tempo por deliberado, sed ankaŭ pli da tempo dum kiu la persono en `pending_removal` restas suspendata (sen aliro). Povas esti perceptata kiel pli peza. »

### 6. Konsideritaj alternativoj

Mencii la aliajn pistojn pri kiuj vi pensis, kaj kial vi malakordiĝas (aŭ ne).

> *Ekzemplo :* « Alternativo : lasi la prokraston je 7 tagoj sed permesi « eksplicitan plilongigon » de alia koordinant-in-o. Pli kompleksa por efektivigi kaj kompreni. Pli bone modifi la defaŭlton. »

### 7. Dezirata diskuto

Kie kaj kiel vi volas ke la propono estu diskutita ?

> *Ekzemplo :* « Diskuto sur la kanalo Matrix `#anarbib`, tiam se konsensas, integro en la specifon dum la sekva regado-pako. »

---

Post redaktado, cirkuligi la noton laŭ la amplekso (vd. ĉapitro 4, §4.2).

\newpage

# Aldoneo D — Fontspecifoj kaj referencoj

Ĉi tiu gvidilo apogiĝas sur la sekvaj dokumentoj, konsulteblaj en la deponejo de la projekto :

## Ĉefaj specifoj

**`spec-gouvernance-roles.md`** — Fondanta specifo de la regado de lokaj stab-roloj. Versio 1.0 de la 5a de majo 2026. 1231 linioj. Detaligas la 4 rolojn, la 5 statusojn, la 9 transirojn, la revizian protokolon, la sciigojn, la UI, kaj 15 referenc-uzkazojn.

**`spec-administrateur-reseau.md`** — Apartigado inter loka stabo kaj ret-administrant-o. Versio 0.3 de la 11a de majo 2026. 975 linioj. Detaligas la tabelon `network_administrators`, la kooptadon per unanimeco, la kolektivan forigon, la transversan rajton, la semantikon de la « paĝo = amplekso » nombriloj.

**`spec-validation-physique.md`** — Akceptmanieroj de legant-in-a konto (`open` kontraŭ `manual_validation`). Kadrigita la 3an de majo 2026. Detaligas la statojn de la konto, la DB-skemon, la laborflumojn.

**`spec-refactor-v3-semantique.md`** — Refaktoigo de la semantiko de la rezervada laborflumo. Ne centra por la regado sed citita en marĝeno pro la kohereco de la SIGB-ansamble.

## Parencaj specifoj menciitaj (por redakti aŭ en kurso)

- `spec-migration-compte.md` — Migrado de konto el unu biblio al alia. 940 linioj, kadrigita la 3an de majo 2026.
- `spec-invitation-equipe.md` — Invita laborflumo per retpoŝto por personoj sen konto AnarBib. Por redakti.
- `spec-fermeture-biblio.md` — Proceduro de pura fermado de biblio. Por redakti.
- `spec-mediation-conflits.md` — Formalizita kadro de mediaciado kaj enketo laŭ signalado. Por redakti (proponita de la nuna gvidilo).

## Por pli sciigi

La specifoj kaj la fontkodo estas sur la Codeberg-deponejo de la projekto, kun GitHub-spegulo. La teknika kaj politika diskuto okazas sur la kanalo Matrix `#anarbib` de la reto.

Por ia propono pri amendo al ĉi tiu gvidilo aŭ al la specifoj, vd. ĉapitro 4 kaj aldoneo C.

---

*Fino de la gvidilo. Versio 1.0, 11a de majo 2026.*

*Ĉi tiu gvidilo estas mem amendingebla. Se vi trovas ke ĝi diras malĝuste, ke ĝi forgesis kazon, aŭ ke ĝi prenas pozicion kiu ne plu konformas al la doktrino de la reto, diru tion.*

