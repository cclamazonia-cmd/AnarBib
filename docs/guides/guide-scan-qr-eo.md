# Gvidilo — Skanado kaj QR-kodo en AnarBib

> **Por kiu estas ĉi tiu gvidilo.** Por ĉiu biblioteka kamarad-in-o kiu volas
> uzi la fotilon de sia telefono (aŭ komputilo) por ŝpari tempon: identigi
> legant-in-on per sia membrila karto, trovi datumojn de libro per strikokodo,
> aŭ kontroli la kolekton. Verkita laŭ peto — kaj por la **komuno** de la reto.
>
> **Spirito.** Nenio ĉi tie vin observas nek taksa vin. La deĉifrado de kodoj
> okazas **100 % sur via aparato**: neniu bildo de la fotilo estas sendita
> ien ajn. La iloj estas ĉi tie por doni al vi aŭtonomion, ne por vin kateni.
> Se io ne funkcias, **la katalogo neniam rompiĝas** — en la plej malbona kazo,
> vi simple tajpu permane.
>
> Parto de la **scio-komuno** de la reciproka helpo en katalogado (vidu la
> kadradon « Reciproka helpo en katalogado »). Ĉi tio estas verkita per
> lingva komunumo: se vi volas version en alia lingvo, ĝi estas farata
> paralele, ne de supre malsupren per traduko.

---

## Kion oni povas skani

AnarBib havas **nur unu fotil-legant-ilon**, reuzatan en tri lokoj:

| Kie | Kion oni skanas | Por kio |
|---|---|---|
| **Panelo › Administri legant-in-on** | QR de la **membrila karto** | Tuj identigi la legant-in-on |
| **Katalogado** (libro-firo) | **ISBN-strikokodo** | Aŭtomate alporti titolon/aŭtor-in-on |
| **Panelo › Inventaro** | QR de la **ekzemplaj etikedoj** | Kontroli la kolekton (inventarado) |

En ĉiuj kazoj: la fotilo malfermiĝas ene de AnarBib, legas la kodon, kaj jen.
Ne necesas instali iun ajn aplikaĵon. Se vi volas, vi povas **aldoni AnarBib al
la hejmekrano** de via telefono (menuo de la retumilo › « Aldoni al hejmekrano »):
ĝi malfermiĝas en plena ekrano kiel aplikaĵo, sed restas la retejo.

---

## 1. Membrila karto de legant-in-o

**Kiu kreas la membrilkaron:** la legant-in-o mem, en sia konto
(`/konto`), kiam la biblioteko aktivigis la funkcion. Ri generas QR-kodon kaj
povas elŝuti ĝin kiel PNG aŭ PDF. La QR portas nur **opakan kodon** — neniu
nomo, neniu persona dato en ĝi.

**Kiel vi, ĉe la kontraŭ, uzas ĝin:**

1. Iru al **Panelo › Administri legant-in-on**.
2. Klaku **« Skani la karton »** kaj direktu la fotilon al la QR de la membrilkarto.
3. AnarBib deĉifras la kodon kaj montras **kiu estas** la legant-in-o (kaj ĉu
   ekzistas aktiva restrikto). Preta por prunto, redono, ktp.

> **« Membrila karto ne rekonita »?** Preskaŭ ĉiam temas pri **malnova karto**.
> Kiam la legant-in-o generas novan membrilkaron, la antaŭa estas **revokita**
> (sekureca mezuro). Petu rin generi/elŝuti la nunan karton. Ekde la 15/06, la
> sistemo mem avertas « karto anstataŭigita, generu novan » en tiu kazo.

---

## 2. Skani la ISBN dum katalogado

Kiam oni reĝistras libron kiu havas strikokodo (ISBN), eblas eviti tajpi ĉion
permane:

1. En la libro-firo (katalogado), malfermu la paneleron de **metadatum-serĉado**.
2. Klaku **« Skani la ISBN »** kaj direktu la foton al la **strikokodo** sur la
   malantaŭa kovrilo de la libro.
3. La numero aŭtomate eniras la ISBN-kampon kaj AnarBib **serĉas la datumojn**
   (titolo, aŭtor-in-o…) en publikaj fontoj. Vi reviziu kaj ĝustigu — la
   katalogo estas la via.

> **Konsilo pri aparato.** Strikokodoj estas pli « postulaj » ol QR-kodoj. **La
> telefono kutime legas multe pli bone** ol la retkomputila rettelevidilo (fokuso
> kaj rezolucio de la fotilo). Se la rettelevidilo ne kaptas, ne penu: tajpu la
> ISBN permane — estas la sama afero.

---

## 3. Inventaro de la kolekto

Kontroli, ekzemplon post ekzemplo, kio efektive estas en la bretaro — komparante
kun tio, kion la sistemo kredas ke la biblioteko havas.

**Antaŭe:** la ekzemplaj etikedoj devas havi **QR-kodon**. Presigu la etikedojn
kun QR en **Katalogado › Etikedoj** (estas opcio « Inkluzivi QR-kodojn »). Ĉiu
QR montras al la ekzemplo.

**Farante la inventaron:**

1. Iru al **Panelo › Inventaro** (videbla por *librarian* kaj *kunordigant-in-o*).
2. **« Komenci inventaron »** — malfermas sesion kaj montras kiom da ekzemploj la
   biblioteko havas.
3. La fotilo restas malfermita: **iru transirante la ekzemplojn**, unu QR post la
   alia. Ĉe ĉiu legado aŭdiĝas **bifono** kaj la nombrilisto altiĝas. Ne necesas
   fermi kaj remalfermi la fotilon inter unu libro kaj la alia.
   - ✓ verda = ekzemplo de la kolekto, kalkulita.
   - « Jam legita » = vi jam trairis ĉi tiun (sen problemo, ne estas kalkulita
     dufoje).
   - ⚠ « Ekster la kolekto » = ekzemplo kiu **ne apartenas** al ĉi tiu biblioteko
     (enpenetrintaĵo).
4. Se iu QR estas difektita, eblas **tajpi permane** (URL de la etikedo aŭ la
   numero de la ekzemplo).
5. **« Fini kaj vidi raporton »** — fermas la sesion kaj montras:
   - **Ĉeestantaj** (skanitaj kaj el la kolekto),
   - **Mankantaj** (el la kolekto, sed ne skanitaj → serĉi / registri kiel
     for-ighintaj),
   - **Enpenetrintaĵoj** (skanitaj, sed el alia biblioteko / nekonataj).
6. Eksportu la rezulton kiel **CSV** (por kalkultabelo) aŭ **PDF** (por presi la
   liston de mankantaj kaj iri serĉi en la bretaroj).

> **Paŭzi kaj rekomenci.** Granda inventaro? Vi povas fermi poste. Se vi eliras
> meze, la sesio restas **en progreso** kaj aperas en « Daŭrantaj seancoj » por
> **rekomenci** de kie vi haltis.

---

## Praktikaj demandoj

**Ĉu mi bezonas instali ion?** Ne. Estas la retejo mem. Laŭvole, « Aldoni al
hejmekrano » por malfermi kiel aplikaĵon.

**Ĉu ĝi funkcias en mia retumilo?** Jes. En Chrome/Android ĝi uzas la denaskan
legant-ilon (pli rapida). En **Brave**, **iOS/Safari** kaj **Firefox** AnarBib
aŭtomate ŝarĝas alternativan legant-ilon — do **ankaŭ funkcias** en tiuj. Se
aperas « legado ne kongrua » dum skanado de ISBN en unu el tiuj, refreŝigu la
paĝon: la alternativa legant-ilo eniĝas aŭtomate.

**La fotilo ne malfermiĝas.** Kontrolu ĉu vi donis **permeson por fotilo** al la
retejo (la ŝlosilo en la adresbaro). La retumilo liberigas la fotilon nur sub
**HTTPS** — `app.anarbib.org` jam estas.

**Privateco.** La deĉifrado estas **loka**. La bildo de la fotilo **ne estas
sendita** al iu ajn servilo. La QR de la membrilkarto konservas nur opakan kodon;
la QR de la etikedo konservas nur la adreson de la ekzemplo. Sentemaj fondusoj
(BTL kaj similaj) restas protektitaj per la samaj reguloj kiel ĉiam.

---

## En unu frazo

La fotilo estas **la etendita mano** por ŝpari al vi tajpadon kaj kontroladon —
ne devigo. Uzu ĝin kiam ĝi helpas; ignoru kiam ne. Kaj se ĝi blokiĝas, la
klavaro estas ĉiam tie.

---

*Dokumento de la AnarBib-komuno. Plibonigoj kaj versioj en aliaj lingvoj estas
bonvenaj, verkitaj paralele de la komunumo de ĉiu lingvo.*
