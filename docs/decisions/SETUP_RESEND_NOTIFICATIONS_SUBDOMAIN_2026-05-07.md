# Configuração Resend — Sub-domínio `notifications.anarbib.org`

**Data:** 06-07/05/2026 (sessão da noite, durante a resolução do bug logos Brevo)
**Status:** Configuração DNS concluída e verificada. Migração progressiva de Brevo para Resend prevista nos próximos chantiers.
**Conta Resend:** pertencente ao CCLA (Coletivo Compas Libertaires em Amazonia)

## Contexto

Após a descoberta do bug logos Brevo (cf. `BUG_LOGOS_BREVO_TRACKER_2026-05-06.md`), confirmamos que Brevo não permite desativar a reescrita de URLs de imagens nos emails transacionais. Após avaliação séria de Resend / Postmark / Mailgun, a escolha recaiu sobre **Resend** :

- ✅ Permite desativar tracking (open + click) explicitamente
- ✅ Free tier permanente (3 000 emails/mês, plafond 100/dia) — largamente suficiente para AnarBib
- ✅ API moderna, migração relativamente simples desde Brevo
- ✅ Conta CCLA já existente (sem fricção administrativa)
- ⚠️ Metadados do compte ficam nos US (mas mesma situação que Supabase), atenuando o argumento RGPD

## Decisões de configuração

### Sub-domínio dedicado

**Escolha:** `notifications.anarbib.org` (e não o domínio principal `anarbib.org`).

**Razões:**

1. **Isolamento da reputação** : os emails de notificações automáticas não afetam a reputação do domínio principal usado para emails humanos
2. **Cohabitação Brevo / Resend durante a transição** : os dois providers podem coexistir sem conflito
3. **Sem risco de saturar o SPF** : SPF do `anarbib.org` continua a apontar somente para OVH (`include:mx.ovh.com`), não corre o risco de exceder o limite de 10 lookups

### Região de envio

**Escolha:** `eu-west-1` (Irlanda, EU).

**Razões:**

1. **Coerência política** : destinatários majoritariamente europeus e latino-americanos
2. **RGPD parcial** : o conteúdo dos emails transita por servidores EU, mesmo se os metadados do compte ficam nos US
3. **Deliverabilidade** : melhor aceitação pelos provedores europeus (Orange, Free, Proton, GMX, Web.de) para IPs EU

### Configuração de tracking

**Escolha:** Tracking desativado de facto.

**Como:** No dashboard Resend, a UI mostra opções "Enable click tracking" e "Enable open tracking" que parecem ativadas por padrão. Mas o teste empírico (envio de email de teste e inspeção do HTML recebido) confirma que **enquanto nenhum sub-domínio de tracking estiver configurado, Resend NÃO reescreve as URLs e NÃO insere pixel de tracking**.

**Verificação:** O email de teste enviado em 07/05/2026 00h53 mostra que :
- O `<a href>` no email recebido aponta diretamente para `https://anarbib.org` (não reescrito)
- O `<img src>` aponta diretamente para `uflwmikiyjfnikiphtcp.supabase.co` (não reescrito)
- Nenhum pixel de tracking 1x1 oculto foi injetado

**Consequência:** Os logos AnarBib + biblioteca aparecerão corretamente nos emails enviados via Resend, e ficarão visíveis nos arquivos de email a longo prazo (resolvendo definitivamente o bug logos Brevo).

## Records DNS configurados (zona OVH `anarbib.org`)

Três records adicionados em 07/05/2026 :

```
# DKIM (assinatura)
Type: TXT
Name: resend._domainkey.notifications
Value: p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC5UxzmXNjIlSOCDqLAcnWqpjjaybfjbVDEqNJLjYeKkFIlLv1wMmWtjMXHrEx5Zt6/CN1QV0b3flejRWVqMly1ebQDXliqakT1FxQzh8r6b103/RzxV9UCqfYjjc85mGaaO64hvu+LLOW/rcj9kqRxgUKEfQnBalxrCBafAR/JQwIDAQAB

# MX (recepção via Amazon SES feedback)
Type: MX
Name: send.notifications
Priority: 10
Value: feedback-smtp.eu-west-1.amazonses.com

# SPF (autorização de envio)
Type: TXT
Name: send.notifications
Value: v=spf1 include:amazonses.com ~all
```

**Verificação DNS** (07/05/2026, ~00h45) : os 3 records resolvem corretamente via `nslookup` no servidor DNS Quad9 (9.9.9.9). Resend confirmou o status `Verified` no dashboard.

**Não foi adicionado um record DMARC** sobre `_dmarc.notifications.anarbib.org` (Resend não exigiu). O DMARC do domínio principal (`_dmarc.anarbib.org`) já existe e aponta para Brevo (`rua@dmarc.brevo.com`), mas isso não afeta o sub-domínio que herda implicitamente da política do domínio pai.

## Teste de envio (07/05/2026 00h53)

```powershell
# Script PowerShell de teste com chave API de teste
$resendKey = "<TEST_API_KEY>"
$body = @{
    from = "AnarBib Test <test@notifications.anarbib.org>"
    to = @("x.vanwelden@gmail.com")
    subject = "Test Resend - verification tracking"
    html = "<html>...</html>"
} | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "https://api.resend.com/emails" -Method Post -Headers @{...} -Body $body
```

**Resultado:**
- HTTP 200, Email ID: `bb8415b2-5eaf-4bc1-b5a6-5215619837b6`
- Email recebido na inbox (não em spam)
- Logo AnarBib visível
- URLs não reescritas (cf. acima)

## Próximas etapas

### Curto prazo (na sessão atual)
1. ✅ DNS configurados e verificados
2. ✅ Sub-domínio funcionando
3. ⏳ **Solução base64 inline para Brevo** : enquanto Brevo continua em produção, embarcar os logos como `data:image/png;base64,...` no HTML para resolver o bug logos imediatamente, sem aguardar a migração completa para Resend

### Médio prazo (chantiers progressivos)
1. **Criar API key prod** dedicada (separada da chave de teste de 07/05) e armazená-la em secrets EF Supabase como `RESEND_API_KEY`
2. **Migrar a primeira EF** (provavelmente `notify-event` que é a mais usada) de Brevo para Resend
3. **Adaptar `_shared/transport/email.ts`** : criar uma função `sendResendEmail()` paralela a `sendBrevoEmail()`, ou um wrapper neutro `sendEmail()` que escolhe o provider baseado em uma variável de ambiente
4. **Migrar progressivamente** as 8 EFs notify-* uma por uma, validando deliverabilidade a cada etapa
5. **Suprimir os secrets Brevo** após 48h de funcionamento estável de todas as EFs em Resend

### Longo prazo
1. **Avaliar deliverabilidade** : monitorar o spam folder em Gmail / Outlook / Yahoo / Proton durante 1 mês após migração completa
2. **Considerar tracking se necessário** : se um dia AnarBib precisar de métricas de open/click (por exemplo para validar que as notificações de retorno de empréstimo são lidas), configurar um sub-domínio de tracking Resend
3. **Considerar EU residency total** : se o projeto militar uma migração completa para infra EU (Codeberg + Supabase EU + Resend EU), isso será um chantier dedicado

## Senders previstos

Decisão: cada email será enviado de um endereço identificável vinculado ao sub-domínio `notifications.anarbib.org`. Senders previstos (a confirmar quando da migração de cada EF) :

- `notifications@notifications.anarbib.org` — sender genérico para todas as notificações
- Possivelmente endereços específicos por biblioteca (`blmf@notifications.anarbib.org`, `btl@notifications.anarbib.org`) se quisermos diferenciar visualmente os senders

## Referências

- Conta Resend (CCLA) : https://resend.com
- Domain configuration : Resend Dashboard → Domains → notifications.anarbib.org
- DNS Zone : OVH Manager → Web Cloud → Domaines → anarbib.org → Zone DNS
- Bug logos Brevo (origem da migração) : `docs/decisions/BUG_LOGOS_BREVO_TRACKER_2026-05-06.md`
