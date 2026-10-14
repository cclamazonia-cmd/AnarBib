---
title: "Ghidul de guvernanță AnarBib"
subtitle: "Pentru persoanele care coordonează o bibliotecă și pentru cele care administrează rețeaua"
author: "Projet AnarBib"
date: "Versiunea 1.2 — 1 septembrie 2026"
lang: ro
---

# Cuvânt înainte

Acest ghid se adresează persoanelor care, în rețeaua AnarBib, îndeplinesc o funcție de coordonare — fie că e vorba de coordonarea unei biblioteci locale, fie de administrarea rețelei. Are un dublu obiectiv:

- **Să explice logica politică** a regulilor înscrise în SIGB-ul AnarBib și filiația lor cu proiectul de emancipare colectivă care a dat naștere bibliotecilor anarhiste;
- **Să dea unelte practicilor** de zi cu zi, răspunzând la întrebările concrete pe care le întâlnesc echipele de coordonare când folosesc programul.

## O convenție politică

Acest ghid nu este regulamentul rețelei și nu are nicio autoritate superioară deciziilor colectivelor care o alcătuiesc. Ce conține are putere doar pentru că niște oameni s-au pus de acord ca lucrurile să funcționeze așa la un moment dat. Dacă practicile evoluează, acest text va trebui să evolueze odată cu ele, sau să fie contrazis, sau să fie rupt. Folosirea pe care i-o vor da colectivele îi va hotărî soarta.

Regulile tehnice pe care SIGB-ul AnarBib le face respectate — perioadele de așteptare, fluxurile de cooptare, statusurile membership-urilor etc. — sunt și ele convenții. Au fost scrise de tovarăși și tovarășe la date precise, pentru a rezolva probleme precise. Sunt consemnate în **fișiere de specificație** (fișierele `spec-*.md` din depozit), datate și semnate, care sunt și ele amendabile. Când citești acest ghid, citești starea unei dezbateri la un moment dat. Nu este o constituție.

## Cum este organizat acest ghid

Ghidul are două părți:

- **Partea I — De ce.** Patru capitole care stabilesc cadrul politic: la ce folosește un SIGB anarhist, care sunt principiile lui fondatoare, cum se articulează cele două perimetre (biblioteca locală și rețeaua) și cum pot fi amendate regulile înseși.

- **Partea a II-a — Cum.** Șase capitole practice, fiecare despre o mare întrebare operațională: a coopta, a retrage, a gestiona situațiile care derapează, a exercita o funcție în administrarea rețelei, a garanta transparența, și un ultim capitol care comentează cazuri concrete de la un capăt la altul.

La sfârșitul fiecărui capitol practic, o rubrică **„Dacă regula te deranjează”** amintește unde se poate discuta și cum se poate propune un amendament. E important, pentru că aceste reguli au sens doar dacă pot fi amendate.

Anexele de la sfârșitul volumului servesc drept referință rapidă: glosar, index al funcțiilor tehnice cu traducerea lor politică, model de propunere de amendament și linkuri către specificațiile-sursă.

## Cum să citești acest ghid

Poate fi citit dintr-o suflare, dar probabil nu e cea mai bună folosire. Trei feluri de a intra în text, după nevoi:

- **Ca să înțelegi spiritul proiectului** înainte să preiei o funcție: citește partea I (capitolele 1–4).
- **În fața unei situații concrete**: sari direct la capitolul practic în cauză (5–10).
- **Ca să te informezi înaintea unei adunări generale** în care va fi pusă o întrebare de guvernanță: citește capitolul în cauză plus rubrica „Dacă regula te deranjează” corespunzătoare și consultă specificația-sursă din anexa D.

Ce e scris aici se sprijină pe patru documente de specificație:

- `spec-gouvernance-roles.md` (5 mai 2026) — roluri, statusuri, tranziții;
- `spec-administrateur-reseau.md` (11 mai 2026) — separarea local/rețea, cooptare cu unanimitate;
- `spec-validation-physique.md` (3 mai 2026) — modurile de primire a conturilor de cititor/cititoare;
- `spec-refactor-v3-semantique.md` (9 mai 2026) — semantica fluxului de rezervare (menționată în treacăt).

Trimiterile la aceste specificații sunt reamintite pe parcursul textului sub forma `(cf. spec-gouvernance, §3.4)`, ca să poți săpa mai adânc.

## O notă despre voce

Textul alternează între **se** și formele impersonale (colectivul AnarBib, din care fac parte și persoana care scrie, și persoana care citește), **tu** (când ne adresăm unei anumite persoane din coordonare sau din administrare, care trebuie să facă o alegere) și **noi** (când vorbim despre tovarășii și tovarășele care au scris regulile, la un moment dat, și care ar putea fi alte persoane decât cele care le citesc). E voit. Nu există aici neutralitate instituțională: acest text e purtat de tovarăși și tovarășe și se adresează unor tovarăși și tovarășe.

\newpage

# Partea I — De ce

\newpage

# 1. Un SIGB anarhist — ce înseamnă asta?

## 1.1. SIGB-ul nu este adunarea generală

Primul principiu de ținut, și cel mai greu, este acesta: **SIGB-ul înregistrează deciziile colectivului, nu le ia**. Fraza pare banală. În realitate, este pivotul în jurul căruia se organizează tot restul.

De fiecare dată când SIGB-ul AnarBib pare să fie o autoritate — când refuză o promovare, când impune o perioadă de așteptare de șapte zile, când blochează o tranziție de status — nu face decât să **facă executabilă** o regulă pe care și-au dat-o colectivele. Regula a fost scrisă undeva, într-o specificație, după discuție. Cineva a recitit-o și a criticat-o. O versiune a fost fixată și pusă în funcțiune. Iar acum, în clipa în care dai clic pe buton, programul se mulțumește să aplice ce s-a convenit.

Dacă ți se pare că regula e proastă, contraproductivă sau nedreaptă, nu SIGB-ul trebuie combătut. Specificația trebuie amendată. Vezi capitolul 4.

## 1.2. Tensiunea asumată

Orice program care gestionează permisiuni este, prin construcție, un dispozitiv de ierarhizare. Trebuie ca cineva să poată valida o înregistrare, să poată modifica identitatea publică a unei biblioteci, să poată accesa datele personale ale unui cititor/unei cititoare. Această necesitate tehnică se află într-o tensiune aparentă cu idealul de orizontalitate care animă bibliotecile anarhiste.

AnarBib **își asumă această tensiune** în loc s-o ascundă. Compromisul politic pe care l-am găsit se reduce la două puncte:

- **Rolurile nu sunt grade**. Sunt **funcții** delegate temporar de colectiv unora dintre persoanele care îl alcătuiesc, pentru a executa sarcini tehnice precise. Nimeni nu e coordonator/coordonatoare „pe viață”. Nimeni nu e administrator/administratoare de rețea „prin esență”. Aceste funcții sunt împrumutate și pot fi luate înapoi.

- **Mecanismele de retragere** contează cât mecanismele de numire. SIGB-ul prevede explicit cum iese cineva dintr-o funcție — prin auto-retrogradare, prin cerere colectivă cu perioadă de așteptare, prin auto-retragere din rețea, prin retragere colectivă cu unanimitate. O funcție din care nu se poate ieși nu e o funcție, e o acaparare.

## 1.3. Delegare și rotație

Ideea centrală este cea de **delegare cu rotație**. Un colectiv deleagă unora dintre persoanele care îl alcătuiesc executarea unor sarcini tehnice (gestionarea împrumuturilor în SIGB, modificarea vizibilității bibliotecii, primirea unei persoane noi în echipă). Această delegare este:

- **Explicită**: se întrupează într-un act de cooptare consemnat în jurnalul de audit;
- **Reversibilă**: persoana delegată poate părăsi funcția când vrea, iar colectivul i-o poate cere după modalități bine încadrate;
- **Temporară prin natura ei**: chiar dacă SIGB-ul nu impune nicio durată, cultura politică a rețelei este că funcțiile se rotesc și nu te instalezi în ele.

Această rotație a funcțiilor face diferența dintre o „delegare” (anarhistă) și o „ierarhie” (statală sau capitalistă). Dacă te instalezi într-o funcție, devii o treaptă. Dacă ieși regulat din ea, rămâi un tovarăș/o tovarășă care face un serviciu.

## 1.4. Cele opt principii fondatoare

Specificația de guvernanță a rolurilor (`spec-gouvernance-roles.md`, §2) explicitează opt principii fondatoare. Le enumerăm aici ca să ne putem referi la ele în restul ghidului; fiecare capitol practic din partea a II-a va trimite la ele.

**P1 — Delegare, nu ierarhie.** Niciun rol nu este un titlu. Toate rolurile sunt temporare prin natura lor și revocabile.

**P2 — Cooptare pentru rolurile de staff.** Intrarea într-o echipă (a deveni librarian sau coordenador) se face prin cooptare de către persoanele care au deja rolul coordenador. Colectivul decide cine intră; persoana coordenador nu e decât mâna care execută decizia în SIGB.

**P3 — Retrogradarea voluntară e mereu posibilă.** Orice persoană cu un rol de staff se poate retrograda singură oricând, fără consultare. „Îmi cedez rolul” este un drept fundamental.

**P4 — Excludere încadrată de o perioadă de așteptare.** Excluderea nevoluntară a unei persoane librarian de către o persoană coordenador trece printr-o perioadă de așteptare de șapte zile înainte de a produce efecte. Această perioadă permite deliberarea colectivă și eventuala anulare de către o altă persoană coordenador.

**P5 — Transparență maximă.** Jurnalul de audit al schimbărilor de rol poate fi citit de întregul staff activ al bibliotecii, nu doar de persoanele coordenador. A împiedica manipulările opace face parte din cultura politică a orizontalității informaționale.

**P6 — Notificări sistematice.** Orice schimbare de rol declanșează un e-mail către persoana în cauză și către întreaga echipă de coordonare. Nimănui nu i se poate modifica rolul fără să știe, iar echipa de coordonare este mereu informată.

**P7 — Suveranitatea locală a bibliotecilor.** Schimbările de rol din biblioteca A nu afectează nimic în biblioteca B, nici chiar pentru aceeași persoană. Fiecare bibliotecă este suverană asupra delegărilor sale interne.

**P8 — SIGB-ul nu modelează adunarea generală.** SIGB-ul execută deciziile, nu le ia. Nu conține niciun mecanism de vot, de cvorum sau de deliberare. Aceste lucruri se petrec în colectiv, în afara programului.

## 1.5. Ce nu face SIGB-ul

E util să facem explicite alegerile de **nemodelare**:

- SIGB-ul **nu definește** ce este o coordonare „bună”. O bibliotecă poate decide în cerc, în adunare generală plenară, prin rotație, prin tragere la sorți, prin consens, prin majoritate. SIGB-ului nu-i pasă.
- SIGB-ul **nu măsoară** legitimitatea politică a unei cooptări. Dacă o persoană din coordonare dă clic pe „promovează X ca librarian”, SIGB-ul înregistrează. Colectivul trebuie să se asigure că decizia a fost luată corect, iar această asigurare se joacă în cultura politică a colectivului.
- SIGB-ul **nu arbitrează** conflictele. Când ceva derapează, SIGB-ul oferă unelte (suspendare imediată, cerere de retragere, jurnal de audit lizibil), dar decizia politică rămâne în afara programului.

Această modestie nu e un defect, e o exigență. Un SIGB care ar pretinde că modelează viața politică a unui colectiv ar fi, ipso facto, autoritar — și-ar impune viziunea despre ce este o decizie „bună”. AnarBib refuză această pantă.

## 1.6. Și respectarea libertăților digitale?

Trei precizări, pentru că întrebarea revine:

- **Date personale**: conturile de cititor/cititoare conțin ce a vrut persoana să pună în ele. Bibliotecile au acces doar la datele strict necesare funcționării lor. Membership-urile din alte biblioteci sunt, prin construcție, etanșe (P7).

- **Jurnalul de audit**: jurnalul este public **pentru staff-ul activ** al bibliotecii, nu pentru persoanele care citesc și nici pentru restul rețelei. Această transparență internă servește la împiedicarea manipulărilor opace între echipele de coordonare; nu este un panopticon îndreptat împotriva persoanelor care citesc.

- **Jurnale cross-biblioteci**: când o persoană din administrarea rețelei intervine într-o bibliotecă (caz acoperit de spec admin-reseau, §6.3.1), acțiunea este consemnată într-un tabel dedicat, cu nivel de criticitate. Poate fi citit de administrarea rețelei și de echipa de coordonare a bibliotecii în cauză. Transparență în ambele sensuri.

\newpage

# 2. Cele două perimetre: biblioteca locală și rețeaua

## 2.1. De ce această separare

Rețeaua AnarBib nu este un lanț de biblioteci cu un sediu central. Este o **federație de colective autonome**. Această realitate politică a ajuns să se impună chiar în structura SIGB-ului.

La început, în primele versiuni, rolul de „administrator AnarBib” era legat de o bibliotecă anume în tabelul `user_library_memberships`. Această modelare sugera — fără s-o spună — că un administrator/o administratoare AnarBib *administra o bibliotecă*. Politic, nu era adevărat: o persoană din administrarea rețelei animă coordonarea între biblioteci, nu conduce nicio bibliotecă anume.

Specificația `spec-administrateur-reseau.md` (11 mai 2026) a consfințit separarea. De acum, SIGB-ul cunoaște **două perimetre distincte**:

- **Staff-ul local** al unei biblioteci (rolurile `reader`, `librarian`, `coordenador`), stocat în `user_library_memberships`. Autoritatea sa politică se situează **în perimetrul bibliotecii**.

- **Administrarea rețelei** (tabelul `network_administrators`), fără legătură cu vreo bibliotecă. Autoritatea sa politică este **transversală**, dar nu ia niciodată locul autonomiei locale.

## 2.2. Ce face fiecare perimetru

**Staff-ul local** se ocupă de viața de zi cu zi a unei biblioteci: împrumuturi, returnări, rezervări, validarea înregistrărilor, modificarea regulamentului, a politicilor de circulație, a identității publice a bibliotecii. Tot ce privește funcționarea **unei** biblioteci se rezolvă la nivelul staff-ului local.

**Administrarea rețelei** asigură coordonarea între biblioteci: activarea bibliotecilor noi, moderarea catalogului comun, întreținerea tehnică a platformei, primirea colectivelor noi și intervenția excepțională când o bibliotecă ajunge blocată (nicio persoană activă în coordonare, conflict major etc.). Tot ce privește **rețeaua** se rezolvă la nivelul administrării rețelei.

## 2.3. Regula nesuprapunerii

O regulă politică simplă ghidează toate contoarele și toate vederile SIGB-ului:

> **Fiecare pagină spune povestea perimetrului ei. Un contor numără ce este înscris în perimetrul său, nici mai mult, nici mai puțin.**

Concret:

- Pagina unei biblioteci își numără membership-urile locale. Punct. Persoanele din administrarea rețelei nu apar în aceste contoare, chiar dacă tehnic pot interveni în bibliotecă.
- Pagina rețelei își numără administratorii/administratoarele de rețea. Punct.

Dacă o persoană este în același timp `coordenador` într-o bibliotecă **și** administrator/administratoare de rețea (cazul lui Xavier la 11 mai 2026), apare în ambele contoare, **o dată în fiecare**, fără deduplicare încrucișată. Sunt **două înscrieri politice distincte**, numărate fiecare în perimetrul ei.

De ce această regulă e sănătoasă politic, în patru puncte:

- **Onestitate**: angajamentul tău local e numărat în biblioteca pe care o animi; angajamentul tău în rețea e numărat la nivelul rețelei. Nimeni nu te numără „de 1,5 ori”.
- **Lizibilitate**: o persoană militantă care se uită la fișa unei biblioteci vede imediat câte persoane sunt angajate **local**, fără să se întrebe dacă niște administratori/administratoare de rețea „din afară” umflă contorul.
- **Robustețe**: dacă mâine se adaugă roluri intermediare (auxiliar, stagiar, observator/observatoare), regula „pagină = perimetru” rămâne clară.
- **Coerență politică**: separarea dintre administrarea rețelei și staff-ul local este o **decizie politică**, nu un detaliu de modelare. Contoarele trebuie s-o reflecte.

## 2.4. Dreptul transversal al administrării rețelei

Acest punct merită bine înțeles, pentru că e ușor de interpretat greșit.

**O persoană din administrarea rețelei poate interveni tehnic în orice bibliotecă.** Poate, de exemplu, să citească catalogul unei biblioteci `private`, să-i modifice vizibilitatea sau — în cazuri excepționale — să creeze ori să modifice membership-uri. Este ceea ce specificația numește **drept de intervenție transversal**.

Acest drept există din două motive:

- **Întreținere**: trebuie ca cineva să poată debloca o bibliotecă rămasă în pană (nicio persoană în coordonare, configurație stricată etc.).
- **Mediere**: când un conflict grav străbate o bibliotecă și împiedică colectivul local să funcționeze, e nevoie de un recurs.

Dar acest drept **nu** o transformă pe persoana din administrarea rețelei într-o instanță ierarhic superioară echipei de coordonare locale. Doctrina rețelei, stabilită în acest ghid:

> **O intervenție a administrării rețelei într-o bibliotecă locală trebuie precedată de informarea echipei de coordonare locale în cauză**, cu excepția unei urgențe vitale (compromitere activă, hărțuire în curs, atac împotriva platformei). Informarea prealabilă nu este o cerere de autorizare: persoana din administrarea rețelei are dreptul să acționeze. Dar este un **semn de respect** față de autonomia bibliotecii și păstrează posibilitatea unui alt aranjament (de exemplu: „lasă-mă să încerc să rezolv eu întâi, te țin la curent”).

Trasabilitatea tehnică există, de altfel: toate acțiunile cross-biblioteci ale unei persoane din administrarea rețelei sunt consemnate în tabelul `cross_library_actions_log` cu un nivel de criticitate și pot fi citite a posteriori de echipa de coordonare locală.

## 2.5. Suveranitatea locală este inviolabilă

O ultimă precizare politică, ce decurge din principiul **P7 — Suveranitatea locală a bibliotecilor**.

Bibliotecile din rețeaua AnarBib **se recunosc reciproc**. Când BLMF validează fizic un cititor nou/o cititoare nouă (cf. `spec-validation-physique.md`), această validare e valabilă pentru toate bibliotecile `network` din rețea. Este un **pact de circulație implicit** între biblioteci care împărtășesc destulă cultură politică pentru a avea încredere unele în altele.

Dar această recunoaștere reciprocă **nu dă niciun drept de ingerință** unei biblioteci în alta. Echipa de coordonare a bibliotecii A nu poate modifica membership-urile bibliotecii B. Nu poate vedea datele personale ale cititorilor/cititoarelor din B (cu excepția celor înscriși/înscrise și la ea). Nu poate schimba regulamentul bibliotecii B.

Fiecare bibliotecă rămâne **suverană asupra delegărilor sale interne**, asupra politicii de primire, a modului de validare, a regulilor de cotizație, a regulamentului intern. Rețeaua nu spune cum trebuie să funcționeze. Spune doar cu cine se recunosc.

\newpage

# 3. Statusuri, roluri, tranziții: gramatica SIGB-ului

Acest capitol e ceva mai arid decât celelalte. Stabilește vocabularul tehnic folosit de-a lungul întregului ghid. Dacă îl sari la prima lectură, poți reveni la el la nevoie.

## 3.1. Cele patru roluri

SIGB-ul AnarBib folosește patru roluri, declarate în baza de date prin constrângerea `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` pe tabelul `user_library_memberships`.

**`reader`** — Cont de bază de cititor/cititoare. Nicio putere de administrare. Permisiuni: consultarea catalogului (după vizibilitatea bibliotecii), împrumut, rezervare, consultare în sală, modificarea propriilor date personale, cererea de migrare sau de ștergere a contului.

**`librarian`** — Staff operațional. Se ocupă de viața de zi cu zi: împrumuturi, rezervări, returnări, validarea înregistrărilor (după modul bibliotecii), modificarea datelor de catalog, acces la datele personale ale cititorilor/cititoarelor bibliotecii. **Doar citire** pe lista echipei. Primește notificările despre schimbările de rol și poate citi jurnalul de audit al echipei (P5).

**`coordenador`** — Staff de coordonare. Tot ce are o persoană librarian, plus: modificarea identității publice a bibliotecii (nume, logo, contact etc.), modificarea configurației (politici de împrumut, regulament), gestionarea regulilor de cotizație, **și toate acțiunile de guvernanță a echipei**: a coopta, a cere o retragere, a suspenda, a ridica o suspendare, a anula o cerere de retragere.

**`administrador`** — Rol istoric, pe cale de dispariție. Exista pentru a însemna „drept de administrare cross-biblioteci”, dar era legat de un `library_id`. De acum înlocuit de **persoanele din administrarea rețelei**, stocate în tabelul `network_administrators` (cf. capitolul 2). Spec admin-reseau prevede migrarea progresivă și retragerea finală a acestui rol din tabelul `user_library_memberships`.

## 3.2. Statusurile unui membership

Fiecare rând din tabelul `user_library_memberships` are un **status** care exprimă starea delegării la un moment dat. Statusurile care privesc guvernanța:

**`active`** — Stare normală. Persoana are rolul și îl exercită.

**`pending_validation`** — Rezervat specificației de validare fizică. Membership-ul e creat, dar așteaptă o întâlnire fizică cu o persoană librarian+ din biblioteca de înscriere. Niciun acces la funcțiile rolului cât timp are acest status.

**`suspended`** — **Măsură de precauție** luată de o persoană coordenador. Niciun acces. Folosire: hărțuire semnalată, în așteptarea investigației, cont compromis, conflict aflat în mediere. **Durată nedefinită**; ridicarea e manuală, de către o persoană din coordonare (revenire la `active`), sau prin destituire efectivă.

**`pending_removal`** — **Perioadă de așteptare de șapte zile** înainte de excluderea efectivă. Niciun acces în această perioadă. Evoluții posibile: anulare de către o altă persoană din coordonare (revenire la `active`), auto-retrogradare a persoanei înseși (scurtcircuit) sau trecere automată la `removed` în ziua Z+7.

**`vacated`** — **Rol părăsit voluntar.** Pus de auto-retrogradare („predau ștafeta”, dreptul P3). Persoana a decis — acest status spune exact asta, și nimic altceva. *(Distincție introdusă la 1 septembrie 2026: înainte de această dată, ieșirea voluntară punea `inactive`, ceea ce o confunda cu un cont abandonat.)*

**`removed`** — Membership închis printr-o decizie sau un mecanism al SIGB-ului: sfârșitul perioadei de așteptare a unei retrageri (Z+7) sau închiderea rândului de rang inferior la o promovare (rol exclusiv, cf. §5.6).

**`inactive`** — **Cont abandonat.** Pus doar de cron-ul de ieșire automată, după 9 luni fără conectare (T9). Persoana n-a decis nimic: a dispărut.

*(Tabelul mai are și câteva statusuri proprii parcursurilor de înscriere și de circulație — `refused`, `left_with_pending_circulation`, `terminated` — care nu țin de guvernanța echipei și nu sunt tratate în acest ghid.)*

## 3.3. Schema tranzițiilor

SIGB-ul nu permite orice tranziție între statusuri. Iată, simplificată, schema permisă:

```
                       ┌──────────────┐
                       │   active     │ ◄──────────┐
                       └──────┬───────┘            │
                              │                    │
        ┌──────────────┬──────┴────────┬───────────│──────┐
        ▼              ▼               ▼           │      ▼
 ┌─────────────┐ ┌─────────────┐ ┌────────────┐    │ ┌────────────┐
 │  suspended  │ │ pending_    │ │  vacated   │    │ │  inactive  │
 │             │ │ removal     │ │ (P3, auto) │    │ │ (T9, cron) │
 └──────┬──────┘ └──────┬──────┘ └────────────┘    │ └────────────┘
        │               │                          │
        │ ridicare      │ anulare                  │
        └───────────────┴──────────────────────────┘
                        │
                        ▼ (Z+7)
                 ┌──────────────┐
                 │   removed    │
                 └──────────────┘
```

Câteva reguli-cheie:

- O persoană librarian **nu** poate fi exclusă dintr-un singur gest, prin decizia unilaterală a unei alte persoane din coordonare. Trebuie trecut prin `pending_removal` și așteptat sfârșitul perioadei de așteptare (sau ca persoana să se retrogradeze singură).
- Propriul rol `active` poate fi **oricând** părăsit voluntar (auto-retrogradare, dreptul P3): rândul trece la `vacated`, imediat.
- `suspended` **nu** are durată maximă. Nu e o perioadă de așteptare înaintea excluderii, e o măsură de precauție — durează cât durează deliberarea.
- Dintr-un status închis (`vacated`, `removed`, `inactive`) **nu se revine** direct la `active`. Pentru a reintegra o persoană, se trece din nou prin circuitul normal — care reactivează rândul închis sau creează unul nou. Istoricul se păstrează.

## 3.4. Cele nouă tranziții: cine ce poate face

Specificația de guvernanță a rolurilor formalizează nouă tranziții, enumerate aici în formă condensată. Detaliul operațional se află în partea a II-a.

| # | Tranziție | Cine | Mecanism |
|---|---|---|---|
| T1 | `reader` → `librarian` | Propunere (o persoană din staff-ul local) → susținere (cvorum) → **acceptare** (persoana în cauză) | Cooptare colegială, prin circuitul de invitație |
| T2 | `librarian` → `coordenador` | Propunere (o persoană din coordonarea locală SAU din administrarea rețelei) → susținere (altă persoană din staff) → **acceptare** (persoana în cauză) | Cooptare colegială, prin circuitul de invitație |
| T2b | `reader` → `coordenador` (**saltul colegial**) | La fel ca la T2 — doar dacă biblioteca a activat opțiunea | Cooptare colegială; opțiune pe bibliotecă, dezactivată implicit |
| T3 | `coordenador` → `librarian` | Persoana însăși SAU alte persoane din coordonare | Auto-retrogradare SAU retragere colegială cu perioadă de așteptare |
| T4 | `librarian` → `reader` (voluntar) | Persoana însăși | Auto-retrogradare |
| T5 | `librarian` → `reader` (colectiv) | Coord+ | `pending_removal` cu perioadă de așteptare de 7 zile |
| T6 | Suspendare imediată | Coord+ | Trecere la `suspended` |
| T7 | Ridicarea suspendării | Coord+ | Revenire `suspended` → `active` |
| T8 | Anularea unei cereri de retragere | Coord+ | Revenire `pending_removal` → `active` |
| T9 | Ieșire automată (cont abandonat) | Cron | Trecere la `inactive` după 9 luni fără conectare |

Trei principii structurează acest tabel:

- **Intrarea trece prin cooptarea colegială** (T1, T2) — și prin T2b acolo unde biblioteca a ales-o: o propunere, susținerea echipei după cvorum, apoi **acceptarea de către persoana în cauză**. Nimeni nu se promovează singur/singură — și nimeni nu e promovat/promovată fără să-și fi spus cuvântul *(reformele din 26 august și 1 septembrie 2026)*.
- **Ieșirea voluntară e mereu posibilă** (T3 auto, T4). Nimeni nu rămâne prins/prinsă într-o funcție pe care nu mai vrea s-o exercite.
- **Ieșirea impusă e încetinită de perioada de așteptare** (T5). Șapte zile pentru a permite o eventuală revenire colegială asupra deciziei.

## 3.5. De partea administrării rețelei: o schemă geamănă

Administrarea rețelei (tabelul `network_administrators`) are propriul ciclu de viață, foarte apropiat ca structură, dar cu două particularități:

- **Cooptare cu unanimitate**: pentru a adăuga o persoană nouă în administrarea rețelei, o propunere este deschisă de o persoană activă din administrare, iar **toate celelalte persoane active din administrare** trebuie să voteze `favorable`. Un singur vot `opposed` (cu justificare obligatorie de minimum 20 de caractere) blochează propunerea. O abținere blochează și ea, cât timp nu e transformată în vot.

- **Retragere colectivă cu unanimitate**: pentru a retrage o persoană din administrarea rețelei împotriva voinței ei, același flux se aplică în oglindă. Cu o perioadă de așteptare de **șapte zile** după acordul unanim (câmpul `pending_collective_removal_until`).

Auto-retragerea, în schimb, este **unilaterală și mereu posibilă** (cu excepția cazului în care ești singura persoană activă din administrare: atunci tranziția trece prin `pending_removal`, cu o perioadă de așteptare de 30 de zile și un e-mail de alertă către celelalte persoane din administrare).

Detalii complete în capitolul 8.

\newpage

# 4. Reversibilitate și amendabilitate

Acest capitol scurt tratează o întrebare politică crucială: **cum pot fi modificate aceste reguli?** Dacă n-ar putea fi, SIGB-ul ar fi o autoritate, iar tot restul acestui ghid ar fi o minciună.

## 4.1. Trei niveluri de amendabilitate

Trebuie distinse trei niveluri de reguli, care nu se amendează în același fel:

**Practicile locale ale unei biblioteci** — politica de primire, modul de validare fizică (`open` sau `manual_validation`), regulamentul intern, frecvența adunărilor generale, modalitățile de cooptare. Aceste practici sunt **interne fiecărei biblioteci**. Rețeaua nu se amestecă. Se amendează în adunarea generală a bibliotecii sau după procedura pe care și-a dat-o colectivul.

**Regulile rețelei** — separarea local/rețea, principiul cooptării cu unanimitate pentru administrarea rețelei, doctrina informării prealabile la o intervenție cross-biblioteci, modalitățile de activare a bibliotecilor noi. Aceste reguli sunt **între biblioteci**. Se amendează în coordonarea rețelei, după discuții între administrarea rețelei și echipele de coordonare locale în cauză.

**Fundamentele politice ale proiectului** — cele opt principii (P1–P8 din capitolul 1), ideea că SIGB-ul nu modelează adunarea generală, modestia revendicată a programului în fața vieții politice a colectivelor. Aceste fundamente pot fi amendate, dar sunt structurante: a le modifica înseamnă probabil a modifica ceea ce numim „AnarBib” în sens larg. O repunere în discuție de asemenea amploare ar trece printr-o discuție colectivă în toată rețeaua, probabil cu prilejul unui eveniment (întâlnire anuală etc.).

## 4.2. Cum propui un amendament

Nu există un singur mod de a face asta — fiecare nivel îl are pe al lui —, dar iată tiparul general pe care rețeaua tinde să-l practice:

1. **Identifică specificația în cauză**. Regulile SIGB-ului sunt consemnate în fișiere `spec-*.md` din depozit. Găsește-o pe cea care conține regula pe care vrei s-o amendezi (anexa D dă corespondențele).

2. **Redactează o notă de amendament**. Format liber, dar care să răspundă la: ce regulă, de ce pune probleme, ce modificare propui, ce consecințe tehnice și politice anticipezi. Anexa C propune un model.

3. **Pune nota în circulație**. După nivel:
   - **Local**: în adunarea generală a bibliotecii sau pe canalul de discuții al colectivului.
   - **Rețea**: pe canalul de coordonare între biblioteci (Matrix `#anarbib`), menționând administrarea rețelei și echipele de coordonare locale relevante.
   - **Fundamente**: pe toate canalele și, probabil, pe ordinea de zi a unei întâlniri.

4. **Discuția, amendarea, alegerea unei versiuni**. SIGB-ul nu spune cum trebuie să se desfășoare această etapă. E meseria colectivelor.

5. **Dacă decizia e luată**: o persoană din administrarea rețelei sau un/o dev (adesea aceeași persoană sau aceleași persoane) implementează modificarea în specificația corespunzătoare, apoi în cod. Noua versiune e pusă în funcțiune după procedura obișnuită (changelog, comunicare etc.).

## 4.3. Dacă decizia tehnică pune probleme

Se întâmplă să cădem de acord politic asupra unei reguli, dar traducerea ei tehnică să fie complicată, grea sau să aibă efecte secundare nedorite. E normal. Specificațiile existente sunt pline de note de felul „această decizie politică implică modificarea a 22 de sub-SELECT-uri din RLS, ceea ce justifică o refactorizare prealabilă”. Dialogul politic / tehnic este permanent.

Când propui un amendament, nu ezita s-o faci chiar dacă n-ai idee cât de grea e partea tehnică. Persoanele dev din rețea îți vor spune cât costă. Iar dacă e foarte scump, veți putea decide colectiv dacă miza politică merită costul tehnic. Invers, uneori o schimbare politică măruntă permite o simplificare enormă a bazei de cod.

## 4.4. Acest ghid este și el amendabil

Acest ghid este versionat. Versiunea curentă e indicată pe pagina de copertă. Dacă ți se pare că spune ceva greșit, că a uitat un caz sau că ia o poziție care nu mai corespunde doctrinei rețelei, **spune-o**. Deschide o discuție, propune o modificare sau rescrie pasajul și trimite-l.

Un ghid care nu poate fi modificat nu e un ghid, e o dogmă. Proiectul AnarBib nu are vocația de a produce dogme.

\newpage

# Partea a II-a — Cum

\newpage

# 5. Cooptarea cuiva în echipa ta

Acest capitol acoperă tranzițiile T1 (`reader` → `librarian`) și T2 (`librarian` → `coordenador`), adică **cele două mișcări de intrare** într-o echipă de bibliotecă. Validarea fizică a unei persoane noi `reader` (care nu e o cooptare în sens politic, ci o operațiune tehnică de primire) e tratată separat în §5.5.

## 5.1. Principiul politic

> **P2 — Cooptare pentru rolurile de staff.** Intrarea într-o echipă se face prin cooptare. Colectivul politic decide cine intră; SIGB-ul nu e decât mâna care execută decizia.

Asta înseamnă că **a depune o propunere** nu este o decizie personală a persoanei care dă clic: este **executarea tehnică** a unei decizii care a fost luată — sau trebuie luată — de colectivul bibliotecii. De la reformele din vara lui 2026, SIGB-ul însuși reflectă această colegialitate: **niciun rol de staff nu se mai dă dintr-un clic**. Orice intrare trece prin trei timpi — propunere, susținere, **acceptarea de către persoana în cauză**. Doctrina despre „când anume” trebuie luată decizia nu este tranșată, în mod voit, de acest ghid: fiecare bibliotecă și-o face pe a ei (vezi §5.4).

## 5.2. Ca să primești pe cineva ca `librarian` (T1)

Din 1 septembrie 2026, primirea este **colegială de la un capăt la altul**: nimeni nu mai e „numit/numită” dintr-un clic. Se depune o **propunere**, echipa o **susține** după cvorumul bibliotecii, iar persoana în cauză **acceptă** — sau refuză, sau lasă propunerea să expire (30 de zile). A nu face nimic e tot un răspuns: propunerea se închide de la sine.

### Condiții prealabile

- Persoana are un cont AnarBib.
- Nu are deja un membership de staff (`librarian` sau `coordenador`) activ în bibliotecă.
- Cazul obișnuit: e înscrisă la bibliotecă drept cititor/cititoare. Primirea acceptă și o persoană fără aderare locală.

### Procedura în SIGB

1. Mergi în `/biblioteca`, fila **Echipa** → „Primește în echipă” (după identificatorul public), sau fila **Cititori/cititoare** → „Propune în echipă” pe rândul persoanei.
2. Confirmă fereastra modală: se depune o **propunere** — nimic nu e promovat în acest stadiu.
3. Echipa susține propunerea, după cvorumul bibliotecii (vizibil în „Setări de guvernanță” din fila Echipa): în modul „cosemnare”, 2 susțineri, dintre care cel puțin una din partea coordonării — propunerea însăși contează ca una.
4. Persoana primește invitația și **acceptă** (în contul ei, la „Bibliotecile mele”) sau refuză.
5. La acceptare, SIGB-ul execută: rând `librarian` activ; rândul `reader`, dacă exista, este **închis** (rolurile sunt exclusive — rolul `librarian` îl include pe cel de `reader`); e-mailuri către persoană și către întreaga echipă de coordonare; jurnal de audit `promoted_to_librarian`.

### Efectul la acceptare

Persoana primește permisiunile de `librarian`: gestionarea împrumuturilor, validarea înregistrărilor, acces la datele personale ale cititorilor/cititoarelor bibliotecii etc. Nu primește permisiunile de modificare a identității publice și nici pe cele de modificare a configurației — acestea sunt rezervate rolurilor `coordenador+`.

### Partea tehnică

RPC-urile circuitului: `fn_team_propose_invitation(p_library_id, p_invited_public_id, 'librarian')` → `fn_team_ratify_invitation(p_invitation_id)` → `fn_team_accept_invitation(p_invitation_id)` (sau `fn_team_decline_invitation`). Vechea promovare directă (`fn_team_promote_to_librarian`) este **condamnată** din 1 septembrie 2026: refuză și indică drumul colegial.

## 5.3. Ca să propui o persoană `librarian` pentru coordonare (T2)

Același circuit, aceeași logică (reforma din 26 august 2026): **propunere → susținere → acceptare**. Coordonarea nu ți-o dai singur/singură și nici nu se impune: este o sarcină și se acceptă.

### Precondiții

- Persoana are o apartenență `librarian` `active` în bibliotecă — **sau**, dacă biblioteca a activat **saltul colegial** (vezi mai jos), o apartenență `reader` `active`.
- Nu are deja o apartenență `coordenador` activă și nici o invitație în curs.

### Procedura în SIGB

1. Fila **Echipa**, rândul persoanei → **„Propune pentru coordonare”** (sau, pentru un salt, fila **Cititori/cititoare** → „Propune pentru coordonare”).
2. Un alt membru/o altă membră a echipei susține propunerea (persoana vizată nu intră în cvorum: ea acceptă, nu susține).
3. Persoana primește un e-mail care numește sarcina drept ceea ce este și **acceptă** — refuzul nu costă nimic, iar cedarea rolului va rămâne un drept și după aceea.
4. La acceptare: rând `coordenador` activ; rândul activ inferior (`librarian` sau, la un salt, `reader`) se închide; jurnal de audit `promoted_to_coordenador`, cu proveniența (`from_role`).

### Saltul colegial: cititor/cititoare → coordonare (opțiune pentru fiecare bibliotecă)

Pentru bibliotecile care funcționează ca **colectiv orizontal** — unde a te alătura colectivului înseamnă a împărți coordonarea — scara `reader` → `librarian` → `coordenador` impunea o treaptă de trecere fără realitate în grup. Din 1 septembrie 2026, o bibliotecă poate permite ca propunerea de coordonare să vizeze direct un **cititor activ/o cititoare activă**:

- **Este alegerea fiecărei biblioteci**, dezactivată implicit. Setarea se comută în fila **Echipa**, blocul „Setări de guvernanță” — vizibilă pentru toată echipa, comutabilă de echipa de coordonare. Activeaz-o prin decizia colectivului tău, nu din comoditate.
- **Circuitul colegial se aplică integral**: propunere, susținere conform cvorumului, acceptare. Saltul scurtează scara, niciodată consimțămintele.
- **Prețul de știut**: persoana primește dintr-o singură mișcare accesul la datele personale ale cititorilor/cititoarelor, la configurare și la gestionarea echipei — fără perioada de exercițiu pe care o dădea etapa `librarian`. Este coerent acolo unde încrederea se construiește în adunare, în afara software-ului.
- **E-mailurile o spun**: susținerea unui salt este cerută în cunoștință de cauză („încă nu face parte din echipă”), iar persoana vizată știe că ar intra direct în coordonare.
- **Se poate dezactiva oricând**: scara redevine singura cale, iar propunerile de salt încă deschise vor eșua la acceptare.

### Partea tehnică

Același circuit RPC ca pentru primirea în echipă, cu `p_role = 'coordenador'`. Setare: `libraries.allow_direct_coordenador`. Vechea `fn_team_promote_to_coordenador` este condamnată din 26 august 2026.

## 5.4. Întrebarea politică: când dai clic?

Este întrebarea pe care și-o pune orice persoană din coordonare prima dată. Rețeaua AnarBib **în mod voit nu a tranșat** această întrebare la nivelul ghidului: fiecare bibliotecă își face propria doctrină, pentru că cultura politică a unui colectiv anarhist nu se decide la scara unui ghid generic.

Iată cele trei doctrine pe care le întâlnim în rețea, fără judecată:

**Doctrina 1 — Așteptare strictă.** Se dă clic doar **după** o decizie consemnată a colectivului (adunare generală, cerc, consens formal, oricare ar fi modalitatea). Persoana din coordonare doar execută. Avantaj: orizontalitate maximă, trasabilitate politică puternică. Dezavantaj: poate fi lent, mai ales când biblioteca e la început sau când colectivul e risipit.

**Doctrina 2 — Anticipare asumată.** Persoana din coordonare poate anticipa o decizie pe care o consideră sigură („e evident că Voltairine va fi cooptată, vine în fiecare săptămână de șase luni”), **cu condiția să o spună explicit în jurnalul de audit**: motiv = „anticipare pe răspunderea mea, de validat la următoarea adunare generală”. Decizia poate fi contestată a posteriori, iar retragerea rămâne mereu posibilă. Avantaj: suplețe practică. Dezavantaj: mută o parte din responsabilitatea politică asupra persoanei din coordonare care dă clic.

**Doctrina 3 — Cercul coordonării.** Cooptarea se hotărăște prin acord între persoanele active din coordonarea bibliotecii, fără a trece prin adunarea generală plenară. Argument: coordonarea este ea însăși un colectiv deliberativ și are mandat să acționeze. Avantaj: cale de mijloc între 1 și 2. Dezavantaj: poate deveni opacă dacă echipa de coordonare nu se reînnoiește la rândul ei.

**Recomandarea noastră** (și nimic mai mult): **alege explicit** o doctrină, scrie-o în regulamentul bibliotecii tale și indic-o în câmpul „Motiv” din jurnalul de audit la fiecare cooptare („doctrina 2 — anticipare pe răspunderea mea”, de exemplu). Opacitatea e rareori bună în politică.

## 5.5. Caz special: validarea în persoană a unei persoane `reader`

**Sosirea** unei persoane `reader` într-o bibliotecă este o operațiune diferită de o cooptare în sens politic. Este acoperită de specificația `spec-validation-physique.md`.

Două moduri posibile, alese de fiecare bibliotecă în configurația ei:

**Modul `open`** — Validarea este **automată** la înregistrare. Odată creat contul și confirmat e-mailul, persoana `reader` are imediat acces la cataloagele `public` și `network`. Potrivit pentru bibliotecile puțin expuse politic.

**Modul `manual_validation`** — Contul este creat online, dar rămâne **în așteptare** până la o **întâlnire în persoană** între persoana `reader` și o persoană `librarian+` din biblioteca de înregistrare. Potrivit pentru bibliotecile expuse (context politic tensionat, fonduri sensibile, spații fragile etc.).

### Procedura de validare în persoană (modul `manual_validation`)

1. Persoana se înregistrează online și alege biblioteca ta ca bibliotecă de apartenență.
2. Contul ei este creat cu `status='pending_validation'`. Primește un e-mail care îi explică faptul că trebuie să vină să se prezinte în persoană la bibliotecă.
3. Când vine, o persoană `librarian+` se întâlnește cu ea, verifică ce e de verificat (doctrina despre ce înseamnă „a verifica” este locală) și dă clic pe **„Validează”** pe rândul ei, în fila **Echipa** → secțiunea **Conturi în așteptare**.
4. Un câmp opțional „Notă” permite consemnarea unui context („întâlnire din 12 mai, la permanență, prezentată de Emma”).
5. Contul trece la `status='active'`. Persoana primește un e-mail de bun venit.

### Important politic

- Validarea în persoană făcută de o bibliotecă **este valabilă în toată rețeaua** bibliotecilor `network` (P7 nuanțat: suveranitatea locală privește delegările interne, dar recunoașterea reciprocă este un pact explicit).
- Ce se „verifică” la o validare în persoană **nu** este un control de identitate în sens administrativ. Este o întâlnire. Fiecare bibliotecă îi definește sensul politic. Pentru unele, înseamnă „stăm puțin de vorbă ca să ne asigurăm că persoana nu e polițist/polițistă sau fascist/fascistă”. Pentru altele, înseamnă „prezentăm biblioteca, felul în care funcționează, regulile ei”. Pentru altele încă, înseamnă doar „ne vedem în carne și oase, ca relația să fie una reală”.
- O bibliotecă poate **schimba modul** oricând (`coordenador+`). Schimbarea nu invalidează validările existente.

## 5.6. Rolul exclusiv, punct de atenție

O persoană are **un singur rol activ** pe bibliotecă (doctrină consemnată pe 20 mai 2026). O promovare **închide** rândul de rang inferior (trece la `removed`); o retrogradare reactivează treapta de dedesubt — sau direct `reader`, la alegerea persoanei. Istoricul nu se pierde: este purtat integral de rândurile inactive și de jurnalul de audit. În interfață ca și în baza de date, rolul afișat este deci **rolul**, fără ambiguitate. *(Versiunile anterioare ale acestui ghid descriau un „multi-membership” cu rânduri active cumulate: e depășit din mai 2026.)*

## 5.7. Erori și mecanisme de siguranță

Câteva cazuri pe care le întâlnim des:

**„SIGB-ul îmi spune că persoana face deja parte din echipă.”** Probabil că e adevărat. Circuitul refuză explicit o propunere care vizează un membru activ/o membră activă a echipei — sau o persoană coordenador deja în funcție, pentru o propunere de coordonare. Verifică fila **Echipa**.

**„Nu văd persoana în listă.”** Trei cazuri posibile: (a) nu are încă un cont AnarBib; (b) are un cont, dar nu e cititor/cititoare a bibliotecii tale (pentru o primire în echipă, invitația prin identificatorul public funcționează oricum; pentru un salt, trebuie să fie mai întâi cititor activ/cititoare activă); (c) e ascunsă de filtrul căutării — încearcă cu adresa ei de e-mail exactă.

**„Am depus o propunere din greșeală.”** Nimic nu s-a schimbat cât timp nu e acceptată: revoc-o din fila **Echipa** sau las-o să expire (30 de zile). Dacă a fost deja acceptată, se aplică capitolul 6 (retragere cu perioadă de așteptare sau persoana își cedează rolul).

**„Persoana nu primește e-mailul.”** Verifică întâi ortografia adresei ei de e-mail din profil și roag-o să se uite în spam. Dacă problema persistă, vorbește cu o persoană din administrarea rețelei: probabil e o problemă de configurare a e-mailului, de investigat.

## 5.8. Dacă regula te deranjează

Mai multe lucruri din acest capitol s-ar putea să nu-ți convină:

- **Principiul cooptării însuși** (P2). Crezi că orice persoană `reader` implicată ar trebui să poată trece liber la `librarian`, fără să fie nevoie de cooptare. E o dezbatere politică de fond, care atinge principiul P1. De adus pe canalul de coordonare a rețelei și probabil de discutat la o întâlnire.

- **Lipsa unei doctrine tranșate privind „când dai clic”** (§5.4). Crezi că ghidul ar trebui să recomande o singură doctrină. Sau, dimpotrivă, găsești că sugerează prea multe. Propune un amendament la acest capitol, cu argumente.

- **Modurile de validare în persoană** (§5.5). Crezi că ar trebui un al treilea („validare amânată”, „validare la distanță”, altceva). De adus în `spec-validation-physique.md`.

- **Rolul exclusiv** (§5.6). Crezi că o persoană ar trebui să poată cumula mai multe roluri active în aceeași bibliotecă (să fie în același timp `librarian` și `coordenador`, de exemplu). E o decizie de model de date, mai structurantă decât pare — și a fost deja tranșată în sens opus în mai 2026. De discutat cu persoanele care dezvoltă aplicația.

Vezi capitolul 4 pentru procedura generală de amendare și anexa C pentru modelul de notă.

\newpage

# 6. Cedarea rolului, retragerea, suspendarea

Acest capitol acoperă tranzițiile de la T3 la T8 — adică **tot ce scoate o persoană dintr-o echipă** sau o pune pe pauză. Politic, este probabil cel mai important capitol al ghidului, pentru că mecanismele de retragere sunt în miezul proiectului anarhist (cf. capitolul 1, §1.2).

## 6.1. Principiile politice

Trei principii structurează acest capitol:

> **P3 — Retrogradarea voluntară este mereu posibilă.** Orice persoană cu un rol în echipă se poate retrograda singură, oricând, fără consultare. „Îmi cedez rolul” este un drept fundamental.

> **P4 — Excluderea, încadrată de o perioadă de așteptare.** Excluderea nevoluntară a unei persoane librarian de către o persoană coordenador trece printr-o perioadă de așteptare de șapte zile înainte de a produce efecte. Această perioadă permite deliberarea colectivă și eventuala anulare de către o altă persoană coordenador.

> **P6 — Notificări sistematice.** Orice schimbare de rol declanșează un e-mail către persoana în cauză și către toată echipa de coordonare.

Ideea de fond este că nu scoatem niciodată pe cineva dintr-o echipă „prin surprindere” sau „în tăcere”. Fie persoana decide ea însăși (și efectul e imediat), fie colectivul o cere (și totul e consemnat, notificat și supus deliberării până în ultima secundă).

## 6.2. Cedarea rolului: autoretrogradarea (T3 și T4)

Este **dreptul cel mai fundamental** din sistemul de guvernanță al AnarBib. Orice persoană care exercită o funcție în echipă o poate părăsi oricând, fără nicio consultare.

### Când s-o folosești

- Nu mai ai timp să te ocupi de funcție.
- Nu te mai regăsești în deciziile echipei de coordonare.
- Nu ești de acord cu o decizie și vrei să te dezolidarizezi de ea.
- Vrei pur și simplu ca funcția să intre în rotație.
- Ai nevoie de o pauză.
- De fapt, nu trebuie să dai niciun motiv. Dreptul de a pleca este necondiționat.

### Procedura

1. Mergi la `/biblioteca`, fila **Echipa**.
2. Pe **propriul tău rând**, dă clic pe **„Îmi cedez rolul”**.
3. Alege nivelul retrogradării:
   - Dacă ești `coordenador`, poți alege „redevin librarian” (rămâi în echipă ca librarian) sau „părăsesc echipa” (redevii reader).
   - Dacă ești `librarian`, poți alege „părăsesc echipa” (redevii reader).
4. Fereastra de dialog îți amintește consecințele. Confirmă.

### Efect imediat

- Apartenența ta actuală (`librarian` sau `coordenador`) trece la `vacated` — starea rolului **părăsit voluntar**, distinctă de `inactive`, starea contului abandonat.
- Rândul tău de rang inferior (`reader` sau `librarian`, după treapta aleasă) este reactivat dacă exista — sau creat ca `active` în caz contrar.
- E-mail către toată echipa de coordonare + către tine (confirmare).
- Jurnal de audit: `action='self_demoted'`.

### Caz special: ești singura persoană coordenador activă

SIGB-ul **te lasă să pleci**, dar te avertizează:

> ⚠️ ATENȚIE: ești singura persoană coordenador activă din [bibliotecă]. Biblioteca va rămâne fără coordonare. Administratorii/administratoarele AnarBib vor fi notificați/notificate. Continui?

Dacă confirmi:
- Apartenența ta de coordonare trece la `vacated`.
- Biblioteca trece în **mod degradat**: persoanele `librarian` pot continua să gestioneze împrumuturile, să valideze înregistrările etc., dar nicio modificare a identității publice sau a configurației nu e posibilă până la cooptarea unei noi persoane în coordonare.
- E-mail către toate persoanele din administrarea rețelei: „Biblioteca X nu mai are nicio persoană coordenador. Iată persoanele librarian active: ...”

Politic, e important: SIGB-ul **nu împiedică** plecarea ta. Dar informează rețeaua, pentru ca o persoană din administrarea rețelei să poată, dacă dorești și dacă colectivul local are nevoie, să ia legătura ca să ajute la organizarea tranziției. Este rotația funcțiilor în acțiune.

### Partea tehnică

RPC: `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

*(v2 a saltului colegial — 1 septembrie 2026)* Dacă ai ajuns în coordonare prin **salt colegial** (direct de la cititor/cititoare), fereastra „Îmi cedez rolul” preselectează „părăsesc echipa”: n-ai exercitat niciodată rolul librarian, nimic nu te obligă să „cobori” într-un rol necunoscut. Alegerea rămâne complet liberă.

## 6.3. Cererea de retragere a unei persoane librarian (T5)

Când colectivul decide că o persoană trebuie să părăsească echipa, iar această persoană nu se retrogradează singură, se deschide o **cerere de retragere cu o perioadă de așteptare de șapte zile**.

### Precondiții

- Ești `coordenador+` activ/activă în bibliotecă.
- Persoana vizată are o apartenență `librarian` sau `coordenador` `active`.
- Nu ești tu persoana vizată (altfel folosește §6.2).

### Procedura

1. Mergi la `/biblioteca`, fila **Echipa**.
2. Pe rândul persoanei, dă clic pe **„Cere retragerea”**.
3. Fereastra care se deschide este **roșie și insistentă**. Ea amintește:
   - Perioada de așteptare: „Această cerere va produce efecte pe [data Z+7], dacă nu e anulată de o altă persoană coordenador.”
   - Caracterul reversibil: „Poate fi anulată de orice persoană din coordonare până la data intrării în vigoare.”
   - Caracterul colegial: „Toate persoanele active din coordonare vor fi notificate.”
4. Un câmp **„Motiv”** este obligatoriu — minimum 20 de caractere. Nicio retragere în tăcere. Motivul poate fi politic („decizia AG din 4 mai”) sau practic („plecare în alt oraș, anunțată”). Va putea fi citit de toată echipa în jurnalul de audit.
5. Confirmă.

### Efect imediat

- Apartenența trece la `pending_removal`.
- Câmpul `pending_removal_until` = `now() + 7 days`.
- Câmpul `pending_removal_requested_by` = tu.
- **Niciun acces** pentru persoană în timpul perioadei de așteptare (apartenența e înghețată ca `suspended`).
- E-mail către persoana în cauză: „Echipa de coordonare a cerut retragerea ta din echipa [bibliotecă] (preaviz până pe [data]). Această decizie ține de viața organică a colectivului [bibliotecă]; pentru orice discuție, adresează-te echipei de coordonare.”
- E-mail către toate persoanele coordenador active: cu numele tău și motivul.
- Jurnal de audit: `action='removal_requested'`, cu `actor_user_id`-ul tău și câmpul `reason`.

### Efect la Z+7 (cron automat)

Dacă cererea n-a fost nici anulată, nici scurtcircuitată:
- Apartenența trece la `removed`. Rândul de rang inferior (închis la promovare, cf. rolul exclusiv §5.6) este reactivat — sau se creează un rând `reader`: persoana părăsește echipa, nu biblioteca.
- E-mail final către persoană și către echipa de coordonare: „Retragere efectivă.”
- Jurnal de audit: `action='removal_completed'`.

### Partea tehnică

RPC: `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron: `cron_team_pending_removal_complete` (rulează zilnic).

## 6.4. Anularea unei cereri de retragere (T8)

**Mecanismul de siguranță colegial** al sistemului. Orice persoană din coordonare — nu neapărat cea care a făcut cererea — poate anula o cerere de retragere în timpul perioadei de așteptare.

### Când s-o folosești

- Discuția colectivă a dus la o altă decizie (mediere, suspendare temporară în locul retragerii etc.).
- Cererea inițială a fost făcută la nervi, iar echipa de coordonare vrea să reia lucrurile în mână, colegial.
- Persoana vizată a putut fi până la urmă contactată și situația s-a dezamorsat.

### Procedura

1. Mergi la `/biblioteca`, fila **Echipa**, secțiunea **Suspendări și preavize în curs**.
2. Pe rândul persoanei aflate în `pending_removal`, dă clic pe **„Anulează cererea”**.
3. Fereastră simplă de confirmare. Câmp „Motiv” opțional.
4. Confirmă.

### Efect imediat

- Apartenența revine la `active`.
- Câmpul `pending_removal_until` e readus la NULL.
- E-mail către persoană: „Cererea de retragere a fost anulată. Îți recapeți prerogativele.”
- E-mail către toată echipa de coordonare.
- Jurnal de audit: `action='removal_cancelled'`, cu `actor_user_id`-ul tău.

### Politic

Anularea este, în mod voit, foarte simplu de declanșat. Este un mecanism de **reechilibrare colegială**: dacă o persoană din coordonare a cerut o retragere la nervi, oricare altă persoană din coordonare poate suspenda executarea cât timp colectivul deliberează. Asta face cererile de retragere mai puțin grele (nicio dramă ireversibilă), dar și mai puțin ușuratice (oricine te poate contrazice). Acesta este rostul perioadei de așteptare.

### Partea tehnică

RPC: `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Suspendarea imediată: măsura de precauție (T6 și T7)

Suspendarea este un instrument **diferit** de cererea de retragere. Este **imediată**, fără perioadă de așteptare, și **fără durată maximă**. Nu e o excludere, e o **punere pe pauză**.

### Când s-o folosești

Cazuri-tip prevăzute de specificație:

- **Cont compromis**: avem motive să credem că parola persoanei a ajuns pe mâini străine. Suspendăm până își schimbă parola.
- **Hărțuire semnalată, urgentă**: o persoană care citește semnalează un comportament abuziv al unui membru/unei membre a echipei. Suspendăm până la investigația colectivă.
- **Comportament vădit abuziv** observat pe loc: suspendăm până se reunește echipa de coordonare.
- **Conflict în curs de mediere**: persoana e pusă pe pauză, în mod voluntar, până când medierea ajunge la un rezultat.

### Procedura

1. Mergi la `/biblioteca`, fila **Echipa**.
2. Pe rândul persoanei, dă clic pe **„Suspendă”**.
3. Fereastră cu un câmp **„Motivul suspendării” obligatoriu** (minimum 20 de caractere). Acest motiv va putea fi citit în jurnalul de audit de toată echipa activă.
4. Confirmă.

### Efect imediat

- Apartenența trece la `suspended`.
- **Niciun acces** pentru persoană. Rolul nominal se păstrează (rămâne afișată ca „librarian suspendat/suspendată”), dar nu mai poate face nimic.
- E-mail către persoana în cauză: urgent, cu motivul și — în cazul unui cont compromis — o invitație de a-și schimba parola.
- E-mail către toată echipa de coordonare.
- Jurnal de audit: `action='suspended'`, cu `actor_user_id`-ul tău și câmpul `reason`.

### Ridicarea suspendării

Când situația e rezolvată (cont din nou în siguranță, mediere încheiată, investigație finalizată etc.):

1. Fila **Echipa** → secțiunea **Suspendări și preavize în curs**.
2. Pe rândul suspendat, dă clic pe **„Ridică suspendarea”**.
3. Fereastră simplă. Câmp de motiv opțional, dar recomandat, ca să închei politic episodul.
4. Confirmă.

Efect: revenire la `active`, e-mailuri, jurnal de audit `action='unsuspended'`.

### Important: suspendare vs retragere

Distincția este crucială:

| | Suspendare (T6) | Retragere (T5) |
|---|---|---|
| Efect | Imediat | Amânat (Z+7) |
| Durată | Nedeterminată | 7 zile, apoi `removed` |
| Reversibilă prin | Ridicare explicită | Anulare în timpul perioadei de așteptare |
| Folosire tipică | Măsură de precauție | Decizie de excludere |
| Politica din spate | „Ne lăsăm timp să înțelegem” | „Am decis că această persoană pleacă” |

SIGB-ul **refuză** să treacă o apartenență de la `suspended` direct la `pending_removal` (tranziția nu e permisă de matrice). De ce: sunt două temporalități politice distincte. Ca să treci de la una la alta, trebuie mai întâi să **ridici explicit suspendarea** (revenire la `active`), apoi să ceri retragerea (`pending_removal`). Acest pas dublu e voit: obligă colectivul să consemneze explicit tranziția.

### Partea tehnică

RPC de suspendare: `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC de ridicare: `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Retrogradarea unei alte persoane `coordenador` (T3 colectiv)

Un caz ceva mai special: ce faci când echipa de coordonare vrea să **retrogradeze o persoană coordenador** care nu se retrogradează din proprie inițiativă?

Specificația de guvernanță tratează acest caz ca pe o **cerere de retragere cu perioadă de așteptare** care vizează apartenența `coordenador`. Concret, folosești aceeași procedură ca la §6.3 („Cere retragerea”), dar selectând rolul `coordenador`. Persoana trece în `pending_removal` pe apartenența ei `coordenador`; la Z+7, această apartenență trece la `removed`. Rândul ei anterior `librarian` — închis la promovare (rol exclusiv, §5.6) — este atunci reactivat: persoana „recade” la librarian. Dacă n-a avut niciodată un astfel de rând (a ajuns prin salt colegial), redevine simplu `reader`.

Este, în mod voit, același mecanism ca pentru persoanele `librarian`, cu aceleași mecanisme de siguranță. **Nicio persoană din coordonare nu are o putere specială** asupra colegilor/colegelor ei: procedura trece prin perioada de așteptare și prin colegialitate.

## 6.7. Cont abandonat: ieșire automată (T9)

SIGB-ul include un mecanism de **ieșire automată** pentru conturile care nu s-au mai conectat de mult timp.

### Pragul

SIGB-ul se uită la câmpul `last_sign_in_at`, în partea Supabase. Dacă o apartenență de echipă aparține unui cont a cărui ultimă conectare datează de mai mult de **9 luni**, contul este scos treptat:

- **Z-30 de zile** (8 luni după ultima conectare): e-mail de avertizare către persoană („apartenența ta va fi dezactivată peste 30 de zile dacă nu te conectezi”).
- **Z-7 zile**: e-mail de reamintire.
- **J = 9 luni**: trecere automată la `inactive`. E-mail final către persoană + către toată echipa de coordonare.

### De ce această regulă

E un compromis între două cerințe:

- Să nu lăsăm **să se adune la nesfârșit** apartenențe-fantomă care umflă artificial echipele.
- Să nu **alungăm** brutal o persoană care doar și-a luat o pauză și are de gând să revină.

O simplă conectare ajunge ca să reseteze contorul. Nu trebuie să faci vreo acțiune, doar să te conectezi.

### Caz special: singura persoană din coordonare abandonează

Dacă persoana scoasă automat este **singura persoană coordenador activă** din bibliotecă, cron-ul escaladează către o persoană din administrarea rețelei **înainte** de a executa ieșirea. Persoana din administrarea rețelei e notificată prin e-mail, poate lua legătura cu echipa de coordonare (dacă a mai rămas un fragment din ea) sau cu persoanele `librarian` ale bibliotecii și poate coordona tranziția.

Politic, e coerent cu ce facem când singura persoană din coordonare se retrogradează explicit (§6.2): nu blocăm ieșirea, dar alertăm rețeaua, ca să poată ajuta dacă e nevoie.

## 6.8. Câteva cazuri-limită de știut

**O persoană în `pending_removal` care cere să plece imediat.** Poate. Îi ajunge să folosească ea însăși „Îmi cedez rolul” (autoretrogradare T4). Efect: trecere imediată la `vacated`, scurtcircuitarea perioadei de așteptare. Politic, e coerent: dreptul P3 (autoretrogradarea) este necondiționat.

**O persoană în `suspended` pe care vrem s-o excludem definitiv.** Vezi §6.5 „Important: suspendare vs retragere”. Trebuie mai întâi ridicată suspendarea, apoi cerută retragerea.

**Cineva își cere propria retragere prin „Cere retragerea”.** SIGB-ul refuză cu un mesaj explicit: „Ca să părăsești echipa, folosește opțiunea «Îmi cedez rolul» (autoretrogradare).” E voit: a confunda o decizie personală cu o decizie colectivă ar încurca semantica politică.

**Încercarea de a retrograda o persoană din administrarea rețelei.** Refuzată sistematic. Rolul de administrare a rețelei poate fi modificat doar prin mecanismele specifice ale specificației admin-reseau (cf. capitolul 8). Nicio persoană din coordonarea locală nu poate destitui o persoană din administrarea rețelei.

## 6.9. Dacă regula te deranjează

**Perioada de așteptare de 7 zile ți se pare prea lungă sau prea scurtă.** De adus în `spec-gouvernance-roles.md`, §4.4 și §5.6.

**Găsești că suspendarea fără durată maximă e o ușă deschisă spre arbitrar.** E un subiect politic serios. Se poate avea în vedere adăugarea unui termen după care o suspendare trebuie transformată în retragere sau ridicată. De discutat în coordonarea rețelei, apoi de adus în specificație.

**Găsești că obligația de a da un motiv pentru suspendare e un exces de birocrație.** Sau, dimpotrivă, găsești că minimul de 20 de caractere e prea scurt. De adus în specificație.

**Găsești că ieșirea automată la 9 luni e prea rapidă sau prea lentă.** Pragul se poate parametra, dar azi e același pentru toate bibliotecile din rețea. Ar trebui făcut configurabil pentru fiecare bibliotecă? De discutat.

Vezi capitolul 4 și anexa C pentru procedura de amendare.

\newpage

# 7. Când ceva merge prost

Acest capitol tratează **situațiile excepționale**, acolo unde mecanismele obișnuite de guvernanță nu ajung sau funcționează, dar cer discernământ politic. Este și capitolul în care vorbim deschis despre **bibliotecile care nu au (sau nu mai au) o viață colectivă deliberativă**, pentru că tăcerea pe acest subiect ar face mai mult rău decât sinceritatea.

## 7.1. Bibliotecă fără adunare generală sau cu puțini oameni

Cazul e mai frecvent decât pare. O bibliotecă la început, cu două sau trei persoane. O bibliotecă al cărei colectiv s-a micșorat de la o plecare la alta. O bibliotecă a cărei adunare generală nu se mai ține de o vreme, din lipsă de oameni sau din descurajare.

SIGB-ul nu se amestecă în viața politică a unui colectiv. Dar acest ghid trebuie să spună deschis ce se schimbă când această viață colectivă e slabă.

### Ce se schimbă concret

**Cuvântul „cooptare” devine ambiguu.** La două persoane, cine pe cine cooptează? Dacă singura persoană din coordonare vrea s-o aducă pe Voltairine în echipă, decide „singură”, în sensul politic al termenului. SIGB-ul va permite asta (o persoană coordenador+ poate coopta), dar nu mai e cooperarea unui colectiv politic, e o decizie personală deghizată. Nu e nici rău, nici bine, e pur și simplu de recunoscut.

**Deliberările sunt teoretice.** O cerere de retragere cu 7 zile de așteptare, într-o bibliotecă de 2 persoane, nu are pe nimeni care s-o contrazică în afară de persoana care a făcut-o. „Mecanismul de siguranță colegial” devine o autoreflecție.

**Riscul personalizării crește.** Când o decizie nu mai e colectivă, depinde de caracterul, de disponibilitatea și de luciditatea uneia sau a două persoane. Nu e catastrofal în sine, dar e mai fragil.

### Recomandările noastre explicite

**1. Recunoaște situația.** Nu vă prefaceți că sunteți un mare colectiv deliberativ dacă sunteți două persoane. Politic, e mai sănătos să scrii „decizie luată de mine singur/singură, de validat când colectivul se va lărgi” în câmpul „Motiv” din jurnalul de audit decât să scrii „decizie AG” pentru o adunare generală care nu există.

**2. Caută dialog în afară.** Dacă ești singur/singură sau sunteți doar două persoane și trebuie luată o decizie importantă (cooptare, retragere, suspendare), fă-ți obiceiul să vorbești despre ea cu tovarăși/tovarășe din alte biblioteci ale rețelei sau cu o persoană din administrarea rețelei. Nu ca să le ceri o autorizație — nu e treaba lor să valideze deciziile interne ale bibliotecii tale —, ci ca să ai o privire critică din afară. Rețeaua Matrix a AnarBib există pentru asta.

**3. Preferă tranzițiile reversibile.** Când colectivul tău e mic, evită, dacă poți, deciziile ireversibile. O suspendare e mai reversibilă decât o retragere. O retragere trece prin 7 zile în care te poți răzgândi. O cooptare se poate anula. Ia-ți timp.

**4. Documentează ce se întâmplă.** Câmpul „Motiv” din jurnalul de audit e cel mai bun prieten al tău. Cu cât pui acolo mai mult context („cooptarea lui Voltairine, decisă de mine singur/singură, de validat la următoarea permanență”), cu atât decizia va putea fi pusă mai ușor în context mai târziu, de tine ca și de un membru nou/o membră nouă a colectivului.

**5. Dacă ești cu adevărat izolat/izolată, cere ajutor.** O bibliotecă de o singură persoană este în pericol politic. SIGB-ul detectează asta în momentul în care ultima persoană din coordonare se retrogradează (§6.2) sau abandonează (§6.7) și alertează persoanele din administrarea rețelei. Poți lua și tu inițiativa: trimite un e-mail coordonării rețelei ca să explici situația. Mai multe biblioteci din rețea au trecut prin perioade de gol și au fost ajutate să se reconstituie.

### Ce nu face ghidul

Nu oferă **nicio** procedură specială pentru bibliotecile mici. E voit. Regulile SIGB se aplică uniform — ce se schimbă sunt condițiile politice în care se aplică. A recunoaște această nuanță face parte din maturitatea politică a unei persoane din coordonare.

## 7.2. Conflict interpersonal într-o echipă de coordonare

Izbucnește un conflict între două persoane din echipă. Munca nu se mai face cum trebuie, atmosfera se degradează, persoanele care citesc simt tensiunea.

### Ce poate face SIGB-ul

Direct, nu mare lucru. SIGB-ul nu arbitrează conflictele. Dar oferă **unelte utilizabile**:

- **Suspendarea provizorie (T6)** a uneia sau a ambelor persoane, cât timp conflictul trece prin mediere. Este ceea ce specificația numește explicit „conflict în curs de mediere”, ca un caz legitim de folosire a suspendării.
- **Autoretrogradarea (T3/T4)** — dacă una dintre cele două persoane alege să ia distanță, efectul e imediat.
- **Jurnalul de audit, pe care îl poate citi toată echipa** — permite întregii echipe să vadă cine ce a făcut și împiedică manevrele opace ale unei persoane din coordonare care ar încerca să rezolve conflictul scoțând-o pe cealaltă pe furiș.

### Ce trebuie să facă colectivul

- **Mediere**. SIGB-ul nu mediază. E nevoie de o terță persoană de încredere, din afara conflictului. După caz: o altă persoană din coordonarea bibliotecii, un tovarăș/o tovarășă din altă bibliotecă, o persoană din administrarea rețelei.
- **Decizie colectivă**. Dacă medierea duce la o decizie (una dintre cele două persoane părăsește coordonarea sau se stabilește un cadru de lucru revizuit), SIGB-ul va executa această decizie prin RPC-urile obișnuite.
- **Urmă politică**. Dacă decizia este retragerea cuiva, câmpul „Motiv” ar trebui să menționeze procesul de mediere („retragere în urma medierii din ZZ/LL, decizie colectivă”), ca să nu se rescrie istoria mai târziu.

### Ce trebuie evitat

- **Folosirea unei suspendări ca armă** în conflict. Suspendarea e făcută ca să pună pe pauză, nu ca să câștigi un raport de forțe. Dacă o persoană din coordonare o suspendă pe cealaltă fără un proces de mediere, asta se vede în jurnalul de audit și e problematic politic.
- **Scurtcircuitarea perioadei de așteptare** prin manevre tehnice (suspendare, apoi „accelerare” prin alte mijloace). Totul e consemnat, iar rețeaua își va da seama.
- **Tăcerea asupra jurnalului de audit**. Toată echipa vede ce se întâmplă (P5). Dacă încerci să ascunzi conflictul, trădezi transparența colectivului.

## 7.3. Hărțuire semnalată

O persoană care citește semnalează că un membru al echipei are un comportament abuziv (hărțuire sexuală, abuz de putere, comportament rasist etc.).

### Demersul recomandat

**1. Semnalarea se ia în serios**, imediat, chiar dacă persoana care semnalează este izolată și chiar dacă persoana semnalată este „cunoscută și apreciată” de echipa de coordonare. Reflexul de a respinge semnalarea ca „probabil exagerată” este cea mai frecventă greșeală.

**2. Suspendarea imediată (T6)** a persoanei semnalate, **cu titlu preventiv**, în așteptarea investigației. Câmpul „Motiv” ar trebui să spună ceva de genul „Suspendare preventivă în urma semnalării primite pe ZZ/LL, în așteptarea unei investigații colective”. Suspendarea **nu** este o acuzație, este o punere pe pauză.

**3. Constituirea unui grup de investigație**. În afara programului. Cel puțin: tovarăși/tovarășe din afara relației directe de putere, în stare să asculte ambele părți fără părtinire. Grupul poate include tovarăși/tovarășe din alte biblioteci dacă biblioteca e mică sau dacă toate persoanele din coordonare sunt implicate în caz.

**4. Comunicarea cu persoana care a semnalat**. Are nevoie să știe că semnalarea e luată în serios și că se iau măsuri. Nu trebuie lăsată în incertitudine.

**5. Ajungerea la o decizie**. În funcție de ce scoate la iveală investigația:
   - Ridicarea suspendării (T7), dacă semnalarea nu se confirmă.
   - Retragerea definitivă (T5 cu perioadă de așteptare), dacă semnalarea se confirmă și decizia este ca persoana să plece.
   - O sancțiune intermediară (cadru de lucru revizuit, formare, îndepărtare de anumite funcții), dacă situația e mai nuanțată.

**6. Consemnarea politică**. Câmpul „Motiv” din jurnalul de audit ar trebui să reflecte decizia colectivă. Fără detalii despre victimă (GDPR), dar cu o formulare care face decizia lizibilă.

### Ce nu trebuie făcut

- **Cererea directă a retragerii**, fără suspendare prealabilă, deși situația e urgentă. Timp de 7 zile persoana semnalată și-ar păstra drepturile, ceea ce contrazice urgența unei semnalări de abuz.
- **Suspendarea pe termen nelimitat, fără decizie**, sub pretextul că „nu reușim să tranșăm”. O suspendare care durează mai multe luni fără decizie devine ea însăși o violență (față de persoana suspendată, care nu se poate apăra, și față de persoana care a semnalat, care nu primește niciun răspuns).
- **Rezolvarea în interior, fără rețea**. Dacă sunteți o bibliotecă mică și situația vă depășește, cereți ajutor administrării rețelei. Nu sunteți singuri/singure.

## 7.4. Cont compromis

O persoană din echipă are contul compromis (parolă scursă, suspiciune de acces neautorizat).

### Procedura imediată

**1. Suspendarea imediată (T6)** a contului, cu motiv explicit: „Suspiciune de compromitere, parolă probabil scursă, verificare în curs”.

**2. Comunicarea cu persoana în cauză**. Persoana primește automat un e-mail urgent care anunță suspendarea și o invită să-și schimbe parola. Persoana din coordonare care suspendă contul ar trebui să o contacteze și direct (telefon, alt canal sigur) pentru confirmare.

**3. Investigație rapidă.** Ce s-a întâmplat? A făcut contul acțiuni neobișnuite în jurnalul de audit (cooptări ciudate, modificări de configurare etc.)? Dacă da, trebuie anunțată imediat o persoană din administrarea rețelei, care să ajute la analiză.

**4. Ridicarea suspendării (T7)** odată ce:
   - Parola a fost schimbată.
   - Eventualul prejudiciu a fost constatat și reparat (anularea acțiunilor abuzive, restaurarea datelor etc.).
   - Persoana este în siguranță din punct de vedere digital.

### Politic

O suspendare pentru cont compromis **nu este o mustrare**. Este o protecție reciprocă: protejăm persoana (împiedicând să fie folosită de un atacator/o atacatoare) și biblioteca (împiedicând să se facă stricăciuni în numele ei). E-mailul către persoană ar trebui să insiste pe acest caracter **nedisciplinar**.

## 7.5. Bibliotecă fără nicio persoană activă în coordonare sau ca librarian

Scenariul catastrofă: nicio persoană activă în echipă. Asta se poate întâmpla prin ieșiri automate cumulate (toate persoanele din echipă și-au abandonat contul în același timp), prin demisie colectivă (rar, dar posibil) sau printr-o succesiune de retrageri.

### Consecințe

- Biblioteca rămâne **tehnic activă** (vizibilitatea ei și catalogul ei rămân accesibile conform RLS obișnuite).
- Dar **nicio acțiune de gestiune** nu mai poate fi făcută prin interfața obișnuită: nicio validare de înregistrare, nicio gestionare a împrumuturilor, nicio modificare a configurării.
- **E-mail urgent către administrarea rețelei**, trimis de cronul care detectează situația.

### Procedura de repornire

În afara specificației, dar iată ce se practică:

**1. Luarea legăturii** de către o persoană din administrarea rețelei cu colectivul local, pe toate canalele disponibile (contul sau conturile de cititor/cititoare care au rămas înregistrate, datele de contact externe ale bibliotecii, dacă există, rețeaua locală de cunoștințe).

**2. Verificarea politică**: mai există colectivul? Vrea să continue să existe? Dacă există membri, dar au lăsat pur și simplu baltă funcțiile tehnice, se poate reconstitui o echipă de coordonare — prin circuitul colegial, ca peste tot.

**3. Recuperarea prin circuitul colegial** *(din 1 septembrie 2026 nu mai există „cooptare în afara fluxului”: promovările directe sunt desființate, inclusiv pentru administrarea rețelei)*. Administrarea rețelei are dreptul să **depună o propunere de coordonare** la orice bibliotecă (vezi capitolul 2). Dacă mai rămâne o persoană activă cu rolul `librarian`, propunerea o poate viza. Dacă rămân doar persoane active cu rolul `reader`, calea practicabilă este **saltul colegial**: colectivul local decide să activeze setarea (`allow_direct_coordenador`), administrarea rețelei depune propunerea care vizează o persoană activă cu rolul reader, se aplică cvorumul de pornire (1 susținere când echipa e prea mică), iar persoana **acceptă**. Nimic nu se face fără colectiv: propunerea îi execută decizia, nu o înlocuiește. Acțiunea este consemnată (jurnalul de audit + `cross_library_actions_log`), iar — punct-cheie de doctrină — **informarea prealabilă a coordonării locale este obligatorie**, cu excepția cazului în care biblioteca nu mai are nicio persoană din echipă care să mai dea semn de viață, caz în care informarea trece prin persoanele active rămase cu rolul `reader` (vezi §7.6).

**4. Dacă colectivul nu mai există**: deschiderea unei discuții despre **închiderea ordonată** a bibliotecii. Ce date se păstrează, care se șterg, cum se comunică persoanelor care citesc etc. Este un flux de lucru care trebuie formalizat separat.

## 7.6. Intervenția unei persoane din administrarea rețelei într-o bibliotecă locală

Un caz pe care l-am atins deja în capitolul 2, dar care merită o dezvoltare practică în acest capitol despre situațiile excepționale.

### Doctrina rețelei

> **O intervenție a administrării rețelei într-o bibliotecă locală trebuie precedată de informarea echipei de coordonare locale în cauză, cu excepția urgențelor vitale.**

Informarea prealabilă **nu este o cerere de autorizare**. Administrarea rețelei are dreptul să acționeze (acesta e sensul dreptului transversal). Dar informarea este un semn de respect față de autonomia locală și păstrează posibilitatea unui alt aranjament.

### Ce este o „urgență vitală”

Definiția e restrictivă în mod voit. Cazuri-tip:

- **Compromitere activă**: o acțiune în curs amenință integritatea bibliotecii sau a rețelei (un cont atacator care modifică apartenențele în timp real etc.).
- **Hărțuire în curs**: un membru al echipei își folosește abuziv funcțiile chiar acum, pericolul pentru persoanele care citesc este imediat.
- **Atac împotriva platformei**: tentativă de intruziune, exfiltrare de date etc.

În afara acestor cazuri, **ne luăm timp să informăm**.

### Cum se informează

Înainte de intervenție (sau în timpul ei, dacă urgența o justifică a posteriori):

- **E-mail către echipa de coordonare locală**, care explică ce urmează să se facă, de ce și cu ce trasabilitate.
- **Mențiune în tabelul `cross_library_actions_log`**, cu un nivel de criticitate care indică natura acțiunii. Toate persoanele active din coordonarea bibliotecii primesc o notificare.
- **Disponibilitate pentru dialog**: echipa de coordonare locală trebuie să poată pune întrebări, cere precizări, ba chiar negocia un alt aranjament („lasă-ne să încercăm noi mai întâi”).

### Ce trebuie evitat

- **Intervenția tăcută**: a acționa asupra bibliotecii fără a informa echipa de coordonare. Chiar dacă tehnic totul e consemnat, politic este o încălcare a suveranității locale.
- **Folosirea dreptului transversal ca putere de supraveghere**: a merge să vezi „ce se întâmplă” într-o bibliotecă fără un motiv operațional. Dreptul transversal există pentru cazuri de întreținere sau de mediere, nu din curiozitate.
- **Impunerea de decizii politice**: o persoană din administrarea rețelei nu poate spune unei biblioteci cum să-și facă cooptările, cum să-și gestioneze conflictele interne sau ce politică de primire să aleagă. Dreptul transversal este tehnic, nu politic.

## 7.7. Dacă regula te deranjează

**Ți se pare că doctrina informării prealabile e prea laxă** (o persoană din administrarea rețelei ar putea abuza de „urgența vitală”). De discutat: e nevoie de o definiție mai strictă a urgenței? E nevoie de o a doua persoană din administrarea rețelei care să confirme urgența?

**Ți se pare că doctrina e prea strictă** (uneori e nevoie să acționăm repede, fără să explicăm totul). De discutat: trebuie distinse mai multe niveluri de intervenție, cu reguli de informare diferite în funcție de criticitate?

**Ți se pare că tăcerea despre închiderea ordonată a unei biblioteci e problematică** (§7.5). Ai dreptate. Probabil trebuie scrisă o specificație dedicată. De dus în rețea.

**Ți se pare că acest capitol lasă prea mult loc improvizației** în cazurile de hărțuire (§7.3). Probabil e adevărat. O specificație dedicată proceselor de mediere și de investigație ar putea fi benefică. De dus în rețea.

Vezi capitolul 4 și anexa C.

\newpage

# 8. Rolul de administrator/administratoare de rețea

Acest capitol se adresează în mod special persoanelor din administrarea rețelei (actuale sau viitoare) și echipelor de coordonare locale care vor să înțeleagă cum se autoorganizează rețeaua la nivelul superior. Completează și aprofundează capitolele 2 și 7.

## 8.1. O funcție politică distinctă

Înainte de toate: a fi **admin de rețea** nu înseamnă nici grad, nici consacrare, nici titlu. Este o **funcție transversală** pe care colectivul administrării rețelei o deleagă unora dintre membrii săi, pe baza unui acord unanim al persoanelor deja în funcție, și care poate fi părăsită oricând.

Proiectul politic al funcției este să **țină vie coordonarea între biblioteci**: să primească noile biblioteci care intră în rețea, să anime discuțiile despre evoluțiile tehnice și politice ale SIGB-ului, să întrețină tehnic platforma, să intervină când o bibliotecă ajunge într-un impas. Nu este o funcție de conducere. Este o funcție de animare și de serviciu.

### Ce poate face o persoană din administrarea rețelei (politic)

- Să activeze o bibliotecă nouă care a cerut să intre în rețea.
- Să anime discuțiile între biblioteci (canalul Matrix `#anarbib`, întâlnirile, listele interne de e-mail).
- Să coordoneze evoluțiile platformei (specificații, versiuni, comunicări).
- Să intervină în orice bibliotecă în caz de blocaj tehnic (drept transversal).
- Să facă mediere între două biblioteci în caz de conflict (dacă echipele de coordonare o doresc).
- Să propună sau să voteze cooptarea și retragerea colectivă a altor persoane din administrarea rețelei.

### Ce nu poate face o persoană din administrarea rețelei (politic)

- Să conducă o bibliotecă.
- Să impună o decizie politică unei biblioteci (politică de primire, mod de validare, cooptări interne etc.).
- Să îndepărteze un coordonator local/o coordonatoare locală împotriva voinței bibliotecii sale.
- Să modifice de unul singur/de una singură regulile rețelei (asta trece printr-o discuție colectivă a administrării și, ideal, a echipelor de coordonare).

## 8.2. Cooptarea în unanimitate: de ce

O persoană nu intră în administrarea rețelei cu majoritate, ci cu **unanimitatea** persoanelor deja în funcție. Regula poate surprinde — de ce nu o majoritate simplă, o majoritate calificată sau un cvorum?

Motivul politic e simplu: puterea unei persoane din administrarea rețelei este **transversală**. Poate interveni în orice bibliotecă. Trebuie deci ca **fiecare persoană activă în prezent în administrarea rețelei** să fie gata să lucreze cu noua persoană. Dacă există un singur dezacord profund, cooperarea va fi otrăvită — mai bine să nu fie impusă.

Regula are o consecință practică importantă: **veto-ul e ușor**. Ajunge un singur vot `opposed`. E voit. Preferăm ca o cooptare să nu reușească decât să lase o persoană deja aflată în administrare într-o poziție incomodă de durată.

## 8.3. Fluxul de cooptare, în detaliu

### Etapa 1 — Propunerea

O persoană activă din administrarea rețelei, din interfața `/rede/administradores` (urmează în pachetul D), apasă pe **„Propune o cooptare”**.

- Introduce identitatea persoanei propuse (o caută în baza de utilizatori AnarBib).
- Introduce o **motivație** obligatorie de **cel puțin 20 de caractere**. Această motivație poate fi citită de toate persoanele din administrare și — în caz de reușită — va fi inclusă în notificarea către persoana cooptată.
- Confirmă.

SIGB-ul:
- Creează un rând în `network_administrator_cooptation_proposals` cu `status='open'`, `expires_at = now() + 30 jours`.
- Înregistrează automat votul `favorable` al persoanei care propune.
- Trimite un e-mail militant tuturor celorlalte persoane active din administrare, invitându-le să voteze.

### Etapa 2 — Voturile

Fiecare dintre celelalte persoane active din administrare are 30 de zile ca să voteze. Trei opțiuni:

- **`favorable`**: acceptă cooptarea.
- **`opposed`**: își pune veto-ul. **Justificare obligatorie** de cel puțin 20 de caractere. Această justificare va fi comunicată persoanei propuse și persoanei care a propus, în caz de respingere.
- **`abstain`**: se abține. **Abținerea blochează**: propunerea trece doar cu unanimitatea voturilor `favorable`. O abținere neretrasă are același efect practic ca un veto, doar că poate fi transformată mai târziu în favorable, dacă persoana se răzgândește.

### Detaliu v0.3 — Dezvăluirea identității

O opțiune **„Dezvăluie-mi identitatea în caz de respingere”** este bifată implicit. Dacă votezi `opposed`, identitatea ta va fi comunicată persoanei propuse și persoanei care a propus, pe lângă justificarea ta.

Poți **debifa** această opțiune ca să rămâi anonim/anonimă. În acest caz, justificarea va fi transmisă fără numele tău („o persoană care s-a opus a ridicat: ...”).

Politic, **transparența implicită** corespunde culturii militante de asumare a pozițiilor. Dar anonimatul rămâne posibil pentru cazurile în care o opoziție ar expune persoana care se opune unui cost personal disproporționat.

### Mementouri automate

Cronul trimite mementouri persoanelor din administrare care n-au votat încă:
- **Ziua +14**: „Încă n-ai votat cooptarea lui X.”
- **Ziua +25**: „Această propunere expiră în 5 zile, ia poziție.”

### Etapa 3 — Încheierea

**Dacă cineva votează `opposed`**: propunerea trece imediat în `status='rejected'`. Persoana propusă și persoana care a propus primesc un e-mail care explică respingerea, cu justificarea (și identitatea persoanei care s-a opus, dacă a acceptat dezvăluirea).

**Dacă toate persoanele active din administrare au votat `favorable`**: propunerea trece în `status='completed'`. Un rând este inserat automat în `network_administrators` cu `status='active'` și `coopted_by_unanimity_of = ARRAY[<liste des voteurs>]`. Persoana primește un e-mail de bun venit, iar un rezumat este trimis tuturor persoanelor din administrare.

**Dacă trec 30 de zile fără să se ajungă la un consens**: propunerea trece în `status='expired'`. Nicio cooptare. Trebuie fie începută o nouă propunere, fie acceptat că rețeaua nu e pregătită să primească această persoană deocamdată.

## 8.4. Retragerea colectivă în unanimitate

**Retragerea colectivă** este oglinda cooptării: ca să retragi o persoană din administrarea rețelei împotriva voinței ei, e nevoie de unanimitatea celorlalte persoane active din administrare.

### Fluxul

1. **Propunere de retragere** din partea unei persoane active din administrarea rețelei, cu motivație obligatorie ≥ 20 de caractere.
2. **Voturile** celorlalte persoane din administrare (favorable / opposed / abstain), cu justificări în caz de `opposed`.
3. **Dacă există unanimitate `favorable`**: apartenența persoanei vizate trece în `pending_removal`, cu `pending_collective_removal_until = now() + 7 jours`.
4. **În cele 7 zile de așteptare**: persoana vizată își păstrează drepturile operaționale, dar primește un e-mail clar despre plecarea ei programată. Poate deschide, eventual, o ultimă discuție. **Nu poate anula retragerea în mod unilateral**: doar unanimitatea celorlalte persoane din administrare poate întoarce decizia (propunând o „anulare a retragerii”, flux-oglindă).
5. **În ziua +7**: trecerea la `status='removed'`, `removed_at=now()`.

### Politic

**Dublul zăvor** (unanimitate + perioadă de așteptare de 7 zile) face retragerea colectivă a unei persoane din administrarea rețelei deosebit de dificilă. E voit. Cum puterea unei persoane din administrarea rețelei este transversală, ea nu se revocă cu ușurință.

Invers, **auto-retragerea rămâne mereu posibilă și ușoară** (vezi §8.5). Aceasta e asimetria politică: e simplu să pleci, e greu să fii alungat/alungată. Asta corespunde culturii anarhiste: respectăm decizia personală de a părăsi o funcție, încadrăm strict decizia colectivă de a i-o retrage cuiva.

## 8.5. Auto-retragerea

O persoană din administrarea rețelei își poate părăsi funcțiile oricând, fără acordul celorlalte. Este un act **unilateral și necondiționat** (P3 aplicat la nivelul rețelei).

### Procedura

Din `/rede/administradores`, pe propriul rând, apasă pe **„Renunță la rolul de administrare”**. Fereastră de confirmare, motiv opțional.

### Efect

- Rândul trece în `status='inactive'` (sau `removed`, în funcție de context, de clarificat în pachetul D).
- E-mail către toate celelalte persoane active din administrare.
- Jurnal de audit `event_type='self_removal_requested'`.

### Caz special: singura persoană activă din administrare

Dacă ești singura persoană activă din administrare și vrei să pleci, SIGB-ul declanșează o **perioadă specială de așteptare de 30 de zile**. În această perioadă:
- Rămâi activ/activă în administrare, cu toate drepturile tale.
- Un e-mail urgent este trimis tuturor fostelor persoane din administrare (`status='inactive'` sau `removed`), care le anunță situația.
- Rețeaua are 30 de zile fie ca să coopteze o nouă persoană în administrare (fluxul normal de cooptare, tu fiind singura persoană care votează), fie ca să organizeze o altfel de tranziție.

În ziua +30, dacă nu s-a făcut nimic, ieși efectiv, iar rețeaua rămâne **fără nicio persoană activă în administrare**. SIGB-ul continuă să funcționeze tehnic, dar nicio acțiune de administrare (activarea unei biblioteci, cooptare etc.) nu mai e posibilă până la o intervenție manuală.

Această procedură este gândită ca să **încetinească** dizolvarea rețelei în cazul în care ultima persoană din administrare ar pleca, fără însă să **împiedice** această plecare. Libertatea de a pleca rămâne întreagă.

## 8.6. Dreptul transversal în viața de zi cu zi

**Dreptul transversal** este ceea ce deosebește politic administrarea rețelei de echipa locală: persoana din administrare poate acționa ca `coord+` în orice bibliotecă, îi poate citi catalogul (chiar dacă vizibilitatea e `private`), îi poate modifica apartenențele etc.

### Când să-l folosești

- **Activarea unei biblioteci noi**: flux normal, este primul caz de utilizare a dreptului transversal.
- **Întreținere**: o bibliotecă are o configurare stricată, un parametru greșit setat, un bug care blochează. Poți interveni ca să corectezi.
- **Blocaj politic**: biblioteca nu mai are coordonare (vezi §7.5), trebuie cooptat din nou cineva ca să repornească.
- **Mediere la cerere**: echipa de coordonare locală îți cere explicit ajutorul ca să arbitrezi un conflict sau să iei o decizie dificilă.
- **Investigație în urma unei semnalări în rețea**: o persoană care citește semnalează o problemă majoră într-o bibliotecă, iar echipa de coordonare locală nu răspunde sau face ea însăși parte din problemă.

### Când să nu-l folosești

- **Din curiozitate**: nu merge să „vezi ce se întâmplă” într-o bibliotecă fără un motiv operațional. Asta e supraveghere, nu administrare.
- **Ca să impui o decizie politică**: dacă nu ești de acord cu politica unei biblioteci (mod de validare, regulament etc.), poți discuta despre ea, dar nu o poți impune.
- **Ca să scurtcircuitezi o dezbatere colectivă**: dacă rețeaua discută o evoluție și nu ești de acord, nu-ți poți folosi dreptul transversal ca să-ți impui punctul de vedere prin fapt împlinit.

### Informare prealabilă obligatorie

Aceasta e doctrina rețelei (capitolul 2, §2.4; capitolul 7, §7.6): **orice intervenție a administrării rețelei într-o bibliotecă locală trebuie precedată de informarea echipei de coordonare locale**, cu excepția urgențelor vitale.

Concret:
- **E-mail către echipa de coordonare locală**, care explică ce se va face și de ce.
- **Așteptarea unui răspuns**, în afara urgențelor: între 24 și 72 de ore, în funcție de natura acțiunii.
- **Dacă nu vine niciun răspuns și acțiunea nu e urgentă**: revino o dată, apoi treci la acțiune, menționând explicit în jurnal că echipa de coordonare locală a fost informată, dar n-a răspuns.
- **Dacă e o urgență vitală**: acționează și trimite informarea imediat după, explicând de ce urgența a justificat acțiunea fără așteptare.

Fiecare acțiune este consemnată în `cross_library_actions_log` cu nivel de criticitate și poate fi citită ulterior de echipa de coordonare locală.

## 8.7. Cazul primului admin și al lui Xavier

Sistemul presupune cel puțin o persoană activă în administrarea rețelei pentru ca o cooptare să fie posibilă. Cum **primul admin** nu poate fi cooptat (nu există nimeni care să voteze), este prevăzută o excepție.

La 11 mai 2026, **Xavier** este înscris/înscrisă ca **admin de rețea fondator/fondatoare** printr-un INSERT direct în `network_administrators`, cu `coopted_by_unanimity_of = ARRAY[]::uuid[]` (tablou gol) și `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. Această manipulare este consemnată în jurnalul de audit cu `event_type='foundational_admin_added'` și `metadata.foundational=true`.

Această manipulare este **transparentă politic**: este documentată, explicată și publică. Nu este o slăbiciune a sistemului — este amorsarea indispensabilă. Odată pusă această temelie, orice cooptare ulterioară trece prin fluxul normal din §8.3.

Pe măsură ce vor fi cooptate noi persoane în administrare, „singurătatea” inițială se va estompa. Rețeaua își propune să aibă **mai multe persoane active în administrare** (obiectivul politic este în general un cerc de 3 până la 5 persoane, în număr impar, ca să se evite blocajele în cazul unui vot pe anumite subiecte conexe din afara specificației).

## 8.8. Dacă regula te deranjează

**Ți se pare unanimitatea prea exigentă** („nu reușim niciodată să cooptăm, un veto blochează totul”). E o dezbatere de fond despre natura colectivului administrării rețelei. Trebuie relaxată regula spre o majoritate calificată? E nevoie de un mecanism de supravot? De adus în discuția rețelei și, eventual, de formalizat într-o revizuire a specificației.

**Ți se pare unanimitatea prea laxă** („ar trebui consultate și echipele de coordonare locale înainte de a coopta o persoană în administrare”). E o altă opțiune politică: consultarea echipelor de coordonare locale înainte de cooptarea unei persoane în administrarea rețelei. De discutat. Ar lărgi cercul care decide, dar ar îngreuna procedura.

**Ți se pare perioada de așteptare de 7 zile pentru retragerea colectivă prea lungă sau prea scurtă.** De adus în specificație.

**Ți se pare doctrina informării prealabile insuficient încadrată**: ce este exact o „urgență vitală”? Ar trebui să existe o definiție canonică? De discutat.

**Ți se pare că funcția de administrare a rețelei are prea multă putere** (drept transversal prea extins) sau prea puțină (ar trebui să poată tranșa anumite conflicte). E o întrebare politică fundamentală. De discutat la întâlnirea anuală.

Vezi capitolul 4 și anexa C.

\newpage

# 9. Transparența în practică

Acest capitol tratează funcționarea concretă a **transparenței** în AnarBib: cine vede ce, cum și de ce. Este aplicarea principiului P5 (transparență maximă) și a lui P6 (notificări sistematice).

## 9.1. Principiul

> **P5 — Transparență maximă.** Jurnalul de audit al schimbărilor de rol poate fi citit de întreaga echipă activă a bibliotecii.
> **P6 — Notificări sistematice.** Orice schimbare de rol declanșează un e-mail către persoana în cauză și către întreaga echipă de coordonare.

Ideea politică: **să facem imposibile manipulările opace**. Dacă totul e consemnat și lizibil, nimeni nu poate muta în tăcere o persoană dintr-un statut în altul fără ca acest lucru să fie văzut de ceilalți membri ai echipei.

## 9.2. Cine vede ce: matrice

### La nivelul unei biblioteci

| Informație | reader | librarian | coordenador | administrarea rețelei |
|---|---|---|---|---|
| Lista echipei (roluri active) | parțială (doar numele publice) | completă | completă | completă |
| Statuturi (`suspended`, `pending_removal`) | nu | da | da | da |
| Jurnalul de audit complet al echipei | nu | da | da | da |
| Jurnalul de audit: motivele acțiunilor | nu | da | da | da |
| Cerere de retragere în curs: cine a cerut-o | nu | da | da | da |
| Datele personale ale celorlalte persoane care citesc | nu | da (din această bibliotecă) | da | da |

### La nivelul rețelei

| Informație | reader | echipa bibliotecii | administrarea rețelei |
|---|---|---|---|
| Lista persoanelor active din administrarea rețelei | da (pagina publică `/rede`) | da | da |
| Contoarele rețelei (numărul de biblioteci etc.) | da | da | da |
| Jurnalul de audit al rețelei (cooptări, retrageri din administrare) | nu | nu | da |
| Propuneri de cooptare în curs | nu | nu | da |
| Jurnale între biblioteci (acțiuni ale administrării rețelei în biblioteca X) | nu | da (din biblioteca lor) | da |

## 9.3. Jurnalul de audit al echipei în practică

Este cel mai important instrument de transparență. Poate fi consultat din `/biblioteca` → fila **Echipa** → secțiunea **Istoricul echipei**.

### Ce se vede în el

Fiecare intrare afișează:
- Data și ora.
- Acțiunea („promovat/promovată librarian”, „auto-retrogradat/auto-retrogradată”, „retragere cerută”, „suspendat/suspendată”, „reintegrat/reintegrată după suspendare”, „trecere automată la inactiv după 9 luni” etc.).
- Persoana în cauză (target).
- Autorul/autoarea acțiunii (actor) — pentru acțiunile umane. Gol pentru acțiunile automate (cron).
- Motivul (dacă a fost completat).
- Rolul și statuturile înainte/după.

### La ce folosește politic

- **Memorie colectivă**: se poate reconstitui istoria coordonării, se poate vedea cum s-a constituit și cum a evoluat.
- **Parapet împotriva opacității**: dacă o persoană din coordonare a făcut acțiuni dubioase (cooptări ciudate, suspendări nejustificate), asta e vizibil pentru toată lumea.
- **Instrument de deliberare**: în caz de dezbatere („ziseserăm că facem rotație în coordonare!”), jurnalul oferă elemente factuale.
- **Instrument de tranziție**: când vine o persoană nouă în coordonare, poate citi jurnalul ca să înțeleagă istoria recentă fără să fie nevoită să întrebe pe toată lumea.

### Ce trebuie făcut cu el

- **Să-l citești regulat**. Nu în fiecare zi, ci o dată pe lună, de exemplu la o întâlnire a echipei de coordonare.
- **Să discuți ce pare ciudat**. Dacă o acțiune ți se pare de neînțeles sau nejustificată, întreabă persoana care a făcut-o.
- **Să nu-l folosești ca armă**. Jurnalul este un instrument de transparență colectivă, nu un instrument de supraveghere interpersonală.

## 9.4. E-mailurile de notificare

Fiecare acțiune de guvernanță declanșează **unul sau mai multe e-mailuri** automate. Nu e spam: e voit, pentru că nimeni nu trebuie să fie afectat/afectată de o schimbare de rol fără să fie informat/informată.

### Cine primește ce

| Eveniment | Persoana în cauză | Persoanele active din coordonarea locală | Administrarea rețelei |
|---|---|---|---|
| Propunere depusă (primire sau coordonare) | — | ✅ de susținut | — |
| Propunere gata (cvorum atins) | ✅ de acceptat | — | — |
| Cooptare reușită (acceptare — T1, T2, T2b) | ✅ bun venit | ✅ | — |
| Auto-retrogradare (T3, T4) | ✅ confirmare | ✅ | — |
| Cerere de retragere (T5) | ✅ | ✅ | — |
| Anularea cererii (T8) | ✅ | ✅ | — |
| Sfârșitul perioadei de așteptare (ziua +7) | ✅ | ✅ | — |
| Suspendare (T6) | ✅ urgent | ✅ | — |
| Ridicarea suspendării (T7) | ✅ | ✅ | — |
| Ieșire automată la 9 luni (T9) | ✅ mementouri + final | ✅ (doar finalul) | — |
| Ultima persoană din coordonare pleacă | ✅ | ✅ (persoana în cauză) | ✅ alertă |
| Cooptare în administrarea rețelei (propunere) | — | — | ✅ |
| Cooptare în administrarea rețelei (reușită) | ✅ bun venit | — | ✅ rezumat |
| Cooptare în administrarea rețelei (respingere) | ✅ cu justificare | — | ✅ |
| Retragere colectivă din administrarea rețelei | ✅ | — | ✅ |
| Intervenție între biblioteci | — | ✅ (coordonarea bibliotecii) | ✅ (autorul/autoarea) |

Două precizări despre e-mailurile circuitului de invitare:

- **A primi pe cineva în echipă și a-i încredința coordonarea nu sunt același act**: e-mailurile unei propuneri de coordonare au propriile texte, distincte de cele ale primirii.
- **Un salt colegial se spune pe nume**: când o propunere de coordonare vizează o persoană care nu e încă membră a echipei (salt `reader` → `coordenador`, §5.3), e-mailurile de propunere și de acceptare folosesc introduceri dedicate care o spun explicit — susținerea, ca și acceptarea, se fac în cunoștință de cauză.

### Tonul e-mailurilor

E-mailurile de guvernanță urmează convențiile militante ale rețelei (vezi memoria internă): sobrietate, claritate, accesibilitate (limbă comună, fără jargon), formulare incluzivă și scriere desacralizată. Fără formule oficiale, fără semnături birocratice.

Exemplu tipic pentru o cerere de retragere:
> Salut, Karl,
>
> Echipa de coordonare a BLMF a cerut retragerea ta din echipă (rol: librarian), cu motivul: „decizia AG din 4 mai”.
>
> Acest preaviz va intra în vigoare pe **12 mai 2026** (peste 7 zile), dacă până atunci nu este anulat de o altă persoană din coordonare.
>
> În această perioadă nu mai ai acces la funcțiile de librarian. Pentru orice discuție, adresează-te echipei de coordonare a BLMF — această decizie ține de viața organică a colectivului local și nu se gestionează prin SIGB.
>
> AnarBib

Tonul urmărește să informeze factual, fără să dramatizeze și fără să minimalizeze.

### Confidențialitatea e-mailurilor — parapet anti-urmărire

E-mailurile de guvernanță, ca toate notificările SIGB-ului, sunt trimise prin **Resend**, persoana împuternicită de rețea pentru trimiterea e-mailurilor (vezi registrul activităților de prelucrare și DPA). Două garanții politice încadrează această trimitere:

- **Nicio urmărire.** Urmărirea deschiderilor și a clicurilor — care ar colecta adresa IP, localizarea, dispozitivul și clientul de e-mail al persoanei destinatare — este o opțiune **dezactivată** pe instanța AnarBib. Primirea unui e-mail de guvernanță nu lasă nicio amprentă tehnică de partea rețelei.
- **Minimizare.** Tranzitează doar datele strict necesare trimiterii (adresa de e-mail, prenumele pentru personalizare, conținutul notificării). Nu se transmite nicio dată sensibilă.

Acest parapet ține de doctrină: extinde angajamentul rețelei de a nu urmări pe nimeni până în stratul de e-mail. Este documentat în registrul activităților de prelucrare (art. 30 GDPR) și în DPA; orice schimbare a persoanei împuternicite pentru e-mail este notificată bibliotecilor membre (DPA art. 5.4).

## 9.5. Cazul notificărilor „între biblioteci”

Când o persoană din administrarea rețelei intervine într-o bibliotecă (vezi §8.6), se produc două notificări:

- **Notificarea prealabilă** (manuală): persoana din administrare trimite un e-mail echipei de coordonare locale înainte de a acționa. Format liber.
- **Notificarea automată** (de către SIGB): la executarea acțiunii, sistemul scrie în `cross_library_actions_log` cu nivel de criticitate și trimite un e-mail persoanelor active din coordonarea bibliotecii în cauză.

Această dublă notificare (manuală + automată) garantează că echipa de coordonare locală este avertizată **înainte**, politic, și **după**, tehnic. Urma tehnică poate fi citită ulterior în fila **Echipa** → secțiunea **Intervențiile rețelei** (urmează în pachetul D).

## 9.6. Limitele transparenței

Transparența AnarBib are limite, care trebuie explicitate:

**Persoanele cu rolul `reader` nu văd jurnalul de audit al echipei.** E voit (P5 vorbește despre „echipa activă”). Persoanele cu rolul `reader` nu văd cine pe cine a cooptat, cine a fost suspendat/suspendată etc. Transparența funcționează **în interiorul coordonării**, nu spre persoanele utilizatoare.

**O bibliotecă nu vede jurnalul de audit al altei biblioteci.** Suveranitate locală (P7). Schimbările de rol din biblioteca A sunt strict opace pentru biblioteca B, cu excepția canalului uman (discuție între persoanele din coordonarea celor două biblioteci).

**Jurnalul de audit al rețelei (cooptări și retrageri din administrare) nu este public.** Poate fi citit doar de persoanele din administrarea rețelei. O bibliotecă locală poate vedea lista actuală a persoanelor din administrarea rețelei (pagina `/rede`), dar nu și istoricul cooptărilor sau justificările voturilor împotrivă.

Aceste limite nu sunt ipocrizii. Ele corespund unui echilibru între **transparență** (în interiorul echipei care deliberează) și **confidențialitate** (față de persoanele utilizatoare și între perimetre). Dacă ți se pare că echilibrul e prost plasat, el poate fi amendat (capitolul 4).

## 9.7. Dacă regula te deranjează

**Crezi că persoanele `reader` ar trebui să vadă jurnalul de audit al echipei** (transparență radicală față de utilizatori/utilizatoare). Este o poziție care se poate susține, dar are consecințe (conflictele interne devin publice, viața politică a colectivului se expune). De discutat în rețea.

**Crezi, dimpotrivă, că jurnalul de audit este prea vizibil** (o persoană discretă cu rolul librarian n-ar trebui să poată „spiona” acțiunile celor din coordonare). Și asta se poate susține. Dar contrazice P5. De discutat.

**Găsești că e-mailurile sunt prea multe sau nu destul de explicite.** Conținutul este parametrizat în `mail-strings.ts` × 10 locale. Orice modificare a unui e-mail poate fi amendată ca o modificare de cod. De dus la echipa de dezvoltare.

**Crezi că jurnalul de audit al rețelei ar trebui să fie public cel puțin pentru persoanele din coordonările locale** (ca să poată vedea cine decide ce la nivelul rețelei). E o opțiune interesantă. De discutat.

Vezi capitolul 4 și anexa C.

\newpage

# 10. Cazuri concrete comentate

Ca să încheiem, șase scenarii complete. Fiecare ilustrează o combinație de mecanisme și ne lasă să vedem SIGB-ul în acțiune. Numele (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) sunt cele ale unor tovarăși și tovarășe istorice ale gândirii libertare; aici servesc drept cazuri-tip fictive.

## 10.1. Voltairine este cooptată ca librarian

> **Context.** Emma este coordenadora la BLMF. Voltairine vine de opt luni la permanențe, participă la viața bibliotecii și are clar profilul pentru a intra în echipă. Colectivul local a discutat despre asta în AG pe 4 mai și a consemnat cooptarea ei.

**Procedură.**

1. Emma se conectează pe 5 mai la 14:30. Merge în `/biblioteca`, fila **Echipa**.
2. O caută pe Voltairine în lista persoanelor `reader` ale bibliotecii (are cont AnarBib din februarie).
3. Dă clic pe **„Primește în echipă”** → alege **librarian**. Câmpul „Motiv”: „decizia AG din 04/05” (doctrina 1, așteptare strictă). Confirmă: **propunerea** este depusă.
4. Lucy (altă persoană din coordonare) primește e-mailul de susținere și **ratifică** propunerea — o a doua privire, nu o formalitate.
5. Voltairine primește un e-mail: o invitație de a intra în echipă o așteaptă în contul ei. Ea **acceptă**.

**Efect la acceptare.**

- Rândul `librarian` al lui Voltairine devine activ; rândul ei `reader` se închide (rol exclusiv, §5.6).
- Voltairine primește un e-mail de bun venit; persoanele active din coordonarea BLMF (Emma, Lucy, Piotr) primesc un e-mail informativ.
- Jurnal de audit: `promoted_to_librarian`, cu propunerea, susținerea și acceptarea trasabile.

**Comentariu.**

Cel mai simplu caz. SIGB-ul execută curat decizia colectivului, în trei timpi: Emma propune, Lucy susține, Voltairine acceptă. Nimeni n-a decis nimic de unul singur sau de una singură — iar Voltairine intră în echipă doar pentru că a **spus-o**, în aplicație ca și în AG *(reforma din 01/09/2026: înainte de această dată, promovarea era directă și imediată)*.

**Ce n-a făcut SIGB-ul:** n-a verificat că AG a avut loc cu adevărat, nici că decizia a fost luată cu adevărat. Aceste lucruri rămân **în afara aplicației**. Dacă Emma ar fi mințit despre AG, ar fi trebuit ca Lucy să susțină minciuna și ca Voltairine s-o accepte — circuitul face frauda costisitoare, nu face cultura politică inutilă.

## 10.2. Lucy predă ștafeta

> **Context.** Lucy este coordenadora la BLMF, dar nu mai poate duce sarcina în acest semestru (începe un doctorat). Vrea să „redevină librarian” ca să rămână în echipă, dar cu mai puține responsabilități.

**Procedură.**

1. Lucy merge în `/biblioteca`, fila **Echipa**.
2. Pe propriul rând (statut `coordenador`), dă clic pe **„Îmi cedez rolul”**.
3. Alegere: „redevin librarian”.
4. Fereastra de confirmare amintește că va pierde imediat permisiunile de coordonare.
5. Lucy confirmă. Motiv opțional: „început de doctorat, ușurare temporară”.

**Efect imediat.**

- Membership-ul ei `coordenador` trece la `vacated` (rol părăsit de bunăvoie).
- Rândul ei `librarian` — închis la promovarea ei în coordonare (rol exclusiv, §5.6) — este reactivat.
- Lucy primește un e-mail de confirmare: „De acum ești librarian la BLMF. Îți păstrezi permisiunile operaționale.”
- Toată echipa de coordonare (Emma, Piotr) primește un e-mail: „Lucy P. a predat ștafeta, nu mai este coordenadora. Rămâne librarian în echipă.”
- Jurnal de audit: `2026-05-05 18:42 — Lucy P. s-a auto-retrogradat coordenador → librarian (motiv: început de doctorat, ușurare temporară)`.

**Comentariu.**

Este folosirea exemplară a dreptului P3. Lucy n-a trebuit să ceară voie nimănui. Auto-retrogradarea ei este imediată. Continuă să contribuie la bibliotecă, dar cu o intensitate potrivită disponibilității ei de acum.

**Politic**: este exact genul de rotație pe care încercăm s-o favorizăm. N-o pierdem pe Lucy, doar ia un alt rol. Peste șase luni sau un an, dacă vrea să reia coordonarea, colectivul o va putea coopta din nou (T2). Nicio decizie nu e definitivă.

## 10.3. Karl trebuie să plece

> **Context.** Karl este librarian la BLMF. Comportamentul lui față de unii cititori și unele cititoare a fost o problemă (paternalism, remarci deplasate). Colectivul a discutat despre asta în AG pe 4 mai și a decis că trebuie să părăsească echipa.

**Procedură.**

1. Piotr (din coordonare) — ales de AG ca să execute decizia — merge în `/biblioteca`, fila **Echipa**.
2. Pe rândul lui Karl, dă clic pe **„Cere retragerea”**.
3. Fereastră roșie, cu termenul de 7 zile explicit.
4. Motiv obligatoriu: „În urma AG din 04/05, comportament inadecvat față de mai mulți cititori/cititoare, semnalat timp de mai multe luni, decizie colectivă de excludere.”
5. Confirmare explicită: „Înțeleg că această cerere va intra în vigoare pe 12 mai 2026, dacă nu este anulată de o altă persoană din coordonare.”

**Efect imediat.**

- Membership-ul lui Karl trece la `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl pierde imediat accesul** la toate funcțiile de librarian (membership-ul este înghețat).
- Karl primește un e-mail:
  > „Salut, Karl, echipa de coordonare a BLMF a cerut retragerea ta din echipă (rol: librarian), cu motivul: "În urma AG din 04/05, comportament inadecvat față de mai mulți cititori/cititoare, semnalat timp de mai multe luni, decizie colectivă de excludere." Acest preaviz va intra în vigoare pe 12 mai 2026 (peste 7 zile), dacă nu este anulat până atunci de o altă persoană din coordonare. Pentru orice discuție, adresează-te echipei de coordonare a BLMF.”
- Emma și Lucy (celelalte persoane din coordonare) primesc e-mailul informativ.
- Jurnal de audit: `2026-05-05 — Piotr K. a cerut retragerea lui Karl M. (rol: librarian, motiv: ...)`.

**Evoluție.**

- 6 mai, la 9:00: Lucy citește e-mailul. E de acord cu decizia și nu intervine.
- 7 mai: Emma are un schimb cu Karl (care îi scrie ca să se explice). Emma conchide că decizia rămâne în picioare. Nu intervine.
- 8-11 mai: nimic.
- **12 mai, la 00:00**: cronul `cron_team_pending_removal_complete` rulează. Karl trece la `removed`; rândul lui `reader` este reactivat (părăsește echipa, nu biblioteca).
- E-mail final către Karl și către echipa de coordonare.
- Jurnal de audit: `2026-05-12 — trecere automată la inactiv (motiv: pending_removal expirat, cron) — actor: NULL`.

**Comentariu.**

Este cazul excluderii colective. Trei elemente politice de reținut:

- **Perioada de așteptare a funcționat ca o posibilă plasă de siguranță**, fără să fie folosită. Lucy și Emma ar fi putut anula; n-au făcut-o. Faptul că nimeni n-a anulat este el însuși o **deliberare implicită**.
- **Karl a rămas informat**, fără surprize. Nicio excludere tăcută.
- **Jurnalul de audit poate fi citit** de toată echipa și permite revenirea asupra acestei decizii dacă, mai târziu, cineva se întreabă de ce a plecat Karl.

**Delicat din punct de vedere politic**: motivul scris în câmpul „Motiv” poate fi citit de toată echipa. N-ar trebui să conțină detalii despre victime (GDPR, demnitate), dar ar trebui să fie destul de clar ca decizia să poată fi apărată politic. Găsirea dozajului potrivit ține de priceperea celor din coordonare.

## 10.4. Cont compromis: suspendare imediată

> **Context.** Pe 5 mai la 19:30, Emma observă în jurnalele de activitate că Friedrich (librarian) a făcut 47 de modificări de fișe de catalog în 3 minute, dintre care mai multe aberante (cărți marcate „dispărute” deși sunt pe raft etc.). Tiparul seamănă cu un acces neautorizat.

**Procedură.**

1. Emma merge în `/biblioteca`, fila **Echipa**.
2. Pe rândul lui Friedrich, dă clic pe **„Suspendă”**.
3. Fereastră cu motiv **obligatoriu** (≥ 20 de caractere).
4. Emma scrie: „Suspiciune de cont compromis, activitate anormală (47 de modificări de catalog în 3 min), verificare în curs.”
5. Confirmă.

**Efect imediat (19:32).**

- Friedrich trece la `status='suspended'`.
- **Niciun acces** pentru Friedrich.
- Friedrich primește un e-mail urgent: „Contul tău AnarBib a fost suspendat cu titlu preventiv la BLMF. Motiv: suspiciune de compromitere a contului tău. Îți sugerăm insistent să-ți **schimbi parola imediat**. După ce ți-ai securizat contul, contactează echipa de coordonare a BLMF ca suspendarea să fie ridicată.”
- Echipa de coordonare (Lucy, Piotr) primește un e-mail.
- Jurnal de audit: `2026-05-05 19:32 — Emma G. l-a suspendat pe Friedrich E. (rol: librarian, motiv: ...)`.

**Evoluție.**

- **19:35**: Emma îl sună pe Friedrich (canal din afara SIGB). Friedrich confirmă că n-a făcut acele acțiuni. Își lăsase calculatorul deschis într-un spațiu comun.
- **19:40**: Friedrich își schimbă parola prin procedura de resetare.
- **20:00**: Emma verifică acțiunile suspecte în jurnalul de audit al bibliotecii (auditul catalogului, nu auditul echipei). Identifică cele 47 de modificări. Le anulează manual sau cere un rollback unei persoane din administrarea rețelei, dacă e nevoie.
- **20:15**: Emma revine în fila Echipa și ridică suspendarea lui Friedrich.
- Friedrich primește un e-mail de confirmare. Jurnal de audit: `2026-05-05 20:15 — Emma G. a ridicat suspendarea lui Friedrich E.`.

**Comentariu.**

Caz tipic în care suspendarea este folosită ca **măsură preventivă**, nu ca excludere. Friedrich nu e vinovat — contul lui a fost compromis. Suspendarea a durat 43 de minute, cât a fost nevoie pentru securizare.

**Important din punct de vedere politic**: Friedrich n-a fost „acuzat”. E-mailul o spune limpede („cu titlu preventiv”). Când situația e rezolvată, suspendarea este ridicată, iar episodul rămâne consemnat în jurnal ca un incident, nu ca o mustrare.

## 10.5. Errico este ultimul coordonator și vrea să plece

> **Context.** BLMF mai are o singură persoană activă în coordonare: Errico. Lucy a predat ștafeta, Emma s-a mutat și nu mai este activă. Piotr s-a retrogradat la începutul anului. Errico trebuie să plece (se mută în străinătate, nu mai are timp).

**Procedură.**

1. Errico merge în `/biblioteca`, fila **Echipa**, dă clic pe **„Îmi cedez rolul”**.
2. Se deschide o fereastră **specială**:
   > ⚠️ **ATENȚIE**: ești singura persoană activă din coordonarea BLMF. Biblioteca va rămâne fără coordonare. Persoanele din administrarea rețelei AnarBib vor fi notificate. BLMF va putea continua să funcționeze (persoanele cu rolul librarian rămân operaționale), dar nicio modificare a configurației nu va fi posibilă până la cooptarea unei noi persoane în coordonare. Continui?
3. Errico confirmă. Motiv: „Mă mut în străinătate, nu mai am disponibilitate pentru coordonare.”

**Efect imediat.**

- Membership-ul coordenador al lui Errico trece la `vacated`.
- E-mail către Errico (confirmare).
- E-mail către toată echipa de coordonare a BLMF — dar nu mai e nimeni în ea, așa că, în practică, persoanele `librarian` active rămase primesc o notificare.
- **E-mail urgent către administrarea rețelei**: „BLMF nu mai are nicio persoană activă în coordonare. Iată persoanele librarian active rămase: Voltairine d.C., Friedrich E., ...”
- Jurnal de audit: `2026-05-05 — Errico M. s-a auto-retrogradat coordenador → reader (motiv: ..., warning: last_coordinator_leaving)`.

**Evoluție în afara aplicației.**

- 6 mai: Xavier (administrator de rețea) ia legătura cu Voltairine și Friedrich, persoanele `librarian` active rămase. Amândoi confirmă că colectivul BLMF încă există și că vor să continue.
- 7-15 mai: discuție internă a colectivului BLMF, care decide în AG s-o coopteze pe Voltairine în rolul de coordenadora.
- 16 mai: Xavier, în virtutea dreptului său transversal (nu mai e nimeni în coordonarea BLMF care s-o facă), **depune propunerea de coordonare** care o vizează pe Voltairine — librarian activă, condiția prealabilă T2 este îndeplinită. Friedrich **susține**, Voltairine **acceptă**: chiar și la o recuperare făcută de administrarea rețelei, circuitul colegial se aplică integral — Xavier nu poate „fabrica” singur o coordenadora. **Informare prealabilă obligatorie**: Xavier le-a scris lui Friedrich și lui Voltairine cu 2 zile înainte, ca să anunțe depunerea. Acțiunea este consemnată în `cross_library_actions_log` cu nivelul de criticitate „ridicat” (modificarea coordonării unei biblioteci de către administrarea rețelei).

**Comentariu.**

Caz delicat din punct de vedere politic: biblioteca trece printr-o perioadă de fragilitate (între 5 și 16 mai, nu are coordonare). Dar SIGB-ul **n-a împiedicat** plecarea lui Errico — dreptul lui P3 este necondiționat. SIGB-ul doar **a alertat rețeaua**, ca aceasta să poată ajuta.

Intervenția lui Xavier ilustrează folosirea **corectă** a dreptului transversal: a fost solicitat (implicit, prin alerta automată), a respectat informarea prealabilă, și-a consemnat acțiunea. N-a impus-o pe Voltairine; colectivul BLMF a ales-o. Xavier doar a **executat tehnic** decizia.

## 10.6. O cooptare în administrarea rețelei care nu se concretizează

> **Context.** Xavier este administrator de rețea fondator. Cu timpul, Maria, Patricia și Diego au fost cooptați/cooptate în administrarea rețelei, pe măsură ce rețeaua s-a extins. La 20 mai 2026, colectivul administrării este: Xavier, Maria, Patricia, Diego (patru persoane active în administrare).
>
> Maria propune cooptarea lui Mohammed, pe care îl cunoaște dintr-o bibliotecă italiană care intră în rețea.

**Procedură.**

1. Maria, din `/rede/administradores`, dă clic pe **„Propune o cooptare”**.
2. Introduce identitatea lui Mohammed (cont AnarBib creat cu două săptămâni înainte).
3. Motivație: „Mohammed coordonează BLA (Bologna), o bibliotecă ce intră în rețea luna aceasta. El a purtat integrarea politică a BLA în AnarBib și este foarte implicat în coordonarea italiană. Cooptarea lui în administrarea rețelei va întări diversitatea geografică a colectivului și va ușura animarea pe partea italiană.”
4. Confirmă.

**Efect imediat.**

- Propunere creată, `status='open'`, `expires_at = 19 iunie 2026`.
- Votul automat `favorable` al Mariei este înregistrat.
- E-mailuri către Xavier, Patricia, Diego cu propunerea.

**Evoluție.**

- 22 mai: **Diego** votează `favorable`. Fără justificare (opțională pentru favorable).
- 25 mai: **Patricia** votează `opposed`. Justificare: „Mohammed nu are nicio vechime în rețea. Cooptarea lui merge mai repede decât cea a BLA, care n-a avut încă ocazia să funcționeze destul timp ca bibliotecă AnarBib. Propun să așteptăm 6 luni, ca BLA să-și găsească ritmul, și să-l propunem din nou pe Mohammed atunci.” Patricia bifează „Dezvăluie-mi identitatea”.

**Efectul imediat al votului opposed.**

- Propunerea trece la `status='rejected'`.
- E-mail către Mohammed: „Bună, Mohammed, propunerea de a te coopta în administrarea rețelei AnarBib nu a reușit. Patricia X. a ridicat următoarea obiecție: "[justificarea completă]". Poți discuta cu ea sau cu Maria, care te propusese. Cooptarea va putea fi propusă din nou mai târziu.”
- E-mail către Maria (cea care a propus): rezumat cu justificarea Patriciei.
- E-mail către Xavier și Diego: informare că propunerea a fost respinsă, cu justificarea.
- Jurnal de audit al rețelei: `2026-05-25 — cooptare respinsă: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Comentariu.**

Caz care ilustrează unanimitatea **în acțiune**. Patricia are drept de veto, îl folosește, iar justificarea ei e explicită și constructivă („să așteptăm 6 luni”). A ales să-și dezvăluie identitatea, ceea ce le permite lui Mohammed și Mariei să discute direct cu ea, în loc să speculeze despre persoana anonimă care s-a opus.

**Politic**: cooptarea în unanimitate nu este o garanție de blocaj permanent. Patricia nu spune „niciodată”, ci „nu acum”. Dacă peste 6 luni BLA este bine integrată și Patricia se răzgândește, o nouă propunere va putea reuși. Această **reversibilitate în timp** face unanimitatea suportabilă.

Alternativa — cooptarea lui Mohammed cu majoritate, împotriva părerii Patriciei — ar fi creat un cerc al administrării în care Patricia s-ar fi simțit pusă într-o poziție falsă. Mai bine să așteptăm.

\newpage

# Anexe

\newpage

# Anexa A — Glosar

**AG** — Adunare generală. Reuniune colectivă de luare a deciziilor într-o bibliotecă. SIGB-ul nu modelează AG (P8). Forma ei (cvorum, frecvență, mod de deliberare) este decisă în întregime de fiecare bibliotecă.

**Jurnal de audit** — Jurnalul acțiunilor de guvernanță, stocat în `library_membership_audit` (la nivelul unei biblioteci) și `network_administrator_audit` (la nivelul rețelei). Poate fi citit de echipa activă (la nivel de bibliotecă) și de administrarea rețelei (la nivel de rețea).

**Auto-retrogradare** — Acțiune prin care o persoană din echipă se retrogradează singură la un rol inferior. Dreptul P3, necondiționat.

**Bibliotecă `private`** — Bibliotecă al cărei catalog este vizibil doar pentru persoanele înscrise în ea. Mod potrivit pentru bibliotecile expuse politic.

**Bibliotecă `network`** — Bibliotecă al cărei catalog este vizibil pentru toate persoanele `reader` validate din rețeaua AnarBib. Mod implicit pentru majoritatea bibliotecilor.

**Bibliotecă `public`** — Bibliotecă al cărei catalog este vizibil pentru oricine, inclusiv pentru persoanele care vizitează anonim.

**Perioadă de așteptare** — Termen impus între o decizie și efectul ei. Șapte zile pentru retragerile colective din echipa locală și din administrarea rețelei. Treizeci de zile pentru auto-retragerea singurei persoane active din administrarea rețelei.

**Cooptare** — Mecanism de intrare într-o echipă (echipa locală) sau în colectivul administrării rețelei. Pentru echipa locală: decizia unei persoane din coordonare (coord+). Pentru rețea: unanimitatea persoanelor active din administrare.

**Cross-biblioteci** — Califică o acțiune efectuată de o persoană din administrarea rețelei într-o bibliotecă în a cărei echipă locală nu se află. Consemnată în `cross_library_actions_log`.

**Cron** — Sarcină automată executată periodic de SIGB. Fără actor uman. Exemple: `cron_team_pending_removal_complete` (trecerea de la `pending_removal` la `removed` la Z+7), `cron_team_inactive_cleanup` (ieșire automată la 9 luni).

**Delegare** — Act prin care un colectiv încredințează temporar o funcție uneia dintre persoanele care îl alcătuiesc, păstrând posibilitatea de a o relua. Concept central, deosebit de „ierarhie”.

**Membership** — Rând din tabelul `user_library_memberships` care exprimă legătura unei persoane cu o bibliotecă într-un rol dat. O persoană poate avea mai multe rânduri într-o bibliotecă (istoria ei), dar **unul singur activ** odată (rol exclusiv, cf. §5.6).

**Multi-membership** — Posibilitatea de a avea mai multe rânduri de membership pentru aceeași persoană în aceeași bibliotecă, cu roluri diferite.

**Rețea** — Colectivul bibliotecilor care se recunosc reciproc și împart platforma AnarBib. Nu o organizație centrală, ci o federație.

**RPC** — *Remote Procedure Call*. Funcție SQL apelată de interfața de utilizare pentru a executa o acțiune. Toate acțiunile de guvernanță trec prin RPC-uri numite `fn_team_*` (echipa locală) sau `fn_network_admin_*` (rețea).

**Suveranitate locală** — Principiul P7, potrivit căruia fiecare bibliotecă este suverană asupra delegărilor ei interne. Schimbările de rol într-o bibliotecă nu afectează nimic în alta.

**Spec** — Document de specificație (`spec-*.md`) care descrie în detaliu funcționarea unei funcționalități a SIGB. Sursă de adevăr tehnic și politic. Versionat, datat, amendabil.

**Unanimitate** — Modalitatea de cooptare și de retragere colectivă în administrarea rețelei. Toate voturile trebuie să fie `favorable`; un singur `opposed` sau o abținere neridicată blochează.

**Validare în persoană** — Procedură prin care o persoană librarian+ validează un cont `reader` după o întâlnire fizică. Valabilă pentru toată rețeaua (pact de recunoaștere reciprocă).

**Veto** — Vot `opposed` la o cooptare sau la o retragere colectivă din administrarea rețelei. Efect imediat: respingerea propunerii. Justificare obligatorie de cel puțin 20 de caractere.

\newpage

# Anexa B — Indexul funcțiilor tehnice

Această anexă dă, pentru fiecare RPC menționată în ghid, traducerea ei politică și tranziția în cauză. Servește drept referință rapidă.

## Funcțiile echipei locale

| RPC SQL | Tranziție | Traducere politică |
|---|---|---|
| `fn_team_propose_invitation` | T1, T2, T2b | Depunerea unei propuneri (primire sau coordonare) |
| `fn_team_ratify_invitation` | T1, T2, T2b | Susținerea unei propuneri (cvorum) |
| `fn_team_accept_invitation` | T1, T2, T2b | Acceptarea sarcinii — acest gest promovează |
| `fn_team_decline_invitation` | T1, T2, T2b | Refuzul sarcinii (nu costă nimic) |
| `fn_team_revoke_invitation` | T1, T2, T2b | Revocarea unei propuneri depuse din greșeală |
| `fn_team_expire_invitations` | T1, T2, T2b | Cron: expirarea propunerilor (30 de zile) |
| `fn_team_self_demote` | T3, T4 | Auto-retrogradare („predau ștafeta”) |
| `fn_team_request_remove_member` | T5 | Cerere de retragere cu perioadă de așteptare de 7 zile |
| `fn_team_cancel_remove_member` | T8 | Anularea unei cereri de retragere |
| `fn_team_suspend_member` | T6 | Suspendare imediată (măsură preventivă) |
| `fn_team_unsuspend_member` | T7 | Ridicarea suspendării |
| `fn_validate_physical_account` | — | Validarea în persoană a unei persoane `reader` |
| `cron_team_pending_removal_complete` | T5 (continuare) | Cron: trecere la `removed` la Z+7 |
| `cron_team_inactive_cleanup` | T9 | Cron: ieșire automată la 9 luni |

*Vechile promovări directe `fn_team_promote_to_librarian` și `fn_team_promote_to_coordenador` sunt **condamnate** (26/08 și 01/09/2026): refuză cu `collegiality_required`, indicând drumul în trei timpi. Mai figurează aici doar pentru ca numele lor, întâlnit într-un document vechi, să nu lase impresia unui drum activ.*

## Funcțiile administrării rețelei

| RPC SQL | Etapă | Traducere politică |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Cooptare: propunere | O persoană din administrare propune o persoană nouă |
| `fn_network_admin_vote_cooptation` | Cooptare: vot | Vot favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Auto-retragere | Renunțarea la funcțiile din administrarea rețelei |
| `fn_network_admin_request_removal` | Retragere colectivă | Flux în oglindă cu cel al cooptării |

## Helpere de autorizare (folosite de RLS)

| Helper SQL | Sens politic |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | Poate această persoană să acționeze ca echipă în această bibliotecă? (membră activă a echipei locale SAU persoană din administrarea rețelei) |
| `user_can_engage_library(library_id)` | Poate această persoană să angajeze politic această bibliotecă? (persoană activă din coordonarea locală SAU din administrarea rețelei) |
| `fn_caller_is_network_admin()` | Este persoana care apelează activă în administrarea rețelei? |
| `fn_library_visible_to_caller(library_id)` | Este catalogul acestei biblioteci vizibil pentru persoana care apelează? |

## Tabele principale

| Tabel | Sens politic |
|---|---|
| `user_library_memberships` | Delegările locale (cine face parte din echipa cărei biblioteci) |
| `network_administrators` | Administratorii/administratoarele rețelei |
| `library_membership_audit` | Jurnalul acțiunilor de guvernanță locală |
| `network_administrator_audit` | Jurnalul acțiunilor de guvernanță a rețelei |
| `network_administrator_cooptation_proposals` | Propuneri de cooptare în curs |
| `network_administrator_cooptation_votes` | Voturile individuale ale persoanelor din administrare |
| `cross_library_actions_log` | Urma acțiunilor administrării rețelei în biblioteci |

\newpage

# Anexa C — Model de notă de amendament

Când vrei să propui un amendament la o regulă a SIGB sau la acest ghid, iată un model de notă care să-ți structureze propunerea. Format liber, îl poți adapta.

---

## Propunere de amendament la [numele spec-ului sau al ghidului]

**Autori/autoare:** [prenume / pseudonime]
**Data:** [ZZ/LL/AAAA]
**Perimetru:** [bibliotecă locală / rețea / fundamente]

### 1. Regula vizată

Citează textual regula sau paragraful de amendat, cu trimiterea la el în spec-ul sursă.

> *Exemplu:* „`spec-gouvernance-roles.md`, §5.6, T5: Perioada de așteptare înainte de excluderea efectivă este de 7 zile.”

### 2. Problema identificată

Descrie în câteva fraze ce pune probleme în regula actuală. Dacă se poate, cu un caz concret întâlnit.

> *Exemplu:* „În practică, 7 zile sunt prea puține când următoarea AG a bibliotecii are loc peste 15 zile. O decizie de retragere luată la cald nu are uneori timp să fie discutată colectiv înainte de efectul automat.”

### 3. Amendamentul propus

Descrie modificarea dorită, pe cât posibil cu o formulare gata de integrat în spec.

> *Exemplu:* „Trecerea perioadei de așteptare de la 7 la 14 zile, SAU o perioadă configurabilă pe bibliotecă (între 7 și 30 de zile), cu valoarea implicită de 14 zile.”

### 4. Consecințe tehnice anticipate

Dacă ai o idee despre ce implică asta în cod, spune-o. Dacă nu, spune și asta („nu știu, de văzut cu echipa de dezvoltare”).

> *Exemplu:* „Modificarea valorii fixe din codul SQL al `fn_team_request_remove_member` și `cron_team_pending_removal_complete`. Dacă e configurabilă pe bibliotecă, adăugarea unei coloane în `libraries`.”

### 5. Consecințe politice anticipate

Descrie ce se schimbă în practica colectivă și eventualele efecte secundare.

> *Exemplu:* „Mai mult timp pentru deliberare, dar și mai mult timp în care persoana aflată în `pending_removal` rămâne suspendată (fără acces). Poate fi perceput ca mai greoi.”

### 6. Alternative luate în calcul

Menționează celelalte piste la care te-ai gândit și de ce le înlături (sau nu).

> *Exemplu:* „Alternativă: păstrarea termenului de 7 zile, dar cu posibilitatea unei "prelungiri explicite" de către o altă persoană din coordonare. Mai complicat de implementat și de înțeles. Preferabil să se modifice valoarea implicită.”

### 7. Discuția dorită

Unde și cum vrei să fie discutată propunerea?

> *Exemplu:* „Discuție pe canalul Matrix `#anarbib`, apoi, dacă există consens, integrare în spec la următorul pachet de guvernanță.”

---

Odată redactată, pune nota în circulație potrivit perimetrului (cf. capitolul 4, §4.2).

\newpage

# Anexa D — Spec-uri sursă și referințe

Acest ghid se sprijină pe următoarele documente, care pot fi consultate în depozitul proiectului:

## Spec-uri principale

**`spec-gouvernance-roles.md`** — Spec-ul fondator al guvernanței rolurilor din echipa locală. Versiunea 1.0 din 5 mai 2026. 1231 de rânduri. Detaliază cele 4 roluri, cele 5 statusuri, cele 9 tranziții, jurnalul de audit, notificările, interfața și 15 cazuri de utilizare de referință.

**`spec-administrateur-reseau.md`** — Separarea dintre echipa locală și administrarea rețelei. Versiunea 0.3 din 11 mai 2026. 975 de rânduri. Detaliază tabelul `network_administrators`, cooptarea în unanimitate, retragerea colectivă, dreptul transversal, semantica contoarelor „pagină = perimetru”.

**`spec-validation-physique.md`** — Modurile de primire a conturilor de cititori/cititoare (`open` vs `manual_validation`). Încadrat pe 3 mai 2026. Detaliază stările contului, schema DB, fluxurile.

**`spec-refactor-v3-semantique.md`** — Refactorizarea semanticii fluxului de rezervare. Nu e central pentru guvernanță, dar e citat în treacăt pentru coerența de ansamblu a SIGB.

## Spec-uri înrudite menționate (de redactat sau în lucru)

- `spec-migration-compte.md` — Migrarea unui cont de la o bibliotecă la alta. 940 de rânduri, încadrat pe 3 mai 2026.
- `spec-invitation-equipe.md` — Flux de invitație prin e-mail pentru persoanele fără cont AnarBib. De redactat.
- `spec-fermeture-biblio.md` — Procedura de închidere ordonată a unei biblioteci. De redactat.
- `spec-mediation-conflits.md` — Cadru formalizat de mediere și investigare în urma unei semnalări. De redactat (sugerat de ghidul de față).

## Pentru mai multe

Spec-urile și codul sursă se află în depozitul Codeberg al proiectului, cu oglindă pe GitHub. Discuția tehnică și politică are loc pe canalul Matrix `#anarbib` al rețelei.

Pentru orice propunere de amendament la acest ghid sau la spec-uri, vezi capitolul 4 și anexa C.

---

*Sfârșitul ghidului. Versiunea 1.0, 11 mai 2026.*

*Acest ghid poate fi el însuși amendat. Dacă găsești că spune ceva greșit, că a uitat un caz sau că ia o poziție care nu mai corespunde doctrinei rețelei, spune-o.*
