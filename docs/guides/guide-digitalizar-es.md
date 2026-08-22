# Ficha — Digitalizar una obra

> **Traducción por revisar.** Esta versión se tradujo del francés para que
> exista ahora y no dentro de seis meses. Si lees este idioma mejor de lo que
> lo escribe la traducción, corrígela: es un común, no un texto cerrado.

> **A quién se dirige esta ficha.** A ti que estás frente al escáner. Cabe en
> una página y solo contiene lo que se decide en el momento de escanear: los
> tres ajustes, los cinco controles, y el destino de los archivos.
>
> El *porqué* está en otra parte, en la decisión
> `DECISION_profil_numerisation_2026-08-20`. Aquí, se hace.

## La regla, en una frase

**Se captura en escala de grises, se entrega en bitonal, solo se conserva en
línea lo que se entrega.**

---

## 1. Antes de escanear — ¿qué tenemos derecho a digitalizar?

| La obra está… | Lo que escaneas |
|---|---|
| **en dominio público** | toda la obra |
| **cedida por quien la escribió**, o con **licencia libre** | toda la obra |
| **bajo derechos** | **la portada, y nada más** |

En caso de duda, **solo la portada**. Siempre se puede digitalizar más
adelante; retirar un fondo entero publicado por error, mucho menos fácilmente.

> **Escribe por qué.** Al subir el archivo, el campo de justificación espera
> una frase: nombre de quien escribió y fecha de fallecimiento, referencia de
> la licencia, o enlace a la cesión escrita. **Es esa frase la que protege a la
> biblioteca, no la casilla marcada.** Si no sabes qué escribir ahí, es que el
> estatus no está establecido — pon `sob_direitos` y pregunta.

---

## 2. Los tres ajustes

| Lo que tienes delante | Ajuste |
|---|---|
| Texto impreso corriente | **Escala de grises — 300 ppp** |
| Cuerpos pequeños, notas, papel amarillento o dañado | **Escala de grises — 400 ppp** |
| Grabados, carteles, octavillas, prensa ilustrada, portadas | **Color — 300 ppp** |

**Nunca en blanco y negro directamente.** El escáner te lo propondrá — suele
ser su ajuste de fábrica. Recházalo. El paso a blanco y negro es irreversible:
un gris convertido en blanco no vuelve, y sobre papel amarillento se lleva
páginas enteras, los sellos y las anotaciones manuscritas.

El criterio para el color: **¿la materia es ella misma el documento?** Un
cartel, sí. Un capítulo de texto, no.

---

## 3. Después de la captura

El PDF subido no es la captura: **deriva** de ella, página a página — texto en
bitonal, ilustraciones en gris o en color. Una obra de 200 páginas mayormente
textual pesa entonces de 8 a 15 MB.

> **La cadena elegida: ScanTailor Advanced, después `img2pdf`.** El primero
> endereza, recorta y separa el texto de las ilustraciones, página por página;
> el segundo ensambla el resultado en PDF sin recodificarlo.
>
> Coge bien **Advanced**: «ScanTailor» designa también una versión abandonada,
> que no tiene el modo mixto que necesitamos aquí.
>
> **Los ajustes precisos llegarán a esta ficha** una vez probada la cadena en
> diez obras. Hasta entonces, pregunta en tu biblioteca — y en todo caso, no
> subas nunca las capturas en bruto.

Dos campos que no hay que fallar al subir:

- **Estatus de derechos** — una lista cerrada de cuatro opciones: *Dominio
  público* · *Cesión de derechos (autorización escrita)* · *Licencia libre (CC,
  copyleft…)* · *Bajo derechos — solo portada*. No se acepta nada más, y el
  campo **Justificación de derechos** justo al lado espera tu frase.
- **Acceso** — dos opciones: *Público* o *Cuenta activa (restringido)*. Para
  una obra libre, debe ser **Público**. El formulario de catalogación ya lo
  propone en *Público*: comprueba simplemente que ahí se ha quedado. En cambio,
  un recurso creado **fuera del formulario** (importación, subida automática)
  llega en *Cuenta activa* — exactamente lo contrario de lo que queremos para
  una obra de dominio público. Si pasas por una importación, revisa ese campo
  después.

---

## 4. Los cinco controles

Sobre **tres páginas al azar**, a ojo, antes de subir:

1. **Ningún carácter comido** — incluidos los acentos y la puntuación fina.
2. **Sellos, ex libris y anotaciones manuscritas legibles.**
3. **Las ilustraciones no han pasado a blanco y negro** por error.
4. **La página está derecha y completa** — sin margen recortado, sin
   encuadernación negra que se desborde.
5. **El texto es seleccionable** en un lector de PDF: la capa OCR está ahí.

**Un solo punto que falla → se rehace a partir de la captura.** Es precisamente
para eso que la conservamos hasta la validación.

---

## 5. ¿Qué pasa con los archivos de captura?

**No suben nunca al servidor.** Se quedan en tu casa o en la biblioteca, en un
disco externo, el tiempo de validar la entrega.

**Después, se borran.** Es la regla de la red: sin archivado sistemático de las
capturas.

> **Lo que eso cambia para ti.** Mientras la captura existe, una entrega
> fallida se rehace en diez minutos. Una vez borrada, hay que volver a sacar la
> obra del estante y digitalizarla de nuevo página a página. **Los cinco
> controles de arriba son por tanto tu última oportunidad — hazlos antes de
> borrar, no después.**

**Una excepción, que te toca reconocer**: una obra rara, frágil o única, que no
podríamos volver a digitalizar sin riesgo para el objeto. Ahí, guarda la
captura. La regla apunta a lo corriente, no a lo irremplazable.

---

## En una frase

Escanea en gris, rechaza el blanco y negro, revisa tres páginas, guarda la
captura hasta que el PDF esté validado. El resto se aprende haciéndolo.

---

*Documento del común AnarBib. Esta versión es una traducción: corrígela si
tu lengua merece algo mejor — es así como se vuelve nuestra.*
