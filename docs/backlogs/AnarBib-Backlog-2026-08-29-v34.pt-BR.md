# Backlog AnarBib v34 — Reescrita integral sobre estado verificado — ferramenta de trabalho para as colaboradoras e os colaboradores por vir

**2026-08-29** · atualizado em **2026-10-10** · 55 itens · Version française : `AnarBib-Backlog-2026-08-29-v34.md`

> Arquivo **gerado** por `scripts/build-backlog.cjs` a partir de `backlog-v34.json`. Não o modifique à mão.

---

## Sumário

- [Por que uma reescrita](#por-que-uma-reescrita)
- [Modo de usar](#modo-de-usar)
- [O estado real em 9 de outubro de 2026](#o-estado-real-em-9-de-outubro-de-2026)
- [Desvios levantados entre o real e o escrito](#desvios-levantados-entre-o-real-e-o-escrito)
- [O calendário restrito](#o-calendário-restrito)
- [Dez regras pagas por um incidente](#dez-regras-pagas-por-um-incidente)
- [Os canteiros](#os-canteiros)
    - [A — Sustentabilidade coletiva](#a--sustentabilidade-coletiva) · 2
    - [B — Banco de dados, segurança, RLS](#b--banco-de-dados-segurança-rls) · 2
    - [C — Catalogação e dados documentais](#c--catalogação-e-dados-documentais) · 9
    - [D — Periódicos, efêmeros, recursos digitais](#d--periódicos-efêmeros-recursos-digitais) · 4
    - [E — Front, OPAC, i18n, acessibilidade](#e--front-opac-i18n-acessibilidade) · 9
    - [F — E-mail e notificações](#f--e-mail-e-notificações) · 3
    - [G — Rede, governança, federação](#g--rede-governança-federação) · 6
    - [H — Interoperabilidade, tesauro, coleta](#h--interoperabilidade-tesauro-coleta) · 9
    - [I — Auto-hospedagem, operação, backups, CI](#i--auto-hospedagem-operação-backups-ci) · 4
    - [J — Documentação e corpus](#j--documentação-e-corpus) · 1
    - [K — Caixa, comunicação, formação](#k--caixa-comunicação-formação) · 6
- [Encerramentos e entradas caducas](#encerramentos-e-entradas-caducas)
- [O que não está no backlog](#o-que-não-está-no-backlog)
- [Manutenção deste documento](#manutenção-deste-documento)

---

## Por que uma reescrita

Este documento substitui o backlog v33 de 17 de junho de 2026. O v33 trazia uma faixa de aviso de frescor acrescentada em 28 de agosto; já não bastava.

O v34 não é uma atualização do v33: é uma **reescrita sobre estado verificado**. Na sua redação, em 29 de agosto de 2026, cada afirmação de estado foi relida contra duas fontes primárias — o banco de produção consultado em somente-leitura e o repositório Codeberg no commit `1d00ed2c`. Nenhum item foi transportado com base na fé de um documento. Entre o v33 e aquele dia, 216 das 221 migrações então aplicadas haviam sido escritas, além de 655 commits.

**Este parágrafo conta uma gênese, não um estado.** Os números que descrevem o presente vivem em « O estado real », levantado à parte e datado; ele foi refeito já em 1º de setembro de 2026 — metade dos valores de 29 de agosto havia mudado em três dias — e o é desde então a cada levantamento (o último: 5 de outubro de 2026, à noite). Confundir os dois é exatamente o erro que tornou o v33 inutilizável.

Este trabalho produziu um resultado que comanda a leitura de todo o resto: **a documentação erra nos dois sentidos**. Declara abertos canteiros entregues há semanas, e declara entregues coisas que ninguém jamais exerceu. A seção « Desvios levantados » os nomeia um a um.

---

## Modo de usar

**Este documento não arbitra nada.** A precedência documental do projeto continua sendo a de `docs/INDEX.md`: o `REGISTRE_decisions.md` faz fé, depois a spec do domínio, depois este backlog. Se uma linha daqui contradiz o REGISTRO, é o REGISTRO que tem razão e essa linha é um defeito a sinalizar.

**Para começar sem pedir nada a ninguém**, leia `docs/CHANTIERS_OUVERTS.md`: sete portas de entrada que não exigem nenhuma coordenação. O presente backlog é o que vem depois, quando se quer saber o que falta e por quê.

**Antes de pegar um item, abra uma issue no Codeberg.** Duas pessoas escrevendo a mesma correção é uma noite perdida para uma das duas. É a única regra de coordenação do projeto, e cabe em uma linha.

**Cada ficha diz seis coisas**: o que é, o estado verificado em 29/08, por que importa, o que conta como terminado, o que exige, e do que depende. Se uma faltar, a ficha está incompleta — diga isso em vez de adivinhar.

**Os identificadores nunca são reutilizados.** Um item liquidado guarda seu número e passa para a seção dos encerramentos. As remissões entre colchetes apontam para o REGISTRO, uma spec ou um identificador herdado de um backlog anterior: permitem recuperar o rastro, não fazem autoridade por si mesmas.

---

## O estado real em 9 de outubro de 2026

**Levantamento de 9 de outubro de 2026 à noite** (`47781985`, medido às 22h15 — pedido em `d116d42d`, dois commits depois C17 estava entregue e sua migração aplicada: o levantamento os inclui) — produção consultada só em leitura e repositório recontado; **todas as linhas foram remedidas** (levantamento anterior: 08/10 à noite, `c06f9ed2`). **A CI está em dia com a cabeça do branch**: 454 migrações aplicadas = 454 no repositório, as quatro que esperavam ontem à noite passaram, mais H21 lote 6b, os tomos II e III de *Acción directa* e C17. O que mudou e por quê: **o catálogo** — −3 fichas, todas por fusão (dois tomos reunidos por migração com acordo de Xavier, uma fusão às 21h46), nenhuma criada, quatro retomadas publicadas; **o banco** — +25 funções (H21 lote 6b em `ingest`, C17 com seu registro `tombos_attribues`, a lista dos fios de correspondência), mais duas tabelas fechadas (daí +2 avisos 0008), **0029 em 428, exatamente a contagem esperada pela auditoria**, e a guarda CI dos DEFINER de lista fechada estendida à correspondência (uma porta, três ajudas); **a rede** — a correspondência vive (um fio, duas mensagens, BLMF para BTL), G19 fechado por Xavier; **o repositório** — +12 commits, +40 chaves, +39 testes, +2 suítes SQL, C17 entregue (um número de tombo nunca se redá). **Atualizado nesta versão**: C17 fechado por decisão de Xavier (os dois critérios cumpridos, o olhar na tela levado por E31). **O que falta fechar, e por quem** — *a verificar num fato por vir*: F19 (uma semana de logs, por volta de 15/10), I30 (disparo longo de 11/10 e depois `restore-test`), I33 (um disparo noturno depois de uma migração — a migração desta noite permite), H15, H16 e H28 (uma importação real da DIRA), H26, K10 (duas edições); *na tela*: E31 (E6 lotes 2, 4, 5, 8; E35; telas do H21; a recusa traduzida de um número liberado, C17); *as decisões*: A1 (uma terceira administração de rede); *sem código*: A1, A3 (a máquina do runner), H2 (um e-mail pronto desde 16/09, a enviar), H32 (o aviso ao PMB Services, a enviar).

**Frescor dos constatos em 2026-10-10.** **39 itens de 55** trazem uma verificação datada própria (A1, A3, B36, B38, C3, C4, C18, C29, D3, D8, E1, E2, E4, E6, E20, E31, F10, F19, F25, G1, G6, G8, G10, G15, H2, H6, H15, H16, H21, H26, H28, H29, I2, I21, I30, I32, K2, K7, K10). Os **16** outros ainda repousam sobre o levantamento de 2026-08-29 e são assinalados como tais em cada ficha. Um constato não reverificado não é falso: é apenas velho, e a diferença vê-se aqui em vez de no uso. Esta linha é recalculada a cada geração do documento.

### Banco

| | | |
|---|---:|---|
| Tabelas `public` | **202** | todas com RLS ativado, **364 policies** em todos os esquemas (`public` 314, `storage` 47, `cron` 2, `ingest` 1). +1 tabela desde 08/10 à noite, sem policy: `tombos_attribues`, o registro dos números de tombo já dados (C17, `5a5a94d6`, 09/10 às 21h46) — fechada a `anon` e `authenticated`, escrita só por gatilho, daí um aviso 0008 a mais. |
| Tabelas `ingest` | **13** | todas com RLS; só uma tem policy (`book_import_baselines_select_staff`), as outras 12 não têm (aviso 0008). +1 desde 08/10 à noite: `ingest.exemplar_import_baselines`, a base por exemplar importado (H21 lote 6b, `22a8a8f1`, 09/10 à 1h18), no fluxo longo de backup. O esquema continua fechado a `anon` e `authenticated`. Primeiro disparo longo com `ingest` em 11/10. |
| Views `api` | **68** | Sem mudança desde o levantamento de 08/10. **67 SECURITY INVOKER, 1 DEFINER** (`library_email_identity`, a única tolerada pela suíte `vues_api_definer_tests`). Sem mudança desde 24/09. |
| Funções aplicativas | **1 103** | `public` 769 · `api` 207 · `ingest` 101 · `private` 26. Das quais **829 SECURITY DEFINER** (809 em 08/10, +20). +25 desde 08/10 à noite: vinte e duas do H21 lote 6b em `ingest` (cota e nota de um exemplar comparadas base / AnarBib / arquivo, 16 DEFINER), três de C17 (o número de tombo nunca se redá, com dois gatilhos), `api.fn_correspondance_fils` (G19 lote 4 bis) e os gatilhos dos lotes 3 e 4 da correspondência. |
| Migrações aplicadas | **454** | **454 aplicadas em produção = 454 numeradas no repositório**, todas pela CI (`created_by` vazio; as 57 com autor são anteriores a 24/09). +7 desde o levantamento de 08/10 à noite, que tinha quatro na fila: a correspondência lotes 3 (avisar), 4 (línguas lidas) e 4 bis (lista no banco); os tomos de *Acción directa anarquista* postos a partir do sumário, depois II e III fundidos (09/10 às 8h47); H21 lote 6b; C17. Última aplicada: `20261009194632`. |
| Jobs `pg_cron` | **43** | Sem mudança desde o levantamento de 08/10. ativos — os dois últimos adicionados: `anarbib-consultas-expire-daily` (03h10, um pedido de consulta expira 60 dias após a criação, F1) e `anarbib-purge-untouched-retakes` (uma retomada nunca salva se esquece, C19). Uma instância restaurada os reencontra por `private.fn_crons_replanifier()` (I26). |
| Avisos de segurança | **488** | 0 ERROR · **428** WARN sobre as DEFINER expostas a `authenticated` (0029; 427 em 08/10: +1, `api.fn_correspondance_fils`, veredito escrito no complemento de 08/10 da auditoria — **428 é exatamente a contagem esperada**, verificada também pelo equivalente SQL; as seis portas da correspondência e suas três ajudas fechadas são mantidas desde 09/10 pela guarda CI de lista fechada, `262bf350` e `d116d42d`), **29** sobre as expostas a `anon` (0028; = a lista T10, sem mudança), **1** `search_path` não fixado (0011, `fn_locale_from_idioma`, intencional, B32), **30** INFO «RLS sem policy» (0008; +2: `ingest.exemplar_import_baselines` e `public.tombos_attribues`, fechadas de propósito; 12 tabelas `ingest` e 18 tabelas `public`). |
| Avisos de desempenho | **417** | **391** «índice não usado» (400 em 08/10, 440 em 07/10: os contadores de uso zerados na pane de 07/10 às 20h19 continuam se enchendo, mais nove índices serviram em um dia — nenhum foi adicionado nem retirado por isso), **17** chaves estrangeiras sem índice (todas em tabelas de trabalho, sob a guarda CI de lista fechada), **8** tabelas sem chave primária (`conv_backup` ×6, `import_blmf_*` ×2: tabelas de refugo conhecidas), **1** sobre as conexões do servidor Auth (teto de 10, intencional numa instância MICRO). B36 relê os índices por volta de 28/10, contando desde 07/10. |
| Esquemas de refugo | **1** | Sem mudança desde o levantamento de 08/10. Só `conv_backup` — **sete tabelas**, todas de 20/08 (cópias de `authors`, `author_drafts`, `books`, `book_drafts` e três listas de revisão: caixa, patronímicos, títulos). Carregam a revisão humana de C3/C5 e **não se purgam** enquanto as fichas não forem relidas. |

### Funções Edge

| | | |
|---|---:|---|
| Pastas no repositório | **52** | + `_shared`; sem mudança desde 05/10. F3 fechado em 08/10 (`read-pdf` e `mail-i18n-test` apagadas da plataforma por Xavier, 50 funções implantadas). Inclui o roteador `main`, nunca implantado (I3). As outras implantadas pela CI (marcador `deployed-functions`, em `5a5a94d6` em 09/10 às 21h46 — a fila da CI está em dia com a cabeça do branch na hora do levantamento). |
| Declarações `verify_jwt` | **38** | Sem mudança desde o levantamento de 08/10. **todas em `false`** — contagem das linhas `^verify_jwt = ` em `supabase/config.toml`. O Bearer não prova nada, portanto: cada função verifica quem a chama (segredo compartilhado ou sessão relida). |

### Catálogo

| | | |
|---|---:|---|
| Fichas | **2 569** | 2 762 exemplares, **2 368 obras**, **1 506 autoridades**, **2 660 fundos, nenhum vazio**. −3 fichas desde 08/10 à noite, todas por fusão (`merge_log`): os tomos II e III de *Acción directa anarquista* (BTL e MLEG reunidos sob uma ficha cada, migração de 09/10 às 8h47 com acordo de Xavier, −1 obra), depois 2600 na 1225 em 09/10 às 21h46. Exemplares sem mudança, retomados pelas fichas mantidas. Nenhuma ficha criada desde a 2749 de 07/10 (37 fichas fundidas em dois dias: 2 606 → 2 569). |
| Rascunhos de catalogação | **2 418** | `draft` 1 842, `published` 575, `cancelled` 1 (2 414 em 08/10: +4, quatro retomadas de fichas publicadas fora de lote; o único cancelado continua sendo o 6393, C18). **Quatro lotes**, sem mudança, cada um com sua biblioteca (B30): MLEG 8 (411: 147 em curso, 264 publicados, aberto), BLMF 57 (9, todos publicados, fechado) e 66 «Acervo histórico CCLA» (24: 22 em curso, 2 publicados, aberto, C26), Solidaires 63 (1 673, aberto — falta revisar e publicar); 304 fora de lote. 296 rascunhos são retomadas (`action = update`); nenhum rascunho de atualização por reimportação (H21 lote 4) existe ainda — a DIRA não reimportou. |
| Indexação de assunto | **2 105 / 2 569** | fichas com pelo menos um assunto — **464 sem nenhum** (464 em 08/10: as três fichas fundidas estavam indexadas, a contagem das sem assunto não se move). O que o vocabulário atual não cobre: item C27. |
| Tesauro FICEDL | **621** | Sem mudança desde o levantamento de 08/10. termos (234 lugares, 227 assuntos, 159 datas, 1 misto), **10 locales completas**; **110 alinhamentos** para os assuntos locais. Sem mudança desde 28/09; o esboço SKOS revisado e o raspador off-line esperam (H13). |
| Periódicos | **4** | Sem mudança desde o levantamento de 08/10. títulos, **5 fascículos vinculados**, sem mudança desde 29/09. |

### Rede

| | | |
|---|---:|---|
| Bibliotecas | **6** | **ativas, em 6 linhas**: BTL, BLMF, MLEG, Solidaires, anarchief.org e a biblioteca de formação `blmf-teste` (fixtures em produção). **A correspondência vive**: um fio aberto, duas mensagens (BLMF para BTL, G19 fechado por Xavier em 09/10), e uma biblioteca declarou as línguas que sua equipe lê (lote 4). |
| Contas | **23** | **26** vínculos ativos; **23 linhas** em `auth.users`, **21 confirmadas** (dois convites nunca honrados). Sem mudança desde 05/10. |
| Administrador(a/e)s da rede | **2** | Sem mudança desde o levantamento de 08/10. o camarada (`ASR2026`) está cooptado desde 05/10 — primeiro uso real do circuito de cooptação, que encontrou seis defeitos no caminho (G1, G18). A1 continua aberto: uma terceira pessoa, de outro coletivo, e uma decisão federal tomada a três. |
| Circulação viva | **7 / 21 / 22 / 0** | Sem mudança desde o levantamento de 08/10. empréstimos / reservas / consultas / PEB **sem `archived_at`** — e **nenhum está aberto**: os 7 empréstimos estão «encerrado» (o último, nº 70, de 07/10, devolvido às 20h33), as 21 reservas e as 22 consultas «encerrada», os 3 PEB devolvidos e arquivados. Nenhum movimento desde 07/10 às 20h33. As 22 consultas não têm prazo: a regra dos 60 dias só vale para as novas (F23). |

### Repositório

| | | |
|---|---:|---|
| Commits | **3 256** | +12 desde o levantamento de 08/10 à noite (`c06f9ed2`), contagem feita no espelho nu completo — o clone de trabalho do WSL é raso. A noite e o dia de 09/10: H21 lote 6b (cota e nota dos exemplares, IMP-33 c), os tomos II e III de *Acción directa* fundidos, **G19 fechado por Xavier** (a correspondência está entregue e em uso), a guarda CI dos DEFINER de lista fechada estendida à correspondência (`262bf350`, `d116d42d`: uma porta, três ajudas, 34 → 37 fechadas), **C17 entregue** (um número de tombo nunca se redá, CAT-E21, `5a5a94d6`), e os levantamentos. |
| Arquivos `src/` | **547** | +2 desde 08/10 à noite: as telas do H21 lote 6b e de C17; 186 arquivos de teste em `src/tests`. |
| Chaves i18n | **7 389** | paridade estrita nas dez locales (7 389 cada, guardada na CI). +40 desde 08/10 à noite (7 349): H21 lote 6b (cota, nota, seis vereditos), C17 (o número recusado, o registro). Desde 08/10, nenhum valor mais copiado tal qual do pt-BR em es, it, de, en — guardado na CI (`DOC-I18N-3`, dois caminhos, listas de homógrafos fechadas nos dois sentidos). |
| Testes | **2 352 + 185** | **2 352 testes JS** (vitest, gate bloqueante, 184 arquivos passados e 3 pulados, 5 testes pulados; rodados inteiros em 09/10 às 22h20 sobre `47781985`: tudo verde; 2 313 em 08/10: +39 — H21 lote 6b, C17, a guarda das locales) e **185 suítes SQL** na CI (183 em 08/10: +2 — H21 lote 6b, C17; a suíte dos DEFINER fechados conta agora 37 fechados e 16 portas). |
| Marcadores de dívida | **18** | Sem mudança desde o levantamento de 08/10. dos quais 4 em `src/` — método fixo (`git grep -E 'TODO|FIXME'` fora de `docs/`): 18, como em cada levantamento desde 15/09. Nenhum é tarefa aberta; nomeiam escolhas assumidas. |

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

Os congelamentos de setembro passaram: a cadeia auto-hospedada está descongelada desde 14/09, e as datas de Bolonha (11-13/09) ficaram para trás. A janela atual não tem congelamento; tem encontros, cada um carregado por um item.

| Data | O que se aplica |
|---|---|
| **por volta de 15/10/2026** | F19: reler uma semana de diários de envio após a correção de `register` de 08/10 — nenhum endereço completo. |
| **10/10/2026** | Noite de formação BLMF (K7). Até a última noite, a barra de navegação não muda (E20). |
| **11/10/2026, 20:00** | Primeiro tiro longo com `ingest`, `private`, `api` e os direitos (I29, I30): « Dump long OK », depois `restore-test` e a impressão dos direitos comparada à produção. |
| **por volta de 28/10/2026** | B36: reler nos contadores de produção os índices mantidos sob reserva, e o tempo da chamada medida pelo B33. — os contadores recomeçaram do zero em 07/10 às 20h19 (I32). |
| **depois da última noite de formação** | E20: a barra se agrupa por natureza — Público, Eu, Trabalho. |

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
| **A3** | Tirar o runner de integração contínua da máquina do mantenedor | `P0` | Em curso |

#### A1 — Obter pelo menos duas outras pessoas administradoras de rede

`P0` Estrutural · Estado : **Decisão coletiva** · Carga : não estimado · O que exige : deliberação coletiva, nenhuma competência técnica

**Estado.** Verificado no banco em 29/08: a rede conta com **um único administrador**. As tabelas `network_administrators`, `network_administrator_cooptation_proposals` e `network_administrator_cooptation_votes` estão vazias após algumas inserções históricas.

*Verificado : 31/08 — `network_administrators`: 1 linha. Nada mudou. **05/10 — o camarada (`ASR2026`) foi cooptado**: dois administradores ativos. Primeiro uso do circuito de cooptação. **Falta**: uma terceira pessoa. **05/10, à noite — a PR #32 do camarada** (`ad5fb042`, merge `300b1a69`; seguimento `206b7b77`): `AppIcon` e suas regras (REGISTRE `IDENT-5` a `IDENT-8`). Ícones ainda em emoji: item E32.*

**O que é.** Encontrar e cooptar mais duas pessoas, em dois coletivos diferentes, dispostas a carregar as decisões federais: admissão de uma biblioteca, arbitragem entre bibliotecas, abertura da coleta.

**Por que importa.** É o item que comanda todos os outros. Decisões federais são **deliberadamente adiadas** por não poderem ser tomadas em conjunto — a admissão da Biblioteca SOLIDAIRES em primeiro lugar. Enquanto houver uma só pessoa, o mecanismo de cooptação continua um dispositivo sem uso, e a rede continua suspensa a alguém que pode adoecer.

**O que conta como terminado.**

- Duas pessoas a mais carregam o papel `network_administrator` no banco.
- Uma decisão federal foi tomada em três, de ponta a ponta, com seu rastro em `network_administrator_audit`.
- O circuito de cooptação foi percorrido pelo menos uma vez: proposta, prazo, ratificação.

**Dependências.** Bloqueia **G7** (decisão sobre SOLIDAIRES) e condiciona **A2**.

*Remissões : `docs/CHANTIERS_OUVERTS.md §7` · `REGISTRE §1 RES-D11` · `CALENDRIER_bologne_2026-08-27`*

#### A3 — Tirar o runner de integração contínua da máquina do mantenedor

`P0` Estrutural · Estado : **Em curso** · Carga : várias semanas · O que exige : administração de sistemas

**Estado.** `.forgejo/workflows/ci.yml` e `sql-tests.yml` trazem ambos `runs-on: anarbib-local` — um `act_runner` auto-hospedado no WSL2 do mantenedor. Máquina desligada, **nada se implanta**, e a falha às vezes é silenciosa. **28/09 —** medido: em 27/09 às 22h40 o portátil entrou em suspensão durante um job `app`; a tarefa foi dada como falha às 23h45, o `backend` nunca correu, uma migração esperou até ao push do dia seguinte, sem aviso. Os runners hospedados da Codeberg não servem (10 min por job, sem Docker). Três gestos sem máquina: `deploy/ops/RUNNER.md` (procedimento para quem não o instalou, mudança de máquina sem corte), a sonda `ci_en_retard` do `health-probe` (uma leitura por hora das tarefas da forja, e-mail «o que fazer: religar, verificar, relançar»), `deploy/runner/compose.yml` (runner em contêiner). Falta a máquina: Xavier tenta o outro portátil. **Implantado em produção em 28/09 às 12h48** (migração pela CI, nenhum incidente) — depois de dois pushes de código que a Forgejo saltou sem um vermelho porque um commit do lote trazia `[skip ci]`; o hook `.githooks/pre-push` recusa agora esse lote misto para a Codeberg.

*Verificado : 31/08 — 7 ocorrências de `runs-on: anarbib-local`. Nada mudou. **28/09, produção** : migração `20260928095045` aplicada pela CI, CHECK alargada a `ci_en_retard`, health-probe implantado; primeiro tique horário às 13h05: a sonda não abriu incidente — a cadeia estava em dia. Três dos quatro critérios cumpridos; falta a máquina, decisão de Xavier. **27-28/09** — `4ac70cc0`: a suíte `ci_en_retard_kind_tests` testa a CHECK dos incidentes contra o banco (o kind `ci_en_retard` aceito, um kind desconhecido recusado, os antigos mantidos), e os logs Docker do runner em contêiner giram (3 × 10 MB). O hook `.githooks/pre-push` vem de `1737bee9`, limitado à Codeberg por `8bf62c1d`. `51f6dcd9` (27/09): o teste do script de implantação (`deployer-backend-marqueur.test.js`) ficava vermelho a cada `npm test` no Windows (9 casos, código 127), porque ali `bash` abre o WSL; agora usa o Git Bash, ou é pulado sem ele, e a CI Linux mantém `bash`. **01/10** — dois runs quebrados pela parada do posto (o de F17 ficou « em curso » 11 horas). A CI vive e morre com a máquina do mantenedor. O commit da sonda `ci_en_retard`, de `RUNNER.md` e de `compose.yml` (28/09) é `afdb81a2`.*

**O que é.** Rodar o runner em outro lugar que não uma estação de trabalho pessoal: máquina do provedor, segunda máquina da rede, ou runner compartilhado. A lógica de implantação já está extraída em `scripts/ci/deployer-backend.sh` e é reexecutável à mão — metade do trabalho está feita.

**Por que importa.** Enquanto o runner for único e pessoal, nenhum procedimento pode tornar a implantação confiável, e ninguém mais pode integrar uma contribuição. É a segunda metade da dependência de uma só pessoa, depois de **A1**.

**O que conta como terminado.**

- Um push em `main` dispara uma implantação sem que a máquina do mantenedor esteja ligada.
- A guarda de exclusão do roteador `main` é preservada nos dois lugares (workflow e script).
- O procedimento de recolocação do runner em funcionamento está escrito para quem não o instalou.
- Uma falha do runner é vista: e-mail «cadeia de implantação atrasada» em até três horas (sonda `ci_en_retard`, 28/09).

**Dependências.** Ligado a **I2** (migração auto-hospedada). Pode ser feito antes, na infraestrutura atual.

*Remissões : `CLAUDE.md, piège connu n°1` · `REPRISE_bascule_autohebergee_2026-08-26`*

---

### B — Banco de dados, segurança, RLS

*197 tabelas `public`, 800 funções SECURITY DEFINER, 360 policies (07/10). A maior superfície do projeto.*

| | | | |
|---|---|---|---|
| **B36** | Reler, com os contadores de produção, os índices mantidos com ressalva | `P3` | Aberto |
| **B38** | Um exemplar «somente equipe» pode ser reservado, convertido em empréstimo e ir para PEB: quatro funções de circulação não filtram `visibility` | `P2` | Aberto |

#### B36 — Reler, com os contadores de produção, os índices mantidos com ressalva

`P3` Adiado · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** O B10 (27/09) retirou 22 índices e manteve outros com ressalva. **22 redundantes ainda usados** (até 10,8 milhões de varreduras em `book_holdings_book_id_idx`) estão nomeados com seus contadores em `index_redondants_garde_tests.sql` (`af98dee8`): retirá-los deslocaria planos quentes para o índice que os cobre, a medir antes de decidir. **108 índices estavam a zero varreduras**, fora chaves estrangeiras e redundantes: 12 retirados (`3ac1c910`), os outros mantidos, com veredito, em `docs/journal/audits/AUDIT_performance_B10_2026-09-27.md`. O B32 (28/09) tornou usáveis os índices das visões materializadas do catálogo; três continuam sem varredura no seu levantamento (`autor_norm_trgm_idx`, `library_slug_idx`, `titulo_trgm_idx`). Esses encontros só viviam nos fechamentos do B10 e do B32.

*Verificado : [object Object],[object Object]*

**O que é.** Por volta de 28/10, reler `pg_stat_user_indexes` em produção — contadores zerados no reinício de 02/09 (B9): datar o levantamento e anotar qualquer reinício desde então. Para cada índice nomeado acima: mantê-lo, com motivo escrito, ou retirá-lo por migração, com motivo escrito, como no B10 e no B33. Para os 22 redundantes usados, comparar os planos das consultas que os usam com o índice que os cobre antes de qualquer retirada.

**Por que importa.** Um índice sem leitor custa uma escrita a cada inserção; um índice retirado por engano faz uma consulta quente cair em varredura sequencial. Decidir sobre um mês de leituras em produção, não sobre uma bancada.

**O que conta como terminado.**

- Cada índice nomeado em v tem seu veredito escrito, datado do levantamento.
- Os índices retirados o são por migração; nenhuma chave estrangeira perde seu índice, e `index_redondants_garde_tests` está atualizado.

**Dependências.** Adiado de propósito: um mês de contadores de produção depois do B32 (implantado em 28/09), não antes de 28/10.

*Remissões : `docs/journal/audits/AUDIT_performance_B10_2026-09-27.md` · `docs/journal/audits/AUDIT_catalogue_grande_echelle_B32_2026-09-28.md` · `tests/sql/index_redondants_garde_tests.sql` · `clôtures B10 et B32`*

#### B38 — Um exemplar «somente equipe» pode ser reservado, convertido em empréstimo e ir para PEB: quatro funções de circulação não filtram `visibility`

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL

**Estado.** Constatado em 09/10: quatro funções de circulação não filtram `visibility = public`; um exemplar «somente equipe» pode ser reservado ou emprestado. Nenhum em produção hoje.

*Verificado : 10/10 — aberto por constatação do lote 7 de H21, a pedido de Xavier.*

**O que é.** Adicionar o filtro de visibilidade às quatro funções; testes e mutantes.

**Por que importa.** Um exemplar de arquivo reservado à equipe não deve sair por um caminho desviado.

**O que conta como terminado.**

- As quatro funções evitam um exemplar `staff_only`.
- Um teste por função.

**Dependências.** Nenhuma.

*Remissões : `supabase/migrations` · `tests/sql`*

---

### C — Catalogação e dados documentais

*A dívida aqui não é de código: são fichas para revisar uma a uma.*

| | | | |
|---|---|---|---|
| **C3** | Conduzir a revisão humana das autoridades: sobrenomes, caixa, títulos | `P1` | Aberto |
| **C4** | Preencher os países ausentes das fichas de autoridade (674 de 1 505 em 27/09) | `P2` | Aberto |
| **C15** | Corrigir oito registros da BTL, com o livro na mão | `P2` | Aberto |
| **C16** | Atribuir as capas postas antes de 27/09 | `P2` | Aberto |
| **C18** | Revisar catorze aproximações de obras: uma mesma obra dividida em duas fichas? | `P2` | Bloqueado |
| **C26** | Revisar e publicar os 24 rascunhos do acervo histórico do CCLA (BLMF) | `P2` | Aberto |
| **C27** | Indexar as notícias que o vocabulário de assuntos não cobre | `P2` | Aberto |
| **C28** | Decidir três pares de notícias que o DEDUP-14 fez aparecer | `P2` | Aberto |
| **C29** | Os exemplares de uma notícia se criam, se editam e se publicam a partir da notícia | `P2` | Em curso |

#### C3 — Conduzir a revisão humana das autoridades: sobrenomes, caixa, títulos

`P1` Prioritário · Estado : **Aberto** · Carga : várias semanas · O que exige : biblioteconomia

**Estado.** As 19 migrações `conventions_*` estão aplicadas desde 21/08: os referenciais estão normalizados, as mecânicas seguras foram passadas, a fila de verificação existe e o aplicativo permite trabalhar nela. **O que resta é a parte que nenhuma máquina faz.**

*Verificado : [object Object],[object Object],[object Object],[object Object]*

**O que é.** Retomar as três tabelas de revisão do esquema `conv_backup` — `titres_a_revoir_20260820` (211), `autorites_casse_a_revoir_20260820` (1 274), `autorites_patronyme_a_revoir_20260820` (22) — e tratá-las ficha por ficha a partir da Oficina de autoridades.

**Por que importa.** Dos 22 duplos sobrenomes hispânicos apontados automaticamente, **três são falsos positivos conhecidos** (Mechoso, Borges, Marcos): 14 % de erro. E dos 13 pontos de acesso sobre partícula, **quatro estão corretos** (Van der Walt, De Amicis, Di Paolo, De Greef). Um script que «terminasse» esse trabalho introduziria erros num catálogo que não os tem.

**O que conta como terminado.**

- As três tabelas são esvaziadas por validação humana, não por script.
- **Proibição absoluta**: descomentar o SQL de aplicação, completá-lo, ou passar `valide = true` em massa.
- Os 9 pontos de acesso postos sobre um sufixo de filiação — tipo `FILHO, Fábio Luz` — são tratados primeiro: a auditoria os dá como **o defeito mais grave do lote**.

**Dependências.** Faz-se no aplicativo, sem migração. É um canteiro de biblioteconomia, aberto a quem sabe catalogar.

*Remissões : `AUDIT_conventions_catalographiques_2026-08-20` · `REGISTRE §37 CONV`*

#### C4 — Preencher os países ausentes das fichas de autoridade (674 de 1 505 em 27/09)

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia

**Estado.** **Em 29/08, 722 fichas de 1 305 (55 %) não tinham `country`; em 27/09, depois de três passagens (Wikidata `b418e149`, Library of Congress `abaa4755`, IdRef `62553dc6`), 674 de 1 505 (45 %).** Ora, é `country` que comanda a regra de entrada do nome: sem ele, a detecção dos duplos sobrenomes hispânicos só vê uma fração dos casos. Os 22 apontamentos são um **piso**, não um total.

*Verificado : [object Object],[object Object],[object Object],[object Object],[object Object],[object Object],[object Object]*

**O que é.** **Decisão de Xavier em 08/10: enriquecimento Wikidata / LC / IdRef, proposto em revisão** — país de autoridade externa quando a identidade é segura, posto como proposta na Oficina, nunca de ofício.

**Por que importa.** É o pré-requisito duro de toda a cadeia de convenções: `CONV-7` faz de `country` em ISO 3166-1 α-2 uma condição, e `CONV-3` faz a caixa ser comandada pela língua. Um catálogo com 45 % sem país (27/09) aplica as próprias regras pela metade.

**O que conta como terminado.**

- A proporção de fichas sem `country` caiu abaixo de 20 %.
- A detecção dos duplos sobrenomes foi reexecutada e a nova lista passou por revisão humana.

**Dependências.** Pré-requisito da segunda passagem de **C3**.

*Remissões : `AUDIT_conventions_catalographiques_2026-08-20 A5` · `REGISTRE §37 CONV-7`*

#### C15 — Corrigir oito registros da BTL, com o livro na mão

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : biblioteconomia

**Estado.** A busca de capas trouxe à tona dados errados, levantados em produção em 28/09 (`docs/journal/chantiers/LIVRAISON_capas_2026-09-27.md`). **Seis anos impossíveis**: BTL-TL-002174 `0187`, BTL-TL-002032 `0193`, BTL-TL-000065 e BTL-TL-001935 `0200`, BTL-TL-002053 `8000`, BTL-TL-002278 `2200` — este último também tem um local onde grudou uma linha de colofão, com um ISBN incompleto. **Um ISBN com dígito verificador errado**: BTL-TL-000503. Soma-se BTL-TL-002335, vista na tela em 27/09: descreve a edição Ramparts Press de 1971 e traz o ISBN da edição AK Press de 2004 (`027e6903`). Os dois «ISBN compartilhados» do mesmo levantamento não são erros: são pares BTL/BLMF de uma mesma edição (`DEDUP-8`).

*Constato de 29/08, não reverificado desde então.*

**O que é.** Registro por registro, no formulário, com o livro na mão: ler o valor no livro, corrigir, publicar. **Nunca por migração**: uma migração adivinharia (decisão de Xavier de 28/09). Os valores «prováveis» da nota de entrega são pistas, não correções.

**Por que importa.** Um ano `8000` ou `0187` distorce a ordenação por ano e o filtro por data do OPAC; um ISBN de outra edição faz propor a capa dessa outra edição. Só quem tem o livro na mão pode decidir, e a lista hoje só vive numa nota de entrega: nada diria quando ela está resolvida.

**O que conta como terminado.**

- Cada um dos oito registros está corrigido, ou seu valor confirmado no livro.
- Nenhuma correção é feita por migração.

**Dependências.** Ter os livros na mão (acervo da BTL); Xavier, no formulário.

*Remissões : `docs/journal/chantiers/LIVRAISON_capas_2026-09-27.md (« à corriger dans le formulaire, livre en main »)` · `REGISTRE §43 CAPAS` · `commit 027e6903 (BTL-TL-002335)`*

#### C16 — Atribuir as capas postas antes de 27/09

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia, SQL / PostgreSQL

**Estado.** A spec das capas (§4.3) faz da atribuição — a fonte e a licença de cada capa — uma exigência ética e de conformidade. **Medido em 27/09 em produção: 0 capa atribuída entre os 250 registros publicados que têm uma, e 0 entre os 132 rascunhos no mesmo caso.** O formulário não punha o par no rascunho (`fd5d2f0e`), e nem a publicação nem a retomada o copiavam (`76c6ae3f`, migração `20260927130518`). Desde então, procedência e licença seguem a imagem em par (`CAPAS-4`) — só para as capas postas depois de 27/09: nenhuma migração retoma o estoque. E o Inventaire não diz a licença das suas imagens: fica nula, «a verificar» (`2a80d43b`).

*Constato de 29/08, não reverificado desde então.*

**O que é.** Levantar quantas capas publicadas continuam sem procedência. Depois escrever uma regra para o estoque, decidida por Xavier: uma procedência recuperada onde um rastro a dá, senão «desconhecida», posta e assumida por escrito. Para as imagens do Inventaire, verificar a licença na fonte, ou assumir sua ausência por escrito.

**Por que importa.** Uma capa é a imagem de um terceiro: sem a fonte, não se pode nem creditá-la nem retirá-la se pedirem. A regra em par vale para as capas novas; o estoque de antes de 27/09 continua mudo, e nenhum item o carregava.

**O que conta como terminado.**

- Cada capa publicada tem uma procedência, ou um motivo escrito para não ter.
- A licença das imagens do Inventaire está verificada, ou sua ausência assumida por escrito.

**Dependências.** Nenhuma: a regra em par (`20260927130518`) está em produção.

*Remissões : `docs/specs/archive/spec-module-capas.md §4.3` · `REGISTRE §43 CAPAS-4` · `docs/journal/chantiers/LIVRAISON_capas_2026-09-27.md` · `commits fd5d2f0e, 76c6ae3f, 2a80d43b`*

#### C18 — Revisar catorze aproximações de obras: uma mesma obra dividida em duas fichas?

`P2` Corrente · Estado : **Bloqueado** · Carga : alguns dias · O que exige : biblioteconomia

**Estado.** Levantado em 01/10 (somente leitura): catorze pares de obras do mesmo autor·a em que um título «auto» de uma é o título real da outra. Em geral, traduções de uma mesma obra em duas fichas (Reclus 133/880/1131, 268/1387/1203; Kropotkin 19/2381, 79/396, 1/1084, 115/386; Tolstói 28/1297; Gori 48/873; Safón 99/2428; Horowitz 74/2484). Casos a decidir: Nettlau 2036/196 e Kropotkin 1366/2064 (coletânea contra texto único).

*Verificado : 01/10 — levantamento em produção: 14 pares; nada modificado. **05/10 — arbitrado por Xavier, aplicado** (`c923fdc0`, migração `20261005071913`): oito obras reunidas (Kropotkin ×4, Gori, Safón, Horowitz, Reclus); os seis tomos Maucci juntam-se aos de 1905 (obra 133); FCE 1986 e Imaginário ficam à parte com nota; notícia 143 no recueil 2064. Resta: Tolstói 28/1297, Nettlau 2036/196, notícias duplicadas 2601/1195 e 143/138. **05/10 — duas notícias duplicadas fundidas** (`176e6894`): 1195 → 2601 (Nettlau, cota MLEG-0144 mantida), 143 → 138 (Kropotkin, dois exemplares BTL; etiqueta do BTL-TL-EX-000142 a refazer). Resta: Tolstói 28/1297 e Nettlau 2036/196. **05/10 — bloqueado**: Tolstói 28/1297 aguarda a BTL (sumário de *La Insumisión*, BTL-TL-000156); também FCE 1986 (BTL-TL-001131) e etiqueta do BTL-TL-EX-000142. Nettlau 2036/196 aguarda a página de créditos (« Título original ») do exemplar BLMF 0000083 da Hedra. **05/10 — Nettlau resolvido: obras distintas** (`a6dec157`): a ed. Hedra é uma seleção organizada por Frank Mintz (página de créditos, exemplar BLMF 0000083); notas em 2036 e 196. Resta só Tolstói 28/1297, aguardando a BTL. **05/10, à noite** — o rascunho obsoleto 6393 da notícia 2287 é descartado (`e60e34a7`, migração `20261005115704`): desfaria a correção de Xavier (rascunho 6398, publicado). Em produção, a 2287 nomeia Max Nettlau, Frank Mintz (organização) e Plínio Augusto Coelho (tradução) — a nota correspondente está resolvida.*

**O que é.** Revisar cada par com as edições; reunir as que são a mesma obra; para as outras, fazer como para 1163.

**Por que importa.** Uma obra dividida aparece duas vezes no catálogo por obra; um resumo fundido na íntegra faria reservar um pelo outro.

**O que conta como terminado.**

- Os catorze pares decididos por quem cataloga, não por script; cada par mantido distinto tem sua nota.

**Dependências.** Faz-se no aplicativo.

#### C26 — Revisar e publicar os 24 rascunhos do acervo histórico do CCLA (BLMF)

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia

**Estado.** Em 05/10, C24 vinculou os arquivos sem recurso do espaço público: 24 rascunhos pré-preenchidos formam o lote 66 « Acervo histórico CCLA — PDF a catalogar » da BLMF (25 arquivos, cessão do CCLA; migração `20261005123453`, `66cf8d9b`). A correspondência bibliográfica está por validar. **Medido em 05/10 à noite**: 22 em `draft`, 2 publicados (notícias 2747 e 2748), lote aberto.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Rascunho por rascunho, com o PDF aberto: validar descrição, contribuições e direitos, publicar ou descartar; fechar o lote quando vazio.

**Por que importa.** Esses documentos estão online sem notícia pública: ninguém os acha no catálogo enquanto o rascunho não for publicado.

**O que conta como terminado.**

- Os 24 rascunhos do lote 66 estão publicados ou descartados, cada um com sua razão.
- O lote 66 está fechado.

**Dependências.** Uma pessoa que cataloga na BLMF.

*Remissões : `clôture C24` · `migration 20261005123453 (66cf8d9b)` · `lot 66 (catalog_batches)`*

#### C27 — Indexar as notícias que o vocabulário de assuntos não cobre

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia

**Estado.** C7 (27/09) indexou 851 notícias no vocabulário existente e deixou de lado as de assunto fora dele (literatura geral, filosofia, ciências sociais, esperanto, espiritualidade, história do Brasil): 466 naquele dia. **Medido em 05/10 à noite**: 463 notícias de 2 607 sem nenhum assunto.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Ler as notícias sem assunto por grandes conjuntos; propor termos e atribuições numa ficha validada por Xavier, como a do C7; fora do tesauro FICEDL, sem criar fork.

**Por que importa.** Uma notícia sem assunto não aparece em nenhuma faceta nem navegação por assunto: quase um sexto do catálogo é invisível por esse caminho.

**O que conta como terminado.**

- Uma ficha de propostas é validada por Xavier.
- O número de notícias sem assunto é remedido e anotado aqui.

**Dependências.** Xavier, para a validação.

*Remissões : `clôture C7` · `docs/journal/arbitrages/C7_propositions_matieres_2026-09-27.md`*

#### C28 — Decidir três pares de notícias que o DEDUP-14 fez aparecer

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : biblioteconomia

**Estado.** Em 28/09, o `DEDUP-14` (`8e0fe538`) fez propor quatro pares até então mascarados pela obra. **Medido em 05/10**: 504/727 fundido em 28/09; restam três, sem veredito: BTL-TL-000301 / BLMF 0000054 (291 e 2264), BTL-TL-001525 / BLMF 0000258 (1432 e 2446), BTL-TL-001808 / BLMF 0000060 (1699 e 2267).

*Constato de 29/08, não reverificado desde então.*

**O que é.** Para cada par, abrir a lista das edições e decidir: « Mesma edição: fundir » (`DEDUP-13`), ou manter as duas e dizer por quê.

**Por que importa.** Duas notícias para uma mesma edição duplicam o catálogo público; duas edições tomadas por uma perderiam uma descrição.

**O que conta como terminado.**

- Cada um dos três pares está fundido ou declarado distinto, com a razão escrita.

**Dependências.** Xavier, na tela; os livros na mão se o ISBN não bastar.

*Remissões : `commit 8e0fe538` · `REGISTRE DEDUP-13, DEDUP-14` · `merge_log`*

#### C29 — Os exemplares de uma notícia se criam, se editam e se publicam a partir da notícia

`P2` Corrente · Estado : **Em curso** · Carga : alguns dias · O que exige : React / JavaScript, SQL / PostgreSQL

**Estado.** Decidido em 10/10 com Xavier, sobre este diagnóstico: o exemplar vive longe da notícia (aba « Indexação », formulário de 948 linhas em cinco etapas planas, lista « meus cem últimos rascunhos »); a ficha nunca mostra seus exemplares juntos; mudar a localização de um exemplar publicado leva seis gestos e um rascunho; a biblioteca se diz de duas formas; dois caminhos de criação. Mesma receita do depósito digital (05/10). **Lote 1 entregue em 10/10 (`0e78be83`)**: `ExemplaresPanel.jsx`, montado na ficha depois dos recursos digitais — exemplares publicados e rascunhos vivos, por biblioteca, as minhas primeiro e editáveis, as outras só leitura; « Novo exemplar » e « Editar » abrem o editor existente já apontado; um exemplar que já tem rascunho de atualização propõe « Retomar » em vez de abrir um segundo. De passagem: pedir de novo um exemplar da MESMA ficha não relançava o alvo — agora leva um nonce. **Lote 2 entregue em 10/10 (`1820b2e1`)**: « Novo exemplar » abre no painel um formulário curto em quatro tempos — onde (lista fechada das bibliotecas em que se é da equipe; uma só → escolhida de antemão), localização (número proposto por `fn_next_tombo`, editável), circulação e visibilidade herdadas da ficha, detalhes dobrados. « Salvar e publicar » cria o rascunho e chama `publish_exemplar_draft` tal como está; recusa → o rascunho fica e a lista o mostra.

*Verificado : [object Object],[object Object]*

**O que é.** Quatro lotes. *(1)* O painel « Exemplares » na notícia, em leitura, que leva ao editor já apontado. *(2)* O formulário curto no painel, só criação, em quatro tempos que se abrem um após o outro: onde, arrumação, circulação e visibilidade herdadas, e um painel dobrado. *(3)* « Editar » um exemplar publicado sem ver o rascunho: uma RPC encadeia rascunho, atualização e publicação numa transação, chamando `publish_exemplar_draft` tal como está. *(4)* O painel substitui `InitialCopiesBlock`; a aba guarda a massa e deixa de ser a porta de entrada.

**Por que importa.** Arrumar um livro recebido é o gesto mais frequente de uma biblioteca de bairro, e é hoje o que pede mais cliques e mais saber sobre a ferramenta. As guardas existentes (B29, B30, tombo único, detenção por biblioteca) ficam todas: muda-se o caminho, não as regras.

**O que conta como terminado.**

- Da ficha, veem-se todos os exemplares por biblioteca, publicados e em rascunho, e chega-se ao editor num clique (lote 1 — feito em 10/10).
- Um exemplar se cria sem sair da ficha, em quatro tempos; o texto livre « Biblioteca » sumiu (lote 2 — feito em 10/10).
- Mudar a localização de um exemplar publicado é um gesto: a RPC encadeia rascunho, atualização e publicação, provada por uma suíte SQL (lote 3).
- Um só caminho de criação: o painel substitui os exemplares iniciais (lote 4).
- Visto na tela por Xavier, conectado (E31).

**Dependências.** Nada para os lotes 1 e 2 (só front, dez locales de saída). O lote 3 pede uma migração, sua suíte SQL e seu « Complemento » na auditoria das DEFINER. O lote 4 toca `publish_book_draft`.

*Remissões : ``ExemplaresPanel.jsx`, `c29-exemplaires-dans-la-notice.test.jsx`` · ``DigitalResourcesPanel.jsx` (le modèle, 05/10)` · `items B29, B30, C17, E6 lot 6 et lot 8` · `E31 (regard à l’écran)` · ``scripts/i18n-add-c29-lot2-formulaire-court.cjs``*

---

### D — Periódicos, efêmeros, recursos digitais

*O que a biblioteconomia do livro não sabe descrever, e que é uma parte enorme dos nossos acervos.*

| | | | |
|---|---|---|---|
| **D3** | Vincular os 91 fascículos e as 87 monografias suspeitas de SOLIDAIRES | `P2` | Aberto |
| **D4** | O material efêmero: panfletos, cartazes, adesivos, fanzines | `P1` | Aberto |
| **D5** | Testar a cadeia de digitalização em dez obras antes de equipar quem quer que seja | `P2` | Aberto |
| **D8** | Descrever os arquivos de coletivos segundo a ISAD(G): níveis vinculados, produtores, acesso por nível, exportação EAD | `P3` | Bloqueado |

#### D3 — Vincular os 91 fascículos e as 87 monografias suspeitas de SOLIDAIRES

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : biblioteconomia

**Estado.** O arquivo SOLIDAIRES já traz colunas `revue` e `numero`: **12 títulos a criar, 91 fascículos a vincular**. Além disso, **87 monografias trazem «n°» no título** e estão marcadas por uma flag `numero_dans_titre`: são candidatas ao vínculo.

*Verificado : [object Object],[object Object]*

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

#### D8 — Descrever os arquivos de coletivos segundo a ISAD(G): níveis vinculados, produtores, acesso por nível, exportação EAD

`P3` Adiado · Estado : **Bloqueado** · Carga : um canteiro longo · O que exige : SQL / PostgreSQL, React / JavaScript, biblioteconomia

**Estado.** Decisão **D7** (REGISTRO `ARCH-1` a `ARCH-4`, Xavier, 27/09): um modelo arquivístico completo no AnarBib. Hoje, um tipo «dossiê» plano, sem hierarquia.

*Verificado : 27/09 — colunas `dossier_*` presentes, sem hierarquia, 0 linha preenchida.*

**O que é.** Depois do parecer da rede: unidades de descrição vinculadas (ISAD(G)), produtores em autoridades (ISAAR(CPF)), condições de acesso por nível herdadas, árvore no OPAC e na catalogação, exportação EAD, importação de inventário em planilha.

**Por que importa.** Achatar arquivos em registros de livro é perder o que faz deles arquivos: o contexto.

**O que conta como terminado.**

- Um fundo real de DIRA descrito em vários níveis.
- Uma unidade restrita não aparece nem no OPAC nem numa exportação pública; os filhos herdam.
- Exportação EAD validada contra o esquema EAD e relida por alguém da rede.

**Dependências.** Bloqueado pelo parecer de DIRA, CIRA e FICEDL (`ARCH-4`). Um inventário real de DIRA (**G15**).

*Remissões : `docs/specs/REGISTRE_decisions.md` · `Réponse à DIRA du 26/09/2026`*

---

### E — Front, OPAC, i18n, acessibilidade

*10 locales em paridade estrita, 7 281 chaves cada (05/10), verificadas na integração contínua.*

| | | | |
|---|---|---|---|
| **E1** | Fazer auditar a acessibilidade por alguém que não escreveu o código | `P1` | Aberto |
| **E2** | Decidir as convenções neerlandesa e grega | `P1` | Aberto |
| **E4** | Resolver os pares irregulares do italiano | `P2` | Aberto |
| **E6** | Dividir as cinco telas que pesam mais de cem quilobytes | `P2` | Em curso |
| **E10** | O resto da base de campo: plantão móvel, notificação push, prancha de códigos | `P3` | Aberto |
| **E20** | A barra de navegação agrupa-se por natureza — Público, Eu, Trabalho — em menus que abrem ao clique, não ao passar do rato | `P2` | Aberto |
| **E30** | Fazer revisar o guia de governança em espanhol | `P3` | Aberto |
| **E31** | O que espera um olhar na tela, com sessão | `P2` | Aberto |
| **E36** | O Ateliê diz « erro técnico (42501) » a uma conta sem papel de equipe, em vez de « reservado às equipes da rede » | `P3` | Aberto |

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

*Verificado : 31/08 — os dez arquivos da carta v2 existem desde 05/06, `nl` e `el` incluídos; mas dentro deles a convenção `nl` está marcada « provisória » e a `el` « a definir com uma pessoa falante de grego militante ». Os documentos existem, as decisões não. **27/09** — `b425dfb1` reescreveu 18 valores `nl` («u/uw» → «je/jouw», e dois «jullie» dirigidos a uma só pessoa → «je») e 172 valores `el` (2ª pessoa do plural → singular), por substituições escritas chave por chave (`scripts/i18n-it-de-nl-el-tu.cjs`), sob `DOC-ADDR-1`, sem revisão de falante nativo. A revisão do critério 2 deve começar por esses 190 valores; a tabela DE → PARA do script serve de folha de revisão.*

**O que é.** Uma falante ou um falante nativo retoma a carta de linguagem inclusiva, decide a forma neutra para sua língua, e revisa as 6 177 cadeias com prioridade nas telas mais vistas.

**Por que importa.** Duas línguas que deixam de ser traduções aproximativas. É um dos três canteiros que **não exigem nenhuma competência técnica** — e o único que ninguém mais pode fazer no lugar.

**O que conta como terminado.**

- As convenções `nl` e `el` estão escritas em `docs/notes-audit/anarbib-charte-langage-inclusif-v2-*.md`.
- As cadeias das telas principais estão revisadas.
- A lista neerlandesa já foi enviada a Ludwig — o acompanhamento faz parte.

**Dependências.** Nenhuma. **Entrada sem competência técnica.**

*Remissões : `docs/CHANTIERS_OUVERTS.md §5` · `docs/notes-audit/anarbib-charte-langage-inclusif-v2.md`*

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

`P2` Corrente · Estado : **Em curso** · Carga : alguns dias · O que exige : React / JavaScript

**Estado.** Em 29/08, `BookDraftForm.jsx` tinha **197 KB**, `BibliotecaPage.jsx` 184 KB, `AccountPage.jsx` 154 KB, `PanelPage.jsx` 114 KB, `ImportacoesPage.jsx` 109 KB. 29 das 38 rotas já estão em carregamento preguiçoso, e `vite.config.js` declara quatro lotes de dependências — o problema não é o carregamento inicial, é o tamanho de um arquivo único. **Lote 1 em 27/09:** constantes e funções puras de `BookDraftForm` (214 Ko) passam para `src/lib/catalogacao/bookDraft.js` (`486c71a1`); o formulário cai para 198 Ko. Falta o essencial: dividir o JSX em componentes, verificado na tela. **Lote 2 em 28/09:** o painel de recursos digitais passa a `DigitalResourcesPanel.jsx` (`305a7922`); o formulário cai para 173 Ko. **Lote 3 em 28/09:** o painel de pesquisa catalográfica passa a `LookupPanel.jsx` (o painel nunca escreve o formulário: três retornos ao pai); o formulário cai para 167 Ko. Lotes 2 e 3 vistos na tela por Xavier em 28/09: ok. **Lote 4 em 28/09:** o bloco de contribuidores passa a `ContributorsPanel.jsx` (a lista fica no pai, o painel avisa por `onDirty`); o formulário cai para 157 Ko. **Lote 5 em 28/09:** o painel de revisão da ficha passa a `ReviewPanel.jsx` (só exibe; ISBD e sua preparação ficam no pai); o formulário cai para 146 Ko. **Lote 6 em 28/09:** a prévia de cota e os exemplares iniciais passam a `ShelfLabelPreview.jsx` e `InitialCopiesBlock.jsx`; o formulário cai para 142 Ko. **Lotes 7 e 8 em 28/09:** a reatribuição de um registro publicado passa a `ReassignPanel.jsx` e os cartões «para informação» da prévia a `InfoCards.jsx`; o formulário cai para 130 Ko. As seções de material já eram renderizadas pelo registro. Falta o cabeçalho (capa), o mais acoplado. **`BibliotecaPage.jsx`, lote 1 em 28/09:** a aba dos empréstimos entre bibliotecas (PEB) passa a `IllSection.jsx` (`3c33b9f6`); a página cai de 184 para 152 Ko. **Lote 2 em 28/09:** a aba das tarefas internas passa a `TasksSection.jsx` (`22083073`); a página cai para 117 Ko. **Lote 3 em 29/09:** a cotização e o depósito de garantia passam a `MembershipSection.jsx` e `DepositSection.jsx` (`2ae132fe`); a página cai para 83 Ko. Faltam relatórios, identidade e comunicações.

*Verificado : [object Object],[object Object]*

**O que é.** Extrair os subformulários e as abas em componentes separados, sem mudar o comportamento. Começar por `BookDraftForm`, o maior e o mais editado.

**Por que importa.** Um arquivo de 197 KB não é relegível por quem chega, e duas pessoas não podem trabalhar nele ao mesmo tempo sem conflito. É um obstáculo à contribuição antes de ser um problema de performance.

**O que conta como terminado.**

- Nenhum arquivo de `src/` passa de 60 KB.
- O comportamento está inalterado, verificado tela por tela.
- Divisão por lotes, uma tela por vez, nunca uma refundação.

**Dependências.** Retoma `#PERF-accountpage-split`, herdado do v32.

*Remissões : `AnarBib-Backlog-2026-06-17-v33 §2.5` · `Relevé du 29/08/2026`*

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

#### E30 — Fazer revisar o guia de governança em espanhol

`P3` Adiado · Estado : **Aberto** · Carga : uma noite · O que exige : língua materna

**Estado.** Visto na entrega do E25 (05/10): o guia de governança em espanhol diz « concernida(s) » 22 vezes; não foi revisado.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Revisão por pessoa de língua materna; aplicar as correções e regenerar a coletânea `Guia_de_governanca_AnarBib.pdf`.

**Por que importa.** O guia diz a uma coordenação como cooptar ou tratar um conflito; uma palavra duvidosa em cada página diz que ninguém o revisou.

**O que conta como terminado.**

- O guia em espanhol foi revisado e as correções aplicadas.
- A coletânea PDF foi regenerada.

**Dependências.** Uma pessoa hispanofalante.

*Remissões : `clôture E25` · `commit 0cc2b6d3`*

#### E31 — O que espera um olhar na tela, com sessão

`P2` Corrente · Estado : **Aberto** · Carga : uma noite · O que exige : nenhuma competência técnica

**Estado.** Várias entregas de fim de setembro e início de outubro estão provadas em bancada e no banco, mas só se julgam na tela, com sessão. **Itens fechados, olhar faltando**: barra de estado e janela de confirmação (C21); « Publicado — e agora? » (C22); depósito digital em cinco etapas (C24); leitura reservada para membro da BTL (C20). **Itens abertos que também esperam**: C23, G16, C14, cada lote do E6. **Acrescentado em 06/10**: um convite real a uma tarefa, recebido (resto do F16).

*Verificado : [object Object],[object Object],[object Object]*

**O que é.** Uma sessão com Xavier conectado, um ponto por vez; anotar « visto, conforme » ou o defeito achado (aberto como item).

**Por que importa.** **O que ainda espera um olhar (08/10)**: lotes 2, 4, 5 e 8 da `AccountPage` (E6); a linha BTL « Indisponível para você » (E35); as telas de H21 lotes 1 a 5. **Vistos e fechados em 08/10**: C14, C23, G16. **Visto em 09/10**: correspondência entre bibliotecas (G19, fechado) — fio real BLMF → BTL na tela, sino recebido do lado da BTL; e-mail ao endereço coletivo da BTL e resposta da BTL na aba ainda por ver.

**O que conta como terminado.**

- Cada ponto da lista é visto na tela e anotado aqui.

**Dependências.** Xavier, conectado.

*Remissões : `clôtures C20, C21, C22, C24, C25` · `items C14, C23, G16, E6` · `clôture F16` · `clôture G19`*

#### E36 — O Ateliê diz « erro técnico (42501) » a uma conta sem papel de equipe, em vez de « reservado às equipes da rede »

`P3` Adiado · Estado : **Aberto** · Carga : uma noite · O que exige : SQL / PostgreSQL, react

**Estado.** **Constatado por Xavier em 10/10**: o link de um e-mail de proposta, aberto num navegador com uma conta leitora, mostra duas vezes « erro técnico (42501) ». As RPC levantam 42501 sem HINT traduzível. Os HINT `atelier.error.notContributor` / `notStaff` não existem em nenhuma locale.

*Constato de 29/08, não reverificado desde então.*

**O que é.** Levantar com `hint = 'atelier.error.reserved'` nas três RPC ; chave nas dez locales, mais `notContributor` e `notStaff` ; a página mostra a frase uma só vez.

**Por que importa.** Quem chega por um e-mail e lê « erro técnico » acha que há uma pane ; não há pane, há a conta errada.

**O que conta como terminado.**

- Uma conta sem papel lê uma frase que diz a quem o Ateliê é reservado.
- Os HINT das RPC do Ateliê existem nas dez locales.

**Dependências.** Nenhuma.

*Remissões : `src/pages/atelier/AtelierAutoridadesPage.jsx` · `src/components/atelier/ConvRevuePanel.jsx` · `C4`*

---

### F — E-mail e notificações

*14 funções `notify-*`. A cadeia tem seu mapa desde 30/09, medido em produção (F1): cerca de 96 cadeias, 41 vivas, 31 nunca percorridas.*

| | | | |
|---|---|---|---|
| **F10** | Sair do Resend: um relay militante a pedir, um transporte a escrever, o roteamento a restabelecer — e `sendViaBrevo` ainda está em `email.ts` | `P2` | Aberto |
| **F19** | Os registros das funções contêm os endereços em claro | `P1` | A verificar |
| **F25** | Envios em rajada ultrapassam o limite do Resend: e-mails se perdem sem ninguém saber | `P1` | A verificar |

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

#### F19 — Os registros das funções contêm os endereços em claro

`P1` Prioritário · Estado : **A verificar** · Carga : uma noite · O que exige : Deno / TypeScript

**Estado.** Achado pelo mapa F1. Os registros das Edge Functions trazem « sent to <endereço> » desde pelo menos 04/08.

*Verificado : [object Object],[object Object],[object Object]*

**O que é.** Mascarar o endereço em todos os registros de envio, na fonte comum; teste de fonte.

**Por que importa.** Vazamento contínuo de dados pessoais.

**O que conta como terminado.**

- Nenhum endereço completo nos registros após a correção.

**Dependências.** Nenhuma.

*Remissões : `docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md`*

#### F25 — Envios em rajada ultrapassam o limite do Resend: e-mails se perdem sem ninguém saber

`P1` Prioritário · Estado : **A verificar** · Carga : alguns dias · O que exige : Deno / TypeScript

**Estado.** **09/10, 21h49**: catorze propostas abertas de uma vez no Ateliê dispararam 72 e-mails em dois segundos; o Resend aceita dez por segundo (HTTP 429): **58 e-mails perdidos**. O transporte compartilhado não repete um 429 nem cadencia; `sent++` conta o fracasso como sucesso. A sonda de saúde viu (incidente 23).

*Verificado : [object Object]*

**O que é.** No transporte: repetir 429 e 5xx com espera crescente, cadenciar (oito por segundo), devolver um resultado verdadeiro contado pelos chamadores. Bancada com um Resend falso.

**Por que importa.** Quem não recebe o e-mail não sabe que algo a espera — e o sistema disse « enviado ».

**O que conta como terminado.**

- Um 429 é repetido e o e-mail parte (bancada).
- 72 destinatários num só chamado: nenhum 429.
- Um fracasso de transporte é contado como fracasso por todos os chamadores.

**Dependências.** Nenhuma. Os 58 e-mails de 09/10 não serão reenviados: as propostas ficam no Ateliê até 16/10.

*Remissões : `clôture F7` · `F15` · `C4` · `supabase/functions/_shared/transport/email.ts` · `supabase/functions/_shared/domain/authority.ts`*

---

### G — Rede, governança, federação

*Muitos circuitos construídos, pouquíssimos percorridos. É o principal ensinamento do levantamento.*

| | | | |
|---|---|---|---|
| **G1** | Percorrer os circuitos construídos e jamais usados | `P0` | Aberto |
| **G6** | Fazer um empréstimo entre bibliotecas de ponta a ponta pela sua tela | `P2` | Aberto |
| **G8** | Completar a cartografia com os arquivos identificados alhures | `P2` | Aberto |
| **G9** | Implementar a cartografia da rede segundo a spec v1.0 | `P3` | Congelado |
| **G10** | Liquidar as três questões de onboarding marcadas «o mais rápido possível» | `P2` | Aberto |
| **G15** | DIRA: um ensaio de importação sobre amostra antes de qualquer adesão, o PMB continuando como base de referência | `P1` | Aberto |

#### G1 — Percorrer os circuitos construídos e jamais usados

`P0` Estrutural · Estado : **Aberto** · Carga : várias semanas · O que exige : deliberação coletiva, nenhuma competência técnica

**Estado.** Verificado em 29/08: **62 tabelas de negócio nunca receberam uma única inserção.** Sete blocos inteiros são atingidos — assembleias da rede (3 tabelas), notas de leitura (2), propostas e objeções de autoridade (3), referenciais de catalogação `catalog_ref_*` (8 de 9), governança dos perfis de biblioteca (4, **enquanto dois crons rodam sobre elas a cada quinze minutos**), deliberação sobre os pedidos de adesão (5, incluindo `library_request_votes` e `library_request_messages`).

**Remedido em 31/08: ainda 62, e não é boa notícia.** A conta não mudou em dois dias — 62 tabelas de `public` em 189 nunca receberam uma inserção. Mas não é a mesma lista: `loan_cycle_notifications`, nascida esta manhã com os lembretes de vencimento, entrou nela **no dia da sua criação**. Um circuito entregue hoje junta-se de imediato à coluna dos circuitos jamais percorridos.

**Um primeiro livro circula.** O empréstimo **#69** foi aberto esta manhã na BLMF — item 84, *O Anarquismo na Escola, no Teatro, na Poesia*, de Edgar Rodrigues, vencimento **21/09**. Dá ao bloco *notas de leitura* a sua primeira hipótese real: o meio-percurso calculado por `notify-loan-cycle` cai em **10 de setembro**, e o convite a deixar uma nota sob pseudónimo parte nesse dia (item **F4**). `book_reading_notes` continua a zero linhas.

Os seis outros blocos estão inalterados em 31/08, verificados tabela a tabela: assembleias da rede (3), propostas e objeções de autoridade (3), referenciais `catalog_ref_*` (8), governança dos perfis (4, **e os dois crons continuam a rodar sobre elas a cada quinze minutos**), deliberação dos pedidos de adesão (5). Todos a zero inserções.

*Verificado : [object Object],[object Object],[object Object],[object Object],[object Object]*

**O que é.** Escolher um bloco e percorrê-lo de verdade, do primeiro ao último gesto: realizar uma assembleia da rede, depositar uma nota de leitura, propor uma autoridade e deixar alguém objetar, fazer deliberar um pedido de adesão. Registrar o que falta, o que surpreende, o que trava.

**Por que importa.** É o principal ensinamento do levantamento de 29 de agosto, e não consta em nenhum documento do corpus. **O projeto não sofre de falta de funcionalidades: sofre de falta de uso.** Um circuito jamais percorrido não está entregue — está apenas escrito. E no dia em que se torna o caminho crítico, como o circuito de convite acaba de se tornar para as promoções, ele quebra em coisas que uma única passagem teria revelado.

**O que conta como terminado.**

- Pelo menos três dos sete blocos foram percorridos de ponta a ponta, em `blmf-teste` e depois no real.
- Cada passagem produziu um relatório escrito do que falta.
- Os blocos cujo uso não é desejado hoje são marcados **dormentes**, com o motivo — não é um fracasso, é uma informação.

**Dependências.** O bloco «assembleia» depende de **A1**. Os outros não.

*Remissões : `Relevé du 29/08/2026` · `REGISTRE §32 AG, §28 ATE, §26 ONBO` · `emprunt #69 (BLMF, item 84, échéance 21/09)` · `item F4` · `public.book_reading_notes`*

#### G6 — Fazer um empréstimo entre bibliotecas de ponta a ponta pela sua tela

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : React / JavaScript, biblioteconomia

**Estado.** O ciclo de vida do empréstimo entre bibliotecas está especificado e implementado no banco: máquina de estados travada, quatro triggers, cron `anarbib-peb-detect-overdue-daily` ativo. **Uma tela existe**: a aba EEB da página Biblioteca, presente desde o commit inicial do AnarBib v3 (`92e0064e`, 26/04), ligada às RPC de EEB em 20/05 (`e4a0b9d6`, EA-12 fase 1), transformada em `IllSection.jsx` em 28/09 (`3c33b9f6`). Um empréstimo aparece nela tanto para a emprestadora quanto para a solicitante. Em 29/08, o banco trazia 2 empréstimos para 20 inserções históricas.

*Verificado : 31/08 — `interlibrary_loans_v2`: 2 empréstimos vivos para 20 inserções, como em 29/08. **29/09** — a aba percorrida na tela por Xavier (revisão do E6): um empréstimo de ensaio criado com seu exemplar (a fila de notificação recebeu o evento) e depois apagado; os dois EEB de maio (nº 24 e 25) arquivados; um segundo ensaio (nº 35) criado, devolução registrada em duas vezes, arquivado. Um defeito no caminho: «Excluir» era oferecido a um EEB já saído e a recusa aparecia em jargão («refusé par RLS»); o botão só aparece nos dois status aceitos pela política DELETE, e a recusa é dita claramente nas dez línguas (`b3ac9d13`). No levantamento da noite, nenhum EEB está aberto. O critério 1 não está cumprido: foram ensaios de uma só pessoa, não um empréstimo real entre duas bibliotecas, cada uma do seu lado.*

**O que é.** Uma tela de pedido do lado da biblioteca solicitante, uma tela de tratamento do lado da emprestadora, e a exibição do estado para as duas. As views `interlibrary_loans_painel_ui` e `interlibrary_loan_items_ui` já existem.

**Por que importa.** O empréstimo entre bibliotecas é o que torna uma rede federativa útil às suas leitoras, em vez de uma simples justaposição de catálogos. O corpus dizia «um início no banco, mesmo sem tela»; a tela, porém, existia (ver v). O que falta é um empréstimo real atravessá-la de ponta a ponta.

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

#### G15 — DIRA: um ensaio de importação sobre amostra antes de qualquer adesão, o PMB continuando como base de referência

`P1` Prioritário · Estado : **Aberto** · Carga : alguns dias · O que exige : nenhuma competência técnica, biblioteconomia

**Estado.** Em 26/09/2026, a DIRA escreveu à rede: biblioteca em **PMB**, coleção multilíngue, zines, arquivos de coletivos, comitê documental ativo. A questão central é a perenidade. A resposta preparada no mesmo dia não promete um ida-e-volta que ainda não existe (**H23**, **H24**) e propõe um ensaio sobre ~50 registros em UNIMARC ISO 2709 com exemplares (995), versão do PMB e codificação, sem dados de leitoras nem de empréstimos. Não existe instância de ensaio separada: o ensaio é feito no banco (**H14**), sem publicar nada.

*Verificado : **29/09** — o envio da resposta à DIRA não está datado em lugar nenhum do repositório (critério 1). O ida-e-volta que a resposta de 26/09 não prometia foi desde então provado no banco: **H27** fechado em 29/09 (o export tirado da base, reimportado num PMB vazio, devolve 46 exemplares de 46). Duas peças existem para o relatório: o CSV de cobertura de uma importação (**H16**, `4be5fee9`) e a tabela do ida-e-volta (`docs/interop/couverture-pmb.md`).*

**O que é.** Enviar a resposta (Xavier). Ao receber a amostra, passá-la no banco (**H14**) com **H15** e **H19**; devolver à DIRA o relatório de cobertura (**H16**); decidir por escrito se se abre um acesso. A adesão segue o circuito normal dos admins da rede.

**Por que importa.** É a primeira biblioteca vinda de outro SIGB com uma exigência real de reversibilidade. Um ensaio honesto a traz; um ensaio que promete demais a perde, e com ela o argumento «seus dados continuam seus».

**O que conta como terminado.**

- Resposta enviada, datada.
- Amostra recebida, com versão do PMB e codificação.
- Relatório de cobertura enviado à DIRA.
- Decisão de acesso escrita, com a razão.

**Dependências.** Antes do relatório: **H28** (entregue em 26/09), **H14** (fechado em 26/09), **H15** e **H16** (entregues em 26/09), **H19** (entregue em 27/09); **H28**, **H15**, **H16** e **H19** ainda a verificar numa importação real. Antes de qualquer migração: **H23** e **H24** (entregues em 28/09), **H27** (fechado em 29/09) e **H21** (em curso: `IMP-26` e `IMP-27` de 29/09, lote 0 entregue em 01/10, depois **H30** e **H31**). Arquivos: **D7** (fechado em 27/09; realização: **D8**).

*Remissões : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

---

### H — Interoperabilidade, tesauro, coleta

*Sair em direção aos outros catálogos, e aceitar ser apontado de volta.*

| | | | |
|---|---|---|---|
| **H2** | Colocar à FICEDL as sete questões que bloqueiam a exportação do tesauro | `P1` | Bloqueado |
| **H6** | Alinhar os vocabulários militantes que não se conhecem | `P2` | Aberto |
| **H12** | As listas fora do tesauro da FICEDL — municípios do Bettini, lugares de edição do Bianco: pedir a exportação como está, nunca a integração | `P3` | Aberto |
| **H28** | Um arquivo MARC ISO 2709 é importado: o formato detectado é aceito pela base | `P1` | A verificar |
| **H15** | A importação lê um arquivo que não está em UTF-8 em vez de corrompê-lo em silêncio | `P1` | A verificar |
| **H16** | Um relatório de cobertura por importação: cada zona do arquivo que a importação não aproveita é contada e mostrada | `P1` | A verificar |
| **H21** | Reimportar um catálogo atualiza o que a importação já conhece em vez de duplicá-lo | `P2` | Em curso |
| **H26** | O export de um catálogo grande não depende mais da memória de uma edge function | `P2` | A verificar |
| **H29** | De volta ao PMB, um exemplar mantém seu tipo, sua seção e seu código estatístico | `P2` | Aberto |

#### H2 — Colocar à FICEDL as sete questões que bloqueiam a exportação do tesauro

`P1` Prioritário · Estado : **Bloqueado** · Carga : uma noite · O que exige : deliberação coletiva

**Estado.** A exportação completa dos 620 descritores nos dois formatos está a **uma noite de trabalho** — assim que as sete questões tiverem resposta. Estão escritas e ninguém ainda as colocou.

*Verificado : [object Object],[object Object],[object Object]*

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

*Verificado : [object Object]*

**O que é.** Começar pelo menor e mais viável: as 11 categorias do AnarcosyndicalismeBOOK, **um primeiro passo concreto, delimitado, viável numa noite** — e como o tesauro já está em dez línguas, o alinhamento vale simultaneamente para as dez. Depois abrir a conversa com a NORLA.

**Por que importa.** Cada vocabulário construído isoladamente é um acervo que os outros não encontrarão. Reserva a ter em mente: os vocabulários de efêmeros são **monolíngues**, o alinhamento será mais pesado neles do que em assuntos.

**O que conta como terminado.**

- As 11 categorias do AnarcosyndicalismeBOOK estão alinhadas.
- Uma conversa está aberta com a NORLA sobre o alinhamento das facetas.
- A reciprocidade é pedida: **os catálogos parceiros não apontam de volta** hoje.

**Dependências.** Outubro-novembro, se o companheiro topar. Ligado a **D4**.

*Remissões : `ORIENTATION_outils_bibliotheques_militantes_2026-08-26 §6` · `VEILLE_leftovers_maydayrooms_2026-08-19`*

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

#### H28 — Um arquivo MARC ISO 2709 é importado: o formato detectado é aceito pela base

`P1` Prioritário · Estado : **A verificar** · Carga : uma noite · O que exige : SQL / PostgreSQL, React / JavaScript

**Estado.** Achado em 26/09, confirmado em produção: a CHECK de `detected_format` não aceitava nem `marc_iso2709` (escrito pela EF) nem `marc21` (enviado pelo front para `.mrc`/`.marc`). Todo import ISO 2709 falhava — na criação ou na atualização final. Nenhum run MARC jamais rodou. O PMB exporta em `.marc`.

*Verificado : 26/09 — migração aplicada pela CI; CHECK em produção com `marc_iso2709`; banco da EF real escreve `marc_iso2709`. **28/09** — ainda nenhum run `marc_iso2709` em produção (levantamento feito para **H17**): o critério 2 espera. Além de «pronta para revisão», um lote MARC não teria sido publicado (idioma bruto contra a CHECK BCP-47): corrigido em 28/09 (`2ee5f7a7`, ver **H17**). **29/09** — `import_format_marc_tests` (4 testes) roda na CI desde `d008bb51`; última bateria anotada: SQL 149/149, antes do push de `2348cb86`. **06/10** — H17, H18 e H19 fechados; a primeira importação ISO 2709 real verifica também responsabilidades, exemplares (DIRA) e fascículos ligados ao periódico.*

**O que é.** **Entregue em 26/09** (`d008bb51`, migração `20260926184500`): `marc_iso2709` aceito, `marc21` recusado (vocabulário, não formato); uma só `detectFileKind`; guarda vitest e suíte SQL. Falta: **uma primeira importação ISO 2709 real em produção**.

**Por que importa.** É a porta de entrada de todo o ida-e-volta PMB.

**O que conta como terminado.**

- A CHECK aceita `marc_iso2709` em produção (feito, 26/09).
- Uma importação ISO 2709 real chega a « pronta para revisão » em produção.

**Dependências.** Antes de **H15** e **H19**. Provado de verdade por **G15**.

*Remissões : `claude/aller-retour-PMB_2026-09-26` · `tests/pmb/README.md`*

#### H15 — A importação lê um arquivo que não está em UTF-8 em vez de corrompê-lo em silêncio

`P1` Prioritário · Estado : **A verificar** · Carga : uma noite · O que exige : Deno / TypeScript

**Estado.** `index.ts` (l. 623) e `marc.ts` (l. 303) decodificam **sempre em UTF-8**, sem `fatal`; só o MARC-8 gera aviso. Uma base PMB em ISO-8859-1 teria os acentos trocados por U+FFFD **sem nenhum aviso**; idem para um CSV em Windows-1252. **Medido no banco PMB em 26/09**: 29 de 50 registros com U+FFFD em latin-1, e um falso « MARC-8 » em todo UNIMARC. **Entregue em 26/09**: UTF-8 estrito, recuo windows-1252 suposto e dito, `forced_encoding`, MARC-8 só em MARC21, 100 $a relido; RPC com `p_forced_encoding` em fusão; reprocessamento recusado após promoção; tela com seletor, painel e « Reprocessar », 10 locales.

*Verificado : 26/09 — a variante latin-1 dá exatamente os mesmos registros que o UTF-8 (testes nas fixtures PMB e banco da EF real); suíte SQL 6/6. Falta: uma importação latin-1 real em produção e o painel visto na tela.*

**O que é.** Decodificar em UTF-8 estrito (`fatal: true`); se falhar, reler em Windows-1252 e **dizê-lo** nos avisos do run. No ISO 2709 UNIMARC, ler também 100 $a/26-29. Ajustar `forced_encoding` em `adapter_overrides`. Testar com fixture latin-1.

**Por que importa.** Uma corrupção silenciosa é a pior perda: ninguém a vê até uma leitora buscar um título acentuado.

**O que conta como terminado.**

- Fixture latin-1 importada sem U+FFFD.
- A codificação adotada aparece nos avisos do run.
- Teste no banco das edge functions.

**Dependências.** Depois de **H28** (feito). Fixture de **H14** (feita).

*Remissões : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H16 — Um relatório de cobertura por importação: cada zona do arquivo que a importação não aproveita é contada e mostrada

`P1` Prioritário · Estado : **A verificar** · Carga : alguns dias · O que exige : Deno / TypeScript, SQL / PostgreSQL, React / JavaScript

**Estado.** O registro bruto é guardado (`raw_payload` → `book_drafts.marc_json` → `books.marc_json`; 2 250 rascunhos com ele em 26/09), mas **nada diz quais zonas foram deixadas de lado**. A perda não aparece nem em Importações nem no relatório de revisão de lote.

*Verificado : 26/09 — suíte SQL 5/5; banco da EF real no export PMB e num CSV; tela renderizada em fr e el. Implantado em 26/09 à noite: migração aplicada pela CI, `coverage` presente em produção, EF reimplantadas e sondadas.*

**O que é.** No parse, calcular por run o inventário de zonas/subzonas (presentes, aproveitadas, ignoradas, ocorrências, exemplo); para CSV, colunas não mapeadas. Guardar em `summary`, mostrar em Importações, anexar a `fn_batch_review_report`, baixável para enviar à biblioteca. Dez locales. **Entregue em 26/09**: cobertura MARC/CSV/RIS no `summary` do run, chave `coverage` no relatório de revisão, painel na tela e **CSV para baixar**, 10 locales. Medido no export PMB: 111 subcampos, 17 aproveitados. **Falta**: a coleta OAI ainda não escreve cobertura; ver o painel numa importação real.

**Por que importa.** É o que torna a importação **segura**: nada se perde sem ser visto. E é a lista de trabalho de **H17**, tirada de catálogos reais.

**O que conta como terminado.**

- Relatório visível para uma importação MARC e uma CSV.
- Anexado ao relatório de revisão de lote.
- Baixável; dez locales; teste.

**Dependências.** Antes de **H17** (diz quais zonas importam).

*Remissões : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H21 — Reimportar um catálogo atualiza o que a importação já conhece em vez de duplicá-lo

`P2` Corrente · Estado : **Em curso** · Carga : várias semanas · O que exige : SQL / PostgreSQL, Deno / TypeScript, React / JavaScript

**Estado.** A marcha em paralelo supõe continuar catalogando no PMB e reimportar. Hoje, um reimport passa pela detecção de duplicatas: não há noção de «registro já importado, a atualizar». `book_drafts.action` já conhece `update`.

*Verificado : 26/09 — `action` ∈ {create, update}. **29/09** — passou para «em curso» com `69dbeec7`; nenhum dos nove lotes entregue na noite de 29/09. Constatação de produção que motivou a regra (REGISTRO `IMP-26` a, 28/09): 198 atualizações publicadas, 33 delas em registros hoje compartilhados e 3 por uma biblioteca que não detinha o registro. A tabela de cobertura o diz à DIRA: o 001 é guardado e devolvido no export, mas um reimport ainda não o usa (`docs/interop/couverture-pmb.md`, `466324aa`). **01/10 — lote 0 entregue** (`1385431b` base, `d4f97afc` tela; migração `20261001200931` aplicada pela CI, `created_by` vazio; REGISTRO `IMP-27`): um registro ou um exemplar vinculado nascido de uma importação só é publicado pela primeira vez num lote revisado, mesmo fora do lote; já publicado (e no catálogo), é republicado fora do lote; a aprovação cobre os rascunhos congelados no pedido, e a coordenação pede de novo a revisão para os acréscimos; um lote de vinculação passa pela revisão; uma seleção entra no lote aberto da importação e «Promover a seleção» só promove ela; «vinculado» nunca vira registro; esvaziar a lixeira de um rascunho importado descarta a linha, que só a restauração desse rascunho retoma; «Reprocessar» recusado na hora para uma importação com linha descartada ou exemplar vinculado na lixeira; a tela diz as linhas ignoradas. Seis passadas de revisão contraditória; SQL 158/158, vitest 1 666; verificado em produção em 01/10. **Registrado**: a corrida entre «Reprocessar» aceito e o apagamento pela edge function, e «Reprocessar» de uma importação sem arquivo (**H30**, **H31**); as fusões `api.merge_*` (lote 5); a lixeira de um exemplar vinculado libera a linha (lote 6); o assistente de importação não lê `skipped_rows`; uma linha cujo registro proposto foi descartado fica «pendente»; uma aba aberta numa importação excluída recebe «Run N introuvable» bruto. **A decidir por Xavier**: um exemplar vinculado tirado da lixeira depois do pedido deve seguir a lista da rodada? Depois de uma reatribuição, o registro guarda para a biblioteca de destino o identificador de origem vindo do PMB da primeira? **05/10 — lote 1 entregue** (`32afb117`, `ba6ec496`; migração `20261005103427`; REGISTRO `IMP-28`): uma linha reimportada cujo identificador de origem já é conhecido vira «Já importada», sem passes aproximados; vincula-se ou rejeita-se, nunca registro novo nem atualização; «não possui mais» é sinalizado; o identificador fica com a biblioteca cujo PMB o emitiu; um exemplar vinculado tirado da lixeira depois do pedido espera nova rodada. Fixture PMB reimportada: 64 «Já importada» de 64. **Registrado (05/10)**: (1) o aviso de chave ambígua não aparece na tela; (2) enquanto um exemplar vinculado espera, republicar o registro é recusado (`items_on_update`); (3) a view `api.partner_catalog_import_rows_workflow_ui` não conhece `known_record`. **05/10 — lote 2 entregue** (`84c455cd`, migração `20261005172708`; REGISTRO `IMP-29`): `ingest.book_import_baselines` guarda, por identificador de origem, o que o último arquivo aceito trouxe; uma só regra de correspondência; base escrita na publicação, na absorção (que a avança) e na vinculação (que só a cria); 264 bases retomadas em produção. **Registrado**: o esquema ingest não tem backup (decisão de 05/10: incluí-lo no fluxo longo). **05/10, à noite** — o ponto « o esquema `ingest` não tem backup » está resolvido: **I29**, fechado em 05/10 (`f5e3f5ed`); direitos e esquemas `private`/`api`: **I30**. **06/10 — lote 3 entregue** (`e8101139`, migração `20261006182421`; REGISTRO `IMP-30`): cada linha reconhecida compara 24 campos entre a base, o AnarBib e o arquivo, seis veredictos, nada aplicado; cálculo por páginas a partir da tela; valores do AnarBib mascarados para um registro fora da visão. **06/10 — lote 4 entregue** (`44ae324a`, migração `20261006203239`; REGISTRO `IMP-31`): gesto «Preparar a atualização»; só a biblioteca única detentora recebe um rascunho, cópia do registro com os campos alterados só no arquivo; autorias e campos esvaziados mostrados, nunca aplicados; publicação recusada se o registro mudou, ficou compartilhado, sumiu, ou se a base ou a `bib_ref` mudaram. **07/10 — lote 5 entregue** (`2cb5fd31`, migração `20261007175456`; REGISTRO `IMP-32`): num registro compartilhado, o recálculo aponta uma divergência por campo, nunca escreve no catálogo; cada coordenação detentora a vê (aba «Divergências», faixa no registro); campo a campo, «Descartar» (a base avança) ou «Aplicar» (rascunho pré-preenchido publicado pela detentora). **08/10 — lote 6a entregue** (`e225f463`, migração `20261008173955`; REGISTRO `IMP-33`): cada exemplar do arquivo recebe um veredicto (novo, já presente, já em rascunho, sem código, deslocado, reetiquetado, código retomado); só «novo» cria um rascunho; o `expl_id` da 996 do PMB é lido como segundo sinal. **09/10 — lote 6b entregue** (`22a8a8f1`, migração `20261008231259`): cota e nota de um exemplar comparadas em três estados; o que mudou só no arquivo se aplica por um rascunho de exemplar submetido à revisão; nunca uma criação, nunca o exemplar de outra biblioteca. **10/10 — lote 7 em andamento** (retirados, `IMP-34`); constatações do cético registradas na ficha; a falha de visibilidade da circulação vai para **B38**.*

**O que é.** Aproximar por `(biblioteca, identificador de origem)`; rascunhos `update` com a diferença mostrada na revisão; exemplares acrescentados/retirados; conflito se o registro foi editado no AnarBib — **nunca sobrescrever em silêncio**. **Decidido em 29/09 por Xavier (REGISTRE `IMP-26`)**: retomar um registro à mão é reservado às bibliotecas que o detêm; uma divergência num registro compartilhado é tratada por qualquer detentora, e descartá-la faz avançar a base; «retirado» é uma constatação reversível (não emprestável, oculto no OPAC, fora do export, nunca apagado), proposta só para exemplares vindos da mesma fonte, num arquivo MARC declarado «export completo»; H21 visa só a DIRA; `accept_duplicate` quer dizer «vinculado», nunca uma criação. **Plano em nove lotes** (0 a 8).

**Por que importa.** Sem reimport incremental, a marcha em paralelo é impraticável.

**O que conta como terminado.**

- Reimportar a fixture modificada não cria duplicatas e mostra as diferenças.
- Conflito sinalizado, não sobrescrito.

**Dependências.** Depois de **H20** e **H19**. Antes de qualquer migração.

*Remissões : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H26 — O export de um catálogo grande não depende mais da memória de uma edge function

`P2` Corrente · Estado : **A verificar** · Carga : alguns dias · O que exige : Deno / TypeScript

**Estado.** `export-catalog-lote` monta tudo em memória; `export-fonds-bundle` já é limitado (150 arquivos, 80 MB). Maior catálogo da rede: 2 184 detenções (26/09). Limite real não medida; tamanho da DIRA desconhecido. **Entregue em 28/09** (`8c80de27`): exportação paginada, arquivo montado pela tela Importações; 306 ms em produção para as 2 167 notícias da BTL. **Falta**: medir 10 000 e 50 000 notícias.

*Verificado : 28/09 — migrações aplicadas pela CI (`created_by` vazio), `deployed-functions` = `8c80de27`.*

**O que é.** Medir a limite com catálogo sintético (10 000, 50 000); se baixa, geração assíncrona (fila, arquivo no Storage, link quando pronto).

**Por que importa.** Um export que falha no dia em que a biblioteca quer sair vale menos que nenhum.

**O que conta como terminado.**

- Limite medida e escrita; além dela, export assíncrono testado.

**Dependências.** Depois de **H24**. Tamanho da DIRA via **G15**.

*Remissões : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H29 — De volta ao PMB, um exemplar mantém seu tipo, sua seção e seu código estatístico

`P2` Corrente · Estado : **Aberto** · Carga : alguns dias · O que exige : Deno / TypeScript, SQL / PostgreSQL, biblioteconomia

**Estado.** **Medido no banco PMB 8.1.1.1 em 29/09** (H27): os 46 exemplares voltam todos com tipo, seção e código estatístico «indeterminado»; na origem, 8 tipos, 12 seções, 3 códigos estatísticos. O PMB acha tipo e seção pelo código de importação, ou os cria (o tipo com prazo de empréstimo de 0 dia). Causa: o export escreve `995 $r uu $q u`; na importação `$r`/`$q` vão só para a nota de proveniência, e os rótulos estão na 996 do PMB, nunca retomada nem reemitida. Uma biblioteca que volta ao PMB precisa reclassificar cada exemplar antes de emprestar.

*Verificado : 29/09 — aberto por decisão de Xavier, no fechamento de H27.*

**O que é.** Pistas, a decidir após a resposta da DIRA: guardar na importação, em colunas do exemplar (nunca numa nota), tipo, seção, código estatístico e localização de origem, e reescrevê-los no export para a biblioteca de origem; para um exemplar nascido no AnarBib, uma correspondência no perfil da biblioteca.

**Por que importa.** A volta ao PMB é a garantia de que o AnarBib não prende uma biblioteca; um catálogo que volta sem tipo nem seção dos exemplares não se empresta no dia seguinte.

**O que conta como terminado.**

- Reimportado no PMB, um exemplar vindo do PMB recupera tipo, seção e código estatístico de origem.
- Um exemplar nascido no AnarBib sai com o tipo e a seção que a biblioteca fez corresponder.
- Medido no banco PMB, balanço versado.

**Dependências.** Depois de **H27** (fechado em 29/09). Perguntar primeiro à DIRA: para que essas informações lhes servem, e se os códigos de importação de tipos e seções estão configurados no PMB delas.

*Remissões : `claude/aller-retour-PMB_2026-09-26` · `Tableau de couverture AnarBib ↔ PMB, § 4 (docs/interop/couverture-pmb.md)`*

---

### I — Auto-hospedagem, operação, backups, CI

*Descongelado desde 14/09/2026. O runner da CI ainda vive na máquina do mantenedor (A3).*

| | | | |
|---|---|---|---|
| **I2** | Concluir a migração para a auto-hospedagem | `P1` | Aberto |
| **I21** | O que deve ser verdade antes da virada para Les Herbes Folles, e ainda não é — oito condições, nenhuma tecnicamente difícil | `P1` | Aberto |
| **I30** | Uma restauração devolve um banco que funciona: os direitos de `public` e os esquemas `private` e `api` | `P1` | A verificar |
| **I32** | Estabelecer a causa da queda de 07/10 e dimensionar a instância do banco | `P1` | Aberto |

#### I2 — Concluir a migração para a auto-hospedagem

`P1` Prioritário · Estado : **Aberto** · Carga : várias semanas · O que exige : administração de sistemas

**Estado.** A pilha está reduzida de doze a **seis contêineres** (`db`, `rest`, `auth`, `storage`, `functions`, `caddy`), as versões estão fixadas, `bootstrap.sh` foi executado de verdade em 26/08 com oito defeitos levantados e corrigidos, e o ensaio de 18/08 reexecutou 124 migrações e restaurou um dump de produção em 17 segundos. Reconstrução completa medida: **25 minutos**.

*Verificado : [object Object],[object Object],[object Object]*

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

#### I21 — O que deve ser verdade antes da virada para Les Herbes Folles, e ainda não é — oito condições, nenhuma tecnicamente difícil

`P1` Prioritário · Estado : **Aberto** · Carga : alguns dias · O que exige : administração de sistemas, deliberação coletiva

**Estado.** A decisão de 07/09 (oferta confirmada: VM IPv4, Debian, backups já lá) e a nota de 05-06/09 deixam uma lista que nada mantém junta. **Verificado em 07/09 em `deploy/`**: nenhum rastro de `unattended-upgrades`, firewall nem autenticação só por chave. O resto é humano ou local: a conexão autenticada na pilha local nunca retestada desde a retirada do Turnstile; `deploy/.env` sobrescrito por `install.sh` (domínios em `localhost`) sem cópia conhecida; o teste a partir de uma rede móvel brasileira (NAT64) nunca feito; o prazo de intervenção de Les Herbes Folles nunca pedido; o meio de lhes pagar «pedido desde julho, sem resposta»; um segundo detentor dos acessos; e a regra posta em 07/09: **não se vira antes que o backup tenha ido para um terceiro** — hoje os três fluxos restic estão no próprio hospedeiro de destino.

*Verificado : [object Object],[object Object],[object Object],[object Object]*

**O que é.** Manter a lista aqui, marcar cada condição com sua prova (arquivo, e-mail, teste datado). O endurecimento entra em `deploy/`; o depósito de backup terceiro pede-se em Bolonha (**I12** diz o que o espelho frio cobre, e não é isso).

**Por que importa.** Cada condição é pequena. Juntas, são a diferença entre uma virada e uma mudança de endereço da fragilidade.

**O que conta como terminado.**

- As oito condições marcadas com prova, neste item.
- `deploy/` carrega o endurecimento, reexecutado por `bootstrap.sh`.

**Dependências.** Bloqueia **I2**. O depósito terceiro e o segundo detentor pertencem à mesma conversa que **A1** (Bolonha).

*Remissões : `claude/DECISION_herbesfolles_offre_confirmee_2026-09-07` · `claude/NOTE_sortie_services_etats_uniens_2026-09-05` · `claude/REPRISE_claude_code_PR28_revoke_anon_2026-09-06 (deploy/.env)`*

#### I30 — Uma restauração devolve um banco que funciona: os direitos de `public` e os esquemas `private` e `api`

`P1` Prioritário · Estado : **A verificar** · Carga : alguns dias · O que exige : administração de sistemas, SQL / PostgreSQL

**Estado.** Registrado no fechamento do I29. Os dois fluxos do backup #BG2 são feitos em `--no-privileges`: nenhum `GRANT`/`REVOKE`; o runbook só repõe os direitos de `ingest`. Depois de uma restauração, `public` perde os acessos de `anon`/`authenticated` e toda função recriada volta a ser executável por `PUBLIC`. Os esquemas `private` e `api` não estão em nenhum fluxo.

*Verificado : [object Object],[object Object],[object Object]*

**O que é.** Medir na produção; levar os direitos nos dumps (ou repô-los por script); incluir `private` e `api` no fluxo longo; provar em banco que uma restauração devolve os mesmos direitos e funções que a produção.

**Por que importa.** Um backup se julga pela restauração: sem os direitos, o banco volta mudo ou aberto demais.

**O que conta como terminado.**

- Os direitos de `public` voltam idênticos à produção.
- `private` e `api` estão num fluxo, ou o runbook diz e prova como são reconstruídos.
- Uma restauração de ensaio em banco devolve os mesmos direitos e funções que a produção, com controle ferramentado.

**Dependências.** Depois do **I29**. Vizinho do **B22**.

*Remissões : `deploy/ops/anarbib-bg2.sh` · `docs/journal/operations/RUNBOOK_restauration_BG2_2026-07-01.md` · `REGISTRE §BG2`*

#### I32 — Estabelecer a causa da queda de 07/10 e dimensionar a instância do banco

`P1` Prioritário · Estado : **Aberto** · Carga : uma noite · O que exige : administração de sistemas

**Estado.** Mesmo episódio. Não foi tráfego (51 requisições em 200 no último minuto), nem erro de consulta, nem implantação. Indício: PostgREST registrava « Thread killed by timeout manager » desde 17:50 UTC. Primeiro suspeito, não provado: falta de memória da instância MICRO (1 GB).

*Verificado : [object Object]*

**O que é.** Ler o relatório de infraestrutura (Reports → Database) entre 19:45 e 20:00 de 07/10; se for memória, achar o consumidor e decidir a passagem de MICRO para SMALL (decisão de custo de Xavier).

**Por que importa.** Sem causa, a queda pode voltar amanhã.

**O que conta como terminado.**

- A causa é estabelecida com provas, ou declarada não estabelecível, com razão escrita.
- O tamanho da instância é decidido por Xavier e escrito aqui.

**Dependências.** Xavier (acesso ao painel, decisão de custo).

*Remissões : `exports supabase_logs.csv du 07/10 (passerelle, 17:58 → 18:25 UTC)` · `journaux Postgres et PostgREST du 07/10` · `job backend 10213611`*

---

### J — Documentação e corpus

*O corpus é vasto e sua deriva é medida. Este backlog faz parte dele.*

| | | | |
|---|---|---|---|
| **J10** | Sete domínios entraram no v17 sem terem sido arbitrados contra seu custo de conclusão | `P3` | Aberto |

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

*Verificado : [object Object],[object Object]*

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
| I17 | 2026-09-07 | **Encerrado em 07/09 sobre o constato da experiência do §7** (`journal/operations/NOTE_experience-I17-rejeu-fidele_2026-09-07`), não sobre o código. Em `main` (`c28baac0`), sem a PR #28, imagem `supabase/postgres:17.6.1.136`, volume virgem: com A.1 (`anon` retirado do padrão de *funções* dos **dois** papéis em `01-roles.sh`, entradas verificadas não vazias) e A.2 (migrações sob `postgres`), **310/310 migrações verdes**, incluindo as de 29/08, 30/08, 02/09 e 04/09 sem nenhum `REVOKE` nem tolerância adicionados; 676 funções de `postgres`; **133 funções executáveis por `anon`, hash MD5 idêntico à produção** consultada em leitura no mesmo minuto; `pg_default_acl` sem `anon=` nos dois papéis; T8-T11 verdes. A opção B não precisou ser considerada. Aprendido: o entrypoint processa `initdb.d/*` na ordem do glob, `99-roles.sh` passa **antes** de `migrate.sh`; `cron.job` ausente na 288ª, `CREATE EXTENSION pg_cron` sob `postgres` funciona (→ `I19`). Resta **T7** vermelho: cinco vistas da base legíveis por `anon` no replay, `anon=m` em produção — levado a `B22`. O código A.1/A.2 fica para propor ao companheiro após a fusão da #28 (D7). **15/09: A.1/A.2 estão em `main`** — retomados tal e qual pelo companheiro na #28 (`f179f1ff`), medidos: 133 funções `anon`, MD5 idêntico à produção. |
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
| A2 | 2026-09-16 | **Encerrado em 16/09/2026, decisão de Xavier.** A reconstrução por alguém que não o mantenedor aconteceu: **um companheiro da ASR** (conta `ASR2026`, primeira contribuição exterior) montou a pilha em casa a partir do repositório só, escreveu-lhe o instalador (`install.sh`, PR #28, **fundida em 15/09** — `f179f1ff`) e registou o que quebrava nos seus commits (`pg_cron` ausente no arranque, esquema a inicializar sob `supabase_admin`, `GRANT` em `supabase_migrations`, `LANG_CODE`, porta 5173…), depois o mantenedor releu e fundiu **a partir dessa instalação**. Os desvios estruturais encontrados têm as suas notas (`CONSTAT_PR28…`, `NOTE_experience-I17…`, `DOC-GRANT-2/3`). O diário de execução como secção de `deploy/README.md` é posto em 16/09. A entrada 1 de `CHANTIERS_OUVERTS` fica a reescrever pelo mantenedor: **J4**. |
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
| J4 | 2026-09-21 | *(segundo item com o identificador J4 — o de `CHANTIERS_OUVERTS` §1)* **Encerrado em 21/09: a entrada 1 foi reescrita, sobre texto validado por Xavier no mesmo dia (opção A).** Continua sendo « o melhor primeiro passo », mas o objeto muda: a reconstrução por um terceiro aconteceu (06–15/09, PR #28 fundida em 15/09); falta rodar `install.sh` numa terceira máquina, limpa (I21). A entrada traz medidas datadas e assinatura. No mesmo commit: o prenome do contribuidor sai da entrada e de `deploy/README.md`; o README não lista mais o replay em CI como não provado; cabeçalho datado de 21/09; a nota de congelamento da entrada 2 vira um estado datado. **Fora do item, sinalizado**: `AIDER.md` (§ `A2`, fr, pt, en) ainda diz « ninguém jamais verificou ». |
| E17 | 2026-09-21 | **Fechado em 21/09 por decisão de Xavier.** Entregue em dois tempos: `3c411f10` (20/09) — o bloco « Explorar » nasce recolhido, lembra-se nos dois sentidos, diz o que esconde, nunca se reabre sozinho; `16d22656` (21/09) — em ecrã estreito, « Filtros » também nasce recolhido, com o seu distintivo de filtros ativos, e leva consigo a sua fila de ações. Medido a 375×812, primeira visita: primeiro título a **778 px, visível sem deslizar** (4 018 px antes de E17). A 1366×768 o bloco « Filtros » nasce aberto e o primeiro título fica a 880 px: **critério afastado por escolha de Xavier em 21/09**. Verificado em produção em 21/09. |
| E16 | 2026-09-21 | **Fechado em 21/09 sobre provas — a contradição vivia nos ficheiros de língua, não na tela.** *Lido no código*: a subpágina é um único componente (`RetentionPolicySection`), que mostra **um só aviso, sem condição** — « a exclusão automática está ativa » — desde 03/06 (`8d3dd444`). A segunda mensagem, `biblioteca.privacy.phase4aNotice` (« ainda não está ativa »), já não era usada por nenhum ficheiro de código mas continuava nas **dez** locales: foi aí que a revisão do manual a leu. *Lido na base*: a mensagem mostrada diz a verdade — o cron `anarbib-rgpd-purge-weekly` está ativo, `p_dry_run := false`, 16 passagens, a última em 20/09, `succeeded`. *Feito* (`48c413ac`): a chave morta retirada das dez locales (6 690 → 6 689) e um banco de teste de 3 casos. **O que não foi feito**: não abri a tela em `blmf-teste` (sessão necessária); o critério é cumprido pela leitura do componente. O Manual v5 pode retirar o seu aviso. |
| I23 | 2026-09-21 | **Fechado em 21/09 sobre provas — resolvido desde 20/09 sem que a ficha o soubesse.** Encontrado pelo inventário de 21/09: nenhuma sessão nomeou `I23`, embora o seu único critério — « o domínio resolve e redireciona » — esteja cumprido. *Medido em 21/09*: `https://anarbib.is/` responde **307 para `https://anarbib.org/`** (`.is`, ccTLD islandês, registado na ISNIC); `app.anarbib.is` serve a aplicação em 200; `anarbib.org.br` e `app.anarbib.org.br` fazem o mesmo desde 21/09. *No registo*: **`OPS-10`** — `anarbib.org` continua canónico, `.is` e `.org.br` são rotas de acesso, **nunca anunciadas**: nada a escrever na política de privacidade. Dois restos, que não são deste item: `www.anarbib.is` não respondeu em HTTPS na medição, e o ensaio de comutação **autenticado**, que `OPS-10` mantém aberto. |
| I26 | 2026-09-21 | **Fechado em 21/09, na mesma noite da abertura — os três « acabado quando » cumpridos, cada um com a sua medida.** Decisão de Xavier: a via da lista no repositório em vez de um quarto ficheiro de dump. *(1) A questão dos segredos*: medido em produção, **0 segredos literais e 0 URL fixas nos 38 comandos**; só um lê um segredo (`anarbib-health-probe`), na execução, em `vault.decrypted_secrets`. *(2) O que foi entregue* (commit `2237d433`, migração `20260921193147`): uma migração sozinha nada podia — restaurada com o seu histórico, fica inscrita como « feita » e não se repete; daí uma **função**, que viaja no dump com o esquema. `private.fn_crons_attendus()` leva nome, horário, comando e estado dos 38 jobs, levantados em produção (impressão md5 `bf25c87f…`, recalculada pela própria migração); `private.fn_crons_replanifier()`, SECURITY DEFINER para que os jobs pertençam a `postgres` como em produção, só toca nos jobs ausentes, diferentes ou inativos, assinala os inesperados e nunca retira nada. `restore.sh` chama-a (etapa « 3 ter »); `bootstrap.sh` repete a suíte dos crons na verificação final (controlo h) e **fica vermelho** se faltarem. A suíte `crons_planifies_tests.sql` ganha T7 e T8. *(3) Provado*: bancada SQL completa; depois **ida e volta real sobre `pg_cron`** — pilha construída a partir do repositório, despejada pela CLI (0 linhas de `cron.job` no dump, a função está lá), desmontada, restaurada: « 3 ter OK — 38 jobs », controlo (h) verde; contraprova, tabela esvaziada → vermelho, função → verde. *Em produção*: migração aplicada pela CI, `fn_crons_replanifier()` devolve `deja_en_place: 38, planifies: []`, e a impressão de `cron.job` não mudou. **O que este fecho não cobre**: a ida e volta foi feita numa pilha sem dados; a restauração de um dump da *produção* posterior a esta migração não foi repetida. |
| E22 | 2026-09-22 | **Fechado em 22/09: a folha está nomeada, a chaveta retirada, e uma guarda fica vermelha antes do build.** Encontrada contando as chavetas de cada folha de `src/`: `src/pages/painel/PanelPage.css`, linha 632 — uma chaveta de fecho que ficou sozinha quando a regra `.ab-painel-tab-divider` foi substituída por um comentário (commit `83e68421`, 15/09). Efeito nos navegadores: nenhum; efeito real: um aviso que se aprende a não ler. Retirada, `npm run build` já não devolve o aviso. `src/tests/css-accolades-equilibrees.test.js` percorre cada folha e fica vermelho nomeando folha e linha — antes do build, na CI. |
| B28 | 2026-09-22 | **Encerrado em 22/09 à noite, sobre medida.** Levantamento completo de `pg_constraint` em produção: **26 colunas em 20 tabelas** com FK para `profiles` ou `auth.users` em NO ACTION ou RESTRICT que `fn_delete_my_account` não redirecionava — `authority_proposals.proposed_by` à frente. Migração `20260922214500` (`4f68cbfe`), partindo da definição real: bloco « ATOS NOMEADOS » redireciona as 26 colunas para o token pseudônimo. Suíte `effacement_compte_fk_tests.sql`: T1 relê `pg_constraint` (lista viva), T2–T5 apagam uma conta que agiu; jogo de teste corrigido em `1fa81534` (5/5). CI verde; migração aplicada em produção. A conta de teste do ensaio se excluiu pela página às 20h54, antes da migração — não tinha proposto nada. |
| I27 | 2026-09-22 | **Fechado em 22/09: os três critérios cumpridos, os dois últimos por Xavier, cada um com a sua prova.** *(1)* `--essai`: « dry-run ok » nos três sites — depois de uma recusa instrutiva: um token só com `repository` leitura-escrita lia o repositório (`push: true`), mas o git-pages começa por `GET /api/v1/user`, que exige **`user` leitura**. *(2)* Publicação real só no domínio de recurso: `--sans-build --site https://app.anarbib.is/` → « result: replaced ». **Prova**: `https://app.anarbib.is/.version-front` devolve `68b18cf8` — um ficheiro que só `publier-front.sh` escreve, e que o canónico publicado pela CI não tem; bundle servido `index-B3w3O5ED.js`, o mesmo que em `app.anarbib.org`. Nenhuma mudança para as leitoras. *(3)* Token `publier-front-hors-forge` (`repository` leitura-escrita + `user` leitura), em `~/anarbib-ops/git-pages.token` e no Dashlane. O caminho de socorro do front existe agora de verdade — percorrido num dia calmo. |
| B27 | 2026-09-22 | **Fechado em 22/09 à noite, sobre peças: os três critérios cumpridos.** *(1)* Cumprido em 21/09 — uma chamada anónima com os argumentos do primeiro carregamento responde em **380 ms** (50 obras) e 460 ms (200), plano registado no cabeçalho da migração `20260921111344`; 3 533 ms e 27 311 ms antes. *(2)* Relido em 22/09 em `postgres_logs`, janela de 24 h: **zero `57014` em `catalog_works_v1`**; `edge_logs` na mesma janela: **337 chamadas, 337 × HTTP 200**. Nuance honesta: as 337 vêm de um só endereço, o da sonda — o « dia de tráfego real » é um dia de sonda de cinco em cinco minutos com os argumentos exatos do primeiro carregamento; nenhum visitante anónimo carregou o catálogo por obra na janela. Os sete `57014` do dia estão noutro lado: cinco leituras de `service_health_incidents` e dois `ALTER TABLE` sobre a mesma tabela, em 21/09 entre as 18h30 e as 18h39 UTC — uma espera de bloqueio numa tabela de sonda, não a RPC do catálogo; causa não levantada. *(3)* Cumprido — a sonda `catalogue_par_oeuvre` do `health-probe` (`5111ac5f`) chama a RPC em anónimo de cinco em cinco minutos, limiar 3 000 ms; o front regista o seu recuo. Suites em CI: `catalogue_par_oeuvre_cout_tests` (7 casos), banco `health-probe-catalogue-par-oeuvre` (3 casos). Fora do item: a view continua a ser o posto mais caro (`fn_library_visible_to_caller` avaliada por detenção, ~70 000 acessos a buffers por chamada). |
| F7 | 2026-09-24 | **Atenção: o identificador `F7` designa dois objetos — os treze segredos vazios (fechado em 02/09, linha acima) e este, o transporte de e-mail.** **Fechado em 24/09 à noite, com provas: os dois critérios cumpridos, e o caso (a) de `DOC-SILENCE-1` que os motivava tem um alarme.** *(1)* Sem `MAIL_TRANSPORT=mock` explícito, uma função sem serviço configurado falha com mensagem legível — entregue pela PR #30 do companheiro (`ASR2026`), merge `2cd27d71` em 23/09 após seis correções obtidas na releitura (RFC 2047, STARTTLS obrigatório com opt-in `SMTP_ALLOW_INSECURE`, corpo em base64 dobrado a 76 colunas, guarda `SMTP_HOST`, `SMTP_TIMEOUT_MS`, banco `smtp-transport.test.js`). **Prova em produção**: uma reserva e o seu cancelamento em 23/09 às 19h30 dispararam quatro e-mails por `notify-event`, registrados como « `[transport] envoi via Resend` » — a maiúscula só existe no código novo. *(2)* Uma só implementação de envio, chamada por todas as funções: as oito cópias da chamada à Resend passaram para `_shared/transport/email.ts` em três lotes (`7a2ba5e9`, `c7db27e1`, `b0ff9970`/`badf88de`/`f2c36a6f`), cada uma passando o SEU roteamento explicitamente — o módulo punha um `Reply-To` por padrão a partir do contexto, o que devolveria a `notify-library-request` o que F14 acabara de retirar; daí `routing` e `noReplyTo`. O módulo aprendeu também `toEmails` e `transportConfigure()` (a guarda de `register` exigia `RESEND_API_KEY`: uma pilha SMTP teria `MISSING_ENV` em toda inscrição). **Guarda** `mail-transport-routage.test.js`: payload fixado e lista fechada das funções ainda diretas, **vazia**; provada por mutação. Implantado em três runs verdes (#1316, #1317, #1318); impressões novas constatadas, OPTIONS 200/405. **Retificação**: `register` nunca foi silencioso — devolve `email_usuaria_enviado: false` e a página de inscrição avisa. O caso (a) real era `request-password-reset`, cujo `catch` anti-enumeração (decisão correta, mantida) engolia toda falha de transporte. **Resposta em 24/09** (`91475d06`, migração em produção `20260924180538`): o módulo anota cada falha em `mail_transport_failures` — nunca o endereço — e `health-probe` traz a sonda `mail_transport`: uma falha nos últimos 30 minutos abre o incidente, trinta minutos de calma o fecham; `kind` na CHECK e em `sondesStructurelles` na mesma entrega; tabela classificada para o backup, purgada a 30 dias; suíte `mail_transport_tests` (6/6). Constatado após o deploy: volta da sonda às 20h35, zero incidente, sonda `ok`. **Não provado**: uma falha real abrindo um incidente real — Xavier escolheu não simular; a receita de F2 continua válida. |
| I25 | 2026-09-24 | **Fechado em 24/09 sobre peças: a causa está nomeada, reproduzida e retirada.** A rede lia a saída por `echo "$out" | grep -qE ' OK : …'` sob `set -o pipefail`: `grep -q` sai na primeira linha « OK : », `echo` ainda não acabou de escrever o que se segue (« ROLLBACK »), recebe SIGPIPE, e `pipefail` faz do seu código 141 o veredicto — FAIL numa suite verde. Raro, porque esse resto cabe em poucos bytes. **Reproduzido em 24/09 fora da CI, 300 vezes em 300**, colocando 300 KB depois da linha « OK : »; **0 em 300 a partir de um ficheiro**. `scripts/ci/run-sql-suites.sh` lê agora a saída de um ficheiro (`grep -c`, nenhum tubo), e um FAIL imprime o código do psql, o do grep, o número de linhas « OK : » e o tamanho da saída. Reproduzido em local: duas suites PASS, uma suite sem balanço FAIL com a sua linha de diagnóstico. O segundo critério (« três meses sem recidiva ») fora escrito para uma causa desconhecida; a causa está nomeada. `32edb185`, `sql-tests` verde na CI. |
| F13 | 2026-09-24 | **Fechado em 24/09 sobre peças.** `sendIll` devolve o veredicto de `safeSendEmail` por `verdictEnvois` (`_shared/domain/outbox-verdict.ts`, o mesmo juiz dos sete módulos corrigidos em 21/09): `sent_count` só conta os envios aceites pelo transporte; a resposta traz `refused_count`, `refused` (endereço e causa) e `skipped_count`. O caso marcado do banco foi virado — transporte em pane: `sent_count` 0, uma recusa nomeada; um caso novo verifica as três contagens num envio a dois (2 / 0 / 0). **Nenhum caso do repositório continua marcado « DÉFAUT CONNU »**. `32edb185`, CI verde, função implantada, sondada em produção: marqueur `deployed-functions` sur `32edb185`, trois appels sans secret → 401 en 0,3 à 1,7 s à 21 h 32, la fonction démarre. |
| E15 | 2026-09-24 | **Entregue em 24/09, fechado sobre peças, com uma reserva.** Em oito locales, a palavra de « esvaziar o histórico » era a de « apagar a conta »: a palavra aprendida para um gesto abria o outro. A primeira muda, no modelo de pt-BR (APAGAR / EXCLUIR) e de ca: **fr EFFACER, en ERASE, es BORRAR, it CANCELLA, de LEEREN, nl WISSEN, el ΕΚΚΑΘΑΡΙΣΗ, eo VIŜI** — a palavra da conta não muda. Banco `confirmation-deux-gestes-deux-mots` (2 casos). Guardas i18n verdes. **Reserva**: as oito palavras são uma escolha de sessão, não de falantes (nl, el: E2) — « corrige-me »; e o manual do leitor, fora do repositório, ainda cita a palavra antiga (J9). `32edb185`, CI verde, em produção. |
| H11 | 2026-09-24 | **Fechado em 24/09 sobre peças.** Migração `20260924194818` (`f4a531ce`), gerada pelo próprio mapping do sync (`isSyncable` + `toRow` importados, nunca recopiados) a partir da aspiração de 03/09: 621 termos (**159 datas**), idempotente. **Comparada linha a linha à produção antes de empurrar**: 619 idênticas, duas diferiam (`mot136`, `mot137`: bandeira `hors_liste_cira` posta pela re-aspiração de 13h17, depois do sync de 11h07) — a produção recebeu-as na implantação, nada mais. **Verificado em produção após a CI**: 621 termos, 159 datas, impressão digital `8d1e585e67e3c5f7059532a41adabcd0` = a do rejogo local = a que a suite imprime; 332 migrações = 332. Suite `ficedl_termes_tests` (7 casos, incluindo um alinhamento para um descritor `dates`). `sql-tests` e `rejeu-image` verdes. |
| F4 | 2026-09-24 | **Fechado em 24/09: o último critério é cumprido por Xavier.** Medido em produção: `loan_cycle_notifications` tem três envios, todos sobre o empréstimo 84 — o convite a uma nota de leitura em 10/09, **o lembrete D-3 em 18/09** e **o do dia do prazo em 21/09**, uma vez cada. Xavier confirma em 24/09 que chegaram, na língua da pessoa. Fora deste fecho: o D+7 (nenhum atraso desde 31/08) — partirá no primeiro atraso real. |
| G14 | 2026-09-24 | **Fechado em 24/09 sobre peças.** Xavier relançou a pessoa; lido em produção em 24/09: o convite de 30/08 passou a **`accepted`** antes de expirar. As duas outras de 01/09: uma aceite, uma à espera de ratificação. O que o episódio diz, para **G1**: o convite por e-mail não bastou, a relance humana sim. |
| E14 | 2026-09-24 | **Fechado em 24/09 à noite, sobre peças.** Entregue em três commits, implantado e **percorrido de verdade**: às 22h55 (hora de Paris), Xavier depositou o relato `35a5dc22` a partir de `/login`, sem sessão, e recebeu o e-mail da administração; em base, a linha da fila passou a `sent` à primeira tentativa, aviso de receção incluído. Critérios 1 e 2 cumpridos; critério 3: dez locales, página titulada, formulário por teclado — **o rendimento no telemóvel não foi visto**. Duas correções nascidas do primeiro relato real: o e-mail já não cita « (E14) », e uma pessoa sem conta já não envia « Biblioteca: AnarBib ». |
| F14 | 2026-09-24 | **Fechado em 24/09: o último critério é cumprido por Xavier.** Código em produção desde 22/09. Xavier refez a prova: uma inscrição para um endereço Riseup, e o e-mail de boas-vindas **chegou à caixa de entrada principal**. Nuance: o cabeçalho `X-Spam-Status` não foi relido linha a linha; é a chegada à caixa principal que faz prova. |
| F11 | 2026-09-24 | **Fechado em 24/09: o último critério é cumprido por Xavier.** Os gestos de código estavam feitos em 22/09. Xavier olhou os e-mails no seu cliente, em tema escuro e claro, incluindo os dois nascidos em 24/09: **tudo se lê**. |
| I15 | 2026-09-24 | **Fechado em 24/09 à noite: os três critérios cumpridos.** Segredo criado por Xavier, `ci.yml` alinhado (`f0a88461`), snapshot gerado às 20h57 UTC; nenhum workflow lê já o segredo antigo, que Xavier apagou em 24/09. |
| E19 | 2026-09-25 | **Fechado em 25/09, sobre um critério reescrito por Xavier.** O primeiro « pronto quando » — « as três cartas visíveis sem deslizar num portátil » — era **impossível por construção**: o cabeçalho, a faixa, a identidade da pessoa e os vídeos tutoriais precedem o separador. **Critério reescrito por Xavier em 25/09**: *as três cartas vêm logo depois do perfil, antes de todo o resto do separador.* **Cumprido** desde `e09bf16a`: perfil, três cartas, « A minha biblioteca », endereço, o que se lê, e « Apagar a minha conta » em último. Guardado pelo banco `conta-decisions-sous-le-profil` (7 casos), verificado em produção, visto por Xavier. **Fora deste fecho**: a captura do Manual v5, fora do repositório (J9). |
| B24 | 2026-09-25 | **Fechado em 25/09, os dois critérios cumpridos.** *(1)* No repositório da vitrine (`d4a110f`): endereço e chave publicável em **`js/config.js` e em nenhum outro lugar**; as dez páginas carregam `config.js`; **`tools/garde-cles.cjs`** recusa qualquer JWT legacy, chave secreta, chave publicável fora de `config.js`, atributo `data-supabase-key` ou chave que não comece por `sb_publishable_` — provada vermelha nos dois erros, verde no estado entregue; corre no pre-push, cuja cópia versionada vive em `tools/hooks/pre-push`. Verificado num navegador e em produção. *(2)* O `CONTRIBUTING.md` da aplicação nomeia cada lugar de cada chave e a releitura dos `edge_logs` após rotação. |
| F12 | 2026-09-25 | **Fechado em 25/09, os três critérios cumpridos.** Entregue por `2a5d2642`. *(1)* O veredicto diz QUEM recusou; os oito handlers das cinco filas escrevem-no; o cron `anarbib-notify-outbox-retry` repõe com « seulement », e o transporte só serve os recusados — banco `courriels-rejeu-banc` (6 casos). *(2)* Após quatro tentativas, `abandoned`; `api.fn_outbox_acquitter` (administração da rede, razão obrigatória) fá-la sair; a sonda distingue `dont_en_rejeu` e `dont_abandonnees` — suite `courriels_rejeu_tests` (9). *(3)* Cron em `fn_crons_attendus()` (39) e na suite. Em produção em 25/09: migração aplicada, cron ativo, sete funções de envio sondadas, e le premier passage du cron, le 25/09 à 00 h 15 (heure de Paris), a réussi en 46 ms (aucune ligne en échec à reprendre). |
| I22 | 2026-09-25 | **Fechado em 25/09 — decidido « proibir e controlar » (decisão de Xavier).** A nota ⚠️ do §30 passa a 🔵, REGISTRE 0.45. A assinatura é `schema_migrations.created_by` (autor quando passa pela API de gestão, nulo pela CI — confirmado pela própria migração do controle). Migração `20260925082749`: `fn_healthcheck_deploiement()` abre o incidente `deploiement` para toda versão assinada não quitada; a quitação só se faz por migração no repositório. Treze desvios anteriores quitados nominalmente, **dois nunca rastreados** (22/09 e 24/09). Suite `deploiement_tests` (9), guarda vitest. Em produção: controle ativo e verde, 57 quitados, health-probe leu a sonda às 08h50 UTC. |
| J2 | 2026-09-25 | **Fechado em 25/09.** *(1)* A tabela do `INDEX.md` vai do v8 ao v34 sem buraco. *(2)* **`DOC-ARCH-1`** no REGISTRO (0.45, decisão de Xavier: não renomear nada, escrever a regra): o prefixo `-archive-` marca os nove arquivos anteriores à fusão de 20/05; depois, o nome de origem e a pasta bastam. |
| H13 | 2026-09-25 | **Fechado em 25/09.** Os dois arquivos no repositório (`docs/journal/ficedl/`, os de 09/09 levados a Bolonha, sha256 verificados), regeneráveis por um comando documentado no README — saída idêntica byte a byte; o CSV fica fora da conversão de fins de linha; guarda vitest que regenera e compara. A nota de 28/08 ao lado, com os três pontos superados. |
| H9 | 2026-09-25 | **Fechado em 25/09 à noite, os três critérios cumpridos.** Entregue por `f67ff3d9`. *(1)* Xavier pôs pela tela um alinhamento « mais amplo » (Anarcossindicalismo → `mot286`), lido na base, exibido « MAIS AMPLO » na página pública e exportado em `skos:broadMatch` (Turtle e JSON-LD, export real em anônimo). *(2)* `npm test` verde (878). *(3)* Bloco 4.2 invertido no mesmo dia. |
| H10 | 2026-09-26 | **Fechado em 26/09, os dois critérios cumpridos.** Releitura linha a linha dos 99 vínculos (`CONV-EXEC-3`), ficha validada em bloco por Xavier e registrada em `docs/journal/arbitrages/RELECTURE_alignements_ficedl_2026-09-26.md`: dos 54 `close`, 19 viram « mais amplo », 21 « mais restrito », 5 « relacionado », 9 confirmados; 6 `exact` exagerados corrigidos, 38 confirmados. **Oito alinhamentos para a faceta `dates`** e três alvos melhores. Migração `20260926182521`, verificada decisão por decisão; testada antes do push (leitura em produção, cópia descartável). |
| H14 | 2026-09-26 | **Fechado em 26/09 à noite, os dois critérios cumpridos.** *(1)* PMB 8.1.1.1 (arquivo oficial, SHA256 verificado) roda na máquina em dois contêineres, receita **sem cliques** no repositório (`tests/pmb/banc`): instalação, atualização do esquema, **exportação** e **importação** por HTTP. *(2)* Fixtures **exportadas pelo próprio PMB** (`tests/pmb/fixtures`): o jogo de teste do PMB (50 registros, 33 exemplares) em ISO 2709, XML MARC e XML próprio do PMB, e 14 **casos difíceis** passados pelo PMB. Latin-1: não pelo PMB (o 8.1 só instala em UTF-8) — variante transcodificada por `yaz-marcdump`, dito. O que o PMB perde ao reimportar está em `tests/pmb/README.md` (**H24**/**H27**). |
| C8 | 2026-09-26 | **Fechado em 26/09, os dois critérios cumpridos.** Duas fases por migração de dados via CI: Wikidata (607 fichas) e Library of Congress (288 ligadas, 90 completadas); regras, amostras e planilhas em `docs/journal/operations/enrichissement-autorites-2026-09-26/`; precisão medida numa amostra aleatória: 60/60. Só se preenche o vazio, com rastro por ficha. (1) Cobertura em identificadores externos: 51 % de todas as autoridades, 78 % das com três livros ou mais, 96 % das com dez. (2) Nenhuma forma de nome tocada. A língua de escrita ganhou sua coluna (503 fichas). **29/09** — O que não foi escrito fica para revisão manual, caso a caso, em `decisions.csv` (Wikidata: 96 homônimos ambíguos, 70 contradições, 88 com um só sinal, 39 não corroboradas), `decisions-lc.csv` (LC: 27 contradições) e `decisions-idref.csv` (IdRef, C4: 50 contradições, 173 não corroboradas). Um valor duvidoso está na base: E. M. Cioran, `writing_language = 'ro'` (`20260926193111`; ele escreve em francês depois de 1949), a corrigir à mão. |
| C11 | 2026-09-27 | **Fechado em 27/09 — critérios 1 e 3 cumpridos, o 2 fica como prática contínua (decisão de Xavier).** Ficha validada em bloco; fusões e reuniões de tomos feitas por Xavier no assistente (a migração que agia em seu nome foi recusada, com razão); o resto por duas migrações em nome próprio (`20260927112143` e `ee07f79c`; `20260927114232` e `6f4d7b89`): O Capital, O Homem e a Terra em seis volumes, sete famílias de tomos reunidas, Peirats devolvido à fila, matérias MLEG. Em produção: as três abas vazias; 175 notas MLEG com decisão escrita. Critério 2 não mensurável: 1 676 títulos automáticos, revisão contínua pela fila do Ateliê. |
| C7 | 2026-09-27 | **Fechado em 27/09 — critérios 1 e 2 cumpridos, o 3 dispensado por decisão de Xavier.** 851 registros indexados pelo vocabulário existente (ficha validada A + B, migração `20260927124038` pela CI): cobertura pública medida como anônimo 2 167 / 2 633 = 82,3 %. `pierre-joseph-proudhon` suprimido, `anarcocomunismo` verificado. Levar os oito assuntos à FICEDL deixa de ser pedido (decisão de Xavier, «se não criar fork»): não há fork — a cópia do tesauro tem 621 termos, todos colhidos na fonte em 03/09, nenhum acrescentado localmente, nenhum vínculo `exact` para os oito. 466 registros ficam fora do vocabulário. **05/10, inventário** — as notícias fora do vocabulário têm seu item: C27. |
| C6 | 2026-09-27 | **Fechado em 27/09 — verificado na tela por Xavier, conectado.** As três assistências da spec das convenções (§7): botão «Normalizar maiúsculas» do título, corrigido por observação de Xavier para aplicar a caixa da língua (§4.1, `1782dfcb`); assistente do ponto de acesso e normalização da caixa do nome de pessoa (`0c3bb62f`, `8c73b850`); cron semanal que alimenta a fila de verificação (`7eb72630`). Limites: o lote «titre_casse» ainda propõe a forma antiga; coletividades sem ferramenta de caixa; `name_lang` fora do formulário. **As três limitações tratadas na mesma noite:** dicionário de nomes próprios atestados + espelho SQL (171 propostas da fila refeitas, 0 divergência); `name_lang` no formulário e na separação do nome; caixa dos nomes de coletividades. |
| B10 | 2026-09-27 | **Fechado em 27/09 à noite, com provas: os três critérios cumpridos, e três guardas para mantê-los.** (1) Os avisos `multiple_permissive_policies` foram resolvidos (25 → 0): uma permissiva por (papel, comando) nas 25 tabelas, com o OU ordenado — primeiro o que não depende da linha, depois a leitura pública, depois o staff linha a linha. A impressão digital das linhas visíveis para anon e para cada uma das 20 contas reais é idêntica nas 25 tabelas antes e depois; `count(*)` em `books` sob leitor 208 → 90 ms, admin 39 → 1,4 ms. Guarda: `policies_permissives_uniques_tests` (33 testes). (2) 21 chaves estrangeiras indexadas — as de pais realmente excluídos em operação; a lista assumida do B21 passa de 38 a 17, com a regra escrita. (3) 22 índices retirados com o motivo escrito (10 redundantes nunca usados, 12 sem leitor no caminho de escrita); guarda `index_redondants_garde_tests`. Os 108 índices sem leitor restantes estão inventariados na auditoria. Novos itens: B31, B32, B33, B34, I28. Desvio registrado a `DOC-DEPLOY-4` (auditoria §7). |
| D7 | 2026-09-27 | **Fechado em 27/09: decisão escrita no REGISTRO (seção `ARCH`), com a sua razão.** **Decidido por Xavier**: um modelo arquivístico completo no AnarBib (níveis ISAD(G), produtores em autoridades ISAAR(CPF), exportação EAD desde a primeira versão), nível de descrição variável segundo o fundo, condições de acesso por nível desde a primeira versão; apresentado para parecer a DIRA, CIRA e FICEDL antes de qualquer código. Realização: **D8**. |
| I3 | 2026-09-27 | **Fechado em 27/09 — os quatro testes passam, e mais três.** O roteador `main` lançado sozinho em `edge-runtime` v1.74.0 com segredo de teste: 404 para nome inexistente, 401 sem token, com token inválido ou expirado, a função protegida executa com token válido, a dispensada não é bloqueada (responder 200 exige a pilha completa, I21). As 14 funções que exigem token são chamadas pelo app com sessão: comportamento desejado. Teste reproduzível: `deploy/scripts/essai-routeur-main.sh`. |
| C9 | 2026-09-27 | **Fechado em 27/09 — o trabalho manual restante feito.** O2: nenhuma coletividade «a rever». O8: ficha de separação validada por Xavier; migração `20260927193940` (`1948b78d`) pela CI: dez fichas separadas (seis pessoas ligadas à ficha existente, duas fichas duplas fundidas, dez criadas), três correções, «Sorel, G.» fundida em «Sorel, Georges», e dez rascunhos (lotes 8 e 63) com uma contribuição por pessoa. Verificado em produção. |
| B35 | 2026-09-28 | **Fechado em 28/09 — pelo esquema `private`, com provas.** Aberto na mesma manhã como «adiado»: o caminho do item (limitar a resposta ao perímetro de quem chama, versão interna) custava quinze chamadores e quatro políticas a raciocinar um a um. Verificado entretanto: o PostgREST só expõe `public, graphql_public, api, ingest` (PGRST106 em `private`). As duas ajudas mudaram de esquema (migração `20260928105437`, commit `6721277b`, implantada pela CI em 28/09 às 11 h 12 UTC): recriadas em `private` a partir da definição real, os quinze chamadores e as quatro políticas reapontados, as versões `public` removidas; `authenticated` mantém EXECUTE para as políticas e os gatilhos, mas nenhuma porta RPC as serve mais — o oráculo fechou sem que um corpo mudasse. Guarda na migração, T32 da suíte do B29 em contínuo, mutantes provados. Em produção após a implantação: as duas funções ausentes de `public`, presentes em `private`, lint 0029 em 441. Decisão de Xavier de 28/09. |
| B13 | 2026-09-28 | Decisão escrita no REGISTRO (`DOC-MIGR-2`, confirmada por Xavier): não se faz squash. Fatos recontados: 384 migrações, 9,0 MB, reexecução completa em 2 min 17 s (run 1418). Um squash refaz um `pg_dump` com o defeito `DOC-GRANT-2`; cada migração é um rastro citado por versão; o custo supera o ganho. |
| B31 | 2026-09-28 | Entregue pela outra sessão em 27/09 (`507afb03`): 13 relações para `anon` e 10 para conta sem adesão levantavam 42501; todas devolvem zero linhas. Verificado em produção em 28/09 sob `anon`. Suíte `lecture_accordee_sans_erreur_tests` na CI. Fechado por Xavier. |
| B33 | 2026-09-28 | Entregue pela outra sessão em 27/09 (`6bdd4331`). Verificado em produção em 28/09: `search_catalog_v1` traz o padrão único; plano — `BitmapOr` de seis `Bitmap Index Scan` nos dois índices trigram de `authors`; `publishers_lower_name_idx` serve a publicação; cinco índices sem leitor retirados (três não podiam servir consulta alguma atrás de uma policy: LIKE, ILIKE, `~` e `%` não são leakproof). Reserva: a chamada completa sob `anon` fica em 183 ms. Fechado por Xavier. **29/09** — De passagem, `6bdd4331` escapa os termos no padrão de `api.search_catalog_v1`: em produção, «c++ anarquia» ou «[anarquia» davam erro 2201B no autocompletar. Em base sintética, o autocompletar passa de 2 182 a 125 ms por chamada. |
| B34 | 2026-09-28 | Entregue pela outra sessão em 27/09 (`df4dcec1`): `fn_delete_my_account` repõe o ator de `catalog_audit_log` e as contas dos instantâneos. Verificado em produção em 28/09: 1 750 linhas, um só ator, nenhum uuid órfão. Suíte na CI. Fechado por Xavier. |
| I28 | 2026-09-28 | **Fechado em 28/09: a CI aplica as regras do hook para todas as sessões.** `src/tests/doctrine-migrations-garde.test.js` (em `npm test`, job `app`): 10 testes — nome com 14 dígitos, versão única, sem hora redonda desde 31/08 (fora uma lista fechada de 15), sem data no futuro, e a doutrina SQL do hook. Entregue em 27/09 por `89a2b508`, logo antes de B31 (`507afb03`) e B34 (`df4dcec1`); já barrou um rascunho do B33. |
| B32 | 2026-09-28 | **Fechado em 28/09, com provas, a 100 000 registros sintéticos.** Três migrações (`20260928122316`, `…17`, `…18`). *(b)* A visibilidade por biblioteca é calculada uma vez por consulta (`fn_visible_library_ids()` em InitPlan nas 21 policies) : `count(*)` em `books` sob anon 3,0 s → 52 ms, em sessão 29,8 s → 0,79 s ; visibilidade idêntica (13 tabelas, 6 identidades). *(a)* As visões do catálogo leem as visões materializadas por duas visões `private` (sem invólucro DEFINER por linha), e os índices enfim são usados. Diante da visão real, `catalog_works_v1` caía em laços aninhados (1 linha estimada para 77 000) : ela monta seu WHERE a partir dos filtros presentes, lê `volume` pela visão, toma o título de recurso no catálogo que serve, materializa `titres` e proíbe laços aninhados durante a consulta. De passagem, `catalog_search_ids_v1` devolvia `LIMIT 500` sem ordem total : `book_id` desempata. *(c)* `fn_locale_from_idioma` é inserida em linha. Quarenta percursos do OPAC idênticos antes/depois. Medidas finais, anon : página padrão 15,9 s → 1,8 s, ordenação por autor·a 11,3 → 1,7 s, lista plana por título 132 → 0,8 ms ; sessão : página padrão 54,8 → 2,2 s. Índices secundários : todos mantidos ; três sem uso a rever nos contadores de produção em um mês. Verificado em produção em 28/09 (implantado às 14:05 UTC): visibilidade idêntica para as 21 identidades; 39 percursos em 40 idênticos, o quadragésimo idêntico ao que a lógica antiga devolve sobre os mesmos dados; página padrão anônima 383 → 74 ms, busca 335 → 49 ms, `count(*)` 87 → 4 ms, página em sessão 442 → 135 ms; lint 0028 = 27, esperado. Auditoria : `journal/audits/AUDIT_catalogue_grande_echelle_B32_2026-09-28.md`. **Completado em 29/09.** Commits `46d10ed2` (b), `f4622aab` (a), `48267f27` (c); suíte `catalogue_grande_echelle_tests` (T1-T9); banco em `scripts/loadtest/catalogue-synthetique.sql` e `catalogue-mesure.sql`. Exceção assumida: `private.catalog_public_rows` e `private.catalog_network_rows` sem `security_invoker` (guarda T7 de `grants_herites_tests`). **Na mesma noite**: `api.catalog_facets_v1` monta seus predicados a partir dos filtros presentes (`cddc567b`, `20260928162102`), depois sua busca «q» passa a ser a da página (`5f13ec86`, `20260928164227`, `OPAC-F2`: «memoria» contava 9 edições nas facetas e 52 na página); `facettes_catalogue_tests` 18. Limite: as facetas continuam as do catálogo público. Auditoria §6 completada em 28/09 (`038efa8b`): a diferença das « novidades » vinha da obra 2037 editada entre dois levantamentos. O limite das facetas: item E29. |
| C12 | 2026-09-28 | **Fechado no mesmo dia, 28/09 — a pesquisa de metadados mostra uma candidata por fonte, não uma por ISBN.** Constatação de Xavier na tela: para o ISBN 8432302120, os marcadores diziam BNE 2, BnF 2, ICCU 2, LoC 1, Open Library 2, e a lista mostrava só uma candidata (Siglo XXI 1976, quando o registro traz 1991). Causa em `catalog_metadata_lookup`: `dedupeAndRank` usava o ISBN sozinho como chave, e a lista fundida era truncada em `maximumRecords` (8), que já limita cada fonte. Correção em dois commits (`78685511`, `16a4dcb4`): a chave traz a fonte, o identificador do registro nela, o ISBN, o título, o primeiro contribuidor e o ano — só o mesmo registro devolvido duas vezes se dobra; sem truncamento. Bancada `catalog-metadata-lookup-candidates.test.js` (cinco casos, 3/4 vermelhos no código anterior). Verificado em produção às 16h16 na aba de Xavier: 7 linhas para 7 resultados anunciados. |
| H27 | 2026-09-29 | **Fechado em 29/09 por decisão de Xavier.** Os três critérios: (1) a suíte SQL `aller_retour_pmb_tests` roda na CI, perdas aceitas escritas e congeladas; (2) o export tirado da base, reimportado num PMB 8.1.1.1 esvaziado: 46 exemplares de 46, 3 fascículos e 15 artigos, 61 responsabilidades, 57 autores, 36 editoras; os registros passam de 62 a 64 (as pseudo-notícias de fascículo do PMB voltam como periódicos); (3) a tabela de cobertura gerada a partir do código e dos balanços (`docs/interop/couverture-pmb.md`). Implantado em 29/09 (`2348cb86`). O que não volta — tipo, seção e código estatístico dos exemplares — passa para **H29**. **O caminho** (ficha em `66943e5a`). (0) Desde 26/09, uma ponte vitest (`src/tests/deno-tests-pont.test.js`, `66750198`) roda como estão os testes Deno do parser MARC e do export, que a CI não rodava; exige a contagem exata: 16 no início, 75 em 29/09. (1) Cumprido em 28/09 (`2ee5f7a7`, revisão `a692a75e`, migração `20260928170909`): a prova achou cinco defeitos, corrigidos — lote MARC impublicável (língua bruta contra `books_idioma_bcp47_chk`), nomes não latinos tomados por «Collectif», palavras-chave 610/653 devolvidas em 606, ISSN de artigo em 011, nível 701/702 perdido. (2)-(3) Cumpridos por `7dbd9f11` e duas revisões contraditórias: `466324aa` (periódicos antes dos artigos, 7 → 15 de 15; `$r uu`/`$q u` na 995); `2348cb86` (os dois ajustes do PMB que decidem tudo: «Gerar os vínculos» em Sim, «autoridades» em Não no PMB 8.1.1.1; e, por `20260929102719`, fascículos e tomos não são mais duplicatas numa importação MARC, 58 → 64 rascunhos); `2f488790` (`IMP-25`). Verificado em 29/09: as três funções no md5 do banco, as duas da aproximação fechadas a anon e a authenticated, as duas EF a 401 sem token; vitest 1 518, SQL 149/149. |
| Capas: a cadeia consertada, uma capa por edição, o lote, a foto na estante (CAPAS-1 a 6) | 2026-09-27 | **Entregue em 27/09, continuação em 28/09** (REGISTRO §43 `CAPAS-1` a `CAPAS-6`; nota `LIVRAISON_capas_2026-09-27.md`). A via ISBN de `cover_lookup` respondia 404 na Open Library desde data desconhecida. A cadeia consertada: URL, Inventaire, título na falta de ISBN (`2a80d43b`: 0 → 85 capas nos 267 registros sem capa com ISBN); fonte fora do ar indicada na tela (`fd5d2f0e`); procedência e licença em par (`76c6ae3f`, `20260927130518`); sonda horária `capas_sources` (`0821035a`, `6a76aa23`). Uma capa é a de uma edição (`027e6903`, `63803dea`; volumes: `3e1a3991`, `123f20e6`). O lote `cover-batch` propõe em `cover_proposals`, uma pessoa decide na tela «Capas sugeridas» (`ce2b759d`, `d37111b2`, `c89e1099`, `7dc13e5c`, `capas_lot_tests` 20); a foto na estante pela aba «Capas» do Painel (`e6fd1dc2`, `capas_photo_tests` 14). Em 28/09, uma capa nova tem um endereço novo (`d7f65c54`, `CAPAS-6`). A nota de entrega cita `e046157f` e `c89e1099` por engano: ler `027e6903`/`63803dea` e `ce2b759d`/`7dc13e5c`. **Fica fora da ferramenta**: as versões substituídas ficam no bucket até `purge-orphelins-covers.py` ser executado manualmente; as capas anteriores a 27/09 seguem sem procedência (**C16**); os dados errados levantados se corrigem no formulário, com o livro na mão (**C15**). `6a76aa23` corrige também um número publicado por `0821035a`: 5 casos de mutação em 6 caem, não 6. Capas antigas não purgadas: item J11. |
| O pt-BR fala brasileiro | 2026-09-27 | **Entregue em 27/09.** No app, 78 valores de `pt-BR.json` com vocabulário de Portugal reescritos («ficheiro» → «arquivo», «Guardar» → «Salvar», «gerir» → «gerenciar»; `faae6e0e`, guarda `PT_EUROPEU`), depois 91 valores franceses ou decalcados, por decisão de Xavier: cota → «número de chamada», notícia → ficha, flux → feed, PEB → EEB, import → importação (`dfa622f5`, guarda `FRANCES_EM_PT`; `e046157f`). Nos e-mails, 16 strings (`49047ae3`) e o texto escrito no código do relatório semanal da biblioteca (`6f762f8f`), que cria a lista fechada `TEXTE_EN_DUR_PT` (oito arquivos das Edge Functions escritos só em pt-BR, lidos pelas três guardas). **Falta**: levar essas decisões de vocabulário ao REGISTRO (**E25**). Em 27/09 à noite, `28f45047` ampliou o padrão `TU_EUROPEU`: 154 erros vistos em 163 (e-mails 58 em 61), sem falso positivo. |
| Fusão de registros: nada se perde, a referência de um exemplar segue seu acervo (DEDUP-11 a 14) | 2026-09-28 | **Encerrado em 28/09** (REGISTRO `DEDUP-11` a `DEDUP-14`, nota `LIVRAISON_fusion-notices_2026-09-28.md`). `suggest_editions_for_book` dava erro 42702 a cada chamada desde 20/06; `911ad1db` a conserta e funde BTL-TL-000880 em BTL-TL-000881 sem perda (`merge_log` 149). `11da0df8` (`20260928100501`): uma só `fn_fusion_notices` para as duas fusões, nada se perde, e três gatilhos mantêm `exemplares.bib_ref` igual à referência do acervo — 43 exemplares realinhados; `fusion_notices_complete_tests` 15/15, gatilhos verificados em produção. `40cb978f`: «Mesma edição: fundir nesta ficha» (`DEDUP-13`). BTL-TL-000881 corrigida (`96b4a104`, `bcd36f9d`), e o formulário não guarda mais as edições sugeridas do registro anterior. `8e0fe538` (`DEDUP-14`): um mesmo ISBN, de 10 ou 13 dígitos, é uma mesma edição; quatro pares desmascarados. |
| Assuntos apagados pela retomada de um registro (THES-5) | 2026-09-28 | **Encerrado em 28/09, achado e consertado no mesmo dia** (REGISTRO `THES-5`). «Editar» um registro publicado criava um rascunho sem seus assuntos, e a publicação apagava os do registro: desde junho, 136 rascunhos de retomada publicados sem assunto, 20 registros desindexados. `6cdd27a0` (`20260928133838`): `trg_seed_draft_subjects` copia os assuntos na criação do rascunho, e um rascunho sem assunto não apaga mais nada; sete registros devolvidos (`sujets_suivent_la_reprise_tests` 7). `bab3f0fa` (`20260928155533`): seis outros recuperados do backup #BG2 (seis snapshots, de 30/06 a 27/09). `e9ded1e8` (`20260928163609`): seis indexados por arbitragem de Xavier, BTL-TL-001242 fica sem assunto. |
| As siglas se buscam sem os pontos (OPAC-F3) | 2026-09-28 | **Encerrado em 28/09 à noite** (REGISTRO `OPAC-F3`, 0.51 e 0.52). «La C.N.T. y la revolución española» (BTL) e «La CNT en la revolución española» (MLEG) eram duas linhas no catálogo por obra conforme a grafia buscada. `fn_sigle_sans_points` reduz uma sigla às suas letras, primeiro em `api.catalog_search_ids_v1` (`f36b4638`, `20260928174350`), depois em `f_normalize_search`, para a busca do cabeçalho (`8d31716d`, `20260928191324`). O primeiro push parou na verificação da própria migração (530 dos 1 644 `alias_norm` vêm de outras normalizações); `36ae8d5d` ajusta `alias_norm` no próprio lugar, sem recalculá-lo. Guarda: `recherche_sigles_tests` T1-T11. **Em produção**: no levantamento de 29/09, as 398 migrações numeradas do repositório estão todas no ledger, aplicadas pela CI, `20260928191324` inclusive. |
| «Vincular a outra obra» funciona a partir da tela (OPAC-OEU7) | 2026-09-28 | **Encerrado em 28/09** (REGISTRO `OPAC-OEU7`). A tela respondia 42501 desde 04/09: `assign_book_to_work`, fechada a `authenticated` em 02/09 (B20), foi reescrita em 04/09 para a tela sem o GRANT, e a suíte a chamava como `postgres`. Direito devolvido pela migração `20260928184700` (`f36b4638`); T4 lê o direito, `solde_des_differees_tests` conta 45 fechadas — o fechamento B20 de 02/09 anuncia 47: `fn_circle_member_count` saiu na mesma noite (`20260902175631`), `assign_book_to_work` em 28/09. |
| O catálogo publicado abre a página de catalogação | 2026-09-28 | **Entregue em 28/09 a pedido de Xavier** (`0d0322c0`): parte-se do que existe antes de catalogar. A aba «Catálogo(s) já publicado(s)» abre a barra e a página de catalogação. A última aba visitada não é mais lembrada (`catalogacaoActiveTab` não é mais lida nem escrita), e o link direto `#tab=` continua prevalecendo. Guarda: `catalogacao-onglet-de-reference.test.js` (4 casos). |
| `robots.txt`: robôs de IA recusados, catálogo público aberto aos buscadores | 2026-09-29 | **Entregue em 29/09, decisão do dia** (`75ccb035`, implantado: servido em `text/plain` desde 18h55). Até então `/robots.txt` respondia com `index.html`. Agora os robôs das empresas de IA são recusados em toda parte; os buscadores percorrem o catálogo público e ficam fora dos espaços de trabalho, formulários, leitor e bancada; `Crawl-delay: 5` poupa o pool anônimo. Guarda `src/tests/robots-txt.test.js`: toda rota de `App.jsx` precisa estar classificada. |
| E3 | 2026-09-30 | **Encerrado em 30/09, os dois critérios cumpridos.** A decisão está no REGISTRO (`DOC-ADDR-1`); as dez locales aplicam o mesmo registro, cada uma com sua guarda em `src/tests/i18n-ecriture.test.js`. Os quatro últimos valores italianos no « Lei » passaram ao tu em 30/09 (`abb4aa38`), e a guarda aprendeu as duas formas. Restos acompanhados em E2 (nl, el) e E25 (pt-BR fora do app). |
| I24 | 2026-09-30 | **Encerrado em 30/09 à noite, pelo ensaio de Xavier.** Um disparo `storage` foi morto (`wsl --terminate`) e relançado sozinho pelo controle de frescor 5 min depois; instantâneo `f420f896`, testemunho enviado, nenhum incidente. Critério 1 reescrito em torno desse ensaio (o texto original era inatingível); critério 2 cumprido desde 20/09 (sonda do servidor); critério 3 coberto pelo rattrapage, pela relança, pela trava entre disparos e pela sonda. |
| F18 | 2026-09-30 | **Encerrado em 30/09, na mesma noite: a constatação era falsa.** `fede@anarbib.org` tem caixa (Xavier a mostrou no seu cliente de e-mail). Nada a corrigir. |
| F17 | 2026-10-01 | **Encerrado em 01/10.** `88dde5b3`, migração aplicada pela CI; os lembretes seguem `coalesce(extended_until, due_at)`; bancadas 13 e 8/8. |
| E26 | 2026-10-01 | **Aberto e encerrado em 01/10: a busca do catálogo não achava «Emma Goldman» nem «Vivre ma vie».** O filtro de autor·a buscava a frase inteira em `autor` (forma de autoridade «GOLDMAN, Emma»), e a busca livre não lia os títulos da obra (`work_titles`). Migração `20261001190729` (`697c81d9`): filtro palavra por palavra, sem acentos nem caixa; a busca lê os títulos da obra em todas as línguas. A obra 1163 (resumo francês de *Living My Life*) perdeu os nove títulos «auto» copiados da obra 2101 — as duas ficam distintas (decisão de Xavier). Seguimento `20261001192041` (`52ebebc1`, guarda T7). Verificado em produção e na tela. Restos: E27, C18. |
| F1 | 2026-10-03 | **Encerrado em 03/10 (decisão do Xavier).** Mapa escrito, os quatro e-mails com veredicto, ramos mortos suprimidos ou documentados (`57a4aafc`, `e897fb26`), `notify-mid-loan-reading` removida da plataforma; execuções de 02 e 03/10 verificadas. |
| C19 | 2026-10-03 | **Pedido e entregue em 03/10 (Xavier).** Uma retomada de registro, autoridade ou exemplar sem nenhuma gravação depois não fica mais na fila editorial: `retake_untouched` a marca ao nascer, a primeira escrita o retira. O editor a faz esquecer ao sair (`discard_untouched_retake`), sem lixeira nem entrada no diário; o job horário `anarbib-purge-untouched-retakes` cobre as abas fechadas (mais de 24 h). No mesmo lote, toda gravação dos três editores sobe até a mensagem de confirmação, com um toast temporário. Migração `20261003202521` (`8ccfa02f`), tela `9419fda7`. |
| E28 | 2026-10-04 | **Aberto e entregue em 04/10: uma autoridade corrigida não mudava nenhuma ficha, e a ficha 2736 mostrava o SNI duas vezes.** (1) Duplicatas criadas pelo lote `conv_revue` de 03/09 em 5 livros (2736, 412, 1282, 1541, 2316), corrigidas nos dados em 04/10. (2) `get_book_contributors_public` passa a devolver `authority_name`: um contribuidor vinculado aparece pela forma autorizada da autoridade (doutrina `CAT-G4`), a transcrição continua na menção de responsabilidade (visão ISBD). Migração `20261004212710`. Os 29 vínculos `book_authors` órfãos de outros 22 livros também foram retirados (papel ou posição vencidos; nenhum vínculo real perdido). Em 05/10, a causa foi retirada: o lote `autor_sans_autorite` vincula o contribuidor existente que se parece com a transcrição (chave normalizada igual ou similaridade ≥ 0,6) em vez de inserir uma linha duplicada. Migração `20261005071316` (`caa147be`), suíte `conv_c5` com 10 testes. No mesmo dia, Huxley (livros 359 e 360) e Grosz (livro 1023, nome desmembrado na importação) corrigidos nos dados; depois, os três outros resíduos da mesma importação: 645 (autoridade refeita, pseudônimo « Juan Crusao » como forma variante), 1187 (ilustrador com o papel `ilustrador`), 1218 (a universidade sai dos contribuidores e fica em nota). Enfim, `CAT-G4` estendido às citações e exportações: um contribuidor vinculado é citado pela forma invertida da autoridade (`sort_name`); a lista do catálogo já seguia a doutrina. Migração `20261005101227` (`8fc3c900`). Depois, uma citação só nomeia os responsáveis principais (autoria, senão direção, composição ou organização); tradução, ilustração e prefácio saem da menção de autoria (`3fc8656a`). A lista do catálogo também nomeia os coautores (migração `20261005164328`, `6bb89e0a`). Depois, uma só forma para nomear um contribuidor vinculado: o ponto de acesso em caixa natural (« Russell, Bertrand »), na ficha, na lista, na página da obra e nas citações; `editor` entra no recurso da lista (migração `20261005184801`, `15763f19`). As fichas 11326, 11327 e 11328 são material de formação, erradas de propósito. Commit da migração `20261004212710`: `af7b7ead`. As quatro transcrições em maiúsculas: C3. |
| F20 | 2026-10-04 | **Encerrado em 04/10.** `7a00b054`, migração aplicada pela CI, verificada em produção: os três crons de reserva usam LEFT JOIN e os prazos padrão das colunas (14 d, 21 d, 24 h) quando a biblioteca não tem linha de política. Suíte 6/6, mutante morto. |
| E27 | 2026-10-04 | **Encerrado em 04/10, verificado na tela em 05/10.** `5e97a77b` (migração `20261004211159`, CI verde). As sugestões da busca rápida (`api.search_catalog_v1`) leem os títulos da obra (`work_titles`), rótulo «Living my Life (Vivre ma vie)»; índice trigrama em `f_normalize_search(title)` mantém o custo de antes. Bancada local: 407/407 migrações, 159/159 suítes (T9 nova). |
| C20 | 2026-10-05 | **Constatado e entregue de 04 a 05/10 (Xavier): o catálogo diz o que se lê online.** 19 livros com PDF público ativo não tinham indicador; `catalog_digital_access_v1` serve o acesso real; selos « Ler / Ouvir / Ver online » e « Reservado a leitor(a/e)s de … »; a ficha diz « RESERVADO » em vez de « NÃO » e traduz os direitos; a administração da rede lê os PDF reservados. Migração `20261004215035` (`6738b02f`), telas `d8a5b5f4`, `14cdd0db`; verificado em produção em 05/10. **05/10, inventário** — no mesmo dia, C25 achou e reparou um defeito de leitura reservada (`/livro/2287`). Que seja o que Xavier apontava aqui não está estabelecido: confirmar na tela (E31). |
| C21 | 2026-10-05 | **Entregue em 05/10.** Barra de estado fixa nos onze painéis da catalogação; janela de confirmação do aplicativo no lugar dos 34 `confirm()`/`alert()`, com o botão nomeando a ação; gestos sobre os lotes confirmados. `9da1ad76`. A verificar na tela com sessão staff. **05/10, à noite** — o botão do cabeçalho diz « Atualizar o catálogo », e quatro rótulos de erro duplicados em cada locale ficam com uma só entrada; guarda `i18n-cles-uniques` (`a64bd04f`). Olhar na tela: item E31. |
| C22 | 2026-10-05 | **Entregue em 05/10.** Um único quadro « Publicado — e agora? » substitui mensagem, toast, faixa e janela obra/edição; sequências propostas para documento, autoridade e exemplar. `b0f60399`. A verificar na tela. O olhar na tela fica com E31; « completar as autoridades não ligadas », com C3. |
| E23 | 2026-10-05 | Cada HINT `error.*` do banco tem seu rótulo nas dez locales: guarda (as mesmas 210 chaves da produção), 780 rótulos, quatro achados pela guarda no mesmo dia (`2414246c`). |
| C24 | 2026-10-05 | **Entregue em 05/10.** Depósito digital em cinco etapas (o quê, direitos, quem lê, arquivo ou link, descrição); espaço de armazenamento deduzido; leitura pública de obra sob direitos só se a coordenação da biblioteca a abriu, com aviso e justificativa; publicação sem recriação (links estáveis). Migração `20261005092916` (`d1d72405`), tela `6c3ab382`. Em 05/10, os PDF órfãos do acervo histórico do CCLA foram vinculados: 24 rascunhos pré-preenchidos no lote « Acervo histórico CCLA — PDF a catalogar » da BLMF e o cartaz do 1º de Maio de 2002 na notícia 2722 (`20261005123453`, `66cf8d9b`); as 7 duplicatas foram apagadas à mão por Xavier em 05/10 (verificado no banco): nenhum órfão no espaço público. **05/10, inventário** — cada resto tem seu item: olhar na tela (E31), os 24 rascunhos do acervo CCLA (C26), o recurso posto por recepção de fundo (D9). |
| C25 | 2026-10-05 | **Aberto e entregue em 05/10: um PDF restrito não aparecia como legível para membro de uma biblioteca detentora (`/livro/2287`).** O arquivo tinha sido enviado ao balde público e o recurso repassado a « restrito » sem que o arquivo acompanhasse. Corrigido à mão (arquivo movido para `pdf-restrito`, cópia pública removida); a base passa a recusar um recurso cujo arquivo não existe no lugar declarado, e a tela avisa quando a cópia antiga não pôde ser removida. Migração `20261005121942` (`3ee267fa`). |
| E24 | 2026-10-05 | As recusas das três funções da página Importações têm código traduzido nas dez locales; banco e recenseamento das outras funções (`17eb498b`). |
| G17 | 2026-10-05 | A cooptação não encontrava uma conta sem biblioteca (RLS de `profiles`). Função reservada à administração da rede, endereço exato; suíte de 5 testes (`4d417f98`). |
| F22 | 2026-10-05 | O link de confirmação da Carta mostrava código HTML: as Edge Functions são servidas em text/plain. Redirecionam (303) para a página `/lettre` do aplicativo (`9fc60a15`). |
| E25 | 2026-10-05 | O guia de governança, a carta inclusiva e o DPA falam português do Brasil; 30 valores de `pt-BR.json`; coletânea PDF v1.3 no bucket; decisões de vocabulário no REGISTRE (`DOC-LEX-2`) (`0cc2b6d3`). O guia em espanhol: item E30. |
| G18 | 2026-10-05 | Um admin da rede sem biblioteca: cinco páginas carregavam sem fim, o link de um e-mail aberto sem sessão perdia a página, a etiqueta dizia « Leitor·a », faltava « Minha conta ». Corrigido e verificado em linha (`43f8481e`, `43359867`, `8a1d2663`, `26142551`, `d147224e`). **05/10, à noite — um sexto defeito do mesmo percurso**: o « Meu espaço de contribuidor(a/e) » de uma conta sem biblioteca não tinha « Minhas bibliotecas »; a página agora monta a aba (`f3694408`). |
| E9 | 2026-10-05 | As grades encolhem com o contêiner e uma guarda lê toda grade de `src/` (`5865a281`); os cartões são sem objeto. As 25 media queries herdadas voltam à escala **ao sabor dos retoques** (`MOB-3`). Decisão de Xavier, 05/10. |
| C10 | 2026-10-05 | **Fechado em 05/10** (`61c82d85`): o estado de revisão de `digital_assets` se chama `review_state`; seis funções reescritas a partir da definição real; saídas, aplicativo e Edge Functions acompanham, um pacote antigo continua legível; a armadilha `access_scope` é lembrada no formulário. Visibilidade inalterada (mesma impressão antes e depois). |
| G13 | 2026-10-05 | **Entregue em 05/10** (`6fca3f3b`): vocabulário `public.networks` e leitura do campo `reseau` da ficha do mapa; função pública do catálogo; o catálogo filtra por rede (verificado em linha: « FICEDL (BLMF, BTL) »). **Para Xavier**: classificar ABABA, FAO, AFI, UK Social Centre Network e Radical Routes. **Os cinco redes que faltavam classificar foram classificadas na mesma noite** (`43eec639`, migração `20261005180958`, decisão de Xavier): ABABA em documentação, FAO e AFI em organização política, UK Social Centre Network e Radical Routes em « outro ». |
| D6 | 2026-10-05 | **Fechado em 05/10** (`5bbdaaf4`): epub.js mantido e fixado em `0.3.93`, xmldom forçado para 0.8 (nunca usado no navegador); foliate-js designado como substituto; um teste abre um EPUB 3 completo. |
| I29 | 2026-10-05 | **O esquema `ingest` entra no fluxo longo do backup #BG2 — entregue e em serviço em 05/10, decisão de Xavier** (`f5e3f5ed`). Nenhum fluxo salvava `ingest`; agora um único `pg_dump --schema=public --schema=ingest`, mesmo arquivo, filtro de classificação nos dois esquemas, 11 tabelas classificadas, RUNBOOK e REGISTRO atualizados. Prova em banco privado; `anarbib-bg2.sh check` → «Filet OK». **Falta**: o primeiro backup longo com ingest, domingo 11/10 às 20:00. |
| B29 | 2026-10-06 | Os rascunhos pertencem à sua biblioteca, constatado em produção em 28/09: a coordenação edita seus 1 673 rascunhos e os outros 147 lhe são recusados; a administração da rede vê tudo; `CAT-E18` realizado (suíte de 32 testes). **Fechado em 06/10 por Xavier com base nessas constatações.** |
| B30 | 2026-10-06 | Cada lote tem sua biblioteca: as políticas de `catalog_batches` comparam `library_id`; constatado em 28/09 e em 05/10 (quatro lotes); a suíte do B29 segue verde. **Fechado em 06/10 por Xavier com base nessas constatações.** |
| H17 | 2026-10-06 | O mapeamento UNIMARC retoma as zonas correntes do PMB: zonas testadas, tabela de cobertura gerada e guardada. Importação real e fascículos ligados ao periódico: H28. **Fechado em 06/10 por Xavier com base nessas constatações.** |
| H18 | 2026-10-06 | As responsabilidades importadas mantêm papel e natureza, aproximações propostas na revisão, testes escritos. Prova numa importação real: H28. **Fechado em 06/10 por Xavier com base nessas constatações.** |
| H19 | 2026-10-06 | Os exemplares importados seguem sua notícia: critérios cumpridos em bancada, 46/46 na reimportação (`IMP-25`). Importação real da DIRA: H28. **Fechado em 06/10 por Xavier com base nessas constatações.** |
| H22 | 2026-10-06 | O leitor do XML do PMB foi entregue (`8c80de27`) e implantado em 28/09; formato `pmb_xml` admitido pela CHECK. **Fechado em 06/10 por Xavier com base nessas constatações.** |
| H23 | 2026-10-06 | Exportação UNIMARC (ISO 2709 e XML), espelho exato da importação: uma só tabela de correspondência, ida e volta idêntica das 64 notícias. **Fechado em 06/10 por Xavier com base nessas constatações.** |
| H24 | 2026-10-06 | A exportação de uma biblioteca contém tudo o que ela catalogou: critério 1 provado em 29/09 (H27), critério 2 por `export_catalogue_tests`. Tipo, seção e código estatístico: H29. **Fechado em 06/10 por Xavier com base nessas constatações.** |
| F16 | 2026-10-06 | O convite a uma tarefa enfim cria um convite (`32cfea66`); suíte 6/6; as marcas `convite:` não aparecem mais. Um convite real recebido: E31. **Fechado em 06/10 por Xavier com base nessas constatações.** |
| F21 | 2026-10-06 | Rodapé e status dos e-mails na língua da biblioteca: uma chave `wf.stage.*` por etapa nas dez línguas, sem rodapé nem assinatura em português por padrão (PR #31 do camarada, `9bdce13a`); bancadas 9 + 4. E-mail real em francês e nome de remetente padrão: F24. **Fechado em 06/10 por Xavier com base nessas constatações.** |
| E29 | 2026-10-06 | As facetas de uma sessão contam o catálogo que a página mostra (`4b27b909`, migração `20261006170736`, verificada em produção às 19h27; suíte T8; impressão de 20 conjuntos de filtros idêntica). **Fechado em 06/10 por Xavier.** |
| F23 | 2026-10-06 | As 22 consultas anteriores a 01/10 ficam sem prazo: estão todas encerradas; a regra dos 60 dias vale para os pedidos novos. Nenhuma migração. **Decisão de Xavier, 06/10.** |
| H25 | 2026-10-06 | **Fechado em 06/10 por decisão de Xavier.** A exportação de autoridades reimporta-se no PMB 8.1.1.1 com «Não»: autores aproximados por nome e datas, nenhum recriado; o vínculo pelo `$3` não funciona por um defeito do PMB (a origem não é transmitida pelo formulário) — sinalização e correção para a DIRA em **H32**. |
| H20 | 2026-10-06 | O identificador de origem é guardado por biblioteca (`book_external_ids`, `8c80de27`); critérios cobertos por `identifiant_origine_tests` T10 e T3 na CI. **Fechado em 06/10 por Xavier.** |
| E35 | 2026-10-06 | **Aberto e entregue em 06/10, sobre três sinalizações de Xavier na tela** (`2ce1bad5`, migração `20261006194628`, verificado às 22h18). (1) Um leitor da BLMF via o exemplar da BTL « Disponível »: não há empréstimo entre bibliotecas, toda linha de outra biblioteca diz « Indisponível para você ». (2) « Confederación » não achava a notícia digitada « C.N.T. »: as duas buscas leem também o nome de autoridade exibido (8 → 9 notícias). (3) `sob_direitos` fixo no leitor PDF: o selo usa o rótulo dos direitos da ficha, dez locales. A quarta sinalização não era falha: a administração da rede lê um PDF reservado, decisão de 04/10. **Resta** ver na tela a linha BTL para uma conta BLMF (E31). *Levado ao backlog em 07/10, no inventário.* |
| B37 | 2026-10-06 | **Aberto e entregue em 06/10** (`1fafc35b`, migração `20261006202320`, verificado às 23h02): **34 funções SECURITY DEFINER sem chamador sob `authenticated` fechadas** — o aviso 0029 passa de 451 a 418. Nove ficam abertas de propósito (7 da lista T10, as duas RPC `fn_outbox_*`, `fn_import_row_comparison`). A guarda da migração reverifica na implantação. Suíte `aides_definer_fermees_tests`; T2 de `b14_oracle_existence_forme` corrigido (premissa falsa). 0028 = 29 = T10; 0011 = 1, voluntário. Complemento na auditoria. *Levado ao backlog em 07/10, no inventário.* |
| I31 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier, os três critérios cumpridos com envio real.** Testemunha de queda fora do banco: a cada cinco minutos, do posto, leitura REST e saúde do Auth; após dois falhos, e-mail pela API da Resend sem tocar no banco; um segundo na volta. Cego se o posto está sem rede; recusa sem configuração. Bancada de 8 casos. Prova real às 20h50: dois e-mails (Resend 200) recebidos em `admins@anarbib.org` e `anarbib@proton.me`. Consignado: não vê a causa (I32) nem uma queda de menos de dez minutos. |
| Dois tomos diferentes nunca são uma duplicata, nos três detectores; cinco tomos catalogados duas vezes fundidos (DEDUP-15) | 2026-10-08 | **Encerrado em 08/10** (REGISTRO `DEDUP-15`). Relatado por Xavier na lista plana do catálogo (a visão por obra agrupa os tomos; a opção «Lista plana» ficara gravada). Medido em produção: a varredura global descartava dois tomos diferentes desde o lote 4 (04/09), mas `suggest_book_duplicates` (o assistente numa ficha) e `api.suggest_draft_duplicates` (o formulário) não liam o tomo — 64 pares de tomos diferentes propostos por engano. Migração `20261008185800`: os dois detectores calculam a ordem do tomo como a varredura e excluem duas ordens conhecidas e diferentes; um tomo desconhecido de um lado continua candidato. Suíte `tomes_jamais_doublons_par_notice_tests` (7). Migração `20261008185801`, com acordo escrito de Xavier e sob sua identidade como em C18: cinco pares de mesma edição e mesmo tomo, em duas bibliotecas, nunca fundidos em 31/08 porque o tomo estava escrito de outro modo («1» / «I», «Vol I» no título) — Thomas, *A guerra civil espanhola* 1964, tomos 1 e 2; *Os Sindicatos operários e a Revolução social* vol. 1; *Rebeldias* vol. 2 e 3. Ficha mais antiga mantida, acervo MLEG com seu próprio número de chamada, nada copiado da ficha MLEG, um assunto recuperado. **Falta a uma mão**: 28 pares entre bibliotecas de mesma edição sem tomo de nenhum lado, candidatos comuns a decidir no assistente; um só par em que só um lado tem tomo (BTL-TL-000294 / BLMF 0000098). Mais tarde, com acordo escrito, migração `20261008201703`: os dois pares com o mesmo ISBN dos dois lados fundidos, ficha BLMF mantida — Goldman (2377 ← 1501) e Reclus (2275 ← 1968). Depois, com acordo escrito, migração `20261008204237`: os 25 pares restantes relidos ficha a ficha e fundidos (BLMF mantida se presente, senão BTL; acervo MLEG com seu próprio número de chamada; 14 assuntos e 2 contribuidores recuperados). *A Internacional* fundida por Xavier na tela. Os 28 pares do levantamento estão resolvidos. À parte: os tomos de *Acción directa anarquista* (obra 38, BTL e MLEG) não são propostos por nenhum detector e sua numeração não coincide — com os livros na mão. |
| E34 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** «Editar» um registro de consulta o torna emprestável na publicação: a retomada esquece `circulation_default`. *Histórico*: 07/10 — aberto por constatação do lote 5 de H21. **08/10 — entregue e verificado às 19 h 37** (`52fd90e2`, migração `20261008172304`). A reprise não copiava `circulation_default`; o gatilho de publicação reescrevia circulação e `loanable` a partir do rascunho. O que protegia: a tela recalcula a circulação a partir de `loanable`; em produção nenhuma das 12 notícias em consulta mudou por este caminho; os « 11 rascunhos divergentes » não são este defeito — nada a corrigir. Entregue: a cópia recopia `circulation_default`; verificação final: toda coluna comum a `books` e `book_drafts` é copiada. Suíte de 5 casos, mutante vermelho. **Fechamento a decidir por Xavier.** |
| H32 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** Sinalizar ao PMB que o formulário de importação não transmite a origem das autoridades, e dar à DIRA a correção de uma linha. *Histórico*: 06/10 — aberto no fechamento de H25, por decisão de Xavier. **08/10 — redigido, provado na bancada, entregue** (`4c2d1c32`). (1) O relato para a PMB Services está escrito (`docs/interop/signalement-pmb-origine-autorites-2026-10-08.md`): a linha em causa, a variável lida, a correção de uma linha, a medida. (2) O passo a passo para a DIRA está em `tests/pmb/README.md`. (3) A correção de uma linha foi provada na bancada: 61 responsabilités sur 61 rattachées à leur fiche AnarBib par le ``, 61 liens notice → source d'autorité, 0 vers une source absente, 0 auteur recréé — chiffre pour chiffre le bilan « origine transmise » du 29/09 (`h25-origine-transmise`) ; sans le correctif, le même import « comme le navigateur » donne 0 sur 61 et 44 liens vers une origine absente (`h25-comme-le-navigateur`). **Resta** o envio, por Xavier. |
| E33 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** Quando o banco não responde, Minha conta diz que o serviço está indisponível em vez de uma página vazia. *Histórico*: **07/10 — entregue e verificado às 21 h 48** (`312f91cc`). Causa: sem timeout no cliente, `ContaRouter` esperava três respostas e renderizava `null` sem fim; com 522 rápido, montava a página com perfil nulo. Entregue: `ServiceIndisponible` (dez locales), roteador e página limitados a doze segundos, `ErrorBoundary` em torno das abas. Bancada 6 casos. **Fechamento a decidir por Xavier.** |
| D9 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** Um recurso posto por recepção de fundo desaparece na publicação seguinte do rascunho. *Histórico*: **06/10 — decisão de Xavier: « manter o que ela ignora ». Entregue e verificado em produção às 20h13** (`0dae3d10`, migração `20261006175037`). Um recurso publicado só sai se o rascunho o tiver retirado ou inativo, ou o tiver apagado (rastro em `book_drafts.digital_resources_removed`). Efeito vizinho resolvido: publicar um rascunho sem retomada (importação) esvaziava a notícia. Suíte T8; `sql-tests` vermelho por uma comparação com captura fixa (`aller_retour_pmb_tests` T5), corrigida (`81c17016`). **Critérios cumpridos; fechamento a decidir por Xavier.** |
| J11 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** Faxina: guardas duplicadas, script morto, capas órfãs, restos do e-mail e do lote C5. *Histórico*: **06/10 — quatro restos de cinco resolvidos.** Guarda duplicada e script morto retirados (`4b8ddebc`); restos do F1 suprimidos com autorização escrita de Xavier (`fe10098d`, migração `20261006190649`, verificada em produção; a tabela saiu também da denylist do backup, hors repositório); as duas views do lote C5 alimentam um relatório ativo: mantidas. Capas: 7 originais órfãos (não 358) — a purga cabe a Xavier. **06/10 — capas purgadas por Xavier**: 12 objetos (6 originais + 6 miniaturas), 778 KB, 0 falha; `books/0000280/front.jpg` mantida. Os cinco restos tratados. **Critérios cumpridos; fechamento a decidir por Xavier.** |
| F24 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** O nome de remetente padrão dos e-mails está em português. *Histórico*: **06/10 — decisão de Xavier: « AnarBib » só. Entregue e implantado** (`7aa8e8c4`, `c952704a`); guarda `mail-expediteur-par-defaut`; `notify-event` v1742 com `|| "AnarBib"`. O segredo `SENDER_NAME` foi posto em « AnarBib » por Xavier em 06/10. **Falta**: ler um e-mail real em francês. |
| H30 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** «Reprocessar» uma importação sem arquivo (coleta OAI, candidato, depósito direto) não apaga mais as linhas. *Histórico*: 01/10 — aberto na entrega do lote 0 de H21 (constatação de revisão, provada na bancada). **05/10 — entregue** (`324a49a5`, migração `20261005064758` aplicada pela CI; edge functions implantadas): `fn_import_dispatch` recusa na hora «Reprocessar» quando o arquivo não está em `storage.objects` (HINT traduzida, 10 locales); as duas edge functions leem e analisam o arquivo antes de apagar e, se falharem antes do apagamento, mantêm linhas e estado (diário, 409). **Registrado**: a tela não lê `error_log`; uma falha DEPOIS do apagamento ainda perde as linhas; a janela de **H31** aumenta. |
| H31 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** «Reprocessar» julga a importação no momento de apagar, não só no envio. *Histórico*: 01/10 — aberto na entrega do lote 0 de H21 (provado na bancada; largura da janela não medida em produção). **05/10 — entregue** (`9942be20`, enviado por engano com a mensagem provisória «wip(h31)»; migração `20261005124652` aplicada pela CI): o apagamento das linhas no reprocessamento passa por uma função que trava a importação e rejulga a guarda; promoção, vinculação, decisão, anexação de arquivo recebido e exclusão da importação usam a mesma trava; um pacote com arquivo já anexado não se reprocessa mais. Provado com duas sessões. **Registrado**: uma promoção grande faz os outros gestos esperarem até 8 s; dois «Reprocessar» simultâneos não são recusados; «Run N introuvable» sem HINT. |
| F6 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** `notify-internal-task` corre sobre uma cópia congelada de toda a pilha de e-mail. *Histórico*: 30/08 — levantamento feito ficheiro a ficheiro, depois da abertura do item: 9 ficheiros duplicados e todos divergentes, ~694 linhas, e **uma única divergência com efeito observável** — a assinatura de rodapé não traduzida, **fechada na mesma noite e guardada por 6 testes**. A origem das cópias não tem resposta no repositório: estão no primeiro commit. O que resta é uma decisão de alcance, não uma medição. **31/08** — no dia seguinte à reunião, e no âmbito deste item, `20260831073104` deu a `painel_internal_tasks.status` os sete estados dos e-mails, com uma CHECK e `aberta` como padrão — a tabela estava vazia. **29/09** — esse segundo gesto tinha quebrado a criação de tarefas: cinco funções ainda escreviam ou filtravam `pendente`, e nenhuma tarefa interna pôde nascer durante quatro semanas (23514). Achado por Xavier na tela; corrigido por `455c7f0b` (migração `20260929095411`, suíte `taches_sept_etats_tests`, 7 testes; `src/lib/taskStatus.js` e o teste `task-status-vocabulaire`, que compara as listas da tela com a CHECK). Os quatro critérios estão cumpridos ou sem objeto desde a reunião de 30/08. **Falta verificar**: que um aviso de tarefa real saia pela função reunida — a tabela estava vazia em 31/08, e nenhuma tarefa pôde nascer depois até 29/09. |
| F15 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** Os e-mails institucionais às admins da rede só chegavam a uma caixa pessoal — uma única resolução de destinatários, com a caixa coletiva. *Histórico*: 24/09/2026 — e-mail recebido às 21h46 lido; `sendToAdmins` lido; uma admin ativa contada na base; `HEALTH_ALERT_CC` presente nos segredos, `NETWORK_ADMIN_CC` ausente. **Entregue em 24/09 à noite**: módulo + seis conversões + modelos de ambiente + guarda e bancadas. Falta o primeiro critério: um e-mail real lido na caixa, por Xavier. |
| G16 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** O voto das transições (mudar um modo de funcionamento de uma biblioteca) não fala a língua do banco. *Histórico*: **05/10 — entregue, implantado e verificado em produção às 12h39** (`f93667ac`). Decisão de Xavier: manter a abstenção (regra da cooptação). Dois defeitos a mais: o tipo 4 nunca fechava, e o tipo 2 aceito por maioria falhava no voto vencedor. Suíte 12/12, três mutantes mortos. **Falta**: um voto real visto na tela. |
| C14 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** Um exemplar que muda de biblioteca leva tudo consigo. *Histórico*: **05/10 — entregue, implantado e verificado em produção (`07ad68af`, migração `20261005074236`, pela CI).** Rascunho aberto antes da mudança do exemplar: recusado na publicação. Reatribuição recusada enquanto houver reserva ativa no fundo. EEB declarado devolvido ou cancelado à mão fecha suas linhas; as duas linhas dos EEB 24 e 25 foram reparadas. Fundos vazios: regra de CAT-E19 no descarte e na mudança de um exemplar (`private.fn_fonds_vides_menage`, fechada a `anon` e `authenticated`). Lixeira sem 23503. Suíte 17/17, sete mutantes mortos, CAT-E19 18/18, vitest 1 865, lint 0 erro. **Falta ver**: os contadores dos fundos BTL 173 e 2426 ainda mostram «0 disponível» — o recálculo noturno (04h43) deve corrigi-los, reler em 06/10; e um olhar do Xavier nas duas recusas na tela. **Visto de passagem, fora de C14**: `publish_exemplar_draft` não cria o fundo da biblioteca de destino; mover um exemplar para uma biblioteca sem fundo da notícia falha em `exemplar_library_holding_mismatch` bruto. **05/10, à noite** — o defeito « visto de passagem, fora de C14 » virou **C23**, entregue no mesmo dia (`16962c55`). **06/10** — contadores relidos após o recálculo das 04h43 UTC: fundos BTL 173 e 2426 com 1 disponível de 1. Falta o olhar de Xavier nas duas recusas (E31). |
| C23 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** Um exemplar movido pela publicação encontra, ou cria, o fundo da sua notícia na biblioteca de destino. *Histórico*: **05/10 — entregue** (`16962c55`). Suíte 6/6, mutante morto, vitest 1 871. Falta um deslocamento visto na tela. |
| J9 | 2026-10-08 | **Fechado em 08/10 à palavra de Xavier.** Manual v5: o restante das capturas — 180 posições em recuo pt-BR, IMG-31 a refazer, IMG-08 a confirmar, tudo a recapturar em 900-1000 px. *Histórico*: 07/09 — manuais .md na v1.1 e branch removido (feito); capturas não verificáveis daqui. |
| F3 | 2026-10-08 | **Fechado em 08/10: Xavier suprimiu `read-pdf` e `mail-i18n-test` no painel — verificado: 50 funções, nenhuma das duas.** Consolidar as funções de notificação redundantes. *Histórico*: 31/08 — `mail-i18n-test` continua implantada (versão 1 566). O repositório tem 50 pastas de funções e 38 declarações `verify_jwt`. 24/09 — `mail-i18n-test` continua no repositório e no `config.toml`, portanto implantada. Desde F7, um só transporte: F1 e esta consolidação ficaram mais baratos. 29/09 — Desde `6f762f8f`, o texto escrito no código dos dois relatórios semanais é lido por `mail-ptbr-voce.test.js` (lista fechada `TEXTE_EN_DUR_PT`): uma função de resumo consolidada deverá entrar nela. **05/10 — vereditos escritos, duas funções retiradas do repositório** (`82afd616`). Recapitulativos, leitores e exportações: separados com razão escrita; `read-pdf` e `mail-i18n-test` retiradas (nenhuma chamada em oito dias). **Falta (Xavier)**: suprimi-las da plataforma. **08/10 — verificado: `read-pdf` e `mail-i18n-test` ainda implantadas.** Xavier as suprime no painel; depois verifico e fecho. |
| Locales: uma chave presente nos dez arquivos está traduzida | «A paridade das chaves, guardada na CI, basta» (ponto cego 2 da guarda código ↔ locales, nomeado em 27/08 e deixado aberto) | **Falso.** Em 08/10, a aba Livros da catalogação mostrava «Painel de revisão da ficha» em espanhol, italiano e alemão. A varredura «valor estritamente igual ao pt-BR» encontrou **607 valores** copiados tal qual em es, it, de e en — guias por tipo de documento, rótulos de campos, placeholders, mensagens, contadores da página Configurações, estados do painel de empréstimo —, traduzidos em seis commits (`89534f93`, `88b2f408`, `801c3d93`, `fbc82403`, `c6cb5a00`, `be119b1e`) com a terminologia de cada locale (e o «-e» inclusivo do espanhol: «le autore» não é italiano). O vetor: os scripts `i18n-add-*` põem pt-BR nas dez locales para manter a paridade, e o «traduzir depois» não acontece. **Guarda** desde a mesma noite: `locales-valeurs-copiees-de-pt-br.test.js` (`78d9c4b8`, `055cc326`), dois caminhos — frases nomeadas chave a chave, palavras por vocabulário de homógrafos por locale (887, relidos um a um), listas fechadas nos dois sentidos, provada vermelha por mutação; `DOC-I18N-3` no registro (v0.78, v0.79). ca, eo, nl, el não tinham nada a corrigir: seus idênticos são homógrafos. |
| G19 | 2026-10-09 | As coordenações escrevem umas às outras no AnarBib: lotes 1 a 4 e 4 bis entregues e verificados em 08 e 09/10 (CORR-1 a CORR-6) — dados e RPC só para coordenações ativas (a administração não lê), aba « Correspondência », sino e e-mail ao endereço coletivo das outras bibliotecas do fio, línguas lidas declaradas na Identidade com língua comum proposta, lista calculada no banco. **Primeiro fio real em 09/10**, BLMF → BTL: visto na tela, sino recebido do lado da BTL. **Sem tradução automática** (decisão de Xavier): lote 5 congelado. **Fechado em 09/10 por Xavier.** |
| C17 | 2026-10-09 | **Fechado em 09/10 por decisão de Xavier («Passe-o a fechado»), os dois critérios cumpridos, o olhar na tela adiado para E31.** Decidir se um número de tombo apagado pode ser dado de novo. *O que contava como pronto*: a regra está escrita no REGISTRO · se um número nunca deve ser dado de novo, uma suíte SQL o prova. **Decidido em 08/10: um número dado nunca se redá** (REGISTRO `CAT-E21` — um número é um rastro; retirado, desbastado ou criado por engano, continua tomado). **Feito em 09/10, implantado e verificado às 21h59** (`5a5a94d6`, migração `20261009194632`): `public.tombos_attribues`, o registro de todos os números já carregados por um exemplar, retomado do acervo (2 762) e do diário das exclusões (13 números, incluindo os cinco já redados — a história fica escrita, não se repete mais); dois gatilhos em `exemplares`: um número já dado que nenhum exemplar presente carrega mais é recusado (`error.catalog.tombo.deja_attribue`, dez locales), todo número posto entra no registro; `fn_next_tombo` devolve o maior número já atribuído, acervo e registro. Suíte `tombo_jamais_redonne` 6/6, mutante sem o registro vermelho (4/6). Tabela fechada a `anon` e `authenticated` (um aviso 0008 a mais, intencional), no levantamento de 09/10. **Visto em 10/10 por Xavier**: recusa traduzida ao publicar com um tombo liberado. O mesmo teste revelou dois buracos, tapados na mesma noite (C17 bis): o rascunho recusa desde o salvamento um tombo já dado ou usado ; publicar sem documento se diz. Suíte 9/9. |
| I33 | 2026-10-09 | O checkout de operação segue `main` sem gesto humano: o disparo do espelho o avança em fast-forward só se estiver em `main`, limpo e sem script de operação rodando ; senão diz por quê e não mexe. Provado em 09/10 (+14 commits antes do backup curto, que passou). **Fechado em 09/10 por Xavier.** |
| I18 | 2026-10-10 | O job `rejeu-image` reaplica todas as migrações na imagem Supabase a cada push (critério 1). **Critério 2 cumprido em 08/10**: ficou vermelho por uma razão real (privilégio padrão de `anon` nas tabelas da imagem) e a razão foi corrigida na migração (`c06f9ed2`), nunca no job. **Fechado em 10/10 por Xavier.** |
| E32 | 2026-10-10 | Nenhum ícone declarado em emoji em `src/`: as 106 declarações restantes passam ao nome `AppIcon` (mesmo componente na tela), a tabela `LEGACY` sai, a guarda `appicon-sans-emoji` mantém a regra (`391d80c9`, 10/10). **Fechado em 10/10 por Xavier.** |

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
3. Atualizar `docs/backlogs/INDEX.md`: versão corrente e linha de histórico.
4. Se o incremento traz uma decisão normativa, inscrever o identificador no `REGISTRE_decisions.md`. O backlog carrega o trabalho a fazer; o registro carrega o que faz fé.
5. **Novidade do v34**: as duas versões linguísticas e a página consultável são **geradas** a partir de `docs/backlogs/backlog-v34.json` por `scripts/build-backlog.cjs`. Nunca modifique os `.md` à mão: serão sobrescritos. Modifique o JSON, rode de novo `node scripts/build-backlog.cjs`, commite os três arquivos juntos.

Se essa mecânica atrapalhar mais do que ajudar, joga-se fora sem dano: os `.md` gerados são autônomos e o JSON pode ser apagado. É uma ferramenta, não uma doutrina.

---

## Colofão

Backlog v34, escrito em 2026-08-29, atualizado em 2026-10-10. Substitui `AnarBib-Backlog-2026-06-17-v33.md`. 55 itens em 11 domínios. O estado numérico foi levantado em 2026-10-09 contra o banco de produção em somente-leitura e contra o repositório Codeberg no commit `47781985`; os itens retocados desde então trazem a própria data no seu texto. Este documento não arbitra nada: o `REGISTRE_decisions.md` faz fé.
