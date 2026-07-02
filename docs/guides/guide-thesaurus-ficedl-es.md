# El tesauro FICEDL en AnarBib — consultar un vocabulario común

> **¿Para quién?** Para todo·e compañere que catalogue y quiera vincular sus libros al
> **vocabulario de materia compartido** del movimiento — el que mantiene la FICEDL. Esta
> guía explica qué es este tesauro, en qué condiciones AnarBib se conecta a él, para qué
> sirve y cómo usarlo en el día a día.
>
> **Espíritu.** AnarBib **consulta** el tesauro; no se lo apropia. El vocabulario sigue
> siendo el de la FICEDL, que es la fuente **que hace fe**. Nada aquí crea una versión
> rival: nuestra copia no es más que un *reflejo* fiel.

---

## ¿Qué es el tesauro FICEDL?

La **FICEDL** — Federación internacional de los centros de estudios y de documentación
libertarios — federa desde 1979 a CIRA, ateneos, CCL y bibliotecas anarquistas de todo el
mundo. Mantiene un **tesauro**: un *vocabulario controlado* de la documentación
libertaria — una lista razonada de **términos-materia** (los sujetos), organizados y
traducidos, para describir aquello de lo que *hablan* los documentos. Cubre las mismas
**diez lenguas** que AnarBib (exactamente las que ofrece el CIRA de Lausana) y reúne
varios cientos de términos (del orden de seiscientos). Es consultable públicamente en
`thesaurus.ficedl.info`.

Un tesauro no es un simple diccionario: es un **grafo de conceptos**. Los términos se
relacionan entre sí (más amplio · más restringido · asociado) y llevan **notas de
aplicación** que indican cómo emplearlos. AnarBib se apoya en **SKOS**, el estándar libre
de la web semántica para este tipo de vocabulario.

## En qué condiciones entró en AnarBib

Adoptar un vocabulario común es ante todo una **decisión política** — la de colectivos
que eligen hablar la misma lengua documental — y la técnica se ajusta a ella. En
concreto, AnarBib retomó el tesauro **desde el sitio de la FICEDL**
(`thesaurus.ficedl.info`) **hacia el 24 de junio de 2026**, importando sus **términos** y
sus **lugares** (las entradas geográficas) — dejando de lado las **fechas** (las entradas
cronológicas). Esta conexión sigue algunos **principios claros**, que son las *bases del
acuerdo*:

1. **Fuente canónica única.** El tesauro que *hace fe* es el de la FICEDL. AnarBib no
   posee *el* tesauro: tiene una copia de trabajo de él.
2. **Sin fork.** Nuestra copia es un **reflejo** de la versión FICEDL, nunca una versión
   rival. La interoperabilidad que la FICEDL desea queda así garantizada *por
   construcción*.
3. **Consultar, no modificar.** AnarBib **no toca** las palabras elegidas por la FICEDL.
   Una única libertad, y solo de nuestro lado: **reubicar una etiqueta de idioma mal
   colocada** (una traducción clasificada bajo un código de idioma equivocado), únicamente
   para no *perder* una traducción que ya existe — sin cambiar jamás el término en sí.
4. **Señalar, no corregir.** Cualquier otra anomalía — un idioma faltante, una errata en
   un término — **no** se rectifica en nuestro lado: se **señala** a la FICEDL, que
   corrige *su* versión de referencia.
5. **Resincronización.** Tras las correcciones de la FICEDL, AnarBib **resincroniza** su
   copia. El reflejo se actualiza; nunca diverge.
6. **Vocabulario libre y compartido.** El tesauro es **libremente compartible** (ningún
   derecho propietario lo bloquea). Su evolución se hace **colectivamente**,
   precisamente para *limitar los forks* y preservar la interoperabilidad entre
   bibliotecas.
7. **Evolución impulsada por el colectivo.** Ciertas zonas del vocabulario necesitan
   actualizarse (por ejemplo, las categorías vinculadas a las temáticas LGBTQI+). Estas
   evoluciones no se decretan desde arriba: se discuten **dentro de la federación**.

En suma: el tesauro sigue siendo **al 100 % el de la FICEDL**; AnarBib es un espejo leal
de él, y un **relevo** que traslada lo que detecta.

## Para qué sirve

- **Describir por el tema.** En la catalogación, el campo **« Materias » (autoridad de
  materia)** vincula un documento con uno o varios términos del tesauro. Es lo que
  permite encontrar un libro por **de qué habla**, no solo por su título o su autore.
- **Navegar por tema.** Estos términos alimentan las **facetas** y la navegación
  temática del catálogo público.
- **Hablar diez lenguas a la vez.** Un mismo concepto lleva su etiqueta en cada una de
  las diez lenguas: une lectore hispanohablante y une lectore grecohablante llegan al
  *mismo tema*, cada quien en su propia lengua.
- **Vincular las bibliotecas.** Porque todo el mundo se apoya en el **mismo**
  vocabulario, los catálogos se vuelven comparables e intercambiables — es la base de
  la mutualización (duplicados, préstamos interbibliotecarios, metacatálogo).

## Cómo usarlo en la práctica

1. **Busca un término en « Materias ».** En la catalogación, empieza a escribir en el
   campo **Materias**: AnarBib propone los términos del tesauro, con su jerarquía.
   Reutiliza lo existente en lugar de inventar.
2. **Elige la granularidad adecuada.** Ni demasiado amplio ni demasiado restringido: el
   término que *alguien usaría para buscar* ese libro. Dos a cuatro materias suelen
   bastar.
3. **Lee la nota de aplicación** si el término tiene una: indica cómo emplearlo.
4. **Etiqueta faltante en tu idioma (⚐).** Si un sujeto aún no tiene una etiqueta **en tu
   idioma**, se muestra por **repliegue** (a menudo en otro idioma) con un ⚐. No es un
   error: es una **laguna de la versión de referencia**. No se arregla en nuestro lado —
   ver más abajo.
5. **¿Un error, una laguna? Señala, no corrijas.** Término erróneo, traducción ausente:
   **repórtalo a la coordinación**, que lo transmite a la FICEDL. La corrección se hace
   sobre la fuente canónica, y luego nos llega por resincronización. *(Única excepción,
   ya mencionada: una etiqueta de idioma simplemente mal colocada puede reubicarse de
   nuestro lado, sin tocar la palabra.)*
6. **¿Necesitas un término que no existe?** El tesauro no se enriquece *localmente*. Por
   ahora, las **palabras clave libres** (texto libre, propias de la ficha) son la
   válvula de escape — ver la guía « Indexar por materia ». A medio plazo, una propuesta
   de incorporación **se eleva al colectivo** de la FICEDL.

## El espíritu: consultar, no capturar

Esta conexión es **una mano tendida**, no una toma: AnarBib *toma prestado* un
vocabulario común sin apropiárselo, lo *refleja* sin *congelarlo*, y le *devuelve* a la
FICEDL lo que en él observa. El tesauro sigue vivo allí donde debe estarlo — en la
federación que lo sostiene — y nuestro catálogo se beneficia de él sin competir jamás con
él. Es, a nivel de las palabras, la misma ética que rige en todo AnarBib: **ofrecer y
vincular, nunca capturar**.

> Ver también: la guía **« Indexar por materia »** (el gesto concreto en la
> catalogación) y el marco **« Ayuda mutua en la catalogación »** (el común de saber del
> que este vocabulario es el corazón). El tesauro de referencia es consultable en
> `thesaurus.ficedl.info` — fuente canónica que hace fe.

*Documento del común AnarBib. El tesauro en sí es obra de la FICEDL; esta guía explica
únicamente su uso en AnarBib.*
