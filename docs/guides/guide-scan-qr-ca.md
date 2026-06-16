# Guia — Escaneig i QR al AnarBib

> **Per a qui és aquesta guia.** Per a qualsevol camarada de biblioteca que vulgui
> fer servir la càmera del mòbil (o de l'ordinador) per guanyar temps: identificar
> una persona lectora pel carnet, capturar les dades d'un llibre pel codi de barres,
> o verificar el fons. Escrita per encàrrec — i per al **comú** de la xarxa.
>
> **Esperit.** Res d'aquí no et vigila ni t'avalua. La lectura dels codis passa
> **100 % al teu dispositiu**: cap imatge de la càmera no surt a cap lloc. Les
> eines hi són per donar-te autonomia, no per lligar-te. Si alguna cosa no
> funciona, **el catàleg no es trenca mai** — en el pitjor dels casos, n'hi ha
> prou amb escriure-ho a mà.
>
> Forma part del **comú de saber** del suport mutu (vegeu el marc « el suport mutu
> en la catalogació »). S'escriu per comunitat de llengua: si voleu una versió en
> una altra llengua, es fa en paral·lel, no per traducció de dalt a baix.

---

## Què es pot escanejar

El AnarBib té **un sol lector de càmera**, reutilitzat en tres llocs:

| On | Què s'escaneja | Per a què |
|---|---|---|
| **Tauler › Gestionar lector-a-e** | QR del **carnet** | Identificar la persona lectora en un instant |
| **Catalogació** (fitxa del llibre) | **codi de barres ISBN** | Capturar títol/autoria automàticament |
| **Tauler › Inventari** | QR de les **etiquetes d'exemplar** | Verificar el fons (recompte) |

En tots els casos: la càmera s'obre dins del AnarBib, llegeix el codi, i ja està.
No cal instal·lar cap aplicació. Si voleu, podeu **afegir el AnarBib a la pantalla
d'inici** del mòbil (menú del navegador › « Afegir a la pantalla d'inici »):
s'obre en pantalla completa com una app, però continua sent el lloc web.

---

## 1. Carnet de lector-a-e

**Qui crea el carnet:** la mateixa persona lectora, des del seu compte
(`/conta`), quan la biblioteca ha activat la funcionalitat. Genera un QR Code i el
pot descarregar en PNG o PDF. El QR conté només un **codi opac** — cap nom, cap
dada personal a dins.

**Com tu, al taulell, el fas servir:**

1. Vés a **Tauler › Gestionar lector-a-e**.
2. Fes clic a **« Escaneja la targeta »** i apunta la càmera al QR del carnet.
3. El AnarBib resol el codi i mostra **qui és** la persona (i si hi ha alguna
   restricció activa). A punt per prestar, retornar, etc.

> **« Targeta no reconeguda »?** Quasi sempre és un **carnet antic**.
> Quan la persona genera un carnet nou, l'anterior queda **revocat** (mesura de
> seguretat). Demana-li que generi/descarregui el carnet actual. Des del 15/06, el
> propi sistema avisa « targeta substituïda, genera'n una de nova » en aquest cas.

---

## 2. Escanejar l'ISBN en catalogar

En registrar un llibre que té codi de barres (ISBN), es pot evitar d'escriure-ho
tot a mà:

1. A la fitxa del llibre (catalogació), obre el panell de **cerca de metadades**.
2. Fes clic a **« Escaneja l'ISBN »** i apunta al **codi de barres** de la
   contraportada del llibre.
3. El número entra sol al camp ISBN i el AnarBib **cerca les dades** (títol,
   autoria…) a les fonts públiques. Tu les revises i ajustes — el catàleg és teu.

> **Consell sobre el dispositiu.** El codi de barres és més « exigent » que el QR.
> **El mòbil sol llegir molt millor** que la webcam d'un ordinador de sobretaula
> (enfocament i resolució de la càmera). Si la webcam no l'agafa, no insisteixis:
> escriu l'ISBN a mà — és el mateix resultat.

---

## 3. Inventari del fons (recompte)

Verificar, exemplar per exemplar, el que hi ha realment a la prestatgeria —
comparant-ho amb el que el sistema creu que la biblioteca té.

**Abans:** les etiquetes dels exemplars han de tenir **QR Code**. Imprimeix les
etiquetes amb QR a **Catalogació › Etiquetes** (hi ha una opció « Incloure QR
codes »). Cada QR apunta a l'exemplar.

**Fent l'inventari:**

1. Vés a **Tauler › Inventari** (visible per a *bibliotecari-ària-e* i *coordinador-a-e*).
2. **« Iniciar inventari »** — obre una sessió i mostra quants exemplars té la
   biblioteca.
3. La càmera queda oberta: **ves passant els exemplars**, un QR darrere l'altre. A
   cada lectura hi ha un **bip** i el comptador puja. No cal tancar i reobrir la
   càmera entre un llibre i l'altre.
   - ✓ verd = exemplar del fons, comptat.
   - « Ja escanejat » = ja havies passat aquest (sense problema, no compta dues vegades).
   - ⚠ « Fora del fons » = un exemplar que **no pertany** a aquesta biblioteca (intrús).
4. Si algun QR està malmès, es pot **escriure a mà** (URL de l'etiqueta o el número
   d'inventari de l'exemplar).
5. **« Finalitzar i veure l'informe »** — tanca la sessió i mostra:
   - **Presents** (escanejats i del fons),
   - **Faltants** (del fons, però no escanejats → buscar / donar de baixa),
   - **Intrusos** (escanejats, però d'una altra biblioteca / desconeguts).
6. Exporta el resultat en **CSV** (per a full de càlcul) o **PDF** (per imprimir la
   llista de faltants i anar a buscar-los a les prestatgeries).

> **Pausar i reprendre.** Inventari gran? Pots finalitzar-lo més tard. Si en surts
> a mitges, la sessió queda **en curs** i apareix a « Sessions en curs » per a
> **reprendre** d'on s'havia deixat.

---

## Preguntes pràctiques

**Cal instal·lar alguna cosa?** No. És el propi lloc web. Opcionalment, « Afegir a
la pantalla d'inici » per obrir-lo com una app.

**Funciona amb el meu navegador?** Sí. Al Chrome/Android fa servir el lector natiu
(més ràpid). Al **Brave**, **iOS/Safari** i **Firefox** el AnarBib carrega
automàticament un lector alternatiu — de manera que **també hi funciona**. Si
apareix « lectura no compatible » en escanejar l'ISBN amb algun d'aquests, actualitza
la pàgina: el lector alternatiu entra sol.

**La càmera no s'obre.** Verifica si has donat **permís de càmera** al lloc (cadenat
a la barra d'adreces). El navegador només allibera la càmera per **HTTPS** —
`app.anarbib.org` ja ho és.

**Privadesa.** La descodificació és **local**. La imatge de la càmera **no s'envia**
a cap servidor. El QR del carnet guarda només un codi opac; el QR de l'etiqueta
guarda només l'adreça de l'exemplar. Els fons sensibles (BTL i similars) segueixen
protegits per les mateixes regles de sempre.

---

## En una frase

La càmera és **la mà estesa** per estalviar-te escriptura i verificació — no una
obligació. Fes-la servir quan ajudi; ignora-la quan no. I si s'encalla, el teclat
sempre hi és.

---

*Document del comú AnarBib. Millores i versions en altres llengües són
benvingudes, escrites en paral·lel per la comunitat de cada llengua.*
