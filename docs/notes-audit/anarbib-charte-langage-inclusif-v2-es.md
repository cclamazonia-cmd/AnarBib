# Carta de lenguaje inclusivo de AnarBib

**Versión** : 2.0
**Fecha** : 2026-06-05
**Estado** : referencia del proyecto (fuente única de autoridad)
**Reemplaza** : `anarbib-charte-langage-inclusif-v1.md` (v1.0, 2026-04-28), ahora **obsoleta**

Este documento fija las convenciones de lenguaje inclusivo adoptadas en las **diez
locales** de AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`,
`el`). Se aplica a toda traducción nueva, a toda revisión, y a toda contribución
futura. Está dirigido a las personas que contribuyen a los archivos
`src/i18n/locales/*.json`, a las cadenas de notificaciones de correo
(`supabase/functions/_shared/i18n/mail-strings.ts`), y a toda traducción
generada en el futuro.

> **Evolución desde la v1**: la v1 solo cubría seis locales (`pt-BR`, `fr`,
> `es`, `en`, `it`, `de`). La v2 agrega `ca`, `eo`, `nl`, `el`, y **oficializa
> la convención italiana** (asterisco para los pares regulares, barra para
> los pares irregulares) que reemplaza la barra provisional de la v1.

---

## Índice

1. [Por qué este documento](#por-qué-este-documento)
2. [Principio rector: coherencia interna por lengua](#principio-rector-coherencia-interna-por-lengua)
3. [Tabla de estados](#tabla-de-estados)
4. [Carta por lengua](#carta-por-lengua)
   - [Francés (fr)](#francés-fr)
   - [Alemán (de)](#alemán-de)
   - [Inglés (en)](#inglés-en)
   - [Portugués brasileño (pt-BR)](#portugués-brasileño-pt-br)
   - [Español castellano (es)](#español-castellano-es)
   - [Italiano (it)](#italiano-it)
   - [Catalán (ca)](#catalán-ca)
   - [Esperanto (eo)](#esperanto-eo)
   - [Neerlandés (nl)](#neerlandés-nl)
   - [Griego (el)](#griego-el)
5. [Términos políticos de referencia](#términos-políticos-de-referencia)
6. [Términos proscritos](#términos-proscritos)
7. [Procedimiento para las incorporaciones futuras](#procedimiento-para-las-incorporaciones-futuras)
8. [Cobertura de los tests (CI)](#cobertura-de-los-tests-ci)
9. [Evolución de la carta](#evolución-de-la-carta)

---

## Por qué este documento

AnarBib es un sistema integrado de gestión de bibliotecas concebido para las
bibliotecas militantes anarquistas. Una biblioteca militante no es una biblioteca
como las demás: no solo archiva documentos, sino que constituye **una memoria
colectiva**, y el lenguaje de su interfaz forma parte de esa memoria. Una interfaz
que habla de «lector» en masculino genérico reproduce el gesto de borramiento
que una biblioteca feminista o queer busca precisamente desarticular; una interfaz
que dice «compañere» señala desde el primer segundo a qué movimiento pertenece.

Pero el lenguaje inclusivo no es una norma universal. Cada lengua tiene su propia
historia, sus propias convenciones militantes, sus propios campos minados políticos.
**No existe una «buena» escritura inclusiva transversal**: existen elecciones
locales situadas, defendidas por comunidades militantes situadas. Esta carta respeta
esas situaciones locales garantizando al mismo tiempo que dentro de una misma lengua
AnarBib hable con una sola voz.

Tres objetivos concretos:

1. **Coherencia.** Dentro de un mismo archivo de locale, la misma posición de
   género se escribe siempre de la misma forma.
2. **Respeto por las culturas militantes locales.** No se impone una convención
   de una lengua a otra.
3. **Legibilidad por no-especialistas.** Une bibliotecarie militante que descubre
   AnarBib debe poder usarlo sin ser experte en tipografía inclusiva.

---

## Principio rector: coherencia interna por lengua

Cada lengua de AnarBib aplica **su propia convención tipográfica de escritura
inclusiva**, heredada del uso militante local. No se impone ninguna convención
transversal.

Dentro de una lengua, **estas convenciones son obligatorias y exclusivas**:
un archivo `fr.json` no mezcla el punto mediano con `(e)`; un archivo
`it.json` no mezcla el asterisco con el punto mediano. Las elecciones hechas en
esta carta son la **forma oficial** de AnarBib para esa lengua.

---

## Tabla de estados

| Locale | Convención | Estado |
|---|---|---|
| `pt-BR` | Forma triple `(o/a/e)` | **Adoptada** (referencia) |
| `fr` | Punto mediano `·` | **Adoptada** |
| `es` | `e` neutra (convención argentina) | **Adoptada** |
| `en` | Epiceno + `they` singular | **Adoptada** |
| `de` | Genderstern `*` | **Adoptada** |
| `it` | Asterisco (regulares) / barra (irregulares) | **Adoptada** |
| `ca` | Terminación triple `-a-e` + artículo `le` | **Adoptada** |
| `eo` | Infijo `-in-` visibilizado por guiones + pronombre `ri` | **Adoptada** |
| `nl` | Formas de rol neutras | **Provisional** — a validar en comunidad |
| `el` | — | **A definir** con une hablante griege militante |

---

## Carta por lengua

### Francés (fr)

**Convención adoptada**: punto mediano (`·`, U+00B7).

**Forma genérica**: raíz común + punto mediano + terminación femenina.

| Masculino | Femenino | Forma AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Plural**: se agrega `·s` (`lecteur·rice·s`).
**Artículos / determinantes combinados**: `le·la`, `du·de la`, `au·à la`, `un·e`,
`le·la SEUL·E`, `actif·ve`.
**Palabras ya epicenas**: sin cambio (`bibliothécaire`, `camarade`, `responsable`,
`personne`).
**Proscrito**: `(e)`, `-e` separado (convenciones anteriores a 2010), punto ordinario `.` o
viñeta `•` en lugar del mediano.

### Alemán (de)

**Convención adoptada**: Genderstern (`*`, asterisco ASCII U+002A).

| Masculino | Femenino | Forma AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Plural**: `*innen` (`Genoss*innen`, `Leser*innen`).
**Proscrito**: Mediopunkt `·`, Genderdoppelpunkt `:innen`, y el neologismo
hispanohablante *«Compas»* dejado sin traducir (siempre `Genoss*in`/`Genoss*innen`).

### Inglés (en)

**Convención adoptada**: términos epicenos por defecto, `they/them/their` en
singular como pronombre neutro.

La gramática inglesa es en gran medida epicena: se utiliza sistemáticamente la
forma neutra existente (`reader`, `librarian`, `author`, `administrator`,
`comrade`, `coordinator`, `user`), sin marcación tipográfica. Para los escasos
términos con género, se elige la forma epicena (`actor` en lugar de `actress`,
`server` en lugar de `waitress`).
**Proscrito**: `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Portugués brasileño (pt-BR)

**Convención adoptada**: forma triple `(o/a/e)` o `(a/e)` según la gramática,
incluyendo explícitamente las tres posiciones (femenino, masculino, no-binario).
**Es la locale de referencia del proyecto.**

| Masculino | Femenino | Forma AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Regla**: palabras en `-or` → `(a/e)`; palabras en `-o` → `(o/a/e)`. Terminaciones en
orden alfabético dentro del paréntesis.
**Contracciones artículo-preposición**: `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`,
`(o/a/e)s`.
**Palabras ya epicenas**: sin cambio (`camarada`, `colega`, `responsável`,
`pessoa`).
**Proscrito**: `(a)` solo, `/a`, `/o`, `@` (arroba), `x`. Atención al
**falso amigo `camarade`** (forma francesa): en pt-BR, es **`camarada`**.

### Español castellano (es)

**Convención adoptada**: `e` neutra (convención argentina militante).

| Masculino | Femenino | Forma AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Regla**: se reemplaza la vocal de género final (`-o`/`-a`) por `-e`; palabras en
`-or` → raíz + `-e` (`lector → lectore`).
**Plural**: `-s` (`compañeres`).
**Artículos / determinantes**: `le` (singular neutro), `les` (plural neutro).
**Participios concordados**: `informade`, `conectade`, `active`.
**Palabras ya epicenas**: sin cambio (`camarada`, `colega`, `responsable`,
`persona`).
**Proscrito**: `(a)`, `/a`, `/o`, **la forma triple `(o/a/e)` del pt-BR**
(el español usa SOLO la `e` neutra), `@` (arroba), `x` (Latinx), y el
**punto mediano `·`** (convención francesa, no usar en español).

### Italiano (it)

**Convención adoptada — oficial**: **asterisco `*` para los pares regulares,
barra abreviada para los pares irregulares.** Esta convención reemplaza la barra
provisional de la v1.

#### Pares regulares (raíz común en `-o`/`-a`) → asterisco `*`

Cuando el masculino y el femenino comparten la **misma raíz**, se reemplaza la
terminación de género por un asterisco, por coherencia con el Genderstern
alemán.

| Masculino | Femenino | Forma AnarBib |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(ya epiceno en sing.)* |

Se aplica también a los **participios y adjetivos concordados**: `stat*` (stato/a),
`ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a),
`benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*`
(questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Pares irregulares (raíces diferentes, tipo `-tore`/`-trice`) → barra abreviada

Cuando el femenino no comparte la raíz del masculino (`lettore` → `lettric-e`),
el asterisco es **incorrecto** (`lettor*` daría a entender un femenino inexistente
`lettora`). Se emplea por tanto la **forma de barra abreviada**, que es el *house style*
atestado en el repositorio.

| Masculino | Femenino | Forma AnarBib |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Plural irregular**: `lettori/trici`, `amministratori/trici`,
`coordinatori/trici`.
**Artículos**: `il/la`, `del/la`, `al/la`, `dal/la` (forma abreviada), `un*` para
`uno/una`.
**Palabras ya epicenas**: sin cambio (`utente`, `responsabile`, `persona`,
`collega`).

#### Nota sobre el carácter `·`

El punto mediano `·` **no** es un marcador inclusivo en italiano: sirve únicamente
como **separador tipográfico** en asuntos de correo y líneas de metadatos
(`Email · ID · Genere`). Nunca emplearlo para marcar el género.

**🚫 Proscrito absoluto**: **`camerata` / `camerati` / `cameratesco`** — apelativo
interno fascista (PNF, MSI, CasaPound, Forza Nuova, FdI). Usar `compagn*` y
sus variantes. **Esta proscripción se prueba en CI** (`i18n.test.js` y
`mail-strings.test.ts`).
**Otras formas proscritas**: `(a)`/`(o)` entre paréntesis, triple `/trice/e`, sufijo
`/x`, punto mediano `·` como marcador de género.

**Justificación militante**: el asterisco (*asterisco*) está atestado en los
ámbitos anarquistas y autónomos italófonos (Carmilla, DinamoPress, InfoAut,
Wu Ming), y ofrece coherencia visual con el Genderstern alemán. La barra
abreviada para los pares irregulares evita los femeninos incorrectos sin dejar
de ser legible.

### Catalán (ca)

**Convención adoptada**: terminación triple sufijo `-a-e` + artículo neutro `le`.

| Masculino | Femenino | Forma AnarBib |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Variante entre paréntesis** aceptada para las contracciones:
`lector(a/e)`, `coordinador(a/e)`.
**Determinante neutro**: `le` (`le lector-a-e`).
**Plural**: `-s` o forma combinada `els-les-les` / `als-a les-a les`.
**Palabras ya epicenas**: sin cambio.

> El catalán también emplea el punto voladito `·` en la **geminada `l·l`**
> (`col·lectiu`, `cancel·lada`, `sol·licitud`): es una **grafía estándar del
> catalán**, sin relación con la inclusividad. No modificarla.

### Esperanto (eo)

**Convención adoptada**: infijo `-in-` visibilizado por guiones + pronombre neutro
`ri`.

| Base | Forma AnarBib |
|---|---|
| leganto (lecteur·rice) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Variante no-binaria**: sufijo `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Pronombre neutro**: `ri`.
**Plural**: `-j` (`legant-in-oj`).

### Neerlandés (nl)

**Estado: PROVISIONAL — a validar en comunidad.**

**Orientación provisional**: privilegiar las **formas de rol neutras**
existentes en lugar de una marcación tipográfica.

| Concepto | Forma provisional |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Reglas provisionales**: evitar los sufijos con género `-ster`/`-e` cuando existe
una forma neutra; pronombre no-binario `die` (o `hen`/`hun`) — **uso aún no fijado**.

> ⚠️ Esta convención **no** es definitiva. Debe ser validada por hablantes
> neerlandófonos militantes antes de quedar establecida. Mientras tanto,
> mantenerse en las formas neutras.

### Griego (el)

**Estado: CONVENCIÓN A DEFINIR.**

**No existe un estándar tipográfico consensuado** para la escritura
inclusiva en griego. **No proponer ningún marcador de oficio.** La convención será
establecida **con une hablante griege militante** que se incorpore al proyecto.

**Enfoque transitorio** (mientras tanto): dobletes o formas neutras existentes
(`αναγνώστης/στρια`, `συντονιστής/στρια`), griego monotónico, 2.ª persona del
singular para el tuteo a le lectore (tratamiento de usted para el equipo). Sigla
RGPD → `ΓΚΠΔ`.

> ⚠️ Toda propuesta de marcador tipográfico inclusivo sistemático para el
> griego es **prematura** mientras ningún relevo helenófono militante se haya
> incorporado al proyecto.

---

## Términos políticos de referencia

### Camarade / Compañere

| Lengua | Forma oficial | Plural |
|---|---|---|
| 🇫🇷 fr | `camarade` *(epiceno)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(epiceno)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(epiceno)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagn*` | `compagn*` |
| ca | `camarada` *(epiceno)* | `camarades` |
| eo | `kamarad-in-o` | `kamarad-in-oj` |
| nl | `kameraad` *(provisional)* | `kameraden` |
| el | `σύντροφος` *(a confirmar)* | — |

### Lectore / Lecteur·rice

| Lengua | Forma oficial |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/trice` |
| ca | `lector-a-e` |
| eo | `legant-in-o` |
| nl | `lezer` *(provisional)* |
| el | `αναγνώστης/στρια` *(transitorio)* |

### Bibliotecarie

| Lengua | Forma oficial |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(epiceno)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecari*` |
| ca | `bibliotecari-ària-e` |
| eo | `bibliotekist-in-o` |
| nl | `bibliothecaris` *(provisional)* |
| el | `βιβλιοθηκάριος` *(a confirmar)* |

### Administradore

| Lengua | Forma oficial |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/trice` |
| ca | `administrador-a-e` |
| eo | `administrant-in-o` |
| nl | `beheerder` *(provisional)* |
| el | *(a definir)* |

---

## Términos proscritos

### Políticamente marcados (proscripción absoluta)

| Término | Lengua | Razón |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Apelativo interno fascista (PNF, MSI, CasaPound, Forza Nuova, FdI). **Probado en CI.** |
| `Compas` *(sin traducir)* | 🇩🇪 de | Neologismo hispanohablante dejado tal cual — usar `Genoss*in`/`Genoss*innen`. |

### Convenciones tipográficas burocráticas o inadecuadas

| Forma | Lenguas afectadas | Por qué |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Forma administrativa, no militante. |
| `@` (arroba) | pt-BR, es | Obsoleta, problema de accesibilidad (lectores de pantalla). |
| `x` (Latinx) | es, pt-BR | Desplazada por la `e` neutra en el uso militante contemporáneo. |
| `(e)`, `-e` separado | fr | Convención anterior a 2010, reemplazada por el mediano. |
| `Genderdoppelpunkt` (`:innen`) | de | Válida pero no adoptada por coherencia con `*`. |
| `he/she`, `s/he`, `(s)he` | en | Preferir `they/them` singular. |
| Triple `(o/a/e)` | es | Reservado al pt-BR; el español usa SOLO la `e` neutra. |
| Punto mediano `·` como marcador de género | es, it, ca | Convención francesa; en otro lugar, `·` es solo un separador (o la geminada `l·l` en ca). |
| Triple `/trice/e`, sufijo `/x` | it | Formas malformadas; usar barra abreviada `/trice`. |

---

## Procedimiento para las incorporaciones futuras

### Cuando se agrega una nueva clave i18n

1. **Identificar** la palabra/expresión a traducir. ¿Es un término con género?
2. **Si es así, elegir la forma epicena cuando existe** (`camarada` pt-BR,
   `responsable` fr, `utente` it…).
3. **Si no, aplicar la convención de la lengua** definida más arriba.
4. **Para el italiano**: distinguir par regular (asterisco) y par
   irregular (barra abreviada).
5. **Verificar la coherencia** con el resto del archivo.
6. **Completar las 10 locales en una sola pasada.** Una clave parcialmente
   traducida es un bug. La **paridad de claves** entre las 10 locales es
   obligatoria.

### Cuando se revisa una traducción existente

1. Localizar los marcadores **proscritos** (`(a)`, `@`, `camerata`, punto mediano
   fuera de fr/ca-geminada, triple `/trice/e`…).
2. Reemplazarlos por la forma oficial de la lengua.
3. Verificar la coherencia singular/plural.
4. Verificar la coherencia inter-locales para la misma clave.

### Cuando se solicita una traducción a una IA

Proporcionar siempre esta carta como contexto, precisar la convención esperada para
la lengua de destino y los términos proscritos, privilegiar las formas epicenas, y
**verificar el resultado** antes de integrarlo.

---

## Cobertura de los tests (CI)

- `src/tests/i18n.test.js` prueba la **paridad de claves** y la **conformidad** de
  **8 locales**: `pt-BR, fr, en, de, it, es, ca, eo`. Incluye el test bloqueante
  «el italiano nunca debe contener camerata/camerati».
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) prueba las
  cadenas de correo: paridad, términos proscritos (camerata), interpolación, fallback.
- ⚠️ **`nl` y `el` NO están cubiertos por el gate CI**: su paridad de claves
  y su conformidad no están garantizadas automáticamente. **Backlog**: agregarlos
  a `i18n.test.js` una vez que sus convenciones hayan sido establecidas.

---

## Evolución de la carta

Esta carta es un documento vivo. Puede modificarse según los siguientes principios:

- **Incorporación de términos políticos de referencia**: por decisión colectiva
  documentada en el repositorio (issue o pull request).
- **Cambio de convención de una lengua**: requiere la participación de al menos
  une militante hablante native de la lengua afectada. El cambio debe estar
  motivado política y técnicamente.
- **Establecimiento de las convenciones provisionales (`nl`) o a definir (`el`)**: sigue
  el mismo protocolo — una elección tipográfica militante local, justificada, validada
  por relevos nativos, y luego incorporada a esta carta y al gate CI.
- **Incorporación de una nueva lengua**: mismo protocolo.

---

*Carta v2 redactada el 2026-06-05 a raíz de la auditoría de lenguaje inclusivo de
las diez locales y las cadenas de correo. Documento de referencia a commitear en
`notes-audit/` del repositorio. Reemplaza la v1.0 del 2026-04-28.*
