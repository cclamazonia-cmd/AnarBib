# AnarBib — Manual de utilizare
## Rețea de biblioteci libertare

*Versiunea 1.1 — septembrie 2026*

---

## 1. Primii pași

### Conectarea
Mergi la URL-ul instanței tale AnarBib și dă clic pe **Entrar** (sau pe butonul de conectare în limba interfeței tale). Introdu e-mailul și parola.

### Schimbarea limbii
Selectorul de limbă se află în dreapta sus pe fiecare pagină (🇧🇷🇵🇹 / 🇫🇷 / 🇪🇸 / 🇬🇧 / 🇮🇹 / 🇩🇪 / 🇳🇱 / 🇬🇷 / Català / Esperanto). Alegerea este salvată local.

### Căutarea în catalog
În **Catalog** apare câte un rând pentru fiecare operă, în limba interfeței tale atunci când titlul a fost tradus: autorul/autoarea, titlul, numărul de ediții și bibliotecile care o dețin.
1. Dă clic pe **Vezi edițiile** („+”-ul de pe rând): fiecare ediție apare dedesubt, cu miniatura, editura și anul ei. Tomurile unei opere în mai multe volume sunt numerotate și ordonate.
2. Dă clic pe **Exemplare pe bibliotecă**: disponibilitatea se afișează bibliotecă cu bibliotecă. Dacă te-ai conectat, „biblioteca ta” este semnalată; ce e disponibil în altă parte, dar nu și pentru tine, e spus ca atare.
3. Butonul **Listă simplă** revine la un rând pentru fiecare ediție; alegerea este memorată.

---

## 2. Cititor/cititoare — Contul meu

### Rezervarea unui document
1. Caută documentul în **Catalog**
2. Dă clic pe fișa lui
3. Dacă documentul este disponibil, dă clic pe **Rezervă un împrumut**
4. Poți să mergi și în fila **Rezervări** din contul tău și să introduci referința locală

### Urmărirea împrumuturilor
Fila **Împrumuturi în curs** îți afișează împrumuturile active, cu:
- Data ieșirii și termenul de returnare
- Un buton **Prelungește** (dacă prelungirea este permisă)
- Indicarea unei eventuale întârzieri

### Prelungirea unui împrumut
Dă clic pe **Prelungește** în lista împrumuturilor tale. Prelungirea poate fi refuzată dacă:
- Împrumutul a fost deja prelungit o dată
- Împrumutul este în întârziere
- Altă persoană care citește a rezervat același document

### Banda de stare a contului
În partea de sus a paginii **Contul meu**, o bandă colorată arată starea contului tău:
- ✓ **Verde**: Cont activ, totul e în regulă
- ⚠ **Portocaliu**: Atenție (împrumut în întârziere, parolă de schimbat)
- ⛔ **Roșu**: Cont restricționat (contactează biblioteca ta)

### Istoric
Fila **Istoric** listează rezervările și împrumuturile tale anterioare. Poți da clic pe titlu ca să vezi fișa documentului, iar cu **Ascunde** scoți din vedere intrările pe care nu mai vrei să le vezi.

### Protejează-ți contul: autentificarea în doi pași
După parolă, AnarBib îți poate cere un cod de șase cifre care se schimbă la fiecare 30 de secunde. Codul vine de la o aplicație de autentificare liberă, care funcționează offline: Aegis sau FreeOTP+ pe Android, FreeOTP sau 2FAS pe iPhone, KeePassXC pe calculator. Fără SMS, fără serviciu extern.

**Obligatorie pentru echipe începând cu 1 ianuarie 2027** (administrarea rețelei, echipele de coordonare, bibliotecari/bibliotecare); opțională pentru conturile persoanelor care citesc.

Ca s-o activezi:
1. Deschide **Contul meu → Date personale**. Sub schimbarea parolei, dă clic pe **Activează autentificarea în doi pași**.
2. Dă un nume dispozitivului (de exemplu „Telefon”), apoi scanează codul QR cu aplicația. Fără cameră, introdu manual cheia afișată.
3. Introdu **codul de șase cifre** afișat de aplicație și dă clic pe **Confirmă**.

De acum înainte, la fiecare conectare, AnarBib îți cere codul după parolă. Dacă ai înregistrat mai multe dispozitive, alege-l pe cel pe care îl ai la îndemână.

- **Înregistrează un al doilea dispozitiv** (de exemplu KeePassXC pe lângă telefon): e singurul mod de a nu rămâne fără acces dacă pierzi unul.
- **Ți-ai pierdut dispozitivul?** Contactează administrarea rețelei (Matrix sau anarbib@proton.me). După ce îți verifică identitatea pe altă cale, îți elimină dispozitivele; înregistrezi unul nou la următoarea conectare.
- Ca să elimini un dispozitiv, dă clic pe **Elimină** lângă numele lui.
- Un cont de echipă fără dispozitiv după 1 ianuarie 2027 va trebui să înregistreze unul la conectare înainte de a continua.
- Nimeni de la AnarBib nu îți va cere vreodată codul sau codul QR.

---

## 3. Bibliotecar/bibliotecară — Panou

### Lucrul zilei
Panoul generează automat sarcinile prioritare:
- Ridicare programată azi
- Rezervări noi de tratat
- Rezervări pregătite pentru ridicare
- Împrumuturi în întârziere
- Returnări prevăzute azi
- Consultări pe loc de tratat

### Gestionarea rezervărilor
Fila **Rezervări** permite:
- Selectarea mai multor rezervări (casete de bifat)
- Aplicarea unei etape în lot (pregătire, programarea ridicării, confirmare)
- Anularea rezervărilor

### Gestionarea împrumuturilor
- **Crearea unui împrumut**: introducerea ID-ului sau a e-mailului persoanei care citește + referințele locale
- **Returnare totală**: introducerea ID-ului împrumutului
- **Returnare parțială**: introducerea ID-urilor exemplarelor individuale
- **Împrumuturi grupate**: vedere sintetică pe împrumut

### Gestionarea unei persoane care citește
Fila **Gestionează cititorul/cititoarea** permite:
- Căutarea după ID public, e-mail sau nume
- Modificarea profilului (nume, e-mail, telefon, gen, adresă)
- **Restricționează accesul** (cu motiv: nereturnare etc.)
- **Ridică restricția**

---

## 4. Catalogare

### Crearea unei fișe de document
1. Mergi la **Catalogare** > fila **Document**
2. Selectează **tipul de material** (Carte, Periodic, Manifest, Audio etc.)
3. Completează câmpurile (modul Simplu arată esențialul, modul Complet toate câmpurile)
4. Folosește **Caută metadate** ca să precompletezi prin ISBN
5. **Salvează ciorna**

### Operă, ediții și tomuri
O operă reunește toate edițiile aceluiași text. În fișa unui document, blocul **Operă** îți permite:
- **Asociază cu altă operă**: caută opera după titlu, apoi **Asociază**. Opera părăsită dispare dacă rămâne goală.
- **Titluri pe limbă**: câte un titlu pentru fiecare limbă a interfeței. Titlurile marcate „traducere automată — corectează-mă” au fost propuse de mașină: recitește-le și dă clic pe **Salvează** ca să le confirmi.
- **Titlu uniform**: titlul de referință al operei, scris în limba originală a operei înseși, nu în cea a unei traduceri.
- **Tom / volum**: numărul tomului atunci când opera are mai multe volume. Tomurile rămân într-o singură operă.

### Asistent de deduplicare: opere scindate și volume
În **Asistent de deduplicare** (Catalogare), două file completează duplicatele de fișe:
- **Opere scindate**: două opere care par să fie același text. **Unește în „…”** le reunește; **Păstrează separate** memorează decizia, iar perechea nu mai revine.
- **Volume**: fișe care par să fie tomurile aceleiași opere. Bifează **Reunește această fișă** pentru fiecare tom reținut, introdu-i numărul, apoi validează; un grup rezolvat nu mai revine.

Nicio fuziune și niciun număr de tom nu sunt puse de mașină: fiecare gest îți aparține.

### Tipuri de documente și câmpuri specializate
Fiecare tip de document afișează câmpuri adaptate:
- **Periodic**: volum, număr, fascicul, periodicitate, ISSN
- **Manifest**: campanie, organizație emitentă, dată aproximativă, format fizic
- **Audio**: durată, suport, format tehnic, participanți/participante
- **Audiovizual**: durată, regie, subtitrări
- **Resursă digitală**: URL, condiție de acces, restricție
- **Dosar**: acoperire, perioadă, organizații, context politic

### Traducerea biografiilor autorilor/autoarelor
În fila **Autor/autoare**, când editezi o fișă de autor/autoare publicată:
1. Deschide panoul **Traducerile biografiei**
2. Introdu biografia în fiecare limbă dorită
3. Dă clic pe **Salvează traducerile**

### Imprimarea etichetelor
În fila **Indexare**, sub formularul de exemplar:
1. Filtrează și selectează exemplarele
2. Dă clic pe **Imprimă etichetele (X)**
3. Se deschide un document A4 cu 21 de etichete pe pagină (7×3)

---

## 5. Administrare

### Gestionarea bibliotecii
Pagina **Gestionarea bibliotecii** permite configurarea:
- Identității (nume, oraș, contact)
- Comunicărilor (e-mailuri, moduri de trimitere, tipuri de notificare)
- Regulamentului (încărcare PDF, reguli de circulație)
- Echipei, schimburilor între biblioteci, rapoartelor

### Gestionarea rețelei
Pagina **Rețea** (accesibilă coordonatorilor/coordonatoarelor și administratorilor/administratoarelor) permite:
- Consultarea privirii de ansamblu (statistici globale)
- Gestionarea cererilor bibliotecilor
- Administrarea membrilor rețelei
- Promovarea administratorilor/administratoarelor

### Autentificarea în doi pași a echipelor
Fila **Autentificare în doi pași** a paginii **Rețea**, rezervată administrării rețelei, listează conturile de echipă active și pe cele care au ales autentificarea în doi pași, cu rolurile lor și numărul lor de dispozitive; cele fără dispozitiv apar primele. Arată și cerința în vigoare.

Ca să ajuți o persoană care și-a pierdut dispozitivul: verifică mai întâi identitatea ei pe altă cale (față în față, Matrix), apoi dă clic pe **Elimină-i dispozitivele**, indică motivul (cum a fost verificată identitatea) și dă clic pe **Elimină și deconectează**. Contul este deconectat peste tot, iar eliminarea este înregistrată în jurnal. Gestul acesta cere ca propria ta sesiune să fi trecut prin cod.

---

## 6. Limbi disponibile

Interfața este disponibilă în 10 limbi:
- 🇧🇷🇵🇹 Português (limba de referință)
- 🇫🇷 Français
- 🇪🇸 Castellano
- 🇬🇧 English
- 🇮🇹 Italiano
- 🇩🇪 Deutsch
- 🇳🇱 Nederlands
- 🇬🇷 Ελληνικά
- Català
- Esperanto

Biografiile autorilor/autoarelor pot fi traduse independent în fiecare limbă.

Titlurile operelor sunt pretraduse automat în cele zece limbi; poartă mențiunea „corectează-mă” până când le recitește o persoană.

---

*AnarBib — Rețea de biblioteci libertare*
*Software liber pentru gestionarea cooperativă a cunoașterii militante*
