# AnarBib — Manual de uso
## Red de bibliotecas libertarias

*Versión 1.1 — Septiembre 2026*

---

## 1. Primeros pasos

### Conectarse
Ve a la URL de tu instancia de AnarBib y haz clic en **Entrar** (o en el botón de inicio de sesión en el idioma de tu interfaz). Escribe tu correo electrónico y tu contraseña.

### Cambiar el idioma
Le selectore de idioma se encuentra en la parte superior derecha de cada página (🇧🇷🇵🇹 / 🇫🇷 / 🇪🇸 / 🇬🇧 / 🇮🇹 / 🇩🇪 / 🇳🇱 / 🇬🇷 / Català / Esperanto). La elección se guarda localmente.

### Buscar en el catálogo
El **Catálogo** muestra una línea por obra, en el idioma de tu interfaz cuando el título ha sido traducido: autore, título, número de ediciones y bibliotecas que la tienen.
1. Haz clic en **Ver las ediciones** (el « + » de la línea): cada edición aparece debajo, con su portada, su editorial y su año. Los tomos de una obra en varios volúmenes van numerados y ordenados.
2. Haz clic en **Ejemplares por biblioteca**: la disponibilidad se muestra biblioteca por biblioteca. Si has iniciado sesión, « tu biblioteca » queda señalada; lo que está disponible en otro sitio pero no para ti se dice tal cual.
3. El botón **Lista plana** vuelve a una línea por edición; la elección se memoriza.

---

## 2. Lectore — Mi cuenta

### Reservar un documento
1. Busca el documento en el **Catálogo**
2. Haz clic en su ficha
3. Si el documento está disponible, haz clic en **Reservar un préstamo**
4. También puedes ir a la pestaña **Reservas** de tu cuenta e introducir la referencia local

### Seguir los préstamos
La pestaña **Préstamos en curso** muestra tus préstamos activos con:
- La fecha de salida y el vencimiento
- Un botón **Renovar** (si la renovación está autorizada)
- La indicación de posible retraso

### Renovar un préstamo
Haz clic en **Renovar** en la lista de tus préstamos. La renovación puede ser denegada si:
- El préstamo ya ha sido renovado una vez
- El préstamo está en retraso
- Otre lectore ha reservado el mismo documento

### Banda de estado de la cuenta
En la parte superior de la página **Mi cuenta**, una banda de color indica el estado de tu cuenta:
- ✓ **Verde**: Cuenta activa, todo va bien
- ⚠ **Naranja**: Atención (préstamo en retraso, contraseña a cambiar)
- ⛔ **Rojo**: Cuenta restringida (contacta con tu biblioteca)

### Historial
La pestaña **Historial** lista tus antiguas reservas y préstamos. Puedes hacer clic en el título para ver la ficha del documento, y **Ocultar** las entradas que no quieras ver.

### Proteger tu cuenta: la autenticación en dos pasos
Después de la contraseña, AnarBib puede pedir un código de seis cifras que cambia cada 30 segundos. Ese código viene de una aplicación de autenticación libre, que funciona sin conexión: Aegis o FreeOTP+ en Android, FreeOTP o 2FAS en iPhone, KeePassXC en el ordenador. Ni SMS ni servicio externo.

**Obligatoria para los equipos a partir del 1 de enero de 2027** (administración de la red, coordinaciones, equipos de biblioteca); opcional para las cuentas de lectura.

Para activarla:
1. Abre **Mi cuenta → Datos personales**. Debajo del cambio de contraseña, haz clic en **Activar la autenticación en dos pasos**.
2. Da un nombre al dispositivo (por ejemplo «Móvil») y escanea el código QR con la aplicación. Sin cámara, escribe a mano la clave que aparece.
3. Escribe el **código de seis cifras** que muestra la aplicación y haz clic en **Confirmar**.

A partir de ahí, AnarBib te pide el código después de la contraseña en cada inicio de sesión. Si registraste varios dispositivos, elige el que tengas a mano.

- **Registra un segundo dispositivo** (KeePassXC además del móvil, por ejemplo): es la única forma de no quedarte sin acceso si pierdes uno.
- **¿Perdiste el dispositivo?** Contacta con la administración de la red (Matrix o anarbib@proton.me). Tras verificar tu identidad por otro medio, quita tus dispositivos; registras uno nuevo en el siguiente inicio de sesión.
- Para quitar un dispositivo, haz clic en **Quitar** junto a su nombre.
- Una cuenta de equipo sin dispositivo después del 1 de enero de 2027 tendrá que registrar uno al iniciar sesión antes de seguir.
- Nadie de AnarBib te pedirá nunca tu código ni tu código QR.

---

## 3. Bibliotecarie — Panel de control

### Trabajo del día
El panel de control genera automáticamente las tareas prioritarias:
- Recogida planificada hoy
- Nuevas reservas a gestionar
- Reservas listas para recoger
- Préstamos en retraso
- Devoluciones previstas hoy
- Consultas en sala a gestionar

### Gestionar las reservas
La pestaña **Reservas** permite:
- Seleccionar varias reservas (casillas de verificación)
- Aplicar un paso en lote (preparar, planificar la recogida, confirmar)
- Cancelar reservas

### Gestionar los préstamos
- **Crear un préstamo**: introducir el ID o el correo electrónico de le lectore + las referencias locales
- **Devolución total**: introducir el ID del préstamo
- **Devolución parcial**: introducir los IDs de les ejemplares individuales
- **Préstamos agrupados**: vista sintética por préstamo

### Gestionar une lectore
La pestaña **Gestionar lectore** permite:
- Buscar por ID público, correo electrónico o nombre
- Modificar el perfil (nombre, correo electrónico, teléfono, género, dirección)
- **Restringir el acceso** (con motivo: no devolución, etc.)
- **Levantar la restricción**

---

## 4. Catalogado

### Crear una ficha de documento
1. Ir a **Catalogado** > pestaña **Documento**
2. Seleccionar el **tipo de material** (Libro, Periódico, Panfleto, Audio, etc.)
3. Rellenar los campos (el modo Simple muestra lo esencial, el modo Completo todos los campos)
4. Usar **Buscar metadatos** para pre-rellenar vía ISBN
5. **Guardar el borrador**

### Obra, ediciones y tomos
Una obra reúne todas las ediciones de un mismo texto. En la ficha de un documento, el bloque **Obra** permite:
- **Vincular a otra obra**: buscar la obra por su título y luego **Vincular**. La obra abandonada desaparece si queda vacía.
- **Títulos por idioma**: un título por idioma de la interfaz. Los títulos marcados « traducción automática — corrígeme » los propuso la máquina: reléelos y haz clic en **Guardar** para confirmarlos.
- **Título uniforme**: el título de referencia de la obra, escrito en el idioma de origen de la propia obra, no en el de una traducción.
- **Tomo / volumen**: el número del tomo cuando la obra tiene varios volúmenes. Los tomos se quedan en una sola obra.

### Asistente de deduplicación: obras escindidas y volúmenes
En el **Asistente de deduplicación** (Catalogación), dos pestañas completan los duplicados de registros:
- **Obras escindidas**: dos obras que parecen ser el mismo texto. **Fusionar en « … »** las reúne; **Mantener separadas** memoriza la decisión y el par no vuelve.
- **Volúmenes**: registros que parecen ser los tomos de una misma obra. Marca **Reunir este registro** para cada tomo elegido, escribe su número y valida; un grupo resuelto no vuelve más.

Ninguna fusión ni ningún número de tomo los pone la máquina: cada gesto es tuyo.

### Tipos de documentos y campos especializados
Cada tipo de documento muestra campos adaptados:
- **Periódico**: volumen, número, fascículo, periodicidad, ISSN
- **Panfleto**: campaña, organización emisora, fecha aproximada, formato físico
- **Audio**: duración, soporte, formato técnico, participantes
- **Audiovisual**: duración, realización, subtítulos
- **Recurso digital**: URL, condición de acceso, restricción
- **Dossier**: alcance, período, organizaciones, contexto político

### Traducir las biografías de autores
En la pestaña **Autore**, cuando editas une autore publicade:
1. Abre el panel **Traducciones de la biografía**
2. Escribe la biografía en cada idioma deseado
3. Haz clic en **Guardar las traducciones**

### Imprimir etiquetas
En la pestaña **Indexación**, bajo el formulario de ejemplar:
1. Filtra y selecciona les ejemplares
2. Haz clic en **Imprimir X etiqueta(s)**
3. Se abre un documento A4 con 21 etiquetas por página (7×3)

---

## 5. Administración

### Gestión de la biblioteca
La página **Gestión de la biblioteca** permite configurar:
- Identidad (nombre, ciudad, contacto)
- Comunicaciones (correos electrónicos, modos de envío, tipos de notificación)
- Reglamento (subida de PDF, reglas de circulación)
- Equipo, intercambios inter-bibliotecas, informes

### Gestión de la red
La página **Red** (accesible a les coordinadores y administradores) permite:
- Ver la vista general (estadísticas globales)
- Gestionar las solicitudes de bibliotecas
- Administrar les miembros de la red
- Promover administradores

### Autenticación en dos pasos de los equipos
La pestaña **Autenticación en dos pasos** de la página **Red**, reservada a la administración de la red, lista las cuentas de equipo activas y las que eligieron la autenticación en dos pasos, con sus papeles y su número de dispositivos; las que no tienen dispositivo aparecen primero. También muestra la exigencia vigente.

Para ayudar a una persona que perdió su dispositivo: verifica primero su identidad por otro medio (en persona, Matrix), luego haz clic en **Quitar sus dispositivos**, indica el motivo (cómo se verificó la identidad) y haz clic en **Quitar y cerrar sesión**. La sesión de la cuenta se cierra en todas partes y la operación queda registrada. Este gesto exige que tu propia sesión haya pasado por el código.

---

## 6. Idiomas disponibles

La interfaz está disponible en 10 idiomas:
- 🇧🇷🇵🇹 Português (idioma de referencia)
- 🇫🇷 Français
- 🇪🇸 Castellano
- 🇬🇧 English
- 🇮🇹 Italiano
- 🇩🇪 Deutsch
- 🇳🇱 Nederlands
- 🇬🇷 Ελληνικά
- Català
- Esperanto

Las biografías de autores pueden traducirse de forma independiente en cada idioma.

Los títulos de las obras se pretraducen automáticamente a los diez idiomas; llevan la mención « corrígeme » hasta que una persona los relea.

---

*AnarBib — Red de bibliotecas libertarias*
*Software libre para la gestión cooperativa del saber militante*
