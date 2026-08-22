# Fitxa — Escriure un nom, escriure un títol

> **Traducció per revisar.** Aquesta versió s'ha traduït del francès perquè
> existís ara i no d'aquí a sis mesos. Si llegeixes aquesta llengua millor del
> que l'escriu la traducció, corregeix-la: és un comú, no un text tancat.

> **A qui s'adreça aquesta fitxa.** A tu que catalogues. Recull el que es
> decideix a l'hora d'escriure: com s'escriu un nom, on tallar una partícula,
> què fer amb una col·lectivitat, i per què un camp buit val més que un camp
> endevinat.
>
> El *perquè* detallat és en un altre lloc, al registre de decisions, secció
> `CONV`. Aquí, es cataloga.

## La regla, en una frase

**Una sola veritat a la base, diverses presentacions.** Tu escrius la forma de
catalogació; les majúscules, l'ordre nom-cognom i els formats bibliogràfics es
**calculen** en mostrar i en exportar. No els escriguis mai a mà.

D'aquí ve tot el desordre que estem reparant: el punt d'accés, la forma de
visualització i la forma d'exportació es van allotjar **en el mateix camp**, en
moments diferents, per mans diferents.

---

## 1. El nom d'una persona

### La forma d'ordenació és la que val

El camp **«Forma d'ordenació»** és la veritat. La **«Forma estàndard»** en
deriva automàticament, per simple inversió de la coma. Mai a l'inrevés.

| Escrius a «Forma d'ordenació» | L'aplicació mostra |
|---|---|
| `Kropotkin, Piotr` | Piotr Kropotkin |
| `Malatesta, Errico` | Errico Malatesta |

### Caixa natural, mai en majúscules

**`Kropotkin, Piotr` — mai `KROPOTKIN, Piotr`.**

Les majúscules del cognom són una **norma de referència bibliogràfica** (ABNT),
no una dada. S'afegeixen en exportar, sobre la marxa. Escriure-les tu no les fa
més certes: destrueix la informació de caixa, que després no es reconstitueix —
`de Sousa` i `De Sousa` deixen de ser distingibles un cop tot en majúscules.

### On tallar: la partícula

**Decideix la llengua del NOM, no el país de naixement.** Una persona argentina
pot dur un nom italià.

| Llengua del nom | La partícula… | Exemple |
|---|---|---|
| portuguès, francès | **va al final**, després del nom de fonts | `Sousa, Manuel Joaquim de`<br>`Beauvoir, Simone de`<br>`Jong, Rudolf de` |
| italià modern, afrikaans, neerlandès | **es manté al davant** | `Di Filippo, Luis`<br>`De Amicis, Edmondo`<br>`Van der Walt, Lucien` |

Luis Di Filippo és el cas de manual: argentí, nom italià, per tant
`Di Filippo, Luis` — i no `Filippo, Luis Di`.

> **En català**, el cognom doble no es talla i la conjunció es manté:
> `Serra i Húnter, Jaume`.

### El que l'eina no sap decidir

**Cognom doble o nom compost?** `García Lorca` és un cognom doble castellà (no
es talla); `Jean-Marie` és un nom compost. Cap funció no distingeix les dues
coses. En cas de dubte, **pregunta** en comptes de decidir: és exactament
aquest tipus de cas el que va a la cua de verificació.

---

## 2. Una col·lectivitat no és una persona

**Un nom de col·lectiu no té forma invertida.**

| ✅ | ❌ |
|---|---|
| `Grupo Krisis` | `Krisis, Grupo` |
| `Instituto de Estudos Libertários` | `Libertários, Instituto de Estudos` |
| `CIRA Marseille` | `Marseille, CIRA` |

### Omple «Tipus d'autoritat»

El camp existeix i **governa la regla**. Marcat com a *Col·lectivitat*,
impedeix la inversió. Deixat buit, res no protegeix el registre: serà tractat
com una persona en el primer pas de l'eina.

Són tres segons que estalvien tres mesos de correcció.

### Si el registre conté DIVERSES persones

Passa — la importació en va fabricar. `KAISER, William Young and David E.` no
és un Kaiser amb dos noms: són **William Young** *i* **David E. Kaiser**, dos
autors d'un mateix llibre.

**No ho reparis sobre la marxa.** Un registre d'autoritat el comparteix tota la
xarxa: reanomenar-lo només desplaça l'error. Passa pel Taller d'autoritats,
proposta de tipus **Escissió**: el registre d'origen es conserva, els altres es
creen, i els enllaços amb els llibres els segueixen. Termini de deliberació:
catorze dies, com una fusió.

---

## 3. El títol

### La caixa depèn de la llengua del títol

**No** hi ha regla universal. L'alemany escriu amb majúscula els seus
substantius: és la seva **ortografia**, no un error d'escriptura.

L'eina de normalització només abaixa les **paraules funcionals de la llengua
del títol**, en posició no inicial. Preserva:

- la **primera paraula**;
- les paraules després de **puntuació forta** (`.` `:` `;` `?` `!` i el guió de
  subtítol);
- les **sigles**.

**Retira un artefacte d'importació, no «recasa» el títol.** Quan et proposa una
correcció, continues sent tu qui jutja si una paraula és nom propi — l'eina no
ho sap.

| Abans | Després |
|---|---|
| `Antologia Do Movimento Operário Gaúcho` | `Antologia do Movimento Operário Gaúcho` |
| `Der Einzige Und Sein Eigentum` | `Der Einzige und sein Eigentum` |

### L'article inicial: no mutilis mai el títol

`Els Treballadors` s'escriu **`Els Treballadors`**. No `Treballadors, Els` —
això és una resta de la fitxa de cartró — i no `Treballadors` tot sol.

L'ordenació es resol amb un **comptador de caràcters no ordenables** (aquí: 4,
per `Els `), que deixa el títol intacte.

---

## 4. La llengua i el país

| Camp | Format | Exemples |
|---|---|---|
| **Llengua** (del document) | codi BCP-47 | `pt-BR`, `fr`, `es`, `de`, `it` |
| **País** (de l'autoritat) | codi ISO 3166-1 α-2 | `BR`, `FR`, `ES`, `NL` |

Ni `català`, ni `Catalunya`, ni `cat`. El selector de l'aplicació et dona el
codi correcte: fes-lo servir en comptes d'escriure.

**Un buit continua buit.** Si no coneixes la llengua, deixa-ho en blanc. Una
llengua desconeguda és una informació honesta; una llengua errònia governa
després la caixa del títol i la regla d'entrada del nom — propaga l'error en
comptes de contenir-lo.

---

## 5. Les dates

Dos nombres enters i un **qualificador**:

| Qualificador | Quan |
|---|---|
| `exact` | la data està establerta |
| `circa` | aproximada («cap al 1876») |
| `uncertain` | les fonts divergeixen |
| `unknown` | no se sap |
| `living` | **la persona és viva** |

`living` no és un detall de comoditat: sense ell, «encara viva» i «data de mort
desconeguda» es confonien — cosa que equivalia a fer morir gent al catàleg.

Quan naixement i mort són tots dos desconeguts, fes servir el **període
d'activitat** («actiu 1900-1910»). I quan les fonts es contradiuen, escriu-ho a
la **nota de dates**: és reparació historiogràfica, no farciment.

---

## 6. El que no et toca decidir tot sol o tota sola

El corpus d'autoritats el **comparteix tota la xarxa**. Modificar un registre
és modificar el catàleg de diverses biblioteques.

| Gest | On passa |
|---|---|
| corregir una errada en un registre | directament |
| **fusionar** dos registres duplicats | Taller — proposta, 14 dies |
| **escindir** un registre que en conté dos | Taller — proposta, 14 dies |
| decidir una caixa o un cognom proposat per l'eina | cua de verificació |

Al Taller, una proposta queda oberta el temps necessari perquè les altres
biblioteques puguin objectar. Aquest termini no és lentitud administrativa: és
el que fa que el corpus continuï sent comú.

---

## En cas de dubte

**Deixa-ho buit en comptes d'endevinar.**

Un camp buit planteja una pregunta — algú la veurà i la respondrà. Un camp fals
respon a una pregunta que ningú no ha fet, i sembla correcte. És aquest el que
retrobem tres mesos després, copiat a cinc catàlegs.
