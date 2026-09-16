# Benvingut-a-e a la xarxa AnarBib

**Guia d'acollida de les coordinacions — els trenta primers dies**

*Versió 1.0 — 16 de setembre de 2026 · Llicència AGPLv3 · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Abans de tot: què s'ha acceptat, i què encara no

La candidatura de la teva biblioteca ha estat acceptada per la coordinació de la xarxa.
Això vol dir dues coses, i només dues:

1. La xarxa reconeix la teva biblioteca com a part de la família anarquista i llibertària
   que acull, i t'ha obert el camí de la constitució.
2. El teu compte ha deixat de ser un compte de sol·licitant i ha passat a ser un compte de
   **coordinació en constitució**.

El que encara **no** ha passat: la teva biblioteca encara no és activa. Encara no apareix
al catàleg comú, encara no rep lector-a-es, encara no intercanvia res amb les altres
biblioteques. És en estat **preactiu**, i ets tu qui l'en traurà — no sol-a-e, i no en un
sol dia.

> **La promesa d'aquesta guia.** No cal que siguis bibliotecari-a-e. No cal que entenguis
> d'informàtica. Cal que sàpigues què vol el teu col·lectiu, i que tinguis algú a qui
> preguntar quan no ho sàpigues. La resta és clicar.
>
> **I la regla d'or: clica, no trencaràs res.** El programari no mostra les transicions
> impossibles, desactiva amb una explicació els botons que una regla bloquejaria, i rebutja
> a la base de dades les combinacions impossibles. Els pocs gestos que realment no tornen
> enrere són llistats al capítol 9.

**La persona amb qui parlar.** En qualsevol moment d'aquest recorregut, abans de decidir i
no després: `anarbib@proton.me`. La xarxa té per principi que una decisió de constitució
es parla amb un-a-e camarada abans de convertir-se en un formulari. Escriure no és senyal
de feblesa — és el funcionament normal.

---

## 1. Dia 1 — Entrar, i entendre on ets

### 1.1 Connectar-se

La pàgina de connexió és `/login` (botó **Iniciar la sessió**). L'adreça `/cadastro` només redirigeix cap a ella:
si algun document antic t'hi envia, no és error teu.

Si encara fas servir la contrasenya provisional rebuda per correu electrònic, **canvia-la
abans que qualsevol altra cosa**. Mentre la contrasenya provisional no es canviï, diverses
accions queden bloquejades — és una prova passiva que el compte l'ha pres realment en mans
una persona.

### 1.2 Les dues cases

És la cosa més important de tota la guia, i val la pena aprendre-la de memòria.

| Si la pregunta és… | Vas a… |
|---|---|
| « què vam decidir? » | **`/biblioteca`** — la casa col·lectiva |
| « què faig amb aquesta persona que tinc al davant? » | **`/painel`** — el taulell |

A `/biblioteca` hi viuen la identitat pública, el reglament, l'equip, el perfil d'adopció,
les transicions i la privacitat: tot allò que el col·lectiu ha deliberat. A `/painel` hi
viu la feina de cada dia: préstecs, devolucions, consultes, reserves, comptes que esperen
validació.

No és un endreç arbitrari. Molts programaris de biblioteca barregen les dues coses, i el
resultat és que la configuració política acaba amagada en un back-office
d'administrador. Aquí, la deliberació queda d'un costat i l'operació de l'altre.

### 1.3 Les rutes que faràs servir

| Ruta | Què és | Per a qui |
|---|---|---|
| `/criar-conta` | inscripció — **l'única porta d'entrada, per a tothom** | qualsevol persona |
| `/conta` | l'espai personal de cada lector-a-e — nou pestanyes | cada persona, només el seu |
| `/atelier` | els tallers: constitució i autoritats | coordinació en constitució |
| `/painel` | el taulell, la feina del dia | equip (librarian, coordinació) |
| `/biblioteca` | la casa col·lectiva, les decisions | equip, amb poders per rol |
| `/catalogacao` | catalogar i importar | equip |
| `/rede` | administració de la xarxa | només admins de la xarxa |

La pàgina **Federação** i les pàgines públiques — catàleg, Obra, Publicació periòdica,
Matèria, Biblioteques, Cartografia, Tesaurus FICEDL — completen el conjunt. Les rutes no es
tradueixen: són les mateixes en les deu llengües.

> **Mai no entres al compte d'una altra persona.** Tot allò que l'equip ha de fer per
> un-a-e lector-a-e és al painel. Si t'has sorprès volent « entrar com a » algú, allò que
> busques és al painel, pestanya **Lector-a-e** (`leitor`).

---

## 2. Dies 1 a 3 — El taller de constitució

La constitució és un recorregut a `/atelier`. Pots desar en qualsevol moment i tornar més
tard: no es perd res entre dues sessions. **Tens 60 dies**, i un recordatori per correu
electrònic arriba al 45è.

### 2.1 Etapa 0 — el perfil d'adopció, l'acte fundador

Abans de tots els altres apartats, el programari pregunta on es col·loca la teva
biblioteca en **quatre eixos independents**. Cap d'ells no és un nivell de qualitat: són
formes d'existir, i una biblioteca petita que tria el mode simple a tot arreu no és una
biblioteca inacabada.

**Eix 1 — `catalog_mode`, el catàleg**

- `local_only` — el fons es queda a casa, no s'exposa a la xarxa. Útil durant un període de
  rodatge, o quan una part del fons encara no està a punt per ser publicada.
- `network_published` — el fons entra al catàleg comú AnarBib.

**Eix 2 — `circulation_mode`, la circulació**

- `off` — cap circulació gestionada al programari: només catàleg. És el cas d'un fons
  patrimonial de consulta.
- `informal` — circulació simple, sense quota ni regles estrictes. El cas típic d'una
  biblioteca militant on tothom es coneix.
- `full_sigb` — circulació completa: regles, reserves, quotes, suspensions.

**Eix 3 — `network_mode`, la federació**

- `isolated` — la biblioteca existeix a AnarBib però no intercanvia res.
- `observer` — rep els fluxos de la xarxa, encara no hi contribueix.
- `federated` — hi participa plenament.

**Eix 4 — `governance_mode`, la governança**

- `informal` — cap rol d'equip diferenciat: tothom és lector-a-e. Sense cooptació, sense
  carència, sense registre d'auditoria.
- `staff_roles` — els rols `librarian` i `coordinador-a-e` existeixen, cooptació
  simplificada.
- `full_governance` — el conjunt: cooptació, carència, registre d'auditoria, crons.

### 2.2 Què encén cada tria al painel

Aquesta taula és la raó per la qual l'etapa 0 ve abans de tot. Les pestanyes del taulell
apareixen o no segons l'eix de circulació:

| Pestanya del painel | Apareix si |
|---|---|
| **Treball del dia** (`trabalho-do-dia`) | sempre |
| **Accions** (`acoes`) | sempre |
| **Lector-a-e** (`leitor`) | sempre |
| **Historial** (`historico`) | sempre |
| **Consultes locals** (`consultas-locais`) | circulació `informal` o `full_sigb` |
| **Préstecs** (`emprestimos-livro`) | circulació `informal` o `full_sigb` |
| **Reserves** (`reservas`) | circulació `full_sigb` |
| **Préstecs en lot** (`emprestimos-lote`) | circulació `full_sigb` |
| **Contribucions** (`contribuicoes`) | quota activada **i** circulació diferent de `off` |

Si una pestanya no t'apareix, no és una avaria: és el perfil que el teu col·lectiu ha
triat. I si el perfil canvia durant la sessió, el painel torna tot sol al **Treball del
dia**.

> **Les tries no són presons.** Cada eix té la seva doctrina de transició — algunes
> ràpides, algunes lentes, algunes irreversibles. La pestanya **Transicions** és a
> `/biblioteca`, i no al painel: canviar de perfil és una decisió col·lectiva, no un gest
> de taulell. Certes transicions que travessen diversos eixos passen per la validació dels
> admins de la xarxa.

### 2.3 Els deu apartats

Després de l'etapa 0, el taller només mostra els apartats que el teu perfil fa pertinents.
Una biblioteca en `circulation_mode = off` no veurà l'apartat de circulació: no és que hi
falti res, és que aquella pregunta no us la feu.

| Apartat | Què s'hi decideix | Condició |
|---|---|---|
| 1 | Identitat — nom, nom curt, adreça, contacte | sempre |
| 2 | Horaris i permanències | sempre |
| 3 | Persones responsables | segons la governança |
| 4 | Política de catalogació | sempre |
| 5 | Política de circulació | si la circulació no és `off` |
| 6 | Política d'adhesió de lector-a-es | segons governança i circulació |
| 7 | Política de correus electrònics | sempre |
| 8 | Visibilitat i participació a la xarxa | si la xarxa no és `isolated` |
| 9 | Dades i confidencialitat | sempre |
| 10 | Generació del reglament | sempre |

**Cap d'aquests apartats no és una qüestió d'informàtica.** Són deu qüestions d'assemblea,
presentades en l'ordre en què es responen bé. Omple'ls amb allò que el col·lectiu ja ha
decidit; allà on encara no ha decidit, atura't i porta-ho a la reunió següent. El taller
espera.

### 2.4 L'apartat 10 — l'esquelet de reglament

Al final, el programari genera un PDF preemplenat amb totes les teves tries. **Aquest PDF
no és un certificat.** És un esquelet per discutir: una matèria primera de deliberació. Les
seccions que mereixen debat vénen marcades.

El recorregut esperat és: descarregar, portar a l'assemblea, esmenar lliurement, i tornar a
carregar el document esmenat com a reglament oficial de la biblioteca. Mentre no es torni a
carregar, la biblioteca continua preactiva.

> **Un punt d'honestedat.** « Concloure la constitució » no val, avui, activació automàtica
> de la biblioteca. És una mancança coneguda del programari, no un error teu. Quan arribis
> al final dels apartats, escriu a `anarbib@proton.me` perquè es faci l'activació — i
> insisteix si ningú no respon en uns quants dies.

---

## 3. Dies 3 a 7 — La pàgina Biblioteca, la casa col·lectiva

Un cop acabada la constitució, `/biblioteca` esdevé el lloc on allò que s'ha decidit queda
inscrit i s'aguanta. És allà on es mira quan algú pregunta « però què havíem quedat? ».

- **Identitat pública** — allò que la xarxa i el públic veuen de la teva biblioteca.
- **Reglament** — el document que heu adoptat, i les seves versions.
- **Equip** — qui és què, i per quin circuit (capítol 4).
- **Perfil** — els quatre eixos, tal com són avui.
- **Transicions** — les propostes de canvi de perfil i la seva votació.
- **Privacitat** — retenció de les dades, purga automàtica, RGPD/LGPD.

**Les decisions a arbitrar aquesta setmana**, totes a `/biblioteca`:

1. **La visibilitat del fons** — catàleg públic o no, aparició a la galeria de biblioteques
   d'`anarbib.org`, presència a la cartografia de la xarxa. A la cartografia, un col·lectiu
   que tria no aparèixer té les seves raons: el programari les respecta, i tu també.
2. **La política de correus electrònics** — quins esdeveniments generen un missatge a la
   persona lectora (cicle de préstec, recordatoris abans del venciment, reclamacions de
   retard) i si l'equip en rep còpia. Tot això s'encén i s'apaga per biblioteca.
3. **La retenció de les dades** — quant de temps es guarda l'historial de préstec d'una
   persona després de la devolució. És una qüestió política tant com legal: en una
   biblioteca militant, un historial és una llista de lectures de persones identificades.
   Guardar-ne poc és una forma de protecció.
4. **La quota**, si existeix a casa vostra — i amb ella la pestanya **Contribucions** del
   painel.
5. **El carnet de lector-a-e** — si l'activeu. No porta cap nom: només el nom curt de la
   biblioteca i un QR opac, i és la mateixa persona lectora qui el genera i el regenera.
   S'ha dissenyat així a propòsit, perquè un carnet perdut no expliqui res sobre qui el
   duia.

> **Sobre la pestanya Privacitat.** Pot mostrar dos missatges que es contradiuen a propòsit
> de la purga automàtica. És un defecte conegut de visualització. Abans de concloure que la
> purga és activa o inactiva, pregunta a la xarxa.

---

## 4. Dies 5 a 10 — Constituir l'equip

### 4.1 Tres rols, i només tres

`lector-a-e` · `librarian` (bibliotecari-a-e) · `coordinador-a-e`.

El rol local « administrador » es va retirar el maig de 2026. Si el trobes citat en algun
document, el document és vell. « Administrador-a-e de la xarxa AnarBib » existeix, però és
un **estatut transversal** — no és el graó següent de l'escala, i no s'hi arriba coordinant
prou temps. És un altre mecanisme polític, amb la seva pròpia cooptació.

### 4.2 El parany que costa car

**Ningú no s'inscriu dues vegades.** Tothom entra una sola vegada per `/criar-conta`, com a
lector-a-e — incloses les persones que seran de l'equip.

Esdevenir equip no és una nova inscripció: és una cooptació, i té lloc al compte que ja
existeix. Qui es reinscriu pensant que així « entra com a equip » només crea un segon
compte i un problema que la coordinació haurà de desfer.

**Per tant, l'única cosa a demanar a qui entrarà a l'equip és: « envia'm el teu ID públic ».**

### 4.3 El circuit en tres temps

Cap promoció no és unilateral. Tres persones diferents, tres gestos:

1. **Proposar** — la coordinació proposa algú pel seu ID públic, per al rol `librarian` o
   `coordinador-a-e`.
2. **Avalar** — una altra persona de l'equip ratifica. La persona afectada queda exclosa
   del quòrum: mentre l'equip tingui dues altres persones actives, calen dues
   ratificacions.
3. **Acceptar** — la persona proposada accepta. Sense aquest consentiment, no passa res.

La proposta **caduca als 30 dies**. Una línia de lector-a-e es tanca, s'obre la de
bibliotecari-a-e: un sol rol actiu per biblioteca, i l'historial es manté.

> **El salt col·legial.** Per defecte, per entrar al cercle de la coordinació cal haver
> passat per bibliotecari-a-e. Per a un col·lectiu horitzontal, aquest graó intermedi no
> correspon a res: una sola decisió d'assemblea exigia dos circuits al programari. D'aquí
> el salt — proposar algú directament de lector-a-e a la coordinació — que existeix com a
> **opció de biblioteca**, desactivada per defecte, que el teu col·lectiu activa si vol.
> Escurça l'escala, mai els consentiments.

### 4.4 Sortir de l'equip

- **Carència de 7 dies** — una sortida d'equip no és immediata; la persona passa per un
  estat intermedi, i això deixa temps per parlar-ne.
- **Inactivitat** — un compte d'equip que fa molt de temps que no es connecta surt
  automàticament, amb avís a la persona 30 dies abans i 7 dies abans. L'avís de 7 dies va
  també a la coordinació, i escala als admins de la xarxa si la persona inactiva és
  l'última coordinació de la casa.
- **Passar el relleu** — transmetre la coordinació a una altra persona es fa pel mateix
  circuit en tres temps, abans de marxar. No ho deixis per a l'últim dia.

---

## 5. Dies 7 a 20 — El fons

### 5.1 Les tres paraules que necessites

- **Obra** — la fitxa compartida: el llibre en tant que obra, la mateixa per a tota la
  xarxa.
- **Holding** — el fet que la teva biblioteca tingui aquesta obra.
- **Exemplar** — l'objecte físic al prestatge, amb la seva etiqueta, el seu estat, la seva
  història.

Tres col·lectius poden tenir el mateix llibre: una obra, tres holdings, diversos exemplars.
És per això que corregir una fitxa beneficia tota la xarxa, i per això que una fitxa es
corregeix amb cura.

### 5.2 Tres nivells de fitxa, i cap no és el dolent

| Nivell | Esperit |
|---|---|
| **Simples** | biblioteca militant, sense pretensió acadèmica: tipus, títol, autoria, any, editorial, llengua, signatura, circulació per defecte, coberta, ISBN |
| **Avançado** | feina de bibliotecari-a-e sense MARC: subtítol, edició, col·lecció, lloc, pàgines, contribucions tipades, matèries, notes |
| **Completo** | exhaustiu: zones ISBD, MARC, identificadors d'autoritat, procedència completa |

**Canviar de nivell no perd res.** Un camp amagat per un nivell més baix conserva el seu
valor. Fes la prova una vegada, amb els teus propis ulls: és el que convenç.

**Comença en Simples.** Cinc fitxes per setmana, en Simples, valen més que una fitxa
perfecta al mes. El fons només existeix quan està catalogat.

### 5.3 L'única exigència que la xarxa demana realment

**Cap exemplar nou sense mode d'adquisició.** D'on ve, quan, donat per qui, després de quin
esdeveniment.

No és un detall erudit. En una biblioteca militant, la procedència és la història del
col·lectiu. Sense ella, el fons es converteix en una pila anònima en una generació. La
xarxa no et demana que facis la feina retroactiva — demana que el deute deixi de créixer a
partir d'ara.

### 5.4 La resta de `/catalogacao`, quan la necessitis

Importacions massives, assistent de desduplicació en tres temps, cerca de cobertes, fonts
externes de metadades, dipòsit amb OCR al navegador, inventari per lectura de les etiquetes
QR, publicacions periòdiques i els seus estats de col·lecció. Res de tot això no és
necessari la primera setmana. Hi és quan sigui el moment.

### 5.5 Matèries i el tesaurus FICEDL

AnarBib porta amb ell el **tesaurus FICEDL**: 462 termes, traduïts a les deu llengües,
lliurats amb el programari. És un bé comú de la federació, i ja ve emplenat — no és una
tasca teva.

Les **matèries locals**, al contrari, són de cada casa: és el teu fons, és el teu
vocabulari, són les teves tries editorials. I **alinear** les teves matèries als termes
FICEDL és un acte del col·lectiu, no una operació tècnica: dir que el teu « abolicionisme
penal » correspon al terme comú « presó » és una posició documental. Per això l'alineament
no ve fet.

---

## 6. Dies 10 a 25 — El taulell

Quatre fluxos, i el painel els organitza:

- **Préstec** — sortida, devolució (inclosa la parcial), pròrroga. La pròrroga es pot fer
  ítem per ítem: si la persona ha acabat dos dels tres llibres, només es prorroga el tercer.
- **Devolució** — total o per línia. Una acció massiva mai no falla en silenci: allò que no
  ha passat es llista amb la raó.
- **Consulta local** — la persona vol veure alguna cosa al local, es negocia un horari. **La
  negociació s'atura a tres anades i tornades**: després d'això, el programari us envia al
  telèfon. És deliberat — una negociació que passa d'aquí no és un problema de programari.
- **Reserva** — fins a la recollida efectiva, que transforma la reserva en préstec.

Al costat d'això, al painel: les **validacions** de les inscripcions de lector-a-es (és aquí
on decidiu qui entra), la **fiança** si a casa vostra la practiqueu, les **contribucions**,
les **notes de lectura**, els **esdeveniments**.

> **Un defecte conegut.** El botó « Obrir préstecs » de certes tasques del Treball del dia
> porta a una pestanya buida. No ets tu. Passa per la pestanya **Préstecs**
> (`emprestimos-livro`) directament.

---

## 7. Dies 20 a 30 — La federació

La pàgina **Federação** té vuit pestanyes: **Início**, **Círculos**, **Diretório**,
**Assembleias**, la gaseta **Rizoma**, **Carta/Boletim**, **Apoio mútuo** i **Comuns**.

És la part del programari que no és un SIGB. Existeix perquè el projecte no vol ser un
« SaaS per a biblioteques »: entrar a AnarBib és entrar en un projecte polític comú, i una
xarxa que només intercanvia registres bibliogràfics no és una xarxa.

Què cal fer aquesta darrera setmana, sense pressa:

1. **Passar d'`observer` a `federated`**, si això és el que heu decidit — i només si.
   Entrar a la xarxa en mode observador durant uns quants mesos és una tria respectable.
2. **Omplir la vostra fitxa al Diretório**, perquè les altres cases sàpiguen qui sou i com
   parlar amb vosaltres.
3. **Decidir sobre la cartografia** — aparèixer amb adreça precisa, només amb la ciutat, o
   no aparèixer. Cap de les tres respostes no s'ha de justificar.
4. **Mirar els Círculos i les Assembleias**, per saber on es prenen les decisions de la
   xarxa.
5. **Si publiqueu el catàleg**, veure amb la xarxa què significa per a vosaltres el punt
   OAI-PMH — és per ell que altres catàlegs poden recol·lectar el vostre.

La pàgina `/rede` és l'administració de la xarxa pròpiament dita, reservada als admins de
la xarxa. Coordinar una biblioteca no hi dóna accés, i això és volgut.

---

## 8. Les deu decisions que no són tècniques

Retalla aquesta llista i porta-la a l'assemblea. Cap d'aquestes respostes no és al
programari: el programari només registra allò que respongueu.

1. On ens col·loquem en els quatre eixos del perfil?
2. El nostre catàleg és públic?
3. Prestem, i sota quines condicions?
4. Qui es pot inscriure com a lector-a-e, i qui valida?
5. Tenim quota? Fiança?
6. Quant de temps guardem l'historial de lectura de les persones?
7. Qui és de l'equip, i activem el salt col·legial?
8. Apareixem a la cartografia, i amb quina precisió?
9. Participem a les assemblees de la xarxa, i qui ens hi representa?
10. Com alineem les nostres matèries al tesaurus comú — i què refusem d'alinear?

---

## 9. Què no trenca res, i què demana una segona lectura

**No trenca res:** clicar a tot arreu, obrir totes les pestanyes, canviar el nivell de
fitxa per veure, desar un apartat a mitges, proposar una persona i deixar que la proposta
caduqui, activar i desactivar el salt col·legial, passar d'`observer` a `federated`,
corregir una fitxa.

**Demana una segona lectura, perquè no torna enrere o costa car:**

- **Eliminar** un compte — i atenció, en portuguès el programari distingeix **APAGAR**
  (buidar l'historial) d'**EXCLUIR** (suprimir el compte), amb dues paraules de confirmació
  diferents. En les altres nou llengües les dues cauen sobre la mateixa paraula: en català,
  **ELIMINAR**. Llegeix la frase sencera abans d'escriure, no només la paraula demanada.
- Esborrar un historial — les dades no tornen.
- Les transicions de perfil marcades com a irreversibles a la pestanya Transicions.
- Publicar en xarxa un fons que el col·lectiu encara no ha decidit publicar.
- Retirar algú de l'equip — el termini de carència de 7 dies existeix justament per això.

---

## 10. On demanar ajuda, i com tornar-ne

**Demanar ajuda:** `anarbib@proton.me`. Digues en quina pantalla ets i què esperaves
veure. No hi ha cap pregunta ximple: el programari l'ha escrit una persona, i cada « no ho
he trobat » que arriba és un defecte identificat.

**Un ritual que funciona.** Mitja hora per setmana, amb l'equip, tres preguntes fixes:

> què no he trobat a la pantalla? · què he fet sense entendre-ho? · què faltava al
> programari?

Les respostes alimenten un full de mancances que esdevé l'ordre del dia següent — i un
material de contribució per al projecte. És l'únic dispositiu que fa pujar l'ús fins al
codi.

**Tornar-ne, sense programar.** El fitxer `AIDER.md`, a l'arrel del repositori, llista les
tasques obertes que no exigeixen codi: traducció, revisió d'escriptura inclusiva,
documentació, alineament de matèries, prova de pantalles. AnarBib és AGPLv3 i avui té
un-a-e sol-a-e mantenidor-a-e — és la seva principal fragilitat, i es diu en comptes
d'amagar-se.

---

## 11. Els trenta dies en una pàgina

| Quan | Què | On |
|---|---|---|
| Dia 1 | Connectar-se, canviar la contrasenya, passejar sense canviar res | `/login`, `/conta` |
| Dies 1–3 | Etapa 0: els quatre eixos, decidits en col·lectiu | `/atelier` |
| Dies 3–5 | Apartats 1 a 9 | `/atelier` |
| Dia 5 | Apartat 10: descarregar l'esquelet de reglament | `/atelier` |
| Dies 5–10 | Portar el reglament a l'assemblea, esmenar, tornar a carregar | assemblea, després `/atelier` |
| Dies 5–10 | Recollir els ID públics, obrir els circuits de cooptació | `/biblioteca`, pestanya Equip |
| Dies 7–20 | Primeres fitxes en mode Simples, totes amb procedència | `/catalogacao` |
| Dies 10–25 | Primer dia de taulell en autonomia | `/painel` |
| Dies 20–30 | Fitxa al diretório, cartografia, mode de xarxa | Federação, `/biblioteca` |
| Dia 30 | Escriure a la xarxa: què ha faltat, què ha enganyat | `anarbib@proton.me` |

---

*Aquesta guia existeix en deu llengües: pt-BR, fr, es, en, it, de, ca, eo, nl, el. Descriu
l'estat del programari el setembre de 2026 i serà corregida quan el programari canviï — si
una pantalla no correspon al que hi ha escrit aquí, és la guia que s'equivoca, i dir-ho és
una contribució.*

**Benvingut-a-e.**
