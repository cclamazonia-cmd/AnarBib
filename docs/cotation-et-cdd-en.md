# BLMF Classification — inventory number standard + anarchist DDC grid

> Working document for cataloguing. DDC source: public Dewey summaries
> (10 classes / 100 divisions), adapted to the actual shelves of the collection.

## 1. Inventory number standard (tombo)

**Format: `CCLA.{YEAR}.{N}`**

- **YEAR** = year of cataloguing (vintage).
- **N** = acquisition counter, **reset each year**, **unique per physical copy**
  (two copies of the same title = two distinct N values).
- **Case**: `CCLA` in uppercase. Separator: period. No padding zeros, no copy suffix
  (`-01`, `-02`).

**Rule for a new librarian:**
> "New book catalogued in {year} → take the highest existing N for
> `CCLA.{year}.*`, and add 1."

**Status as of 2026-06-07 (after unification of the 246 BLMF copies):**

| Vintage | Range used | Next free N |
|---|---|---|
| 2023 | 1 → 222 (legacy) | (closed) |
| 2024 | 1 → 53 (legacy) | (closed) |
| **2026** | 1 → 76 | **77** |

→ The 2026 cataloguing resumption therefore continues at `CCLA.2026.77`.

*Historical note: in 2023, N often followed the library reference number;
in 2024/2026, N is an acquisition counter. Since the vintages are distinct,
no collision is possible. Only the current vintage follows the "max+1" rule.*

## 2. Targeted DDC grid (anarchist shelves)

The anarchist reference classification in Dewey is **335.83 (Anarquismo)**. Most
works of theory go there; the rest is distributed by **theme** (education,
labour, land, history of a given revolution, biography).

### Political core — 300

| DDC | Heading (pt-BR) | For what / examples |
|---|---|---|
| 303.6 | Conflito social, revolução | theory of revolution, violence/non-violence |
| 305.42 | Mulheres, feminismo | "Mulher, Vida, Liberdade", libertarian feminism |
| 305.5 / 305.8 | Classes sociais / grupos étnicos | class, race |
| 320.5 | Ideologias políticas | overviews of ideologies |
| 321.07 | Anarquia (ausência de governo) | theory of the State/non-State (variant of 335.83) |
| 322.42 | Movimentos revolucionários | movements, struggle organisations |
| 323.044 | Ação direta, desobediência civil | direct action, resistance |
| 324.2 | Partidos / eleições | "Os Anarquistas e as Eleições" |
| 331.88 | Sindicalismo, sindicatos | syndicalism, "imprensa operária" |
| 333.3 | Posse da terra | MST, land struggle, agrarian |
| 334 | Cooperativas, autogestão | "Autogestão", cooperativism |
| **335.83** | **Anarquismo** | **anarchist theory (default classification)** |
| 335.4 | Marxismo | Marxism, comparisons |
| 355 | Ciência militar, militarismo | "Militarismo na América latina" |
| 365 | Prisões | prison, abolition |
| 370.1 / 371.04 | Filosofia da educação / escolas alternativas | Escola Moderna, Ferrer, "Educar para emancipar" |

### Other useful classes

| DDC | Heading | For what / examples |
|---|---|---|
| 070.4 | Imprensa, jornalismo | "A imprensa libertária do Ceará" |
| 170 / 171 | Ética | ethics, moral anarchism |
| 211 | Ateísmo, agnosticismo | "Deus e o Estado" (anticlericalism) |
| 335.83 ↔ 304.5 | (Kropotkin) | "Apoio mútuo": depending on angle, 335.83 (social) |
| 741.5 / 760 | HQ / gravura | illustrated fanzines, militant printmaking |
| 791.43 | Cinema | "Viva Zapata!" and films |
| 860 / 869 | Lit. hispano-am. / brasileira | novels, "Amor e anarquia" |
| 840 | Literatura francesa | "Tout pour tous", etc. |
| 920 (or B) | Biografia | Emma Goldman, Durruti, Bakunin |

### Regional history — 900

| DDC | Region | Examples |
|---|---|---|
| 909 | História mundial | overviews |
| 944.081 | França (Comuna de Paris) | Commune, French movement |
| 946.081 | Espanha (Guerra Civil) | Durruti, "Revolução e Guerra civil na Espanha" |
| 972.08 | México (Revolução) | Zapata, Flores Magón, "México insurgente" |
| 980 / 981 | América do Sul / Brasil | "História do Anarquismo no Brasil" |

### Decision heuristic

1. **General anarchist theory** → `335.83`.
2. Identifiable dominant theme → the theme's classification (education `370.1`,
   syndicalism `331.88`, land `333.3`, feminism `305.42`…).
3. **History** of an event/country → regional `9xx`.
4. **Biography** of a militant → `920`.
5. **Fiction/poetry** → `8xx` according to the language.
6. When in doubt between theory and theme: prefer `335.83` if the work
   is explicitly anarchist; otherwise the theme.
