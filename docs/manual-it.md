# AnarBib — Manuale d'uso
## Rete di biblioteche libertarie

*Versione 1.1 — Settembre 2026*

---

## 1. Primi passi

### Accedere
Vai all'URL della tua istanza AnarBib e clicca su **Entrar** (o il pulsante di accesso nella lingua della tua interfaccia). Inserisci la tua e-mail e la tua password.

### Cambiare la lingua
Il selettore di lingua si trova in alto a destra di ogni pagina (🇧🇷🇵🇹 / 🇫🇷 / 🇪🇸 / 🇬🇧 / 🇮🇹 / 🇩🇪 / 🇳🇱 / 🇬🇷 / Català / Esperanto). La scelta viene salvata localmente.

### Cercare nel catalogo
Il **Catalogo** mostra una riga per opera, nella lingua della tua interfaccia quando il titolo è stato tradotto: autore/trice, titolo, il numero di edizioni e le biblioteche che la possiedono.
1. Clicca su **Vedi le edizioni** (il « + » della riga): ogni edizione compare sotto, con copertina, editore e anno. I tomi di un'opera in più volumi sono numerati e ordinati.
2. Clicca su **Esemplari per biblioteca**: la disponibilità compare biblioteca per biblioteca. Se hai effettuato l'accesso, « la tua biblioteca » è segnalata; ciò che è disponibile altrove ma non per te viene detto così com'è.
3. Il pulsante **Lista piatta** torna a una riga per edizione; la scelta viene memorizzata.

---

## 2. Lettore/trice — Il mio account

### Prenotare un documento
1. Cerca il documento nel **Catalogo**
2. Clicca sulla sua scheda
3. Se il documento è disponibile, clicca su **Prenotare un prestito**
4. Puoi anche andare nella scheda **Prenotazioni** del tuo account e inserire il riferimento locale

### Seguire i propri prestiti
La scheda **Prestiti in corso** mostra i tuoi prestiti attivi con :
- La data di uscita e la scadenza
- Un pulsante **Rinnovare** (se il rinnovo è autorizzato)
- L'indicazione dell'eventuale ritardo

### Rinnovare un prestito
Clicca su **Rinnovare** nella lista dei tuoi prestiti. Il rinnovo può essere rifiutato se :
- Il prestito è già stato rinnovato una volta
- Il prestito è in ritardo
- Un* altr* lettore/trice ha prenotato lo stesso documento

### Intestazione di stato dell'account
In cima alla pagina **Il mio account**, un'intestazione colorata indica lo stato del tuo account :
- ✓ **Verde** : Account attivo, tutto bene
- ⚠ **Arancione** : Attenzione (prestito in ritardo, password da cambiare)
- ⛔ **Rosso** : Account limitato (contatta la tua biblioteca)

### Cronologia
La scheda **Cronologia** elenca le tue vecchie prenotazioni e i tuoi vecchi prestiti. Puoi cliccare sul titolo per vedere la scheda del documento, e **Nascondere** le voci che non vuoi più visualizzare.

### Proteggere il tuo account: l'autenticazione a due fattori
Dopo la password, AnarBib può chiedere un codice di sei cifre che cambia ogni 30 secondi. Il codice viene da un'app di autenticazione libera, che funziona offline: Aegis o FreeOTP+ su Android, FreeOTP o 2FAS su iPhone, KeePassXC sul computer. Niente SMS né servizi esterni.

**Obbligatoria per i gruppi di lavoro dal 1° gennaio 2027** (amministrazione della rete, coordinamenti, gruppi delle biblioteche); facoltativa per gli account di lettura.

Per attivarla:
1. Apri **Il mio account → Dati personali**. Sotto il cambio della password, clicca su **Attiva l'autenticazione a due fattori**.
2. Dai un nome al dispositivo (per esempio «Telefono») e scansiona il codice QR con l'app. Senza fotocamera, inserisci a mano la chiave mostrata.
3. Inserisci il **codice di sei cifre** mostrato dall'app e clicca su **Conferma**.

Da quel momento, a ogni accesso AnarBib ti chiede il codice dopo la password. Se hai registrato più dispositivi, scegli quello che hai a portata di mano.

- **Registra un secondo dispositivo** (KeePassXC oltre al telefono, per esempio): è l'unico modo per non restare senza accesso se ne perdi uno.
- **Hai perso il dispositivo?** Contatta l'amministrazione della rete (Matrix o anarbib@proton.me). Dopo aver verificato la tua identità con un altro mezzo, rimuove i tuoi dispositivi; ne registri uno nuovo all'accesso successivo.
- Per rimuovere un dispositivo, clicca su **Rimuovi** accanto al suo nome.
- Un account di un gruppo di lavoro senza dispositivo dopo il 1° gennaio 2027 dovrà registrarne uno all'accesso, prima di continuare.
- Nessuno di AnarBib ti chiederà mai il tuo codice né il tuo codice QR.

---

## 3. Bibliotecari* — Pannello di controllo

### Lavoro del giorno
Il pannello di controllo genera automaticamente le attività prioritarie :
- Ritiro pianificato oggi
- Nuove prenotazioni da gestire
- Prenotazioni pronte per il ritiro
- Prestiti in ritardo
- Rientri previsti oggi
- Consultazioni in loco da gestire

### Gestire le prenotazioni
La scheda **Prenotazioni** permette di :
- Selezionare più prenotazioni (caselle di spunta)
- Applicare un passaggio in blocco (preparare, pianificare il ritiro, confermare)
- Annullare prenotazioni

### Gestire i prestiti
- **Creare un prestito** : inserire l'ID o l'e-mail del lettore/trice + i riferimenti locali
- **Restituzione totale** : inserire l'ID del prestito
- **Restituzione parziale** : inserire gli ID degli esemplari singoli
- **Prestiti raggruppati** : vista sintetica per prestito

### Gestire un* lettore/trice
La scheda **Gestire lettore/trice** permette di :
- Cercare per ID pubblico, e-mail o nome
- Modificare il profilo (nome, e-mail, telefono, genere, indirizzo)
- **Limitare l'accesso** (con motivazione : mancata restituzione, ecc.)
- **Rimuovere la limitazione**

---

## 4. Catalogazione

### Creare una scheda documento
1. Andare in **Catalogazione** > scheda **Documento**
2. Selezionare il **tipo di materiale** (Libro, Periodico, Volantino, Audio, ecc.)
3. Compilare i campi (la modalità Semplice mostra l'essenziale, la modalità Completa tutti i campi)
4. Usare **Ricerca metadati** per precompilare tramite ISBN
5. **Salvare la bozza**

### Opera, edizioni e tomi
Un'opera riunisce tutte le edizioni di uno stesso testo. Nella scheda di un documento, il blocco **Opera** permette di:
- **Collegare a un'altra opera**: cercare l'opera per titolo, poi **Collegare**. L'opera lasciata scompare se resta vuota.
- **Titoli per lingua**: un titolo per lingua dell'interfaccia. I titoli segnati « traduzione automatica — correggimi » sono stati proposti dalla macchina: rileggili e clicca **Salva** per confermarli.
- **Titolo uniforme**: il titolo di riferimento dell'opera, scritto nella lingua d'origine dell'opera stessa, non in quella di una traduzione.
- **Tomo / volume**: il numero del tomo quando l'opera è in più volumi. I tomi restano in un'unica opera.

### Assistente di deduplicazione: opere scisse e volumi
Nell'**Assistente di deduplicazione** (Catalogazione), due schede completano i doppioni di schede:
- **Opere scisse**: due opere che sembrano essere lo stesso testo. **Unire in « … »** le riunisce; **Tenere separate** memorizza la decisione e la coppia non torna.
- **Volumi**: schede che sembrano essere i tomi di una stessa opera. Spunta **Riunire questa scheda** per ogni tomo scelto, inserisci il numero e conferma; un gruppo risolto non torna più.

Nessuna fusione e nessun numero di tomo vengono posti dalla macchina: ogni gesto è tuo.

### Tipi di documento e campi specializzati
Ogni tipo di documento mostra campi adattati :
- **Periodico** : volume, numero, fascicolo, periodicità, ISSN
- **Volantino** : campagna, organizzazione emittente, data approssimativa, formato fisico
- **Audio** : durata, supporto, formato tecnico, partecipant*
- **Audiovisivo** : durata, regia, sottotitoli
- **Risorsa digitale** : URL, condizione d'accesso, restrizione
- **Dossier** : portata, periodo, organizzazioni, contesto politico

### Tradurre le biografie degli autori/trici
Nella scheda **Autore/trice**, quando si modifica un autore/trice pubblicat*:
1. Aprire il pannello **Traduzioni della biografia**
2. Inserire la biografia in ogni lingua desiderata
3. Cliccare **Salvare le traduzioni**

### Stampare le etichette
Nella scheda **Indicizzazione**, sotto il modulo dell'esemplare :
1. Filtrare e selezionare gli esemplari
2. Cliccare **Stampare X etichetta/e**
3. Si apre un documento A4 con 21 etichette per pagina (7×3)

---

## 5. Amministrazione

### Gestione della biblioteca
La pagina **Gestione della biblioteca** permette di configurare :
- Identità (nome, città, contatto)
- Comunicazioni (e-mail, modalità di invio, tipi di notifica)
- Regolamento (caricamento PDF, regole di circolazione)
- Équipe, scambi interbibliotecari, rapporti

### Gestione della rete
La pagina **Rete** (accessibile ai coordinatori/trici e agli amministratori/trici) permette di :
- Vedere la panoramica (statistiche globali)
- Gestire le richieste delle biblioteche
- Amministrare i membri della rete
- Promuovere amministratori/trici

### Autenticazione a due fattori dei gruppi di lavoro
La scheda **Autenticazione a due fattori** della pagina **Rete**, riservata all'amministrazione della rete, elenca gli account attivi dei gruppi di lavoro e quelli che hanno scelto l'autenticazione a due fattori, con i loro ruoli e il numero di dispositivi; quelli senza dispositivo compaiono per primi. Mostra anche il requisito in vigore.

Per aiutare una persona che ha perso il dispositivo: verifica prima la sua identità con un altro mezzo (di persona, Matrix), poi clicca su **Rimuovi i dispositivi**, indica il motivo (come è stata verificata l'identità) e clicca su **Rimuovi e disconnetti**. L'account viene disconnesso ovunque e la rimozione viene registrata. Questa operazione richiede che la tua sessione sia passata per il codice.

---

## 6. Lingue disponibili

L'interfaccia è disponibile in 10 lingue :
- 🇧🇷🇵🇹 Português (lingua di riferimento)
- 🇫🇷 Français
- 🇪🇸 Castellano
- 🇬🇧 English
- 🇮🇹 Italiano
- 🇩🇪 Deutsch
- 🇳🇱 Nederlands
- 🇬🇷 Ελληνικά
- Català
- Esperanto

Le biografie degli autori/trici possono essere tradotte indipendentemente in ogni lingua.

I titoli delle opere sono pretradotti automaticamente nelle dieci lingue; portano la dicitura « correggimi » finché una persona non li rilegge.

---

*AnarBib — Rete di biblioteche libertarie*
*Software libero per la gestione cooperativa del sapere militante*
