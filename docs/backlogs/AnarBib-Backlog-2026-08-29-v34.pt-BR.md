# Backlog AnarBib v34 — Reescrita integral sobre estado verificado — ferramenta de trabalho para as colaboradoras e os colaboradores por vir

**2026-08-29** · atualizado em **2026-09-21** · 70 itens · Version française : `AnarBib-Backlog-2026-08-29-v34.md`

> Arquivo **gerado** por `scripts/build-backlog.cjs` a partir de `backlog-v34.json`. Não o modifique à mão.

---

## Sumário

- [Por que uma reescrita](#por-que-uma-reescrita)
- [Modo de usar](#modo-de-usar)
- [O estado real em 20 de setembro de 2026](#o-estado-real-em-20-de-setembro-de-2026)
- [Desvios levantados entre o real e o escrito](#desvios-levantados-entre-o-real-e-o-escrito)
- [O calendário restrito](#o-calendário-restrito)
- [Dez regras pagas por um incidente](#dez-regras-pagas-por-um-incidente)
- [Os canteiros](#os-canteiros)
    - [A — Sustentabilidade coletiva](#a--sustentabilidade-coletiva) · 2
    - [B — Banco de dados, segurança, RLS](#b--banco-de-dados-segurança-rls) · 4
    - [C — Catalogação e dados documentais](#c--catalogação-e-dados-documentais) · 8
    - [D — Periódicos, efêmeros, recursos digitais](#d--periódicos-efêmeros-recursos-digitais) · 4
    - [E — Front, OPAC, i18n, acessibilidade](#e--front-opac-i18n-acessibilidade) · 13
    - [F — E-mail e notificações](#f--e-mail-e-notificações) · 6
    - [G — Rede, governança, federação](#g--rede-governança-federação) · 7
    - [H — Interoperabilidade, tesauro, coleta](#h--interoperabilidade-tesauro-coleta) · 7
    - [I — Auto-hospedagem, operação, backups, CI](#i--auto-hospedagem-operação-backups-ci) · 9
    - [J — Documentação e corpus](#j--documentação-e-corpus) · 4
    - [K — Caixa, comunicação, formação](#k--caixa-comunicação-formação) · 6
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

## O estado real em 20 de setembro de 2026

Levantamento de **16 de setembro de 2026** à noite — produção consultada em leitura apenas e repositório recontado no commit `2e89c1de`. Dois dias densos desde o levantamento de 15/09 às 21 h (`60e0580a`): a sessão vizinha fundiu a **PR #28** (instalador do Bastien), entregou GAZ-7 a GAZ-11 (retomada de uma nota rejeitada, sonda das fontes, correção pelo staff, a gazeta chama-se **Fractale**), **E21** (numeração na tela, cotas de um lote), I19, I18 e, no instante do levantamento, **B22** (migração no repositório, em CI, ainda não em produção: 322 no repositório para 321 aplicadas); Xavier **revogou a HS256** (B19 fechado, nenhum 401 em 24 h) e **admitiu Solidaires** (G7 fechado: biblioteca ativa, 1 673 rascunhos com cota `SOL-`); esta sessão entregou **B25/B26** (os contadores de abuso contam, chaves com hash) e fez um inventário dos itens abertos contra os factos (A2, F9, I6 fechados; oito itens anotados). Todas as linhas foram remedidas, advisors incluídos.

**Frescor dos constatos em 2026-09-21.** **56 itens de 70** trazem uma verificação datada própria (A1, A3, B10, B13, B24, B27, C3, C4, C7, C8, C9, C10, C11, D3, D6, E1, E2, E4, E6, E9, E14, E15, E16, E17, E19, E20, F1, F3, F4, F6, F7, F10, G1, G6, G8, G10, G13, G14, H2, H9, H10, H11, H13, I2, I3, I15, I18, I21, I24, I25, J2, J4, J9, K2, K7, K10). Os **14** outros ainda repousam sobre o levantamento de 2026-08-29 e são assinalados como tais em cada ficha. Um constato não reverificado não é falso: é apenas velho, e a diferença vê-se aqui em vez de no uso. Esta linha é recalculada a cada geração do documento.

### Banco

| | | |
|---|---:|---|
| Tabelas `public` | **191** | todas com RLS ativado, **332 policies** — +4 tabelas desde 03/09 (`work_titles`, `work_not_same`, `volume_group_dismissals`, `catalog_batch_reviews`), todas classificadas no filete BG2. |
| Tabelas `ingest` | **10** | todas com RLS desde a noite de 29/08 (item **B1**, liquidado). O esquema nunca esteve exposto: nem `anon` nem `authenticated` tem `USAGE` nele |
| Views `api` | **68** | **67 SECURITY INVOKER, 1 DEFINER** — contra 65/3 em 29/08: duas views de governança voltaram a invoker. `CREATE OR REPLACE VIEW` reinicializa essa opção, e o T2 de `vues_api_definer_tests` a guarda |
| Funções aplicativas | **919** | `public` 687 · `api` 189 · `ingest` 34 · `private` 9. Das quais **706 SECURITY DEFINER** — inalterado desde 16/09: nem B22, nem os contadores de abuso, nem E17/E19 criam funções. O veredito que faltava, `api.fn_gazette_probe_sources`, **está escrito**: guarda `network_staff` ativo à cabeça, justificada. |
| Migrações aplicadas | **324** | **324 aplicadas em produção = 324 numeradas no repositório** (332 ficheiros com o modelo e os 7 rollbacks). As três desde 16/09: `20260916223000` **B22**, `20260916233000` (a sonda das fontes espera um minuto, GAZ-8) e `20260917165542` (o aviso de exportação RGPD sem endereço `.org`). Última aplicada: `20260917165542`; nada em fila. |
| Jobs `pg_cron` | **38** | ativos — +1 desde 03/09 (pré-tradução dos títulos de obra). |
| Avisos de segurança | **470** | 0 ERROR · **420** WARN nas DEFINER expostas a `authenticated` (0029) · **26** nas expostas a `anon` (0028) · 24 INFO « RLS sem policy ». **O 0028 passou de 28 a 26: B22 está aplicada.** Os 26 nomes do lint são **exatamente** a lista nomeada T10 de `grants_herites_tests.sql` (comparados um a um). Os 420 de 0029 estão todos justificados. Formato agrupado: contar `findings`. |
| Avisos de desempenho | **416** | **344 « índices não utilizados »** (345 em 16/09, 368 em 06/09 — os contadores partem do reinício de 02/09), 38 FK sem índice (todas assumidas, guardadas por B21), 25 tabelas com policies permissivas múltiplas, 8 sem chave primária, 1 aviso sobre as conexões `auth`. Nada de novo. |
| Esquemas de refugo | **1** | só `conv_backup` — não se purga. `backup_2026_05_07` saiu em 04/09 (B9). |

### Funções Edge

| | | |
|---|---:|---|
| Pastas no repositório | **53** | + `_shared` ; **+1 desde 03/09 : `work-titles-autofill`**. O roteador `main` nunca é implantado, de propósito. |
| Declarações `verify_jwt` | **38** | **todas a `false`** ; +1 desde 03/09. |

### Catálogo

| | | |
|---|---:|---|
| Fichas | **2 656** | 2 758 exemplares, **2 449 obras** (35 vazias suprimidas + fusões), **1 505 autoridades** (17 fusões C5), **3 497 títulos de obra** (pré-traduzidos, 1 452 a rever — C11). 0 proposta sobre obra ainda (G1). |
| Rascunhos de catalogação | **2 250** | `draft` 1 820, `published` 430 — inalterado em número, mas **os 1 673 rascunhos do lote Solidaires (63) têm agora uma proprietária, uma biblioteca ativa e uma cota** (`SOL-00001`…`SOL-01673`). Esperam as classes de arrumação (35 rubricas, Christian), a revisão do lote e `publish_catalog_batch(63)`. |
| Indexação de assunto | **1 184 / 2 656** | registos com pelo menos um assunto — **1 472 sem nenhum** (eram 1 537). Objeto de **C7**. |
| Tesauro FICEDL | **621** | termos — 159 datas desde 03/09 (H1). 98 alinhamentos intactos. |
| Periódicos | **4** | títulos, 7 fascículos vinculados. O **arbítrio de duplicatas** deles está aberto a qualquer `librarian` enquanto o dos livros é reservado à coordenação: desvio medido em 01/09, decidido, aguardando aviso prévio |

### Rede

| | | |
|---|---:|---|
| Bibliotecas | **5** | **todas ativas desde 15/09**: Solidaires (Paris, França) está **admitida** (decisão de Xavier em modo « só admin », `RES-D12` emendado, G7 fechado) — `is_active = true`, série de tombo `SOL-` + ano configurada na tela (E21), coordenação vinculada. Os seus 1 673 rascunhos têm cota `SOL-00001`…`SOL-01673`; falta as classes por rubricas, a revisão do lote e a publicação (C2, D3). |
| Contas | **20** | **24** filiações ativas (inalterado); **+1 conta em 16/09** (inscrição às 14h27 UTC, ainda sem filiação). 0 contribuidor(a) de rede, ainda. |
| Administrador(a/e)s da rede | **1** | **é o item A1, e ele comanda todo o resto** |
| Circulação viva | **6 / 19 / 22 / 0** | empréstimos / reservas / consultas / PEB abertos — inalterado. Dois PEB de maio, devolvidos, ficam como histórico. |

### Repositório

| | | |
|---|---:|---|
| Commits | **2 729** | 32 commits desde o levantamento de 16/09, em quatro dias. Cabeça no momento do levantamento: `6cf45ef4` (a sessão vizinha empurrou às 20h08, durante a medição: as duas linhas afetadas foram remedidas sobre o seu commit). |
| Arquivos `src/` | **332** | +9 desde 16/09: os bancos de teste de E17, E19, das origens CORS e do endereço do projeto, e os ficheiros da sonda e do instalador da sessão vizinha. |
| Chaves i18n | **6 690** | paridade estrita nas dez locales (6 690 cada, recontadas ficheiro a ficheiro). +8 desde 16/09: as duas chaves do bloco « Explorar » recolhido (E17) e seis da sessão vizinha. E19 não pediu nenhuma chave. |
| Testes | **556 + 104** | **556 testes JS** (vitest, gate bloqueante, 52 ficheiros — relançados por inteiro esta noite às 20h14, 43 s, todos verdes) + **104 suites SQL** em `ci-suites.txt`. +47 desde 16/09: E17 (5), E19 (5), as origens CORS (7), a guarda do endereço do projeto e os bancos da sessão vizinha. |
| Marcadores de dívida | **18** | dos quais 4 em `src/` — método fixo (`git grep -E 'TODO|FIXME'` fora de `docs/`): 18 em 20/09 como em 16 e 15/09. Nenhum é uma tarefa aberta. |

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

*191 tabelas, 694 funções SECURITY DEFINER, 332 policies (06/09). A maior superfície do projeto.*

| | | | |
|---|---|---|---|
| **B10** | Higiene de performance: 170 índices não usados, 38 chaves estrangeiras não indexadas, 24 policies permissivas duplicadas | `P3` | Aberto |
| **B13** | Decidir o destino das 221 migrações: squash ou não | `P3` | Aberto |
| **B24** | Uma rotação de chave toca dois repositórios — a vitrine quebrou seis dias depois de B18, e nada a impediria de acontecer de novo | `P2` | Aberto |
| **B27** | `api.catalog_works_v1` ultrapassa o prazo de 3 s do papel anónimo: o catálogo por obra falha em silêncio e a página recai na lista plana | `P1` | Em curso |

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

#### B24 — Uma rotação de chave toca dois repositórios — a vitrine quebrou seis dias depois de B18, e nada a impediria de acontecer de novo

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** B18 (02/09) desativou as chaves legacy com um sinal verde numérico que só olhava o aplicativo. Só que o site vitrine `anarbib.org` é um **segundo repositório** (`codeberg.org/anarbib/pages`) cuja galeria *Explorar* lê `api.public_libraries` em produção com uma chave embutida em `data-supabase-key` em **dez `index.html`** (um por locale): desde o toggle, a galeria devolveu 401 — **página vazia durante seis dias**, consertada na noite de 07 para 08/09 pela sessão do mapa base (vitrine `df9ba40`), não pela vigilância que deveria ter visto. Essa vigilância (tarefa diária `anarbib-trafic-cles-legacy`) contava 4 a 7 requisições legacy por dia de 04 a 07/09 e as lia como abas fósseis; o `referer`, pedido em 08/09 pela primeira vez, apontou a vitrine numa linha. O harnês de carga do aplicativo também carregava a chave legacy em claro (`scripts/loadtest/anarbib-loadtest.mjs`), retirada em 07/09 (`e2f5d75a`). **Verificado em 08/09**: `grep -r eyJhbGciOi` devolve zero nos dois repositórios, `/fr/explorar/` publicada serve `sb_publishable_…`, zero requisição legacy desde a correção. O que falta já não é o conserto, é o que impede a repetição: a vitrine não tem **nenhuma guarda**, e sua chave vive em dez cópias que um `sed` teve de tocar uma a uma.

*Verificado : 08/09 — logs edge 24 h: as 4 requisições legacy (todas 401) são a verificação pré-correção da sessão da vitrine, referer `anarbib.org` e `localhost:8765`, mesma rede; `curl anarbib.org/fr/explorar/` → `sb_publishable_…`; `grep eyJhbGciOi` = 0 em `anarbib` e `pages`.*

**O que é.** Dois gestos no repositório `pages`, uma noite. (1) **Uma única cópia da chave**: tirá-la dos dez `index.html` para um `js/config.js` (ou um único `data-*` na tag raiz lido por `explorar.js`), para que uma rotação seja um commit de uma linha. (2) **Uma guarda que recusa uma chave legacy**: teste ou hook `pre-commit` que fica vermelho com `eyJhbGciOi` em qualquer lugar do repositório, e que verifica que a chave embutida começa com `sb_publishable_`. E no aplicativo: a lista dos repositórios a inventariar a cada rotação escrita em `B19` (feito em 08/09) e em `CONTRIBUTING.md`.

**Por que importa.** B19 é o próximo gesto sobre as chaves: nesse dia uma página esquecida não devolverá mais 401, devolverá uma desconexão geral — reversível (a chave revogada volta para standby), mas geral. *(Corrigido em 15/09: esta frase dizia o gesto irreversível.)* E seis dias de galeria vazia são seis dias em que a vitrine dizia ao público «esta rede não tem nenhuma biblioteca» — indistinguível de uma pane, como diz `DOC-SILENCE-1`.

**O que conta como terminado.**

- A chave da vitrine vive num único lugar, e uma guarda fica vermelha com qualquer chave legacy ou com uma chave que não comece por `sb_publishable_`.
- `B19` e `CONTRIBUTING.md` nomeiam os repositórios a inventariar antes e depois de qualquer rotação.

**Dependências.** Não bloqueia mais **B19** (levantado em 15/09: o inventário está feito e verificado, e a revogação é reversível); os dois gestos protegem a rotação seguinte. Repositório `pages`: o congelamento acabou em 14/09.

*Remissões : `REGISTRE §38 OPS-9` · `item B18 (clôture nuancée)` · `item B19` · `vitrine df9ba40` · `app e2f5d75a`*

#### B27 — `api.catalog_works_v1` ultrapassa o prazo de 3 s do papel anónimo: o catálogo por obra falha em silêncio e a página recai na lista plana

`P1` Prioritário · Estado : **Em curso** · Carga : alguns dias · O que exige : SQL / PostgreSQL

**Estado.** **Constatado em 20/09/2026** ao verificar E17 na tela. A consola do catálogo tinha erros 500; os registos edge atribuem-nos todos a `POST /rest/v1/rpc/catalog_works_v1` — 13 em 12 minutos — e `postgres_logs` tem, um por um, 13 erros **`57014 canceling statement due to statement timeout`**, em rajadas de **quatro por carregamento de página**. Medido: `anon → statement_timeout=3s`, `authenticated → 8s`. O volume é minúsculo — 2 449 obras, 2 656 registos: mais de três segundos em tão poucas linhas é um plano, não um tamanho. **Nada se vê na tela**: o front recai em `catalog_list_anon_v1` e mostra 91 registos; é o agrupamento por obra que não serve. Treze chamadas anónimas em treze falharam, contra a base real. O primeiro dos dois pré-visualizadores servia `main` sem E17. **O que não está estabelecido**: desde quando; se uma conta ligada passa nos seus 8 s; porquê quatro chamadas por carregamento.

*Verificado : [object Object],[object Object]*

**O que é.** Medir antes de tocar: `EXPLAIN (ANALYZE, BUFFERS)` da chamada que o front faz, **sob o papel `anon`**, com os argumentos por defeito; dizer para onde vai o tempo. Contar as chamadas reais do front ao carregar (quatro?) e dizer porquê. Depois corrigir a consulta — **não** aumentar o prazo do papel anónimo, que protege o pool de 20 conexões. E tornar a falha visível: um recuo silencioso para a lista plana escondeu a avaria.

**Por que importa.** O OPAC por obra é a obra principal de setembro e é a porta de entrada pública da rede. Se só serve contas ligadas — ou ninguém —, todo o trabalho de agrupamento das edições é invisível para quem foi feito. E uma avaria que o recuo esconde perfeitamente é uma avaria que dura.

**O que conta como terminado.**

- Uma chamada anónima de `catalog_works_v1` com os argumentos do primeiro carregamento responde em menos de 3 s — medido, com o plano registado.
- Mais nenhum `57014` nesta RPC em `postgres_logs` durante um dia de tráfego real.
- O front já não recai em silêncio: a falha da RPC é registada, e algo a vigia.

**Dependências.** Encontrado ao verificar **E17**. Toca **C11** e a obra OPAC por obra; primo de **B10**.

*Remissões : `api.catalog_works_v1` · `src/pages/public/CatalogPage.jsx (worksServer, repli)` · `src/lib/catalogueFallback.js` · `anarbib-capacite-plafonds-mesures`*

---

### C — Catalogação e dados documentais

*A dívida aqui não é de código: são fichas para revisar uma a uma.*

| | | | |
|---|---|---|---|
| **C3** | Conduzir a revisão humana das autoridades: sobrenomes, caixa, títulos | `P1` | Aberto |
| **C4** | Preencher os países ausentes em 722 fichas de autoridade | `P2` | Aberto |
| **C6** | Entregar as três assistências de digitação previstas pela spec das convenções | `P2` | Aberto |
| **C7** | Indexar por assunto os 1 549 registros que não têm nenhum assunto | `P2` | Aberto |
| **C8** | Enriquecer as autoridades: datas, identificadores externos, formas variantes | `P3` | Aberto |
| **C9** | As oito perguntas das convenções estão decididas: falta uma chave, uma atualização e cinco gestos à mão | `P2` | Aberto |
| **C10** | Renomear uma das duas colunas `rights_status` | `P2` | Aberto |
| **C11** | Arbitrar o que o OPAC por obra pôs em fila: tomos, obras cindidas, títulos pré-traduzidos, notas MLEG | `P2` | Aberto |

#### C3 — Conduzir a revisão humana das autoridades: sobrenomes, caixa, títulos

`P1` Prioritário · Estado : **Aberto** · Carga : várias semanas · O que exige : biblioteconomia

**Estado.** As 19 migrações `conventions_*` estão aplicadas desde 21/08: os referenciais estão normalizados, as mecânicas seguras foram passadas, a fila de verificação existe e o aplicativo permite trabalhar nela. **O que resta é a parte que nenhuma máquina faz.**

*Verificado : 31/08 — a fila `catalog_review_queue` medida, 310 linhas: o lote de **patronímicos está terminado** (0 a rever), `autorite_casse` quase (3 a rever), `titre_casse` carrega o grosso (174 a rever), e um quarto lote `autorite_collectivite` (2 a rever). **Restam 179 vereditos humanos.** **03/09** — 1 532 autoridades (+227 criadas pelo lote C5, não relidas), 1 468 sem tipo. **Auditoria em profundidade pedida, em nova sessão** : cadramento em `docs/journal/cadrages/REPRISE_audit_autorites_en_profondeur_2026-09-03.md`. **03/09, noite — auditoria feita** (`journal/audits/AUDIT_autorites_2026-09-03.md`): 1 532 autoridades, 23 livros sem autoridade (18 descartados + 5 com `autor` NULL), 3 órfãs (não 6), **13 pares de duplicatas exatas**, 9 delas nascidas do lote C5, 17 `preferred_name` em maiúsculas após a correção de 21/08, 14 coletividades invertidas que o padrão não via, 12 fichas duplas (O8). **Entregue**: cinco migrações testadas (CONV-2 em 17 fichas; homonímia sem caixa nem acentos + 8 sinalizações (os 5 pares de fixtures de formação excluídos); padrão das coletividades + nova semeadura ~36; segunda semeadura do lote caixa ~40; novo lote `autorite_forme` ~95). **A fila carrega agora ~170 vereditos a mais**, todos humanos: lotes `autorite_collectivite`, `autorite_casse`, `autorite_forme` em `/atelier-autoridades`. **Depois, na mesma noite, por decisão de Xavier (« corrige o que é evidente »): quatro migrações de evidências** — 10 duplicatas exatas fundidas, 4 não-agentes retirados, 24 contribuidores vinculados à sua ficha homônima exata, 43 linhas evidentes da fila decididas e aplicadas (Xavier havia posto 87 vereditos ele mesmo entre 20h00 e 20h07). Ficam à mão: as fichas duplas (decisão O8), os periódicos e a editora alojados em `authors`, os pseudônimos e as formas hispânicas ambíguas.*

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

#### C9 — As oito perguntas das convenções estão decididas: falta uma chave, uma atualização e cinco gestos à mão

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : biblioteconomia

**Estado.** `CONV-6` continua «a confirmar» e `CONV-O1` a `CONV-O8` estão abertos. Dois deles carregam trabalho quantificado: `CONV-O7` (o tipo de autoridade existe mas continua ilegível pelo SQL — **16 vereditos de coletividades faltam**) e `CONV-O8` (a cisão de autoridade não existe — **3 separações faltam**).

*Verificado : 31/08 — dos 16 vereditos de coletividades, **14 estão postos** (2 a rever); `authority_type`: 19 `collective`, 45 `person`, 1 241 sem tipo. A cisão de autoridade continua inexistente no banco. Nada medido sobre as oito questões em si. **03/09** — um veredito proposto por pergunta na página das cinco decisões. **Recomendado A**. Veredito pendente. **03/09 — decidido: A, as oito.** Passa a «aberto». **03/09, tarde** — O5 entregue, O6 já feito ; fica só f[3], trabalho manual. **03/09, noite — f[3] mudou de tamanho**: a auditoria das autoridades conta **12 fichas duplas**, não 3 (três antigas não vistas, seis nascidas do lote C5); o veredito O8 « sem cisão antes da quarta » foi ultrapassado pelos fatos e `fn_authority_split` existe desde a migração 17 — **decisão a retomar** (REGISTRO §37, atualização de 03/09 noite). As 2 coletividades a rever continuam; o lote recebe ~36 a mais (padrão refeito).*

**O que é.** **Decidido em 03/09 (C9 = A, as oito).** Resta código pequeno e trabalho à mão: O5 renomear o título da fila; O6 atualizar `avant` na exibição; O2 os dois vereditos de coletividades; O8 as três fichas duplas à mão.

**Por que importa.** A coluna `name_lang` foi criada anulável e sem restrição validada: **criá-la não compromete nada, usá-la sim**. Enquanto a questão ficar aberta, cada nova regra de entrada precisa se perguntar em que se apoia.

**O que conta como terminado.**

- [object Object]
- [object Object]
- [object Object]
- [object Object]

**Dependências.** Esclarece **C6**.

*Remissões : `REGISTRE §37 CONV-6, CONV-O1..O8`*

#### C10 — Renomear uma das duas colunas `rights_status`

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** `digital_assets.rights_status` é um **estado de workflow** (`to_review`, `public_domain_confirmed`) que comanda a visibilidade. O vocabulário de direitos autorais leva o mesmo nome desde a migração `20260820235000_vocabulaire_rights_status`. Dois sentidos, um nome.

*Verificado : [object Object],[object Object]*

**O que é.** Renomear a coluna de workflow — `review_state` por exemplo — e propagar ao front e às RPC. O vocabulário de direitos guarda o nome, já que é ele que fala de direitos.

**Por que importa.** Confusão garantida do contrário, e num assunto em que a confusão se paga: é o estado dos direitos que decide se um documento é visível ao público. Uma armadilha documentada se acrescenta — `access_scope` vale `conta_ativa` **por omissão**, de modo que um documento de domínio público continua reservado às contas ativas enquanto ninguém tiver posto `publico` explicitamente.

**O que conta como terminado.**

- As duas noções levam dois nomes distintos, no banco e na tela.
- A armadilha `access_scope` é lembrada no formulário de catalogação, não só numa nota.

**Dependências.** Nenhuma.

*Remissões : `PLAN_DE_MARCHE §8` · `DECISION_profil_numerisation_2026-08-20`*

#### C11 — Arbitrar o que o OPAC por obra pôs em fila: tomos, obras cindidas, títulos pré-traduzidos, notas MLEG

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia

**Estado.** O OPAC lê-se por obra desde 04/09 (`OPAC-OEU1..6`). O código está entregue; o que resta é **biblioteconomia, no aplicativo**. Contado em produção em 05/09: **9 grupos de tomos** (30 registros) na aba «Volumes», **90 pares** propostos em «Obras cindidas», **3 duplicatas de registros** em «A decidir», **1 452 títulos automáticos** «corrija-me» em 162 obras (pré-tradução terminada, zero erro), **176 notas MLEG** «Assuntos importados» sem assunto no tesauro (oito categorias), e **161 obras com várias edições** das quais uma só tem o título uniforme verificado na língua da obra.

*Verificado : 05/09 — contado em produção: 9 grupos / 30 registros; 90 pares; 3 duplicatas; 1 452 títulos automáticos em 162 obras; 176 notas MLEG; 161 obras multi-edições, 1 verificada.*

**O que é.** No assistente de deduplicação: decidir os grupos de tomos linha a linha (número posto à mão), os pares de obras cindidas («Fundir» ou «Manter separadas»), as três duplicatas. Na ficha: reler os «Títulos por idioma» de uma obra ao abri-la, pôr o «Título uniforme» na língua da obra. Para as 176 notas MLEG, uma decisão **por categoria**: deixar em nota, ou escolher um assunto próximo **existente** — nunca criar entrada (`THES-4`), nunca converter para mais genérico.

**Por que importa.** Um OPAC por obra vale o que valem suas obras: cada biblioteca que entra acrescenta suas edições. A máquina propõe e memoriza, nunca decide (`OPAC-OEU3`, `OPAC-OEU5`, `DEDUP-7`): dois tomos não são uma duplicata, duas edições não são duas obras, e só um olhar o sabe.

**O que conta como terminado.**

- As abas «Volumes» e «Obras cindidas» estão vazias, ou o que fica está memorizado como «não são tomos» / «manter separadas».
- Nenhum título «corrija-me» numa obra aberta ao menos uma vez na catalogação.
- As 176 notas MLEG têm cada uma uma decisão escrita, e `subjects` não ganhou nenhuma entrada.
- As obras com várias edições têm título uniforme na sua língua de origem.

**Dependências.** Nenhuma migração: tudo se faz no aplicativo, pela coordenação de catalogação.

*Remissões : `DECISION_opac_par_oeuvre_2026-09-04` · `REGISTRE §18 OPAC-OEU1..6` · `REGISTRE §30 THES-4` · `REGISTRE §40 DEDUP-10`*

---

### D — Periódicos, efêmeros, recursos digitais

*O que a biblioteconomia do livro não sabe descrever, e que é uma parte enorme dos nossos acervos.*

| | | | |
|---|---|---|---|
| **D3** | Vincular os 91 fascículos e as 87 monografias suspeitas de SOLIDAIRES | `P2` | Bloqueado |
| **D4** | O material efêmero: panfletos, cartazes, adesivos, fanzines | `P1` | Aberto |
| **D5** | Testar a cadeia de digitalização em dez obras antes de equipar quem quer que seja | `P2` | Aberto |
| **D6** | Retomar ou substituir o leitor EPUB | `P3` | Aberto |

#### D3 — Vincular os 91 fascículos e as 87 monografias suspeitas de SOLIDAIRES

`P2` Corrente · Estado : **Bloqueado** · Carga : alguns dias · O que exige : biblioteconomia

**Estado.** O arquivo SOLIDAIRES já traz colunas `revue` e `numero`: **12 títulos a criar, 91 fascículos a vincular**. Além disso, **87 monografias trazem «n°» no título** e estão marcadas por uma flag `numero_dans_titre`: são candidatas ao vínculo.

*Verificado : 31/08 — os 1 673 rascunhos SOLIDAIRES estão no banco (ver C2) e **nenhum traz `serial_id`**: o vínculo dos fascículos não começou. **15/09** — a biblioteca de destino existe e o lote está-lhe atribuído ; o resto continua bloqueado por C2/G7.*

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

*10 locales em paridade estrita, 6 570 chaves cada (06/09), verificadas na integração contínua.*

| | | | |
|---|---|---|---|
| **E1** | Fazer auditar a acessibilidade por alguém que não escreveu o código | `P1` | Aberto |
| **E2** | Decidir as convenções neerlandesa e grega | `P1` | Aberto |
| **E3** | Uniformizar o registro de tratamento entre as dez locales | `P2` | Decisão coletiva |
| **E4** | Resolver os pares irregulares do italiano | `P2` | Aberto |
| **E6** | Dividir as cinco telas que pesam mais de cem quilobytes | `P2` | Aberto |
| **E9** | Terminar o layout móvel: três lotes identificados | `P2` | Aberto |
| **E10** | O resto da base de campo: plantão móvel, notificação push, prancha de códigos | `P3` | Aberto |
| **E14** | Uma página para relatar um bug a partir do aplicativo | `P2` | Aberto |
| **E15** | As palavras de confirmação «esvaziar o histórico» e «excluir a conta» são a mesma palavra em oito de nove locales | `P2` | Aberto |
| **E16** | A subaba Privacidade da Biblioteca mostraria duas mensagens contraditórias sobre a purga automática | `P2` | A verificar |
| **E17** | O bloco «Explorar» do catálogo abre recolhido, para que o primeiro registro seja visível sem rolar | `P2` | Em curso |
| **E19** | Minha conta, «Dados pessoais» : os três blocos de decisão sobem para depois do perfil, lado a lado ; a supressão da conta fica sozinha no fundo | `P2` | Em curso |
| **E20** | A barra de navegação agrupa-se por natureza — Público, Eu, Trabalho — em menus que abrem ao clique, não ao passar do rato | `P2` | Aberto |

#### E1 — Fazer auditar a acessibilidade por alguém que não escreveu o código

`P1` Prioritário · Estado : **Aberto** · Carga : alguns dias · O que exige : nenhuma competência técnica, React / JavaScript

**Estado.** Funcionalidades de acessibilidade estão implementadas: painel de ajustes em todas as páginas desde 26/08, `html lang` que segue a língua exibida (WCAG 3.1.1) com seu teste, campos de 16 px no mínimo, alvos táteis de 44 px, `viewport-fit=cover`. **Nenhuma auditoria de acessibilidade independente foi jamais conduzida.**

*Verificado : **03/09** — a formação (noite 1 em 08/09/2026) tem uma **testemunha leve** (etapa 8: teclado só). Não é a auditoria pedida; E1 fica aberto, o discurso fica «implementado, não auditado». **03/09, fim do dia** — a testemunha leve cabe em qualquer noite da formação. **06/09** — a navegação mudou em 05/09 : página «Quero…» (`/inicio`, 51 intenções) e ligações profundas para os PDF. A auditoria terá de percorrer esses caminhos.*

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

*Verificado : [object Object]*

**O que é.** Decidir o tratamento dos pares irregulares com um falante nativo, depois aplicá-lo às cadeias envolvidas. É um trabalho de língua, não de código.

**Por que importa.** O italiano é a língua da apresentação de Bolonha. Uma interface que aplica sua convenção pela metade se vê na tela compartilhada.

**O que conta como terminado.**

- O tratamento dos pares irregulares está escrito na carta italiana.
- As cadeias envolvidas estão corrigidas.
- As três cadeias que ficaram em francês na interface italiana estão traduzidas (716 cadeias vistas, 3 defeituosas).

**Dependências.** Antes de 08/09 se possível, senão outubro.

*Remissões : `CLAUDE.md, piège connu n°9` · `CALENDRIER_bologne_2026-08-27`*

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

#### E14 — Uma página para relatar um bug a partir do aplicativo

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript, Deno / TypeScript, SQL / PostgreSQL, língua materna

**Estado.** **Pedido de Xavier em 07/09/2026.** Verificado no mesmo dia: **nenhum mecanismo de relato existe no app**. Nenhuma tabela (`bug_reports`, `feedback` — nada; `service_health_incidents` é a supervisão automática), nenhuma das 52 Edge Functions, nenhuma rota em `App.jsx`, nenhuma chave i18n, nenhum link para as issues do Codeberg em `src/`. O único e-mail de contato geral, `contato@anarbib.org`, está enterrado na política de privacidade. O canal documentado vive fora do app, do lado do desenvolvedor: «abrir uma issue no Codeberg» — inacessível a uma bibliotecária sem conta lá.

**Três padrões caseiros já existem**: *(1)* `authority_duplicate_reports` (staff → coordenação, índice único parcial anti-inundação, `HINT` = chaves i18n); *(2)* `book_reading_note_reports` (moderação); *(3)* **`cartography_submissions`** — o único aberto a `anon`: tabela trancada, Edge Function pública com altcha, outbox → `notify-event`, trio `list/approve/reject`, tela de moderação. É o modelo 3 que cobre a necessidade, com o anti-inundação do modelo 1.

*Verificado : 07/09 — grep em `src/`, `supabase/functions/` (52 EF), `App.jsx`, `fr.json`; repositório `eb790c33`. Nenhum mecanismo, nenhum item no backlog antes deste.*

**O que é.** Uma página pública «Relatar um problema» (rota a nomear), acessível **sem conta** e a partir de **todas** as páginas: um link no `Footer` (`src/components/layout/index.jsx`) e uma intenção «Quero relatar um problema» em `intentions.js` (grupo leitor — uma linha). Formulário mínimo: o que aconteceu, o que era esperado, como refazer; **o contexto preenche-se sozinho** (página de origem, locale, papel e biblioteca de sessão, navegador); e-mail de resposta opcional. No servidor, copiar `cartography_submissions`: tabela `bug_reports` trancada, Edge Function `submit-bug-report` com altcha para anônimos, outbox → `notify-event` para `admins@anarbib.org`, status `open/closed`, índice único parcial anti-inundação, RPC `list/close` para admins de rede, e um separador na Rede para a fila. **Duas decisões ao escrever**: ponte para o Codeberg (um admin recopia à mão) ou não; acusar recebimento por e-mail quando houver endereço. Dez locales de imediato, e um teste que guarda a rota e o `Footer`.

**Por que importa.** A formação BLMF começa em 08/09 (sete noites): as coordenações vão topar com defeitos, e o único caminho de retorno hoje é o ouvido de Xavier. Uma ferramenta em que não se pode dizer «está quebrado» sem passar pelo mantenedor contradiz `DOC-COLLECTIVE-1`; e a promessa de **A4** não tem porta para quem não programa.

**O que conta como terminado.**

- [object Object]
- [object Object]
- [object Object]

**Dependências.** Nenhuma bloqueante. Vizinho de **A4** e **E12**. Reutiliza `notify-event` e altcha tal como estão.

*Remissões : `src/components/layout/index.jsx (Footer)` · `src/pages/inicio/intentions.js` · `supabase/migrations/20260618182516_cartography_submissions.sql` · `supabase/functions/submit-cartography-entry` · `supabase/migrations/20260821130001_signaler_un_doublon_d_autorite.sql` · `CONTRIBUTING.md`*

#### E15 — As palavras de confirmação «esvaziar o histórico» e «excluir a conta» são a mesma palavra em oito de nove locales

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : língua materna

**Estado.** **Verificado em `src/i18n/locales/` em 07/09.** Em pt-BR, `account.history.deleteAll.confirmWord` = `APAGAR` e `account.deleteAccount.confirmText` = `EXCLUIR`: dois gestos, duas palavras. Em fr, en, es, it, de, nl, el e eo, **as duas chaves carregam a mesma palavra** (`SUPPRIMER`/`SUPPRIMER`, `DELETE`/`DELETE`…). Só o catalão distingue (`ELIMINA` / `SUPRIMIR`). Levantado primeiro pelo manual da leitora v2 de 03/09.

*Verificado : [object Object],[object Object]*

**O que é.** Escolher duas palavras distintas por locale, com as pessoas falantes quando houver (**E2** para nl e el), e pôr o manual de acordo.

**Por que importa.** Uma palavra de confirmação serve para não confundir duas destruições. Quando é a mesma, não serve para nada — e é exatamente `DOC-DESTR-2`: dizer o que se destrói.

**O que conta como terminado.**

- Nove locales, duas palavras diferentes cada; o teste i18n passa.

**Dependências.** Nenhuma.

*Remissões : `claude/MANUEL_LECTEUR_v2_refonte_2026-09-03` · `REGISTRE §0 DOC-DESTR-2`*

#### E16 — A subaba Privacidade da Biblioteca mostraria duas mensagens contraditórias sobre a purga automática

`P2` Corrente · Estado : **A verificar** · Carga : uma noite · O que exige : React / JavaScript

**Estado.** Levantado pela refonte do manual v5 (01/09): «duas mensagens contraditórias sobre a ativação da purga automática — o manual pede para verificar a instância». **Não verificado em 07/09**: é um defeito de tela, a constatar na aplicação, não nos arquivos.

*Verificado : 07/09 — não verificado, constatação de tela apenas.*

**O que é.** Abrir a subaba em `blmf-teste`, ler as duas mensagens, decidir qual diz a verdade olhando o ajuste no banco, corrigir a outra.

**Por que importa.** Uma tela de privacidade que se contradiz faz duvidar de todo o resto da página — e é a página que uma coordenação lê primeiro.

**O que conta como terminado.**

- Uma só mensagem, conforme o estado real do ajuste.

**Dependências.** Nenhuma.

*Remissões : `claude/MANUEL_v5_refonte_2026-09-01 (points à trancher)`*

#### E17 — O bloco «Explorar» do catálogo abre recolhido, para que o primeiro registro seja visível sem rolar

`P2` Corrente · Estado : **Em curso** · Carga : uma noite · O que exige : React / JavaScript, língua materna

**Estado.** **Pedido de Xavier em 07/09/2026, pela legibilidade do catálogo.** Em `CatalogPage.jsx`, o bloco «Explorar» (modos, alfabeto, árvore de assuntos, facetas) é recolhível desde 21/08, mas nasce **aberto**: `useState(true)`. A cada visita, a página abre num muro de comandos acima dos resultados; no celular, o primeiro registro fica abaixo da dobra. A escolha de recolher **não é lembrada**: `saveFilters` guarda dezessete preferências em `anarbib:catalog:filters`, não `exploreOpen`. Dois fatos tornam o recolhimento sem perda: os filtros ativos aparecem em **chips acima dos resultados**, independentemente do painel, e a árvore de assuntos só carrega à abertura do painel — recolhido por padrão, é também uma requisição a menos.

*Verificado : [object Object],[object Object],[object Object]*

**O que é.** Três gestos, uma noite. **(1)** `useState(false)` por padrão, e `exploreOpen` acrescentado a `saveFilters` / `loadSavedFilters` — a escolha sobrevive ao recarregamento, como `compact`. **(2)** O cabeçalho recolhido diz o que esconde: «Explorar: assuntos, facetas, alfabeto», com o número de facetas ativas em badge (dez locales). **(3)** Um teste de fonte que guarda `useState(false)` e a presença de `exploreOpen` na gravação. Depois verificar na tela, celular incluído. Não reabrir automaticamente quando um filtro está ativo: os chips bastam.

**Por que importa.** O catálogo é a porta de entrada de quem não tem conta — a que a vitrine e a formação mostram primeiro. O que se procura ali é um registro, não um painel; a superfície de exploração deve estar ao alcance da mão, não diante dos olhos. Vizinho direto de **E9** (celular).

**O que conta como terminado.**

- [object Object]
- [object Object]
- [object Object]

**Dependências.** Nenhuma. **G13** acrescentará um seletor ao lado do filtro de bibliotecas, fora do bloco «Explorar»: sem interferência.

*Remissões : `src/pages/public/CatalogPage.jsx (exploreOpen l. 325, saveFilters l. 352-355, arbre des sujets l. 704-715, bloc l. 1410-1416)` · `src/pages/public/CatalogPage.css (.ab-explore-toggle, .ab-explore-panel, .ab-collapse-header)` · `src/i18n/locales/*.json (catalog.section.explore)` · `src/tests/serial-picker-monte.test.js (patron de test de source)`*

#### E19 — Minha conta, «Dados pessoais» : os três blocos de decisão sobem para depois do perfil, lado a lado ; a supressão da conta fica sozinha no fundo

`P2` Corrente · Estado : **Em curso** · Carga : uma noite · O que exige : React / JavaScript

**Estado.** **Pedido de Xavier em 08/09/2026, decidido após debate.** O separador «Dados pessoais» de `/conta` é o mais longo da página ; os três blocos de decisão (exportar, notificações, carta da federação) estão no fundo, e a supressão da conta a seguir. As preferências de conservação vivem em «Histórico» e aí ficam.

*Verificado : [object Object],[object Object],[object Object]*

**O que é.** Uma fila de **três cartões lado a lado** (exportar, notificações, carta) **logo depois do formulário do perfil** ; grelha em `minmax(0, 1fr)`, uma coluna abaixo de 640 px. «Suprimir a minha conta» fica sozinho no fundo, a toda a largura, a vermelho. Nenhuma RPC, nenhuma chave nova ; refazer a captura no Manual v5.

**Por que importa.** O que a página pede para decidir deve ver-se antes do que dá a ler. E a supressão da conta, isolada, mantém o gesto raro à parte dos ordinários.

**O que conta como terminado.**

- Os três cartões visíveis sem rolar num portátil, sob o formulário do perfil.
- A 360 px, uma coluna, sem transbordo.
- A supressão da conta é o último bloco, sozinha, a vermelho.
- Captura do Manual v5 refeita.

**Dependências.** Nenhuma. Depois de 14/09 (congelamento). Vizinho de **E9**.

*Remissões : `AccountPage.jsx (onglet perfil)` · `anarbib-mobile-grid-blowout-doctrine` · `Manuel v5 §Mon compte`*

#### E20 — A barra de navegação agrupa-se por natureza — Público, Eu, Trabalho — em menus que abrem ao clique, não ao passar do rato

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript, língua materna

**Estado.** **Pedido de Xavier em 08/09/2026, decidido após debate.** A barra alinha numa só linha até doze ligações ; cada página alinha os seus separadores (nove a quinze). Tudo está achatado. A proposta inicial (menus por papel, ao passar do rato) foi substituída no debate.

*Verificado : 08/09 — barra relida : sete ligações públicas ou pessoais + até seis de trabalho segundo `canSee*`. Separadores : Minha conta 9, Biblioteca 12, Rede 15, Federação 8. Rede continua reservada às admins (02/09). **15/09 — uma das seis ligações de Trabalho mudou de nome** : « Biblioteca » (`/biblioteca`) chama-se « Gestão da biblioteca » (Xavier, `09165764`, REGISTRE 0.36 `PUBLIB-NAV-2`). O grupo Trabalho listará Painel, Catalogação, Importações, **Gestão da biblioteca**, Federação, Rede ; os 89 diapositivos BLMF mostram a palavra antiga : retomar neste lote.*

**O que é.** **Agrupar por natureza, não por papel** : **Público** (catálogo, bibliotecas, cartografia, tesauro), **Eu** (minha conta, «Quero…»), **Trabalho** (painel, catalogação, importações, biblioteca, federação, rede — cada entrada sob o mesmo `canSee*`, o grupo só aparece se tiver entradas). **Menus ao clique ou Enter, nunca ao passar do rato** (E9, E1), com `aria-haspopup`/`aria-expanded`, Esc, foco devolvido. **Os separadores não mudam neste lote.** Entregar com o registo `intentions.js` relido, as dez locales, o Manual v5 e a formação BLMF.

**Por que importa.** Uma barra de doze ligações sem hierarquia lê-se percorrendo, não olhando. Agrupar por natureza resiste ao número de papéis de uma pessoa ; ao clique funciona onde a app corre.

**O que conta como terminado.**

- A barra só expõe as ligações diretas e três botões de grupo ; cada grupo abre ao clique e ao teclado, fecha em Esc, e só mostra o que o papel abre.
- Uma desconhecida não vê Eu nem Trabalho ; uma leitora vê Eu ; uma bibliotecária vê Trabalho com Painel e Catalogação ; uma coordenação também Importações, Biblioteca, Federação ; a admin de rede vê Rede.
- Nenhum caminho muda : intenções e ligações profundas continuam válidas.
- Dez locales, paridade estrita.
- A 360 px a barra cabe.
- Manual v5 e guião da formação atualizados — ou lote datado depois da última noite de formação.

**Dependências.** Depois de **E9** de preferência ; mesma exigência de olhar externo que **E1**. **Não entregar durante a formação BLMF** (sete noites a partir de 08/09). Congelamento até 14/09.

*Remissões : `src/components/layout/index.jsx` · `src/lib/roles.js (canSee*)` · `src/pages/inicio (intentions.js)` · `anarbib-rede-perimetre-admins (doctrine : une porte se pose dans la page du geste, pas dans la barre)` · `K7 (formation BLMF)`*

---

### F — E-mail e notificações

*13 funções notify-*, 5 filas, 6 gatilhos de despacho. Ninguém jamais auditou o conjunto.*

| | | | |
|---|---|---|---|
| **F1** | Auditar a cadeia de e-mail de ponta a ponta | `P1` | Aberto |
| **F3** | Consolidar as funções de notificação redundantes | `P2` | Aberto |
| **F4** | Três bibliotecas tinham ativado lembretes que ninguém enviava | `P1` | Em curso |
| **F6** | `notify-internal-task` corre sobre uma cópia congelada de toda a pilha de e-mail | `P2` | Aberto |
| **F7** | Um transporte de e-mail sem serviço configurado falha; não simula em silêncio | `P1` | Aberto |
| **F10** | Sair do Resend: um relay militante a pedir, um transporte a escrever, o roteamento a restabelecer — e `sendViaBrevo` ainda está em `email.ts` | `P2` | Aberto |

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

*Verificado : [object Object],[object Object]*

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

#### F7 — Um transporte de e-mail sem serviço configurado falha; não simula em silêncio

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : Deno / TypeScript

**Estado.** A PR #28 adiciona um transporte híbrido SMTP / Resend / « mock »: sem `SMTP_HOST` nem `RESEND_API_KEY`, `sendEmail` devolve `{ok:true, mocked:true}`. É o caso (a) de `DOC-SILENCE-1`. Em produção nada muda hoje; no dia em que o segredo faltar, a produção responderá 200 sem enviar nada. **D4 (21h30)**: no instalador, a simulação vira opção 3, nunca padrão.

*Verificado : [object Object],[object Object]*

**O que é.** Regra a pedir na PR e escrever na spec: mock **só** com `MAIL_TRANSPORT=mock` explícito; sem configuração, falhar como antes. E uma única implementação: os dois `notify-*` devem chamar `_shared/transport/email.ts` em vez de copiar.

**Por que importa.** Uma coordenação acreditou por meses ter cortado suas notificações; o contrário — acreditar que partem — custa lembretes e circuitos colegiais que param sem ruído.

**O que conta como terminado.**

- Sem `MAIL_TRANSPORT=mock`, uma função sem serviço configurado falha com erro legível.
- Uma única função de envio em `_shared/`, chamada por todas as EF.

**Dependências.** Releitura da PR « código aplicativo » (I16).

*Remissões : `supabase/functions/_shared/transport/email.ts` · `REGISTRE §0 DOC-SILENCE-1` · `docs/specs/spec-migration-mail-resend.md` · `codeberg.org/anarbib/anarbib/pulls/28`*

#### F10 — Sair do Resend: um relay militante a pedir, um transporte a escrever, o roteamento a restabelecer — e `sendViaBrevo` ainda está em `email.ts`

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : Deno / TypeScript, deliberação coletiva

**Estado.** **Verificado no repositório em 07/09**: `supabase/functions/_shared/transport/email.ts` conhece dois transportes, `sendViaResend` e `sendViaBrevo` — o segundo sobrevive à retirada do Brevo (R.6/R.7, anunciado fechado). Nenhum transporte SMTP genérico, logo nenhum meio de ligar um relay militante (ARN, Nodo50, bida.im) no dia em que um disser sim. A nota de 05-06/09 põe essa saída depois de Bolonha, atrás do pedido de um relay SMTP no dia 12.

*Verificado : 07/09 — dois transportes em `email.ts`, nenhum SMTP.*

**O que é.** Pedir antes de escolher (os relays militantes primeiro, Scaleway como recuo); escrever `sendViaSmtp` (ou o transporte escolhido) e restabelecer um roteamento por variável; remover `sendViaBrevo`; só levantar erro onde deve (**F7** está fechado nisso).

**Por que importa.** O Resend é o último serviço estadunidense depois do Supabase. Sair de um sem o outro deixa metade da dependência, e a metade mais falante: o e-mail das leitoras.

**O que conta como terminado.**

- Um e-mail real sai pelo novo transporte, da produção, para uma caixa terceira.
- `sendViaBrevo` não existe mais no repositório.

**Dependências.** Depois de **K5** (relay pedido em Bolonha). Não antes de **I2**: mudar de transporte e de hospedeiro na mesma semana são duas incógnitas.

*Remissões : `claude/NOTE_sortie_services_etats_uniens_2026-09-05 (chemin, étape 4)` · `spec-migration-mail-resend`*

---

### G — Rede, governança, federação

*Muitos circuitos construídos, pouquíssimos percorridos. É o principal ensinamento do levantamento.*

| | | | |
|---|---|---|---|
| **G1** | Percorrer os circuitos construídos e jamais usados | `P0` | Aberto |
| **G6** | Dar uma tela ao empréstimo entre bibliotecas | `P2` | Aberto |
| **G8** | Completar a cartografia com os arquivos identificados alhures | `P2` | Aberto |
| **G9** | Implementar a cartografia da rede segundo a spec v1.0 | `P3` | Congelado |
| **G10** | Liquidar as três questões de onboarding marcadas «o mais rápido possível» | `P2` | Aberto |
| **G13** | Um comutador «redes constituídas» no OPAC: ver só os catálogos FICEDL, RebAL, NORLA… | `P2` | Aberto |
| **G14** | Um convite de equipe espera desde 30/08 e expirará em 29/09 — a pessoa talvez não saiba | `P2` | Aberto |

#### G1 — Percorrer os circuitos construídos e jamais usados

`P0` Estrutural · Estado : **Aberto** · Carga : várias semanas · O que exige : deliberação coletiva, nenhuma competência técnica

**Estado.** Verificado em 29/08: **62 tabelas de negócio nunca receberam uma única inserção.** Sete blocos inteiros são atingidos — assembleias da rede (3 tabelas), notas de leitura (2), propostas e objeções de autoridade (3), referenciais de catalogação `catalog_ref_*` (8 de 9), governança dos perfis de biblioteca (4, **enquanto dois crons rodam sobre elas a cada quinze minutos**), deliberação sobre os pedidos de adesão (5, incluindo `library_request_votes` e `library_request_messages`).

**Remedido em 31/08: ainda 62, e não é boa notícia.** A conta não mudou em dois dias — 62 tabelas de `public` em 189 nunca receberam uma inserção. Mas não é a mesma lista: `loan_cycle_notifications`, nascida esta manhã com os lembretes de vencimento, entrou nela **no dia da sua criação**. Um circuito entregue hoje junta-se de imediato à coluna dos circuitos jamais percorridos.

**Um primeiro livro circula.** O empréstimo **#69** foi aberto esta manhã na BLMF — item 84, *O Anarquismo na Escola, no Teatro, na Poesia*, de Edgar Rodrigues, vencimento **21/09**. Dá ao bloco *notas de leitura* a sua primeira hipótese real: o meio-percurso calculado por `notify-loan-cycle` cai em **10 de setembro**, e o convite a deixar uma nota sob pseudónimo parte nesse dia (item **F4**). `book_reading_notes` continua a zero linhas.

Os seis outros blocos estão inalterados em 31/08, verificados tabela a tabela: assembleias da rede (3), propostas e objeções de autoridade (3), referenciais `catalog_ref_*` (8), governança dos perfis (4, **e os dois crons continuam a rodar sobre elas a cada quinze minutos**), deliberação dos pedidos de adesão (5). Todos a zero inserções.

*Verificado : 31/08 — remedido em produção: **62 tabelas de `public` em 189** a zero inserções. A conta é estável, a lista não. Empréstimo **#69** aberto na BLMF; o convite a escrever uma nota de leitura é esperado em **10/09**. **06/09** — dois circuitos a mais construídos sem uso : a oficina aberta às obras (0 proposta) e a revisão dos lotes importados (0 revisão) ; `network_contributors` continua a 0.*

**O que é.** Escolher um bloco e percorrê-lo de verdade, do primeiro ao último gesto: realizar uma assembleia da rede, depositar uma nota de leitura, propor uma autoridade e deixar alguém objetar, fazer deliberar um pedido de adesão. Registrar o que falta, o que surpreende, o que trava.

**Por que importa.** É o principal ensinamento do levantamento de 29 de agosto, e não consta em nenhum documento do corpus. **O projeto não sofre de falta de funcionalidades: sofre de falta de uso.** Um circuito jamais percorrido não está entregue — está apenas escrito. E no dia em que se torna o caminho crítico, como o circuito de convite acaba de se tornar para as promoções, ele quebra em coisas que uma única passagem teria revelado.

**O que conta como terminado.**

- Pelo menos três dos sete blocos foram percorridos de ponta a ponta, em `blmf-teste` e depois no real.
- Cada passagem produziu um relatório escrito do que falta.
- Os blocos cujo uso não é desejado hoje são marcados **dormentes**, com o motivo — não é um fracasso, é uma informação.

**Dependências.** O bloco «assembleia» depende de **A1**. Os outros não.

*Remissões : `Relevé du 29/08/2026` · `REGISTRE §32 AG, §28 ATE, §26 ONBO` · `emprunt #69 (BLMF, item 84, échéance 21/09)` · `item F4` · `public.book_reading_notes`*

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

*Verificado : 07/09 — no repositório: `fn_activate_approved_library_request` não é chamada por **nenhum** componente de `src/` — «Concluir a constituição» não vale, portanto, ativação, como o manual v5 tinha levantado em 01/09. É a quarta questão de onboarding, ou a primeira.*

**O que é.** Os três se tratam juntos porque carregam a mesma questão: o que acontece quando alguém chega, e quando alguém sai?

**Por que importa.** `ONBO-Q13` é o caso de uma coordenação que muda de mãos. Hoje, uma biblioteca cuja pessoa coordenadora desaparece não tem caminho escrito. É exatamente o risco que **A1** descreve na escala da rede, desta vez na escala de uma biblioteca.

**O que conta como terminado.**

- A transferência de mandato tem um caminho escrito e testado em `blmf-teste`.
- `#111` tem um veredicto: reativada, ou fechada.
- O módulo 10 está terminado.

**Dependências.** Esclarecido por **G3** (o circuito de convite é o mesmo).

*Remissões : `REGISTRE §26 ONBO-Q13` · `spec-onboarding-biblioteca-v2.0`*

#### G13 — Um comutador «redes constituídas» no OPAC: ver só os catálogos FICEDL, RebAL, NORLA…

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : SQL / PostgreSQL, React / JavaScript, língua materna, biblioteconomia

**Estado.** **Pedido de Xavier em 07/09/2026**: restringir a exibição aos catálogos das bibliotecas que pertencem a uma rede constituída **antes** do AnarBib — FICEDL, RebAL, NORLA.

**O modelo não conhece essas redes.** `libraries` não tem coluna nem tabela de afiliação externa — `network_mode`, `visibility_level='network'`, `catalog_mode='network_published'` falam todos da relação com a rede **AnarBib**, falsos amigos. Dois únicos portadores, em texto livre: **`cartography_entries.reseau`** (sem vocabulário controlado) e `library_commons.affiliation_label` (editorial). Nas 187 fichas do mapa: `FICEDL` 34, `RebAL ; FICEDL` 11, `RebAL` 6, `FAI Reggiana` 2 … — 130 vazias; separadores `;` e `,` misturados. **NORLA não aparece em lugar nenhum dos dados.** O campo só aparece no balão do mapa, nunca filtrável, ausente do formulário de edição, ausente das vistas públicas (`api.libraries_public_v1` serve `id, slug, name, short_name, city, state`).

**No OPAC**, o filtro por biblioteca passa pelos **nomes curtos** (`p_filters.libraries` → `api.catalog_works_v1`), guardado em `localStorage` — nenhuma noção de rede.

**Medido em produção em 07/09**: só três bibliotecas têm ficha de mapa ligada — BLMF (FICEDL, 248 exemplares), BTL (FICEDL, 2 184), MLEG (sem rede, 269). Um comutador «só FICEDL» mostraria hoje BLMF + BTL; «RebAL» ou «NORLA», nada: o item vale pelo que a rede se torna, não pelo que é.

*Verificado : 07/09 — produção consultada em leitura (junção `cartography_entries` × `libraries`: três linhas); valores de `reseau` contados em `carte-reseau.umap`; repositório `eb790c33`.*

**O que é.** Três passos. **(1) Normalizar**: um vocabulário controlado das redes (tabela `networks`: slug, rótulo, site) e uma coluna `reseaux text[]` — ou tabela de junção — em `cartography_entries`, preenchida a partir de `reseau` (cortar em `;` e `,`), o campo acrescentado ao `CartographyEditModal` com suas chaves i18n; a pertença continua declarada pela ficha do mapa, que já tem moderação — **nenhum circuito novo**. **(2) Expor**: uma coluna `networks` em `api.libraries_public_v1` por junção em `cartography_entries.library_id` — reescrevendo a vista **com** `security_invoker`. **(3) Filtrar**: em `CatalogPage.jsx`, ao lado do seletor de bibliotecas, um seletor de redes que reduz `libraryOptions` e alimenta `libraryShortNames` — **sem tocar no RPC** nem nas vistas materializadas; guardado em `localStorage`, visível em chip. **Decisão ao escrever**: um interruptor único «só redes constituídas» ou um filtro por rede (FICEDL / RebAL / NORLA) — o segundo custa o mesmo e responde a «onde estão os nossos catálogos?». Uma biblioteca sem ficha de mapa não aparece em rede nenhuma: dizê-lo na tela, não a fazer desaparecer em silêncio.

**Por que importa.** Bolonha (13/09) reúne gente cujas redes existiam antes do AnarBib; a primeira coisa que procurarão na tela é a sua. As convenções de interoperabilidade dizem que «não há nada a que aderir»: mostrar as redes tal como existem, em vez de fundi-las num anuário AnarBib, é a tradução dessa frase na interface.

**O que conta como terminado.**

- [object Object]
- [object Object]
- [object Object]

**Dependências.** **G8** enriquece o resultado sem o condicionar. **G9** está congelado: não esperar por ele, o passo (1) lhe servirá. Vizinho de **H6**. O passo (2) toca uma vista: reler as opções de `CREATE OR REPLACE VIEW` antes.

*Remissões : `supabase/migrations/20260618142238_cartography_schema.sql (colonne reseau)` · `docs/specs/spec-cartographie-reseau.md` · `src/pages/public/CatalogPage.jsx (libraryFilter, libraryShortNames, FILTER_STORAGE_KEY)` · `supabase/migrations/20260904150000_l_opac_par_oeuvre_se_lit_sans_session.sql (p_filters.libraries)` · `api.libraries_public_v1 (baseline)` · `src/pages/federacao/CartographyMap.jsx` · `docs/cartographie/carte-reseau.umap`*

#### G14 — Um convite de equipe espera desde 30/08 e expirará em 29/09 — a pessoa talvez não saiba

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado.** **Verificado no banco em 07/09**: em `library_team_invitations`, um convite criado em 30/08 continua `ready`, expira em 29/09 (dois outros de 01/09 estão `accepted` e `pending_ratification`). O plano de formação de 01/09 já o sinalizava: «é preciso avisá-la». O cron de expiração vai fechá-lo em silêncio.

*Verificado : [object Object],[object Object],[object Object]*

**O que é.** Uma mensagem à pessoa convidada, pelo canal humano (`DOC-COLLECTIVE-1`). Depois olhar por que o convite por e-mail não bastou — é **G1** em miniatura.

**Por que importa.** Um circuito que expira sem que ninguém perceba é um circuito que não existe.

**O que conta como terminado.**

- O convite está `accepted` ou `declined` antes de 29/09, não expirado.

**Dependências.** Nenhuma.

*Remissões : `claude/PLAN_formation_coordination_BLMF_2026-08-26 (annexe)` · `REGISTRE §0 DOC-COLLECTIVE-1`*

---

### H — Interoperabilidade, tesauro, coleta

*Sair em direção aos outros catálogos, e aceitar ser apontado de volta.*

| | | | |
|---|---|---|---|
| **H2** | Colocar à FICEDL as sete questões que bloqueiam a exportação do tesauro | `P1` | Bloqueado |
| **H6** | Alinhar os vocabulários militantes que não se conhecem | `P2` | Aberto |
| **H9** | Abrir as cinco relações SKOS aos consumidores — RPC, página de assunto, serializador, trinta chaves i18n, num só bloco | `P1` | Congelado |
| **H10** | Reler à mão os 98 alinhamentos FICEDL — 54 `close` dos quais uma parte são `broad` — e alinhar enfim as quatro rubricas históricas de Solidaires | `P2` | Aberto |
| **H11** | O repositório diz 462 descritores FICEDL, a produção carrega 621 — regenerar a migração de dados antes que um replay do zero quebre | `P2` | Aberto |
| **H12** | As listas fora do tesauro da FICEDL — municípios do Bettini, lugares de edição do Bianco: pedir a exportação como está, nunca a integração | `P3` | Aberto |
| **H13** | O esboço SKOS dos 26 descritores não está nem no repositório nem no projeto — versá-lo em `docs/journal/ficedl/` para que seja doável e versionado | `P2` | A verificar |

#### H2 — Colocar à FICEDL as sete questões que bloqueiam a exportação do tesauro

`P1` Prioritário · Estado : **Bloqueado** · Carga : uma noite · O que exige : deliberação coletiva

**Estado.** A exportação completa dos 620 descritores nos dois formatos está a **uma noite de trabalho** — assim que as sete questões tiverem resposta. Estão escritas e ninguém ainda as colocou.

*Verificado : [object Object],[object Object]*

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

#### H9 — Abrir as cinco relações SKOS aos consumidores — RPC, página de assunto, serializador, trinta chaves i18n, num só bloco

`P1` Prioritário · Estado : **Congelado** · Carga : alguns dias · O que exige : SQL / PostgreSQL, React / JavaScript, língua materna

**Estado.** **Verificado no banco e no repositório em 07/09.** O domínio de `subject_ficedl_links.match_type` agora carrega `exact`, `close`, `broad`, `narrow`, `related` (migração `20260907172508`), mas a porta ficou fechada de propósito: `api.fn_subject_add_ficedl_match` só aceita `exact`/`close`, porque **duas renderizações são binárias** — `src/pages/public/SubjectPage.jsx` (l. 163) mostra «exata» para tudo que não é `close`, e `src/lib/skosExport.js` serializa como `skos:exactMatch` tudo que não é `close`, no Turtle e no JSON-LD publicados. Um `broad` criado hoje seria publicado como correspondência exata.

*Verificado : 07/09 — domínio estendido no banco, porta fechada, duas renderizações binárias constatadas no repositório.*

**O que é.** Estender a guarda da RPC aos três valores; substituir os dois ternários por uma tabela de cinco entradas (`skos:broadMatch`, `skos:narrowMatch`, `skos:relatedMatch`); acrescentar três chaves `subject.matchBroad/Narrow/Related` nas dez locales (o teste i18n bloqueia se faltar). Entregar os três juntos, nunca um sem os outros.

**Por que importa.** Enquanto o domínio existir no banco sem consumidor capaz de dizê-lo, cada alinhamento «mais amplo» continua espremido em `close` — uma sobreafirmação publicada. E abri-lo sem as renderizações seria pior: um `broad` sairia como `exactMatch` num arquivo que outros catálogos podem coletar.

**O que conta como terminado.**

- Um alinhamento `broad` posto pela tela aparece «mais amplo» na página de assunto e sai como `skos:broadMatch` no Turtle e no JSON-LD.
- `npm test` passa com as trinta chaves.
- A migração `20260907172508` tem seu bloco de verificação 4.2 (porta fechada) retirado ou invertido no mesmo dia.

**Dependências.** Congelado até 14/09 (código de produção). Precede **H10**.

*Remissões : `REGISTRE §0 DOC-THES-1` · `REGISTRE §30 THES-FIC4, THES-FIC5` · `claude/VERIF_subject_ficedl_links_schema_2026-09-07` · `migration 20260907172508`*

#### H10 — Reler à mão os 98 alinhamentos FICEDL — 54 `close` dos quais uma parte são `broad` — e alinhar enfim as quatro rubricas históricas de Solidaires

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia

**Estado.** **Verificado no banco em 07/09.** 98 vínculos em `subject_ficedl_links`: 44 `exact`, 54 `close`. Até 07/09 o domínio só tinha esses dois valores, logo tudo que é realmente «mais amplo» ou «vizinho» foi espremido em `close`. Por vocabulário visado: 72 para a lista comum, 26 para a geo-histo, **0 para a faceta `dates`** — as quatro rubricas históricas de Solidaires (guerras, períodos) continuam, portanto, sem alinhamento, embora as 159 datas estejam no banco desde 03/09 (H1 fechado).

*Verificado : 07/09 — 98 vínculos, 54 `close`, 0 para `dates`.*

**O que é.** Ficha por ficha, nunca por passagem automática (`CONV-EXEC-3`): para cada `close`, decidir se fica `close` ou vira `broad`/`narrow`/`related`; pôr os alinhamentos faltantes para a faceta `dates` nas rubricas históricas; passar também os 44 alinhamentos do lote Solidaires de 28/08.

**Por que importa.** Um `skos:closeMatch` diz «quase o mesmo conceito». Quando o assunto local é mais estreito, é falso — e está publicado no export que outros catálogos podem ler.

**O que conta como terminado.**

- Cada vínculo carrega uma relação escolhida, não herdada de um domínio de dois valores.
- Existe pelo menos um alinhamento para um descritor `dates`.

**Dependências.** Depois de **H9**: sem os cinco valores abertos na tela, a releitura não tem ferramenta para dizer o que vê.

*Remissões : `REGISTRE §30 THES-FIC4, THES-FIC-O1` · `claude/VERIF_subject_ficedl_links_schema_2026-09-07` · `CALENDRIER_bologne_2026-08-27 (rubriques historiques)`*

#### H11 — O repositório diz 462 descritores FICEDL, a produção carrega 621 — regenerar a migração de dados antes que um replay do zero quebre

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** **Verificado em 07/09, repositório e produção.** `20260826191000_donnees_ficedl_thesaurus.sql` insere 462 linhas (227 assuntos, 234 geo, 1 dupla, **0 data**) — congelada na coleta de 30/06. A produção carrega a coleta de 03/09: **621** (159 datas a mais) porque `ficedl_thesaurus_sync.mjs` foi reexecutado. O replay a partir de um banco vazio ainda passa: os 47 `mot_id` referenciados pela migração de alinhamento estão todos nos 462. Vai quebrar no dia em que um alinhamento visar um termo posterior a 30/06 — é exatamente o que **H10** vai fazer. Duas datas da coleta (161) faltam no banco (159): sem rótulo, descartadas por `isSyncable`.

*Verificado : 07/09 — 462 no repositório, 621 na produção, replay ainda verde.*

**O que é.** Regenerar a migração de dados a partir de `docs/journal/ficedl/ficedl_thesaurus_2026-09-03.json` (ou substituí-la por um seed reexecutado pelo sync na CI), e olhar as duas fichas sem rótulo. Nunca rodar o sync com `--prune`.

**Por que importa.** Uma reconstrução do zero (**A2**, a virada **I2**) que não reexecuta os dados de produção não é uma reconstrução — é outro banco.

**O que conta como terminado.**

- `count(*)` de `ficedl_thesaurus_terms` idêntico na CI e na produção.
- O replay de `sql-tests.yml` passa com um alinhamento para um descritor `dates`.

**Dependências.** Antes de **H10**. Condiciona **A2** e **I2**.

*Remissões : `REGISTRE §30 THES-FIC-O4` · `claude/VERIF_subject_ficedl_links_schema_2026-09-07` · `REPRISE_claude_code_2026-08-27 (piège --prune)`*

#### H12 — As listas fora do tesauro da FICEDL — municípios do Bettini, lugares de edição do Bianco: pedir a exportação como está, nunca a integração

`P3` Adiado · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica, deliberação coletiva

**Estado.** Resposta da fonte, 07/09: dois referenciais existem fora do tesauro — os municípios das biografias do *Bettini* (com cartografia) e os lugares de edição do *Bianco* — «não integrados ao tesauro, provavelmente pesado demais para gerir». O AnarBib não tem nenhuma autoridade de lugares: `local_publicacao` é campo livre (auditoria de 20/08: `BELEM`), e a spec de periódicos descartou o alinhamento FICEDL porque o tesauro indexa assuntos — verdade para os assuntos, falso para os lugares.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Depois de Bolonha, e fora do pedido do dia 12 (que se sustenta porque pede *uma* coisa): pedir as duas listas como arquivos separados, como estão. Depois alinhar a um referencial geográfico existente (Wikidata, GeoNames) com a lista do Bianco como sobrecamada militante — não construir mais uma lista de municípios.

**Por que importa.** Pedir a integração é pedir a carga que a fonte diz não poder carregar. Uma lista não precisa estar no tesauro para ser útil; precisa ser copiável.

**O que conta como terminado.**

- As duas listas recebidas em forma legível por máquina, versadas em `docs/journal/ficedl/`.
- Uma decisão escrita sobre a autoridade de lugares do AnarBib.

**Dependências.** Depois de **K5**. Toca `spec-periodiques` e **C3** (autoridades).

*Remissões : `REGISTRE §30 THES-FIC-O2` · `claude/REPONSE_hortical_deux_thesaurus_2026-09-07` · `claude/spec-periodiques-v0.1 §5`*

#### H13 — O esboço SKOS dos 26 descritores não está nem no repositório nem no projeto — versá-lo em `docs/journal/ficedl/` para que seja doável e versionado

`P2` Corrente · Estado : **A verificar** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado.** O dossiê de Bolonha de 03/09 diz: `ficedl_thesaurus_ESQUISSE.csv` e `.jsonld` «não estão no projeto», a levar em pendrive. **Verificado em 07/09**: `docs/journal/ficedl/` contém as quatro coletas e as auditorias, **nenhum arquivo `ESQUISSE`**; o projeto Claude tampouco. O raspador e o sync, esses, estão no repositório (`scripts/ficedl_thesaurus_scrape.mjs`, `_sync.mjs`) — essa metade já é doável.

*Verificado : 07/09 — ausentes do repositório e do projeto; sua existência em disco não foi verificada.*

**O que é.** Reencontrar os dois arquivos (Downloads?) ou regenerá-los a partir da coleta de 03/09, e commitá-los com a nota de 28/08 ao lado. Desde 07/09 o esboço está para revisar: dois `skos:ConceptScheme`, as cabeças `guerres`/`art : courants` em `skos:Collection`, nunca URI de esquema inventada — e, desde a nota da fonte sobre as URL: URI canônica `https://thesaurus.ficedl.info/?motNN`, `skos:notation` = o número, a forma `/id/motNN` retirada.

**Por que importa.** É a peça que você põe na mesa em Bolonha. Uma peça que só existe num pendrive não é contribuição, é demonstração.

**O que conta como terminado.**

- Os dois arquivos no repositório, regeneráveis por um comando documentado.

**Dependências.** Ligado a **H2** e **K6**.

*Remissões : `claude/DOSSIER_rencontre_leftovers_bologne_2026-09-12 §B.1` · `claude/NOTE_export_thesaurus_questions_ouvertes_2026-08-28`*

---

### I — Auto-hospedagem, operação, backups, CI

*Congelado até 14/09/2026 na produção. O trabalho em ambiente de teste continua aberto.*

| | | | |
|---|---|---|---|
| **I2** | Concluir a migração para a auto-hospedagem | `P1` | Congelado |
| **I3** | Testar o roteador `main` da pilha auto-hospedada | `P1` | Congelado |
| **I15** | O secret do Forgejo da chave publicável ainda carrega seu nome antigo | `P3` | Aberto |
| **I18** | O banco de CI não faz replay numa imagem Supabase — é preciso um que faça | `P2` | Em curso |
| **I21** | O que deve ser verdade antes da virada para Les Herbes Folles, e ainda não é — oito condições, nenhuma tecnicamente difícil | `P1` | Aberto |
| **I22** | Decidir `DOC-DEPLOY-1` após o desvio de 07/09: tolerar e rastrear, ou proibir e controlar | `P2` | Aberto |
| **I24** | O fluxo de backup `storage` é morto quando a sessão WSL para, e o seu alerta `OnFailure` não parte | `P1` | Aberto |
| **I23** | Registrar um ccTLD europeu e fazê-lo alias de `anarbib.org` — o `.org` continua sob registro estadunidense | `P2` | Aberto |
| **I25** | A rede das suítes SQL deu FAIL numa suíte verde — uma vez, sem causa encontrada | `P3` | Aberto |

#### I2 — Concluir a migração para a auto-hospedagem

`P1` Prioritário · Estado : **Congelado** · Carga : várias semanas · O que exige : administração de sistemas

**Estado.** A pilha está reduzida de doze a **seis contêineres** (`db`, `rest`, `auth`, `storage`, `functions`, `caddy`), as versões estão fixadas, `bootstrap.sh` foi executado de verdade em 26/08 com oito defeitos levantados e corrigidos, e o ensaio de 18/08 reexecutou 124 migrações e restaurou um dump de produção em 17 segundos. Reconstrução completa medida: **25 minutos**.

*Verificado : 08/09 — o hospedeiro da videoconferência é o Framatalk desde este dia; nenhuma resposta de hospedeiro sobre um Jitsi foi ainda pedida. O fundo de mapa é um arquivo de 18 GB no Storage (`map-tiles`), a fazer seguir.*

**O que é.** O que resta: desacoplar a cadeia de implantação da integração contínua (**extração, não criação** — `scripts/ci/deployer-backend.sh` já existe), colocar um proxy reverso com túnel na frente da pilha, passar de tags para impressões `sha256`, e refazer o ensaio a frio um mês depois para verificar que nada divergiu. **Acrescentado em 08/09/2026, a colocar ao hospedeiro previsto (Les Herbes Folles), ou a um ou vários outros**: **um Jitsi nosso.** A videoconferência de apoio mútuo e de assembleias vivia na Autistici/Inventati; a A/I foi designada «SDGT» pelos Estados Unidos em 26/08 e fechou; em 08/09 mudámos para o Framatalk (Framasoft, Hetzner na Alemanha) — um terceiro de confiança, mas um terceiro, numa infraestrutura que uma medida do mesmo tipo pode atingir. Um Jitsi hospedado por nós (ou por um coletivo de hospedagem aliado, ou repartido entre vários) é a única saída completa. Não é a mesma carga que o resto da pilha: o videobridge consome largura de banda de subida na proporção das participantes. **Perguntas a fazer**: a VM aguenta um Jitsi (RAM, banda, porta UDP 10000); preferem uma segunda máquina; outro hospedeiro aliado (Chapril, Systemli, uma instância amiga) aceitaria carregar a videoconferência da rede, mesmo que não viva no mesmo lugar que a base? No mesmo dia, **o arquivo de fundo de mapa** (`map-tiles/planet-z12.pmtiles`, 18 GB, a reextrair em z15 a partir da VM: 138 GB) entrou no que se muda — a contar no disco pedido (I21).

**Por que importa.** É o objetivo que o projeto se deu e que ainda não atingiu: o fim da dependência de um provedor terceiro. **É o canteiro mais técnico e mais autônomo do lote** — alguém pode assumi-lo sem coordenação.

**O que conta como terminado.**

- A pilha roda atrás de um proxy reverso, com as versões em impressões.
- Uma reconstrução completa foi refeita um mês após a primeira.
- Guarda a preservar imperativamente: o laço de implantação percorre `supabase/functions/*/` **excluindo `_shared` e `main`** — sem o que o roteador iria para o Supabase hospedado.
- Armadilha já encontrada: os papéis de serviço não têm senha na imagem `supabase/postgres` (SQLSTATE 28P01 em laço), `postgres` não é superusuário (é `supabase_admin`), `authenticator` é reservado, e um `set -e` no laço mata o script no primeiro papel em falha.
- A pergunta de um Jitsi (no hospedeiro, num aliado, ou repartido) foi feita, e a resposta está registada aqui — mesmo que seja «não».

**Dependências.** **Congelado na produção até 14/09.** Depende de **I1**. A fazer antes de alugar o que quer que seja: retomar a conexão autenticada em local, bloqueada por uma resolução IPv6 sem rota — **esse bloqueio provavelmente desapareceu sozinho**, verificá-lo custa cinco minutos e pode poupar uma máquina montada à toa.

*Remissões : `docs/CHANTIERS_OUVERTS.md §2` · `deploy/README.md` · `REPRISE_bascule_autohebergee_2026-08-26` · `SETUP_fonds_de_carte_pmtiles_2026-09-07` · `REGISTRE FED-O9 (08/09)`*

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

#### I18 — O banco de CI não faz replay numa imagem Supabase — é preciso um que faça

`P2` Corrente · Estado : **Em curso** · Carga : alguns dias · O que exige : administração de sistemas

**Estado.** `scripts/ci/run-sql-suites.sh` cria `anarbib_test` a partir de `template0`: `pg_default_acl` está vazia, as funções nascem fechadas e a verificação passa — uma imagem real a faz falhar. O verde do `sql-tests` não atesta que uma imagem Supabase reproduz o repositório. **07/09**: a spec de `I17` (§8) torna este item barato — basta um segundo job que reproduza as migrações no banco `postgres` do serviço em vez de um banco `template0`. **07/09, confirmado pela experiência de `I17`**: com A.1 antes da base e `CREATE EXTENSION pg_cron`, o banco `postgres` da imagem reproduz as 310 migrações sob `postgres`; o job estaria verde hoje. **16/09: entregue.** Job `rejeu-image` em `sql-tests.yml` (`scripts/ci/run-image-replay.sh`): mesmo serviço Postgres, replay no banco `postgres` da imagem pelos dois scripts da pilha (`01-roles.sh`: A.1 e `pg_cron`; `run-migrations.sh` sob `postgres`), precedido do que a pilha obtém dos seus serviços antes de migrar (sal no Vault real, stubs `auth`/`storage`, stub de ponte `_ci_setup_image_services_stub.sql`). Quatro faltas da imagem nua medidas no caminho: `auth.jwt()` ausente; `auth.users` de origem sem `email_confirmed_at` / `is_sso_user` / `is_anonymous`; `auth.uid()` de origem que não lê `request.jwt.claims`; `storage.buckets` fechada a `postgres`. Provado quatro vezes em contêiner descartável `17.6.1.084`: **320/320 em 54 s, 133 funções `anon`, MD5 idêntico à produção, 38 crons, 0 tabela sem RLS**. Falta: o primeiro run da forja e o critério 2 (um vermelho por razão real, corrigido).

*Verificado : 16/09 — job escrito e provado quatro vezes em contêiner descartável `17.6.1.084` (worktree `claude/i18`), lista das 133 funções `anon` comparada linha a linha com a de 15/09, MD5 idêntico.*

**O que é.** Ler o run em Actions. Quando ficar vermelho, corrigir a causa — uma migração, ou a ponte — nunca o job. No dia em que um vermelho motivado for corrigido, encerrar (critério 2).

**Por que importa.** Toda afirmação « N migrações reproduzem do zero » mede-se numa imagem Supabase, nunca no banco de CI.

**O que conta como terminado.**

- Um job da forja reproduz as migrações em `supabase/postgres` com resultado legível em Actions.
- Foi vermelho uma vez por uma razão real, corrigida.

**Dependências.** Depois de I17.

*Remissões : `scripts/ci/run-sql-suites.sh` · `REGISTRE §0 DOC-GRANT-2` · `REGISTRE §0 DOC-MIGR-1` · `scripts/ci/run-image-replay.sh` · `tests/sql/_ci_setup_image_services_stub.sql` · `.forgejo/workflows/sql-tests.yml` · `deploy/init-db/01-roles.sh` · `deploy/scripts/run-migrations.sh`*

#### I21 — O que deve ser verdade antes da virada para Les Herbes Folles, e ainda não é — oito condições, nenhuma tecnicamente difícil

`P1` Prioritário · Estado : **Aberto** · Carga : alguns dias · O que exige : administração de sistemas, deliberação coletiva

**Estado.** A decisão de 07/09 (oferta confirmada: VM IPv4, Debian, backups já lá) e a nota de 05-06/09 deixam uma lista que nada mantém junta. **Verificado em 07/09 em `deploy/`**: nenhum rastro de `unattended-upgrades`, firewall nem autenticação só por chave. O resto é humano ou local: a conexão autenticada na pilha local nunca retestada desde a retirada do Turnstile; `deploy/.env` sobrescrito por `install.sh` (domínios em `localhost`) sem cópia conhecida; o teste a partir de uma rede móvel brasileira (NAT64) nunca feito; o prazo de intervenção de Les Herbes Folles nunca pedido; o meio de lhes pagar «pedido desde julho, sem resposta»; um segundo detentor dos acessos; e a regra posta em 07/09: **não se vira antes que o backup tenha ido para um terceiro** — hoje os três fluxos restic estão no próprio hospedeiro de destino.

*Verificado : [object Object],[object Object]*

**O que é.** Manter a lista aqui, marcar cada condição com sua prova (arquivo, e-mail, teste datado). O endurecimento entra em `deploy/`; o depósito de backup terceiro pede-se em Bolonha (**I12** diz o que o espelho frio cobre, e não é isso).

**Por que importa.** Cada condição é pequena. Juntas, são a diferença entre uma virada e uma mudança de endereço da fragilidade.

**O que conta como terminado.**

- As oito condições marcadas com prova, neste item.
- `deploy/` carrega o endurecimento, reexecutado por `bootstrap.sh`.

**Dependências.** Bloqueia **I2**. O depósito terceiro e o segundo detentor pertencem à mesma conversa que **A1** (Bolonha).

*Remissões : `claude/DECISION_herbesfolles_offre_confirmee_2026-09-07` · `claude/NOTE_sortie_services_etats_uniens_2026-09-05` · `claude/REPRISE_claude_code_PR28_revoke_anon_2026-09-06 (deploy/.env)`*

#### I22 — Decidir `DOC-DEPLOY-1` após o desvio de 07/09: tolerar e rastrear, ou proibir e controlar

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado.** Em 07/09, a migração `20260907172508` foi aplicada em produção por `apply_migration` (MCP) — o que `DOC-DEPLOY-1` proíbe com todas as letras. Desvio constatado depois, rastreado no REGISTRE §30, recuperado sem dupla aplicação (arquivo renomeado com o timestamp registrado em `supabase_migrations.schema_migrations`). O registro deixa a questão aberta e lembra que, enquanto estiver, **a regra escrita vale**.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Duas saídas, uma linha no registro cada: tolerar em caráter excepcional e rastreado, no modelo de `DOC-DEPLOY-3` — ou reafirmar a proibição e pôr o controle que a torna verificável: uma versão presente em `supabase_migrations.schema_migrations` cujo arquivo não está no repositório é a assinatura exata do desvio (uma consulta, executável na CI).

**Por que importa.** Uma regra infringida sem consequência vira regra decorativa. A consequência pode ser uma exceção escrita; não pode ser o silêncio.

**O que conta como terminado.**

- A linha `DOC-DEPLOY-1` do registro não carrega mais o ⚠️ de 07/09.

**Dependências.** Nenhuma.

*Remissões : `REGISTRE §0 DOC-DEPLOY-1` · `REGISTRE §30 (écart tracé)` · `claude/VERIF_subject_ficedl_links_schema_2026-09-07 §4`*

#### I24 — O fluxo de backup `storage` é morto quando a sessão WSL para, e o seu alerta `OnFailure` não parte

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** **Constatado em 15/09/2026 ao voltar de Bolonha.** Domingo 13/09 o posto estava desligado ; em 15/09 às 08h15 o systemd recuperou os três fluxos : `court` e `long` terminaram, **`storage` foi morto às 08h23 por `SIGTERM`** — o encerramento da sessão WSL — e a unidade de alerta `OnFailure` **não pôde ser lançada**. Resultado : fluxo `storage` com nove dias, testemunho `started` sem `ok`, nenhum e-mail. Relançado à mão às 20h50.

*Verificado : [object Object],[object Object],[object Object],[object Object]*

**O que é.** **(1)** O serviço `storage` não deve morrer com a sessão (`KillMode=`, `TimeoutStopSec=`, ou `loginctl enable-linger`). **(2)** O alerta não deve depender da sessão : o controlo de frescura do meio-dia deve **enviar** quando um fluxo passa o limiar ou tem um `started` sem `ok`.

**Por que importa.** Um backup que falha em silêncio quando o posto reinicia é a avaria que só se vê na recuperação. O fluxo `storage` é **o único backup dos 16 buckets**.

**O que conta como terminado.**

- O serviço `storage` sobrevive ao fecho do terminal WSL.
- Um fluxo em atraso ou «interrompido» produz um e-mail em 24 h.
- Um posto desligado ao domingo dá três fluxos verdes na segunda, ou um e-mail.

**Dependências.** Primo de **I12**. Ligado a **A3**.

*Remissões : `deploy/ops/systemd/` · `anarbib-systemd-etat-non-fiable` · `anarbib-backup-stale-lock-selfheal` · `RUNBOOK_restauration_BG2_2026-07-01`*

#### I23 — Registrar um ccTLD europeu e fazê-lo alias de `anarbib.org` — o `.org` continua sob registro estadunidense

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** A nota de 05-06/09 põe isso no início do caminho: «esta semana — registrar um ccTLD europeu e fazê-lo alias», compatível com o congelamento porque não toca a produção. Motivo: o registro do `.org` (Public Interest Registry) é estadunidense, como os dois serviços dos quais o projeto está saindo. **Não verificado** — sem resolução DNS possível daqui; nada no repositório o menciona.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Escolher o domínio, registrá-lo na OVH, pôr um redirecionamento para `anarbib.org` (e não o inverso, por enquanto), e escrevê-lo na política de privacidade se ela o mencionar.

**Por que importa.** Um alias custa um euro por mês e dá um endereço que sobrevive a uma decisão estrangeira sobre o `.org`.

**O que conta como terminado.**

- O domínio resolve e redireciona.

**Dependências.** Nenhuma. Independente do congelamento.

*Remissões : `claude/NOTE_sortie_services_etats_uniens_2026-09-05 (chemin, étape 1)`*

#### I25 — A rede das suítes SQL deu FAIL numa suíte verde — uma vez, sem causa encontrada

`P3` Adiado · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** Em 16/09 (run 7092391, `d5228c7f`), `sql-tests` ficou vermelho só em `paquet19_loan_wrappers_tests.sql`, cujo balanço diz « OK : 46/46 ». A rede de `run-sql-suites.sh` (`grep -qE` sob `pipefail`) deu FAIL nesse texto. Reproduzido byte a byte fora da CI (WSL e imagem `node:22`): PASS sempre. Nenhuma anomalia no log; suíte inalterada desde 02/09, quatro linhas por construção. Relançado por Xavier: verde às 22h05. Um acaso — e um acaso que dá vermelho custa um relance e um ticket; o inverso seria pior.

*Verificado : 16/09 — log do run 7092391 lido por inteiro, rede reproduzida fora da CI em dois ambientes, ticket #17 fechado no verde do relance.*

**O que é.** Não procurar na suíte. Instrumentar a rede: gravar `$out` em ficheiro, testar com `grep -c` no ficheiro (sem tubo, logo sem `pipefail` nem SIGPIPE), e em FAIL imprimir `PIPESTATUS` e `wc -c`. Se voltar, o log dirá qual elo mentiu.

**Por que importa.** Uma CI que fica vermelha sem causa corrói a confiança: na terceira falsa alerta relança-se sem ler, e a verdadeira passa.

**O que conta como terminado.**

- A rede lê a saída de um ficheiro, sem tubo, e um FAIL imprime `PIPESTATUS` e o tamanho da saída.
- Ou o vermelho voltou e o log nomeou a causa, ou três meses sem recidiva.

**Dependências.** Nenhuma.

*Remissões : `scripts/ci/run-sql-suites.sh` · `.forgejo/workflows/sql-tests.yml` · `REGISTRE §0 DOC-SILENCE-1` · `REGISTRE §0 OPS-8`*

---

### J — Documentação e corpus

*O corpus é vasto e sua deriva é medida. Este backlog faz parte dele.*

| | | | |
|---|---|---|---|
| **J2** | Reparar o índice dos backlogs e decidir a convenção de arquivamento | `P2` | Aberto |
| **J4** | `CHANTIERS_OUVERTS` §1: escrever o estado real depois da primeira reconstrução externa | `P2` | Aberto |
| **J9** | Manual v5: o restante das capturas — 180 posições em recuo pt-BR, IMG-31 a refazer, IMG-08 a confirmar, tudo a recapturar em 900-1000 px | `P2` | A verificar |
| **J10** | Sete domínios entraram no v17 sem terem sido arbitrados contra seu custo de conclusão | `P3` | Aberto |

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

#### J4 — `CHANTIERS_OUVERTS` §1: escrever o estado real depois da primeira reconstrução externa

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado.** A entrada 1 dizia « ninguém nunca verificou ». Desde 06/09, alguém verificou. A PR reescreve a entrada como « Validado em 28 de agosto, replay de 218 migrações » — data anterior à PR, número retirado por ele mesmo. Um estado datado foi acrescentado em 06/09 sem tocar no texto.

*Verificado : 06/09 — PR #28 relida por inteiro (46 arquivos, cabeça `b5782ec1`), produção consultada em leitura, constato `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**O que é.** Na volta: o mantenedor reescreve a entrada 1 — o que foi provado, por quem, o que quebrou, o que falta — e decide se « o melhor primeiro passo » continua sendo a entrada 1.

**Por que importa.** Este documento é a porta de entrada dos contribuidores. Escrever « validado » antes de ser verdade manda a próxima pessoa para um canteiro que ela julgará fechado.

**O que conta como terminado.**

- A entrada 1 traz uma medida datada, assinada, e a PR #28 não a reescreve mais.

**Dependências.** Fusão da PR « auto-hospedagem » (I16).

*Remissões : `docs/CHANTIERS_OUVERTS.md` · `REGISTRE §0 DOC-CONSTAT-1` · `REGISTRE §0 DOC-ACTIF-1`*

#### J9 — Manual v5: o restante das capturas — 180 posições em recuo pt-BR, IMG-31 a refazer, IMG-08 a confirmar, tudo a recapturar em 900-1000 px

`P2` Corrente · Estado : **A verificar** · Carga : alguns dias · O que exige : nenhuma competência técnica

**Estado.** O portfólio de 02/09 deixa cinco coisas abertas: 320 posições preenchidas das quais **180 por recuo pt-BR** (sem captura na própria língua para nove locales); **IMG-31** reproduz um pedido de adesão real ainda em análise (Solidaires); **IMG-08** deixa legíveis o endereço e o e-mail da BLMF, «provavelmente deliberado, a confirmar»; o texto fica ≈ 4,5 pt no papel, daí recaptura em 900-1000 px e recorte do fundo; **IMG-20** espera o deploy da correção do seletor de periódico. O manual da leitora v2 de 03/09 reutilizou as mesmas capturas sem essa correção. **Verificado em 07/09 no repositório**: os dez `docs/manual*.md` estão na v1.1 de setembro — essa parte está feita; o branch e o worktree `manualv5` não existem mais — feito também. As capturas em si estão na máquina de Xavier, fora de alcance.

*Verificado : 07/09 — manuais .md na v1.1 e branch removido (feito); capturas não verificáveis daqui.*

**O que é.** Decidir IMG-31 (pedido fictício ou desfoque) e IMG-08; depois uma passagem de recaptura em 900-1000 px, locale por locale, começando pelas que têm leitoras.

**Por que importa.** Um manual que não se consegue ler no papel, e cuja imagem mostra o dossiê de uma biblioteca que espera resposta, não se imprime para Bolonha.

**O que conta como terminado.**

- IMG-31 e IMG-08 decididas, com a razão escrita.
- As capturas relidas legíveis na impressão.

**Dependências.** IMG-31 toca **G7** (não expor uma candidatura em curso).

*Remissões : `claude/MANUEL_v5_portfolio_captures_2026-09-02` · `claude/MANUEL_LECTEUR_v2_refonte_2026-09-03`*

#### J10 — Sete domínios entraram no v17 sem terem sido arbitrados contra seu custo de conclusão

`P3` Adiado · Estado : **Aberto** · Carga : alguns dias · O que exige : nenhuma competência técnica

**Estado.** O levantamento do GLB v17 (01/09) o diz sem ação datada: periódicos, notas de leitura, coleta OAI de entrada, OPDS, sondas, testemunha de backup, fila das convenções — «nenhum foi arbitrado contra seu custo de conclusão». Desde então, H5 (OAI) e I4 (testemunha) estão fechados; os outros cinco estão entregues em parte e não arbitrados.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Cinco linhas: o que está entregue, o que falta para estar pronto, o que custa, e se se termina ou se congela com a razão escrita (`P3`).

**Por que importa.** O congelamento de perímetro (`DOC-GEL-1`) só vale se o que entrou durante o congelamento for julgado — senão não houve congelamento.

**O que conta como terminado.**

- Cinco veredictos no registro ou no backlog, datados.

**Dependências.** Depois de Bolonha. Sem dependência técnica.

*Remissões : `claude/GLB_v17_releve_et_constats_2026-09-01` · `REGISTRE §0 DOC-GEL-1`*

---

### K — Caixa, comunicação, formação

*O que decide se o projeto tem meios e braços, e não apenas código.*

| | | | |
|---|---|---|---|
| **K1** | Fazer adotar a ata de criação do Fundo AnarBib | `P0` | Bloqueado |
| **K2** | Abrir os canais de arrecadação dormentes | `P1` | Bloqueado |
| **K3** | Manter o registro público das contas | `P2` | Aberto |
| **K7** | Conduzir a formação das duas coordenações BLMF até a autonomia | `P1` | Em curso |
| **K8** | Terminar o texto de orientação sobre as ferramentas de bibliotecas militantes | `P2` | Aberto |
| **K10** | Três artigos prometidos ao *Monde libertaire*, um por mês — e um programa proposto à *Trous Noirs* | `P2` | A verificar |

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

#### K7 — Conduzir a formação das duas coordenações BLMF até a autonomia

`P1` Prioritário · Estado : **Em curso** · Carga : várias semanas · O que exige : deliberação coletiva

**Estado.** O material está entregue: 89 slides em português do Brasil, seis módulos, três encontros, seis exercícios práticos, notas de animação em cada slide. Nenhuma das duas pessoas é bibliotecária ou informática.

*Verificado : 07/09 — no banco: a leitora fictícia «Voltairine de Teste» **nunca** abriu sessão (`auth.users.last_sign_in_at` nulo); nenhum exemplar criado desde 01/09, logo o compromisso «nenhum exemplar sem modo de aquisição» ainda não foi provado. O convite BTL em espera saiu em **G14**.

**03/09 — preparação da sessão 1, verificada na base.** Contas das duas coordenações em `blmf-teste` (Rafael G. sem login desde 24/06); as cinco fichas do exercício 2 desde 26/08; **mas nenhum leitor fictício** e **nenhuma regra de circulação** — regras e horários da BLMF copiados em 03/09. Fica com Xavier: convidar dois leitores fictícios, verificar Rafael, decidir a colisão de datas com Bolonha, encontrar o plano e o gabarito (ausentes do repositório). Percurso: `docs/journal/chantiers/PARCOURS_formation_BLMF_seance1_2026-09-08.md`. **03/09, fim do dia — os documentos estão no repositório e o dispositivo mudou.** Plano de 01/09, condutor, roteiro, 89 slides : em `formation-BLMF/`. Sete noites de 2h15, seis módulos, cápsula de 40 min. **O «13/09» não está em nenhum documento** : a primeira noite não tem data ; a «colisão com Bolonha» era um falso alarme. Duas leitoras fictícias criadas em `blmf-teste` (Emma Teste, Errico Teste). A página `docs/journal/chantiers/PARCOURS_formation_BLMF_seance1_2026-09-08.md` foi reescrita como complementos ao condutor. **Noite 1 datada por Xavier : 08/09/2026.** Voltairine de Teste voltou a **leitora** ; Emma e Errico Teste entraram em 03/09.*

**O que é.** Antes do primeiro encontro: criar em `blmf-teste` as duas contas de coordenação, uma ou duas contas de leitura fictícias, e as cinco fichas defeituosas do exercício 2. Depois o acompanhamento de oito semanas: cinco fichas por semana **todas com sua proveniência**, um dia de balcão por semana, uma consulta conduzida de ponta a ponta com negociação real, e o voto do perfil da biblioteca levado à assembleia.

**Por que importa.** Duas pessoas autônomas na coordenação de uma biblioteca é **A1** na escala local. O princípio pedagógico cabe em três palavras — *«cliqua, não vai quebrar nada!»* — e é sustentável porque as transições impossíveis não aparecem, os botões travados vêm pré-desativados com uma explicação, e o banco recusa as combinações impossíveis. Os nove gestos irreversíveis são nomeados explicitamente.

**O que conta como terminado.**

- As oito semanas estão feitas, com o ritual semanal de trinta minutos e suas três perguntas fixas.
- A folha de lacunas alimentada por esse ritual vira a pauta seguinte **e um material de contribuição ao projeto**.
- O compromisso quantificado é cumprido: **nenhuma ficha nova sem modo de aquisição** — a recuperação retroativa das 2 450 fichas sem dado de aquisição não é pedida, só a parada da dívida é.

**Dependências.** Apoia-se em **G3** e **G4** para o ambiente de teste.

*Remissões : `docs/journal/chantiers/formation-BLMF/PLAN_formation_coordination_BLMF_2026-09-01.docx` · `docs/journal/chantiers/formation-BLMF/CONDUCTEUR_seance1_BLMF.pdf` · `docs/journal/chantiers/formation-BLMF/ROTEIRO_capsula_sessao1_BLMF.pdf` · `docs/journal/chantiers/formation-BLMF/Formacao_coordenacao_BLMF_AnarBib.pptx` · `docs/journal/chantiers/PARCOURS_formation_BLMF_seance1_2026-09-08.md`*

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

#### K10 — Três artigos prometidos ao *Monde libertaire*, um por mês — e um programa proposto à *Trous Noirs*

`P2` Corrente · Estado : **A verificar** · Carga : alguns dias · O que exige : língua materna

**Estado.** Sessão de 30/08: o e-mail a Monique e Serge (Radio Libertaire, *Trous Noirs*) escreve «Le Monde libertaire en publie trois articles dans les mois qui viennent, un par mois». **Não verificado**: nem a entrega do primeiro artigo, nem o envio do e-mail, nem a resposta. Nenhum item do backlog carregava esse compromisso.

*Verificado : 07/09 — compromisso encontrado numa sessão, nenhum rastro de acompanhamento em outro lugar.*

**O que é.** Dizer aqui onde estão os três artigos (entregue, revisto, publicado) e se o e-mail saiu; depois manter o ritmo — um artigo por mês é uma dívida que se vê.

**Por que importa.** Uma promessa feita a um jornal militante compromete o projeto tanto quanto um deploy: lê-se nos números em que o artigo falta.

**O que conta como terminado.**

- Três datas de publicação, ou uma renegociação escrita do ritmo.

**Dependências.** Vizinho de **K5**; sem dependência técnica.

*Remissões : `session Cowork « Monde libertaire article publication », 30/08/2026`*

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
| Periódicos P1 a P9 | «Nove pacotes a entregar» | **Os nove entregues em 27-28/08.** Resta a revisão da spec, item **D1**. **Nuance de 02/09: P7 estava entregue, não exercido.** O seletor de título de revista (`SerialAuthorityPicker`) estava no bundle desde 27/08 e **nunca foi montado** na ficha de catalogação — declarado num ponto de extensão (`sectionExtras`) que a ficha não lê para a zona Periódico, cujos campos são renderizados um a um. Seis dias sem que um fascículo pudesse ser vinculado a partir da ficha, com lint, testes e build verdes. Constatado em produção em 02/09, corrigido no mesmo dia (`9d9b7744`), verificado na tela com uma sessão de coordenação, guardado por `src/tests/serial-picker-monte.test.js`; registrado em `spec-periodiques-v1.0-etat-livre`. Mesma família de «declarado entregue, jamais exercido». |
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

**O que o dia custou e ensinou**: três vermelhos na CI, todos do mesmo motivo, e três lições versadas nos arquivos. **Correção na mesma noite, e a lição que faltava ao método.** Três funções fechadas pelas campanhas de 01-02/09 são chamadas por **views `api` em `security_invoker`**, que o front lê no lugar das funções — a view executa suas funções sob o papel de quem a lê, o EXECUTE é necessário, PostgREST devolve 403 sem ele. Constato de Xavier ao preparar as capturas do Manual v5: a aba Círculos da BLMF mostrava «nenhum círculo». As duas medidas eram verdadeiras e a conclusão falsa: **`pg_depend` sabia (`classid = pg_rewrite`)**. Reabertas pela migração `20260902175631` (sessão vizinha); varredura retroativa das 62 fechaduras do dia: nenhuma outra. A checklist pré-REVOKE ganha seu ponto zero: *uma view também chama*. **Fica aberto, fora do perímetro**: a prova real da mensageria espera a primeira candidatura viva — SOLIDAIRES (`DOC-ACTIF-1`: ligado não é provado). |
| J7 | 2026-09-02 | **As linhas vermelhas dos Livros brancos têm agora seus códigos — REGISTRO v0.14.** Três inscrições: **`DOC-GEL-1`** (o congelamento v16, com sua janela de arbitragem), **`DOC-ACTIF-1`** (nenhuma camada ao ativo antes de um exercício real — a prática das encerramentos sob prova torna-se oponível), **`DOC-GLB-1`** (toda linha vermelha de um Livro branco recebe seu código em uma semana, senão é um voto). |
| J8 | 2026-09-02 | **Um só «v17», e é o certo — a série do Grande Livro branco está versada no depósito** (arbitragem de 02/09). O docx de maio arquivado sob nome datado, o **v17 de 01/09 entra em `docs/GLB/`** como referência viva, o INDEX não designa mais um estado de maio. Detalhe: o PDF já tinha saído de Downloads — **reconstituído ao byte (762 814) a partir do transcript da sessão que o leu**. **Fica aberto**: o v16 de 2 de julho segue por encontrar; quando ressurgir, entra em `GLB/archive/` sem outra decisão. |
| B21 | 2026-09-02 | **O contador das chaves estrangeiras sem índice tem sua guarda, e ela mordeu já na primeira volta de CI** (run verde de 02/09). 38 entradas assumidas em três famílias motivadas, cabeçalho com a consulta E seu ângulo morto (`DOC-RECENS-1`). Guardada nos dois sentidos: toda FK nova sem índice avermelha a CI no momento em que a migração se escreve; uma entrada indexada ou desaparecida avermelha também — a lista só encolhe conscientemente. T3 prova a mordida a cada execução. A doutrina v17 está servida: o canteiro não foi «saldado», foi **instrumentado** — e o contador não subirá mais em silêncio. |
| F7 | 2026-09-02 | **Treze segredos vazios, treze vereditos — e só restam dois, de propósito e documentados.** **11 suprimidos** — dez duplicatas de cadeias de fallback cuja variante `ANARBIB_*` preenchida já ganhava, mais `REGIMENTO_URL` por decisão: nenhum regimento de rede está publicado, o ramo morto foi **retirado do código** (três lugares, incluindo uma cadeia mal nomeada que buscava a URL do manual tentando primeiro a do regimento). **2 conservados e documentados**: `BLMF_/BTL_INTERNAL_REDIRECT_EMAIL`, cujo vazio É a configuração — comentário posto em `register/index.ts`, onde são lidos, para que ninguém os «conserte». |
| B18 | 2026-09-02 | **As chaves API legacy estão desativadas — e o sinal verde foi um número, como a ficha exigia.** O medidor refeito de manhã dava: zero `service_role` desde a virada de 01/09, e do lado `anon` **um único user-agent de navegador** (uma aba nunca recarregada) mais o Googlebot repetindo seu cache. Aba recarregada, toggle virado no dashboard (gesto reversível), contraprova nos logs: **zero JWT legacy e zero 401 em 857 requisições vivas**. O código seguiu na mesma hora: fallback retirado de `secret-key.ts` (uma chave morta não merece caminho de código — DOC-SILENCE-1), `.env.example` limpo, vestígio do vault suprimido. A virada `service_role` → `sb_secret` está encerrada de ponta a ponta. **Nuance de 08/09: o encerramento estava certo para o aplicativo, e o aplicativo não era tudo.** O site vitrine `anarbib.org` — segundo repositório, `codeberg.org/anarbib/pages` — carregava a chave anon legacy nos dez `index.html` da sua galeria *Explorar*, que lê `api.public_libraries`: desde o toggle, cada visitante da galeria recebeu um 401 e uma página vazia, **durante seis dias**. O medidor diário viu (4 a 7 requisições legacy por dia de 04 a 07/09) e leu como resíduo de abas, porque o número era pequeno e ninguém tinha pedido o `referer`. Encontrado e consertado na noite de 07 para 08/09 pela sessão do mapa base (vitrine `df9ba40`). O que sai disso é o item **B24** e o cartão `OPS-9` do registro: uma rotação de chave começa pelo inventário dos repositórios que a carregam, e depois de uma desativação o limiar de alerta é um, não cinquenta. |
| G2 | 2026-09-02 | **A divergência P2/P8 está decidida — o texto se alinha ao código, e a forma da decisão importa tanto quanto o fundo.** Opção 1: a prática viva (o circuito colegial que a BTL exerce desde 01/09) vira a regra. Spec v1.11: P2 diz que **a própria execução é colegial**; P8 esclarece a fronteira — os quóruns do código não são votos, são **garantias de execução**: «modelar a deliberação, nunca; exigir várias mãos para executar, sempre». Nenhuma linha de código. **Decisão tomada sozinho, dizendo-o** — modo degradado assumido, datada, `GOUV-18` no REGISTRO, **janela de objeção na noite 1 da formação, em 08/09/2026**: o dia em que o coletivo existir, encontrará uma decisão contestável, não um fato consumado mudo. |
| H5 | 2026-09-02 | **A coleta OAI-PMH está provada nos dois sentidos, com dados reais dos dois lados — e dois circuitos cívicos exercidos pela primeira vez na mesma noite.** **Entrada**: primeira fonte real registrada (Persée, fascículos de sociologia, 2 lotes/ciclo); o disparo manual trouxe **40 fascículos reais**: run `ready_for_review`, trava em `paused`, **token de retomada conservado** — o cron de terça continuará onde a prova parou. **Saída**: o repositório respondia conforme mas vazio; **a BLMF abriu-se pelo circuito real** (pedido → decisão, notificação incluída) e um cliente terceiro colheu **200 registros em dois lotes**, retomada honrada, `GetRecord` exato *(matizado em 07/09: o ensaio era no primeiro registro — a função ignora o identificador pedido, ver **H8**)*. **Dois constatos para Bolonha**: os dois parceiros PMB não expõem `oai2.php` — do lado deles os fluxos nem existem (assunto para H6/K6); e `blmf-teste` falha a elegibilidade nas suas três travas — a receita de biblioteca mascarada resiste até ao OAI. **Nada sobrevive à prova, por decisão de Xavier na mesma noite**: os 40 registros Persée não pertenciam a nenhuma biblioteca real (run ligado à caixa de areia, por isso invisível num contexto de biblioteca comum); run, linhas e fonte purgados pelo caminho próprio — **nenhuma fonte OAI fica armada, o cron de terça nada colherá**. A abertura da BLMF é fechada pela mão de Xavier. A prova, essa, está adquirida. **Fica aberto**: um colhedor verdadeiramente terceiro — Bolonha pode fornecê-lo. |
| B17 | 2026-09-02 | **O aviso imediato das ações transversais está provado de ponta a ponta — inclusive, esta noite, sobre o tipo para o qual foi escrito.** O andar imediato provado em envio real em 31/08 só o fora sobre a promoção colegial — um tipo com três canais. Faltava vê-lo sobre um tipo **sem outro canal antes de segunda**. Feito em 02/09, em transação revertida em `blmf-teste` com uma atriz sintética (admin de rede fixture, não staff da biblioteca — o critério exclui com razão o admin que também é staff local): `fn_team_suspend_member` → membership `suspended`, **linha de outbox `network.cross_library_critical_action` com `action_type=team_suspend_member`**, linha de diário. A perna EF não precisa ser repetida: o handler é agnóstico ao tipo (o tipo só escolhe o rótulo, presente nas dez locales). Sanidade pós-rollback: tudo desaparecido, zero resíduo. |
| G5 | 2026-09-02 | **A bandeira comanda algo real, está posta certo, e a Terra Livre não está em modo de teste.** A ficha olhava `libraries.is_test_mode`: essa coluna **já não existe** — a migração de 30/08 já decidira a outra metade. A bandeira vive em `library_commons.is_test_mode`: **`blmf-teste = true`, as três bibliotecas reais = `false`** (02/09). O que comanda: o **banner «contexto de teste»** nos avisos internos de inscrição — nenhum front a lê, nenhuma policy. O nome não mente sobre o alcance; nada a perguntar à BTL. **Limite escrita**: põe-se na criação e não tem interruptor depois. |
| I14 (config.toml et la CI) | 2026-09-02 | **O ângulo morto já estava fechado — desde 01/09, pelo commit `5e129c54` — e o item não o acompanhou.** `deployer-backend.sh` vigia agora `supabase/config.toml` ao lado de `supabase/functions/`, reimplanta **tudo** quando a configuração muda, e narra o incidente de 01/09 no seu próprio texto. **Provado no banco em 02/09**, localmente, num ramo descartável: um commit tocando só `config.toml` aparece na lista de gatilhos. **Limite escrita (`DOC-ACTIF-1`)**: nenhum push só-config aconteceu desde a correção; a prova real será o próximo. |
| E13 | 2026-09-03 | **Entregue na mesma manhã, commit `18ac8676`.** O painel «Meu pedido» faz três coisas que não fazia: **(1)** uma frase diz o que é; **(2)** um pedido aprovado traz um botão «Ir à oficina de constituição» para `/atelier`; **(3)** uma condição de fim — biblioteca nascida (`completed_at`) ou recusa com mais de trinta dias → o bloco recolhe-se atrás de «Histórico dos meus pedidos». Dez locales, +3 chaves. Banco 362/362. **O olhar externo do circuito completo fica devido** (formação BLMF, noite 1 em 08/09/2026); a fixture Voltairine foi retirada pela sessão das capturas durante a noite. |
| I4 | 2026-09-03 | **A testemunha de proveniência estava pronta desde 20/08 — com outros nomes.** A migração `20260827180000` e o patch `health_probe_provenance.patch` não existem em lado nenhum (procurados em 03/09). Mas o que deviam produzir está **em produção**: `fn_backup_heartbeat_status` expõe `host`, `temoin_amorcage` e `instantane_atteste` (desde `20260820012343`); a `health-probe` **implantada** (fonte relida pela API em 03/09) mostra essa proveniência em cada incidente e e-mail. Forma `DOC-RECENS-1`. Dois fantasmas a não procurar mais. |
| H1 | 2026-09-03 | **As 159 datas estão na base, com rótulo e links — e a prova encontrou um segundo retorno precoce.** O corretivo estava commitado desde 27/08 com o seu teste; faltava a aspiração. Feita em 03/09: as datas saíam com `title_fr` **mas sem links** — a secção dos links vinha *depois* dos retornos precoces. `collectCatalogLinks` passa a ser chamada no início de `parseDescriptor` (`2f314f15`); nova aspiração: 159 datas com rótulo, 147 com links (275). **Sincronização em 03/09** com a semântica do script (upsert por `mot_id`, sem purga), pela base diretamente: 159 novas, 32 atualizadas, 430 inalteradas; `subject_ficedl_links` intacto. A página pública do tesauro só tinha Assuntos e Lugares: **separador «Datas» adicionado** (`d42f54a5`). Fica fora da ficha: `bianco.ficedl.info` não está em `CATALOG_HOSTS`. |
| I16 | 2026-09-03 | **Decidido A e entregue na mesma manhã.** `_shared/deps.ts` fixa `supabase-js@2.114.0` e re-exporta `createClient`; as trinta funções e `env.ts` importam dali. Regra em `CONTRIBUTING.md` e guardada por um banco (`supabase-js-epingle.test.js`). Subir a versão é um gesto datado. |
| C5 | 2026-09-03 | **B, entregue na mesma tarde — e a dívida era o dobro do que a ficha dizia.** O render «autoridade senão transcrição» já era a regra do OPAC ; o formulário só preenche a transcrição, rótulo «autor tal como impresso» em dez locales ; o lote `autor_sans_autorite` existe (`7618ccfc`) : aplicar **põe uma ligação** em vez de reescrever um texto, com anti-sobreposição CONV-O6. **464 livros semeados em produção, não 226** : a ficha lia `book_authors`, tabela derivada ; a verdade vive em `book_contributors`. Suite SQL de 8 testes. O trabalho dos 464 é manual, na Oficina, sem prazo. **Na mesma noite, Xavier decidiu os 464** na Oficina: 446 validados e aplicados (446 ligações, **227 autoridades criadas**), 18 descartados. As 227 autoridades novas são o primeiro objeto da auditoria cadrada em `docs/journal/cadrages/REPRISE_audit_autorites_en_profondeur_2026-09-03.md`. **03/09, noite — a auditoria está feita**: as 227 estão classificadas (98 formas invertidas corretas, 60 formas diretas, 35 mononímios, 48 em maiúsculas, ~20 coletividades sem tipo, 7 menções de função, 8 fichas duplas, `??`, `identificado, Não`); **9 são duplicatas** de fichas corrigidas em 21/08 — a busca de homônimo do lote comparava letra a letra. Corrigido (busca `fn_conv_autorite_homonyme`, sem caixa nem acentos, forma derivada; proposta que lê « identificado, Não »); as 227 vão para os lotes `autorite_casse`, `autorite_collectivite` e para o novo `autorite_forme`; 8 duplicatas exatas são sinalizadas ao Ateliê (os 5 pares de fixtures de formação excluídos). As 333 segundas pessoas ficam: lote por contribuidor a escrever, depois da homonímia. |
| D2 | 2026-09-03 | **A, as cinco — e o único gesto de código está entregue.** Vereditos inscritos em acordo com o código ; lista de sugestões de `periodicidade` (oito valores, dez locales) em `SerialDetailEditor` desde `5f43a247`. |
| E11 | 2026-09-03 | **A — tags fechadas, feed requalificado e entregue no mesmo dia.** `OPAC-TAG1` fechado ; `OPAC-RSS1` requalificado e **entregue** (`e7a8acab`) : Edge Function `rss-novidades`, duas guardas e nada mais (biblioteca pública, vista pública), RSS 2.0, banco de 5 testes, link «Novidades (RSS)» na página pública de cada biblioteca. Sem consulta, sem conta : nada a rastrear. |
| B4 | 2026-09-04 | **Veredicto escrito em 04/09 (`04b5c298`, migração `20260904184501`) : as quatro estão fechadas de propósito.** `author_name_aliases` é lida por seis funções DEFINER e duas vistas ; `library_themes` / `library_theme_configs` passam por `get/set_library_theme_config*` ; `interlibrary_loan_events` só é escrita por `fn_v2_log_emprestimo_interbibliotecas_event`. Cada tabela leva o veredicto em `COMMENT ON TABLE`. O segundo critério já estava cumprido : `bootstrap.sh` lista as 15 tabelas fechadas esperadas. |
| I11 | 2026-09-04 | **`node:22` desde 04/09 (`04b5c298`)** — sete ocorrências nos dois workflows. A CLI Supabase é um binário descarregado por `curl`, nada a reinstalar. Prova : o run 1191 passou `app` e `sql-tests`, `backend` chegou ao `db push` (falhou na guarda de B9, não na imagem) ; o run seguinte (`ea813837`) passou `backend` até ao fim. |
| I8 | 2026-09-04 | **Reescrito em 04/09 (`04b5c298`).** O cabeçalho diz o que correu em 26/08 — três passagens de `bootstrap.sh`, oito defeitos corrigidos, oito etapas mais uma «7 bis» — e o que não correu. `notify-cross-library-digest` fechado (está no repositório), rejogo das migrações feito, `CADDY_TAG=2` justificado ; GoTrue/correio e `PGRST_DB_SCHEMAS` continuam a verificar. |
| E8 | 2026-09-04 | **Fechado em 04/09 com a medida registada — o trabalho era de 06/05.** Antes : dois TTF bloqueantes, ≈ 1,5 MB. Depois : 19 woff2 auto-alojados, 1 296 308 bytes no total, por face e por escrita, todos em `font-display: swap` ; só dois pré-carregados no primeiro render : 81 420 bytes. Nada bloqueia. |
| J6 | 2026-09-04 | **O constato era falso desde 17/05 — `DOC-RECENS-1`.** As cinco doutrinas estão no README (FR/EN) desde `fbe8969b`. Faltava um caminho a partir de `CONTRIBUTING.md` : acrescentado em 04/09 (`04b5c298`) na tabela «conforme o que toca». |
| I10 | 2026-09-04 | **Fechado em 04/09 (`04b5c298`).** `tmp-ficedl/` apagado ; segredo `TURNSTILE_SECRET_KEY` retirado ; `docs/drafts/` tem regra (`README.md` : um sas, não uma reserva — o que entra sai no mês) e foi esvaziado : o rascunho de pesquisa, obsoleto desde 03/07, passou para `archive/`. |
| B9 | 2026-09-05 | **Purgado em 04/09 à noite, por decisão de Xavier após releitura** (`6295f256`, migração `20260904223000`) : o esquema tinha as vinte operações de ensaio da circulação v2, não «zero linhas» — o constato lia `pg_stat_user_tables`, reposto a zero em 02/09. Verificado em 05/09 : o esquema já não existe. |
| B11 | 2026-09-05 | **Encontrado em 05/09 : é o arnês de teste de carga, não um laço do front.** `scripts/loadtest/anarbib-loadtest.mjs` (17/08) escreve de propósito em `user_wishlist`, uma das duas tabelas sem gatilho de e-mail. Desde 02/09 : zero escritas. A linha sai do constato. |
| E7 | 2026-09-05 | **Fechado em 05/09 (`7434c1b6`).** 31 rotas em `App.jsx`, todas com `useDocumentTitle` salvo duas : a página 404 e a página de ensaio OCR. Postas em 05/09 com duas chaves nas dez locales (6 395 chaves, paridade estrita). |
| B7 | 2026-09-05 | **Desambiguadas em 05/09 (`7434c1b6`, migração `20260905132602`).** Todos os apelos vivos são qualificados e visam `ingest.*` ; as três de `public` não eram chamadas por nada e eram DEFINER executáveis por `authenticated` (lint 0029 : 399 → 396). Suprimidas com guarda ; seis testes. |
| OPAC por obra | 2026-09-05 | **Entregue em 04-05/09** (`cac464fd` → `06b928ed`, doze migrações, quatro suítes SQL, Edge Function `work-titles-autofill`): uma linha por obra no OPAC, edições e exemplares por biblioteca desdobráveis, título na língua da leitora (`work_titles`, pré-tradução «corrija-me»), vínculo e fusão de obras na catalogação, abas «Obras cindidas» e «Volumes» do assistente, campo «Tomo / volume», título uniforme na língua da obra. Doutrina no REGISTRO: `OPAC-OEU1..6`, `DEDUP-10`, `THES-4`. O que resta arbitrar é o item **C11**. |
| H8 | 2026-09-07 | **Encerrado em 07/09, no mesmo dia do constato** (migração `20260907120000`, suíte `oai_getrecord_tests.sql` no manifesto). `fn_oai_harvestable_records` aplicava `p_book_id` à contagem e não aos registros: `GetRecord` servia o primeiro registro da biblioteca fosse qual fosse o identificador pedido. A função é reescrita **a partir da definição lida na produção**, com o mesmo predicado nas duas consultas; grants e lista T10 inalterados. A suíte pede o **segundo** registro de uma biblioteca aberta com dois registros (T3) e um identificador desconhecido (T4) — a única forma de teste que vê o defeito. Sem efeito na produção: nenhuma biblioteca aberta, nenhuma fonte registrada. Falta, na próxima abertura real: repetir `GetRecord` num identificador que não seja o primeiro. |
| I20 | 2026-09-07 | **Encerrado em 07/09, no mesmo dia do constato** (migração `20260907123000`, suíte `adresse_des_fonctions_tests.sql`, guarda `migrations-sans-url-cloud.test.js`, `bootstrap.sh` etapa 5 bis + controle (g)). Uma fonte de verdade: o ajuste de banco `anarbib.functions_base_url` (`ALTER DATABASE … SET`, lido na abertura de cada sessão), servido por `private.fn_functions_base_url()` — INVOKER, fechado a anon/authenticated — com fallback no projeto cloud quando o ajuste falta: **a produção não muda de comportamento**. As doze funções são reescritas **por padrão sobre a sua definição real** no momento da aplicação, a partir de uma lista nominativa e fechada. O job cron `anarbib-health-probe` é replanejado por `cron.schedule`. O vitest só aceita o literal nas oito migrações históricas e nesta. `bootstrap.sh` põe o ajuste a partir de `API_EXTERNAL_URL` **nos dois modos** e verifica-o no fim. Não exercido numa pilha real: o domínio I está congelado na produção até 14/09; é o primeiro controle a olhar na próxima repetição (I2). |
| I17 | 2026-09-07 | **Encerrado em 07/09 sobre o constato da experiência do §7** (`journal/operations/NOTE_experience-I17-rejeu-fidele_2026-09-07`), não sobre o código. Em `main` (`c28baac0`), sem a PR #28, imagem `supabase/postgres:17.6.1.136`, volume virgem: com A.1 (`anon` retirado do padrão de *funções* dos **dois** papéis em `01-roles.sh`, entradas verificadas não vazias) e A.2 (migrações sob `postgres`), **310/310 migrações verdes**, incluindo as de 29/08, 30/08, 02/09 e 04/09 sem nenhum `REVOKE` nem tolerância adicionados; 676 funções de `postgres`; **133 funções executáveis por `anon`, hash MD5 idêntico à produção** consultada em leitura no mesmo minuto; `pg_default_acl` sem `anon=` nos dois papéis; T8-T11 verdes. A opção B não precisou ser considerada. Aprendido: o entrypoint processa `initdb.d/*` na ordem do glob, `99-roles.sh` passa **antes** de `migrate.sh`; `cron.job` ausente na 288ª, `CREATE EXTENSION pg_cron` sob `postgres` funciona (→ `I19`). Resta **T7** vermelho: cinco vistas da base legíveis por `anon` no replay, `anon=m` em produção — levado a `B22`. O código A.1/A.2 fica para propor a Bastien após a fusão da #28 (D7). **15/09: A.1/A.2 estão em `main`** — retomados tal e qual por Bastien na #28 (`f179f1ff`), medidos: 133 funções `anon`, MD5 idêntico à produção. |
| E18 | 2026-09-07 | **Constatado e encerrado em 07/09 por Xavier, em `/obra/133`** : seis «edições» idênticas na tela, na ordem VI, V, IV, I, III, II. Os dados estavam certos (`volume` = I a VI): `api.work_public_detail` não servia `volume` e ordenava por ano e título. A lista do catálogo já servia o tomo com o seu badge «Tomo N» — a página Obra era a única superfície a ignorá-lo. Migração `20260907220000` (RPC retomada da definição em produção: `volume` em cada edição, ordem ano → `fn_volume_rank` → título, grants conservados), badge em `WorkPage.jsx` com a chave existente, suíte `oeuvre_tomes_page_tests.sql` (três tomos inseridos III, I, II que devem sair I, II, III). Verificado na tela em `/obra/133` após o deploy. **Segundo gesto na mesma noite, por observação de Xavier** («não são seis edições, são seis tomos de uma só edição»): o cabeçalho ainda dizia «6 edição(ões)». Migração `20260907233000`: a RPC serve `edition_count` e `volume_count` (mesma regra que a lista), o cabeçalho compõe «1 edição · 6 volumes»; T6-T7 na suíte. |
| E5 | 2026-09-07 | **Entregue e em produção na mesma noite — a última exceção antirrastreamento cai, e não pela via que a ficha propunha.** A ficha queria um *relé* de `tile.openstreetmap.org` com cache; a política de ladrilhos do OSM desaconselha proxies e proíbe qualquer pré-carregamento, e um relé manteria a dependência. Feito em vez disso: **um único arquivo PMTiles** (planet Protomaps de 07/09, derivado do OpenStreetMap, ODbL) extraído em **z12 = 18 GB** (medidas a seco: z10 3,7 GB, z11 7,9, z13 36, z14 68, z15 138), depositado no bucket público **`map-tiles`** (criado na base + migração `20260907234500` inerte depois, teto global do Storage subido de 500 MB para 20 GiB pela API de gestão) e lido pelo navegador **por requisições Range** (Storage responde 206 + CORS `*`, verificado). Renderizado no Leaflet vendorizado por **`protomaps-leaflet` 4.0.1** via `src/lib/mapTiles.js`; os três mapas não têm mais nenhuma linha `L.tileLayer`. Guarda CI `src/tests/carte-sans-domaine-tiers.test.js`. `privacy.s6.maptiles` e `federacao.carte.attribution` reescritos nas dez locales. Receita: `scripts/maptiles/README.md`. **Dois limites escritos**: (1) o arquivo está no Storage Supabase — o vazamento de IP para terceiro está fechado, não o perímetro Cloud Act, que cai com **I2** (contar estes 18 GB no disco pedido às Herbes Folles — **I21**); (2) `map-tiles` fica fora do fluxo storage do **BG2**. `ca` e `eo` ausentes do fundo → nomes locais. O fracasso de junho de 2026 lembrado como «os fundos de mapa» era o **Nominatim** (geocodificação), que segue não configurado. Incidente de método: a medida a seco de z15 travou o WSL no teto de 15 GB — `wsl --shutdown` com acordo de Xavier, nada perdido. |
| IMP-20 | 2026-09-15 | **Um lote importado pertence a uma biblioteca de destino — entregue e em produção na mesma noite** (registo §17 `IMP-20`, migração `20260915184154`). Não era um item : era uma pergunta de Xavier de 15/09 — como atribuir os 1 673 rascunhos de Solidaires à sua biblioteca — cuja resposta honesta era « um UPDATE à mão, a refazer a cada admissão ». Feito : `destination_library_id` na fonte, carimbo de `owner_library_id` na promoção, `fn_batch_reassign_library` (administração da rede), coluna « Biblioteca » nos lotes, 21 chaves em dez locales, suite SQL de 12 testes. **O lote Solidaires está atribuído** ; os avisos (sem série de tombos, inativa) dão **E21**. Continua atrás de **G7** e da revisão do lote. |
| I19 | 2026-09-15 | **Encerrado em 15/09, sobre medição.** *(1)* `01-roles.sh` cria `pg_cron` e **para** se falhar; na primeira passagem do entrypoint diz que adia (PR #28, `f179f1ff`). *(2)* `deploy.sh --controle` verifica a extensão e **reproduz `tests/sql/crons_planifies_tests.sql` no `cron.job` real** — a mesma lista da CI, sem cópia; ✓ ou ⚠ com código de retorno 1. Provado em pilha virgem: 38 jobs, suíte verde; job removido → ⚠ rc 1; extensão removida → ⚠ rc 1. |
| E21 | 2026-09-15 | **A série de tombos e a cota de uma biblioteca configuram-se no ecrã ; um lote recebe as suas cotas e as suas classes de arrumação num só gesto — entregue e em produção na mesma noite** (registo §12 `CAT-E17`, migração `20260915201252`). Três gestos, no padrão proposto para os tombos — convenção, pré-visualização, aplicação, rasto : bloco « Numeração » (Biblioteca e Rede ; prefixo único na rede, congelado após uso), « Cotas em falta » num lote (na ordem do lote, a seguir às existentes), « Classificar por rubricas » (rubrica lida onde a importação a deixou — `assunto_local` para Solidaires —, tabela rubrica → código relida pela coordenação). 14 testes SQL, 101 suites verdes. **Fica às pessoas** : o prefixo de Solidaires, as 1 673 cotas, a tabela das 35 rubricas, a ativação, depois a revisão do lote. |
| G7 | 2026-09-15 | **Solidaires está admitida** — decisão de Xavier em 15/09/2026, em modo « só admin », à falta de co-administradores encontrados em Bolonha (registo `RES-D12` alterado, v0.34). Biblioteca ativa, série de tombo `SOL-`, 1 673 rascunhos atribuídos e cotados. O perímetro de admissão (`RES-Q13`) continua para a AG. |
| B19 | 2026-09-16 | **A HS256 está revogada** — gesto de Xavier em 15/09 às 22h14 (20h14 UTC), Settings → JWT Keys → Revoke. **Primeiro controlo, 24 h depois** (tarefa `anarbib-trafic-cles-legacy`, levantamento de 16/09): nenhum 401 numa conexão de usuário — 1 144 respostas 200, 20 em 204, 12 em 206, todos os tokens de sessão em ES256 antes como depois; cruzado com os logs edge: 0 × 401 em `/rest/v1/` em 24 h fora os quatro do bingbot de 16/09 às 15h19 (robô sem chave, nem antiga nem nova). Só resta em HS256 a conta `supabase_admin` de `@supabase-infra/mgmt-api` em `/admin/v1/network-bans/retrieve`, sempre em 200 — a infraestrutura da Supabase, não a aplicação. As três anomalias vistas de passagem não vêm da revogação e têm cada uma a sua causa: os `403` em `DELETE auth_rate_limits` (**B25**, desde maio), os `400` em `GET gazette_submissions` de 15/09 às 21h09–21h11 UTC (o front de GAZ-9 publicado pelo job `app` alguns minutos **antes** de o job `backend` aplicar a migração que acrescenta `staff_edited_at`/`original_*` — a ordem normal da CI, transitório) e os `400` em `POST auth_rate_limits` (**B26**). **Os quatro percursos (conexão, inscrição, recuperação de senha, documento digital) foram testados por Xavier em 16/09: funcionam.** A tarefa `anarbib-trafic-cles-legacy` foi apagada no mesmo dia. |
| B25 | 2026-09-16 | **Entregue em 16/09 à noite** (`af60bc49`, Edge Function `login` reimplantada pela CI às 22h27). Dois clientes: o da chave secreta nunca se conecta (lê, escreve e apaga os contadores), um segundo, criado só para `signInWithPassword`, leva a sessão da pessoa — o `DELETE` de `clearFailures` volta a partir em `service_role`. As chaves são impressões `sha256Hex` (IP, e-mail em minúsculas): mais nenhum endereço nem e-mail na tabela, nem na query string do `DELETE` que atravessa os registos edge. Cada erro do armazém é registado; um contador ilegível fecha (500). Bancada `login-compteurs-haches` (6 testes). **Verificado em produção**: `auth_rate_limits` purgada (52 linhas em claro → 0), restrição `auth_rate_limits_key_empreinte` posta. Falta ver passar a primeira conexão real: um `DELETE` em 204 nos registos edge, mais nenhum `42501` em `postgres_logs`. |
| B26 | 2026-09-16 | **Entregue em 16/09 à noite** (`af60bc49`, migração `20260916201249` aplicada pela CI: prod 321 = repositório 321). `_shared/core/rate-limit.ts` substitui o `hit()` copiado três vezes: janela fixa que recomeça em 1, chave obrigatoriamente uma impressão, **falha fechada** (`frapper` lança, `freiner` responde 500). `geocode`, `submit-cartography-entry` e `submit-gazette-contribution` usam-no; `gazette_email` passa por hash. **Verificado em produção**: a `CHECK` de `kind` lista os sete kinds reais, uma segunda `CHECK` exige uma impressão de 64 hexadecimais, a tabela está vazia (linhas em claro purgadas). Suíte `compteurs_d_abus_tests` (4 testes, na CI) e bancada `compteurs-d-abus-partages` (7 testes); 509 testes JS verdes. |
| F9 | 2026-09-16 | **Levantado em 16/09/2026 às 22h30 (UTC+2), a partir do posto (`nslookup`)** — os três registos existem. **SPF**: `send.notifications.anarbib.org` TXT `v=spf1 include:amazonses.com ~all` (a Resend envia a partir do subdomínio `send.`, é lá que vive o SPF), MX `10 feedback-smtp.eu-west-1.amazonses.com`. **DKIM**: `resend._domainkey.notifications.anarbib.org` TXT `p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC5Uxzm…` (chave RSA publicada, seletor `resend`). **DMARC**: `_dmarc.notifications.anarbib.org` TXT `v=DMARC1; p=none; rua=mailto:admins@anarbib.org` — política de observação com relatórios para as admins, a forma prudente que o item pedia antes de endurecer. Nada a pôr; endurecer para `p=quarantine` é uma decisão à parte, depois de ler os relatórios `rua`. |
| I6 | 2026-09-16 | **Provado em 16/09/2026, na data que o item fixava.** `service_health_probes`: 34 568 linhas, a mais antiga de **17/08 às 20h30 UTC**, a mais recente de 16/09 às 20h25 — e **zero linhas com mais de trinta dias**. O limite inferior avançou trinta dias em trinta dias: a purga integrada em `health-probe` apaga de verdade (o contador `n_tup_del` do `pg_stat`, reposto a zero em 02/09, não podia dizê-lo; a contagem direta diz). `service_health_incidents` não é tocada. Nenhum cron a acrescentar. |
| A2 | 2026-09-16 | **Encerrado em 16/09/2026, decisão de Xavier.** A reconstrução por alguém que não o mantenedor aconteceu: **Bastien** (conta `ASR2026`, primeira contribuição exterior) montou a pilha em casa a partir do repositório só, escreveu-lhe o instalador (`install.sh`, PR #28, **fundida em 15/09** — `f179f1ff`) e registou o que quebrava nos seus commits (`pg_cron` ausente no arranque, esquema a inicializar sob `supabase_admin`, `GRANT` em `supabase_migrations`, `LANG_CODE`, porta 5173…), depois o mantenedor releu e fundiu **a partir dessa instalação**. Os desvios estruturais encontrados têm as suas notas (`CONSTAT_PR28…`, `NOTE_experience-I17…`, `DOC-GRANT-2/3`). O diário de execução como secção de `deploy/README.md` é posto em 16/09. A entrada 1 de `CHANTIERS_OUVERTS` fica a reescrever pelo mantenedor: **J4**. |
| B22 | 2026-09-16 | **Encerrado em 16/09, sobre medição.** 133 funções executáveis por `anon`, 47 sem GRANT escrito. Chamadores procurados antes de qualquer REVOKE. Migração `20260916223000`: 4 aberturas que servem, escritas; 43 fechadas; 5 vistas de T7 com `REVOKE SELECT` escrito. T10 a 26, **T12 = lista fechada das 90 funções executáveis por anon**. Implantado pela CI (`21a98d0e`); **medido em prod: 90 funções, 30 DEFINER, MD5 idêntico ao replay, lint 0028 = 26**. Regra: função que anon deve chamar = GRANT escrito na migração E linha em T12. |
| E12 | 2026-09-16 | **Encerrado em 16/09/2026 por decisão de Xavier (« fecha tudo o que pode sê-lo com razão »)** — os três lotes estavam entregues desde 02/09 (página Importações reestruturada, lotes A-C: dois separadores, exportação ordenada, sem código bruto) e a página tem os seus separadores; o item ficara « em curso » por falta de fecho, não de entrega. |
| C2 | 2026-09-16 | **Encerrado em 16/09/2026 por decisão de Xavier (« fecha tudo o que pode sê-lo com razão »)** — o fundo Solidaires **passou pela ferramenta de importação do repositório** (fonte 17, run 29, lote 63: 1 673 rascunhos), não por `INSERT`; a admissão foi pronunciada antes de tocar no lote de verdade (G7, 15/09, modo « só admin » de `RES-D12`); a chave `assunto_local_sugerido` está presente na carga bruta dos 1 673 rascunhos (medido em 20/09) — que as correções de acentos lá vivam, e que nenhuma tenha sido feita em silêncio noutro lado, **não foi verificado**: a ver na revisão do lote. O que quebrou está registado: `library_without_tombo_pattern` → E21, 91 fascículos e 87 monografias suspeitas → **D3**, nenhum assunto ligado pelo run → rubricas (E21). A releitura de uma amostra faz-se na revisão do lote (`fn_batch_review_report`, relatório admin obrigatório antes de `publish_catalog_batch(63)`). |
| K5 | 2026-09-16 | **Encerrado em 16/09/2026 por decisão de Xavier (« fecha tudo o que pode sê-lo com razão »).** **Retificado em 20/09/2026**: a primeira redação desta linha afirmava factos que a sessão que a escreveu não tinha à vista. O que está estabelecido: o prazo de Bolonha (13/09) passou, e a sequência técnica está aberta à parte (H10-H13; K9 fechado sem objeto). O que **não é atestado por nenhuma peça lida**: que a intervenção aconteceu e que o apelo foi levado, e a lista dos contactos com o que cada um propôs — a nota de memória de Bolonha é de 20/08 e nada diz de 13/09, nenhum ficheiro do diário tem data de 12-14/09. As « notas de sessão de 13-14/09 » citadas primeiro não existem; « CIRA incerto » estava ultrapassado (biblioteca retirada em 31/08). O fecho assenta na decisão de Xavier, que lá esteve. Sobre a acessibilidade, E1 fica. |
| K6 | 2026-09-16 | **Encerrado em 16/09/2026 por decisão de Xavier (« fecha tudo o que pode sê-lo com razão »).** **Retificado em 20/09/2026**: a primeira redação desta linha afirmava factos que a sessão que a escreveu não tinha à vista. O que está estabelecido: existem ficheiros de trabalho no disco `F:` numa pasta chamada « Rencontre Leftove.rs », e o esboço SKOS do tesauro foi regenerado em 09/09 **sobre as respostas da FICEDL de 07/09** (H13 leva-o ao repositório) — não « com » leftove.rs, como fora escrito. O que **não é atestado por nenhuma peça lida**: que o encontro se realizou, que as três perguntas tiveram resposta, e que o ponto da licença (CC BY-NC-SA) foi visto antes — os únicos vestígios « leftove » do repositório são de 26-27/08. O fecho assenta na decisão de Xavier; a digitalização e a NORLA ficam abertas em H6/G8. |
| K9 | 2026-09-16 | **Encerrado em 16/09/2026 por decisão de Xavier (« fecha tudo o que pode sê-lo com razão »)** — **sem objeto**: os quatro textos de Bolonha serviram em 13/09; corrigir números num dossiê de intervenção passado já não tem destinatário. Os números vivos são os de H10-H13, que ficam abertos. |
| I12 | 2026-09-16 | **Encerrado em 16/09/2026 por decisão de Xavier (« fecha tudo o que pode sê-lo com razão »)** — a automatização está feita e provada desde 05/09 (timer systemd de utilizador, 18h02 cada dia, passagens lidas em `journalctl --user`). O que restava — dar um destinatário ao `die` do script e escrever a data no testemunho — é **o mesmo problema que I24**: é lá vertido, para ser resolvido uma só vez com o fluxo `storage`. |
| I13 | 2026-09-16 | **Encerrado em 16/09/2026 por decisão de Xavier (« fecha tudo o que pode sê-lo com razão »)** — medido em 16/09: o site é servido por git-pages, uma rota desconhecida devolve **200 `text/html`**; `public/_redirects` existe, `public/.domains` já não existe, o ramo `pages` já não existe na Codeberg, `public/CNAME` mantido para o espelho GitHub. A limpeza dos segredos Forgejo tornados inúteis é um gesto de Xavier nos ajustes da forja, fora do repositório. |
| I1 | 2026-09-16 | **Encerrado em 16/09/2026 por decisão de Xavier (« fecha tudo o que pode sê-lo com razão »)** — `deploy/.env.example` tem `GOTRUE_TAG=v2.192.0` com a regra « imagem ≥ produção » e o histórico; as passagens de 26/08 mediram **77 migrações GoTrue = a produção exatamente**; a PR #28 reproduziu a pilha nessa imagem. O terceiro « acabado quando » é levantado: a medida direta vale mais do que a lista. |
| G11 | 2026-09-16 | **Encerrado em 16/09/2026 por decisão de Xavier (« fecha tudo o que pode sê-lo com razão »)** — a regra de arranque está **registada**: `GOUV-19`, « ✅ decidido 06/09 (Xavier, Q1: A + B + C + D′) » — arranque único fora do circuito, recusado assim que exista um admin ativo; palavra-passe aleatória em todos os modos, mostrada uma vez; primeira conta = coordenação da primeira biblioteca **e** admin de rede; biblioteca `demo` criada se a tabela estiver vazia. `deploy/scripts/seed-admin.mjs` (PR #28) aplica as quatro, e `deploy/README.md` apresenta-o como o arranque de uma base virgem. |
| J3 | 2026-09-17 |  *(segundo item com o identificador J3 — o da PR #28, 06/09; o primeiro está fechado mais acima)* **Encerrado em 17/09/2026 sobre os factos, decisão de Xavier de 16/09; assinalado pela sessão vizinha em 16/09 à noite.** A PR pages #2 (guia de auto-hospedagem do site vitrine, dez línguas) está **fundida em 16/09 às 22h00** (API Codeberg: `merged: true`), depois da PR #28 (15/09) como a ficha exigia; as quatro frases estão corrigidas e o aviso posto; a releitura D4 foi tomada, e `install.sh` já só promete a Resend (`035853eb`). |
| A4 | 2026-09-17 |  *(segundo item com o identificador A4 — o da PR #28, 06/09; o primeiro está fechado mais acima)* **Encerrado em 17/09/2026 sobre os factos, decisão de Xavier de 16/09; assinalado pela sessão vizinha em 16/09 à noite.** `CONTRIBUTING.md` tem as três regras e a promessa do mantenedor, em francês e em inglês; `DOC-CONTRIB-1` no registo. A PR #28 foi **dividida segundo estas regras** (instalador em #28, código aplicativo em #29, guia vitrine em pages #2) e fundida em 15/09 com conhecimento de causa. A exigência de uma versão portuguesa é levantada: o ficheiro é bilingue FR/EN por construção. |
| I16 | 2026-09-17 |  *(segundo item com o identificador I16 — o da PR #28, 06/09; o primeiro está fechado mais acima)* **Encerrado em 17/09/2026 sobre os factos, decisão de Xavier de 16/09; assinalado pela sessão vizinha em 16/09 à noite.** O objeto do item — **seguir a PR #28 até à fusão** — está atingido: divisão feita (#28 instalador, #29 código aplicativo aberta à parte, pages #2 guia vitrine), os quatro pontos bloqueantes resolvidos, congelamento de 08 a 14/09 mantido, **fusão em 15/09** (`f179f1ff`), pages #2 em 16/09, `GOUV-19` registado (G11 fechado). O terceiro « acabado quando » (`install.sh` executado numa máquina que não é a do autor) não é uma condição da fusão: é uma prova da pilha, vertida em **I21**. A releitura de #29 continua sob o seu próprio número de PR, com F7 e B20. |
| B23 | 2026-09-20 | **Encerrado em 20/09/2026 sobre peça — constato corrigido: não havia nada a fazer.** O « acabado quando » dizia « a vista está em invoker, **ou** tem o comentário que diz por que não está ». `obj_description('api.library_email_identity')` devolve um `COMMENT ON VIEW` completo, assinado « Paquet API-VUES-DEFINER du 29/08/2026 » e emendado em 30/08: identidade de expedição lida pelas funções de e-mail, só `service_role`, nunca concedida a anon nem a authenticated, e a passar a security_invoker no mesmo movimento se um GRANT aplicativo lhe fosse dado. Medido em 20/09: proprietário `postgres`, `reloptions` vazias, só `service_role` tem `SELECT`, nenhuma função nem vista a cita, um único leitor no repositório (`register`, pelo cliente admin). O levantamento de 07/09 só lera `reloptions`, não o comentário. |
| G12 | 2026-09-20 | **Encerrado em 20/09, sobre peças.** *(1)* A frase: REGISTRO `FED-O11` (decidido em 06/09); o guia de auto-hospedagem da vitrine diz isso nesses termos desde `b9c85e6` (dez línguas: «Uma instância, uma rede»), e `deploy/README.md` traz a mesma frase. *(2)* O anuário: decisão datada em `journal/arbitrages/QUESTIONS_pr28_contribution_exterieure_2026-09-06.md` (veredito A de 06/09: não aberto). Nenhum código. |
| B20 | 2026-09-20 | **Encerrado em 20/09, sobre medição.** Duas funções ainda liam `SUPABASE_SERVICE_ROLE_KEY` diretamente (`opds`, `rss-novidades`). Commit `f83c5f66`: ambas passam por `secretKey()`; `src/tests/cle-legacy-garde.test.js` proíbe qualquer leitura da variável legacy (lista fechada vazia); o banco do RSS avalia o verdadeiro `secret-key.ts`; uma frase em `CONTRIBUTING.md`. A guarda fica vermelha em `main` antes da correção e no `secret-key.ts` do topo da PR #28 em 06/09 (`b5782ec1`, l. 26); verde depois, 536 testes. Implantado pela CI no segundo run (`fd5f5a6b`); relido em produção em 20/09: `opds` versão 27 lê `secretKey()`, `/opds/all` devolve 18 entradas, `rss-novidades/blmf` 30. |

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

Backlog v34, escrito em 2026-08-29, atualizado em 2026-09-21. Substitui `AnarBib-Backlog-2026-06-17-v33.md`. 70 itens em 11 domínios. O estado numérico foi levantado em 2026-09-20 contra o banco de produção em somente-leitura e contra o repositório Codeberg no commit `6cf45ef4`; os itens retocados desde então trazem a própria data no seu texto. Este documento não arbitra nada: o `REGISTRE_decisions.md` faz fé.
