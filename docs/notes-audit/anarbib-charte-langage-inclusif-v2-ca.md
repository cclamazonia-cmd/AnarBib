# Carta de llenguatge inclusiu d'AnarBib

**Versió** : 2.0
**Data** : 2026-06-05
**Estat** : referència del projecte (font única d'autoritat)
**Substitueix** : `anarbib-charte-langage-inclusif-v1.md` (v1.0, 2026-04-28), ara **deprecada**

Aquest document fixa les convencions de llenguatge inclusiu adoptades en les **deu
localitzacions** d'AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`,
`el`). S'aplica a tota traducció nova, a tota revisió, i a tota contribució futura. Està
destinat a les persones que contribueixen als fitxers
`src/i18n/locales/*.json`, a les cadenes de les notificacions de correu
(`supabase/functions/_shared/i18n/mail-strings.ts`), i a tota traducció
generada posteriorment.

> **Evolució des de la v1** : la v1 només cobria sis localitzacions (`pt-BR`, `fr`,
> `es`, `en`, `it`, `de`). La v2 afegeix `ca`, `eo`, `nl`, `el`, i **oficialitza
> la convenció italiana** (asterisc per a les parelles regulars, barra per a
> les parelles irregulars) que substitueix la barra provisional de la v1.

---

## Sumari

1. [Per què aquest document](#per-què-aquest-document)
2. [Principi director: coherència interna per llengua](#principi-director--coherència-interna-per-llengua)
3. [Taula d'estatuts](#taula-destatuts)
4. [Carta per llengua](#carta-per-llengua)
   - [Francès (fr)](#francès-fr)
   - [Alemany (de)](#alemany-de)
   - [Anglès (en)](#anglès-en)
   - [Portuguès brasiler (pt-BR)](#portuguès-brasiler-pt-br)
   - [Espanyol castellà (es)](#espanyol-castellà-es)
   - [Italià (it)](#italià-it)
   - [Català (ca)](#català-ca)
   - [Esperanto (eo)](#esperanto-eo)
   - [Neerlandès (nl)](#neerlandès-nl)
   - [Grec (el)](#grec-el)
5. [Termes polítics de referència](#termes-polítics-de-referència)
6. [Termes proscrits](#termes-proscrits)
7. [Procediment per a les addicions futures](#procediment-per-a-les-addicions-futures)
8. [Cobertura dels tests (CI)](#cobertura-dels-tests-ci)
9. [Evolució de la carta](#evolució-de-la-carta)

---

## Per què aquest document

AnarBib és un sistema integrat de gestió de biblioteques pensat per a les
biblioteques militants anarquistes. Una biblioteca militant no és una
biblioteca com les altres: no arxiva únicament documents, constitueix
**una memòria col·lectiva**, i el llenguatge de la seva interfície forma part
d'aquesta memòria. Una interfície que parla de «lecteur» en masculí genèric
reprodueix el gest d'esborratjament que una biblioteca feminista o queer busca
precisament desfer; una interfície que diu «compagn·e·s» indica des del
primer segon a quin moviment pertany.

Però el llenguatge inclusiu no és una norma universal. Cada llengua té la seva
pròpia història, les seves pròpies convencions militants, els seus propis terrenys
polítics minats. **No existeix una «bona» escriptura inclusiva
transversal**: hi ha eleccions locals situades, defensades per comunitats
militants situades. Aquesta carta respecta aquestes situacions locals tot
garantint que, a l'interior d'una mateixa llengua, AnarBib parla amb una sola veu.

Tres objectius concrets:

1. **Coherència.** A l'interior d'un mateix fitxer de localització, la mateixa posició de
   gènere s'escriu sempre de la mateixa manera.
2. **Respecte de les cultures militants locals.** Sense imposició d'una convenció
   d'una llengua a una altra.
3. **Llegibilitat per a no-especialistes.** Una bibliotecari-ària-e militant que descobreix
   AnarBib ha de poder utilitzar-lo sense ser experta en tipografia inclusiva.

---

## Principi director: coherència interna per llengua

Cada llengua d'AnarBib aplica **la seva pròpia convenció tipogràfica d'escriptura
inclusiva**, heretada de l'ús militant local. Cap convenció transversal
no és imposada.

A l'interior d'una llengua, **aquestes convencions són obligatòries i exclusives**:
un fitxer `fr.json` no barreja el punt volat amb `(e)`; un fitxer
`it.json` no barreja l'asterisc amb el punt volat. Les eleccions fetes en
aquesta carta són la **forma oficial** d'AnarBib per a aquella llengua.

---

## Taula d'estatuts

| Localització | Convenció | Estatut |
|---|---|---|
| `pt-BR` | Forma triple `(o/a/e)` | **Adoptada** (referència) |
| `fr` | Punt volat `·` | **Adoptada** |
| `es` | `e` neutre (convenció argentina) | **Adoptada** |
| `en` | Epicè + `they` singular | **Adoptada** |
| `de` | Genderstern `*` | **Adoptada** |
| `it` | Asterisc (regulars) / barra (irregulars) | **Adoptada** |
| `ca` | Terminació triple `-a-e` + article `le` | **Adoptada** |
| `eo` | Infix `-in-` visibilitzat per guions + pronom `ri` | **Adoptada** |
| `nl` | Formes de rol neutres | **Provisional** — a validar en comunitat |
| `el` | — | **A definir** amb una persona locutora grega militant |

---

## Carta per llengua

### Francès (fr)

**Convenció adoptada** : punt volat (`·`, U+00B7).

**Forma genèrica** : arrel comuna + punt volat + terminació femenina.

| Masculí | Femení | Forma AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Plural** : s'afegeix `·s` (`lecteur·rice·s`).
**Articles / determinants combinats** : `le·la`, `du·de la`, `au·à la`, `un·e`,
`le·la SEUL·E`, `actif·ve`.
**Mots ja epicèns** : sense canvi (`bibliothécaire`, `camarade`, `responsable`,
`personne`).
**Proscrit** : `(e)`, `-e` separat (convencions pre-2010), punt ordinari `.` o
vinyeta `•` en lloc del punt volat.

### Alemany (de)

**Convenció adoptada** : Genderstern (`*`, asterisc ASCII U+002A).

| Masculí | Femení | Forma AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Plural** : `*innen` (`Genoss*innen`, `Leser*innen`).
**Proscrit** : Mediopunkt `·`, Genderdoppelpunkt `:innen`, i el neologisme
hispanòfon *«Compas»* deixat sense traduir (sempre `Genoss*in`/`Genoss*innen`).

### Anglès (en)

**Convenció adoptada** : termes epicèns per defecte, `they/them/their` en
singular com a pronom neutre.

La gramàtica anglesa és àmpliament epicena: s'utilitza sistemàticament la
forma neutra existent (`reader`, `librarian`, `author`, `administrator`,
`comrade`, `coordinator`, `user`), sense marcatge tipogràfic. Per als rars
termes genrats, es tria la forma epicena (`actor` en lloc d'`actress`,
`server` en lloc de `waitress`).
**Proscrit** : `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Portuguès brasiler (pt-BR)

**Convenció adoptada** : forma triple `(o/a/e)` o `(a/e)` segons la gramàtica,
incloent explícitament les tres posicions (femení, masculí, no-binari).
**És la localització de referència del projecte.**

| Masculí | Femení | Forma AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Regla** : mots en `-or` → `(a/e)` ; mots en `-o` → `(o/a/e)`. Terminacions per
ordre alfabètic dins el parèntesi.
**Contraccions article-preposició** : `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`,
`(o/a/e)s`.
**Mots ja epicèns** : sense canvi (`camarada`, `colega`, `responsável`,
`pessoa`).
**Proscrit** : `(a)` sol, `/a`, `/o`, `@` (arroba), `x`. Atenció al
**fals amic `camarade`** (forma francesa): en pt-BR, és **`camarada`**.

### Espanyol castellà (es)

**Convenció adoptada** : `e` neutre (convenció argentina militant).

| Masculí | Femení | Forma AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Regla** : es substitueix la vocal de gènere final (`-o`/`-a`) per `-e`; mots en
`-or` → arrel + `-e` (`lector → lectore`).
**Plural** : `-s` (`compañeres`).
**Articles / determinants** : `le` (singular neutre), `les` (plural neutre).
**Participis concordats** : `informade`, `conectade`, `active`.
**Mots ja epicèns** : sense canvi (`camarada`, `colega`, `responsable`,
`persona`).
**Proscrit** : `(a)`, `/a`, `/o`, **la forma triple `(o/a/e)` del pt-BR**
(l'espanyol utilitza NOMÉS la `e` neutra), `@` (arroba), `x` (Latinx), i el
**punt volat `·`** (convenció francesa, que no s'ha d'emprar en espanyol).

### Italià (it)

**Convenció adoptada — oficial** : **asterisc `*` per a les parelles
regulars, barra abreujada per a les parelles irregulars.** Aquesta convenció
substitueix la barra provisional de la v1.

#### Parelles regulars (arrel comuna en `-o`/`-a`) → asterisc `*`

Quan el masculí i el femení comparteixen la **mateixa arrel**, es substitueix la
terminació de gènere per un asterisc, per coherència amb el Genderstern
alemany.

| Masculí | Femení | Forma AnarBib |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(ja epicè al sing.)* |

S'aplica també als **participis i adjectius concordats** : `stat*` (stato/a),
`ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a),
`benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*`
(questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Parelles irregulars (arrels diferents, tipus `-tore`/`-trice`) → barra abreujada

Quan el femení no comparteix l'arrel del masculí (`lettore` → `lettric-e`),
l'asterisc és **erroni** (`lettor*` suggeriria un femení inexistent
`lettora`). S'empra doncs la **forma barra abreujada**, que és l'*house style*
attestat en el dipòsit.

| Masculí | Femení | Forma AnarBib |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Plural irregular** : `lettori/trici`, `amministratori/trici`,
`coordinatori/trici`.
**Articles** : `il/la`, `del/la`, `al/la`, `dal/la` (forma abreujada), `un*` per
`uno/una`.
**Mots ja epicèns** : sense canvi (`utente`, `responsabile`, `persona`,
`collega`).

#### Nota sobre el caràcter `·`

El punt volat `·` **no** és un marcador inclusiu en italià: serveix
únicament de **separador tipogràfic** en els assumptes de correu i les línies
de metadades (`Email · ID · Genere`). Mai emprar-lo per marcar el gènere.

**🚫 Proscrit absolut** : **`camerata` / `camerati` / `cameratesco`** — forma d'adreça
interna feixista (PNF, MSI, CasaPound, Forza Nuova, FdI). Emprar `compagn*` i
les seves variants. **Aquesta proscripció és testada en CI** (`i18n.test.js` i
`mail-strings.test.ts`).
**Altres formes proscrites** : `(a)`/`(o)` parèntesis, triple `/trice/e`, sufix
`/x`, punt volat `·` com a marcador de gènere.

**Justificació militant** : l'asterisc (*asterisco*) és attestat en els
àmbits anarquistes i autònoms italofons (Carmilla, DinamoPress, InfoAut,
Wu Ming), i ofereix la coherència visual amb el Genderstern alemany. La barra
abreujada per a les parelles irregulars evita els femenins erronis tot restant
llegible.

### Català (ca)

**Convenció adoptada** : terminació triple sufix `-a-e` + article neutre `le`.

| Masculí | Femení | Forma AnarBib |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Variant parentesitzada** acceptada per a les contraccions:
`lector(a/e)`, `coordinador(a/e)`.
**Determinant neutre** : `le` (`le lector-a-e`).
**Plural** : `-s` o forma combinada `els-les-les` / `als-a les-a les`.
**Mots ja epicèns** : sense canvi.

> El català empra també el punt volat `·` a la **geminada `l·l`**
> (`col·lectiu`, `cancel·lada`, `sol·licitud`): és una **grafia estàndard del
> català**, sense relació amb la inclusivitat. No modificar-la.

### Esperanto (eo)

**Convenció adoptada** : infix `-in-` visibilitzat per guions + pronom neutre
`ri`.

| Base | Forma AnarBib |
|---|---|
| leganto (lecteur·rice) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Variant no-binària** : sufix `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Pronom neutre** : `ri`.
**Plural** : `-j` (`legant-in-oj`).

### Neerlandès (nl)

**Estatut : PROVISIONAL — a validar en comunitat.**

**Orientació provisional** : privilegiar les **formes de rol neutres**
existents en lloc d'un marcatge tipogràfic.

| Concepte | Forma provisional |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Regles provisionals** : evitar els sufixos genrats `-ster`/`-e` quan existeix una forma
neutra; pronom no-binari `die` (o `hen`/`hun`) — **ús encara no fixat**.

> ⚠️ Aquesta convenció **no** és definitiva. Ha de ser validada per locutors-es
> neerlandòfons militants abans de ser fixada. Mentrestant,
> romandre sobre les formes neutres.

### Grec (el)

**Estatut : CONVENCIÓ A DEFINIR.**

**No existeix un estàndard tipogràfic consensual** per a l'escriptura
inclusiva en grec. **No proposar cap marcador d'ofici.** La convenció serà
fixada **amb una persona locutora grega militant** que s'uneixi al projecte.

**Aproximació transitòria** (en espera): dobletes o formes neutres existents
(`αναγνώστης/στρια`, `συντονιστής/στρια`), grec monotònic, 2ᵃ persona del
singular per al tutejament de lector-a-e (vosejament per a l'equip). Sigla
RGPD → `ΓΚΠΔ`.

> ⚠️ Tota proposta de marcador tipogràfic inclusiu sistemàtic per al
> grec és **prematura** mentre cap interlocutor·a hel·lenòfon militant no s'hagi afegit
> al projecte.

---

## Termes polítics de referència

### Camarade / Compagn·e

| Llengua | Forma oficial | Plural |
|---|---|---|
| 🇫🇷 fr | `camarade` *(epicè)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(epicè)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(epicè)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagn*` | `compagn*` |
| ca | `camarada` *(epicè)* | `camarades` |
| eo | `kamarad-in-o` | `kamarad-in-oj` |
| nl | `kameraad` *(provisional)* | `kameraden` |
| el | `σύντροφος` *(a confirmar)* | — |

### Lecteur·rice

| Llengua | Forma oficial |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/trice` |
| ca | `lector-a-e` |
| eo | `legant-in-o` |
| nl | `lezer` *(provisional)* |
| el | `αναγνώστης/στρια` *(transitori)* |

### Bibliothécaire

| Llengua | Forma oficial |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(epicè)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecari*` |
| ca | `bibliotecari-ària-e` |
| eo | `bibliotekist-in-o` |
| nl | `bibliothecaris` *(provisional)* |
| el | `βιβλιοθηκάριος` *(a confirmar)* |

### Administrateur·rice

| Llengua | Forma oficial |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/trice` |
| ca | `administrador-a-e` |
| eo | `administrant-in-o` |
| nl | `beheerder` *(provisional)* |
| el | *(a definir)* |

---

## Termes proscrits

### Políticament marcats (proscripció absoluta)

| Terme | Llengua | Raó |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Forma d'adreça interna feixista (PNF, MSI, CasaPound, Forza Nuova, FdI). **Testat en CI.** |
| `Compas` *(sense traduir)* | 🇩🇪 de | Neologisme hispanòfon deixat tal qual — emprar `Genoss*in`/`Genoss*innen`. |

### Convencions tipogràfiques burocràtiques o inadaptades

| Forma | Llengües afectades | Per què |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Forma administrativa, no militant. |
| `@` (arroba) | pt-BR, es | Obsoleta, problema d'accessibilitat (lectors de pantalla). |
| `x` (Latinx) | es, pt-BR | Superada per la `e` neutra en l'ús militant contemporani. |
| `(e)`, `-e` separat | fr | Convenció pre-2010, substituïda pel punt volat. |
| `Genderdoppelpunkt` (`:innen`) | de | Vàlida però no retinguda per coherència amb `*`. |
| `he/she`, `s/he`, `(s)he` | en | Preferir `they/them` singular. |
| Triple `(o/a/e)` | es | Reservada al pt-BR; l'espanyol utilitza NOMÉS la `e` neutra. |
| Punt volat `·` com a marcador de gènere | es, it, ca | Convenció francesa; en d'altres llocs, `·` és només un separador (o la geminada `l·l` en ca). |
| Triple `/trice/e`, sufix `/x` | it | Formes malformades; emprar barra abreujada `/trice`. |

---

## Procediment per a les addicions futures

### Quan s'afegeix una nova clau i18n

1. **Identificar** la paraula/expressió a traduir. És un terme a generar?
2. **Si és així, triar la forma epicena quan existeixi** (`camarada` pt-BR,
   `responsable` fr, `utente` it…).
3. **Sinó, aplicar la convenció de la llengua** definida més amunt.
4. **Per a l'italià** : distingir parella regular (asterisc) i parella
   irregular (barra abreujada).
5. **Verificar la coherència** amb la resta del fitxer.
6. **Completar les 10 localitzacions en una sola passada.** Una clau parcialment
   traduïda és un bug. La **paritat de claus** entre les 10 localitzacions és
   obligatòria.

### Quan es revisa una traducció existent

1. Localitzar els marcadors **proscrits** (`(a)`, `@`, `camerata`, punt volat fora de
   fr/ca-geminada, triple `/trice/e`…).
2. Substituir-los per la forma oficial de la llengua.
3. Verificar la coherència singular/plural.
4. Verificar la coherència inter-localitzacions per a la mateixa clau.

### Quan es demana una traducció a una IA

Sempre proporcionar aquesta carta en context, precisar la convenció esperada per
a la llengua de destí i els termes proscrits, privilegiar les formes epicenes, i
**verificar el resultat** abans de la integració.

---

## Cobertura dels tests (CI)

- `src/tests/i18n.test.js` testa la **paritat de claus** i la **conformitat** de
  **8 localitzacions** : `pt-BR, fr, en, de, it, es, ca, eo`. Inclou el test bloquejant
  «l'italià no ha de contenir mai camerata/camerati».
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) testa les
  cadenes de correu: paritat, termes proscrits (camerata), interpolació, fallback.
- ⚠️ **`nl` i `el` NO estan coberts pel gate CI**: la seva paritat de claus
  i la seva conformitat no estan garantides automàticament. **Backlog** : afegir-los
  a `i18n.test.js` un cop fixades les seves convencions.

---

## Evolució de la carta

Aquesta carta és un document viu. Pot ser modificada seguint els principis
següents:

- **Addicions de termes polítics de referència** : per decisió col·lectiva
  documentada en el dipòsit (issue o pull request).
- **Canvi de convenció d'una llengua** : requereix la participació d'almenys
  una persona militant locutora nativa de la llengua afectada. El canvi ha de
  ser motivat políticament i tècnicament.
- **Fixació de les convencions provisionals (`nl`) o a definir (`el`)** : segueix el
  mateix protocol — una elecció tipogràfica militant local, justificada, validada per
  interlocutors-es natius, i aleshores incorporada a aquesta carta i afegida al gate CI.
- **Addició d'una nova llengua** : mateix protocol.

---

*Carta v2 redactada el 2026-06-05 a continuació de l'auditoria de llenguatge inclusiu de les
deu localitzacions i de les cadenes de correu. Document de referència a committejar en
`notes-audit/` del dipòsit. Substitueix la v1.0 del 2026-04-28.*
