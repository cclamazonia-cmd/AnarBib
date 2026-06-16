# Kadriĝo — Kunhelpado en katalogado (langeto « Kunhelpado » de la Federacio)

**Dato** : 2026-06-15
**Statuso** : **kadriĝo / projekto** — esplora reflekto kiu starigas la *vizion*,
la *arkitekturon* kaj la *principajn decidojn*. **Ĝi ankoraŭ ne estas spec por konstrui** : por diskuto, eprovo, poste detaligado en specoj.
**Etika bazo** : [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
(« la etendita mano »). **Ĉiu ekrano sube estis pasigita tra la krado « ĉu ĝi etendiĝas aŭ kaptas ? ».** Ĉi tiu kadriĝo estas, en certa senco, la unua konkreta provo de la ĉarto.

---

## 1. La bezono

Katalogado estas la dolorpunkto de komencant-in-aj bibliotekoj (cf. la laborchantieroj de aŭtoritato, subjekto-indeksado, malkovra gvid-sorĉisto). Sola biblioteko antaŭ la aŭtoritatoj, subjektoj, klasifiko estas timigata. La langeto « Kunhelpado » respondas al ĉi tiu preciza bezono — sed la anarkiisma katalogado ne estas neŭtrala : la ĉefaj subjektaj titoloj patologiziĝas, forviŝiĝas, mis-nomiĝas. **La kunhelpado transdonas *politikan metion* kiun nek normoj nek IA enkodigas.**

Transversa principo : **la helpoalvoko estas ĝenerika** (kunhelpado pri *ĉia* teknika malfacila afero), la **katalogado estas la unua kabloligita domajno**.

## 2. Tri gradoj de kunhelpado — skalo, per subsidieco

Ne « unu AŬ la alia » sed tri *intensoj* ; la helpoalvoko estas la pivoto, la respondo prenas unu el la tri formoj, de la plej malpeza al la plej peza :

1. **La scio-komuno** (vademekumoj, kazoj, tezaŭro) — nula kosto, nula dependeco, 100 % inter egaluloj. La daŭra bazo.
2. **Miniaj gvid-sorĉistoj** — gvidas la bibliotekon por ke ĝi faru *mem* (aŭtonomiganta, ne dependiganta).
3. **Rekta homa helpo** (alvoko → respondo → eventuala videokonferenco) — la plej rilata, por kiam la komuno kaj la gvid-sorĉisto ne sufiĉas.

**La descendanta banto** : malfacila kazo solvita je grado 3 → resumo → iĝas kaz/gvid-sorĉisto de grado 1-2 → la venontan fojon, la gvid-sorĉisto sufiĉas. *La scio descendas la gradojn kun la tempo ; la reto iĝas pli inteligenta kaj pli memstara ĉe ĉiu epizodo.*

## 3. La scio-komuno — la tavolo de aŭtonomio

Tri tavoloj, kaj la plej profunda estas **la vortaro mem** :

- **La tezaŭro, politika kerno.** Ne vorto-listo : *koncepta grafo*. La politiko vivas en la **termoj**, la **rilatoj** (broader/narrower/related) kaj la **apliko-notoj** (kiuj estas mikro-vademekumoj). Konstrui sur **SKOS** (libera normo) — lasos normon, ne brikolaĵon. Semo ekzistas (tezaŭro ~30 kategorioj).
- **Kazoj & vademekumoj** — laboritaj ekzemploj, redaktablaj, aperantaj *ĉe la bezono-punkto*.
- **Gvid-sorĉistoj en *datoj*, ne en *kodo*** — *la aŭtonomia veto* : se gvid-sorĉisto estas kodo, oni dependas de programistoj por ĉiam ; se ĝi estas **strukturita dokumento** (arbo de demandokartoj → fino-kartoj) kiun motoro unu-foje-skribita malvolvas, **ĉia biblioteko skribas unu sen kodi**. Gardiloj por ke ĝi ne fariĝu kaŝita prog-lingvo : neniaj variabloj/kalkulo/libera kondiĉo ; nura stato = trapasita vojo ; eventuaj kondiĉoj el fermita listo ; **la gvid-sorĉisto *konsilas*, neniam *skribas*** (plej malbona fiasko = « ne utila », neniam « rompis la katalogon ») ; malgrandaj unutemaj gvid-sorĉistoj.

**Plurlingve sen IA** : la i18n-ŝelo (10 lokaĵoj) portas la interfacon ; la *substanco* (termoj, kazoj) skribiĝas **per lingvo-komunumo** (paralela transversa skribo, ne descendanta traduko) — malrapide sed daŭre kaj senkosta. **Regado** : aldono/modifo de termino per la **konsento/objekdo**-fluo de la rondoj ; politika kursoro « admisitaj variantoj vs konverĝo » metota de la reto.

## 4. La ekigo — ĉe la bezono-punkto (ĉarto ③)

**La ekigilo estas la *kampo*, la *dato*, aŭ la *peto* — neniam la observado de la persono.** Forbanu kondutajn signalojn (« 5 minutoj sur la kampo », hezitoj) : tio estas Clippy *kaj* laboro-observado. Tri honestaj ekigiloj :
- **kampo-intrina** (subjektoj/aŭtoritato estas malfacilaj *por ĉiuj* → helpo ĉiam tie) ;
- **derivita el la dato** (neniu ISBN, ambigua aŭtor-in-o → la libro signalas, ne la persono) ;
- **eksplicita peto** (trankvila « helpon », ĉiam atingebla).

La helpo supreniras **la skalon unu-klak-plu-longe** (enlinia → gvid-sorĉisto → rondo), **diskreta sed malkovrebla** (fidebla loko, neniam modala/gamifikata), kun **domajnkurba ĉeesto** (iom pli alloga se kampo malplena + malgranda nombro de rikordo ; malaperadas kun majstrado ; ĉiam faldebla permane).

## 5. Du ekranoj jam pasigitaj tra la krado

### 5.1 — La « ? » sub malfacila kampo (katalogado)
Ĉeesta *ĉar la kampo estas malfacila por ĉiuj* (digneca enkadriĝo, ne « vi ŝajnas havi malfacilecon »). Malfermante ĝin : enliniaj tezaŭro-sugestoj + komunaj kazoj → « guidita vojo » (gvid-sorĉisto) → « petu la rondon » (grado 3, konsento-momento).
**La krado mortigis du tentajn funkciojn** : ❌ detekti la hezitadon por proponi helpon (observado, faceto ③) ; ❌ insignoj/vicoj/strio al « eksperto » (faceto ⑥).
**Retenita defaŭltoj** : reto « unuafoje ? guidita vojo » *propononita sed en propona registaro* ; « ? » ĉiam videbla, sugestoj **malfermitaj ĉe klako** (diskreta + malkovrebla).

### 5.2 — La epizodo-fermo + kapturado de la komuno
Fino **iniciata de la helpato** (neniu aŭto-fermo, neniu fermo de la helpant-in-o). Sobra « dankon »-ekrano, **nenio alkroĉita** (sendebta malligado). Simetria « resti en kontakto ? »-etaĝo, ignorigebla, kreis nenion krom duobla-jes.
**Komunkapturado sen ŝuldo** : oni invitas la **helpant-in-on** (posedas la novan scion), ne la helpaton ; **mikrokontribuo alkroĉita al la objekto** (noto pri termino/kampo), **ekigita de la spurado** de la epizodo ; poste la **helpato estas invitata relegi/riĉigi** (« kio estis vere malfacila ») — *ria voĉo, rifuzebla, neniam juĝo de la helpant-in-o*, kaj **ne-blokanta** (la noto tenas sola).
**La krado mortigis** : ❌ « taksu vian sperton » (kaŝita rangigo) ; ❌ komplet-insigon.

## 6. Konfidenceco

La katalogo-dato estas *malpli* sentema ol la legant-in-o-dato (metadatumoj pri *libroj*, neniam ekzempleroj/pruntoj/identecoj), **sed ne nula** (la fondusoj de anar-biblioteko povas esti politike sentemaj ; cf. la distingo `visibility_level='network'` / BTL). Do :
- **opt-in laŭ ero** (neniam dump), **BTL/sentemaj ekskluzivitaj defaŭlte** ;
- **la helpant-in-o *proponas*, la posedant-in-o *validigas*** — neniam rekta skribo de tria ; aliro **limigita, revokebla, revidiita** ;
- la grado **« petu la rondon » ESTAS la konsento-momento** (« vi montros ĉi tiujn erojn al la biblioteko X — jen kio eliras ») ;
- **la komuno kaptas *ĝenerikan senpersoniĝintan metion*, ne *identigantajn kazojn*** ; la specifaĵoj estas forigitaj aŭ konsentitaj.

Respondo al la demando « absoluta rajto delegi ? » : **jes al aŭtonomio, sed *klara kaj kadrigita* konsento, ne blanka ĉeko** — fari la riskon malgranda kaj ekkonsciiĝi pri ĝi.

## 7. Akordado & maturiĝo en partnereco

- **Mola ordiĝo, ne malmola filtrado.** En disflorita reto, KAJ (sama lingvo KAJ geo KAJ disponeco KAJ eksperto) = malplena aro. Oni **ordigas** laŭ afineco (lingvo ↑, fushoraro ↑, volontul-in-o ↑) sen **ekskludi** ; subsidieco **rondo-unue → reto se silento**. La **relevantan rondon determinas la helptipo** (katalogado → lingvistika ; materialo/represado → geografia).
- **Unua gesto sen antaŭkondiĉo** : sin volontuli por *unu* akto postulas neniun rondon nek profilon. **Aparteno akumulas de gestoj** (konsenta rekono, neniam etikedo).
- **Kontraŭhierarkio** : neniu individua reputacio, neniu merkato ; deklarita disponeco, videbla reciprokeco sen poentoj, rotacio.
- **Maturiĝo en partnereco (§21)** — *dua fazo kiu dissolvas la malabundon* : bona epizodo povas **maturiĝi** en partnereco → estonta helpo estas *antaŭakordita* (lingvo, fushoraro, konsento jam donita) ; la reto **densigadas**. **Malligita** de la epizodo (neniam en la momento = ŝuldo) ; **post ripeto** (rekono, ne kreado) ; **simetria duobla-opt-in** ; **profund-skalo** (0 → resti-en-kontakto → gvid-kunvivado → formala partnereco) ; **ŝuldo-inversigo** (la partnereco estas *donaco* al la helpato : « kamarad-in-o kiun oni povas revoki sen re-konsenti », ne ŝuldo) ; ĉiam **kodisolvebla**.

## 8. La videokonferenco-aldono (grado 3)

Kunigi la homan helpon al **Jitsi videokonferenco** (sinkrona = efika transdonado) ; viviero = **lingva rondo**. **Unue asinhrona, videokonferenco kiel optia akcelilo** (la plej malfortika persono havas malbonan konekton → gradoj 0-2 en teksto/senrete).
Teknike, « senpage » : **kodi la integriĝon unufoje per la iframe API kun la `domain` en agordado** → neniam ŝlosita al unu provizanto. Defaŭlte montri al **milita Jitsi-instanco** (plej ene de la doktrino, senkosta, ne GAFAM) ; manke `meet.jit.si` (supozante la aŭtentikon de la ĉambro-kreant-in-o). Ĉambroj **efemeroj, nediveneblaj nomoj, antaŭĉambro**. **Nula servilo, nula sekreto, nula rekura kosto.** La memgastigita restas *parkejo* (VPS malakceptita).

## 9. Kosto & aŭtonomio

Ĉio (komuno, gvid-sorĉistoj, paneloj, akordado, visio-ligilo) **kuras sur la ekzistanta stako** (Supabase + statika fronto) : **nula marĝena kosto, sen IA por funkcii**. IA restas **nedeviga kaj malŝaltebla akcelilo** (nur antaŭ-katalogado de la *neŭtrala* ; la politika restas inter kamarad-in-oj). **La organoj jam ekzistas** : tezaŭra semo, malkovra gvid-sorĉisto, i18n 10 lokaĵoj, konsento/objekdo-fluo de la rondoj, §21 partnereco. **Ĉi tiu kadriĝo ligas ekzistantajn organojn — tial ĝia modesteco, kaj ĝia sendependeco de kosto kaj ĉia ekstera dependeco.**

## 10. Fiksitaj decidoj / malfermitaj demandoj

**Fiksitaj (dum la reflekto) :**
- Tri gradoj en skalo + descendanta scio-banto.
- Komuno = tezaŭro (SKOS, politika kerno) + kazoj + **gvid-sorĉistoj en datoj**.
- Ekigo per kampo/dato/peto, **neniam observado** ; unuklaka skalo ; domajnkurba ĉeesto.
- Ekrano « ? » : defaŭltoj (propono, sugestoj ĉe klako) ; rifuzataj (hezito-detektado, gamifikado).
- Fermo : helpato fermas ; **helpant-in-o redaktas → helpato riĉigas** (nula ŝuldo) ; komuno = **ĝenerika metio** ; regado **additiva = 2 personoj / vortaro = kolektiva**.
- Akordado **mola ordiĝo + rondo-unue** ; rondo **laŭ la helptipo** ; unua gesto sen antaŭkondiĉo ; **aparteno per gesto**.
- Maturiĝo §21 **malligita, post ripeto, duobla-opt-in, profund-skalo, ŝuldo-inversigo, kodisolvebla**.
- Videokonferenco **Jitsi `domain` agordigebla**, asinhrono-unue, nula infrao/sekreto.
- (Retpoŝta memorigo, jam kabloligita ekster ĉi tiu kadriĝo) lokaĵo de la destinanto = **ria persona prefero**.

**Malfermitaj (politikaj kursoro por meti de la reto) :**
- **Nivel-o de komenca akcepto** (gastamo) kaj **kiu metas ĝin** : reto / rondo / biblioteko / persono. Pisto : *demandi* la novalivenint-in-on ĉu ri akceptas (konsento) + subsidieco (la supro nur plenigas la silenton) + opcio *persona patronado* de ronda volontul-in-o.
- Nivelo de **ĉeesto de la resti-strio** kaj de la invito al komuno (propona vs disponebla) — larĝe ĉarmalagita per la **semantiko** (propona registaro ≠ mandato).
- Konkretan formon de **la redaktilo de gvid-sorĉisto-en-datoj** (ĝis kie sen fariĝi kodo).
- Kursoro **variantoj vs konverĝo** de la tezaŭro.

## 11. Statuso

Kadriĝo por **diskuto kaj eprovo**, ne konstruordo. Kiam segmento estos matura, ĝi detaligados en spec, kaj ĉiu ekrano repasiĝos tra la **krado de la rilata ĉarto**.
