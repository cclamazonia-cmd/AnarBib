# Redeploy notify-event com `--no-verify-jwt` (06/05/2026)

**Data:** 06/05/2026 (sessão da noite, durante o desenvolvimento do Lote 5 spec-gouvernance)
**Autor:** Xavier
**Tipo:** Correção de bug de produção silencioso descoberto por acaso

## Resumo executivo

Durante o desenvolvimento da Fase 1 do Lote 5 (infraestrutura outbox para notificações `team.*` da spec-gouvernance), descobrimos que **a Edge Function `notify-event` estava em produção com `verify_jwt=true`** (configuração padrão do Supabase). Isso significa que o gateway Supabase rejeitava com HTTP 401 toda requisição POST que não trouxesse um header `Authorization: Bearer <jwt>` válido — **antes mesmo** que o código da Edge Function fosse executado.

Consequência: **todos os triggers PostgreSQL que faziam `pg_net.http_post` para `notify-event`** — incluindo `fn_dispatch_circulation_notify_event`, em vigor desde abril de 2026 — recebiam silenciosamente HTTP 401 e **nenhum email saía**. O bug era silencioso porque:

- Os triggers PostgreSQL capturavam o erro em `EXCEPTION WHEN OTHERS` e retornavam `NULL` sem propagar
- Os logs do gateway Supabase mostravam 401 mas ninguém olhava
- O frontend não esperava feedback síncrono dessas notificações
- Nenhum sistema de monitoramento alertava sobre a ausência de emails

## Como descobrimos

A descoberta foi acidental, no contexto do Lote 5:

1. Implementamos `fn_team_notify_event` para emitir eventos `team.*` via `pg_net.http_post` para `notify-event`
2. Os primeiros testes retornaram HTTP 401 com mensagem `UNAUTHORIZED_NO_AUTH_HEADER`
3. Inicialmente pensamos que era um problema do nosso código (formato do payload, header `x-webhook-secret` incorreto, etc.)
4. Após várias verificações cruzadas (vault.decrypted_secrets, comparação com `fn_dispatch_circulation_notify_event`, teste manual via cURL com a chave correta), confirmamos que **o erro vinha do gateway Supabase**, não do código da EF
5. Verificamos `net._http_response` e constatamos que **as últimas 5 invocações de `notify-event` resultaram em 401**, todas vindas dos nossos testes — **nenhuma invocação real desde a criação de `fn_dispatch_circulation_notify_event`**

Isso confirmou que **as notificações de circulação (empréstimos, reservas) também estavam quebradas em prod desde abril de 2026** — embora o impacto seja limitado pelo fato de que o frontend complementa com seus próprios envios via `supabase.functions.invoke()` para alguns fluxos.

## Solução aplicada

Redeploy da Edge Function com flag `--no-verify-jwt`:

```bash
supabase functions deploy notify-event --no-verify-jwt
```

**O que isso faz:**
- O gateway Supabase deixa passar todas as requisições para `notify-event` sem exigir `Authorization: Bearer <jwt>` válido
- O código da Edge Function é executado normalmente
- A função `authorizeWebhook` interna (em `_shared/core/webhook.ts`) valida o segredo via header `x-webhook-secret`

**O que isso NÃO faz:**
- Não desabilita nenhuma proteção interna da função (o `authorizeWebhook` continua exigindo segredo válido)
- Não afeta as outras Edge Functions (`--no-verify-jwt` é por função)
- Não quebra o frontend que usa `supabase.functions.invoke('notify-event', ...)` (o JWT continua sendo enviado, apenas é ignorado pelo gateway, e o `bearerOk` interno valida normalmente)

## Verificação pós-redeploy

Teste manual via cURL com o segredo correto (extraído de `vault.decrypted_secrets`):

```bash
# Antes do redeploy:
# Status: 401 - {"code":"UNAUTHORIZED_NO_AUTH_HEADER","message":"Missing authorization header"}

# Depois do redeploy:
# Status: 200 - {"ok":true,"ignored":true,"event":"test_after_deploy","record_id":1}
```

Teste end-to-end via `fn_team_notify_event` (cadeia outbox completa):

```sql
SELECT public.fn_team_notify_event('team.test_phase1_final', '{"test":"phase1 — full chain after gateway fix"}'::jsonb);
-- Status HTTP retornado pelo trigger: 200
-- Response body: {"ok":true,"ignored":true,"event":"team.test_phase1_final","record_id":4}
```

## Impacto sobre `fn_dispatch_circulation_notify_event`

Esta função, criada em abril de 2026, agora **funciona corretamente** sem nenhuma modificação de código. O bug era 100% no nível do gateway, não no código da função. As próximas operações de circulação (criação de empréstimo, reserva, devolução, lembretes) **devem agora gerar emails normalmente**.

⚠️ **A verificar:** validar com um empréstimo real em prod que os emails de notificação chegam efetivamente (Xavier deve verificar a caixa de email da BLMF nos próximos dias).

## Bug similar potencial em outras Edge Functions

Outras EFs que recebem POSTs de triggers PostgreSQL podem ter o mesmo bug:

- `notify-internal-task` (verificada no chantier de 06/05 manhã, parece OK porque é invocada via `supabase.functions.invoke()` desde o frontend, não diretamente do DB)
- `notify-weekly-report`, `notify-network-weekly-report` (cron-driven, podem ter o mesmo problema se os crons usam `pg_net.http_post` com header próprio)
- `notify-mid-loan-reading` (idem, cron-driven)
- `notify-library-request`, `notify-document-permission-request`, `notify-interlibrary-loan` (idem)

**A fazer:** auditoria sistemática das outras EFs para confirmar que cada uma está corretamente configurada (`verify_jwt=false` se recebe POST direto do DB, ou autenticação Bearer + JWT se invocada do frontend).

## Lição aprendida

O `verify_jwt` padrão do Supabase é **uma armadilha silenciosa** para arquiteturas de notificação baseadas em triggers PostgreSQL. Quando uma EF é deployada com a CLI sem o flag `--no-verify-jwt`, ela funciona em modo "verificação JWT" — o que faz sentido para EFs invocadas de frontend autenticado, mas **bloqueia totalmente** as invocações vindas do banco de dados (que não têm JWT do usuário).

**Recomendação para AnarBib:** documentar explicitamente, em cada novo arquivo de migração que criar uma função `pg_net.http_post`, qual EF está sendo invocada e se ela precisa estar em modo `--no-verify-jwt`.

## Referências

- Migração que descobriu o bug: `db/migrations/2026_05_06_lot5_phase1_outbox_infrastructure.sql`
- Spec governance §11.4: estratégia outbox (Option B)
- Função "anciã" similar: `fn_dispatch_circulation_notify_event` (abril 2026)
- Edge Function: `supabase/functions/notify-event/index.ts` (sem mudança de código, apenas redeploy)
- Auth interna: `supabase/functions/_shared/core/webhook.ts` → função `authorizeWebhook`
