# O thesaurus FICEDL no AnarBib — consultando um vocabulário comum

> **Para quem?** Para tod(o/a/e) camarada que catalog(a/e) e quer conectar seus
> livros ao **vocabulário de assuntos compartilhado** do movimento — aquele
> mantido pel(o/a/e) FICEDL. Este guia explica o que é esse thesaurus, em quais
> condições o AnarBib se conecta a ele, para que serve, e como usá-lo no dia a
> dia.
>
> **Espírito.** O AnarBib **consulta** o thesaurus; ele não se apropria dele. O
> vocabulário continua sendo d(o/a/e) FICEDL, que é sua fonte **que faz fé**.
> Nada aqui cria uma versão concorrente: nossa cópia é apenas um *reflexo*
> fiel.

---

## O que é o thesaurus FICEDL?

A **FICEDL** — Federação Internacional dos Centros de Estudos e Documentação
Libertários — federa desde 1979 CIRAs, ateneus, CCLs e bibliotecas anarquistas
do mundo inteiro. Ela mantém um **thesaurus**: um *vocabulário controlado* da
documentação libertária — uma lista organizada de **termos de assunto** (os
temas), estruturados e traduzidos, para descrever aquilo *sobre o que falam*
os documentos. Ele cobre os mesmos **dez idiomas** do AnarBib (exatamente os
mesmos oferecidos pel(o/a/e) CIRA de Lausanne) e reúne várias centenas de
termos (algo em torno de seiscentos). Está disponível publicamente em
`thesaurus.ficedl.info`.

Um thesaurus não é um simples dicionário: é um **grafo de conceitos**. Os
termos se relacionam entre si (mais amplo · mais restrito · associado) e
trazem **notas de aplicação** que explicam como devem ser usados. O AnarBib se
apoia em **SKOS**, o padrão livre da web semântica para esse tipo de
vocabulário.

## Em quais condições ele entrou no AnarBib

Adotar um vocabulário comum é, antes de tudo, uma **decisão política** — a de
coletivos que escolhem falar a mesma língua documental — e a técnica se
adapta a isso. Concretamente, o AnarBib importou o thesaurus **a partir do
site d(o/a/e) FICEDL** (`thesaurus.ficedl.info`) **por volta de 24 de junho de
2026**, trazendo seus **termos** e seus **lugares** (as entradas
geográficas) — deixando de fora as **datas** (as entradas cronológicas). Essa
conexão segue alguns **princípios claros**, que são as *bases do acordo*:

1. **Fonte canônica única.** O thesaurus que *faz fé* é o d(o/a/e) FICEDL. O
   AnarBib não detém *o* thesaurus: ele mantém uma cópia de trabalho.
2. **Sem fork.** Nossa cópia é um **reflexo** da versão FICEDL, nunca uma
   versão rival. A interoperabilidade que a FICEDL busca fica assim garantida
   *por construção*.
3. **Consultar, não modificar.** O AnarBib **não mexe** nas palavras
   escolhid(a/e)s pel(o/a/e) FICEDL. Uma única liberdade, e só do nosso lado:
   **recolocar no lugar certo uma etiqueta de idioma mal classificada** (uma
   tradução arquivada sob o código de idioma errado), unicamente para não
   *perder* uma tradução que já existe — sem nunca alterar o termo em si.
4. **Sinalizar, não corrigir.** Qualquer outra anomalia — um idioma faltando,
   um erro de digitação em um termo — **não** é corrigida aqui: ela é
   **sinalizada** à FICEDL, que corrige *sua* versão de referência.
5. **Ressincronização.** Depois das correções da FICEDL, o AnarBib
   **ressincroniza** sua cópia. O reflexo se atualiza; ele nunca diverge.
6. **Vocabulário livre e compartilhado.** O thesaurus é **livremente
   compartilhável** (nenhum direito proprietário o trava). Sua evolução
   acontece **coletivamente**, justamente para *limitar os forks* e preservar
   a interoperabilidade entre bibliotecas.
7. **Evolução conduzida pelo coletivo.** Algumas áreas do vocabulário precisam
   ser atualizadas (por exemplo, as categorias ligadas às temáticas
   LGBTQI+). Essas evoluções não são decretadas de cima para baixo: elas são
   discutidas **dentro da federação**.

Em suma: o thesaurus continua sendo **100% d(o/a/e) FICEDL**; o AnarBib é um
espelho leal, e um **elo de repasse** que encaminha o que observa.

## Para que serve

- **Descrever pelo assunto.** No catalogação, o campo **« Assuntos »
  (autoridade de assunto)** conecta um documento a um ou mais termos do
  thesaurus. É isso que permite encontrar um livro por **aquilo de que ele
  trata**, não só pelo título ou pel(o/a/e) autor(a/e).
- **Navegar por tema.** Esses termos alimentam as **facetas** e a navegação
  temática do catálogo público.
- **Falar dez idiomas de uma vez.** Um mesmo conceito carrega sua etiqueta em
  cada um dos dez idiomas: uma leitora hispanófona e um leitor grecófono caem
  n(o/a) *mesmo assunto*, cada um(a/e) em seu próprio idioma.
- **Conectar as bibliotecas.** Como tod(o/a/e) mundo se apoia no **mesmo**
  vocabulário, os catálogos se tornam comparáveis e intercambiáveis — é a base
  da mutualização (duplicatas, empréstimos interbibliotecários,
  meta-catálogo).

## Como usar na prática

1. **Busque um termo em « Assuntos ».** No catalogação, comece a digitar no
   campo **Assuntos**: o AnarBib sugere os termos do thesaurus, com sua
   hierarquia. Reaproveite o que já existe em vez de inventar.
2. **Escolha a granularidade certa.** Nem muito amplo, nem muito restrito: o
   termo que *alguém usaria para buscar* esse livro. Dois a quatro assuntos
   costumam bastar.
3. **Leia a nota de aplicação**, se o termo tiver uma: ela explica como
   usá-lo.
4. **Etiqueta faltando no seu idioma (⚐).** Se um assunto ainda não tem um
   rótulo **no seu idioma**, ele aparece por **substituição** (geralmente em
   outro idioma) com um ⚐. Isso não é um bug: é uma **lacuna da versão de
   referência**. Não a corrigimos por conta própria aqui — veja abaixo.
5. **Um erro, uma lacuna? Sinalize, não corrija.** Termo incorreto, tradução
   ausente: **repasse à coordenação**, que encaminha à FICEDL. A correção é
   feita na fonte canônica, e depois chega até nós pela ressincronização.
   *(Única exceção, já mencionada: uma etiqueta de idioma simplesmente mal
   classificada pode ser recolocada no lugar do nosso lado, sem tocar na
   palavra.)*
6. **Precisa de um termo que não existe?** O thesaurus não é enriquecido
   *localmente*. Por enquanto, as **palavras-chave livres** (texto livre,
   próprias de cada ficha) são a válvula de escape — veja o guia « Indexar por
   assunto ». A médio prazo, uma proposta de inclusão **é repassada ao
   coletivo** d(o/a/e) FICEDL.

## O espírito: consultar, não capturar

Essa conexão é uma **mão estendida**, não uma tomada de posse: o AnarBib
*toma emprestado* um vocabulário comum sem se apropriar dele, o *reflete* sem
o *congelar*, e *devolve* à FICEDL o que observa. O thesaurus continua vivo
onde deve estar — na federação que o sustenta — e nosso catálogo se
beneficia disso sem nunca competir com ele. É, no nível das palavras, a mesma
ética de sempre no AnarBib: **oferecer e conectar, nunca capturar**.

> Veja também: o guia **« Indexar por assunto »** (o gesto concreto na
> catalogação) e o enquadramento **« Apoio mútuo na catalogação »** (o comum
> de saber do qual esse vocabulário é o coração). O thesaurus de referência
> está disponível em `thesaurus.ficedl.info` — fonte canônica que faz fé.

*Documento do comum AnarBib. O thesaurus em si é obra d(o/a/e) FICEDL; este
guia apenas explica seu uso no AnarBib.*
