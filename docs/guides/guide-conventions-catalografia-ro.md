# Fișă — Cum scrii un nume, cum scrii un titlu

> **Traducere de revizuit.** Această versiune a fost tradusă din franceză ca să existe acum, nu
> peste șase luni. Dacă citești această limbă mai bine decât o scrie traducerea, corecteaz-o:
> este un bun comun, nu un text închis.

> **Cui se adresează această fișă.** Ție, care catalogezi. Adună ce se
> hotărăște în momentul introducerii: cum se scrie un nume, unde desparți o
> particulă, ce faci cu o colectivitate și de ce un câmp gol e mai bun decât un
> câmp ghicit.
>
> *De ce*-ul detaliat e în altă parte, în registrul deciziilor, secțiunea
> `CONV`. Aici, introducem date.

## Regula, într-o frază

**Un singur adevăr în bază, mai multe redări.** Tu introduci forma de
catalogare; majusculele, ordinea prenume-nume și formatările bibliografice sunt
**calculate** la afișare și la export. Nu le introduce niciodată de mână.

De aici vine toată dezordinea pe care o reparăm de două zile: punctul de
acces, forma de afișare și forma de export au fost puse **în aceeași căsuță**,
în momente diferite, de mâini diferite.

---

## 1. Numele unei persoane

### Forma de sortare e cea care contează

Câmpul **„Formă de sortare”** e adevărul. **„Formă standard”** derivă automat
din ea, prin simpla inversare la virgulă. Niciodată invers.

| Scrii în „Formă de sortare” | Aplicația afișează |
|---|---|
| `Kropotkin, Piotr` | Piotr Kropotkin |
| `Malatesta, Errico` | Errico Malatesta |

### Scriere naturală, niciodată majuscule

**`Kropotkin, Piotr` — niciodată `KROPOTKIN, Piotr`.**

Majusculele numelui de familie sunt o **normă de referință bibliografică**
(ABNT), nu o dată. Se adaugă la export, din mers. Dacă le tastezi tu, nu devin
mai adevărate: distrugi informația despre majuscule și minuscule, care nu se
mai poate reconstitui după aceea — `de Sousa` și `De Sousa` nu se mai pot
deosebi odată ce totul e cu majuscule.

### Unde desparți: particula

**Hotărăște limba NUMELUI, nu țara nașterii.** O persoană argentiniană poate
purta un nume italian.

| Limba numelui | Particula… | Exemplu |
|---|---|---|
| portugheză, franceză | **trece** după prenume | `Sousa, Manuel Joaquim de`<br>`Beauvoir, Simone de`<br>`Jong, Rudolf de` |
| italiană modernă, afrikaans, neerlandeză | **rămâne** în față | `Di Filippo, Luis`<br>`De Amicis, Edmondo`<br>`Van der Walt, Lucien` |

Luis Di Filippo e cazul de manual: argentinian, nume italian, deci `Di Filippo,
Luis` — și nu `Filippo, Luis Di`.

### Ce nu știe să hotărască instrumentul

**Nume de familie dublu sau prenume compus?** `García Lorca` e un nume de
familie dublu spaniol (nu se desparte); `Jean-Marie` e un prenume compus.
Nicio funcție nu face diferența. Dacă ai dubii, **întreabă** în loc să
tranșezi: exact astfel de cazuri ajung în coada de verificare.

---

## 2. O colectivitate nu e o persoană

**Numele unui colectiv nu are formă inversată.**

| ✅ | ❌ |
|---|---|
| `Grupo Krisis` | `Krisis, Grupo` |
| `Instituto de Estudos Libertários` | `Libertários, Instituto de Estudos` |
| `CIRA Marseille` | `Marseille, CIRA` |

### Completează „Tip de autoritate”

Câmpul există și **conduce regula**. Pus pe *Colectivitate*, împiedică
inversarea. Lăsat gol, nimic nu protejează fișa: va fi tratată ca o persoană
la prima trecere a unui instrument.

E un câmp de trei secunde care te scutește de o corectură de trei luni.

### Dacă fișa conține MAI MULTE persoane

Se întâmplă — importul a fabricat astfel de fișe.
`KAISER, William Young and David E.` nu e un Kaiser cu două prenume: sunt
**William Young** *și* **David E. Kaiser**, doi autori ai aceleiași cărți.

**Nu o repara pe loc.** O fișă de autoritate e folosită în comun de toată
rețeaua: dacă o redenumești, doar muți eroarea. Treci prin Atelierul
autorităților, propunere de tip **Divizare**: fișa de origine e păstrată,
celelalte sunt create, iar legăturile către cărți le urmează. Termen de
deliberare: paisprezece zile, ca la o unire.

---

## 3. Titlul

### Majusculele depind de limba titlului

**Nu** există o regulă universală. Germana scrie substantivele cu majusculă: e
**ortografia** ei, nu o greșeală de tastare.

Instrumentul de normalizare trece în minuscule doar **cuvintele funcționale ale
limbii titlului**, în poziție neinițială. Păstrează:

- **primul cuvânt**;
- cuvintele de după o **punctuație tare** (`.` `:` `;` `?` `!` și linia de
  subtitlu);
- **siglele**.

**Elimină un artefact de import, nu „rescrie” titlul.** Când îți propune o
corectură, doar tu judeci dacă un cuvânt e nume propriu — instrumentul nu
știe asta.

| Înainte | După |
|---|---|
| `Antologia Do Movimento Operário Gaúcho` | `Antologia do Movimento Operário Gaúcho` |
| `Der Einzige Und Sein Eigentum` | `Der Einzige und sein Eigentum` |

### Articolul inițial: nu mutila niciodată titlul

`Os Trabalhadores` se scrie **`Os Trabalhadores`**. Nu `Trabalhadores, Os` —
asta e o rămășiță a fișei de carton — și nici simplu `Trabalhadores`.

Ordonarea se reglează printr-un **contor de caractere ignorate la sortare**
(aici: 3, pentru `Os `), care lasă titlul intact.

---

## 4. Limba și țara

| Câmp | Format | Exemple |
|---|---|---|
| **Limbă** (a documentului) | cod BCP-47 | `pt-BR`, `fr`, `es`, `de`, `it` |
| **Țară** (a autorității) | cod ISO 3166-1 α-2 | `BR`, `FR`, `ES`, `NL` |

Nu `português`, nu `Brasil`, nu `bra`. Selectorul din aplicație îți dă codul
corect: folosește-l în loc să tastezi.

**Un NULL rămâne NULL.** Dacă nu cunoști limba, lasă gol. O limbă necunoscută
e o informație onestă; o limbă greșită conduce apoi majusculele titlului și
regula de intrare a numelui — propagă eroarea în loc s-o țină pe loc.

---

## 5. Datele

Doi întregi și un **calificativ**:

| Calificativ | Când |
|---|---|
| `exact` | data e stabilită |
| `circa` | aproximativă („pe la 1876”) |
| `uncertain` | sursele nu se potrivesc |
| `unknown` | nu se știe |
| `living` | **persoana e în viață** |

`living` nu e un detaliu de confort: fără el, „încă în viață” și „data morții
necunoscută” se confundau — adică oamenii erau făcuți să moară în catalog.

Când nașterea și moartea sunt amândouă necunoscute, folosește **perioada de
activitate** („activ/activă 1900-1910”). Și când sursele se contrazic, scrie
asta în **nota despre date**: e o reparație istoriografică, nu umplutură.

---

## 6. Ce nu e treaba ta să tranșezi singur/singură

Corpusul de autorități e **folosit în comun de toată rețeaua**. Să modifici o
fișă înseamnă să modifici catalogul mai multor biblioteci.

| Gest | Unde se întâmplă |
|---|---|
| corectezi o greșeală de tastare pe o fișă | direct |
| **unești** două fișe duplicate | Atelier — propunere, 14 zile |
| **divizezi** o fișă care conține două | Atelier — propunere, 14 zile |
| tranșezi o majusculă sau un nume de familie propus de instrument | coada de verificare |

În Atelier, o propunere rămâne deschisă cât timp celelalte biblioteci pot
obiecta. Termenul ăsta nu e o încetineală administrativă: el face ca corpusul
să rămână comun.

---

## Dacă ai dubii

**Lasă gol în loc să ghicești.**

Un câmp gol pune o întrebare — cineva o va vedea și îi va răspunde. Un câmp
greșit răspunde la o întrebare pe care n-a pus-o nimeni, și pare corect. Pe el
îl regăsim trei luni mai târziu, copiat în cinci cataloage.
