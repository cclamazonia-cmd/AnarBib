# Benvenut* nella rete AnarBib

**Guida di accoglienza delle coordinazioni — i primi trenta giorni**

*Versione 1.0 — 16 settembre 2026 · Licenza AGPLv3 · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Prima di tutto: ciò che è stato accettato, e ciò che ancora non lo è

La candidatura della tua biblioteca è stata accettata dalla coordinazione della rete.
Questo vuol dire due cose, e due soltanto:

1. La rete riconosce la tua biblioteca come parte della famiglia anarchica e libertaria
   che accoglie, e ti ha aperto il cammino della costituzione.
2. Il tuo account non è più un account di richiedente: è un account di **coordinazione in
   costituzione**.

Ciò che **non** è ancora avvenuto: la tua biblioteca non è attiva. Non compare nel
catalogo comune, non riceve lettor*, non scambia nulla con le altre biblioteche. È
**pre-attiva**, e sei tu a doverla tirare fuori di lì — non da sol*, e non in un giorno
solo.

> **La promessa di questa guida.** Non hai bisogno di essere bibliotecari*. Non hai
> bisogno di essere informatic*. Hai bisogno di sapere che cosa vuole il tuo collettivo,
> e di avere qualcuno a cui chiedere quando non lo sai. Il resto è cliccare.
>
> **E la regola d'oro: clicca, non romperai niente.** Il software non mostra le
> transizioni impossibili, disattiva con una spiegazione i pulsanti che una regola
> bloccherebbe, e rifiuta nel database le combinazioni impossibili. I rari gesti che
> davvero non tornano indietro sono elencati al capitolo 9.

**La persona con cui parlare.** In qualsiasi momento di questo percorso, prima di decidere
e non dopo: `anarbib@proton.me`. La rete tiene per principio che una decisione di
costituzione si discute con un* compagn* prima di diventare un modulo. Scrivere non è
un'ammissione di debolezza — è il funzionamento normale.

---

## 1. Giorno 1 — Entrare, e capire dove sei

### 1.1 Connettersi

La pagina di connessione è `/login` (pulsante **Accedi**). L'indirizzo `/cadastro` non fa che
reindirizzare verso di essa: se un vecchio documento ti ci manda, non è un tuo errore.

Se usi ancora la password provvisoria ricevuta per e-mail, **cambiala prima di ogni altra
cosa**. Finché non è cambiata, diverse azioni restano bloccate — è una prova passiva che
l'account è stato davvero preso in mano da una persona.

### 1.2 Le due case

È la cosa più importante di tutta la guida, e vale la pena impararla a memoria.

| Se la domanda è… | Vai in… |
|---|---|
| « che cosa abbiamo deciso? » | **`/biblioteca`** — la casa collettiva |
| « che cosa faccio con questa persona davanti a me? » | **`/painel`** — il bancone |

In `/biblioteca` vivono l'identità pubblica, il regolamento, l'équipe, il profilo di
adozione, le transizioni e la riservatezza: tutto ciò che il collettivo ha deliberato.
In `/painel` vive il lavoro di tutti i giorni: prestiti, restituzioni, consultazioni,
prenotazioni, account in attesa di convalida.

Non è un ordinamento arbitrario. Molti software di biblioteca mescolano le due cose, e il
risultato è che la configurazione politica finisce nascosta in un back-office da
amministratore. Qui, la deliberazione sta da una parte e l'operatività dall'altra.

### 1.3 Le rotte che userai

| Rotta | Che cos'è | Per chi |
|---|---|---|
| `/criar-conta` | iscrizione — **l'unica porta d'ingresso, per tutte le persone** | chiunque |
| `/conta` | lo spazio personale di ogni lettor* — nove schede | ciascun*, il proprio |
| `/atelier` | i laboratori: costituzione e autorità | coordinazione in costituzione |
| `/painel` | il bancone, il lavoro del giorno | équipe (librarian, coordinazione) |
| `/biblioteca` | la casa collettiva, le decisioni | équipe, con poteri per ruolo |
| `/catalogacao` | catalogare e importare | équipe |
| `/rede` | amministrazione della rete | solo admin di rete |

La pagina **Federação** e le pagine pubbliche — catalogo, Opera, Periodico, Soggetto,
Biblioteche, Cartografia, Thesaurus FICEDL — completano l'insieme. Le rotte non sono
tradotte: sono le stesse nelle dieci lingue.

> **Non entri mai nell'account di qualcun altro.** Tutto ciò che l'équipe deve fare per
> un* lettor* si trova nel painel. Se ti sei sorpres* a voler « entrare come » qualcuno,
> quello che cerchi è nel painel, scheda **Lettor\*** (`leitor`).

---

## 2. Giorni da 1 a 3 — Il laboratorio di costituzione

La costituzione è un percorso in `/atelier`. Puoi salvare in qualsiasi momento e tornare
più tardi: nulla si perde tra due sessioni. **Hai 60 giorni**, e un promemoria per e-mail
arriva al 45º.

### 2.1 Tappa 0 — il profilo di adozione, l'atto fondatore

Prima di tutti gli altri volet, il software chiede dove la tua biblioteca si colloca su
**quattro assi indipendenti**. Nessuno è un livello di qualità: sono modi di esistere, e
una piccola biblioteca che sceglie il modo semplice dappertutto non è una biblioteca
incompiuta.

**Asse 1 — `catalog_mode`, il catalogo**

- `local_only` — il fondo resta a casa, non esposto alla rete. Utile durante un periodo
  di rodaggio, o quando una parte del fondo non è pronta per essere pubblicata.
- `network_published` — il fondo entra nel catalogo comune AnarBib.

**Asse 2 — `circulation_mode`, la circolazione**

- `off` — nessuna circolazione gestita nel software: solo catalogo. È il caso di un fondo
  patrimoniale di consultazione.
- `informal` — circolazione semplice, senza quota associativa né regole rigide. Il caso
  tipico di una biblioteca militante dove tutt* si conoscono.
- `full_sigb` — circolazione completa: regole, prenotazioni, quote, sospensioni.

**Asse 3 — `network_mode`, la federazione**

- `isolated` — la biblioteca esiste in AnarBib ma non scambia nulla.
- `observer` — riceve i flussi della rete, non contribuisce ancora.
- `federated` — partecipa pienamente.

**Asse 4 — `governance_mode`, la governance**

- `informal` — nessun ruolo d'équipe distinto: tutt* sono lettor*. Nessuna cooptazione,
  nessuna carenza, nessun registro di audit.
- `staff_roles` — i ruoli `librarian` e `coordenador*` esistono, cooptazione
  semplificata.
- `full_governance` — l'insieme: cooptazione, carenza, registro di audit, cron.

### 2.2 Ciò che ogni scelta accende nel painel

Questa tabella è la ragione per cui la tappa 0 viene prima di tutto il resto. Le schede
del bancone compaiono o no secondo l'asse di circolazione:

| Scheda del painel | Compare se |
|---|---|
| **Lavoro del giorno** (`trabalho-do-dia`) | sempre |
| **Azioni** (`acoes`) | sempre |
| **Lettor\*** (`leitor`) | sempre |
| **Storico** (`historico`) | sempre |
| **Consultazioni locali** (`consultas-locais`) | circolazione `informal` o `full_sigb` |
| **Prestiti** (`emprestimos-livro`) | circolazione `informal` o `full_sigb` |
| **Prenotazioni** (`reservas`) | circolazione `full_sigb` |
| **Prestiti in blocco** (`emprestimos-lote`) | circolazione `full_sigb` |
| **Contributi** (`contribuicoes`) | quota attivata **e** circolazione diversa da `off` |

Se una scheda non compare da te, non è un guasto: è il profilo che il tuo collettivo ha
scelto. E se il profilo cambia nel corso della sessione, il painel torna da solo al
**Lavoro del giorno**.

> **Le scelte non sono prigioni.** Ogni asse ha la sua dottrina di transizione — alcune
> rapide, alcune lente, alcune irreversibili. La scheda **Transizioni** sta in
> `/biblioteca`, e non nel painel: cambiare profilo è una decisione collettiva, non un
> gesto di bancone. Certe transizioni che attraversano più assi passano dalla convalida
> degli admin di rete.

### 2.3 I dieci volet

Dopo la tappa 0, il laboratorio mostra solo i volet che il tuo profilo rende pertinenti.
Una biblioteca in `circulation_mode = off` non vedrà il volet circolazione: non manca
nulla, è che quella domanda non si pone da voi.

| Volet | Ciò che si decide | Condizione |
|---|---|---|
| 1 | Identità — nome, nome breve, indirizzo, contatto | sempre |
| 2 | Orari e permanenze | sempre |
| 3 | Persone responsabili | secondo la governance |
| 4 | Politica di catalogazione | sempre |
| 5 | Politica di circolazione | se la circolazione non è `off` |
| 6 | Politica di adesione dei lettor* | secondo governance e circolazione |
| 7 | Politica delle e-mail | sempre |
| 8 | Visibilità e partecipazione alla rete | se la rete non è `isolated` |
| 9 | Dati e riservatezza | sempre |
| 10 | Generazione del regolamento | sempre |

**Nessuno di questi volet è una questione informatica.** Sono dieci domande d'assemblea,
presentate nell'ordine in cui si risponde bene. Riempili con ciò che il collettivo ha già
deciso; dove non ha deciso, fermati e porta la questione alla prossima riunione. Il
laboratorio aspetta.

### 2.4 Il volet 10 — lo scheletro di regolamento

Alla fine, il software produce un PDF precompilato con tutte le tue scelte. **Questo PDF
non è un certificato.** È uno scheletro da discutere: una materia prima di deliberazione.
Le sezioni che meritano dibattito sono marcate come tali.

Il percorso atteso è: scaricare, portare in assemblea, emendare liberamente, e ricaricare
il documento emendato come regolamento ufficiale della biblioteca. Finché non è
ricaricato, la biblioteca resta pre-attiva.

> **Un punto di onestà.** « Concludere la costituzione » non vale, oggi, attivazione
> automatica della biblioteca. È una lacuna nota del software, non un tuo errore. Quando
> arrivi in fondo ai volet, scrivi a `anarbib@proton.me` perché l'attivazione venga
> fatta — e insisti se nessuno risponde in qualche giorno.

---

## 3. Giorni da 3 a 7 — La pagina Biblioteca, la casa collettiva

Una volta terminata la costituzione, `/biblioteca` diventa il luogo dove ciò che è stato
deciso resta iscritto e si mantiene. È lì che si guarda quando qualcuno chiede « ma che
cosa avevamo stabilito? ».

- **Identità pubblica** — ciò che la rete e il pubblico vedono della tua biblioteca.
- **Regolamento** — il documento che avete adottato, e le sue versioni.
- **Équipe** — chi è che cosa, e per quale circuito (capitolo 4).
- **Profilo** — i quattro assi, così come sono oggi.
- **Transizioni** — le proposte di cambio di profilo e la loro votazione.
- **Riservatezza** — conservazione dei dati, purga automatica, GDPR/LGPD.

**Le decisioni da arbitrare questa settimana**, tutte in `/biblioteca`:

1. **La visibilità del fondo** — catalogo pubblico o no, comparsa nella galleria di
   biblioteche di `anarbib.org`, presenza nella cartografia della rete. Nella
   cartografia, un collettivo che sceglie di non comparire ha le sue ragioni: il software
   le rispetta, e anche tu.
2. **La politica delle e-mail** — quali eventi generano un messaggio alla persona che
   legge (ciclo di prestito, promemoria prima della scadenza, solleciti di ritardo) e se
   l'équipe ne riceve copia. Tutto questo si accende e si spegne per biblioteca.
3. **La conservazione dei dati** — quanto tempo lo storico di prestito di una persona
   resta conservato dopo la restituzione. È una questione politica tanto quanto legale:
   in una biblioteca militante, uno storico è un elenco di letture di persone
   identificate. Conservarne poco è una forma di protezione.
4. **La quota associativa**, se esiste da voi — e con essa la scheda **Contributi** del
   painel.
5. **La tessera di lettor\*** — se la attivate. Non porta alcun nome: soltanto il nome
   breve della biblioteca e un QR opaco, ed è la persona che legge a generarla e a
   rigenerarla. È disegnata così apposta, perché una tessera persa non racconti nulla su
   chi la portava.

> **A proposito della scheda Riservatezza.** Può mostrare due messaggi che si
> contraddicono a proposito della purga automatica. È un difetto di visualizzazione noto.
> Prima di concludere che la purga è attiva o inattiva, chiedi alla rete.

---

## 4. Giorni da 5 a 10 — Costituire l'équipe

### 4.1 Tre ruoli, e tre soltanto

`lettor*` · `librarian` (bibliotecari*) · `coordenador*` (coordinazione).

Il ruolo locale « amministratore » è stato ritirato nel maggio 2026. Se lo trovi citato
da qualche parte, il documento è scaduto. « Amministrator* della rete AnarBib » esiste, ma
è uno **statuto trasversale** — non è il gradino successivo della scala, e non ci si
arriva coordinando abbastanza a lungo. È un altro meccanismo politico, con la sua propria
cooptazione.

### 4.2 La trappola che costa cara

**Nessuno si iscrive due volte.** Tutt* entrano una sola volta da `/criar-conta`, come
lettor* — comprese le persone che faranno parte dell'équipe.

Diventare équipe non è una nuova iscrizione: è una cooptazione, e avviene sull'account che
esiste già. Chi si reiscrive credendo di « entrare come équipe » crea solo un secondo
account e un problema che la coordinazione dovrà disfare.

**Quindi l'unica cosa da chiedere a chi entrerà nell'équipe è: « mandami il tuo ID
pubblico ».**

### 4.3 Il circuito in tre tempi

Nessuna promozione è unilaterale. Tre persone distinte, tre gesti:

1. **Proporre** — la coordinazione propone qualcuno tramite il suo ID pubblico, per il
   ruolo `librarian` o `coordenador*`.
2. **Avallare** — un'altra persona dell'équipe ratifica. La persona interessata è esclusa
   dal quorum: non appena l'équipe conta altre due persone attive, servono due ratifiche.
3. **Accettare** — la persona proposta accetta. Senza questo consenso, non succede nulla.

La proposta **scade a 30 giorni**. Una riga di lettor* si chiude, quella di bibliotecari*
si apre: un solo ruolo attivo per biblioteca, e lo storico resta.

> **Il salto collegiale.** Per impostazione predefinita, per entrare nel cerchio della
> coordinazione bisogna essere passat* da bibliotecari*. Per un collettivo orizzontale,
> questo gradino intermedio non corrisponde a nulla: una sola decisione d'assemblea
> richiedeva due circuiti nel software. Di qui il salto — proporre qualcuno direttamente
> da lettor* alla coordinazione — che esiste come **opzione di biblioteca**, disattivata
> per impostazione predefinita, che il tuo collettivo attiva se vuole. Accorcia la scala,
> mai i consensi.

### 4.4 Uscire dall'équipe

- **Carenza di 7 giorni** — un'uscita dall'équipe non è immediata; la persona passa da
  uno stato intermedio, e questo lascia il tempo di parlarsi.
- **Inattività** — un account d'équipe che non si connette da molto tempo esce
  automaticamente, con un avviso alla persona 30 giorni prima e 7 giorni prima. L'avviso
  a 7 giorni parte anche verso la coordinazione, ed è scalato agli admin di rete se la
  persona inattiva è l'ultima coordinazione della casa.
- **Passare la mano** — trasmettere la coordinazione a qualcun altro si fa con lo stesso
  circuito in tre tempi, prima di andarsene. Non lasciarlo all'ultimo giorno.

---

## 5. Giorni da 7 a 20 — Il fondo

### 5.1 Le tre parole di cui hai bisogno

- **Opera** (*obra*) — la scheda condivisa: il libro in quanto opera, la stessa per tutta
  la rete.
- **Holding** — il fatto che la tua biblioteca possieda quest'opera.
- **Esemplare** — l'oggetto fisico sullo scaffale, con la sua etichetta, il suo stato, la
  sua storia.

Tre collettivi possono avere lo stesso libro: un'opera, tre holding, più esemplari. È per
questo che correggere una scheda giova a tutta la rete, e per questo che una scheda si
corregge con cura.

### 5.2 Tre livelli di scheda, e nessuno è quello sbagliato

| Livello | Spirito |
|---|---|
| **Simples** | biblioteca militante, senza pretese accademiche: tipo, titolo, autorità, anno, editore, lingua, collocazione, circolazione predefinita, copertina, ISBN |
| **Avançado** | lavoro da bibliotecari* senza MARC: sottotitolo, edizione, collana, luogo, pagine, contributi tipizzati, soggetti, note |
| **Completo** | esaustivo: zone ISBD, MARC, identificativi di autorità, provenienza completa |

**Cambiare livello non perde nulla.** Un campo nascosto da un livello più basso conserva
il suo valore. Fai la prova una volta, con i tuoi occhi: è ciò che convince.

**Comincia da Simples.** Cinque schede a settimana in Simples valgono più di una scheda
perfetta al mese. Il fondo esiste solo se catalogato.

### 5.3 L'unica esigenza che la rete chiede davvero

**Nessun esemplare nuovo senza modalità di acquisizione.** Da dove viene, quando, donato
da chi, dopo quale evento.

Non è un dettaglio erudito. In una biblioteca militante, la provenienza è la storia del
collettivo. Senza di essa, il fondo diventa una pila anonima nel giro di una generazione.
La rete non ti chiede di fare il recupero retroattivo — chiede che il debito smetta di
crescere da adesso in poi.

### 5.4 Il resto di `/catalogacao`, quando ne avrai bisogno

Importazioni di massa, assistente di deduplicazione in tre tempi, ricerca di copertine,
fonti esterne di metadati, deposito con OCR nel browser, inventario tramite lettura delle
etichette QR, periodici e i loro stati di collezione. Niente di tutto questo è necessario
la prima settimana. È lì quando sarà il momento.

### 5.5 Soggetti e thesaurus FICEDL

AnarBib porta con sé il **thesaurus FICEDL**: 462 termini, tradotti nelle dieci lingue,
consegnati con il software. È un bene comune della federazione, e arriva già riempito —
non è un compito per te.

I **soggetti locali**, al contrario, appartengono a ciascuna casa: è il tuo fondo, il tuo
vocabolario, le tue scelte editoriali. E **allineare** i tuoi soggetti ai termini FICEDL è
un atto del collettivo, non un'operazione tecnica: dire che il tuo « abolizionismo penale »
corrisponde al termine comune « prigione » è una posizione documentaria. Per questo
l'allineamento non arriva già fatto.

---

## 6. Giorni da 10 a 25 — Il bancone

Quattro flussi, e il painel li organizza:

- **Prestito** — uscita, restituzione (anche parziale), proroga. La proroga può essere
  fatta pezzo per pezzo: se la persona ha finito due dei tre libri, solo il terzo viene
  prorogato.
- **Restituzione** — totale o riga per riga. Un'azione di massa non fallisce mai in
  silenzio: ciò che non è passato viene elencato con la sua ragione.
- **Consultazione locale** — la persona vuole vedere qualcosa sul posto, si negozia una
  fascia oraria. **La negoziazione si ferma a tre andate e ritorni**: oltre, il software
  vi rimanda al telefono. È deliberato — una negoziazione che va oltre non è un problema
  di software.
- **Prenotazione** — fino al ritiro effettivo, che trasforma la prenotazione in prestito.

Accanto a questo, nel painel: le **convalide** delle iscrizioni dei lettor* (è qui che
decidete chi entra), la **cauzione** se la vostra casa la pratica, i **contributi**, le
**note di lettura**, gli **eventi**.

> **Un difetto noto.** Il pulsante « Aprire i prestiti » di certi compiti del Lavoro del
> giorno porta a una scheda vuota. Non sei tu. Passa direttamente dalla scheda
> **Prestiti** (`emprestimos-livro`).

---

## 7. Giorni da 20 a 30 — La federazione

La pagina **Federação** ha otto schede: **Início**, **Círculos**, **Diretório**,
**Assembleias**, la gazzetta **Rizoma**, **Carta/Boletim**, **Apoio mútuo** e **Comuns**.

È la parte del software che non è un SIGB. Esiste perché il progetto non vuole essere un
« SaaS per biblioteche »: entrare in AnarBib è entrare in un progetto politico comune, e
una rete che scambia solo notizie bibliografiche non è una rete.

Ciò che c'è da fare in quest'ultima settimana, senza fretta:

1. **Passare da `observer` a `federated`**, se è ciò che avete deciso — e solo in quel
   caso. Entrare nella rete in modo osservatore per qualche mese è una scelta
   rispettabile.
2. **Riempire la vostra scheda nel Diretório**, perché le altre case sappiano chi siete e
   come parlarvi.
3. **Decidere sulla cartografia** — comparire con un indirizzo preciso, solo con la
   città, o non comparire. Nessuna delle tre risposte deve essere giustificata.
4. **Guardare i Círculos e le Assembleias**, per sapere dove si prendono le decisioni
   della rete.
5. **Se pubblicate il catalogo**, vedere con la rete che cosa significa per voi il punto
   OAI-PMH — è tramite esso che altri cataloghi possono raccogliere il vostro.

La pagina `/rede` è l'amministrazione della rete propriamente detta, riservata agli admin
di rete. Coordinare una biblioteca non dà accesso ad essa, ed è voluto.

---

## 8. Le dieci decisioni che non sono tecniche

Ritaglia questo elenco e portalo in assemblea. Nessuna di queste risposte è nel software:
il software non fa che registrare ciò che risponderete.

1. Dove ci collochiamo sui quattro assi del profilo?
2. Il nostro catalogo è pubblico?
3. Prestiamo, e a quali condizioni?
4. Chi può iscriversi come lettor*, e chi convalida?
5. Abbiamo una quota associativa? Una cauzione?
6. Quanto tempo conserviamo lo storico di lettura delle persone?
7. Chi fa parte dell'équipe, e attiviamo il salto collegiale?
8. Compariamo nella cartografia, e con quale precisione?
9. Partecipiamo alle assemblee della rete, e chi ci rappresenta?
10. Come allineiamo i nostri soggetti al thesaurus comune — e che cosa rifiutiamo di
    allineare?

---

## 9. Ciò che non rompe niente, e ciò che chiede una seconda lettura

**Non rompe niente:** cliccare dappertutto, aprire tutte le schede, cambiare il livello di
scheda per vedere, salvare un volet a metà, proporre una persona e lasciare scadere la
proposta, attivare e disattivare il salto collegiale, passare da `observer` a `federated`,
correggere una scheda.

**Chiede una seconda lettura, perché non torna indietro o costa caro:**

- **Eliminare** un account — e attenzione: in portoghese il software distingue **APAGAR**
  (svuotare lo storico) da **EXCLUIR** (sopprimere l'account), con due parole di conferma
  diverse. Nelle altre nove lingue le due cadono sulla stessa parola: in italiano
  entrambi i gesti cadono su **ELIMINA**. Leggi la frase intera prima di digitare, non
  solo la parola richiesta.
- Cancellare uno storico — i dati non tornano.
- Le transizioni di profilo marcate come irreversibili nella scheda Transizioni.
- Pubblicare in rete un fondo che il collettivo non ha deciso di pubblicare.
- Togliere qualcuno dall'équipe — il termine di carenza di 7 giorni esiste proprio per
  questo.

---

## 10. Dove chiedere aiuto, e come restituire

**Chiedere aiuto:** `anarbib@proton.me`. Di' su quale schermata sei e che cosa ti
aspettavi di vedere. Non esistono domande sciocche: il software è stato scritto da una
persona, e ogni « non l'ho trovato » che arriva è un difetto identificato.

**Un rituale che funziona.** Mezz'ora a settimana, con l'équipe, tre domande fisse:

> che cosa non ho trovato sullo schermo? · che cosa ho fatto senza capire? · che cosa
> mancava nel software?

Le risposte alimentano un foglio di lacune che diventa l'ordine del giorno successivo — e
un materiale di contribuzione al progetto. È l'unico dispositivo che fa risalire l'uso
fino al codice.

**Restituire, senza programmare.** Il file `AIDER.md`, nella radice del repository, elenca
i compiti aperti che non richiedono codice: traduzione, rilettura di scrittura inclusiva,
documentazione, allineamento di soggetti, test di schermate. AnarBib è sotto AGPLv3 e oggi
ha un* sol* manutentor* — è la sua principale fragilità, e si dice invece di tacersi.

---

## 11. I trenta giorni in una pagina

| Quando | Che cosa | Dove |
|---|---|---|
| Giorno 1 | Connettersi, cambiare la password, girare senza cambiare nulla | `/login`, `/conta` |
| Giorni 1–3 | Tappa 0: i quattro assi, decisi in collettivo | `/atelier` |
| Giorni 3–5 | Volet da 1 a 9 | `/atelier` |
| Giorno 5 | Volet 10: scaricare lo scheletro di regolamento | `/atelier` |
| Giorni 5–10 | Portare il regolamento in assemblea, emendare, ricaricare | assemblea, poi `/atelier` |
| Giorni 5–10 | Raccogliere gli ID pubblici, aprire i circuiti di cooptazione | `/biblioteca`, scheda Équipe |
| Giorni 7–20 | Prime schede in modo Simples, tutte con provenienza | `/catalogacao` |
| Giorni 10–25 | Prima giornata di bancone in autonomia | `/painel` |
| Giorni 20–30 | Scheda nel diretório, cartografia, modo di rete | Federação, `/biblioteca` |
| Giorno 30 | Scrivere alla rete: che cosa è mancato, che cosa ha ingannato | `anarbib@proton.me` |

---

*Questa guida esiste in dieci lingue: pt-BR, fr, es, en, it, de, ca, eo, nl, el. Descrive
lo stato del software a settembre 2026 e sarà corretta quando il software cambierà — se
una schermata non corrisponde a ciò che è scritto qui, è la guida ad avere torto, e dirlo
è una contribuzione.*

**Benvenut\*.**
