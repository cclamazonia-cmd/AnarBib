# Bem-vind(o/a/e) à rede AnarBib

**Guia de acolhimento das coordenações — os trinta primeiros dias**

*Versão 1.0 — 16 de setembro de 2026 · Licença AGPLv3 · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Antes de tudo: o que foi aceito, e o que ainda não

A candidatura da sua biblioteca foi aceita pela coordenação da rede. Isso quer dizer
duas coisas, e só duas:

1. A rede reconhece a sua biblioteca como parte da família anarquista e libertária que
   ela acolhe, e abriu para você o caminho da constituição.
2. A sua conta deixou de ser uma conta de solicitante e passou a ser uma conta de
   **coordenaç(ão) em constituição**.

O que ainda **não** aconteceu: a sua biblioteca ainda não está ativa. Ela ainda não
aparece no catálogo comum, ainda não recebe leitor(a/e)s, ainda não troca nada com as
outras bibliotecas. Ela está em estado **pré-ativo**, e é você quem vai tirá-la de lá —
não sozinh(o/a/e), e não num único dia.

> **A promessa deste guia.** Você não precisa ser bibliotecári(o/a/e). Você não precisa
> entender de informática. Você precisa saber o que o seu coletivo quer, e ter alguém
> para perguntar quando não souber. O resto é clicar.
>
> **E a regra de ouro: clica, não vai quebrar nada.** O software não mostra as
> transições impossíveis, desativa com uma explicação os botões que uma regra
> bloquearia, e recusa no banco de dados as combinações impossíveis. Os poucos gestos
> que realmente não voltam atrás estão listados no capítulo 9.

**A pessoa com quem falar.** Em qualquer momento deste percurso, antes de decidir e não
depois: `anarbib@proton.me`. A rede tem por princípio que uma decisão de constituição
se conversa com um(a/e) camarada antes de virar um formulário. Escrever não é sinal de
fraqueza — é o funcionamento normal.

---

## 1. Dia 1 — Entrar, e entender onde você está

### 1.1 Entrar

A página de conexão é `/login` (botão **Entrar**). O endereço `/cadastro` apenas redireciona para
ela: se algum documento antigo mandar você para lá, não é erro seu.

Se você ainda usa a senha provisória recebida por e-mail, **troque-a antes de qualquer
outra coisa**. Enquanto a senha provisória não for trocada, várias ações ficam bloqueadas
— é uma prova passiva de que a conta foi realmente tomada em mãos por uma pessoa.

### 1.2 As duas casas

É a coisa mais importante do guia inteiro, e vale decorar.

| Se a pergunta é… | Você vai para… |
|---|---|
| « o que a gente decidiu? » | **`/biblioteca`** — a casa coletiva |
| « o que eu faço com esta pessoa na minha frente? » | **`/painel`** — o balcão |

Em `/biblioteca` moram a identidade pública, o regimento, a equipe, o perfil de adoção,
as transições e a privacidade: tudo o que o coletivo deliberou. Em `/painel` mora o
trabalho de todo dia: empréstimos, devoluções, consultas, reservas, contas esperando
validação.

Isso não é arrumação arbitrária. Muitos softwares de biblioteca misturam as duas coisas,
e o resultado é que a configuração política acaba escondida num back-office de
administrador. Aqui, a deliberação fica de um lado e a operação do outro.

### 1.3 As rotas que você vai usar

| Rota | O que é | Para quem |
|---|---|---|
| `/criar-conta` | inscrição — **a única porta de entrada, para todo mundo** | qualquer pessoa |
| `/conta` | o espaço pessoal de cada leitor(a/e) — nove abas | cada pessoa, só a sua |
| `/atelier` | as oficinas: constituição e autoridades | coordenação em constituição |
| `/painel` | o balcão, o trabalho do dia | equipe (librarian, coordenação) |
| `/biblioteca` | a casa coletiva, as decisões | equipe, com poderes por papel |
| `/catalogacao` | catalogar e importar | equipe |
| `/rede` | administração da rede | somente admins da rede |

A página **Federação** e as páginas públicas — catálogo, Obra, Periódico, Assunto,
Bibliotecas, Cartografia, Tesauro FICEDL — completam o conjunto. As rotas não são
traduzidas: elas são as mesmas nos dez idiomas.

> **Você nunca entra na conta de outra pessoa.** Tudo o que a equipe precisa fazer por
> um(a/e) leitor(a/e) está no painel. Se você se pegou querendo « entrar como » alguém,
> o que você procura está no painel, aba **Leitor** (`leitor`).

---

## 2. Dias 1 a 3 — A oficina de constituição

A constituição é um percurso em `/atelier`. Você pode salvar a qualquer momento e voltar
depois: nada se perde entre duas sessões. **Você tem 60 dias**, e um lembrete por e-mail
chega no 45º.

### 2.1 Etapa 0 — o perfil de adoção, o ato fundador

Antes de todos os outros volets, o software pergunta onde a sua biblioteca se coloca em
**quatro eixos independentes**. Nenhum deles é um nível de qualidade: são formas de
existir, e uma biblioteca pequena que escolhe o modo simples em tudo não é uma
biblioteca inacabada.

**Eixo 1 — `catalog_mode`, o catálogo**

- `local_only` — o acervo fica em casa, não é exposto à rede. Útil num período de
  rodagem, ou quando parte do fundo ainda não está pronta para ser publicada.
- `network_published` — o acervo entra no catálogo comum AnarBib.

**Eixo 2 — `circulation_mode`, a circulação**

- `off` — nenhuma circulação gerida no software: só catálogo. É o caso de um fundo
  patrimonial de consulta.
- `informal` — circulação simples, sem cotização nem regras estritas. O caso típico de
  uma biblioteca militante onde todo mundo se conhece.
- `full_sigb` — circulação completa: regras, reservas, cotizações, suspensões.

**Eixo 3 — `network_mode`, a federação**

- `isolated` — a biblioteca existe no AnarBib mas não troca nada.
- `observer` — recebe os fluxos da rede, não contribui ainda.
- `federated` — participa plenamente.

**Eixo 4 — `governance_mode`, a governança**

- `informal` — nenhum papel de equipe distinto: todo mundo é leitor(a/e). Sem cooptação,
  sem carência, sem registro de auditoria.
- `staff_roles` — os papéis `librarian` e `coordenador(a/e)` existem, cooptação
  simplificada.
- `full_governance` — o conjunto: cooptação, carência, registro de auditoria, crons.

### 2.2 O que cada escolha acende no painel

Esta tabela é a razão pela qual a etapa 0 vem antes de tudo. As abas do balcão aparecem
ou não segundo o eixo de circulação:

| Aba do painel | Aparece se |
|---|---|
| **Trabalho do dia** (`trabalho-do-dia`) | sempre |
| **Ações** (`acoes`) | sempre |
| **Leitor** (`leitor`) | sempre |
| **Histórico** (`historico`) | sempre |
| **Consultas locais** (`consultas-locais`) | circulação `informal` ou `full_sigb` |
| **Empréstimos** (`emprestimos-livro`) | circulação `informal` ou `full_sigb` |
| **Reservas** (`reservas`) | circulação `full_sigb` |
| **Empréstimos em lote** (`emprestimos-lote`) | circulação `full_sigb` |
| **Contribuições** (`contribuicoes`) | cotização ativada **e** circulação diferente de `off` |

Se uma aba não aparece para você, não é uma pane: é o perfil que o seu coletivo
escolheu. E se o perfil mudar durante a sessão, o painel volta sozinho para o
**Trabalho do dia**.

> **As escolhas não são prisões.** Cada eixo tem sua doutrina de transição — algumas
> rápidas, algumas lentas, algumas irreversíveis. A aba **Transições** fica em
> `/biblioteca`, e não no painel: mudar de perfil é uma decisão coletiva, não um gesto
> de balcão. Certas transições que atravessam vários eixos passam pela validação dos
> admins da rede.

### 2.3 Os dez volets

Depois da etapa 0, a oficina mostra apenas os volets que o seu perfil torna pertinentes.
Uma biblioteca em `circulation_mode = off` não verá o volet de circulação: não é que
falte alguma coisa, é que aquela pergunta não se faz para vocês.

| Volet | O que se decide | Condição |
|---|---|---|
| 1 | Identidade — nome, nome curto, endereço, contato | sempre |
| 2 | Horários e permanências | sempre |
| 3 | Pessoas responsáveis | segundo a governança |
| 4 | Política de catalogação | sempre |
| 5 | Política de circulação | se a circulação não é `off` |
| 6 | Política de adesão de leitor(a/e)s | segundo governança e circulação |
| 7 | Política de e-mails | sempre |
| 8 | Visibilidade e participação na rede | se a rede não é `isolated` |
| 9 | Dados e confidencialidade | sempre |
| 10 | Geração do regimento | sempre |

**Nenhum destes volets é uma questão de informática.** São dez questões de assembleia,
apresentadas na ordem em que se respondem bem. Preencha-os com o que o coletivo já
decidiu; onde ele ainda não decidiu, pare e leve para a próxima reunião. A oficina
espera.

### 2.4 O volet 10 — o esqueleto de regimento

No fim, o software gera um PDF pré-preenchido com todas as suas escolhas. **Esse PDF não
é um certificado.** Ele é um esqueleto a discutir: uma matéria-prima de deliberação. As
seções que merecem debate vêm marcadas.

O percurso esperado é: baixar, levar à assembleia, emendar livremente, e recarregar o
documento emendado como regimento oficial da biblioteca. Enquanto ele não for
recarregado, a biblioteca permanece pré-ativa.

> **Um ponto de honestidade.** « Concluir a constituição » não vale, hoje, ativação
> automática da biblioteca. É uma lacuna conhecida do software, não um erro seu. Quando
> você chegar ao fim dos volets, escreva a `anarbib@proton.me` para que a ativação
> seja feita — e insista se ninguém responder em alguns dias.

---

## 3. Dias 3 a 7 — A página Biblioteca, a casa coletiva

Terminada a constituição, `/biblioteca` vira o lugar onde o que foi decidido fica
inscrito e se mantém. É lá que se olha quando alguém pergunta « mas a gente combinou
o quê? ».

- **Identidade pública** — o que a rede e o público veem da sua biblioteca.
- **Regimento** — o documento que vocês adotaram, e suas versões.
- **Equipe** — quem é o quê, e por qual circuito (capítulo 4).
- **Perfil** — os quatro eixos, tais como estão hoje.
- **Transições** — as propostas de mudança de perfil e sua votação.
- **Privacidade** — retenção dos dados, purga automática, LGPD/RGPD.

**As decisões a arbitrar nesta semana**, todas em `/biblioteca`:

1. **A visibilidade do acervo** — catálogo público ou não, aparição na galeria de
   bibliotecas de `anarbib.org`, presença na cartografia da rede. Na cartografia, um
   coletivo que escolhe não aparecer tem suas razões: o software respeita isso, e você
   também.
2. **A política de e-mails** — quais eventos geram uma mensagem para a pessoa leitora
   (ciclo de empréstimo, lembretes antes do vencimento, cobranças de atraso) e se a
   equipe recebe cópia. Tudo isso se liga e se desliga por biblioteca.
3. **A retenção dos dados** — quanto tempo o histórico de empréstimo de uma pessoa fica
   guardado depois da devolução. É uma questão política tanto quanto legal: numa
   biblioteca militante, um histórico é uma lista de leituras de pessoas identificadas.
   Guardar pouco é uma forma de proteção.
4. **A cotização**, se ela existe na sua casa — e com ela a aba **Contribuições** do
   painel.
5. **A carteirinha de leitor(a/e)** — se vocês a ativam. Ela não carrega nome nenhum:
   só o nome curto da biblioteca e um QR opaco, e é a própria pessoa leitora que a gera
   e a regenera. Foi desenhada assim de propósito, para que um cartão perdido não conte
   nada sobre quem o carregava.

> **Sobre a aba Privacidade.** Ela pode mostrar duas mensagens que se contradizem a
> respeito da purga automática. É um defeito conhecido de exibição. Antes de concluir
> que a purga está ativa ou inativa, pergunte à rede.

---

## 4. Dias 5 a 10 — Constituir a equipe

### 4.1 Três papéis, e só três

`leitor(a/e)` · `librarian` (bibliotecári(o/a/e)) · `coordenador(a/e)`.

O papel local « administrador » foi retirado em maio de 2026. Se você o encontrar citado
em algum documento, o documento está velho. « Administrador(a/e) da rede AnarBib » existe,
mas é um **estatuto transversal** — não é o degrau seguinte da escada, e não se chega lá
sendo coordenador(a/e) por bastante tempo. É outro mecanismo político, com sua própria
cooptação.

### 4.2 O engano que custa caro

**Ninguém se inscreve duas vezes.** Todo mundo entra uma única vez por `/criar-conta`,
como leitor(a/e) — inclusive quem vai ser da equipe.

Virar equipe não é uma nova inscrição: é uma cooptação, e ela acontece na conta que já
existe. Quem se reinscreve achando que assim « entra como equipe » só cria uma segunda
conta e um problema para a coordenação desfazer.

**Então a única coisa a pedir a quem vai entrar na equipe é: « me manda o teu ID público ».**

### 4.3 O circuito em três tempos

Nenhuma promoção é unilateral. Três pessoas distintas, três gestos:

1. **Propor** — a coordenação propõe alguém pelo ID público, para o papel `librarian` ou
   `coordenador(a/e)`.
2. **Endossar** — outra pessoa da equipe ratifica. A pessoa visada está excluída do
   quórum: enquanto a equipe tiver duas outras pessoas ativas, são necessárias duas
   ratificações.
3. **Aceitar** — a pessoa proposta aceita. Sem esse consentimento, nada acontece.

A proposta **expira em 30 dias**. Uma linha de leitor(a/e) fecha, abre a de
bibliotecári(o/a/e): um só papel ativo por biblioteca, e o histórico fica.

> **O salto colegial.** Por padrão, para entrar no círculo da coordenação é preciso ter
> passado por bibliotecári(o/a/e). Para um coletivo horizontal, esse degrau intermediário
> não corresponde a nada: uma única decisão de assembleia exigia dois circuitos no
> software. Por isso o salto — propor alguém direto de leitor(a/e) à coordenação — existe
> como **opção de biblioteca**, desativada por padrão, que o seu coletivo ativa se
> quiser. Ele encurta a escada, nunca os consentimentos.

### 4.4 Sair da equipe

- **Carência de 7 dias** — uma saída de equipe não é imediata; a pessoa passa por um
  estado intermediário, e isso deixa tempo para conversar.
- **Inatividade** — uma conta de equipe que não se conecta há muito tempo sai
  automaticamente, com aviso à pessoa 30 dias antes e 7 dias antes. O aviso de 7 dias
  vai também para a coordenação, e escala para os admins da rede se a pessoa inativa for
  a última coordenação da casa.
- **Passar a mão** — transmitir a coordenação a outra pessoa se faz pelo mesmo circuito
  em três tempos, antes de sair. Não deixe para o último dia.

---

## 5. Dias 7 a 20 — O acervo

### 5.1 As três palavras que você precisa

- **Obra** — a ficha compartilhada: o livro enquanto obra, o mesmo para toda a rede.
- **Holding** — o fato de a sua biblioteca ter essa obra.
- **Exemplar** — o objeto físico na estante, com sua etiqueta, seu estado, sua história.

Três coletivos podem ter o mesmo livro: uma obra, três holdings, vários exemplares.
É por isso que corrigir uma ficha beneficia toda a rede, e por isso que uma ficha se
corrige com cuidado.

### 5.2 Três níveis de ficha, e nenhum é errado

| Nível | Espírito |
|---|---|
| **Simples** | biblioteca militante, sem pretensão acadêmica: tipo, título, autoria, ano, editora, idioma, cota, circulação padrão, capa, ISBN |
| **Avançado** | trabalho de bibliotecári(o/a/e) sem MARC: subtítulo, edição, coleção, local, páginas, contribuições tipadas, assuntos, notas |
| **Completo** | exaustivo: zonas ISBD, MARC, identificadores de autoridade, proveniência completa |

**Mudar de nível não perde nada.** Um campo escondido por um nível mais baixo conserva o
seu valor. Faça o teste uma vez, com os próprios olhos: é o que convence.

**Comece em Simples.** Cinco fichas por semana, em Simples, valem mais que uma ficha
perfeita por mês. O acervo só existe quando está catalogado.

### 5.3 A única exigência que a rede realmente pede

**Nenhum exemplar novo sem modo de aquisição.** De onde veio, quando, doado por quem,
depois de qual acontecimento.

Não é um detalhe erudito. Numa biblioteca militante, a proveniência é a história do
coletivo. Sem ela, o acervo vira uma pilha anônima em uma geração. A rede não pede que
você faça o trabalho retroativo — pede que a dívida pare de crescer a partir de agora.

### 5.4 O resto de `/catalogacao`, quando você precisar

Importações em massa, assistente de deduplicação em três tempos, busca de capas, fontes
externas de metadados, depósito com OCR no navegador, inventário por leitura das
etiquetas QR, periódicos e seus estados de coleção. Nada disso é necessário na primeira
semana. Está lá quando for.

### 5.5 Assuntos e o tesauro FICEDL

O AnarBib traz consigo o **tesauro FICEDL**: 462 termos, traduzidos nos dez idiomas,
entregues com o software. É um bem comum da federação, e ele já vem preenchido — não é
uma tarefa sua.

Os **assuntos locais**, ao contrário, são de cada casa: é o seu acervo, é o seu
vocabulário, são as suas escolhas editoriais. E **alinhar** os seus assuntos aos termos
FICEDL é um ato do coletivo, não uma operação técnica: dizer que o seu « abolicionismo
penal » corresponde ao termo comum « prisão » é uma posição documentária. Por isso o
alinhamento não vem pronto.

---

## 6. Dias 10 a 25 — O balcão

Quatro fluxos, e o painel os organiza:

- **Empréstimo** — saída, devolução (inclusive parcial), prorrogação. A prorrogação pode
  ser feita item por item: se a pessoa terminou dois dos três livros, só o terceiro é
  prorrogado.
- **Devolução** — total ou por linha. Uma ação em massa nunca falha em silêncio: o que
  não passou é listado com a razão.
- **Consulta local** — a pessoa quer ver algo no local, negocia-se um horário. **A
  negociação para em três idas e vindas**: depois disso, o software manda vocês ao
  telefone. É deliberado — uma negociação que passa disso não é um problema de software.
- **Reserva** — até a retirada efetivada, que transforma a reserva em empréstimo.

Ao lado disso, no painel: as **validações** das inscrições de leitor(a/e)s (é aqui que
vocês decidem quem entra), a **caução** se a sua casa a pratica, as **contribuições**, as
**notas de leitura**, os **eventos**.

> **Um defeito conhecido.** O botão « Abrir empréstimos » de certas tarefas do Trabalho
> do dia leva a uma aba vazia. Não é você. Passe pela aba **Empréstimos**
> (`emprestimos-livro`) diretamente.

---

## 7. Dias 20 a 30 — A federação

A página **Federação** tem oito abas: **Início**, **Círculos**, **Diretório**,
**Assembleias**, a gazeta **Rizoma**, **Carta/Boletim**, **Apoio mútuo** e **Comuns**.

É a parte do software que não é um SIGB. Ela existe porque o projeto não quer ser um
« SaaS para bibliotecas »: entrar no AnarBib é entrar num projeto político comum, e uma
rede que só troca registros bibliográficos não é uma rede.

O que fazer nesta última semana, sem pressa:

1. **Passar de `observer` a `federated`**, se foi isso que vocês decidiram — e só se foi.
   Entrar na rede em modo observador durante alguns meses é uma escolha respeitável.
2. **Preencher a sua ficha no Diretório**, para que as outras casas saibam quem vocês
   são e como falar com vocês.
3. **Decidir sobre a cartografia** — aparecer com endereço preciso, só com a cidade, ou
   não aparecer. Nenhuma das três respostas precisa ser justificada.
4. **Olhar os Círculos e as Assembleias**, para saber onde as decisões da rede se tomam.
5. **Se vocês publicam o catálogo**, ver com a rede o que o ponto OAI-PMH significa para
   vocês — é por ele que outros catálogos podem colher o seu.

A página `/rede` é a administração da rede propriamente dita, reservada aos admins da
rede. Coordenar uma biblioteca não dá acesso a ela, e isso é proposital.

---

## 8. As dez decisões que não são técnicas

Recorte esta lista e leve-a para a assembleia. Nenhuma dessas respostas está no software:
o software só registra o que vocês responderem.

1. Onde nos colocamos nos quatro eixos do perfil?
2. O nosso catálogo é público?
3. Emprestamos, e sob quais condições?
4. Quem pode se inscrever como leitor(a/e), e quem valida?
5. Temos cotização? Caução?
6. Quanto tempo guardamos o histórico de leitura das pessoas?
7. Quem é da equipe, e ativamos o salto colegial?
8. Aparecemos na cartografia, e com qual precisão?
9. Participamos das assembleias da rede, e quem nos representa?
10. Como alinhamos os nossos assuntos ao tesauro comum — e o que recusamos alinhar?

---

## 9. O que não quebra nada, e o que pede uma segunda leitura

**Não quebra nada:** clicar em tudo, abrir todas as abas, mudar o nível de ficha para ver,
salvar um volet pela metade, propor uma pessoa e deixar a proposta expirar, ativar e
desativar o salto colegial, passar de `observer` a `federated`, corrigir uma ficha.

**Pede uma segunda leitura, porque não volta atrás ou custa caro:**

- **Excluir** uma conta — e atenção, em português o software distingue **APAGAR** (esvaziar
  o histórico) de **EXCLUIR** (suprimir a conta), com duas palavras de confirmação
  diferentes. Nos outros nove idiomas as duas caem na mesma palavra. Leia a frase inteira
  antes de digitar, não só a palavra pedida.
- Apagar um histórico — os dados não voltam.
- As transições de perfil marcadas como irreversíveis na aba Transições.
- Publicar em rede um acervo que o coletivo ainda não decidiu publicar.
- Retirar alguém da equipe — o prazo de carência de 7 dias existe justamente para isso.

---

## 10. Onde pedir ajuda, e como devolver

**Pedir ajuda:** `anarbib@proton.me`. Diga em qual tela você está e o que esperava ver.
Não há pergunta boba: o software foi escrito por uma pessoa, e cada « não achei » que
chega é um defeito identificado.

**Um ritual que funciona.** Meia hora por semana, com a equipe, três perguntas fixas:

> o que eu não achei na tela? · o que eu fiz sem entender? · o que faltava no software?

As respostas alimentam uma folha de lacunas que vira a pauta seguinte — e um material de
contribuição para o projeto. É o único dispositivo que faz o uso subir até o código.

**Devolver, sem programar.** O arquivo `AIDER.md`, na raiz do repositório, lista as
tarefas abertas que não exigem código: tradução, revisão de escrita inclusiva,
documentação, alinhamento de assuntos, teste de telas. O AnarBib é AGPLv3 e tem hoje
um(a/e) só mantenedor(a/e) — é a sua principal fragilidade, e ela se diz em vez de se
esconder.

---

## 11. Os trinta dias em uma página

| Quando | O quê | Onde |
|---|---|---|
| Dia 1 | Entrar, trocar a senha, passear sem mudar nada | `/login`, `/conta` |
| Dias 1–3 | Etapa 0: os quatro eixos, decididos em coletivo | `/atelier` |
| Dias 3–5 | Volets 1 a 9 | `/atelier` |
| Dia 5 | Volet 10: baixar o esqueleto de regimento | `/atelier` |
| Dias 5–10 | Levar o regimento à assembleia, emendar, recarregar | assembleia, depois `/atelier` |
| Dias 5–10 | Recolher os ID públicos, abrir os circuitos de cooptação | `/biblioteca`, aba Equipe |
| Dias 7–20 | Primeiras fichas em modo Simples, todas com proveniência | `/catalogacao` |
| Dias 10–25 | Primeiro dia de balcão em autonomia | `/painel` |
| Dias 20–30 | Ficha no diretório, cartografia, modo de rede | Federação, `/biblioteca` |
| Dia 30 | Escrever à rede: o que faltou, o que enganou | `anarbib@proton.me` |

---

*Este guia existe em dez idiomas: pt-BR, fr, es, en, it, de, ca, eo, nl, el. Ele descreve
o estado do software em setembro de 2026 e será corrigido quando o software mudar — se
uma tela não corresponder ao que está escrito aqui, é o guia que está errado, e dizer
isso é uma contribuição.*

**Bem-vind(o/a/e).**
