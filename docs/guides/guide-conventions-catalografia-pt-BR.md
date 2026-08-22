# Ficha — Escrever um nome, escrever um título

> **A quem se dirige esta ficha.** A você que cataloga. Ela reúne o que se
> decide na hora de digitar: como se escreve um nome, onde cortar uma
> partícula, o que fazer com uma coletividade, e por que um campo vazio vale
> mais do que um campo adivinhado.
>
> O *porquê* detalhado está noutro lugar, no registro de decisões, seção
> `CONV`. Aqui, a gente cataloga.

## A regra, em uma frase

**Uma só verdade no banco, várias apresentações.** Você digita a forma de
catalogação; as maiúsculas, a ordem nome-sobrenome e as formatações
bibliográficas são **calculadas** na exibição e na exportação. Nunca as digite
à mão.

É daí que vem toda a desordem que estamos consertando: o ponto de acesso, a
forma de exibição e a forma de exportação foram alojados **no mesmo campo**, em
momentos diferentes, por mãos diferentes.

---

## 1. O nome de uma pessoa

### O nome para ordenação é que vale

O campo **«Nome para ordenação»** é a verdade. A **«Forma padrão»** deriva dele
automaticamente, por simples inversão da vírgula. Nunca o contrário.

| Você escreve em «Nome para ordenação» | O app exibe |
|---|---|
| `Kropotkin, Piotr` | Piotr Kropotkin |
| `Malatesta, Errico` | Errico Malatesta |

### Caixa natural, nunca em maiúsculas

**`Kropotkin, Piotr` — nunca `KROPOTKIN, Piotr`.**

As maiúsculas do sobrenome são uma **norma de referência bibliográfica**
(ABNT), não um dado. Elas são acrescentadas na exportação, na hora. Digitá-las
você mesmo não as torna mais verdadeiras: destrói a informação de caixa, que
depois não se reconstitui — `de Sousa` e `De Sousa` deixam de ser
distinguíveis uma vez tudo em maiúsculas.

### Onde cortar: a partícula

**É a língua do NOME que decide, não o país de nascimento.** Uma pessoa
argentina pode ter um nome italiano.

| Língua do nome | A partícula… | Exemplo |
|---|---|---|
| português, francês | **vai para o fim**, após o prenome | `Sousa, Manuel Joaquim de`<br>`Beauvoir, Simone de`<br>`Jong, Rudolf de` |
| italiano moderno, africâner, neerlandês | **fica na frente** | `Di Filippo, Luis`<br>`De Amicis, Edmondo`<br>`Van der Walt, Lucien` |

Luis Di Filippo é o caso exemplar: argentino, nome italiano, portanto
`Di Filippo, Luis` — e não `Filippo, Luis Di`.

### O que a ferramenta não sabe decidir

**Sobrenome duplo ou prenome composto?** `García Lorca` é um sobrenome duplo
espanhol (não se corta); `Jean-Marie` é um prenome composto. Nenhuma função faz
essa diferença. Na dúvida, **pergunte** em vez de decidir: é exatamente esse
tipo de caso que vai para a fila de verificação.

---

## 2. Uma coletividade não é uma pessoa

**Nome de coletivo não tem forma invertida.**

| ✅ | ❌ |
|---|---|
| `Grupo Krisis` | `Krisis, Grupo` |
| `Instituto de Estudos Libertários` | `Libertários, Instituto de Estudos` |
| `CIRA Marseille` | `Marseille, CIRA` |

### Preencha «Tipo de autoridade»

O campo existe e **comanda a regra**. Marcado como *Coletividade*, impede a
inversão. Deixado em branco, nada protege a ficha: ela será tratada como
pessoa na primeira passagem de ferramenta.

São três segundos de preenchimento que evitam três meses de correção.

### Se a ficha contém VÁRIAS pessoas

Acontece — a importação fabricou casos assim. `KAISER, William Young and
David E.` não é um Kaiser de dois prenomes: são **William Young** *e* **David
E. Kaiser**, dois autores de um mesmo livro.

**Não conserte no lugar.** Uma ficha de autoridade é compartilhada por toda a
rede: renomeá-la apenas desloca o erro. Passe pela Oficina de autoridades,
proposta do tipo **Cisão**: a ficha de origem é mantida, as outras são criadas,
e os vínculos com os livros acompanham. Prazo de deliberação: catorze dias,
como numa fusão.

---

## 3. O título

### A caixa depende da língua do título

**Não** existe regra universal. O alemão capitaliza seus substantivos: é a
**ortografia** dele, não um erro de digitação.

A ferramenta de normalização só rebaixa as **palavras funcionais da língua do
título**, em posição não inicial. Ela preserva:

- a **primeira palavra**;
- as palavras depois de **pontuação forte** (`.` `:` `;` `?` `!` e o travessão
  de subtítulo);
- as **siglas**.

**Ela retira um artefato de importação, não «recasa» o título.** Quando ela
propõe uma correção, você continua sendo quem julga se uma palavra é nome
próprio — a ferramenta não sabe.

| Antes | Depois |
|---|---|
| `Antologia Do Movimento Operário Gaúcho` | `Antologia do Movimento Operário Gaúcho` |
| `Der Einzige Und Sein Eigentum` | `Der Einzige und sein Eigentum` |

### O artigo inicial: nunca mutile o título

`Os Trabalhadores` escreve-se **`Os Trabalhadores`**. Não `Trabalhadores, Os` —
isso é resquício da ficha de papel — e não `Trabalhadores` sozinho.

A ordenação se resolve por um **contador de caracteres não ordenáveis** (aqui:
3, para `Os `), que deixa o título intacto.

---

## 4. O idioma e o país

| Campo | Formato | Exemplos |
|---|---|---|
| **Idioma** (do documento) | código BCP-47 | `pt-BR`, `fr`, `es`, `de`, `it` |
| **País** (da autoridade) | código ISO 3166-1 α-2 | `BR`, `FR`, `ES`, `NL` |

Não `português`, não `Brasil`, não `bra`. O seletor do app te dá o código
certo: use-o em vez de digitar.

**Um vazio continua vazio.** Se você não conhece o idioma, deixe em branco. Um
idioma desconhecido é uma informação honesta; um idioma errado comanda depois a
caixa do título e a regra de entrada do nome — ele propaga o erro em vez de
contê-lo.

---

## 5. As datas

Dois números inteiros e um **qualificador**:

| Qualificador | Quando |
|---|---|
| `exact` | a data está estabelecida |
| `circa` | aproximada («por volta de 1876») |
| `uncertain` | as fontes divergem |
| `unknown` | não se sabe |
| `living` | **a pessoa está viva** |

`living` não é um detalhe de conforto: sem ele, «ainda viva» e «data de morte
desconhecida» se confundiam — o que equivalia a matar gente no catálogo.

Quando nascimento e morte são ambos desconhecidos, use o **período de
atividade** («ativo 1900-1910»). E quando as fontes se contradizem, escreva
isso na **nota de datas**: é reparação historiográfica, não preenchimento.

---

## 6. O que não cabe a você decidir sozinho

O corpus de autoridades é **compartilhado por toda a rede**. Modificar uma
ficha é modificar o catálogo de várias bibliotecas.

| Gesto | Onde acontece |
|---|---|
| corrigir um erro de digitação numa ficha | diretamente |
| **fundir** duas fichas duplicadas | Oficina — proposta, 14 dias |
| **cindir** uma ficha que contém duas | Oficina — proposta, 14 dias |
| decidir uma caixa ou um sobrenome proposto pela ferramenta | fila de verificação |

Na Oficina, uma proposta fica aberta o tempo necessário para que as outras
bibliotecas possam objetar. Esse prazo não é lentidão administrativa: é o que
faz o corpus continuar comum.

---

## Na dúvida

**Deixe em branco em vez de adivinhar.**

Um campo vazio faz uma pergunta — alguém vai vê-la e respondê-la. Um campo
errado responde a uma pergunta que ninguém fez, e parece certo. É ele que a
gente reencontra três meses depois, copiado em cinco catálogos.
