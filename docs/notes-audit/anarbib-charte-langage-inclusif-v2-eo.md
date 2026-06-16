# Inkluziva lingva ĉarto de AnarBib

**Versio** : 2.0
**Dato** : 2026-06-05
**Statuso** : referenco de la projekto (unusola fonto de aŭtoritato)
**Anstataŭas** : `anarbib-charte-langage-inclusif-v1.md` (v1.0, 2026-04-28), nun **deprecita**

Ĉi tiu dokumento fiksas la konvenciojn de inkluziva lingvo adoptitajn en la **dek lokaĵoj** de AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`, `el`). Ĝi aplikas al ĉia nova traduko, ĉia relegado, kaj ĉia estonta kontribuo. Ĝi estas adresita al la personoj kiuj kontribuas al la dosieroj `src/i18n/locales/*.json`, al la retpoŝt-sciig-ĉenoj (`supabase/functions/_shared/i18n/mail-strings.ts`), kaj al ĉia poste generita traduko.

> **Evoluo ekde v1** : la v1 kovris nur ses lokaĵojn (`pt-BR`, `fr`, `es`, `en`, `it`, `de`). La v2 aldonas `ca`, `eo`, `nl`, `el`, kaj **oficialas la italan konvencion** (asterisko por regulaj paroj, oblikvo por neregulaj paroj) kiu anstataŭas la provizoran oblikvon de la v1.

---

## Enhavtabelo

1. [Kial ĉi tiu dokumento](#kial-ĉi-tiu-dokumento)
2. [Direkta principo : interna konsistenco laŭ lingvo](#direkta-principo--interna-konsistenco-laŭ-lingvo)
3. [Statusotabelo](#statusotabelo)
4. [Ĉarto laŭ lingvo](#ĉarto-laŭ-lingvo)
   - [Franca (fr)](#franca-fr)
   - [Germana (de)](#germana-de)
   - [Angla (en)](#angla-en)
   - [Brazila portugala (pt-BR)](#brazila-portugala-pt-br)
   - [Kastelia hispana (es)](#kastelia-hispana-es)
   - [Itala (it)](#itala-it)
   - [Kataluna (ca)](#kataluna-ca)
   - [Esperanto (eo)](#esperanto-eo)
   - [Nederlanda (nl)](#nederlanda-nl)
   - [Greka (el)](#greka-el)
5. [Politikaj referenctermoj](#politikaj-referenctermoj)
6. [Malpermesataj termoj](#malpermesataj-termoj)
7. [Proceduro por estontaj aldonoj](#proceduro-por-estontaj-aldonoj)
8. [Kovrado de testoj (KI)](#kovrado-de-testoj-ki)
9. [Evoluo de la ĉarto](#evoluo-de-la-ĉarto)

---

## Kial ĉi tiu dokumento

AnarBib estas integra bibliotekadministra sistemo pensita por militaj anarkiistaj bibliotekoj. Milita biblioteko ne estas biblioteko kiel la aliaj : ĝi ne nur arĥivas dokumentojn, ĝi konstituas **kolektivan memoron**, kaj la lingvo de ĝia interfaco estas parto de ĉi tiu memoro. Interfaco kiu parolas pri « leganto » en la generika maskla formo reproduktas la ĝeston de forviŝado kiun feministaj aŭ kveeraj bibliotekoj ĝuste celas detrui ; interfaco kiu diras « kompagn·e·s » signalas de la unua sekundo al kiu movado ĝi apartenas.

Sed inkluziva lingvo ne estas universala normo. Ĉiu lingvo havas sian propran historion, siajn proprajn militajn konvenciojn, siajn proprajn minacajn politikajn terenojn. **Ne ekzistas « bona » transversa inkluziva skribo** : ekzistas lokaj situiaj elektoj, defendataj de situiaj militaj komunumoj. Ĉi tiu ĉarto respektas ĉi tiujn lokajn situaciojn garantiante ke ene de la sama lingvo, AnarBib parolas per unusola voĉo.

Tri konkretaj celoj :

1. **Konsistenco.** Ene de la sama lokaĵo-dosiero, la sama seksa pozicio ĉiam skribas same.
2. **Respekto de lokaj militaj kulturoj.** Neniu trudado de konvencio el unu lingvo al alia.
3. **Legeblo de ne-specialistoj.** Milita bibliotekist-in-o kiu malkovras AnarBib devas povi uzi ĝin sen esti inkluziva tipografia eksperto.

---

## Direkta principo : interna konsistenco laŭ lingvo

Ĉiu lingvo de AnarBib aplikas **sian propran tipografian konvencion de inkluziva skribo**, hereditan de la loka milita uzado. Neniu transversa konvencio estas trudita.

Ene de lingvo, **ĉi tiuj konvencioj estas devigaj kaj ekskluzivaj** : dosiero `fr.json` ne miksigas la medianan punkton kun `(e)`-formoj ; dosiero `it.json` ne miksigas la asteriskon kun la mediana punkto. La elektoj faritaj en ĉi tiu ĉarto estas la **oficiala formo** de AnarBib por tiu lingvo.

---

## Statusotabelo

| Lokaĵo | Konvencio | Statuso |
|---|---|---|
| `pt-BR` | Triobla formo `(o/a/e)` | **Adoptita** (referenco) |
| `fr` | Mediana punkto `·` | **Adoptita** |
| `es` | Neŭtra `e` (argentina konvencio) | **Adoptita** |
| `en` | Epicena + unuopa `they` | **Adoptita** |
| `de` | Genderstern `*` | **Adoptita** |
| `it` | Asterisko (regulaj) / oblikvo (neregulaj) | **Adoptita** |
| `ca` | Triobla sufikso `-a-e` + artikolo `le` | **Adoptita** |
| `eo` | Infixo `-in-` videbligita per streketo + pronomo `ri` | **Adoptita** |
| `nl` | Neŭtraj rolformoj | **Provizora** — por validigo en komunumo |
| `el` | — | **Por difini** kun greka milita parolant-in-o |

---

## Ĉarto laŭ lingvo

### Franca (fr)

**Adoptita konvencio** : mediana punkto (`·`, U+00B7).

**Generika formo** : komuna radiko + mediana punkto + ina sufikso.

| Maskla | Ina | Formo AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Pluralo** : oni aldonas `·s` (`lecteur·rice·s`).
**Artikoloj / kombinitaj determinantoj** : `le·la`, `du·de la`, `au·à la`, `un·e`, `le·la SEUL·E`, `actif·ve`.
**Jam epicenaj vortoj** : senŝanĝaj (`bibliothécaire`, `camarade`, `responsable`, `personne`).
**Malpermesata** : `(e)`, apartigita `-e` (antaŭ-2010-aj konvencioj), ordinara punkto `.` aŭ bultpunkto `•` anstataŭ la mediana.

### Germana (de)

**Adoptita konvencio** : Genderstern (`*`, ASCII-asterisko U+002A).

| Maskla | Ina | Formo AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Pluralo** : `*innen` (`Genoss*innen`, `Leser*innen`).
**Malpermesata** : Mediopunkt `·`, Genderdoppelpunkt `:innen`, kaj la hispana neologismo *« Compas »* lasita netradukita (ĉiam `Genoss*in`/`Genoss*innen`).

### Angla (en)

**Adoptita konvencio** : epicenaj termoj defaŭlte, `they/them/their` en unuopa nombro kiel neŭtrala pronomo.

La angla gramatiko estas larĝe epicena : oni sisteme uzas la ekzistantan neŭtran formon (`reader`, `librarian`, `author`, `administrator`, `comrade`, `coordinator`, `user`), sen tipografia markado. Por la maloftaj seksigitaj termoj, oni elektas la epicena formon (`actor` prefere ol `actress`, `server` prefere ol `waitress`).
**Malpermesata** : `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Brazila portugala (pt-BR)

**Adoptita konvencio** : triobla formo `(o/a/e)` aŭ `(a/e)` laŭ la gramatiko, eksplicite inkludante la tri poziciojn (ina, maskla, nebinara).
**Ĝi estas la referenclokaĵo de la projekto.**

| Maskla | Ina | Formo AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Regulo** : vortoj je `-or` → `(a/e)` ; vortoj je `-o` → `(o/a/e)`. Sufiksoj laŭ alfabeta ordo en la parentezo.
**Artikolo-prepoziciaj kuntiradoj** : `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`, `(o/a/e)s`.
**Jam epicenaj vortoj** : senŝanĝaj (`camarada`, `colega`, `responsável`, `pessoa`).
**Malpermesata** : unusola `(a)`, `/a`, `/o`, `@` (arroba), `x`. Atentu la **falsan amikon `camarade`** (franca formo) : en pt-BR, tio estas **`camarada`**.

### Kastelia hispana (es)

**Adoptita konvencio** : neŭtra `e` (argentina milita konvencio).

| Maskla | Ina | Formo AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Regulo** : oni anstataŭas la finan seksan vokalon (`-o`/`-a`) per `-e` ; vortoj je `-or` → radiko + `-e` (`lector → lectore`).
**Pluralo** : `-s` (`compañeres`).
**Artikoloj / determinantoj** : `le` (neŭtra unuopa), `les` (neŭtra plurala).
**Konkorditaj participoj** : `informade`, `conectade`, `active`.
**Jam epicenaj vortoj** : senŝanĝaj (`camarada`, `colega`, `responsable`, `persona`).
**Malpermesata** : `(a)`, `/a`, `/o`, **la triobla formo `(o/a/e)` de pt-BR** (la hispana uzas NUR la neŭtran `e`), `@` (arroba), `x` (Latinx), kaj la **mediana punkto `·`** (franca konvencio, ne uzebla en hispana).

### Itala (it)

**Adoptita konvencio — oficiala** : **asterisko `*` por regulaj paroj, mallonga oblikvo por neregulaj paroj.** Ĉi tiu konvencio anstataŭas la provizoran oblikvon de la v1.

#### Regulaj paroj (komuna radiko je `-o`/`-a`) → asterisko `*`

Kiam la maskla kaj la ina dividas la **saman radikon**, oni anstataŭas la seksan sufikson per asterisko, kohere kun la germana Genderstern.

| Maskla | Ina | Formo AnarBib |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(jam epicena j. unuopa)* |

Aplikas ankaŭ al **konkorditaj participoj kaj adjektivoj** : `stat*` (stato/a), `ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a), `benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*` (questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Neregulaj paroj (malsamaj radikoj, tipo `-tore`/`-trice`) → mallonga oblikvo

Kiam la ina formo ne dividas la radikon de la maskla (`lettore` → `lettric-e`), la asterisko estas **erara** (`lettor*` sugestus neekzistantan inan formon `lettora`). Oni do uzas la **mallongan oblikvo-formon**, kiu estas la *house style* atestita en la deponejo.

| Maskla | Ina | Formo AnarBib |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Neregula pluralo** : `lettori/trici`, `amministratori/trici`, `coordinatori/trici`.
**Artikoloj** : `il/la`, `del/la`, `al/la`, `dal/la` (mallonga formo), `un*` por `uno/una`.
**Jam epicenaj vortoj** : senŝanĝaj (`utente`, `responsabile`, `persona`, `collega`).

#### Noto pri la signo `·`

La mediana punkto `·` **ne** estas inkluziva markilo en itala : ĝi servas sole kiel **tipografia apartigilo** en retpoŝtaj temosubjektoj kaj metadatumaj linioj (`Email · ID · Genere`). Neniam uzu ĝin por marki sekson.

**🚫 Absolute malpermesata** : **`camerata` / `camerati` / `cameratesco`** — interna faŝisma titolado (PNF, MSI, CasaPound, Forza Nuova, FdI). Uzu `compagn*` kaj ĝiajn variantojn. **Ĉi tiu malpermeso estas testata en KI** (`i18n.test.js` kaj `mail-strings.test.ts`).
**Aliaj malpermesataj formoj** : `(a)`/`(o)` parentezoj, triobla `/trice/e`, sufikso `/x`, mediana punkto `·` kiel seksa markilo.

**Milita pravigo** : la asterisko (*asterisco*) estas atestita en itala-lingvaj anarkiistaj kaj aŭtonomaj medioj (Carmilla, DinamoPress, InfoAut, Wu Ming), kaj ofertas vizualan koherencon kun la germana Genderstern. La mallonga oblikvo por neregulaj paroj evitas erarajn inajn formojn restante legebla.

### Kataluna (ca)

**Adoptita konvencio** : triobla sufikso `-a-e` + neŭtrala artikolo `le`.

| Maskla | Ina | Formo AnarBib |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Parenteza varianto** akceptata por kuntiradoj :
`lector(a/e)`, `coordinador(a/e)`.
**Neŭtrala determinanto** : `le` (`le lector-a-e`).
**Pluralo** : `-s` aŭ kombina formo `els-les-les` / `als-a les-a les`.
**Jam epicenaj vortoj** : senŝanĝaj.

> La kataluna ankaŭ uzas la punton volat `·` en la **geminata `l·l`** (`col·lectiu`, `cancel·lada`, `sol·licitud`) : tio estas **norma kataluna ortografio**, sen rilato al inkluziveco. Ne modifi ĝin.

### Esperanto (eo)

**Adoptita konvencio** : infixo `-in-` videbligita per streketoj + neŭtrala pronomo `ri`.

| Bazo | Formo AnarBib |
|---|---|
| leganto (lecteur·rice) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Nebinara varianto** : sufikso `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Neŭtrala pronomo** : `ri`.
**Pluralo** : `-j` (`legant-in-oj`).

### Nederlanda (nl)

**Statuso : PROVIZORA — por validigo en komunumo.**

**Provizora orientiĝo** : preferi la **ekzistantajn neŭtrajn rolformojn** anstataŭ tipografian markadon.

| Koncepto | Provizora formo |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Provizora reguloj** : eviti seksigitajn sufiksojn `-ster`/`-e` kiam neŭtra formo ekzistas ; nebinara pronomo `die` (aŭ `hen`/`hun`) — **uzado ankoraŭ ne fiksita**.

> ⚠️ Ĉi tiu konvencio estas **ne** definitiva. Ĝi devas esti validigita de nederlandlingvaj militaj parolant-in-oj antaŭ ol fiksiĝi. Dum atendo, resti sur neŭtraj formoj.

### Greka (el)

**Statuso : KONVENCIO POR DIFINI.**

**Ne ekzistas konsensusa tipografia normo** por inkluziva skribo en greka. **Ne proponu oficialan markilon.** La konvencio estos fiksita **kun greka milita parolant-in-o** kiu aliĝas al la projekto.

**Transira aliro** (dum atendo) : dubletoj aŭ ekzistantaj neŭtraj formoj (`αναγνώστης/στρια`, `συντονιστής/στρια`), monotonika greka, 2-a singulara persono por parolado kiel kamarad-in-o (pluraler por teamo). Siglo RGPD → `ΓΚΠΔ`.

> ⚠️ Ĉia propono de sistema inkluziva tipografia markilo por la greka estas **trofruaj** dum neniu greka milita parolant-in-o aliĝis al la projekto.

---

## Politikaj referenctermoj

### Kamarad-in-o

| Lingvo | Oficiala formo | Pluralo |
|---|---|---|
| 🇫🇷 fr | `camarade` *(épicène)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(épicène)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(épicène)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagn*` | `compagn*` |
| ca | `camarada` *(épicène)* | `camarades` |
| eo | `kamarad-in-o` | `kamarad-in-oj` |
| nl | `kameraad` *(provisoire)* | `kameraden` |
| el | `σύντροφος` *(à confirmer)* | — |

### Legant-in-o

| Lingvo | Oficiala formo |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/trice` |
| ca | `lector-a-e` |
| eo | `legant-in-o` |
| nl | `lezer` *(provisoire)* |
| el | `αναγνώστης/στρια` *(transitoire)* |

### Bibliotekist-in-o

| Lingvo | Oficiala formo |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(épicène)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecari*` |
| ca | `bibliotecari-ària-e` |
| eo | `bibliotekist-in-o` |
| nl | `bibliothecaris` *(provisoire)* |
| el | `βιβλιοθηκάριος` *(à confirmer)* |

### Administrant-in-o

| Lingvo | Oficiala formo |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/trice` |
| ca | `administrador-a-e` |
| eo | `administrant-in-o` |
| nl | `beheerder` *(provisoire)* |
| el | *(à définir)* |

---

## Malpermesataj termoj

### Politike markitaj (absoluta malpermeso)

| Termino | Lingvo | Kialo |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Interna faŝisma titolado (PNF, MSI, CasaPound, Forza Nuova, FdI). **Testata en KI.** |
| `Compas` *(netradukita)* | 🇩🇪 de | Hispanlingva neologismo lasita tia — uzu `Genoss*in`/`Genoss*innen`. |

### Burokratiaj aŭ neadaptitaj tipografiaj konvencioj

| Formo | Koncernaj lingvoj | Kialo |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Administrata formo, ne milita. |
| `@` (arroba) | pt-BR, es | Malaktuala, alirebla problemo (ekranlegantoj). |
| `x` (Latinx) | es, pt-BR | Anstataŭigita de neŭtra `e` en nuntempaj militaj uzadoj. |
| `(e)`, apartigita `-e` | fr | Antaŭ-2010-a konvencio, anstataŭigita de la mediana punkto. |
| `Genderdoppelpunkt` (`:innen`) | de | Valida sed neretena por kohereco kun `*`. |
| `he/she`, `s/he`, `(s)he` | en | Preferi unuopan `they/them`. |
| Triobla `(o/a/e)` | es | Rezervita al pt-BR ; la hispana uzas nur neŭtran `e`. |
| Mediana punkto `·` kiel seksa markilo | es, it, ca | Franca konvencio ; aliloke, `·` estas nur apartigilo (aŭ la geminata `l·l` en ca). |
| Triobla `/trice/e`, sufikso `/x` | it | Malformitaj formoj ; uzu mallongan oblikvon `/trice`. |

---

## Proceduro por estontaj aldonoj

### Kiam oni aldonas novan i18n-ŝlosilon

1. **Identigi** la vorton/esprimon por traduki. Ĉu ĝi estas seksa termino ?
2. **Se jes, elekti la epicena formon kiam ĝi ekzistas** (`camarada` pt-BR, `responsable` fr, `utente` it…).
3. **Se ne, apliki la lingvan konvencion** difinitan supre.
4. **Por la itala** : distingi regulan paron (asterisko) kaj neregularan paron (mallonga oblikvo).
5. **Kontroli la konsistencon** kun la cetero de la dosiero.
6. **Plenigi la 10 lokaĵojn en unusola plenigo.** Parte tradukita ŝlosilo estas cimo. La **ŝlosilo-egaleco** inter la 10 lokaĵoj estas deviga.

### Kiam oni relegas ekzistantan tradukon

1. Ekvidi la **malpermesatajn** markilojn (`(a)`, `@`, `camerata`, mediana punkto ekster fr/ca-geminata, triobla `/trice/e`…).
2. Anstataŭigi ilin per la oficiala formo de la lingvo.
3. Kontroli la unuopa/plurala konsistencon.
4. Kontroli la inter-lokaĵan konsistencon por la sama ŝlosilo.

### Kiam oni petas tradukon al IA

Ĉiam provizi ĉi tiun ĉarton kiel kuntekston, precizigi la atendata konvencion por la cela lingvo kaj la malpermesatajn terminojn, preferi epicenajn formojn, kaj **kontroli la rezulton** antaŭ integrado.

---

## Kovrado de testoj (KI)

- `src/tests/i18n.test.js` testas la **ŝlosilo-egalecon** kaj la **konformeron** de **8 lokaĵoj** : `pt-BR, fr, en, de, it, es, ca, eo`. Ĝi inkludas la blokantan teston « la itala ne devas iam ajn enhavi camerata/camerati ».
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) testas la retpoŝtajn ĉenojn : egaleco, malpermesataj termoj (camerata), interpolado, returno.
- ⚠️ **`nl` kaj `el` ne estas kovrataj de la KI-gejto** : ilia ŝlosilo-egaleco kaj konformero ne estas aŭtomate garantiataj. **Restanta laboro** : aldoni ilin al `i18n.test.js` post kiam iliaj konvencioj estos fiksitaj.

---

## Evoluo de la ĉarto

Ĉi tiu ĉarto estas vivanta dokumento. Ĝi povas esti modifita laŭ la sekvaj principoj :

- **Aldonoj de politikaj referenctermoj** : per kolektiva dokumentita decido en la deponejo (diskutaĵo aŭ tiraĵo-peto).
- **Ŝanĝo de lingva konvencio** : postulas la partoprenon de almenaŭ unu milita denask-parolant-in-o de la koncerna lingvo. La ŝanĝo devas esti politike kaj teknike motivita.
- **Fiksado de provizora konvencio (`nl`) aŭ por difini (`el`)** : sekvas la saman protokolon — loka milita tipografia elekto, pravigita, validigita de indiĝenaj relaisoj, poste aldonita en ĉi tiun ĉarton kaj al la KI-gejto.
- **Aldono de nova lingvo** : sama protokolo.

---

*Ĉarto v2 verkita la 2026-06-05 sekve al la inkluziva lingva revizio de la dek lokaĵoj kaj retpoŝtaj ĉenoj. Referenca dokumento por konfiuzo en `notes-audit/` de la deponejo. Anstataŭas la v1.0 de 2026-04-28.*
