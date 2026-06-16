# Cotació BLMF — norma de tombo + graella CDD anarquista

> Document de treball de catalogatge. Font CDD: sumaris Dewey públics
> (10 classes / 100 divisions), adaptats als prestatges reals de la col·lecció.

## 1. Norma de tombo (número d'inventari)

**Format: `CCLA.{ANY}.{N}`**

- **ANY** = any de catalogatge (millesime).
- **N** = comptador d'adquisició, **reinicialitzat cada any**, **únic per
  exemplar físic** (dos exemplars d'un mateix títol = dos N distints).
- **Majúscules**: `CCLA` en majúscules. Separador: punt. Sense zeros de
  farciment, sense sufix de còpia (`-01`, `-02`).

**Regla per a bibliotecari-ària-e debutant:**
> «Nou llibre catalogat en {any} → agafo el N més gran existent
> per a `CCLA.{any}.*`, i afegeixo 1.»

**Estat al 2026-06-07 (després de la unificació dels 246 exemplars BLMF):**

| Millesime | Rang utilitzat | Proper N lliure |
|---|---|---|
| 2023 | 1 → 222 (legacy) | (tancat) |
| 2024 | 1 → 53 (legacy) | (tancat) |
| **2026** | 1 → 76 | **77** |

→ La represa del catalogatge 2026 continua doncs a `CCLA.2026.77`.

*Nota històrica: el 2023, N seguia sovint el número de referència bibliogràfica;
el 2024/2026, N és un comptador d'adquisició. Com que els millesimes són distints,
cap col·lisió és possible. Només el millesime corrent segueix la regla «max+1».*

## 2. Graella CDD dirigida (prestatges anarquistes)

La cota anarquista de referència en Dewey és **335.83 (Anarquismo)**. La majoria
de les obres de teoria hi van; la resta es distribueix per **tema** (educació,
treball, terra, història d'una revolució determinada, biografia).

### Nucli polític — 300

| CDD | Intitulat (pt-BR) | Per a què / exemples |
|---|---|---|
| 303.6 | Conflito social, revolução | teoria de la revolució, violència/no-violència |
| 305.42 | Mulheres, feminismo | «Mulher, Vida, Liberdade», feminisme llibertari |
| 305.5 / 305.8 | Classes sociais / grupos étnicos | classe, raça |
| 320.5 | Ideologias políticas | panorames d'ideologies |
| 321.07 | Anarquia (ausência de governo) | teoria de l'Estat/no-Estat (variant de 335.83) |
| 322.42 | Movimentos revolucionários | moviments, organitzacions de lluita |
| 323.044 | Ação direta, desobediência civil | acció directa, resistència |
| 324.2 | Partidos / eleições | «Os Anarquistas e as Eleições» |
| 331.88 | Sindicalismo, sindicatos | sindicalisme, «imprensa operária» |
| 333.3 | Posse da terra | MST, lluita per la terra, agrari |
| 334 | Cooperativas, autogestão | «Autogestão», cooperativisme |
| **335.83** | **Anarquismo** | **teoria anarquista (cota per defecte)** |
| 335.4 | Marxismo | marxisme, comparacions |
| 355 | Ciência militar, militarismo | «Militarismo na América latina» |
| 365 | Prisões | presó, abolició |
| 370.1 / 371.04 | Filosofia da educação / escolas alternativas | Escola Moderna, Ferrer, «Educar para emancipar» |

### Altres classes útils

| CDD | Intitulat | Per a què / exemples |
|---|---|---|
| 070.4 | Imprensa, jornalismo | «A imprensa libertária do Ceará» |
| 170 / 171 | Ética | ètica, anarquisme moral |
| 211 | Ateísmo, agnosticismo | «Deus e o Estado» (anticlericalisme) |
| 335.83 ↔ 304.5 | (Kropotkin) | «Apoio mútuo»: segons l'angle, 335.83 (social) |
| 741.5 / 760 | HQ / gravura | fanzines il·lustrats, gravat militant |
| 791.43 | Cinema | «Viva Zapata!» i films |
| 860 / 869 | Lit. hispano-am. / brasileira | novel·les, «Amor e anarquia» |
| 840 | Literatura francesa | «Tout pour tous», etc. |
| 920 (o B) | Biografia | Emma Goldman, Durruti, Bakunin |

### Història per regió — 900

| CDD | Regió | Exemples |
|---|---|---|
| 909 | História mundial | panorames |
| 944.081 | França (Comuna de París) | Comuna, moviment francès |
| 946.081 | Espanha (Guerra Civil) | Durruti, «Revolução e Guerra civil na Espanha» |
| 972.08 | México (Revolução) | Zapata, Flores Magón, «México insurgente» |
| 980 / 981 | América do Sul / Brasil | «História do Anarquismo no Brasil» |

### Heurística de decisió

1. **Teoria anarquista general** → `335.83`.
2. Tema dominant identificable → cota del tema (educació `370.1`,
   sindicalisme `331.88`, terra `333.3`, feminisme `305.42`…).
3. **Història** d'un esdeveniment/país → `9xx` regional.
4. **Biografia** d'un-a-e militant → `920`.
5. **Ficció/poesia** → `8xx` segons la llengua.
6. En cas de dubte entre teoria i tema: privilegiar `335.83` si l'obra
   és explícitament anarquista; sinó, el tema.
