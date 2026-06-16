# Carta del linguaggio inclusivo di AnarBib

**Versione** : 2.0
**Data** : 2026-06-05
**Stato** : riferimento del progetto (fonte unica di autorità)
**Sostituisce** : `anarbib-charte-langage-inclusif-v1.md` (v1.0, 2026-04-28), ora **deprecata**

Questo documento fissa le convenzioni di linguaggio inclusivo adottate nelle **dieci
locali** di AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`,
`el`). Si applica a ogni nuova traduzione, a ogni rilettura e a ogni
contribuzione futura. È destinato alle persone che contribuiscono ai file
`src/i18n/locales/*.json`, alle stringhe delle notifiche mail
(`supabase/functions/_shared/i18n/mail-strings.ts`) e a ogni traduzione
generata in seguito.

> **Evoluzione dalla v1** : la v1 copriva solo sei locali (`pt-BR`, `fr`,
> `es`, `en`, `it`, `de`). La v2 aggiunge `ca`, `eo`, `nl`, `el`, e **ufficializza
> la convenzione italiana** (asterisco per le coppie regolari, slash per
> le coppie irregolari) che sostituisce lo slash provvisorio della v1.

---

## Sommario

1. [Perché questo documento](#perché-questo-documento)
2. [Principio guida : coerenza interna per lingua](#principio-guida--coerenza-interna-per-lingua)
3. [Tabella degli stati](#tabella-degli-stati)
4. [Carta per lingua](#carta-per-lingua)
   - [Francese (fr)](#francese-fr)
   - [Tedesco (de)](#tedesco-de)
   - [Inglese (en)](#inglese-en)
   - [Portoghese brasiliano (pt-BR)](#portoghese-brasiliano-pt-br)
   - [Spagnolo castigliano (es)](#spagnolo-castigliano-es)
   - [Italiano (it)](#italiano-it)
   - [Catalano (ca)](#catalano-ca)
   - [Esperanto (eo)](#esperanto-eo)
   - [Olandese (nl)](#olandese-nl)
   - [Greco (el)](#greco-el)
5. [Termini politici di riferimento](#termini-politici-di-riferimento)
6. [Termini proscritti](#termini-proscritti)
7. [Procedura per le aggiunte future](#procedura-per-le-aggiunte-future)
8. [Copertura dei test (CI)](#copertura-dei-test-ci)
9. [Evoluzione della carta](#evoluzione-della-carta)

---

## Perché questo documento

AnarBib è un sistema integrato di gestione di biblioteche pensato per le
biblioteche militanti anarchiche. Una biblioteca militante non è una
biblioteca come le altre : non archivia soltanto documenti, costituisce **una memoria
collettiva**, e il linguaggio della sua interfaccia fa parte di questa memoria.
Un'interfaccia che parla di « lettore » al maschile generico riproduce il gesto
di cancellazione che una biblioteca femminista o queer cerca precisamente di smantellare ;
un'interfaccia che dice « compagn* » segnala fin dal primo istante a quale movimento appartiene.

Ma il linguaggio inclusivo non è una norma universale. Ogni lingua ha la sua
propria storia, le sue proprie convenzioni militanti, i propri terreni
politici minati. **Non esiste una « buona » scrittura inclusiva
trasversale** : esistono scelte locali situate, difese da comunità
militanti situate. Questa carta rispetta queste situazioni locali garantendo al
tempo stesso che all'interno di una stessa lingua AnarBib parli con una sola voce.

Tre obiettivi concreti :

1. **Coerenza.** All'interno di uno stesso file di locale, la stessa posizione di
   genere si scrive sempre nello stesso modo.
2. **Rispetto delle culture militanti locali.** Nessuna imposizione di una convenzione
   da una lingua all'altra.
3. **Leggibilità da parte di non specialiste.** Un* bibliotecari* militant* che scopre
   AnarBib deve potersene servire senza essere espert* in tipografia inclusiva.

---

## Principio guida : coerenza interna per lingua

Ogni lingua di AnarBib applica **la propria convenzione tipografica di scrittura
inclusiva**, ereditata dall'uso militante locale. Nessuna convenzione trasversale
viene imposta.

All'interno di una lingua, **queste convenzioni sono obbligatorie ed esclusive** :
un file `fr.json` non mescola il punto mediano con `(e)` ; un file
`it.json` non mescola l'asterisco con il punto mediano. Le scelte operate in
questa carta sono la **forma ufficiale** di AnarBib per quella lingua.

---

## Tabella degli stati

| Locale | Convenzione | Stato |
|---|---|---|
| `pt-BR` | Forma tripla `(o/a/e)` | **Adottata** (riferimento) |
| `fr` | Punto mediano `·` | **Adottata** |
| `es` | `e` neutro (convenzione argentina) | **Adottata** |
| `en` | Epiceno + `they` singolare | **Adottata** |
| `de` | Genderstern `*` | **Adottata** |
| `it` | Asterisco (coppie regolari) / slash (coppie irregolari) | **Adottata** |
| `ca` | Terminazione tripla `-a-e` + articolo `le` | **Adottata** |
| `eo` | Infisso `-in-` visibilizzato con trattini + pronome `ri` | **Adottata** |
| `nl` | Forme di ruolo neutre | **Provvisoria** — da validare in comunità |
| `el` | — | **Da definire** con una persona parlante greca militante |

---

## Carta per lingua

### Francese (fr)

**Convenzione adottata** : punto mediano (`·`, U+00B7).

**Forma generica** : radice comune + punto mediano + terminazione femminile.

| Maschile | Femminile | Forma AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Plurale** : si aggiunge `·s` (`lecteur·rice·s`).
**Articoli / determinanti combinati** : `le·la`, `du·de la`, `au·à la`, `un·e`,
`le·la SEUL·E`, `actif·ve`.
**Parole già epicene** : invariate (`bibliothécaire`, `camarade`, `responsable`,
`personne`).
**Proscritto** : `(e)`, `-e` separato (convenzioni pre-2010), punto ordinario `.` o
pallino `•` al posto del mediano.

### Tedesco (de)

**Convenzione adottata** : Genderstern (`*`, asterisco ASCII U+002A).

| Maschile | Femminile | Forma AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Plurale** : `*innen` (`Genoss*innen`, `Leser*innen`).
**Proscritto** : Mediopunkt `·`, Genderdoppelpunkt `:innen`, e il neologismo
ispanofono *« Compas »* lasciato non tradotto (sempre `Genoss*in`/`Genoss*innen`).

### Inglese (en)

**Convenzione adottata** : termini epiceni per default, `they/them/their` al
singolare come pronome neutro.

La grammatica inglese è ampiamente epicena : si utilizza sistematicamente la
forma neutra esistente (`reader`, `librarian`, `author`, `administrator`,
`comrade`, `coordinator`, `user`), senza marcatura tipografica. Per i rari
termini gendered, si sceglie la forma epicena (`actor` piuttosto che `actress`,
`server` piuttosto che `waitress`).
**Proscritto** : `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Portoghese brasiliano (pt-BR)

**Convenzione adottata** : forma tripla `(o/a/e)` o `(a/e)` secondo la grammatica,
includendo esplicitamente le tre posizioni (femminile, maschile, non-binario).
**È la locale di riferimento del progetto.**

| Maschile | Femminile | Forma AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Regola** : parole in `-or` → `(a/e)` ; parole in `-o` → `(o/a/e)`. Terminazioni per
ordine alfabetico nella parentesi.
**Contrazioni articolo-preposizione** : `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`,
`(o/a/e)s`.
**Parole già epicene** : invariate (`camarada`, `colega`, `responsável`,
`pessoa`).
**Proscritto** : `(a)` da solo, `/a`, `/o`, `@` (arroba), `x`. Attenzione al
**falso amico `camarade`** (forma francese) : in pt-BR è **`camarada`**.

### Spagnolo castigliano (es)

**Convenzione adottata** : `e` neutro (convenzione argentina militante).

| Maschile | Femminile | Forma AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Regola** : si sostituisce la vocale di genere finale (`-o`/`-a`) con `-e` ; parole in
`-or` → radice + `-e` (`lector → lectore`).
**Plurale** : `-s` (`compañeres`).
**Articoli / determinanti** : `le` (singolare neutro), `les` (plurale neutro).
**Participi concordati** : `informade`, `conectade`, `active`.
**Parole già epicene** : invariate (`camarada`, `colega`, `responsable`,
`persona`).
**Proscritto** : `(a)`, `/a`, `/o`, **la forma tripla `(o/a/e)` del pt-BR**
(lo spagnolo usa SOLO la `e` neutro), `@` (arroba), `x` (Latinx), e il
**punto mediano `·`** (convenzione francese, da non usare in spagnolo).

### Italiano (it)

**Convenzione adottata — ufficiale** : **asterisco `*` per le coppie
regolari, slash abbreviato per le coppie irregolari.** Questa convenzione
sostituisce lo slash provvisorio della v1.

#### Coppie regolari (radice comune in `-o`/`-a`) → asterisco `*`

Quando il maschile e il femminile condividono la **stessa radice**, si sostituisce la
terminazione di genere con un asterisco, per coerenza con il Genderstern
tedesco.

| Maschile | Femminile | Forma AnarBib |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(già epiceno al sing.)* |

Si applica anche ai **participi e agli aggettivi concordati** : `stat*` (stato/a),
`ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a),
`benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*`
(questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Coppie irregolari (radici diverse, tipo `-tore`/`-trice`) → slash abbreviato

Quando il femminile non condivide la radice del maschile (`lettore` → `lettric-e`),
l'asterisco è **scorretto** (`lettor*` farebbe intendere un femminile inesistente
`lettora`). Si usa quindi la **forma slash abbreviata**, che è lo *house style*
attestato nel repository.

| Maschile | Femminile | Forma AnarBib |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Plurale irregolare** : `lettori/trici`, `amministratori/trici`,
`coordinatori/trici`.
**Articoli** : `il/la`, `del/la`, `al/la`, `dal/la` (forma abbreviata), `un*` per
`uno/una`.
**Parole già epicene** : invariate (`utente`, `responsabile`, `persona`,
`collega`).

#### Nota sul carattere `·`

Il punto mediano `·` **non** è un marcatore inclusivo in italiano : serve
unicamente come **separatore tipografico** nei soggetti delle mail e nelle righe
di metadati (`Email · ID · Genere`). Non usarlo mai per marcare il genere.

**🚫 Proscrizione assoluta** : **`camerata` / `camerati` / `cameratesco`** — appellativo
interno fascista (PNF, MSI, CasaPound, Forza Nuova, FdI). Usare `compagn*` e
le sue varianti. **Questa proscrizone è testata in CI** (`i18n.test.js` e
`mail-strings.test.ts`).
**Altre forme proscrite** : `(a)`/`(o)` parentesi, triplo `/trice/e`, suffisso
`/x`, punto mediano `·` come marcatore di genere.

**Giustificazione militante** : l'asterisco (*asterisco*) è attestato negli
ambienti anarchici e autonomi italofoni (Carmilla, DinamoPress, InfoAut,
Wu Ming), e offre coerenza visiva con il Genderstern tedesco. Lo slash
abbreviato per le coppie irregolari evita i femminili scorretti pur restando
leggibile.

### Catalano (ca)

**Convenzione adottata** : terminazione tripla suffisso `-a-e` + articolo neutro `le`.

| Maschile | Femminile | Forma AnarBib |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Variante tra parentesi** accettata per le contrazioni :
`lector(a/e)`, `coordinador(a/e)`.
**Determinante neutro** : `le` (`le lector-a-e`).
**Plurale** : `-s` o forma combinata `els-les-les` / `als-a les-a les`.
**Parole già epicene** : invariate.

> Il catalano usa anche il punt volat `·` nella **geminata `l·l`**
> (`col·lectiu`, `cancel·lada`, `sol·licitud`) : è una **grafia standard del
> catalano**, senza rapporto con l'inclusività. Non modificarla.

### Esperanto (eo)

**Convenzione adottata** : infisso `-in-` visibilizzato con trattini + pronome neutro
`ri`.

| Base | Forma AnarBib |
|---|---|
| leganto (lettore/trice) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Variante non-binaria** : suffisso `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Pronome neutro** : `ri`.
**Plurale** : `-j` (`legant-in-oj`).

### Olandese (nl)

**Stato : PROVVISORIO — da validare in comunità.**

**Orientamento provvisorio** : privilegiare le **forme di ruolo neutre**
esistenti piuttosto che una marcatura tipografica.

| Concetto | Forma provvisoria |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Regole provvisorie** : evitare i suffissi gendered `-ster`/`-e` quando esiste una forma
neutra ; pronome non-binario `die` (o `hen`/`hun`) — **uso non ancora definitivo**.

> ⚠️ Questa convenzione **non** è definitiva. Deve essere validata da
> persone parlanti olandesi militanti prima di essere cristallizzata. Nel frattempo,
> attenersi alle forme neutre.

### Greco (el)

**Stato : CONVENZIONE DA DEFINIRE.**

**Non esiste uno standard tipografico consensuale** per la scrittura
inclusiva in greco. **Non proporre alcun marcatore d'ufficio.** La convenzione sarà
definita **con una persona parlante greca militante** che si unirà al progetto.

**Approccio transitorio** (in attesa) : doppietti o forme neutre esistenti
(`αναγνώστης/στρια`, `συντονιστής/στρια`), greco monotonico, 2ᵃ persona
singolare per il tu al lettore/trice (vouvoiement per l'équipe). Sigla
GDPR → `ΓΚΠΔ`.

> ⚠️ Qualsiasi proposta di marcatore tipografico inclusivo sistematico per il
> greco è **prematura** finché nessun/a relais ellenofono/a militant* si è unit* al
> progetto.

---

## Termini politici di riferimento

### Camarade / Compagn*

| Lingua | Forma ufficiale | Plurale |
|---|---|---|
| 🇫🇷 fr | `camarade` *(epiceno)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(epiceno)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(epiceno)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagn*` | `compagn*` |
| ca | `camarada` *(epiceno)* | `camarades` |
| eo | `kamarad-in-o` | `kamarad-in-oj` |
| nl | `kameraad` *(provvisorio)* | `kameraden` |
| el | `σύντροφος` *(da confermare)* | — |

### Lettore/trice

| Lingua | Forma ufficiale |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/trice` |
| ca | `lector-a-e` |
| eo | `legant-in-o` |
| nl | `lezer` *(provvisorio)* |
| el | `αναγνώστης/στρια` *(transitorio)* |

### Bibliotecari*

| Lingua | Forma ufficiale |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(epiceno)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecari*` |
| ca | `bibliotecari-ària-e` |
| eo | `bibliotekist-in-o` |
| nl | `bibliothecaris` *(provvisorio)* |
| el | `βιβλιοθηκάριος` *(da confermare)* |

### Amministratore/trice

| Lingua | Forma ufficiale |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/trice` |
| ca | `administrador-a-e` |
| eo | `administrant-in-o` |
| nl | `beheerder` *(provvisorio)* |
| el | *(da definire)* |

---

## Termini proscritti

### Politicamente marcati (proscrizone assoluta)

| Termine | Lingua | Motivo |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Appellativo interno fascista (PNF, MSI, CasaPound, Forza Nuova, FdI). **Testato in CI.** |
| `Compas` *(non tradotto)* | 🇩🇪 de | Neologismo ispanofono lasciato tale quale — usare `Genoss*in`/`Genoss*innen`. |

### Convenzioni tipografiche burocratiche o inadatte

| Forma | Lingue interessate | Perché |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Forma amministrativa, non militante. |
| `@` (arroba) | pt-BR, es | Obsoleta, problema di accessibilità (lettori di schermo). |
| `x` (Latinx) | es, pt-BR | Soppiantata da `e` neutro nell'uso militante contemporaneo. |
| `(e)`, `-e` separato | fr | Convenzione pre-2010, sostituita dal mediano. |
| `Genderdoppelpunkt` (`:innen`) | de | Valida ma non adottata per coerenza con `*`. |
| `he/she`, `s/he`, `(s)he` | en | Preferire `they/them` singolare. |
| Triplo `(o/a/e)` | es | Riservato al pt-BR ; lo spagnolo usa solo la `e` neutro. |
| Punto mediano `·` come marcatore di genere | es, it, ca | Convenzione francese ; altrove, `·` è solo un separatore (o la geminata `l·l` in ca). |
| Triplo `/trice/e`, suffisso `/x` | it | Forme malformate ; usare slash abbreviato `/trice`. |

---

## Procedura per le aggiunte future

### Quando si aggiunge una nuova chiave i18n

1. **Identificare** la parola/espressione da tradurre. Si tratta di un termine da
   declinare per genere ?
2. **Se sì, scegliere la forma epicena quando esiste** (`camarada` pt-BR,
   `responsable` fr, `utente` it…).
3. **In caso contrario, applicare la convenzione della lingua** definita qui sopra.
4. **Per l'italiano** : distinguere coppia regolare (asterisco) e coppia
   irregolare (slash abbreviato).
5. **Verificare la coerenza** con il resto del file.
6. **Compilare le 10 locali in un'unica passata.** Una chiave parzialmente
   tradotta è un bug. La **parità delle chiavi** tra le 10 locali è
   obbligatoria.

### Quando si rilegge una traduzione esistente

1. Individuare i marcatori **proscritti** (`(a)`, `@`, `camerata`, punto mediano fuori
   fr/ca-geminata, triplo `/trice/e`…).
2. Sostituirli con la forma ufficiale della lingua.
3. Verificare la coerenza singolare/plurale.
4. Verificare la coerenza inter-locali per la stessa chiave.

### Quando si chiede una traduzione a un'IA

Fornire sempre questa carta come contesto, precisare la convenzione attesa per
la lingua di destinazione e i termini proscritti, privilegiare le forme epicene e
**verificare il risultato** prima dell'integrazione.

---

## Copertura dei test (CI)

- `src/tests/i18n.test.js` testa la **parità delle chiavi** e la **conformità** di
  **8 locali** : `pt-BR, fr, en, de, it, es, ca, eo`. Include il test bloccante
  « l'italiano non deve mai contenere camerata/camerati ».
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) testa le
  stringhe mail : parità, termini proscritti (camerata), interpolazione, fallback.
- ⚠️ **`nl` e `el` NON sono coperti dal gate CI** : la loro parità di chiavi
  e la loro conformità non sono garantite automaticamente. **Backlog** : aggiungerle a
  `i18n.test.js` una volta definite le rispettive convenzioni.

---

## Evoluzione della carta

Questa carta è un documento vivente. Può essere modificata secondo i seguenti principi :

- **Aggiunta di termini politici di riferimento** : per decisione collettiva
  documentata nel repository (issue o pull request).
- **Cambio di convenzione di una lingua** : richiede la partecipazione di almeno
  una persona militante parlante nativa della lingua interessata. Il
  cambiamento deve essere motivato politicamente e tecnicamente.
- **Definizione delle convenzioni provvisorie (`nl`) o da definire (`el`)** : segue lo stesso
  protocollo — una scelta tipografica militante locale, giustificata, validata da
  relais nativi, poi reversata in questa carta e aggiunta al gate CI.
- **Aggiunta di una nuova lingua** : stesso protocollo.

---

*Carta v2 redatta il 2026-06-05 a seguito dell'audit del linguaggio inclusivo delle
dieci locali e delle stringhe mail. Documento di riferimento da committare in
`notes-audit/` del repository. Sostituisce la v1.0 del 2026-04-28.*
