# Ficha — Escribir un nombre, escribir un título

> **Traducción por revisar.** Esta versión se tradujo del francés para que
> exista ahora y no dentro de seis meses. Si lees este idioma mejor de lo que
> lo escribe la traducción, corrígela: es un común, no un texto cerrado.

> **A quién se dirige esta ficha.** A ti que catalogas. Reúne lo que se decide
> en el momento de escribir: cómo se escribe un nombre, dónde cortar una
> partícula, qué hacer con una colectividad, y por qué un campo vacío vale más
> que un campo adivinado.
>
> El *porqué* detallado está en otra parte, en el registro de decisiones,
> sección `CONV`. Aquí, se cataloga.

## La regla, en una frase

**Una sola verdad en la base, varias presentaciones.** Tú escribes la forma de
catalogación; las mayúsculas, el orden nombre-apellido y los formatos
bibliográficos se **calculan** al mostrar y al exportar. No los escribas nunca
a mano.

De ahí viene todo el desorden que estamos reparando: el punto de acceso, la
forma de visualización y la forma de exportación se alojaron **en el mismo
campo**, en momentos distintos, por manos distintas.

---

## 1. El nombre de una persona

### La forma de ordenación es la que vale

El campo **«Forma de ordenación»** es la verdad. La **«Forma estándar»** deriva
de él automáticamente, por simple inversión de la coma. Nunca al revés.

| Escribes en «Forma de ordenación» | La aplicación muestra |
|---|---|
| `Kropotkin, Piotr` | Piotr Kropotkin |
| `Malatesta, Errico` | Errico Malatesta |

### Caja natural, nunca en mayúsculas

**`Kropotkin, Piotr` — nunca `KROPOTKIN, Piotr`.**

Las mayúsculas del apellido son una **norma de referencia bibliográfica**
(ABNT), no un dato. Se añaden al exportar, sobre la marcha. Escribirlas tú no
las hace más verdaderas: destruye la información de caja, que después no se
reconstituye — `de Sousa` y `De Sousa` dejan de ser distinguibles una vez todo
en mayúsculas.

### Dónde cortar: la partícula

**Decide la lengua del NOMBRE, no el país de nacimiento.** Una persona
argentina puede llevar un nombre italiano.

| Lengua del nombre | La partícula… | Ejemplo |
|---|---|---|
| portugués, francés | **se pospone** tras el nombre de pila | `Sousa, Manuel Joaquim de`<br>`Beauvoir, Simone de`<br>`Jong, Rudolf de` |
| italiano moderno, afrikáans, neerlandés | **se mantiene** delante | `Di Filippo, Luis`<br>`De Amicis, Edmondo`<br>`Van der Walt, Lucien` |

Luis Di Filippo es el caso ejemplar: argentino, nombre italiano, por tanto
`Di Filippo, Luis` — y no `Filippo, Luis Di`.

> **En castellano**, el apellido doble no se corta: `García Lorca, Federico`,
> no `Lorca, Federico García`.

### Lo que la herramienta no sabe decidir

**¿Apellido doble o nombre compuesto?** `García Lorca` es un apellido doble; 
`Jean-Marie` es un nombre compuesto. Ninguna función distingue las dos cosas.
En caso de duda, **pregunta** en vez de decidir: es exactamente ese tipo de
caso el que va a la cola de verificación.

---

## 2. Una colectividad no es una persona

**Un nombre de colectivo no tiene forma invertida.**

| ✅ | ❌ |
|---|---|
| `Grupo Krisis` | `Krisis, Grupo` |
| `Instituto de Estudos Libertários` | `Libertários, Instituto de Estudos` |
| `CIRA Marseille` | `Marseille, CIRA` |

### Rellena «Tipo de autoridad»

El campo existe y **gobierna la regla**. Marcado como *Colectividad*, impide la
inversión. Dejado vacío, nada protege la ficha: será tratada como persona en el
primer paso de la herramienta.

Son tres segundos que evitan tres meses de corrección.

### Si la ficha contiene VARIAS personas

Ocurre — la importación fabricó casos así. `KAISER, William Young and David E.`
no es un Kaiser con dos nombres: son **William Young** *y* **David E. Kaiser**,
dos autores de un mismo libro.

**No lo repares sobre la marcha.** Una ficha de autoridad la comparte toda la
red: renombrarla solo desplaza el error. Pasa por el Taller de autoridades,
propuesta de tipo **Escisión**: la ficha de origen se conserva, las demás se
crean, y los vínculos con los libros las siguen. Plazo de deliberación: catorce
días, como una fusión.

---

## 3. El título

### La caja depende de la lengua del título

**No** hay regla universal. El alemán capitaliza sus sustantivos: es su
**ortografía**, no un error de escritura.

La herramienta de normalización solo baja las **palabras funcionales de la
lengua del título**, en posición no inicial. Preserva:

- la **primera palabra**;
- las palabras tras **puntuación fuerte** (`.` `:` `;` `?` `!` y la raya de
  subtítulo);
- las **siglas**.

**Retira un artefacto de importación, no «recasa» el título.** Cuando te
propone una corrección, sigues siendo tú quien juzga si una palabra es nombre
propio — la herramienta no lo sabe.

| Antes | Después |
|---|---|
| `Antologia Do Movimento Operário Gaúcho` | `Antologia do Movimento Operário Gaúcho` |
| `Der Einzige Und Sein Eigentum` | `Der Einzige und sein Eigentum` |

### El artículo inicial: no mutiles nunca el título

`Los Trabajadores` se escribe **`Los Trabajadores`**. No `Trabajadores, Los` —
eso es un resto de la ficha de cartón — y no `Trabajadores` a secas.

La ordenación se resuelve con un **contador de caracteres no ordenables** (aquí:
4, por `Los `), que deja el título intacto.

---

## 4. La lengua y el país

| Campo | Formato | Ejemplos |
|---|---|---|
| **Idioma** (del documento) | código BCP-47 | `pt-BR`, `fr`, `es`, `de`, `it` |
| **País** (de la autoridad) | código ISO 3166-1 α-2 | `BR`, `FR`, `ES`, `NL` |

Ni `español`, ni `España`, ni `esp`. El selector de la aplicación te da el
código correcto: úsalo en vez de escribir.

**Un vacío sigue vacío.** Si no conoces el idioma, déjalo en blanco. Un idioma
desconocido es una información honesta; un idioma equivocado gobierna después
la caja del título y la regla de entrada del nombre — propaga el error en vez
de contenerlo.

---

## 5. Las fechas

Dos números enteros y un **calificador**:

| Calificador | Cuándo |
|---|---|
| `exact` | la fecha está establecida |
| `circa` | aproximada («hacia 1876») |
| `uncertain` | las fuentes divergen |
| `unknown` | no se sabe |
| `living` | **la persona está viva** |

`living` no es un detalle cómodo: sin él, «aún viva» y «fecha de muerte
desconocida» se confundían — lo que equivalía a matar gente en el catálogo.

Cuando nacimiento y muerte son ambos desconocidos, usa el **periodo de
actividad** («activo 1900-1910»). Y cuando las fuentes se contradicen,
escríbelo en la **nota de fechas**: es reparación historiográfica, no relleno.

---

## 6. Lo que no te toca decidir en solitario

El corpus de autoridades lo **comparte toda la red**. Modificar una ficha es
modificar el catálogo de varias bibliotecas.

| Gesto | Dónde ocurre |
|---|---|
| corregir una errata en una ficha | directamente |
| **fusionar** dos fichas duplicadas | Taller — propuesta, 14 días |
| **escindir** una ficha que contiene dos | Taller — propuesta, 14 días |
| decidir una caja o un apellido propuesto por la herramienta | cola de verificación |

En el Taller, una propuesta queda abierta el tiempo necesario para que las
demás bibliotecas puedan objetar. Ese plazo no es lentitud administrativa: es
lo que hace que el corpus siga siendo común.

---

## En caso de duda

**Deja vacío en vez de adivinar.**

Un campo vacío formula una pregunta — alguien la verá y la responderá. Un campo
falso responde a una pregunta que nadie hizo, y parece correcto. Es ese el que
se reencuentra tres meses después, copiado en cinco catálogos.
