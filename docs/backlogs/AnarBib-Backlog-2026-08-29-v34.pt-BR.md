# Backlog AnarBib v34 — Reescrita integral sobre estado verificado — ferramenta de trabalho para as colaboradoras e os colaboradores por vir

**2026-08-29** · atualizado em **2026-09-01** · 72 itens · Version française : `AnarBib-Backlog-2026-08-29-v34.md`

> Arquivo **gerado** por `scripts/build-backlog.cjs` a partir de `backlog-v34.json`. Não o modifique à mão.

---

## Sumário

- [Por que uma reescrita](#por-que-uma-reescrita)
- [Modo de usar](#modo-de-usar)
- [O estado real em 2 de setembro de 2026](#o-estado-real-em-2-de-setembro-de-2026)
- [Desvios levantados entre o real e o escrito](#desvios-levantados-entre-o-real-e-o-escrito)
- [O calendário restrito](#o-calendário-restrito)
- [Dez regras pagas por um incidente](#dez-regras-pagas-por-um-incidente)
- [Os canteiros](#os-canteiros)
    - [A — Sustentabilidade coletiva](#a--sustentabilidade-coletiva) · 3
    - [B — Banco de dados, segurança, RLS](#b--banco-de-dados-segurança-rls) · 7
    - [C — Catalogação e dados documentais](#c--catalogação-e-dados-documentais) · 9
    - [D — Periódicos, efêmeros, recursos digitais](#d--periódicos-efêmeros-recursos-digitais) · 5
    - [E — Front, OPAC, i18n, acessibilidade](#e--front-opac-i18n-acessibilidade) · 12
    - [F — E-mail e notificações](#f--e-mail-e-notificações) · 4
    - [G — Rede, governança, federação](#g--rede-governança-federação) · 7
    - [H — Interoperabilidade, tesauro, coleta](#h--interoperabilidade-tesauro-coleta) · 3
    - [I — Auto-hospedagem, operação, backups, CI](#i--auto-hospedagem-operação-backups-ci) · 13
    - [J — Documentação e corpus](#j--documentação-e-corpus) · 2
    - [K — Caixa, comunicação, formação](#k--caixa-comunicação-formação) · 7
- [Encerramentos e entradas caducas](#encerramentos-e-entradas-caducas)
- [O que não está no backlog](#o-que-não-está-no-backlog)
- [Manutenção deste documento](#manutenção-deste-documento)

---

## Por que uma reescrita

Este documento substitui o backlog v33 de 17 de junho de 2026. O v33 trazia uma faixa de aviso de frescor acrescentada em 28 de agosto; já não bastava.

O v34 não é uma atualização do v33: é uma **reescrita sobre estado verificado**. Na sua redação, em 29 de agosto de 2026, cada afirmação de estado foi relida contra duas fontes primárias — o banco de produção consultado em somente-leitura e o repositório Codeberg no commit `1d00ed2c`. Nenhum item foi transportado com base na fé de um documento. Entre o v33 e aquele dia, 216 das 221 migrações então aplicadas haviam sido escritas, além de 655 commits.

**Este parágrafo conta uma gênese, não um estado.** Os números que descrevem o presente vivem em « O estado real », levantado à parte e datado; ele foi refeito em 1º de setembro de 2026, e metade dos valores de 29 de agosto havia mudado em três dias. Confundir os dois é exatamente o erro que tornou o v33 inutilizável.

Este trabalho produziu um resultado que comanda a leitura de todo o resto: **a documentação erra nos dois sentidos**. Declara abertos canteiros entregues há semanas, e declara entregues coisas que ninguém jamais exerceu. A seção « Desvios levantados » os nomeia um a um.

---

## Modo de usar

**Este documento não arbitra nada.** A precedência documental do projeto continua sendo a de `docs/INDEX.md`: o `REGISTRE_decisions.md` faz fé, depois a spec do domínio, depois este backlog. Se uma linha daqui contradiz o REGISTRO, é o REGISTRO que tem razão e essa linha é um defeito a sinalizar.

**Para começar sem pedir nada a ninguém**, leia `docs/CHANTIERS_OUVERTS.md`: sete portas de entrada que não exigem nenhuma coordenação. O presente backlog é o que vem depois, quando se quer saber o que falta e por quê.

**Antes de pegar um item, abra uma issue no Codeberg.** Duas pessoas escrevendo a mesma correção é uma noite perdida para uma das duas. É a única regra de coordenação do projeto, e cabe em uma linha.

**Cada ficha diz seis coisas**: o que é, o estado verificado em 29/08, por que importa, o que conta como terminado, o que exige, e do que depende. Se uma faltar, a ficha está incompleta — diga isso em vez de adivinhar.

**Os identificadores nunca são reutilizados.** Um item liquidado guarda seu número e passa para a seção dos encerramentos. As remissões entre colchetes apontam para o REGISTRO, uma spec ou um identificador herdado de um backlog anterior: permitem recuperar o rastro, não fazem autoridade por si mesmas.

---

## O estado real em 2 de setembro de 2026

Levantamento de **2 de setembro de 2026** — atualização dirigida após o dia B20/B21/J7/J8: só as linhas que a campanha moveu foram remedidas (direitos, migrações, crons, repositório); as volumetrias de acervo seguem as de 1º de setembro. Banco de produção consultado em leitura; repositório no commit `cb37a2a8`. Estes números não são estimativas: são a resposta de uma consulta ou de um `ls`. Vão vencer rápido — é normal, e é por isso que são datados. **A data deste título é gerada a partir desta fonte.**

**Frescor dos constatos em 2026-09-01.** **50 itens de 72** trazem uma verificação datada própria (A1, A3, B4, B7, B9, B10, B11, B13, B19, C2, C3, C4, C5, C7, C8, C9, C10, D3, D6, E2, E5, E6, E7, E8, E9, E12, F1, F3, F4, F6, G1, G5, G6, G8, H1, I1, I3, I4, I6, I8, I10, I11, I12, I13, I14, I15, I16, J2, J6, K2). Os **22** outros ainda repousam sobre o levantamento de 2026-08-29 e são assinalados como tais em cada ficha. Um constato não reverificado não é falso: é apenas velho, e a diferença vê-se aqui em vez de no uso. Esta linha é recalculada a cada geração do documento.

### Banco

| | | |
|---|---:|---|
| Tabelas `public` | **187** | todas com RLS ativado, 279 policies em **173** tabelas |
| Tabelas `ingest` | **10** | todas com RLS desde a noite de 29/08 (item **B1**, liquidado). O esquema nunca esteve exposto: nem `anon` nem `authenticated` tem `USAGE` nele |
| Views `api` | **68** | **67 SECURITY INVOKER, 1 DEFINER** — contra 65/3 em 29/08: duas views de governança voltaram a invoker. `CREATE OR REPLACE VIEW` reinicializa essa opção, e o T2 de `vues_api_definer_tests` a guarda |
| Funções aplicativas | **856** | `public` 630 · `api` 184 · `ingest` 34 · `private` 8. Sendo **668 SECURITY DEFINER**, **nenhuma** sem `search_path` fixado. A superfície `authenticated` já não é um canteiro: **B14 encerrado em 01/09, B20 em 02/09** — cada exposição restante tem sua razão escrita nas auditorias |
| Migrações aplicadas | **268** | 268 arquivos no repositório = **268 aplicadas, alinhamento exato**. Verificado em 02/09 dos dois lados |
| Jobs `pg_cron` | **37** | **todos ativos** (+1 desde 01/09: o lembrete antes do vencimento dos convites de equipe, GOUV-17b); cobertos na CI por `crons_planifies_tests` |
| Avisos de segurança | **447** | 0 ERROR · **395** + **28** WARN sobre funções DEFINER expostas · 24 INFO. O 28 (`anon`) é o **valor esperado** — exatamente a lista nomeada T10 (`DOC-GRANT-1`). O 395 desce de 453 pelo dia B20: 2 ligadas, 65 fechadas, 1 rejulgada (`fn_book_due_dates` → registro B2). Números pelo proxy SQL de 02/09 |
| Avisos de desempenho | **243** | 166 índices não usados · **38 chaves estrangeiras sem índice, agora todas ASSUMIDAS e guardadas** (B21 encerrado em 02/09: a dívida não entra mais sem um ato) · 25 policies permissivas · 14 tabelas sem chave primária · 0 `auth_rls_initplan` |
| Esquemas de refugo | **2** | `backup_2026_05_07` e `conv_backup` — inalterados desde 29/08 |

### Funções Edge

| | | |
|---|---:|---|
| Pastas no repositório | **51** | + `_shared`; entre elas o roteador `main`, **nunca implantado no Supabase, e isso é intencional** — serve apenas à pilha auto-hospedada |
| Declarações `verify_jwt` | **36** | **todas em `false`** — contagem das linhas `^verify_jwt = `, não das ocorrências da palavra (os comentários também a mencionam, e foi assim que o número derivou duas vezes). As funções protegidas o são pelo padrão da plataforma; reconciliar este arquivo com as funções implantadas continua sendo o item **B6** |

### Catálogo

| | | |
|---|---:|---|
| Fichas | **2 659** | 2 758 exemplares, 2 495 obras, 1 305 autoridades. As fichas caem 17 e os exemplares sobem 17 desde 29/08: são as fusões de duplicatas (item **P4**), não perdas |
| Rascunhos de catalogação | **2 240** | apenas dois estados: `draft` e `published` |
| Indexação de assunto | **1 122 / 2 659** | 42 % das fichas; 1 279 atribuições sobre 89 assuntos locais |
| Tesauro FICEDL | **462** | termos, **10 locales completas**; 98 alinhamentos para os assuntos locais |
| Periódicos | **4** | títulos, 7 fascículos vinculados. O **arbítrio de duplicatas** deles está aberto a qualquer `librarian` enquanto o dos livros é reservado à coordenação: desvio medido em 01/09, decidido, aguardando aviso prévio |

### Rede

| | | |
|---|---:|---|
| Bibliotecas | **4** | `blmf` 248 · `btl` 2 187 · `mleg` 269 · `blmf-teste` 5. **`cira-marseille` foi retirada da rede** — remoção voluntária confirmada pela coordenação em 01/09, registrada em `NOTE_retrait_cira_marseille_2026-09-01`. Cascata limpa (0 acervo, 0 órfão); tema conservado no storage, fonte de importação encerrada |
| Contas | **16** | **18** vínculos ativos — eram 28 em 29/08 |
| Administrador(a/e)s da rede | **1** | **é o item A1, e ele comanda todo o resto** |
| Circulação viva | **6 / 19 / 22 / 2** | empréstimos / reservas / consultas / EEB — última escrita de empréstimo em 31/08 |

### Repositório

| | | |
|---|---:|---|
| Commits | **2 494** | em `main`, na noite de 02/09 — 21 commits só no dia B20/GLB |
| Arquivos `src/` | **290** | 79 páginas, 89 componentes |
| Chaves i18n | **6 222** | por locale, **paridade estrita nas 10**, guardada na CI; +43 desde 01/09 |
| Testes | **354 + 70** | 354 testes JS (vitest, gate bloqueante) + **70 suítes SQL** — 7 nascidas só em 02/09, entre elas duas guardas de contador |
| Marcadores de dívida | **6** | sendo 4 em `src/` — eram 17 em 29/08. Nenhum é uma tarefa aberta: a dívida não está nos comentários, está neste backlog |

---

## Desvios levantados entre o real e o escrito

Eis por que o v33 já não podia servir. **Esta tabela é um levantamento de 29 de agosto de 2026 e assim permanece**: é o relato de uma comparação feita naquele dia, não um estado corrente. Vários desses desvios foram liquidados desde então (`ingest` sob RLS, periódicos entregues, crons reativados, views devolvidas a invoker), e os itens envolvidos o dizem na própria ficha. Não se reescreve esta tabela a cada levantamento: reescrevê-la apagaria aquilo que ela demonstra.

Esses desvios não são negligências: são o rastro normal de um projeto que entregou 655 commits enquanto seus documentos de pilotagem permaneciam congelados. O que importa não é lamentá-los, é saber que eles vão **nos dois sentidos** — e portanto que um documento não reverificado tanto pode fazer perder tempo refazendo o existente quanto levar a crer adquirido o que não é.

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

**Nenhuma suíte de testes sabia simular uma chamada anônima**

- *O que diz a documentação* — dezenas de testes anunciam «recusa `auth` (28000): chamada anônima» e passavam em verde
- *O que diz o banco ou o repositório* — `set_config('request.jwt.claims', NULL)` não põe NULL mas a cadeia vazia, e os helpers `auth.uid()`, `auth.role()`, `auth.email()` do stub de CI convertiam em `jsonb` **antes** de neutralizá-la: `''::jsonb` levantava erro de sintaxe onde a função real do Supabase devolve NULL. Os testes provavam portanto uma pane do banco de ensaio, e sua salvaguarda (`SQLERRM LIKE '%uthenticat%'`) não podia corresponder. `auth.jwt()`, quatro linhas abaixo, tinha a forma correta desde sempre. **Corrigido em 29/08.** O arnês passa em verde de ponta a ponta desde 29/08 à noite, sobre 45 suítes.

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

**Identificadores de contas reais serviam de fixtures de teste**

- *O que diz a documentação* — `tests/sql/README.md` apresentava-os como personas — «Xavier», «Lívia», «Arthur», «Patricia»
- *O que diz o banco ou o repositório* — O mesmo README os datava: «UUIDs BLMF, **verificados em 11/05/2026**». Tinham sido colhidos na base real, e **três dos quatro correspondiam a linhas existentes em produção**. Os nomes, esses, eram fictícios — o que é a verdadeira armadilha: um rótulo inventado sobre uma linha real apaga a vigilância em vez de convocá-la. As suítes rodam em `BEGIN/ROLLBACK` sobre uma base descartável, então nada aconteceu, mas a convenção que tornava isso seguro não estava escrita em lugar nenhum. **Corrigido em 29/08** — 89 substituições em 12 arquivos, personas sintéticas fornecidas pelo seed. A regra é mecânica desde a noite de 29/08: sexta regra bloqueante do hook, lista branca lida no seed, doutrina `DOC-FIXT-1` (item **I14**, encerrado).

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
- *O que diz o banco ou o repositório* — Sete views anteriores ao hook escapavam: `collective_removal_proposals_current_v1`, `cooptation_proposals_current_v1`, `gazette_issues_public_v1`, `gazette_locales_public_v1`, `lettre_locales_public_v1`, `lettre_public_v1`, `library_email_identity`. **Encerrado em 29/08** (item **B3**): quatro passadas a `security_invoker`, as duas views de governança mantidas fora das policies mas dotadas na própria view da cláusula de visibilidade retomada da policy das tabelas de base, a sétima concedida a nenhum papel aplicativo. O hook só cobria `CREATE VIEW`: cobre agora também `CREATE OR REPLACE VIEW`, e uma suíte recusa qualquer view nova fora das duas derrogações nomeadas.

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

#### A1 — Obter pelo menos duas outras pessoas administradoras de rede

`P0` Estrutural · Estado : **Decisão coletiva** · Carga : não estimado · O que exige : deliberação coletiva, nenhuma competência técnica

**Estado.** Verificado no banco em 29/08: a rede conta com **um único administrador**. As tabelas `network_administrators`, `network_administrator_cooptation_proposals` e `network_administrator_cooptation_votes` estão vazias após algumas inserções históricas.

*Verificado : 31/08 — `network_administrators`: 1 linha. Nada mudou.*

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

**Estado.** Nunca feito. `deploy/README.md`, `deploy/REPETITION.md` e `deploy/bootstrap.sh` existem e foram executados — **apenas na máquina do mantenedor**.

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** `.forgejo/workflows/ci.yml` e `sql-tests.yml` trazem ambos `runs-on: anarbib-local` — um `act_runner` auto-hospedado no WSL2 do mantenedor. Máquina desligada, **nada se implanta**, e a falha às vezes é silenciosa.

*Verificado : 31/08 — 7 ocorrências de `runs-on: anarbib-local` em `.forgejo/workflows/`. Nada mudou.*

**O que é.** Rodar o runner em outro lugar que não uma estação de trabalho pessoal: máquina do provedor, segunda máquina da rede, ou runner compartilhado. A lógica de implantação já está extraída em `scripts/ci/deployer-backend.sh` e é reexecutável à mão — metade do trabalho está feita.

**Por que importa.** Enquanto o runner for único e pessoal, nenhum procedimento pode tornar a implantação confiável, e ninguém mais pode integrar uma contribuição. É a segunda metade da dependência de uma só pessoa, depois de **A1**.

**O que conta como terminado.**

- Um push em `main` dispara uma implantação sem que a máquina do mantenedor esteja ligada.
- A guarda de exclusão do roteador `main` é preservada nos dois lugares (workflow e script).
- O procedimento de recolocação do runner em funcionamento está escrito para quem não o instalou.

**Dependências.** Ligado a **I2** (migração auto-hospedada). Pode ser feito antes, na infraestrutura atual.

*Remissões : `CLAUDE.md, piège connu n°1` · `REPRISE_bascule_autohebergee_2026-08-26`*

---

### B — Banco de dados, segurança, RLS

*187 tabelas, 666 funções SECURITY DEFINER, 279 policies. A maior superfície do projeto.*

| | | | |
|---|---|---|---|
| **B4** | Examinar as quatro tabelas com RLS sem policy que não são de trânsito | `P2` | Aberto |
| **B7** | Desambiguar os homônimos de funções entre `ingest` e `public` | `P2` | Aberto |
| **B9** | Purgar o esquema `backup_2026_05_07` | `P2` | Aberto |
| **B10** | Higiene de performance: 170 índices não usados, 38 chaves estrangeiras não indexadas, 24 policies permissivas duplicadas | `P3` | Aberto |
| **B11** | Compreender `user_wishlist`: uma linha viva para 9 092 inserções | `P3` | Aberto |
| **B13** | Decidir o destino das 221 migrações: squash ou não | `P3` | Aberto |
| **B19** | Revogar a antiga chave de assinatura HS256 — o botão que desconectaria todo mundo | `P2` | Congelado |

#### B4 — Examinar as quatro tabelas com RLS sem policy que não são de trânsito

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** 15 tabelas têm RLS ativado e zero policy. Onze são tabelas de trânsito ou vazias. Quatro não são: `author_name_aliases` (**1 647 linhas**), `library_themes` (3 linhas), `library_theme_configs`, `interlibrary_loan_events`.

*Verificado : 31/08 — 14 tabelas com RLS sem policy (15 em 29/08). As quatro nomeadas continuam lá, `author_name_aliases` com 1 647 linhas vivas.*

**O que é.** Para cada uma, decidir: ou o acesso passa por uma RPC e a ausência de policy está correta — escrevê-lo em comentário SQL —, ou uma leitura legítima é hoje impossível e falta uma policy ou uma função.

**Por que importa.** Uma tabela com RLS e sem policy está fechada para todos exceto para as funções `DEFINER`. Às vezes é exatamente o que se quer, e às vezes é uma funcionalidade que não funciona sem que ninguém tenha percebido — `author_name_aliases` carrega 1 647 linhas que talvez nada leia.

**O que conta como terminado.**

- As quatro tabelas têm um veredicto escrito.
- O controle de restauração do runbook lista nominalmente as tabelas sem policy esperadas.

**Dependências.** Nenhuma.

*Remissões : `PLAN_DE_MARCHE §8` · `MATRICE_rls_deny_all_2026-06-23`*

#### B7 — Desambiguar os homônimos de funções entre `ingest` e `public`

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** Quatro nomes de função existem nos dois esquemas com assinaturas e semânticas diferentes: `fn_bulk_create_book_drafts_from_run`, `fn_bulk_set_partner_catalog_editorial_decision`, `fn_set_partner_catalog_editorial_decision`, e `set_updated_at()`. Nenhuma duplicata de assinatura num mesmo esquema — o problema é o nome compartilhado.

*Verificado : 30/08 — quatro homónimos levantados: `set_updated_at` (trivial) e três que tocam nas decisões editoriais sobre catálogo parceiro. Os corpos não foram comparados.*

**O que é.** Verificar qual das duas é chamada pelo front e pelas RPC, renomear a que não é, ou suprimir a versão morta. `set_updated_at()` é um trigger banal e pode ficar.

**Por que importa.** Um `search_path` que muda de ordem basta para chamar a outra função, com parâmetros que não correspondem. É uma pane difícil de diagnosticar, e o projeto já pagou uma vez por um `search_path` mal fixado.

**O que conta como terminado.**

- As três funções de negócio homônimas estão desambiguadas.
- Nenhuma depende da ordem do `search_path` para ser resolvida corretamente.

**Dependências.** Nenhuma.

*Remissões : `Relevé du 29/08/2026`*

#### B9 — Purgar o esquema `backup_2026_05_07`

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** Seis tabelas, **todas com zero linha e zero inserção desde a criação**, sem chave primária, sem RLS: `emprestimos_v2`, `emprestimo_itens_v2`, `reservas_v2`, `reserva_linhas_v2`, `reserva_item_workflow_v2`, `loan_midpoint_message_log`. A decisão `BG2-9` prescreve essa purga desde junho.

*Verificado : 30/08 — o esquema pesa 6 tabelas e 0,1 Mo. O que ainda o lê não foi procurado.*

**O que é.** `DROP SCHEMA backup_2026_05_07 CASCADE` por migração, após confirmar uma última vez que as seis tabelas estão vazias.

**Por que importa.** Seis tabelas de backup vazias poluem cada levantamento de advisors — carregam sozinhas seis dos catorze avisos «sem chave primária». E um esquema chamado `backup_` que não contém nada é uma armadilha para quem retomar o projeto.

**O que conta como terminado.**

- O esquema não existe mais.
- `deploy/bg2-known-tables.txt` foi atualizado no mesmo movimento.

**Dependências.** Não confundir com `conv_backup`, que carrega dados de revisão humana e **não se purga** (ver **C4**).

*Remissões : `REGISTRE §BG2 BG2-9`*

#### B10 — Higiene de performance: 170 índices não usados, 38 chaves estrangeiras não indexadas, 24 policies permissivas duplicadas

`P3` Adiado · Estado : **Aberto** · Carga : alguns dias · O que exige : SQL / PostgreSQL

**Estado.** 256 avisos de performance em 29/08. As tabelas mais carregadas de índices não usados são `library_partnerships` (6), `books` (5), `membership_payments` (4). As 24 policies permissivas duplicadas incidem todas sobre o papel `authenticated` em `SELECT`, em tabelas centrais (`books`, `authors`, `exemplares`, `subjects`, `works`).

**Requalificado pela medida (GLB v17 cap. 8.1, contraverificada em 02/09).** As FK sem índice, «saldadas» em 02/07 (151 → 15), estão em **38** oito semanas depois, pelo funcionamento normal do projeto. A campanha segue adiada com razão; **a guarda que impede a reabertura foi extraída em B21** e não espera a volumetria.

*Verificado : 31/08 — 254 avisos: 167 índices sem uso, 38 chaves estrangeiras sem índice, **25** tabelas com policies permissivas em dobro (`book_reading_notes` entrou na lista), 14 sem chave primária.*

**O que é.** Três passagens distintas, a não misturar: fundir os pares de policies permissivas; indexar as chaves estrangeiras que realmente servem; só suprimir um índice não usado se se compreender por que foi criado.

**Por que importa.** Na volumetria atual — 2 676 registros, 16 contas — **nada disso se vê**. É um canteiro de pré-crescimento, adiado de propósito desde julho. Anotá-lo permite não redescobri-lo às pressas no dia em que uma biblioteca chegar com 100 000 registros.

**O que conta como terminado.**

- Os 24 avisos de policies duplicadas estão resolvidos — é a passagem mais rentável.
- As chaves estrangeiras das tabelas realmente escritas estão indexadas.
- Os índices suprimidos o são com o motivo escrito.

**Dependências.** A retomar se uma biblioteca de grande acervo entrar na rede.

*Remissões : `ETAT-lancement-consolide-2026-07-03 §2 item 7` · `Advisors performance du 29/08/2026`*

#### B11 — Compreender `user_wishlist`: uma linha viva para 9 092 inserções

`P3` Adiado · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** **Medido em 30/08: 1 linha viva, 9 092 inserções, 9 082 supressões.** A razão não é uma fuga de escrita mas um **ciclo**: quase tudo o que entra volta a sair. Nove mil idas e voltas para uma única linha sobrevivente não se parece com um uso de leitoras — a rede não tem esse volume.

A pergunta já não é «o que escreve», mas **«o que escreve e apaga logo a seguir»**.

*Verificado : 30/08 — `pg_stat_user_tables`: 1 linha viva, 9 092 inserções, 9 082 supressões. O que escreve e depois apaga continua desconhecido.*

**O que é.** Encontrar o que escreve e apaga: um teste reexecutado, um carregamento de página que insere e depois cancela, um componente React que chama a RPC a cada renderização. Olhar `OPAC-W1`, cuja nota diz «resta `WITH CHECK`».

**Por que importa.** Nove mil escritas para uma linha não é um uso: é um laço. Custa pouco hoje e custará exatamente o mesmo por usuária no dia em que houver cem.

**O que conta como terminado.**

- A causa está identificada e escrita.
- Se for um laço do front, está corrigido; se for um teste, a linha é retirada da constatação.

**Dependências.** Nenhuma.

*Remissões : `REGISTRE §18 OPAC-W1` · `Relevé du 29/08/2026`*

#### B13 — Decidir o destino das 221 migrações: squash ou não

`P3` Adiado · Estado : **Aberto** · Carga : várias semanas · O que exige : SQL / PostgreSQL, administração de sistemas

**Estado.** 221 migrações aplicadas, das quais a primeira é um `baseline_live` de **2,4 MB** — o maior arquivo do repositório. O squash está marcado «decidido, não iniciado» desde 20/08, numa época em que a contagem era de 146.

*Verificado : 31/08 — 243 migrações aplicadas: vinte e duas a mais que em 29/08.*

**O que é.** Ou reconstruir um `baseline` a partir do esquema atual e arquivar as migrações anteriores, ou assumir a cadeia longa e documentar por quê. A reexecução completa leva hoje cerca de 25 minutos, medido.

**Por que importa.** O risco do squash é inteiro: reescreve o único rastro ordenado do que foi feito, e o arnês de testes SQL reexecuta toda a cadeia a cada vez. Não fazê-lo custa tempo de CI; fazê-lo mal custa a capacidade de reconstruir. **Não se comprometer antes que A2 tenha sido bem-sucedido pelo menos uma vez.**

**O que conta como terminado.**

- Uma decisão escrita no REGISTRO, num sentido ou no outro.
- Se squash: a reconstrução a partir do novo baseline foi testada numa máquina de terceiro.

**Dependências.** **Bloqueado por A2.** Não começar antes.

*Remissões : `ETAT-AVANCEMENT-multisessions` · `docs/schema/baseline_schema_2026-06-11.sql`*

#### B19 — Revogar a antiga chave de assinatura HS256 — o botão que desconectaria todo mundo

`P2` Corrente · Estado : **Congelado** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** As chaves de assinatura JWT estão migradas: a chave corrente é uma ECC P-256, a antiga HS256 está guardada em « Previously used keys » e só faz verificação. O dashboard mostra ao lado dela um botão Revoke e um texto que convida gentilmente a clicar « uma vez expirados os tokens ». Só que essa chave ainda valida a chave anon legada que os navegadores com bundle em cache enviam — 2.026 requisições por dia no levantamento de 01/09.

*Verificado : 01/09 — página Settings → JWT Keys lida: ECC P-256 corrente, HS256 em « previously used », última rotação há 5 meses.*

**O que é.** Nada antes de B18 estar terminado e digerido. Só depois: verificar que nenhum token nem URL assinada de longa duração ainda depende da HS256, e então revogar. Item congelado de propósito para que ninguém « arrume » esse botão de passagem.

**Por que importa.** É o único gesto realmente irreversível de todo o canteiro das chaves, e está a um clique de uma tela que se visita por outras razões. Revogada cedo demais, a HS256 invalida de uma vez tudo o que ela ainda validava: a desconexão seria geral e imediata.

**O que conta como terminado.**

- B18 está fechado há tempo suficiente para que nenhum token assinado com HS256 circule mais.
- A revogação foi feita e um login, um cadastro e uma recuperação de senha foram verificados logo depois.

**Dependências.** Item B18 terminado.

*Remissões : `item B18`*

---

### C — Catalogação e dados documentais

*A dívida aqui não é de código: são fichas para revisar uma a uma.*

| | | | |
|---|---|---|---|
| **C2** | Importar o acervo SOLIDAIRES pela ferramenta de importação, e registrar o que quebra | `P1` | Bloqueado |
| **C3** | Conduzir a revisão humana das autoridades: sobrenomes, caixa, títulos | `P1` | Aberto |
| **C4** | Preencher os países ausentes em 722 fichas de autoridade | `P2` | Aberto |
| **C5** | Decidir o destino do campo livre `books.autor` | `P2` | Decisão coletiva |
| **C6** | Entregar as três assistências de digitação previstas pela spec das convenções | `P2` | Aberto |
| **C7** | Indexar por assunto os 1 549 registros que não têm nenhum assunto | `P2` | Aberto |
| **C8** | Enriquecer as autoridades: datas, identificadores externos, formas variantes | `P3` | Aberto |
| **C9** | Fechar as oito questões abertas das convenções catalográficas | `P2` | Decisão coletiva |
| **C10** | Renomear uma das duas colunas `rights_status` | `P2` | Aberto |

#### C2 — Importar o acervo SOLIDAIRES pela ferramenta de importação, e registrar o que quebra

`P1` Prioritário · Estado : **Bloqueado** · Carga : alguns dias · O que exige : biblioteconomia, SQL / PostgreSQL

**Estado.** 1 685 registros em `SOLIDAIRES_import_test.csv`. **Constato corrigido em 31/08: o arquivo foi sim confrontado com o importador.** `book_drafts` traz 1 673 rascunhos da fonte `SOLIDAIRES_import_v2.csv`, criados num único lote na noite anterior à escrita do constato « nunca confrontados ». Todos `draft`, **nenhum publicado**: o catálogo público não foi tocado. A decisão de Xavier (29/08) permanece: nenhuma promoção antes da admissão (G7). O que resta não é mais « importar », mas consignar o que quebrou e promover depois da admissão.

*Verificado : 31/08 — `book_drafts`: 1 673 linhas, todas `draft`, 0 publicadas. O primeiro critério (« admissão antes de tocar o arquivo ») caducou na letra: o arquivo foi tocado — mas nada entrou no catálogo.*

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

**Estado.** As 19 migrações `conventions_*` estão aplicadas desde 21/08: os referenciais estão normalizados, as mecânicas seguras foram passadas, a fila de verificação existe e o aplicativo permite trabalhar nela. **O que resta é a parte que nenhuma máquina faz.**

*Verificado : 31/08 — a fila `catalog_review_queue` medida, 310 linhas: o lote de **patronímicos está terminado** (0 a rever), `autorite_casse` quase (3 a rever), `titre_casse` carrega o grosso (174 a rever), e um quarto lote `autorite_collectivite` (2 a rever). **Restam 179 vereditos humanos.***

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

**Estado.** **722 fichas de 1 305 (55 %) não têm `country`.** Ora, é `country` que comanda a regra de entrada do nome: sem ele, a detecção dos duplos sobrenomes hispânicos só vê uma fração dos casos. Os 22 apontamentos são um **piso**, não um total.

*Verificado : 31/08 — 726 de 1 305 fichas sem `country` (55,6 %): quatro a mais que em 29/08.*

**O que é.** Preencher `country` por lotes, a partir dos registros, das fontes externas já conectadas (Wikidata, VIAF) e do conhecimento do acervo. Depois reexecutar a detecção dos sobrenomes.

**Por que importa.** É o pré-requisito duro de toda a cadeia de convenções: `CONV-7` faz de `country` em ISO 3166-1 α-2 uma condição, e `CONV-3` faz a caixa ser comandada pela língua. Um catálogo com 55 % sem país aplica as próprias regras pela metade.

**O que conta como terminado.**

- A proporção de fichas sem `country` caiu abaixo de 20 %.
- A detecção dos duplos sobrenomes foi reexecutada e a nova lista passou por revisão humana.

**Dependências.** Pré-requisito da segunda passagem de **C3**.

*Remissões : `AUDIT_conventions_catalographiques_2026-08-20 A5` · `REGISTRE §37 CONV-7`*

#### C5 — Decidir o destino do campo livre `books.autor`

`P2` Corrente · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : biblioteconomia, SQL / PostgreSQL

**Estado.** `CONV-O3` está aberto: depreciar `books.autor` agora, ou na Oficina? O campo coexiste com a tabela `authors` e carrega os mesmos defeitos **piores** — encontram-se lá `identificado, Não`, `REICH, Hilhem`, `Rosamund Bartlett (Org.)`. A auditoria de 20/08 o deixou explicitamente fora do perímetro: sua dívida não está quantificada.

*Verificado : 31/08 — dívida quantificada: 2 653 livros de 2 659 com `autor` não vazio, 1 629 valores distintos, e **231 livros sem nenhum vínculo com `authors`** — para eles o campo livre é a única informação de autoria.*

**O que é.** Primeiro quantificar: quantos registros têm um `autor` sem contribuidor vinculado, e como é o conteúdo. Depois decidir: depreciação imediata com migração dos valores recuperáveis, ou conservação como forma transcrita no sentido do `P3` dos periódicos.

**Por que importa.** Duas verdades concorrentes sobre o autor de um livro é o contrário de `DOC-CONV-1` («uma só verdade no banco, várias renderizações»). Enquanto o campo viver, cada tela precisa escolher qual exibir, e os dois divergem.

**O que conta como terminado.**

- ~~A dívida está quantificada~~ — 31/08: 2 653 `autor` não vazios, 1 629 distintos, 231 livros sem vínculo com `authors`.
- Uma decisão está inscrita no REGISTRO, num sentido ou no outro.
- Se depreciação: o campo não é mais escrito por nenhum formulário.

**Dependências.** Remete a `INV-4`.

*Remissões : `REGISTRE §37 CONV-O3` · `AUDIT_conventions_catalographiques_2026-08-20`*

#### C6 — Entregar as três assistências de digitação previstas pela spec das convenções

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript, biblioteconomia

**Estado.** O banco sabe normalizar; a interface de digitação ainda não assiste. Três dispositivos estão especificados e não entregues: o assistente de separação do nome (§7.1), o botão «Normalizar maiúsculas» com pré-visualização (§7.2), e a fila de controles de coerência em segundo plano (§7.3).

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** Verificado em 29/08: **1 127 registros indexados de 2 676**, ou seja 42 %. 1 284 atribuições distribuídas em 89 assuntos locais. Do lado público anônimo, a cobertura é ainda mais baixa.

*Verificado : 31/08 — 1 122 de 2 659 registros indexados (42,2 %), 1 279 atribuições, 89 assuntos. As fusões de duplicatas de 31/08 explicam a leve queda.*

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

**Estado.** De 1 305 autoridades: **726 (56 %) sem data de nascimento**, cerca de **1 272 (98 %) sem identificador VIAF, ISNI ou Wikidata**, cerca de **1 275 (98 %) sem `variant_forms`**.

*Verificado : 31/08 — de 1 305 autoridades: 728 sem ano de nascimento, 1 276 sem identificador externo, 1 280 sem `variant_forms`. O constato se mantém.*

**O que é.** Passagens de enriquecimento pelas fontes já conectadas, com revisão. Os pseudônimos militantes são um caso à parte: a entrada se faz pela forma mais conhecida do movimento, com remissão a partir do nome civil, **nunca o contrário**.

**Por que importa.** Os identificadores externos são o que permitirá a outro catálogo reconhecer nossas autoridades sem redescrevê-las. As formas variantes são o que permite encontrar alguém sob o nome que se conhece. E para um pseudônimo militante, a forma de uso **carrega frequentemente o único rastro de uma repressão**: não se sobrescreve.

**O que conta como terminado.**

- A cobertura em identificadores externos passa de 20 % nas autoridades mais citadas.
- Nenhum pseudônimo militante foi substituído por um nome civil.

**Dependências.** Depois de **C4** (os países ajudam os alinhamentos).

*Remissões : `AUDIT_conventions_catalographiques_2026-08-20 A7-A9` · `REGISTRE §12 CAT-D6`*

#### C9 — Fechar as oito questões abertas das convenções catalográficas

`P2` Corrente · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : biblioteconomia

**Estado.** `CONV-6` continua «a confirmar» e `CONV-O1` a `CONV-O8` estão abertos. Dois deles carregam trabalho quantificado: `CONV-O7` (o tipo de autoridade existe mas continua ilegível pelo SQL — **16 vereditos de coletividades faltam**) e `CONV-O8` (a cisão de autoridade não existe — **3 separações faltam**).

*Verificado : 31/08 — dos 16 vereditos de coletividades, **14 estão postos** (2 a rever); `authority_type`: 19 `collective`, 45 `person`, 1 241 sem tipo. A cisão de autoridade continua inexistente no banco. Nada medido sobre as oito questões em si.*

**O que é.** Decidir as oito numa sessão, apoiando-se no acervo real: `name_lang` distinto de `country` ou não, convenções das coletividades, destino de `books.autor` (ver **C5**), critério de mudança para EDTF, perímetro da tela de verificação, e os dois lotes manuais.

**Por que importa.** A coluna `name_lang` foi criada anulável e sem restrição validada: **criá-la não compromete nada, usá-la sim**. Enquanto a questão ficar aberta, cada nova regra de entrada precisa se perguntar em que se apoia.

**O que conta como terminado.**

- As oito têm um veredicto no REGISTRO.
- As 16 coletividades e as 3 separações são tratadas à mão — são explicitamente **não automatizáveis**.

**Dependências.** Esclarece **C6**.

*Remissões : `REGISTRE §37 CONV-6, CONV-O1..O8`*

#### C10 — Renomear uma das duas colunas `rights_status`

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** `digital_assets.rights_status` é um **estado de workflow** (`to_review`, `public_domain_confirmed`) que comanda a visibilidade. O vocabulário de direitos autorais leva o mesmo nome desde a migração `20260820235000_vocabulaire_rights_status`. Dois sentidos, um nome.

*Verificado : 31/08 — o nome vive agora em **três** tabelas: `digital_assets`, `book_digital_resources` e `book_draft_digital_resources`, além do vocabulário homônimo.*

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
| **D2** | Decidir as cinco questões que ficaram abertas sobre os periódicos | `P2` | Decisão coletiva |
| **D3** | Vincular os 91 fascículos e as 87 monografias suspeitas de SOLIDAIRES | `P2` | Bloqueado |
| **D4** | O material efêmero: panfletos, cartazes, adesivos, fanzines | `P1` | Aberto |
| **D5** | Testar a cadeia de digitalização em dez obras antes de equipar quem quer que seja | `P2` | Aberto |
| **D6** | Retomar ou substituir o leitor EPUB | `P3` | Aberto |

#### D2 — Decidir as cinco questões que ficaram abertas sobre os periódicos

`P2` Corrente · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : biblioteconomia

**Estado.** Cinco arbitragens ficaram pendentes na spec, com uma inclinação escrita para cada uma: vocabulário de `periodicidade` livre ou fechado; filiação n-n ou dois vínculos simples; `serials` deve levar um `library_id`; promoção automática de um título proposto; página pública dedicada ou faceta.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Decidi-las sobre casos reais em vez de no abstrato — o acervo Anarchief (cerca de cem títulos desde 1860) e o acervo SOLIDAIRES (12 títulos, 91 fascículos) são a matéria para testar.

**Por que importa.** Duas das cinco já estão decididas de fato pelo código entregue (página dedicada `/periodico/<slug>`, sem `library_id`). Deixá-las «abertas» no REGISTRO enquanto o código escolheu cria exatamente o tipo de desvio que este backlog corrige.

**O que conta como terminado.**

- As cinco têm um veredicto inscrito, de acordo com o código entregue ou corrigindo-o.
- A promoção de um título continua **um gesto e não um limiar** — era a inclinação, e vale confirmá-la.

**Dependências.** Depois de **D1**.

*Remissões : `spec-periodiques-v0.1 §13`*

#### D3 — Vincular os 91 fascículos e as 87 monografias suspeitas de SOLIDAIRES

`P2` Corrente · Estado : **Bloqueado** · Carga : alguns dias · O que exige : biblioteconomia

**Estado.** O arquivo SOLIDAIRES já traz colunas `revue` e `numero`: **12 títulos a criar, 91 fascículos a vincular**. Além disso, **87 monografias trazem «n°» no título** e estão marcadas por uma flag `numero_dans_titre`: são candidatas ao vínculo.

*Verificado : 31/08 — os 1 673 rascunhos SOLIDAIRES estão no banco (ver C2) e **nenhum traz `serial_id`**: o vínculo dos fascículos não começou.*

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

**Estado.** Nada existe. O modelo de registro herdado da biblioteconomia do livro não sabe descrever esse material, e o AnarBib não é exceção. É a necessidade **pior atendida**, para uma parte enorme dos nossos acervos.

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** A regra está registrada e cabe numa frase: «captura-se em tons de cinza, entrega-se em bitonal, só se mantém on-line o que é entregue». Os tetos dos buckets estão em produção. **A ferramenta de derivação não foi escolhida**, e a ficha prática de uma página não está escrita.

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** `epubjs ^0.3.93` é a única dependência claramente pré-1.0 num caminho crítico — o leitor EPUB, `src/lib/reader/epubEngine.js` e `src/components/viewers/EpubReader.jsx`. A biblioteca não teve publicação maior há anos.

*Verificado : 31/08 — `package.json`: `epubjs ^0.3.93`, sem mudança.*

**O que é.** Avaliar o que quebra hoje, o que quebrará com os navegadores futuros, e se existe uma alternativa livre mantida. Decidir entre fixar e assumir, ou substituir.

**Por que importa.** O leitor é o que torna um acervo digitalizado consultável sem download. Se cair, não é um conforto que desaparece, é o acesso. Nada urge hoje — mas é melhor saber.

**O que conta como terminado.**

- Um veredicto escrito: conservar e fixar, ou substituir por quê.
- Se conservação: um teste que verifica a abertura de um EPUB real.

**Dependências.** Nenhuma.

*Remissões : `package.json` · `Relevé du 29/08/2026`*

---

### E — Front, OPAC, i18n, acessibilidade

*10 locales em paridade estrita, 6 179 chaves cada, verificadas na integração contínua.*

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
| **E12** | A página Importações fala a língua da máquina — e a exportação não tem endereço | `P2` | Aberto |

#### E1 — Fazer auditar a acessibilidade por alguém que não escreveu o código

`P1` Prioritário · Estado : **Aberto** · Carga : alguns dias · O que exige : nenhuma competência técnica, React / JavaScript

**Estado.** Funcionalidades de acessibilidade estão implementadas: painel de ajustes em todas as páginas desde 26/08, `html lang` que segue a língua exibida (WCAG 3.1.1) com seu teste, campos de 16 px no mínimo, alvos táteis de 44 px, `viewport-fit=cover`. **Nenhuma auditoria de acessibilidade independente foi jamais conduzida.**

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** As dez locales estão em paridade estrita de chaves — 6 177 cada uma, verificada na integração contínua desde 27/08. Mas as **convenções** de duas delas não estão decididas: o neerlandês está em estado de rascunho, o grego resta a definir. O teste de paridade não vê isso: conta as chaves, não a justeza delas.

*Verificado : 31/08 — os dez arquivos da carta v2 existem desde 05/06, `nl` e `el` incluídos; mas dentro deles a convenção `nl` está marcada « provisória » e a `el` « a definir com uma pessoa falante de grego militante ». Os documentos existem, as decisões não.*

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

**Estado.** `DOC-ADDR-1` fixa o tratamento informal como registro da interface. Na prática, **`nl` e `el` tratam por «tu», as outras oito por «você» formal**. A divergência está documentada e assumida como «um canteiro a decidir, não a sofrer de passagem numa correção».

*Constato de 29/08, não reverificado desde então.*

**O que é.** Decidir uma vez para as dez, levando em conta que o valor político do tratamento informal não é o mesmo em cada língua, depois passar as locales envolvidas numa única operação.

**Por que importa.** O AnarBib propõe a outros catálogos convenções de interoperabilidade, uma das quais diz explicitamente que o vocabulário comum não impõe a escrita inclusiva de cada um. **A coerência interna se resolve antes de pregar a convenção.**

**O que conta como terminado.**

- Uma decisão no REGISTRO, com o motivo.
- As dez locales aplicam o mesmo registro, ou a divergência é justificada língua por língua.

**Dependências.** A fazer depois de **E2** (as convenções decidem o registro).

*Remissões : `REGISTRE §0 DOC-ADDR-1` · `VERIF_confidentialite_tiers_2026-08-20`*

#### E4 — Resolver os pares irregulares do italiano

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : língua materna

**Estado.** `it.json` não está conforme à convenção do asterisco final: os pares irregulares como `lettore` / `lettrice` não se reduzem a `lettor*`. O teste de carta verifica uma só coisa no italiano — que `camerata` e `camerati` nunca apareçam, termo fascista, falha dura — e nada mais.

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** É a **única exceção antirrastreamento restante**: os ladrilhos de `tile.openstreetmap.org` são carregados pelo navegador da visitante, que entrega portanto seu endereço IP a um terceiro. A intenção de retransmitir já está **anunciada publicamente** na chave `privacy.s6.maptiles` das dez locales.

*Verificado : 31/08 — três arquivos ainda carregam `tile.openstreetmap.org` do lado do navegador.*

**O que é.** Retomar o modelo já em vigor para o Nominatim: um relé do lado servidor, com cache, e o endereço do relé na configuração do front.

**Por que importa.** A regra de conformidade do projeto está escrita e é geral: **toda dependência que recebe um endereço IP de visitante deve ser declarada, mesmo quando não é um operador no sentido do RGPD.** O raciocínio inverso é precisamente o que deixara o Turnstile invisível durante meses. Aqui a dependência está declarada — falta suprimi-la, como anunciado.

**O que conta como terminado.**

- Nenhuma requisição sai do navegador para um domínio de terceiro nas páginas de mapa.
- A chave `privacy.s6.maptiles` é atualizada nas dez locales para descrever o novo estado.

**Dependências.** Mais simples depois de **I2** (pilha auto-hospedada), mas viável antes.

*Remissões : `VERIF_confidentialite_tiers_2026-08-20` · `PLAN_DE_MARCHE §8` · `scripts/nominatim/`*

#### E6 — Dividir as cinco telas que pesam mais de cem quilobytes

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript

**Estado.** `BookDraftForm.jsx` tem **197 KB**, `BibliotecaPage.jsx` 184 KB, `AccountPage.jsx` 154 KB, `PanelPage.jsx` 114 KB, `ImportacoesPage.jsx` 109 KB. 29 das 38 rotas já estão em carregamento preguiçoso, e `vite.config.js` declara quatro lotes de dependências — o problema não é o carregamento inicial, é o tamanho de um arquivo único.

*Verificado : 31/08 — os cinco mesmos arquivos, com tamanhos vizinhos (197, 186, 155, 116 e 111 KB).*

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

**Estado.** **Constato corrigido em 31/08: estava errado desde maio.** O hook `src/lib/useDocumentTitle.js` atualiza `document.title` na navegação desde **05/05/2026**, e 32 páginas de 79 o usam. O que resta é a cobertura das 47 páginas sem hook e o teste prometido, que não existe.

*Verificado : 31/08 — medido no repositório: hook presente desde 05/05, 32 usos, nenhum teste de título. Na mesma noite: o teste prometido está escrito e verde (6 casos).*

**O que é.** Definir o título a cada mudança de rota, a partir das chaves i18n existentes.

**Por que importa.** O título de página é o que os leitores de tela leem na chegada, o que se inscreve no histórico do navegador, e o que aparece numa aba fixada. Um título congelado torna os três inutilizáveis.

**O que conta como terminado.**

- O título segue a rota, nas dez línguas.
- ~~Um teste o verifica, no modelo de `documentLanguage.test.js`~~ — `src/tests/documentTitle.test.js`, seis casos, entregue em 31/08.

**Dependências.** Complemento natural de **E1**.

*Remissões : `Mémoire de projet, dette technique`*

#### E8 — Carregar as duas fontes sem bloquear a exibição

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : React / JavaScript

**Estado.** **Constato corrigido em 31/08: descrevia um estado morto desde maio.** `titre.ttf` e `accent.ttf` desapareceram em **06/05/2026** — resta só um comentário em `theme.js:198`. Desde então: 19 arquivos woff2 auto-hospedados (1,3 MB), `font-display: swap` em todas as faces, pré-carregamento dos dois arquivos críticos. Resta só a medição antes/depois nunca consignada — candidato a encerramento.

*Verificado : 31/08 — medido no repositório: arquivos, CSS, `index.html`, histórico git.*

**O que é.** Adicionar `font-display: swap`, pré-carregar apenas a fonte de título, subconjuntar os arquivos aos caracteres realmente usados — dez línguas incluindo o grego, então o subconjunto não é trivial.

**Por que importa.** 1,5 MB de fontes numa conexão de balcão são vários segundos de tela branca. O público do AnarBib inclui bibliotecas que não têm fibra.

**O que conta como terminado.**

- ~~O texto aparece antes das fontes, com uma substituição aceitável~~ — `font-display: swap` em todas as faces desde 06/05.
- O peso total das fontes carregadas na primeira visita é medido antes e depois.

**Dependências.** Não tocar na identidade visual: `IDENT-1` a `IDENT-4` estão registrados.

*Remissões : `Mémoire de projet, dette technique` · `REGISTRE §39 IDENT`*

#### E9 — Terminar o layout móvel: três lotes identificados

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript

**Estado.** As fases A, B e C estão entregues e a doutrina graduada está registrada. Três questões continuam abertas no REGISTRO: `MOB-Q1` (24 grades declaradas em linha no JSX com trilhas `fr` nuas), `MOB-Q2` (20 media queries herdadas a repatriar em `src/styles/mobile.css`), `MOB-Q3` (as abas Validações e Inventário a converter em cartões).

*Verificado : 31/08 — `MOB-Q1` está saldada no código: das 49 trilhas `1fr` do JSX, todas em `minmax(0,1fr)` salvo um comentário. `MOB-Q2` derreteu: 8 media queries fora de `mobile.css` em vez de 20. `MOB-Q3` não medido. Veredito posto na mesma noite sobre `MOB-Q2`: nada a repatriar. Resta `MOB-Q3`.*

**O que é.** Três passagens mecânicas, nesta ordem de valor: as 24 grades (`minmax(0, Nfr)` em toda parte, é a regra `MOB-1`), as duas abas em cartões segundo o padrão entregue, depois o repatriamento das media queries.

**Por que importa.** Uma trilha `fr` nua transborda assim que seu conteúdo é mais largo que a coluna, e um transbordamento **se constata pela medida, nunca a olho** (`MOB-9`). As 24 grades são outros tantos transbordamentos à espera de um título longo.

**O que conta como terminado.**

- ~~Nenhuma grade do JSX traz trilha `fr` nua~~ — 31/08: nenhuma resta, a última ocorrência é um comentário.
- As duas abas estão em cartões abaixo de 640 px.
- ~~As media queries herdadas vivem em `mobile.css`~~ — as 20 herdadas estão lá; as 8 restantes têm cada uma razão de estar onde estão (documentos gerados, fonte canônica dos breakpoints, componente tabbar). Veredito de 31/08.

**Dependências.** Nenhuma. Canteiro divisível em três.

*Remissões : `REGISTRE §36 MOB-Q1..Q3`*

#### E10 — O resto da base de campo: plantão móvel, notificação push, prancha de códigos

`P3` Adiado · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript

**Estado.** A base de campo está entregue: aplicativo instalável, leitura de códigos QR e ISBN, inventário, layout adaptativo. Três elementos restam, herdados do v32 e não reverificados desde então: o plantão móvel (P3), a notificação push (P5), e a prancha de códigos QR em formato A4.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Começar verificando qual dos três ainda é uma falta real. A notificação push levanta uma questão de fundo antes de uma questão de código: pressupõe um serviço de terceiro, o que a doutrina antirrastreamento examina de perto.

**Por que importa.** A prancha A4 é a mais simples e a mais útil no balcão: permite etiquetar um acervo sem impressora de etiquetas. As outras duas merecem primeiro uma conversa.

**O que conta como terminado.**

- A prancha A4 existe e imprime corretamente.
- Para a notificação push, um veredicto escrito: viável sem terceiro, ou renúncia assumida.

**Dependências.** Herdado de `#MOBILE P3`, `#MOBILE P5`, `#MOB-QR-A4`.

*Remissões : `AnarBib-Backlog-2026-06-17-v33 §2.1`*

#### E11 — Os dois adiamentos assumidos do OPAC: tags contributivas e feed RSS

`P3` Adiado · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : deliberação coletiva, React / JavaScript

**Estado.** `#OPAC5` (folksonomia, tags postas pelas leitoras) está bloqueado numa decisão de comunidade e de privacidade. `#OPAC11` (feed RSS de busca) está adiado por razão antirrastreamento. Os dois estão abertos desde maio e nunca foram instruídos.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Instruí-los de uma vez: o que uma tag pública revela sobre quem a pôs, e o que um feed RSS revela sobre quem o segue? Depois decidir, ou fechar.

**Por que importa.** Um item adiado sem instrução continua na pauta de cada releitura e custa atenção a cada vez. Fechar um item é uma decisão tão válida quanto entregá-lo.

**O que conta como terminado.**

- Os dois têm um veredicto no REGISTRO: entregue, ou fechado com o motivo.
- `OPAC-RSS1` é atualizado em consequência.

**Dependências.** Nenhuma.

*Remissões : `REGISTRE §18 OPAC-RSS1` · `AnarBib-Backlog-2026-06-17-v33 §2.4`*

#### E12 — A página Importações fala a língua da máquina — e a exportação não tem endereço

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript, língua materna

**Estado.** **Constato de Xavier em 02/09, sobre a própria captura de tela**: «nada ergonômico, sobretudo para camaradas que não são informáticos». Três defeitos distintos. **(1) O vocabulário é o do pipeline, não do gesto**: «Tratamentos», «Linhas em staging», «Promovidas» descrevem staging → revisão → promoção; quem cataloga quer *fazer entrar registros*. **(2) Códigos brutos vazam na tela**: `mapeada`, `importacao_autorizada` — valores de enumeração sem tradução, nenhuma chave i18n nas dez locales (verificado em 02/09). É o defeito mais nítido e mais barato. **(3) Importação e exportação estão misturadas, e a exportação está noutro lugar**: a página «Importações» hospeda «Coleta OAI» (uma importação); «ser fonte» vive na página Rede; a exportação de um lote se esconde atrás de dois ícones sem rótulo. Quem quer «dar nossos registros a outro catálogo» não tem lugar com esse nome.

*Verificado : 02/09 — constato de quem usa a ferramenta, verificado no código (valor bruto renderizado; nenhuma chave i18n).*

**O que é.** Três lotes. **Lote A — antes da formação de 13/09**: traduzir os status brutos nas dez locales e rotular os dois ícones — uma noite. **Lote B**: renomear para o gesto, sem tocar no pipeline. **Lote C**: dar um endereço à exportação — uma entrada «Dar nossos registros» (ser fonte, OPDS, exportação de lote) e um percurso guiado «tenho um arquivo» em duas telas. Provar cada lote com quem não escreveu o código.

**Por que importa.** É a doutrina anti-megamáquina aplicada à tela mais técnica do software: uma ferramenta que esconde os camaradas atrás do seu vocabulário faz o contrário do que promete. E a formação de 13/09 mostrará esta página — o lote A é datado por esse calendário.

**O que conta como terminado.**

- [object Object]
- [object Object]
- [object Object]
- [object Object]

**Dependências.** Nascido da prova **H5**. Vizinho de **E9** e **C6** sem os cobrir; mesma exigência de olhar externo que **E1**. O lote A é datado por **K7**.

*Remissões : `src/pages/importacoes/ImportacoesPage.jsx` · `src/components/rede/OaiSourcePanel.jsx` · `supabase/functions/export-catalog-lote` · `capture d'écran de Xavier du 02/09 (contexte blmf-teste)`*

---

### F — E-mail e notificações

*13 funções notify-*, 5 filas, 6 gatilhos de despacho. Ninguém jamais auditou o conjunto.*

| | | | |
|---|---|---|---|
| **F1** | Auditar a cadeia de e-mail de ponta a ponta | `P1` | Aberto |
| **F3** | Consolidar as funções de notificação redundantes | `P2` | Aberto |
| **F4** | Três bibliotecas tinham ativado lembretes que ninguém enviava | `P1` | Em curso |
| **F6** | `notify-internal-task` corre sobre uma cópia congelada de toda a pilha de e-mail | `P2` | Aberto |

#### F1 — Auditar a cadeia de e-mail de ponta a ponta

`P1` Prioritário · Estado : **Aberto** · Carga : alguns dias · O que exige : Deno / TypeScript, SQL / PostgreSQL

**Estado.** **14 funções `notify-*` implantadas**, cinco filas, seis gatilhos de despacho. Três filas nunca receberam uma única inserção: `authority_proposal_notification_outbox`, `membership_expiry_notifications`, `painel_internal_task_invitation_outbox`. Uma quarta, `painel_internal_task_notification_outbox`, está vazia após 34 inserções cuja última é de 04/06. Ninguém jamais auditou o conjunto.

*Verificado : 31/08 — **15** funções `notify-*` implantadas, a décima quinta nascida no mesmo dia com F4. As três filas nunca servidas seguem a zero. O perímetro cresce mais rápido que a auditoria.*

**O que é.** Traçar o mapa: para cada evento de negócio, qual gatilho, qual fila, qual função, qual template, quais dez línguas. Depois marcar os ramos mortos e os ramos nunca percorridos.

**Por que importa.** Uma notificação que não sai não faz barulho nenhum. É o mesmo ponto cego dos backups, e já mordeu duas vezes: os e-mails `retirada_efetivada`, `retirada_reagendada`, `retirada_no_show` e `liberada_para_circulacao` foram apontados como não saindo, sem que o diagnóstico fosse levado a termo.

**O que conta como terminado.**

- Um mapa escrito, evento por evento.
- Os quatro e-mails apontados como não enviados têm um veredicto: corrigidos, ou explicados.
- Os ramos mortos são suprimidos ou documentados como dormentes.

**Dependências.** Pré-requisito de **F2** e **F3**.

*Remissões : `Mémoire de projet, reliquats de la chaîne courriel` · `AUDITORIA_NOTIFY_FUNCTIONS_2026-05-06`*

#### F3 — Consolidar as funções de notificação redundantes

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : Deno / TypeScript

**Estado.** Quatro funções fazem resumos: `notify-weekly-report`, `notify-network-weekly-report`, `notify-cross-library-digest`, `notify-rede-digest`. Três funções servem documentos: `read-pdf`, `read-digital-asset`, `read-ill-shared-asset`. Duas exportam lotes: `export-catalog-lote`, `export-fonds-bundle`. E `mail-i18n-test`, função de teste, está implantada em produção na versão 1553.

*Verificado : 31/08 — `mail-i18n-test` continua implantada (versão 1 566). O repositório tem 50 pastas de funções e 38 declarações `verify_jwt`.*

**O que é.** Verificar o que cada uma faz de fato antes de concluir pela redundância — provavelmente têm destinatários e alcances diferentes. Depois fundir o que deve sê-lo, e retirar `mail-i18n-test` da produção.

**Por que importa.** 48 funções implantadas é muito para manter num projeto com um mantenedor. Cada uma carrega seu próprio template, suas próprias dez línguas, seus próprios segredos. Não é um problema de performance, é um problema de superfície a revisar.

**O que conta como terminado.**

- Cada grupo tem um veredicto: fusão, ou motivo escrito da separação.
- `mail-i18n-test` não está mais implantada em produção.
- A contagem de funções implantadas está atualizada em `CLAUDE.md` e em `config.toml`.

**Dependências.** Depois de **F1**. Atenção: a implantação de `notify-event` não passa por MCP, seu pacote é grande demais.

*Remissões : `PLAN_DE_MARCHE §8` · `Relevé du 29/08/2026`*

#### F4 — Três bibliotecas tinham ativado lembretes que ninguém enviava

`P1` Prioritário · Estado : **Em curso** · Carga : alguns dias · O que exige : SQL / PostgreSQL

**Estado.** `spec-flux-emprunts.md` §10.2 prevê lembretes em D-5, D-3 e no próprio dia, depois cobranças em D+1, D+7 e D+30. **Nenhum job dedicado é identificável** entre os 36 crons; o único vizinho é `anarbib-notify-mid-loan-reading-daily`, que faz outra coisa.

**Verificado em 30/08: a falta está confirmada.** Os onze crons cujo nome evoca um vencimento ou uma cobrança foram relidos um a um. **Nenhum lembra um vencimento de empréstimo nem cobra um atraso.** A dúvida está levantada: já não é um item a verificar, é uma decisão a tomar.

**Instruído e entregue em 31/08.** Os lembretes não existiam — mas **os interruptores que os comandam existiam**, e as três bibliotecas com política tinham-nos a `true` sem o saber. Seis momentos passam a **três** (`DOC-RAPPEL-1`). Um quarto envio substitui `notify-mid-loan-reading`, que perguntava «Como vai a leitura?» **em português fixo**: agora convida a deixar uma **nota de leitura sob pseudónimo** no catálogo. **Entregue**: EF `notify-loan-cycle`, tabela `loan_cycle_notifications` com unicidade (item, momento), suíte `rappels_echeance_tests.sql`.

*Verificado : 31/08 — levantamento em base e no repositório. Entregue no mesmo dia; **ainda não provado em envio real**.*

**O que é.** Ver a CI verde, implantar, depois **provar a sério**: criar um empréstimo com vencimento a J-3 e verificar que um e-mail parte, na língua certa, uma só vez.

**Por que importa.** O acompanhamento de oito semanas da formação BLMF prevê que uma consulta seja conduzida de ponta a ponta com negociação real: é o momento em que a ausência de lembrete aparecerá. Melhor saber antes.

**O que conta como terminado.**

- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]

**Dependências.** Verifica-se ao mesmo tempo que **F1**.

*Remissões : `spec-flux-emprunts §2.4 et §10.2` · `REGISTRE DOC-RAPPEL-1, OPS-8, DOC-SILENCE-1` · `supabase/functions/notify-loan-cycle/` · `migration 20260831111700` · `tests/sql/rappels_echeance_tests.sql` · `public.book_reading_notes`*

#### F6 — `notify-internal-task` corre sobre uma cópia congelada de toda a pilha de e-mail

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : Deno / TypeScript

**Estado.** **A divergência de assinatura foi fechada em 30/08.** O `resolveMailRouting` da cópia aceita agora uma locale e lê `signature_short_i18n[locale]`, igual ao canónico; `renderEmail` transmite-a, e os três envios do gestor passam a sua — já estava calculada quatro linhas acima de cada vez, por `normalizeTaskLocale`. Um aviso de tarefa na BLMF é agora assinado na língua de quem o lê. Guardado por `src/tests/notify-internal-task-signature.test.js`, 6 testes que exercitam o ficheiro real sobre o contexto real da BLMF — incluindo um que verifica que **sem locale, o comportamento é exatamente o de antes**.

**O que fica em aberto, e é o grosso:** os 9 ficheiros de infraestrutura duplicados. O levantamento abaixo não muda.

**Medido em 30/08, depois da abertura do item.** Há de facto três árvores `_shared` sob `supabase/functions/`, mas não pesam o mesmo: a de `catalog_metadata_lookup` contém apenas um `cors.ts` sem equivalente canónico — não é duplicação. O caso real é `notify-internal-task`.

Os seus 12 ficheiros repartem-se assim: **3 são legitimamente privados** (`data/internal-tasks.ts`, `handlers/internal-task.ts`, `i18n/task-mail-strings.ts`, ausentes do canónico) e **9 são infraestrutura duplicada, toda divergente** — `library-mail-routing` (116 linhas de diferença), `library-notification-context` (122), `mail/layout` (140), `transport/email` (121), `shared/format` (89), `context/policies` (42), `core/webhook` (30), `core/env` (10), `shared/branding` (4). Cerca de **694 linhas** ao todo.

**Porque existem estas cópias: a pergunta não tem resposta no repositório.** Aparecem no PRIMEIRO commit (`e6ec991a`, 21/08/2026) — 1 479 ficheiros e 615 892 inserções sob uma mensagem que fala de um botão do ecrã de catalogação. É a importação inicial: a história não começa antes. Nenhuma decisão está escrita em lado nenhum.

**O que diverge realmente, verificado:** o canónico resolve a assinatura de rodapé em `signature_short_i18n[locale]` com recurso a `signature_short`; a cópia só conhece `signature_short`, e o seu `resolveMailRouting` nem sequer aceita uma locale. **A BLMF tem `signature_short_i18n` preenchido em seis línguas.** Os seus avisos de tarefa interna são portanto assinados «Equipe da BLMF» seja qual for a língua da pessoa, ao passo que todos os outros e-mails da mesma biblioteca dizem «L'équipe de la BLMF» a quem lê em francês.

**O que NÃO diverge, também verificado:** `transportDisabledReason` é idêntico byte a byte nas duas cópias, e o contexto da cópia lê bem `channel_active`. O interruptor de envio tornado real em 30/08 é portanto honrado aqui como noutro sítio. `policyEnabled` e `resolveNetworkLogoUrl`, presentes só na cópia, não são chamados por ninguém.

*Verificado : 30/08 — levantamento feito ficheiro a ficheiro, depois da abertura do item: 9 ficheiros duplicados e todos divergentes, ~694 linhas, e **uma única divergência com efeito observável** — a assinatura de rodapé não traduzida, **fechada na mesma noite e guardada por 6 testes**. A origem das cópias não tem resposta no repositório: estão no primeiro commit. O que resta é uma decisão de alcance, não uma medição.*

**O que é.** A primeira pergunta do item — *porque existem estas cópias* — está encerrada: precedem a história do repositório, nenhuma decisão está escrita. É preciso portanto decidir **pelo mérito**, não por arqueologia.

**O menor gesto útil**, se não se quiser abrir o canteiro: dar ao `resolveMailRouting` da cópia o parâmetro `locale` e a leitura de `signature_short_i18n`, igual ao canónico. Isso fecha a única divergência cujo efeito foi constatado.

**O gesto completo**: fazer os 9 ficheiros de infraestrutura de `notify-internal-task` apontarem para `../../_shared/`, e guardar em próprio apenas os 3 ficheiros de tarefas. O risco não é nulo — 694 linhas de diferença talvez contenham outras diferenças desejadas — portanto cada ficheiro retoma-se um a um, comparando os envios antes/depois num aviso de tarefa real.

**E nos dois casos**: escrever no cabeçalho de `notify-internal-task/_shared/` o que ali vive e porquê, para que a próxima pessoa não tenha de refazer este levantamento.

**Por que importa.** Porque o roteamento do e-mail é justamente o sítio onde uma divergência não se vê. Um logótipo resolvido de outra forma, uma regra de extinção aplicada numa cópia e não na outra: a mensagem parte na mesma, e ninguém compara dois e-mails enviados por duas funções diferentes.

É exatamente o que acaba de acontecer à escala de uma única coluna — `register` resolvia o logótipo de forma diferente de todas as outras funções, e a diferença durou meses. Aqui a diferença é de 139 linhas.

**O que conta como terminado.**

- ~~A divergência de assinatura localizada está fechada~~ — feito em 30/08, guardado por 6 testes.
- O destino dos 9 ficheiros de infraestrutura duplicados está decidido — reunidos, ou assumidos por escrito.
- Um cabeçalho em `notify-internal-task/_shared/` diz o que ali vive e porquê.
- A colisão de nome sobre `resolveLibraryLogoUrl` está resolvida.

**Dependências.** Nenhuma. O levantamento está feito — está neste item. O que resta é uma decisão de alcance, não uma investigação.

*Remissões : `supabase/functions/_shared/context/library-mail-routing.ts` · `supabase/functions/notify-internal-task/_shared/ (12 fichiers, dont 9 dupliqués)` · `library_notification_profiles.signature_short_i18n (BLMF, 6 langues)` · `commit e6ec991a — import initial du dépôt, 21/08/2026` · `src/tests/notify-internal-task-signature.test.js`*

---

### G — Rede, governança, federação

*Muitos circuitos construídos, pouquíssimos percorridos. É o principal ensinamento do levantamento.*

| | | | |
|---|---|---|---|
| **G1** | Percorrer os circuitos construídos e jamais usados | `P0` | Aberto |
| **G5** | O que `is_test_mode` realmente comanda na Biblioteca Terra Livre | `P2` | Aberto |
| **G6** | Dar uma tela ao empréstimo entre bibliotecas | `P2` | Aberto |
| **G7** | Decidir a admissão da Biblioteca SOLIDAIRES | `P1` | Bloqueado |
| **G8** | Completar a cartografia com os arquivos identificados alhures | `P2` | Aberto |
| **G9** | Implementar a cartografia da rede segundo a spec v1.0 | `P3` | Congelado |
| **G10** | Liquidar as três questões de onboarding marcadas «o mais rápido possível» | `P2` | Aberto |

#### G1 — Percorrer os circuitos construídos e jamais usados

`P0` Estrutural · Estado : **Aberto** · Carga : várias semanas · O que exige : deliberação coletiva, nenhuma competência técnica

**Estado.** Verificado em 29/08: **62 tabelas de negócio nunca receberam uma única inserção.** Sete blocos inteiros são atingidos — assembleias da rede (3 tabelas), notas de leitura (2), propostas e objeções de autoridade (3), referenciais de catalogação `catalog_ref_*` (8 de 9), governança dos perfis de biblioteca (4, **enquanto dois crons rodam sobre elas a cada quinze minutos**), deliberação sobre os pedidos de adesão (5, incluindo `library_request_votes` e `library_request_messages`).

**Remedido em 31/08: ainda 62, e não é boa notícia.** A conta não mudou em dois dias — 62 tabelas de `public` em 189 nunca receberam uma inserção. Mas não é a mesma lista: `loan_cycle_notifications`, nascida esta manhã com os lembretes de vencimento, entrou nela **no dia da sua criação**. Um circuito entregue hoje junta-se de imediato à coluna dos circuitos jamais percorridos.

**Um primeiro livro circula.** O empréstimo **#69** foi aberto esta manhã na BLMF — item 84, *O Anarquismo na Escola, no Teatro, na Poesia*, de Edgar Rodrigues, vencimento **21/09**. Dá ao bloco *notas de leitura* a sua primeira hipótese real: o meio-percurso calculado por `notify-loan-cycle` cai em **10 de setembro**, e o convite a deixar uma nota sob pseudónimo parte nesse dia (item **F4**). `book_reading_notes` continua a zero linhas.

Os seis outros blocos estão inalterados em 31/08, verificados tabela a tabela: assembleias da rede (3), propostas e objeções de autoridade (3), referenciais `catalog_ref_*` (8), governança dos perfis (4, **e os dois crons continuam a rodar sobre elas a cada quinze minutos**), deliberação dos pedidos de adesão (5). Todos a zero inserções.

*Verificado : 31/08 — remedido em produção: **62 tabelas de `public` em 189** a zero inserções. A conta é estável, a lista não. Empréstimo **#69** aberto na BLMF; o convite a escrever uma nota de leitura é esperado em **10/09**.*

**O que é.** Escolher um bloco e percorrê-lo de verdade, do primeiro ao último gesto: realizar uma assembleia da rede, depositar uma nota de leitura, propor uma autoridade e deixar alguém objetar, fazer deliberar um pedido de adesão. Registrar o que falta, o que surpreende, o que trava.

**Por que importa.** É o principal ensinamento do levantamento de 29 de agosto, e não consta em nenhum documento do corpus. **O projeto não sofre de falta de funcionalidades: sofre de falta de uso.** Um circuito jamais percorrido não está entregue — está apenas escrito. E no dia em que se torna o caminho crítico, como o circuito de convite acaba de se tornar para as promoções, ele quebra em coisas que uma única passagem teria revelado.

**O que conta como terminado.**

- Pelo menos três dos sete blocos foram percorridos de ponta a ponta, em `blmf-teste` e depois no real.
- Cada passagem produziu um relatório escrito do que falta.
- Os blocos cujo uso não é desejado hoje são marcados **dormentes**, com o motivo — não é um fracasso, é uma informação.

**Dependências.** O bloco «assembleia» depende de **A1**. Os outros não.

*Remissões : `Relevé du 29/08/2026` · `REGISTRE §32 AG, §28 ATE, §26 ONBO` · `emprunt #69 (BLMF, item 84, échéance 21/09)` · `item F4` · `public.book_reading_notes`*

#### G5 — O que `is_test_mode` realmente comanda na Biblioteca Terra Livre

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : deliberação coletiva

**Estado.** **Verificado em 30/08, e o item reduz-se a metade.** O constato assentava em `library_commons.email_delivery_mode = 'test_only'`. Ora **nenhum caminho de envio lê essa coluna**: é o seletor inerte retirado no mesmo dia. O verdadeiro comutador é `library_mail_channels`, e diz outra coisa — a BTL tem `delivery_mode = 'platform_shared'` e `active = true`. **O correio da BTL parte normalmente, e sempre partiu.**

Resta uma pergunta: a coluna `libraries.is_test_mode`, ainda a `true` numa biblioteca de 2 187 exemplares publicada na rede. O que a lê, e o que ela muda?

*Verificado : 30/08 — `library_mail_channels` consultada: a BTL está em `platform_shared` / `active = true`. O que `is_test_mode` comanda não foi procurado.*

**O que é.** Procurar o que lê `libraries.is_test_mode` — no banco e no front. Três saídas, e é preciso decidir entre elas: ou a coluna comanda algo real, e é preciso perguntar à BTL o que quer; ou não comanda nada, e é um segundo seletor inerte a retirar (`DOC-SILENCE-1`); ou serve apenas a um filtro de exibição, e o seu nome mente sobre o alcance.

**Por que importa.** Em modo de teste, os e-mails não saem. Uma biblioteca com 2 187 exemplares publicados cujas leitoras não recebem nenhuma notificação é ou uma escolha, ou uma pane silenciosa há meses. A BTL entrou na rede com um estatuto «experimental» assumido — mas um estatuto político e um ajuste técnico não são a mesma coisa.

**O que conta como terminado.**

- A BTL respondeu, e a configuração corresponde à sua resposta.
- O estatuto está escrito onde alguém vai procurá-lo.

**Dependências.** Nenhuma. Uma conversa.

*Remissões : `PLAN_formation_coordination_BLMF §8`*

#### G6 — Dar uma tela ao empréstimo entre bibliotecas

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript, biblioteconomia

**Estado.** O ciclo de vida do empréstimo entre bibliotecas está especificado e implementado no banco: máquina de estados travada, quatro triggers, cron `anarbib-peb-detect-overdue-daily` ativo. **Nenhuma tela existe.** O banco traz 2 empréstimos para 20 inserções históricas.

*Verificado : 31/08 — `interlibrary_loans_v2`: 2 empréstimos vivos para 20 inserções, como em 29/08.*

**O que é.** Uma tela de pedido do lado da biblioteca solicitante, uma tela de tratamento do lado da emprestadora, e a exibição do estado para as duas. As views `interlibrary_loans_painel_ui` e `interlibrary_loan_items_ui` já existem.

**Por que importa.** O empréstimo entre bibliotecas é o que torna uma rede federativa útil às suas leitoras, em vez de uma simples justaposição de catálogos. Hoje ele tem «um início no banco, mesmo sem tela» — o que quer dizer que ninguém pode usá-lo.

**O que conta como terminado.**

- Um empréstimo completo foi feito entre duas bibliotecas da rede, pela interface.
- O fluxo «livro perdido ou danificado» tem um tratamento escrito — **nenhum fluxo o cobre hoje**, trata-se fora do SIGB com escalada à coordenação.

**Dependências.** `EA-12 fase 2` (paridade EEB, cerca de 45 funções) está congelada por `BIBLIO-9` — a não confundir com este item.

*Remissões : `spec-cycle-vie-peb.md` · `PLAN_formation_coordination_BLMF §5` · `REGISTRE §14 PEB`*

#### G7 — Decidir a admissão da Biblioteca SOLIDAIRES

`P1` Prioritário · Estado : **Bloqueado** · Carga : não estimado · O que exige : deliberação coletiva

**Estado.** Decisão federal **deliberadamente adiada**, por não poder ser tomada em conjunto. Prazo previsto: outubro ou novembro, depois de Bolonha.

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** `cartography_entries` traz 187 fichas e o arquivo `anarbib_bibliotheques_libertaires.geojson` conta 121. Nove arquivos identificados na rede NORLA não foram confrontados com essa lista.

*Verificado : 31/08 — 187 fichas no banco. O arquivo público mudou de endereço: `data/carte-publique.geojson` no repositório vitrine, **109** entradas (o item citava 121). As nove NORLA seguem por confrontar.*

**O que é.** Verificar quais das nove já constam, e fazer entrar as ausentes com `source = "FICEDL"` ou `"NORLA"` conforme sua proveniência.

**Por que importa.** O mapa só tem interesse se for mais completo do que aquilo que cada um já conhece. E a rastreabilidade da fonte é o que permitirá mais tarde dizer de onde vem cada ficha sem ter de perguntar de novo.

**O que conta como terminado.**

- Os nove arquivos têm um veredicto: já presente, ou acrescentado com sua fonte.
- Lembrete: `statut_public` está em `FALSE` por omissão e **nenhuma importação em massa** é autorizada (`MAP-E`).

**Dependências.** Nenhuma. **Entrada sem competência técnica.**

*Remissões : `VEILLE_leftovers_maydayrooms_2026-08-19 §3.4` · `REGISTRE §34 MAP-E`*

#### G9 — Implementar a cartografia da rede segundo a spec v1.0

`P3` Adiado · Estado : **Congelado** · Carga : várias semanas · O que exige : React / JavaScript

**Estado.** As arbitragens estão decididas desde 18/06: tabela dedicada, i18n híbrida, mapa público como rota do aplicativo, motor Leaflet, OpenStreetMap e Nominatim auto-hospedados, entradas não membros exibidas com um filtro claro. `MAP-I` (estatuto do empréstimo entre bibliotecas no mapa interno) e `MAP-J` (autodeclaração «adicionar minha biblioteca» com moderação) continuam adiados.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Retomar a spec v1.0 quando a janela se abrir. Atenção: o REGISTRO traz **duas seções `MAP`** — a §2 é um esqueleto onde tudo está aberto, a §34 é a versão decidida. A §2 não tem carimbo de supersessão nem remissão à §34: **é a §34 que vale**.

**Por que importa.** O mapa é o primeiro objeto que uma biblioteca que descobre a rede vai olhar. Merece ser feito quando houver tempo para fazê-lo bem, e não na janela anterior a Bolonha.

**O que conta como terminado.**

- O mapa público é uma rota do aplicativo, servido sem requisição a terceiro (ver **E5**).
- A §2 do REGISTRO traz uma remissão à §34.

**Dependências.** Depois de Bolonha. Ligado a **E5** e **J5**.

*Remissões : `spec-cartographie-reseau.md v1.0` · `REGISTRE §34 MAP`*

#### G10 — Liquidar as três questões de onboarding marcadas «o mais rápido possível»

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : deliberação coletiva

**Estado.** Três pontos estão marcados 🔴 «a resolver o mais rápido possível» desde junho e não se moveram: `#111` (avaliação colaborativa de uma pessoa administradora de rede, dormente), `ONBO-Q13` (transferência técnica do mandato de coordenação), e o acabamento do módulo 10 da oficina de onboarding.

*Constato de 29/08, não reverificado desde então.*

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
| **H6** | Alinhar os vocabulários militantes que não se conhecem | `P2` | Aberto |

#### H1 — Reparar a coleta dos 158 descritores de datas do tesauro

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : Deno / TypeScript, biblioteconomia

**Estado.** `parseDescriptor` sai por retorno antecipado antes de alcançar o título de página quando uma ficha não tem bloco de tradução. Resultado: **158 descritores da faceta «datas», ou seja um quarto do tesauro, são registrados como identificadores nus, sem rótulo, portanto não alinháveis.** Seus vínculos com os catálogos se perdem da mesma forma. A correção `ficedl_scrape_titre_dates.patch` existe, passa `node --check`, e **nunca foi testada contra o site**.

*Verificado : 31/08 — precisão: os 158 descritores de datas estão sem rótulo no **JSON de aspiração** (620 termos); a tabela não traz **nenhum** deles — 462 linhas, só facetas assuntos e geo. No banco eles não estão « nus »: faltam. O corretivo segue sem prova contra o site.*

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

**Estado.** A exportação completa dos 620 descritores nos dois formatos está a **uma noite de trabalho** — assim que as sete questões tiverem resposta. Estão escritas e ninguém ainda as colocou.

*Constato de 29/08, não reverificado desde então.*

**O que é.** As sete: a forma dos identificadores; **a hierarquia, que é a verdadeira questão**; o estatuto da faceta «datas»; o destino dos 2 842 vínculos para seis catálogos; o grego romanizado; a licença; e a maneira como o arquivo se regenera.

**Por que importa.** De 148 descritores com rótulo arborescente, **93 pais são encontrados e 55 são inencontráveis**: «arte», «economia», «guerras», «literatura», «imprensa», «sindicalismo» não são descritores, ou têm outro nome. Visto de fora, **a hierarquia não é um dado, é uma convenção de exibição numa cadeia de caracteres** — e não se pode escrever `skos:broader` honestamente sobre isso. Só a FICEDL pode dizer se o site mantém uma verdadeira relação pai-filho.

**O que conta como terminado.**

- As sete questões estão colocadas, com a auditoria de qualidade produzida na primeira coleta em anexo — **as correções pertencem à fonte, não às cópias**.
- Quatro anomalias vistas de passagem são reportadas: dois sites diferentes sob o mesmo rótulo «catálogo do CCL»; os arquivos do *Monde libertaire* aparecendo duas vezes por termo sob duas formas de endereço; `mot228` («populações autóctones») presente em duas facetas; 29 rótulos portugueses com asterisco, ponto de interrogação ou espaço final.
- A questão 7 é a mais rentável: um esqueleto SPIP que imprime os termos em CSV resolve também a carga de robôs — **uma requisição em vez de 620, por consumidor e por atualização**, para meia jornada de trabalho do lado da FICEDL.

**Dependências.** Bloqueia **H3**. A colocar em Bolonha ou antes.

*Remissões : `NOTE_export_thesaurus_questions_ouvertes_2026-08-28`*

#### H6 — Alinhar os vocabulários militantes que não se conhecem

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia, deliberação coletiva

**Estado.** A NORLA construiu seu vocabulário — com suas facetas *Tactics* e *Social Movement* — **sem vínculo com o tesauro FICEDL**. Dois vocabulários militantes, construídos em paralelo, que se ignoram. Além disso, as 11 categorias temáticas do AnarcosyndicalismeBOOK não estão alinhadas a nada.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Começar pelo menor e mais viável: as 11 categorias do AnarcosyndicalismeBOOK, **um primeiro passo concreto, delimitado, viável numa noite** — e como o tesauro já está em dez línguas, o alinhamento vale simultaneamente para as dez. Depois abrir a conversa com a NORLA.

**Por que importa.** Cada vocabulário construído isoladamente é um acervo que os outros não encontrarão. Reserva a ter em mente: os vocabulários de efêmeros são **monolíngues**, o alinhamento será mais pesado neles do que em assuntos.

**O que conta como terminado.**

- As 11 categorias do AnarcosyndicalismeBOOK estão alinhadas.
- Uma conversa está aberta com a NORLA sobre o alinhamento das facetas.
- A reciprocidade é pedida: **os catálogos parceiros não apontam de volta** hoje.

**Dependências.** Outubro-novembro, se Bastien topar. Ligado a **D4**.

*Remissões : `ORIENTATION_outils_bibliotheques_militantes_2026-08-26 §6` · `VEILLE_leftovers_maydayrooms_2026-08-19`*

---

### I — Auto-hospedagem, operação, backups, CI

*Congelado até 14/09/2026 na produção. O trabalho em ambiente de teste continua aberto.*

| | | | |
|---|---|---|---|
| **I1** | Alinhar a imagem GoTrue com o estado real das migrações de autenticação | `P1` | Congelado |
| **I2** | Concluir a migração para a auto-hospedagem | `P1` | Congelado |
| **I3** | Testar o roteador `main` da pilha auto-hospedada | `P1` | Congelado |
| **I4** | Terminar a testemunha de proveniência dos backups | `P1` | Aberto |
| **I6** | Purgar os registros da sonda de saúde | `P2` | A verificar |
| **I8** | Pôr `deploy/README.md` de acordo com o que foi executado | `P2` | Aberto |
| **I10** | Limpar os rastros do Turnstile e os arquivos de refugo | `P2` | Aberto |
| **I11** | Sair do `node:20`, em fim de manutenção | `P2` | Aberto |
| **I12** | Automatizar a atualização do espelho frio | `P2` | Aberto |
| **I13** | Terminar a migração para o novo motor de páginas | `P3` | Aberto |
| **I14** | A CI não faz redeploy de nada quando só a configuração das funções muda | `P1` | Aberto |
| **I15** | O secret do Forgejo da chave publicável ainda carrega seu nome antigo | `P3` | Aberto |
| **I16** | supabase-js: uma versão fixada, vinte e nove flutuantes — decidir um regime | `P3` | Decisão coletiva |

#### I1 — Alinhar a imagem GoTrue com o estado real das migrações de autenticação

`P1` Prioritário · Estado : **Congelado** · Carga : alguns dias · O que exige : administração de sistemas

**Estado.** A produção traz **77 migrações `auth`** (remedido em 31/08). **O constato sobre a fixação caducou: `deploy/.env` e `.env.example` trazem ambos `GOTRUE_TAG=v2.192.0`.** O que a v2.192.0 embarca não foi medido: o alinhamento continua por provar.

*Verificado : 31/08 — `auth.schema_migrations`: 77; `deploy/.env` e `.env.example` relidos: `v2.192.0` dos dois lados.*

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

**Estado.** A pilha está reduzida de doze a **seis contêineres** (`db`, `rest`, `auth`, `storage`, `functions`, `caddy`), as versões estão fixadas, `bootstrap.sh` foi executado de verdade em 26/08 com oito defeitos levantados e corrigidos, e o ensaio de 18/08 reexecutou 124 migrações e restaurou um dump de produção em 17 segundos. Reconstrução completa medida: **25 minutos**.

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** `supabase/functions/main/index.ts` existe (6,9 KB), lê `config.toml` na inicialização, aplica uma **recusa por omissão** — só as dispensas `verify_jwt = false` são lidas, todo o resto exige um token — e recusa iniciar se o arquivo for ilegível. **Os quatro testes previstos não foram feitos.**

*Verificado : 31/08 — `main/index.ts`: 6 885 bytes, presente; nenhum teste o menciona.*

**O que é.** Os quatro testes da etapa 5 de `deploy/REPETITION.md`: função protegida sem cabeçalho de autorização → 401; com um token válido → 200; `health-probe` sem token → 200; nome inexistente → 404.

**Por que importa.** O roteador é o que substitui a proteção por omissão da plataforma no dia da migração. Como `config.toml` só declara 31 funções de 48, **a recusa por omissão do roteador fechará dezoito funções que hoje funcionam** — é preciso saber isso antes, não depois.

**O que conta como terminado.**

- Os quatro testes passam.
- O comportamento para as 18 funções não declaradas é conhecido e desejado.

**Dependências.** **Bloqueado por B6.** Congelado na produção até 14/09; o teste em ambiente de teste está aberto.

*Remissões : `deploy/README.md` · `deploy/REPETITION.md étape 5`*

#### I4 — Terminar a testemunha de proveniência dos backups

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** A migração `20260827180000_temoin_sauvegarde_provenance.sql` está **testada num PostgreSQL 16 descartável, com sete controles passados, mas nunca executada contra a produção**. A correção `health_probe_provenance.patch` **não se aplica**: `patch failed … index.ts:286`. Foi produzida contra o espelho GitHub.

*Verificado : 31/08 — a versão `20260827180000` não está nem no repositório nem no registro de produção. « provenance » aparece dez vezes no `health-probe` do repositório: a parte função existe ao menos em parte; a parte banco, em lugar nenhum.*

**O que é.** Desempatar o conflito por `git hash-object` no arquivo alvo, comparado ao blob de base `0d00dc0e016fdfb86ef314e4e707abd4a84d1d2c`. **Impressão idêntica → `git apply --3way` passa. Impressão diferente → refazer a correção à mão sobre a versão real: não forçar, não sobrescrever.** Depois implantar `health-probe`.

**Por que importa.** O que a correção deve obter, seja qual for o caminho: no e-mail, cada fluxo exibe seu host (ou «nenhum») e uma menção explícita quando se trata de uma semeadura; na razão de backup, `(última fonte: …)` ou `(nenhum sinal recebido)`. Sem isso, um e-mail verde não diz de onde vem o verde — e é exatamente o defeito que deixou os backups falharem 36 horas em silêncio.

**O que conta como terminado.**

- A migração está em `supabase/migrations/` e aplicada.
- `health-probe` está implantada com o comportamento de proveniência.
- **`temoin_sauvegarde_provenance.patch` está vencido: ignorar, não aplicá-lo.**

**Dependências.** Não confundir com o `snapshot_id` nulo em cinco linhas: o remédio cabe em três linhas mas **`anarbib-bg2.sh` vive na estação de trabalho, fora do repositório** — é para sinalizar, não para tentar a partir do repositório.

*Remissões : `NOTE_temoin_sauvegarde_2026-08-27` · `REPRISE_claude_code_2026-08-27 chantier 1`*

#### I6 — Purgar os registros da sonda de saúde

`P2` Corrente · Estado : **A verificar** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** **Constato corrigido em 31/08 à noite: a purga existe — vive na própria sonda, não num cron.** `health-probe` apaga a cada volta os registros com mais de 30 dias (verificado no código implantado). Nunca apagou nada (`n_tup_del = 0` para 16 268 inserções): a tabela nasceu em 17/08, mais jovem que sua retenção. O levantamento procurava um *cron*; o dispositivo estava no corpo da função — `DOC-RECENS-1` de novo. Escrever o cron pedido teria feito uma purga em dobro.

*Verificado : 31/08 — código implantado relido (retenção 30 dias); `pg_stat_user_tables`: 16 268 inserções, **0 supressão**, mais antigo de 17/08 — nascimento da tabela, não efeito de purga. Primeiro efeito esperado por volta de **16/09**.*

**O que é.** Um cron de purga no modelo de `anarbib-catalog-audit-snapshot-purge`, com uma retenção a decidir — trinta dias provavelmente bastam, já que os incidentes são conservados à parte em `service_health_incidents`.

**Por que importa.** É a tabela mais volumosa do banco, e só contém ruído do qual o útil já foi extraído. Nesse ritmo alcançará cem mil linhas antes do fim do ano, o que pesará em cada backup à toa.

**O que conta como terminado.**

- ~~Um cron de purga existe, com uma retenção escrita~~ — a purga existe desde a origem, na própria função, retenção de 30 dias; o cron pedido faria dobro.
- ~~`service_health_incidents` não é tocada pela purga~~ — verificado: a purga só visa `service_health_probes`.
- A purga apagou de verdade: `n_tup_del > 0`, a levantar depois de 16/09.

**Dependências.** Nenhuma.

*Remissões : `Relevé du 29/08/2026` · `REGISTRE §38 OPS`*

#### I8 — Pôr `deploy/README.md` de acordo com o que foi executado

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** O documento afirma em negrito: «Nada disso ainda rodou». Três commits de 26/08 descrevem execuções reais com oito defeitos levantados. Além disso `bootstrap.sh` tem **oito etapas** mais uma «7 bis» e uma verificação, onde o README anuncia sete; e o README declara `notify-cross-library-digest` «ausente do repositório» quando ela está lá.

*Verificado : 31/08 — `deploy/README.md` ainda afirma que nada rodou e ainda declara `notify-cross-library-digest` ausente do repositório.*

**O que é.** Reescrever a seção de estado a partir dos diários de execução de 26/08, corrigir a contagem de etapas, e retirar a afirmação sobre `notify-cross-library-digest`.

**Por que importa.** `deploy/README.md` é o documento que lerá quem assumir **A2** — a reconstrução por um terceiro. Uma frase que diz «nada rodou» vai fazê-lo crer que está abrindo caminho quando oito defeitos já foram encontrados e corrigidos para ele.

**O que conta como terminado.**

- A seção de estado descreve o que rodou e o que não rodou.
- Os quatro pontos «a confirmar antes da migração» têm um veredicto: GoTrue e o e-mail, `PGRST_DB_SCHEMAS` posto em `public,api,storage` por dedução, o caso `notify-cross-library-digest` (encerrado), e a reexecução das migrações.
- `CADDY_TAG=2` é um tag maior flutuante num arquivo que proclama «nenhum `latest`, jamais»: a fixar ou a justificar.

**Dependências.** Pré-requisito moral de **A2**.

*Remissões : `deploy/README.md` · `Commits 57321385, 35c03dd5, 90266600`*

#### I10 — Limpar os rastros do Turnstile e os arquivos de refugo

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** O Turnstile foi inteiramente retirado do código em 20/08 — sua reaparição seria uma regressão. Mas **chaves de teste subsistem** em `.env.example` (duas entradas), `.env.local`, `deploy/functions.env`, uma referência em `package.json`, e um segredo no Vault. Além disso `tmp-ficedl/` (754 KB, duplicata exata de um arquivo versionado) fica na raiz, e `docs/drafts/` está versionado sem regra.

*Verificado : 31/08 — a limpeza avançou: nenhum traço Turnstile em `package.json`, `.env.local`, `functions.env` nem no Vault. Restam: o segredo de função `TURNSTILE_SECRET_KEY`, `tmp-ficedl/` (740 KB) e `docs/drafts/` sem regra.*

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

**Estado.** Os três jobs de integração contínua rodam num contêiner `node:20`, cuja janela de manutenção de longo prazo terminou em abril de 2026. É o ponto de fim de vida mais claro da cadeia.

*Verificado : 31/08 — 7 ocorrências de `node:20` nos dois workflows. Nada mudou.*

**O que é.** Passar para a versão em manutenção longa seguinte, verificar que o build, os testes e o lint passam, e que a CLI Supabase fixada `v2.98.1` se instala nela.

**Por que importa.** Uma imagem sem atualizações de segurança faz rodar toda a implantação. A mudança é mecânica e se verifica numa execução.

**O que conta como terminado.**

- Os três jobs rodam numa versão mantida.
- O lint continua com zero erro (cerca de cem avisos é o estado normal).

**Dependências.** Nenhuma.

*Remissões : `.forgejo/workflows/ci.yml` · `package.json`*

#### I12 — Automatizar a atualização do espelho frio

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** O espelho frio `anarbib-mirror.git` existe na estação de trabalho e sua atualização é manual. As unidades systemd `anarbib-mirror-refresh.service` e `.timer` estão versionadas em `deploy/ops/` mas sua entrada em serviço não está confirmada.

*Verificado : 31/08 — as unidades estão versionadas em `deploy/ops/systemd/`. O espelho frio traz um HEAD de 30/08 às 16h — no máximo um dia de atraso — mas nada daqui distingue um timer ativo de um refresh manual.*

**O que é.** Verificar se o temporizador roda, e senão colocá-lo em serviço. Registrar o frescor do espelho em algum lugar legível.

**Por que importa.** Uma reconstrução exige **três** coisas e não duas: o repositório, um backup, **e os segredos do Vault**. O espelho frio é a terceira cópia do repositório, depois do Codeberg e do espelho GitHub. Só serve se estiver atualizado — e o espelho GitHub já acumulou 6 878 objetos de atraso uma vez.

**O que conta como terminado.**

- A atualização é automática e sua falha alerta.
- O frescor do espelho aparece na testemunha de backup.

**Dependências.** Ligado a **I4**.

*Remissões : `RUNBOOK_exploitation_v0.3 §4 §9.1`*

#### I13 — Terminar a migração para o novo motor de páginas

`P3` Adiado · Estado : **Aberto** · Carga : alguns dias · O que exige : administração de sistemas

**Estado.** A etapa 0 é conclusiva desde 20/08: `test.anarbib.org` é servido pelo novo motor em paralelo. A cadeia de integração contínua já usa a ação `git-pages`. **O Codeberg Pages em versão histórica está em modo de manutenção, não em fim de vida** — a documentação diz que continuará funcionando indefinidamente.

*Verificado : 31/08 — parte da limpeza já está feita: o branch `pages` não existe mais, `public/.domains` sumiu, `public/CNAME` preservado.*

**O que é.** Colocar o registro TXT de lista branca, criar `public/_redirects` com a regra de reescrita, verificar que uma rota desconhecida retorna 200 com o conteúdo certo, depois limpar **somente após** verificação verde.

**Por que importa.** Dois pontos de vigilância estão escritos. **Não tocar nos registros A e AAAA**, que estão bons. E **verificar a caixa do URL**: o workflow escreve `AnarBib`, a documentação escreve `anarbib` — na dúvida, colocar os dois registros TXT.

**O que conta como terminado.**

- O site é servido pelo novo motor, com as rotas desconhecidas em 200.
- A limpeza é feita após verificação: `public/.domains`, o branch `pages`, os segredos que se tornaram inúteis.
- **Deixar `public/CNAME`** — serve ao espelho GitHub.
- Incertezas assumidas: a reversibilidade da migração não está documentada em lugar nenhum, nenhum limite numérico está publicado (tamanho, banda, prazo), e os arquivos vendorizados pesam — **ponto a vigiar na primeira implantação**.

**Dependências.** P1, não P0 — a versão histórica não tem data de encerramento anunciada.

*Remissões : `PLAN_migration_git_pages_2026-08-19` · `RUNBOOK_exploitation_v0.3`*

#### I14 — A CI não faz redeploy de nada quando só a configuração das funções muda

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** Constatado em 01/09: o commit `c152e7fa` passava `login`, `register` e `request-password-reset` para `verify_jwt = false` e só tocava `supabase/config.toml` — a CI ficou verde e não implantou nada. O `deployer-backend.sh` decide o redeploy com `git diff -- supabase/functions/` (perto da linha 296): uma mudança só de configuração é invisível para ele. Foi preciso implantar as três funções à mão para o ajuste ter efeito.

*Verificado : 01/09 — reproduzido em produção: três funções ainda respondendo o 401 da plataforma depois do run verde de `c152e7fa`, respostas aplicativas corretas depois do deploy manual das três.*

**O que é.** Ampliar a detecção para `supabase/config.toml` — no mais simples, reimplantar tudo quando ele muda; no mais fino, reimplantar só as funções cuja seção `[functions.*]` mudou. E documentar o caso na narrativa do bloco « Edge Functions » do script, que já conta o incidente `--depuis event.before` de 27/08: é a mesma família de ponto cego. Uma ficha de tarefa foi criada em 01/09.

**Por que importa.** Um `verify_jwt` que não vai para produção é uma porta que se acredita ter aberto ou fechado quando ela não se moveu — e a CI verde afirma o contrário. Mesmo silêncio do `--depuis` de 27/08: nada fica vermelho, o trabalho simplesmente não é feito.

**O que conta como terminado.**

- Um commit que só toca `config.toml` dispara um redeploy, verificado com um teste real.
- O comentário do script conta esse terceiro incidente ao lado dos dois primeiros.

**Dependências.** Nenhuma.

*Remissões : `scripts/ci/deployer-backend.sh` · `item B18`*

#### I15 — O secret do Forgejo da chave publicável ainda carrega seu nome antigo

`P3` Adiado · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** Desde 01/09, o código lê `VITE_SUPABASE_PUBLISHABLE_KEY` e seu valor é mesmo a chave publicável — mas na CI essa variável é alimentada pelo secret do Forgejo com o nome histórico `VITE_SUPABASE_ANON_KEY`. Desacoplamento proposital: evitava exigir a renomeação do secret e o merge no mesmo instante. A armadilha está documentada no `ci.yml`: o `prebuild` faz `exit 0` se a variável faltar, um nome desalinhado não quebra o build, publica um instantâneo de catálogo vencido em silêncio.

*Verificado : 01/09 — `ci.yml` relido depois da virada: mapeamento `VITE_SUPABASE_PUBLISHABLE_KEY: ${{ secrets.VITE_SUPABASE_ANON_KEY }}` no lugar, comentado.*

**O que é.** Criar o secret `VITE_SUPABASE_PUBLISHABLE_KEY` nas configurações do Forgejo (mesmo valor), alinhar a linha do `ci.yml`, verificar um build completo — o frescor do `catalogue-snapshot.json` serve de prova — e então apagar o secret antigo.

**Por que importa.** O canteiro das chaves pagou duas vezes o preço de um nome que mente — uma variável de plataforma cujo conteúdo mudou sem avisar, e um controle `verify_jwt` satisfeito por uma chave pública. Melhor não deixar um terceiro no lugar, mesmo benigno.

**O que conta como terminado.**

- A linha do `ci.yml` lê um secret com o mesmo nome da variável, o secret antigo não existe mais, e um build posterior produziu um snapshot com a data do dia.

**Dependências.** Acesso às configurações do repositório Forgejo (Settings → Actions → Secrets).

*Remissões : `.forgejo/workflows/ci.yml` · `item B18`*

#### I16 — supabase-js: uma versão fixada, vinte e nove flutuantes — decidir um regime

`P3` Adiado · Estado : **Decisão coletiva** · Carga : uma noite · O que exige : Deno / TypeScript

**Estado.** O `_shared/core/env.ts` fixa `supabase-js@2.112.4` (antes de 01/09: `2.49.1`, sessenta versões para trás durante meses); as vinte e nove outras funções importam `@2` flutuante, resolvido no deploy. O dia 01/09 mostrou o que esse regime misto produz: as flutuantes tinham absorvido em silêncio o suporte às chaves `sb_` enquanto a fixada o ignorava — o diagnóstico de compatibilidade errou exatamente aí.

*Verificado : 01/09 — levantamento dos imports: `grep supabase-js@ supabase/functions -r` → 1 fixado (`env.ts`), 29 em `@2`, 1 em `@2` via npm:.*

**O que é.** Decidir: fixar tudo (deploys reproduzíveis, mas é preciso um ritual de subida de versão, senão repete-se o caso das sessenta versões de atraso) ou deixar tudo flutuar (sempre em dia, mas uma ruptura maior da biblioteca chega em produção sem avisar). Um ou outro — não a mistura atual.

**Por que importa.** A mistura dá o pior dos dois regimes: acredita-se a versão controlada onde ela flutua, e em dia onde está congelada. Os dois erros de 01/09 — um por excesso de confiança na fixação, outro por ignorância da flutuação — saem do mesmo desacordo.

**O que conta como terminado.**

- Uma regra escrita existe (no `CONTRIBUTING.md` ou no cabeçalho do `env.ts`), e as cinquenta e uma funções a seguem todas.

**Dependências.** Nenhuma — é uma arbitragem, não um canteiro.

*Remissões : `supabase/functions/_shared/core/env.ts` · `CONTRIBUTING.md`*

---

### J — Documentação e corpus

*O corpus é vasto e sua deriva é medida. Este backlog faz parte dele.*

| | | | |
|---|---|---|---|
| **J2** | Reparar o índice dos backlogs e decidir a convenção de arquivamento | `P2` | Aberto |
| **J6** | Escrever as cinco doutrinas internalizadas onde um terceiro as encontraria | `P2` | Aberto |

#### J2 — Reparar o índice dos backlogs e decidir a convenção de arquivamento

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado.** **Corrigido em 31/08: a linha do v32 está restabelecida desde 29/08.** Restam: as duas convenções de nomenclatura (9 arquivos com prefixo `-archive-`, 27 sem) e um cabeçalho do INDEX que já deriva (« 90 itens », « restam 84 », quando o JSON conta 83).

*Verificado : 31/08 — `INDEX.md` relido, arquivos contados: 9 com prefixo `-archive-`, 27 sem.*

**O que é.** Acrescentar a linha do v32, as do v33 e do v34, e decidir a convenção de arquivamento numa frase inscrita no REGISTRO.

**Por que importa.** O índice dos backlogs é o que permite saber qual versão faz fé. Uma linhagem com um buraco e duas convenções concorrentes não cumpre esse ofício.

**O que conta como terminado.**

- A tabela está completa do v8 ao v34.
- Uma única convenção de nomenclatura está inscrita no REGISTRO.

**Dependências.** Faz-se ao depositar este backlog.

*Remissões : `docs/backlogs/INDEX.md`*

#### J6 — Escrever as cinco doutrinas internalizadas onde um terceiro as encontraria

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado.** Cinco regras de concepção são aplicadas em toda parte e escritas em nenhum lugar acessível: a ordem das atualizações numa RPC (o relato antes do estado), a distinção entre `workflow_note` e `schedule_reply_note`, a proibição de `async` em `onAuthStateChange`, as armadilhas de codificação sob PowerShell, e o contrato `actionBox` da função de renderização dos e-mails.

*Verificado : 31/08 — `CONTRIBUTING.md` existe, mas nenhuma ocorrência de `actionBox` nem `workflow_note` é alcançável dali.*

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
| **K5** | Realizar a intervenção de Bolonha e tirar as consequências | `P1` | Em curso |
| **K6** | Preparar o encontro com leftove.rs e May Day Rooms | `P2` | Em curso |
| **K7** | Conduzir a formação das duas coordenações BLMF até a autonomia | `P1` | Em curso |
| **K8** | Terminar o texto de orientação sobre as ferramentas de bibliotecas militantes | `P2` | Aberto |

#### K1 — Fazer adotar a ata de criação do Fundo AnarBib

`P0` Estrutural · Estado : **Bloqueado** · Carga : uma noite · O que exige : deliberação coletiva

**Estado.** Um projeto de ata está redigido e arquivado. Não foi adotado. **É o preliminar político à abertura de qualquer canal de arrecadação: nada se move antes.**

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** O Liberapay está no ar e recebeu sua primeira doação em 27/08. O encarte «apoiar financeiramente» está publicado nas dez locales e nomeia o Liberapay como único canal aberto. **Pix e IBAN dormem** num bloco de comentário HTML entre os marcadores `ENCART-DORMANT-START` e `ENCART-DORMANT-END`.

*Verificado : 31/08 — os marcadores `ENCART-DORMANT-START` estão nos dez arquivos do repositório vitrine.*

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

**Estado.** `FINANCES.md` está na raiz do repositório vitrine e dez páginas públicas são geradas a partir dele, por língua. O gerador sinaliza nominalmente toda célula não traduzida. Uma tabela distinta traz o que uma pessoa adiantou antes de o fundo existir — cerca de **228 € de março a agosto de 2026** — e a questão de saber se é uma dívida a reembolsar fica para a assembleia.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Registrar cada receita e cada despesa continuamente, e reexecutar o gerador após cada edição.

**Por que importa.** **Registrar os adiantamentos passados desde já, antes da deliberação** — daqui a um ano, ninguém se lembrará dos valores. O regime de transparência escolhido é o relatório anual mais as contas sob pedido; só se sustenta se o registro estiver atualizado.

**O que conta como terminado.**

- O registro está atualizado e as dez páginas refletem seu conteúdo.
- Antecipação anotada: a renovação do domínio em março de 2027 custará mais caro, a promoção do primeiro ano não se renovando.

**Dependências.** Independente de **K1** e **K2**.

*Remissões : `PLAN_financement_AnarBib_2026-08-25` · `tools/build-finances-pages.cjs`*

#### K5 — Realizar a intervenção de Bolonha e tirar as consequências

`P1` Prioritário · Estado : **Em curso** · Carga : alguns dias · O que exige : deliberação coletiva

**Estado.** Oficina AnarBib em 12/09 pela manhã, assembleia aberta em 13. Um conjunto de 29 slides italiano-inglês está pronto, assim como um folheto manifesto bilíngue. Três objetivos anunciados: a gênese e a concepção, o panorama das funcionalidades, e **um chamado à participação**.

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** **A mensagem foi enviada** — por volta de 19/08, três semanas antes do encontro, exatamente a janela visada: cedo o bastante para que olhassem o AnarBib sem que fosse urgente. **A oficina AnarBib é de manhã, a oficina leftove.rs à tarde do dia 12/09, mesma sala, mesmo dia.** O que continua aberto são as respostas e a preparação do dia.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Retomar o contato se necessário, e preparar as três perguntas feitas para que sejam discutidas no local: o vocabulário de assuntos, o perfil de digitalização (eles têm 16 000 documentos ocerizados), e a NORLA e a cartografia. Mais a pergunta sobre auto-hospedagem ao coletivo técnico presente.

**Por que importa.** Duas oficinas no mesmo dia na mesma sala, sobre assuntos vizinhos, sem que as duas equipes tenham se falado, seria um desperdício. E há um ponto a olhar antes, não depois: **leftove.rs está sob licença CC BY-NC-SA, e a cláusula não comercial não é uma licença livre em sentido estrito.**

**O que conta como terminado.**

- As três perguntas têm resposta, ou um horário de conversa está marcado para 12/09.
- **Ponto a olhar antes do encontro, não depois**: leftove.rs está sob licença CC BY-NC-SA, e a cláusula não comercial não é uma licença livre em sentido estrito.

**Dependências.** Em 12/09, no mesmo dia. Ligado a **D4** (material efêmero) e **H6** (alinhamento dos vocabulários).

*Remissões : `VEILLE_leftovers_maydayrooms_2026-08-19` · `CALENDRIER_bologne_2026-08-27`*

#### K7 — Conduzir a formação das duas coordenações BLMF até a autonomia

`P1` Prioritário · Estado : **Em curso** · Carga : várias semanas · O que exige : deliberação coletiva

**Estado.** O material está entregue: 89 slides em português do Brasil, seis módulos, três encontros, seis exercícios práticos, notas de animação em cada slide. Nenhuma das duas pessoas é bibliotecária ou informática.

*Constato de 29/08, não reverificado desde então.*

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

**Estado.** `ORIENTATION_outils_bibliotheques_militantes_2026-08-26` é um **esqueleto destinado a ser cossinado**. Seis pontos estão explicitamente a verificar ou decidir, e a seção final — a que carrega o chamado — resta escrever.

*Constato de 29/08, não reverificado desde então.*

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
| A4 | Uma porta de entrada para quem quer ajudar sem programar | **Entregue em 29/08** — `AIDER.md` na raiz, em francês, português e inglês: sete entradas, cada uma com seu identificador de backlog, o que exige, o que traz e **o número do dia**. É o que a página `/colaborar` do site não faz, e com razão: ela é genérica e intemporal. Dois erros de `CONTRIBUTING.md` corrigidos de passagem — remetia a `specs/REGISTRE_decisions.md`, caminho inexistente (o arquivo está em `docs/specs/`), duas vezes, em francês e em inglês; e ainda anunciava o Woodpecker. |
| B3 | As sete views `api` que continuavam fora das policies | Encerrado em 29/08 (migração `20260830160000`), **e corrigido em 30/08** (`20260830180000`). As quatro views gazeta/carta passaram a `security_invoker` já no primeiro dia. As duas views de governança tinham sido mantidas fora das policies com a cláusula de visibilidade recopiada na view: motivo exato — em invoker, o join em `profiles` devolve NULL a quem administra e precisa decidir — mas era o **sintoma de uma policy ausente**, não uma razão para contornar. O advisor do Supabase assinalava-o em `ERROR`, com razão. No dia seguinte, duas policies estreitas substituíram a derrogação: `profiles_select_gouvernance_en_cours` (as pessoas envolvidas numa deliberação **em curso**, admins de rede e pessoa visada) e `rls_crv_select` alargada à pessoa visada — que, sem ela, teria lido **«0 votos» em vez da contagem real**, um número falso e silencioso. Estado verificado em base: **uma única** view fora das policies (`library_email_identity`, concedida a nenhum papel aplicativo). Suíte `vues_api_definer_tests.sql`, 7 testes. |
| J5 | As incoerências do corpus documental | Encerrado em 29/08. `PRIV` deixa a §17 que dividia com `IMP` e passa a §42 sem renumerar o normativo já inscrito (`#HYG-REG-1`); a §2 `MAP` traz sua remissão à §34; as sete specs órfãs estão referenciadas em `docs/specs/INDEX.md`; Woodpecker corrigido para Forgejo Actions; os números de `docs/INDEX.md` repostos no real (970 linhas, 44 seções, 42 specs, 10 locales). E os dois identificadores citados desde junho sem nunca constarem da tabela das doutrinas — `DOC-COLLECTIVE-1`, `USER-EMAIL-1` — estão nela inscritos, o segundo após verificação do trigger em base. REGISTRO em v0.5. |
| I7 | As seis suítes SQL esquecidas da integração contínua | Encerrado em 29/08 à noite. As seis suítes estão no manifesto — 45 ao todo — e **o arnês passa em verde de ponta a ponta**. Produziram primeiro 35 falhas por **quatro causas, das quais só uma dizia respeito ao produto**. (1) O stub de autenticação convertia `current_setting('request.jwt.claims')` em `jsonb` antes de neutralizar a cadeia vazia, de modo que `''::jsonb` levantava erro onde a função real do Supabase devolve NULL: **nenhuma suíte do corpus testava a recusa de uma chamada anônima**, provavam uma pane do banco de ensaio. (2) O seed não tinha nem leitor nem exemplar. (3) Quatro testes estavam errados contra um produto que estava certo, e sua correção tornou-os **mais** exigentes — a partilha `anon`/`authenticated` é agora guardada nos dois sentidos, e a recusa de `administrador` é testada por si mesma. (4) `paquetA` e `paquetA1` terminavam com um `SELECT` de uma cadeia **constante** anunciando «15/15 testes passam», impressa mesmo após uma falha; `paquet19`, `paquet25` e `paquet26` passavam e eram contadas vermelhas por falta de um balanço na forma que a CI lê — uma delas por dois espaços em torno de uma barra. A sorte dos onze SKIP restantes passa a **I15**, onde cabe à reescrita. |
| I14 | Os identificadores de produção nas fixtures de teste | Encerrado em 29/08 durante a noite, no mesmo dia da constatação. Sexta regra bloqueante do hook `pre-commit`: em `tests/sql/`, todo UUID de aparência real ausente do seed é recusado. A lista branca é **lida** em `supabase/seed.sql` em vez de recopiada — acrescentar um ator é acrescentá-lo ao seed; os valores visivelmente sintéticos permanecem tolerados para que cada suíte forje suas fixtures na sua transação. Doutrina `DOC-FIXT-1` no REGISTRO (v0.6). Ao instalar-se, a regra fez sair `cleanup-frt-2026-05-15.sql` de `tests/sql/`: script de limpeza pontual que nomeava legitimamente uma biblioteca real — um script de manutenção deve nomear o real, era o seu lugar entre fixtures que estava errado. Vai para arquivo, verificado que a biblioteca já não existe. **Limite assumido**: o seed contém o identificador real da BLMF, de que depende a suíte de mensalidades; a regra tolera-o porque está no seed, não porque fosse sintético. |
| I15 | As três suítes de circulação anteriores à CI, e os dois caminhos E2E | **Saldado em 30/08.** Doze ramos `jwt sim` retirados; os denominadores de `paquet25`, `paquet_emprestimos` e `paquet_reservas` incluem agora os skips — sem o que uma regressão do stub de autenticação teria feito uma suíte passar de `32/32` a `20/20` continuando verde; seis guardas que procuravam um texto de HINT em `SQLERRM` (que carrega a MENSAGEM) substituídas pelo código levantado; três testes que contavam sucesso em todos os seus ramos reescritos; duas etiquetas que nomeavam pessoas renomeadas. Os **dois caminhos E2E estão escritos** — empréstimos e reservas — e o seed traz o conjunto de regras de circulação sem o qual renovar era impossível. Nenhum SKIP nas cinco suítes. **O que o dia ensinou, três vezes: o produto tinha razão e o teste lia o campo errado.** A questão de produto que daí sai — uma recusa que não levanta — tornou-se o item **B15**. |
| F5 | O prazo de negociação de 21 dias das reservas | **Verificado e encerrado em 30/08.** O mecanismo está implementado, e melhor do que dizia a spec: `fn_expire_negotiation_timeout()` **lê o prazo por biblioteca** em vez de fixá-lo, a coluna traz exatamente o `DEFAULT 21` e o `CHECK BETWEEN 7 AND 60` do §5, e as três bibliotecas estão em 21 dias. O cron roda de hora em hora. O cabeçalho da spec, que ainda dizia «a validar antes da implementação», foi corrigido no mesmo dia, distinguindo o que está **construído** do que falta **votar**. |
| I9 | As migrações datadas no futuro | **Encerrado em 30/08 por uma regra, não por uma correção.** O item apontava três migrações datadas com antecedência. Verificação em 30/08: já não estão — **mas porque a hora as alcançou**, não porque foram corrigidas. Um item que se resolve pela passagem do tempo não se resolve, adia-se: na mesma noite apareciam duas novas, datadas de 20:30 e 21:00 UTC quando eram 19:15. **Oitava regra do hook `pre-commit`**: uma migração adicionada cujo carimbo ultrapassa a hora UTC real (tolerância de 60 s) é recusada. Completa `DOC-DEPLOY-4`. |
| B8 | As views «em duplicado» entre `public` e `api` | **Verificado e encerrado em 30/08 — o item errava o diagnóstico.** `my_access` e `my_session_context` não existem em duplicado: as versões de `public` são **projeções** das de `api` (300 caracteres contra 2 100). Um só foco, uma fachada por cima: está bem construído.

Mas a verificação encontrou outra coisa. **A fachada enumera as suas colunas**: acrescentar uma coluna a `api.my_access` não a faz aparecer em `public.my_access`. E **31 funções declaram `v_actor public.my_access%rowtype`** — a forma da fachada tornou-se um *tipo*. Uma divergência não levantaria nada: as 31 compilariam e nunca veriam a coluna nova. Uma divergência por **omissão**, a única que não faz barulho.

Em 30/08 os dois pares concordam (20/20 e 13/13 colunas). Guardado pelo **T8** de `vues_api_definer_tests.sql`. |
| B6 | `config.toml` e as 48 funções implantadas | **Reconciliado e encerrado em 30/08 — o ficheiro estava certo desde o início.** O item anunciava que «18 das 48 funções implantadas não estão declaradas». Comparação feita contra `supabase functions list`: **31 declaradas, todas a `false`, e todas a `false` em produção; 17 não declaradas, todas a `true` em produção. Nenhum desacordo.**

A conclusão do item assentava num contrassenso: **não declarar uma função não é um esquecimento, é a forma de lhe deixar o padrão da plataforma** — e esse padrão é o ajuste *mais fechado*. A doutrina escrita no topo do ficheiro já dizia exatamente isso.

O que estava errado eram os **números do comentário**, datados de 07/05, e os de `CLAUDE.md`. Três documentos contradiziam-se a respeito de um ficheiro que tinha razão. O comentário foi refeito, datado, e diz agora onde está a fonte de verdade: a lista das secções `[functions.*]`, não a prosa que a comenta. |
| J3 | As afirmações falsas da spec das consultas | **Corrigido e encerrado em 30/08 — e o constato ficava aquém da verdade.** O item apontava três afirmações falsas. Levantamento em `public.libraries` a 30/08: as **cinco** bibliotecas estão **todas** em `circulation_mode = full_sigb`. A spec não errava em três linhas: ilustrava uma **diversidade de perfis que não existe**.

O que daí decorre vale mais que a correção. A doutrina continua justa, mas os comportamentos adaptativos `informal` e `off` **nunca foram experimentados numa biblioteca real**, ao contrário do que «validados no pacote E.0-E.5» deixava entender. A linha di-lo agora, com a data do levantamento. |
| J1 | Os números de `CLAUDE.md` e do `README.md` | **Encerrado em 30/08, e pelo segundo ramo da alternativa que o próprio item colocava** — «talvez uma remissão para o backlog valha mais que uma cópia».

De manhã, a secção de estado do `README` foi recontada no banco e o seu título neutralizado. **À noite do mesmo dia, a recontagem da manhã já estava errada**: «224 migrações» quando o banco tinha **231**. Sete migrações em doze horas, e nada num `README` assinala que um número envelheceu.

Feita a demonstração num só dia, os números cedem lugar a uma **remissão para `docs/backlogs/`**, que traz uma foto datada. **Uma remissão não caduca; uma cópia, sim.**

`CLAUDE.md` recebeu as mesmas correções, mas está gitignorado desde 23/07: **nada do que aí se escreve chega a quem contribui**. É mais um argumento para que o estado numérico viva no repositório, e num único lugar. |
| J4 | A secção 14 da spec de governança dos papéis | **Encerrado em 30/08 — o trabalho fora feito em 26/08, apenas o ponteiro não o seguira.** A spec traz **v1.4.1 (26/08/2026)**, o seu §14 está refeito sobre estado constatado, e vai além do que o item pedia: distingue **«entregue» de «experimentado»** — o circuito de convite estava entregue havia dois meses e nunca servira, zero linhas em 26/08. O §14.2 nomeia mesmo as duas afirmações que **não** verificou.

O que continuava errado era o **índice das specs**, que anunciava v1.3 (24/05). Corrigido. Um segundo desvio foi encontrado: `spec-migration-mail-resend`, índice v0.4 contra v0.6 no ficheiro arquivado.

Controlo mecânico sobre os **48 links** do índice: **nenhum link morto**. Quarta vez no dia em que um item do backlog descrevia o ponteiro e não o objeto. |
| B16 | O slug de uma biblioteca perdia as maiúsculas e os acentos | **Corrigido e encerrado em 30/08, no próprio dia da abertura — e o constato ficava aquém da verdade.** O item dizia «perde as maiúsculas» citando a primeira letra. Medido em base: caíam **todas** as maiúsculas, sendo `lower()` aplicado depois do filtro `[^a-z0-9]`. «Biblioteca Terra Livre» não dava `iblioteca-terra-livre` mas **`iblioteca-erra-ivre`**. Os acentos caíam no mesmo filtro, sendo o `translate()` destinado a dobrá-los um no-op: «Associação Cultural Ñandú» dava `associa-o-cultural-and`.

O cálculo sai do corpo de `fn_provision_preactive_library` para se tornar `fn_library_slug_from_name`, nomeada e testável sozinha: minúsculas primeiro, acentos dobrados por `extensions.unaccent` (a extensão já estava instalada), todo o resto em traços. Verificado provisionando realmente uma biblioteca de teste em transação anulada — «Associação Cultural Ñandú» sai em `associacao-cultural-nandu`.

**Os slugs existentes não são renomeados**, e isso está escrito na migração: um slug vive nos URL públicos, em `library_commons.library_slug` e no caminho de armazenamento `themes/<slug>/logo.png`. Renomeá-los quebraria os três de uma vez, incluindo a exibição dos logótipos. A correção vale apenas para as bibliotecas por vir.

Suíte `tests/sql/slug_biblioteca_tests.sql`, 7 testes. O T5 é o que conta a longo prazo: recusa que se reinsira o cálculo no corpo da função de provisionamento, o que reintroduziria o defeito sem que nenhuma luz acendesse. |
| I5 | Um alerta de CI que se repete a cada iteração já não alerta | **Encerrado em 31/08 — e é o primeiro item da série fechado porque o problema foi resolvido, e não porque o constato era falso.** O constato também o era: dizia que um vermelho de CI passava despercebido. A forja continha 24 tickets `[CI rouge]`, dez só no dia 30/08, e os e-mails tinham partido. O alerta não faltava — **transbordava**.

**A causa não estava no código mas no uso que ele impunha.** O anti-duplicado de `OPS-6` só joga enquanto o ticket fica *aberto*; ora a convenção escrita dizia «fechar vale acusação de recepção», e numa noite de afinação fechar quer dizer «eu vi». Cada clique rearmava o alarme para a iteração seguinte: dez tickets e dez e-mails **para um só e mesmo vermelho**.

**A prova encontrou dois defeitos que a releitura não vira.** O terceiro vermelho de uma hora não abriu ticket nenhum: **HTTP 429**, *« posted 2 similairy named issues in the last hour: rate limited »*. O Codeberg limita a dois tickets de título semelhante por hora. E o job mostrava **`Job succeeded`**: um `continue-on-error` e um `|| echo 000` faziam com que o alerta se calasse sobre a sua própria avaria — `DOC-SILENCE-1` violado dentro do próprio dispositivo de alerta.

**Entregue**: um job `acquittement` simétrico de `alerte` nos dois workflows, e `alerte` refundido em torno de outro modelo — **um só ticket por workflow, para sempre**. Aberto no primeiro vermelho, **reaberto** nos seguintes com o commit e o run em comentário, fechado no retorno ao verde. O seu estado é o espelho vivo da saúde da CI, os seus comentários o diário. `continue-on-error` retirado de `alerte`, conservado em `acquittement`.

**Provado de ponta a ponta, cinco estados, cinco observações**, com uma suíte descartável escrita para falhar e retirada no mesmo dia: vermelho → ticket aberto; verde → fechado uma segunda depois do seu comentário; vermelho → *reaberto* (HTTP 201/201); vermelho de novo com o ticket já aberto → **nada**, e o job di-lo; verde → fechado. A condição em parênteses rectos `needs['sql-tests'].result`, nunca exercitada até então, funcionou.

Doutrina `OPS-8`: **a acusação de recepção de um alerta é o estado do sistema, não um gesto humano repetido.** |
| B12 | Um envio não efetuado não dizia porquê — e num caso, a tabela afirmava o contrário | **Encerrado em 31/08.** O constato não era falso, era pequeno demais.

**As quatro linhas são um só evento**: `network.cross_library_critical_action`, e são as únicas desse evento — nunca partiu desde 8 de junho. A causa é um handler ausente em `_shared/domain/network.ts`, que devolve **`ok: true`**. Tornou-se o item **B17**, em P1: a spec §6.3 prometia «e-mail imediato aos coordenadores ativos da biblioteca», o contrapeso ao único poder transversal da rede.

**O silêncio não estava confinado a esse evento**: cinco das sete tabelas de outbox perdiam a razão do salto, que o código nomeia antes de a deitar fora. E `authority.ts` marcava **`sent`** aconteça o que acontecer — não ignorava que um envio faltara, **afirmava que ocorrera**.

**Entregue**: coluna `skip_reason` nas cinco tabelas, dois `CHECK` por tabela, `skipped` no enum de `authority`, os sete sítios do código corrigidos, as quatro linhas retomadas. Suíte `outbox_raison_du_saut_tests.sql`, 8 testes, quatro dos quais **escrevem**.

**Verificado em produção**: 5 colunas, 10 guardas, 4 linhas retomadas, 0 linhas mudas.

**E a falha pelo caminho valeu uma doutrina.** A primeira versão punha as guardas *antes* da retoma: verde em CI, recusada pela produção. A CI não podia vê-lo, reconstrói uma base vazia. Daí `DOC-MIGR-1`. |
| B15 | Uma recusa que parecia um sucesso: 26 chamadas em 34 não liam o `ok` | **Encerrado em 31/08 — e o recenseamento inverteu o item.** `api.renew_my_loan`, citada como o caso culpado que deu origem a B15, é das poucas **conformes**.

**O levantamento.** 34 RPC chamadas pelo front devolvem `{ok, reason, …}` em vez de levantar. **26 chamadas não inspecionavam `ok`**, e dezoito escreviam `const { error } = await supabase.rpc(...)`: a carga útil deitada fora na desestruturação, o `ok` **inatingível**. `BookPage` mostrava «consulta pedida» num `ok:false`.

**A doutrina** (`DOC-RPC-4`): o contrato de estado é **mantido** — permite o tratamento linha a linha dos lotes — e ler o `ok` passa a ser obrigatório.

**E não custou uma única cadeia i18n**: `assertRpcOk(data)` levanta um `Error` com o `reason`, entrando no caminho de erro já existente; `localizeError` não tem lista branca.

**23 guardas postas, 4 sítios deixados e nomeados.** `src/tests/rpc-statut-ok-lu.test.js` falha se uma chamada ignorar o estado, e um segundo teste recusa uma entrada de dívida sem objeto — a lista só pode encolher.

CI verde. |
| K4 | Corrigir o gerador das páginas de privacidade sobre a língua declarada | **Encerrado em 31/08 à noite.** O gerador emitia `lang="pt"` onde todo o texto é em português do Brasil; as páginas à mão traziam `pt-BR` e tinham razão. O modelo do corretivo dormia na linha ao lado (`HTML_LANG` de `build-finances-pages.cjs`). Dez páginas regeradas, cabeçalhos ressincronizados de passagem. **Verificado online**: `anarbib.org/pt/privacidade` serve `lang="pt-BR"`. Commit `2fb4796` do repositório vitrine. |
| H3 | Publicar as correspondências para o tesauro FICEDL em SKOS | **Encerrado em 31/08 à noite — e o constato estava meio errado.** As correspondências já eram exportadas em SKOS (`exactMatch`/`closeMatch` desde 30/06); o que faltava era o **endereço** — só existia um botão de download. Entregue: `build-thesaurus-skos.mjs` no padrão do snapshot do catálogo, mesmo serializador que o botão. **Verificado online**: `app.anarbib.org/thesaurus.ttl` responde 200 em `text/turtle`, 51 alinhamentos, `exactMatch` distinto de `closeMatch`, nada sobre a hierarquia FICEDL. Os 47 vínculos restantes esperam a promoção dos 35 assuntos `proposto`. Commit `472db13b`. |
| F2 | Corrigir o template dos e-mails de alerta de operação | **Encerrado em 31/08 à noite, entregue e provado em condições reais na mesma noite.** Os alertas de operação partiam com o rodapé de leitora — « entre em contato com a biblioteca » e o telefone: dizia-se à pessoa operadora para telefonar a si mesma. Entregue: `footerOps` (origem do alerta, onde olhar, OPS-8 — nada a confirmar, o incidente fecha sozinho), dez locales, ligado no funil único dos oito envios. **A armadilha pega no caminho**: a versão texto de `renderEmail` fabricava seu próprio rodapé sem olhar o `footerHtml` — coberta por `footerTextLines`, guardada por teste. **Provado num alerta real**: incidente de ensaio `#9` aberto à mão às 18h40 UTC, fechado pela própria sonda às 18h45 — quatro minutos, zero confirmação — e os dois e-mails **recebidos e relidos por Xavier**, que não escreveu o código. Commits `4b1d8a86` e `12d4b760`. |
| B2 | Triar as 36 funções `SECURITY DEFINER` abertas a `anon` | **Encerrado em 01/09, os quatro lotes executados e a conta mantida.** Lote 1: os três grants que a própria função contradizia, retirados. Lote 2: as cinco intocáveis comentadas e guardadas por T8/T9. Lote 4: as 33 relidas uma a uma (`AUDIT_execute_anon_2026-08-30.md`) — C.1–C.4 fechadas na mesma noite, C.5 decidida em 01/09 pelos fatos (o único chamador é a escolha de biblioteca alvo da catalogação, admin de rede por decisão de 17/08 — guarda desejada, nome documentado, grant morto retirado). Lote 3: o padrão do esquema revertido — uma função criada em `public` nasce fechada a `anon`; doutrina no REGISTRO (`DOC-GRANT-1`). **O invariante está guardado**: a lista nomeada do T10 conta 28 funções, e **o lint 0028 mostra exatamente 28**. Um aviso esperado não é mais um aviso. A triagem das 464 de `authenticated` é B14. |
| B5 | Resolver as nove policies que reavaliam `auth.*()` por linha | **Encerrado em 01/09/2026, por medição e não por intenção.** O item pedia para resolver as nove policies que reavaliavam `auth.*()` **por linha** em vez de uma vez por consulta. O wrap idempotente de 03/07 já existia: fora escrito, e depois o desvio voltou pelo exemplo cru do `_TEMPLATE.sql`, que as nove haviam copiado. A reaplicação de 31/08 (`20260831171526`) fecha as nove **e** corrige a fonte — sem isso, a décima nasceria do mesmo modelo. <br><br>**O que autoriza o encerramento é um número, não um commit**: o advisor de desempenho contava 9 `auth_rls_initplan` em 29/08; conta **0** em 01/09, remedido duas vezes no dia, antes e depois dos pacotes do `B14`. É a única prova que vale aqui — uma migração aplicada não diz que o defeito sumiu, diz que se agiu. |
| B14 | Auditar as funções `SECURITY DEFINER` abertas a `authenticated` | **Encerrado em 01/09/2026, em onze pacotes e um dia, pelo fechamento de dois caminhos do `DOC-RECENS-1`**: dez critérios temáticos (`api` 138/138, `public` 315/315), o complemento dos critérios **vazio** após a leitura das 24 funções que ele devolvia, e os esquemas fora da hipótese varridos — `private` (6 lidas, e o último constato do lote vivia ali: o mapa da rede mostrava 79 entradas não públicas, entre elas possíveis esperas de consentimento, a qualquer conta autenticada) e `ingest` (0 exposta). **459 funções lidas ao todo.** Vazamentos corrigidos, todos dormentes: dois em `api`, o foco atrás da fachada, a volumetria dos acervos (`fn_next_tombo`), uma escrita sem guarda, a view `my_access` (37 funções abriam o painel da biblioteca errada), 23 oráculos de existência, 5 funções mortas — uma delas juntava identidade e papel militante —, o mapa da rede. **Três decisões coletivas** postas e decididas no mesmo dia (recusas mudas, arbítrio dos periódicos — após aviso prévio às quatro pessoas —, mapa da rede para membros). **Nove suítes de guarda** nascidas do lote, todas na CI: o lote não corrigiu, tornou cada invariante observável. Custo assumido: quatro CIs vermelhas, todas a mesma falta em três formas — mudar o que uma função diz, devolve ou tem direito de fazer sem procurar quem a observa — daí os três volets do `DOC-MSG-1` e dois corolários do `DOC-RECENS-1`. O advisor 0029 cai de 464 para 453, **e esse número já não é um aviso: cada uma das 453 restantes foi lida, e sua razão de estar exposta está escrita.** A crônica completa, pacote por pacote, vive em `AUDIT_execute_authenticated_2026-09-01.md`. |
| H4 | Expor o catálogo em OPDS | **Encerrado em 01/09/2026, onze dias antes de Bolonha, com prova real.** O fluxo OPDS 1.2 está vivo: `/functions/v1/opds` (navegação) e `/opds/all` (aquisição) — os **18 documentos digitais públicos** do catálogo, legíveis por qualquer aplicativo de leitura sem passar pela nossa interface. A convenção nº 1 do texto de interoperabilidade (« os fluxos OPDS existem de ambos os lados mas não apontam para lugar nenhum ») está **cumprida antes de ser proposta**. Provado no `curl`: Atom conforme, 18 entradas com títulos todos distintos (os seis tomos de Reclus se distinguem por volume e subtítulo), línguas normalizadas (7 fr, 7 pt-BR, 2 es, 2 it — `language_code` havia derivado, `idioma` faz fé), direitos e atribuição Gallica/BnF presentes, capas ligadas, link de volta para `/livro/<bib_ref>`, e um PDF realmente servido (10,4 MB, apóstrofos e espaços dos caminhos URL-codificados). Autodescoberta posta no `index.html`. **O perímetro é estrito e guardado**: apenas `access_scope='publico'` ativo — o mesmo predicado de `documents_numeriques_tests`; o fluxo não cria acesso algum, torna encontrável o que já é público. **Dois constatos de passagem**: `book_digital_resources` não porta **nenhuma chave estrangeira** — nem para `books` — daí uma junção em duas consultas na função (o embed do PostgREST exige uma FK); a colocar um dia, não na véspera de Bolonha. E o primeiro deploy respondeu 500 no `/all`: *a prova no `curl` faz parte da entrega*, não da verificação de depois. |
| G3 | Testar o circuito de promoção colegiada em `blmf-teste` | **Encerrado em 01/09/2026 à noite: o circuito foi percorrido passo a passo em `blmf-teste`, e validou de quebra a funcionalidade entregue horas antes.** Sete passos, o negativo primeiro: (0) o salto colegiado reader → coordenador(a/e) é **recusado** enquanto `allow_direct_coordenador` está desligado — mensagem histórica conservada; (1) opt-in ligado só na biblioteca de ensaio; (2) proposta de Voltairine (reader) à coordenação por um coordenador — e o mecanismo se revela: **a assinatura de quem propõe conta como a primeira das duas** (« cosignature » ao pé da letra); (3) Voltairine não pode ratificar a própria promoção (recusa); (4) segunda assinatura → `ready`; (5) aceitação pela interessada, sob o próprio JWT, com reverificação do opt-in; (6) estado final conforme: `coordenador:active`, a linha `reader` **fechada** (papel exclusivo), auditoria `promoted_to_coordenador [from reader]` + `removal_completed` — o `from_role` que GOUV-11/12 prometia. Os três eventos de outbox partiram para a função de envio. **Uma ressalva, dita**: o não-envio efetivo (e-mails `disabled` na biblioteca de ensaio) não pôde ser observado na mesma noite — a API de logs Edge respondia em erro — mas a caixa destinatária é uma caixa de teste real conferível num relance, e a prova do **conteúdo** dos e-mails de equipe é justamente o objeto de `G4`, que segue aberto. O ajuste `team_admission_mode='cosignature'` da BLMF, nunca exercido até aqui, tem agora um circuito provado de ponta a ponta; o convite real da BTL (`ebd78fb9`) está em `ready` e só espera o gesto da pessoa envolvida. O opt-in fica ligado apenas em `blmf-teste` — é a caixa de areia, e `G4` vai usá-la. |
| G4 | Exercer os quatro e-mails de equipe jamais enviados | **Encerrado em 01/09/2026 à noite, com envio real E leitura pela coordenação (« nada a apontar »).** Os quatro e-mails mais delicados do sistema — nunca enviados em produção — partiram e foram lidos, mais dois bônus também inéditos (`removal_cancelled`, `unsuspended`): cinco em pt-BR na caixa da persona visada, a difusão `self_demoted` em francês na outra coordenação, as cópias admin na locale da biblioteca num alias controlado. **O protocolo de contenção segurou duas vezes**: quatro dos seis membros da coordenação de ensaio são pessoas reais — sala esvaziada por rebaixamento direto silencioso antes de cada difusão, tudo restaurado ao idêntico depois. **O primeiro disparo acertou ao falhar**: nenhum e-mail recebido, porque o canal porta DOIS interruptores na mesma linha (`delivery_mode` e `active`) e só um havia sido girado — mesma família do falso interruptor de 30/08: *dois interruptores para um só gesto acabam sempre girados pela metade*. O diagnóstico levou três consultas porque cada salto trazia sua razão (`skipped: delivery_disabled`) na resposta: **a doutrina B12 provada em situação real**. Na repetição, os dois sinais verificados na view que a função lê (`v_library_notification_context`) ANTES de disparar. **O ângulo morto das dez línguas foi fechado em seguida**: os gabaritos vivem em `mail-strings.ts`, fora do perímetro da guarda de paridade do front — medidas 648 chaves todas completas nas dez locales, e guardadas agora por `src/tests/mail-strings-parity.test.js` (cuja primeira execução apanhou um falso positivo exemplar: o cabeçalho do arquivo que enuncia « JAMAIS camerata »). Nuance registrada de passagem: `self_demote` põe o papel deixado em `inactive` onde a promoção o havia `removed`. |
| F8 | O domínio de envio, verificado: em regra para enviar, seus relatórios vão para a Brevo | **Encerrado em 01/09/2026, com dois levantamentos DNS emoldurando os gestos — nove dias antes do prazo de 10/09.** O levantamento da manhã (nunca feito antes) confirmou o item palavra por palavra: **em regra para enviar** — SPF no subdomínio Resend (`send.notifications`: `v=spf1 include:amazonses.com` + MX feedback SES), DKIM presente (seletor `resend`) — mas DMARC em `p=none` com `rua` na **Brevo**, o provedor abandonado, no subdomínio E na raiz: os relatórios de autenticação partiam para outra parte, e um canal de relatórios que aponta para um provedor abandonado é um dispositivo de vigilância que se cala (`DOC-SILENCE-1`). Mais dois TXT `brevo-code` residuais, fichas de verificação que diziam publicamente « este domínio esteve na Brevo ». **Os gestos, feitos pela coordenação na OVH no mesmo dia, verificados no levantamento da noite via resolvedor externo**: os dois `_dmarc` apontam para `admins@anarbib.org` (já destinatária dos alertas de saúde), os dois `brevo-code` desapareceram, e nada mais se moveu — o SPF OVH da raiz (as caixas `admins@` dependem dele) e toda a zona Resend estão intactos. **A política DMARC está decidida, não adiada**: `p=none` mantido enquanto se leem os primeiros relatórios — que agora chegam a nós, diariamente, em pequenos XML zipados — e o endurecimento (`quarantine`) será decidido sobre o conteúdo deles, em algumas semanas. O critério está escrito; não há mais decisão pendente, apenas um encontro marcado. |
| C1 | Fazer os 35 assuntos SOLIDAIRES entrarem nas migrações | **Encerrado em 01/09/2026, por decisão escrita em vez de migração** — era uma das duas saídas que o item previa, e a doutrina FICEDL de 26/08 a comandava: *o vocabulário federal embarca, os assuntos locais e seus alinhamentos não embarcam*. Estado medido no dia da decisão: **35 assuntos** `solidaires-*` no banco, todos `proposto`, **47 alinhamentos** FICEDL (de 98). O rascunho o dizia por si — « os rótulos são os do coletivo, não retraduzidos »: um vocabulário *situado*, que traduzir ou normalizar para embarcar trairia. Uma instalação nova nasce com o tesauro; cada biblioteca traz suas palavras, e os alinhamentos fazem a ponte. O rascunho SQL foi guardado em arquivo (`docs/drafts/archive/`), a decisão está datada (`DECISION_sujets_solidaires_2026-09-01.md`) com sua cláusula de revisão: se outras bibliotecas um dia adotarem essas rubricas tal e qual, é o critério « federal » que comanda, não o prefixo — e a migração se reescreverá a partir do banco, não do rascunho. |
| D1 | Revisar a spec dos periódicos contra o que foi entregue | **Encerrado em 01/09/2026 — e o primeiro constato é que a spec a revisar não existe.** `spec-periodiques-v0.1`, citada por este item com seus números de seção (§11, §14), está **em parte alguma** — nem no repositório, nem nos arquivos de trabalho: havia vivido em Downloads, colada em sessão em 27/08 (« On met ça en œuvre »), e o arquivo foi depois apagado — **reencontrada na mesma noite, íntegra (391 linhas), no transcript daquela sessão**, e arquivada: `docs/specs/archive-spec-periodiques-v0.1-retrouvee.md`. Os §11 e §14 citados existem, as seis guardas estão no §9. *A precisão de uma citação não é prova de existência* (`DOC-RECENS-1`). Em vez de revisar um fantasma, o estado entregue foi escrito a partir do código: `docs/specs/spec-periodiques-v1.0-etat-livre.md` — uma spec *a posteriori* que o assume, onde o código faz fé e o documento o segue. **As seis guardas anunciadas foram verificadas uma a uma**: o anticiclo limitado a 20 saltos relido na linha (`WHILE v_hops < 20`), a reciprocidade por trigger, a proibição do `serial_id` fora de fascículo, a chave `issue_key` **gerada** que nenhum caminho de importação referencia, o estado declarado/calculado em colunas separadas, o índice de ordenação. E sobretudo: **as seis são exercidas continuamente** por `periodiques_tests.sql` (35/35 na CI, verde ainda esta noite) — a prova não é o documento, é a suíte, a cada commit. O documento novo porta também a mudança do dia (arbítrio alinhado aos livros) e os três gestos manuais restantes, que não são defeitos. |
| H7 | Decidir o destino do texto de convenções de interoperabilidade | **Encerrado em 01/09/2026, ao fim de uma noite de caça: decidido, perdido, reencontrado, preparado.** A coordenação decidiu « levar a Bolonha » — e o texto se revelou perdido: nunca no git, nunca como anexo de sessão (inventário integral, Windows e WSL), nunca escrito por ferramenta. A investigação estabeleceu que ele nunca passou pelas máquinas: escrito numa **conversa claude.ai de 26/08**, como o próprio v34 (o export PDF de 29/08 às 20:08 na pasta E: é a assinatura). **Reencontrado na mesma noite pela coordenação nessa conversa**, exportado, e versado ao repositório em dois exemplares com papéis claros: o original intacto, notas de trabalho incluídas (`docs/journal/cadrages/CONVENTIONS_interop_catalogues_libertaires_brouillon-original_2026-08-26.md`); e a **versão a levar** (`docs/CONVENTIONS_interoperabilite_catalogues_libertaires.md`), cujos dois únicos cortes são os que o próprio texto se ordenava — a seção « Notas de trabalho *(a retirar antes da difusão)* » e a nota entre colchetes sobre a auditoria a anexar. O chapéu « este texto não compromete ninguém » permanece: é sua política, não uma nota. **E ele chega a Bolonha com suas provas**: a convenção nº 1 (OPDS) é cumprida pelo AnarBib desde a manhã do mesmo dia, a nº 2 (SKOS) desde o H3 — o texto já não propõe, mostra. Mesma lição da spec dos periódicos, duas vezes na mesma noite: *o que serve de referência a um item deve ser versado em lugar durável, no dia em que serve.* |
| F8 (rappel avant péremption) | O lembrete antes da expiração: uma proposta de equipe não pode mais morrer em silêncio | **Encerrado em 02/09/2026, entregue na noite de 01 para 02.** O item dizia que o sino anunciava a existência de uma proposta sem nunca dizer que ela ia expirar, e que `fn_team_expire_invitations` fechava aos 30 dias sem uma palavra — um silêncio fazendo as vezes de recusa, quando **toda** nomeação à equipe passa por esse circuito desde `GOUV-11` e `GOUV-13`.

**O arbítrio descartou a transposição mecânica do precedente da rede.** `RES-Q3` coloca seus lembretes em D+14 e D+25 de uma janela de 60 dias, ou seja, na sua **primeira metade**: prazos feitos para manter o impulso de um voto por unanimidade. Transpostos proporcionalmente para 30 dias (D+7 e D+12), teriam deixado **dezoito dias de silêncio antes da expiração** — justamente o buraco a tapar. Retido em vez disso: **um lembrete em D+21**, nove dias restantes, e **um aviso na expiração**. Este último vale mais que um segundo lembrete: repetir apenas repete, ao passo que o aviso transforma um desaparecimento silencioso em fato registrado. Seu texto diz o que o silêncio significava — « não é uma recusa: ninguém decidiu; ela pode ser reapresentada ».

**Quem propôs é avisad(o/a/e) nos dois casos.** A objeção era que essa pessoa não pode desbloquear nada sozinha, logo culpa sem poder. É o contrário: devolve-lhe o único poder que conta aqui, ir falar com as pessoas (`DOC-COLLECTIVE-1`, `RES-D9`).

**Medidas datadas.** Migração `20260901213921`, com carimbo no segundo UTC real (`DOC-DEPLOY-4`). **Nenhuma coluna acrescentada**: como o cron passa uma vez por dia, o lembrete dispara na igualdade de data `created_at + 21 dias` = hoje — uma vez, uma só, sem marcador « já lembrado » que pudesse desandar. Cron `anarbib-team-invitations-remind` às **09h35 UTC**, verificado ativo em `cron.job` após o deploy. `fn_team_expire_invitations` passa de um `UPDATE` global a um laço — é preciso saber **quem** avisar. Os dois canais: in-app (`user_notifications`, a via que controlamos, todo o objeto de `GOUV-17`) e e-mail.

**O que foi verificado, e o que ainda não.** 64 suítes SQL verdes antes do push — entre elas `crons_planifies_tests.sql`, que **recusou a migração** enquanto o novo cron não estava ali declarado: a proteção fez o seu trabalho. Após o deploy, `fn_team_invitation_remind()` foi **realmente executada** contra o esquema de produção: retorno `0`, nenhuma notificação escrita — nenhum convite atingia D+21 naquele dia. Isso estabelece que o caminho executa, ainda não que ele lembra. **A primeira execução real está datada**: 20/09/2026 para o convite da BTL pendente desde 30/08, depois 22/09 para o de `blmf-teste`. É nessas datas que o item será posto à prova, e não antes.

**Continua em aberto, fora do escopo deste item**: nada. O lembrete antes da expiração era o único ponto deixado em suspenso por `GOUV-17`, e `GOUV-17b` pode passar de aberto a decidido. **Contraverificação independente (segunda sessão, noite de 01 para 02/09) — o código sustenta pelos dois caminhos.** Estrutural: migração `20260901213921` aplicada em produção, cron `anarbib-team-invitations-remind` posto às 09h35 (a expiração seguindo às 03h20), `EXECUTE` das duas funções reservado a `service_role`, as 4 chaves i18n presentes nas dez locales, as 49 linhas novas de `mail-strings` validadas pela guarda de paridade nascida na véspera, o sino roteando os dois `link_type`. Comportamental, em transação revertida em `blmf-teste` com fixtures sintéticas em J-21 e J+31: o lembrete alcança **exatamente** os 5 da equipe fora a pessoa convidada (a convidada 0), quem propôs **uma única vez** — a guarda antiduplicata morde mesmo estando também na difusão —, 1 linha de outbox de e-mail; a expiração fecha (`expired`) e avisa as **duas** pessoas certas. O disparo por igualdade de data não deixa marcador a dessincronizar. **Sobre a fixture `f8504c47`, a objeção da sessão que entregou prevalece sobre minha instrução de cancelá-la**, com medidas: único convite vivo da persona (a restrição de unicidade nada mais bloqueia) e lembrete de 22/09 caindo depois da formação — conservada, ela vira a **segunda prova real datada**, depois da de 20/09 na BTL. Dois vereditos independentes, uma ressalva comum e escrita: a função ainda nada relançou de verdade, e é nessas duas datas que o item se provará. |
| B20 | 2026-09-02 | **A superfície morta medida pelo GLB v17 está inteiramente tratada — 2 ligadas, 65 fechadas, 1 rejulgada alhures — em um dia, cada gesto provado na CI e contraverificado em produção.** A mensageria de candidatura ligada (a seção de trocas que a spec v2.0 prometia), a retirada de ficha cartográfica ligada, as 15 outras fechadas por quatro migrações narradas. O prazo das 48 adiadas: **saldado com um mês de antecedência** — 47 fechadas sob remedição, `fn_book_due_dates` fora do saldo (veredito B2/T10). O lint 0029 passa de 442 a 395.

**O que o dia custou e ensinou**: três vermelhos na CI, todos do mesmo motivo, e três lições versadas nos arquivos. **Fica aberto, fora do perímetro**: a prova real da mensageria espera a primeira candidatura viva — SOLIDAIRES (`DOC-ACTIF-1`: ligado não é provado). |
| J7 | 2026-09-02 | **As linhas vermelhas dos Livros brancos têm agora seus códigos — REGISTRO v0.14.** Três inscrições: **`DOC-GEL-1`** (o congelamento v16, com sua janela de arbitragem), **`DOC-ACTIF-1`** (nenhuma camada ao ativo antes de um exercício real — a prática das encerramentos sob prova torna-se oponível), **`DOC-GLB-1`** (toda linha vermelha de um Livro branco recebe seu código em uma semana, senão é um voto). |
| J8 | 2026-09-02 | **Um só «v17», e é o certo — a série do Grande Livro branco está versada no depósito** (arbitragem de 02/09). O docx de maio arquivado sob nome datado, o **v17 de 01/09 entra em `docs/GLB/`** como referência viva, o INDEX não designa mais um estado de maio. Detalhe: o PDF já tinha saído de Downloads — **reconstituído ao byte (762 814) a partir do transcript da sessão que o leu**. **Fica aberto**: o v16 de 2 de julho segue por encontrar; quando ressurgir, entra em `GLB/archive/` sem outra decisão. |
| B21 | 2026-09-02 | **O contador das chaves estrangeiras sem índice tem sua guarda, e ela mordeu já na primeira volta de CI** (run verde de 02/09). 38 entradas assumidas em três famílias motivadas, cabeçalho com a consulta E seu ângulo morto (`DOC-RECENS-1`). Guardada nos dois sentidos: toda FK nova sem índice avermelha a CI no momento em que a migração se escreve; uma entrada indexada ou desaparecida avermelha também — a lista só encolhe conscientemente. T3 prova a mordida a cada execução. A doutrina v17 está servida: o canteiro não foi «saldado», foi **instrumentado** — e o contador não subirá mais em silêncio. |
| F7 | 2026-09-02 | **Treze segredos vazios, treze vereditos — e só restam dois, de propósito e documentados.** **11 suprimidos** — dez duplicatas de cadeias de fallback cuja variante `ANARBIB_*` preenchida já ganhava, mais `REGIMENTO_URL` por decisão: nenhum regimento de rede está publicado, o ramo morto foi **retirado do código** (três lugares, incluindo uma cadeia mal nomeada que buscava a URL do manual tentando primeiro a do regimento). **2 conservados e documentados**: `BLMF_/BTL_INTERNAL_REDIRECT_EMAIL`, cujo vazio É a configuração — comentário posto em `register/index.ts`, onde são lidos, para que ninguém os «conserte». |
| B18 | 2026-09-02 | **As chaves API legacy estão desativadas — e o sinal verde foi um número, como a ficha exigia.** O medidor refeito de manhã dava: zero `service_role` desde a virada de 01/09, e do lado `anon` **um único user-agent de navegador** (uma aba nunca recarregada) mais o Googlebot repetindo seu cache. Aba recarregada, toggle virado no dashboard (gesto reversível), contraprova nos logs: **zero JWT legacy e zero 401 em 857 requisições vivas**. O código seguiu na mesma hora: fallback retirado de `secret-key.ts` (uma chave morta não merece caminho de código — DOC-SILENCE-1), `.env.example` limpo, vestígio do vault suprimido. A virada `service_role` → `sb_secret` está encerrada de ponta a ponta. |
| G2 | 2026-09-02 | **A divergência P2/P8 está decidida — o texto se alinha ao código, e a forma da decisão importa tanto quanto o fundo.** Opção 1: a prática viva (o circuito colegial que a BTL exerce desde 01/09) vira a regra. Spec v1.11: P2 diz que **a própria execução é colegial**; P8 esclarece a fronteira — os quóruns do código não são votos, são **garantias de execução**: «modelar a deliberação, nunca; exigir várias mãos para executar, sempre». Nenhuma linha de código. **Decisão tomada sozinho, dizendo-o** — modo degradado assumido, datada, `GOUV-18` no REGISTRO, **janela de objeção na formação de 13/09**: o dia em que o coletivo existir, encontrará uma decisão contestável, não um fato consumado mudo. |
| H5 | 2026-09-02 | **A coleta OAI-PMH está provada nos dois sentidos, com dados reais dos dois lados — e dois circuitos cívicos exercidos pela primeira vez na mesma noite.** **Entrada**: primeira fonte real registrada (Persée, fascículos de sociologia, 2 lotes/ciclo); o disparo manual trouxe **40 fascículos reais**: run `ready_for_review`, trava em `paused`, **token de retomada conservado** — o cron de terça continuará onde a prova parou. **Saída**: o repositório respondia conforme mas vazio; **a BLMF abriu-se pelo circuito real** (pedido → decisão, notificação incluída) e um cliente terceiro colheu **200 registros em dois lotes**, retomada honrada, `GetRecord` exato. **Dois constatos para Bolonha**: os dois parceiros PMB não expõem `oai2.php` — do lado deles os fluxos nem existem (assunto para H6/K6); e `blmf-teste` falha a elegibilidade nas suas três travas — a receita de biblioteca mascarada resiste até ao OAI. **Nada sobrevive à prova, por decisão de Xavier na mesma noite**: os 40 registros Persée não pertenciam a nenhuma biblioteca real (run ligado à caixa de areia, por isso invisível num contexto de biblioteca comum); run, linhas e fonte purgados pelo caminho próprio — **nenhuma fonte OAI fica armada, o cron de terça nada colherá**. A abertura da BLMF é fechada pela mão de Xavier. A prova, essa, está adquirida. **Fica aberto**: um colhedor verdadeiramente terceiro — Bolonha pode fornecê-lo. |
| B17 | 2026-09-02 | **O aviso imediato das ações transversais está provado de ponta a ponta — inclusive, esta noite, sobre o tipo para o qual foi escrito.** O andar imediato provado em envio real em 31/08 só o fora sobre a promoção colegial — um tipo com três canais. Faltava vê-lo sobre um tipo **sem outro canal antes de segunda**. Feito em 02/09, em transação revertida em `blmf-teste` com uma atriz sintética (admin de rede fixture, não staff da biblioteca — o critério exclui com razão o admin que também é staff local): `fn_team_suspend_member` → membership `suspended`, **linha de outbox `network.cross_library_critical_action` com `action_type=team_suspend_member`**, linha de diário. A perna EF não precisa ser repetida: o handler é agnóstico ao tipo (o tipo só escolhe o rótulo, presente nas dez locales). Sanidade pós-rollback: tudo desaparecido, zero resíduo. |

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

Backlog v34, escrito em 2026-08-29, atualizado em 2026-09-01. Substitui `AnarBib-Backlog-2026-06-17-v33.md`. 72 itens em 11 domínios. O estado numérico foi levantado em 2026-09-02 contra o banco de produção em somente-leitura e contra o repositório Codeberg no commit `cb37a2a8`; os itens retocados desde então trazem a própria data no seu texto. Este documento não arbitra nada: o `REGISTRE_decisions.md` faz fé.
