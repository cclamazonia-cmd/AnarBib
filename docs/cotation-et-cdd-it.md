# Quotatura BLMF — norma di inventario + griglia CDD anarchica

> Documento di lavoro per la catalogazione. Fonte CDD : sommari Dewey pubblici
> (10 classi / 100 divisioni), adattati ai ripiani reali della collezione.

## 1. Norma di inventario (numero di tombo)

**Formato : `CCLA.{ANNO}.{N}`**

- **ANNO** = anno di catalogazione (millesimo).
- **N** = contatore di acquisizione, **azzerato ogni anno**, **univoco per
  esemplare fisico** (due esemplari dello stesso titolo = due N distinti).
- **Maiuscole** : `CCLA` in maiuscolo. Separatore : punto. Nessuno zero di
  riempimento, nessun suffisso di copia (`-01`, `-02`).

**Regola per bibliotecari* alle prime armi :**
> « Nuovo libro catalogato in {anno} → prendo il maggiore N esistente
> per `CCLA.{anno}.*`, e aggiungo 1. »

**Stato al 2026-06-07 (dopo l'unificazione dei 246 esemplari BLMF) :**

| Millesimo | Intervallo utilizzato | Prossimo N libero |
|---|---|---|
| 2023 | 1 → 222 (legacy) | (chiuso) |
| 2024 | 1 → 53 (legacy) | (chiuso) |
| **2026** | 1 → 76 | **77** |

→ La ripresa della catalogazione 2026 continua quindi da `CCLA.2026.77`.

*Nota storica : nel 2023, N seguiva spesso il numero di riferimento bibliot. ;
nel 2024/2026, N è un contatore di acquisizione. I millesimi essendo distinti,
nessuna collisione è possibile. Solo il millesimo corrente segue la regola « max+1 ».*

## 2. Griglia CDD mirata (ripiani anarchici)

La quota anarchica di riferimento in Dewey è **335.83 (Anarquismo)**. La maggior
parte delle opere di teoria vi vanno ; il resto si ripartisce per **tema** (educazione,
lavoro, terra, storia di una rivoluzione data, biografia).

### Nucleo politico — 300

| CDD | Titolo (pt-BR) | Per cosa / esempi |
|---|---|---|
| 303.6 | Conflito social, revolução | teoria della rivoluzione, violenza/non-violenza |
| 305.42 | Mulheres, feminismo | « Mulher, Vida, Liberdade », femminismo libertario |
| 305.5 / 305.8 | Classes sociais / grupos étnicos | classe, razza |
| 320.5 | Ideologias políticas | panoramiche d'ideologie |
| 321.07 | Anarquia (ausência de governo) | teoria dello Stato/non-Stato (variante di 335.83) |
| 322.42 | Movimentos revolucionários | movimenti, organizzazioni di lotta |
| 323.044 | Ação direta, desobediência civil | azione diretta, resistenza |
| 324.2 | Partidos / eleições | « Os Anarquistas e as Eleições » |
| 331.88 | Sindicalismo, sindicatos | sindacalismo, « imprensa operária » |
| 333.3 | Posse da terra | MST, lotta per la terra, agrario |
| 334 | Cooperativas, autogestão | « Autogestão », cooperativismo |
| **335.83** | **Anarquismo** | **teoria anarchica (quota predefinita)** |
| 335.4 | Marxismo | marxismo, confronti |
| 355 | Ciência militar, militarismo | « Militarismo na América latina » |
| 365 | Prisões | carcere, abolizione |
| 370.1 / 371.04 | Filosofia da educação / escolas alternativas | Scuola Moderna, Ferrer, « Educar para emancipar » |

### Altre classi utili

| CDD | Titolo | Per cosa / esempi |
|---|---|---|
| 070.4 | Imprensa, jornalismo | « A imprensa libertária do Ceará » |
| 170 / 171 | Ética | etica, anarchismo morale |
| 211 | Ateísmo, agnosticismo | « Deus e o Estado » (anticlericalismo) |
| 335.83 ↔ 304.5 | (Kropotkin) | « Apoio mútuo » : secondo l'angolazione, 335.83 (sociale) |
| 741.5 / 760 | HQ / gravura | fanzine illustrati, incisione militante |
| 791.43 | Cinema | « Viva Zapata! » e film |
| 860 / 869 | Lit. hispano-am. / brasileira | romanzi, « Amor e anarquia » |
| 840 | Literatura francesa | « Tout pour tous », ecc. |
| 920 (o B) | Biografia | Emma Goldman, Durruti, Bakunin |

### Storia per regione — 900

| CDD | Regione | Esempi |
|---|---|---|
| 909 | História mundial | panoramiche |
| 944.081 | França (Comuna de Paris) | Comune, movimento francese |
| 946.081 | Espanha (Guerra Civil) | Durruti, « Revolução e Guerra civil na Espanha » |
| 972.08 | México (Revolução) | Zapata, Flores Magón, « México insurgente » |
| 980 / 981 | América do Sul / Brasil | « História do Anarquismo no Brasil » |

### Euristica di decisione

1. **Teoria anarchica generale** → `335.83`.
2. Tema dominante identificabile → quota del tema (educazione `370.1`,
   sindacalismo `331.88`, terra `333.3`, femminismo `305.42`…).
3. **Storia** di un evento/paese → `9xx` regionale.
4. **Biografia** di un* militant* → `920`.
5. **Narrativa/poesia** → `8xx` secondo la lingua.
6. In caso di dubbio tra teoria e tema : privilegiare `335.83` se l'opera
   è esplicitamente anarchica ; altrimenti il tema.
