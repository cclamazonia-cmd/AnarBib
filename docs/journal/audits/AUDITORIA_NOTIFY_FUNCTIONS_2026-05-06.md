<!--
  Auditoria de qualidade das Edge Functions notify-*
  Copyright (c) 2026 Xavier VAN WELDEN and AnarBib contributors.

  This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
  International License (CC-BY-SA-4.0). To view a copy of this license, visit
  https://creativecommons.org/licenses/by-sa/4.0/ or see the LICENSE-docs file
  at the root of this repository.
-->

# Auditoria das Edge Functions notify-* — 2026-05-06

> Documento d(o/a/e) responsável técnic(o/a/e) d(o/a/e) AnarBib registrando os achados e decisões da auditoria de qualidade do conjunto das Edge Functions notify-*, conduzida em 2026-05-06.

---

## Contexto

Em 2026-05-06, no seguimento da auditoria de qualidade do Livre Blanc v0.1, foi conduzida uma leitura sistemática das 8 Edge Functions notify-* presentes em produção:

- `notify-event` — dispatcher principal de eventos de empréstimos/reservas/perfis
- `notify-internal-task` — notificações de tarefas internas (alertes técnicos)
- `notify-library-request` — workflow de adesão de bibliotecas
- `notify-mid-loan-reading` — mensagem de meio de empréstimo + recomendações
- `notify-document-permission-request` — solicitação de acesso a documentos
- `notify-weekly-report` — relatório semanal por biblioteca
- `notify-network-weekly-report` — relatório semanal de rede
- `notify-interlibrary-loan` — empréstimos interbibliotecas

A auditoria visava detectar bugs, código morto, dette técnica e oportunidades de refactor.

---

## Achados principais

### 1. `notify-interlibrary-loan` era um stub silencioso (CRÍTICO — corrigido)

A função estava ativa em produção (versão 6) mas continha um TODO explicito e somente registrava em consola sem enviar mail. Ela era invocada pelo trigger DB `trg_interlibrary_loan_enqueue_notifications` em todo INSERT/UPDATE da tabela `interlibrary_loans_v2`.

**Risco operacional**: limitado pois a página `/biblioteca` que usa essa tabela é acessível apenas aos coordenadores. Apenas 1 linha de teste existia (criada em 2026-04-10 pelo responsável técnico), removida durante a auditoria.

**Correção aplicada**: reescrita em stub honesto com retorno HTTP 501 Not Implemented, log explícito `console.warn`, e referência ao documento [`MODULE_INTERBIBLIOTECAS_STATUT_2026-05-06.md`](./MODULE_INTERBIBLIOTECAS_STATUT_2026-05-06.md) que detalha o chantier em curso.

### 2. Duplicação massiva entre `notify-weekly-report` e `_shared/` (corrigida)

A função `notify-weekly-report` (760 linhas) duplicava aproximadamente 150 linhas de código já presente em `_shared/context/library-notification-context.ts` e `_shared/context/library-mail-routing.ts`. Essa duplicação criava risco de divergência: qualquer correção na resolução do contexto de biblioteca deveria ser propagada manualmente.

**Correção aplicada**: refactor para imports `_shared/` + wrapper local `resolveWeeklyMailRouting` para adicionar `recipientEmail`/`recipientName` específicos ao weekly report (baseados em `weekly_report_email`). A função passou de 760 para 554 linhas (~27% de redução).

### 3. `notify-mid-loan-reading` : duplicação parcial mas com divergências intencionais (mini-refactor aplicado)

A leitura detalhada revelou que `notify-mid-loan-reading` usa cascadas de variáveis de ambiente subtilmente diferentes (`BREVO_SENDER_NAME` notavelmente, não coberto pelo `_shared/core/env.ts`), e um `renderEmail` propre com seção de recomendações. Não é duplicação simples a eliminar.

**Correção aplicada**: mini-refactor minimal — apenas substituição de `createClient` local por `supabaseAdmin` partilhado de `_shared/core/env.ts`. O resto do código permanece intencionalmente específico, com comentário de cabeçalho documentando esta decisão.

### 4. `notify-network-weekly-report` : arquitetura intencionalmente específica (sem refactor)

A função opera ao nível **rede AnarBib globale** (não por biblioteca), com:
- Uma variável `recipientEmail` resolvida a partir de `NETWORK_WEEKLY_REPORT_EMAIL` (env globale)
- Sua própria `normalizeLibraryContext` que retorna apenas 11 colunas específicas
- Cascadas env próprias (`NETWORK_BRAND_NAME`, `NETWORK_SENDER_NAME`, etc.) distintas das per-biblio

Esta especificidade reflete um cas d'usage estructuralmente diferente do `notify-weekly-report` (per-biblio). Aucune refactor não é justificado.

### 5. `notify-library-request` e `notify-document-permission-request` : autônomas legítimas (sem refactor)

Essas duas funções não usam `library_notification_context` nem `resolveMailRouting` de `_shared/`. Elas têm suas próprias funções `renderEmail` (template HTML específico ao workflow), seu próprio `footerHtml`/`footerText`, e gerenciam diretamente os destinataires (lecteur·rices solicitando admissão ou acesso).

Elas têm cada uma cerca de 30 funções utilitárias internas (`esc`, `isValidEmail`, `formatDateBR`, etc.) que pourraient ser fatorisadas num `_shared/utils/` para harmonização, **mas isso é um chantier de mutualisação séparado** sem urgência. A duplicação não é com `_shared/` racine: é entre as funções autônomas entre si, e é tolerável.

### 6. `notify-internal-task/_shared/` interno : fork arquitetural (P3 cancelado, P4 isolado aplicado)

A função `notify-internal-task` tem seu próprio dossiê `_shared/` interno com 11 arquivos (~600 linhas) que constituem **uma implementação distinta e divergente** do `_shared/` racine. Os 9 arquivos comuns são todos diferentes (4 a 8 vezes mais linhas no interno). Não é uma duplicação à harmonizer mecaniquement, mas **um fork arquitetural** que evoluiu independentemente.

**Decisão (P3 cancelado)**: a unificação dos dois `_shared/` representaria um risco de regressão sobre uma função que funciona, sem benefício imediato. A unificação deverá ser feita oportunamente quando `notify-internal-task` for retomada por outras razões (correção de bug, evolução, refonte). Em cada caso, ela deverá ser cadrada como um chantier dedicado, não como uma simples migração mecânica.

**Correção isolada aplicada (P4)**: A linha morta `export const WEBHOOK_SECRET = (Deno.env.get("WEBHOOK_SECRET_NOTIFY_EVENT") || "").trim();` em `notify-internal-task/_shared/core/env.ts` foi removida. Essa constante apontava semanticamente para o secret incorreto (`notify-event` em vez de `notify-internal-task`) e nunca era importada em outros lugares — o secret real é definido localmente em `index.ts` a partir de `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK`. Comentário de cabeçalho adicionado para tracejabilidade.

---

## Backlog de mutualisação para o futuro

Os seguintes itens **não são bloqueantes** e não justificam refactor isolado, mas pourraient ser oportunidades quando outras razões nous fizessem retornar a essas funções:

1. **Mutualisação de helpers utilitários** entre `notify-library-request` e `notify-document-permission-request` (`esc`, `isValidEmail`, `formatDateBR`, `firstNameOnly`, `fullName`, `dedupeTargets`, etc.) num `_shared/utils/` ou `_shared/shared/`
2. **Unificação dos dois `_shared/`** (racine vs `notify-internal-task/_shared/`) à terme, dans um chantier dédié com audit de divergence approfundi
3. **Cleanup das variáveis de ambiente Brevo** : três chaves cohabitam (`BREVO_API_KEY_NOTIFICATIONS`, `BREVO_API_KEY_NOTIFY_RESERVA`, `BREVO_KEY`) com fallbacks entre elas. À harmonizer um dia
4. **Audit dos tres patterns d'autenticação webhook** : `notify-event` usa `serveJsonWebhook` de `_shared/`, `notify-internal-task` usa `serveJsonWebhook` de seu `_shared/` interno, os outros gerenciam à mão. À harmonizer

---

## Tabela récap das ações tomadas

| Função | Linhas avant | Linhas après | Ação | Trace |
|---|---|---|---|---|
| `notify-interlibrary-loan` | 84 (stub silencieux) | 105 (stub honesto 501) | Réécriture em stub honesto + doc politique | [Doc statut](./MODULE_INTERBIBLIOTECAS_STATUT_2026-05-06.md) |
| `notify-weekly-report` | 760 | 554 | Refactor profond imports `_shared/` + wrapper | Refactor commit |
| `notify-mid-loan-reading` | 599 | 610 | Mini-refactor `supabaseAdmin` partilhado + comentário | Refactor commit |
| `notify-internal-task/_shared/core/env.ts` | 19 | 22 | Remoção da const morta `WEBHOOK_SECRET` + comentário | Cleanup commit |
| `notify-event` | 44 | 44 | (auditado, arquitetura cible, nenhuma modificação) | — |
| `notify-network-weekly-report` | 480 | 480 | (auditado, arquitetura intencionalmente específica, nenhuma modificação) | — |
| `notify-library-request` | 649 | 649 | (auditado, autônoma legítima, nenhuma modificação) | — |
| `notify-document-permission-request` | 550 | 550 | (auditado, autônoma legítima, nenhuma modificação) | — |
| `notify-internal-task/index.ts` | 7 | 7 | (auditado, fork arquitetural assumido, P3 cancelado) | — |

---

## Histórico de revisão

| Data | Autor(a/e) | Modificação |
|---|---|---|
| 2026-05-06 | Xavier VAN WELDEN | Criação inicial. Acta a auditoria completa do conjunto notify-* conduzida em 2026-05-06 (P1 a P4), com refactor effetivado dos 4 itens nécessitants (P1 stub honesto, P2-A refactor profond weekly-report, P2-B mini-refactor mid-loan-reading, P4 remoção const morta) e annulation justifiée du P3 (fork arquitetural à traiter oportunament). |

---

*Este documento é disponibilizado sob licença **Creative Commons Attribution-ShareAlike 4.0 International** (CC-BY-SA-4.0). Ver o arquivo [`LICENSE-docs`](../../LICENSE-docs) na raiz do repositório.*
