# El tesaurus FICEDL a AnarBib — consultar un vocabulari comú

> **Per a qui és?** Per a tot·a companyx que catalogui i vulgui vincular els seus
> llibres al **vocabulari de matèries compartit** del moviment — el que manté la
> FICEDL. Aquesta guia explica què és aquest tesaurus, en quines condicions
> AnarBib s'hi connecta, per a què serveix, i com fer-lo servir dia a dia.
>
> **Esperit.** AnarBib **consulta** el tesaurus; no se l'apropia. El vocabulari
> segueix sent el de la FICEDL, que n'és la font **de referència**. Res, aquí,
> crea una versió rival: la nostra còpia només és un *reflex* fidel.

---

## Què és el tesaurus FICEDL?

La **FICEDL** — Federació internacional dels centres d'estudis i documentació
llibertaris — federa des de 1979 CIRA, ateneus, CCL i biblioteques anarquistes
de tot el món. Manté un **tesaurus**: un *vocabulari controlat* de la
documentació llibertària — una llista raonada de **termes de matèria** (els
temes), organitzats i traduïts, per descriure allò de què *parlen* els
documents. Cobreix les mateixes **deu llengües** que AnarBib (exactament les
que ofereix el CIRA de Lausana) i aplega diversos centenars de termes (de
l'ordre de sis-cents). Es pot consultar públicament a `thesaurus.ficedl.info`.

Un tesaurus no és un simple diccionari: és un **graf de conceptes**. Els termes
s'hi relacionen (més ampli · més estret · associat) i porten **notes
d'aplicació** que expliquen com fer-los servir. AnarBib es recolza en **SKOS**,
l'estàndard lliure del web semàntic per a aquest tipus de vocabulari.

## En quines condicions ha entrat a AnarBib

Adoptar un vocabulari comú és, primer de tot, una **decisió política** — la de
col·lectius que trien parlar la mateixa llengua documental — i la tècnica s'hi
adapta. Concretament, AnarBib va importar el tesaurus **des del lloc de la
FICEDL** (`thesaurus.ficedl.info`) **cap al 24 de juny de 2026**, tot important
els seus **termes** i els seus **llocs** (les entrades geogràfiques) — i deixant
de banda les **dates** (les entrades cronològiques). Aquesta connexió segueix
uns quants **principis clars**, que són les *bases de l'acord*:

1. **Font canònica única.** El tesaurus que *fa fe* és el de la FICEDL. AnarBib
   no posseeix *el* tesaurus: en té una còpia de treball.
2. **Cap bifurcació (fork).** La nostra còpia és un **reflex** de la versió
   FICEDL, mai una versió rival. La interoperabilitat que la FICEDL desitja
   queda així garantida *per construcció*.
3. **Consultar, no modificar.** AnarBib **no toca** els mots triats per la
   FICEDL. Una única llibertat, i només de la nostra banda: **recol·locar una
   etiqueta de llengua mal classificada** (una traducció classificada sota un
   codi de llengua erroni), únicament per no *perdre* una traducció que ja
   existeix — sense mai canviar el terme en si.
4. **Assenyalar, no corregir.** Qualsevol altra anomalia — una llengua que
   falta, una errada en un terme — **no** es rectifica aquí: es **notifica** a
   la FICEDL, que corregeix *la seva* versió de referència.
5. **Resincronització.** Després de les correccions de la FICEDL, AnarBib
   **resincronitza** la seva còpia. El reflex s'actualitza; mai divergeix.
6. **Vocabulari lliure i compartit.** El tesaurus es pot **compartir
   lliurement** (cap dret propietari el tanca). La seva evolució es fa
   **col·lectivament**, precisament per *limitar les bifurcacions* i preservar
   la interoperabilitat entre biblioteques.
7. **Evolució portada pel col·lectiu.** Algunes zones del vocabulari necessiten
   actualitzar-se (per exemple les categories relacionades amb les temàtiques
   LGBTQI+). Aquestes evolucions no es decreten des de dalt: es discuteixen
   **dins la federació**.

En resum: el tesaurus continua sent **100% de la FICEDL**; AnarBib n'és un
mirall lleial, i un **enllaç** que fa arribar allò que hi detecta.

## Per a què serveix

- **Descriure pel tema.** En catalogar, el camp **«Matèries (autoritat)»**
  vincula un document a un o diversos termes del tesaurus. És això el que
  permet trobar un llibre per **allò de què parla**, no només pel títol o
  l'autoria.
- **Navegar per tema.** Aquests termes alimenten les **facetes** i la navegació
  temàtica del catàleg públic.
- **Parlar deu llengües alhora.** Un mateix concepte porta la seva etiqueta en
  cadascuna de les deu llengües: una lectora hispanoparlant i un lector
  grecoparlant arriben a **el mateix tema**, cadascun·a en la seva llengua.
- **Vincular les biblioteques.** Com que tothom es recolza en el **mateix**
  vocabulari, els catàlegs esdevenen comparables i intercanviables — és la
  base de la mutualització (duplicats, préstecs interbibliotecaris,
  metacatàleg).

## Com fer-lo servir concretament

1. **Cerca un terme a «Matèries».** En catalogar, comença a escriure al camp
   **Matèries**: AnarBib proposa els termes del tesaurus, amb la seva
   jerarquia. Reutilitza el que ja existeix en lloc d'inventar-ne.
2. **Tria la granularitat adequada.** Ni massa ampli, ni massa estret: el
   terme que *algú faria servir per cercar* aquest llibre. Dos a quatre temes
   solen ser suficients.
3. **Llegeix la nota d'aplicació** si el terme en té una: hi diu com fer-lo
   servir.
4. **Etiqueta que falta en la teva llengua (⚐).** Si un tema encara no té
   etiqueta **en la teva llengua**, es mostra per **reserva** (sovint en una
   altra llengua) amb un ⚐. No és un error: és una **mancança de la versió de
   referència**. No s'apedaça aquí — vegeu més avall.
5. **Un error, una mancança? Assenyala-ho, no ho corregeixis.** Terme erroni,
   traducció absent: **fes-ho arribar a la coordinació**, que ho transmetrà a
   la FICEDL. La correcció es fa sobre la font canònica, i ens torna després
   per resincronització. *(Única excepció, ja esmentada: una etiqueta de
   llengua simplement mal classificada es pot recol·locar de la nostra banda,
   sense tocar el mot.)*
6. **Necessites un terme que no existeix?** El tesaurus no s'amplia
   *localment*. De moment, les **paraules clau lliures** (text lliure, propi
   de la fitxa) són la vàlvula d'escapament — vegeu la guia «Indexar per
   tema». A mitjà termini, una proposta d'addició **puja al col·lectiu** de la
   FICEDL.

## L'esperit: consultar, no capturar

Aquesta connexió és **la mà estesa**, no una presa: AnarBib *pren prestat* un
vocabulari comú sense apropiar-se'l, el *reflecteix* sense *fixar-lo*, i
*retorna* a la FICEDL allò que hi observa. El tesaurus continua viu allà on ha
d'estar-ho — a la federació que el sosté — i el nostre catàleg se'n beneficia
sense mai fer-li competència. Aquesta és, a nivell dels mots, la mateixa ètica
que arreu a AnarBib: **oferir i vincular, mai capturar**.

> Vegeu també: la guia **«Indexar per tema»** (el gest concret en catalogar) i
> el marc **«Ajuda mútua en la catalogació»** (el comú de coneixement del qual
> aquest vocabulari n'és el cor). El tesaurus de referència es pot consultar a
> `thesaurus.ficedl.info` — font canònica de referència.

*Document del comú AnarBib. El tesaurus en si és obra de la FICEDL; aquesta
guia només n'explica l'ús dins AnarBib.*
