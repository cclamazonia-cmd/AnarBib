# Bun venit în rețeaua AnarBib

**Ghid de primire pentru echipele de coordonare — primele treizeci de zile**

*Versiunea 1.0 — 16 septembrie 2026 · Licență AGPLv3 · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Înainte de toate: ce a fost acceptat și ce nu încă

Candidatura bibliotecii tale a fost acceptată de echipa de coordonare a rețelei. Asta
înseamnă două lucruri, și numai două:

1. Rețeaua recunoaște biblioteca ta ca făcând parte din familia anarhistă și libertară
   pe care o găzduiește, și ți-a deschis drumul constituirii.
2. Contul tău nu mai este un cont de solicitare: este un cont de **coordonare în curs de
   constituire**.

Ce **nu** s-a întâmplat încă: biblioteca ta nu este activă. Nu apare în catalogul comun,
nu primește cititori/cititoare, nu face niciun schimb cu celelalte biblioteci. Este
**preactivă**, iar tu o vei scoate de acolo — nu fără ajutor, și nu într-o singură zi.

> **Promisiunea acestui ghid.** Nu trebuie să fii bibliotecar/bibliotecară. Nu trebuie
> să fii informatician/informaticiană. Trebuie să știi ce vrea colectivul tău și să ai
> pe cineva pe care să-l întrebi când nu știi. Restul înseamnă să dai clic.
>
> **Și regula de aur: dă clic, nu strici nimic.** Programul nu afișează tranzițiile
> imposibile, dezactivează cu o explicație butoanele pe care le-ar bloca o regulă și
> refuză în baza de date combinațiile imposibile. Puținele gesturi care chiar nu se mai
> pot anula sunt enumerate în capitolul 9.

**Persoana cu care vorbești.** În orice moment al acestui parcurs, înainte de a hotărî,
nu după: `anarbib@proton.me`. Rețeaua are ca principiu ca o decizie de constituire să se
discute cu un tovarăș/o tovarășă înainte de a deveni un formular. A scrie nu e o
mărturisire de slăbiciune — e funcționarea normală.

---

## 1. Ziua 1 — Intră și înțelege unde ești

### 1.1 Conectarea

Pagina de conectare este `/login` (butonul **Conectează-te**). Adresa `/cadastro` doar redirecționează
către ea: dacă un document vechi te trimite acolo, nu e greșeala ta.

Dacă folosești încă parola provizorie primită prin e-mail, **schimb-o înainte de orice
altceva**. Cât timp nu e schimbată, mai multe acțiuni rămân blocate — e o dovadă pasivă
că o persoană a preluat cu adevărat contul.

### 1.2 Cele două case

Este lucrul cel mai important din tot ghidul și merită învățat pe de rost.

| Dacă întrebarea este… | Mergi în… |
|---|---|
| „ce am hotărât?” | **`/biblioteca`** — casa colectivă |
| „ce fac cu persoana asta din fața mea?” | **`/painel`** — ghișeul |

În `/biblioteca` locuiesc identitatea publică, regulamentul, echipa, profilul de
adoptare, tranzițiile și confidențialitatea: tot ce a deliberat colectivul.
În `/painel` locuiește munca de zi cu zi: împrumuturi, returnări, consultări,
rezervări, conturi care așteaptă validarea.

Nu e o rânduială arbitrară. Multe programe de bibliotecă le amestecă pe cele două, iar
rezultatul este că setările politice ajung ascunse într-un colț de administrare. Aici,
deliberarea e de o parte și operarea de cealaltă.

### 1.3 Rutele pe care le vei folosi

| Rută | Ce este | Pentru cine |
|---|---|---|
| `/criar-conta` | înregistrare — **singura ușă de intrare, pentru toată lumea** | oricine |
| `/conta` | spațiul personal al fiecărei persoane care citește — nouă file | fiecare, pe al său |
| `/atelier` | atelierele: constituire și autorități | coordonare în curs de constituire |
| `/painel` | ghișeul, munca zilei | echipa (librarian, coordonare) |
| `/biblioteca` | casa colectivă, deciziile | echipa, cu puteri după rol |
| `/catalogacao` | catalogare și import | echipa |
| `/rede` | administrarea rețelei | doar persoanele care administrează rețeaua |

Pagina **Federação** și paginile publice — catalog, Operă, Periodic, Subiect,
Biblioteci, Cartografia rețelei, Tezaurul FICEDL — completează ansamblul. Rutele nu sunt
traduse: sunt aceleași în toate cele zece limbi.

> **Nu intri niciodată în contul altcuiva.** Tot ce trebuie să facă echipa pentru un
> cititor/o cititoare se află în `/painel`. Dacă te surprinzi vrând să „intri ca”
> altcineva, ce cauți e în `/painel`, fila
> **Cititor/cititoare** (`leitor`).

---

## 2. Zilele 1–3 — Atelierul de constituire

Constituirea este un parcurs în `/atelier`. Poți salva în orice moment și reveni mai
târziu: nimic nu se pierde între două sesiuni. **Ai 60 de zile**, iar o reamintire prin
e-mail sosește în ziua a 45-a.

### 2.1 Etapa 0 — profilul de adoptare, actul fondator

Înaintea tuturor celorlalte etape, programul te întreabă unde se plasează biblioteca ta
pe **patru axe independente**. Niciuna nu este un nivel de calitate: sunt moduri de a
exista, iar o bibliotecă mică ce alege peste tot modul simplu nu este o bibliotecă
neterminată.

**Axa 1 — `catalog_mode`, catalogul**

- `local_only` — fondul rămâne acasă, neexpus rețelei. Util într-o perioadă de rodaj
  sau când o parte din fond nu e gata să fie publicată.
- `network_published` — fondul intră în catalogul comun AnarBib.

**Axa 2 — `circulation_mode`, circulația**

- `off` — nicio circulație gestionată în program: doar catalog. E cazul unui fond
  patrimonial de consultare.
- `informal` — circulație simplă, fără cotizație și fără reguli stricte. Cazul tipic al
  unei mici biblioteci militante unde toată lumea se cunoaște.
- `full_sigb` — circulație completă: reguli, rezervări, cotizații, suspendări.

**Axa 3 — `network_mode`, federația**

- `isolated` — biblioteca există în AnarBib, dar nu face niciun schimb.
- `observer` — primește fluxurile rețelei, nu contribuie încă.
- `federated` — participă pe deplin.

**Axa 4 — `governance_mode`, guvernanța**

- `informal` — niciun rol de echipă distinct: toată lumea este cititor/cititoare. Fără
  cooptare, fără perioadă de așteptare, fără jurnal de audit.
- `staff_roles` — rolurile `librarian` și `coordenador·a` există, cooptare
  simplificată.
- `full_governance` — totul: cooptare, perioadă de așteptare, jurnal de audit, sarcini cron.

### 2.2 Ce aprinde fiecare alegere în `/painel`

Acest tabel este motivul pentru care etapa 0 vine înaintea tuturor celorlalte. Filele
ghișeului apar sau nu în funcție de axa circulației:

| Fila din `/painel` | Apare dacă |
|---|---|
| **Munca zilei** (`trabalho-do-dia`) | întotdeauna |
| **Acțiuni** (`acoes`) | întotdeauna |
| **Cititor/cititoare** (`leitor`) | întotdeauna |
| **Istoric** (`historico`) | întotdeauna |
| **Consultări pe loc** (`consultas-locais`) | circulație `informal` sau `full_sigb` |
| **Împrumuturi** (`emprestimos-livro`) | circulație `informal` sau `full_sigb` |
| **Rezervări** (`reservas`) | circulație `full_sigb` |
| **Împrumuturi grupate** (`emprestimos-lote`) | circulație `full_sigb` |
| **Contribuții** (`contribuicoes`) | cotizație activată **și** circulație diferită de `off` |

Dacă o filă nu apare la tine, nu e o defecțiune: e profilul pe care l-a ales colectivul
tău. Iar dacă profilul se schimbă în timpul sesiunii, `/painel` revine de la sine la
**Munca zilei**.

> **Alegerile nu sunt închisori.** Fiecare axă are propria doctrină de tranziție —
> unele rapide, unele lente, unele ireversibile. Fila **Tranziții**
> se află în `/biblioteca`, nu în `/painel`: schimbarea profilului este o decizie
> colectivă, nu un gest de ghișeu. Unele tranziții care traversează mai multe
> axe trec prin validarea persoanelor care administrează rețeaua.

### 2.3 Cele zece etape

După etapa 0, atelierul afișează doar etapele pe care profilul tău le face relevante. O
bibliotecă în `circulation_mode = off` nu va vedea etapa circulației: nu lipsește
nimic, doar că întrebarea asta nu se pune la voi.

| Etapă | Ce se hotărăște | Condiție |
|---|---|---|
| 1 | Identitate — nume, nume scurt, adresă, contact | întotdeauna |
| 2 | Program și ture | întotdeauna |
| 3 | Persoane responsabile | în funcție de guvernanță |
| 4 | Politica de catalogare | întotdeauna |
| 5 | Politica de circulație | dacă circulația nu este `off` |
| 6 | Politica de aderare a cititorilor/cititoarelor | în funcție de guvernanță și circulație |
| 7 | Politica de e-mailuri | întotdeauna |
| 8 | Vizibilitate și participare în rețea | dacă rețeaua nu este `isolated` |
| 9 | Date și confidențialitate | întotdeauna |
| 10 | Generarea regulamentului | întotdeauna |

**Niciuna dintre aceste etape nu este o chestiune de informatică.** Sunt zece întrebări
de adunare, prezentate în ordinea în care li se răspunde cel mai bine. Completează-le cu
ce a hotărât deja colectivul; acolo unde n-a hotărât, oprește-te și du întrebarea la
următoarea întâlnire. Atelierul așteaptă.

### 2.4 Etapa 10 — scheletul de regulament

La sfârșit, programul produce un PDF precompletat cu toate alegerile tale. **Acest PDF nu
este un certificat.** Este un schelet de discutat: materie primă pentru deliberare.
Secțiunile care merită dezbatere sunt marcate ca atare.

Parcursul așteptat este: îl descarci, îl duci în adunare, îl amendezi liber și reîncarci
documentul amendat ca regulament oficial al bibliotecii. Cât timp nu e reîncărcat,
biblioteca rămâne preactivă.

> **Un punct de onestitate.** „Încheierea constituirii” nu înseamnă, azi, activarea
> automată a bibliotecii. E o lacună cunoscută a programului, nu o greșeală a ta. Când
> ajungi la capătul etapelor, scrie la `anarbib@proton.me` ca să se facă activarea
> — și insistă dacă nu răspunde nimeni în câteva zile.

---

## 3. Zilele 3–7 — Pagina Biblioteca, casa colectivă

Odată încheiată constituirea, `/biblioteca` devine locul în care ce s-a hotărât rămâne
scris și ține. Acolo te uiți când cineva întreabă „dar ce conveniserăm?”.

- **Identitate publică** — ce văd rețeaua și publicul despre biblioteca ta.
- **Regulament** — documentul pe care l-ați adoptat și versiunile lui.
- **Echipa** — cine ce este și prin ce circuit (capitolul 4).
- **Profil** — cele patru axe, așa cum sunt azi.
- **Tranziții** — propunerile de schimbare a profilului și votul lor.
- **Confidențialitate** — păstrarea datelor, ștergerea automată, GDPR/LGPD.

**Deciziile de luat săptămâna aceasta**, toate în `/biblioteca`:

1. **Vizibilitatea fondului** — catalog public sau nu, apariția în galeria de
   biblioteci de pe `anarbib.org`, prezența pe cartografia rețelei. Pe
   cartografie, un colectiv care alege să nu apară are motivele lui: programul
   le respectă, și tu la fel.
2. **Politica de e-mailuri** — ce evenimente declanșează un mesaj către persoana care
   citește (ciclul împrumutului, reamintiri înainte de termen, somații pentru întârziere)
   și dacă echipa primește o copie. Toate acestea se aprind și se sting pentru fiecare bibliotecă.
3. **Păstrarea datelor** — cât timp rămâne păstrat istoricul de împrumut al unei persoane
   după returnare. E o chestiune politică pe cât e de legală: într-o
   bibliotecă militantă, un istoric este o listă de lecturi ale unor persoane
   identificate. A păstra puțin e o formă de protecție.
4. **Cotizația**, dacă există la voi — și odată cu ea fila **Contribuții**
   din `/painel`.
5. **Cardul de cititor** — dacă îl activați. Nu poartă niciun nume: doar
   numele scurt al bibliotecii și un cod QR opac, iar persoana care citește îl generează
   și îl regenerează ea însăși. E gândit așa intenționat, pentru ca un card
   pierdut să nu spună nimic despre cine îl purta.

> **Despre fila Confidențialitate.** Poate afișa două mesaje care se
> contrazic în privința ștergerii automate. E un defect de afișare cunoscut. Înainte
> să tragi concluzia că ștergerea este activă sau inactivă, întreabă rețeaua.

---

## 4. Zilele 5–10 — Formarea echipei

### 4.1 Trei roluri, și numai trei

`cititor/cititoare` · `librarian` (bibliotecar/bibliotecară) · `coordenador·a` (coordonare).

Rolul local de „administrator” a fost retras în mai 2026. Dacă îl găsești menționat
undeva, documentul este depășit. „Administrarea rețelei AnarBib” există, dar este
un **statut transversal** — nu e treapta următoare a scării și nu ajungi acolo
coordonând destul de mult timp. E un alt mecanism politic, cu propria
cooptare.

### 4.2 Capcana care costă scump

**Nimeni nu se înregistrează de două ori.** Toată lumea intră o singură dată prin
`/criar-conta`, ca cititor/cititoare — inclusiv persoanele care vor face parte din echipă.

A intra în echipă nu este o nouă înregistrare: este o cooptare și are loc
pe contul care există deja. Cine se reînregistrează crezând că „intră ca echipă” nu creează
decât un al doilea cont și o problemă pe care echipa de coordonare va trebui s-o desfacă.

**Așadar singurul lucru pe care trebuie să-l ceri cuiva care urmează să intre în echipă
este: „trimite-mi ID-ul tău public”.**

### 4.3 Circuitul în trei timpi

Nicio promovare nu este unilaterală. Trei persoane distincte, trei gesturi:

1. **Propune** — echipa de coordonare propune pe cineva prin ID-ul public, pentru rolul
   `librarian` sau `coordenador·a`.
2. **Susține** — o altă persoană din echipă ratifică. Persoana vizată este exclusă din
   cvorum: de îndată ce echipa numără alte două persoane active, sunt necesare două
   ratificări.
3. **Acceptă** — persoana propusă acceptă. Fără acest consimțământ, nu se întâmplă nimic.

Propunerea **expiră după 30 de zile**. O linie de cititor/cititoare se închide, cea de
bibliotecar/bibliotecară se deschide: un singur rol activ pe bibliotecă, iar istoricul rămâne.

> **Saltul colegial.** Implicit, ca să intri în cercul echipei de coordonare trebuie să fi
> trecut prin rolul de bibliotecar/bibliotecară. Pentru un colectiv orizontal, această treaptă
> intermediară nu corespunde la nimic: o singură decizie de adunare cerea două
> circuite în program. De aici saltul — să propui pe cineva direct de la cititor/cititoare
> la coordonare — care există ca **opțiune a bibliotecii**, dezactivată implicit,
> pe care colectivul tău o activează dacă vrea. Scurtează scara, niciodată
> consimțămintele.

### 4.4 Ieșirea din echipă

- **Perioadă de așteptare de 7 zile** — o ieșire din echipă nu e imediată; persoana trece printr-o
  stare intermediară, iar asta lasă timp de vorbit.
- **Inactivitate** — un cont de echipă care nu se mai conectează de mult iese
  automat, cu un aviz trimis persoanei cu 30 de zile înainte și cu 7 zile înainte. Avizul de la
  7 zile pleacă și către echipa de coordonare și este escaladat la persoanele care administrează rețeaua dacă
  persoana inactivă este ultima coordonare a casei.
- **Predarea ștafetei** — transmiterea coordonării către altcineva se face prin același
  circuit în trei timpi, înainte să pleci. Nu o lăsa pe ultima zi.

---

## 5. Zilele 7–20 — Fondul

### 5.1 Cele trei cuvinte de care ai nevoie

- **Operă** (*obra*) — fișa comună: cartea ca operă, aceeași pentru toată
  rețeaua.
- **Holding** — faptul că biblioteca ta deține această operă.
- **Exemplar** — obiectul fizic de pe raft, cu eticheta lui, starea lui,
  istoria lui.

Trei colective pot avea aceeași carte: o operă, trei holdinguri, mai multe
exemplare. De aceea corectarea unei fișe folosește întregii rețele, și tot de aceea
o fișă se corectează cu grijă.

### 5.2 Trei niveluri de fișă, și niciunul nu e cel greșit

| Nivel | Spirit |
|---|---|
| **Simples** | bibliotecă militantă, fără pretenții academice: tip, titlu, autoritate, an, editură, limbă, cotă, circulație implicită, copertă, ISBN |
| **Avançado** | muncă de bibliotecar/bibliotecară fără MARC: subtitlu, ediție, colecție, loc, pagini, contribuții tipizate, subiecte, note |
| **Completo** | exhaustiv: zone ISBD, MARC, identificatori de autoritate, proveniență completă |

**Schimbarea nivelului nu pierde nimic.** Un câmp ascuns de un nivel mai jos își păstrează
valoarea. Fă testul o dată, cu ochii tăi: asta convinge.

**Începe cu Simples.** Cinci fișe pe săptămână în Simples valorează mai mult decât o fișă
perfectă pe lună. Fondul nu există decât catalogat.

### 5.3 Singura cerință pe care rețeaua o are cu adevărat

**Niciun exemplar nou fără mod de achiziție.** De unde vine, când, donat de cine,
după ce eveniment.

Nu e un detaliu de erudiție. Într-o bibliotecă militantă, proveniența este
istoria colectivului. Fără ea, fondul devine un morman anonim în decursul unei generații.
Rețeaua nu-ți cere să recuperezi retroactiv — cere ca datoria să
înceteze să crească de acum înainte.

### 5.4 Restul din `/catalogacao`, când vei avea nevoie

Importuri în masă, asistent de eliminare a duplicatelor în trei timpi, căutare de
coperte, surse externe de metadate, depunere cu OCR în browser,
inventariere prin citirea etichetelor QR, periodice și stările lor de colecție. Nimic
din toate acestea nu e necesar în prima săptămână. E acolo când va veni momentul.

### 5.5 Subiecte și tezaurul FICEDL

AnarBib include **tezaurul FICEDL**: 462 de termeni, traduși în cele zece limbi,
livrați odată cu programul. Este un bun comun al federației și vine deja completat —
nu e o sarcină pentru tine.

**Subiectele locale**, dimpotrivă, aparțin fiecărei case: e fondul tău, vocabularul tău,
alegerile tale editoriale. Iar **alinierea** subiectelor tale la termenii FICEDL este un
act al colectivului, nu o operație tehnică: a spune că „aboliționismul penal” al tău
corespunde termenului comun „închisoare” este o poziție documentară. De aceea
alinierea nu vine gata făcută.

---

## 6. Zilele 10–25 — Ghișeul

Patru fluxuri, iar `/painel` le organizează:

- **Împrumut** — ieșire, returnare (inclusiv parțială), prelungire. Prelungirea se poate
  face exemplar cu exemplar: dacă persoana a terminat două dintre cele trei cărți, se
  prelungește doar a treia.
- **Returnare** — totală sau linie cu linie. O acțiune în masă nu eșuează niciodată în tăcere:
  ce n-a trecut e listat împreună cu motivul.
- **Consultare pe loc** — persoana vrea să vadă ceva pe loc, negociați un
  interval orar. **Negocierea se oprește după trei schimburi dus-întors**: dincolo de asta, programul vă
  trimite la telefon. E deliberat — o negociere care depășește atât nu e o
  problemă de program.
- **Rezervare** — până la ridicarea efectivă, care transformă rezervarea în împrumut.

Alături de acestea, în `/painel`: **validările** înregistrărilor de cititori/cititoare
(aici hotărâți cine intră), **garanția** dacă la voi se practică, **contribuțiile**,
**notele de lectură**, **evenimentele**.

> **Un defect cunoscut.** Butonul „Deschide împrumuturile” din unele sarcini ale filei
> Munca zilei duce la o filă goală. Nu e vina ta. Treci direct prin fila **Împrumuturi**
> (`emprestimos-livro`).

---

## 7. Zilele 20–30 — Federația

Pagina **Federação** are opt file: **Início**, **Círculos**, **Diretório**,
**Assembleias**, gazeta **Rizoma**, **Carta/Boletim**, **Apoio mútuo** și **Comuns**.

E partea programului care nu este un sistem integrat de gestiune a bibliotecii. Există pentru că proiectul nu vrea
să fie un „SaaS pentru biblioteci”: a intra în AnarBib înseamnă a intra într-un proiect
politic comun, iar o rețea care face schimb doar de fișe nu e o rețea.

Ce e de făcut în această ultimă săptămână, fără grabă:

1. **Treceți de la `observer` la `federated`**, dacă asta ați hotărât — și numai
   atunci. A intra în rețea în modul observator câteva luni este o alegere
   respectabilă.
2. **Completați-vă fișa în Diretório**, ca celelalte case să știe cine sunteți
   și cum să vă vorbească.
3. **Hotărâți în privința cartografiei** — să apăreți cu adresă precisă, doar cu
   orașul sau să nu apăreți deloc. Niciunul dintre cele trei răspunsuri nu trebuie justificat.
4. **Uitați-vă la Círculos și la Assembleias**, ca să știți unde se iau deciziile rețelei.
5. **Dacă publicați catalogul**, vedeți cu rețeaua ce înseamnă pentru voi punctul OAI-PMH
   — prin el pot alte cataloage să-l recolteze pe al vostru.

Pagina `/rede` este administrarea propriu-zisă a rețelei, rezervată persoanelor care
administrează rețeaua. Coordonarea unei biblioteci nu dă acces la ea, și e voit așa.

---

## 8. Cele zece decizii care nu sunt tehnice

Decupează această listă și du-o în adunare. Niciunul dintre aceste răspunsuri nu se află
în program: programul nu face decât să înregistreze ce veți răspunde.

1. Unde ne plasăm pe cele patru axe ale profilului?
2. Catalogul nostru este public?
3. Împrumutăm, și în ce condiții?
4. Cine se poate înregistra ca cititor/cititoare și cine validează?
5. Avem o cotizație? O garanție?
6. Cât timp păstrăm istoricul de lectură al persoanelor?
7. Cine face parte din echipă și activăm saltul colegial?
8. Apărem pe cartografie, și cu ce precizie?
9. Participăm la adunările rețelei, și cine ne reprezintă acolo?
10. Cum ne aliniem subiectele la tezaurul comun — și ce refuzăm să
    aliniem?

---

## 9. Ce nu strică nimic și ce cere o a doua citire

**Nu strică nimic:** să dai clic peste tot, să deschizi toate filele, să schimbi nivelul fișei
ca să vezi, să salvezi o etapă pe jumătate, să propui o persoană și să lași propunerea
să expire, să activezi și să dezactivezi saltul colegial, să treci de la `observer` la `federated`,
să corectezi o fișă.

**Cere o a doua citire, pentru că nu se mai poate anula sau costă scump:**

- **Ștergerea** unui cont — și atenție: în portugheză, programul deosebește **APAGAR**
  (golirea istoricului) de **EXCLUIR** (ștergerea contului), cu două cuvinte de
  confirmare diferite. În celelalte nouă limbi, cele două cad pe același cuvânt — în
  română însă cuvintele diferă: **GOLIRE** pentru istoric și **ELIMINARE** pentru cont.
  Citește toată fraza înainte să tastezi, nu doar cuvântul cerut.
- Ștergerea unui istoric — datele nu se mai întorc.
- Tranzițiile de profil marcate ca ireversibile în fila Tranziții.
- Publicarea în rețea a unui fond pe care colectivul n-a hotărât să-l publice.
- Scoaterea cuiva din echipă — perioada de așteptare de 7 zile există tocmai pentru
  asta.

---

## 10. Unde ceri ajutor și cum dai înapoi

**Să ceri ajutor:** `anarbib@proton.me`. Spune pe ce ecran ești și ce te
așteptai să vezi. Nu există întrebări proaste: programul a fost scris de o singură
persoană, iar fiecare „n-am găsit” care ajunge înapoi este un defect identificat.

**Un ritual care funcționează.** O jumătate de oră pe săptămână, cu echipa, trei întrebări
fixe:

> ce n-am găsit pe ecran? · ce am făcut fără să înțeleg?
> · ce îi lipsea programului?

Răspunsurile alimentează o foaie de lacune care devine ordinea de zi următoare — și un
material de contribuție la proiect. E singurul dispozitiv care face ca utilizarea să urce
până la cod.

**Să dai înapoi, fără să programezi.** Fișierul `AIDER.md`, de la rădăcina depozitului,
enumeră sarcinile deschise care nu cer cod: traducere, revizuirea scrierii incluzive,
documentație, alinierea subiectelor, testarea ecranelor. AnarBib este sub AGPLv3 și are
azi o singură persoană care îl întreține — e principala lui fragilitate, și se spune
în loc să fie trecută sub tăcere.

---

## 11. Cele treizeci de zile pe o pagină

| Când | Ce | Unde |
|---|---|---|
| Ziua 1 | Conectare, schimbarea parolei, plimbare fără a schimba nimic | `/login`, `/conta` |
| Zilele 1–3 | Etapa 0: cele patru axe, hotărâte în colectiv | `/atelier` |
| Zilele 3–5 | Etapele 1–9 | `/atelier` |
| Ziua 5 | Etapa 10: descărcarea scheletului de regulament | `/atelier` |
| Zilele 5–10 | Regulamentul dus în adunare, amendat, reîncărcat | adunare, apoi `/atelier` |
| Zilele 5–10 | Strângerea ID-urilor publice, deschiderea circuitelor de cooptare | `/biblioteca`, fila Echipa |
| Zilele 7–20 | Primele fișe în modul Simples, toate cu proveniență | `/catalogacao` |
| Zilele 10–25 | Prima zi de ghișeu pe cont propriu | `/painel` |
| Zilele 20–30 | Fișa în diretório, cartografie, modul de rețea | Federação, `/biblioteca` |
| Ziua 30 | Scrie rețelei: ce a lipsit, ce a indus în eroare | `anarbib@proton.me` |

---

*Acest ghid există în zece limbi: pt-BR, fr, es, en, it, de, ca, eo, nl, el. Descrie
starea programului în septembrie 2026 și va fi corectat când programul se va schimba — dacă un
ecran nu corespunde cu ce scrie aici, ghidul greșește, iar a spune asta este
o contribuție.*

**Bun venit.**
