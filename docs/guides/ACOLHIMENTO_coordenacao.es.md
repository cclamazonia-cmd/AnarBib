# Bienvenide a la red AnarBib

**Guía de acogida de las coordinaciones — los treinta primeros días**

*Versión 1.0 — 16 de septiembre de 2026 · Licencia AGPLv3 · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Antes que nada: lo que fue aceptado, y lo que todavía no

La candidatura de tu biblioteca fue aceptada por la coordinación de la red. Eso quiere
decir dos cosas, y solo dos:

1. La red reconoce a tu biblioteca como parte de la familia anarquista y libertaria que
   acoge, y te abrió el camino de la constitución.
2. Tu cuenta dejó de ser una cuenta de solicitante y pasó a ser una cuenta de
   **coordinación en constitución**.

Lo que todavía **no** ocurrió: tu biblioteca aún no está activa. Todavía no aparece en el
catálogo común, todavía no recibe lectores, todavía no intercambia nada con las otras
bibliotecas. Está en estado **preactivo**, y sos vos quien va a sacarla de ahí — no sole,
y no en un solo día.

> **La promesa de esta guía.** No hace falta que seas bibliotecarie. No hace falta que
> entiendas de informática. Hace falta que sepas lo que tu colectivo quiere, y que tengas
> a alguien a quien preguntar cuando no sepas. El resto es hacer clic.
>
> **Y la regla de oro: hacé clic, no vas a romper nada.** El software no muestra las
> transiciones imposibles, desactiva con una explicación los botones que una regla
> bloquearía, y rechaza en la base de datos las combinaciones imposibles. Los pocos gestos
> que realmente no vuelven atrás están listados en el capítulo 9.

**La persona con quien hablar.** En cualquier momento de este recorrido, antes de decidir
y no después: `anarbib@proton.me`. La red tiene por principio que una decisión de
constitución se conversa con une compañere antes de volverse un formulario. Escribir no es
señal de debilidad — es el funcionamiento normal.

---

## 1. Día 1 — Entrar, y entender dónde estás

### 1.1 Conectarse

La página de conexión es `/login` (botón **Entrar**). La dirección `/cadastro` solamente redirige
hacia ella: si algún documento viejo te manda ahí, no es error tuyo.

Si todavía usás la contraseña provisoria recibida por correo, **cambiala antes que
cualquier otra cosa**. Mientras la contraseña provisoria no se cambie, varias acciones
quedan bloqueadas — es una prueba pasiva de que la cuenta fue realmente tomada en mano por
una persona.

### 1.2 Las dos casas

Es lo más importante de toda la guía, y vale la pena aprenderlo de memoria.

| Si la pregunta es… | Vas a… |
|---|---|
| « ¿qué decidimos? » | **`/biblioteca`** — la casa colectiva |
| « ¿qué hago con esta persona que tengo delante? » | **`/painel`** — el mostrador |

En `/biblioteca` viven la identidad pública, el reglamento, el equipo, el perfil de
adopción, las transiciones y la privacidad: todo lo que el colectivo deliberó. En
`/painel` vive el trabajo de todos los días: préstamos, devoluciones, consultas, reservas,
cuentas esperando validación.

Esto no es un ordenamiento arbitrario. Muchos softwares de biblioteca mezclan las dos
cosas, y el resultado es que la configuración política termina escondida en un back-office
de administrador. Acá, la deliberación queda de un lado y la operación del otro.

### 1.3 Las rutas que vas a usar

| Ruta | Qué es | Para quién |
|---|---|---|
| `/criar-conta` | inscripción — **la única puerta de entrada, para tode el mundo** | cualquier persona |
| `/conta` | el espacio personal de cada lectore — nueve pestañas | cada persona, solo la suya |
| `/atelier` | los talleres: constitución y autoridades | coordinación en constitución |
| `/painel` | el mostrador, el trabajo del día | equipo (librarian, coordinación) |
| `/biblioteca` | la casa colectiva, las decisiones | equipo, con poderes por rol |
| `/catalogacao` | catalogar e importar | equipo |
| `/rede` | administración de la red | solo admins de la red |

La página **Federação** y las páginas públicas — catálogo, Obra, Publicación periódica,
Materia, Bibliotecas, Cartografía, Tesauro FICEDL — completan el conjunto. Las rutas no se
traducen: son las mismas en los diez idiomas.

> **Nunca entrás en la cuenta de otra persona.** Todo lo que el equipo necesita hacer por
> une lectore está en el painel. Si te sorprendiste queriendo « entrar como » alguien, lo
> que buscás está en el painel, pestaña **Lectore** (`leitor`).

---

## 2. Días 1 a 3 — El taller de constitución

La constitución es un recorrido en `/atelier`. Podés guardar en cualquier momento y volver
después: nada se pierde entre dos sesiones. **Tenés 60 días**, y un recordatorio por correo
llega el 45º.

### 2.1 Etapa 0 — el perfil de adopción, el acto fundador

Antes de todos los otros volets, el software pregunta dónde se ubica tu biblioteca en
**cuatro ejes independientes**. Ninguno es un nivel de calidad: son formas de existir, y
una biblioteca chica que elige el modo simple en todo no es una biblioteca inacabada.

**Eje 1 — `catalog_mode`, el catálogo**

- `local_only` — el acervo queda en casa, no se expone a la red. Útil en un período de
  rodaje, o cuando parte del fondo todavía no está lista para publicarse.
- `network_published` — el acervo entra en el catálogo común AnarBib.

**Eje 2 — `circulation_mode`, la circulación**

- `off` — ninguna circulación gestionada en el software: solo catálogo. Es el caso de un
  fondo patrimonial de consulta.
- `informal` — circulación simple, sin cuota ni reglas estrictas. El caso típico de una
  biblioteca militante donde todes se conocen.
- `full_sigb` — circulación completa: reglas, reservas, cuotas, suspensiones.

**Eje 3 — `network_mode`, la federación**

- `isolated` — la biblioteca existe en AnarBib pero no intercambia nada.
- `observer` — recibe los flujos de la red, todavía no contribuye.
- `federated` — participa plenamente.

**Eje 4 — `governance_mode`, la gobernanza**

- `informal` — ningún rol de equipo distinto: todes son lectores. Sin cooptación, sin
  carencia, sin registro de auditoría.
- `staff_roles` — los roles `librarian` y `coordenadore` existen, cooptación
  simplificada.
- `full_governance` — el conjunto: cooptación, carencia, registro de auditoría, crons.

### 2.2 Lo que cada elección enciende en el painel

Esta tabla es la razón por la cual la etapa 0 viene antes que todo. Las pestañas del
mostrador aparecen o no según el eje de circulación:

| Pestaña del painel | Aparece si |
|---|---|
| **Trabajo del día** (`trabalho-do-dia`) | siempre |
| **Acciones** (`acoes`) | siempre |
| **Lectore** (`leitor`) | siempre |
| **Historial** (`historico`) | siempre |
| **Consultas locales** (`consultas-locais`) | circulación `informal` o `full_sigb` |
| **Préstamos** (`emprestimos-livro`) | circulación `informal` o `full_sigb` |
| **Reservas** (`reservas`) | circulación `full_sigb` |
| **Préstamos en lote** (`emprestimos-lote`) | circulación `full_sigb` |
| **Contribuciones** (`contribuicoes`) | cuota activada **y** circulación distinta de `off` |

Si una pestaña no aparece en tu casa, no es una falla: es el perfil que tu colectivo
eligió. Y si el perfil cambia durante la sesión, el painel vuelve solo al **Trabajo del
día**.

> **Las elecciones no son prisiones.** Cada eje tiene su doctrina de transición — algunas
> rápidas, algunas lentas, algunas irreversibles. La pestaña **Transiciones** está en
> `/biblioteca`, y no en el painel: cambiar de perfil es una decisión colectiva, no un
> gesto de mostrador. Ciertas transiciones que atraviesan varios ejes pasan por la
> validación de los admins de la red.

### 2.3 Los diez volets

Después de la etapa 0, el taller muestra solamente los volets que tu perfil vuelve
pertinentes. Una biblioteca en `circulation_mode = off` no verá el volet de circulación:
no es que falte algo, es que esa pregunta no se hace en su casa.

| Volet | Lo que se decide | Condición |
|---|---|---|
| 1 | Identidad — nombre, nombre corto, dirección, contacto | siempre |
| 2 | Horarios y permanencias | siempre |
| 3 | Personas responsables | según la gobernanza |
| 4 | Política de catalogación | siempre |
| 5 | Política de circulación | si la circulación no es `off` |
| 6 | Política de adhesión de les lectores | según gobernanza y circulación |
| 7 | Política de correos | siempre |
| 8 | Visibilidad y participación en la red | si la red no es `isolated` |
| 9 | Datos y confidencialidad | siempre |
| 10 | Generación del reglamento | siempre |

**Ninguno de estos volets es una cuestión de informática.** Son diez cuestiones de
asamblea, presentadas en el orden en que se responden bien. Completalos con lo que el
colectivo ya decidió; donde todavía no decidió, pará y llevá la pregunta a la próxima
reunión. El taller espera.

### 2.4 El volet 10 — el esqueleto de reglamento

Al final, el software genera un PDF precompletado con todas tus elecciones. **Ese PDF no
es un certificado.** Es un esqueleto a discutir: una materia prima de deliberación. Las
secciones que merecen debate vienen marcadas.

El recorrido esperado es: descargar, llevar a la asamblea, enmendar libremente, y volver a
subir el documento enmendado como reglamento oficial de la biblioteca. Mientras no se
vuelva a subir, la biblioteca sigue preactiva.

> **Un punto de honestidad.** « Concluir la constitución » no vale, hoy, activación
> automática de la biblioteca. Es una laguna conocida del software, no un error tuyo.
> Cuando llegues al final de los volets, escribí a `anarbib@proton.me` para que la
> activación se haga — e insistí si nadie responde en algunos días.

---

## 3. Días 3 a 7 — La página Biblioteca, la casa colectiva

Terminada la constitución, `/biblioteca` se vuelve el lugar donde lo que fue decidido
queda inscripto y se sostiene. Es ahí donde se mira cuando alguien pregunta « ¿pero qué
habíamos acordado? ».

- **Identidad pública** — lo que la red y el público ven de tu biblioteca.
- **Reglamento** — el documento que adoptaron, y sus versiones.
- **Equipo** — quién es qué, y por qué circuito (capítulo 4).
- **Perfil** — los cuatro ejes, tal como están hoy.
- **Transiciones** — las propuestas de cambio de perfil y su votación.
- **Privacidad** — retención de los datos, purga automática, RGPD/LGPD.

**Las decisiones a resolver esta semana**, todas en `/biblioteca`:

1. **La visibilidad del acervo** — catálogo público o no, aparición en la galería de
   bibliotecas de `anarbib.org`, presencia en la cartografía de la red. En la cartografía,
   un colectivo que elige no aparecer tiene sus razones: el software las respeta, y vos
   también.
2. **La política de correos** — qué eventos generan un mensaje a la persona lectora (ciclo
   de préstamo, recordatorios antes del vencimiento, reclamos de atraso) y si el equipo
   recibe copia. Todo eso se enciende y se apaga por biblioteca.
3. **La retención de los datos** — cuánto tiempo el historial de préstamo de una persona
   queda guardado después de la devolución. Es una cuestión política tanto como legal: en
   una biblioteca militante, un historial es una lista de lecturas de personas
   identificadas. Guardar poco es una forma de protección.
4. **La cuota**, si existe en tu casa — y con ella la pestaña **Contribuciones** del
   painel.
5. **El carnet de lectore** — si lo activan. No lleva ningún nombre: solo el nombre corto
   de la biblioteca y un QR opaco, y es la propia persona lectora quien lo genera y lo
   regenera. Fue diseñado así a propósito, para que un carnet perdido no cuente nada sobre
   quien lo llevaba.

> **Sobre la pestaña Privacidad.** Puede mostrar dos mensajes que se contradicen respecto
> de la purga automática. Es un defecto conocido de visualización. Antes de concluir que
> la purga está activa o inactiva, preguntá a la red.

---

## 4. Días 5 a 10 — Constituir el equipo

### 4.1 Tres roles, y solo tres

`lectore` · `librarian` (bibliotecarie) · `coordenadore` (coordinación).

El rol local « administrador » fue retirado en mayo de 2026. Si lo encontrás citado en
algún documento, el documento está viejo. « Administradore de la red AnarBib » existe, pero
es un **estatuto transversal** — no es el escalón siguiente de la escalera, y no se llega
ahí por coordinar bastante tiempo. Es otro mecanismo político, con su propia cooptación.

### 4.2 El engaño que cuesta caro

**Nadie se inscribe dos veces.** Todes entran una sola vez por `/criar-conta`, como
lectores — incluidas las personas que van a ser del equipo.

Volverse equipo no es una nueva inscripción: es una cooptación, y ocurre en la cuenta que
ya existe. Quien se reinscribe creyendo que así « entra como equipo » solo crea una segunda
cuenta y un problema para que la coordinación deshaga.

**Entonces lo único que hay que pedirle a quien va a entrar al equipo es: « mandame tu ID
público ».**

### 4.3 El circuito en tres tiempos

Ninguna promoción es unilateral. Tres personas distintas, tres gestos:

1. **Proponer** — la coordinación propone a alguien por su ID público, para el rol
   `librarian` o `coordenadore`.
2. **Avalar** — otra persona del equipo ratifica. La persona en cuestión queda excluida
   del quórum: mientras el equipo tenga otras dos personas activas, hacen falta dos
   ratificaciones.
3. **Aceptar** — la persona propuesta acepta. Sin ese consentimiento, no pasa nada.

La propuesta **vence a los 30 días**. Una línea de lectore se cierra, se abre la de
bibliotecarie: un solo rol activo por biblioteca, y el historial queda.

> **El salto colegiado.** Por defecto, para entrar en el círculo de la coordinación hay
> que haber pasado por bibliotecarie. Para un colectivo horizontal, ese escalón intermedio
> no corresponde a nada: una sola decisión de asamblea exigía dos circuitos en el
> software. Por eso el salto — proponer a alguien directamente de lectore a la
> coordinación — existe como **opción de biblioteca**, desactivada por defecto, que tu
> colectivo activa si quiere. Acorta la escalera, nunca los consentimientos.

### 4.4 Salir del equipo

- **Carencia de 7 días** — una salida de equipo no es inmediata; la persona pasa por un
  estado intermedio, y eso deja tiempo para conversar.
- **Inactividad** — una cuenta de equipo que no se conecta hace mucho tiempo sale
  automáticamente, con aviso a la persona 30 días antes y 7 días antes. El aviso de 7 días
  va también a la coordinación, y escala a los admins de la red si la persona inactiva es
  la última coordinación de la casa.
- **Pasar la posta** — transmitir la coordinación a otra persona se hace por el mismo
  circuito en tres tiempos, antes de salir. No lo dejes para el último día.

---

## 5. Días 7 a 20 — El acervo

### 5.1 Las tres palabras que necesitás

- **Obra** — la ficha compartida: el libro en tanto obra, la misma para toda la red.
- **Holding** — el hecho de que tu biblioteca tenga esa obra.
- **Ejemplar** — el objeto físico en el estante, con su etiqueta, su estado, su historia.

Tres colectivos pueden tener el mismo libro: una obra, tres holdings, varios ejemplares.
Es por eso que corregir una ficha beneficia a toda la red, y por eso que una ficha se
corrige con cuidado.

### 5.2 Tres niveles de ficha, y ninguno está mal

| Nivel | Espíritu |
|---|---|
| **Simples** | biblioteca militante, sin pretensión académica: tipo, título, autoría, año, editorial, idioma, signatura, circulación por defecto, tapa, ISBN |
| **Avançado** | trabajo de bibliotecarie sin MARC: subtítulo, edición, colección, lugar, páginas, contribuciones tipadas, materias, notas |
| **Completo** | exhaustivo: zonas ISBD, MARC, identificadores de autoridad, procedencia completa |

**Cambiar de nivel no pierde nada.** Un campo escondido por un nivel más bajo conserva su
valor. Hacé la prueba una vez, con tus propios ojos: es lo que convence.

**Empezá en Simples.** Cinco fichas por semana, en Simples, valen más que una ficha
perfecta por mes. El acervo solo existe cuando está catalogado.

### 5.3 La única exigencia que la red realmente pide

**Ningún ejemplar nuevo sin modo de adquisición.** De dónde vino, cuándo, donado por
quién, después de qué acontecimiento.

No es un detalle erudito. En una biblioteca militante, la procedencia es la historia del
colectivo. Sin ella, el acervo se vuelve una pila anónima en una generación. La red no te
pide que hagas el trabajo retroactivo — pide que la deuda deje de crecer de ahora en
adelante.

### 5.4 El resto de `/catalogacao`, cuando lo necesites

Importaciones masivas, asistente de desduplicación en tres tiempos, búsqueda de tapas,
fuentes externas de metadatos, depósito con OCR en el navegador, inventario por lectura de
las etiquetas QR, publicaciones periódicas y sus estados de colección. Nada de eso es
necesario en la primera semana. Está ahí cuando sea el momento.

### 5.5 Materias y el tesauro FICEDL

AnarBib trae consigo el **tesauro FICEDL**: 462 términos, traducidos a los diez idiomas,
entregados con el software. Es un bien común de la federación, y ya viene completado — no
es una tarea tuya.

Las **materias locales**, al contrario, son de cada casa: es tu acervo, es tu vocabulario,
son tus elecciones editoriales. Y **alinear** tus materias con los términos FICEDL es un
acto del colectivo, no una operación técnica: decir que tu « abolicionismo penal »
corresponde al término común « prisión » es una posición documental. Por eso el
alineamiento no viene hecho.

---

## 6. Días 10 a 25 — El mostrador

Cuatro flujos, y el painel los organiza:

- **Préstamo** — salida, devolución (incluso parcial), prórroga. La prórroga puede hacerse
  ítem por ítem: si la persona terminó dos de los tres libros, solo el tercero se prorroga.
- **Devolución** — total o por línea. Una acción masiva nunca falla en silencio: lo que no
  pasó se lista con la razón.
- **Consulta local** — la persona quiere ver algo en el lugar, se negocia un horario. **La
  negociación se detiene a las tres idas y vueltas**: después de eso, el software las manda
  al teléfono. Es deliberado — una negociación que pasa de ahí no es un problema de
  software.
- **Reserva** — hasta el retiro efectivo, que transforma la reserva en préstamo.

Al lado de eso, en el painel: las **validaciones** de las inscripciones de lectores (es acá
donde deciden quién entra), la **fianza** si en su casa la practican, las
**contribuciones**, las **notas de lectura**, los **eventos**.

> **Un defecto conocido.** El botón « Abrir préstamos » de ciertas tareas del Trabajo del
> día lleva a una pestaña vacía. No sos vos. Pasá directamente por la pestaña **Préstamos**
> (`emprestimos-livro`).

---

## 7. Días 20 a 30 — La federación

La página **Federação** tiene ocho pestañas: **Início**, **Círculos**, **Diretório**,
**Assembleias**, la gaceta **Rizoma**, **Carta/Boletim**, **Apoio mútuo** y **Comuns**.

Es la parte del software que no es un SIGB. Existe porque el proyecto no quiere ser un
« SaaS para bibliotecas »: entrar en AnarBib es entrar en un proyecto político común, y una
red que solo intercambia registros bibliográficos no es una red.

Lo que hay que hacer en esta última semana, sin apuro:

1. **Pasar de `observer` a `federated`**, si eso fue lo que decidieron — y solo si fue así.
   Entrar en la red en modo observador durante algunos meses es una elección respetable.
2. **Completar su ficha en el Diretório**, para que las otras casas sepan quiénes son y
   cómo hablarles.
3. **Decidir sobre la cartografía** — aparecer con dirección precisa, solo con la ciudad, o
   no aparecer. Ninguna de las tres respuestas necesita ser justificada.
4. **Mirar los Círculos y las Assembleias**, para saber dónde se toman las decisiones de la
   red.
5. **Si publican el catálogo**, ver con la red qué significa para ustedes el punto OAI-PMH
   — es por él que otros catálogos pueden cosechar el suyo.

La página `/rede` es la administración de la red propiamente dicha, reservada a los admins
de la red. Coordinar una biblioteca no da acceso a ella, y eso es a propósito.

---

## 8. Las diez decisiones que no son técnicas

Recortá esta lista y llevala a la asamblea. Ninguna de esas respuestas está en el software:
el software solo registra lo que ustedes respondan.

1. ¿Dónde nos ubicamos en los cuatro ejes del perfil?
2. ¿Nuestro catálogo es público?
3. ¿Prestamos, y bajo qué condiciones?
4. ¿Quién puede inscribirse como lectore, y quién valida?
5. ¿Tenemos cuota? ¿Fianza?
6. ¿Cuánto tiempo guardamos el historial de lectura de las personas?
7. ¿Quién es del equipo, y activamos el salto colegiado?
8. ¿Aparecemos en la cartografía, y con qué precisión?
9. ¿Participamos de las asambleas de la red, y quién nos representa?
10. ¿Cómo alineamos nuestras materias con el tesauro común — y qué nos negamos a alinear?

---

## 9. Lo que no rompe nada, y lo que pide una segunda lectura

**No rompe nada:** hacer clic en todo, abrir todas las pestañas, cambiar el nivel de ficha
para ver, guardar un volet por la mitad, proponer a una persona y dejar que la propuesta
venza, activar y desactivar el salto colegiado, pasar de `observer` a `federated`, corregir
una ficha.

**Pide una segunda lectura, porque no vuelve atrás o cuesta caro:**

- **Eliminar** una cuenta — y atención, en portugués el software distingue **APAGAR**
  (vaciar el historial) de **EXCLUIR** (suprimir la cuenta), con dos palabras de
  confirmación diferentes. En los otros nueve idiomas las dos caen en la misma palabra: en
  español, los dos gestos caen en **ELIMINAR**. Leé la frase entera antes de escribir, no
  solo la palabra pedida.
- Borrar un historial — los datos no vuelven.
- Las transiciones de perfil marcadas como irreversibles en la pestaña Transiciones.
- Publicar en red un acervo que el colectivo todavía no decidió publicar.
- Sacar a alguien del equipo — el plazo de carencia de 7 días existe justamente para eso.

---

## 10. Dónde pedir ayuda, y cómo devolver

**Pedir ayuda:** `anarbib@proton.me`. Decí en qué pantalla estás y qué esperabas ver. No
hay pregunta tonta: el software fue escrito por una persona, y cada « no lo encontré » que
llega es un defecto identificado.

**Un ritual que funciona.** Media hora por semana, con el equipo, tres preguntas fijas:

> ¿qué no encontré en la pantalla? · ¿qué hice sin entender? · ¿qué faltaba en el software?

Las respuestas alimentan una hoja de lagunas que se vuelve el orden del día siguiente — y
un material de contribución para el proyecto. Es el único dispositivo que hace subir el uso
hasta el código.

**Devolver, sin programar.** El archivo `AIDER.md`, en la raíz del repositorio, lista las
tareas abiertas que no exigen código: traducción, revisión de escritura inclusiva,
documentación, alineamiento de materias, prueba de pantallas. AnarBib es AGPLv3 y hoy tiene
une sole mantenedore — es su principal fragilidad, y se dice en vez de esconderse.

---

## 11. Los treinta días en una página

| Cuándo | Qué | Dónde |
|---|---|---|
| Día 1 | Entrar, cambiar la contraseña, pasear sin cambiar nada | `/login`, `/conta` |
| Días 1–3 | Etapa 0: los cuatro ejes, decididos en colectivo | `/atelier` |
| Días 3–5 | Volets 1 a 9 | `/atelier` |
| Día 5 | Volet 10: descargar el esqueleto de reglamento | `/atelier` |
| Días 5–10 | Llevar el reglamento a la asamblea, enmendar, volver a subir | asamblea, después `/atelier` |
| Días 5–10 | Recoger los ID públicos, abrir los circuitos de cooptación | `/biblioteca`, pestaña Equipo |
| Días 7–20 | Primeras fichas en modo Simples, todas con procedencia | `/catalogacao` |
| Días 10–25 | Primer día de mostrador en autonomía | `/painel` |
| Días 20–30 | Ficha en el diretório, cartografía, modo de red | Federação, `/biblioteca` |
| Día 30 | Escribir a la red: qué faltó, qué confundió | `anarbib@proton.me` |

---

*Esta guía existe en diez idiomas: pt-BR, fr, es, en, it, de, ca, eo, nl, el. Describe el
estado del software en septiembre de 2026 y será corregida cuando el software cambie — si
una pantalla no corresponde a lo que está escrito acá, es la guía la que está equivocada, y
decirlo es una contribución.*

**Bienvenide.**
