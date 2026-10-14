# Document-cadru — Întrajutorarea la catalogare (fila „Întrajutorare” din Federație)

**Data**: 15 iunie 2026
**Stadiu**: **document-cadru / proiect** — reflecție exploratorie care stabilește *viziunea*,
*arhitectura* și *deciziile de principiu*. **Nu este încă o specificație de
construit**: de discutat, de pus la încercare, apoi de declinat în specificații.
**Temelia etică**: [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
(„mâna întinsă”). **Fiecare ecran de mai jos a fost trecut prin grila „întinde sau
apucă?”.** Acest document-cadru este, într-un fel, prima punere la încercare
concretă a cartei.

---

> **Notă din 8 septembrie 2026.** §8 de mai jos, scris în iunie, prevedea o instanță Jitsi militantă „în lipsă, `meet.jit.si`”. Ambele puncte s-au schimbat: gazda aleasă în iunie, Autistici/Inventati, a fost declarată „teroristă” de Statele Unite pe 26 august 2026 și s-a închis; din 8 septembrie, apelul video trimite la **Framatalk** (Framasoft), iar varianta de rezervă codată spre `meet.jit.si` (companie americană) a fost **retrasă** — în lipsa unei setări, se ajunge la Framatalk, niciodată la o gazdă americană. Un Jitsi găzduit de noi sau de un aliat este trecut în șantierul de autogăzduire (backlog I2). Registru: FED-O9.

## 1. Nevoia

Catalogarea este punctul dureros al bibliotecilor începătoare (cf. șantierele
autorități, indexare pe subiecte, wizard de descoperire). O bibliotecă singură în fața
autorităților, a subiectelor, a clasificării se simte intimidată. Fila „Întrajutorare”
răspunde exact acestei nevoi — dar catalogarea anarhistă nu este neutră: vedetele
de subiect dominante patologizează, șterg, numesc greșit. **Întrajutorarea
transmite un *meșteșug politic* pe care nici standardele, nici o IA nu-l codifică.**

Principiu transversal: **apelul la ajutor este generic** (întrajutorare pe *orice* subiect
tehnic spinos), **catalogarea este primul domeniu conectat**.

## 2. Trei grade de întrajutorare — o scară, prin subsidiaritate

Nu „unul SAU altul”, ci trei *intensități*; apelul la ajutor este pivotul, iar
răspunsul ia una dintre cele trei forme, de la cea mai ușoară la cea mai grea:

1. **Bunul comun al cunoașterii** (vademecumuri, cazuri, tezaur) — cost zero, dependență zero,
   100 % între egali. Baza durabilă.
2. **Mini-wizarduri** — ghidează biblioteca astfel încât să facă *ea însăși* (emancipator,
   nu creator de dependență).
3. **Ajutor uman direct** (apel → răspuns → eventual apel video) — cel mai
   relațional, pentru când bunul comun și wizardul nu ajung.

**Bucla descendentă**: un caz dificil rezolvat la gradul 3 → rezumat → devine un caz/wizard
de gradul 1-2 → data viitoare, wizardul ajunge. *Cunoașterea coboară treptele cu
timpul; rețeaua devine mai isteață și mai autosuficientă la fiecare episod.*

## 3. Bunul comun al cunoașterii — stratul de autonomie

Trei straturi, iar cel mai adânc este **vocabularul însuși**:

- **Tezaurul, nucleu politic.** Nu o listă de cuvinte: un *graf de concepte*. Politica
  trăiește în **termeni**, în **relații** (broader/narrower/related) și în **note de
  aplicare** (care sunt micro-vademecumuri). De construit pe **SKOS** (standard
  liber) — să lăsăm moștenire o normă, nu o cârpeală. Există o sămânță (tezaur de ~30 de categorii).
- **Cazuri & vademecumuri** — exemple lucrate, editabile, care apar *la punctul de nevoie*.
- **Wizarduri ca *date*, nu ca *cod*** — *pariul autonomiei*: dacă un wizard este
  cod, depindem de dezvoltatori pentru totdeauna; dacă este un **document structurat** (arbore de
  cartonașe-întrebare → cartonașe-final) pe care un motor scris-o-singură-dată îl derulează, **orice
  bibliotecă scrie unul fără să programeze**. Bariere de siguranță ca să nu devină un limbaj de
  programare deghizat: fără variabile/calcul/condiție liberă; singura stare = drumul parcurs; condiții
  eventuale dintr-o listă închisă; **wizardul *sfătuiește*, nu *scrie* niciodată** (cel mai rău
  eșec = „nu a fost util”, niciodată „a stricat catalogul”); wizarduri mici, cu un singur subiect.

**Multilingv fără IA**: carcasa i18n (10 limbi) poartă interfața; *substanța*
(termeni, cazuri) se scrie **pe comunități lingvistice** (scriere paralelă cu legături încrucișate, nu
traducere de sus în jos) — lent, dar durabil și gratuit. **Guvernanță**: adăugarea/modificarea unui
termen prin fluxul **consimțământ/obiecție** al cercurilor; cursorul politic „variante
admise vs convergență” rămâne de plasat de către rețea.

## 4. Declanșarea — la punctul de nevoie (carta ③)

**Declanșatorul este *câmpul*, *datele* sau *cererea* — niciodată supravegherea
persoanei.** Interzise semnalele comportamentale („5 min pe câmp”, ezitări):
asta e Clippy *și* supravegherea muncii. Trei declanșatori onești:
- **intrinsec câmpului** (subiectele/autoritatea sunt grele *pentru toată lumea* → ajutorul e mereu acolo);
- **derivat din date** (fără ISBN, autor/autoare ambiguu/ambiguă → cartea semnalează, nu persoana);
- **cerere explicită** (un „ajutor!” calm, mereu la îndemână).

Ajutorul urcă **scara cu-un-clic-mai-departe** (inline → wizard → cerc), **discret, dar
ușor de descoperit** (amplasare de încredere, niciodată modal/gamificat), cu o **prezență în curbă pe
domeniu** (puțin mai primitor dacă e câmpul gol + număr mic de fișe; se estompează odată cu
stăpânirea; mereu pliabil manual).

## 5. Două ecrane deja trecute prin grilă

### 5.1 — „?” de sub un câmp dificil (catalogare)
Prezent *pentru că acel câmp e greu pentru oricine* (abordare a demnității, nu „pari să ai
dificultăți”). Când îl deschizi: sugestii din tezaur inline + cazuri din bunul comun → „drum
ghidat” (wizard) → „întreabă cercul” (gradul 3, momentul consimțământului).
**Grila a ucis două funcții tentante**: ❌ detectarea ezitării pentru a oferi
ajutor (supraveghere, fațeta ③); ❌ insigne/serii/bară spre „expert/expertă” (fațeta ⑥).
**Valori implicite reținute**: plasa „prima dată? drum ghidat” *oferită, dar în registrul
ofertei*; „?” mereu vizibil, sugestii **desfășurate la clic** (discret + ușor de descoperit).

### 5.2 — Încheierea episodului + captarea în bunul comun
Final **inițiat de persoana ajutată** (fără închidere automată, fără încheiere de către persoana care ajută). Ecran
„mulțumesc” sobru, **nimic agățat** (decuplare anti-datorie). **Treapta-fulg** „păstrăm
legătura?”, simetrică, ignorabilă, nu creează nimic decât la dublu-da.
**Captarea în bunul comun fără datorie**: este invitată **persoana care ajută** (deține cunoașterea nouă), nu
persoana ajutată; **micro-contribuție legată de obiect** (notă pe un termen/câmp), **amorsată
de urma** episodului; apoi **persoana ajutată este invitată să recitească/îmbogățească** („ce a fost
cu adevărat greu”) — *vocea ei, refuzabilă, niciodată o judecată a persoanei care ajută*, și **neblocantă**
(nota stă în picioare singură).
**Grila a ucis**: ❌ „notează-ți experiența” (clasament deghizat); ❌ insignă de finalizare.

## 6. Confidențialitate

Datele de catalog sunt *mai puțin* sensibile decât datele cititorilor/cititoarelor (metadate despre
*cărți*, niciodată exemplare/împrumuturi/identități), **dar nu zero** (fondurile unei biblioteci
anarhiste pot fi sensibile politic; cf. distincția `visibility_level='network'` /
BTL). Prin urmare:
- **opt-in pe element** (niciodată un dump), **BTL/sensibilele excluse implicit**;
- **persoana care ajută *propune*, biblioteca proprietară *validează*** — niciodată scriere directă de către un terț;
  acces **delimitat, revocabil, auditat**;
- treapta **„întreabă cercul” ESTE momentul consimțământului** („vei arăta aceste
  elemente bibliotecii X — iată ce iese”);
- **bunul comun captează meșteșug *generic dezidentificat*, nu *cazuri* identificabile**;
  particularitățile sunt eliminate sau consimțite.

Răspuns la întrebarea „drept absolut de a delega?”: **da autonomiei, dar consimțământ
*informat și încadrat*, nu cec în alb** — riscul să fie făcut mic și asumat în
cunoștință de cauză.

## 7. Potrivire & maturizare în parteneriat

- **Sortare blândă, nu filtru dur.** Într-o rețea rarefiată, un ȘI (aceeași limbă ȘI geografie ȘI
  disponibilitate ȘI expertiză) = mulțime vidă. **Ordonăm** după afinitate (limbă ↑, fus orar ↑,
  voluntar/voluntară ↑) fără să **excludem**; subsidiaritate **întâi cercul → rețeaua dacă e tăcere**.
  **Cercul pertinent depinde de tipul de ajutor** (catalogare → lingvistic; material/represiune → geografic).
- **Primul gest fără precondiții**: să te oferi voluntar/voluntară pentru *un singur* act nu cere niciun cerc
  și niciun profil. **Apartenența se adună din gesturi** (recunoaștere consimțită, niciodată etichetă).
- **Anti-ierarhie**: fără reputație individuală, fără marketplace; disponibilitate
  declarată, reciprocitate vizibilă fără scor, rotație.
- **Maturizare în parteneriat (§21)** — *a doua fază, care dizolvă raritatea*: un episod bun
  se poate **maturiza** într-un parteneriat → ajutorul viitor este *pre-potrivit* (limbă, fus orar,
  consimțământ deja dat); rețeaua se **îndesește**. **Decuplat** de episod (niciodată pe loc =
  datorie); **după repetare** (recunoaștere, nu creare); **dublu opt-in simetric**;
  **scară de profunzime** (0 → păstrăm-legătura → tovărășie → parteneriat formal);
  **inversarea datoriei** (parteneriatul este un *dar* pentru persoana ajutată: „un tovarăș/o tovarășă
  pe care îl/o poți chema din nou fără un nou consimțământ”, nu ceva datorat); mereu **dizolvabil**.

## 8. Grefa video (gradul 3)

Cuplăm ajutorul uman cu un **apel video Jitsi** (sincron = transmitere eficientă); bazin =
**cercul lingvistic**. **Întâi asincron, video ca turbo opțional** (persoana cea mai precară are o
conexiune proastă → gradele 0-2 în text/offline).
Tehnic, „gratuit”: **integrarea se codează o singură dată prin iframe API, cu `domain`
în configurație** → niciodată blocată la un furnizor. Implicit trimitem spre o **instanță Jitsi
militantă** (cel mai fidel doctrinei, gratuit, fără GAFAM); în lipsă, `meet.jit.si` (asumând
autentificarea creatorului sălii). Săli **efemere, nume imposibil de ghicit, lobby**. **Zero
server, zero secret, zero cost recurent.** Autogăzduirea rămâne *în parcare* (VPS exclus).

## 9. Cost & autonomie

Totul (bun comun, wizarduri, panouri, potrivire, video link-out) **rulează pe stack-ul existent**
(Supabase + front static): **cost marginal zero, fără IA ca să funcționeze**. IA rămâne un
**accelerator opțional și decuplabil** (precatalogarea doar a *neutrului*; politicul
rămâne între tovarăși/tovarășe). **Organele există deja**: sămânța de tezaur, wizardul de
descoperire, i18n în 10 limbi, fluxul consimțământ/obiecție al cercurilor, §21 parteneriat. **Acest
document-cadru leagă organe existente — de aici modestia lui și independența lui față de cost
și de orice dependență externă.**

## 10. Decizii luate / întrebări deschise

**Luate (pe parcursul reflecției):**
- Trei grade în scară + bucla descendentă a cunoașterii.
- Bun comun = tezaur (SKOS, nucleu politic) + cazuri + **wizarduri ca date**.
- Declanșare prin câmp/date/cerere, **niciodată supraveghere**; scară cu un clic;
  prezență în curbă pe domeniu.
- Ecranul „?”: valori implicite (ofertă, sugestii la clic); refuzuri (detectarea ezitării, gamificare).
- Încheiere: persoana ajutată încheie; **persoana care ajută redactează → persoana ajutată îmbogățește**
  (datorie zero); bun comun = **meșteșug generic**; guvernanță **aditiv = 2 persoane / vocabular = colectiv**.
- Potrivire **sortare blândă + întâi cercul**; cerc **după tipul de ajutor**; primul gest fără
  precondiții; **apartenență prin gest**.
- Maturizare §21 **decuplată, după repetare, dublu opt-in, scară de profunzime, inversarea
  datoriei, dizolvabilă**.
- Video **Jitsi cu `domain` configurabil**, întâi asincron, zero infrastructură/secret.
- (Reamintire e-mail, deja implementată în afara acestui document-cadru) limba destinatarului/destinatarei
  = **preferința sa personală**.

**Deschise (cursoare politice de plasat de către rețea):**
- **Nivelul inițial de primire** (ospitalitate) și **cine îl stabilește**: rețea / cerc / bibliotecă /
  persoană. Pistă: s-o *întrebăm* pe persoana nou-venită ce primire dorește (consimțământ) + subsidiaritate
  (nivelul de sus umple doar tăcerea) + opțiunea unui *mentorat întrupat* de un voluntar/o voluntară din cerc.
- Nivelul de **prezență al treptei-fulg** și al invitației la bunul comun (oferit vs disponibil) —
  în mare parte dezamorsat de **semantică** (registrul ofertei ≠ injoncțiune).
- Forma concretă a **editorului de wizarduri-ca-date** (până unde, fără să devină cod).
- Cursorul **variante vs convergență** al tezaurului.

## 11. Stadiu

Document-cadru de **discutat și pus la încercare**, nu un ordin de construcție. Când o componentă va fi
matură, se va declina într-o specificație, iar fiecare ecran va trece din nou prin **grila cartei relaționale**.
