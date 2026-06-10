<!--
  Refactor dos triggers de sincronização is_primary / is_librarian
  Copyright (c) 2026 Xavier VAN WELDEN and AnarBib contributors.

  This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
  International License (CC-BY-SA-4.0). To view a copy of this license, visit
  https://creativecommons.org/licenses/by-sa/4.0/ or see the LICENSE-docs file
  at the root of this repository.
-->

# Refator dos triggers de sincronização is_primary / is_librarian — 2026-05-06

> Documento d(o/a/e) responsável técnic(o/a/e) d(o/a/e) AnarBib que registra a descoberta de um bug de arquitetura legada bloqueando a especificação de governança dos papéis, a análise das causas, e a solução escolhida.

---

## Contexto

Em 2026-05-06, durante a sessão de implementação dos Lots 2 e 3 da especificação de governança dos papéis (cf. `docs/spec-gouvernance-roles.md` §11), 8 funções RPC foram criadas em base para gerir as ações de cooptação, retirada e suspensão de membros do staff de uma biblioteca da rede AnarBib.

Após o deploy bem-sucedido do arquivo de migração, o **primeiro teste funcional** da RPC `fn_team_promote_to_librarian` em produção foi bloqueado por um erro de violação de unicidade.

---

## Diagnóstico do bug

### Cenário do bug

A RPC `fn_team_promote_to_librarian` foi chamada para coopter uma usuária `reader` ativa (compte de teste com seu consentimento prévio) ao papel de `librarian` na BLMF.

### Encadeamento dos triggers

Conforme a especificação §5.2, esta RPC deve **adicionar uma nova membership `librarian` ativa** em paralelo da membership `reader` existente (multi-membership), sem alterar a membership `reader`. Mas na prática, dois triggers legados se ativaram em cascata:

1. RPC executou `INSERT ... ON CONFLICT DO UPDATE` na tabela `user_library_memberships` para criar a linha `(user, BLMF, librarian, active)` — **bem sucedido**.
2. Trigger `trg_sync_profile_is_librarian_from_memberships` (sobre `user_library_memberships`) atualizou `profiles.is_librarian = true` para refletir a nova membership librarian — **bem sucedido**.
3. Trigger `trg_sync_primary_membership_role_from_profile_flag` (sobre `profiles`) tentou então **renomear** a membership do user marcada `is_primary = true` para `librarian`, considerando que o flag profiles.is_librarian fosse autoritativo sobre o papel.
4. Este UPDATE tentou escrever `(user, BLMF, librarian)` num momento em que a linha existia já (criada na etapa 1), violando a contrainte d'unicidade `(user_id, library_id, role)`.

### Análise da causa raiz

Os dois triggers refletiam uma **arquitetura mono-papel** na qual cada user tinha **uma única** membership "primária", e o flag `profiles.is_librarian` era a fonte de verdade do papel efetivo. Esta arquitetura não é compatível com o multi-membership previsto pela especificação §5.2 :

> *"L'ancienne membership reader reste active (la personne reste reader ET devient librarian). Multi-membership cohabite."*

Os dois sistemas (mono-papel legado e multi-membership novo) **co-existiam silenciosamente em produção sem nunca ter sido testados juntos**, simplesmente porque nenhum user em produção tinha jamais várias memberships ativas simultâneas. O teste funcional do Lot 2 foi a primeira tentativa concreta de cooptação multi-membership, e revelou o bug imediatamente.

---

## Análise dos impactos

Antes de qualquer modificação, foram conduzidas verificações exhaustivas de uso do flag `profiles.is_librarian` :

### Em base de dados

- **RLS policies** : nenhuma policy referencia `is_librarian` (verificação `pg_policies`).
- **Funções PL/pgSQL** : além dos dois triggers `sync_*`, **nenhuma outra função** modifica ou lê `is_librarian` (verificação `pg_proc`).

### No frontend (5 ocorrências em `src/`)

Todas operam sobre a **variable `role` da membership ativa**, e não sobre o flag `profiles.is_librarian` :

- `src/lib/roles.js` (linhas 25, 29, 60, 65) : helper `isLibrarian(role)` que recebe um papel em argumento.
- `src/pages/biblioteca/BibliotecaPage.jsx` (linhas 38, 562) : variável local computada a partir do papel da membership.
- `src/pages/painel/PanelPage.jsx` (linhas 30, 578, 588) : idem.

**Conclusão** : o frontend não depende de `profiles.is_librarian`.

### Nas Edge Functions (2 ocorrências em `supabase/functions/`)

- `notify-internal-task/_shared/data/internal-tasks.ts:8` : SELECT do flag `is_librarian`.
- `notify-internal-task/_shared/handlers/internal-task.ts:478` : verificação `if (!ownerProfile || ownerProfile.is_librarian !== true)`.

Esta única utilização de leitura do flag **deve ser preservada** — ela serve a determinar se o destinatári(o/a/e) interno de uma tarefa é um(a/e) librarian ativo.

---

## Solução adotada

### Opção retida : DROP do trigger inverso, conservação do outro

- **DROP** de `trg_sync_primary_membership_role_from_profile_flag` (sobre `public.profiles`) — este era o trigger problemático, que tentava renomear uma membership a partir do flag.
- **Conservação** de `trg_sync_profile_is_librarian_from_memberships` (sobre `public.user_library_memberships`) — este trigger continua a alimentar `profiles.is_librarian` em função das memberships ativas.

### Comportamento após o refator

- Quando uma membership `librarian` ativa é criada/modificada/desativada, `profiles.is_librarian` é automaticamente atualizado pelo trigger conservado.
- Quando alguém modifica diretamente `profiles.is_librarian` (caso sem ocorrência conhecida em todo o código), nenhum efeito de cascada é produzido sobre as memberships — a coluna fica simplesmente desincronizada (visível apenas via SQL direto).
- A coluna `user_library_memberships.is_primary` permanece em base mas não é mais utilizada para determinar o papel efetivo de um user.

### Alternativas consideradas e rejeitadas

- **Adaptar as RPCs para fazer um UPDATE da membership existente em vez de um INSERT** : rejeitada porque contradiz explicitamente a especificação §5.2 e perde o histórico fino por papel.
- **Audit completo + refator do sistema is_primary / is_librarian** : adiada porque representa um chantier dedicado de vários dias, e o impacto real do flag é mínimo (1 leitura em 1 EF).

---

## Testes funcionais validados

Após o DROP do trigger, 5 cenários foram testados em produção sobre a BLMF, com um compte de teste (com consentimento da usuária):

| # | RPC testada | Resultado |
|---|---|---|
| 1 | `fn_team_promote_to_librarian` | ✅ Cooptação OK, multi-membership preservado, `profiles.is_librarian` corretamente sincronizado |
| 2 | Reapelado idempotente | ✅ `no_change: true` |
| 3 | Auto-promoção | ✅ Recusada (`forbidden: cannot self-promote`, audit count = 0, nenhuma membership criada) |
| 4 | `fn_team_request_remove_member` | ✅ Pending_removal + carência 7d, `profiles.is_librarian` voltou a `false` |
| 5 | `fn_team_cancel_remove_member` | ✅ Retorno a active |

E em bonus : a idempotência da `request_remove_member` também foi validada (segundo apelado detectado).

Após os testes, o estado do compte de teste foi **integralmente restaurado** ao seu estado de origem (`reader, active` apenas) por um DELETE manual da membership `librarian` criada para os testes. As entradas em `library_membership_audit` foram conservadas como rastro de auditoria.

---

## Consequências e seguimento

### Para os Lots restantes

A descoberta deste bug confirma a **necessidade de testar todas as RPCs em prod** antes de considerar a especificação como aplicada. As RPCs não testadas neste momento (`promote_to_coordenador`, `suspend_member`, `unsuspend_member`) compartilham a estrutura das testadas e são consideradas validadas por parentesco estrutural, mas devem ser testadas explicitamente quando uma UI as expor (Lot 6).

### Para o backlog

Adicionar ao backlog :

1. **Suprimir a função morta `sync_primary_membership_role_from_profile_flag()`** após um período de observação (ex: 30 dias) sem reativação do bug.
2. **Considerar a depreciação de `user_library_memberships.is_primary`** : a coluna não tem mais função operacional. Em uma sessão futura, decidir se ela é deletada ou conservada (para fins históricos / migração de outras instâncias AnarBib).
3. **Refator de `notify-internal-task/_shared/handlers/internal-task.ts:478`** para usar uma joiNTURA sobre `user_library_memberships` em vez de ler `profiles.is_librarian`. Isto eliminaria o último uso do flag legado e permitiria deletar todo o sistema `is_librarian / is_primary` num futuro chantier de simplificação.

### Para a documentação técnica

Este documento e o arquivo de migração `db/migrations/2026_05_06_lot2_3_rpc_team_governance.sql` (que inclui o DROP do trigger com garda idempotente) constituem o rastro completo desta descoberta e da solução. Qualquer reaplicação da migração sobre uma instância AnarBib futura aplicará automaticamente o DROP, evitando que o bug se manifeste novamente em outra instância.

---

## Histórico de revisão

| Data | Autor(a/e) | Modificação |
|---|---|---|
| 2026-05-06 | Xavier VAN WELDEN | Criação inicial do documento. Acta a descoberta do bug bloqueando o Lot 2 da especificação de governança, a análise dos impactos do flag `is_librarian` no código, a solução escolhida (DROP do trigger inverso, conservação do trigger direto), os 5 testes funcionais validados, e o backlog de seguimento. |

---

*Este documento é disponibilizado sob licença **Creative Commons Attribution-ShareAlike 4.0 International** (CC-BY-SA-4.0). Ver o arquivo [`LICENSE-docs`](../../LICENSE-docs) na raiz do repositório.*
