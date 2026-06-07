---
title: "Guía de gobernanza de AnarBib"
subtitle: "Para le uso de les coordinadores de biblio y les administradores de la red"
author: "Projet AnarBib"
date: "Versión 1.1 — 5 de junio de 2026"
lang: es
---

# Prefacio

Esta guía está dirigida a las personas que, en la red AnarBib, ejercen una función de coordinación — ya sea coordinando una biblio local o administrando la red. Tiene un doble objetivo:

- **Explicar la lógica política** de las reglas inscritas en el SIGB AnarBib, y su filiación con el proyecto de emancipación colectiva que dio origen a las bibliotecas anarquistas;
- **Dotar de herramientas las prácticas** cotidianas, respondiendo a las preguntas concretas que las coordinaciones encuentran cuando utilizan el software.

## Una convención política

Esta guía no es el reglamento de la red, y no tiene ninguna autoridad superior a las decisiones de los colectivos que la componen. Lo que contiene solo tiene fuerza porque une serie de personas se pusieron de acuerdo para hacer funcionar las cosas así en un momento dado. Si las prácticas evolucionan, este texto deberá evolucionar con ellas, o ser contradicho, o ser roto. Es el uso que los colectivos hagan de él lo que decidirá su suerte.

Las reglas técnicas que el SIGB AnarBib hace cumplir — los plazos de carencia, los flujos de trabajo de cooptación, los estatutos de los membresías, etc. — también son convenciones. Fueron escritas por compañeres en fechas precisas, para resolver problemas precisos. Están consignadas en **archivos de especificación** (los `spec-*.md` del repositorio), fechados y firmados, que son a su vez enmendables. Cuando se lee esta guía, se lee el estado de un debate en un instante dado. No es una constitución.

## Cómo está organizada esta guía

La guía está en dos partes:

- **Parte I — El porqué.** Cuatro capítulos que plantean el marco político: para qué sirve un SIGB anarquista, cuáles son sus principios fundadores, cómo se articulan los dos perímetros (biblio local y red), y cómo las propias reglas pueden ser enmendadas.

- **Parte II — El cómo.** Seis capítulos prácticos que tratan cada une una gran pregunta operacional: cooptar, retirar, gestionar las situaciones que se descarrilan, ejercer una función de admin de red, garantizar la transparencia, y un último capítulo que comenta casos concretos de principio a fin.

Al final de cada capítulo práctico, una sección **«Si la regla te molesta»** recuerda dónde discutirlo y cómo proponer una enmienda. Esto es importante porque estas reglas solo tienen sentido si son enmendables.

Los anexos al final del volumen sirven de referencia rápida: glosario, índice de las funciones técnicas con su traducción política, modelo de propuesta de enmienda, y enlaces hacia las specs fuentes.

## Cómo leer esta guía

Se puede leer de un tirón, pero probablemente ese no sea el mejor uso. Tres formas de entrar en el texto según las necesidades:

- **Para comprender el espíritu del proyecto** antes de asumir una función: leer la parte I (capítulos 1 a 4).
- **Ante una situación concreta**: saltar directamente al capítulo práctico correspondiente (5 a 10).
- **Para informarse de cara a una asamblea** donde se va a plantear una cuestión de gobernanza: leer el capítulo correspondiente más la sección «Si la regla te molesta» correspondiente, y consultar la spec fuente en el anexo D.

Lo que está escrito aquí se apoya en cuatro documentos de especificación:

- `spec-gouvernance-roles.md` (5 de mayo de 2026) — roles, estatutos, transiciones;
- `spec-administrateur-reseau.md` (11 de mayo de 2026) — separación local/red, cooptación por unanimidad;
- `spec-validation-physique.md` (3 de mayo de 2026) — modos de acogida de las cuentas lectores;
- `spec-refactor-v3-semantique.md` (9 de mayo de 2026) — semántica del flujo de trabajo de reserva (mencionado al margen).

Las referencias a estas specs se recuerdan a lo largo del texto bajo la forma `(cf. spec-gouvernance, §3.4)` para permitir profundizar.

## Una nota sobre la voz

El texto alterna entre **une** (el colectivo AnarBib, del que le autore y le lectore también forman parte), **vos** (cuando se dirige a une coordinadore o administradore precise que debe tomar una decisión), y **nosotres** (cuando se habla de les compañeres que escribieron las reglas, en un momento dado, y que podrían ser distintes de quien las lee). Es deliberado. No hay neutralidad institucional aquí: este texto es impulsado por compañeres, y se dirige a compañeres.

\newpage

# Parte I — El porqué

\newpage

# 1. ¿Qué significa un SIGB anarquista?

## 1.1. El SIGB no es la asamblea

El primer principio a sostener, y el más difícil, es este: **el SIGB registra las decisiones del colectivo, no las toma**. Esta frase parece inocua. En realidad es el pivote alrededor del cual todo lo demás se organiza.

Cada vez que el SIGB AnarBib parece una autoridad — cuando rechaza una promoción, cuando impone un plazo de carencia de siete días, cuando bloquea una transición de estatuto — solo está **haciendo ejecutable** una regla que los colectivos se dieron a sí mismos. La regla fue escrita en algún lugar, en una spec, tras una discusión. Alguien la releyó y criticó. Una versión fue fijada y desplegada. Y ahora, en el instante en que hacés clic en el botón, el software se limita a aplicar lo que fue acordado.

Si encontrás la regla estúpida, contraproducente o injusta, no es el SIGB lo que hay que combatir. Es la spec lo que hay que enmendar. Ver capítulo 4.

## 1.2. La tensión asumida

Todo software que gestiona permisos es, por construcción, un dispositivo de jerarquización. Alguien tiene que poder validar una inscripción, modificar la identidad pública de una biblio, acceder a los datos personales de une lectore. Esta necesidad técnica está en tensión aparente con el ideal de horizontalidad que anima a las bibliotecas anarquistas.

AnarBib **asume esta tensión** en lugar de ocultarla. El compromiso político que se encontró se sostiene en dos puntos:

- Los **roles no son rangos**. Son **funciones** temporalmente delegadas por el colectivo a algunes de sus miembros para ejecutar tareas técnicas precisas. Nadie es coordinadore «de por vida». Nadie es admin de red «por esencia». Estas funciones son prestadas, y pueden ser recuperadas.

- Los **mecanismos de retiro** cuentan tanto como los mecanismos de nominación. El SIGB prevé explícitamente cómo alguien sale de una función — por auto-remoción, por pedido colectivo con plazo de carencia, por auto-retiro de la red, por retiro colectivo a la unanimidad. Una función que no puede abandonarse no es una función, es una captación.

## 1.3. Delegación y rotación

La idea central es la de la **delegación con rotación**. Un colectivo delega en algunes de sus miembros la ejecución de tareas técnicas (gestionar los préstamos en el SIGB, modificar la visibilidad de la biblio, dar la bienvenida a une nueve membre en el equipo). Esta delegación es:

- **Explícita**: se encarna en un acto de cooptación trazado en el audit log;
- **Reversible**: la persona delegada puede abandonar la función cuando quiera, y el colectivo puede pedírselo según modalidades encuadradas;
- **Temporaria por naturaleza**: incluso si el SIGB no impone ninguna duración, la cultura política de la red es que las funciones rotan, y nadie se instala en ellas.

Es esta rotación de funciones lo que marca la diferencia entre una «delegación» (anarquista) y una «jerarquía» (estatal o capitalista). Si uno se instala en una función, se convierte en un escalón. Si se sale regularmente de ella, se sigue siendo une compañere que presta un servicio.

## 1.4. Los ocho principios fundadores

La spec de gobernanza de roles (`spec-gouvernance-roles.md`, §2) explicita ocho principios fundadores. Los listamos aquí para referencia en el resto de la guía; cada capítulo práctico de la parte II remitirá a ellos.

**P1 — Delegación, no jerarquía.** Ningún rol es un título. Todos los roles son temporarios por naturaleza y revocables.

**P2 — Cooptación para los roles de staff.** El ingreso a un equipo (convertirse en librarian o coordenador) se hace por cooptación de les coordenadores existentes. Es el colectivo quien decide quién es admitide; le coordinadore no es más que la mano que ejecuta la decisión en el SIGB.

**P3 — Remoción voluntaria siempre posible.** Toda persona con un rol de staff puede removerse a sí misma en cualquier momento, sin consulta. «Paso la posta» es un derecho fundamental.

**P4 — Exclusión encuadrada por un plazo de carencia.** La exclusión no voluntaria de une librarian por parte de une coordinadore pasa por un plazo de carencia de siete días antes de entrar en efecto. Este plazo permite la deliberación colectiva y la eventual anulación por parte de otre coordinadore.

**P5 — Transparencia máxima.** El audit log de los cambios de rol es legible por todo el staff activo de la biblio, no solo por les coordenadores. Impedir las manipulaciones opacas forma parte de la cultura política de horizontalidad informacional.

**P6 — Notificaciones sistemáticas.** Todo cambio de rol desencadena un email a la persona concernida y a toda la coordinación. Nadie puede ser modificade en su rol sin saberlo, y la coordinación siempre está informada.

**P7 — Soberanía local de las biblios.** Los cambios de rol en la biblio A no afectan nada en la biblio B, incluso para la misma persona. Cada biblio es soberana sobre sus delegaciones internas.

**P8 — El SIGB no modela la asamblea.** El SIGB ejecuta las decisiones, no las toma. No contiene ningún mecanismo de voto, quórum o deliberación. Estas cosas ocurren en colectivo, fuera del software.

## 1.5. Lo que el SIGB no hace

Es útil hacer explícitas las elecciones de **no-modelización**:

- El SIGB **no define** qué es una «buena» coordinación. Una biblio puede decidir en círculo, en asamblea plenaria, por rotación, por sorteo, por consenso, por mayoría. Al SIGB eso no le importa.
- El SIGB **no mide** la legitimidad política de una cooptación. Si une coordinadore hace clic en «promover a X librarian», el SIGB registra. Es el colectivo quien debe asegurarse de que la decisión fue tomada correctamente, y es en la cultura política del colectivo donde se juega esa seguridad.
- El SIGB **no arbitra** los conflictos. Cuando algo se descarrila, el SIGB provee herramientas (suspensión inmediata, pedido de retiro, audit log legible) pero la decisión política permanece fuera del software.

Esta modestia no es un defecto, es una exigencia. Un SIGB que pretendiera modelar la vida política de un colectivo sería, ipso facto, autoritario — impondría su visión de lo que es una «buena» decisión. AnarBib rechaza esa pendiente.

## 1.6. ¿Y el respeto de las libertades digitales?

Tres precisiones, porque la pregunta vuelve:

- **Datos personales**: las cuentas lectores contienen lo que la persona quiso poner ahí. Las biblios solo tienen acceso a los datos estrictamente necesarios para su funcionamiento. Las membresías en otras biblios son, por construcción, estancas (P7).

- **Audit log**: el log es público **para el staff activo** de la biblio, no para les lectores ni para el resto de la red. Esta transparencia interna sirve para impedir las manipulaciones opacas entre coordinaciones; no es un panóptico dirigido contra les lectores.

- **Logs cross-biblios**: cuando une admin de red interviene en una biblio (caso cubierto por la spec admin-reseau, §6.3.1), la acción es trazada en una tabla dedicada con nivel de criticidad. Es legible por les admins de red y por la coordinación de la biblio concernida. La transparencia en ambos sentidos.

\newpage

# 2. Los dos perímetros: biblio local y red

## 2.1. Por qué esta separación

La red AnarBib no es una cadena de bibliotecas con una sede central. Es una **federación de colectivos autónomos**. Esta realidad política terminó por imponerse en la propia estructura del SIGB.

Inicialmente, en las primeras versiones, el rol de «administradore AnarBib» estaba asociado a una biblio precisa en la tabla `user_library_memberships`. Esta modelización sugería — sin decirlo — que une admin AnarBib *administraba una biblio*. Eso no era cierto políticamente: une admin de red anima la coordinación inter-biblios, no dirige ninguna biblio en particular.

La spec `spec-administrateur-reseau.md` (11 de mayo de 2026) formalizó la separación. Ahora el SIGB conoce **dos perímetros distintos**:

- **El staff local** de una biblio (roles `reader`, `librarian`, `coordenador`), almacenado en `user_library_memberships`. Su autoridad política se sitúa **dentro del perímetro de la biblio**.

- **La administración de la red** (tabla `network_administrators`), sin asociación a una biblio. Su autoridad política es **transversal**, pero nunca se sustituye a la autonomía local.

## 2.2. Lo que hace cada perímetro

**El staff local** gestiona el día a día de una biblio: préstamos, devoluciones, reservas, validación de las inscripciones, modificación del reglamento, de las políticas de circulación, de la identidad pública de la biblio. Todo lo que concierne el funcionamiento de **una** biblio se resuelve al nivel del staff local.

**La administración de la red** asegura la coordinación inter-biblios: activación de las nuevas biblios, moderación del catálogo compartido, mantenimiento técnico de la plataforma, acogida de los nuevos colectivos, e intervención excepcional cuando una biblio se encuentra bloqueada (sin coordinadore active, conflicto mayor, etc.). Todo lo que concierne **la red** se resuelve al nivel de la administración de red.

## 2.3. La regla de la no-superposición

Una regla política simple guía todos los contadores y todas las vistas del SIGB:

> **Cada página cuenta la historia de su perímetro. Un contador cuenta lo que está inscripto en su perímetro, ni más ni menos.**

Concretamente:

- La página de una biblio cuenta sus membresías locales. Punto. Les admins de red no aparecen en esos contadores, aunque puedan técnicamente intervenir en la biblio.
- La página de la red cuenta sus administradores de red. Punto.

Si una persona es a la vez `coordenador` de una biblio **y** administradore de red (el caso de Xavier al 11 de mayo de 2026), aparece en ambos contadores, **una vez en cada une**, sin deduplicación cruzada. Son **dos inscripciones políticas distintas**, contadas cada una en su perímetro.

Por qué esta regla es políticamente sana, en cuatro puntos:

- **Honestidad**: tu compromiso local es contado en la biblio donde animás; tu compromiso de red es contado al nivel de la red. Nadie te cuenta «1,5 veces».
- **Legibilidad**: une militante que mira la ficha de una biblio ve inmediatamente cuántas personas están comprometidas **localmente**, sin tener que preguntarse si les admins de red «externes» inflan el contador.
- **Robustez**: si mañana se agregan roles intermedios (auxiliar, practicante, observadore), la regla «página = perímetro» sigue siendo clara.
- **Coherencia política**: la separación entre admin de red y staff local es una **decisión política**, no un detalle de modelización. Los contadores deben reflejarla.

## 2.4. El derecho transversal del admin de red

Este punto merece ser bien comprendido porque es fácil interpretarlo mal.

**Une admin de red puede técnicamente intervenir en cualquier biblio.** Puede, por ejemplo, leer el catálogo de una biblio `private`, modificar su visibilidad, o — en casos excepcionales — crear o modificar membresías. Esto es lo que la spec llama el **derecho de intervención transversal**.

Este derecho existe por dos razones:

- **Mantenimiento**: alguien tiene que poder desbloquear una biblio que se averió (sin coordinadore, configuración rota, etc.).
- **Mediación**: cuando un conflicto grave atraviesa una biblio e impide al colectivo local funcionar, se necesita un recurso.

Pero este derecho **no** convierte a le admin de red en une superiore jerárquique de la coordinación local. La doctrina de la red, planteada en esta guía:

> **Una intervención de admin de red en una biblio local debe estar precedida de una información a la coordinación local concernida**, salvo urgencia vital (compromiso activo, acoso en curso, ataque contra la plataforma). La información previa no es una solicitud de autorización: le admin de red tiene el derecho de actuar. Pero es una **muestra de respeto** hacia la autonomía de la biblio, y preserva la posibilidad de otro arreglo (por ejemplo: «dejame intentar resolver esto primero, te mantengo informade»).

La trazabilidad técnica existe además: todas las acciones cross-biblios de une admin de red son trazadas en la tabla `cross_library_actions_log` con un nivel de criticidad, legibles por la coordinación local a posteriori.

## 2.5. La soberanía local es inviolable

Una última precisión política, que se desprende del principio **P7 — Soberanía local de las biblios**.

Las biblios de la red AnarBib **se reconocen mutuamente**. Cuando BLMF valida físicamente a une nueve lectore (cf. `spec-validation-physique.md`), esta validación vale para todas las biblios `network` de la red. Es un **pacto de circulación implícito** entre biblios que comparten suficiente cultura política como para confiar unas en otras.

Pero este reconocimiento mutuo **no otorga ningún derecho de injerencia** de una biblio en otra. La coordinación de la biblio A no puede modificar las membresías de la biblio B. No puede ver los datos personales de les lectores de B (salvo aquelles que también estén inscriptes en la suya). No puede cambiar el reglamento de B.

Cada biblio sigue siendo **soberana sobre sus delegaciones internas**, su política de acogida, su modo de validación, sus reglas de cuota, su reglamento interno. La red no dice cómo deben funcionar. Solo dice con quiénes se reconocen.

\newpage

# 3. Estatutos, roles, transiciones: la gramática del SIGB

Este capítulo es un poco más árido que los demás. Aquí se sienta el vocabulario técnico que se utilizará a lo largo de toda la guía. Si lo saltáis en la primera lectura, podréis volver cuando lo necesitéis.

## 3.1. Los cuatro roles

El SIGB AnarBib utiliza cuatro roles, declarados en la base de datos mediante la restricción `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` sobre la tabla `user_library_memberships`.

**`reader`** — Cuenta lectore de base. Sin poder de administración. Permisos: consultar el catálogo (según la visibilidad de la biblio), pedir prestado, reservar, consultar en sala, modificar sus propios datos personales, solicitar la migración o supresión de su cuenta.

**`librarian`** — Staff operacionale. Gestiona el día a día: préstamos, reservas, devoluciones, validación de inscripciones (según el modo de la biblio), modificación de los datos del catálogo, acceso a los datos personales de les lectores de la biblio. **Solo lectura** sobre la lista del equipo. Recibe las notificaciones de cambios de rol y puede leer el registro de auditoría del equipo (P5).

**`coordenador`** — Staff de coordinación. Todo lo que tiene un·a librarian, más: modificar la identidad pública de la biblio (nombre, logo, contacto, etc.), modificar la configuración (políticas de préstamo, reglamento), gestionar las reglas de cotización, **y todas las acciones de gobernanza del equipo**: cooptar, solicitar una retirada, suspender, levantar una suspensión, cancelar una solicitud de retirada.

**`administrador`** — Rol histórico, en vías de desaparición. Existía para significar «derecho de administración cross-biblios» pero vinculado a una `library_id`. Ahora reemplazado por les **administradores de red** almacenades en la tabla `network_administrators` (cf. capítulo 2). La spec admin-red prevé la migración progresiva y la retirada definitiva de este rol de la tabla `user_library_memberships`.

## 3.2. Los cinco estatutos de una membership

Cada línea de la tabla `user_library_memberships` tiene un **estatuto** que expresa el estado de la delegación en un momento dado. Son posibles cinco estatutos:

**`active`** — Estado normal. La persona tiene su rol y lo ejerce.

**`pending`** — Reservado a la spec de validación física. La membership está creada pero en espera de un encuentro físico con une librarian+ de la biblio de inscripción. Sin acceso a las funciones del rol mientras se tenga este estatuto.

**`suspended`** — **Medida cautelar** tomada por une coordenador·a. Sin ningún acceso. Uso: acoso notificado en espera de investigación, cuenta comprometida, conflicto en proceso de mediación. **Duración indefinida**; el levantamiento es manual, por une coord (retorno a `active`) o por destitución efectiva.

**`pending_removal`** — **Período de carencia de siete días** antes de la exclusión efectiva. Sin ningún acceso durante este período. Evolución posible: cancelación por otre coord (retorno a `active`), auto-retrogradación por la propia persona (cortocircuito), o paso automático a `inactive` a D+7.

**`inactive`** — Membership cerrada. La persona ya no está en el equipo. Sin ningún acceso. Varios orígenes posibles: salida voluntaria, fin de la carencia, cuenta abandonada (automático a los 9 meses).

## 3.3. El esquema de transiciones

El SIGB no permite cualquier transición entre estatutos. A continuación, simplificado, el esquema autorizado:

```
                       ┌──────────────┐
                       │   active     │ ◄──────────┐
                       └──────┬───────┘            │
                              │                    │
              ┌───────────────┼───────────────┐    │
              ▼               ▼               ▼    │
       ┌─────────────┐  ┌─────────────┐  ┌─────────┴────┐
       │  suspended  │  │ pending_    │  │  inactive    │
       │             │  │ removal     │  │              │
       └──────┬──────┘  └──────┬──────┘  └──────────────┘
              │                │
              │ levantamiento  │ cancelación
              └────────────────┴────────────┐
                               │            │
                               ▼ (D+7)      ▼
                        ┌──────────────┐
                        │   inactive   │
                        └──────────────┘
```

Algunas reglas clave:

- **No** se puede pasar directamente de `active` a `inactive` para une librarian por decisión unilateral de otre coord. Hay que pasar por `pending_removal` y esperar la carencia (o que la persona se retrograde elle misma).
- Siempre se puede pasar del propio estatuto `active` a `inactive` (auto-retro, derecho P3).
- `suspended` **no** tiene duración máxima. No es una carencia antes de la exclusión, es una medida cautelar — dura lo que dura la deliberación.
- De `inactive`, **no se vuelve** a `active`. Para reintegrar a une persona, se crea una nueva línea de membership. El historial queda preservado.

## 3.4. Las nueve transiciones, quién puede hacer qué

La spec de gobernanza de roles formaliza nueve transiciones, listadas aquí de forma condensada. El detalle operacional está en la parte II.

| # | Transición | Quién | Mecanismo |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coord+ | Cooptación |
| T2 | `librarian` → `coordenador` | Coord+ | Cooptación |
| T3 | `coordenador` → `librarian` | Elle misma O otrés coords | Auto-retro O retirada colegiada con carencia |
| T4 | `librarian` → `reader` (voluntarie) | Elle misma | Auto-retro |
| T5 | `librarian` → `reader` (colectivo) | Coord+ | `pending_removal` con carencia 7d |
| T6 | Suspensión inmediata | Coord+ | Paso a `suspended` |
| T7 | Levantamiento de suspensión | Coord+ | Retorno `suspended` → `active` |
| T8 | Cancelación de una solicitud de retirada | Coord+ | Retorno `pending_removal` → `active` |
| T9 | Salida automática (cuenta abandonada) | Cron | Paso a `inactive` tras 9 meses sin login |

Tres principios articulan esta tabla:

- **La entrada pasa por la cooptación** (T1, T2). Nadie se promueve a sí misme.
- **La salida voluntaria siempre es posible** (T3 auto, T4). Nadie queda atrapade en una función que ya no quiere ejercer.
- **La salida impuesta se ralentiza con la carencia** (T5). Siete días para permitir un posible cambio de opinión colegiado.

## 3.5. Lado admin de red: un esquema gemelo

La administración de red (tabla `network_administrators`) tiene su propio ciclo de vida, estructuralmente muy próximo pero con dos especificidades:

- **Cooptación por unanimidad**: para añadir une nueve admin de red, une admin active abre una propuesta, y **todes les demás admins actives** deben votar `favorable`. Un solo voto `opposed` (con justificación obligatoria de 20 caracteres mínimo) bloquea la propuesta. Una abstención también bloquea mientras no se convierta en voto.

- **Retirada colectiva por unanimidad**: para retirar a une admin de red contra su voluntad, el mismo workflow se aplica en espejo. Con un plazo de carencia de **siete días** tras el acuerdo unánime (campo `pending_collective_removal_until`).

El auto-retiro, en cambio, es **unilateral y siempre posible** (salvo si se es le únique admin active, en cuyo caso la transición pasa por `pending_removal` con una carencia de 30 días, y un correo de alerta a les demás admins).

Detalles completos en el capítulo 8.

\newpage

# 4. Reversibilidad y enmendabilidad

Este capítulo corto trata una cuestión política crucial: **¿cómo pueden modificarse estas reglas?** Si no pudieran serlo, el SIGB sería una autoridad, y todo el resto de esta guía sería una mentira.

## 4.1. Tres niveles de enmendabilidad

Hay que distinguir tres niveles de reglas, que no se enmiendан de la misma manera:

**Las prácticas locales de una biblio** — política de acogida, modo de validación física (`open` o `manual_validation`), reglamento interno, frecuencia de las asambleas, modalidades de cooptación. Estas prácticas son **internas a cada biblio**. La red no se mete. Se enmiendán en asamblea de biblio, o según el procedimiento que el colectivo se haya dado.

**Las reglas de la red** — separación local/red, principio de cooptación por unanimidad para les admins de red, doctrina de información previa en una intervención cross-biblios, modalidades de activación de nuevas biblios. Estas reglas son **inter-biblios**. Se enmiendán en coordinación de red, tras discusión entre admins de red y coordinaciones locales concernidas.

**Los fundamentos políticos del proyecto** — los ocho principios (P1 a P8 del capítulo 1), la idea de que el SIGB no modela la asamblea, la modestia reivindicada del software frente a la vida política de los colectivos. Estos fundamentos pueden enmendarse, pero son estructurantes: modificarlos es probablemente modificar lo que llamamos «AnarBib» en sentido amplio. Una revisión de tal envergadura pasaría por una discusión colectiva en toda la red, probablemente con motivo de un evento (encuentro anual, etc.).

## 4.2. Cómo proponer una enmienda

No hay una sola manera de hacerlo — cada nivel tiene la suya — pero aquí está el patrón general que la red tiende a practicar:

1. **Identificar la spec concernida**. Las reglas del SIGB están consignadas en ficheros `spec-*.md` del repositorio. Encontrad la que contiene la regla que queréis enmendar (el anexo D da las correspondencias).

2. **Redactar una nota de enmienda**. Formato libre, pero que responda a: qué regla, por qué plantea un problema, qué modificación se propone, qué consecuencias técnicas y políticas se anticipan. El anexo C propone un modelo.

3. **Hacer circular la nota**. Según el nivel:
   - **Local**: en asamblea de biblio, o en el canal de discusión del colectivo.
   - **Red**: en el canal de coordinación inter-biblios (Matrix `#anarbib`), etiquetando a les admins de red y las coordinaciones locales pertinentes.
   - **Fundamentos**: en todos los canales, y probablemente en el orden del día de un encuentro.

4. **Discutir, enmendar, retener una versión**. El SIGB no dice cómo debe desarrollarse este paso. Es el oficio de los colectivos.

5. **Si se toma la decisión**: une admin de red o une dev (a menudo les mismes) implementa la modificación en la spec correspondiente, luego en el código. La nueva versión se despliega según el procedimiento habitual (changelog, comunicación, etc.).

## 4.3. Si la decisión técnica plantea un problema

A veces se llega a un acuerdo político sobre una regla, pero su traducción técnica es complicada, pesada, o tiene efectos secundarios indeseados. Es normal. Las specs existentes están llenas de notas del tipo «esta decisión política implica tocar 22 sub-SELECT en las RLS, lo que justifica un refactoring previo». El diálogo político / técnico es permanente.

Cuando propongáis una enmienda, no dudéis en hacerlo aunque no tengáis idea de la dificultad técnica. Les dev de la red os dirán lo que cuesta. Y si es muy caro, podréis decidir colectivamente si el reto político vale el coste técnico. A la inversa, a veces un cambio político aparentemente anodino permite simplificar enormemente la base de código.

## 4.4. Esta guía es ella misma enmendable

Esta guía está versionada. La versión actual se indica en la página de portada. Si encontráis que dice algo incorrecto, que ha olvidado un caso, o que toma una posición que ya no corresponde a la doctrina de la red, **decidlo**. Abrid una discusión, proponed una modificación, o reescribid el pasaje y enviadlo.

Una guía que no puede modificarse no es una guía, es un dogma. El proyecto AnarBib no tiene vocación de producir dogmas.

\newpage

# Parte II — El cómo

\newpage

# 5. Cooptar a alguien en el equipo

Este capítulo cubre las transiciones T1 (`reader` → `librarian`) y T2 (`librarian` → `coordenador`), es decir, los **dos movimientos de entrada** en un equipo de biblio. La validación física de une nueve `reader` (que no es una cooptación en sentido político sino una operación técnica de acogida) se trata por separado en §5.5.

## 5.1. El principio político

> **P2 — Cooptación para los roles staff.** La entrada en un equipo se hace por cooptación de les coordenadores existentes. Es el colectivo político quien decide quién es admitide; le coordenador·a no es más que la mano que ejecuta la decisión en el SIGB.

Esto significa que **hacer clic en «Promover»** no es una decisión personal de le coord que hace clic. Es la **ejecución técnica** de una decisión que ha sido tomada — o debe tomarse — por el colectivo político de la biblio. La doctrina de la red sobre «en qué momento exacto» debe tomarse la decisión no está deliberadamente zanjada por esta guía: cada biblio elabora su propia doctrina (ver §5.4).

## 5.2. Para hacer entrar a alguien como `librarian` (T1)

### Precondiciones

- La persona tiene una cuenta AnarBib (está inscrite en algún lugar de la red).
- No tiene ya una membership `librarian` o `coordenador` activa en la misma biblio.
- Puede, o no, tener ya una membership `reader` en la misma biblio. Si es así, esa membership existente permanecerá activa en paralelo (multi-membership autorizada).

### Procedimiento en el SIGB

1. Ir a `/biblioteca`, pestaña **Equipo** (visible para `coordenador+`).
2. Si la persona ya es reader de la biblio, hacer clic en **«Invitar al equipo»** en su línea. Si todavía no es reader, usar la búsqueda en la barra superior o — si aún no tiene cuenta — pasar por el workflow de invitación por email (por venir, cf. `spec-invitation-equipe.md`).
3. Elegir el rol `librarian`.
4. Confirmar la modal. Un campo «Razón» es opcional — sirve para inscribir en el registro de auditoría el contexto de la cooptación (por ejemplo «decisión de la asamblea del 04/05», o «cooptación en círculo restringido, a validar en la próxima asamblea»).
5. El SIGB ejecuta:
   - Creación de una línea `user_library_memberships` con `role='librarian'`, `status='active'`.
   - Email a la persona concernida: «Has sido nombrade librarian de [biblio] por [vosotres]».
   - Email a todes les coordenadores actives de la biblio.
   - Entrada en el registro de auditoría: `action='promoted_to_librarian'`.

### Efecto inmediato

La persona recibe, sin demora, los permisos de `librarian`: gestión de préstamos, validación de inscripciones, acceso a los datos personales de les lectores de la biblio, etc. No recibe los permisos de modificación de la identidad pública ni de la configuración — estos están reservados a les `coordenador+`.

### Lado técnico

RPC concernida: `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.3. Para promover a une `librarian` a `coordenador` (T2)

### Precondiciones

- La persona tiene una membership `librarian` `active` en la biblio.
- No tiene ya una membership `coordenador` activa en la misma biblio.

### Procedimiento en el SIGB

1. Ir a `/biblioteca`, pestaña **Equipo**.
2. En la línea de la persona, hacer clic en **«Promover»** → **«coordenador»**.
3. Confirmar la modal. El campo «Razón» es opcional.
4. El SIGB ejecuta:
   - Creación (o reactivación) de una línea `coordenador` `active`. La antigua línea `librarian` permanece activa en paralelo (multi-membership; ver §5.6).
   - Email a la persona.
   - Email a todes les coordenadores actives.
   - Entrada en el registro de auditoría: `action='promoted_to_coordenador'`.

### Efecto inmediato

La persona recibe, además de sus permisos de `librarian`, los permisos de coordinación: modificación de la identidad pública, de la configuración, de las reglas de cotización, y todas las acciones de gobernanza del equipo.

### Lado técnico

RPC concernida: `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.4. La cuestión política: ¿cuándo hacer clic?

Es la pregunta que tode coord se hace la primera vez. La red AnarBib **deliberadamente no ha zanjado** esta cuestión a nivel de la guía: cada biblio elabora su propia doctrina, porque la cultura política de un colectivo anarquista no se decide a escala de una guía genérica.

Aquí están las tres doctrinas que se encuentran en la red, sin juicio de valor:

**Doctrina 1 — Espera estricta.** Solo se hace clic **después** de una decisión actatada del colectivo (asamblea, círculo, consenso formal, independientemente de la modalidad). Le coord solo ejecuta. Ventaja: maximización de la horizontalidad, fuerte trazabilidad política. Inconveniente: puede ser lento, especialmente cuando la biblio está en sus inicios o el colectivo está disperso.

**Doctrina 2 — Anticipación delimitada.** Le coord puede anticipar una decisión que considere cierta («está claro que Voltairine va a ser cooptade, lleva seis meses viniendo todas las semanas»), **a condición de explicitarlo en el registro de auditoría**: razón = «anticipación bajo mi responsabilidad, a validar en la próxima asamblea». La decisión puede ser impugnada a posteriori, y la retirada siempre es posible. Ventaja: flexibilidad práctica. Inconveniente: desplaza una parte de la responsabilidad política sobre le coord que hace clic.

**Doctrina 3 — Círculo de coords.** La cooptación es tomada por acuerdo entre les coords actives de la biblio, sin pasar por la asamblea plenaria. Argumento: la coordinación es en sí misma un colectivo deliberativo, y tiene el mandato de actuar. Ventaja: intermedia entre 1 y 2. Inconveniente: puede volverse opaca si la coordinación no se renueva elle misma.

**Nuestra recomendación** (y nada más): **elegid explícitamente** una doctrina, escribidla en el reglamento de vuestra biblio, e indicadla en el campo «Razón» del registro de auditoría en cada cooptación («doctrina 2 — anticipación bajo mi responsabilidad», por ejemplo). La opacidad rara vez es buena en política.

## 5.5. Caso particular: la validación física de une `reader`

La **llegada** de une `reader` a una biblio es una operación diferente de una cooptación en sentido político. Está cubierta por la spec `spec-validation-physique.md`.

Dos modos posibles, elegidos por cada biblio en su configuración:

**Modo `open`** — La validación es **automática** en la inscripción. Una vez creada la cuenta y confirmado el email, le `reader` tiene acceso inmediato a los catálogos `public` y `network`. Adaptado a las biblios poco expuestas políticamente.

**Modo `manual_validation`** — La cuenta se crea en línea pero permanece **en espera** hasta un **encuentro físico** entre le `reader` y une `librarian+` de la biblio de inscripción. Adaptado a las biblios expuestas (contexto político tenso, fondos sensibles, locales frágiles, etc.).

### Procedimiento de validación física (modo `manual_validation`)

1. La persona se inscribe en línea y elige vuestra biblio como biblio de adscripción.
2. Su cuenta se crea con `status='pending'`. Recibe un correo explicando que debe presentarse físicamente en la biblio.
3. Cuando viene, une `librarian+` la encuentra, verifica lo que haya que verificar (la doctrina de lo que «verificar» significa es local), y hace clic en **«Validar»** en su línea en la pestaña **Equipo** → sección **Cuentas en espera**.
4. Un campo «Nota» opcional permite inscribir un contexto («encuentro del 12/05 durante la permanencia, presentade por Emma»).
5. La cuenta pasa a `status='active'`. La persona recibe un correo de bienvenida.

### Importante político

- La validación física de una biblio **vale para toda la red** de biblios `network` (P7 matizado: la soberanía local concierne a las delegaciones internas, pero el reconocimiento mutuo es un pacto explícito).
- Lo que se «verifica» en una validación física **no** es un control de identidad en sentido administrativo. Es un encuentro. Cada biblio define su sentido político. Para algunas, es «intercambiamos un poco para comprobar que la persona no es une policía o une fasciste». Para otras, es «presentamos la biblio, su funcionamiento, sus reglas». Para otras más, es simplemente «nos vemos en persona para que la relación sea encarnada».
- Una biblio puede **cambiar de modo** en cualquier momento (`coordenador+`). El cambio no invalida las validaciones existentes.

## 5.6. El multi-membership, punto de atención

Una particularidad técnica que conviene entender: una persona puede tener **varias líneas** de membership en la misma biblio, con roles diferentes. Por ejemplo, Voltairine puede ser a la vez `reader` y `librarian` de BLMF. Esto es posible gracias a la restricción UNIQUE sobre el trío `(user_id, library_id, role)`.

**Por qué esta posibilidad:** preserva el historial. Si mañana Voltairine se retrogrада de `librarian` a `reader`, su línea `librarian` pasa a `inactive` pero la línea `reader` permanece — sin tener que recrear una nueva inscripción desde cero.

**Consecuencia práctica:** en la UI, se muestra a la persona **una sola vez**, con su rol **de nivel más alto activo** (administrador > coordenador > librarian > reader). En el registro de auditoría, en cambio, se ve cada línea por separado.

## 5.7. Errores y salvaguardas

Algunos casos que se encuentran regularmente:

**«El SIGB me dice que la persona ya es librarian.»** Probablemente es cierto. Verificad la pestaña **Equipo**: si la persona ya figura como librarian, estáis intentando promoverla al mismo nivel, el SIGB devuelve un éxito silencioso (`{ok: true, no_change: true}`) porque no hay nada que hacer.

**«No veo a la persona en la lista.»** Tres casos posibles: (a) aún no tiene cuenta AnarBib (usar el workflow de invitación por correo, por venir); (b) tiene una cuenta pero no está inscrite en ninguna biblio (debe inscribirse en vuestra biblio como `reader` primero); (c) está en la red pero filtrade por la búsqueda — intentar con su email exacto.

**«He hecho clic por error en Promover.»** Sin pánico. Usar **«Solicitar la retirada»** para abrir un período de carencia de 7 días (cf. capítulo 6), o pedir a la persona que haga clic en **«Cedo el paso»** (auto-retrogradación inmediata). Mencionar «error de manipulación» como razón.

**«La persona no recibe el correo.»** Verificad primero la ortografía de su email en su perfil, y pedirle que mire en sus spams. Si el problema persiste, comentadlo con une admin de red: probablemente es un problema de configuración de correo que investigar.

## 5.8. Si la regla os molesta

Varias cosas de este capítulo pueden no convenceros:

- **El principio de cooptación en sí** (P2). Pensáis que toda persona `reader` comprometide debería poder pasar libremente a `librarian` sin necesitar cooptación. Es un debate político de fondo, que toca el principio P1. A llevar al canal de coordinación de red y probablemente a discutir en un encuentro.

- **La ausencia de una doctrina zanjada sobre «cuándo hacer clic»** (§5.4). Pensáis que la guía debería recomendar una sola doctrina. O al contrario, que sugiere demasiadas. Proponed una enmienda a este capítulo, argumentando.

- **Los modos de validación física** (§5.5). Pensáis que hace falta un tercero («validación diferida», «validación a distancia», otro). A llevar a `spec-validation-physique.md`.

- **El multi-membership** (§5.6). Pensáis que es innecesariamente complejo y que debería haber un solo rol por persona por biblio. Es una decisión de modelo de datos, más estructurante de lo que parece. A plantear con les dev.

Ver capítulo 4 para el procedimiento general de enmienda, y anexo C para el modelo de nota.

\newpage

# 6. Ceder la función, retirarse, suspender

Este capítulo cubre las transiciones T3 a T8 — es decir, **todo lo que saca a une compañere de un equipo**, o le pone en pausa. Políticamente, es probablemente el capítulo más importante de la guía, porque los mecanismos de retiro están en el corazón del proyecto anarquista (cf. capítulo 1, §1.2).

## 6.1. Los principios políticos

Tres principios estructuran este capítulo :

> **P3 — Degradación voluntaria siempre posible.** Tode compañere con un rol staff puede degradarse a sí misme en cualquier momento, sin consulta. « Cedo la función » es un derecho fundamental.

> **P4 — Exclusión encuadrada por un plazo de espera.** La exclusión no voluntaria de une `librarian` por parte de une `coordenador` pasa por un plazo de espera de siete días antes de tener efecto. Este plazo permite la deliberación colectiva y la eventual anulación por parte de otre coordenador.

> **P6 — Notificaciones sistemáticas.** Todo cambio de rol desencadena un correo electrónico a la persona concernida y a toda la coordinación.

La idea de fondo es que nunca se saca a nadie de un equipo « por sorpresa » o « en silencio ». O la persona decide por sí misma (y es inmediato), o el colectivo lo solicita (y está registrado, notificado, y deliberable hasta el último segundo).

## 6.2. Ceder la función : auto-degradación (T3 y T4)

Es el **derecho más fundamental** en el sistema de gobernanza de AnarBib. Toda persona que ejerza una función staff puede, en cualquier momento, sin ninguna consulta, abandonarla.

### Cuándo utilizarlo

- Ya no tienes tiempo para ejercer la función.
- Ya no te reconoces en las decisiones de la coordinación.
- Estás en desacuerdo con una decisión y quieres dessolidarizarte.
- Simplemente quieres hacer rotar la función.
- Necesitas una pausa.
- No hace falta dar ninguna razón, en realidad. El derecho a marcharse es incondicional.

### Procedimiento

1. Ir a `/biblioteca`, pestaña **Equipe**.
2. En **tu propia línea**, hacer clic en **« Je passe la main »**.
3. Elegir el nivel de degradación :
   - Si eres `coordenador`, puedes elegir « volver a librarian » (te quedas en el equipo como `librarian`) o « salir del equipo » (vuelves a ser `reader`).
   - Si eres `librarian`, puedes elegir « salir del equipo » (vuelves a ser `reader`).
4. El modal recuerda las consecuencias. Confirmar.

### Efecto inmediato

- Tu membership actual (`librarian` o `coordenador`) pasa a `inactive`.
- Si no tenías ya la membership objetivo (`reader` o `librarian`), se crea con estado `active`.
- Correo a toda la coordinación + a ti misme (confirmación).
- Audit log : `action='self_demoted'`.

### Caso especial : eres le unique coordenador active

El SIGB **te deja marcharte**, pero te avisa :

> ⚠️ ATENCIÓN : eres le unique coordenador active de [biblio]. La biblioteca quedará sin coordinación. Les administradore de AnarBib serán notificades. ¿Continuar?

Si confirmas :
- Tu membership coord pasa a `inactive`.
- La biblioteca entra en **modo degradado** : les `librarian` pueden seguir gestionando los préstamos, validar las inscripciones, etc., pero ninguna modificación de la identidad pública o de la configuración es posible hasta la cooptación de une nueve coord.
- Correo a todes les admins de la red : « La biblioteca X no tiene coordenador. Les librarians actives son : ... »

Políticamente, esto es importante : el SIGB **no impide** tu marcha. Pero informa a la red, para que une admin de red pueda, si así lo deseas y si el colectivo local lo necesita, ponerse en contacto para ayudar a organizar la transición. Es la rotación de funciones en acción.

### Lado técnico

RPC : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

## 6.3. Solicitar el retiro de une librarian (T5)

Cuando el colectivo decide que una persona debe abandonar el equipo, y esa persona no se degrada por sí misma, se abre una **solicitud de retiro con espera de siete días**.

### Precondiciones

- Eres `coordenador+` active de la biblioteca.
- La persona destinataria tiene una membership `librarian` o `coordenador` en estado `active`.
- No eres la persona destinataria (en ese caso usar §6.2).

### Procedimiento

1. Ir a `/biblioteca`, pestaña **Equipe**.
2. En la línea de la persona, hacer clic en **« Demander le retrait »**.
3. El modal que se abre es **rojo e insistente**. Recuerda :
   - El plazo de espera : « Esta solicitud tendrá efecto el [fecha J+7] salvo anulación por parte de otre coordenador. »
   - El carácter reversible : « Anulable por cualquier coord hasta la fecha de efecto. »
   - El carácter colegiado : « Todes les coords actives serán notificades. »
4. Un campo **« Raison »** es obligatorio — mínimo 20 caracteres. No hay retiro silencioso. La razón puede ser política (« decisión AG del 04/05 ») o práctica (« salida geográfica anunciada »). Será legible por tode le staff en el audit log.
5. Confirmar.

### Efecto inmediato

- La membership pasa a `pending_removal`.
- Campo `pending_removal_until` = `now() + 7 days`.
- Campo `pending_removal_requested_by` = tú.
- **Sin acceso** para la persona durante el plazo de espera (la membership queda congelada como `suspended`).
- Correo a la persona concernida : « La coordinación ha solicitado tu retiro del equipo [biblio] (preaviso hasta el [fecha]). Esta decisión corresponde a la vida orgánica del colectivo [biblio] ; para cualquier discusión, dirígete a la coordinación. »
- Correo a todes les coordenadores actives : con tu nombre y la razón.
- Audit log : `action='removal_requested'` con tu `actor_user_id` y el campo `reason`.

### Efecto en J+7 (cron automático)

Si la solicitud no ha sido ni anulada ni cortocircuitada :
- La membership pasa a `inactive`.
- Correo final a la persona y a la coordinación : « Retiro efectivo. »
- Audit log : `action='removal_completed'`.

### Lado técnico

RPC : `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron : `cron_team_pending_removal_complete` (se ejecuta diariamente).

## 6.4. Anular una solicitud de retiro (T8)

El **resguardo colegiado** del sistema. Cualquier coord — no necesariamente quien lo solicitó — puede anular una solicitud de retiro durante el período de espera.

### Cuándo utilizarlo

- La discusión colectiva ha llegado a otra decisión (mediación, suspensión temporal en su lugar, etc.).
- La solicitud inicial se hizo en caliente y la coordinación quiere retomar el control colegiadamente.
- La persona destinataria ha sido finalmente contactada y la situación está desactivada.

### Procedimiento

1. Ir a `/biblioteca`, pestaña **Equipe**, sección **Suspensions et préavis en cours**.
2. En la línea de la persona en `pending_removal`, hacer clic en **« Annuler la demande »**.
3. Modal simple de confirmación. Campo « Raison » opcional.
4. Confirmar.

### Efecto inmediato

- La membership vuelve a `active`.
- Campo `pending_removal_until` restablecido a NULL.
- Correo a la persona : « La solicitud de retiro ha sido anulada. Recuperas tus prerrogativas. »
- Correo a toda la coordinación.
- Audit log : `action='removal_cancelled'` con tu `actor_user_id`.

### Políticamente

La anulación está deliberadamente muy fácil de activar. Es un mecanismo de **reequilibrio colegiado** : si une coord ha solicitado un retiro en caliente, cualquier otre coord puede suspender la ejecución mientras el colectivo delibera. Esto hace que las solicitudes de retiro sean menos pesadas (no hay drama irreversible) pero también menos ligeras (cualquiera puede contradecirte). Ese es el valor del plazo de espera.

### Lado técnico

RPC : `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Suspensión inmediata : la medida cautelar (T6 y T7)

La suspensión es una herramienta **diferente** a la solicitud de retiro. Es **inmediata**, sin plazo de espera, y **sin duración máxima**. No es una exclusión, es una **puesta en pausa**.

### Cuándo utilizarlo

Casos típicos previstos por la spec :

- **Cuenta comprometida** : hay razones para pensar que la contraseña de la persona se ha filtrado. Se suspende a la espera de que cambie su contraseña.
- **Acoso reportado urgente** : une lectore reporta un comportamiento abusivo de une membre del staff. Se suspende a la espera de la investigación colectiva.
- **Comportamiento manifiestamente abusivo** observado en directo : se suspende mientras la coordinación se reúne.
- **Conflicto en mediación** : la persona queda en pausa voluntariamente mientras la mediación concluye.

### Procedimiento

1. Ir a `/biblioteca`, pestaña **Equipe**.
2. En la línea de la persona, hacer clic en **« Suspendre »**.
3. Modal con un campo **« Raison de la suspension » obligatorio** (mínimo 20 caracteres). Esta razón será legible en el audit log por tode le staff active.
4. Confirmar.

### Efecto inmediato

- La membership pasa a `suspended`.
- **Sin acceso** para la persona. El rol nominal se conserva (sigue apareciendo como « librarian suspendide ») pero ya no puede hacer nada.
- Correo a la persona concernida : urgente, con la razón, y — en el caso de una cuenta comprometida — una invitación a cambiar su contraseña.
- Correo a toda la coordinación.
- Audit log : `action='suspended'` con tu `actor_user_id` y el campo `reason`.

### Levantamiento de la suspensión

Cuando la situación está resuelta (cuenta asegurada nuevamente, mediación concluida, investigación cerrada, etc.) :

1. Pestaña **Equipe** → sección **Suspensions et préavis en cours**.
2. En la línea suspendida, hacer clic en **« Lever la suspension »**.
3. Modal simple. Campo razón opcional pero recomendado para cerrar políticamente el episodio.
4. Confirmar.

Efecto : retorno a `active`, correos, audit log `action='unsuspended'`.

### Importante : suspensión vs retiro

La distinción es crucial :

| | Suspensión (T6) | Retiro (T5) |
|---|---|---|
| Efecto | Inmediato | Diferido (J+7) |
| Duración | Indefinida | 7 días luego `inactive` |
| Reversible por | Levantamiento explícito | Anulación durante el plazo de espera |
| Uso típico | Medida cautelar | Decisión de exclusión |
| Política subyacente | « Nos damos tiempo para entender » | « Hemos decidido que esta persona sale » |

El SIGB **rechaza** pasar una membership de `suspended` directamente a `pending_removal` (la transición no está autorizada por la matriz). Por qué : son dos temporalidades políticas distintas. Para pasar de una a la otra, hay que explícitamente **levantar la suspensión** primero (retorno a `active`), luego solicitar el retiro (`pending_removal`). Esta doble etapa es deliberada : obliga al colectivo a formalizar explícitamente la transición.

### Lado técnico

RPC suspender : `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC levantar : `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Degradar a otre `coordenador` (T3 colectivo)

Un caso algo particular : ¿qué hacer cuando la coordinación quiere **degradar a une coordenador** que no se degrada espontáneamente?

La spec de gobernanza trata este caso como una **solicitud de retiro con plazo de espera** dirigida a la membership `coordenador`. Concretamente, se utiliza el mismo procedimiento que en §6.3 (« Demander le retrait »), pero seleccionando el rol `coordenador`. La persona pasa a `pending_removal` en su membership `coordenador` ; en J+7, esa membership pasa a `inactive`. Si tenía una membership `librarian` paralela, esta sigue activa (y la persona « cae » a librarian). Si no, vuelve a ser simple `reader`.

Es deliberadamente el mismo mecanismo que para les `librarian`, con los mismos resguardos. **Ningune otre coord tiene un poder especial** sobre sus compañeres : el procedimiento pasa por el plazo de espera y la colegialidad.

## 6.7. Cuenta abandonada : salida automática (T9)

El SIGB incluye un mecanismo de **salida automática** para las cuentas que no han tenido conexión desde hace mucho tiempo.

### El umbral

El SIGB observa el campo `last_sign_in_at` en Supabase. Si una membership staff tiene une usuarie cuya última conexión se remonta a más de **9 meses**, la cuenta es retirada progresivamente :

- **J-30 días** (8 meses después de la última conexión) : correo de aviso a la persona (« tu membership va a desactivarse en 30 días sin conexión »).
- **J-7 días** : correo de recordatorio.
- **J = 9 meses** : paso automático a `inactive`. Correo final a la persona + a toda la coordinación.

### Por qué esta regla

Es un compromiso entre dos exigencias :

- No dejar **indefinidamente** memberships fantasma que inflan artificialmente los equipos.
- No **expulsar** brutalmente a une compañere que simplemente haya tomado una pausa y cuente con volver.

Una simple conexión basta para reiniciar el contador. No es necesario realizar ninguna acción, solo conectarse.

### Caso especial : le unique coord abandona

Si la persona retirada automáticamente es le **unique coordenador active** de la biblioteca, el cron escala a une admin de red **antes** de ejecutar la salida. Le admin de red es notificade por correo, puede ponerse en contacto con la coordinación (si queda algún fragmento) o con les `librarian` de la biblioteca, y coordinar la transición.

Políticamente, esto es coherente con lo que se hace cuando le unique coord se degrada explícitamente (§6.2) : no se bloquea la salida, pero se alerta a la red para que pueda ayudar si es necesario.

## 6.8. Algunos casos límite a conocer

**Une compañere en `pending_removal` que pide marcharse enseguida.** Puede hacerlo. Le basta con usar por sí misme « Je passe la main » (auto-degr. T4). Efecto : paso inmediato a `inactive`, cortocircuito del plazo de espera. Políticamente, es coherente : el derecho P3 (auto-degradación) es incondicional.

**Une compañere en `suspended` a quien se quiere excluir definitivamente.** Ver §6.5 « Importante : suspensión vs retiro ». Hay que levantar la suspensión primero, luego solicitar el retiro.

**Alguien solicita su propio retiro mediante « Demander le retrait ».** El SIGB rechaza con un mensaje explícito : « Para abandonar el equipo, usa la opción "Je passe la main" (auto-degradación). » Es deliberado : confundir una decisión personal con una decisión colectiva enturbia la semántica política.

**Intento de degradar a une admin de red.** Rechazado sistemáticamente. El rol de admin de red solo puede ser modificado a través de los mecanismos específicos de la spec admin-reseau (cf. capítulo 8). Ningune coord locale puede destituir a une admin de red.

## 6.9. Si la regla te molesta

**El plazo de espera de 7 días te parece demasiado largo o demasiado corto.** A trasladar a `spec-gouvernance-roles.md`, §4.4 y §5.6.

**Consideras que la suspensión sin duración máxima es una puerta abierta al arbitrio.** Es un tema político serio. Se puede considerar añadir un plazo más allá del cual una suspensión deba convertirse en retiro o levantarse. A discutir en coordinación de red, luego a trasladar a la spec.

**Consideras que la obligación de razón en la suspensión es un exceso de burocracia.** O al contrario, consideras que el mínimo de 20 caracteres es demasiado corto. A trasladar a la spec.

**Consideras que la salida automática a los 9 meses es demasiado rápida o demasiado lenta.** El umbral es parametrizable, pero hoy es el mismo para todas las bibliotecas de la red. ¿Debería hacerse configurable por biblioteca? A discutir.

Ver capítulo 4 y anexo C para el procedimiento de enmienda.

\newpage

# 7. Cuando algo sale mal

Este capítulo trata las **situaciones excepcionales**, aquellas donde los mecanismos ordinarios de gobernanza no son suficientes, o bien funcionan pero requieren discernimiento político. Es también el capítulo donde se habla con franqueza de las **biblios que no tienen (o ya no tienen) vida colectiva deliberante**, porque el silencio sobre este tema haría más daño que la franqueza.

## 7.1. Biblio sin AG o con pocas personas miembras

El caso es más frecuente de lo que parece. Una biblio en sus comienzos, con dos o tres personas. Una biblio cuyo colectivo se fue reduciendo a medida que la gente se marchó. Una biblio cuya AG ya no se reúne desde hace un tiempo, por falta de gente o por desánimo.

El SIGB no se involucra en la vida política de un colectivo. Pero esta guía debe decir con franqueza qué cambia cuando esa vida colectiva es débil.

### Lo que cambia concretamente

**La palabra "cooptación" se vuelve ambigua.** Con dos personas, ¿quién coopta a quién? Si le únice coord desea incorporar a Voltairine al equipo, decide "sole" en el sentido político del término. El SIGB lo autorizará (une coord+ puede cooptar), pero ya no es la cooperación de un colectivo político, es una decisión personal disfrazada. No es ni malo ni bueno, simplemente hay que reconocerlo.

**Las deliberaciones son teóricas.** Una solicitud de baja a 7 días, en una biblio de 2 personas, no tiene nadie más para contradecirla que quien la solicitó. El "resguardo colegiado" se convierte en una auto-reflexión.

**El riesgo de personalización aumenta.** Cuando una decisión ya no es colectiva, depende del carácter, la disponibilidad y la lucidez de una o dos personas. No es catastrófico en sí mismo, pero es más frágil.

### Nuestras recomendaciones explícitas

**1. Reconoce la situación.** No finjas que sois un gran colectivo deliberante si sois dos. Políticamente, es más sano escribir "decisión tomada por mí sole, a validar cuando el colectivo crezca" en el campo "Razón" del audit log, que escribir "decisión AG" en una AG que no existe.

**2. Busca diálogo en el exterior.** Si estás sole o sois dos, y debe tomarse una decisión importante (cooptación, baja, suspensión), adquiere el hábito de comentarlo con compañeres de otras biblios de la red, o con une admin de red. No para pedirles autorización — no les corresponde validar las decisiones internas de tu biblio — sino para obtener una devolución crítica externa. La red Matrix de AnarBib existe para eso.

**3. Privilegia las transiciones reversibles.** Cuando tu colectivo es pequeño, evita en lo posible las decisiones irreversibles. Una suspensión es más reversible que una baja. Una baja tiene un plazo de 7 días durante los cuales puedes cambiar de opinión. Una cooptación es anulable. Date tiempo.

**4. Documenta lo que ocurre.** El campo "Razón" del audit log es tu mejor aliado. Cuanto más contexto pongas ("cooptación de Voltairine, decidida sole, a validar en la próxima permanencia"), más contextualizable será la decisión después, tanto para ti misme como para une nueve miembra del colectivo.

**5. Si estás realmente isolade, pide ayuda.** Una biblio de una sola persona está en peligro políticamente. El SIGB lo detecta en el momento en que le últ­ime coord se autoretrograda (§6.2) o abandona (§6.7), y alerta a les admins de red. También puedes tomar la iniciativa: envía un correo a la coordinación de red para explicar la situación. Varias biblios de la red han pasado por períodos de vacío y han recibido ayuda para reconstituirse.

### Lo que la guía no hace

No proporciona **ningún** procedimiento especial para las pequeñas biblios. Es deliberado. Las reglas del SIGB se aplican de manera uniforme — lo que cambia son las condiciones políticas en las que se aplican. Reconocer este matiz forma parte de la madurez política de une coord.

## 7.2. Conflicto interpersonal en una coordinación

Estalla un conflicto entre dos personas del staff. El trabajo ya no funciona correctamente, el ambiente se deteriora, les lectores perciben la tensión.

### Lo que el SIGB puede hacer

Poco, directamente. El SIGB no arbitra conflictos. Pero proporciona **herramientas utilizables**:

- **Suspensión provisional (T6)** de una o las dos personas, mientras el conflicto sea mediado. Es lo que la spec llama explícitamente "conflicto en proceso de mediación" como caso de uso legítimo de la suspensión.
- **Auto-retrogradación (T3/T4)** — si una de las dos personas elige tomar distancia, es inmediato.
- **Audit log legible por todo el staff** — permite al conjunto del staff ver quién hizo qué, y evitar las manipulaciones opacas de une coord que buscara resolver el conflicto sacando a la otra persona de forma disimulada.

### Lo que el colectivo debe hacer

- **Mediación**. El SIGB no media. Hace falta una persona tercera de confianza, ajena al conflicto. Según las configuraciones: otre coord de la biblio, une compañere de otra biblio, une admin de red.
- **Decisión colectiva**. Si la mediación lleva a una decisión (una de las dos personas abandona la coordinación, o se define un marco de trabajo revisado), el SIGB ejecutará esa decisión a través de los RPCs normales.
- **Rastro político**. Si la decisión es dar de baja a alguien, el campo "Razón" debería mencionar el proceso de mediación ("baja tras mediación del DD/MM, decisión colectiva") para no reescribir la historia más adelante.

### Lo que hay que evitar

- **Usar una suspensión como arma** en el conflicto. La suspensión sirve para pausar, no para ganar una relación de fuerza. Si une coord suspende a otre sin proceso de mediación, es observable en el audit log, y es políticamente problemático.
- **Cortocircuitar la carencia** mediante maniobras técnicas (suspender y luego "acelerar" por otros medios). Todo queda trazado, y la red se dará cuenta.
- **Guardar silencio sobre el audit log**. Todo el staff ve lo que ocurre (P5). Si intentas ocultar el conflicto, traicionas la transparencia del colectivo.

## 7.3. Acoso denunciado

Une lectore denuncia que une miembra del staff tiene un comportamiento abusivo (acoso sexual, abuso de poder, comportamiento racista, etc.).

### Proceso recomendado

**1. Tomar la denuncia en serio**, de inmediato, aunque la persona denunciante esté isolada y aunque la persona denunciada sea "conocida y apreciada" por la coordinación. El reflejo de descartar la denuncia como "probablemente exagerada" es el error más habitual.

**2. Suspensión inmediata (T6)** de la persona denunciada, **con carácter cautelar**, a la espera de la investigación. El campo "Razón" debería decir algo como "Suspensión cautelar tras denuncia recibida el DD/MM, a la espera de investigación colectiva". La suspensión **no** es una acusación, es una pausa.

**3. Constituir un grupo de investigación**. Fuera del software. Como mínimo: compañeres ajenes a la situación de poder directa, capaces de escuchar los dos lados sin sesgos. Este grupo puede incluir compañeres de otras biblios si la biblio es pequeña o si todes les coords están implicades en el asunto.

**4. Comunicarse con la persona denunciante**. Necesita saber que se le toma en serio, y que se están tomando medidas. No dejarla en la incertidumbre.

**5. Llegar a una decisión**. Según lo que revele la investigación:
   - Levantamiento de la suspensión (T7) si la denuncia no se confirma.
   - Baja definitiva (T5 con carencia) si la denuncia se confirma y la decisión es dar de baja a la persona.
   - Sanción intermedia (marco de trabajo revisado, formación, alejamiento de ciertas funciones) si la situación es más matizada.

**6. Trazar políticamente**. El campo "Razón" en el audit log debería reflejar la decisión colectiva. Sin detalles sobre la víctima (RGPD), pero con una formulación que haga legible la decisión.

### Lo que no hay que hacer

- **Solicitar una baja directamente** sin suspensión previa, cuando la situación es urgente. Durante 7 días la persona denunciada conservaría sus derechos, lo que es contradictorio con la urgencia de una denuncia de abuso.
- **Suspender indefinidamente sin decisión** con el pretexto de que "no conseguimos resolver el asunto". Una suspensión que dura varios meses sin decisión se convierte ella misma en una violencia (hacia la persona suspendida, que no puede defenderse, y hacia la persona denunciante, que no recibe respuesta).
- **Resolver internamente sin la red**. Si sois una biblio pequeña y la situación os supera, pedid ayuda a les admins de red. No estáis soles.

## 7.4. Cuenta comprometida

Une miembra del staff constata que su cuenta ha sido comprometida (contraseña filtrada, sospecha de acceso no autorizado).

### Procedimiento inmediato

**1. Suspensión inmediata (T6)** de la cuenta, con razón explícita: "Sospecha de compromiso, contraseña probablemente filtrada, verificación en curso".

**2. Comunicación con la persona afectada**. La persona recibe automáticamente un correo urgente indicando la suspensión e invitándola a cambiar su contraseña. Le coord que suspende debería también contactar directamente (teléfono, otro canal seguro) para confirmar.

**3. Investigación rápida.** ¿Qué ocurrió? ¿La cuenta realizó acciones inusuales en el audit log (cooptaciones extrañas, modificaciones de configuración, etc.)? En caso afirmativo, avisar de inmediato a une admin de red para ayudar a analizar.

**4. Levantamiento de la suspensión (T7)** una vez que:
   - La contraseña ha sido cambiada.
   - El eventual daño ha sido constatado y reparado (anulación de las acciones abusivas, restauración de datos, etc.).
   - La persona está segura digitalmente.

### Políticamente

Una suspensión por cuenta comprometida **no es una reprimenda**. Es una protección mutua: se protege a la persona (impidiendo que sea utilizada por une atacante) y a la biblio (impidiendo que se causen daños en su nombre). El correo a la persona debería insistir en este carácter **no disciplinario**.

## 7.5. Biblio sin coord ni librarian actives

El escenario catastrófico: ningune miembra del staff active. Esto puede ocurrir por salida automática acumulada (todes les miembros del staff han abandonado sus cuentas simultáneamente), por dimisión colectiva (raro pero posible), o por sucesión de bajas.

### Consecuencias

- La biblio sigue **técnicamente activa** (su visibilidad, su catálogo siguen accesibles según las RLS habituales).
- Pero **ninguna acción de gestión** puede realizarse ya a través de la UI normal: sin validación de inscripciones, sin gestión de préstamos, sin modificación de la configuración.
- **Correo urgente a les admins de red** por el cron que detecta la situación.

### Procedimiento de reinicio

Fuera de spec, pero así es como se practica:

**1. Toma de contacto** por parte de une admin de red con el colectivo local, por todos los canales disponibles (la cuenta o cuentas de lectores que siguen inscrites, los datos de contacto externos de la biblio si existen, la red de conocides locales).

**2. Verificación política**: ¿existe todavía el colectivo? ¿Quiere seguir existiendo? Si hay miembros pero han dejado caer simplemente las funciones técnicas, se puede recooptar nuevo staff por cooptación fuera del flujo habitual.

**3. Cooptación fuera del flujo** por parte de le admin de red, vía SQL directo o vía la UI (une admin de red tiene derecho a actuar como coord+ en cualquier biblio, cf. capítulo 2). La cooptación fuera del flujo debe quedar trazada en el audit log con una razón explícita: "Reanudación de la coordinación tras vacancia, tras contacto del colectivo del DD/MM, por admin de red X". Y — punto clave de doctrina — **información previa a la coordinación local obligatoria**, salvo si la biblio ya no tiene ningune miembra del staff vive, en cuyo caso la información llega a través de les `reader` actives restantes (cf. §7.6).

**4. Si el colectivo ya no existe**: apertura de una discusión sobre el **cierre ordenado** de la biblio. Qué datos conservar, cuáles suprimir, cómo comunicarlo a les lectores, etc. Es un flujo a formalizar por separado.

## 7.6. La intervención de une admin de red en una biblio local

Un caso que ya se aborda en el capítulo 2, pero que merece un desarrollo práctico en este capítulo de situaciones excepcionales.

### La doctrina de la red

> **Una intervención de admin de red en una biblio local debe ir precedida de una comunicación a la coordinación local concernida, salvo urgencia vital.**

La información previa **no es una solicitud de autorización**. Le admin de red tiene derecho a actuar (ese es el sentido del derecho transversal). Pero es una muestra de respeto hacia la autonomía local, y preserva la posibilidad de otro arreglo.

### Qué es una "urgencia vital"

Es deliberadamente restrictivo. Casos tipo:

- **Compromiso activo**: una acción en curso amenaza la integridad de la biblio o de la red (cuenta atacante que modifica memberships en tiempo real, etc.).
- **Acoso en curso**: une miembra del staff abusa activamente de sus funciones, el peligro para les lectores es inmediato.
- **Ataque contra la plataforma**: intento de intrusión, exfiltración de datos, etc.

Fuera de estos casos, **se toma el tiempo de informar**.

### Cómo informar

Antes de la intervención (o durante, si la urgencia lo justifica a posteriori):

- **Correo a la coordinación local** explicando qué se va a hacer, por qué, y con qué trazabilidad.
- **Mención en la tabla `cross_library_actions_log`** con un nivel de criticidad que indique la naturaleza de la acción. Todes les coords actives de la biblio reciben una notificación.
- **Disponibilidad para el diálogo**: la coordinación local debe poder hacer preguntas, pedir aclaraciones, e incluso negociar un arreglo distinto ("dejadnos intentarlo primero").

### Lo que hay que evitar

- **La intervención silenciosa**: actuar sobre la biblio sin informar a la coordinación. Aunque técnicamente quede trazado, políticamente es una violación de la soberanía local.
- **El uso del derecho transversal como poder de vigilancia**: ir a ver "lo que ocurre" en una biblio sin razón operacional. El derecho transversal existe para casos de mantenimiento o mediación, no por curiosidad.
- **La imposición de decisiones políticas**: une admin de red no puede decirle a una biblio cómo hacer sus cooptaciones, cómo gestionar sus conflictos internos, o qué política de acogida elegir. El derecho transversal es técnico, no político.

## 7.7. Si la regla te molesta

**Encuentras que la doctrina de información previa es demasiado laxa** (une admin de red podría abusar de la "urgencia vital"). A debatir: ¿hace falta una definición más estricta de la urgencia? ¿Hace falta une segunde admin de red que confirme la urgencia?

**Encuentras la doctrina demasiado estricta** (a veces hay que actuar rápido sin explicar todo). A debatir: ¿hace falta distinguir varios niveles de intervención, con reglas de información diferentes según la criticidad?

**Encuentras que el silencio sobre el cierre ordenado de una biblio es problemático** (§7.5). Tienes razón. Probablemente haya que escribir una spec dedicada. A llevar a la red.

**Encuentras que este capítulo deja demasiado espacio a la improvisación** en los casos de acoso (§7.3). Es probable que sea cierto. Una spec dedicada sobre los procesos de mediación e investigación podría ser beneficiosa. A llevar a la red.

Ver capítulo 4 y anexo C.

\newpage

# 8. El rol de administradore de red

Este capítulo se dirige específicamente a les administradore de red (actuales o futures), y a las coordinaciones locales que quieren entender cómo la red se auto-organiza a nivel superior. Completa y profundiza los capítulos 2 y 7.

## 8.1. Una función política diferenciada

Ante todo: ser **admin de red** no es un grado, ni una consagración, ni un título. Es una **función transversal** que el colectivo de les admins de red delega a algunes de sus miembros, sobre la base de un acuerdo unánime de les admins ya en funciones, y que puede abandonarse en cualquier momento.

El proyecto político de la función es **hacer vivir la coordinación inter-biblios**: acoger las nuevas biblios que se unen a la red, animar las discusiones sobre las evoluciones técnicas y políticas del SIGB, mantener la plataforma técnicamente, intervenir cuando una biblio se encuentra en un bloqueo. No es una función de dirección. Es una función de animación y de servicio.

### Lo que une admin de red puede hacer (políticamente)

- Activar una nueva biblio que ha presentado su solicitud de inscripción a la red.
- Animar las discusiones inter-biblios (el canal Matrix `#anarbib`, los encuentros, las listas de correo internas).
- Coordinar las evoluciones de la plataforma (specs, releases, comunicaciones).
- Intervenir en cualquier biblio en caso de bloqueo técnico (derecho transversal).
- Mediar entre dos biblios en caso de conflicto (si las coordinaciones lo desean).
- Proponer o votar sobre la cooptación y el retiro colectivo de otres admins de red.

### Lo que une admin de red no puede hacer (políticamente)

- Dirigir una biblio.
- Imponer una decisión política a una biblio (política de acogida, modo de validación, cooptaciones internas, etc.).
- Expulsar a une coordinadore locale contra la voluntad de su biblio.
- Modificar sole las reglas de la red (esto pasa por una discusión colectiva de les admins e idealmente de las coordinaciones).

## 8.2. La cooptación por unanimidad: por qué

Le admin de red no se agrega por mayoría, sino por **unanimidad** de les admins en funciones. Esta regla puede sorprender — ¿por qué no una mayoría simple, una mayoría calificada, o un quórum?

La razón política es simple: el poder de une admin de red es **transversal**. Puede intervenir en cualquier biblio. Es necesario entonces que **cada admin de red actualmente active** esté dispeste a trabajar con la nueva persona. Si hay un solo desacuerdo profundo, la cooperación quedará envenenada — es preferible no imponerla.

Esta regla tiene una consecuencia práctica importante: **el veto es fácil**. Un solo voto `opposed` es suficiente. Es voluntario. Se prefiere que una cooptación no prospere antes que dejar a une admin existente en una posición incómoda de manera duradera.

## 8.3. Workflow de cooptación, en detalle

### Etapa 1 — Propuesta

Une admin de red active, desde la interfaz `/rede/administradores` (por llegar en el paquete D), hace clic en **« Proponer una cooptación »**.

- Introduce la identidad de la persona propuesta (busca en la base de usuaries AnarBib).
- Introduce una **motivación** obligatoria de **mínimo 20 caracteres**. Esta motivación es legible por todes les admins, y — en caso de éxito — será incluida en la notificación a la persona cooptada.
- Confirma.

El SIGB:
- Crea una fila en `network_administrator_cooptation_proposals` con `status='open'`, `expires_at = now() + 30 días`.
- Registra automáticamente el voto `favorable` de quien propone.
- Envía un correo militante a todes les otres admins actives invitándoles a votar.

### Etapa 2 — Votos

Cada otre admin active tiene 30 días para votar. Tres opciones:

- **`favorable`**: acepta la cooptación.
- **`opposed`**: ejerce su veto. **Justificación obligatoria** de mínimo 20 caracteres. Esta justificación será comunicada a la persona propuesta y a quien propuso en caso de rechazo.
- **`abstain`**: se abstiene. **La abstención bloquea**: la propuesta solo prospera con la unanimidad de los votos `favorable`. Una abstención no levantada tiene el mismo efecto práctico que un veto, salvo que puede convertirse en favorable más adelante si la persona cambia de opinión.

### Detalle v0.3 — Divulgación de identidad

Una opción **« Revelar mi identidad en caso de rechazo »** está marcada por defecto. Si votas `opposed`, tu identidad será comunicada a la persona propuesta y a quien propuso, además de tu justificación.

Puedes **desmarcar** esta opción para permanecer anonime. En ese caso, la justificación será transmitida sin tu nombre (« une oponente señaló: ... »).

Políticamente, la **transparencia por defecto** corresponde a la cultura militante de asumir las posiciones. Pero el anonimato sigue siendo posible para los casos en que una oposición expondría a le oponente a un coste personal desproporcionado.

### Recordatorios automáticos

El cron envía recordatorios a les admins que aún no han votado:
- **D+14 días**: « Todavía no has votado sobre la cooptación de X. »
- **D+25 días**: « Esta propuesta vence en 5 días, toma posición. »

### Etapa 3 — Conclusión

**Si alguien vota `opposed`**: la propuesta pasa inmediatamente a `status='rejected'`. La persona propuesta y quien propuso reciben un correo explicando el rechazo, con la justificación (y la identidad de le oponente si aceptó la divulgación).

**Si todes les admins actives han votado `favorable`**: la propuesta pasa a `status='completed'`. Se inserta automáticamente una fila en `network_administrators` con `status='active'` y `coopted_by_unanimity_of = ARRAY[<lista de votantes>]`. La persona recibe un correo de bienvenida y se envía un resumen a todes les admins.

**Si transcurren 30 días sin llegar a un consenso**: la propuesta pasa a `status='expired'`. No hay cooptación. Hay que o bien comenzar una nueva propuesta, o bien considerar que la red no está lista para acoger a esta persona por el momento.

## 8.4. El retiro colectivo por unanimidad

El **retiro colectivo** es el espejo de la cooptación: para retirar a une admin de red contra su voluntad, se necesita la unanimidad de les otres admins actives.

### Workflow

1. **Propuesta de retiro** por parte de une admin de red active, motivación obligatoria ≥ 20 caracteres.
2. **Votos** de les otres admins (favorable / opposed / abstain), con justificaciones si `opposed`.
3. **Si unanimidad `favorable`**: la membresía de la persona visada pasa a `pending_removal`, con `pending_collective_removal_until = now() + 7 días`.
4. **Durante los 7 días de carencia**: la persona visada conserva sus derechos operacionales, pero recibe un correo claro sobre su salida programada. Puede eventualmente iniciar una última discusión. **No puede anular el retiro unilateralmente**: solo la unanimidad de les otres admins puede dar marcha atrás (proponiendo una « anulación de retiro », workflow espejo).
5. **En D+7**: paso a `status='removed'`, `removed_at=now()`.

### Políticamente

El **doble cerrojo** (unanimidad + carencia 7 días) hace que el retiro colectivo de une admin de red sea particularmente difícil. Es intencional. El poder de une admin de red siendo transversal, no se revoca a la ligera.

Inversamente, **el auto-retiro siempre es posible y fácil** (cf. §8.5). Aquí reside la disimetría política: es simple partir, es difícil ser expulsade. Esto corresponde a la cultura anarquista: se respeta la decisión personal de abandonar una función, se encuadra firmemente la decisión colectiva de retirarla.

## 8.5. Auto-retiro

Une admin de red puede abandonar sus funciones en cualquier momento, sin el acuerdo de les demás. Es un acto **unilateral e incondicional** (P3 aplicado al nivel de la red).

### Procedimiento

Desde `/rede/administradores`, en su propia fila, hacer clic en **« Abandonar mis funciones de admin de red »**. Modal de confirmación, razón opcional.

### Efecto

- La fila pasa a `status='inactive'` (o `removed` según el contexto, a precisar en el paquete D).
- Correo a todes les otres admins actives.
- Audit log `event_type='self_removal_requested'`.

### Caso especial: le únique admin active

Si eres le únique admin active y quieres partir, el SIGB activa una **carencia especial de 30 días**. Durante este período:
- Permaneces como admin active con todos tus derechos.
- Se envía un correo urgente a todes les antiguos admins (`status='inactive'` o `removed`) indicándoles la situación.
- La red tiene 30 días para o bien recooptar a une nueve admin (workflow normal de cooptación, siendo tú le únique votante), o bien organizar una transición diferente.

En D+30, si no se ha hecho nada, saldrás efectivamente y la red quedará **sin admin active**. El SIGB seguirá funcionando técnicamente, pero ninguna acción de admin (activación de biblio, cooptación, etc.) será posible hasta una intervención manual.

Este procedimiento está diseñado para **ralentizar** la disolución de la red en caso de que le últime admin partiera, sin **impedir** esa salida. La libertad de partir permanece íntegra.

## 8.6. El derecho transversal en el día a día

El **derecho transversal** es lo que distingue políticamente a le admin de red del staff local: puede actuar como `coord+` en cualquier biblio, leer su catálogo (incluso si la visibilidad es `private`), modificar sus membresías, etc.

### Cuándo utilizarlo

- **Activación de una nueva biblio**: workflow normal, es el caso de uso primero del derecho transversal.
- **Mantenimiento**: una biblio tiene una configuración rota, un parámetro mal configurado, un bug bloqueante. Puedes intervenir para corregir.
- **Bloqueo político**: la biblio ya no tiene coordinadore (cf. §7.5), hay que recooptar para reiniciar.
- **Mediación a demanda**: la coordinación local te solicita explícitamente para ayudar a arbitrar un conflicto o tomar una decisión difícil.
- **Investigación tras una denuncia en la red**: une lectore denuncia un problema grave en una biblio, y la coordinación local no responde o es ella misma parte del problema.

### Cuándo no utilizarlo

- **Por curiosidad**: no ir a « ver qué pasa » en una biblio sin motivo operacional. Eso es vigilancia, no administración.
- **Para imponer una decisión política**: si no estás de acuerdo con la política de una biblio (modo de validación, reglamento, etc.), puedes discutirlo, pero no imponerlo.
- **Para cortocircuitar un debate colectivo**: si la red discute una evolución y no estás de acuerdo, no puedes usar tu derecho transversal para imponer tu visión por hechos consumados.

### Información previa obligatoria

Es la doctrina de la red (capítulo 2, §2.4; capítulo 7, §7.6): **toda intervención de admin de red en una biblio local debe estar precedida de una información a la coordinación local**, salvo en caso de urgencia vital.

Concretamente:
- **Correo a la coordinación local** explicando qué se hará y por qué.
- **Espera de una respuesta** salvo urgencia: 24 a 72 horas según la naturaleza de la acción.
- **Si no hay respuesta y la acción no es urgente**: relanzar una vez, y proceder explicitando en el log que la coordinación local fue informada pero no respondió.
- **Si urgencia vital**: actuar, y enviar la información inmediatamente después explicando por qué la urgencia justificó la acción sin espera.

Cada acción queda registrada en `cross_library_actions_log` con nivel de criticidad, legible por la coordinación local a posteriori.

## 8.7. El caso del primer admin y de Xavier

El sistema supone al menos une admin de red active para que la cooptación sea posible. Le **primer admin** no pudiendo ser cooptade (no hay nadie para votar), se prevé una excepción.

El 11 de mayo de 2026, **Xavier** está inscrite como **admin de red fundadore** por INSERT directo en `network_administrators`, con `coopted_by_unanimity_of = ARRAY[]::uuid[]` (tabla vacía) y `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. Esta manipulación queda registrada en el audit log con `event_type='foundational_admin_added'` y `metadata.foundational=true`.

Esta manipulación es **transparente políticamente**: está documentada, explicada y es pública. No es una debilidad del sistema — es el arranque indispensable. Una vez sentada esta base, toda cooptación ulterior pasa por el workflow normal del §8.3.

A medida que se vayan cooptando nuevos admins, la « soledad » inicial se irá borrando. La red tiene vocación de tener **varias admins actives** (el objetivo político es generalmente un círculo de 3 a 5 personas, en número impar para evitar bloqueos en caso de votación sobre ciertos asuntos conexos fuera de spec).

## 8.8. Si la regla te incomoda

**Encuentras la unanimidad demasiado exigente** (« nunca se llega a cooptar, un veto lo bloquea todo »). Es un debate de fondo sobre la naturaleza del colectivo de les admins de red. ¿Hay que flexibilizarlo hacia una mayoría calificada? ¿Hace falta un mecanismo de supervoto? A llevar en discusión en la red, y posiblemente a formalizar en una revisión de la spec.

**Encuentras la unanimidad demasiado laxa** (« habría que consultar también a las coordinaciones locales antes de cooptar a une admin »). Es otra opción política: consultar a las coordinaciones locales antes de la cooptación de une admin de red. A discutir. Eso ampliaría el círculo decisor pero agrabaría el procedimiento.

**Encuentras que la carencia de 7 días para el retiro colectivo es demasiado larga o demasiado corta.** A llevar a la spec.

**Encuentras que la doctrina de información previa está insuficientemente encuadrada**: ¿qué es exactamente una « urgencia vital »? ¿Debe existir una definición canónica? A discutir.

**Encuentras que la función de admin de red tiene demasiado poder** (derecho transversal demasiado extenso) o no suficiente (debería poder zanjar ciertos conflictos). Es una pregunta política fundamental. A discutir en el encuentro anual.

Ver capítulo 4 y anexo C.

\newpage

# 9. La transparencia en la práctica

Este capítulo trata del funcionamiento concreto de la **transparencia** en AnarBib: quién ve qué, cómo y por qué. Es la aplicación del principio P5 (transparencia máxima) y de P6 (notificaciones sistemáticas).

## 9.1. El principio

> **P5 — Transparencia máxima.** El audit log de los cambios de rol es legible por todo el staff activo de la biblio.
> **P6 — Notificaciones sistemáticas.** Todo cambio de rol desencadena un correo a la persona concernida y a toda la coordinación.

La idea política: **hacer imposibles las manipulaciones opacas**. Si todo está registrado y es legible, no se puede pasar en silencio a una persona de un estatus a otro sin que lo vean les demás miembros del staff.

## 9.2. Quién ve qué: matriz

### A nivel de una biblio

| Información | reader | librarian | coordenador | admin de red |
|---|---|---|---|---|
| Lista del equipo (roles activos) | parcial (solo los nombres públicos) | completa | completa | completa |
| Estatus (`suspended`, `pending_removal`) | no | sí | sí | sí |
| Audit log completo del equipo | no | sí | sí | sí |
| Audit log: razones de las acciones | no | sí | sí | sí |
| Solicitud de retiro en curso: quién solicitó | no | sí | sí | sí |
| Datos personales de les otres lectores | no | sí (de esta biblio) | sí | sí |

### A nivel de la red

| Información | reader | staff biblio | admin de red |
|---|---|---|---|
| Lista de les admins de red actives | sí (página pública `/rede`) | sí | sí |
| Contadores de la red (número de biblios, etc.) | sí | sí | sí |
| Audit log de la red (cooptaciones, retiros de admins) | no | no | sí |
| Propuestas de cooptación en curso | no | no | sí |
| Logs cross-biblios (acciones de admin de red en biblio X) | no | sí (de su biblio) | sí |

## 9.3. El audit log de equipo en la práctica

Es la herramienta de transparencia más importante. Es consultable desde `/biblioteca` → pestaña **Equipo** → sección **Historial del equipo**.

### Qué se ve

Cada entrada muestra:
- Fecha y hora.
- Acción (« promovide a librarian », « auto-retrogradade », « retiro solicitado », « suspendide », « reintegrade tras suspensión », « paso automático a inactive tras 9 meses », etc.).
- Persona concernida (target).
- Autore de la acción (actor) — para las acciones humanas. Vacío para las acciones automáticas (cron).
- Razón (si fue indicada).
- Rol y estatus antes/después.

### Para qué sirve políticamente

- **Memoria colectiva**: se puede reconstituir la historia de la coordinación, ver cómo se constituyó y evolucionó.
- **Guardabosques contra la opacidad**: si une coordinadore ha realizado acciones dudosas (cooptaciones extrañas, suspensiones injustificadas), es visible para todes.
- **Herramienta de deliberación**: en caso de debate (« ¡habíamos dicho que haríamos rotar les coords! »), el log da elementos factuales.
- **Herramienta de transición**: cuando llega une nueve coordinadore, puede leer el log para entender la historia reciente sin tener que interrogar a todo el mundo.

### Qué hacer con él

- **Leerlo regularmente**. No todos los días, pero una vez al mes, durante una reunión de coordinación por ejemplo.
- **Discutir lo que resulta extraño**. Si una acción te parece incomprensible o injustificada, pregunta a su autore.
- **No usarlo como arma**. El log es una herramienta de transparencia colectiva, no un instrumento de vigilancia interpersonal.

## 9.4. Los correos de notificación

Cada acción de gobernanza desencadena **uno o varios correos** automáticos. No es spam: es voluntario, porque nadie debe verse afectade por un cambio de rol sin ser informade.

### Quién recibe qué

| Evento | Persona concernida | Coordinadores locales actives | Admins de red |
|---|---|---|---|
| Cooptación (T1, T2) | ✅ | ✅ | — |
| Auto-retrogradación (T3, T4) | ✅ confirmación | ✅ | — |
| Solicitud de retiro (T5) | ✅ | ✅ | — |
| Anulación de solicitud (T8) | ✅ | ✅ | — |
| Fin de carencia (D+7) | ✅ | ✅ | — |
| Suspensión (T6) | ✅ urgente | ✅ | — |
| Levantamiento de suspensión (T7) | ✅ | ✅ | — |
| Salida automática a 9 meses (T9) | ✅ recordatorios + final | ✅ (solo final) | — |
| Le últime coordinadore parte | ✅ | ✅ (le concernide) | ✅ alerta |
| Cooptación admin de red (propuesta) | — | — | ✅ |
| Cooptación admin de red (éxito) | ✅ bienvenida | — | ✅ resumen |
| Cooptación admin de red (rechazo) | ✅ con justificación | — | ✅ |
| Retiro colectivo admin de red | ✅ | — | ✅ |
| Intervención cross-biblios | — | ✅ (coords de la biblio) | ✅ (le autore) |

### El tono de los correos

Los correos de gobernanza siguen las convenciones militantes de la red (cf. memoria interna): sobriedad, claridad, accesibilidad (lengua común sin jerga), formulación inclusiva y escritura desacralizada. Sin fórmulas oficiales, sin firmas burocráticas.

Ejemplo tipo para una solicitud de retiro:
> Hola Karl,
>
> La coordinación de la BLMF ha solicitado tu retiro del equipo (rol: librarian), como resultado de: « decisión AG del 04/05 ».
>
> Este preaviso tendrá efecto el **12 de mayo de 2026** (en 7 días), salvo anulación por parte de otre coordinadore de aquí a entonces.
>
> Durante este período, ya no tienes acceso a las funciones de librarian. Para cualquier discusión, dirígete a la coordinación de la BLMF — esta decisión pertenece a la vida orgánica del colectivo local y no se gestiona a través del SIGB.
>
> AnarBib

El tono apunta a informar factualmente sin dramatizar ni minimizar.

### Confidencialidad de los correos — guardabosques anti-rastreo

Los correos de gobernanza, como todas las notificaciones del SIGB, son expedidos a través de **Resend**, el subcontratista de envío de la red (cf. registro de tratamientos y DPA). Dos garantías políticas enmarcan este envío:

- **Ningún rastreo.** El seguimiento de aperturas y clics — que recogería la dirección IP, la localización, el dispositivo y el cliente de correo de la persona destinataria — es una opción **desactivada** en la instancia AnarBib. Recibir un correo de gobernanza no deja ninguna huella técnica en el lado de la red.
- **Minimización.** Solo los datos estrictamente necesarios para el envío transitan (dirección de correo, nombre para la personalización, contenido de la notificación). Ningún dato sensible es transmitido.

Este guardabosques es doctrinal: prolonga el compromiso de no-rastreo de la red hasta la capa de correo. Está documentado en el registro de tratamientos (art. 30 RGPD) y en el DPA; todo cambio de subcontratista de correo se notifica a las bibliotecas adherentes (DPA art. 5.4).

## 9.5. El caso de las notificaciones « cross-biblios »

Cuando une admin de red interviene en una biblio (cf. §8.6), se producen dos notificaciones:

- **Notificación previa** (manual): le admin envía un correo a la coordinación local antes de actuar. Formato libre.
- **Notificación automática** (por el SIGB): en la ejecución de la acción, el sistema escribe en `cross_library_actions_log` con nivel de criticidad, y envía un correo a les coordinadores actives de la biblio concernida.

Esta doble notificación (manual + automática) garantiza que la coordinación local sea avisada **antes** políticamente y **después** técnicamente. La traza técnica es legible a posteriori en la pestaña **Equipo** → sección **Intervenciones de la red** (por llegar en el paquete D).

## 9.6. Límites de la transparencia

La transparencia de AnarBib tiene límites que hay que explicitar:

**Les `reader` no ven el audit log del equipo.** Es voluntario (P5 habla de « staff activo »). Les `reader` no ven quién cooptó a quién, quién fue suspendide, etc. La transparencia actúa **dentro de la coordinación**, no hacia les usuaries.

**Una biblio no ve el audit log de otra biblio.** Soberanía local (P7). Los cambios de rol en la biblio A son estrictamente opacos para la biblio B, salvo por el canal humano (discusión entre coordinadores de las dos biblios).

**El audit log de la red (cooptaciones y retiros de admins) no es público.** Legible solo por les admins de red. Una biblio local puede ver la lista de les admins de red actuales (página `/rede`), pero no el historial de las cooptaciones ni las justificaciones de los votos contrarios.

Estos límites no son hipocresías. Corresponden a un equilibrio entre **transparencia** (dentro del staff deliberante) y **confidencialidad** (respecto de les usuaries y entre perímetros). Si encuentras el equilibrio mal situado, es enmendable (capítulo 4).

## 9.7. Si la regla te incomoda

**Piensas que les `reader` deberían ver el audit log del equipo** (transparencia radical hacia les usuaries). Es una posición defendible, pero tiene consecuencias (los conflictos internos se vuelven públicos, la vida política del colectivo queda expuesta). A discutir en la red.

**Piensas a la inversa que el audit log es demasiado visible** (une librarian discretx no debería poder « espiar » las acciones de les coordinadores). También es defendible. Pero contradice P5. A discutir.

**Encuentras los correos demasiado numerosos o no suficientemente explícitos.** El contenido está parametrizado en `mail-strings.ts` × 10 locales. Toda modificación de un correo es enmendable como una modificación de código. A llevar con les dev.

**Piensas que el audit log de la red debería ser público al menos para les coordinadores locales** (para que puedan ver quién decide qué a nivel de la red). Es una opción interesante. A discutir.

Ver capítulo 4 y anexo C.

\newpage

# 10. Casos concretos comentados

Para terminar, seis escenarios completos. Cada uno ilustra una combinación de mecanismos y permite ver el SIGB en acción. Los nombres (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) son los de compañeres históricos del pensamiento libertario; aquí sirven como casos tipo ficticios.

## 10.1. Voltairine es cooptada librarian

> **Contexto.** Emma es coordenadora en la BLMF. Voltairine lleva ocho meses viniendo a las permanencias, participa en la vida de la biblio, y tiene claramente el perfil para unirse al equipo. Le colectivo local lo discutió en AG el 4 de mayo y aprobó su cooptación.

**Procedimiento.**

1. Emma se conecta el 5 de mayo a las 14:30. Va a `/biblioteca`, pestaña **Equipo**.
2. Busca a Voltairine en la lista de `reader` de la biblio (tiene una cuenta AnarBib desde febrero).
3. Hace clic en **« Invitar al equipo »** → elige **librarian**.
4. Campo « Razón »: « decisión AG del 04/05 » (doctrina 1, espera estricta).
5. Confirma.

**Efecto inmediato.**

- Voltairine recibe un mail: « Hola Voltairine, has sido nombrada librarian de la BLMF por Emma G. como consecuencia de: "decisión AG del 04/05". Tus nuevos derechos están activos. Bienvenida al equipo. »
- Las demás coordinadoras activas de la BLMF (Lucy y Piotr) reciben un mail informativo.
- Audit log: `2026-05-05 14:30 — Emma G. promovió a Voltairine d.C. librarian (razón: decisión AG del 04/05)`.

**Comentario.**

Caso más simple. El SIGB ejecuta correctamente la decisión de le colectivo. Emma no decidió nada políticamente — hizo clic para ejecutar lo que se decidió fuera del software.

**Lo que el SIGB no hizo:** verificar que la AG realmente tuvo lugar, que la decisión fue realmente tomada, que Voltairine está realmente de acuerdo. Estas cosas están **fuera del software**. Si Emma hubiera mentido sobre la AG, el SIGB no habría visto nada. La cultura política de la BLMF es lo que impide esa mentira (y el log la hace rastreable a posteriori).

## 10.2. Lucy pasa la posta

> **Contexto.** Lucy es coordenadora en la BLMF, pero no puede asumir la carga este semestre (empieza una tesis). Desea « volver a ser librarian » para seguir en el equipo pero aligerar sus responsabilidades.

**Procedimiento.**

1. Lucy va a `/biblioteca`, pestaña **Equipo**.
2. En su propia línea (estado `coordenador`), hace clic en **« Paso la posta »**.
3. Elección: « volver a librarian ».
4. La ventana de confirmación recuerda que perderá los permisos de coordinación de inmediato.
5. Lucy confirma. Razón opcional: « inicio de tesis, reducción temporal ».

**Efecto inmediato.**

- Su membership `coordenador` pasa a `inactive`.
- Su membership `librarian` (que existía en paralelo) permanece `active`.
- Lucy recibe un mail de confirmación: « Ahora eres librarian de la BLMF. Conservas tus permisos operacionales. »
- Tode la coordinación (Emma, Piotr) recibe un mail: « Lucy P. pasó la posta, ya no es coordinadora. Permanece librarian del equipo. »
- Audit log: `2026-05-05 18:42 — Lucy P. se auto-degradó coordenador → librarian (razón: inicio de tesis, reducción temporal)`.

**Comentario.**

Es el uso ejemplar del derecho P3. Lucy no tuvo que pedir autorización a nadie. Su auto-degradación es inmediata. Sigue contribuyendo a la biblio, pero con una intensidad ajustada a su disponibilidad actual.

**Políticamente**: es exactamente el tipo de rotación que se busca favorecer. No se pierde a Lucy, simplemente asume otro rol. En seis meses o un año, si quiere retomar la coordinación, le colectivo podrá recooptarla (T2). Ninguna decisión es definitiva.

## 10.3. Karl tiene que irse

> **Contexto.** Karl es librarian en la BLMF. Su comportamiento con algunes lectores ha generado problemas (paternalismo, comentarios inapropiados). Le colectivo lo discutió en AG el 4 de mayo y decidió que debía abandonar el equipo.

**Procedimiento.**

1. Piotr (coord) — elegide por la AG para ejecutar la decisión — va a `/biblioteca`, pestaña **Equipo**.
2. En la línea de Karl, hace clic en **« Solicitar la baja »**.
3. Ventana roja con plazo de 7 días explícito.
4. Razón obligatoria: « Tras la AG del 04/05, comportamiento inadecuado con varias lectores señalado durante varios meses, decisión colectiva de exclusión. »
5. Confirmación explícita: « Entiendo que esta solicitud tendrá efecto el 12 de mayo de 2026 salvo cancelación por otre coordinadore. »

**Efecto inmediato.**

- La membership de Karl pasa a `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl pierde el acceso** inmediatamente a todas las funciones de librarian (la membership está bloqueada).
- Karl recibe un mail:
  > « Hola Karl, la coordinación de la BLMF ha solicitado tu baja del equipo (rol: librarian), como consecuencia de: "Tras la AG del 04/05, comportamiento inadecuado con varias lectores señalado durante varios meses, decisión colectiva de exclusión." Este aviso tendrá efecto el 12 de mayo de 2026 (en 7 días), salvo cancelación por otre coordinadore antes de esa fecha. Para cualquier discusión, diríjete a la coordinación de la BLMF. »
- Emma y Lucy (otras coordinadoras) reciben el mail informativo.
- Audit log: `2026-05-05 — Piotr K. solicitó la baja de Karl M. (rol: librarian, razón: ...)`.

**Evolución.**

- 6 de mayo a las 9h: Lucy lee el mail. Está de acuerdo con la decisión y no interviene.
- 7 de mayo: Emma tiene un intercambio con Karl (quien le escribe para explicarse). Emma concluye que la decisión se mantiene. No interviene.
- 8-11 de mayo: nada.
- **12 de mayo a las 00:00**: el cron `cron_team_pending_removal_complete` se ejecuta. Karl pasa a `inactive`.
- Mail final a Karl + a la coordinación.
- Audit log: `2026-05-12 — paso automático a inactive (razón: pending_removal expirado, cron) — actor: NULL`.

**Comentario.**

Es el caso de la exclusión colectiva. Tres elementos políticos a destacar:

- **La carencia funcionó como posible salvaguarda**, sin ser utilizada. Lucy y Emma podrían haber cancelado; no lo hicieron. El hecho de que nadie haya cancelado es en sí mismo una **deliberación implícita**.
- **Karl permaneció informade** sin sorpresas. No hay exclusión silenciosa.
- **El audit log es legible** por todo el staff y permite volver sobre esta decisión si más adelante alguien se pregunta por qué se fue Karl.

**Políticamente delicado**: la razón escrita en el campo « Razón » es legible por todo el staff. No debería contener detalles sobre las víctimas (RGPD, dignidad), pero debería ser suficientemente clara para que la decisión sea defendible políticamente. Encontrar el equilibrio adecuado es una competencia de coordinación.

## 10.4. Cuenta comprometida: suspensión inmediata

> **Contexto.** El 5 de mayo a las 19:30, Emma observa en los logs de actividad que Friedrich (librarian) realizó 47 modificaciones de fichas del catálogo en 3 minutos, varias de las cuales son aberrantes (libros marcados como « desaparecidos » cuando están en estantería, etc.). El patrón se parece a un acceso no autorizado.

**Procedimiento.**

1. Emma va a `/biblioteca`, pestaña **Equipo**.
2. En la línea de Friedrich, hace clic en **« Suspender »**.
3. Ventana con razón **obligatoria** (≥ 20 caracteres).
4. Emma escribe: « Sospecha de cuenta comprometida, actividad anormal (47 modificaciones de catálogo en 3 min), verificación en curso. »
5. Confirma.

**Efecto inmediato (19:32).**

- Friedrich pasa a `status='suspended'`.
- **Sin acceso** para Friedrich.
- Friedrich recibe un mail urgente: « Tu cuenta AnarBib ha sido suspendida de forma cautelar en la BLMF. Razón: sospecha de compromiso de tu cuenta. Te sugerimos encarecidamente que **cambies tu contraseña inmediatamente**. Una vez asegurada tu cuenta, contacta a la coordinación de la BLMF para que se levante la suspensión. »
- La coordinación (Lucy, Piotr) recibe un mail.
- Audit log: `2026-05-05 19:32 — Emma G. suspendió a Friedrich E. (rol: librarian, razón: ...)`.

**Evolución.**

- **19:35**: Emma llama a Friedrich (canal fuera del SIGB). Friedrich confirma que no realizó esas acciones. Había dejado su ordenador abierto en un espacio compartido.
- **19:40**: Friedrich cambia su contraseña mediante el procedimiento de restablecimiento.
- **20:00**: Emma verifica las acciones dudosas en el audit log de la biblio (el audit de catálogo, no el audit de equipo). Identifica las 47 modificaciones. Las anula manualmente o solicita un rollback a une administradore de red si es necesario.
- **20:15**: Emma vuelve a la pestaña Equipo, levanta la suspensión de Friedrich.
- Friedrich recibe un mail de confirmación. Audit log: `2026-05-05 20:15 — Emma G. levantó la suspensión de Friedrich E.`.

**Comentario.**

Caso típico donde la suspensión se utiliza como **medida cautelar**, no como exclusión. Friedrich no tiene culpa — fue su cuenta la que fue comprometida. La suspensión duró 43 minutos, el tiempo necesario para asegurarla.

**Importante políticamente**: Friedrich no fue « acusade ». El mail lo precisa claramente (« de forma cautelar »). Cuando la situación se resuelve, la suspensión se levanta, y el episodio queda registrado en el log como un incidente, no como una sanción.

## 10.5. Errico es le últime coordinadore y quiere irse

> **Contexto.** La BLMF ya solo tiene une coordinadore active, Errico. Lucy pasó la posta, Emma se mudó y ya no está activa. Piotr se auto-degradó a principios de año. Errico tiene que irse (mudanza al extranjero, sin tiempo).

**Procedimiento.**

1. Errico va a `/biblioteca`, pestaña **Equipo**, hace clic en **« Paso la posta »**.
2. Se abre una ventana **especial**:
   > ⚠️ **ATENCIÓN**: eres le únique coordinadore active de la BLMF. La biblio quedará sin coordinación. Les administradores de red de AnarBib serán notificades. La BLMF podrá seguir funcionando (les librarians siguen operacionales) pero ninguna modificación de la configuración será posible hasta la cooptación de une nueve coordinadore. ¿Continuar?
3. Errico confirma. Razón: « Mudanza al extranjero, sin disponibilidad para la coordinación. »

**Efecto inmediato.**

- La membership coordenador de Errico pasa a `inactive`.
- Mail a Errico (confirmación).
- Mail a tode la coordinación de la BLMF — pero ya no hay ningune, así que en la práctica les `librarian` actives restantes reciben una notificación.
- **Mail urgente a les admins de red**: « La BLMF ya no tiene coordinadore active. Les librarians actives restantes son: Voltairine d.C., Friedrich E., ... »
- Audit log: `2026-05-05 — Errico M. se auto-degradó coordenador → reader (razón: ..., warning: last_coordinator_leaving)`.

**Evolución fuera del software.**

- 6 de mayo: Xavier (admin de red) contacta a Voltairine y Friedrich, les `librarian` actives restantes. Elles confirman que le colectivo BLMF sigue existiendo, y que quieren continuar.
- 7-15 de mayo: discusión interna de le colectivo BLMF, que decide en AG cooptar a Voltairine en el rol de coordinadora.
- 16 de mayo: Xavier (u otre coordinadore de la BLMF que ya no existe en este caso, por lo tanto Xavier en su derecho transversal) coop­ta a Voltairine como coordinadora. **Información previa obligatoria**: Xavier escribió a Friedrich y Voltairine 2 días antes para anunciar la acción. Una vez realizada, la acción queda registrada en `cross_library_actions_log` con nivel de criticidad « elevado » (modificación de coordinación de una biblio por admin de red).

**Comentario.**

Caso políticamente delicado: la biblio pasa por un período de fragilidad (entre el 5 y el 16 de mayo, no tiene coordinación). Pero el SIGB **no impidió** la salida de Errico — su derecho P3 es incondicional. El SIGB simplemente **alertó a la red** para que esta pudiera ayudar.

La intervención de Xavier ilustra el uso **correcto** del derecho transversal: fue solicitade (implícitamente, por la alerta automática), respetó la información previa, registró su acción. No impuso a Voltairine; fue le colectivo BLMF quien la eligió. Xavier simplemente **ejecutó técnicamente** la decisión.

## 10.6. Una cooptación de admin de red que se frustra

> **Contexto.** Xavier es admin de red fundadore. Con el tiempo, Maria, Patricia y Diego fueron cooptades como admins de red a medida que la red se expandió. Al 20 de mayo de 2026, le colectivo de admins es: Xavier, Maria, Patricia, Diego (cuatro admins actives).
>
> Maria propone la cooptación de Mohammed, a quien conoce en una biblio italiana que se une a la red.

**Procedimiento.**

1. Maria, desde `/rede/administradores`, hace clic en **« Proponer una cooptación »**.
2. Introduce la identidad de Mohammed (cuenta AnarBib creada dos semanas antes).
3. Motivación: « Mohammed coordina la BLA (Bolonia), una biblio que se une a la red este mes. Ha impulsado la integración política de la BLA en AnarBib y está muy involucrade en la coordinación italiana. Su cooptación como admin de red reforzará la diversidad geográfica de le colectivo y facilitará la animación del lado italiano. »
4. Confirma.

**Efecto inmediato.**

- Propuesta creada, `status='open'`, `expires_at = 19 junio 2026`.
- Voto automático `favorable` de Maria registrado.
- Mails a Xavier, Patricia, Diego con la propuesta.

**Evolución.**

- 22 de mayo: **Diego** vota `favorable`. Sin rationale (opcional para favorable).
- 25 de mayo: **Patricia** vota `opposed`. Rationale: « Mohammed no tiene ninguna antigüedad en la red. Su cooptación va más rápido que la de la BLA, que aún no ha tenido la oportunidad de funcionar como biblio AnarBib durante suficiente tiempo. Propongo esperar 6 meses para que la BLA haya encontrado su ritmo, y luego reproponerle a Mohammed en ese momento. » Patricia marca « Revelar mi identidad ».

**Efecto inmediato del voto opposed.**

- La propuesta pasa a `status='rejected'`.
- Mail a Mohammed: « Hola Mohammed, tu propuesta de cooptación como admin de red de AnarBib no prosperó. Patricia X. planteó la siguiente objeción: "[rationale completa]". Puedes intercambiar con elle o con Maria, quien te había propueste. La cooptación podrá ser reproponuesta más adelante. »
- Mail a Maria (proponente): resumen con la rationale de Patricia.
- Mail a Xavier y Diego: información de que la propuesta fue rechazada, con la rationale.
- Audit log de red: `2026-05-25 — cooptación rechazada: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Comentario.**

Caso ilustrativo de la unanimidad **en acción**. Patricia tiene un veto, lo utiliza, su rationale es explícita y constructiva (« esperemos 6 meses »). Eligió revelar su identidad, lo que permite a Mohammed y Maria hablar directamente con elle en lugar de especular sobre quién se opuso de forma anónima.

**Políticamente**: la cooptación por unanimidad no es garantía de bloqueo permanente. Patricia no dice « nunca » sino « no ahora ». Si en 6 meses la BLA está bien integrada y Patricia cambia de opinión, una nueva propuesta podrá prosperar. Es esta **reversibilidad en el tiempo** lo que hace soportable la unanimidad.

La alternativa — cooptar a Mohammed por mayoría en contra de la opinión de Patricia — habría creado un círculo de admins donde Patricia se habría sentido en una posición incómoda. Es mejor esperar.

\newpage

# Anexos

\newpage

# Anexo A — Glosario

**AG** — Asamblea general. Reunión colectiva de toma de decisiones de una biblio. El SIGB no modela la AG (P8). Su modalidad (quórum, frecuencia, modo de deliberación) es enteramente decidida por cada biblio.

**Audit log** — Registro de las acciones de gobernanza, almacenado en `library_membership_audit` (a nivel de una biblio) y `network_administrator_audit` (a nivel de red). Legible por el staff activo (a nivel biblio) y por les admins de red (a nivel de red).

**Auto-degradación** — Acción por la cual une membre del staff se degrada a sí misme a un rol inferior. Derecho P3, incondicional.

**Biblio `private`** — Biblio cuyo catálogo solo es visible para sus miembros inscrites. Modo adaptado para las biblios políticamente expuestas.

**Biblio `network`** — Biblio cuyo catálogo es visible para todes les `reader` validadesde la red AnarBib. Modo por defecto para la mayoría de las biblios.

**Biblio `public`** — Biblio cuyo catálogo es visible para todo el mundo, incluyendo les visitantes anónimes.

**Carencia** — Plazo impuesto entre una decisión y su efecto. Siete días para las bajas colectivas de staff local y de admin de red. Treinta días para la auto-baja de le únique admin de red active.

**Cooptación** — Mecanismo de entrada en un equipo (staff local) o en le colectivo de admins de red. Para el staff local: decisión de une coordinadore+. Para la red: unanimidad de les admins actives.

**Cross-biblios** — Califica una acción realizada por une admin de red sobre una biblio de la que no es miembro del staff local. Registrada en `cross_library_actions_log`.

**Cron** — Tarea automática ejecutada periódicamente por el SIGB. Sin actor humane. Ejemplos: `cron_team_pending_removal_complete` (paso de `pending_removal` a `inactive` a J+7), `cron_team_inactive_cleanup` (salida automática a los 9 meses).

**Delegación** — Acto por el cual un colectivo confía temporalmente una función a une de sus miembros, conservando la posibilidad de recuperarla. Concepto central, distinguido de « jerarquía ».

**Membership** — Línea de la tabla `user_library_memberships` que expresa la vinculación de una persona a una biblio en un rol dado. Una persona puede tener varias memberships en una biblio (multi-membership).

**Multi-membership** — Posibilidad de tener varias líneas de membership para una misma persona en una misma biblio, con roles diferentes.

**Red** — Le colectivo de las biblios que se reconocen mutuamente y comparten la plataforma AnarBib. No es una organización central, es una federación.

**RPC** — *Remote Procedure Call*. Función SQL llamada por la interfaz usuarie para ejecutar una acción. Todas las acciones de gobernanza pasan por RPC nombradas `fn_team_*` (staff local) o `fn_network_admin_*` (red).

**Soberanía local** — Principio P7 según el cual cada biblio es soberana sobre sus delegaciones internas. Los cambios de rol en una biblio no afectan nada en otra.

**Spec** — Documento de especificación (`spec-*.md`) que describe en detalle el funcionamiento de una funcionalidad del SIGB. Fuente de verdad técnica y política. Versionada, datada, enmendable.

**Unanimidad** — Modalidad de cooptación y de baja colectiva de les admins de red. Todos los votos deben ser `favorable`; un solo `opposed` o una abstención no levantada bloquea.

**Validación física** — Procedimiento por el cual une librarian+ valida una cuenta `reader` tras un encuentro físico. Vale para toda la red (pacto de reconocimiento mutuo).

**Veto** — Voto `opposed` durante una cooptación o una baja colectiva de admin de red. Efecto inmediato: rechazo de la propuesta. Rationale obligatoria de 20 caracteres mínimo.

\newpage

# Anexo B — Índice de funciones técnicas

Este anexo ofrece, para cada RPC mencionada en el guía, su traducción política y la transición correspondiente. Sirve de referencia rápida.

## Funciones de staff local

| RPC SQL | Transición | Traducción política |
|---|---|---|
| `fn_team_promote_to_librarian` | T1 | Cooptación `reader` → `librarian` |
| `fn_team_promote_to_coordenador` | T2 | Cooptación `librarian` → `coordenador` |
| `fn_team_self_demote` | T3, T4 | Auto-degradación (« paso la posta ») |
| `fn_team_request_remove_member` | T5 | Solicitud de baja con carencia de 7 días |
| `fn_team_cancel_remove_member` | T8 | Cancelación de una solicitud de baja |
| `fn_team_suspend_member` | T6 | Suspensión inmediata (medida cautelar) |
| `fn_team_unsuspend_member` | T7 | Levantamiento de suspensión |
| `fn_validate_physical_account` | — | Validación física de une `reader` |
| `cron_team_pending_removal_complete` | T5 (continuación) | Cron: paso a `inactive` a J+7 |
| `cron_team_inactive_cleanup` | T9 | Cron: salida automática a los 9 meses |

## Funciones de admin de red

| RPC SQL | Etapa | Traducción política |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Cooptación: propuesta | Une admin propone une nueve |
| `fn_network_admin_vote_cooptation` | Cooptación: voto | Voto favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Auto-baja | Abandonar sus funciones de admin de red |
| `fn_network_admin_request_removal` | Baja colectiva | Workflow espejo de la cooptación |

## Helpers de autorización (usados por las RLS)

| Helper SQL | Sentido político |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | ¿Puede esta persona actuar como staff en esta biblio? (staff local active O admin de red) |
| `user_can_engage_library(library_id)` | ¿Puede esta persona comprometer políticamente esta biblio? (coordinadore local active O admin de red) |
| `fn_caller_is_network_admin()` | ¿Es la persona llamante une admin de red active? |
| `fn_library_visible_to_caller(library_id)` | ¿Es visible el catálogo de esta biblio para quien llama? |

## Tablas principales

| Tabla | Sentido político |
|---|---|
| `user_library_memberships` | Las delegaciones locales (quién es staff de qué biblio) |
| `network_administrators` | Les administradores de la red |
| `library_membership_audit` | Registro de las acciones de gobernanza local |
| `network_administrator_audit` | Registro de las acciones de gobernanza de red |
| `network_administrator_cooptation_proposals` | Propuestas de cooptación en curso |
| `network_administrator_cooptation_votes` | Votos individuales de les admins |
| `cross_library_actions_log` | Registro de las acciones de admin de red sobre biblios |

\newpage

# Anexo C — Modelo de nota de enmienda

Cuando quieras proponer una enmienda a una regla del SIGB o a este guía, aquí tienes un modelo de nota para estructurar tu propuesta. Formato libre, puedes adaptarlo.

---

## Propuesta de enmienda a [nombre de la spec o del guía]

**Autore/s:** [tus nombres / pseudos]
**Fecha:** [DD/MM/AAAA]
**Alcance:** [biblio local / red / fundamentos]

### 1. Regla concernida

Citar textualmente la regla o el párrafo a enmendar, con su referencia en la spec fuente.

> *Ejemplo:* « `spec-gouvernance-roles.md`, §5.6, T5: El plazo de carencia antes de la exclusión efectiva es de 7 días. »

### 2. Problema identificado

Describir en unas pocas frases qué genera problemas en la regla actual. Si es posible, con un caso concreto encontrado.

> *Ejemplo:* « En la práctica, 7 días es demasiado poco cuando la próxima AG de la biblio se celebra en 15 días. Una decisión de baja tomada en caliente a veces no tiene tiempo de ser discutida colectivamente antes del efecto automático. »

### 3. Enmienda propuesta

Describir la modificación deseada, en la medida de lo posible con una formulación lista para integrar en la spec.

> *Ejemplo:* « Ampliar el plazo de carencia de 7 a 14 días, O hacer el plazo configurable por biblio (entre 7 y 30 días), con un valor por defecto de 14 días. »

### 4. Consecuencias técnicas anticipadas

Si tienes idea de qué implica del lado del código, decirlo. Si no, decirlo también (« no lo sé, a ver con les dev »).

> *Ejemplo:* « Modificar el valor fijo en el código SQL de `fn_team_request_remove_member` y `cron_team_pending_removal_complete`. Si es configurable por biblio, añadir una columna a `libraries`. »

### 5. Consecuencias políticas anticipadas

Describir qué cambia en la práctica colectiva, y los posibles efectos secundarios.

> *Ejemplo:* « Más tiempo para la deliberación, pero también más tiempo durante el cual la persona en `pending_removal` permanece suspendida (sin acceso). Puede percibirse como más gravoso. »

### 6. Alternativas consideradas

Mencionar las otras pistas que hayas pensado, y por qué las descartas (o no).

> *Ejemplo:* « Alternativa: dejar el plazo en 7 días pero permitir una "prórroga explícita" por otre coordinadore. Más complejo de implementar y de entender. Preferible modificar el valor por defecto. »

### 7. Discusión deseada

¿Dónde y cómo quieres que se discuta la propuesta?

> *Ejemplo:* « Discusión en el canal Matrix `#anarbib`, y si hay consenso, integración en la spec en el próximo paquete de gobernanza. »

---

Una vez redactada, hacer circular la nota según el alcance (cf. capítulo 4, §4.2).

\newpage

# Anexo D — Specs fuente y referencias

Este guía se apoya en los siguientes documentos, consultables en el repositorio del proyecto:

## Specs principales

**`spec-gouvernance-roles.md`** — Spec fundadora de la gobernanza de los roles de staff local. Versión 1.0 del 5 de mayo de 2026. 1231 líneas. Detalla los 4 roles, los 5 estados, las 9 transiciones, el audit log, las notificaciones, la UI, y 15 casos de uso de referencia.

**`spec-administrateur-reseau.md`** — Separación entre staff local y admin de red. Versión 0.3 del 11 de mayo de 2026. 975 líneas. Detalla la tabla `network_administrators`, la cooptación por unanimidad, la baja colectiva, el derecho transversal, la semántica de los contadores « página = perímetro ».

**`spec-validation-physique.md`** — Modos de acogida de las cuentas lectores (`open` vs `manual_validation`). Enmarcada el 3 de mayo de 2026. Detalla los estados de la cuenta, el esquema DB, los flujos de trabajo.

**`spec-refactor-v3-semantique.md`** — Refactor de la semántica del flujo de trabajo de reserva. No es central para la gobernanza pero se cita al margen por la coherencia de conjunto del SIGB.

## Specs relacionadas mencionadas (a redactar o en curso)

- `spec-migration-compte.md` — Migración de una cuenta de una biblio a otra. 940 líneas, enmarcada el 3 de mayo de 2026.
- `spec-invitation-equipe.md` — Flujo de trabajo de invitación por correo electrónico para personas sin cuenta AnarBib. A redactar.
- `spec-fermeture-biblio.md` — Procedimiento de cierre ordenado de una biblio. A redactar.
- `spec-mediation-conflits.md` — Marco formalizado de mediación e investigación tras una denuncia. A redactar (sugerido por el presente guía).

## Para saber más

Las specs y el código fuente están en el repositorio Codeberg del proyecto, con espejo en GitHub. La discusión técnica y política se desarrolla en el canal Matrix `#anarbib` de la red.

Para cualquier propuesta de enmienda a este guía o a las specs, ver capítulo 4 y anexo C.

---

*Fin del guía. Versión 1.0, 11 de mayo de 2026.*

*Este guía es en sí mismo enmendable. Si encuentras que dice algo erróneo, que ha olvidado un caso, o que toma una posición que ya no corresponde a la doctrina de la red, dilo.*

