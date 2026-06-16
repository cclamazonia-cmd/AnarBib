# Cotação BLMF — norma de tombo + grade CDD anarquista

> Documento de trabalho de catalogação. Fonte CDD: sumários Dewey públicos
> (10 classes / 100 divisões), adaptados às estantes reais da coleção.

## 1. Norma de tombo (número de inventário)

**Formato: `CCLA.{ANO}.{N}`**

- **ANO** = ano de catalogação (safra).
- **N** = contador de aquisição, **reiniciado a cada ano**, **único por
  exemplar físico** (dois exemplares de um mesmo título = dois N distintos).
- **Caixa**: `CCLA` em maiúsculas. Separador: ponto. Sem zeros de
  preenchimento, sem sufixo de cópia (`-01`, `-02`).

**Regra para bibliotecári(o/a/e) iniciante:**
> « Novo livro catalogado em {ano} → pego o maior N existente
> para `CCLA.{ano}.*`, e adiciono 1. »

**Estado em 2026-06-07 (após unificação dos 246 exemplares BLMF):**

| Safra | Faixa utilizada | Próximo N livre |
|---|---|---|
| 2023 | 1 → 222 (legacy) | (fechado) |
| 2024 | 1 → 53 (legacy) | (fechado) |
| **2026** | 1 → 76 | **77** |

→ A retomada da catalogação 2026 continua portanto em `CCLA.2026.77`.

*Nota histórica: em 2023, N seguia muitas vezes o número de referência da biblioteca;
em 2024/2026, N é um contador de aquisição. Como as safras são distintas,
nenhuma colisão é possível. Apenas a safra corrente segue a regra « max+1 ».*

## 2. Grade CDD direcionada (estantes anarquistas)

A cota anarquista de referência em Dewey é **335.83 (Anarquismo)**. A maioria
das obras de teoria vai para lá; o restante se distribui por **tema** (educação,
trabalho, terra, história de uma revolução específica, biografia).

### Núcleo político — 300

| CDD | Intitulado (pt-BR) | Para quê / exemplos |
|---|---|---|
| 303.6 | Conflito social, revolução | teoria da revolução, violência/não-violência |
| 305.42 | Mulheres, feminismo | « Mulher, Vida, Liberdade », feminismo libertário |
| 305.5 / 305.8 | Classes sociais / grupos étnicos | classe, raça |
| 320.5 | Ideologias políticas | panoramas de ideologias |
| 321.07 | Anarquia (ausência de governo) | teoria do Estado/não-Estado (variante de 335.83) |
| 322.42 | Movimentos revolucionários | movimentos, organizações de luta |
| 323.044 | Ação direta, desobediência civil | ação direta, resistência |
| 324.2 | Partidos / eleições | « Os Anarquistas e as Eleições » |
| 331.88 | Sindicalismo, sindicatos | sindicalismo, « imprensa operária » |
| 333.3 | Posse da terra | MST, luta pela terra, questão agrária |
| 334 | Cooperativas, autogestão | « Autogestão », cooperativismo |
| **335.83** | **Anarquismo** | **teoria anarquista (cota por padrão)** |
| 335.4 | Marxismo | marxismo, comparações |
| 355 | Ciência militar, militarismo | « Militarismo na América latina » |
| 365 | Prisões | prisão, abolição |
| 370.1 / 371.04 | Filosofia da educação / escolas alternativas | Escola Moderna, Ferrer, « Educar para emancipar » |

### Outras classes úteis

| CDD | Intitulado | Para quê / exemplos |
|---|---|---|
| 070.4 | Imprensa, jornalismo | « A imprensa libertária do Ceará » |
| 170 / 171 | Ética | ética, anarquismo moral |
| 211 | Ateísmo, agnosticismo | « Deus e o Estado » (anticlericalismo) |
| 335.83 ↔ 304.5 | (Kropotkin) | « Apoio mútuo »: segundo o ângulo, 335.83 (social) |
| 741.5 / 760 | HQ / gravura | fanzines ilustrados, gravura militante |
| 791.43 | Cinema | « Viva Zapata! » e filmes |
| 860 / 869 | Lit. hispano-am. / brasileira | romances, « Amor e anarquia » |
| 840 | Literatura francesa | « Tout pour tous », etc. |
| 920 (ou B) | Biografia | Emma Goldman, Durruti, Bakunin |

### História por região — 900

| CDD | Região | Exemplos |
|---|---|---|
| 909 | História mundial | panoramas |
| 944.081 | França (Comuna de Paris) | Comuna, movimento francês |
| 946.081 | Espanha (Guerra Civil) | Durruti, « Revolução e Guerra civil na Espanha » |
| 972.08 | México (Revolução) | Zapata, Flores Magón, « México insurgente » |
| 980 / 981 | América do Sul / Brasil | « História do Anarquismo no Brasil » |

### Heurística de decisão

1. **Teoria anarquista geral** → `335.83`.
2. Tema dominante identificável → cota do tema (educação `370.1`,
   sindicalismo `331.88`, terra `333.3`, feminismo `305.42`…).
3. **História** de um evento/país → `9xx` regional.
4. **Biografia** de um(a/e) militante → `920`.
5. **Ficção/poesia** → `8xx` segundo a língua.
6. Em caso de dúvida entre teoria e tema: privilegiar `335.83` se a obra
   for explicitamente anarquista; caso contrário, o tema.
