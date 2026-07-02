# Il thesaurus FICEDL in AnarBib — consultare un vocabolario comune

> **Per chi?** Per ogni compagn* che catalogare e vuole collegare i propri libri al
> **vocabolario per soggetti condiviso** dal movimento — quello mantenuto dalla FICEDL.
> Questa guida spiega cos'è questo thesaurus, a quali condizioni AnarBib vi si
> connette, a cosa serve, e come usarlo quotidianamente.
>
> **Spirito.** AnarBib **consulta** il thesaurus; non se ne appropria. Il
> vocabolario resta quello della FICEDL, che ne è la fonte **che fa fede**. Nulla
> qui crea una versione concorrente: la nostra copia è solo un *riflesso* fedele.

---

## Cos'è il thesaurus FICEDL?

La **FICEDL** — Federazione internazionale dei centri di studi e documentazione
libertari — federa dal 1979 CIRA, atenei, CCL e biblioteche anarchiche di tutto il
mondo. Mantiene un **thesaurus**: un *vocabolario controllato* della documentazione
libertaria — un elenco ragionato di **termini-soggetto** (i soggetti), organizzati e
tradotti, per descrivere di cosa *parlano* i documenti. Copre le stesse **dieci
lingue** di AnarBib (esattamente quelle proposte dal CIRA di Losanna) e raccoglie
diverse centinaia di termini (dell'ordine di seicento). È consultabile pubblicamente
su `thesaurus.ficedl.info`.

Un thesaurus non è un semplice dizionario: è un **grafo di concetti**. I termini vi
si collegano (più ampio · più ristretto · associato) e portano delle **note
d'applicazione** che dicono come impiegarli. AnarBib si appoggia su **SKOS**, lo
standard libero del web semantico per questo tipo di vocabolario.

## A quali condizioni è entrato in AnarBib

Adottare un vocabolario comune è anzitutto una **decisione politica** — quella di
collettivi che scelgono di parlare la stessa lingua documentaria — e la tecnica vi si
conforma. Concretamente, AnarBib ha ripreso il thesaurus **dal sito della FICEDL**
(`thesaurus.ficedl.info`) **intorno al 24 giugno 2026**, importandone i **termini** e
i **luoghi** (le voci geografiche) — lasciando da parte le **date** (le voci
cronologiche). Questa connessione segue alcuni **principi chiari**, che sono le
*basi dell'accordo*:

1. **Fonte canonica unica.** Il thesaurus che *fa fede* è quello della FICEDL.
   AnarBib non detiene *il* thesaurus: ne tiene una copia di lavoro.
2. **Nessun fork.** La nostra copia è un **riflesso** della versione FICEDL, mai una
   versione rivale. L'interoperabilità auspicata dalla FICEDL è così garantita *per
   costruzione*.
3. **Consultare, non modificare.** AnarBib **non tocca** le parole scelte dalla
   FICEDL. Un'unica libertà, e solo dalla nostra parte: **rimettere a posto
   un'etichetta di lingua mal classificata** (una traduzione archiviata sotto un
   codice di lingua sbagliato), unicamente per non *perdere* una traduzione già
   esistente — senza mai cambiare il termine stesso.
4. **Segnalare, non correggere.** Ogni altra anomalia — una lingua mancante, un
   refuso in un termine — **non** viene rettificata da noi: viene **segnalata**
   alla FICEDL, che corregge *la sua* versione di riferimento.
5. **Ri-sincronizzazione.** Dopo le correzioni della FICEDL, AnarBib
   **ri-sincronizza** la propria copia. Il riflesso si aggiorna; non diverge mai.
6. **Vocabolario libero e condiviso.** Il thesaurus è **liberamente condivisibile**
   (nessun diritto proprietario lo blocca). La sua evoluzione avviene
   **collettivamente**, proprio per *limitare i fork* e preservare
   l'interoperabilità tra biblioteche.
7. **Evoluzione portata dal collettivo.** Alcune aree del vocabolario necessitano di
   essere aggiornate (per esempio le categorie legate alle tematiche LGBTQI+). Queste
   evoluzioni non si decretano dall'alto: si discutono **in seno alla federazione**.

In sintesi: il thesaurus resta **al 100% quello della FICEDL**; AnarBib ne è uno
specchio leale, e un **relè** che riporta ciò che vi rileva.

## A cosa serve

- **Descrivere per soggetto.** Nella catalogazione, il campo **« Soggetti »
  (autorità soggetto)** collega un documento a uno o più termini del thesaurus. È
  ciò che permette di ritrovare un libro per **ciò di cui parla**, non solo per il
  suo titolo o la sua autrice.
- **Navigare per tema.** Questi termini alimentano le **faccette** e la navigazione
  tematica del catalogo pubblico.
- **Parlare dieci lingue in una volta.** Uno stesso concetto porta la sua etichetta
  in ciascuna delle dieci lingue: una lettrice ispanofona e un lettore grecofono
  incontrano *lo stesso soggetto*, ciascun* nella propria lingua.
- **Collegare le biblioteche.** Poiché tutt* si appoggiano sullo **stesso**
  vocabolario, i cataloghi diventano comparabili e scambiabili — è la base della
  mutualizzazione (doppioni, prestiti interbibliotecari, meta-catalogo).

## Come usarlo concretamente

1. **Cerca un termine in « Soggetti ».** Nella catalogazione, inizia a digitare nel
   campo **Soggetti**: AnarBib propone i termini del thesaurus, con la loro
   gerarchia. Riusa l'esistente piuttosto che inventare.
2. **Scegli la granularità giusta.** Né troppo ampio, né troppo ristretto: il
   termine che *qualcuno userebbe per cercare* questo libro. Da due a quattro
   soggetti bastano in genere.
3. **Leggi la nota d'applicazione** se il termine ne ha una: dice come impiegarlo.
4. **Etichetta mancante nella tua lingua (⚐).** Se un soggetto non ha ancora
   un'etichetta **nella tua lingua**, viene mostrato per **ripiego** (spesso in
   un'altra lingua) con un ⚐. Non è un bug: è una **lacuna della versione di
   riferimento**. Non la si aggiusta da noi — vedi sotto.
5. **Un errore, una lacuna? Segnala, non correggere.** Termine errato, traduzione
   assente: **segnalalo al coordinamento**, che lo trasmette alla FICEDL. La
   correzione avviene sulla fonte canonica, e ci torna poi tramite
   ri-sincronizzazione. *(Unica eccezione, già detta: un'etichetta di lingua
   semplicemente mal classificata può essere rimessa a posto dalla nostra parte,
   senza toccare la parola.)*
6. **Serve un termine che non esiste?** Il thesaurus non si arricchisce
   *localmente*. Nell'immediato, le **parole chiave libere** (testo libero, proprie
   alla scheda) sono la valvola di sfogo — vedi la guida « Indicizzare per
   soggetto ». A medio termine, una proposta di aggiunta **risale al collettivo**
   della FICEDL.

## Lo spirito: consultare, non catturare

Questa connessione è **una mano tesa**, non una presa: AnarBib *prende in prestito*
un vocabolario comune senza appropriarsene, lo *riflette* senza *fissarlo*, e
*restituisce* alla FICEDL ciò che vi osserva. Il thesaurus resta vivo dove deve
esserlo — nella federazione che lo porta — e il nostro catalogo ne beneficia senza
mai competere con esso. È, a livello delle parole, la stessa etica di sempre in
AnarBib: **offrire e collegare, mai catturare**.

> Vedi anche: la guida **« Indicizzare per soggetto »** (il gesto concreto nella
> catalogazione) e l'inquadramento **« Il mutuo appoggio nella catalogazione »** (il
> comune di sapere di cui questo vocabolario è il cuore). Il thesaurus di
> riferimento è consultabile su `thesaurus.ficedl.info` — fonte canonica che fa
> fede.

*Documento del comune AnarBib. Il thesaurus stesso è opera della FICEDL; questa
guida ne spiega solo l'uso in AnarBib.*
