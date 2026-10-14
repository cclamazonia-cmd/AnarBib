# Tezaurul FICEDL în AnarBib — consultarea unui vocabular comun

> **Pentru cine?** Pentru orice tovarăș/tovarășă care catalogează și vrea să-și lege cărțile de
> **vocabularul de subiecte comun** al mișcării — cel întreținut de FICEDL. Acest
> ghid explică ce este acest tezaur, în ce condiții se conectează AnarBib la el,
> la ce folosește și cum să-l folosești zi de zi.
>
> **Spirit.** AnarBib **consultă** tezaurul; nu și-l însușește. Vocabularul
> rămâne al FICEDL, care este sursa lui **de referință**. Nimic
> de aici nu creează o versiune concurentă: copia noastră nu este decât o *reflectare* fidelă.

---

## Ce este tezaurul FICEDL?

**FICEDL** — Federația internațională a centrelor de studii și documentare
libertare — reunește din 1979 CIRA, ateneuri, CCL și biblioteci
anarhiste din întreaga lume. Ea întreține un **tezaur**: un *vocabular
controlat* al documentației libertare — o listă sistematică de **termeni de subiect**
(subiectele), organizați și traduși, ca să descrie despre ce *vorbesc* documentele. El
acoperă aceleași **zece limbi** ca AnarBib (exact cele pe care le oferă CIRA din
Lausanne) și reunește câteva sute de termeni (în jur de șase sute). Poate fi
consultat public la `thesaurus.ficedl.info`.

Un tezaur nu este un simplu dicționar: este un **graf de concepte**. Termenii
sunt legați între ei (mai larg · mai restrâns · asociat) și poartă **note
de aplicare** care spun cum să fie folosiți. AnarBib se sprijină pe **SKOS**,
standardul liber al web-ului semantic pentru acest tip de vocabular.

## În ce condiții a intrat în AnarBib

Adoptarea unui vocabular comun este mai întâi o **decizie politică** — a unor
colective care aleg să vorbească aceeași limbă documentară — iar tehnica se
conformează ei. Concret, AnarBib a preluat tezaurul **de pe site-ul FICEDL**
(`thesaurus.ficedl.info`) **în jurul datei de 24 iunie 2026**, importând **termenii** și
**locurile** (intrările geografice) — și lăsând deoparte **datele** (intrările
cronologice). Această conectare urmează câteva **principii clare**, care sunt
*bazele acordului*:

1. **O singură sursă canonică.** Tezaurul care *face autoritate* este cel al FICEDL.
   AnarBib nu deține *tezaurul*: ține doar o copie de lucru a lui.
2. **Fără fork.** Copia noastră este o **reflectare** a versiunii FICEDL, niciodată o
   versiune rivală. Interoperabilitatea pe care o dorește FICEDL este astfel
   garantată *prin construcție*.
3. **Consultăm, nu modificăm.** AnarBib **nu se atinge** de cuvintele alese de
   FICEDL. O singură libertate, și doar de partea noastră: **să pună la locul ei o
   etichetă de limbă așezată greșit** (o traducere clasată sub un cod de
   limbă greșit), numai ca să nu se *piardă* o traducere care există deja — fără
   să schimbe vreodată termenul însuși.
4. **Semnalăm, nu corectăm.** Orice altă anomalie — o limbă lipsă, o
   greșeală de tipar într-un termen — **nu** este rectificată la noi: este **semnalată**
   către FICEDL, care își corectează *propria* versiune de referință.
5. **Resincronizare.** După corecturile FICEDL, AnarBib
   **își resincronizează** copia. Reflectarea se actualizează; nu se îndepărtează niciodată.
6. **Vocabular liber și comun.** Tezaurul poate fi **partajat liber** (niciun
   drept de proprietate nu-l blochează). Evoluția lui se face **colectiv**,
   tocmai ca să *limiteze fork-urile* și să păstreze interoperabilitatea între
   biblioteci.
7. **Evoluție purtată de colectiv.** Unele zone ale vocabularului trebuie
   actualizate (de exemplu categoriile legate de temele LGBTQI+). Aceste
   evoluții nu se decretează de sus: se discută **în interiorul
   federației**.

Pe scurt: tezaurul rămâne **100 % al FICEDL**; AnarBib este o
oglindă loială a lui și un **releu** care transmite mai departe ce observă.

## La ce folosește

- **Descrierea prin subiect.** La catalogare, câmpul **„Subiecte” (autoritate de subiect)**
  leagă un document de unul sau mai mulți termeni din tezaur. Asta face posibil să
  găsești o carte după **ceea ce tratează**, nu doar după titlu sau după
  autoarea ei.
- **Navigarea pe teme.** Acești termeni alimentează **fațetele** și navigarea
  tematică a catalogului public.
- **Zece limbi deodată.** Același concept își poartă eticheta în fiecare
  dintre cele zece limbi: o cititoare hispanofonă și un cititor grecofon ajung la *același
  subiect*, fiecare în limba sa.
- **Legarea bibliotecilor.** Pentru că toată lumea se sprijină pe **același**
  vocabular, cataloagele devin comparabile și interschimbabile — aceasta este temelia
  punerii în comun (duplicate, împrumut între biblioteci, metacatalog).

## Cum îl folosești concret

1. **Caută un termen în „Subiecte”.** La catalogare, începe să tastezi în câmpul
   **Subiecte**: AnarBib propune termenii din tezaur, cu ierarhia lor.
   Refolosește ce există în loc să inventezi.
2. **Alege granularitatea potrivită.** Nici prea larg, nici prea restrâns: termenul pe care
   *cineva l-ar folosi ca să caute* cartea asta. De obicei ajung două până la patru
   subiecte.
3. **Citește nota de aplicare** dacă termenul are una: ea spune cum să-l folosești.
4. **Etichetă lipsă în limba ta (⚐).** Dacă un subiect nu are încă o denumire
   **în limba ta**, el este afișat **în varianta de rezervă** (adesea într-o altă limbă) cu
   un ⚐. Nu e o eroare: e o **lacună a versiunii de referință**. Nu o
   cârpim la noi — vezi mai jos.
5. **O eroare, o lacună? Semnalează, nu corecta.** Termen greșit, traducere
   absentă: **semnalează-le echipei de coordonare**, care le duce mai departe la FICEDL. Corectura
   se face în sursa canonică, apoi ne revine prin resincronizare.
   *(Singura excepție, deja spusă: o etichetă de limbă pur și simplu așezată greșit poate
   fi pusă la locul ei de partea noastră, fără să ne atingem de cuvânt.)*
6. **Ai nevoie de un termen care nu există?** Tezaurul nu se îmbogățește *local*.
   Pe moment, **cuvintele-cheie libere** (text liber, proprii fișei) sunt
   supapa — vezi ghidul „Indexarea pe subiecte”. Pe termen mediu, o propunere
   de adăugare **ajunge la colectivul** FICEDL.

## Spiritul: consultăm, nu capturăm

Această conectare este **o mână întinsă**, nu o acaparare: AnarBib *împrumută* un
vocabular comun fără să și-l însușească, îl *reflectă* fără să-l *înghețe* și *dă înapoi*
către FICEDL ceea ce observă în el. Tezaurul rămâne viu acolo unde trebuie să fie — în
federația care îl poartă — iar catalogul nostru profită de el fără să-i facă vreodată concurență.
Este, la nivelul cuvintelor, aceeași etică de peste tot din AnarBib: **să oferi și să
legi, niciodată să captezi**.

> Vezi și: ghidul **„Indexarea pe subiecte”** (gestul concret la catalogare) și
> documentul-cadru **„Întrajutorarea la catalogare”** (bunul comun al cunoașterii al cărui
> nucleu este acest vocabular). Tezaurul de referință poate fi consultat la `thesaurus.ficedl.info`
> — sursa canonică ce face autoritate.

*Document al bunului comun AnarBib. Tezaurul însuși este opera FICEDL; acest ghid
explică doar folosirea lui în AnarBib.*
