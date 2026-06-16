# Guía — Escáner y QR en AnarBib

> **Para quién es esta guía.** Para cualquier compañere de biblioteca que quiera
> usar la cámara del móvil (o del ordenador) para ganar tiempo: identificar a une
> lectore por el carnet, obtener los datos de un libro por el código de barras, o
> hacer el inventario del fondo. Escrita a petición — y para le **común** de la red.
>
> **Espíritu.** Nada aquí te vigila ni te evalúa. La lectura de los códigos sucede
> **100 % en tu dispositivo**: ninguna imagen de la cámara sale hacia ningún lugar.
> Las herramientas están ahí para darte autonomía, no para atraparte. Si algo no
> funciona, **nunca rompe el catálogo** — en el peor caso, simplemente se escribe
> a mano.
>
> Parte del **común de saber** del apoyo mutuo en la catalogación (ver el encuadre
> «Apoyo mutuo en la catalogación»). Se escribe por comunidad de lengua: si quieres
> una versión en otra lengua, se hace en paralelo, no por traducción de arriba abajo.

---

## Qué se puede escanear

AnarBib tiene **un solo lector de cámara**, reutilizado en tres lugares:

| Dónde | Qué se escanea | Para qué |
|---|---|---|
| **Panel › Gestionar le lectore** | QR del **carnet** | Identificar a le lectore en un instante |
| **Catalogación** (ficha del libro) | **código de barras ISBN** | Obtener título/autoría automáticamente |
| **Panel › Inventario** | QR de las **etiquetas de ejemplar** | Revisar el fondo (recuento) |

En todos los casos: la cámara se abre dentro de AnarBib, lee el código, y listo.
No hace falta instalar ninguna aplicación. Si quieres, puedes **añadir AnarBib a
la pantalla de inicio** del móvil (menú del navegador › «Añadir a la pantalla de
inicio»): se abre en pantalla completa como una app, pero sigue siendo el sitio web.

---

## 1. Carnet de lectore

**Quién crea el carnet:** le propie lectore, en su cuenta (`/conta`), cuando
la biblioteca ha activado la función. Genera un QR Code y puede descargarlo en PNG
o PDF. El QR almacena únicamente un **código opaco** — ningún nombre, ningún dato
personal dentro de él.

**Cómo usarlo, en el mostrador:**

1. Ve a **Panel › Gestionar le lectore**.
2. Haz clic en **«Escanear la tarjeta»** y apunta la cámara hacia el QR del carnet.
3. AnarBib resuelve el código y muestra **quién es** le lectore (y si existe alguna
   restricción activa). Listo para prestar, devolver, etc.

> **¿«Carnet no reconocido»?** Casi siempre es un **carnet antiguo**.
> Cuando une lectore genera un carnet nuevo, el anterior queda **revocado** (medida
> de seguridad). Pídele que genere o descargue el carnet actual. Desde el 15/06, el
> propio sistema avisa «carnet sustituido, genera uno nuevo» en ese caso.

---

## 2. Escanear el ISBN al catalogar

Al registrar un libro que tiene código de barras (ISBN), puedes evitar escribir todo
a mano:

1. En la ficha del libro (catalogación), abre el panel de **búsqueda de metadatos**.
2. Haz clic en **«Escanear ISBN»** y apunta hacia el **código de barras** en la
   contraportada del libro.
3. El número entra solo en el campo ISBN y AnarBib **busca los datos** (título,
   autoría…) en las fuentes públicas. Tú revisas y ajustas — el catálogo es tuyo.

> **Consejo de dispositivo.** El código de barras es más «exigente» que el QR.
> **El móvil suele leer mucho mejor** que la webcam de un ordenador de mesa (enfoque
> y resolución de la cámara). Si la webcam no lo capta, no insistas: escribe el ISBN
> a mano — el resultado es el mismo.

---

## 3. Inventario del fondo (recuento)

Verificar, ejemplar por ejemplar, lo que hay realmente en la estantería — comparándolo
con lo que el sistema cree que tiene la biblioteca.

**Antes:** las etiquetas de los ejemplares deben tener **QR Code**. Imprime las
etiquetas con QR en **Catalogación › Etiquetas** (hay una opción «Incluir QR codes»).
Cada QR apunta al ejemplar correspondiente.

**Haciendo el inventario:**

1. Ve a **Panel › Inventario** (visible para les roles *librarian* y *coordinadore*).
2. **«Iniciar inventario»** — abre una sesión y muestra cuántos ejemplares tiene
   la biblioteca.
3. La cámara permanece abierta: **ve pasando los ejemplares**, un QR tras otro. En
   cada lectura suena un **bip** y el contador sube. No hace falta cerrar y abrir
   la cámara entre un libro y otro.
   - ✓ verde = ejemplar del fondo, contado.
   - «Ya leído» = ya lo habías pasado antes (sin problema, no cuenta dos veces).
   - ⚠ «Fuera del fondo» = un ejemplar que **no pertenece** a esta biblioteca (intruso).
4. Si algún QR está dañado, puedes **escribir a mano** (URL de la etiqueta o el
   número del ejemplar).
5. **«Finalizar y ver el informe»** — cierra la sesión y muestra:
   - **Presentes** (escaneados y del fondo),
   - **Faltantes** (del fondo, pero no escaneados → buscar / dar de baja),
   - **Intrusos** (escaneados, pero de otra biblioteca / desconocidos).
6. Exporta el resultado en **CSV** (para hoja de cálculo) o **PDF** (para imprimir
   la lista de faltantes y buscarlos por las estanterías).

> **Pausar y retomar.** ¿Inventario grande? Puedes cerrar después. Si sales a mitad,
> la sesión queda **en curso** y aparece en «Sesiones en curso» para **reanudarla**
> desde donde la dejaste.

---

## Preguntas prácticas

**¿Tengo que instalar algo?** No. Es el propio sitio web. Opcionalmente, «Añadir a
la pantalla de inicio» para abrirlo como app.

**¿Funciona en mi navegador?** Sí. En Chrome/Android usa el lector nativo (más
rápido). En **Brave**, **iOS/Safari** y **Firefox**, AnarBib carga automáticamente
un lector alternativo — así que **también funciona** en ellos. Si aparece «lectura
no compatible» al escanear el ISBN en alguno de esos, recarga la página: el lector
alternativo entra solo.

**La cámara no abre.** Verifica que hayas dado **permiso de cámara** al sitio
(candado en la barra de dirección). El navegador solo libera la cámara en **HTTPS**
— `app.anarbib.org` ya lo es.

**Privacidad.** La decodificación es **local**. La imagen de la cámara **no se envía**
a ningún servidor. El QR del carnet guarda solo un código opaco; el QR de la etiqueta
guarda solo la dirección del ejemplar. Los fondos sensibles (BTL y similares) siguen
protegidos por las mismas reglas de siempre.

---

## En una frase

La cámara es **una mano tendida** para ahorrarte escritura y revisión — no una
obligación. Úsala cuando ayude; ignórala cuando no. Y si se bloquea, el teclado
siempre está ahí.

---

*Documento del común AnarBib. Mejoras y versiones en otras lenguas son bienvenidas,
escritas en paralelo por la comunidad de cada lengua.*
