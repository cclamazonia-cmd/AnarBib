# Acuerdo de Tratamiento de Datos (DPA)

**Entre AnarBib (encargado del tratamiento) y la biblioteca adherente (responsable del tratamiento)**

---

## Preámbulo

Este acuerdo se firma entre el proyecto **AnarBib** y la biblioteca
adherente designada en el artículo 12. Se inscribe en un marco
político y jurídico específico que es importante explicitar antes
de detallar los artículos.

**Conformidad al RGPD/LGPD como herramienta de protección.** Las
bibliotecas militantes anarquistas operan en contextos donde la
vigilancia estatal, la represión policial y judicial, o la
curiosidad hostil de actores económicos pueden apuntar directamente
a les lector(a/e)s. La conformidad al Reglamento General de
Protección de Datos europeo (RGPD) y a la Ley General de Protección
de Datos brasileña (LGPD) no es, en este contexto, un alineamiento
neoliberal: es un uso táctico del derecho para proteger a quienes
nos confían sus datos personales. Las obligaciones descritas en
este acuerdo (minimización, seguridad, rechazo de transferencia
sin fundamento) constituyen un arsenal jurídico movilizable en
caso de pedido abusivo de una autoridad.

**Coherencia con la ética anarquista.** El principio de minimización
de datos (RGPD artículo 5(1)(c)) coincide con el cuidado anarquista
de no acumular información sobre las personas. No recolectamos ni
conservamos nada más allá de lo estrictamente necesario para el
funcionamiento de la biblioteca. Las duraciones de retención cortas,
el rechazo a vender o comunicar a terceros, la transparencia sobre
nuestres encargades ulteriores: todo esto es a la vez conforme al
derecho y fiel a nuestra cultura política.

**Compromiso mutuo en un marco federativo.** AnarBib no es una
empresa que vende un servicio a clientes. Es una red federativa de
bibliotecas autónomas que comparten una infraestructura técnica.
Este DPA no es un contrato comercial: es un acto de compromiso
mutuo entre el colectivo AnarBib (que asume la responsabilidad
técnica y la protección de los datos) y cada biblioteca adherente
(que mantiene el control político de sus datos y de su gobernanza).
Cada parte permanece autónoma. Este acuerdo formaliza las
responsabilidades respectivas en el marco del tratamiento técnico
que AnarBib opera por cuenta de la biblioteca.

---

## Artículo 1 — Objeto

La biblioteca adherente confía a AnarBib el tratamiento técnico de
ciertos datos personales necesarios para el funcionamiento de su
sistema integrado de gestión bibliotecaria (SIGB), según las
condiciones descritas en el presente acuerdo.

AnarBib actúa como **encargade del tratamiento** en el sentido del
artículo 28 del RGPD y del artículo 39 de la LGPD. La biblioteca
adherente es le **responsable del tratamiento** y permanece
soberana respecto a las decisiones sobre sus datos.

## Artículo 2 — Duración

El presente acuerdo entra en vigor en la fecha de firma y permanece
válido mientras la biblioteca adherente utilice la infraestructura
AnarBib.

La biblioteca adherente puede rescindir este acuerdo en cualquier
momento sin penalización, mediante notificación por correo
electrónico a contato@anarbib.org. AnarBib puede rescindir mediante
preaviso de 90 días y procederá según el artículo 10 del presente
acuerdo respecto al destino de los datos.

## Artículo 3 — Definiciones

A los fines del presente acuerdo, se aplican las definiciones del
RGPD (artículo 4) y de la LGPD (artículo 5). En particular:

- **Datos personales**: toda información relativa a una persona
  física identificada o identificable.
- **Tratamiento**: toda operación efectuada sobre datos personales
  (recolección, registro, conservación, modificación, consulta,
  comunicación, eliminación, etc.).
- **Responsable del tratamiento**: la persona o entidad que
  determina las finalidades y los medios del tratamiento — en este
  acuerdo, la biblioteca adherente.
- **Encargade del tratamiento**: la persona o entidad que trata los
  datos personales por cuenta del responsable — en este acuerdo,
  AnarBib.
- **Persona afectada**: la persona física a la que se refieren los
  datos personales (en la biblioteca: lector(a/e)s,
  bibliotecari(o/a/e)s, coordinador(a/e)s).

## Artículo 4 — Descripción del tratamiento

### 4.1 Categorías de datos tratados

- Identidad: nombre, apellido, correo electrónico, teléfono
  (opcional), género (opcional), dirección (opcional)
- Identificadores técnicos: ID interno, ID público, idioma preferido
- Datos de circulación: préstamos, reservas, consultas in situ
  (con su historial)
- Adhesión: estado de cotización, fechas, montos pagados
- Notificaciones: mensajes recibidos en la aplicación
- Lista de deseos: libros marcados por le lector(a/e)

### 4.2 Categorías de personas afectadas

- Lector(a/e)s adherentes de la biblioteca
- Bibliotecari(o/a/e)s y coordinador(a/e)s de la biblioteca
- Personas que hacen una solicitud de adhesión sin ser aún
  adherentes

### 4.3 Finalidades

- Gestión de la circulación de documentos (préstamos, reservas,
  devoluciones)
- Comunicación operativa con les lector(a/e)s (recordatorios, avisos)
- Gestión asociativa (cotizaciones, adhesiones)
- Estadísticas internas anónimas para el funcionamiento de la
  biblioteca

### 4.4 Duraciones de conservación

Conforme al principio de minimización, las duraciones predeterminadas
de la red AnarBib son:

- Historial de préstamos finalizados: 24 meses
- Historial de reservas finalizadas: 12 meses
- Historial de consultas in situ finalizadas: 12 meses
- Notificaciones leídas: 90 días
- Perfil y datos de inscripción: mientras la cuenta de la persona
  exista

La biblioteca adherente puede adoptar duraciones más cortas (o más
largas, mediante decisión colectiva justificada) a través de la
página de configuración de su biblioteca. Las duraciones vigentes
se publican en la política de privacidad pública.

## Artículo 5 — Obligaciones de AnarBib (encargade)

AnarBib se compromete a:

### 5.1 Tratar los datos únicamente bajo instrucción documentada

AnarBib trata los datos personales solo para las finalidades
descritas en el artículo 4 y según las configuraciones que la
biblioteca define en su interfaz de gestión. AnarBib no usa esos
datos para finalidades propias.

### 5.2 Garantizar la confidencialidad del personal involucrado

Las personas que acceden a los datos personales por cuenta de
AnarBib (en particular el desarrollador principal, Xavier
Van Welden) se comprometen por principio a respetar la
confidencialidad. Ningún acceso a datos de una biblioteca
específica se efectúa sin necesidad técnica documentada.

### 5.3 Implementar medidas de seguridad apropiadas

AnarBib implementa las siguientes medidas técnicas y organizativas:

- Cifrado en tránsito (TLS) para todas las comunicaciones
- Hasheo de las contraseñas (bcrypt vía Supabase Auth)
- Control de acceso por filas (Row Level Security PostgreSQL)
- Principio de minimización aplicado por diseño
- Auditoría periódica de las políticas de seguridad

### 5.4 Comunicar les encargades ulteriores

AnarBib utiliza les encargades ulteriores listades en el artículo 7.
Toda incorporación se notificará a la biblioteca por correo
electrónico con 30 días de preaviso. La biblioteca puede oponerse
a la incorporación por escrito; en caso de oposición persistente,
el presente acuerdo podrá ser rescindido a iniciativa de la
biblioteca.

### 5.5 Asistir a la biblioteca

AnarBib asiste a la biblioteca adherente para:

- Responder a las solicitudes de ejercicio de derechos de las
  personas afectadas (acceso, rectificación, eliminación,
  portabilidad)
- Cumplir las obligaciones de seguridad (artículo 32 RGPD)
- Notificar una eventual violación de datos (artículos 33 y 34 RGPD)

La biblioteca puede apoyarse en las herramientas integradas (página
"Mi cuenta" de les lector(a/e)s, exportación RGPD en formato
JSON+CSV, eliminación de cuenta directa) que AnarBib mantiene a
disposición.

### 5.6 Notificar las violaciones de datos

En caso de violación de datos personales, AnarBib notifica a la
biblioteca adherente sin demora indebida y a más tardar en un plazo
de 72 horas tras la constatación. La notificación describe la
naturaleza de la violación, las categorías y el número aproximado
de personas y datos afectados, las medidas tomadas o propuestas, y
los puntos de contacto.

El documento INCIDENT_RESPONSE.md publicado en el repositorio
AnarBib detalla el procedimiento operativo.

### 5.7 Restituir o eliminar los datos al final del contrato

Conforme al artículo 10 del presente acuerdo.

## Artículo 6 — Obligaciones de la biblioteca (responsable)

La biblioteca adherente se compromete a:

### 6.1 Garantizar la legalidad de los tratamientos

La biblioteca verifica que cada tratamiento que confía a AnarBib se
basa en una base legal válida (consentimiento, ejecución
contractual, interés legítimo, etc.).

### 6.2 Informar a las personas afectadas

La biblioteca se asegura de que les lector(a/e)s estén informades
del tratamiento de sus datos personales. La política de
privacidad común de AnarBib (accesible en /privacidade) y la
sección específica eventualmente publicada por la biblioteca
constituyen el soporte de información. La biblioteca puede
completar libremente esta información por sus propios medios.

### 6.3 Dar instrucciones legítimas

La biblioteca no dará a AnarBib instrucciones que contravengan la
regulación aplicable. AnarBib puede legítimamente negarse a
ejecutar una instrucción manifiestamente ilegal y lo señalará por
escrito.

## Artículo 7 — Encargades ulteriores

La biblioteca adherente autoriza a AnarBib a recurrir a les
siguientes encargades ulteriores:

| Encargade ulterior | Función | Ubicación | Estado |
|---|---|---|---|
| **Supabase Inc.** | Base de datos, autenticación, almacenamiento, edge functions | AWS São Paulo (sa-east-1) | DPA específico firmado (ref TFXNN-HUMKJ-3WKP8-MZMYW, CCT 2021/914 módulo 2) |
| **Sendinblue (Brevo)** | Envío de correos transaccionales | UE (Francia) | DPA estándar Brevo |
| **Codeberg e.V.** | Alojamiento del frontend (Codeberg Pages) | UE (Alemania) | No trata datos personales (frontend estático) |

Toda modificación de esta lista se notificará según el artículo 5.4.

## Artículo 8 — Transferencias fuera de la UE/Brasil

La ubicación principal de los datos es AWS São Paulo (Brasil), lo
cual no constituye una transferencia fuera de Brasil bajo la LGPD.

Para las bibliotecas establecidas en la UE, la ubicación brasileña
constituye una transferencia fuera de la UE. Esta transferencia se
enmarca en las Cláusulas Contractuales Tipo (CCT 2021/914 módulo 2)
firmadas con Supabase, que constituyen garantía adecuada en los
términos del artículo 46(2)(c) del RGPD.

Brevo y Codeberg están establecides en la UE.

## Artículo 9 — Auditoría

La biblioteca adherente puede solicitar una vez al año una auditoría
o inspección de las medidas tomadas por AnarBib en aplicación del
presente acuerdo. Las modalidades se definen de común acuerdo con
al menos 30 días de preaviso.

AnarBib pone a disposición de la biblioteca:

- El presente acuerdo
- El documento REGISTRE_TRAITEMENTS.md (registro de tratamientos)
- El documento INCIDENT_RESPONSE.md (procedimiento de incidente)
- El código fuente (auditoría por diseño, proyecto de código abierto)

## Artículo 10 — Destino de los datos al final del contrato

Al final del presente acuerdo (rescisión por una u otra parte, o
cese de utilización del servicio por la biblioteca), AnarBib
procederá, según la elección de la biblioteca expresada por escrito:

**Opción A — Restitución**: AnarBib provee a la biblioteca una
exportación completa de los datos en formato estructurado (JSON+CSV)
en un plazo máximo de 30 días.

**Opción B — Eliminación**: AnarBib procede a la eliminación de
todos los datos de la biblioteca en un plazo máximo de 30 días, y
provee un certificado de eliminación.

En caso de ausencia de manifestación de la biblioteca dentro de
los 30 días posteriores al fin del contrato, la opción B
(eliminación) se aplica por defecto.

Las copias de seguridad técnicas que contengan eventualmente esos
datos se reemplazan por rotación en un plazo máximo de 90 días tras
la eliminación principal.

## Artículo 11 — Resolución de conflictos

En caso de divergencia de interpretación o aplicación del presente
acuerdo, las partes se comprometen a buscar prioritariamente una
solución amistosa por mediación. Si la mediación fracasa, cada
parte mantiene su libertad de recurrir a las vías legales aplicables
en su jurisdicción.

No se prevé ninguna cláusula de arbitraje comercial. El presente
acuerdo no constituye una renuncia a los derechos de la biblioteca
o de las personas afectadas previstos por el derecho aplicable.

## Artículo 12 — Firma

**Biblioteca adherente (responsable del tratamiento):**

- Nombre: ____________________________________________
- Slug AnarBib: ____________________________________
- Dirección: ________________________________________
- Correo electrónico de contacto: ___________________
- Persona(s) signataria(s) (coordinador(a/e)s):

  - ______________________________________ (nombre, función)
  - ______________________________________ (nombre, función)

- Lugar y fecha: ____________________________________
- Firma(s):

**AnarBib (encargade del tratamiento):**

- Representade por: Xavier Van Welden, desarrollador principal y
  administrador
- Correo electrónico: contato@anarbib.org
- Lugar y fecha: ____________________________________
- Firma:

---

*Este documento constituye el Acuerdo de Tratamiento de Datos en
los términos del artículo 28 del RGPD y del artículo 39 de la
LGPD. Versión 1.0 — 4 de mayo de 2026. Documento elaborado
colectivamente, distribuido bajo licencia CC-BY-SA-4.0.*
