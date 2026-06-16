# Cotización BLMF — norma de tombo + grilla CDD anarquista

> Documento de trabajo de catalogado. Fuente CDD: sumarios Dewey públicos
> (10 clases / 100 divisiones), adaptados a los estantes reales de la colección.

## 1. Norma de tombo (número de inventario)

**Formato: `CCLA.{AÑO}.{N}`**

- **AÑO** = año de catalogado (cosecha).
- **N** = contador de adquisición, **reiniciado cada año**, **único por
  ejemplar físico** (dos ejemplares de un mismo título = dos N distintos).
- **Mayúsculas**: `CCLA` en mayúsculas. Separador: punto. Sin ceros de
  relleno, sin sufijo de copia (`-01`, `-02`).

**Regla para bibliotecaries principiantes:**
> «Nuevo libro catalogado en {año} → tomo el mayor N existente
> para `CCLA.{año}.*`, y sumo 1.»

**Estado al 2026-06-07 (tras la unificación de los 246 ejemplares BLMF):**

| Cosecha | Rango utilizado | Próximo N libre |
|---|---|---|
| 2023 | 1 → 222 (legacy) | (cerrado) |
| 2024 | 1 → 53 (legacy) | (cerrado) |
| **2026** | 1 → 76 | **77** |

→ La reanudación del catalogado en 2026 continúa a partir de `CCLA.2026.77`.

*Nota histórica: en 2023, N seguía a menudo el número de referencia de la biblioteca;
en 2024/2026, N es un contador de adquisición. Al ser distintas las cosechas,
no es posible ninguna colisión. Solo la cosecha actual sigue la regla «max+1».*

## 2. Grilla CDD focalizada (estantes anarquistas)

La cota anarquista de referencia en Dewey es **335.83 (Anarquismo)**. La mayor
parte de las obras de teoría van ahí; el resto se distribuye por **tema** (educación,
trabajo, tierra, historia de una revolución determinada, biografía).

### Núcleo político — 300

| CDD | Intitulado (pt-BR) | Para qué / ejemplos |
|---|---|---|
| 303.6 | Conflito social, revolução | teoría de la revolución, violencia/no-violencia |
| 305.42 | Mulheres, feminismo | «Mulher, Vida, Liberdade», feminismo libertario |
| 305.5 / 305.8 | Classes sociais / grupos étnicos | clase, raza |
| 320.5 | Ideologias políticas | panoramas de ideologías |
| 321.07 | Anarquia (ausência de governo) | teoría del Estado/no-Estado (variante de 335.83) |
| 322.42 | Movimentos revolucionários | movimientos, organizaciones de lucha |
| 323.044 | Ação direta, desobediência civil | acción directa, resistencia |
| 324.2 | Partidos / eleições | «Os Anarquistas e as Eleições» |
| 331.88 | Sindicalismo, sindicatos | sindicalismo, «imprensa operária» |
| 333.3 | Posse da terra | MST, lucha por la tierra, agrario |
| 334 | Cooperativas, autogestão | «Autogestão», cooperativismo |
| **335.83** | **Anarquismo** | **teoría anarquista (cota por defecto)** |
| 335.4 | Marxismo | marxismo, comparaciones |
| 355 | Ciência militar, militarismo | «Militarismo na América latina» |
| 365 | Prisões | prisión, abolición |
| 370.1 / 371.04 | Filosofia da educação / escolas alternativas | Escola Moderna, Ferrer, «Educar para emancipar» |

### Otras clases útiles

| CDD | Intitulado | Para qué / ejemplos |
|---|---|---|
| 070.4 | Imprensa, jornalismo | «A imprensa libertária do Ceará» |
| 170 / 171 | Ética | ética, anarquismo moral |
| 211 | Ateísmo, agnosticismo | «Deus e o Estado» (anticlericalismo) |
| 335.83 ↔ 304.5 | (Kropotkin) | «Apoio mútuo»: según el ángulo, 335.83 (social) |
| 741.5 / 760 | HQ / gravura | fanzines ilustrados, grabado militante |
| 791.43 | Cinema | «Viva Zapata!» y películas |
| 860 / 869 | Lit. hispano-am. / brasileira | novelas, «Amor e anarquia» |
| 840 | Literatura francesa | «Tout pour tous», etc. |
| 920 (o B) | Biografia | Emma Goldman, Durruti, Bakunin |

### Historia por región — 900

| CDD | Región | Ejemplos |
|---|---|---|
| 909 | História mundial | panoramas |
| 944.081 | França (Comuna de Paris) | Comuna, movimiento francés |
| 946.081 | Espanha (Guerra Civil) | Durruti, «Revolução e Guerra civil na Espanha» |
| 972.08 | México (Revolução) | Zapata, Flores Magón, «México insurgente» |
| 980 / 981 | América do Sul / Brasil | «História do Anarquismo no Brasil» |

### Heurística de decisión

1. **Teoría anarquista general** → `335.83`.
2. Tema dominante identificable → cota del tema (educación `370.1`,
   sindicalismo `331.88`, tierra `333.3`, feminismo `305.42`…).
3. **Historia** de un acontecimiento/país → `9xx` regional.
4. **Biografía** de une militante → `920`.
5. **Ficción/poesía** → `8xx` según la lengua.
6. En caso de duda entre teoría y tema: privilegiar `335.83` si la obra
   es explícitamente anarquista; si no, el tema.
