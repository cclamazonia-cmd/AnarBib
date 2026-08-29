# Backlog AnarBib v34 — Reescrita integral sobre estado verificado — ferramenta de trabalho para as colaboradoras e os colaboradores por vir

**2026-08-29** · 92 itens · Version française : `AnarBib-Backlog-2026-08-29-v34.md`

> Arquivo **gerado** por `scripts/build-backlog.cjs` a partir de `backlog-v34.json`. Não o modifique à mão.

---

## Sumário

- [Por que uma reescrita](#por-que-uma-reescrita)
- [Modo de usar](#modo-de-usar)
- [O estado real em 29 de agosto de 2026](#o-estado-real-em-29-de-agosto-de-2026)
- [Desvios levantados entre o real e o escrito](#desvios-levantados-entre-o-real-e-o-escrito)
- [O calendário restrito](#o-calendário-restrito)
- [Dez regras pagas por um incidente](#dez-regras-pagas-por-um-incidente)
- [Os canteiros](#os-canteiros)
    - [A — Sustentabilidade coletiva](#a-sustentabilidade-coletiva) · 4
    - [B — Banco de dados, segurança, RLS](#b-banco-de-dados-segurança-rls) · 12
    - [C — Catalogação e dados documentais](#c-catalogação-e-dados-documentais) · 10
    - [D — Periódicos, efêmeros, recursos digitais](#d-periódicos-efêmeros-recursos-digitais) · 6
    - [E — Front, OPAC, i18n, acessibilidade](#e-front-opac-i18n-acessibilidade) · 11
    - [F — E-mail e notificações](#f-e-mail-e-notificações) · 5
    - [G — Rede, governança, federação](#g-rede-governança-federação) · 10
    - [H — Interoperabilidade, tesauro, coleta](#h-interoperabilidade-tesauro-coleta) · 7
    - [I — Auto-hospedagem, operação, backups, CI](#i-auto-hospedagem-operação-backups-ci) · 13
    - [J — Documentação e corpus](#j-documentação-e-corpus) · 6
    - [K — Caixa, comunicação, formação](#k-caixa-comunicação-formação) · 8
- [Encerramentos e entradas caducas](#encerramentos-e-entradas-caducas)
- [O que não está no backlog](#o-que-não-está-no-backlog)
- [Manutenção deste documento](#manutenção-deste-documento)

---

## Por que uma reescrita

Este documento substitui o backlog v33 de 17 de junho de 2026. Entre os dois, **216 das 221 migrações aplicadas em produção** foram escritas, além de 655 commits. O v33 trazia um aviso de frescor acrescentado em 28 de agosto; já não bastava.

O v34 não é uma atualização do v33: é uma **reescrita sobre estado verificado**. Cada afirmação de estado foi relida em 29 de agosto de 2026 contra duas fontes primárias — o banco de dados de produção consultado em somente-leitura, e o repositório Codeberg no commit `1d00ed2c`. Nenhum item foi transportado com base na fé de um documento.

Esse trabalho produziu um resultado que comanda a leitura de todo o resto: **a documentação erra nos dois sentidos**. Ela declara abertos canteiros entregues há semanas, e declara entregues coisas que ninguém jamais exerceu. A seção «Desvios levantados» nomeia cada um deles.

---

## Modo de usar

**Este documento não arbitra nada.** A precedência documental do projeto continua sendo a de `docs/INDEX.md`: o `REGISTRE_decisions.md` faz fé, depois a spec do domínio, depois este backlog. Se uma linha daqui contradiz o REGISTRO, é o REGISTRO que tem razão e essa linha é um defeito a sinalizar.

**Para começar sem pedir nada a ninguém**, leia `docs/CHANTIERS_OUVERTS.md`: sete portas de entrada que não exigem nenhuma coordenação. O presente backlog é o que vem depois, quando se quer saber o que falta e por quê.

**Antes de pegar um item, abra uma issue no Codeberg.** Duas pessoas escrevendo a mesma correção é uma noite perdida para uma das duas. É a única regra de coordenação do projeto, e cabe em uma linha.

**Cada ficha diz seis coisas**: o que é, o estado verificado em 29/08, por que importa, o que conta como terminado, o que exige, e do que depende. Se uma faltar, a ficha está incompleta — diga isso em vez de adivinhar.

**Os identificadores nunca são reutilizados.** Um item liquidado guarda seu número e passa para a seção dos encerramentos. As remissões entre colchetes apontam para o REGISTRO, uma spec ou um identificador herdado de um backlog anterior: permitem recuperar o rastro, não fazem autoridade por si mesmas.

---

## O estado real em 29 de agosto de 2026

Levantamento de **29 de agosto de 2026**. Banco de produção `uflwmikiyjfnikiphtcp` consultado em somente-leitura; repositório `codeberg.org/anarbib/anarbib` no commit `1d00ed2c`. Estes números não são estimativas: são a resposta de uma consulta ou de um `ls`. Vão vencer rápido — é normal, e é a razão pela qual estão datados.

### Banco

| | | |
|---|---:|---|
| Tabelas `public` | **187** | todas com RLS ativado, 279 policies em 174 tabelas |
| Tabelas `ingest` | **10** | 8 estavam sem RLS na manhã de 29/08 — **as 10 estão desde a noite** (item **B1**, liquidado). O esquema nunca esteve exposto: nem `anon` nem `authenticated` tem `USAGE` nele |
| Views `api` | **68** | 61 SECURITY INVOKER, **7 DEFINER** (item **B3**) |
| Funções aplicativas | **847** | das quais **664 SECURITY DEFINER**; nenhuma sem `search_path` fixado |
| Migrações aplicadas | **221** | 224 arquivos no repositório; 3 datadas em 30/08 (item **I9**) |
| Jobs `pg_cron` | **36** | **todos ativos**; 0 falha desde 17/08; 1 nunca executado (`oai-harvest-weekly`) |
| Avisos de segurança | **515** | 0 ERROR · 464 + 36 WARN sobre as funções DEFINER expostas · 15 INFO RLS sem policy |
| Avisos de performance | **256** | 170 índices não usados · 38 chaves estrangeiras não indexadas · 24 policies permissivas · 9 `auth_rls_initplan` |
| Esquemas de refugo | **2** | `backup_2026_05_07` (6 tabelas vazias) e `conv_backup` (7 tabelas de revisão humana) |

### Funções Edge

| | | |
|---|---:|---|
| Implantadas e ativas | **48** | todas reimplantadas em bloco em 28/08 às 02h24 |
| Pastas no repositório | **49** | + `_shared`; a 49ª é o roteador `main`, **nunca implantado no Supabase, e é intencional** |
| Declarações `verify_jwt` | **31** | **todas em `false`**; 18 funções implantadas não estão declaradas (item **B6**) |

### Catálogo

| | | |
|---|---:|---|
| Registros | **2 676** | 2 741 exemplares, 2 495 obras, 1 305 autoridades |
| Rascunhos de catalogação | **2 237** | 5 671 inserções acumuladas, 310 na fila de revisão |
| Indexação de assunto | **1 127 / 2 676** | 42 % dos registros; 1 284 atribuições sobre 89 assuntos locais |
| Tesauro FICEDL | **462** | termos, **10 locales completas**; 98 alinhamentos para os assuntos locais |
| Periódicos | **4** | títulos, 7 fascículos vinculados — P1→P9 entregues em 27-28/08 |

### Rede

| | | |
|---|---:|---|
| Bibliotecas | **5** | `blmf` 248 · `btl` 2 187 · `mleg` 269 · `cira-marseille` 0 · `blmf-teste` 0 |
| Contas | **16** | 28 vínculos ativos |
| Administradores·as de rede | **1** | **é o item A1, e ele comanda todo o resto** |
| Circulação viva | **5 / 19 / 22 / 2** | empréstimos / reservas / consultas / EEB — últimas escritas: 01/08 para empréstimos, 18/06 para o resto |

### Repositório

| | | |
|---|---:|---|
| Commits | **2 265** | 655 desde o v33; 345 só no mês de agosto |
| Arquivos `src/` | **280** | 38 rotas, 79 páginas, 89 componentes |
| Chaves i18n | **6 177** | × 10 locales, paridade estrita verificada na CI |
| Testes | **171 + 43** | 171 casos JavaScript, 43 suítes SQL — **6 suítes não rodam na CI** (item **I7**) |
| Marcadores de dívida | **17** | dos quais 4 em `src/` e **nenhum** é uma tarefa aberta real: a dívida não está no código |

---

## Desvios levantados entre o real e o escrito

Eis por que o v33 não podia mais servir. Estes desvios não são negligências: são o rastro normal de um projeto que entregou 655 commits enquanto seus documentos de pilotagem ficaram parados. O que importa não é lamentá-los, é saber que vão **nos dois sentidos** — e portanto que um documento não reverificado tanto pode fazer perder tempo refazendo o existente quanto acreditar adquirido o que não é.

### Declarado aberto, na verdade entregue

**As seis migrações de convenções catalográficas**

- *O que diz a documentação* — «escritas, nunca aplicadas» — `REPRISE_claude_code_conventions_2026-08-20`
- *O que diz o banco ou o repositório* — **19 migrações `conventions_00` a `conventions_17` aplicadas em 21/08**, bem além das seis anunciadas. O canteiro foi conduzido quase inteiramente.

**A colegialidade de promoção a coordenador·a**

- *O que diz a documentação* — «escrita, testada fora de produção, não aplicada» + runbook de implantação em 11 etapas
- *O que diz o banco ou o repositório* — `20260826120000_team_coordenador_collegial_promotion` **está em produção**. O runbook de implantação está caduco; o ensaio em `blmf-teste` continua por fazer (item **G3**).

**Os periódicos**

- *O que diz a documentação* — «spec enquadrada, não implementada — nove pacotes a entregar» — `spec-periodiques-v0.1`, 27/08
- *O que diz o banco ou o repositório* — **P1 a P9 entregues em 24 horas nos dias 27-28/08**: tabela `serials`, RPC, anti-falsos-duplicados, estado de coleção, Oficina, retomada, UI de catalogação, página pública, dez línguas. A spec venceu no dia seguinte à sua redação.

**Altcha — AR-3 e AR-4**

- *O que diz a documentação* — «🔴 a implementar» e «condição de entrada em serviço, não negociável» — `DECISION_anti_robots_2026-08-20`
- *O que diz o banco ou o repositório* — Função `altcha-challenge` implantada em 19/08, migração `20260820180000_altcha_anti_rejeu` aplicada em 20/08. Os dois estão feitos.

**O teto dos PDF, o vocabulário dos direitos, `api.resolve_reader_card`**

- *O que diz a documentação* — três itens abertos em `PLAN_DE_MARCHE` e `PLAN_formation_BLMF`
- *O que diz o banco ou o repositório* — `plafond_pdf_500mo_recueils_illustres`, `vocabulaire_rights_status` e `resolve_reader_card_motif_neutre` estão aplicadas desde 20 e 21/08. As três linhas estão caducas.

**Os crons ditos inativos**

- *O que diz a documentação* — «crons RGPD #6/#7 desativados — esclarecer» e «três crons inativos a decidir pela coordenação»
- *O que diz o banco ou o repositório* — **Os 36 jobs estão ativos.** `20260821070000_reactiver_crons_gouvernance` e `20260827080000_activer_cron_request_eval_digest` liquidaram a questão. Nenhuma decisão de coordenação está pendente.

**A duplicata `login` / `login-with-identifier` e a dupla assinatura de `fn_v2_set_reserva_linhas_workflow`**

- *O que diz a documentação* — duas entradas de dívida técnica reconduzidas de backlog em backlog
- *O que diz o banco ou o repositório* — `login-with-identifier` **não existe**. `fn_v2_set_reserva_linhas_workflow` tem **uma única assinatura**. Mais amplamente: não existe **nenhuma duplicata de assinatura** nos quatro esquemas aplicativos. As duas entradas estão caducas.

**As tabelas `_backup_*_20260408`**

- *O que diz a documentação* — «limpar 3 tabelas `_backup_*_20260408` + `book_authors_backup_suspect_mono`»
- *O que diz o banco ou o repositório* — Nenhuma existe em `public`. Em compensação **`backup_2026_05_07` (6 tabelas vazias) continua lá**, embora `BG2-9` prescreva sua purga desde junho (item **B9**).

### Declarado entregue, jamais exercido

**Sete blocos funcionais inteiros**

- *O que diz a documentação* — entregues, implantados, marcados ✅ no REGISTRO e nas specs
- *O que diz o banco ou o repositório* — **62 tabelas de negócio nunca receberam uma única inserção.** Assembleias da rede (3 tabelas), notas de leitura (2), propostas de autoridades (3), referenciais de catalogação `catalog_ref_*` (8 de 9), governança dos perfis de biblioteca (4 — enquanto **dois crons rodam sobre elas**), deliberação sobre os pedidos de adesão (5). O código existe; o uso não existe. É o item **G1**.

**O circuito de convite de equipe**

- *O que diz a documentação* — entregue: lotes 1, 2, 3a, 3b + função `notify-library-invitation` em dez línguas
- *O que diz o banco ou o repositório* — `library_team_invitations`: **0 linha**, uma única inserção histórica. O ajuste `team_admission_mode = 'cosignature'` da BLMF nunca teve efeito sobre nada. Ora, a migração de colegialidade faz desse circuito jamais exercido **o caminho crítico** de toda promoção.

**A acessibilidade**

- *O que diz a documentação* — painel de ajustes entregue em todas as páginas, `html lang` conforme WCAG 3.1.1
- *O que diz o banco ou o repositório* — Funcionalidades de acessibilidade estão implementadas. **Nenhuma auditoria de acessibilidade independente foi jamais conduzida.** Dizer um sem o outro seria uma falta (item **E1**).

**A coleta OAI-PMH**

- *O que diz a documentação* — caminho executável, função `harvest-oai-pmh` implantada, cron semanal posto
- *O que diz o banco ou o repositório* — O cron `anarbib-oai-harvest-weekly` **nunca rodou** (primeira ocorrência: terça-feira 04h20). `oai_harvest_state`: 9 inserções, 0 linha viva. O ponto de acesso OAI também nunca foi coletado de fora.

### Número ou afirmação falsos

**Os números de `CLAUDE.md`**

- *O que diz a documentação* — 200 migrações · 48 funções Edge · 6 154 chaves i18n · 36 declarações `verify_jwt` das quais 5 em `true` · `i18n.test.js` cobre 8 locales · 492 funções DEFINER
- *O que diz o banco ou o repositório* — 221 · 49 pastas para 48 implantadas · 6 177 · **31 declarações, todas em `false`, nenhuma em `true`** · **10 locales** desde 27/08 · 664. O mais grave é a linha `verify_jwt`: descreve uma proteção que não existe.

**O número de migrações, através do corpus**

- *O que diz a documentação* — 309 (10/06) → 128 (20/08) → 146 (`ETAT-AVANCEMENT`) → 221 (28/08)
- *O que diz o banco ou o repositório* — **221 aplicadas, 224 arquivos.** A série documental não é monótona: o número de 10 de junho é superior aos de dois levantamentos posteriores. Nunca retomar uma contagem de migrações a partir de um documento.

**`deploy/README.md`**

- *O que diz a documentação* — «Este documento descreve um estado a atingir, não um estado atingido. **Nada disso ainda rodou.**»
- *O que diz o banco ou o repositório* — Três commits de 26/08 descrevem execuções reais de `bootstrap.sh`, com oito defeitos levantados e corrigidos. O README está atrasado em relação aos seus próprios commits vizinhos (item **I8**).

**`spec-flux-consultations-v2.2` e `spec-gouvernance-roles` §14**

- *O que diz a documentação* — uma afirma três perfis de biblioteca «verificados em prod»; a outra lista como «a implementar» a auditoria, as colunas de carência, os e-mails `team.*` e dois crons
- *O que diz o banco ou o repositório* — A primeira é **falsa** (`BLT-test` não existe, a BTL está em `full_sigb`); a segunda **subestima** o que roda. Duas derivas de sentido inverso, levantadas no mesmo dia (itens **J3** e **J4**).

### Nunca escrito em lugar nenhum

**O esquema `ingest` não tinha RLS — mas nem por isso estava aberto**

- *O que diz a documentação* — nada — nenhum documento do corpus menciona o estado RLS de `ingest`
- *O que diz o banco ou o repositório* — **8 das 10 tabelas do esquema `ingest` não tinham RLS ativado**, entre elas `partner_catalog_staging_rows` (2 172 linhas) e `partner_catalog_row_to_draft` (2 084) — dados de bibliotecas de terceiros. O discurso «0 tabela sem RLS» é verdadeiro para `public` e nunca o foi para o banco inteiro. **Mas a verificação dos direitos, feita em seguida, corrigiu o diagnóstico**: `anon` e `authenticated` não têm sequer `USAGE` nesse esquema, e nenhuma de suas tabelas lhes concede o que quer que seja. Nada era alcançável. É uma lição de método tanto quanto de segurança: a ausência de RLS não diz nada sozinha, é preciso ler os direitos junto. Liquidado em 29/08 (item **B1**) como segundo ferrolho.

**Os 35 assuntos Solidaires estão no banco, a migração deles não**

- *O que diz a documentação* — «rodar `20260828_sujets_solidaires_ficedl.sql` e verificar 35 assuntos + 44 vínculos» — canteiro anunciado a fazer
- *O que diz o banco ou o repositório* — **35 assuntos foram criados no banco em 27/08** e os alinhamentos passaram de 51 para 98. Mas o arquivo continua em `docs/drafts/`, fora de `supabase/migrations/`. Uma instância nova, portanto, não terá esses assuntos. Item **C1**.

**A tabela mais volumosa do banco é a tabela de supervisão**

- *O que diz a documentação* — nada
- *O que diz o banco ou o repositório* — `service_health_probes`: **13 932 linhas**, +288 por dia, sem nenhum cron de purga — enquanto sete outras purgas existem. Item **I6**.

**Sete views do esquema `api` estão em SECURITY DEFINER**

- *O que diz a documentação* — o hook `pre-commit` proíbe no entanto todo `CREATE VIEW` sem `security_invoker = true`
- *O que diz o banco ou o repositório* — Sete views anteriores ao hook escapam: `collective_removal_proposals_current_v1`, `cooptation_proposals_current_v1`, `gazette_issues_public_v1`, `gazette_locales_public_v1`, `lettre_locales_public_v1`, `lettre_public_v1`, `library_email_identity`. Item **B3**.

---

## O calendário restrito

Três datas governam a janela atual, e duas delas são congelamentos. Não são negociáveis caso a caso: foram postas porque uma demonstração pública roda na produção.

| Data | O que se aplica |
|---|---|
| **até 14/09/2026** | Congelamento da cadeia de migração auto-hospedada **na produção**. Fora do perímetro, nominalmente: alinhamento da imagem GoTrue, primeira execução de `bootstrap.sh`, desacoplamento da CI, proxy reverso e túnel, qualquer modificação de `deploy/compose.yml` e do `Caddyfile`. O trabalho em ambiente de teste continua inteiramente aberto. |
| **a partir de 08/09/2026** | Nenhuma modificação de código em produção. |
| **11-13/09/2026** | FICEDL Bolonha. Oficina AnarBib no dia 12 pela manhã, assembleia aberta no dia 13. |
| **a partir de 14/09/2026** | Descongelamento. O domínio I volta a ser o canteiro principal. |

Um item marcado **congelado** não é um item morto: é um item cuja data de retomada está escrita.

---

## Dez regras pagas por um incidente

Estas regras não são preferências. Cada uma foi paga por um incidente cujo rastro existe em `docs/journal/`.

1. **O único caminho de implantação é `git push` → integração contínua.** Nunca `apply_migration` por MCP, nunca o editor SQL, nunca a CLI direto. Uma migração aplicada à mão quebra a CI para todo mundo: `supabase db push` recusa assim que vê uma versão ausente do repositório. *(REGISTRO `DOC-DEPLOY-1` e `-3`)*
2. **Nunca misturar documentação e código num mesmo push.** Em 26/08, um push misto não disparou nenhum workflow e uma migração não foi aplicada, **sem nenhum vermelho**. Verificar no banco depois de todo push que deveria aplicar uma migração. *(REGISTRO `GOUV-9`)*
3. **Toda migração que cria uma tabela em `public` quebra o backup seguinte** enquanto a tabela não estiver inscrita em `deploy/bg2-known-tables.txt`. A migração e os arquivos de operação andam juntos. A falha é silenciosa: `altcha_consumed_challenges` fez todos os backups falharem durante 36 horas.
4. **Entregar correções completas testadas num clone limpo, ou arquivos inteiros.** Nunca «substitua a linha 42».
5. **Dez locales numa só passagem.** Uma chave acrescentada em uma só língua quebra o build, e isso é intencional. *(REGISTRO `DOC-I18N-1`)*
6. **Nunca um segredo no repositório.** `deploy/.env` e `deploy/functions.env` são ignorados pelo git; a `SERVICE_ROLE_KEY` não tem lugar nem no repositório, nem no front, nem numa mensagem.
7. **O runner de integração contínua vive na máquina do mantenedor.** Máquina desligada, nada se implanta. Não é uma pane, é o estado do projeto — e é o item **A3**.
8. **Antes de toda sessão, buscar o estado do repositório remoto.** Em 28/08, um clone atrasado em 26 commits produziu a conclusão falsa de que onze migrações rodavam em produção sem existir no repositório.
9. **Três famílias de tarefas não se automatizam**: as três tabelas de revisão do esquema `conv_backup`, a revisão dos duplos sobrenomes hispânicos (14 % de falsos positivos medidos), e a triagem dos subtítulos e diacríticos. Toda proposta de mecanizá-las é uma regressão documental.
10. **Antes de inscrever uma lacuna, procurar a fonte que a desmente.** De sete erros analisados em `PLAN_DE_MARCHE`, quatro vinham de uma fonte não lida.

---

## Os canteiros

**Identificador** = letra de domínio + número. Os números nunca são reutilizados. **Prioridade**: `P0` Estrutural · `P1` Prioritário · `P2` Corrente · `P3` Adiado.

- `P0` **Estrutural** — O projeto continua frágil enquanto isso não for feito. Nenhum código substitui.
- `P1` **Prioritário** — Corrige um defeito real, ou desbloqueia vários outros canteiros.
- `P2` **Corrente** — Útil, não bloqueante, a pegar quando abrir uma janela.
- `P3` **Adiado** — Adiado deliberadamente, com o motivo escrito. Não retomar sem reabrir o motivo.

### A — Sustentabilidade coletiva

*O que nem o código nem uma só pessoa vão resolver. Este domínio vem antes de todos os outros.*

| | | | |
|---|---|---|---|
| **A1** | Obter pelo menos duas outras pessoas administradoras de rede | `P0` | Decisão coletiva |
| **A2** | Testar a reconstrução completa por outra pessoa que não o mantenedor | `P0` | Aberto |
| **A3** | Tirar o runner de integração contínua da máquina do mantenedor | `P0` | Aberto |
| **A4** | Escrever uma porta de entrada para quem quer ajudar sem saber programar | `P1` | Aberto |

#### A1 — Obter pelo menos duas outras pessoas administradoras de rede

`P0` Estrutural · Estado : **Decisão coletiva** · Carga : não estimado · O que exige : deliberação coletiva, nenhuma competência técnica

**Estado verificado em 29/08.** Verificado no banco em 29/08: a rede conta com **um único administrador**. As tabelas `network_administrators`, `network_administrator_cooptation_proposals` e `network_administrator_cooptation_votes` estão vazias após algumas inserções históricas.

**O que é.** Encontrar e cooptar mais duas pessoas, em dois coletivos diferentes, dispostas a carregar as decisões federais: admissão de uma biblioteca, arbitragem entre bibliotecas, abertura da coleta.

**Por que importa.** É o item que comanda todos os outros. Decisões federais são **deliberadamente adiadas** por não poderem ser tomadas em conjunto — a admissão da Biblioteca SOLIDAIRES em primeiro lugar. Enquanto houver uma só pessoa, o mecanismo de cooptação continua um dispositivo sem uso, e a rede continua suspensa a alguém que pode adoecer.

**O que conta como terminado.**

- Duas pessoas a mais carregam o papel `network_administrator` no banco.
- Uma decisão federal foi tomada em três, de ponta a ponta, com seu rastro em `network_administrator_audit`.
- O circuito de cooptação foi percorrido pelo menos uma vez: proposta, prazo, ratificação.

**Dependências.** Bloqueia **G7** (decisão sobre SOLIDAIRES) e condiciona **A2**.

*Remissões : `docs/CHANTIERS_OUVERTS.md §7` · `REGISTRE §1 RES-D11` · `CALENDRIER_bologne_2026-08-27`*

#### A2 — Testar a reconstrução completa por outra pessoa que não o mantenedor

`P0` Estrutural · Estado : **Aberto** · Carga : alguns dias · O que exige : administração de sistemas, SQL / PostgreSQL, React / JavaScript

**Estado verificado em 29/08.** Nunca feito. `deploy/README.md`, `deploy/REPETITION.md` e `deploy/bootstrap.sh` existem e foram executados — **apenas na máquina do mantenedor**.

**O que é.** Clonar o repositório numa máquina de terceiro, subir a pilha completa seguindo `deploy/README.md`, e escrever o que quebra. Nenhum segredo, nenhum acesso, nenhuma coordenação: a pilha se reconstrói a partir do repositório sozinho. Docker, uma máquina, uma noite.

**Por que importa.** É a resposta à única pergunta que decide todo o resto: *este projeto é retomável por outra pessoa além de quem o escreveu?* Um relatório de falha detalhado vale aqui mais que uma correção: é a lista do que só funciona numa única máquina.

**O que conta como terminado.**

- A pilha sobe numa máquina que nunca viu o projeto, seguindo apenas a documentação.
- Cada divergência entre a documentação e a realidade é registrada, com seu comando e sua mensagem de erro.
- O diário de execução vira uma seção de `deploy/README.md`.

**Dependências.** Nenhuma. **É o melhor primeiro passo para quem chega.**

*Remissões : `docs/CHANTIERS_OUVERTS.md §1` · `deploy/REPETITION.md`*

#### A3 — Tirar o runner de integração contínua da máquina do mantenedor

`P0` Estrutural · Estado : **Aberto** · Carga : várias semanas · O que exige : administração de sistemas

**Estado verificado em 29/08.** `.forgejo/workflows/ci.yml` e `sql-tests.yml` trazem ambos `runs-on: anarbib-local` — um `act_runner` auto-hospedado no WSL2 do mantenedor. Máquina desligada, **nada se implanta**, e a falha às vezes é silenciosa.

**O que é.** Rodar o runner em outro lugar que não uma estação de trabalho pessoal: máquina do provedor, segunda máquina da rede, ou runner compartilhado. A lógica de implantação já está extraída em `scripts/ci/deployer-backend.sh` e é reexecutável à mão — metade do trabalho está feita.

**Por que importa.** Enquanto o runner for único e pessoal, nenhum procedimento pode tornar a implantação confiável, e ninguém mais pode integrar uma contribuição. É a segunda metade da dependência de uma só pessoa, depois de **A1**.

**O que conta como terminado.**

- Um push em `main` dispara uma implantação sem que a máquina do mantenedor esteja ligada.
- A guarda de exclusão do roteador `main` é preservada nos dois lugares (workflow e script).
- O procedimento de recolocação do runner em funcionamento está escrito para quem não o instalou.

**Dependências.** Ligado a **I2** (migração auto-hospedada). Pode ser feito antes, na infraestrutura atual.

*Remissões : `CLAUDE.md, piège connu n°1` · `REPRISE_bascule_autohebergee_2026-08-26`*

#### A4 — Escrever uma porta de entrada para quem quer ajudar sem saber programar

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado verificado em 29/08.** `CONTRIBUTING.md` (28/08) se dirige a quem programa: fork, branch, `npm ci`, prefixos de commit. `docs/CHANTIERS_OUVERTS.md` faz melhor e sinaliza três entradas sem competência técnica, mas continua guardado numa pasta `docs/`.

**O que é.** Uma página curta, no topo do repositório e em anarbib.org, dizendo o que se pode fazer pelo AnarBib **sem escrever uma linha de código**: revisar uma língua, indexar assuntos, exercer um papel de administração de rede, testar uma reconstrução, revisar uma convenção. Cada entrada com o que exige e para quem escrever.

**Por que importa.** Os três canteiros mais úteis do projeto hoje — administradores·as de rede, convenções neerlandesa e grega, indexação de assunto — não exigem **nenhuma competência técnica**. Uma porta de entrada que fala de `npm ci` os torna invisíveis.

**O que conta como terminado.**

- Uma página existe, em francês e português no mínimo.
- É alcançável a partir de anarbib.org e da raiz do repositório.
- Nomeia um endereço de contato real por entrada.

**Dependências.** Útil antes de Bolonha (**K5**): é lá que o chamado se faz.

*Remissões : `CONTRIBUTING.md` · `docs/CHANTIERS_OUVERTS.md`*

---

### B — Banco de dados, segurança, RLS

*187 tabelas, 664 funções SECURITY DEFINER, 279 policies. A maior superfície do projeto.*

| | | | |
|---|---|---|---|
| **B2** | Triar as 142 funções `SECURITY DEFINER` do esquema `api` | `P1` | Aberto |
| **B3** | Passar as sete views `api` que continuam em SECURITY DEFINER | `P1` | Aberto |
| **B4** | Examinar as quatro tabelas com RLS sem policy que não são de trânsito | `P2` | Aberto |
| **B5** | Resolver as nove policies que reavaliam `auth.*()` por linha | `P2` | Aberto |
| **B6** | Reconciliar `config.toml` com as 48 funções realmente implantadas | `P1` | Aberto |
| **B7** | Desambiguar os homônimos de funções entre `ingest` e `public` | `P2` | Aberto |
| **B8** | Desambiguar as views que existem em duplicata entre `public` e `api` | `P2` | Aberto |
| **B9** | Purgar o esquema `backup_2026_05_07` | `P2` | Aberto |
| **B10** | Higiene de performance: 170 índices não usados, 38 chaves estrangeiras não indexadas, 24 policies permissivas duplicadas | `P3` | Aberto |
| **B11** | Compreender `user_wishlist`: uma linha viva para 9 092 inserções | `P2` | A verificar |
| **B12** | Elucidar as três ações críticas interbibliotecas que ficaram em `skipped` | `P2` | A verificar |
| **B13** | Decidir o destino das 221 migrações: squash ou não | `P3` | Aberto |

#### B2 — Triar as 142 funções `SECURITY DEFINER` do esquema `api`

`P1` Prioritário · Estado : **Aberto** · Carga : várias semanas · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** A auditoria de 20/08 revisou as funções de `public` uma a uma e fechou cinco falhas reais. **Não abrangia `api`.** O esquema `api` conta 184 funções das quais **142 em `SECURITY DEFINER`**, todas chamáveis pelo papel `authenticated` via `/rest/v1/rpc/`.

**O que é.** Retomar o critério de auditoria já estabelecido — *o que ela retorna, a partir de qual parâmetro, e o que impede um terceiro de pedi-lo?* — e aplicá-lo às 142. Procurar `auth.uid()` no corpo não prova nada.

**Por que importa.** É a metade não auditada da superfície de API do projeto. As cinco falhas encontradas em `public` eram oráculos — número para e-mail, identificador para nome — e nada diz que `api` não carregue outros.

**O que conta como terminado.**

- As 142 funções têm um veredicto escrito: legítima, a restringir, ou a suprimir.
- As funções a restringir perderam seu `EXECUTE` por migração.
- O relatório vive em `docs/journal/audits/`, no formato do de 20/08.
- Atenção: cinco funções carregam 106 policies RLS e **nunca** devem perder seu `EXECUTE`, inclusive `anon`.

**Dependências.** Faz-se por lotes. Um lote de vinte funções já é útil.

*Remissões : `PLAN_DE_MARCHE §8` · `PLAN_DE_MARCHE règle 13.3` · `AUDIT_securite_fonctions_privees_2026-05-18`*

#### B3 — Passar as sete views `api` que continuam em SECURITY DEFINER

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** 61 das 68 views de `api` trazem `security_invoker = true`. Sete não têm: `collective_removal_proposals_current_v1`, `cooptation_proposals_current_v1`, `gazette_issues_public_v1`, `gazette_locales_public_v1`, `lettre_locales_public_v1`, `lettre_public_v1`, `library_email_identity`. O hook `pre-commit` proíbe no entanto desde maio toda view nova sem esse atributo.

**O que é.** Para cada uma: verificar o que a view expõe, decidir se o atributo ausente é um esquecimento ou uma escolha, depois ou pôr `security_invoker = true` por migração, ou escrever por que ela deve permanecer em DEFINER.

**Por que importa.** Uma view `security_invoker = false` contorna as policies RLS de suas tabelas de origem: é exatamente a mesma armadilha da policy ausente. `library_email_identity` é a mais preocupante — carrega a palavra «identity» e a palavra «email».

**O que conta como terminado.**

- As sete views têm um veredicto escrito e aplicado.
- O hook `pre-commit` cobre também `CREATE OR REPLACE VIEW`.
- Um teste SQL verifica que nenhuma view de `api` está em DEFINER sem derrogação nomeada.

**Dependências.** Independente de **B2**, mesma família de risco.

*Remissões : `Relevé du 29/08/2026` · `PLAN_DE_MARCHE règle 13.2`*

#### B4 — Examinar as quatro tabelas com RLS sem policy que não são de trânsito

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** 15 tabelas têm RLS ativado e zero policy. Onze são tabelas de trânsito ou vazias. Quatro não são: `author_name_aliases` (**1 647 linhas**), `library_themes` (3 linhas), `library_theme_configs`, `interlibrary_loan_events`.

**O que é.** Para cada uma, decidir: ou o acesso passa por uma RPC e a ausência de policy está correta — escrevê-lo em comentário SQL —, ou uma leitura legítima é hoje impossível e falta uma policy ou uma função.

**Por que importa.** Uma tabela com RLS e sem policy está fechada para todos exceto para as funções `DEFINER`. Às vezes é exatamente o que se quer, e às vezes é uma funcionalidade que não funciona sem que ninguém tenha percebido — `author_name_aliases` carrega 1 647 linhas que talvez nada leia.

**O que conta como terminado.**

- As quatro tabelas têm um veredicto escrito.
- O controle de restauração do runbook lista nominalmente as tabelas sem policy esperadas.

**Dependências.** Nenhuma.

*Remissões : `PLAN_DE_MARCHE §8` · `MATRICE_rls_deny_all_2026-06-23`*

#### B5 — Resolver as nove policies que reavaliam `auth.*()` por linha

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** A migração `20260703203953_perf_rls_initplan_wrap_auth_calls` tratou as policies de então. Nove policies escritas desde então escapam: `book_reading_notes` (4), `book_reading_note_reports` (2), `catalog_duplicate_reports` (1), `authority_duplicate_reports` (1), `author_not_duplicate` (1).

**O que é.** Envolver as chamadas `auth.uid()` / `auth.jwt()` num sub-select, como a migração de julho fez para as outras.

**Por que importa.** Sem esse envolvimento, a função é chamada uma vez por linha examinada. As cinco tabelas envolvidas estão vazias hoje, então o custo é nulo — e é precisamente o bom momento para corrigir, antes que as notas de leitura sirvam.

**O que conta como terminado.**

- O lint `auth_rls_initplan` não retorna mais nenhum aviso.
- O padrão de envolvimento é lembrado no modelo de migração.

**Dependências.** Nenhuma.

*Remissões : `Advisors performance, relevé du 29/08/2026`*

#### B6 — Reconciliar `config.toml` com as 48 funções realmente implantadas

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : Deno / TypeScript, administração de sistemas

**Estado verificado em 29/08.** `supabase/config.toml` traz **31 seções `[functions.*]`, todas em `verify_jwt = false`, nenhuma em `true`**. Os comentários do arquivo anunciam «17 em `false` e 6 em `true`»; `CLAUDE.md` anuncia «36 das quais 5 em `true`». Os três se contradizem, e **18 das 48 funções implantadas não estão declaradas de forma alguma**.

**O que é.** Estabelecer a lista real das 48 funções e, para cada uma, o que deve protegê-la: JWT da plataforma, segredo de webhook, ou nada porque é pública por natureza. Escrever essa lista em `config.toml` e corrigir os comentários e o `CLAUDE.md`.

**Por que importa.** É a única linha da documentação que descreve uma proteção **que não existe**. As 18 funções não declaradas dependem do comportamento padrão da plataforma — um comportamento que desaparecerá no dia da migração auto-hospedada, onde é o roteador `main` que decidirá, em recusa por omissão.

**O que conta como terminado.**

- `config.toml` declara as 48 funções implantadas, sem exceção.
- Cada `verify_jwt = false` traz uma linha de comentário dizendo o que protege a função no lugar.
- O roteador `main` foi relido contra essa lista.

**Dependências.** Pré-requisito de **I3** (teste do roteador `main`).

*Remissões : `Relevé du 29/08/2026` · `deploy/README.md` · `supabase/functions/main/index.ts`*

#### B7 — Desambiguar os homônimos de funções entre `ingest` e `public`

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** Quatro nomes de função existem nos dois esquemas com assinaturas e semânticas diferentes: `fn_bulk_create_book_drafts_from_run`, `fn_bulk_set_partner_catalog_editorial_decision`, `fn_set_partner_catalog_editorial_decision`, e `set_updated_at()`. Nenhuma duplicata de assinatura num mesmo esquema — o problema é o nome compartilhado.

**O que é.** Verificar qual das duas é chamada pelo front e pelas RPC, renomear a que não é, ou suprimir a versão morta. `set_updated_at()` é um trigger banal e pode ficar.

**Por que importa.** Um `search_path` que muda de ordem basta para chamar a outra função, com parâmetros que não correspondem. É uma pane difícil de diagnosticar, e o projeto já pagou uma vez por um `search_path` mal fixado.

**O que conta como terminado.**

- As três funções de negócio homônimas estão desambiguadas.
- Nenhuma depende da ordem do `search_path` para ser resolvida corretamente.

**Dependências.** Nenhuma.

*Remissões : `Relevé du 29/08/2026`*

#### B8 — Desambiguar as views que existem em duplicata entre `public` e `api`

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** Quatro pares de views homônimas ou quase: `public.my_access` / `api.my_access`, `public.my_session_context` / `api.my_session_context`, `public.v_library_service_public` / `api.library_service_public`, `public.v_book_detail_public_v2` / `api.catalog_book_detail_public_v2`. E em `public`, `catalog_partners_policy_flags` coexiste com `catalog_partners_policy_flags_v2`.

**O que é.** Verificar qual é lida pelo front — o esquema exposto pelo PostgREST é `public,api,storage` — e suprimir as outras, ou explicitar que a view `public` é a base e a view `api` a exposição.

**Por que importa.** Duas views do mesmo nome em dois esquemas ambos expostos pelo PostgREST é uma ambiguidade na chamada. E uma view `_v2` que nunca substituiu sua `v1` é código morto que se parece com código vivo.

**O que conta como terminado.**

- Cada par tem um veredicto: base + exposição assumidas, ou supressão da morta.
- A view `_v2` substituiu a antecessora, ou o contrário.

**Dependências.** Nenhuma.

*Remissões : `Relevé du 29/08/2026`*

#### B9 — Purgar o esquema `backup_2026_05_07`

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** Seis tabelas, **todas com zero linha e zero inserção desde a criação**, sem chave primária, sem RLS: `emprestimos_v2`, `emprestimo_itens_v2`, `reservas_v2`, `reserva_linhas_v2`, `reserva_item_workflow_v2`, `loan_midpoint_message_log`. A decisão `BG2-9` prescreve essa purga desde junho.

**O que é.** `DROP SCHEMA backup_2026_05_07 CASCADE` por migração, após confirmar uma última vez que as seis tabelas estão vazias.

**Por que importa.** Seis tabelas de backup vazias poluem cada levantamento de advisors — carregam sozinhas seis dos catorze avisos «sem chave primária». E um esquema chamado `backup_` que não contém nada é uma armadilha para quem retomar o projeto.

**O que conta como terminado.**

- O esquema não existe mais.
- `deploy/bg2-known-tables.txt` foi atualizado no mesmo movimento.

**Dependências.** Não confundir com `conv_backup`, que carrega dados de revisão humana e **não se purga** (ver **C4**).

*Remissões : `REGISTRE §BG2 BG2-9`*

#### B10 — Higiene de performance: 170 índices não usados, 38 chaves estrangeiras não indexadas, 24 policies permissivas duplicadas

`P3` Adiado · Estado : **Aberto** · Carga : alguns dias · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** 256 avisos de performance em 29/08. As tabelas mais carregadas de índices não usados são `library_partnerships` (6), `books` (5), `membership_payments` (4). As 24 policies permissivas duplicadas incidem todas sobre o papel `authenticated` em `SELECT`, em tabelas centrais (`books`, `authors`, `exemplares`, `subjects`, `works`).

**O que é.** Três passagens distintas, a não misturar: fundir os pares de policies permissivas; indexar as chaves estrangeiras que realmente servem; só suprimir um índice não usado se se compreender por que foi criado.

**Por que importa.** Na volumetria atual — 2 676 registros, 16 contas — **nada disso se vê**. É um canteiro de pré-crescimento, adiado de propósito desde julho. Anotá-lo permite não redescobri-lo às pressas no dia em que uma biblioteca chegar com 100 000 registros.

**O que conta como terminado.**

- Os 24 avisos de policies duplicadas estão resolvidos — é a passagem mais rentável.
- As chaves estrangeiras das tabelas realmente escritas estão indexadas.
- Os índices suprimidos o são com o motivo escrito.

**Dependências.** A retomar se uma biblioteca de grande acervo entrar na rede.

*Remissões : `ETAT-lancement-consolide-2026-07-03 §2 item 7` · `Advisors performance du 29/08/2026`*

#### B11 — Compreender `user_wishlist`: uma linha viva para 9 092 inserções

`P2` Corrente · Estado : **A verificar** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** A tabela `public.user_wishlist` carrega **1 linha viva** para **9 092 inserções acumuladas**. É a relação escrita/exclusão mais extrema do banco, por duas ordens de grandeza.

**O que é.** Encontrar o que escreve e apaga: um teste reexecutado, um carregamento de página que insere e depois cancela, um componente React que chama a RPC a cada renderização. Olhar `OPAC-W1`, cuja nota diz «resta `WITH CHECK`».

**Por que importa.** Nove mil escritas para uma linha não é um uso: é um laço. Custa pouco hoje e custará exatamente o mesmo por usuária no dia em que houver cem.

**O que conta como terminado.**

- A causa está identificada e escrita.
- Se for um laço do front, está corrigido; se for um teste, a linha é retirada da constatação.

**Dependências.** Nenhuma.

*Remissões : `REGISTRE §18 OPAC-W1` · `Relevé du 29/08/2026`*

#### B12 — Elucidar as três ações críticas interbibliotecas que ficaram em `skipped`

`P2` Corrente · Estado : **A verificar** · Carga : uma noite · O que exige : SQL / PostgreSQL, Deno / TypeScript

**Estado verificado em 29/08.** Três linhas de `network.cross_library_critical_action` estão em `status = 'skipped'` desde 08/06/2026, com `attempts = 1`, `last_error` nulo e um `pg_net_request_id` presente. O apontamento é de 26/08 e não foi instruído.

**O que é.** Cruzar os `pg_net_request_id` com os logs de `notify-event` para saber se a chamada saiu, se falhou, ou se foi deliberadamente ignorada. Depois decidir: reexecutar, ou encerrar com o motivo.

**Por que importa.** Estas linhas rastreiam ações de administração de rede que tocam uma biblioteca diferente da pessoa que age. Um status `skipped` sem erro é ou uma notificação que nunca saiu, ou um rastro mal registrado. Ambos merecem ser sabidos.

**O que conta como terminado.**

- As três linhas têm uma explicação escrita.
- Se o mecanismo pode pular uma notificação em silêncio, está corrigido.

**Dependências.** Ligado a **F1** (auditoria da cadeia de e-mail).

*Remissões : `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §4`*

#### B13 — Decidir o destino das 221 migrações: squash ou não

`P3` Adiado · Estado : **Aberto** · Carga : várias semanas · O que exige : SQL / PostgreSQL, administração de sistemas

**Estado verificado em 29/08.** 221 migrações aplicadas, das quais a primeira é um `baseline_live` de **2,4 MB** — o maior arquivo do repositório. O squash está marcado «decidido, não iniciado» desde 20/08, numa época em que a contagem era de 146.

**O que é.** Ou reconstruir um `baseline` a partir do esquema atual e arquivar as migrações anteriores, ou assumir a cadeia longa e documentar por quê. A reexecução completa leva hoje cerca de 25 minutos, medido.

**Por que importa.** O risco do squash é inteiro: reescreve o único rastro ordenado do que foi feito, e o arnês de testes SQL reexecuta toda a cadeia a cada vez. Não fazê-lo custa tempo de CI; fazê-lo mal custa a capacidade de reconstruir. **Não se comprometer antes que A2 tenha sido bem-sucedido pelo menos uma vez.**

**O que conta como terminado.**

- Uma decisão escrita no REGISTRO, num sentido ou no outro.
- Se squash: a reconstrução a partir do novo baseline foi testada numa máquina de terceiro.

**Dependências.** **Bloqueado por A2.** Não começar antes.

*Remissões : `ETAT-AVANCEMENT-multisessions` · `docs/schema/baseline_schema_2026-06-11.sql`*

---

### C — Catalogação e dados documentais

*A dívida aqui não é de código: são fichas para revisar uma a uma.*

| | | | |
|---|---|---|---|
| **C1** | Fazer os 35 assuntos SOLIDAIRES entrarem nas migrações | `P1` | Aberto |
| **C2** | Importar o acervo SOLIDAIRES pela ferramenta de importação, e registrar o que quebra | `P1` | Bloqueado |
| **C3** | Conduzir a revisão humana das autoridades: sobrenomes, caixa, títulos | `P1` | Aberto |
| **C4** | Preencher os países ausentes em 722 fichas de autoridade | `P2` | Aberto |
| **C5** | Decidir o destino do campo livre `books.autor` | `P2` | Decisão coletiva |
| **C6** | Entregar as três assistências de digitação previstas pela spec das convenções | `P2` | Aberto |
| **C7** | Indexar por assunto os 1 549 registros que não têm nenhum assunto | `P2` | Aberto |
| **C8** | Enriquecer as autoridades: datas, identificadores externos, formas variantes | `P3` | Aberto |
| **C9** | Fechar as oito questões abertas das convenções catalográficas | `P2` | Decisão coletiva |
| **C10** | Renomear uma das duas colunas `rights_status` | `P2` | Aberto |

#### C1 — Fazer os 35 assuntos SOLIDAIRES entrarem nas migrações

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL, biblioteconomia

**Estado verificado em 29/08.** Verificado em 29/08: **35 assuntos foram criados no banco em 27/08** e os alinhamentos FICEDL passaram de 51 para **98**. Mas `docs/drafts/20260828_sujets_solidaires_ficedl.sql` continua em `docs/drafts/`, fora de `supabase/migrations/`. Uma instância nova, portanto, não terá esses assuntos.

**O que é.** Comparar o conteúdo do rascunho ao estado real do banco, transformá-lo numa migração idempotente que não recrie o que existe, e guardá-la em `supabase/migrations/`. Ou decidir que esses assuntos são próprios de uma biblioteca e não devem embarcar — mas escrevê-lo.

**Por que importa.** É exatamente a questão decidida em 26/08 para o tesauro FICEDL: o vocabulário federal embarca, os assuntos locais e seu alinhamento não embarcam, porque são o acervo e o ato de cada coletivo. Se essa regra vale aqui, é preciso dizê-lo; senão, a migração falta. Nos dois casos, o desvio entre `docs/drafts/` e o banco é uma dívida de rastreabilidade.

**O que conta como terminado.**

- `docs/drafts/20260828_sujets_solidaires_ficedl.sql` desapareceu: ou virou migração, ou foi arquivado com o motivo.
- A contagem de controle está escrita: 89 assuntos, 98 alinhamentos em 29/08.
- Lembrete: `subject_ficedl_links.match_type` só aceita `exact` e `close` — não existe `broad`.

**Dependências.** Ligado a **C2** (importação do acervo SOLIDAIRES).

*Remissões : `REPRISE_claude_code_2026-08-27 chantier 2` · `REGISTRE §30 THES`*

#### C2 — Importar o acervo SOLIDAIRES pela ferramenta de importação, e registrar o que quebra

`P1` Prioritário · Estado : **Bloqueado** · Carga : alguns dias · O que exige : biblioteconomia, SQL / PostgreSQL

**Estado verificado em 29/08.** 1 685 registros em `SOLIDAIRES_import_test.csv`. Os cabeçalhos seguem `spec-catalogacao-fiche-et-paliers` e **nunca foram confrontados com o importador**. **Decisão de Xavier, 29/08: a importação só se fará se a candidatura da SOLIDAIRES for aceita por várias pessoas administradoras de rede.** O prazo de fim de agosto cai, portanto, e a ordem dos dois canteiros se inverte em relação às notas de agosto: a admissão primeiro, a importação depois.

**O que é.** Adaptar os cabeçalhos ao formato realmente esperado (cerca de uma hora), passar o arquivo **pela ferramenta de importação do repositório e não por `INSERT` à mão**, revisar umas vinte fichas ao acaso, e depois fazer uma demonstração em videoconferência com tela compartilhada.

**Por que importa.** O objetivo continua sendo tanto testar o importador quanto obter os registros: **a entrega mais útil do canteiro é a lista do que quebra, do que é mal adivinhado e do que se perde** — não as 1 685 fichas. Mas fazer entrar um acervo antes de a rede ter dito sim equivaleria a decidir pelo fato o que se diz querer decidir em conjunto. É o mesmo raciocínio que proibia criar a ficha de biblioteca; estende-se agora ao próprio lote.

**O que conta como terminado.**

- **A admissão foi pronunciada em conjunto (G7) antes de o arquivo ser tocado.**
- O lote passou pela ferramenta de importação do repositório, não por `INSERT` à mão.
- Um relatório escrito diz o que quebrou, linha por linha quando possível.
- Vinte fichas sorteadas ao acaso foram revisadas.
- **Nenhum erro de acento da fonte foi corrigido em silêncio**: as correções vivem em `assunto_local_sugerido`.

**Dependências.** **Bloqueado por G7**, ele mesmo bloqueado por **A1**. Nada se move enquanto a rede tiver um único administrador.

*Remissões : `REPRISE_claude_code_2026-08-27 chantier 2` · `CALENDRIER_bologne_2026-08-27`*

#### C3 — Conduzir a revisão humana das autoridades: sobrenomes, caixa, títulos

`P1` Prioritário · Estado : **Aberto** · Carga : várias semanas · O que exige : biblioteconomia

**Estado verificado em 29/08.** As 19 migrações `conventions_*` estão aplicadas desde 21/08: os referenciais estão normalizados, as mecânicas seguras foram passadas, a fila de verificação existe e o aplicativo permite trabalhar nela. **O que resta é a parte que nenhuma máquina faz.**

**O que é.** Retomar as três tabelas de revisão do esquema `conv_backup` — `titres_a_revoir_20260820` (211), `autorites_casse_a_revoir_20260820` (1 274), `autorites_patronyme_a_revoir_20260820` (22) — e tratá-las ficha por ficha a partir da Oficina de autoridades.

**Por que importa.** Dos 22 duplos sobrenomes hispânicos apontados automaticamente, **três são falsos positivos conhecidos** (Mechoso, Borges, Marcos): 14 % de erro. E dos 13 pontos de acesso sobre partícula, **quatro estão corretos** (Van der Walt, De Amicis, Di Paolo, De Greef). Um script que «terminasse» esse trabalho introduziria erros num catálogo que não os tem.

**O que conta como terminado.**

- As três tabelas são esvaziadas por validação humana, não por script.
- **Proibição absoluta**: descomentar o SQL de aplicação, completá-lo, ou passar `valide = true` em massa.
- Os 9 pontos de acesso postos sobre um sufixo de filiação — tipo `FILHO, Fábio Luz` — são tratados primeiro: a auditoria os dá como **o defeito mais grave do lote**.

**Dependências.** Faz-se no aplicativo, sem migração. É um canteiro de biblioteconomia, aberto a quem sabe catalogar.

*Remissões : `AUDIT_conventions_catalographiques_2026-08-20` · `REGISTRE §37 CONV`*

#### C4 — Preencher os países ausentes em 722 fichas de autoridade

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia

**Estado verificado em 29/08.** **722 fichas de 1 305 (55 %) não têm `country`.** Ora, é `country` que comanda a regra de entrada do nome: sem ele, a detecção dos duplos sobrenomes hispânicos só vê uma fração dos casos. Os 22 apontamentos são um **piso**, não um total.

**O que é.** Preencher `country` por lotes, a partir dos registros, das fontes externas já conectadas (Wikidata, VIAF) e do conhecimento do acervo. Depois reexecutar a detecção dos sobrenomes.

**Por que importa.** É o pré-requisito duro de toda a cadeia de convenções: `CONV-7` faz de `country` em ISO 3166-1 α-2 uma condição, e `CONV-3` faz a caixa ser comandada pela língua. Um catálogo com 55 % sem país aplica as próprias regras pela metade.

**O que conta como terminado.**

- A proporção de fichas sem `country` caiu abaixo de 20 %.
- A detecção dos duplos sobrenomes foi reexecutada e a nova lista passou por revisão humana.

**Dependências.** Pré-requisito da segunda passagem de **C3**.

*Remissões : `AUDIT_conventions_catalographiques_2026-08-20 A5` · `REGISTRE §37 CONV-7`*

#### C5 — Decidir o destino do campo livre `books.autor`

`P2` Corrente · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : biblioteconomia, SQL / PostgreSQL

**Estado verificado em 29/08.** `CONV-O3` está aberto: depreciar `books.autor` agora, ou na Oficina? O campo coexiste com a tabela `authors` e carrega os mesmos defeitos **piores** — encontram-se lá `identificado, Não`, `REICH, Hilhem`, `Rosamund Bartlett (Org.)`. A auditoria de 20/08 o deixou explicitamente fora do perímetro: sua dívida não está quantificada.

**O que é.** Primeiro quantificar: quantos registros têm um `autor` sem contribuidor vinculado, e como é o conteúdo. Depois decidir: depreciação imediata com migração dos valores recuperáveis, ou conservação como forma transcrita no sentido do `P3` dos periódicos.

**Por que importa.** Duas verdades concorrentes sobre o autor de um livro é o contrário de `DOC-CONV-1` («uma só verdade no banco, várias renderizações»). Enquanto o campo viver, cada tela precisa escolher qual exibir, e os dois divergem.

**O que conta como terminado.**

- A dívida está quantificada.
- Uma decisão está inscrita no REGISTRO, num sentido ou no outro.
- Se depreciação: o campo não é mais escrito por nenhum formulário.

**Dependências.** Remete a `INV-4`.

*Remissões : `REGISTRE §37 CONV-O3` · `AUDIT_conventions_catalographiques_2026-08-20`*

#### C6 — Entregar as três assistências de digitação previstas pela spec das convenções

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript, biblioteconomia

**Estado verificado em 29/08.** O banco sabe normalizar; a interface de digitação ainda não assiste. Três dispositivos estão especificados e não entregues: o assistente de separação do nome (§7.1), o botão «Normalizar maiúsculas» com pré-visualização (§7.2), e a fila de controles de coerência em segundo plano (§7.3).

**O que é.** Três telas, nesta ordem de valor: o botão de normalização de caixa (o mais simples, ativo só se a língua estiver preenchida); o assistente de separação, que propõe palavra por palavra com um botão «Corrigir» e uma explicação de uma linha; a fila de controles, que sinaliza sem bloquear.

**Por que importa.** É a restrição de concepção mais firme do projeto: **toda regra deve ser ou invisível porque calculada, ou assistida porque proposta e confirmada, nunca um saber prévio exigido na digitação.** As pessoas que catalogam não são bibliotecárias nem informáticas. Sem essas três telas, as convenções continuam uma doutrina que só seu autor sabe aplicar.

**O que conta como terminado.**

- Os três dispositivos existem e **nenhum é bloqueante**.
- Cada proposta é recusável, com o original conservado.
- Os rótulos existem nas dez locales numa só passagem.

**Dependências.** Apoia-se nas migrações `conventions_*` já em vigor.

*Remissões : `spec-conventions-catalographiques-v0.1 §7`*

#### C7 — Indexar por assunto os 1 549 registros que não têm nenhum assunto

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia, nenhuma competência técnica

**Estado verificado em 29/08.** Verificado em 29/08: **1 127 registros indexados de 2 676**, ou seja 42 %. 1 284 atribuições distribuídas em 89 assuntos locais. Do lado público anônimo, a cobertura é ainda mais baixa.

**O que é.** Indexar, registro por registro, com o vocabulário local e o tesauro FICEDL já carregado. Nenhuma competência técnica: é um trabalho de biblioteca, feito a partir do aplicativo.

**Por que importa.** Um catálogo com 42 % de indexação não se percorre: busca-se por título, o que pressupõe saber o que se procura. O assunto é o único caminho de entrada para quem vem ver o que há sobre uma questão. E, como o tesauro está traduzido em dez línguas, cada atribuição vale simultaneamente para as dez.

**O que conta como terminado.**

- A cobertura passa de 70 % dos registros públicos.
- O assunto parasita `pierre-joseph-proudhon` (0 livro) é suprimido, e `anarcocomunismo` é verificado.
- Os oito assuntos AnarBib sem equivalente FICEDL continuam vinculados a um termo mais amplo e são **levados à federação como contribuição, não como queixa**: educação libertária (64 livros), abolicionismo penal (13), ecologia social (10), anarcafeminismo, comunismo libertário, anarcopunk, especifismo, cabanagem.

**Dependências.** Nenhuma. **Entrada sem competência técnica.**

*Remissões : `AnarBib-Backlog-2026-06-17-v33 §5` · `ETAT-lancement-consolide-2026-07-03 §2 item 6`*

#### C8 — Enriquecer as autoridades: datas, identificadores externos, formas variantes

`P3` Adiado · Estado : **Aberto** · Carga : várias semanas · O que exige : biblioteconomia

**Estado verificado em 29/08.** De 1 305 autoridades: **726 (56 %) sem data de nascimento**, cerca de **1 272 (98 %) sem identificador VIAF, ISNI ou Wikidata**, cerca de **1 275 (98 %) sem `variant_forms`**.

**O que é.** Passagens de enriquecimento pelas fontes já conectadas, com revisão. Os pseudônimos militantes são um caso à parte: a entrada se faz pela forma mais conhecida do movimento, com remissão a partir do nome civil, **nunca o contrário**.

**Por que importa.** Os identificadores externos são o que permitirá a outro catálogo reconhecer nossas autoridades sem redescrevê-las. As formas variantes são o que permite encontrar alguém sob o nome que se conhece. E para um pseudônimo militante, a forma de uso **carrega frequentemente o único rastro de uma repressão**: não se sobrescreve.

**O que conta como terminado.**

- A cobertura em identificadores externos passa de 20 % nas autoridades mais citadas.
- Nenhum pseudônimo militante foi substituído por um nome civil.

**Dependências.** Depois de **C4** (os países ajudam os alinhamentos).

*Remissões : `AUDIT_conventions_catalographiques_2026-08-20 A7-A9` · `REGISTRE §12 CAT-D6`*

#### C9 — Fechar as oito questões abertas das convenções catalográficas

`P2` Corrente · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : biblioteconomia

**Estado verificado em 29/08.** `CONV-6` continua «a confirmar» e `CONV-O1` a `CONV-O8` estão abertos. Dois deles carregam trabalho quantificado: `CONV-O7` (o tipo de autoridade existe mas continua ilegível pelo SQL — **16 vereditos de coletividades faltam**) e `CONV-O8` (a cisão de autoridade não existe — **3 separações faltam**).

**O que é.** Decidir as oito numa sessão, apoiando-se no acervo real: `name_lang` distinto de `country` ou não, convenções das coletividades, destino de `books.autor` (ver **C5**), critério de mudança para EDTF, perímetro da tela de verificação, e os dois lotes manuais.

**Por que importa.** A coluna `name_lang` foi criada anulável e sem restrição validada: **criá-la não compromete nada, usá-la sim**. Enquanto a questão ficar aberta, cada nova regra de entrada precisa se perguntar em que se apoia.

**O que conta como terminado.**

- As oito têm um veredicto no REGISTRO.
- As 16 coletividades e as 3 separações são tratadas à mão — são explicitamente **não automatizáveis**.

**Dependências.** Esclarece **C6**.

*Remissões : `REGISTRE §37 CONV-6, CONV-O1..O8`*

#### C10 — Renomear uma das duas colunas `rights_status`

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** `digital_assets.rights_status` é um **estado de workflow** (`to_review`, `public_domain_confirmed`) que comanda a visibilidade. O vocabulário de direitos autorais leva o mesmo nome desde a migração `20260820235000_vocabulaire_rights_status`. Dois sentidos, um nome.

**O que é.** Renomear a coluna de workflow — `review_state` por exemplo — e propagar ao front e às RPC. O vocabulário de direitos guarda o nome, já que é ele que fala de direitos.

**Por que importa.** Confusão garantida do contrário, e num assunto em que a confusão se paga: é o estado dos direitos que decide se um documento é visível ao público. Uma armadilha documentada se acrescenta — `access_scope` vale `conta_ativa` **por omissão**, de modo que um documento de domínio público continua reservado às contas ativas enquanto ninguém tiver posto `publico` explicitamente.

**O que conta como terminado.**

- As duas noções levam dois nomes distintos, no banco e na tela.
- A armadilha `access_scope` é lembrada no formulário de catalogação, não só numa nota.

**Dependências.** Nenhuma.

*Remissões : `PLAN_DE_MARCHE §8` · `DECISION_profil_numerisation_2026-08-20`*

---

### D — Periódicos, efêmeros, recursos digitais

*O que a biblioteconomia do livro não sabe descrever, e que é uma parte enorme dos nossos acervos.*

| | | | |
|---|---|---|---|
| **D1** | Revisar a spec dos periódicos contra o que foi entregue | `P1` | A verificar |
| **D2** | Decidir as cinco questões que ficaram abertas sobre os periódicos | `P2` | Decisão coletiva |
| **D3** | Vincular os 91 fascículos e as 87 monografias suspeitas de SOLIDAIRES | `P2` | Bloqueado |
| **D4** | O material efêmero: panfletos, cartazes, adesivos, fanzines | `P1` | Aberto |
| **D5** | Testar a cadeia de digitalização em dez obras antes de equipar quem quer que seja | `P2` | Aberto |
| **D6** | Retomar ou substituir o leitor EPUB | `P3` | Aberto |

#### D1 — Revisar a spec dos periódicos contra o que foi entregue

`P1` Prioritário · Estado : **A verificar** · Carga : uma noite · O que exige : biblioteconomia, SQL / PostgreSQL

**Estado verificado em 29/08.** `spec-periodiques-v0.1` (27/08) anuncia «nove pacotes a entregar». **Os nove foram entregues em 27 e 28/08**, num dia: `serials`, RPC, anti-falsos-duplicados, estado de coleção, entrada na Oficina, retomada dos registros existentes, UI de catalogação, página pública, e os rótulos nas dez línguas.

**O que é.** Reler a spec, marcar os nove pacotes como entregues, depois verificar uma a uma as seis guardas anunciadas — anticiclo de filiação limitado a 20 saltos, reciprocidade predecessor/sucessor por trigger, proibição de `serial_id` num não-fascículo, simetria do importador diante da coluna gerada, fusão dos estados de coleção sem sobrescrita, ordem de classificação.

**Por que importa.** Uma spec que diz «a entregar» sobre código entregue causa exatamente o dano inverso de uma spec atrasada: faz refazer. E as seis guardas são o que distingue um subsistema que aguenta de um subsistema que quebra na primeira importação em massa.

**O que conta como terminado.**

- A spec passa a v1.0 e descreve o estado entregue.
- As seis guardas estão verificadas no banco, com o resultado escrito.
- A guarda `G2` (reciprocidade) é de fato um trigger: «a disciplina não sobrevive a seis meses».

**Dependências.** Pré-requisito de **D2**.

*Remissões : `spec-periodiques-v0.1 §11 §14` · `Migrations 20260827163000 à 20260827210000`*

#### D2 — Decidir as cinco questões que ficaram abertas sobre os periódicos

`P2` Corrente · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : biblioteconomia

**Estado verificado em 29/08.** Cinco arbitragens ficaram pendentes na spec, com uma inclinação escrita para cada uma: vocabulário de `periodicidade` livre ou fechado; filiação n-n ou dois vínculos simples; `serials` deve levar um `library_id`; promoção automática de um título proposto; página pública dedicada ou faceta.

**O que é.** Decidi-las sobre casos reais em vez de no abstrato — o acervo Anarchief (cerca de cem títulos desde 1860) e o acervo SOLIDAIRES (12 títulos, 91 fascículos) são a matéria para testar.

**Por que importa.** Duas das cinco já estão decididas de fato pelo código entregue (página dedicada `/periodico/<slug>`, sem `library_id`). Deixá-las «abertas» no REGISTRO enquanto o código escolheu cria exatamente o tipo de desvio que este backlog corrige.

**O que conta como terminado.**

- As cinco têm um veredicto inscrito, de acordo com o código entregue ou corrigindo-o.
- A promoção de um título continua **um gesto e não um limiar** — era a inclinação, e vale confirmá-la.

**Dependências.** Depois de **D1**.

*Remissões : `spec-periodiques-v0.1 §13`*

#### D3 — Vincular os 91 fascículos e as 87 monografias suspeitas de SOLIDAIRES

`P2` Corrente · Estado : **Bloqueado** · Carga : alguns dias · O que exige : biblioteconomia

**Estado verificado em 29/08.** O arquivo SOLIDAIRES já traz colunas `revue` e `numero`: **12 títulos a criar, 91 fascículos a vincular**. Além disso, **87 monografias trazem «n°» no título** e estão marcadas por uma flag `numero_dans_titre`: são candidatas ao vínculo.

**O que é.** Criar os 12 títulos, vincular os 91 fascículos, depois **submeter** as 87 candidatas a alguém que conheça o acervo. Não vinculá-las automaticamente.

**Por que importa.** Um título que contém «n°» nem sempre é um fascículo — às vezes é um título de coleção, às vezes um erro de digitação. A flag sinaliza, não decide. E a rede conta hoje apenas 4 títulos de periódicos: este lote os multiplicaria por quatro, e testaria o subsistema de verdade.

**O que conta como terminado.**

- Os 12 títulos existem e os 91 fascículos estão vinculados.
- As 87 candidatas foram submetidas, e cada veredicto é humano.
- O comportamento observado nos quatro registros *Encontros com a Civilização brasileira* confirma a regra antifalsos-duplicados: dois pares saem, dois ficam.

**Dependências.** **Bloqueado por C2**, portanto por **G7** e **A1**. A revisão da spec (**D1**) pode ser feita sem esperar.

*Remissões : `spec-periodiques-v0.1 §10` · `REPRISE_claude_code_2026-08-27`*

#### D4 — O material efêmero: panfletos, cartazes, adesivos, fanzines

`P1` Prioritário · Estado : **Aberto** · Carga : um canteiro longo · O que exige : biblioteconomia, React / JavaScript, deliberação coletiva

**Estado verificado em 29/08.** Nada existe. O modelo de registro herdado da biblioteconomia do livro não sabe descrever esse material, e o AnarBib não é exceção. É a necessidade **pior atendida**, para uma parte enorme dos nossos acervos.

**O que é.** Este material não tem ISBN, nem editora, frequentemente nem autor nem título. É visual tanto quanto textual: um cartaz não se resume à sua ocerização. O canteiro começa por reflexão documental — o que se descreve, com quê, e para quem — antes de qualquer tabela.

**Por que importa.** É o que as bibliotecas militantes têm de mais específico e menos aparelhado. Os vocabulários de efêmeros construídos alhures — NORLA, com suas facetas *Tactics* e *Social Movement* — são **monolíngues** e sem vínculo com o tesauro FICEDL: há aí um trabalho comum a fazer, não um módulo a escrever sozinho.

**O que conta como terminado.**

- Um enquadramento documental escrito, discutido com pelo menos um outro acervo.
- Um modelo mínimo testado em cinquenta peças reais.
- **Não é um canteiro para quem só quer escrever funções.**

**Dependências.** A ligar a **H6** (alinhamento dos vocabulários militantes) e ao encontro de Bolonha.

*Remissões : `docs/CHANTIERS_OUVERTS.md §3` · `VEILLE_leftovers_maydayrooms_2026-08-19`*

#### D5 — Testar a cadeia de digitalização em dez obras antes de equipar quem quer que seja

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia

**Estado verificado em 29/08.** A regra está registrada e cabe numa frase: «captura-se em tons de cinza, entrega-se em bitonal, só se mantém on-line o que é entregue». Os tetos dos buckets estão em produção. **A ferramenta de derivação não foi escolhida**, e a ficha prática de uma página não está escrita.

**O que é.** Comparar ScanTailor + `img2pdf` com `unpaper` ou ImageMagick em dez obras reais e variadas, medir o peso e a legibilidade, escolher. Depois escrever a ficha: três ajustes, cinco controles, nada mais.

**Por que importa.** Equipar uma biblioteca com uma cadeia não testada é fazê-la escanear duzentas páginas que será preciso refazer. E a limiarização bitonal é **destrutiva e irreversível**: nunca se escaneia diretamente em bitonal, nunca.

**O que conta como terminado.**

- Uma ferramenta é escolhida, com as medidas que decidiram.
- A ficha prática de uma página existe, em português e francês.
- O destino das imagens de captura está escrito: arquivamento off-line sistemático ou apagamento após validação — **a resposta pertence a cada biblioteca, mas precisa estar escrita em algum lugar**.

**Dependências.** O dimensionamento anunciado (20 GB para começar, até 50 GB em 3-5 anos) depende da escolha da ferramenta.

*Remissões : `DECISION_profil_numerisation_2026-08-20 §9`*

#### D6 — Retomar ou substituir o leitor EPUB

`P3` Adiado · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript, Deno / TypeScript

**Estado verificado em 29/08.** `epubjs ^0.3.93` é a única dependência claramente pré-1.0 num caminho crítico — o leitor EPUB, `src/lib/reader/epubEngine.js` e `src/components/viewers/EpubReader.jsx`. A biblioteca não teve publicação maior há anos.

**O que é.** Avaliar o que quebra hoje, o que quebrará com os navegadores futuros, e se existe uma alternativa livre mantida. Decidir entre fixar e assumir, ou substituir.

**Por que importa.** O leitor é o que torna um acervo digitalizado consultável sem download. Se cair, não é um conforto que desaparece, é o acesso. Nada urge hoje — mas é melhor saber.

**O que conta como terminado.**

- Um veredicto escrito: conservar e fixar, ou substituir por quê.
- Se conservação: um teste que verifica a abertura de um EPUB real.

**Dependências.** Nenhuma.

*Remissões : `package.json` · `Relevé du 29/08/2026`*

---

### E — Front, OPAC, i18n, acessibilidade

*10 locales em paridade estrita, 6 177 chaves cada uma, verificadas na integração contínua.*

| | | | |
|---|---|---|---|
| **E1** | Fazer auditar a acessibilidade por alguém que não escreveu o código | `P1` | Aberto |
| **E2** | Decidir as convenções neerlandesa e grega | `P1` | Aberto |
| **E3** | Uniformizar o registro de tratamento entre as dez locales | `P2` | Decisão coletiva |
| **E4** | Resolver os pares irregulares do italiano | `P2` | Aberto |
| **E5** | Retransmitir os ladrilhos OpenStreetMap pelo servidor | `P2` | Aberto |
| **E6** | Dividir as cinco telas que pesam mais de cem quilobytes | `P2` | Aberto |
| **E7** | Corrigir o título de página que não segue a navegação | `P2` | Aberto |
| **E8** | Carregar as duas fontes sem bloquear a exibição | `P2` | Aberto |
| **E9** | Terminar o layout móvel: três lotes identificados | `P2` | Aberto |
| **E10** | O resto da base de campo: plantão móvel, notificação push, prancha de códigos | `P3` | Aberto |
| **E11** | Os dois adiamentos assumidos do OPAC: tags contributivas e feed RSS | `P3` | Decisão coletiva |

#### E1 — Fazer auditar a acessibilidade por alguém que não escreveu o código

`P1` Prioritário · Estado : **Aberto** · Carga : alguns dias · O que exige : nenhuma competência técnica, React / JavaScript

**Estado verificado em 29/08.** Funcionalidades de acessibilidade estão implementadas: painel de ajustes em todas as páginas desde 26/08, `html lang` que segue a língua exibida (WCAG 3.1.1) com seu teste, campos de 16 px no mínimo, alvos táteis de 44 px, `viewport-fit=cover`. **Nenhuma auditoria de acessibilidade independente foi jamais conduzida.**

**O que é.** Fazer percorrer os percursos principais — buscar, abrir um registro, reservar, cadastrar-se — por uma pessoa que use um leitor de tela ou navegação só por teclado, e escrever o que trava.

**Por que importa.** «Implementado» e «auditado» não são a mesma palavra, e confundi-los é a falta mais fácil de cometer numa apresentação pública. Dizer os dois, sempre: funcionalidades existem, ninguém de fora as testou.

**O que conta como terminado.**

- Um percurso completo foi feito com leitor de tela, com relatório escrito.
- Os travamentos estão no backlog com sua tela.
- O discurso público passa a dizer «implementado e auditado por X», ou continua dizendo os dois separadamente.

**Dependências.** **Entrada sem competência técnica** para a parte de percurso.

*Remissões : `Mémoire de projet, 25/08/2026` · `Commits 69af3cf5, df472bed`*

#### E2 — Decidir as convenções neerlandesa e grega

`P1` Prioritário · Estado : **Aberto** · Carga : alguns dias · O que exige : língua materna

**Estado verificado em 29/08.** As dez locales estão em paridade estrita de chaves — 6 177 cada uma, verificada na integração contínua desde 27/08. Mas as **convenções** de duas delas não estão decididas: o neerlandês está em estado de rascunho, o grego resta a definir. O teste de paridade não vê isso: conta as chaves, não a justeza delas.

**O que é.** Uma falante ou um falante nativo retoma a carta de linguagem inclusiva, decide a forma neutra para sua língua, e revisa as 6 177 cadeias com prioridade nas telas mais vistas.

**Por que importa.** Duas línguas que deixam de ser traduções aproximativas. É um dos três canteiros que **não exigem nenhuma competência técnica** — e o único que ninguém mais pode fazer no lugar.

**O que conta como terminado.**

- As convenções `nl` e `el` estão escritas em `docs/notes-audit/anarbib-charte-langage-inclusif-v2-*.md`.
- As cadeias das telas principais estão revisadas.
- A lista neerlandesa já foi enviada a Ludwig — o acompanhamento faz parte.

**Dependências.** Nenhuma. **Entrada sem competência técnica.**

*Remissões : `docs/CHANTIERS_OUVERTS.md §5` · `docs/notes-audit/anarbib-charte-langage-inclusif-v2.md`*

#### E3 — Uniformizar o registro de tratamento entre as dez locales

`P2` Corrente · Estado : **Decisão coletiva** · Carga : alguns dias · O que exige : língua materna, deliberação coletiva

**Estado verificado em 29/08.** `DOC-ADDR-1` fixa o tratamento informal como registro da interface. Na prática, **`nl` e `el` tratam por «tu», as outras oito por «você» formal**. A divergência está documentada e assumida como «um canteiro a decidir, não a sofrer de passagem numa correção».

**O que é.** Decidir uma vez para as dez, levando em conta que o valor político do tratamento informal não é o mesmo em cada língua, depois passar as locales envolvidas numa única operação.

**Por que importa.** O AnarBib propõe a outros catálogos convenções de interoperabilidade, uma das quais diz explicitamente que o vocabulário comum não impõe a escrita inclusiva de cada um. **A coerência interna se resolve antes de pregar a convenção.**

**O que conta como terminado.**

- Uma decisão no REGISTRO, com o motivo.
- As dez locales aplicam o mesmo registro, ou a divergência é justificada língua por língua.

**Dependências.** A fazer depois de **E2** (as convenções decidem o registro).

*Remissões : `REGISTRE §0 DOC-ADDR-1` · `VERIF_confidentialite_tiers_2026-08-20`*

#### E4 — Resolver os pares irregulares do italiano

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : língua materna

**Estado verificado em 29/08.** `it.json` não está conforme à convenção do asterisco final: os pares irregulares como `lettore` / `lettrice` não se reduzem a `lettor*`. O teste de carta verifica uma só coisa no italiano — que `camerata` e `camerati` nunca apareçam, termo fascista, falha dura — e nada mais.

**O que é.** Decidir o tratamento dos pares irregulares com um falante nativo, depois aplicá-lo às cadeias envolvidas. É um trabalho de língua, não de código.

**Por que importa.** O italiano é a língua da apresentação de Bolonha. Uma interface que aplica sua convenção pela metade se vê na tela compartilhada.

**O que conta como terminado.**

- O tratamento dos pares irregulares está escrito na carta italiana.
- As cadeias envolvidas estão corrigidas.
- As três cadeias que ficaram em francês na interface italiana estão traduzidas (716 cadeias vistas, 3 defeituosas).

**Dependências.** Antes de 08/09 se possível, senão outubro.

*Remissões : `CLAUDE.md, piège connu n°9` · `CALENDRIER_bologne_2026-08-27`*

#### E5 — Retransmitir os ladrilhos OpenStreetMap pelo servidor

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : React / JavaScript

**Estado verificado em 29/08.** É a **única exceção antirrastreamento restante**: os ladrilhos de `tile.openstreetmap.org` são carregados pelo navegador da visitante, que entrega portanto seu endereço IP a um terceiro. A intenção de retransmitir já está **anunciada publicamente** na chave `privacy.s6.maptiles` das dez locales.

**O que é.** Retomar o modelo já em vigor para o Nominatim: um relé do lado servidor, com cache, e o endereço do relé na configuração do front.

**Por que importa.** A regra de conformidade do projeto está escrita e é geral: **toda dependência que recebe um endereço IP de visitante deve ser declarada, mesmo quando não é um operador no sentido do RGPD.** O raciocínio inverso é precisamente o que deixara o Turnstile invisível durante meses. Aqui a dependência está declarada — falta suprimi-la, como anunciado.

**O que conta como terminado.**

- Nenhuma requisição sai do navegador para um domínio de terceiro nas páginas de mapa.
- A chave `privacy.s6.maptiles` é atualizada nas dez locales para descrever o novo estado.

**Dependências.** Mais simples depois de **I2** (pilha auto-hospedada), mas viável antes.

*Remissões : `VERIF_confidentialite_tiers_2026-08-20` · `PLAN_DE_MARCHE §8` · `scripts/nominatim/`*

#### E6 — Dividir as cinco telas que pesam mais de cem quilobytes

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript

**Estado verificado em 29/08.** `BookDraftForm.jsx` tem **197 KB**, `BibliotecaPage.jsx` 184 KB, `AccountPage.jsx` 154 KB, `PanelPage.jsx` 114 KB, `ImportacoesPage.jsx` 109 KB. 29 das 38 rotas já estão em carregamento preguiçoso, e `vite.config.js` declara quatro lotes de dependências — o problema não é o carregamento inicial, é o tamanho de um arquivo único.

**O que é.** Extrair os subformulários e as abas em componentes separados, sem mudar o comportamento. Começar por `BookDraftForm`, o maior e o mais editado.

**Por que importa.** Um arquivo de 197 KB não é relegível por quem chega, e duas pessoas não podem trabalhar nele ao mesmo tempo sem conflito. É um obstáculo à contribuição antes de ser um problema de performance.

**O que conta como terminado.**

- Nenhum arquivo de `src/` passa de 60 KB.
- O comportamento está inalterado, verificado tela por tela.
- Divisão por lotes, uma tela por vez, nunca uma refundação.

**Dependências.** Retoma `#PERF-accountpage-split`, herdado do v32.

*Remissões : `AnarBib-Backlog-2026-06-17-v33 §2.5` · `Relevé du 29/08/2026`*

#### E7 — Corrigir o título de página que não segue a navegação

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : React / JavaScript

**Estado verificado em 29/08.** `document.title` não se atualiza durante uma navegação dentro do aplicativo; só muda no recarregamento completo da página.

**O que é.** Definir o título a cada mudança de rota, a partir das chaves i18n existentes.

**Por que importa.** O título de página é o que os leitores de tela leem na chegada, o que se inscreve no histórico do navegador, e o que aparece numa aba fixada. Um título congelado torna os três inutilizáveis.

**O que conta como terminado.**

- O título segue a rota, nas dez línguas.
- Um teste o verifica, no modelo de `documentLanguage.test.js`.

**Dependências.** Complemento natural de **E1**.

*Remissões : `Mémoire de projet, dette technique`*

#### E8 — Carregar as duas fontes sem bloquear a exibição

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : React / JavaScript

**Estado verificado em 29/08.** `titre.ttf` pesa 1 MB e `accent.ttf` 484 KB; as duas são carregadas sem pré-carregamento declarado, sem `font-display: swap`, e sem `preconnect` para o Supabase.

**O que é.** Adicionar `font-display: swap`, pré-carregar apenas a fonte de título, subconjuntar os arquivos aos caracteres realmente usados — dez línguas incluindo o grego, então o subconjunto não é trivial.

**Por que importa.** 1,5 MB de fontes numa conexão de balcão são vários segundos de tela branca. O público do AnarBib inclui bibliotecas que não têm fibra.

**O que conta como terminado.**

- O texto aparece antes das fontes, com uma substituição aceitável.
- O peso total das fontes carregadas na primeira visita é medido antes e depois.

**Dependências.** Não tocar na identidade visual: `IDENT-1` a `IDENT-4` estão registrados.

*Remissões : `Mémoire de projet, dette technique` · `REGISTRE §39 IDENT`*

#### E9 — Terminar o layout móvel: três lotes identificados

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript

**Estado verificado em 29/08.** As fases A, B e C estão entregues e a doutrina graduada está registrada. Três questões continuam abertas no REGISTRO: `MOB-Q1` (24 grades declaradas em linha no JSX com trilhas `fr` nuas), `MOB-Q2` (20 media queries herdadas a repatriar em `src/styles/mobile.css`), `MOB-Q3` (as abas Validações e Inventário a converter em cartões).

**O que é.** Três passagens mecânicas, nesta ordem de valor: as 24 grades (`minmax(0, Nfr)` em toda parte, é a regra `MOB-1`), as duas abas em cartões segundo o padrão entregue, depois o repatriamento das media queries.

**Por que importa.** Uma trilha `fr` nua transborda assim que seu conteúdo é mais largo que a coluna, e um transbordamento **se constata pela medida, nunca a olho** (`MOB-9`). As 24 grades são outros tantos transbordamentos à espera de um título longo.

**O que conta como terminado.**

- Nenhuma grade do JSX traz trilha `fr` nua.
- As duas abas estão em cartões abaixo de 640 px.
- As media queries herdadas vivem em `mobile.css`.

**Dependências.** Nenhuma. Canteiro divisível em três.

*Remissões : `REGISTRE §36 MOB-Q1..Q3`*

#### E10 — O resto da base de campo: plantão móvel, notificação push, prancha de códigos

`P3` Adiado · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript

**Estado verificado em 29/08.** A base de campo está entregue: aplicativo instalável, leitura de códigos QR e ISBN, inventário, layout adaptativo. Três elementos restam, herdados do v32 e não reverificados desde então: o plantão móvel (P3), a notificação push (P5), e a prancha de códigos QR em formato A4.

**O que é.** Começar verificando qual dos três ainda é uma falta real. A notificação push levanta uma questão de fundo antes de uma questão de código: pressupõe um serviço de terceiro, o que a doutrina antirrastreamento examina de perto.

**Por que importa.** A prancha A4 é a mais simples e a mais útil no balcão: permite etiquetar um acervo sem impressora de etiquetas. As outras duas merecem primeiro uma conversa.

**O que conta como terminado.**

- A prancha A4 existe e imprime corretamente.
- Para a notificação push, um veredicto escrito: viável sem terceiro, ou renúncia assumida.

**Dependências.** Herdado de `#MOBILE P3`, `#MOBILE P5`, `#MOB-QR-A4`.

*Remissões : `AnarBib-Backlog-2026-06-17-v33 §2.1`*

#### E11 — Os dois adiamentos assumidos do OPAC: tags contributivas e feed RSS

`P3` Adiado · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : deliberação coletiva, React / JavaScript

**Estado verificado em 29/08.** `#OPAC5` (folksonomia, tags postas pelas leitoras) está bloqueado numa decisão de comunidade e de privacidade. `#OPAC11` (feed RSS de busca) está adiado por razão antirrastreamento. Os dois estão abertos desde maio e nunca foram instruídos.

**O que é.** Instruí-los de uma vez: o que uma tag pública revela sobre quem a pôs, e o que um feed RSS revela sobre quem o segue? Depois decidir, ou fechar.

**Por que importa.** Um item adiado sem instrução continua na pauta de cada releitura e custa atenção a cada vez. Fechar um item é uma decisão tão válida quanto entregá-lo.

**O que conta como terminado.**

- Os dois têm um veredicto no REGISTRO: entregue, ou fechado com o motivo.
- `OPAC-RSS1` é atualizado em consequência.

**Dependências.** Nenhuma.

*Remissões : `REGISTRE §18 OPAC-RSS1` · `AnarBib-Backlog-2026-06-17-v33 §2.4`*

---

### F — E-mail e notificações

*13 funções notify-*, 5 filas, 6 gatilhos de despacho. Ninguém jamais auditou o conjunto.*

| | | | |
|---|---|---|---|
| **F1** | Auditar a cadeia de e-mail de ponta a ponta | `P1` | Aberto |
| **F2** | Corrigir o template dos e-mails de alerta de operação | `P1` | Aberto |
| **F3** | Consolidar as funções de notificação redundantes | `P2` | Aberto |
| **F4** | Verificar os lembretes de vencimento e as cobranças de atraso | `P2` | A verificar |
| **F5** | Verificar se o prazo de negociação de 21 dias está de fato aplicado | `P2` | A verificar |

#### F1 — Auditar a cadeia de e-mail de ponta a ponta

`P1` Prioritário · Estado : **Aberto** · Carga : alguns dias · O que exige : Deno / TypeScript, SQL / PostgreSQL

**Estado verificado em 29/08.** **14 funções `notify-*` implantadas**, cinco filas, seis gatilhos de despacho. Três filas nunca receberam uma única inserção: `authority_proposal_notification_outbox`, `membership_expiry_notifications`, `painel_internal_task_invitation_outbox`. Uma quarta, `painel_internal_task_notification_outbox`, está vazia após 34 inserções cuja última é de 04/06. Ninguém jamais auditou o conjunto.

**O que é.** Traçar o mapa: para cada evento de negócio, qual gatilho, qual fila, qual função, qual template, quais dez línguas. Depois marcar os ramos mortos e os ramos nunca percorridos.

**Por que importa.** Uma notificação que não sai não faz barulho nenhum. É o mesmo ponto cego dos backups, e já mordeu duas vezes: os e-mails `retirada_efetivada`, `retirada_reagendada`, `retirada_no_show` e `liberada_para_circulacao` foram apontados como não saindo, sem que o diagnóstico fosse levado a termo.

**O que conta como terminado.**

- Um mapa escrito, evento por evento.
- Os quatro e-mails apontados como não enviados têm um veredicto: corrigidos, ou explicados.
- Os ramos mortos são suprimidos ou documentados como dormentes.

**Dependências.** Pré-requisito de **F2** e **F3**.

*Remissões : `Mémoire de projet, reliquats de la chaîne courriel` · `AUDITORIA_NOTIFY_FUNCTIONS_2026-05-06`*

#### F2 — Corrigir o template dos e-mails de alerta de operação

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : Deno / TypeScript

**Estado verificado em 29/08.** Os e-mails de alerta de operação — backup em falha, incidente de sonda — usam o template destinado às leitoras. Terminam portanto com «entre em contato com a biblioteca» seguido de um número de telefone.

**O que é.** Um template de operação distinto: sem rodapé destinado ao público, o comando a executar, e o link para a seção do runbook.

**Por que importa.** **A corrigir antes que um segundo administrador de rede exista.** Hoje uma só pessoa recebe esses alertas e sabe lê-los; no dia em que **A1** for concluído, eles chegarão a alguém que descobrirá um e-mail de incidente aconselhando a ligar para a biblioteca.

**O que conta como terminado.**

- Um template de operação existe, distinto do template de leitora.
- Um alerta de teste foi recebido e relido por alguém que não escreveu o código.

**Dependências.** Deve preceder a conclusão de **A1**.

*Remissões : `RUNBOOK_exploitation_v0.3 §7` · `PLAN_DE_MARCHE §8`*

#### F3 — Consolidar as funções de notificação redundantes

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : Deno / TypeScript

**Estado verificado em 29/08.** Quatro funções fazem resumos: `notify-weekly-report`, `notify-network-weekly-report`, `notify-cross-library-digest`, `notify-rede-digest`. Três funções servem documentos: `read-pdf`, `read-digital-asset`, `read-ill-shared-asset`. Duas exportam lotes: `export-catalog-lote`, `export-fonds-bundle`. E `mail-i18n-test`, função de teste, está implantada em produção na versão 1553.

**O que é.** Verificar o que cada uma faz de fato antes de concluir pela redundância — provavelmente têm destinatários e alcances diferentes. Depois fundir o que deve sê-lo, e retirar `mail-i18n-test` da produção.

**Por que importa.** 48 funções implantadas é muito para manter num projeto com um mantenedor. Cada uma carrega seu próprio template, suas próprias dez línguas, seus próprios segredos. Não é um problema de performance, é um problema de superfície a revisar.

**O que conta como terminado.**

- Cada grupo tem um veredicto: fusão, ou motivo escrito da separação.
- `mail-i18n-test` não está mais implantada em produção.
- A contagem de funções implantadas está atualizada em `CLAUDE.md` e em `config.toml`.

**Dependências.** Depois de **F1**. Atenção: a implantação de `notify-event` não passa por MCP, seu pacote é grande demais.

*Remissões : `PLAN_DE_MARCHE §8` · `Relevé du 29/08/2026`*

#### F4 — Verificar os lembretes de vencimento e as cobranças de atraso

`P2` Corrente · Estado : **A verificar** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** `spec-flux-emprunts.md` §10.2 prevê lembretes em D-5, D-3 e no próprio dia, depois cobranças em D+1, D+7 e D+30. **Nenhum job dedicado é identificável** entre os 36 crons; o único vizinho é `anarbib-notify-mid-loan-reading-daily`, que faz outra coisa.

**O que é.** Verificar no banco se os lembretes saem por outro caminho, e senão, decidir: implementá-los, ou emendar a spec. Um empréstimo atrasado que não dispara nada é um empréstimo que ninguém cobra.

**Por que importa.** O acompanhamento de oito semanas da formação BLMF prevê que uma consulta seja conduzida de ponta a ponta com negociação real: é o momento em que a ausência de lembrete aparecerá. Melhor saber antes.

**O que conta como terminado.**

- Um veredicto escrito: os lembretes existem por tal caminho, ou não existem.
- Se ausentes: ou implementados, ou a spec emendada.

**Dependências.** Verifica-se ao mesmo tempo que **F1**.

*Remissões : `spec-flux-emprunts.md §10.2` · `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §3` · `PLAN_formation_coordination_BLMF §5`*

#### F5 — Verificar se o prazo de negociação de 21 dias está de fato aplicado

`P2` Corrente · Estado : **A verificar** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** O cron `anarbib-reservation-expire-negotiation` roda a cada hora (`25 * * * *`) — enquanto a spec de reserva v2 dava esse prazo como **não implementado**. O mecanismo existe portanto; o que ele faz exatamente não foi verificado.

**O que é.** Ler `fn_expire_negotiation_timeout()`, verificar o prazo que aplica, e corrigir a spec ou a função conforme o que se encontrar.

**Por que importa.** Um desvio do mesmo tipo já foi encontrado: a spec e o material de formação anunciavam uma expiração das reservas a cada seis horas, enquanto o cron roda **a cada hora**. O material foi corrigido, a spec não necessariamente.

**O que conta como terminado.**

- O prazo real está escrito na spec.
- As frequências anunciadas nos materiais de formação correspondem aos crons reais.

**Dependências.** Nenhuma.

*Remissões : `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §3` · `spec-workflow-reservation-v2-negotiation.md`*

---

### G — Rede, governança, federação

*Muitos circuitos construídos, pouquíssimos percorridos. É o principal ensinamento do levantamento.*

| | | | |
|---|---|---|---|
| **G1** | Percorrer os circuitos construídos e jamais usados | `P0` | Aberto |
| **G2** | Decidir politicamente o desvio entre P2 e P8 sobre a promoção a coordenador·a | `P1` | Decisão coletiva |
| **G3** | Testar o circuito de promoção colegiada em `blmf-teste` | `P1` | Aberto |
| **G4** | Exercer os quatro e-mails de equipe jamais enviados | `P1` | Aberto |
| **G5** | Esclarecer o estatuto da Biblioteca Terra Livre | `P2` | A verificar |
| **G6** | Dar uma tela ao empréstimo entre bibliotecas | `P2` | Aberto |
| **G7** | Decidir a admissão da Biblioteca SOLIDAIRES | `P1` | Bloqueado |
| **G8** | Completar a cartografia com os arquivos identificados alhures | `P2` | Aberto |
| **G9** | Implementar a cartografia da rede segundo a spec v1.0 | `P3` | Congelado |
| **G10** | Liquidar as três questões de onboarding marcadas «o mais rápido possível» | `P2` | Aberto |

#### G1 — Percorrer os circuitos construídos e jamais usados

`P0` Estrutural · Estado : **Aberto** · Carga : várias semanas · O que exige : deliberação coletiva, nenhuma competência técnica

**Estado verificado em 29/08.** Verificado em 29/08: **62 tabelas de negócio nunca receberam uma única inserção.** Sete blocos inteiros são atingidos — assembleias da rede (3 tabelas), notas de leitura (2), propostas e objeções de autoridade (3), referenciais de catalogação `catalog_ref_*` (8 de 9), governança dos perfis de biblioteca (4, **enquanto dois crons rodam sobre elas a cada quinze minutos**), deliberação sobre os pedidos de adesão (5, incluindo `library_request_votes` e `library_request_messages`).

**O que é.** Escolher um bloco e percorrê-lo de verdade, do primeiro ao último gesto: realizar uma assembleia da rede, depositar uma nota de leitura, propor uma autoridade e deixar alguém objetar, fazer deliberar um pedido de adesão. Registrar o que falta, o que surpreende, o que trava.

**Por que importa.** É o principal ensinamento do levantamento de 29 de agosto, e não consta em nenhum documento do corpus. **O projeto não sofre de falta de funcionalidades: sofre de falta de uso.** Um circuito jamais percorrido não está entregue — está apenas escrito. E no dia em que se torna o caminho crítico, como o circuito de convite acaba de se tornar para as promoções, ele quebra em coisas que uma única passagem teria revelado.

**O que conta como terminado.**

- Pelo menos três dos sete blocos foram percorridos de ponta a ponta, em `blmf-teste` e depois no real.
- Cada passagem produziu um relatório escrito do que falta.
- Os blocos cujo uso não é desejado hoje são marcados **dormentes**, com o motivo — não é um fracasso, é uma informação.

**Dependências.** O bloco «assembleia» depende de **A1**. Os outros não.

*Remissões : `Relevé du 29/08/2026` · `REGISTRE §32 AG, §28 ATE, §26 ONBO`*

#### G2 — Decidir politicamente o desvio entre P2 e P8 sobre a promoção a coordenador·a

`P1` Prioritário · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : deliberação coletiva

**Estado verificado em 29/08.** A migração `20260826120000` **está em produção** e decide no sentido de P2: colegialidade obrigatória, ratificação prévia, recuo a uma assinatura quando há uma só pessoa coordenadora, consentimento explícito da pessoa promovida, exclusão dessa pessoa da contagem do quórum. **Mas a decisão política nunca foi tomada.**

**O que é.** Levar a questão ao coletivo. Três opções estão escritas: não mudar nada no código e corrigir o texto de P2; estender o caminho A como o código fez; ou manter a promoção direta mas torná-la visível com um prazo de objeção.

**Por que importa.** Há hoje **código em produção que antecipa uma decisão coletiva não tomada**. O rollback está escrito e testado, o que torna a antecipação reversível — mas a outra leitura, *o SIGB não modela a assembleia geral*, continua inteiramente defensável. **Não é uma arbitragem técnica.**

**O que conta como terminado.**

- O coletivo decidiu, e a decisão está inscrita no REGISTRO.
- O código está alinhado com a decisão, ou o texto de P2 é emendado.
- Lembrete: o arquivo de rollback traz um sublinhado inicial que impede a CLI de aplicá-lo — **não renomeá-lo**.

**Dependências.** Questão aberta desde 26/08. Bloqueia **G3** se a resposta for «voltar atrás».

*Remissões : `ECART_cosignature_promotion_coordenador_2026-08-26 §5` · `REGISTRE §41 GOUV-1`*

#### G3 — Testar o circuito de promoção colegiada em `blmf-teste`

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : deliberação coletiva

**Estado verificado em 29/08.** A migração está em produção; o runbook de implantação em onze etapas está portanto caduco. O que resta é o **ensaio em seis passos em `blmf-teste`**, nunca feito. Ora, `library_team_invitations` traz **zero linha** desde sua criação: o circuito que a migração torna obrigatório nunca foi percorrido uma única vez.

**O que é.** Os seis passos na biblioteca de teste `blmf-teste`, cujos e-mails estão cortados (`email_delivery_mode = 'disabled'`). **Se um passo falhar, não fazer nada na BLMF.**

**Por que importa.** O ajuste `team_admission_mode = 'cosignature'` da BLMF **nunca teve efeito sobre nada**: as treze promoções ao papel de bibliotecário·a e as cinco à coordenação passaram todas pela promoção direta. O custo real da escolha adotada, escrito preto no branco, é que «o workflow de convite, jamais exercido, torna-se de repente o caminho crítico».

**O que conta como terminado.**

- Os seis passos foram feitos em `blmf-teste`, com o resultado de cada um escrito.
- Uma promoção real percorreu o circuito na BLMF.
- Atenção: `blmf-teste` **não é um banco separado** — é uma biblioteca no mesmo projeto.

**Dependências.** Depende de **G2** se o coletivo decidir voltar atrás.

*Remissões : `RUNBOOK_deploiement_collegialite_coordenador_2026-08-26 étape 10` · `MIGRATION_collegialite_coordenador_2026-08-26`*

#### G4 — Exercer os quatro e-mails de equipe jamais enviados

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : deliberação coletiva

**Estado verificado em 29/08.** Quatro e-mails existem, estão ligados, e nunca passaram em produção: `team.self_demoted`, `team.suspended`, `team.removal_requested`, `team.inactive_warning_*`. O mecanismo funciona — `team_notification_outbox` conta 21 envios e zero falha — mas esses quatro nunca foram disparados.

**O que é.** Provocar cada um dos quatro casos em `blmf-teste`, ler o e-mail recebido, verificar que diz o que deve dizer nas dez línguas.

**Por que importa.** Estes e-mails anunciam a alguém que perde um papel, que está suspenso, ou que se pede sua retirada. São as mensagens mais delicadas do sistema, e ninguém jamais as leu como chegam. As duas pessoas em formação para a coordenação BLMF serão as primeiras envolvidas.

**O que conta como terminado.**

- Os quatro e-mails foram recebidos e relidos.
- O tom e o conteúdo são validados por alguém que não escreveu os templates.
- **Primeiro em `blmf-teste`, nunca diretamente na BLMF.**

**Dependências.** Faz-se com **G3**, mesmo ambiente de teste.

*Remissões : `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §2`*

#### G5 — Esclarecer o estatuto da Biblioteca Terra Livre

`P2` Corrente · Estado : **A verificar** · Carga : uma noite · O que exige : deliberação coletiva

**Estado verificado em 29/08.** A BTL traz `is_test_mode = true` e `email_delivery_mode = 'test_only'`, **embora contenha 2 187 exemplares** — o maior acervo da rede — e esteja publicada na rede. Postura deliberada, ou resíduo de configuração?

**O que é.** Perguntar à BTL o que ela quer, depois alinhar a configuração. Se o modo de teste for deliberado, escrevê-lo em algum lugar para que ninguém o «corrija».

**Por que importa.** Em modo de teste, os e-mails não saem. Uma biblioteca com 2 187 exemplares publicados cujas leitoras não recebem nenhuma notificação é ou uma escolha, ou uma pane silenciosa há meses. A BTL entrou na rede com um estatuto «experimental» assumido — mas um estatuto político e um ajuste técnico não são a mesma coisa.

**O que conta como terminado.**

- A BTL respondeu, e a configuração corresponde à sua resposta.
- O estatuto está escrito onde alguém vai procurá-lo.

**Dependências.** Nenhuma. Uma conversa.

*Remissões : `PLAN_formation_coordination_BLMF §8`*

#### G6 — Dar uma tela ao empréstimo entre bibliotecas

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript, biblioteconomia

**Estado verificado em 29/08.** O ciclo de vida do empréstimo entre bibliotecas está especificado e implementado no banco: máquina de estados travada, quatro triggers, cron `anarbib-peb-detect-overdue-daily` ativo. **Nenhuma tela existe.** O banco traz 2 empréstimos para 20 inserções históricas.

**O que é.** Uma tela de pedido do lado da biblioteca solicitante, uma tela de tratamento do lado da emprestadora, e a exibição do estado para as duas. As views `interlibrary_loans_painel_ui` e `interlibrary_loan_items_ui` já existem.

**Por que importa.** O empréstimo entre bibliotecas é o que torna uma rede federativa útil às suas leitoras, em vez de uma simples justaposição de catálogos. Hoje ele tem «um início no banco, mesmo sem tela» — o que quer dizer que ninguém pode usá-lo.

**O que conta como terminado.**

- Um empréstimo completo foi feito entre duas bibliotecas da rede, pela interface.
- O fluxo «livro perdido ou danificado» tem um tratamento escrito — **nenhum fluxo o cobre hoje**, trata-se fora do SIGB com escalada à coordenação.

**Dependências.** `EA-12 fase 2` (paridade EEB, cerca de 45 funções) está congelada por `BIBLIO-9` — a não confundir com este item.

*Remissões : `spec-cycle-vie-peb.md` · `PLAN_formation_coordination_BLMF §5` · `REGISTRE §14 PEB`*

#### G7 — Decidir a admissão da Biblioteca SOLIDAIRES

`P1` Prioritário · Estado : **Bloqueado** · Carga : não estimado · O que exige : deliberação coletiva

**Estado verificado em 29/08.** Decisão federal **deliberadamente adiada**, por não poder ser tomada em conjunto. Prazo previsto: outubro ou novembro, depois de Bolonha.

**O que é.** Uma vez concluído **A1**, instruir o pedido em conjunto e decidir.

**Por que importa.** A restrição está escrita preto no branco ao coletivo e é absoluta: **não criar biblioteca «SOLIDAIRES» no banco** enquanto a decisão não for tomada, nem membro, nem parceira, nem alvo. «Criar a ficha equivaleria a inscrever no banco uma decisão que se diz não tomar.» **E desde 29/08 a mesma regra vale para o acervo: a importação dos 1 685 registros (C2) só se fará depois da admissão.** Este item não decide portanto apenas uma adesão: desbloqueia um canteiro de catalogação inteiro.

**O que conta como terminado.**

- A decisão é tomada por pelo menos três, e rastreada em `network_administrator_audit`.
- Seja qual for, é comunicada ao coletivo SOLIDAIRES com seu motivo.
- Uma vez pronunciada a admissão, **C2** e **D3** se desbloqueiam nesta ordem.

**Dependências.** **Bloqueado por A1.** Mesma observação para o pedido de adesão belga em avaliação.

*Remissões : `REPRISE_claude_code_2026-08-27` · `CALENDRIER_bologne_2026-08-27`*

#### G8 — Completar a cartografia com os arquivos identificados alhures

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : biblioteconomia, nenhuma competência técnica

**Estado verificado em 29/08.** `cartography_entries` traz 187 fichas e o arquivo `anarbib_bibliotheques_libertaires.geojson` conta 121. Nove arquivos identificados na rede NORLA não foram confrontados com essa lista.

**O que é.** Verificar quais das nove já constam, e fazer entrar as ausentes com `source = "FICEDL"` ou `"NORLA"` conforme sua proveniência.

**Por que importa.** O mapa só tem interesse se for mais completo do que aquilo que cada um já conhece. E a rastreabilidade da fonte é o que permitirá mais tarde dizer de onde vem cada ficha sem ter de perguntar de novo.

**O que conta como terminado.**

- Os nove arquivos têm um veredicto: já presente, ou acrescentado com sua fonte.
- Lembrete: `statut_public` está em `FALSE` por omissão e **nenhuma importação em massa** é autorizada (`MAP-E`).

**Dependências.** Nenhuma. **Entrada sem competência técnica.**

*Remissões : `VEILLE_leftovers_maydayrooms_2026-08-19 §3.4` · `REGISTRE §34 MAP-E`*

#### G9 — Implementar a cartografia da rede segundo a spec v1.0

`P3` Adiado · Estado : **Congelado** · Carga : várias semanas · O que exige : React / JavaScript

**Estado verificado em 29/08.** As arbitragens estão decididas desde 18/06: tabela dedicada, i18n híbrida, mapa público como rota do aplicativo, motor Leaflet, OpenStreetMap e Nominatim auto-hospedados, entradas não membros exibidas com um filtro claro. `MAP-I` (estatuto do empréstimo entre bibliotecas no mapa interno) e `MAP-J` (autodeclaração «adicionar minha biblioteca» com moderação) continuam adiados.

**O que é.** Retomar a spec v1.0 quando a janela se abrir. Atenção: o REGISTRO traz **duas seções `MAP`** — a §2 é um esqueleto onde tudo está aberto, a §34 é a versão decidida. A §2 não tem carimbo de supersessão nem remissão à §34: **é a §34 que vale**.

**Por que importa.** O mapa é o primeiro objeto que uma biblioteca que descobre a rede vai olhar. Merece ser feito quando houver tempo para fazê-lo bem, e não na janela anterior a Bolonha.

**O que conta como terminado.**

- O mapa público é uma rota do aplicativo, servido sem requisição a terceiro (ver **E5**).
- A §2 do REGISTRO traz uma remissão à §34.

**Dependências.** Depois de Bolonha. Ligado a **E5** e **J5**.

*Remissões : `spec-cartographie-reseau.md v1.0` · `REGISTRE §34 MAP`*

#### G10 — Liquidar as três questões de onboarding marcadas «o mais rápido possível»

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : deliberação coletiva

**Estado verificado em 29/08.** Três pontos estão marcados 🔴 «a resolver o mais rápido possível» desde junho e não se moveram: `#111` (avaliação colaborativa de uma pessoa administradora de rede, dormente), `ONBO-Q13` (transferência técnica do mandato de coordenação), e o acabamento do módulo 10 da oficina de onboarding.

**O que é.** Os três se tratam juntos porque carregam a mesma questão: o que acontece quando alguém chega, e quando alguém sai?

**Por que importa.** `ONBO-Q13` é o caso de uma coordenação que muda de mãos. Hoje, uma biblioteca cuja pessoa coordenadora desaparece não tem caminho escrito. É exatamente o risco que **A1** descreve na escala da rede, desta vez na escala de uma biblioteca.

**O que conta como terminado.**

- A transferência de mandato tem um caminho escrito e testado em `blmf-teste`.
- `#111` tem um veredicto: reativada, ou fechada.
- O módulo 10 está terminado.

**Dependências.** Esclarecido por **G3** (o circuito de convite é o mesmo).

*Remissões : `REGISTRE §26 ONBO-Q13` · `spec-onboarding-biblioteca-v2.0`*

---

### H — Interoperabilidade, tesauro, coleta

*Sair em direção aos outros catálogos, e aceitar ser apontado de volta.*

| | | | |
|---|---|---|---|
| **H1** | Reparar a coleta dos 158 descritores de datas do tesauro | `P1` | Aberto |
| **H2** | Colocar à FICEDL as sete questões que bloqueiam a exportação do tesauro | `P1` | Bloqueado |
| **H3** | Publicar as correspondências para o tesauro FICEDL em SKOS | `P1` | Aberto |
| **H4** | Expor o catálogo em OPDS | `P1` | Aberto |
| **H5** | Testar a coleta OAI-PMH nos dois sentidos | `P2` | Aberto |
| **H6** | Alinhar os vocabulários militantes que não se conhecem | `P2` | Aberto |
| **H7** | Decidir o destino do texto de convenções de interoperabilidade | `P1` | Decisão coletiva |

#### H1 — Reparar a coleta dos 158 descritores de datas do tesauro

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : Deno / TypeScript, biblioteconomia

**Estado verificado em 29/08.** `parseDescriptor` sai por retorno antecipado antes de alcançar o título de página quando uma ficha não tem bloco de tradução. Resultado: **158 descritores da faceta «datas», ou seja um quarto do tesauro, são registrados como identificadores nus, sem rótulo, portanto não alinháveis.** Seus vínculos com os catálogos se perdem da mesma forma. A correção `ficedl_scrape_titre_dates.patch` existe, passa `node --check`, e **nunca foi testada contra o site**.

**O que é.** Aplicar a correção, que capta o título de página antes dos retornos antecipados e o guarda num campo `title_fr` **distinto de `labels`** — uma data tem um rótulo canônico mas não uma tradução.

**Por que importa.** Um quarto do tesauro está hoje inutilizável. E é preciso repará-lo **no momento de uma coleta já prevista**, não lançando 620 requisições especialmente: o provedor do tesauro sinalizou uma carga de robôs excessiva.

**O que conta como terminado.**

- Os 158 descritores de datas trazem um rótulo.
- A verificação se fez durante uma coleta prevista.
- Duas armadilhas do script de sincronização a não redescobrir: **sempre passar `--json` explicitamente** (um arquivo sem data ordena antes dos arquivos datados) e **nunca usar `--prune`** (suprimiria descritores referenciados por `subject_ficedl_links`).

**Dependências.** Previsto para a semana de 14/09. Abandonável sem arrependimento se faltar tempo antes de Bolonha.

*Remissões : `REPRISE_claude_code_2026-08-27 chantier 3` · `NOTE_export_thesaurus_questions_ouvertes_2026-08-28`*

#### H2 — Colocar à FICEDL as sete questões que bloqueiam a exportação do tesauro

`P1` Prioritário · Estado : **Bloqueado** · Carga : uma noite · O que exige : deliberação coletiva

**Estado verificado em 29/08.** A exportação completa dos 620 descritores nos dois formatos está a **uma noite de trabalho** — assim que as sete questões tiverem resposta. Estão escritas e ninguém ainda as colocou.

**O que é.** As sete: a forma dos identificadores; **a hierarquia, que é a verdadeira questão**; o estatuto da faceta «datas»; o destino dos 2 842 vínculos para seis catálogos; o grego romanizado; a licença; e a maneira como o arquivo se regenera.

**Por que importa.** De 148 descritores com rótulo arborescente, **93 pais são encontrados e 55 são inencontráveis**: «arte», «economia», «guerras», «literatura», «imprensa», «sindicalismo» não são descritores, ou têm outro nome. Visto de fora, **a hierarquia não é um dado, é uma convenção de exibição numa cadeia de caracteres** — e não se pode escrever `skos:broader` honestamente sobre isso. Só a FICEDL pode dizer se o site mantém uma verdadeira relação pai-filho.

**O que conta como terminado.**

- As sete questões estão colocadas, com a auditoria de qualidade produzida na primeira coleta em anexo — **as correções pertencem à fonte, não às cópias**.
- Quatro anomalias vistas de passagem são reportadas: dois sites diferentes sob o mesmo rótulo «catálogo do CCL»; os arquivos do *Monde libertaire* aparecendo duas vezes por termo sob duas formas de endereço; `mot228` («populações autóctones») presente em duas facetas; 29 rótulos portugueses com asterisco, ponto de interrogação ou espaço final.
- A questão 7 é a mais rentável: um esqueleto SPIP que imprime os termos em CSV resolve também a carga de robôs — **uma requisição em vez de 620, por consumidor e por atualização**, para meia jornada de trabalho do lado da FICEDL.

**Dependências.** Bloqueia **H3**. A colocar em Bolonha ou antes.

*Remissões : `NOTE_export_thesaurus_questions_ouvertes_2026-08-28`*

#### H3 — Publicar as correspondências para o tesauro FICEDL em SKOS

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : biblioteconomia, Deno / TypeScript

**Estado verificado em 29/08.** 98 alinhamentos existem no banco entre os assuntos locais e os descritores FICEDL, em `exact` ou `close`. O vocabulário de assunto do AnarBib já está exposto em SKOS. **As correspondências para a FICEDL não estão.**

**O que é.** Expor `subject_ficedl_links` em `skos:exactMatch` e `skos:closeMatch`. **Um alinhamento parcial vale mais que nenhum alinhamento** — é a convenção 2 do texto de interoperabilidade, e se aplica primeiro a nós.

**Por que importa.** É o que permite que um acervo catalogado com um vocabulário local continue encontrável por quem não conhece esse vocabulário — e em dez línguas, já que o tesauro já está traduzido. Algumas horas para um primeiro fluxo.

**O que conta como terminado.**

- Um arquivo SKOS é servido pelo aplicativo, num endereço estável.
- Distingue `exactMatch` de `closeMatch`.
- Não afirma nada sobre a hierarquia enquanto **H2** não tiver respondido.

**Dependências.** A parte hierarquia depende de **H2**. A parte correspondências, não.

*Remissões : `docs/CHANTIERS_OUVERTS.md §4` · `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26 convention 2`*

#### H4 — Expor o catálogo em OPDS

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : Deno / TypeScript

**Estado verificado em 29/08.** O ponto de acesso OAI-PMH está implantado. **OPDS não existe.** Ora, «os fluxos OPDS existem de um lado e de outro mas não apontam para lugar nenhum», e é a convenção 1 do texto proposto aos outros catálogos.

**O que é.** Um fluxo OPDS 1.2 ou 2.0 sobre o catálogo público, com as facetas já disponíveis. Algumas horas para um primeiro fluxo.

**Por que importa.** OPDS é o que os leitores digitais e os aplicativos de leitura leem. É o formato pelo qual um acervo digitalizado se torna consultável sem passar pela nossa interface — e é a primeira das quatro convenções que o AnarBib propõe aos outros. **Seria difícil propô-la sem aplicá-la.**

**O que conta como terminado.**

- Um fluxo OPDS é servido e legível por pelo menos um cliente real.
- Respeita a visibilidade: nada que já não seja público sai.

**Dependências.** Nenhuma.

*Remissões : `docs/CHANTIERS_OUVERTS.md §4` · `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26 convention 1`*

#### H5 — Testar a coleta OAI-PMH nos dois sentidos

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : Deno / TypeScript, administração de sistemas

**Estado verificado em 29/08.** O caminho está executável desde 28/08: função `harvest-oai-pmh` implantada, cron `anarbib-oai-harvest-weekly` posto. **O cron nunca rodou** — primeira ocorrência prevista para terça-feira às 04h20. E o ponto de acesso `oai-pmh-provider` **nunca foi coletado de fora**.

**O que é.** Esperar a primeira passagem do cron e ler o que ela traz. Em paralelo, coletar nosso próprio ponto de acesso a partir de uma máquina de terceiro, com um cliente OAI padrão, e verificar que os registros estão conformes.

**Por que importa.** Um ponto de acesso nunca coletado é um ponto de acesso do qual se ignora se funciona. É o mesmo esquema do circuito de convite: construído, declarado, jamais percorrido. E a limitação de taxa não está em vigor — o plugin `caddy-ratelimit` não está embutido na imagem `caddy:2`, o que deixa o ponto de acesso público sem limite.

**O que conta como terminado.**

- O cron rodou pelo menos uma vez e seu resultado está lido.
- Uma coleta externa foi bem-sucedida, com o relatório escrito.
- A limitação de taxa tem um veredicto: restabelecida no dia em que a coleta incomodar, ou assumida.

**Dependências.** A limitação de taxa está ligada a **I2**.

*Remissões : `Relevé du 29/08/2026` · `REPRISE_bascule_autohebergee_2026-08-26` · `spec-oai-provider-gouvernance.md`*

#### H6 — Alinhar os vocabulários militantes que não se conhecem

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia, deliberação coletiva

**Estado verificado em 29/08.** A NORLA construiu seu vocabulário — com suas facetas *Tactics* e *Social Movement* — **sem vínculo com o tesauro FICEDL**. Dois vocabulários militantes, construídos em paralelo, que se ignoram. Além disso, as 11 categorias temáticas do AnarcosyndicalismeBOOK não estão alinhadas a nada.

**O que é.** Começar pelo menor e mais viável: as 11 categorias do AnarcosyndicalismeBOOK, **um primeiro passo concreto, delimitado, viável numa noite** — e como o tesauro já está em dez línguas, o alinhamento vale simultaneamente para as dez. Depois abrir a conversa com a NORLA.

**Por que importa.** Cada vocabulário construído isoladamente é um acervo que os outros não encontrarão. Reserva a ter em mente: os vocabulários de efêmeros são **monolíngues**, o alinhamento será mais pesado neles do que em assuntos.

**O que conta como terminado.**

- As 11 categorias do AnarcosyndicalismeBOOK estão alinhadas.
- Uma conversa está aberta com a NORLA sobre o alinhamento das facetas.
- A reciprocidade é pedida: **os catálogos parceiros não apontam de volta** hoje.

**Dependências.** Outubro-novembro, se Bastien topar. Ligado a **D4**.

*Remissões : `ORIENTATION_outils_bibliotheques_militantes_2026-08-26 §6` · `VEILLE_leftovers_maydayrooms_2026-08-19`*

#### H7 — Decidir o destino do texto de convenções de interoperabilidade

`P1` Prioritário · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : deliberação coletiva

**Estado verificado em 29/08.** `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26` é um **rascunho que não compromete ninguém e nunca foi discutido com nenhuma organização**. Propõe quatro convenções e um pedido único à FICEDL.

**O que é.** Retirar as notas de trabalho, levar o texto a Bolonha, e deixá-lo ser retomado coletivamente — ou arquivado.

**Por que importa.** Duas coisas estão escritas e merecem ser mantidas. Por um lado, **um texto que convida outras ferramentas a se apoiarem no tesauro exige uma posição da federação, não um sinal verde individual** — é uma questão de assembleia. Por outro, **se o texto se tornar útil, deverá deixar de ser o de quem o escreveu**. Sem lista de signatários: aplicar uma convenção se constata olhando um catálogo, não consultando um registro.

**O que conta como terminado.**

- As notas de trabalho estão retiradas.
- O texto foi apresentado em Bolonha e seu destino está decidido.
- Esperar que a **convenção 4 — aceitar ser apontado de volta** — seja a mais discutida: é a que mais custa aos catálogos estabelecidos e mais rende aos recém-chegados. **Não retirá-la por essa razão.**

**Dependências.** Bolonha, 12-13/09.

*Remissões : `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26`*

---

### I — Auto-hospedagem, operação, backups, CI

*Congelado até 14/09/2026 na produção. O trabalho em ambiente de teste continua aberto.*

| | | | |
|---|---|---|---|
| **I1** | Alinhar a imagem GoTrue com o estado real das migrações de autenticação | `P1` | Congelado |
| **I2** | Concluir a migração para a auto-hospedagem | `P1` | Congelado |
| **I3** | Testar o roteador `main` da pilha auto-hospedada | `P1` | Congelado |
| **I4** | Terminar a testemunha de proveniência dos backups | `P1` | Aberto |
| **I5** | Fazer saber que um workflow falhou | `P1` | Aberto |
| **I6** | Purgar os registros da sonda de saúde | `P2` | Aberto |
| **I7** | Recolocar na integração contínua as seis suítes SQL esquecidas | `P1` | Aberto |
| **I8** | Pôr `deploy/README.md` de acordo com o que foi executado | `P2` | Aberto |
| **I9** | Corrigir as três migrações datadas no futuro | `P2` | Aberto |
| **I10** | Limpar os rastros do Turnstile e os arquivos de refugo | `P2` | Aberto |
| **I11** | Sair do `node:20`, em fim de manutenção | `P2` | Aberto |
| **I12** | Automatizar a atualização do espelho frio | `P2` | Aberto |
| **I13** | Terminar a migração para o novo motor de páginas | `P3` | Aberto |

#### I1 — Alinhar a imagem GoTrue com o estado real das migrações de autenticação

`P1` Prioritário · Estado : **Congelado** · Carga : alguns dias · O que exige : administração de sistemas

**Estado verificado em 29/08.** A produção traz **77 migrações `auth`**, a última datada de 25/06. A imagem fixada em `deploy/.env` é `GOTRUE_TAG=v2.189.0`, que traz **69**. `deploy/.env.example` indica `v2.192.0`. A diferença é um **bloqueio de correção**, não de conforto.

**O que é.** Um método que **se mede e não se adivinha**: subir um patamar, iniciar num volume virgem, `select count(*) from auth.schema_migrations;`, recomeçar até atingir pelo menos 77.

**Por que importa.** A regra é simples e absoluta: **a imagem deve ser superior ou igual à produção, nunca o contrário.** Uma imagem atrasada inicia sobre um esquema que não conhece e pode corrompê-lo ao tentar migrá-lo.

**O que conta como terminado.**

- Um tag é escolhido, com a contagem medida em cada patamar escrita.
- `deploy/.env.example` está corrigido e a documentação de `deploy/` acompanha.
- As doze últimas versões de produção estão listadas para conferência.

**Dependências.** **Congelado na produção até 14/09.** O trabalho em ambiente de teste está aberto. Primeiro elo da cadeia de migração.

*Remissões : `REPRISE_bascule_autohebergee_2026-08-26 §1`*

#### I2 — Concluir a migração para a auto-hospedagem

`P1` Prioritário · Estado : **Congelado** · Carga : várias semanas · O que exige : administração de sistemas

**Estado verificado em 29/08.** A pilha está reduzida de doze a **seis contêineres** (`db`, `rest`, `auth`, `storage`, `functions`, `caddy`), as versões estão fixadas, `bootstrap.sh` foi executado de verdade em 26/08 com oito defeitos levantados e corrigidos, e o ensaio de 18/08 reexecutou 124 migrações e restaurou um dump de produção em 17 segundos. Reconstrução completa medida: **25 minutos**.

**O que é.** O que resta: desacoplar a cadeia de implantação da integração contínua (**extração, não criação** — `scripts/ci/deployer-backend.sh` já existe), colocar um proxy reverso com túnel na frente da pilha, passar de tags para impressões `sha256`, e refazer o ensaio a frio um mês depois para verificar que nada divergiu.

**Por que importa.** É o objetivo que o projeto se deu e que ainda não atingiu: o fim da dependência de um provedor terceiro. **É o canteiro mais técnico e mais autônomo do lote** — alguém pode assumi-lo sem coordenação.

**O que conta como terminado.**

- A pilha roda atrás de um proxy reverso, com as versões em impressões.
- Uma reconstrução completa foi refeita um mês após a primeira.
- Guarda a preservar imperativamente: o laço de implantação percorre `supabase/functions/*/` **excluindo `_shared` e `main`** — sem o que o roteador iria para o Supabase hospedado.
- Armadilha já encontrada: os papéis de serviço não têm senha na imagem `supabase/postgres` (SQLSTATE 28P01 em laço), `postgres` não é superusuário (é `supabase_admin`), `authenticator` é reservado, e um `set -e` no laço mata o script no primeiro papel em falha.

**Dependências.** **Congelado na produção até 14/09.** Depende de **I1**. A fazer antes de alugar o que quer que seja: retomar a conexão autenticada em local, bloqueada por uma resolução IPv6 sem rota — **esse bloqueio provavelmente desapareceu sozinho**, verificá-lo custa cinco minutos e pode poupar uma máquina montada à toa.

*Remissões : `docs/CHANTIERS_OUVERTS.md §2` · `deploy/README.md` · `REPRISE_bascule_autohebergee_2026-08-26`*

#### I3 — Testar o roteador `main` da pilha auto-hospedada

`P1` Prioritário · Estado : **Congelado** · Carga : uma noite · O que exige : Deno / TypeScript

**Estado verificado em 29/08.** `supabase/functions/main/index.ts` existe (6,9 KB), lê `config.toml` na inicialização, aplica uma **recusa por omissão** — só as dispensas `verify_jwt = false` são lidas, todo o resto exige um token — e recusa iniciar se o arquivo for ilegível. **Os quatro testes previstos não foram feitos.**

**O que é.** Os quatro testes da etapa 5 de `deploy/REPETITION.md`: função protegida sem cabeçalho de autorização → 401; com um token válido → 200; `health-probe` sem token → 200; nome inexistente → 404.

**Por que importa.** O roteador é o que substitui a proteção por omissão da plataforma no dia da migração. Como `config.toml` só declara 31 funções de 48, **a recusa por omissão do roteador fechará dezoito funções que hoje funcionam** — é preciso saber isso antes, não depois.

**O que conta como terminado.**

- Os quatro testes passam.
- O comportamento para as 18 funções não declaradas é conhecido e desejado.

**Dependências.** **Bloqueado por B6.** Congelado na produção até 14/09; o teste em ambiente de teste está aberto.

*Remissões : `deploy/README.md` · `deploy/REPETITION.md étape 5`*

#### I4 — Terminar a testemunha de proveniência dos backups

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado verificado em 29/08.** A migração `20260827180000_temoin_sauvegarde_provenance.sql` está **testada num PostgreSQL 16 descartável, com sete controles passados, mas nunca executada contra a produção**. A correção `health_probe_provenance.patch` **não se aplica**: `patch failed … index.ts:286`. Foi produzida contra o espelho GitHub.

**O que é.** Desempatar o conflito por `git hash-object` no arquivo alvo, comparado ao blob de base `0d00dc0e016fdfb86ef314e4e707abd4a84d1d2c`. **Impressão idêntica → `git apply --3way` passa. Impressão diferente → refazer a correção à mão sobre a versão real: não forçar, não sobrescrever.** Depois implantar `health-probe`.

**Por que importa.** O que a correção deve obter, seja qual for o caminho: no e-mail, cada fluxo exibe seu host (ou «nenhum») e uma menção explícita quando se trata de uma semeadura; na razão de backup, `(última fonte: …)` ou `(nenhum sinal recebido)`. Sem isso, um e-mail verde não diz de onde vem o verde — e é exatamente o defeito que deixou os backups falharem 36 horas em silêncio.

**O que conta como terminado.**

- A migração está em `supabase/migrations/` e aplicada.
- `health-probe` está implantada com o comportamento de proveniência.
- **`temoin_sauvegarde_provenance.patch` está vencido: ignorar, não aplicá-lo.**

**Dependências.** Não confundir com o `snapshot_id` nulo em cinco linhas: o remédio cabe em três linhas mas **`anarbib-bg2.sh` vive na estação de trabalho, fora do repositório** — é para sinalizar, não para tentar a partir do repositório.

*Remissões : `NOTE_temoin_sauvegarde_2026-08-27` · `REPRISE_claude_code_2026-08-27 chantier 1`*

#### I5 — Fazer saber que um workflow falhou

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado verificado em 29/08.** Um job de alerta existe nos dois workflows: abre uma issue na forja, com antiduplicação. No entanto `sql-tests` **ficou vermelho de 17 a 20 de agosto sem que ninguém visse**. A constatação escrita é clara: «mesmo ponto cego dos backups, e não está coberto».

**O que é.** Fazer o alerta sair da forja: um e-mail, ou o mesmo canal dos alertas de backup. Uma issue aberta num repositório que ninguém vigia não alerta ninguém.

**Por que importa.** O princípio já está escrito para os backups: **um alarme jamais disparado não é um alarme.** E um pipeline que falha uma vez em duas deixa de ser lido — que é exatamente o que aconteceu.

**O que conta como terminado.**

- Uma falha de workflow produz um sinal fora da forja.
- O sinal foi testado disparando-o deliberadamente.
- Lição de método já paga: **não entregar CI sem tê-la visto passar em verde e em vermelho.**

**Dependências.** Nenhuma.

*Remissões : `RUNBOOK_exploitation_v0.3 §7 §9.3` · `REGISTRE §38 OPS-6`*

#### I6 — Purgar os registros da sonda de saúde

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** `service_health_probes` traz **13 932 linhas** e cresce 288 por dia, sem nenhum cron de purga — enquanto sete outras purgas existem nos 36 jobs.

**O que é.** Um cron de purga no modelo de `anarbib-catalog-audit-snapshot-purge`, com uma retenção a decidir — trinta dias provavelmente bastam, já que os incidentes são conservados à parte em `service_health_incidents`.

**Por que importa.** É a tabela mais volumosa do banco, e só contém ruído do qual o útil já foi extraído. Nesse ritmo alcançará cem mil linhas antes do fim do ano, o que pesará em cada backup à toa.

**O que conta como terminado.**

- Um cron de purga existe, com uma retenção escrita.
- `service_health_incidents` não é tocada pela purga.

**Dependências.** Nenhuma.

*Remissões : `Relevé du 29/08/2026` · `REGISTRE §38 OPS`*

#### I7 — Recolocar na integração contínua as seis suítes SQL esquecidas

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado verificado em 29/08.** 43 suítes de testes SQL existem em `tests/sql/`. O manifesto `ci-suites.txt` só ativa **37**. As seis ausentes são as mais antigas: `paquet19_loan_wrappers_tests.sql` (32 KB), `paquet24_consulta_helpers_tests.sql`, `paquet25_consulta_wrappers_tests.sql` (25 KB), `paquet26_consulta_notification_triggers_tests.sql`, `paquetA1_cancel_note_required_tests.sql`, `paquetA_profils_tests.sql`.

**O que é.** Reexecutá-las uma a uma, reparar as que falham, e recolocá-las no manifesto. Se uma estiver obsoleta, suprimi-la em vez de deixá-la no lugar sem execução.

**Por que importa.** São precisamente as suítes que cobrem os empréstimos e as consultas — o coração da circulação. Uma suíte presente mas não executada é pior que uma suíte ausente: dá a impressão de que o domínio está coberto.

**O que conta como terminado.**

- `ci-suites.txt` lista 43 suítes, ou menos com as supressões justificadas.
- O arnês passa em verde com o conjunto.
- Colocar também o stub `storage` ausente ao lado dos stubs `auth` e `vault` — sem ele, toda migração que toca `storage.*` precisa se guardar sozinha.

**Dependências.** Nenhuma.

*Remissões : `Relevé du 29/08/2026` · `PLAN_DE_MARCHE §8 §9`*

#### I8 — Pôr `deploy/README.md` de acordo com o que foi executado

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado verificado em 29/08.** O documento afirma em negrito: «Nada disso ainda rodou». Três commits de 26/08 descrevem execuções reais com oito defeitos levantados. Além disso `bootstrap.sh` tem **oito etapas** mais uma «7 bis» e uma verificação, onde o README anuncia sete; e o README declara `notify-cross-library-digest` «ausente do repositório» quando ela está lá.

**O que é.** Reescrever a seção de estado a partir dos diários de execução de 26/08, corrigir a contagem de etapas, e retirar a afirmação sobre `notify-cross-library-digest`.

**Por que importa.** `deploy/README.md` é o documento que lerá quem assumir **A2** — a reconstrução por um terceiro. Uma frase que diz «nada rodou» vai fazê-lo crer que está abrindo caminho quando oito defeitos já foram encontrados e corrigidos para ele.

**O que conta como terminado.**

- A seção de estado descreve o que rodou e o que não rodou.
- Os quatro pontos «a confirmar antes da migração» têm um veredicto: GoTrue e o e-mail, `PGRST_DB_SCHEMAS` posto em `public,api,storage` por dedução, o caso `notify-cross-library-digest` (encerrado), e a reexecução das migrações.
- `CADDY_TAG=2` é um tag maior flutuante num arquivo que proclama «nenhum `latest`, jamais»: a fixar ou a justificar.

**Dependências.** Pré-requisito moral de **A2**.

*Remissões : `deploy/README.md` · `Commits 57321385, 35c03dd5, 90266600`*

#### I9 — Corrigir as três migrações datadas no futuro

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado verificado em 29/08.** `20260830090000`, `20260830110000` e `20260830130000` estão aplicadas em produção enquanto a data de hoje é **29/08**. Trazem um carimbo do dia seguinte.

**O que é.** Nada a desfazer — as migrações estão aplicadas e funcionam. O que é preciso é compreender de onde vem o descompasso (fuso horário da estação, ou escolha manual) e colocar uma guarda.

**Por que importa.** O nome de uma migração é também sua posição na ordem de reexecução. Um carimbo adiantado em relação ao relógio cria uma janela em que uma migração escrita depois ordena antes dela. A doutrina já diz para verificar o carimbo UTC antes de escolher — a guarda falta.

**O que conta como terminado.**

- A causa está identificada.
- O hook `pre-commit` recusa uma migração cujo carimbo esteja no futuro.

**Dependências.** Nenhuma.

*Remissões : `Relevé du 29/08/2026` · `REPRISE_claude_code_conventions_2026-08-20`*

#### I10 — Limpar os rastros do Turnstile e os arquivos de refugo

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado verificado em 29/08.** O Turnstile foi inteiramente retirado do código em 20/08 — sua reaparição seria uma regressão. Mas **chaves de teste subsistem** em `.env.example` (duas entradas), `.env.local`, `deploy/functions.env`, uma referência em `package.json`, e um segredo no Vault. Além disso `tmp-ficedl/` (754 KB, duplicata exata de um arquivo versionado) fica na raiz, e `docs/drafts/` está versionado sem regra.

**O que é.** Retirar os cinco rastros, suprimir `tmp-ficedl/` (ignorado pelo git desde 28/08, portanto sem risco), e decidir o estatuto de `docs/drafts/`: ou é uma antecâmara e se ignora, ou é conteúdo e se documenta.

**Por que importa.** Uma chave de teste num arquivo de exemplo é o que copiará a próxima pessoa que instalar o projeto. E `docs/drafts/` é exatamente o lugar onde o SQL dos assuntos SOLIDAIRES se perdeu (ver **C1**): uma pasta sem regra é uma pasta onde as coisas ficam.

**O que conta como terminado.**

- Nenhum rastro do Turnstile fora do histórico git.
- `tmp-ficedl/` desapareceu do disco.
- `docs/drafts/` tem uma regra escrita: o que entra sai, ou não entra.

**Dependências.** Nenhuma.

*Remissões : `RUNBOOK_exploitation_v0.3 §9.8` · `PLAN_DE_MARCHE §7.4` · `Relevé du 29/08/2026`*

#### I11 — Sair do `node:20`, em fim de manutenção

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado verificado em 29/08.** Os três jobs de integração contínua rodam num contêiner `node:20`, cuja janela de manutenção de longo prazo terminou em abril de 2026. É o ponto de fim de vida mais claro da cadeia.

**O que é.** Passar para a versão em manutenção longa seguinte, verificar que o build, os testes e o lint passam, e que a CLI Supabase fixada `v2.98.1` se instala nela.

**Por que importa.** Uma imagem sem atualizações de segurança faz rodar toda a implantação. A mudança é mecânica e se verifica numa execução.

**O que conta como terminado.**

- Os três jobs rodam numa versão mantida.
- O lint continua com zero erro (cerca de cem avisos é o estado normal).

**Dependências.** Nenhuma.

*Remissões : `.forgejo/workflows/ci.yml` · `package.json`*

#### I12 — Automatizar a atualização do espelho frio

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado verificado em 29/08.** O espelho frio `anarbib-mirror.git` existe na estação de trabalho e sua atualização é manual. As unidades systemd `anarbib-mirror-refresh.service` e `.timer` estão versionadas em `deploy/ops/` mas sua entrada em serviço não está confirmada.

**O que é.** Verificar se o temporizador roda, e senão colocá-lo em serviço. Registrar o frescor do espelho em algum lugar legível.

**Por que importa.** Uma reconstrução exige **três** coisas e não duas: o repositório, um backup, **e os segredos do Vault**. O espelho frio é a terceira cópia do repositório, depois do Codeberg e do espelho GitHub. Só serve se estiver atualizado — e o espelho GitHub já acumulou 6 878 objetos de atraso uma vez.

**O que conta como terminado.**

- A atualização é automática e sua falha alerta.
- O frescor do espelho aparece na testemunha de backup.

**Dependências.** Ligado a **I4**.

*Remissões : `RUNBOOK_exploitation_v0.3 §4 §9.1`*

#### I13 — Terminar a migração para o novo motor de páginas

`P3` Adiado · Estado : **Aberto** · Carga : alguns dias · O que exige : administração de sistemas

**Estado verificado em 29/08.** A etapa 0 é conclusiva desde 20/08: `test.anarbib.org` é servido pelo novo motor em paralelo. A cadeia de integração contínua já usa a ação `git-pages`. **O Codeberg Pages em versão histórica está em modo de manutenção, não em fim de vida** — a documentação diz que continuará funcionando indefinidamente.

**O que é.** Colocar o registro TXT de lista branca, criar `public/_redirects` com a regra de reescrita, verificar que uma rota desconhecida retorna 200 com o conteúdo certo, depois limpar **somente após** verificação verde.

**Por que importa.** Dois pontos de vigilância estão escritos. **Não tocar nos registros A e AAAA**, que estão bons. E **verificar a caixa do URL**: o workflow escreve `AnarBib`, a documentação escreve `anarbib` — na dúvida, colocar os dois registros TXT.

**O que conta como terminado.**

- O site é servido pelo novo motor, com as rotas desconhecidas em 200.
- A limpeza é feita após verificação: `public/.domains`, o branch `pages`, os segredos que se tornaram inúteis.
- **Deixar `public/CNAME`** — serve ao espelho GitHub.
- Incertezas assumidas: a reversibilidade da migração não está documentada em lugar nenhum, nenhum limite numérico está publicado (tamanho, banda, prazo), e os arquivos vendorizados pesam — **ponto a vigiar na primeira implantação**.

**Dependências.** P1, não P0 — a versão histórica não tem data de encerramento anunciada.

*Remissões : `PLAN_migration_git_pages_2026-08-19` · `RUNBOOK_exploitation_v0.3`*

---

### J — Documentação e corpus

*O corpus é vasto e sua deriva é medida. Este backlog faz parte dele.*

| | | | |
|---|---|---|---|
| **J1** | Atualizar os números de `CLAUDE.md` e do `README.md` | `P1` | Aberto |
| **J2** | Reparar o índice dos backlogs e decidir a convenção de arquivamento | `P2` | Aberto |
| **J3** | Corrigir as três afirmações falsas da spec das consultas | `P1` | Aberto |
| **J4** | Reescrever a seção 14 da spec de governança dos papéis | `P1` | Aberto |
| **J5** | Resolver as incoerências do corpus documental | `P2` | Aberto |
| **J6** | Escrever as cinco doutrinas internalizadas onde um terceiro as encontraria | `P2` | Aberto |

#### J1 — Atualizar os números de `CLAUDE.md` e do `README.md`

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado verificado em 29/08.** `CLAUDE.md` erra em sete números — entre eles a linha `verify_jwt`, que descreve uma proteção inexistente (ver **B6**). A seção de estado do `README.md` está **datada de 7 de julho de 2026**, ou seja 345 commits atrás.

**O que é.** Retomar a foto numérica deste backlog e transpô-la, datando cada número. Depois decidir se esses números têm lugar num documento que não se relê: talvez uma remissão ao backlog valha mais que uma cópia.

**Por que importa.** `CLAUDE.md` não é versionado — vive numa única máquina, retirado do repositório em 07/07. Seus números falsos só são corrigíveis por uma pessoa, e invisíveis para todas as outras. É um caso particular de **A2**.

**O que conta como terminado.**

- Os sete números estão corrigidos e datados.
- A seção de estado do `README.md` traz uma data recente.
- Uma decisão é tomada sobre o lugar onde esses números devem viver — um só.

**Dependências.** Nenhuma.

*Remissões : `Relevé du 29/08/2026` · `CLAUDE.md`*

#### J2 — Reparar o índice dos backlogs e decidir a convenção de arquivamento

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado verificado em 29/08.** A tabela de histórico de `docs/backlogs/INDEX.md` para no v31: **a linha do v32 falta**, embora o arquivo esteja em `archive/`. E duas convenções de nomenclatura dos arquivos coexistem — com ou sem o prefixo `-archive-` —, ponto aberto explícito jamais levado ao REGISTRO.

**O que é.** Acrescentar a linha do v32, as do v33 e do v34, e decidir a convenção de arquivamento numa frase inscrita no REGISTRO.

**Por que importa.** O índice dos backlogs é o que permite saber qual versão faz fé. Uma linhagem com um buraco e duas convenções concorrentes não cumpre esse ofício.

**O que conta como terminado.**

- A tabela está completa do v8 ao v34.
- Uma única convenção de nomenclatura está inscrita no REGISTRO.

**Dependências.** Faz-se ao depositar este backlog.

*Remissões : `docs/backlogs/INDEX.md`*

#### J3 — Corrigir as três afirmações falsas da spec das consultas

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado verificado em 29/08.** `spec-flux-consultations-v2.2.md` afirma, seção perfis, que a BLMF está em `full_sigb`, a BTL em `informal` e `BLT-test` em `informal`, tudo «verificado em prod». **As três são falsas hoje**: `BLT-test` não existe no banco, e a BTL está em `full_sigb`.

**O que é.** Levantar o estado real das cinco bibliotecas e transpô-lo, com a data do levantamento.

**Por que importa.** Uma afirmação marcada «verificado em prod» que já não o é é mais perigosa que uma afirmação não marcada: desencoraja a verificação. É a lição central deste backlog.

**O que conta como terminado.**

- A seção descreve o estado real, datado.
- Toda afirmação «verificado em prod» do corpus traz agora sua data.

**Dependências.** Ligado a **G5** (estatuto da BTL).

*Remissões : `PLAN_formation_coordination_BLMF §8`*

#### J4 — Reescrever a seção 14 da spec de governança dos papéis

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado verificado em 29/08.** `spec-gouvernance-roles.md` §14 lista como «a implementar» coisas **que rodam em produção**: a tabela de auditoria `library_membership_audit` (alimentada, oito entradas recentes), as colunas de carência `pending_removal_until` e `pending_removal_requested_by`, os e-mails `team.*` (21 envios, zero falha), e os dois crons `anarbib-team-pending-removal-complete` e `anarbib-team-inactive-cleanup`.

**O que é.** Reescrever as duas seções conforme o estado verificado de 26/08, e atualizar a versão — o REGISTRO já cita uma v1.4 que o índice das specs ignora.

**Por que importa.** Uma spec que subestima o entregue faz refazer o que existe. É a deriva de sentido inverso de **J3**, e as duas foram levantadas no mesmo dia.

**O que conta como terminado.**

- As §14 e §5.3 descrevem o estado real.
- A versão da spec é a mesma no REGISTRO e em `docs/specs/INDEX.md`.
- A doutrina do papel exclusivo é anotada como aplicada pela própria RPC, não apenas escrita — a promoção de 26/08 dá o rastro: linha `coordenador` criada ativa, linha `librarian` passada a `removed` no mesmo carimbo, duas entradas de auditoria, notificação em 2,5 segundos.

**Dependências.** Nenhuma.

*Remissões : `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §2` · `REGISTRE §41 GOUV`*

#### J5 — Resolver as incoerências do corpus documental

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : nenhuma competência técnica

**Estado verificado em 29/08.** Uma releitura do corpus levantou umas vinte contradições internas. As mais estruturantes: **duas seções `MAP` no REGISTRO** com vereditos inversos e sem remissão de uma à outra; **duas seções numeradas §17** (`IMP` e `PRIV`); três versões declaradas do REGISTRO (v0.1, v0.2, v0.3) conforme o índice consultado; `OAI-1` a `OAI-9` anunciados «a inscrever aqui» e nunca inscritos; **sete specs presentes em disco e referenciadas por nenhum índice**; e o índice geral que ainda designa o Woodpecker como cadeia de implantação onde o REGISTRO diz Forgejo desde 11/06.

**O que é.** Uma passagem de higiene, por ordem de gravidade: as colisões de número e de seção no REGISTRO primeiro, depois as versões declaradas, depois as sete specs órfãs, depois as remissões vencidas.

**Por que importa.** O REGISTRO faz fé: está escrito na regra de precedência, e essa regra é o que permite a alguém decidir sem perguntar. Um registro que traz duas §17 e duas seções `MAP` contraditórias não pode fazer fé nesses pontos precisos. É um defeito na única coisa que não tem direito a tê-los.

**O que conta como terminado.**

- As colisões de seção estão resolvidas, respeitando `#HYG-REG-1`: **não se renumera o normativo já inscrito**, as seções novas tomam os números seguintes.
- A §2 `MAP` traz uma remissão à §34.
- As sete specs órfãs estão referenciadas ou arquivadas.
- As remissões ao Woodpecker estão corrigidas em `docs/specs/INDEX.md` e `CONTRIBUTING.md`.
- Os dois identificadores citados mas ausentes da tabela das doutrinas — `DOC-COLLECTIVE-1` e `USER-EMAIL-1` — estão inscritos ou retirados.

**Dependências.** Nenhuma. **Entrada sem competência técnica**, mas que exige paciência.

*Remissões : `docs/specs/REGISTRE_decisions.md` · `docs/INDEX.md` · `docs/specs/INDEX.md`*

#### J6 — Escrever as cinco doutrinas internalizadas onde um terceiro as encontraria

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado verificado em 29/08.** Cinco regras de concepção são aplicadas em toda parte e escritas em nenhum lugar acessível: a ordem das atualizações numa RPC (o relato antes do estado), a distinção entre `workflow_note` e `schedule_reply_note`, a proibição de `async` em `onAuthStateChange`, as armadilhas de codificação sob PowerShell, e o contrato `actionBox` da função de renderização dos e-mails.

**O que é.** Escrevê-las no repositório, não num arquivo local. Uma página basta; cada uma cabe em três linhas e um exemplo.

**Por que importa.** Estas cinco regras vivem hoje em `CLAUDE.md`, que está **explicitamente fora do repositório**. Quem clonar o projeto nunca as verá e as infringirá, uma a uma, escrevendo código perfeitamente razoável.

**O que conta como terminado.**

- As cinco estão no repositório, alcançáveis a partir de `CONTRIBUTING.md`.
- Cada uma traz o incidente que a produziu, quando existe.

**Dependências.** Serve **A2** e **A4**.

*Remissões : `CLAUDE.md, doctrines internalisées` · `PLAN_DE_MARCHE §8`*

---

### K — Caixa, comunicação, formação

*O que decide se o projeto tem meios e braços, e não apenas código.*

| | | | |
|---|---|---|---|
| **K1** | Fazer adotar a ata de criação do Fundo AnarBib | `P0` | Bloqueado |
| **K2** | Abrir os canais de arrecadação dormentes | `P1` | Bloqueado |
| **K3** | Manter o registro público das contas | `P2` | Aberto |
| **K4** | Corrigir o gerador das páginas de privacidade sobre a língua declarada | `P2` | Aberto |
| **K5** | Realizar a intervenção de Bolonha e tirar as consequências | `P1` | Em curso |
| **K6** | Preparar o encontro com leftove.rs e May Day Rooms | `P2` | Em curso |
| **K7** | Conduzir a formação das duas coordenações BLMF até a autonomia | `P1` | Em curso |
| **K8** | Terminar o texto de orientação sobre as ferramentas de bibliotecas militantes | `P2` | Aberto |

#### K1 — Fazer adotar a ata de criação do Fundo AnarBib

`P0` Estrutural · Estado : **Bloqueado** · Carga : uma noite · O que exige : deliberação coletiva

**Estado verificado em 29/08.** Um projeto de ata está redigido e arquivado. Não foi adotado. **É o preliminar político à abertura de qualquer canal de arrecadação: nada se move antes.**

**O que é.** A ata deve fazer quatro coisas: criar o fundo, designar nominalmente a pessoa que detém a chave Pix, designar a pessoa depositária da parte europeia, e fixar o princípio do relatório anual.

**Por que importa.** As despesas de funcionamento — cerca de **36 € por mês, 430 € por ano**, integralmente lastreadas em faturas — saem hoje do bolso de uma só pessoa. Duas caixas estão previstas, com um único registro: a caixa brasileira financia as despesas locais, a caixa europeia financia a infraestrutura. **O dinheiro deve pousar onde as faturas se pagam.**

**O que conta como terminado.**

- A ata está adotada e arquivada.
- A pessoa que detém a chave Pix aceita com pleno conhecimento.
- O nome público da caixa está definido.
- **Seu artigo 1 basta sozinho para publicar um canal honestamente, se a assembleia demorar.**

**Dependências.** Bloqueia **K2**.

*Remissões : `PLAN_financement_AnarBib_2026-08-25 §9` · `MINUTA_ata_fundo_anarbib_CCLA_2026-08-26`*

#### K2 — Abrir os canais de arrecadação dormentes

`P1` Prioritário · Estado : **Bloqueado** · Carga : alguns dias · O que exige : deliberação coletiva

**Estado verificado em 29/08.** O Liberapay está no ar e recebeu sua primeira doação em 27/08. O encarte «apoiar financeiramente» está publicado nas dez locales e nomeia o Liberapay como único canal aberto. **Pix e IBAN dormem** num bloco de comentário HTML entre os marcadores `ENCART-DORMANT-START` e `ENCART-DORMANT-END`.

**O que é.** Lado Brasil: uma chave aleatória dedicada criada pela pessoa mandatada, e a abertura de uma conta no CNPJ — uma cooperativa de crédito é mais coerente que um banco comercial. Lado Europa: decidir qual conta recebe. Depois preencher os modelos, retirar os dois marcadores de comentário, e suprimir os dois parágrafos «em abertura».

**Por que importa.** O Pix não pode ser criado desde a França — a ampliação de agosto de 2026 só vale para enviar. E uma chave posta no CPF pessoal de um compa o expõe à malha fina: daí a urgência da conta no CNPJ. Sobre o IBAN, a recomendação escrita é publicá-lo **em claro** — um «pedir por e-mail» fará perder mais doações do que evitará aborrecimentos.

**O que conta como terminado.**

- Pelo menos um canal adicional está aberto e publicado nas dez locales.
- O gerador das páginas de contas foi reexecutado após cada edição de `FINANCES.md`.
- Se a resposta sobre o Wero for negativa, **a frase Wero é retirada do bloco dormente dos dez arquivos** — o modelo ainda está lá.
- Lembrete: o hook `pre-push` recusa o push enquanto um modelo estiver visível fora do bloco dormente.

**Dependências.** **Bloqueado por K1.**

*Remissões : `PLAN_financement_AnarBib_2026-08-25` · `FINANCES.md`*

#### K3 — Manter o registro público das contas

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado verificado em 29/08.** `FINANCES.md` está na raiz do repositório vitrine e dez páginas públicas são geradas a partir dele, por língua. O gerador sinaliza nominalmente toda célula não traduzida. Uma tabela distinta traz o que uma pessoa adiantou antes de o fundo existir — cerca de **228 € de março a agosto de 2026** — e a questão de saber se é uma dívida a reembolsar fica para a assembleia.

**O que é.** Registrar cada receita e cada despesa continuamente, e reexecutar o gerador após cada edição.

**Por que importa.** **Registrar os adiantamentos passados desde já, antes da deliberação** — daqui a um ano, ninguém se lembrará dos valores. O regime de transparência escolhido é o relatório anual mais as contas sob pedido; só se sustenta se o registro estiver atualizado.

**O que conta como terminado.**

- O registro está atualizado e as dez páginas refletem seu conteúdo.
- Antecipação anotada: a renovação do domínio em março de 2027 custará mais caro, a promoção do primeiro ano não se renovando.

**Dependências.** Independente de **K1** e **K2**.

*Remissões : `PLAN_financement_AnarBib_2026-08-25` · `tools/build-finances-pages.cjs`*

#### K4 — Corrigir o gerador das páginas de privacidade sobre a língua declarada

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado verificado em 29/08.** As páginas escritas à mão trazem `<html lang="pt-BR">`; `tools/build-privacy-pages.cjs` emite `lang="pt"`. **As páginas têm razão, o script está errado.**

**O que é.** Corrigir o script para que emita a etiqueta completa, e verificar que o gerador das páginas de contas, construído no mesmo modelo, não reproduza o defeito.

**Por que importa.** O atributo de língua é o que os leitores de tela usam para escolher sua pronúncia. `pt` fará ler português de Portugal para um público brasileiro. É o mesmo critério WCAG 3.1.1 que o projeto já corrigiu do lado do aplicativo.

**O que conta como terminado.**

- O script emite a etiqueta completa.
- As páginas geradas e as páginas escritas à mão concordam.

**Dependências.** Nenhuma.

*Remissões : `Dépôt vitrine anarbib/pages` · `tools/build-privacy-pages.cjs`*

#### K5 — Realizar a intervenção de Bolonha e tirar as consequências

`P1` Prioritário · Estado : **Em curso** · Carga : alguns dias · O que exige : deliberação coletiva

**Estado verificado em 29/08.** Oficina AnarBib em 12/09 pela manhã, assembleia aberta em 13. Um conjunto de 29 slides italiano-inglês está pronto, assim como um folheto manifesto bilíngue. Três objetivos anunciados: a gênese e a concepção, o panorama das funcionalidades, e **um chamado à participação**.

**O que é.** Pedir o horário de intervenção à assembleia do dia 13, cronometrar a versão italiana em voz alta, imprimir o material em papel — nem todo mundo abre um PDF numa sala —, e ensaiar a demonstração **off-line**, caso a rede falte.

**Por que importa.** O chamado à participação é o que decide **A1** e **A3**. O objetivo enunciado é que o AnarBib deixe de ser um projeto solitário: que o código evolua por contribuições humanas em vez de assistência automática, e que os custos sejam mutualizados. Ponto de vigilância: a coluna «faltando» do slide 21 está **amplamente vencida** — muito do que ela lista foi entregue desde então.

**O que conta como terminado.**

- A intervenção ocorreu e o chamado foi levado à assembleia.
- Os contatos feitos estão registrados, com o que cada um propôs.
- Sobre acessibilidade, dizer os dois: funcionalidades estão implementadas, nenhuma auditoria independente foi conduzida (ver **E1**).

**Dependências.** Congelamento do código em produção a partir de 08/09.

*Remissões : `CALENDRIER_bologne_2026-08-27` · `PLAN_intervention_FICEDL_Bologne_2026-09-12`*

#### K6 — Preparar o encontro com leftove.rs e May Day Rooms

`P2` Corrente · Estado : **Em curso** · Carga : uma noite · O que exige : deliberação coletiva

**Estado verificado em 29/08.** **A mensagem foi enviada** — por volta de 19/08, três semanas antes do encontro, exatamente a janela visada: cedo o bastante para que olhassem o AnarBib sem que fosse urgente. **A oficina AnarBib é de manhã, a oficina leftove.rs à tarde do dia 12/09, mesma sala, mesmo dia.** O que continua aberto são as respostas e a preparação do dia.

**O que é.** Retomar o contato se necessário, e preparar as três perguntas feitas para que sejam discutidas no local: o vocabulário de assuntos, o perfil de digitalização (eles têm 16 000 documentos ocerizados), e a NORLA e a cartografia. Mais a pergunta sobre auto-hospedagem ao coletivo técnico presente.

**Por que importa.** Duas oficinas no mesmo dia na mesma sala, sobre assuntos vizinhos, sem que as duas equipes tenham se falado, seria um desperdício. E há um ponto a olhar antes, não depois: **leftove.rs está sob licença CC BY-NC-SA, e a cláusula não comercial não é uma licença livre em sentido estrito.**

**O que conta como terminado.**

- As três perguntas têm resposta, ou um horário de conversa está marcado para 12/09.
- **Ponto a olhar antes do encontro, não depois**: leftove.rs está sob licença CC BY-NC-SA, e a cláusula não comercial não é uma licença livre em sentido estrito.

**Dependências.** Em 12/09, no mesmo dia. Ligado a **D4** (material efêmero) e **H6** (alinhamento dos vocabulários).

*Remissões : `VEILLE_leftovers_maydayrooms_2026-08-19` · `CALENDRIER_bologne_2026-08-27`*

#### K7 — Conduzir a formação das duas coordenações BLMF até a autonomia

`P1` Prioritário · Estado : **Em curso** · Carga : várias semanas · O que exige : deliberação coletiva

**Estado verificado em 29/08.** O material está entregue: 89 slides em português do Brasil, seis módulos, três encontros, seis exercícios práticos, notas de animação em cada slide. Nenhuma das duas pessoas é bibliotecária ou informática.

**O que é.** Antes do primeiro encontro: criar em `blmf-teste` as duas contas de coordenação, uma ou duas contas de leitura fictícias, e as cinco fichas defeituosas do exercício 2. Depois o acompanhamento de oito semanas: cinco fichas por semana **todas com sua proveniência**, um dia de balcão por semana, uma consulta conduzida de ponta a ponta com negociação real, e o voto do perfil da biblioteca levado à assembleia.

**Por que importa.** Duas pessoas autônomas na coordenação de uma biblioteca é **A1** na escala local. O princípio pedagógico cabe em três palavras — *«cliqua, não vai quebrar nada!»* — e é sustentável porque as transições impossíveis não aparecem, os botões travados vêm pré-desativados com uma explicação, e o banco recusa as combinações impossíveis. Os nove gestos irreversíveis são nomeados explicitamente.

**O que conta como terminado.**

- As oito semanas estão feitas, com o ritual semanal de trinta minutos e suas três perguntas fixas.
- A folha de lacunas alimentada por esse ritual vira a pauta seguinte **e um material de contribuição ao projeto**.
- O compromisso quantificado é cumprido: **nenhuma ficha nova sem modo de aquisição** — a recuperação retroativa das 2 450 fichas sem dado de aquisição não é pedida, só a parada da dívida é.

**Dependências.** Apoia-se em **G3** e **G4** para o ambiente de teste.

*Remissões : `PLAN_formation_coordination_BLMF_2026-08-26` · `GABARITO_exercicio2_formacao_BLMF_2026-08-26`*

#### K8 — Terminar o texto de orientação sobre as ferramentas de bibliotecas militantes

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : deliberação coletiva

**Estado verificado em 29/08.** `ORIENTATION_outils_bibliotheques_militantes_2026-08-26` é um **esqueleto destinado a ser cossinado**. Seis pontos estão explicitamente a verificar ou decidir, e a seção final — a que carrega o chamado — resta escrever.

**O que é.** Listar alguns provedores associativos, verificar a vitalidade atual do PMB, verificar a licença exata do Pandora e o que implica a entrada de um arquivo parceiro, verificar o endereço de contato da rede ALN, decidir a linha «catálogo consultável, sem empréstimo» da tabela, fazer completar a descrição do AnarcosyndicalismeBOOK, e **escrever juntos a seção final «O que falta» — é o chamado**.

**Por que importa.** Três posições do texto merecem ser mantidas tais quais. **A pergunta que decide tudo: quem vai manter o servidor, e por quanto tempo?** **Sejam honestos quanto à escala** — abaixo de algumas centenas de documentos sem empréstimo, uma planilha faz o serviço, e **o AnarBib é superdimensionado para um pequeno acervo sem empréstimo**. E a declaração de interesse explícita: os dois projetos comparados são livres, os dois são mantidos por uma só pessoa — **dizer isso vale mais que descobrir**.

**O que conta como terminado.**

- As seis verificações estão feitas.
- A seção final está escrita em conjunto.
- O texto é traduzido depois de estabilizado, não antes.

**Dependências.** Ligado a **K5** e **H7**.

*Remissões : `ORIENTATION_outils_bibliotheques_militantes_2026-08-26`*

---

## Encerramentos e entradas caducas

Estas entradas constavam no v33, em `ETAT-AVANCEMENT-multisessions`, em `ETAT-lancement-consolide` ou nas notas de agosto. Estão encerradas, verificadas em 29/08. São listadas para que ninguém as reabra achando ter encontrado um esquecimento.

| | | |
|---|---|---|
| #25 · #33 | Mensalidades: cron de expiração e teste de bloqueio | Entregues em 03/07. O cron `anarbib-membership-expiry-daily` roda às 6h40. |
| #4 | Os cinco entregáveis da sessão de junho | Integrados em 03/07 (commit `cd5c7d967`). Atenção: o identificador `#4` designa dois objetos diferentes conforme o documento — este e um item sem título do v32. |
| #5 | Performance do casamento na importação | Partes A, B e C confirmadas em 03/07; o remendo `statement_timeout=0` foi substituído por um limite de 120 s (migração `20260703182035`). |
| AR-1 · AR-2 | Piso de duração no login, retirada do Turnstile | Feitos em 20/08. O Turnstile foi retirado do cliente e do servidor, **sem substituto**: sua reaparição seria uma regressão. |
| AR-3 · AR-4 | Altcha auto-hospedado e antirreexecução | Função implantada em 19/08, migração `altcha_anti_rejeu` aplicada em 20/08. |
| Crons RGPD n°6 e n°7 | «Desativados — a esclarecer» | **Falso.** Os 36 jobs estão ativos. Entrada caduca. |
| Três crons de governança | «Desativação deliberada ou esquecimento? A decidir pela coordenação» | Reativados por `20260821070000` e `20260827080000`. Nenhuma decisão está pendente. |
| login-with-identifier | Duplicata de função Edge a suprimir | **A função não existe.** Só `login` está implantada. |
| fn_v2_set_reserva_linhas_workflow | Coexistência das assinaturas de 5 e 7 argumentos | **Existe uma única assinatura.** E não há mais nenhuma duplicata de assinatura nos quatro esquemas aplicativos. |
| _backup_*_20260408 | Tabelas de refugo a limpar | Nenhuma existe em `public`. Resta `backup_2026_05_07`, que é o item **B9**. |
| api.resolve_reader_card | Resolução de carteirinha ausente | Entregue. Migração `20260821020000_resolve_reader_card_motif_neutre` aplicada em 21/08. |
| Teto dos PDF | «Elevar de 300 para 500 MB — um número numa migração, cinco minutos» | Feito em 20/08 (`plafond_pdf_500mo_recueils_illustres`). |
| Lote «vocabulário dos direitos» | «Doze arquivos no disco, a commitar» | Commitado e aplicado em 20/08 (`vocabulaire_rights_status`). Resta a colisão de nome, item **C10**. |
| Seis migrações de convenções | «Escritas, nunca aplicadas» | **Dezenove migrações `conventions_*` aplicadas em 21/08.** O canteiro foi bem além. Resta a revisão humana, item **C3**. |
| Colegialidade da promoção | «Migração escrita, não aplicada» + runbook em 11 etapas | Aplicada em 26/08. O runbook está caduco; restam o ensaio (**G3**) e a decisão política (**G2**). |
| Periódicos P1 a P9 | «Nove pacotes a entregar» | **Os nove entregues em 27-28/08.** Resta a revisão da spec, item **D1**. |
| notify-cross-library-digest | Função apontada como ausente do repositório | Presente, implantada, confirmada três vezes. **Não suprimir nada.** |
| #PUBLIB · #FED · #ASSEMBLEIAS · #THES · #GAZ · #MOBILE (socle) | Macrocanteiros do v33 | Entregues e em produção. A nuançar num ponto: vários desses circuitos **nunca foram percorridos** — é o item **G1**, que não é uma reabertura mas uma constatação de uso. |
| npm ci | Reparo das dependências locais | Feito em 27/08. `@supabase/auth-js` recuperou seu ponto de entrada. **Não reexecutar sem motivo.** |
| Encarte de apoio financeiro | «A redigir nas dez locales» | Publicado em 26/08 (`47d23fa`). Liberapay no ar, primeira doação recebida em 27/08. Registro público em vigor desde 27/08. |
| A5 | Configuração git com dois URLs de push | **Já corrigido.** Constatado em 29/08 em `.git/config`: `origin` traz um único URL de push (Codeberg) e o GitHub é um remote nomeado à parte. A correção prevista após os quatro incidentes de 19/08 foi aplicada. Não há mais alias `git publish-app`: empurra-se explicitamente para os dois remotes. |
| B1 | Oito tabelas do esquema `ingest` sem RLS | **Entregue em 29/08** — migração `20260830140000_ingest_ne_depend_plus_d_un_grant`, suíte `ingest_ferme_tests.sql` (7 testes) no manifesto, hook `pre-commit` estendido a `ingest`. Verificado no banco após a implantação: 10 tabelas sob RLS, nenhuma em FORCE, as 2 172 linhas de staging e os 2 084 vínculos intactos. **Mas a ficha errava no essencial**: `anon` e `authenticated` nunca tiveram `USAGE` nesse esquema, portanto nenhuma falha estava aberta. O pacote é um segundo ferrolho, não uma correção. |

---

## O que não está no backlog

Três coisas não estão no backlog, e é preciso dizê-lo para que ninguém as recoloque nele.

**As decisões registradas no REGISTRO não se reabrem de passagem numa tarefa.** `text` + `CHECK` em vez de um tipo enumerado PostgreSQL, a caixa natural no banco com a renderização calculada na exibição, a ausência de captcha hospedado por terceiros, o opt-in estrito da carta, a recusa do pagamento on-line self-service, a ausência de hierarquia à moda da Library of Congress para as coletividades — são posições, não escolhas por omissão. Reabrem-se por uma decisão inscrita no REGISTRO, nunca por uma correção.

**As tarefas de revisão humana não viram scripts.** O SQL de aplicação das três tabelas `conv_backup` está comentado, atrás de uma guarda anti-sobrescrita. Descomentá-lo, completá-lo, ou escrever um script que passe `valide = true` em massa: não. É o plano de trabalho da Oficina de autoridades, não um resto a liquidar.

**Os canteiros coletivos não têm data fixada por uma só pessoa.** A revisão portuguesa completa do tesauro, o vocabulário das questões LGBTQI+, a governança do comum, a aproximação com leftove.rs e NORLA: o calendário deles não se escreve aqui. Pretender fixá-lo sozinho seria exatamente o erro que este projeto procura não cometer.

---

## Manutenção deste documento

O backlog se mantém como os anteriores, com um acréscimo.

1. Mover a versão corrente para `docs/backlogs/archive/` conservando seu nome de origem.
2. Colocar a nova versão na raiz de `docs/backlogs/`.
3. Atualizar `docs/backlogs/INDEX.md`: versão corrente e linha de histórico. *(A linha do v32 ainda falta lá — é o item **J2**.)*
4. Se o incremento traz uma decisão normativa, inscrever o identificador no `REGISTRE_decisions.md`. O backlog carrega o trabalho a fazer; o registro carrega o que faz fé.
5. **Novidade do v34**: as duas versões linguísticas e a página consultável são **geradas** a partir de `docs/backlogs/backlog-v34.json` por `scripts/build-backlog.cjs`. Nunca modifique os `.md` à mão: serão sobrescritos. Modifique o JSON, rode de novo `node scripts/build-backlog.cjs`, commite os três arquivos juntos.

Se essa mecânica atrapalhar mais do que ajudar, joga-se fora sem dano: os `.md` gerados são autônomos e o JSON pode ser apagado. É uma ferramenta, não uma doutrina.

---

## Colofão

Backlog v34, 2026-08-29. Substitui `AnarBib-Backlog-2026-06-17-v33.md`. 92 itens em 11 domínios. Cada estado foi verificado em 29/08/2026 contra o banco de produção em somente-leitura e contra o repositório Codeberg no commit `1d00ed2c`. Este documento não arbitra nada: o `REGISTRE_decisions.md` faz fé.
