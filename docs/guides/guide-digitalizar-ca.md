# Fitxa — Digitalitzar una obra

> **Traducció per revisar.** Aquesta versió s'ha traduït del francès perquè
> existís ara i no d'aquí a sis mesos. Si llegeixes aquesta llengua millor del
> que l'escriu la traducció, corregeix-la: és un comú, no un text tancat.

> **A qui s'adreça aquesta fitxa.** A tu que ets davant l'escàner. Cap en una
> pàgina i només conté el que es decideix a l'hora d'escanejar: els tres
> ajustos, els cinc controls, i el destí dels fitxers.
>
> El *perquè* és en un altre lloc, a la decisió
> `DECISION_profil_numerisation_2026-08-20`. Aquí, es fa.

## La regla, en una frase

**Es captura en escala de grisos, es lliura en bitonal, només es manté en línia
allò que es lliura.**

---

## 1. Abans d'escanejar — què tenim dret a digitalitzar?

| L'obra és… | El que escaneges |
|---|---|
| **de domini públic** | tota l'obra |
| **cedida per qui l'ha escrita**, o amb **llicència lliure** | tota l'obra |
| **sota drets** | **la coberta, i res més** |

En cas de dubte, **només la coberta**. Sempre es pot digitalitzar més
endavant; retirar un fons sencer publicat per error, molt menys fàcilment.

> **Escriu per què.** En el moment de la pujada, el camp de justificació
> espera una frase: nom de qui ho ha escrit i data de mort, referència de la
> llicència, o enllaç a la cessió escrita. **És aquesta frase la que protegeix
> la biblioteca, no la casella marcada.** Si no saps què escriure-hi, és que
> l'estatus no està establert — posa-hi `sob_direitos` i pregunta.

---

## 2. Els tres ajustos

| El que tens al davant | Ajust |
|---|---|
| Text imprès ordinari | **Escala de grisos — 300 ppp** |
| Cossos petits, notes, paper esgrogueït o malmès | **Escala de grisos — 400 ppp** |
| Gravats, cartells, fulls volants, premsa il·lustrada, cobertes | **Color — 300 ppp** |

**Mai en blanc i negre directament.** L'escàner t'ho proposarà — sovint és el
seu ajust de fàbrica. Refusa-ho. El pas a blanc i negre és irreversible: un
gris convertit en blanc no torna, i sobre paper esgrogueït s'emporta pàgines
senceres, els segells i les anotacions manuscrites.

El criteri per al color: **la matèria és ella mateixa el document?** Un cartell,
sí. Un capítol de text, no.

---

## 3. Després de la captura

El PDF pujat no és la captura: en **deriva**, pàgina a pàgina — text en
bitonal, il·lustracions en gris o en color. Una obra de 200 pàgines
majoritàriament textual pesa aleshores entre 8 i 15 MB.

> **La cadena escollida: ScanTailor Advanced, després `img2pdf`.** El primer
> redreça, retalla i separa el text de les il·lustracions, pàgina per pàgina;
> el segon acobla el resultat en PDF sense recodificar-lo.
>
> Agafa bé **Advanced**: «ScanTailor» designa també una versió abandonada, que
> no té el mode mixt que necessitem aquí.
>
> **Els ajustos precisos arribaran a aquesta fitxa** un cop provada la cadena
> en deu obres. Fins llavors, pregunta a la teva biblioteca — i en tot cas, no
> pugis mai les captures en brut.

Dos camps que no s'han de fallar en pujar:

- **Estatus de drets** — una llista tancada de quatre opcions: *Domini públic*
  · *Cessió de drets (autorització escrita)* · *Llicència lliure (CC,
  copyleft…)* · *Sota drets — només coberta*. No s'accepta res més, i el camp
  **Justificació de drets** just al costat espera la teva frase.
- **Accés** — dues opcions: *Públic* o *Compte actiu (restringit)*. Per a una
  obra lliure, ha de ser **Públic**. El formulari de catalogació ja el proposa
  en *Públic*: comprova simplement que hi hagi quedat. En canvi, un recurs
  creat **fora del formulari** (importació, pujada automàtica) arriba en
  *Compte actiu* — exactament el contrari del que volem d'una obra de domini
  públic. Si passes per una importació, controla aquest camp després.

---

## 4. Els cinc controls

Sobre **tres pàgines a l'atzar**, a ull, abans de pujar:

1. **Cap caràcter menjat** — accents i puntuació fina inclosos.
2. **Segells, ex-libris i anotacions manuscrites llegibles.**
3. **Les il·lustracions no han passat a blanc i negre** per error.
4. **La pàgina és dreta i completa** — cap marge retallat, cap
   enquadernació negra que sobresurti.
5. **El text és seleccionable** en un lector de PDF: la capa OCR hi és.

**Un sol punt que falla → es refà a partir de la captura.** És precisament per
això que la conservem fins a la validació.

---

## 5. Què se'n fa, dels fitxers de captura?

**No pugen mai al servidor.** Es queden a casa teva o a la biblioteca, en un
disc extern, el temps de validar el lliurament.

**Després, s'esborren.** És la regla de la xarxa: sense arxivament sistemàtic
de les captures.

> **El que això et canvia.** Mentre la captura existeix, un lliurament fallit
> es refà en deu minuts. Un cop esborrada, cal tornar a treure l'obra del
> prestatge i redigitalitzar-la pàgina a pàgina. **Els cinc controls de dalt
> són, doncs, la teva darrera oportunitat — fes-los abans d'esborrar, no
> després.**

**Una excepció, que et toca reconèixer**: una obra rara, fràgil o única, que no
es podria redigitalitzar sense risc per a l'objecte. Aleshores, guarda la
captura. La regla apunta al corrent, no a l'irreemplaçable.

---

## En una frase

Escaneja en gris, refusa el blanc i negre, verifica tres pàgines, guarda la
captura fins que el PDF estigui validat. La resta s'aprèn fent-ho.

---

*Document del comú AnarBib. Aquesta versió és una traducció: corregeix-la si
la teva llengua mereix quelcom millor — és així com esdevé nostra.*
