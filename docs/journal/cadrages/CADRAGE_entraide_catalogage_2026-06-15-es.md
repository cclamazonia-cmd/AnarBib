# Encuadre — Ayuda mutua en el catalogado (pestaña «Ayuda mutua» de la Federación)

**Fecha** : 2026-06-15
**Estado** : **encuadre / proyecto** — reflexión exploratoria que plantea la *visión*,
la *arquitectura* y las *decisiones de principio*. **No es todavía una spec a
construir**: hay que discutirlo, someterlo a prueba, y luego desarrollarlo en specs.
**Base ética** : [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
(«la mano tendida»). **Cada pantalla de las siguientes ha sido sometida a la grilla «¿tiende o
agarra?».** Este encuadre es, en cierto modo, la primera puesta a prueba concreta de la carta.

---

## 1. La necesidad

El catalogado es el punto de dolor de las bibliotecas principiantes (cf. los talleres
de autoridades, indexación por materia, wizard de descubrimiento). Una biblioteca sola
frente a las autoridades, los temas, la clasificación, se siente intimidada. La pestaña
«Ayuda mutua» responde a esa necesidad concreta — pero el catalogado anarquista no es
neutro: los encabezamientos de materia convencionales patologizan, borran, mal-nombran.
**La ayuda mutua transmite un *artesanado político* que ni los estándares ni una IA
codifican.**

Principio transversal: **la petición de ayuda es genérica** (ayuda mutua sobre *cualquier*
asunto técnico espinoso), el **catalogado es el primer dominio cableado**.

## 2. Tres grados de ayuda mutua — una escala, por subsidiaridad

No «uno U otro» sino tres *intensidades*; la petición de ayuda es el pivote, la
respuesta adopta una de las tres formas, de la más ligera a la más pesada:

1. **El común de saber** (vademécums, casos, tesauro) — coste cero, dependencia
   cero, 100 % entre iguales. La base duradera.
2. **Mini-wizards** — guían a la biblioteca para que lo haga *elle misma* (autonomizante,
   no generador de dependencia).
3. **Ayuda humana directa** (llamada → respuesta → posible videoconferencia) — la más
   relacional, para cuando el común y el wizard no bastan.

**El bucle descendente**: un caso difícil resuelto en grado 3 → resumen → se convierte
en un caso/wizard de grado 1-2 → la próxima vez, el wizard basta. *El saber baja los
grados con el tiempo; la red se vuelve más inteligente y más autosuficiente con cada
episodio.*

## 3. El común de saber — la capa de autonomía

Tres capas, y la más profunda es **el vocabulario en sí**:

- **El tesauro, núcleo político.** No una lista de palabras: un *grafo de conceptos*. La
  política vive en los **términos**, las **relaciones** (broader/narrower/related) y las
  **notas de aplicación** (que son micro-vademécums). Construir sobre **SKOS** (estándar
  libre) — legar una norma, no un bricolaje. Existe una semilla (tesauro de ~30 categorías).
- **Casos y vademécums** — ejemplos trabajados, editables, que surgen *en el punto de necesidad*.
- **Wizards en *datos*, no en *código*** — *la apuesta de autonomía*: si un wizard es
  código, se depende de desarrollo para siempre; si es un **documento estructurado** (árbol
  de tarjetas-pregunta → tarjetas-fin) que un motor escrito-una-vez despliega, **cualquier
  biblioteca escribe uno sin programar**. Salvaguardias para que no se convierta en un
  lenguaje de programación disfrazado: sin variables/cálculo/condición libre; el único
  estado = el camino recorrido; condiciones eventuales desde una lista cerrada; **el wizard
  *aconseja*, nunca *escribe*** (el peor fallo = «no útil», nunca «rompió el catálogo»);
  wizards pequeños y monotemáticos.

**Multilingüe sin IA**: la carcasa i18n (10 locales) porta la interfaz; la *sustancia*
(términos, casos) se escribe **por comunidad de lengua** (escritura paralela cross-enlazada,
no traducción descendente) — lento pero duradero y gratuito. **Gobernanza**: incorporación/
modificación de un término mediante el flujo **consentimiento/objeción** de los círculos;
cursor político «variantes admitidas vs convergencia» a fijar por la red.

## 4. El detonante — en el punto de necesidad (carta ③)

**El detonante es el *campo*, el *dato* o la *demanda* — nunca la vigilancia
de la persona.** Prohibir las señales conductuales («5 min en el campo», vacilaciones):
eso es Clippy *y* vigilancia del trabajo. Tres detonantes honestos:
- **intrínseco al campo** (temas/autoridad son difíciles *para todes* → ayuda siempre presente);
- **derivado del dato** (sin ISBN, autore ambigue → el libro señala, no la persona);
- **demanda explícita** («socorro» discreto, siempre al alcance).

La ayuda sube **la escala a un-clic-más-lejos** (inline → wizard → círculo), **discreta pero
descubrible** (posicionamiento fiable, nunca modal/gamificada), con una **presencia en curva
por dominio** (un poco más cercana si el campo está vacío + escaso número de registros; se
difumina con la maestría; siempre plegable a mano).

## 5. Dos pantallas ya sometidas a la grilla

### 5.1 — El «?» bajo un campo difícil (catalogado)
Presente *porque el campo es difícil para todes* (encuadre de dignidad, no «pareces tener
dificultades»). Al abrirlo: sugerencias de tesauro inline + casos del común → «camino guiado»
(wizard) → «pedir al círculo» (grado 3, momento del consentimiento).
**La grilla eliminó dos funcionalidades tentadoras**: ❌ detectar la vacilación para
proponer la ayuda (vigilancia, faceta ③); ❌ insignias/rachas/barra hacia «experte» (faceta ⑥).
**Valores predeterminados adoptados**: filete «¿primera vez? camino guiado» *ofrecido en
registro de oferta*; «?» siempre visible, sugerencias **desplegadas al clic** (discreto + descubrible).

### 5.2 — El cierre de episodio + captura del común
Cierre **iniciado por la ayudada** (sin auto-cierre, sin cierre por parte de quien ayuda). Pantalla
de «gracias» sobria, **sin nada enganchado** (desacoplamiento anti-deuda). **Barrote-pluma**
«¿mantener el contacto?» simétrico, ignorable, no crea nada salvo doble-sí.
**Captura del común sin deuda**: se invita a **quien ayuda** (porta el saber nuevo), no a la
ayudada; **micro-contribución acoplada al objeto** (nota sobre un término/campo), **iniciada
por el rastro** del episodio; luego **la ayudada es invitada a revisar/enriquecer** («lo que
era realmente difícil») — *su voz, declinable, nunca un juicio de quien ayudó*, y **no
bloqueante** (la nota vale por sí sola).
**La grilla eliminó**: ❌ «valora tu experiencia» (clasificación disfrazada); ❌ insignia
de finalización.

## 6. Confidencialidad

El dato de catálogo es *menos* sensible que el dato de le lectore (metadatos sobre
*libros*, nunca ejemplares/préstamos/identidades), **pero no es cero** (los fondos de una
biblioteca anar pueden ser políticamente sensibles; cf. la distinción `visibility_level='network'` /
BTL). Por tanto:
- **opt-in por ítem** (nunca un volcado), **BTL/sensibles excluidos por defecto**;
- **quien ayuda *propone*, la propietaria *valida*** — nunca escritura directa por un tercero;
  acceso **acotado, revocable, auditado**;
- el nivel **«pedir al círculo» ES el momento del consentimiento** («vas a mostrar estos
  ítems a la biblioteca X — he aquí lo que sale»);
- **el común capta artesanado *genérico des-identificado*, no *casos* identificadores**;
  las especificidades se eliminan o se consienten.

Respuesta a la pregunta «¿derecho absoluto a delegar?»: **sí a la autonomía, pero consentimiento
*informado y acotado*, no un cheque en blanco** — hacer el riesgo pequeño y asumirlo
con conocimiento de causa.

## 7. Emparejamiento y maduración en partenariado

- **Clasificación suave, no filtro duro.** En una red dispersa, un Y (misma lengua Y geo Y
  disponibilidad Y experticia) = conjunto vacío. Se **clasifica** por afinidad (lengua ↑,
  huso ↑, voluntarie ↑) sin **excluir**; subsidiaridad **círculo primero → red si hay silencio**.
  El **círculo pertinente depende del tipo de ayuda** (catalogado → lingüístico; material/
  represión → geográfico).
- **Primer gesto sin prerequisito**: ofrecerse voluntarie para *un* acto no exige ningún
  círculo ni perfil. **La pertenencia se acumula con los gestos** (reconocimiento consentido,
  nunca etiqueta).
- **Anti-jerarquía**: sin reputación individual, sin marketplace; disponibilidad
  declarada, reciprocidad visible sin puntuación, rotación.
- **Maduración en partenariado (§21)** — *segunda fase que disuelve la escasez*: un buen
  episodio puede **madurar** en partenariado → la ayuda futura está *pre-emparejada*
  (lengua, huso, consentimiento ya dado); la red se **densifica**. **Desacoplado** del episodio
  (nunca en el instante = deuda); **tras repetición** (reconocimiento, no creación);
  **doble-opt-in simétrico**; **escala de profundidad** (0 → mantener-contacto →
  acompañamiento → partenariado formal); **inversión de la deuda** (el partenariado es un
  *regalo* a la ayudada: «une compañere a quien llamar sin re-consentir», no una deuda);
  siempre **separable**.

## 8. El módulo de videoconferencia (grado 3)

Acoplar la ayuda humana a una **videoconferencia Jitsi** (síncrono = transmisión eficaz);
vivero = **círculo lingüístico**. **Asíncrono primero, videoconferencia como turbo opcional**
(la más precaria tiene mala conectividad → grados 0-2 en texto/sin conexión).
Técnicamente, «de manera gratuita»: **codificar la integración una vez mediante la iframe API
con el `domain` en config** → nunca bloqueade a un proveedor. Apuntar por defecto a una
**instancia Jitsi militante** (lo más acorde a la doctrina, gratuito, sin GAFAM); en su defecto
`meet.jit.si` (asumiendo la autenticación de quien crea la sala). Salas **efímeras, nombre
no-adivinable, lobby**. **Cero servidor, cero secreto, cero coste recurrente.** El auto-alojado
queda como *parking* (VPS descartado).

## 9. Coste y autonomía

Todo (común, wizards, paneles, matching, enlace a videoconferencia) **funciona sobre la stack
existente** (Supabase + front estático): **coste marginal cero, sin IA para funcionar**. La IA
sigue siendo un **acelerador opcional y desconectable** (pre-catalogado del *neutro* únicamente;
lo político queda entre compañeres). **Los órganos ya existen**: semilla de tesauro, wizard de
descubrimiento, i18n 10 locales, flujo consentimiento/objeción de los círculos, §21 partenariado.
**Este encuadre conecta órganos existentes — de ahí su modestia, y su independencia respecto al
coste y a cualquier dependencia externa.**

## 10. Decisiones tomadas / preguntas abiertas

**Tomadas (a lo largo de la reflexión):**
- Tres grados en escala + bucle descendente del saber.
- Común = tesauro (SKOS, núcleo político) + casos + **wizards en datos**.
- Detonante por campo/dato/demanda, **nunca vigilancia**; escala a un-clic;
  presencia en curva por dominio.
- Pantalla «?»: valores predeterminados (oferta, sugerencias al clic); rechazos (detección
  de vacilación, gamificación).
- Cierre: la ayudada cierra; **quien ayuda redacta → la ayudada enriquece** (deuda cero);
  común = **artesanado genérico**; gobernanza **aditivo = 2 personas / vocabulario = colectivo**.
- Emparejamiento **clasificación suave + círculo primero**; círculo **según el tipo de ayuda**;
  primer gesto sin prerequisito; **pertenencia por el gesto**.
- Maduración §21 **desacoplada, tras repetición, doble-opt-in, escala de profundidad,
  inversión de deuda, separable**.
- Videoconferencia **Jitsi `domain` configurable**, asíncrono-primero, cero infra/secreto.
- (Recordatorio correo, ya cableado fuera de este encuadre) locale de la persona destinataria =
  **su preferencia personal**.

**Abiertas (cursores políticos a fijar por la red):**
- **Nivel de acogida inicial** (hospitalidad) y **quién lo establece**: red / círculo / biblioteca /
  persona. Pista: *preguntar* a la recién llegada su acogida (consentimiento) + subsidiaridad
  (lo alto solo llena el silencio) + opción de *acompañamiento encarnado* por une voluntarie
  del círculo.
- Nivel de **presencia del barrote-pluma** y de la invitación al común (ofrecido vs disponible) —
  ampliamente desactivado por la **semántica** (registro de oferta ≠ imposición).
- Forma concreta del **editor de wizard-en-datos** (hasta dónde sin convertirse en código).
- Cursor **variantes vs convergencia** del tesauro.

## 11. Estado

Encuadre a **discutir y someter a prueba**, no una orden de construcción. Cuando un módulo
esté maduro, se desarrollará en spec, y cada pantalla volverá a pasar por la **grilla de la
carta relacional**.
