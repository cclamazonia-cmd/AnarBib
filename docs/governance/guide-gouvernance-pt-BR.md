---
title: "Guia de governança do AnarBib"
subtitle: "Para uso das coordenadoras/es/es de biblioteca e das administradoras/es/es da rede"
author: "Projeto AnarBib"
date: "Versão 1.1 — 5 de junho de 2026"
lang: pt-BR
---

# Prefácio

Este guia se destina às pessoas que, na rede AnarBib, exercem uma função de coordenação — seja coordenando uma biblioteca local ou administrando a rede. Ele tem um duplo objetivo:

- **Explicar a lógica política** das regras inscritas no SIGB AnarBib, e sua filiação com o projeto de emancipação coletiva que deu origem às bibliotecas anarquistas;
- **Instrumentalizar as práticas** cotidianas, respondendo às questões concretas que as coordenações encontram ao usar o software.

## Uma convenção política

Este guia não é o regulamento da rede, e não tem nenhuma autoridade superior às decisões dos coletivos que a compõem. O que ele contém só tem força porque humanas/os/es chegaram a um acordo para fazer as coisas funcionarem assim em determinado momento. Se as práticas evoluírem, este texto terá que evoluir com elas, ou ser contradito, ou ser rasgado. É o uso que dele fizerem os coletivos que decidirá seu destino.

As regras técnicas que o SIGB AnarBib faz respeitar — os prazos de carência, os fluxos de cooptação, os status dos memberships, etc. — são também convenções. Foram escritas por camaradas em datas precisas, para resolver problemas precisos. Estão consignadas em **arquivos de especificação** (os `spec-*.md` do repositório), datados e assinados, que são eles próprios emendáveis. Quando se lê este guia, lê-se o estado de um debate em um dado instante. Não é uma constituição.

## Como este guia está organizado

O guia está em duas partes:

- **Parte I — O porquê.** Quatro capítulos que estabelecem o quadro político: para que serve um SIGB anarquista, quais são seus princípios fundadores, como se articulam os dois perímetros (biblioteca local e rede), e como as próprias regras podem ser emendadas.

- **Parte II — O como.** Seis capítulos práticos que tratam cada um de uma grande questão operacional: cootar, remover, gerir as situações que desviam, exercer uma função de admin de rede, garantir a transparência, e um último capítulo que comenta casos concretos do início ao fim.

Ao final de cada capítulo prático, uma rubrica **"Se a regra te incomoda"** lembra onde discuti-la e como propor uma emenda. Isso é importante porque essas regras só fazem sentido se forem emendáveis.

Os anexos no final do volume servem de referência rápida: glossário, índice das funções técnicas com sua tradução política, modelo de proposta de emenda e links para as specs fontes.

## Como ler este guia

Pode-se lê-lo de uma vez, mas provavelmente não é o melhor uso. Três formas de entrar no texto segundo as necessidades:

- **Para compreender o espírito do projeto** antes de assumir uma função: ler a Parte I (capítulos 1 a 4).
- **Diante de uma situação concreta**: pular diretamente ao capítulo prático correspondente (5 a 10).
- **Para se informar visando uma AG** onde uma questão de governança será colocada: ler o capítulo correspondente mais a rubrica "Se a regra te incomoda" correspondente, e consultar a spec fonte no Anexo D.

O que está escrito aqui se apoia em quatro documentos de especificação:

- `spec-gouvernance-roles.md` (5 de maio de 2026) — papéis, status, transições;
- `spec-administrateur-reseau.md` (11 de maio de 2026) — separação local/rede, cooptação por unanimidade;
- `spec-validation-physique.md` (3 de maio de 2026) — modos de acolhimento das contas de leitoras/es/es;
- `spec-refactor-v3-semantique.md` (9 de maio de 2026) — semântica do fluxo de reserva (mencionado marginalmente).

As referências a essas specs são retomadas ao longo do texto na forma `(cf. spec-gouvernance, §3.4)` para permitir aprofundamento.

## Uma nota sobre a voz

O texto alterna entre **a gente** (o coletivo AnarBib, do qual a autora/o autor/a pessoa autora e a leitora/o leitor/a pessoa leitora também fazem parte), **você** (quando se fala a uma/um/a coord ou admin específica/o/e que deve fazer uma escolha), e **nós** (quando se fala das camaradas e camarades que escreveram as regras, em determinado momento, e que podem ser diferentes de quem as lê). É intencional. Não há neutralidade institucional aqui: este texto é carregado por camaradas, e se dirige a camarades.

\newpage

# Parte I — O porquê

\newpage

# 1. Um SIGB anarquista, o que isso quer dizer?

## 1.1. O SIGB não é a AG

O primeiro princípio a ter em mente, e o mais difícil, é este: **o SIGB registra as decisões do coletivo, ele não as toma**. Esta frase parece inocente. Na realidade é o pivô em torno do qual todo o resto se organiza.

Cada vez que o SIGB AnarBib parece uma autoridade — quando recusa uma promoção, quando impõe um prazo de carência de sete dias, quando bloqueia uma transição de status — ele apenas **torna executável** uma regra que os coletivos se deram. A regra foi escrita em algum lugar, numa spec, após discussão. Alguém releu e criticou. Uma versão foi fixada e implantada. E agora, no instante em que você clica no botão, o software se limita a aplicar o que foi acordado.

Se você acha a regra boba, contraproducente, ou injusta, não é o SIGB que se deve combater. É a spec que se deve emendar. Ver capítulo 4.

## 1.2. A tensão assumida

Todo software que gerencia permissões é, por construção, um dispositivo de hierarquização. É preciso que alguém possa validar uma inscrição, modificar a identidade pública de uma biblioteca, acessar os dados pessoais de uma leitora/um leitor/uma pessoa leitora. Esta necessidade técnica está em tensão aparente com o ideal de horizontalidade que anima as bibliotecas anarquistas.

AnarBib **assume essa tensão** em vez de mascará-la. O compromisso político encontrado se resume em dois pontos:

- Os **papéis não são graus**. São **funções** temporariamente delegadas pelo coletivo a certas/certos/certes de suas/seus/sues membras/os/es para executar tarefas técnicas precisas. Ninguém é coordenadora/coordenador/coordenador·e "vitalícia/o/e". Ninguém é admin de rede "por essência". Essas funções são emprestadas, e podem ser retomadas.

- Os **mecanismos de retirada** contam tanto quanto os mecanismos de nomeação. O SIGB prevê explicitamente como alguém sai de uma função — por auto-rebaixamento, por solicitação coletiva com prazo de carência, por auto-retirada da rede, por retirada coletiva por unanimidade. Uma função que não pode ser deixada não é uma função, é uma captura.

## 1.3. Delegação e rotação

A ideia central é a da **delegação com rotação**. Um coletivo delega a certas/certos de suas/seus membras/os a execução de tarefas técnicas (gerir os empréstimos no SIGB, modificar a visibilidade da biblioteca, acolher uma nova membra/um novo membro na equipe). Essa delegação é:

- **Explícita**: ela se concretiza em um ato de cooptação rastreado no log de auditoria;
- **Reversível**: a pessoa delegada pode deixar a função quando quiser, e o coletivo pode solicitá-lo segundo modalidades enquadradas;
- **Temporária por natureza**: mesmo que nenhuma duração seja imposta pelo SIGB, a cultura política da rede é que se faz rodar as funções, e não se fica instalada/instalado nelas.

É essa rotação das funções que faz a diferença entre uma "delegação" (anarquista) e uma "hierarquia" (estatal ou capitalista). Se a gente se instala numa função, vira um degrau. Se sai dela regularmente, continua sendo uma camarada ou camarade que presta um serviço.

## 1.4. Os oito princípios fundadores

A spec de governança dos papéis (`spec-gouvernance-roles.md`, §2) explicita oito princípios fundadores. Listamo-los aqui para referência ao longo do guia; cada capítulo prático da Parte II os retomará.

**P1 — Delegação, não hierarquia.** Nenhum papel é um título. Todos os papéis são temporários por natureza e revogáveis.

**P2 — Cooptação para os papéis de staff.** A entrada numa equipe (tornar-se librarian ou coordenador) se dá por cooptação das/dos coordenadoras/es existentes. Cabe ao coletivo decidir quem é admitida/o; a/o coordenadora/coordenador é apenas a mão que executa a decisão no SIGB.

**P3 — Rebaixamento voluntário sempre possível.** Toda pessoa com um papel de staff pode se rebaixar a qualquer momento, sem consulta. "Passo a função" é um direito fundamental.

**P4 — Exclusão enquadrada por um prazo de carência.** A exclusão não voluntária de uma/um librarian por uma/um coordenadora/coordenador passa por um prazo de carência de sete dias antes de fazer efeito. Esse prazo permite a deliberação coletiva e a eventual anulação por outra/outro coordenadora/coordenador.

**P5 — Transparência máxima.** O log de auditoria das mudanças de papel é legível por todo o staff ativo da biblioteca, não apenas pelas/pelos coordenadoras/es. Impedir manipulações opacas faz parte da cultura política de horizontalidade informacional.

**P6 — Notificações sistemáticas.** Toda mudança de papel aciona um e-mail para a pessoa envolvida e para toda a coordenação. Ninguém pode ter seu papel modificado sem saber, e a coordenação é sempre informada.

**P7 — Soberania local das bibliotecas.** As mudanças de papel na biblioteca A não afetam nada na biblioteca B, mesmo para a mesma pessoa. Cada biblioteca é soberana sobre suas delegações internas.

**P8 — O SIGB não modela a AG.** O SIGB executa as decisões, ele não as toma. Não contém nenhum mecanismo de votação, quórum, ou deliberação. Essas coisas acontecem no coletivo, fora do software.

## 1.5. O que o SIGB não faz

É útil tornar explícitas as escolhas de **não-modelagem**:

- O SIGB **não define** o que é uma "boa" coordenação. Uma biblioteca pode decidir em círculo, em AG plenária, por revezamento, por sorteio, por consenso, por maioria. O SIGB não se importa.
- O SIGB **não mede** a legitimidade política de uma cooptação. Se uma/um coord clica em "promover X librarian", o SIGB registra. Cabe ao coletivo garantir que a decisão foi tomada corretamente, e é na cultura política do coletivo que essa garantia se joga.
- O SIGB **não arbitra** conflitos. Quando algo desanda, o SIGB fornece ferramentas (suspensão imediata, solicitação de retirada, log de auditoria legível), mas a decisão política permanece fora do software.

Essa modéstia não é um defeito, é uma exigência. Um SIGB que pretendesse modelar a vida política de um coletivo seria, ipso facto, autoritário — imporia sua visão do que é uma "boa" decisão. AnarBib recusa essa inclinação.

## 1.6. E o respeito às liberdades digitais?

Três esclarecimentos, porque a questão sempre volta:

- **Dados pessoais**: as contas de leitoras/es/es contêm o que a pessoa quis colocar nelas. As bibliotecas só têm acesso aos dados estritamente necessários ao seu funcionamento. Os memberships em outras bibliotecas são, por construção, estanques (P7).

- **Log de auditoria**: o log é público **para o staff ativo** da biblioteca, não para as/os leitoras/es nem para o restante da rede. Essa transparência interna serve para impedir manipulações opacas entre coordenações; não é um panóptico dirigido contra as/os leitoras/es.

- **Logs cross-bibliotecas**: quando uma/um admin de rede intervém em uma biblioteca (caso coberto pela spec admin-reseau, §6.3.1), a ação é rastreada numa tabela dedicada com nível de criticidade. É legível pelas/pelos admins de rede e pela coordenação da biblioteca envolvida. Transparência nos dois sentidos.

\newpage

# 2. Os dois perímetros: biblioteca local e rede

## 2.1. Por que essa separação

A rede AnarBib não é uma cadeia de bibliotecas com uma sede central. É uma **federação de coletivos autônomos**. Essa realidade política acabou por se impor na própria estrutura do SIGB.

Inicialmente, nas primeiras versões, o papel de "administradora/administrador AnarBib" estava vinculado a uma biblioteca precisa na tabela `user_library_memberships`. Essa modelagem sugeria — sem dizê-lo — que uma/um admin AnarBib *administrava uma biblioteca*. Isso não era politicamente verdade: uma/um admin de rede anima a coordenação inter-bibliotecas, ela/ele não dirige nenhuma biblioteca em particular.

A spec `spec-administrateur-reseau.md` (11 de maio de 2026) oficializou a separação. Doravante o SIGB reconhece **dois perímetros distintos**:

- **O staff local** de uma biblioteca (papéis `reader`, `librarian`, `coordenador`), armazenado em `user_library_memberships`. Sua autoridade política se situa **no perímetro da biblioteca**.

- **A administração da rede** (tabela `network_administrators`), sem vínculo a uma biblioteca. Sua autoridade política é **transversal**, mas nunca se substitui à autonomia local.

## 2.2. O que cada perímetro faz

**O staff local** gere o cotidiano de uma biblioteca: empréstimos, devoluções, reservas, validação das inscrições, modificação do regulamento, das políticas de circulação, da identidade pública da biblioteca. Tudo o que diz respeito ao funcionamento de **uma** biblioteca se resolve no nível do staff local.

**A administração da rede** assegura a coordenação inter-bibliotecas: ativação de novas bibliotecas, moderação do catálogo compartilhado, manutenção técnica da plataforma, acolhimento de novos coletivos, e intervenção excepcional quando uma biblioteca se encontra bloqueada (sem coord ativo/a, conflito maior, etc.). Tudo o que diz respeito à **rede** se resolve no nível da administração de rede.

## 2.3. A regra da não-sobreposição

Uma regra política simples guia todos os contadores e todas as visões do SIGB:

> **Cada página conta a história de seu perímetro. Um contador conta o que está inscrito em seu perímetro, nem mais, nem menos.**

Concretamente:

- A página de uma biblioteca conta seus memberships locais. Ponto. As/os admins de rede não aparecem nesses contadores, mesmo que possam tecnicamente intervir na biblioteca.
- A página da rede conta suas/seus administradoras/es de rede. Ponto.

Se uma pessoa é ao mesmo tempo `coordenador` de uma biblioteca **e** administradora/administrador de rede (o caso de Xavier em 11 de maio de 2026), ela aparece nos dois contadores, **uma vez em cada**, sem deduplicação cruzada. São **duas inscrições políticas distintas**, contadas cada uma em seu perímetro.

Por que essa regra é politicamente saudável, em quatro pontos:

- **Honestidade**: seu engajamento local é contado na biblioteca onde você atua; seu engajamento na rede é contado no nível da rede. Ninguém te conta "1,5 vez".
- **Legibilidade**: uma militante/um militante/uma pessoa militante que olha a ficha de uma biblioteca vê imediatamente quantas pessoas estão engajadas **localmente**, sem ter que se perguntar se admins de rede "externas/os/es" incham o contador.
- **Robustez**: se amanhã forem acrescentados papéis intermediários (auxiliar, estagiária/estagiário, observadora/observador/observadore), a regra "página = perímetro" permanece clara.
- **Coerência política**: a separação entre admin de rede e staff local é uma **decisão política**, não um detalhe de modelagem. Os contadores devem refleti-la.

## 2.4. O direito transversal da/do admin de rede

Este ponto merece ser bem compreendido porque é fácil de interpretar mal.

**Uma/um admin de rede pode tecnicamente intervir em qualquer biblioteca.** Ela/ele pode, por exemplo, ler o catálogo de uma biblioteca `private`, modificar sua visibilidade, ou — em casos excepcionais — criar ou modificar memberships. É o que a spec chama de **direito de intervenção transversal**.

Esse direito existe por duas razões:

- **Manutenção**: é preciso que alguém possa desbloquear uma biblioteca que entrou em pane (sem coord, configuração quebrada, etc.).
- **Mediação**: quando um conflito grave atravessa uma biblioteca e impede o coletivo local de funcionar, é preciso um recurso.

Mas esse direito **não** faz da/do admin de rede uma/um superiora/superior hierárquica/hierárquico da coordenação local. A doutrina da rede, estabelecida neste guia:

> **Uma intervenção de admin de rede em uma biblioteca local deve ser precedida de uma informação à coordenação local envolvida**, salvo urgência vital (comprometimento ativo, assédio em curso, ataque contra a plataforma). A informação prévia não é um pedido de autorização: a/o admin de rede tem o direito de agir. Mas ela é uma **marca de respeito** à autonomia da biblioteca, e preserva a possibilidade de outro arranjo (por exemplo: "deixa eu tentar resolver isso primeiro, te mantenho informada/o/e").

A rastreabilidade técnica existe por outro lado: todas as ações cross-bibliotecas de uma/um admin de rede são rastreadas na tabela `cross_library_actions_log` com um nível de criticidade, legíveis pela coordenação local a posteriori.

## 2.5. A soberania local é inviolável

Um último esclarecimento político, que decorre do princípio **P7 — Soberania local das bibliotecas**.

As bibliotecas da rede AnarBib **se reconhecem mutuamente**. Quando BLMF valida fisicamente uma nova leitora/um novo leitor/uma nova pessoa leitora (cf. `spec-validation-physique.md`), essa validação vale para todas as bibliotecas `network` da rede. É um **pacto de circulação implícito** entre bibliotecas que compartilham cultura política suficiente para se confiarem mutuamente.

Mas esse reconhecimento mútuo **não dá nenhum direito de ingerência** de uma biblioteca em outra. A coordenação da biblioteca A não pode modificar os memberships da biblioteca B. Não pode ver os dados pessoais das/dos leitoras/es de B (exceto as/os que também estão inscritas/os nela). Não pode mudar o regulamento de B.

Cada biblioteca permanece **soberana sobre suas delegações internas**, sua política de acolhimento, seu modo de validação, suas regras de contribuição, seu regulamento interno. A rede não diz como elas devem funcionar. Diz apenas com quem elas se reconhecem.

\newpage

# 3. Estatutos, papéis, transições: a gramática do SIGB

Este capítulo é um pouco mais árido que os outros. Aqui estabelecemos o vocabulário técnico que será usado ao longo de todo o guia. Se você o pular na primeira leitura, poderá retornar a ele quando necessário.

## 3.1. Os quatro papéis

O SIGB AnarBib utiliza quatro papéis, declarados na base de dados pela restrição `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` na tabela `user_library_memberships`.

**`reader`** — Conta de leitore(a/e) básica. Sem poder de administração. Permissões: consultar o catálogo (conforme a visibilidade da biblioteca), emprestar, reservar, consultar em sala, modificar seus próprios dados pessoais, solicitar a migração ou exclusão de sua conta.

**`librarian`** — Staff operacional. Gerencia o cotidiano: empréstimos, reservações, devoluções, validação das inscrições (conforme o modo da biblioteca), modificação dos dados do catálogo, acesso aos dados pessoais das leitoras/os/es da biblioteca. **Somente leitura** na lista da equipe. Recebe as notificações de mudanças de papel e pode ler o log de auditoria da equipe (P5).

**`coordenador`** — Staff de coordenação. Tudo o que tem um(a/e) librarian, mais: modificar a identidade pública da biblioteca (nome, logo, contato, etc.), modificar a configuração (políticas de empréstimo, regulamento), gerenciar as regras de contribuição, **e todas as ações de governança de equipe**: cooptar, solicitar uma saída, suspender, levantar uma suspensão, cancelar uma solicitação de saída.

**`administrador`** — Papel histórico, em vias de extinção. Existia para significar "direito de administração cross-biblios" mas vinculado a uma `library_id`. Agora substituído pelas **administradoras/es/es de rede** armazenadas/os/es na tabela `network_administrators` (cf. capítulo 2). A spec admin-rede prevê a migração progressiva e a remoção final deste papel da tabela `user_library_memberships`.

## 3.2. Os cinco estatutos de uma membership

Cada linha da tabela `user_library_memberships` tem um **estatuto** que expressa o estado da delegação em um determinado momento. Cinco estatutos são possíveis:

**`active`** — Estado normal. A pessoa tem seu papel e o exerce.

**`pending`** — Reservado para a spec de validação física. A membership é criada mas aguarda um encontro físico com um(a/e) librarian+ da biblioteca de inscrição. Sem acesso às funções do papel enquanto neste estatuto.

**`suspended`** — **Medida conservatória** tomada por um(a/e) coordenador(a/e). Nenhum acesso. Uso: assédio relatado aguardando investigação, conta comprometida, conflito em mediação. **Duração indefinida**; o levantamento é manual, por um(a/e) coord (retorno a `active`) ou por destituição efetiva.

**`pending_removal`** — **Período de carência de sete dias** antes da exclusão efetiva. Nenhum acesso durante este período. Evolução possível: cancelamento por um(a/e) outre coord (retorno a `active`), auto-rebaixamento pela própria pessoa (atalho), ou passagem automática a `inactive` no D+7.

**`inactive`** — Membership encerrada. A pessoa não está mais na equipe. Nenhum acesso. Várias origens possíveis: saída voluntária, fim da carência, conta abandonada (automático após 9 meses).

## 3.3. O esquema de transições

O SIGB não permite qualquer transição entre estatutos. A seguir, simplificado, o esquema autorizado:

```
                       ┌──────────────┐
                       │   active     │ ◄──────────┐
                       └──────┬───────┘            │
                              │                    │
              ┌───────────────┼───────────────┐    │
              ▼               ▼               ▼    │
       ┌─────────────┐  ┌─────────────┐  ┌─────────┴────┐
       │  suspended  │  │ pending_    │  │  inactive    │
       │             │  │ removal     │  │              │
       └──────┬──────┘  └──────┬──────┘  └──────────────┘
              │                │
              │ levantamento   │ cancelamento
              └────────────────┴────────────┐
                               │            │
                               ▼ (D+7)      ▼
                        ┌──────────────┐
                        │   inactive   │
                        └──────────────┘
```

Algumas regras-chave:

- **Não** se pode passar diretamente de `active` a `inactive` para um(a/e) librarian por decisão unilateral de um(a/e) outre coord. É preciso passar por `pending_removal` e aguardar a carência (ou que a pessoa se rebaixe ela mesma).
- **Sempre** se pode passar do próprio estatuto `active` a `inactive` (auto-rebaixamento, direito P3).
- `suspended` **não** tem duração máxima. Não é uma carência antes da exclusão, é uma medida conservatória — dura o tempo da deliberação.
- De `inactive`, **não se retorna** a `active`. Para reintegrar uma pessoa, cria-se uma nova linha de membership. O histórico é preservado.

## 3.4. As nove transições, quem pode fazer o quê

A spec de governança dos papéis formaliza nove transições, listadas aqui de forma condensada. O detalhamento operacional está na parte II.

| # | Transição | Quem | Mecanismo |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coord+ | Cooptação |
| T2 | `librarian` → `coordenador` | Coord+ | Cooptação |
| T3 | `coordenador` → `librarian` | Própria pessoa OU outras/os/es coords | Auto-rebaixamento OU saída coletiva com carência |
| T4 | `librarian` → `reader` (voluntária/o/e) | Própria pessoa | Auto-rebaixamento |
| T5 | `librarian` → `reader` (coletivo) | Coord+ | `pending_removal` com carência de 7 dias |
| T6 | Suspensão imediata | Coord+ | Passagem a `suspended` |
| T7 | Levantamento de suspensão | Coord+ | Retorno `suspended` → `active` |
| T8 | Cancelamento de uma solicitação de saída | Coord+ | Retorno `pending_removal` → `active` |
| T9 | Saída automática (conta abandonada) | Cron | Passagem a `inactive` após 9 meses sem login |

Três princípios estruturam este quadro:

- **A entrada passa pela cooptação** (T1, T2). Ninguém se promove sozinha/o/e.
- **A saída voluntária é sempre possível** (T3 auto, T4). Ninguém fica presa/o/e em uma função que não quer mais exercer.
- **A saída imposta é retardada pela carência** (T5). Sete dias para permitir um eventual recuo coletivo.

## 3.5. Lado admin de rede: um esquema gêmeo

A administração de rede (tabela `network_administrators`) tem seu próprio ciclo de vida, estruturalmente muito próximo mas com duas especificidades:

- **Cooptação por unanimidade**: para adicionar um(a/e) nova/o/e admin de rede, uma proposta é aberta por um(a/e) admin ativa/o/e, e **todas/os/es as/os/es outras/os/es admins ativas/os/es** devem votar `favorable`. Um único voto `opposed` (com fundamentação obrigatória de no mínimo 20 caracteres) bloqueia a proposta. Uma abstenção também bloqueia enquanto não for convertida em voto.

- **Saída coletiva por unanimidade**: para retirar um(a/e) admin de rede contra sua vontade, o mesmo workflow se aplica em espelho. Com um prazo de carência de **sete dias** após acordo unânime (campo `pending_collective_removal_until`).

A auto-saída, por sua vez, é **unilateral e sempre possível** (exceto se for a única/o/e admin ativa/o/e, caso em que a transição passa por `pending_removal` com uma carência de 30 dias, e um e-mail de alerta às/aos/es outras/os/es admins).

Detalhes completos no capítulo 8.

\newpage

# 4. Reversibilidade e emendabilidade

Este capítulo curto trata de uma questão política crucial: **como essas regras podem ser modificadas?** Se não pudessem ser modificadas, o SIGB seria uma autoridade, e todo o resto deste guia seria uma mentira.

## 4.1. Três níveis de emendabilidade

É preciso distinguir três níveis de regras, que não se emendas da mesma forma:

**As práticas locais de uma biblioteca** — política de acolhimento, modo de validação física (`open` ou `manual_validation`), regulamento interno, frequência das assembleias, modalidades de cooptação. Essas práticas são **internas a cada biblioteca**. A rede não se intromete. Emendas-se em assembleia da biblioteca, ou segundo o procedimento que o coletivo adotou.

**As regras da rede** — separação local/rede, princípio de cooptação por unanimidade para as/os/es admins de rede, doutrina de informação prévia durante uma intervenção cross-biblios, modalidades de ativação de novas bibliotecas. Essas regras são **inter-biblios**. Emendas-se em coordenação de rede, após discussão entre admins de rede e coordenações locais envolvidas.

**Os fundamentos políticos do projeto** — os oito princípios (P1 a P8 do capítulo 1), a ideia de que o SIGB não modela a assembleia, a modéstia reivindicada do software diante da vida política dos coletivos. Esses fundamentos podem ser emendados, mas são estruturantes: modificá-los é provavelmente modificar o que chamamos de "AnarBib" em sentido amplo. Uma revisão desta amplitude passaria por uma discussão coletiva em toda a rede, provavelmente por ocasião de um evento (encontro anual, etc.).

## 4.2. Como propor um emenda

Não há uma única forma de fazer — cada nível tem a sua — mas aqui está o padrão geral que a rede tende a praticar:

1. **Identificar a spec envolvida**. As regras do SIGB estão consignadas em arquivos `spec-*.md` do repositório. Encontre aquela que contém a regra que você quer emendar (o anexo D fornece as correspondências).

2. **Redigir uma nota de emenda**. Formato livre, mas que responda a: qual regra, por que ela apresenta problema, qual modificação se propõe, quais consequências técnicas e políticas se antecipa. O anexo C propõe um modelo.

3. **Fazer circular a nota**. Conforme o nível:
   - **Local**: em assembleia da biblioteca, ou no canal de discussão do coletivo.
   - **Rede**: no canal de coordenação inter-biblios (Matrix `#anarbib`), marcando as/os/es admins de rede e as coordenações locais pertinentes.
   - **Fundamentos**: em todos os canais, e provavelmente na pauta de um encontro.

4. **Discutir, emendar, reter uma versão**. O SIGB não diz como esta etapa deve se desenrolar. É o ofício dos coletivos.

5. **Se a decisão for tomada**: um(a/e) admin de rede ou um(a/e) dev (frequentemente as mesmas pessoas) implementa a modificação na spec correspondente, depois no código. A nova versão é implantada segundo o procedimento habitual (changelog, comunicação, etc.).

## 4.3. Se a decisão técnica apresentar problema

Acontece de se chegar a um acordo político sobre uma regra, mas sua tradução técnica ser complicada, pesada ou ter efeitos colaterais indesejáveis. Isso é normal. As specs existentes estão repletas de notas do tipo "esta decisão política implica tocar em 22 sub-SELECT nas RLS, o que justifica um refatoramento prévio". O diálogo político/técnico é permanente.

Quando você propuser uma emenda, não hesite em fazê-lo mesmo que não tenha ideia da dificuldade técnica. As/os/es devs da rede lhe dirão o que isso custa. E se for muito caro, vocês poderão decidir coletivamente se o desafio político vale o custo técnico. Inversamente, às vezes uma mudança política aparentemente simples permite simplificar enormemente a base de código.

## 4.4. Este guia é ele próprio emendável

Este guia é versionado. A versão corrente está indicada na página de capa. Se você achar que ele diz algo errado, que esqueceu um caso, ou que assume uma posição que não corresponde mais à doutrina da rede, **diga**. Abra uma discussão, proponha uma modificação, ou reescreva a passagem e submeta-a.

Um guia que não pode ser modificado não é um guia, é um dogma. O projeto AnarBib não tem vocação para produzir dogmas.

\newpage

# Parte II — O como

\newpage

# 5. Cooptar alguém para sua equipe

Este capítulo cobre as transições T1 (`reader` → `librarian`) e T2 (`librarian` → `coordenador`), ou seja, os **dois movimentos de entrada** em uma equipe de biblioteca. A validação física de um(a/e) nova/o/e `reader` (que não é uma cooptação no sentido político, mas uma operação técnica de acolhimento) é tratada separadamente no §5.5.

## 5.1. O princípio político

> **P2 — Cooptação para os papéis de staff.** A entrada em uma equipe se faz por cooptação das/os/es coordenadoras/es/es existentes. Cabe ao coletivo político decidir quem é admitida/o/e; a/o/e coordenadora/or/e é apenas a mão que executa a decisão no SIGB.

Isso significa que **clicar em "Promover"** não é uma decisão pessoal da/o/e coord que clica. É a **execução técnica** de uma decisão que foi tomada — ou deve ser tomada — pelo coletivo político da biblioteca. A doutrina da rede sobre o "quando exatamente" a decisão deve ser tomada não é deliberadamente definida por este guia: cada biblioteca faz sua própria doutrina (ver §5.4).

## 5.2. Para fazer entrar alguém como `librarian` (T1)

### Pré-condições

- A pessoa tem uma conta AnarBib (está inscrita em alguma parte da rede).
- Ela não tem ainda uma membership `librarian` ou `coordenador` ativa na mesma biblioteca.
- Ela pode, ou não, já ter uma membership `reader` na mesma biblioteca. Se sim, essa membership existente continuará ativa em paralelo (multi-membership autorizado).

### Procedimento no SIGB

1. Ir a `/biblioteca`, aba **Equipe** (visível às/aos/es `coordenador+`).
2. Se a pessoa já é leitora/or/e da biblioteca, clicar em **"Convidar para a equipe"** na sua linha. Se ela ainda não é leitora/or/e, usar a busca na barra superior ou — se ela ainda não tem conta — passar pelo workflow de convite por e-mail (a vir, cf. `spec-invitation-equipe.md`).
3. Escolher o papel `librarian`.
4. Confirmar o modal. Um campo "Motivo" é opcional — serve para registrar no log de auditoria o contexto da cooptação (por exemplo, "decisão da assembleia de 04/05" ou "cooptação em círculo restrito, a validar na próxima assembleia").
5. O SIGB executa:
   - Criação de uma linha `user_library_memberships` com `role='librarian'`, `status='active'`.
   - E-mail à pessoa envolvida: "Você foi nomeada/o/e librarian de [biblioteca] por [você]".
   - E-mail a todas/os/es as/os/es coordenadoras/es/es ativas/os/es da biblioteca.
   - Entrada no log de auditoria: `action='promoted_to_librarian'`.

### Efeito imediato

A pessoa recebe, sem demora, as permissões de `librarian`: gestão de empréstimos, validação das inscrições, acesso aos dados pessoais das leitoras/os/es da biblioteca, etc. Ela não recebe as permissões de modificação da identidade pública nem da configuração — estas são reservadas às/aos/es `coordenador+`.

### Lado técnico

RPC envolvida: `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.3. Para promover um(a/e) `librarian` a `coordenador` (T2)

### Pré-condições

- A pessoa tem uma membership `librarian` `active` na biblioteca.
- Ela não tem ainda uma membership `coordenador` ativa na mesma biblioteca.

### Procedimento no SIGB

1. Ir a `/biblioteca`, aba **Equipe**.
2. Na linha da pessoa, clicar em **"Promover"** → **"coordenador"**.
3. Confirmar o modal. O campo "Motivo" é opcional.
4. O SIGB executa:
   - Criação (ou reativação) de uma linha `coordenador` `active`. A antiga linha `librarian` permanece ativa em paralelo (multi-membership; ver §5.6).
   - E-mail à pessoa.
   - E-mail a todas/os/es as/os/es coordenadoras/es/es ativas/os/es.
   - Entrada no log de auditoria: `action='promoted_to_coordenador'`.

### Efeito imediato

A pessoa recebe, além de suas permissões de `librarian`, as permissões de coordenação: modificação da identidade pública, da configuração, das regras de contribuição, e todas as ações de governança de equipe.

### Lado técnico

RPC envolvida: `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.4. A questão política: quando clicar?

É a questão que toda/o/e coord se faz na primeira vez. A rede AnarBib **deliberadamente não definiu** esta questão no nível do guia: cada biblioteca faz sua própria doutrina, porque a cultura política de um coletivo anarquista não se decide na escala de um guia genérico.

Aqui estão as três doutrinas que se encontram na rede, sem julgamento:

**Doutrina 1 — Espera estrita.** Só se clica **após** uma decisão registrada do coletivo (assembleia, círculo, consenso formal, pouco importa a modalidade). A/o/e coord apenas executa. Vantagem: maximização da horizontalidade, rastreabilidade política forte. Desvantagem: pode ser lento, particularmente quando a biblioteca está em fase inicial ou o coletivo está disperso.

**Doutrina 2 — Antecipação balizada.** A/o/e coord pode antecipar uma decisão que considera certa ("é evidente que Voltairine vai ser cooptada, faz seis meses que ela vem toda semana"), **desde que o explicite no log de auditoria**: motivo = "antecipação sob minha responsabilidade, a validar na próxima assembleia". A decisão pode ser contestada a posteriori, e a saída continua sempre possível. Vantagem: flexibilidade prática. Desvantagem: desloca uma parte da responsabilidade política para a/o/e coord que clica.

**Doutrina 3 — Círculo de coord.** A cooptação é decidida por acordo entre as/os/es coords ativas/os/es da biblioteca, sem passar pela assembleia plenária. Argumento: a coordenação é ela própria um coletivo deliberante, e tem o mandato para agir. Vantagem: intermediária entre 1 e 2. Desvantagem: pode se tornar opaca se a coordenação não se renova ela própria.

**Nossa recomendação** (e nada mais que isso): **escolha explicitamente** uma doutrina, escreva-a no regulamento de sua biblioteca, e indique-a no campo "Motivo" do log de auditoria a cada cooptação ("doutrina 2 — antecipação sob minha responsabilidade", por exemplo). A opacidade raramente é boa em política.

## 5.5. Caso particular: a validação física de um(a/e) `reader`

A **chegada** de um(a/e) `reader` a uma biblioteca é uma operação diferente de uma cooptação no sentido político. Está coberta pela spec `spec-validation-physique.md`.

Dois modos possíveis, escolhidos por cada biblioteca em sua configuração:

**Modo `open`** — A validação é **automática** na inscrição. Uma vez a conta criada e o e-mail confirmado, a/o/e `reader` tem acesso imediato aos catálogos `public` e `network`. Adequado para bibliotecas com menor exposição política.

**Modo `manual_validation`** — A conta é criada online mas fica **em espera** até um **encontro físico** entre a/o/e `reader` e um(a/e) `librarian+` da biblioteca de inscrição. Adequado para bibliotecas expostas (contexto político tenso, acervo sensível, locais frágeis, etc.).

### Procedimento de validação física (modo `manual_validation`)

1. A pessoa se inscreve online e escolhe sua biblioteca como biblioteca de referência.
2. Sua conta é criada com `status='pending'`. Ela recebe um e-mail explicando que deve vir se apresentar fisicamente à biblioteca.
3. Quando ela vem, um(a/e) `librarian+` a encontra, verifica o que há a verificar (a doutrina do que "verificar" significa é local), e clica em **"Validar"** na sua linha na aba **Equipe** → seção **Contas em espera**.
4. Um campo "Nota" opcional permite registrar um contexto ("encontro de 12/05 na permanência, apresentada/o/e por Emma").
5. A conta passa a `status='active'`. A pessoa recebe um e-mail de boas-vindas.

### Importante politicamente

- A validação física de uma biblioteca **vale para toda a rede** das bibliotecas `network` (P7 matizado: a soberania local diz respeito às delegações internas, mas o reconhecimento mútuo é um pacto explícito).
- O que se "verifica" durante uma validação física **não** é um controle de identidade no sentido administrativo. É um encontro. Cada biblioteca define seu sentido político. Para algumas, é "trocamos um pouco para verificar que a pessoa não é policial ou fascista". Para outras, é "apresentamos a biblioteca, seu funcionamento, suas regras". Para outras ainda, é simplesmente "nos vemos pessoalmente para que a relação seja encarnada".
- Uma biblioteca pode **mudar de modo** a qualquer momento (`coordenador+`). A mudança não invalida as validações existentes.

## 5.6. O multi-membership, ponto de atenção

Uma particularidade técnica a compreender: uma pessoa pode ter **várias linhas** de membership na mesma biblioteca, com papéis diferentes. Por exemplo, Voltairine pode ser ao mesmo tempo `reader` e `librarian` da BLMF. Isso é possível pela restrição UNIQUE sobre o trio `(user_id, library_id, role)`.

**Por que essa possibilidade:** ela preserva o histórico. Se amanhã Voltairine se rebaixar de `librarian` a `reader`, sua linha `librarian` passa a `inactive` mas a linha `reader` permanece — sem precisar recriar uma nova inscrição do zero.

**Consequência prática:** na UI, exibe-se a pessoa **uma única vez**, com seu papel **de nível mais alto ativo** (administrador > coordenador > librarian > reader). No log de auditoria, por outro lado, vê-se cada linha separadamente.

## 5.7. Erros e salvaguardas

Alguns casos que se encontram regularmente:

**"O SIGB me diz que a pessoa já é librarian."** É provavelmente verdade. Verifique a aba **Equipe**: se a pessoa já aparece como librarian, você está tentando promovê-la ao mesmo nível; o SIGB retorna um sucesso silencioso (`{ok: true, no_change: true}`) porque não há nada a fazer.

**"Não vejo a pessoa na lista."** Três casos possíveis: (a) ela ainda não tem conta AnarBib (usar o workflow de convite por e-mail a vir); (b) ela tem uma conta mas não está inscrita em nenhuma biblioteca (ela deve se inscrever em sua biblioteca como `reader` primeiro); (c) ela está na rede mas filtrada pela busca — tentar com seu e-mail exato.

**"Cliquei por engano em Promover."** Sem pânico. Usar **"Solicitar saída"** para abrir um período de carência de 7 dias (cf. capítulo 6), ou pedir à pessoa que clique em **"Passo adiante"** (auto-rebaixamento imediato). Mencionar "erro de manipulação" no motivo.

**"A pessoa não recebe o e-mail."** Verificar primeiro a grafia de seu e-mail em seu perfil, e pedir que ela verifique sua pasta de spam. Se o problema persistir, falar com um(a/e) admin de rede: é provavelmente um problema de configuração de e-mail a investigar.

## 5.8. Se a regra lhe incomoda

Várias coisas podem não lhe convir neste capítulo:

- **O próprio princípio de cooptação** (P2). Você acha que toda pessoa `reader` engajada deveria poder passar livremente a `librarian` sem precisar de cooptação. É um debate político de fundo, que toca no princípio P1. A levar ao canal de coordenação de rede e provavelmente a discutir em encontro.

- **A ausência de doutrina definida sobre o "quando clicar"** (§5.4). Você acha que o guia deveria recomendar uma única doutrina. Ou ao contrário, você acha que ele sugere demasiado. Propor uma emenda a este capítulo, argumentando.

- **Os modos de validação física** (§5.5). Você acha que seria necessário um terceiro modo ("validação diferida", "validação à distância", outro). A levar para `spec-validation-physique.md`.

- **O multi-membership** (§5.6). Você acha que é desnecessariamente complexo e que deveria haver um único papel por pessoa por biblioteca. É uma decisão de modelo de dados, mais estruturante do que parece. A levar com as/os/es devs.

Ver capítulo 4 para o procedimento geral de emenda, e o anexo C para o modelo de nota.

\newpage

# 6. Passar o bastão, sair, suspender

Este capítulo abrange as transições T3 a T8 — ou seja, **tudo o que retira uma pessoa de uma equipe**, ou a coloca em pausa. Politicamente, é provavelmente o capítulo mais importante do guia, porque os mecanismos de retirada estão no cerne do projeto anarquista (cf. capítulo 1, §1.2).

## 6.1. Os princípios políticos

Três princípios estruturam este capítulo :

> **P3 — Rebaixamento voluntário sempre possível.** Toda pessoa com um papel staff pode se rebaixar a qualquer momento, sem consulta. "Passo o bastão" é um direito fundamental.

> **P4 — Exclusão enquadrada por um prazo de carência.** A exclusão não voluntária de um(a/e) librarian por um(a/e) coordenador(a/e) passa por um prazo de carência de sete dias antes de entrar em vigor. Esse prazo permite a deliberação coletiva e a eventual anulação por um(a/e) outro(a/e) coordenador(a/e).

> **P6 — Notificações sistemáticas.** Toda mudança de papel aciona um e-mail para a pessoa envolvida e para toda a coordenação.

A ideia de fundo é que nunca se retira alguém de uma equipe "de surpresa" ou "em silêncio". Ou a pessoa decide por si mesma (e é imediato), ou o coletivo pede (e é rastreado, notificado, e deliberável até o último momento).

## 6.2. Passar o bastão : auto-rebaixamento (T3 e T4)

Este é o **direito mais fundamental** no sistema de governança do AnarBib. Toda pessoa que exerce uma função staff pode, a qualquer momento, sem nenhuma consulta, deixá-la.

### Quando usar

- Você não tem mais tempo para exercer a função.
- Você não se reconhece mais nas decisões da coordenação.
- Você está em desacordo com uma decisão e quer se dessolidarizar dela.
- Você quer simplesmente fazer a função rodar.
- Você precisa de uma pausa.
- Não há razão a dar, na verdade. O direito de sair é incondicional.

### Procedimento

1. Ir em `/biblioteca`, aba **Equipe**.
2. Na **sua própria linha**, clicar **"Passo o bastão"**.
3. Escolher o nível de rebaixamento :
   - Se você é `coordenador`, pode escolher "voltar a ser librarian" (você permanece na equipe como librarian) ou "sair da equipe" (você volta a ser reader).
   - Se você é `librarian`, pode escolher "sair da equipe" (você volta a ser reader).
4. O modal lembra as consequências. Confirmar.

### Efeito imediato

- Sua membership atual (`librarian` ou `coordenador`) passa para `inactive`.
- Se você não tivesse ainda a membership alvo (`reader` ou `librarian`), ela é criada como `active`.
- E-mail para toda a coordenação + para você(a/e) mesmo(a/e) (confirmação).
- Log de auditoria : `action='self_demoted'`.

### Caso especial : você é o(a/e) único(a/e) coordenador(a/e) ativo(a/e)

O SIGB **deixa você sair**, mas te avisa :

> ⚠️ ATENÇÃO : você é o(a/e) único(a/e) coordenador(a/e) ativo(a/e) de [biblio]. A biblio ficará sem coordenação. Os(as/es) administradores(as/es) AnarBib serão notificados(as/es). Continuar ?

Se você confirmar :
- Sua membership coord passa para `inactive`.
- A biblio entra em **modo degradado** : os(as/es) `librarian` podem continuar gerindo os empréstimos, validar as inscrições, etc., mas nenhuma modificação da identidade pública ou da configuração é possível até a cooptação de um(a/e) novo(a/e) coord.
- E-mail para todos(as/es) os(as/es) admins da rede : "A biblio X não tem mais coordenador(a/e). Aqui estão os(as/es) librarians ativos(as/es) : ..."

Politicamente, isso é importante : o SIGB **não impede** sua saída. Mas ele informa a rede, para que um(a/e) admin da rede possa, se você desejar e se o coletivo local precisar, entrar em contato para ajudar a organizar a transição. É a rotação das funções em ação.

### Lado técnico

RPC : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

## 6.3. Pedir o afastamento de um(a/e) librarian (T5)

Quando o coletivo decide que uma pessoa deve sair da equipe, e essa pessoa não se rebaixa por conta própria, abre-se um **pedido de afastamento com carência de sete dias**.

### Pré-condições

- Você é `coordenador+` ativo(a/e) da biblio.
- A pessoa-alvo tem uma membership `librarian` ou `coordenador` `active`.
- Você não é a pessoa-alvo (caso contrário, usar §6.2).

### Procedimento

1. Ir em `/biblioteca`, aba **Equipe**.
2. Na linha da pessoa, clicar **"Pedir afastamento"**.
3. O modal que se abre é **vermelho e insistente**. Ele lembra :
   - O prazo de carência : "Este pedido entrará em vigor em [data J+7] salvo anulação por um(a/e) outro(a/e) coordenador(a/e)."
   - O caráter reversível : "Anulável por qualquer coord até a data de efeito."
   - O caráter colegial : "Todos(as/es) os(as/es) coords ativos(as/es) serão notificados(as/es)."
4. Um campo **"Razão"** é obrigatório — mínimo 20 caracteres. Nenhum afastamento silencioso. A razão pode ser política ("decisão da AG de 04/05") ou prática ("saída geográfica anunciada"). Ela será legível por todo(a/e) o staff no log de auditoria.
5. Confirmar.

### Efeito imediato

- A membership passa para `pending_removal`.
- Campo `pending_removal_until` = `now() + 7 days`.
- Campo `pending_removal_requested_by` = você.
- **Nenhum acesso** para a pessoa durante a carência (a membership fica congelada como `suspended`).
- E-mail para a pessoa envolvida : "A coordenação pediu seu afastamento da equipe [biblio] (aviso prévio até [data]). Esta decisão faz parte da vida orgânica do coletivo [biblio] ; para qualquer discussão, dirija-se à coordenação."
- E-mail para todos(as/es) os(as/es) coordenadores(as/es) ativos(as/es) : com seu nome e a razão.
- Log de auditoria : `action='removal_requested'` com seu `actor_user_id` e o campo `reason`.

### Efeito em J+7 (cron automático)

Se o pedido não tiver sido anulado nem contornado :
- A membership passa para `inactive`.
- E-mail final para a pessoa e para a coordenação : "Afastamento efetivo."
- Log de auditoria : `action='removal_completed'`.

### Lado técnico

RPC : `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron : `cron_team_pending_removal_complete` (executa diariamente).

## 6.4. Anular um pedido de afastamento (T8)

A **salvaguarda colegial** do sistema. Qualquer coord — não necessariamente aquele(a/e) que pediu — pode anular um pedido de afastamento durante o período de carência.

### Quando usar

- A discussão coletiva chegou a uma outra decisão (mediação, suspensão temporária no lugar, etc.).
- O pedido inicial foi feito no calor do momento e a coordenação quer retomar a questão colegialmente.
- A pessoa-alvo foi finalmente contatada e a situação foi desarmada.

### Procedimento

1. Ir em `/biblioteca`, aba **Equipe**, seção **Suspensões e avisos prévios em curso**.
2. Na linha da pessoa em `pending_removal`, clicar **"Anular o pedido"**.
3. Modal simples de confirmação. Campo "Razão" opcional.
4. Confirmar.

### Efeito imediato

- A membership volta para `active`.
- Campo `pending_removal_until` recolocado como NULL.
- E-mail para a pessoa : "O pedido de afastamento foi anulado. Você recupera suas prerrogativas."
- E-mail para toda a coordenação.
- Log de auditoria : `action='removal_cancelled'` com seu `actor_user_id`.

### Politicamente

A anulação é deliberadamente muito simples de ativar. É um mecanismo de **reequilíbrio colegial** : se um(a/e) coord pediu um afastamento no calor do momento, qualquer outro(a/e) coord pode suspender a execução enquanto o coletivo delibera. Isso torna os pedidos de afastamento menos pesados (nenhum drama irreversível) mas também menos leves (qualquer pessoa pode contradizê-lo). É o interesse da carência.

### Lado técnico

RPC : `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Suspensão imediata : a medida cautelar (T6 e T7)

A suspensão é uma ferramenta **diferente** do pedido de afastamento. Ela é **imediata**, sem carência, e **sem duração máxima**. Não é uma exclusão, é uma **colocação em pausa**.

### Quando usar

Casos típicos previstos pela spec :

- **Conta comprometida** : há razões para acreditar que a senha da pessoa vazou. Suspende-se enquanto aguarda que ela troque sua senha.
- **Assédio sinalizado urgente** : um(a/e) leitor(a/e) sinaliza um comportamento abusivo de um(a/e) membro staff. Suspende-se enquanto aguarda a investigação coletiva.
- **Comportamento manifestamente abusivo** observado diretamente : suspende-se enquanto a coordenação se reúne.
- **Conflito em mediação** : a pessoa é colocada em pausa voluntariamente enquanto a mediação é concluída.

### Procedimento

1. Ir em `/biblioteca`, aba **Equipe**.
2. Na linha da pessoa, clicar **"Suspender"**.
3. Modal com um campo **"Razão da suspensão" obrigatório** (mínimo 20 caracteres). Esta razão será legível no log de auditoria por todo(a/e) o staff ativo.
4. Confirmar.

### Efeito imediato

- A membership passa para `suspended`.
- **Nenhum acesso** para a pessoa. O papel nominal é mantido (ela continua sendo exibida como "librarian suspenso(a/e)") mas ela não pode mais fazer nada.
- E-mail para a pessoa envolvida : urgente, com a razão, e — no caso de uma conta comprometida — um convite para trocar sua senha.
- E-mail para toda a coordenação.
- Log de auditoria : `action='suspended'` com seu `actor_user_id` e o campo `reason`.

### Levantamento da suspensão

Quando a situação estiver resolvida (conta rebloqueada, mediação concluída, investigação encerrada, etc.) :

1. Aba **Equipe** → seção **Suspensões e avisos prévios em curso**.
2. Na linha suspensa, clicar **"Levantar a suspensão"**.
3. Modal simples. Campo razão opcional mas recomendado para encerrar politicamente o episódio.
4. Confirmar.

Efeito : retorno a `active`, e-mails, log de auditoria `action='unsuspended'`.

### Importante : suspensão vs afastamento

A distinção é crucial :

| | Suspensão (T6) | Afastamento (T5) |
|---|---|---|
| Efeito | Imediato | Diferido (J+7) |
| Duração | Indefinida | 7 dias e então `inactive` |
| Reversível por | Levantamento explícito | Anulação durante a carência |
| Uso típico | Medida cautelar | Decisão de exclusão |
| Política subjacente | "Nos damos tempo para entender" | "Decidimos que essa pessoa sai" |

O SIGB **recusa** fazer uma membership passar de `suspended` diretamente para `pending_removal` (a transição não é autorizada pela matriz). Por quê : são duas temporalidades políticas distintas. Para passar de uma para outra, é preciso explicitamente **levantar a suspensão** primeiro (retorno a `active`), depois pedir o afastamento (`pending_removal`). Esta dupla etapa é intencional : ela obriga o coletivo a reconhecer explicitamente a transição.

### Lado técnico

RPC suspender : `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC levantar : `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Rebaixar um(a/e) outro(a/e) `coordenador` (T3 coletivo)

Um caso um pouco particular : o que fazer quando a coordenação quer **rebaixar um(a/e) coordenador(a/e)** que não se rebaixa espontaneamente ?

A spec de governança trata este caso como um **pedido de afastamento com carência** visando a membership `coordenador`. Concretamente, você usa o mesmo procedimento do §6.3 ("Pedir o afastamento"), mas selecionando o papel `coordenador`. A pessoa passa para `pending_removal` em sua membership `coordenador` ; em J+7, essa membership passa para `inactive`. Se ela tiver uma membership `librarian` paralela, esta permanece ativa (e a pessoa "cai de volta" como librarian). Caso contrário, ela volta a ser simples `reader`.

É intencionalmente o mesmo mecanismo que para os(as/es) `librarian`, com as mesmas salvaguardas. **Nenhum(a/e) outro(a/e) coord tem um poder especial** sobre suas colegas : o procedimento passa pela carência e pela colegialidade.

## 6.7. Conta abandonada : saída automática (T9)

O SIGB inclui um mecanismo de **saída automática** para contas que não tiveram conexão há muito tempo.

### O limite

O SIGB observa o campo `last_sign_in_at` no lado Supabase. Se uma membership staff tem um(a/e) usuário(a/e) cuja última conexão remonta a mais de **9 meses**, a conta é progressivamente retirada :

- **J-30 dias** (8 meses após a última conexão) : e-mail de aviso para a pessoa ("sua membership será desativada em 30 dias sem conexão").
- **J-7 dias** : e-mail de lembrete.
- **J = 9 meses** : passagem automática para `inactive`. E-mail final para a pessoa + para toda a coordenação.

### Por que esta regra

É um compromisso entre duas exigências :

- Não deixar **arrastar indefinidamente** memberships fantasmas que incham artificialmente as equipes.
- Não **expulsar** brutalmente uma pessoa que simplesmente teria tirado uma pausa e pretende voltar.

Uma simples conexão basta para reiniciar o contador. Não é preciso realizar nenhuma ação, apenas se conectar.

### Caso especial : o(a/e) único(a/e) coord abandona

Se a pessoa retirada automaticamente for o(a/e) **único(a/e) coordenador(a/e) ativo(a/e)** da biblio, o cron escala para um(a/e) admin da rede **antes** de executar a saída. O(A/E) admin da rede é notificado(a/e) por e-mail, pode entrar em contato com a coordenação (se ainda restar algum fragmento) ou com os(as/es) `librarian` da biblio, e coordenar a transição.

Politicamente, isso é coerente com o que se faz quando o(a/e) único(a/e) coord se rebaixa explicitamente (§6.2) : não se bloqueia a saída, mas alerta-se a rede para que ela possa ajudar se necessário.

## 6.8. Alguns casos-limite a conhecer

**Uma pessoa em `pending_removal` que pede para sair imediatamente.** Ela pode. Basta usar por conta própria "Passo o bastão" (auto-rebaixamento T4). Efeito : passagem imediata para `inactive`, contornando a carência. Politicamente, é coerente : o direito P3 (auto-rebaixamento) é incondicional.

**Uma pessoa em `suspended` que se quer excluir definitivamente.** Ver §6.5 "Importante : suspensão vs afastamento". É preciso levantar a suspensão primeiro, depois pedir o afastamento.

**Alguém pede seu próprio afastamento via "Pedir afastamento".** O SIGB recusa com uma mensagem explícita : "Para sair da equipe, use a opção 'Passo o bastão' (auto-rebaixamento)." É intencional : confundir uma decisão pessoal com uma decisão coletiva embaralharia a semântica política.

**Tentativa de rebaixar um(a/e) admin da rede.** Recusada sistematicamente. O papel de admin da rede só pode ser modificado via os mecanismos específicos da spec admin-reseau (cf. capítulo 8). Nenhum(a/e) coord local pode destituir um(a/e) admin da rede.

## 6.9. Se a regra te incomoda

**O prazo de carência de 7 dias te parece longo demais ou curto demais.** A levar para `spec-gouvernance-roles.md`, §4.4 e §5.6.

**Você acha que a suspensão sem duração máxima é uma porta aberta para o arbítrio.** É um assunto político sério. Pode-se pensar em adicionar um prazo além do qual uma suspensão deve ser convertida em afastamento ou levantada. A discutir na coordenação da rede, depois a levar para a spec.

**Você acha que a obrigação de razão na suspensão é um excesso de burocracia.** Ou, ao contrário, você acha que o mínimo de 20 caracteres é curto demais. A levar para a spec.

**Você acha que a saída automática aos 9 meses é rápida demais ou lenta demais.** O limite é parametrizável, mas hoje é o mesmo para todas as biblios da rede. Deve-se torná-lo configurável por biblio ? A discutir.

Ver capítulo 4 e anexo C para o procedimento de emenda.

\newpage

# 7. Quando algo vai mal

Este capítulo trata das **situações excepcionais**, onde os mecanismos ordinários de governança não são suficientes, ou funcionam mas exigem discernimento político. É também o capítulo em que se fala com franqueza das **bibliotecas que não têm (ou não têm mais) vida coletiva deliberativa**, porque o silêncio sobre esse assunto faria mais mal do que a franqueza.

## 7.1. Biblioteca sem AG ou com poucas pessoas membras

O caso é mais frequente do que parece. Uma biblioteca em fase inicial, com duas ou três pessoas. Uma biblioteca que viu seu coletivo reduzir-se com o passar do tempo. Uma biblioteca cuja AG não se reúne há algum tempo, por falta de gente ou por desânimo.

O SIGB não se envolve na vida política de um coletivo. Mas este guia precisa dizer com franqueza o que muda quando essa vida coletiva é fraca.

### O que muda concretamente

**A palavra "cooptação" torna-se ambígua.** Com duas pessoas, quem copta quem? Se a única coord deseja trazer Voltairine para a equipe, ela decide "sozinha/sozinho/sozinhe" no sentido político do termo. O SIGB vai permitir isso (uma coord+ pode cooptar), mas isso não é mais a cooperação de um coletivo político, é uma decisão pessoal disfarçada. Não é nem bom nem ruim, é simplesmente algo a reconhecer.

**As deliberações são teóricas.** Um pedido de retirada de 7 dias, em uma biblioteca com 2 pessoas, não tem ninguém mais para contestá-lo além de quem o pediu. A "salvaguarda colegial" torna-se uma autorreflexão.

**O risco de personalização aumenta.** Quando uma decisão não é mais coletiva, ela depende do caráter, da disponibilidade e da lucidez de uma ou duas pessoas. Isso não é catastrófico em si, mas é mais frágil.

### Nossas recomendações explícitas

**1. Reconheça a situação.** Não finja ser um grande coletivo deliberativo se vocês são dois. Politicamente, é mais saudável escrever "decisão tomada por mim sozinha/sozinho/sozinhe, a validar quando o coletivo crescer" no campo "Razão" do audit log, do que escrever "decisão AG" em uma AG que não existe.

**2. Busque diálogo com pessoas de fora.** Se você está sozinha/sozinho/sozinhe ou em duas pessoas, e uma decisão importante precisa ser tomada (cooptação, retirada, suspensão), crie o hábito de conversar com camaradas de outras bibliotecas da rede, ou com uma pessoa admin da rede. Não para pedir autorização — elas não precisam validar as decisões internas da sua biblioteca — mas para obter um retorno crítico externo. A rede Matrix do AnarBib existe para isso.

**3. Prefira as transições reversíveis.** Quando seu coletivo é pequeno, evite se possível as decisões irreversíveis. Uma suspensão é mais reversível do que uma retirada. Uma retirada passa por 7 dias durante os quais você pode mudar de ideia. Uma cooptação pode ser anulada. Dê tempo a si mesma/mesmo/mesme.

**4. Documente o que acontece.** O campo "Razão" do audit log é seu melhor amigo. Quanto mais contexto você colocar nele ("cooptação de Voltairine, decidida sozinha/sozinho/sozinhe, a validar na próxima reunião"), mais a decisão será contextualizável depois, por você mesma/mesmo/mesme e por uma nova pessoa membra do coletivo.

**5. Se você está realmente isolada/isolado/isolade, peça ajuda.** Uma biblioteca com uma única pessoa está em perigo politicamente. O SIGB detecta isso no momento em que a última coord se autorebaixa (§6.2) ou abandona (§6.7), e alerta as pessoas admins da rede. Você também pode tomar a iniciativa: envie um e-mail para a coordenação da rede explicando a situação. Várias bibliotecas da rede passaram por momentos difíceis e foram ajudadas a se reconstituir.

### O que o guia não faz

Ele **não** fornece um procedimento especial para bibliotecas pequenas. Isso é intencional. As regras do SIGB se aplicam uniformemente — o que muda são as condições políticas em que elas se aplicam. Reconhecer essa nuance faz parte da maturidade política de uma coord.

## 7.2. Conflito interpessoal numa coordenação

Um conflito explode entre duas pessoas membras do staff. O trabalho não está sendo feito corretamente, o clima se deteriora, leitoras/leitores/leitores percebem a tensão.

### O que o SIGB pode fazer

Pouca coisa, diretamente. O SIGB não arbitra conflitos. Mas fornece **ferramentas utilizáveis**:

- **Suspensão provisória (T6)** de uma ou das duas pessoas, enquanto o conflito é mediado. É o que a spec chama explicitamente de "conflito em processo de mediação" como caso de uso legítimo da suspensão.
- **Auto-rebaixamento (T3/T4)** — se uma das duas pessoas escolhe se afastar, é imediato.
- **Audit log legível por todo o staff** — permite que todo o staff veja quem fez o quê, e evita manipulações opacas de uma coord que tentasse resolver o conflito retirando a outra pessoa discretamente.

### O que o coletivo deve fazer

- **Mediação**. O SIGB não faz mediação. É preciso uma pessoa de confiança, de fora do conflito. Dependendo das configurações: outra coord da biblioteca, uma camarada de outra biblioteca, uma pessoa admin da rede.
- **Decisão coletiva**. Se a mediação resulta em uma decisão (uma das duas pessoas sai da coordenação, ou se define um novo quadro de trabalho), o SIGB executará essa decisão via as RPCs normais.
- **Rastro político**. Se a decisão for retirar alguém, o campo "Razão" deveria mencionar o processo de mediação ("retirada após mediação de DD/MM, decisão coletiva") para não reescrever a história mais tarde.

### O que evitar

- **Usar uma suspensão como arma** no conflito. A suspensão é feita para colocar em pausa, não para ganhar uma disputa de poder. Se uma coord suspende a outra sem processo de mediação, isso é observável no audit log, e é politicamente problemático.
- **Contornar a carência** por manobras técnicas (suspender e depois "acelerar" por outros meios). Tudo é rastreado, e a rede vai perceber.
- **Silenciar o audit log**. Todo o staff vê o que acontece (P5). Se você tenta esconder o conflito, está traindo a transparência do coletivo.

## 7.3. Assédio denunciado

Uma leitora/um leitor/uma pessoa leitora denuncia que uma pessoa membra do staff tem um comportamento abusivo (assédio sexual, abuso de poder, comportamento racista, etc.).

### Procedimento recomendado

**1. Levar a denúncia a sério**, imediatamente, mesmo que a pessoa denunciante esteja isolada e mesmo que a pessoa denunciada seja "conhecida e estimada" pela coordenação. O reflexo de descartar a denúncia como "provavelmente exagerada" é o erro mais comum.

**2. Suspensão imediata (T6)** da pessoa denunciada, **a título cautelar**, enquanto aguarda a investigação. O campo "Razão" deveria dizer algo como "Suspensão cautelar após denúncia recebida em DD/MM, aguardando investigação coletiva". A suspensão **não** é uma acusação, é uma pausa.

**3. Constituir um grupo de investigação**. Fora do software. No mínimo: camaradas fora da relação de poder direta, capazes de ouvir os dois lados sem viés. Esse grupo pode incluir camaradas de outras bibliotecas se a biblioteca for pequena ou se todas as coords estiverem envolvidas no caso.

**4. Comunicar com a pessoa denunciante**. Ela precisa saber que a denúncia foi levada a sério e que medidas estão em andamento. Não a deixar na incerteza.

**5. Chegar a uma decisão**. Dependendo do que a investigação revelar:
   - Levantamento da suspensão (T7) se a denúncia não for confirmada.
   - Retirada definitiva (T5 com carência) se a denúncia for confirmada e a decisão for excluir a pessoa.
   - Sanção intermediária (novo quadro de trabalho, formação, afastamento de certas funções) se a situação for mais matizada.

**6. Registrar politicamente**. O campo "Razão" no audit log deveria refletir a decisão coletiva. Sem detalhes sobre a vítima (LGPD), mas uma formulação que torne a decisão legível.

### O que não fazer

- **Pedir uma retirada diretamente** sem suspensão prévia, quando a situação é urgente. Durante 7 dias a pessoa denunciada conservaria seus direitos, o que contradiz a urgência de uma denúncia de abuso.
- **Suspender indefinidamente sem decisão** sob o pretexto de "não conseguimos decidir". Uma suspensão que dura vários meses sem decisão torna-se ela própria uma violência (contra a pessoa suspensa, que não pode se defender, e contra a pessoa denunciante, que não recebe resposta).
- **Resolver internamente sem a rede**. Se você é uma biblioteca pequena e a situação está além da sua capacidade, peça ajuda às pessoas admins da rede. Você não está sozinha/sozinho/sozinhe.

## 7.4. Conta comprometida

Uma pessoa membra do staff vê sua conta comprometida (senha vazada, suspeita de acesso não autorizado).

### Procedimento imediato

**1. Suspensão imediata (T6)** da conta, com razão explícita: "Suspeita de comprometimento, senha provavelmente vazada, verificação em andamento".

**2. Comunicação com a pessoa em questão**. A pessoa recebe automaticamente um e-mail urgente indicando a suspensão e pedindo que mude sua senha. A coord que suspende também deveria entrar em contato diretamente (telefone, outro canal seguro) para confirmar.

**3. Investigação rápida.** O que aconteceu? A conta realizou ações incomuns no audit log (cooptações estranhas, modificações de configuração, etc.)? Se sim, avisar imediatamente uma pessoa admin da rede para ajudar a analisar.

**4. Levantamento da suspensão (T7)** uma vez que:
   - A senha for trocada.
   - O eventual dano for constatado e reparado (anulação das ações abusivas, restauração dos dados, etc.).
   - A pessoa estiver segura digitalmente.

### Politicamente

Uma suspensão por conta comprometida **não é uma punição**. É uma proteção mútua: protegemos a pessoa (impedindo que ela seja usada por uma pessoa atacante) e a biblioteca (impedindo que danos sejam feitos em seu nome). O e-mail à pessoa deveria enfatizar esse caráter **não disciplinar**.

## 7.5. Biblioteca sem coord nem librarian ativas/ativos/atives

O cenário catastrófico: nenhuma pessoa do staff ativa/ativo/ative. Isso pode acontecer por saída automática acumulada (todas as pessoas do staff abandonaram suas contas simultaneamente), por demissão coletiva (rara mas possível), ou por sucessão de retiradas.

### Consequências

- A biblioteca permanece **tecnicamente ativa** (sua visibilidade, seu catálogo continuam acessíveis segundo as RLS habituais).
- Mas **nenhuma ação de gestão** pode mais ser feita via a UI normal: sem validação de inscrição, sem gestão de empréstimo, sem modificação de configuração.
- **E-mail urgente às pessoas admins da rede** pelo cron que detecta a situação.

### Procedimento de reinicialização

Fora da spec, mas é o que se pratica:

**1. Contato** por uma pessoa admin da rede com o coletivo local, por todos os canais disponíveis (as contas leitoras/leitores que ainda estão inscritoras/inscritos, os contatos externos da biblioteca se existirem, a rede de conhecidos local).

**2. Verificação política**: o coletivo ainda existe? Quer continuar a existir? Se há pessoas membras mas que simplesmente deixaram cair as funções técnicas, pode-se recrutar novo staff por cooptação fora do fluxo de trabalho.

**3. Cooptação fora do fluxo de trabalho** pela pessoa admin da rede, via SQL direto ou via a UI (uma pessoa admin da rede tem o direito de agir como coord+ em qualquer biblioteca, cf. capítulo 2). A cooptação fora do fluxo de trabalho deve ser registrada no audit log com uma razão explícita: "Retomada de coordenação após vacância, após contato com o coletivo em DD/MM, pela pessoa admin da rede X". E — ponto-chave de doutrina — **informação prévia à coordenação local obrigatória**, salvo se a biblioteca não tiver mais nenhuma pessoa membra do staff ativa/ativo/ative, caso em que a informação passa pelas pessoas `reader` ativas/ativos/atives restantes (cf. §7.6).

**4. Se o coletivo não existe mais**: abertura de uma discussão sobre o **encerramento adequado** da biblioteca. Quais dados conservar, quais excluir, como comunicar às leitoras/leitores, etc. Isso é um fluxo de trabalho a formalizar separadamente.

## 7.6. A intervenção de uma pessoa admin da rede numa biblioteca local

Um caso que já aparece no capítulo 2, mas que merece um desenvolvimento prático neste capítulo das situações excepcionais.

### A doutrina da rede

> **Uma intervenção de pessoa admin da rede numa biblioteca local deve ser precedida de uma informação à coordenação local concernida, salvo urgência vital.**

A informação prévia **não é um pedido de autorização**. A pessoa admin da rede tem o direito de agir (é o sentido do direito transversal). Mas é uma marca de respeito pela autonomia local, e preserva a possibilidade de outro arranjo.

### O que é uma "urgência vital"

Isso é deliberadamente restritivo. Casos-tipo:

- **Comprometimento ativo**: uma ação em curso ameaça a integridade da biblioteca ou da rede (conta atacante que modifica memberships em tempo real, etc.).
- **Assédio em curso**: uma pessoa membra do staff está abusando ativamente de suas funções, o perigo para as leitoras/leitores é imediato.
- **Ataque contra a plataforma**: tentativa de intrusão, exfiltração de dados, etc.

Fora desses casos, **toma-se o tempo de informar**.

### Como informar

Antes da intervenção (ou durante, se a urgência o justificar a posteriori):

- **E-mail à coordenação local** explicando o que vai ser feito, por quê, e com qual rastreabilidade.
- **Menção na tabela `cross_library_actions_log`** com um nível de criticidade indicando a natureza da ação. Todas as coords ativas/ativos/atives da biblioteca recebem uma notificação.
- **Disponibilidade para o diálogo**: a coordenação local deve poder fazer perguntas, pedir esclarecimentos, ou até negociar outro arranjo ("deixa a gente tentar primeiro").

### O que evitar

- **A intervenção silenciosa**: agir na biblioteca sem informar a coordenação. Mesmo que tecnicamente seja rastreado, politicamente é uma violação da soberania local.
- **O uso do direito transversal como poder de vigilância**: ir ver "o que está acontecendo" numa biblioteca sem razão operacional. O direito transversal existe para casos de manutenção ou mediação, não por curiosidade.
- **A imposição de decisões políticas**: uma pessoa admin da rede não pode dizer a uma biblioteca como fazer suas cooptações, como gerir seus conflitos internos, ou qual política de acolhimento escolher. O direito transversal é técnico, não político.

## 7.7. Se a regra te incomoda

**Você acha que a doutrina de informação prévia é muito frouxa** (uma pessoa admin da rede poderia abusar da "urgência vital"). A discutir: é preciso uma definição mais estrita da urgência? É preciso uma segunda pessoa admin da rede que confirme a urgência?

**Você acha a doutrina muito estrita** (às vezes é preciso agir rápido sem explicar tudo). A discutir: é preciso distinguir vários níveis de intervenção, com regras de informação diferentes segundo a criticidade?

**Você acha que o silêncio sobre o encerramento adequado de uma biblioteca é problemático** (§7.5). Você tem razão. Uma spec dedicada provavelmente precisa ser escrita. A levar à rede.

**Você acha que este capítulo deixa muito espaço para a improvisação** nos casos de assédio (§7.3). Provavelmente é verdade. Uma spec dedicada sobre os processos de mediação e investigação poderia ser benéfica. A levar à rede.

Ver capítulo 4 e anexo C.

\newpage

# 8. O papel de administrador·a·e de rede

Este capítulo se dirige especificamente às administradoras·es de rede (presentes ou futuras·os), e às coordenações locais que querem entender como a rede se auto-organiza no nível superior. Ele complementa e aprofunda os capítulos 2 e 7.

## 8.1. Uma função política distinta

Antes de tudo: ser **admin de rede** não é um grau, nem uma consagração, nem um título. É uma **função transversal** que o coletivo das admins de rede delega a determinadas pessoas, com base em acordo unânime das admins já em exercício, e que pode ser deixada a qualquer momento.

O projeto político da função é **fazer viver a coordenação inter-biblios**: acolher as novas biblios que se juntam à rede, animar as discussões sobre as evoluções técnicas e políticas do SIGB, manter a plataforma tecnicamente, intervir quando uma biblio se encontra em bloqueio. Não é uma função de direção. É uma função de animação e de serviço.

### O que uma admin de rede pode fazer (politicamente)

- Ativar uma nova biblio que fez seu pedido de inscrição na rede.
- Animar as discussões inter-biblios (o canal Matrix `#anarbib`, os encontros, as listas de e-mails internas).
- Coordenar as evoluções da plataforma (specs, releases, comunicações).
- Intervir em qualquer biblio em caso de bloqueio técnico (direito transversal).
- Mediar entre duas biblios em caso de conflito (se as coordenações assim desejarem).
- Propor ou votar sobre a cooptação e a retirada coletiva de outras admins de rede.

### O que uma admin de rede não pode fazer (politicamente)

- Dirigir uma biblio.
- Impor uma decisão política a uma biblio (política de acolhimento, modo de validação, cooptações internas, etc.).
- Afastar uma pessoa coordenadora local contra a vontade de sua biblio.
- Modificar sozinha as regras da rede (isso passa por uma discussão coletiva das admins e idealmente das coordenações).

## 8.2. A cooptação por unanimidade: por quê

A admin de rede não é adicionada pela maioria, mas pela **unanimidade** das admins em exercício. Essa regra pode surpreender — por que não maioria simples, maioria qualificada, ou quórum?

A razão política é simples: o poder de uma admin de rede é **transversal**. Ela pode intervir em qualquer biblio. É preciso, portanto, que **cada admin de rede atualmente ativa** esteja pronta a trabalhar com a nova pessoa. Se houver um único desacordo profundo, a cooperação ficará envenenada — melhor não impô-la.

Essa regra tem uma consequência prática importante: **o veto é fácil**. Um único voto `opposed` é suficiente. É proposital. Prefere-se que uma cooptação não se concretize a deixar uma admin existente em situação de constrangimento duradouro.

## 8.3. Workflow de cooptação, em detalhe

### Etapa 1 — Proposta

Uma admin de rede ativa, a partir da interface `/rede/administradores` (a ser implementada no pacote D), clica em **« Propor uma cooptação »**.

- Insere a identidade da pessoa proposta (busca na base de usuárias·os do AnarBib).
- Insere uma **motivação** obrigatória de **mínimo 20 caracteres**. Essa motivação é legível por todas as admins, e — em caso de sucesso — será incluída na notificação à pessoa cooptada.
- Confirma.

O SIGB:
- Cria uma linha em `network_administrator_cooptation_proposals` com `status='open'`, `expires_at = now() + 30 dias`.
- Registra automaticamente o voto `favorable` da pessoa proponente.
- Envia um e-mail militante a todas as outras admins ativas convidando-as a votar.

### Etapa 2 — Votos

Cada outra admin ativa tem 30 dias para votar. Três opções:

- **`favorable`**: ela aceita a cooptação.
- **`opposed`**: ela coloca seu veto. **Rationale obrigatória** de mínimo 20 caracteres. Essa rationale será comunicada à pessoa proposta e à pessoa proponente em caso de rejeição.
- **`abstain`**: ela se abstém. **A abstenção bloqueia**: a proposta só prospera com unanimidade de votos `favorable`. Uma abstenção não retirada tem o mesmo efeito prático que um veto, exceto que pode ser convertida em favorável mais tarde se a pessoa mudar de posição.

### Detalhe v0.3 — Divulgação de identidade

Uma opção **« Revelar minha identidade em caso de rejeição »** vem marcada por padrão. Se você votar `opposed`, sua identidade será comunicada à pessoa proposta e à pessoa proponente, além de sua rationale.

Você pode **desmarcar** essa opção para permanecer anônima·o. Nesse caso, a rationale será transmitida sem seu nome (« uma pessoa opositora levantou: ... »).

Politicamente, a **transparência por padrão** corresponde à cultura militante de assunção das posições. Mas o anonimato permanece possível para os casos em que uma oposição exporia a pessoa opositora a um custo pessoal desproporcional.

### Lembretes automáticos

O cron envia lembretes às admins que ainda não votaram:
- **D+14 dias**: « Você ainda não votou sobre a cooptação de X. »
- **D+25 dias**: « Esta proposta expira em 5 dias, posicione-se. »

### Etapa 3 — Conclusão

**Se alguém votar `opposed`**: a proposta passa imediatamente a `status='rejected'`. A pessoa proposta e a pessoa proponente recebem um e-mail explicando a rejeição, com a rationale (e a identidade da pessoa opositora se ela aceitou a divulgação).

**Se todas as admins ativas votarem `favorable`**: a proposta passa a `status='completed'`. Uma linha é inserida automaticamente em `network_administrators` com `status='active'` e `coopted_by_unanimity_of = ARRAY[<lista das votantes>]`. A pessoa recebe um e-mail de boas-vindas e um resumo é enviado a todas as admins.

**Se 30 dias se passarem sem que se chegue a um consenso**: a proposta passa a `status='expired'`. Sem cooptação. É preciso ou recomeçar uma nova proposta, ou considerar que a rede não está pronta para acolher essa pessoa no momento.

## 8.4. A retirada coletiva por unanimidade

A **retirada coletiva** é o espelho da cooptação: para retirar uma admin de rede contra sua vontade, é preciso unanimidade das outras admins ativas.

### Workflow

1. **Proposta de retirada** por uma admin de rede ativa, motivação obrigatória ≥ 20 caracteres.
2. **Votos** das outras admins (favorable / opposed / abstain), com rationales se `opposed`.
3. **Se unanimidade `favorable`**: a membership da pessoa visada passa a `pending_removal`, com `pending_collective_removal_until = now() + 7 dias`.
4. **Durante os 7 dias de carência**: a pessoa visada mantém seus direitos operacionais, mas recebe um e-mail claro sobre sua saída programada. Ela pode eventualmente engajar uma última discussão. **Ela não pode cancelar a retirada unilateralmente**: somente a unanimidade das outras admins pode recuar (propondo uma « anulação de retirada », workflow espelho).
5. **Em D+7**: passagem a `status='removed'`, `removed_at=now()`.

### Politicamente

O **duplo travamento** (unanimidade + carência 7d) torna a retirada coletiva de uma admin de rede particularmente difícil. É proposital. O poder de uma admin de rede sendo transversal, não se o revoga levianamente.

Inversamente, **a auto-retirada permanece sempre possível e fácil** (cf. §8.5). É aí a dissimetria política: é simples partir, é difícil ser afastada·o. Isso corresponde à cultura anarquista: respeita-se a decisão pessoal de deixar uma função, enquadra-se fortemente a decisão coletiva de retirá-la.

## 8.5. Auto-retirada

Uma admin de rede pode deixar suas funções a qualquer momento, sem o acordo das outras. É um ato **unilateral e incondicional** (P3 aplicado ao nível de rede).

### Procedimento

A partir de `/rede/administradores`, em sua própria linha, clicar em **« Deixar minhas funções de admin de rede »**. Modal de confirmação, razão opcional.

### Efeito

- A linha passa a `status='inactive'` (ou `removed` conforme o contexto, a esclarecer no pacote D).
- E-mail a todas as outras admins ativas.
- Audit log `event_type='self_removal_requested'`.

### Caso especial: a única admin ativa

Se você for a única admin ativa e quiser partir, o SIGB desencadeia uma **carência especial de 30 dias**. Durante esse período:
- Você permanece admin ativa com todos os seus direitos.
- Um e-mail urgente é enviado a todas as antigas admins (`status='inactive'` ou `removed`) indicando a situação.
- A rede tem 30 dias para ou recooptar uma nova admin (workflow normal de cooptação, sendo você a única votante), ou organizar uma transição diferente.

Em D+30, se nada tiver sido feito, você sai efetivamente e a rede se encontra **sem admin ativa**. O SIGB continua a funcionar tecnicamente, mas nenhuma ação de admin (ativação de biblio, cooptação, etc.) é mais possível até intervenção manual.

Esse procedimento foi concebido para **desacelerar** a dissolução da rede caso a última admin parta, sem no entanto **impedir** essa partida. A liberdade de partir permanece inteira.

## 8.6. O direito transversal no cotidiano

O **direito transversal** é o que distingue politicamente a admin de rede do staff local: ela pode agir como `coord+` em qualquer biblio, ler seu catálogo (mesmo se visibilidade `private`), modificar suas memberships, etc.

### Quando usá-lo

- **Ativação de uma nova biblio**: workflow normal, é o caso de uso primeiro do direito transversal.
- **Manutenção**: uma biblio tem uma configuração quebrada, um parâmetro mal ajustado, um bug bloqueante. Você pode intervir para corrigir.
- **Bloqueio político**: a biblio não tem mais coord (cf. §7.5), é preciso recooptar para reiniciar.
- **Mediação a pedido**: a coordenação local solicita explicitamente sua ajuda para arbitrar um conflito ou tomar uma decisão difícil.
- **Investigação após um relato de rede**: uma pessoa leitora relata um problema grave em uma biblio, e a coordenação local não responde ou é ela mesma parte do problema.

### Quando não usá-lo

- **Por curiosidade**: não ir « ver o que acontece » em uma biblio sem razão operacional. Isso é vigilância, não administração.
- **Para impor uma decisão política**: se você não concorda com a política de uma biblio (modo de validação, regulamento, etc.), você pode discutir, mas não impor.
- **Para curto-circuitar um debate coletivo**: se a rede discute uma evolução e você não concorda, você não pode usar seu direito transversal para impor sua visão por fato consumado.

### Informação prévia obrigatória

É a doutrina da rede (capítulo 2, §2.4; capítulo 7, §7.6): **toda intervenção de admin de rede em uma biblio local deve ser precedida de uma informação à coordenação local**, salvo em caso de urgência vital.

Concretamente:
- **E-mail à coordenação local** explicando o que será feito e por quê.
- **Aguardo de uma resposta** salvo urgência: 24 a 72 horas conforme a natureza da ação.
- **Se sem resposta e ação não urgente**: retomar uma vez, e proceder explicitando no log que a coordenação local foi informada mas não respondeu.
- **Se urgência vital**: agir, e enviar a informação imediatamente depois explicando por que a urgência justificou a ação sem espera.

Cada ação é rastreada em `cross_library_actions_log` com nível de criticidade, legível pela coordenação local a posteriori.

## 8.7. O caso da primeira admin e de Xavier

O sistema pressupõe ao menos uma admin de rede ativa para que a cooptação seja possível. A **primeira admin** não podendo ser cooptada (não há ninguém para votar), uma exceção está prevista.

Em 11 de maio de 2026, **Xavier** está inscrita·o como **admin de rede fundadora·or** por INSERT direto em `network_administrators`, com `coopted_by_unanimity_of = ARRAY[]::uuid[]` (array vazio) e `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. Essa manipulação está rastreada no audit log com `event_type='foundational_admin_added'` e `metadata.foundational=true`.

Essa manipulação é **transparente politicamente**: está documentada, explicada e é pública. Não é uma fraqueza do sistema — é o amor necessário para iniciar. Uma vez esse alicerce posto, toda cooptação ulterior passa pelo workflow normal do §8.3.

À medida que novas admins forem cooptadas, a « solidão » inicial se apagará. A rede tem vocação de ter **várias admins ativas** (o objetivo político é geralmente um círculo de 3 a 5 pessoas, em número ímpar para evitar bloqueios em caso de voto sobre certos temas conexos fora da spec).

## 8.8. Se a regra lhe incomoda

**Você acha a unanimidade muito exigente** (« a gente nunca consegue cooptar, um veto bloqueia tudo »). É um debate de fundo sobre a natureza do coletivo das admins de rede. Deve-se flexibilizar para maioria qualificada? Deve-se ter um mecanismo de supervoto? A levar para discussão de rede, e possivelmente a formalizar em uma revisão da spec.

**Você acha a unanimidade muito laxa** (« seria preciso também consultar as coordenações locais antes de cooptar uma admin »). É outra opção política: consultar as coordenações locais antes da cooptação de uma admin de rede. A discutir. Isso ampliaria o círculo decisor, mas alargaria o procedimento.

**Você acha a carência de 7d para a retirada coletiva muito longa ou muito curta.** A levar para a spec.

**Você acha que a doutrina de informação prévia está insuficientemente enquadrada**: o que é exatamente uma « urgência vital »? Deve haver uma definição canônica? A discutir.

**Você acha que a função de admin de rede tem poder demais** (direito transversal muito amplo) ou de menos (deveria poder resolver certos conflitos). É uma questão política fundamental. A discutir em encontro anual.

Ver capítulo 4 e anexo C.

\newpage

# 9. A transparência na prática

Este capítulo trata do funcionamento concreto da **transparência** no AnarBib: quem vê o quê, como, e por quê. É a aplicação do princípio P5 (transparência máxima) e de P6 (notificações sistemáticas).

## 9.1. O princípio

> **P5 — Transparência máxima.** O audit log das mudanças de papel é legível por todo o staff ativo da biblio.
> **P6 — Notificações sistemáticas.** Toda mudança de papel aciona um e-mail à pessoa concernida e a toda a coordenação.

A ideia política: **tornar as manipulações opacas impossíveis**. Se tudo está rastreado e legível, não se pode em silêncio fazer passar uma pessoa de um status a outro sem que isso seja visto pelas outras pessoas do staff.

## 9.2. Quem vê o quê: matriz

### No nível de uma biblio

| Informação | reader | librarian | coordenador | admin de rede |
|---|---|---|---|---|
| Lista da equipe (papéis ativos) | parcial (apenas os nomes públicos) | completa | completa | completa |
| Statuses (`suspended`, `pending_removal`) | não | sim | sim | sim |
| Audit log completo da equipe | não | sim | sim | sim |
| Audit log: razões das ações | não | sim | sim | sim |
| Pedido de retirada em curso: quem pediu | não | sim | sim | sim |
| Dados pessoais das outras pessoas leitoras | não | sim (desta biblio) | sim | sim |

### No nível da rede

| Informação | reader | staff biblio | admin de rede |
|---|---|---|---|
| Lista das admins de rede ativas | sim (página pública `/rede`) | sim | sim |
| Contadores de rede (número de biblios, etc.) | sim | sim | sim |
| Audit log de rede (cooptações, retiradas de admins) | não | não | sim |
| Propostas de cooptação em curso | não | não | sim |
| Logs cross-biblios (ações de admin de rede em biblio X) | não | sim (de sua biblio) | sim |

## 9.3. O audit log de equipe na prática

É a ferramenta de transparência mais importante. Ela é consultável a partir de `/biblioteca` → aba **Equipe** → seção **Histórico da equipe**.

### O que se vê

Cada entrada exibe:
- Data e hora.
- Ação (« promovida·o·e a librarian », « auto-rebaixada·o·e », « retirada solicitada », « suspensa·o·e », « reintegrada·o·e após suspensão », « passagem automática para inativa·o·e após 9 meses », etc.).
- Pessoa concernida (target).
- Autora·or·e da ação (actor) — para as ações humanas. Vazio para as ações automáticas (cron).
- Razão (se preenchida).
- Papel e statuses antes/depois.

### Para que serve politicamente

- **Memória coletiva**: pode-se reconstituir a história da coordenação, ver como ela se constituiu e evoluiu.
- **Guarda-chuva contra a opacidade**: se uma pessoa coordenadora fez ações duvidosas (cooptações estranhas, suspensões injustificadas), isso é visível por todas.
- **Ferramenta de deliberação**: em caso de debate (« a gente tinha dito que iria rodizar as coords! »), o log fornece elementos factuais.
- **Ferramenta de transição**: quando uma nova pessoa coordenadora chega, ela pode ler o log para entender a história recente sem ter de interrogar todo mundo.

### O que fazer com ele

- **Lê-lo regularmente**. Não todos os dias, mas uma vez por mês, em uma reunião de coordenação, por exemplo.
- **Discutir o que parece estranho**. Se uma ação lhe parece incompreensível ou injustificada, pergunte à sua autora·or·e.
- **Não usá-lo como arma**. O log é uma ferramenta de transparência coletiva, não um instrumento de vigilância interpessoal.

## 9.4. Os e-mails de notificação

Cada ação de governança aciona **um ou vários e-mails** automáticos. Não é spam: é proposital, porque ninguém deve ser afetada·o·e por uma mudança de papel sem ser informada·o·e.

### Quem recebe o quê

| Evento | Pessoa concernida | Coords locais ativas | Admins de rede |
|---|---|---|---|
| Cooptação (T1, T2) | ✅ | ✅ | — |
| Auto-rebaixamento (T3, T4) | ✅ confirmação | ✅ | — |
| Pedido de retirada (T5) | ✅ | ✅ | — |
| Cancelamento de pedido (T8) | ✅ | ✅ | — |
| Fim de carência (D+7) | ✅ | ✅ | — |
| Suspensão (T6) | ✅ urgente | ✅ | — |
| Levantamento de suspensão (T7) | ✅ | ✅ | — |
| Saída auto aos 9 meses (T9) | ✅ lembretes + final | ✅ (final somente) | — |
| Última pessoa coord parte | ✅ | ✅ (a pessoa concernida) | ✅ alerta |
| Cooptação admin de rede (proposta) | — | — | ✅ |
| Cooptação admin de rede (sucesso) | ✅ boas-vindas | — | ✅ resumo |
| Cooptação admin de rede (rejeição) | ✅ com rationale | — | ✅ |
| Retirada coletiva admin de rede | ✅ | — | ✅ |
| Intervenção cross-biblios | — | ✅ (coords da biblio) | ✅ (a autora·or·e) |

### O tom dos e-mails

Os e-mails de governança seguem as convenções militantes da rede (cf. memória interna): sobriedade, clareza, acessibilidade (língua comum sem jargão), formulação inclusiva e escrita dessacralizada. Sem fórmulas oficiais, sem assinaturas burocráticas.

Exemplo tipo para um pedido de retirada:
> Oi Karl,
>
> A coordenação da BLMF pediu sua retirada da equipe (papel: librarian), em razão de: « decisão AG de 04/05 ».
>
> Este aviso prévio entrará em vigor em **12 de maio de 2026** (em 7 dias), salvo cancelamento por outra pessoa coord até lá.
>
> Durante esse período, você não tem mais acesso às funções de librarian. Para qualquer discussão, dirija-se à coordenação da BLMF — essa decisão faz parte da vida orgânica do coletivo local e não se gerencia via SIGB.
>
> AnarBib

O tom visa informar factualmente sem dramatizar nem minimizar.

### Confidencialidade dos e-mails — guarda-chuva anti-rastreamento

Os e-mails de governança, como todas as notificações do SIGB, são enviados via **Resend**, o subcontratado de envio da rede (cf. registro de tratamentos e DPA). Duas garantias políticas enquadram esse envio:

- **Nenhum rastreamento.** O acompanhamento de aberturas e cliques — que coletaria o endereço IP, a localização, o dispositivo e o cliente de e-mail da pessoa destinatária — é uma opção **desativada** na instância AnarBib. Receber um e-mail de governança não deixa nenhuma pegada técnica do lado da rede.
- **Minimização.** Apenas os dados estritamente necessários ao envio transitam (endereço de e-mail, nome para a personalização, conteúdo da notificação). Nenhum dado sensível é transmitido.

Esse guarda-chuva é doutrinário: ele prolonga o compromisso de não-rastreamento da rede até a camada de e-mail. Está documentado no registro de tratamentos (art. 30 RGPD) e no DPA; toda mudança de subcontratado de e-mail é notificada às bibliotecas aderentes (DPA art. 5.4).

## 9.5. O caso das notificações « cross-biblios »

Quando uma admin de rede intervém em uma biblio (cf. §8.6), duas notificações são produzidas:

- **Notificação prévia** (manual): a admin envia um e-mail à coordenação local antes de agir. Formato livre.
- **Notificação automática** (pelo SIGB): à execução da ação, o sistema escreve em `cross_library_actions_log` com nível de criticidade, e envia um e-mail às coords ativas da biblio concernida.

Essa dupla notificação (manual + automática) garante que a coordenação local seja avisada **antes** politicamente e **depois** tecnicamente. O rastro técnico é legível a posteriori na aba **Equipe** → seção **Intervenções de rede** (a ser implementada no pacote D).

## 9.6. Limites da transparência

A transparência do AnarBib tem limites que é preciso explicitar:

**As pessoas `reader` não veem o audit log da equipe.** É proposital (P5 fala em « staff ativo »). As pessoas `reader` não veem quem cooptou quem, quem foi suspensa·o·e, etc. A transparência opera **na coordenação**, não em direção às usuárias·os.

**Uma biblio não vê o audit log de outra biblio.** Soberania local (P7). As mudanças de papel na biblio A são estritamente opacas para a biblio B, salvo via canal humano (discussão entre coords das duas biblios).

**O audit log de rede (cooptações e retiradas de admins) não é público.** Legível apenas pelas admins de rede. Uma biblio local pode ver a lista das admins de rede atuais (página `/rede`), mas não o histórico das cooptações nem as rationales dos votos opostos.

Esses limites não são hipocrisias. Eles correspondem a um equilíbrio entre **transparência** (dentro do staff deliberante) e **confidencialidade** (em relação às usuárias·os e entre perímetros). Se você acha o equilíbrio mal colocado, é emendável (capítulo 4).

## 9.7. Se a regra lhe incomoda

**Você acha que as pessoas `reader` deveriam ver o audit log da equipe** (transparência radical em relação às usuárias·os). É uma posição defensável, mas tem consequências (os conflitos internos se tornam públicos, a vida política do coletivo se expõe). A discutir em rede.

**Você acha ao contrário que o audit log é visível demais** (uma pessoa librarian discreta não deveria poder « espionar » as ações das coords). Também é defensável. Mas isso contradiz P5. A discutir.

**Você acha os e-mails em número excessivo ou pouco explícitos.** O conteúdo está parametrizado em `mail-strings.ts` × 10 locales. Toda modificação de um e-mail é emendável como uma modificação de código. A levar com as pessoas dev.

**Você acha que o audit log de rede deveria ser público ao menos para as coords locais** (para que elas possam ver quem decide o quê no nível de rede). É uma opção interessante. A discutir.

Ver capítulo 4 e anexo C.

\newpage

# 10. Casos concretos comentados

Para finalizar, seis cenários completos. Cada um ilustra uma combinação de mecanismos e permite ver o SIGB em ação. Os nomes (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) são os de camaradas históricoas do pensamento libertário; eles servem aqui como casos-tipo fictícios.

## 10.1. Voltairine é cooptada librarian

> **Contexto.** Emma é coordenadora na BLMF. Voltairine frequenta as permanências há oito meses, participa da vida da biblioteca e tem claramente o perfil para entrar na equipe. O coletivo local discutiu em AG no dia 4 de maio e acatou sua cooptação.

**Procedimento.**

1. Emma se conecta no dia 5 de maio às 14h30. Vai em `/biblioteca`, aba **Equipe**.
2. Busca Voltairine na lista de `reader` da biblioteca (ela tem conta AnarBib desde fevereiro).
3. Clica **« Convidar para a equipe »** → escolhe **librarian**.
4. Campo « Motivo »: « decisão AG de 04/05 » (doutrina 1, exigência estrita).
5. Confirma.

**Efeito imediato.**

- Voltairine recebe um e-mail: « Olá Voltairine, você foi nomeada librarian da BLMF por Emma G. em razão de: "decisão AG de 04/05". Seus novos direitos estão ativos. Bem-vinda à equipe. »
- As demais coordenadoras ativas da BLMF (Lucy e Piotr) recebem um e-mail informativo.
- Audit log: `2026-05-05 14:30 — Emma G. promoveu Voltairine d.C. a librarian (motivo: decisão AG de 04/05)`.

**Comentário.**

Caso mais simples. O SIGB executa corretamente a decisão do coletivo. Emma não decidiu nada politicamente — ela clicou para executar o que foi decidido fora do software.

**O que o SIGB não fez:** verificar que a AG realmente aconteceu, que a decisão realmente foi tomada, que Voltairine realmente concordou. Essas coisas estão **fora do software**. Se Emma tivesse mentido sobre a AG, o SIGB não teria visto nada. A cultura política da BLMF é o que impede essa mentira (e o log a torna rastreável a posteriori).

## 10.2. Lucy passa o bastão

> **Contexto.** Lucy é coordenadora na BLMF, mas não pode mais assumir a carga neste semestre (ela começa uma tese). Ela quer « voltar a ser librarian » para continuar na equipe mas aliviar suas responsabilidades.

**Procedimento.**

1. Lucy vai em `/biblioteca`, aba **Equipe**.
2. Na sua própria linha (status `coordenador`), clica **« Passo o bastão »**.
3. Escolha: « voltar a ser librarian ».
4. Modal de confirmação lembra que ela perderá as permissões de coordenação imediatamente.
5. Lucy confirma. Motivo opcional: « início da tese, redução temporária de carga ».

**Efeito imediato.**

- Sua membership `coordenador` passa a `inactive`.
- Sua membership `librarian` (que existia em paralelo) permanece `active`.
- Lucy recebe um e-mail de confirmação: « Você agora é librarian da BLMF. Você mantém suas permissões operacionais. »
- Toda a coordenação (Emma, Piotr) recebe um e-mail: « Lucy P. passou o bastão, não é mais coordenadora. Ela continua librarian da equipe. »
- Audit log: `2026-05-05 18:42 — Lucy P. se auto-rebaixou coordenador → librarian (motivo: início da tese, redução temporária de carga)`.

**Comentário.**

É o uso exemplar do direito P3. Lucy não precisou pedir autorização a ninguém. Seu auto-rebaixamento é imediato. Ela continua contribuindo para a biblioteca, mas numa intensidade ajustada à sua disponibilidade atual.

**Politicamente**: é exatamente o tipo de rotação que se busca favorecer. Não se perde Lucy, ela apenas assume outro papel. Em seis meses ou um ano, se ela quiser retomar a coordenação, o coletivo poderá recooptá-la (T2). Nenhuma decisão é definitiva.

## 10.3. Karl precisa partir

> **Contexto.** Karl é librarian na BLMF. Seu comportamento com algumas leitoras e leitores gerou problema (paternalismo, comentários inapropriados). O coletivo discutiu em AG no dia 4 de maio e decidiu que ele deveria deixar a equipe.

**Procedimento.**

1. Piotr (coord) — escolhido pela AG para executar a decisão — vai em `/biblioteca`, aba **Equipe**.
2. Na linha de Karl, clica **« Solicitar retirada »**.
3. Modal vermelha com prazo de 7 dias explícito.
4. Motivo obrigatório: « Em razão de AG de 04/05, comportamento inadequado com várias leitoras e leitores relatado durante vários meses, decisão coletiva de exclusão. »
5. Confirmação explícita: « Entendo que esta solicitação terá efeito em 12 de maio de 2026, salvo cancelamento por outra coordenadora ou coordenador. »

**Efeito imediato.**

- Membership de Karl passa a `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl perde o acesso** imediatamente a todas as funções de librarian (a membership fica congelada).
- Karl recebe um e-mail:
  > « Olá Karl, a coordenação da BLMF solicitou sua retirada da equipe (papel: librarian), em razão de: "Em razão de AG de 04/05, comportamento inadequado com várias leitoras e leitores relatado durante vários meses, decisão coletiva de exclusão." Este aviso prévio terá efeito em 12 de maio de 2026 (em 7 dias), salvo cancelamento por outra coordenadora ou coordenador até lá. Para qualquer discussão, dirija-se à coordenação da BLMF. »
- Emma e Lucy (demais coords) recebem o e-mail informativo.
- Audit log: `2026-05-05 — Piotr K. solicitou a retirada de Karl M. (papel: librarian, motivo: ...)`.

**Evolução.**

- 6 de maio às 9h: Lucy lê o e-mail. Concorda com a decisão e não intervém.
- 7 de maio: Emma tem uma conversa com Karl (que lhe escreve para se explicar). Emma conclui que a decisão se mantém. Não intervém.
- 8-11 de maio: nada.
- **12 de maio às 00h00**: o cron `cron_team_pending_removal_complete` é executado. Karl passa a `inactive`.
- E-mail final para Karl + para a coordenação.
- Audit log: `2026-05-12 — passagem automática para inativo (motivo: pending_removal expirado, cron) — actor: NULL`.

**Comentário.**

É o caso da exclusão coletiva. Três elementos políticos a notar:

- **A carência funcionou como possível salvaguarda**, sem ser utilizada. Lucy e Emma poderiam ter cancelado; não o fizeram. O fato de ninguém ter cancelado é ele próprio uma **deliberação implícita**.
- **Karl ficou informadoa** sem surpresa. Sem exclusão silenciosa.
- **O audit log é legível** por toda a equipe e permite revisitar essa decisão se mais tarde alguém se perguntar por que Karl foi embora.

**Politicamente delicado**: o motivo escrito no campo « Motivo » é legível por toda a equipe. Não deveria conter detalhes sobre as vítimas (RGPD, dignidade), mas deveria ser claro o suficiente para que a decisão seja defensável politicamente. Encontrar o equilíbrio certo é uma competência de coordenação.

## 10.4. Conta comprometida: suspensão imediata

> **Contexto.** No dia 5 de maio às 19h30, Emma nota nos logs de atividade que Friedrich (librarian) realizou 47 modificações de fichas do catálogo em 3 minutos, várias delas aberrantes (livros marcados como « desaparecidos » quando estão na estante, etc.). O padrão se parece com um acesso não autorizado.

**Procedimento.**

1. Emma vai em `/biblioteca`, aba **Equipe**.
2. Na linha de Friedrich, clica **« Suspender »**.
3. Modal com motivo **obrigatório** (≥ 20 caracteres).
4. Emma digita: « Suspeita de conta comprometida, atividade anormal (47 modif. catálogo em 3 min), verificação em curso. »
5. Confirma.

**Efeito imediato (19h32).**

- Friedrich passa a `status='suspended'`.
- **Nenhum acesso** para Friedrich.
- Friedrich recebe um e-mail urgente: « Sua conta AnarBib foi suspensa a título cautelar na BLMF. Motivo: suspeita de comprometimento da sua conta. Recomendamos fortemente que você **troque sua senha imediatamente**. Uma vez que sua conta esteja segura, entre em contato com a coordenação da BLMF para que a suspensão seja levantada. »
- A coordenação (Lucy, Piotr) recebe um e-mail.
- Audit log: `2026-05-05 19:32 — Emma G. suspendeu Friedrich E. (papel: librarian, motivo: ...)`.

**Evolução.**

- **19h35**: Emma liga para Friedrich (canal fora do SIGB). Friedrich confirma que não realizou essas ações. Ele havia deixado seu computador aberto em um espaço compartilhado.
- **19h40**: Friedrich troca sua senha pelo procedimento de redefinição.
- **20h00**: Emma verifica as ações suspeitas no audit log da biblioteca (o audit de catálogo, não o audit team). Identifica as 47 modificações. Cancela-as manualmente ou solicita um rollback a uma pessoa administradora de rede se necessário.
- **20h15**: Emma volta à aba Equipe, levanta a suspensão de Friedrich.
- Friedrich recebe um e-mail de confirmação. Audit log: `2026-05-05 20:15 — Emma G. levantou a suspensão de Friedrich E.`.

**Comentário.**

Caso típico em que a suspensão é usada como **medida cautelar**, não como exclusão. Friedrich não está em falta — foi sua conta que foi comprometida. A suspensão durou 43 minutos, o tempo necessário para garantir a segurança.

**Importante politicamente**: Friedrich não foi « acusadoe ». O e-mail deixa isso claro (« a título cautelar »). Quando a situação é resolvida, a suspensão é levantada e o episódio fica registrado no log como um incidente, não como uma punição.

## 10.5. Errico é a única coord e quer partir

> **Contexto.** A BLMF tem apenas uma coordenadora ou coordenador ativo, Errico. Lucy passou o bastão, Emma mudou de cidade e não está mais ativa. Piotr se auto-rebaixou no início do ano. Errico precisa partir (mudança para o exterior, sem mais tempo).

**Procedimento.**

1. Errico vai em `/biblioteca`, aba **Equipe**, clica **« Passo o bastão »**.
2. Uma modal **especial** se abre:
   > ⚠️ **ATENÇÃO**: você é a única coordenadora ou coordenador ativo da BLMF. A biblioteca ficará sem coordenação. As pessoas administradoras de rede do AnarBib serão notificadas. A BLMF poderá continuar a funcionar (as pessoas librarians continuam operacionais) mas nenhuma modificação de configuração será possível até a cooptação de uma nova coordenadora ou coordenador. Continuar?
3. Errico confirma. Motivo: « Mudança para o exterior, sem mais disponibilidade para a coordenação. »

**Efeito imediato.**

- Membership coordenador de Errico passa a `inactive`.
- E-mail para Errico (confirmação).
- E-mail para toda a coordenação da BLMF — mas não há mais nenhuma, então na prática são as pessoas `librarian` ativas restantes que recebem uma notificação.
- **E-mail urgente para as pessoas admins de rede**: « A BLMF não tem mais coordenadora ou coordenador ativo. Pessoas librarians ativas restantes: Voltairine d.C., Friedrich E., ... »
- Audit log: `2026-05-05 — Errico M. se auto-rebaixou coordenador → reader (motivo: ..., warning: last_coordinator_leaving)`.

**Evolução fora do software.**

- 6 de maio: Xavier (admin de rede) entra em contato com Voltairine e Friedrich, as pessoas `librarian` ativas restantes. Elas confirmam que o coletivo BLMF ainda existe e que querem continuar.
- 7-15 de maio: discussão interna do coletivo BLMF, que decide em AG cooptar Voltairine no papel de coordenadora.
- 16 de maio: Xavier (ou outra coordenadora ou coordenador da BLMF que já não existe nesse caso, portanto Xavier no seu direito transversal) coopta Voltairine como coordenadora. **Informação prévia obrigatória**: Xavier escreveu para Friedrich e Voltairine 2 dias antes para anunciar a ação. Uma vez feita, a ação fica registrada em `cross_library_actions_log` com nível de criticidade « elevado » (modificação de coordenação de uma biblioteca por admin de rede).

**Comentário.**

Caso politicamente delicado: a biblioteca passa por um período de fragilidade (entre 5 e 16 de maio, ela não tem coordenação). Mas o SIGB **não impediu** a partida de Errico — seu direito P3 é incondicional. O SIGB apenas **alertou a rede** para que ela pudesse ajudar.

A intervenção de Xavier ilustra o uso **adequado** do direito transversal: ele foi solicitado (implicitamente, pelo alerta automático), respeitou a informação prévia, registrou sua ação. Ele não impôs Voltairine; foi o coletivo BLMF que a escolheu. Xavier apenas **executou tecnicamente** a decisão.

## 10.6. Uma cooptação de admin de rede que não dá certo

> **Contexto.** Xavier é admin de rede fundadore. Com o tempo, Maria, Patricia e Diego foram cooptados como admins de rede à medida que a rede se expandiu. Em 20 de maio de 2026, o coletivo de admins é: Xavier, Maria, Patricia, Diego (quatro admins ativos).
>
> Maria propõe a cooptação de Mohammed, que ela conhece em uma biblioteca italiana que está ingressando na rede.

**Procedimento.**

1. Maria, em `/rede/administradores`, clica **« Propor uma cooptação »**.
2. Insere a identidade de Mohammed (conta AnarBib criada duas semanas antes).
3. Motivação: « Mohammed coordena a BLA (Bologna), uma biblioteca que ingressa na rede este mês. Ele liderou a integração política da BLA no AnarBib e está muito envolvido na coordenação italiana. Sua cooptação como admin de rede fortalecerá a diversidade geográfica do coletivo e facilitará a animação do lado da Itália. »
4. Confirma.

**Efeito imediato.**

- Proposta criada, `status='open'`, `expires_at = 19 de junho de 2026`.
- Voto automático `favorable` de Maria registrado.
- E-mails para Xavier, Patricia, Diego com a proposta.

**Evolução.**

- 22 de maio: **Diego** vota `favorable`. Sem justificativa (opcional para favorável).
- 25 de maio: **Patricia** vota `opposed`. Justificativa: « Mohammed não tem nenhuma antiguidade na rede. Sua cooptação vai mais rápido que a da BLA, que ainda não teve a oportunidade de funcionar como biblioteca AnarBib por tempo suficiente. Proponho esperar 6 meses para que a BLA se estabeleça, e então repropostar Mohammed nesse momento. » Patricia marca « Revelar minha identidade ».

**Efeito imediato do voto opposed.**

- Proposta passa a `status='rejected'`.
- E-mail para Mohammed: « Olá Mohammed, sua proposta de cooptação como admin de rede do AnarBib não foi aprovada. Patricia X. levantou a seguinte objeção: "[justificativa completa]". Você pode conversar com ela ou com Maria, que te havia proposto. A cooptação poderá ser repropostada posteriormente. »
- E-mail para Maria (proponente): resumo com a justificativa de Patricia.
- E-mail para Xavier e Diego: informação de que a proposta foi rejeitada, com a justificativa.
- Audit log de rede: `2026-05-25 — cooptação rejeitada: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Comentário.**

Caso ilustrativo da unanimidade **em ação**. Patricia tem um veto, ela o usa, sua justificativa é explícita e construtiva (« esperemos 6 meses »). Ela optou por revelar sua identidade, o que permite a Mohammed e a Maria conversar diretamente com ela em vez de especular sobre quem se opôs anonimamente.

**Politicamente**: a cooptação por unanimidade não é uma garantia de bloqueio permanente. Patricia não diz « nunca » mas « não agora ». Se em 6 meses a BLA estiver bem integrada e Patricia mudar de opinião, uma nova proposta poderá ser aprovada. É essa **reversibilidade no tempo** que torna a unanimidade suportável.

A alternativa — cooptar Mohammed por maioria contra a opinião de Patricia — teria criado um círculo de admins onde Patricia se sentiria em posição desconfortável. Melhor esperar.

\newpage

# Anexos

\newpage

# Anexo A — Glossário

**AG** — Assembleia geral. Reunião coletiva de tomada de decisão de uma biblioteca. O SIGB não modela a AG (P8). Sua modalidade (quórum, frequência, modo de deliberação) é inteiramente decidida por cada biblioteca.

**Audit log** — Registro das ações de governança, armazenado em `library_membership_audit` (no nível de uma biblioteca) e `network_administrator_audit` (no nível de rede). Legível pela equipe ativa (no nível da biblioteca) e pelas pessoas admins de rede (no nível de rede).

**Auto-rebaixamento** — Ação pela qual uma pessoa da equipe se rebaixa para um papel inferior. Direito P3, incondicional.

**Biblioteca `private`** — Biblioteca cujo catálogo é visível apenas por suas pessoas membros inscritas. Modo adequado para bibliotecas com exposição política.

**Biblioteca `network`** — Biblioteca cujo catálogo é visível por todas as pessoas `reader` validadas da rede AnarBib. Modo padrão para a maioria das bibliotecas.

**Biblioteca `public`** — Biblioteca cujo catálogo é visível por todas as pessoas, incluindo visitantes anônimos.

**Carência** — Prazo imposto entre uma decisão e seu efeito. Sete dias para retiradas coletivas de equipe local e de admin de rede. Trinta dias para o auto-retirada da única pessoa admin de rede ativa.

**Cooptação** — Mecanismo de entrada em uma equipe (equipe local) ou no coletivo de admins de rede. Para a equipe local: decisão de uma coordenadora ou coordenador+. Para a rede: unanimidade das pessoas admins ativas.

**Cross-bibliotecas** — Qualifica uma ação realizada por uma pessoa admin de rede em uma biblioteca da qual ela não é membro da equipe local. Registrada em `cross_library_actions_log`.

**Cron** — Tarefa automática executada periodicamente pelo SIGB. Sem ator ou atora humana. Exemplos: `cron_team_pending_removal_complete` (passagem de `pending_removal` para `inactive` em J+7), `cron_team_inactive_cleanup` (saída automática aos 9 meses).

**Delegação** — Ato pelo qual um coletivo confia temporariamente uma função a uma de suas pessoas membras, mantendo a possibilidade de retomá-la. Conceito central, distinto de « hierarquia ».

**Membership** — Linha da tabela `user_library_memberships` que expressa o vínculo de uma pessoa com uma biblioteca em um determinado papel. Uma pessoa pode ter várias memberships em uma biblioteca (multi-membership).

**Multi-membership** — Possibilidade de ter várias linhas de membership para uma mesma pessoa em uma mesma biblioteca, com papéis diferentes.

**Rede** — O coletivo de bibliotecas que se reconhecem mutuamente e compartilham a plataforma AnarBib. Não uma organização central, uma federação.

**RPC** — *Remote Procedure Call*. Função SQL chamada pela interface da pessoa usuária para executar uma ação. Todas as ações de governança passam por RPCs nomeadas `fn_team_*` (equipe local) ou `fn_network_admin_*` (rede).

**Soberania local** — Princípio P7 segundo o qual cada biblioteca é soberana sobre suas delegações internas. Mudanças de papel em uma biblioteca não afetam nada em outra.

**Spec** — Documento de especificação (`spec-*.md`) que descreve em detalhes o funcionamento de uma funcionalidade do SIGB. Fonte de verdade técnica e política. Versionada, datada, emendável.

**Unanimidade** — Modalidade de cooptação e de retirada coletiva das pessoas admins de rede. Todos os votos devem ser `favorable`; um único `opposed` ou uma abstenção não levantada bloqueia.

**Validação física** — Procedimento pelo qual uma pessoa librarian+ valida uma conta `reader` após um encontro presencial. Vale para toda a rede (pacto de reconhecimento mútuo).

**Veto** — Voto `opposed` durante uma cooptação ou retirada coletiva de admin de rede. Efeito imediato: rejeição da proposta. Justificativa obrigatória de no mínimo 20 caracteres.

\newpage

# Anexo B — Índice das funções técnicas

Este anexo fornece, para cada RPC mencionada no guia, sua tradução política e a transição correspondente. Serve como referência rápida.

## Funções de equipe local

| RPC SQL | Transição | Tradução política |
|---|---|---|
| `fn_team_promote_to_librarian` | T1 | Cooptação `reader` → `librarian` |
| `fn_team_promote_to_coordenador` | T2 | Cooptação `librarian` → `coordenador` |
| `fn_team_self_demote` | T3, T4 | Auto-rebaixamento (« passo o bastão ») |
| `fn_team_request_remove_member` | T5 | Solicitação de retirada com carência de 7 dias |
| `fn_team_cancel_remove_member` | T8 | Cancelamento de solicitação de retirada |
| `fn_team_suspend_member` | T6 | Suspensão imediata (medida cautelar) |
| `fn_team_unsuspend_member` | T7 | Levantamento de suspensão |
| `fn_validate_physical_account` | — | Validação física de uma pessoa `reader` |
| `cron_team_pending_removal_complete` | T5 (continuação) | Cron: passagem para `inactive` em J+7 |
| `cron_team_inactive_cleanup` | T9 | Cron: saída automática aos 9 meses |

## Funções de admin de rede

| RPC SQL | Etapa | Tradução política |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Cooptação: proposta | Uma pessoa admin propõe uma nova |
| `fn_network_admin_vote_cooptation` | Cooptação: voto | Voto favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Auto-retirada | Deixar suas funções de admin de rede |
| `fn_network_admin_request_removal` | Retirada coletiva | Fluxo espelho da cooptação |

## Helpers de autorização (usados pelas RLS)

| Helper SQL | Sentido político |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | Esta pessoa pode agir como equipe nesta biblioteca? (equipe local ativa OU admin de rede) |
| `user_can_engage_library(library_id)` | Esta pessoa pode engajar politicamente esta biblioteca? (coord local ativa OU admin de rede) |
| `fn_caller_is_network_admin()` | Quem chama é uma pessoa admin de rede ativa? |
| `fn_library_visible_to_caller(library_id)` | O catálogo desta biblioteca é visível para quem chama? |

## Tabelas principais

| Tabela | Sentido político |
|---|---|
| `user_library_memberships` | As delegações locais (quem é equipe de qual biblioteca) |
| `network_administrators` | As pessoas administradoras da rede |
| `library_membership_audit` | Registro das ações de governança local |
| `network_administrator_audit` | Registro das ações de governança de rede |
| `network_administrator_cooptation_proposals` | Propostas de cooptação em andamento |
| `network_administrator_cooptation_votes` | Votos individuais das pessoas admins |
| `cross_library_actions_log` | Rastro das ações de admin de rede em bibliotecas |

\newpage

# Anexo C — Modelo de nota de emenda

Quando você quiser propor uma emenda a uma regra do SIGB ou a este guia, segue um modelo de nota para estruturar sua proposta. Formato livre, pode adaptá-lo.

---

## Proposta de emenda a [nome da spec ou do guia]

**Autora(s) ou autor(es):** [seus nomes / pseudônimos]
**Data:** [DD/MM/AAAA]
**Escopo:** [biblioteca local / rede / fundamentos]

### 1. Regra em questão

Citar textualmente a regra ou parágrafo a ser emendado, com sua referência na spec fonte.

> *Exemplo:* « `spec-gouvernance-roles.md`, §5.6, T5: O prazo de carência antes da exclusão efetiva é de 7 dias. »

### 2. Problema identificado

Descrever em algumas frases o que é problemático na regra atual. Se possível com um caso concreto encontrado.

> *Exemplo:* « Na prática, 7 dias é muito curto quando a AG seguinte da biblioteca se realiza em 15 dias. Uma decisão de retirada tomada a quente às vezes não tem tempo de ser discutida coletivamente antes do efeito automático. »

### 3. Emenda proposta

Descrever a modificação desejada, na medida do possível com uma formulação pronta para integrar à spec.

> *Exemplo:* « Ampliar o prazo de carência de 7 para 14 dias, OU tornar o prazo configurável por biblioteca (entre 7 e 30 dias), com valor padrão em 14 dias. »

### 4. Consequências técnicas antecipadas

Se você tiver ideia do que isso implica no código, dizê-lo. Caso contrário, dizer também (« não sei, a ver com as pessoas desenvolvedoras »).

> *Exemplo:* « Modificar o valor fixo no código SQL de `fn_team_request_remove_member` e `cron_team_pending_removal_complete`. Se configurável por biblioteca, adicionar uma coluna a `libraries`. »

### 5. Consequências políticas antecipadas

Descrever o que muda na prática coletiva e os possíveis efeitos colaterais.

> *Exemplo:* « Mais tempo para deliberação, mas também mais tempo durante o qual a pessoa em `pending_removal` permanece suspensa (sem acesso). Pode ser percebido como mais pesado. »

### 6. Alternativas consideradas

Mencionar as outras pistas que você considerou e por que as descarta (ou não).

> *Exemplo:* « Alternativa: manter o prazo em 7 dias, mas permitir uma "prorrogação explícita" por outra coordenadora ou coordenador. Mais complexo de implementar e de entender. Preferível modificar o padrão. »

### 7. Discussão desejada

Onde e como você quer que a proposta seja discutida?

> *Exemplo:* « Discussão no canal Matrix `#anarbib`, depois, se houver consenso, integração à spec no próximo pacote de governança. »

---

Uma vez redigida, fazer circular a nota conforme o escopo (cf. capítulo 4, §4.2).

\newpage

# Anexo D — Specs fontes e referências

Este guia se apoia nos seguintes documentos, consultáveis no repositório do projeto:

## Specs principais

**`spec-gouvernance-roles.md`** — Spec fundadora da governança dos papéis de equipe local. Versão 1.0 de 5 de maio de 2026. 1231 linhas. Detalha os 4 papéis, os 5 status, as 9 transições, o audit log, as notificações, a UI e 15 casos de uso de referência.

**`spec-administrateur-reseau.md`** — Separação entre equipe local e admin de rede. Versão 0.3 de 11 de maio de 2026. 975 linhas. Detalha a tabela `network_administrators`, a cooptação por unanimidade, a retirada coletiva, o direito transversal e a semântica dos contadores « página = escopo ».

**`spec-validation-physique.md`** — Modos de acolhimento das contas de leitoras e leitores (`open` vs `manual_validation`). Definida em 3 de maio de 2026. Detalha os estados da conta, o esquema de BD e os fluxos.

**`spec-refactor-v3-semantique.md`** — Refatoração da semântica do fluxo de reserva. Não central para a governança, mas citado marginalmente pela coerência do conjunto do SIGB.

## Specs relacionadas mencionadas (a redigir ou em andamento)

- `spec-migration-compte.md` — Migração de uma conta de uma biblioteca para outra. 940 linhas, definida em 3 de maio de 2026.
- `spec-invitation-equipe.md` — Fluxo de convite por e-mail para pessoas sem conta AnarBib. A redigir.
- `spec-fermeture-biblio.md` — Procedimento de fechamento adequado de uma biblioteca. A redigir.
- `spec-mediation-conflits.md` — Quadro formalizado de mediação e investigação após denúncia. A redigir (sugerido pelo presente guia).

## Para saber mais

As specs e o código-fonte estão no repositório Codeberg do projeto, espelhado no GitHub. A discussão técnica e política ocorre no canal Matrix `#anarbib` da rede.

Para qualquer proposta de emenda a este guia ou às specs, ver capítulo 4 e anexo C.

---

*Fim do guia. Versão 1.0, 11 de maio de 2026.*

*Este guia é ele próprio emendável. Se você achar que ele está errado, que esqueceu um caso ou que assume uma posição que não corresponde mais à doutrina da rede, diga.*

