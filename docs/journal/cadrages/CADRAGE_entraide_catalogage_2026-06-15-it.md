# Quadro — Mutuo appoggio alla catalogazione (scheda « Mutuo appoggio » della Federazione)

**Data** : 2026-06-15
**Stato** : **quadro / progetto** — riflessione esplorativa che pone la *visione*,
l'*architettura* e le *decisioni di principio*. **Non è ancora una spec da costruire** :
da discutere, mettere alla prova, poi declinare in spec.
**Fondamento etico** : [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
(« la mano tesa »). **Ogni schermata qui sotto è stata passata alla griglia « tende o afferra ? ».**
Questo quadro è, in un certo senso, la prima messa alla prova concreta della carta.

---

## 1. Il bisogno

La catalogazione è il punto dolente delle biblioteche alle prime armi (cfr. i cantieri
autorità, indicizzazione per soggetto, wizard di scoperta). Una biblioteca sola di fronte alle
autorità, ai soggetti, alla classificazione, si sente intimidita. La scheda « Mutuo appoggio »
risponde a questo bisogno preciso — ma la catalogazione anarchica non è neutra : i
descrittori mainstream patologizzano, cancellano, denominano male. **Il mutuo appoggio
trasmette un *artigianato politico* che né gli standard né un'IA riescono a codificare.**

Principio trasversale : **la richiesta d'aiuto è generica** (mutuo appoggio su *qualsiasi* questione
tecnica spinosa), la **catalogazione è il primo dominio cablato**.

## 2. Tre gradi di mutuo appoggio — una scala, per sussidiarietà

Non « l'uno O l'altro » ma tre *intensità* ; la richiesta d'aiuto è il perno, la
risposta prende una delle tre forme, dalla più leggera alla più impegnativa :

1. **Il bene comune del sapere** (vademecum, casi, thesaurus) — zero costo, zero dipendenza,
   100 % tra pari. La base duratura.
2. **Mini-wizard** — guidano la biblioteca affinché faccia *da sé* (autonomizzante,
   non dipendente).
3. **Aiuto umano diretto** (richiesta → risposta → eventuale videochiamata) — il più
   relazionale, per quando il bene comune e il wizard non bastano.

**Il ciclo discendente** : un caso difficile risolto al grado 3 → riassunto → diventa un caso/wizard
del grado 1-2 → la prossima volta il wizard basta. *Il sapere scende i gradi col
tempo ; la rete diventa più intelligente e più autosufficiente a ogni episodio.*

## 3. Il bene comune del sapere — il livello dell'autonomia

Tre livelli, e il più profondo è **il vocabolario stesso** :

- **Il thesaurus, cuore politico.** Non una lista di parole : un *grafo di concetti*. La
  politica vi vive nei **termini**, nelle **relazioni** (broader/narrower/related) e nelle
  **note di applicazione** (che sono micro-vademecum). Costruire su **SKOS** (standard
  libero) — trasmettere una norma, non un bricolage. Esiste già un seme (thesaurus ~30 categorie).
- **Casi & vademecum** — esempi lavorati, modificabili, che emergono *nel punto di bisogno*.
- **Wizard in *dati*, non in *codice*** — *la scommessa dell'autonomia* : se un wizard è del
  codice, dipendiamo per sempre dagli sviluppatori/trici ; se è un **documento strutturato** (albero di
  schede-domande → schede-fine) che un motore scritto-una-volta esegue, **qualsiasi biblioteca ne
  scrive uno senza programmare**. Protezioni affinché non diventi un linguaggio di programmazione
  mascherato : nessuna variabile/calcolo/condizione libera ; unico stato = il percorso percorso ;
  condizioni eventuali da una lista chiusa ; **il wizard *consiglia*, non *scrive* mai** (il
  peggiore dei fallimenti = « non utile », mai « ho rotto il catalogo ») ; wizard piccoli e
  mono-argomento.

**Multilingue senza IA** : la struttura i18n (10 locali) porta l'interfaccia ; la *sostanza*
(termini, casi) si scrive **per comunità di lingua** (scrittura parallela cross-collegata, non
traduzione discendente) — lento ma duraturo e gratuito. **Governance** : aggiunta/modifica di
termine tramite il flusso **consenso/obiezione** dei cerchi ; cursore politico « varianti
ammesse vs convergenza » da collocare dalla rete.

## 4. L'attivazione — nel punto di bisogno (carta ③)

**L'attivatore è il *campo*, il *dato*, o la *richiesta* — mai la sorveglianza
della persona.** Vietare i segnali comportamentali (« 5 min sul campo », esitazioni) :
è Clippy *e* sorveglianza del lavoro. Tre attivatori onesti :
- **intrinseco al campo** (soggetti/autorità sono difficili *per tutt** → aiuto sempre presente) ;
- **derivato dal dato** (nessun ISBN, autore/trice ambiguo → è il libro a segnalarlo, non la persona) ;
- **richiesta esplicita** (« aiuto » calmo, sempre a portata).

L'aiuto sale **la scala un-clic-più-in-là** (inline → wizard → cerchio), **discreto ma
individuabile** (posizionamento affidabile, mai modale/gamificato), con una **presenza in curva per
dominio** (un po' più proattivo se campo vuoto + basso numero di schede ; si riduce con la
padronanza ; sempre piegabile a mano).

## 5. Due schermate già passate alla griglia

### 5.1 — Il « ? » sotto un campo difficile (catalogazione)
Presente *perché il campo è difficile per tutt** (inquadramento di dignità, non « sembri in
difficoltà »). Aprendolo : suggerimenti thesaurus inline + casi del bene comune → « percorso
guidato » (wizard) → « chiedere al cerchio » (grado 3, momento del consenso).
**La griglia ha eliminato due funzionalità allettanti** : ❌ rilevare l'esitazione per proporre
l'aiuto (sorveglianza, faccia ③) ; ❌ badge/serie/barra verso « espert* » (faccia ⑥).
**Predefiniti mantenuti** : rete « prima volta ? percorso guidato » *offerto ma in registro
d'offerta* ; « ? » sempre visibile, suggerimenti **dispiegati al clic** (discreto + individuabile).

### 5.2 — La chiusura dell'episodio + cattura del bene comune
Fine **avviata dall'aiutat*** (nessuna auto-chiusura, nessuna chiusura da parte dell'aiutant*). Schermata
« grazie » sobria, **nulla di agganciato** (disaccoppiamento anti-debito). **Barra-piuma** « mantenere
il contatto ? » simmetrica, ignorabile, non crea nulla se non doppio-sì.
**Cattura del bene comune senza debito** : si invita l'**aiutant*** (detiene il sapere nuovo), non
l'aiutat* ; **micro-contribuzione agganciata all'oggetto** (nota su un termine/campo), **avviata
dalla traccia** dell'episodio ; poi l'**aiutat* è invitatat* a rileggere/arricchire** (« ciò che era
davvero difficile ») — *la sua voce, declinabile, mai un giudizio dell'aiutant**, e **non
bloccante** (la nota regge da sola).
**La griglia ha eliminato** : ❌ « valuta la tua esperienza » (classificazione mascherata) ; ❌ badge di completamento.

## 6. Riservatezza

Il dato di catalogo è *meno* sensibile del dato lettore/trice (metadati su *libri*,
mai esemplari/prestiti/identità), **ma non zero** (i fondi di una biblioteca anar possono
essere politicamente sensibili ; cfr. la distinzione `visibility_level='network'` /
BTL). Quindi :
- **opt-in per elemento** (mai un dump), **BTL/sensibili esclusi per default** ;
- **l'aiutant* *propone*, la proprietaria *valida*** — mai scrittura diretta da parte di un terzo ;
  accesso **circoscritto, revocabile, verificabile** ;
- il livello **« chiedere al cerchio » È il momento del consenso** (« mostreremo questi
  elementi alla biblioteca X — ecco cosa uscirà ») ;
- **il bene comune cattura artigianato *generico de-identificato*, non *casi* identificanti** ;
  le specificità vengono eliminate o consentite.

Risposta alla domanda « diritto assoluto di delegare ? » : **sì all'autonomia, ma consenso
*informato e inquadrato*, non una delega in bianco** — rendere il rischio piccolo e farlo assumere
in piena consapevolezza.

## 7. Abbinamento & maturazione in partenariato

- **Smistamento morbido, non filtro duro.** In una rete sparsa, un AND (stessa lingua E geo E disp E
  espert*) = insieme vuoto. Si **classifica** per affinità (lingua ↑, fuso orario ↑, volontari* ↑) senza
  **escludere** ; sussidiarietà **cerchio prima → rete se silenzio**. Il **cerchio pertinente
  dipende dal tipo di aiuto** (catalogazione → linguistico ; materiale/repressione → geografico).
- **Primo gesto senza prerequisiti** : offrirsi volontari* per *un* atto non richiede alcun cerchio
  né profilo. **L'appartenenza si accumula dai gesti** (riconoscimento consensuale, mai etichetta).
- **Anti-gerarchia** : nessuna reputazione individuale, nessuna marketplace ; disponibilità
  dichiarata, reciprocità visibile senza punteggio, rotazione.
- **Maturazione in partenariato (§21)** — *seconda fase che dissolve la scarsità* : un buon episodio
  può **maturare** in partenariato → l'aiuto futuro è *pre-abbinato* (lingua, fuso orario, consenso
  già dato) ; la rete si **densifica**. **Disaccoppiato** dall'episodio (mai nell'istante =
  debito) ; **dopo ripetizione** (riconoscimento, non creazione) ; **doppio-opt-in simmetrico** ;
  **scala di profondità** (0 → mantenere-contatto → compagnonnage → partenariato formale) ;
  **inversione del debito** (il partenariato è un *dono* all'aiutat* : « un* compagn* da
  richiamare senza ri-consentire », non un dovuto) ; sempre **scioglibile**.

## 8. Il modulo visio (grado 3)

Collegare l'aiuto umano a una **videochiamata Jitsi** (sincrona = trasmissione efficace) ; vivaio =
**cerchio linguistico**. **Asincrono prima, visio come turbo opzionale** (la più precaria è mal
connessa → gradi 0-2 in testo/offline).
Tecnicamente, « gratuitamente » : **codificare l'integrazione una volta tramite l'iframe API con il `domain`
in config** → mai vincolat* a un solo fornitore. Puntare per default verso un'**istanza Jitsi
militante** (il massimo nella dottrina, gratuita, nessun GAFAM) ; in mancanza `meet.jit.si` (assumendo
l'auth del creatore della stanza). Stanze **effimere, nome non-indovinabile, lobby**. **Zero
server, zero segreto, zero costo ricorrente.** L'auto-ospitato resta *parcheggio* (VPS escluso).

## 9. Costo & autonomia

Tutto (bene comune, wizard, pannelli, matching, visio link-out) **gira sullo stack esistente**
(Supabase + front statico) : **zero costo marginale, senza IA per funzionare**. L'IA resta un
**acceleratore opzionale e disconnettibile** (pre-catalogazione del *neutro* unicamente ; il politico
resta tra compagn*). **Gli organi esistono già** : seme di thesaurus, wizard di
scoperta, i18n 10 locali, flusso consenso/obiezione dei cerchi, §21 partenariato. **Questo
quadro collega organi esistenti — da qui la sua modestia, e la sua indipendenza rispetto ai costi
e a qualsiasi dipendenza esterna.**

## 10. Decisioni prese / questioni aperte

**Prese (nel corso della riflessione) :**
- Tre gradi in scala + ciclo discendente del sapere.
- Bene comune = thesaurus (SKOS, cuore politico) + casi + **wizard in dati**.
- Attivazione per campo/dato/richiesta, **mai sorveglianza** ; scala un-clic ;
  presenza in curva per dominio.
- Schermata « ? » : predefiniti (offerta, suggerimenti al clic) ; rifiuti (rilevazione-esitazione, gamification).
- Chiusura : aiutat* chiude ; **aiutant* redige → aiutat* arricchisce** (zero debito) ; bene comune = **artigianato
  generico** ; governance **additivo = 2 persone / vocabolario = collettivo**.
- Matching **smistamento morbido + cerchio prima** ; cerchio **secondo il tipo di aiuto** ; primo gesto senza
  prerequisiti ; **appartenenza per il gesto**.
- Maturazione §21 **disaccoppiata, dopo ripetizione, doppio-opt-in, scala di profondità, inversione
  di debito, scioglibile**.
- Visio **Jitsi `domain` configurabile**, async-first, zero infra/segreto.
- (Richiamo mail, già cablato fuori da questo quadro) locale del destinatario = **sua preferenza personale**.

**Aperte (cursori politici da collocare dalla rete) :**
- **Livello di accoglienza iniziale** (ospitalità) e **chi la pone** : rete / cerchio / biblioteca /
  persona. Pista : *chiedere* alla nuov* arrivatata la sua accoglienza (consenso) + sussidiarietà
  (il livello superiore colma solo il silenzio) + opzione *tutoraggio incarnato* da part* di un* volontari* del cerchio.
- Livello di **presenza della barra-piuma** e dell'invito al bene comune (offerto vs disponibile) —
  ampiamente disinnescato dalla **semantica** (registro d'offerta ≠ ingiunzione).
- Forma concreta dell'**editor di wizard-in-dati** (fino a dove senza diventare codice).
- Cursore **varianti vs convergenza** del thesaurus.

## 11. Stato

Quadro da **discutere e mettere alla prova**, non un ordine di costruzione. Quando un volet sarà maturo,
si declinerà in spec, e ogni schermata tornerà alla **griglia della carta relazionale**.
