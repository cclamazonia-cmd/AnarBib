# BLMF-signatuur — inventarisnorm + anarchistische DDC-raster

> Werkinstrument voor catalogisering. Bron DDC : publieke Dewey-overzichten
> (10 klassen / 100 divisies), aangepast aan de werkelijke secties van de collectie.

## 1. Inventarisnorm (inventarisnummer)

**Formaat : `CCLA.{JAAR}.{N}`**

- **JAAR** = catalogiseringsjaar (jaargang).
- **N** = acquisitietelder, **elk jaar opnieuw gestart**, **uniek per fysiek exemplaar**
  (twee exemplaren van dezelfde titel = twee afzonderlijke N's).
- **Hoofdletters** : `CCLA` in hoofdletters. Scheidingsteken : punt. Geen opvulnullen,
  geen kopiesnummer (`-01`, `-02`).

**Regel voor beginnende bibliothecaris :**
> « Nieuw boek gecatalogiseerd in {jaar} → ik neem het hoogste bestaande N
> voor `CCLA.{jaar}.*` en tel er 1 bij op. »

**Stand van zaken op 2026-06-07 (na de unificatie van de 246 BLMF-exemplaren) :**

| Jaargang | Gebruikte reeks | Volgende vrije N |
|---|---|---|
| 2023 | 1 → 222 (legacy) | (gesloten) |
| 2024 | 1 → 53 (legacy) | (gesloten) |
| **2026** | 1 → 76 | **77** |

→ De hervatting van de catalogisering 2026 gaat dus verder met `CCLA.2026.77`.

*Historische noot : in 2023 volgde N vaak het bibliografische referentienummer ;
in 2024/2026 is N een acquisitieteller. Omdat de jaargangen afzonderlijk zijn,
is geen enkele botsing mogelijk. Alleen de lopende jaargang volgt de regel « max+1 ».*

## 2. Gerichte DDC-raster (anarchistische secties)

De anarchistische Dewey-referentiecode is **335.83 (Anarquismo)**. De meeste werken
over theorie vallen hieronder ; de rest wordt ingedeeld naar **thema** (onderwijs,
arbeid, land, geschiedenis van een bepaalde revolutie, biografie).

### Politieke kern — 300

| DDC | Benaming (pt-BR) | Waarvoor / voorbeelden |
|---|---|---|
| 303.6 | Conflito social, revolução | revolutietheorie, geweld/geweldloosheid |
| 305.42 | Mulheres, feminismo | « Mulher, Vida, Liberdade », libertair feminisme |
| 305.5 / 305.8 | Classes sociais / grupos étnicos | klasse, ras |
| 320.5 | Ideologias políticas | overzichten van ideologieën |
| 321.07 | Anarquia (ausência de governo) | staats-/niet-staatstheorie (variant van 335.83) |
| 322.42 | Movimentos revolucionários | bewegingen, strijdorganisaties |
| 323.044 | Ação direta, desobediência civil | directe actie, verzet |
| 324.2 | Partidos / eleições | « Os Anarquistas e as Eleições » |
| 331.88 | Sindicalismo, sindicatos | syndicalisme, « imprensa operária » |
| 333.3 | Posse da terra | MST, strijd om het land, agrariërs |
| 334 | Cooperativas, autogestão | « Autogestão », coöperativisme |
| **335.83** | **Anarquismo** | **anarchistische theorie (standaardsignatuur)** |
| 335.4 | Marxismo | marxisme, vergelijkingen |
| 355 | Ciência militar, militarismo | « Militarismo na América latina » |
| 365 | Prisões | gevangenis, abolitionisme |
| 370.1 / 371.04 | Filosofia da educação / escolas alternativas | Moderne School, Ferrer, « Educar para emancipar » |

### Overige nuttige klassen

| DDC | Benaming | Waarvoor / voorbeelden |
|---|---|---|
| 070.4 | Imprensa, jornalismo | « A imprensa libertária do Ceará » |
| 170 / 171 | Ética | ethiek, moreel anarchisme |
| 211 | Ateísmo, agnosticismo | « Deus e o Estado » (anticléricalisme) |
| 335.83 ↔ 304.5 | (Kropotkin) | « Apoio mútuo » : afhankelijk van de invalshoek, 335.83 (sociaal) |
| 741.5 / 760 | HQ / gravura | geïllustreerde fanzines, militante gravure |
| 791.43 | Cinema | « Viva Zapata! » en films |
| 860 / 869 | Lit. hispano-am. / brasileira | romans, « Amor e anarquia » |
| 840 | Literatura francesa | « Tout pour tous », enz. |
| 920 (of B) | Biografia | Emma Goldman, Durruti, Bakunin |

### Geschiedenis per regio — 900

| DDC | Regio | Voorbeelden |
|---|---|---|
| 909 | História mundial | panorama's |
| 944.081 | França (Comuna de Paris) | Commune, Franse beweging |
| 946.081 | Espanha (Guerra Civil) | Durruti, « Revolução e Guerra civil na Espanha » |
| 972.08 | México (Revolução) | Zapata, Flores Magón, « México insurgente » |
| 980 / 981 | América do Sul / Brasil | « História do Anarquismo no Brasil » |

### Beslissingsheuristiek

1. **Algemene anarchistische theorie** → `335.83`.
2. Herkenbaar dominant thema → signatuur van het thema (onderwijs `370.1`,
   syndicalisme `331.88`, land `333.3`, feminisme `305.42`…).
3. **Geschiedenis** van een gebeurtenis/land → `9xx` regionaal.
4. **Biografie** van een militant → `920`.
5. **Fictie/poëzie** → `8xx` naar gelang de taal.
6. Bij twijfel tussen theorie en thema : de voorkeur geven aan `335.83` als het werk
   expliciet anarchistisch is ; anders het thema.
