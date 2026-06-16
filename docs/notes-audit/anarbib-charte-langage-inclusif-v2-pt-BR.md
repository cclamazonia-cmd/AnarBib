# Carta de linguagem inclusiva do AnarBib

**Versão** : 2.0
**Data** : 2026-06-05
**Estatuto** : referência do projeto (fonte única de autoridade)
**Substitui** : `anarbib-charte-langage-inclusif-v1.md` (v1.0, 2026-04-28), doravante **depreciada**

Este documento fixa as convenções de linguagem inclusiva adotadas nas **dez
locales** do AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`,
`el`). Aplica-se a toda tradução nova, a toda releitura e a toda
contribuição futura. Destina-se às pessoas que contribuem com os arquivos
`src/i18n/locales/*.json`, com as cadeias das notificações e-mail
(`supabase/functions/_shared/i18n/mail-strings.ts`), e a toda tradução
gerada em seguida.

> **Evolução desde a v1**: a v1 cobria apenas seis locales (`pt-BR`, `fr`,
> `es`, `en`, `it`, `de`). A v2 adiciona `ca`, `eo`, `nl`, `el`, e **oficializa
> a convenção italiana** (asterisco para os pares regulares, barra para
> os pares irregulares) que substitui a barra provisória da v1.

---

## Sumário

1. [Por que este documento](#por-que-este-documento)
2. [Princípio orientador: coerência interna por língua](#princípio-orientador--coerência-interna-por-língua)
3. [Tabela dos estatutos](#tabela-dos-estatutos)
4. [Carta por língua](#carta-por-língua)
   - [Francês (fr)](#francês-fr)
   - [Alemão (de)](#alemão-de)
   - [Inglês (en)](#inglês-en)
   - [Português brasileiro (pt-BR)](#português-brasileiro-pt-br)
   - [Espanhol castelhano (es)](#espanhol-castelhano-es)
   - [Italiano (it)](#italiano-it)
   - [Catalão (ca)](#catalão-ca)
   - [Esperanto (eo)](#esperanto-eo)
   - [Holandês (nl)](#holandês-nl)
   - [Grego (el)](#grego-el)
5. [Termos políticos de referência](#termos-políticos-de-referência)
6. [Termos proscritos](#termos-proscritos)
7. [Procedimento para as adições futuras](#procedimento-para-as-adições-futuras)
8. [Cobertura dos testes (CI)](#cobertura-dos-testes-ci)
9. [Evolução da carta](#evolução-da-carta)

---

## Por que este documento

O AnarBib é um sistema integrado de gestão de bibliotecas pensado para as
bibliotecas militantes anarquistas. Uma biblioteca militante não é uma
biblioteca como as outras: ela não arquiva apenas documentos, ela
constitui **uma memória coletiva**, e a linguagem de sua interface faz parte
dessa memória. Uma interface que fala de « leitor » no masculino genérico
reproduz o gesto de apagamento que uma biblioteca feminista ou queer busca
precisamente desfazer; uma interface que diz « companheir(o/a/e)s » sinaliza desde
o primeiro segundo a qual movimento pertence.

Mas a linguagem inclusiva não é uma norma universal. Cada língua tem sua
própria história, suas próprias convenções militantes, seus próprios terrenos
políticos minados. **Não existe uma « boa » escrita inclusiva
transversal**: existem escolhas locais situadas, defendidas por comunidades
militantes situadas. Esta carta respeita essas situações locais ao mesmo tempo em que
garante que, dentro de uma mesma língua, o AnarBib fale com uma única voz.

Três objetivos concretos:

1. **Coerência**. Dentro de um mesmo arquivo de locale, a mesma posição de
   gênero se escreve sempre da mesma forma.
2. **Respeito pelas culturas militantes locais**. Nenhuma imposição de uma convenção
   de uma língua a outra.
3. **Legibilidade por não especialistas**. Uma bibliotecária militante que descobre
   o AnarBib deve poder utilizá-lo sem ser especialista em tipografia inclusiva.

---

## Princípio orientador: coerência interna por língua

Cada língua do AnarBib aplica **sua própria convenção tipográfica de escrita
inclusiva**, herdada do uso militante local. Nenhuma convenção transversal
é imposta.

Dentro de uma língua, **essas convenções são obrigatórias e exclusivas**:
um arquivo `fr.json` não mistura o ponto medial com `(e)`; um arquivo
`it.json` não mistura o asterisco com o ponto medial. As escolhas feitas nesta
carta são a **forma oficial** do AnarBib para essa língua.

---

## Tabela dos estatutos

| Locale | Convenção | Estatuto |
|---|---|---|
| `pt-BR` | Forma tripla `(o/a/e)` | **Adotada** (referência) |
| `fr` | Ponto medial `·` | **Adotada** |
| `es` | `e` neutro (convenção argentina) | **Adotada** |
| `en` | Epiceno + `they` singular | **Adotada** |
| `de` | Genderstern `*` | **Adotada** |
| `it` | Asterisco (regulares) / barra (irregulares) | **Adotada** |
| `ca` | Terminação tripla `-a-e` + artigo `le` | **Adotada** |
| `eo` | Infixo `-in-` visibilizado por hífens + pronome `ri` | **Adotada** |
| `nl` | Formas de papel neutras | **Provisória** — a validar em comunidade |
| `el` | — | **A definir** com uma pessoa falante grega militante |

---

## Carta por língua

### Francês (fr)

**Convenção adotada**: ponto medial (`·`, U+00B7).

**Forma genérica**: raiz comum + ponto medial + terminação feminina.

| Masculino | Feminino | Forma AnarBib |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Plural**: acrescenta-se `·s` (`lecteur·rice·s`).
**Artigos / determinantes combinados**: `le·la`, `du·de la`, `au·à la`, `un·e`,
`le·la SEUL·E`, `actif·ve`.
**Palavras já epicenas**: inalteradas (`bibliothécaire`, `camarade`, `responsable`,
`personne`).
**Proibido**: `(e)`, `-e` separado (convenções pré-2010), ponto ordinário `.` ou
marcador `•` no lugar do medial.

### Alemão (de)

**Convenção adotada**: Genderstern (`*`, asterisco ASCII U+002A).

| Masculino | Feminino | Forma AnarBib |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Plural**: `*innen` (`Genoss*innen`, `Leser*innen`).
**Proibido**: Mediopunkt `·`, Genderdoppelpunkt `:innen`, e o neologismo
hispanófono *« Compas »* deixado sem tradução (sempre `Genoss*in`/`Genoss*innen`).

### Inglês (en)

**Convenção adotada**: termos epicenos por padrão, `they/them/their` no
singular como pronome neutro.

A gramática inglesa é amplamente epicena: usa-se sistematicamente a
forma neutra existente (`reader`, `librarian`, `author`, `administrator`,
`comrade`, `coordinator`, `user`), sem marcação tipográfica. Para os raros
termos gendrificados, escolhe-se a forma epicena (`actor` em vez de `actress`,
`server` em vez de `waitress`).
**Proibido**: `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Português brasileiro (pt-BR)

**Convenção adotada**: forma tripla `(o/a/e)` ou `(a/e)` segundo a gramática,
incluindo explicitamente as três posições (feminino, masculino, não-binário).
**É a locale de referência do projeto.**

| Masculino | Feminino | Forma AnarBib |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Regra**: palavras em `-or` → `(a/e)`; palavras em `-o` → `(o/a/e)`. Terminações por
ordem alfabética dentro do parêntese.
**Contrações artigo-preposição**: `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`,
`(o/a/e)s`.
**Palavras já epicenas**: inalteradas (`camarada`, `colega`, `responsável`,
`pessoa`).
**Proibido**: `(a)` sozinho, `/a`, `/o`, `@` (arroba), `x`. Atenção ao
**falso cognato `camarade`** (forma francesa): em pt-BR, é **`camarada`**.

### Espanhol castelhano (es)

**Convenção adotada**: `e` neutro (convenção argentina militante).

| Masculino | Feminino | Forma AnarBib |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Regra**: substitui-se a vogal de gênero final (`-o`/`-a`) por `-e`; palavras em
`-or` → raiz + `-e` (`lector → lectore`).
**Plural**: `-s` (`compañeres`).
**Artigos / determinantes**: `le` (singular neutro), `les` (plural neutro).
**Particípios concordados**: `informade`, `conectade`, `active`.
**Palavras já epicenas**: inalteradas (`camarada`, `colega`, `responsable`,
`persona`).
**Proibido**: `(a)`, `/a`, `/o`, **a forma tripla `(o/a/e)` do pt-BR**
(o espanhol usa APENAS o `e` neutro), `@` (arroba), `x` (Latinx), e o
**ponto medial `·`** (convenção francesa; não usar em espanhol).

### Italiano (it)

**Convenção adotada — oficial**: **asterisco `*` para os pares
regulares, barra abreviada para os pares irregulares.** Esta convenção
substitui a barra provisória da v1.

#### Pares regulares (raiz comum em `-o`/`-a`) → asterisco `*`

Quando o masculino e o feminino compartilham a **mesma raiz**, substitui-se a
terminação de gênero por um asterisco, por coerência com o Genderstern
alemão.

| Masculino | Feminino | Forma AnarBib |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(já epiceno no sing.)* |

Aplica-se também aos **particípios e adjetivos concordados**: `stat*` (stato/a),
`ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a),
`benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*`
(questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Pares irregulares (raízes diferentes, tipo `-tore`/`-trice`) → barra abreviada

Quando o feminino não compartilha a raiz do masculino (`lettore` → `lettric-e`),
o asterisco é **incorreto** (`lettor*` deixaria supor um feminino inexistente
`lettora`). Usa-se portanto a **forma barra abreviada**, que é o *house style*
atestado no repositório.

| Masculino | Feminino | Forma AnarBib |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Plural irregular**: `lettori/trici`, `amministratori/trici`,
`coordinatori/trici`.
**Artigos**: `il/la`, `del/la`, `al/la`, `dal/la` (forma abreviada), `un*` para
`uno/una`.
**Palavras já epicenas**: inalteradas (`utente`, `responsabile`, `persona`,
`collega`).

#### Nota sobre o caractere `·`

O ponto medial `·` **não** é um marcador inclusivo em italiano: serve
unicamente como **separador tipográfico** nos assuntos de e-mail e nas linhas
de metadados (`Email · ID · Genere`). Nunca empregá-lo para marcar o gênero.

**🚫 Proibido absoluto**: **`camerata` / `camerati` / `cameratesco`** — forma de
tratamento interna fascista (PNF, MSI, CasaPound, Forza Nuova, FdI). Usar `compagn*` e
suas variantes. **Esta proscrição é testada no CI** (`i18n.test.js` e
`mail-strings.test.ts`).
**Outras formas proibidas**: `(a)`/`(o)` parênteses, triplo `/trice/e`, sufixo
`/x`, ponto medial `·` como marcador de gênero.

**Justificativa militante**: o asterisco (*asterisco*) está atestado nos
meios anarquistas e autônomos italófonos (Carmilla, DinamoPress, InfoAut,
Wu Ming), e oferece coerência visual com o Genderstern alemão. A barra abreviada
para os pares irregulares evita os femininos incorretos e permanece legível.

### Catalão (ca)

**Convenção adotada**: terminação tripla sufixo `-a-e` + artigo neutro `le`.

| Masculino | Feminino | Forma AnarBib |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Variante entre parênteses** aceita para as contrações:
`lector(a/e)`, `coordinador(a/e)`.
**Determinante neutro**: `le` (`le lector-a-e`).
**Plural**: `-s` ou forma combinada `els-les-les` / `als-a les-a les`.
**Palavras já epicenas**: inalteradas.

> O catalão emprega também o ponto volat `·` na **geminada `l·l`**
> (`col·lectiu`, `cancel·lada`, `sol·licitud`): trata-se de uma **grafia padrão do
> catalão**, sem relação com a inclusividade. Não a modificar.

### Esperanto (eo)

**Convenção adotada**: infixo `-in-` visibilizado por hífens + pronome neutro
`ri`.

| Base | Forma AnarBib |
|---|---|
| leganto (lecteur·rice) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Variante não-binária**: sufixo `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Pronome neutro**: `ri`.
**Plural**: `-j` (`legant-in-oj`).

### Holandês (nl)

**Estatuto: PROVISÓRIO — a validar em comunidade.**

**Orientação provisória**: privilegiar as **formas de papel neutras**
existentes em vez de uma marcação tipográfica.

| Conceito | Forma provisória |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Regras provisórias**: evitar os sufixos gendrificados `-ster`/`-e` quando uma forma
neutra existe; pronome não-binário `die` (ou `hen`/`hun`) — **uso ainda não definido**.

> ⚠️ Esta convenção **não** é definitiva. Deve ser validada por pessoas
> falantes neerlandesas militantes antes de ser fixada. Enquanto isso,
> manter as formas neutras.

### Grego (el)

**Estatuto: CONVENÇÃO A DEFINIR.**

**Não existe padrão tipográfico consensual** para a escrita
inclusiva em grego. **Não propor nenhum marcador de ofício.** A convenção será
definida **com uma pessoa falante grega militante** que se junte ao projeto.

**Abordagem transitória** (enquanto isso): duplas ou formas neutras existentes
(`αναγνώστης/στρια`, `συντονιστής/στρια`), grego monotônico, 2ª pessoa do
singular para o tratamento informal com leitores(as/es) (tratamento formal para a equipe). Sigla
RGPD → `ΓΚΠΔ`.

> ⚠️ Qualquer proposta de marcador tipográfico inclusivo sistemático para o
> grego é **prematura** enquanto nenhum(a/e) relai helenófon(o/a/e) militante tiver se juntado
> ao projeto.

---

## Termos políticos de referência

### Camarada / Compagn·e

| Língua | Forma oficial | Plural |
|---|---|---|
| 🇫🇷 fr | `camarade` *(epiceno)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(epiceno)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(epiceno)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagn*` | `compagn*` |
| ca | `camarada` *(epiceno)* | `camarades` |
| eo | `kamarad-in-o` | `kamarad-in-oj` |
| nl | `kameraad` *(provisório)* | `kameraden` |
| el | `σύντροφος` *(a confirmar)* | — |

### Leitor(a/e)

| Língua | Forma oficial |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/trice` |
| ca | `lector-a-e` |
| eo | `legant-in-o` |
| nl | `lezer` *(provisório)* |
| el | `αναγνώστης/στρια` *(transitório)* |

### Bibliotecári(o/a/e)

| Língua | Forma oficial |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(epiceno)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecari*` |
| ca | `bibliotecari-ària-e` |
| eo | `bibliotekist-in-o` |
| nl | `bibliothecaris` *(provisório)* |
| el | `βιβλιοθηκάριος` *(a confirmar)* |

### Administrador(a/e)

| Língua | Forma oficial |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/trice` |
| ca | `administrador-a-e` |
| eo | `administrant-in-o` |
| nl | `beheerder` *(provisório)* |
| el | *(a definir)* |

---

## Termos proscritos

### Politicamente marcados (proscrição absoluta)

| Termo | Língua | Motivo |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Forma de tratamento interna fascista (PNF, MSI, CasaPound, Forza Nuova, FdI). **Testado no CI.** |
| `Compas` *(não traduzido)* | 🇩🇪 de | Neologismo hispanófono deixado tal qual — usar `Genoss*in`/`Genoss*innen`. |

### Convenções tipográficas burocráticas ou inadequadas

| Forma | Línguas concernidas | Por quê |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Forma administrativa, não militante. |
| `@` (arroba) | pt-BR, es | Obsoleta, problema de acessibilidade (leitores de tela). |
| `x` (Latinx) | es, pt-BR | Substituída pelo `e` neutro no uso militante contemporâneo. |
| `(e)`, `-e` separado | fr | Convenção pré-2010, substituída pelo medial. |
| `Genderdoppelpunkt` (`:innen`) | de | Válida, mas não adotada por coerência com `*`. |
| `he/she`, `s/he`, `(s)he` | en | Preferir `they/them` singular. |
| Triplo `(o/a/e)` | es | Reservado ao pt-BR; o espanhol usa apenas o `e` neutro. |
| Ponto medial `·` como marcador de gênero | es, it, ca | Convenção francesa; em outros idiomas, `·` é apenas separador (ou a geminada `l·l` no ca). |
| Triplo `/trice/e`, sufixo `/x` | it | Formas mal construídas; usar barra abreviada `/trice`. |

---

## Procedimento para as adições futuras

### Quando se adiciona uma nova chave i18n

1. **Identificar** a palavra/expressão a traduzir. Trata-se de um termo a gendrificar?
2. **Se sim, escolher a forma epicena quando ela existe** (`camarada` pt-BR,
   `responsable` fr, `utente` it…).
3. **Caso contrário, aplicar a convenção da língua** definida acima.
4. **Para o italiano**: distinguir par regular (asterisco) e par
   irregular (barra abreviada).
5. **Verificar a coerência** com o restante do arquivo.
6. **Preencher as 10 locales em uma única passagem.** Uma chave parcialmente
   traduzida é um bug. A **paridade de chaves** entre as 10 locales é
   obrigatória.

### Quando se relê uma tradução existente

1. Identificar os marcadores **proscritos** (`(a)`, `@`, `camerata`, ponto medial fora de
   fr/ca-geminada, triplo `/trice/e`…).
2. Substituí-los pela forma oficial da língua.
3. Verificar a coerência singular/plural.
4. Verificar a coerência inter-locales para a mesma chave.

### Quando se solicita uma tradução a uma IA

Fornecer sempre esta carta como contexto, especificar a convenção esperada para
a língua-alvo e os termos proscritos, privilegiar as formas epicenas, e
**verificar o resultado** antes da integração.

---

## Cobertura dos testes (CI)

- `src/tests/i18n.test.js` testa a **paridade de chaves** e a **conformidade** de
  **8 locales**: `pt-BR, fr, en, de, it, es, ca, eo`. Inclui o teste bloqueador
  « o italiano nunca deve conter camerata/camerati ».
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) testa as
  cadeias de e-mail: paridade, termos proscritos (camerata), interpolação, fallback.
- ⚠️ **`nl` e `el` NÃO são cobertos pelo gate do CI**: sua paridade de chaves
  e conformidade não são garantidas automaticamente. **Backlog**: adicioná-los a `i18n.test.js` assim que suas convenções estiverem definidas.

---

## Evolução da carta

Esta carta é um documento vivo. Pode ser modificada segundo os seguintes princípios:

- **Adições de termos políticos de referência**: por decisão coletiva
  documentada no repositório (issue ou pull request).
- **Mudança de convenção de uma língua**: exige a participação de pelo menos
  uma pessoa militante falante nativa da língua concernida. A
  mudança deve ser motivada política e tecnicamente.
- **Definição das convenções provisórias (`nl`) ou a definir (`el`)**: segue o mesmo
  protocolo — uma escolha tipográfica militante local, justificada, validada por relais
  nativos, e depois integrada nesta carta e adicionada ao gate do CI.
- **Adição de uma nova língua**: mesmo protocolo.

---

*Carta v2 redigida em 2026-06-05 após a auditoria de linguagem inclusiva das
dez locales e das cadeias de e-mail. Documento de referência a commitar em
`notes-audit/` do repositório. Substitui a v1.0 de 2026-04-28.*
