# Guida — Scansione e QR Code in AnarBib

> **A chi serve questa guida.** A qualsiasi compagn* di biblioteca che voglia
> usare la fotocamera del telefono (o del computer) per guadagnare tempo:
> identificare un* lettore/trice dalla tessera, recuperare i dati di un libro
> tramite il codice a barre, o verificare il patrimonio. Scritta su richiesta —
> e per il **patrimonio comune** della rete.
>
> **Spirito.** Niente qui ti sorveglia né ti valuta. La lettura dei codici avviene
> **100 % sul tuo dispositivo**: nessuna immagine della fotocamera viene inviata
> da nessuna parte. Gli strumenti sono qui per darti autonomia, non per
> imprigionarti. Se qualcosa non funziona, **il catalogo non si rompe mai** —
> nel peggiore dei casi basta digitare a mano.
>
> Fa parte del **patrimonio comune di sapere** del mutuo appoggio (vedi il
> quadro « il mutuo appoggio nella catalogazione »). Si scrive per comunità
> linguistica: se vuoi una versione in un'altra lingua, si costruisce in
> parallelo, non per traduzione dall'alto.

---

## Cosa si può scansionare

AnarBib ha **un solo lettore di fotocamera**, riutilizzato in tre punti:

| Dove | Cosa si scansiona | Per cosa |
|---|---|---|
| **Pannello › Gestire lettore/trice** | QR della **tessera** | Identificare il/la lettore/trice in un istante |
| **Catalogazione** (scheda del libro) | **codice a barre ISBN** | Recuperare titolo/autore/trice automaticamente |
| **Pannello › Inventario** | QR delle **etichette di esemplare** | Verificare il patrimonio (rilevamento) |

In tutti i casi: la fotocamera si apre all'interno di AnarBib, legge il codice, e
il gioco è fatto. Non è necessario installare nessuna applicazione. Se vuoi, puoi
**aggiungere AnarBib alla schermata Home** del telefono (menu del browser ›
« Aggiungi alla schermata Home »): si apre a schermo intero come un'app, ma
rimane il sito.

---

## 1. Tessera lettore/trice

**Chi crea la tessera:** il/la lettore/trice stesso/a, dal proprio account
(`/conta`), quando la biblioteca ha attivato la funzione. Genera un QR Code e
può scaricarlo in PNG o PDF. Il QR contiene solo un **codice opaco** — nessun
nome, nessun dato personale al suo interno.

**Come si usa, allo sportello:**

1. Vai in **Pannello › Gestire lettore/trice**.
2. Clicca su **« Scansiona la tessera »** e punta la fotocamera sul QR della tessera.
3. AnarBib risolve il codice e mostra **chi è** il/la lettore/trice (e se vi sono
   restrizioni attive). Pronto* per prestare, restituire, ecc.

> **« Tessera non riconosciuta »?** Quasi sempre si tratta di una **tessera
> vecchia**. Quando un* lettore/trice genera una nuova tessera, la precedente viene
> **revocata** (misura di sicurezza). Chiedi di generare/scaricare la tessera
> attuale. Dal 15/06, il sistema stesso avvisa « tessera sostituita, generane una
> nuova » in questo caso.

---

## 2. Scansionare l'ISBN in fase di catalogazione

Quando si schededa un libro con codice a barre (ISBN), si può evitare di digitare
tutto a mano:

1. Nella scheda del libro (catalogazione), apri il pannello di **ricerca metadati**.
2. Clicca su **« Scansiona l'ISBN »** e punta sul **codice a barre** nel retro del
   libro.
3. Il numero entra da solo nel campo ISBN e AnarBib **cerca i dati** (titolo,
   autore/trice…) nelle fonti pubbliche. Tu revisioni e aggiusti — il catalogo è
   tuo.

> **Consiglio sul dispositivo.** Il codice a barre è più « esigente » del QR.
> **Il telefono di solito legge molto meglio** della webcam di un computer fisso
> (messa a fuoco e risoluzione della fotocamera). Se la webcam non riesce, non
> insistere: digita l'ISBN a mano — il risultato è lo stesso.

---

## 3. Inventario del patrimonio (rilevamento)

Verificare, esemplare per esemplare, cosa si trova effettivamente sullo scaffale —
confrontandolo con ciò che il sistema ritiene che la biblioteca possegga.

**Prima:** le etichette degli esemplari devono avere il **QR Code**. Stampa le
etichette con QR in **Catalogazione › Etichette** (c'è un'opzione « Includi QR
code »). Ogni QR punta all'esemplare.

**Eseguire l'inventario:**

1. Vai in **Pannello › Inventario** (visibile per *librarian* e *coordinatore/trice*).
2. **« Avvia inventario »** — apre una sessione e mostra quanti esemplari ha la
   biblioteca.
3. La fotocamera rimane aperta: **passa gli esemplari uno dopo l'altro**, un QR
   dopo l'altro. A ogni lettura si sente un **bip** e il contatore sale. Non è
   necessario chiudere e riaprire la fotocamera tra un libro e l'altro.
   - ✓ verde = esemplare del patrimonio, conteggiato.
   - « Già letto » = era già stato passato (nessun problema, non viene contato due volte).
   - ⚠ « Fuori patrimonio » = un esemplare che **non appartiene** a questa biblioteca (intruso).
4. Se qualche QR è danneggiato, si può **digitare a mano** (URL dell'etichetta o
   il numero dell'esemplare).
5. **« Termina e vedi il rapporto »** — chiude la sessione e mostra:
   - **Presenti** (scansionati e del patrimonio),
   - **Mancanti** (del patrimonio, ma non scansionati → cercare / eliminare),
   - **Intrusi** (scansionati, ma di un'altra biblioteca / sconosciuti).
6. Esporta il risultato in **CSV** (per foglio di calcolo) o **PDF** (per stampare
   la lista dei mancanti e andare a cercarli sugli scaffali).

> **Sospendere e riprendere.** Inventario lungo? Si può chiudere dopo. Se si esce a
> metà, la sessione rimane **in corso** e appare in « Sessioni in corso » per
> **riprendere** da dove ci si era fermati.

---

## Domande pratiche

**Devo installare qualcosa?** No. È il sito stesso. Facoltativamente, « Aggiungi
alla schermata Home » per aprirlo come app.

**Funziona nel mio browser?** Sì. In Chrome/Android usa il lettore nativo (più
veloce). In **Brave**, **iOS/Safari** e **Firefox** AnarBib carica automaticamente
un lettore alternativo — quindi **funziona anche** su questi. Se appare « lettura
non compatibile » quando si scansiona un ISBN su uno di questi, aggiorna la
pagina: il lettore alternativo si attiva da solo.

**La fotocamera non si apre.** Verifica di aver dato il **permesso fotocamera** al
sito (lucchetto nella barra degli indirizzi). Il browser consente la fotocamera
solo in **HTTPS** — `app.anarbib.org` lo è già.

**Privacy.** La decodifica è **locale**. L'immagine della fotocamera **non viene
inviata** ad alcun server. Il QR della tessera contiene solo un codice opaco; il
QR dell'etichetta contiene solo l'indirizzo dell'esemplare. I fondi sensibili (BTL
e simili) restano protetti dalle stesse regole di sempre.

---

## In una frase

La fotocamera è **una mano tesa** per risparmiarti digitazione e verifiche — non
un obbligo. Usala quando ti aiuta; ignorala quando no. E se si blocca, la tastiera
è sempre lì.

---

*Documento del patrimonio comune AnarBib. Miglioramenti e versioni in altre lingue
sono benvenut*, scritt* in parallelo dalla comunità di ciascuna lingua.*
