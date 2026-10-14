# Ghid — Scanare și cod QR în AnarBib

> **Cui i se adresează acest ghid.** Oricărui tovarăș/oricărei tovarășe de bibliotecă
> care vrea să folosească camera telefonului (sau a computerului) ca să câștige timp:
> să identifice persoana care citește după cardul ei, să preia datele unei cărți după
> codul de bare sau să verifice fondul. Scris la cerere — și pentru **bunul comun**
> al rețelei.
>
> **Spirit.** Nimic de aici nu te supraveghează și nu te evaluează. Citirea codurilor se face
> **100 % pe dispozitivul tău**: nicio imagine de la cameră nu pleacă de la tine. Aceste
> instrumente sunt aici ca să-ți dea autonomie, nu ca să te înlănțuie. Dacă ceva
> nu funcționează, **catalogul nu se strică niciodată** — în cel mai rău
> caz, e de ajuns să introduci datele de mână.
>
> Parte din **bunul comun al cunoașterii** creat de întrajutorare (vezi documentul-cadru „întrajutorarea
> la catalogare”). Acest ghid este scris de comunitatea lingvistică: dacă vrei o
> versiune în altă limbă, ea se construiește în paralel, nu prin traducere
> de sus în jos.

---

## Ce se poate scana

AnarBib are **un singur cititor prin cameră**, folosit în trei locuri:

| Unde | Ce se scanează | La ce folosește |
|---|---|---|
| **Panou › Gestionează cititorul/cititoarea** | Codul QR al **cardului de cititor** | Identifici persoana pe loc |
| **Catalogare** (fișa cărții) | **codul de bare ISBN** | Preiei automat titlul/autorul/autoarea |
| **Panou › Inventariere** | Codurile QR ale **etichetelor de exemplar** | Verifici fondul (inventariere) |

În toate cazurile: camera se deschide în AnarBib, citește codul și gata. Nu trebuie
să instalezi nicio aplicație. Dacă vrei, poți **adăuga AnarBib pe ecranul de
pornire** al telefonului (meniul browserului › „Adaugă pe ecranul de pornire”): se
deschide pe tot ecranul, ca o aplicație, rămânând totuși site-ul.

---

## 1. Cardul de cititor

**Cine creează cardul:** chiar persoana care citește, din contul ei
(`/conta`), de îndată ce biblioteca a activat funcția. Ea generează
un cod QR și îl poate descărca în PNG sau în PDF. Codul QR conține doar un
**cod opac** — niciun nume, nicio dată personală înăuntru.

**Cum îl folosești, la ghișeu:**

1. Mergi la **Panou › Gestionează cititorul/cititoarea**.
2. Apasă pe **„Scanează cardul”** și îndreaptă camera spre codul QR al cardului.
3. AnarBib descifrează codul și afișează **cine este** persoana (și dacă are o restricție
   activă). Gata de împrumut, de returnarea unei cărți etc.

> **„Card nerecunoscut”?** Aproape întotdeauna e vorba de un **card vechi**.
> Când o persoană generează un card nou, cel anterior este **revocat**
> (măsură de securitate). Cere-i să-și genereze/descarce cardul actual.
> Din 15 iunie, sistemul însuși afișează în acest caz „card înlocuit, generează
> unul nou”.

---

## 2. Scanarea ISBN-ului la catalogare

Când înregistrezi o carte care are cod de bare (ISBN), poți evita să
introduci totul de mână:

1. În fișa cărții (catalogare), deschide panoul de **căutare de
   metadate**.
2. Apasă pe **„Scanează ISBN-ul”** și îndreaptă camera spre **codul de bare** de pe
   coperta a patra.
3. Numărul se completează singur în câmpul ISBN și AnarBib **preia
   datele** (titlu, autor/autoare…) din sursele publice. Tu verifici și
   ajustezi — catalogul este al tău.

> **Sfat despre echipament.** Codul de bare e mai „pretențios” decât codul QR. **Telefonul
> citește de obicei mult mai bine** decât camera web a unui computer de birou
> (focalizare și rezoluție). Dacă camera web nu prinde codul, nu insista: introdu
> ISBN-ul de mână — e totuna.

---

## 3. Inventarierea fondului (verificarea la raft)

Să verifici, exemplar cu exemplar, ce se află cu adevărat pe raft —
comparând cu ce crede sistemul că deține biblioteca.

**Înainte să începi:** etichetele exemplarelor trebuie să aibă un **cod
QR**. Tipărește etichetele cu QR din **Catalogare › Etichete** (este disponibilă o
opțiune „Include codurile QR”). Fiecare cod QR trimite la exemplarul lui.

**Cum decurge inventarierea:**

1. Mergi la **Panou › Inventariere** (vizibil pentru rolurile *librarian* și
   *coordonator/coordonatoare*).
2. **„Pornește o inventariere”** — deschide o sesiune și afișează numărul
   de exemplare pe care le deține biblioteca.
3. Camera rămâne deschisă: **treci exemplarele unul după altul**, cod QR
   după cod QR. La fiecare citire se aude un **bip** și contorul crește. Nu e nevoie să
   închizi și să redeschizi camera între două cărți.
   - ✓ verde = exemplar din fond, numărat.
   - „Deja scanat” = îl trecuseși deja (nicio problemă, nu este numărat de două ori).
   - ⚠ „În afara fondului” = un exemplar care **nu aparține** acestei biblioteci
     (intrus).
4. Dacă un cod QR este deteriorat, poți **introduce de mână** (URL-ul etichetei sau numărul
   exemplarului).
5. **„Încheie și vezi raportul”** — închide sesiunea și afișează:
   - **Prezente** (scanate și aparținând fondului),
   - **Lipsă** (în fond, dar nescanate → de căutat / de scos din evidență),
   - **Intruse** (scanate, dar dintr-o altă bibliotecă / necunoscute).
6. Exportă rezultatul în **CSV** (pentru foaie de calcul) sau în **PDF** (ca să tipărești
   lista exemplarelor lipsă și să pleci să le cauți pe rafturi).

> **Pauză și reluare.** Inventar mare? Te poți opri pe parcurs.
> Dacă ieși la jumătatea drumului, sesiunea rămâne **în curs** și apare în
> „Sesiuni în curs”, ca să **reiei** de unde te-ai oprit.

---

## Întrebări practice

**Trebuie să instalez ceva?** Nu. Este chiar site-ul. Opțional,
„Adaugă pe ecranul de pornire”, ca să-l deschizi ca pe o aplicație.

**Funcționează în browserul meu?** Da. În Chrome/Android, AnarBib folosește
cititorul nativ (mai rapid). În **Brave**, **iOS/Safari** și **Firefox**, încarcă
automat un cititor alternativ — deci **funcționează și** în aceste
browsere. Dacă la scanarea unui ISBN apare mesajul „citire incompatibilă”,
reîmprospătează pagina: cititorul alternativ se încarcă singur.

**Camera nu se deschide.** Verifică dacă ai acordat site-ului **permisiunea de acces la
cameră** (lacătul din bara de adrese). Browserul permite accesul la
cameră doar prin **HTTPS** — `app.anarbib.org` folosește deja HTTPS.

**Viața privată.** Decodarea este **locală**. Imaginea de la cameră **nu este trimisă
niciunui server**. Codul QR al cardului conține doar un cod opac; codul QR al
etichetei conține doar adresa exemplarului. Fondurile sensibile (BTL și
altele asemenea) rămân protejate de aceleași reguli ca de obicei.

---

## Într-o frază

Camera este **o mână întinsă** ca să te scutească de introducerea și verificarea de mână —
nu o obligație. Folosește-o când te ajută; ignoră-o când nu folosește la
nimic. Și dacă se blochează ceva, tastatura e mereu acolo.

---

*Document al bunului comun AnarBib. Îmbunătățirile și versiunile în alte limbi sunt
binevenite, scrise în paralel de comunitatea fiecărei limbi.*
