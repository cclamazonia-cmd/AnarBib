<!--
  Estatuto do módulo de empréstimos interbibliotecas — em chantier
  Copyright (c) 2026 Xavier VAN WELDEN and AnarBib contributors.

  This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
  International License (CC-BY-SA-4.0). To view a copy of this license, visit
  https://creativecommons.org/licenses/by-sa/4.0/ or see the LICENSE-docs file
  at the root of this repository.
-->

# Estatuto do módulo de empréstimos interbibliotecas — 2026-05-06

> Documento d(o/a/e) responsável técnic(o/a/e) d(o/a/e) AnarBib sobre o estado d(o/a/e) módulo de empréstimos interbibliotecas em base AnarBib.

---

## Contexto

D(o/a/e) AnarBib comporta um módulo previsto de **empréstimos interbibliotecas**, destinado a permitir que uma biblioteca aderente envie um pedido de empréstimo a outra biblioteca aderente para aceder a um livro do catálogo desta. Este módulo é destinado a se tornar uma das funcionalidades estruturantes da rede AnarBib, na medida em que ele dá vida concreta à dimensão **rede** do projeto: cada biblioteca conserva sua autonomia, mas pode mutualizar seus acervos com as outras quando for útil às lutas.

Este documento atesta que **este módulo não está atualmente operacional** e que será **retomado e refinado** antes de qualquer entrada em serviço efetivo.

---

## Estado atual em base

### O que existe

- **Tabela `interlibrary_loans_v2`** — modelo de dados dos empréstimos interbibliotecas
- **Trigger `trg_interlibrary_loan_enqueue_notifications`** — dispara em `INSERT/UPDATE` da tabela
- **Função `fn_enqueue_emprestimo_interbibliotecas_notification`** — enqueue um evento na fila de notificações
- **Função `fn_notify_emprestimo_interbibliotecas_webhook`** — chama a Edge Function via webhook
- **Edge Function `notify-interlibrary-loan`** — recebe o webhook... mas **não envia mail** (cf. abaixo)

### O que falta

- **Envio efetivo dos mails** via Brevo na Edge Function (parte deixada explicitamente em `// TODO` no código original)
- **Validação política** dos formatos de mensagem, das políticas de acesso (quais bibliotecas podem pedir empréstimos a quais? sob quais condições?), do consentimento das partes, da gestão dos atrasos
- **Interface frontend** para criar e gerenciar pedidos de empréstimo interbibliotecas
- **Documentação** do fluxo completo

### Decisão atual

Em 2026-05-06, durante a auditoria de qualidade do conjunto das Edge Functions notify-*, foi constatado que `notify-interlibrary-loan` é uma EF **ativa em produção** (versão 6) mas **não-funcional** (somente loga em consola, não envia mail).

Para evitar que o módulo seja utilizado em estado de stub silencioso (com risco de criar pedidos de empréstimos interbibliotecas que ninguém receberia por mail, gerando uma falha invisível), a EF foi reescrita em **stub honesto**:

- A EF responde com HTTP **501 Not Implemented** ao invés de 200 OK
- Um log `console.warn` explícito sinaliza que o mail não foi enviado
- A documentação interna do código aponta para este documento
- O código existente de pré-formatagem (subjectMap, textBody) é **conservado** como ponto de partida para a implementação final

Esta escolha permite que:

- Se o trigger DB se ativar acidentalmente durante testes ou desenvolvimento, a falha será **visível** nos logs e no statut HTTP retornado
- Quem retomar o chantier não terá que reescrever a partir do zero (a estrutura está em ordem)
- Qualquer chamada futura involuntária ao webhook não passará despercebida

### O que NÃO foi feito

- A Edge Function **não foi suprimida** (permanece deployed em statut stub para sinalizar claramente o chantier em curso)
- O trigger DB **não foi desativado** (permanece ativo mas sem efeito útil enquanto a EF for stub)
- A tabela `interlibrary_loans_v2` **não foi modificada**

---

## Trabalho à reprendre

Quando o chantier for retomado, as etapas seguintes serão necessárias:

### Etapa A — Decisões políticas (a tomar antes de qualquer código)

1. **Quais bibliotecas podem pedir empréstimos a quais?** Toda biblioteca aderente da rede AnarBib pode pedir a toda outra? Ou existe um sistema de aprovações bilaterais? Reciprocidade obrigatória?
2. **Quais documentos podem ser objetos de empréstimo interbibliotecas?** Todos os exemplares? Apenas os que a biblioteca emprestadora marcar como "elegíveis"? Restrições por tipo de obra (raras, arquivos, etc.)?
3. **Quem suporta os custos de envio?** Biblioteca emprestadora? Tomadora? Lecteur·rice final? Caixa militante mutualizada?
4. **Quais durações de empréstimo se aplicam?** As mesmas que para os empréstimos locais? Mais longas? Negociáveis caso a caso?
5. **Como gerenciar os atrasos e perdas?** Mesma política que para os empréstimos locais? Mais flexível para acomodar os custos de envio? Engagement das duas bibliotecas?
6. **Consentimento dos lecteur·rice·s** — quando a lecteur·rice fizer um pedido de empréstimo interbibliotecas, qual é a base legal RGPD/LGPD? Suas dadas pessoais serão transmitidas à biblioteca emprestadora — sob quais condições?

Estas decisões deverão ser tomadas, idealmente, em **consultação com as bibliotecas aderentes do momento** (BLMF e eventuais outras) antes de qualquer redação técnica.

### Etapa B — Implementação técnica

Após validação política das decisões da etapa A:

1. Reescrita completa da Edge Function com envio Brevo real
2. Recurso à arquitetura `_shared/` da raiz (pattern do `notify-event`) para evitar a duplicação massiva detectada nas outras `notify-*` autônomas
3. Internacionalização dos mails via `mail-strings.ts` (6 locais)
4. Tests anti-régression
5. Implementação UI no frontend
6. Documentação de uso para os coordenador(a/e)s das bibliotecas

### Etapa C — Mise en service progressive

1. Activation testada com **somente a BLMF** primeiramente (auto-empréstimos para fins de teste)
2. Em seguida com **uma segunda biblioteca pilote** voluntária (em parceria de teste como a BTL atualmente)
3. Em seguida abertura à rede AnarBib completa quando o módulo for estável

---

## Anexo — Referências aos documentos relacionados

- [`REGISTRE_TRAITEMENTS.md`](../legal/REGISTRE_TRAITEMENTS.md) — Registro das atividades de tratamento (a complementar com este módulo quando ele for ativo)
- [`DECISOES_COORDENACAO_BLMF_2026-05-05.md`](./DECISOES_COORDENACAO_BLMF_2026-05-05.md) — Decisões de coordenação BLMF (referência de formato)
- Especificação de governança dos papéis (`docs/spec-gouvernance-roles.md`) — Cadrage político geral

---

## Histórico de revisão

| Data | Autor(a/e) | Modificação |
|---|---|---|
| 2026-05-06 | Xavier VAN WELDEN | Criação inicial do documento. Acta o estatuto de chantier em curso do módulo de empréstimos interbibliotecas, paralelamente à reescrita da Edge Function `notify-interlibrary-loan` em stub honesto (HTTP 501) durante a auditoria de qualidade das EF notify-*. |

---

*Este documento é disponibilizado sob licença **Creative Commons Attribution-ShareAlike 4.0 International** (CC-BY-SA-4.0). Ver o arquivo [`LICENSE-docs`](../../LICENSE-docs) na raiz do repositório.*
