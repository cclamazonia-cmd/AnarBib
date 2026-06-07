---
title: "Guida alla governance di AnarBib"
subtitle: "Ad uso dei coordinatore/trice di biblioteca e degli amministratore/trice della rete"
author: "Projet AnarBib"
date: "Versione 1.1 — 5 giugno 2026"
lang: it
---

# Prefazione

Questa guida si rivolge alle persone che, nella rete AnarBib, svolgono una funzione di coordinamento — che si tratti di coordinare una biblioteca locale o di amministrare la rete. Ha un duplice obiettivo:

- **Spiegare la logica politica** delle regole iscritte nel SIGB AnarBib, e la loro filiazione con il progetto di emancipazione collettiva che ha dato origine alle biblioteche anarchiche;
- **Fornire strumenti pratici** per il quotidiano, rispondendo alle domande concrete che i coordinamento/trice incontrano quando usano il software.

## Una convenzione politica

Questa guida non è il regolamento della rete, e non ha alcuna autorità superiore alle decisioni dei collettivi che la compongono. Ciò che contiene ha forza solo perché degli esseri umani si sono accordati per far funzionare le cose in questo modo in un determinato momento. Se le pratiche si evolvono, questo testo dovrà evolversi con esse, o essere contraddetto, o essere strappato. È l'uso che ne faranno i collettivi a deciderne il destino.

Le regole tecniche che il SIGB AnarBib fa rispettare — i periodi di attesa, i workflow di cooptazione, gli status dei membership, ecc. — sono anch'esse convenzioni. Sono state scritte da compagn* in date precise, per risolvere problemi precisi. Sono consegnate in **file di specifica** (gli `spec-*.md` del deposito), datati e firmati, essi stessi emendabili. Quando si legge questa guida, si legge lo stato di un dibattito in un dato momento. Non è una costituzione.

## Come è organizzata questa guida

La guida è in due parti:

- **Parte I — Il perché.** Quattro capitoli che pongono il quadro politico: a cosa serve un SIGB anarchico, quali sono i suoi principi fondatori, come si articolano i due perimetri (biblioteca locale e rete), e come le stesse regole possono essere emendate.

- **Parte II — Il come.** Sei capitoli pratici che trattano ciascuno una grande questione operativa: cooptare, rimuovere, gestire le situazioni che degenerano, esercitare una funzione di admin di rete, garantire la trasparenza, e un ultimo capitolo che commenta casi concreti dall'inizio alla fine.

Alla fine di ogni capitolo pratico, una rubrica **"Se la regola vi pesa"** ricorda dove discuterne e come proporre un emendamento. È importante perché queste regole hanno senso solo se emendabili.

Le appendici in fondo al volume servono da riferimento rapido: glossario, indice delle funzioni tecniche con la loro traduzione politica, modello di proposta di emendamento, e link alle spec sorgenti.

## Come leggere questa guida

La si può leggere tutta d'un fiato, ma probabilmente non è l'uso migliore. Tre modi di entrare nel testo secondo le necessità:

- **Per capire lo spirito del progetto** prima di assumere una funzione: leggere la parte I (capitoli da 1 a 4).
- **Di fronte a una situazione concreta**: saltare direttamente al capitolo pratico pertinente (da 5 a 10).
- **Per informarsi in vista di un'AG** in cui una questione di governance verrà posta: leggere il capitolo pertinente più la rubrica "Se la regola vi pesa" corrispondente, e consultare la spec sorgente nell'appendice D.

Ciò che è scritto qui si basa su quattro documenti di specifica:

- `spec-gouvernance-roles.md` (5 maggio 2026) — ruoli, status, transizioni;
- `spec-administrateur-reseau.md` (11 maggio 2026) — separazione locale/rete, cooptazione all'unanimità;
- `spec-validation-physique.md` (3 maggio 2026) — modalità di accoglienza degli account lettore/trice;
- `spec-refactor-v3-semantique.md` (9 maggio 2026) — semantica del workflow di prenotazione (citato in margine).

I riferimenti a queste spec sono richiamati nel corso del testo nella forma `(cf. spec-gouvernance, §3.4)` per permettere di approfondire.

## Una nota sulla voce

Il testo alterna tra **si** (il collettivo AnarBib, di cui l'autore/trice e il/la lettore/trice fanno ugualmente parte), **voi** (quando ci si rivolge a un/una coord o admin precis* che deve fare una scelta), e **noi** (quando si parla dei compagn* che hanno scritto le regole, in un determinato momento, e che potrebbero essere diversi da chi le legge). È intenzionale. Non c'è neutralità istituzionale qui: questo testo è portato da compagn*, e si rivolge a compagn*.

\newpage

# Parte I — Il perché

\newpage

# 1. Un SIGB anarchico, cosa significa?

## 1.1. Il SIGB non è l'AG

Il primo principio da tenere, e il più difficile, è questo: **il SIGB registra le decisioni del collettivo, non le prende**. Questa frase sembra innocua. In realtà è il perno attorno al quale tutto il resto si organizza.

Tutte le volte in cui il SIGB AnarBib assume l'aria di un'autorità — quando rifiuta una promozione, quando impone un periodo di attesa di sette giorni, quando blocca una transizione di status — non fa che **rendere eseguibile** una regola che i collettivi si sono dati. La regola è stata scritta da qualche parte, in una spec, dopo discussione. Qualcuno ha riletto e criticato. Una versione è stata fissata e deployata. E ora, nell'istante in cui si clicca sul pulsante, il software si limita ad applicare ciò che era stato convenuto.

Se trovate la regola stupida, controproducente, o ingiusta, non è il SIGB che bisogna combattere. È la spec che bisogna emendare. Vedere capitolo 4.

## 1.2. La tensione assunta

Ogni software che gestisce permessi è, per costruzione, un dispositivo di gerarchizzazione. Bisogna pur che qualcuno possa validare un'iscrizione, modificare l'identità pubblica di una biblioteca, accedere ai dati personali di un/una lettore/trice. Questa necessità tecnica è in tensione apparente con l'ideale di orizzontalità che anima le biblioteche anarchiche.

AnarBib **assume questa tensione** piuttosto che nasconderla. Il compromesso politico trovato si regge su due punti:

- I **ruoli non sono gradi**. Sono **funzioni** temporaneamente delegate dal collettivo ad algun* dei suoi membri per eseguire compiti tecnici precisi. Nessuno è coordinatore/trice "a vita". Nessuno è admin di rete "per essenza". Queste funzioni sono prestate, e possono essere riprese.

- I **meccanismi di revoca** contano quanto i meccanismi di nomina. Il SIGB prevede esplicitamente come qualcuno esce da una funzione — per auto-retrocessione, per richiesta collettiva con periodo di attesa, per auto-uscita dalla rete, per revoca collettiva all'unanimità. Una funzione che non può essere abbandonata non è una funzione, è una captazione.

## 1.3. Delega e rotazione

L'idea centrale è quella della **delega con rotazione**. Un collettivo delega ad alcuni dei suoi membri l'esecuzione di compiti tecnici (gestire i prestiti nel SIGB, modificare la visibilità della biblioteca, accogliere un nuovo membro nel team). Questa delega è:

- **Esplicita**: si incarna in un atto di cooptazione tracciato nell'audit log;
- **Reversibile**: la persona delegata può lasciare la funzione quando vuole, e il collettivo può chiederlo secondo modalità definite;
- **Temporanea per natura**: anche se nessuna durata è imposta dal SIGB, la cultura politica della rete è che si fanno ruotare le funzioni, e non ci si installa.

È questa rotazione delle funzioni che fa la differenza tra una "delega" (anarchica) e una "gerarchia" (statale o capitalista). Se ci si installa in una funzione, si diventa un gradino. Se se ne esce regolarmente, si rimane un/una compagn* che rende un servizio.

## 1.4. Gli otto principi fondatori

La spec governance dei ruoli (`spec-gouvernance-roles.md`, §2) esplicita otto principi fondatori. Li elenchiamo qui per riferirsi ad essi nel prosieguo della guida; ogni capitolo pratico della parte II vi farà rimando.

**P1 — Delega, non gerarchia.** Nessun ruolo è un titolo. Tutti i ruoli sono temporanei per natura e revocabili.

**P2 — Cooptazione per i ruoli staff.** L'ingresso in un team (diventare librarian o coordenador) avviene per cooptazione dei coordenadores esistenti. È il collettivo a decidere chi viene ammess*; il/la coordenador/a è solo la mano che esegue la decisione nel SIGB.

**P3 — Retrocessione volontaria sempre possibile.** Ogni persona con un ruolo staff può retrocedere se stessa in qualsiasi momento, senza consultazione. "Passo la mano" è un diritto fondamentale.

**P4 — Esclusione regolamentata da un periodo di attesa.** L'esclusione non volontaria di un/una librarian da parte di un/una coordenador/a passa attraverso un periodo di attesa di sette giorni prima di avere effetto. Questo periodo permette la deliberazione collettiva e l'eventuale annullamento da parte di un/un'altra coordenador/a.

**P5 — Trasparenza massima.** L'audit log dei cambiamenti di ruolo è leggibile dall'insieme dello staff attiv* della biblioteca, non solo dai coordenadores. Impedire le manipolazioni opache fa parte della cultura politica di orizzontalità informativa.

**P6 — Notifiche sistematiche.** Ogni cambiamento di ruolo scatena un'email alla persona interessata e a tutto il coordinamento. Nessuno può essere modificato nel proprio ruolo senza saperlo, e il coordinamento è sempre informato.

**P7 — Sovranità locale delle biblioteche.** I cambiamenti di ruolo nella biblioteca A non influenzano nulla nella biblioteca B, anche per la stessa persona. Ogni biblioteca è sovrana sulle proprie deleghe interne.

**P8 — Il SIGB non modella l'AG.** Il SIGB esegue le decisioni, non le prende. Non contiene alcun meccanismo di voto, quorum, o deliberazione. Queste cose avvengono in collettivo, fuori dal software.

## 1.5. Ciò che il SIGB non fa

È utile rendere esplicite le scelte di **non-modellazione**:

- Il SIGB **non definisce** cos'è un "buon" coordinamento. Una biblioteca può decidere in cerchio, in AG plenaria, per turnazione, per sorteggio, per consenso, per maggioranza. Il SIGB non se ne occupa.
- Il SIGB **non misura** la legittimità politica di una cooptazione. Se un/una coord clicca su "promuovi X librarian", il SIGB registra. È al collettivo assicurarsi che la decisione sia stata presa correttamente, ed è nella cultura politica del collettivo che si gioca questa garanzia.
- Il SIGB **non arbitra** i conflitti. Quando qualcosa degenera, il SIGB fornisce strumenti (sospensione immediata, richiesta di revoca, audit log leggibile) ma la decisione politica rimane fuori dal software.

Questa modestia non è un difetto, è un'esigenza. Un SIGB che pretendesse di modellare la vita politica di un collettivo sarebbe, ipso facto, autoritario — imporrebbe la propria visione di cosa è una "buona" decisione. AnarBib rifiuta questa deriva.

## 1.6. E il rispetto delle libertà digitali?

Tre precisazioni, perché la questione ritorna:

- **Dati personali**: gli account lettore/trice contengono ciò che la persona ha voluto inserire. Le biblioteche hanno accesso solo ai dati strettamente necessari al loro funzionamento. I membership in altre biblioteche sono, per costruzione, stagni (P7).

- **Audit log**: il log è pubblico **allo staff attiv*** della biblioteca, non ai lettore/trice né al resto della rete. Questa trasparenza interna serve a impedire le manipolazioni opache tra coordinamenti; non è un panopticon diretto contro i lettore/trice.

- **Log cross-biblioteche**: quando un/una admin di rete interviene su una biblioteca (caso coperto dalla spec admin-reseau, §6.3.1), l'azione è tracciata in una tabella dedicata con livello di criticità. È leggibile dagli admin di rete e dal coordinamento della biblioteca interessata. La trasparenza in entrambe le direzioni.

\newpage

# 2. I due perimetri: biblioteca locale e rete

## 2.1. Perché questa separazione

La rete AnarBib non è una catena di biblioteche con una sede centrale. È una **federazione di collettivi autonomi**. Questa realtà politica ha finito per imporsi nella struttura del SIGB stesso.

Inizialmente, nelle prime versioni, il ruolo di "amministratore AnarBib" era legato a una biblioteca precisa nella tabella `user_library_memberships`. Questa modellazione suggeriva — senza dirlo — che un/una admin AnarBib *amministrasse una biblioteca*. Non era politicamente vero: un/una admin di rete anima il coordinamento inter-biblioteche, non dirige nessuna biblioteca in particolare.

La spec `spec-administrateur-reseau.md` (11 maggio 2026) ha sancito la separazione. D'ora in poi il SIGB conosce **due perimetri distinti**:

- **Lo staff locale** di una biblioteca (ruoli `reader`, `librarian`, `coordenador`), memorizzato in `user_library_memberships`. La sua autorità politica si situa **nel perimetro della biblioteca**.

- **L'amministrazione della rete** (tabella `network_administrators`), senza collegamento a una biblioteca. La sua autorità politica è **trasversale**, ma non si sostituisce mai all'autonomia locale.

## 2.2. Cosa fa ciascun perimetro

**Lo staff locale** gestisce il quotidiano di una biblioteca: prestiti, resi, prenotazioni, validazione delle iscrizioni, modifica del regolamento, delle politiche di circolazione, dell'identità pubblica della biblioteca. Tutto ciò che riguarda il funzionamento di **una** biblioteca si risolve a livello dello staff locale.

**L'amministrazione della rete** assicura il coordinamento inter-biblioteche: attivazione delle nuove biblioteche, moderazione del catalogo condiviso, manutenzione tecnica della piattaforma, accoglienza dei nuovi collettivi, e intervento eccezionale quando una biblioteca si trova in blocco (nessun/nessuna coord attiv*, conflitto grave, ecc.). Tutto ciò che riguarda la **rete** si risolve a livello dell'amministrazione di rete.

## 2.3. La regola della non-sovrapposizione

Una regola politica semplice guida tutti i contatori e tutte le viste del SIGB:

> **Ogni pagina racconta la storia del suo perimetro. Un contatore conta ciò che è iscritto nel suo perimetro, né più né meno.**

Concretamente:

- La pagina di una biblioteca conta i suoi membership locali. Punto. Gli admin di rete non appaiono in questi contatori, anche se possono tecnicamente intervenire sulla biblioteca.
- La pagina della rete conta i suoi amministratore/trice di rete. Punto.

Se una persona è al tempo stesso `coordenador` di una biblioteca **e** amministratore/trice di rete (il caso di Xavier all'11 maggio 2026), appare in entrambi i contatori, **una volta in ciascuno**, senza deduplicazione incrociata. Sono **due iscrizioni politiche distinte**, contate ciascuna nel proprio perimetro.

Perché questa regola è politicamente sana, in quattro punti:

- **Onestà**: il tuo impegno locale è contato nella biblioteca in cui sei attiv*; il tuo impegno di rete è contato a livello di rete. Nessuno ti conta "1,5 volte".
- **Leggibilità**: un/una militante che guarda la scheda di una biblioteca vede immediatamente quante persone sono impegnat* **localmente**, senza doversi chiedere se degli admin di rete "estern*" gonfiano il contatore.
- **Robustezza**: se domani si aggiungono ruoli intermedi (ausiliario/a, stagist*, osservatore/trice), la regola "pagina = perimetro" rimane chiara.
- **Coerenza politica**: la separazione tra admin di rete e staff locale è una **decisione politica**, non un dettaglio di modellazione. I contatori devono rifletterla.

## 2.4. Il diritto trasversale dell'admin di rete

Questo punto merita di essere ben compreso perché è facile fraintenderlo.

**Un/una admin di rete può tecnicamente intervenire su qualsiasi biblioteca.** Può, per esempio, leggere il catalogo di una biblioteca `private`, modificarne la visibilità, o — in casi eccezionali — creare o modificare dei membership. È ciò che la spec chiama il **diritto di intervento trasversale**.

Questo diritto esiste per due ragioni:

- **Manutenzione**: bisogna pur che qualcuno possa sbloccare una biblioteca che si è inceppata (nessun/a coord, configurazione rotta, ecc.).
- **Mediazione**: quando un conflitto grave attraversa una biblioteca e impedisce al collettivo locale di funzionare, bisogna un ricorso.

Ma questo diritto **non fa** dell'admin di rete un/una superiore gerarchic* del coordinamento locale. La dottrina della rete, posta in questa guida:

> **Un intervento di admin di rete su una biblioteca locale deve essere preceduto da un'informazione al coordinamento locale interessato**, salvo urgenza vitale (compromissione attiva, molestie in corso, attacco contro la piattaforma). L'informazione preventiva non è una richiesta di autorizzazione: l'admin di rete ha il diritto di agire. Ma è una **prova di rispetto** verso l'autonomia della biblioteca, e preserva la possibilità di un altro accordo (per esempio: "lasciami provare a sistemarlo prima, ti tengo aggiornat*").

La tracciabilità tecnica esiste peraltro: tutte le azioni cross-biblioteche di un/una admin di rete sono tracciate nella tabella `cross_library_actions_log` con un livello di criticità, leggibili dal coordinamento locale a posteriori.

## 2.5. La sovranità locale è inviolabile

Un'ultima precisazione politica, che discende dal principio **P7 — Sovranità locale delle biblioteche**.

Le biblioteche della rete AnarBib **si riconoscono reciprocamente**. Quando BLMF valida fisicamente un/una nuov* lettore/trice (cf. `spec-validation-physique.md`), questa validazione vale per tutte le biblioteche `network` della rete. È un **patto di circolazione implicito** tra biblioteche che condividono abbastanza cultura politica per fidarsi l'una dell'altra.

Ma questo riconoscimento reciproco **non dà nessun diritto di ingerenza** di una biblioteca in un'altra. Il coordinamento della biblioteca A non può modificare i membership della biblioteca B. Non può vedere i dati personali dei lettore/trice di B (salvo quelli che sono anche iscritti da lei). Non può cambiare il regolamento di B.

Ogni biblioteca rimane **sovrana sulle proprie deleghe interne**, sulla propria politica di accoglienza, sul proprio modo di validazione, sulle proprie regole di quota associativa, sul proprio regolamento interno. La rete non dice come devono funzionare. Dice solo con chi si riconoscono.

\newpage

# 3. Statuti, ruoli, transizioni: la grammatica del SIGB

Questo capitolo è un po' più arido degli altri. Vi si pone il vocabolario tecnico che sarà utilizzato nel corso di tutta la guida. Se lo saltate alla prima lettura, potrete tornarvici all'occorrenza.

## 3.1. I quattro ruoli

Il SIGB AnarBib utilizza quattro ruoli, dichiarati nel database tramite il vincolo `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` sulla tabella `user_library_memberships`.

**`reader`** — Account di lettor/trice di base. Nessun potere di amministrazione. Permessi: consultare il catalogo (secondo la visibilità della biblioteca), prendere in prestito, prenotare, consultare in sala, modificare i propri dati personali, richiedere la migrazione o la cancellazione del proprio account.

**`librarian`** — Staff operativ*. Gestisce il quotidiano: prestiti, prenotazioni, resi, validazione delle iscrizioni (secondo la modalità della biblioteca), modifica dei dati del catalogo, accesso ai dati personali dei lettori/trici della biblioteca. **Sola lettura** sull'elenco del team. Riceve le notifiche dei cambiamenti di ruolo e può leggere l'audit log del team (P5).

**`coordenador`** — Staff di coordinamento. Tutto ciò che ha un/una librarian, più: modificare l'identità pubblica della biblioteca (nome, logo, contatti, ecc.), modificare la configurazione (politiche di prestito, regolamento), gestire le regole di quota associativa, **e tutte le azioni di governance del team**: cooptare, richiedere una rimozione, sospendere, revocare una sospensione, annullare una richiesta di rimozione.

**`administrador`** — Ruolo storico, in via di eliminazione. Esisteva per indicare «diritto di amministrazione cross-biblioteche» ma collegato a una `library_id`. Ora sostituito dagli **amministratori/trici di rete** memorizzat* nella tabella `network_administrators` (cfr. capitolo 2). La spec admin-reseau prevede la migrazione progressiva e la rimozione finale di questo ruolo dalla tabella `user_library_memberships`.

## 3.2. I cinque statuti di una membership

Ogni riga della tabella `user_library_memberships` ha uno **statuto** che esprime lo stato della delega in un dato momento. Sono possibili cinque statuti:

**`active`** — Stato normale. La persona ha il suo ruolo e lo esercita.

**`pending`** — Riservato alla spec di validazione fisica. La membership è creata ma in attesa di un incontro fisico con un/una librarian+ della biblioteca di iscrizione. Nessun accesso alle funzioni del ruolo finché sussiste questo statuto.

**`suspended`** — **Misura conservativa** adottata da un/una coordenador/a. Nessun accesso. Utilizzo: molestie segnalate in attesa di indagine, account compromesso, conflitto in corso di mediazione. **Durata indefinita**; la revoca è manuale, da parte di un/una coord (ritorno a `active`) o per destituzione effettiva.

**`pending_removal`** — **Periodo di carenza di sette giorni** prima dell'esclusione effettiva. Nessun accesso durante questo periodo. Evoluzione possibile: annullamento da parte di un/una altro/a coord (ritorno `active`), auto-retrocessione da parte della persona stessa (cortocircuito), oppure passaggio automatico a `inactive` a J+7.

**`inactive`** — Membership chiusa. La persona non fa più parte del team. Nessun accesso. Diverse origini possibili: uscita volontaria, fine del periodo di carenza, account abbandonato (automatico a 9 mesi).

## 3.3. Lo schema delle transizioni

Il SIGB non autorizza qualsiasi transizione tra statuti. Ecco, in forma semplificata, lo schema autorizzato:

```
                       ┌──────────────┐
                       │   active     │ ◄──────────┐
                       └──────┬───────┘            │
                              │                    │
              ┌───────────────┼───────────────┐    │
              ▼               ▼               ▼    │
       ┌─────────────┐  ┌─────────────┐  ┌─────────┴────┐
       │  suspended  │  │ pending_    │  │  inactive    │
       │             │  │ removal     │  │              │
       └──────┬──────┘  └──────┬──────┘  └──────────────┘
              │                │
              │ revoca         │ annullamento
              └────────────────┴────────────┐
                               │            │
                               ▼ (J+7)      ▼
                        ┌──────────────┐
                        │   inactive   │
                        └──────────────┘
```

Alcune regole chiave:

- **Non** si può passare direttamente da `active` a `inactive` per un/una librarian per decisione unilaterale di un/una altro/a coord. Bisogna passare per `pending_removal` e attendere la carenza (o che la persona si retroceda da sola).
- Si può **sempre** passare dal proprio statuto `active` a `inactive` (auto-retrocessione, diritto P3).
- `suspended` **non** ha durata massima. Non è una carenza prima dell'esclusione, è una misura conservativa — dura il tempo della deliberazione.
- Da `inactive`, **non si torna** a `active`. Per reintegrare una persona, si crea una nuova riga di membership. La cronologia è preservata.

## 3.4. Le nove transizioni, chi può fare cosa

La spec di governance dei ruoli formalizza nove transizioni, elencate qui in forma condensata. Il dettaglio operativo è nella parte II.

| # | Transizione | Chi | Meccanismo |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coord+ | Cooptazione |
| T2 | `librarian` → `coordenador` | Coord+ | Cooptazione |
| T3 | `coordenador` → `librarian` | Sé stess* OPPURE altri/e coord | Auto-retrocessione OPPURE rimozione collegiale con carenza |
| T4 | `librarian` → `reader` (volontario) | Sé stess* | Auto-retrocessione |
| T5 | `librarian` → `reader` (collettivo) | Coord+ | `pending_removal` con carenza 7g |
| T6 | Sospensione immediata | Coord+ | Passaggio a `suspended` |
| T7 | Revoca della sospensione | Coord+ | Ritorno `suspended` → `active` |
| T8 | Annullamento di una richiesta di rimozione | Coord+ | Ritorno `pending_removal` → `active` |
| T9 | Uscita automatica (account abbandonato) | Cron | Passaggio a `inactive` dopo 9 mesi senza login |

Tre principi strutturano questa tabella:

- **L'ingresso passa per la cooptazione** (T1, T2). Nessun* si promuove da sol*.
- **L'uscita volontaria è sempre possibile** (T3 auto, T4). Nessun* resta intrappolat* in una funzione che non vuole più esercitare.
- **L'uscita imposta è rallentata dalla carenza** (T5). Sette giorni per permettere un eventuale ripensamento collegiale.

## 3.5. Lato admin di rete: uno schema gemello

L'amministrazione di rete (tabella `network_administrators`) ha il proprio ciclo di vita, strutturalmente molto simile ma con due specificità:

- **Cooptazione all'unanimità**: per aggiungere un/una nuov* admin di rete, una proposta viene aperta da un/una admin attiv*, e **tutti gli altri/e admin attiv*** devono votare `favorable`. Un solo voto `opposed` (con motivazione obbligatoria di almeno 20 caratteri) blocca la proposta. Un'astensione blocca anch'essa finché non viene convertita in voto.

- **Rimozione collettiva all'unanimità**: per rimuovere un/una admin di rete contro la sua volontà, lo stesso workflow si applica in modo speculare. Con un periodo di carenza di **sette giorni** dopo accordo unanime (campo `pending_collective_removal_until`).

L'auto-ritiro, invece, è **unilaterale e sempre possibile** (salvo se si è l'unic* admin attiv*, nel qual caso la transizione passa per `pending_removal` con una carenza di 30 giorni, e una mail di allerta agli altri/e admin).

Dettagli completi al capitolo 8.

\newpage

# 4. Reversibilità e modificabilità

Questo breve capitolo tratta una questione politica cruciale: **come possono essere modificate queste regole?** Se non potessero esserlo, il SIGB sarebbe un'autorità, e tutto il resto di questa guida sarebbe una menzogna.

## 4.1. Tre livelli di modificabilità

Occorre distinguere tre livelli di regole, che non si modificano nello stesso modo:

**Le pratiche locali di una biblioteca** — politica di accoglienza, modalità di validazione fisica (`open` o `manual_validation`), regolamento interno, frequenza delle assemblee, modalità di cooptazione. Queste pratiche sono **interne a ciascuna biblioteca**. La rete non se ne occupa. Si modificano in assemblea di biblioteca, o secondo la procedura che il collettivo si è data.

**Le regole della rete** — separazione locale/rete, principio di cooptazione all'unanimità per gli/le admin di rete, dottrina dell'informazione preventiva in caso di intervento cross-biblioteche, modalità di attivazione delle nuove biblioteche. Queste regole sono **inter-biblioteche**. Si modificano in coordinamento di rete, dopo discussione tra admin di rete e coordinamenti locali interessati.

**I fondamenti politici del progetto** — gli otto principi (P1 a P8 del capitolo 1), l'idea che il SIGB non modella l'assemblea, la modestia rivendicata del software di fronte alla vita politica dei collettivi. Questi fondamenti possono essere modificati, ma sono strutturanti: modificarli significa probabilmente modificare ciò che si chiama «AnarBib» in senso ampio. Una rimessa in discussione di tale portata passerebbe per una discussione collettiva in tutta la rete, probabilmente in occasione di un evento (incontro annuale, ecc.).

## 4.2. Come proporre una modifica

Non c'è un solo modo di procedere — ogni livello ha il suo — ma ecco il pattern generale che la rete tende a praticare:

1. **Identificare la spec interessata**. Le regole del SIGB sono consegnate in file `spec-*.md` del repository. Trovate quella che contiene la regola che volete modificare (l'appendice D riporta le corrispondenze).

2. **Redigere una nota di modifica**. Formato libero, ma che risponda a: quale regola, perché crea problemi, quale modifica si propone, quali conseguenze tecniche e politiche si anticipano. L'appendice C propone un modello.

3. **Far circolare la nota**. Secondo il livello:
   - **Locale**: in assemblea di biblioteca, o sul canale di discussione del collettivo.
   - **Rete**: sul canale di coordinamento inter-biblioteche (Matrix `#anarbib`), taggando gli/le admin di rete e i coordinamenti locali pertinenti.
   - **Fondamenti**: su tutti i canali, e probabilmente all'ordine del giorno di un incontro.

4. **Discutere, emendare, adottare una versione**. Il SIGB non dice come questa fase deve svolgersi. È il mestiere dei collettivi.

5. **Se la decisione è presa**: un/una admin di rete o un/una dev (spesso gli/le stess*) implementa la modifica nella spec corrispondente, poi nel codice. La nuova versione viene distribuita secondo la procedura abituale (changelog, comunicazione, ecc.).

## 4.3. Se la decisione tecnica pone problemi

Capita di concordare politicamente su una regola, ma che la sua traduzione tecnica sia complicata, pesante, o abbia effetti collaterali indesiderati. È normale. Le spec esistenti sono piene di note del tipo «questa decisione politica implica di toccare 22 sotto-SELECT nelle RLS, il che giustifica un refactoring preliminare». Il dialogo politico/tecnico è permanente.

Quando proponete una modifica, non esitate a farlo anche se non avete idea della difficoltà tecnica. Gli/le dev della rete vi diranno quanto costa. E se è molto costoso, potrete decidere collettivamente se la posta politica vale il costo tecnico. Al contrario, a volte un cambiamento politico apparentemente banale permette di semplificare enormemente la base di codice.

## 4.4. Questa guida è essa stessa modificabile

Questa guida è versionata. La versione corrente è indicata sulla pagina di copertina. Se trovate che dica il falso, che abbia dimenticato un caso, o che assuma una posizione che non corrisponde più alla dottrina della rete, **ditelo**. Aprite una discussione, proponete una modifica, o riscrivete il passaggio e sottoponetelo.

Una guida che non può essere modificata non è una guida, è un dogma. Il progetto AnarBib non ha vocazione a produrre dogmi.

\newpage

# Parte II — Il come

\newpage

# 5. Cooptare qualcun* nel proprio team

Questo capitolo copre le transizioni T1 (`reader` → `librarian`) e T2 (`librarian` → `coordenador`), ovvero i **due movimenti di ingresso** in un team di biblioteca. La validazione fisica di un/una nuov* `reader` (che non è una cooptazione in senso politico ma un'operazione tecnica di accoglienza) è trattata separatamente al §5.5.

## 5.1. Il principio politico

> **P2 — Cooptazione per i ruoli staff.** L'ingresso in un team avviene per cooptazione dei/delle coordenadores esistenti. Spetta al collettivo politico decidere chi è ammess*; il/la coordenador/a è solo la mano che esegue la decisione nel SIGB.

Ciò significa che **cliccare su «Promuovi»** non è una decisione personale del/della coord che clicca. È l'**esecuzione tecnica** di una decisione che è stata presa — o deve essere presa — dal collettivo politico della biblioteca. La dottrina della rete sul «quando esattamente» la decisione deve essere presa non è volutamente definita da questa guida: ogni biblioteca elabora la propria dottrina (vedere §5.4).

## 5.2. Per fare entrare qualcun* come `librarian` (T1)

### Precondizioni

- La persona ha un account AnarBib (è iscritta da qualche parte nella rete).
- Non ha già una membership `librarian` o `coordenador` attiva nella stessa biblioteca.
- Può, o meno, avere già una membership `reader` nella stessa biblioteca. In caso affermativo, questa membership esistente resterà attiva in parallelo (multi-membership autorizzata).

### Procedura nel SIGB

1. Andare in `/biblioteca`, scheda **Equipe** (visibile ai `coordenador+`).
2. Se la persona è già reader della biblioteca, cliccare **«Invita nel team»** sulla sua riga. Se non è ancora reader, usare la ricerca nella barra superiore oppure — se non ha ancora un account — passare per il workflow di invito via email (in arrivo, cfr. `spec-invitation-equipe.md`).
3. Scegliere il ruolo `librarian`.
4. Confermare la modale. Un campo «Motivo» è opzionale — serve a iscrivere nell'audit log il contesto della cooptazione (ad esempio «decisione assemblea del 04/05», o «cooptazione in cerchio ristretto, da validare alla prossima assemblea»).
5. Il SIGB esegue:
   - Creazione di una riga `user_library_memberships` con `role='librarian'`, `status='active'`.
   - Email alla persona interessata: «Sei stat* nominat* librarian di [biblioteca] da [voi]».
   - Email a tutt* i/le coordenadores attiv* della biblioteca.
   - Voce nell'audit log: `action='promoted_to_librarian'`.

### Effetto immediato

La persona riceve, senza ritardo, i permessi di `librarian`: gestione dei prestiti, validazione delle iscrizioni, accesso ai dati personali dei lettori/trici della biblioteca, ecc. Non riceve i permessi di modifica dell'identità pubblica né della configurazione — questi sono riservati ai `coordenador+`.

### Lato tecnico

RPC interessata: `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.3. Per promuovere un/una `librarian` a `coordenador` (T2)

### Precondizioni

- La persona ha una membership `librarian` `active` nella biblioteca.
- Non ha già una membership `coordenador` attiva nella stessa biblioteca.

### Procedura nel SIGB

1. Andare in `/biblioteca`, scheda **Equipe**.
2. Sulla riga della persona, cliccare **«Promuovi»** → **«coordenador»**.
3. Confermare la modale. Il campo «Motivo» è opzionale.
4. Il SIGB esegue:
   - Creazione (o riattivazione) di una riga `coordenador` `active`. La vecchia riga `librarian` resta attiva in parallelo (multi-membership; vedere §5.6).
   - Email alla persona.
   - Email a tutt* i/le coordenadores attiv*.
   - Voce nell'audit log: `action='promoted_to_coordenador'`.

### Effetto immediato

La persona riceve, in aggiunta ai suoi permessi di `librarian`, i permessi di coordinamento: modifica dell'identità pubblica, della configurazione, delle regole di quota associativa, e tutte le azioni di governance del team.

### Lato tecnico

RPC interessata: `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.4. La questione politica: quando cliccare?

È la domanda che ogni coord si pone la prima volta. La rete AnarBib **non ha volutamente definito** questa questione a livello della guida: ogni biblioteca elabora la propria dottrina, perché la cultura politica di un collettivo anarchico non si decide alla scala di una guida generica.

Ecco le tre dottrine che si incontrano nella rete, senza giudizio:

**Dottrina 1 — Attesa rigorosa.** Si clicca solo **dopo** una decisione ratificata dal collettivo (assemblea, cerchio, consenso formale, qualunque sia la modalità). Il/la coord si limita a eseguire. Vantaggio: massimizzazione dell'orizzontalità, forte tracciabilità politica. Svantaggio: può essere lento, in particolare quando la biblioteca è agli inizi o il collettivo è disperso.

**Dottrina 2 — Anticipazione segnalata.** Il/la coord può anticipare una decisione che ritiene certa («è evidente che Voltairine sarà cooptat*, sono sei mesi che viene tutte le settimane»), **a condizione di esplicitarlo nell'audit log**: motivo = «anticipazione sotto mia responsabilità, da validare alla prossima assemblea». La decisione può essere contestata a posteriori, e la rimozione resta sempre possibile. Vantaggio: flessibilità pratica. Svantaggio: sposta una parte di responsabilità politica sul/sulla coord che clicca.

**Dottrina 3 — Cerchio di coord.** La cooptazione è presa per accordo tra i/le coord attiv* della biblioteca, senza passare per l'assemblea plenaria. Argomento: il coordinamento è esso stesso un collettivo deliberante, e ha il mandato di agire. Vantaggio: intermedio tra 1 e 2. Svantaggio: può diventare opaco se il coordinamento non viene esso stesso rinnovato.

**La nostra raccomandazione** (e niente di più): **scegliete esplicitamente** una dottrina, scrivetela nel regolamento della vostra biblioteca, e indicatela nel campo «Motivo» dell'audit log ad ogni cooptazione («dottrina 2 — anticipazione sotto mia responsabilità» per esempio). L'opacità è raramente buona in politica.

## 5.5. Caso particolare: la validazione fisica di un/una `reader`

L'**arrivo** di un/una `reader` in una biblioteca è un'operazione diversa da una cooptazione in senso politico. È coperta dalla spec `spec-validation-physique.md`.

Due modalità possibili, scelte da ogni biblioteca nella propria configurazione:

**Modalità `open`** — La validazione è **automatica** all'iscrizione. Una volta creato l'account e confermata l'email, il/la `reader` ha immediatamente accesso ai cataloghi `public` e `network`. Adatto alle biblioteche poco esposte politicamente.

**Modalità `manual_validation`** — L'account è creato online ma resta **in attesa** fino a un **incontro fisico** tra il/la `reader` e un/una `librarian+` della biblioteca di iscrizione. Adatto alle biblioteche esposte (contesto politico teso, fondi sensibili, locali fragili, ecc.).

### Procedura di validazione fisica (modalità `manual_validation`)

1. La persona si iscrive online e sceglie la vostra biblioteca come biblioteca di riferimento.
2. Il suo account è creato con `status='pending'`. Riceve una mail che spiega che deve venire a presentarsi fisicamente alla biblioteca.
3. Quando viene, un/una `librarian+` la incontra, verifica ciò che c'è da verificare (la dottrina su cosa «verificare» significhi è locale), e clicca **«Valida»** sulla sua riga nella scheda **Equipe** → sezione **Account in attesa**.
4. Un campo «Nota» opzionale permette di iscrivere un contesto («incontro del 12/05 durante il permanente, presentata da Emma»).
5. L'account passa a `status='active'`. La persona riceve una mail di benvenuto.

### Importante politico

- La validazione fisica di una biblioteca **vale per tutta la rete** delle biblioteche `network` (P7 sfumato: la sovranità locale riguarda le deleghe interne, ma il riconoscimento reciproco è un patto esplicito).
- Ciò che si «verifica» durante una validazione fisica **non** è un controllo d'identità in senso amministrativo. È un incontro. Ogni biblioteca ne definisce il senso politico. Per alcune è «ci scambiamo due parole per verificare che la persona non sia un/una sbirr* o un/una fascist*». Per altre è «presentiamo la biblioteca, il suo funzionamento, le sue regole». Per altre ancora è semplicemente «ci vediamo di persona perché la relazione sia incarnata».
- Una biblioteca può **cambiare modalità** in qualsiasi momento (`coordenador+`). Il cambiamento non invalida le validazioni esistenti.

## 5.6. La multi-membership, punto di attenzione

Una particolarità tecnica da comprendere: una persona può avere **più righe** di membership nella stessa biblioteca, con ruoli diversi. Per esempio, Voltairine può essere allo stesso tempo `reader` e `librarian` di BLMF. Ciò è reso possibile dal vincolo UNIQUE sul triplo `(user_id, library_id, role)`.

**Perché questa possibilità:** preserva la cronologia. Se domani Voltairine si retrocede da `librarian` a `reader`, la sua riga `librarian` passa a `inactive` ma la riga `reader` resta — senza dover ricreare una nuova iscrizione da zero.

**Conseguenza pratica:** nell'UI, si visualizza la persona **una sola volta**, con il suo ruolo **di livello più alto attivo** (administrador > coordenador > librarian > reader). Nell'audit log, invece, si vede ogni riga separatamente.

## 5.7. Errori e salvaguardie

Alcuni casi che si incontrano regolarmente:

**«Il SIGB mi dice che la persona è già librarian.»** È probabilmente vero. Verificate la scheda **Equipe**: se la persona vi figura già come librarian, state cercando di promuoverla allo stesso livello, il SIGB restituisce un successo silenzioso (`{ok: true, no_change: true}`) perché non c'è nulla da fare.

**«Non vedo la persona nell'elenco.»** Tre casi possibili: (a) non ha ancora un account AnarBib (usare il workflow di invito via mail in arrivo); (b) ha un account ma non è iscritta in nessuna biblioteca (deve iscriversi alla vostra biblioteca come `reader` prima); (c) è nella rete ma filtrata dalla ricerca — provare con la sua email esatta.

**«Ho cliccato per errore su Promuovi.»** Niente panico. Usare **«Richiedi la rimozione»** per aprire un periodo di carenza di 7 giorni (cfr. capitolo 6), oppure chiedere alla persona di cliccare **«Passo il testimone»** (auto-retrocessione immediata). Indicare «errore di manipolazione» come motivo.

**«La persona non riceve la mail.»** Verificare prima l'ortografia della sua email nel suo profilo, e chiederle di controllare la posta indesiderata. Se il problema persiste, parlarne con un/una admin di rete: è probabilmente un problema di configurazione mail da investigare.

## 5.8. Se la regola vi pesa

Diverse cose in questo capitolo potrebbero non convenirvi:

- **Il principio di cooptazione in sé** (P2). Pensate che ogni `reader` impegnat* dovrebbe poter passare liberamente a `librarian` senza aver bisogno di cooptazione. È un dibattito politico di fondo, che tocca il principio P1. Da portare sul canale di coordinamento di rete e probabilmente da discutere in un incontro.

- **L'assenza di dottrina definita sul «quando cliccare»** (§5.4). Pensate che la guida dovrebbe raccomandare una sola dottrina. O al contrario trovate che ne suggerisca troppe. Proporre una modifica a questo capitolo, argomentando.

- **Le modalità di validazione fisica** (§5.5). Pensate che ne servirebbe una terza («validazione differita», «validazione a distanza», altro). Da portare su `spec-validation-physique.md`.

- **La multi-membership** (§5.6). Pensate che sia inutilmente complessa e che ci vorrebbe un solo ruolo per persona per biblioteca. È una decisione di modello di dati, più strutturante di quanto appaia. Da portare con gli/le dev.

Vedere capitolo 4 per la procedura generale di modifica, e appendice C per il modello di nota.

\newpage

# 6. Passare il testimone, ritirarsi, sospendere

Questo capitolo copre le transizioni T3–T8 — ovvero **tutto ciò che fa uscire una persona da un'équipe**, o la mette in pausa. Dal punto di vista politico, è probabilmente il capitolo più importante della guida, perché i meccanismi di ritiro sono al cuore del progetto anarchico (cfr. capitolo 1, §1.2).

## 6.1. I principi politici

Tre principi strutturano questo capitolo :

> **P3 — Declassamento volontario sempre possibile.** Ogni person* con un ruolo staff può declassarsi da sola in qualsiasi momento, senza consultazione. « Passo il testimone » è un diritto fondamentale.

> **P4 — Esclusione regolamentata da un periodo di carenza.** L'esclusione non volontaria di un*/a `librarian` da parte di un/a `coordinatore/trice` passa attraverso un periodo di carenza di sette giorni prima di avere effetto. Questo periodo consente la deliberazione collettiva e la possibile annullazione da parte di un/a altr* `coordinatore/trice`.

> **P6 — Notifiche sistematiche.** Ogni cambiamento di ruolo genera un'email alla persona interessata e all'intera coordinazione.

L'idea di fondo è che non si fa mai uscire qualcuno da un'équipe « di sorpresa » o « in silenzio ». O la persona decide da sola (ed è immediato), o il collettivo lo richiede (ed è tracciato, notificato, e deliberabile fino all'ultimo secondo).

## 6.2. Passare il testimone : auto-declassamento (T3 e T4)

È il **diritto più fondamentale** nel sistema di governance di AnarBib. Ogni person* che esercita una funzione staff può, in qualsiasi momento, senza alcuna consultazione, abbandonarla.

### Quando usarlo

- Non si ha più il tempo di svolgere la funzione.
- Non ci si riconosce più nelle decisioni della coordinazione.
- Si è in disaccordo con una decisione e si vuole prenderne le distanze.
- Si vuole semplicemente far ruotare la funzione.
- Si ha bisogno di una pausa.
- Non è necessario fornire alcuna ragione, in effetti. Il diritto di partire è incondizionato.

### Procedura

1. Andare in `/biblioteca`, scheda **Equipe**.
2. Sulla **propria riga**, cliccare **« Passo il testimone »**.
3. Scegliere il livello di declassamento :
   - Se si è `coordenador`, si può scegliere « tornare librarian » (si rimane nell'équipe come `librarian`) o « lasciare l'équipe » (si torna reader).
   - Se si è `librarian`, si può scegliere « lasciare l'équipe » (si torna reader).
4. La modale ricorda le conseguenze. Confermare.

### Effetto immediato

- La membership attuale (`librarian` o `coordenador`) passa a `inactive`.
- Se non si aveva già la membership di destinazione (`reader` o `librarian`), essa viene creata a `active`.
- Mail a tutta la coordinazione + a se stess* (conferma).
- Audit log : `action='self_demoted'`.

### Caso speciale : si è l'unic* `coordenador`/`coordinatrice` attiv*

Il SIGB **vi lascia partire**, ma vi avvisa :

> ⚠️ ATTENZIONE : sei l'unic* `coordinatore/trice` attiv* di [biblio]. La biblio si ritroverà senza coordinazione. Gli/le `amministratore/trice` AnarBib saranno notificat*. Continuare ?

Se si conferma :
- La membership coord passa a `inactive`.
- La biblio entra in **modalità degradata** : i `librarian` possono continuare a gestire i prestiti, validare le iscrizioni, ecc., ma nessuna modifica dell'identità pubblica o della configurazione è possibile fino alla cooptazione di un*/a nuov* coord.
- Mail a tutt* gli/le admin di rete : « La biblio X non ha più un/a `coordinatore/trice`. Ecco i/le `librarian` attiv* : ... »

Dal punto di vista politico, è importante : il SIGB **non impedisce** la partenza. Ma informa la rete, affinché un*/a admin di rete possa, se lo si desidera e se il collettivo locale ne ha bisogno, prendere contatto per aiutare a organizzare la transizione. È la rotazione delle funzioni in azione.

### Lato tecnico

RPC : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

## 6.3. Richiedere il ritiro di un*/a `librarian` (T5)

Quando il collettivo decide che una persona deve lasciare l'équipe, e quella persona non si declassa da sola, si apre una **richiesta di ritiro con carenza di sette giorni**.

### Precondizioni

- Si è `coordenador+` attiv* della biblio.
- La persona bersaglio ha una membership `librarian` o `coordenador` `active`.
- Non si è la persona bersaglio (altrimenti usare §6.2).

### Procedura

1. Andare in `/biblioteca`, scheda **Equipe**.
2. Sulla riga della persona, cliccare **« Richiedere il ritiro »**.
3. La modale che si apre è **rossa e insistente**. Ricorda :
   - Il periodo di carenza : « Questa richiesta avrà effetto il [data G+7] salvo annullamento da parte di un*/a altr* `coordinatore/trice`. »
   - Il carattere reversibile : « Annullabile da qualsiasi coord fino alla data di effetto. »
   - Il carattere collegiale : « Tutt* i/le coord attiv* saranno notificat*. »
4. Un campo **« Motivo »** è obbligatorio — minimo 20 caratteri. Nessun ritiro silenzioso. Il motivo può essere politico (« decisione AG del 04/05 ») o pratico (« partenza geografica annunciata »). Sarà leggibile da tutt* lo staff nell'audit log.
5. Confermare.

### Effetto immediato

- La membership passa a `pending_removal`.
- Campo `pending_removal_until` = `now() + 7 days`.
- Campo `pending_removal_requested_by` = sé stess*.
- **Nessun accesso** per la persona durante la carenza (la membership è congelata come `suspended`).
- Mail alla persona interessata : « La coordinazione ha richiesto il tuo ritiro dall'équipe [biblio] (preavviso fino al [data]). Questa decisione riguarda la vita organica del collettivo [biblio] ; per qualsiasi discussione, rivolgiti alla coordinazione. »
- Mail a tutt* i/le `coordinatore/trice` attiv* : con il vostro nome e il motivo.
- Audit log : `action='removal_requested'` con il vostro `actor_user_id` e il campo `reason`.

### Effetto a G+7 (cron automatico)

Se la richiesta non è stata né annullata né aggirata :
- La membership passa a `inactive`.
- Mail finale alla persona e alla coordinazione : « Ritiro effettivo. »
- Audit log : `action='removal_completed'`.

### Lato tecnico

RPC : `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron : `cron_team_pending_removal_complete` (si esegue quotidianamente).

## 6.4. Annullare una richiesta di ritiro (T8)

Il **guardrail collegiale** del sistema. Qualsiasi coord — non necessariamente chi ha richiesto — può annullare una richiesta di ritiro durante il periodo di carenza.

### Quando usarlo

- La discussione collettiva ha portato a un'altra decisione (mediazione, sospensione temporanea al suo posto, ecc.).
- La richiesta iniziale è stata fatta a caldo e la coordinazione vuole riprendere la mano collegialmente.
- La persona bersaglio è stata infine raggiunta e la situazione è stata disinescata.

### Procedura

1. Andare in `/biblioteca`, scheda **Equipe**, sezione **Sospensioni e preavvisi in corso**.
2. Sulla riga della persona in `pending_removal`, cliccare **« Annullare la richiesta »**.
3. Modale semplice di conferma. Campo « Motivo » facoltativo.
4. Confermare.

### Effetto immediato

- La membership torna a `active`.
- Campo `pending_removal_until` rimesso a NULL.
- Mail alla persona : « La richiesta di ritiro è stata annullata. Ritrovi le tue prerogative. »
- Mail a tutta la coordinazione.
- Audit log : `action='removal_cancelled'` con il vostro `actor_user_id`.

### Dal punto di vista politico

L'annullamento è volutamente molto semplice da attivare. È un meccanismo di **riequilibrio collegiale** : se un*/a coord ha richiesto un ritiro a caldo, qualsiasi altr* coord può sospendere l'esecuzione il tempo che il collettivo deliberi. Questo rende le richieste di ritiro meno pesanti (nessun dramma irreversibile) ma anche meno leggere (chiunque può contraddirvi). È l'interesse della carenza.

### Lato tecnico

RPC : `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Sospensione immediata : la misura conservativa (T6 e T7)

La sospensione è uno strumento **diverso** dalla richiesta di ritiro. È **immediata**, senza carenza, e **senza durata massima**. Non è un'esclusione, è una **messa in pausa**.

### Quando usarlo

Casi-tipo previsti dalla spec :

- **Account compromesso** : si hanno ragioni di pensare che la password della persona sia trapelata. Si sospende in attesa che cambi la propria password.
- **Molestia segnalata urgente** : un*/a `lettore/trice` segnala un comportamento abusivo di un*/a membro dello staff. Si sospende in attesa dell'indagine collettiva.
- **Comportamento manifestamente abusivo** osservato in diretta : si sospende il tempo che la coordinazione si riunisca.
- **Conflitto in corso di mediazione** : la persona è messa in pausa volontariamente il tempo che la mediazione si concluda.

### Procedura

1. Andare in `/biblioteca`, scheda **Equipe**.
2. Sulla riga della persona, cliccare **« Sospendere »**.
3. Modale con un campo **« Motivo della sospensione » obbligatorio** (minimo 20 caratteri). Questo motivo sarà leggibile nell'audit log da tutt* lo staff attiv*.
4. Confermare.

### Effetto immediato

- La membership passa a `suspended`.
- **Nessun accesso** per la persona. Il ruolo nominale è conservato (rimane visualizzat* come « librarian sospes* ») ma non può più fare nulla.
- Mail alla persona interessata : urgente, con il motivo, e — nel caso di un account compromesso — un invito a cambiare la propria password.
- Mail a tutta la coordinazione.
- Audit log : `action='suspended'` con il vostro `actor_user_id` e il campo `reason`.

### Revoca della sospensione

Quando la situazione è risolta (account rimesso in sicurezza, mediazione conclusa, indagine completata, ecc.) :

1. Scheda **Equipe** → sezione **Sospensioni e preavvisi in corso**.
2. Sulla riga sospes*, cliccare **« Revocare la sospensione »**.
3. Modale semplice. Campo motivo facoltativo ma raccomandato per chiudere politicamente l'episodio.
4. Confermare.

Effetto : ritorno a `active`, mail, audit log `action='unsuspended'`.

### Importante : sospensione vs ritiro

La distinzione è cruciale :

| | Sospensione (T6) | Ritiro (T5) |
|---|---|---|
| Effetto | Immediato | Differito (G+7) |
| Durata | Indefinita | 7 giorni poi `inactive` |
| Reversibile da | Revoca esplicita | Annullamento durante la carenza |
| Uso tipico | Misura conservativa | Decisione di esclusione |
| Politica sottostante | « Ci lasciamo il tempo di capire » | « Abbiamo deciso che questa persona esce » |

Il SIGB **rifiuta** di far passare una membership da `suspended` direttamente a `pending_removal` (la transizione non è autorizzata dalla matrice). Perché : sono due temporalità politiche distinte. Per passare dall'una all'altra, bisogna esplicitamente **revocare la sospensione** prima (ritorno `active`), poi richiedere il ritiro (`pending_removal`). Questo doppio passaggio è volontario : obbliga il collettivo ad attestare esplicitamente la transizione.

### Lato tecnico

RPC sospendere : `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC revocare : `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Declassare un*/a altr* `coordenador` (T3 collettivo)

Un caso un po' particolare : cosa fare quando la coordinazione vuole **declassare un/a `coordinatore/trice`** che non si declassa spontaneamente ?

La spec governance tratta questo caso come una **richiesta di ritiro con carenza** che bersaglia la membership `coordenador`. Concretamente, si usa la stessa procedura del §6.3 (« Richiedere il ritiro »), ma selezionando il ruolo `coordenador`. La persona passa a `pending_removal` sulla propria membership `coordenador` ; a G+7, questa membership passa a `inactive`. Se aveva una membership `librarian` parallela, quest'ultima rimane attiva (e la persona « ricade » `librarian`). Altrimenti torna semplice `reader`.

È volutamente lo stesso meccanismo che per i `librarian`, con gli stessi guardrail. **Nessun*/a altr* coord ha un potere speciale** sui/sulle propri colleghi/colleghe : la procedura passa per la carenza e la collegialità.

## 6.7. Account abbandonato : uscita automatica (T9)

Il SIGB include un meccanismo di **uscita automatica** per gli account che non hanno avuto connessioni da molto tempo.

### La soglia

Il SIGB controlla il campo `last_sign_in_at` lato Supabase. Se una membership staff ha un utente la cui ultima connessione risale a più di **9 mesi**, l'account viene progressivamente rimosso :

- **G-30 giorni** (8 mesi dopo l'ultima connessione) : mail di avvertimento alla persona (« la tua membership verrà disattivata in 30 giorni senza connessione »).
- **G-7 giorni** : mail di promemoria.
- **G = 9 mesi** : passaggio automatico a `inactive`. Mail finale alla persona + a tutta la coordinazione.

### Perché questa regola

È un compromesso tra due esigenze :

- Non lasciare **trascinare indefinitamente** membership fantasma che gonfiano artificialmente le équipe.
- Non **cacciare** brutalmente una persona che avrebbe semplicemente preso una pausa e conta di tornare.

Una semplice connessione è sufficiente per azzerare il contatore. Non è necessario eseguire un'azione, basta connettersi.

### Caso speciale : l'unic* coord abbandona

Se la persona uscita automaticamente è l'**unic* `coordinatore/trice` attiv***  della biblio, il cron escalate a un*/a admin di rete **prima** di eseguire l'uscita. L'admin di rete è notificat* via mail, può prendere contatto con la coordinazione (se ne rimane un frammento) o con i/le `librarian` della biblio, e coordinare la transizione.

Dal punto di vista politico, è coerente con ciò che si fa quando l'unic* coord si declassa esplicitamente (§6.2) : non si blocca l'uscita, ma si avvisa la rete affinché possa aiutare se necessario.

## 6.8. Alcuni casi limite da conoscere

**Una person* in `pending_removal` che chiede di partire subito.** Può farlo. Le basta usare da sola « Passo il testimone » (auto-declassamento T4). Effetto : passaggio immediato a `inactive`, cortocircuito della carenza. Dal punto di vista politico, è coerente : il diritto P3 (auto-declassamento) è incondizionato.

**Una person* in `suspended` che si vuole escludere definitivamente.** Vedere §6.5 « Importante : sospensione vs ritiro ». Bisogna revocare la sospensione prima, poi richiedere il ritiro.

**Qualcuno richiede il proprio ritiro tramite « Richiedere il ritiro ».** Il SIGB rifiuta con un messaggio esplicito : « Per lasciare l'équipe, usa l'opzione "Passo il testimone" (auto-declassamento). » È volontario : confondere una decisione personale con una decisione collettiva confonderebbe la semantica politica.

**Tentativo di declassare un*/a admin di rete.** Rifiutato sistematicamente. Il ruolo di admin di rete può essere modificato solo tramite i meccanismi specifici della spec admin-reseau (cfr. capitolo 8). Nessun*/a coord locale può destituire un*/a admin di rete.

## 6.9. Se la regola vi pesa

**Il periodo di carenza di 7 giorni vi sembra troppo lungo o troppo corto.** Da portare su `spec-gouvernance-roles.md`, §4.4 e §5.6.

**Trovate che la sospensione senza durata massima sia una porta aperta all'arbitrio.** È un argomento politico serio. Si può pensare di aggiungere un limite oltre il quale una sospensione deve essere convertita in ritiro o revocata. Da discutere in coordinazione di rete, poi da portare sulla spec.

**Trovate che l'obbligo di motivazione sulla sospensione sia un eccesso di burocrazia.** O al contrario trovate che il minimo di 20 caratteri sia troppo corto. Da portare sulla spec.

**Trovate che l'uscita auto a 9 mesi sia troppo rapida o troppo lenta.** La soglia è parametrabile, ma oggi è la stessa per tutte le biblio della rete. Va resa configurabile per biblio ? Da discutere.

Vedere capitolo 4 e allegato C per la procedura di emendamento.

\newpage

# 7. Quando qualcosa va storto

Questo capitolo tratta le **situazioni eccezionali**, quelle in cui i meccanismi ordinari di governance non bastano, o funzionano ma richiedono discernimento politico. È anche il capitolo in cui si parla francamente delle **biblioteche che non hanno (o non hanno più) una vita collettiva deliberante**, perché il silenzio su questo argomento farebbe più danno della franchezza.

## 7.1. Biblioteca senza assemblea o con pochi membri

Il caso è più frequente di quanto sembri. Una biblioteca agli inizi, con due o tre persone. Una biblioteca il cui collettivo si è ridotto nel corso delle partenze. Una biblioteca in cui l'assemblea non si tiene più da un po', per mancanza di persone o per scoraggiamento.

Il SIGB non s'immischia nella vita politica di un collettivo. Ma questa guida deve dire francamente cosa cambia quando questa vita collettiva è debole.

### Cosa cambia concretamente

**La parola «cooptazione» diventa ambigua.** In due persone, chi coopera chi? Se l'unic* coordinatore/trice desidera far entrare Voltairine nel gruppo, decide «da sol*» in senso politico. Il SIGB lo autorizzerà (un coordinatore/trice+ può cooptare), ma non è più la cooperazione di un collettivo politico, è una decisione personale travestita. Non è né bene né male, è semplicemente da riconoscere.

**Le deliberazioni sono teoriche.** Una richiesta di rimozione a 7 giorni, in una biblioteca con 2 persone, non ha nessun'altra persona che la contraddica se non chi l'ha richiesta. Il «guardiano collegiale» diventa un'auto-riflessione.

**Il rischio di personalizzazione aumenta.** Quando una decisione non è più collettiva, dipende dal carattere, dalla disponibilità e dalla lucidità di una o due persone. Non è catastrofico di per sé, ma è più fragile.

### Le nostre raccomandazioni esplicite

**1. Riconoscete la situazione.** Non fingete di essere un grande collettivo deliberante se siete in due. Politicamente, è più sano scrivere «decisione presa da me sol*, da validare quando il collettivo si sarà allargato» nel campo «Ragione» dell'audit log, che scrivere «decisione dell'assemblea» per un'assemblea che non esiste.

**2. Cercate dialogo all'esterno.** Se siete sol* o in due, e deve essere presa una decisione importante (cooptazione, rimozione, sospensione), prendete l'abitudine di parlarne con compagn* di altre biblioteche della rete, o con un amministratore/trice di rete. Non per chiedere loro un'autorizzazione — non devono validare le decisioni interne della vostra biblioteca — ma per avere un riscontro critico esterno. La rete Matrix di AnarBib è fatta per questo.

**3. Privilegiate le transizioni reversibili.** Quando il vostro collettivo è piccolo, evitate se possibile le decisioni irreversibili. Una sospensione è più reversibile di una rimozione. Una rimozione prevede 7 giorni durante i quali potete cambiare idea. Una cooptazione è annullabile. Datevi del tempo.

**4. Documentate quello che succede.** Il campo «Ragione» dell'audit log è il vostro migliore alleato. Più contesto vi mettete (« cooptazione di Voltairine, decisa da sol*, da validare alla prossima permanenza »), più la decisione sarà contestualizzabile in seguito, da voi stess* come da un nuovo membro del collettivo.

**5. Se siete davvero isolat*, chiedete aiuto.** Una biblioteca con una sola persona è in pericolo politicamente. Il SIGB lo rileva nel momento in cui l'ultim* coordinatore/trice si retrograda (§6.2) o abbandona (§6.7), e avvisa gli amministratori/trici di rete. Potete anche prendere l'iniziativa: inviate una mail alla coordinazione di rete per spiegare la situazione. Diverse biblioteche della rete hanno attraversato periodi di vuoto e sono state aiutate a ricostituirsi.

### Cosa questa guida non fa

Non fornisce **alcuna** procedura speciale per le piccole biblioteche. È volontario. Le regole del SIGB si applicano in modo uniforme — ciò che cambia sono le condizioni politiche in cui si applicano. Riconoscere questa sfumatura fa parte della maturità politica di un coordinatore/trice.

## 7.2. Conflitto interpersonale in una coordinazione

Un conflitto scoppia tra due membri dello staff. Il lavoro non si svolge più correttamente, l'atmosfera si deteriora, lettori/trici percepiscono la tensione.

### Cosa può fare il SIGB

Non molto, direttamente. Il SIGB non arbitra i conflitti. Ma fornisce **strumenti utilizzabili**:

- **Sospensione provvisoria (T6)** di una o entrambe le persone, mentre il conflitto è in mediazione. È ciò che la spec chiama esplicitamente «conflitto in corso di mediazione» come caso d'uso legittimo della sospensione.
- **Auto-retrocessione (T3/T4)** — se una delle due persone sceglie di fare un passo indietro, è immediata.
- **Audit log leggibile da tutto lo staff** — consente all'intero staff di vedere chi ha fatto cosa, ed evitare le manipolazioni opache di un coordinatore/trice che cercasse di risolvere il conflitto facendo fuori l'altro/a di nascosto.

### Cosa deve fare il collettivo

- **Mediazione**. Il SIGB non media. Occorre una persona terza di fiducia, al di fuori del conflitto. A seconda delle configurazioni: un altro coordinatore/trice della biblioteca, un* compagn* di un'altra biblioteca, un amministratore/trice di rete.
- **Decisione collettiva**. Se la mediazione porta a una decisione (una delle due persone lascia la coordinazione, o si definisce un quadro di lavoro riveduto), il SIGB eseguirà questa decisione tramite le RPC normali.
- **Traccia politica**. Se la decisione è di rimuovere qualcuno, il campo «Ragione» dovrebbe menzionare il processo di mediazione («rimozione a seguito di mediazione del GG/MM, decisione collettiva») per non riscrivere la storia in seguito.

### Cosa evitare

- **Usare una sospensione come arma** nel conflitto. La sospensione serve a mettere in pausa, non a vincere un rapporto di forza. Se un coordinatore/trice sospende l'altro/a senza un processo di mediazione, è osservabile nell'audit log, ed è politicamente problematico.
- **Aggirare la carenza** con manovre tecniche (sospendere poi «accelerare» con altri mezzi). Tutto è tracciato, e la rete se ne accorgerà.
- **Tacere sull'audit log**. Tutto lo staff vede cosa succede (P5). Se tentate di nascondere il conflitto, tradite la trasparenza del collettivo.

## 7.3. Segnalazione di molestie

Un lettore/trice segnala che un membro dello staff ha un comportamento abusivo (molestie sessuali, abuso di potere, comportamento razzista, ecc.).

### Procedura raccomandata

**1. Prendere la segnalazione sul serio**, immediatamente, anche se la persona che segnala è isolata e anche se la persona segnalata è «conosciuta e apprezzata» dalla coordinazione. Il riflesso di scartare la segnalazione come «probabilmente esagerata» è l'errore più comune.

**2. Sospensione immediata (T6)** della persona segnalata, **a titolo conservativo**, in attesa dell'indagine. Il campo «Ragione» dovrebbe dire qualcosa come «Sospensione conservativa a seguito di segnalazione ricevuta il GG/MM, in attesa di indagine collettiva». La sospensione **non** è un'accusa, è una messa in pausa.

**3. Costituire un gruppo di indagine**. Al di fuori del software. Al minimo: compagn* fuori dalla situazione di potere diretta, capaci di ascoltare entrambi i lati senza pregiudizi. Questo gruppo può includere compagn* di altre biblioteche se la biblioteca è piccola o se tutti i coordinatori/trici sono coinvolti nella vicenda.

**4. Comunicare con la persona segnalante**. Ha bisogno di sapere che la cosa è presa sul serio, e che sono in corso delle misure. Non lasciarla nell'incertezza.

**5. Giungere a una decisione**. A seconda di ciò che l'indagine rivela:
   - Revoca della sospensione (T7) se la segnalazione non è confermata.
   - Rimozione definitiva (T5 con carenza) se la segnalazione è confermata e la decisione è di allontanare la persona.
   - Sanzione intermedia (quadro di lavoro riveduto, formazione, esclusione da alcune funzioni) se la situazione è più sfumata.

**6. Tracciare politicamente**. Il campo «Ragione» nell'audit log dovrebbe riflettere la decisione collettiva. Nessun dettaglio sulla vittima (GDPR), ma una formulazione che renda la decisione leggibile.

### Cosa non fare

- **Chiedere una rimozione direttamente** senza sospensione preliminare, quando la situazione è urgente. Per 7 giorni la persona segnalata conserverebbe i propri diritti, il che è contraddittorio con l'urgenza di una segnalazione di abusi.
- **Sospendere indefinitamente senza decisione** con il pretesto che «non riusciamo a decidere». Una sospensione che dura diversi mesi senza decisione diventa essa stessa una violenza (nei confronti della persona sospesa, che non può difendersi, e nei confronti della persona segnalante, che non riceve risposta).
- **Risolvere internamente senza la rete**. Se siete una piccola biblioteca e la situazione vi supera, chiedete aiuto agli amministratori/trici di rete. Non siete sol*.

## 7.4. Account compromesso

Un membro dello staff vede il proprio account compromesso (password in chiaro, sospetto di accesso non autorizzato).

### Procedura immediata

**1. Sospensione immediata (T6)** dell'account, con ragione esplicita: «Sospetto di compromissione, password probabilmente trapelata, verifica in corso».

**2. Comunicazione con la persona interessata**. La persona riceve automaticamente una mail urgente che indica la sospensione e la invita a cambiare la password. Il coordinatore/trice che sospende dovrebbe anche prendere contatto direttamente (telefono, altro canale sicuro) per confermare.

**3. Indagine rapida.** Cosa è successo? L'account ha fatto azioni insolite nell'audit log (cooptazioni strane, modifiche di configurazione, ecc.)? Se sì, avvisare immediatamente un amministratore/trice di rete per aiutare ad analizzare.

**4. Revoca della sospensione (T7)** una volta che:
   - La password è cambiata.
   - L'eventuale danno è constatato e riparato (annullamento delle azioni abusive, ripristino dei dati, ecc.).
   - La persona è al sicuro digitalmente.

### Politicamente

Una sospensione per account compromesso **non è un biasimo**. È una protezione reciproca: si protegge la persona (impedendo che venga usata da un attaccante/trice) e la biblioteca (impedendo che vengano arrecati danni a suo nome). La mail alla persona dovrebbe insistere su questo carattere **non disciplinare**.

## 7.5. Biblioteca senza coordinatori/trici né librarian attiv*

Lo scenario catastrofe: nessun membro dello staff attiv*. Può accadere per uscita automatica cumulata (tutti i membri dello staff hanno abbandonato il proprio account simultaneamente), per dimissioni collettive (raro ma possibile), o per una successione di rimozioni.

### Conseguenze

- La biblioteca rimane **tecnicamente attiva** (la sua visibilità, il suo catalogo restano accessibili secondo le RLS abituali).
- Ma **nessuna azione di gestione** può più essere effettuata tramite l'UI normale: nessuna validazione di iscrizioni, nessuna gestione dei prestiti, nessuna modifica della configurazione.
- **Mail urgente agli amministratori/trici di rete** dal cron che rileva la situazione.

### Procedura di riavvio

Fuori-spec, ma ecco cosa si pratica:

**1. Presa di contatto** da parte di un amministratore/trice di rete con il collettivo locale, attraverso tutti i canali disponibili (uno o più account lettore/trice ancora iscritti/e, i contatti esterni della biblioteca se esistono, la rete di conoscenze locale).

**2. Verifica politica**: il collettivo esiste ancora? Vuole continuare a esistere? Se ci sono membri ma hanno semplicemente lasciato cadere le funzioni tecniche, si possono ricooptare nuovi staff tramite cooptazione fuori-workflow.

**3. Cooptazione fuori-workflow** da parte dell'amministratore/trice di rete, via SQL diretto o tramite l'UI (un amministratore/trice di rete ha il diritto di agire come coordinatore/trice+ su qualsiasi biblioteca, cfr. capitolo 2). La cooptazione fuori-workflow deve essere tracciata nell'audit log con una ragione esplicita: «Ripresa della coordinazione dopo vacanza, a seguito di contatto del collettivo del GG/MM, da parte dell'amministratore/trice di rete X». E — punto chiave di dottrina — **informazione preliminare alla coordinazione locale obbligatoria**, tranne se la biblioteca non ha più alcun membro dello staff vivente/e, nel qual caso l'informazione passa attraverso i `reader` attiv* rimasti/e (cfr. §7.6).

**4. Se il collettivo non esiste più**: apertura di una discussione sulla **chiusura corretta** della biblioteca. Quali dati conservare, quali eliminare, come comunicare ai lettori/trici, ecc. È un workflow da formalizzare separatamente.

## 7.6. L'intervento di un amministratore/trice di rete su una biblioteca locale

Un caso già toccato nel capitolo 2, ma che merita uno sviluppo pratico in questo capitolo delle situazioni eccezionali.

### La dottrina della rete

> **Un intervento di un amministratore/trice di rete su una biblioteca locale deve essere preceduto da un'informazione alla coordinazione locale interessata, salvo urgenza vitale.**

L'informazione preliminare **non è una richiesta di autorizzazione**. L'amministratore/trice di rete ha il diritto di agire (questo è il senso del diritto trasversale). Ma è un segno di rispetto verso l'autonomia locale, e preserva la possibilità di un altro accordo.

### Cos'è un'«urgenza vitale»

È volontariamente restrittivo. Casi tipici:

- **Compromissione attiva**: un'azione in corso minaccia l'integrità della biblioteca o della rete (account attaccante che modifica i membership in tempo reale, ecc.).
- **Molestie in corso**: un membro dello staff abusa attivamente delle proprie funzioni, il pericolo per i lettori/trici è immediato.
- **Attacco contro la piattaforma**: tentativo di intrusione, esfiltrazione di dati, ecc.

Al di fuori di questi casi, **ci si prende il tempo di informare**.

### Come informare

Prima dell'intervento (o durante, se l'urgenza lo giustifica a posteriori):

- **Mail alla coordinazione locale** che spiega cosa verrà fatto, perché, e con quale tracciabilità.
- **Menzione nella tabella `cross_library_actions_log`** con un livello di criticità che indica la natura dell'azione. Tutti i coordinatori/trici attiv* della biblioteca ricevono una notifica.
- **Disponibilità al dialogo**: la coordinazione locale deve poter fare domande, chiedere chiarimenti, e persino negoziare un altro accordo («lasciateci provare prima»).

### Cosa evitare

- **L'intervento silenzioso**: agire sulla biblioteca senza informarne la coordinazione. Anche se tecnicamente è tracciato, politicamente è una violazione della sovranità locale.
- **L'uso del diritto trasversale come potere di sorveglianza**: andare a vedere «cosa succede» in una biblioteca senza una ragione operativa. Il diritto trasversale esiste per casi di manutenzione o mediazione, non per curiosità.
- **L'imposizione di decisioni politiche**: un amministratore/trice di rete non può dire a una biblioteca come fare le sue cooptazioni, come gestire i suoi conflitti interni, o quale politica di accoglienza scegliere. Il diritto trasversale è tecnico, non politico.

## 7.7. Se la regola vi ostacola

**Trovate che la dottrina dell'informazione preliminare sia troppo permissiva** (un amministratore/trice di rete potrebbe abusare dell'«urgenza vitale»). Da discutere: occorre una definizione più restrittiva dell'urgenza? Occorre un secondo amministratore/trice di rete che confermi l'urgenza?

**Trovate che la dottrina sia troppo restrittiva** (a volte bisogna agire in fretta senza spiegare tutto). Da discutere: occorre distinguere diversi livelli di intervento, con regole di informazione diverse a seconda della criticità?

**Trovate che il silenzio sulla chiusura corretta di una biblioteca sia problematico** (§7.5). Avete ragione. Una spec dedicata è probabilmente da scrivere. Da portare alla rete.

**Trovate che questo capitolo lasci troppo spazio all'improvvisazione** nei casi di molestie (§7.3). È probabilmente vero. Una spec dedicata sui processi di mediazione e indagine potrebbe essere utile. Da portare alla rete.

Vedere capitolo 4 e allegato C.

\newpage

# 8. Il ruolo di amministratore/trice di rete

Questo capitolo si rivolge specificamente agli amministratori/trici di rete (presenti o futuri/e), e alle coordinazioni locali che vogliono capire come la rete si auto-organizza a livello superiore. Integra e approfondisce i capitoli 2 e 7.

## 8.1. Una funzione politica distinta

Prima di tutto: essere **admin di rete** non è né un grado, né una consacrazione, né un titolo. È una **funzione trasversale** che il collettivo degli admin di rete delega ad alcun* dei suoi membri, sulla base di un accordo unanime degli admin già in carica, e che può essere lasciata in qualsiasi momento.

Il progetto politico della funzione è quello di **far vivere il coordinamento inter-biblioteche**: accogliere le nuove biblioteche che si uniscono alla rete, animare le discussioni sulle evoluzioni tecniche e politiche del SIGB, mantenere la piattaforma tecnicamente, intervenire quando una biblioteca si trova in un blocco. Non è una funzione di direzione. È una funzione di animazione e di servizio.

### Cosa può fare un*/a admin di rete (politicamente)

- Attivare una nuova biblioteca che ha fatto la sua richiesta di iscrizione alla rete.
- Animare le discussioni inter-biblioteche (il canale Matrix `#anarbib`, gli incontri, le mailing list interne).
- Coordinare le evoluzioni della piattaforma (specifiche, release, comunicazioni).
- Intervenire su qualsiasi biblioteca in caso di blocco tecnico (diritto trasversale).
- Mediare tra due biblioteche in caso di conflitto (se le coordinazioni lo desiderano).
- Proporre o votare sulla cooptazione e il ritiro collettivo di altri admin di rete.

### Cosa non può fare un*/a admin di rete (politicamente)

- Dirigere una biblioteca.
- Imporre una decisione politica a una biblioteca (politica di accoglienza, modalità di validazione, cooptazioni interne, ecc.).
- Estromettere un*/a coord locale contro il volere della sua biblioteca.
- Modificare da sol* le regole della rete (ciò passa attraverso una discussione collettiva degli admin e idealmente delle coordinazioni).

## 8.2. La cooptazione all'unanimità: perché

L'admin di rete non viene aggiunt* a maggioranza, ma all'**unanimità** degli admin in carica. Questa regola può sorprendere — perché non una maggioranza semplice, una maggioranza qualificata, o un quorum?

La ragione politica è semplice: il potere di un*/a admin di rete è **trasversale**. Può intervenire su qualsiasi biblioteca. È quindi necessario che **ogni admin di rete attualmente attiv*** sia pront* a lavorare con la nuova persona. Se c'è un solo disaccordo profondo, la cooperazione sarà avvelenata — è meglio non imporla.

Questa regola ha una conseguenza pratica importante: **il veto è facile**. Un solo voto `opposed` è sufficiente. È volontario. Si preferisce che una cooptazione non vada a buon fine, piuttosto che lasci un*/a admin esistente in una posizione scomoda duratura.

## 8.3. Workflow di cooptazione, in dettaglio

### Fase 1 — Proposta

Un*/a admin di rete attiv*, dall'interfaccia `/rede/administradores` (in arrivo nel pacchetto D), clicca **« Proporre una cooptazione »**.

- Inserisce l'identità della persona proposta (cerca nella base degli utenti AnarBib).
- Inserisce una **motivazione** obbligatoria di **minimo 20 caratteri**. Questa motivazione è leggibile da tutt* gli admin, e — in caso di successo — sarà inclusa nella notifica alla persona cooptata.
- Conferma.

Il SIGB:
- Crea una riga in `network_administrator_cooptation_proposals` con `status='open'`, `expires_at = now() + 30 giorni`.
- Registra automaticamente il voto `favorable` del/della proponente.
- Invia una mail militante a tutt* gli altri admin attiv* invitandoli a votare.

### Fase 2 — Voti

Ogni altro/a admin attiv* ha 30 giorni per votare. Tre opzioni:

- **`favorable`**: accetta la cooptazione.
- **`opposed`**: pone il veto. **Razionale obbligatorio** di minimo 20 caratteri. Questo razionale sarà comunicato alla persona proposta e al/alla proponente in caso di rifiuto.
- **`abstain`**: si astiene. **L'astensione blocca**: la proposta va a buon fine solo all'unanimità dei voti `favorable`. Un'astensione non revocata ha lo stesso effetto pratico di un veto, salvo che può essere convertita in favorevole in seguito se la persona cambia idea.

### Dettaglio v0.3 — Divulgazione dell'identità

Un'opzione **« Rivela la mia identità in caso di rifiuto »** è selezionata per impostazione predefinita. Se si vota `opposed`, la propria identità sarà comunicata alla persona proposta e al/alla proponente, oltre al razionale.

È possibile **deselezionare** questa opzione per restare anonim*. In tal caso, il razionale sarà trasmesso senza il proprio nome (« un*/a opponente ha sollevato: ... »).

Politicamente, la **trasparenza per impostazione predefinita** corrisponde alla cultura militante di assunzione delle posizioni. Ma l'anonimato resta possibile per i casi in cui un'opposizione esporrebbe l'opponente a un costo personale sproporzionato.

### Promemoria automatici

Il cron invia promemoria agli admin che non hanno ancora votato:
- **G+14 giorni**: « Non hai ancora votato sulla cooptazione di X. »
- **G+25 giorni**: « Questa proposta scade tra 5 giorni, prendi posizione. »

### Fase 3 — Conclusione

**Se qualcuno vota `opposed`**: la proposta passa immediatamente a `status='rejected'`. La persona proposta e il/la proponente ricevono una mail che spiega il rifiuto, con il razionale (e l'identità dell'opponente se ha accettato la divulgazione).

**Se tutt* gli admin attiv* hanno votato `favorable`**: la proposta passa a `status='completed'`. Una riga viene inserita automaticamente in `network_administrators` con `status='active'` e `coopted_by_unanimity_of = ARRAY[<lista dei votanti>]`. La persona riceve una mail di benvenuto e un riepilogo è inviato a tutt* gli admin.

**Se trascorrono 30 giorni senza raggiungere un consenso**: la proposta passa a `status='expired'`. Nessuna cooptazione. Bisogna o ricominciare una nuova proposta, o considerare che la rete non è pronta ad accogliere questa persona per il momento.

## 8.4. Il ritiro collettivo all'unanimità

Il **ritiro collettivo** è lo specchio della cooptazione: per ritirare un*/a admin di rete contro la sua volontà, occorre l'unanimità degli altri admin attiv*.

### Workflow

1. **Proposta di ritiro** da parte di un*/a admin di rete attiv*, motivazione obbligatoria ≥ 20 caratteri.
2. **Voti** degli altri admin (favorable / opposed / abstain), con razionali se `opposed`.
3. **Se unanimità `favorable`**: la membership della persona interessata passa a `pending_removal`, con `pending_collective_removal_until = now() + 7 giorni`.
4. **Durante i 7 giorni di carenzia**: la persona interessata conserva i propri diritti operativi, ma riceve una mail chiara sulla propria uscita programmata. Può eventualmente avviare un'ultima discussione. **Non può annullare il ritiro unilateralmente**: solo l'unanimità degli altri admin può fare marcia indietro (proponendo un « annullamento del ritiro », workflow specchio).
5. **A G+7**: passaggio a `status='removed'`, `removed_at=now()`.

### Politicamente

Il **doppio blocco** (unanimità + carenzia 7g) rende il ritiro collettivo di un*/a admin di rete particolarmente difficile. È voluto. Il potere di un*/a admin di rete essendo trasversale, non lo si revoca alla leggera.

Inversamente, **l'auto-ritiro resta sempre possibile e facile** (cfr. §8.5). Questa è la dissimmetria politica: è semplice andarsene, è difficile essere cacciati/e. Ciò corrisponde alla cultura anarchica: si rispetta la decisione personale di lasciare una funzione, si inquadra fortemente la decisione collettiva di revocarla.

## 8.5. Auto-ritiro

Un*/a admin di rete può lasciare le proprie funzioni in qualsiasi momento, senza il consenso degli altri. È un atto **unilaterale e incondizionato** (P3 applicato a livello di rete).

### Procedura

Da `/rede/administradores`, sulla propria riga, cliccare **« Lasciare le mie funzioni di admin di rete »**. Modale di conferma, motivazione opzionale.

### Effetto

- La riga passa a `status='inactive'` (o `removed` secondo il contesto, da chiarire nel pacchetto D).
- Mail a tutt* gli altri admin attiv*.
- Audit log `event_type='self_removal_requested'`.

### Caso speciale: l'unic* admin attiv*

Se si è l'unic* admin attiv* e si vuole andarsene, il SIGB avvia una **carenzia speciale di 30 giorni**. Durante questo periodo:
- Si resta admin attiv* con tutti i propri diritti.
- Una mail urgente è inviata a tutt* gli ex admin (`status='inactive'` o `removed`) indicando loro la situazione.
- La rete ha 30 giorni per ricooptare un*/a nuov* admin (workflow normale di cooptazione, essendo il/la solo/a votante), oppure organizzare una transizione diversa.

A G+30, se non è stato fatto nulla, si esce effettivamente e la rete si ritrova **senza admin attiv***. Il SIGB continua a funzionare tecnicamente, ma nessuna azione di admin (attivazione di biblioteca, cooptazione, ecc.) è più possibile fino a un intervento manuale.

Questa procedura è concepita per **rallentare** la dissoluzione della rete nel caso in cui un*/a ultim* admin se ne andasse, senza però **impedire** tale partenza. La libertà di andarsene resta integra.

## 8.6. Il diritto trasversale nella pratica quotidiana

Il **diritto trasversale** è ciò che distingue politicamente l'admin di rete dallo staff locale: può agire come `coord+` su qualsiasi biblioteca, leggere il suo catalogo (anche se la visibilità è `private`), modificare le sue membership, ecc.

### Quando utilizzarlo

- **Attivazione di una nuova biblioteca**: workflow normale, è il caso d'uso principale del diritto trasversale.
- **Manutenzione**: una biblioteca ha una configurazione rotta, un parametro mal configurato, un bug bloccante. È possibile intervenire per correggere.
- **Blocco politico**: la biblioteca non ha più un*/a coord (cfr. §7.5), occorre ricooptare per ripartire.
- **Mediazione su richiesta**: la coordinazione locale vi sollecita esplicitamente per aiutare ad arbitrare un conflitto o prendere una decisione difficile.
- **Indagine a seguito di una segnalazione di rete**: un*/a lettore/trice segnala un problema grave in una biblioteca, e la coordinazione locale non risponde o è essa stessa parte del problema.

### Quando non utilizzarlo

- **Per curiosità**: non andare « a vedere cosa succede » in una biblioteca senza ragione operativa. È sorveglianza, non amministrazione.
- **Per imporre una decisione politica**: se non si è d'accordo con la politica di una biblioteca (modalità di validazione, regolamento, ecc.), se ne può discutere, ma non imporla.
- **Per aggirare un dibattito collettivo**: se la rete discute di un'evoluzione e non si è d'accordo, non si può utilizzare il proprio diritto trasversale per imporre il proprio punto di vista come fatto compiuto.

### Informazione preventiva obbligatoria

Questa è la dottrina della rete (capitolo 2, §2.4; capitolo 7, §7.6): **qualsiasi intervento di admin di rete su una biblioteca locale deve essere preceduto da un'informazione alla coordinazione locale**, salvo in caso di urgenza vitale.

Concretamente:
- **Mail alla coordinazione locale** che spiega cosa verrà fatto e perché.
- **Attesa di una risposta** salvo urgenza: da 24 a 72 ore secondo la natura dell'azione.
- **Se nessuna risposta e azione non urgente**: riproporre una volta, e procedere esplicitando nel log che la coordinazione locale è stata informata ma non ha risposto.
- **Se urgenza vitale**: agire, e inviare l'informazione immediatamente dopo spiegando perché l'urgenza ha giustificato l'azione senza attesa.

Ogni azione è tracciata in `cross_library_actions_log` con livello di criticità, leggibile dalla coordinazione locale a posteriori.

## 8.7. Il caso del primo admin e di Xavier

Il sistema presuppone almeno un*/a admin di rete attiv* affinché la cooptazione sia possibile. Il **primo admin** non potendo essere cooptato (non c'è nessuno per votare), è prevista un'eccezione.

All'11 maggio 2026, **Xavier** è iscritto/a come **admin di rete fondatore/trice** tramite INSERT diretto in `network_administrators`, con `coopted_by_unanimity_of = ARRAY[]::uuid[]` (array vuoto) e `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. Questa operazione è tracciata nell'audit log con `event_type='foundational_admin_added'` e `metadata.foundational=true`.

Questa operazione è **trasparente politicamente**: è documentata, spiegata, e pubblica. Non è una debolezza del sistema — è l'innesco indispensabile. Una volta posto questo fondamento, qualsiasi cooptazione successiva passa attraverso il workflow normale del §8.3.

Man mano che nuovi admin saranno cooptati/e, la « solitudine » iniziale si dissolverà. La rete ha vocazione ad avere **più admin attiv*** (l'obiettivo politico è generalmente un cerchio da 3 a 5 persone, in numero dispari per evitare blocchi in caso di voto su certi argomenti connessi fuori spec).

## 8.8. Se la regola vi crea problemi

**Trovate l'unanimità troppo esigente** (« non si riesce mai a cooptare, un veto blocca tutto »). È un dibattito di fondo sulla natura del collettivo degli admin di rete. Occorre ammorbidire verso una maggioranza qualificata? Occorre un meccanismo di supervoto? Da portare in discussione di rete, e possibilmente da formalizzare in una revisione della spec.

**Trovate l'unanimità troppo permissiva** (« si dovrebbero anche consultare le coordinazioni locali prima di cooptare un*/a admin »). È un'altra opzione politica: consultare le coordinazioni locali prima della cooptazione di un*/a admin di rete. Da discutere. Ciò allargherebbe il cerchio decisore ma appesantirebbe la procedura.

**Trovate la carenzia di 7g per il ritiro collettivo troppo lunga o troppo corta.** Da portare sulla spec.

**Trovate che la dottrina dell'informazione preventiva sia insufficientemente inquadrata**: cos'è esattamente un'« urgenza vitale »? Deve esserci una definizione canonica? Da discutere.

**Trovate che la funzione di admin di rete abbia troppo potere** (diritto trasversale troppo esteso) o non abbastanza (dovrebbe poter dirimere certi conflitti). È una questione politica fondamentale. Da discutere all'incontro annuale.

Vedere capitolo 4 e allegato C.

\newpage

# 9. La trasparenza in pratica

Questo capitolo tratta del funzionamento concreto della **trasparenza** in AnarBib: chi vede cosa, come, e perché. È l'applicazione del principio P5 (trasparenza massima) e di P6 (notifiche sistematiche).

## 9.1. Il principio

> **P5 — Trasparenza massima.** L'audit log delle modifiche di ruolo è leggibile da tutto lo staff attiv* della biblioteca.
> **P6 — Notifiche sistematiche.** Qualsiasi modifica di ruolo attiva un'email alla persona interessata e a tutta la coordinazione.

L'idea politica: **rendere impossibili le manipolazioni opache**. Se tutto è tracciato e leggibile, non si può in silenzio far passare una persona da uno stato a un altro senza che ciò sia visto dagli altri membri dello staff.

## 9.2. Chi vede cosa: matrice

### A livello di una biblioteca

| Informazione | reader | librarian | coordenador | admin di rete |
|---|---|---|---|---|
| Lista del team (ruoli attivi) | parziale (solo i nomi pubblici) | completa | completa | completa |
| Statuti (`suspended`, `pending_removal`) | no | sì | sì | sì |
| Audit log completo del team | no | sì | sì | sì |
| Audit log: ragioni delle azioni | no | sì | sì | sì |
| Richiesta di ritiro in corso: chi ha chiesto | no | sì | sì | sì |
| Dati personali degli altri lettori/trici | no | sì (di questa biblioteca) | sì | sì |

### A livello della rete

| Informazione | reader | staff biblioteca | admin di rete |
|---|---|---|---|
| Lista degli admin di rete attiv* | sì (pagina pubblica `/rede`) | sì | sì |
| Contatori di rete (numero di biblioteche, ecc.) | sì | sì | sì |
| Audit log di rete (cooptazioni, ritiri di admin) | no | no | sì |
| Proposte di cooptazione in corso | no | no | sì |
| Log cross-biblioteche (azioni di admin di rete su biblioteca X) | no | sì (della propria biblioteca) | sì |

## 9.3. L'audit log del team in pratica

È lo strumento di trasparenza più importante. È consultabile da `/biblioteca` → scheda **Team** → sezione **Storico del team**.

### Cosa vi si vede

Ogni voce mostra:
- Data e ora.
- Azione (« promoss* a librarian », « auto-retrocession* », « ritiro richiesto », « sospeso/a », « reintegrat* dopo sospensione », « passaggio automatico a inattiv* dopo 9 mesi », ecc.).
- Persona interessata (target).
- Autore/trice dell'azione (actor) — per le azioni umane. Vuoto per le azioni automatiche (cron).
- Ragione (se indicata).
- Ruolo e statuti prima/dopo.

### A cosa serve politicamente

- **Memoria collettiva**: si può ricostruire la storia della coordinazione, vedere come si è costituita e si è evoluta.
- **Guardia contro l'opacità**: se un*/a coord ha compiuto azioni dubbie (cooptazioni strane, sospensioni ingiustificate), è visibile da tutt*.
- **Strumento di deliberazione**: in caso di dibattito (« avevamo detto che avremmo fatto ruotare i/le coord! »), il log fornisce elementi fattuali.
- **Strumento di transizione**: quando arriva un*/a nuov* coord, può leggere il log per capire la storia recente senza dover interrogare tutti/e.

### Cosa bisogna farci

- **Leggerlo regolarmente**. Non ogni giorno, ma una volta al mese, durante una riunione di coordinazione ad esempio.
- **Discutere ciò che è strano**. Se un'azione vi sembra incomprensibile o ingiustificata, chiedete al/alla suo/a autore/trice.
- **Non usarlo come arma**. Il log è uno strumento di trasparenza collettiva, non uno strumento di sorveglianza interpersonale.

## 9.4. Le email di notifica

Ogni azione di governance attiva **una o più email** automatiche. Non è spam: è volontario, perché nessuno deve essere colpito/a da un cambiamento di ruolo senza esserne informato/a.

### Chi riceve cosa

| Evento | Persona interessata | Coord locali attiv* | Admin di rete |
|---|---|---|---|
| Cooptazione (T1, T2) | ✅ | ✅ | — |
| Auto-retrocessione (T3, T4) | ✅ conferma | ✅ | — |
| Richiesta di ritiro (T5) | ✅ | ✅ | — |
| Annullamento della richiesta (T8) | ✅ | ✅ | — |
| Fine carenzia (G+7) | ✅ | ✅ | — |
| Sospensione (T6) | ✅ urgente | ✅ | — |
| Revoca della sospensione (T7) | ✅ | ✅ | — |
| Uscita automatica a 9 mesi (T9) | ✅ promemoria + finale | ✅ (solo finale) | — |
| Ultim* coord che parte | ✅ | ✅ (il/la concerned*) | ✅ allerta |
| Cooptazione admin di rete (proposta) | — | — | ✅ |
| Cooptazione admin di rete (successo) | ✅ benvenuto/a | — | ✅ riepilogo |
| Cooptazione admin di rete (rifiuto) | ✅ con razionale | — | ✅ |
| Ritiro collettivo admin di rete | ✅ | — | ✅ |
| Intervento cross-biblioteche | — | ✅ (coord della biblioteca) | ✅ (l'autore/trice) |

### Il tono delle email

Le email di governance seguono le convenzioni militanti della rete (cfr. memoria interna): sobrietà, chiarezza, accessibilità (lingua comune senza gergo), formulazione inclusiva e scrittura desacralizzata. Niente formule ufficiali, niente firme burocratiche.

Esempio tipo per una richiesta di ritiro:
> Ciao Karl,
>
> La coordinazione della BLMF ha richiesto il tuo ritiro dal team (ruolo: librarian), a seguito di: « decisione AG del 04/05 ».
>
> Questo preavviso entrerà in vigore il **12 maggio 2026** (tra 7 giorni), salvo annullamento da parte di un*/a altr* coord entro tale data.
>
> Durante questo periodo, non hai più accesso alle funzioni di librarian. Per qualsiasi discussione, rivolgiti alla coordinazione della BLMF — questa decisione appartiene alla vita organica del collettivo locale e non si gestisce tramite il SIGB.
>
> AnarBib

Il tono mira a informare fattualmente senza drammatizzare né minimizzare.

### Riservatezza delle email — guardia anti-tracciamento

Le email di governance, come tutte le notifiche del SIGB, sono inviate tramite **Resend**, il sub-fornitore di invio della rete (cfr. registro dei trattamenti e DPA). Due garanzie politiche inquadrano questo invio:

- **Nessun tracciamento.** Il monitoraggio delle aperture e dei clic — che raccoglierebbe l'indirizzo IP, la localizzazione, il dispositivo e il client mail della persona destinataria — è un'opzione **disabilitata** sull'istanza AnarBib. Ricevere un'email di governance non lascia alcuna impronta tecnica lato rete.
- **Minimizzazione.** Solo i dati strettamente necessari all'invio transitano (indirizzo email, nome per la personalizzazione, contenuto della notifica). Nessun dato sensibile viene trasmesso.

Questa guardia è dottrinale: prolunga l'impegno di non-tracciamento della rete fino allo strato email. È documentata nel registro dei trattamenti (art. 30 RGPD) e nel DPA; qualsiasi cambiamento di sub-fornitore mail è notificato alle biblioteche aderenti (DPA art. 5.4).

## 9.5. Il caso delle notifiche « cross-biblioteche »

Quando un*/a admin di rete interviene su una biblioteca (cfr. §8.6), vengono prodotte due notifiche:

- **Notifica preventiva** (manuale): l'admin invia una mail alla coordinazione locale prima di agire. Formato libero.
- **Notifica automatica** (tramite il SIGB): all'esecuzione dell'azione, il sistema scrive in `cross_library_actions_log` con livello di criticità, e invia una mail ai/alle coord attiv* della biblioteca interessata.

Questa doppia notifica (manuale + automatica) garantisce che la coordinazione locale sia avvisata **prima** politicamente e **dopo** tecnicamente. La traccia tecnica è leggibile a posteriori nella scheda **Team** → sezione **Interventi di rete** (in arrivo nel pacchetto D).

## 9.6. Limiti della trasparenza

La trasparenza di AnarBib ha dei limiti, che occorre esplicitare:

**I `reader` non vedono l'audit log del team.** È volontario (P5 parla di « staff attiv* »). I `reader` non vedono chi ha cooptato chi, chi è stato/a sospeso/a, ecc. La trasparenza vale **nella coordinazione**, non verso gli/le utenti.

**Una biblioteca non vede l'audit log di un'altra biblioteca.** Sovranità locale (P7). Le modifiche di ruolo nella biblioteca A sono strettamente opache per la biblioteca B, salvo attraverso il canale umano (discussione tra coord delle due biblioteche).

**L'audit log di rete (cooptazioni e ritiri di admin) non è pubblico.** Leggibile solo dagli admin di rete. Una biblioteca locale può vedere la lista degli admin di rete attuali (pagina `/rede`), ma non la storia delle cooptazioni né le razionali dei voti contrari.

Questi limiti non sono ipocrisie. Corrispondono a un equilibrio tra **trasparenza** (all'interno dello staff deliberante) e **riservatezza** (nei confronti degli/delle utenti e tra perimetri). Se trovate l'equilibrio mal posto, è emendabile (capitolo 4).

## 9.7. Se la regola vi crea problemi

**Pensate che i `reader` dovrebbero vedere l'audit log del team** (trasparenza radicale verso gli/le utenti). È una posizione difendibile, ma ha delle conseguenze (i conflitti interni diventano pubblici, la vita politica del collettivo si espone). Da discutere in rete.

**Pensate al contrario che l'audit log sia troppo visibile** (un*/a librarian discret* non dovrebbe poter « spiare » le azioni dei/delle coord). È anche difendibile. Ma contraddice P5. Da discutere.

**Trovate le email troppo numerose o non abbastanza esplicite.** Il contenuto è parametrizzato in `mail-strings.ts` × 10 locali. Qualsiasi modifica di una mail è emendabile come una modifica di codice. Da portare con i/le dev.

**Pensate che l'audit log di rete dovrebbe essere pubblico almeno per i/le coord locali** (affinché possano vedere chi decide cosa a livello di rete). È un'opzione interessante. Da discutere.

Vedere capitolo 4 e allegato C.

\newpage

# 10. Casi concreti commentati

Per concludere, sei scenari completi. Ognuno illustra una combinazione di meccanismi e permette di vedere il SIGB in azione. I nomi (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) sono quelli dei compagn* storici del pensiero libertario; servono qui come casi tipo fittizi.

## 10.1. Voltairine viene cooptata librarian

> **Contesto.** Emma è coordinatrice/trice alla BLMF. Voltairine frequenta i turni da otto mesi, partecipa alla vita della biblioteca, e ha chiaramente il profilo per entrare nel gruppo. Il collettivo locale ne ha discusso in AG il 4 maggio e ha sancito la sua cooptazione.

**Procedura.**

1. Emma si connette il 5 maggio alle 14:30. Va in `/biblioteca`, scheda **Equipe**.
2. Cerca Voltairine nell'elenco dei `reader` della biblioteca (ha un account AnarBib da febbraio).
3. Clicca **« Invitare/trice nell'équipe »** → sceglie **librarian**.
4. Campo « Motivo »: « decisione AG del 04/05 » (dottrina 1, attesa rigorosa).
5. Conferma.

**Effetto immediato.**

- Voltairine riceve un'email: « Ciao Voltairine, sei stata nominata librarian della BLMF da Emma G. in seguito a: "decisione AG del 04/05". I tuoi nuovi diritti sono attivi. Benvenut* nel gruppo. »
- Le altre coordinatrici/trice attive della BLMF (Lucy e Piotr) ricevono un'email informativa.
- Audit log: `2026-05-05 14:30 — Emma G. ha promosso Voltairine d.C. librarian (motivo: decisione AG del 04/05)`.

**Commento.**

Caso più semplice. Il SIGB esegue correttamente la decisione del collettivo. Emma non ha deciso nulla politicamente — ha cliccato per eseguire ciò che era stato deciso fuori dal software.

**Ciò che il SIGB non ha fatto:** verificare che l'AG abbia davvero avuto luogo, che la decisione sia stata davvero presa, che Voltairine sia davvero d'accordo. Queste cose sono **fuori dal software**. Se Emma avesse mentito sull'AG, il SIGB non avrebbe visto nulla. La cultura politica della BLMF è ciò che impedisce questa menzogna (e il log la rende a posteriori tracciabile).

## 10.2. Lucy passa il testimone

> **Contesto.** Lucy è coordinatrice/trice alla BLMF, ma non riesce più a sostenere l'impegno questo semestre (inizia un dottorato). Vuole « retrocedere a librarian » per restare nel gruppo ma alleggerire le sue responsabilità.

**Procedura.**

1. Lucy va in `/biblioteca`, scheda **Equipe**.
2. Sulla propria riga (stato `coordenador`), clicca **« Passo il testimone »**.
3. Scelta: « retrocedere a librarian ».
4. La modale di conferma ricorda che perderà immediatamente i permessi di coordinamento.
5. Lucy conferma. Motivo opzionale: « inizio dottorato, alleggerimento temporaneo ».

**Effetto immediato.**

- La sua membership `coordenador` passa a `inactive`.
- La sua membership `librarian` (che esisteva in parallelo) rimane `active`.
- Lucy riceve un'email di conferma: « Sei ora librarian della BLMF. Mantieni le tue autorizzazioni operative. »
- Tutta la coordinazione (Emma, Piotr) riceve un'email: « Lucy P. ha passato il testimone, non è più coordinatrice/trice. Rimane librarian del gruppo. »
- Audit log: `2026-05-05 18:42 — Lucy P. si è auto-retrocessa coordenador → librarian (motivo: inizio dottorato, alleggerimento temporaneo)`.

**Commento.**

Questo è l'uso esemplare del diritto P3. Lucy non ha dovuto chiedere autorizzazione a nessuno. La sua auto-retrocessione è immediata. Continua a contribuire alla biblioteca, ma con un'intensità adeguata alla sua disponibilità attuale.

**Politicamente**: è esattamente il tipo di rotazione che si vuole favorire. Non si perde Lucy, prende semplicemente un altro ruolo. Tra sei mesi o un anno, se vorrà riprendere il coordinamento, il collettivo potrà ricooptarla (T2). Nessuna decisione è definitiva.

## 10.3. Karl deve andarsene

> **Contesto.** Karl è librarian alla BLMF. Il suo comportamento con alcun* lettori/trice ha posto problemi (paternalismo, commenti inappropriati). Il collettivo ne ha discusso in AG il 4 maggio e ha deciso che doveva lasciare il gruppo.

**Procedura.**

1. Piotr (coordinatore/trice) — scelto dall'AG per eseguire la decisione — va in `/biblioteca`, scheda **Equipe**.
2. Sulla riga di Karl, clicca **« Richiedere la rimozione »**.
3. Modale rossa con i 7 giorni di ritardo espliciti.
4. Motivo obbligatorio: « A seguito di AG del 04/05, comportamento inadeguato con diversi lettori/trice segnalato per diversi mesi, decisione collettiva di esclusione. »
5. Conferma esplicita: « Comprendo che questa richiesta avrà effetto il 12 maggio 2026 salvo annullamento da parte di un* altr* coordinatore/trice. »

**Effetto immediato.**

- La membership di Karl passa a `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl perde l'accesso** immediatamente a tutte le funzioni di librarian (la membership è bloccata).
- Karl riceve un'email:
  > « Ciao Karl, la coordinazione della BLMF ha richiesto la tua rimozione dal gruppo (ruolo: librarian), a seguito di: "A seguito di AG del 04/05, comportamento inadeguato con diversi lettori/trice segnalato per diversi mesi, decisione collettiva di esclusione." Questo preavviso avrà effetto il 12 maggio 2026 (tra 7 giorni), salvo annullamento da parte di un* altr* coordinatore/trice entro tale data. Per qualsiasi discussione, rivolgiti alla coordinazione della BLMF. »
- Emma e Lucy (altre coordinatrici/trice) ricevono l'email informativa.
- Audit log: `2026-05-05 — Piotr K. ha richiesto la rimozione di Karl M. (ruolo: librarian, motivo: ...)`.

**Evoluzione.**

- 6 maggio alle 9h: Lucy legge l'email. È d'accordo con la decisione e non interviene.
- 7 maggio: Emma ha uno scambio con Karl (che le scrive per spiegarsi). Emma conclude che la decisione tiene. Non interviene.
- 8-11 maggio: niente.
- **12 maggio alle 00:00**: il cron `cron_team_pending_removal_complete` viene eseguito. Karl passa a `inactive`.
- Email finale a Karl e alla coordinazione.
- Audit log: `2026-05-12 — passaggio automatico a inattivo (motivo: pending_removal scaduto, cron) — actor: NULL`.

**Commento.**

Questo è il caso dell'esclusione collettiva. Tre elementi politici da notare:

- **La carence ha funzionato come possibile salvaguardia**, senza essere utilizzata. Lucy ed Emma avrebbero potuto annullare; non l'hanno fatto. Il fatto che nessuno abbia annullato è esso stesso una **deliberazione implicita**.
- **Karl è rimasto informato** senza sorprese. Nessuna esclusione silenziosa.
- **L'audit log è leggibile** da tutto lo staff e permette di tornare su questa decisione se in seguito qualcuno si chiede perché Karl è andato via.

**Politicamente delicato**: il motivo scritto nel campo « Motivo » è leggibile da tutto lo staff. Non dovrebbe contenere dettagli sulle vittime (RGPD, dignità), ma dovrebbe essere abbastanza chiaro da rendere la decisione difendibile politicamente. Trovare il giusto equilibrio è una competenza di coordinamento.

## 10.4. Account compromesso: sospensione immediata

> **Contesto.** Il 5 maggio alle 19:30, Emma nota nei log di attività che Friedrich (librarian) ha effettuato 47 modifiche a schede catalogo in 3 minuti, di cui diverse aberranti (libri segnati come « scomparsi » mentre sono in scaffale, ecc.). Il pattern somiglia a un accesso non autorizzato.

**Procedura.**

1. Emma va in `/biblioteca`, scheda **Equipe**.
2. Sulla riga di Friedrich, clicca **« Sospendere »**.
3. Modale con motivo **obbligatorio** (≥ 20 caratteri).
4. Emma digita: « Sospetto account compromesso, attività anomala (47 modifiche catalogo in 3 min), verifica in corso. »
5. Conferma.

**Effetto immediato (19:32).**

- Friedrich passa a `status='suspended'`.
- **Nessun accesso** per Friedrich.
- Friedrich riceve un'email urgente: « Il tuo account AnarBib è stato sospeso a titolo conservativo alla BLMF. Motivo: sospetto di compromissione del tuo account. Ti suggeriamo vivamente di **cambiare immediatamente la tua password**. Una volta messo in sicurezza il tuo account, contatta la coordinazione della BLMF perché la sospensione venga revocata. »
- La coordinazione (Lucy, Piotr) riceve un'email.
- Audit log: `2026-05-05 19:32 — Emma G. ha sospeso Friedrich E. (ruolo: librarian, motivo: ...)`.

**Evoluzione.**

- **19:35**: Emma chiama Friedrich (canale fuori-SIGB). Friedrich conferma di non aver effettuato queste azioni. Aveva lasciato il computer aperto in uno spazio condiviso.
- **19:40**: Friedrich cambia la sua password tramite la procedura di reimpostazione.
- **20:00**: Emma verifica le azioni sospette nell'audit log della biblioteca (l'audit catalogo, non l'audit team). Identifica le 47 modifiche. Le annulla manualmente o richiede un rollback a un* amministratore/trice di rete se necessario.
- **20:15**: Emma torna nella scheda Equipe, revoca la sospensione di Friedrich.
- Friedrich riceve un'email di conferma. Audit log: `2026-05-05 20:15 — Emma G. ha revocato la sospensione di Friedrich E.`.

**Commento.**

Caso tipico in cui la sospensione è usata come **misura conservativa**, non come esclusione. Friedrich non è in torto — è il suo account ad essere stato compromesso. La sospensione è durata 43 minuti, il tempo di mettere in sicurezza.

**Politicamente importante**: Friedrich non è stato « accusato ». L'email lo precisa chiaramente (« a titolo conservativo »). Quando la situazione è risolta, la sospensione viene revocata, e l'episodio è registrato nel log come un incidente, non come una sanzione.

## 10.5. Errico è l'ultimo/a coordinatore/trice e vuole andarsene

> **Contesto.** La BLMF ha ormai un solo/a coordinatore/trice attiv*, Errico. Lucy ha passato il testimone, Emma si è trasferita e non è più attiva. Piotr si è auto-retrocesso all'inizio dell'anno. Errico deve andarsene (trasferimento all'estero, non ha più tempo).

**Procedura.**

1. Errico va in `/biblioteca`, scheda **Equipe**, clicca **« Passo il testimone »**.
2. Si apre una **modale speciale**:
   > ⚠️ **ATTENZIONE**: sei l'unico/a coordinatore/trice attiv* della BLMF. La biblioteca si ritroverà senza coordinamento. Gli/le amministratori/trice di rete di AnarBib saranno notificat*. La BLMF potrà continuare a funzionare (i/le librarian* restano operativ*) ma nessuna modifica alla configurazione sarà possibile fino alla cooptazione di un* nuov* coordinatore/trice. Continuare?
3. Errico conferma. Motivo: « Trasferimento all'estero, non ho più disponibilità per il coordinamento. »

**Effetto immediato.**

- La membership coordenador di Errico passa a `inactive`.
- Email a Errico (conferma).
- Email a tutta la coordinazione della BLMF — ma non ce n'è più, quindi in pratica sono i/le `librarian` attiv* rimanenti a ricevere una notifica.
- **Email urgente agli/alle amministratori/trice di rete**: « La BLMF non ha più coordinatori/trice attiv*. Ecco i/le librarian* attiv* rimanenti: Voltairine d.C., Friedrich E., ... »
- Audit log: `2026-05-05 — Errico M. si è auto-retrocesso coordenador → reader (motivo: ..., warning: last_coordinator_leaving)`.

**Evoluzione fuori-software.**

- 6 maggio: Xavier (amministratore/trice di rete) prende contatto con Voltairine e Friedrich, i/le `librarian` attiv* rimanenti. Confermano che il collettivo BLMF esiste ancora, e che vogliono continuare.
- 7-15 maggio: discussione interna del collettivo BLMF, che decide in AG di cooptare Voltairine nel ruolo di coordinatrice/trice.
- 16 maggio: Xavier (o un* altr* coordinatore/trice BLMF che non esiste più in questo caso, quindi Xavier nel suo diritto trasversale) cootta Voltairine come coordinatrice/trice. **Informazione preliminare obbligatoria**: Xavier ha scritto a Friedrich e Voltairine 2 giorni prima per annunciare l'azione. Una volta effettuata, l'azione è registrata in `cross_library_actions_log` con livello di criticità « elevato » (modifica del coordinamento di una biblioteca da parte di amministratore/trice di rete).

**Commento.**

Caso politicamente delicato: la biblioteca attraversa un periodo di fragilità (tra il 5 e il 16 maggio, è senza coordinamento). Ma il SIGB **non ha impedito** la partenza di Errico — il suo diritto P3 è incondizionale. Il SIGB ha semplicemente **allertato la rete** perché questa potesse aiutare.

L'intervento di Xavier illustra l'uso **corretto** del diritto trasversale: è stato sollecitato (implicitamente, dall'alerta automatica), ha rispettato l'informazione preliminare, ha tracciato la sua azione. Non ha imposto Voltairine; è stato il collettivo BLMF a sceglierla. Xavier ha semplicemente **eseguito tecnicamente** la decisione.

## 10.6. Una cooptazione di amministratore/trice di rete che va a monte

> **Contesto.** Xavier è amministratore/trice di rete fondatore/trice. Nel corso del tempo, Maria, Patricia e Diego sono stati/e cooptat* amministratori/trice di rete man mano che la rete si è allargata. Al 20 maggio 2026, il collettivo degli/delle amministratori/trice è: Xavier, Maria, Patricia, Diego (quattro amministratori/trice attiv*).
>
> Maria propone la cooptazione di Mohammed, che conosce in una biblioteca italiana che entra nella rete.

**Procedura.**

1. Maria, da `/rede/administradores`, clicca **« Proporre una cooptazione »**.
2. Inserisce l'identità di Mohammed (account AnarBib creato due settimane prima).
3. Motivazione: « Mohammed coordina la BLA (Bologna), una biblioteca che entra nella rete questo mese. Ha portato l'integrazione politica della BLA in AnarBib ed è molto coinvolt* nel coordinamento italiano. La sua cooptazione come amministratore/trice di rete rafforzerà la diversità geografica del collettivo e faciliterà l'animazione lato Italia. »
4. Conferma.

**Effetto immediato.**

- Proposta creata, `status='open'`, `expires_at = 19 giugno 2026`.
- Voto automatico `favorable` di Maria registrato.
- Email a Xavier, Patricia, Diego con la proposta.

**Evoluzione.**

- 22 maggio: **Diego** vota `favorable`. Nessuna motivazione (opzionale per i favorevoli).
- 25 maggio: **Patricia** vota `opposed`. Motivazione: « Mohammed non ha alcuna anzianità nella rete. La sua cooptazione va più veloce di quella della BLA, che non ha ancora avuto l'occasione di funzionare come biblioteca AnarBib per abbastanza tempo. Propongo di aspettare 6 mesi perché la BLA prenda le sue marche, poi di riproporre Mohammed in quel momento. » Patricia spunta « Rivela la mia identità ».

**Effetto immediato del voto opposed.**

- La proposta passa a `status='rejected'`.
- Email a Mohammed: « Ciao Mohammed, la tua proposta di cooptazione come amministratore/trice di rete di AnarBib non è andata a buon fine. Patricia X. ha sollevato la seguente obiezione: "[motivazione completa]". Puoi discuterne con lei o con Maria, che ti aveva propost*. La cooptazione potrà essere riproposta in seguito. »
- Email a Maria (proponente): riepilogo con la motivazione di Patricia.
- Email a Xavier e Diego: informazione che la proposta è respinta, con la motivazione.
- Audit log di rete: `2026-05-25 — cooptazione respinta: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Commento.**

Caso illustrativo dell'unanimità **in azione**. Patricia ha un veto, lo usa, la sua motivazione è esplicita e costruttiva (« aspettiamo 6 mesi »). Ha scelto di rivelare la sua identità, il che permette a Mohammed e Maria di discutere direttamente con lei piuttosto che speculare sull'opponentə anonimə.

**Politicamente**: la cooptazione all'unanimità non è una garanzia di blocco permanente. Patricia non dice « mai » ma « non adesso ». Se tra 6 mesi la BLA è ben integrata e Patricia cambia idea, una nuova proposta potrà andare in porto. È questa **reversibilità nel tempo** che rende l'unanimità sopportabile.

L'alternativa — cooptare Mohammed a maggioranza contro il parere di Patricia — avrebbe creato un cerchio di amministratori/trice in cui Patricia si sarebbe sentita fuori posto. Meglio aspettare.

\newpage

# Allegati

\newpage

# Allegato A — Glossario

**AG** — Assemblea generale. Riunione collettiva di presa di decisione di una biblioteca. Il SIGB non modella l'AG (P8). La sua modalità (quorum, frequenza, modalità di deliberazione) è interamente decisa da ogni biblioteca.

**Audit log** — Registro delle azioni di governance, archiviato in `library_membership_audit` (a livello di biblioteca) e `network_administrator_audit` (a livello di rete). Leggibile dallo staff attiv* (a livello biblioteca) e dagli/dalle amministratori/trice di rete (a livello rete).

**Auto-retrocessione** — Azione con cui una persona dello staff si retrocede autonomamente a un ruolo inferiore. Diritto P3, incondizionale.

**Biblioteca `private`** — Biblioteca il cui catalogo è visibile solo dai/dalle suoi/sue membri iscritti. Modalità adatta alle biblioteche politicamente esposte.

**Biblioteca `network`** — Biblioteca il cui catalogo è visibile da tutt* i/le `reader` validat* della rete AnarBib. Modalità predefinita per la maggior parte delle biblioteche.

**Biblioteca `public`** — Biblioteca il cui catalogo è visibile da tutti, inclusi i/le visitatori/trice anonimi.

**Carence** — Ritardo imposto tra una decisione e il suo effetto. Sette giorni per le rimozioni collettive di staff locale e di amministratore/trice di rete. Trenta giorni per l'auto-ritiro dell'unico/a amministratore/trice di rete attiv*.

**Cooptazione** — Meccanismo di ingresso in un gruppo (staff locale) o nel collettivo degli/delle amministratori/trice di rete. Per lo staff locale: decisione di un*/una coordinatore/trice+. Per la rete: unanimità degli/delle amministratori/trice attiv*.

**Cross-biblioteche** — Qualifica un'azione effettuata da un*/una amministratore/trice di rete su una biblioteca di cui non è membro dello staff locale. Registrata in `cross_library_actions_log`.

**Cron** — Compito automatico eseguito periodicamente dal SIGB. Senza attore/trice umano/a. Esempi: `cron_team_pending_removal_complete` (passaggio da `pending_removal` a `inactive` a G+7), `cron_team_inactive_cleanup` (uscita automatica a 9 mesi).

**Delega** — Atto con cui un collettivo affida temporaneamente una funzione a un/una dei suoi membri, mantenendo la possibilità di riprenderla. Concetto centrale, distinto da « gerarchia ».

**Membership** — Riga della tabella `user_library_memberships` che esprime il legame di una persona a una biblioteca in un dato ruolo. Una persona può avere più membership in una biblioteca (multi-membership).

**Multi-membership** — Possibilità di avere più righe di membership per la stessa persona nella stessa biblioteca, con ruoli diversi.

**Rete** — Il collettivo delle biblioteche che si riconoscono reciprocamente e condividono la piattaforma AnarBib. Non un'organizzazione centrale, una federazione.

**RPC** — *Remote Procedure Call*. Funzione SQL chiamata dall'interfaccia utente/trice per eseguire un'azione. Tutte le azioni di governance passano per RPC denominate `fn_team_*` (staff locale) o `fn_network_admin_*` (rete).

**Sovranità locale** — Principio P7 secondo cui ogni biblioteca è sovrana sulle proprie deleghe interne. I cambiamenti di ruolo in una biblioteca non influenzano nulla in un'altra.

**Spec** — Documento di specifica (`spec-*.md`) che descrive in dettaglio il funzionamento di una funzionalità del SIGB. Fonte di verità tecnica e politica. Versionata, datata, emendabile.

**Unanimità** — Modalità di cooptazione e di ritiro collettivo degli/delle amministratori/trice di rete. Tutti i voti devono essere `favorable`; un solo `opposed` o un'astensione non revocata blocca.

**Validazione fisica** — Procedura con cui un*/una librarian+ valida un account `reader` dopo un incontro fisico. Vale per tutta la rete (patto di riconoscimento reciproco).

**Veto** — Voto `opposed` durante una cooptazione o un ritiro collettivo di amministratore/trice di rete. Effetto immediato: rigetto della proposta. Motivazione obbligatoria di minimo 20 caratteri.

\newpage

# Allegato B — Indice delle funzioni tecniche

Questo allegato fornisce, per ogni RPC menzionata nella guida, la sua traduzione politica e la transizione interessata. Serve come riferimento rapido.

## Funzioni di staff locale

| RPC SQL | Transizione | Traduzione politica |
|---|---|---|
| `fn_team_promote_to_librarian` | T1 | Cooptazione `reader` → `librarian` |
| `fn_team_promote_to_coordenador` | T2 | Cooptazione `librarian` → `coordenador` |
| `fn_team_self_demote` | T3, T4 | Auto-retrocessione (« passo il testimone ») |
| `fn_team_request_remove_member` | T5 | Richiesta di rimozione con carence 7g |
| `fn_team_cancel_remove_member` | T8 | Annullamento di una richiesta di rimozione |
| `fn_team_suspend_member` | T6 | Sospensione immediata (misura conservativa) |
| `fn_team_unsuspend_member` | T7 | Revoca della sospensione |
| `fn_validate_physical_account` | — | Validazione fisica di un*/una `reader` |
| `cron_team_pending_removal_complete` | T5 (seguito) | Cron: passaggio a `inactive` a G+7 |
| `cron_team_inactive_cleanup` | T9 | Cron: uscita automatica a 9 mesi |

## Funzioni di amministratore/trice di rete

| RPC SQL | Fase | Traduzione politica |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Cooptazione: proposta | Un*/una amministratore/trice propone un*/una nuov* |
| `fn_network_admin_vote_cooptation` | Cooptazione: voto | Voto favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Auto-ritiro | Lasciare le funzioni di amministratore/trice di rete |
| `fn_network_admin_request_removal` | Ritiro collettivo | Workflow speculare della cooptazione |

## Helper di autorizzazione (usati dalle RLS)

| Helper SQL | Significato politico |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | Questa persona può agire come staff su questa biblioteca? (staff locale attiv* O amministratore/trice di rete) |
| `user_can_engage_library(library_id)` | Questa persona può impegnare politicamente questa biblioteca? (coordinatore/trice locale attiv* O amministratore/trice di rete) |
| `fn_caller_is_network_admin()` | La persona chiamante è un*/una amministratore/trice di rete attiv*? |
| `fn_library_visible_to_caller(library_id)` | Il catalogo di questa biblioteca è visibile per la persona chiamante? |

## Tabelle principali

| Tabella | Significato politico |
|---|---|
| `user_library_memberships` | Le deleghe locali (chi è staff di quale biblioteca) |
| `network_administrators` | Gli/le amministratori/trice della rete |
| `library_membership_audit` | Registro delle azioni di governance locale |
| `network_administrator_audit` | Registro delle azioni di governance di rete |
| `network_administrator_cooptation_proposals` | Proposte di cooptazione in corso |
| `network_administrator_cooptation_votes` | Voti individuali degli/delle amministratori/trice |
| `cross_library_actions_log` | Traccia delle azioni di amministratore/trice di rete sulle biblioteche |

\newpage

# Allegato C — Modello di nota di emendamento

Quando volete proporre un emendamento a una regola del SIGB o a questa guida, ecco un modello di nota per strutturare la proposta. Formato libero, potete adattarlo.

---

## Proposta di emendamento a [nome della spec o della guida]

**Autori/trice:** [i vostri nomi / pseudonimi]
**Data:** [GG/MM/AAAA]
**Perimetro:** [biblioteca locale / rete / fondamenti]

### 1. Regola interessata

Citare testualmente la regola o il paragrafo da emendare, con il suo riferimento nella spec fonte.

> *Esempio:* « `spec-gouvernance-roles.md`, §5.6, T5: Il ritardo di carence prima dell'esclusione effettiva è di 7 giorni. »

### 2. Problema identificato

Descrivere in alcune frasi ciò che pone problema nella regola attuale. Se possibile con un caso concreto incontrato.

> *Esempio:* « In pratica, 7 giorni è troppo breve quando l'AG successiva della biblioteca si tiene tra 15 giorni. Una decisione di rimozione presa a caldo non ha a volte il tempo di essere discussa collettivamente prima dell'effetto automatico. »

### 3. Emendamento proposto

Descrivere la modifica desiderata, nella misura del possibile con una formulazione pronta da integrare nella spec.

> *Esempio:* « Portare il ritardo di carence da 7 a 14 giorni, OPPURE rendere il ritardo configurabile per biblioteca (tra 7 e 30 giorni), con un valore predefinito a 14 giorni. »

### 4. Conseguenze tecniche anticipate

Se avete un'idea di cosa implica lato codice, dirlo. Altrimenti, dirlo comunque (« non lo so, da vedere con i/le dev »).

> *Esempio:* « Modificare il valore fisso nel codice SQL di `fn_team_request_remove_member` e `cron_team_pending_removal_complete`. Se configurabile per biblioteca, aggiungere una colonna a `libraries`. »

### 5. Conseguenze politiche anticipate

Descrivere cosa cambia nella pratica collettiva, ed eventuali effetti collaterali.

> *Esempio:* « Più tempo per la deliberazione, ma anche più tempo durante il quale la persona in `pending_removal` rimane sospesa (senza accesso). Può essere percepito come più pesante. »

### 6. Alternative considerate

Menzionare le altre piste a cui avete pensato, e perché le scartate (o no).

> *Esempio:* « Alternativa: lasciare il ritardo a 7 giorni ma permettere una "proroga esplicita" da parte di un*/altra coordinatore/trice. Più complessa da implementare e da capire. Preferibile modificare il valore predefinito. »

### 7. Discussione desiderata

Dove e come volete che la proposta venga discussa?

> *Esempio:* « Discussione sul canale Matrix `#anarbib`, poi se consenso, integrazione nella spec nel prossimo pacchetto di governance. »

---

Una volta redatta, far circolare la nota secondo il perimetro (cfr. capitolo 4, §4.2).

\newpage

# Allegato D — Spec fonti e riferimenti

Questa guida si basa sui documenti seguenti, consultabili nel deposito del progetto:

## Spec principali

**`spec-gouvernance-roles.md`** — Spec fondatrice della governance dei ruoli di staff locale. Versione 1.0 del 5 maggio 2026. 1231 righe. Dettaglia i 4 ruoli, i 5 stati, le 9 transizioni, l'audit log, le notifiche, l'interfaccia, e 15 casi d'uso di riferimento.

**`spec-administrateur-reseau.md`** — Separazione tra staff locale e amministratore/trice di rete. Versione 0.3 dell'11 maggio 2026. 975 righe. Dettaglia la tabella `network_administrators`, la cooptazione all'unanimità, il ritiro collettivo, il diritto trasversale, la semantica dei contatori « pagina = perimetro ».

**`spec-validation-physique.md`** — Modalità di accoglienza degli account lettori/trice (`open` vs `manual_validation`). Definita il 3 maggio 2026. Dettaglia gli stati dell'account, lo schema DB, i workflow.

**`spec-refactor-v3-semantique.md`** — Refactoring della semantica del workflow di prenotazione. Non centrale per la governance ma citato a margine per la coerenza d'insieme del SIGB.

## Spec cugine menzionate (da redigere o in corso)

- `spec-migration-compte.md` — Migrazione di un account da una biblioteca a un'altra. 940 righe, definita il 3 maggio 2026.
- `spec-invitation-equipe.md` — Workflow di invito via email per le persone senza account AnarBib. Da redigere.
- `spec-fermeture-biblio.md` — Procedura di chiusura regolare di una biblioteca. Da redigere.
- `spec-mediation-conflits.md` — Quadro formalizzato di mediazione e indagine a seguito di segnalazione. Da redigere (suggerito dalla presente guida).

## Per saperne di più

Le spec e il codice sorgente sono sul deposito Codeberg del progetto, mirror GitHub. La discussione tecnica e politica si svolge sul canale Matrix `#anarbib` della rete.

Per qualsiasi proposta di emendamento a questa guida o alle spec, vedere capitolo 4 e allegato C.

---

*Fine della guida. Versione 1.0, 11 maggio 2026.*

*Questa guida è essa stessa emendabile. Se ritenete che dica il falso, che abbia dimenticato un caso, o che prenda una posizione che non corrisponde più alla dottrina della rete, ditelo.*

