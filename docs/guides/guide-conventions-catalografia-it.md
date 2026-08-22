# Scheda — Scrivere un nome, scrivere un titolo

> **Traduzione da rivedere.** Questa versione è stata tradotta dal francese
> perché esistesse subito e non fra sei mesi. Se leggi questa lingua meglio di
> come la scrive la traduzione, correggila: è un bene comune, non un testo
> chiuso.

> **A chi si rivolge questa scheda.** A te che cataloghi. Raccoglie ciò che si
> decide al momento di digitare: come si scrive un nome, dove tagliare una
> particella, cosa fare di un ente collettivo, e perché un campo vuoto vale più
> di un campo indovinato.
>
> Il *perché* dettagliato sta altrove, nel registro delle decisioni, sezione
> `CONV`. Qui si cataloga.

## La regola, in una frase

**Una sola verità nella base, più rese.** Tu digiti la forma di catalogazione;
le maiuscole, l'ordine nome-cognome e le formattazioni bibliografiche sono
**calcolate** in visualizzazione e in esportazione. Non digitarle mai a mano.

Da lì viene tutto il disordine che stiamo riparando: il punto di accesso, la
forma di visualizzazione e la forma di esportazione sono stati alloggiati
**nello stesso campo**, in momenti diversi, da mani diverse.

---

## 1. Il nome di una persona

### La forma di ordinamento fa fede

Il campo **«Forma di ordinamento»** è la verità. La **«Forma standard»** ne
deriva automaticamente, per semplice inversione della virgola. Mai il
contrario.

| Scrivi in «Forma di ordinamento» | L'app mostra |
|---|---|
| `Kropotkin, Pëtr` | Pëtr Kropotkin |
| `Malatesta, Errico` | Errico Malatesta |

### Grafia naturale, mai in maiuscolo

**`Kropotkin, Pëtr` — mai `KROPOTKIN, Pëtr`.**

Le maiuscole del cognome sono una **norma di citazione bibliografica** (ABNT),
non un dato. Vengono aggiunte in esportazione, al volo. Digitarle tu non le
rende più vere: distrugge l'informazione di grafia, che poi non si
ricostituisce — `de Sousa` e `De Sousa` non sono più distinguibili una volta
tutto in maiuscolo.

### Dove tagliare: la particella

**Decide la lingua del NOME, non il paese di nascita.** Una persona argentina
può portare un nome italiano.

| Lingua del nome | La particella… | Esempio |
|---|---|---|
| portoghese, francese | **va in coda**, dopo il nome di battesimo | `Sousa, Manuel Joaquim de`<br>`Beauvoir, Simone de`<br>`Jong, Rudolf de` |
| italiano moderno, afrikaans, neerlandese | **resta davanti** | `Di Filippo, Luis`<br>`De Amicis, Edmondo`<br>`Van der Walt, Lucien` |

Luis Di Filippo è il caso da manuale: argentino, nome italiano, dunque
`Di Filippo, Luis` — e non `Filippo, Luis Di`.

> **In italiano moderno** la particella resta parte del cognome:
> `De Amicis, Edmondo`, `Di Vittorio, Giuseppe`. È l'italiano antico a
> comportarsi diversamente — nel dubbio, la forma moderna.

### Ciò che lo strumento non sa decidere

**Cognome doppio o nome composto?** `García Lorca` è un cognome doppio spagnolo
(non si taglia); `Jean-Marie` è un nome composto. Nessuna funzione distingue le
due cose. Nel dubbio, **chiedi** invece di decidere: è esattamente questo tipo
di caso che finisce nella lista di verifica.

---

## 2. Un ente collettivo non è una persona

**Un nome di collettivo non ha forma invertita.**

| ✅ | ❌ |
|---|---|
| `Grupo Krisis` | `Krisis, Grupo` |
| `Instituto de Estudos Libertários` | `Libertários, Instituto de Estudos` |
| `CIRA Marseille` | `Marseille, CIRA` |

### Compila «Tipo di autorità»

Il campo esiste e **guida la regola**. Impostato su *Ente collettivo*,
impedisce l'inversione. Lasciato vuoto, nulla protegge la scheda: sarà trattata
come una persona al primo passaggio di uno strumento.

Tre secondi di compilazione che evitano tre mesi di correzione.

### Se la scheda contiene PIÙ persone

Capita — l'importazione ne ha fabbricate. `KAISER, William Young and David E.`
non è un Kaiser con due nomi: sono **William Young** *e* **David E. Kaiser**,
due autori dello stesso libro.

**Non ripararlo sul posto.** Una scheda di autorità è condivisa da tutta la
rete: rinominarla non fa che spostare l'errore. Passa dall'Officina delle
autorità, proposta di tipo **Scissione**: la scheda d'origine è conservata, le
altre sono create, e i legami con i libri le seguono. Termine di
deliberazione: quattordici giorni, come per una fusione.

---

## 3. Il titolo

### La grafia dipende dalla lingua del titolo

**Non** c'è regola universale. Il tedesco scrive maiuscoli i sostantivi: è la
sua **ortografia**, non un errore di battitura.

Lo strumento di normalizzazione abbassa solo le **parole funzionali della
lingua del titolo**, in posizione non iniziale. Preserva:

- la **prima parola**;
- le parole dopo **punteggiatura forte** (`.` `:` `;` `?` `!` e il trattino di
  sottotitolo);
- le **sigle**.

**Toglie un artefatto d'importazione, non «riscrive» il titolo.** Quando ti
propone una correzione, resti tu a giudicare se una parola è un nome proprio —
lo strumento non lo sa.

| Prima | Dopo |
|---|---|
| `Antologia Do Movimento Operário Gaúcho` | `Antologia do Movimento Operário Gaúcho` |
| `Der Einzige Und Sein Eigentum` | `Der Einzige und sein Eigentum` |

### L'articolo iniziale: non mutilare mai il titolo

`I Lavoratori` si scrive **`I Lavoratori`**. Non `Lavoratori, I` — è un residuo
della scheda di cartone — e non `Lavoratori` da solo.

L'ordinamento si risolve con un **contatore di caratteri non ordinanti** (qui:
2, per `I `), che lascia il titolo intatto.

---

## 4. La lingua e il paese

| Campo | Formato | Esempi |
|---|---|---|
| **Lingua** (del documento) | codice BCP-47 | `pt-BR`, `fr`, `es`, `de`, `it` |
| **Paese** (dell'autorità) | codice ISO 3166-1 α-2 | `BR`, `FR`, `ES`, `NL` |

Non `italiano`, non `Italia`, non `ita`. Il selettore dell'app ti dà il codice
giusto: usalo invece di digitare.

**Un vuoto resta vuoto.** Se non conosci la lingua, lascia in bianco. Una
lingua sconosciuta è un'informazione onesta; una lingua sbagliata guida poi la
grafia del titolo e la regola d'intestazione del nome — propaga l'errore invece
di contenerlo.

---

## 5. Le date

Due numeri interi e un **qualificatore**:

| Qualificatore | Quando |
|---|---|
| `exact` | la data è stabilita |
| `circa` | approssimativa («verso il 1876») |
| `uncertain` | le fonti divergono |
| `unknown` | non si sa |
| `living` | **la persona è viva** |

`living` non è un dettaglio di comodo: senza di esso, «ancora viva» e «data di
morte sconosciuta» si confondevano — il che equivaleva a far morire delle
persone nel catalogo.

Quando nascita e morte sono entrambe ignote, usa il **periodo di attività**
(«attivo 1900-1910»). E quando le fonti si contraddicono, scrivilo nella **nota
sulle date**: è riparazione storiografica, non riempimento.

---

## 6. Ciò che non tocca a te decidere da sola o solo

Il corpus delle autorità è **condiviso da tutta la rete**. Modificare una
scheda significa modificare il catalogo di più biblioteche.

| Gesto | Dove avviene |
|---|---|
| correggere un refuso su una scheda | direttamente |
| **fondere** due schede duplicate | Officina — proposta, 14 giorni |
| **scindere** una scheda che ne contiene due | Officina — proposta, 14 giorni |
| decidere una grafia o un cognome proposto dallo strumento | lista di verifica |

Nell'Officina una proposta resta aperta il tempo necessario perché le altre
biblioteche possano obiettare. Quel termine non è lentezza amministrativa: è
ciò che fa restare comune il corpus.

---

## In caso di dubbio

**Lascia vuoto invece di indovinare.**

Un campo vuoto pone una domanda — qualcuno la vedrà e risponderà. Un campo
sbagliato risponde a una domanda che nessuno ha posto, e sembra giusto. È
quello che ritroviamo tre mesi dopo, copiato in cinque cataloghi.
